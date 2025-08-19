# エラーカタログ: avion-notification

**Last Updated:** 2025/08/19  
**Service:** Push Notifications and SSE Event Delivery Service

## 概要

avion-notificationサービスで発生する可能性のあるエラーコード一覧とその対処法です。

## ドメイン層エラー

### Notification関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| NOTIFICATION_DOMAIN_NOTIFICATION_NOT_FOUND | 404 | NOT_FOUND | 通知が見つかりません | 通知IDを確認してください |
| NOTIFICATION_DOMAIN_NOTIFICATION_EXPIRED | 410 | NOT_FOUND | 通知が期限切れです | 新しい通知を確認してください |
| NOTIFICATION_DOMAIN_INVALID_NOTIFICATION_TYPE | 400 | INVALID_ARGUMENT | 通知タイプが不正です | 対応する通知タイプを使用してください |
| NOTIFICATION_DOMAIN_NOTIFICATION_ALREADY_READ | 409 | ALREADY_EXISTS | 通知は既に既読です | 通知状態を確認してください |
| NOTIFICATION_DOMAIN_NOTIFICATION_ALREADY_DELETED | 410 | NOT_FOUND | 通知は既に削除されています | 削除済み通知にはアクセスできません |

### NotificationTemplate関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| NOTIFICATION_DOMAIN_TEMPLATE_NOT_FOUND | 404 | NOT_FOUND | 通知テンプレートが見つかりません | テンプレートIDを確認してください |
| NOTIFICATION_DOMAIN_INVALID_TEMPLATE | 400 | INVALID_ARGUMENT | 通知テンプレートが不正です | テンプレート形式を確認してください |
| NOTIFICATION_DOMAIN_TEMPLATE_COMPILATION_FAILED | 422 | INTERNAL | テンプレートコンパイルに失敗しました | テンプレート構文を確認してください |
| NOTIFICATION_DOMAIN_TEMPLATE_VARIABLE_MISSING | 400 | INVALID_ARGUMENT | テンプレート変数が不足しています | 必要な変数を確認してください |

### DeviceToken関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| NOTIFICATION_DOMAIN_DEVICE_TOKEN_NOT_FOUND | 404 | NOT_FOUND | デバイストークンが見つかりません | トークンを確認してください |
| NOTIFICATION_DOMAIN_INVALID_DEVICE_TOKEN | 400 | INVALID_ARGUMENT | デバイストークンが不正です | トークン形式を確認してください |
| NOTIFICATION_DOMAIN_DEVICE_TOKEN_EXPIRED | 410 | NOT_FOUND | デバイストークンが期限切れです | 新しいトークンを登録してください |
| NOTIFICATION_DOMAIN_DEVICE_TOKEN_REVOKED | 410 | NOT_FOUND | デバイストークンが無効化されています | 新しいトークンを登録してください |
| NOTIFICATION_DOMAIN_DUPLICATE_DEVICE_TOKEN | 409 | ALREADY_EXISTS | 重複したデバイストークンです | 既存のトークンを確認してください |

### UserPreference関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| NOTIFICATION_DOMAIN_PREFERENCE_NOT_FOUND | 404 | NOT_FOUND | 通知設定が見つかりません | 設定を確認してください |
| NOTIFICATION_DOMAIN_INVALID_PREFERENCE | 400 | INVALID_ARGUMENT | 通知設定が不正です | 設定値を確認してください |
| NOTIFICATION_DOMAIN_PREFERENCE_DISABLED | 403 | PERMISSION_DENIED | 通知設定が無効です | 通知設定を有効にしてください |

### Channel関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| NOTIFICATION_DOMAIN_CHANNEL_NOT_FOUND | 404 | NOT_FOUND | 通知チャンネルが見つかりません | チャンネルIDを確認してください |
| NOTIFICATION_DOMAIN_INVALID_CHANNEL | 400 | INVALID_ARGUMENT | 通知チャンネルが不正です | チャンネル設定を確認してください |
| NOTIFICATION_DOMAIN_CHANNEL_DISABLED | 403 | PERMISSION_DENIED | 通知チャンネルが無効です | チャンネルを有効にしてください |
| NOTIFICATION_DOMAIN_CHANNEL_RATE_LIMITED | 429 | RESOURCE_EXHAUSTED | チャンネルレート制限中です | 制限がリセットされるまで待ってください |

### Event関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| NOTIFICATION_DOMAIN_EVENT_NOT_FOUND | 404 | NOT_FOUND | イベントが見つかりません | イベントIDを確認してください |
| NOTIFICATION_DOMAIN_INVALID_EVENT | 400 | INVALID_ARGUMENT | イベントが不正です | イベント形式を確認してください |
| NOTIFICATION_DOMAIN_EVENT_ALREADY_PROCESSED | 409 | ALREADY_EXISTS | イベントは既に処理済みです | 処理状態を確認してください |
| NOTIFICATION_DOMAIN_EVENT_EXPIRED | 410 | NOT_FOUND | イベントが期限切れです | 新しいイベントを送信してください |

## ユースケース層エラー

### 入力検証エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| NOTIFICATION_USECASE_INVALID_INPUT | 400 | INVALID_ARGUMENT | 入力値が不正です | 入力値を確認してください |
| NOTIFICATION_USECASE_MISSING_REQUIRED | 400 | INVALID_ARGUMENT | 必須項目が不足しています | 必須項目を入力してください |
| NOTIFICATION_USECASE_INVALID_USER_ID | 400 | INVALID_ARGUMENT | ユーザーIDが不正です | ユーザーIDの形式を確認してください |
| NOTIFICATION_USECASE_INVALID_PAYLOAD | 400 | INVALID_ARGUMENT | ペイロードが不正です | ペイロード形式を確認してください |

### 認証・認可エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| NOTIFICATION_USECASE_UNAUTHORIZED | 401 | UNAUTHENTICATED | 認証が必要です | ログインしてください |
| NOTIFICATION_USECASE_FORBIDDEN | 403 | PERMISSION_DENIED | アクセスが禁止されています | アクセス権限を確認してください |
| NOTIFICATION_USECASE_INSUFFICIENT_PERMISSION | 403 | PERMISSION_DENIED | 権限が不足しています | 必要な権限を確認してください |

### ビジネスロジックエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| NOTIFICATION_USECASE_CONFLICT | 409 | ABORTED | リソースの競合が発生しました | 時間をおいて再試行してください |
| NOTIFICATION_USECASE_PRECONDITION_FAILED | 412 | FAILED_PRECONDITION | 事前条件を満たしていません | 事前条件を確認してください |
| NOTIFICATION_USECASE_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |
| NOTIFICATION_USECASE_QUOTA_EXCEEDED | 429 | RESOURCE_EXHAUSTED | 通知クォータを超過しました | 使用量を確認してください |

### 配信エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| NOTIFICATION_USECASE_DELIVERY_FAILED | 502 | INTERNAL | 通知配信に失敗しました | 配信設定を確認してください |
| NOTIFICATION_USECASE_DELIVERY_TIMEOUT | 504 | DEADLINE_EXCEEDED | 通知配信がタイムアウトしました | タイムアウト設定を確認してください |
| NOTIFICATION_USECASE_DELIVERY_REJECTED | 422 | INVALID_ARGUMENT | 通知配信が拒否されました | 配信先を確認してください |
| NOTIFICATION_USECASE_BATCH_DELIVERY_FAILED | 502 | INTERNAL | バッチ配信に失敗しました | バッチ設定を確認してください |

### SSE関連エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| NOTIFICATION_USECASE_SSE_CONNECTION_FAILED | 503 | UNAVAILABLE | SSE接続に失敗しました | 接続設定を確認してください |
| NOTIFICATION_USECASE_SSE_STREAM_CLOSED | 410 | NOT_FOUND | SSEストリームが閉じられています | 新しい接続を確立してください |
| NOTIFICATION_USECASE_SSE_BUFFER_OVERFLOW | 507 | RESOURCE_EXHAUSTED | SSEバッファオーバーフロー | バッファサイズを確認してください |

## インフラストラクチャ層エラー

### データベースエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| NOTIFICATION_INFRA_DATABASE_CONNECTION_FAILED | 503 | UNAVAILABLE | データベース接続失敗 | 接続設定を確認してください |
| NOTIFICATION_INFRA_DATABASE_QUERY_FAILED | 500 | INTERNAL | クエリ実行失敗 | クエリを確認してください |
| NOTIFICATION_INFRA_DATABASE_TRANSACTION_FAILED | 500 | INTERNAL | トランザクション失敗 | 再試行してください |

### キャッシュエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| NOTIFICATION_INFRA_CACHE_CONNECTION_FAILED | 503 | UNAVAILABLE | キャッシュ接続失敗 | 接続設定を確認してください |
| NOTIFICATION_INFRA_CACHE_OPERATION_FAILED | 500 | INTERNAL | キャッシュ操作失敗 | 再試行してください |
| NOTIFICATION_INFRA_CACHE_INVALIDATION_FAILED | 500 | INTERNAL | キャッシュ無効化失敗 | キャッシュシステムを確認してください |

### プッシュサービスエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| NOTIFICATION_INFRA_PUSH_SERVICE_ERROR | 502 | INTERNAL | プッシュサービスエラー | プッシュサービスの状態を確認してください |
| NOTIFICATION_INFRA_APNS_ERROR | 502 | INTERNAL | APNSエラー | APNS設定を確認してください |
| NOTIFICATION_INFRA_FCM_ERROR | 502 | INTERNAL | FCMエラー | FCM設定を確認してください |
| NOTIFICATION_INFRA_WEBPUSH_ERROR | 502 | INTERNAL | WebPushエラー | WebPush設定を確認してください |

### メールサービスエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| NOTIFICATION_INFRA_EMAIL_SERVICE_ERROR | 502 | INTERNAL | メールサービスエラー | メールサービスの状態を確認してください |
| NOTIFICATION_INFRA_EMAIL_SEND_FAILED | 502 | INTERNAL | メール送信失敗 | メール設定を確認してください |
| NOTIFICATION_INFRA_EMAIL_TEMPLATE_ERROR | 500 | INTERNAL | メールテンプレートエラー | テンプレートを確認してください |

### メッセージキューエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| NOTIFICATION_INFRA_QUEUE_CONNECTION_FAILED | 503 | UNAVAILABLE | キュー接続失敗 | 接続設定を確認してください |
| NOTIFICATION_INFRA_QUEUE_PUBLISH_FAILED | 500 | INTERNAL | メッセージ発行失敗 | 再試行してください |
| NOTIFICATION_INFRA_QUEUE_CONSUME_FAILED | 500 | INTERNAL | メッセージ消費失敗 | メッセージ形式を確認してください |
| NOTIFICATION_INFRA_QUEUE_FULL | 503 | UNAVAILABLE | キューが満杯です | しばらく待ってから再試行してください |

### 外部サービスエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| NOTIFICATION_INFRA_USER_SERVICE_ERROR | 502 | INTERNAL | ユーザーサービスエラー | ユーザーサービスの状態を確認してください |
| NOTIFICATION_INFRA_TEMPLATE_SERVICE_ERROR | 502 | INTERNAL | テンプレートサービスエラー | テンプレートサービスの状態を確認してください |
| NOTIFICATION_INFRA_ANALYTICS_SERVICE_ERROR | 502 | INTERNAL | 分析サービスエラー | 分析サービスの状態を確認してください |

### WebSocketエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| NOTIFICATION_INFRA_WEBSOCKET_CONNECTION_FAILED | 503 | UNAVAILABLE | WebSocket接続失敗 | 接続設定を確認してください |
| NOTIFICATION_INFRA_WEBSOCKET_SEND_FAILED | 500 | INTERNAL | WebSocket送信失敗 | 接続状態を確認してください |
| NOTIFICATION_INFRA_WEBSOCKET_UPGRADE_FAILED | 400 | INVALID_ARGUMENT | WebSocketアップグレード失敗 | プロトコル設定を確認してください |

### ハンドラー層エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| NOTIFICATION_HANDLER_BAD_REQUEST | 400 | INVALID_ARGUMENT | 不正なリクエスト | リクエスト形式を確認してください |
| NOTIFICATION_HANDLER_PAYLOAD_TOO_LARGE | 413 | INVALID_ARGUMENT | ペイロードサイズ超過 | リクエストサイズを小さくしてください |
| NOTIFICATION_HANDLER_UNSUPPORTED_MEDIA_TYPE | 415 | INVALID_ARGUMENT | サポートされないメディアタイプ | Content-Typeを確認してください |
| NOTIFICATION_HANDLER_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |
| NOTIFICATION_HANDLER_SSE_NOT_SUPPORTED | 400 | INVALID_ARGUMENT | SSEがサポートされていません | 対応するブラウザを使用してください |

## 関連ドキュメント

- [Avion エラーコード標準化ガイドライン](../common/errors/error-standards.md)
- [avion-notification PRD](./prd.md)
- [avion-notification Design Doc](./designdoc.md)