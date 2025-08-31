# avion-auth キャッシュ最適化実装計画

## 概要

avion-authサービスの認証・認可処理におけるレイテンシ削減とスループット向上のため、多層キャッシュ戦略を実装します。

## 目標

- **レイテンシ削減**: p50 < 10ms, p99 < 50ms
- **キャッシュヒット率**: > 90%
- **スループット向上**: 10,000 req/sec以上
- **リソース効率化**: DB負荷を80%削減

## 1. Redisキャッシュレイヤーの実装

### 1.1 キャッシュアーキテクチャ

```go
// cache/redis_cache.go
package cache

import (
    "context"
    "encoding/json"
    "fmt"
    "time"
    
    "github.com/redis/go-redis/v9"
    "github.com/avion/avion-auth/domain"
)

type AuthCache interface {
    // JWT検証結果のキャッシュ
    GetJWTValidation(ctx context.Context, token string) (*JWTValidationResult, error)
    SetJWTValidation(ctx context.Context, token string, result *JWTValidationResult, ttl time.Duration) error
    
    // 認可結果のキャッシュ
    GetAuthorization(ctx context.Context, key string) (*AuthorizationResult, error)
    SetAuthorization(ctx context.Context, key string, result *AuthorizationResult, ttl time.Duration) error
    
    // ユーザーセッションのキャッシュ
    GetUserSession(ctx context.Context, userID string) (*UserSession, error)
    SetUserSession(ctx context.Context, userID string, session *UserSession, ttl time.Duration) error
    InvalidateUserSession(ctx context.Context, userID string) error
    
    // APIキー情報のキャッシュ
    GetAPIKey(ctx context.Context, keyHash string) (*APIKeyInfo, error)
    SetAPIKey(ctx context.Context, keyHash string, info *APIKeyInfo, ttl time.Duration) error
}

type RedisAuthCache struct {
    client *redis.Client
    prefix string
}

func NewRedisAuthCache(client *redis.Client) *RedisAuthCache {
    return &RedisAuthCache{
        client: client,
        prefix: "auth:",
    }
}

// JWT検証結果
type JWTValidationResult struct {
    Valid     bool              `json:"valid"`
    UserID    string           `json:"user_id"`
    Scopes    []string         `json:"scopes"`
    ExpiresAt time.Time        `json:"expires_at"`
    TokenType string           `json:"token_type"`
    Metadata  map[string]interface{} `json:"metadata"`
}

// 認可結果
type AuthorizationResult struct {
    Allowed    bool     `json:"allowed"`
    UserID     string   `json:"user_id"`
    Resource   string   `json:"resource"`
    Action     string   `json:"action"`
    Conditions []string `json:"conditions"`
    CachedAt   time.Time `json:"cached_at"`
}
```

### 1.2 キャッシュキー設計

```go
// cache/key_builder.go
package cache

import (
    "crypto/sha256"
    "fmt"
    "strings"
)

type CacheKeyBuilder struct {
    namespace string
}

func NewCacheKeyBuilder(namespace string) *CacheKeyBuilder {
    return &CacheKeyBuilder{namespace: namespace}
}

// JWT検証キー: auth:jwt:{token_hash}
func (b *CacheKeyBuilder) JWTKey(token string) string {
    hash := sha256.Sum256([]byte(token))
    return fmt.Sprintf("%s:jwt:%x", b.namespace, hash[:8])
}

// 認可キー: auth:authz:{user_id}:{resource}:{action}
func (b *CacheKeyBuilder) AuthorizationKey(userID, resource, action string) string {
    return fmt.Sprintf("%s:authz:%s:%s:%s", 
        b.namespace, userID, resource, action)
}

// セッションキー: auth:session:{user_id}
func (b *CacheKeyBuilder) SessionKey(userID string) string {
    return fmt.Sprintf("%s:session:%s", b.namespace, userID)
}

// APIキー: auth:apikey:{key_hash}
func (b *CacheKeyBuilder) APIKeyKey(keyHash string) string {
    return fmt.Sprintf("%s:apikey:%s", b.namespace, keyHash)
}
```

### 1.3 キャッシュ実装

```go
// cache/redis_cache_impl.go
package cache

import (
    "context"
    "encoding/json"
    "errors"
    "time"
    
    "github.com/redis/go-redis/v9"
)

var (
    ErrCacheMiss = errors.New("cache miss")
    ErrCacheSet  = errors.New("cache set failed")
)

func (c *RedisAuthCache) GetJWTValidation(ctx context.Context, token string) (*JWTValidationResult, error) {
    keyBuilder := NewCacheKeyBuilder(c.prefix)
    key := keyBuilder.JWTKey(token)
    
    data, err := c.client.Get(ctx, key).Bytes()
    if err == redis.Nil {
        return nil, ErrCacheMiss
    }
    if err != nil {
        return nil, err
    }
    
    var result JWTValidationResult
    if err := json.Unmarshal(data, &result); err != nil {
        return nil, err
    }
    
    // 有効期限チェック
    if time.Now().After(result.ExpiresAt) {
        c.client.Del(ctx, key)
        return nil, ErrCacheMiss
    }
    
    return &result, nil
}

func (c *RedisAuthCache) SetJWTValidation(ctx context.Context, token string, result *JWTValidationResult, ttl time.Duration) error {
    keyBuilder := NewCacheKeyBuilder(c.prefix)
    key := keyBuilder.JWTKey(token)
    
    data, err := json.Marshal(result)
    if err != nil {
        return err
    }
    
    // TTLは最大でトークンの有効期限まで
    maxTTL := time.Until(result.ExpiresAt)
    if ttl > maxTTL {
        ttl = maxTTL
    }
    
    return c.client.Set(ctx, key, data, ttl).Err()
}

func (c *RedisAuthCache) GetAuthorization(ctx context.Context, authKey string) (*AuthorizationResult, error) {
    data, err := c.client.Get(ctx, authKey).Bytes()
    if err == redis.Nil {
        return nil, ErrCacheMiss
    }
    if err != nil {
        return nil, err
    }
    
    var result AuthorizationResult
    if err := json.Unmarshal(data, &result); err != nil {
        return nil, err
    }
    
    return &result, nil
}

func (c *RedisAuthCache) SetAuthorization(ctx context.Context, authKey string, result *AuthorizationResult, ttl time.Duration) error {
    result.CachedAt = time.Now()
    
    data, err := json.Marshal(result)
    if err != nil {
        return err
    }
    
    return c.client.Set(ctx, authKey, data, ttl).Err()
}
```

## 2. JWTローカル検証の最適化

### 2.1 インメモリキャッシュ層

```go
// cache/local_cache.go
package cache

import (
    "sync"
    "time"
    
    "github.com/dgraph-io/ristretto"
)

type LocalCache struct {
    cache *ristretto.Cache
    mu    sync.RWMutex
}

func NewLocalCache() (*LocalCache, error) {
    cache, err := ristretto.NewCache(&ristretto.Config{
        NumCounters: 1e4,     // 10,000個のキー
        MaxCost:     1 << 27, // 128MB
        BufferItems: 64,
    })
    if err != nil {
        return nil, err
    }
    
    return &LocalCache{
        cache: cache,
    }, nil
}

// JWT公開鍵のローカルキャッシュ
type JWTPublicKeyCache struct {
    local *LocalCache
    redis *RedisAuthCache
}

func NewJWTPublicKeyCache(local *LocalCache, redis *RedisAuthCache) *JWTPublicKeyCache {
    return &JWTPublicKeyCache{
        local: local,
        redis: redis,
    }
}

func (c *JWTPublicKeyCache) GetPublicKey(ctx context.Context, kid string) ([]byte, error) {
    // L1: ローカルキャッシュ
    if value, found := c.local.cache.Get(kid); found {
        return value.([]byte), nil
    }
    
    // L2: Redisキャッシュ
    key := fmt.Sprintf("jwks:%s", kid)
    data, err := c.redis.client.Get(ctx, key).Bytes()
    if err == nil {
        c.local.cache.Set(kid, data, int64(len(data)))
        return data, nil
    }
    
    return nil, ErrCacheMiss
}

func (c *JWTPublicKeyCache) SetPublicKey(ctx context.Context, kid string, key []byte) error {
    // ローカルキャッシュに保存
    c.local.cache.Set(kid, key, int64(len(key)))
    
    // Redisに保存（TTL: 1時間）
    redisKey := fmt.Sprintf("jwks:%s", kid)
    return c.redis.client.Set(ctx, redisKey, key, time.Hour).Err()
}
```

### 2.2 JWT検証の最適化

```go
// auth/jwt_validator.go
package auth

import (
    "context"
    "errors"
    "time"
    
    "github.com/golang-jwt/jwt/v5"
    "github.com/avion/avion-auth/cache"
)

type OptimizedJWTValidator struct {
    cache         cache.AuthCache
    publicKeyCache *cache.JWTPublicKeyCache
    metrics       *Metrics
}

func (v *OptimizedJWTValidator) ValidateToken(ctx context.Context, tokenString string) (*cache.JWTValidationResult, error) {
    startTime := time.Now()
    defer func() {
        v.metrics.RecordJWTValidation(time.Since(startTime))
    }()
    
    // キャッシュチェック
    if result, err := v.cache.GetJWTValidation(ctx, tokenString); err == nil {
        v.metrics.IncrementCacheHit("jwt_validation")
        return result, nil
    }
    v.metrics.IncrementCacheMiss("jwt_validation")
    
    // JWTパース（署名検証なし）
    token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
        kid, ok := token.Header["kid"].(string)
        if !ok {
            return nil, errors.New("kid not found in token header")
        }
        
        // 公開鍵をキャッシュから取得
        publicKey, err := v.publicKeyCache.GetPublicKey(ctx, kid)
        if err != nil {
            return nil, err
        }
        
        return publicKey, nil
    })
    
    if err != nil {
        return nil, err
    }
    
    if !token.Valid {
        return nil, errors.New("invalid token")
    }
    
    // クレームの抽出
    claims, ok := token.Claims.(jwt.MapClaims)
    if !ok {
        return nil, errors.New("invalid claims")
    }
    
    result := &cache.JWTValidationResult{
        Valid:     true,
        UserID:    claims["sub"].(string),
        Scopes:    extractScopes(claims),
        ExpiresAt: time.Unix(int64(claims["exp"].(float64)), 0),
        TokenType: "Bearer",
        Metadata:  extractMetadata(claims),
    }
    
    // 結果をキャッシュ
    ttl := time.Until(result.ExpiresAt)
    if ttl > 5*time.Minute {
        ttl = 5 * time.Minute // 最大5分
    }
    
    if err := v.cache.SetJWTValidation(ctx, tokenString, result, ttl); err != nil {
        // キャッシュエラーはログのみ
        v.metrics.IncrementCacheError("jwt_validation_set")
    }
    
    return result, nil
}
```

## 3. 認可結果のキャッシュ

### 3.1 認可キャッシュ戦略

```go
// auth/authorization_cache.go
package auth

import (
    "context"
    "fmt"
    "time"
    
    "github.com/avion/avion-auth/cache"
    "github.com/avion/avion-auth/domain"
)

type CachedAuthorizationService struct {
    authzService domain.AuthorizationService
    cache        cache.AuthCache
    keyBuilder   *cache.CacheKeyBuilder
    ttl          time.Duration
    metrics      *Metrics
}

func NewCachedAuthorizationService(
    authzService domain.AuthorizationService,
    cache cache.AuthCache,
) *CachedAuthorizationService {
    return &CachedAuthorizationService{
        authzService: authzService,
        cache:        cache,
        keyBuilder:   cache.NewCacheKeyBuilder("auth"),
        ttl:          5 * time.Minute, // デフォルトTTL: 5分
        metrics:      NewMetrics(),
    }
}

func (s *CachedAuthorizationService) Authorize(
    ctx context.Context,
    userID string,
    resource string,
    action string,
) (bool, error) {
    // キャッシュキーの生成
    cacheKey := s.keyBuilder.AuthorizationKey(userID, resource, action)
    
    // キャッシュチェック
    if result, err := s.cache.GetAuthorization(ctx, cacheKey); err == nil {
        s.metrics.IncrementCacheHit("authorization")
        
        // キャッシュの鮮度チェック
        if time.Since(result.CachedAt) < s.ttl {
            return result.Allowed, nil
        }
    }
    s.metrics.IncrementCacheMiss("authorization")
    
    // 実際の認可処理
    allowed, err := s.authzService.Authorize(ctx, userID, resource, action)
    if err != nil {
        return false, err
    }
    
    // 結果をキャッシュ
    result := &cache.AuthorizationResult{
        Allowed:  allowed,
        UserID:   userID,
        Resource: resource,
        Action:   action,
        CachedAt: time.Now(),
    }
    
    // 非同期でキャッシュに保存
    go func() {
        ctx, cancel := context.WithTimeout(context.Background(), 100*time.Millisecond)
        defer cancel()
        
        if err := s.cache.SetAuthorization(ctx, cacheKey, result, s.ttl); err != nil {
            s.metrics.IncrementCacheError("authorization_set")
        }
    }()
    
    return allowed, nil
}

// 権限変更時のキャッシュ無効化
func (s *CachedAuthorizationService) InvalidateUserAuthorization(ctx context.Context, userID string) error {
    pattern := fmt.Sprintf("%s:authz:%s:*", "auth", userID)
    
    // Redisのパターンマッチングで該当キーを削除
    iter := s.cache.(*cache.RedisAuthCache).client.Scan(ctx, 0, pattern, 0).Iterator()
    for iter.Next(ctx) {
        if err := s.cache.(*cache.RedisAuthCache).client.Del(ctx, iter.Val()).Err(); err != nil {
            return err
        }
    }
    
    return iter.Err()
}
```

### 3.2 条件付き認可のキャッシュ

```go
// auth/conditional_cache.go
package auth

import (
    "context"
    "crypto/md5"
    "encoding/json"
    "fmt"
)

type ConditionalAuthCache struct {
    cache cache.AuthCache
}

// 条件付き認可結果のキャッシュ
func (c *ConditionalAuthCache) GetConditionalAuth(
    ctx context.Context,
    userID string,
    conditions map[string]interface{},
) (*cache.AuthorizationResult, error) {
    // 条件をハッシュ化してキーの一部に
    conditionHash := hashConditions(conditions)
    key := fmt.Sprintf("auth:conditional:%s:%s", userID, conditionHash)
    
    return c.cache.GetAuthorization(ctx, key)
}

func hashConditions(conditions map[string]interface{}) string {
    data, _ := json.Marshal(conditions)
    hash := md5.Sum(data)
    return fmt.Sprintf("%x", hash[:8])
}
```

## 4. キャッシュヒット率の監視

### 4.1 メトリクス実装

```go
// metrics/cache_metrics.go
package metrics

import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
)

type CacheMetrics struct {
    hitCounter   *prometheus.CounterVec
    missCounter  *prometheus.CounterVec
    errorCounter *prometheus.CounterVec
    latency      *prometheus.HistogramVec
    hitRate      *prometheus.GaugeVec
}

func NewCacheMetrics() *CacheMetrics {
    return &CacheMetrics{
        hitCounter: promauto.NewCounterVec(
            prometheus.CounterOpts{
                Name: "auth_cache_hits_total",
                Help: "Total number of cache hits",
            },
            []string{"cache_type"},
        ),
        missCounter: promauto.NewCounterVec(
            prometheus.CounterOpts{
                Name: "auth_cache_misses_total",
                Help: "Total number of cache misses",
            },
            []string{"cache_type"},
        ),
        errorCounter: promauto.NewCounterVec(
            prometheus.CounterOpts{
                Name: "auth_cache_errors_total",
                Help: "Total number of cache errors",
            },
            []string{"cache_type", "operation"},
        ),
        latency: promauto.NewHistogramVec(
            prometheus.HistogramOpts{
                Name:    "auth_cache_latency_seconds",
                Help:    "Cache operation latency",
                Buckets: prometheus.ExponentialBuckets(0.001, 2, 10),
            },
            []string{"cache_type", "operation"},
        ),
        hitRate: promauto.NewGaugeVec(
            prometheus.GaugeOpts{
                Name: "auth_cache_hit_rate",
                Help: "Cache hit rate percentage",
            },
            []string{"cache_type"},
        ),
    }
}

// ヒット率の計算と更新
func (m *CacheMetrics) UpdateHitRate(cacheType string) {
    hits := getCounterValue(m.hitCounter.WithLabelValues(cacheType))
    misses := getCounterValue(m.missCounter.WithLabelValues(cacheType))
    
    total := hits + misses
    if total > 0 {
        rate := (hits / total) * 100
        m.hitRate.WithLabelValues(cacheType).Set(rate)
    }
}
```

### 4.2 監視ダッシュボード設定

```yaml
# monitoring/grafana-dashboard.json
{
  "dashboard": {
    "title": "avion-auth Cache Performance",
    "panels": [
      {
        "title": "Cache Hit Rate",
        "targets": [
          {
            "expr": "auth_cache_hit_rate",
            "legendFormat": "{{cache_type}}"
          }
        ],
        "alert": {
          "conditions": [
            {
              "evaluator": {
                "params": [90],
                "type": "lt"
              },
              "operator": {
                "type": "and"
              },
              "query": {
                "params": ["A", "5m", "now"]
              },
              "reducer": {
                "params": [],
                "type": "avg"
              },
              "type": "query"
            }
          ],
          "message": "Cache hit rate is below 90%"
        }
      },
      {
        "title": "Cache Operation Latency",
        "targets": [
          {
            "expr": "histogram_quantile(0.99, auth_cache_latency_seconds)",
            "legendFormat": "p99 {{cache_type}}"
          }
        ]
      },
      {
        "title": "Cache Errors",
        "targets": [
          {
            "expr": "rate(auth_cache_errors_total[5m])",
            "legendFormat": "{{cache_type}} - {{operation}}"
          }
        ]
      }
    ]
  }
}
```

## 5. 実装スケジュール

### Week 1: 基盤構築
- [ ] Redisクラスタのセットアップ
- [ ] キャッシュインターフェースの実装
- [ ] 基本的なキャッシュ操作の実装
- [ ] ユニットテストの作成

### Week 2: 統合と最適化
- [ ] JWT検証の統合
- [ ] 認可処理の統合
- [ ] メトリクス実装
- [ ] 負荷テストとチューニング
- [ ] 監視ダッシュボードの構築

## 6. テスト計画

### 6.1 ユニットテスト

```go
// cache/cache_test.go
package cache_test

import (
    "context"
    "testing"
    "time"
    
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
    "github.com/alicebob/miniredis/v2"
)

func TestJWTCaching(t *testing.T) {
    // Redisモックの準備
    mr, err := miniredis.Run()
    require.NoError(t, err)
    defer mr.Close()
    
    cache := setupTestCache(mr.Addr())
    
    t.Run("JWT validation caching", func(t *testing.T) {
        ctx := context.Background()
        token := "test.jwt.token"
        
        result := &JWTValidationResult{
            Valid:     true,
            UserID:    "user123",
            ExpiresAt: time.Now().Add(1 * time.Hour),
        }
        
        // キャッシュに保存
        err := cache.SetJWTValidation(ctx, token, result, 5*time.Minute)
        assert.NoError(t, err)
        
        // キャッシュから取得
        cached, err := cache.GetJWTValidation(ctx, token)
        assert.NoError(t, err)
        assert.Equal(t, result.UserID, cached.UserID)
    })
}
```

### 6.2 負荷テスト

```go
// loadtest/cache_load_test.go
package loadtest

import (
    "context"
    "sync"
    "testing"
    "time"
)

func BenchmarkCachePerformance(b *testing.B) {
    cache := setupBenchmarkCache()
    ctx := context.Background()
    
    b.Run("Concurrent JWT validation", func(b *testing.B) {
        b.RunParallel(func(pb *testing.PB) {
            for pb.Next() {
                token := generateTestToken()
                result, _ := cache.ValidateToken(ctx, token)
                _ = result
            }
        })
    })
    
    b.Run("Cache hit rate", func(b *testing.B) {
        // 事前にキャッシュを温める
        tokens := warmupCache(cache, 1000)
        
        b.ResetTimer()
        hits := 0
        for i := 0; i < b.N; i++ {
            token := tokens[i%len(tokens)]
            if _, err := cache.GetJWTValidation(ctx, token); err == nil {
                hits++
            }
        }
        
        hitRate := float64(hits) / float64(b.N) * 100
        b.Logf("Cache hit rate: %.2f%%", hitRate)
    })
}
```

## 7. ロールバック計画

```yaml
rollback_strategy:
  triggers:
    - cache_hit_rate < 50%
    - error_rate > 5%
    - latency_p99 > 100ms
  
  steps:
    1_disable_cache:
      - feature_flag: ENABLE_AUTH_CACHE=false
      - restart_pods: kubectl rollout restart deployment/avion-auth
    
    2_monitor:
      - duration: 10m
      - check_metrics: latency, error_rate
    
    3_investigate:
      - collect_logs: kubectl logs -l app=avion-auth
      - analyze_metrics: grafana dashboards
      - identify_root_cause: cache configuration, network issues
```

## 8. 成功基準

- ✅ キャッシュヒット率 > 90%
- ✅ p50レイテンシ < 10ms
- ✅ p99レイテンシ < 50ms
- ✅ スループット > 10,000 req/sec
- ✅ DB負荷削減 > 80%
- ✅ エラー率 < 0.1%

## 9. 運用ガイド

### キャッシュのウォームアップ

```bash
# 起動時のキャッシュウォームアップ
curl -X POST http://avion-auth/admin/cache/warmup

# 公開鍵の事前ロード
curl -X POST http://avion-auth/admin/jwks/preload
```

### キャッシュの手動クリア

```bash
# 特定ユーザーのキャッシュクリア
curl -X DELETE http://avion-auth/admin/cache/user/{user_id}

# 全キャッシュクリア（緊急時のみ）
curl -X DELETE http://avion-auth/admin/cache/all
```

### 監視アラート設定

```yaml
alerts:
  - name: LowCacheHitRate
    expr: auth_cache_hit_rate < 90
    for: 5m
    annotations:
      summary: "Cache hit rate is below threshold"
      
  - name: HighCacheLatency
    expr: histogram_quantile(0.99, auth_cache_latency_seconds) > 0.05
    for: 5m
    annotations:
      summary: "Cache latency is above 50ms"
```