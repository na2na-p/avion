# Design Doc: avion-auth

**Author:** Avion Team
**Last Updated:** 2025/08/06

## 1. Summary (これは何？)

- **一言で:** Avionにおける認証（Authentication）および認可（Authorization）機能を統合して提供するマイクロサービスを実装します。
- **目的:** ユーザーの認証処理、セッション管理、JWT発行・検証、および認可判定を一元的に扱い、プラットフォーム全体のアクセス制御を提供します。多要素認証（MFA）、OAuth 2.0対応、きめ細かな権限管理により、セキュアで柔軟なアクセス制御基盤を構築します。

## 2. テスト戦略

このサービスでは、[共通テスト戦略](../common/testing-strategy.md)に従ったテスト実装を行います。

### E2Eテスト

このサービスのE2Eテストは、[共通E2Eテスト戦略](../common/e2e-testing-strategy.md)に従って実装します。

#### 主要なE2Eテストシナリオ
- パスワード認証フローの完全なテスト
- WebAuthn（Passkey）登録から認証までのフルサイクル
- TOTP設定から認証完了までのMFAフロー
- JWT発行から検証、失効までのセッション管理
- ロール付与からリソースアクセス判定までの認可フロー
- OAuth 2.0 Client Credentials FlowによるBot認証
- 認証失敗時のアカウントロック・解除フロー
- セキュリティイベント発生から監査ログ記録までの流れ

詳細は[共通E2Eテスト戦略ドキュメント](../common/e2e-testing-strategy.md)を参照してください。

## 3. Background & Links (背景と関連リンク)

- SNSプラットフォームにおける最重要機能である認証・認可を統合管理するため。
- 高速な認証・認可判定により、システム全体のパフォーマンスを向上させるため。
- マイクロサービス間の認証・認可を統一し、セキュリティポリシーの一貫性を確保するため。
- 業界標準（OAuth 2.0、WebAuthn、TOTP）に準拠した実装により、将来的な拡張性を確保するため。
- [PRD: avion-auth](./prd.md)
- [Avion アーキテクチャ概要](../common/architecture.md)
- [OAuth 2.0 RFC 6749](https://tools.ietf.org/html/rfc6749)
- [WebAuthn Specification](https://www.w3.org/TR/webauthn/)
- [TOTP RFC 6238](https://tools.ietf.org/html/rfc6238)
- [JWT RFC 7519](https://tools.ietf.org/html/rfc7519)

## 4. 技術スタック

このサービスでは、[共通Goバックエンド技術スタックガイドライン](../common/architecture/go-backend-framework.md)に従った実装を行います。

### 主要技術
- **HTTPルーティング:** Chi v5
- **RPC:** ConnectRPC
- **認証ライブラリ:** go-chi/jwtauth v5 (JWT処理)
- **セキュリティ:** Argon2id (パスワードハッシュ), WebAuthn (Passkey)

詳細な実装パターンおよびライブラリの使用方法については、[ガイドライン](../common/architecture/go-backend-framework.md)を参照してください。

## 5. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

#### 認証機能
- パスワード認証API（Argon2idハッシュ化）の実装
- Passkey（WebAuthn）登録・認証APIの実装
- TOTP登録・検証APIの実装
- 多要素認証（MFA）フローの実装
- 認証失敗回数管理とアカウントロック機能
- デバイス信頼度管理機能（基本実装）
- パスワードリセット機能
- メール検証フロー（avion-notificationと連携）
- ハードウェアトークン（FIDO2/YubiKey）対応（将来）
- バックアップ認証方法の管理

#### セッション管理
- JWT発行・検証APIの実装
- JWT署名鍵のローテーション機能
- セッション失効管理（Redis）
- 公開鍵提供エンドポイント（JWKS）
- リフレッシュトークン管理
- デバイスセッション管理
- 同時セッション数制限
- セッションタイムアウト管理
- 強制セッションリフレッシュ

#### 認可機能
- 認可判定API（リソース、アクション、ユーザーベース）
- ロールベースアクセス制御（RBAC）
- スコープベース権限管理
- ポリシーベース認可（ABAC）
- 認可結果のキャッシング（Redis）
- リソース所有者判定

#### OAuth 2.0
- Client Credentials Flow（Bot認証）
- Authorization Code Flow（将来実装）
- トークンエンドポイント（/oauth/token）
- クライアント管理API

#### セキュリティ機能
- 認証試行のロギングと分析
- レート制限実装（認証エンドポイント）
- セキュリティイベントログ（認証成功/失敗）
- 基本的な監査ログ（認証・セッション関連）
- CSRF対策
- トークン盗用検知
- デバイスフィンガープリント管理

#### 技術実装
- Go言語による実装
- PostgreSQLへのデータ永続化
- Redisによるキャッシュ・セッション管理
- gRPC APIの実装
- HTTP API（OAuth、JWKS）の実装
- Kubernetes上でのステートレス運用
- OpenTelemetryによるトレーシング・メトリクス・ロギング

### Non-Goals (やらないこと)

- **ユーザー登録・プロフィール管理:** `avion-user` が担当
- **フォロー関係管理:** `avion-user` が担当
- **高度な脅威検出:** `avion-moderation` が担当（不審ログイン、ブルートフォース検出など）
- **コンプライアンス管理:** `avion-system-admin` が担当（GDPR対応、データ保持ポリシーなど）
- **ユーザー行動分析:** `avion-user` が担当（デバイス信頼度の詳細分析、位置情報追跡など）
- **メール送信:** `avion-notification` が担当
- **UIの提供:** `avion-web` が担当
- **ユーザー検索:** `avion-search` が担当
- **メディア認証:** `avion-media` が独自に管理
- **外部IdP連携（初期）:** SAML、LDAP、OAuth2プロバイダー機能は将来実装
- **生体認証（初期）:** Face ID、指紋認証は将来実装
- **適応型認証:** リスクベース認証は `avion-moderation` との連携で将来実装

## 6. Configuration Management

このサービスは、[共通環境変数管理パターン](../common/infrastructure/environment-variables.md)に従った統一的な設定管理を実装します。

### 6.1. 環境変数仕様

#### 必須環境変数
- `DATABASE_URL` (required): PostgreSQL接続URL
- `REDIS_URL` (required): Redis接続URL  
- `JWT_SECRET` (required): JWT署名鍵のパスフレーズ

#### オプション環境変数（デフォルト値付き）
- `JWT_EXPIRY` (default: 15m): JWTアクセストークンの有効期限
- `REFRESH_TOKEN_EXPIRY` (default: 7d): リフレッシュトークンの有効期限
- `PORT` (default: 8081): HTTPサーバーポート
- `GRPC_PORT` (default: 9091): gRPCサーバーポート

### 6.2. Config構造体実装例

```go
// internal/infrastructure/config/config.go
package config

import (
    "time"
)

// Config はavion-authサービスの設定を保持する構造体
type Config struct {
    // サーバー設定
    Server ServerConfig
    
    // データベース設定
    Database DatabaseConfig
    
    // Redis設定
    Redis RedisConfig
    
    // JWT設定
    JWT JWTConfig
    
    // 監視設定
    Observability ObservabilityConfig
}

// ServerConfig サーバー関連の設定
type ServerConfig struct {
    Port        int           `env:"PORT" required:"true" default:"8081"`
    GRPCPort    int           `env:"GRPC_PORT" required:"true" default:"9091"`
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

// JWTConfig JWT関連の設定
type JWTConfig struct {
    Secret              string        `env:"JWT_SECRET" required:"true" secret:"true"`
    AccessTokenExpiry   time.Duration `env:"JWT_EXPIRY" required:"false" default:"15m"`
    RefreshTokenExpiry  time.Duration `env:"REFRESH_TOKEN_EXPIRY" required:"false" default:"7d"`
    KeyRotationInterval time.Duration `env:"JWT_KEY_ROTATION_INTERVAL" required:"false" default:"90d"`
}

// ObservabilityConfig 監視関連の設定
type ObservabilityConfig struct {
    MetricsPort     int    `env:"METRICS_PORT" required:"false" default:"9090"`
    TracingEnabled  bool   `env:"TRACING_ENABLED" required:"false" default:"true"`
    LogLevel        string `env:"LOG_LEVEL" required:"false" default:"info"`
}
```

### 6.3. 使用方法

```go
// cmd/server/main.go
func main() {
    // 環境変数の読み込み（必須環境変数が不足していればここで失敗）
    cfg := config.MustLoad()
    
    // ロガーの初期化
    logger := initLogger(cfg.Server.LogLevel)
    
    logger.Info("Starting avion-auth server",
        "environment", cfg.Server.Environment,
        "port", cfg.Server.Port,
        "grpc_port", cfg.Server.GRPCPort,
    )
    
    // 依存関係の初期化
    db := initDatabase(cfg.Database.URL)
    redis := initRedis(cfg.Redis.URL)
    
    // サーバーの起動
    // ...
}
```

### 6.4. セキュリティ考慮事項

- `JWT_SECRET`には`secret:"true"`タグが付与されており、ログ出力時にマスキングされます
- データベースURLやRedis URLに認証情報が含まれる場合は適切に保護されます
- 本番環境では環境変数を暗号化して管理することを推奨します

## セキュリティ実装ガイドライン

このサービスは以下のセキュリティガイドラインに準拠する必要があります：

### CSRF保護
- **ガイドライン**: [../common/security/csrf-protection.md](../common/security/csrf-protection.md)
- **実装要件**: すべての認証エンドポイントは、ダブルサブミットクッキーとオリジン検証によるCSRF保護を実装する必要があります。パスワードリセット、MFA登録、セッション管理などの重要な操作では、CSRFトークンを検証する必要があります。OAuthフローでは、CSRF防止のためにstateパラメータを含める必要があります。

### TLS設定
- **ガイドライン**: [../common/security/tls-configuration.md](../common/security/tls-configuration.md)
- **実装要件**: 認証データを処理するすべての接続でTLS 1.3を強制します。重要な内部サービス通信には証明書ピニングを実装します。JWT署名鍵と機密認証情報は、適切に設定されたTLS接続上でのみ送信され、該当する場合は相互認証を使用する必要があります。

### 暗号化ガイドライン
- **ガイドライン**: [../common/security/encryption-guidelines.md](../common/security/encryption-guidelines.md)
- **実装要件**: パスワードハッシュには指定されたパラメータ（メモリ=64MB、イテレーション=3、並列度=2）でArgon2idを使用します。JWT署名には最小2048ビット鍵でRS256を使用する必要があります。保存時の機密データ（リカバリーコード、TOTPシークレット）はAES-256-GCMを使用して暗号化する必要があります。署名鍵（30日サイクル）と暗号化鍵（90日サイクル）の適切な鍵ローテーションを実装します。

### セキュリティヘッダー
- **ガイドライン**: [../common/security/security-headers.md](../common/security/security-headers.md)
- **実装要件**: すべての認証エンドポイントに適切なセキュリティヘッダーを設定します。これには、X-Frame-Options（DENY）、X-Content-Type-Options（nosniff）、厳格なContent-Security-Policyが含まれます。認証レスポンスには、機密データのキャッシュを防ぐために適切なCache-Controlヘッダーを含める必要があります。

## 7. Architecture (どうやって作る？)

### 7.1. レイヤードアーキテクチャ (DDD準拠)

#### Domain Layer (ドメイン層)

**Aggregates:**
- AuthCredential: ユーザーの認証情報を統合管理
- Session: 認証セッションとJWTトークンを管理
- SigningKey: JWT署名鍵のライフサイクル管理
- Authorization: ユーザーの権限情報と認可判定を管理
- BotClient: Botクライアントの認証情報とスコープを管理
- Role: ロール定義とスコープマッピングを管理
- Policy: 認可ポリシーの定義と評価
- AuthenticationManager: 認証試行の管理と基本的な異常検出
- APIKeyManager: サービス間認証用のAPIキー管理

**Entities:**
- PasskeyCredential: WebAuthnクレデンシャル情報
- TOTPCredential: TOTP認証情報
- DeviceSession: デバイス別セッション情報
- RefreshToken: リフレッシュトークン情報
- UserRole: ユーザーに付与されたロール
- BotScope: Botクライアントのスコープ
- PolicyRule: ポリシー内の個別ルール
- AuditLog: 認証・認可の監査ログ
- AuthenticationAttempt: 認証試行の記録
- ServiceAccount: サービス間認証用アカウント
- APIKey: APIキー情報
- EmailVerification: メール検証トークン

**Value Objects:**
- UserID, SessionID, ClientID, KeyID, PolicyID, RoleID, ScopeID
- PasswordHash, PlainPassword, TOTPCode, RecoveryCode, ClientSecret
- JWTToken, JWTClaims, JWTHeader, TokenType
- SessionType, DeviceFingerprint, IPAddress, TrustLevel
- Permission, Resource, Action, Effect, PolicyCondition
- CreatedAt, UpdatedAt, ExpiresAt, IssuedAt, LockedUntil, Duration
- FailedAttempts, SignCount, SecurityEventType, AuditAction

**Domain Events:**
- AuthenticationAttempted: 認証試行イベント
- AuthenticationSucceeded: 認証成功イベント
- AuthenticationFailed: 認証失敗イベント
- SessionCreated: セッション作成イベント
- SessionExpired: セッション期限切れイベント
- SessionRevoked: セッション取り消しイベント
- RefreshTokenRotated: リフレッシュトークンローテーションイベント
- PasskeyRegistered: Passkey登録イベント
- PasskeyAuthenticated: Passkey認証イベント
- TOTPEnabled: TOTP有効化イベント
- TOTPDisabled: TOTP無効化イベント
- MultiFactorChallengeIssued: MFAチャレンジ発行イベント
- PasswordResetRequested: パスワードリセット要求イベント
- PasswordResetCompleted: パスワードリセット完了イベント
- EmailVerificationSent: メール検証送信イベント
- EmailVerified: メール検証完了イベント
- AccountLocked: アカウントロックイベント
- AccountUnlocked: アカウントアンロックイベント
- RoleAssigned: ロール付与イベント
- RoleRevoked: ロール削除イベント
- APIKeyCreated: APIキー作成イベント
- APIKeyRevoked: APIキー無効化イベント
- DeviceFingerprintMismatch: デバイスフィンガープリント不一致イベント
- ConcurrentLimitExceeded: 同時セッション数超過イベント

**Domain Services:**
- PasswordService: パスワード関連の処理を統括
- TokenService: JWT関連の処理を統括
- MFAService: 多要素認証の処理を統括
- WebAuthnService: WebAuthn認証の処理を統括
- AuthorizationService: 認可判定の処理を統括
- AuditService: 監査ログの記録と管理
- SecurityMonitoringService: セキュリティ監視と異常検知
- EmailVerificationService: メール検証処理
- APIKeyService: APIキー管理処理

**Repository Interfaces:**
- AuthCredentialRepository: AuthCredential集約の永続化インターフェース
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_auth_credential_repository.go -package=mocks
  ```
- SessionRepository: Session集約の永続化インターフェース
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_session_repository.go -package=mocks
  ```
- SigningKeyRepository: SigningKey集約の永続化インターフェース
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_signing_key_repository.go -package=mocks
  ```
- AuthorizationRepository: Authorization集約の永続化インターフェース
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_authorization_repository.go -package=mocks
  ```
- BotClientRepository: BotClient集約の永続化インターフェース
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_bot_client_repository.go -package=mocks
  ```
- RoleRepository: Role集約の永続化インターフェース
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_role_repository.go -package=mocks
  ```
- PolicyRepository: Policy集約の永続化インターフェース
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_policy_repository.go -package=mocks
  ```
- AuditLogRepository: AuditLog永続化インターフェース
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_audit_log_repository.go -package=mocks
  ```

#### Use Case Layer (ユースケース層)

**Command Use Cases (更新系):**
- AuthenticateCommandUseCase: パスワード認証処理
- ValidateTOTPCommandUseCase: TOTP検証処理
- RegisterPasskeyCommandUseCase: Passkey登録処理
- AuthenticatePasskeyCommandUseCase: Passkey認証処理
- RegisterTOTPCommandUseCase: TOTP登録処理
- DisableTOTPCommandUseCase: TOTP無効化処理
- CreateSessionCommandUseCase: セッション作成処理
- RevokeSessionCommandUseCase: セッション失効処理
- RefreshTokenCommandUseCase: トークンリフレッシュ処理
- AssignRoleCommandUseCase: ロール付与処理
- RevokeRoleCommandUseCase: ロール剥奪処理
- CreateBotClientCommandUseCase: Botクライアント作成処理
- RevokeBotClientCommandUseCase: Botクライアント無効化処理
- UpdateBotScopesCommandUseCase: Botスコープ更新処理
- CreatePolicyCommandUseCase: ポリシー作成処理
- UpdatePolicyCommandUseCase: ポリシー更新処理
- DeletePolicyCommandUseCase: ポリシー削除処理
- RequestPasswordResetCommandUseCase: パスワードリセット要求処理
- ResetPasswordCommandUseCase: パスワードリセット実行処理
- RotateSigningKeyCommandUseCase: 署名鍵ローテーション処理
- UnlockAccountCommandUseCase: アカウントロック解除処理
- TrustDeviceCommandUseCase: デバイス信頼設定処理
- RecordSecurityEventCommandUseCase: セキュリティイベント記録処理

**Query Use Cases (参照系):**
- ValidateTokenQueryUseCase: JWT検証処理
- CheckAuthorizationQueryUseCase: 認可判定処理
- GetUserRolesQueryUseCase: ユーザーロール取得処理
- GetUserPermissionsQueryUseCase: ユーザー権限取得処理
- GetSessionsQueryUseCase: セッション一覧取得処理
- GetSigningKeysQueryUseCase: 署名鍵一覧取得処理
- GetJWKSQueryUseCase: JWKS取得処理
- GetBotClientsQueryUseCase: Botクライアント一覧取得処理
- GetPoliciesQueryUseCase: ポリシー一覧取得処理
- GetAuditLogsQueryUseCase: 監査ログ取得処理
- GetSecurityEventsQueryUseCase: セキュリティイベント取得処理
- GetDeviceSessionsQueryUseCase: デバイスセッション取得処理
- GetAuthMethodsQueryUseCase: 認証方法取得処理
- GetAccountStatusQueryUseCase: アカウント状態取得処理
- GetRoleDefinitionQueryUseCase: ロール定義取得処理

**Query Service Interfaces:**
- AuthQueryService: 認証情報参照専用インターフェース
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_auth_query_service.go -package=mocks
  ```
- AuthorizationQueryService: 認可情報参照専用インターフェース
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_authorization_query_service.go -package=mocks
  ```
- SessionQueryService: セッション情報参照専用インターフェース
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_session_query_service.go -package=mocks
  ```

**External Service Interfaces:**
- UserService: avion-userとの連携インターフェース
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_user_service.go -package=mocks
  ```
- NotificationService: avion-notificationとの連携インターフェース
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_notification_service.go -package=mocks
  ```
- ModerationService: avion-moderationとの連携インターフェース（リスク評価取得）
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_moderation_service.go -package=mocks
  ```
- SystemAdminService: avion-system-adminとの連携インターフェース（監査ログ転送）
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_system_admin_service.go -package=mocks
  ```
- EventPublisher: イベント発行インターフェース
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_event_publisher.go -package=mocks
  ```

#### Infrastructure Layer (インフラストラクチャ層)

**Repository Implementations:**
- PostgresAuthCredentialRepository: PostgreSQL実装
- PostgresSessionRepository: PostgreSQL実装
- PostgresSigningKeyRepository: PostgreSQL実装
- PostgresAuthorizationRepository: PostgreSQL実装
- PostgresBotClientRepository: PostgreSQL実装
- PostgresRoleRepository: PostgreSQL実装
- PostgresPolicyRepository: PostgreSQL実装
- PostgresAuditLogRepository: PostgreSQL実装

**Cache Implementations:**
- RedisSessionCache: セッションキャッシュ
- RedisAuthorizationCache: 認可結果キャッシュ
- RedisRevokedTokenCache: 失効トークンキャッシュ
- RedisRateLimiter: レート制限実装

**External Service Implementations:**
- GRPCUserService: avion-userとのgRPC通信
- GRPCNotificationService: avion-notificationとのgRPC通信
- RedisEventPublisher: Redis Pub/Subでのイベント発行

**Security Implementations:**
- Argon2idPasswordHasher: パスワードハッシュ化
- RSATokenSigner: JWT署名
- WebAuthnCredentialManager: WebAuthn処理
- TOTPManager: TOTP処理

#### Handler Layer (ハンドラー層)

**gRPC Handlers:**
- AuthServiceHandler: 認証関連のgRPCハンドラー
- AuthorizationServiceHandler: 認可関連のgRPCハンドラー
- SessionServiceHandler: セッション関連のgRPCハンドラー
- BotServiceHandler: Bot管理のgRPCハンドラー

**HTTP Handlers:**
- OAuthHandler: OAuth 2.0エンドポイント
- JWKSHandler: JWKS提供エンドポイント
- HealthHandler: ヘルスチェックエンドポイント

### 7.2. データモデル

#### PostgreSQL

```sql
-- 認証情報
CREATE TABLE auth_credentials (
    user_id UUID PRIMARY KEY,
    password_hash TEXT,
    totp_secret TEXT,
    totp_enabled BOOLEAN DEFAULT false,
    totp_recovery_codes TEXT[],
    failed_attempts INT DEFAULT 0,
    locked_until TIMESTAMP,
    require_mfa BOOLEAN DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Passkey情報
CREATE TABLE passkey_credentials (
    credential_id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth_credentials(user_id) ON DELETE CASCADE,
    public_key BYTEA NOT NULL,
    sign_count BIGINT DEFAULT 0,
    device_name TEXT,
    aaguid BYTEA,
    backup_eligible BOOLEAN,
    backup_state BOOLEAN,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_used_at TIMESTAMP,
    INDEX idx_passkey_user_id (user_id)
);

-- セッション
CREATE TABLE sessions (
    session_id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    session_type VARCHAR(20) NOT NULL, -- 'human', 'bot', 'service'
    device_fingerprint TEXT,
    device_name TEXT,
    ip_address INET,
    user_agent TEXT,
    trust_level INT DEFAULT 50,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    revoked_at TIMESTAMP,
    last_active_at TIMESTAMP,
    INDEX idx_sessions_user_id (user_id),
    INDEX idx_sessions_expires_at (expires_at),
    INDEX idx_sessions_revoked_at (revoked_at)
);

-- リフレッシュトークン
CREATE TABLE refresh_tokens (
    token_id UUID PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    issued_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    rotation_count INT DEFAULT 0,
    parent_token_id UUID REFERENCES refresh_tokens(token_id),
    used_at TIMESTAMP,
    INDEX idx_refresh_tokens_session_id (session_id),
    INDEX idx_refresh_tokens_expires_at (expires_at)
);

-- JWT署名鍵
CREATE TABLE signing_keys (
    key_id TEXT PRIMARY KEY,
    private_key_encrypted BYTEA NOT NULL,
    public_key BYTEA NOT NULL,
    algorithm VARCHAR(10) NOT NULL DEFAULT 'RS256',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    rotated_at TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT false,
    INDEX idx_signing_keys_active (is_active),
    INDEX idx_signing_keys_expires_at (expires_at)
);

-- ユーザー権限
CREATE TABLE authorizations (
    user_id UUID PRIMARY KEY,
    default_role_id VARCHAR(50) NOT NULL DEFAULT 'user',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ロール定義
CREATE TABLE roles (
    role_id VARCHAR(50) PRIMARY KEY,
    role_name VARCHAR(100) NOT NULL,
    description TEXT,
    parent_role_id VARCHAR(50) REFERENCES roles(role_id),
    is_system BOOLEAN DEFAULT false,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ユーザーロール割り当て
CREATE TABLE user_roles (
    user_id UUID REFERENCES authorizations(user_id) ON DELETE CASCADE,
    role_id VARCHAR(50) REFERENCES roles(role_id) ON DELETE CASCADE,
    assigned_by UUID NOT NULL,
    assigned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    reason TEXT,
    PRIMARY KEY (user_id, role_id),
    INDEX idx_user_roles_expires_at (expires_at)
);

-- スコープ定義
CREATE TABLE scopes (
    scope_id VARCHAR(100) PRIMARY KEY,
    resource VARCHAR(50) NOT NULL,
    action VARCHAR(50) NOT NULL,
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_scopes_resource_action (resource, action)
);

-- ロール・スコープマッピング
CREATE TABLE role_scopes (
    role_id VARCHAR(50) REFERENCES roles(role_id) ON DELETE CASCADE,
    scope_id VARCHAR(100) REFERENCES scopes(scope_id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, scope_id)
);

-- Botクライアント
CREATE TABLE bot_clients (
    client_id VARCHAR(100) PRIMARY KEY,
    client_secret_hash TEXT NOT NULL,
    bot_user_id UUID NOT NULL,
    owner_user_id UUID NOT NULL,
    client_name VARCHAR(200) NOT NULL,
    client_description TEXT,
    redirect_uris TEXT[],
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    revoked_at TIMESTAMP,
    expires_at TIMESTAMP,
    INDEX idx_bot_clients_owner (owner_user_id),
    INDEX idx_bot_clients_bot_user (bot_user_id)
);

-- Botクライアントスコープ
CREATE TABLE bot_client_scopes (
    client_id VARCHAR(100) REFERENCES bot_clients(client_id) ON DELETE CASCADE,
    scope_id VARCHAR(100) REFERENCES scopes(scope_id) ON DELETE CASCADE,
    granted_by UUID NOT NULL,
    granted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (client_id, scope_id)
);

-- 認可ポリシー
CREATE TABLE policies (
    policy_id UUID PRIMARY KEY,
    policy_name VARCHAR(200) NOT NULL UNIQUE,
    effect VARCHAR(20) NOT NULL CHECK (effect IN ('allow', 'deny')),
    resources TEXT[] NOT NULL,
    actions TEXT[] NOT NULL,
    conditions JSONB,
    priority INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_policies_priority (priority),
    INDEX idx_policies_active (is_active)
);

-- ポリシールール
CREATE TABLE policy_rules (
    rule_id UUID PRIMARY KEY,
    policy_id UUID REFERENCES policies(policy_id) ON DELETE CASCADE,
    effect VARCHAR(20) NOT NULL CHECK (effect IN ('allow', 'deny')),
    resource_pattern TEXT NOT NULL,
    action_pattern TEXT NOT NULL,
    conditions JSONB,
    rule_order INT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_policy_rules_order (policy_id, rule_order)
);

-- 監査ログ
CREATE TABLE audit_logs (
    log_id UUID PRIMARY KEY,
    user_id UUID,
    action VARCHAR(100) NOT NULL,
    resource TEXT,
    result VARCHAR(20) NOT NULL,
    ip_address INET,
    user_agent TEXT,
    details JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_audit_logs_user_id (user_id),
    INDEX idx_audit_logs_action (action),
    INDEX idx_audit_logs_created_at (created_at)
);

-- セキュリティイベント
CREATE TABLE security_events (
    event_id UUID PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL,
    user_id UUID,
    ip_address INET,
    details JSONB,
    risk_score INT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_security_events_user_id (user_id),
    INDEX idx_security_events_type (event_type),
    INDEX idx_security_events_created_at (created_at)
);

-- デバイス信頼情報
CREATE TABLE trusted_devices (
    device_id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    device_fingerprint TEXT NOT NULL,
    device_name TEXT,
    trust_level INT DEFAULT 50,
    last_seen_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    UNIQUE KEY uk_trusted_devices (user_id, device_fingerprint),
    INDEX idx_trusted_devices_expires_at (expires_at)
);

-- 認証試行履歴
CREATE TABLE authentication_attempts (
    attempt_id UUID PRIMARY KEY,
    user_id UUID,
    auth_method VARCHAR(50) NOT NULL, -- 'password', 'passkey', 'totp', 'api_key'
    success BOOLEAN NOT NULL,
    ip_address INET,
    user_agent TEXT,
    device_fingerprint TEXT,
    error_code VARCHAR(50),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_auth_attempts_user_id (user_id),
    INDEX idx_auth_attempts_created_at (created_at),
    INDEX idx_auth_attempts_success (success)
);

-- APIキー管理
CREATE TABLE api_keys (
    key_id UUID PRIMARY KEY,
    key_hash TEXT NOT NULL UNIQUE,
    service_account_id UUID NOT NULL,
    key_name VARCHAR(200) NOT NULL,
    last_used_at TIMESTAMP,
    expires_at TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    revoked_at TIMESTAMP,
    INDEX idx_api_keys_service_account (service_account_id),
    INDEX idx_api_keys_expires_at (expires_at)
);

-- サービスアカウント
CREATE TABLE service_accounts (
    account_id UUID PRIMARY KEY,
    account_name VARCHAR(200) NOT NULL UNIQUE,
    owner_user_id UUID NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_service_accounts_owner (owner_user_id)
);

-- メール検証トークン
CREATE TABLE email_verifications (
    token_id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    email VARCHAR(255) NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    verification_type VARCHAR(50) NOT NULL, -- 'registration', 'password_reset', 'email_change'
    expires_at TIMESTAMP NOT NULL,
    verified_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_email_verifications_user_id (user_id),
    INDEX idx_email_verifications_expires_at (expires_at)
);
```

#### Redis キャッシュ構造

```
# セッション情報
session:{session_id} -> {
    user_id: UUID,
    session_type: string,
    scopes: string[],
    roles: string[],
    expires_at: timestamp,
    device_info: {
        fingerprint: string,
        ip_address: string,
        user_agent: string,
        trust_level: int
    }
}
TTL: セッションの有効期限まで

# 認可結果キャッシュ
authz:{user_id}:{resource}:{action} -> {
    allowed: boolean,
    reason: string,
    evaluated_policies: string[],
    cached_at: timestamp
}
TTL: 5分

# 失効JWTリスト（ブラックリスト）
revoked_jwt:{jti} -> 1
TTL: JWTの有効期限まで

# ユーザーロール情報
user_roles:{user_id} -> {
    roles: [{
        role_id: string,
        role_name: string,
        expires_at: timestamp
    }],
    scopes: string[],
    cached_at: timestamp
}
TTL: 10分

# Bot認証情報
bot_client:{client_id} -> {
    client_secret_hash: string,
    bot_user_id: UUID,
    owner_user_id: UUID,
    scopes: string[],
    is_active: boolean
}
TTL: 30分

# レート制限（認証試行）
rate_limit:auth:{ip_address} -> count
TTL: 1分

# レート制限（API呼び出し）
rate_limit:api:{user_id}:{endpoint} -> count
TTL: 1分

# パスワードリセットトークン
password_reset:{token} -> {
    user_id: UUID,
    expires_at: timestamp,
    used: boolean
}
TTL: 1時間

# 一時セッション（MFA待ち）
temp_session:{temp_id} -> {
    user_id: UUID,
    auth_method: string,
    mfa_required: boolean,
    expires_at: timestamp
}
TTL: 5分

# TOTP使用済みコード（再利用防止）
totp_used:{user_id}:{code} -> 1
TTL: 90秒

# デバイス信頼情報
device_trust:{user_id}:{device_fingerprint} -> {
    trust_level: int,
    last_seen: timestamp,
    location: string
}
TTL: 30日
```

## データベースマイグレーション

このサービスでは、[共通マイグレーション戦略](../common/database-migration-strategy.md)に従って、Gooseを使用したマイグレーション管理を行います。

### マイグレーション戦略

- **ツール**: Goose v3
- **ディレクトリ**: `./migrations/`
- **命名規則**: `[sequence_number]_[description].sql`
- **実行方法**: `make migrate-up` / `make migrate-down`

### avion-auth固有の考慮事項

- **セキュリティデータ保護**: 認証情報やセッション情報の移行では、暗号化状態を維持
- **セッション無効化**: スキーマ変更時は影響を受けるセッションを適切に無効化
- **監査ログ保持**: 監査要件を満たすため、ログデータの完全性を保証
- **多段階移行**: パスワードハッシュアルゴリズム変更など、重要な変更は段階的に実施
- **ダウンタイム最小化**: 認証機能は他サービスの依存関係が高いため、ゼロダウンタイム移行を徹底

### 標準テンプレート参照

マイグレーションファイル作成時は[マイグレーション設定テンプレート](../templates/migration-setup-template.md)を参照してください。

### 7.3. API設計

#### gRPC API

```protobuf
syntax = "proto3";
package avion.auth.v1;

service AuthService {
  // 認証
  rpc Authenticate(AuthenticateRequest) returns (AuthenticateResponse);
  rpc ValidateTOTP(ValidateTOTPRequest) returns (ValidateTOTPResponse);
  rpc RegisterPasskey(RegisterPasskeyRequest) returns (RegisterPasskeyResponse);
  rpc AuthenticatePasskey(AuthenticatePasskeyRequest) returns (AuthenticatePasskeyResponse);
  rpc RegisterTOTP(RegisterTOTPRequest) returns (RegisterTOTPResponse);
  rpc DisableTOTP(DisableTOTPRequest) returns (DisableTOTPResponse);
  
  // セッション管理
  rpc ValidateToken(ValidateTokenRequest) returns (ValidateTokenResponse);
  rpc RevokeSession(RevokeSessionRequest) returns (RevokeSessionResponse);
  rpc RefreshToken(RefreshTokenRequest) returns (RefreshTokenResponse);
  rpc GetSessions(GetSessionsRequest) returns (GetSessionsResponse);
  
  // 認可
  rpc CheckAuthorization(CheckAuthorizationRequest) returns (CheckAuthorizationResponse);
  rpc GetUserRoles(GetUserRolesRequest) returns (GetUserRolesResponse);
  rpc AssignRole(AssignRoleRequest) returns (AssignRoleResponse);
  rpc RevokeRole(RevokeRoleRequest) returns (RevokeRoleResponse);
  
  // Bot管理
  rpc CreateBotClient(CreateBotClientRequest) returns (CreateBotClientResponse);
  rpc RevokeBotClient(RevokeBotClientRequest) returns (RevokeBotClientResponse);
  rpc UpdateBotScopes(UpdateBotScopesRequest) returns (UpdateBotScopesResponse);
  rpc GetBotClients(GetBotClientsRequest) returns (GetBotClientsResponse);
  
  // ポリシー管理
  rpc CreatePolicy(CreatePolicyRequest) returns (CreatePolicyResponse);
  rpc UpdatePolicy(UpdatePolicyRequest) returns (UpdatePolicyResponse);
  rpc DeletePolicy(DeletePolicyRequest) returns (DeletePolicyResponse);
  rpc GetPolicies(GetPoliciesRequest) returns (GetPoliciesResponse);
  
  // セキュリティ
  rpc RequestPasswordReset(RequestPasswordResetRequest) returns (RequestPasswordResetResponse);
  rpc ResetPassword(ResetPasswordRequest) returns (ResetPasswordResponse);
  rpc UnlockAccount(UnlockAccountRequest) returns (UnlockAccountResponse);
  rpc TrustDevice(TrustDeviceRequest) returns (TrustDeviceResponse);
  
  // 監査
  rpc GetAuditLogs(GetAuditLogsRequest) returns (GetAuditLogsResponse);
  rpc GetSecurityEvents(GetSecurityEventsRequest) returns (GetSecurityEventsResponse);
}
```

#### HTTP API

```
# OAuth 2.0 Token Endpoint
POST /oauth/token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials&
client_id={client_id}&
client_secret={client_secret}&
scope={requested_scopes}

Response:
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 900,
  "scope": "drop:write timeline:read"
}

# JWKS Endpoint
GET /.well-known/jwks.json

Response:
{
  "keys": [
    {
      "kty": "RSA",
      "use": "sig",
      "kid": "2024-01-key",
      "alg": "RS256",
      "n": "...",
      "e": "AQAB"
    }
  ]
}

# Health Check
GET /health

Response:
{
  "status": "healthy",
  "version": "1.0.0",
  "timestamp": "2024-01-01T00:00:00Z"
}

# Readiness Check
GET /ready

Response:
{
  "ready": true,
  "dependencies": {
    "database": "healthy",
    "redis": "healthy"
  }
}
```

### 7.4. イベント設計

#### 発行イベント (Redis Pub/Sub)

```json
// 認証成功イベント
{
  "event_type": "auth.login_success",
  "event_id": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2024-01-01T00:00:00Z",
  "data": {
    "user_id": "123e4567-e89b-12d3-a456-426614174000",
    "session_id": "987f6543-e21c-98d7-b654-321098765432",
    "auth_method": "password",
    "ip_address": "192.168.1.1",
    "device_fingerprint": "abc123..."
  }
}

// 認証失敗イベント
{
  "event_type": "auth.login_failure",
  "event_id": "550e8400-e29b-41d4-a716-446655440001",
  "timestamp": "2024-01-01T00:00:01Z",
  "data": {
    "user_id": "123e4567-e89b-12d3-a456-426614174000",
    "reason": "invalid_password",
    "ip_address": "192.168.1.1",
    "failed_attempts": 3
  }
}

// アカウントロックイベント
{
  "event_type": "auth.account_locked",
  "event_id": "550e8400-e29b-41d4-a716-446655440002",
  "timestamp": "2024-01-01T00:00:02Z",
  "data": {
    "user_id": "123e4567-e89b-12d3-a456-426614174000",
    "locked_until": "2024-01-01T00:15:02Z",
    "reason": "too_many_attempts"
  }
}

// ロール変更イベント
{
  "event_type": "authz.role_changed",
  "event_id": "550e8400-e29b-41d4-a716-446655440003",
  "timestamp": "2024-01-01T00:00:03Z",
  "data": {
    "user_id": "123e4567-e89b-12d3-a456-426614174000",
    "action": "grant",
    "role_id": "moderator",
    "granted_by": "admin-user-id",
    "expires_at": null
  }
}

// セッション失効イベント
{
  "event_type": "auth.session_revoked",
  "event_id": "550e8400-e29b-41d4-a716-446655440004",
  "timestamp": "2024-01-01T00:00:04Z",
  "data": {
    "session_id": "987f6543-e21c-98d7-b654-321098765432",
    "user_id": "123e4567-e89b-12d3-a456-426614174000",
    "reason": "user_logout"
  }
}

// 異常ログイン検知イベント
{
  "event_type": "security.anomalous_login",
  "event_id": "550e8400-e29b-41d4-a716-446655440005",
  "timestamp": "2024-01-01T00:00:05Z",
  "data": {
    "user_id": "123e4567-e89b-12d3-a456-426614174000",
    "risk_score": 85,
    "indicators": ["new_location", "new_device"],
    "ip_address": "192.168.1.1",
    "location": "Tokyo, Japan"
  }
}
```

### 7.5. セキュリティ設計

#### 認証セキュリティ
- **パスワード:** Argon2id (memory=64MB, iterations=3, parallelism=2)
- **Passkey:** WebAuthn Level 2準拠、FIDO2対応
- **TOTP:** SHA-256、6桁、30秒時間窓、±1ドリフト許容
- **セッションCookie:** Secure, HttpOnly, SameSite=Strict

#### JWT設計
```json
// Header
{
  "alg": "RS256",
  "typ": "JWT",
  "kid": "2024-01-key"
}

// Payload (Claims)
{
  "sub": "123e4567-e89b-12d3-a456-426614174000",  // User ID
  "iat": 1704067200,                               // Issued At
  "exp": 1704070800,                               // Expires At (1 hour)
  "jti": "987f6543-e21c-98d7-b654-321098765432",  // Session ID
  "type": "human",                                 // Session Type
  "scopes": ["drop:write", "timeline:read"],       // Permissions
  "roles": ["user", "moderator"],                  // Roles
  "device": {
    "fingerprint": "abc123...",
    "trust_level": 75
  }
}
```

#### レート制限
- **認証試行:** 5回/分/IP、5回失敗で15分ロック
- **トークン検証:** 1000回/分/サービス
- **認可判定:** 10000回/分/サービス
- **パスワードリセット:** 3回/時/ユーザー

#### 暗号化
- **保存時暗号化:** AES-256-GCM（秘密鍵、TOTPシークレット）
- **通信暗号化:** TLS 1.3必須
- **鍵管理:** KMS統合、定期ローテーション

### 7.6. パフォーマンス最適化

#### 並行処理
- **Goroutineプール:** 認証処理の並列化（最大100）
- **非同期処理:** イベント発行、監査ログ記録
- **バッチ処理:** 認可判定の一括処理（最大100件）

#### キャッシュ戦略
- **多層キャッシュ:** インメモリ（LRU） → Redis → PostgreSQL
- **プリロード:** 頻繁にアクセスされるロール情報
- **TTL管理:** 用途別の適切な有効期限設定

#### データベース最適化
- **コネクションプール:** 最大100接続、アイドル10接続
- **インデックス:** 検索頻度の高いカラムに設定
- **パーティショニング:** 監査ログの月次パーティション

### 7.7. 監視・運用

#### メトリクス (Prometheus形式)
```
# 認証関連
auth_attempts_total{result="success|failure", method="password|passkey|totp"}
auth_duration_seconds{method="password|passkey|totp", quantile="0.5|0.9|0.99"}

# 認可関連
authz_checks_total{result="allow|deny", cache_hit="true|false"}
authz_check_duration_seconds{quantile="0.5|0.9|0.99"}

# セッション関連
active_sessions_gauge{type="human|bot"}
jwt_validations_total{result="valid|invalid|expired"}

# エラー関連
errors_total{type="auth|authz|system", code="codes.Unauthenticated|codes.PermissionDenied|codes.Internal"}
```

> **注意:** エラーコードは[共通エラーコード標準](../common/errors/error-codes.md)に準拠します。このサービスではプレフィックス `ATH` を使用します。

### エラーコード体系

本サービスは、Avionプラットフォーム標準のエラーコード体系に準拠します。

- **命名規則**: `[SERVICE]_[LAYER]_[ERROR_TYPE]`形式
- **エラーカタログ**: [error-catalog.md](./error-catalog.md)
- **実装ガイド**: [共通エラー実装ガイド](../common/errors/implementation-guide.md)
- **標準仕様**: [エラーコード標準化ガイドライン](../common/errors/error-standards.md)

詳細なエラーコード定義とマッピングについては、上記のドキュメントを参照してください。

#### ログ形式 (構造化ログ)
```json
{
  "timestamp": "2024-01-01T00:00:00Z",
  "level": "INFO",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "service": "avion-auth",
  "user_id": "123e4567-e89b-12d3-a456-426614174000",
  "message": "Authentication successful",
  "details": {
    "method": "password",
    "ip_address": "192.168.1.1",
    "duration_ms": 150
  }
}
```

#### アラート設定
- **認証失敗率:** 5分間で30%超過
- **レスポンスタイム:** p99が1秒超過
- **エラー率:** 5分間で1%超過
- **キャッシュヒット率:** 50%未満
- **署名鍵期限:** 7日前に通知

### 7.8. 実装計画

#### フェーズ1: 基本機能（Sprint 1-2）
- パスワード認証
- JWT発行・検証
- 基本的なロールベース認可
- セッション管理
- 監査ログ

#### フェーズ2: 高度な認証（Sprint 3-4）
- Passkey（WebAuthn）対応
- TOTP対応
- デバイス信頼管理
- 異常ログイン検知

#### フェーズ3: 高度な認可（Sprint 5-6）
- ポリシーベース認可
- 動的スコープ管理
- Bot OAuth 2.0対応
- 詳細な権限管理

#### フェーズ4: 運用機能（Sprint 7-8）
- 管理API
- 詳細な監視・メトリクス
- パフォーマンスチューニング
- ドキュメント整備

## 8. テスト実装

テスト実装の詳細については、[共通テスト戦略](../common/testing-strategy.md)に従って実装します。

### 認証サービス特化のテスト要件

#### セキュリティテスト
- ペネトレーションテスト
- OWASP Top 10チェック
- 暗号化強度検証
- JWT署名検証テスト
- セッション固定攻撃防御テスト

#### パフォーマンステスト
- 負荷テスト（10,000 req/s）
- 認証レイテンシ: p50 < 100ms
- 認可レイテンシ: p50 < 20ms
- メモリリーク検出

#### 統合テスト重点項目
- パスキー認証フロー
- TOTP認証フロー
- OAuth 2.0フロー
- セッションライフサイクル
- Redis障害時のフォールバック


## 9. 非機能要件

### 可用性
- **SLA:** 99.99%（月間ダウンタイム4.32分以内）
- **RTO:** 1分以内
- **RPO:** 1分以内

### パフォーマンス
- **認証処理:** p50 < 100ms、p99 < 300ms
- **認可判定:** p50 < 20ms、p99 < 100ms
- **JWT検証:** p50 < 5ms、p99 < 20ms
- **スループット:** 10,000 req/s

### セキュリティ
- **暗号化:** AES-256-GCM（保存時）、TLS 1.3（通信時）
- **監査:** 全操作の記録、90日保持
- **コンプライアンス:** GDPR、個人情報保護法準拠

### スケーラビリティ
- **水平スケール:** 3-10レプリカ
- **自動スケール:** CPU 70%閾値
- **データ分割:** 将来的なシャーディング対応

## 10. リスクと対策

### リスク1: JWTの盗用
**対策:**
- 短い有効期限（1時間）
- デバイスフィンガープリント検証
- 異常検知システム

### リスク2: ブルートフォース攻撃
**対策:**
- レート制限
- アカウントロック
- CAPTCHA（将来実装）

### リスク3: 署名鍵の漏洩
**対策:**
- KMS統合
- 定期ローテーション
- 監査ログ

### リスク4: サービス停止
**対策:**
- 複数レプリカ
- 自動フェイルオーバー
- サーキットブレーカー

## 11. 今後の拡張

- 外部IdP連携（Google、GitHub、Twitter）
- OpenID Connect対応
- 生体認証（Face ID、指紋）
- ゼロトラストアーキテクチャ
- AIベースの異常検知
- ブロックチェーン統合（将来検討）

## 12. サービス固有のテスト戦略

このサービスでは、[共通テスト戦略](../common/testing-strategy.md)に加えて、以下のサービス固有のテスト要件を実装します。

### 12.1 認証・認可固有のテスト要件

#### 12.1.1 認証フローのモック戦略

```go
// WebAuthn/Passkeyのモック
type MockWebAuthnClient struct {
    mock.Mock
}

func (m *MockWebAuthnClient) BeginRegistration(ctx context.Context, user *User) (*protocol.CredentialCreation, error) {
    args := m.Called(ctx, user)
    return args.Get(0).(*protocol.CredentialCreation), args.Error(1)
}

func (m *MockWebAuthnClient) FinishRegistration(ctx context.Context, user *User, response *protocol.ParsedCredentialCreationData) (*Credential, error) {
    args := m.Called(ctx, user, response)
    return args.Get(0).(*Credential), args.Error(1)
}

// JWTトークン生成/検証のテスト
func TestJWTService_GenerateAndValidate(t *testing.T) {
    fixedTime := time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC)
    ctx := ctxtime.WithTime(context.Background(), fixedTime)
    
    tests := []struct {
        name      string
        userID    string
        scopes    []string
        expiresIn time.Duration
        wantErr   bool
    }{
        {
            name:      "正常系: アクセストークン生成",
            userID:    "user123",
            scopes:    []string{"read", "write"},
            expiresIn: 15 * time.Minute,
            wantErr:   false,
        },
        {
            name:      "正常系: リフレッシュトークン生成",
            userID:    "user123",
            scopes:    []string{"refresh"},
            expiresIn: 7 * 24 * time.Hour,
            wantErr:   false,
        },
        {
            name:      "異常系: 期限切れトークン",
            userID:    "user123",
            scopes:    []string{"read"},
            expiresIn: -1 * time.Hour, // 過去の時刻
            wantErr:   true,
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // テスト実装
        })
    }
}
```

#### 12.1.2 MFA（多要素認証）のテスト

```go
// TOTPのテスト
func TestTOTPService_GenerateAndVerify(t *testing.T) {
    // 固定時刻でのTOTP生成
    fixedTime := time.Date(2024, 1, 1, 12, 0, 0, 0, time.UTC)
    ctx := ctxtime.WithTime(context.Background(), fixedTime)
    
    secret := "JBSWY3DPEHPK3PXP" // テスト用固定シークレット
    
    tests := []struct {
        name     string
        code     string
        window   int
        expected bool
    }{
        {
            name:     "正常系: 現在のコード",
            code:     generateTOTPCode(secret, fixedTime),
            window:   1,
            expected: true,
        },
        {
            name:     "正常系: 1つ前のコード",
            code:     generateTOTPCode(secret, fixedTime.Add(-30*time.Second)),
            window:   1,
            expected: true,
        },
        {
            name:     "異常系: 無効なコード",
            code:     "000000",
            window:   1,
            expected: false,
        },
        {
            name:     "異常系: 期限切れコード",
            code:     generateTOTPCode(secret, fixedTime.Add(-90*time.Second)),
            window:   1,
            expected: false,
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // テスト実装
        })
    }
}
```

### 12.2 ドメイン固有のテストシナリオ

#### 12.2.1 クリティカルパステスト（95%カバレッジ必須）

```go
// 認証フロー全体のテスト
func TestAuthenticationFlow_Complete(t *testing.T) {
    tests := []struct {
        name     string
        scenario func(t *testing.T, svc *AuthService)
    }{
        {
            name: "パスワード認証 → MFA → JWT発行",
            scenario: func(t *testing.T, svc *AuthService) {
                // 1. パスワード認証
                session, err := svc.AuthenticateWithPassword(ctx, "user@example.com", "password123")
                require.NoError(t, err)
                require.Equal(t, SessionStateMFARequired, session.State)
                
                // 2. TOTP検証
                err = svc.VerifyTOTP(ctx, session.ID, "123456")
                require.NoError(t, err)
                
                // 3. JWT発行
                tokens, err := svc.IssueTokens(ctx, session.ID)
                require.NoError(t, err)
                require.NotEmpty(t, tokens.AccessToken)
                require.NotEmpty(t, tokens.RefreshToken)
            },
        },
        {
            name: "Passkey認証（MFAスキップ）",
            scenario: func(t *testing.T, svc *AuthService) {
                // Passkeyは inherently MFA
                tokens, err := svc.AuthenticateWithPasskey(ctx, passkeyCredential)
                require.NoError(t, err)
                require.NotEmpty(t, tokens.AccessToken)
            },
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Setup
            svc := setupTestAuthService(t)
            defer teardownTestAuthService(t, svc)
            
            // Execute
            tt.scenario(t, svc)
        })
    }
}

// セッション管理の不変条件テスト
func TestSession_Invariants(t *testing.T) {
    tests := []struct {
        name      string
        setup     func() *Session
        invariant func(*Session) error
    }{
        {
            name: "セッションは必ず有効期限を持つ",
            setup: func() *Session {
                return &Session{
                    ID:        "session123",
                    UserID:    "user123",
                    CreatedAt: time.Now(),
                    // ExpiresAt を意図的に設定しない
                }
            },
            invariant: func(s *Session) error {
                if s.ExpiresAt.IsZero() {
                    return errors.New("session must have expiration")
                }
                return nil
            },
        },
        {
            name: "MFA必須ユーザーは必ずMFAステップを経る",
            setup: func() *Session {
                return &Session{
                    ID:          "session123",
                    UserID:      "user123",
                    RequiresMFA: true,
                    State:       SessionStateAuthenticated, // MFAをスキップ
                }
            },
            invariant: func(s *Session) error {
                if s.RequiresMFA && s.State == SessionStateAuthenticated && !s.MFAVerified {
                    return errors.New("MFA required but not verified")
                }
                return nil
            },
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            session := tt.setup()
            err := tt.invariant(session)
            require.Error(t, err, "Invariant should be violated")
        })
    }
}
```

### 12.3 統合テストシナリオ

#### 12.3.1 Redis統合テスト

```go
// Redisセッションストアのテスト
func TestRedisSessionStore_Integration(t *testing.T) {
    if testing.Short() {
        t.Skip("Skipping integration test in short mode")
    }
    
    ctx := context.Background()
    
    // Redisコンテナ起動
    redis, err := testcontainers.GenericContainer(ctx, testcontainers.GenericContainerRequest{
        ContainerRequest: testcontainers.ContainerRequest{
            Image:        "redis:7-alpine",
            ExposedPorts: []string{"6379/tcp"},
            WaitingFor:   wait.ForListeningPort("6379/tcp"),
        },
        Started: true,
    })
    require.NoError(t, err)
    defer redis.Terminate(ctx)
    
    // Redis接続
    endpoint, err := redis.Endpoint(ctx, "")
    require.NoError(t, err)
    
    client := redis.NewClient(&redis.Options{
        Addr: endpoint,
    })
    defer client.Close()
    
    store := NewRedisSessionStore(client)
    
    t.Run("セッション作成と取得", func(t *testing.T) {
        session := &Session{
            ID:        "test-session",
            UserID:    "user123",
            ExpiresAt: time.Now().Add(15 * time.Minute),
        }
        
        err := store.Save(ctx, session)
        require.NoError(t, err)
        
        retrieved, err := store.Get(ctx, session.ID)
        require.NoError(t, err)
        require.Equal(t, session.UserID, retrieved.UserID)
    })
    
    t.Run("セッション無効化", func(t *testing.T) {
        err := store.Revoke(ctx, "test-session")
        require.NoError(t, err)
        
        _, err = store.Get(ctx, "test-session")
        require.ErrorIs(t, err, ErrSessionNotFound)
    })
}
```

### 12.4 パフォーマンステスト基準

#### 12.4.1 認証処理のベンチマーク

```go
// Argon2idパスワードハッシュのベンチマーク
func BenchmarkPasswordHash(b *testing.B) {
    password := "TestPassword123!@#"
    
    b.Run("Argon2id-Default", func(b *testing.B) {
        for i := 0; i < b.N; i++ {
            _ = HashPassword(password, DefaultArgon2Params)
        }
    })
    
    b.Run("Argon2id-HighSecurity", func(b *testing.B) {
        for i := 0; i < b.N; i++ {
            _ = HashPassword(password, HighSecurityArgon2Params)
        }
    })
}

// JWT生成/検証のベンチマーク
func BenchmarkJWT(b *testing.B) {
    svc := NewJWTService(testPrivateKey)
    claims := &JWTClaims{
        UserID: "user123",
        Scopes: []string{"read", "write"},
    }
    
    b.Run("Generate-RS256", func(b *testing.B) {
        for i := 0; i < b.N; i++ {
            _, _ = svc.Generate(claims)
        }
    })
    
    token, _ := svc.Generate(claims)
    
    b.Run("Validate-RS256", func(b *testing.B) {
        for i := 0; i < b.N; i++ {
            _, _ = svc.Validate(token)
        }
    })
}
```

#### 12.4.2 負荷テストシナリオ

| シナリオ | 同時接続数 | RPS | 成功率目標 | レイテンシ目標 |
|---------|----------|-----|-----------|--------------|
| ログイン通常負荷 | 100 | 500 | 99.9% | p50 < 100ms, p99 < 500ms |
| ログインピーク | 1000 | 2000 | 99.5% | p50 < 200ms, p99 < 1000ms |
| トークン検証 | 5000 | 10000 | 99.99% | p50 < 20ms, p99 < 100ms |
| MFA検証 | 500 | 1000 | 99.9% | p50 < 50ms, p99 < 200ms |

### 12.5 セキュリティテスト

#### 12.5.1 認証バイパステスト

```go
// 認証バイパスの試行テスト
func TestSecurity_AuthenticationBypass(t *testing.T) {
    tests := []struct {
        name    string
        attempt func(*AuthService) error
    }{
        {
            name: "空のJWTトークン",
            attempt: func(svc *AuthService) error {
                _, err := svc.ValidateToken(ctx, "")
                return err
            },
        },
        {
            name: "改竄されたJWT",
            attempt: func(svc *AuthService) error {
                token := generateValidToken()
                tampered := token[:len(token)-10] + "tampered"
                _, err := svc.ValidateToken(ctx, tampered)
                return err
            },
        },
        {
            name: "SQLインジェクション試行",
            attempt: func(svc *AuthService) error {
                _, err := svc.AuthenticateWithPassword(ctx, 
                    "admin' OR '1'='1", "password")
                return err
            },
        },
        {
            name: "ブルートフォース保護",
            attempt: func(svc *AuthService) error {
                for i := 0; i < 10; i++ {
                    svc.AuthenticateWithPassword(ctx, 
                        "user@example.com", fmt.Sprintf("wrong%d", i))
                }
                // 11回目はロックされるべき
                _, err := svc.AuthenticateWithPassword(ctx, 
                    "user@example.com", "correct")
                return err
            },
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            svc := setupTestAuthService(t)
            err := tt.attempt(svc)
            require.Error(t, err, "Security bypass should fail")
        })
    }
}
```

### 12.6 エラーハンドリングテスト

#### 12.6.1 障害シナリオテスト

```go
// 外部サービス障害のテスト
func TestChaos_ExternalServiceFailure(t *testing.T) {
    tests := []struct {
        name     string
        failure  func(*AuthService)
        expected error
    }{
        {
            name: "Redis接続障害",
            failure: func(svc *AuthService) {
                svc.sessionStore.(*RedisSessionStore).client.Close()
            },
            expected: ErrSessionStoreUnavailable,
        },
        {
            name: "KMS署名鍵取得失敗",
            failure: func(svc *AuthService) {
                svc.kmsClient.(*MockKMSClient).
                    On("GetSigningKey", mock.Anything).
                    Return(nil, errors.New("KMS unavailable"))
            },
            expected: ErrSigningKeyUnavailable,
        },
        {
            name: "データベース接続障害",
            failure: func(svc *AuthService) {
                svc.db.Close()
            },
            expected: ErrDatabaseUnavailable,
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            svc := setupTestAuthService(t)
            
            // 障害を注入
            tt.failure(svc)
            
            // グレースフルデグレード確認
            _, err := svc.AuthenticateWithPassword(ctx, 
                "user@example.com", "password")
            require.ErrorIs(t, err, tt.expected)
            
            // サーキットブレーカー確認
            require.True(t, svc.circuitBreaker.IsOpen())
        })
    }
}
```

### 12.7 E2Eテストシナリオ

このサービス固有のE2Eテストシナリオ：

1. **新規ユーザー登録からログインまで**
   - 前提条件: 未登録のメールアドレス
   - 実行手順:
     1. パスワードでユーザー登録
     2. メール確認
     3. TOTP設定
     4. ログイン試行
     5. MFA検証
     6. アクセストークン取得
   - 期待結果: 有効なJWTトークンペア取得

2. **Passkey登録と認証**
   - 前提条件: 既存ユーザー、WebAuthn対応ブラウザ
   - 実行手順:
     1. パスワードでログイン
     2. Passkey登録開始
     3. 認証器レスポンス送信
     4. Passkey登録完了
     5. ログアウト
     6. Passkeyでログイン
   - 期待結果: MFAスキップでトークン取得

3. **アカウントロックと回復**
   - 前提条件: アクティブなユーザーアカウント
   - 実行手順:
     1. 5回連続で誤パスワード入力
     2. アカウントロック確認
     3. パスワードリセットリクエスト
     4. リセットトークンで新パスワード設定
     5. 新パスワードでログイン
   - 期待結果: アカウント回復成功

### 12.8 テストデータ管理

#### 12.8.1 認証テスト用フィクスチャ

```go
// テスト用ユーザーフィクスチャ
func NewTestUser(t *testing.T, opts ...TestUserOption) *User {
    t.Helper()
    
    user := &User{
        ID:           uuid.New().String(),
        Email:        fmt.Sprintf("test-%s@example.com", uuid.New()),
        PasswordHash: HashPassword("TestPassword123!", DefaultArgon2Params),
        MFAEnabled:   false,
        CreatedAt:    time.Now(),
    }
    
    for _, opt := range opts {
        opt(user)
    }
    
    return user
}

// MFA有効ユーザー
func WithMFAEnabled(secret string) TestUserOption {
    return func(u *User) {
        u.MFAEnabled = true
        u.TOTPSecret = secret
    }
}

// Passkey登録済みユーザー
func WithPasskey(credentialID []byte) TestUserOption {
    return func(u *User) {
        u.PasskeyCredentials = append(u.PasskeyCredentials, 
            &PasskeyCredential{
                ID:        credentialID,
                PublicKey: generateTestPublicKey(),
            })
    }
}
```

### 12.9 CI/CD固有の設定

```yaml
# avion-auth固有のCI設定
auth-service-tests:
  services:
    postgres:
      image: postgres:15
      env:
        POSTGRES_PASSWORD: test
        POSTGRES_DB: auth_test
    
    redis:
      image: redis:7-alpine
    
    # KMSモックサーバー
    localstack:
      image: localstack/localstack
      env:
        SERVICES: kms
        DEFAULT_REGION: us-east-1
  
  env:
    # セキュリティテスト用
    ENABLE_SECURITY_TESTS: true
    RATE_LIMIT_BYPASS_TOKEN: test-token
    
    # パフォーマンステスト閾値
    MAX_PASSWORD_HASH_TIME_MS: 500
    MAX_JWT_GENERATION_TIME_MS: 10
    MAX_JWT_VALIDATION_TIME_MS: 5
  
  timeout: 15m  # 認証テストは時間がかかる
```

### 12.10 テスト実行マトリクス

| テストタイプ | 実行タイミング | 実行時間目標 | 必須/任意 |
|------------|--------------|-------------|----------|
| Unit Tests | Every commit | < 2min | 必須 |
| Integration (Redis/DB) | Every PR | < 5min | 必須 |
| E2E Auth Flow | Before merge | < 10min | 必須 |
| Security Tests | Every PR | < 15min | 必須 |
| Performance | Nightly | < 30min | 必須 |
| Penetration | Weekly | < 2hr | 任意 |
