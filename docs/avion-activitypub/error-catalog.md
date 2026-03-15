# エラーカタログ: avion-activitypub

**Last Updated:** 2026/03/15
**Service:** ActivityPub Federation Service

## 概要

avion-activitypubサービスで発生する可能性のあるエラーコード一覧とその対処法です。
エラーコード命名規則は[Avion エラーコード標準化ガイドライン](../common/errors/error-standards.md)に準拠しています。

命名規則: `ACTIVITYPUB_[LAYER]_[ERROR_TYPE]`

## ドメイン層エラー

### ActivityPub Object関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_DOMAIN_OBJECT_NOT_FOUND | 404 | NOT_FOUND | ActivityPubオブジェクトが見つかりません | オブジェクトIDを確認してください |
| ACTIVITYPUB_DOMAIN_INVALID_OBJECT | 400 | INVALID_ARGUMENT | ActivityPubオブジェクトが不正です | オブジェクト形式を確認してください |
| ACTIVITYPUB_DOMAIN_OBJECT_TYPE_UNSUPPORTED | 400 | INVALID_ARGUMENT | サポートされないオブジェクトタイプです | 対応するオブジェクトタイプを使用してください |
| ACTIVITYPUB_DOMAIN_OBJECT_SCHEMA_INVALID | 400 | INVALID_ARGUMENT | オブジェクトスキーマが不正です | スキーマ定義を確認してください |

### Actor関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_DOMAIN_ACTOR_NOT_FOUND | 404 | NOT_FOUND | Actorが見つかりません | Actor IDを確認してください |
| ACTIVITYPUB_DOMAIN_INVALID_ACTOR | 400 | INVALID_ARGUMENT | Actorが不正です | Actor形式を確認してください |
| ACTIVITYPUB_DOMAIN_ACTOR_TYPE_UNSUPPORTED | 400 | INVALID_ARGUMENT | サポートされないActorタイプです | 対応するActorタイプを使用してください |
| ACTIVITYPUB_DOMAIN_ACTOR_SUSPENDED | 403 | PERMISSION_DENIED | Actorが停止されています | Actor状態を確認してください |
| ACTIVITYPUB_DOMAIN_ACTOR_BLOCKED | 403 | PERMISSION_DENIED | Actorがブロックされています | ブロック状態を確認してください |
| ACTIVITYPUB_DOMAIN_ACTOR_UNREACHABLE | 502 | UNAVAILABLE | Actorに到達できません | リモートサーバーの状態を確認してください |
| ACTIVITYPUB_DOMAIN_ACTOR_TRUST_SCORE_LOW | 403 | PERMISSION_DENIED | Actorの信頼度スコアが低いです | Actorの信頼度状態を確認してください |

### Activity関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_DOMAIN_ACTIVITY_NOT_FOUND | 404 | NOT_FOUND | Activityが見つかりません | Activity IDを確認してください |
| ACTIVITYPUB_DOMAIN_INVALID_ACTIVITY | 400 | INVALID_ARGUMENT | Activityが不正です | Activity形式を確認してください |
| ACTIVITYPUB_DOMAIN_ACTIVITY_TYPE_UNSUPPORTED | 400 | INVALID_ARGUMENT | サポートされないActivityタイプです | 対応するActivityタイプを使用してください |
| ACTIVITYPUB_DOMAIN_ACTIVITY_ALREADY_PROCESSED | 409 | ALREADY_EXISTS | Activityは既に処理済みです | 処理状態を確認してください |
| ACTIVITYPUB_DOMAIN_ACTIVITY_EXPIRED | 410 | NOT_FOUND | Activityが期限切れです | 新しいActivityを送信してください |
| ACTIVITYPUB_DOMAIN_ACTIVITY_ACTOR_MISMATCH | 403 | PERMISSION_DENIED | Activityの実行者が一致しません | Actor権限を確認してください |

### Federation関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_DOMAIN_FEDERATION_DISABLED | 403 | PERMISSION_DENIED | フェデレーションが無効です | フェデレーション設定を確認してください |
| ACTIVITYPUB_DOMAIN_INSTANCE_BLOCKED | 403 | PERMISSION_DENIED | インスタンスがブロックされています | ブロック状態を確認してください |
| ACTIVITYPUB_DOMAIN_INSTANCE_SUSPENDED | 403 | PERMISSION_DENIED | インスタンスが停止されています | インスタンス状態を確認してください |
| ACTIVITYPUB_DOMAIN_INVALID_INSTANCE | 400 | INVALID_ARGUMENT | インスタンスが不正です | インスタンス情報を確認してください |

### Signature関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_DOMAIN_SIGNATURE_INVALID | 401 | UNAUTHENTICATED | 署名が不正です | 署名を確認してください |
| ACTIVITYPUB_DOMAIN_SIGNATURE_EXPIRED | 401 | UNAUTHENTICATED | 署名が期限切れです | 新しい署名を生成してください |
| ACTIVITYPUB_DOMAIN_KEY_NOT_FOUND | 404 | NOT_FOUND | 公開鍵が見つかりません | 公開鍵を確認してください |
| ACTIVITYPUB_DOMAIN_INVALID_KEY | 400 | INVALID_ARGUMENT | 公開鍵が不正です | 公開鍵形式を確認してください |
| ACTIVITYPUB_DOMAIN_SIGNATURE_VERIFICATION_FAILED | 401 | UNAUTHENTICATED | 署名検証に失敗しました | 署名と鍵を確認してください |
| ACTIVITYPUB_DOMAIN_SIGNATURE_REPLAY_DETECTED | 401 | UNAUTHENTICATED | リプレイ攻撃が検出されました | 新しいリクエストを送信してください |
| ACTIVITYPUB_DOMAIN_DIGEST_MISMATCH | 401 | UNAUTHENTICATED | Digestヘッダーが本文と一致しません | リクエスト本文とDigestヘッダーを確認してください |

### Collection関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_DOMAIN_COLLECTION_NOT_FOUND | 404 | NOT_FOUND | コレクションが見つかりません | コレクションIDを確認してください |
| ACTIVITYPUB_DOMAIN_INVALID_COLLECTION | 400 | INVALID_ARGUMENT | コレクションが不正です | コレクション形式を確認してください |
| ACTIVITYPUB_DOMAIN_COLLECTION_TOO_LARGE | 413 | INVALID_ARGUMENT | コレクションが大きすぎます | コレクションサイズを確認してください |
| ACTIVITYPUB_DOMAIN_COLLECTION_ACCESS_DENIED | 403 | PERMISSION_DENIED | コレクションへのアクセスが拒否されました | アクセス権限を確認してください |

### ドメインブロック関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_DOMAIN_BLOCKED_DOMAIN_NOT_FOUND | 404 | NOT_FOUND | ブロック済みドメインが見つかりません | ドメイン名を確認してください |
| ACTIVITYPUB_DOMAIN_BLOCKED_DOMAIN_ALREADY_EXISTS | 409 | ALREADY_EXISTS | ドメインは既にブロック済みです | ブロック状態を確認してください |
| ACTIVITYPUB_DOMAIN_BLOCKED_DOMAIN_INVALID | 400 | INVALID_ARGUMENT | ドメイン名が不正です | DNS名の形式を確認してください |
| ACTIVITYPUB_DOMAIN_BLOCKED_DOMAIN_UNBLOCK_DENIED | 403 | PERMISSION_DENIED | ドメインブロック解除が拒否されました | 権限と条件を確認してください |

### WebFinger関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_DOMAIN_WEBFINGER_RESOURCE_NOT_FOUND | 404 | NOT_FOUND | WebFingerリソースが見つかりません | リソースURIを確認してください |
| ACTIVITYPUB_DOMAIN_WEBFINGER_INVALID_RESOURCE | 400 | INVALID_ARGUMENT | WebFingerリソース形式が不正です | acct:形式またはHTTPS URIを使用してください |

### 配送関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_DOMAIN_DELIVERY_NOT_FOUND | 404 | NOT_FOUND | 配送タスクが見つかりません | 配送タスクIDを確認してください |
| ACTIVITYPUB_DOMAIN_DELIVERY_MAX_RETRIES_EXCEEDED | 500 | INTERNAL | 最大リトライ回数に達しました | デッドレターキューを確認してください |
| ACTIVITYPUB_DOMAIN_DELIVERY_CIRCUIT_BREAKER_OPEN | 503 | UNAVAILABLE | サーキットブレーカーが作動しています | 対象ドメインの状態を確認してください |
| ACTIVITYPUB_DOMAIN_DELIVERY_DEAD_LETTER | 500 | INTERNAL | 配送がデッドレターキューに移動しました | DLQの内容を確認し手動対応してください |
| ACTIVITYPUB_DOMAIN_DELIVERY_INVALID_TARGET | 400 | INVALID_ARGUMENT | 配送先InboxURLが不正です | 配送先URLを確認してください |

### アカウント移行関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_DOMAIN_MOVE_INVALID_TARGET | 400 | INVALID_ARGUMENT | 移行先Actorが不正です | 移行先Actor URIを確認してください |
| ACTIVITYPUB_DOMAIN_MOVE_CIRCULAR_MIGRATION | 400 | INVALID_ARGUMENT | 循環移行が検出されました | 移行先が循環参照していないか確認してください |
| ACTIVITYPUB_DOMAIN_MOVE_NOT_AUTHORIZED | 403 | PERMISSION_DENIED | 移行が承認されていません | 移行先Actorが移行を承認しているか確認してください |
| ACTIVITYPUB_DOMAIN_MOVE_ALREADY_MIGRATED | 409 | ALREADY_EXISTS | Actorは既に移行済みです | 移行状態を確認してください |

### 投票（Question/Answer）関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_DOMAIN_QUESTION_NOT_FOUND | 404 | NOT_FOUND | 投票が見つかりません | 投票IDを確認してください |
| ACTIVITYPUB_DOMAIN_QUESTION_EXPIRED | 410 | NOT_FOUND | 投票が終了しています | 投票の終了日時を確認してください |
| ACTIVITYPUB_DOMAIN_ANSWER_INVALID | 400 | INVALID_ARGUMENT | 投票回答が不正です | 有効な選択肢を選んでください |
| ACTIVITYPUB_DOMAIN_ANSWER_ALREADY_SUBMITTED | 409 | ALREADY_EXISTS | 既に投票済みです | 投票状態を確認してください |

### コミュニティ連合関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_DOMAIN_COMMUNITY_NOT_FOUND | 404 | NOT_FOUND | コミュニティGroup Actorが見つかりません | コミュニティIDを確認してください |
| ACTIVITYPUB_DOMAIN_COMMUNITY_JOIN_DENIED | 403 | PERMISSION_DENIED | コミュニティ参加が拒否されました | 参加条件を確認してください |
| ACTIVITYPUB_DOMAIN_COMMUNITY_ALREADY_MEMBER | 409 | ALREADY_EXISTS | 既にコミュニティメンバーです | メンバーシップ状態を確認してください |
| ACTIVITYPUB_DOMAIN_COMMUNITY_NOT_MEMBER | 403 | PERMISSION_DENIED | コミュニティメンバーではありません | メンバーシップ状態を確認してください |
| ACTIVITYPUB_DOMAIN_COMMUNITY_INVITE_INVALID | 400 | INVALID_ARGUMENT | コミュニティ招待が不正です | 招待情報を確認してください |
| ACTIVITYPUB_DOMAIN_COMMUNITY_ROLE_INSUFFICIENT | 403 | PERMISSION_DENIED | コミュニティ内の権限が不足しています | 役割と権限を確認してください |
| ACTIVITYPUB_DOMAIN_COMMUNITY_PLATFORM_UNSUPPORTED | 400 | INVALID_ARGUMENT | リモートプラットフォームがGroup Actorをサポートしていません | プラットフォーム互換性を確認してください |

### 通報（Flag）関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_DOMAIN_REPORT_NOT_FOUND | 404 | NOT_FOUND | 通報が見つかりません | 通報IDを確認してください |
| ACTIVITYPUB_DOMAIN_REPORT_DUPLICATE | 409 | ALREADY_EXISTS | 同一内容の通報が既に存在します | 通報状態を確認してください |
| ACTIVITYPUB_DOMAIN_REPORT_INVALID_REASON | 400 | INVALID_ARGUMENT | 通報理由が不正です | 有効な通報理由を選択してください |
| ACTIVITYPUB_DOMAIN_REPORT_TARGET_NOT_FOUND | 404 | NOT_FOUND | 通報対象が見つかりません | 通報対象のURIを確認してください |

## ユースケース層エラー

### 入力検証エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_USECASE_INVALID_INPUT | 400 | INVALID_ARGUMENT | 入力値が不正です | 入力値を確認してください |
| ACTIVITYPUB_USECASE_MISSING_REQUIRED | 400 | INVALID_ARGUMENT | 必須項目が不足しています | 必須項目を入力してください |
| ACTIVITYPUB_USECASE_INVALID_URI | 400 | INVALID_ARGUMENT | URIが不正です | URI形式を確認してください |
| ACTIVITYPUB_USECASE_INVALID_CONTENT_TYPE | 400 | INVALID_ARGUMENT | Content-Typeが不正です | Content-Typeを確認してください |

### 認証・認可エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_USECASE_UNAUTHORIZED | 401 | UNAUTHENTICATED | 認証が必要です | 認証情報を確認してください |
| ACTIVITYPUB_USECASE_FORBIDDEN | 403 | PERMISSION_DENIED | アクセスが禁止されています | アクセス権限を確認してください |
| ACTIVITYPUB_USECASE_AUTHENTICATION_FAILED | 401 | UNAUTHENTICATED | 認証に失敗しました | 認証情報を確認してください |

### プロトコルエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_USECASE_PROTOCOL_VERSION_UNSUPPORTED | 400 | INVALID_ARGUMENT | サポートされないプロトコルバージョンです | プロトコルバージョンを確認してください |
| ACTIVITYPUB_USECASE_MALFORMED_REQUEST | 400 | INVALID_ARGUMENT | リクエストが不正な形式です | リクエスト形式を確認してください |
| ACTIVITYPUB_USECASE_CONTENT_NEGOTIATION_FAILED | 406 | INVALID_ARGUMENT | コンテンツネゴシエーションに失敗しました | Accept ヘッダーを確認してください |
| ACTIVITYPUB_USECASE_JSONLD_INVALID | 400 | INVALID_ARGUMENT | JSON-LD形式が不正です | @contextフィールドを含む有効なJSON-LDを送信してください |

### フェデレーションエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_USECASE_FEDERATION_FAILED | 500 | INTERNAL | フェデレーションに失敗しました | フェデレーション設定を確認してください |
| ACTIVITYPUB_USECASE_REMOTE_DELIVERY_FAILED | 502 | INTERNAL | リモート配信に失敗しました | リモートサーバーの状態を確認してください |
| ACTIVITYPUB_USECASE_REMOTE_FETCH_FAILED | 502 | INTERNAL | リモート取得に失敗しました | リモートサーバーの状態を確認してください |
| ACTIVITYPUB_USECASE_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |
| ACTIVITYPUB_USECASE_WEBFINGER_RESOLUTION_FAILED | 502 | INTERNAL | WebFinger解決に失敗しました | リモートサーバーのWebFinger設定を確認してください |

### インボックス/アウトボックスエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_USECASE_INBOX_FULL | 507 | RESOURCE_EXHAUSTED | インボックスが満杯です | インボックスを整理してください |
| ACTIVITYPUB_USECASE_OUTBOX_DELIVERY_FAILED | 502 | INTERNAL | アウトボックス配信に失敗しました | 配信設定を確認してください |
| ACTIVITYPUB_USECASE_DUPLICATE_ACTIVITY | 409 | ALREADY_EXISTS | 重複したActivityです | Activity IDを確認してください |

### アカウント移行エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_USECASE_MOVE_VALIDATION_FAILED | 400 | INVALID_ARGUMENT | アカウント移行の検証に失敗しました | 移行元・移行先の情報を確認してください |
| ACTIVITYPUB_USECASE_MOVE_FOLLOWER_MIGRATION_FAILED | 500 | INTERNAL | フォロー関係の移行に失敗しました | 再試行してください |

### 投票エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_USECASE_QUESTION_PROCESSING_FAILED | 500 | INTERNAL | 投票の処理に失敗しました | 投票データの形式を確認してください |
| ACTIVITYPUB_USECASE_ANSWER_PROCESSING_FAILED | 500 | INTERNAL | 投票回答の処理に失敗しました | 回答データの形式を確認してください |

### コミュニティ連合エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_USECASE_COMMUNITY_PROCESSING_FAILED | 500 | INTERNAL | コミュニティ連合処理に失敗しました | コミュニティサービスの状態を確認してください |
| ACTIVITYPUB_USECASE_COMMUNITY_DISTRIBUTION_FAILED | 500 | INTERNAL | コミュニティメンバーへの配信に失敗しました | 配信対象とメンバーリストを確認してください |

## インフラストラクチャ層エラー

### データベースエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_INFRA_DATABASE_CONNECTION_FAILED | 503 | UNAVAILABLE | データベース接続失敗 | 接続設定を確認してください |
| ACTIVITYPUB_INFRA_DATABASE_QUERY_FAILED | 500 | INTERNAL | クエリ実行失敗 | クエリを確認してください |
| ACTIVITYPUB_INFRA_DATABASE_TRANSACTION_FAILED | 500 | INTERNAL | トランザクション失敗 | 再試行してください |

### HTTPクライアントエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_INFRA_HTTP_CLIENT_ERROR | 502 | INTERNAL | HTTPクライアントエラー | リモートサーバーの状態を確認してください |
| ACTIVITYPUB_INFRA_HTTP_TIMEOUT | 504 | DEADLINE_EXCEEDED | HTTPタイムアウト | タイムアウト設定を確認してください |
| ACTIVITYPUB_INFRA_HTTP_CONNECTION_FAILED | 503 | UNAVAILABLE | HTTP接続失敗 | ネットワーク接続を確認してください |
| ACTIVITYPUB_INFRA_TLS_VERIFICATION_FAILED | 502 | INTERNAL | TLS検証に失敗しました | 証明書を確認してください |
| ACTIVITYPUB_INFRA_DNS_RESOLUTION_FAILED | 502 | INTERNAL | DNS解決に失敗しました | ドメイン名を確認してください |

### キャッシュエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_INFRA_CACHE_CONNECTION_FAILED | 503 | UNAVAILABLE | キャッシュ接続失敗 | 接続設定を確認してください |
| ACTIVITYPUB_INFRA_CACHE_OPERATION_FAILED | 500 | INTERNAL | キャッシュ操作失敗 | 再試行してください |
| ACTIVITYPUB_INFRA_CACHE_MISS | 500 | INTERNAL | キャッシュミスによる内部処理失敗 | キャッシュの再生成を待つか、再試行してください。キャッシュミス自体はクライアントエラーではなく、サービス内部でフォールバック処理（DB問い合わせ等）が必要な状態です |

### メッセージキューエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_INFRA_QUEUE_CONNECTION_FAILED | 503 | UNAVAILABLE | キュー接続失敗 | 接続設定を確認してください |
| ACTIVITYPUB_INFRA_QUEUE_PUBLISH_FAILED | 500 | INTERNAL | メッセージ発行失敗 | 再試行してください |
| ACTIVITYPUB_INFRA_QUEUE_CONSUME_FAILED | 500 | INTERNAL | メッセージ消費失敗 | メッセージ形式を確認してください |
| ACTIVITYPUB_INFRA_QUEUE_DLQ_WRITE_FAILED | 500 | INTERNAL | デッドレターキューへの書き込み失敗 | キューの状態を確認してください |

### 暗号化・署名エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_INFRA_CRYPTO_ERROR | 500 | INTERNAL | 暗号化エラー | 暗号化設定を確認してください |
| ACTIVITYPUB_INFRA_SIGNATURE_GENERATION_FAILED | 500 | INTERNAL | 署名生成に失敗しました | 秘密鍵を確認してください |
| ACTIVITYPUB_INFRA_KEY_MANAGEMENT_ERROR | 500 | INTERNAL | 鍵管理エラー | 鍵管理システムを確認してください |

### 外部サービスエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_INFRA_USER_SERVICE_ERROR | 502 | INTERNAL | ユーザーサービスエラー | ユーザーサービスの状態を確認してください |
| ACTIVITYPUB_INFRA_DROP_SERVICE_ERROR | 502 | INTERNAL | Dropサービスエラー | Dropサービスの状態を確認してください |
| ACTIVITYPUB_INFRA_MEDIA_SERVICE_ERROR | 502 | INTERNAL | メディアサービスエラー | メディアサービスの状態を確認してください |
| ACTIVITYPUB_INFRA_COMMUNITY_SERVICE_ERROR | 502 | INTERNAL | コミュニティサービスエラー | コミュニティサービスの状態を確認してください |
| ACTIVITYPUB_INFRA_MODERATION_SERVICE_ERROR | 502 | INTERNAL | モデレーションサービスエラー | モデレーションサービスの状態を確認してください |
| ACTIVITYPUB_INFRA_TIMELINE_SERVICE_ERROR | 502 | INTERNAL | タイムラインサービスエラー | タイムラインサービスの状態を確認してください |

## ハンドラー層エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ACTIVITYPUB_HANDLER_BAD_REQUEST | 400 | INVALID_ARGUMENT | 不正なリクエスト | リクエスト形式を確認してください |
| ACTIVITYPUB_HANDLER_UNSUPPORTED_MEDIA_TYPE | 415 | INVALID_ARGUMENT | サポートされないメディアタイプ | Content-Typeを確認してください |
| ACTIVITYPUB_HANDLER_NOT_ACCEPTABLE | 406 | INVALID_ARGUMENT | 受信できない形式です | Accept ヘッダーを確認してください |
| ACTIVITYPUB_HANDLER_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |
| ACTIVITYPUB_HANDLER_PAYLOAD_TOO_LARGE | 413 | INVALID_ARGUMENT | リクエストペイロードが大きすぎます | ペイロードサイズを削減してください |

## 関連ドキュメント

- [Avion エラーコード標準化ガイドライン](../common/errors/error-standards.md)
- [Avion エラーコード一覧](../common/errors/error-codes.md)
- [Avion エラー実装ガイド](../common/errors/implementation-guide.md)
- [avion-activitypub PRD](./prd.md)
- [avion-activitypub Design Doc](./designdoc.md)
