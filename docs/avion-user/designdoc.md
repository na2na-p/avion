# Design Doc: avion-user

**Author:** Cline
**Last Updated:** 2025/03/30

## 1. Summary (これは何？)

- **一言で:** Avionにおけるユーザーアカウント管理、プロフィール、フォロー関係、ミュート/ブロック、およびユーザー設定を提供するマイクロサービスを実装します。
- **目的:** ユーザー情報の永続化、フォロー関係の管理、プライバシー制御（ミュート/ブロック）、個人設定の管理を提供します。他のサービス（Drop, Timeline, Notification, ActivityPubなど）へのユーザー情報提供とイベント通知も行います。

## テスト戦略

このサービスでは、[共通テスト戦略](../common/testing-strategy.md)に従ってテストを実装します。

### テスト方針
- **TDD必須**: インターフェース定義 → テスト作成 → 実装の順序を厳守
- **カバレッジ目標**: ユニットテスト85%以上、クリティカルパス95%以上
- **テーブル駆動テスト**: 全テストで必須
- **モック生成**: `go.uber.org/mock/gomock`使用

### E2Eテスト

このサービスのE2Eテストは、[共通E2Eテスト戦略](../common/e2e-testing-strategy.md)に従って実装します。

#### 主要なE2Eテストシナリオ
- ユーザー登録からプロフィール設定完了までのフルサイクル
- フォロー/アンフォロー機能の完全なワークフロー
- ブロック/ミュート機能とその影響の確認
- プライバシー設定変更とその反映の検証
- ユーザー検索機能の精度と性能確認
- プロフィール更新とリアルタイム反映の確認
- 相互フォロー状態の管理と通知連携
- 大量フォロワー/フォロイーでの性能確認

詳細は[共通E2Eテスト戦略ドキュメント](../common/e2e-testing-strategy.md)を参照してください。

詳細は[共通テスト戦略ドキュメント](../common/testing-strategy.md)を参照してください。

## 3. 技術スタック

このサービスでは、[共通Goバックエンド技術スタックガイドライン](../common/architecture/go-backend-framework.md)に従った実装を行います。

### 主要技術
- **HTTPルーティング:** Chi v5
- **RPC:** ConnectRPC
- **ミドルウェア:** 標準net/httpベースの共通ミドルウェア

詳細な実装パターンおよびライブラリの使用方法については、[ガイドライン](../common/architecture/go-backend-framework.md)を参照してください。

## 4. Background & Links (背景と関連リンク)

- SNSの基盤機能であるユーザー管理機能を提供するため。
- ユーザーのアイデンティティ、関係性、設定を一元管理することで、システム全体の一貫性を確保する。
- マイクロサービスアーキテクチャにおいて、ユーザー関連の機能を独立させることで、変更容易性とスケーラビリティを確保する。
- [PRD: avion-user](./prd.md)
- [Avion アーキテクチャ概要](../common/architecture.md)

## 5. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

- ユーザープロフィールの作成、取得、更新、削除を行うgRPC APIの実装。
- ユーザーデータのPostgreSQLへの永続化。
- フォロー関係の管理API (gRPC) の実装。
- ミュート/ブロック機能のAPI (gRPC) の実装。
- ユーザー設定の管理API (gRPC) の実装。
- ユーザーリスト機能のAPI (gRPC) の実装。
- ユーザー統計情報のキャッシュ管理 (Redis)。
- ユーザー作成、プロフィール更新、フォロー/アンフォロー、ブロック/ミュート時にイベントを発行 (Redis Pub/Sub) し、他のサービスと連携する。
- プライバシー設定に基づいたアクセス制御チェック。
- Go言語で実装し、Kubernetes上でのステートレス運用を前提とする。
- OpenTelemetryによるトレーシング・メトリクス・ロギング対応。

### Non-Goals (やらないこと)
- **認証・認可処理:** `avion-auth` が担当。
- **投稿管理:** `avion-drop` が担当。
- **タイムライン生成:** `avion-timeline` が担当。
- **通知生成・配信:** `avion-notification` が担当。
- **メディアファイルの保存・配信:** `avion-media` が担当。
- **全文検索インデックス作成:** `avion-search` が担当 (本サービスはイベント発行のみ)。
- **DM（ダイレクトメッセージ）機能。**
- **支払い・サブスクリプション管理。**

## 6. Configuration Management

このサービスは、[共通環境変数管理パターン](../common/infrastructure/environment-variables.md)に従った統一的な設定管理を実装します。

### 6.1. 環境変数仕様

#### 必須環境変数
- `DATABASE_URL` (required): PostgreSQL接続URL
- `REDIS_URL` (required): Redis接続URL

#### オプション環境変数（デフォルト値付き）
- `PORT` (default: 8082): HTTPサーバーポート
- `GRPC_PORT` (default: 9092): gRPCサーバーポート
- `MAX_PROFILE_SIZE` (default: 1MB): プロフィール画像等の最大サイズ
- `FOLLOW_RATE_LIMIT` (default: 100/hour): フォロー操作のレート制限

### 6.2. Config構造体実装例

```go
// internal/infrastructure/config/config.go
package config

import (
    "time"
)

// Config はavion-userサービスの設定を保持する構造体
type Config struct {
    // サーバー設定
    Server ServerConfig
    
    // データベース設定
    Database DatabaseConfig
    
    // Redis設定
    Redis RedisConfig
    
    // ユーザー機能設定
    User UserConfig
    
    // 監視設定
    Observability ObservabilityConfig
}

// ServerConfig サーバー関連の設定
type ServerConfig struct {
    Port        int           `env:"PORT" required:"true" default:"8082"`
    GRPCPort    int           `env:"GRPC_PORT" required:"true" default:"9092"`
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

// UserConfig ユーザー機能関連の設定
type UserConfig struct {
    MaxProfileSize    int64         `env:"MAX_PROFILE_SIZE" required:"false" default:"1048576"` // 1MB
    FollowRateLimit   int           `env:"FOLLOW_RATE_LIMIT" required:"false" default:"100"`
    RateLimitWindow   time.Duration `env:"FOLLOW_RATE_WINDOW" required:"false" default:"1h"`
    MaxBioLength      int           `env:"MAX_BIO_LENGTH" required:"false" default:"500"`
    MaxDisplayName    int           `env:"MAX_DISPLAY_NAME" required:"false" default:"50"`
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
    
    logger.Info("Starting avion-user server",
        "environment", cfg.Server.Environment,
        "port", cfg.Server.Port,
        "grpc_port", cfg.Server.GRPCPort,
        "max_profile_size", cfg.User.MaxProfileSize,
    )
    
    // 依存関係の初期化
    db := initDatabase(cfg.Database.URL)
    redis := initRedis(cfg.Redis.URL)
    
    // サーバーの起動
    // ...
}
```

### 6.4. セキュリティ考慮事項

- データベースURLやRedis URLに認証情報が含まれる場合は適切に保護されます
- プロフィールサイズ制限やレート制限により、サービスの濫用を防止します
- 本番環境では環境変数を暗号化して管理することを推奨します

## 7. Architecture (どうやって作る？)

### 7.1. レイヤードアーキテクチャ (DDD準拠)

本サービスは、Domain-Driven Design (DDD) の戦術的パターンを適用した4層アーキテクチャを採用します：

1. **Domain Layer (ドメイン層)**: ビジネスルールとエンティティを管理
2. **Use Case Layer (ユースケース層)**: アプリケーション固有のビジネスロジックを管理
3. **Infrastructure Layer (インフラストラクチャ層)**: データベースや外部システムとの連携を管理
4. **Handler Layer (ハンドラー層)**: プロトコル固有のリクエスト・レスポンス処理を管理

各層は明確な責務を持ち、依存関係の方向は上位層から下位層への単方向に限定されます。これにより、ビジネスロジックの独立性と変更容易性を確保します。

#### Domain Layer (ドメイン層)
- **Aggregates:**
  - User: ユーザーアカウントのライフサイクルと基本情報を管理
  - Follow: フォロー関係を管理
  - Block: ブロック関係を管理
  - Mute: ミュート設定を管理
  - UserSettings: ユーザー設定を管理
  - UserList: ユーザーリストを管理
  - UserStats: ユーザー統計情報を管理
- **Entities:**
  - User: ユーザーの主体
  - ProfileField: カスタムプロフィール項目
  - FollowRequest: フォローリクエスト
  - MuteKeyword: ミュートキーワード
  - ListMember: リストメンバー
- **Value Objects:**
  - UserID, Username, Email, DisplayName, Bio
  - AvatarURL, HeaderURL, Location, Website, Birthday
  - AccountStatus, PrivacyLevel, Language, Timezone, Theme
  - FollowStatus, MuteType, NotificationPreference
  - FollowerCount, FollowingCount, DropCount
  ※各値オブジェクトは自己完結した検証ロジックを内包
- **Domain Services:**
  - UsernameValidationService: ユーザー名の一意性検証
  - ProfileValidationService: プロフィール内容の検証
  - ReputationCalculationService: 信頼度スコア計算
  - FollowDomainService: フォロー関係のビジネスルール（事前条件/事後条件付き）
  - BlockDomainService: ブロック機能のビジネスルール（事前条件/事後条件付き）
  - MuteDomainService: ミュート機能のビジネスルール（事前条件/事後条件付き）
  - PrivacyDomainService: プライバシー制御のビジネスルール
  - EngagementAnalysisService: エンゲージメント分析
  - SocialGraphAnalysisService: ソーシャルグラフ分析
  - ProfileVerificationService: プロフィール検証
  ※各サービスは単一責任原則に従い、明示的な事前条件/事後条件を持つ
- **Domain Events:**
  - UserCreatedEvent: ユーザーが作成された
  - UserUpdatedEvent: ユーザー情報が更新された
  - UserFollowedEvent: ユーザーがフォローされた
  - UserUnfollowedEvent: ユーザーがアンフォローされた
  - UserBlockedEvent: ユーザーがブロックされた
  - UserMutedEvent: ユーザーがミュートされた
  - UserReputationUpdatedEvent: 信頼度スコア更新
  - UserVerifiedEvent: ユーザー検証完了
  - InfluencerStatusGrantedEvent: インフルエンサー認定
  - UserEngagementUpdatedEvent: エンゲージメント更新
  - UserSegmentChangedEvent: ユーザーセグメント変更
  - PrivacySettingsUpdatedEvent: プライバシー設定更新
  - DeviceTrustLevelChangedEvent: デバイス信頼度変更
  - GeolocationChangedEvent: 位置情報変更
- **Repository Interfaces:**
  - UserRepository: User集約の永続化インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_user_repository.go -package=mocks
    ```
  - FollowRepository: Follow集約の永続化インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_follow_repository.go -package=mocks
    ```
  - BlockRepository: Block集約の永続化インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_block_repository.go -package=mocks
    ```
  - MuteRepository: Mute集約の永続化インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_mute_repository.go -package=mocks
    ```
  - UserSettingsRepository: UserSettings集約の永続化インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_user_settings_repository.go -package=mocks
    ```
  - UserListRepository: UserList集約の永続化インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_user_list_repository.go -package=mocks
    ```
  - UserStatsRepository: UserStats集約の永続化インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_user_stats_repository.go -package=mocks
    ```

#### Use Case Layer (ユースケース層)
- **Command Use Cases (更新系):**
  - CreateUserCommandUseCase: ユーザー作成処理（POSTリクエスト用）
  - UpdateProfileCommandUseCase: プロフィール更新処理（PATCHリクエスト用）
  - DeleteUserCommandUseCase: ユーザー削除処理（DELETEリクエスト用）
  - FollowUserCommandUseCase: フォロー処理（POSTリクエスト用）
  - UnfollowUserCommandUseCase: アンフォロー処理（DELETEリクエスト用）
  - ApproveFollowRequestCommandUseCase: フォローリクエスト承認（POSTリクエスト用）
  - RejectFollowRequestCommandUseCase: フォローリクエスト拒否（POSTリクエスト用）
  - BlockUserCommandUseCase: ブロック処理（POSTリクエスト用）
  - UnblockUserCommandUseCase: ブロック解除処理（DELETEリクエスト用）
  - MuteUserCommandUseCase: ミュート処理（POSTリクエスト用）
  - UnmuteUserCommandUseCase: ミュート解除処理（DELETEリクエスト用）
  - CreateMuteKeywordCommandUseCase: ミュートキーワード作成（POSTリクエスト用）
  - DeleteMuteKeywordCommandUseCase: ミュートキーワード削除（DELETEリクエスト用）
  - UpdateSettingsCommandUseCase: 設定更新処理（PATCHリクエスト用）
  - CreateUserListCommandUseCase: リスト作成処理（POSTリクエスト用）
  - UpdateUserListCommandUseCase: リスト更新処理（PATCHリクエスト用）
  - DeleteUserListCommandUseCase: リスト削除処理（DELETEリクエスト用）
  - AddListMemberCommandUseCase: リストメンバー追加（POSTリクエスト用）
  - RemoveListMemberCommandUseCase: リストメンバー削除（DELETEリクエスト用）
  - SuspendUserCommandUseCase: ユーザー凍結処理（POSTリクエスト用）
  - UnsuspendUserCommandUseCase: 凍結解除処理（POSTリクエスト用）
  - DeactivateUserCommandUseCase: アカウント無効化（POSTリクエスト用）
  - ReactivateUserCommandUseCase: アカウント再有効化（POSTリクエスト用）
  - ExportDataCommandUseCase: データエクスポート処理（POSTリクエスト用）
  - ImportDataCommandUseCase: データインポート処理（POSTリクエスト用）
  - UpdateReputationScoreCommandUseCase: 信頼度スコア更新
  - RequestVerificationCommandUseCase: プロフィール検証要求
  - ApproveVerificationCommandUseCase: プロフィール検証承認
  - GrantInfluencerStatusCommandUseCase: インフルエンサー認定
  - UpdatePrivacySettingsCommandUseCase: 詳細プライバシー設定更新
  - UpdateDataSharingConsentCommandUseCase: データ共有同意更新
  - RecordDeviceInfoCommandUseCase: デバイス情報記録
  - UpdateLocationHistoryCommandUseCase: 位置情報履歴更新
- **Query Use Cases (参照系):**
  - GetUserQueryUseCase: ユーザー取得処理（GETリクエスト用）
  - GetUsersByIDsQueryUseCase: 複数ユーザー一括取得（GETリクエスト用）
  - SearchUsersQueryUseCase: ユーザー検索処理（GETリクエスト用）
  - GetFollowersQueryUseCase: フォロワー一覧取得（GETリクエスト用）
  - GetFollowingQueryUseCase: フォロー中一覧取得（GETリクエスト用）
  - GetFollowRequestsQueryUseCase: フォローリクエスト一覧取得（GETリクエスト用）
  - GetBlockedUsersQueryUseCase: ブロックユーザー一覧取得（GETリクエスト用）
  - GetMutedUsersQueryUseCase: ミュートユーザー一覧取得（GETリクエスト用）
  - GetMuteKeywordsQueryUseCase: ミュートキーワード一覧取得（GETリクエスト用）
  - GetUserSettingsQueryUseCase: ユーザー設定取得（GETリクエスト用）
  - GetUserListsQueryUseCase: ユーザーリスト一覧取得（GETリクエスト用）
  - GetUserListQueryUseCase: ユーザーリスト詳細取得（GETリクエスト用）
  - GetListMembersQueryUseCase: リストメンバー一覧取得（GETリクエスト用）
  - GetUserStatsQueryUseCase: ユーザー統計取得（GETリクエスト用）
  - CheckFollowStatusQueryUseCase: フォロー状態確認（GETリクエスト用）
  - GetRecommendedUsersQueryUseCase: おすすめユーザー取得（GETリクエスト用）
  - GetUserReputationQueryUseCase: ユーザー信頼度取得
  - GetVerificationStatusQueryUseCase: 検証ステータス取得
  - GetUserEngagementQueryUseCase: エンゲージメント指標取得
  - GetSocialGraphQueryUseCase: ソーシャルグラフ取得
  - GetInfluenceScoreQueryUseCase: 影響力スコア取得
  - GetUserSegmentQueryUseCase: ユーザーセグメント取得（新規违加）
  - GetPrivacySettingsQueryUseCase: 詳細プライバシー設定取得
  - GetDeviceInfoQueryUseCase: デバイス情報取得
  - GetLocationHistoryQueryUseCase: 位置情報履歴取得
- **Query Service Interfaces:**
  - UserQueryService: ユーザー参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_user_query_service.go -package=mocks
    ```
  - FollowQueryService: フォロー関係参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_follow_query_service.go -package=mocks
    ```
  - BlockQueryService: ブロック関係参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_block_query_service.go -package=mocks
    ```
  - MuteQueryService: ミュート設定参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_mute_query_service.go -package=mocks
    ```
  - UserListQueryService: ユーザーリスト参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_user_list_query_service.go -package=mocks
    ```
- **External Service Interfaces:**
  - IAMServiceClient: avion-authとの連携インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_iam_service_client.go -package=mocks
    ```
  - MediaServiceClient: avion-mediaとの連携インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_media_service_client.go -package=mocks
    ```
  - SearchServiceClient: avion-searchとの連携インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_search_service_client.go -package=mocks
    ```
  - EventPublisher: イベント発行インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_event_publisher.go -package=mocks
    ```
  - CacheService: キャッシュ管理インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_cache_service.go -package=mocks
    ```

#### Infrastructure Layer (インフラストラクチャ層)
- **Repository実装:**
  - PostgresUserRepository: PostgreSQLを使用したUser永続化
  - PostgresFollowRepository: PostgreSQLを使用したFollow永続化
  - PostgresBlockRepository: PostgreSQLを使用したBlock永続化
  - PostgresMuteRepository: PostgreSQLを使用したMute永続化
  - PostgresUserSettingsRepository: PostgreSQLを使用したUserSettings永続化
  - PostgresUserListRepository: PostgreSQLを使用したUserList永続化
  - PostgresUserStatsRepository: PostgreSQLを使用したUserStats永続化
- **Cache実装:**
  - RedisUserCache: Redisを使用したユーザー情報キャッシュ
  - RedisFollowCache: Redisを使用したフォロー関係キャッシュ
  - RedisStatsCache: Redisを使用した統計情報キャッシュ
  - RedisSearchCache: Redisを使用した検索結果キャッシュ
- **Event実装:**
  - RedisEventPublisher: Redis Pub/Subを使用したイベント発行
  - UserEventHandler: ユーザー関連イベントのハンドラー
  - FollowEventHandler: フォロー関連イベントのハンドラー
- **External Service実装:**
  - GRPCIAMClient: gRPCを使用したavion-auth連携
  - GRPCMediaClient: gRPCを使用したavion-media連携
  - GRPCSearchClient: gRPCを使用したavion-search連携

#### Handler Layer (ハンドラー層)
- **gRPC Handlers:**
  - UserServiceHandler: ユーザー管理エンドポイント
  - FollowServiceHandler: フォロー管理エンドポイント
  - BlockServiceHandler: ブロック管理エンドポイント
  - MuteServiceHandler: ミュート管理エンドポイント
  - SettingsServiceHandler: 設定管理エンドポイント
  - UserListServiceHandler: リスト管理エンドポイント
  - StatsServiceHandler: 統計情報エンドポイント

### 7.2. 詳細ドメインモデル（DDD戦術パターン）

本セクションでは、PRDで定義された要件を基に、DDDの戦術的パターンを適用した詳細なドメインモデルを示します。各集約とエンティティには厳密な不変条件とドメインロジックが定義されています。

#### User Aggregate (ユーザー集約)

**責務**: ユーザーアカウントのライフサイクル全体と基本情報を管理する中核集約
- **集約ルート**: User
- **不変条件**:
  - UserIDは変更不可（Snowflake ID）
  - Usernameは一意（大文字小文字を区別しない、3-30文字、英数字とアンダースコアのみ）
  - Emailは一意（アクティブユーザー内で、RFC 5322準拠）
  - DisplayNameは最大30文字（絵文字対応、Unicode正規化必須）
  - Bioは最大500文字（改行対応、URL の自動検出）
  - ProfileFieldは最大4つまで（各項目名20文字、値200文字）
  - 削除されたユーザーは復元不可（論理削除、30日後物理削除）
  - 凍結されたユーザーはログイン・API利用不可
  - プライバシーレベル変更時の一貫性保証
  - アカウント状態の有効な遷移のみ許可

- **ドメインロジック**:
  - `canBeViewedBy(viewerID, requestContext)`: プロフィール閲覧権限の判定（プライバシー設定、ブロック関係、フォロー状態を考慮）
  - `canFollowUser(targetID, followRequest)`: フォロー可能かの判定（自己フォロー防止、ブロック確認、アカウント状態確認）
  - `canSendDMTo(targetID, senderSettings)`: DM送信可能かの判定（プライバシー設定、相互フォロー、ブロック状態を考慮）
  - `updateProfile(profileData, validator)`: プロフィール更新（全フィールドバリデーション、変更差分検出、イベント生成）
  - `validateUsername(username)`: ユーザー名妥当性検証（形式チェック、禁止ワード確認、利用可能性確認）
  - `suspend(reason, suspendedBy, duration)`: アカウント凍結処理（理由記録、期限設定、関連処理トリガー）
  - `unsuspend(unsuspendedBy, reason)`: 凍結解除処理（履歴記録、権限復元）
  - `deactivate(reason)`: アカウント無効化（設定保持、可逆的処理）
  - `reactivate()`: アカウント再有効化（設定復元、フォロー関係復元）
  - `markAsDeleted(deletionReason)`: 論理削除処理（30日間の猶予期間、関連データのクリーンアップスケジュール）
  - `permanentDelete()`: 物理削除処理（GDPR対応、完全なデータ消去）
  - `calculateProfileCompleteness()`: プロフィール完成度計算（推薦システム向け）
  - `toActivityPubActor()`: ActivityPub Actor形式への変換（公開鍵、エンドポイント含む）
  - `mergeProfileFields(newFields)`: プロフィールフィールドのマージ処理（順序保持、検証付き）

#### Follow Aggregate (フォロー集約)

**責務**: フォロー関係とリクエストを管理
- **集約ルート**: Follow
- **不変条件**:
  - FollowerIDとFolloweeIDの組み合わせは一意
  - 自分自身をフォローすることはできない
  - ブロックされているユーザーをフォローできない（相互ブロック確認）
  - 削除されたユーザーとのフォロー関係は自動無効化
  - フォローリクエストの重複は許可しない
  - 承認済みフォローの再リクエストは不可
  - フォロー数の上限制御（スパム防止、デフォルト7500人）
  - 承認制アカウントのフォローには必ずリクエストが必要

- **ドメインロジック**:
  - `isApproved()`: 承認済みかの判定（承認制アカウント対応）
  - `approve(approvedBy, approvalTime)`: フォローリクエストの承認（承認者記録、タイムスタンプ）
  - `reject(rejectedBy, reason)`: フォローリクエストの拒否（拒否理由記録）
  - `isMutual(reverseFollow)`: 相互フォローかの判定（双方向関係確認）
  - `canBeApprovedAutomatically(targetSettings)`: 自動承認可否判定（設定ベース）
  - `calculateFollowStrength()`: フォロー関係の強度計算（相互作用履歴ベース）
  - `shouldNotifyFollowee()`: フォロー通知の必要性判定（設定と関係性考慮）
  - `isWithinFollowLimit(currentCount, limit)`: フォロー上限チェック
  - `generateFollowRequest(message, requestTime)`: フォローリクエスト生成
  - `expireRequest(expirationReason)`: リクエスト期限切れ処理
  - `toActivityPubFollow()`: ActivityPub Follow アクティビティへの変換
  - `validateFollowContext(context)`: フォロー文脈の妥当性検証（スパム検出）

#### Block Aggregate (ブロック集約)

**責務**: ブロック関係と関連処理を管理
- **集約ルート**: Block
- **不変条件**:
  - BlockerIDとBlockedIDの組み合わせは一意
  - 自分自身をブロックすることはできない
  - ブロック時は双方向のフォロー関係を自動解除
  - ブロック時はリストメンバーからの相互除外
  - ブロック数の上限制御（濫用防止、デフォルト10000人）
  - ブロック解除後の再フォローには制限期間を設定
  - インスタンスブロックは個別ユーザーブロックより優先

- **ドメインロジック**:
  - `shouldUnfollow(existingFollows)`: フォロー解除が必要かの判定（双方向確認）
  - `cleanupRelatedData()`: 関連データのクリーンアップ処理（リスト除外、通知削除等）
  - `affectsVisibility(contentType)`: 表示に影響するかの判定（投稿、リアクション等）
  - `shouldCascadeToLists()`: リストからの除外が必要かの判定
  - `calculateBlockEffectiveness()`: ブロック効果の範囲計算
  - `validateUnblockConditions()`: ブロック解除条件の検証
  - `generateBlockEvent(reason, context)`: ブロックイベント生成
  - `shouldNotifyModerators(blockReason)`: モデレーター通知の必要性判定
  - `toActivityPubBlock()`: ActivityPub Block アクティビティへの変換（プライベート）
  - `createBlockHistory(reason, duration)`: ブロック履歴の作成

#### Mute Aggregate (ミュート集約)

**責務**: ミュート設定と効果を管理
- **集約ルート**: Mute
- **不変条件**:
  - MuterIDとMutedIDの組み合わせは一意（ユーザーミュート）
  - キーワードミュートは最大100個まで（スパム対策）
  - 期限付きミュートの期限は未来の日時（最大1年先）
  - キーワード長は最大100文字まで
  - 正規表現パターンの妥当性検証必須
  - ミュート総数の上限制御（ユーザー1000個、キーワード100個）
  - 自分自身のミュートは不可
  - 空文字列やホワイトスペースのみのキーワードは無効

- **ドメインロジック**:
  - `isActive(currentTime)`: 現在有効かの判定（期限チェック、アカウント状態確認）
  - `shouldHideDrop(drop, context)`: 投稿を非表示にすべきかの判定（内容、添付メディア、リポスト考慮）
  - `shouldHideNotification(notification)`: 通知を非表示にすべきかの判定
  - `expire(expirationTime)`: ミュートの期限切れ処理（自動解除、履歴記録）
  - `extend(newExpirationTime)`: ミュート期間の延長
  - `matches(text, options)`: キーワードマッチング（正規表現、大文字小文字、単語境界対応）
  - `validateKeywordPattern(pattern)`: 正規表現パターンの妥当性検証
  - `calculateMatchScore(text)`: マッチング精度の計算
  - `shouldMuteRepost(originalDrop, reposter)`: リポストミュートの判定
  - `shouldMuteThread(threadId)`: スレッドミュートの判定
  - `optimizeKeywordList()`: キーワードリストの最適化（重複除去、パフォーマンス向上）
  - `generateMuteStatistics()`: ミュート効果の統計生成

#### UserSettings Aggregate (ユーザー設定集約)

**責務**: ユーザー設定の一元管理
- **集約ルート**: UserSettings
- **不変条件**:
  - UserIDごとに1つの設定セット
  - 言語コードはISO 639-1準拠（ja, en, fr等）
  - タイムゾーンはIANA Time Zone Database準拠（Asia/Tokyo等）
  - テーマ設定は列挙値のみ（light, dark, auto, system）
  - 通知設定の各項目はboolean値または列挙値
  - プライバシー設定の階層構造整合性保証
  - アクセシビリティ設定の相互排他性制御
  - 設定変更履歴の保持（監査ログ用）

- **ドメインロジック**:
  - `updatePrivacySettings(newSettings, validator)`: プライバシー設定の更新（整合性チェック、影響範囲計算）
  - `updateNotificationSettings(newSettings)`: 通知設定の更新（デバイス別設定対応）
  - `updateUISettings(newSettings)`: UI設定の更新（テーマ、レイアウト、言語）
  - `updateAccessibilitySettings(newSettings)`: アクセシビリティ設定の更新（互換性チェック）
  - `shouldRequireFollowApproval(followerContext)`: フォロー承認が必要かの判定（文脈考慮）
  - `canReceiveDMFrom(senderID, relationship)`: DM受信可能かの判定（関係性、設定統合判断）
  - `canReceiveNotification(notificationType, context)`: 通知受信可否判定
  - `getEffectiveSettings(settingCategory)`: デフォルト値とのマージ済み設定を取得
  - `validateSettingChange(oldValue, newValue, settingType)`: 設定変更の妥当性検証
  - `calculatePrivacyScore()`: プライバシー保護度の計算
  - `exportSettings(format)`: 設定のエクスポート（移行・バックアップ用）
  - `importSettings(settingsData, mergeStrategy)`: 設定のインポート（競合解決付き）
  - `resetToDefaults(category)`: デフォルト設定への リセット
  - `auditSettingChange(change, timestamp, reason)`: 設定変更の監査ログ記録

#### UserList Aggregate (ユーザーリスト集約)

**責務**: ユーザーリストとメンバーシップを管理
- **集約ルート**: UserList
- **不変条件**:
  - ListIDは一意（Snowflake ID）
  - OwnerIDは変更不可
  - リストメンバーは最大5000人まで（パフォーマンス考慮）
  - ユーザーごとのリスト作成上限50個
  - リスト名は所有者内で一意（大文字小文字区別なし）
  - 非公開リストは所有者のみアクセス可能
  - 削除されたユーザーは自動除外
  - ブロック関係のユーザーは相互除外
  - リスト名は最大100文字、説明は最大200文字
  - 空のリスト名や禁止ワードの使用は不可

- **ドメインロジック**:
  - `canBeViewedBy(viewerID, context)`: 閲覧権限の判定（公開設定、所有権、フォロー関係考慮）
  - `canAddMember(targetUserID, adderID)`: メンバー追加権限の判定（所有者確認、ブロック確認）
  - `canRemoveMember(targetUserID, removerID)`: メンバー削除権限の判定
  - `addMember(userID, addedBy, context)`: メンバー追加（重複チェック、上限チェック、通知生成）
  - `removeMember(userID, removedBy, reason)`: メンバー削除（履歴記録、カウント更新）
  - `isMember(userID)`: メンバーかどうかの判定
  - `updateListMetadata(name, description, isPublic)`: リストメタデータ更新（名前重複チェック）
  - `validateMemberAddition(targetUser)`: メンバー追加の妥当性検証
  - `calculateListEngagement()`: リストエンゲージメント計算
  - `shouldNotifyMembers(changeType)`: メンバー通知の必要性判定
  - `optimizeMemberOrder()`: メンバー順序の最適化
  - `exportMemberList(format)`: メンバーリストのエクスポート
  - `bulkAddMembers(userIDs, addedBy)`: 複数メンバーの一括追加
  - `cleanupInactiveMembers()`: 非アクティブメンバーのクリーンアップ

#### UserStats Aggregate (ユーザー統計集約)

**責務**: ユーザー統計情報の精密管理
- **集約ルート**: UserStats
- **不変条件**:
  - すべてのカウントは非負の整数
  - 同時更新時の整合性を保証（楽観的ロック、バージョン管理）
  - カウントの急激な変動検知（スパム・ボット対策）
  - 統計値と実際のデータの定期的な整合性チェック
  - カウント更新の順序性保証（タイムスタンプベース）
  - 異常値の検出と自動修正機能
  - 統計データの履歴保持（分析用）

- **ドメインロジック**:
  - `incrementDropCount(delta, timestamp)`: 投稿数増加（バッチ処理対応）
  - `decrementDropCount(delta, timestamp)`: 投稿数減少（下限チェック付き）
  - `updateFollowerCount(newCount, source)`: フォロワー数更新（ソース記録）
  - `updateFollowingCount(newCount, source)`: フォロー中数更新（ソース記録）
  - `incrementReactionCount(reactionType)`: リアクション受信数増加
  - `updateListedCount(delta)`: リスト登録数更新
  - `recalculate(calculationType)`: 統計の再計算（全体または部分）
  - `validateCountAccuracy()`: カウント精度の検証
  - `detectAnomalies()`: 異常値の検出（急激な変化、不自然なパターン）
  - `generateStatisticsSnapshot()`: 統計スナップショットの生成
  - `compareWithPreviousPeriod()`: 前期間との比較分析
  - `calculateEngagementRate()`: エンゲージメント率の計算
  - `predictFutureStats(period)`: 将来統計の予測
  - `exportStatistics(format, period)`: 統計データのエクスポート
  - `rollbackStatistics(timestamp)`: 統計値の巻き戻し

### 7.3. データモデル

#### PostgreSQL テーブル構造

##### users テーブル
```sql
CREATE TABLE users (
    user_id BIGINT PRIMARY KEY,  -- Snowflake ID
    username VARCHAR(30) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE,
    display_name VARCHAR(30),
    bio TEXT,
    avatar_url VARCHAR(500),
    header_url VARCHAR(500),
    location VARCHAR(30),
    website VARCHAR(255),
    birthday DATE,
    account_status VARCHAR(20) NOT NULL DEFAULT 'active',
    privacy_level VARCHAR(20) NOT NULL DEFAULT 'public',
    is_bot BOOLEAN DEFAULT FALSE,
    bot_owner_id BIGINT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    last_active_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    version INTEGER NOT NULL DEFAULT 1,
    
    INDEX idx_username (username),
    INDEX idx_email (email),
    INDEX idx_account_status (account_status),
    INDEX idx_created_at (created_at),
    INDEX idx_deleted_at (deleted_at)
);
```

##### profile_fields テーブル
```sql
CREATE TABLE profile_fields (
    field_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    name VARCHAR(20) NOT NULL,
    value VARCHAR(200) NOT NULL,
    verified BOOLEAN DEFAULT FALSE,
    verified_at TIMESTAMP WITH TIME ZONE,
    display_order INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    
    UNIQUE(user_id, display_order),
    INDEX idx_user_id (user_id)
);
```

##### follows テーブル
```sql
CREATE TABLE follows (
    follow_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    followee_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    is_approved BOOLEAN DEFAULT TRUE,
    requested_at TIMESTAMP WITH TIME ZONE,
    approved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    
    UNIQUE(follower_id, followee_id),
    INDEX idx_follower_id (follower_id),
    INDEX idx_followee_id (followee_id),
    INDEX idx_is_approved (is_approved),
    INDEX idx_created_at (created_at)
);
```

##### follow_requests テーブル
```sql
CREATE TABLE follow_requests (
    request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    target_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    message TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    requested_at TIMESTAMP WITH TIME ZONE NOT NULL,
    processed_at TIMESTAMP WITH TIME ZONE,
    
    UNIQUE(requester_id, target_id),
    INDEX idx_target_id_status (target_id, status),
    INDEX idx_requested_at (requested_at)
);
```

##### blocks テーブル
```sql
CREATE TABLE blocks (
    block_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    blocked_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    
    UNIQUE(blocker_id, blocked_id),
    INDEX idx_blocker_id (blocker_id),
    INDEX idx_blocked_id (blocked_id)
);
```

##### mutes テーブル
```sql
CREATE TABLE mutes (
    mute_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    muter_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    muted_id BIGINT REFERENCES users(user_id) ON DELETE CASCADE,
    mute_type VARCHAR(20) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    
    UNIQUE(muter_id, muted_id),
    INDEX idx_muter_id (muter_id),
    INDEX idx_mute_type (mute_type),
    INDEX idx_expires_at (expires_at)
);
```

##### mute_keywords テーブル
```sql
CREATE TABLE mute_keywords (
    keyword_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    keyword VARCHAR(100) NOT NULL,
    is_regex BOOLEAN DEFAULT FALSE,
    case_sensitive BOOLEAN DEFAULT FALSE,
    whole_word BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    
    INDEX idx_user_id (user_id)
);
```

##### user_settings テーブル
```sql
CREATE TABLE user_settings (
    user_id BIGINT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    language VARCHAR(5) DEFAULT 'ja',
    timezone VARCHAR(50) DEFAULT 'Asia/Tokyo',
    theme VARCHAR(20) DEFAULT 'auto',
    privacy_settings JSONB NOT NULL DEFAULT '{}',
    notification_settings JSONB NOT NULL DEFAULT '{}',
    ui_settings JSONB NOT NULL DEFAULT '{}',
    accessibility_settings JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    version INTEGER NOT NULL DEFAULT 1
);
```

##### user_lists テーブル
```sql
CREATE TABLE user_lists (
    list_id BIGINT PRIMARY KEY,  -- Snowflake ID
    owner_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_public BOOLEAN DEFAULT TRUE,
    member_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    
    UNIQUE(owner_id, name),
    INDEX idx_owner_id (owner_id),
    INDEX idx_is_public (is_public)
);
```

##### list_members テーブル
```sql
CREATE TABLE list_members (
    member_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    list_id BIGINT NOT NULL REFERENCES user_lists(list_id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    added_by BIGINT NOT NULL REFERENCES users(user_id),
    added_at TIMESTAMP WITH TIME ZONE NOT NULL,
    
    UNIQUE(list_id, user_id),
    INDEX idx_list_id (list_id),
    INDEX idx_user_id (user_id)
);
```

##### user_stats テーブル
```sql
CREATE TABLE user_stats (
    user_id BIGINT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    follower_count INTEGER NOT NULL DEFAULT 0,
    following_count INTEGER NOT NULL DEFAULT 0,
    drop_count INTEGER NOT NULL DEFAULT 0,
    listed_count INTEGER NOT NULL DEFAULT 0,
    reaction_received_count INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    version INTEGER NOT NULL DEFAULT 1
);
```

#### Redis キャッシュ構造

##### ユーザー情報キャッシュ
```
KEY: user:{user_id}
TYPE: Hash
FIELDS:
  - username
  - display_name
  - bio
  - avatar_url
  - header_url
  - account_status
  - privacy_level
  - is_bot
TTL: 5分
```

##### フォロー関係キャッシュ
```
KEY: follow:{follower_id}:{followee_id}
TYPE: String (boolean)
VALUE: "true" | "false"
TTL: 1分
```

##### フォロワーリストキャッシュ
```
KEY: followers:{user_id}:{page}
TYPE: List
VALUE: JSON array of user IDs
TTL: 30秒
```

##### フォロー中リストキャッシュ
```
KEY: following:{user_id}:{page}
TYPE: List
VALUE: JSON array of user IDs
TTL: 30秒
```

##### ユーザー統計キャッシュ
```
KEY: stats:{user_id}
TYPE: Hash
FIELDS:
  - follower_count
  - following_count
  - drop_count
  - listed_count
TTL: 1分
```

##### ブロックリストキャッシュ
```
KEY: blocks:{blocker_id}
TYPE: Set
VALUE: blocked user IDs
TTL: 5分
```

##### ミュートリストキャッシュ
```
KEY: mutes:{muter_id}
TYPE: Set
VALUE: muted user IDs
TTL: 5分
```

### 7.4. イベント駆動アーキテクチャ

#### 発行イベント

##### user_created
```json
{
  "event_id": "evt_xxx",
  "event_type": "user_created",
  "user_id": "123456789",
  "username": "alice",
  "email": "alice@example.com",
  "is_bot": false,
  "created_at": "2024-01-01T00:00:00Z"
}
```

##### profile_updated
```json
{
  "event_id": "evt_xxx",
  "event_type": "profile_updated",
  "user_id": "123456789",
  "changes": {
    "display_name": "Alice",
    "bio": "Updated bio",
    "avatar_url": "https://..."
  },
  "updated_at": "2024-01-01T00:00:00Z"
}
```

##### follow_created
```json
{
  "event_id": "evt_xxx",
  "event_type": "follow_created",
  "follower_id": "123456789",
  "followee_id": "987654321",
  "is_approved": true,
  "created_at": "2024-01-01T00:00:00Z"
}
```

##### follow_deleted
```json
{
  "event_id": "evt_xxx",
  "event_type": "follow_deleted",
  "follower_id": "123456789",
  "followee_id": "987654321",
  "deleted_at": "2024-01-01T00:00:00Z"
}
```

##### block_created
```json
{
  "event_id": "evt_xxx",
  "event_type": "block_created",
  "blocker_id": "123456789",
  "blocked_id": "987654321",
  "created_at": "2024-01-01T00:00:00Z"
}
```

##### mute_created
```json
{
  "event_id": "evt_xxx",
  "event_type": "mute_created",
  "muter_id": "123456789",
  "muted_id": "987654321",
  "mute_type": "user",
  "expires_at": "2024-01-02T00:00:00Z",
  "created_at": "2024-01-01T00:00:00Z"
}
```

##### user_suspended
```json
{
  "event_id": "evt_xxx",
  "event_type": "user_suspended",
  "user_id": "123456789",
  "reason": "violation",
  "suspended_by": "admin_123",
  "suspended_at": "2024-01-01T00:00:00Z"
}
```

#### 購読イベント

##### iam_user_registered
avion-authから受信するユーザー登録イベント。新規ユーザーのプロフィール作成をトリガーする。

##### drop_count_updated
avion-dropから受信する投稿数更新イベント。ユーザー統計の更新をトリガーする。

## データベースマイグレーション

このサービスでは、[共通マイグレーション戦略](../common/database-migration-strategy.md)に従って、Gooseを使用したマイグレーション管理を行います。

### マイグレーション戦略

- **ツール**: Goose v3
- **ディレクトリ**: `./migrations/`
- **命名規則**: `[sequence_number]_[description].sql`
- **実行方法**: `make migrate-up` / `make migrate-down`

### avion-user固有の考慮事項

- **プロフィールデータ保護**: ユーザーの個人情報を含むプロフィールデータの移行では、プライバシー設定を維持
- **フォロー関係整合性**: フォロー・ブロック関係のデータ移行時は、関係性の一貫性を保証
- **統計データ再計算**: スキーマ変更により統計値の再計算が必要な場合は、バッチ処理で対応
- **大規模データ移行**: ユーザー数増加に対応するため、段階的な移行戦略を採用
- **イベント整合性**: 他サービスとのイベント連携データの整合性を維持

### 標準テンプレート参照

マイグレーションファイル作成時は[マイグレーション設定テンプレート](../templates/migration-setup-template.md)を参照してください。

### 7.5. API設計

#### gRPC API定義 (proto3)

```protobuf
syntax = "proto3";

package avion.user.v1;

import "google/protobuf/timestamp.proto";
import "google/protobuf/empty.proto";

service UserService {
  // User management
  rpc CreateUser(CreateUserRequest) returns (CreateUserResponse);
  rpc GetUser(GetUserRequest) returns (GetUserResponse);
  rpc GetUsersByIDs(GetUsersByIDsRequest) returns (GetUsersByIDsResponse);
  rpc UpdateProfile(UpdateProfileRequest) returns (UpdateProfileResponse);
  rpc DeleteUser(DeleteUserRequest) returns (google.protobuf.Empty);
  rpc SearchUsers(SearchUsersRequest) returns (SearchUsersResponse);
  
  // Follow management
  rpc FollowUser(FollowUserRequest) returns (FollowUserResponse);
  rpc UnfollowUser(UnfollowUserRequest) returns (google.protobuf.Empty);
  rpc GetFollowers(GetFollowersRequest) returns (GetFollowersResponse);
  rpc GetFollowing(GetFollowingRequest) returns (GetFollowingResponse);
  rpc CheckFollowStatus(CheckFollowStatusRequest) returns (CheckFollowStatusResponse);
  
  // Follow requests
  rpc GetFollowRequests(GetFollowRequestsRequest) returns (GetFollowRequestsResponse);
  rpc ApproveFollowRequest(ApproveFollowRequestRequest) returns (google.protobuf.Empty);
  rpc RejectFollowRequest(RejectFollowRequestRequest) returns (google.protobuf.Empty);
  
  // Block management
  rpc BlockUser(BlockUserRequest) returns (BlockUserResponse);
  rpc UnblockUser(UnblockUserRequest) returns (google.protobuf.Empty);
  rpc GetBlockedUsers(GetBlockedUsersRequest) returns (GetBlockedUsersResponse);
  
  // Mute management
  rpc MuteUser(MuteUserRequest) returns (MuteUserResponse);
  rpc UnmuteUser(UnmuteUserRequest) returns (google.protobuf.Empty);
  rpc GetMutedUsers(GetMutedUsersRequest) returns (GetMutedUsersResponse);
  rpc CreateMuteKeyword(CreateMuteKeywordRequest) returns (CreateMuteKeywordResponse);
  rpc DeleteMuteKeyword(DeleteMuteKeywordRequest) returns (google.protobuf.Empty);
  rpc GetMuteKeywords(GetMuteKeywordsRequest) returns (GetMuteKeywordsResponse);
  
  // Settings management
  rpc GetSettings(GetSettingsRequest) returns (GetSettingsResponse);
  rpc UpdateSettings(UpdateSettingsRequest) returns (UpdateSettingsResponse);
  
  // List management
  rpc CreateUserList(CreateUserListRequest) returns (CreateUserListResponse);
  rpc UpdateUserList(UpdateUserListRequest) returns (UpdateUserListResponse);
  rpc DeleteUserList(DeleteUserListRequest) returns (google.protobuf.Empty);
  rpc GetUserLists(GetUserListsRequest) returns (GetUserListsResponse);
  rpc GetUserList(GetUserListRequest) returns (GetUserListResponse);
  rpc AddListMember(AddListMemberRequest) returns (google.protobuf.Empty);
  rpc RemoveListMember(RemoveListMemberRequest) returns (google.protobuf.Empty);
  rpc GetListMembers(GetListMembersRequest) returns (GetListMembersResponse);
  
  // Stats
  rpc GetUserStats(GetUserStatsRequest) returns (GetUserStatsResponse);
  
  // Admin operations
  rpc SuspendUser(SuspendUserRequest) returns (google.protobuf.Empty);
  rpc UnsuspendUser(UnsuspendUserRequest) returns (google.protobuf.Empty);
}

// Messages definitions...
```

## 8. Use Cases / Key Flows (主な使い方・処理の流れ)

- **フロー 1: ユーザー作成 (Command)**
    1. Gateway → CreateUserCommandHandler: `CreateUser` gRPC Call (user_data, Metadata: X-Service-ID, Trace Context)
    2. CreateUserCommandHandler: CreateUserCommandUseCaseを呼び出し
    3. CreateUserCommandUseCase: User Aggregateを生成し、UserDomainServiceでビジネスルール検証
    4. CreateUserCommandUseCase: UserRepositoryを通じてUser Aggregateを永続化
    5. CreateUserCommandUseCase: EventPublisherを通じて `user_created` イベントを発行
    6. CreateUserCommandHandler → Gateway: `CreateUserResponse { user_id: "..." }`
- **フロー 2: ユーザー取得 (Query)**
    1. Gateway → GetUserQueryHandler: `GetUser` gRPC Call (user_id, Metadata: X-User-ID, Trace Context)
    2. GetUserQueryHandler: GetUserQueryUseCaseを呼び出し
    3. GetUserQueryUseCase: UserQueryServiceを通じてユーザーのDTOを取得
    4. GetUserQueryUseCase: プライバシー設定に基づくアクセス権限チェック
    5. (アクセス不可の場合) GetUserQueryHandler → Gateway: gRPC Error (PermissionDenied or NotFound)
    6. (アクセス可の場合) GetUserQueryHandler → Gateway: `GetUserResponse { user: { ... } }`
- **フロー 3: プロフィール更新 (Command)**
    1. Gateway → UpdateProfileCommandHandler: `UpdateProfile` gRPC Call (user_id, updates, Metadata: X-User-ID, Trace Context)
    2. UpdateProfileCommandHandler: UpdateProfileCommandUseCaseを呼び出し
    3. UpdateProfileCommandUseCase: UserRepositoryからUser Aggregateを取得
    4. UpdateProfileCommandUseCase: User Aggregate内で所有者検証
    5. (不一致の場合) UpdateProfileCommandHandler → Gateway: gRPC Error (PermissionDenied)
    6. (一致の場合) UpdateProfileCommandUseCase: UserRepositoryを通じてUser Aggregateを更新
    7. UpdateProfileCommandUseCase: EventPublisherを通じて `profile_updated` イベントを発行
    8. UpdateProfileCommandHandler → Gateway: `UpdateProfileResponse {}`
- **フロー 4: フォロー (Command)**
    1. Gateway → FollowUserCommandHandler: `FollowUser` gRPC Call (target_user_id, Metadata: X-User-ID, Trace Context)
    2. FollowUserCommandHandler: FollowUserCommandUseCaseを呼び出し
    3. FollowUserCommandUseCase: Follow Aggregateを生成し、FollowDomainServiceで重複チェック
    4. FollowUserCommandUseCase: 対象ユーザーのプライバシー設定確認（承認制かどうか）
    5. FollowUserCommandUseCase: FollowRepositoryを通じてFollow Aggregateを永続化
    6. FollowUserCommandUseCase: UserStatsRepositoryを通じて統計情報を更新
    7. FollowUserCommandUseCase: EventPublisherを通じて `follow_created` イベントを発行
    8. FollowUserCommandHandler → Gateway: `FollowUserResponse {}`
- **フロー 5: フォロー解除 (Command)**
    1. Gateway → UnfollowUserCommandHandler: `UnfollowUser` gRPC Call (target_user_id, Metadata: X-User-ID, Trace Context)
    2. UnfollowUserCommandHandler: UnfollowUserCommandUseCaseを呼び出し
    3. UnfollowUserCommandUseCase: FollowRepositoryからFollow Aggregateを取得
    4. UnfollowUserCommandUseCase: Follow Aggregate内で所有者検証
    5. UnfollowUserCommandUseCase: FollowRepositoryを通じてFollow Aggregateを削除
    6. UnfollowUserCommandUseCase: EventPublisherを通じて `follow_deleted` イベントを発行
    7. UnfollowUserCommandHandler → Gateway: `UnfollowUserResponse {}`
- **フロー 6: ユーザーブロック (Command)**
    1. Gateway → BlockUserCommandHandler: `BlockUser` gRPC Call (target_user_id, Metadata: X-User-ID, Trace Context)
    2. BlockUserCommandHandler: BlockUserCommandUseCaseを呼び出し
    3. BlockUserCommandUseCase: Block Aggregateを生成し、BlockDomainServiceで重複チェック
    4. BlockUserCommandUseCase: 既存のフォロー関係があれば削除処理
    5. BlockUserCommandUseCase: BlockRepositoryを通じてBlock Aggregateを永続化
    6. BlockUserCommandUseCase: EventPublisherを通じて `block_created` イベントを発行
    7. BlockUserCommandHandler → Gateway: `BlockUserResponse {}`
- **フロー 7: ユーザー検索 (Query)**
    1. Gateway → SearchUsersQueryHandler: `SearchUsers` gRPC Call (query, filters, Metadata: X-User-ID, Trace Context)
    2. SearchUsersQueryHandler: SearchUsersQueryUseCaseを呼び出し
    3. SearchUsersQueryUseCase: UserQueryServiceを通じて検索実行
    4. SearchUsersQueryUseCase: 検索結果に対してプライバシーフィルタリング適用
    5. SearchUsersQueryUseCase: ブロック・ミュート関係のフィルタリング適用
    6. SearchUsersQueryHandler → Gateway: `SearchUsersResponse { users: [...] }`
- **フロー 8: フォロワー一覧取得 (Query)**
    1. Gateway → GetFollowersQueryHandler: `GetFollowers` gRPC Call (user_id, page_info, Metadata: X-User-ID, Trace Context)
    2. GetFollowersQueryHandler: GetFollowersQueryUseCaseを呼び出し
    3. GetFollowersQueryUseCase: FollowQueryServiceを通じてフォロワー一覧を取得
    4. GetFollowersQueryUseCase: プライバシー設定とアクセス権限の確認
    5. GetFollowersQueryUseCase: ブロック・ミュート関係のフィルタリング適用
    6. GetFollowersQueryHandler → Gateway: `GetFollowersResponse { followers: [...] }`
- **フロー 9: ユーザー設定更新 (Command)**
    1. Gateway → UpdateSettingsCommandHandler: `UpdateSettings` gRPC Call (settings, Metadata: X-User-ID, Trace Context)
    2. UpdateSettingsCommandHandler: UpdateSettingsCommandUseCaseを呼び出し
    3. UpdateSettingsCommandUseCase: UserSettingsRepositoryからUserSettings Aggregateを取得
    4. UpdateSettingsCommandUseCase: UserSettings Aggregate内で設定値の検証
    5. UpdateSettingsCommandUseCase: UserSettingsRepositoryを通じて設定を更新
    6. UpdateSettingsCommandUseCase: EventPublisherを通じて `settings_updated` イベントを発行
    7. UpdateSettingsCommandHandler → Gateway: `UpdateSettingsResponse {}`
- **フロー 10: ユーザーリスト作成 (Command)**
    1. Gateway → CreateUserListCommandHandler: `CreateUserList` gRPC Call (list_data, Metadata: X-User-ID, Trace Context)
    2. CreateUserListCommandHandler: CreateUserListCommandUseCaseを呼び出し
    3. CreateUserListCommandUseCase: UserList Aggregateを生成し、UserListDomainServiceでビジネスルール検証
    4. CreateUserListCommandUseCase: UserListRepositoryを通じてUserList Aggregateを永続化
    5. CreateUserListCommandUseCase: EventPublisherを通じて `user_list_created` イベントを発行
    6. CreateUserListCommandHandler → Gateway: `CreateUserListResponse { list_id: "..." }`

## 9. Implementation Plan (実装計画)

### Phase 1: 基本的なユーザー管理 (Week 1-2)
- User Aggregate と基本的なCRUD操作
- UserRepository の実装
- 基本的なプロフィール管理機能
- ユーザー情報のキャッシュ実装

### Phase 2: フォロー機能 (Week 2-3)
- Follow Aggregate の実装
- フォロー/アンフォロー機能
- フォロワー/フォロー中リストの取得
- フォローリクエスト機能（承認制アカウント）

### Phase 3: ブロック/ミュート機能 (Week 3-4)
- Block Aggregate の実装
- Mute Aggregate の実装
- ブロック/ミュート時の関係解除処理
- キーワードミュート機能

### Phase 4: ユーザー設定とリスト (Week 4-5)
- UserSettings Aggregate の実装
- UserList Aggregate の実装
- 設定管理API
- リスト管理API

### Phase 5: 統計とイベント連携 (Week 5-6)
- UserStats Aggregate の実装
- イベント発行・購読の実装
- 他サービスとの連携テスト
- パフォーマンス最適化

## 10. Testing Strategy (テスト戦略)

このサービスでは、[共通テスト戦略](../common/testing-strategy.md)に従ったテスト実装を行います。

### サービス固有のテスト要件
- 大量ユーザーでの検索性能テスト
- フォロー関係の大規模グラフでの性能テスト
- キャッシュヒット率の測定

## 11. Monitoring & Observability (監視と可観測性)

### Metrics
- API レスポンスタイム
- キャッシュヒット率
- データベースクエリ性能
- イベント処理遅延

### Logging
- APIアクセスログ
- エラーログ
- イベント処理ログ

### Tracing
- OpenTelemetryによる分散トレーシング
- サービス間の依存関係の可視化

### Alerting
- エラー率の急増
- レスポンスタイムの劣化
- キャッシュミス率の上昇

## 12. Security Considerations (セキュリティ考慮事項)

### Authentication & Authorization
- avion-authとの連携による認証
- ユーザーIDベースのアクセス制御

### Data Protection
- 個人情報の暗号化
- メールアドレスのハッシュ化
- 削除済みデータの完全削除

### Input Validation
- SQLインジェクション対策
- XSS対策
- ユーザー入力の厳密な検証

### Rate Limiting
- API呼び出しのレート制限
- フォロー/アンフォローの頻度制限

## 13. Performance Optimization (パフォーマンス最適化)

### Database Optimization
- 適切なインデックス設計
- クエリの最適化
- パーティショニングの検討

### Caching Strategy
- 多層キャッシュ（Redis + アプリケーション）
- キャッシュの事前ロード
- キャッシュの無効化戦略

### Query Optimization
- N+1問題の回避
- バッチ処理の活用
- 非同期処理の活用

## 14. Scalability (スケーラビリティ)

### Horizontal Scaling
- ステートレスなサービス設計
- Kubernetes上での自動スケーリング

### Data Sharding
- ユーザーIDベースのシャーディング
- フォロー関係のグラフ分割

### Event Processing
- イベントの並列処理
- バックプレッシャー制御

## 15. エラーハンドリング戦略（ユーザー特化）

> **注意:** エラーコードは[共通エラーコード標準](../common/errors/error-codes.md)に準拠します。このサービスではプレフィックス `USR` を使用します。

### エラーコード体系

本サービスは、Avionプラットフォーム標準のエラーコード体系に準拠します。

- **命名規則**: `[SERVICE]_[LAYER]_[ERROR_TYPE]`形式
- **エラーカタログ**: [error-catalog.md](./error-catalog.md)
- **実装ガイド**: [共通エラー実装ガイド](../common/errors/implementation-guide.md)
- **標準仕様**: [エラーコード標準化ガイドライン](../common/errors/error-standards.md)

詳細なエラーコード定義とマッピングについては、上記のドキュメントを参照してください。

avion-userサービスでは、ユーザーデータの整合性とフォロー関係の複雑性に対応するため、包括的なエラーハンドリング戦略を実装します。

### ユーザーデータエラーの分類と対応

#### データ整合性エラー
**発生場面**: ユーザー作成、プロフィール更新、設定変更時
**対応戦略**:
- **事前検証**: ドメインロジック内での厳密なバリデーション
- **楽観的ロック**: 同時更新によるデータ破損防止
- **トランザクション境界**: データ不整合時の自動ロールバック
- **リトライ機構**: 一時的な競合状態への対応

```go
// ユーザーデータ整合性エラーの例
type UserDataIntegrityError struct {
    UserID    string
    Field     string
    Value     interface{}
    Violation string
    Context   map[string]interface{}
}

func (e *UserDataIntegrityError) Error() string {
    return fmt.Sprintf("user data integrity violation: %s field '%s' with value '%v': %s", 
        e.UserID, e.Field, e.Value, e.Violation)
}
```

#### プロフィールデータ検証エラー
**発生場面**: プロフィール項目の更新、カスタムフィールドの追加時
**特別な考慮事項**:
- **Unicode正規化**: 絵文字やマルチバイト文字の適切な処理
- **URL検証**: アバター・ヘッダー画像URLの存在確認とセキュリティチェック
- **禁止コンテンツ検出**: スパムやハラスメント内容の自動検出
- **文字数制限**: Unicode文字数の正確な計算（サロゲートペア対応）

```go
type ProfileValidationError struct {
    UserID      string
    FieldName   string
    FieldValue  string
    ValidationRule string
    SuggestedFix   string
}

func (e *ProfileValidationError) Error() string {
    return fmt.Sprintf("profile validation failed for user %s: %s field violates %s rule", 
        e.UserID, e.FieldName, e.ValidationRule)
}
```

### フォロー関係エラーの高度な対応

#### フォロー失敗パターンの分類

**1. ブロック関係による失敗**
- **双方向ブロックチェック**: フォロー・フォロワー両方向のブロック確認
- **インスタンスブロック**: ドメインレベルでのブロック確認
- **継続的監視**: ブロック関係の変更をリアルタイム反映

**2. プライバシー設定による失敗**
- **承認制アカウント**: フォローリクエストの自動生成と通知
- **条件付きフォロー**: 相互フォロワーのみなど、複雑な条件の評価
- **段階的エスカレーション**: 拒否された場合の代替手段提示

**3. システム制限による失敗**
- **フォロー上限**: スパム防止のための動的制限調整
- **レート制限**: 短時間での大量フォローの防止
- **アカウント信頼度**: 新規アカウント・疑わしいパターンの制限

```go
type FollowFailureContext struct {
    FollowerID      string
    FolloweeID      string
    FailureReason   FollowFailureReason
    BlockingFactor  BlockingFactor
    RetryPossible   bool
    RetryAfter      *time.Time
    AlternativeActions []AlternativeAction
    UserMessage     string
    TechnicalDetails map[string]interface{}
}

type FollowFailureReason int

const (
    FollowFailureBlocked FollowFailureReason = iota
    FollowFailurePrivacyRestriction
    FollowFailureLimitExceeded
    FollowFailureAccountSuspended
    FollowFailureSpamDetected
    FollowFailureTechnical
)

func (f *FollowFailureContext) ShouldNotifyUser() bool {
    return f.FailureReason != FollowFailureTechnical
}

func (f *FollowFailureContext) GetUserFriendlyMessage() string {
    switch f.FailureReason {
    case FollowFailureBlocked:
        return "This user has blocked you or you have blocked them."
    case FollowFailurePrivacyRestriction:
        return "This user has privacy settings that prevent following."
    case FollowFailureLimitExceeded:
        return "You've reached your follow limit. Please unfollow some accounts first."
    default:
        return f.UserMessage
    }
}
```

#### フォロー関係の修復機能

**自動修復**:
- **データ不整合の検出**: 定期的なフォロー関係の整合性チェック
- **統計値の再計算**: フォロワー・フォロー数の自動修正
- **孤立したリクエスト**: 無効になったフォローリクエストのクリーンアップ

**手動修復サポート**:
- **関係リセット**: ユーザーが関係をリセットできる機能
- **履歴確認**: フォロー関係の変更履歴表示
- **問題報告**: システム不具合の報告機能

### エラー回復戦略

#### 段階的グレースフル デグラデーション
1. **完全機能**: すべての機能が正常動作
2. **制限モード**: 重要機能のみ提供（新規フォローを制限）
3. **読み取り専用**: 既存データの参照のみ許可
4. **緊急モード**: 最小限のユーザー情報のみ提供

#### 復旧優先度の設定
- **P0**: ユーザー認証・基本プロフィール表示
- **P1**: フォロー関係の参照・基本的なプライバシー制御
- **P2**: プロフィール更新・フォロー操作
- **P3**: 統計情報・推薦機能

### ドメインエラーの定義

```go
// domain/error/errors.go
package error

import "errors"

// ユーザー関連エラー
var (
    ErrUserNotFound          = errors.New("user not found")
    ErrUserAlreadyExists     = errors.New("user already exists")
    ErrInvalidUsername       = errors.New("invalid username")
    ErrUsernameTaken         = errors.New("username already taken")
    ErrInvalidEmail          = errors.New("invalid email address")
    ErrEmailTaken            = errors.New("email already taken")
    ErrUserSuspended         = errors.New("user account suspended")
    ErrUserDeactivated       = errors.New("user account deactivated")
    ErrSelfAction            = errors.New("cannot perform action on self")
)

// プロフィール関連エラー
var (
    ErrInvalidDisplayName    = errors.New("invalid display name")
    ErrBioTooLong           = errors.New("bio text too long")
    ErrInvalidProfileField   = errors.New("invalid profile field")
    ErrTooManyProfileFields  = errors.New("too many profile fields")
    ErrInvalidAvatarURL     = errors.New("invalid avatar URL")
    ErrInvalidHeaderURL     = errors.New("invalid header URL")
)

// フォロー関連エラー
var (
    ErrFollowNotFound       = errors.New("follow relationship not found")
    ErrAlreadyFollowing     = errors.New("already following user")
    ErrCannotFollowSelf     = errors.New("cannot follow yourself")
    ErrFollowRequestPending = errors.New("follow request already pending")
    ErrFollowLimitExceeded  = errors.New("follow limit exceeded")
    ErrPrivateAccount       = errors.New("account is private")
)

// ブロック関連エラー
var (
    ErrBlockNotFound        = errors.New("block relationship not found")
    ErrAlreadyBlocked       = errors.New("user already blocked")
    ErrCannotBlockSelf      = errors.New("cannot block yourself")
    ErrBlockLimitExceeded   = errors.New("block limit exceeded")
)

// ミュート関連エラー
var (
    ErrMuteNotFound         = errors.New("mute relationship not found")
    ErrAlreadyMuted         = errors.New("user already muted")
    ErrCannotMuteSelf       = errors.New("cannot mute yourself")
    ErrMuteLimitExceeded    = errors.New("mute limit exceeded")
    ErrInvalidMuteKeyword   = errors.New("invalid mute keyword")
    ErrKeywordTooLong       = errors.New("mute keyword too long")
)

// 設定関連エラー
var (
    ErrSettingsNotFound     = errors.New("user settings not found")
    ErrInvalidLanguage      = errors.New("invalid language setting")
    ErrInvalidTimezone      = errors.New("invalid timezone setting")
    ErrInvalidTheme         = errors.New("invalid theme setting")
    ErrInvalidPrivacySetting = errors.New("invalid privacy setting")
)

// リスト関連エラー
var (
    ErrListNotFound         = errors.New("user list not found")
    ErrListNameTaken        = errors.New("list name already taken")
    ErrInvalidListName      = errors.New("invalid list name")
    ErrListLimitExceeded    = errors.New("list limit exceeded")
    ErrMemberAlreadyInList  = errors.New("user already in list")
    ErrMemberNotInList      = errors.New("user not in list")
    ErrListMemberLimitExceeded = errors.New("list member limit exceeded")
)

// 統計関連エラー
var (
    ErrStatsNotFound        = errors.New("user stats not found")
    ErrStatsUpdateFailed    = errors.New("stats update failed")
    ErrNegativeCount        = errors.New("count cannot be negative")
)

// 認可関連エラー
var (
    ErrUnauthorizedAccess   = errors.New("unauthorized access")
    ErrPermissionDenied     = errors.New("permission denied")
    ErrInsufficientPrivileges = errors.New("insufficient privileges")
)
```

### 各層でのエラーハンドリング

#### Handler層
- ドメインエラーを適切なgRPCステータスコードに変換
- クライアントに適切なエラーメッセージを返す

```go
func (h *CreateUserCommandHandler) CreateUser(ctx context.Context, req *pb.CreateUserRequest) (*pb.CreateUserResponse, error) {
    output, err := h.useCase.Execute(ctx, input)
    if err != nil {
        switch {
        case errors.Is(err, domain.ErrUsernameTaken):
            return nil, status.Error(codes.AlreadyExists, "username already taken")
        case errors.Is(err, domain.ErrEmailTaken):
            return nil, status.Error(codes.AlreadyExists, "email already taken")
        case errors.Is(err, domain.ErrInvalidUsername):
            return nil, status.Error(codes.InvalidArgument, "invalid username format")
        case errors.Is(err, domain.ErrInvalidEmail):
            return nil, status.Error(codes.InvalidArgument, "invalid email format")
        case errors.Is(err, domain.ErrUnauthorizedAccess):
            return nil, status.Error(codes.PermissionDenied, "unauthorized access")
        default:
            return nil, status.Error(codes.Internal, "internal server error")
        }
    }
    return response, nil
}
```

#### UseCase層
- ドメインエラーをそのまま上位層に伝播
- 必要に応じてコンテキスト情報を追加
- トランザクション境界でのエラーハンドリング

```go
func (u *FollowUserCommandUseCase) Execute(ctx context.Context, input *FollowUserInput) (*FollowUserOutput, error) {
    // ユーザーの取得
    targetUser, err := u.userRepo.FindByID(ctx, input.TargetUserID)
    if err != nil {
        if errors.Is(err, repository.ErrNotFound) {
            return nil, domain.ErrUserNotFound
        }
        return nil, fmt.Errorf("find target user: %w", err)
    }
    
    // ビジネスルールの検証
    if targetUser.ID == input.FollowerID {
        return nil, domain.ErrCannotFollowSelf
    }
    
    // 既存のフォロー関係チェック
    exists, err := u.followRepo.ExistsByFollowerAndFollowee(ctx, input.FollowerID, input.TargetUserID)
    if err != nil {
        return nil, fmt.Errorf("check existing follow: %w", err)
    }
    if exists {
        return nil, domain.ErrAlreadyFollowing
    }
    
    // フォローの作成
    if err := u.followRepo.Create(ctx, follow); err != nil {
        return nil, fmt.Errorf("create follow: %w", err)
    }
    
    return output, nil
}
```

#### Infrastructure層
- データベースの制約違反を適切なドメインエラーにマッピング
- 外部システムのエラーをドメインエラーに変換

```go
func (r *PostgreSQLUserRepository) Create(ctx context.Context, user *domain.User) error {
    _, err := r.db.ExecContext(ctx, query, args...)
    if err != nil {
        var pgErr *pgconn.PgError
        if errors.As(err, &pgErr) {
            switch pgErr.Code {
            case "23505": // unique_violation
                if pgErr.ConstraintName == "users_username_key" {
                    return domain.ErrUsernameTaken
                }
                if pgErr.ConstraintName == "users_email_key" {
                    return domain.ErrEmailTaken
                }
                return domain.ErrUserAlreadyExists
            case "23514": // check_violation
                if pgErr.ConstraintName == "users_username_format_check" {
                    return domain.ErrInvalidUsername
                }
            }
        }
        return fmt.Errorf("insert user: %w", err)
    }
    return nil
}
```

## 16. 構造化ログ戦略（ユーザー活動中心）

avion-userサービスでは、ユーザー活動の追跡とセキュリティ監視を重視した構造化ログ戦略を実装します。SNSプラットフォームにおけるユーザー行動の分析、異常検出、コンプライアンス要件への対応を考慮しています。

### ログフレームワーク
- **使用ライブラリ**: `slog` (Go標準ライブラリ) または `zap`
- **出力形式**: JSON形式
- **ログレベル**: Debug, Info, Warn, Error, CRITICAL
- **CRITICALレベル**: panicにして処理を停止させないといけないレベル（データ整合性の致命的破壊、システムリソースの枯渇等）

### ログ構造の標準フィールド
```go
type LogContext struct {
    // 必須フィールド
    Timestamp   time.Time `json:"timestamp"`
    Level       string    `json:"level"`
    Service     string    `json:"service"`     // "avion-user"
    Version     string    `json:"version"`     // サービスバージョン
    TraceID     string    `json:"trace_id"`    // OpenTelemetry TraceID
    SpanID      string    `json:"span_id"`     // OpenTelemetry SpanID
    
    // コンテキストフィールド
    UserID      string    `json:"user_id,omitempty"`
    TargetUserID string   `json:"target_user_id,omitempty"`
    RequestID   string    `json:"request_id,omitempty"`
    Method      string    `json:"method,omitempty"`      // gRPCメソッド名
    Layer       string    `json:"layer,omitempty"`       // domain/usecase/infra/handler
    
    // エラー情報
    Error       string    `json:"error,omitempty"`
    ErrorCode   string    `json:"error_code,omitempty"`
    StackTrace  string    `json:"stack_trace,omitempty"`
    
    // パフォーマンス
    Duration    int64     `json:"duration_ms,omitempty"` // 処理時間（ミリ秒）
    
    // カスタムフィールド
    Extra       map[string]interface{} `json:"extra,omitempty"`
}
```

### 各層でのログ出力例

#### Handler層
```go
logger.Info("gRPC request received",
    slog.String("method", "CreateUser"),
    slog.String("trace_id", traceID),
    slog.String("username", username),
    slog.String("email", email),
    slog.String("layer", "handler"),
)

logger.Error("gRPC request failed",
    slog.String("method", "GetUser"),
    slog.String("trace_id", traceID),
    slog.String("user_id", userID),
    slog.String("error", err.Error()),
    slog.String("error_code", "USER_NOT_FOUND"),
    slog.Int64("duration_ms", duration),
    slog.String("layer", "handler"),
)
```

#### Use Case層
```go
logger.Info("user creation processing",
    slog.String("trace_id", ctx.Value("trace_id").(string)),
    slog.String("username", username),
    slog.Bool("is_bot", isBot),
    slog.String("layer", "usecase"),
)

logger.Info("follow relationship created",
    slog.String("trace_id", ctx.Value("trace_id").(string)),
    slog.String("follower_id", followerID),
    slog.String("followee_id", followeeID),
    slog.Bool("is_approved", isApproved),
    slog.String("layer", "usecase"),
)
```

#### Infrastructure層
```go
logger.Debug("database query executed",
    slog.String("table", "users"),
    slog.String("operation", "insert"),
    slog.Int64("duration_ms", queryDuration),
    slog.String("layer", "infra"),
)

logger.Warn("redis cache miss",
    slog.String("cache_type", "user_profile"),
    slog.String("user_id", userID),
    slog.String("layer", "infra"),
)
```

### ユーザー活動の包括的ログ記録

#### アカウント管理イベント

```go
// ユーザー作成（正常・異常ケース共通）
logger.Info("user account created",
    slog.String("event_category", "account_lifecycle"),
    slog.String("event_type", "user_created"),
    slog.String("user_id", userID),
    slog.String("username", username),
    slog.String("email_hash", emailHash), // ハッシュ化済み
    slog.Bool("is_bot", isBot),
    slog.String("registration_source", registrationSource), // web, api, import等
    slog.String("account_status", "active"),
    slog.String("client_ip", clientIP),
    slog.String("user_agent", userAgent),
    slog.String("referrer", referrer),
    slog.Group("profile_completeness",
        slog.Int("completed_fields", completedFields),
        slog.Int("total_fields", totalFields),
        slog.Float64("completion_rate", completionRate),
    ),
)

// プロフィール更新（詳細な変更追跡）
logger.Info("user profile updated",
    slog.String("event_category", "profile_management"),
    slog.String("event_type", "profile_updated"),
    slog.String("user_id", userID),
    slog.Group("changes",
        slog.Any("modified_fields", modifiedFields),
        slog.Any("before_values", sanitizedBeforeValues), // 機密情報除去済み
        slog.Any("after_values", sanitizedAfterValues),
        slog.Int("total_changes", changeCount),
    ),
    slog.Group("validation_results",
        slog.Bool("all_passed", allValidationPassed),
        slog.Any("failed_validations", failedValidations),
        slog.Int("warning_count", warningCount),
    ),
    slog.String("update_reason", updateReason), // user_initiated, migration, admin_correction
    slog.Int64("profile_version", profileVersion),
)

// アカウント状態変更（重要度の高いイベント）
logger.Warn("account status changed",
    slog.String("event_category", "account_security"),
    slog.String("event_type", "status_changed"),
    slog.String("user_id", userID),
    slog.String("previous_status", previousStatus),
    slog.String("new_status", newStatus),
    slog.String("changed_by", changedBy), // user_self, admin, system
    slog.String("reason", reason),
    slog.String("admin_id", adminID), // 管理者による変更の場合
    slog.Time("scheduled_revert", scheduledRevert), // 一時的な変更の場合
    slog.Group("affected_relationships",
        slog.Int("followers_affected", followersAffected),
        slog.Int("following_affected", followingAffected),
        slog.Int("lists_affected", listsAffected),
    ),
)
```

#### ソーシャル関係イベント

```go
// フォロー関係の作成（成功・失敗含む）
logger.Info("follow relationship attempt",
    slog.String("event_category", "social_interaction"),
    slog.String("event_type", "follow_attempted"),
    slog.String("follower_id", followerID),
    slog.String("followee_id", followeeID),
    slog.Bool("success", success),
    slog.String("result", result), // approved, pending, rejected, failed
    slog.String("failure_reason", failureReason), // blocked, limit_exceeded, private等
    slog.Bool("requires_approval", requiresApproval),
    slog.Bool("mutual_follow", mutualFollow),
    slog.Group("relationship_context",
        slog.Bool("previously_followed", previouslyFollowed),
        slog.Time("last_follow_attempt", lastFollowAttempt),
        slog.Int("follow_attempt_count", followAttemptCount),
        slog.String("relationship_strength", relationshipStrength), // strong, moderate, weak, none
    ),
    slog.Group("anti_spam_signals",
        slog.Bool("rate_limited", rateLimited),
        slog.Bool("suspicious_pattern", suspiciousPattern),
        slog.Float64("spam_score", spamScore),
    ),
)

// ブロック操作（重要なセキュリティイベント）
logger.Warn("user blocked",
    slog.String("event_category", "content_safety"),
    slog.String("event_type", "user_blocked"),
    slog.String("blocker_id", blockerID),
    slog.String("blocked_id", blockedID),
    slog.String("block_reason", blockReason), // harassment, spam, impersonation等
    slog.Bool("mutual_block", mutualBlock),
    slog.Group("cleanup_actions",
        slog.Bool("follow_removed", followRemoved),
        slog.Int("lists_cleaned", listsCleanedCount),
        slog.Int("notifications_removed", notificationsRemoved),
    ),
    slog.Group("escalation_info",
        slog.Bool("requires_moderation_review", requiresModerationReview),
        slog.Bool("pattern_detected", patternDetected),
        slog.String("escalation_reason", escalationReason),
    ),
)

// ミュート操作（プライバシー重視）
logger.Info("content filtering applied",
    slog.String("event_category", "content_curation"),
    slog.String("event_type", "mute_applied"),
    slog.String("muter_id", muterID),
    slog.String("muted_target", mutedTarget), // user_id, keyword, domain
    slog.String("mute_type", muteType), // user, keyword, thread, notification
    slog.String("mute_scope", muteScope), // posts, reposts, notifications, all
    slog.Time("expires_at", expiresAt),
    slog.Group("effectiveness_prediction",
        slog.Float64("expected_reduction", expectedReduction),
        slog.Int("estimated_affected_items", estimatedAffectedItems),
    ),
)
```

#### プライバシー・セキュリティイベント

```go
// 設定変更（プライバシーに影響する変更）
logger.Info("privacy settings changed",
    slog.String("event_category", "privacy_control"),
    slog.String("event_type", "settings_updated"),
    slog.String("user_id", userID),
    slog.Group("privacy_changes",
        slog.Any("visibility_changes", visibilityChanges),
        slog.Any("notification_changes", notificationChanges),
        slog.Any("interaction_changes", interactionChanges),
    ),
    slog.Group("impact_assessment",
        slog.Float64("privacy_score_before", privacyScoreBefore),
        slog.Float64("privacy_score_after", privacyScoreAfter),
        slog.String("privacy_trend", privacyTrend), // increasing, decreasing, stable
        slog.Bool("public_visibility_changed", publicVisibilityChanged),
    ),
)

// 異常なアクセスパターンの検出
logger.Warn("unusual activity detected",
    slog.String("event_category", "security_monitoring"),
    slog.String("event_type", "anomaly_detected"),
    slog.String("user_id", userID),
    slog.String("anomaly_type", anomalyType), // bulk_operations, unusual_timing, geographic等
    slog.Group("activity_metrics",
        slog.Int("actions_per_minute", actionsPerMinute),
        slog.Int("unique_targets", uniqueTargets),
        slog.Float64("deviation_score", deviationScore),
    ),
    slog.Group("risk_assessment",
        slog.String("risk_level", riskLevel), // low, medium, high, critical
        slog.Bool("automated_action_taken", automatedActionTaken),
        slog.String("mitigation_applied", mitigationApplied), // rate_limit, temp_restriction等
    ),
)

// データエクスポート・インポート（GDPR対応）
logger.Info("data portability request",
    slog.String("event_category", "data_governance"),
    slog.String("event_type", "data_export_requested"),
    slog.String("user_id", userID),
    slog.String("request_type", requestType), // full_export, selective_export, account_migration
    slog.Group("export_scope",
        slog.Any("data_types", dataTypes), // profile, follows, blocks, settings等
        slog.String("format", format), // json, csv, activitypub
        slog.Bool("include_media", includeMedia),
    ),
    slog.Group("compliance_context",
        slog.String("legal_basis", legalBasis), // gdpr_request, user_convenience等
        slog.String("request_source", requestSource), // user_portal, api, support_ticket
        slog.Time("completion_deadline", completionDeadline),
    ),
)
```

#### パフォーマンス・メトリクスログ

```go
// 大量操作のパフォーマンス追跡
logger.Info("bulk operation completed",
    slog.String("event_category", "performance_monitoring"),
    slog.String("event_type", "bulk_operation"),
    slog.String("operation_type", operationType), // bulk_follow, bulk_unfollow, list_management
    slog.String("user_id", userID),
    slog.Group("performance_metrics",
        slog.Int("items_processed", itemsProcessed),
        slog.Int("items_successful", itemsSuccessful),
        slog.Int("items_failed", itemsFailed),
        slog.Int64("total_duration_ms", totalDuration),
        slog.Float64("average_item_duration_ms", avgItemDuration),
        slog.Int("database_queries", databaseQueries),
        slog.Int("cache_hits", cacheHits),
        slog.Int("cache_misses", cacheMisses),
    ),
    slog.Group("resource_usage",
        slog.Int64("memory_peak_mb", memoryPeakMB),
        slog.Int("goroutines_peak", goroutinesPeak),
        slog.Float64("cpu_usage_percent", cpuUsagePercent),
    ),
)
```

#### セキュリティ・コンプライアンス拡張

```go
// 管理者操作の監査ログ（法的要件対応）
logger.Warn("admin action performed",
    slog.String("event_category", "admin_audit"),
    slog.String("event_type", "admin_action"),
    slog.String("admin_id", adminID),
    slog.String("admin_role", adminRole),
    slog.String("target_user_id", targetUserID),
    slog.String("action_type", actionType), // suspend, unsuspend, delete, modify_profile
    slog.String("justification", justification),
    slog.String("approval_reference", approvalReference), // チケット番号等
    slog.Group("audit_context",
        slog.Bool("user_consent_obtained", userConsentObtained),
        slog.String("legal_basis", legalBasis), // gdpr_art6_1f, terms_violation等
        slog.String("retention_period", retentionPeriod),
        slog.Bool("requires_user_notification", requiresUserNotification),
    ),
)

// データ保護関連イベント
logger.Info("data protection event",
    slog.String("event_category", "data_protection"),
    slog.String("event_type", "data_access_logged"),
    slog.String("accessor_type", accessorType), // user_self, admin, system, third_party
    slog.String("accessor_id", accessorID),
    slog.String("data_subject_id", dataSubjectID),
    slog.Group("accessed_data",
        slog.Any("data_categories", dataCategories), // profile, social_graph, settings
        slog.String("access_purpose", accessPurpose), // service_delivery, analytics, compliance
        slog.String("legal_basis", legalBasis),
        slog.Bool("automated_processing", automatedProcessing),
    ),
    slog.Group("consent_tracking",
        slog.Bool("explicit_consent", explicitConsent),
        slog.Time("consent_timestamp", consentTimestamp),
        slog.String("consent_version", consentVersion),
        slog.Bool("can_withdraw", canWithdraw),
    ),
)
```

### 高度なログ分析・監視戦略

#### ログ集約とリアルタイム監視

**ログ集約パターン**:
- **イベントカテゴリ別ストリーム**: セキュリティ、パフォーマンス、ビジネス指標で分離
- **リアルタイムアラート**: 異常パターンの即座検出
- **メトリクス抽出**: 構造化ログからのKPI自動計算

```go
// 異常検出のためのメトリクス
type UserActivityMetrics struct {
    UserID              string
    FollowsPerHour      int
    UnfollowsPerHour    int
    ProfileUpdatesPerDay int
    BlocksPerDay        int
    MutesPerHour        int
    FailedActionsCount  int
    SuspiciousScore     float64
    RiskLevel          string
}

// ログからメトリクス生成の例
logger.Info("user activity metrics calculated",
    slog.String("event_category", "metrics_generation"),
    slog.String("event_type", "activity_metrics"),
    slog.String("user_id", userID),
    slog.Group("activity_rates",
        slog.Float64("follows_per_hour", metrics.FollowsPerHour),
        slog.Float64("profile_changes_per_day", metrics.ProfileUpdatesPerDay),
        slog.Float64("suspicious_score", metrics.SuspiciousScore),
    ),
    slog.Group("behavioral_analysis",
        slog.String("activity_pattern", activityPattern), // normal, burst, bot_like
        slog.Bool("potential_automation", potentialAutomation),
        slog.String("confidence_level", confidenceLevel), // high, medium, low
    ),
)
```

#### セキュリティ監視の自動化

**パターン検出**:
- **大量フォロー/アンフォロー**: スパム行動の検出
- **短時間での複数ブロック**: 嫌がらせパターンの検出
- **異常なプロフィール変更**: 乗っ取りアカウントの可能性

```go
// 自動セキュリティアクションのログ
logger.Warn("automated security action triggered",
    slog.String("event_category", "automated_security"),
    slog.String("event_type", "auto_mitigation_applied"),
    slog.String("user_id", userID),
    slog.String("trigger_reason", triggerReason),
    slog.String("action_taken", actionTaken), // rate_limit, temp_restriction, review_queue
    slog.Group("detection_details",
        slog.String("pattern_type", patternType),
        slog.Float64("confidence_score", confidenceScore),
        slog.Any("evidence", evidence),
        slog.Int("similar_cases_last_24h", similarCases),
    ),
    slog.Group("action_parameters",
        slog.Time("action_expires_at", actionExpiresAt),
        slog.Bool("human_review_required", humanReviewRequired),
        slog.String("escalation_path", escalationPath),
    ),
)
```

### セキュリティ考慮事項

#### 個人情報保護
- **機密情報の完全除外**: パスワード、トークン、APIキーは絶対にログに含めない
- **メールアドレスのハッシュ化**: SHA-256ハッシュで個人特定を困難にしつつ追跡可能性を維持
- **IPアドレスの匿名化**: 最後のオクテットをマスク（例: 192.168.1.xxx）
- **ユーザーエージェントの正規化**: ブラウザバージョン等の詳細情報を抽象化

#### 法的コンプライアンス
- **データ保持期間の遵守**: イベントタイプ別の適切な保持期間設定
- **監査証跡の確保**: 管理者操作の完全な記録と改ざん防止
- **ユーザー権利への対応**: データポータビリティ、削除権への迅速対応
- **地域別法令対応**: GDPR、CCPA等の地域別要件への適合

#### 運用セキュリティ
- **ログアクセス制御**: 職責に応じたログアクセス権限の厳格な管理
- **暗号化**: 保存時・転送時のログの暗号化
- **改ざん検出**: ログの整合性チェックとデジタル署名
- **リアルタイム監視**: 異常パターンの即座検出と自動対応

## 17. ドメインオブジェクトとDBスキーマのマッピング

### User Aggregate → users テーブル

```sql
CREATE TABLE users (
    user_id BIGINT PRIMARY KEY,  -- Snowflake ID
    username VARCHAR(30) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE,
    display_name VARCHAR(30),
    bio TEXT,
    avatar_url VARCHAR(500),
    header_url VARCHAR(500),
    location VARCHAR(30),
    website VARCHAR(255),
    birthday DATE,
    account_status VARCHAR(20) NOT NULL DEFAULT 'active',
    privacy_level VARCHAR(20) NOT NULL DEFAULT 'public',
    is_bot BOOLEAN DEFAULT FALSE,
    bot_owner_id BIGINT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    last_active_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    version INTEGER NOT NULL DEFAULT 1,
    
    INDEX idx_username (username),
    INDEX idx_email (email),
    INDEX idx_account_status (account_status),
    INDEX idx_created_at (created_at),
    INDEX idx_deleted_at (deleted_at)
);
```

### ProfileField Entity → profile_fields テーブル

```sql
CREATE TABLE profile_fields (
    field_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    name VARCHAR(20) NOT NULL,
    value VARCHAR(200) NOT NULL,
    verified BOOLEAN DEFAULT FALSE,
    verified_at TIMESTAMP WITH TIME ZONE,
    display_order INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    
    UNIQUE(user_id, display_order),
    INDEX idx_user_id (user_id)
);
```

### Follow Aggregate → follows テーブル

```sql
CREATE TABLE follows (
    follow_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    followee_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    is_approved BOOLEAN DEFAULT TRUE,
    requested_at TIMESTAMP WITH TIME ZONE,
    approved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    
    UNIQUE(follower_id, followee_id),
    INDEX idx_follower_id (follower_id),
    INDEX idx_followee_id (followee_id),
    INDEX idx_is_approved (is_approved),
    INDEX idx_created_at (created_at)
);
```

### FollowRequest Entity → follow_requests テーブル

```sql
CREATE TABLE follow_requests (
    request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    target_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    message TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    requested_at TIMESTAMP WITH TIME ZONE NOT NULL,
    processed_at TIMESTAMP WITH TIME ZONE,
    
    UNIQUE(requester_id, target_id),
    INDEX idx_target_id_status (target_id, status),
    INDEX idx_requested_at (requested_at)
);
```

### Block Aggregate → blocks テーブル

```sql
CREATE TABLE blocks (
    block_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    blocked_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    
    UNIQUE(blocker_id, blocked_id),
    INDEX idx_blocker_id (blocker_id),
    INDEX idx_blocked_id (blocked_id)
);
```

### Mute Aggregate → mutes テーブル

```sql
CREATE TABLE mutes (
    mute_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    muter_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    muted_id BIGINT REFERENCES users(user_id) ON DELETE CASCADE,
    mute_type VARCHAR(20) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    
    UNIQUE(muter_id, muted_id),
    INDEX idx_muter_id (muter_id),
    INDEX idx_mute_type (mute_type),
    INDEX idx_expires_at (expires_at)
);
```

### MuteKeyword Entity → mute_keywords テーブル

```sql
CREATE TABLE mute_keywords (
    keyword_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    keyword VARCHAR(100) NOT NULL,
    is_regex BOOLEAN DEFAULT FALSE,
    case_sensitive BOOLEAN DEFAULT FALSE,
    whole_word BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    
    INDEX idx_user_id (user_id)
);
```

### UserSettings Aggregate → user_settings テーブル

```sql
CREATE TABLE user_settings (
    user_id BIGINT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    language VARCHAR(5) DEFAULT 'ja',
    timezone VARCHAR(50) DEFAULT 'Asia/Tokyo',
    theme VARCHAR(20) DEFAULT 'auto',
    privacy_settings JSONB NOT NULL DEFAULT '{}',
    notification_settings JSONB NOT NULL DEFAULT '{}',
    ui_settings JSONB NOT NULL DEFAULT '{}',
    accessibility_settings JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    version INTEGER NOT NULL DEFAULT 1
);
```

### UserList Aggregate → user_lists テーブル

```sql
CREATE TABLE user_lists (
    list_id BIGINT PRIMARY KEY,  -- Snowflake ID
    owner_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_public BOOLEAN DEFAULT TRUE,
    member_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    
    UNIQUE(owner_id, name),
    INDEX idx_owner_id (owner_id),
    INDEX idx_is_public (is_public)
);
```

### ListMember Entity → list_members テーブル

```sql
CREATE TABLE list_members (
    member_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    list_id BIGINT NOT NULL REFERENCES user_lists(list_id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    added_by BIGINT NOT NULL REFERENCES users(user_id),
    added_at TIMESTAMP WITH TIME ZONE NOT NULL,
    
    UNIQUE(list_id, user_id),
    INDEX idx_list_id (list_id),
    INDEX idx_user_id (user_id)
);
```

### UserStats Aggregate → user_stats テーブル

```sql
CREATE TABLE user_stats (
    user_id BIGINT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    follower_count INTEGER NOT NULL DEFAULT 0,
    following_count INTEGER NOT NULL DEFAULT 0,
    drop_count INTEGER NOT NULL DEFAULT 0,
    listed_count INTEGER NOT NULL DEFAULT 0,
    reaction_received_count INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    version INTEGER NOT NULL DEFAULT 1
);
```

### Value Objectのキャッシュ（Redis）

```redis
# ユーザー情報キャッシュ
KEY: user:{user_id}
VALUE: {
    "username": "alice",
    "display_name": "Alice",
    "bio": "Hello world",
    "avatar_url": "https://...",
    "account_status": "active",
    "privacy_level": "public",
    "is_bot": false
}
TTL: 300 (5分)

# フォロー関係キャッシュ
KEY: follow:{follower_id}:{followee_id}
VALUE: "true" | "false"
TTL: 60 (1分)

# フォロワー統計キャッシュ
KEY: stats:{user_id}
VALUE: {
    "follower_count": 100,
    "following_count": 50,
    "drop_count": 200,
    "listed_count": 5
}
TTL: 60 (1分)

# ブロックリストキャッシュ
KEY: blocks:{blocker_id}
VALUE: Set of blocked user IDs
TTL: 300 (5分)

# ミュートリストキャッシュ
KEY: mutes:{muter_id}
VALUE: Set of muted user IDs
TTL: 300 (5分)

# ユーザー検索結果キャッシュ
KEY: search_users:{query_hash}
VALUE: List of user IDs
TTL: 60 (1分)

# ユーザー設定キャッシュ
KEY: settings:{user_id}
VALUE: {
    "language": "ja",
    "timezone": "Asia/Tokyo",
    "theme": "dark",
    "privacy_settings": {...},
    "notification_settings": {...}
}
TTL: 300 (5分)
```

## 18. Migration Strategy (移行戦略)

### Data Migration
- 既存システムからのユーザーデータ移行
- フォロー関係の移行
- 設定データの移行

### Zero-Downtime Deployment
- Blue-Green deployment
- カナリアリリース
- ロールバック戦略

## 19. Service-Specific Test Strategy (サービス固有のテスト戦略)

### Overview
The avion-user service requires comprehensive testing strategies that focus on social graph operations, data consistency, and performance under high load. This section outlines testing approaches specific to user management, relationship handling, and social features.

### 19.1 Social Graph Operations Testing

#### Follow/Follower Relationship Management
Social relationship operations must handle concurrent requests, maintain data consistency, and prevent race conditions.

```go
// TestFollowUnfollowConcurrency tests concurrent follow/unfollow operations
func TestFollowUnfollowConcurrency(t *testing.T) {
    tests := []struct {
        name          string
        followerID    string
        followeeID    string
        operations    int
        expectedState bool
    }{
        {
            name:          "concurrent_follow_unfollow_even_operations",
            followerID:    "user1",
            followeeID:    "user2",
            operations:    100, // Even number should result in no follow
            expectedState: false,
        },
        {
            name:          "concurrent_follow_unfollow_odd_operations",
            followerID:    "user1",
            followeeID:    "user2",
            operations:    101, // Odd number should result in follow
            expectedState: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            ctx := context.Background()
            repo := setupTestRepository(t)
            usecase := NewFollowUseCase(repo)
            
            // Create test users
            createTestUser(t, repo, tt.followerID)
            createTestUser(t, repo, tt.followeeID)
            
            var wg sync.WaitGroup
            errChan := make(chan error, tt.operations)
            
            // Perform concurrent follow/unfollow operations
            for i := 0; i < tt.operations; i++ {
                wg.Add(1)
                go func(iteration int) {
                    defer wg.Done()
                    
                    var err error
                    if iteration%2 == 0 {
                        err = usecase.Follow(ctx, tt.followerID, tt.followeeID)
                    } else {
                        err = usecase.Unfollow(ctx, tt.followerID, tt.followeeID)
                    }
                    
                    if err != nil {
                        errChan <- err
                    }
                }(i)
            }
            
            wg.Wait()
            close(errChan)
            
            // Check for errors
            for err := range errChan {
                if !errors.Is(err, domain.ErrAlreadyFollowing) && 
                   !errors.Is(err, domain.ErrNotFollowing) {
                    t.Errorf("unexpected error: %v", err)
                }
            }
            
            // Verify final state
            isFollowing, err := repo.IsFollowing(ctx, tt.followerID, tt.followeeID)
            require.NoError(t, err)
            assert.Equal(t, tt.expectedState, isFollowing)
            
            // Verify follower/following counts
            followerCount, err := repo.GetFollowerCount(ctx, tt.followeeID)
            require.NoError(t, err)
            followingCount, err := repo.GetFollowingCount(ctx, tt.followerID)
            require.NoError(t, err)
            
            if tt.expectedState {
                assert.Equal(t, int64(1), followerCount)
                assert.Equal(t, int64(1), followingCount)
            } else {
                assert.Equal(t, int64(0), followerCount)
                assert.Equal(t, int64(0), followingCount)
            }
        })
    }
}

// TestMutualFollowDetection tests detection of mutual follows
func TestMutualFollowDetection(t *testing.T) {
    tests := []struct {
        name           string
        user1ID        string
        user2ID        string
        setupFollows   func(ctx context.Context, repo Repository)
        expectedMutual bool
    }{
        {
            name:    "mutual_follow_detected",
            user1ID: "user1",
            user2ID: "user2",
            setupFollows: func(ctx context.Context, repo Repository) {
                repo.CreateFollow(ctx, "user1", "user2")
                repo.CreateFollow(ctx, "user2", "user1")
            },
            expectedMutual: true,
        },
        {
            name:    "one_way_follow_not_mutual",
            user1ID: "user1",
            user2ID: "user2",
            setupFollows: func(ctx context.Context, repo Repository) {
                repo.CreateFollow(ctx, "user1", "user2")
            },
            expectedMutual: false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            ctx := context.Background()
            repo := setupTestRepository(t)
            usecase := NewRelationshipUseCase(repo)
            
            createTestUser(t, repo, tt.user1ID)
            createTestUser(t, repo, tt.user2ID)
            tt.setupFollows(ctx, repo)
            
            relationship, err := usecase.GetRelationship(ctx, tt.user1ID, tt.user2ID)
            require.NoError(t, err)
            
            assert.Equal(t, tt.expectedMutual, relationship.IsMutualFollow)
        })
    }
}
```

### 19.2 Block/Mute Propagation Testing

#### Cross-Service Block/Mute Cascade
Block and mute operations must propagate across services to ensure consistent user experience.

```go
// TestBlockCascadeAcrossServices tests block propagation to other services
func TestBlockCascadeAcrossServices(t *testing.T) {
    tests := []struct {
        name              string
        blockerID         string
        blockedID         string
        expectedEvents    []string
        expectedCascades  map[string]bool
    }{
        {
            name:      "block_cascades_to_timeline_and_notification",
            blockerID: "user1",
            blockedID: "user2",
            expectedEvents: []string{
                "user.blocked",
                "timeline.user_blocked",
                "notification.user_blocked",
            },
            expectedCascades: map[string]bool{
                "timeline_service":     true,
                "notification_service": true,
                "drop_service":        true,
            },
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            ctx := context.Background()
            
            // Setup mock event publisher
            eventPublisher := &mockEventPublisher{
                publishedEvents: make([]string, 0),
            }
            
            // Setup service cascades tracker
            cascadeTracker := &mockCascadeTracker{
                cascades: make(map[string]bool),
            }
            
            repo := setupTestRepository(t)
            usecase := NewBlockUseCase(repo, eventPublisher, cascadeTracker)
            
            createTestUser(t, repo, tt.blockerID)
            createTestUser(t, repo, tt.blockedID)
            
            err := usecase.BlockUser(ctx, tt.blockerID, tt.blockedID)
            require.NoError(t, err)
            
            // Verify events were published
            assert.ElementsMatch(t, tt.expectedEvents, eventPublisher.publishedEvents)
            
            // Verify cascade operations
            for service, expected := range tt.expectedCascades {
                actual, exists := cascadeTracker.cascades[service]
                assert.True(t, exists, "cascade not tracked for service %s", service)
                assert.Equal(t, expected, actual, "unexpected cascade state for service %s", service)
            }
            
            // Verify database state
            isBlocked, err := repo.IsBlocked(ctx, tt.blockerID, tt.blockedID)
            require.NoError(t, err)
            assert.True(t, isBlocked)
            
            // Verify automatic unfollow
            isFollowing, err := repo.IsFollowing(ctx, tt.blockerID, tt.blockedID)
            require.NoError(t, err)
            assert.False(t, isFollowing)
            
            isFollowingBack, err := repo.IsFollowing(ctx, tt.blockedID, tt.blockerID)
            require.NoError(t, err)
            assert.False(t, isFollowingBack)
        })
    }
}

// TestMuteDoesNotAffectFollowRelationship tests that muting preserves follows
func TestMuteDoesNotAffectFollowRelationship(t *testing.T) {
    ctx := context.Background()
    repo := setupTestRepository(t)
    usecase := NewMuteUseCase(repo, &mockEventPublisher{})
    
    muterID := "user1"
    mutedID := "user2"
    
    createTestUser(t, repo, muterID)
    createTestUser(t, repo, mutedID)
    
    // Establish follow relationship
    err := repo.CreateFollow(ctx, muterID, mutedID)
    require.NoError(t, err)
    
    err = repo.CreateFollow(ctx, mutedID, muterID)
    require.NoError(t, err)
    
    // Mute user
    err = usecase.MuteUser(ctx, muterID, mutedID)
    require.NoError(t, err)
    
    // Verify mute state
    isMuted, err := repo.IsMuted(ctx, muterID, mutedID)
    require.NoError(t, err)
    assert.True(t, isMuted)
    
    // Verify follow relationships are preserved
    isFollowing, err := repo.IsFollowing(ctx, muterID, mutedID)
    require.NoError(t, err)
    assert.True(t, isFollowing)
    
    isFollowingBack, err := repo.IsFollowing(ctx, mutedID, muterID)
    require.NoError(t, err)
    assert.True(t, isFollowingBack)
}
```

### 19.3 Profile Data Validation Testing

#### Custom Field Validation and Avatar Processing
Profile updates require comprehensive validation and media processing verification.

```go
// TestProfileCustomFieldsValidation tests custom profile fields validation
func TestProfileCustomFieldsValidation(t *testing.T) {
    tests := []struct {
        name          string
        customFields  map[string]string
        expectedError error
    }{
        {
            name: "valid_custom_fields",
            customFields: map[string]string{
                "website": "https://example.com",
                "location": "Tokyo, Japan",
                "bio": "Software Engineer",
            },
            expectedError: nil,
        },
        {
            name: "invalid_url_field",
            customFields: map[string]string{
                "website": "not-a-valid-url",
            },
            expectedError: domain.ErrInvalidCustomFieldValue,
        },
        {
            name: "field_too_long",
            customFields: map[string]string{
                "bio": strings.Repeat("a", 501), // Assuming 500 char limit
            },
            expectedError: domain.ErrCustomFieldTooLong,
        },
        {
            name: "too_many_fields",
            customFields: func() map[string]string {
                fields := make(map[string]string)
                for i := 0; i < 11; i++ { // Assuming 10 field limit
                    fields[fmt.Sprintf("field%d", i)] = "value"
                }
                return fields
            }(),
            expectedError: domain.ErrTooManyCustomFields,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            ctx := context.Background()
            repo := setupTestRepository(t)
            usecase := NewProfileUseCase(repo, &mockImageProcessor{})
            
            userID := "test_user"
            createTestUser(t, repo, userID)
            
            err := usecase.UpdateCustomFields(ctx, userID, tt.customFields)
            
            if tt.expectedError != nil {
                assert.ErrorIs(t, err, tt.expectedError)
            } else {
                assert.NoError(t, err)
                
                // Verify fields were saved correctly
                profile, err := repo.GetProfile(ctx, userID)
                require.NoError(t, err)
                assert.Equal(t, tt.customFields, profile.CustomFields)
            }
        })
    }
}

// TestAvatarImageProcessing tests avatar upload and processing pipeline
func TestAvatarImageProcessing(t *testing.T) {
    tests := []struct {
        name            string
        imageData       []byte
        contentType     string
        expectedSizes   []string
        expectedFormats []string
        shouldSucceed   bool
    }{
        {
            name:            "valid_jpeg_avatar",
            imageData:       generateTestJPEG(t, 1024, 1024),
            contentType:     "image/jpeg",
            expectedSizes:   []string{"32x32", "64x64", "128x128", "256x256"},
            expectedFormats: []string{"webp", "jpeg"},
            shouldSucceed:   true,
        },
        {
            name:            "valid_png_avatar",
            imageData:       generateTestPNG(t, 512, 512),
            contentType:     "image/png",
            expectedSizes:   []string{"32x32", "64x64", "128x128", "256x256"},
            expectedFormats: []string{"webp", "png"},
            shouldSucceed:   true,
        },
        {
            name:          "invalid_file_type",
            imageData:     []byte("not an image"),
            contentType:   "text/plain",
            shouldSucceed: false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            ctx := context.Background()
            
            imageProcessor := &mockImageProcessor{
                processedImages: make(map[string][]ProcessedImage),
            }
            
            repo := setupTestRepository(t)
            usecase := NewProfileUseCase(repo, imageProcessor)
            
            userID := "test_user"
            createTestUser(t, repo, userID)
            
            avatarURL, err := usecase.UpdateAvatar(ctx, userID, tt.imageData, tt.contentType)
            
            if tt.shouldSucceed {
                assert.NoError(t, err)
                assert.NotEmpty(t, avatarURL)
                
                // Verify image processing was called with correct parameters
                processed, exists := imageProcessor.processedImages[userID]
                assert.True(t, exists)
                
                // Verify expected sizes and formats were generated
                for _, size := range tt.expectedSizes {
                    found := false
                    for _, img := range processed {
                        if img.Size == size {
                            found = true
                            break
                        }
                    }
                    assert.True(t, found, "expected size %s not found", size)
                }
                
                // Verify profile was updated with new avatar URL
                profile, err := repo.GetProfile(ctx, userID)
                require.NoError(t, err)
                assert.Equal(t, avatarURL, profile.AvatarURL)
            } else {
                assert.Error(t, err)
                assert.Empty(t, avatarURL)
            }
        })
    }
}
```

### 19.4 Settings Synchronization Testing

#### Cross-Device Settings Sync and Export/Import
User settings must remain consistent across devices and support bulk operations.

```go
// TestSettingsSynchronization tests settings sync across multiple devices
func TestSettingsSynchronization(t *testing.T) {
    tests := []struct {
        name                string
        initialSettings     *domain.UserSettings
        device1Updates      *domain.UserSettings
        device2Updates      *domain.UserSettings
        expectedFinalState  *domain.UserSettings
    }{
        {
            name: "non_conflicting_updates",
            initialSettings: &domain.UserSettings{
                Language: "en",
                Theme:    "light",
                Privacy: &domain.PrivacySettings{
                    IsProfilePublic: true,
                },
            },
            device1Updates: &domain.UserSettings{
                Language: "ja", // Device 1 changes language
            },
            device2Updates: &domain.UserSettings{
                Theme: "dark", // Device 2 changes theme
            },
            expectedFinalState: &domain.UserSettings{
                Language: "ja",    // From device 1
                Theme:    "dark",  // From device 2
                Privacy: &domain.PrivacySettings{
                    IsProfilePublic: true, // Unchanged
                },
            },
        },
        {
            name: "conflicting_updates_last_write_wins",
            initialSettings: &domain.UserSettings{
                Language: "en",
                Theme:    "light",
            },
            device1Updates: &domain.UserSettings{
                Language: "ja",
                Theme:    "dark",
            },
            device2Updates: &domain.UserSettings{
                Language: "ko",  // Conflicts with device 1
                Theme:    "auto", // Conflicts with device 1
            },
            expectedFinalState: &domain.UserSettings{
                Language: "ko",   // Last write wins
                Theme:    "auto", // Last write wins
            },
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            ctx := context.Background()
            repo := setupTestRepository(t)
            syncService := &mockSettingsSyncService{
                syncedSettings: make(map[string]*domain.UserSettings),
            }
            usecase := NewSettingsUseCase(repo, syncService)
            
            userID := "test_user"
            createTestUser(t, repo, userID)
            
            // Set initial settings
            err := usecase.UpdateSettings(ctx, userID, tt.initialSettings)
            require.NoError(t, err)
            
            // Simulate concurrent updates from different devices
            var wg sync.WaitGroup
            
            wg.Add(1)
            go func() {
                defer wg.Done()
                time.Sleep(10 * time.Millisecond) // Slight delay
                err := usecase.UpdateSettings(ctx, userID, tt.device1Updates)
                assert.NoError(t, err)
            }()
            
            wg.Add(1)
            go func() {
                defer wg.Done()
                time.Sleep(20 * time.Millisecond) // Later update
                err := usecase.UpdateSettings(ctx, userID, tt.device2Updates)
                assert.NoError(t, err)
            }()
            
            wg.Wait()
            
            // Verify final state
            finalSettings, err := repo.GetUserSettings(ctx, userID)
            require.NoError(t, err)
            
            assert.Equal(t, tt.expectedFinalState.Language, finalSettings.Language)
            assert.Equal(t, tt.expectedFinalState.Theme, finalSettings.Theme)
            
            if tt.expectedFinalState.Privacy != nil {
                assert.Equal(t, tt.expectedFinalState.Privacy.IsProfilePublic, 
                           finalSettings.Privacy.IsProfilePublic)
            }
            
            // Verify sync service was called
            syncedSettings, exists := syncService.syncedSettings[userID]
            assert.True(t, exists)
            assert.NotNil(t, syncedSettings)
        })
    }
}

// TestSettingsExportImport tests bulk settings export and import functionality
func TestSettingsExportImport(t *testing.T) {
    ctx := context.Background()
    repo := setupTestRepository(t)
    usecase := NewSettingsUseCase(repo, &mockSettingsSyncService{})
    
    userID := "test_user"
    createTestUser(t, repo, userID)
    
    // Setup comprehensive settings
    originalSettings := &domain.UserSettings{
        Language: "ja",
        Timezone: "Asia/Tokyo",
        Theme:    "dark",
        Privacy: &domain.PrivacySettings{
            IsProfilePublic:     false,
            AllowDirectMessages: true,
            ShowOnlineStatus:    false,
        },
        Notifications: &domain.NotificationSettings{
            EmailNotifications: true,
            PushNotifications:  false,
            MentionNotifications: true,
        },
        Accessibility: &domain.AccessibilitySettings{
            HighContrast:    true,
            ReducedMotion:   false,
            LargeText:      true,
        },
    }
    
    err := usecase.UpdateSettings(ctx, userID, originalSettings)
    require.NoError(t, err)
    
    // Export settings
    exportedData, err := usecase.ExportSettings(ctx, userID)
    require.NoError(t, err)
    assert.NotEmpty(t, exportedData)
    
    // Clear settings (simulate new device/account)
    newUserID := "new_user"
    createTestUser(t, repo, newUserID)
    
    // Import settings
    err = usecase.ImportSettings(ctx, newUserID, exportedData)
    require.NoError(t, err)
    
    // Verify imported settings match original
    importedSettings, err := repo.GetUserSettings(ctx, newUserID)
    require.NoError(t, err)
    
    assert.Equal(t, originalSettings.Language, importedSettings.Language)
    assert.Equal(t, originalSettings.Timezone, importedSettings.Timezone)
    assert.Equal(t, originalSettings.Theme, importedSettings.Theme)
    assert.Equal(t, originalSettings.Privacy.IsProfilePublic, importedSettings.Privacy.IsProfilePublic)
    assert.Equal(t, originalSettings.Notifications.EmailNotifications, importedSettings.Notifications.EmailNotifications)
    assert.Equal(t, originalSettings.Accessibility.HighContrast, importedSettings.Accessibility.HighContrast)
}
```

### 19.5 Performance Testing

#### Large-Scale Graph Traversal Performance
Social graph operations must perform efficiently even with large datasets.

```go
// TestLargeScaleGraphTraversal tests performance with large social graphs
func TestLargeScaleGraphTraversal(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping performance test in short mode")
    }
    
    tests := []struct {
        name             string
        userCount        int
        followsPerUser   int
        maxTraversalTime time.Duration
    }{
        {
            name:             "medium_graph_1k_users",
            userCount:        1000,
            followsPerUser:   50,
            maxTraversalTime: 100 * time.Millisecond,
        },
        {
            name:             "large_graph_10k_users",
            userCount:        10000,
            followsPerUser:   100,
            maxTraversalTime: 500 * time.Millisecond,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            ctx := context.Background()
            repo := setupTestRepository(t)
            usecase := NewGraphTraversalUseCase(repo)
            
            // Create users and follows
            userIDs := setupLargeGraph(t, repo, tt.userCount, tt.followsPerUser)
            targetUserID := userIDs[0]
            
            // Test mutual follows discovery
            start := time.Now()
            mutualFollows, err := usecase.GetMutualFollows(ctx, targetUserID, userIDs[1])
            elapsed := time.Since(start)
            
            require.NoError(t, err)
            assert.True(t, elapsed < tt.maxTraversalTime, 
                       "mutual follows query took %v, expected < %v", elapsed, tt.maxTraversalTime)
            
            // Test follower recommendations
            start = time.Now()
            recommendations, err := usecase.GetFollowerRecommendations(ctx, targetUserID, 20)
            elapsed = time.Since(start)
            
            require.NoError(t, err)
            assert.True(t, elapsed < tt.maxTraversalTime,
                       "recommendations query took %v, expected < %v", elapsed, tt.maxTraversalTime)
            assert.LessOrEqual(t, len(recommendations), 20)
            
            // Test follower graph depth
            start = time.Now()
            followerGraph, err := usecase.GetFollowerGraph(ctx, targetUserID, 2) // 2 degrees
            elapsed = time.Since(start)
            
            require.NoError(t, err)
            assert.True(t, elapsed < tt.maxTraversalTime*2, // Allow 2x time for deeper traversal
                       "follower graph query took %v, expected < %v", elapsed, tt.maxTraversalTime*2)
            assert.NotEmpty(t, followerGraph)
        })
    }
}

// Benchmark for concurrent relationship operations
func BenchmarkConcurrentRelationshipOperations(b *testing.B) {
    ctx := context.Background()
    repo := setupTestRepository(b)
    usecase := NewRelationshipUseCase(repo)
    
    // Setup test users
    userCount := 1000
    userIDs := make([]string, userCount)
    for i := 0; i < userCount; i++ {
        userID := fmt.Sprintf("user_%d", i)
        userIDs[i] = userID
        createTestUser(b, repo, userID)
    }
    
    b.ResetTimer()
    
    b.RunParallel(func(pb *testing.PB) {
        for pb.Next() {
            followerID := userIDs[rand.Intn(userCount)]
            followeeID := userIDs[rand.Intn(userCount)]
            
            if followerID != followeeID {
                // Randomly follow or unfollow
                if rand.Float32() < 0.7 { // 70% follow, 30% unfollow
                    usecase.Follow(ctx, followerID, followeeID)
                } else {
                    usecase.Unfollow(ctx, followerID, followeeID)
                }
            }
        }
    })
}
```

### 19.6 Test Infrastructure and Utilities

#### Mock Services and Test Data Generation
Supporting infrastructure for comprehensive testing.

```go
// Mock implementations for testing
type mockEventPublisher struct {
    publishedEvents []string
    mu              sync.Mutex
}

func (m *mockEventPublisher) PublishEvent(ctx context.Context, event string, data interface{}) error {
    m.mu.Lock()
    defer m.mu.Unlock()
    m.publishedEvents = append(m.publishedEvents, event)
    return nil
}

type mockImageProcessor struct {
    processedImages map[string][]ProcessedImage
    mu              sync.Mutex
}

type ProcessedImage struct {
    Size   string
    Format string
    URL    string
}

func (m *mockImageProcessor) ProcessAvatar(ctx context.Context, userID string, imageData []byte) (string, error) {
    m.mu.Lock()
    defer m.mu.Unlock()
    
    sizes := []string{"32x32", "64x64", "128x128", "256x256"}
    processed := make([]ProcessedImage, 0, len(sizes))
    
    for _, size := range sizes {
        processed = append(processed, ProcessedImage{
            Size:   size,
            Format: "webp",
            URL:    fmt.Sprintf("https://cdn.example.com/avatars/%s_%s.webp", userID, size),
        })
    }
    
    m.processedImages[userID] = processed
    return fmt.Sprintf("https://cdn.example.com/avatars/%s_256x256.webp", userID), nil
}

// setupLargeGraph creates a large graph for performance testing
func setupLargeGraph(t testing.TB, repo Repository, userCount, followsPerUser int) []string {
    ctx := context.Background()
    userIDs := make([]string, userCount)
    
    // Create users
    for i := 0; i < userCount; i++ {
        userID := fmt.Sprintf("perf_user_%d", i)
        userIDs[i] = userID
        createTestUser(t, repo, userID)
    }
    
    // Create follow relationships
    for i, followerID := range userIDs {
        followCount := 0
        for j := 0; j < userCount && followCount < followsPerUser; j++ {
            if i != j { // Don't follow yourself
                followeeID := userIDs[j]
                err := repo.CreateFollow(ctx, followerID, followeeID)
                if err == nil {
                    followCount++
                }
            }
        }
    }
    
    return userIDs
}
```

### 19.7 Integration Test Scenarios

The test strategy includes comprehensive integration tests that verify end-to-end functionality:

- **Cross-service communication**: Verify that user blocks propagate to timeline and notification services
- **Event consistency**: Ensure all user events are properly published and consumed
- **Cache consistency**: Validate that Redis cache invalidation works correctly with database updates
- **Privacy inheritance**: Test that privacy settings properly affect visible data across services
- **Media processing pipeline**: Verify complete avatar/header image processing workflow
- **Verification badge management**: Test verification status changes and their system-wide effects

This comprehensive test strategy ensures the avion-user service maintains high reliability, performance, and data consistency while supporting the complex social features required by the platform.