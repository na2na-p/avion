# Design Doc: avion-media

**Author:** Cline
**Last Updated:** 2025/03/30

## 1. Summary (これは何？)

- **一言で:** Avionにおける画像、動画などのメディアファイルのアップロード、保存、配信、およびリモートメディアのキャッシュを行うマイクロサービスを実装します。
- **目的:** メディアファイルの効率的な処理と配信を実現し、S3互換オブジェクトストレージとCDNを活用します。

## 2. Background & Links (背景と関連リンク)

- リッチなコンテンツ投稿機能を提供するため。
- メディア処理という専門的な機能を分離し、スケーラビリティを確保するため。
- ActivityPubで受信したリモートメディアの表示パフォーマンス向上のため、キャッシュ機能を提供。
- [PRD: avion-media](./prd.md)
- [Avion アーキテクチャ概要](../architecture.md)

## 3. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

- 画像・動画ファイルのアップロード用Presigned URL払い出しAPI (gRPC) の実装。
- アップロードファイルのバリデーション (形式、サイズ)。
- S3互換オブジェクトストレージへのファイル保存 (クライアントがPresigned URLを使用)。
- アップロード完了通知を受け、サムネイル生成等の後処理を非同期実行 (Redis Stream + Consumer Group)。
- 一意なメディアID/URLの割り当て。
- サムネイル生成 (画像、動画)。
- メディアファイルおよびサムネイルの配信 (CDN経由を推奨)。
- リモートメディアキャッシュ機能の実装 (内部gRPC API経由、非同期処理)。
- メディア削除機能 (イベント駆動、非同期遅延削除)。
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

## 4. Architecture (どうやって作る？)

- **主要コンポーネント:**
    - `avion-media (Go, Kubernetes Deployment)`: 本サービス。gRPCサーバー、非同期処理ワーカ (Redis Stream Consumer)。
    - `avion-gateway (Go)`: gRPCリクエストのルーティング元。
    - `avion-post (Go)`: Drop削除イベント発行元 (Pub/Sub)。
    - `avion-activitypub (Go)`: リモートメディアキャッシュ依頼元 (gRPC)。
    - `S3互換オブジェクトストレージ`: ファイル永続化。
    - `CDN`: ファイル配信。
    - `Redis`: 非同期処理キュー (Stream)。
    - `Observability Stack`: メトリクス、トレース、ログ収集。
- **構成図:** (アーキテクチャ概要図を参照)
    - [Avion アーキテクチャ概要](../architecture.md)
- **ポイント:**
    - アップロードはPresigned URL方式を採用し、クライアントからS3へ直接行う。
    - サムネイル生成などの後処理は非同期ワーカで実行。
    - ファイルの実体はS3互換ストレージに保存。
    - 配信はCDNを介して行うことを基本とする。
    - リモートメディアキャッシュも非同期で行う。
    - メディア削除はイベント駆動の遅延削除。
    - ステートレス設計 (処理キューはRedis Streamで管理)。

## 5. Use Cases / Key Flows (主な使い方・処理の流れ)

- **フロー 1: メディアアップロード (Presigned URL方式)**
    1. Client (via BFF/Gateway) → `RequestMediaUpload` gRPC Call (filename, content_type, size)
    2. MediaService: バリデーション実行。一意なメディアID生成。
    3. MediaService: S3互換ストレージに対し、メディアIDをキーとするPUT用Presigned URLを生成。
    4. MediaService → Gateway: `RequestMediaUploadResponse { media_id: "...", upload_url: "..." }`
    5. Client: 受け取った `upload_url` に直接ファイルをPUTリクエストで送信。
    6. Client: アップロード完了後、`CompleteMediaUpload` gRPC Call (media_id) を送信。
    7. MediaService: リクエストを受け付け、Redis Stream `media_processing_queue` に後処理タスクを追加 (`XADD`) (Payload: { task_id, media_id, type: "thumbnail" })。
    8. MediaService → Gateway: `CompleteMediaUploadResponse {}`
    9. (非同期) MediaService (Worker): `media_processing_queue` からタスク取得 (`XREADGROUP`)。
    10. (非同期) MediaService (Worker): S3から元ファイル取得。サムネイル生成。S3へサムネイル保存。
    11. (非同期) MediaService (Worker): タスク完了をACK (`XACK`)。エラー時はリトライ/DLQ。
- **フロー 2: メディア配信** (変更なし)
    ...
- **フロー 3: リモートメディアキャッシュ**
    1. ActivityPubService → `CacheRemoteMedia` gRPC Call (remote_url)
    2. MediaService: リクエストを受け付け、Redis Stream `media_cache_queue` にキャッシュタスクを追加 (`XADD`) (Payload: { task_id, remote_url })。
    3. MediaService → ActivityPubService: `CacheRemoteMediaResponse { status: "pending", task_id: "..." }`
    4. (非同期) MediaService (Worker): `media_cache_queue` からタスク取得 (`XREADGROUP`)。
    5. (非同期) MediaService (Worker): `remote_url` からファイルを取得。
    6. (非同期) MediaService (Worker): 取得したファイルをS3に保存 (例: `cached_remote/{hash(remote_url)}`)。
    7. (非同期) MediaService (Worker): キャッシュ完了イベントを発行 (検討) or 状態を記録。
    8. (非同期) MediaService (Worker): タスク完了をACK (`XACK`)。エラー時はリトライ/DLQ。
- **フロー 4: メディア削除 (イベント駆動)**
    1. MediaService (Subscriber): Redis Pub/Subチャネル `drop_deleted` からイベント受信 (Payload: { ..., media_ids: [...] })。
    2. MediaService: 該当する `media_ids` について、Redis Stream `media_delete_queue` に削除タスクを追加 (`XADD`) (Payload: { task_id, media_id }, 遅延実行設定検討)。
    3. (非同期・遅延実行) MediaService (Worker): `media_delete_queue` からタスク取得。
    4. (非同期・遅延実行) MediaService (Worker): S3から該当ファイル (オリジナル、サムネイル) を削除。
    5. (非同期・遅延実行) MediaService (Worker): タスク完了をACK。

## 6. Endpoints (API)

- **gRPC Services (`avion.MediaService`):**
    - `RequestMediaUpload(RequestMediaUploadRequest) returns (RequestMediaUploadResponse)` // Presigned URL払い出し
    - `CompleteMediaUpload(CompleteMediaUploadRequest) returns (CompleteMediaUploadResponse)` // 後処理トリガー
    - `CacheRemoteMedia(CacheRemoteMediaRequest) returns (CacheRemoteMediaResponse)` // 内部API
    // `GetMediaInfo` は初期では不要 (パスから情報を類推)
- **HTTP Endpoints:** (直接公開せずCDNオリジンとして設定)
    - `/media/{media_id}`: メディアファイル配信 (CDNオリジン用)
    - `/thumbnail/{size}/{media_id}`: サムネイル配信 (CDNオリジン用)
- Proto定義は別途管理する。

## 7. Data Design (データ)

- **S3互換オブジェクトストレージ:**
    - Bucket: `avion-media`
        - Original files: `original/{year}/{month}/{day}/{media_id}.{ext}`
        - Thumbnails: `thumbnail/{size}/{year}/{month}/{day}/{media_id}.jpg`
        - Cached remote files: `cached_remote/{hash_of_url}`
- **Redis:**
    - 非同期処理キュー (Stream): `media_processing_queue`, `media_cache_queue`, `media_delete_queue` (Consumer Group: `media_workers`)
    - Pub/Sub Channels: `drop_deleted` (購読)

## 8. Operations & Monitoring (運用と監視)

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

## 9. Concerns / Open Questions (懸念事項・相談したいこと)

- **技術的負債リスク:**
    - **非同期処理の複雑性:** 複数の非同期フローと外部サービス連携があり、エラーハンドリング、冪等性確保、状態管理が複雑化しやすい。実装・運用コストが高く、不備はデータ不整合や処理漏れに繋がる。
    - **外部サービス依存:** S3互換ストレージやCDNへの依存度が高く、仕様変更、障害、コスト変動の影響を受ける。ロックインリスク。
    - **ストレージコスト管理:** 未使用ファイル削除ポリシーやリモートキャッシュ戦略が不明確だと、コストが予期せず増大する可能性がある。継続的なモニタリングとポリシー見直しが必要。
- 動画処理 (サムネイル生成) の具体的なライブラリ/ツール選定とリソース要件。
- リモートメディアキャッシュのポリシー詳細 (対象ドメイン、不正利用対策)。
- メディア削除戦略 (遅延削除の具体的な実装、参照カウントの導入是非)。

---
