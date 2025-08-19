# エラーカタログ: avion-user

**Last Updated:** 2025/08/19  
**Service:** User Management Service

## 概要

avion-userサービスで発生する可能性のあるエラーコード一覧とその対処法です。

## ドメイン層エラー

### User関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| USER_DOMAIN_USER_NOT_FOUND | 404 | NOT_FOUND | ユーザーが見つかりません | ユーザーIDを確認してください |
| USER_DOMAIN_USER_ALREADY_EXISTS | 409 | ALREADY_EXISTS | ユーザーが既に存在します | 別のユーザー名を選択してください |
| USER_DOMAIN_INVALID_USERNAME | 400 | INVALID_ARGUMENT | ユーザー名が不正です | ユーザー名の規則を確認してください |
| USER_DOMAIN_USERNAME_UNAVAILABLE | 409 | ALREADY_EXISTS | ユーザー名が利用できません | 別のユーザー名を選択してください |
| USER_DOMAIN_USER_SUSPENDED | 403 | PERMISSION_DENIED | ユーザーが停止されています | 管理者に連絡してください |
| USER_DOMAIN_USER_DELETED | 404 | NOT_FOUND | ユーザーが削除されています | 削除されたユーザーにはアクセスできません |

### Profile関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| USER_DOMAIN_PROFILE_NOT_FOUND | 404 | NOT_FOUND | プロフィールが見つかりません | プロフィールIDを確認してください |
| USER_DOMAIN_INVALID_PROFILE_DATA | 400 | INVALID_ARGUMENT | プロフィールデータが不正です | 入力データを確認してください |
| USER_DOMAIN_PROFILE_UPDATE_RESTRICTED | 403 | PERMISSION_DENIED | プロフィール更新が制限されています | 更新制限を確認してください |
| USER_DOMAIN_DISPLAY_NAME_TOO_LONG | 400 | INVALID_ARGUMENT | 表示名が長すぎます | 表示名を短縮してください |
| USER_DOMAIN_BIO_TOO_LONG | 400 | INVALID_ARGUMENT | 自己紹介が長すぎます | 自己紹介を短縮してください |
| USER_DOMAIN_INVALID_AVATAR_FORMAT | 400 | INVALID_ARGUMENT | アバター形式が不正です | 対応形式の画像を使用してください |

### Follow関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| USER_DOMAIN_FOLLOW_NOT_FOUND | 404 | NOT_FOUND | フォロー関係が見つかりません | フォロー状態を確認してください |
| USER_DOMAIN_ALREADY_FOLLOWING | 409 | ALREADY_EXISTS | 既にフォローしています | フォロー状態を確認してください |
| USER_DOMAIN_NOT_FOLLOWING | 404 | NOT_FOUND | フォローしていません | フォロー状態を確認してください |
| USER_DOMAIN_SELF_FOLLOW_ATTEMPT | 400 | INVALID_ARGUMENT | 自分自身をフォローすることはできません | 他のユーザーをフォローしてください |
| USER_DOMAIN_FOLLOW_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | フォロー上限を超過しました | フォロー数を整理してください |
| USER_DOMAIN_BLOCKED_USER_FOLLOW | 403 | PERMISSION_DENIED | ブロックされたユーザーはフォローできません | ブロック状態を確認してください |

### Block関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| USER_DOMAIN_BLOCK_NOT_FOUND | 404 | NOT_FOUND | ブロック関係が見つかりません | ブロック状態を確認してください |
| USER_DOMAIN_ALREADY_BLOCKED | 409 | ALREADY_EXISTS | 既にブロックしています | ブロック状態を確認してください |
| USER_DOMAIN_NOT_BLOCKED | 404 | NOT_FOUND | ブロックしていません | ブロック状態を確認してください |
| USER_DOMAIN_SELF_BLOCK_ATTEMPT | 400 | INVALID_ARGUMENT | 自分自身をブロックすることはできません | 他のユーザーをブロックしてください |
| USER_DOMAIN_BLOCK_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | ブロック上限を超過しました | ブロックリストを整理してください |

### Mute関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| USER_DOMAIN_MUTE_NOT_FOUND | 404 | NOT_FOUND | ミュート関係が見つかりません | ミュート状態を確認してください |
| USER_DOMAIN_ALREADY_MUTED | 409 | ALREADY_EXISTS | 既にミュートしています | ミュート状態を確認してください |
| USER_DOMAIN_NOT_MUTED | 404 | NOT_FOUND | ミュートしていません | ミュート状態を確認してください |
| USER_DOMAIN_SELF_MUTE_ATTEMPT | 400 | INVALID_ARGUMENT | 自分自身をミュートすることはできません | 他のユーザーをミュートしてください |
| USER_DOMAIN_MUTE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | ミュート上限を超過しました | ミュートリストを整理してください |

### Privacy関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| USER_DOMAIN_PRIVATE_ACCOUNT | 403 | PERMISSION_DENIED | プライベートアカウントです | フォローリクエストを送信してください |
| USER_DOMAIN_RESTRICTED_CONTENT | 403 | PERMISSION_DENIED | 制限されたコンテンツです | アクセス権限を確認してください |
| USER_DOMAIN_INVALID_PRIVACY_SETTING | 400 | INVALID_ARGUMENT | プライバシー設定が不正です | 設定値を確認してください |

### Verification関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| USER_DOMAIN_VERIFICATION_NOT_FOUND | 404 | NOT_FOUND | 認証情報が見つかりません | 認証状態を確認してください |
| USER_DOMAIN_ALREADY_VERIFIED | 409 | ALREADY_EXISTS | 既に認証済みです | 認証状態を確認してください |
| USER_DOMAIN_VERIFICATION_EXPIRED | 410 | NOT_FOUND | 認証が期限切れです | 再認証を行ってください |
| USER_DOMAIN_VERIFICATION_FAILED | 400 | INVALID_ARGUMENT | 認証に失敗しました | 認証情報を確認してください |

## ユースケース層エラー

### 入力検証エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| USER_USECASE_INVALID_INPUT | 400 | INVALID_ARGUMENT | 入力値が不正です | 入力値を確認してください |
| USER_USECASE_MISSING_REQUIRED | 400 | INVALID_ARGUMENT | 必須項目が不足しています | 必須項目を入力してください |
| USER_USECASE_INVALID_EMAIL | 400 | INVALID_ARGUMENT | メールアドレスが不正です | メールアドレス形式を確認してください |
| USER_USECASE_INVALID_PHONE | 400 | INVALID_ARGUMENT | 電話番号が不正です | 電話番号形式を確認してください |

### 認証・認可エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| USER_USECASE_UNAUTHORIZED | 401 | UNAUTHENTICATED | 認証が必要です | ログインしてください |
| USER_USECASE_FORBIDDEN | 403 | PERMISSION_DENIED | アクセスが禁止されています | アクセス権限を確認してください |
| USER_USECASE_INSUFFICIENT_PERMISSION | 403 | PERMISSION_DENIED | 権限が不足しています | 必要な権限を確認してください |

### ビジネスロジックエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| USER_USECASE_CONFLICT | 409 | ABORTED | リソースの競合が発生しました | 時間をおいて再試行してください |
| USER_USECASE_PRECONDITION_FAILED | 412 | FAILED_PRECONDITION | 事前条件を満たしていません | 事前条件を確認してください |
| USER_USECASE_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |

### 検索・発見エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| USER_USECASE_SEARCH_FAILED | 500 | INTERNAL | 検索に失敗しました | 検索条件を見直してください |
| USER_USECASE_INVALID_SEARCH_QUERY | 400 | INVALID_ARGUMENT | 検索クエリが不正です | 検索条件を確認してください |
| USER_USECASE_SEARCH_TIMEOUT | 504 | DEADLINE_EXCEEDED | 検索がタイムアウトしました | 検索条件を絞り込んでください |

## インフラストラクチャ層エラー

### データベースエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| USER_INFRA_DATABASE_CONNECTION_FAILED | 503 | UNAVAILABLE | データベース接続失敗 | 接続設定を確認してください |
| USER_INFRA_DATABASE_QUERY_FAILED | 500 | INTERNAL | クエリ実行失敗 | クエリを確認してください |
| USER_INFRA_DATABASE_TRANSACTION_FAILED | 500 | INTERNAL | トランザクション失敗 | 再試行してください |
| USER_INFRA_DATABASE_CONSTRAINT_VIOLATION | 409 | ABORTED | データベース制約違反 | データの整合性を確認してください |

### キャッシュエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| USER_INFRA_CACHE_CONNECTION_FAILED | 503 | UNAVAILABLE | キャッシュ接続失敗 | 接続設定を確認してください |
| USER_INFRA_CACHE_OPERATION_FAILED | 500 | INTERNAL | キャッシュ操作失敗 | 再試行してください |
| USER_INFRA_CACHE_INVALIDATION_FAILED | 500 | INTERNAL | キャッシュ無効化失敗 | キャッシュシステムを確認してください |

### ストレージエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| USER_INFRA_STORAGE_UPLOAD_FAILED | 500 | INTERNAL | アップロード失敗 | 再試行してください |
| USER_INFRA_STORAGE_DELETE_FAILED | 500 | INTERNAL | 削除失敗 | 再試行してください |
| USER_INFRA_STORAGE_QUOTA_EXCEEDED | 507 | RESOURCE_EXHAUSTED | ストレージ容量超過 | 不要なファイルを削除してください |

### 外部サービスエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| USER_INFRA_EXTERNAL_SERVICE_ERROR | 502 | INTERNAL | 外部サービスエラー | サービス状態を確認してください |
| USER_INFRA_EXTERNAL_SERVICE_TIMEOUT | 504 | DEADLINE_EXCEEDED | 外部サービスタイムアウト | 時間をおいて再試行してください |
| USER_INFRA_NOTIFICATION_SERVICE_ERROR | 502 | INTERNAL | 通知サービスエラー | 通知サービスの状態を確認してください |

### ハンドラー層エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| USER_HANDLER_BAD_REQUEST | 400 | INVALID_ARGUMENT | 不正なリクエスト | リクエスト形式を確認してください |
| USER_HANDLER_PAYLOAD_TOO_LARGE | 413 | INVALID_ARGUMENT | ペイロードサイズ超過 | リクエストサイズを小さくしてください |
| USER_HANDLER_UNSUPPORTED_MEDIA_TYPE | 415 | INVALID_ARGUMENT | サポートされないメディアタイプ | Content-Typeを確認してください |
| USER_HANDLER_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |

## 関連ドキュメント

- [Avion エラーコード標準化ガイドライン](../common/errors/error-standards.md)
- [avion-user PRD](./prd.md)
- [avion-user Design Doc](./designdoc.md)