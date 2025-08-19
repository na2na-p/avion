# エラーカタログ: avion-media

**Last Updated:** 2025/08/19  
**Service:** Media Upload, Processing, and CDN Service

## 概要

avion-mediaサービスで発生する可能性のあるエラーコード一覧とその対処法です。

## ドメイン層エラー

### Media関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MEDIA_DOMAIN_MEDIA_NOT_FOUND | 404 | NOT_FOUND | メディアが見つかりません | メディアIDを確認してください |
| MEDIA_DOMAIN_INVALID_MEDIA_TYPE | 400 | INVALID_ARGUMENT | メディアタイプが不正です | 対応するメディアタイプを使用してください |
| MEDIA_DOMAIN_MEDIA_TOO_LARGE | 413 | INVALID_ARGUMENT | メディアサイズが大きすぎます | ファイルサイズを小さくしてください |
| MEDIA_DOMAIN_MEDIA_TOO_SMALL | 400 | INVALID_ARGUMENT | メディアサイズが小さすぎます | 最小サイズ要件を確認してください |
| MEDIA_DOMAIN_UNSUPPORTED_FORMAT | 415 | INVALID_ARGUMENT | サポートされない形式です | 対応形式を確認してください |
| MEDIA_DOMAIN_CORRUPTED_MEDIA | 422 | INVALID_ARGUMENT | メディアが破損しています | 正常なファイルを使用してください |

### Upload関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MEDIA_DOMAIN_UPLOAD_NOT_FOUND | 404 | NOT_FOUND | アップロードが見つかりません | アップロードIDを確認してください |
| MEDIA_DOMAIN_UPLOAD_ALREADY_EXISTS | 409 | ALREADY_EXISTS | アップロードが既に存在します | 既存のアップロードを確認してください |
| MEDIA_DOMAIN_UPLOAD_INCOMPLETE | 409 | ABORTED | アップロードが未完了です | アップロードを完了してください |
| MEDIA_DOMAIN_UPLOAD_EXPIRED | 410 | NOT_FOUND | アップロードが期限切れです | 新しいアップロードを開始してください |
| MEDIA_DOMAIN_UPLOAD_CANCELLED | 409 | ABORTED | アップロードがキャンセルされました | 新しいアップロードを開始してください |

### Processing関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MEDIA_DOMAIN_PROCESSING_FAILED | 422 | INTERNAL | メディア処理に失敗しました | メディアファイルを確認してください |
| MEDIA_DOMAIN_PROCESSING_TIMEOUT | 504 | DEADLINE_EXCEEDED | メディア処理がタイムアウトしました | ファイルサイズまたは複雑さを確認してください |
| MEDIA_DOMAIN_PROCESSING_IN_PROGRESS | 202 | INTERNAL | メディア処理中です | 処理完了まで待ってください |
| MEDIA_DOMAIN_TRANSCODING_FAILED | 422 | INTERNAL | トランスコーディングに失敗しました | ソースファイルを確認してください |
| MEDIA_DOMAIN_THUMBNAIL_GENERATION_FAILED | 422 | INTERNAL | サムネイル生成に失敗しました | ソースファイルを確認してください |

### Storage関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MEDIA_DOMAIN_STORAGE_QUOTA_EXCEEDED | 507 | RESOURCE_EXHAUSTED | ストレージ容量を超過しました | 不要なファイルを削除してください |
| MEDIA_DOMAIN_STORAGE_ACCESS_DENIED | 403 | PERMISSION_DENIED | ストレージへのアクセスが拒否されました | アクセス権限を確認してください |
| MEDIA_DOMAIN_STORAGE_NOT_AVAILABLE | 503 | UNAVAILABLE | ストレージが利用できません | ストレージサービスの状態を確認してください |
| MEDIA_DOMAIN_INVALID_STORAGE_PATH | 400 | INVALID_ARGUMENT | ストレージパスが不正です | パス形式を確認してください |

### CDN関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MEDIA_DOMAIN_CDN_NOT_AVAILABLE | 503 | UNAVAILABLE | CDNが利用できません | CDNサービスの状態を確認してください |
| MEDIA_DOMAIN_CDN_CACHE_MISS | 404 | NOT_FOUND | CDNキャッシュミス | オリジンサーバーから取得します |
| MEDIA_DOMAIN_CDN_CACHE_EXPIRED | 410 | NOT_FOUND | CDNキャッシュが期限切れです | キャッシュが更新されるまで待ってください |
| MEDIA_DOMAIN_CDN_PURGE_FAILED | 500 | INTERNAL | CDNキャッシュ削除に失敗しました | CDN設定を確認してください |

### Metadata関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MEDIA_DOMAIN_METADATA_NOT_FOUND | 404 | NOT_FOUND | メタデータが見つかりません | メタデータIDを確認してください |
| MEDIA_DOMAIN_INVALID_METADATA | 400 | INVALID_ARGUMENT | メタデータが不正です | メタデータ形式を確認してください |
| MEDIA_DOMAIN_METADATA_EXTRACTION_FAILED | 422 | INTERNAL | メタデータ抽出に失敗しました | ファイル形式を確認してください |
| MEDIA_DOMAIN_METADATA_TOO_LARGE | 413 | INVALID_ARGUMENT | メタデータが大きすぎます | メタデータサイズを確認してください |

### Security関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MEDIA_DOMAIN_MALICIOUS_FILE_DETECTED | 422 | INVALID_ARGUMENT | 悪意のあるファイルが検出されました | 安全なファイルを使用してください |
| MEDIA_DOMAIN_VIRUS_DETECTED | 422 | INVALID_ARGUMENT | ウイルスが検出されました | ファイルをスキャンしてください |
| MEDIA_DOMAIN_INAPPROPRIATE_CONTENT | 422 | INVALID_ARGUMENT | 不適切なコンテンツが検出されました | コンテンツを確認してください |
| MEDIA_DOMAIN_COPYRIGHT_VIOLATION | 422 | INVALID_ARGUMENT | 著作権違反が検出されました | 著作権を確認してください |

## ユースケース層エラー

### 入力検証エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MEDIA_USECASE_INVALID_INPUT | 400 | INVALID_ARGUMENT | 入力値が不正です | 入力値を確認してください |
| MEDIA_USECASE_MISSING_REQUIRED | 400 | INVALID_ARGUMENT | 必須項目が不足しています | 必須項目を入力してください |
| MEDIA_USECASE_INVALID_FILE_NAME | 400 | INVALID_ARGUMENT | ファイル名が不正です | ファイル名の規則を確認してください |
| MEDIA_USECASE_INVALID_MIME_TYPE | 400 | INVALID_ARGUMENT | MIMEタイプが不正です | MIMEタイプを確認してください |

### 認証・認可エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MEDIA_USECASE_UNAUTHORIZED | 401 | UNAUTHENTICATED | 認証が必要です | ログインしてください |
| MEDIA_USECASE_FORBIDDEN | 403 | PERMISSION_DENIED | アクセスが禁止されています | アクセス権限を確認してください |
| MEDIA_USECASE_INSUFFICIENT_PERMISSION | 403 | PERMISSION_DENIED | 権限が不足しています | 必要な権限を確認してください |
| MEDIA_USECASE_NOT_OWNER | 403 | PERMISSION_DENIED | メディアの所有者ではありません | 所有者のみが実行できる操作です |

### ビジネスロジックエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MEDIA_USECASE_CONFLICT | 409 | ABORTED | リソースの競合が発生しました | 時間をおいて再試行してください |
| MEDIA_USECASE_PRECONDITION_FAILED | 412 | FAILED_PRECONDITION | 事前条件を満たしていません | 事前条件を確認してください |
| MEDIA_USECASE_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |
| MEDIA_USECASE_QUOTA_EXCEEDED | 429 | RESOURCE_EXHAUSTED | クォータを超過しました | 使用量を確認してください |

### アップロードエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MEDIA_USECASE_UPLOAD_FAILED | 500 | INTERNAL | アップロードに失敗しました | 再試行してください |
| MEDIA_USECASE_MULTIPART_UPLOAD_FAILED | 500 | INTERNAL | マルチパートアップロードに失敗しました | アップロード設定を確認してください |
| MEDIA_USECASE_UPLOAD_INTERRUPTED | 409 | ABORTED | アップロードが中断されました | 再開または再試行してください |
| MEDIA_USECASE_CHECKSUM_MISMATCH | 422 | INVALID_ARGUMENT | チェックサムが一致しません | ファイルの整合性を確認してください |

### 処理エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MEDIA_USECASE_RESIZE_FAILED | 422 | INTERNAL | リサイズに失敗しました | 画像形式を確認してください |
| MEDIA_USECASE_COMPRESSION_FAILED | 422 | INTERNAL | 圧縮に失敗しました | 圧縮設定を確認してください |
| MEDIA_USECASE_FORMAT_CONVERSION_FAILED | 422 | INTERNAL | 形式変換に失敗しました | サポートされる形式を確認してください |

## インフラストラクチャ層エラー

### データベースエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MEDIA_INFRA_DATABASE_CONNECTION_FAILED | 503 | UNAVAILABLE | データベース接続失敗 | 接続設定を確認してください |
| MEDIA_INFRA_DATABASE_QUERY_FAILED | 500 | INTERNAL | クエリ実行失敗 | クエリを確認してください |
| MEDIA_INFRA_DATABASE_TRANSACTION_FAILED | 500 | INTERNAL | トランザクション失敗 | 再試行してください |

### ストレージエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MEDIA_INFRA_STORAGE_CONNECTION_FAILED | 503 | UNAVAILABLE | ストレージ接続失敗 | 接続設定を確認してください |
| MEDIA_INFRA_STORAGE_UPLOAD_FAILED | 500 | INTERNAL | ストレージアップロード失敗 | 再試行してください |
| MEDIA_INFRA_STORAGE_DOWNLOAD_FAILED | 500 | INTERNAL | ストレージダウンロード失敗 | 再試行してください |
| MEDIA_INFRA_STORAGE_DELETE_FAILED | 500 | INTERNAL | ストレージ削除失敗 | 再試行してください |
| MEDIA_INFRA_S3_ERROR | 502 | INTERNAL | S3エラー | S3設定を確認してください |

### 画像処理エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MEDIA_INFRA_IMAGE_PROCESSING_ERROR | 422 | INTERNAL | 画像処理エラー | 画像ファイルを確認してください |
| MEDIA_INFRA_VIDEO_PROCESSING_ERROR | 422 | INTERNAL | 動画処理エラー | 動画ファイルを確認してください |
| MEDIA_INFRA_FFMPEG_ERROR | 422 | INTERNAL | FFmpegエラー | エンコード設定を確認してください |
| MEDIA_INFRA_IMAGEMAGICK_ERROR | 422 | INTERNAL | ImageMagickエラー | 画像変換設定を確認してください |

### CDNエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MEDIA_INFRA_CDN_CONNECTION_FAILED | 503 | UNAVAILABLE | CDN接続失敗 | CDN設定を確認してください |
| MEDIA_INFRA_CDN_UPLOAD_FAILED | 500 | INTERNAL | CDNアップロード失敗 | 再試行してください |
| MEDIA_INFRA_CDN_INVALIDATION_FAILED | 500 | INTERNAL | CDN無効化失敗 | CDN設定を確認してください |

### キャッシュエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MEDIA_INFRA_CACHE_CONNECTION_FAILED | 503 | UNAVAILABLE | キャッシュ接続失敗 | 接続設定を確認してください |
| MEDIA_INFRA_CACHE_OPERATION_FAILED | 500 | INTERNAL | キャッシュ操作失敗 | 再試行してください |
| MEDIA_INFRA_CACHE_MISS | 404 | NOT_FOUND | キャッシュミス | キャッシュの再生成を待ってください |

### メッセージキューエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MEDIA_INFRA_QUEUE_CONNECTION_FAILED | 503 | UNAVAILABLE | キュー接続失敗 | 接続設定を確認してください |
| MEDIA_INFRA_QUEUE_PUBLISH_FAILED | 500 | INTERNAL | メッセージ発行失敗 | 再試行してください |
| MEDIA_INFRA_QUEUE_CONSUME_FAILED | 500 | INTERNAL | メッセージ消費失敗 | メッセージ形式を確認してください |

### セキュリティサービスエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MEDIA_INFRA_VIRUS_SCANNER_ERROR | 502 | INTERNAL | ウイルススキャナーエラー | スキャナーサービスを確認してください |
| MEDIA_INFRA_CONTENT_FILTER_ERROR | 502 | INTERNAL | コンテンツフィルターエラー | フィルターサービスを確認してください |
| MEDIA_INFRA_HASH_GENERATION_FAILED | 500 | INTERNAL | ハッシュ生成失敗 | ハッシュ計算を確認してください |

### ハンドラー層エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MEDIA_HANDLER_BAD_REQUEST | 400 | INVALID_ARGUMENT | 不正なリクエスト | リクエスト形式を確認してください |
| MEDIA_HANDLER_PAYLOAD_TOO_LARGE | 413 | INVALID_ARGUMENT | ペイロードサイズ超過 | リクエストサイズを小さくしてください |
| MEDIA_HANDLER_UNSUPPORTED_MEDIA_TYPE | 415 | INVALID_ARGUMENT | サポートされないメディアタイプ | Content-Typeを確認してください |
| MEDIA_HANDLER_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |
| MEDIA_HANDLER_MULTIPART_PARSE_ERROR | 400 | INVALID_ARGUMENT | マルチパート解析エラー | フォーム形式を確認してください |

## 関連ドキュメント

- [Avion エラーコード標準化ガイドライン](../common/errors/error-standards.md)
- [avion-media PRD](./prd.md)
- [avion-media Design Doc](./designdoc.md)