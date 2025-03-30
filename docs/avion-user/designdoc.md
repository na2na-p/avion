# Design Doc: avion-user

**Author:** Cline
**Last Updated:** 2025/03/30

## 1. Summary (これは何？)

- **一言で:** Avionにおけるユーザーアカウント（人間・Bot）のライフサイクル管理、認証手段の提供、およびフォロー関係の管理を行うマイクロサービスを実装します。
- **目的:** ユーザー情報の永続化、安全な認証手段（パスワード、Passkey、TOTP）の提供、フォロー関係の管理を実現します。認証機能と認可機能 (`avion-authz`) は分離し、JWTの発行、公開鍵提供、失効管理を行います。

## 2. Background & Links (背景と関連リンク)

- SNSの基盤として、ユーザーアカウント、認証、フォロー関係の管理機能が必要。
- Botユーザー対応と権限管理の柔軟性向上のため、認可機能を `avion-authz` に分離。
- API Gateway (`avion-gateway`) での効率的なJWT検証のため、公開鍵提供と失効イベント発行機能を提供。
- [PRD: avion-user](./prd.md)
- [Avion アーキテクチャ概要](../architecture.md)
- [PRD: avion-authz](../avion-authz/prd.md)
- [Design Doc: avion-gateway](../avion-gateway/designdoc.md)
- [Design Doc: avion-authz](../avion-authz/designdoc.md)

## 3. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

- ユーザーアカウント (人間) のライフサイクル管理 (登録、情報取得、更新、削除)。
- Botユーザーアカウントのライフサイクル管理 (人間ユーザーに紐づく、アカウント存在管理のみ)。Bot作成/削除時にイベントを発行。
- 認証手段の提供と管理:
    - パスワード認証 (ハッシュ化して保存)。
    - Passkey (WebAuthn) 登録・認証。
    - TOTP登録・認証。
- セッション管理: 認証成功時にJWT (含む `jti`, `exp`, `user_id` 等、スコープは含まない) を発行。
- JWT公開鍵提供API (`GetJWTPublicKeys`) の実装 (gRPC)。
- JWT署名鍵のローテーション機能と、鍵更新イベント (`jwt_key_updated`) の発行 (Redis Pub/Sub)。
- トークン失効処理と失効イベント (`token_revoked`) の発行 (Redis Pub/Sub)。
- Bot認証 (Client Credentials Flow) 用HTTPエンドポイント (`/oauth/token`) の実装 (`avion-authz` と連携)。
- フォロー/アンフォロー機能の実装。
- フォローリスト/フォロワーリスト取得APIの実装。
- プロフィール取得・更新APIの実装。
- Go言語で実装し、Kubernetes上でのステートレス運用を前提とする。
- PostgreSQLをプライマリデータストアとして利用。
- Redisを認証関連情報（チャレンジ、失効リスト等）の一時保存やキャッシュに利用。
- OpenTelemetryによるトレーシング・メトリクス・ロギング対応。

### Non-Goals (やらないこと)

- **認可判定:** `avion-authz` が担当。
- **BotユーザーのAPIキー/シークレット管理・スコープ管理:** `avion-authz` が担当。
- **JWTへのスコープ情報埋め込み。**
- **JWTの検証ロジック (Gateway向け):** Gatewayが公開鍵を用いて行う。
- **複雑な認証フロー (初期):** OAuth連携など。
- **ユーザーブロック機能 (初期)。**
- **ユーザー検索:** `avion-search` が担当。
- **管理者機能 (初期)。**
- **パスワードリセット (初期):** 実装するが、本Design Docの主要スコープ外とする。
- **JWT検証結果のキャッシュ管理:** Gatewayが担当。

## 4. Architecture (どうやって作る？)

- **主要コンポーネント:**
    - `avion-user (Go, Kubernetes Deployment)`: 本サービス。gRPCサーバー、HTTPサーバー (Bot認証用)、Redis Pub/Sub発行者。
    - `avion-gateway (Go)`: gRPCリクエスト元、Bot認証リクエスト転送元。鍵更新/失効イベント購読者。
    - `avion-authz (Go)`: Bot認証連携 (gRPC)。Bot作成/削除イベント購読者。
    - `avion-activitypub (Go)`: リモートフォロー処理依頼。
    - `PostgreSQL`: ユーザー情報、フォロー関係、認証情報（ハッシュ化パスワード、Passkeyクレデンシャル、TOTP秘密鍵）を永続化。
    - `Redis`: WebAuthnチャレンジ、TOTP登録中の秘密鍵、失効済みJWTのJTIリスト、Pub/Sub。
    - `Observability Stack`: メトリクス、トレース、ログ収集。
- **構成図:** (アーキテクチャ概要図を参照)
    - [Avion アーキテクチャ概要](../architecture.md)
- **ポイント:**
    - 認証手段（パスワード、Passkey、TOTP）の提供とJWT発行/失効管理を行う。
    - JWT検証に必要な公開鍵を提供し、更新/失効イベントを発行する。
    - Bot認証エンドポイントを提供し、Authzサービスと連携する。
    - ユーザー情報とフォロー関係をPostgreSQLで管理。
    - 認証プロセス中の一時データや失効情報はRedisを利用。
    - Botアカウントの存在のみ管理し、キー生成等はイベント経由でAuthzに委譲。
    - リモートフォローはActivityPubサービスと連携。
    - ステートレス設計。

## 5. Use Cases / Key Flows (主な使い方・処理の流れ)

- **フロー 1: パスワードログイン & JWT発行**
    1. Gateway → `LoginPassword` gRPC Call (username, password)
    2. UserService: DBからユーザー検索。ハッシュ化パスワード比較。
    3. UserService: (TOTP有効ならTOTP検証ステップへ)
    4. UserService: JWT (含む `jti`, `exp`, `user_id`) 生成。
    5. UserService → Gateway: `LoginPasswordResponse { jwt: "..." }`
- **フロー 2: JWT公開鍵取得 (Gateway起動時/更新時)**
    1. Gateway → `GetJWTPublicKeys` gRPC Call
    2. UserService: 現在有効な公開鍵リストを取得。
    3. UserService → Gateway: `GetJWTPublicKeysResponse { keys: [...] }`
- **フロー 3: ユーザーログアウト & トークン失効**
    1. Gateway → `Logout` gRPC Call (Metadata: Authorization=Bearer {JWT})
    2. UserService: JWTから `jti` と `exp` を取得。
    3. UserService: Redisに `revoked_jti:{jti}` を `exp` までのTTLで保存 (Set with EX)。
    4. UserService: Redis Pub/Subチャネル `token_revoked` に `{ "jti": "..." }` を発行。
    5. UserService → Gateway: `LogoutResponse {}`
- **フロー 4: JWT鍵更新**
    1. (管理者操作等で) UserService: 新しい鍵ペアを生成。古い鍵を無効化予定に。
    2. UserService: Redis Pub/Subチャネル `jwt_key_updated` に新しい公開鍵リスト `{ "keys": [...] }` を発行。
- **フロー 5: Bot認証 (Client Credentials Flow)**
    1. Bot → Gateway: `POST /oauth/token` (HTTP) (grant_type=client_credentials, client_id, client_secret)
    2. Gateway → UserService: `POST /oauth/token` (HTTP転送)
    3. UserService: リクエスト受信。`client_id`, `client_secret` を取得。
    4. UserService → AuthzService: `AuthenticateClient` gRPC Call (client_id, client_secret)
    5. AuthzService → UserService: `AuthenticateClientResponse { valid: true, user_id: client_id, scopes: [...] }`
    6. (検証成功) UserService: JWT (含む `jti`, `exp`, `user_id`, `scopes`) 生成。
    7. UserService → Gateway: HTTP Response (`200 OK` with JWT)
    8. (検証失敗) UserService → Gateway: HTTP Response (`401 Unauthorized`)
- **フロー 6: Passkey登録/認証、TOTP登録/認証** (PRD参照、gRPCで実装)
- **フロー 7: フォロー** (PRD参照、gRPCで実装)
- **フロー 8: Botユーザー登録**
    1. (Web経由) Gateway → `RegisterBot` gRPC Call (name, owner_user_id)
    2. UserService: DBに `user_type='bot'`, `created_by=owner_user_id` でユーザーレコード作成。Botの `user_id` を取得。
    3. UserService: Redis Pub/Subチャネル `bot_created` に `{ "bot_user_id": "...", "owner_user_id": "..." }` を発行。
    4. UserService → Gateway: `RegisterBotResponse { bot_user_id: "..." }`

## 6. Endpoints (API)

- **gRPC Services (`avion.UserService`):**
    - `RegisterUser(RegisterUserRequest) returns (RegisterUserResponse)`
    - `LoginPassword(LoginPasswordRequest) returns (LoginPasswordResponse)`
    - `CreatePasskeyRegistrationChallenge(...) returns (...)`
    - `RegisterPasskey(...) returns (...)`
    - `CreatePasskeyAuthenticationChallenge(...) returns (...)`
    - `AuthenticatePasskey(...) returns (...)`
    - `InitiateTOTPRegistration(...) returns (...)`
    - `VerifyTOTPRegistration(...) returns (...)`
    - `VerifyTOTP(...) returns (...)`
    // `VerifyJWT` は削除
    - `GetJWTPublicKeys(GetJWTPublicKeysRequest) returns (GetJWTPublicKeysResponse)` // New
    - `Logout(LogoutRequest) returns (LogoutResponse)`
    - `GetUserProfile(GetUserProfileRequest) returns (GetUserProfileResponse)`
    - `UpdateUserProfile(UpdateUserProfileRequest) returns (UpdateUserProfileResponse)`
    - `FollowUser(FollowUserRequest) returns (FollowUserResponse)`
    - `UnfollowUser(UnfollowUserRequest) returns (UnfollowUserResponse)`
    - `GetFollowingList(GetFollowingListRequest) returns (GetFollowingListResponse)`
    - `GetFollowersList(GetFollowersListRequest) returns (GetFollowersListResponse)`
    - `RegisterBot(RegisterBotRequest) returns (RegisterBotResponse)` // Botアカウント存在作成のみ
    - `ListBots(ListBotsRequest) returns (ListBotsResponse)` // 自身が作成したBot一覧
    - `DeleteBot(DeleteBotRequest) returns (DeleteBotResponse)` // Botアカウント存在削除 + イベント発行
    - ...
- **HTTP Endpoints:**
    - `/oauth/token`: Bot認証用 (Client Credentials Flow)
- Proto定義は別途管理する。

## 7. Data Design (データ)

- **PostgreSQL:** (変更なし)
    - `users` table
    - `passkey_credentials` table
    - `totp_secrets` table
    - `follows` table
- **Redis:**
    - WebAuthnチャレンジ: `webauthn_challenge:{type}:{user_id}` (Value: challenge data, TTL: 5 minutes)
    - TOTP登録中秘密鍵: `totp_pending:{user_id}` (Value: encrypted secret, TTL: 10 minutes)
    - 失効済みJWT JTI: `revoked_jti:{jti}` (Value: 1, TTL: JWTの元々の有効期限まで)
    - Pub/Sub Channel: `token_revoked`, `jwt_key_updated`, `bot_created`, `bot_deleted`

## 8. Operations & Monitoring (運用と監視)

- **主なオペレーション:**
    - DBマイグレーション。
    - JWT署名鍵のローテーションとイベント発行確認。
    - Redis接続情報、Pub/Sub設定。
    - TOTP秘密鍵暗号化キーの管理。
- **監視/アラート:**
    - **メトリクス:**
        - gRPC/HTTPリクエスト数、レイテンシ、エラーレート。
        - 認証成功/失敗レート (パスワード/Passkey/TOTP/Bot別)。
        - DB/Redis接続エラー。
        - Pub/Sub発行エラー/遅延。
    - **ログ:** 認証試行、成功、失敗ログ。ユーザー作成・更新・削除ログ。フォロー操作ログ。トークン失効ログ。Bot作成/削除ログ。鍵更新ログ。
    - **トレース:** 認証フロー、API呼び出しのトレース。
    - **アラート:** gRPC/HTTPエラーレート急増、高レイテンシ、認証失敗レート急増、DB/Redis接続障害、Pub/Sub発行失敗。

## 9. Concerns / Open Questions (懸念事項・相談したいこと)

- **技術的負債リスク:**
    - **認証フローの複雑性:** Passkey, TOTP, Bot認証など多様な認証方式は実装が複雑になり、セキュリティリスクやメンテナンスコスト増大の可能性がある。ライブラリの選定と適切なテストが重要。
    - **鍵管理:** JWT署名鍵やTOTP秘密鍵の安全な管理・ローテーションは重要だが運用負荷が高い。鍵管理システム(KMS)等の導入も将来的に検討すべきか。
    - **イベント連携の信頼性:** トークン失効や鍵更新、Bot作成/削除イベントの信頼性が低いと、システム全体で不整合が発生する。イベントロスト対策や冪等性確保が必要。
- WebAuthn/Passkey実装の複雑さとライブラリ選定。RP IDの設定。
- TOTP秘密鍵の安全な保存方法 (暗号化キー管理)。
- Bot登録/削除時のイベント連携の信頼性担保 (イベントロスト対策など)。
- DBスキーマの詳細 (インデックス、制約など)。

---
