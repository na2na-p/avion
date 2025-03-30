# Design Doc: avion-timeline

**Author:** Cline
**Last Updated:** 2025/03/30

## 1. Summary (これは何？)

- **一言で:** Avionにおける各種タイムライン（ホーム、ローカル、グローバル）の生成および取得、リアルタイム更新 (SSE) を行うマイクロサービスを実装します。
- **目的:** ユーザーに関連性の高いDropを効率的に集約し、高速に提供します。Redisキャッシュを積極的に活用し、SSEを通じてリアルタイムな体験を提供します。

## 2. Background & Links (背景と関連リンク)

- SNSの主要なユーザー体験であるタイムライン機能を提供するため。
- ホームタイムラインのパーソナライズ、ローカル/グローバルタイムラインの集約、リアルタイム更新といった要求に応えるため、独立したサービスとする。
- [PRD: avion-timeline](./prd.md)
- [Avion アーキテクチャ概要](../architecture.md)

## 3. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

- ホームタイムライン生成・取得API (gRPC) の実装 (フォロー中のユーザーのDrop)。
- ローカルタイムライン生成・取得API (gRPC) の実装 (同一サーバー内の公開Drop)。
- グローバルタイムライン生成・取得API (gRPC) の実装 (連合サーバー含む公開Drop)。
- Redis (Sorted Set) を用いたタイムラインキャッシュの実装 (Drop IDをスコア=タイムスタンプで保持)。
- Drop作成/削除イベント (Redis Pub/Sub) を購読し、関連タイムラインキャッシュを非同期で更新する (Fan-out on write)。
- ActivityPubからのDrop受信イベント (`ap_drop_received`) を購読し、グローバルタイムラインキャッシュを更新する。
- ホームタイムライン更新イベントをServer-Sent Events (SSE) で配信するエンドポイントの実装。
- ページネーション機能 (カーソルベース) の実装。
- Go言語で実装し、Kubernetes上でのステートレス運用を前提とする。
- OpenTelemetryによるトレーシング・メトリクス・ロギング対応。

### Non-Goals (やらないこと)

- **Drop/ユーザー情報の永続化:** `avion-post`/`avion-user` が担当。本サービスはIDリスト等をキャッシュする。
- **フォロー関係の管理:** `avion-user` が担当。本サービスは参照する。
- **複雑なランキングアルゴリズム (初期):** 時系列順を基本とする。
- **WebSocket:** SSEを優先。
- **タイムライン内検索:** `avion-search` が担当。
- **Fan-out on writeの厳密なスケーラビリティ保証 (初期):** モニタリングし、必要に応じて改善。

## 4. Architecture (どうやって作る？)

- **主要コンポーネント:**
    - `avion-timeline (Go, Kubernetes Deployment)`: 本サービス。gRPCサーバー、SSEサーバー、Redis Pub/Sub購読者、非同期Fan-outワーカ。
    - `avion-gateway (Go)`: gRPC/SSEリクエストのルーティング元。
    - `avion-user (Go)`: フォローリスト取得 (gRPC)。
    - `avion-post (Go)`: Drop詳細情報取得 (gRPC、キャッシュミス時など)。
    - `avion-activitypub (Go)`: リモートDrop情報取得 (gRPC or イベント経由)。`ap_drop_received` イベント発行元。
    - `Redis`: タイムラインキャッシュ (Sorted Set)、イベント通知 (Pub/Sub)、SSE接続管理。
    - `Observability Stack`: メトリクス、トレース、ログ収集。
- **構成図:** (アーキテクチャ概要図を参照)
    - [Avion アーキテクチャ概要](../architecture.md)
- **ポイント:**
    - タイムライン取得リクエストに対し、主にRedisキャッシュからDrop IDリストを返す。
    - Drop作成/削除/AP受信イベントを購読し、非同期ワーカで関連タイムラインキャッシュを更新 (Fan-out)。
    - ホームタイムラインの更新はSSEでクライアントにプッシュする。
    - ステートレス設計。SSE接続状態はRedisで管理。

## 5. Use Cases / Key Flows (主な使い方・処理の流れ)

- **フロー 1: ホームタイムライン取得 (キャッシュヒット)**
    1. Gateway → `GetHomeTimeline` gRPC Call (user_id, limit, since_id/max_id, Metadata: Trace Context)
    2. TimelineService: Redisで `timeline:home:{user_id}` (Sorted Set) を検索。
    3. TimelineService: 指定されたカーソルに基づきDrop IDリストを取得 (`ZRANGEBYSCORE` or `ZREVRANGEBYSCORE` with `LIMIT`)。
    4. TimelineService → Gateway: `GetHomeTimelineResponse { drop_ids: [...] }`
- **フロー 2: ホームタイムライン取得 (キャッシュミス/再構築)**
    1. Gateway → `GetHomeTimeline` gRPC Call (user_id, ...)
    2. TimelineService: Redisキャッシュ検索 (ミス)。
    3. TimelineService → UserService: `GetFollowingList` gRPC Call (user_id)
    4. UserService → TimelineService: `GetFollowingListResponse { user_ids: [...] }`
    5. TimelineService → PostService: `GetDropsByUserID` gRPC Call (各following_id, limit=N) // 並列実行
    6. PostService → TimelineService: `GetDropsByUserIDResponse { drops: [...] }` // 各レスポンス
    7. TimelineService: 取得したDropをマージし、タイムスタンプでソート。
    8. TimelineService: Redisキャッシュ (`timeline:home:{user_id}`) にDrop IDとタイムスタンプを保存 (`ZADD`)。古いエントリを削除 (`ZREMRANGEBYRANK key 0 -(limit+1)`)。
    9. TimelineService: 要求されたページのDrop IDリストを抽出。
    10. TimelineService → Gateway: `GetHomeTimelineResponse { drop_ids: [...] }`
- **フロー 3: Drop作成イベント受信 & キャッシュ更新 (Fan-out)**
    1. TimelineService (Subscriber): Redis Pub/Subチャネル `drop_created` からイベント受信 (Payload: { drop_id, user_id, visibility, created_at })。
    2. TimelineService (Async Worker): visibilityが `public` なら、`timeline:local` および `timeline:global` (Sorted Set) に `ZADD ... {created_at} {drop_id}` を実行。古いエントリ削除 (`ZREMRANGEBYRANK`)。
    3. TimelineService (Async Worker) → UserService: `GetFollowersList` gRPC Call (user_id)
    4. UserService → TimelineService (Async Worker): `GetFollowersListResponse { user_ids: [...] }`
    5. TimelineService (Async Worker): 各フォロワー (`follower_id`) について、Redisキャッシュ `timeline:home:{follower_id}` に `ZADD ... {created_at} {drop_id}` を実行。古いエントリ削除 (`ZREMRANGEBYRANK`)。(※多数フォロワーの場合の負荷をモニタリング)
    6. TimelineService (Async Worker): (SSE) 該当フォロワーのSSE接続があれば、更新イベントを送信。
- **フロー 4: Drop削除イベント受信 & キャッシュ更新**
    1. TimelineService (Subscriber): Redis Pub/Subチャネル `drop_deleted` からイベント受信 (Payload: { drop_id, user_id })。
    2. TimelineService (Async Worker): `timeline:local`, `timeline:global` から `ZREM ... {drop_id}` を実行。
    3. TimelineService (Async Worker) → UserService: `GetFollowersList` gRPC Call (user_id)
    4. UserService → TimelineService (Async Worker): `GetFollowersListResponse { user_ids: [...] }`
    5. TimelineService (Async Worker): 各フォロワー (`follower_id`) について、Redisキャッシュ `timeline:home:{follower_id}` から `ZREM ... {drop_id}` を実行。
    6. TimelineService (Async Worker): (SSE) 該当フォロワーのSSE接続があれば、削除イベントを送信 (検討)。
- **フロー 5: ActivityPub Drop受信イベント & キャッシュ更新**
    1. TimelineService (Subscriber): Redis Pub/Subチャネル `ap_drop_received` からイベント受信 (Payload: { drop_id, created_at })。
    2. TimelineService (Async Worker): `timeline:global` (Sorted Set) に `ZADD ... {created_at} {drop_id}` を実行。古いエントリ削除 (`ZREMRANGEBYRANK`)。
- **フロー 6: SSE接続 & イベント送信**
    1. Client (via BFF/Gateway) → SSE接続リクエスト (`/events/timeline/home`, Authヘッダー)
    2. TimelineService: 認証情報からユーザーID取得。接続を確立し、Redisに接続情報を登録 (`sse_connections:user:{user_id}` に接続ID追加、`sse_connection:{connection_id}` にPod情報等保存)。
    3. (フロー3-6の後) TimelineService: ユーザーIDに対応する接続情報 (接続ID、Pod情報) をRedisから取得。
    4. TimelineService: 該当Pod上の接続を見つけ、`event: new_drop\ndata: {"drop_id": "..."}\n\n` のようなメッセージを送信。接続が存在しない場合は何もしない。

## 6. Endpoints (API)

- **gRPC Services (`avion.TimelineService`):**
    - `GetHomeTimeline(GetTimelineRequest) returns (GetTimelineResponse)`
    - `GetLocalTimeline(GetTimelineRequest) returns (GetTimelineResponse)`
    - `GetGlobalTimeline(GetTimelineRequest) returns (GetTimelineResponse)`
    - (Requestには `user_id`, `limit`, `since_id`, `max_id` などを含む)
    - (Responseには `drop_ids` のリストを含む)
- **HTTP Endpoints:**
    - `/events/timeline/home`: ホームタイムライン更新用SSEストリームエンドポイント (認証要)。
- Proto定義は別途管理する。

## 7. Data Design (データ)

- **Redis:**
    - **タイムラインキャッシュ (Sorted Set):**
        - `timeline:home:{user_id}`: ホームタイムライン (Score: timestamp(ms), Member: drop_id)
        - `timeline:local`: ローカルタイムライン (Score: timestamp(ms), Member: drop_id)
        - `timeline:global`: グローバルタイムライン (Score: timestamp(ms), Member: drop_id)
        - ※ キャッシュ件数上限: 設定値 (例: 1000)。`ZADD` 後に `ZREMRANGEBYRANK key 0 -(limit+1)` で古いものを削除。上限値は要調整。
    - **Pub/Sub Channels:** `drop_created`, `drop_deleted`, `ap_drop_received` (購読)
    - **SSE接続管理 (Hash/Set):**
        - `sse_connections:user:{user_id}` (Set): Member: connection_id
        - `sse_connection:{connection_id}` (Hash): Field: pod_name, Field: created_at, ... (TTLを設定し、定期的な接続確認/クリーンアップが必要)

## 8. Operations & Monitoring (運用と監視)

- **主なオペレーション:**
    - Redis接続情報、Pub/Sub設定。
    - キャッシュ件数上限などのパラメータ調整。
    - SSE接続情報のクリーンアップジョブ運用。
    - (必要に応じて) キャッシュの手動クリア。
- **監視/アラート:**
    - **メトリクス:**
        - gRPC/SSEリクエスト数、レイテンシ、エラーレート。
        - Redisキャッシュヒット率、コマンド実行時間、メモリ使用量。
        - Pub/Subイベント処理遅延、エラーレート。
        - SSE接続数。
        - Fan-out処理時間/キュー長 (多数フォロワー対応実装時)。
    - **ログ:** API処理ログ、イベント処理ログ、SSE接続/切断ログ、エラーログ。
    - **トレース:** API呼び出し、キャッシュアクセス、イベント処理、他サービス連携のトレース。
    - **アラート:** gRPC/SSEエラーレート急増、高レイテンシ、Redis接続障害、Pub/Sub処理遅延大、SSE接続数異常、Fan-out処理遅延大。

## 9. Concerns / Open Questions (懸念事項・相談したいこと)

- **技術的負債リスク:**
    - **Fan-out on writeのスケーラビリティ:** 多数フォロワーユーザーへの対応は依然として最大の懸念。初期実装はこの方式とするが、負荷状況に応じて非同期ワーカのスケールアウト、バッチ処理導入、シャーディング、最終的にはFan-out on readへの移行検討が必要となる可能性が高い。
    - **キャッシュ上限:** 固定長キャッシュはシンプルだが、利用状況によってユーザー体験（古い投稿が見えない）とリソース消費（メモリ）のトレードオフ調整が運用後も続く可能性がある。
    - **SSE接続管理:** ステートレスサービスでの多数接続管理は複雑化しやすく、接続情報の外部管理（Redis等）とそのスケーラビリティ、整合性維持（Pod障害時のクリーンアップ等）が将来的な課題となる可能性がある。
- グローバルタイムラインの定義と実装方法 (`avion-activitypub` との連携詳細)。ActivityPubからのDropをどの程度キャッシュに保持するか。
- Drop削除イベント受信時のキャッシュ削除処理の確実性。

---
