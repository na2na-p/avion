# Design Doc: avion-activitypub

**Author:** Cline
**Last Updated:** 2025/03/30

## 1. Summary (これは何？)

- **一言で:** AvionをActivityPubプロトコルに対応させ、他の互換サーバー（Terminal）との連合（Federation）を実現するマイクロサービスを実装します。
- **目的:** ActivityPubアクティビティの送受信 (Inbox/Outbox)、Actor情報の提供 (WebFinger含む)、HTTP Signaturesによる検証・署名、リモート情報の管理・キャッシュ連携を行います。

## 2. Background & Links (背景と関連リンク)

- AvionをFediverseの一部として機能させ、相互運用性を確保するため。
- 複雑なActivityPubプロトコル処理を他のコアサービスから分離するため。
- [PRD: avion-activitypub](./prd.md)
- [Avion アーキテクチャ概要](../architecture.md)
- ActivityPub, ActivityStreams, WebFinger, HTTP Signatures等の関連仕様。

## 3. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

- ActivityPub Actor (Person) エンドポイントの実装 (`/users/{username}`)。
- WebFingerエンドポイントの実装 (`/.well-known/webfinger`)。
- Inboxエンドポイントの実装 (`/inbox`, `/users/{username}/inbox`)。
    - HTTP Signatures検証 (公開鍵は `avion-user` またはキャッシュから取得)。
    - 受信アクティビティ (Create, Update, Delete, Follow, Accept, Reject, Announce, Like, Undo等) の解釈と、関連サービスへのイベント発行 (Redis Pub/Sub)。
- Outbox処理の実装 (非同期、Redis Stream + Consumer Group)。
    - ローカルイベント (Drop作成、フォロー、リアクション等) を購読 (Redis Pub/Sub)。
    - 対応するActivityPubアクティビティを生成。
    - HTTP Signaturesで署名 (秘密鍵は `avion-user` に問い合わせ)。
    - 対象リモートActorのInboxへ配送 (共有Inbox利用含む)。
    - 指数バックオフによるリトライ機構とデッドレターキュー (DLQ)。
- リモートActor/Object情報のキャッシュ/DB保存 (定期的な削除ポリシー含む)。
- リモートメディアのキャッシュ依頼 (`avion-media` へ)。
- Go言語で実装し、Kubernetes上でのステートレス運用を前提とする。
- OpenTelemetryによるトレーシング・メトリクス・ロギング対応。

### Non-Goals (やらないこと)

- **ActivityPub Client-to-Server (C2S) プロトコル。**
- **全てのActivityPubアクティビティ/オブジェクトタイプの完全サポート (初期)。**
- **複雑なActivityPubアクセス制御ロジック (初期)。**
- **リレーサーバー機能 (初期)。**
- **高度なスパム/不正行為対策 (初期)。**
- **Outbox処理における厳密な順序保証 (初期)。**

## 4. Architecture (どうやって作る？)

- **主要コンポーネント:**
    - `avion-activitypub (Go, Kubernetes Deployment)`: 本サービス。HTTPサーバー、Redis Pub/Sub購読者、非同期Outboxワーカ (Redis Stream Consumer)。
    - `avion-gateway (Go)`: HTTPリクエストのルーティング元。
    - `avion-user (Go)`: Actor情報生成、フォロー関係連携、HTTP Signatures鍵管理・署名/検証API提供 (gRPC)。
    - `avion-post (Go)`: Drop情報連携 (gRPC or イベント経由)。
    - `avion-media (Go)`: リモートメディアキャッシュ依頼 (gRPC)。
    - `PostgreSQL`: リモートActor/Object情報、DLQ情報などを永続化。
    - `Redis`: ローカルイベント購読 (Pub/Sub)、Outbox配送キュー (Stream)、リモート情報キャッシュ、公開鍵キャッシュ。
    - `Observability Stack`: メトリクス、トレース、ログ収集。
    - `Other Terminal`: 通信相手のActivityPubサーバー。
- **構成図:** (アーキテクチャ概要図を参照)
    - [Avion アーキテクチャ概要](../architecture.md)
- **ポイント:**
    - HTTPエンドポイントで外部サーバーと通信。
    - 内部サービスとはgRPCおよびRedis Pub/Sub/Streamで連携。
    - Inbox処理は同期的に受け付け、実際の処理は非同期で行う場合がある。
    - Outbox処理はRedis StreamとConsumer Groupを用いた非同期処理。
    - HTTP Signaturesの鍵管理・操作は `avion-user` に委任。
    - ステートレス設計 (配送キューの状態などはRedis/Postgresで管理)。

## 5. Use Cases / Key Flows (主な使い方・処理の流れ)

- **フロー 1: InboxへのActivity受信 (例: Follow)**
    1. Other Terminal → Gateway: `POST /users/alice/inbox` (Activity: Follow, Signatureヘッダー)
    2. Gateway → ActivityPubService: `POST /users/alice/inbox` (HTTP転送)
    3. ActivityPubService → UserService: `GetPublicKey` gRPC Call (actor_id from Signature) // 公開鍵取得 (キャッシュ優先)
    4. UserService → ActivityPubService: `GetPublicKeyResponse { public_key_pem: "..." }`
    5. ActivityPubService: HTTP Signature検証。
    6. (検証成功) ActivityPubService: Followアクティビティを解析。リモートActor情報をDB/キャッシュに保存。
    7. ActivityPubService: Redis Pub/Subチャネル `ap_follow_received` にイベント発行 (Payload: { follower_actor_id, following_user_id })。
    8. ActivityPubService → Gateway: `202 Accepted`
    9. (非同期) `avion-user` がイベントを購読し、フォロー承認処理へ。
- **フロー 2: ローカルDrop作成イベント受信 & Outbox処理**
    1. ActivityPubService (Subscriber): Redis Pub/Subチャネル `drop_created` からイベント受信 (Payload: { drop_id, user_id, text, visibility, ... })。
    2. ActivityPubService: visibilityが連合可能なものかチェック。
    3. ActivityPubService → UserService: `GetFollowersList` gRPC Call (user_id, type=remote) // リモートフォロワーのみ取得
    4. UserService → ActivityPubService: `GetFollowersListResponse { actor_ids: [...] }`
    5. ActivityPubService: 取得したフォロワー情報とDrop情報から `Create(Note)` アクティビティを生成。
    6. ActivityPubService: 各フォロワーのInbox URL (またはShared Inbox URL) をDB/キャッシュから取得。
    7. ActivityPubService: Redis Stream `outbox_delivery_queue` に配送タスクを追加 (`XADD`) (Payload: { target_inbox_url, activity_json, user_id_for_signature })。
- **フロー 3: Outbox配送ワーカ**
    1. ActivityPubService (Worker): Redis Stream `outbox_delivery_queue` からConsumer Group経由で配送タスクを取得 (`XREADGROUP`)。
    2. ActivityPubService → UserService: `SignHttpRequest` gRPC Call (user_id, http_method, target_url, date_header, body_digest) // 署名依頼
    3. UserService → ActivityPubService: `SignHttpRequestResponse { signature_header: "..." }`
    4. ActivityPubService → Other Terminal: `POST {target_inbox_url}` (Activity JSON, Signatureヘッダー, Dateヘッダーなど)
    5. (成功時) ActivityPubService: タスクをACK (`XACK`)。
    6. (失敗時) ActivityPubService: リトライ処理 (指数バックオフ)。一定回数失敗後はDLQに移動 or ログ記録しACK。
- **フロー 4: リモートメディアキャッシュ依頼** (変更なし)
    ...

## 6. Endpoints (API)

- **HTTP Endpoints:** (変更なし)
    - `GET /.well-known/webfinger?resource=acct:{username}@{domain}`
    - `GET /users/{username}` (Accept: application/activity+json)
    - `POST /inbox` (共有Inbox)
    - `POST /users/{username}/inbox` (ユーザー別Inbox)
    - `GET /users/{username}/outbox` (読み取り用、実装優先度低)
- **gRPC Services:** (内部連携用、必要に応じて定義)
    - 例: `GetRemoteActor(GetRemoteActorRequest) returns (GetRemoteActorResponse)`
- Proto定義は別途管理する。

## 7. Data Design (データ)

- **PostgreSQL:**
    - `remote_actors` table: (変更なし)
    - `remote_objects` table: (変更なし)
    - `outbox_dlq` table (検討): 配送失敗タスク情報 (リトライ回数超過時)。
- **Redis:**
    - Pub/Sub Channels: `drop_created`, ... (購読), `ap_follow_received`, ... (発行)
    - Outbox配送キュー (Stream): `outbox_delivery_queue` (Consumer Group: `activitypub_workers`)
    - リモート情報キャッシュ: `remote_actor:{actor_id}`, `remote_object:{object_id}` (TTL設定)
    - WebFingerキャッシュ: `webfinger:{acct_uri}` (TTL設定)
    - 公開鍵キャッシュ: `public_key:{actor_id}` (TTL設定)

## 8. Operations & Monitoring (運用と監視)

- **主なオペレーション:**
    - DBマイグレーション。
    - Redis接続情報、Pub/Sub/Stream設定。
    - Outboxワーカ数、Consumer Groupの調整。
    - DLQの監視と対応。
    - リモート情報DB/キャッシュの削除ジョブ運用。
    - ドメインブロックリストの管理。
- **監視/アラート:**
    - **メトリクス:**
        - HTTPリクエスト数、レイテンシ、エラーレート (Inbox, Actor, WebFinger別)。
        - gRPCリクエスト数、レイテンシ、エラーレート (内部連携)。
        - Pub/Subイベント処理遅延、エラーレート。
        - Outboxキュー長、処理時間、成功/失敗/リトライ/DLQレート。
        - HTTP Signatures検証/署名エラーレート。
        - リモートサーバーへの配送エラーレート (宛先ドメイン別)。
        - Redisキャッシュヒット率。
    - **ログ:** Inbox/Outbox処理ログ、アクティビティ送受信ログ、HTTP Signatures検証/署名結果、エラーログ、DLQ投入ログ。
    - **トレース:** リクエスト処理、イベント処理、配送処理、他サービス連携のトレース。
    - **アラート:** HTTP/gRPCエラーレート急増、高レイテンシ、Pub/Sub処理遅延大、Outboxキュー滞留、配送失敗レート高騰、DLQ増加、特定リモートドメインへの接続エラー多発。

## 9. Concerns / Open Questions (懸念事項・相談したいこと)

- **技術的負債リスク:**
    - **プロトコルの複雑性と互換性維持:** 仕様解釈や拡張追従、実装差異への対応は継続的なコスト。テスト戦略が重要。
    - **非同期処理の複雑性:** Redis StreamとConsumer Groupは堅牢だが、エラーハンドリング、リトライ、DLQ管理の実装・運用は依然として複雑。特に順序保証が必要なケースへの対応は将来的な課題。
    - **リモート情報管理:** データ量増大に伴うパフォーマンス・コスト問題。適切なキャッシュTTLとDB削除ポリシーの定義・運用が不可欠。
    - **エラーハンドリング:** 外部サーバー起因のエラーへの堅牢な対応（リトライ、タイムアウト、サーキットブレーカー等）が重要。
- 使用するGo言語のActivityPubライブラリ/フレームワーク選定。
- HTTP Signatures鍵管理 (`avion-user` との連携API詳細)。
- OutboxキューのConsumer Group設定詳細（ワーカ数、ブロック時間など）。
- リモート情報のDBスキーマ設計とキャッシュ戦略の詳細（TTL、削除ポリシー）。
- 共有Inboxの実装詳細。
- 相互運用性のテスト戦略。

---
