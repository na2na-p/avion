# Design Doc: avion-notification

**Author:** Cline
**Last Updated:** 2026/03/15

## 関連ドキュメント

本DesignDocは可読性のため目的別に分割されています。

| ドキュメント | 内容 |
|:------------|:-----|
| **本文書 (designdoc.md)** | 概要、ドメインモデル、API定義、データ設計、連携仕様、リリース計画 |
| [designdoc-channels.md](./designdoc-channels.md) | 通知配信チャネル（SSE配信失敗対応、WebPush実装、Circuit Breaker、Bulkhead、監視） |
| [designdoc-grouping.md](./designdoc-grouping.md) | 通知グループ化、優先度計算、バッチ処理、追加実装時の考慮事項 |
| [designdoc-infra-testing.md](./designdoc-infra-testing.md) | 構造化ログ戦略、エラーハンドリング戦略、インフラ層マッピング、テスト戦略 |

---

## 1. Summary (これは何？)

- **一言で:** Avionにおけるユーザーへの通知（メンション、フォロー、リアクション、リポストなど）を生成、管理、および配信 (SSE, Web Push) するマイクロサービスを実装します。
- **目的:** ユーザーに関連するイベントを検知し、通知データを作成・永続化します。リアルタイム (SSE) およびプッシュ (Web Push) でユーザーに通知を届け、未読管理機能を提供します。

## 2. テスト戦略

このサービスでは、[共通テスト戦略](../common/testing-strategy.md)に従ってテストを実装します。

### テスト方針
- **TDD必須**: インターフェース定義 → テスト作成 → 実装の順序を厳守
- **カバレッジ目標**: ユニットテスト85%以上、クリティカルパス95%以上
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
- ダイレクトメッセージ関連イベント (`message.sent`, `message.delivered`, `message.reaction_added`, `conversation.created`, `participant.added`) を avion-message から購読し、通知を生成。
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
    - イベント発行元サービス (`avion-user`, `avion-drop`, `avion-message`, `avion-activitypub`)。
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
  - 通知属性: NotificationType (follow, mention, reaction, repost, quote_repost, reply, poll_vote, poll_end, follow_request, follow_request_accepted, drop_updated, status, system, admin_user_registered, admin_report_created, moderation_warning, severed_relationships, announcement, direct_message, group_message, message_reaction, conversation_invite), EventType, ReadStatus, NotificationData, EventData
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
  - ProcessMessageEventCommandUseCase: ダイレクトメッセージ関連通知処理（message.sent, conversation.created, participant.added等）
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
  - NotificationType（Value Object）: 'follow', 'mention', 'reaction', 'repost', 'quote_repost', 'reply', 'poll_vote', 'poll_end', 'follow_request', 'follow_request_accepted', 'drop_updated', 'status', 'system', 'admin_user_registered', 'admin_report_created', 'moderation_warning', 'severed_relationships', 'announcement', 'direct_message', 'group_message', 'message_reaction', 'conversation_invite'
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
  - EventType（Value Object）: 'follow_created', 'mention_created', 'reaction_created', 'repost_created', 'quote_repost_created', 'reply_created', 'poll_voted', 'poll_ended', 'follow_request_created', 'follow_request_accepted', 'drop_updated', 'drop_created', 'user_registered', 'report_created', 'moderation_action_taken', 'relationships_severed', 'announcement_published', 'message_sent', 'message_delivered', 'message_reaction_added', 'conversation_created', 'participant_added'
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

### セキュリティガイドライン参照

- [XSS対策](../common/security/xss-prevention.md)
- [SQLインジェクション対策](../common/security/sql-injection-prevention.md)
- [TLS設定](../common/security/tls-configuration.md)

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
        - `type (VARCHAR(50), NOT NULL)` // NotificationType Value Object (22種類: follow, mention, reaction, repost, quote_repost, reply, poll_vote, poll_end, follow_request, follow_request_accepted, drop_updated, status, system, admin_user_registered, admin_report_created, moderation_warning, severed_relationships, announcement, direct_message, group_message, message_reaction, conversation_invite)
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

> **詳細は [designdoc-infra-testing.md](./designdoc-infra-testing.md) を参照してください。**

## 13. エラーハンドリング戦略

> **詳細は [designdoc-infra-testing.md](./designdoc-infra-testing.md) を参照してください。**

## 14. ドメインオブジェクトとデータベース/キューのマッピング

> **詳細は [designdoc-infra-testing.md](./designdoc-infra-testing.md) を参照してください。**

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

### 15.3. avion-message との連携

**Purpose:** ダイレクトメッセージ関連の通知生成

**Integration Method:** NATS JetStream（イベント駆動）

**責務境界:**
- avion-notification: DM関連通知の生成・配信・既読管理を担当
- avion-message: メッセージ固有の通知制御（会話ミュート、DnD）を管理し、イベントペイロードに制御情報を含めて発行

**Data Flow:**
1. avion-message がメッセージ送信等のビジネスロジックを処理
2. avion-message が `message.sent` 等のドメインイベントを NATS JetStream に発行（ペイロードにミュート・DnD情報を含む）
3. avion-notification がイベントを消費し、受信者の通知設定とメッセージ固有設定を考慮して通知生成
4. SSE/Web Push で通知を配信（メッセージ本文のリアルタイム配信は avion-message が WebSocket で直接行う）

**Error Handling:** avion-message のイベント発行失敗時は NATS JetStream の配信保証に依存。avion-notification 側での処理失敗時はリトライ後 DLQ に移動。

### 15.4. Event Publishing

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

### 15.5. Event Consuming

**Events Consumed:**
- `avion.user.follow.created`: avion-userからフォロー通知生成用
- `avion.drop.reaction.created`: avion-dropからリアクション通知生成用
- `avion.drop.repost.created`: avion-dropからリポスト通知生成用
- `avion.drop.mention.created`: avion-dropからメンション通知生成用
- `avion.drop.poll.voted`: avion-dropから投票通知生成用
- `avion.drop.drop.updated`: avion-dropから投稿更新通知生成用
- `avion.message.message.sent`: avion-messageから新規メッセージ受信通知生成用
- `avion.message.message.delivered`: avion-messageからメッセージ配信完了通知用
- `avion.message.message.reaction_added`: avion-messageからメッセージリアクション通知生成用
- `avion.message.conversation.created`: avion-messageから会話作成通知用
- `avion.message.participant.added`: avion-messageから会話招待通知生成用

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
- リリース基準: ユニットテストカバレッジ85%以上、基本APIのレイテンシp99 < 200ms

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
- リリース基準: 全テストカバレッジ85%以上、稼働率99.9%達成、負荷テスト合格

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

- **前提サービス:** avion-user、avion-drop、avion-message（通知イベント発行元）、NATS JetStream基盤
- **後続サービス:** avion-gateway（API公開）、avion-web（フロントエンド通知表示）

### 17.6. リリース前チェックリスト

- [ ] 全テストがパス（ユニット + 統合）
- [ ] カバレッジ目標達成（85%以上）
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

> **詳細は [designdoc-channels.md](./designdoc-channels.md) を参照してください。**

## 19. 追加実装時の考慮事項

> **詳細は [designdoc-grouping.md](./designdoc-grouping.md) を参照してください。**

## 20. サービス固有のテスト戦略

> **詳細は [designdoc-infra-testing.md](./designdoc-infra-testing.md) を参照してください。**
