# エラーカタログ: avion-community

**Last Updated:** 2026/03/15
**Service:** Community Management Service
**サービスプレフィックス:** `COMMUNITY`

## 概要

avion-communityサービスで発生する可能性のあるエラーコード一覧とその対処法です。
エラーコードは `[COMMUNITY]_[LAYER]_[ERROR_TYPE]` の命名規則に従います。

## ドメイン層エラー

### Community関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_DOMAIN_NOT_FOUND | 404 | NOT_FOUND | コミュニティが見つかりません | コミュニティIDを確認してください |
| COMMUNITY_DOMAIN_ALREADY_EXISTS | 409 | ALREADY_EXISTS | コミュニティが既に存在します | 別のコミュニティ名を選択してください |
| COMMUNITY_DOMAIN_INVALID_COMMUNITY_NAME | 400 | INVALID_ARGUMENT | コミュニティ名が不正です（2-50文字、特殊文字制限） | 名前の規則を確認してください |
| COMMUNITY_DOMAIN_NAME_TOO_LONG | 400 | INVALID_ARGUMENT | コミュニティ名が長すぎます | 50文字以内に短縮してください |
| COMMUNITY_DOMAIN_INVALID_STATE | 412 | FAILED_PRECONDITION | コミュニティの状態遷移が不正です | 現在のコミュニティ状態を確認してください |
| COMMUNITY_DOMAIN_SUSPENDED | 403 | PERMISSION_DENIED | コミュニティが停止されています | 管理者に連絡してください |
| COMMUNITY_DOMAIN_DELETED | 404 | NOT_FOUND | コミュニティが削除されています | 削除されたコミュニティにはアクセスできません |
| COMMUNITY_DOMAIN_ARCHIVED | 412 | FAILED_PRECONDITION | コミュニティがアーカイブされています | アーカイブされたコミュニティは読み取り専用です |
| COMMUNITY_DOMAIN_OWNERSHIP_TRANSFER_FAILED | 412 | FAILED_PRECONDITION | 所有権譲渡に失敗しました | 譲渡先ユーザーがアクティブメンバーであることを確認してください |

### Membership関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_DOMAIN_MEMBERSHIP_NOT_FOUND | 404 | NOT_FOUND | メンバーシップが見つかりません | メンバーシップ状態を確認してください |
| COMMUNITY_DOMAIN_ALREADY_MEMBER | 409 | ALREADY_EXISTS | 既にメンバーです | メンバーシップ状態を確認してください |
| COMMUNITY_DOMAIN_NOT_MEMBER | 403 | PERMISSION_DENIED | メンバーではありません | コミュニティに参加してください |
| COMMUNITY_DOMAIN_MEMBERSHIP_PENDING | 412 | FAILED_PRECONDITION | メンバーシップが承認待ちです | 承認を待ってください |
| COMMUNITY_DOMAIN_MEMBERSHIP_SUSPENDED | 403 | PERMISSION_DENIED | メンバーシップが一時停止されています | 停止期間の終了を待つか、管理者に連絡してください |
| COMMUNITY_DOMAIN_MEMBERSHIP_BANNED | 403 | PERMISSION_DENIED | メンバーシップがBANされています | BAN状態を確認してください |
| COMMUNITY_DOMAIN_MEMBERSHIP_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | メンバー数上限を超過しました | コミュニティの制限を確認してください |
| COMMUNITY_DOMAIN_OWNER_CANNOT_LEAVE | 412 | FAILED_PRECONDITION | オーナーはコミュニティを退会できません | 先に所有権を譲渡してください |

### Role関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_DOMAIN_ROLE_NOT_FOUND | 404 | NOT_FOUND | ロールが見つかりません | ロールIDを確認してください |
| COMMUNITY_DOMAIN_ROLE_ALREADY_EXISTS | 409 | ALREADY_EXISTS | ロールが既に存在します | 既存のロールを確認してください |
| COMMUNITY_DOMAIN_INVALID_ROLE_NAME | 400 | INVALID_ARGUMENT | ロール名が不正です（2-20文字） | ロール名の規則を確認してください |
| COMMUNITY_DOMAIN_INVALID_ROLE | 400 | INVALID_ARGUMENT | 無効なロール指定です | 有効なロール（owner, moderator, member, custom）を指定してください |
| COMMUNITY_DOMAIN_INSUFFICIENT_ROLE | 403 | PERMISSION_DENIED | ロール権限が不足しています | 必要なロールを確認してください |
| COMMUNITY_DOMAIN_PERMISSION_DENIED | 403 | PERMISSION_DENIED | 操作に必要な権限がありません | 必要な権限を確認してください |
| COMMUNITY_DOMAIN_CANNOT_REMOVE_LAST_ADMIN | 403 | PERMISSION_DENIED | 最後の管理者は削除できません | 他の管理者を指定してください |
| COMMUNITY_DOMAIN_ROLE_HIERARCHY_VIOLATION | 403 | PERMISSION_DENIED | ロール階層違反です | 上位ロールのメンバーに対する操作は制限されています |

### Topic関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_DOMAIN_TOPIC_NOT_FOUND | 404 | NOT_FOUND | トピックが見つかりません | トピックIDを確認してください |
| COMMUNITY_DOMAIN_TOPIC_ALREADY_EXISTS | 409 | ALREADY_EXISTS | トピックが既に存在します | コミュニティ内で一意のトピック名を指定してください |
| COMMUNITY_DOMAIN_INVALID_TOPIC_NAME | 400 | INVALID_ARGUMENT | トピック名が不正です（2-30文字） | トピック名の規則を確認してください |
| COMMUNITY_DOMAIN_TOPIC_ACCESS_DENIED | 403 | PERMISSION_DENIED | トピックへのアクセスが拒否されました | アクセス権限を確認してください |
| COMMUNITY_DOMAIN_TOPIC_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | トピック数上限を超過しました（最大1,000トピック/コミュニティ） | 不要なトピックをアーカイブしてください |
| COMMUNITY_DOMAIN_TOPIC_ARCHIVED | 412 | FAILED_PRECONDITION | トピックがアーカイブされています | アーカイブされたトピックには新規投稿できません |

### Event関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_DOMAIN_EVENT_NOT_FOUND | 404 | NOT_FOUND | イベントが見つかりません | イベントIDを確認してください |
| COMMUNITY_DOMAIN_EVENT_CONFLICT | 409 | ABORTED | イベントスケジュールが競合しています | 異なる時間帯を選択してください |
| COMMUNITY_DOMAIN_INVALID_EVENT_TIME | 400 | INVALID_ARGUMENT | イベント時刻が不正です | 開始時刻は未来、終了時刻は開始時刻以降に設定してください |
| COMMUNITY_DOMAIN_EVENT_CAPACITY_EXCEEDED | 429 | RESOURCE_EXHAUSTED | イベント定員を超過しました | 定員制限を確認してください |
| COMMUNITY_DOMAIN_EVENT_ALREADY_STARTED | 412 | FAILED_PRECONDITION | イベントは既に開始されています | 進行中のイベントは編集できません |
| COMMUNITY_DOMAIN_EVENT_CANCELLED | 412 | FAILED_PRECONDITION | イベントがキャンセルされています | キャンセルされたイベントには操作できません |
| COMMUNITY_DOMAIN_EVENT_COMPLETED | 412 | FAILED_PRECONDITION | イベントは既に完了しています | 完了したイベントには操作できません |

### Invitation関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_DOMAIN_INVITATION_NOT_FOUND | 404 | NOT_FOUND | 招待が見つかりません | 招待IDを確認してください |
| COMMUNITY_DOMAIN_INVITE_EXPIRED | 410 | DEADLINE_EXCEEDED | 招待が期限切れです | 新しい招待をリクエストしてください |
| COMMUNITY_DOMAIN_INVITATION_ALREADY_USED | 409 | ALREADY_EXISTS | 招待の使用回数上限に達しました | 新しい招待を取得してください |
| COMMUNITY_DOMAIN_INVITATION_REVOKED | 410 | FAILED_PRECONDITION | 招待が取り消されています | 新しい招待を取得してください |
| COMMUNITY_DOMAIN_INVALID_INVITATION_CODE | 400 | INVALID_ARGUMENT | 招待コードが不正です | 招待コードを確認してください |

### Rule関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_DOMAIN_RULE_NOT_FOUND | 404 | NOT_FOUND | コミュニティルールが見つかりません | ルールIDを確認してください |
| COMMUNITY_DOMAIN_RULE_ALREADY_EXISTS | 409 | ALREADY_EXISTS | コミュニティルールが既に存在します | ルール番号の一意性を確認してください |
| COMMUNITY_DOMAIN_INVALID_RULE | 400 | INVALID_ARGUMENT | コミュニティルールが不正です（タイトル1-100文字、説明最大1000文字） | ルール内容を確認してください |
| COMMUNITY_DOMAIN_RULE_VIOLATION | 422 | FAILED_PRECONDITION | コミュニティルール違反が検出されました | コミュニティルールを確認してください |

### Moderation関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_DOMAIN_MODERATION_LOG_NOT_FOUND | 404 | NOT_FOUND | モデレーションログが見つかりません | ログIDを確認してください |
| COMMUNITY_DOMAIN_APPEAL_NOT_FOUND | 404 | NOT_FOUND | 異議申し立てが見つかりません | 申し立てIDを確認してください |
| COMMUNITY_DOMAIN_APPEAL_ALREADY_EXISTS | 409 | ALREADY_EXISTS | 同一モデレーション処理への異議申し立てが既に存在します | 既存の申し立て状態を確認してください |
| COMMUNITY_DOMAIN_APPEAL_ALREADY_REVIEWED | 412 | FAILED_PRECONDITION | 異議申し立ては既にレビュー済みです | レビュー結果を確認してください |
| COMMUNITY_DOMAIN_AUTO_MODERATION_RULE_INVALID | 400 | INVALID_ARGUMENT | 自動モデレーションルールが不正です | ルールのパターンとアクションを確認してください |

## ユースケース層エラー

### 入力検証エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_USECASE_INVALID_INPUT | 400 | INVALID_ARGUMENT | 入力値が不正です | 入力値を確認してください |
| COMMUNITY_USECASE_MISSING_REQUIRED | 400 | INVALID_ARGUMENT | 必須項目が不足しています | 必須項目を入力してください |
| COMMUNITY_USECASE_INVALID_USER_ID | 400 | INVALID_ARGUMENT | ユーザーIDが不正です | ユーザーIDの形式（UUID v7）を確認してください |
| COMMUNITY_USECASE_INVALID_COMMUNITY_ID | 400 | INVALID_ARGUMENT | コミュニティIDが不正です | コミュニティIDの形式（UUID v7）を確認してください |

### 認証・認可エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_USECASE_UNAUTHORIZED | 401 | UNAUTHENTICATED | 認証が必要です | ログインしてください |
| COMMUNITY_USECASE_FORBIDDEN | 403 | PERMISSION_DENIED | アクセスが禁止されています | アクセス権限を確認してください |
| COMMUNITY_USECASE_INSUFFICIENT_PERMISSION | 403 | PERMISSION_DENIED | 権限が不足しています | 必要な権限を確認してください |
| COMMUNITY_USECASE_NOT_COMMUNITY_MEMBER | 403 | PERMISSION_DENIED | コミュニティメンバーではありません | コミュニティに参加してください |

### ビジネスロジックエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_USECASE_CONFLICT | 409 | ABORTED | リソースの競合が発生しました | 時間をおいて再試行してください |
| COMMUNITY_USECASE_PRECONDITION_FAILED | 412 | FAILED_PRECONDITION | 事前条件を満たしていません | 事前条件を確認してください |
| COMMUNITY_USECASE_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |
| COMMUNITY_USECASE_QUOTA_EXCEEDED | 429 | RESOURCE_EXHAUSTED | クォータを超過しました | 使用量を確認してください |

### メンバーシップ管理エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_USECASE_JOIN_FAILED | 500 | INTERNAL | 参加処理に失敗しました | 再試行してください |
| COMMUNITY_USECASE_LEAVE_FAILED | 500 | INTERNAL | 脱退処理に失敗しました | 再試行してください |
| COMMUNITY_USECASE_INVITE_FAILED | 500 | INTERNAL | 招待処理に失敗しました | 招待設定を確認してください |
| COMMUNITY_USECASE_KICK_FAILED | 500 | INTERNAL | キック処理に失敗しました | 権限を確認してください |
| COMMUNITY_USECASE_OWNERSHIP_TRANSFER_FAILED | 500 | INTERNAL | 所有権譲渡処理に失敗しました | 再試行してください |

### モデレーション管理エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_USECASE_MODERATION_FAILED | 500 | INTERNAL | モデレーション処理に失敗しました | 再試行してください |
| COMMUNITY_USECASE_REPORT_FAILED | 500 | INTERNAL | 報告処理に失敗しました | 再試行してください |
| COMMUNITY_USECASE_APPEAL_FAILED | 500 | INTERNAL | 異議申し立て処理に失敗しました | 再試行してください |
| COMMUNITY_USECASE_ESCALATION_FAILED | 500 | INTERNAL | avion-moderationへのエスカレーションに失敗しました | 再試行してください |

### イベント管理エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_USECASE_EVENT_CREATION_FAILED | 500 | INTERNAL | イベント作成に失敗しました | イベント設定を確認してください |
| COMMUNITY_USECASE_EVENT_UPDATE_FAILED | 500 | INTERNAL | イベント更新に失敗しました | 更新内容を確認してください |
| COMMUNITY_USECASE_EVENT_REGISTRATION_FAILED | 500 | INTERNAL | イベント参加登録に失敗しました | 登録設定を確認してください |

### データエクスポートエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_USECASE_EXPORT_FAILED | 500 | INTERNAL | コミュニティデータのエクスポートに失敗しました | 再試行してください |

## インフラストラクチャ層エラー

### データベースエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_INFRA_DATABASE_CONNECTION_FAILED | 503 | UNAVAILABLE | データベース接続失敗 | 接続設定を確認してください |
| COMMUNITY_INFRA_DATABASE_QUERY_FAILED | 500 | INTERNAL | クエリ実行失敗 | クエリを確認してください |
| COMMUNITY_INFRA_DATABASE_TRANSACTION_FAILED | 500 | INTERNAL | トランザクション失敗 | 再試行してください |
| COMMUNITY_INFRA_DATABASE_CONSTRAINT_VIOLATION | 409 | ABORTED | データベース制約違反 | データの整合性を確認してください |

### キャッシュエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_INFRA_CACHE_CONNECTION_FAILED | 503 | UNAVAILABLE | キャッシュ（Redis）接続失敗 | 接続設定を確認してください |
| COMMUNITY_INFRA_CACHE_OPERATION_FAILED | 500 | INTERNAL | キャッシュ操作失敗 | 再試行してください |
| COMMUNITY_INFRA_CACHE_INVALIDATION_FAILED | 500 | INTERNAL | 権限キャッシュの無効化に失敗しました | キャッシュシステムの状態を確認し、手動でキャッシュをクリアしてください |

### ストレージエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_INFRA_STORAGE_UPLOAD_FAILED | 500 | INTERNAL | アップロード失敗 | 再試行してください |
| COMMUNITY_INFRA_STORAGE_DELETE_FAILED | 500 | INTERNAL | 削除失敗 | 再試行してください |
| COMMUNITY_INFRA_STORAGE_QUOTA_EXCEEDED | 507 | RESOURCE_EXHAUSTED | ストレージ容量超過 | 不要なファイルを削除してください |

### メッセージキューエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_INFRA_QUEUE_CONNECTION_FAILED | 503 | UNAVAILABLE | NATS JetStream接続失敗 | 接続設定を確認してください |
| COMMUNITY_INFRA_QUEUE_PUBLISH_FAILED | 500 | INTERNAL | メッセージ発行失敗 | 再試行してください |
| COMMUNITY_INFRA_QUEUE_CONSUME_FAILED | 500 | INTERNAL | メッセージ消費失敗 | メッセージ形式を確認してください |

### 外部サービスエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_INFRA_USER_SERVICE_ERROR | 502 | UNAVAILABLE | ユーザーサービスエラー | ユーザーサービスの状態を確認してください |
| COMMUNITY_INFRA_NOTIFICATION_SERVICE_ERROR | 502 | UNAVAILABLE | 通知サービスエラー | 通知サービスの状態を確認してください |
| COMMUNITY_INFRA_MEDIA_SERVICE_ERROR | 502 | UNAVAILABLE | メディアサービスエラー | メディアサービスの状態を確認してください |
| COMMUNITY_INFRA_SEARCH_SERVICE_ERROR | 502 | UNAVAILABLE | 検索サービスエラー | 検索サービスの状態を確認してください |
| COMMUNITY_INFRA_MODERATION_SERVICE_ERROR | 502 | UNAVAILABLE | モデレーションサービスエラー | avion-moderationサービスの状態を確認してください |
| COMMUNITY_INFRA_ACTIVITYPUB_SYNC_FAILED | 502 | UNAVAILABLE | ActivityPub連携の同期処理に失敗しました | リモートインスタンスの状態を確認し、再試行してください |
| COMMUNITY_INFRA_WEBHOOK_DELIVERY_FAILED | 502 | UNAVAILABLE | Webhook配信に失敗しました | Webhookエンドポイントの状態を確認し、再試行してください |

## ハンドラー層エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| COMMUNITY_HANDLER_BAD_REQUEST | 400 | INVALID_ARGUMENT | 不正なリクエスト | リクエスト形式を確認してください |
| COMMUNITY_HANDLER_PAYLOAD_TOO_LARGE | 413 | INVALID_ARGUMENT | ペイロードサイズ超過 | リクエストサイズを小さくしてください |
| COMMUNITY_HANDLER_UNSUPPORTED_MEDIA_TYPE | 415 | INVALID_ARGUMENT | サポートされないメディアタイプ | Content-Typeを確認してください |
| COMMUNITY_HANDLER_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |

## 関連ドキュメント

- [Avion エラーコード標準化ガイドライン](../common/errors/error-standards.md)
- [Avion エラーコード一覧](../common/errors/error-codes.md)
- [Avion エラー実装ガイド](../common/errors/implementation-guide.md)
- [avion-community PRD](./prd.md)
- [avion-community Design Doc](./designdoc.md)
