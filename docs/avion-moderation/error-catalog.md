# エラーカタログ: avion-moderation

**Last Updated:** 2025/08/19  
**Service:** Content Moderation and Filtering Service

## 概要

avion-moderationサービスで発生する可能性のあるエラーコード一覧とその対処法です。

## ドメイン層エラー

### ModerationRule関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_DOMAIN_RULE_NOT_FOUND | 404 | NOT_FOUND | モデレーションルールが見つかりません | ルールIDを確認してください |
| MODERATION_DOMAIN_RULE_ALREADY_EXISTS | 409 | ALREADY_EXISTS | モデレーションルールが既に存在します | 既存のルールを確認してください |
| MODERATION_DOMAIN_INVALID_RULE | 400 | INVALID_ARGUMENT | モデレーションルールが不正です | ルール定義を確認してください |
| MODERATION_DOMAIN_RULE_CONFLICT | 409 | ABORTED | ルールの競合が発生しました | ルールの優先度を確認してください |
| MODERATION_DOMAIN_RULE_DISABLED | 403 | PERMISSION_DENIED | モデレーションルールが無効です | ルールを有効にしてください |

### ModerationAction関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_DOMAIN_ACTION_NOT_FOUND | 404 | NOT_FOUND | モデレーションアクションが見つかりません | アクションIDを確認してください |
| MODERATION_DOMAIN_INVALID_ACTION | 400 | INVALID_ARGUMENT | モデレーションアクションが不正です | アクション定義を確認してください |
| MODERATION_DOMAIN_ACTION_ALREADY_EXECUTED | 409 | ALREADY_EXISTS | アクションは既に実行済みです | 実行状態を確認してください |
| MODERATION_DOMAIN_ACTION_EXECUTION_FAILED | 500 | INTERNAL | アクション実行に失敗しました | 実行エラーを確認してください |
| MODERATION_DOMAIN_UNSUPPORTED_ACTION_TYPE | 400 | INVALID_ARGUMENT | サポートされないアクションタイプです | 対応するアクションタイプを使用してください |

### ContentFilter関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_DOMAIN_FILTER_NOT_FOUND | 404 | NOT_FOUND | コンテンツフィルターが見つかりません | フィルターIDを確認してください |
| MODERATION_DOMAIN_INVALID_FILTER | 400 | INVALID_ARGUMENT | コンテンツフィルターが不正です | フィルター設定を確認してください |
| MODERATION_DOMAIN_FILTER_COMPILATION_FAILED | 422 | INTERNAL | フィルターコンパイルに失敗しました | フィルター構文を確認してください |
| MODERATION_DOMAIN_FILTER_PROCESSING_FAILED | 500 | INTERNAL | フィルター処理に失敗しました | フィルター処理を確認してください |

### Report関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_DOMAIN_REPORT_NOT_FOUND | 404 | NOT_FOUND | 報告が見つかりません | 報告IDを確認してください |
| MODERATION_DOMAIN_REPORT_ALREADY_EXISTS | 409 | ALREADY_EXISTS | 報告が既に存在します | 既存の報告を確認してください |
| MODERATION_DOMAIN_INVALID_REPORT | 400 | INVALID_ARGUMENT | 報告が不正です | 報告内容を確認してください |
| MODERATION_DOMAIN_REPORT_ALREADY_PROCESSED | 409 | ALREADY_EXISTS | 報告は既に処理済みです | 処理状態を確認してください |
| MODERATION_DOMAIN_SELF_REPORT_FORBIDDEN | 403 | PERMISSION_DENIED | 自分自身への報告はできません | 他のユーザーの報告を行ってください |

### ContentClassification関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_DOMAIN_CLASSIFICATION_FAILED | 500 | INTERNAL | コンテンツ分類に失敗しました | 分類システムを確認してください |
| MODERATION_DOMAIN_INVALID_CLASSIFICATION | 400 | INVALID_ARGUMENT | コンテンツ分類が不正です | 分類結果を確認してください |
| MODERATION_DOMAIN_CLASSIFICATION_CONFIDENCE_LOW | 422 | INTERNAL | 分類信頼度が低すぎます | 手動確認が必要です |
| MODERATION_DOMAIN_UNSUPPORTED_CONTENT_TYPE | 400 | INVALID_ARGUMENT | サポートされないコンテンツタイプです | 対応するコンテンツタイプを使用してください |

### ModerationQueue関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_DOMAIN_QUEUE_NOT_FOUND | 404 | NOT_FOUND | モデレーションキューが見つかりません | キューIDを確認してください |
| MODERATION_DOMAIN_QUEUE_FULL | 507 | RESOURCE_EXHAUSTED | モデレーションキューが満杯です | キューを処理してください |
| MODERATION_DOMAIN_QUEUE_ITEM_NOT_FOUND | 404 | NOT_FOUND | キューアイテムが見つかりません | アイテムIDを確認してください |
| MODERATION_DOMAIN_QUEUE_PROCESSING_FAILED | 500 | INTERNAL | キュー処理に失敗しました | 処理エラーを確認してください |

### Appeal関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_DOMAIN_APPEAL_NOT_FOUND | 404 | NOT_FOUND | 異議申し立てが見つかりません | 異議申し立てIDを確認してください |
| MODERATION_DOMAIN_APPEAL_ALREADY_EXISTS | 409 | ALREADY_EXISTS | 異議申し立てが既に存在します | 既存の異議申し立てを確認してください |
| MODERATION_DOMAIN_INVALID_APPEAL | 400 | INVALID_ARGUMENT | 異議申し立てが不正です | 申し立て内容を確認してください |
| MODERATION_DOMAIN_APPEAL_DEADLINE_EXPIRED | 410 | NOT_FOUND | 異議申し立て期限が切れています | 期限内に申し立てを行ってください |
| MODERATION_DOMAIN_APPEAL_ALREADY_PROCESSED | 409 | ALREADY_EXISTS | 異議申し立ては既に処理済みです | 処理状態を確認してください |

## ユースケース層エラー

### 入力検証エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_USECASE_INVALID_INPUT | 400 | INVALID_ARGUMENT | 入力値が不正です | 入力値を確認してください |
| MODERATION_USECASE_MISSING_REQUIRED | 400 | INVALID_ARGUMENT | 必須項目が不足しています | 必須項目を入力してください |
| MODERATION_USECASE_INVALID_CONTENT_ID | 400 | INVALID_ARGUMENT | コンテンツIDが不正です | コンテンツIDの形式を確認してください |
| MODERATION_USECASE_INVALID_USER_ID | 400 | INVALID_ARGUMENT | ユーザーIDが不正です | ユーザーIDの形式を確認してください |

### 認証・認可エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_USECASE_UNAUTHORIZED | 401 | UNAUTHENTICATED | 認証が必要です | ログインしてください |
| MODERATION_USECASE_FORBIDDEN | 403 | PERMISSION_DENIED | アクセスが禁止されています | アクセス権限を確認してください |
| MODERATION_USECASE_INSUFFICIENT_PERMISSION | 403 | PERMISSION_DENIED | 権限が不足しています | モデレーター権限が必要です |
| MODERATION_USECASE_NOT_MODERATOR | 403 | PERMISSION_DENIED | モデレーター権限がありません | 権限を確認してください |

### ビジネスロジックエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_USECASE_CONFLICT | 409 | ABORTED | リソースの競合が発生しました | 時間をおいて再試行してください |
| MODERATION_USECASE_PRECONDITION_FAILED | 412 | FAILED_PRECONDITION | 事前条件を満たしていません | 事前条件を確認してください |
| MODERATION_USECASE_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |
| MODERATION_USECASE_QUOTA_EXCEEDED | 429 | RESOURCE_EXHAUSTED | クォータを超過しました | 使用量を確認してください |

### モデレーション処理エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_USECASE_MODERATION_FAILED | 500 | INTERNAL | モデレーションに失敗しました | モデレーションシステムを確認してください |
| MODERATION_USECASE_AUTO_MODERATION_FAILED | 500 | INTERNAL | 自動モデレーションに失敗しました | 自動処理システムを確認してください |
| MODERATION_USECASE_MANUAL_REVIEW_REQUIRED | 202 | INTERNAL | 手動レビューが必要です | モデレーターによる確認を待ってください |
| MODERATION_USECASE_ESCALATION_REQUIRED | 202 | INTERNAL | エスカレーションが必要です | 上位モデレーターによる確認を待ってください |

### コンテンツ処理エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_USECASE_CONTENT_ANALYSIS_FAILED | 500 | INTERNAL | コンテンツ分析に失敗しました | 分析システムを確認してください |
| MODERATION_USECASE_TOXIC_CONTENT_DETECTED | 422 | INVALID_ARGUMENT | 有害コンテンツが検出されました | コンテンツを修正してください |
| MODERATION_USECASE_SPAM_DETECTED | 422 | INVALID_ARGUMENT | スパムが検出されました | コンテンツを見直してください |
| MODERATION_USECASE_HATE_SPEECH_DETECTED | 422 | INVALID_ARGUMENT | ヘイトスピーチが検出されました | コンテンツを修正してください |

## インフラストラクチャ層エラー

### データベースエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_INFRA_DATABASE_CONNECTION_FAILED | 503 | UNAVAILABLE | データベース接続失敗 | 接続設定を確認してください |
| MODERATION_INFRA_DATABASE_QUERY_FAILED | 500 | INTERNAL | クエリ実行失敗 | クエリを確認してください |
| MODERATION_INFRA_DATABASE_TRANSACTION_FAILED | 500 | INTERNAL | トランザクション失敗 | 再試行してください |

### AIモデルエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_INFRA_AI_MODEL_ERROR | 502 | INTERNAL | AIモデルエラー | AIサービスの状態を確認してください |
| MODERATION_INFRA_AI_MODEL_TIMEOUT | 504 | DEADLINE_EXCEEDED | AIモデルタイムアウト | タイムアウト設定を確認してください |
| MODERATION_INFRA_AI_MODEL_UNAVAILABLE | 503 | UNAVAILABLE | AIモデルが利用できません | AIサービスの復旧を待ってください |
| MODERATION_INFRA_AI_MODEL_QUOTA_EXCEEDED | 429 | RESOURCE_EXHAUSTED | AIモデルクォータ超過 | クォータリセットを待ってください |

### 画像解析エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_INFRA_IMAGE_ANALYSIS_ERROR | 502 | INTERNAL | 画像解析エラー | 画像解析サービスを確認してください |
| MODERATION_INFRA_IMAGE_PROCESSING_FAILED | 422 | INTERNAL | 画像処理に失敗しました | 画像ファイルを確認してください |
| MODERATION_INFRA_NSFW_DETECTION_FAILED | 500 | INTERNAL | NSFW検出に失敗しました | 検出システムを確認してください |

### テキスト解析エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_INFRA_TEXT_ANALYSIS_ERROR | 502 | INTERNAL | テキスト解析エラー | テキスト解析サービスを確認してください |
| MODERATION_INFRA_SENTIMENT_ANALYSIS_FAILED | 500 | INTERNAL | 感情分析に失敗しました | 分析システムを確認してください |
| MODERATION_INFRA_LANGUAGE_DETECTION_FAILED | 500 | INTERNAL | 言語検出に失敗しました | 検出システムを確認してください |

### キャッシュエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_INFRA_CACHE_CONNECTION_FAILED | 503 | UNAVAILABLE | キャッシュ接続失敗 | 接続設定を確認してください |
| MODERATION_INFRA_CACHE_OPERATION_FAILED | 500 | INTERNAL | キャッシュ操作失敗 | 再試行してください |
| MODERATION_INFRA_CACHE_INVALIDATION_FAILED | 500 | INTERNAL | キャッシュ無効化失敗 | キャッシュシステムを確認してください |

### メッセージキューエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_INFRA_QUEUE_CONNECTION_FAILED | 503 | UNAVAILABLE | キュー接続失敗 | 接続設定を確認してください |
| MODERATION_INFRA_QUEUE_PUBLISH_FAILED | 500 | INTERNAL | メッセージ発行失敗 | 再試行してください |
| MODERATION_INFRA_QUEUE_CONSUME_FAILED | 500 | INTERNAL | メッセージ消費失敗 | メッセージ形式を確認してください |
| MODERATION_INFRA_QUEUE_FULL | 503 | UNAVAILABLE | キューが満杯です | しばらく待ってから再試行してください |

### 外部サービスエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_INFRA_USER_SERVICE_ERROR | 502 | INTERNAL | ユーザーサービスエラー | ユーザーサービスの状態を確認してください |
| MODERATION_INFRA_DROP_SERVICE_ERROR | 502 | INTERNAL | Dropサービスエラー | Dropサービスの状態を確認してください |
| MODERATION_INFRA_NOTIFICATION_SERVICE_ERROR | 502 | INTERNAL | 通知サービスエラー | 通知サービスの状態を確認してください |

### ハンドラー層エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_HANDLER_BAD_REQUEST | 400 | INVALID_ARGUMENT | 不正なリクエスト | リクエスト形式を確認してください |
| MODERATION_HANDLER_PAYLOAD_TOO_LARGE | 413 | INVALID_ARGUMENT | ペイロードサイズ超過 | リクエストサイズを小さくしてください |
| MODERATION_HANDLER_UNSUPPORTED_MEDIA_TYPE | 415 | INVALID_ARGUMENT | サポートされないメディアタイプ | Content-Typeを確認してください |
| MODERATION_HANDLER_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |

## 関連ドキュメント

- [Avion エラーコード標準化ガイドライン](../common/errors/error-standards.md)
- [avion-moderation PRD](./prd.md)
- [avion-moderation Design Doc](./designdoc.md)