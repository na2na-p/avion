# エラーカタログ: avion-activitypub

**Last Updated:** 2025/08/19  
**Service:** ActivityPub Federation Service

## 概要

avion-activitypubサービスで発生する可能性のあるエラーコード一覧とその対処法です。

## ドメイン層エラー

### ActivityPub Object関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_DOMAIN_OBJECT_NOT_FOUND | 404 | NOT_FOUND | ActivityPubオブジェクトが見つかりません | オブジェクトIDを確認してください |
| ACTIVITYPUB_DOMAIN_INVALID_OBJECT | 400 | INVALID_ARGUMENT | ActivityPubオブジェクトが不正です | オブジェクト形式を確認してください |
| ACTIVITYPUB_DOMAIN_OBJECT_TYPE_UNSUPPORTED | 400 | INVALID_ARGUMENT | サポートされないオブジェクトタイプです | 対応するオブジェクトタイプを使用してください |
| ACTIVITYPUB_DOMAIN_OBJECT_SCHEMA_INVALID | 400 | INVALID_ARGUMENT | オブジェクトスキーマが不正です | スキーマ定義を確認してください |

### Actor関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_DOMAIN_ACTOR_NOT_FOUND | 404 | NOT_FOUND | Actorが見つかりません | Actor IDを確認してください |
| ACTIVITYPUB_DOMAIN_INVALID_ACTOR | 400 | INVALID_ARGUMENT | Actorが不正です | Actor形式を確認してください |
| ACTIVITYPUB_DOMAIN_ACTOR_TYPE_UNSUPPORTED | 400 | INVALID_ARGUMENT | サポートされないActorタイプです | 対応するActorタイプを使用してください |
| ACTIVITYPUB_DOMAIN_ACTOR_SUSPENDED | 403 | PERMISSION_DENIED | Actorが停止されています | Actor状態を確認してください |
| ACTIVITYPUB_DOMAIN_ACTOR_BLOCKED | 403 | PERMISSION_DENIED | Actorがブロックされています | ブロック状態を確認してください |

### Activity関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_DOMAIN_ACTIVITY_NOT_FOUND | 404 | NOT_FOUND | Activityが見つかりません | Activity IDを確認してください |
| ACTIVITYPUB_DOMAIN_INVALID_ACTIVITY | 400 | INVALID_ARGUMENT | Activityが不正です | Activity形式を確認してください |
| ACTIVITYPUB_DOMAIN_ACTIVITY_TYPE_UNSUPPORTED | 400 | INVALID_ARGUMENT | サポートされないActivityタイプです | 対応するActivityタイプを使用してください |
| ACTIVITYPUB_DOMAIN_ACTIVITY_ALREADY_PROCESSED | 409 | ALREADY_EXISTS | Activityは既に処理済みです | 処理状態を確認してください |
| ACTIVITYPUB_DOMAIN_ACTIVITY_EXPIRED | 410 | NOT_FOUND | Activityが期限切れです | 新しいActivityを送信してください |

### Federation関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_DOMAIN_FEDERATION_DISABLED | 403 | PERMISSION_DENIED | フェデレーションが無効です | フェデレーション設定を確認してください |
| ACTIVITYPUB_DOMAIN_INSTANCE_BLOCKED | 403 | PERMISSION_DENIED | インスタンスがブロックされています | ブロック状態を確認してください |
| ACTIVITYPUB_DOMAIN_INSTANCE_SUSPENDED | 403 | PERMISSION_DENIED | インスタンスが停止されています | インスタンス状態を確認してください |
| ACTIVITYPUB_DOMAIN_INVALID_INSTANCE | 400 | INVALID_ARGUMENT | インスタンスが不正です | インスタンス情報を確認してください |

### Signature関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_DOMAIN_SIGNATURE_INVALID | 401 | UNAUTHENTICATED | 署名が不正です | 署名を確認してください |
| ACTIVITYPUB_DOMAIN_SIGNATURE_EXPIRED | 401 | UNAUTHENTICATED | 署名が期限切れです | 新しい署名を生成してください |
| ACTIVITYPUB_DOMAIN_KEY_NOT_FOUND | 404 | NOT_FOUND | 公開鍵が見つかりません | 公開鍵を確認してください |
| ACTIVITYPUB_DOMAIN_INVALID_KEY | 400 | INVALID_ARGUMENT | 公開鍵が不正です | 公開鍵形式を確認してください |
| ACTIVITYPUB_DOMAIN_SIGNATURE_VERIFICATION_FAILED | 401 | UNAUTHENTICATED | 署名検証に失敗しました | 署名と鍵を確認してください |

### Collection関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_DOMAIN_COLLECTION_NOT_FOUND | 404 | NOT_FOUND | コレクションが見つかりません | コレクションIDを確認してください |
| ACTIVITYPUB_DOMAIN_INVALID_COLLECTION | 400 | INVALID_ARGUMENT | コレクションが不正です | コレクション形式を確認してください |
| ACTIVITYPUB_DOMAIN_COLLECTION_TOO_LARGE | 413 | INVALID_ARGUMENT | コレクションが大きすぎます | コレクションサイズを確認してください |
| ACTIVITYPUB_DOMAIN_COLLECTION_ACCESS_DENIED | 403 | PERMISSION_DENIED | コレクションへのアクセスが拒否されました | アクセス権限を確認してください |

## ユースケース層エラー

### 入力検証エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_USECASE_INVALID_INPUT | 400 | INVALID_ARGUMENT | 入力値が不正です | 入力値を確認してください |
| ACTIVITYPUB_USECASE_MISSING_REQUIRED | 400 | INVALID_ARGUMENT | 必須項目が不足しています | 必須項目を入力してください |
| ACTIVITYPUB_USECASE_INVALID_URI | 400 | INVALID_ARGUMENT | URIが不正です | URI形式を確認してください |
| ACTIVITYPUB_USECASE_INVALID_CONTENT_TYPE | 400 | INVALID_ARGUMENT | Content-Typeが不正です | Content-Typeを確認してください |

### 認証・認可エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_USECASE_UNAUTHORIZED | 401 | UNAUTHENTICATED | 認証が必要です | 認証情報を確認してください |
| ACTIVITYPUB_USECASE_FORBIDDEN | 403 | PERMISSION_DENIED | アクセスが禁止されています | アクセス権限を確認してください |
| ACTIVITYPUB_USECASE_AUTHENTICATION_FAILED | 401 | UNAUTHENTICATED | 認証に失敗しました | 認証情報を確認してください |

### プロトコルエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_USECASE_PROTOCOL_VERSION_UNSUPPORTED | 400 | INVALID_ARGUMENT | サポートされないプロトコルバージョンです | プロトコルバージョンを確認してください |
| ACTIVITYPUB_USECASE_MALFORMED_REQUEST | 400 | INVALID_ARGUMENT | リクエストが不正な形式です | リクエスト形式を確認してください |
| ACTIVITYPUB_USECASE_CONTENT_NEGOTIATION_FAILED | 406 | INVALID_ARGUMENT | コンテンツネゴシエーションに失敗しました | Accept ヘッダーを確認してください |

### フェデレーションエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_USECASE_FEDERATION_FAILED | 500 | INTERNAL | フェデレーションに失敗しました | フェデレーション設定を確認してください |
| ACTIVITYPUB_USECASE_REMOTE_DELIVERY_FAILED | 502 | INTERNAL | リモート配信に失敗しました | リモートサーバーの状態を確認してください |
| ACTIVITYPUB_USECASE_REMOTE_FETCH_FAILED | 502 | INTERNAL | リモート取得に失敗しました | リモートサーバーの状態を確認してください |
| ACTIVITYPUB_USECASE_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |

### インボックス/アウトボックスエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_USECASE_INBOX_FULL | 507 | RESOURCE_EXHAUSTED | インボックスが満杯です | インボックスを整理してください |
| ACTIVITYPUB_USECASE_OUTBOX_DELIVERY_FAILED | 502 | INTERNAL | アウトボックス配信に失敗しました | 配信設定を確認してください |
| ACTIVITYPUB_USECASE_DUPLICATE_ACTIVITY | 409 | ALREADY_EXISTS | 重複したActivityです | Activity IDを確認してください |

## インフラストラクチャ層エラー

### データベースエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_INFRA_DATABASE_CONNECTION_FAILED | 503 | UNAVAILABLE | データベース接続失敗 | 接続設定を確認してください |
| ACTIVITYPUB_INFRA_DATABASE_QUERY_FAILED | 500 | INTERNAL | クエリ実行失敗 | クエリを確認してください |
| ACTIVITYPUB_INFRA_DATABASE_TRANSACTION_FAILED | 500 | INTERNAL | トランザクション失敗 | 再試行してください |

### HTTPクライアントエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_INFRA_HTTP_CLIENT_ERROR | 502 | INTERNAL | HTTPクライアントエラー | リモートサーバーの状態を確認してください |
| ACTIVITYPUB_INFRA_HTTP_TIMEOUT | 504 | DEADLINE_EXCEEDED | HTTPタイムアウト | タイムアウト設定を確認してください |
| ACTIVITYPUB_INFRA_HTTP_CONNECTION_FAILED | 503 | UNAVAILABLE | HTTP接続失敗 | ネットワーク接続を確認してください |
| ACTIVITYPUB_INFRA_TLS_VERIFICATION_FAILED | 502 | INTERNAL | TLS検証に失敗しました | 証明書を確認してください |

### キャッシュエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_INFRA_CACHE_CONNECTION_FAILED | 503 | UNAVAILABLE | キャッシュ接続失敗 | 接続設定を確認してください |
| ACTIVITYPUB_INFRA_CACHE_OPERATION_FAILED | 500 | INTERNAL | キャッシュ操作失敗 | 再試行してください |
| ACTIVITYPUB_INFRA_CACHE_MISS | 404 | NOT_FOUND | キャッシュミス | キャッシュの再生成を待ってください |

### メッセージキューエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_INFRA_QUEUE_CONNECTION_FAILED | 503 | UNAVAILABLE | キュー接続失敗 | 接続設定を確認してください |
| ACTIVITYPUB_INFRA_QUEUE_PUBLISH_FAILED | 500 | INTERNAL | メッセージ発行失敗 | 再試行してください |
| ACTIVITYPUB_INFRA_QUEUE_CONSUME_FAILED | 500 | INTERNAL | メッセージ消費失敗 | メッセージ形式を確認してください |

### 暗号化・署名エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_INFRA_CRYPTO_ERROR | 500 | INTERNAL | 暗号化エラー | 暗号化設定を確認してください |
| ACTIVITYPUB_INFRA_SIGNATURE_GENERATION_FAILED | 500 | INTERNAL | 署名生成に失敗しました | 秘密鍵を確認してください |
| ACTIVITYPUB_INFRA_KEY_MANAGEMENT_ERROR | 500 | INTERNAL | 鍵管理エラー | 鍵管理システムを確認してください |

### 外部サービスエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_INFRA_USER_SERVICE_ERROR | 502 | INTERNAL | ユーザーサービスエラー | ユーザーサービスの状態を確認してください |
| ACTIVITYPUB_INFRA_DROP_SERVICE_ERROR | 502 | INTERNAL | Dropサービスエラー | Dropサービスの状態を確認してください |
| ACTIVITYPUB_INFRA_MEDIA_SERVICE_ERROR | 502 | INTERNAL | メディアサービスエラー | メディアサービスの状態を確認してください |

### ハンドラー層エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_HANDLER_BAD_REQUEST | 400 | INVALID_ARGUMENT | 不正なリクエスト | リクエスト形式を確認してください |
| ACTIVITYPUB_HANDLER_UNSUPPORTED_MEDIA_TYPE | 415 | INVALID_ARGUMENT | サポートされないメディアタイプ | Content-Typeを確認してください |
| ACTIVITYPUB_HANDLER_NOT_ACCEPTABLE | 406 | INVALID_ARGUMENT | 受信できない形式です | Accept ヘッダーを確認してください |
| ACTIVITYPUB_HANDLER_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |

## 関連ドキュメント

- [Avion エラーコード標準化ガイドライン](../common/errors/error-standards.md)
- [avion-activitypub PRD](./prd.md)
- [avion-activitypub Design Doc](./designdoc.md)