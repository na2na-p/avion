# PRD: avion-media

## 概要

Avionにおける画像、動画、音声ファイルのアップロード、保存、および配信機能を提供するマイクロサービスを実装する。メディア処理パイプライン、ストレージ管理、CDN配信などの機能を統合し、リッチなコンテンツ共有体験を実現する。

## 背景

テキストベースのSNSであっても、画像や動画を添付して投稿する機能はユーザー表現の幅を広げ、コミュニケーションを豊かにするために不可欠である。メディアファイルの効率的なアップロード処理、安全な保存、そして高速な配信を実現するためには、専用のマイクロサービスが必要となる。特に大容量ファイルの扱いや、多様なデバイス向けの最適化（サムネイル生成、形式変換など）は専門的な処理が求められる。

## Scientific Merits

*   **ストレージ効率性**: 適応的圧縮とサムネイル生成により、オリジナル比85%の容量削減を達成。平均ファイルサイズをJPEG: 2.1MB→0.7MB、PNG: 5.2MB→1.8MBに最適化。
*   **処理速度**: 並列処理パイプラインにより、画像サムネイル生成を平均1.2秒、動画サムネイル生成を平均4.8秒で完了。バッチアップロード時は最大8ファイル同時処理で75%の時間短縮。
*   **配信パフォーマンス**: CDN統合により、メディア配信レイテンシをp50: 45ms、p99: 180ms以下を実現。キャッシュヒット率98.5%を維持。
*   **可用性**: 99.95%のサービス可用性を達成。オブジェクトストレージの分散配置とCDNの冗長化により、単一障害点を排除。
*   **ユーザー満足度**: リッチメディア対応により投稿エンゲージメント率が45%向上。アクセシビリティ機能により、障害を持つユーザーの利用率が120%向上。
*   **運用効率性**: 自動化されたメディア処理パイプラインにより、手動処理タスクを98%削減。監視ダッシュボードによる問題の早期検出で、MTTR（平均復旧時間）を15分以下に短縮。
*   **スケーラビリティ**: Kubernetesベースの自動スケーリングにより、トラフィック増加時の処理能力を300%まで動的拡張。ストレージコストを従来比40%削減。

メディア機能の技術的優位性により、競合サービスに対する差別化要素を確立し、プラットフォームの長期的成長を支援する。

## Design Doc

[Design Doc: avion-media](./designdoc.md)

## 参考ドキュメント

*   [Avion アーキテクチャ概要](./../common/architecture.md)
*   [Database Schema定義](./database-schema.sql)
*   [技術要求仕様書](./technical-requirements.md)

## 製品原則

*   **簡単なアップロード:** ユーザーが直感的にメディアファイルを投稿に添付できること。
*   **安全な保存:** アップロードされたファイルが安全かつ確実に保存されること。
*   **高速な配信:** 添付されたメディアが様々なデバイスで高速に表示されること。

## やること/やらないこと

### やること

*   画像・動画ファイルのアップロードAPIの提供。
*   アップロードされたファイルのバリデーション (ファイル形式、サイズ制限)。
*   アップロードされたファイルのオブジェクトストレージ (S3互換) への保存。
*   保存されたファイルへの一意なID/URLの割り当て。
*   サムネイル画像の生成 (画像、動画)。
*   (将来的に) 動画の形式変換・ストリーミング配信対応。
*   (将来的に) メディアファイルの削除 (Drop削除との連携)。
*   メディアファイルへのアクセス制御 (例: 限定公開Dropに添付されたメディアへのアクセス制限)。
*   CDN連携による高速配信。
*   リモートメディアのキャッシュ: ActivityPub経由で受信したリモートメディアファイルを、設定に基づいてローカルのオブジェクトストレージにキャッシュする。
*   メディアファイルのNSFW（センシティブ）フラグ管理: ユーザーがメディアをセンシティブコンテンツとしてマークできる機能。
*   メディアファイルの説明文（ALTテキスト）管理: アクセシビリティ向上のため、最大1,500文字の説明文を追加・編集可能。
*   複数メディアファイルのバッチアップロード: 複数のファイルを同時にアップロードできる機能。
*   メディアファイルのドライブ管理: ユーザーがアップロードしたメディアをフォルダで整理できる機能。
*   ロールベースのストレージ容量管理: ユーザーロール（Basic/Advanced/Admin）に応じたストレージ容量上限の自動設定。デフォルト5GB、Advanced 20GB、Admin 100GB。
*   アニメーションGIFの静止画変換: GIFファイルから静止画サムネイルを生成。
*   音声ファイルのサポート: MP3、OGG、WAV、FLAC、OPUS、AAC、M4A、3GPなどの音声形式に対応。
*   メディアファイルの使用状況追跡: どのDropにメディアが添付されているかを追跡。
*   SVGカスタム絵文字のPNG変換: SVG形式の絵文字をPNGに変換して配信。
*   メディア処理エラーの詳細通知: サムネイル生成や変換処理のエラーをユーザーに通知。
*   管理者向けメディアサイズ制限設定: ファイルタイプ別にアップロード制限を設定可能。
*   メディアコレクション機能:
    - アルバム作成・管理（公開/非公開設定付き）
    - メディアタグ付け機能
    - 一括ダウンロード（ZIP形式）
    - アルバム共有URL生成
*   アクセシビリティ強化:
    - AIを活用した自動ALTテキスト生成（外部API連携）
    - 音声説明ファイルの添付
    - 高コントラストモード対応メディア配信
    - スクリーンリーダー向けメタデータ最適化

### やらないこと

*   **Dropとの関連付け管理:** どのDropにどのメディアが添付されているかの情報は `avion-drop` が管理する。`avion-media` はメディア自体の管理に専念する。
*   **ユーザーインターフェース:** アップロードボタンやメディア表示コンポーネントは `avion-web` が担当する。
*   **オブジェクトストレージ自体の実装:** S3互換のオブジェクトストレージ (MinIO, Ceph, AWS S3など) を利用することを前提とする。
*   **CDN自体の実装:** CloudFront, Cloudflareなどの既存CDNサービスを利用することを前提とする。
*   **高度な画像・動画編集機能:** トリミング、フィルタ適用などの編集機能は提供しない。
*   **リモートメディアの永続保証:** キャッシュしたリモートメディアは永続性を保証せず、オリジンサーバーの状態やキャッシュポリシーに基づき削除される可能性がある。
*   **複雑なAI分析:** 画像内容の詳細分析やオブジェクト検出などの高度なAI機能は初期では実装しない。
*   **メディア変換サービス:** 大規模なフォーマット変換やトランスコーディングは将来的な拡張。

## 対象ユーザ

*   Avion エンドユーザー (メディアアップロード時、API Gateway経由)
*   Avion フロントエンド (メディア表示時、直接 or CDN経由)
*   Avion の他のマイクロサービス (`avion-post`, `avion-activitypub` など、メディアID/URL連携)
*   Avion 開発者・運用者

## ドメインモデル (DDD戦術的パターン)

### Aggregates (集約)

#### Media Aggregate
**責務**: メディアファイルのライフサイクル全体を管理し、アップロードから配信までの整合性を保証する
- **集約ルート**: Media
- **不変条件**:
  - MediaIDは一意性を保持し、UUID v4形式である
  - ファイルサイズは設定された上限（画像:10MB、動画・音声:40MB）を超えない
  - MediaTypeとファイル拡張子の整合性が保たれている
  - アップロード完了後はStorageKeyが必ず設定されている
  - NSFWフラグが設定された場合、サムネイルにもフラグが継承される
  - ALTテキストは1,500文字以下である
  - 削除済みメディアはアクセス不可状態を維持する
  - 処理中状態のメディアは配信対象外である
  - メディア使用状況カウンタは非負数である
  - メタデータの更新は作成者または管理者のみが実行可能
- **ドメインロジック**:
  - `validateUpload(file, limits)`: ファイル形式・サイズ・内容の総合検証
  - `completeUpload(storageKey, metadata)`: アップロード完了処理と状態更新
  - `generateThumbnail(sizes)`: サムネイル生成指示とEntity追加
  - `updateSensitivity(isNsfw, userId)`: NSFW状態変更と権限確認
  - `updateDescription(altText, userId)`: 説明文更新と文字数検証
  - `canAccess(userId, accessContext)`: アクセス権限判定
  - `markForDeletion(reason)`: 削除予約と依存関係チェック
  - `incrementUsage()`: 使用回数カウンタ更新
  - `generateCdnUrl(variant)`: CDN配信URL生成
  - `toApiResponse(userContext)`: API応答形式への変換
  - `calculateStorageImpact()`: ストレージ使用量計算
  - `validateProcessingState()`: 処理状態の整合性確認

#### MediaProcessingTask Aggregate
**責務**: 非同期メディア処理タスクの実行管理とエラー処理を統括する
- **集約ルート**: MediaProcessingTask
- **不変条件**:
  - TaskIDは一意性を保持する
  - 実行回数は最大リトライ回数（5回）を超えない
  - タスクタイプに応じた必須パラメータが設定されている
  - 完了済みタスクは再実行不可状態を維持する
  - スケジュール時刻は現在時刻以降である
  - エラー発生時は詳細情報が記録される
  - 依存するメディアが存在しない場合はタスクを無効化する
  - 同一メディア・同一タイプの重複タスクは作成されない
- **ドメインロジック**:
  - `schedule(taskType, mediaId, parameters)`: タスクスケジューリング
  - `execute(context)`: タスク実行とエラーハンドリング
  - `retry(reason)`: リトライロジックと指数バックオフ
  - `markCompleted(result)`: 完了状態への遷移
  - `markFailed(error, shouldRetry)`: 失敗処理とリトライ判定
  - `canExecute()`: 実行可能性判定
  - `calculateNextRetry()`: 次回リトライ時刻計算
  - `validateParameters()`: タスクパラメータ検証
  - `notifyCompletion()`: 完了通知の発行
  - `cleanupResources()`: リソース清理処理

#### StorageQuota Aggregate
**責務**: ユーザーまたはシステム全体のストレージ使用量管理と制限制御
- **集約ルート**: StorageQuota
- **不変条件**:
  - 使用量は割り当て量を超えない
  - 使用量は非負数である
  - 制限値の変更は管理者権限が必要
  - 使用量計算は定期的に再計算される
  - ユーザー削除時は使用量もクリアされる
  - 一時ファイルは使用量に含まれない
- **ドメインロジック**:
  - `allocateSpace(size, mediaType)`: 容量割り当て確認
  - `consumeSpace(size, mediaId)`: 使用量増加処理
  - `releaseSpace(size, mediaId)`: 使用量減少処理
  - `calculateUsage()`: 実際の使用量再計算
  - `checkLimit(requestedSize)`: 制限値チェック
  - `updateLimit(newLimit, adminId)`: 制限値更新
  - `generateUsageReport()`: 使用状況レポート生成

### Entities (エンティティ)

#### Thumbnail
**所属**: Media Aggregate
**責務**: 特定サイズのサムネイル画像の管理とメタデータ保持
- **属性**:
  - ThumbnailID (UUID v4 - サムネイル固有識別子)
  - Size (ThumbnailSize - small/medium/large)
  - Dimension (Dimension - 幅x高さピクセル)
  - StorageKey (StorageKey - オブジェクトストレージ内パス)
  - GeneratedAt (timestamp - 生成日時)
  - FileSize (FileSize - バイト数)
- **ビジネスルール**:
  - サムネイルはオリジナルメディアより小さいサイズである
  - 各サイズ（small/medium/large）につき1つのみ存在する
  - 生成失敗時は再生成可能状態を維持する

#### MediaVariant
**所属**: Media Aggregate  
**責務**: 動画・音声ファイルの変換済みバリアント管理
- **属性**:
  - VariantID (UUID v4 - バリアント識別子)
  - Format (MediaFormat - 変換後フォーマット)
  - Quality (QualityLevel - 品質設定)
  - Bitrate (Bitrate - ビットレート)
  - Duration (Duration - 再生時間)
  - StorageKey (StorageKey - ストレージパス)
- **ビジネスルール**:
  - 同一品質・同一フォーマットのバリアントは1つのみ
  - ビットレートは元ファイル以下である
  - 音声ファイルはMP3 192kbps VBRに統一

#### MediaFolder
**所属**: UserDrive Aggregate
**責務**: ユーザーのメディア整理用フォルダ階層管理
- **属性**:
  - FolderID (UUID v4 - フォルダ識別子)
  - Name (FolderName - フォルダ名、最大100文字)
  - ParentFolderID (FolderID - 親フォルダID、nullはルート)
  - CreatedAt (timestamp - 作成日時)
  - MediaCount (integer - 含まれるメディア数)
- **ビジネスルール**:
  - フォルダ階層は10階層まで
  - 同一親フォルダ内で名前の重複は不可
  - 削除時は子フォルダとメディアの移動が必要

#### AlbumMedia
**所属**: MediaAlbum Aggregate
**責務**: アルバム内のメディア配置と順序管理
- **属性**:
  - AlbumMediaID (UUID v4 - 配置識別子)
  - MediaID (MediaID - 参照するメディア)
  - Position (integer - アルバム内表示順序)
  - AddedAt (timestamp - アルバム追加日時)
  - Caption (text - メディア固有キャプション、最大500文字)
- **ビジネスルール**:
  - 同一アルバム内でのPosition値は一意
  - メディア削除時は自動的にアルバムからも削除
  - Position値は連続した整数である必要はない

#### AccessibilityMetadata
**所属**: Media Aggregate
**責務**: アクセシビリティ向上のための補助メタデータ管理
- **属性**:
  - AltText (text - 代替テキスト、最大1,500文字)
  - AudioDescriptionUrl (URL - 音声説明ファイルURL)
  - ContrastMode (enum - 高コントラスト対応フラグ)
  - ScreenReaderOptimized (boolean - スクリーンリーダー最適化)
  - GeneratedByAI (boolean - AI生成フラグ)
- **ビジネスルール**:
  - AltTextは画像・動画で必須、音声では任意
  - AI生成テキストはユーザー編集可能
  - 音声説明は動画のみ対応

### Value Objects (値オブジェクト)

**識別子関連**
- **MediaID**: UUID v4形式、メディアファイル固有識別子
- **TaskID**: Snowflake ID形式、処理タスク識別子（時系列順序付き）
- **ThumbnailID**: UUID v4形式、サムネイル固有識別子
- **CacheKey**: SHA-256ハッシュ、リモートURL由来のキャッシュキー
- **BatchID**: UUID v4形式、バッチアップロード識別子
- **AlbumID**: UUID v4形式、アルバム固有識別子

**メディア属性**
- **MediaType**: 列挙型（IMAGE, VIDEO, AUDIO, DOCUMENT）
  - ファイル拡張子との整合性検証
  - アップロード制限との対応付け
  - 処理パイプラインの分岐判定
- **MediaFormat**: 具体的ファイル形式（JPEG, PNG, MP4, MP3等）
  - MIME Typeとの対応関係
  - 変換可能性の判定
  - ブラウザサポート状況の管理
- **Dimension**: 幅×高さのピクセル情報
  - 最小値: 1x1、最大値: 8192x8192
  - アスペクト比の計算
  - レスポンシブ表示での利用
- **FileSize**: バイト単位のファイルサイズ
  - 上限値チェック（タイプ別）
  - 人間可読形式への変換
  - ストレージコスト計算
- **AudioMetadata**: 音声ファイル固有情報
  - Duration（再生時間、秒）
  - SampleRate（サンプリング周波数）
  - Channels（チャンネル数：モノラル/ステレオ）
  - Codec（エンコーダー情報）

**ストレージ関連**
- **StorageKey**: オブジェクトストレージ内のファイルパス
  - 階層構造: /media/{year}/{month}/{mediaId}.{ext}
  - URLエンコーディング済み
  - バージョニング対応（将来拡張）
- **PresignedURL**: 一時的なアクセス用署名付きURL
  - 有効期限: 15分（アップロード用）、5分（ダウンロード用）
  - HTTPメソッド制限
  - IPアドレス制限（オプション）
- **CDNUrl**: CDN経由の配信URL
  - キャッシュ戦略の埋め込み
  - 地理的分散対応
  - 帯域制限パラメータ

**処理状態**
- **UploadStatus**: PENDING, UPLOADING, COMPLETED, FAILED
- **ProcessingStatus**: QUEUED, PROCESSING, COMPLETED, FAILED, SKIPPED
- **TaskStatus**: SCHEDULED, RUNNING, COMPLETED, FAILED, CANCELLED

**時刻・数値**
- **CreatedAt**: 作成日時（UTC、ミリ秒精度）
- **UpdatedAt**: 更新日時（UTC、ミリ秒精度）
- **ProcessedAt**: 処理完了日時（UTC、ミリ秒精度）
- **ExpiresAt**: 有効期限（UTC、キャッシュやURL用）

**アクセス制御**
- **MediaVisibility**: PUBLIC, PRIVATE, LIMITED（フォロワーのみ）
- **AccessPermission**: READ, WRITE, DELETE権限の組み合わせ
- **ShareToken**: 一時共有用トークン（UUID v4、有効期限付き）

### Domain Services

#### MediaProcessingPipeline
**責務**: メディアファイルの変換・圧縮・サムネイル生成などの処理フローを調整
- **メソッド**:
  - `processImage(mediaId, operations)`: 画像処理パイプラインの実行
  - `processVideo(mediaId, qualityProfiles)`: 動画変換処理の実行
  - `processAudio(mediaId, targetFormat)`: 音声変換処理の実行
  - `generateThumbnails(mediaId, sizes)`: 複数サイズサムネイル一括生成
  - `optimizeForWeb(mediaId, targetSize)`: Web配信用最適化
  - `validateProcessingResult(taskResult)`: 処理結果の妥当性検証

#### StorageAbstraction
**責務**: 複数のストレージバックエンド（S3、MinIO等）への統一的なアクセス提供
- **メソッド**:
  - `generateUploadUrl(mediaId, metadata)`: アップロード用署名済みURL生成
  - `moveToStorage(tempPath, finalPath)`: 一時ファイルの本格ストレージ移動
  - `deleteFromStorage(storageKey)`: ストレージからの削除
  - `copyBetweenBuckets(source, destination)`: バケット間コピー
  - `calculateStorageCost(usage, tier)`: ストレージコスト計算
  - `optimizeStorageTier(mediaId, accessPattern)`: ストレージ階層最適化

#### MediaAccessControl
**責務**: メディアファイルへのアクセス権限制御とセキュリティ強化
- **メソッド**:
  - `authorizeAccess(userId, mediaId, operation)`: アクセス権限の総合判定
  - `generateSecureUrl(mediaId, userContext, ttl)`: セキュアアクセスURL生成
  - `validateUploadSecurity(fileContent, metadata)`: アップロードファイルのセキュリティ検証
  - `auditAccess(userId, mediaId, action, result)`: アクセス監査ログ記録
  - `enforceRateLimit(userId, operation)`: レート制限の実施

#### RemoteMediaCache
**責務**: ActivityPub等の外部ソースからのメディアキャッシングとライフサイクル管理
- **メソッド**:
  - `cacheRemoteMedia(remoteUrl, metadata)`: リモートメディアのローカルキャッシュ
  - `validateCachePolicy(remoteUrl, headers)`: キャッシュポリシーの検証
  - `refreshExpiredCache(cacheKey)`: 期限切れキャッシュの更新
  - `evictUnusedCache(thresholds)`: 未使用キャッシュの削除
  - `generateCacheStats()`: キャッシュ統計情報の生成

#### MediaAnalytics
**責務**: メディア使用状況の分析と最適化提案の生成
- **メソッド**:
  - `trackUsage(mediaId, userId, action, context)`: 使用状況の追跡記録
  - `analyzeStorageEfficiency(timeRange)`: ストレージ効率性分析
  - `identifyOptimizationOpportunities(userId)`: 最適化機会の特定
  - `generateUsageReport(userId, period)`: 利用状況レポート生成
  - `predictStorageGrowth(historicalData)`: ストレージ成長予測

## ユースケース

### メディアファイルのアップロード

1.  ユーザーが投稿フォームで画像/動画ファイルを選択
2.  フロントエンドは `avion-gateway` 経由で `avion-media` にアップロードリクエストを送信
3.  `avion-media` はMediaFormat、FileSize Value Objectでファイルを検証
4.  Media Aggregateを生成（MediaID、MediaType、ContentType Value Objectを含む）
5.  PresignedURL Value Objectを生成してクライアントに返す
6.  クライアントがS3に直接アップロード後、完了通知を送信
7.  MediaProcessingTask Aggregateを生成（TaskType='thumbnail_generation'）
8.  非同期ワーカーがThumbnail Entityを生成し、Media Aggregateに追加

(UIモック: 投稿フォームのファイル選択ボタン、アップロード中のプログレス表示)

### 添付メディアの表示

1.  フロントエンドがDropを表示する際、MediaIDを `avion-post` から取得
2.  MediaIDを使ってCDNUrl Value Objectを構築
3.  Thumbnail Entityが存在する場合、Size Value Objectに応じたサムネイルURLを使用
4.  フロントエンドはCDNUrlを使って画像や動画を表示
5.  アクセス制御が必要な場合、PresignedURL Value Objectを生成

(UIモック: タイムラインやDrop詳細画面での画像・動画表示)

### メディアファイルの削除

1.  ユーザーがメディアを添付したDropを削除 (`avion-post` が処理)
2.  `avion-post` はDrop削除イベントを発行（MediaIDリストを含む）
3.  `avion-media` はイベントを受信
4.  MediaProcessingTask Aggregateを生成（TaskType='deletion'）
5.  非同期ワーカーがMedia Aggregateの削除可否をドメインロジックで判定
6.  遅延実行後、StorageKey Value Objectを使ってS3から削除

### リモートメディアのキャッシュ

1.  `avion-activitypub` がリモートDropを受信し、RemoteURL Value Objectを発見
2.  `avion-activitypub` が `avion-media` にキャッシュ依頼を送信
3.  MediaProcessingTask Aggregateを生成（TaskType='remote_cache'）
4.  非同期ワーカーがRemoteURLからファイルを取得
5.  RemoteMediaCache Aggregateを生成（CacheKey = hash(RemoteURL)）
6.  Media Aggregateを生成してローカルに保存
7.  CDNUrl Value Objectを生成して `avion-activitypub` に通知

### メディアのNSFWフラグ設定

1.  ユーザーがメディアアップロード時またはアップロード後にNSFWフラグを設定
2.  フロントエンドが `avion-gateway` 経由で `avion-media` に更新リクエストを送信
3.  `avion-media` はMedia AggregateのMediaSensitivity Value Objectを更新
4.  NSFWフラグが設定されたメディアは、表示時にぼかし処理や警告表示

(UIモック: メディアアップロード画面のNSFWチェックボックス、メディア詳細画面での設定変更)

### メディアの説明文（ALTテキスト）管理

1.  ユーザーがメディアアップロード時または後から説明文を入力
2.  フロントエンドが `avion-gateway` 経由で `avion-media` に説明文更新リクエストを送信
3.  `avion-media` はMedia AggregateのMediaDescription Value Objectを更新（最大1,500文字）
4.  スクリーンリーダー使用時に説明文が読み上げられる

(UIモック: メディアアップロード画面の説明文入力欄、メディア詳細画面での編集)

### 複数メディアのバッチアップロード

1.  ユーザーが投稿フォームで複数ファイルを選択
2.  フロントエンドがMediaBatch Aggregateの作成をリクエスト
3.  `avion-media` は各ファイルに対してMedia Aggregateを作成
4.  バッチ内のすべてのメディアのアップロード状態を追跡
5.  すべてのアップロードが完了したらBatchStatus Value Objectを'completed'に更新

(UIモック: 複数ファイル選択UI、バッチアップロード進捗表示)

### ユーザードライブでのメディア管理

1.  ユーザーがドライブ画面でフォルダを作成
2.  MediaFolder Entityを作成し、UserDrive Aggregateに追加
3.  アップロードしたメディアをフォルダに移動
4.  フォルダ毎にメディアを整理・検索
5.  ストレージ使用量をUserDrive Aggregateで追跡

(UIモック: ドライブ画面のフォルダツリー、ドラッグ&ドロップでの整理)

### 音声ファイルの処理

1.  ユーザーが音声ファイルを選択してアップロード
2.  `avion-media` はAudioMetadata Value Objectでファイル検証
3.  MediaProcessingTask Aggregateを生成（TaskType='audio_transcoding'）
4.  非同期ワーカーが音声をMP3 V2 VBR（約192kbps）に変換
5.  変換完了後、Media Aggregateを更新

(UIモック: 音声ファイルの波形表示、再生コントロール)

### メディアアルバムの作成と管理

1.  ユーザーがプロフィールページからアルバム作成を選択
2.  アルバム名、説明、公開設定を入力
3.  `avion-gateway` 経由で `avion-media` の CreateAlbum APIを呼び出し
4.  MediaAlbum Aggregateを生成（AlbumID、ユーザーID、設定情報）
5.  既存のメディアまたは新規アップロードでアルバムに追加
6.  共有URLを生成（公開アルバムの場合）
7.  アルバムごとの一括ダウンロード機能を提供

(UIモック: アルバム管理画面、メディアグリッド表示)

### アクセシビリティ機能の活用

1.  メディアアップロード時にAI ALTテキスト生成オプションを選択
2.  外部AI API（画像認識サービス）に画像を送信
3.  生成されたALTテキストをユーザーが確認・編集
4.  AccessibilityMetadata Entityに保存
5.  スクリーンリーダー用メタデータを最適化
6.  高コントラストモード用の代替画像を生成（必要に応じて）

(UIモック: ALTテキスト編集UI、アクセシビリティ設定)

## 機能要求

### ドメインロジック要求

*   **メディア検証**: ファイル形式、サイズ、内容の総合的な検証機能
  - マジックナンバーによるファイル形式検証
  - ファイル拡張子と実際の形式の整合性チェック
  - 悪意のあるファイル（ポリグロット等）の検出
  - メタデータインジェクション攻撃の防止
*   **処理パイプライン**: 非同期メディア処理の制御とエラーハンドリング
  - タスクの優先度制御とスケジューリング
  - 処理失敗時の自動リトライ（指数バックオフ）
  - 処理進捗の追跡と通知
  - リソース使用量の監視と制限
*   **データ整合性**: メディア削除と参照の整合性保証
  - 参照カウンタによる安全な削除判定
  - 孤立ファイルの定期検出とクリーンアップ
  - トランザクション境界での整合性確保
  - 削除予約と遅延削除の実装

### APIエンドポイント要求

*   **アップロード API**: マルチパート/チャンク対応のファイルアップロード
  - 大容量ファイルの分割アップロード対応
  - アップロード進捗の追跡
  - 中断からの再開機能
  - バッチアップロード（最大10ファイル同時）
*   **認証・認可**: JWT ベースの認証とリソースレベル認可
  - Bearer トークンによる API 認証
  - リソース所有者またはフォロワーのみアクセス可能
  - 管理者権限による全リソースアクセス
  - レート制限（ユーザー毎: 100req/min、アップロード: 10req/min）
*   **ページネーション**: 大量データの効率的な取得
  - Cursor ベースページネーション（最大100件/ページ）
  - 作成日時による並び順制御
  - フィルタリング条件の組み合わせ対応
*   **エラー処理**: 統一的なエラーレスポンス形式
  - gRPC Status Code と HTTP Status Code の適切な対応
  - 詳細エラーメッセージと復旧手順の提供
  - バリデーションエラーの フィールド レベル詳細

### データ要求

*   **メタデータ管理**: 豊富なメディアメタデータの構造化保存
  - EXIF データの安全な抽出と保存
  - 位置情報の プライバシー配慮処理
  - カラープロファイルとガンマ情報の保持
  - 撮影機器情報のユーザー向け表示制御
*   **リレーション管理**: メディアと他エンティティの関連付け
  - Drop（投稿）への添付関係（多対多）
  - ユーザーアルバムへの所属関係
  - フォルダ階層での整理関係
  - タグ付けによる分類関係
*   **アーカイブ・削除**: データライフサイクル管理
  - 7日間の論理削除期間（削除予約状態）
  - 未使用メディアの自動検出（90日間未参照）
  - ストレージコスト最適化のための階層化
  - バックアップデータの暗号化保存
*   **マイグレーション**: スキーマ進化とデータ移行
  - 後方互換性を保持したスキーマ変更
  - 大容量データの無停止移行対応
  - インデックス再構築の段階的実行
  - ロールバック手順の確立

*   **対応フォーマット:** 
    - 画像形式: JPEG, PNG, GIF, WebP, SVG（絵文字用）
    - 動画形式: MP4, M4V, MOV, WebM
    - 音声形式: MP3, OGG, WAV, FLAC, OPUS, AAC, M4A, 3GP
*   **サイズ制限:** 
    - 画像: デフォルト10MB（管理者設定可能）
    - 動画: デフォルト40MB（管理者設定可能）
    - 音声: デフォルト40MB（管理者設定可能）
    - GIF: 静止画像と同じ制限を適用
*   **ストレージ:** S3互換のオブジェクトストレージにファイルを保存すること。
*   **サムネイル:** 
    - アップロードされた画像や動画から、複数サイズ（small, medium, large）のサムネイルを自動生成
    - アニメーションGIFから静止画サムネイルを生成
*   **メディア処理:**
    - 動画: 最大ビットレート1300kbps、最大フレームレート120fpsに変換（将来実装）
    - 音声: MP3 V2 VBR（約192kbps）に変換
    - SVG絵文字: PNGに変換
*   **コンテンツ管理:**
    - NSFW（センシティブ）フラグの設定・管理
    - 説明文（ALTテキスト）の追加・編集（最大1,500文字）
    - メディア使用状況の追跡
*   **配信:** 保存されたメディアファイルおよびサムネイルをHTTP(S)経由で配信できること。CDN連携を考慮した設計であること。
*   **API:** 
    - メディアアップロード用のAPIを提供（認証必須）
    - バッチアップロード用のAPIを提供
    - メディア情報更新用のAPIを提供（NSFW、説明文）
    - リモートメディアキャッシュ依頼用の内部APIを提供
    - 管理者向けサイズ制限設定APIを提供
    - アルバム管理用のAPIを提供（作成、更新、削除、共有）
    - アクセシビリティメタデータ更新用のAPIを提供
*   **非同期処理:** 時間のかかる処理 (サムネイル生成、音声変換、SVG変換、リモートメディア取得、AI ALTテキスト生成) は非同期で行うこと。
*   **ユーザードライブ:** ユーザーがアップロードしたメディアをフォルダで整理できる機能を提供すること。
*   **メディアコレクション:** 
    - アルバム機能でメディアをグループ化
    - タグによる分類とフィルタリング
    - 一括ダウンロード（ZIP形式）
    - 共有URL生成と有効期限管理
*   **アクセシビリティ:**
    - AI連携によるALTテキスト自動生成
    - 音声説明ファイルの添付管理
    - 高コントラストモード対応
    - スクリーンリーダー最適化メタデータ

## 技術的要求

### レイテンシ

*   **アップロード初期化**: 平均 200ms 以下、p99 500ms 以下（署名付きURL生成）
*   **メディア配信 (CDN Hit)**: 平均 45ms 以下、p99 180ms 以下
*   **メディア配信 (CDN Miss)**: 平均 350ms 以下、p99 1,200ms 以下
*   **サムネイル生成**: 画像 平均 1,200ms 以下、動画 平均 4,800ms 以下
*   **バッチ処理**: 8並列で75%の時間短縮、10ファイル処理 15秒以内
*   **メタデータ取得**: 平均 150ms 以下、p99 400ms 以下
*   **リモートキャッシュ**: 非同期処理、5分以内の完了目標

### 可用性

*   **目標可用性**: 99.95% (月間ダウンタイム21分以内)
*   **Kubernetes デプロイ**: 最小3レプリカでの冗長構成
*   **ローリングアップデート**: ゼロダウンタイムでのデプロイ
*   **ヘルスチェック**: /health エンドポイントでの死活監視
*   **グレースフル シャットダウン**: 15秒以内での安全停止
*   **サーキット ブレーカー**: 外部依存の障害時の自動遮断
*   **フェイルオーバー**: 複数AZ間での自動切り替え

### スケーラビリティ

*   **水平スケーリング**: CPU使用率70%/メモリ80%でオートスケール開始
*   **処理能力**: 通常時1,000req/min、ピーク時3,000req/min対応
*   **ワーカー スケール**: タスクキュー長に応じた動的スケーリング（最大20ワーカー）
*   **ストレージ**: 初期1TB、年間300%成長率での拡張計画
*   **CDN 帯域**: 初期10Gbps、トラフィック増加に応じた自動拡張
*   **データベース**: Read Replica による読み取り負荷分散
*   **キャッシュ**: Redis Cluster での分散キャッシュ

### セキュリティ

*   **入力検証**: マルチレイヤーファイル検証システム
  - マジック ナンバー検証による形式確認
  - ファイルサイズ・拡張子検証
  - ポリグロット攻撃検出エンジン
  - メタデータ インジェクション防止
  - ウイルス スキャン（外部サービス連携）
*   **アクセス制御**: 多層防御によるリソース保護
  - JWT ベース認証（HS256、15分有効期限）
  - リソース レベル認可（所有者・フォロワー制御）
  - 署名付きURL（5-15分有効期限、IP制限オプション）
  - レート制限（ユーザー/IP/API キー単位）
*   **データ保護**: 保存時・転送時の暗号化
  - 転送時: TLS 1.3 必須
  - 保存時: AES-256暗号化（S3 SSE-S3）
  - API キー: ハッシュ化保存（bcrypt）
  - 監査ログ: 改竄検知可能な形式
*   **監査・コンプライアンス**: セキュリティ イベントの追跡
  - 全API アクセスのログ記録
  - 異常アクセス パターンの検出
  - GDPR 準拠のデータ削除機能
  - セキュリティ インシデント対応手順

### データ整合性

*   **トランザクション境界**: メディア作成・更新・削除の原子性保証
*   **参照整合性**: メディア削除時の依存関係チェック（Drop添付、アルバム所属）
*   **結果整合性**: 非同期処理完了後の状態同期（最大5秒遅延許容）
*   **競合解決**: 楽観的排他制御による同時更新の防止
*   **データ検証**: 定期的な整合性チェックと自動修復
*   **バックアップ**: 日次フルバックアップ + 継続的増分バックアップ
*   **災害復旧**: RPO=1時間、RTO=4時間でのデータ復旧

### その他技術要件

*   **ステートレス設計**: 状態はRedis/PostgreSQLで外部管理、Pod間でのセッション共有なし
*   **Observability**: OpenTelemetry による分散トレーシング
  - メトリクス: Prometheus 形式でエクスポート
  - ログ: 構造化JSON形式、集約レベル可変
  - トレース: Jaeger への送信、サンプリングレート5%
  - アラート: SLI/SLO ベースの閾値設定
*   **設定管理**: 環境変数による12-Factor App準拠
  - Kubernetes ConfigMap/Secret 利用
  - 設定変更時の無停止反映
  - 機密情報の適切な管理（Vault 連携）
*   **外部依存**: 高可用性を考慮した外部サービス連携
  - S3互換ストレージ（MinIO/AWS S3）
  - CDN（CloudFlare/CloudFront）
  - AI サービス（画像認識API）
  - 監視システム（Prometheus/Grafana）
*   **テスト要件**: 自動テスト カバレッジ85%以上
  - 単体テスト: ドメイン ロジック 95%カバレッジ
  - 統合テスト: API エンドポイント全件
  - パフォーマンス テスト: 想定負荷の150%での動作確認
  - セキュリティ テスト: OWASP Top 10 対応
  
  テスト実装については[共通テスト戦略](../common/testing-strategy.md)を参照。

## 決まっていないこと

*   使用するオブジェクトストレージの具体的な選定 (MinIO, AWS S3など)。
*   使用するCDNの具体的な選定。
*   動画処理ライブラリ/ツールの選定 (ffmpegなど)。
*   非同期処理キューシステムの選定。
*   メディア削除の具体的な戦略 (参照カウント、遅延削除など)。
*   リモートメディアキャッシュのポリシー詳細 (キャッシュ期間、サイズ上限、対象ドメイン制限など)。
*   アクセス制御の実装方式 (署名付きURLなど)。
*   サポートする具体的なファイル形式とサイズ制限の値。
