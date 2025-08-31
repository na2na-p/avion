# PRD: avion-auth

## 概要

Avionにおける認証（Authentication）および認可（Authorization）機能を統合して提供するマイクロサービスを実装する。ユーザーの認証処理、セッション管理、JWT発行・検証、および認可判定を一元的に扱い、プラットフォーム全体のアクセス制御を担う。

## 背景

SNSプラットフォームにおいて、安全で効率的なアクセス制御は最重要機能の一つである。Avionでは、以下の要件を満たす認証・認可サービスが必要となる：

*   多要素認証（パスワード、Passkey、TOTP）による強固なセキュリティ
*   JWTトークンの発行・検証・失効管理の一元化
*   スコープ/ロールベースのきめ細かな認可制御
*   高速な認証・認可判定によるシステム全体のパフォーマンス向上
*   Botクライアントに対するOAuth 2.0サポート

これらの機能を単一のサービスに統合することで、以下を実現する：

*   **パフォーマンス最適化:** 認証と認可を同一サービスで処理し、ネットワークオーバーヘッドを削減
*   **セキュリティ向上:** アクセス制御ロジックが一元管理され、セキュリティポリシーの適用が一貫する
*   **開発効率:** 認証・認可の実装が統一され、他サービスからの利用が簡単になる
*   **運用の単純化:** JWT署名鍵管理、セッション管理、認可ポリシーを一箇所で管理

## Scientific Merits

### パフォーマンス指標
*   **認証処理時間:** p50 < 50ms, p95 < 100ms, p99 < 200ms（パスワード認証、MFA含む）
*   **JWT検証時間:** < 5ms（署名検証、クレーム抽出を含む）
*   **認可判定時間:** p50 < 10ms, p99 < 20ms（ポリシー評価、キャッシュヒット時）
*   **レイテンシ削減:** 認証・認可判定を同一サービス内で完結させることで、サービス間通信のオーバーヘッドを排除。APIレスポンスタイム全体で30%削減。

### スケーラビリティ指標
*   **同時セッション数:** 1,000,000セッション（Redisクラスタでの管理）
*   **処理能力:** 10,000 req/s（ピーク時）、通常時5,000 req/s
*   **水平スケーリング:** CPU使用率70%で自動スケール、最小2レプリカ、最大20レプリカ
*   **キャッシュ容量:** 最大100,000エントリ（LRU方式）、キャッシュヒット率 > 95%

### セキュリティ指標
*   **パスワードハッシュ強度:** Argon2id（メモリ: 64MB、イテレーション: 3、並列度: 4）
*   **JWT有効期限:** アクセストークン15分、リフレッシュトークン7日間
*   **セッション有効期限:** 24時間（設定可能、最大7日間）
*   **ブルートフォース防御:** 5回失敗で15分間ロック、IPごとに10回/分の制限
*   **MFA採用率:** 目標50%以上のアクティブユーザー

### 可用性・信頼性指標
*   **SLA:** 99.99%（月間ダウンタイム < 4.32分）
*   **エラー率:** < 0.1%（認証成功率 > 99.9%）
*   **監査ログ保持:** 90日間（暗号化保存、改ざん検知付き）
*   **鍵ローテーション:** JWT署名鍵は30日ごと、暗号化鍵は90日ごと

### ビジネス価値
*   **運用コスト削減:** 認証・認可の統合により運用工数40%削減
*   **開発効率向上:** 統一APIにより新機能開発時間30%短縮
*   **セキュリティインシデント:** MTTR（平均復旧時間）< 30分
*   **コンプライアンス:** GDPR、CCPA準拠、SOC2 Type II認証対応

認証・認可機能はSNSプラットフォームの全APIアクセスの基盤となる重要な機能であり、高性能と高可用性を両立することで、プラットフォーム全体のユーザーエクスペリエンスを向上させることができる。

## Design Doc

[Design Doc: avion-auth](./designdoc.md)

## 参考ドキュメント

*   [Avion アーキテクチャ概要](./../common/architecture.md)
*   OAuth 2.0 / OpenID Connect (認可コードフロー、クライアントクレデンシャルフロー)
*   WebAuthn/FIDO2 仕様
*   TOTP (RFC 6238)
*   JWT (RFC 7519)

## 製品原則

*   **安全第一:** 全ての認証・認可判定において、セキュリティを最優先する。脆弱性が発見された場合は、機能性よりもセキュリティ対策を優先し、即座に対応する。
*   **高速レスポンス:** 認可判定は50ms以内、認証処理は200ms以内を目標とし、ユーザーの体感速度を損なわない。キャッシュを積極活用し、データベースアクセスを最小化する。
*   **最小権限の原則:** ユーザーには必要最小限の権限のみを付与し、権限のスコープと有効期限を明確に定義する。定期的な権限見直しプロセスを実装する。
*   **監査可能性:** 全てのアクセス制御判定は追跡・監査可能であり、不正アクセスの検知と法的要件への対応を確実にする。ログの改ざん検知機能を含む。
*   **標準準拠:** 業界標準のプロトコルとベストプラクティスに従い、独自仕様は最小限に抑える。新しい標準への移行パスを常に確保する。
*   **開発者フレンドリー:** 他サービスから簡単に利用できる直感的なAPIを提供し、詳細なドキュメントとエラーメッセージでサポートする。
*   **無停止運用:** 認証・認可サービスの停止は全サービスに影響するため、99.99%の可用性を維持し、ローリングアップデートによる無停止デプロイを実現する。
*   **透明な制御:** ユーザーは自分の認証情報とアクセス権限を明確に把握でき、必要に応じて制御できる。セキュリティ設定の変更履歴も提供する。

## やること/やらないこと

### やること

#### 認証機能
*   パスワード認証（Argon2idによるハッシュ化）
*   Passkey（WebAuthn）の登録・認証
*   TOTPの登録・管理・検証
*   多要素認証の強制設定
*   認証失敗回数の管理とアカウントロック
*   デバイス信頼度管理
*   異常ログイン検知
*   パスワードリセット機能

#### セッション管理
*   JWT発行（アクセストークン）
*   JWT検証（署名、有効期限、失効確認）
*   JWT署名鍵のローテーション
*   セッション失効管理
*   公開鍵提供エンドポイント（JWKS）
*   リフレッシュトークン（将来実装）
*   デバイスセッション管理

#### 認可機能
*   認可判定API（ユーザー、リソース、アクションに基づく許可/拒否）
*   ロール管理（user、bot、moderator、admin）
*   スコープ管理（drop:write、timeline:read等）
*   ポリシーベース認可（初期はコード内定義）
*   認可結果のキャッシング（高速化）
*   Bot用スコープ管理と検証
*   リソース所有者判定

#### OAuth 2.0
*   Client Credentials Flow（Bot認証用）
*   Authorization Code Flow（将来のサードパーティアプリ用）
*   トークンエンドポイント（/oauth/token）
*   スコープ検証とトークン発行
*   クライアント管理（登録、無効化）

#### セキュリティ機能
*   ブルートフォース攻撃対策
*   レート制限（認証試行回数）
*   セキュリティイベントログ
*   不審なアクティビティの検知
*   IPアドレスベースの制限
*   CSRF対策
*   トークン盗用検知

### やらないこと

*   **ユーザー登録・プロフィール管理:** avion-userが担当
*   **フォロー関係管理:** avion-userが担当
*   **モデレーション判定:** avion-moderationが担当
*   **メール送信:** avion-notificationが担当
*   **UIの提供:** avion-webが担当
*   **ユーザー検索:** avion-searchが担当
*   **メディア認証:** avion-mediaが独自に管理

## 対象ユーザ

*   Avionの全マイクロサービス（認証・認可が必要な全API）
*   avion-gateway（JWT検証、認可判定）
*   Botクライアント（OAuth 2.0経由）
*   システム管理者（ロール・ポリシー管理）

## ドメインモデル設計（DDD戦術的パターン）

### Aggregates (集約)

#### AuthCredential Aggregate
**責務**: ユーザーの認証情報を統合管理する集約
- **集約ルート**: AuthCredential
- **不変条件**:
  - UserIDは変更不可
  - パスワードは平文で保存不可（必ずArgon2idでハッシュ化）
  - 同一UserIDに対して複数のPasskeyを登録可能
  - TOTPSecretは1つのみ
  - 認証失敗回数の上限（5回でロック）
  - 最低1つの認証方法が有効である
  - ロック期間中は認証不可（15分間）
- **ドメインロジック**:
  - `verifyPassword(plainPassword)`: パスワード検証（Argon2id）
  - `canAuthenticate()`: 認証可能状態の判定（ロック状態チェック）
  - `recordFailedAttempt()`: 失敗回数増加とロック処理
  - `resetFailedAttempts()`: 失敗回数リセット
  - `requiresMFA()`: 多要素認証が必要かの判定
  - `addPasskey(credential)`: Passkey追加（最大10個）
  - `removePasskey(credentialID)`: Passkey削除（最低1つの認証方法維持）
  - `enableTOTP(secret)`: TOTP有効化
  - `disableTOTP()`: TOTP無効化（他の認証方法必須）
  - `validate()`: 認証情報全体の妥当性検証

#### Session Aggregate
**責務**: 認証セッションとJWTトークンを管理
- **集約ルート**: Session
- **不変条件**:
  - SessionID（JTI）は一意
  - 有効期限を過ぎたセッションは無効
  - 失効したセッションは復活不可
  - UserIDとセッションの紐付けは変更不可
  - SessionTypeは定義された値のみ
  - RefreshTokenは1つのアクセストークンに対して1つ
- **ドメインロジック**:
  - `isValid()`: セッション有効性判定（期限、失効チェック）
  - `revoke()`: セッション失効処理
  - `canRefresh()`: リフレッシュ可能かの判定
  - `generateJWT(signingKey)`: JWT生成
  - `extractClaims()`: JWTクレーム抽出
  - `shouldRotateRefreshToken()`: リフレッシュトークンローテーション判定
  - `recordActivity()`: セッション活動記録
  - `detectAnomalies()`: 異常検知（IP変更、User-Agent変更）

#### SigningKey Aggregate
**責務**: JWT署名鍵のライフサイクル管理
- **集約ルート**: SigningKey
- **不変条件**:
  - KeyIDは一意
  - 秘密鍵は暗号化して保存
  - アクティブな署名鍵は1つのみ
  - ローテーション時は古い鍵も一定期間保持
  - 期限切れ鍵での署名は不可
  - 鍵の復号には専用のKMSを使用
- **ドメインロジック**:
  - `canSign()`: 署名可能かの判定（アクティブかつ期限内）
  - `canVerify()`: 検証可能かの判定（期限内）
  - `rotate(newKey)`: 鍵ローテーション処理
  - `sign(payload)`: ペイロード署名
  - `verify(token)`: トークン検証
  - `exportPublicKey()`: 公開鍵エクスポート（JWKS形式）
  - `shouldRotate()`: ローテーション必要性判定
  - `markAsInactive()`: 非アクティブ化

#### Authorization Aggregate
**責務**: ユーザーの権限情報と認可判定を管理
- **集約ルート**: Authorization
- **不変条件**:
  - UserIDは変更不可
  - デフォルトロールは必ず付与される
  - 矛盾するロールの同時付与は禁止
  - システムロールの削除は不可
  - 権限の委譲は1段階まで
  - 有効期限切れのロールは自動削除
- **ドメインロジック**:
  - `hasPermission(resource, action)`: 権限判定
  - `addRole(role, grantedBy)`: ロール付与（権限チェック含む）
  - `removeRole(roleID, removedBy)`: ロール削除（システムロール除く）
  - `canGrant(roleID, granterID)`: ロール付与権限判定
  - `getEffectiveScopes()`: 有効なスコープ一覧取得
  - `isAllowed(policy)`: ポリシーベース判定
  - `exportPermissions()`: 権限エクスポート（JWT用）
  - `audit()`: 権限変更監査ログ生成

#### BotClient Aggregate
**責務**: Botクライアントの認証情報とスコープを管理
- **集約ルート**: BotClient
- **不変条件**:
  - ClientIDは一意かつ変更不可
  - ClientSecretは平文で保存不可
  - OwnerUserIDは変更不可
  - 無効化されたクライアントは復活不可
  - スコープは所有者の権限を超えない
  - 有効期限切れクライアントは使用不可
- **ドメインロジック**:
  - `verifySecret(plainSecret)`: シークレット検証
  - `canAuthenticate()`: 認証可能状態判定
  - `updateScopes(scopes, updatedBy)`: スコープ更新（権限チェック）
  - `revoke(revokedBy)`: クライアント無効化
  - `regenerateSecret()`: シークレット再生成
  - `validateScopes(requestedScopes)`: スコープ妥当性検証
  - `toOAuthClient()`: OAuth 2.0クライアント形式変換
  - `shouldExpire()`: 有効期限判定

#### Role Aggregate
**責務**: ロール定義とスコープマッピングを管理
- **集約ルート**: Role
- **不変条件**:
  - RoleIDは一意
  - システムロールの変更は制限付き
  - スコープの循環参照は禁止
  - 基本ロールは削除不可
  - 階層深度は最大3レベル
  - 同一スコープの重複は自動除去
- **ドメインロジック**:
  - `hasScope(scopeID)`: スコープ保有判定
  - `addScope(scope)`: スコープ追加（循環参照チェック）
  - `removeScope(scopeID)`: スコープ削除
  - `canInherit(parentRole)`: 継承可能性判定
  - `getEffectiveScopes()`: 継承込みの有効スコープ取得
  - `isSystemRole()`: システムロール判定
  - `validate()`: ロール定義の妥当性検証
  - `merge(otherRole)`: ロール統合

#### Policy Aggregate
**責務**: 認可ポリシーの定義と評価
- **集約ルート**: Policy
- **不変条件**:
  - PolicyIDは一意
  - ポリシー定義は有効な形式
  - 矛盾するルールは検出される
  - デフォルトは拒否（明示的な許可が必要）
  - 優先度は0-100の範囲
  - 条件式は評価可能である
- **ドメインロジック**:
  - `evaluate(context)`: ポリシー評価（Allow/Deny/NotApplicable）
  - `matches(resource, action)`: 適用判定
  - `hasConflict(otherPolicy)`: 競合検出
  - `merge(otherPolicy)`: ポリシー統合
  - `toPolicyDocument()`: ポリシードキュメント形式変換
  - `validate()`: ポリシー定義の妥当性検証
  - `getPriority()`: 優先度取得
  - `isApplicable(context)`: 適用可能性判定

### Entities (エンティティ)

#### PasskeyCredential Entity
**所属**: AuthCredential Aggregate
**責務**: WebAuthnクレデンシャル情報を管理
- **属性**:
  - CredentialID（Entity識別子）
  - PublicKey（公開鍵）
  - SignCount（署名カウンタ）
  - DeviceName（デバイス名）
  - AAGUID（認証器GUID）
  - BackupEligible（バックアップ可能フラグ）
  - CreatedAt（登録日時）
  - LastUsedAt（最終使用日時）
- **ビジネスルール**:
  - SignCountは単調増加
  - PublicKeyは変更不可
  - DeviceNameは50文字以内

#### TOTPCredential Entity
**所属**: AuthCredential Aggregate
**責務**: TOTP認証情報を管理
- **属性**:
  - Secret（Entity識別子、Base32エンコード）
  - RecoveryCodes（リカバリーコード配列）
  - EnabledAt（有効化日時）
  - LastUsedAt（最終使用日時）
  - BackupCodesUsed（使用済みバックアップコード）
- **ビジネスルール**:
  - Secretは32文字のBase32文字列
  - RecoveryCodesは8個生成
  - 各RecoveryCodeは一度のみ使用可能

#### DeviceSession Entity
**所属**: Session Aggregate
**責務**: デバイス別セッション情報を管理
- **属性**:
  - DeviceID（Entity識別子）
  - DeviceName（デバイス名）
  - DeviceFingerprint（デバイスフィンガープリント）
  - UserAgent（User-Agent文字列）
  - IPAddress（IPアドレス）
  - Location（推定位置情報）
  - TrustLevel（信頼レベル）
  - LastActiveAt（最終活動日時）
- **ビジネスルール**:
  - TrustLevelは0-100の範囲
  - IPAddressはIPv4/IPv6形式
  - 信頼できないデバイスは追加認証必要

#### RefreshToken Entity
**所属**: Session Aggregate
**責務**: リフレッシュトークン情報を管理
- **属性**:
  - TokenID（Entity識別子）
  - TokenHash（トークンハッシュ）
  - IssuedAt（発行日時）
  - ExpiresAt（有効期限）
  - RotationCount（ローテーション回数）
  - ParentTokenID（親トークンID）
- **ビジネスルール**:
  - TokenHashはSHA-256ハッシュ
  - RotationCountは最大10回
  - 親トークン使用時は全系列無効化

#### UserRole Entity
**所属**: Authorization Aggregate
**責務**: ユーザーに付与されたロールを管理
- **属性**:
  - RoleID（Entity識別子）
  - AssignedBy（付与者UserID）
  - AssignedAt（付与日時）
  - ExpiresAt（有効期限）
  - Reason（付与理由）
- **ビジネスルール**:
  - 有効期限は最大1年
  - AssignedByは変更不可
  - システムロールは期限なし

#### BotScope Entity
**所属**: BotClient Aggregate
**責務**: Botクライアントのスコープを管理
- **属性**:
  - ScopeID（Entity識別子）
  - GrantedAt（付与日時）
  - GrantedBy（付与者UserID）
  - ExpiresAt（有効期限）
- **ビジネスルール**:
  - 所有者の権限範囲内のみ
  - 有効期限は最大90日

#### PolicyRule Entity
**所属**: Policy Aggregate
**責務**: ポリシー内の個別ルールを管理
- **属性**:
  - RuleID（Entity識別子）
  - Effect（Allow/Deny）
  - ResourcePattern（リソースパターン）
  - ActionPattern（アクションパターン）
  - Conditions（条件式）
  - Order（評価順序）
- **ビジネスルール**:
  - ResourcePatternは正規表現
  - Conditionsは評価可能な式
  - Orderは1から始まる連番

#### AuditLog Entity
**所属**: 独立（監査用）
**責務**: 認証・認可の監査ログを管理
- **属性**:
  - LogID（Entity識別子）
  - UserID（対象ユーザー）
  - Action（実行アクション）
  - Resource（対象リソース）
  - Result（成功/失敗）
  - IPAddress（実行元IP）
  - Timestamp（実行日時）
  - Details（詳細情報JSON）
- **ビジネスルール**:
  - 過去ログは変更不可
  - 90日間保持必須
  - PII情報は暗号化

### Value Objects (値オブジェクト)

**識別子関連**
- **UserID**: ユーザーの一意識別子（Snowflake ID）
- **SessionID**: セッションの一意識別子（UUID v4）
- **ClientID**: OAuthクライアントID（ランダム文字列）
- **KeyID**: 署名鍵の識別子（kid）
- **PolicyID**: ポリシーの一意識別子（UUID v4）
- **RoleID**: ロールの識別子（文字列、例: "admin"）
- **ScopeID**: スコープの識別子（文字列、例: "drop:write"）

**認証関連**
- **PasswordHash**: Argon2idハッシュ化されたパスワード
  - memory=64MB, iterations=3, parallelism=2
  - Salt長: 16バイト
  - Hash長: 32バイト
- **PlainPassword**: 平文パスワード（一時的使用のみ）
  - 最小8文字、最大128文字
  - 複雑性要件（大小英数字記号）
- **TOTPCode**: 6桁のTOTPコード
  - 数字のみ、30秒有効
- **RecoveryCode**: 8文字のリカバリーコード
  - 英数字、大文字小文字区別なし
- **ClientSecret**: OAuthクライアントシークレット
  - 32文字のランダム文字列
  - Base64URLエンコード

**JWT関連**
- **JWTToken**: JWT形式のトークン
  - Header.Payload.Signature形式
  - RS256署名
- **JWTClaims**: JWTのクレーム情報
  - sub, iat, exp, jti必須
  - カスタムクレーム対応
- **JWTHeader**: JWTヘッダー情報
  - alg: RS256固定
  - kid: 署名鍵ID
  - typ: JWT
- **TokenType**: トークン種別
  - `access`: アクセストークン
  - `refresh`: リフレッシュトークン
  - `id`: IDトークン

**セッション関連**
- **SessionType**: セッション種別
  - `human`: 人間ユーザー
  - `bot`: Botクライアント
  - `service`: サービス間通信
- **DeviceFingerprint**: デバイス識別情報
  - User-Agent、画面解像度、タイムゾーン等のハッシュ
- **IPAddress**: IPアドレス（IPv4/IPv6）
  - CIDR記法対応
  - 地理情報マッピング
- **TrustLevel**: デバイス信頼度（0-100）
  - 0-30: 不信
  - 31-70: 通常
  - 71-100: 信頼

**認可関連**
- **Permission**: 権限情報
  - Resource + Action の組み合わせ
  - ワイルドカード対応
- **Resource**: 対象リソース
  - 形式: "service:resource:id"
  - 例: "drop:post:12345"
- **Action**: 実行アクション
  - CRUD操作: create, read, update, delete
  - カスタムアクション対応
- **Effect**: ポリシー効果
  - `allow`: 許可
  - `deny`: 拒否
  - `not_applicable`: 非適用
- **PolicyCondition**: ポリシー条件
  - JSON形式の条件式
  - 変数展開対応

**時刻・期間**
- **CreatedAt**: 作成日時（UTC、ミリ秒精度）
- **UpdatedAt**: 更新日時（UTC、ミリ秒精度）
- **ExpiresAt**: 有効期限（UTC、ミリ秒精度）
- **IssuedAt**: 発行日時（UTC、ミリ秒精度）
- **LockedUntil**: ロック解除日時（UTC）
- **LastUsedAt**: 最終使用日時（UTC）
- **Duration**: 期間（ISO 8601形式）
  - 例: "PT15M"（15分）
  - 例: "P30D"（30日）

**セキュリティ関連**
- **FailedAttempts**: 認証失敗回数（0-5）
- **SignCount**: WebAuthn署名カウンタ（単調増加）
- **SecurityEventType**: セキュリティイベント種別
  - `login_success`: ログイン成功
  - `login_failure`: ログイン失敗
  - `suspicious_activity`: 不審なアクティビティ
  - `account_locked`: アカウントロック
  - `password_reset`: パスワードリセット
- **AuditAction**: 監査アクション
  - `auth.login`: ログイン
  - `auth.logout`: ログアウト
  - `authz.grant`: 権限付与
  - `authz.revoke`: 権限剥奪

### Domain Services

#### AuthenticationService
**責務**: 認証関連の処理を統括（パスワード処理とトークン管理を統合）
- **メソッド**:
  - `authenticate(credentials)`: 統合認証処理
  - `refreshAuthentication(refreshToken)`: 認証更新
  - `terminateSession(sessionID)`: セッション終了
  - `hashPassword(plainPassword)`: Argon2idでハッシュ化
  - `verifyPassword(plainPassword, hash)`: パスワード検証
  - `validatePasswordStrength(password)`: 強度検証
  - `generateJWT(claims, signingKey)`: JWT生成
  - `verifyJWT(token, publicKeys)`: JWT検証
  - `extractClaims(token)`: クレーム抽出
  - `revokeToken(jti)`: トークン失効
  - `isRevoked(jti)`: 失効確認

#### MFAService
**責務**: 多要素認証全般を統括（TOTP、WebAuthn、リカバリーコード）
- **メソッド**:
  - `generateTOTPSecret()`: TOTPシークレット生成
  - `verifyTOTP(secret, code)`: TOTPコード検証
  - `generateRecoveryCodes()`: リカバリーコード生成
  - `verifyRecoveryCode(codes, input)`: リカバリーコード検証
  - `generateQRCode(secret, userID)`: QRコード生成
  - `generateWebAuthnRegistrationOptions(userID)`: WebAuthn登録オプション生成
  - `verifyWebAuthnRegistrationResponse(response)`: WebAuthn登録レスポンス検証
  - `generateWebAuthnAuthenticationOptions(userID)`: WebAuthn認証オプション生成
  - `verifyWebAuthnAuthenticationResponse(response, credential)`: WebAuthn認証レスポンス検証
  - `updateWebAuthnSignCount(credentialID, count)`: WebAuthn署名カウンタ更新

#### AuthorizationService
**責務**: 認可判定の処理を統括
- **メソッド**:
  - `checkPermission(userID, resource, action)`: 権限チェック
  - `evaluatePolicies(context, policies)`: ポリシー評価
  - `resolveConflicts(effects)`: 競合解決
  - `expandScopes(roles)`: スコープ展開
  - `cacheResult(key, result)`: 結果キャッシュ
  - `invalidateCache(pattern)`: キャッシュ無効化
  - `loadPolicies(resource)`: ポリシー読み込み
  - `evaluateConditions(conditions, context)`: 条件評価

#### AuditService
**責務**: 監査ログの記録と管理
- **メソッド**:
  - `logAuthenticationAttempt(userID, result, details)`: 認証試行記録
  - `logAuthorizationDecision(userID, resource, action, result)`: 認可判定記録
  - `logSecurityEvent(eventType, details)`: セキュリティイベント記録
  - `logPasswordChange(userID, timestamp)`: パスワード変更記録
  - `logMFAEvent(userID, mfaType, event)`: MFAイベント記録
  - `queryAuditLogs(criteria)`: 監査ログ検索
  - `exportAuditReport(period)`: 監査レポート出力
  - `archiveOldLogs(threshold)`: 古いログのアーカイブ

#### SecurityMonitoringService
**責務**: セキュリティ監視と異常検知
- **メソッド**:
  - `detectBruteForce(ipAddress, userID)`: ブルートフォース検知
  - `detectAnomalousLogin(session, context)`: 異常ログイン検知
  - `assessRisk(context)`: リスク評価
  - `triggerAlert(alertType, details)`: アラート発火
  - `blockSuspiciousActivity(context)`: 不審アクティビティブロック
  - `analyzeLoginPattern(userID, history)`: ログインパターン分析
  - `detectAccountTakeover(indicators)`: アカウント乗っ取り検知
  - `updateThreatIntelligence(data)`: 脅威インテリジェンス更新

## ユースケース

### ユーザーログイン（パスワード認証）

**事前条件:**
- ユーザーアカウントが存在する
- ユーザーアカウントが無効化されていない
- システムがメンテナンスモードでない

**正常フロー:**
1. ユーザーがログインフォームにユーザー名とパスワードを入力
2. フロントエンドは `avion-gateway` 経由で `avion-auth` に認証リクエストを送信
3. AuthenticateCommandUseCase がリクエストを処理
4. UserValidationService で avion-user にユーザー存在確認（gRPC）
5. AuthCredentialRepository から AuthCredential Aggregate を取得
6. AuthCredential.canAuthenticate() でロック状態を確認
7. AuthenticationService.verifyPassword() でパスワード検証
8. 認証成功時は AuthCredential.resetFailedAttempts() を実行
9. AuthCredential.requiresMFA() でMFA必要性を確認
10. MFA不要時は通常のセッション生成処理へ
11. AuthorizationRepository から Authorization Aggregate を取得
12. Authorization.getEffectiveScopes() でスコープ取得
13. SessionFactory で Session Aggregate を生成
14. SigningKeyRepository から現在アクティブな SigningKey を取得
15. AuthenticationService.generateJWT() でアクセストークン生成
16. SessionRepository でセッション永続化
17. AuditService.logAuthenticationAttempt() で監査ログ記録
18. AuthenticateResponse DTO を返却（AccessToken、RefreshToken、ExpiresIn含む）

**エラーケース:**
- E1: ユーザーが存在しない → UserNotFoundException（404）
- E2: パスワードが間違っている → InvalidCredentialsException（401）
- E3: アカウントがロック中 → AccountLockedException（423）
- E4: アカウントが無効化 → AccountDisabledException（403）
- E5: ネットワークエラー → ServiceUnavailableException（503）

**代替フロー（認証失敗）:**
1. ステップ7でパスワード検証失敗
2. AuthCredential.recordFailedAttempt() で失敗回数増加
3. 失敗回数が5回に達した場合、15分間のアカウントロック
4. AuditService.logAuthenticationAttempt() で失敗を記録
5. SecurityMonitoringService.detectBruteForce() でブルートフォース検知
6. InvalidCredentialsException を返却

**代替フロー（MFA必要）:**
1. ステップ9でMFA必要と判定
2. TemporarySessionService で一時セッション生成（5分有効）
3. MFARequiredResponse を返却（temporarySessionID含む）
4. クライアントはMFA画面へ遷移

**事後条件:**
- 成功時：有効なセッションが生成されている
- 成功時：アクセストークンが発行されている
- 失敗時：失敗回数がインクリメントされている
- 全ケース：監査ログが記録されている

(UIモック: ログインフォーム)

### TOTP認証（二要素認証）

**事前条件:**
- 一時セッションが有効（5分以内）
- ユーザーがTOTPを設定済み
- 認証アプリが正しく同期されている

**正常フロー:**
1. ユーザーが認証アプリで表示される6桁のコードを入力
2. フロントエンドは一時セッションIDとTOTPコードを送信
3. ValidateTOTPCommandUseCase がリクエストを処理
4. TemporarySessionCache から一時セッション情報を取得
5. AuthCredentialRepository から AuthCredential を取得
6. TOTPCredential Entity から Secret を取得
7. MFAService.verifyTOTP() でコード検証（30秒の時間窓、±1ドリフト許容）
8. 同一コードの再利用を防ぐため LastUsedAt を更新
9. Authorization、Session生成は通常ログインと同様
10. TemporarySessionCache から一時セッション削除
11. AuditService.logMFAEvent() でMFA成功を記録
12. ValidateTOTPResponse DTO を返却（AccessToken、RefreshToken含む）

**エラーケース:**
- E1: 一時セッションが期限切れ → SessionExpiredException（401）
- E2: TOTPコードが無効 → InvalidTOTPException（401）
- E3: 同一コードの再利用 → DuplicateTOTPException（401）
- E4: 連続失敗（3回）→ TemporaryLockException（429）
- E5: TOTPが未設定 → MFANotConfiguredException（400）

**代替フロー（リカバリーコード使用）:**
1. ユーザーが「リカバリーコードを使用」を選択
2. 8文字のリカバリーコードを入力
3. ValidateRecoveryCodeCommandUseCase がリクエストを処理
4. MFAService.verifyRecoveryCode() で検証
5. 使用済みコードをマーク
6. 残りコードが2個以下の場合、警告を含める
7. 通常のセッション生成処理へ

**代替フロー（時刻ずれ対応）:**
1. ステップ7で初回検証失敗
2. 前後1つの時間窓（±30秒）で再検証
3. 成功した場合、時刻ずれを記録
4. 3回連続で時刻ずれ検出時、ユーザーに通知

**事後条件:**
- 成功時：本セッションが生成されている
- 成功時：一時セッションが削除されている
- 失敗時：失敗回数が記録されている
- 全ケース：MFAイベントが監査ログに記録されている

(UIモック: TOTP入力フォーム)

### Passkey登録

1. ユーザーがアカウント設定から「Passkeyを追加」を選択
2. フロントエンドは登録開始リクエストを送信
3. RegisterPasskeyStartCommandUseCase がリクエストを処理
4. WebAuthnService.generateRegistrationOptions() でオプション生成
5. チャレンジをセッションに保存
6. RegisterPasskeyStartResponse を返却（PublicKeyCredentialCreationOptions）
7. ブラウザがWebAuthn APIを使用してクレデンシャル生成
8. フロントエンドは生成されたクレデンシャルを送信
9. RegisterPasskeyFinishCommandUseCase がリクエストを処理
10. WebAuthnService.verifyRegistrationResponse() で検証
11. PasskeyCredentialFactory で PasskeyCredential Entity 生成
12. AuthCredential.addPasskey() でクレデンシャル追加
13. AuthCredentialRepository で永続化
14. RegisterPasskeyFinishResponse を返却

(UIモック: Passkey登録ダイアログ)

### JWT検証

**事前条件:**
- JWTトークンが Authorization ヘッダーに含まれる
- トークンが正しいフォーマット（Bearer scheme）
- 署名鍵が利用可能

**正常フロー:**
1. サービスが Authorization ヘッダー付きでAPIリクエスト
2. ValidateTokenQueryUseCase がリクエストを処理
3. TokenCacheService でキャッシュ確認（JTI単位）
4. キャッシュヒット時は即座に結果返却
5. キャッシュミスの場合、AuthenticationService.extractClaims() でクレーム抽出
6. 有効期限（exp）確認
7. 発行時刻（iat）が未来でないことを確認
8. RevokedTokenCache で失効確認
9. SigningKeyRepository から対応する公開鍵取得（kid使用）
10. AuthenticationService.verifyJWT() で署名検証
11. SessionRepository から Session Aggregate 取得
12. Session.isValid() でセッション有効性確認
13. DeviceSession の異常検知（IP変更等）
14. 検証結果を TokenCacheService にキャッシュ（TTL: 1分）
15. ValidateTokenResponse を返却（UserID、Scopes、ExpiresAt含む）

**エラーケース:**
- E1: トークンが期限切れ → TokenExpiredException（401）
- E2: トークンが失効済み → TokenRevokedException（401）
- E3: 署名検証失敗 → InvalidSignatureException（401）
- E4: セッションが無効 → InvalidSessionException（401）
- E5: トークンフォーマット不正 → MalformedTokenException（400）
- E6: 公開鍵が見つからない → KeyNotFoundException（500）

**代替フロー（リフレッシュトークン使用）:**
1. アクセストークンが期限切れ（E1）
2. クライアントがリフレッシュトークンを送信
3. RefreshTokenCommandUseCase がリクエストを処理
4. リフレッシュトークンの有効性確認
5. 新しいアクセストークン生成
6. リフレッシュトークンローテーション
7. 新しいトークンペアを返却

**代替フロー（デバイス変更検知）:**
1. ステップ13でIP/デバイス変更検知
2. リスクレベル評価
3. 低リスク：警告ログのみ記録
4. 高リスク：セッション一時停止、再認証要求

**事後条件:**
- 成功時：検証結果がキャッシュされている
- 成功時：アクセスログが記録されている
- 失敗時：セキュリティイベントが記録されている
- 全ケース：パフォーマンスメトリクスが更新されている

### 認可判定

1. サービスが UserID、Resource、Action で認可判定要求
2. CheckAuthorizationQueryUseCase がリクエストを処理
3. AuthorizationCacheService で結果確認（キャッシュヒット時は即返却）
4. AuthorizationRepository から Authorization Aggregate 取得
5. Authorization.hasPermission() で基本権限チェック
6. RoleRepository から関連 Role Aggregate 取得
7. Role.getEffectiveScopes() で継承含むスコープ展開
8. PolicyRepository から適用可能な Policy Aggregate 取得
9. AuthorizationService.evaluatePolicies() でポリシー評価
10. 複数ポリシーの競合を AuthorizationService.resolveConflicts() で解決
11. 最終的な判定結果を生成（Allow/Deny）
12. AuditService.logAuthorizationDecision() で監査ログ記録
13. 結果を AuthorizationCacheService にキャッシュ（TTL: 5分）
14. CheckAuthorizationResponse を返却（allowed、reason含む）

### Bot認証（OAuth 2.0 Client Credentials）

1. BotがClientIDとClientSecretで `/oauth/token` へPOST
2. OAuthTokenCommandUseCase がリクエストを処理
3. grant_type=client_credentials を検証
4. BotClientRepository から BotClient Aggregate 取得
5. BotClient.verifySecret() でシークレット検証
6. BotClient.canAuthenticate() で有効性確認（無効化、期限）
7. BotClient.validateScopes() で要求スコープ検証
8. BotSessionFactory で Bot用 Session 生成（有効期限15分）
9. SigningKeyRepository からアクティブな SigningKey 取得
10. TokenService.generateJWT() でアクセストークン生成（Bot用claims）
11. SessionRepository でセッション永続化
12. AuditService.logAuthenticationAttempt() で監査ログ
13. OAuthTokenResponse を返却（OAuth 2.0形式）

### ロール付与

1. 管理者が管理画面でユーザーにロールを付与
2. AssignRoleCommandUseCase がリクエストを処理
3. 実行者の権限を AuthorizationService.checkPermission() で確認
4. AuthorizationRepository から対象ユーザーの Authorization 取得
5. RoleRepository から付与する Role Aggregate 取得
6. Authorization.canGrant() で付与可能性判定
7. 矛盾するロールがないか確認
8. UserRoleFactory で UserRole Entity 生成
9. Authorization.addRole() でロール追加
10. AuthorizationRepository で永続化
11. AuthorizationCacheService のキャッシュ無効化
12. RoleAssignmentEventPublisher でイベント発行
13. AuditService.logAuthorizationDecision() で監査ログ
14. AssignRoleResponse を返却

### セッション失効

1. ユーザーがログアウトボタンをクリック
2. RevokeSessionCommandUseCase がリクエストを処理
3. SessionRepository から Session Aggregate 取得
4. Session.revoke() で失効処理
5. RevokedTokenCache に JTI を追加（TTL: 元の有効期限まで）
6. RefreshToken があれば連鎖的に失効
7. SessionRepository で永続化
8. SessionCacheService のキャッシュ削除
9. DeviceSessionService で関連デバイス情報更新
10. AuditService.logAuthenticationAttempt() で監査ログ
11. RevokeSessionResponse を返却

### パスワードリセット

1. ユーザーが「パスワードを忘れた」リンクをクリック
2. メールアドレスまたはユーザー名を入力
3. RequestPasswordResetCommandUseCase がリクエストを処理
4. UserValidationService で avion-user にユーザー確認
5. PasswordResetTokenService でリセットトークン生成
6. トークンを PasswordResetCache に保存（TTL: 1時間）
7. NotificationService 経由でリセットメール送信依頼
8. RequestPasswordResetResponse を返却（成功/失敗を隠蔽）
9. ユーザーがメール内のリンクをクリック
10. 新しいパスワードを入力
11. ResetPasswordCommandUseCase がリクエストを処理
12. PasswordResetCache からトークン検証
13. PasswordService.validatePasswordStrength() で強度確認
14. PasswordService.hashPassword() でハッシュ化
15. AuthCredential のパスワード更新
16. 全既存セッションを失効
17. PasswordResetCache からトークン削除
18. AuditService.logSecurityEvent() で監査ログ
19. ResetPasswordResponse を返却

### 異常ログイン検知

1. ユーザーが新しいデバイス/場所からログイン試行
2. AuthenticateCommandUseCase 内で処理
3. DeviceFingerprintService でデバイス情報収集
4. SecurityMonitoringService.detectAnomalousLogin() で異常検知
5. 過去のログイン履歴と比較（IP、地理情報、デバイス）
6. リスクスコア計算（0-100）
7. 高リスク（>70）の場合、追加認証要求
8. AdditionalVerificationRequired レスポンス返却
9. ユーザーがメールで受信したコード入力
10. VerifyAdditionalAuthCommandUseCase で検証
11. 検証成功時、DeviceSession を信頼済みとしてマーク
12. 通常のセッション生成処理へ
13. SecurityAlertService で所有者に通知

## 機能要求

### 認証機能
*   パスワード: Argon2id（memory=64MB, iterations=3, parallelism=2）
*   Passkey: WebAuthn Level 2準拠、最大10デバイス
*   TOTP: SHA-256、6桁、30秒時間窓、ドリフト許容±1
*   リカバリーコード: 8個生成、各8文字、一度のみ使用可
*   アカウントロック: 5回失敗で15分ロック、管理者による即時解除可能
*   デバイス信頼: 30日間有効、最大5デバイス

### セッション管理
*   アクセストークン: RS256署名、1時間有効（人間）、15分（Bot）
*   リフレッシュトークン: 7日間有効、ローテーション式
*   署名鍵: 30日ごとローテーション、古い鍵は7日保持
*   同時セッション: ユーザーあたり最大10セッション
*   失効管理: 即座に反映、Redis管理、TTLは元の有効期限

### 認可機能
*   基本ロール: user, bot, moderator, admin
*   カスタムロール: 最大100個定義可能
*   スコープ: リソース:アクション形式、ワイルドカード対応
*   ポリシー: JSON形式、優先度付き、条件式対応
*   キャッシュ: TTL 5分、LRU方式、最大10000エントリ

## セキュリティ実装ガイドライン

このサービスは以下のセキュリティガイドラインに準拠する必要がある：

### CSRF保護
- **ガイドライン**: [../common/security/csrf-protection.md](../common/security/csrf-protection.md)
- **実装要件**: すべての認証エンドポイントは、ダブルサブミットクッキーとOrigin検証によるCSRF保護を実装する必要がある。パスワードリセット、MFA登録、セッション管理などの重要な操作はCSRFトークンを検証する必要がある。OAuthフローはCSRF防止のためのstateパラメータを含める必要がある。

### TLS設定
- **ガイドライン**: [../common/security/tls-configuration.md](../common/security/tls-configuration.md)
- **実装要件**: 認証データを扱うすべての接続でTLS 1.3を強制する。重要な内部サービス通信には証明書ピンニングを実装する。JWT署名鍵と機密認証情報は、適切に設定されたTLS接続（該当する場合は相互認証を含む）を介してのみ送信される必要がある。

### 暗号化ガイドライン
- **ガイドライン**: [../common/security/encryption-guidelines.md](../common/security/encryption-guidelines.md)
- **実装要件**: パスワードハッシュには指定されたパラメータ（memory=64MB、iterations=3、parallelism=2）でArgon2idを使用する。JWT署名は最小2048ビット鍵でRS256を使用する必要がある。保存時の機密データ（リカバリーコード、TOTPシークレット）はAES-256-GCMを使用して暗号化する必要がある。署名鍵（30日サイクル）と暗号化鍵（90日サイクル）の適切な鍵ローテーションを実装する。

### セキュリティヘッダー
- **ガイドライン**: [../common/security/security-headers.md](../common/security/security-headers.md)
- **実装要件**: すべての認証エンドポイントに適切なセキュリティヘッダーを設定する。これにはX-Frame-Options（DENY）、X-Content-Type-Options（nosniff）、厳格なContent-Security-Policyが含まれる。認証レスポンスには、機密データのキャッシュを防ぐための適切なCache-Controlヘッダーを含める必要がある。

## 技術的要求

### パフォーマンス
*   認証処理: p50 < 100ms、p99 < 300ms
*   認可判定: p50 < 20ms、p99 < 100ms（キャッシュなし）
*   JWT検証: p50 < 5ms、p99 < 20ms
*   同時接続: 10,000リクエスト/秒
*   データベース接続: プール最大100、タイムアウト5秒

### 可用性
*   99.99%の可用性目標（月間ダウンタイム4.32分以内）
*   Kubernetes上で最小3レプリカ、最大10レプリカ
*   ローリングアップデート、最大サージ1、最大利用不可0
*   ヘルスチェック: /health（liveness）、/ready（readiness）
*   グレースフルシャットダウン: 30秒

### セキュリティ
*   全通信TLS 1.3必須、1.2は非推奨
*   秘密情報: 環境変数またはKubernetes Secret
*   監査ログ: 90日保持、暗号化、改ざん検知
*   OWASP Top 10対策実装
*   セキュリティヘッダー: HSTS、CSP、X-Frame-Options等

### スケーラビリティ
*   水平スケール: ステートレス設計、セッション情報はRedis
*   Redisクラスタ: 3ノード以上、自動フェイルオーバー
*   データベース: 読み取りレプリカ活用、シャーディング対応準備
*   メトリクス駆動: CPU使用率70%で自動スケールアウト
*   バックプレッシャー: Circuit Breaker、レート制限

## 決まっていないこと

*   リフレッシュトークンの実装時期と詳細仕様
*   外部IdP連携（Google、GitHub、Twitter等）の要否と優先順位
*   詳細な権限スコープの定義（初期は基本的なCRUD操作のみ）
*   ポリシー記述言語（Rego、CEL等）の採用
*   セッション同時接続数の制限ポリシー
*   地理的アクセス制限の実装範囲
*   生体認証（Face ID、指紋）のサポート
*   ゼロトラストアーキテクチャへの移行計画