# Design Doc: avion-gateway

**Author:** Cline
**Last Updated:** 2025/03/30

## 1. Summary (これは何？)

- **一言で:** AvionマイクロサービスアーキテクチャにおけるAPIゲートウェイを実装します。
- **目的:** BFF (`avion-bff-web`) や外部クライアント (他のActivityPubサーバー含む) からのリクエストを集約し、認証 (JWT検証+キャッシュ)、認可チェック (`avion-authz`連携) を行った上で適切なバックエンドサービスへgRPC/HTTPでルーティングします。レートリミット (BFF/Bot向け) やログ集約などの共通機能も提供します。

## 2. Background & Links (背景と関連リンク)

- マイクロサービスアーキテクチャを採用する上で、単一のエントリーポイントと共通機能の集約が必要となるため。
- BFFからのgRPCリクエスト、ActivityPub関連のHTTPリクエスト、Bot認証用HTTPリクエストを受け付け、適切なサービスへ転送する。
- [PRD: avion-gateway](./prd.md)
- [Avion アーキテクチャ概要](../architecture.md)

## 3. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

- BFF (`avion-bff-web`, Go言語) からのgRPCリクエスト受信とバックエンドサービスへのgRPCルーティング。
- 他のActivityPubサーバーからのHTTPリクエスト受信 (例: `/inbox`) と `avion-activitypub` へのHTTPルーティング。
- Bot認証用HTTPリクエスト (`/oauth/token`) の `avion-user` へのルーティング。
- (将来的に) 外部クライアントからのgRPC/HTTPリクエスト受信とルーティング。
- リクエスト/レスポンスの構造化ログ記録 (JSON形式)。
- 認証連携:
    - gRPCリクエストのメタデータに含まれるJWTを、保持している公開鍵で検証。検証結果はRedisでキャッシュする。
    - JWT検証用公開鍵を `avion-user` から取得し、メモリに保持。鍵更新イベント (`jwt_key_updated`) を購読し、鍵を更新する。
    - `avion-user` からのトークン失効イベント (`token_revoked`) に基づき、関連するキャッシュを削除する。
- 認可チェック: 各リクエストに対し `avion-authz` へgRPCで問い合わせ、結果に基づき処理を制御 (ActivityPub受信リクエスト、Bot認証リクエストは除く)。
- レートリミット: IPアドレスまたは認証ユーザーIDに基づく制限 (BFF/Botからのリクエスト向け)。
- 基本的なメトリクス収集 (Prometheus形式)。
- OpenTelemetryトレースコンテキストの生成とバックエンドへの伝播 (gRPCメタデータ/HTTPヘッダー経由)。
- Go言語で実装し、Kubernetes (ECS/Fargate等) 上でのステートレス運用を前提とする。

### Non-Goals (やらないこと)

- **JWTの署名検証ロジックの詳細 (ライブラリ利用):** 検証自体は行うが、複雑なロジックはライブラリに依存。
- **JWT公開鍵の発行・管理:** `avion-user` が担当。
- **Bot認証 (Client Credentials Flow) の処理ロジック:** `avion-user` と `avion-authz` が担当。
- **複雑なビジネスロジック:** ルーティングと共通処理に専念。
- **データ永続化:** 状態を持たない。
- **フロントエンド固有のデータ変換・集約:** BFF (`avion-bff-web`) が担当。
- **サービスディスカバリの動的実装 (初期):** 静的なルーティング設定を基本とする。
- **ActivityPubのHTTP Signatures検証:** `avion-activitypub` が担当。
- **ActivityPub受信リクエストのレートリミット。**
- **レートリミットの詳細実装 (v1)。**

## 4. Architecture (どうやって作る？)

- **主要コンポーネント:**
    - `avion-gateway (Go, Kubernetes Deployment)`: 本サービス。gRPCサーバーおよびHTTPサーバーとして機能。Redis Pub/Subクライアント機能も持つ (トークン失効/鍵更新イベント受信用)。JWT公開鍵をメモリに保持。
    - `avion-bff-web (Go)`: 主要なgRPCクライアント。
    - `avion-user (Go)`: JWT公開鍵提供、トークン失効/鍵更新イベント発行。Bot認証処理。
    - `avion-authz (Go)`: 認可判定、Bot認証連携。
    - `avion-activitypub (Go)`: ActivityPub関連処理。
    - 各バックエンドサービス (`avion-post`, `avion-timeline` など): gRPCルーティング先。
    - `Redis`: JWT検証結果のキャッシュ、トークン失効/鍵更新イベント通知 (Pub/Sub) に使用。
    - `Observability Stack (Prometheus, Jaeger/Tempo, Lokiなど)`: メトリクス、トレース、ログ収集。
- **構成図:** (アーキテクチャ概要図を参照)
    - [Avion アーキテクチャ概要](../architecture.md)
- **ポイント:**
    - BFFからのリクエストはgRPC、ActivityPub/Bot認証はHTTPで受け付ける。
    - 認証 (JWT検証@Gateway+Cache)・認可チェック (Authz連携) を行ってからバックエンドにルーティング。
    - JWT検証キャッシュは `avion-user` からの失効イベントで削除。公開鍵はイベントで更新。
    - ステートレス設計。
    - バックエンドからのgRPCエラーは、必要に応じて適切なHTTPステータスコードに変換する責務を持つ (特にHTTPで受け付けたリクエストへの応答時)。

## 5. Use Cases / Key Flows (主な使い方・処理の流れ)

- **フロー 1: BFFからのgRPCリクエスト (人間ユーザー、キャッシュヒット)**
    1. BFF → Gateway: `CreateDrop` gRPC Call (Metadata: Authorization=Bearer {JWT})
    2. Gateway: JWTから `jti` を抽出。Redisで `jwt_validation:{jti}` を検索。
    3. Gateway: キャッシュヒット。有効なユーザーID `user123` とスコープ情報を取得。
    4. Gateway → AuthzService: `Check` gRPC Call (user: user123, action: write, resource: drop)
    5. AuthzService → Gateway: `CheckResponse { allowed: true }`
    6. Gateway: ルーティングルールに基づき `avion-post` を選択。
    7. Gateway → PostService: `CreateDrop` gRPC Call (リクエスト内容 + Metadata: X-User-ID=user123, Trace Context)
    8. PostService → Gateway: `CreateDropResponse { drop_id: ... }`
    9. Gateway → BFF: `CreateDropResponse { drop_id: ... }`
    10. Gateway: アクセスログ記録 (user123, gRPC CreateDrop, OK, CacheHit, ...)
- **フロー 2: BFFからのgRPCリクエスト (人間ユーザー、キャッシュミス)**
    1. BFF → Gateway: `GetTimeline` gRPC Call (Metadata: Authorization=Bearer {JWT})
    2. Gateway: JWTから `jti` を抽出。Redisで `jwt_validation:{jti}` を検索。
    3. Gateway: キャッシュミス。
    4. Gateway: JWT署名をメモリ上の公開鍵で検証。有効期限チェック。
    5. (検証成功) Gateway: JWTペイロードから `user_id`, `exp` 等を取得。検証結果をRedisに保存 (`jwt_validation:{jti}`, TTL=exp-now)。
    6. (検証失敗) Gateway → BFF: gRPC Error (Unauthenticated)
    7. Gateway → AuthzService: `Check` gRPC Call (user: user123, action: read, resource: timeline)
    8. AuthzService → Gateway: `CheckResponse { allowed: true }`
    9. Gateway: ルーティングルールに基づき `avion-timeline` を選択。
    10. Gateway → TimelineService: `GetTimeline` gRPC Call (Metadata: X-User-ID=user123, Trace Context)
    11. TimelineService → Gateway: `GetTimelineResponse { ... }`
    12. Gateway → BFF: `GetTimelineResponse { ... }`
    13. Gateway: アクセスログ記録 (user123, gRPC GetTimeline, OK, CacheMiss, ...)
- **フロー 3: トークン失効イベント受信**
    1. UserService: ユーザーログアウト等によりJWTを失効させ、Redis Pub/Subに `token_revoked` イベントを発行 (Payload: `{"jti": "some_jti"}`)。
    2. Gateway (Subscriber): `token_revoked` イベントを受信。
    3. Gateway: Redisから `jwt_validation:some_jti` を削除 (DELコマンド)。
- **フロー 4: JWT公開鍵更新イベント受信**
    1. UserService: 鍵ローテーション等で新しい公開鍵を発行し、Redis Pub/Subに `jwt_key_updated` イベントを発行 (Payload: `{"keys": [...]}` or key endpoint)。
    2. Gateway (Subscriber): `jwt_key_updated` イベントを受信。
    3. Gateway: メモリ上の公開鍵リストを更新。
- **フロー 5: Botからの認証リクエスト**
    1. Bot → Gateway: `POST /oauth/token` (HTTP) (grant_type=client_credentials, ...)
    2. Gateway: ルーティングルールに基づき `avion-user` (の認証エンドポイント) へHTTPリクエストを転送。
    3. (avion-userがavion-authzと連携して認証・トークン発行)
    4. avion-user → Gateway: HTTP Response (例: `200 OK` with JWT)
    5. Gateway → Bot: HTTP Response
- **フロー 6: BotからのgRPCリクエスト** (フロー1, 2と同様にキャッシュを利用)
    ... (省略) ...
- **フロー 7: 認可失敗 (gRPC)**
    1. BFF → Gateway: `DeleteUser` gRPC Call (user_id: other_user, Metadata: Authorization=Bearer {JWT})
    2. Gateway: JWT検証 (キャッシュorローカル検証)。ユーザーID `user123` を取得。
    3. Gateway → AuthzService: `Check` gRPC Call (user: user123, action: delete, resource: user/other_user)
    4. AuthzService → Gateway: `CheckResponse { allowed: false }`
    5. Gateway → BFF: gRPC Error (PermissionDenied)
- **フロー 8: ActivityPub InboxへのHTTPリクエスト受信**
    1. 他のActivityPubサーバー → `POST /inbox` (HTTP) (Content-Type: application/activity+json, ...)
    2. Gateway: ルーティングルールに基づき `avion-activitypub` を選択。
    3. Gateway: (基本的なリクエスト検証)
    4. Gateway → ActivityPubService: `POST /inbox` (HTTPリクエスト転送 + Trace Contextヘッダー)
    5. ActivityPubService → Gateway: `202 Accepted` (HTTP) or gRPC Error (例: Internal)
    6. (エラーの場合) Gateway: gRPCエラーを適切なHTTPステータスコード (例: 500) に変換。
    7. Gateway → 他のActivityPubサーバー: `202 Accepted` or `500 Internal Server Error` (HTTP)
    8. Gateway: アクセスログ記録 (送信元IP, POST /inbox, 202 or 500, ...)

## 6. Endpoints (API)

- **gRPC Services:**
    - GatewayはバックエンドサービスへのプロキシとなるgRPCサービスを公開する (例: `avion.TimelineService`, `avion.PostService` など)。具体的なメソッドはBFFの要求に応じて定義。
- **HTTP Endpoints:**
    - `/inbox`, `/users/{username}/inbox`: `avion-activitypub` へ転送。
    - `/.well-known/webfinger`: `avion-activitypub` へ転送。
    - `/oauth/token`: `avion-user` へ転送。
- Proto定義は別途管理する。

## 7. Data Design (データ)

- Gateway自体はデータを永続化しない。
- JWT検証結果のキャッシュのためにRedisを使用する。
    - **Key:** `jwt_validation:{jti}` (`jti` はJWT ID Claim)
    - **Value:** `{ "user_id": "...", "scopes": [...], "valid": true, "exp": 17xxxxxxx }` (JSON or similar)
    - **TTL:** JWTの有効期限 (`exp`) に基づいて設定 (例: `EXPIRE key (exp - now)`)。有効期限切れのキャッシュが残らないようにする。
- JWT検証用の公開鍵: メモリ上に保持。`avion-user` からのイベントで更新。

## 8. Operations & Monitoring (運用と監視)

- **主なオペレーション:**
    - 設定変更 (ルーティングルールなど) はConfigMap等を更新し、ローリングアップデートで適用。
    - Redis接続情報、Pub/Sub設定。
    - JWT公開鍵の初期取得方法と更新失敗時のハンドリング。
- **監視/アラート:**
    - **メトリクス (Prometheus):**
        - gRPCリクエスト数 (サービス、メソッド、ステータスコード別)
        - HTTPリクエスト数 (パス、メソッド、ステータスコード別)
        - レスポンスタイム (gRPC/HTTP別、パーセンタイル)
        - gRPC/HTTPエラーレート
        - 認可成功/失敗レート
        - レートリミット発生回数 (BFF/Bot向け)
        - JWTキャッシュヒット率
        - JWT検証エラーレート
    - **ログ (Lokiなど):** 構造化ログによるリクエスト追跡、エラー調査。Trace IDを含むこと。JWT検証失敗、認可失敗ログ。
    - **トレース (Jaeger/Tempo):** リクエスト全体の流れ、ボトルネック特定。
    - **アラート:** 5xx/gRPCエラーレート急増、高レイテンシ、バックエンドサービス接続エラー、認可サービス接続エラー、Redis接続エラー、JWT公開鍵更新失敗。

## 9. Concerns / Open Questions (懸念事項・相談したいこと)

- `avion-user` が発行するJWTに一意な `jti` Claimが含まれることの確認。
- トークン失効/鍵更新イベントの具体的なフォーマットとPub/Subチャネル名。
- Redisキャッシュのキー衝突可能性（`jti` の一意性が保証されない場合）。
- gRPCエラーからHTTPステータスコードへのマッピングルールの詳細定義。

---
