# Design Doc: avion-gateway

**Author:** Cline
**Last Updated:** 2025/08/02

## 1. Summary (これは何？)

- **一言で:** Avionマイクロサービスアーキテクチャにおける純粋なAPIゲートウェイとして、すべての外部リクエストを受け付け、認証・認可・レート制限を行い、適切なバックエンドサービスへルーティングを提供するサービスを実装します。
- **目的:** 横断的関心事の一元管理、バックエンドサービスへの効率的なルーティング、およびセキュリティ境界の確立を提供します。BFF機能（GraphQL、SSE）はavion-webに配置されます。

## 2. テスト戦略

このサービスでは、[共通テスト戦略](../common/testing-strategy.md)に従ったテスト実装を行います。

### ゲートウェイ特化のテスト要件
- ルーティングロジックの完全テスト
- サーキットブレーカー状態遷移テスト
- レート制限境界値テスト
- 認証・認可フローの統合テスト
- 負荷分散アルゴリズムの検証

### ゲートウェイ特化の生成対象インターフェース

#### Repository Interfaces (Domain Layer)
```go
//go:generate mockgen -source=$GOFILE -destination=../../tests/mocks/routing_rule_repository_mock.go -package=mocks
type RoutingRuleRepository interface {
    Create(ctx context.Context, rule *RoutingRule) error
    FindByPath(ctx context.Context, path string, method HTTPMethod) (*RoutingRule, error)
    FindByServiceName(ctx context.Context, serviceName ServiceName) ([]*RoutingRule, error)
    FindAll(ctx context.Context) ([]*RoutingRule, error)
    Update(ctx context.Context, rule *RoutingRule) error
    Delete(ctx context.Context, id RuleID) error
    BulkUpdate(ctx context.Context, rules []*RoutingRule) error
}

//go:generate mockgen -source=$GOFILE -destination=../../tests/mocks/circuit_breaker_repository_mock.go -package=mocks
type CircuitBreakerRepository interface {
    GetState(ctx context.Context, serviceName ServiceName) (CircuitState, error)
    UpdateState(ctx context.Context, serviceName ServiceName, state CircuitState) error
    RecordSuccess(ctx context.Context, serviceName ServiceName) error
    RecordFailure(ctx context.Context, serviceName ServiceName) error
    GetMetrics(ctx context.Context, serviceName ServiceName) (*CircuitMetrics, error)
}
```

#### Query Service Interfaces (Use Case Layer)
```go
//go:generate mockgen -source=$GOFILE -destination=../../tests/mocks/service_discovery_mock.go -package=mocks
type ServiceDiscovery interface {
    GetService(ctx context.Context, serviceName ServiceName) (*ServiceEndpoint, error)
    ListServices(ctx context.Context) ([]*ServiceEndpoint, error)
    RegisterService(ctx context.Context, endpoint *ServiceEndpoint) error
    UnregisterService(ctx context.Context, serviceName ServiceName) error
    HealthCheck(ctx context.Context, serviceName ServiceName) (*HealthStatus, error)
}
```

#### External Service Interfaces (Use Case Layer)
```go
//go:generate mockgen -source=$GOFILE -destination=../../tests/mocks/backend_service_client_mock.go -package=mocks
type BackendServiceClient interface {
    Call(ctx context.Context, service string, method string, request interface{}) (interface{}, error)
    CallWithRetry(ctx context.Context, service string, method string, request interface{}, retryConfig RetryConfig) (interface{}, error)
    CheckHealth(ctx context.Context, service string) (*HealthStatus, error)
    GetMetrics(ctx context.Context, service string) (*ServiceMetrics, error)
}

//go:generate mockgen -source=$GOFILE -destination=../../tests/mocks/event_dispatcher_mock.go -package=mocks
type EventDispatcher interface {
    Subscribe(ctx context.Context, channels []string) (<-chan Event, error)
    Publish(ctx context.Context, channel string, event Event) error
    Broadcast(ctx context.Context, event Event, filter EventFilter) (int, error)
    Unsubscribe(ctx context.Context, channels []string) error
}
```

### ゲートウェイ専用テストヘルパー

```go
package testhelpers

// ルーティングテストヘルパー
func SetupRoutingTestContext(t *testing.T) *RoutingTestContext {
    ctrl := gomock.NewController(t)
    return &RoutingTestContext{
        Repository: mocks.NewMockRoutingRuleRepository(ctrl),
        ServiceDiscovery: mocks.NewMockServiceDiscovery(ctrl),
        CircuitBreaker: mocks.NewMockCircuitBreakerRepository(ctrl),
        TestRules: generateTestRoutingRules(),
    }
}

// 認証テストヘルパー
func SetupAuthTestEnvironment(t *testing.T) *AuthTestEnvironment {
    ctrl := gomock.NewController(t)
    return &AuthTestEnvironment{
        JWTVerifier: mocks.NewMockJWTVerifier(ctrl),
        AuthCache: mocks.NewMockAuthCache(ctrl),
        TestTokens: generateTestJWTTokens(),
        PublicKeys: generateTestPublicKeys(),
    }
}

```

### サーキットブレーカーテスト支援

```go
// サーキットブレーカー状態シミュレーション
func SimulateCircuitBreakerStates(t *testing.T) *CircuitBreakerSimulator {
    return &CircuitBreakerSimulator{
        States: map[string]CircuitState{
            "avion-drop": CircuitClosed,
            "avion-timeline": CircuitClosed,
            "avion-user": CircuitClosed,
        },
        FailureThreshold: 5,
        SuccessThreshold: 2,
        Timeout: 30 * time.Second,
        OnStateChange: func(service string, from, to CircuitState) {
            t.Logf("Circuit breaker state change: %s [%s -> %s]", service, from, to)
        },
    }
}
```

### E2Eテスト

このサービスのE2Eテストは、[共通E2Eテスト戦略](../common/e2e-testing-strategy.md)に従って実装します。

#### 主要なE2Eテストシナリオ
- 認証されたリクエストの完全なルーティングフロー
- レート制限違反時の適切なHTTP 429レスポンス
- サーキットブレーカー開放時のフォールバック動作
- バックエンドサービス障害時のエラーハンドリング
- 複数サービス間のルーティング負荷分散
- CORS処理を含むクロスオリジンリクエスト
- ヘルスチェックエンドポイントの正常性確認
- メトリクス収集とObservabilityデータの出力確認

詳細は[共通E2Eテスト戦略ドキュメント](../common/e2e-testing-strategy.md)を参照してください。

詳細なテスト実行方法、モック生成戦略、CI/CD統合については[共通テスト戦略ドキュメント](../common/testing-strategy.md)を参照してください。

## 3. 技術スタック

このサービスでは、[共通Goバックエンド技術スタックガイドライン](../common/architecture/go-backend-framework.md)に従った実装を行います。

### 主要技術
- **HTTPルーティング:** Chi v5
- **RPC:** ConnectRPC
- **GraphQL:** gqlgen（GraphQLゲートウェイとして）
- **ミドルウェア:** 標準net/httpベースの共通ミドルウェア

詳細な実装パターンおよびライブラリの使用方法については、[ガイドライン](../common/architecture/go-backend-framework.md)を参照してください。

## 4. Background & Links (背景と関連リンク)

- マイクロサービスアーキテクチャにおける統一的なAPIゲートウェイの必要性。
- すべての外部クライアントに対する単一エントリーポイントの提供。
- 認証・認可・ルーティングの一元管理。
- [PRD: avion-gateway](./prd.md)
- [Avion アーキテクチャ概要](../common/architecture.md)

## 5. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

#### APIゲートウェイ機能
- すべての外部リクエストの受付とルーティング（REST、gRPC-Web）。
- JWT検証（公開鍵によるローカル検証、Redisキャッシュ活用）。
- Bot認証（APIキー検証）。
- 認可チェック（`avion-auth` との連携）。
- レートリミット実装。
- 構造化ログとメトリクスの収集。
- OpenTelemetryトレースコンテキストの生成と伝播。
- サーキットブレーカーによる障害サービスの隔離。
- avion-webのBFFへのプロキシ機能。


#### 技術要件
- Go言語で実装し、Kubernetes上でのステートレス運用。
- 高可用性を実現する複数レプリカ構成。
- 水平スケーリングによる負荷分散。

### Non-Goals (やらないこと)

- **ビジネスロジック:** アプリケーション固有のロジック実装（各マイクロサービスで実装）。
- **データ永続化:** キャッシュを除くデータの保存。
- **フロントエンドアセット配信:** 静的ファイルのホスティング（CDN経由で配信）。
- **GraphQL処理:** GraphQLエンドポイント実装（avion-webのBFFで実装）。
- **SSE処理:** Server-Sent Events実装（avion-webのBFFで実装）。
- **データ集約:** 複数サービスからのデータ集約（avion-webのBFFで実装）。

## セキュリティ実装ガイドライン

このサービスは以下のセキュリティガイドラインに準拠する必要があります：

### CSRF保護
- **ガイドライン**: [../common/security/csrf-protection.md](../common/security/csrf-protection.md)
- **実装要件**: すべての外部リクエストのエントリーポイントとして、avion-gatewayはダブルサブミットクッキー検証、Origin/Refererヘッダー検証、状態変更操作のカスタムヘッダー要件を含む包括的なCSRF保護を実装する必要があります。ゲートウェイはすべての非安全HTTPメソッド（POST、PUT、PATCH、DELETE）に対してCSRFトークンを生成し検証する必要があります。

### TLS設定
- **ガイドライン**: [../common/security/tls-configuration.md](../common/security/tls-configuration.md)
- **実装要件**: ゲートウェイはすべての外部接続に対してTLS 1.3を強制し、バックエンドサービス接続に対して適切な証明書検証を実装し、サービス間認証のための相互TLS（mTLS）をサポートする必要があります。重要なバックエンドサービスには証明書ピンニングを実装する必要があります。

### セキュリティヘッダー
- **ガイドライン**: [../common/security/security-headers.md](../common/security/security-headers.md)
- **実装要件**: Strict-Transport-Security、X-Content-Type-Options、X-Frame-Options、X-XSS-Protection、Content-Security-Policyを含むすべてのレスポンスに対してセキュリティヘッダーを自動的に注入します。ヘッダーは安全なデフォルトを維持しながら、ルートごとに設定可能である必要があります。

### XSS防止
- **ガイドライン**: [../common/security/xss-prevention.md](../common/security/xss-prevention.md)
- **実装要件**: バックエンドサービスに転送する前に、すべての受信リクエストに対して包括的な入力検証とサニタイゼーションを実装します。プロトコル間（HTTPからgRPC）でレスポンスを変換する際に、コンテキストを考慮した出力エンコーディングを適用します。Content-Typeヘッダーを検証し、予期しないコンテンツタイプを拒否します。

## 6. Architecture (どうやって作る？)

### 6.1. レイヤードアーキテクチャ (DDD準拠)

#### Domain Layer (ドメイン層)
- **Aggregates:**
  - RoutingRule: APIルーティングルールの管理（10+不変条件）
  - LoadBalancingPolicy: 負荷分散ポリシー管理（13不変条件）
  - SecurityPolicy: セキュリティポリシー管理（15不変条件）
  - RequestContext: リクエストライフサイクル管理（12不変条件）
  - RateLimitBucket: レート制限状態管理（13不変条件）
- **Entities:**
  - AuthenticationContext: 認証情報と検証結果
  - RouteTarget: ルーティング先サービス情報
  - Backend: バックエンドサーバー状態
  - CircuitBreaker: サーキットブレーカー状態
  - RateLimitWindow: レート制限時間ウィンドウ
- **Value Objects:**
  - 識別子系: RequestID, TraceID, SpanID, UserID, ServiceName, BucketID
  - ネットワーク系: HTTPMethod, HTTPPath, HTTPStatusCode, IPAddress, Port, Endpoint
  - 時刻系: Timestamp, Duration, TTL, WindowSize
  - セキュリティ系: JWTToken, APIKey, Scope, CSRFToken
  - レート制限系: TokenCount, RefillRate, BurstSize
- **Domain Services:**
  - APIOrchestrator: 複数Aggregate調整サービス
  - AuthenticationService: 統合認証サービス
  - RateLimitingService: レート制限評価サービス
- **Repository Interfaces:**
  - RoutingRuleRepository
  - LoadBalancingPolicyRepository
  - SecurityPolicyRepository
  - RateLimitBucketRepository

#### Use Case Layer (ユースケース層)
- **Command Use Cases (更新系):**
  - ProcessAPIRequestCommandUseCase: APIリクエスト処理（POST/PUT/DELETE）
  - UpdateRateLimitCommandUseCase: レート制限更新
  - InvalidateAuthCacheCommandUseCase: 認証キャッシュ無効化
- **Query Use Cases (参照系):**
  - ValidateJWTQueryUseCase: JWT検証
  - CheckRateLimitQueryUseCase: レート制限確認
  - ResolveRouteQueryUseCase: ルーティング解決
- **Query Service Interfaces:**
  - AuthCacheQueryService: 認証キャッシュ参照
  - RateLimitQueryService: レート制限情報参照
- **DTOs:**
  - APIRequest, APIResponse, RouteInfo等
- **External Service Interfaces:**
  - IAMServiceClient: avion-authとの連携
  - BackendServiceClient: 各バックエンドサービスとの連携

#### Infrastructure Layer (インフラストラクチャ層)
- **External Service Implementations:**
  - GRPCBackendServiceClient: gRPCクライアント実装
  - HTTPBackendServiceClient: HTTPクライアント実装
- **Cache:**
  - RedisAuthCache: JWT検証結果キャッシュ
  - RedisRateLimitCache: レート制限カウンタ
- **Circuit Breaker:**
  - ServiceCircuitBreaker: サービス別サーキットブレーカー
- **Service Discovery:**
  - KubernetesServiceDiscovery: K8sサービス発見

#### Handler Layer (ハンドラー層)
- **Command Handlers (更新系):**
  - APICommandHandler: 更新系APIエンドポイント（POST/PUT/DELETE）
  - OAuthTokenCommandHandler: Bot認証トークン発行
- **Query Handlers (参照系):**
  - APIQueryHandler: 参照系APIエンドポイント（GET）
  - HealthCheckQueryHandler: ヘルスチェック
  - MetricsQueryHandler: メトリクス
- **Event Handlers:**
  - JWTRevokedEventHandler: JWT失効イベント
  - PublicKeyUpdatedEventHandler: 公開鍵更新イベント
- **Middleware:**
  - AuthenticationMiddleware: 認証処理
  - RateLimitMiddleware: レート制限
  - TracingMiddleware: OpenTelemetryトレーシング
  - CircuitBreakerMiddleware: サーキットブレーカー

### 6.2. 主要コンポーネント

- **主要コンポーネント:**
    - `avion-gateway (Go, Kubernetes Deployment)`: 本サービス。HTTPサーバー、gRPCクライアント、Redisクライアント。
    - `avion-web (Next.js)`: BFF機能を含むWebアプリケーション（GraphQL、SSE、データ集約）。
    - `avion-auth (Go)`: 認証・認可サービス。
    - `avion-drop (Go)`: 投稿管理。
    - `avion-timeline (Go)`: タイムライン生成。
    - `avion-notification (Go)`: 通知管理。
    - `avion-activitypub (Go)`: ActivityPub処理。
    - `Redis`: 認証キャッシュ、レート制限、イベント通知。
    - `Observability Stack`: メトリクス、トレース、ログ収集。
- **構成図:** (アーキテクチャ概要図を参照)
    - [Avion アーキテクチャ概要](../common/architecture.md)
- **ポイント:**
    - 単一のエントリーポイントとしてすべての外部リクエストを処理。
    - 横断的関心事の一元的な処理。
    - ステートレス設計による高可用性。
    - サーキットブレーカーによる障害の隔離。

## データベースマイグレーション

このサービスでは、[共通マイグレーション戦略](../common/database-migration-strategy.md)に従って、Gooseを使用したマイグレーション管理を行います。

### マイグレーション戦略

- **ツール**: Goose v3
- **ディレクトリ**: `./migrations/`
- **命名規則**: `[sequence_number]_[description].sql`
- **実行方法**: `make migrate-up` / `make migrate-down`

### avion-gateway固有の考慮事項

- **最小限のデータベース依存**: Gateway主要機能はステートレスため、データベーススキーマは最小限
- **設定データ整合性**: API設定やルーティング設定の整合性を保持
- **ログデータ移行**: リクエストログやメトリクス履歴の適切な移行
- **レート制限データ**: Redis中心のため、PostgreSQL移行データは限定的
- **無停止運用**: Gateway特性上、完全無停止での移行を前提とした設計

### 標準テンプレート参照

マイグレーションファイル作成時は[マイグレーション設定テンプレート](../templates/migration-setup-template.md)を参照してください。

## 7. Use Cases / Key Flows (主な使い方・処理の流れ)

- **フロー 1: REST APIリクエスト（認証付き）**
    1. Client → Gateway: REST API Request (JWT付き)
    2. Gateway: JWT検証（Redisキャッシュチェック → ローカル検証）
    3. Gateway: レート制限チェック
    4. Gateway: ルーティング解決（RouteResolver）
    5. Gateway: サーキットブレーカー確認
    6. Gateway → BackendService: gRPC/HTTP Call
    7. BackendService → Gateway: Response
    8. Gateway → Client: HTTP Response

- **フロー 2: Bot認証とAPI利用**
    1. Bot → Gateway: `POST /oauth/token` (client_credentials)
    2. Gateway → IAMService: Bot認証要求
    3. IAMService → Gateway: JWT発行
    4. Gateway → Bot: JWT Response
    5. Bot → Gateway: API呼び出し（JWT付き）
    6. Gateway: JWT検証、スコープチェック、処理実行

- **フロー 3: ActivityPub受信**
    1. Remote Server → Gateway: `POST /inbox` (Activity)
    2. Gateway: 基本検証、レート制限
    3. Gateway → ActivityPubService: HTTPリクエスト転送
    4. ActivityPubService → Gateway: 処理結果
    5. Gateway → Remote Server: HTTPレスポンス

- **フロー 4: サーキットブレーカー動作**
    1. Gateway → BackendService: リクエスト送信
    2. BackendService: エラーレスポンス（タイムアウト等）
    3. Gateway: エラーカウント増加
    4. Gateway: 閾値超過でサーキット開放
    5. 後続リクエスト: 即座にエラー返却（バックエンド呼び出しスキップ）
    6. 一定時間後: Half-Open状態で試行

- **フロー 5: JWT失効処理**
    1. IAMService: ログアウト等でJWT失効
    2. IAMService → Redis: `token_revoked` イベント発行
    3. Gateway: イベント受信
    4. Gateway: Redisキャッシュから該当JWT削除


## 8. Endpoints (API)

- **REST Endpoints:**
    - `/*`: すべてのAPIリクエストを受付、適切なバックエンドへルーティング
    - `/oauth/token`: Bot認証トークン発行
    - `/inbox`, `/users/{username}/inbox`: ActivityPub受信
    - `/.well-known/webfinger`: WebFinger
    - `/health`: ヘルスチェック
    - `/metrics`: Prometheusメトリクス

- **内部gRPCクライアント:**
    - 各バックエンドサービスのgRPCクライアント実装

## 9. Data Design (データ)

### 9.1. Domain Model (ドメインモデル)

#### Aggregates (集約)

##### RoutingRule Aggregate
- **責務:** APIルーティングルールの管理とパスマッチング
- **集約ルート:** RoutingRule
- **構成要素:**
  - RuleID (Value Object): ルール識別子
  - PathPattern (Value Object): パスパターン（正規表現またはパラメータ付き）
  - HTTPMethods (Value Object Collection): 対応HTTPメソッドリスト
  - RouteTarget (Entity): ルーティング先情報
  - Priority (Value Object): ルーティング優先度（1-1000）
  - AuthRequired (Value Object): 認証必須フラグ
  - QueryValidation (Value Object): クエリパラメータ検証ルール
  - HeaderRequirements (Value Object): ヘッダー要件
  - TimeoutConfig (Value Object): タイムアウト設定
- **不変条件:**
  - パスパターンは有効な正規表現またはパラメータ付きパス
  - 優先度は1-1000の範囲内で一意
  - 同一パスパターンとHTTPメソッドの組み合わせは一意
  - ターゲットサービスはavion-*命名規則に従う
  - HTTPメソッドは標準メソッドのみ
  - パスパラメータ名は予約語を使用しない
  - タイムアウトは100ms-30秒の範囲
  - パスの最大長は2048文字
  - ルーティングループが発生しない
  - レスポンス変換ルールが定義されている

##### LoadBalancingPolicy Aggregate
- **責務:** 負荷分散ポリシーとヘルスチェックの管理
- **集約ルート:** LoadBalancingPolicy
- **構成要素:**
  - PolicyID (Value Object): ポリシー識別子
  - ServiceName (Value Object): 対象サービス名
  - Algorithm (Value Object): 負荷分散アルゴリズム
  - Backends (Entity Collection): バックエンドサーバーリスト
  - CircuitBreaker (Entity): サーキットブレーカー設定
  - HealthCheckConfig (Value Object): ヘルスチェック設定
  - RetryPolicy (Value Object): リトライポリシー
  - ConnectionPool (Value Object): コネクションプール設定
  - StickySession (Value Object): スティッキーセッション設定
- **不変条件:**
  - アルゴリズムは定義済みのもののみ
  - ヘルスチェック間隔は1-300秒
  - リトライ回数は0-5回
  - サーキットブレーカー開放閾値は50-100%
  - 最低1台のバックエンドが定義
  - コネクションプールサイズは1-1000
  - スティッキーセッションTTLは1分-24時間
  - Half-Open試行間隔は5秒-5分
  - バックエンド重み付けは1-100
  - 連続失敗閾値は1-10回

##### SecurityPolicy Aggregate
- **責務:** セキュリティポリシーと認証・認可ルールの管理
- **集約ルート:** SecurityPolicy
- **構成要素:**
  - PolicyID (Value Object): ポリシー識別子
  - AuthMethods (Value Object Collection): 認証方式リスト
  - RateLimitRules (Value Object Collection): レート制限ルール
  - IPAccessControl (Value Object): IPアクセス制御
  - CORSConfig (Value Object): CORS設定
  - SecurityHeaders (Value Object): セキュリティヘッダー
  - CSRFProtection (Value Object): CSRF保護設定
  - AuditConfig (Value Object): 監査設定
  - EncryptionConfig (Value Object): 暗号化設定
- **不変条件:**
  - 認証方式はJWT, OAuth2, APIKey, mTLSのみ
  - JWT署名アルゴリズムはRS256, ES256のみ
  - レート制限は1-10000req/sec
  - IPアドレスは有効なCIDR形式
  - CORSオリジンは有効なURL
  - 最大リクエストサイズは1KB-100MB
  - CSRFトークン有効期限は1分-24時間
  - TLS最小バージョンは1.2以上
  - 監査ログ保持期間は7-365日
  - APIキー長は32-128文字
  - セッションタイムアウトは5分-24時間
  - バーストサイズは基本レートの10倍以下
  - 異常検知閾値は3-100回
  - セキュリティヘッダーはOWASP準拠
  - 暗号化アルゴリズムはNIST推奨

##### RequestContext Aggregate
- **責務:** リクエストのライフサイクルとコンテキスト情報の管理
- **集約ルート:** RequestContext
- **構成要素:**
  - RequestID (Value Object): リクエスト識別子
  - TraceContext (Value Object): OpenTelemetryトレース情報
  - AuthenticationContext (Entity): 認証コンテキスト
  - HTTPRequest (Value Object): HTTPリクエスト情報
  - ClientInfo (Value Object): クライアント情報
  - ProcessingMetrics (Value Object): 処理メトリクス
  - ResponseContext (Value Object): レスポンスコンテキスト
- **不変条件:**
  - RequestIDはUUID v4形式で一意
  - TraceID/SpanIDはOpenTelemetry準拠
  - タイムスタンプはUTCミリ秒精度
  - User-Agentは1024文字以下
  - ヘッダー総サイズは8KB以下
  - X-Forwarded-Forは10ホップ以下
  - Content-Typeは有効なMIMEタイプ
  - 処理時間は30秒以下
  - 認証トークンはBearerスキーム
  - APIバージョンはセマンティックバージョニング
  - カスタムヘッダー名は予約語と非衝突
  - Accept-Languageは有効なロケール

##### RateLimitBucket Aggregate
- **責務:** レート制限の状態管理とトークンバケットアルゴリズムの実装
- **集約ルート:** RateLimitBucket
- **構成要素:**
  - BucketID (Value Object): バケット識別子
  - TokenState (Value Object): トークン状態
  - RefillConfig (Value Object): 補充設定
  - Windows (Entity Collection): レート制限ウィンドウリスト
  - BurstConfig (Value Object): バースト設定
  - GracePeriod (Value Object): グレースピリオド設定
  - PriorityLevel (Value Object): 優先度レベル
- **不変条件:**
  - バケットIDは type:identifier:endpoint 形式
  - トークン数は0-最大容量
  - 最大容量は1-100000
  - 補充レートは1-10000/秒
  - ウィンドウサイズは1-3600秒
  - バーストサイズは基本容量の1-10倍
  - スライディングウィンドウ履歴は最大3600
  - 識別子タイプはuser, ip, api_key, domain
  - 優先度レベルは1-5
  - グレースピリオドは0-60秒
  - IPアドレスは有効な形式
  - 最終更新時刻は現在時刻以前
  - リセット時刻は最終更新時刻より後

#### Entities (エンティティ)

##### AuthenticationContext (認証コンテキスト)
- **責務:** ユーザー認証情報を保持
- **所属集約:** GatewayRequest
- **属性:**
  - UserID (Value Object): ユーザーID
  - TokenJTI (Value Object): JWTトークンID
  - Scopes (Value Object Collection): アクセススコープのリスト
  - ExpiresAt (Value Object): トークン有効期限
- **不変条件:** 有効期限切れのトークンは無効

##### RouteTarget (ルーティング先)
- **責務:** リクエストのルーティング先情報を保持
- **所属集約:** GatewayRequest
- **属性:**
  - ServiceName (Value Object): バックエンドサービス名
  - ServiceEndpoint (Value Object): サービスエンドポイント
  - MethodName (Value Object): gRPCメソッド名
  - RequiresAuth (Value Object): 認証必須フラグ
- **不変条件:** ServiceNameとServiceEndpointは必須

##### RateLimitWindow (レート制限ウィンドウ)
- **責務:** レート制限の時間ウィンドウを管理
- **所属集約:** RateLimitBucket
- **属性:**
  - WindowStart (Value Object): ウィンドウ開始時刻
  - WindowEnd (Value Object): ウィンドウ終了時刻
  - RequestTimestamps (Value Object Collection): リクエストタイムスタンプリスト
- **不変条件:** WindowEndはWindowStartより後

#### Value Objects (値オブジェクト)

##### 識別子系Value Objects

###### RequestID
- **責務:** リクエストの一意識別子を表現
- **属性:** UUID v4形式
- **不変性:** 完全に不変
- **バリデーション:** 正しいUUID形式

###### UserID
- **責務:** ユーザーの一意識別子を表現
- **属性:** Snowflake ID
- **不変性:** 完全に不変

###### TokenJTI
- **責務:** JWTトークンの一意識別子を表現
- **属性:** JWT ID
- **不変性:** 完全に不変

###### BucketID
- **責務:** レート制限バケットの識別子を表現
- **属性:** ユーザーIDとエンドポイントの組み合わせ
- **不変性:** 完全に不変

##### ネットワーク系Value Objects

###### HTTPMethod
- **責務:** HTTPメソッドを表現
- **値:** GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD
- **不変性:** 完全に不変
- **バリデーション:** 定義された値のみ

###### HTTPPath
- **責務:** HTTPパスを表現
- **属性:** URLパス文字列
- **制約:** 最大2048文字
- **不変性:** 完全に不変
- **バリデーション:** 有効なURLパス形式

###### HTTPStatusCode
- **責務:** HTTPステータスコードを表現
- **属性:** 3桁の数値
- **制約:** 100-599の範囲
- **不変性:** 完全に不変

###### ServiceEndpoint
- **責務:** サービスエンドポイントを表現
- **属性:** URL文字列
- **不変性:** 完全に不変
- **バリデーション:** 有効なURL形式

##### サービス系Value Objects

###### ServiceName
- **責務:** マイクロサービス名を表現
- **属性:** サービス名文字列
- **制約:** 英数字とハイフンのみ
- **不変性:** 完全に不変

###### MethodName
- **責務:** gRPCメソッド名を表現
- **属性:** メソッド名文字列
- **不変性:** 完全に不変

##### レート制限系Value Objects

###### RateLimitKey
- **責務:** レート制限のキーを表現
- **属性:** UserID + Endpointの組み合わせ
- **不変性:** 完全に不変

###### RequestCount
- **責務:** リクエスト数を表現
- **属性:** カウント値
- **制約:** 0以上の整数
- **不変性:** 完全に不変

###### WindowSize
- **責務:** レート制限ウィンドウサイズを表現
- **属性:** 秒数
- **制約:** 1秒以上3600秒以下
- **不変性:** 完全に不変

###### MaxRequests
- **責務:** 最大リクエスト数を表現
- **属性:** 最大値
- **制約:** 1以上の整数
- **不変性:** 完全に不変

##### サーキットブレーカー系Value Objects

###### CircuitState
- **責務:** サーキットブレーカー状態を表現
- **値:** CLOSED, OPEN, HALF_OPEN
- **不変性:** 完全に不変

###### ErrorCount
- **責務:** エラーカウントを表現
- **属性:** カウント値
- **制約:** 0以上の整数
- **不変性:** 完全に不変

###### SuccessCount
- **責務:** 成功カウントを表現
- **属性:** カウント値
- **制約:** 0以上の整数
- **不変性:** 完全に不変

###### ErrorRate
- **責務:** エラー率を表現
- **属性:** パーセンテージ
- **制約:** 0.0-100.0の範囲
- **不変性:** 完全に不変

###### ErrorThreshold
- **責務:** エラー闾値を表現
- **属性:** 闾値
- **制約:** 1以上の整数
- **不変性:** 完全に不変

##### 認証系Value Objects

###### JWTClaims
- **責務:** JWTクレームを表現
- **属性:** クレームマップ
- **不変性:** 完全に不変

###### Scope
- **責務:** アクセススコープを表現
- **属性:** スコープ文字列
- **不変性:** 完全に不変

###### RequiresAuth
- **責務:** 認証必須フラグを表現
- **属性:** 真偽値
- **不変性:** 完全に不変

##### メトリクス系Value Objects

###### Latency
- **責務:** レイテンシを表現
- **属性:** ミリ秒単位
- **制約:** 0以上の数値
- **不変性:** 完全に不変

##### 日時系Value Objects

###### Timestamp
- **責務:** タイムスタンプを表現
- **属性:** UTCタイムスタンプ
- **不変性:** 完全に不変

###### WindowStart
- **責務:** ウィンドウ開始時刻を表現
- **属性:** UTCタイムスタンプ
- **不変性:** 完全に不変

###### WindowEnd
- **責務:** ウィンドウ終了時刻を表現
- **属性:** UTCタイムスタンプ
- **不変性:** 完全に不変

###### ExpiresAt
- **責務:** 有効期限を表現
- **属性:** UTCタイムスタンプ
- **不変性:** 完全に不変

###### LastFailureTime
- **責務:** 最終失敗時刻を表現
- **属性:** UTCタイムスタンプ
- **不変性:** 完全に不変

##### トレース系Value Objects

###### TraceContext
- **責務:** OpenTelemetryトレース情報を表現
- **属性:** TraceID, SpanID, TraceFlags
- **不変性:** 完全に不変

###### RequestMetadata
- **責務:** リクエストメタデータを表現
- **属性:** ヘッダー、クエリパラメータ等
- **不変性:** 完全に不変

#### Domain Services (ドメインサービス)

##### APIOrchestrator
- **責務:** 複数のAggregateを調整してAPIリクエスト全体を処理
- **主要メソッド:**
  - `ProcessRequest(ctx, request)`: リクエスト処理全体を調整
  - `ApplySecurityPolicies(ctx, policies)`: 複数のセキュリティポリシーを順次適用
  - `RouteWithLoadBalancing(rule, policy)`: ルーティングと負荷分散を統合実行
  - `HandleCircuitBreaker(service, operation)`: サーキットブレーカーを考慮した処理
  - `AggregateMetrics(request, response)`: 各層のメトリクスを集約
  - `CoordinateRetry(operation, policy)`: リトライポリシーに基づく再試行調整

##### AuthenticationService
- **責務:** 複数の認証方式を統合的に処理し、認証コンテキストを生成
- **主要メソッド:**
  - `Authenticate(credentials)`: 認証方式を自動判定して認証実行
  - `ValidateJWT(token)`: JWT検証とキャッシュ管理
  - `ValidateAPIKey(key)`: APIキー検証と権限マッピング
  - `RefreshToken(refreshToken)`: トークンのリフレッシュ処理
  - `RevokeToken(token)`: トークンの失効処理
  - `ExtractBearerToken(headers)`: ヘッダーからBearerトークン抽出
  - `CheckTokenRevocation(jti)`: トークン失効リストの確認

##### RateLimitingService
- **責務:** 複雑なレート制限ルールの評価と複数バケットの統合管理
- **主要メソッド:**
  - `EvaluateRateLimit(identifier, endpoint)`: レート制限の評価
  - `ApplyMultipleLimit(userLimit, ipLimit, globalLimit)`: 複数制限の統合
  - `CalculateBackoff(violations)`: 違反回数に基づくバックオフ時間計算
  - `GrantGracePeriod(user, reason)`: グレースピリオドの付与
  - `GetBucketStatus(bucketID)`: バケットの現在状態取得
  - `ResetBucket(bucketID)`: バケットの強制リセット
  - `ApplyPriorityBoost(user, level)`: 優先度に基づくレート制限緩和

##### CircuitBreakerService
- **責務:** サービス全体のサーキットブレーカー状態を管理
- **主要メソッド:**
  - `EvaluateCircuit(service, errorRate)`: サーキット状態の評価
  - `OpenCircuit(service, reason)`: サーキットを開放
  - `AttemptHalfOpen(service)`: Half-Open状態への移行試行
  - `RecordSuccess(service)`: 成功の記録と状態更新
  - `RecordFailure(service, error)`: 失敗の記録と閾値評価
  - `GetCircuitStatus(service)`: 現在の状態取得
  - `ForceClose(service)`: 手動でのサーキットクローズ

### 9.2. Infrastructure Layer (インフラストラクチャ層)

- **Redisキャッシュ:**
    - JWT検証結果:
        - Key: `jwt_validation:{jti}`
        - Value: `{"user_id": "...", "scopes": [...], "exp": ...}`
        - TTL: JWT有効期限まで
    - レート制限:
        - Key: `rate_limit:{user_id}:{window}`
        - Value: リクエスト数
        - TTL: ウィンドウサイズ
    - サーキットブレーカー状態:
        - Key: `circuit_breaker:{service_name}`
        - Value: `{"state": "OPEN", "failure_count": 5, "last_failure": ...}`
        - TTL: 状態に応じて動的

- **メモリ内データ:**
    - JWT公開鍵（IAMServiceから取得、イベントで更新）
    - ルーティングルール（ConfigMapから読み込み）
    - サービスエンドポイント情報

## 10. Operations & Monitoring (運用と監視)

- **主なオペレーション:**
    - デプロイ（ローリングアップデート）
    - スケーリング（HPA設定）
    - 設定更新（ConfigMap）
    - Redis接続管理
    - JWT公開鍵の初期取得と更新

- **監視/アラート:**
    - **メトリクス:**
        - HTTPリクエスト数、レイテンシ、エラー率（path/method別）
        - gRPCクライアントメトリクス（service/method別）
        - JWT検証成功/失敗率、キャッシュヒット率
        - レート制限発生数（user/endpoint別）
        - サーキットブレーカー状態（service別）
        - バックエンドサービス呼び出しレイテンシ
    - **ログ:**
        - アクセスログ（user_id, path, method, status, latency）
        - エラーログ（詳細なスタックトレース）
        - 認証/認可失敗ログ
        - サーキットブレーカー状態変更ログ
    - **トレース:**
        - リクエスト全体のフロー可視化
        - バックエンドサービス呼び出しの詳細
        - 認証・認可処理の追跡
    - **アラート:**
        - エラー率急増（5xx > 1%）
        - 高レイテンシ（P99 > 100ms）
        - サーキットブレーカー開放
        - バックエンドサービス接続障害
        - Redis接続障害
        - メモリ/CPU使用率異常

## 11. Concerns / Open Questions (懸念事項・相談したいこと)

- **技術的負債リスク:**
    - **単一障害点:** すべてのリクエストが経由するため、可用性要求が極めて高い。複数レプリカとロードバランサーによる冗長化が必須。
    - **レイテンシの積み上げ:** Gateway処理がバックエンドレイテンシに追加される。最小限の処理時間を維持する必要がある。
    - **設定管理の複雑性:** ルーティングルール、レート制限ポリシー、サーキットブレーカー設定など、多数の設定項目の管理。
    - **サービス間認証:** 内部サービス間通信のmTLS実装（将来的）。

- HTTPルーターライブラリ選定（`gin`を推奨）。
- サービスディスカバリの実装（Kubernetes Service利用）。
- レート制限アルゴリズム（Sliding Window推奨）。
- サーキットブレーカーライブラリ（`sony/gobreaker`推奨）。
- 内部通信のセキュリティ強化（mTLS）。

## 12. エラーハンドリング戦略

> **注意:** エラーコードは[共通エラーコード標準](../common/errors/error-codes.md)に準拠します。このサービスではプレフィックス `GWY` を使用します。

### エラーコード体系

本サービスは、Avionプラットフォーム標準のエラーコード体系に準拠します。

- **命名規則**: `[SERVICE]_[LAYER]_[ERROR_TYPE]`形式
- **エラーカタログ**: [error-catalog.md](./error-catalog.md)
- **実装ガイド**: [共通エラー実装ガイド](../common/errors/implementation-guide.md)
- **標準仕様**: [エラーコード標準化ガイドライン](../common/errors/error-standards.md)

詳細なエラーコード定義とマッピングについては、上記のドキュメントを参照してください。

### ドメインエラーの定義

```go
// domain/error/errors.go
package error

import "errors"

// ゲートウェイ関連エラー
var (
    ErrInvalidRoute          = errors.New("invalid route")
    ErrServiceUnavailable    = errors.New("service unavailable")
    ErrAuthenticationFailed  = errors.New("authentication failed")
    ErrInvalidJWT           = errors.New("invalid JWT token")
    ErrJWTExpired           = errors.New("JWT token expired")
    ErrUnauthorized         = errors.New("unauthorized access")
    ErrRateLimitExceeded    = errors.New("rate limit exceeded")
    ErrCircuitBreakerOpen   = errors.New("circuit breaker is open")
    ErrInvalidAPIKey        = errors.New("invalid API key")
    ErrMissingAuthHeader    = errors.New("missing authorization header")
    ErrInvalidRequestFormat = errors.New("invalid request format")
    ErrUpstreamTimeout      = errors.New("upstream service timeout")
)

// Bot認証関連エラー
var (
    ErrBotNotFound        = errors.New("bot not found")
    ErrInvalidClientID    = errors.New("invalid client ID")
    ErrInvalidClientSecret = errors.New("invalid client secret")
    ErrInvalidGrantType   = errors.New("invalid grant type")
    ErrScopeNotAllowed    = errors.New("scope not allowed")
)
```

### エラーハンドリング階層

#### 1. ドメイン層でのエラー処理

```go
// domain/service/route_resolver.go
func (r *RouteResolver) ResolveRoute(path string, method HTTPMethod) (*RouteTarget, error) {
    route, exists := r.routes[buildRouteKey(path, method)]
    if !exists {
        return nil, error.ErrInvalidRoute
    }
    
    if route.circuitBreakerState == CircuitBreakerOpen {
        return nil, error.ErrCircuitBreakerOpen
    }
    
    return route, nil
}
```

#### 2. ユースケース層でのエラー処理

```go
// usecase/command/process_api_request.go
func (uc *ProcessAPIRequestCommandUseCase) Execute(ctx context.Context, req *ProcessAPIRequestCommand) error {
    // JWT検証
    authContext, err := uc.ValidateJWT(ctx, req.JWT)
    if err != nil {
        switch {
        case errors.Is(err, error.ErrInvalidJWT):
            return &AuthenticationError{Reason: "Invalid token format"}
        case errors.Is(err, error.ErrJWTExpired):
            return &AuthenticationError{Reason: "Token expired"}
        default:
            return &InternalError{Cause: err}
        }
    }
    
    // レート制限チェック
    allowed, err := uc.CheckRateLimit(ctx, authContext.UserID, req.Path)
    if err != nil {
        return &InternalError{Cause: err}
    }
    if !allowed {
        return &RateLimitError{ResetTime: time.Now().Add(time.Hour)}
    }
    
    // ルーティング解決
    route, err := uc.ResolveRoute(req.Path, req.Method)
    if err != nil {
        switch {
        case errors.Is(err, error.ErrInvalidRoute):
            return &NotFoundError{Resource: "endpoint"}
        case errors.Is(err, error.ErrCircuitBreakerOpen):
            return &ServiceUnavailableError{RetryAfter: time.Minute * 5}
        default:
            return &InternalError{Cause: err}
        }
    }
    
    return nil
}
```

#### 3. ハンドラー層でのエラー処理とHTTPステータスマッピング

```go
// handler/middleware/error_handler.go
func ErrorHandlerMiddleware() gin.HandlerFunc {
    return gin.CustomRecovery(func(c *gin.Context, recovered interface{}) {
        if err, ok := recovered.(error); ok {
            handleError(c, err)
        } else {
            c.JSON(500, gin.H{
                "error": "Internal server error",
                "code":  "INTERNAL_ERROR",
            })
        }
        c.Abort()
    })
}

func handleError(c *gin.Context, err error) {
    var (
        statusCode int
        errorCode  string
        message    string
    )
    
    switch e := err.(type) {
    case *AuthenticationError:
        statusCode = 401
        errorCode = "AUTHENTICATION_FAILED"
        message = e.Reason
    case *AuthorizationError:
        statusCode = 403
        errorCode = "FORBIDDEN"
        message = e.Reason
    case *RateLimitError:
        statusCode = 429
        errorCode = "RATE_LIMIT_EXCEEDED"
        message = "Too many requests"
        c.Header("Retry-After", e.ResetTime.Format(time.RFC3339))
    case *NotFoundError:
        statusCode = 404
        errorCode = "NOT_FOUND"
        message = fmt.Sprintf("%s not found", e.Resource)
    case *ServiceUnavailableError:
        statusCode = 503
        errorCode = "SERVICE_UNAVAILABLE"
        message = "Service temporarily unavailable"
        c.Header("Retry-After", e.RetryAfter.String())
    case *ValidationError:
        statusCode = 400
        errorCode = "BAD_REQUEST"
        message = e.Message
    default:
        statusCode = 500
        errorCode = "INTERNAL_ERROR"
        message = "Internal server error"
    }
    
    // 構造化ログに記録
    slog.ErrorContext(c.Request.Context(), "Request failed",
        "error", err.Error(),
        "status_code", statusCode,
        "error_code", errorCode,
        "path", c.Request.URL.Path,
        "method", c.Request.Method,
        "user_id", c.GetString("user_id"),
        "trace_id", trace.SpanFromContext(c.Request.Context()).SpanContext().TraceID(),
    )
    
    c.JSON(statusCode, gin.H{
        "error": message,
        "code":  errorCode,
    })
}
```

### サーキットブレーカーエラー処理

```go
// infrastructure/circuit_breaker.go
type ServiceCircuitBreaker struct {
    breakers map[string]*gobreaker.CircuitBreaker
    mu       sync.RWMutex
}

func (scb *ServiceCircuitBreaker) ExecuteWithBreaker(serviceName string, operation func() (interface{}, error)) (interface{}, error) {
    breaker := scb.getBreaker(serviceName)
    
    result, err := breaker.Execute(operation)
    if err != nil {
        if errors.Is(err, gobreaker.ErrOpenState) {
            return nil, error.ErrCircuitBreakerOpen
        }
        return nil, err
    }
    
    return result, nil
}
```

## 13. 構造化ログ戦略

このサービスでは、運用性とデバッグ効率を向上させるため、構造化ログを採用します。

### ログフレームワーク
- **使用ライブラリ**: `slog` (Go標準ライブラリ)
- **出力形式**: JSON形式
- **ログレベル**: Debug, Info, Warn, Error, CRITICAL
- **CRITICALレベル**: panicにして処理を停止させないといけないレベル（Redis接続断、全サービスへの接続不能等）

### ログ構造の標準フィールド
```go
type LogContext struct {
    // 必須フィールド
    Timestamp   time.Time `json:"timestamp"`
    Level       string    `json:"level"`
    Service     string    `json:"service"`     // "avion-gateway"
    Version     string    `json:"version"`     // サービスバージョン
    TraceID     string    `json:"trace_id"`    // OpenTelemetry TraceID
    SpanID      string    `json:"span_id"`     // OpenTelemetry SpanID
    
    // リクエスト関連
    RequestID   string    `json:"request_id"` // X-Request-IDまたは生成
    UserID      string    `json:"user_id"`    // 認証済みユーザーID
    Method      string    `json:"method"`     // HTTPメソッド
    Path        string    `json:"path"`       // リクエストパス
    UserAgent   string    `json:"user_agent"` // User-Agent
    RemoteAddr  string    `json:"remote_addr"` // クライアントIP
    
    // ゲートウェイ固有フィールド
    TargetService string `json:"target_service"` // ルーティング先サービス
    AuthMethod    string `json:"auth_method"`    // jwt, api_key, none
    RateLimitKey  string `json:"rate_limit_key"` // レート制限キー
    
    // パフォーマンス関連
    Duration      int64  `json:"duration_ms"`     // 処理時間（ミリ秒）
    UpstreamDuration int64 `json:"upstream_ms"`   // アップストリーム呼び出し時間
    
    // エラー関連（エラー時のみ）
    ErrorCode     string `json:"error_code,omitempty"` 
    ErrorMessage  string `json:"error_message,omitempty"`
    StackTrace    string `json:"stack_trace,omitempty"`
}
```

### ログレベル別記録方針

#### DEBUGレベル
- JWT検証の詳細情報
- キャッシュヒット/ミス情報
- ルーティング解決の詳細
- 開発環境でのみ有効

```go
slog.DebugContext(ctx, "JWT validation completed",
    "user_id", userID,
    "scopes", scopes,
    "cache_hit", cacheHit,
    "validation_duration_ms", duration.Milliseconds(),
)
```

#### INFOレベル
- 正常なリクエスト処理完了
- サービス起動・シャットダウン
- 設定変更

```go
slog.InfoContext(ctx, "Request processed",
    "method", method,
    "path", path,
    "status_code", statusCode,
    "user_id", userID,
    "target_service", targetService,
    "duration_ms", duration.Milliseconds(),
    "upstream_ms", upstreamDuration.Milliseconds(),
)
```

#### WARNレベル
- レート制限発動
- JWT有効期限切れ
- サーキットブレーカー状態変更
- 外部サービスの軽微な障害

```go
slog.WarnContext(ctx, "Rate limit triggered",
    "user_id", userID,
    "path", path,
    "current_count", currentCount,
    "limit", limit,
    "window_start", windowStart,
)
```

#### ERRORレベル
- 認証・認可エラー
- アップストリームサービスエラー
- 設定エラー
- タイムアウト

```go
slog.ErrorContext(ctx, "Upstream service call failed",
    "target_service", serviceName,
    "error", err.Error(),
    "method", method,
    "path", path,
    "user_id", userID,
    "attempt", attemptCount,
    "duration_ms", duration.Milliseconds(),
)
```

#### CRITICALレベル
- Redis接続完全断絶
- 全アップストリームサービス接続不能
- メモリ枯渇
- セキュリティ侵害の疑い

```go
slog.Error("CRITICAL: All upstream services unavailable",
    "available_services", availableServices,
    "circuit_breaker_states", breakerStates,
    "redis_status", redisStatus,
)
// アラート送信とフェイルセーフ処理を実行
```

### ログのサンプリング
高負荷時のログ量制御のため、INFOレベルのログにサンプリングを適用:

```go
type SamplingLogger struct {
    logger     *slog.Logger
    sampleRate float64
    random     *rand.Rand
}

func (sl *SamplingLogger) InfoWithSampling(ctx context.Context, msg string, args ...any) {
    if sl.random.Float64() < sl.sampleRate {
        sl.logger.InfoContext(ctx, msg, args...)
    }
}
```

### ログ収集とアラート
- **収集**: Fluent Bitによる収集、Elasticsearchに送信
- **可視化**: Kibanaでダッシュボード作成
- **アラート**: ElastWatch or Prometheusアラートマネージャーでアラート設定

### セキュリティ考慮事項
- **PII除外**: JWTトークン、パスワード、APIキーはマスクして記録
- **機密情報の検出**: 正規表現による自動マスキング

```go
func sanitizeLogField(key, value string) string {
    sensitivePatterns := map[string]*regexp.Regexp{
        "authorization": regexp.MustCompile(`Bearer\s+(.+)`),
        "api_key":       regexp.MustCompile(`([a-zA-Z0-9]{32,})`),
        "password":      regexp.MustCompile(`.*`),
    }
    
    if pattern, exists := sensitivePatterns[strings.ToLower(key)]; exists {
        return pattern.ReplaceAllString(value, "[REDACTED]")
    }
    return value
}
```

## 14. ドメインオブジェクトとキャッシュ・設定のマッピング

### Gateway Request Context → Redis Cache

API Gatewayは直接的なデータベースを持たないため、主にRedisキャッシュと設定ファイルでデータを管理します。

#### JWT検証結果キャッシュ
```go
// AuthenticationContext → Redis Hash
type AuthCacheEntry struct {
    UserID    string    `json:"user_id"`
    Scopes    []string  `json:"scopes"`
    ExpiresAt time.Time `json:"expires_at"`
    IssuedAt  time.Time `json:"issued_at"`
    Subject   string    `json:"subject"`
    Issuer    string    `json:"issuer"`
}

// Redis Key: jwt_validation:{jti}
// TTL: JWT有効期限まで
func (a *AuthCacheEntry) ToRedisHash() map[string]interface{} {
    return map[string]interface{}{
        "user_id":    a.UserID,
        "scopes":     strings.Join(a.Scopes, ","),
        "expires_at": a.ExpiresAt.Unix(),
        "issued_at":  a.IssuedAt.Unix(),
        "subject":    a.Subject,
        "issuer":     a.Issuer,
    }
}
```

#### レート制限状態キャッシュ
```go
// RateLimitBucket → Redis String (Counter)
type RateLimitEntry struct {
    Count       int       `json:"count"`
    WindowStart time.Time `json:"window_start"`
    Limit       int       `json:"limit"`
    ResetAt     time.Time `json:"reset_at"`
}

// Redis Key Pattern: rate_limit:{user_id}:{endpoint_hash}:{window}
// Example: rate_limit:user123:drops_create:1641024000
// TTL: Window期間（通常1時間）
```

#### サーキットブレーカー状態キャッシュ
```go
// CircuitBreakerPolicy → Redis Hash
type CircuitBreakerEntry struct {
    State        string    `json:"state"`         // CLOSED, OPEN, HALF_OPEN
    FailureCount int       `json:"failure_count"`
    LastFailure  time.Time `json:"last_failure"`
    NextRetry    time.Time `json:"next_retry,omitempty"`
    SuccessCount int       `json:"success_count,omitempty"`
}

// Redis Key: circuit_breaker:{service_name}
// Example: circuit_breaker:avion-drop
// TTL: 状態により動的（OPEN: 5分、HALF_OPEN: 1分、CLOSED: なし）
```

### ルーティング設定 → ConfigMap

```yaml
# kubernetes/configmap/gateway-routes.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: gateway-routes
  namespace: avion
data:
  routes.yaml: |
    routes:
      # Drop関連エンドポイント
      - path: "/api/v1/drops"
        methods: ["GET", "POST"]
        target_service: "avion-drop"
        target_port: 9000
        auth_required: true
        rate_limit:
          requests_per_hour: 1000
          burst: 100
      
      - path: "/api/v1/drops/{id}"
        methods: ["GET", "PATCH", "DELETE"]
        target_service: "avion-drop"
        target_port: 9000
        auth_required: true
        rate_limit:
          requests_per_hour: 2000
          burst: 200
      
      # IAM関連エンドポイント
      - path: "/api/v1/auth/login"
        methods: ["POST"]
        target_service: "avion-auth"
        target_port: 9000
        auth_required: false
        rate_limit:
          requests_per_hour: 100
          burst: 10
      
      # ActivityPub関連
      - path: "/inbox"
        methods: ["POST"]
        target_service: "avion-activitypub"
        target_port: 9000
        auth_required: false
        rate_limit:
          requests_per_hour: 10000
          burst: 1000
      
      - path: "/users/{username}/inbox"
        methods: ["POST"]
        target_service: "avion-activitypub"
        target_port: 9000
        auth_required: false
        rate_limit:
          requests_per_hour: 5000
          burst: 500
```

### ルーティングルール → Domain Model マッピング

```go
// RouteTarget Domain Object
type RouteTarget struct {
    ServiceName   ServiceName      `json:"service_name"`
    Port          int             `json:"port"`
    Path          string          `json:"path"`
    Methods       []HTTPMethod    `json:"methods"`
    AuthRequired  bool            `json:"auth_required"`
    RateLimit     RateLimitConfig `json:"rate_limit"`
    Timeout       time.Duration   `json:"timeout"`
    RetryPolicy   RetryConfig     `json:"retry_policy"`
}

type RateLimitConfig struct {
    RequestsPerHour int           `json:"requests_per_hour"`
    Burst          int           `json:"burst"`
    WindowSize     time.Duration `json:"window_size"`
}

type RetryConfig struct {
    MaxAttempts     int           `json:"max_attempts"`
    InitialInterval time.Duration `json:"initial_interval"`
    MaxInterval     time.Duration `json:"max_interval"`
    Multiplier      float64       `json:"multiplier"`
}

// ConfigMapからDomain Objectへのマッピング関数
func (rm *RouteConfigManager) LoadRoutesFromConfigMap() (map[string]*RouteTarget, error) {
    var config RouteConfig
    if err := yaml.Unmarshal(rm.configData, &config); err != nil {
        return nil, err
    }
    
    routes := make(map[string]*RouteTarget)
    for _, route := range config.Routes {
        for _, method := range route.Methods {
            key := buildRouteKey(route.Path, HTTPMethod(method))
            routes[key] = &RouteTarget{
                ServiceName:  ServiceName(route.TargetService),
                Port:         route.TargetPort,
                Path:         route.Path,
                Methods:      convertMethods(route.Methods),
                AuthRequired: route.AuthRequired,
                RateLimit: RateLimitConfig{
                    RequestsPerHour: route.RateLimit.RequestsPerHour,
                    Burst:          route.RateLimit.Burst,
                    WindowSize:     time.Hour,
                },
                Timeout: time.Duration(route.Timeout) * time.Second,
                RetryPolicy: RetryConfig{
                    MaxAttempts:     route.RetryPolicy.MaxAttempts,
                    InitialInterval: time.Duration(route.RetryPolicy.InitialInterval) * time.Millisecond,
                    MaxInterval:     time.Duration(route.RetryPolicy.MaxInterval) * time.Second,
                    Multiplier:      route.RetryPolicy.Multiplier,
                },
            }
        }
    }
    return routes, nil
}
```

### JWT公開鍵キャッシュ

```go
// JWT公開鍵のメモリキャッシュ（Redis + in-memory）
type JWTPublicKeyCache struct {
    keys       map[string]*rsa.PublicKey
    mu         sync.RWMutex
    redisClient *redis.Client
    ttl        time.Duration
}

// Redis Key: jwt_public_key:{kid}
// Value: PEM形式の公開鍵
// TTL: 24時間（定期更新）

func (jc *JWTPublicKeyCache) GetPublicKey(kid string) (*rsa.PublicKey, error) {
    // メモリキャッシュチェック
    jc.mu.RLock()
    key, exists := jc.keys[kid]
    jc.mu.RUnlock()
    
    if exists {
        return key, nil
    }
    
    // Redisからロード
    pemData, err := jc.redisClient.Get(context.Background(), "jwt_public_key:"+kid).Result()
    if err != nil {
        if errors.Is(err, redis.Nil) {
            return nil, error.ErrInvalidJWT
        }
        return nil, err
    }
    
    // PEM解析してメモリキャッシュに保存
    publicKey, err := jwt.ParseRSAPublicKeyFromPEM([]byte(pemData))
    if err != nil {
        return nil, error.ErrInvalidJWT
    }
    
    jc.mu.Lock()
    jc.keys[kid] = publicKey
    jc.mu.Unlock()
    
    return publicKey, nil
}
```

### メトリクス収集用データ構造

```go
// Prometheus メトリクス収集のためのラベル構造
type MetricsLabels struct {
    Method        string // HTTP method
    Path          string // Request path (テンプレート化)
    StatusCode    string // HTTP status code
    TargetService string // Backend service name
    AuthMethod    string // Authentication method
    ErrorCode     string // Error code (if any)
}

// Example:
// http_requests_total{method="POST",path="/api/v1/drops",status="200",service="avion-drop",auth="jwt"}
// http_request_duration_seconds{method="GET",path="/api/v1/drops/{id}",service="avion-drop"}
// rate_limit_triggered_total{method="POST",path="/api/v1/drops",user_id="user123"}
```

## 15. GraphQL Schema Design

### 主要型定義

```graphql
# スカラー型
scalar DateTime
scalar Cursor
scalar ID

# ルート型
type Query {
  # ユーザー関連
  me: User!
  user(id: ID!): User
  users(first: Int!, after: Cursor): UserConnection!
  
  # タイムライン
  homeTimeline(first: Int!, after: Cursor): TimelineConnection!
  globalTimeline(first: Int!, after: Cursor): TimelineConnection!
  localTimeline(instanceId: ID!, first: Int!, after: Cursor): TimelineConnection!
  
  # Drop関連
  drop(id: ID!): Drop
  drops(userID: ID, first: Int!, after: Cursor): DropConnection!
  
  # 通知
  notifications(first: Int!, after: Cursor, unreadOnly: Boolean): NotificationConnection!
  notificationCount: NotificationCount!
  
  # 検索
  searchDrops(query: String!, first: Int!, after: Cursor): DropConnection!
  searchUsers(query: String!, first: Int!, after: Cursor): UserConnection!
}

type Mutation {
  # 認証
  login(input: LoginInput!): AuthPayload!
  logout: Boolean!
  refreshToken(token: String!): AuthPayload!
  
  # Drop操作
  createDrop(input: CreateDropInput!): Drop!
  updateDrop(id: ID!, input: UpdateDropInput!): Drop!
  deleteDrop(id: ID!): DeleteResult!
  
  # リアクション
  addReaction(dropId: ID!, emoji: String!): Reaction!
  removeReaction(dropId: ID!, emoji: String!): Boolean!
  
  # フォロー
  followUser(userId: ID!): User!
  unfollowUser(userId: ID!): User!
  
  # 通知
  markNotificationAsRead(id: ID!): Notification!
  markAllNotificationsAsRead: Boolean!
}

type Subscription {
  # リアルタイム更新
  timelineUpdates(timelineType: TimelineType!): TimelineUpdate!
  notificationReceived: Notification!
  dropUpdated(dropId: ID!): Drop!
}
```

### DataLoader実装

```go
// UserDataLoader - ユーザー情報のバッチローディング
type UserDataLoader struct {
    batchFn func(context.Context, []string) (map[string]*User, error)
    wait    time.Duration
    maxBatch int
}

func NewUserDataLoader(client UserServiceClient) *UserDataLoader {
    return &UserDataLoader{
        batchFn: func(ctx context.Context, userIDs []string) (map[string]*User, error) {
            // バッチでユーザー情報を取得
            users, err := client.GetUsers(ctx, &GetUsersRequest{UserIDs: userIDs})
            if err != nil {
                return nil, err
            }
            
            result := make(map[string]*User)
            for _, user := range users.Users {
                result[user.ID] = user
            }
            return result, nil
        },
        wait: 10 * time.Millisecond,
        maxBatch: 100,
    }
}

// GraphQL Resolver with DataLoader
func (r *queryResolver) User(ctx context.Context, id string) (*User, error) {
    // DataLoaderを使用してバッチング
    loader := GetUserDataLoader(ctx)
    return loader.Load(ctx, id)
}
```

### 複雑度計算

```go
// GraphQLクエリの複雑度計算
func CalculateQueryComplexity(query string, variables map[string]interface{}) (int, error) {
    doc, err := parser.Parse(parser.ParseParams{Source: query})
    if err != nil {
        return 0, err
    }
    
    complexity := 0
    visitor.Visit(doc, &visitor.VisitorOptions{
        Enter: func(p visitor.VisitFuncParams) (string, interface{}) {
            switch node := p.Node.(type) {
            case *ast.Field:
                // フィールドごとの複雑度を計算
                fieldComplexity := getFieldComplexity(node.Name.Value)
                
                // リスト型の場合は要求数を掛ける
                if first, ok := getArgument(node, "first"); ok {
                    if value, ok := first.(int); ok {
                        fieldComplexity *= value
                    }
                }
                
                complexity += fieldComplexity
            }
            return visitor.ActionNoChange, nil
        },
    }, nil)
    
    return complexity, nil
}
```

## 16. Integration Specifications

### 16.1 gRPC Service Contracts

#### Service Discovery Mechanisms

```go
// サービス発見設定
type ServiceDiscoveryConfig struct {
    ConsulAddress      string `env:"CONSUL_ADDRESS" default:"consul:8500"`
    ServiceRegistry    string `env:"SERVICE_REGISTRY" default:"consul"`
    HealthCheckInterval time.Duration `env:"HEALTH_CHECK_INTERVAL" default:"30s"`
    DeregisterTimeout  time.Duration `env:"DEREGISTER_TIMEOUT" default:"10m"`
}

// サービス登録
func (gw *Gateway) registerService() error {
    consulClient, err := consul.NewClient(&consul.Config{
        Address: gw.config.ServiceDiscovery.ConsulAddress,
    })
    if err != nil {
        return fmt.Errorf("failed to create consul client: %w", err)
    }

    registration := &consul.AgentServiceRegistration{
        ID:      fmt.Sprintf("avion-gateway-%s", gw.instanceID),
        Name:    "avion-gateway",
        Port:    gw.config.Server.Port,
        Address: gw.config.Server.Host,
        Tags:    []string{"gateway", "graphql", "api"},
        Check: &consul.AgentServiceCheck{
            HTTP:                           fmt.Sprintf("http://%s:%d/health", gw.config.Server.Host, gw.config.Server.Port),
            Interval:                       gw.config.ServiceDiscovery.HealthCheckInterval.String(),
            Timeout:                        "10s",
            DeregisterCriticalServiceAfter: gw.config.ServiceDiscovery.DeregisterTimeout.String(),
        },
    }

    return consulClient.Agent().ServiceRegister(registration)
}
```

#### Load Balancing Strategies

```go
// 負荷分散戦略設定
type LoadBalancingConfig struct {
    Strategy         string        `env:"LB_STRATEGY" default:"round_robin"`
    MaxConnections   int           `env:"MAX_CONNECTIONS_PER_SERVICE" default:"100"`
    ConnectionTimeout time.Duration `env:"CONNECTION_TIMEOUT" default:"5s"`
    MaxRetries       int           `env:"MAX_RETRIES" default:"3"`
}

// gRPC負荷分散設定
func (gw *Gateway) setupGRPCLoadBalancing() error {
    // Consul resolver for service discovery
    resolver.Register(consulresolver.NewBuilder())

    // 各サービスの接続設定
    serviceConfigs := map[string]*grpc.ClientConn{
        "avion-auth":     gw.createServiceConnection("consul:///avion-auth"),
        "avion-user":     gw.createServiceConnection("consul:///avion-user"),
        "avion-drop":     gw.createServiceConnection("consul:///avion-drop"),
        "avion-timeline": gw.createServiceConnection("consul:///avion-timeline"),
        "avion-search":   gw.createServiceConnection("consul:///avion-search"),
    }

    gw.serviceConnections = serviceConfigs
    return nil
}

func (gw *Gateway) createServiceConnection(target string) *grpc.ClientConn {
    conn, err := grpc.Dial(target,
        grpc.WithTransportCredentials(insecure.NewCredentials()),
        grpc.WithDefaultServiceConfig(`{
            "loadBalancingPolicy": "round_robin",
            "healthCheckConfig": {
                "serviceName": ""
            },
            "retryPolicy": {
                "maxAttempts": 3,
                "initialBackoff": "0.1s",
                "maxBackoff": "1s",
                "backoffMultiplier": 2.0,
                "retryableStatusCodes": ["UNAVAILABLE", "DEADLINE_EXCEEDED"]
            }
        }`),
        grpc.WithKeepaliveParams(keepalive.ClientParameters{
            Time:                10 * time.Second,
            Timeout:             time.Second,
            PermitWithoutStream: true,
        }),
    )
    if err != nil {
        gw.logger.Error("Failed to create gRPC connection", 
            zap.String("target", target), zap.Error(err))
        return nil
    }
    return conn
}
```

#### Health Check Protocols

```go
// ヘルスチェック実装
type HealthChecker struct {
    services map[string]healthpb.HealthClient
    logger   *zap.Logger
}

func (hc *HealthChecker) CheckServiceHealth(ctx context.Context, serviceName string) error {
    client, exists := hc.services[serviceName]
    if !exists {
        return fmt.Errorf("service %s not registered", serviceName)
    }

    resp, err := client.Check(ctx, &healthpb.HealthCheckRequest{
        Service: serviceName,
    })
    if err != nil {
        return fmt.Errorf("health check failed for %s: %w", serviceName, err)
    }

    if resp.Status != healthpb.HealthCheckResponse_SERVING {
        return fmt.Errorf("service %s is not serving (status: %v)", serviceName, resp.Status)
    }

    return nil
}

// 定期ヘルスチェック
func (gw *Gateway) startHealthChecking() {
    ticker := time.NewTicker(30 * time.Second)
    go func() {
        defer ticker.Stop()
        for {
            select {
            case <-ticker.C:
                gw.performHealthChecks()
            case <-gw.shutdownCh:
                return
            }
        }
    }()
}
```

#### Connection Pooling Configuration

```go
// 接続プール設定
type ConnectionPoolConfig struct {
    MaxIdleConns        int           `env:"MAX_IDLE_CONNS" default:"50"`
    MaxOpenConns        int           `env:"MAX_OPEN_CONNS" default:"100"`
    ConnMaxLifetime     time.Duration `env:"CONN_MAX_LIFETIME" default:"1h"`
    ConnMaxIdleTime     time.Duration `env:"CONN_MAX_IDLE_TIME" default:"10m"`
    KeepaliveTime       time.Duration `env:"KEEPALIVE_TIME" default:"30s"`
    KeepaliveTimeout    time.Duration `env:"KEEPALIVE_TIMEOUT" default:"5s"`
}

// gRPC接続プール管理
type GRPCConnectionPool struct {
    pools  map[string]*connectionPool
    config *ConnectionPoolConfig
    mu     sync.RWMutex
}

type connectionPool struct {
    connections chan *grpc.ClientConn
    factory     func() (*grpc.ClientConn, error)
    mu          sync.Mutex
    closed      bool
}

func (pool *connectionPool) Get() (*grpc.ClientConn, error) {
    select {
    case conn := <-pool.connections:
        return conn, nil
    default:
        return pool.factory()
    }
}

func (pool *connectionPool) Put(conn *grpc.ClientConn) {
    if pool.closed {
        conn.Close()
        return
    }
    
    select {
    case pool.connections <- conn:
    default:
        conn.Close()
    }
}
```

### 16.2 Backend Service Integration

#### avion-auth Service Integration Patterns

```go
// 認証サービス統合
type AuthServiceIntegration struct {
    client      authpb.AuthServiceClient
    cache       cache.Cache
    circuitBE   *circuitbreaker.CircuitBreaker
    timeout     time.Duration
}

func (asi *AuthServiceIntegration) ValidateToken(ctx context.Context, token string) (*authpb.TokenValidationResponse, error) {
    // キャッシュから検証結果を確認
    if cached, found := asi.cache.Get(fmt.Sprintf("token_validation:%s", token)); found {
        if validation, ok := cached.(*authpb.TokenValidationResponse); ok {
            return validation, nil
        }
    }

    // サーキットブレーカーでラップ
    result, err := asi.circuitBE.Execute(func() (interface{}, error) {
        ctx, cancel := context.WithTimeout(ctx, asi.timeout)
        defer cancel()

        return asi.client.ValidateToken(ctx, &authpb.TokenValidationRequest{
            Token: token,
        })
    })

    if err != nil {
        return nil, fmt.Errorf("token validation failed: %w", err)
    }

    validation := result.(*authpb.TokenValidationResponse)
    
    // 成功した場合はキャッシュに保存
    if validation.Valid {
        asi.cache.Set(fmt.Sprintf("token_validation:%s", token), validation, 5*time.Minute)
    }

    return validation, nil
}

// 権限チェック
func (asi *AuthServiceIntegration) CheckPermission(ctx context.Context, userID string, resource string, action string) (bool, error) {
    resp, err := asi.client.CheckPermission(ctx, &authpb.PermissionCheckRequest{
        UserId:   userID,
        Resource: resource,
        Action:   action,
    })
    if err != nil {
        return false, fmt.Errorf("permission check failed: %w", err)
    }
    return resp.Allowed, nil
}
```

#### avion-user Service Communication

```go
// ユーザーサービス統合
type UserServiceIntegration struct {
    client    userpb.UserServiceClient
    dataLoader *dataloader.Loader
    cache     cache.Cache
}

func (usi *UserServiceIntegration) GetUser(ctx context.Context, userID string) (*userpb.User, error) {
    // DataLoaderでバッチング
    thunk := usi.dataLoader.Load(ctx, dataloader.StringKey(userID))
    result, err := thunk()
    if err != nil {
        return nil, err
    }
    return result.(*userpb.User), nil
}

// DataLoader実装
func (usi *UserServiceIntegration) createUserDataLoader() *dataloader.Loader {
    return dataloader.NewBatchedLoader(func(ctx context.Context, keys dataloader.Keys) []*dataloader.Result {
        userIDs := make([]string, len(keys))
        for i, key := range keys {
            userIDs[i] = key.String()
        }

        resp, err := usi.client.GetUsers(ctx, &userpb.GetUsersRequest{
            UserIds: userIDs,
        })

        results := make([]*dataloader.Result, len(keys))
        if err != nil {
            for i := range results {
                results[i] = &dataloader.Result{Error: err}
            }
            return results
        }

        userMap := make(map[string]*userpb.User)
        for _, user := range resp.Users {
            userMap[user.Id] = user
        }

        for i, userID := range userIDs {
            if user, found := userMap[userID]; found {
                results[i] = &dataloader.Result{Data: user}
            } else {
                results[i] = &dataloader.Result{Error: fmt.Errorf("user not found: %s", userID)}
            }
        }

        return results
    }, dataloader.WithBatchTimeout(50*time.Millisecond))
}
```

#### avion-drop Service Interaction

```go
// Dropサービス統合
type DropServiceIntegration struct {
    client      droppb.DropServiceClient
    cache       cache.Cache
    eventBus    eventbus.EventBus
}

func (dsi *DropServiceIntegration) CreateDrop(ctx context.Context, req *droppb.CreateDropRequest) (*droppb.Drop, error) {
    // リクエスト検証
    if err := dsi.validateCreateDropRequest(req); err != nil {
        return nil, fmt.Errorf("invalid request: %w", err)
    }

    // Drop作成
    drop, err := dsi.client.CreateDrop(ctx, req)
    if err != nil {
        return nil, fmt.Errorf("failed to create drop: %w", err)
    }

    // イベント発行
    event := events.DropCreatedEvent{
        DropID:    drop.Id,
        UserID:    drop.UserId,
        CreatedAt: drop.CreatedAt.AsTime(),
    }
    dsi.eventBus.Publish(ctx, "drop.created", event)

    // キャッシュ更新
    dsi.cache.Delete(fmt.Sprintf("user_drops:%s", drop.UserId))

    return drop, nil
}

// Dropの取得（キャッシュ付き）
func (dsi *DropServiceIntegration) GetDrop(ctx context.Context, dropID string) (*droppb.Drop, error) {
    cacheKey := fmt.Sprintf("drop:%s", dropID)
    
    if cached, found := dsi.cache.Get(cacheKey); found {
        if drop, ok := cached.(*droppb.Drop); ok {
            return drop, nil
        }
    }

    drop, err := dsi.client.GetDrop(ctx, &droppb.GetDropRequest{
        DropId: dropID,
    })
    if err != nil {
        return nil, err
    }

    // 5分間キャッシュ
    dsi.cache.Set(cacheKey, drop, 5*time.Minute)
    return drop, nil
}
```

#### Error Handling and Fallback Strategies

```go
// エラーハンドリングとフォールバック戦略
type ServiceErrorHandler struct {
    logger       *zap.Logger
    metrics      *prometheus.CounterVec
    fallbackCache cache.Cache
}

func (seh *ServiceErrorHandler) HandleServiceError(serviceName string, operation string, err error) error {
    // メトリクス記録
    seh.metrics.WithLabelValues(serviceName, operation, "error").Inc()

    // エラータイプ別処理
    switch {
    case isTimeoutError(err):
        seh.logger.Warn("Service timeout", 
            zap.String("service", serviceName),
            zap.String("operation", operation),
            zap.Error(err))
        return NewServiceUnavailableError(serviceName, "Request timeout")

    case isUnavailableError(err):
        seh.logger.Error("Service unavailable",
            zap.String("service", serviceName),
            zap.String("operation", operation),
            zap.Error(err))
        return NewServiceUnavailableError(serviceName, "Service temporarily unavailable")

    case isAuthenticationError(err):
        return NewAuthenticationError("Authentication failed")

    case isAuthorizationError(err):
        return NewAuthorizationError("Permission denied")

    default:
        seh.logger.Error("Unexpected service error",
            zap.String("service", serviceName),
            zap.String("operation", operation),
            zap.Error(err))
        return NewInternalServerError("Internal service error")
    }
}

// フォールバック応答
func (seh *ServiceErrorHandler) GetFallbackResponse(serviceName string, operation string, key string) (interface{}, bool) {
    fallbackKey := fmt.Sprintf("fallback:%s:%s:%s", serviceName, operation, key)
    return seh.fallbackCache.Get(fallbackKey)
}
```

### 16.3 Event-Driven Integration Patterns

#### Redis Pub/Sub Event Schemas

```go
// イベントスキーマ定義
type EventSchema struct {
    EventType   string                 `json:"event_type"`
    Version     string                 `json:"version"`
    Timestamp   time.Time              `json:"timestamp"`
    Source      string                 `json:"source"`
    TraceID     string                 `json:"trace_id"`
    Data        map[string]interface{} `json:"data"`
    Metadata    EventMetadata          `json:"metadata"`
}

type EventMetadata struct {
    CorrelationID string            `json:"correlation_id"`
    UserID        string            `json:"user_id,omitempty"`
    SessionID     string            `json:"session_id,omitempty"`
    Tags          map[string]string `json:"tags,omitempty"`
}

// イベントタイプ定義
const (
    EventTypeDropCreated     = "drop.created"
    EventTypeDropUpdated     = "drop.updated"
    EventTypeDropDeleted     = "drop.deleted"
    EventTypeReactionAdded   = "reaction.added"
    EventTypeReactionRemoved = "reaction.removed"
    EventTypeUserFollowed    = "user.followed"
    EventTypeUserUnfollowed  = "user.unfollowed"
    EventTypeNotificationCreated = "notification.created"
)

// イベント発行
func (gw *Gateway) publishEvent(ctx context.Context, eventType string, data interface{}) error {
    traceID := trace.SpanFromContext(ctx).SpanContext().TraceID().String()
    
    event := EventSchema{
        EventType: eventType,
        Version:   "1.0",
        Timestamp: time.Now(),
        Source:    "avion-gateway",
        TraceID:   traceID,
        Data:      data,
        Metadata: EventMetadata{
            CorrelationID: generateCorrelationID(),
            UserID:        getCurrentUserID(ctx),
            SessionID:     getSessionID(ctx),
        },
    }

    eventJSON, err := json.Marshal(event)
    if err != nil {
        return fmt.Errorf("failed to marshal event: %w", err)
    }

    return gw.redisClient.Publish(ctx, eventType, eventJSON).Err()
}
```

#### Event Routing and Filtering

```go
// イベントルーティング設定
type EventRouter struct {
    subscribers map[string][]EventHandler
    filters     map[string][]EventFilter
    mu          sync.RWMutex
}

type EventHandler interface {
    Handle(ctx context.Context, event EventSchema) error
    GetEventTypes() []string
}

type EventFilter interface {
    ShouldProcess(event EventSchema) bool
}

// ユーザー固有フィルター
type UserSpecificFilter struct {
    userID string
}

func (f *UserSpecificFilter) ShouldProcess(event EventSchema) bool {
    return event.Metadata.UserID == f.userID || 
           f.isUserRelatedEvent(event)
}

// イベント処理
func (er *EventRouter) ProcessEvent(ctx context.Context, event EventSchema) {
    er.mu.RLock()
    handlers := er.subscribers[event.EventType]
    filters := er.filters[event.EventType]
    er.mu.RUnlock()

    // フィルタリング
    for _, filter := range filters {
        if !filter.ShouldProcess(event) {
            return
        }
    }

    // 並行処理
    var wg sync.WaitGroup
    for _, handler := range handlers {
        wg.Add(1)
        go func(h EventHandler) {
            defer wg.Done()
            if err := h.Handle(ctx, event); err != nil {
                log.Printf("Event handler error: %v", err)
            }
        }(handler)
    }
    wg.Wait()
}
```

#### Event Ordering Guarantees

```go
// イベント順序保証
type OrderedEventProcessor struct {
    queues    map[string]chan EventSchema
    processor map[string]*sequentialProcessor
    mu        sync.RWMutex
}

type sequentialProcessor struct {
    queue   chan EventSchema
    handler EventHandler
    done    chan struct{}
}

func (oep *OrderedEventProcessor) ProcessEvent(event EventSchema) {
    // ユーザーIDをキーとして順序保証
    key := event.Metadata.UserID
    if key == "" {
        key = "global"
    }

    oep.mu.RLock()
    queue, exists := oep.queues[key]
    oep.mu.RUnlock()

    if !exists {
        oep.createSequentialProcessor(key)
        queue = oep.queues[key]
    }

    select {
    case queue <- event:
    case <-time.After(5 * time.Second):
        log.Printf("Event queue full for key: %s", key)
    }
}

func (oep *OrderedEventProcessor) createSequentialProcessor(key string) {
    oep.mu.Lock()
    defer oep.mu.Unlock()

    if _, exists := oep.queues[key]; exists {
        return
    }

    queue := make(chan EventSchema, 1000)
    processor := &sequentialProcessor{
        queue: queue,
        done:  make(chan struct{}),
    }

    oep.queues[key] = queue
    oep.processor[key] = processor

    go processor.run()
}
```

#### Dead Letter Queue Handling

```go
// デッドレターキューハンドリング
type DeadLetterQueueHandler struct {
    dlqClient    redis.Cmdable
    maxRetries   int
    retryDelay   time.Duration
    alertManager AlertManager
}

func (dlq *DeadLetterQueueHandler) HandleFailedEvent(event EventSchema, err error, retryCount int) {
    if retryCount >= dlq.maxRetries {
        // DLQに送信
        dlq.sendToDeadLetterQueue(event, err)
        dlq.alertManager.SendAlert("Event processing failed permanently", map[string]interface{}{
            "event_type": event.EventType,
            "trace_id":   event.TraceID,
            "error":      err.Error(),
        })
        return
    }

    // リトライスケジュール
    dlq.scheduleRetry(event, retryCount+1)
}

func (dlq *DeadLetterQueueHandler) sendToDeadLetterQueue(event EventSchema, err error) {
    dlqEvent := DeadLetterEvent{
        OriginalEvent: event,
        Error:         err.Error(),
        Timestamp:     time.Now(),
        RetryCount:    dlq.maxRetries,
    }

    eventJSON, _ := json.Marshal(dlqEvent)
    dlq.dlqClient.LPush(context.Background(), "dlq:events", eventJSON)
}

func (dlq *DeadLetterQueueHandler) scheduleRetry(event EventSchema, retryCount int) {
    delay := time.Duration(retryCount) * dlq.retryDelay
    
    retryEvent := RetryEvent{
        Event:      event,
        RetryCount: retryCount,
        ScheduledAt: time.Now().Add(delay),
    }

    eventJSON, _ := json.Marshal(retryEvent)
    dlq.dlqClient.ZAdd(context.Background(), "retry:events", &redis.Z{
        Score:  float64(time.Now().Add(delay).Unix()),
        Member: eventJSON,
    })
}
```

### 16.4 Circuit Breaker Configuration

#### Threshold Values for Each Service

```go
// サーキットブレーカー設定
type CircuitBreakerConfig struct {
    AuthService struct {
        FailureThreshold    int           `env:"AUTH_CB_FAILURE_THRESHOLD" default:"5"`
        RecoveryTimeout     time.Duration `env:"AUTH_CB_RECOVERY_TIMEOUT" default:"30s"`
        Timeout             time.Duration `env:"AUTH_CB_TIMEOUT" default:"5s"`
        MaxConcurrentReqs   int           `env:"AUTH_CB_MAX_CONCURRENT" default:"100"`
    }
    UserService struct {
        FailureThreshold    int           `env:"USER_CB_FAILURE_THRESHOLD" default:"10"`
        RecoveryTimeout     time.Duration `env:"USER_CB_RECOVERY_TIMEOUT" default:"60s"`
        Timeout             time.Duration `env:"USER_CB_TIMEOUT" default:"10s"`
        MaxConcurrentReqs   int           `env:"USER_CB_MAX_CONCURRENT" default:"200"`
    }
    DropService struct {
        FailureThreshold    int           `env:"DROP_CB_FAILURE_THRESHOLD" default:"15"`
        RecoveryTimeout     time.Duration `env:"DROP_CB_RECOVERY_TIMEOUT" default:"45s"`
        Timeout             time.Duration `env:"DROP_CB_TIMEOUT" default:"15s"`
        MaxConcurrentReqs   int           `env:"DROP_CB_MAX_CONCURRENT" default:"300"`
    }
    TimelineService struct {
        FailureThreshold    int           `env:"TIMELINE_CB_FAILURE_THRESHOLD" default:"20"`
        RecoveryTimeout     time.Duration `env:"TIMELINE_CB_RECOVERY_TIMEOUT" default:"90s"`
        Timeout             time.Duration `env:"TIMELINE_CB_TIMEOUT" default:"20s"`
        MaxConcurrentReqs   int           `env:"TIMELINE_CB_MAX_CONCURRENT" default:"500"`
    }
    SearchService struct {
        FailureThreshold    int           `env:"SEARCH_CB_FAILURE_THRESHOLD" default:"8"`
        RecoveryTimeout     time.Duration `env:"SEARCH_CB_RECOVERY_TIMEOUT" default:"120s"`
        Timeout             time.Duration `env:"SEARCH_CB_TIMEOUT" default:"30s"`
        MaxConcurrentReqs   int           `env:"SEARCH_CB_MAX_CONCURRENT" default:"100"`
    }
}

// サーキットブレーカー初期化
func (gw *Gateway) initializeCircuitBreakers() {
    gw.circuitBreakers = map[string]*hystrix.Circuit{
        "auth": hystrix.NewCircuit(hystrix.CommandConfig{
            Name:                   "auth-service",
            Timeout:                int(gw.config.CircuitBreaker.AuthService.Timeout.Milliseconds()),
            MaxConcurrentRequests:  gw.config.CircuitBreaker.AuthService.MaxConcurrentReqs,
            RequestVolumeThreshold: gw.config.CircuitBreaker.AuthService.FailureThreshold,
            SleepWindow:           int(gw.config.CircuitBreaker.AuthService.RecoveryTimeout.Milliseconds()),
            ErrorPercentThreshold:  50,
        }),
        "user": hystrix.NewCircuit(hystrix.CommandConfig{
            Name:                   "user-service",
            Timeout:                int(gw.config.CircuitBreaker.UserService.Timeout.Milliseconds()),
            MaxConcurrentRequests:  gw.config.CircuitBreaker.UserService.MaxConcurrentReqs,
            RequestVolumeThreshold: gw.config.CircuitBreaker.UserService.FailureThreshold,
            SleepWindow:           int(gw.config.CircuitBreaker.UserService.RecoveryTimeout.Milliseconds()),
            ErrorPercentThreshold:  50,
        }),
        // 他のサービスも同様に設定
    }
}
```

#### Retry Policies

```go
// リトライポリシー設定
type RetryPolicy struct {
    MaxAttempts      int           `env:"RETRY_MAX_ATTEMPTS" default:"3"`
    InitialInterval  time.Duration `env:"RETRY_INITIAL_INTERVAL" default:"100ms"`
    MaxInterval      time.Duration `env:"RETRY_MAX_INTERVAL" default:"5s"`
    Multiplier       float64       `env:"RETRY_MULTIPLIER" default:"2.0"`
    RandomizationFactor float64    `env:"RETRY_RANDOMIZATION" default:"0.1"`
}

// エクスポネンシャルバックオフ実装
func (rp *RetryPolicy) ExecuteWithRetry(ctx context.Context, operation func() error) error {
    var lastErr error
    interval := rp.InitialInterval

    for attempt := 0; attempt < rp.MaxAttempts; attempt++ {
        if attempt > 0 {
            // ジッターを追加
            jitter := time.Duration(float64(interval) * rp.RandomizationFactor * (rand.Float64()*2 - 1))
            waitTime := interval + jitter
            
            select {
            case <-time.After(waitTime):
            case <-ctx.Done():
                return ctx.Err()
            }
            
            // 次の間隔を計算
            interval = time.Duration(float64(interval) * rp.Multiplier)
            if interval > rp.MaxInterval {
                interval = rp.MaxInterval
            }
        }

        lastErr = operation()
        if lastErr == nil {
            return nil
        }

        // リトライ不可能なエラーの場合は即座に終了
        if !isRetryableError(lastErr) {
            return lastErr
        }
    }

    return fmt.Errorf("operation failed after %d attempts: %w", rp.MaxAttempts, lastErr)
}

func isRetryableError(err error) bool {
    // gRPCステータスコードをチェック
    if st, ok := status.FromError(err); ok {
        switch st.Code() {
        case codes.Unavailable, codes.DeadlineExceeded, codes.ResourceExhausted:
            return true
        case codes.InvalidArgument, codes.NotFound, codes.PermissionDenied:
            return false
        default:
            return true
        }
    }
    
    // ネットワークエラーはリトライ可能
    if netErr, ok := err.(net.Error); ok {
        return netErr.Timeout() || netErr.Temporary()
    }
    
    return true
}
```

#### Fallback Responses

```go
// フォールバック応答管理
type FallbackResponseManager struct {
    cache           cache.Cache
    defaultResponses map[string]interface{}
    logger          *zap.Logger
}

// サービス別フォールバック応答
func (frm *FallbackResponseManager) GetFallbackResponse(serviceName, operation string, params map[string]interface{}) interface{} {
    switch serviceName {
    case "user":
        return frm.getUserServiceFallback(operation, params)
    case "drop":
        return frm.getDropServiceFallback(operation, params)
    case "timeline":
        return frm.getTimelineServiceFallback(operation, params)
    case "search":
        return frm.getSearchServiceFallback(operation, params)
    default:
        return frm.getDefaultFallback(operation)
    }
}

func (frm *FallbackResponseManager) getUserServiceFallback(operation string, params map[string]interface{}) interface{} {
    switch operation {
    case "GetUser":
        userID := params["user_id"].(string)
        // キャッシュから取得を試行
        if cached, found := frm.cache.Get(fmt.Sprintf("user:%s", userID)); found {
            return cached
        }
        // デフォルトユーザー情報を返す
        return &userpb.User{
            Id:          userID,
            Username:    "unknown",
            DisplayName: "User Unavailable",
            Avatar:      "/default-avatar.png",
            Status:      "unavailable",
        }
    case "GetUsers":
        userIDs := params["user_ids"].([]string)
        users := make([]*userpb.User, len(userIDs))
        for i, userID := range userIDs {
            users[i] = frm.getUserServiceFallback("GetUser", map[string]interface{}{
                "user_id": userID,
            }).(*userpb.User)
        }
        return &userpb.GetUsersResponse{Users: users}
    default:
        return nil
    }
}

func (frm *FallbackResponseManager) getTimelineServiceFallback(operation string, params map[string]interface{}) interface{} {
    switch operation {
    case "GetTimeline":
        // 空のタイムラインを返す
        return &timelinepb.TimelineResponse{
            Drops:      []*timelinepb.TimelineDrop{},
            NextCursor: "",
            HasMore:    false,
            Message:    "Timeline temporarily unavailable",
        }
    default:
        return nil
    }
}
```

### 16.5 Authentication & Authorization Flow

#### JWT Validation with avion-auth

```go
// JWT検証フロー
type JWTValidator struct {
    authClient   authpb.AuthServiceClient
    cache        cache.Cache
    jwtSecret    []byte
    issuer       string
    audience     string
}

func (jv *JWTValidator) ValidateToken(ctx context.Context, tokenString string) (*Claims, error) {
    // ローカル検証を先に実行
    claims, err := jv.parseAndValidateLocally(tokenString)
    if err != nil {
        return nil, fmt.Errorf("local token validation failed: %w", err)
    }

    // キャッシュで無効化チェック
    if jv.isTokenRevoked(claims.JTI) {
        return nil, fmt.Errorf("token has been revoked")
    }

    // リモート検証（必要な場合のみ）
    if jv.needsRemoteValidation(claims) {
        if err := jv.validateWithAuthService(ctx, tokenString); err != nil {
            return nil, fmt.Errorf("remote token validation failed: %w", err)
        }
    }

    return claims, nil
}

func (jv *JWTValidator) parseAndValidateLocally(tokenString string) (*Claims, error) {
    token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
        if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
            return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
        }
        return jv.jwtSecret, nil
    })

    if err != nil {
        return nil, err
    }

    claims, ok := token.Claims.(*Claims)
    if !ok || !token.Valid {
        return nil, fmt.Errorf("invalid token claims")
    }

    // 標準クレーム検証
    if claims.Issuer != jv.issuer {
        return nil, fmt.Errorf("invalid issuer")
    }

    if !claims.VerifyAudience(jv.audience, true) {
        return nil, fmt.Errorf("invalid audience")
    }

    if claims.ExpiresAt.Before(time.Now()) {
        return nil, fmt.Errorf("token expired")
    }

    return claims, nil
}

// カスタムクレーム定義
type Claims struct {
    UserID      string   `json:"user_id"`
    Username    string   `json:"username"`
    Roles       []string `json:"roles"`
    Permissions []string `json:"permissions"`
    SessionID   string   `json:"session_id"`
    jwt.RegisteredClaims
}
```

#### Session Management Integration

```go
// セッション管理統合
type SessionManager struct {
    redisClient   redis.Cmdable
    authClient    authpb.AuthServiceClient
    sessionTTL    time.Duration
    refreshWindow time.Duration
}

func (sm *SessionManager) CreateSession(ctx context.Context, userID string, deviceInfo DeviceInfo) (*Session, error) {
    sessionID := generateSessionID()
    session := &Session{
        ID:           sessionID,
        UserID:       userID,
        DeviceInfo:   deviceInfo,
        CreatedAt:    time.Now(),
        LastActivity: time.Now(),
        IsActive:     true,
    }

    // Redisに保存
    sessionKey := fmt.Sprintf("session:%s", sessionID)
    sessionJSON, err := json.Marshal(session)
    if err != nil {
        return nil, fmt.Errorf("failed to marshal session: %w", err)
    }

    err = sm.redisClient.SetEX(ctx, sessionKey, sessionJSON, sm.sessionTTL).Err()
    if err != nil {
        return nil, fmt.Errorf("failed to store session: %w", err)
    }

    // 認証サービスに通知
    _, err = sm.authClient.CreateSession(ctx, &authpb.CreateSessionRequest{
        SessionId: sessionID,
        UserId:    userID,
        DeviceInfo: &authpb.DeviceInfo{
            UserAgent: deviceInfo.UserAgent,
            IpAddress: deviceInfo.IPAddress,
            Platform:  deviceInfo.Platform,
        },
    })
    if err != nil {
        sm.redisClient.Del(ctx, sessionKey) // ロールバック
        return nil, fmt.Errorf("failed to create session in auth service: %w", err)
    }

    return session, nil
}

func (sm *SessionManager) ValidateSession(ctx context.Context, sessionID string) (*Session, error) {
    sessionKey := fmt.Sprintf("session:%s", sessionID)
    sessionJSON, err := sm.redisClient.Get(ctx, sessionKey).Result()
    if err != nil {
        if err == redis.Nil {
            return nil, fmt.Errorf("session not found")
        }
        return nil, fmt.Errorf("failed to get session: %w", err)
    }

    var session Session
    if err := json.Unmarshal([]byte(sessionJSON), &session); err != nil {
        return nil, fmt.Errorf("failed to unmarshal session: %w", err)
    }

    if !session.IsActive {
        return nil, fmt.Errorf("session is inactive")
    }

    // アクティビティ更新
    session.LastActivity = time.Now()
    updatedJSON, _ := json.Marshal(session)
    sm.redisClient.SetEX(ctx, sessionKey, updatedJSON, sm.sessionTTL)

    return &session, nil
}
```

#### Permission Checking Patterns

```go
// 権限チェックパターン
type PermissionChecker struct {
    authClient      authpb.AuthServiceClient
    cache          cache.Cache
    defaultPolicies map[string][]string
}

// リソースベース権限チェック
func (pc *PermissionChecker) CheckResourcePermission(ctx context.Context, userID, resourceType, resourceID, action string) error {
    // キャッシュチェック
    permKey := fmt.Sprintf("perm:%s:%s:%s:%s", userID, resourceType, resourceID, action)
    if cached, found := pc.cache.Get(permKey); found {
        if allowed, ok := cached.(bool); ok && allowed {
            return nil
        } else {
            return fmt.Errorf("permission denied")
        }
    }

    // リソース所有者チェック
    if pc.isResourceOwner(ctx, userID, resourceType, resourceID) {
        pc.cache.Set(permKey, true, 5*time.Minute)
        return nil
    }

    // ロールベース権限チェック
    resp, err := pc.authClient.CheckResourcePermission(ctx, &authpb.ResourcePermissionRequest{
        UserId:       userID,
        ResourceType: resourceType,
        ResourceId:   resourceID,
        Action:       action,
    })
    if err != nil {
        return fmt.Errorf("permission check failed: %w", err)
    }

    if !resp.Allowed {
        pc.cache.Set(permKey, false, 1*time.Minute)
        return fmt.Errorf("permission denied: %s", resp.Reason)
    }

    pc.cache.Set(permKey, true, 5*time.Minute)
    return nil
}

// コンテキストベース権限チェック
func (pc *PermissionChecker) CheckContextualPermission(ctx context.Context, userID string, context PermissionContext) error {
    req := &authpb.ContextualPermissionRequest{
        UserId: userID,
        Context: &authpb.PermissionContext{
            Resource:   context.Resource,
            Action:     context.Action,
            Attributes: context.Attributes,
        },
    }

    resp, err := pc.authClient.CheckContextualPermission(ctx, req)
    if err != nil {
        return fmt.Errorf("contextual permission check failed: %w", err)
    }

    if !resp.Allowed {
        return fmt.Errorf("permission denied: %s", resp.Reason)
    }

    return nil
}

type PermissionContext struct {
    Resource   string
    Action     string
    Attributes map[string]string
}
```

#### Token Refresh Mechanisms

```go
// トークンリフレッシュメカニズム
type TokenRefreshManager struct {
    authClient       authpb.AuthServiceClient
    refreshCache     cache.Cache
    accessTokenTTL   time.Duration
    refreshTokenTTL  time.Duration
    refreshThreshold time.Duration
}

func (trm *TokenRefreshManager) RefreshToken(ctx context.Context, refreshToken string) (*TokenPair, error) {
    // リフレッシュトークン検証
    claims, err := trm.validateRefreshToken(refreshToken)
    if err != nil {
        return nil, fmt.Errorf("invalid refresh token: %w", err)
    }

    // 既存トークンの無効化
    if err := trm.revokeToken(ctx, claims.JTI); err != nil {
        return nil, fmt.Errorf("failed to revoke old token: %w", err)
    }

    // 新しいトークンペア生成
    resp, err := trm.authClient.RefreshToken(ctx, &authpb.RefreshTokenRequest{
        RefreshToken: refreshToken,
        UserId:       claims.UserID,
    })
    if err != nil {
        return nil, fmt.Errorf("token refresh failed: %w", err)
    }

    tokenPair := &TokenPair{
        AccessToken:  resp.AccessToken,
        RefreshToken: resp.RefreshToken,
        ExpiresIn:    int(trm.accessTokenTTL.Seconds()),
        TokenType:    "Bearer",
    }

    // リフレッシュトークンをキャッシュ
    trm.refreshCache.Set(
        fmt.Sprintf("refresh:%s", resp.RefreshToken),
        claims.UserID,
        trm.refreshTokenTTL,
    )

    return tokenPair, nil
}

// 自動リフレッシュチェック
func (trm *TokenRefreshManager) ShouldRefreshToken(claims *Claims) bool {
    timeToExpiry := time.Until(claims.ExpiresAt.Time)
    return timeToExpiry <= trm.refreshThreshold
}

// バックグラウンドでのトークンリフレッシュ
func (trm *TokenRefreshManager) StartAutoRefresh(ctx context.Context, tokenPair *TokenPair, onRefresh func(*TokenPair)) {
    go func() {
        ticker := time.NewTicker(trm.refreshThreshold / 2)
        defer ticker.Stop()

        for {
            select {
            case <-ticker.C:
                claims, err := trm.parseToken(tokenPair.AccessToken)
                if err != nil {
                    continue
                }

                if trm.ShouldRefreshToken(claims) {
                    newTokenPair, err := trm.RefreshToken(ctx, tokenPair.RefreshToken)
                    if err != nil {
                        continue
                    }
                    
                    tokenPair = newTokenPair
                    onRefresh(newTokenPair)
                }
            case <-ctx.Done():
                return
            }
        }
    }()
}

type TokenPair struct {
    AccessToken  string `json:"access_token"`
    RefreshToken string `json:"refresh_token"`
    ExpiresIn    int    `json:"expires_in"`
    TokenType    string `json:"token_type"`
}
```

## 17. SSE実装詳細

### イベントストリーム管理

```go
// SSE接続マネージャー
type SSEConnectionManager struct {
    connections map[ConnectionID]*SSEConnection
    userIndex   map[UserID][]ConnectionID
    mu          sync.RWMutex
    eventBuffer *CircularBuffer
    metrics     *SSEMetrics
}

// SSE接続の確立
func (m *SSEConnectionManager) EstablishConnection(ctx context.Context, userID UserID, w http.ResponseWriter) (*SSEConnection, error) {
    // ヘッダー設定
    w.Header().Set("Content-Type", "text/event-stream")
    w.Header().Set("Cache-Control", "no-cache")
    w.Header().Set("Connection", "keep-alive")
    w.Header().Set("X-Accel-Buffering", "no")
    
    conn := &SSEConnection{
        ID:        GenerateConnectionID(),
        UserID:    userID,
        Writer:    w,
        EventChan: make(chan *SSEEvent, 100),
        Done:      make(chan struct{}),
        CreatedAt: time.Now(),
    }
    
    m.mu.Lock()
    m.connections[conn.ID] = conn
    m.userIndex[userID] = append(m.userIndex[userID], conn.ID)
    m.mu.Unlock()
    
    // ハートビート開始
    go m.startHeartbeat(conn)
    
    return conn, nil
}

// イベント配信
func (m *SSEConnectionManager) BroadcastToUser(userID UserID, event *SSEEvent) error {
    m.mu.RLock()
    connIDs := m.userIndex[userID]
    m.mu.RUnlock()
    
    for _, connID := range connIDs {
        m.mu.RLock()
        conn, exists := m.connections[connID]
        m.mu.RUnlock()
        
        if !exists {
            continue
        }
        
        select {
        case conn.EventChan <- event:
            m.metrics.IncrementEventSent(event.Type)
        default:
            // バッファがフルの場合はスキップ
            m.metrics.IncrementEventDropped(event.Type)
        }
    }
    
    return nil
}

// イベントのフィルタリング
func FilterEventForUser(event *SSEEvent, userID UserID, preferences UserPreferences) bool {
    // ユーザーの設定に基づいてイベントをフィルタリング
    if event.Privacy == PrivateEvent && event.UserID != userID {
        return false
    }
    
    if preferences.MutedUsers.Contains(event.AuthorID) {
        return false
    }
    
    if preferences.BlockedUsers.Contains(event.AuthorID) {
        return false
    }
    
    return preferences.EventTypes.Contains(event.Type)
}
```

### イベントタイプ定義

```go
// SSEイベントタイプ
const (
    EventTypeTimelineUpdate    = "timeline.update"
    EventTypeDropCreated       = "drop.created"
    EventTypeDropDeleted       = "drop.deleted"
    EventTypeReactionAdded     = "reaction.added"
    EventTypeReactionRemoved   = "reaction.removed"
    EventTypeNotification      = "notification.new"
    EventTypeFollowReceived    = "follow.received"
    EventTypeFollowAccepted    = "follow.accepted"
    EventTypeMentioned         = "mention.received"
    EventTypeSystemAnnouncement = "system.announcement"
)

// SSEイベント構造
type SSEEvent struct {
    ID        string                 `json:"id"`
    Type      string                 `json:"type"`
    Data      interface{}            `json:"data"`
    UserID    UserID                 `json:"userId,omitempty"`
    AuthorID  UserID                 `json:"authorId,omitempty"`
    Privacy   EventPrivacy           `json:"privacy"`
    Timestamp time.Time              `json:"timestamp"`
    Retry     int                    `json:"retry,omitempty"`
}

// イベントをSSE形式にフォーマット
func (e *SSEEvent) Format() []byte {
    var buf bytes.Buffer
    
    if e.ID != "" {
        fmt.Fprintf(&buf, "id: %s\n", e.ID)
    }
    
    if e.Type != "" {
        fmt.Fprintf(&buf, "event: %s\n", e.Type)
    }
    
    if e.Retry > 0 {
        fmt.Fprintf(&buf, "retry: %d\n", e.Retry)
    }
    
    data, _ := json.Marshal(e.Data)
    fmt.Fprintf(&buf, "data: %s\n\n", data)
    
    return buf.Bytes()
}
```

## 18. Service-Specific Test Strategy

avion-gatewayサービスは、システム全体のエントリーポイントとして、高度な可用性と性能が要求されます。そのため、特化したテスト戦略を必要とします。

### 17.1. GraphQL Resolver Testing with DataLoader

GraphQLリゾルバーとDataLoaderの効率的なバッチング処理をテストします。

```go
// tests/graphql/resolver_test.go
package graphql_test

import (
    "context"
    "testing"
    "time"
    
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
    "go.uber.org/mock/gomock"
    
    "avion-gateway/internal/graphql"
    "avion-gateway/tests/mocks"
    "avion-gateway/tests/testhelpers"
)

func TestUserResolver_WithDataLoader(t *testing.T) {
    tests := []struct {
        name          string
        userIDs       []string
        mockSetup     func(*mocks.MockUserServiceClient)
        expectedCalls int // バッチング効果の検証
        wantError     bool
    }{
        {
            name:    "single user request",
            userIDs: []string{"user1"},
            mockSetup: func(m *mocks.MockUserServiceClient) {
                m.EXPECT().GetUsers(gomock.Any(), gomock.Any()).
                    DoAndReturn(func(ctx context.Context, req *pb.GetUsersRequest) (*pb.GetUsersResponse, error) {
                        assert.Len(t, req.UserIDs, 1)
                        return &pb.GetUsersResponse{
                            Users: []*pb.User{{ID: "user1", Username: "alice"}},
                        }, nil
                    }).Times(1)
            },
            expectedCalls: 1,
        },
        {
            name:    "multiple users - should batch",
            userIDs: []string{"user1", "user2", "user3"},
            mockSetup: func(m *mocks.MockUserServiceClient) {
                // DataLoaderが正しくバッチングしていることを確認
                m.EXPECT().GetUsers(gomock.Any(), gomock.Any()).
                    DoAndReturn(func(ctx context.Context, req *pb.GetUsersRequest) (*pb.GetUsersResponse, error) {
                        assert.Len(t, req.UserIDs, 3, "Should batch all user requests")
                        return &pb.GetUsersResponse{
                            Users: []*pb.User{
                                {ID: "user1", Username: "alice"},
                                {ID: "user2", Username: "bob"},
                                {ID: "user3", Username: "charlie"},
                            },
                        }, nil
                    }).Times(1) // 3回の個別リクエストではなく1回のバッチリクエスト
            },
            expectedCalls: 1,
        },
        {
            name:    "dataloader cache hit test",
            userIDs: []string{"user1", "user1"}, // 同じユーザーを2回要求
            mockSetup: func(m *mocks.MockUserServiceClient) {
                m.EXPECT().GetUsers(gomock.Any(), gomock.Any()).
                    Return(&pb.GetUsersResponse{
                        Users: []*pb.User{{ID: "user1", Username: "alice"}},
                    }, nil).Times(1) // キャッシュにより1回のみ
            },
            expectedCalls: 1,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Test setup
            ctrl := gomock.NewController(t)
            defer ctrl.Finish()
            
            mockUserClient := mocks.NewMockUserServiceClient(ctrl)
            tt.mockSetup(mockUserClient)
            
            // DataLoader setup
            ctx := context.Background()
            ctx = graphql.WithDataLoaders(ctx, graphql.DataLoaders{
                UserLoader: graphql.NewUserDataLoader(mockUserClient),
            })
            
            resolver := &graphql.Resolver{
                UserServiceClient: mockUserClient,
            }
            
            // Execute concurrent requests to test batching
            results := make(chan *pb.User, len(tt.userIDs))
            errors := make(chan error, len(tt.userIDs))
            
            for _, userID := range tt.userIDs {
                go func(id string) {
                    user, err := resolver.Query().User(ctx, id)
                    if err != nil {
                        errors <- err
                        return
                    }
                    results <- user
                }(userID)
            }
            
            // Wait for completion
            time.Sleep(20 * time.Millisecond) // Allow batching window
            
            // Collect results
            var users []*pb.User
            var errs []error
            for i := 0; i < len(tt.userIDs); i++ {
                select {
                case user := <-results:
                    users = append(users, user)
                case err := <-errors:
                    errs = append(errs, err)
                case <-time.After(time.Second):
                    t.Fatal("Test timeout")
                }
            }
            
            if tt.wantError {
                assert.NotEmpty(t, errs)
            } else {
                assert.Empty(t, errs)
                assert.Len(t, users, len(tt.userIDs))
            }
        })
    }
}

// GraphQL Query Complexity Testing
func TestGraphQLComplexityLimiting(t *testing.T) {
    tests := []struct {
        name          string
        query         string
        variables     map[string]interface{}
        maxComplexity int
        wantError     bool
        expectedError string
    }{
        {
            name: "simple query within limit",
            query: `
                query {
                    me {
                        id
                        username
                    }
                }
            `,
            maxComplexity: 100,
            wantError:     false,
        },
        {
            name: "complex query exceeds limit",
            query: `
                query {
                    users(first: 1000) {
                        edges {
                            node {
                                id
                                username
                                followers(first: 100) {
                                    edges {
                                        node {
                                            id
                                            username
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            `,
            maxComplexity: 1000,
            wantError:     true,
            expectedError: "query complexity exceeds maximum",
        },
        {
            name: "query with variables",
            query: `
                query GetTimeline($first: Int!) {
                    homeTimeline(first: $first) {
                        edges {
                            node {
                                id
                                content
                                author {
                                    id
                                    username
                                }
                            }
                        }
                    }
                }
            `,
            variables:     map[string]interface{}{"first": 50},
            maxComplexity: 1000,
            wantError:     false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            complexity, err := graphql.CalculateQueryComplexity(tt.query, tt.variables)
            require.NoError(t, err)
            
            if tt.wantError {
                assert.Greater(t, complexity, tt.maxComplexity)
            } else {
                assert.LessOrEqual(t, complexity, tt.maxComplexity)
            }
        })
    }
}
```

### 17.2. Rate Limiting Testing Strategies

レート制限の境界値テストと負荷条件下での動作を検証します。

```go
// tests/middleware/rate_limit_test.go
package middleware_test

import (
    "context"
    "sync"
    "testing"
    "time"
    
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
    "go.uber.org/mock/gomock"
    
    "avion-gateway/internal/middleware"
    "avion-gateway/tests/mocks"
)

func TestRateLimiter_ConcurrentRequests(t *testing.T) {
    tests := []struct {
        name               string
        limit              int
        window             time.Duration
        concurrentRequests int
        requestInterval    time.Duration
        expectedAllowed    int
        expectedDenied     int
    }{
        {
            name:               "within limit",
            limit:              10,
            window:             time.Minute,
            concurrentRequests: 5,
            requestInterval:    0,
            expectedAllowed:    5,
            expectedDenied:     0,
        },
        {
            name:               "exceeds limit",
            limit:              10,
            window:             time.Minute,
            concurrentRequests: 15,
            requestInterval:    0,
            expectedAllowed:    10,
            expectedDenied:     5,
        },
        {
            name:               "burst then steady",
            limit:              10,
            window:             time.Minute,
            concurrentRequests: 20,
            requestInterval:    100 * time.Millisecond,
            expectedAllowed:    10,
            expectedDenied:     10,
        },
        {
            name:               "sliding window test",
            limit:              5,
            window:             time.Second,
            concurrentRequests: 10,
            requestInterval:    200 * time.Millisecond, // 5 requests per second
            expectedAllowed:    5,
            expectedDenied:     5,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            ctrl := gomock.NewController(t)
            defer ctrl.Finish()
            
            mockCache := mocks.NewMockRateLimitCache(ctrl)
            rateLimiter := middleware.NewRateLimiter(mockCache, tt.limit, tt.window)
            
            // Mock setup for rate limit state
            var currentCount int64
            mockCache.EXPECT().IncrementAndGet(gomock.Any(), gomock.Any(), gomock.Any()).
                DoAndReturn(func(ctx context.Context, key string, window time.Duration) (int64, error) {
                    currentCount++
                    return currentCount, nil
                }).AnyTimes()
            
            mockCache.EXPECT().Get(gomock.Any(), gomock.Any()).
                DoAndReturn(func(ctx context.Context, key string) (int64, error) {
                    return currentCount, nil
                }).AnyTimes()
            
            // Test concurrent requests
            var wg sync.WaitGroup
            results := make(chan bool, tt.concurrentRequests)
            
            userID := "test_user"
            endpoint := "/api/v1/drops"
            
            for i := 0; i < tt.concurrentRequests; i++ {
                wg.Add(1)
                go func(index int) {
                    defer wg.Done()
                    
                    if tt.requestInterval > 0 {
                        time.Sleep(time.Duration(index) * tt.requestInterval)
                    }
                    
                    ctx := context.Background()
                    allowed, err := rateLimiter.CheckRateLimit(ctx, userID, endpoint)
                    require.NoError(t, err)
                    results <- allowed
                }(i)
            }
            
            wg.Wait()
            close(results)
            
            // Count results
            var allowed, denied int
            for result := range results {
                if result {
                    allowed++
                } else {
                    denied++
                }
            }
            
            assert.Equal(t, tt.expectedAllowed, allowed, "Allowed requests count mismatch")
            assert.Equal(t, tt.expectedDenied, denied, "Denied requests count mismatch")
        })
    }
}

// Rate Limiter Behavior Under Load
func TestRateLimiter_LoadBehavior(t *testing.T) {
    ctrl := gomock.NewController(t)
    defer ctrl.Finish()
    
    mockCache := mocks.NewMockRateLimitCache(ctrl)
    rateLimiter := middleware.NewRateLimiter(mockCache, 100, time.Minute)
    
    // Simulate Redis behavior
    buckets := make(map[string]int64)
    var mu sync.Mutex
    
    mockCache.EXPECT().IncrementAndGet(gomock.Any(), gomock.Any(), gomock.Any()).
        DoAndReturn(func(ctx context.Context, key string, window time.Duration) (int64, error) {
            mu.Lock()
            defer mu.Unlock()
            buckets[key]++
            return buckets[key], nil
        }).AnyTimes()
    
    // Load test with multiple users
    numUsers := 50
    requestsPerUser := 10
    var wg sync.WaitGroup
    
    startTime := time.Now()
    
    for userID := 0; userID < numUsers; userID++ {
        wg.Add(1)
        go func(uid int) {
            defer wg.Done()
            
            for req := 0; req < requestsPerUser; req++ {
                ctx := context.Background()
                userIDStr := fmt.Sprintf("user_%d", uid)
                _, err := rateLimiter.CheckRateLimit(ctx, userIDStr, "/api/v1/drops")
                assert.NoError(t, err)
            }
        }(userID)
    }
    
    wg.Wait()
    duration := time.Since(startTime)
    
    totalRequests := numUsers * requestsPerUser
    requestsPerSecond := float64(totalRequests) / duration.Seconds()
    
    t.Logf("Processed %d requests in %v (%.2f req/s)", 
        totalRequests, duration, requestsPerSecond)
    
    // Verify performance expectations
    assert.Less(t, duration, 5*time.Second, "Rate limiter should handle load efficiently")
}
```

### 17.3. Circuit Breaker Testing

サーキットブレーカーの状態遷移と障害復旧のテストを実装します。

```go
// tests/middleware/circuit_breaker_test.go
package middleware_test

import (
    "context"
    "errors"
    "testing"
    "time"
    
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
    "go.uber.org/mock/gomock"
    
    "avion-gateway/internal/middleware"
    "avion-gateway/internal/domain"
)

func TestCircuitBreaker_StateTransitions(t *testing.T) {
    tests := []struct {
        name            string
        initialState    domain.CircuitState
        failures        int
        successes       int
        expectedState   domain.CircuitState
        shouldCallFunc  bool
    }{
        {
            name:           "closed to open on failures",
            initialState:   domain.CircuitClosed,
            failures:       5, // threshold is 5
            successes:      0,
            expectedState:  domain.CircuitOpen,
            shouldCallFunc: false,
        },
        {
            name:           "open to half-open after timeout",
            initialState:   domain.CircuitOpen,
            failures:       0,
            successes:      0,
            expectedState:  domain.CircuitHalfOpen,
            shouldCallFunc: true,
        },
        {
            name:           "half-open to closed on success",
            initialState:   domain.CircuitHalfOpen,
            failures:       0,
            successes:      2, // threshold is 2
            expectedState:  domain.CircuitClosed,
            shouldCallFunc: true,
        },
        {
            name:           "half-open to open on failure",
            initialState:   domain.CircuitHalfOpen,
            failures:       1,
            successes:      0,
            expectedState:  domain.CircuitOpen,
            shouldCallFunc: false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            ctrl := gomock.NewController(t)
            defer ctrl.Finish()
            
            mockRepo := mocks.NewMockCircuitBreakerRepository(ctrl)
            
            serviceName := "avion-drop"
            breaker := middleware.NewCircuitBreaker(mockRepo, middleware.CircuitBreakerConfig{
                FailureThreshold: 5,
                SuccessThreshold: 2,
                Timeout:         30 * time.Second,
            })
            
            // Setup initial state
            mockRepo.EXPECT().GetState(gomock.Any(), serviceName).
                Return(tt.initialState, nil).AnyTimes()
            
            if tt.initialState == domain.CircuitOpen {
                // Simulate timeout passage
                mockRepo.EXPECT().UpdateState(gomock.Any(), serviceName, domain.CircuitHalfOpen).
                    Return(nil).Times(1)
            }
            
            // Mock state updates based on test case
            if tt.expectedState != tt.initialState {
                mockRepo.EXPECT().UpdateState(gomock.Any(), serviceName, tt.expectedState).
                    Return(nil).Times(1)
            }
            
            // Mock failure/success recording
            if tt.failures > 0 {
                mockRepo.EXPECT().RecordFailure(gomock.Any(), serviceName).
                    Return(nil).Times(tt.failures)
            }
            if tt.successes > 0 {
                mockRepo.EXPECT().RecordSuccess(gomock.Any(), serviceName).
                    Return(nil).Times(tt.successes)
            }
            
            ctx := context.Background()
            
            // Execute operations to trigger state changes
            for i := 0; i < tt.failures; i++ {
                _, err := breaker.Execute(ctx, serviceName, func() (interface{}, error) {
                    return nil, errors.New("service failure")
                })
                assert.Error(t, err)
            }
            
            for i := 0; i < tt.successes; i++ {
                result, err := breaker.Execute(ctx, serviceName, func() (interface{}, error) {
                    return "success", nil
                })
                if tt.shouldCallFunc {
                    assert.NoError(t, err)
                    assert.Equal(t, "success", result)
                }
            }
            
            // Verify final state
            state, err := mockRepo.GetState(ctx, serviceName)
            require.NoError(t, err)
            assert.Equal(t, tt.expectedState, state)
        })
    }
}

// Circuit breaker behavior under concurrent load
func TestCircuitBreaker_ConcurrentRequests(t *testing.T) {
    ctrl := gomock.NewController(t)
    defer ctrl.Finish()
    
    mockRepo := mocks.NewMockCircuitBreakerRepository(ctrl)
    serviceName := "avion-timeline"
    
    breaker := middleware.NewCircuitBreaker(mockRepo, middleware.CircuitBreakerConfig{
        FailureThreshold: 10,
        SuccessThreshold: 3,
        Timeout:         1 * time.Second,
    })
    
    // Initially closed circuit
    mockRepo.EXPECT().GetState(gomock.Any(), serviceName).
        Return(domain.CircuitClosed, nil).AnyTimes()
    
    mockRepo.EXPECT().RecordFailure(gomock.Any(), serviceName).
        Return(nil).AnyTimes()
    
    // Expect circuit to open after threshold
    mockRepo.EXPECT().UpdateState(gomock.Any(), serviceName, domain.CircuitOpen).
        Return(nil).Times(1)
    
    ctx := context.Background()
    numRequests := 50
    var successCount, failureCount int64
    var mu sync.Mutex
    
    var wg sync.WaitGroup
    for i := 0; i < numRequests; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            
            _, err := breaker.Execute(ctx, serviceName, func() (interface{}, error) {
                // Simulate failure to trigger circuit opening
                return nil, errors.New("simulated failure")
            })
            
            mu.Lock()
            if err != nil {
                failureCount++
            } else {
                successCount++
            }
            mu.Unlock()
        }()
    }
    
    wg.Wait()
    
    t.Logf("Success: %d, Failures: %d", successCount, failureCount)
    assert.Equal(t, int64(numRequests), failureCount, "All requests should fail")
}
```

### 17.4. Routing and Load Balancing Tests

ルーティングロジックと負荷分散アルゴリズムのテストを実装します。

```go
// tests/routing/load_balancer_test.go
package routing_test

import (
    "context"
    "testing"
    "time"
    
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
    
    "avion-gateway/internal/routing"
    "avion-gateway/internal/domain"
)

func TestLoadBalancer_RoundRobinAlgorithm(t *testing.T) {
    backends := []*domain.Backend{
        {ID: "backend1", Endpoint: "http://backend1:8080", Weight: 1, Healthy: true},
        {ID: "backend2", Endpoint: "http://backend2:8080", Weight: 1, Healthy: true},
        {ID: "backend3", Endpoint: "http://backend3:8080", Weight: 1, Healthy: true},
    }
    
    lb := routing.NewLoadBalancer(routing.RoundRobinAlgorithm, backends)
    
    // Test round-robin distribution
    selectedBackends := make(map[string]int)
    for i := 0; i < 30; i++ {
        backend, err := lb.SelectBackend(context.Background())
        require.NoError(t, err)
        selectedBackends[backend.ID]++
    }
    
    // Each backend should be selected equally
    for _, count := range selectedBackends {
        assert.Equal(t, 10, count, "Round-robin should distribute evenly")
    }
}

func TestLoadBalancer_WeightedRoundRobin(t *testing.T) {
    backends := []*domain.Backend{
        {ID: "backend1", Endpoint: "http://backend1:8080", Weight: 3, Healthy: true},
        {ID: "backend2", Endpoint: "http://backend2:8080", Weight: 2, Healthy: true},
        {ID: "backend3", Endpoint: "http://backend3:8080", Weight: 1, Healthy: true},
    }
    
    lb := routing.NewLoadBalancer(routing.WeightedRoundRobinAlgorithm, backends)
    
    selectedBackends := make(map[string]int)
    totalRequests := 60 // Should distribute as 30:20:10
    
    for i := 0; i < totalRequests; i++ {
        backend, err := lb.SelectBackend(context.Background())
        require.NoError(t, err)
        selectedBackends[backend.ID]++
    }
    
    // Verify weighted distribution
    assert.Equal(t, 30, selectedBackends["backend1"], "Weight 3 should get 30 requests")
    assert.Equal(t, 20, selectedBackends["backend2"], "Weight 2 should get 20 requests")
    assert.Equal(t, 10, selectedBackends["backend3"], "Weight 1 should get 10 requests")
}

func TestLoadBalancer_HealthyBackendsOnly(t *testing.T) {
    backends := []*domain.Backend{
        {ID: "backend1", Endpoint: "http://backend1:8080", Weight: 1, Healthy: true},
        {ID: "backend2", Endpoint: "http://backend2:8080", Weight: 1, Healthy: false}, // Unhealthy
        {ID: "backend3", Endpoint: "http://backend3:8080", Weight: 1, Healthy: true},
    }
    
    lb := routing.NewLoadBalancer(routing.RoundRobinAlgorithm, backends)
    
    selectedBackends := make(map[string]int)
    for i := 0; i < 20; i++ {
        backend, err := lb.SelectBackend(context.Background())
        require.NoError(t, err)
        selectedBackends[backend.ID]++
    }
    
    // Only healthy backends should be selected
    assert.Equal(t, 10, selectedBackends["backend1"])
    assert.Equal(t, 0, selectedBackends["backend2"], "Unhealthy backend should not be selected")
    assert.Equal(t, 10, selectedBackends["backend3"])
}

func TestRouteResolver_PathMatching(t *testing.T) {
    tests := []struct {
        name       string
        routes     []*domain.RoutingRule
        path       string
        method     domain.HTTPMethod
        wantMatch  bool
        wantTarget string
    }{
        {
            name: "exact path match",
            routes: []*domain.RoutingRule{
                {
                    PathPattern:  "/api/v1/drops",
                    HTTPMethods:  []domain.HTTPMethod{domain.MethodGET},
                    RouteTarget:  &domain.RouteTarget{ServiceName: "avion-drop"},
                    Priority:     1,
                },
            },
            path:       "/api/v1/drops",
            method:     domain.MethodGET,
            wantMatch:  true,
            wantTarget: "avion-drop",
        },
        {
            name: "parametric path match",
            routes: []*domain.RoutingRule{
                {
                    PathPattern:  "/api/v1/drops/{id}",
                    HTTPMethods:  []domain.HTTPMethod{domain.MethodGET},
                    RouteTarget:  &domain.RouteTarget{ServiceName: "avion-drop"},
                    Priority:     1,
                },
            },
            path:       "/api/v1/drops/123",
            method:     domain.MethodGET,
            wantMatch:  true,
            wantTarget: "avion-drop",
        },
        {
            name: "regex path match",
            routes: []*domain.RoutingRule{
                {
                    PathPattern:  "/api/v1/users/[a-zA-Z0-9]+/drops",
                    HTTPMethods:  []domain.HTTPMethod{domain.MethodGET},
                    RouteTarget:  &domain.RouteTarget{ServiceName: "avion-drop"},
                    Priority:     1,
                },
            },
            path:       "/api/v1/users/alice123/drops",
            method:     domain.MethodGET,
            wantMatch:  true,
            wantTarget: "avion-drop",
        },
        {
            name: "priority-based matching",
            routes: []*domain.RoutingRule{
                {
                    PathPattern:  "/api/v1/drops/special",
                    HTTPMethods:  []domain.HTTPMethod{domain.MethodGET},
                    RouteTarget:  &domain.RouteTarget{ServiceName: "avion-special"},
                    Priority:     1, // Higher priority
                },
                {
                    PathPattern:  "/api/v1/drops/{id}",
                    HTTPMethods:  []domain.HTTPMethod{domain.MethodGET},
                    RouteTarget:  &domain.RouteTarget{ServiceName: "avion-drop"},
                    Priority:     2, // Lower priority
                },
            },
            path:       "/api/v1/drops/special",
            method:     domain.MethodGET,
            wantMatch:  true,
            wantTarget: "avion-special", // Should match higher priority route
        },
        {
            name: "no match for wrong method",
            routes: []*domain.RoutingRule{
                {
                    PathPattern:  "/api/v1/drops",
                    HTTPMethods:  []domain.HTTPMethod{domain.MethodGET},
                    RouteTarget:  &domain.RouteTarget{ServiceName: "avion-drop"},
                    Priority:     1,
                },
            },
            path:      "/api/v1/drops",
            method:    domain.MethodPOST,
            wantMatch: false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            resolver := routing.NewRouteResolver(tt.routes)
            
            target, err := resolver.ResolveRoute(tt.path, tt.method)
            
            if tt.wantMatch {
                require.NoError(t, err)
                assert.Equal(t, tt.wantTarget, string(target.ServiceName))
            } else {
                assert.Error(t, err)
                assert.Nil(t, target)
            }
        })
    }
}
```

### 17.5. Cache Invalidation Testing

キャッシュの無効化とデータ整合性のテストを実装します。

```go
// tests/cache/invalidation_test.go
package cache_test

import (
    "context"
    "testing"
    "time"
    
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
    "go.uber.org/mock/gomock"
    
    "avion-gateway/internal/cache"
    "avion-gateway/tests/mocks"
)

func TestJWTCache_InvalidationOnTokenRevocation(t *testing.T) {
    tests := []struct {
        name          string
        setupCache    func(*mocks.MockRedisClient)
        jti           string
        expectCached  bool
        expectDeleted bool
    }{
        {
            name: "token exists and gets invalidated",
            setupCache: func(mc *mocks.MockRedisClient) {
                // Token initially exists in cache
                mc.EXPECT().Get(gomock.Any(), "jwt_validation:test_jti").
                    Return(`{"user_id":"user123","scopes":["read","write"]}`, nil).Times(1)
                
                // Token gets deleted on revocation
                mc.EXPECT().Del(gomock.Any(), "jwt_validation:test_jti").
                    Return(int64(1), nil).Times(1)
                
                // Subsequent access returns cache miss
                mc.EXPECT().Get(gomock.Any(), "jwt_validation:test_jti").
                    Return("", redis.Nil).Times(1)
            },
            jti:           "test_jti",
            expectCached:  true,
            expectDeleted: true,
        },
        {
            name: "token doesn't exist in cache",
            setupCache: func(mc *mocks.MockRedisClient) {
                mc.EXPECT().Get(gomock.Any(), "jwt_validation:nonexistent_jti").
                    Return("", redis.Nil).Times(1)
                
                mc.EXPECT().Del(gomock.Any(), "jwt_validation:nonexistent_jti").
                    Return(int64(0), nil).Times(1) // 0 keys deleted
            },
            jti:           "nonexistent_jti",
            expectCached:  false,
            expectDeleted: false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            ctrl := gomock.NewController(t)
            defer ctrl.Finish()
            
            mockRedis := mocks.NewMockRedisClient(ctrl)
            tt.setupCache(mockRedis)
            
            jwtCache := cache.NewJWTCache(mockRedis)
            ctx := context.Background()
            
            // Check if token is initially cached
            cachedData, err := jwtCache.Get(ctx, tt.jti)
            if tt.expectCached {
                require.NoError(t, err)
                assert.NotEmpty(t, cachedData)
            } else {
                assert.Error(t, err)
            }
            
            // Invalidate token
            deleted, err := jwtCache.InvalidateToken(ctx, tt.jti)
            require.NoError(t, err)
            assert.Equal(t, tt.expectDeleted, deleted)
            
            // Verify token is no longer cached
            cachedData, err = jwtCache.Get(ctx, tt.jti)
            assert.Error(t, err)
            assert.Empty(t, cachedData)
        })
    }
}

// Test cache hit/miss scenarios
func TestAuthCache_HitMissPatterns(t *testing.T) {
    ctrl := gomock.NewController(t)
    defer ctrl.Finish()
    
    mockRedis := mocks.NewMockRedisClient(ctrl)
    authCache := cache.NewJWTCache(mockRedis)
    
    ctx := context.Background()
    userID := "user123"
    jti := "test_token_123"
    
    authData := cache.AuthCacheEntry{
        UserID:    userID,
        Scopes:    []string{"read", "write"},
        ExpiresAt: time.Now().Add(time.Hour),
    }
    
    // First access - cache miss
    mockRedis.EXPECT().Get(gomock.Any(), "jwt_validation:"+jti).
        Return("", redis.Nil).Times(1)
    
    cachedAuth, err := authCache.Get(ctx, jti)
    assert.Error(t, err)
    assert.Nil(t, cachedAuth)
    
    // Store in cache
    authDataJSON, _ := json.Marshal(authData)
    mockRedis.EXPECT().Set(gomock.Any(), "jwt_validation:"+jti, string(authDataJSON), time.Hour).
        Return("OK", nil).Times(1)
    
    err = authCache.Set(ctx, jti, &authData, time.Hour)
    require.NoError(t, err)
    
    // Second access - cache hit
    mockRedis.EXPECT().Get(gomock.Any(), "jwt_validation:"+jti).
        Return(string(authDataJSON), nil).Times(1)
    
    cachedAuth, err = authCache.Get(ctx, jti)
    require.NoError(t, err)
    assert.Equal(t, authData.UserID, cachedAuth.UserID)
    assert.Equal(t, authData.Scopes, cachedAuth.Scopes)
}
```

### 17.6. WebSocket/SSE Connection Testing

WebSocketとSSE接続の管理とイベント配信のテストを実装します。

```go
// tests/sse/connection_test.go
package sse_test

import (
    "context"
    "net/http/httptest"
    "testing"
    "time"
    
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
    
    "avion-gateway/internal/sse"
)

func TestSSEConnectionManager_ConnectionLifecycle(t *testing.T) {
    manager := sse.NewConnectionManager()
    
    // Create test server
    recorder := httptest.NewRecorder()
    userID := "user123"
    
    // Establish connection
    conn, err := manager.EstablishConnection(context.Background(), userID, recorder)
    require.NoError(t, err)
    assert.NotNil(t, conn)
    
    // Verify connection is tracked
    connections := manager.GetUserConnections(userID)
    assert.Len(t, connections, 1)
    assert.Equal(t, conn.ID, connections[0].ID)
    
    // Send test event
    event := &sse.Event{
        ID:   "event1",
        Type: "test",
        Data: map[string]interface{}{"message": "hello"},
    }
    
    err = manager.BroadcastToUser(userID, event)
    require.NoError(t, err)
    
    // Wait for event to be written
    time.Sleep(10 * time.Millisecond)
    
    // Verify event was written to response
    response := recorder.Body.String()
    assert.Contains(t, response, "event: test")
    assert.Contains(t, response, `data: {"message":"hello"}`)
    
    // Close connection
    err = manager.CloseConnection(conn.ID)
    require.NoError(t, err)
    
    // Verify connection is removed
    connections = manager.GetUserConnections(userID)
    assert.Len(t, connections, 0)
}

func TestSSEConnectionManager_EventFiltering(t *testing.T) {
    tests := []struct {
        name           string
        event          *sse.Event
        userPrefs      sse.UserPreferences
        expectedFilter bool
    }{
        {
            name: "public event allowed",
            event: &sse.Event{
                Type:     "drop.created",
                Privacy:  sse.PublicEvent,
                AuthorID: "author123",
            },
            userPrefs: sse.UserPreferences{
                EventTypes:   []string{"drop.created", "reaction.added"},
                MutedUsers:   []string{},
                BlockedUsers: []string{},
            },
            expectedFilter: true,
        },
        {
            name: "event from muted user filtered",
            event: &sse.Event{
                Type:     "drop.created",
                Privacy:  sse.PublicEvent,
                AuthorID: "muted_user",
            },
            userPrefs: sse.UserPreferences{
                EventTypes:   []string{"drop.created"},
                MutedUsers:   []string{"muted_user"},
                BlockedUsers: []string{},
            },
            expectedFilter: false,
        },
        {
            name: "private event filtered for non-owner",
            event: &sse.Event{
                Type:    "notification.private",
                Privacy: sse.PrivateEvent,
                UserID:  "owner123",
            },
            userPrefs: sse.UserPreferences{
                EventTypes: []string{"notification.private"},
            },
            expectedFilter: false, // Different user ID
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            manager := sse.NewConnectionManager()
            
            result := manager.FilterEventForUser(tt.event, "user123", tt.userPrefs)
            assert.Equal(t, tt.expectedFilter, result)
        })
    }
}
```

### 17.7. Security Header Validation

セキュリティヘッダーの検証とCSRF保護のテストを実装します。

```go
// tests/security/headers_test.go
package security_test

import (
    "net/http"
    "net/http/httptest"
    "testing"
    
    "github.com/gin-gonic/gin"
    "github.com/stretchr/testify/assert"
    
    "avion-gateway/internal/middleware"
)

func TestSecurityHeaders_Middleware(t *testing.T) {
    tests := []struct {
        name            string
        expectedHeaders map[string]string
    }{
        {
            name: "security headers applied",
            expectedHeaders: map[string]string{
                "X-Content-Type-Options":   "nosniff",
                "X-Frame-Options":          "DENY",
                "X-XSS-Protection":         "1; mode=block",
                "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
                "Content-Security-Policy":   "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'",
                "Referrer-Policy":          "strict-origin-when-cross-origin",
            },
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            gin.SetMode(gin.TestMode)
            router := gin.New()
            
            // Apply security headers middleware
            router.Use(middleware.SecurityHeaders())
            router.GET("/test", func(c *gin.Context) {
                c.JSON(http.StatusOK, gin.H{"status": "ok"})
            })
            
            req := httptest.NewRequest("GET", "/test", nil)
            resp := httptest.NewRecorder()
            
            router.ServeHTTP(resp, req)
            
            // Verify security headers
            for header, expectedValue := range tt.expectedHeaders {
                actualValue := resp.Header().Get(header)
                assert.Equal(t, expectedValue, actualValue, "Security header %s mismatch", header)
            }
            
            assert.Equal(t, http.StatusOK, resp.Code)
        })
    }
}

func TestCSRFProtection_ValidateToken(t *testing.T) {
    tests := []struct {
        name          string
        method        string
        csrfToken     string
        headerToken   string
        expectedValid bool
    }{
        {
            name:          "valid CSRF token in header",
            method:        "POST",
            csrfToken:     "valid_token_123",
            headerToken:   "valid_token_123",
            expectedValid: true,
        },
        {
            name:          "missing CSRF token",
            method:        "POST",
            csrfToken:     "valid_token_123",
            headerToken:   "",
            expectedValid: false,
        },
        {
            name:          "invalid CSRF token",
            method:        "POST",
            csrfToken:     "valid_token_123",
            headerToken:   "invalid_token",
            expectedValid: false,
        },
        {
            name:          "GET request - no CSRF check",
            method:        "GET",
            csrfToken:     "valid_token_123",
            headerToken:   "",
            expectedValid: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            gin.SetMode(gin.TestMode)
            router := gin.New()
            
            csrfMiddleware := middleware.NewCSRFProtection("secret_key")
            router.Use(csrfMiddleware)
            
            router.Any("/test", func(c *gin.Context) {
                c.JSON(http.StatusOK, gin.H{"status": "ok"})
            })
            
            req := httptest.NewRequest(tt.method, "/test", nil)
            if tt.headerToken != "" {
                req.Header.Set("X-CSRF-Token", tt.headerToken)
            }
            
            // Simulate session with CSRF token
            req.Header.Set("Cookie", "csrf_token="+tt.csrfToken)
            
            resp := httptest.NewRecorder()
            router.ServeHTTP(resp, req)
            
            if tt.expectedValid {
                assert.Equal(t, http.StatusOK, resp.Code)
            } else {
                assert.Equal(t, http.StatusForbidden, resp.Code)
            }
        })
    }
}
```

このservice-specific test strategyでは、avion-gatewayの主要機能に対する包括的なテスト戦略を提供しています。各テストは実際のコード例とともに、境界値テスト、負荷テスト、セキュリティテストを含んでいます。

## 19. テスト実装詳細

テスト実装の詳細については、[共通テスト戦略](../common/testing-strategy.md)に従って実装します。

### ゲートウェイ特化のテスト実装
- ルーティングロジックのテーブル駆動テスト
- GraphQL統合テストでのDataLoader検証
- SSEイベント配信のパフォーマンステスト
- 負荷分散アルゴリズムのベンチマーク

## 20. Configuration Management

This service follows the unified configuration pattern defined in [Common Environment Variables](../common/infrastructure/environment-variables.md).

### Environment Variables

#### Required Variables
- `REDIS_URL`: Redis connection string for rate limiting and caching
- `JWT_PUBLIC_KEY`: JWT verification public key for authentication
- `SERVICE_DISCOVERY_URL`: Service discovery endpoint for backend service routing

#### Optional Variables (with defaults)
- `PORT`: HTTP server port (default: 8080)
- `GRPC_PORT`: gRPC server port (default: 9090)
- `RATE_LIMIT_PER_MIN`: Rate limit per minute per client (default: 60)
- `GRAPHQL_DEPTH_LIMIT`: Maximum GraphQL query depth (default: 10)

### Config Structure Implementation

```go
// internal/infrastructure/config/config.go
package config

import (
    "time"
)

type Config struct {
    // サーバー設定
    Server ServerConfig
    
    // Redis設定
    Redis RedisConfig
    
    // 認証設定
    Auth AuthConfig
    
    // サービス設定
    Services ServicesConfig
    
    // Gateway特有設定
    Gateway GatewayConfig
}

type ServerConfig struct {
    Port        int           `env:"PORT" required:"false" default:"8080"`
    GRPCPort    int           `env:"GRPC_PORT" required:"false" default:"9090"`
    Environment string        `env:"ENVIRONMENT" required:"false" default:"development"`
    LogLevel    string        `env:"LOG_LEVEL" required:"false" default:"info"`
    Timeout     time.Duration `env:"SERVER_TIMEOUT" required:"false" default:"30s"`
}

type RedisConfig struct {
    URL      string `env:"REDIS_URL" required:"true"`
    Password string `env:"REDIS_PASSWORD" required:"false" secret:"true"`
    DB       int    `env:"REDIS_DB" required:"false" default:"0"`
}

type AuthConfig struct {
    JWTPublicKey string `env:"JWT_PUBLIC_KEY" required:"true"`
}

type ServicesConfig struct {
    DiscoveryURL string        `env:"SERVICE_DISCOVERY_URL" required:"true"`
    Timeout      time.Duration `env:"SERVICE_TIMEOUT" required:"false" default:"5s"`
}

type GatewayConfig struct {
    RateLimitPerMin    int `env:"RATE_LIMIT_PER_MIN" required:"false" default:"60"`
    GraphQLDepthLimit  int `env:"GRAPHQL_DEPTH_LIMIT" required:"false" default:"10"`
}
```

### Usage Example

```go
// cmd/server/main.go
func main() {
    // 環境変数の読み込み（必須環境変数が不足していればここで失敗）
    cfg := config.MustLoad()
    
    logger := initLogger(cfg.Server.LogLevel)
    
    logger.Info("Starting avion-gateway server",
        "environment", cfg.Server.Environment,
        "port", cfg.Server.Port,
        "grpc_port", cfg.Server.GRPCPort,
        "rate_limit", cfg.Gateway.RateLimitPerMin,
    )
    
    // Redis接続の初期化
    redis := initRedis(cfg.Redis)
    
    // サービスディスカバリの初期化
    discovery := initServiceDiscovery(cfg.Services)
    
    // ゲートウェイサーバーの起動
    // ...
}
```

---