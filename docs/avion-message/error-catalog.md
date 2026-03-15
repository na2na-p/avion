# エラーカタログ: avion-message

**Last Updated:** 2026/03/15
**Service:** Direct Messaging, Group Chat, E2E Encryption, Real-time Delivery Service

## 概要

avion-messageサービスで発生する可能性のあるエラーコード一覧とその対処法です。
エラーコードは[エラーコード標準化ガイドライン](../common/errors/error-standards.md)に準拠し、`MESSAGE_` プレフィクスを使用します。

## ドメイン層エラー

### Conversation関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_DOMAIN_CONVERSATION_NOT_FOUND | 404 | NOT_FOUND | 会話が見つかりません | 会話IDを確認してください |
| MESSAGE_DOMAIN_CONVERSATION_ALREADY_EXISTS | 409 | ALREADY_EXISTS | 会話が既に存在します | 既存の会話を使用してください |
| MESSAGE_DOMAIN_CONVERSATION_DELETED | 410 | NOT_FOUND | 会話は削除されています | 削除された会話にはアクセスできません |
| MESSAGE_DOMAIN_CONVERSATION_ARCHIVED | 403 | FAILED_PRECONDITION | 会話はアーカイブされています | 会話をアーカイブ解除してください |
| MESSAGE_DOMAIN_INVALID_CONVERSATION_TYPE | 400 | INVALID_ARGUMENT | 会話タイプが不正です | direct または group を指定してください |
| MESSAGE_DOMAIN_DIRECT_CONVERSATION_FULL | 400 | INVALID_ARGUMENT | 1対1会話に参加者を追加できません | グループ会話を作成してください |
| MESSAGE_DOMAIN_CONVERSATION_SETTINGS_INVALID | 400 | INVALID_ARGUMENT | 会話設定が不正です | 設定値を確認してください |

### Message関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_DOMAIN_MESSAGE_NOT_FOUND | 404 | NOT_FOUND | メッセージが見つかりません | メッセージIDを確認してください |
| MESSAGE_DOMAIN_MESSAGE_TOO_LONG | 400 | INVALID_ARGUMENT | メッセージが文字数上限（10,000文字）を超えています | メッセージを短縮してください |
| MESSAGE_DOMAIN_MESSAGE_EDIT_EXPIRED | 403 | FAILED_PRECONDITION | メッセージの編集可能時間（15分）を超過しています | 新しいメッセージとして送信してください |
| MESSAGE_DOMAIN_MESSAGE_ALREADY_DELETED | 410 | NOT_FOUND | メッセージは既に削除されています | 削除済みメッセージにはアクセスできません |
| MESSAGE_DOMAIN_EMPTY_MESSAGE_CONTENT | 400 | INVALID_ARGUMENT | メッセージ内容が空です | テキストまたは添付ファイルを含めてください |
| MESSAGE_DOMAIN_INVALID_MESSAGE_TYPE | 400 | INVALID_ARGUMENT | メッセージタイプが不正です | 対応するメッセージタイプを使用してください |
| MESSAGE_DOMAIN_MESSAGE_SEND_FAILED | 500 | INTERNAL | メッセージ送信に失敗しました | 時間をおいて再試行してください |

### Participant関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_DOMAIN_PARTICIPANT_NOT_FOUND | 404 | NOT_FOUND | 参加者が見つかりません | 参加者IDを確認してください |
| MESSAGE_DOMAIN_ALREADY_PARTICIPANT | 409 | ALREADY_EXISTS | ユーザーは既に会話に参加しています | 参加状態を確認してください |
| MESSAGE_DOMAIN_NOT_PARTICIPANT | 403 | PERMISSION_DENIED | ユーザーはこの会話の参加者ではありません | 会話への参加を確認してください |
| MESSAGE_DOMAIN_PARTICIPANT_LIMIT_EXCEEDED | 400 | INVALID_ARGUMENT | 参加者数が上限（100人）を超えています | 参加者数を減らしてください |
| MESSAGE_DOMAIN_CANNOT_REMOVE_SELF | 400 | INVALID_ARGUMENT | 自分自身を会話から除外できません | 退出機能を使用してください |
| MESSAGE_DOMAIN_INSUFFICIENT_PERMISSION | 403 | PERMISSION_DENIED | この操作に対する権限がありません | 管理者に権限の付与を依頼してください |
| MESSAGE_DOMAIN_LAST_ADMIN | 400 | FAILED_PRECONDITION | 最後の管理者は削除できません | 先に別のメンバーを管理者に昇格してください |

### EncryptionKey関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_DOMAIN_ENCRYPTION_KEY_NOT_FOUND | 404 | NOT_FOUND | 暗号化鍵が見つかりません | 鍵を登録してください |
| MESSAGE_DOMAIN_KEY_EXPIRED | 403 | FAILED_PRECONDITION | 暗号化鍵が期限切れです | 鍵をローテーションしてください |
| MESSAGE_DOMAIN_KEY_REVOKED | 403 | FAILED_PRECONDITION | 暗号化鍵が無効化されています | 新しい鍵を登録してください |
| MESSAGE_DOMAIN_DECRYPTION_FAILED | 422 | INTERNAL | メッセージの復号に失敗しました | 鍵の整合性を確認してください |
| MESSAGE_DOMAIN_KEY_EXCHANGE_FAILED | 500 | INTERNAL | 鍵交換に失敗しました | 時間をおいて再試行してください |
| MESSAGE_DOMAIN_INVALID_KEY_FINGERPRINT | 400 | INVALID_ARGUMENT | 鍵のフィンガープリントが不正です | 鍵の形式を確認してください |
| MESSAGE_DOMAIN_INVALID_PUBLIC_KEY | 400 | INVALID_ARGUMENT | 公開鍵の形式が不正です | PEM形式のRSA 2048bit以上の鍵を使用してください |

### DeliveryStatus関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_DOMAIN_DELIVERY_FAILED | 502 | UNAVAILABLE | メッセージ配信に失敗しました | 時間をおいて再試行してください |
| MESSAGE_DOMAIN_DELIVERY_TIMEOUT | 504 | DEADLINE_EXCEEDED | メッセージ配信がタイムアウトしました | ネットワーク状態を確認してください |
| MESSAGE_DOMAIN_DUPLICATE_DELIVERY | 409 | ALREADY_EXISTS | 重複したメッセージ配信です | 冪等性IDを確認してください |
| MESSAGE_DOMAIN_INVALID_DELIVERY_STATE_TRANSITION | 400 | FAILED_PRECONDITION | 不正な配信状態遷移です | 配信状態の順序（sent->delivered->read）を確認してください |

### MessageRequest関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_DOMAIN_REQUEST_NOT_FOUND | 404 | NOT_FOUND | メッセージリクエストが見つかりません | リクエストIDを確認してください |
| MESSAGE_DOMAIN_REQUEST_ALREADY_HANDLED | 409 | ALREADY_EXISTS | メッセージリクエストは既に処理済みです | リクエスト状態を確認してください |
| MESSAGE_DOMAIN_REQUEST_EXPIRED | 410 | NOT_FOUND | メッセージリクエストが期限切れです | 新しいリクエストを送信してください |
| MESSAGE_DOMAIN_USER_BLOCKED | 403 | PERMISSION_DENIED | ユーザーがブロックされています | ブロック状態を確認してください |

### ScheduledMessage関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_DOMAIN_SCHEDULED_MESSAGE_NOT_FOUND | 404 | NOT_FOUND | スケジュールメッセージが見つかりません | スケジュールメッセージIDを確認してください |
| MESSAGE_DOMAIN_SCHEDULE_IN_PAST | 400 | INVALID_ARGUMENT | 過去の日時にはスケジュールできません | 未来の日時を指定してください |
| MESSAGE_DOMAIN_SCHEDULE_TOO_FAR_AHEAD | 400 | INVALID_ARGUMENT | スケジュール可能期間（30日先まで）を超えています | 30日以内の日時を指定してください |
| MESSAGE_DOMAIN_SCHEDULED_ALREADY_SENT | 409 | FAILED_PRECONDITION | スケジュールメッセージは既に送信済みです | 送信済みメッセージは変更できません |
| MESSAGE_DOMAIN_INVALID_RECURRENCE_RULE | 400 | INVALID_ARGUMENT | 定期送信ルールが不正です | RFC 5545 RRULE形式を確認してください |

### Device関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_DOMAIN_DEVICE_NOT_FOUND | 404 | NOT_FOUND | デバイスが見つかりません | デバイスIDを確認してください |
| MESSAGE_DOMAIN_DEVICE_ALREADY_REGISTERED | 409 | ALREADY_EXISTS | デバイスは既に登録されています | 既存のデバイス情報を確認してください |
| MESSAGE_DOMAIN_DEVICE_REVOKED | 403 | FAILED_PRECONDITION | デバイスは無効化されています | 新しいデバイスを登録してください |

### Reaction関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_DOMAIN_REACTION_NOT_FOUND | 404 | NOT_FOUND | リアクションが見つかりません | リアクションIDを確認してください |
| MESSAGE_DOMAIN_REACTION_ALREADY_EXISTS | 409 | ALREADY_EXISTS | 同じリアクションが既に存在します | リアクション状態を確認してください |
| MESSAGE_DOMAIN_INVALID_EMOJI | 400 | INVALID_ARGUMENT | 絵文字が不正です | 対応する絵文字コードを使用してください |

## ユースケース層エラー

### 入力検証エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_USECASE_INVALID_INPUT | 400 | INVALID_ARGUMENT | 入力値が不正です | 入力値を確認してください |
| MESSAGE_USECASE_MISSING_REQUIRED | 400 | INVALID_ARGUMENT | 必須項目が不足しています | 必須項目を入力してください |
| MESSAGE_USECASE_INVALID_CONVERSATION_ID | 400 | INVALID_ARGUMENT | 会話IDが不正です | UUID形式の会話IDを使用してください |
| MESSAGE_USECASE_INVALID_MESSAGE_ID | 400 | INVALID_ARGUMENT | メッセージIDが不正です | UUID形式のメッセージIDを使用してください |

### 認証・認可エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_USECASE_UNAUTHORIZED | 401 | UNAUTHENTICATED | 認証が必要です | ログインしてください |
| MESSAGE_USECASE_FORBIDDEN | 403 | PERMISSION_DENIED | アクセスが禁止されています | アクセス権限を確認してください |
| MESSAGE_USECASE_ADMIN_ACTION_DENIED | 403 | PERMISSION_DENIED | 管理者操作が拒否されました | 管理者権限を確認してください |

### E2E暗号化処理エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_USECASE_ENCRYPTION_REQUIRED | 400 | FAILED_PRECONDITION | この会話ではE2E暗号化が必須です | 暗号化されたメッセージを送信してください |
| MESSAGE_USECASE_KEY_ROTATION_IN_PROGRESS | 409 | ABORTED | 鍵ローテーション中です | 完了後に再試行してください |
| MESSAGE_USECASE_SENDER_KEY_DISTRIBUTION_FAILED | 500 | INTERNAL | Sender Key配布に失敗しました | 時間をおいて再試行してください |
| MESSAGE_USECASE_DEVICE_KEY_SYNC_FAILED | 500 | INTERNAL | デバイス鍵同期に失敗しました | デバイスの鍵状態を確認してください |

### メッセージ配信エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_USECASE_DELIVERY_ROUTING_FAILED | 502 | INTERNAL | メッセージルーティングに失敗しました | 時間をおいて再試行してください |
| MESSAGE_USECASE_OFFLINE_QUEUE_FULL | 507 | RESOURCE_EXHAUSTED | オフラインキューが満杯です | しばらく待ってから再試行してください |
| MESSAGE_USECASE_DELIVERY_ORDER_VIOLATION | 500 | INTERNAL | メッセージ配信順序の違反が検出されました | システム管理者に連絡してください |

### 既読管理エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_USECASE_READ_RECEIPT_FAILED | 500 | INTERNAL | 既読処理に失敗しました | 時間をおいて再試行してください |
| MESSAGE_USECASE_BULK_READ_LIMIT_EXCEEDED | 400 | INVALID_ARGUMENT | 一括既読処理の上限を超えています | 対象メッセージ数を減らしてください |

### リアクション処理エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_USECASE_REACTION_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | リアクション数の上限に達しました | 既存のリアクションを削除してください |

### スパムフィルタリングエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_USECASE_SPAM_DETECTED | 422 | RESOURCE_EXHAUSTED | スパムとして検出されました | メッセージ内容を見直してください |
| MESSAGE_USECASE_SPAM_QUARANTINED | 422 | RESOURCE_EXHAUSTED | メッセージがスパム隔離されました | サポートに連絡してください |
| MESSAGE_USECASE_SENDER_REPUTATION_LOW | 429 | RESOURCE_EXHAUSTED | 送信者の評価が低いため制限されています | しばらく時間をおいてください |

### 一括操作エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_USECASE_BULK_OPERATION_FAILED | 500 | INTERNAL | 一括操作に失敗しました | 操作対象を確認して再試行してください |
| MESSAGE_USECASE_BULK_LIMIT_EXCEEDED | 400 | INVALID_ARGUMENT | 一括操作の対象数が上限を超えています | 対象数を減らしてください |
| MESSAGE_USECASE_BULK_OPERATION_IN_PROGRESS | 409 | ABORTED | 一括操作が進行中です | 完了を待ってから再試行してください |

### デバイス同期エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_USECASE_SYNC_FAILED | 500 | INTERNAL | デバイス同期に失敗しました | 時間をおいて再試行してください |
| MESSAGE_USECASE_SYNC_CONFLICT | 409 | ABORTED | 同期の競合が発生しました | 最新の状態を取得してください |
| MESSAGE_USECASE_DRAFT_SYNC_FAILED | 500 | INTERNAL | 下書き同期に失敗しました | 時間をおいて再試行してください |

### ビジネスロジックエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_USECASE_CONFLICT | 409 | ABORTED | リソースの競合が発生しました | 時間をおいて再試行してください |
| MESSAGE_USECASE_PRECONDITION_FAILED | 412 | FAILED_PRECONDITION | 事前条件を満たしていません | 事前条件を確認してください |
| MESSAGE_USECASE_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |

## インフラストラクチャ層エラー

### データベースエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_INFRA_DATABASE_CONNECTION_FAILED | 503 | UNAVAILABLE | データベース接続失敗 | 接続設定を確認してください |
| MESSAGE_INFRA_DATABASE_QUERY_FAILED | 500 | INTERNAL | クエリ実行失敗 | クエリを確認してください |
| MESSAGE_INFRA_DATABASE_TRANSACTION_FAILED | 500 | INTERNAL | トランザクション失敗 | 再試行してください |
| MESSAGE_INFRA_DATABASE_CONSTRAINT_VIOLATION | 409 | ABORTED | データベース制約違反 | データの整合性を確認してください |
| MESSAGE_INFRA_DATABASE_SHARD_UNAVAILABLE | 503 | UNAVAILABLE | データベースシャードが利用不可 | シャードの状態を確認してください |

### キャッシュエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_INFRA_CACHE_CONNECTION_FAILED | 503 | UNAVAILABLE | キャッシュ接続失敗 | 接続設定を確認してください |
| MESSAGE_INFRA_CACHE_OPERATION_FAILED | 500 | INTERNAL | キャッシュ操作失敗 | 再試行してください |
| MESSAGE_INFRA_CACHE_INVALIDATION_FAILED | 500 | INTERNAL | キャッシュ無効化失敗 | キャッシュシステムを確認してください |

### WebSocket接続エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_INFRA_WEBSOCKET_CONNECTION_FAILED | 503 | UNAVAILABLE | WebSocket接続に失敗しました | 接続設定を確認してください |
| MESSAGE_INFRA_WEBSOCKET_SEND_FAILED | 500 | INTERNAL | WebSocketメッセージ送信に失敗しました | 接続状態を確認してください |
| MESSAGE_INFRA_WEBSOCKET_DISCONNECTED | 503 | UNAVAILABLE | WebSocket接続が切断されました | 自動再接続を待つか、手動で再接続してください |
| MESSAGE_INFRA_WEBSOCKET_UPGRADE_FAILED | 400 | INVALID_ARGUMENT | WebSocketアップグレードに失敗しました | プロトコル設定を確認してください |
| MESSAGE_INFRA_WEBSOCKET_HEARTBEAT_TIMEOUT | 503 | UNAVAILABLE | WebSocketハートビートがタイムアウトしました | 接続を再確立してください |
| MESSAGE_INFRA_WEBSOCKET_POD_ROUTING_FAILED | 500 | INTERNAL | Pod間メッセージルーティングに失敗しました | システム管理者に連絡してください |

### 暗号化ライブラリ（libsignal）エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_INFRA_LIBSIGNAL_INIT_FAILED | 500 | INTERNAL | libsignal初期化に失敗しました | システム管理者に連絡してください |
| MESSAGE_INFRA_LIBSIGNAL_ENCRYPTION_FAILED | 500 | INTERNAL | libsignal暗号化処理に失敗しました | 鍵の状態を確認してください |
| MESSAGE_INFRA_LIBSIGNAL_SESSION_ERROR | 500 | INTERNAL | libsignalセッションエラー | 鍵交換を再実行してください |
| MESSAGE_INFRA_LIBSIGNAL_FFI_ERROR | 500 | INTERNAL | libsignal FFIバインディングエラー | システム管理者に連絡してください |

### 外部サービス連携エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_INFRA_MEDIA_SERVICE_ERROR | 502 | INTERNAL | avion-mediaサービスエラー | メディアサービスの状態を確認してください |
| MESSAGE_INFRA_MEDIA_SERVICE_TIMEOUT | 504 | DEADLINE_EXCEEDED | avion-mediaサービスタイムアウト | 時間をおいて再試行してください |
| MESSAGE_INFRA_NOTIFICATION_SERVICE_ERROR | 502 | INTERNAL | avion-notificationサービスエラー | 通知サービスの状態を確認してください |
| MESSAGE_INFRA_NOTIFICATION_SERVICE_TIMEOUT | 504 | DEADLINE_EXCEEDED | avion-notificationサービスタイムアウト | 時間をおいて再試行してください |
| MESSAGE_INFRA_USER_SERVICE_ERROR | 502 | INTERNAL | avion-userサービスエラー | ユーザーサービスの状態を確認してください |
| MESSAGE_INFRA_AUTH_SERVICE_ERROR | 502 | INTERNAL | avion-authサービスエラー | 認証サービスの状態を確認してください |

### メッセージキュー（NATS）エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_INFRA_NATS_CONNECTION_FAILED | 503 | UNAVAILABLE | NATSキュー接続失敗 | 接続設定を確認してください |
| MESSAGE_INFRA_NATS_PUBLISH_FAILED | 500 | INTERNAL | NATSメッセージ発行失敗 | 再試行してください |
| MESSAGE_INFRA_NATS_CONSUME_FAILED | 500 | INTERNAL | NATSメッセージ消費失敗 | メッセージ形式を確認してください |
| MESSAGE_INFRA_NATS_DLQ_MOVE_FAILED | 500 | INTERNAL | Dead Letter Queue移動に失敗しました | DLQの状態を確認してください |

### データ整合性エラー（CRITICAL）

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_INFRA_MESSAGE_LOSS | 500 | INTERNAL | メッセージ喪失が検出されました | **即座にオンコールエンジニアに連絡してください。** 配信パイプラインの緊急調査が必要です |
| MESSAGE_INFRA_DELIVERY_EXHAUSTED | 500 | INTERNAL | メッセージ配信がリトライ上限に到達しました | DLQを確認し、手動で再処理してください |
| MESSAGE_INFRA_DELIVERY_STATE_INCONSISTENCY | 500 | INTERNAL | 配信状態の不整合が検出されました | 配信状態の整合性修復手順を実行してください |
| MESSAGE_INFRA_KEY_INCONSISTENCY | 500 | INTERNAL | 暗号化鍵の不整合が検出されました | 鍵の不整合修復手順を実行してください |

## ハンドラー層エラー

### WebSocketハンドシェイクエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_HANDLER_WEBSOCKET_AUTH_FAILED | 401 | UNAUTHENTICATED | WebSocket認証に失敗しました | 認証トークンを確認してください |
| MESSAGE_HANDLER_WEBSOCKET_PROTOCOL_ERROR | 400 | INVALID_ARGUMENT | WebSocketプロトコルエラー | WebSocketプロトコルの仕様を確認してください |

### ペイロード検証エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_HANDLER_BAD_REQUEST | 400 | INVALID_ARGUMENT | 不正なリクエスト | リクエスト形式を確認してください |
| MESSAGE_HANDLER_PAYLOAD_TOO_LARGE | 413 | INVALID_ARGUMENT | ペイロードサイズ超過 | リクエストサイズを小さくしてください |
| MESSAGE_HANDLER_UNSUPPORTED_MEDIA_TYPE | 415 | INVALID_ARGUMENT | サポートされないメディアタイプ | Content-Typeを確認してください |
| MESSAGE_HANDLER_INVALID_JSON | 400 | INVALID_ARGUMENT | JSONパースに失敗しました | JSON形式を確認してください |

### レート制限エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MESSAGE_HANDLER_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました（ユーザー単位: 100msg/min） | しばらく待ってから再試行してください |
| MESSAGE_HANDLER_IP_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | IPベースのレート制限を超過しました（1000msg/min） | しばらく待ってから再試行してください |

## 関連ドキュメント

- [Avion エラーコード標準化ガイドライン](../common/errors/error-standards.md)
- [avion-message PRD](./prd.md)
- [avion-message Design Doc](./designdoc.md)
