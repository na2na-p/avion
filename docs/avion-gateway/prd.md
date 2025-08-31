# PRD: avion-gateway

## 概要

AvionマイクロサービスアーキテクチャにおけるAPIゲートウェイとして、すべての外部クライアントからのリクエストを受け付け、認証・認可・レート制限などの横断的関心事を処理し、適切なバックエンドサービスへルーティングする純粋なAPIゲートウェイサービスを実装する。

## 背景

マイクロサービスアーキテクチャを採用するAvionにおいて、以下の要件を満たす純粋なAPIゲートウェイが必要：

*   すべての外部クライアント（Web、Bot、ActivityPubサーバー）からのリクエストを受け付ける単一のエントリーポイント
*   認証・認可、レート制限、ログ集約などの横断的関心事の一元管理
*   バックエンドマイクロサービスへの効率的なルーティング
*   セキュリティ境界の確立と一貫したポリシー適用

## Scientific Merits

*   **セキュリティの一元化:** すべてのリクエストが通過する単一ポイントでセキュリティポリシーを適用することで、一貫性のあるセキュリティ実装を実現。
*   **横断的関心事の効率的な処理:** 認証、認可、レート制限、ロギング、メトリクス収集を一箇所で実装することで、各マイクロサービスでの重複実装を回避。
*   **運用の効率化:** 監視、ログ収集、デバッグ、トラフィック制御を一元的に管理可能。
*   **スケーラビリティの向上:** ステートレス設計により、負荷に応じた水平スケーリングが容易。

## Design Doc

[Design Doc: avion-gateway](./designdoc.md)

## 参考ドキュメント

*   [Avion アーキテクチャ概要](./../common/architecture.md)
*   [avion-bff-web PRD](./../avion-bff-web/prd.md)

## 製品原則

*   **単一のエントリーポイント:** すべての外部クライアントリクエストの窓口となる。
*   **横断的関心事の一元管理:** 認証・認可・レート制限・ロギング等を統一的に処理する。
*   **効率的なルーティング:** リクエストを適切なバックエンドサービスへ高速かつ確実に転送する。
*   **プロトコル中立性:** HTTP、gRPC、WebSocketなど複数のプロトコルをサポート。

## やること/やらないこと

### やること

#### 認証・認可
*   JWT検証（公開鍵によるローカル検証、結果のキャッシュ）
*   Bot認証サポート（APIキー検証）
*   認可チェック（`avion-auth` との連携）
*   トークン失効管理（Redis Pub/Sub経由）

#### ルーティング
*   パスベースルーティング（REST API）
*   ヘッダーベースルーティング（Accept, Content-Type）
*   サービスディスカバリ（静的設定、将来的には動的）
*   ロードバランシング（ラウンドロビン、将来的にはヘルスチェック連動）

#### レート制限
*   ユーザー単位のレート制限
*   IPアドレス単位のレート制限
*   エンドポイント別の制限設定
*   グレースフルな制限（429 Too Many Requests）

#### 監視・ロギング
*   リクエスト/レスポンスのログ記録
*   メトリクス収集（リクエスト数、レイテンシ、エラー率）
*   OpenTelemetryトレースコンテキストの生成と伝播
*   ヘルスチェックエンドポイント

#### プロトコル変換
*   HTTP → gRPC（内部サービス呼び出し）
*   gRPC → HTTP（レスポンス変換）
*   WebSocket → 内部イベントストリーム（将来的）

### やらないこと

*   **ビジネスロジックの実装:** データ変換、集約、フィルタリングなどのビジネスロジックは実装しない
*   **データの永続化:** 状態を持たず、データの保存は行わない（認証キャッシュを除く）
*   **複雑なデータ変換:** リクエスト/レスポンスの複雑な変換処理は行わない
*   **GraphQL処理:** GraphQLの解析、実行、データ集約はavion-webが担当
*   **アプリケーション固有の最適化:** 特定のクライアント向けの最適化は行わない
*   **SSE処理:** Server-Sent Eventsはavion-webが担当
*   **データアグリゲーション:** 複数サービスからのデータ集約はavion-webが担当

## 対象ユーザ

*   avion-web（Webフロントエンド）
*   将来的なモバイルアプリケーション
*   Botアプリケーション
*   ActivityPubクライアント（他のフェデレーションサーバー）
*   サードパーティAPI利用者
*   Avion 開発者・運用者

## ドメインモデル (DDD戦術的パターン)

### Aggregates (集約)

#### RoutingRule Aggregate
**責務**: APIルーティングルールの管理とパスマッチング
- **集約ルート**: RoutingRule
- **不変条件**:
  - パスパターンは有効な正規表現またはパラメータ付きパス（例: /users/{id}）である
  - 優先度は1-1000の範囲内で、同一優先度のルールは存在しない
  - 同一パスパターンとHTTPメソッドの組み合わせは一意である
  - ターゲットサービスは登録済みのAvionマイクロサービスのみ（avion-*の命名規則に従う）
  - HTTPメソッドは標準メソッド（GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD）のみ
  - パスパラメータ名は予約語（api, health, metrics等）を使用しない
  - クエリパラメータのバリデーションルールが明確に定義されている
  - 必須ヘッダーと任意ヘッダーの区別が明確である
  - レスポンス変換ルールがHTTPステータスコードごとに定義されている
  - ルーティングループが発生しない（自己参照や循環参照がない）
  - パスの最大長は2048文字以下
  - タイムアウト設定は100ms以上30秒以下
- **ドメインロジック**:
  - `matchPath(requestPath)`: リクエストパスがルールにマッチするか判定
  - `extractPathParameters(path)`: パスからパラメータを抽出
  - `validateQueryParameters(params)`: クエリパラメータを検証
  - `getPriority()`: ルーティング優先度を取得
  - `isAuthRequired()`: 認証が必要か判定

#### LoadBalancingPolicy Aggregate
**責務**: 負荷分散ポリシーとヘルスチェックの管理
- **集約ルート**: LoadBalancingPolicy
- **不変条件**:
  - アルゴリズムは定義済みのもののみ（RoundRobin, LeastConnection, IPHash, WeightedRandom）
  - ヘルスチェック間隔は1秒以上300秒以下
  - ヘルスチェックタイムアウトは100ms以上10秒以下
  - 連続失敗閾値は1-10回の範囲内
  - リトライ回数は0-5回で、リトライ間隔は指数バックオフに従う
  - サーキットブレーカーの開放閾値は50-100%の範囲内
  - スティッキーセッションのTTLは1分以上24時間以下
  - バックエンドサーバーの重み付けは1-100の範囲内
  - 最低1台のバックエンドサーバーが定義されている
  - フェイルオーバー条件（エラー率、レイテンシ）が数値で定義されている
  - 負荷分散メトリクスの収集間隔は1秒以上60秒以下
  - コネクションプールの最大サイズは1-1000の範囲内
  - Half-Open状態での試行間隔は5秒以上5分以下
- **ドメインロジック**:
  - `selectBackend(requestContext)`: リクエストコンテキストに基づいてバックエンドを選択
  - `recordSuccess(backend)`: 成功を記録しヘルスステータスを更新
  - `recordFailure(backend, error)`: 失敗を記録しサーキットブレーカーを更新
  - `isHealthy(backend)`: バックエンドの健全性を判定
  - `shouldOpenCircuit(errorRate)`: サーキットブレーカーを開放すべきか判定

#### SecurityPolicy Aggregate
**責務**: セキュリティポリシーと認証・認可ルールの管理
- **集約ルート**: SecurityPolicy
- **不変条件**:
  - 認証方式は定義済みのもののみ（JWT, OAuth2, APIKey, mTLS）
  - JWTの署名アルゴリズムはRS256, ES256のみサポート
  - レート制限は1req/sec以上10000req/sec以下
  - バーストサイズは基本レートの10倍以下
  - IPホワイトリスト/ブラックリストは有効なCIDR形式（IPv4/IPv6）
  - CORSの許可オリジンは有効なURL形式かワイルドカード
  - 最大リクエストサイズは1KB以上100MB以下
  - CSRFトークンの有効期限は1分以上24時間以下
  - セキュリティヘッダーはOWASP推奨設定に準拠
  - TLS最小バージョンは1.2以上
  - 暗号化アルゴリズムはNIST推奨のもののみ
  - 監査ログの保持期間は7日以上365日以下
  - 異常検知の閾値（連続失敗回数）は3-100回の範囲内
  - APIキーの長さは32文字以上128文字以下
  - セッションタイムアウトは5分以上24時間以下
- **ドメインロジック**:
  - `validateAuthentication(credentials)`: 認証情報を検証
  - `checkAuthorization(user, resource, action)`: 認可を確認
  - `enforceRateLimit(identifier)`: レート制限を適用
  - `validateIPAccess(ipAddress)`: IPアクセス制御を検証
  - `generateCSRFToken()`: CSRFトークンを生成
  - `auditAccess(request, response)`: アクセスを監査ログに記録

#### RequestContext Aggregate
**責務**: リクエストのライフサイクルとコンテキスト情報の管理
- **集約ルート**: RequestContext
- **不変条件**:
  - RequestIDはUUID v4形式で一意である
  - TraceIDとSpanIDはOpenTelemetry仕様に準拠
  - タイムスタンプはUTCでミリ秒精度
  - User-Agentは1024文字以下
  - リクエストヘッダーの総サイズは8KB以下
  - X-Forwarded-Forチェーンは10ホップ以下
  - カスタムヘッダー名は予約語と衝突しない
  - Content-Typeは有効なMIMEタイプ
  - Accept-Languageは有効なロケール形式
  - リクエストの処理時間は30秒以下でタイムアウト
  - 認証トークンは Bearer スキームに従う
  - APIバージョンは有効なセマンティックバージョニング形式
- **ドメインロジック**:
  - `extractTraceContext()`: トレースコンテキストを抽出
  - `generateRequestID()`: リクエストIDを生成
  - `enrichWithUserContext(authInfo)`: ユーザーコンテキストを追加
  - `calculateLatency()`: 処理レイテンシを計算
  - `shouldRetry(error)`: リトライすべきか判定

#### RateLimitBucket Aggregate
**責務**: レート制限の状態管理とトークンバケットアルゴリズムの実装
- **集約ルート**: RateLimitBucket
- **不変条件**:
  - バケット識別子は「type:identifier:endpoint」形式（例: user:123:POST:/api/drops）
  - トークン数は0以上、最大容量以下
  - 最大容量は1以上100000以下
  - 補充レートは1/秒以上10000/秒以下
  - ウィンドウサイズは1秒以上3600秒以下
  - バーストサイズは基本容量の1倍以上10倍以下
  - 最終更新時刻は現在時刻以前
  - スライディングウィンドウの履歴は最大3600エントリ
  - 識別子タイプはuser, ip, api_key, domainのいずれか
  - IPアドレスは有効なIPv4またはIPv6形式
  - 優先度付きバケットは1-5のレベル
  - グレースピリオドは0-60秒の範囲
  - リセット時刻は最終更新時刻より後
- **ドメインロジック**:
  - `consumeTokens(count)`: トークンを消費
  - `refillTokens()`: 経過時間に基づいてトークンを補充
  - `calculateWaitTime(requestedTokens)`: 次回利用可能時刻を計算
  - `reset()`: バケットをリセット
  - `getAvailableTokens()`: 利用可能トークン数を取得

### Entities (エンティティ)

#### AuthenticationContext
**所属**: RequestContext Aggregate
**責務**: ユーザー認証情報と検証結果を保持
- **属性**:
  - UserID (Snowflake ID形式)
  - TokenType (JWT, APIKey, OAuth2)
  - Scopes (権限スコープのリスト)
  - ExpiresAt (有効期限UTC)
  - IssuedAt (発行時刻UTC)
- **ビジネスルール**:
  - 有効期限切れのトークンは無効
  - 必須スコープが不足している場合はアクセス拒否
  - 失効リストに含まれるトークンは無効

#### RouteTarget
**所属**: RoutingRule Aggregate
**責務**: ルーティング先のサービス情報を保持
- **属性**:
  - ServiceName (avion-*形式)
  - ServiceEndpoint (gRPCまたはHTTPエンドポイント)
  - Protocol (gRPC, HTTP, WebSocket)
  - RetryPolicy (リトライ設定)
- **ビジネスルール**:
  - サービス名はavion-プレフィックスを持つ
  - エンドポイントは有効なURL形式
  - リトライは冪等性のある操作のみ

#### Backend
**所属**: LoadBalancingPolicy Aggregate
**責務**: バックエンドサーバーの状態と統計を管理
- **属性**:
  - Address (IPアドレス:ポート)
  - Weight (負荷分散の重み)
  - HealthStatus (Healthy, Unhealthy, Draining)
  - ActiveConnections (アクティブ接続数)
  - ErrorRate (直近のエラー率)
- **ビジネスルール**:
  - Unhealthyなバックエンドにはトラフィックを送らない
  - Drainingステータスでは新規接続を受け付けない
  - エラー率が閾値を超えたら自動的にUnhealthyに遷移

#### CircuitBreaker
**所属**: LoadBalancingPolicy Aggregate
**責務**: サービスごとのサーキットブレーカー状態を管理
- **属性**:
  - State (Closed, Open, HalfOpen)
  - FailureCount (連続失敗回数)
  - LastFailureTime (最終失敗時刻)
  - NextRetryTime (次回試行時刻)
- **ビジネスルール**:
  - Open状態では新規リクエストを即座に拒否
  - HalfOpen状態では限定的にリクエストを許可
  - 成功が続けばClosedに戻る

#### RateLimitWindow
**所属**: RateLimitBucket Aggregate
**責務**: レート制限の時間ウィンドウを管理
- **属性**:
  - WindowStart (ウィンドウ開始時刻UTC)
  - WindowEnd (ウィンドウ終了時刻UTC)
  - RequestCount (ウィンドウ内のリクエスト数)
  - RequestTimestamps (個別リクエストのタイムスタンプリスト)
- **ビジネスルール**:
  - ウィンドウサイズは設定値に従う
  - 古いウィンドウは自動的に削除される
  - スライディングウィンドウ方式で集計

### Value Objects (値オブジェクト)

**識別子関連**
- **RequestID**: UUID v4形式のリクエスト識別子
- **TraceID**: OpenTelemetry準拠のトレースID（32文字の16進数）
- **SpanID**: OpenTelemetry準拠のスパンID（16文字の16進数）
- **UserID**: Snowflake ID形式のユーザー識別子
- **ServiceName**: avion-*形式のサービス名（最大64文字）
- **BucketID**: type:identifier:endpoint形式のバケット識別子

**ネットワーク関連**
- **HTTPMethod**: GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD
- **HTTPPath**: URLパス（最大2048文字）、パラメータプレースホルダー対応
- **HTTPStatusCode**: 100-599の範囲のHTTPステータスコード
- **IPAddress**: IPv4またはIPv6形式のIPアドレス
- **Port**: 1-65535の範囲のポート番号
- **Endpoint**: プロトコル://ホスト:ポート/パス形式

**時刻・期間関連**
- **Timestamp**: UTCミリ秒精度のタイムスタンプ
- **Duration**: ミリ秒単位の期間（1ms-300000ms）
- **TTL**: 秒単位の有効期限（1秒-86400秒）
- **WindowSize**: 秒単位のウィンドウサイズ（1-3600秒）

**セキュリティ関連**
- **JWTToken**: RFC 7519準拠のJWTトークン
- **APIKey**: 32-128文字の英数字とハイフン
- **Scope**: OAuth2スコープ（例: read:drops, write:profile）
- **CSRFToken**: 32文字のランダム文字列

**レート制限関連**
- **TokenCount**: 0-100000の範囲のトークン数
- **RefillRate**: 1-10000トークン/秒の補充レート
- **BurstSize**: 基本容量の1-10倍のバーストサイズ

### Domain Services

#### APIOrchestrator
**責務**: 複数のAggregateを調整してAPIリクエストを処理
- **メソッド**:
  - `processRequest(context, request)`: リクエスト全体の処理を調整
  - `applySecurityPolicies(context, policies)`: セキュリティポリシーを適用
  - `routeWithLoadBalancing(rule, policy)`: ルーティングと負荷分散を統合
  - `handleCircuitBreaker(service, operation)`: サーキットブレーカーを考慮した実行
  - `aggregateMetrics(request, response)`: メトリクスを集約

#### AuthenticationService
**責務**: 複数の認証方式を統合的に処理
- **メソッド**:
  - `authenticate(credentials)`: 認証方式を自動判定して認証
  - `validateJWT(token)`: JWT検証（キャッシュ活用）
  - `validateAPIKey(key)`: APIキー検証
  - `refreshToken(refreshToken)`: トークンリフレッシュ
  - `revokeToken(token)`: トークン失効

#### RateLimitingService
**責務**: 複雑なレート制限ルールの評価と適用
- **メソッド**:
  - `evaluateRateLimit(identifier, endpoint)`: レート制限を評価
  - `applyMultipleLimit (userLimit, ipLimit, globalLimit)`: 複数制限の統合
  - `calculateBackoff(violations)`: バックオフ時間を計算
  - `grantGracePeriod(user, reason)`: グレースピリオドを付与

## ユースケース

### 認証付きAPIリクエスト

1.  クライアント（avion-web等）がJWT付きでAPIリクエストを送信
2.  `avion-gateway` はJWTを検証（ローカルキャッシュ → 公開鍵検証）
3.  レート制限チェック（ユーザー単位）
4.  認可チェック（必要に応じて`avion-auth`に問い合わせ）
5.  適切なバックエンドサービスにgRPCでリクエストを転送
6.  レスポンスをHTTPに変換してクライアントに返却

### Bot APIアクセス

1.  BotがAPIキーを使用してリクエストを送信
2.  `avion-gateway` はAPIキーを検証（`avion-auth`との連携）
3.  レート制限チェック（Bot単位、より厳しい制限）
4.  許可されたエンドポイントへのアクセスか確認
5.  バックエンドサービスへ転送

### ActivityPub Webhook

1.  他のActivityPubサーバーから `/inbox` へのHTTPリクエストを受信
2.  `avion-gateway` は基本的なリクエスト検証（サイズ、形式）
3.  レート制限チェック（ドメイン単位）
4.  `avion-activitypub` へ転送（HTTPプロトコルのまま）
5.  処理結果を適切なHTTPステータスコードで返却

### ヘルスチェック

1.  監視システムが `/health` エンドポイントにアクセス
2.  `avion-gateway` は自身の状態を確認
3.  依存サービスの状態を確認（Redis接続等）
4.  集約したヘルス状態を返却

## 機能要求

### ドメインロジック要求

*   **リクエストルーティング管理:**
    *   パスパターンマッチング
    *   HTTPメソッドによるルーティング
    *   ヘッダーベースルーティング
    *   サービス名解決

*   **レート制限管理:**
    *   スライディングウィンドウアルゴリズム
    *   複数の制限ポリシー（ユーザー、IP、エンドポイント）
    *   制限状態の効率的な管理

*   **認証コンテキスト管理:**
    *   JWT検証結果のキャッシング
    *   APIキー検証
    *   認証情報の伝播

### 技術要求

*   **プロトコル変換:** HTTP ↔ gRPC の双方向変換
*   **サービス間通信:** gRPCクライアントの実装と管理
*   **キャッシュ:** Redis を使用した認証結果とレート制限状態のキャッシュ
*   **並行処理:** 高スループットを実現する効率的な並行処理
*   **タイムアウト管理:** 各サービス呼び出しの適切なタイムアウト設定
*   **サーキットブレーカー:** 障害サービスの自動検出と迂回

## セキュリティ実装ガイドライン

本サービスは以下のセキュリティガイドラインに準拠する必要があります：

### CSRF保護
- **ガイドライン**: [../common/security/csrf-protection.md](../common/security/csrf-protection.md)
- **実装要件**: すべての外部リクエストのエントリーポイントとして、avion-gatewayは包括的なCSRF保護を実装する必要があります。これには、ダブルサブミットクッキー検証、Origin/Refererヘッダー検証、状態変更操作のためのカスタムヘッダー要件が含まれます。ゲートウェイは、すべての非安全HTTPメソッド（POST、PUT、PATCH、DELETE）に対してCSRFトークンを生成・検証する必要があります。

### TLS設定
- **ガイドライン**: [../common/security/tls-configuration.md](../common/security/tls-configuration.md)
- **実装要件**: ゲートウェイは、すべての外部接続でTLS 1.3を強制し、バックエンドサービス接続の適切な証明書検証を実装し、サービス間認証のための相互TLS（mTLS）をサポートする必要があります。重要なバックエンドサービスに対しては証明書ピンニングを実装する必要があります。

### セキュリティヘッダー
- **ガイドライン**: [../common/security/security-headers.md](../common/security/security-headers.md)
- **実装要件**: Strict-Transport-Security、X-Content-Type-Options、X-Frame-Options、X-XSS-Protection、Content-Security-Policyを含むすべてのレスポンスに対してセキュリティヘッダーを自動的に注入します。ヘッダーは安全なデフォルトを維持しながら、ルートごとに設定可能である必要があります。

### XSS防止
- **ガイドライン**: [../common/security/xss-prevention.md](../common/security/xss-prevention.md)
- **実装要件**: バックエンドサービスに転送する前に、すべての受信リクエストに対して包括的な入力検証とサニタイゼーションを実装します。プロトコル間（HTTPからgRPC）でレスポンスを変換する際には、コンテキストに応じた出力エンコーディングを適用します。Content-Typeヘッダーを検証し、予期しないコンテンツタイプを拒否する必要があります。

## 技術的要求

### パフォーマンス
*   Gateway処理による追加レイテンシ: 平均 5ms 以下
*   スループット: 20,000 req/s 以上
*   P99レイテンシ: 20ms 以下（バックエンド呼び出しを除く）

### 可用性
*   99.99%以上の可用性を目標
*   Kubernetes上での複数レプリカによる冗長構成
*   グレースフルシャットダウンとコネクションドレイニング
*   ゼロダウンタイムデプロイメント

### スケーラビリティ
*   完全なステートレス設計
*   水平スケーリングによる線形のスループット向上
*   CPU使用率に基づくオートスケーリング

### セキュリティ
*   TLS 1.3によるHTTPS通信
*   厳格な入力検証
*   セキュリティヘッダーの自動付与
*   DDoS対策（レート制限、リクエストサイズ制限）

### その他技術要件
*   **言語:** Go言語で実装
*   **フレームワーク:** 軽量HTTPルーター（gin, echo等）
*   **設定管理:** ConfigMapと環境変数による設定
*   **Observability:** OpenTelemetry SDKによる完全な可観測性

## 決まっていないこと

*   HTTPルーターライブラリの選定（gin vs echo vs chi）
*   サービスディスカバリの実装方式（Consul, Kubernetes Service）
*   レート制限アルゴリズムの詳細（Token Bucket vs Sliding Window）
*   サーキットブレーカーの実装（Hystrix-go vs 自前実装）
*   メトリクス公開フォーマット（Prometheus vs OpenTelemetry）