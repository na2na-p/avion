# Design Doc: avion-media

**Author:** Cline
**Last Updated:** 2025/03/30

## 1. Summary (これは何？)

- **一言で:** Avionにおける画像、動画などのメディアファイルのアップロード、保存、配信、およびリモートメディアのキャッシュを行うマイクロサービスを実装します。
- **目的:** メディアファイルの効率的な処理と配信を実現し、S3互換オブジェクトストレージとCDNを活用します。

## テスト戦略

このサービスでは、[共通テスト戦略](../common/testing-strategy.md)に従ってテストを実装します。

### テスト方針
- **TDD必須**: インターフェース定義 → テスト作成 → 実装の順序を厳守
- **カバレッジ目標**: ユニットテスト85%以上、クリティカルパス95%以上
- **テーブル駆動テスト**: 全テストで必須
- **モック生成**: `go.uber.org/mock/gomock`使用

### サービス固有のテスト要件
- **メディア処理パイプラインのテスト**: 画像/動画変換、サムネイル生成のモック化
- **S3互換ストレージのテスト**: ストレージ操作のモック化、Presigned URL生成テスト
- **非同期タスク処理のテスト**: Redis Stream Consumer Groupの処理テスト
- **ファイル形式検証のテスト**: MIME type、ファイルサイズ、セキュリティ検証
- **CDN配信のテスト**: URL生成、キャッシュ制御のテスト
- **リモートメディアキャッシュのテスト**: ActivityPubメディア取得・キャッシュ機能

### E2Eテスト

このサービスのE2Eテストは、[共通E2Eテスト戦略](../common/e2e-testing-strategy.md)に従って実装します。

#### 主要なE2Eテストシナリオ
- メディアアップロードから処理完了まで完全なライフサイクル
- 画像・動画の変換とサムネイル生成処理の確認
- S3互換ストレージへの保存とCDN配信の連携
- メディアファイルのセキュリティ検証と不正ファイル検出
- 異なる形式のメディアファイル処理対応確認
- リモートメディアのプロキシ機能とキャッシュ管理
- メディア削除時の関連データクリーンアップ
- 大容量ファイルの非同期処理と進捗管理

詳細は[共通E2Eテスト戦略ドキュメント](../common/e2e-testing-strategy.md)を参照してください。

詳細は[共通テスト戦略ドキュメント](../common/testing-strategy.md)を参照してください。

## 3. 技術スタック

このサービスでは、[共通Goバックエンド技術スタックガイドライン](../common/architecture/go-backend-framework.md)に従った実装を行います。

### 主要技術
- **HTTPルーティング:** Chi v5
- **RPC:** ConnectRPC
- **ミドルウェア:** 標準net/httpベースの共通ミドルウェア
- **メディア処理:** 画像処理ライブラリ、動画処理ライブラリ、サムネイル生成

詳細な実装パターンおよびライブラリの使用方法については、[ガイドライン](../common/architecture/go-backend-framework.md)を参照してください。

## 4. Background & Links (背景と関連リンク)

- リッチなコンテンツ投稿機能を提供するため。
- メディア処理という専門的な機能を分離し、スケーラビリティを確保するため。
- ActivityPubで受信したリモートメディアの表示パフォーマンス向上のため、キャッシュ機能を提供。
- [PRD: avion-media](./prd.md)
- [Avion アーキテクチャ概要](../common/architecture.md)
- [Database Schema定義](./database-schema.sql)
- [技術要求仕様書](./technical-requirements.md)

## 5. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

- 画像・動画・音声ファイルのアップロード用Presigned URL払い出しAPI (gRPC) の実装。
- アップロードファイルのバリデーション (形式、サイズ)。
- S3互換オブジェクトストレージへのファイル保存 (クライアントがPresigned URLを使用)。
- アップロード完了通知を受け、サムネイル生成等の後処理を非同期実行 (Redis Stream + Consumer Group)。
- 一意なメディアID/URLの割り当て。
- サムネイル生成 (画像、動画、アニメーションGIF静止画)。
- 音声ファイルのMP3変換処理。
- SVGカスタム絵文字のPNG変換処理。
- メディアファイルおよびサムネイルの配信 (CDN経由を推奨)。
- NSFW（センシティブ）フラグと説明文（ALTテキスト）の管理機能。
- バッチアップロード機能の実装。
- ユーザードライブ機能（フォルダ管理、使用量追跡）の実装。
- メディア使用状況追跡機能の実装。
- リモートメディアキャッシュ機能の実装 (内部gRPC API経由、非同期処理)。
- メディア削除機能 (イベント駆動、非同期遅延削除)。
- 管理者向けメディアサイズ制限設定機能。
- Go言語で実装し、Kubernetes上でのステートレス運用を前提とする。
- OpenTelemetryによるトレーシング・メトリクス・ロギング対応。

### Non-Goals (やらないこと)

- **Dropとの関連付け管理:** `avion-post` が担当。
- **UI:** `avion-web` が担当。
- **オブジェクトストレージ/CDN自体の実装。**
- **高度な画像・動画編集機能。**
- **リモートメディアの永続保証。**
- **メディアメタデータのDB管理 (初期)。**
- **Direct Upload to Service (サービスへの直接アップロード)。**
- **動画の形式変換・ストリーミング配信 (v1)。**

## 6. Architecture (どうやって作る？)

### 5.1. レイヤードアーキテクチャ (DDD準拠)

#### Domain Layer (ドメイン層)
- **Aggregates:**
  - Media: メディアファイルのライフサイクルと整合性を管理
  - MediaProcessingTask: 非同期処理タスクの管理
  - RemoteMediaCache: リモートメディアキャッシュ管理
  - MediaBatch: バッチアップロード管理
  - UserDrive: ユーザーのメディアドライブ管理
- **Entities:**
  - Thumbnail: サムネイル画像情報
  - MediaVariant: 動画の変換バリアント（将来実装）
  - GifThumbnail: アニメーションGIFの静止画サムネイル
  - MediaFolder: メディア整理用フォルダ
  - EmojiVariant: PNG変換後のカスタム絵文字
- **Value Objects:**
  - MediaID, MediaType, MediaFormat, FileSize, Dimension
  - StorageKey, PresignedURL, CDNUrl, UploadStatus
  - TaskID, TaskType, TaskStatus, RemoteURL, CacheKey
  - MediaSensitivity, MediaDescription, AudioMetadata
  - MediaUsageStats, ProcessingError, MediaLimits
  - BatchID, BatchStatus, FolderID
- **Domain Services:**
  - MediaValidationPolicy: メディアファイル検証ルール
  - ThumbnailGenerationPolicy: サムネイル生成ポリシー
  - AudioTranscodingPolicy: 音声変換ポリシー
  - EmojiConversionPolicy: 絵文字変換ポリシー
  - MediaStorageService: ストレージ操作のインターフェース
- **Repository Interfaces:**
  - MediaRepository
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_media_repository.go -package=mocks
    ```
  - MediaProcessingTaskRepository
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_media_processing_task_repository.go -package=mocks
    ```
  - RemoteMediaCacheRepository
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_remote_media_cache_repository.go -package=mocks
    ```

#### Use Case Layer (ユースケース層)
- **Command Use Cases (更新系):**
  - RequestMediaUploadCommandUseCase: アップロードURL発行処理（POSTリクエスト用）
  - CompleteMediaUploadCommandUseCase: アップロード完了処理（POSTリクエスト用）
  - ProcessThumbnailGenerationCommandUseCase: サムネイル生成処理（非同期タスク用）
  - ProcessGifThumbnailCommandUseCase: GIF静止画生成処理（非同期タスク用）
  - ProcessAudioTranscodingCommandUseCase: 音声変換処理（非同期タスク用）
  - ConvertSvgEmojiCommandUseCase: SVG絵文字変換処理（非同期タスク用）
  - UpdateMediaSensitivityCommandUseCase: NSFWフラグ更新処理（PATCHリクエスト用）
  - UpdateMediaDescriptionCommandUseCase: 説明文更新処理（PATCHリクエスト用）
  - RequestBatchMediaUploadCommandUseCase: バッチアップロード処理（POSTリクエスト用）
  - OrganizeMediaInDriveCommandUseCase: ドライブ整理処理（POSTリクエスト用）
  - TrackMediaUsageCommandUseCase: メディア使用状況追跡処理（イベントハンドラ用）
  - CacheRemoteMediaCommandUseCase: リモートメディアキャッシュ処理（POSTリクエスト用）
  - DeleteMediaCommandUseCase: メディア削除処理（イベントハンドラ用）
  - UpdateMediaLimitsCommandUseCase: サイズ制限更新処理（管理者API用）
  - NotifyMediaProcessingErrorCommandUseCase: エラー通知処理（非同期タスク用）
- **Query Use Cases (参照系):**
  - GetMediaInfoQueryUseCase: メディア情報取得処理（GETリクエスト用）
  - GetMediaByPathQueryUseCase: パスによるメディア取得処理（GETリクエスト用）
  - GetThumbnailQueryUseCase: サムネイル取得処理（GETリクエスト用）
  - GetCachedRemoteMediaQueryUseCase: キャッシュ済みリモートメディア取得（GETリクエスト用）
  - GetUserDriveContentsQueryUseCase: ドライブ内容取得処理（GETリクエスト用）
  - GetMediaUsageStatsQueryUseCase: 使用状況統計取得処理（GETリクエスト用）
  - GetMediaLimitsQueryUseCase: サイズ制限取得処理（GETリクエスト用）
- **Query Service Interfaces:**
  - MediaQueryService: メディア情報参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_media_query_service.go -package=mocks
    ```
  - ThumbnailQueryService: サムネイル参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_thumbnail_query_service.go -package=mocks
    ```
  - RemoteMediaCacheQueryService: キャッシュ参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_remote_media_cache_query_service.go -package=mocks
    ```
  - UserDriveQueryService: ドライブ参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_user_drive_query_service.go -package=mocks
    ```
  - MediaUsageQueryService: 使用状況参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_media_usage_query_service.go -package=mocks
    ```
- **DTOs:**
  - MediaUploadRequestDTO, MediaInfoDTO, ThumbnailDTO
  - BatchUploadRequestDTO, MediaFolderDTO, MediaUsageStatsDTO
  - MediaLimitsDTO, ProcessingErrorDTO等
- **External Service Interfaces:**
  - S3StorageService: S3操作インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_s3_storage_service.go -package=mocks
    ```
  - EventSubscriber: イベント購読インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_event_subscriber.go -package=mocks
    ```

#### Infrastructure Layer (インフラストラクチャ層)
- **Repository Implementations (更新系):**
  - S3MediaRepository: Media永続化実装
  - RedisMediaProcessingTaskRepository: タスク管理実装
  - S3RemoteMediaCacheRepository: キャッシュ永続化実装
  - S3MediaBatchRepository: バッチ管理実装
  - S3UserDriveRepository: ドライブ管理実装
- **Query Service Implementations (参照系):**
  - S3MediaQueryService: メディア参照専用実装
  - S3ThumbnailQueryService: サムネイル参照専用実装
  - S3RemoteMediaCacheQueryService: キャッシュ参照専用実装
  - S3UserDriveQueryService: ドライブ参照専用実装
  - RedisMediaUsageQueryService: 使用状況参照専用実装
- **External Service Implementations:**
  - AWSS3StorageService: S3操作実装
  - RedisStreamTaskQueue: タスクキュー実装
  - RedisEventSubscriber: イベント購読実装
  - ConfigMediaLimitsService: 制限設定管理実装
- **Media Processing:**
  - ImageProcessor: 画像処理実装
  - VideoProcessor: 動画処理実装
  - AudioProcessor: 音声処理実装
  - ThumbnailGenerator: サムネイル生成実装
  - GifProcessor: GIF処理実装
  - SvgToImageConverter: SVG変換実装

#### Handler Layer (ハンドラー層)
- **Command Handlers (更新系):**
  - RequestMediaUploadCommandHandler: アップロードURL発行エンドポイント（POST）
  - CompleteMediaUploadCommandHandler: アップロード完了エンドポイント（POST）
  - RequestBatchMediaUploadCommandHandler: バッチアップロードエンドポイント（POST）
  - UpdateMediaSensitivityCommandHandler: NSFWフラグ更新エンドポイント（PATCH）
  - UpdateMediaDescriptionCommandHandler: 説明文更新エンドポイント（PATCH）
  - OrganizeMediaInDriveCommandHandler: ドライブ整理エンドポイント（POST）
  - CacheRemoteMediaCommandHandler: リモートメディアキャッシュエンドポイント（POST）
  - UpdateMediaLimitsCommandHandler: サイズ制限更新エンドポイント（PUT）
- **Query Handlers (参照系):**
  - GetMediaInfoQueryHandler: メディア情報取得エンドポイント（GET）
  - MediaFileQueryHandler: メディアファイル配信エンドポイント（GET）
  - ThumbnailFileQueryHandler: サムネイル配信エンドポイント（GET）
  - GetUserDriveContentsQueryHandler: ドライブ内容取得エンドポイント（GET）
  - GetMediaUsageStatsQueryHandler: 使用状況取得エンドポイント（GET）
  - GetMediaLimitsQueryHandler: サイズ制限取得エンドポイント（GET）
- **Event Handlers:**
  - MediaProcessingEventHandler: 非同期処理タスクハンドラー（Command処理）
  - DropDeletedEventHandler: Drop削除イベントハンドラー（Command処理）
  - MediaAttachedEventHandler: メディア添付イベントハンドラー（使用状況追跡）
- **Worker Handlers:**
  - ThumbnailGenerationWorker: サムネイル生成ワーカー
  - GifThumbnailWorker: GIF静止画生成ワーカー
  - AudioTranscodingWorker: 音声変換ワーカー
  - SvgEmojiConversionWorker: SVG絵文字変換ワーカー
  - RemoteMediaCacheWorker: リモートメディアキャッシュワーカー
  - MediaDeletionWorker: メディア削除ワーカー
  - ProcessingErrorNotificationWorker: エラー通知ワーカー

### 5.2. 詳細ドメインモデル（DDD戦術パターン）

本セクションでは、PRDで定義された要件を基に、DDDの戦術的パターンを適用した詳細なドメインモデルを示します。各集約とエンティティには厳密な不変条件とドメインロジックが定義されています。

#### Media Aggregate (メディア集約)

**責務**: メディアファイルのライフサイクル全体と関連情報を管理する中核集約
- **集約ルート**: Media
- **不変条件**:
  - MediaIDは変更不可（Snowflake ID）
  - ファイルサイズ上限：画像20MB、動画300MB、音声20MB
  - 対応形式：JPEG, PNG, GIF, WebP（画像）、MP4, WebM（動画）、MP3, AAC（音声）
  - 一度アップロードされたメディアのバイナリは変更不可
  - StorageKeyは一意かつ変更不可
  - 削除されたメディアは30日後に物理削除
  - NSFWフラグ設定後は管理者以外変更不可
  - アップロード完了前のメディアは参照不可
  - 同一ユーザーの同時アップロード数は10まで
  - メディアの説明文は最大2000文字

- **ドメインロジック**:
  - `canBeViewedBy(viewerID, viewerContext)`: メディア閲覧権限の判定（所有者、公開範囲、NSFW設定考慮）
  - `canBeDeletedBy(deleterID, adminContext)`: 削除権限の判定（所有者または管理者）
  - `validateFormat(file)`: ファイル形式の妥当性検証（MIMEタイプ、マジックナンバー確認）
  - `validateSize(fileSize, mediaType)`: ファイルサイズ制限の検証
  - `generateStorageKey()`: ユニークなストレージキーの生成（ハッシュベース）
  - `markAsProcessed()`: 処理完了マーク（サムネイル生成後）
  - `markAsSensitive(moderatorID)`: NSFWマーク付与（権限確認）
  - `updateDescription(description, updaterID)`: 説明文更新（権限確認、文字数制限）
  - `calculateStorageCost()`: ストレージコストの計算
  - `scheduleExpiration()`: 有効期限の設定（一時メディア用）
  - `toActivityPubDocument()`: ActivityPub Document形式への変換
  - `generatePresignedUrl(expiry)`: 署名付きURL生成（期限付き）
  - `extractMetadata()`: メタデータ抽出（EXIF、動画情報等）

#### MediaProcessingTask Aggregate (メディア処理タスク集約)

**責務**: 非同期メディア処理タスクの管理と実行状態を追跡
- **集約ルート**: MediaProcessingTask
- **不変条件**:
  - TaskIDは変更不可
  - TaskTypeは定義された値のみ（thumbnail, transcode, emoji_convert等）
  - TaskStatusは有効な状態遷移のみ（pending→processing→completed/failed）
  - リトライ回数は最大3回
  - 処理タイムアウトは5分
  - 失敗タスクは24時間後に自動削除
  - 優先度は1-10の範囲
  - 同一メディアの同一タスクタイプは重複不可

- **ドメインロジック**:
  - `canRetry()`: リトライ可能判定（回数制限、エラータイプ確認）
  - `scheduleRetry()`: リトライスケジューリング（指数バックオフ）
  - `markAsProcessing()`: 処理開始マーク（タイムスタンプ記録）
  - `markAsCompleted(result)`: 完了マーク（結果保存）
  - `markAsFailed(error)`: 失敗マーク（エラー詳細記録）
  - `isTimedOut(currentTime)`: タイムアウト判定
  - `calculatePriority()`: 優先度計算（メディアタイプ、ユーザー種別基準）
  - `shouldCircuitBreak()`: サーキットブレーカー発動判定
  - `getEstimatedProcessingTime()`: 処理時間推定
  - `cancelTask(reason)`: タスクキャンセル（理由記録）

#### RemoteMediaCache Aggregate (リモートメディアキャッシュ集約)

**責務**: 外部サーバーのメディアキャッシュを管理
- **集約ルート**: RemoteMediaCache
- **不変条件**:
  - RemoteURLとCacheKeyの組み合わせは一意
  - キャッシュ有効期限は最大7日
  - キャッシュサイズ上限は元メディアと同じ
  - HTTPSのURLのみキャッシュ可能
  - キャッシュヒット率が10%未満のメディアは自動削除対象
  - 同一URLの同時キャッシュリクエストは1つに統合

- **ドメインロジック**:
  - `isExpired(currentTime)`: 有効期限切れ判定
  - `shouldRefresh()`: 更新必要性判定（アクセス頻度基準）
  - `canCache(url)`: キャッシュ可能判定（URL検証、ブラックリスト確認）
  - `updateAccessStats()`: アクセス統計更新
  - `calculateCacheScore()`: キャッシュ優先度スコア計算
  - `markForEviction()`: 削除対象マーク
  - `validateRemoteContent(content)`: リモートコンテンツ検証
  - `generateCacheKey(url)`: キャッシュキー生成
  - `recordHit()`: キャッシュヒット記録
  - `recordMiss()`: キャッシュミス記録

#### MediaBatch Aggregate (メディアバッチ集約)

**責務**: 複数メディアの一括アップロードを管理
- **集約ルート**: MediaBatch
- **不変条件**:
  - BatchIDは変更不可
  - バッチ内のメディア数は最大10個
  - バッチ全体のサイズ上限は100MB
  - バッチ処理は原子性を保証（全成功または全失敗）
  - バッチ作成から30分以内に完了必須
  - 部分的な失敗時は全体をロールバック

- **ドメインロジック**:
  - `addMedia(media)`: メディア追加（制限チェック）
  - `canAddMore()`: 追加可能判定（個数、サイズ制限）
  - `validateBatch()`: バッチ全体の妥当性検証
  - `processAll()`: 一括処理実行
  - `rollback()`: ロールバック処理
  - `isComplete()`: 完了判定
  - `getProgress()`: 進捗率取得
  - `cancelBatch(reason)`: バッチキャンセル
  - `resumeProcessing()`: 処理再開
  - `calculateTotalSize()`: 合計サイズ計算

#### UserDrive Aggregate (ユーザードライブ集約)

**責務**: ユーザーのメディアストレージ使用状況を管理
- **集約ルート**: UserDrive
- **不変条件**:
  - UserIDは変更不可
  - ストレージ容量上限：無料5GB、有料50GB
  - 使用容量は非負整数
  - フォルダ階層は最大5階層
  - フォルダ名は最大100文字
  - 同一階層に同名フォルダは作成不可
  - ルートフォルダは削除不可

- **ドメインロジック**:
  - `hasCapacity(size)`: 容量確認（現在使用量と上限比較）
  - `addUsage(size)`: 使用量追加
  - `reduceUsage(size)`: 使用量削減
  - `createFolder(name, parentID)`: フォルダ作成（階層制限確認）
  - `moveMedia(mediaID, targetFolderID)`: メディア移動
  - `calculateUsagePercentage()`: 使用率計算
  - `isOverQuota()`: 容量超過判定
  - `upgradeStorage(plan)`: ストレージプラン変更
  - `getOrganizationStructure()`: フォルダ構造取得
  - `cleanupExpiredMedia()`: 期限切れメディアクリーンアップ

### 5.3. 主要コンポーネント

- **主要コンポーネント:**
    - `avion-media (Go, Kubernetes Deployment)`: 本サービス。gRPCサーバー、非同期処理ワーカ (Redis Stream Consumer)。
    - `avion-gateway (Go)`: gRPCリクエストのルーティング元。
    - `avion-drop (Go)`: Drop削除イベント発行元 (Pub/Sub)。
    - `avion-activitypub (Go)`: リモートメディアキャッシュ依頼元 (gRPC)。
    - `S3互換オブジェクトストレージ`: ファイル永続化。
    - `CDN`: ファイル配信。
    - `Redis`: 非同期処理キュー (Stream)。
    - `Observability Stack`: メトリクス、トレース、ログ収集。
- **構成図:** (アーキテクチャ概要図を参照)
    - [Avion アーキテクチャ概要](../common/architecture.md)
- **ポイント:**
    - アップロードはPresigned URL方式を採用し、クライアントからS3へ直接行う。
    - サムネイル生成などの後処理は非同期ワーカで実行。
    - ファイルの実体はS3互換ストレージに保存。
    - 配信はCDNを介して行うことを基本とする。
    - リモートメディアキャッシュも非同期で行う。
    - メディア削除はイベント駆動の遅延削除。
    - ステートレス設計 (処理キューはRedis Streamで管理)。
    - CQRS適用により更新系と参照系を明確に分離。

### ドメインモデル設計（DDD戦術的パターン）

#### Aggregate（集約ルート）

**Media Aggregate**
- 集約ルート: Media（アップロードされたメディアファイル）
- ID: MediaID（Value Object）
- 主要フィールド:
  - MediaType（Value Object）: 'image', 'video', 'audio'
  - MediaFormat（Value Object）: JPEG, PNG, GIF, WebP, MP4, MP3など
  - FileSize（Value Object）: ファイルサイズ
  - Dimension（Value Object）: 幅・高さ（画像・動画）
  - ContentType（Value Object）: MIMEタイプ
  - StorageKey（Value Object）: S3オブジェクトキー
  - StorageURL（Value Object）: S3 URL
  - UploadStatus（Value Object）: 'pending', 'processing', 'completed', 'failed'
  - CDNUrl（Value Object）: CDN経由の配信URL
  - MediaMetadata（Value Object）: EXIF情報、動画長さなど
  - AudioMetadata（Value Object）: 音声長さ、ビットレート、コーデック
  - MediaSensitivity（Value Object）: NSFWフラグ
  - MediaDescription（Value Object）: ALTテキスト（最大1,500文字）
- 関連Entity:
  - Thumbnail（Entity）: サムネイル画像情報
  - MediaVariant（Entity）: 動画の変換バリアント（将来実装）
  - GifThumbnail（Entity）: アニメーションGIFの静止画
- **ドメイン不変条件（Invariants）:**
  - MediaID は一意で、一度割り当てられたら変更不可
  - MediaType と MediaFormat は対応関係が正しい（例: video タイプに jpeg フォーマットは不可）
  - FileSize は 0 より大きく、管理者設定の上限以下
  - Dimension は MediaType が image または video の場合のみ設定可能
  - UploadStatus が 'completed' の場合、StorageKey と StorageURL は必須
  - MediaDescription は最大1,500文字、UTF-8エンコード
  - AudioMetadata は MediaType が 'audio' の場合のみ設定可能
  - Thumbnail は MediaType が image または video の場合のみ生成可能

- **ドメインロジック（Business Rules）:**
```go
// Media Aggregate のドメインロジック例
type Media struct {
    // フィールド定義...
}

// ファイル形式検証
func (m *Media) ValidateFormat() error {
    validFormats := map[MediaType][]string{
        Image: {"jpeg", "png", "gif", "webp", "svg"},
        Video: {"mp4", "mov", "webm", "m4v"},
        Audio: {"mp3", "ogg", "wav", "flac", "opus", "aac", "m4a", "3gp"},
    }
    
    allowedFormats, exists := validFormats[m.mediaType]
    if !exists {
        return NewValidationError("UNSUPPORTED_MEDIA_TYPE", "Media type not supported")
    }
    
    for _, format := range allowedFormats {
        if m.format.String() == format {
            return nil
        }
    }
    
    return NewValidationError("INVALID_FORMAT", 
        fmt.Sprintf("Format %s not supported for %s", m.format, m.mediaType))
}

// サイズ制限検証
func (m *Media) ValidateSize(limits MediaLimits) error {
    maxSize := limits.GetMaxSizeFor(m.mediaType)
    if m.fileSize.Bytes() > maxSize {
        return NewValidationError("FILE_TOO_LARGE", 
            fmt.Sprintf("File size %d exceeds limit %d", m.fileSize.Bytes(), maxSize))
    }
    
    if m.fileSize.Bytes() <= 0 {
        return NewValidationError("INVALID_FILE_SIZE", "File size must be greater than 0")
    }
    
    return nil
}

// アップロード完了処理
func (m *Media) CompleteUpload(storageKey StorageKey, storageURL StorageURL) error {
    if m.uploadStatus != Pending {
        return NewBusinessRuleViolation("INVALID_STATUS_TRANSITION", 
            fmt.Sprintf("Cannot complete upload from status %s", m.uploadStatus))
    }
    
    m.storageKey = storageKey
    m.storageURL = storageURL
    m.uploadStatus = Completed
    m.updatedAt = time.Now()
    
    // ドメインイベント発行
    m.addDomainEvent(MediaUploadCompleted{
        MediaID:   m.id,
        MediaType: m.mediaType,
        FileSize:  m.fileSize,
        Timestamp: time.Now(),
    })
    
    return nil
}

// サムネイル生成可否判定
func (m *Media) CanGenerateThumbnail() bool {
    return m.mediaType == Image || m.mediaType == Video
}

// 音声変換可否判定
func (m *Media) RequiresAudioTranscoding() bool {
    if m.mediaType != Audio {
        return false
    }
    
    // MP3以外は変換が必要
    return m.format.String() != "mp3"
}

// NSFW設定の更新
func (m *Media) UpdateSensitivity(sensitivity MediaSensitivity, updatedBy UserID) error {
    if m.uploadStatus != Completed {
        return NewBusinessRuleViolation("MEDIA_NOT_READY", 
            "Cannot update sensitivity of incomplete media")
    }
    
    oldSensitivity := m.sensitivity
    m.sensitivity = sensitivity
    m.updatedAt = time.Now()
    
    // ドメインイベント発行
    m.addDomainEvent(MediaSensitivityUpdated{
        MediaID:       m.id,
        OldValue:      oldSensitivity,
        NewValue:      sensitivity,
        UpdatedBy:     updatedBy,
        Timestamp:     time.Now(),
    })
    
    return nil
}

// 説明文の更新
func (m *Media) UpdateDescription(description MediaDescription, updatedBy UserID) error {
    if m.uploadStatus != Completed {
        return NewBusinessRuleViolation("MEDIA_NOT_READY", 
            "Cannot update description of incomplete media")
    }
    
    if err := description.Validate(); err != nil {
        return err
    }
    
    oldDescription := m.description
    m.description = description
    m.updatedAt = time.Now()
    
    // ドメインイベント発行
    m.addDomainEvent(MediaDescriptionUpdated{
        MediaID:       m.id,
        OldValue:      oldDescription,
        NewValue:      description,
        UpdatedBy:     updatedBy,
        Timestamp:     time.Now(),
    })
    
    return nil
}

// 削除可能性の判定
func (m *Media) CanBeDeleted(usageStats MediaUsageStats) bool {
    // 使用中のメディアは削除不可
    return usageStats.UsageCount() == 0
}

// CDN URL生成
func (m *Media) GenerateCDNURL(cdnBaseURL string) CDNUrl {
    if m.uploadStatus != Completed {
        return CDNUrl{}
    }
    
    path := strings.Replace(m.storageKey.String(), "original/", "", 1)
    return CDNUrl{Value: fmt.Sprintf("%s/media/%s", cdnBaseURL, path)}
}

// サムネイル追加（ファクトリーメソッド）
func (m *Media) AddThumbnail(size Size, dimension Dimension, storageKey StorageKey) (*Thumbnail, error) {
    if !m.CanGenerateThumbnail() {
        return nil, NewBusinessRuleViolation("THUMBNAIL_NOT_SUPPORTED", 
            fmt.Sprintf("Thumbnails not supported for media type %s", m.mediaType))
    }
    
    if m.uploadStatus != Completed {
        return nil, NewBusinessRuleViolation("MEDIA_NOT_READY", 
            "Cannot generate thumbnail for incomplete media")
    }
    
    thumbnail := NewThumbnail(m.id, size, dimension, storageKey)
    m.thumbnails = append(m.thumbnails, *thumbnail)
    
    // ドメインイベント発行
    m.addDomainEvent(ThumbnailGenerated{
        MediaID:     m.id,
        ThumbnailID: thumbnail.id,
        Size:        size,
        Timestamp:   time.Now(),
    })
    
    return thumbnail, nil
}
```

**MediaProcessingTask Aggregate**
- 集約ルート: MediaProcessingTask（非同期処理タスク）
- ID: TaskID（Value Object）
- 主要フィールド:
  - TaskType（Value Object）: 'thumbnail_generation', 'gif_thumbnail', 'audio_transcoding', 'svg_conversion', 'remote_cache', 'deletion'
  - TaskStatus（Value Object）: 'pending', 'processing', 'completed', 'failed'
  - TargetMediaID（Value Object）: 処理対象のMediaID
  - RetryCount（Value Object）: リトライ回数
  - ScheduledAt（Value Object）: 実行予定時刻
  - ProcessedAt（Value Object）: 処理完了時刻
  - ProcessingError（Value Object）: エラー情報
- **ドメイン不変条件（Invariants）:**
  - TaskID は一意で、一度割り当てられたら変更不可
  - TaskStatus の状態遷移は決められた順序のみ許可
  - RetryCount は MaxRetries を超えない
  - ScheduledAt は過去または現在の時刻
  - ProcessedAt は TaskStatus が 'completed' または 'failed' の場合のみ設定
  - TargetMediaID は有効なMediaIDを参照

- **ドメインロジック（Business Rules）:**
```go
type MediaProcessingTask struct {
    // フィールド定義...
}

// タスクの実行可否判定
func (t *MediaProcessingTask) CanExecute() bool {
    now := time.Now()
    return t.taskStatus == Pending && 
           t.scheduledAt.Before(now) &&
           t.retryCount <= t.maxRetries
}

// 状態遷移の検証
func (t *MediaProcessingTask) validateStatusTransition(newStatus TaskStatus) error {
    validTransitions := map[TaskStatus][]TaskStatus{
        Pending:    {Processing, Failed},
        Processing: {Completed, Failed},
        Completed:  {}, // 終了状態
        Failed:     {Pending}, // リトライ時のみ
    }
    
    allowed, exists := validTransitions[t.taskStatus]
    if !exists {
        return NewBusinessRuleViolation("INVALID_CURRENT_STATUS", 
            fmt.Sprintf("Invalid current status: %s", t.taskStatus))
    }
    
    for _, validStatus := range allowed {
        if validStatus == newStatus {
            return nil
        }
    }
    
    return NewBusinessRuleViolation("INVALID_STATUS_TRANSITION", 
        fmt.Sprintf("Cannot transition from %s to %s", t.taskStatus, newStatus))
}

// タスク開始
func (t *MediaProcessingTask) StartProcessing() error {
    if !t.CanExecute() {
        return NewBusinessRuleViolation("TASK_NOT_EXECUTABLE", 
            "Task cannot be executed in current state")
    }
    
    if err := t.validateStatusTransition(Processing); err != nil {
        return err
    }
    
    t.taskStatus = Processing
    t.addDomainEvent(TaskProcessingStarted{
        TaskID:    t.id,
        TaskType:  t.taskType,
        MediaID:   t.targetMediaID,
        Timestamp: time.Now(),
    })
    
    return nil
}

// タスク完了
func (t *MediaProcessingTask) MarkCompleted() error {
    if err := t.validateStatusTransition(Completed); err != nil {
        return err
    }
    
    t.taskStatus = Completed
    t.processedAt = time.Now()
    
    t.addDomainEvent(TaskCompleted{
        TaskID:    t.id,
        TaskType:  t.taskType,
        MediaID:   t.targetMediaID,
        Duration:  t.processedAt.Sub(t.scheduledAt),
        Timestamp: time.Now(),
    })
    
    return nil
}

// タスク失敗とリトライ判定
func (t *MediaProcessingTask) MarkFailed(err ProcessingError) error {
    if validateErr := t.validateStatusTransition(Failed); validateErr != nil {
        return validateErr
    }
    
    t.taskStatus = Failed
    t.processedAt = time.Now()
    t.errorInfo = err
    
    shouldRetry := t.shouldRetry(err)
    if shouldRetry {
        t.retryCount++
        t.scheduledAt = t.calculateNextRetryTime(err)
        t.taskStatus = Pending // 自動的にリトライ待ちに
        
        t.addDomainEvent(TaskRetryScheduled{
            TaskID:      t.id,
            RetryCount:  t.retryCount,
            NextRetryAt: t.scheduledAt,
            Error:       err,
            Timestamp:   time.Now(),
        })
    } else {
        t.addDomainEvent(TaskFailed{
            TaskID:    t.id,
            TaskType:  t.taskType,
            MediaID:   t.targetMediaID,
            Error:     err,
            Final:     true,
            Timestamp: time.Now(),
        })
    }
    
    return nil
}

// リトライ可否判定
func (t *MediaProcessingTask) shouldRetry(err ProcessingError) bool {
    // 致命的エラーの場合はリトライしない
    if err.Fatal {
        return false
    }
    
    // リトライ上限チェック
    if t.retryCount >= t.maxRetries {
        return false
    }
    
    // エラー種別によるリトライ判定
    retryableErrors := []string{
        "NETWORK_ERROR",
        "TEMPORARY_FAILURE",
        "RESOURCE_BUSY",
        "TIMEOUT",
    }
    
    for _, retryableError := range retryableErrors {
        if err.ErrorCode == retryableError {
            return true
        }
    }
    
    return false
}

// 次回リトライ時間の計算
func (t *MediaProcessingTask) calculateNextRetryTime(err ProcessingError) time.Time {
    baseDelay := 30 * time.Second
    maxDelay := 30 * time.Minute
    
    // Exponential backoff
    delay := time.Duration(float64(baseDelay) * math.Pow(2.0, float64(t.retryCount)))
    if delay > maxDelay {
        delay = maxDelay
    }
    
    // Jitter追加（±10%）
    jitter := time.Duration(rand.Float64() * float64(delay) * 0.2 - float64(delay) * 0.1)
    delay += jitter
    
    return time.Now().Add(delay)
}

// エラー通知判定
func (t *MediaProcessingTask) ShouldNotifyUser(err ProcessingError) bool {
    // 最終的な失敗の場合は通知
    if t.retryCount >= t.maxRetries {
        return true
    }
    
    // ユーザーアクションが必要なエラーは即座に通知
    userActionRequired := []string{
        "INVALID_FILE_FORMAT",
        "FILE_CORRUPTED",
        "FILE_TOO_LARGE",
    }
    
    for _, errorCode := range userActionRequired {
        if err.ErrorCode == errorCode {
            return true
        }
    }
    
    return false
}
```

**RemoteMediaCache Aggregate**
- 集約ルート: RemoteMediaCache（リモートメディアのキャッシュ）
- ID: CacheKey（Value Object）: RemoteURLのハッシュ値
- 主要フィールド:
  - RemoteURL（Value Object）: オリジナルのURL
  - LocalMediaID（Value Object）: ローカルに保存したMediaID
  - CachedAt（Value Object）: キャッシュ日時
  - LastAccessedAt（Value Object）: 最終アクセス日時
  - CacheStatus（Value Object）: 'active', 'expired', 'deleted'
- **ドメイン不変条件（Invariants）:**
  - CacheKey は RemoteURL のハッシュ値で一意
  - RemoteURL は有効なURL形式
  - LocalMediaID は有効なMediaIDを参照
  - CachedAt は過去または現在の時刻
  - LastAccessedAt は CachedAt 以降の時刻
  - CacheStatus が 'active' の場合、LocalMediaID は必須

- **ドメインロジック（Business Rules）:**
```go
type RemoteMediaCache struct {
    // フィールド定義...
}

// キャッシュ有効性の判定
func (c *RemoteMediaCache) IsValid() bool {
    if c.cacheStatus != Active {
        return false
    }
    
    // 有効期限チェック（デフォルト30日）
    maxAge := 30 * 24 * time.Hour
    return time.Since(c.cachedAt) < maxAge
}

// キャッシュ更新必要性の判定
func (c *RemoteMediaCache) NeedsRefresh() bool {
    // 期限切れの場合
    if !c.IsValid() {
        return true
    }
    
    // 長期間アクセスされていない場合（7日）
    stalePeriod := 7 * 24 * time.Hour
    if time.Since(c.lastAccessedAt) > stalePeriod {
        return true
    }
    
    return false
}

// アクセス記録
func (c *RemoteMediaCache) RecordAccess() error {
    if c.cacheStatus != Active {
        return NewBusinessRuleViolation("CACHE_NOT_ACTIVE", 
            "Cannot record access for inactive cache")
    }
    
    c.lastAccessedAt = time.Now()
    
    c.addDomainEvent(RemoteMediaAccessed{
        CacheKey:  c.cacheKey,
        RemoteURL: c.remoteURL,
        Timestamp: time.Now(),
    })
    
    return nil
}

// キャッシュ作成
func (c *RemoteMediaCache) Activate(localMediaID MediaID) error {
    if c.cacheStatus == Active {
        return NewBusinessRuleViolation("ALREADY_ACTIVE", 
            "Cache is already active")
    }
    
    c.localMediaID = localMediaID
    c.cacheStatus = Active
    c.cachedAt = time.Now()
    c.lastAccessedAt = time.Now()
    
    c.addDomainEvent(RemoteMediaCached{
        CacheKey:     c.cacheKey,
        RemoteURL:    c.remoteURL,
        LocalMediaID: localMediaID,
        Timestamp:    time.Now(),
    })
    
    return nil
}

// 削除可否判定
func (c *RemoteMediaCache) CanBeDeleted() bool {
    // 非アクティブまたは期限切れは削除可能
    return c.cacheStatus != Active || !c.IsValid()
}

// キャッシュ削除
func (c *RemoteMediaCache) MarkForDeletion() error {
    if !c.CanBeDeleted() {
        return NewBusinessRuleViolation("CANNOT_DELETE_ACTIVE_CACHE", 
            "Cannot delete active and valid cache")
    }
    
    c.cacheStatus = Deleted
    
    c.addDomainEvent(RemoteMediaCacheDeleted{
        CacheKey:     c.cacheKey,
        RemoteURL:    c.remoteURL,
        LocalMediaID: c.localMediaID,
        Timestamp:    time.Now(),
    })
    
    return nil
}

// URL安全性チェック
func (c *RemoteMediaCache) ValidateRemoteURL() error {
    parsedURL, err := url.Parse(c.remoteURL.String())
    if err != nil {
        return NewValidationError("INVALID_URL", "Remote URL is not valid")
    }
    
    // HTTPS必須
    if parsedURL.Scheme != "https" {
        return NewValidationError("INSECURE_URL", "Remote URL must use HTTPS")
    }
    
    // ローカルホスト禁止
    if parsedURL.Hostname() == "localhost" || 
       parsedURL.Hostname() == "127.0.0.1" ||
       strings.HasSuffix(parsedURL.Hostname(), ".local") {
        return NewValidationError("LOCAL_URL_FORBIDDEN", 
            "Local URLs are not allowed for remote caching")
    }
    
    return nil
}
```

**MediaBatch Aggregate**
- 集約ルート: MediaBatch（バッチアップロード）
- ID: BatchID（Value Object）
- 主要フィールド:
  - MediaIDs（Value Object）: バッチ内のMediaIDリスト
  - BatchStatus（Value Object）: 'pending', 'processing', 'completed', 'partial_failed'
  - TotalCount（Value Object）: 総ファイル数
  - CompletedCount（Value Object）: 完了ファイル数
  - FailedCount（Value Object）: 失敗ファイル数
  - CreatedAt（Value Object）: 作成日時
- **ドメイン不変条件（Invariants）:**
  - BatchID は一意で、一度割り当てられたら変更不可
  - MediaIDs リストは空でない
  - TotalCount = len(MediaIDs)
  - CompletedCount + FailedCount ≤ TotalCount
  - BatchStatus の状態遷移は決められた順序のみ許可

- **ドメインロジック（Business Rules）:**
```go
type MediaBatch struct {
    // フィールド定義...
}

// バッチ完了判定
func (b *MediaBatch) IsCompleted() bool {
    return b.completedCount + b.failedCount == b.totalCount
}

// 部分失敗の判定
func (b *MediaBatch) HasPartialFailure() bool {
    return b.IsCompleted() && b.failedCount > 0 && b.completedCount > 0
}

// 進捗率計算
func (b *MediaBatch) CalculateProgress() float64 {
    if b.totalCount == 0 {
        return 0.0
    }
    return float64(b.completedCount + b.failedCount) / float64(b.totalCount)
}

// 成功率計算
func (b *MediaBatch) CalculateSuccessRate() float64 {
    processed := b.completedCount + b.failedCount
    if processed == 0 {
        return 0.0
    }
    return float64(b.completedCount) / float64(processed)
}

// メディア完了報告
func (b *MediaBatch) ReportMediaCompleted(mediaID MediaID) error {
    if !b.containsMediaID(mediaID) {
        return NewBusinessRuleViolation("MEDIA_NOT_IN_BATCH", 
            "Media ID not found in batch")
    }
    
    if b.batchStatus == Completed {
        return NewBusinessRuleViolation("BATCH_ALREADY_COMPLETED", 
            "Cannot update completed batch")
    }
    
    b.completedCount++
    
    // バッチ状態の更新
    b.updateBatchStatus()
    
    b.addDomainEvent(BatchMediaCompleted{
        BatchID:   b.batchID,
        MediaID:   mediaID,
        Progress:  b.CalculateProgress(),
        Timestamp: time.Now(),
    })
    
    return nil
}

// メディア失敗報告
func (b *MediaBatch) ReportMediaFailed(mediaID MediaID, reason string) error {
    if !b.containsMediaID(mediaID) {
        return NewBusinessRuleViolation("MEDIA_NOT_IN_BATCH", 
            "Media ID not found in batch")
    }
    
    if b.batchStatus == Completed {
        return NewBusinessRuleViolation("BATCH_ALREADY_COMPLETED", 
            "Cannot update completed batch")
    }
    
    b.failedCount++
    
    // バッチ状態の更新
    b.updateBatchStatus()
    
    b.addDomainEvent(BatchMediaFailed{
        BatchID:   b.batchID,
        MediaID:   mediaID,
        Reason:    reason,
        Progress:  b.CalculateProgress(),
        Timestamp: time.Now(),
    })
    
    return nil
}

// バッチ状態の更新
func (b *MediaBatch) updateBatchStatus() {
    oldStatus := b.batchStatus
    
    if b.IsCompleted() {
        if b.failedCount == 0 {
            b.batchStatus = BatchCompleted
        } else if b.completedCount == 0 {
            b.batchStatus = BatchFailed
        } else {
            b.batchStatus = BatchPartialFailed
        }
        
        // バッチ完了イベント
        b.addDomainEvent(BatchProcessingCompleted{
            BatchID:      b.batchID,
            OldStatus:    oldStatus,
            NewStatus:    b.batchStatus,
            TotalCount:   b.totalCount,
            CompletedCount: b.completedCount,
            FailedCount:  b.failedCount,
            SuccessRate:  b.CalculateSuccessRate(),
            Timestamp:    time.Now(),
        })
    }
}

// メディアIDの存在確認
func (b *MediaBatch) containsMediaID(mediaID MediaID) bool {
    for _, id := range b.mediaIDs {
        if id.Equals(mediaID) {
            return true
        }
    }
    return false
}

// バッチキャンセル（処理前のみ）
func (b *MediaBatch) Cancel() error {
    if b.batchStatus != Pending {
        return NewBusinessRuleViolation("CANNOT_CANCEL", 
            "Can only cancel pending batches")
    }
    
    b.batchStatus = BatchCancelled
    
    b.addDomainEvent(BatchCancelled{
        BatchID:   b.batchID,
        Timestamp: time.Now(),
    })
    
    return nil
}
```

**UserDrive Aggregate**
- 集約ルート: UserDrive（ユーザーのメディアドライブ）
- ID: UserID（Value Object）
- 主要フィールド:
  - TotalUsage（Value Object）: 総使用量
  - FileCount（Value Object）: ファイル数
  - QuotaLimit（Value Object）: 容量制限
  - LastUpdatedAt（Value Object）: 最終更新日時
- 関連Entity:
  - MediaFolder（Entity）: フォルダ情報
- **ドメイン不変条件（Invariants）:**
  - UserID は有効なユーザーIDを参照
  - TotalUsage ≥ 0
  - FileCount ≥ 0
  - QuotaLimit > 0
  - TotalUsage ≤ QuotaLimit（容量制限）
  - フォルダ階層の循環参照禁止

- **ドメインロジック（Business Rules）:**
```go
type UserDrive struct {
    // フィールド定義...
}

// 容量制限チェック
func (d *UserDrive) CanAddMedia(mediaSize FileSize) bool {
    newUsage := d.totalUsage + int64(mediaSize.Bytes())
    return newUsage <= d.quotaLimit
}

// 使用量チェック
func (d *UserDrive) GetUsageRatio() float64 {
    if d.quotaLimit == 0 {
        return 0.0
    }
    return float64(d.totalUsage) / float64(d.quotaLimit)
}

// 容量警告判定
func (d *UserDrive) ShouldWarnUser() bool {
    return d.GetUsageRatio() >= 0.8 // 80%以上で警告
}

// メディア追加
func (d *UserDrive) AddMedia(mediaID MediaID, fileSize FileSize, folderID *FolderID) error {
    if !d.CanAddMedia(fileSize) {
        return NewBusinessRuleViolation("QUOTA_EXCEEDED", 
            fmt.Sprintf("Adding media would exceed quota limit %d", d.quotaLimit))
    }
    
    // フォルダの存在確認
    if folderID != nil {
        folder := d.findFolder(*folderID)
        if folder == nil {
            return NewValidationError("FOLDER_NOT_FOUND", 
                "Specified folder does not exist")
        }
        folder.AddMedia(mediaID)
    }
    
    d.totalUsage += int64(fileSize.Bytes())
    d.fileCount++
    d.lastUpdatedAt = time.Now()
    
    d.addDomainEvent(MediaAddedToDrive{
        UserID:    d.userID,
        MediaID:   mediaID,
        FileSize:  fileSize,
        FolderID:  folderID,
        NewUsage:  d.totalUsage,
        Timestamp: time.Now(),
    })
    
    // 容量警告イベント
    if d.ShouldWarnUser() {
        d.addDomainEvent(DriveQuotaWarning{
            UserID:     d.userID,
            CurrentUsage: d.totalUsage,
            QuotaLimit: d.quotaLimit,
            UsageRatio: d.GetUsageRatio(),
            Timestamp:  time.Now(),
        })
    }
    
    return nil
}

// メディア削除
func (d *UserDrive) RemoveMedia(mediaID MediaID, fileSize FileSize) error {
    if d.totalUsage < int64(fileSize.Bytes()) {
        return NewBusinessRuleViolation("INVALID_USAGE_CALCULATION", 
            "Cannot have negative usage")
    }
    
    // 全フォルダからメディアを削除
    for i := range d.folders {
        d.folders[i].RemoveMedia(mediaID)
    }
    
    d.totalUsage -= int64(fileSize.Bytes())
    d.fileCount--
    d.lastUpdatedAt = time.Now()
    
    d.addDomainEvent(MediaRemovedFromDrive{
        UserID:    d.userID,
        MediaID:   mediaID,
        FileSize:  fileSize,
        NewUsage:  d.totalUsage,
        Timestamp: time.Now(),
    })
    
    return nil
}

// フォルダ作成
func (d *UserDrive) CreateFolder(name string, parentFolderID *FolderID) (*MediaFolder, error) {
    // 親フォルダの存在確認
    if parentFolderID != nil {
        parentFolder := d.findFolder(*parentFolderID)
        if parentFolder == nil {
            return nil, NewValidationError("PARENT_FOLDER_NOT_FOUND", 
                "Parent folder does not exist")
        }
        
        // 循環参照チェック
        if d.wouldCreateCircularReference(*parentFolderID, FolderID{}) {
            return nil, NewBusinessRuleViolation("CIRCULAR_REFERENCE", 
                "Creating folder would result in circular reference")
            }
    }
    
    // フォルダ名の重複チェック
    if d.folderNameExists(name, parentFolderID) {
        return nil, NewValidationError("FOLDER_NAME_EXISTS", 
            "Folder with this name already exists in the same parent")
    }
    
    folder := NewMediaFolder(name, parentFolderID)
    d.folders = append(d.folders, *folder)
    d.lastUpdatedAt = time.Now()
    
    d.addDomainEvent(FolderCreated{
        UserID:         d.userID,
        FolderID:       folder.id,
        FolderName:     name,
        ParentFolderID: parentFolderID,
        Timestamp:      time.Now(),
    })
    
    return folder, nil
}

// フォルダ階層の循環参照チェック
func (d *UserDrive) wouldCreateCircularReference(parentID, newFolderID FolderID) bool {
    visited := make(map[FolderID]bool)
    return d.checkCircularReference(parentID, newFolderID, visited)
}

func (d *UserDrive) checkCircularReference(currentID, targetID FolderID, visited map[FolderID]bool) bool {
    if currentID.Equals(targetID) {
        return true
    }
    
    if visited[currentID] {
        return true // 既に訪問済み = 循環
    }
    
    visited[currentID] = true
    
    folder := d.findFolder(currentID)
    if folder == nil || folder.parentFolderID == nil {
        return false
    }
    
    return d.checkCircularReference(*folder.parentFolderID, targetID, visited)
}

// フォルダ名重複チェック
func (d *UserDrive) folderNameExists(name string, parentFolderID *FolderID) bool {
    for _, folder := range d.folders {
        if folder.folderName == name && 
           ((folder.parentFolderID == nil && parentFolderID == nil) ||
            (folder.parentFolderID != nil && parentFolderID != nil && 
             folder.parentFolderID.Equals(*parentFolderID))) {
            return true
        }
    }
    return false
}

// フォルダ検索
func (d *UserDrive) findFolder(folderID FolderID) *MediaFolder {
    for i := range d.folders {
        if d.folders[i].id.Equals(folderID) {
            return &d.folders[i]
        }
    }
    return nil
}

// ドライブ統計取得
func (d *UserDrive) GetStatistics() DriveStatistics {
    return DriveStatistics{
        TotalUsage:   d.totalUsage,
        FileCount:    d.fileCount,
        FolderCount:  len(d.folders),
        QuotaLimit:   d.quotaLimit,
        UsageRatio:   d.GetUsageRatio(),
        LastUpdated:  d.lastUpdatedAt,
    }
}
```

#### Entity

**Thumbnail Entity**
- Media Aggregateに属する
- ID: ThumbnailID（Value Object）
- フィールド:
  - Size（Value Object）: 'small', 'medium', 'large'
  - Dimension（Value Object）: サムネイルの幅・高さ
  - StorageKey（Value Object）: S3オブジェクトキー
  - StorageURL（Value Object）: S3 URL
  - GeneratedAt（Value Object）: 生成日時

**GifThumbnail Entity**
- Media Aggregateに属する
- ID: GifThumbnailID（Value Object）
- フィールド:
  - FramePosition（Value Object）: 抽出フレーム位置
  - Dimension（Value Object）: 静止画の幅・高さ
  - StorageKey（Value Object）: S3オブジェクトキー
  - StorageURL（Value Object）: S3 URL
  - GeneratedAt（Value Object）: 生成日時

**MediaVariant Entity**（将来実装）
- Media Aggregateに属する
- ID: VariantID（Value Object）
- フィールド:
  - Resolution（Value Object）: '720p', '1080p'など
  - Bitrate（Value Object）: ビットレート
  - Codec（Value Object）: コーデック情報
  - StorageKey（Value Object）: S3オブジェクトキー
  - StorageURL（Value Object）: S3 URL

**MediaFolder Entity**
- UserDrive Aggregateに属する
- ID: FolderID（Value Object）
- フィールド:
  - FolderName（Value Object）: フォルダ名
  - ParentFolderID（Value Object）: 親フォルダID
  - MediaIDs（Value Object）: 含まれるMediaIDのリスト
  - CreatedAt（Value Object）: 作成日時
  - UpdatedAt（Value Object）: 更新日時

**EmojiVariant Entity**
- ID: EmojiVariantID（Value Object）
- フィールド:
  - OriginalSVGKey（Value Object）: 元のSVGファイルキー
  - PNGStorageKey（Value Object）: 変換後PNGのキー
  - Size（Value Object）: 絵文字サイズ
  - ConvertedAt（Value Object）: 変換日時

#### Value Object

Value Objectは不変オブジェクトであり、ビジネスロジックとバリデーションをカプセル化します。各Value Objectは自身の整合性を保証し、ドメイン固有のルールを実装します。

**識別子関連 Value Objects**
```go
// MediaID - メディアファイルの一意識別子
type MediaID struct {
    value string
}

func NewMediaID() MediaID {
    return MediaID{value: "media_" + generateULID()}
}

func (id MediaID) String() string {
    return id.value
}

func (id MediaID) Equals(other MediaID) bool {
    return id.value == other.value
}

func (id MediaID) IsEmpty() bool {
    return id.value == ""
}

func (id MediaID) Validate() error {
    if id.value == "" {
        return NewValidationError("EMPTY_MEDIA_ID", "Media ID cannot be empty")
    }
    if !strings.HasPrefix(id.value, "media_") {
        return NewValidationError("INVALID_MEDIA_ID_FORMAT", "Media ID must start with 'media_'")
    }
    return nil
}

// TaskID - 非同期タスクの識別子
type TaskID struct {
    value string
}

func NewTaskID(taskType string) TaskID {
    return TaskID{value: fmt.Sprintf("task_%s_%s", taskType, generateULID())}
}

func (id TaskID) String() string {
    return id.value
}

func (id TaskID) GetTaskType() string {
    parts := strings.Split(id.value, "_")
    if len(parts) >= 2 {
        return parts[1]
    }
    return ""
}
```

**メディア属性 Value Objects**
```go
// MediaType - メディアタイプを表すValue Object
type MediaType int

const (
    MediaTypeImage MediaType = iota + 1
    MediaTypeVideo
    MediaTypeAudio
)

func (mt MediaType) String() string {
    switch mt {
    case MediaTypeImage:
        return "image"
    case MediaTypeVideo:
        return "video"
    case MediaTypeAudio:
        return "audio"
    default:
        return "unknown"
    }
}

func (mt MediaType) IsValid() bool {
    return mt >= MediaTypeImage && mt <= MediaTypeAudio
}

func (mt MediaType) SupportsThumbnails() bool {
    return mt == MediaTypeImage || mt == MediaTypeVideo
}

func ParseMediaType(str string) (MediaType, error) {
    switch strings.ToLower(str) {
    case "image":
        return MediaTypeImage, nil
    case "video":
        return MediaTypeVideo, nil
    case "audio":
        return MediaTypeAudio, nil
    default:
        return 0, NewValidationError("INVALID_MEDIA_TYPE", 
            fmt.Sprintf("Unknown media type: %s", str))
    }
}

// FileSize - ファイルサイズを表すValue Object
type FileSize struct {
    bytes int64
}

func NewFileSize(bytes int64) (FileSize, error) {
    if bytes < 0 {
        return FileSize{}, NewValidationError("NEGATIVE_FILE_SIZE", 
            "File size cannot be negative")
    }
    if bytes > MaxFileSizeBytes {
        return FileSize{}, NewValidationError("FILE_TOO_LARGE", 
            fmt.Sprintf("File size %d exceeds maximum %d", bytes, MaxFileSizeBytes))
    }
    return FileSize{bytes: bytes}, nil
}

func (fs FileSize) Bytes() int64 {
    return fs.bytes
}

func (fs FileSize) KB() float64 {
    return float64(fs.bytes) / 1024
}

func (fs FileSize) MB() float64 {
    return fs.KB() / 1024
}

func (fs FileSize) GB() float64 {
    return fs.MB() / 1024
}

func (fs FileSize) HumanReadable() string {
    if fs.bytes < 1024 {
        return fmt.Sprintf("%d B", fs.bytes)
    } else if fs.bytes < 1024*1024 {
        return fmt.Sprintf("%.2f KB", fs.KB())
    } else if fs.bytes < 1024*1024*1024 {
        return fmt.Sprintf("%.2f MB", fs.MB())
    } else {
        return fmt.Sprintf("%.2f GB", fs.GB())
    }
}

// Dimension - 幅と高さのペア
type Dimension struct {
    width  int
    height int
}

func NewDimension(width, height int) (Dimension, error) {
    if width <= 0 || height <= 0 {
        return Dimension{}, NewValidationError("INVALID_DIMENSION", 
            "Width and height must be positive")
    }
    if width > MaxImageDimension || height > MaxImageDimension {
        return Dimension{}, NewValidationError("DIMENSION_TOO_LARGE", 
            fmt.Sprintf("Dimension %dx%d exceeds maximum %d", width, height, MaxImageDimension))
    }
    return Dimension{width: width, height: height}, nil
}

func (d Dimension) Width() int {
    return d.width
}

func (d Dimension) Height() int {
    return d.height
}

func (d Dimension) AspectRatio() float64 {
    if d.height == 0 {
        return 0
    }
    return float64(d.width) / float64(d.height)
}

func (d Dimension) IsPortrait() bool {
    return d.height > d.width
}

func (d Dimension) IsLandscape() bool {
    return d.width > d.height
}

func (d Dimension) IsSquare() bool {
    return d.width == d.height
}

func (d Dimension) String() string {
    return fmt.Sprintf("%dx%d", d.width, d.height)
}
```

**コンテンツ管理 Value Objects**
```go
// MediaDescription - ALTテキストの管理
type MediaDescription struct {
    text string
}

func NewMediaDescription(text string) (MediaDescription, error) {
    // UTF-8エンコードの文字数カウント
    runeCount := utf8.RuneCountInString(text)
    if runeCount > MaxDescriptionLength {
        return MediaDescription{}, NewValidationError("DESCRIPTION_TOO_LONG", 
            fmt.Sprintf("Description length %d exceeds maximum %d characters", 
                runeCount, MaxDescriptionLength))
    }
    
    // 無効な文字のチェック
    if !utf8.ValidString(text) {
        return MediaDescription{}, NewValidationError("INVALID_UTF8", 
            "Description contains invalid UTF-8 characters")
    }
    
    // 制御文字の除去
    cleanText := strings.Map(func(r rune) rune {
        if unicode.IsControl(r) && r != '\n' && r != '\r' && r != '\t' {
            return -1 // 文字を削除
        }
        return r
    }, text)
    
    return MediaDescription{text: cleanText}, nil
}

func (md MediaDescription) String() string {
    return md.text
}

func (md MediaDescription) IsEmpty() bool {
    return strings.TrimSpace(md.text) == ""
}

func (md MediaDescription) Length() int {
    return utf8.RuneCountInString(md.text)
}

func (md MediaDescription) Truncate(maxLength int) MediaDescription {
    if md.Length() <= maxLength {
        return md
    }
    
    runes := []rune(md.text)
    if maxLength <= 3 {
        return MediaDescription{text: string(runes[:maxLength])}
    }
    
    return MediaDescription{text: string(runes[:maxLength-3]) + "..."}
}

// MediaSensitivity - NSFWフラグの管理
type MediaSensitivity struct {
    isSensitive bool
    reason      string
}

func NewMediaSensitivity(isSensitive bool, reason string) MediaSensitivity {
    return MediaSensitivity{
        isSensitive: isSensitive,
        reason:      reason,
    }
}

func (ms MediaSensitivity) IsSensitive() bool {
    return ms.isSensitive
}

func (ms MediaSensitivity) Reason() string {
    return ms.reason
}

func (ms MediaSensitivity) RequiresWarning() bool {
    return ms.isSensitive
}
```

**ストレージ関連 Value Objects**
```go
// StorageKey - S3オブジェクトキー
type StorageKey struct {
    key string
}

func NewStorageKey(mediaType MediaType, mediaID MediaID, format string) StorageKey {
    now := time.Now()
    datePath := now.Format("2006/01/02")
    
    var prefix string
    switch mediaType {
    case MediaTypeImage:
        prefix = "original"
    case MediaTypeVideo:
        prefix = "original"
    case MediaTypeAudio:
        prefix = "audio"
    default:
        prefix = "unknown"
    }
    
    key := fmt.Sprintf("%s/%s/%s.%s", prefix, datePath, mediaID.String(), format)
    return StorageKey{key: key}
}

func (sk StorageKey) String() string {
    return sk.key
}

func (sk StorageKey) GetPrefix() string {
    parts := strings.Split(sk.key, "/")
    if len(parts) > 0 {
        return parts[0]
    }
    return ""
}

func (sk StorageKey) GetExtension() string {
    ext := filepath.Ext(sk.key)
    return strings.TrimPrefix(ext, ".")
}

func (sk StorageKey) IsValid() bool {
    return sk.key != "" && strings.Contains(sk.key, "/")
}

// PresignedURL - 署名付きURL
type PresignedURL struct {
    url       string
    expiresAt time.Time
}

func NewPresignedURL(url string, duration time.Duration) PresignedURL {
    return PresignedURL{
        url:       url,
        expiresAt: time.Now().Add(duration),
    }
}

func (pu PresignedURL) URL() string {
    return pu.url
}

func (pu PresignedURL) IsExpired() bool {
    return time.Now().After(pu.expiresAt)
}

func (pu PresignedURL) TimeUntilExpiry() time.Duration {
    if pu.IsExpired() {
        return 0
    }
    return pu.expiresAt.Sub(time.Now())
}

func (pu PresignedURL) ExpiresAt() time.Time {
    return pu.expiresAt
}
```

**ステータス Value Objects**
```go
// UploadStatus - アップロード状態
type UploadStatus int

const (
    UploadStatusPending UploadStatus = iota + 1
    UploadStatusProcessing
    UploadStatusCompleted
    UploadStatusFailed
)

func (us UploadStatus) String() string {
    switch us {
    case UploadStatusPending:
        return "pending"
    case UploadStatusProcessing:
        return "processing"
    case UploadStatusCompleted:
        return "completed"
    case UploadStatusFailed:
        return "failed"
    default:
        return "unknown"
    }
}

func (us UploadStatus) IsTerminal() bool {
    return us == UploadStatusCompleted || us == UploadStatusFailed
}

func (us UploadStatus) CanTransitionTo(newStatus UploadStatus) bool {
    validTransitions := map[UploadStatus][]UploadStatus{
        UploadStatusPending:    {UploadStatusProcessing, UploadStatusFailed},
        UploadStatusProcessing: {UploadStatusCompleted, UploadStatusFailed},
        UploadStatusCompleted:  {},
        UploadStatusFailed:     {UploadStatusPending}, // リトライのみ
    }
    
    allowed, exists := validTransitions[us]
    if !exists {
        return false
    }
    
    for _, status := range allowed {
        if status == newStatus {
            return true
        }
    }
    return false
}

func ParseUploadStatus(str string) (UploadStatus, error) {
    switch strings.ToLower(str) {
    case "pending":
        return UploadStatusPending, nil
    case "processing":
        return UploadStatusProcessing, nil
    case "completed":
        return UploadStatusCompleted, nil
    case "failed":
        return UploadStatusFailed, nil
    default:
        return 0, NewValidationError("INVALID_UPLOAD_STATUS", 
            fmt.Sprintf("Unknown upload status: %s", str))
    }
}
```

**エラー管理 Value Objects**
```go
// ProcessingError - 処理エラー情報
type ProcessingError struct {
    errorCode string
    message   string
    fatal     bool
    timestamp time.Time
    metadata  map[string]interface{}
}

func NewProcessingError(code, message string, fatal bool) ProcessingError {
    return ProcessingError{
        errorCode: code,
        message:   message,
        fatal:     fatal,
        timestamp: time.Now(),
        metadata:  make(map[string]interface{}),
    }
}

func (pe ProcessingError) ErrorCode() string {
    return pe.errorCode
}

func (pe ProcessingError) Message() string {
    return pe.message
}

func (pe ProcessingError) IsFatal() bool {
    return pe.fatal
}

func (pe ProcessingError) Timestamp() time.Time {
    return pe.timestamp
}

func (pe ProcessingError) WithMetadata(key string, value interface{}) ProcessingError {
    newError := pe
    newError.metadata = make(map[string]interface{})
    for k, v := range pe.metadata {
        newError.metadata[k] = v
    }
    newError.metadata[key] = value
    return newError
}

func (pe ProcessingError) GetMetadata(key string) (interface{}, bool) {
    value, exists := pe.metadata[key]
    return value, exists
}

func (pe ProcessingError) IsRetryable() bool {
    if pe.fatal {
        return false
    }
    
    retryableCodes := []string{
        "NETWORK_ERROR",
        "TEMPORARY_FAILURE",
        "RESOURCE_BUSY",
        "TIMEOUT",
        "RATE_LIMITED",
    }
    
    for _, code := range retryableCodes {
        if pe.errorCode == code {
            return true
        }
    }
    
    return false
}

func (pe ProcessingError) Error() string {
    return fmt.Sprintf("%s: %s", pe.errorCode, pe.message)
}
```

## データベースマイグレーション

このサービスでは、[共通マイグレーション戦略](../common/database-migration-strategy.md)に従って、Gooseを使用したマイグレーション管理を行います。

### マイグレーション戦略

- **ツール**: Goose v3
- **ディレクトリ**: `./migrations/`
- **命名規則**: `[sequence_number]_[description].sql`
- **実行方法**: `make migrate-up` / `make migrate-down`

### avion-media固有の考慮事項

- **メディアファイル整合性**: データベースとS3ストレージ間でのメディア参照整合性を保証
- **処理ジョブ継続性**: 進行中の画像・動画処理ジョブが中断されないよう配慮
- **CDN キャッシュ更新**: メディアURL変更時はCDNキャッシュの適切な無効化
- **大容量データ移行**: メディアメタデータの大量移行時は段階的処理
- **アップロード一時停止**: 重要な移行中は一時的にアップロード機能を停止

### 標準テンプレート参照

マイグレーションファイル作成時は[マイグレーション設定テンプレート](../templates/migration-setup-template.md)を参照してください。

## 7. Configuration Management (設定管理)

### 7.1. 統一設定パターンの採用

このサービスは[共通環境変数管理パターン](../common/infrastructure/environment-variables.md)で定義された統一設定パターンに準拠しています。早期失敗（Fail Fast）原則により、必須環境変数が不足している場合は起動時に即座に失敗します。

### 7.2. 環境変数一覧

#### 必須環境変数

| 変数名 | 説明 | 例 |
|--------|------|-----|
| `DATABASE_URL` | PostgreSQLデータベース接続URL | `postgresql://user:pass@localhost:5432/avion_media` |
| `REDIS_URL` | Redis接続URL | `redis://localhost:6379/0` |
| `S3_BUCKET` | S3バケット名 | `avion-media-bucket` |
| `S3_REGION` | S3リージョン | `us-west-2` |
| `AWS_ACCESS_KEY_ID` | AWS アクセスキーID | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS シークレットアクセスキー | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `CDN_URL` | CDN基盤URL | `https://cdn.avion.example.com` |

#### オプション環境変数（デフォルト値あり）

| 変数名 | 説明 | デフォルト値 |
|--------|------|-------------|
| `PORT` | HTTPサーバーポート | `8087` |
| `GRPC_PORT` | gRPCサーバーポート | `9097` |
| `MAX_UPLOAD_SIZE` | 最大アップロードサイズ | `100MB` |
| `ENVIRONMENT` | 実行環境 | `development` |
| `LOG_LEVEL` | ログレベル | `info` |
| `SERVER_TIMEOUT` | サーバータイムアウト | `30s` |

### 7.3. Config構造体実装例

```go
// internal/infrastructure/config/config.go
package config

import (
    "time"
)

// Config はavion-mediaサービスの設定を保持する構造体
type Config struct {
    // サーバー設定
    Server ServerConfig
    
    // データベース設定
    Database DatabaseConfig
    
    // Redis設定
    Redis RedisConfig
    
    // S3ストレージ設定
    Storage StorageConfig
    
    // メディア処理設定
    MediaProcessing MediaProcessingConfig
    
    // CDN設定
    CDN CDNConfig
    
    // 監視設定
    Observability ObservabilityConfig
}

// ServerConfig サーバー関連の設定
type ServerConfig struct {
    Port        int           `env:"PORT" required:"true" default:"8087"`
    GRPCPort    int           `env:"GRPC_PORT" required:"true" default:"9097"`
    Environment string        `env:"ENVIRONMENT" required:"true" default:"development"`
    LogLevel    string        `env:"LOG_LEVEL" required:"false" default:"info"`
    Timeout     time.Duration `env:"SERVER_TIMEOUT" required:"false" default:"30s"`
}

// DatabaseConfig データベース関連の設定
type DatabaseConfig struct {
    URL string `env:"DATABASE_URL" required:"true"`
}

// RedisConfig Redis関連の設定
type RedisConfig struct {
    URL string `env:"REDIS_URL" required:"true"`
}

// StorageConfig S3ストレージ関連の設定
type StorageConfig struct {
    S3Bucket            string `env:"S3_BUCKET" required:"true"`
    S3Region            string `env:"S3_REGION" required:"true"`
    AWSAccessKeyID      string `env:"AWS_ACCESS_KEY_ID" required:"true"`
    AWSSecretAccessKey  string `env:"AWS_SECRET_ACCESS_KEY" required:"true" secret:"true"`
}

// MediaProcessingConfig メディア処理関連の設定
type MediaProcessingConfig struct {
    MaxUploadSize           int64 `env:"MAX_UPLOAD_SIZE" required:"false" default:"104857600"` // 100MB
    ImageMaxWidth           int   `env:"IMAGE_MAX_WIDTH" required:"false" default:"4096"`
    ImageMaxHeight          int   `env:"IMAGE_MAX_HEIGHT" required:"false" default:"4096"`
    VideoMaxDuration        int   `env:"VIDEO_MAX_DURATION" required:"false" default:"600"`    // 10分
    ThumbnailGenerationEnabled bool `env:"THUMBNAIL_GENERATION_ENABLED" required:"false" default:"true"`
}

// CDNConfig CDN関連の設定
type CDNConfig struct {
    BaseURL        string        `env:"CDN_URL" required:"true"`
    CacheTTL       time.Duration `env:"CDN_CACHE_TTL" required:"false" default:"24h"`
    PurgeEnabled   bool          `env:"CDN_PURGE_ENABLED" required:"false" default:"true"`
}

// ObservabilityConfig 監視関連の設定
type ObservabilityConfig struct {
    TracingEnabled bool   `env:"TRACING_ENABLED" required:"false" default:"true"`
    MetricsEnabled bool   `env:"METRICS_ENABLED" required:"false" default:"true"`
    JaegerEndpoint string `env:"JAEGER_ENDPOINT" required:"false" default:"http://jaeger:14268/api/traces"`
}
```

### 7.4. 設定の読み込みと検証

```go
// cmd/server/main.go
package main

import (
    "log"
    
    "github.com/avion/avion-media/internal/infrastructure/config"
)

func main() {
    // 環境変数の読み込み（必須環境変数が不足していればここで失敗）
    cfg := config.MustLoad()
    
    // ロガーの初期化
    logger := initLogger(cfg.Server.LogLevel)
    
    logger.Info("Starting avion-media server",
        "environment", cfg.Server.Environment,
        "port", cfg.Server.Port,
        "grpc_port", cfg.Server.GRPCPort,
        "s3_bucket", cfg.Storage.S3Bucket,
        "s3_region", cfg.Storage.S3Region,
    )
    
    // サービスの初期化と起動
    // ...
}
```

### 7.5. セキュリティ考慮事項

- **機密情報の保護**: `AWS_SECRET_ACCESS_KEY` は `secret:"true"` タグにより、ログ出力時にマスキングされます
- **S3バケット分離**: 環境ごとに異なるS3バケットを使用（本番、ステージング、開発）
- **IAM権限制限**: 各環境のAWSアクセスキーは必要最小限のS3権限のみ付与
- **CDN設定**: CDNのアクセス制御とキャッシュ戦略の適切な設定

## 8. Use Cases / Key Flows (主な使い方・処理の流れ)

- **フロー 1: メディアアップロード (Presigned URL方式) (Command)**
    1. Client (via avion-web/Gateway) → RequestMediaUploadCommandHandler: `RequestMediaUpload` gRPC Call (filename, content_type, size)
    2. RequestMediaUploadCommandHandler: RequestMediaUploadCommandUseCaseを呼び出し
    3. RequestMediaUploadCommandUseCase: MediaValidationPolicy (Domain Service) でファイル検証
    4. RequestMediaUploadCommandUseCase: Media Aggregateを生成（UploadStatus='pending'）
    5. RequestMediaUploadCommandUseCase: S3StorageServiceを通じてPresignedURL Value Objectを生成
    6. RequestMediaUploadCommandUseCase: MediaRepositoryを通じてMedia Aggregateを永続化
    7. RequestMediaUploadCommandHandler → Gateway: `RequestMediaUploadResponse { media_id: "...", upload_url: "..." }`
    8. Client: 受け取った `upload_url` に直接ファイルをPUTリクエストで送信。
    9. Client: アップロード完了後、CompleteMediaUploadCommandHandler: `CompleteMediaUpload` gRPC Call (media_id)
    10. CompleteMediaUploadCommandHandler: CompleteMediaUploadCommandUseCaseを呼び出し
    11. CompleteMediaUploadCommandUseCase: MediaProcessingTask Aggregateを生成（TaskType='thumbnail_generation'）
    12. CompleteMediaUploadCommandUseCase: MediaProcessingTaskRepositoryを通じてタスクをキューに追加
    13. CompleteMediaUploadCommandHandler → Gateway: `CompleteMediaUploadResponse {}`
    14. (非同期) ThumbnailGenerationWorker: ProcessThumbnailGenerationCommandUseCaseを実行
    15. (非同期) ProcessThumbnailGenerationCommandUseCase: Media AggregateのThumbnail Entityを生成・永続化
- **フロー 2: メディア配信 (Query)**
    1. Client → MediaFileQueryHandler: HTTP GET `/media/{media_id}`
    2. MediaFileQueryHandler: GetMediaByPathQueryUseCaseを呼び出し
    3. GetMediaByPathQueryUseCase: MediaQueryServiceを通じてMediaInfoDTOを取得
    4. GetMediaByPathQueryUseCase: S3StorageServiceを通じてファイルストリームを取得
    5. MediaFileQueryHandler → Client: ファイルデータをストリーミング配信
- **フロー 3: リモートメディアキャッシュ (Command)**
    1. ActivityPubService → CacheRemoteMediaCommandHandler: `CacheRemoteMedia` gRPC Call (remote_url)
    2. CacheRemoteMediaCommandHandler: CacheRemoteMediaCommandUseCaseを呼び出し
    3. CacheRemoteMediaCommandUseCase: RemoteMediaCache Aggregateを生成（CacheStatus='pending'）
    4. CacheRemoteMediaCommandUseCase: MediaProcessingTask Aggregateを生成（TaskType='remote_cache'）
    5. CacheRemoteMediaCommandUseCase: MediaProcessingTaskRepositoryを通じてタスクをキューに追加
    6. CacheRemoteMediaCommandHandler → ActivityPubService: `CacheRemoteMediaResponse { status: "pending", task_id: "..." }`
    7. (非同期) RemoteMediaCacheWorker: RemoteURLからファイル取得
    8. (非同期) RemoteMediaCacheWorker: Media Aggregateとして保存
    9. (非同期) RemoteMediaCacheWorker: RemoteMediaCache AggregateのCacheStatusを'active'に更新
- **フロー 4: メディア削除 (イベント駆動) (Command)**
    1. DropDeletedEventHandler: Redis Pub/Subチャネル `drop_deleted` からイベント受信 (Payload: { ..., media_ids: [...] })
    2. DropDeletedEventHandler: DeleteMediaCommandUseCaseを呼び出し
    3. DeleteMediaCommandUseCase: 各media_idに対してMediaProcessingTask Aggregateを生成（TaskType='deletion'）
    4. DeleteMediaCommandUseCase: MediaProcessingTaskRepositoryを通じてタスクをキューに追加（遅延実行）
    5. (非同期・遅延) MediaDeletionWorker: MediaRepositoryを通じてMedia Aggregateを取得
    6. (非同期・遅延) MediaDeletionWorker: S3StorageServiceを通じてファイル（オリジナル、サムネイル）を削除
    7. (非同期・遅延) MediaDeletionWorker: MediaRepositoryを通じてMedia Aggregateを削除
- **フロー 5: バッチアップロード (Command)**
    1. Client → RequestBatchMediaUploadCommandHandler: `RequestBatchMediaUpload` gRPC Call (files[])
    2. RequestBatchMediaUploadCommandHandler: RequestBatchMediaUploadCommandUseCaseを呼び出し
    3. RequestBatchMediaUploadCommandUseCase: MediaBatch Aggregateを生成（BatchStatus='pending'）
    4. RequestBatchMediaUploadCommandUseCase: 各ファイルに対してMedia AggregateとPresignedURLを生成
    5. RequestBatchMediaUploadCommandHandler → Gateway: `RequestBatchMediaUploadResponse { batch_id: "...", upload_urls: [...] }`
    6. Client: 各ファイルを並行してアップロード
    7. Client: 各ファイルのアップロード完了通知
    8. (非同期) MediaBatch AggregateのBatchStatusを更新
- **フロー 6: NSFW/説明文更新 (Command)**
    1. Client → UpdateMediaSensitivityCommandHandler: `UpdateMediaSensitivity` gRPC Call (media_id, is_sensitive)
    2. UpdateMediaSensitivityCommandHandler: UpdateMediaSensitivityCommandUseCaseを呼び出し
    3. UpdateMediaSensitivityCommandUseCase: Media AggregateのMediaSensitivity Value Objectを更新
    4. UpdateMediaSensitivityCommandHandler → Gateway: `UpdateMediaSensitivityResponse {}`
    5. (同様に説明文更新も処理)
- **フロー 7: 音声ファイル処理 (Command)**
    1. Client: 音声ファイルアップロード完了後
    2. CompleteMediaUploadCommandUseCase: MediaProcessingTask Aggregateを生成（TaskType='audio_transcoding'）
    3. (非同期) AudioTranscodingWorker: ProcessAudioTranscodingCommandUseCaseを実行
    4. ProcessAudioTranscodingCommandUseCase: ffmpegを使用してMP3 V2 VBRに変換
    5. ProcessAudioTranscodingCommandUseCase: Media AggregateのAudioMetadata Value Objectを更新
- **フロー 8: ユーザードライブ操作 (Command/Query)**
    1. Client → OrganizeMediaInDriveCommandHandler: `OrganizeMediaInDrive` gRPC Call (user_id, folder_operations)
    2. OrganizeMediaInDriveCommandHandler: OrganizeMediaInDriveCommandUseCaseを呼び出し
    3. OrganizeMediaInDriveCommandUseCase: UserDrive AggregateとMediaFolder Entityを更新
    4. Client → GetUserDriveContentsQueryHandler: `GetUserDriveContents` gRPC Call (user_id, folder_id)
    5. GetUserDriveContentsQueryHandler: UserDriveQueryServiceを通じてフォルダ構造とメディア一覧を取得

## 9. Endpoints (API)

- **gRPC Services (`avion.MediaService`):**
    - **Command Operations (更新系):**
        - `RequestMediaUpload(RequestMediaUploadRequest) returns (RequestMediaUploadResponse)` // POST相当、Presigned URL払い出し
        - `CompleteMediaUpload(CompleteMediaUploadRequest) returns (CompleteMediaUploadResponse)` // POST相当、後処理トリガー
        - `RequestBatchMediaUpload(RequestBatchMediaUploadRequest) returns (RequestBatchMediaUploadResponse)` // POST相当、バッチアップロード
        - `UpdateMediaSensitivity(UpdateMediaSensitivityRequest) returns (UpdateMediaSensitivityResponse)` // PATCH相当、NSFWフラグ更新
        - `UpdateMediaDescription(UpdateMediaDescriptionRequest) returns (UpdateMediaDescriptionResponse)` // PATCH相当、説明文更新
        - `OrganizeMediaInDrive(OrganizeMediaInDriveRequest) returns (OrganizeMediaInDriveResponse)` // POST相当、ドライブ整理
        - `CacheRemoteMedia(CacheRemoteMediaRequest) returns (CacheRemoteMediaResponse)` // POST相当、内部API
        - `UpdateMediaLimits(UpdateMediaLimitsRequest) returns (UpdateMediaLimitsResponse)` // PUT相当、管理者API
    - **Query Operations (参照系):**
        - `GetMediaInfo(GetMediaInfoRequest) returns (GetMediaInfoResponse)` // GET相当、メディア情報取得
        - `GetUserDriveContents(GetUserDriveContentsRequest) returns (GetUserDriveContentsResponse)` // GET相当、ドライブ内容取得
        - `GetMediaUsageStats(GetMediaUsageStatsRequest) returns (GetMediaUsageStatsResponse)` // GET相当、使用状況取得
        - `GetMediaLimits(GetMediaLimitsRequest) returns (GetMediaLimitsResponse)` // GET相当、制限設定取得
- **HTTP Endpoints:** (直接公開せずCDNオリジンとして設定)
    - **Query Operations (参照系):**
        - `GET /media/{media_id}`: メディアファイル配信 (CDNオリジン用)
        - `GET /thumbnail/{size}/{media_id}`: サムネイル配信 (CDNオリジン用)
- Proto定義は別途管理する。

## 10. Data Design (データ)

### ドメインオブジェクトとストレージのマッピング

DDDの戦術的パターンに基づき、以下のようにドメインオブジェクトをストレージにマッピングします：

#### Media Aggregate → S3オブジェクトストレージ
- **S3互換オブジェクトストレージ:**
    - Bucket: `avion-media`
        - Original files: `original/{year}/{month}/{day}/{media_id}.{ext}` (Media AggregateのStorageKey)
        - Audio files: `audio/{year}/{month}/{day}/{media_id}.{ext}`
        - Emoji files: `emoji/{emoji_id}/{size}.png`
        - MediaIDをキーとしてMedia Aggregateの実体を保存
        - MediaMetadata/AudioMetadata Value Objectは画像のEXIFデータやビデオ/音声メタデータとして保持
        - MediaSensitivity、MediaDescriptionはS3オブジェクトのメタデータとして保存

#### Thumbnail Entity → S3オブジェクトストレージ
        - Thumbnails: `thumbnail/{size}/{year}/{month}/{day}/{media_id}.jpg`
        - Size Value Object ('small', 'medium', 'large') でパスを分類
        - Dimension Value Objectの情報はメタデータとして保持

#### RemoteMediaCache Aggregate → S3オブジェクトストレージ
        - Cached remote files: `cached_remote/{hash_of_url}`
        - CacheKey Value Object (RemoteURLのハッシュ) をキーとして使用
        - RemoteURL Value Objectの情報はメタデータとして保持

### 処理状態の管理（Redis）
#### MediaProcessingTask Aggregate → Redis Stream
- **Redis:**
    - 非同期処理キュー (Stream): 
        - `media_processing_queue`: サムネイル生成タスク
        - `gif_thumbnail_queue`: GIF静止画生成タスク
        - `audio_transcoding_queue`: 音声変換タスク
        - `svg_conversion_queue`: SVG絵文字変換タスク
        - `media_cache_queue`: リモートメディアキャッシュタスク
        - `media_delete_queue`: メディア削除タスク
        - `error_notification_queue`: エラー通知タスク
        - Consumer Group: `media_workers`
    - 各StreamエントリーはMediaProcessingTask Aggregateを表現
    - TaskID Value ObjectがStreamメッセージIDにマッピング
    - TaskType, TaskStatus Value Objectはペイロードに含まれる
    - ProcessingError Value Objectでエラー情報を管理

#### UserDrive/MediaBatch → Redis
    - ユーザードライブ情報: `user_drive:{user_id}` (Hash)
    - バッチ処理状態: `batch:{batch_id}` (Hash)
    - メディア使用状況: `media_usage:{media_id}` (Hash)
    - 管理者設定: `media_limits` (Hash)

#### イベント購読
    - Pub/Sub Channels: `drop_deleted` (購読)
    - 削除イベントを受信してMediaProcessingTaskを生成

### PostgreSQLスキーマ設計

このサービスでは、メディアメタデータの管理とクエリパフォーマンスの最適化のためにPostgreSQLを使用します。

#### メディアメタデータテーブル

```sql
-- メディアファイルのメタデータ管理
CREATE TABLE media (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    filename VARCHAR(255) NOT NULL,
    content_type VARCHAR(100) NOT NULL,
    file_size BIGINT NOT NULL,
    checksum_sha256 VARCHAR(64) NOT NULL,
    storage_key VARCHAR(500) NOT NULL, -- S3パス
    upload_status VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending, processing, completed, failed
    media_type VARCHAR(20) NOT NULL, -- image, video, audio, document
    width INTEGER, -- 画像・動画の場合
    height INTEGER, -- 画像・動画の場合
    duration_seconds INTEGER, -- 動画・音声の場合
    is_sensitive BOOLEAN NOT NULL DEFAULT false,
    description TEXT,
    blurhash VARCHAR(100), -- 画像のぼかしハッシュ
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE,
    
    CONSTRAINT media_upload_status_check CHECK (upload_status IN ('pending', 'processing', 'completed', 'failed')),
    CONSTRAINT media_type_check CHECK (media_type IN ('image', 'video', 'audio', 'document')),
    CONSTRAINT media_dimensions_check CHECK (
        (media_type IN ('image', 'video') AND width > 0 AND height > 0) OR
        (media_type NOT IN ('image', 'video') AND width IS NULL AND height IS NULL)
    ),
    CONSTRAINT media_duration_check CHECK (
        (media_type IN ('video', 'audio') AND duration_seconds >= 0) OR
        (media_type NOT IN ('video', 'audio') AND duration_seconds IS NULL)
    )
);

-- インデックス設計
CREATE INDEX idx_media_user_id ON media(user_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_media_upload_status ON media(upload_status) WHERE deleted_at IS NULL;
CREATE INDEX idx_media_created_at ON media(created_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_media_media_type ON media(media_type) WHERE deleted_at IS NULL;
CREATE INDEX idx_media_storage_key ON media(storage_key) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX idx_media_checksum_unique ON media(checksum_sha256) WHERE deleted_at IS NULL;

-- 論理削除対応インデックス
CREATE INDEX idx_media_deleted_at ON media(deleted_at) WHERE deleted_at IS NOT NULL;
```

#### メディア処理タスクテーブル

```sql
-- 非同期処理タスクの永続化（Redis Stream補完）
CREATE TABLE media_processing_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    media_id UUID NOT NULL REFERENCES media(id) ON DELETE CASCADE,
    task_type VARCHAR(50) NOT NULL,
    task_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    priority INTEGER NOT NULL DEFAULT 0,
    retry_count INTEGER NOT NULL DEFAULT 0,
    max_retries INTEGER NOT NULL DEFAULT 3,
    error_message TEXT,
    error_code VARCHAR(50),
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    next_retry_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    CONSTRAINT task_type_check CHECK (task_type IN (
        'thumbnail_generation', 'gif_thumbnail', 'audio_transcoding', 
        'svg_conversion', 'remote_cache', 'deletion', 'validation'
    )),
    CONSTRAINT task_status_check CHECK (task_status IN (
        'pending', 'processing', 'completed', 'failed', 'retrying', 'cancelled'
    )),
    CONSTRAINT retry_count_check CHECK (retry_count >= 0 AND retry_count <= max_retries),
    CONSTRAINT priority_check CHECK (priority >= 0 AND priority <= 10)
);

-- インデックス設計
CREATE INDEX idx_processing_tasks_media_id ON media_processing_tasks(media_id);
CREATE INDEX idx_processing_tasks_status ON media_processing_tasks(task_status);
CREATE INDEX idx_processing_tasks_type_status ON media_processing_tasks(task_type, task_status);
CREATE INDEX idx_processing_tasks_retry_at ON media_processing_tasks(next_retry_at) 
    WHERE task_status = 'retrying';
CREATE INDEX idx_processing_tasks_priority ON media_processing_tasks(priority DESC, created_at ASC) 
    WHERE task_status = 'pending';
```

#### メディアバリアントテーブル

```sql
-- サムネイルと異なる解像度のメディアファイル管理
CREATE TABLE media_variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    media_id UUID NOT NULL REFERENCES media(id) ON DELETE CASCADE,
    variant_type VARCHAR(20) NOT NULL,
    size_name VARCHAR(20) NOT NULL, -- small, medium, large, original
    storage_key VARCHAR(500) NOT NULL,
    content_type VARCHAR(100) NOT NULL,
    file_size BIGINT NOT NULL,
    width INTEGER,
    height INTEGER,
    quality INTEGER, -- 画質（1-100）
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    CONSTRAINT variant_type_check CHECK (variant_type IN ('thumbnail', 'resized', 'converted')),
    CONSTRAINT size_name_check CHECK (size_name IN ('small', 'medium', 'large', 'original')),
    CONSTRAINT quality_check CHECK (quality IS NULL OR (quality >= 1 AND quality <= 100)),
    
    UNIQUE(media_id, variant_type, size_name)
);

-- インデックス設計
CREATE INDEX idx_media_variants_media_id ON media_variants(media_id);
CREATE INDEX idx_media_variants_type_size ON media_variants(variant_type, size_name);
CREATE INDEX idx_media_variants_storage_key ON media_variants(storage_key);
```

#### リモートメディアキャッシュテーブル

```sql
-- ActivityPubからの外部メディアキャッシュ管理
CREATE TABLE remote_media_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    remote_url TEXT NOT NULL,
    cache_key VARCHAR(100) NOT NULL, -- URLのハッシュ
    local_storage_key VARCHAR(500), -- S3パス
    content_type VARCHAR(100),
    file_size BIGINT,
    cache_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    last_accessed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    retry_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    CONSTRAINT cache_status_check CHECK (cache_status IN ('pending', 'active', 'failed', 'expired')),
    CONSTRAINT retry_count_check CHECK (retry_count >= 0)
);

-- インデックス設計
CREATE UNIQUE INDEX idx_remote_cache_key ON remote_media_cache(cache_key);
CREATE INDEX idx_remote_cache_url ON remote_media_cache(remote_url);
CREATE INDEX idx_remote_cache_status ON remote_media_cache(cache_status);
CREATE INDEX idx_remote_cache_expires_at ON remote_media_cache(expires_at) 
    WHERE cache_status = 'active';
CREATE INDEX idx_remote_cache_last_accessed ON remote_media_cache(last_accessed_at) 
    WHERE cache_status = 'active';
```

#### メディアバッチテーブル

```sql
-- バッチアップロード管理
CREATE TABLE media_batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    batch_name VARCHAR(255),
    total_files INTEGER NOT NULL,
    completed_files INTEGER NOT NULL DEFAULT 0,
    failed_files INTEGER NOT NULL DEFAULT 0,
    batch_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    
    CONSTRAINT batch_status_check CHECK (batch_status IN ('pending', 'processing', 'completed', 'failed')),
    CONSTRAINT file_counts_check CHECK (
        total_files > 0 AND 
        completed_files >= 0 AND 
        failed_files >= 0 AND
        (completed_files + failed_files) <= total_files
    )
);

-- バッチとメディアの関連
CREATE TABLE media_batch_items (
    batch_id UUID NOT NULL REFERENCES media_batches(id) ON DELETE CASCADE,
    media_id UUID NOT NULL REFERENCES media(id) ON DELETE CASCADE,
    item_status VARCHAR(20) NOT NULL DEFAULT 'pending',
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    PRIMARY KEY (batch_id, media_id),
    CONSTRAINT item_status_check CHECK (item_status IN ('pending', 'completed', 'failed'))
);

-- インデックス設計
CREATE INDEX idx_media_batches_user_id ON media_batches(user_id);
CREATE INDEX idx_media_batches_status ON media_batches(batch_status);
CREATE INDEX idx_media_batch_items_status ON media_batch_items(item_status);
```

#### ユーザードライブテーブル

```sql
-- ユーザーストレージ管理
CREATE TABLE user_drives (
    user_id UUID PRIMARY KEY,
    total_storage_bytes BIGINT NOT NULL DEFAULT 0,
    used_storage_bytes BIGINT NOT NULL DEFAULT 0,
    file_count INTEGER NOT NULL DEFAULT 0,
    folder_count INTEGER NOT NULL DEFAULT 0,
    storage_limit_bytes BIGINT,
    file_limit INTEGER,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    CONSTRAINT storage_check CHECK (used_storage_bytes >= 0 AND used_storage_bytes <= total_storage_bytes),
    CONSTRAINT count_check CHECK (file_count >= 0 AND folder_count >= 0),
    CONSTRAINT limit_check CHECK (
        (storage_limit_bytes IS NULL OR storage_limit_bytes > 0) AND
        (file_limit IS NULL OR file_limit > 0)
    )
);

-- メディアフォルダ管理
CREATE TABLE media_folders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES user_drives(user_id) ON DELETE CASCADE,
    parent_folder_id UUID REFERENCES media_folders(id) ON DELETE CASCADE,
    folder_name VARCHAR(255) NOT NULL,
    folder_path TEXT NOT NULL, -- 階層パス
    depth INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    CONSTRAINT folder_depth_check CHECK (depth >= 0 AND depth <= 10),
    CONSTRAINT folder_name_check CHECK (LENGTH(folder_name) > 0),
    
    UNIQUE(user_id, parent_folder_id, folder_name)
);

-- メディアとフォルダの関連
CREATE TABLE media_folder_items (
    media_id UUID NOT NULL REFERENCES media(id) ON DELETE CASCADE,
    folder_id UUID REFERENCES media_folders(id) ON DELETE SET NULL,
    user_id UUID NOT NULL,
    moved_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    PRIMARY KEY (media_id),
    FOREIGN KEY (user_id) REFERENCES user_drives(user_id) ON DELETE CASCADE
);

-- インデックス設計
CREATE INDEX idx_user_drives_usage ON user_drives(used_storage_bytes, file_count);
CREATE INDEX idx_media_folders_user_parent ON media_folders(user_id, parent_folder_id);
CREATE INDEX idx_media_folders_path ON media_folders(folder_path);
CREATE INDEX idx_media_folder_items_folder ON media_folder_items(folder_id);
CREATE INDEX idx_media_folder_items_user ON media_folder_items(user_id);
```

### ドメインオブジェクト → DB マッピング戦略

#### Aggregate Root のマッピング

**Media Aggregate → media テーブル**
```go
type Media struct {
    // Entity
    id          MediaID
    userID      UserID
    filename    Filename
    contentType ContentType
    fileSize    FileSize
    checksum    Checksum
    storageKey  StorageKey
    
    // Value Objects
    uploadStatus    UploadStatus
    mediaType      MediaType
    dimensions     *Dimensions      // width, height
    duration       *Duration        // 動画・音声の場合
    sensitivity    MediaSensitivity // is_sensitive
    description    *MediaDescription
    blurhash       *Blurhash
    
    // Entities (Composition)
    thumbnails     []Thumbnail      // media_variants テーブル
    
    // 時刻
    createdAt      CreatedAt
    updatedAt      UpdatedAt
    deletedAt      *DeletedAt
}
```

**マッピング仕様:**
- Aggregate Root の EntityID → Primary Key (UUID)
- Value Objects → 対応するカラム（型変換あり）
- 子 Entity (Thumbnail) → 別テーブル (media_variants) で外部キー参照
- ドメインイベント → Redis Pub/Sub で発行（DBには保存しない）

**UserDrive Aggregate → user_drives + media_folders テーブル**
```go
type UserDrive struct {
    // Entity
    userID UserID
    
    // Value Objects
    storageStats   StorageStats    // total_storage_bytes, used_storage_bytes
    fileCounts     FileCounts      // file_count, folder_count
    storageLimits  *StorageLimits  // storage_limit_bytes, file_limit
    
    // Entities (Composition)
    folders        []MediaFolder   // media_folders テーブル
    mediaItems     []MediaFolderItem // media_folder_items テーブル
    
    // 時刻
    createdAt      CreatedAt
    updatedAt      UpdatedAt
}
```

#### Value Object の永続化戦略

**単純な Value Object**
```go
// MediaType Value Object → VARCHAR enum制約
type MediaType string
const (
    MediaTypeImage    MediaType = "image"
    MediaTypeVideo    MediaType = "video"
    MediaTypeAudio    MediaType = "audio"
    MediaTypeDocument MediaType = "document"
)

// データベース制約でドメインルールを保証
// CONSTRAINT media_type_check CHECK (media_type IN ('image', 'video', 'audio', 'document'))
```

**複合 Value Object**
```go
// Dimensions Value Object → 複数カラム
type Dimensions struct {
    width  int
    height int
}

// DBマッピング
// width INTEGER
// height INTEGER
// CONSTRAINT media_dimensions_check CHECK (
//     (media_type IN ('image', 'video') AND width > 0 AND height > 0) OR
//     (media_type NOT IN ('image', 'video') AND width IS NULL AND height IS NULL)
// )
```

**JSON Value Object**
```go
// ProcessingMetadata Value Object → JSONB
type ProcessingMetadata struct {
    originalFormat  string
    processingSteps []ProcessingStep
    quality        int
    compression    CompressionSettings
}

// DBマッピング
// metadata JSONB
```

#### Entity の永続化戦略

**子 Entity (Thumbnail) の独立テーブル管理**
```go
type Thumbnail struct {
    // Entity Identity
    id        ThumbnailID  // media_variants.id
    mediaID   MediaID      // media_variants.media_id (外部キー)
    
    // Value Objects
    size      ThumbnailSize    // variant_type, size_name
    storageKey StorageKey      // storage_key
    dimensions Dimensions      // width, height
    quality   *Quality         // quality
    
    createdAt CreatedAt        // created_at
}

// Aggregateからの取得
func (m *Media) GetThumbnails() []Thumbnail {
    // Repository経由で media_variants テーブルから取得
    return m.thumbnails
}
```

#### Repository パターンの実装戦略

**Aggregate Repository インターフェース**
```go
type MediaRepository interface {
    // Aggregate操作
    Save(ctx context.Context, media *Media) error
    FindByID(ctx context.Context, id MediaID) (*Media, error)
    FindByUserID(ctx context.Context, userID UserID, opts *QueryOptions) ([]*Media, error)
    Delete(ctx context.Context, id MediaID) error
    
    // 検索・フィルタリング
    FindByChecksum(ctx context.Context, checksum Checksum) (*Media, error)
    FindPendingProcessing(ctx context.Context, limit int) ([]*Media, error)
}

type MediaFolderRepository interface {
    // UserDrive Aggregate操作
    SaveUserDrive(ctx context.Context, drive *UserDrive) error
    FindUserDriveByID(ctx context.Context, userID UserID) (*UserDrive, error)
    
    // Folder操作
    SaveFolder(ctx context.Context, folder *MediaFolder) error
    FindFoldersByParent(ctx context.Context, userID UserID, parentID *FolderID) ([]*MediaFolder, error)
    DeleteFolder(ctx context.Context, id FolderID) error
}
```

**実装での注意点**
- トランザクション境界 = Aggregate境界
- 子Entityの変更は親Aggregateのメソッド経由
- 複数Aggregateにまたがる操作はDomainServiceで調整
- 楽観的ロック（updated_at）でコンカレンシー制御

### マイグレーション戦略

#### Goose マイグレーション管理

**ディレクトリ構成**
```
avion-media/
├── migrations/
│   ├── 001_initial_schema.sql
│   ├── 002_add_media_variants.sql
│   ├── 003_add_remote_cache.sql
│   ├── 004_add_user_drives.sql
│   ├── 005_add_batch_processing.sql
│   └── 006_add_indexes_optimization.sql
├── scripts/
│   ├── migrate.sh
│   └── rollback.sh
└── cmd/
    └── migrate/
        └── main.go
```

**マイグレーション実行戦略**
```bash
# 開発環境
make migrate-up

# 本番環境（ダウンタイムゼロ）
# 1. 新しいカラム追加（NULL許可）
goose -dir ./migrations up-to 004

# 2. アプリケーションデプロイ（両対応）
kubectl rollout restart deployment/avion-media

# 3. データ移行（バックグラウンド）
goose -dir ./migrations up-to 005

# 4. NOT NULL制約追加
goose -dir ./migrations up-to 006
```

**ダウンタイムゼロ戦略の原則**
1. **Additive Changes First**: 新しいカラム・テーブルを先に追加
2. **Backward Compatibility**: 古いスキーマでも動作するアプリケーション
3. **Gradual Migration**: データ移行は段階的に実行
4. **Constraint Last**: NOT NULL、外部キー制約は最後に追加
5. **Rollback Ready**: 各段階でロールバック可能

**メディアサービス固有の考慮事項**
- **大容量テーブル**: media テーブルは段階的にインデックス作成
- **S3整合性**: マイグレーション中もS3オブジェクトとの整合性を保持
- **処理継続性**: Redis Stream処理が中断されないよう配慮
- **CDNキャッシュ**: URL変更時はCDNキャッシュ無効化
- **バッチ処理**: 大量データ移行は小さなバッチに分割

## 11. Operations & Monitoring (運用と監視)

- **主なオペレーション:**
    - S3/CDN設定、アクセスキー/認証情報管理。
    - 非同期ワーカ数、Consumer Groupの調整。
    - 処理キュー/DLQの監視と対応。
    - 古いキャッシュファイル/削除対象ファイルのクリーンアップジョブ運用。
    - リモートキャッシュポリシー設定の管理。
- **監視/アラート:**
    - **メトリクス:**
        - gRPCリクエスト数、レイテンシ、エラーレート。
        - S3/CDNアクセスエラーレート、レイテンシ、転送量。
        - Redis Streamキュー長、処理時間、成功/失敗/DLQレート。
        - サムネイル生成/キャッシュ処理時間。
    - **ログ:** API処理ログ、非同期処理ログ、S3/CDNアクセスログ（可能なら）、エラーログ、削除ジョブ実行ログ。
    - **トレース:** API呼び出し、非同期処理、S3アクセスのトレース。
    - **アラート:** gRPCエラーレート急増、高レイテンシ、S3/CDN接続障害、処理キュー滞留、非同期処理失敗レート上昇。

## 11. エラーハンドリング戦略

> **注意:** エラーコードは[共通エラーコード標準](../common/errors/error-codes.md)に準拠します。このサービスではプレフィックス `MDA` を使用します。

### エラーコード体系

本サービスは、Avionプラットフォーム標準のエラーコード体系に準拠します。

- **命名規則**: `[SERVICE]_[LAYER]_[ERROR_TYPE]`形式
- **エラーカタログ**: [error-catalog.md](./error-catalog.md)
- **実装ガイド**: [共通エラー実装ガイド](../common/errors/implementation-guide.md)
- **標準仕様**: [エラーコード標準化ガイドライン](../common/errors/error-standards.md)

詳細なエラーコード定義とマッピングについては、上記のドキュメントを参照してください。

メディア処理における包括的なエラー管理は、サービスの信頼性と運用性に直結します。本セクションでは、メディア特有のエラーパターンとその対処戦略を定義します。

### エラー分類とハンドリングポリシー

#### ユーザー起因エラー（4xx系）
**バリデーションエラー**
- **ファイル形式エラー**: 非対応形式、破損ファイル
- **ファイルサイズエラー**: 制限値超過
- **権限エラー**: アクセス権限不足
- **レート制限エラー**: アップロード頻度制限違反

**処理方針**:
```go
type ValidationError struct {
    Code    string `json:"code"`
    Message string `json:"message"`
    Field   string `json:"field,omitempty"`
}

// メディアバリデーションエラーの例
func validateMediaFile(file *MediaFile) error {
    if !isValidFormat(file.ContentType) {
        return &ValidationError{
            Code:    "UNSUPPORTED_FORMAT",
            Message: fmt.Sprintf("Format %s is not supported", file.ContentType),
            Field:   "content_type",
        }
    }
    if file.Size > getMaxSize(file.MediaType) {
        return &ValidationError{
            Code:    "FILE_TOO_LARGE",
            Message: fmt.Sprintf("File size %d exceeds limit %d", file.Size, getMaxSize(file.MediaType)),
            Field:   "file_size",
        }
    }
    return nil
}
```

**ユーザー通知**:
- 即座にエラーレスポンスを返す
- 具体的で実行可能な修正方法を提示
- ログレベル: INFO（通常運用の範囲内）

#### システム起因エラー（5xx系）
**インフラストラクチャエラー**
- **S3接続エラー**: ネットワーク障害、認証失敗
- **Redis接続エラー**: キュー処理不可
- **処理リソース不足**: CPU/メモリ枯渇

**処理方針**:
```go
type InfrastructureError struct {
    Component string    `json:"component"`
    Operation string    `json:"operation"`
    Cause     error     `json:"-"`
    Retryable bool      `json:"retryable"`
    RetryAt   time.Time `json:"retry_at,omitempty"`
}

// S3操作エラーハンドリングの例
func handleS3Error(err error, operation string) error {
    if isTemporary(err) {
        return &InfrastructureError{
            Component: "s3_storage",
            Operation: operation,
            Cause:     err,
            Retryable: true,
            RetryAt:   time.Now().Add(exponentialBackoff()),
        }
    }
    return &InfrastructureError{
        Component: "s3_storage",
        Operation: operation,
        Cause:     err,
        Retryable: false,
    }
}
```

**復旧戦略**:
- 自動リトライ（Exponential Backoff）
- Circuit Breaker パターンの適用
- フォールバック処理（縮退運転）
- ログレベル: ERROR

#### メディア処理エラー
**サムネイル生成エラー**
- **画像破損**: ファイルヘッダー不正、データ欠損
- **メモリ不足**: 大容量画像処理時
- **処理ライブラリエラー**: ImageMagick/ffmpegの異常終了

**音声処理エラー**
- **コーデック非対応**: 変換不可能な音声形式
- **音声データ破損**: 再生不可能なファイル
- **変換プロセス失敗**: ffmpeg異常終了

**SVG変換エラー**
- **悪意あるSVG**: XXE攻撃、無限ループ
- **非対応要素**: ブラウザ固有の拡張
- **レンダリング失敗**: 変換ライブラリエラー

```go
type ProcessingError struct {
    MediaID     string        `json:"media_id"`
    TaskType    string        `json:"task_type"`
    Stage       string        `json:"stage"`
    ErrorCode   string        `json:"error_code"`
    Message     string        `json:"message"`
    RetryCount  int           `json:"retry_count"`
    MaxRetries  int           `json:"max_retries"`
    NextRetryAt time.Time     `json:"next_retry_at"`
    Fatal       bool          `json:"fatal"`
    Metadata    map[string]interface{} `json:"metadata"`
}

// サムネイル生成エラーの処理例
func handleThumbnailError(mediaID string, err error, retryCount int) *ProcessingError {
    procErr := &ProcessingError{
        MediaID:    mediaID,
        TaskType:   "thumbnail_generation",
        Stage:      "image_processing",
        RetryCount: retryCount,
        MaxRetries: 3,
        Metadata:   map[string]interface{}{},
    }

    switch {
    case isCorruptedImageError(err):
        procErr.ErrorCode = "IMAGE_CORRUPTED"
        procErr.Message = "Source image file is corrupted or invalid"
        procErr.Fatal = true // リトライしない
    case isMemoryError(err):
        procErr.ErrorCode = "INSUFFICIENT_MEMORY"
        procErr.Message = "Insufficient memory for image processing"
        procErr.NextRetryAt = time.Now().Add(5 * time.Minute) // 時間を空けてリトライ
    case isLibraryError(err):
        procErr.ErrorCode = "PROCESSING_LIBRARY_ERROR"
        procErr.Message = "Image processing library error"
        procErr.NextRetryAt = time.Now().Add(time.Duration(retryCount*30) * time.Second)
    default:
        procErr.ErrorCode = "UNKNOWN_PROCESSING_ERROR"
        procErr.Message = err.Error()
        procErr.NextRetryAt = time.Now().Add(time.Duration(retryCount*60) * time.Second)
    }

    if retryCount >= procErr.MaxRetries {
        procErr.Fatal = true
    }

    return procErr
}
```

### リトライ戦略

#### 階層化リトライポリシー

**Level 1: 即座リトライ (Fast Retry)**
- 対象: 一時的なネットワークエラー、レート制限
- 回数: 3回
- 間隔: 1秒、2秒、4秒
- 適用箇所: S3 API呼び出し、Redis操作

**Level 2: 遅延リトライ (Delayed Retry)**
- 対象: リソース不足、外部サービス障害
- 回数: 5回
- 間隔: Exponential Backoff (30秒〜30分)
- 適用箇所: サムネイル生成、音声変換

**Level 3: 手動復旧 (Manual Recovery)**
- 対象: データ破損、設定エラー
- アラート: Critical レベル
- 処理: Dead Letter Queue へ移動

```go
type RetryPolicy struct {
    MaxRetries    int
    BaseDelay     time.Duration
    MaxDelay      time.Duration
    BackoffFactor float64
    Jitter        bool
}

func (p *RetryPolicy) NextRetryDelay(attempt int) time.Duration {
    delay := time.Duration(float64(p.BaseDelay) * math.Pow(p.BackoffFactor, float64(attempt)))
    if delay > p.MaxDelay {
        delay = p.MaxDelay
    }
    if p.Jitter {
        jitter := time.Duration(rand.Float64() * float64(delay) * 0.1)
        delay += jitter
    }
    return delay
}

// 各処理タイプごとのポリシー
var retryPolicies = map[string]*RetryPolicy{
    "thumbnail_generation": {
        MaxRetries:    3,
        BaseDelay:     30 * time.Second,
        MaxDelay:      10 * time.Minute,
        BackoffFactor: 2.0,
        Jitter:        true,
    },
    "audio_transcoding": {
        MaxRetries:    5,
        BaseDelay:     60 * time.Second,
        MaxDelay:      30 * time.Minute,
        BackoffFactor: 1.5,
        Jitter:        true,
    },
    "remote_cache": {
        MaxRetries:    2,
        BaseDelay:     10 * time.Second,
        MaxDelay:      5 * time.Minute,
        BackoffFactor: 3.0,
        Jitter:        false,
    },
}
```

### Dead Letter Queue (DLQ) 運用

#### DLQ 設計
```go
type DLQEntry struct {
    OriginalMessageID string                 `json:"original_message_id"`
    TaskType         string                 `json:"task_type"`
    MediaID          string                 `json:"media_id"`
    Payload          map[string]interface{} `json:"payload"`
    FirstFailure     time.Time              `json:"first_failure"`
    LastFailure      time.Time              `json:"last_failure"`
    FailureCount     int                    `json:"failure_count"`
    LastError        string                 `json:"last_error"`
    Category         string                 `json:"category"` // "transient", "permanent", "unknown"
}
```

**DLQ 処理フロー**:
1. 最大リトライ数に到達したタスクをDLQに移動
2. DLQエントリーをPostgreSQLに永続化
3. 管理者ダッシュボードで確認可能
4. 手動での再実行機能を提供
5. 定期的なDLQ分析とパターン検出

### エラー通知戦略

#### ユーザー通知
```go
type UserNotification struct {
    UserID      string            `json:"user_id"`
    MediaID     string            `json:"media_id"`
    Type        string            `json:"type"` // "processing_failed", "upload_failed"
    Title       string            `json:"title"`
    Message     string            `json:"message"`
    ActionURL   string            `json:"action_url,omitempty"`
    Severity    string            `json:"severity"` // "info", "warning", "error"
    Timestamp   time.Time         `json:"timestamp"`
    Metadata    map[string]string `json:"metadata"`
}
```

#### システム監視アラート
```go
type SystemAlert struct {
    Level       string            `json:"level"` // "warning", "critical"
    Component   string            `json:"component"`
    Title       string            `json:"title"`
    Description string            `json:"description"`
    Metrics     map[string]float64 `json:"metrics"`
    Timestamp   time.Time         `json:"timestamp"`
    Tags        []string          `json:"tags"`
}
```

### エラーメトリクス

#### 収集対象メトリクス
```go
// Prometheus メトリクス定義
var (
    mediaProcessingErrors = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "avion_media_processing_errors_total",
            Help: "Total number of media processing errors",
        },
        []string{"task_type", "error_code", "fatal"},
    )

    mediaProcessingRetries = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "avion_media_processing_retries_total",
            Help: "Total number of media processing retries",
        },
        []string{"task_type", "retry_count"},
    )

    deadLetterQueueSize = prometheus.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "avion_media_dlq_size",
            Help: "Current size of dead letter queue",
        },
        []string{"task_type"},
    )

    errorResolutionTime = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "avion_media_error_resolution_seconds",
            Help: "Time taken to resolve errors",
            Buckets: prometheus.ExponentialBuckets(1, 2, 10), // 1s to ~17min
        },
        []string{"error_type", "resolution_method"},
    )
)
```

### 復旧手順書

#### 緊急時対応フロー
1. **アラート受信**: 自動監視システムからの通知
2. **影響範囲特定**: 失敗しているタスクタイプと件数の確認
3. **原因調査**: ログ分析とメトリクス確認
4. **緊急対応**: Circuit Breaker、トラフィック制限
5. **根本対応**: インフラ修復、設定変更
6. **復旧確認**: DLQ処理、失敗タスクの再実行

#### 定期メンテナンス
- DLQの定期的なレビューと処理
- エラーパターンの分析と改善
- アラート閾値の調整
- リトライポリシーの最適化

## 12. 構造化ログ戦略

このサービスでは、運用性とデバッグ効率を向上させるため、構造化ログを採用します。

### ログフレームワーク
- **使用ライブラリ**: `slog` (Go標準ライブラリ) または `zap`
- **出力形式**: JSON形式
- **ログレベル**: Debug, Info, Warn, Error, CRITICAL
- **CRITICALレベル**: panicにして処理を停止させないといけないレベル（データ整合性の致命的破壊、システムリソースの枯渇等）

### ログ構造の標準フィールド
```go
type LogContext struct {
    // 必須フィールド
    Timestamp   time.Time `json:"timestamp"`
    Level       string    `json:"level"`
    Service     string    `json:"service"`     // "avion-media"
    Version     string    `json:"version"`     // サービスバージョン
    TraceID     string    `json:"trace_id"`    // OpenTelemetry TraceID
    SpanID      string    `json:"span_id"`     // OpenTelemetry SpanID
    
    // コンテキストフィールド
    UserID      string    `json:"user_id,omitempty"`
    MediaID     string    `json:"media_id,omitempty"`
    TaskID      string    `json:"task_id,omitempty"`
    RequestID   string    `json:"request_id,omitempty"`
    Method      string    `json:"method,omitempty"`      // gRPCメソッド名
    Layer       string    `json:"layer,omitempty"`       // domain/usecase/infra/handler
    
    // エラー情報
    Error       string    `json:"error,omitempty"`
    ErrorCode   string    `json:"error_code,omitempty"`
    StackTrace  string    `json:"stack_trace,omitempty"`
    
    // パフォーマンス
    Duration    int64     `json:"duration_ms,omitempty"` // 処理時間（ミリ秒）
    
    // カスタムフィールド
    Extra       map[string]interface{} `json:"extra,omitempty"`
}
```

### 各層でのログ出力例

#### Handler層
```go
logger.Info("gRPC request received",
    slog.String("method", "RequestMediaUpload"),
    slog.String("trace_id", traceID),
    slog.String("user_id", userID),
    slog.String("content_type", contentType),
    slog.Int64("file_size", fileSize),
    slog.String("layer", "handler"),
)

logger.Error("gRPC request failed",
    slog.String("method", "GetMediaInfo"),
    slog.String("trace_id", traceID),
    slog.String("error", err.Error()),
    slog.String("error_code", "MEDIA_NOT_FOUND"),
    slog.Int64("duration_ms", duration),
)
```

#### Use Case層
```go
logger.Info("upload request processing",
    slog.String("trace_id", ctx.Value("trace_id").(string)),
    slog.String("media_type", mediaType),
    slog.String("media_format", mediaFormat),
    slog.Int64("file_size", fileSize),
    slog.String("layer", "usecase"),
)

logger.Info("media processing task created",
    slog.String("task_id", taskID),
    slog.String("task_type", taskType),
    slog.String("media_id", mediaID),
    slog.String("layer", "usecase"),
)
```

#### Infrastructure層
```go
logger.Debug("s3 presigned url generated",
    slog.String("bucket", bucket),
    slog.String("key", key),
    slog.String("method", "PUT"),
    slog.Int64("expires_seconds", expiresIn),
    slog.String("layer", "infra"),
)

logger.Warn("redis queue lag detected",
    slog.String("queue", "media_processing_queue"),
    slog.Int("pending_tasks", pendingCount),
    slog.Int64("oldest_task_age_ms", oldestAge),
    slog.String("layer", "infra"),
)
```

### アップロード処理のログ
```go
// Presigned URL生成
logger.Info("presigned url created",
    slog.String("event", "presigned_url_created"),
    slog.String("media_id", mediaID),
    slog.String("storage_key", storageKey),
    slog.String("content_type", contentType),
    slog.Int64("max_size", maxSize),
)

// アップロード完了
logger.Info("media upload completed",
    slog.String("event", "upload_completed"),
    slog.String("media_id", mediaID),
    slog.String("user_id", userID),
    slog.String("upload_status", "completed"),
    slog.Int64("file_size", fileSize),
)

// バリデーションエラー
logger.Warn("media validation failed",
    slog.String("event", "validation_failed"),
    slog.String("media_id", mediaID),
    slog.String("reason", reason),
    slog.String("media_format", mediaFormat),
    slog.Int64("file_size", fileSize),
)
```

### 非同期処理のログ
```go
// サムネイル生成
logger.Info("thumbnail generation started",
    slog.String("event", "thumbnail_started"),
    slog.String("task_id", taskID),
    slog.String("media_id", mediaID),
    slog.String("source_format", sourceFormat),
    slog.String("thumbnail_size", thumbnailSize),
)

logger.Info("thumbnail generated",
    slog.String("event", "thumbnail_completed"),
    slog.String("task_id", taskID),
    slog.String("media_id", mediaID),
    slog.String("thumbnail_id", thumbnailID),
    slog.Int64("processing_time_ms", processingTime),
    slog.Int64("output_size", outputSize),
)

// タスクリトライ
logger.Warn("task retry scheduled",
    slog.String("event", "task_retry"),
    slog.String("task_id", taskID),
    slog.String("task_type", taskType),
    slog.Int("retry_count", retryCount),
    slog.String("error", lastError),
    slog.Time("next_retry_at", nextRetryTime),
)
```

### リモートメディアキャッシュのログ
```go
// キャッシュリクエスト
logger.Info("remote media cache requested",
    slog.String("event", "cache_requested"),
    slog.String("remote_url", maskURL(remoteURL)),
    slog.String("cache_key", cacheKey),
    slog.Bool("already_cached", alreadyCached),
)

// ダウンロード処理
logger.Info("remote media download",
    slog.String("event", "remote_download"),
    slog.String("cache_key", cacheKey),
    slog.String("remote_host", remoteHost),
    slog.Int64("content_length", contentLength),
    slog.Int64("download_time_ms", downloadTime),
    slog.Bool("success", success),
)

// キャッシュヒット
logger.Debug("remote media cache hit",
    slog.String("cache_key", cacheKey),
    slog.String("local_media_id", localMediaID),
    slog.Time("cached_at", cachedAt),
)
```

### メディア削除のログ
```go
// 削除タスク受信
logger.Info("media deletion scheduled",
    slog.String("event", "deletion_scheduled"),
    slog.String("media_id", mediaID),
    slog.String("drop_id", dropID),
    slog.Int64("delay_seconds", delaySeconds),
)

// 削除実行
logger.Info("media deleted",
    slog.String("event", "media_deleted"),
    slog.String("media_id", mediaID),
    slog.Int("files_deleted", filesDeleted),
    slog.String("storage_keys", strings.Join(storageKeys, ",")),
)
```

### エラーログの詳細化
```go
logger.Error("failed to process image",
    slog.String("media_id", mediaID),
    slog.String("task_type", "thumbnail_generation"),
    slog.String("error", err.Error()),
    slog.String("error_type", fmt.Sprintf("%T", err)),
    slog.String("image_format", imageFormat),
    slog.Int64("image_size", imageSize),
    slog.String("stack_trace", string(debug.Stack())),
    slog.String("layer", "infra"),
)
```

### CRITICALレベルログの例
```go
// S3ストレージ完全障害時
logger.With(slog.String("level", "CRITICAL")).Error("s3 storage complete failure",
    slog.String("component", "s3_storage"),
    slog.String("bucket", bucketName),
    slog.String("error", "all_operations_failing"),
    slog.Float64("error_rate", 1.0),
    slog.String("impact", "media_upload_download_stopped"),
)

// メディア処理キュー完全停止時
logger.With(slog.String("level", "CRITICAL")).Error("media processing queue failure",
    slog.String("queue_name", "media_processing_queue"),
    slog.String("error", "all_workers_failed"),
    slog.Int("pending_tasks", pendingTaskCount),
    slog.String("impact", "thumbnail_generation_stopped"),
)

// メディアデータ破損時
logger.With(slog.String("level", "CRITICAL")).Error("media data corruption detected",
    slog.String("media_id", mediaID),
    slog.String("corruption_type", "checksum_mismatch"),
    slog.String("storage_key", storageKey),
    slog.String("action", "immediate_file_quarantine_required"),
)
```

### パフォーマンスログ
```go
// 処理統計
logger.Info("media processing statistics",
    slog.String("event", "processing_stats"),
    slog.String("period", "5m"),
    slog.Int("uploads_completed", uploadsCompleted),
    slog.Int("thumbnails_generated", thumbnailsGenerated),
    slog.Int("remote_cached", remoteCached),
    slog.Int("deletions", deletions),
    slog.Float64("avg_thumbnail_time_ms", avgThumbnailTime),
)

// ストレージ使用量
logger.Info("storage usage",
    slog.String("event", "storage_stats"),
    slog.String("bucket", bucket),
    slog.Int64("total_objects", totalObjects),
    slog.Int64("total_size_bytes", totalSize),
    slog.Float64("avg_object_size_mb", avgSizeMB),
)
```

### ログ集約とクエリ
- **出力先**: 標準出力（Kubernetes環境ではFluentd/Fluent Bitが収集）
- **集約先**: Elasticsearch、CloudWatch Logs、またはLoki
- **クエリ例**:
  ```
  service="avion-media" AND event="upload_completed" AND file_size>10485760
  service="avion-media" AND event="task_retry" AND retry_count>3
  service="avion-media" AND event="thumbnail_completed" AND processing_time_ms>5000
  service="avion-media" AND task_type="remote_cache" AND success=false
  service="avion-media" AND level="CRITICAL"
  ```

### セキュリティ考慮事項
- S3の署名付きURLは絶対にログに含めない
- リモートURLは部分的にマスク（ドメインのみ表示）
- ストレージキーは必要最小限の情報のみ記録
- 個人を特定できるファイル名は避ける

## 13. ドメインオブジェクトとDBスキーマのマッピング

DDDの戦術的パターンに基づき、ドメインオブジェクトを具体的なストレージシステムにマッピングします。メディアサービスの特性上、オブジェクトストレージが中心となり、処理状態の管理にRedisを活用します。

### S3互換オブジェクトストレージマッピング

#### Media Aggregate のマッピング
```go
// ドメインオブジェクト
type Media struct {
    id          MediaID
    mediaType   MediaType     // image, video, audio
    format      MediaFormat   // jpeg, png, mp4, mp3, etc.
    fileSize    FileSize
    dimension   Dimension
    storageKey  StorageKey    // S3オブジェクトキー
    storageURL  StorageURL    // S3 URL
    cdnURL      CDNUrl        // CDN配信URL
    uploadStatus UploadStatus // pending, processing, completed, failed
    sensitivity MediaSensitivity // NSFWフラグ
    description MediaDescription // ALTテキスト
    metadata    MediaMetadata    // EXIF情報など
    audioMeta   AudioMetadata    // 音声メタデータ
    thumbnails  []Thumbnail      // サムネイルEntity
    createdAt   time.Time
    updatedAt   time.Time
}

// S3マッピング仕様
type S3MediaMapping struct {
    BucketName   string // "avion-media"
    KeyTemplate  string // "original/{year}/{month}/{day}/{media_id}.{ext}"
    Metadata     map[string]string
    ContentType  string
    CacheControl string
    ACL          string
}
```

**S3オブジェクト構造**:
```yaml
Bucket: avion-media
Objects:
  # オリジナルファイル
  original/2025/03/15/media_12345.jpg:
    content-type: image/jpeg
    x-amz-meta-media-id: media_12345
    x-amz-meta-user-id: user_67890
    x-amz-meta-media-type: image
    x-amz-meta-format: jpeg
    x-amz-meta-file-size: "2048000"
    x-amz-meta-width: "1920"
    x-amz-meta-height: "1080"
    x-amz-meta-nsfw: "false"
    x-amz-meta-description: "美しい夕日の写真"
    x-amz-meta-upload-status: completed
    x-amz-meta-created-at: "2025-03-15T10:30:00Z"
    cache-control: "public, max-age=31536000"
    
  # 変換済み音声ファイル
  audio/2025/03/15/media_12346.mp3:
    content-type: audio/mpeg
    x-amz-meta-media-id: media_12346
    x-amz-meta-original-format: flac
    x-amz-meta-transcoded: "true"
    x-amz-meta-bitrate: "192000"
    x-amz-meta-duration: "245.6"
    x-amz-meta-codec: "mp3"
    
  # SVG絵文字変換後
  emoji/custom_emoji_123/32.png:
    content-type: image/png
    x-amz-meta-emoji-id: custom_emoji_123
    x-amz-meta-size: "32"
    x-amz-meta-original-svg: emoji/custom_emoji_123/original.svg
```

#### Thumbnail Entity のマッピング
```go
type Thumbnail struct {
    id         ThumbnailID
    mediaID    MediaID      // 親Media Aggregateの参照
    size       Size         // small, medium, large
    dimension  Dimension    // サムネイルの寸法
    storageKey StorageKey   // S3キー
    storageURL StorageURL   // S3 URL
    generatedAt time.Time
}

// S3キー生成規則
func (t *Thumbnail) GenerateStorageKey() string {
    date := t.generatedAt.Format("2006/01/02")
    return fmt.Sprintf("thumbnail/%s/%s/%s.jpg", 
        t.size.String(), date, t.mediaID.String())
}
```

**サムネイルS3構造**:
```yaml
  # サムネイル（複数サイズ）
  thumbnail/small/2025/03/15/media_12345.jpg:
    content-type: image/jpeg
    x-amz-meta-parent-media-id: media_12345
    x-amz-meta-thumbnail-size: small
    x-amz-meta-width: "320"
    x-amz-meta-height: "180"
    x-amz-meta-generated-at: "2025-03-15T10:35:00Z"
    cache-control: "public, max-age=31536000"
    
  thumbnail/medium/2025/03/15/media_12345.jpg:
    content-type: image/jpeg
    x-amz-meta-parent-media-id: media_12345
    x-amz-meta-thumbnail-size: medium
    x-amz-meta-width: "640"
    x-amz-meta-height: "360"
    
  thumbnail/large/2025/03/15/media_12345.jpg:
    content-type: image/jpeg
    x-amz-meta-parent-media-id: media_12345
    x-amz-meta-thumbnail-size: large
    x-amz-meta-width: "1280"
    x-amz-meta-height: "720"
```

#### RemoteMediaCache Aggregate のマッピング
```go
type RemoteMediaCache struct {
    cacheKey       CacheKey      // hash(RemoteURL)
    remoteURL      RemoteURL     // オリジナルURL
    localMediaID   MediaID       // ローカルに保存したMediaID
    cacheStatus    CacheStatus   // active, expired, deleted
    cachedAt       time.Time
    lastAccessedAt time.Time
    expiresAt      time.Time
}

// キャッシュキー生成
func generateCacheKey(remoteURL string) string {
    hash := sha256.Sum256([]byte(remoteURL))
    return fmt.Sprintf("%x", hash[:16]) // 先頭32文字
}
```

**リモートキャッシュS3構造**:
```yaml
  # リモートメディアキャッシュ
  cached_remote/a1b2c3d4e5f6g7h8:
    content-type: image/jpeg
    x-amz-meta-cache-key: a1b2c3d4e5f6g7h8
    x-amz-meta-remote-url: https://example.com/media/photo.jpg
    x-amz-meta-local-media-id: cached_media_56789
    x-amz-meta-cached-at: "2025-03-15T11:00:00Z"
    x-amz-meta-last-accessed: "2025-03-15T14:30:00Z"
    x-amz-meta-expires-at: "2025-04-15T11:00:00Z"
    x-amz-meta-cache-status: active
    x-amz-meta-remote-host: example.com
```

### Redis マッピング

#### MediaProcessingTask Aggregate のマッピング
```go
type MediaProcessingTask struct {
    id           TaskID
    taskType     TaskType     // thumbnail_generation, audio_transcoding, etc.
    taskStatus   TaskStatus   // pending, processing, completed, failed
    mediaID      MediaID      // 処理対象
    retryCount   int
    maxRetries   int
    scheduledAt  time.Time
    processedAt  time.Time
    errorInfo    ProcessingError
}

// Redis Stream マッピング
type RedisStreamMapping struct {
    StreamName    string // "media_processing_queue"
    ConsumerGroup string // "media_workers"
    MessageID     string // "*" for auto-generation
    Fields        map[string]interface{}
}
```

**Redis Stream構造**:
```redis
# 非同期処理キュー (Stream)
STREAM media_processing_queue:
  1710505800000-0: {
    "task_id": "task_12345",
    "task_type": "thumbnail_generation",
    "media_id": "media_12345",
    "user_id": "user_67890",
    "retry_count": "0",
    "max_retries": "3",
    "scheduled_at": "2025-03-15T10:30:00Z",
    "priority": "normal"
  }
  
STREAM gif_thumbnail_queue:
  1710505900000-0: {
    "task_id": "task_12346",
    "task_type": "gif_thumbnail",
    "media_id": "media_12346",
    "frame_position": "0.5",
    "output_size": "medium"
  }

# Consumer Group
CONSUMER GROUP media_workers:
  consumers: ["worker-1", "worker-2", "worker-3"]
  pending: [...]
  processed: [...]
```

#### UserDrive/MediaBatch のマッピング
```go
type UserDrive struct {
    userID        UserID
    totalUsage    int64        // bytes
    fileCount     int
    quotaLimit    int64        // bytes
    folders       []MediaFolder
    lastUpdated   time.Time
}

type MediaBatch struct {
    batchID       BatchID
    userID        UserID
    mediaIDs      []MediaID
    batchStatus   BatchStatus  // pending, processing, completed, partial_failed
    totalCount    int
    completedCount int
    failedCount   int
    createdAt     time.Time
}
```

**Redis Hash構造**:
```redis
# ユーザードライブ情報
HASH user_drive:user_67890:
  total_usage: "2048000000"      # 2GB
  file_count: "150"
  quota_limit: "5368709120"      # 5GB
  last_updated: "2025-03-15T15:00:00Z"
  
# バッチ処理状態
HASH batch:batch_12345:
  user_id: "user_67890"
  batch_status: "processing"
  total_count: "5"
  completed_count: "3"
  failed_count: "1"
  created_at: "2025-03-15T14:45:00Z"
  media_ids: "media_001,media_002,media_003,media_004,media_005"
  
# メディア使用状況追跡
HASH media_usage:media_12345:
  usage_count: "3"               # 使用回数
  last_used_at: "2025-03-15T14:30:00Z"
  attached_drops: "drop_001,drop_002,drop_003"
  
# 管理者設定
HASH media_limits:
  image_max_size: "10485760"     # 10MB
  video_max_size: "41943040"     # 40MB
  audio_max_size: "41943040"     # 40MB
  supported_formats: "jpeg,png,gif,webp,mp4,mp3,ogg,wav"
  thumbnail_sizes: "320x180,640x360,1280x720"
```

### CDN統合マッピング

#### CDN URL 生成戦略
```go
type CDNMapping struct {
    BaseURL        string // "https://cdn.avion.example.com"
    PathTransform  func(StorageKey) string
    CacheHeaders   map[string]string
    PurgeStrategy  string
}

// CDN URL生成
func (m *Media) GenerateCDNURL() string {
    // S3キー: "original/2025/03/15/media_12345.jpg"
    // CDN URL: "https://cdn.avion.example.com/media/2025/03/15/media_12345.jpg"
    return fmt.Sprintf("%s/media/%s", 
        config.CDN.BaseURL, 
        strings.Replace(m.storageKey.String(), "original/", "", 1))
}

func (t *Thumbnail) GenerateCDNURL() string {
    // S3キー: "thumbnail/medium/2025/03/15/media_12345.jpg"
    // CDN URL: "https://cdn.avion.example.com/thumb/medium/2025/03/15/media_12345.jpg"
    return fmt.Sprintf("%s/thumb/%s/%s", 
        config.CDN.BaseURL,
        t.size.String(),
        strings.Replace(t.storageKey.String(), fmt.Sprintf("thumbnail/%s/", t.size.String()), "", 1))
}
```

### データ整合性の確保

#### 整合性チェック機能
```go
type ConsistencyChecker struct {
    s3Client    S3Client
    redisClient RedisClient
}

// S3とRedisの整合性確認
func (c *ConsistencyChecker) ValidateMediaConsistency(mediaID MediaID) error {
    // 1. S3にオリジナルファイルが存在するか確認
    exists, err := c.s3Client.ObjectExists(generateOriginalKey(mediaID))
    if err != nil {
        return fmt.Errorf("failed to check S3 object: %w", err)
    }
    if !exists {
        return errors.New("original file not found in S3")
    }
    
    // 2. サムネイルの存在確認
    for _, size := range []string{"small", "medium", "large"} {
        thumbExists, err := c.s3Client.ObjectExists(generateThumbnailKey(mediaID, size))
        if err != nil {
            return fmt.Errorf("failed to check thumbnail %s: %w", size, err)
        }
        if !thumbExists {
            // サムネイル再生成タスクをキューに追加
            c.scheduleRethumbnail(mediaID, size)
        }
    }
    
    // 3. 処理中タスクの確認
    pendingTasks, err := c.redisClient.GetPendingTasks(mediaID)
    if err != nil {
        return fmt.Errorf("failed to check pending tasks: %w", err)
    }
    
    // 長時間処理中のタスクがあれば警告
    for _, task := range pendingTasks {
        if time.Since(task.ScheduledAt) > 30*time.Minute {
            logger.Warn("long running task detected",
                slog.String("task_id", task.ID),
                slog.String("media_id", mediaID.String()),
                slog.Duration("duration", time.Since(task.ScheduledAt)))
        }
    }
    
    return nil
}
```

#### バックアップとリストア戦略
```go
type BackupStrategy struct {
    S3Backup    S3BackupConfig
    RedisBackup RedisBackupConfig
    Schedule    string // cron expression
}

type S3BackupConfig struct {
    DestinationBucket string
    CrossRegion       bool
    RetentionDays     int
    Compression       bool
}

// メディアデータのバックアップ
func (b *BackupStrategy) BackupMediaData(mediaID MediaID) error {
    // 1. S3オブジェクトのクロスリージョンレプリケーション
    originalKey := generateOriginalKey(mediaID)
    err := b.replicateToBackupRegion(originalKey)
    if err != nil {
        return fmt.Errorf("failed to replicate original: %w", err)
    }
    
    // 2. サムネイルのバックアップ
    for _, size := range []string{"small", "medium", "large"} {
        thumbKey := generateThumbnailKey(mediaID, size)
        err := b.replicateToBackupRegion(thumbKey)
        if err != nil {
            logger.Warn("thumbnail backup failed",
                slog.String("media_id", mediaID.String()),
                slog.String("size", size),
                slog.String("error", err.Error()))
        }
    }
    
    // 3. メタデータのスナップショット
    metadata := b.extractMetadata(mediaID)
    err = b.storeMetadataSnapshot(mediaID, metadata)
    if err != nil {
        return fmt.Errorf("failed to backup metadata: %w", err)
    }
    
    return nil
}
```

## 14. Integration Specifications (連携仕様)

### 13.1. avion-drop との連携

**Purpose:** Dropの作成・削除時のメディア使用状況管理とライフサイクル連携

**Integration Method:** Redis Pub/Sub Events

**Data Flow:**
1. Drop作成時: avion-dropがDrop_Createdイベントを発行（mediaIDsリストを含む）
2. avion-mediaはイベントを受信し、該当メディアの使用カウンタをインクリメント
3. Drop削除時: avion-dropがDrop_Deletedイベントを発行（mediaIDsリストを含む）
4. avion-mediaはイベントを受信し、該当メディアの使用カウンタをデクリメント
5. 使用カウンタが0になったメディアは削除候補としてマーク
6. 遅延削除タスクをスケジュール（72時間後）
7. 削除実行前に最終確認を行い、参照が復活していない場合のみ物理削除

**Error Handling:** イベント処理失敗時はDLQ（Dead Letter Queue）に送信し、手動復旧フローを実行

### 13.2. avion-activitypub との連携

**Purpose:** リモートメディアのローカルキャッシング処理

**Integration Method:** gRPC

**Data Flow:**
1. avion-activitypubがリモートDropを受信
2. 含まれるメディアURLをavion-mediaのCacheRemoteMediaエンドポイントに送信
3. avion-mediaはリモートメディアキャッシュタスクを非同期実行
4. ダウンロード・検証・ローカル保存・サムネイル生成を実行
5. 完了時にローカルメディアIDとCDN URLをレスポンス
6. avion-activitypubは受信したローカルURLでDrop情報を更新

**Error Handling:** 
- ダウンロード失敗: 元のリモートURLを保持、定期的に再試行
- セキュリティ検証失敗: キャッシュをスキップ、監査ログに記録
- 容量制限超過: LRU方式で古いキャッシュを削除後に再実行

### 13.3. avion-gateway との連携

**Purpose:** メディアアップロード・管理API の提供

**Integration Method:** gRPC

**Data Flow:**
1. クライアントがメディアアップロード要求
2. avion-gatewayが認証情報を検証してavion-mediaにリクエスト転送
3. avion-mediaはPresigned URLを生成してレスポンス
4. クライアントが直接S3にアップロード
5. アップロード完了後、クライアントからavion-mediaに完了通知
6. avion-mediaは非同期でサムネイル生成・メタデータ抽出を実行
7. 処理完了をSSEでavion-gatewayに通知
8. avion-gatewayはWebSocketでクライアントに通知

**Error Handling:** 
- 認証エラー: codes.Unauthenticated
- 容量制限エラー: codes.ResourceExhausted
- 処理失敗: SSEでエラーイベントを送信

### 13.4. Event Publishing

**Events Published:**
- `media.uploaded`: メディアアップロード完了時
- `media.processing.completed`: サムネイル生成等の処理完了時
- `media.deleted`: メディア削除完了時
- `media.cache.created`: リモートメディアキャッシュ作成時
- `media.usage.updated`: 使用状況変更時

**Event Schema:**
```go
type MediaUploadedEvent struct {
    MediaID     string    `json:"media_id"`
    UserID      string    `json:"user_id"`
    MediaType   string    `json:"media_type"`
    FileSize    int64     `json:"file_size"`
    Timestamp   time.Time `json:"timestamp"`
}

type MediaProcessingCompletedEvent struct {
    MediaID           string    `json:"media_id"`
    ProcessingType    string    `json:"processing_type"` // thumbnail, audio_transcode, etc.
    Success           bool      `json:"success"`
    ThumbnailURLs     []string  `json:"thumbnail_urls,omitempty"`
    Error             string    `json:"error,omitempty"`
    Timestamp         time.Time `json:"timestamp"`
}

type MediaDeletedEvent struct {
    MediaID       string    `json:"media_id"`
    UserID        string    `json:"user_id"`
    DeleteReason  string    `json:"delete_reason"`
    StorageKeys   []string  `json:"storage_keys"`
    Timestamp     time.Time `json:"timestamp"`
}
```

### 13.5. avion-notification との連携

**Purpose:** メディア処理完了・エラーの通知

**Integration Method:** Redis Pub/Sub Events

**Data Flow:**
1. メディア処理（サムネイル生成、変換等）が完了
2. avion-mediaが処理結果イベントを発行
3. avion-notificationがイベントを受信
4. ユーザー設定に基づいて通知方法を決定（プッシュ、メール等）
5. 成功時はシンプルな完了通知、エラー時は詳細とリカバリ手順を含む通知を送信

**Error Handling:** 通知配信失敗時も元の処理は正常完了として扱う

## 15. Concerns / Open Questions (懸念事項・相談したいこと)

- **技術的負債リスク:**
    - **非同期処理の複雑性:** 複数の非同期フローと外部サービス連携があり、エラーハンドリング、冪等性確保、状態管理が複雑化しやすい。実装・運用コストが高く、不備はデータ不整合や処理漏れに繋がる。
    - **外部サービス依存:** S3互換ストレージやCDNへの依存度が高く、仕様変更、障害、コスト変動の影響を受ける。ロックインリスク。
    - **ストレージコスト管理:** 未使用ファイル削除ポリシーやリモートキャッシュ戦略が不明確だと、コストが予期せず増大する可能性がある。継続的なモニタリングとポリシー見直しが必要。
    - **処理負荷の増大:** 音声変換、SVG変換、複数サイズのサムネイル生成など、CPU/メモリ集約的な処理が増加。適切なリソース配分とスケーリング戦略が必要。
- 動画処理 (サムネイル生成) の具体的なライブラリ/ツール選定とリソース要件。
- 音声処理 (ffmpeg) のコンテナイメージサイズとセキュリティ対策。
- SVG→PNG変換ライブラリの選定（librsvg、ImageMagick等）とセキュリティリスク。
- リモートメディアキャッシュのポリシー詳細 (対象ドメイン、不正利用対策)。
- メディア削除戦略 (遅延削除の具体的な実装、参照カウントの導入是非)。
- ユーザードライブの容量制限とクォータ管理の実装方式。
- バッチアップロードの同時接続数制限とレート制限。
- NSFW判定の自動化（機械学習モデル活用）の検討。

## 16. Service-Specific Test Strategy (サービス固有のテスト戦略)

### 15.1. Overview (概要)

avion-mediaサービスは、メディア処理パイプライン、外部ストレージとの連携、非同期タスク処理など、複雑な処理フローを持つため、包括的なテスト戦略が必要です。

**Testing Objectives:**
- メディア処理パイプラインの品質保証
- 外部サービス（S3、CDN、VirusScanning）との統合信頼性
- 非同期処理とエラーハンドリングの確実性
- パフォーマンス要件の満足
- セキュリティ脆弱性の防止

### 15.2. Test Categories (テストカテゴリ)

#### 15.2.1. Unit Tests (単体テスト)

**Coverage Target:** 95% for critical paths, 90% minimum overall

**Core Testing Areas:**
- メディア処理アルゴリズム（リサイズ、圧縮、変換）
- ファイル形式検証とmagic number チェック
- EXIF メタデータ除去
- プリサインドURL生成ロジック
- バリデーション関数

```go
// Example: Image Processing Pipeline Testing
func TestImageProcessingPipeline(t *testing.T) {
    tests := []struct {
        name           string
        input          []byte
        format         string
        options        ProcessingOptions
        expectedFormat string
        expectedSize   ImageSize
        expectError    bool
    }{
        {
            name:   "JPEG resize with compression",
            input:  loadTestImage("sample.jpg"),
            format: "jpeg",
            options: ProcessingOptions{
                Width:       800,
                Height:      600,
                Quality:     85,
                StripEXIF:   true,
                Compression: CompressionHigh,
            },
            expectedFormat: "jpeg",
            expectedSize:   ImageSize{Width: 800, Height: 600},
            expectError:    false,
        },
        {
            name:   "PNG with transparency preservation",
            input:  loadTestImage("sample.png"),
            format: "png",
            options: ProcessingOptions{
                Width:              400,
                Height:             300,
                PreserveTransparency: true,
                OptimizePNG:        true,
            },
            expectedFormat: "png",
            expectedSize:   ImageSize{Width: 400, Height: 300},
            expectError:    false,
        },
        {
            name:        "Invalid image format",
            input:       []byte("invalid image data"),
            format:      "jpeg",
            options:     ProcessingOptions{},
            expectError: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            processor := NewImageProcessor()
            
            result, err := processor.ProcessImage(context.Background(), tt.input, tt.format, tt.options)
            
            if tt.expectError {
                assert.Error(t, err)
                return
            }
            
            assert.NoError(t, err)
            assert.Equal(t, tt.expectedFormat, result.Format)
            assert.Equal(t, tt.expectedSize.Width, result.Dimensions.Width)
            assert.Equal(t, tt.expectedSize.Height, result.Dimensions.Height)
            
            // Verify EXIF removal
            if tt.options.StripEXIF {
                hasEXIF, _ := CheckEXIFData(result.Data)
                assert.False(t, hasEXIF, "EXIF data should be removed")
            }
            
            // Verify compression effectiveness
            if tt.options.Compression == CompressionHigh {
                compressionRatio := float64(len(result.Data)) / float64(len(tt.input))
                assert.Less(t, compressionRatio, 0.8, "Compression should reduce file size significantly")
            }
        })
    }
}

// Example: File Type Validation with Magic Number Checking
func TestFileTypeValidation(t *testing.T) {
    tests := []struct {
        name         string
        fileData     []byte
        filename     string
        expectedType string
        expectError  bool
    }{
        {
            name:         "Valid JPEG file",
            fileData:     []byte{0xFF, 0xD8, 0xFF, 0xE0}, // JPEG magic number
            filename:     "test.jpg",
            expectedType: "image/jpeg",
            expectError:  false,
        },
        {
            name:         "Valid PNG file",
            fileData:     []byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A}, // PNG magic number
            filename:     "test.png",
            expectedType: "image/png",
            expectError:  false,
        },
        {
            name:         "Mismatched extension and content",
            fileData:     []byte{0xFF, 0xD8, 0xFF, 0xE0}, // JPEG content
            filename:     "test.png",                      // PNG extension
            expectedType: "",
            expectError:  true,
        },
        {
            name:         "Malicious file with fake extension",
            fileData:     []byte{0x4D, 0x5A}, // PE executable magic number
            filename:     "malware.jpg",
            expectedType: "",
            expectError:  true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            validator := NewFileTypeValidator()
            
            detectedType, err := validator.ValidateFileType(tt.fileData, tt.filename)
            
            if tt.expectError {
                assert.Error(t, err)
                return
            }
            
            assert.NoError(t, err)
            assert.Equal(t, tt.expectedType, detectedType)
        })
    }
}
```

#### 15.2.2. Integration Tests (統合テスト)

**S3 Integration with Mock Testing:**

```go
// Example: S3 Integration Testing with Mocks
func TestS3Integration(t *testing.T) {
    // Setup mock S3 client
    mockS3 := &MockS3Client{}
    mediaRepo := NewMediaRepository(mockS3)
    
    tests := []struct {
        name              string
        setupMock         func(*MockS3Client)
        mediaData         []byte
        mediaType         string
        expectedUploadURL string
        expectError       bool
    }{
        {
            name: "Successful multipart upload",
            setupMock: func(m *MockS3Client) {
                m.EXPECT().CreateMultipartUpload(gomock.Any(), gomock.Any()).
                    Return(&s3.CreateMultipartUploadOutput{
                        UploadId: aws.String("test-upload-id"),
                    }, nil)
                
                m.EXPECT().UploadPart(gomock.Any(), gomock.Any()).
                    Return(&s3.UploadPartOutput{
                        ETag: aws.String("test-etag"),
                    }, nil).AnyTimes()
                
                m.EXPECT().CompleteMultipartUpload(gomock.Any(), gomock.Any()).
                    Return(&s3.CompleteMultipartUploadOutput{}, nil)
            },
            mediaData:         generateLargeTestFile(10 * 1024 * 1024), // 10MB
            mediaType:         "image/jpeg",
            expectedUploadURL: "https://cdn.example.com/media/test-file",
            expectError:       false,
        },
        {
            name: "Upload failure with retry",
            setupMock: func(m *MockS3Client) {
                m.EXPECT().CreateMultipartUpload(gomock.Any(), gomock.Any()).
                    Return(nil, errors.New("network error")).Times(1)
                
                m.EXPECT().CreateMultipartUpload(gomock.Any(), gomock.Any()).
                    Return(&s3.CreateMultipartUploadOutput{
                        UploadId: aws.String("test-upload-id"),
                    }, nil).Times(1)
                
                m.EXPECT().UploadPart(gomock.Any(), gomock.Any()).
                    Return(&s3.UploadPartOutput{
                        ETag: aws.String("test-etag"),
                    }, nil).AnyTimes()
                
                m.EXPECT().CompleteMultipartUpload(gomock.Any(), gomock.Any()).
                    Return(&s3.CompleteMultipartUploadOutput{}, nil)
            },
            mediaData:         generateTestFile(1024), // 1KB
            mediaType:         "image/png",
            expectedUploadURL: "https://cdn.example.com/media/test-file-retry",
            expectError:       false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            tt.setupMock(mockS3)
            
            ctx := context.Background()
            uploadResult, err := mediaRepo.UploadMedia(ctx, tt.mediaData, tt.mediaType)
            
            if tt.expectError {
                assert.Error(t, err)
                return
            }
            
            assert.NoError(t, err)
            assert.NotEmpty(t, uploadResult.URL)
            assert.NotEmpty(t, uploadResult.StorageKey)
            
            // Verify pre-signed URL generation
            presignedURL, err := mediaRepo.GeneratePresignedURL(ctx, uploadResult.StorageKey, 1*time.Hour)
            assert.NoError(t, err)
            assert.Contains(t, presignedURL, "X-Amz-Signature")
        })
    }
}
```

#### 15.2.3. Async Task Processing Tests (非同期タスク処理テスト)

```go
// Example: Redis Streams Async Task Testing
func TestAsyncTaskProcessing(t *testing.T) {
    // Setup test Redis client
    redisClient := redis.NewClient(&redis.Options{
        Addr: "localhost:6379",
        DB:   1, // Use test database
    })
    defer redisClient.Close()
    
    taskProcessor := NewTaskProcessor(redisClient)
    
    tests := []struct {
        name           string
        task           ProcessingTask
        expectedRetries int
        expectedStatus  TaskStatus
        simulateFailure bool
    }{
        {
            name: "Video thumbnail generation success",
            task: ProcessingTask{
                ID:        "task-001",
                Type:      TaskTypeVideoThumbnail,
                MediaID:   "media-001",
                InputURL:  "https://storage.example.com/video.mp4",
                Options:   map[string]interface{}{"timestamp": "00:00:10"},
            },
            expectedRetries: 0,
            expectedStatus:  TaskStatusCompleted,
            simulateFailure: false,
        },
        {
            name: "Image processing with retry logic",
            task: ProcessingTask{
                ID:       "task-002",
                Type:     TaskTypeImageResize,
                MediaID:  "media-002",
                InputURL: "https://storage.example.com/image.jpg",
                Options: map[string]interface{}{
                    "width":  800,
                    "height": 600,
                    "quality": 85,
                },
            },
            expectedRetries: 2,
            expectedStatus:  TaskStatusCompleted,
            simulateFailure: true, // First 2 attempts fail
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
            defer cancel()
            
            // Setup failure simulation
            if tt.simulateFailure {
                taskProcessor.SetFailureSimulation(tt.task.ID, tt.expectedRetries)
            }
            
            // Submit task
            err := taskProcessor.SubmitTask(ctx, tt.task)
            assert.NoError(t, err)
            
            // Wait for processing completion
            result, err := taskProcessor.WaitForCompletion(ctx, tt.task.ID)
            assert.NoError(t, err)
            
            assert.Equal(t, tt.expectedStatus, result.Status)
            assert.Equal(t, tt.expectedRetries, result.RetryCount)
            
            if result.Status == TaskStatusCompleted {
                assert.NotEmpty(t, result.OutputURL)
                assert.NotEmpty(t, result.Metadata)
            }
        })
    }
}

// Example: Dead Letter Queue Handling
func TestDeadLetterQueueHandling(t *testing.T) {
    redisClient := redis.NewClient(&redis.Options{Addr: "localhost:6379", DB: 1})
    defer redisClient.Close()
    
    dlqHandler := NewDeadLetterQueueHandler(redisClient)
    
    // Create a task that will consistently fail
    poisonTask := ProcessingTask{
        ID:       "poison-task",
        Type:     TaskTypeImageResize,
        MediaID:  "corrupt-media",
        InputURL: "https://storage.example.com/corrupt-image.jpg",
        Options:  map[string]interface{}{"width": 800},
    }
    
    ctx := context.Background()
    
    // Process task through normal retry mechanism
    taskProcessor := NewTaskProcessor(redisClient)
    taskProcessor.SetMaxRetries(3)
    taskProcessor.SetFailureSimulation(poisonTask.ID, 10) // Always fail
    
    err := taskProcessor.SubmitTask(ctx, poisonTask)
    assert.NoError(t, err)
    
    // Wait for task to be moved to DLQ
    time.Sleep(5 * time.Second)
    
    // Verify task is in DLQ
    dlqTasks, err := dlqHandler.GetDLQTasks(ctx, 0, 10)
    assert.NoError(t, err)
    assert.Len(t, dlqTasks, 1)
    assert.Equal(t, poisonTask.ID, dlqTasks[0].ID)
    assert.Equal(t, 3, dlqTasks[0].RetryCount)
    
    // Test DLQ task reprocessing
    err = dlqHandler.RequeueTask(ctx, poisonTask.ID)
    assert.NoError(t, err)
    
    // Verify task is removed from DLQ
    dlqTasksAfter, err := dlqHandler.GetDLQTasks(ctx, 0, 10)
    assert.NoError(t, err)
    assert.Len(t, dlqTasksAfter, 0)
}
```

#### 15.2.4. Performance Tests (パフォーマンステスト)

```go
// Example: Large File Upload Performance Testing
func TestLargeFileUploadPerformance(t *testing.T) {
    if testing.Short() {
        t.Skip("Skipping performance test in short mode")
    }
    
    tests := []struct {
        name         string
        fileSize     int64
        expectedTime time.Duration
        concurrency  int
    }{
        {
            name:         "100MB file upload",
            fileSize:     100 * 1024 * 1024,
            expectedTime: 30 * time.Second,
            concurrency:  1,
        },
        {
            name:         "500MB file upload",
            fileSize:     500 * 1024 * 1024,
            expectedTime: 2 * time.Minute,
            concurrency:  1,
        },
        {
            name:         "Concurrent 10MB uploads",
            fileSize:     10 * 1024 * 1024,
            expectedTime: 45 * time.Second,
            concurrency:  5,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            uploader := NewMediaUploader(setupS3Config())
            
            // Generate test file data
            testData := make([]byte, tt.fileSize)
            rand.Read(testData)
            
            startTime := time.Now()
            
            if tt.concurrency == 1 {
                // Single upload test
                _, err := uploader.UploadMedia(context.Background(), testData, "application/octet-stream")
                assert.NoError(t, err)
            } else {
                // Concurrent upload test
                var wg sync.WaitGroup
                errChan := make(chan error, tt.concurrency)
                
                for i := 0; i < tt.concurrency; i++ {
                    wg.Add(1)
                    go func() {
                        defer wg.Done()
                        _, err := uploader.UploadMedia(context.Background(), testData, "application/octet-stream")
                        if err != nil {
                            errChan <- err
                        }
                    }()
                }
                
                wg.Wait()
                close(errChan)
                
                // Check for any errors
                for err := range errChan {
                    assert.NoError(t, err)
                }
            }
            
            elapsed := time.Since(startTime)
            assert.Less(t, elapsed, tt.expectedTime, 
                "Upload took longer than expected: %v > %v", elapsed, tt.expectedTime)
            
            // Calculate throughput
            throughputMBps := float64(tt.fileSize*int64(tt.concurrency)) / elapsed.Seconds() / (1024 * 1024)
            t.Logf("Throughput: %.2f MB/s", throughputMBps)
            
            // Minimum throughput assertion
            assert.Greater(t, throughputMBps, 5.0, "Throughput should be at least 5 MB/s")
        })
    }
}

// Example: Memory Usage Testing for Large Files
func TestMemoryUsageDuringProcessing(t *testing.T) {
    if testing.Short() {
        t.Skip("Skipping memory test in short mode")
    }
    
    processor := NewImageProcessor()
    
    // Generate large test image (50MB uncompressed)
    largeImageData := generateLargeTestImage(8000, 6000) // 8000x6000 RGBA
    
    var memStatsBefore, memStatsAfter runtime.MemStats
    runtime.GC()
    runtime.ReadMemStats(&memStatsBefore)
    
    // Process multiple images to test memory management
    for i := 0; i < 10; i++ {
        result, err := processor.ProcessImage(context.Background(), largeImageData, "jpeg", ProcessingOptions{
            Width:   1920,
            Height:  1080,
            Quality: 85,
        })
        assert.NoError(t, err)
        assert.NotNil(t, result)
        
        // Force garbage collection every few iterations
        if i%3 == 0 {
            runtime.GC()
        }
    }
    
    runtime.GC()
    runtime.ReadMemStats(&memStatsAfter)
    
    // Memory usage should not grow significantly
    memoryGrowthMB := float64(memStatsAfter.Alloc-memStatsBefore.Alloc) / (1024 * 1024)
    t.Logf("Memory growth: %.2f MB", memoryGrowthMB)
    
    // Assert memory growth is reasonable (less than 100MB for this test)
    assert.Less(t, memoryGrowthMB, 100.0, "Memory usage grew too much during processing")
}
```

#### 15.2.5. Security Tests (セキュリティテスト)

```go
// Example: Virus Scanning Integration Testing
func TestVirusScanningIntegration(t *testing.T) {
    mockScanner := &MockVirusScanner{}
    scanService := NewVirusScanService(mockScanner)
    
    tests := []struct {
        name           string
        fileData       []byte
        setupMock      func(*MockVirusScanner)
        expectedResult ScanResult
        expectError    bool
    }{
        {
            name:     "Clean file scan",
            fileData: generateCleanTestFile(),
            setupMock: func(m *MockVirusScanner) {
                m.EXPECT().ScanFile(gomock.Any(), gomock.Any()).
                    Return(ScanResult{
                        IsClean:    true,
                        ThreatName: "",
                        ScanTime:   time.Now(),
                    }, nil)
            },
            expectedResult: ScanResult{IsClean: true},
            expectError:    false,
        },
        {
            name:     "Infected file detection",
            fileData: generateMaliciousTestFile(),
            setupMock: func(m *MockVirusScanner) {
                m.EXPECT().ScanFile(gomock.Any(), gomock.Any()).
                    Return(ScanResult{
                        IsClean:    false,
                        ThreatName: "EICAR-Test-File",
                        ScanTime:   time.Now(),
                    }, nil)
            },
            expectedResult: ScanResult{IsClean: false, ThreatName: "EICAR-Test-File"},
            expectError:    false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            tt.setupMock(mockScanner)
            
            result, err := scanService.ScanMedia(context.Background(), tt.fileData)
            
            if tt.expectError {
                assert.Error(t, err)
                return
            }
            
            assert.NoError(t, err)
            assert.Equal(t, tt.expectedResult.IsClean, result.IsClean)
            if !result.IsClean {
                assert.Equal(t, tt.expectedResult.ThreatName, result.ThreatName)
            }
        })
    }
}

// Example: CDN Cache Invalidation Testing
func TestCDNCacheInvalidation(t *testing.T) {
    mockCDN := &MockCDNProvider{}
    cacheManager := NewCDNCacheManager(mockCDN)
    
    tests := []struct {
        name        string
        mediaURLs   []string
        setupMock   func(*MockCDNProvider)
        expectError bool
    }{
        {
            name: "Successful cache invalidation",
            mediaURLs: []string{
                "https://cdn.example.com/media/image1.jpg",
                "https://cdn.example.com/media/image2.png",
            },
            setupMock: func(m *MockCDNProvider) {
                m.EXPECT().InvalidateCache(gomock.Any(), gomock.Any()).
                    Return(InvalidationResult{
                        InvalidationID: "inv-12345",
                        Status:         "InProgress",
                    }, nil)
            },
            expectError: false,
        },
        {
            name: "CDN service unavailable",
            mediaURLs: []string{
                "https://cdn.example.com/media/image3.jpg",
            },
            setupMock: func(m *MockCDNProvider) {
                m.EXPECT().InvalidateCache(gomock.Any(), gomock.Any()).
                    Return(InvalidationResult{}, errors.New("CDN service unavailable"))
            },
            expectError: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            tt.setupMock(mockCDN)
            
            result, err := cacheManager.InvalidateMediaCache(context.Background(), tt.mediaURLs)
            
            if tt.expectError {
                assert.Error(t, err)
                return
            }
            
            assert.NoError(t, err)
            assert.NotEmpty(t, result.InvalidationID)
        })
    }
}
```

### 15.3. Test Data Management (テストデータ管理)

**Test Asset Generation:**
```go
// Test data generation utilities
func generateTestImage(width, height int, format string) []byte {
    img := image.NewRGBA(image.Rect(0, 0, width, height))
    // Fill with test pattern
    for y := 0; y < height; y++ {
        for x := 0; x < width; x++ {
            img.Set(x, y, color.RGBA{
                R: uint8((x + y) % 256),
                G: uint8((x * y) % 256),
                B: uint8((x - y) % 256),
                A: 255,
            })
        }
    }
    
    var buf bytes.Buffer
    switch format {
    case "jpeg":
        jpeg.Encode(&buf, img, &jpeg.Options{Quality: 90})
    case "png":
        png.Encode(&buf, img)
    }
    return buf.Bytes()
}

func generateLargeTestFile(size int64) []byte {
    data := make([]byte, size)
    rand.Read(data)
    return data
}
```

### 15.4. Test Environment Setup (テスト環境セットアップ)

**Docker Compose for Testing:**
```yaml
version: '3.8'
services:
  redis-test:
    image: redis:7-alpine
    ports:
      - "6380:6379"
    command: redis-server --appendonly yes
    
  minio-test:
    image: minio/minio:latest
    ports:
      - "9001:9000"
      - "9002:9001"
    environment:
      MINIO_ROOT_USER: testuser
      MINIO_ROOT_PASSWORD: testpassword
    command: server /data --console-address ":9001"
    
  postgres-test:
    image: postgres:17-alpine
    environment:
      POSTGRES_DB: avion_media_test
      POSTGRES_USER: test
      POSTGRES_PASSWORD: test
    ports:
      - "5433:5432"
```

### 15.5. Continuous Integration (CI/CD)

**Test Pipeline Configuration:**
```yaml
test:
  stage: test
  services:
    - redis:7-alpine
    - postgres:17-alpine
    - minio/minio:latest
  variables:
    REDIS_URL: "redis://redis:6379/1"
    DATABASE_URL: "postgres://test:test@postgres:5432/avion_media_test"
    S3_ENDPOINT: "http://minio:9000"
  script:
    - go test -v -race -coverprofile=coverage.out ./...
    - go tool cover -html=coverage.out -o coverage.html
    - go test -v -tags=integration ./tests/integration/...
    - go test -v -tags=performance -timeout=10m ./tests/performance/...
  coverage: '/coverage: \d+\.\d+% of statements/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml
    paths:
      - coverage.html
      - coverage.xml
```

### 15.6. Test Metrics and Monitoring (テストメトリクスとモニタリング)

**Key Test Metrics:**
- **Test Coverage:** Minimum 90% overall, 95% for critical paths
- **Test Execution Time:** Unit tests < 30s, Integration tests < 5min
- **Flaky Test Rate:** < 1% of test runs
- **Performance Regression:** < 10% degradation in throughput

**Monitoring Test Health:**
```go
// Test metrics collection
type TestMetrics struct {
    TotalTests      int           `json:"total_tests"`
    PassedTests     int           `json:"passed_tests"`
    FailedTests     int           `json:"failed_tests"`
    ExecutionTime   time.Duration `json:"execution_time"`
    Coverage        float64       `json:"coverage_percentage"`
    FlakyTests      []string      `json:"flaky_tests"`
}

func CollectTestMetrics(results TestResults) TestMetrics {
    return TestMetrics{
        TotalTests:    results.Total,
        PassedTests:   results.Passed,
        FailedTests:   results.Failed,
        ExecutionTime: results.Duration,
        Coverage:      results.CoveragePercentage,
        FlakyTests:    identifyFlakyTests(results),
    }
}
```

この包括的なテスト戦略により、avion-mediaサービスの品質、信頼性、パフォーマンスを確保し、本番環境での安定稼働を実現します。

---
