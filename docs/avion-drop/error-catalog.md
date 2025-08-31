# エラーカタログ: avion-drop

**Last Updated:** 2025/08/19  
**Service:** Content Management Service

## 概要

avion-dropサービスで発生する可能性のあるエラーコード一覧とその対処法です。

## ドメイン層エラー

### Drop関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_DOMAIN_DROP_NOT_FOUND | 404 | NOT_FOUND | Dropが見つかりません | DropIDを確認してください |
| DROP_DOMAIN_DROP_ALREADY_EXISTS | 409 | ALREADY_EXISTS | Dropが既に存在します | 既存のDropを確認してください |
| DROP_DOMAIN_INVALID_CONTENT | 400 | INVALID_ARGUMENT | コンテンツが不正です | コンテンツを確認してください |
| DROP_DOMAIN_CONTENT_TOO_LONG | 400 | INVALID_ARGUMENT | コンテンツが長すぎます | 文字数制限を確認してください |
| DROP_DOMAIN_EMPTY_CONTENT | 400 | INVALID_ARGUMENT | コンテンツが空です | コンテンツを入力してください |
| DROP_DOMAIN_DROP_DELETED | 404 | NOT_FOUND | Dropが削除されています | 削除されたDropにはアクセスできません |
| DROP_DOMAIN_DROP_ARCHIVED | 410 | NOT_FOUND | Dropがアーカイブされています | アーカイブされたDropは編集できません |

### Reaction関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_DOMAIN_REACTION_NOT_FOUND | 404 | NOT_FOUND | リアクションが見つかりません | リアクションIDを確認してください |
| DROP_DOMAIN_ALREADY_REACTED | 409 | ALREADY_EXISTS | 既にリアクションしています | 既存のリアクションを確認してください |
| DROP_DOMAIN_NOT_REACTED | 404 | NOT_FOUND | リアクションしていません | リアクション状態を確認してください |
| DROP_DOMAIN_INVALID_REACTION_TYPE | 400 | INVALID_ARGUMENT | リアクションタイプが不正です | 対応するリアクションタイプを使用してください |
| DROP_DOMAIN_SELF_REACTION_FORBIDDEN | 403 | PERMISSION_DENIED | 自分のDropにはリアクションできません | 他のユーザーのDropにリアクションしてください |
| DROP_DOMAIN_REACTION_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | リアクション制限を超過しました | 制限がリセットされるまで待ってください |

### Comment関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_DOMAIN_COMMENT_NOT_FOUND | 404 | NOT_FOUND | コメントが見つかりません | コメントIDを確認してください |
| DROP_DOMAIN_COMMENT_ALREADY_EXISTS | 409 | ALREADY_EXISTS | コメントが既に存在します | 既存のコメントを確認してください |
| DROP_DOMAIN_INVALID_COMMENT | 400 | INVALID_ARGUMENT | コメントが不正です | コメント内容を確認してください |
| DROP_DOMAIN_COMMENT_TOO_LONG | 400 | INVALID_ARGUMENT | コメントが長すぎます | 文字数制限を確認してください |
| DROP_DOMAIN_EMPTY_COMMENT | 400 | INVALID_ARGUMENT | コメントが空です | コメントを入力してください |
| DROP_DOMAIN_COMMENT_DELETED | 404 | NOT_FOUND | コメントが削除されています | 削除されたコメントにはアクセスできません |
| DROP_DOMAIN_COMMENT_DEPTH_EXCEEDED | 400 | INVALID_ARGUMENT | コメントの階層が深すぎます | 階層制限を確認してください |

### Media関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_DOMAIN_MEDIA_NOT_FOUND | 404 | NOT_FOUND | メディアが見つかりません | メディアIDを確認してください |
| DROP_DOMAIN_INVALID_MEDIA_TYPE | 400 | INVALID_ARGUMENT | メディアタイプが不正です | 対応するメディアタイプを使用してください |
| DROP_DOMAIN_MEDIA_TOO_LARGE | 413 | INVALID_ARGUMENT | メディアサイズが大きすぎます | ファイルサイズを小さくしてください |
| DROP_DOMAIN_MEDIA_COUNT_EXCEEDED | 400 | INVALID_ARGUMENT | メディア数が上限を超過しました | メディア数を減らしてください |
| DROP_DOMAIN_MEDIA_PROCESSING_FAILED | 422 | INTERNAL | メディア処理に失敗しました | メディアファイルを確認してください |

### Tag関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_DOMAIN_TAG_NOT_FOUND | 404 | NOT_FOUND | タグが見つかりません | タグ名を確認してください |
| DROP_DOMAIN_INVALID_TAG | 400 | INVALID_ARGUMENT | タグが不正です | タグの形式を確認してください |
| DROP_DOMAIN_TAG_TOO_LONG | 400 | INVALID_ARGUMENT | タグが長すぎます | タグの長さを短くしてください |
| DROP_DOMAIN_TOO_MANY_TAGS | 400 | INVALID_ARGUMENT | タグ数が多すぎます | タグ数を減らしてください |
| DROP_DOMAIN_DUPLICATE_TAG | 400 | INVALID_ARGUMENT | 重複したタグがあります | 重複を除去してください |

### Privacy関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_DOMAIN_PRIVATE_DROP | 403 | PERMISSION_DENIED | プライベートなDropです | アクセス権限を確認してください |
| DROP_DOMAIN_RESTRICTED_ACCESS | 403 | PERMISSION_DENIED | アクセスが制限されています | 制限条件を確認してください |
| DROP_DOMAIN_INVALID_PRIVACY_SETTING | 400 | INVALID_ARGUMENT | プライバシー設定が不正です | 設定値を確認してください |

## ユースケース層エラー

### 入力検証エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_USECASE_INVALID_INPUT | 400 | INVALID_ARGUMENT | 入力値が不正です | 入力値を確認してください |
| DROP_USECASE_MISSING_REQUIRED | 400 | INVALID_ARGUMENT | 必須項目が不足しています | 必須項目を入力してください |
| DROP_USECASE_INVALID_DROP_ID | 400 | INVALID_ARGUMENT | DropIDが不正です | DropIDの形式を確認してください |
| DROP_USECASE_INVALID_USER_ID | 400 | INVALID_ARGUMENT | ユーザーIDが不正です | ユーザーIDの形式を確認してください |

### 認証・認可エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_USECASE_UNAUTHORIZED | 401 | UNAUTHENTICATED | 認証が必要です | ログインしてください |
| DROP_USECASE_FORBIDDEN | 403 | PERMISSION_DENIED | アクセスが禁止されています | アクセス権限を確認してください |
| DROP_USECASE_INSUFFICIENT_PERMISSION | 403 | PERMISSION_DENIED | 権限が不足しています | 必要な権限を確認してください |
| DROP_USECASE_NOT_OWNER | 403 | PERMISSION_DENIED | Dropの所有者ではありません | 所有者のみが実行できる操作です |

### ビジネスロジックエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_USECASE_CONFLICT | 409 | ABORTED | リソースの競合が発生しました | 時間をおいて再試行してください |
| DROP_USECASE_PRECONDITION_FAILED | 412 | FAILED_PRECONDITION | 事前条件を満たしていません | 事前条件を確認してください |
| DROP_USECASE_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |
| DROP_USECASE_QUOTA_EXCEEDED | 429 | RESOURCE_EXHAUSTED | クォータを超過しました | 使用量を確認してください |

### コンテンツ処理エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_USECASE_CONTENT_FILTERING_FAILED | 422 | INTERNAL | コンテンツフィルタリングに失敗しました | コンテンツを確認してください |
| DROP_USECASE_SPAM_DETECTED | 422 | INVALID_ARGUMENT | スパムコンテンツが検出されました | コンテンツを見直してください |
| DROP_USECASE_INAPPROPRIATE_CONTENT | 422 | INVALID_ARGUMENT | 不適切なコンテンツが検出されました | コンテンツを修正してください |

## インフラストラクチャ層エラー

### データベースエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_INFRA_DATABASE_CONNECTION_FAILED | 503 | UNAVAILABLE | データベース接続失敗 | 接続設定を確認してください |
| DROP_INFRA_DATABASE_QUERY_FAILED | 500 | INTERNAL | クエリ実行失敗 | クエリを確認してください |
| DROP_INFRA_DATABASE_TRANSACTION_FAILED | 500 | INTERNAL | トランザクション失敗 | 再試行してください |
| DROP_INFRA_DATABASE_CONSTRAINT_VIOLATION | 409 | ABORTED | データベース制約違反 | データの整合性を確認してください |

### キャッシュエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_INFRA_CACHE_CONNECTION_FAILED | 503 | UNAVAILABLE | キャッシュ接続失敗 | 接続設定を確認してください |
| DROP_INFRA_CACHE_OPERATION_FAILED | 500 | INTERNAL | キャッシュ操作失敗 | 再試行してください |
| DROP_INFRA_CACHE_INVALIDATION_FAILED | 500 | INTERNAL | キャッシュ無効化失敗 | キャッシュシステムを確認してください |

### ストレージエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_INFRA_STORAGE_UPLOAD_FAILED | 500 | INTERNAL | アップロード失敗 | 再試行してください |
| DROP_INFRA_STORAGE_DELETE_FAILED | 500 | INTERNAL | 削除失敗 | 再試行してください |
| DROP_INFRA_STORAGE_QUOTA_EXCEEDED | 507 | RESOURCE_EXHAUSTED | ストレージ容量超過 | 不要なファイルを削除してください |

### 外部サービスエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_INFRA_MEDIA_SERVICE_ERROR | 502 | INTERNAL | メディアサービスエラー | メディアサービスの状態を確認してください |
| DROP_INFRA_SEARCH_SERVICE_ERROR | 502 | INTERNAL | 検索サービスエラー | 検索サービスの状態を確認してください |
| DROP_INFRA_MODERATION_SERVICE_ERROR | 502 | INTERNAL | モデレーションサービスエラー | モデレーションサービスの状態を確認してください |

### ハンドラー層エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_HANDLER_BAD_REQUEST | 400 | INVALID_ARGUMENT | 不正なリクエスト | リクエスト形式を確認してください |
| DROP_HANDLER_PAYLOAD_TOO_LARGE | 413 | INVALID_ARGUMENT | ペイロードサイズ超過 | リクエストサイズを小さくしてください |
| DROP_HANDLER_UNSUPPORTED_MEDIA_TYPE | 415 | INVALID_ARGUMENT | サポートされないメディアタイプ | Content-Typeを確認してください |
| DROP_HANDLER_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |

## 関連ドキュメント

- [Avion エラーコード標準化ガイドライン](../common/errors/error-standards.md)
- [avion-drop PRD](./prd.md)
- [avion-drop Design Doc](./designdoc.md)