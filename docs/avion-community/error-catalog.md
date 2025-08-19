# エラーカタログ: avion-community

**Last Updated:** 2025/08/19  
**Service:** Community Management Service

## 概要

avion-communityサービスで発生する可能性のあるエラーコード一覧とその対処法です。

## ドメイン層エラー

### Community関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_DOMAIN_COMMUNITY_NOT_FOUND | 404 | NOT_FOUND | コミュニティが見つかりません | コミュニティIDを確認してください |
| COMMUNITY_DOMAIN_COMMUNITY_ALREADY_EXISTS | 409 | ALREADY_EXISTS | コミュニティが既に存在します | 別のコミュニティ名を選択してください |
| COMMUNITY_DOMAIN_INVALID_COMMUNITY_NAME | 400 | INVALID_ARGUMENT | コミュニティ名が不正です | 名前の規則を確認してください |
| COMMUNITY_DOMAIN_COMMUNITY_NAME_TOO_LONG | 400 | INVALID_ARGUMENT | コミュニティ名が長すぎます | 名前を短縮してください |
| COMMUNITY_DOMAIN_COMMUNITY_SUSPENDED | 403 | PERMISSION_DENIED | コミュニティが停止されています | 管理者に連絡してください |
| COMMUNITY_DOMAIN_COMMUNITY_DELETED | 404 | NOT_FOUND | コミュニティが削除されています | 削除されたコミュニティにはアクセスできません |

### Membership関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_DOMAIN_MEMBERSHIP_NOT_FOUND | 404 | NOT_FOUND | メンバーシップが見つかりません | メンバーシップ状態を確認してください |
| COMMUNITY_DOMAIN_ALREADY_MEMBER | 409 | ALREADY_EXISTS | 既にメンバーです | メンバーシップ状態を確認してください |
| COMMUNITY_DOMAIN_NOT_MEMBER | 403 | PERMISSION_DENIED | メンバーではありません | コミュニティに参加してください |
| COMMUNITY_DOMAIN_MEMBERSHIP_PENDING | 202 | INTERNAL | メンバーシップが承認待ちです | 承認を待ってください |
| COMMUNITY_DOMAIN_MEMBERSHIP_BANNED | 403 | PERMISSION_DENIED | メンバーシップがBANされています | BAN状態を確認してください |
| COMMUNITY_DOMAIN_MEMBERSHIP_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | メンバー数上限を超過しました | コミュニティの制限を確認してください |

### Role関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_DOMAIN_ROLE_NOT_FOUND | 404 | NOT_FOUND | ロールが見つかりません | ロールIDを確認してください |
| COMMUNITY_DOMAIN_ROLE_ALREADY_EXISTS | 409 | ALREADY_EXISTS | ロールが既に存在します | 既存のロールを確認してください |
| COMMUNITY_DOMAIN_INVALID_ROLE_NAME | 400 | INVALID_ARGUMENT | ロール名が不正です | ロール名の規則を確認してください |
| COMMUNITY_DOMAIN_INSUFFICIENT_ROLE | 403 | PERMISSION_DENIED | ロール権限が不足しています | 必要なロールを確認してください |
| COMMUNITY_DOMAIN_CANNOT_REMOVE_LAST_ADMIN | 403 | PERMISSION_DENIED | 最後の管理者は削除できません | 他の管理者を指定してください |
| COMMUNITY_DOMAIN_ROLE_HIERARCHY_VIOLATION | 403 | PERMISSION_DENIED | ロール階層違反です | ロール階層を確認してください |

### Channel関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_DOMAIN_CHANNEL_NOT_FOUND | 404 | NOT_FOUND | チャンネルが見つかりません | チャンネルIDを確認してください |
| COMMUNITY_DOMAIN_CHANNEL_ALREADY_EXISTS | 409 | ALREADY_EXISTS | チャンネルが既に存在します | 既存のチャンネルを確認してください |
| COMMUNITY_DOMAIN_INVALID_CHANNEL_NAME | 400 | INVALID_ARGUMENT | チャンネル名が不正です | チャンネル名の規則を確認してください |
| COMMUNITY_DOMAIN_CHANNEL_ACCESS_DENIED | 403 | PERMISSION_DENIED | チャンネルへのアクセスが拒否されました | アクセス権限を確認してください |
| COMMUNITY_DOMAIN_CHANNEL_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | チャンネル数上限を超過しました | チャンネル数制限を確認してください |

### Event関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_DOMAIN_EVENT_NOT_FOUND | 404 | NOT_FOUND | イベントが見つかりません | イベントIDを確認してください |
| COMMUNITY_DOMAIN_EVENT_ALREADY_EXISTS | 409 | ALREADY_EXISTS | イベントが既に存在します | 既存のイベントを確認してください |
| COMMUNITY_DOMAIN_INVALID_EVENT_TIME | 400 | INVALID_ARGUMENT | イベント時刻が不正です | 開始・終了時刻を確認してください |
| COMMUNITY_DOMAIN_EVENT_CAPACITY_EXCEEDED | 429 | RESOURCE_EXHAUSTED | イベント定員を超過しました | 定員制限を確認してください |
| COMMUNITY_DOMAIN_EVENT_ALREADY_STARTED | 409 | ABORTED | イベントは既に開始されています | イベントの状態を確認してください |
| COMMUNITY_DOMAIN_EVENT_CANCELLED | 410 | NOT_FOUND | イベントがキャンセルされています | イベントの状態を確認してください |

### Invitation関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_DOMAIN_INVITATION_NOT_FOUND | 404 | NOT_FOUND | 招待が見つかりません | 招待IDを確認してください |
| COMMUNITY_DOMAIN_INVITATION_EXPIRED | 410 | NOT_FOUND | 招待が期限切れです | 新しい招待を取得してください |
| COMMUNITY_DOMAIN_INVITATION_ALREADY_USED | 409 | ALREADY_EXISTS | 招待は既に使用済みです | 新しい招待を取得してください |
| COMMUNITY_DOMAIN_INVITATION_REVOKED | 410 | NOT_FOUND | 招待が取り消されています | 新しい招待を取得してください |
| COMMUNITY_DOMAIN_INVALID_INVITATION_CODE | 400 | INVALID_ARGUMENT | 招待コードが不正です | 招待コードを確認してください |

### Rule関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_DOMAIN_RULE_NOT_FOUND | 404 | NOT_FOUND | コミュニティルールが見つかりません | ルールIDを確認してください |
| COMMUNITY_DOMAIN_RULE_ALREADY_EXISTS | 409 | ALREADY_EXISTS | コミュニティルールが既に存在します | 既存のルールを確認してください |
| COMMUNITY_DOMAIN_INVALID_RULE | 400 | INVALID_ARGUMENT | コミュニティルールが不正です | ルール内容を確認してください |
| COMMUNITY_DOMAIN_RULE_VIOLATION | 422 | INVALID_ARGUMENT | コミュニティルール違反です | ルールを確認してください |

### Tag関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_DOMAIN_TAG_NOT_FOUND | 404 | NOT_FOUND | タグが見つかりません | タグ名を確認してください |
| COMMUNITY_DOMAIN_TAG_ALREADY_EXISTS | 409 | ALREADY_EXISTS | タグが既に存在します | 既存のタグを確認してください |
| COMMUNITY_DOMAIN_INVALID_TAG | 400 | INVALID_ARGUMENT | タグが不正です | タグの形式を確認してください |
| COMMUNITY_DOMAIN_TAG_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | タグ数上限を超過しました | タグ数を減らしてください |

## ユースケース層エラー

### 入力検証エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_USECASE_INVALID_INPUT | 400 | INVALID_ARGUMENT | 入力値が不正です | 入力値を確認してください |
| COMMUNITY_USECASE_MISSING_REQUIRED | 400 | INVALID_ARGUMENT | 必須項目が不足しています | 必須項目を入力してください |
| COMMUNITY_USECASE_INVALID_USER_ID | 400 | INVALID_ARGUMENT | ユーザーIDが不正です | ユーザーIDの形式を確認してください |
| COMMUNITY_USECASE_INVALID_COMMUNITY_ID | 400 | INVALID_ARGUMENT | コミュニティIDが不正です | コミュニティIDの形式を確認してください |

### 認証・認可エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_USECASE_UNAUTHORIZED | 401 | UNAUTHENTICATED | 認証が必要です | ログインしてください |
| COMMUNITY_USECASE_FORBIDDEN | 403 | PERMISSION_DENIED | アクセスが禁止されています | アクセス権限を確認してください |
| COMMUNITY_USECASE_INSUFFICIENT_PERMISSION | 403 | PERMISSION_DENIED | 権限が不足しています | 必要な権限を確認してください |
| COMMUNITY_USECASE_NOT_COMMUNITY_MEMBER | 403 | PERMISSION_DENIED | コミュニティメンバーではありません | コミュニティに参加してください |

### ビジネスロジックエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_USECASE_CONFLICT | 409 | ABORTED | リソースの競合が発生しました | 時間をおいて再試行してください |
| COMMUNITY_USECASE_PRECONDITION_FAILED | 412 | FAILED_PRECONDITION | 事前条件を満たしていません | 事前条件を確認してください |
| COMMUNITY_USECASE_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |
| COMMUNITY_USECASE_QUOTA_EXCEEDED | 429 | RESOURCE_EXHAUSTED | クォータを超過しました | 使用量を確認してください |

### メンバーシップ管理エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_USECASE_JOIN_FAILED | 500 | INTERNAL | 参加に失敗しました | 再試行してください |
| COMMUNITY_USECASE_LEAVE_FAILED | 500 | INTERNAL | 脱退に失敗しました | 再試行してください |
| COMMUNITY_USECASE_INVITE_FAILED | 500 | INTERNAL | 招待に失敗しました | 招待設定を確認してください |
| COMMUNITY_USECASE_KICK_FAILED | 500 | INTERNAL | キックに失敗しました | 権限を確認してください |

### イベント管理エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_USECASE_EVENT_CREATION_FAILED | 500 | INTERNAL | イベント作成に失敗しました | イベント設定を確認してください |
| COMMUNITY_USECASE_EVENT_UPDATE_FAILED | 500 | INTERNAL | イベント更新に失敗しました | 更新内容を確認してください |
| COMMUNITY_USECASE_EVENT_REGISTRATION_FAILED | 500 | INTERNAL | イベント登録に失敗しました | 登録設定を確認してください |

## インフラストラクチャ層エラー

### データベースエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_INFRA_DATABASE_CONNECTION_FAILED | 503 | UNAVAILABLE | データベース接続失敗 | 接続設定を確認してください |
| COMMUNITY_INFRA_DATABASE_QUERY_FAILED | 500 | INTERNAL | クエリ実行失敗 | クエリを確認してください |
| COMMUNITY_INFRA_DATABASE_TRANSACTION_FAILED | 500 | INTERNAL | トランザクション失敗 | 再試行してください |
| COMMUNITY_INFRA_DATABASE_CONSTRAINT_VIOLATION | 409 | ABORTED | データベース制約違反 | データの整合性を確認してください |

### キャッシュエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_INFRA_CACHE_CONNECTION_FAILED | 503 | UNAVAILABLE | キャッシュ接続失敗 | 接続設定を確認してください |
| COMMUNITY_INFRA_CACHE_OPERATION_FAILED | 500 | INTERNAL | キャッシュ操作失敗 | 再試行してください |
| COMMUNITY_INFRA_CACHE_INVALIDATION_FAILED | 500 | INTERNAL | キャッシュ無効化失敗 | キャッシュシステムを確認してください |

### ストレージエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_INFRA_STORAGE_UPLOAD_FAILED | 500 | INTERNAL | アップロード失敗 | 再試行してください |
| COMMUNITY_INFRA_STORAGE_DELETE_FAILED | 500 | INTERNAL | 削除失敗 | 再試行してください |
| COMMUNITY_INFRA_STORAGE_QUOTA_EXCEEDED | 507 | RESOURCE_EXHAUSTED | ストレージ容量超過 | 不要なファイルを削除してください |

### メッセージキューエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_INFRA_QUEUE_CONNECTION_FAILED | 503 | UNAVAILABLE | キュー接続失敗 | 接続設定を確認してください |
| COMMUNITY_INFRA_QUEUE_PUBLISH_FAILED | 500 | INTERNAL | メッセージ発行失敗 | 再試行してください |
| COMMUNITY_INFRA_QUEUE_CONSUME_FAILED | 500 | INTERNAL | メッセージ消費失敗 | メッセージ形式を確認してください |

### 外部サービスエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_INFRA_USER_SERVICE_ERROR | 502 | INTERNAL | ユーザーサービスエラー | ユーザーサービスの状態を確認してください |
| COMMUNITY_INFRA_NOTIFICATION_SERVICE_ERROR | 502 | INTERNAL | 通知サービスエラー | 通知サービスの状態を確認してください |
| COMMUNITY_INFRA_MEDIA_SERVICE_ERROR | 502 | INTERNAL | メディアサービスエラー | メディアサービスの状態を確認してください |
| COMMUNITY_INFRA_SEARCH_SERVICE_ERROR | 502 | INTERNAL | 検索サービスエラー | 検索サービスの状態を確認してください |

### カレンダーサービスエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_INFRA_CALENDAR_SERVICE_ERROR | 502 | INTERNAL | カレンダーサービスエラー | カレンダーサービスの状態を確認してください |
| COMMUNITY_INFRA_CALENDAR_SYNC_FAILED | 500 | INTERNAL | カレンダー同期に失敗しました | 同期設定を確認してください |
| COMMUNITY_INFRA_TIMEZONE_ERROR | 400 | INVALID_ARGUMENT | タイムゾーンエラー | タイムゾーン設定を確認してください |

### 分析サービスエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_INFRA_ANALYTICS_SERVICE_ERROR | 502 | INTERNAL | 分析サービスエラー | 分析サービスの状態を確認してください |
| COMMUNITY_INFRA_METRICS_COLLECTION_FAILED | 500 | INTERNAL | メトリクス収集失敗 | メトリクスシステムを確認してください |
| COMMUNITY_INFRA_REPORT_GENERATION_FAILED | 500 | INTERNAL | レポート生成失敗 | レポートシステムを確認してください |

### ハンドラー層エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_HANDLER_BAD_REQUEST | 400 | INVALID_ARGUMENT | 不正なリクエスト | リクエスト形式を確認してください |
| COMMUNITY_HANDLER_PAYLOAD_TOO_LARGE | 413 | INVALID_ARGUMENT | ペイロードサイズ超過 | リクエストサイズを小さくしてください |
| COMMUNITY_HANDLER_UNSUPPORTED_MEDIA_TYPE | 415 | INVALID_ARGUMENT | サポートされないメディアタイプ | Content-Typeを確認してください |
| COMMUNITY_HANDLER_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |

## 関連ドキュメント

- [Avion エラーコード標準化ガイドライン](../common/errors/error-standards.md)
- [avion-community PRD](./prd.md)
- [avion-community Design Doc](./designdoc.md)