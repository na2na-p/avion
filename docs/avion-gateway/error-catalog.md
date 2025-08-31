# エラーカタログ: avion-gateway

**Last Updated:** 2025/08/19  
**Service:** API Gateway Service

## 概要

avion-gatewayサービスで発生する可能性のあるエラーコード一覧とその対処法です。

## ドメイン層エラー

### Route関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| GATEWAY_DOMAIN_ROUTE_NOT_FOUND | 404 | NOT_FOUND | ルートが見つかりません | ルート設定を確認してください |
| GATEWAY_DOMAIN_ROUTE_ALREADY_EXISTS | 409 | ALREADY_EXISTS | ルートが既に存在します | 既存のルートを確認してください |
| GATEWAY_DOMAIN_INVALID_ROUTE_PATTERN | 400 | INVALID_ARGUMENT | ルートパターンが不正です | ルートパターンを修正してください |
| GATEWAY_DOMAIN_CIRCULAR_ROUTE | 400 | INVALID_ARGUMENT | 循環ルートが検出されました | ルート設定を見直してください |

### CircuitBreaker関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| GATEWAY_DOMAIN_CIRCUIT_BREAKER_OPEN | 503 | UNAVAILABLE | サーキットブレーカーが開いています | バックエンドサービスの復旧を待ってください |
| GATEWAY_DOMAIN_CIRCUIT_BREAKER_HALF_OPEN | 503 | UNAVAILABLE | サーキットブレーカーがハーフオープン状態です | 少し待ってから再試行してください |
| GATEWAY_DOMAIN_CIRCUIT_BREAKER_CONFIG_INVALID | 400 | INVALID_ARGUMENT | サーキットブレーカー設定が不正です | 設定を確認してください |

### LoadBalancer関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| GATEWAY_DOMAIN_NO_HEALTHY_BACKENDS | 503 | UNAVAILABLE | 正常なバックエンドがありません | バックエンドサービスの状態を確認してください |
| GATEWAY_DOMAIN_LOAD_BALANCER_CONFIG_INVALID | 400 | INVALID_ARGUMENT | ロードバランサー設定が不正です | 設定を確認してください |
| GATEWAY_DOMAIN_BACKEND_OVERLOADED | 503 | UNAVAILABLE | バックエンドが過負荷状態です | 負荷分散設定を見直してください |

### GraphQLSchema関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| GATEWAY_DOMAIN_SCHEMA_NOT_FOUND | 404 | NOT_FOUND | GraphQLスキーマが見つかりません | スキーマファイルを確認してください |
| GATEWAY_DOMAIN_SCHEMA_INVALID | 400 | INVALID_ARGUMENT | GraphQLスキーマが不正です | スキーマ構文を確認してください |
| GATEWAY_DOMAIN_SCHEMA_CONFLICT | 409 | ABORTED | スキーマの競合が発生しました | スキーマバージョニングを確認してください |
| GATEWAY_DOMAIN_RESOLVER_NOT_FOUND | 404 | NOT_FOUND | リゾルバーが見つかりません | リゾルバー実装を確認してください |

## ユースケース層エラー

### 入力検証エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| GATEWAY_USECASE_INVALID_INPUT | 400 | INVALID_ARGUMENT | 入力値が不正です | 入力値を確認してください |
| GATEWAY_USECASE_MISSING_REQUIRED | 400 | INVALID_ARGUMENT | 必須項目が不足しています | 必須項目を入力してください |
| GATEWAY_USECASE_INVALID_GRAPHQL_QUERY | 400 | INVALID_ARGUMENT | GraphQLクエリが不正です | クエリ構文を確認してください |
| GATEWAY_USECASE_QUERY_TOO_COMPLEX | 400 | INVALID_ARGUMENT | クエリが複雑すぎます | クエリを簡略化してください |

### 認証・認可エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| GATEWAY_USECASE_UNAUTHORIZED | 401 | UNAUTHENTICATED | 認証が必要です | 認証トークンを確認してください |
| GATEWAY_USECASE_FORBIDDEN | 403 | PERMISSION_DENIED | アクセスが禁止されています | アクセス権限を確認してください |
| GATEWAY_USECASE_TOKEN_EXPIRED | 401 | UNAUTHENTICATED | トークンが期限切れです | トークンを更新してください |
| GATEWAY_USECASE_INVALID_TOKEN | 401 | UNAUTHENTICATED | トークンが不正です | 有効なトークンを使用してください |

### レート制限エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| GATEWAY_USECASE_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |
| GATEWAY_USECASE_QUOTA_EXCEEDED | 429 | RESOURCE_EXHAUSTED | クォータを超過しました | 制限がリセットされるまで待ってください |
| GATEWAY_USECASE_CONCURRENT_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | 同時実行制限を超過しました | 実行中のリクエストが完了するまで待ってください |

### プロキシエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| GATEWAY_USECASE_BACKEND_UNAVAILABLE | 503 | UNAVAILABLE | バックエンドサービスが利用できません | サービス状態を確認してください |
| GATEWAY_USECASE_TIMEOUT | 504 | DEADLINE_EXCEEDED | タイムアウトが発生しました | タイムアウト設定を確認してください |
| GATEWAY_USECASE_UPSTREAM_ERROR | 502 | INTERNAL | アップストリームエラー | バックエンドサービスのログを確認してください |

## インフラストラクチャ層エラー

### データベースエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| GATEWAY_INFRA_DATABASE_CONNECTION_FAILED | 503 | UNAVAILABLE | データベース接続失敗 | 接続設定を確認してください |
| GATEWAY_INFRA_DATABASE_QUERY_FAILED | 500 | INTERNAL | クエリ実行失敗 | クエリを確認してください |
| GATEWAY_INFRA_DATABASE_TRANSACTION_FAILED | 500 | INTERNAL | トランザクション失敗 | 再試行してください |

### キャッシュエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| GATEWAY_INFRA_CACHE_CONNECTION_FAILED | 503 | UNAVAILABLE | キャッシュ接続失敗 | 接続設定を確認してください |
| GATEWAY_INFRA_CACHE_OPERATION_FAILED | 500 | INTERNAL | キャッシュ操作失敗 | 再試行してください |
| GATEWAY_INFRA_CACHE_INVALIDATION_FAILED | 500 | INTERNAL | キャッシュ無効化失敗 | キャッシュシステムを確認してください |

### 外部サービスエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| GATEWAY_INFRA_EXTERNAL_SERVICE_ERROR | 502 | INTERNAL | 外部サービスエラー | サービス状態を確認してください |
| GATEWAY_INFRA_EXTERNAL_SERVICE_TIMEOUT | 504 | DEADLINE_EXCEEDED | 外部サービスタイムアウト | 時間をおいて再試行してください |
| GATEWAY_INFRA_EXTERNAL_SERVICE_UNAVAILABLE | 503 | UNAVAILABLE | 外部サービス利用不可 | サービス復旧を待ってください |

### メトリクス・モニタリングエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| GATEWAY_INFRA_METRICS_COLLECTION_FAILED | 500 | INTERNAL | メトリクス収集失敗 | メトリクスシステムを確認してください |
| GATEWAY_INFRA_TRACING_FAILED | 500 | INTERNAL | トレーシング失敗 | トレーシングシステムを確認してください |
| GATEWAY_INFRA_HEALTH_CHECK_FAILED | 503 | UNAVAILABLE | ヘルスチェック失敗 | サービス状態を確認してください |

### ネットワークエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| GATEWAY_INFRA_NETWORK_TIMEOUT | 504 | DEADLINE_EXCEEDED | ネットワークタイムアウト | ネットワーク接続を確認してください |
| GATEWAY_INFRA_NETWORK_CONNECTION_REFUSED | 503 | UNAVAILABLE | 接続拒否 | 対象サービスの状態を確認してください |
| GATEWAY_INFRA_DNS_RESOLUTION_FAILED | 502 | INTERNAL | DNS解決失敗 | DNS設定を確認してください |

## ハンドラー層エラー

### HTTP関連エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| GATEWAY_HANDLER_BAD_REQUEST | 400 | INVALID_ARGUMENT | 不正なリクエスト | リクエスト形式を確認してください |
| GATEWAY_HANDLER_PAYLOAD_TOO_LARGE | 413 | INVALID_ARGUMENT | ペイロードサイズ超過 | リクエストサイズを小さくしてください |
| GATEWAY_HANDLER_UNSUPPORTED_MEDIA_TYPE | 415 | INVALID_ARGUMENT | サポートされないメディアタイプ | Content-Typeを確認してください |
| GATEWAY_HANDLER_METHOD_NOT_ALLOWED | 405 | INVALID_ARGUMENT | 許可されないHTTPメソッド | HTTPメソッドを確認してください |

### GraphQL関連エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| GATEWAY_HANDLER_GRAPHQL_PARSE_ERROR | 400 | INVALID_ARGUMENT | GraphQL解析エラー | クエリ構文を確認してください |
| GATEWAY_HANDLER_GRAPHQL_VALIDATION_ERROR | 400 | INVALID_ARGUMENT | GraphQLバリデーションエラー | スキーマに対するクエリを確認してください |
| GATEWAY_HANDLER_GRAPHQL_EXECUTION_ERROR | 500 | INTERNAL | GraphQL実行エラー | クエリ実行結果を確認してください |

### WebSocket関連エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| GATEWAY_HANDLER_WEBSOCKET_UPGRADE_FAILED | 400 | INVALID_ARGUMENT | WebSocketアップグレード失敗 | WebSocketヘッダーを確認してください |
| GATEWAY_HANDLER_WEBSOCKET_CONNECTION_FAILED | 500 | INTERNAL | WebSocket接続失敗 | ネットワーク状態を確認してください |
| GATEWAY_HANDLER_WEBSOCKET_MESSAGE_TOO_LARGE | 413 | INVALID_ARGUMENT | WebSocketメッセージサイズ超過 | メッセージサイズを小さくしてください |

## 関連ドキュメント

- [Avion エラーコード標準化ガイドライン](../common/errors/error-standards.md)
- [avion-gateway PRD](./prd.md)
- [avion-gateway Design Doc](./designdoc.md)