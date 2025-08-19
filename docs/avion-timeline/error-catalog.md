# Error Catalog: avion-timeline

**Service:** avion-timeline  
**Version:** 1.0.0  
**Last Updated:** 2025/01/19

## Error Code Format

すべてのエラーコードは以下の形式に従います：

```
TIMELINE_[LAYER]_[ERROR_TYPE]
```

- **TIMELINE**: サービス識別子
- **LAYER**: エラー発生層 (DOMAIN | USECASE | HANDLER | INFRA)
- **ERROR_TYPE**: 具体的なエラー種別

## Error Categories

### 1. Domain Layer Errors (TIMELINE_DOMAIN_*)

| Error Code | HTTP Status | gRPC Code | Description | User Message | Recovery Action |
|------------|-------------|-----------|-------------|--------------|-----------------|
| TIMELINE_DOMAIN_NOT_FOUND | 404 | NOT_FOUND | タイムラインが見つからない | タイムラインが見つかりません | 再構築を試みる |
| TIMELINE_DOMAIN_EXPIRED | 410 | FAILED_PRECONDITION | タイムラインキャッシュが期限切れ | タイムラインの有効期限が切れています | キャッシュを再生成 |
| TIMELINE_DOMAIN_MAX_ENTRIES_EXCEEDED | 413 | RESOURCE_EXHAUSTED | タイムラインエントリー数が上限超過 | タイムラインが上限に達しました | 古いエントリーを削除 |
| TIMELINE_DOMAIN_INVALID_CURSOR | 400 | INVALID_ARGUMENT | 無効なカーソル値 | ページネーション情報が無効です | 最初から取得し直す |
| TIMELINE_DOMAIN_INVALID_TYPE | 400 | INVALID_ARGUMENT | 無効なタイムラインタイプ | タイムラインの種類が無効です | 有効な値を指定 |
| TIMELINE_DOMAIN_DUPLICATE_ENTRY | 409 | ALREADY_EXISTS | 重複したタイムラインエントリー | エントリーが既に存在します | 既存エントリーを使用 |
| TIMELINE_DOMAIN_INVALID_FILTER | 400 | INVALID_ARGUMENT | 無効なフィルター条件 | フィルター条件が無効です | 有効な条件を指定 |
| TIMELINE_DOMAIN_ENTRY_TOO_OLD | 410 | OUT_OF_RANGE | エントリーが古すぎる | 投稿が古すぎます | 新しい投稿を取得 |
| TIMELINE_DOMAIN_MAX_LISTS_EXCEEDED | 413 | RESOURCE_EXHAUSTED | リスト作成数が上限超過 | リストの作成上限に達しました | 既存リストを削除 |
| TIMELINE_DOMAIN_MAX_MEMBERS_EXCEEDED | 413 | RESOURCE_EXHAUSTED | リストメンバー数が上限超過 | リストメンバーの上限に達しました | メンバーを削除 |
| TIMELINE_DOMAIN_LIST_NOT_FOUND | 404 | NOT_FOUND | リストが見つからない | リストが見つかりません | リストを確認 |
| TIMELINE_DOMAIN_ACCESS_DENIED | 403 | PERMISSION_DENIED | リストへのアクセス拒否 | このリストにアクセスできません | 権限を確認 |
| TIMELINE_DOMAIN_DUPLICATE_MEMBER | 409 | ALREADY_EXISTS | 重複したリストメンバー | メンバーは既に追加されています | 既存メンバーを使用 |
| TIMELINE_DOMAIN_MEMBER_NOT_FOUND | 404 | NOT_FOUND | リストメンバーが見つからない | メンバーが見つかりません | メンバーを確認 |
| TIMELINE_DOMAIN_INVALID_VISIBILITY | 400 | INVALID_ARGUMENT | 無効な可視性設定 | 可視性設定が無効です | 有効な値を指定 |

### 2. UseCase Layer Errors (TIMELINE_USECASE_*)

| Error Code | HTTP Status | gRPC Code | Description | User Message | Recovery Action |
|------------|-------------|-----------|-------------|--------------|-----------------|
| TIMELINE_USECASE_FANOUT_TIMEOUT | 504 | DEADLINE_EXCEEDED | Fan-out処理がタイムアウト | 配信処理がタイムアウトしました | リトライまたはPull型に切替 |
| TIMELINE_USECASE_INVALID_TYPE | 400 | INVALID_ARGUMENT | 無効なタイムラインタイプ指定 | タイムラインの種類が正しくありません | 有効なタイプを指定 |
| TIMELINE_USECASE_CONCURRENT_UPDATE | 409 | ABORTED | 同時更新による競合 | 更新が競合しました | リトライを実行 |
| TIMELINE_USECASE_EVENT_PROCESSING_FAILED | 500 | INTERNAL | イベント処理の失敗 | イベント処理に失敗しました | イベントを再送信 |
| TIMELINE_USECASE_REBUILD_FAILED | 500 | INTERNAL | タイムライン再構築失敗 | タイムラインの再構築に失敗しました | 手動で再構築 |
| TIMELINE_USECASE_CACHE_UPDATE_FAILED | 500 | DATA_LOSS | キャッシュ更新失敗 | キャッシュの更新に失敗しました | キャッシュクリア |
| TIMELINE_USECASE_INVALID_STRATEGY | 500 | INTERNAL | 無効なFan-out戦略 | 配信戦略が無効です | デフォルト戦略を使用 |
| TIMELINE_USECASE_BATCH_PROCESSING_FAILED | 500 | INTERNAL | バッチ処理失敗 | バッチ処理に失敗しました | 個別処理に切替 |
| TIMELINE_USECASE_SSE_SUBSCRIBE_FAILED | 500 | INTERNAL | SSE購読失敗 | リアルタイム更新の購読に失敗しました | 再接続を試行 |
| TIMELINE_USECASE_LIST_OPERATION_FAILED | 500 | INTERNAL | リスト操作失敗 | リスト操作に失敗しました | 操作を再試行 |
| TIMELINE_USECASE_MERGE_CONFLICT | 409 | ABORTED | タイムラインマージ競合 | タイムラインのマージに失敗しました | マージを再試行 |
| TIMELINE_USECASE_POLICY_VIOLATION | 403 | PERMISSION_DENIED | ポリシー違反 | ポリシー違反により操作が拒否されました | ポリシーを確認 |

### 3. Handler Layer Errors (TIMELINE_HANDLER_*)

| Error Code | HTTP Status | gRPC Code | Description | User Message | Recovery Action |
|------------|-------------|-----------|-------------|--------------|-----------------|
| TIMELINE_HANDLER_INVALID_REQUEST | 400 | INVALID_ARGUMENT | 不正なリクエスト形式 | リクエストが不正です | リクエストを修正 |
| TIMELINE_HANDLER_UNAUTHORIZED | 401 | UNAUTHENTICATED | 認証失敗 | 認証が必要です | ログインし直す |
| TIMELINE_HANDLER_FORBIDDEN | 403 | PERMISSION_DENIED | 権限不足 | この操作を実行する権限がありません | 権限を確認 |
| TIMELINE_HANDLER_RATE_LIMITED | 429 | RESOURCE_EXHAUSTED | レート制限超過 | リクエスト数が上限を超えました | 時間をおいて再試行 |
| TIMELINE_HANDLER_VALIDATION_FAILED | 400 | INVALID_ARGUMENT | バリデーション失敗 | 入力値が不正です | 入力値を修正 |
| TIMELINE_HANDLER_METHOD_NOT_ALLOWED | 405 | UNIMPLEMENTED | 許可されていないメソッド | このメソッドは許可されていません | 別のメソッドを使用 |
| TIMELINE_HANDLER_CONTENT_TYPE_ERROR | 415 | INVALID_ARGUMENT | Content-Typeエラー | サポートされていないコンテンツタイプです | 正しいContent-Typeを指定 |
| TIMELINE_HANDLER_SSE_INIT_FAILED | 500 | INTERNAL | SSE初期化失敗 | リアルタイム接続の初期化に失敗しました | 再接続を試行 |
| TIMELINE_HANDLER_SSE_WRITE_FAILED | 500 | INTERNAL | SSEイベント送信失敗 | イベントの送信に失敗しました | 接続を確認 |
| TIMELINE_HANDLER_CONTEXT_EXTRACTION_FAILED | 500 | INTERNAL | コンテキスト抽出失敗 | ユーザー情報の取得に失敗しました | 再認証 |
| TIMELINE_HANDLER_RESPONSE_ENCODING_FAILED | 500 | INTERNAL | レスポンスエンコード失敗 | レスポンスの生成に失敗しました | 再試行 |
| TIMELINE_HANDLER_TIMEOUT | 504 | DEADLINE_EXCEEDED | リクエストタイムアウト | リクエストがタイムアウトしました | 再試行 |

### 4. Infrastructure Layer Errors (TIMELINE_INFRA_*)

| Error Code | HTTP Status | gRPC Code | Description | User Message | Recovery Action |
|------------|-------------|-----------|-------------|--------------|-----------------|
| TIMELINE_INFRA_REDIS_CONNECTION | 503 | UNAVAILABLE | Redis接続エラー | キャッシュサービスに接続できません | 接続を再試行 |
| TIMELINE_INFRA_REDIS_TIMEOUT | 504 | DEADLINE_EXCEEDED | Redisタイムアウト | キャッシュ操作がタイムアウトしました | 直接DBアクセス |
| TIMELINE_INFRA_REDIS_COMMAND_FAILED | 500 | INTERNAL | Redisコマンド実行失敗 | キャッシュ操作に失敗しました | コマンドを再実行 |
| TIMELINE_INFRA_DATABASE_CONNECTION | 503 | UNAVAILABLE | データベース接続エラー | データベースに接続できません | 接続を再試行 |
| TIMELINE_INFRA_DATABASE_TIMEOUT | 504 | DEADLINE_EXCEEDED | データベースタイムアウト | データベース操作がタイムアウトしました | クエリを最適化 |
| TIMELINE_INFRA_QUERY_FAILED | 500 | INTERNAL | クエリ実行失敗 | データベース操作に失敗しました | クエリを再実行 |
| TIMELINE_INFRA_TRANSACTION_FAILED | 500 | ABORTED | トランザクション失敗 | トランザクション処理に失敗しました | トランザクションを再試行 |
| TIMELINE_INFRA_CACHE_CORRUPTED | 500 | DATA_LOSS | キャッシュデータ破損 | キャッシュデータが破損しています | キャッシュをクリア |
| TIMELINE_INFRA_SSE_CONNECTION_LOST | 500 | UNAVAILABLE | SSE接続喪失 | リアルタイム接続が失われました | 再接続を実行 |
| TIMELINE_INFRA_SSE_BUFFER_OVERFLOW | 503 | RESOURCE_EXHAUSTED | SSEバッファオーバーフロー | イベントバッファが満杯です | バッファをクリア |
| TIMELINE_INFRA_EXTERNAL_TIMEOUT | 504 | DEADLINE_EXCEEDED | 外部サービスタイムアウト | 外部サービスからの応答がありません | フォールバック処理 |
| TIMELINE_INFRA_EXTERNAL_ERROR | 502 | UNAVAILABLE | 外部サービスエラー | 外部サービスでエラーが発生しました | リトライまたはフォールバック |
| TIMELINE_INFRA_SERIALIZATION_FAILED | 500 | INTERNAL | シリアライズ失敗 | データの変換に失敗しました | データ形式を確認 |
| TIMELINE_INFRA_DESERIALIZATION_FAILED | 500 | INTERNAL | デシリアライズ失敗 | データの復元に失敗しました | データ形式を確認 |
| TIMELINE_INFRA_PUBSUB_FAILED | 500 | INTERNAL | Pub/Sub失敗 | イベント配信に失敗しました | 配信を再試行 |

## Error Response Format

### gRPC Error Response

```protobuf
message ErrorResponse {
    string code = 1;           // e.g., "TIMELINE_DOMAIN_NOT_FOUND"
    string message = 2;        // User-friendly message
    string details = 3;        // Technical details (optional)
    string trace_id = 4;       // Trace ID for debugging
    google.protobuf.Timestamp timestamp = 5;
    map<string, string> metadata = 6;  // Additional context
}
```

### HTTP Error Response

```json
{
    "error": {
        "code": "TIMELINE_DOMAIN_NOT_FOUND",
        "message": "タイムラインが見つかりません",
        "details": "Timeline with ID 'user123:HOME' not found in cache or database",
        "trace_id": "550e8400-e29b-41d4-a716-446655440000",
        "timestamp": "2024-01-01T00:00:00Z",
        "metadata": {
            "timeline_id": "user123:HOME",
            "user_id": "user123",
            "timeline_type": "HOME"
        }
    }
}
```

### SSE Error Event

```
event: error
data: {"code":"TIMELINE_INFRA_SSE_CONNECTION_LOST","message":"接続が失われました","action":"reconnect","retry":3000}
```

## Error Handling Best Practices

### 1. ログ記録

```go
logger.Error("timeline operation failed",
    slog.String("error_code", "TIMELINE_DOMAIN_NOT_FOUND"),
    slog.String("timeline_id", timelineID),
    slog.String("trace_id", traceID),
    slog.Error(err),
)
```

### 2. エラーラッピング

```go
if err != nil {
    return fmt.Errorf("TIMELINE_USECASE_REBUILD_FAILED: %w", err)
}
```

### 3. リトライ戦略

| Error Category | Retry Strategy | Max Attempts | Backoff |
|---------------|----------------|--------------|---------|
| Connection Errors | Exponential | 3 | 1s, 2s, 4s |
| Timeout Errors | Linear | 2 | 1s |
| Rate Limit | Exponential | 5 | Based on Retry-After |
| Concurrent Update | Immediate | 3 | 100ms jitter |
| External Service | Exponential | 3 | 500ms, 1s, 2s |

### 4. フォールバック処理

```go
func getTimeline(ctx context.Context, id string) (*Timeline, error) {
    // Try cache first
    timeline, err := cache.Get(ctx, id)
    if err != nil {
        log.Warn("cache miss, falling back to database")
        // Fallback to database
        timeline, err = db.Get(ctx, id)
        if err != nil {
            // Final fallback to empty timeline
            return NewEmptyTimeline(id), nil
        }
    }
    return timeline, nil
}
```

## Circuit Breaker Configuration

| Service | Threshold | Timeout | Half-Open Requests |
|---------|-----------|---------|-------------------|
| Redis | 5 failures | 30s | 1 |
| PostgreSQL | 3 failures | 60s | 1 |
| avion-drop | 10 failures | 30s | 3 |
| avion-user | 10 failures | 30s | 3 |
| avion-search | 15 failures | 45s | 2 |

## Monitoring and Alerting

### Error Rate Alerts

```yaml
- alert: HighErrorRate
  expr: rate(timeline_errors_total[5m]) > 0.01
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "High error rate detected"
    description: "Error rate is {{ $value }} errors per second"

- alert: CriticalErrorRate
  expr: rate(timeline_errors_total{code=~"TIMELINE_INFRA_.*"}[5m]) > 0.001
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "Critical infrastructure errors"
    description: "Infrastructure error rate is {{ $value }} errors per second"
```

### Error Metrics

```prometheus
# Error counter by code
timeline_errors_total{code="TIMELINE_DOMAIN_NOT_FOUND", layer="domain"} 42

# Error histogram by handler
timeline_error_duration_seconds{handler="GetHomeTimeline", quantile="0.99"} 0.05

# Circuit breaker state
timeline_circuit_breaker_state{service="redis", state="open"} 1
```

## Recovery Procedures

### 1. Cache Corruption Recovery

```bash
# 1. Identify corrupted keys
redis-cli --scan --pattern "timeline:*" | xargs -L 1 redis-cli ttl | grep -1

# 2. Clear corrupted cache
redis-cli FLUSHDB

# 3. Warm up cache
curl -X POST http://timeline-service/admin/cache/warmup

# 4. Verify
curl http://timeline-service/health/cache
```

### 2. Database Connection Recovery

```sql
-- Check connection pool status
SELECT state, count(*) 
FROM pg_stat_activity 
WHERE application_name = 'avion-timeline'
GROUP BY state;

-- Kill idle connections
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE state = 'idle' 
  AND state_change < NOW() - INTERVAL '10 minutes';
```

### 3. SSE Connection Recovery

```go
// Client-side reconnection logic
func reconnectSSE(url string, lastEventID string) {
    backoff := 1 * time.Second
    for attempts := 0; attempts < 5; attempts++ {
        conn, err := connectSSE(url, lastEventID)
        if err == nil {
            return conn
        }
        time.Sleep(backoff)
        backoff *= 2
    }
}
```

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-01-19 | Complete error catalog with DDD compliance |
| 0.9.0 | 2025-01-15 | Initial draft |

## Related Documents

- [Design Doc: avion-timeline](./designdoc.md)
- [PRD: avion-timeline](./prd.md)
- [Common Error Standards](../common/errors/error-standards.md)
- [Error Implementation Guide](../common/errors/implementation-guide.md)