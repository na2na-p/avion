# エラーカタログ: avion-timeline

**Last Updated:** 2026/03/15
**Service:** Timeline Service
**Version:** 1.2.0

## 概要

avion-timelineサービスで発生する可能性のあるエラーコード一覧とその対処法です。

## エラーコード形式

すべてのエラーコードは以下の形式に従います:

```
TIMELINE_[LAYER]_[ERROR_TYPE]
```

- **TIMELINE**: サービス識別子
- **LAYER**: エラー発生層 (DOMAIN | USECASE | HANDLER | INFRA)
- **ERROR_TYPE**: 具体的なエラー種別

## ドメイン層エラー

### Timeline関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| TIMELINE_DOMAIN_NOT_FOUND | 404 | NOT_FOUND | タイムラインが見つかりません | 再構築を試みてください |
| TIMELINE_DOMAIN_EXPIRED | 410 | FAILED_PRECONDITION | タイムラインキャッシュが期限切れです | キャッシュを再生成してください |
| TIMELINE_DOMAIN_MAX_ENTRIES_EXCEEDED | 413 | RESOURCE_EXHAUSTED | タイムラインエントリー数が上限を超過しました | 古いエントリーを削除してください |
| TIMELINE_DOMAIN_INVALID_CURSOR | 400 | INVALID_ARGUMENT | 無効なカーソル値です | 最初から取得し直してください |
| TIMELINE_DOMAIN_INVALID_TYPE | 400 | INVALID_ARGUMENT | 無効なタイムラインタイプです | 有効な値を指定してください |
| TIMELINE_DOMAIN_DUPLICATE_ENTRY | 409 | ALREADY_EXISTS | 重複したタイムラインエントリーです | 既存エントリーを使用してください |
| TIMELINE_DOMAIN_INVALID_FILTER | 400 | INVALID_ARGUMENT | 無効なフィルター条件です | 有効な条件を指定してください |
| TIMELINE_DOMAIN_ENTRY_TOO_OLD | 410 | OUT_OF_RANGE | エントリーが古すぎます | 新しい投稿を取得してください |

### List関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| TIMELINE_DOMAIN_MAX_LISTS_EXCEEDED | 413 | RESOURCE_EXHAUSTED | リスト作成数が上限（100個）を超過しました | 既存リストを削除してください |
| TIMELINE_DOMAIN_MAX_MEMBERS_EXCEEDED | 413 | RESOURCE_EXHAUSTED | リストメンバー数が上限（500人）を超過しました | メンバーを削除してください |
| TIMELINE_DOMAIN_LIST_NOT_FOUND | 404 | NOT_FOUND | リストが見つかりません | リストIDを確認してください |
| TIMELINE_DOMAIN_ACCESS_DENIED | 403 | PERMISSION_DENIED | リストへのアクセスが拒否されました | 権限を確認してください |
| TIMELINE_DOMAIN_DUPLICATE_MEMBER | 409 | ALREADY_EXISTS | メンバーは既に追加されています | 既存メンバーを使用してください |
| TIMELINE_DOMAIN_MEMBER_NOT_FOUND | 404 | NOT_FOUND | リストメンバーが見つかりません | メンバーIDを確認してください |
| TIMELINE_DOMAIN_INVALID_VISIBILITY | 400 | INVALID_ARGUMENT | 無効な可視性設定です | 有効な値（PUBLIC/PRIVATE/UNLISTED）を指定してください |

## ユースケース層エラー

### Fan-out関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| TIMELINE_USECASE_FANOUT_TIMEOUT | 504 | DEADLINE_EXCEEDED | Fan-out処理がタイムアウトしました | リトライまたはPull型に切り替えてください |
| TIMELINE_USECASE_INVALID_STRATEGY | 500 | INTERNAL | 無効なFan-out戦略です | デフォルト戦略を使用してください |
| TIMELINE_USECASE_BATCH_PROCESSING_FAILED | 500 | INTERNAL | バッチ処理に失敗しました | 個別処理に切り替えてください |

### タイムライン操作関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| TIMELINE_USECASE_INVALID_TYPE | 400 | INVALID_ARGUMENT | 無効なタイムラインタイプ指定です | 有効なタイプを指定してください |
| TIMELINE_USECASE_CONCURRENT_UPDATE | 409 | ABORTED | 同時更新による競合が発生しました | リトライを実行してください |
| TIMELINE_USECASE_EVENT_PROCESSING_FAILED | 500 | INTERNAL | イベント処理に失敗しました | イベントを再送信してください |
| TIMELINE_USECASE_REBUILD_FAILED | 500 | INTERNAL | タイムライン再構築に失敗しました | 手動で再構築してください |
| TIMELINE_USECASE_CACHE_UPDATE_FAILED | 500 | DATA_LOSS | キャッシュ更新に失敗しました | キャッシュをクリアしてください |
| TIMELINE_USECASE_LIST_OPERATION_FAILED | 500 | INTERNAL | リスト操作に失敗しました | 操作を再試行してください |
| TIMELINE_USECASE_MERGE_CONFLICT | 409 | ABORTED | タイムラインマージに失敗しました | マージを再試行してください |
| TIMELINE_USECASE_POLICY_VIOLATION | 403 | PERMISSION_DENIED | ポリシー違反により操作が拒否されました | ポリシーを確認してください |

### SSE関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| TIMELINE_USECASE_SSE_SUBSCRIBE_FAILED | 500 | INTERNAL | リアルタイム更新の購読に失敗しました | 再接続を試行してください |

### フィルタリング関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| TIMELINE_USECASE_PRIVACY_CHECK_FAILED | 500 | INTERNAL | プライバシー設定の取得に失敗しました（avion-user連携エラー） | 時間をおいて再試行してください |
| TIMELINE_USECASE_MODERATION_CHECK_FAILED | 500 | INTERNAL | モデレーション判定の取得に失敗しました（avion-moderation連携エラー） | 時間をおいて再試行してください |

## ハンドラー層エラー

### リクエスト検証関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| TIMELINE_HANDLER_INVALID_REQUEST | 400 | INVALID_ARGUMENT | 不正なリクエスト形式です | リクエストを修正してください |
| TIMELINE_HANDLER_VALIDATION_FAILED | 400 | INVALID_ARGUMENT | 入力値が不正です | 入力値を修正してください |
| TIMELINE_HANDLER_METHOD_NOT_ALLOWED | 405 | UNIMPLEMENTED | 許可されていないメソッドです | 別のメソッドを使用してください |
| TIMELINE_HANDLER_CONTENT_TYPE_ERROR | 415 | INVALID_ARGUMENT | サポートされていないコンテンツタイプです | 正しいContent-Typeを指定してください |

### 認証・認可関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| TIMELINE_HANDLER_UNAUTHORIZED | 401 | UNAUTHENTICATED | 認証が必要です | ログインし直してください |
| TIMELINE_HANDLER_FORBIDDEN | 403 | PERMISSION_DENIED | この操作を実行する権限がありません | 権限を確認してください |
| TIMELINE_HANDLER_RATE_LIMITED | 429 | RESOURCE_EXHAUSTED | リクエスト数が上限を超えました | 時間をおいて再試行してください |
| TIMELINE_HANDLER_CONTEXT_EXTRACTION_FAILED | 500 | INTERNAL | ユーザー情報の取得に失敗しました | 再認証してください |

### SSE関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| TIMELINE_HANDLER_SSE_INIT_FAILED | 500 | INTERNAL | リアルタイム接続の初期化に失敗しました | 再接続を試行してください |
| TIMELINE_HANDLER_SSE_WRITE_FAILED | 500 | INTERNAL | イベントの送信に失敗しました | 接続を確認してください |
| TIMELINE_HANDLER_RESPONSE_ENCODING_FAILED | 500 | INTERNAL | レスポンスの生成に失敗しました | 再試行してください |
| TIMELINE_HANDLER_TIMEOUT | 504 | DEADLINE_EXCEEDED | リクエストがタイムアウトしました | 再試行してください |

## インフラストラクチャ層エラー

### Redis関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| TIMELINE_INFRA_REDIS_CONNECTION | 503 | UNAVAILABLE | Redisへの接続に失敗しました | 接続を再試行してください |
| TIMELINE_INFRA_REDIS_TIMEOUT | 504 | DEADLINE_EXCEEDED | Redis操作がタイムアウトしました | 直接DBアクセスに切り替えてください |
| TIMELINE_INFRA_REDIS_COMMAND_FAILED | 500 | INTERNAL | Redisコマンド実行に失敗しました | コマンドを再実行してください |
| TIMELINE_INFRA_CACHE_CORRUPTED | 500 | DATA_LOSS | キャッシュデータが破損しています | キャッシュをクリアしてください |

### データベース関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| TIMELINE_INFRA_DATABASE_CONNECTION | 503 | UNAVAILABLE | データベース接続に失敗しました | 接続を再試行してください |
| TIMELINE_INFRA_DATABASE_TIMEOUT | 504 | DEADLINE_EXCEEDED | データベース操作がタイムアウトしました | クエリを最適化してください |
| TIMELINE_INFRA_QUERY_FAILED | 500 | INTERNAL | クエリ実行に失敗しました | クエリを再実行してください |
| TIMELINE_INFRA_TRANSACTION_FAILED | 500 | ABORTED | トランザクション処理に失敗しました | トランザクションを再試行してください |

### SSE関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| TIMELINE_INFRA_SSE_CONNECTION_LOST | 500 | UNAVAILABLE | リアルタイム接続が失われました | 再接続を実行してください |
| TIMELINE_INFRA_SSE_BUFFER_OVERFLOW | 503 | RESOURCE_EXHAUSTED | イベントバッファが満杯です | バッファをクリアしてください |
| TIMELINE_INFRA_SSE_ORDER_VIOLATION | 500 | INTERNAL | SSEイベントの順序保証に失敗しました | イベントキューの状態を確認し、再接続を実行してください |
| TIMELINE_INFRA_SSE_RECONNECT_FAILED | 500 | INTERNAL | Last-Event-IDによる再接続処理に失敗しました | 新規接続を確立し、タイムラインを再取得してください |

### 外部サービス関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| TIMELINE_INFRA_EXTERNAL_TIMEOUT | 504 | DEADLINE_EXCEEDED | 外部サービスからの応答がありません | フォールバック処理を実行してください |
| TIMELINE_INFRA_EXTERNAL_ERROR | 502 | UNAVAILABLE | 外部サービスでエラーが発生しました | リトライまたはフォールバックしてください |
| TIMELINE_INFRA_PUBSUB_FAILED | 500 | INTERNAL | イベント配信に失敗しました | 配信を再試行してください |

### シリアライズ関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| TIMELINE_INFRA_SERIALIZATION_FAILED | 500 | INTERNAL | データの変換に失敗しました | データ形式を確認してください |
| TIMELINE_INFRA_DESERIALIZATION_FAILED | 500 | INTERNAL | データの復元に失敗しました | データ形式を確認してください |

## エラーレスポンス形式

### gRPCエラーレスポンス

```protobuf
message ErrorResponse {
    string code = 1;           // 例: "TIMELINE_DOMAIN_NOT_FOUND"
    string message = 2;        // ユーザー向けメッセージ
    string details = 3;        // 技術詳細（オプショナル）
    string trace_id = 4;       // デバッグ用トレースID
    google.protobuf.Timestamp timestamp = 5;
    map<string, string> metadata = 6;  // 追加コンテキスト
}
```

### HTTPエラーレスポンス

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

### SSEエラーイベント

```
event: error
data: {"code":"TIMELINE_INFRA_SSE_CONNECTION_LOST","message":"接続が失われました","action":"reconnect","retry":3000}
```

## エラーハンドリングベストプラクティス

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

| エラーカテゴリ | リトライ戦略 | 最大試行回数 | バックオフ |
|--------------|------------|------------|---------|
| 接続エラー | 指数バックオフ | 3 | 1s, 2s, 4s |
| タイムアウトエラー | 線形バックオフ | 2 | 1s |
| レート制限 | 指数バックオフ | 5 | Retry-Afterヘッダーに基づく |
| 同時更新 | 即時リトライ | 3 | 100msジッター |
| 外部サービスエラー | 指数バックオフ | 3 | 500ms, 1s, 2s |

### 4. フォールバック処理

```go
func getTimeline(ctx context.Context, id string) (*Timeline, error) {
    // キャッシュから取得を試行
    timeline, err := cache.Get(ctx, id)
    if err != nil {
        log.Warn("cache miss, falling back to database")
        // データベースにフォールバック
        timeline, err = db.Get(ctx, id)
        if err != nil {
            // 最終フォールバック: 空のタイムラインを返却
            return NewEmptyTimeline(id), nil
        }
    }
    return timeline, nil
}
```

## サーキットブレーカー設定

| サービス | 閾値 | タイムアウト | ハーフオープンリクエスト数 |
|---------|------|-----------|----------------------|
| Redis | 5回失敗 | 30秒 | 1 |
| PostgreSQL | 3回失敗 | 60秒 | 1 |
| avion-drop | 10回失敗 | 30秒 | 3 |
| avion-user | 10回失敗 | 30秒 | 3 |
| avion-search | 15回失敗 | 45秒 | 2 |
| avion-moderation | 10回失敗 | 30秒 | 3 |

## 監視とアラート

### エラーレートアラート

```yaml
- alert: HighErrorRate
  expr: rate(timeline_errors_total[5m]) > 0.01
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "高いエラーレートを検出"
    description: "エラーレートは {{ $value }} errors/秒 です"

- alert: CriticalErrorRate
  expr: rate(timeline_errors_total{code=~"TIMELINE_INFRA_.*"}[5m]) > 0.001
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "インフラストラクチャの重大エラー"
    description: "インフラエラーレートは {{ $value }} errors/秒 です"
```

### エラーメトリクス

```prometheus
# エラーコード別カウンター
timeline_errors_total{code="TIMELINE_DOMAIN_NOT_FOUND", layer="domain"} 42

# ハンドラー別エラーヒストグラム
timeline_error_duration_seconds{handler="GetHomeTimeline", quantile="0.99"} 0.05

# サーキットブレーカー状態
timeline_circuit_breaker_state{service="redis", state="open"} 1
```

## リカバリ手順

### 1. キャッシュ破損時のリカバリ

```bash
# 1. 破損キーの特定
redis-cli --scan --pattern "timeline:*" | xargs -L 1 redis-cli ttl | grep -1

# 2. 破損キャッシュのクリア
redis-cli FLUSHDB

# 3. キャッシュのウォームアップ
curl -X POST http://timeline-service/admin/cache/warmup

# 4. 検証
curl http://timeline-service/health/cache
```

### 2. データベース接続リカバリ

```sql
-- コネクションプール状態の確認
SELECT state, count(*)
FROM pg_stat_activity
WHERE application_name = 'avion-timeline'
GROUP BY state;

-- アイドル接続の切断
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle'
  AND state_change < NOW() - INTERVAL '10 minutes';
```

### 3. SSE接続リカバリ

```go
// クライアント側の再接続ロジック
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

## バージョン履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|---------|
| 1.2.0 | 2026-03-15 | SSEイベント順序保証・再接続処理関連エラー追加 |
| 1.1.0 | 2026-03-15 | 日本語ヘッダー統一、フィルタリング関連エラー追加、フォーマット標準化 |
| 1.0.0 | 2025-01-19 | DDD準拠の完全なエラーカタログ |
| 0.9.0 | 2025-01-15 | 初版 |

## 関連ドキュメント

- [Design Doc: avion-timeline](./designdoc.md)
- [PRD: avion-timeline](./prd.md)
- [Avion エラーコード標準化ガイドライン](../common/errors/error-standards.md)
