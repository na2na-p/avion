# Design Doc: avion-community

**Author:** Claude Code
**Last Updated:** 2026/03/15

## 1. Summary (これは何？)

- **一言で:** Avionにおけるコミュニティ機能（グループ、トピック、協働スペース）の作成・管理・モデレーションを提供するマイクロサービスを実装します。
- **目的:** コミュニティデータの永続化、メンバーシップ管理、権限制御、トピック管理、モデレーション機能、イベント管理を提供します。他のサービス（Drop, Timeline, Notification等）へのコミュニティ関連イベント通知も行います。

## 2. テスト戦略

このサービスでは、[共通テスト戦略](../common/testing-strategy.md)に従ってテストを実装します。

### 2.1. テスト方針
- **TDD必須**: インターフェース定義 → テスト作成 → 実装の順序を厳守
- **カバレッジ目標**: ユニットテスト85%以上、クリティカルパス95%以上
- **テーブル駆動テスト**: 全テストで必須
- **モック生成**: `go.uber.org/mock/gomock`使用

### 2.2. E2Eテスト

このサービスのE2Eテストは、[共通E2Eテスト戦略](../common/e2e-testing-strategy.md)に従って実装します。

#### 主要なE2Eテストシナリオ
- コミュニティ作成から設定完了までの完全フロー
- メンバー招待・承認・除名機能の管理サイクル
- トピック作成とトピック管理機能
- コミュニティ内でのドロップ投稿と表示制御
- イベント作成・参加・管理機能の完全テスト
- ロール・権限設定とアクセス制御の確認
- プライベート/パブリックコミュニティの可視性制御
- 大規模コミュニティでの性能とスケーラビリティ確認

詳細は[共通E2Eテスト戦略ドキュメント](../common/e2e-testing-strategy.md)を参照してください。

詳細は[共通テスト戦略ドキュメント](../common/testing-strategy.md)を参照してください。

## 3. エラーハンドリング戦略

このサービスでは、[共通エラー標準化ガイドライン](../common/errors/error-standards.md)に従ってエラーハンドリングを実装します。

### 3.1. エラーコード体系

本サービスは、Avionプラットフォーム標準のエラーコード体系に準拠します。

- **命名規則**: `[SERVICE]_[LAYER]_[ERROR_TYPE]`形式
- **エラーカタログ**: [error-catalog.md](./error-catalog.md)
- **実装ガイド**: [共通エラー実装ガイド](../common/errors/implementation-guide.md)
- **標準仕様**: [エラーコード標準化ガイドライン](../common/errors/error-standards.md)

詳細なエラーコード定義とマッピングについては、上記のドキュメントを参照してください。
- サービスプレフィックス: `COMMUNITY`
- 命名規則: `[COMMUNITY]_[LAYER]_[ERROR_TYPE]`
- 例: `COMMUNITY_DOMAIN_NOT_FOUND`, `COMMUNITY_USECASE_UNAUTHORIZED`

### 3.2. エラーカタログ

#### Domain層エラー
```go
// Domain層エラー定義
var (
    ErrCommunityNotFound      = errors.New("COMMUNITY_DOMAIN_NOT_FOUND")
    ErrCommunityAlreadyExists = errors.New("COMMUNITY_DOMAIN_ALREADY_EXISTS")
    ErrMemberLimitExceeded    = errors.New("COMMUNITY_DOMAIN_MEMBER_LIMIT")
    ErrInvalidCommunityState  = errors.New("COMMUNITY_DOMAIN_INVALID_STATE")
    ErrEventConflict          = errors.New("COMMUNITY_DOMAIN_EVENT_CONFLICT")
    ErrMemberAlreadyExists    = errors.New("COMMUNITY_DOMAIN_MEMBER_EXISTS")
    ErrNotMember              = errors.New("COMMUNITY_DOMAIN_NOT_MEMBER")
    ErrPermissionDenied       = errors.New("COMMUNITY_DOMAIN_PERMISSION_DENIED")
    ErrInviteExpired          = errors.New("COMMUNITY_DOMAIN_INVITE_EXPIRED")
    ErrTopicLimitExceeded     = errors.New("COMMUNITY_DOMAIN_TOPIC_LIMIT_EXCEEDED")
    ErrInvalidRole            = errors.New("COMMUNITY_DOMAIN_INVALID_ROLE")
)
```

#### UseCase層エラー
```go
// UseCase層エラー定義
var (
    ErrUnauthorizedAccess = errors.New("COMMUNITY_USECASE_UNAUTHORIZED")
    ErrInvalidInput       = errors.New("COMMUNITY_USECASE_INVALID_INPUT")
    ErrQuotaExceeded      = errors.New("COMMUNITY_USECASE_QUOTA_EXCEEDED")
    ErrConflict           = errors.New("COMMUNITY_USECASE_CONFLICT")
    ErrPreconditionFailed = errors.New("COMMUNITY_USECASE_PRECONDITION_FAILED")
    ErrRateLimitExceeded  = errors.New("COMMUNITY_USECASE_RATE_LIMIT")
)
```

### 3.3. エラーコードマッピング

| エラーコード | gRPCステータス | 説明 | 対処法 |
|------------|--------------|------|--------|
| COMMUNITY_DOMAIN_NOT_FOUND | codes.NotFound | コミュニティが見つからない | コミュニティIDを確認してください |
| COMMUNITY_DOMAIN_ALREADY_EXISTS | codes.AlreadyExists | コミュニティが既に存在 | 別の名前を使用してください |
| COMMUNITY_DOMAIN_MEMBER_LIMIT | codes.ResourceExhausted | メンバー数上限到達 | コミュニティプランのアップグレードを検討してください |
| COMMUNITY_DOMAIN_INVALID_STATE | codes.FailedPrecondition | 不正な状態遷移 | 現在の状態を確認してください |
| COMMUNITY_DOMAIN_EVENT_CONFLICT | codes.Aborted | イベントスケジュールの競合 | 異なる時間帯を選択してください |
| COMMUNITY_DOMAIN_MEMBER_EXISTS | codes.AlreadyExists | 既にメンバーである | 既存のメンバーシップを確認してください |
| COMMUNITY_DOMAIN_NOT_MEMBER | codes.PermissionDenied | メンバーではない | コミュニティへの参加が必要です |
| COMMUNITY_DOMAIN_PERMISSION_DENIED | codes.PermissionDenied | 権限がない | 必要なロールを確認してください |
| COMMUNITY_DOMAIN_INVITE_EXPIRED | codes.DeadlineExceeded | 招待の有効期限切れ | 新しい招待をリクエストしてください |
| COMMUNITY_DOMAIN_TOPIC_LIMIT_EXCEEDED | codes.ResourceExhausted | トピック数上限到達 | 不要なトピックをアーカイブしてください |
| COMMUNITY_DOMAIN_INVALID_ROLE | codes.InvalidArgument | 無効なロール指定 | 有効なロールを指定してください |
| COMMUNITY_USECASE_UNAUTHORIZED | codes.Unauthenticated | 認証エラー | ログインしてください |
| COMMUNITY_USECASE_INVALID_INPUT | codes.InvalidArgument | 入力値が不正 | リクエストパラメータを確認してください |
| COMMUNITY_USECASE_QUOTA_EXCEEDED | codes.ResourceExhausted | クォータ制限超過 | しばらく待ってから再試行してください |
| COMMUNITY_USECASE_CONFLICT | codes.Aborted | 競合状態 | 操作を再試行してください |
| COMMUNITY_USECASE_PRECONDITION_FAILED | codes.FailedPrecondition | 事前条件違反 | 必要な前提条件を満たしてください |
| COMMUNITY_USECASE_RATE_LIMIT | codes.ResourceExhausted | レート制限超過 | しばらく待ってから再試行してください |

詳細は[共通エラー標準化ガイドライン](../common/errors/error-standards.md)を参照してください。

## 4. 構造化ログ戦略

このサービスでは、[共通Observabilityパッケージ設計](../common/observability/observability-package-design.md)に従って構造化ログを実装します。

### 4.1. ログレベル定義
- `DEBUG`: 開発時の詳細情報
- `INFO`: 正常な処理フロー（コミュニティ作成、メンバー追加等）
- `WARN`: 予期された異常（権限不足、メンバー上限等）
- `ERROR`: 予期しないエラー（DB接続失敗等）
- `CRITICAL`: システム停止レベルの重大エラー

### 4.2. 標準フィールド
```json
{
  "timestamp": "2025-08-15T10:00:00Z",
  "level": "INFO",
  "service": "avion-community",
  "trace_id": "123e4567-e89b-12d3-a456-426614174000",
  "span_id": "7891011",
  "user_id": "user_123",
  "community_id": "com_456",
  "layer": "usecase",
  "method": "CreateCommunity",
  "duration_ms": 45,
  "message": "Community created successfully"
}
```

詳細は[共通Observabilityパッケージ設計](../common/observability/observability-package-design.md)を参照してください。

## 5. 技術スタック

このサービスでは、[共通Goバックエンド技術スタックガイドライン](../common/architecture/go-backend-framework.md)に従った実装を行います。

### 5.1. 主要技術
- **言語:** Go 1.25.1
- **データベース:** PostgreSQL 17
- **キャッシュ/メッセージング:** Redis 8+
- **イベント配信:** NATS JetStream
- **HTTPルーティング:** Chi v5
- **RPC:** ConnectRPC
- **ミドルウェア:** 標準net/httpベースの共通ミドルウェア
- **ID生成:** UUID v7 (RFC 9562準拠)

詳細な実装パターンおよびライブラリの使用方法については、[ガイドライン](../common/architecture/go-backend-framework.md)を参照してください。

## 6. Configuration Management (設定管理)

このサービスでは、[共通環境変数管理パターン](../common/infrastructure/environment-variables.md)に従って設定管理を実装します。

### 6.1. Environment Variables (環境変数)

#### Required Variables (必須環境変数)
- `DATABASE_URL`: PostgreSQL接続URL
- `REDIS_URL`: Redis接続URL

#### Optional Variables (オプション環境変数)
- `PORT`: HTTPサーバーポート (default: 8091)
- `GRPC_PORT`: gRPCサーバーポート (default: 9101)
- `MAX_COMMUNITY_SIZE`: コミュニティの最大メンバー数 (default: 10000)
- `MAX_EVENT_PARTICIPANTS`: イベントの最大参加者数 (default: 1000)
- `TOPIC_POST_RETENTION`: トピック内投稿の保持期間 (default: 30d)

### 6.2. Config Struct Implementation (設定構造体実装)

```go
// internal/infrastructure/config/config.go
package config

import "time"

type Config struct {
    Server      ServerConfig
    Database    DatabaseConfig
    Redis       RedisConfig
    Community   CommunityConfig
    Logging     LoggingConfig
}

type ServerConfig struct {
    Port     int `env:"PORT" required:"false" default:"8091"`
    GRPCPort int `env:"GRPC_PORT" required:"false" default:"9101"`
}

type DatabaseConfig struct {
    URL string `env:"DATABASE_URL" required:"true"`
}

type RedisConfig struct {
    URL string `env:"REDIS_URL" required:"true"`
}

type CommunityConfig struct {
    MaxCommunitySize      int           `env:"MAX_COMMUNITY_SIZE" required:"false" default:"10000"`
    MaxEventParticipants  int           `env:"MAX_EVENT_PARTICIPANTS" required:"false" default:"1000"`
    TopicPostRetention time.Duration `env:"TOPIC_POST_RETENTION" required:"false" default:"720h"` // 30 days
}

type LoggingConfig struct {
    Level string `env:"LOG_LEVEL" required:"false" default:"info"`
}
```

### 6.3. Configuration Loading (設定読み込み)

設定の読み込みと検証は、サービス起動時に実行され、必須環境変数が不足している場合は早期失敗（Fail Fast）します。

```go
func LoadConfig() (*Config, error) {
    loader := NewDefaultEnvironmentLoader()
    config := &Config{}
    
    if err := LoadFromEnvironment(loader, config); err != nil {
        return nil, fmt.Errorf("failed to load configuration: %w", err)
    }
    
    if err := ValidateConfig(config); err != nil {
        return nil, fmt.Errorf("configuration validation failed: %w", err)
    }
    
    return config, nil
}

func ValidateConfig(config *Config) error {
    if config.Community.MaxCommunitySize <= 0 {
        return ErrInvalidMaxCommunitySize
    }
    if config.Community.MaxEventParticipants <= 0 {
        return ErrInvalidMaxEventParticipants
    }
    if config.Community.TopicPostRetention <= 0 {
        return ErrInvalidTopicPostRetention
    }
    return nil
}
```

## 7. Background & Links (背景と関連リンク)

- コミュニティ機能により、ユーザーが興味・目的別のグループを形成し、より深い交流を実現するため。
- Discord的なサーバー機能やRedditのsubreddit的な機能を提供し、プラットフォームの価値を向上させる。
- マイクロサービスアーキテクチャにおいて、コミュニティ関連機能を独立させることで、拡張性とメンテナンス性を確保する。
- [PRD: avion-community](./prd.md)
- [Avion アーキテクチャ概要](../common/architecture.md)

## 8. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

#### コミュニティ固有モデレーション（ローカルルール）の責務

本サービスは **コミュニティ固有のモデレーション** を担当し、以下の責務を持つ:

- **コミュニティ独自ルールの定義・適用**: コミュニティオーナー・モデレーターが設定するキーワードフィルタ、行動ルール等のローカルルール管理
- **コミュニティモデレーターの管理**: コミュニティ内のモデレーター任命・解任、権限設定
- **メンバーのsuspend/ban（コミュニティスコープ）**: コミュニティローカルルール違反に対するメンバー一時停止・追放処理
- **トピックの承認制管理**: トピックへの投稿に対する承認フロー、コンテンツ管理

#### グローバルルールとの関係

- **判定順序**: ローカルルール判定 → avion-moderation のグローバルルール判定の順で実行される
- **グローバルルール違反はローカルルールで上書き不可**: プラットフォーム全体ポリシー（法的要件、利用規約等）に違反するコンテンツは、コミュニティのローカルルール設定に関係なく除去される
- **コミュニティモデレーターの権限範囲**: コミュニティモデレーターはグローバルポリシーの範囲内でのみ権限を持つ。グローバルポリシーを緩和・無効化することはできない

#### 機能実装

- コミュニティのCRUD操作を行うgRPC APIの実装
- メンバーシップ管理（参加・退会・役割変更・モデレーション）のgRPC API実装
- トピック管理のgRPC API実装
- コミュニティルール・モデレーション機能のAPI実装
- イベント機能のCRUD API実装
- 招待システム（招待コード生成・使用）のAPI実装
- 権限・役割システムの実装
- コミュニティデータのPostgreSQLへの永続化
- 統計情報・キャッシュのRedis活用
- コミュニティ関連イベントの発行（NATS JetStream）による他サービスとの連携
- 公開範囲に基づくアクセス制御
- Go言語で実装し、Kubernetes上でのステートレス運用を前提
- OpenTelemetryによるトレーシング・メトリクス・ログ出力

### Non-Goals (やらないこと)

- **リアルタイムチャット機能:** 将来的な拡張として、初期実装では対象外
- **ファイル共有・ストレージ機能:** `avion-media` が担当
- **ビデオ・音声通話:** リアルタイムコミュニケーション機能は対象外
- **外部SNS連携:** Twitter、Discord等との直接連携は対象外
- **高度なBI・分析機能:** 専門の分析サービスが担当
- **AIコンテンツ生成:** AI機能は対象外
- **投稿ピン留めの実体管理:** `avion-drop` が担当（コミュニティはピン留め指示のみ）
- **プラットフォーム全体のモデレーションポリシー:** `avion-moderation` が担当
- **グローバルスパム検出:** `avion-moderation` が担当

> **サービス間責務境界（決定済み）**: (1) モデレーション階層構造: 本サービスの `AutoModerationRule` はコミュニティローカルのルール（コミュニティオーナーが設定するキーワードフィルタ等）のみを管理する。`avion-moderation` のプラットフォーム全体ポリシーが常に優先される。コミュニティ内コンテンツフィルタリングは `avion-moderation` が非同期イベント検査で実行する。(2) コミュニティ内投稿はDropと同一モデル。本サービスはDropとTopic/Communityの関連付けのみ管理する。Topic別タイムラインは `avion-timeline` に委譲する。
- **イベントリマインダーの実送信:** `avion-notification` が担当

## 9. Architecture (どうやって作る？)

### 9.0. avion-moderation との連携フロー（モデレーション責務境界）

本サービス（ローカルルール）と avion-moderation（グローバルルール）は以下のフローで連携する:

1. **コンテンツ投稿時**: 本サービス（avion-community）がコミュニティ固有のローカルルール判定を実行
2. **ローカルルール違反なし → グローバルルール判定**: avion-moderation が非同期でプラットフォーム全体のグローバルルール判定を実行（`DropCreatedEvent` 等のイベント駆動）
3. **グローバルルール違反検知 → 即座にコンテンツ除去**: コミュニティのローカルルール設定に関係なく、法的要件・プラットフォーム利用規約違反コンテンツは即座に除去される
4. **通報時**: 本サービスのコミュニティモデレーターが最初に確認 → コミュニティスコープで解決できない場合やグローバルポリシー違反が疑われる場合は avion-moderation へエスカレーション

```
┌─────────────────────────────────────────────────────────┐
│                   コンテンツ投稿                         │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│  avion-community: ローカルルール判定                     │
│  (コミュニティ固有のキーワードフィルタ等)                  │
└─────────────────────┬───────────────────────────────────┘
                      │ 違反なし
                      ▼
┌─────────────────────────────────────────────────────────┐
│  avion-moderation: グローバルルール判定（非同期）          │
│  (法的要件、利用規約、スパム検知、ML分類)                  │
└─────────────────────┬───────────────────────────────────┘
                      │ 違反検知
                      ▼
┌─────────────────────────────────────────────────────────┐
│  即座にコンテンツ除去・制裁実行                           │
│  (ローカルルール設定に関係なく強制)                       │
└─────────────────────────────────────────────────────────┘
```

```
┌─────────────────────────────────────────────────────────┐
│                    通報受付                              │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│  avion-community: コミュニティモデレーターが確認          │
│  (コミュニティローカルスコープでの対応)                   │
└─────────────────────┬───────────────────────────────────┘
                      │ エスカレーション
                      ▼
┌─────────────────────────────────────────────────────────┐
│  avion-moderation: グローバルスコープでの通報処理         │
│  (プラットフォーム全体ポリシーに基づく判定)               │
└─────────────────────────────────────────────────────────┘
```

### 9.1. レイヤードアーキテクチャ (DDD準拠)

#### Domain Layer (ドメイン層)
- **Aggregates:**
  - Community: コミュニティのライフサイクルと基本設定を管理
  - Membership: コミュニティへの参加状態と役割を管理
  - Topic: コミュニティ内のトピックを管理
  - CommunityRule: コミュニティのルールとモデレーションポリシーを管理
  - CommunityInvitation: コミュニティへの招待を管理
  - CommunityEvent: コミュニティイベントとスケジュールを管理
  - ModerationAppeal: モデレーション処理への異議申し立てを管理
- **Entities:**
  - Community: コミュニティの主体
  - Membership: メンバーシップ情報
  - MembershipRole: カスタム役割定義
  - Topic: トピック
  - CommunityRule: コミュニティルール
  - CommunityModerationLog: モデレーションログ
  - CommunityInvitation: 招待情報
  - CommunityEvent: イベント情報
  - EventParticipant: イベント参加者
  - CommunityStatistics: 統計情報キャッシュ
  - CommunityTemplate: コミュニティテンプレート設定
  - AutoModerationRule: 自動モデレーション設定
  - ModerationAppealRecord: 異議申し立て記録
- **Value Objects:**
  - CommunityID, MembershipID, TopicID, InviteCode, EventID
  - CommunityName, CommunityDescription, CommunityVisibility
  - MembershipStatus, MembershipRole, MemberPermissions
  - TopicName, TopicType, TopicVisibility
  - EventTitle, EventDescription, EventStatus, EventDateTime
- **Domain Services:**
  - CommunityPermissionService: 権限チェックと認可処理
  - CommunityDiscoveryService: コミュニティ発見と推薦
  - CommunityModerationService: モデレーション処理支援

#### Use Case Layer (ユースケース層)
- **Command Use Cases:**
  - CreateCommunityCommandUseCase
  - UpdateCommunityCommandUseCase
  - DeleteCommunityCommandUseCase
  - TransferOwnershipCommandUseCase
  - JoinCommunityCommandUseCase
  - LeaveCommunityCommandUseCase
  - ChangeRoleCommandUseCase
  - SuspendMemberCommandUseCase
  - BulkMembershipCommandUseCase
  - CreateTopicCommandUseCase
  - UpdateTopicCommandUseCase
  - DeleteTopicCommandUseCase
  - CreateRuleCommandUseCase
  - UpdateRuleCommandUseCase
  - CreateInvitationCommandUseCase
  - UseInvitationCommandUseCase
  - RevokeInvitationCommandUseCase
  - CreateEventCommandUseCase
  - UpdateEventCommandUseCase
  - JoinEventCommandUseCase
  - LeaveEventCommandUseCase
  - AppealModerationCommandUseCase
  - ExportCommunityDataCommandUseCase
- **Query Use Cases:**
  - GetCommunityQueryUseCase
  - SearchCommunitiesQueryUseCase
  - GetCommunityMembersQueryUseCase
  - GetMembershipQueryUseCase
  - GetTopicsQueryUseCase
  - GetTopicQueryUseCase
  - GetRulesQueryUseCase
  - GetInvitationsQueryUseCase
  - GetEventsQueryUseCase
  - GetEventQueryUseCase
  - GetCommunityStatsQueryUseCase
- **Query Service Interfaces:**
  - CommunityQueryService
  - MembershipQueryService
  - TopicQueryService
  - CommunityRuleQueryService
  - CommunityInvitationQueryService
  - CommunityEventQueryService
- **External Service Interfaces:**
  - UserService (ユーザー情報取得)
  - NotificationService (通知送信)
  - MediaService (画像・ファイル管理)

#### Infrastructure Layer (インフラ層)
- **Repository Implementations:**
  - PostgresCommunityRepository
  - PostgresMembershipRepository
  - PostgresTopicRepository
  - PostgresCommunityRuleRepository
  - PostgresCommunityInvitationRepository
  - PostgresCommunityEventRepository
- **External Service Clients:**
  - gRPCUserServiceClient
  - gRPCNotificationServiceClient
  - gRPCMediaServiceClient
  - gRPCModerationServiceClient（エスカレーション用）
- **Event Publishers:**
  - NATSEventPublisher
- **Cache Services:**
  - RedisPermissionCacheService
  - RedisCommunityStatsService

#### Handler Layer (ハンドラー層)
- **gRPC Handlers:**
  - CommunityServiceHandler
  - MembershipServiceHandler
  - TopicServiceHandler
  - RuleServiceHandler
  - InvitationServiceHandler
  - EventServiceHandler

### 9.2. データベース設計

#### PostgreSQL テーブル設計

```sql
-- コミュニティテーブル
CREATE TABLE communities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- UUID v7 (Backend採番)
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    avatar_url VARCHAR(500),
    header_url VARCHAR(500),
    visibility VARCHAR(20) NOT NULL CHECK (visibility IN ('public', 'private', 'invite_only')),
    category VARCHAR(50) NOT NULL,
    owner_user_id UUID NOT NULL,
    member_count INTEGER DEFAULT 0,
    is_archived BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    version INTEGER DEFAULT 1
);

-- メンバーシップテーブル
CREATE TABLE memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- UUID v7 (Backend採番)
    community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('active', 'pending', 'suspended', 'banned', 'left')),
    role VARCHAR(30) NOT NULL DEFAULT 'member',
    custom_role_id UUID REFERENCES membership_roles(id),
    permissions BIGINT DEFAULT 0, -- ビットマスク
    joined_at TIMESTAMP WITH TIME ZONE,
    suspended_until TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    UNIQUE(community_id, user_id)
);

-- カスタム役割テーブル
CREATE TABLE membership_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- UUID v7 (Backend採番)
    community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    name VARCHAR(20) NOT NULL,
    color VARCHAR(7), -- HEX color
    permissions BIGINT NOT NULL DEFAULT 0,
    is_default BOOLEAN DEFAULT FALSE,
    display_order INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    UNIQUE(community_id, name)
);

-- トピックテーブル
CREATE TABLE topics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- UUID v7 (Backend採番)
    community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    name VARCHAR(30) NOT NULL,
    description TEXT,
    topic_type VARCHAR(20) NOT NULL DEFAULT 'general',
    visibility VARCHAR(20) NOT NULL DEFAULT 'public',
    required_role VARCHAR(30),
    display_order INTEGER NOT NULL,
    is_archived BOOLEAN DEFAULT FALSE,
    created_by_user_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    UNIQUE(community_id, name)
);

-- 自動モデレーションルールテーブル
CREATE TABLE auto_moderation_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- UUID v7 (Backend採番)
    community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    rule_name VARCHAR(100) NOT NULL,
    rule_type VARCHAR(50) NOT NULL, -- keyword, pattern, behavior
    rule_pattern TEXT,
    action VARCHAR(50) NOT NULL, -- warn, delete, suspend
    is_active BOOLEAN DEFAULT TRUE,
    created_by_user_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- モデレーション異議申し立てテーブル
CREATE TABLE moderation_appeals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- UUID v7 (Backend採番)
    community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    moderation_log_id UUID NOT NULL REFERENCES community_moderation_logs(id),
    appealer_user_id UUID NOT NULL,
    appeal_reason TEXT NOT NULL,
    appeal_status VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending, accepted, rejected
    reviewed_by_user_id UUID,
    review_comment TEXT,
    appealed_at TIMESTAMP WITH TIME ZONE NOT NULL,
    reviewed_at TIMESTAMP WITH TIME ZONE
);

-- コミュニティテンプレートテーブル
CREATE TABLE community_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- UUID v7 (Backend採番)
    template_name VARCHAR(100) NOT NULL,
    template_type VARCHAR(50) NOT NULL, -- gaming, education, business, etc
    default_rules JSONB,
    default_topics JSONB,
    default_roles JSONB,
    is_public BOOLEAN DEFAULT TRUE,
    created_by_user_id UUID,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- コミュニティルールテーブル
CREATE TABLE community_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- UUID v7 (Backend採番)
    community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    rule_number INTEGER NOT NULL,
    title VARCHAR(100) NOT NULL,
    description TEXT NOT NULL,
    enforcement VARCHAR(20) NOT NULL CHECK (enforcement IN ('warning', 'temp_suspend', 'permanent_ban')),
    is_active BOOLEAN DEFAULT TRUE,
    created_by_user_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    UNIQUE(community_id, rule_number)
);

-- モデレーションログテーブル
CREATE TABLE community_moderation_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- UUID v7 (Backend採番)
    community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    moderator_user_id UUID NOT NULL,
    target_user_id UUID NOT NULL,
    action_type VARCHAR(50) NOT NULL,
    reason TEXT NOT NULL,
    evidence TEXT,
    rule_id UUID REFERENCES community_rules(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- 招待テーブル
CREATE TABLE community_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- UUID v7 (Backend採番)
    community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    invite_code VARCHAR(50) NOT NULL UNIQUE,
    created_by_user_id UUID NOT NULL,
    max_usage INTEGER DEFAULT -1, -- -1 は無制限
    usage_count INTEGER DEFAULT 0,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- 招待使用履歴テーブル
CREATE TABLE invitation_usages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- UUID v7 (Backend採番)
    invitation_id UUID NOT NULL REFERENCES community_invitations(id) ON DELETE CASCADE,
    used_by_user_id UUID NOT NULL,
    used_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- イベントテーブル
CREATE TABLE community_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- UUID v7 (Backend採番)
    community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    title VARCHAR(100) NOT NULL,
    description TEXT,
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE NOT NULL,
    max_participants INTEGER DEFAULT -1, -- -1 は無制限
    participant_count INTEGER DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'scheduled',
    created_by_user_id UUID NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- イベント参加者テーブル
CREATE TABLE event_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- UUID v7 (Backend採番)
    event_id UUID NOT NULL REFERENCES community_events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    participant_status VARCHAR(20) NOT NULL DEFAULT 'confirmed',
    rsvp VARCHAR(10), -- yes, no, maybe
    joined_at TIMESTAMP WITH TIME ZONE NOT NULL,
    UNIQUE(event_id, user_id)
);

-- コミュニティ統計テーブル（キャッシュ）
CREATE TABLE community_statistics (
    community_id UUID PRIMARY KEY REFERENCES communities(id) ON DELETE CASCADE,
    member_count INTEGER DEFAULT 0,
    active_member_count INTEGER DEFAULT 0,
    post_count INTEGER DEFAULT 0,
    topic_count INTEGER DEFAULT 0,
    event_count INTEGER DEFAULT 0,
    last_activity_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);
```

#### インデックス設計

```sql
-- コミュニティ関連
CREATE INDEX idx_communities_category ON communities(category);
CREATE INDEX idx_communities_owner ON communities(owner_user_id);
CREATE INDEX idx_communities_visibility ON communities(visibility);
CREATE INDEX idx_communities_created_at ON communities(created_at DESC);

-- メンバーシップ関連
CREATE INDEX idx_memberships_community_status ON memberships(community_id, status);
CREATE INDEX idx_memberships_user_id ON memberships(user_id);
CREATE INDEX idx_memberships_joined_at ON memberships(joined_at DESC);

-- トピック関連
CREATE INDEX idx_topics_community_id ON topics(community_id, display_order);
CREATE INDEX idx_topics_created_by ON topics(created_by_user_id);

-- 自動モデレーション関連
CREATE INDEX idx_auto_moderation_community ON auto_moderation_rules(community_id);
CREATE INDEX idx_auto_moderation_active ON auto_moderation_rules(is_active);

-- 異議申し立て関連
CREATE INDEX idx_appeals_community ON moderation_appeals(community_id);
CREATE INDEX idx_appeals_status ON moderation_appeals(appeal_status);
CREATE INDEX idx_appeals_appealer ON moderation_appeals(appealer_user_id);

-- イベント関連
CREATE INDEX idx_events_community_time ON community_events(community_id, start_time);
CREATE INDEX idx_events_status ON community_events(status);

-- モデレーション関連
CREATE INDEX idx_moderation_logs_community ON community_moderation_logs(community_id, created_at DESC);
CREATE INDEX idx_moderation_logs_target ON community_moderation_logs(target_user_id);
```

### 9.3. Redis キャッシュ設計

#### 権限キャッシュ
```
# ユーザーのコミュニティ権限
HSET user:permissions:{user_id}:{community_id} 
  role "moderator"
  permissions "1023" # ビットマスク
  expires_at "1672531200"

# コミュニティメンバー一覧（軽量版）
ZSET community:members:{community_id} 
  {user_id} {joined_timestamp}
```

#### 統計情報キャッシュ
```
# コミュニティ統計
HSET community:stats:{community_id}
  member_count "1500"
  active_member_count "450"
  post_count "12000"
  topic_count "25"

# 人気コミュニティ（カテゴリ別）
ZSET trending:communities:{category}
  {community_id} {popularity_score}
```

### 9.4. イベント設計

#### 発行イベント（NATS JetStream）

```json
// avion.community.group.created
{
  "event_type": "avion.community.group.created",
  "community_id": "123456789012345678",
  "owner_user_id": "987654321098765432",
  "community_name": "Tech Discussions",
  "category": "technology",
  "visibility": "public",
  "created_at": "2025-08-06T10:30:00Z"
}

// avion.community.group.updated (visibility changed)
{
  "event_type": "avion.community.group.updated",
  "community_id": "123456789012345678",
  "old_visibility": "public",
  "new_visibility": "private",
  "changed_by_user_id": "987654321098765432",
  "changed_at": "2025-08-06T10:32:00Z"
}

// avion.community.group.updated (owner transferred)
{
  "event_type": "avion.community.group.updated",
  "community_id": "123456789012345678",
  "old_owner_user_id": "987654321098765432",
  "new_owner_user_id": "555666777888999000",
  "transferred_at": "2025-08-06T10:33:00Z"
}

// avion.community.member.joined
{
  "event_type": "avion.community.member.joined",
  "community_id": "123456789012345678",
  "user_id": "555666777888999000",
  "membership_status": "active",
  "role": "member",
  "joined_at": "2025-08-06T10:35:00Z"
}

// avion.community.member.promoted
{
  "event_type": "avion.community.member.promoted",
  "community_id": "123456789012345678",
  "user_id": "555666777888999000",
  "old_role": "member",
  "new_role": "moderator",
  "promoted_by_user_id": "987654321098765432",
  "promoted_at": "2025-08-06T10:36:00Z"
}

// avion.community.member.demoted
{
  "event_type": "avion.community.member.demoted",
  "community_id": "123456789012345678",
  "user_id": "555666777888999000",
  "old_role": "moderator",
  "new_role": "member",
  "demoted_by_user_id": "987654321098765432",
  "reason": "Inactive moderation",
  "demoted_at": "2025-08-06T10:37:00Z"
}

// avion.community.topic.created
{
  "event_type": "avion.community.topic.created",
  "community_id": "123456789012345678",
  "topic_id": "234567890123456789",
  "topic_name": "General Discussion",
  "created_by_user_id": "555666777888999000",
  "created_at": "2025-08-06T10:40:00Z"
}

// avion.community.topic.updated (visibility changed)
{
  "event_type": "avion.community.topic.updated",
  "community_id": "123456789012345678",
  "topic_id": "234567890123456789",
  "old_visibility": "public",
  "new_visibility": "restricted",
  "changed_by_user_id": "555666777888999000",
  "changed_at": "2025-08-06T10:42:00Z"
}

// avion.community.invitation.revoked
{
  "event_type": "avion.community.invitation.revoked",
  "community_id": "123456789012345678",
  "invitation_id": "345678901234567890",
  "invite_code": "ABC123XYZ",
  "revoked_by_user_id": "987654321098765432",
  "revoked_at": "2025-08-06T10:43:00Z"
}

// avion.community.event.started
{
  "event_type": "avion.community.event.started",
  "community_id": "123456789012345678",
  "event_id": "456789012345678901",
  "event_title": "Weekly Meetup",
  "started_at": "2025-08-06T10:44:00Z"
}

// avion.community.event.completed
{
  "event_type": "avion.community.event.completed",
  "community_id": "123456789012345678",
  "event_id": "456789012345678901",
  "event_title": "Weekly Meetup",
  "participant_count": 25,
  "completed_at": "2025-08-06T11:44:00Z"
}

// avion.community.event.cancelled
{
  "event_type": "avion.community.event.cancelled",
  "community_id": "123456789012345678",
  "event_id": "456789012345678901",
  "event_title": "Monthly Review",
  "cancelled_by_user_id": "987654321098765432",
  "cancellation_reason": "Schedule conflict",
  "cancelled_at": "2025-08-06T10:45:00Z"
}

// avion.community.rule.violated
{
  "event_type": "avion.community.rule.violated",
  "community_id": "123456789012345678",
  "violator_user_id": "111222333444555666",
  "rule_id": "567890123456789012",
  "rule_title": "No spam",
  "violation_content": "[Content ID]",
  "detected_at": "2025-08-06T10:46:00Z",
  "detection_method": "auto_moderation"
}

// avion.community.member.suspended
{
  "event_type": "avion.community.member.suspended",
  "community_id": "123456789012345678",
  "target_user_id": "111222333444555666",
  "moderator_user_id": "555666777888999000",
  "action_type": "temp_suspend",
  "reason": "Rule violation: inappropriate behavior",
  "suspended_until": "2025-08-13T10:45:00Z",
  "created_at": "2025-08-06T10:45:00Z"
}

// avion.community.appeal.created
{
  "event_type": "avion.community.appeal.created",
  "community_id": "123456789012345678",
  "appeal_id": "678901234567890123",
  "appealer_user_id": "111222333444555666",
  "moderation_log_id": "789012345678901234",
  "appeal_reason": "Misunderstanding of context",
  "appealed_at": "2025-08-06T10:47:00Z"
}
```

## 10. データベースマイグレーション

このサービスでは、[共通マイグレーション戦略](../common/database-migration-strategy.md)に従って、Gooseを使用したマイグレーション管理を行います。

### マイグレーション戦略

- **ツール**: Goose v3
- **ディレクトリ**: `./migrations/`
- **命名規則**: `[sequence_number]_[description].sql`
- **実行方法**: `make migrate-up` / `make migrate-down`

### avion-community固有の考慮事項

- **コミュニティメンバー関係**: グループ・イベント・トピックのメンバーシップデータを正確に移行
- **権限継承**: コミュニティ内の管理者・モデレータ権限を適切に継承
- **イベントスケジュール保持**: 予定されているイベントの日時・参加者情報を保護
- **コミュニティ設定維持**: プライベート設定やカスタムルールを完全に移行
- **関連コンテンツ整合性**: コミュニティ内のDrops・メディアとの関連性を保証

### 標準テンプレート参照

マイグレーションファイル作成時は[マイグレーション設定テンプレート](../templates/migration-setup-template.md)を参照してください。

## 11. Use Cases / Key Flows (主な使い方・処理の流れ)

- **フロー 1: コミュニティ作成 (Command)**
    1. Gateway → CreateCommunityCommandHandler: `CreateCommunity` gRPC Call (name, description, visibility, category, Metadata: X-User-ID, Trace Context)
    2. CreateCommunityCommandHandler: CreateCommunityCommandUseCaseを呼び出し
    3. CreateCommunityCommandUseCase: Community Aggregateを生成し、CommunityDomainServiceでビジネスルール検証（名前重複チェック）
    4. CreateCommunityCommandUseCase: CommunityRepositoryを通じてCommunity Aggregateを永続化
    5. CreateCommunityCommandUseCase: MembershipRepositoryを通じて作成者をOwnerとして自動参加
    6. CreateCommunityCommandUseCase: EventPublisherを通じて `avion.community.group.created` イベントを発行
    7. CreateCommunityCommandHandler → Gateway: `CreateCommunityResponse { community_id: "..." }`

- **フロー 2: コミュニティ参加 (Command)**
    1. Gateway → JoinCommunityCommandHandler: `JoinCommunity` gRPC Call (community_id, invitation_code?, Metadata: X-User-ID, Trace Context)
    2. JoinCommunityCommandHandler: JoinCommunityCommandUseCaseを呼び出し
    3. JoinCommunityCommandUseCase: CommunityRepositoryからCommunity Aggregateを取得
    4. JoinCommunityCommandUseCase: Community Aggregateでvisibilityチェック（public/private/invite_only）
    5. (invite_onlyの場合) InvitationRepositoryで招待コード検証
    6. JoinCommunityCommandUseCase: MembershipRepositoryで重複参加チェック
    7. JoinCommunityCommandUseCase: Membership Aggregateを生成・永続化
    8. JoinCommunityCommandUseCase: CommunityStatisticsの更新（member_count+1）
    9. JoinCommunityCommandUseCase: EventPublisherを通じて `avion.community.member.joined` イベントを発行
    10. JoinCommunityCommandHandler → Gateway: `JoinCommunityResponse {}`

- **フロー 3: トピック作成 (Command)**
    1. Gateway → CreateTopicCommandHandler: `CreateTopic` gRPC Call (community_id, name, description, topic_type, visibility, Metadata: X-User-ID, Trace Context)
    2. CreateTopicCommandHandler: CreateTopicCommandUseCaseを呼び出し
    3. CreateTopicCommandUseCase: MembershipRepositoryでコミュニティメンバーシップ・権限確認
    4. (権限不十分の場合) CreateTopicCommandHandler → Gateway: gRPC Error (PermissionDenied)
    5. CreateTopicCommandUseCase: Topic Aggregateを生成し、TopicDomainServiceでビジネスルール検証（名前重複チェック）
    6. CreateTopicCommandUseCase: TopicRepositoryを通じてTopic Aggregateを永続化
    7. CreateTopicCommandUseCase: EventPublisherを通じて `avion.community.topic.created` イベントを発行
    8. CreateTopicCommandHandler → Gateway: `CreateTopicResponse { topic_id: "..." }`

- **フロー 4: メンバー役割変更 (Command)**
    1. Gateway → ChangeRoleCommandHandler: `ChangeRole` gRPC Call (community_id, target_user_id, new_role, Metadata: X-User-ID, Trace Context)
    2. ChangeRoleCommandHandler: ChangeRoleCommandUseCaseを呼び出し
    3. ChangeRoleCommandUseCase: MembershipRepositoryで実行者の権限確認（moderator以上）
    4. (権限不十分の場合) ChangeRoleCommandHandler → Gateway: gRPC Error (PermissionDenied)
    5. ChangeRoleCommandUseCase: MembershipRepositoryから対象メンバーのMembership Aggregateを取得
    6. ChangeRoleCommandUseCase: Membership Aggregate内で役割変更処理
    7. ChangeRoleCommandUseCase: MembershipRepositoryを通じてMembership Aggregateを更新
    8. ChangeRoleCommandUseCase: Redis権限キャッシュクリア
    9. ChangeRoleCommandUseCase: EventPublisherを通じて `avion.community.member.promoted` / `avion.community.member.demoted` イベントを発行
    10. ChangeRoleCommandHandler → Gateway: `ChangeRoleResponse {}`

- **フロー 5: メンバー一時停止 (Command)**
    1. Gateway → SuspendMemberCommandHandler: `SuspendMember` gRPC Call (community_id, target_user_id, reason, duration, Metadata: X-User-ID, Trace Context)
    2. SuspendMemberCommandHandler: SuspendMemberCommandUseCaseを呼び出し
    3. SuspendMemberCommandUseCase: MembershipRepositoryで実行者の権限確認（moderator以上）
    4. SuspendMemberCommandUseCase: CommunityModerationLogを記録
    5. SuspendMemberCommandUseCase: Membership Aggregateのステータスを'suspended'に変更、suspended_until設定
    6. SuspendMemberCommandUseCase: Redis権限キャッシュクリア
    7. SuspendMemberCommandUseCase: EventPublisherを通じて `avion.community.member.suspended` イベントを発行
    8. SuspendMemberCommandHandler → Gateway: `SuspendMemberResponse {}`

- **フロー 6: コミュニティ検索 (Query)**
    1. Gateway → SearchCommunitiesQueryHandler: `SearchCommunities` gRPC Call (query, category?, visibility?, limit, offset, Metadata: X-User-ID, Trace Context)
    2. SearchCommunitiesQueryHandler: SearchCommunitiesQueryUseCaseを呼び出し
    3. SearchCommunitiesQueryUseCase: CommunityQueryServiceを通じてコミュニティのDTOを取得
    4. SearchCommunitiesQueryUseCase: visibilityフィルタリング（publicのみまたはメンバーシップ確認）
    5. SearchCommunitiesQueryUseCase: RedisキャッシュからHot Communitiesを取得・統合
    6. SearchCommunitiesQueryHandler → Gateway: `SearchCommunitiesResponse { communities: [...] }`

- **フロー 7: イベント作成 (Command)**
    1. Gateway → CreateEventCommandHandler: `CreateEvent` gRPC Call (community_id, title, description, start_time, end_time, max_participants, Metadata: X-User-ID, Trace Context)
    2. CreateEventCommandHandler: CreateEventCommandUseCaseを呼び出し
    3. CreateEventCommandUseCase: MembershipRepositoryでコミュニティメンバーシップ確認
    4. CreateEventCommandUseCase: CommunityEvent Aggregateを生成し、時間検証・重複チェック
    5. CreateEventCommandUseCase: CommunityEventRepositoryを通じてCommunityEvent Aggregateを永続化
    6. CreateEventCommandUseCase: EventPublisherを通じて `avion.community.event.created` イベントを発行
    7. CreateEventCommandHandler → Gateway: `CreateEventResponse { event_id: "..." }`

- **フロー 8: コミュニティ統計取得 (Query)**
    1. Gateway → GetCommunityStatsQueryHandler: `GetCommunityStats` gRPC Call (community_id, Metadata: X-User-ID, Trace Context)
    2. GetCommunityStatsQueryHandler: GetCommunityStatsQueryUseCaseを呼び出し
    3. GetCommunityStatsQueryUseCase: Redis統計キャッシュから取得を試行
    4. (キャッシュヒット) 統計データを返却
    5. (キャッシュミス) CommunityStatisticsテーブルから取得、Redisにキャッシュ
    6. GetCommunityStatsQueryHandler → Gateway: `GetCommunityStatsResponse { stats: {...} }`

## 12. Interface Design (API設計)

### 12.1. gRPC Service定義

```protobuf
syntax = "proto3";

package avion.community.v1;

import "google/protobuf/timestamp.proto";
import "google/protobuf/empty.proto";

// コミュニティサービス
service CommunityService {
  // コミュニティ作成
  rpc CreateCommunity(CreateCommunityRequest) returns (CreateCommunityResponse);
  
  // コミュニティ取得
  rpc GetCommunity(GetCommunityRequest) returns (GetCommunityResponse);
  
  // コミュニティ更新
  rpc UpdateCommunity(UpdateCommunityRequest) returns (UpdateCommunityResponse);
  
  // コミュニティ削除
  rpc DeleteCommunity(DeleteCommunityRequest) returns (google.protobuf.Empty);
  
  // コミュニティ検索
  rpc SearchCommunities(SearchCommunitiesRequest) returns (SearchCommunitiesResponse);
  
  // コミュニティ参加
  rpc JoinCommunity(JoinCommunityRequest) returns (JoinCommunityResponse);
  
  // コミュニティ退会
  rpc LeaveCommunity(LeaveCommunityRequest) returns (google.protobuf.Empty);
}

// メンバーシップサービス
service MembershipService {
  // メンバー一覧取得
  rpc GetMembers(GetMembersRequest) returns (GetMembersResponse);
  
  // メンバー権限確認
  rpc CheckPermission(CheckPermissionRequest) returns (CheckPermissionResponse);
  
  // 役割変更
  rpc ChangeRole(ChangeRoleRequest) returns (ChangeRoleResponse);
  
  // メンバー一時停止
  rpc SuspendMember(SuspendMemberRequest) returns (SuspendMemberResponse);
  
  // メンバー追放
  rpc BanMember(BanMemberRequest) returns (BanMemberResponse);
}

// トピックサービス
service TopicService {
  // トピック作成
  rpc CreateTopic(CreateTopicRequest) returns (CreateTopicResponse);
  
  // トピック一覧取得
  rpc GetTopics(GetTopicsRequest) returns (GetTopicsResponse);
  
  // トピック更新
  rpc UpdateTopic(UpdateTopicRequest) returns (UpdateTopicResponse);
  
  // トピック削除
  rpc DeleteTopic(DeleteTopicRequest) returns (google.protobuf.Empty);
}

// メッセージ定義
message Community {
  string id = 1;
  string name = 2;
  string description = 3;
  string avatar_url = 4;
  string header_url = 5;
  CommunityVisibility visibility = 6;
  string category = 7;
  string owner_user_id = 8;
  int32 member_count = 9;
  bool is_archived = 10;
  google.protobuf.Timestamp created_at = 11;
  google.protobuf.Timestamp updated_at = 12;
}

message Membership {
  string id = 1;
  string community_id = 2;
  string user_id = 3;
  MembershipStatus status = 4;
  MembershipRole role = 5;
  repeated string permissions = 6;
  google.protobuf.Timestamp joined_at = 7;
  google.protobuf.Timestamp suspended_until = 8;
}

message Topic {
  string id = 1;
  string community_id = 2;
  string name = 3;
  string description = 4;
  TopicType type = 5;
  TopicVisibility visibility = 6;
  int32 display_order = 7;
  bool is_archived = 8;
  string created_by_user_id = 9;
  google.protobuf.Timestamp created_at = 10;
}

// 列挙型
enum CommunityVisibility {
  COMMUNITY_VISIBILITY_UNSPECIFIED = 0;
  COMMUNITY_VISIBILITY_PUBLIC = 1;
  COMMUNITY_VISIBILITY_PRIVATE = 2;
  COMMUNITY_VISIBILITY_INVITE_ONLY = 3;
}

enum MembershipStatus {
  MEMBERSHIP_STATUS_UNSPECIFIED = 0;
  MEMBERSHIP_STATUS_ACTIVE = 1;
  MEMBERSHIP_STATUS_PENDING = 2;
  MEMBERSHIP_STATUS_SUSPENDED = 3;
  MEMBERSHIP_STATUS_BANNED = 4;
  MEMBERSHIP_STATUS_LEFT = 5;
}

enum MembershipRole {
  MEMBERSHIP_ROLE_UNSPECIFIED = 0;
  MEMBERSHIP_ROLE_MEMBER = 1;
  MEMBERSHIP_ROLE_MODERATOR = 2;
  MEMBERSHIP_ROLE_OWNER = 3;
  MEMBERSHIP_ROLE_CUSTOM = 4; // カスタムロール（custom_role_idで詳細権限を参照）
}

enum TopicType {
  TOPIC_TYPE_UNSPECIFIED = 0;
  TOPIC_TYPE_GENERAL = 1;
  TOPIC_TYPE_ANNOUNCEMENT = 2;
  TOPIC_TYPE_ARCHIVED = 3;
}

enum TopicVisibility {
  TOPIC_VISIBILITY_UNSPECIFIED = 0;
  TOPIC_VISIBILITY_PUBLIC = 1;
  TOPIC_VISIBILITY_RESTRICTED = 2;
  TOPIC_VISIBILITY_PRIVATE = 3;
}

// ---- Request / Response メッセージ定義 ----

// CommunityService
message CreateCommunityRequest {
  string name = 1;
  string description = 2;
  CommunityVisibility visibility = 3;
  string category = 4;
  string avatar_url = 5;
  string header_url = 6;
}

message CreateCommunityResponse {
  Community community = 1;
}

message GetCommunityRequest {
  string community_id = 1;
}

message GetCommunityResponse {
  Community community = 1;
}

message UpdateCommunityRequest {
  string community_id = 1;
  string name = 2;
  string description = 3;
  CommunityVisibility visibility = 4;
  string category = 5;
  string avatar_url = 6;
  string header_url = 7;
}

message UpdateCommunityResponse {
  Community community = 1;
}

message DeleteCommunityRequest {
  string community_id = 1;
}

message SearchCommunitiesRequest {
  string query = 1;
  string category = 2;
  CommunityVisibility visibility = 3;
  int32 limit = 4;
  int32 offset = 5;
}

message SearchCommunitiesResponse {
  repeated Community communities = 1;
  int32 total_count = 2;
}

message JoinCommunityRequest {
  string community_id = 1;
  string invitation_code = 2; // optional: 招待制の場合
}

message JoinCommunityResponse {
  Membership membership = 1;
}

message LeaveCommunityRequest {
  string community_id = 1;
}

// MembershipService
message GetMembersRequest {
  string community_id = 1;
  MembershipStatus status = 2;
  MembershipRole role = 3;
  int32 limit = 4;
  int32 offset = 5;
}

message GetMembersResponse {
  repeated Membership members = 1;
  int32 total_count = 2;
}

message CheckPermissionRequest {
  string community_id = 1;
  string user_id = 2;
  string permission = 3;
}

message CheckPermissionResponse {
  bool has_permission = 1;
  MembershipRole role = 2;
}

message ChangeRoleRequest {
  string community_id = 1;
  string target_user_id = 2;
  MembershipRole new_role = 3;
}

message ChangeRoleResponse {
  Membership membership = 1;
}

message SuspendMemberRequest {
  string community_id = 1;
  string target_user_id = 2;
  string reason = 3;
  google.protobuf.Timestamp suspended_until = 4;
}

message SuspendMemberResponse {
  Membership membership = 1;
}

message BanMemberRequest {
  string community_id = 1;
  string target_user_id = 2;
  string reason = 3;
}

message BanMemberResponse {
  Membership membership = 1;
}

// TopicService
message CreateTopicRequest {
  string community_id = 1;
  string name = 2;
  string description = 3;
  TopicType type = 4;
  TopicVisibility visibility = 5;
}

message CreateTopicResponse {
  Topic topic = 1;
}

message GetTopicsRequest {
  string community_id = 1;
  bool include_archived = 2;
  int32 limit = 3;
  int32 offset = 4;
}

message GetTopicsResponse {
  repeated Topic topics = 1;
  int32 total_count = 2;
}

message UpdateTopicRequest {
  string community_id = 1;
  string topic_id = 2;
  string name = 3;
  string description = 4;
  TopicType type = 5;
  TopicVisibility visibility = 6;
}

message UpdateTopicResponse {
  Topic topic = 1;
}

message DeleteTopicRequest {
  string community_id = 1;
  string topic_id = 2;
}

// EventService
service EventService {
  rpc CreateEvent(CreateEventRequest) returns (CreateEventResponse);
  rpc GetEvents(GetEventsRequest) returns (GetEventsResponse);
  rpc GetEvent(GetEventRequest) returns (GetEventResponse);
  rpc UpdateEvent(UpdateEventRequest) returns (UpdateEventResponse);
  rpc JoinEvent(JoinEventRequest) returns (JoinEventResponse);
  rpc LeaveEvent(LeaveEventRequest) returns (google.protobuf.Empty);
}

message CommunityEvent {
  string id = 1;
  string community_id = 2;
  string title = 3;
  string description = 4;
  google.protobuf.Timestamp start_time = 5;
  google.protobuf.Timestamp end_time = 6;
  int32 max_participants = 7;
  int32 participant_count = 8;
  string status = 9;
  string created_by_user_id = 10;
  google.protobuf.Timestamp created_at = 11;
  google.protobuf.Timestamp updated_at = 12;
}

message CreateEventRequest {
  string community_id = 1;
  string title = 2;
  string description = 3;
  google.protobuf.Timestamp start_time = 4;
  google.protobuf.Timestamp end_time = 5;
  int32 max_participants = 6;
}

message CreateEventResponse {
  CommunityEvent event = 1;
}

message GetEventsRequest {
  string community_id = 1;
  string status = 2;
  int32 limit = 3;
  int32 offset = 4;
}

message GetEventsResponse {
  repeated CommunityEvent events = 1;
  int32 total_count = 2;
}

message GetEventRequest {
  string event_id = 1;
}

message GetEventResponse {
  CommunityEvent event = 1;
}

message UpdateEventRequest {
  string event_id = 1;
  string title = 2;
  string description = 3;
  google.protobuf.Timestamp start_time = 4;
  google.protobuf.Timestamp end_time = 5;
  int32 max_participants = 6;
}

message UpdateEventResponse {
  CommunityEvent event = 1;
}

message JoinEventRequest {
  string event_id = 1;
}

message JoinEventResponse {
  CommunityEvent event = 1;
}

message LeaveEventRequest {
  string event_id = 1;
}

// RuleService
service RuleService {
  rpc CreateRule(CreateRuleRequest) returns (CreateRuleResponse);
  rpc GetRules(GetRulesRequest) returns (GetRulesResponse);
  rpc UpdateRule(UpdateRuleRequest) returns (UpdateRuleResponse);
  rpc DeleteRule(DeleteRuleRequest) returns (google.protobuf.Empty);
}

message CommunityRule {
  string id = 1;
  string community_id = 2;
  int32 rule_number = 3;
  string title = 4;
  string description = 5;
  string enforcement = 6;
  bool is_active = 7;
  string created_by_user_id = 8;
  google.protobuf.Timestamp created_at = 9;
  google.protobuf.Timestamp updated_at = 10;
}

message CreateRuleRequest {
  string community_id = 1;
  string title = 2;
  string description = 3;
  string enforcement = 4;
}

message CreateRuleResponse {
  CommunityRule rule = 1;
}

message GetRulesRequest {
  string community_id = 1;
  bool include_inactive = 2;
}

message GetRulesResponse {
  repeated CommunityRule rules = 1;
}

message UpdateRuleRequest {
  string rule_id = 1;
  string title = 2;
  string description = 3;
  string enforcement = 4;
  bool is_active = 5;
}

message UpdateRuleResponse {
  CommunityRule rule = 1;
}

message DeleteRuleRequest {
  string rule_id = 1;
}

// InvitationService
service InvitationService {
  rpc CreateInvitation(CreateInvitationRequest) returns (CreateInvitationResponse);
  rpc GetInvitations(GetInvitationsRequest) returns (GetInvitationsResponse);
  rpc RevokeInvitation(RevokeInvitationRequest) returns (google.protobuf.Empty);
  rpc UseInvitation(UseInvitationRequest) returns (UseInvitationResponse);
}

message CommunityInvitation {
  string id = 1;
  string community_id = 2;
  string invite_code = 3;
  string created_by_user_id = 4;
  int32 max_usage = 5;
  int32 usage_count = 6;
  google.protobuf.Timestamp expires_at = 7;
  bool is_active = 8;
  google.protobuf.Timestamp created_at = 9;
}

message CreateInvitationRequest {
  string community_id = 1;
  int32 max_usage = 2;
  google.protobuf.Timestamp expires_at = 3;
}

message CreateInvitationResponse {
  CommunityInvitation invitation = 1;
  string invite_url = 2;
}

message GetInvitationsRequest {
  string community_id = 1;
  bool include_expired = 2;
}

message GetInvitationsResponse {
  repeated CommunityInvitation invitations = 1;
}

message RevokeInvitationRequest {
  string invitation_id = 1;
}

message UseInvitationRequest {
  string invite_code = 1;
}

message UseInvitationResponse {
  Membership membership = 1;
}
```

## 13. Implementation Plan (実装計画)

### Phase 1: 基盤実装 (2週間)
- Domain Layer の Aggregates/Entities/Value Objects 実装
- Repository Interfaces 定義
- PostgreSQL テーブル作成とマイグレーション
- 基本的な gRPC API 構造構築

### Phase 2: コア機能実装 (3週間)
- Community CRUD 操作
- Membership 管理（参加・退会・役割変更）
- Topic 管理
- 基本的な権限チェック機能
- Redis キャッシュ連携

### Phase 3: 拡張機能実装 (3週間)
- Rule・モデレーション機能
- Invitation システム
- Event 機能
- 統計・分析機能
- 検索・発見機能

### Phase 4: 最適化・テスト (2週間)
- パフォーマンス最適化
- 包括的テストスイート
- 監視・ロギング強化
- ドキュメント整備

## 14. Release Plan (リリース計画)

### 14.1. 実装フェーズ

| Phase | 内容 | 期間 | 前提条件 |
|:------|:-----|:-----|:---------|
| Phase 1 | 基盤実装（Domain Layer、Repository Interfaces、PostgreSQLマイグレーション、基本gRPC構造） | 2週間 | - |
| Phase 2 | コア機能実装（Community CRUD、Membership管理、Topic管理、権限チェック、Redisキャッシュ） | 3週間 | Phase 1 完了 |
| Phase 3 | 拡張機能実装（Rule・モデレーション、Invitation、Event、統計・検索機能） | 3週間 | Phase 2 完了 |
| Phase 4 | 最適化・テスト（パフォーマンス最適化、包括的テストスイート、監視・ロギング強化） | 2週間 | Phase 3 完了 |

### 14.2. 段階的ロールアウト戦略

**Canary Release:**
1. **5%** -- 初期検証（最低15分間監視）
2. **25%** -- 拡大検証（最低30分間監視）
3. **50%** -- 広域検証（最低1時間監視）
4. **100%** -- 全展開

**各段階の監視項目:**
- エラー率 < 1%
- レイテンシ p99 < SLO の 2倍
- CPU/Memory 使用率が正常範囲内

### 14.3. ロールバック判定基準と手順

**ロールバック判定基準:**
- エラー率が 1% を超過
- p99 レイテンシが SLO の 2倍を超過
- CRITICAL レベルのログが発生
- データ整合性エラーの検出

**ロールバック手順:**
```bash
# 1. 新バージョンのデプロイを停止
kubectl rollout pause deployment/avion-community -n avion

# 2. 前バージョンにロールバック
kubectl rollout undo deployment/avion-community -n avion

# 3. ロールバック完了を確認
kubectl rollout status deployment/avion-community -n avion

# 4. 必要に応じてDBマイグレーションのロールバック
# (docs/common/database/database-migration-strategy.md 参照)
```

### 14.4. 環境デプロイ順序

1. **dev** -- 開発環境でのE2Eテスト
2. **staging** -- 本番同等環境での負荷テスト・統合テスト
3. **production** -- 段階的ロールアウト（14.2参照）

### 14.5. サービス間依存関係

- **前提サービス:** avion-auth（認証基盤）、avion-user（ユーザー情報）
- **後続サービス:** avion-timeline（コミュニティフィード生成）、avion-notification（通知配信）、avion-search（コミュニティ検索インデックス）

### 14.6. リリース前チェックリスト

- [ ] 全テストがパス（ユニット + 統合）
- [ ] カバレッジ目標達成（85%以上）
- [ ] DBマイグレーションスクリプト準備完了
- [ ] 環境変数の追加/変更がドキュメント化済み
- [ ] ロールバック手順のリハーサル完了
- [ ] 監視ダッシュボード・アラートの設定完了
- [ ] staging環境での動作確認完了

### 14.7. リリース後検証ステップ

- [ ] Canary比率の段階的拡大
- [ ] エラー率・レイテンシの継続監視
- [ ] ログの異常パターン確認
- [ ] 依存サービスとの連携正常性確認
- [ ] 24時間後のメトリクス確認

## 15. サービス固有のテスト要件

### コミュニティ機能固有のテスト
- **権限システムのテスト**: 複雑なロール・権限マトリックスの検証
- **メンバーシップ管理のテスト**: 大規模コミュニティでの性能確認
- **イベント発行のテスト**: 他サービスへの通知正確性確認
- **データ整合性のテスト**: PostgreSQL/Redis間のデータ同期検証

テスト実装の詳細は[共通テスト戦略](../common/testing-strategy.md)を参照してください。

> **注意:** エラーコードは[共通エラーコード標準](../common/errors/error-codes.md)に準拠します。このサービスではプレフィックス `COMMUNITY` を使用します。

## 16. Operations & Monitoring (運用と監視)

- **主なオペレーション:**
    - DBマイグレーション（PostgreSQL）
    - Redis接続情報、NATS JetStream設定
    - (必要に応じて) コミュニティ統計キャッシュの手動クリア
    - (必要に応じて) 権限キャッシュの手動クリア
    - モデレーションログの定期アーカイブ
    - 招待コードの期限切れクリーンアップ
    - コミュニティ統計の定期再計算バッチ処理

- **監視/アラート:**
    - **メトリクス:**
        - gRPCリクエスト数、レイテンシ、エラーレート
        - DB接続エラー、クエリ実行時間（特にmembershipsテーブルアクセス）
        - Redisキャッシュヒット率（目標: 95%以上）、コマンド実行時間、メモリ使用量
        - NATS JetStream発行エラー/遅延（コミュニティ関連イベント）
        - コミュニティ作成・参加・退会レート
        - モデレーション操作頻度・レスポンス時間
        - 招待コード使用率・期限切れ率
        - イベント参加・キャンセルレート
        - Hot Communitiesキャッシュメモリ使用量
    - **ログ:** CRUD操作ログ、メンバーシップ変更ログ、モデレーション操作ログ、権限チェックログ、エラーログ
    - **トレース:** API呼び出し、DBアクセス、キャッシュアクセス、権限チェック、イベント発行のトレース
    - **アラート:** gRPCエラーレート急増、高レイテンシ、DB/Redis接続障害、NATS JetStream発行失敗、権限チェック失敗率急増、モデレーション操作異常増加

## 17. 構造化ログ戦略（詳細）

このサービスでは、運用性とデバッグ効率を向上させるため、構造化ログを採用します。

### ログフレームワーク
- **使用ライブラリ**: `slog` (Go標準ライブラリ) または `zap`
- **出力形式**: JSON形式
- **ログレベル**: Debug, Info, Warn, Error, CRITICAL
- **CRITICALレベル**: panicにして処理を停止させないといけないレベル（データ整合性の致命的破壊、システムリソースの枯渇等）

### ログ構造の標準フィールド

```go
type LogContext struct {
    // 必須フィールド
    Timestamp     time.Time `json:"timestamp"`
    Level         string    `json:"level"`
    Service       string    `json:"service"`       // "avion-community"
    Version       string    `json:"version"`       // サービスバージョン
    TraceID       string    `json:"trace_id"`      // OpenTelemetry TraceID
    SpanID        string    `json:"span_id"`       // OpenTelemetry SpanID
    
    // コンテキストフィールド
    UserID        string    `json:"user_id,omitempty"`
    CommunityID   string    `json:"community_id,omitempty"`
    MembershipID  string    `json:"membership_id,omitempty"`
    TopicID       string    `json:"topic_id,omitempty"`
    EventID       string    `json:"event_id,omitempty"`
    RequestID     string    `json:"request_id,omitempty"`
    Method        string    `json:"method,omitempty"`        // gRPCメソッド名
    Layer         string    `json:"layer,omitempty"`         // domain/usecase/infra/handler
    
    // エラー情報
    Error         string    `json:"error,omitempty"`
    ErrorCode     string    `json:"error_code,omitempty"`
    StackTrace    string    `json:"stack_trace,omitempty"`
    
    // パフォーマンス
    Duration      int64     `json:"duration_ms,omitempty"`   // 処理時間（ミリ秒）
    
    // カスタムフィールド
    Extra         map[string]interface{} `json:"extra,omitempty"`
}
```

### 各層でのログ出力例

#### Handler層
```go
logger.Info("gRPC request received",
    slog.String("method", "CreateCommunity"),
    slog.String("trace_id", traceID),
    slog.String("user_id", userID),
    slog.String("layer", "handler"),
)

logger.Error("gRPC request failed",
    slog.String("method", "CreateCommunity"),
    slog.String("trace_id", traceID),
    slog.String("user_id", userID),
    slog.String("error", err.Error()),
    slog.String("error_code", "COMMUNITY_DOMAIN_ALREADY_EXISTS"),
    slog.String("layer", "handler"),
)
```

#### Use Case層
```go
logger.Info("community creation started",
    slog.String("trace_id", traceID),
    slog.String("user_id", userID),
    slog.String("community_name", communityName),
    slog.String("layer", "usecase"),
)

logger.Warn("permission check failed",
    slog.String("trace_id", traceID),
    slog.String("user_id", userID),
    slog.String("community_id", communityID),
    slog.String("required_permission", "MODERATE_MEMBERS"),
    slog.String("layer", "usecase"),
)
```

#### Infrastructure層
```go
logger.Debug("database query executed",
    slog.String("trace_id", traceID),
    slog.String("table", "communities"),
    slog.String("operation", "INSERT"),
    slog.Int64("duration_ms", durationMs),
    slog.String("layer", "infra"),
)

logger.Error("cache operation failed",
    slog.String("trace_id", traceID),
    slog.String("cache_key", cacheKey),
    slog.String("operation", "SET"),
    slog.String("error", err.Error()),
    slog.String("layer", "infra"),
)
```

#### Domain層
```go
logger.Info("business rule validation",
    slog.String("trace_id", traceID),
    slog.String("rule", "max_members_per_community"),
    slog.String("community_id", communityID),
    slog.Int("current_members", currentMembers),
    slog.Int("max_members", maxMembers),
    slog.String("layer", "domain"),
)
```

### 特定操作のログ出力戦略

#### モデレーション操作
```go
logger.Warn("moderation action executed",
    slog.String("trace_id", traceID),
    slog.String("moderator_user_id", moderatorUserID),
    slog.String("target_user_id", targetUserID),
    slog.String("community_id", communityID),
    slog.String("action", "SUSPEND_MEMBER"),
    slog.String("reason", reason),
    slog.String("duration", suspendDuration),
    slog.String("layer", "usecase"),
)
```

#### 権限チェック
```go
logger.Debug("permission check",
    slog.String("trace_id", traceID),
    slog.String("user_id", userID),
    slog.String("community_id", communityID),
    slog.String("required_permission", permission),
    slog.Bool("granted", granted),
    slog.String("user_role", userRole),
    slog.String("layer", "domain"),
)
```

#### イベント発行
```go
logger.Info("event published",
    slog.String("trace_id", traceID),
    slog.String("event_type", "avion.community.group.created"),
    slog.String("community_id", communityID),
    slog.String("channel", "nats_jetstream"),
    slog.String("layer", "infra"),
)
```

## 18. Security Considerations (セキュリティ考慮事項)

### 18.1. アクセス制御
- 厳密な権限チェックの実装
- プライベートコミュニティの情報漏洩防止
- 特権昇格攻撃の対策

### 18.2. 入力検証
- すべての入力データの妥当性検証
- SQL インジェクション対策
- XSS 攻撃対策

### 18.3. データ保護
- 個人情報の適切な取り扱い
- 削除されたデータの確実な消去
- 監査証跡の改ざん防止

## 19. ドメインオブジェクトとDBスキーマのマッピング

このセクションでは、ドメイン層で定義されるオブジェクトとデータベーススキーマの対応関係を明確にします。

### 19.1. Community Aggregate
```go
// Domain Object
type Community struct {
    id           CommunityID
    name         CommunityName
    description  string
    avatarURL    string
    headerURL    string
    visibility   CommunityVisibility
    category     string
    ownerUserID  UserID
    memberCount  int
    isArchived   bool
    createdAt    time.Time
    updatedAt    time.Time
    version      int
}

// DB Schema Mapping
// Table: communities
// - id (UUID) ↔ Community.id (CommunityID) -- UUID v7
// - name (VARCHAR(50)) ↔ Community.name (CommunityName)
// - description (TEXT) ↔ Community.description (string)
// - avatar_url (VARCHAR(500)) ↔ Community.avatarURL (string)
// - header_url (VARCHAR(500)) ↔ Community.headerURL (string)
// - visibility (VARCHAR(20)) ↔ Community.visibility (CommunityVisibility)
// - category (VARCHAR(50)) ↔ Community.category (string)
// - owner_user_id (UUID) ↔ Community.ownerUserID (UserID) -- UUID v7
// - member_count (INTEGER) ↔ Community.memberCount (int)
// - is_archived (BOOLEAN) ↔ Community.isArchived (bool)
// - created_at (TIMESTAMP WITH TIME ZONE) ↔ Community.createdAt (time.Time)
// - updated_at (TIMESTAMP WITH TIME ZONE) ↔ Community.updatedAt (time.Time)
// - version (INTEGER) ↔ Community.version (int)
```

### 19.2. Membership Aggregate
```go
// Domain Object
type Membership struct {
    id             MembershipID
    communityID    CommunityID
    userID         UserID
    status         MembershipStatus
    role           MembershipRole
    customRoleID   *CustomRoleID
    permissions    MemberPermissions
    joinedAt       *time.Time
    suspendedUntil *time.Time
    createdAt      time.Time
    updatedAt      time.Time
}

// DB Schema Mapping
// Table: memberships
// - id (UUID) ↔ Membership.id (MembershipID) -- UUID v7
// - community_id (UUID) ↔ Membership.communityID (CommunityID) -- UUID v7
// - user_id (UUID) ↔ Membership.userID (UserID) -- UUID v7
// - status (VARCHAR(20)) ↔ Membership.status (MembershipStatus)
// - role (VARCHAR(30)) ↔ Membership.role (MembershipRole)
// - custom_role_id (UUID) ↔ Membership.customRoleID (*CustomRoleID)
// - permissions (BIGINT) ↔ Membership.permissions (MemberPermissions) [bitmask]
// - joined_at (TIMESTAMP WITH TIME ZONE) ↔ Membership.joinedAt (*time.Time)
// - suspended_until (TIMESTAMP WITH TIME ZONE) ↔ Membership.suspendedUntil (*time.Time)
// - created_at (TIMESTAMP WITH TIME ZONE) ↔ Membership.createdAt (time.Time)
// - updated_at (TIMESTAMP WITH TIME ZONE) ↔ Membership.updatedAt (time.Time)
```

### 19.3. Topic Aggregate
```go
// Domain Object
type Topic struct {
    id              TopicID
    communityID     CommunityID
    name            TopicName
    description     string
    topicType       TopicType
    visibility      TopicVisibility
    requiredRole    *MembershipRole
    displayOrder    int
    isArchived      bool
    createdByUserID UserID
    createdAt       time.Time
    updatedAt       time.Time
}

// DB Schema Mapping
// Table: topics
// - id (UUID) ↔ Topic.id (TopicID) -- UUID v7
// - community_id (UUID) ↔ Topic.communityID (CommunityID) -- UUID v7
// - name (VARCHAR(30)) ↔ Topic.name (TopicName)
// - description (TEXT) ↔ Topic.description (string)
// - topic_type (VARCHAR(20)) ↔ Topic.topicType (TopicType)
// - visibility (VARCHAR(20)) ↔ Topic.visibility (TopicVisibility)
// - required_role (VARCHAR(30)) ↔ Topic.requiredRole (*MembershipRole)
// - display_order (INTEGER) ↔ Topic.displayOrder (int)
// - is_archived (BOOLEAN) ↔ Topic.isArchived (bool)
// - created_by_user_id (UUID) ↔ Topic.createdByUserID (UserID) -- UUID v7
// - created_at (TIMESTAMP WITH TIME ZONE) ↔ Topic.createdAt (time.Time)
// - updated_at (TIMESTAMP WITH TIME ZONE) ↔ Topic.updatedAt (time.Time)
```

### 19.4. CommunityEvent Aggregate
```go
// Domain Object
type CommunityEvent struct {
    id                 EventID
    communityID        CommunityID
    title              EventTitle
    description        string
    startTime          time.Time
    endTime            time.Time
    maxParticipants    int
    participantCount   int
    status             EventStatus
    createdByUserID    UserID
    createdAt          time.Time
    updatedAt          time.Time
}

// DB Schema Mapping
// Table: community_events
// - id (UUID) ↔ CommunityEvent.id (EventID) -- UUID v7
// - community_id (UUID) ↔ CommunityEvent.communityID (CommunityID) -- UUID v7
// - title (VARCHAR(100)) ↔ CommunityEvent.title (EventTitle)
// - description (TEXT) ↔ CommunityEvent.description (string)
// - start_time (TIMESTAMP WITH TIME ZONE) ↔ CommunityEvent.startTime (time.Time)
// - end_time (TIMESTAMP WITH TIME ZONE) ↔ CommunityEvent.endTime (time.Time)
// - max_participants (INTEGER) ↔ CommunityEvent.maxParticipants (int)
// - participant_count (INTEGER) ↔ CommunityEvent.participantCount (int)
// - status (VARCHAR(20)) ↔ CommunityEvent.status (EventStatus)
// - created_by_user_id (UUID) ↔ CommunityEvent.createdByUserID (UserID) -- UUID v7
// - created_at (TIMESTAMP WITH TIME ZONE) ↔ CommunityEvent.createdAt (time.Time)
// - updated_at (TIMESTAMP WITH TIME ZONE) ↔ CommunityEvent.updatedAt (time.Time)
```

### 19.5. Value Objects のマッピング戦略

#### String-based Value Objects
```go
// Domain Value Objects → DB Types
type CommunityID string     // → UUID (UUID v7)
type UserID string          // → UUID (UUID v7)
type CommunityName string   // → VARCHAR(50)
type TopicName string       // → VARCHAR(30)
type EventTitle string      // → VARCHAR(100)
type InviteCode string      // → VARCHAR(50)
```

#### Enum Value Objects
```go
// Domain Enums → DB Types
type CommunityVisibility int // → VARCHAR(20) {"public", "private", "invite_only"}
type MembershipStatus int    // → VARCHAR(20) {"active", "pending", "suspended", "banned", "left"}
type MembershipRole int      // → VARCHAR(30) {"member", "moderator", "owner"}
type TopicType int           // → VARCHAR(20) {"general", "announcement", "archived"}
type EventStatus int         // → VARCHAR(20) {"scheduled", "ongoing", "completed", "cancelled"}
```

#### Complex Value Objects
```go
// MemberPermissions (bitmask)
type MemberPermissions int64
// DB: permissions (BIGINT) - ビットフラグとして格納
// 例: READ_POSTS(1) | WRITE_POSTS(2) | MODERATE_POSTS(4) = 7

// InviteCode (UUID + metadata)
type InviteCode struct {
    Code      string
    CreatedBy UserID
    ExpiresAt time.Time
}
// DB: invite_code (VARCHAR(50)), created_by_user_id (UUID), expires_at (TIMESTAMP)
```

### 19.6. Repository Implementation Strategy
```go
// Example: CommunityRepository implementation
func (r *PostgresCommunityRepository) toDomainCommunity(row CommunityRow) *Community {
    return &Community{
        id:          CommunityID(row.ID),
        name:        CommunityName(row.Name),
        description: row.Description,
        // ... other mappings
        visibility:  parseVisibility(row.Visibility),
        createdAt:   row.CreatedAt,
    }
}

func (r *PostgresCommunityRepository) toDBRow(community *Community) CommunityRow {
    return CommunityRow{
        ID:          string(community.id),
        Name:        string(community.name),
        Description: community.description,
        // ... other mappings
        Visibility:  visibilityToString(community.visibility),
        CreatedAt:   community.createdAt,
    }
}
```

## 20. 他サービスとの責任分界

### avion-drop との連携
- **avion-communityの責任:**
  - トピック内でのピン留め指示の管理
  - トピックごとの投稿権限設定
  - コミュニティ固有の投稿ルール設定
- **avion-dropの責任:**
  - 実際の投稿（Drop）データの管理
  - ピン留め状態の保持と表示制御
  - 投稿コンテンツの検索・フィルタリング

### avion-moderation との連携
- **avion-communityの責任:**
  - コミュニティ固有のモデレーションルール
  - コミュニティモデレーターによる手動モデレーション
  - コミュニティ内での制裁処理
- **avion-moderationの責任:**
  - プラットフォーム全体のモデレーションポリシー
  - グローバルなスパム・不適切コンテンツ検出
  - AIベースの自動コンテンツ分析
  - プラットフォームレベルの制裁処理

### avion-notification との連携
- **avion-communityの責任:**
  - 通知イベントの発行
  - 通知対象者の特定
  - コミュニティ固有の通知設定管理
- **avion-notificationの責任:**
  - 実際の通知配信処理
  - プッシュ通知・メール送信
  - イベントリマインダーのスケジューリング
  - 通知の重複排除・バッチ処理

## 21. Concerns / Open Questions (懸念事項・相談したいこと)

- **技術的負債リスク:**
    - **コミュニティ階層構造:** 現在はフラットな構造だが、将来的にサブコミュニティやカテゴリ階層が必要になった場合のマイグレーション戦略
    - **権限システムの複雑性:** カスタム役割の導入により権限チェックが複雑化する可能性。パフォーマンスへの影響を検討
    - **イベント機能の拡張:** 現在は基本的なイベント機能のみ。将来的にリマインダー、カレンダー統合等が必要になる可能性

- **スケーラビリティ懸念:**
    - **大規模コミュニティ対応:** メンバー数が数万人規模になった場合のmembershipsテーブルのパフォーマンス
    - **モデレーション負荷:** 大規模コミュニティでのモデレーション作業量増大への対応
    - **統計計算コスト:** コミュニティ統計の実時間計算が重くなる可能性

- **セキュリティ・プライバシー:**
    - **プライベートコミュニティの情報漏洩:** 検索結果やAPIレスポンスでの意図しない情報露出
    - **モデレーション権限の乱用:** モデレーターによる不正な権限行使の検知・防止策
    - **招待システムの悪用:** 招待コードの不正使用や大量生成への対策

- **他サービスとの連携:**
    - **avion-drop との統合:** コミュニティ内投稿の取得・表示方法の最適化
    - **avion-notification との連携:** コミュニティ関連通知の適切な配信制御
    - **avion-moderation との役割分担:** コミュニティレベルとプラットフォームレベルのモデレーション機能の境界

- **運用・保守性:**
    - **データベース運用:** コミュニティデータの長期保存戦略とアーカイブ機能
    - **バックアップ・復旧:** コミュニティデータの完全性保持と障害時復旧手順
    - **マイグレーション戦略:** 既存データを保持したままでの機能拡張方法

- **UX・機能面:**
    - **コミュニティ発見機能:** ユーザーが関心のあるコミュニティを効率的に見つけられるアルゴリズム
    - **通知の過多問題:** 活発なコミュニティでの通知量制御
    - **モバイルアプリ対応:** コミュニティ機能のモバイル最適化

この設計に基づき、avion-communityサービスは、スケーラブルで安全、かつ拡張可能なコミュニティ機能を提供し、Avionプラットフォーム全体の価値向上に貢献します。

## 22. Service-Specific Test Strategy (サービス固有テスト戦略)

このセクションでは、avion-community サービスの複雑な機能要件に特化したテスト戦略を定義します。

### 22.1. 階層ロール権限システムのテスト

#### 権限継承と階層構造の検証

```go
func TestCommunityPermissionService_HasPermission(t *testing.T) {
    t.Parallel()

    tests := []struct {
        name          string
        userRole      MembershipRole
        requiredPerm  Permission
        hasCustomRole bool
        customPerms   int64
        want          bool
    }{
        {
            name:         "正常系: オーナーは全権限を保有",
            userRole:     RoleOwner,
            requiredPerm: PermissionModerateMembers,
            want:         true,
        },
        {
            name:         "正常系: モデレーターはコミュニティ削除権限を持たない",
            userRole:     RoleModerator,
            requiredPerm: PermissionDeleteCommunity,
            want:         false,
        },
        {
            name:          "正常系: カスタムロールで特定権限を付与",
            userRole:      RoleMember,
            requiredPerm:  PermissionCreateTopics,
            hasCustomRole: true,
            customPerms:   int64(PermissionCreateTopics | PermissionPinPosts),
            want:          true,
        },
        {
            name:         "異常系: 一般メンバーはモデレーション権限を持たない",
            userRole:     RoleMember,
            requiredPerm: PermissionSuspendMembers,
            want:         false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()
            // Setup
            ctrl := gomock.NewController(t)
            defer ctrl.Finish()

            membership := &Membership{
                Role:        tt.userRole,
                Permissions: tt.customPerms,
            }

            permissionService := NewCommunityPermissionService()

            // Execute
            got := permissionService.HasPermission(membership, tt.requiredPerm)

            // Assert
            if diff := cmp.Diff(tt.want, got); diff != "" {
                t.Errorf("HasPermission() mismatch (-want +got):\n%s", diff)
            }
        })
    }
}

func TestCommunityPermissionService_HasCommunityPermission(t *testing.T) {
    t.Parallel()

    tests := []struct {
        name       string
        setup      func() (*Community, *Membership, Permission)
        want       bool
    }{
        {
            name: "正常系: トピック管理権限を持つモデレーターはトピック削除可能",
            setup: func() (*Community, *Membership, Permission) {
                community := &Community{ID: "comm1", Visibility: VisibilityPrivate}
                membership := &Membership{
                    Role:        RoleModerator,
                    Permissions: int64(PermissionManageTopics),
                }
                return community, membership, PermissionDeleteTopics
            },
            want: true,
        },
        {
            name: "異常系: 別コミュニティのオーナー権限は適用されない",
            setup: func() (*Community, *Membership, Permission) {
                community := &Community{ID: "comm2"}
                membership := &Membership{
                    CommunityID: "comm1",
                    Role:        RoleOwner,
                }
                return community, membership, PermissionModerateMembers
            },
            want: false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()
            community, membership, permission := tt.setup()
            permissionService := NewCommunityPermissionService()

            got := permissionService.HasCommunityPermission(
                membership, community, permission)

            if diff := cmp.Diff(tt.want, got); diff != "" {
                t.Errorf("HasCommunityPermission() mismatch (-want +got):\n%s", diff)
            }
        })
    }
}
```

### 22.2. 招待システムのテスト

#### 招待コード生成と有効期限管理

```go
func TestInvitationService_ValidateInvitation(t *testing.T) {
    t.Parallel()

    fixedNow := time.Date(2026, 3, 14, 12, 0, 0, 0, time.UTC)

    tests := []struct {
        name    string
        fields  struct {
            maxUsage     int
            currentUsage int
            expiresAt    time.Time
            isActive     bool
        }
        want    InvitationStatus
    }{
        {
            name: "正常系: 使用制限内かつ有効期限内の招待は有効",
            fields: struct {
                maxUsage     int
                currentUsage int
                expiresAt    time.Time
                isActive     bool
            }{10, 5, fixedNow.Add(24 * time.Hour), true},
            want: InvitationStatusValid,
        },
        {
            name: "異常系: 有効期限切れの招待は期限切れ",
            fields: struct {
                maxUsage     int
                currentUsage int
                expiresAt    time.Time
                isActive     bool
            }{10, 3, fixedNow.Add(-1 * time.Hour), true},
            want: InvitationStatusExpired,
        },
        {
            name: "異常系: 使用回数上限到達の招待は使い切り",
            fields: struct {
                maxUsage     int
                currentUsage int
                expiresAt    time.Time
                isActive     bool
            }{5, 5, fixedNow.Add(24 * time.Hour), true},
            want: InvitationStatusExhausted,
        },
        {
            name: "異常系: 手動無効化された招待は無効",
            fields: struct {
                maxUsage     int
                currentUsage int
                expiresAt    time.Time
                isActive     bool
            }{10, 2, fixedNow.Add(24 * time.Hour), false},
            want: InvitationStatusInactive,
        },
        {
            name: "正常系: 無制限招待は使用回数に関わらず有効",
            fields: struct {
                maxUsage     int
                currentUsage int
                expiresAt    time.Time
                isActive     bool
            }{-1, 1000, fixedNow.Add(24 * time.Hour), true},
            want: InvitationStatusValid,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()
            // Setup
            ctx := ctxtimetest.SetFixedNow(context.Background(), fixedNow)
            invitation := &CommunityInvitation{
                ID:         uuid.Must(uuid.NewV7()),
                InviteCode: generateInviteCode(),
                MaxUsage:   tt.fields.maxUsage,
                UsageCount: tt.fields.currentUsage,
                ExpiresAt:  tt.fields.expiresAt,
                IsActive:   tt.fields.isActive,
            }

            invitationService := NewInvitationService()

            // Execute
            got := invitationService.ValidateInvitation(ctx, invitation)

            // Assert
            if diff := cmp.Diff(tt.want, got); diff != "" {
                t.Errorf("ValidateInvitation() mismatch (-want +got):\n%s", diff)
            }
        })
    }
}

func TestConcurrentInvitationUsage(t *testing.T) {
    // 並行招待使用時のレースコンディション防止テスト
    invitation := &CommunityInvitation{
        ID:         uuid.New(),
        InviteCode: "TEST_CODE_123",
        MaxUsage:   5,
        UsageCount: 0,
        ExpiresAt:  time.Now().Add(24 * time.Hour),
        IsActive:   true,
    }

    invitationRepo := NewMockInvitationRepository()
    invitationService := NewInvitationService(invitationRepo)

    var wg sync.WaitGroup
    successCount := int32(0)
    concurrentAttempts := 10

    for i := 0; i < concurrentAttempts; i++ {
        wg.Add(1)
        go func(userID string) {
            defer wg.Done()

            err := invitationService.UseInvitation(invitation.InviteCode, userID)
            if err == nil {
                atomic.AddInt32(&successCount, 1)
            }
        }(fmt.Sprintf("user_%d", i))
    }

    wg.Wait()

    // 成功数の検証: MaxUsage=5なので5人のみ成功すべき
    wantSuccessCount := int32(5)
    if diff := cmp.Diff(wantSuccessCount, successCount); diff != "" {
        t.Errorf("successCount mismatch (-want +got):\n%s", diff)
    }

    // 最終使用回数の検証
    finalInvitation, _ := invitationRepo.GetByCode(invitation.InviteCode)
    wantUsageCount := 5
    if diff := cmp.Diff(wantUsageCount, finalInvitation.UsageCount); diff != "" {
        t.Errorf("UsageCount mismatch (-want +got):\n%s", diff)
    }
}
```

### 22.3. イベント管理のテスト

#### 繰り返しイベントとタイムゾーン処理

```go
func TestEventRecurrenceCalculation(t *testing.T) {
    tests := []struct {
        name           string
        baseEvent      *CommunityEvent
        recurrenceRule RecurrenceRule
        wantCount      int
        timeRange      TimeRange
    }{
        {
            name: "正常系: 週次繰り返しで4週分のイベントが生成される",
            baseEvent: &CommunityEvent{
                Title:     "Weekly Meeting",
                StartTime: time.Date(2025, 8, 1, 10, 0, 0, 0, time.UTC),
                EndTime:   time.Date(2025, 8, 1, 11, 0, 0, 0, time.UTC),
            },
            recurrenceRule: RecurrenceRule{
                Type:      RecurrenceWeekly,
                Interval:  1,
                EndDate:   time.Date(2025, 8, 29, 0, 0, 0, 0, time.UTC),
            },
            wantCount: 4,
            timeRange: TimeRange{
                Start: time.Date(2025, 8, 1, 0, 0, 0, 0, time.UTC),
                End:   time.Date(2025, 8, 31, 23, 59, 59, 0, time.UTC),
            },
        },
        {
            name: "正常系: 月次繰り返しでタイムゾーン変換が正しく処理される",
            baseEvent: &CommunityEvent{
                Title:     "Monthly Review",
                StartTime: time.Date(2025, 8, 15, 14, 0, 0, 0, jstTimezone()),
                EndTime:   time.Date(2025, 8, 15, 15, 0, 0, 0, jstTimezone()),
            },
            recurrenceRule: RecurrenceRule{
                Type:     RecurrenceMonthly,
                Interval: 1,
                Count:    3,
                Timezone: "Asia/Tokyo",
            },
            wantCount: 3,
            timeRange: TimeRange{
                Start: time.Date(2025, 8, 1, 0, 0, 0, 0, time.UTC),
                End:   time.Date(2025, 10, 31, 23, 59, 59, 0, time.UTC),
            },
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            eventService := NewEventService(mockTimeProvider())

            occurrences := eventService.GenerateRecurringEvents(
                tt.baseEvent, tt.recurrenceRule, tt.timeRange)

            // 生成件数の検証
            if diff := cmp.Diff(tt.wantCount, len(occurrences)); diff != "" {
                t.Errorf("occurrences count mismatch (-want +got):\n%s", diff)
            }

            // 各イベント間の間隔が正しいか検証
            for i := 1; i < len(occurrences); i++ {
                prev := occurrences[i-1]
                curr := occurrences[i]

                expectedInterval := calculateExpectedInterval(tt.recurrenceRule)
                actualInterval := curr.StartTime.Sub(prev.StartTime)

                if diff := cmp.Diff(expectedInterval, actualInterval); diff != "" {
                    t.Errorf("recurrence interval mismatch at index %d (-want +got):\n%s", i, diff)
                }
            }
        })
    }
}

func TestEventParticipantManagement(t *testing.T) {
    tests := []struct {
        name            string
        maxParticipants int
        currentCount    int
        newParticipants int
        want            ParticipationResult
    }{
        {
            name:            "正常系: 定員内での参加が許可される",
            maxParticipants: 100,
            currentCount:    50,
            newParticipants: 25,
            want:            ParticipationResultSuccess,
        },
        {
            name:            "異常系: 定員超過で参加が拒否される",
            maxParticipants: 50,
            currentCount:    45,
            newParticipants: 10,
            want:            ParticipationResultCapacityExceeded,
        },
        {
            name:            "正常系: 無制限定員イベントは常に参加可能",
            maxParticipants: -1, // Unlimited
            currentCount:    1000,
            newParticipants: 500,
            want:            ParticipationResultSuccess,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            event := &CommunityEvent{
                ID:               EventID("event_123"),
                MaxParticipants:  tt.maxParticipants,
                ParticipantCount: tt.currentCount,
            }

            eventService := NewEventService(mockEventRepository())

            got := eventService.AddParticipants(event, tt.newParticipants)

            if diff := cmp.Diff(tt.want, got); diff != "" {
                t.Errorf("AddParticipants() mismatch (-want +got):\n%s", diff)
            }
        })
    }
}
```

### 22.4. コミュニティ成長制限とスケーリングテスト

```go
func TestCommunityGrowthLimitsAndScaling(t *testing.T) {
    tests := []struct {
        name               string
        communityTier      CommunityTier
        currentMembers     int
        membershipRequests int
        wantAdmitted       int
        wantRejected       int
    }{
        {
            name:               "正常系: スタンダードティアで制限内の全メンバーが承認される",
            communityTier:      TierStandard,
            currentMembers:     500,
            membershipRequests: 100,
            wantAdmitted:       100,
            wantRejected:       0,
        },
        {
            name:               "正常系: スタンダードティアで上限に達した場合は部分承認される",
            communityTier:      TierStandard,
            currentMembers:     950,
            membershipRequests: 100,
            wantAdmitted:       50,
            wantRejected:       50,
        },
        {
            name:               "正常系: アドバンスドティアでより大きなコミュニティが処理される",
            communityTier:      TierAdvanced,
            currentMembers:     5000,
            membershipRequests: 1000,
            wantAdmitted:       1000,
            wantRejected:       0,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            community := &Community{
                ID:          CommunityID("comm_123"),
                Tier:        tt.communityTier,
                MemberCount: tt.currentMembers,
            }

            communityService := NewCommunityService(mockCommunityRepository())

            gotAdmitted, gotRejected := communityService.ProcessMembershipRequests(
                community, tt.membershipRequests)

            if diff := cmp.Diff(tt.wantAdmitted, gotAdmitted); diff != "" {
                t.Errorf("admitted mismatch (-want +got):\n%s", diff)
            }
            if diff := cmp.Diff(tt.wantRejected, gotRejected); diff != "" {
                t.Errorf("rejected mismatch (-want +got):\n%s", diff)
            }
        })
    }
}

func TestCommunityScalingMetrics(t *testing.T) {
    // 異なるスケールでのコミュニティパフォーマンスメトリクステスト
    scales := []struct {
        name        string
        memberCount int
        topicCount  int
        eventCount  int
    }{
        {"正常系: 小規模コミュニティ", 100, 5, 2},
        {"正常系: 中規模コミュニティ", 1000, 20, 10},
        {"正常系: 大規模コミュニティ", 10000, 50, 25},
        {"正常系: エンタープライズ規模コミュニティ", 50000, 100, 50},
    }

    for _, scale := range scales {
        t.Run(scale.name, func(t *testing.T) {
            community := createTestCommunityWithScale(
                scale.memberCount, scale.topicCount, scale.eventCount)

            // メンバー一覧取得のパフォーマンス計測
            startTime := time.Now()

            members, err := communityService.GetMembers(community.ID, PaginationParams{
                Limit:  50,
                Offset: 0,
            })

            memberListDuration := time.Since(startTime)

            if err != nil {
                t.Fatalf("GetMembers() unexpected error: %v", err)
            }
            if len(members) > 50 {
                t.Errorf("GetMembers() returned %d members, want <= 50", len(members))
            }

            // スケールに応じたパフォーマンス検証
            expectedMaxDuration := getExpectedDurationForScale(scale.name)
            if memberListDuration > expectedMaxDuration {
                t.Errorf("GetMembers() took %v, want <= %v", memberListDuration, expectedMaxDuration)
            }
        })
    }
}
```

### 22.5. トピック・スレッド管理のテスト

```go
func TestTopicThreadManagement(t *testing.T) {
    tests := []struct {
        name         string
        topicType    TopicType
        threadAction ThreadAction
        userRole     MembershipRole
        want         ThreadActionResult
    }{
        {
            name:         "正常系: モデレーターが投稿をピン留めできる",
            topicType:    TopicTypeGeneral,
            threadAction: ThreadActionPin,
            userRole:     RoleModerator,
            want:         ThreadActionResultSuccess,
        },
        {
            name:         "異常系: 一般メンバーはピン留めできない",
            topicType:    TopicTypeGeneral,
            threadAction: ThreadActionPin,
            userRole:     RoleMember,
            want:         ThreadActionResultPermissionDenied,
        },
        {
            name:         "正常系: オーナーがアナウンストピックをアーカイブできる",
            topicType:    TopicTypeAnnouncement,
            threadAction: ThreadActionArchive,
            userRole:     RoleOwner,
            want:         ThreadActionResultSuccess,
        },
        {
            name:         "異常系: モデレーターはアナウンスをアーカイブできない",
            topicType:    TopicTypeAnnouncement,
            threadAction: ThreadActionArchive,
            userRole:     RoleModerator,
            want:         ThreadActionResultPermissionDenied,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            topic := &Topic{
                ID:   TopicID("topic_123"),
                Type: tt.topicType,
            }

            membership := &Membership{
                Role: tt.userRole,
            }

            topicService := NewTopicService(mockTopicRepository())

            got := topicService.ExecuteThreadAction(
                topic, membership, tt.threadAction)

            if diff := cmp.Diff(tt.want, got); diff != "" {
                t.Errorf("ExecuteThreadAction() mismatch (-want +got):\n%s", diff)
            }
        })
    }
}

func TestTopicDisplayOrdering(t *testing.T) {
    // トピック表示順序と可視性ルールのテスト
    topics := []*Topic{
        {ID: "topic_1", DisplayOrder: 1, Type: TopicTypeAnnouncement},
        {ID: "topic_2", DisplayOrder: 2, Type: TopicTypeGeneral},
        {ID: "topic_3", DisplayOrder: 3, Type: TopicTypeGeneral},
        {ID: "topic_4", DisplayOrder: 4, Type: TopicTypeArchived},
    }

    tests := []struct {
        name         string
        userRole     MembershipRole
        showArchived bool
        wantIDs      []string
    }{
        {
            name:         "正常系: メンバーはアクティブなトピックのみ表示される",
            userRole:     RoleMember,
            showArchived: false,
            wantIDs:      []string{"topic_1", "topic_2", "topic_3"},
        },
        {
            name:         "正常系: モデレーターはアーカイブ含む全トピックが表示される",
            userRole:     RoleModerator,
            showArchived: true,
            wantIDs:      []string{"topic_1", "topic_2", "topic_3", "topic_4"},
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            topicService := NewTopicService(mockTopicRepository())
            membership := &Membership{Role: tt.userRole}

            visibleTopics := topicService.GetVisibleTopics(
                topics, membership, tt.showArchived)

            gotIDs := extractTopicIDs(visibleTopics)
            if diff := cmp.Diff(tt.wantIDs, gotIDs); diff != "" {
                t.Errorf("GetVisibleTopics() IDs mismatch (-want +got):\n%s", diff)
            }
        })
    }
}
```

### 22.6. パフォーマンステストフレームワーク

```go
func TestCommunityServicePerformance(t *testing.T) {
    if testing.Short() {
        t.Skip("Skipping performance tests in short mode")
    }

    performanceTests := []struct {
        name        string
        operation   func(*CommunityService) error
        maxDuration time.Duration
        maxMemoryMB int
    }{
        {
            name: "正常系: 大規模コミュニティのメンバー一覧取得が200ms以内に完了する",
            operation: func(svc *CommunityService) error {
                _, err := svc.GetMembers("large_community", PaginationParams{
                    Limit:  100,
                    Offset: 0,
                })
                return err
            },
            maxDuration: 200 * time.Millisecond,
            maxMemoryMB: 50,
        },
        {
            name: "正常系: コミュニティ統計計算が100ms以内に完了する",
            operation: func(svc *CommunityService) error {
                _, err := svc.GetCommunityStatistics("test_community")
                return err
            },
            maxDuration: 100 * time.Millisecond,
            maxMemoryMB: 20,
        },
        {
            name: "正常系: 1000ユーザーの一括権限チェックが500ms以内に完了する",
            operation: func(svc *CommunityService) error {
                userIDs := generateTestUserIDs(1000)
                _, err := svc.BatchCheckPermissions("test_community", userIDs, PermissionReadPosts)
                return err
            },
            maxDuration: 500 * time.Millisecond,
            maxMemoryMB: 100,
        },
    }

    for _, tt := range performanceTests {
        t.Run(tt.name, func(t *testing.T) {
            // パフォーマンスモニタリングのセットアップ
            var memStats runtime.MemStats
            runtime.GC()
            runtime.ReadMemStats(&memStats)
            initialMem := memStats.Alloc

            communityService := setupPerformanceTestService()

            // 実行時間計測
            startTime := time.Now()
            err := tt.operation(communityService)
            duration := time.Since(startTime)

            // メモリ使用量計測
            runtime.ReadMemStats(&memStats)
            memoryUsedMB := int((memStats.Alloc - initialMem) / 1024 / 1024)

            // 検証
            if err != nil {
                t.Fatalf("operation unexpected error: %v", err)
            }
            if duration > tt.maxDuration {
                t.Errorf("operation took %v, want <= %v", duration, tt.maxDuration)
            }
            if memoryUsedMB > tt.maxMemoryMB {
                t.Errorf("memory usage %dMB, want <= %dMB", memoryUsedMB, tt.maxMemoryMB)
            }

            // パフォーマンスメトリクスをログ出力
            t.Logf("Performance metrics for %s: Duration=%v, Memory=%dMB",
                tt.name, duration, memoryUsedMB)
        })
    }
}
```

### 22.7. セキュリティ・権限テスト

```go
func TestSecurityAndPrivacyEnforcement(t *testing.T) {
    tests := []struct {
        name           string
        communityType  CommunityVisibility
        userMembership *Membership
        requestedData  DataType
        wantAccess     bool
        wantDataLevel  DataLevel
    }{
        {
            name:           "正常系: 公開コミュニティのメンバー一覧は全員に表示される",
            communityType:  VisibilityPublic,
            userMembership: nil, // Non-member
            requestedData:  DataTypeMemberList,
            wantAccess:     true,
            wantDataLevel:  DataLevelPublic,
        },
        {
            name:           "異常系: 非公開コミュニティの詳細は非メンバーに非表示",
            communityType:  VisibilityPrivate,
            userMembership: nil,
            requestedData:  DataTypeCommunityDetails,
            wantAccess:     false,
            wantDataLevel:  DataLevelNone,
        },
        {
            name:           "正常系: 招待制コミュニティのトピックはメンバーに表示される",
            communityType:  VisibilityInviteOnly,
            userMembership: &Membership{Status: StatusActive, Role: RoleMember},
            requestedData:  DataTypeTopicList,
            wantAccess:     true,
            wantDataLevel:  DataLevelMember,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            community := &Community{
                Visibility: tt.communityType,
            }

            securityService := NewSecurityService()

            accessResult := securityService.CheckDataAccess(
                community, tt.userMembership, tt.requestedData)

            if diff := cmp.Diff(tt.wantAccess, accessResult.Allowed); diff != "" {
                t.Errorf("Allowed mismatch (-want +got):\n%s", diff)
            }
            if accessResult.Allowed {
                if diff := cmp.Diff(tt.wantDataLevel, accessResult.DataLevel); diff != "" {
                    t.Errorf("DataLevel mismatch (-want +got):\n%s", diff)
                }
            }
        })
    }
}
```

### 22.8. テスト実行ガイドライン

#### テスト分類と実行方法

```bash
# 単体テスト（高速）
go test ./... -short

# 統合テスト（中速）
go test ./... -tags=integration

# パフォーマンステスト（低速）
go test ./... -tags=performance

# 全テストスイート
go test ./... -tags="integration,performance"

# カバレッジレポート生成
go test ./... -coverprofile=coverage.out
go tool cover -html=coverage.out -o coverage.html
```

#### モック生成戦略

```bash
# 全モック生成
go generate ./...

# 特定サービスのモック生成
//go:generate mockgen -source=./domain/repository/community_repository.go -destination=./tests/mocks/mock_community_repository.go
//go:generate mockgen -source=./domain/service/permission_service.go -destination=./tests/mocks/mock_permission_service.go
```

この包括的なテスト戦略により、avion-community サービスの複雑な機能要件と性能要件を確実に検証し、本番環境でも安定稼働する高品質なサービスを実現します。

## 23. セキュリティ実装ガイドライン

本サービスのセキュリティ実装は、以下の共通セキュリティガイドラインに準拠します：

### 適用セキュリティガイドライン

#### XSS Prevention
[XSS Prevention Guidelines](../common/security/xss-prevention.md)に従い、以下を実装：

- **コミュニティコンテンツ処理**:
  - コミュニティ投稿のHTML/Markdownサニタイゼーション
  - ユーザープロフィール・自己紹介文のエスケープ処理
  - カスタム絵文字・リアクション名の安全な処理
  - イベント説明・アナウンスのXSS対策

- **表示コンテンツ**:
  - コミュニティ名・説明文の安全な表示
  - トピックタイトル・内容のサニタイゼーション
  - メンバーリストでのユーザー名エスケープ
  - 招待メッセージの安全な処理

#### SQL Injection Prevention
[SQL Injection Prevention Guidelines](../common/security/sql-injection-prevention.md)に従い、以下を実装：

- **検索・フィルタリング**:
  - コミュニティ検索でのパラメータバインディング
  - メンバー検索クエリのプリペアドステートメント使用
  - トピックフィルタリングでの安全なクエリ構築
  - イベント検索での入力値サニタイゼーション

- **統計・集計処理**:
  - コミュニティ統計取得での安全なクエリ実行
  - メンバー数集計でのSQLインジェクション対策
  - アクティビティ分析クエリのパラメータ化

#### Security Headers
[Security Headers Guidelines](../common/security/security-headers.md)に従い、以下を実装：

- **APIエンドポイント**:
  - コミュニティAPIでのCSP設定
  - ユーザー生成コンテンツ配信時のセキュリティヘッダー
  - X-Content-Type-Options: `nosniff`設定
  - X-Frame-Options: `DENY`によるクリックジャッキング対策

- **コンテンツ配信**:
  - メディアファイル配信時のセキュリティヘッダー
  - CORS設定による適切なアクセス制御
  - Referrer-Policy設定によるプライバシー保護

### コミュニティ固有のセキュリティ要件

#### 権限管理とアクセス制御
- **ロールベースアクセス制御（RBAC）**:
  - Owner > Moderator > Member の階層的権限管理
  - カスタムロールの権限検証
  - 権限昇格攻撃の防止

- **プライバシー設定**:
  - プライベートコミュニティのコンテンツ保護
  - 招待制コミュニティのアクセス制御
  - メンバー情報の適切な公開範囲制御

#### モデレーション機能
- **コンテンツフィルタリング**:
  - 不適切コンテンツの自動検出
  - スパム投稿の防止
  - 悪意あるリンクのブロック

- **監査ログ**:
  - モデレーション活動の完全な記録
  - 権限変更の追跡
  - セキュリティイベントのログ記録

### 実装チェックリスト

- [ ] 全てのユーザー入力に対するサニタイゼーション実装
- [ ] SQLクエリでのプリペアドステートメント使用
- [ ] セキュリティヘッダーの適切な設定
- [ ] RBAC権限チェックの実装
- [ ] プライベートコミュニティのアクセス制御
- [ ] モデレーション機能のセキュリティ強化
- [ ] 監査ログの実装と保護
- [ ] レート制限の実装

### セキュリティテスト要件

- **ペネトレーションテスト**: コミュニティ機能の脆弱性診断
- **権限エスカレーションテスト**: ロール権限の境界テスト
- **プライバシーテスト**: コンテンツアクセス制御の検証
- **インジェクションテスト**: XSS/SQLインジェクション対策の確認