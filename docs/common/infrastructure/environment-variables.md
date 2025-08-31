# Avion 環境変数管理設計ガイドライン

## 概要

すべてのAvionマイクロサービスにおいて、環境変数管理を統一的に実装するためのガイドラインです。
起動時の必須環境変数検証と、.cursor/rules準拠の設計を実現します。

## 設計原則

1. **早期失敗（Fail Fast）**: 必須環境変数が不足している場合、起動時に即座に失敗
2. **明確なエラーメッセージ**: どの環境変数が不足しているかを明確に報告
3. **型安全性**: 環境変数を適切な型に変換し、Value Objectとして扱う
4. **テスト容易性**: 環境変数の読み込みをインターフェース化し、モック可能に
5. **DDD準拠**: Infrastructure層のConfigパッケージとして実装

## 実装ガイドライン

### 1. パッケージ構造

```
avion-[service-name]/
└── internal/
    └── infrastructure/
        └── config/
            ├── config.go          # Config構造体とロード関数
            ├── config_test.go     # テスト
            ├── validator.go       # 検証ロジック
            └── errors.go          # エラー定義
```

### 2. Config構造体の定義

```go
// internal/infrastructure/config/config.go
package config

import (
    "fmt"
    "os"
    "strconv"
    "time"
)

// Config はサービスの設定を保持する構造体
type Config struct {
    // サーバー設定
    Server ServerConfig
    
    // データベース設定
    Database DatabaseConfig
    
    // Redis設定
    Redis RedisConfig
    
    // 認証設定
    Auth AuthConfig
    
    // 外部サービス設定
    Services ServicesConfig
    
    // 監視設定
    Observability ObservabilityConfig
}

// ServerConfig サーバー関連の設定
type ServerConfig struct {
    Port        int           `env:"PORT" required:"true" default:"8080"`
    GRPCPort    int           `env:"GRPC_PORT" required:"true" default:"9090"`
    Environment string        `env:"ENVIRONMENT" required:"true" default:"development"`
    LogLevel    string        `env:"LOG_LEVEL" required:"false" default:"info"`
    Timeout     time.Duration `env:"SERVER_TIMEOUT" required:"false" default:"30s"`
}

// DatabaseConfig データベース関連の設定
type DatabaseConfig struct {
    Host     string `env:"DB_HOST" required:"true"`
    Port     int    `env:"DB_PORT" required:"true" default:"5432"`
    Name     string `env:"DB_NAME" required:"true"`
    User     string `env:"DB_USER" required:"true"`
    Password string `env:"DB_PASSWORD" required:"true" secret:"true"`
    SSLMode  string `env:"DB_SSL_MODE" required:"false" default:"require"`
}

// RedisConfig Redis関連の設定
type RedisConfig struct {
    Host     string `env:"REDIS_HOST" required:"true"`
    Port     int    `env:"REDIS_PORT" required:"true" default:"6379"`
    Password string `env:"REDIS_PASSWORD" required:"false" secret:"true"`
    DB       int    `env:"REDIS_DB" required:"false" default:"0"`
}
```

### 3. 環境変数ローダーの実装

```go
// internal/infrastructure/config/config.go (続き)

// EnvironmentLoader は環境変数を読み込むインターフェース
//go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/infrastructure/config/mock_environment_loader.go -package=config
type EnvironmentLoader interface {
    Get(key string) string
    Lookup(key string) (string, bool)
}

// OSEnvironmentLoader はOSの環境変数を読み込む実装
type OSEnvironmentLoader struct{}

func (l *OSEnvironmentLoader) Get(key string) string {
    return os.Getenv(key)
}

func (l *OSEnvironmentLoader) Lookup(key string) (string, bool) {
    return os.LookupEnv(key)
}

// Load は環境変数から設定を読み込む
func Load(loader EnvironmentLoader) (*Config, error) {
    validator := NewValidator(loader)
    
    cfg := &Config{}
    
    // 各設定セクションの読み込みと検証
    if err := validator.ValidateAndLoad(&cfg.Server); err != nil {
        return nil, fmt.Errorf("server config: %w", err)
    }
    
    if err := validator.ValidateAndLoad(&cfg.Database); err != nil {
        return nil, fmt.Errorf("database config: %w", err)
    }
    
    if err := validator.ValidateAndLoad(&cfg.Redis); err != nil {
        return nil, fmt.Errorf("redis config: %w", err)
    }
    
    // ... 他の設定セクション
    
    return cfg, nil
}

// MustLoad は環境変数から設定を読み込み、エラーの場合はパニックする
func MustLoad() *Config {
    cfg, err := Load(&OSEnvironmentLoader{})
    if err != nil {
        panic(fmt.Sprintf("failed to load config: %v", err))
    }
    return cfg
}
```

### 4. バリデーターの実装

```go
// internal/infrastructure/config/validator.go
package config

import (
    "fmt"
    "reflect"
    "strconv"
    "time"
)

// Validator は設定の検証とロードを行う
type Validator struct {
    loader EnvironmentLoader
}

func NewValidator(loader EnvironmentLoader) *Validator {
    return &Validator{loader: loader}
}

// ValidateAndLoad は構造体のタグを読み取り、環境変数から値をロードして検証する
func (v *Validator) ValidateAndLoad(cfg interface{}) error {
    val := reflect.ValueOf(cfg).Elem()
    typ := val.Type()
    
    var missingVars []string
    
    for i := 0; i < typ.NumField(); i++ {
        field := typ.Field(i)
        fieldVal := val.Field(i)
        
        envKey := field.Tag.Get("env")
        if envKey == "" {
            continue
        }
        
        required := field.Tag.Get("required") == "true"
        defaultValue := field.Tag.Get("default")
        
        envValue, exists := v.loader.Lookup(envKey)
        
        if !exists || envValue == "" {
            if required && defaultValue == "" {
                missingVars = append(missingVars, envKey)
                continue
            }
            if defaultValue != "" {
                envValue = defaultValue
            }
        }
        
        if err := v.setFieldValue(fieldVal, field.Type, envValue); err != nil {
            return fmt.Errorf("failed to set %s: %w", envKey, err)
        }
    }
    
    if len(missingVars) > 0 {
        return NewMissingEnvVarsError(missingVars)
    }
    
    return nil
}

func (v *Validator) setFieldValue(field reflect.Value, fieldType reflect.Type, value string) error {
    switch fieldType.Kind() {
    case reflect.String:
        field.SetString(value)
    case reflect.Int:
        intVal, err := strconv.Atoi(value)
        if err != nil {
            return err
        }
        field.SetInt(int64(intVal))
    case reflect.Bool:
        boolVal, err := strconv.ParseBool(value)
        if err != nil {
            return err
        }
        field.SetBool(boolVal)
    default:
        // time.Duration などの特殊な型の処理
        if fieldType == reflect.TypeOf(time.Duration(0)) {
            duration, err := time.ParseDuration(value)
            if err != nil {
                return err
            }
            field.Set(reflect.ValueOf(duration))
            return nil
        }
        return fmt.Errorf("unsupported type: %v", fieldType)
    }
    return nil
}
```

### 5. エラー定義

```go
// internal/infrastructure/config/errors.go
package config

import (
    "fmt"
    "strings"
)

// MissingEnvVarsError は必須環境変数が不足している場合のエラー
type MissingEnvVarsError struct {
    MissingVars []string
}

func NewMissingEnvVarsError(vars []string) *MissingEnvVarsError {
    return &MissingEnvVarsError{MissingVars: vars}
}

func (e *MissingEnvVarsError) Error() string {
    return fmt.Sprintf(
        "Missing required environment variables:\n  - %s\n\nPlease set these environment variables and try again.",
        strings.Join(e.MissingVars, "\n  - "),
    )
}
```

### 6. サービス固有の設定拡張例

#### avion-auth の場合

```go
// internal/infrastructure/config/config.go
type Config struct {
    // ... 共通設定
    
    // JWT設定
    JWT JWTConfig
    
    // OAuth2設定
    OAuth2 OAuth2Config
    
    // WebAuthn設定
    WebAuthn WebAuthnConfig
}

type JWTConfig struct {
    SigningKeyPath    string        `env:"JWT_SIGNING_KEY_PATH" required:"true"`
    AccessTokenTTL    time.Duration `env:"JWT_ACCESS_TOKEN_TTL" required:"false" default:"15m"`
    RefreshTokenTTL   time.Duration `env:"JWT_REFRESH_TOKEN_TTL" required:"false" default:"30d"`
    RotationInterval  time.Duration `env:"JWT_KEY_ROTATION_INTERVAL" required:"false" default:"90d"`
}

type OAuth2Config struct {
    AuthCodeTTL          time.Duration `env:"OAUTH2_AUTH_CODE_TTL" required:"false" default:"10m"`
    PKCERequired         bool          `env:"OAUTH2_PKCE_REQUIRED" required:"false" default:"true"`
    DynamicClientEnabled bool          `env:"OAUTH2_DYNAMIC_CLIENT_ENABLED" required:"false" default:"true"`
}

type WebAuthnConfig struct {
    RPName     string `env:"WEBAUTHN_RP_NAME" required:"true"`
    RPID       string `env:"WEBAUTHN_RP_ID" required:"true"`
    RPOrigin   string `env:"WEBAUTHN_RP_ORIGIN" required:"true"`
}
```

#### avion-timeline の場合

```go
type Config struct {
    // ... 共通設定
    
    // タイムライン設定
    Timeline TimelineConfig
    
    // キャッシュ設定
    Cache CacheConfig
    
    // Fan-out設定
    Fanout FanoutConfig
}

type TimelineConfig struct {
    MaxEntriesPerTimeline int           `env:"TIMELINE_MAX_ENTRIES" required:"false" default:"1000"`
    CacheTTL              time.Duration `env:"TIMELINE_CACHE_TTL" required:"false" default:"7d"`
}

type FanoutConfig struct {
    CelebrityThreshold   int `env:"FANOUT_CELEBRITY_THRESHOLD" required:"false" default:"10000"`
    BatchSize            int `env:"FANOUT_BATCH_SIZE" required:"false" default:"100"`
    WorkerCount          int `env:"FANOUT_WORKER_COUNT" required:"false" default:"10"`
    ActiveUserWindowDays int `env:"FANOUT_ACTIVE_USER_WINDOW_DAYS" required:"false" default:"7"`
}
```

### 7. main.goでの使用例

```go
// cmd/server/main.go
package main

import (
    "log"
    "os"
    "os/signal"
    "syscall"
    
    "github.com/avion/avion-auth/internal/infrastructure/config"
    // ... 他のインポート
)

func main() {
    // 環境変数の読み込み（必須環境変数が不足していればここで失敗）
    cfg := config.MustLoad()
    
    // ロガーの初期化
    logger := initLogger(cfg.Server.LogLevel)
    
    logger.Info("Starting avion-auth server",
        "environment", cfg.Server.Environment,
        "port", cfg.Server.Port,
        "grpc_port", cfg.Server.GRPCPort,
    )
    
    // 依存関係の初期化
    db := initDatabase(cfg.Database)
    redis := initRedis(cfg.Redis)
    
    // サーバーの起動
    // ...
}
```

### 8. テストの実装例

```go
// internal/infrastructure/config/config_test.go
package config_test

import (
    "testing"
    
    "github.com/golang/mock/gomock"
    "github.com/stretchr/testify/assert"
    
    "github.com/avion/avion-auth/internal/infrastructure/config"
    "github.com/avion/avion-auth/tests/mocks/infrastructure/config"
)

func TestLoad_RequiredEnvVarsMissing(t *testing.T) {
    ctrl := gomock.NewController(t)
    defer ctrl.Finish()
    
    mockLoader := mock_config.NewMockEnvironmentLoader(ctrl)
    
    // 必須環境変数が設定されていない状態をモック
    mockLoader.EXPECT().Lookup("PORT").Return("", false)
    mockLoader.EXPECT().Lookup("GRPC_PORT").Return("", false)
    mockLoader.EXPECT().Lookup("ENVIRONMENT").Return("", false)
    mockLoader.EXPECT().Lookup("DB_HOST").Return("", false)
    // ... 他の必須環境変数
    
    cfg, err := config.Load(mockLoader)
    
    assert.Nil(t, cfg)
    assert.Error(t, err)
    
    missingErr, ok := err.(*config.MissingEnvVarsError)
    assert.True(t, ok)
    assert.Contains(t, missingErr.MissingVars, "PORT")
    assert.Contains(t, missingErr.MissingVars, "DB_HOST")
}

func TestLoad_WithDefaults(t *testing.T) {
    ctrl := gomock.NewController(t)
    defer ctrl.Finish()
    
    mockLoader := mock_config.NewMockEnvironmentLoader(ctrl)
    
    // 必須環境変数のみ設定
    mockLoader.EXPECT().Lookup("PORT").Return("", false) // デフォルト値を使用
    mockLoader.EXPECT().Lookup("ENVIRONMENT").Return("production", true)
    mockLoader.EXPECT().Lookup("DB_HOST").Return("localhost", true)
    // ... 他の設定
    
    cfg, err := config.Load(mockLoader)
    
    assert.NoError(t, err)
    assert.NotNil(t, cfg)
    assert.Equal(t, 8080, cfg.Server.Port) // デフォルト値
    assert.Equal(t, "production", cfg.Server.Environment)
}
```

## 各サービスへの適用手順

1. **infrastructure/configパッケージの作成**
   - 共通のConfig構造体定義
   - サービス固有の設定を追加

2. **環境変数の文書化**
   - READMEに必須/オプション環境変数の一覧を記載
   - .env.exampleファイルの提供

3. **Docker/Kubernetes設定の更新**
   - ConfigMapで環境変数を管理
   - Secretsで機密情報を管理

4. **CI/CDパイプラインの更新**
   - 環境変数の設定確認
   - テスト環境での検証

## セキュリティ考慮事項

1. **機密情報の扱い**
   - パスワード、APIキーなどは`secret:"true"`タグを付与
   - ログ出力時にマスキング

2. **環境変数の暗号化**
   - Kubernetes Secretsの使用
   - 環境変数の暗号化ツールの活用

3. **最小権限の原則**
   - 各サービスに必要最小限の環境変数のみ設定

## まとめ

この設計により、以下が実現されます：

1. **起動時の早期失敗**: 必須環境変数の不足を即座に検出
2. **明確なエラーメッセージ**: 不足している環境変数のリストを表示
3. **型安全性**: 環境変数を適切な型に変換
4. **テスト容易性**: モックを使用した単体テスト
5. **DDD準拠**: Infrastructure層での適切な実装
6. **.cursor/rules準拠**: 設計ガイドラインに完全準拠

各サービスはこのガイドラインに従って環境変数管理を実装することで、統一的で堅牢な設定管理を実現できます。