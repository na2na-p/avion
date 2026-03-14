# Design Doc: avion-notification

**Author:** Cline
**Last Updated:** 2026/03/14

## 1. Summary (これは何？)

- **一言で:** Avionにおけるユーザーへの通知（メンション、フォロー、リアクション、リポストなど）を生成、管理、および配信 (SSE, Web Push) するマイクロサービスを実装します。
- **目的:** ユーザーに関連するイベントを検知し、通知データを作成・永続化します。リアルタイム (SSE) およびプッシュ (Web Push) でユーザーに通知を届け、未読管理機能を提供します。

## 2. テスト戦略

このサービスでは、[共通テスト戦略](../common/testing-strategy.md)に従ってテストを実装します。

### テスト方針
- **TDD必須**: インターフェース定義 → テスト作成 → 実装の順序を厳守
- **カバレッジ目標**: ユニットテスト90%以上、クリティカルパス95%以上
- **テーブル駆動テスト**: 全テストで必須
- **モック生成**: `go.uber.org/mock/gomock`使用

### サービス固有のテスト要件
- **リアルタイム通知配信のテスト**: SSE接続、Web Push配信のモック化
- **イベント駆動アーキテクチャのテスト**: NATS JetStreamイベントの送受信テスト
- **通知グループ化ロジックのテスト**: 複数通知の適切なグループ化
- **外部Pushサービスのテスト**: VAPID、FCMクライアントのモック化
- **並行通知処理のテスト**: 大量通知の並行配信テスト

### E2Eテスト

このサービスのE2Eテストは、[共通E2Eテスト戦略](../common/e2e-testing-strategy.md)に従って実装します。

#### 主要なE2Eテストシナリオ
- イベント発生から通知配信までの完全な非同期フロー
- プッシュ通知（VAPID Web Push、FCM）の実際の配信確認
- SSEリアルタイム通知のWebブラウザでの受信テスト
- メール通知の送信とテンプレート適用確認
- 通知設定（ミュート、フィルター）による配信制御
- 複数通知のグループ化と重複回避機能
- 通知履歴の管理と既読状態の同期
- 大量ユーザーでの通知配信性能とスケーラビリティ

詳細は[共通E2Eテスト戦略ドキュメント](../common/e2e-testing-strategy.md)を参照してください。

詳細は[共通テスト戦略ドキュメント](../common/testing-strategy.md)を参照してください。

## 3. 技術スタック

このサービスでは、[共通Goバックエンド技術スタックガイドライン](../common/architecture/go-backend-framework.md)に従った実装を行います。

### 主要技術
- **言語:** Go 1.25.1
- **データベース:** PostgreSQL 17
- **キャッシュ/キュー:** Redis 8+
- **イベント配信:** NATS JetStream
- **HTTPルーティング:** Chi v5
- **RPC:** ConnectRPC
- **ミドルウェア:** 標準net/httpベースの共通ミドルウェア
- **通知関連:** Server-Sent Events (SSE)、WebPush標準実装

詳細な実装パターンおよびライブラリの使用方法については、[ガイドライン](../common/architecture/go-backend-framework.md)を参照してください。

## 4. Background & Links (背景と関連リンク)

- ユーザーエンゲージメント維持とコミュニケーション促進のため、関連イベントの通知が必要。
- 通知生成・管理・配信ロジックを他サービスから分離するため。
- PWAとしての体験向上のため、Web Pushに対応する。
- [PRD: avion-notification](./prd.md)
- [Avion アーキテクチャ概要](../common/architecture.md)

## 5. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

- 各種イベント (フォロー、メンション、リアクション、リポスト、引用リポスト、投票、投票終了、フォローリクエスト、フォローリクエスト承認、投稿更新等) を購読 (NATS JetStream)。
- 特定ユーザーの投稿通知（通知を有効にしたユーザーが新規投稿した際の通知）。
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
- 管理者向け通知 (新規ユーザー登録、通報受信など) の実装。
- モデレーション関連通知（モデレーターからの警告、関係切断通知）。
- サーバーアナウンス配信機能。
- 通知のグループ化（大量の同種通知を集約表示）。

### Non-Goals (やらないこと)

- **イベント発生元のビジネスロジック:** 各サービスが担当。
- **通知内容の詳細データ保持:** 概要と参照IDのみ保持。
- **通知の優先度付け (初期)。**
- **メール通知。**
- **WebSocket。**

## 6. Architecture (どうやって作る？)

### 6.1. レイヤードアーキテクチャ (DDD準拠)

通知サービスは、DDD (Domain-Driven Design) の戦術的パターンに基づいて設計されており、以下の4層で構成されています：

#### Domain Layer (ドメイン層)
- **責務**: 通知システムのビジネスルールとドメインロジックをカプセル化
- **主要コンポーネント**: 
  - Aggregates: Notification, WebPushSubscription, NotificationEvent, SSEConnectionManager, Announcement
  - Entities: NotificationPreference, SSEConnection, WebPushCredential, NotificationGroup, UserNotificationPreference
  - Value Objects: 各種ID、通知属性、Web Push関連、SSE関連、数値・時刻
  - Domain Services: NotificationPolicy, WebPushEncryption, NotificationFactory, NotificationPreferenceService, SSEBroadcaster, NotificationGroupingService, NotificationDeliveryStrategy, AnnouncementDistributionService
  - Repository Interfaces: 集約の永続化インターフェース
- **依存関係**: 他の層に依存しない（最も安定した層）
- **特徴**: 通知配信の複雑なビジネスルール（配信チャネル選択、再送制御、グループ化戦略）を封じ込め

#### Use Case Layer (ユースケース層)
- **責務**: 通知システム固有のアプリケーションビジネスルールを実装
- **主要コンポーネント**: 
  - Command Use Cases: イベント処理、通知操作、サブスクリプション管理
  - Query Use Cases: 通知リスト取得、未読件数取得、設定取得
  - DTOs: レイヤー間データ転送オブジェクト
  - External Service Interfaces: 他サービスとの連携インターフェース
- **依存関係**: Domain Layerにのみ依存
- **特徴**: 通知イベント処理の複雑なワークフロー（冪等性チェック、配信チャネル選択、エラーハンドリング）を制御

#### Infrastructure Layer (インフラストラクチャ層)
- **責務**: 外部システムとの統合、通知配信の技術的実装詳細
- **主要コンポーネント**: 
  - Repository実装: PostgreSQL、Redis
  - Query Service実装: 参照専用データアクセス
  - External Service実装: Web Push、SSE、gRPC クライアント
  - Event Handling: NATS JetStream Consumer、SSE/Web Push Event Publisher
  - Cache: 未読件数、通知設定、SSE接続管理
- **依存関係**: Domain LayerとUse Case Layerに依存
- **特徴**: Web Push暗号化、SSE接続管理、NATS JetStream処理等の技術的複雑性を隠蔽

#### Handler Layer (ハンドラー層)
- **責務**: 外部からのリクエスト受付と適切なUse Caseへの委譲
- **主要コンポーネント**: 
  - gRPCハンドラー: 通知CRUD操作
  - イベントハンドラー: 通知イベント購読処理
  - SSEハンドラー: リアルタイム通知配信
  - バッチハンドラー: 古い通知削除等の定期処理
- **依存関係**: Use Case Layerに依存
- **特徴**: 多様な入力ソース（gRPC、NATS JetStream、SSE、バッチ）を統一的に処理

### 主要コンポーネント

- **主要コンポーネント:**
    - `avion-notification (Go, Kubernetes Deployment)`: 本サービス。gRPCサーバー、SSEサーバー、Web Push送信機能、NATS JetStream Consumer。
    - `avion-gateway (Go)`: gRPC/SSEリクエストのルーティング元。
    - `avion-user (Go)`: 通知設定取得 (gRPC、将来)。
    - `PostgreSQL`: 通知データ、Web Pushサブスクリプション情報を永続化。
    - `NATS`: イベント通知 (JetStream)。
    - `Redis`: SSE接続管理、キャッシュ。
    - `Observability Stack`: メトリクス、トレース、ログ収集。
    - イベント発行元サービス (`avion-user`, `avion-post`, `avion-reaction`, `avion-activitypub`)。
    - Web Push Service (ブラウザベンダー提供)。
- **構成図:** (アーキテクチャ概要図を参照)
    - [Avion アーキテクチャ概要](../common/architecture.md)
- **ポイント:**
    - イベントをNATS JetStreamから購読し、通知データを生成・保存。冪等性を確保。
    - gRPC APIで通知リストや未読件数を提供。
    - SSEでリアルタイム更新トリガーを通知。
    - Web Pushでプッシュ通知を送信（暗号化）。
    - ステートレス設計 (SSE接続状態はRedisで管理)。
    - 定期的なデータ削除ポリシーを適用。

### 6.2. レイヤードアーキテクチャ (DDD準拠) - 詳細設計

#### Domain Layer (ドメイン層)
- **Aggregates:**
  - Notification: 通知のライフサイクルと整合性を管理
  - WebPushSubscription: Web Pushサブスクリプションを管理
  - NotificationEvent: 通知イベント処理を管理
  - SSEConnectionManager: SSE接続のライフサイクル管理
  - Announcement: サーバーアナウンスを管理
- **Entities:**
  - NotificationPreference: ユーザーの通知設定
  - SSEConnection: アクティブなSSE接続情報
  - WebPushCredential: Web Push認証情報
  - NotificationGroup: 通知のグルーピング情報
  - UserNotificationPreference: 特定ユーザーに対する通知設定
- **Value Objects:**
  - 識別子: NotificationID, EventID, RecipientUserID, ActorUserID, TargetDropID, UserID, ConnectionID, SubscriptionID, AnnouncementID, GroupID
  - 通知属性: NotificationType (follow, mention, reaction, repost, quote_repost, reply, poll_vote, poll_end, follow_request, follow_request_accepted, drop_updated, status, system, admin_user_registered, admin_report_created, moderation_warning, severed_relationships, announcement), EventType, ReadStatus, NotificationData, EventData
  - Web Push: WebPushEndpoint, WebPushKeys, VAPIDKeys, PushPayload, BrowserInfo
  - SSE: SSEConnectionID, SSEEvent, SSEConnectionStatus
  - 数値・時刻: UnreadCount, CreatedAt, ProcessedAt, ReadAt, ExpiresAt, StartAt, EndAt
  - グループ化: GroupType, GroupCount, LatestActors
- **Domain Services:**
  - **NotificationPolicy**: 通知生成のビジネスルールを実装するドメインサービス
    - 責務: 通知の妥当性検証、通知タイプに応じたルール適用、通知抑制判定
    - メソッド:
      ```go
      type NotificationPolicy interface {
          ShouldCreateNotification(event NotificationEvent, recipient RecipientUserID) bool
          ValidateNotificationData(notificationType NotificationType, data NotificationData) error
          DetermineNotificationPriority(notification Notification) NotificationPriority
          ShouldGroupNotifications(existing []Notification, new Notification) bool
          ApplyMuteRules(notification Notification, preferences NotificationPreference) bool
      }
      ```
  - **WebPushEncryption**: Web Pushペイロード暗号化（RFC 8291準拠）を実装するドメインサービス
    - 責務: Web Pushメッセージの暗号化、VAPID認証ヘッダー生成、ペイロード制限の適用
    - メソッド:
      ```go
      type WebPushEncryption interface {
          EncryptPayload(message PushPayload, subscription WebPushSubscription) ([]byte, error)
          GenerateVAPIDHeaders(endpoint WebPushEndpoint, privateKey VAPIDPrivateKey) (map[string]string, error)
          ValidateSubscription(subscription WebPushSubscription) error
          CalculatePayloadSize(payload PushPayload) (int, error)
      }
      ```
  - **NotificationFactory**: イベントから通知生成を実装するドメインサービス
    - 責務: イベントタイプに応じた通知生成、通知内容の構築、メタデータの設定
    - メソッド:
      ```go
      type NotificationFactory interface {
          CreateNotificationFromEvent(event NotificationEvent) (Notification, error)
          CreateGroupedNotification(notifications []Notification, groupType GroupType) (Notification, error)
          EnrichNotificationData(notification Notification, actor User, target interface{}) Notification
          GenerateNotificationMessage(notificationType NotificationType, data NotificationData) NotificationMessage
      }
      ```
  - **NotificationPreferenceService**: 通知設定の適用を実装するドメインサービス
    - 責務: ユーザー通知設定の検証、デフォルト設定の適用、設定の階層的マージ
    - メソッド:
      ```go
      type NotificationPreferenceService interface {
          GetEffectivePreferences(userID UserID, notificationType NotificationType) NotificationPreference
          MergePreferences(global NotificationPreference, specific UserNotificationPreference) NotificationPreference
          ValidatePreferences(preferences NotificationPreference) error
          ApplyDefaultPreferences(userID UserID) NotificationPreference
      }
      ```
  - **SSEBroadcaster**: SSEイベントのブロードキャストを実装するドメインサービス
    - 責務: SSEイベントの配信、接続管理、イベントフィルタリング
    - メソッド:
      ```go
      type SSEBroadcaster interface {
          BroadcastNotification(notification Notification, connections []SSEConnection) error
          FilterConnectionsForUser(userID UserID, connections []SSEConnection) []SSEConnection
          GenerateSSEEvent(notification Notification) SSEEvent
          HandleConnectionHeartbeat(connectionID SSEConnectionID) error
      }
      ```
  - **NotificationGroupingService**: 通知のグループ化ロジックを実装するドメインサービス
    - 責務: 同種通知の集約、グループ化ルールの適用、グループ表示データの生成
    - メソッド:
      ```go
      type NotificationGroupingService interface {
          DetermineGroupingStrategy(notifications []Notification) GroupingStrategy
          GroupNotifications(notifications []Notification, strategy GroupingStrategy) []NotificationGroup
          UpdateGroupWithNewNotification(group NotificationGroup, notification Notification) NotificationGroup
          ShouldBreakGroup(group NotificationGroup, newNotification Notification) bool
      }
      ```
  - **NotificationDeliveryStrategy**: 通知配信戦略を実装するドメインサービス
    - 責務: 配信チャネルの選択、配信タイミングの決定、再送制御
    - メソッド:
      ```go
      type NotificationDeliveryStrategy interface {
          SelectDeliveryChannels(notification Notification, preferences NotificationPreference) []DeliveryChannel
          DetermineDeliveryTiming(notification Notification, userTimezone Timezone) DeliveryTiming
          ShouldRetryDelivery(notification Notification, failureCount int) bool
          CalculateBackoffDelay(attemptNumber int) time.Duration
      }
      ```
  - **AnnouncementDistributionService**: サーバーアナウンスの配信を実装するドメインサービス
    - 責務: アナウンス対象ユーザーの選定、配信スケジューリング、既読管理
    - メソッド:
      ```go
      type AnnouncementDistributionService interface {
          SelectTargetUsers(announcement Announcement) []UserID
          ScheduleAnnouncement(announcement Announcement) DistributionSchedule
          TrackAnnouncementDelivery(announcementID AnnouncementID, userID UserID) error
          CalculateAnnouncementReach(announcementID AnnouncementID) AnnouncementMetrics
      }
      ```
- **Repository Interfaces:**
  - NotificationRepository
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_notification_repository.go -package=mocks
    ```
  - WebPushSubscriptionRepository
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_webpush_subscription_repository.go -package=mocks
    ```
  - NotificationEventRepository
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_notification_event_repository.go -package=mocks
    ```
  - SSEConnectionRepository
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_sse_connection_repository.go -package=mocks
    ```

#### Use Case Layer (ユースケース層)
- **Command Use Cases (更新系):**
  - ProcessNotificationEventCommandUseCase: 通知イベント処理（イベントハンドラ用）
  - ProcessPollEventCommandUseCase: 投票イベント処理（投票/投票終了）
  - ProcessFollowRequestEventCommandUseCase: フォローリクエストイベント処理
  - ProcessDropUpdateEventCommandUseCase: 投稿更新イベント処理
  - ProcessStatusEventCommandUseCase: 特定ユーザーの投稿通知処理
  - ProcessModerationEventCommandUseCase: モデレーション関連通知処理
  - ProcessAdminEventCommandUseCase: 管理者向け通知処理
  - GroupNotificationsCommandUseCase: 通知グループ化処理
  - MarkAsReadCommandUseCase: 通知既読化処理（PATCHリクエスト用）
  - MarkAllAsReadCommandUseCase: 一括既読化処理（PATCHリクエスト用）
  - SubscribeWebPushCommandUseCase: Web Pushサブスクリプション登録（POSTリクエスト用）
  - UnsubscribeWebPushCommandUseCase: Web Pushサブスクリプション削除（DELETEリクエスト用）
  - EstablishSSEConnectionCommandUseCase: SSE接続確立処理（POST相当）
  - CloseSSEConnectionCommandUseCase: SSE接続切断処理（DELETE相当）
  - UpdateNotificationPreferencesCommandUseCase: 通知設定更新（PATCHリクエスト用）
  - UpdateUserNotificationPreferenceCommandUseCase: 特定ユーザー通知設定更新
  - PublishAnnouncementCommandUseCase: アナウンス配信処理
  - DeleteOldNotificationsCommandUseCase: 古い通知削除処理（バッチ処理）
- **Query Use Cases (参照系):**
  - GetNotificationsQueryUseCase: 通知リスト取得処理（GETリクエスト用）
  - GetPollNotificationsQueryUseCase: 投票関連通知の取得処理
  - GetFollowRequestNotificationsQueryUseCase: フォローリクエスト関連通知の取得処理
  - GetUnreadCountQueryUseCase: 未読件数取得処理（GETリクエスト用）
  - GetNotificationPreferencesQueryUseCase: 通知設定取得処理（GETリクエスト用）
  - GetActiveSSEConnectionsQueryUseCase: アクティブSSE接続取得（管理用）
- **Query Service Interfaces:**
  - NotificationQueryService: 通知情報参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_notification_query_service.go -package=mocks
    ```
  - WebPushSubscriptionQueryService: Web Pushサブスクリプション参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_webpush_subscription_query_service.go -package=mocks
    ```
  - SSEConnectionQueryService: SSE接続情報参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_sse_connection_query_service.go -package=mocks
    ```
- **DTOs:**
  - NotificationDTO: 通知情報の転送オブジェクト
  - UnreadCountDTO: 未読件数の転送オブジェクト
  - WebPushSubscriptionDTO: Web Pushサブスクリプションの転送オブジェクト
  - NotificationPreferenceDTO: 通知設定の転送オブジェクト
  - SSEConnectionDTO: SSE接続情報の転送オブジェクト
- **External Service Interfaces:**
  - EventPublisher: イベント発行
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_event_publisher.go -package=mocks
    ```
  - UserServiceClient: ユーザー情報取得
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_user_service_client.go -package=mocks
    ```
  - DropServiceClient: Drop情報取得
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_drop_service_client.go -package=mocks
    ```
  - WebPushClient: Web Pushサービスへの通知送信
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_webpush_client.go -package=mocks
    ```
  - BlockServiceClient: ブロック情報取得
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_block_service_client.go -package=mocks
    ```

#### Infrastructure Layer (インフラストラクチャ層)
- **Repository Implementations (更新系):**
  - PostgreSQLNotificationRepository: 通知永続化実装
  - PostgreSQLWebPushSubscriptionRepository: Web Pushサブスクリプション永続化実装
  - RedisNotificationEventRepository: 処理済みイベント管理実装
  - RedisSSEConnectionRepository: SSE接続情報永続化実装
- **Query Service Implementations (参照系):**
  - PostgreSQLNotificationQueryService: 通知情報参照専用実装
  - PostgreSQLWebPushSubscriptionQueryService: Web Pushサブスクリプション参照専用実装
  - RedisSSEConnectionQueryService: SSE接続情報参照専用実装
- **External Service Implementations:**
  - NATSEventPublisher: NATS JetStreamを使用したイベント発行実装
  - GRPCUserServiceClient: ユーザーサービス連携実装
  - GRPCDropServiceClient: Dropサービス連携実装
  - HTTPWebPushClient: Web Pushサービスへの通知送信実装
  - GRPCBlockServiceClient: ブロックサービス連携実装
- **Event Handling:**
  - NATSJetStreamConsumer: NATS JetStream購読実装
  - SSEEventPublisher: SSEイベント配信実装
  - WebPushEventPublisher: Web Pushイベント配信実装
- **Cache:**
  - RedisUnreadCountCache: 未読件数キャッシュ
  - RedisNotificationPreferenceCache: 通知設定キャッシュ
  - RedisSSEConnectionCache: SSE接続管理キャッシュ

#### Handler Layer (ハンドラー層)
- **Command Handlers (更新系):**
  - MarkAsReadCommandHandler: 通知既読化エンドポイント（PATCH）
  - SubscribeWebPushCommandHandler: Web Pushサブスクリプション登録エンドポイント（POST）
  - UnsubscribeWebPushCommandHandler: Web Pushサブスクリプション削除エンドポイント（DELETE）
- **Query Handlers (参照系):**
  - GetNotificationsQueryHandler: 通知リスト取得エンドポイント（GET）
  - GetUnreadCountQueryHandler: 未読件数取得エンドポイント（GET）
- **Event Handlers:**
  - NotificationEventHandler: 通知イベント購読ハンドラー（Command処理）
- **SSE Handler:**
  - NotificationSSEHandler: 通知SSEストリーム配信エンドポイント
- **Batch Handlers:**
  - DeleteOldNotificationsHandler: 古い通知削除バッチハンドラー

### 6.3. ドメインモデル設計（DDD戦術的パターン）

#### Aggregate（集約ルート）

**Notification Aggregate**
- **責務**: ユーザーへの通知を管理する中核的な集約
- **集約ルート**: Notification
- **ID**: NotificationID（Value Object）
- **不変条件（ドメインルール）**:
  - **一意性制約**: 同一EventIDから生成される通知は1つのみ（冪等性保証）
  - **受信者不変性**: RecipientUserIDは作成後変更不可（データ整合性保証）
  - **通知タイプ不変性**: NotificationTypeは作成後変更不可（通知内容の一貫性保証）
  - **既読状態遷移制約**: ReadStatusは未読→既読の一方向のみ変更可能（既読の取り消し不可）
  - **既読日時制約**: ReadAtはmarkAsRead()実行時のみ設定可能（手動設定禁止）
  - **削除可能性制約**: 削除は「既読かつ30日以上経過」または「90日以上経過」の通知のみ可能
  - **有効期限制約**: ExpiresAtを過ぎた通知は新規配信対象外（既存は表示可能）
  - **配信チャネル制約**: SSE/WebPush配信は受信者の通知設定に従う
- **主要フィールド**:
  - NotificationType（Value Object）: 'follow', 'mention', 'reaction', 'repost', 'quote_repost', 'reply', 'poll_vote', 'poll_end', 'follow_request', 'follow_request_accepted', 'drop_updated', 'status', 'system', 'admin_user_registered', 'admin_report_created', 'moderation_warning', 'severed_relationships', 'announcement'
  - RecipientUserID（Value Object）: 通知受信者
  - ActorUserID（Value Object）: アクション実行者（システム通知の場合はnull）
  - TargetDropID（Value Object）: 関連するDrop（Drop関連通知の場合）
  - TargetUserID（Value Object）: 関連するユーザー（フォロー通知等の場合）
  - ReadStatus（Value Object）: 既読/未読状態（boolean with timestamp）
  - NotificationData（Value Object）: 追加情報（JSON、最大1KB）
  - CreatedAt（Value Object）: 作成日時
  - ReadAt（Value Object）: 既読化日時
  - ExpiresAt（Value Object）: 有効期限
- **関連Entity**:
  - NotificationPreference（Entity）: 通知設定
  - NotificationGroup（Entity）: グループ化情報
- **高度なドメインロジック**:
  - `markAsRead()`: 既読化処理（冪等性保証、既読日時自動設定）
  - `canBeDeleted()`: 削除可否判定（期間と既読状態の複合条件）
  - `shouldNotify(preferences)`: 通知配信可否判定（設定、ブロック状態考慮）
  - `toSSEEvent()`: SSE配信用イベント変換（接続状態考慮）
  - `toWebPushPayload(subscription)`: Web Push用ペイロード生成（暗号化対応）
  - `isExpired()`: 有効期限切れ判定（配信制御用）
  - `calculatePriority()`: 通知優先度算出（緊急度・重要度マトリクス）
  - `shouldGroup(existingNotifications)`: グループ化可否判定（同種類・同対象・時間窓）
  - `applyPrivacyFilter(requesterUserID)`: プライバシーフィルタ適用（ブロック・ミュート考慮）

**WebPushSubscription Aggregate**
- **責務**: Web Pushサブスクリプションを管理
- **集約ルート**: WebPushSubscription
- **ID**: SubscriptionID（Value Object）
- **不変条件**:
  - 同一エンドポイントのサブスクリプションは1つのみ
  - 無効なサブスクリプションは自動的に削除
  - VAPIDキーは環境変数から取得（集約内では保持しない）
- **主要フィールド**:
  - UserID（Value Object）: サブスクリプション所有者
  - WebPushEndpoint（Value Object）: PushサービスエンドポイントURL
  - CreatedAt（Value Object）: 登録日時
  - LastUsedAt（Value Object）: 最終使用日時
- **関連Entity**:
  - WebPushCredential（Entity）: 認証情報
- **ドメインロジック**:
  - `isValid()`: サブスクリプションの有効性検証
  - `shouldSendPush()`: プッシュ送信可否判定
  - `encrypt(payload)`: ペイロードの暗号化（RFC 8291準拠）
  - `handleDeliveryFailure()`: 配信失敗時の処理
  - `updateLastUsed()`: 最終使用日時更新

**NotificationEvent Aggregate**
- **責務**: 通知イベント処理を管理
- **集約ルート**: NotificationEvent
- **ID**: EventID（Value Object）
- **不変条件**:
  - EventIDは一意（冪等性保証）
  - 同一EventIDの重複処理は拒否
  - イベント処理は成功/失敗の二値
- **主要フィールド**:
  - EventType（Value Object）: 'follow_created', 'mention_created', 'reaction_created', 'repost_created', 'quote_repost_created', 'reply_created', 'poll_voted', 'poll_ended', 'follow_request_created', 'follow_request_accepted', 'drop_updated', 'drop_created', 'user_registered', 'report_created', 'moderation_action_taken', 'relationships_severed', 'announcement_published'
  - EventData（Value Object）: イベント詳細情報
  - ProcessedAt（Value Object）: 処理日時
  - ProcessingStatus（Value Object）: 'pending', 'processing', 'completed', 'failed'
- **ドメインロジック**:
  - `shouldProcess()`: 処理すべきイベントかの判定
  - `toNotification()`: Notification Aggregateへの変換
  - `extractRecipients()`: 通知対象ユーザーの抽出
  - `validate()`: イベントデータの妥当性検証
  - `markAsProcessed()`: 処理済みマーク

**SSEConnectionManager Aggregate**
- **責務**: SSE接続のライフサイクル管理
- **集約ルート**: SSEConnectionManager
- **ID**: ManagerID（Value Object）
- **不変条件**:
  - 同一ユーザーの複数接続を許可（マルチデバイス対応）
  - タイムアウトした接続は自動的にクローズ
  - 接続数には上限を設定（DoS対策）
- **主要フィールド**:
  - UserID（Value Object）: 接続ユーザー
  - ConnectionCount（Value Object）: アクティブ接続数
- **関連Entity**:
  - SSEConnection（Entity）: 個別の接続情報
- **ドメインロジック**:
  - `establishConnection()`: 新規接続の確立
  - `heartbeat()`: 接続の生存確認
  - `broadcast()`: 特定ユーザーへのイベント配信
  - `cleanup()`: タイムアウト接続の削除
  - `canEstablishNewConnection()`: 新規接続可否判定

**Announcement Aggregate**
- **責務**: サーバーアナウンスを管理
- **集約ルート**: Announcement
- **ID**: AnnouncementID（Value Object）
- **不変条件**:
  - 期間外のアナウンスは配信されない
  - 既読管理は通知と同様
- **主要フィールド**:
  - Title（Value Object）: アナウンスタイトル
  - Content（Value Object）: アナウンス内容
  - TargetUsers（Value Object）: 対象ユーザーリスト（nullで全員）
  - IsActive（Value Object）: 有効/無効フラグ
  - StartAt（Value Object）: 配信開始日時
  - EndAt（Value Object）: 配信終了日時
  - CreatedBy（Value Object）: 作成管理者ID
- **ドメインロジック**:
  - `isDeliverable()`: 配信可能かの判定（期間内かつ有効）
  - `shouldNotifyUser()`: 特定ユーザーへの配信要否判定
  - `toNotification()`: Notification Aggregateへの変換

#### Entity

**NotificationPreference**
- **所属**: Notification Aggregate
- **責務**: ユーザーの通知設定を管理
- **属性**:
  - PreferenceID（Entity識別子）
  - NotificationType（通知種別）
  - IsEnabled（有効/無効フラグ）
  - DeliveryChannels（配信チャネルのリスト）
  - UpdatedAt（最終更新日時）
- **ビジネスルール**:
  - システム通知は無効化不可
  - デフォルトは全通知有効

**SSEConnection**
- **所属**: SSEConnectionManager Aggregate
- **責務**: アクティブなSSE接続情報を保持
- **属性**:
  - ConnectionID（Entity識別子）
  - UserID（接続ユーザー）
  - EstablishedAt（接続確立時刻）
  - LastHeartbeatAt（最終生存確認時刻）
  - UserAgent（クライアント情報）
  - IPAddress（接続元IP）
- **ビジネスルール**:
  - 15秒以上heartbeatがない接続は無効
  - 同一IPからの接続数制限（10接続まで）

**WebPushCredential**
- **所属**: WebPushSubscription Aggregate
- **責務**: Web Push認証情報を管理
- **属性**:
  - CredentialID（Entity識別子）
  - P256dhKey（公開鍵）
  - AuthKey（認証キー）
  - Browser（ブラウザ種別）
  - DeviceType（デバイス種別）
  - RegisteredAt（登録日時）
- **ビジネスルール**:
  - キーの形式はBase64URL
  - 同一デバイスで複数のクレデンシャル不可

**NotificationGroup**
- **所属**: Notification Aggregate
- **責務**: 通知のグルーピング情報を管理
- **属性**:
  - GroupID（Entity識別子）
  - GroupType（グループ種別）
  - MemberNotifications（グループ化された通知のリスト）
  - Summary（グループのサマリー文）
  - Count（グループ内の通知数）
  - LatestActors（最新のアクター情報）
- **ビジネスルール**:
  - 同一種別・同一対象の通知のみグループ化可能
  - グループ内の通知は時系列順
  - reaction、repost、followタイプのみグループ化可能

**UserNotificationPreference**
- **所属**: Notification Aggregate
- **責務**: 特定ユーザーに対する通知設定を管理
- **属性**:
  - PreferenceID（Entity識別子）
  - TargetUserID（通知対象ユーザー）
  - IsEnabled（投稿通知の有効/無効）
  - CreatedAt（設定作成日時）
  - UpdatedAt（最終更新日時）
- **ビジネスルール**:
  - 同一ターゲットユーザーへの設定は1つのみ
  - ブロック中のユーザーへの通知設定は無効

#### Value Object

詳細は PRD のValue Object定義を参照

## データベースマイグレーション

このサービスでは、[共通マイグレーション戦略](../common/database-migration-strategy.md)に従って、Gooseを使用したマイグレーション管理を行います。

### マイグレーション戦略

- **ツール**: Goose v3
- **ディレクトリ**: `./migrations/`
- **命名規則**: `[sequence_number]_[description].sql`
- **実行方法**: `make migrate-up` / `make migrate-down`

### avion-notification固有の考慮事項

- **未読通知保持**: 移行中も未読通知の状態を正確に保持
- **配信ステータス整合性**: プッシュ通知やSSEの配信状況を適切に移行
- **通知設定継承**: ユーザーの通知設定（プリファレンス）を完全に継承
- **重複通知防止**: 移行処理中の重複通知配信を防止
- **配信トークン更新**: プッシュ通知トークンの有効性を移行後に検証

### 標準テンプレート参照

マイグレーションファイル作成時は[マイグレーション設定テンプレート](../templates/migration-setup-template.md)を参照してください。

## 7. Configuration Management (設定管理)

### 7.1. 統一設定パターンの採用

このサービスは[共通環境変数管理パターン](../common/infrastructure/environment-variables.md)で定義された統一設定パターンに準拠しています。早期失敗（Fail Fast）原則により、必須環境変数が不足している場合は起動時に即座に失敗します。

### 7.2. 環境変数一覧

#### 必須環境変数

| 変数名 | 説明 | 例 |
|--------|------|-----|
| `DATABASE_URL` | PostgreSQLデータベース接続URL | `postgresql://user:pass@localhost:5432/avion_notification` |
| `REDIS_URL` | Redis接続URL | `redis://localhost:6379/0` |
| `FCM_SERVER_KEY` | Firebase Cloud Messaging サーバーキー（プッシュ通知用） | `AAAA...` |
| `APNS_KEY_ID` | Apple Push Notification Service キーID（iOS プッシュ通知用） | `ABC123DEF4` |
| `APNS_TEAM_ID` | Apple Developer Team ID（iOS プッシュ通知用） | `DEF456GHI7` |

#### オプション環境変数（デフォルト値あり）

| 変数名 | 説明 | デフォルト値 |
|--------|------|-------------|
| `PORT` | HTTPサーバーポート | `8086` |
| `GRPC_PORT` | gRPCサーバーポート | `9096` |
| `SSE_HEARTBEAT_INTERVAL` | SSE接続のハートビート間隔 | `15s` |
| `ENVIRONMENT` | 実行環境 | `development` |
| `LOG_LEVEL` | ログレベル | `info` |
| `SERVER_TIMEOUT` | サーバータイムアウト | `30s` |

### 7.3. Config構造体実装例

```go
// internal/infrastructure/config/config.go
package config

import (
    "time"
)

// Config はavion-notificationサービスの設定を保持する構造体
type Config struct {
    // サーバー設定
    Server ServerConfig
    
    // データベース設定
    Database DatabaseConfig
    
    // Redis設定
    Redis RedisConfig
    
    // プッシュ通知設定
    PushNotification PushNotificationConfig
    
    // SSE設定
    SSE SSEConfig
    
    // 監視設定
    Observability ObservabilityConfig
}

// ServerConfig サーバー関連の設定
type ServerConfig struct {
    Port        int           `env:"PORT" required:"true" default:"8086"`
    GRPCPort    int           `env:"GRPC_PORT" required:"true" default:"9096"`
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

// PushNotificationConfig プッシュ通知関連の設定
type PushNotificationConfig struct {
    FCMServerKey string `env:"FCM_SERVER_KEY" required:"true" secret:"true"`
    APNSKeyID    string `env:"APNS_KEY_ID" required:"true"`
    APNSTeamID   string `env:"APNS_TEAM_ID" required:"true"`
}

// SSEConfig Server-Sent Events関連の設定
type SSEConfig struct {
    HeartbeatInterval time.Duration `env:"SSE_HEARTBEAT_INTERVAL" required:"false" default:"15s"`
}

// ObservabilityConfig 監視関連の設定
type ObservabilityConfig struct {
    TracingEnabled bool   `env:"TRACING_ENABLED" required:"false" default:"true"`
    MetricsEnabled bool   `env:"METRICS_ENABLED" required:"false" default:"true"`
    JaegerEndpoint string `env:"JAEGER_ENDPOINT" required:"false" default:"http://jaeger:14268/api/traces"`
}
```

### 7.4. 設定の読み込みと検証

```go
// cmd/server/main.go
package main

import (
    "log"
    
    "github.com/avion/avion-notification/internal/infrastructure/config"
)

func main() {
    // 環境変数の読み込み（必須環境変数が不足していればここで失敗）
    cfg := config.MustLoad()
    
    // ロガーの初期化
    logger := initLogger(cfg.Server.LogLevel)
    
    logger.Info("Starting avion-notification server",
        "environment", cfg.Server.Environment,
        "port", cfg.Server.Port,
        "grpc_port", cfg.Server.GRPCPort,
    )
    
    // サービスの初期化と起動
    // ...
}
```

### 7.5. セキュリティ考慮事項

- **機密情報の保護**: `FCM_SERVER_KEY` は `secret:"true"` タグにより、ログ出力時にマスキングされます
- **環境分離**: 本番環境とステージング環境で異なるプッシュ通知設定を使用
- **最小権限**: 各環境で必要最小限の権限を持つAPIキーのみを設定

## 8. Use Cases / Key Flows (主な使い方・処理の流れ)

- **フロー 1: イベント受信 & 通知生成 (例: リアクション) (Command)**
    1. NotificationEventHandler: NATS JetStream `avion.notification.events.*` サブジェクトからイベント取得 (Payload: { event_id, type: "avion.drop.reaction.created", data: { drop_id, user_id, emoji_code, target_user_id } })。
    2. NotificationEventHandler: ProcessNotificationEventCommandUseCaseを呼び出し
    3. ProcessNotificationEventCommandUseCase: `event_id` をキーに冪等性チェック (NotificationEventRepositoryで処理済みIDを確認)。
    4. ProcessNotificationEventCommandUseCase: NotificationFactory (Domain Service) でNotification Aggregateを生成。
    5. ProcessNotificationEventCommandUseCase: NotificationRepositoryを通じてNotification Aggregateを永続化。
    6. ProcessNotificationEventCommandUseCase: SSEEventPublisherを通じて更新イベント (`{"type": "new_notification"}`) を送信。
    7. ProcessNotificationEventCommandUseCase: WebPushSubscriptionRepositoryからサブスクリプション情報を取得。
    8. ProcessNotificationEventCommandUseCase: WebPushEncryption (Domain Service) でペイロード暗号化後、WebPushClientで送信。送信失敗時のエラーハンドリング。
    9. NotificationEventHandler: イベントをACK。処理失敗時はリトライ or DLQへ。
- **フロー 2: 通知リスト取得 (Query)**
    1. Gateway → GetNotificationsQueryHandler: `GetNotifications` gRPC Call (recipient_user_id, filter, limit, cursor, Metadata: Trace Context)
    2. GetNotificationsQueryHandler: GetNotificationsQueryUseCaseを呼び出し
    3. GetNotificationsQueryUseCase: NotificationQueryServiceを通じて通知リストDTOを取得
    4. NotificationQueryService: フィルタ条件（ReadStatus Value Object）に基づいてクエリ実行
    5. NotificationQueryService: NotificationDTOリストを返却
    6. GetNotificationsQueryUseCase: UserServiceClientで必要に応じて追加情報取得
    7. GetNotificationsQueryHandler → Gateway: `GetNotificationsResponse { notifications: [...] }`
- **フロー 3: 未読件数取得 (Query)**
    1. Gateway → GetUnreadCountQueryHandler: `GetUnreadCount` gRPC Call (recipient_user_id, Metadata: Trace Context)
    2. GetUnreadCountQueryHandler: GetUnreadCountQueryUseCaseを呼び出し
    3. GetUnreadCountQueryUseCase: NotificationQueryServiceを通じて未読件数取得
    4. NotificationQueryService: RecipientUserID Value ObjectとReadStatus=falseでカウント実行
    5. NotificationQueryService: UnreadCountDTO（UnreadCount Value Object含む）を返却
    6. GetUnreadCountQueryHandler → Gateway: `GetUnreadCountResponse { count: 42 }`
- **フロー 4: 通知既読化 (Command)**
    1. Gateway → MarkAsReadCommandHandler: `MarkNotificationsAsRead` gRPC Call (notification_ids, Metadata: X-User-ID, Trace Context)
    2. MarkAsReadCommandHandler: MarkAsReadCommandUseCaseを呼び出し
    3. MarkAsReadCommandUseCase: NotificationRepositoryから対象Notification Aggregateリストを取得
    4. MarkAsReadCommandUseCase: 各Notification Aggregate内で所有者検証とReadStatus更新
    5. MarkAsReadCommandUseCase: NotificationRepositoryを通じて更新されたAggregateを永続化
    6. MarkAsReadCommandUseCase: EventPublisherを通じて `avion.notification.notification.read` イベントを発行
    7. MarkAsReadCommandHandler → Gateway: `MarkNotificationsAsReadResponse { success: true }`
- **フロー 5: Web Pushサブスクリプション登録 (Command)**
    1. Gateway → SubscribeWebPushCommandHandler: `SubscribeWebPush` gRPC Call (endpoint, keys, Metadata: X-User-ID, Trace Context)
    2. SubscribeWebPushCommandHandler: SubscribeWebPushCommandUseCaseを呼び出し
    3. SubscribeWebPushCommandUseCase: WebPushSubscription Aggregateを生成
    4. SubscribeWebPushCommandUseCase: WebPushEndpoint Value Objectでユニーク性検証
    5. SubscribeWebPushCommandUseCase: WebPushSubscriptionRepositoryを通じてAggregateを永続化
    6. SubscribeWebPushCommandUseCase: EventPublisherを通じて `avion.notification.webpush.subscribed` イベントを発行
    7. SubscribeWebPushCommandHandler → Gateway: `SubscribeWebPushResponse { success: true }`
- **フロー 6: 投票通知 (Command)**
    1. NotificationEventHandler: NATS JetStream `avion.notification.events.*` サブジェクトから `avion.drop.poll.voted` イベント取得
    2. ProcessPollEventCommandUseCaseを呼び出し
    3. ProcessPollEventCommandUseCase: 投票作成者を特定（EventDataから抽出）
    4. ProcessPollEventCommandUseCase: 投票作成者への通知を生成（投票者情報と選択肢を含む）
    5. ProcessPollEventCommandUseCase: NotificationRepositoryを通じて永続化
    6. ProcessPollEventCommandUseCase: SSE/Web Push配信
- **フロー 7: フォローリクエスト通知 (Command)**
    1. NotificationEventHandler: `avion.user.follow_request.created` イベント取得
    2. ProcessFollowRequestEventCommandUseCaseを呼び出し
    3. ProcessFollowRequestEventCommandUseCase: 対象ユーザーのアカウント設定を確認（非公開アカウントか）
    4. ProcessFollowRequestEventCommandUseCase: 非公開アカウントの場合のみ通知を生成
    5. ProcessFollowRequestEventCommandUseCase: NotificationRepositoryを通じて永続化
    6. ProcessFollowRequestEventCommandUseCase: SSE/Web Push配信
- **フロー 8: 投稿更新通知 (Command)**
    1. NotificationEventHandler: `avion.drop.drop.updated` イベント取得
    2. ProcessDropUpdateEventCommandUseCaseを呼び出し
    3. ProcessDropUpdateEventCommandUseCase: 該当Dropにインタラクションしたユーザーを特定
    4. ProcessDropUpdateEventCommandUseCase: バッチで通知を生成（パフォーマンス考慮）
    5. ProcessDropUpdateEventCommandUseCase: NotificationRepositoryを通じて一括永続化
    6. ProcessDropUpdateEventCommandUseCase: 影響を受けるユーザーへSSE/Web Push配信
- **フロー 9: 特定ユーザーの投稿通知 (Command)**
    1. NotificationEventHandler: `avion.drop.drop.created` イベント取得
    2. ProcessStatusEventCommandUseCaseを呼び出し
    3. ProcessStatusEventCommandUseCase: UserNotificationPreferenceから通知設定を取得
    4. ProcessStatusEventCommandUseCase: 該当ユーザーの投稿通知を有効にしているユーザーを特定
    5. ProcessStatusEventCommandUseCase: 対象ユーザー全員にstatus通知を生成
    6. ProcessStatusEventCommandUseCase: SSE/Web Push配信
- **フロー 10: モデレーション警告通知 (Command)**
    1. NotificationEventHandler: `moderation_action_taken` イベント取得
    2. ProcessModerationEventCommandUseCaseを呼び出し
    3. ProcessModerationEventCommandUseCase: 警告対象ユーザーにmoderation_warning通知を生成
    4. ProcessModerationEventCommandUseCase: 警告理由と対処方法を含めて永続化
    5. ProcessModerationEventCommandUseCase: SSE/Web Push配信（優先度高）
- **フロー 11: アナウンス配信 (Command)**
    1. 管理者がアナウンスを作成
    2. PublishAnnouncementCommandUseCaseを呼び出し
    3. PublishAnnouncementCommandUseCase: Announcement Aggregateを生成
    4. PublishAnnouncementCommandUseCase: 対象ユーザーを特定（全員または特定ユーザー）
    5. PublishAnnouncementCommandUseCase: announcement通知を一括生成
    6. PublishAnnouncementCommandUseCase: SSE/Web Push即時配信
- **フロー 12: 通知グループ化 (Command)**
    1. ProcessNotificationEventCommandUseCaseで新規通知生成時
    2. GroupNotificationsCommandUseCaseを呼び出し
    3. GroupNotificationsCommandUseCase: 同一種別・同一対象の既存グループを検索
    4. GroupNotificationsCommandUseCase: グループが存在する場合、NotificationGroupに追加
    5. GroupNotificationsCommandUseCase: グループが存在しない場合、新規グループ作成
    6. GroupNotificationsCommandUseCase: グループサマリーを更新（「○人がリアクションしました」）

## 9. Endpoints (API)

- **gRPC Services (`avion.NotificationService`):** (変更なし)
    - `GetNotifications(GetNotificationsRequest) returns (GetNotificationsResponse)`
    - `GetUnreadCount(GetUnreadCountRequest) returns (GetUnreadCountResponse)`
    - `MarkNotificationsAsRead(MarkNotificationsAsReadRequest) returns (MarkNotificationsAsReadResponse)`
    - `SubscribeWebPush(SubscribeWebPushRequest) returns (SubscribeWebPushResponse)`
    - `UnsubscribeWebPush(UnsubscribeWebPushRequest) returns (UnsubscribeWebPushResponse)`
- **HTTP Endpoints:**
    - `/events/notifications`: 新規通知イベント用SSEストリームエンドポイント (認証要)。
- Proto定義は別途管理する。

## 10. Data Design (データ)

### ドメインオブジェクトとDBスキーマのマッピング

DDDの戦術的パターンに基づき、以下のようにドメインオブジェクトをDBスキーマにマッピングします：

#### Notification Aggregate → notifications テーブル
- **PostgreSQL:**
    - `notifications` table:
        - `id (UUID, PK)` // NotificationID (UUID v7)
        - `recipient_user_id (UUID, FK to users.id, INDEX)` // RecipientUserID Value Object
        - `type (VARCHAR(50), NOT NULL)` // NotificationType Value Object (18種類: follow, mention, reaction, repost, quote_repost, reply, poll_vote, poll_end, follow_request, follow_request_accepted, drop_updated, status, system, admin_user_registered, admin_report_created, moderation_warning, severed_relationships, announcement)
        - `actor_user_id (UUID, FK to users.id, NULLABLE)` // ActorUserID Value Object
        - `target_drop_id (UUID, FK to drops.id, NULLABLE)` // TargetDropID Value Object
        - `read (BOOLEAN, DEFAULT false, INDEX)` // ReadStatus Value Object
        - `created_at (TIMESTAMPTZ, INDEX)` // CreatedAt Value Object
        - `data (JSONB)` // NotificationData Value Object
        - Index: `(recipient_user_id, read, created_at)` // 未読リスト取得用
        - Index: `created_at` // 定期削除用

#### WebPushSubscription Aggregate → webpush_subscriptions テーブル
    - `webpush_subscriptions` table:
        - `id (UUID, PK)` // SubscriptionID (UUID v7)
        - `user_id (UUID, FK to users.id, INDEX)` // UserID Value Object
        - `endpoint (TEXT, UNIQUE)` // WebPushEndpoint Value Object (集約ID)
        - `p256dh (VARCHAR)` // WebPushKeys Value Object の一部
        - `auth (VARCHAR)` // WebPushKeys Value Object の一部
        - `created_at (TIMESTAMPTZ)` // CreatedAt Value Object

### イベント処理（NATS JetStream）とSSE管理（Redis）
#### NotificationEvent Aggregate → NATS JetStream
- **NATS JetStream:**
    - Subject: `avion.notification.events.*` (Durable Consumer: `notification_workers`)
        - 各メッセージはNotificationEvent Aggregateを表現
        - EventID Value Objectがメッセージヘッダーにマッピング
        - EventType, EventData Value Objectはペイロードに含まれる
    
#### 冪等性管理
    - Processed Event IDs (for idempotency): `processed_event:{event_id}` (Value: 1, TTL: short)
        - EventID Value Objectをキーとして使用
        - ProcessedAt Value Objectの情報を保持
    
#### SSE接続管理
    - SSE接続管理 (Hash/Set): 
        - `sse_connections:user:{user_id}`: UserID別の接続管理
        - `sse_connection:{connection_id}`: SSEConnectionID Value Objectの情報
        - SSEEvent Value Objectの配信に使用

## 11. Operations & Monitoring (運用と監視)

- **主なオペレーション:**
    - DBマイグレーション。
    - Redis接続情報、NATS JetStream Consumer設定。
    - Web Push VAPIDキーの管理・ローテーション。
    - 通知データのアーカイブ/削除ジョブ運用 (例: 90日以上経過した既読通知を削除)。
- **監視/アラート:**
    - **メトリクス:**
        - gRPC/SSEリクエスト数、レイテンシ、エラーレート。
        - NATS JetStream処理遅延、エラーレート、Pending数。
        - Web Push送信成功/失敗レート、レイテンシ。
        - DB接続エラー、クエリ実行時間。
        - SSE接続数。
    - **ログ:** API処理ログ、イベント処理ログ (冪等性チェック結果含む)、SSE接続/切断ログ、Web Push送信ログ（エラー詳細含む）、エラーログ、削除ジョブ実行ログ。
    - **トレース:** API呼び出し、イベント処理、DBアクセス、Web Push送信のトレース。
    - **アラート:** gRPC/SSEエラーレート急増、高レイテンシ、NATS JetStream処理遅延大/Pending数増加、Web Push送信失敗レート上昇、DB/Redis接続障害、SSE接続数異常。

## 12. 構造化ログ戦略

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
    Timestamp   time.Time `json:"timestamp"`
    Level       string    `json:"level"`
    Service     string    `json:"service"`     // "avion-notification"
    Version     string    `json:"version"`     // サービスバージョン
    TraceID     string    `json:"trace_id"`    // OpenTelemetry TraceID
    SpanID      string    `json:"span_id"`     // OpenTelemetry SpanID
    
    // コンテキストフィールド
    UserID      string    `json:"user_id,omitempty"`
    NotificationID string `json:"notification_id,omitempty"`
    EventID     string    `json:"event_id,omitempty"`
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
    slog.String("method", "GetNotifications"),
    slog.String("trace_id", traceID),
    slog.String("user_id", userID),
    slog.String("layer", "handler"),
)

logger.Error("gRPC request failed",
    slog.String("method", "MarkAsRead"),
    slog.String("trace_id", traceID),
    slog.String("error", err.Error()),
    slog.String("error_code", "NOTIFICATION_NOT_FOUND"),
    slog.Int64("duration_ms", duration),
)
```

#### Use Case層
```go
logger.Info("notification processing started",
    slog.String("trace_id", ctx.Value("trace_id").(string)),
    slog.String("event_type", eventType),
    slog.String("recipient_user_id", recipientUserID),
    slog.String("layer", "usecase"),
)

logger.Info("notification created",
    slog.String("notification_id", notificationID),
    slog.String("notification_type", notificationType),
    slog.String("recipient_user_id", recipientUserID),
    slog.String("actor_user_id", actorUserID),
    slog.String("layer", "usecase"),
)
```

#### Infrastructure層
```go
logger.Debug("database query executed",
    slog.String("query", "INSERT INTO notifications"),
    slog.String("table", "notifications"),
    slog.Int64("duration_ms", queryDuration),
    slog.String("layer", "infra"),
)

logger.Warn("nats jetstream event processing delay",
    slog.String("stream", "NOTIFICATIONS"),
    slog.String("consumer", "notification_workers"),
    slog.Int64("lag_ms", lagMs),
    slog.String("layer", "infra"),
)
```

### 通知イベント処理のログ
```go
// イベント受信
logger.Info("notification event received",
    slog.String("event", "event_received"),
    slog.String("event_id", eventID),
    slog.String("event_type", eventType),
    slog.String("source", "nats_jetstream"),
    slog.Bool("idempotency_check", isProcessed),
)

// 通知生成
logger.Info("notification generated",
    slog.String("event", "notification_generated"),
    slog.String("notification_type", notificationType),
    slog.String("recipient_user_id", recipientUserID),
    slog.String("actor_user_id", actorUserID),
    slog.String("target_drop_id", targetDropID),
)

// 投票通知
logger.Info("poll notification generated",
    slog.String("event", "poll_notification_generated"),
    slog.String("poll_id", pollID),
    slog.String("voter_user_id", voterUserID),
    slog.String("poll_owner_id", pollOwnerID),
    slog.String("selected_option", selectedOption),
)

// フォローリクエスト通知
logger.Info("follow request notification generated",
    slog.String("event", "follow_request_notification_generated"),
    slog.String("requester_user_id", requesterUserID),
    slog.String("target_user_id", targetUserID),
    slog.Bool("is_private_account", isPrivateAccount),
)

// 冪等性処理
logger.Debug("idempotency check",
    slog.String("event_id", eventID),
    slog.Bool("already_processed", alreadyProcessed),
    slog.String("processed_at", processedAt),
)
```

### SSE処理のログ
```go
// SSE接続確立
logger.Info("SSE connection established",
    slog.String("event", "sse_connected"),
    slog.String("user_id", userID),
    slog.String("connection_id", connID),
    slog.String("client_ip", clientIP),
)

// 通知イベント配信
logger.Debug("SSE notification sent",
    slog.String("connection_id", connID),
    slog.String("event_type", "new_notification"),
    slog.String("notification_id", notificationID),
    slog.Int("active_connections", activeConnections),
)

// 接続切断
logger.Info("SSE connection closed",
    slog.String("event", "sse_disconnected"),
    slog.String("connection_id", connID),
    slog.String("reason", reason),
    slog.Int64("duration_seconds", duration),
)
```

### Web Push処理のログ
```go
// サブスクリプション登録
logger.Info("web push subscription registered",
    slog.String("event", "push_subscription_registered"),
    slog.String("user_id", userID),
    slog.String("endpoint", maskEndpoint(endpoint)),
    slog.String("browser", browser),
)

// プッシュ通知送信
logger.Info("web push sent",
    slog.String("event", "push_sent"),
    slog.String("notification_id", notificationID),
    slog.String("user_id", userID),
    slog.Int("payload_size", payloadSize),
    slog.Bool("encrypted", true),
)

// 送信失敗
logger.Warn("web push failed",
    slog.String("event", "push_failed"),
    slog.String("endpoint", maskEndpoint(endpoint)),
    slog.Int("status_code", statusCode),
    slog.String("error", err.Error()),
    slog.Bool("subscription_invalid", isInvalid),
)
```

### 既読処理のログ
```go
logger.Info("notifications marked as read",
    slog.String("event", "notifications_read"),
    slog.String("user_id", userID),
    slog.Int("count", len(notificationIDs)),
    slog.String("notification_ids", strings.Join(notificationIDs, ",")),
)
```

### バッチ処理のログ
```go
// 古い通知削除
logger.Info("old notifications cleanup",
    slog.String("event", "cleanup_started"),
    slog.Time("cutoff_date", cutoffDate),
    slog.String("criteria", "read_and_older_than_90_days"),
)

logger.Info("old notifications deleted",
    slog.String("event", "cleanup_completed"),
    slog.Int("deleted_count", deletedCount),
    slog.Int64("duration_ms", duration),
)
```

### エラーログの詳細化
```go
logger.Error("failed to send web push",
    slog.String("user_id", userID),
    slog.String("endpoint", maskEndpoint(endpoint)),
    slog.String("error", err.Error()),
    slog.String("error_type", fmt.Sprintf("%T", err)),
    slog.String("stack_trace", string(debug.Stack())),
    slog.String("layer", "infra"),
)
```

### CRITICALレベルログの例
```go
// 通知システム全体停止時
logger.With(slog.String("level", "CRITICAL")).Error("notification system failure",
    slog.String("component", "notification_processor"),
    slog.String("error", "all_event_consumers_failed"),
    slog.Int("pending_events", pendingEventCount),
    slog.String("action", "emergency_restart_required"),
)

// データベース接続完全失敗時
logger.With(slog.String("level", "CRITICAL")).Error("database connection failure",
    slog.String("database", "notifications_db"),
    slog.String("error", "all_connections_exhausted"),
    slog.String("impact", "notification_read_write_stopped"),
    slog.String("action", "immediate_intervention_required"),
)

// Web Pushサービス系全体障害時
logger.With(slog.String("level", "CRITICAL")).Error("web push service outage",
    slog.String("component", "webpush_client"),
    slog.Float64("failure_rate", 1.0),
    slog.Int("failed_notifications", failedCount),
    slog.String("impact", "push_notifications_completely_stopped"),
)
```

### メトリクスログ
```go
// 通知統計
logger.Info("notification statistics",
    slog.String("event", "notification_stats"),
    slog.String("period", "5m"),
    slog.Int("created", created),
    slog.Int("delivered_sse", deliveredSSE),
    slog.Int("delivered_push", deliveredPush),
    slog.Int("read", read),
)

// 未読件数
logger.Debug("unread count calculated",
    slog.String("user_id", userID),
    slog.Int("unread_count", unreadCount),
    slog.Int64("query_duration_ms", queryDuration),
)
```

### ログ集約とクエリ
- **出力先**: 標準出力（Kubernetes環境ではFluentd/Fluent Bitが収集）
- **集約先**: Elasticsearch、CloudWatch Logs、またはLoki
- **クエリ例**:
  ```
  service="avion-notification" AND event="event_received" AND event_type="reaction_created"
  service="avion-notification" AND event="push_failed" AND subscription_invalid=true
  service="avion-notification" AND event="sse_connected" AND client_ip="192.168.*"
  service="avion-notification" AND layer="usecase" AND duration_ms>500
  service="avion-notification" AND level="CRITICAL"
  ```

### セキュリティ考慮事項
- Web Pushエンドポイントは部分的にマスク（最初と最後の数文字のみ表示）
- 暗号化キー（p256dh、auth）は絶対にログに含めない
- 通知の詳細内容は最小限に留める
- クライアントIPは必要最小限の場合のみ記録

## 13. エラーハンドリング戦略

> **注意:** エラーコードは[共通エラーコード標準](../common/errors/error-codes.md)に準拠します。このサービスではプレフィックス `NTF` を使用します。

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

// 通知関連エラー
var (
    ErrNotificationNotFound         = errors.New("notification not found")
    ErrNotificationAlreadyRead      = errors.New("notification already read")
    ErrInvalidNotificationType      = errors.New("invalid notification type")
    ErrInvalidRecipient             = errors.New("invalid recipient")
    ErrNotificationExpired          = errors.New("notification expired")
    ErrCannotDeleteNotification     = errors.New("cannot delete notification")
)

// イベント処理関連エラー
var (
    ErrEventAlreadyProcessed        = errors.New("event already processed")
    ErrInvalidEventType             = errors.New("invalid event type")
    ErrInvalidEventData             = errors.New("invalid event data")
    ErrEventProcessingFailed        = errors.New("event processing failed")
    ErrMissingRecipient             = errors.New("missing recipient in event")
    ErrPollNotFound                 = errors.New("poll not found")
    ErrPollAlreadyEnded             = errors.New("poll already ended")
    ErrInvalidPollVote              = errors.New("invalid poll vote")
    ErrFollowRequestNotAllowed      = errors.New("follow request not allowed for public account")
    ErrDropNotFound                 = errors.New("drop not found")
    ErrNoUsersToNotify              = errors.New("no users to notify for drop update")
)

// Web Push関連エラー
var (
    ErrWebPushSubscriptionNotFound  = errors.New("web push subscription not found")
    ErrInvalidWebPushEndpoint       = errors.New("invalid web push endpoint")
    ErrInvalidWebPushKeys           = errors.New("invalid web push keys")
    ErrWebPushSubscriptionExpired   = errors.New("web push subscription expired")
    ErrWebPushDeliveryFailed        = errors.New("web push delivery failed")
    ErrWebPushPayloadTooLarge       = errors.New("web push payload too large")
    ErrWebPushEncryptionFailed      = errors.New("web push encryption failed")
)

// SSE関連エラー
var (
    ErrSSEConnectionLimitExceeded   = errors.New("SSE connection limit exceeded")
    ErrSSEConnectionNotFound        = errors.New("SSE connection not found")
    ErrSSEConnectionTimeout         = errors.New("SSE connection timeout")
    ErrSSEBroadcastFailed           = errors.New("SSE broadcast failed")
)

// 通知設定関連エラー
var (
    ErrNotificationPreferenceNotFound = errors.New("notification preference not found")
    ErrCannotDisableSystemNotification = errors.New("cannot disable system notification")
    ErrInvalidDeliveryChannel       = errors.New("invalid delivery channel")
)

// 権限関連エラー
var (
    ErrUnauthorizedAccess           = errors.New("unauthorized access")
    ErrNotificationOwnerMismatch    = errors.New("notification owner mismatch")
)

// グループ化関連エラー
var (
    ErrInvalidGroupType             = errors.New("invalid group type")
    ErrGroupNotFound                = errors.New("notification group not found")
    ErrCannotGroupDifferentTypes    = errors.New("cannot group notifications of different types")
    ErrGroupLimitExceeded           = errors.New("group limit exceeded")
)

// 特定ユーザー通知設定関連エラー
var (
    ErrUserNotificationPreferenceNotFound = errors.New("user notification preference not found")
    ErrCannotNotifyBlockedUser      = errors.New("cannot set notification for blocked user")
    ErrDuplicateUserPreference      = errors.New("duplicate user notification preference")
)

// アナウンス関連エラー
var (
    ErrAnnouncementNotFound         = errors.New("announcement not found")
    ErrAnnouncementExpired          = errors.New("announcement expired")
    ErrInvalidAnnouncementPeriod    = errors.New("invalid announcement period")
    ErrUnauthorizedAnnouncement     = errors.New("unauthorized to create announcement")
)

// 管理者通知関連エラー
var (
    ErrAdminNotificationFailed      = errors.New("admin notification failed")
    ErrNoAdminUsersFound            = errors.New("no admin users found")
)
```

### 各層でのエラーハンドリング

#### Handler層
- ドメインエラーを適切なgRPCステータスコードに変換
- クライアントに適切なエラーメッセージを返す
- 構造化ログでエラー詳細を記録

```go
func (h *MarkAsReadCommandHandler) MarkNotificationsAsRead(ctx context.Context, req *pb.MarkNotificationsAsReadRequest) (*pb.MarkNotificationsAsReadResponse, error) {
    output, err := h.useCase.Execute(ctx, input)
    if err != nil {
        switch {
        case errors.Is(err, domain.ErrNotificationNotFound):
            return nil, status.Error(codes.NotFound, "notification not found")
        case errors.Is(err, domain.ErrNotificationAlreadyRead):
            return nil, status.Error(codes.FailedPrecondition, "notification already read")
        case errors.Is(err, domain.ErrUnauthorizedAccess):
            return nil, status.Error(codes.PermissionDenied, "unauthorized access")
        default:
            h.logger.Error("unexpected error", 
                slog.String("error", err.Error()),
                slog.String("trace_id", traceID),
            )
            return nil, status.Error(codes.Internal, "internal server error")
        }
    }
    return response, nil
}
```

#### UseCase層
- ドメインエラーをそのまま上位層に伝播
- トランザクション境界でのロールバック処理
- 必要に応じてコンテキスト情報を追加

```go
func (u *ProcessNotificationEventCommandUseCase) Execute(ctx context.Context, input ProcessNotificationEventInput) error {
    // 冪等性チェック
    processed, err := u.eventRepo.IsProcessed(ctx, input.EventID)
    if err != nil {
        return fmt.Errorf("failed to check event processing status: %w", err)
    }
    if processed {
        return domain.ErrEventAlreadyProcessed
    }

    // 通知生成
    notification, err := u.notificationFactory.Create(ctx, input.EventData)
    if err != nil {
        if errors.Is(err, domain.ErrInvalidEventType) {
            // 無効なイベントタイプはスキップ（エラー扱いしない）
            u.logger.Warn("skipping invalid event type",
                slog.String("event_type", input.EventType),
            )
            return nil
        }
        return fmt.Errorf("failed to create notification: %w", err)
    }

    // 永続化
    if err := u.notificationRepo.Save(ctx, notification); err != nil {
        return fmt.Errorf("failed to save notification: %w", err)
    }

    return nil
}
```

#### Infrastructure層
- 外部システムのエラーをドメインエラーに変換
- リトライ可能なエラーとそうでないエラーを区別
- データベースの制約違反を適切なドメインエラーにマッピング

```go
func (r *PostgreSQLNotificationRepository) FindByID(ctx context.Context, id domain.NotificationID) (*domain.Notification, error) {
    row := r.db.QueryRowContext(ctx, query, id.Value())
    
    var notification domain.Notification
    err := row.Scan(&notification.ID, &notification.RecipientUserID, ...)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, domain.ErrNotificationNotFound
        }
        return nil, fmt.Errorf("failed to query notification: %w", err)
    }
    
    return &notification, nil
}

func (c *HTTPWebPushClient) Send(ctx context.Context, subscription *domain.WebPushSubscription, payload []byte) error {
    resp, err := c.httpClient.Do(req)
    if err != nil {
        return fmt.Errorf("failed to send web push: %w", err)
    }
    defer resp.Body.Close()

    switch resp.StatusCode {
    case http.StatusCreated:
        return nil
    case http.StatusGone:
        // サブスクリプションが無効
        return domain.ErrWebPushSubscriptionExpired
    case http.StatusRequestEntityTooLarge:
        return domain.ErrWebPushPayloadTooLarge
    case http.StatusTooManyRequests:
        // リトライ可能
        return fmt.Errorf("rate limited: retry after %s", resp.Header.Get("Retry-After"))
    default:
        return domain.ErrWebPushDeliveryFailed
    }
}
```

### エラーリカバリー戦略

#### イベント処理のリトライ
```go
func (h *NotificationEventHandler) handleEvent(ctx context.Context, event domain.NotificationEvent) error {
    maxRetries := 3
    backoff := time.Second
    
    for i := 0; i < maxRetries; i++ {
        err := h.processEvent(ctx, event)
        if err == nil {
            return nil
        }
        
        // リトライ不可能なエラーは即座に返す
        if errors.Is(err, domain.ErrEventAlreadyProcessed) ||
           errors.Is(err, domain.ErrInvalidEventType) ||
           errors.Is(err, domain.ErrMissingRecipient) {
            return err
        }
        
        // リトライ可能なエラーの場合、バックオフ付きリトライ
        time.Sleep(backoff)
        backoff *= 2
    }
    
    // 最大リトライ回数を超えた場合、DLQへ
    return h.sendToDLQ(ctx, event)
}
```

#### Web Push配信のフォールバック
```go
func (u *SendWebPushCommandUseCase) Execute(ctx context.Context, input SendWebPushInput) error {
    // プライマリ送信試行
    err := u.webPushClient.Send(ctx, input.Subscription, input.Payload)
    if err == nil {
        return nil
    }
    
    // エラーハンドリング
    switch {
    case errors.Is(err, domain.ErrWebPushSubscriptionExpired):
        // 無効なサブスクリプションを削除
        return u.subscriptionRepo.Delete(ctx, input.Subscription.ID)
    case errors.Is(err, domain.ErrWebPushPayloadTooLarge):
        // ペイロードを縮小して再試行
        smallerPayload := u.createMinimalPayload(input.Notification)
        return u.webPushClient.Send(ctx, input.Subscription, smallerPayload)
    default:
        // その他のエラーはログに記録
        u.logger.Warn("web push delivery failed",
            slog.String("error", err.Error()),
            slog.String("endpoint", input.Subscription.Endpoint.Mask()),
        )
        return err
    }
}
```

### クライアントへのエラー通知

#### SSE経由のエラー通知
```go
func (h *NotificationSSEHandler) sendError(w http.ResponseWriter, errMsg string) {
    event := domain.SSEEvent{
        Event: "error",
        Data:  fmt.Sprintf(`{"error":"%s"}`, errMsg),
    }
    fmt.Fprintf(w, "event: %s\ndata: %s\n\n", event.Event, event.Data)
    w.(http.Flusher).Flush()
}
```

## 14. ドメインオブジェクトとデータベース/キューのマッピング

通知サービスでは、DDDの戦術的パターンに基づいて、ドメインオブジェクトをデータベースおよびキューシステムに以下のようにマッピングします：

### 14.1. PostgreSQLマッピング

#### Notification Aggregate → notifications テーブル
```sql
CREATE TABLE notifications (
    id UUID PRIMARY KEY,                                -- NotificationID Value Object (UUID v7)
    recipient_user_id UUID NOT NULL,                    -- RecipientUserID Value Object
    type VARCHAR(50) NOT NULL,                          -- NotificationType Value Object
    actor_user_id UUID,                                 -- ActorUserID Value Object (nullable)
    target_drop_id UUID,                                -- TargetDropID Value Object (nullable)
    target_user_id UUID,                                -- TargetUserID Value Object (nullable)
    read_status BOOLEAN DEFAULT FALSE NOT NULL,         -- ReadStatus Value Object
    read_at TIMESTAMP WITH TIME ZONE,                   -- ReadAt Value Object (nullable)
    notification_data JSONB,                            -- NotificationData Value Object
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),  -- CreatedAt Value Object
    expires_at TIMESTAMP WITH TIME ZONE,                -- ExpiresAt Value Object
    group_id UUID,                                      -- グループ化用
    CONSTRAINT chk_read_at CHECK (read_at IS NULL OR read_status = TRUE)
);

-- インデックス
CREATE INDEX idx_notifications_recipient_read ON notifications (recipient_user_id, read_status, created_at);
CREATE INDEX idx_notifications_created_at ON notifications (created_at);
CREATE INDEX idx_notifications_expires_at ON notifications (expires_at);
```

**集約不変条件のDB制約による強制:**
- `recipient_user_id` は NOT NULL (RecipientUserIDは変更不可)
- `type` は NOT NULL (NotificationTypeは作成後変更不可)
- `read_status` のデフォルト値は FALSE
- CHECK制約で `read_at` は `read_status = TRUE` の場合のみ設定可能

#### WebPushSubscription Aggregate → webpush_subscriptions テーブル
```sql
CREATE TABLE webpush_subscriptions (
    id UUID PRIMARY KEY,                                -- SubscriptionID Value Object (UUID v7)
    user_id UUID NOT NULL,                              -- UserID Value Object
    endpoint TEXT UNIQUE NOT NULL,                       -- WebPushEndpoint Value Object
    p256dh_key VARCHAR(128) NOT NULL,                    -- WebPushKeys Value Object
    auth_key VARCHAR(64) NOT NULL,                       -- WebPushKeys Value Object
    browser_info JSONB,                                 -- BrowserInfo Value Object
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),  -- CreatedAt Value Object
    last_used_at TIMESTAMP WITH TIME ZONE               -- LastUsedAt Value Object
);

-- インデックス
CREATE INDEX idx_webpush_user_id ON webpush_subscriptions (user_id);
```

**集約不変条件のDB制約による強制:**
- `endpoint` はUNIQUE制約 (同一エンドポイントは1つのみ)
- 定期的なクリーンアップジョブで無効なサブスクリプションを削除

### 14.2. Redisマッピング

#### NotificationEvent Aggregate → NATS JetStream
```
# Stream: NOTIFICATION
# Subject: avion.notification.events.*
# Durable Consumer: notification_workers

# メッセージPayload例:
{
  "event_id": "018e3e28-5c42-7xxx-xxxx-xxxxxxxxxxxx",  # EventID Value Object (UUID v7)
  "event_type": "avion.drop.reaction.created",            # EventType Value Object
  "event_data": {                                       # EventData Value Object
    "actor_user_id": "018e3e28-aaaa-7xxx-xxxx-xxxxxxxxxxxx",
    "target_drop_id": "018e3e28-bbbb-7xxx-xxxx-xxxxxxxxxxxx",
    "recipient_user_id": "018e3e28-cccc-7xxx-xxxx-xxxxxxxxxxxx",
    "emoji_code": "thumbs_up"
  },
  "timestamp": "2025-03-30T12:00:00Z",
  "trace_id": "abc123"
}
```

#### 冪等性管理 → Redis Hash
```
# Key Pattern: processed_event:{event_id}
# TTL: 1時間（重複処理防止に十分な期間）
# Value: JSON with processing metadata
{
  "processed_at": "2025-03-30T12:00:01Z",
  "status": "completed",
  "notification_id": "987654321"
}
```

#### SSE接続管理 → Redis Hash/Set
```
# ユーザー別接続管理
# Key: sse_connections:user:{user_id}
# Type: Hash
# TTL: 1時間（heartbeatで更新）
{
  "connection_count": "3",
  "last_heartbeat": "2025-03-30T12:00:00Z"
}

# 個別接続情報
# Key: sse_connection:{connection_id}
# Type: Hash
# TTL: 15秒（heartbeatで更新）
{
  "user_id": "123",
  "established_at": "2025-03-30T11:50:00Z",
  "user_agent": "Mozilla/5.0...",
  "ip_address": "192.168.1.100"
}
```

#### キャッシュ → Redis Hash
```
# 未読件数キャッシュ
# Key: unread_count:{user_id}
# TTL: 5分
{
  "count": "42",
  "updated_at": "2025-03-30T12:00:00Z"
}

# 通知設定キャッシュ
# Key: notification_prefs:{user_id}
# TTL: 30分
{
  "follow": "true",
  "mention": "true",
  "reaction": "false",
  "delivery_channels": ["sse", "push"]
}
```

### 14.3. マッピング戦略

#### 集約境界の保持
- **Notification Aggregate**: 単一テーブル `notifications` で完全に表現
- **WebPushSubscription Aggregate**: `webpush_subscriptions` テーブルと関連するRedisキャッシュで管理
- **NotificationEvent Aggregate**: NATS JetStreamメッセージと冪等性チェック用Redis Hashで表現
- **SSEConnectionManager Aggregate**: 複数のRedisキーで分散管理（パフォーマンス重視）

#### Value Objectの永続化
- **Primitive Value Objects**: そのままカラムにマッピング
- **Complex Value Objects**: JSON形式で永続化（例：NotificationData、BrowserInfo）
- **Enumeration Value Objects**: VARCHAR制約またはENUM型で制限

#### Repository実装での集約再構築
```go
// PostgreSQLから集約を再構築する例
func (r *PostgreSQLNotificationRepository) FindByID(ctx context.Context, id domain.NotificationID) (*domain.Notification, error) {
    var row struct {
        ID               string          // UUID v7
        RecipientUserID  string          // UUID v7
        Type             string
        ActorUserID      sql.NullString  // UUID v7 (nullable)
        TargetDropID     sql.NullString  // UUID v7 (nullable)
        ReadStatus       bool
        ReadAt           sql.NullTime
        NotificationData json.RawMessage
        CreatedAt        time.Time
        ExpiresAt        sql.NullTime
    }
    
    // データベースからの読み取り
    err := r.db.QueryRowContext(ctx, query, id.Value()).Scan(
        &row.ID, &row.RecipientUserID, &row.Type,
        &row.ActorUserID, &row.TargetDropID,
        &row.ReadStatus, &row.ReadAt,
        &row.NotificationData, &row.CreatedAt, &row.ExpiresAt,
    )
    
    // Value Objectsの再構築
    notificationID := domain.NewNotificationID(row.ID)
    recipientUserID := domain.NewRecipientUserID(row.RecipientUserID)
    notificationType := domain.NewNotificationTypeFromString(row.Type)
    
    // 集約の再構築
    return domain.ReconstructNotification(
        notificationID,
        recipientUserID,
        notificationType,
        // ... その他のパラメーター
    ), nil
}
```

## 15. Integration Specifications (連携仕様)

### 15.1. avion-user との連携

**Purpose:** ユーザー情報の取得とブロック・ミュート設定の確認

**Integration Method:** gRPC

**Data Flow:**
1. 通知生成時にActorユーザーの基本情報を取得
2. NotificationPermissionServiceでブロック・ミュート状態を確認
3. UserNotificationPreference設定時に対象ユーザーの存在確認

**Error Handling:** ユーザーサービス障害時は通知生成を継続、エンリッチメントは後で実行

### 15.2. avion-drop との連携

**Purpose:** Drop詳細情報の取得と通知エンリッチメント

**Integration Method:** gRPC

**Data Flow:**
1. Drop関連通知生成時にDrop基本情報を取得
2. 通知表示時にDrop詳細情報でエンリッチメント
3. 投稿更新通知でのインタラクションユーザー特定

**Error Handling:** Drop削除済みの場合は通知をソフト削除

### 15.3. Event Publishing

**Events Published:**
- `avion.notification.notification.created`: 新規通知生成時に発行
- `avion.notification.notification.read`: 通知既読化時に発行
- `avion.notification.webpush.updated`: サブスクリプション変更時に発行

**Event Schema:**
```go
type NotificationCreatedEventData struct {
    NotificationID   string    `json:"notification_id"`
    RecipientUserID  string    `json:"recipient_user_id"`
    NotificationType string    `json:"notification_type"`
    CreatedAt        time.Time `json:"created_at"`
}
```

### 15.4. Event Consuming

**Events Consumed:**
- `avion.user.follow.created`: avion-userからフォロー通知生成用
- `avion.drop.reaction.created`: avion-dropからリアクション通知生成用
- `avion.drop.repost.created`: avion-dropからリポスト通知生成用
- `avion.drop.mention.created`: avion-dropからメンション通知生成用
- `avion.drop.poll.voted`: avion-dropから投票通知生成用
- `avion.drop.drop.updated`: avion-dropから投稿更新通知生成用

## 16. Concerns / Open Questions (懸念事項・相談したいこと)

### 技術的負債リスク

#### イベント処理の信頼性
- **NATS JetStream**: 以下の実装・運用が重要
  - 冪等性確保: `processed_event:{event_id}` キーでの重複チェック
  - リトライ戦略: 指数バックオフによる再試行（最大3回）
  - DLQ管理: 処理失敗イベントの別Streamへの移動
  - Consumer状態監視: Pending数とLag時間の監視
- **対策**: 包括的なエラーハンドリング戦略とモニタリング体制の構築

#### Web Push配信の複雑性と外部依存
- **外部サービス依存**: ブラウザベンダーのPushサービスへの依存
- **エラーハンドリングの複雑性**: 
  - 無効サブスクリプション (410 Gone) の自動削除
  - レート制限 (429) への対応
  - ペイロードサイズ制限 (413) への対応
- **対策**: 包括的なフォールバック戦略と自動復旧機能の実装

#### SSE接続管理のスケーラビリティ
- **多数接続管理**: ステートレスサービスでの接続状態共有
- **リソース枯渇**: 接続数制限とタイムアウト管理
- **対策**: Redis-based接続プールとConnection Limiting

#### 通知データの増大
- **データ成長**: ユーザー数×アクティビティ量に比例した線形成長
- **削除ポリシー**: 90日経過した既読通知の自動削除
- **対策**: パーティション戦略と効率的なクリーンアップジョブ

### 仕様・実装に関する検討事項

- **通知データの保存期間**: 90日間の妥当性検証
- **SSEイベントフォーマット**: `{"type": "new_notification"}` の詳細度
- **Web Push暗号化**: RFC 8291準拠ライブラリの選定
- **投票終了通知**: cronベースのスケジューラー実装
- **投稿更新通知**: 大量ユーザーへのバッチ通知のパフォーマンス最適化
- **通知グループ化**: リアルタイム性とリソース効率のバランス

## 17. Release Plan (リリース計画)

### 17.1. 実装フェーズ

| Phase | 内容 | 期間 | 前提条件 |
|:------|:-----|:-----|:---------|
| Phase 1 | Core Notification | Week 1-2 | PostgreSQL/Redis/NATS環境構築 |
| Phase 2 | Realtime Delivery | Week 3-4 | Phase 1 完了 |
| Phase 3 | Web Push & Preferences | Week 5-6 | Phase 2 完了 |
| Phase 4 | Advanced Features | Week 7-8 | Phase 3 完了 |
| Phase 5 | Optimization & GA | Week 9-10 | Phase 4 完了 |

#### Phase 1: Core Notification (Week 1-2)
- Notification Aggregate、NotificationEvent Aggregate実装
- PostgreSQLスキーマ作成（UUID v7によるID生成）
- NATS JetStreamイベント購読基盤の構築
- 基本的な通知生成・永続化機能（冪等性保証含む）
- 通知リスト取得API、未読件数取得API、既読化API
- リリース基準: ユニットテストカバレッジ90%以上、基本APIのレイテンシp99 < 200ms

#### Phase 2: Realtime Delivery (Week 3-4)
- SSEConnectionManager Aggregate実装
- SSEリアルタイム通知配信エンドポイント
- SSE接続管理（heartbeat 15秒間隔、接続数制限）
- Redis-basedのSSE接続状態管理
- リリース基準: SSE配信レイテンシp99 < 500ms、同時接続100,000セッション対応

#### Phase 3: Web Push & Preferences (Week 5-6)
- WebPushSubscription Aggregate実装（RFC 8291準拠暗号化）
- Web Pushサブスクリプション登録/削除API
- NotificationPreference Aggregate実装
- 通知設定管理API（種別ごと有効/無効、フィルタリング）
- リリース基準: Web Push送信成功率95%以上、設定更新のレイテンシp99 < 250ms

#### Phase 4: Advanced Features (Week 7-8)
- 通知グループ化機能（NotificationGroup Entity）
- 特定ユーザーの投稿通知（UserNotificationPreference）
- モデレーション関連通知、管理者向け通知
- Announcement Aggregate実装（サーバーアナウンス配信）
- リリース基準: グループ化処理500ms以内、管理者通知の配信遅延 < 2秒

#### Phase 5: Optimization & GA (Week 9-10)
- パフォーマンス最適化（キャッシュウォーミング、クエリ最適化）
- 負荷テスト（毎秒10,000通知生成、同時SSE接続100,000セッション）
- 古い通知の自動アーカイブ/削除バッチ処理
- カオスエンジニアリングによる障害耐性検証
- リリース基準: 全テストカバレッジ90%以上、稼働率99.9%達成、負荷テスト合格

#### Rollback Strategy
- 各Phaseのリリースは独立してロールバック可能
- データベースマイグレーションは前方互換性を保持
- フィーチャーフラグによる段階的な機能有効化
- ロールバック判断基準: エラー率 > 1%、レイテンシp99が目標値の2倍超過

### 17.2. 段階的ロールアウト戦略

**Canary Release:**
1. **5%** -- 初期検証（最低15分間監視）
2. **25%** -- 拡大検証（最低30分間監視）
3. **50%** -- 広域検証（最低1時間監視）
4. **100%** -- 全展開

**各段階の監視項目:**
- エラー率 < 1%
- レイテンシ p99 < SLO の 2倍
- CPU/Memory 使用率が正常範囲内

### 17.3. ロールバック判定基準と手順

**ロールバック判定基準:**
- エラー率が 1% を超過
- p99 レイテンシが SLO の 2倍を超過
- CRITICAL レベルのログが発生
- データ整合性エラーの検出

**ロールバック手順:**
```bash
# 1. 新バージョンのデプロイを停止
kubectl rollout pause deployment/avion-notification -n avion

# 2. 前バージョンにロールバック
kubectl rollout undo deployment/avion-notification -n avion

# 3. ロールバック完了を確認
kubectl rollout status deployment/avion-notification -n avion

# 4. 必要に応じてDBマイグレーションのロールバック
# (docs/common/database/database-migration-strategy.md 参照)
```

### 17.4. 環境デプロイ順序

1. **dev** -- 開発環境でのE2Eテスト
2. **staging** -- 本番同等環境での負荷テスト・統合テスト
3. **production** -- 段階的ロールアウト（17.2参照）

### 17.5. サービス間依存関係

- **前提サービス:** avion-user、avion-drop（通知イベント発行元）、NATS JetStream基盤
- **後続サービス:** avion-gateway（API公開）、avion-web（フロントエンド通知表示）

### 17.6. リリース前チェックリスト

- [ ] 全テストがパス（ユニット + 統合）
- [ ] カバレッジ目標達成（90%以上）
- [ ] DBマイグレーションスクリプト準備完了
- [ ] 環境変数の追加/変更がドキュメント化済み
- [ ] ロールバック手順のリハーサル完了
- [ ] 監視ダッシュボード・アラートの設定完了
- [ ] staging環境での動作確認完了

### 17.7. リリース後検証ステップ

- [ ] Canary比率の段階的拡大
- [ ] エラー率・レイテンシの継続監視
- [ ] ログの異常パターン確認
- [ ] 依存サービスとの連携正常性確認
- [ ] 24時間後のメトリクス確認

---

## 18. エラーハンドリング戦略 - 通知配信特有の課題への対応

通知システムは外部依存性が高く、配信失敗、再送制御、部分的障害への対応が重要です。以下の包括的なエラーハンドリング戦略を採用します：

### 18.1. 配信失敗パターンと対応戦略

#### Web Push配信失敗
```go
// WebPushDeliveryStrategy implements notification-specific retry logic
type WebPushDeliveryStrategy struct {
    maxRetries    int
    baseDelay     time.Duration
    maxDelay      time.Duration
    jitterPercent float64
}

func (s *WebPushDeliveryStrategy) HandleDeliveryFailure(ctx context.Context, failure WebPushFailure) error {
    switch failure.Type {
    case WebPushFailureSubscriptionExpired:
        // 無効なサブスクリプションを即座に削除
        return s.subscriptionRepo.Delete(ctx, failure.SubscriptionID)
    
    case WebPushFailurePayloadTooLarge:
        // ペイロードを最小限に縮小して再送
        minimalPayload := s.createMinimalPayload(failure.Notification)
        return s.retrySend(ctx, failure.SubscriptionID, minimalPayload)
    
    case WebPushFailureRateLimited:
        // Retry-Afterヘッダーに基づく遅延後再送
        delay := s.parseRetryAfter(failure.RetryAfter)
        return s.scheduleRetry(ctx, failure, delay)
    
    case WebPushFailureTemporary:
        // 指数バックオフによる再送（最大3回）
        if failure.AttemptCount >= s.maxRetries {
            return s.sendToDLQ(ctx, failure)
        }
        delay := s.calculateBackoffDelay(failure.AttemptCount)
        return s.scheduleRetry(ctx, failure, delay)
    
    default:
        // その他のエラーはログ記録後スキップ
        s.logger.Error("unhandled web push failure",
            slog.String("failure_type", failure.Type.String()),
            slog.String("endpoint", failure.Endpoint.Mask()),
            slog.String("error", failure.Error),
        )
        return nil
    }
}
```

#### SSE配信失敗
```go
// SSEBroadcastFailureHandler handles SSE-specific delivery failures
func (h *SSEBroadcastFailureHandler) HandleBroadcastFailure(ctx context.Context, failure SSEBroadcastFailure) {
    switch failure.Type {
    case SSEFailureConnectionClosed:
        // 閉じた接続をクリーンアップ
        h.connectionManager.CleanupConnection(ctx, failure.ConnectionID)
    
    case SSEFailureConnectionTimeout:
        // タイムアウト接続を無効化
        h.connectionManager.MarkConnectionInactive(ctx, failure.ConnectionID)
    
    case SSEFailureBufferOverflow:
        // バッファオーバーフロー時は接続を切断
        h.connectionManager.ForceDisconnect(ctx, failure.ConnectionID)
        h.metrics.RecordSSEBufferOverflow(failure.UserID)
    
    case SSEFailureNetworkError:
        // ネットワークエラーは接続状態をチェック
        if h.connectionManager.IsConnectionAlive(ctx, failure.ConnectionID) {
            h.scheduleRetry(ctx, failure)
        } else {
            h.connectionManager.CleanupConnection(ctx, failure.ConnectionID)
        }
    }
}
```

### 18.2. イベント処理の信頼性保証

#### NATS JetStreamイベント処理
```go
// EventProcessingReliabilityHandler ensures reliable event processing
func (h *EventProcessingReliabilityHandler) ProcessEventWithReliability(ctx context.Context, event NotificationEvent) error {
    // 冪等性チェック
    if processed, err := h.eventRepo.IsProcessed(ctx, event.ID); err != nil {
        return fmt.Errorf("idempotency check failed: %w", err)
    } else if processed {
        h.logger.Debug("event already processed, skipping",
            slog.String("event_id", event.ID.String()),
            slog.String("event_type", event.Type.String()),
        )
        return nil
    }
    
    // トランザクション境界での処理
    return h.txManager.WithTransaction(ctx, func(tx Transaction) error {
        // 通知生成
        notification, err := h.notificationFactory.CreateFromEvent(ctx, event)
        if err != nil {
            if errors.Is(err, domain.ErrInvalidEventType) {
                // 無効なイベントタイプはスキップ（エラーではない）
                return h.markEventAsSkipped(tx, event.ID)
            }
            return fmt.Errorf("notification creation failed: %w", err)
        }
        
        // 通知永続化
        if err := h.notificationRepo.Save(tx, notification); err != nil {
            return fmt.Errorf("notification persistence failed: %w", err)
        }
        
        // イベント処理完了マーク
        if err := h.eventRepo.MarkAsProcessed(tx, event.ID); err != nil {
            return fmt.Errorf("event completion marking failed: %w", err)
        }
        
        return nil
    })
}
```

#### Circuit Breaker パターン
```go
// CircuitBreakerConfig for external service calls
type CircuitBreakerConfig struct {
    FailureThreshold int
    RecoveryTimeout  time.Duration
    HalfOpenMaxCalls int
}

// WebPushClientWithCircuitBreaker wraps WebPush client with circuit breaker
type WebPushClientWithCircuitBreaker struct {
    client         WebPushClient
    circuitBreaker *gobreaker.CircuitBreaker
}

func (c *WebPushClientWithCircuitBreaker) Send(ctx context.Context, subscription WebPushSubscription, payload []byte) error {
    result, err := c.circuitBreaker.Execute(func() (interface{}, error) {
        return nil, c.client.Send(ctx, subscription, payload)
    })
    
    if err != nil {
        if err == gobreaker.ErrOpenState {
            // Circuit Breaker開放中はキューに保存
            return c.queueForLater(ctx, subscription, payload)
        }
        return err
    }
    
    return nil
}
```

### 18.3. 部分的障害への対応

#### Bulkhead パターンによる障害隔離
```go
// ResourcePool provides isolated resources for different notification types
type ResourcePool struct {
    webPushPool    chan struct{}
    ssePool        chan struct{}
    dbPool         chan struct{}
    processingPool chan struct{}
}

func NewResourcePool() *ResourcePool {
    return &ResourcePool{
        webPushPool:    make(chan struct{}, 100),    // Web Push専用リソース
        ssePool:        make(chan struct{}, 200),    // SSE専用リソース
        dbPool:         make(chan struct{}, 50),     // DB専用リソース
        processingPool: make(chan struct{}, 150),    // イベント処理専用リソース
    }
}

func (p *ResourcePool) ExecuteWithWebPushPool(ctx context.Context, fn func() error) error {
    select {
    case p.webPushPool <- struct{}{}:
        defer func() { <-p.webPushPool }()
        return fn()
    case <-ctx.Done():
        return ctx.Err()
    case <-time.After(5 * time.Second):
        return ErrResourcePoolTimeout
    }
}
```

### 18.4. 監視とアラート

#### メトリクスによる障害検知
```go
// NotificationMetrics tracks delivery success/failure rates
type NotificationMetrics struct {
    deliveryAttempts   *prometheus.CounterVec
    deliveryFailures   *prometheus.CounterVec
    deliveryLatency    *prometheus.HistogramVec
    retryQueueSize     *prometheus.GaugeVec
    circuitBreakerState *prometheus.GaugeVec
}

func (m *NotificationMetrics) RecordDeliveryFailure(deliveryType, failureReason string) {
    m.deliveryFailures.WithLabelValues(deliveryType, failureReason).Inc()
    
    // 失敗率が閾値を超えた場合のアラート
    failureRate := m.calculateFailureRate(deliveryType)
    if failureRate > 0.1 { // 10%以上の失敗率
        m.alertManager.TriggerAlert(AlertHighFailureRate, map[string]interface{}{
            "delivery_type": deliveryType,
            "failure_rate": failureRate,
            "timestamp":    time.Now(),
        })
    }
}
```

## 19. 追加実装時の考慮事項

### 投票関連通知
- **不変条件:** 投票通知は投票作成者のみに送信
- **冪等性:** 投票変更時の重複通知を防ぐため、`user_id + poll_id` の組み合わせで管理
- **投票終了通知:** 別途バッチ処理またはスケジューラーで実装

### フォローリクエスト通知
- **不変条件:** 非公開アカウントのみ通知を生成
- **状態管理:** フォローリクエストの承認/拒否/期限切れ状態を追跡
- **通知の無効化:** フォローリクエストが取り消された場合の通知削除

### 投稿更新通知
- **パフォーマンス:** 大量のユーザーへの通知生成をバッチ処理
- **通知対象:** リアクション、リポスト、返信したユーザーのみ
- **更新内容:** 更新の差分情報を NotificationData に含める

### 通知グループ化
- **グループ化対象:** reaction、repost、followタイプのみ
- **グループ上限:** 1グループあたり最大100件の通知
- **表示形式:** 「○人がリアクションしました」「○人がリポストしました」
- **パフォーマンス:** グループ化処理は非同期で実行
- **既読管理:** グループ内の通知を一括既読化

### 特定ユーザーの投稿通知
- **設定管理:** ユーザーごとの通知設定をUserNotificationPreferenceで管理
- **ブロック連携:** ブロック中のユーザーへの通知設定は自動無効化
- **パフォーマンス:** 人気ユーザーの場合、大量の通知発生を考慮
- **プライバシー:** 非公開アカウントの投稿は通知しない

### モデレーション関連通知
- **優先度:** 他の通知より高優先度で配信
- **内容:** 警告理由、違反内容、対処方法を明確に記載
- **追跡:** モデレーション履歴との連携
- **関係切断通知:** 影響を受けたフォロー/フォロワー数を含める

### 管理者向け通知
- **対象:** 管理者権限を持つユーザーのみ
- **種類:** 新規ユーザー登録、通報受信、システムアラート
- **配信:** 管理者全員に一斉配信
- **ダッシュボード連携:** 管理画面での一覧表示

### アナウンス機能
- **対象設定:** 全ユーザー、特定ユーザーグループ、個別ユーザー
- **期間管理:** 開始/終了日時の自動制御
- **多言語対応:** 複数言語でのアナウンス配信
- **既読追跡:** アナウンスごとの既読率統計

## 20. サービス固有のテスト戦略

このサービスでは、[共通テスト戦略](../common/testing-strategy.md)に加えて、以下のサービス固有のテスト要件を実装します。

### 20.1 WebPush/SSE配信テスト

#### 20.1.1 WebPush暗号化テスト（RFC 8291準拠）

```go
package webpush_test

import (
    "errors"
    "testing"

    "github.com/google/go-cmp/cmp"
    domain "github.com/avion/avion-notification/internal/domain/webpush"
)

// WebPush暗号化のテスト
func TestWebPushEncryption_EncryptPayload(t *testing.T) {
    t.Parallel()

    validSubscription := &domain.WebPushSubscription{
        Endpoint: "https://fcm.googleapis.com/fcm/send/xxx",
        Keys: domain.WebPushKeys{
            P256dh: "validP256dhKey",
            Auth:   "validAuthKey",
        },
    }

    tests := []struct {
        name         string
        payload      string
        subscription *domain.WebPushSubscription
        wantEncoding string
        wantErr      error
    }{
        {
            name:         "正常系: 小さいペイロードの暗号化が成功する",
            payload:      `{"title":"Test","body":"Hello"}`,
            subscription: validSubscription,
            wantEncoding: "aes128gcm",
            wantErr:      nil,
        },
        {
            name:         "正常系: 最大サイズペイロード（4KB）の暗号化が成功する",
            payload:      generateLargePayload(4096),
            subscription: validSubscription,
            wantEncoding: "aes128gcm",
            wantErr:      nil,
        },
        {
            name:         "異常系: ペイロードサイズ超過でエラーを返す",
            payload:      generateLargePayload(4097),
            subscription: validSubscription,
            wantErr:      domain.ErrWebPushPayloadTooLarge,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()

            encrypted, err := domain.EncryptWebPushPayload(
                []byte(tt.payload),
                tt.subscription,
            )

            if !errors.Is(err, tt.wantErr) {
                t.Errorf("error = %v, wantErr %v", err, tt.wantErr)
                return
            }

            if tt.wantErr == nil {
                if encrypted.CipherText == nil {
                    t.Error("CipherText should not be nil")
                }
                if diff := cmp.Diff(tt.wantEncoding, encrypted.ContentEncoding); diff != "" {
                    t.Errorf("ContentEncoding mismatch (-want +got):\n%s", diff)
                }
            }
        })
    }
}

// VAPID署名生成テスト
func TestVAPIDSignature(t *testing.T) {
    privateKey, publicKey := generateVAPIDKeys(t)
    
    tests := []struct {
        name     string
        endpoint string
        exp      int64
        wantErr  bool
    }{
        {
            name:     "正常系: 有効な署名",
            endpoint: "https://fcm.googleapis.com/fcm/send/xxx",
            exp:      time.Now().Add(12 * time.Hour).Unix(),
            wantErr:  false,
        },
        {
            name:     "異常系: 期限切れ",
            endpoint: "https://fcm.googleapis.com/fcm/send/xxx",
            exp:      time.Now().Add(-1 * time.Hour).Unix(),
            wantErr:  true,
        },
        {
            name:     "異常系: 期限が24時間超",
            endpoint: "https://fcm.googleapis.com/fcm/send/xxx",
            exp:      time.Now().Add(25 * time.Hour).Unix(),
            wantErr:  true,
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            token, err := GenerateVAPIDToken(
                tt.endpoint,
                privateKey,
                publicKey,
                tt.exp,
            )
            
            if (err != nil) != tt.wantErr {
                t.Errorf("GenerateVAPIDToken() error = %v, wantErr %v", 
                    err, tt.wantErr)
                return
            }
            
            if !tt.wantErr {
                // JWT形式の検証
                parts := strings.Split(token, ".")
                require.Len(t, parts, 3)
            }
        })
    }
}
```

#### 20.1.2 SSE接続管理テスト

```go
// SSE接続ライフサイクルテスト
func TestSSEConnectionLifecycle(t *testing.T) {
    manager := NewSSEConnectionManager()
    
    tests := []struct {
        name           string
        connections    int
        disconnections int
        expectedActive int
    }{
        {
            name:           "100接続の追加と管理",
            connections:    100,
            disconnections: 0,
            expectedActive: 100,
        },
        {
            name:           "50接続の切断",
            connections:    0,
            disconnections: 50,
            expectedActive: 50,
        },
        {
            name:           "全接続の切断",
            connections:    0,
            disconnections: 50,
            expectedActive: 0,
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // 接続追加
            for i := 0; i < tt.connections; i++ {
                conn := &SSEConnection{
                    ID:     fmt.Sprintf("conn-%d", i),
                    UserID: fmt.Sprintf("user-%d", i%10),
                    Events: make(chan *SSEEvent, 100),
                }
                manager.AddConnection(conn)
            }
            
            // 接続切断
            for i := 0; i < tt.disconnections; i++ {
                manager.RemoveConnection(fmt.Sprintf("conn-%d", i))
            }
            
            // アクティブ接続数の確認
            require.Equal(t, tt.expectedActive, manager.ActiveConnections())
        })
    }
}

// SSEイベント配信テスト
func TestSSEEventDelivery(t *testing.T) {
    manager := NewSSEConnectionManager()
    
    // 1000接続を作成
    connections := make([]*SSEConnection, 1000)
    for i := 0; i < 1000; i++ {
        conn := &SSEConnection{
            ID:     fmt.Sprintf("conn-%d", i),
            UserID: fmt.Sprintf("user-%d", i%100),
            Events: make(chan *SSEEvent, 10),
        }
        connections[i] = conn
        manager.AddConnection(conn)
    }
    
    // イベント配信
    event := &SSEEvent{
        Type: "notification",
        Data: map[string]interface{}{
            "title": "Test Notification",
            "body":  "This is a test",
        },
    }
    
    start := time.Now()
    delivered := manager.BroadcastToUsers(
        generateUserIDs(100),
        event,
    )
    duration := time.Since(start)
    
    // パフォーマンス検証
    require.Equal(t, 1000, delivered)
    require.Less(t, duration, 100*time.Millisecond,
        "1000接続への配信は100ms以内で完了すべき")
    
    // 各接続でイベント受信確認
    for _, conn := range connections {
        select {
        case received := <-conn.Events:
            require.Equal(t, event.Type, received.Type)
        case <-time.After(1 * time.Second):
            t.Fatal("イベントが受信されませんでした")
        }
    }
}
```

### 20.2 イベント駆動処理テスト

#### 20.2.1 NATS JetStreamイベント消費テスト

```go
// イベント重複排除テスト
func TestEventDeduplication(t *testing.T) {
    ctx := context.Background()
    processor := NewNotificationEventProcessor()
    
    // 同一イベントを複数回送信
    event := &NotificationEvent{
        EventID:   "evt-123",
        UserID:    "user-456",
        Type:      "follow",
        CreatedAt: time.Now(),
    }
    
    // 5回同じイベントを処理
    var processedCount int
    for i := 0; i < 5; i++ {
        processed, err := processor.ProcessEvent(ctx, event)
        require.NoError(t, err)
        if processed {
            processedCount++
        }
    }
    
    // イデンポテンシー確認（1回のみ処理）
    require.Equal(t, 1, processedCount,
        "同一EventIDは1回のみ処理されるべき")
}

// NATS JetStream消費パフォーマンステスト
func TestNATSJetStreamConsumption(t *testing.T) {
    if testing.Short() {
        t.Skip("Skipping integration test")
    }

    ctx := context.Background()

    // NATSコンテナ起動
    natsServer := setupNATSContainer(t)
    defer natsServer.Terminate(ctx)

    nc := setupNATSClient(t, natsServer)
    js, err := nc.JetStream()
    require.NoError(t, err)

    // Streamとコンシューマーのセットアップ
    _, err = js.AddStream(&nats.StreamConfig{
        Name:     "NOTIFICATION",
        Subjects: []string{"avion.notification.events.*"},
    })
    require.NoError(t, err)

    consumer := NewJetStreamConsumer(js, "NOTIFICATION", "notification_workers")

    // 10,000イベントを投入
    for i := 0; i < 10000; i++ {
        payload, _ := json.Marshal(map[string]interface{}{
            "event_id": fmt.Sprintf("evt-%d", i),
            "user_id":  fmt.Sprintf("user-%d", i%100),
            "type":     "notification",
        })
        _, err := js.Publish("avion.notification.events.created", payload)
        require.NoError(t, err)
    }

    // 消費開始
    var consumed int32
    start := time.Now()

    go func() {
        err := consumer.Consume(ctx, func(msg *nats.Msg) error {
            atomic.AddInt32(&consumed, 1)
            return msg.Ack()
        })
        require.NoError(t, err)
    }()

    // 全イベント消費まで待機
    require.Eventually(t, func() bool {
        return atomic.LoadInt32(&consumed) == 10000
    }, 10*time.Second, 100*time.Millisecond)

    duration := time.Since(start)
    throughput := float64(10000) / duration.Seconds()

    t.Logf("Consumed 10,000 events in %v (%.2f events/sec)",
        duration, throughput)
    require.Greater(t, throughput, 1000.0,
        "スループットは1000イベント/秒以上必要")
}
```

### 20.3 通知配信リトライテスト

```go
// 指数バックオフリトライテスト
func TestNotificationRetryWithBackoff(t *testing.T) {
    tests := []struct {
        name           string
        failureCount   int
        expectedDelay  time.Duration
        shouldGiveUp   bool
    }{
        {
            name:          "1回目の失敗",
            failureCount:  1,
            expectedDelay: 1 * time.Second,
            shouldGiveUp:  false,
        },
        {
            name:          "3回目の失敗",
            failureCount:  3,
            expectedDelay: 4 * time.Second,
            shouldGiveUp:  false,
        },
        {
            name:          "5回目の失敗（最大リトライ）",
            failureCount:  5,
            expectedDelay: 16 * time.Second,
            shouldGiveUp:  true,
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            retrier := NewExponentialBackoffRetrier()
            
            delay, giveUp := retrier.NextDelay(tt.failureCount)
            
            require.Equal(t, tt.shouldGiveUp, giveUp)
            if !giveUp {
                require.Equal(t, tt.expectedDelay, delay)
            }
        })
    }
}

// エンドポイント無効化検出テスト
func TestEndpointInvalidation(t *testing.T) {
    notifier := NewWebPushNotifier()
    
    tests := []struct {
        name           string
        statusCode     int
        shouldInvalidate bool
    }{
        {
            name:           "410 Gone - 無効化すべき",
            statusCode:     410,
            shouldInvalidate: true,
        },
        {
            name:           "404 Not Found - 無効化すべき",
            statusCode:     404,
            shouldInvalidate: true,
        },
        {
            name:           "500 Server Error - リトライ",
            statusCode:     500,
            shouldInvalidate: false,
        },
        {
            name:           "429 Too Many Requests - リトライ",
            statusCode:     429,
            shouldInvalidate: false,
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := &WebPushError{
                StatusCode: tt.statusCode,
                Endpoint:   "https://example.com/push",
            }
            
            shouldInvalidate := notifier.ShouldInvalidateEndpoint(err)
            require.Equal(t, tt.shouldInvalidate, shouldInvalidate)
        })
    }
}
```

### 20.4 通知優先度とバッチングテスト

```go
// 通知優先度管理テスト
func TestNotificationPriority(t *testing.T) {
    queue := NewPriorityNotificationQueue()
    
    // 異なる優先度の通知を追加
    notifications := []struct {
        id       string
        priority NotificationPriority
    }{
        {"n1", PriorityLow},
        {"n2", PriorityHigh},
        {"n3", PriorityNormal},
        {"n4", PriorityCritical},
        {"n5", PriorityNormal},
    }
    
    for _, n := range notifications {
        queue.Add(&Notification{
            ID:       n.id,
            Priority: n.priority,
        })
    }
    
    // 優先度順に取得
    expected := []string{"n4", "n2", "n3", "n5", "n1"}
    for _, expectedID := range expected {
        notification := queue.Pop()
        require.Equal(t, expectedID, notification.ID)
    }
}

// 通知バッチング最適化テスト
func TestNotificationBatching(t *testing.T) {
    batcher := NewNotificationBatcher(
        100,              // バッチサイズ
        100*time.Millisecond, // バッチタイムアウト
    )
    
    // 500通知を送信
    var wg sync.WaitGroup
    wg.Add(500)
    
    for i := 0; i < 500; i++ {
        go func(id int) {
            defer wg.Done()
            notification := &Notification{
                ID:     fmt.Sprintf("n-%d", id),
                UserID: fmt.Sprintf("user-%d", id%50),
            }
            batcher.Add(notification)
        }(i)
    }
    
    // バッチ処理
    var batchCount int
    var totalProcessed int
    
    go func() {
        for batch := range batcher.Batches() {
            batchCount++
            totalProcessed += len(batch)
            
            // バッチサイズ検証
            require.LessOrEqual(t, len(batch), 100)
        }
    }()
    
    wg.Wait()
    time.Sleep(200 * time.Millisecond) // バッチタイムアウト待機
    batcher.Close()
    
    // 結果検証
    require.Equal(t, 500, totalProcessed)
    require.GreaterOrEqual(t, batchCount, 5)
    require.LessOrEqual(t, batchCount, 10)
}
```

### 20.5 パフォーマンステスト基準

| テスト項目 | 目標値 | 測定方法 |
|-----------|--------|----------|
| SSE同時接続数 | 100,000接続 | 負荷テスト |
| SSEイベント配信遅延 | p99 < 100ms | レイテンシ測定 |
| WebPush配信スループット | 10,000/秒 | ベンチマーク |
| NATS JetStream消費速度 | 5,000イベント/秒 | 統合テスト |
| 通知バッチ処理 | 1,000通知/バッチ | 最適化テスト |

### 20.6 CI/CD固有の設定

```yaml
# avion-notification固有のCI設定
notification-service-tests:
  services:
    redis:
      image: redis:8-alpine
      command: redis-server --appendonly yes
    
    postgres:
      image: postgres:17
      env:
        POSTGRES_DB: notification_test
        POSTGRES_PASSWORD: test
  
  env:
    # WebPush設定
    VAPID_PRIVATE_KEY: test-private-key
    VAPID_PUBLIC_KEY: test-public-key
    
    # SSE設定
    MAX_SSE_CONNECTIONS: 100000
    SSE_KEEPALIVE_INTERVAL: 15s
    
    # パフォーマンス閾値
    MAX_NOTIFICATION_LATENCY_MS: 100
    MIN_THROUGHPUT_PER_SEC: 1000
  
  timeout: 20m  # SSE/WebPushテストは時間がかかる
```

### 20.7 テスト実行マトリクス

| テストタイプ | 実行タイミング | 実行時間目標 | 必須/任意 |
|------------|--------------|-------------|----------|
| Unit Tests | Every commit | < 2min | 必須 |
| Integration | Every PR | < 5min | 必須 |
| E2E (WebPush/SSE) | Before merge | < 15min | 必須 |
| Load Tests | Nightly | < 30min | 必須 |
| Stress Tests | Weekly | < 1hr | 任意 |
