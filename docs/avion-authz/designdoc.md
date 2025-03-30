# Design Doc: avion-authz

**Author:** Cline
**Last Updated:** 2025/03/30

## 1. Summary (これは何？)

- **一言で:** Avionにおける認可（Authorization）機能を提供するマイクロサービスを実装します。
- **目的:** ユーザー（人間およびBot）が特定のリソースに対してどのような操作を実行できるかを判定します。Botユーザーのクライアント情報（APIキー/シークレット、スコープ）の管理も行います。

## 2. Background & Links (背景と関連リンク)

- 認証 (`avion-user`) と認可を分離し、柔軟でスケーラブルな権限管理を実現するため。
- Botユーザーの導入に伴い、アプリケーションごとの権限管理が必要となるため。
- [PRD: avion-authz](./prd.md)
- [Avion アーキテクチャ概要](../architecture.md)
- [Design Doc: avion-user](../avion-user/designdoc.md)
- [Design Doc: avion-gateway](../avion-gateway/designdoc.md)

## 3. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

- 認可判定API (`Check`) の実装 (gRPC)。ユーザーID、要求アクション、対象リソース、(あれば)スコープ情報を受け取り、許可/拒否を返す。判定結果はRedisでキャッシュ。
- Botユーザー (クライアントアプリケーション) の登録・管理機能の実装。
    - `bot_created` イベント (Redis Pub/Sub) を購読し、クライアントID/シークレットを生成・ハッシュ化して保存。
    - Bot情報 (クライアントID、ハッシュ化シークレット、許可スコープ) をPostgreSQLに永続化。
    - Bot情報更新・削除API (gRPC) の実装 (`avion-user` からのイベント連携または直接APIコール)。
- クライアント認証機能 (Client Credentials Flow) の実装 (`avion-user` と連携)。
- スコープ/ロール定義の管理 (初期は設定ファイルやコード内定義、拡張可能な命名規則)。
- ポリシーに基づいた認可判定ロジックの実装 (初期はシンプルなRBAC/スコープベース、コード/設定ファイルで定義)。
- ポリシー/ロール変更時にキャッシュ無効化イベントを発行 (Redis Pub/Sub)。
- Go言語で実装し、Kubernetes上でのステートレス運用を前提とする。
- OpenTelemetryによるトレーシング・メトリクス・ロギング対応。

### Non-Goals (やらないこと)

- **認証 (Authentication):** ユーザー識別は `avion-user` が担当。本サービスは認証済み情報を受け取る。
- **ユーザーアカウントの永続化:** `avion-user` が担当。
- **UIの提供。**
- **複雑なABAC/ReBAC (初期)。**
- **ポリシーエンジン (OPA等) の導入 (初期)。**

## 4. Architecture (どうやって作る？)

- **主要コンポーネント:**
    - `avion-authz (Go, Kubernetes Deployment)`: 本サービス。gRPCサーバー、Redis Pub/Sub購読者/発行者。
    - `avion-gateway (Go)`: 認可判定依頼元 (gRPC)、キャッシュ無効化イベント購読者。
    - `avion-user (Go)`: Bot作成/削除イベント発行元 (Redis Pub/Sub)、クライアント認証連携 (gRPC)。
    - `PostgreSQL`: Botクライアント情報、スコープ/ロール定義 (将来) を永続化。
    - `Redis`: 認可判定結果キャッシュ、イベント通知 (Pub/Sub)。
    - `Observability Stack`: メトリクス、トレース、ログ収集。
- **構成図:** (アーキテクチャ概要図を参照)
    - [Avion アーキテクチャ概要](../architecture.md)
- **ポイント:**
    - Gatewayからの認可判定リクエストを受け付け、ポリシーに基づき判定結果を返す。結果はキャッシュ。
    - Botクライアント情報を管理し、クライアント認証機能を提供する (Userサービスと連携)。
    - Userサービスからのイベントを購読し、Bot情報を更新する。
    - ポリシー/ロール変更時にはキャッシュ無効化イベントを発行。
    - ステートレス設計。

## 5. Use Cases / Key Flows (主な使い方・処理の流れ)

- **フロー 1: APIリクエスト時の認可チェック (キャッシュヒット)**
    1. Gateway → `Check` gRPC Call (user_id, action, resource, scopes, Metadata: Trace Context)
    2. AuthzService: Redisで `authz_cache:{user_id}:{action}:{resource}` を検索。
    3. AuthzService: キャッシュヒット。`allowed: true` を取得。
    4. AuthzService → Gateway: `CheckResponse { allowed: true }`
- **フロー 2: APIリクエスト時の認可チェック (キャッシュミス)**
    1. Gateway → `Check` gRPC Call (...)
    2. AuthzService: Redisキャッシュ検索 (ミス)。
    3. AuthzService: ポリシー(コード/設定ファイル)に基づき判定 (例: user_idのロール/スコープ確認)。
    4. AuthzService: 判定結果 `allowed: true/false` をRedisに保存 (`authz_cache:...`, TTL: 1 minute)。
    5. AuthzService → Gateway: `CheckResponse { allowed: true/false }`
- **フロー 3: Bot作成イベント受信 & クライアント情報生成**
    1. AuthzService (Subscriber): Redis Pub/Subチャネル `bot_created` からイベント受信 (Payload: { bot_user_id, owner_user_id })。
    2. AuthzService: クライアントID (`bot_user_id`) とランダムなシークレットを生成。
    3. AuthzService: シークレットをハッシュ化 (bcryptなど)。
    4. AuthzService: DBの `bot_clients` テーブルにレコード作成 (client_id=bot_user_id, hashed_secret, owner_user_id, default_scopes)。
- **フロー 4: Botクライアント認証 (Client Credentials Flow)**
    1. Gateway → UserService: `POST /oauth/token` (HTTP転送)
    2. UserService → AuthzService: `AuthenticateClient` gRPC Call (client_id, client_secret)
    3. AuthzService: DBから `client_id` で `bot_clients` レコード取得。
    4. AuthzService: 提供された `client_secret` とDBの `hashed_secret` を比較検証。
    5. (検証成功) AuthzService → UserService: `AuthenticateClientResponse { valid: true, user_id: client_id, scopes: [...] }`
    6. (検証失敗) AuthzService → UserService: `AuthenticateClientResponse { valid: false }`
    7. (UserServiceがJWTを発行してGateway経由でBotに返す)
- **フロー 5: Bot削除イベント受信**
    1. AuthzService (Subscriber): Redis Pub/Subチャネル `bot_deleted` からイベント受信 (Payload: { bot_user_id })。
    2. AuthzService: DBの `bot_clients` テーブルから該当レコードを削除。関連キャッシュも削除。
- **フロー 6: ポリシー/ロール変更時のキャッシュ無効化**
    1. (管理者操作等で) AuthzService: ポリシー/ロール定義を更新。
    2. AuthzService: Redis Pub/Subチャネル `authz_policy_updated` にイベント発行 (Payload: { updated_policy_ids } or 全無効化フラグ)。
    3. Gateway (Subscriber): イベント受信。関連するRedisキャッシュ (`authz_cache:...`) を削除 (または全削除)。

## 6. Endpoints (API)

- **gRPC Services (`avion.AuthzService`):**
    - `Check(CheckRequest) returns (CheckResponse)` // 認可判定
    - `AuthenticateClient(AuthenticateClientRequest) returns (AuthenticateClientResponse)` // Bot認証用
    - `CreateBotClient(CreateBotClientRequest) returns (CreateBotClientResponse)` // イベント処理用 or 管理API
    - `DeleteBotClient(DeleteBotClientRequest) returns (DeleteBotClientResponse)` // イベント処理用 or 管理API
    - `UpdateBotClientScopes(UpdateBotClientScopesRequest) returns (UpdateBotClientScopesResponse)` // 管理用API
- Proto定義は別途管理する。

## 7. Data Design (データ)

- **PostgreSQL:**
    - `bot_clients` table: (変更なし)
    - `scopes` table (検討): (変更なし)
    - `roles` table (検討): (変更なし)
    - `role_scopes` table (検討): (変更なし)
    - `user_roles` table (検討): (変更なし)
- **Redis:**
    - Pub/Sub Channels: `bot_created`, `bot_deleted` (購読), `authz_policy_updated` (発行)
    - 認可判定結果キャッシュ: `authz_cache:{user_id}:{action}:{resource}` (Value: allow/deny, TTL: 1 minute)

## 8. Operations & Monitoring (運用と監視)

- **主なオペレーション:**
    - DBマイグレーション。
    - Redis接続情報、Pub/Sub設定。
    - ポリシー/スコープ/ロール定義の更新（初期はデプロイ）。
    - Botクライアントシークレットのハッシュ化ソルト管理。
- **監視/アラート:**
    - **メトリクス:**
        - gRPCリクエスト数、レイテンシ、エラーレート (特に `Check` API)。
        - DB/Redis接続エラー、クエリ実行時間。
        - Pub/Subイベント処理/発行エラー/遅延。
        - 認可判定キャッシュヒット率。
    - **ログ:** 認可判定ログ (許可/拒否、理由)、Botクライアント管理ログ、エラーログ。
    - **トレース:** API呼び出し、DB/キャッシュアクセス、イベント処理のトレース。
    - **アラート:** gRPCエラーレート急増、高レイテンシ (特に `Check` API)、DB/Redis接続障害、Pub/Sub処理遅延大。

## 9. Concerns / Open Questions (懸念事項・相談したいこと)

- **技術的負債リスク:**
    - **ポリシー管理の複雑化:** コード/設定ファイルでのポリシー管理は、複雑化・増加に伴い管理が煩雑化し、変更容易性が低下するリスクがある。早期のOPA等ポリシーエンジン導入検討が望ましい可能性がある。
    - **パフォーマンス:** `Check` APIの低レイテンシ維持が重要。キャッシュ戦略（特に無効化）の設計・実装が不十分だと問題になる。
    - **Bot認証連携:** Client Credentials Flowの実装やキー/シークレットの安全な管理はセキュリティ上重要であり、実装の複雑性や不備がリスクとなりうる。
    - **スコープ/ロール定義の硬直化:** 初期定義が将来の要求変更に対応できない場合、大規模な変更が必要になる可能性がある。
- 認可ポリシーの具体的な表現形式と管理方法 (初期実装)。
- 使用するロール/スコープの具体的な初期セット。
- Botクライアントシークレットのハッシュ化アルゴリズム。
- 認可判定結果キャッシュの無効化戦略の詳細（イベントペイロード、削除対象キーの特定方法）。

---
