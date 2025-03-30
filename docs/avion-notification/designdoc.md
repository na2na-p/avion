# Design Doc: avion-notification

**Author:** Cline
**Last Updated:** 2025/03/30

## 1. Summary (これは何？)

- **一言で:** Avionにおけるユーザーへの通知（メンション、フォロー、リアクション、リポストなど）を生成、管理、および配信 (SSE, Web Push) するマイクロサービスを実装します。
- **目的:** ユーザーに関連するイベントを検知し、通知データを作成・永続化します。リアルタイム (SSE) およびプッシュ (Web Push) でユーザーに通知を届け、未読管理機能を提供します。

## 2. Background & Links (背景と関連リンク)

- ユーザーエンゲージメント維持とコミュニケーション促進のため、関連イベントの通知が必要。
- 通知生成・管理・配信ロジックを他サービスから分離するため。
- PWAとしての体験向上のため、Web Pushに対応する。
- [PRD: avion-notification](./prd.md)
- [Avion アーキテクチャ概要](../architecture.md)

## 3. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

- 各種イベント (フォロー、メンション、リアクション、リポスト等) を購読 (Redis Stream + Consumer Group)。
- イベントに基づき、通知データを生成しPostgreSQLに永続化 (冪等性確保)。
- 通知リスト取得API (gRPC) の実装 (未読/既読フィルタ、ページネーション)。
- 未読通知件数取得API (gRPC) の実装。
- 通知既読化API (gRPC) の実装 (個別/一括)。
- 新規通知イベントをServer-Sent Events (SSE) で配信するエンドポイントの実装。
- Web Pushサブスクリプション情報の管理 (登録/削除)。
- 新規通知をWeb Pushで送信する機能の実装 (ペイロード暗号化含む)。
- Go言語で実装し、Kubernetes上でのステートレス運用を前提とする。
- OpenTelemetryによるトレーシング・メトリクス・ロギング対応。
- 通知データの定期的なアーカイブ/削除。

### Non-Goals (やらないこと)

- **イベント発生元のビジネスロジック:** 各サービスが担当。
- **通知内容の詳細データ保持:** 概要と参照IDのみ保持。
- **複雑な通知グルーピング (初期)。**
- **通知の優先度付け (初期)。**
- **メール通知。**
- **WebSocket。**

## 4. Architecture (どうやって作る？)

- **主要コンポーネント:**
    - `avion-notification (Go, Kubernetes Deployment)`: 本サービス。gRPCサーバー、SSEサーバー、Web Push送信機能、Redis Stream Consumer。
    - `avion-gateway (Go)`: gRPC/SSEリクエストのルーティング元。
    - `avion-user (Go)`: 通知設定取得 (gRPC、将来)。
    - `PostgreSQL`: 通知データ、Web Pushサブスクリプション情報を永続化。
    - `Redis`: イベント通知 (Stream)、SSE接続管理。
    - `Observability Stack`: メトリクス、トレース、ログ収集。
    - イベント発行元サービス (`avion-user`, `avion-post`, `avion-reaction`, `avion-activitypub`)。
    - Web Push Service (ブラウザベンダー提供)。
- **構成図:** (アーキテクチャ概要図を参照)
    - [Avion アーキテクチャ概要](../architecture.md)
- **ポイント:**
    - イベントをRedis Streamから購読し、通知データを生成・保存。冪等性を確保。
    - gRPC APIで通知リストや未読件数を提供。
    - SSEでリアルタイム更新トリガーを通知。
    - Web Pushでプッシュ通知を送信（暗号化）。
    - ステートレス設計 (SSE接続状態はRedisで管理)。
    - 定期的なデータ削除ポリシーを適用。

## 5. Use Cases / Key Flows (主な使い方・処理の流れ)

- **フロー 1: イベント受信 & 通知生成 (例: リアクション)**
    1. NotificationService (Consumer): Redis Stream `notification_events` からConsumer Group経由でイベント取得 (`XREADGROUP`) (Payload: { event_id, type: "reaction_created", data: { drop_id, user_id, emoji_code, target_user_id } })。
    2. NotificationService: `event_id` をキーに冪等性チェック (例: Redisに処理済みIDを短時間保存)。
    3. NotificationService: (必要なら `avion-user` から通知設定確認)。
    4. NotificationService: DBに通知レコードを作成 (recipient_user_id=target_user_id, type=reaction, ...)。
    5. NotificationService: (SSE) ユーザー `target_user_id` のSSE接続があれば、更新イベント (`{"type": "new_notification"}`) を送信。
    6. NotificationService: (Web Push) ユーザー `target_user_id` のWeb Pushサブスクリプション情報をDBから取得。
    7. NotificationService: Web Pushメッセージ (暗号化ペイロード含む) を生成し、サブスクリプション情報のエンドポイントURLへ送信。送信失敗時のエラーハンドリング (例: 410 Goneならサブスクリプション削除) を行う。
    8. NotificationService: イベントをACK (`XACK`)。処理失敗時はリトライ or DLQへ。
- **フロー 2: 通知リスト取得** (変更なし)
    ...
- **フロー 3: 未読件数取得** (変更なし)
    ...
- **フロー 4: 通知既読化** (変更なし)
    ...
- **フロー 5: Web Pushサブスクリプション登録** (変更なし)
    ...

## 6. Endpoints (API)

- **gRPC Services (`avion.NotificationService`):** (変更なし)
    - `GetNotifications(GetNotificationsRequest) returns (GetNotificationsResponse)`
    - `GetUnreadCount(GetUnreadCountRequest) returns (GetUnreadCountResponse)`
    - `MarkNotificationsAsRead(MarkNotificationsAsReadRequest) returns (MarkNotificationsAsReadResponse)`
    - `SubscribeWebPush(SubscribeWebPushRequest) returns (SubscribeWebPushResponse)`
    - `UnsubscribeWebPush(UnsubscribeWebPushRequest) returns (UnsubscribeWebPushResponse)`
- **HTTP Endpoints:**
    - `/events/notifications`: 新規通知イベント用SSEストリームエンドポイント (認証要)。
- Proto定義は別途管理する。

## 7. Data Design (データ)

- **PostgreSQL:**
    - `notifications` table: (変更なし、INDEX追加)
        - `id (BIGINT, PK)`
        - `recipient_user_id (BIGINT, FK to users.id, INDEX)`
        - `type (ENUM('follow', 'mention', 'reaction', 'repost', ...))`
        - `actor_user_id (BIGINT, FK to users.id, NULLABLE)`
        - `target_drop_id (BIGINT, FK to drops.id, NULLABLE)`
        - `read (BOOLEAN, DEFAULT false, INDEX)`
        - `created_at (TIMESTAMP, INDEX)`
        - `data (JSONB)`
        - Index: `(recipient_user_id, read, created_at)` // 未読リスト取得用
        - Index: `created_at` // 定期削除用
    - `webpush_subscriptions` table: (変更なし)
        - `id (BIGINT, PK)`
        - `user_id (BIGINT, FK to users.id, INDEX)`
        - `endpoint (TEXT, UNIQUE)`
        - `p256dh (VARCHAR)`
        - `auth (VARCHAR)`
        - `created_at (TIMESTAMP)`
- **Redis:**
    - Event Stream: `notification_events` (Consumer Group: `notification_workers`)
    - Processed Event IDs (for idempotency): `processed_event:{event_id}` (Value: 1, TTL: short)
    - SSE接続管理 (Hash/Set): `sse_connections:user:{user_id}`, `sse_connection:{connection_id}`

## 8. Operations & Monitoring (運用と監視)

- **主なオペレーション:**
    - DBマイグレーション。
    - Redis接続情報、Stream/Consumer Group設定。
    - Web Push VAPIDキーの管理・ローテーション。
    - 通知データのアーカイブ/削除ジョブ運用 (例: 90日以上経過した既読通知を削除)。
- **監視/アラート:**
    - **メトリクス:**
        - gRPC/SSEリクエスト数、レイテンシ、エラーレート。
        - Redis Stream処理遅延、エラーレート、Pending数。
        - Web Push送信成功/失敗レート、レイテンシ。
        - DB接続エラー、クエリ実行時間。
        - SSE接続数。
    - **ログ:** API処理ログ、イベント処理ログ (冪等性チェック結果含む)、SSE接続/切断ログ、Web Push送信ログ（エラー詳細含む）、エラーログ、削除ジョブ実行ログ。
    - **トレース:** API呼び出し、イベント処理、DBアクセス、Web Push送信のトレース。
    - **アラート:** gRPC/SSEエラーレート急増、高レイテンシ、Stream処理遅延大/Pending数増加、Web Push送信失敗レート上昇、DB/Redis接続障害、SSE接続数異常。

## 9. Concerns / Open Questions (懸念事項・相談したいこと)

- **技術的負債リスク:**
    - **イベント処理の信頼性:** Redis StreamとConsumer GroupはPub/Subより堅牢だが、冪等性確保、リトライ、DLQ管理の実装・運用は依然として重要。不備は通知の欠損/重複につながる。
    - **Web Push配信の複雑性と外部依存:** 外部サービス依存とエラーハンドリング（特に無効サブスクリプション）の複雑性は変わらずリスク。
    - **SSE接続管理:** ステートレスサービスでの多数接続管理の複雑性とスケーラビリティは課題。
    - **通知データの増大:** 定期削除ポリシーを定義したが、適切な期間や削除対象（既読のみか、全てか）の判断、ジョブ自体の安定運用が重要。
- 通知データの保存期間 (90日) と削除対象 (既読のみ？) の妥当性。
- 通知設定機能の詳細な仕様と実装方法。
- SSEで送信するイベントの具体的なフォーマット (`{"type": "new_notification"}` で十分か？)。
- Web Pushペイロード暗号化ライブラリの選定と実装詳細。

---
