# Design Doc: avion-post

**Author:** Cline
**Last Updated:** 2025/03/30

## 1. Summary (これは何？)

- **一言で:** Avionにおける投稿（Drop）の作成、取得、削除などのライフサイクル管理を行うマイクロサービスを実装します。
- **目的:** Dropデータの永続化、基本的なアクセス制御（公開範囲に基づく）、および関連操作（削除）を提供します。他のサービス（Timeline, Search, ActivityPubなど）へのイベント通知も行います。

## 2. Background & Links (背景と関連リンク)

- SNSの根幹機能である投稿管理機能を提供するため。
- マイクロサービスアーキテクチャにおいて、投稿関連の機能を独立させることで、変更容易性とスケーラビリティを確保する。
- [PRD: avion-post](./prd.md)
- [Avion アーキテクチャ概要](../architecture.md)

## 3. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

- Dropの作成、取得、物理削除を行うgRPC APIの実装。
- DropデータのPostgreSQLへの永続化。
- Drop作成、削除時にイベントを発行 (Redis Pub/Sub) し、他のサービス (Timeline, Search, ActivityPub, Notification) と連携する。
- Dropの公開範囲 (`visibility`) に基づいた基本的なアクセス制御チェック (取得時)。
- 添付メディア情報 (`avion-media` が管理するID/URL) の関連付け。
- Go言語で実装し、Kubernetes上でのステートレス運用を前提とする。
- OpenTelemetryによるトレーシング・メトリクス・ロギング対応。

### Non-Goals (やらないこと)

- **Dropの編集機能 (v1)。**
- **タイムライン生成:** `avion-timeline` が担当。
- **リアクション管理:** `avion-reaction` が担当。
- **通知生成:** `avion-notification` が担当。
- **メディアファイルの保存・配信:** `avion-media` が担当。
- **全文検索インデックス作成:** `avion-search` が担当 (本サービスはイベント発行のみ)。
- **ハッシュタグ/メンション解析 (初期)。**
- **複雑なアクセス制御ロジック:** フォロワー関係に基づくアクセス判定などは行わない。呼び出し元 (Gateway/Authz/BFF) が事前に行う前提。
- **削除済みDropの復元機能。**

## 4. Architecture (どうやって作る？)

- **主要コンポーネント:**
    - `avion-post (Go, Kubernetes Deployment)`: 本サービス。gRPCサーバー、Redis Pub/Sub発行者。
    - `avion-gateway (Go)`: gRPCリクエストのルーティング元。
    - `avion-media (Go)`: メディア情報の関連付けで連携。
    - `PostgreSQL`: Dropデータを永続化。
    - `Redis`: イベント通知 (Pub/Sub)。
    - `Observability Stack`: メトリクス、トレース、ログ収集。
    - イベント購読者 (`avion-timeline`, `avion-search`, `avion-activitypub`, `avion-notification`)。
- **構成図:** (アーキテクチャ概要図を参照)
    - [Avion アーキテクチャ概要](../architecture.md)
- **ポイント:**
    - Dropの作成、取得、物理削除とデータ永続化を行う。
    - 状態変更時にイベントを発行し、他サービスとの連携を疎結合に保つ。
    - ステートレス設計。

## 5. Use Cases / Key Flows (主な使い方・処理の流れ)

- **フロー 1: Drop作成**
    1. Gateway → `CreateDrop` gRPC Call (text, visibility, media_ids, Metadata: X-User-ID, Trace Context)
    2. PostService: リクエスト内容検証 (文字数など)。
    3. PostService: DBに新しいDropレコードを作成 (user_id, text, visibility, media_idsなど)。Drop IDを生成。
    4. PostService: Redis Pub/Subチャネル `drop_created` にイベント発行 (Payload: 作成されたDropの全データ)。
    5. PostService → Gateway: `CreateDropResponse { drop_id: "..." }`
- **フロー 2: Drop取得 (単一)**
    1. Gateway → `GetDrop` gRPC Call (drop_id, Metadata: X-User-ID, Trace Context)
    2. PostService: DBから `drop_id` でDropレコードを取得。
    3. PostService: Dropの公開範囲 (`visibility`) を確認。もし `public` でなければ、リクエスト元のユーザーID (`X-User-ID`) がDropの作成者 (`user_id`) と一致するかチェック。(フォロワー限定などの詳細なチェックは呼び出し元で行われている前提)
    4. (アクセス不可の場合) PostService → Gateway: gRPC Error (PermissionDenied or NotFound)
    5. (アクセス可の場合) PostService → Gateway: `GetDropResponse { drop: { ... } }`
- **フロー 3: Drop削除**
    1. Gateway → `DeleteDrop` gRPC Call (drop_id, Metadata: X-User-ID, Trace Context)
    2. PostService: DBからDropレコード取得。作成者IDと `X-User-ID` が一致するか確認。
    3. (不一致の場合) PostService → Gateway: gRPC Error (PermissionDenied)
    4. (一致の場合) PostService: DBから該当するDropレコードを物理削除 (`DELETE FROM drops WHERE id = ...`)。
    5. PostService: Redis Pub/Subチャネル `drop_deleted` にイベント発行 (Payload: `{ "drop_id": "...", "user_id": "..." }`)。
    6. PostService → Gateway: `DeleteDropResponse {}`

## 6. Endpoints (API)

- **gRPC Services (`avion.PostService`):**
    - `CreateDrop(CreateDropRequest) returns (CreateDropResponse)`
    - `GetDrop(GetDropRequest) returns (GetDropResponse)`
    - `GetDropsByUserID(GetDropsByUserIDRequest) returns (GetDropsByUserIDResponse)` // ユーザープロフィール用
    - `DeleteDrop(DeleteDropRequest) returns (DeleteDropResponse)`
    // `UpdateDrop` はv1では実装しない
- Proto定義は別途管理する。

## 7. Data Design (データ)

- **PostgreSQL:**
    - `drops` table:
        - `id (BIGINT, PK)`
        - `user_id (BIGINT, FK to users.id, INDEX)`
        - `text (TEXT)`
        - `visibility (ENUM('public', 'followers_only', ...))`
        - `media_ids (BIGINT[])`: `avion-media` で管理されるメディアIDの配列
        - `created_at (TIMESTAMP)`
        - `updated_at (TIMESTAMP)`
        - Index: `(user_id, created_at)`, `created_at`
- **Redis:**
    - Pub/Sub Channels: `drop_created`, `drop_deleted` // `drop_updated` はv1では不要

## 8. Operations & Monitoring (運用と監視)

- **主なオペレーション:**
    - DBマイグレーション。
    - Redis接続情報、Pub/Sub設定。
- **監視/アラート:**
    - **メトリクス:**
        - gRPCリクエスト数、レイテンシ、エラーレート。
        - DB接続エラー、クエリ実行時間。
        - Pub/Sub発行エラー/遅延。
    - **ログ:** CRUD操作ログ、エラーログ。
    - **トレース:** API呼び出し、DBアクセス、イベント発行のトレース。
    - **アラート:** gRPCエラーレート急増、高レイテンシ、DB接続障害、Pub/Sub発行失敗。

## 9. Concerns / Open Questions (懸念事項・相談したいこと)

- **技術的負債リスク:**
    - **物理削除の非可逆性:** 物理削除はシンプルだが、誤削除時の復旧や将来的な「ゴミ箱」機能などの要求変更に対応できない。これは設計上のトレードオフ。
    - **イベントペイロード:** `drop_created` で全データを含めるのは、データサイズが大きい場合にネットワーク帯域や受信側サービスの負荷になる可能性がある。必要な情報のみに絞るか検討が必要。
- 引用/リポストのデータモデルを将来的にどう統合するか。

---
