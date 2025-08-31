# Design Doc: avion-activitypub

**Author:** Cline
**Last Updated:** 2025/03/30

## 1. Summary (これは何？)

- **一言で:** AvionをActivityPubプロトコルに対応させ、他の互換サーバー（Mastodon、Misskey、Pleroma等）との連合（Federation）を実現するマイクロサービスを実装します。
- **目的:** ActivityPubアクティビティの送受信 (Inbox/Outbox)、Actor情報の提供 (WebFinger含む)、HTTP Signaturesによる検証・署名、リモート情報の管理・キャッシュ連携を行います。

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
- ActivityPub Inbox/Outbox処理の完全なワークフロー
- HTTP Signaturesによる署名検証・署名付与の確認
- WebFinger Discovery機能の正常性確認
- リモートアクター情報のフェッチとキャッシュ管理
- 他インスタンスとのFollow/Unfollow機能連携
- リモート投稿のローカルインスタンスへの取り込み
- ローカル投稿の他インスタンスへの配送確認
- ドメインブロック/許可機能の動作確認

詳細は[共通E2Eテスト戦略ドキュメント](../common/e2e-testing-strategy.md)を参照してください。

詳細は[共通テスト戦略ドキュメント](../common/testing-strategy.md)を参照してください。

## 3. 技術スタック

このサービスでは、[共通Goバックエンド技術スタックガイドライン](../common/architecture/go-backend-framework.md)に従った実装を行います。

### 主要技術
- **HTTPルーティング:** Chi v5
- **RPC:** ConnectRPC
- **ミドルウェア:** 標準net/httpベースの共通ミドルウェア
- **ActivityPub関連:** JSON-LD処理ライブラリ、HTTP署名標準実装

詳細な実装パターンおよびライブラリの使用方法については、[ガイドライン](../common/architecture/go-backend-framework.md)を参照してください。

## 4. Background & Links (背景と関連リンク)

- AvionをFediverseの一部として機能させ、相互運用性を確保するため。
- 複雑なActivityPubプロトコル処理を他のコアサービスから分離するため。
- [PRD: avion-activitypub](./prd.md)
- [Avion アーキテクチャ概要](../common/architecture.md)
- ActivityPub, ActivityStreams, WebFinger, HTTP Signatures等の関連仕様。

## 5. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

- ActivityPub Actor (Person) エンドポイントの実装 (`/users/{username}`)。
- WebFingerエンドポイントの実装 (`/.well-known/webfinger`)。
- Inboxエンドポイントの実装 (`/inbox`, `/users/{username}/inbox`)。
    - HTTP Signatures検証 (公開鍵は `avion-user` またはキャッシュから取得)。
    - 受信アクティビティ (Create, Update, Delete, Follow, Accept, Reject, Announce, Like, Undo等) の解釈と、関連サービスへのイベント発行 (Redis Pub/Sub)。
- Outbox処理の実装 (非同期、Redis Stream + Consumer Group)。
    - ローカルイベント (Drop作成、フォロー、リアクション等) を購読 (Redis Pub/Sub)。
    - 対応するActivityPubアクティビティを生成。
    - HTTP Signaturesで署名 (秘密鍵は `avion-user` に問い合わせ)。
    - 対象リモートActorのInboxへ配送 (共有Inbox利用含む)。
    - 指数バックオフによるリトライ機構とデッドレターキュー (DLQ)。
- リモートActor/Object情報のキャッシュ/DB保存 (定期的な削除ポリシー含む)。
- リモートメディアのキャッシュ依頼 (`avion-media` へ)。
- Go言語で実装し、Kubernetes上でのステートレス運用を前提とする。
- OpenTelemetryによるトレーシング・メトリクス・ロギング対応。

### Non-Goals (やらないこと)

- **ActivityPub Client-to-Server (C2S) プロトコル。**
- **全てのActivityPubアクティビティ/オブジェクトタイプの完全サポート (初期)。**
- **複雑なActivityPubアクセス制御ロジック (初期)。**
- **リレーサーバー機能 (初期)。**
- **高度なスパム/不正行為対策 (初期)。**
- **Outbox処理における厳密な順序保証 (初期)。**

## 6. Architecture (どうやって作る？)

### 5.1. レイヤードアーキテクチャ (DDD準拠)

#### Domain Layer (ドメイン層)

##### Aggregates (集約)

###### RemoteActor (リモートアクター集約)
- **責務:** リモートActorの情報と状態を管理する集約
- **集約ルート:** RemoteActor
- **不変条件:**
  - ActorURIは一意かつ変更不可（W3C ActivityPub仕様準拠）
  - UsernameとDomainの組み合わせは一意（WebFinger準拠）
  - PublicKeyPEMは有効なRSA公開鍵（2048bit以上）
  - InboxURLとOutboxURLは有効なHTTPS URL（RFC 3986準拠）
  - LastFetchedAtは取得後必須更新（キャッシュ無効化制御）
  - SuspendedActorは全アクティビティ受信を停止
  - FederationStatusは定義された値（active, suspended, migrated, deleted）のいずれか
  - TrustScoreは0.0〜1.0の範囲（スパム対策用）
- **ドメインロジック:**
  - `CanReceiveActivity(activityType)`: アクティビティ受信可能性判定（タイプ別制御）
  - `NeedsRefresh(cachePolicy)`: 情報更新必要性判定（TTL・ポリシーベース）
  - `UpdateProfile(actorDocument)`: プロフィール情報の差分更新とバージョン管理
  - `VerifySignature(httpSignature)`: HTTP Signature検証（draft-cavage-http-signatures-12準拠）
  - `Suspend(reason)`: アクター停止処理（理由記録付き）
  - `Unsuspend()`: アクター復旧処理（履歴記録）
  - `MarkAsUnreachable(errorInfo)`: 到達不能マーク（エラー情報付き）
  - `MarkAsReachable()`: 到達可能マーク（失敗回数リセット）
  - `MoveTo(targetActor)`: アカウント移行処理
  - `ToActivityPubActor()`: ActivityPub Actor形式への変換（JSON-LD）
  - `CalculateTrustScore()`: 信頼度スコア算出（スパム対策）
  - `ValidateInvariants()`: 不変条件の実行時検証

###### FederationDelivery (Federation配送集約)
- **責務:** ActivityPub配送タスクの状態、配送履歴、信頼性制御を管理する集約
- **集約ルート:** FederationDelivery  
- **不変条件:**
  - DeliveryStatusは定義された値（pending, delivering, delivered, failed, dead_letter）のいずれか
  - RetryCountはMaxRetries（5回）を超えない
  - DeliveredAtは配送成功時のみ設定（UTC精度）
  - NextRetryAtは失敗時のみ設定（指数バックオフ）
  - ActivityContentは有効なActivityPubアクティビティ（JSON-LD）
  - Priorityは1-10の範囲（1=highest, 10=lowest）
  - TargetInboxURLは有効なHTTPS URL
  - CircuitBreakerStateは各ドメインごとに管理
- **ドメインロジック:**
  - `CanRetry()`: リトライ可能性判定（最大回数・時間制限チェック）
  - `ScheduleRetry(backoffStrategy)`: 次回リトライのスケジューリング（指数バックオフ）
  - `MarkAsDelivered(responseInfo)`: 配送成功の記録（レスポンス情報付き）
  - `MarkAsFailed(errorInfo)`: 配送失敗の記録（詳細エラー情報）
  - `MoveToDeadLetter(reason)`: デッドレターキューへの移動（理由記録）
  - `ShouldCircuitBreak(domain)`: ドメイン別サーキットブレーカー発動判定
  - `CalculateBackoffDelay(attemptNumber)`: バックオフ遅延計算（最大24時間）
  - `UpdatePriority(newPriority)`: 配送優先度の動的更新
  - `CanBatch(otherDelivery)`: バッチ配送可能性の判定
  - `RecordDeliveryMetrics()`: 配送統計の記録

###### BlockedActor (ブロック済みアクター集約)
- **責務:** ブロックされたActorの管理と制御
- **集約ルート:** BlockedActor
- **不変条件:**
  - BlockReasonは必須（spam, harassment, illegal_content等）
  - BlockedAtは設定後変更不可
  - IsActiveはブロック状態を正確に表現
  - 同一Actorの重複ブロックは不可
  - ブロック解除には適切な権限が必要
- **ドメインロジック:**
  - `IsBlocked()`: ブロック状態確認（期限付きブロック対応）
  - `CanUnblock()`: ブロック解除可能性判定（権限・期限チェック）
  - `Unblock()`: ブロック解除処理（履歴記録）
  - `ShouldRejectActivity()`: アクティビティ拒否判定
  - `GetBlockSeverity()`: ブロック重要度判定
  - `IsTemporaryBlock()`: 一時的ブロックかの判定

###### ReportedContent (通報コンテンツ集約)
- **責務:** 通報されたコンテンツの管理と処理状況追跡
- **集約ルート:** ReportedContent
- **不変条件:**
  - ReportReasonは定義された値のいずれか（spam, harassment, misinformation等）
  - ReportStatusは処理状況を正確に反映（pending, reviewing, resolved, rejected）
  - ReporterActorIDは変更不可
  - TargetContentURIは必須かつ有効
  - 同一内容の重複通報は統合管理
- **ドメインロジック:**
  - `CanProcess()`: 処理可能性判定（権限・状態チェック）
  - `MarkAsProcessed()`: 処理完了記録（対応内容含む）
  - `EscalateToModerator()`: モデレーターエスカレーション
  - `RequiresAction()`: 対応必要性判定（緊急度評価）
  - `IsDuplicate()`: 重複通報判定
  - `GetProcessingPriority()`: 処理優先度算出
- **Entities:**
  - RemoteObject: リモートのActivityPubオブジェクト
  - Activity: 配送するアクティビティ
  - DeliveryAttempt: 配送試行記録
  - Question: 投票オブジェクト
  - Answer: 投票回答
- **Domain Events:**
  - RemoteActorDiscovered: 新しいリモートActorが発見された
  - ActivityReceived: アクティビティを受信した
  - DeliverySucceeded: 配送が成功した
  - DeliveryFailed: 配送が失敗した
  - CircuitBreakerStateChanged: サーキットブレーカー状態が変更された
  - ActorBlocked: Actorがブロックされた
  - ActorUnblocked: Actorのブロックが解除された
  - ContentReported: コンテンツが通報された
  - ActorMoved: Actorが移行した
  - QuestionReceived: 投票を受信した
  - AnswerReceived: 投票回答を受信した
  - ActorRefreshRequired: Actor情報の更新が必要
  - DeliveryTemporarilyFailed: 配送が一時的に失敗した
  - DeliveryPermanentlyFailed: 配送が恒久的に失敗した
- **Value Objects:**
  - ActorURI, InboxURL, ActivityContent, DeliveryStatus等
  - RetryPolicy: リトライポリシー（最大回数、バックオフ戦略）
  - CircuitBreakerState: サーキットブレーカー状態（CLOSED, OPEN, HALF_OPEN）
  - BlockReason: ブロック理由
  - ReportReason: 通報理由
  - MoveTarget: 移行先Actor情報
  - QuestionOption: 投票選択肢
  - DeliveryFailureType: 配送失敗タイプ（temporary, permanent）
  - CommunityActorType: コミュニティActorタイプ（Group固定）
  - CommunityJoinMode: 参加モード（open, approval, invite_only）
  - CommunityRole: コミュニティ役割（owner, moderator, member）
  - TopicType: トピックタイプ（general, announcement, restricted）
  - CommunityContext: コミュニティコンテキスト（avion名前空間拡張）
- **Domain Services:**
  - **ActivityPubTranslator**: 外部ActivityPubプロトコルとドメインモデル間の変換を担うアンチコラプションレイヤー
    - 責務: 外部プロトコルからの保護、ドメインモデルの清潔保持、プロトコル拡張への対応
    - メソッド:
      ```go
      type ActivityPubTranslator interface {
          // 外部ActivityPubオブジェクトをドメインオブジェクトに変換
          TranslateActor(apActor APActor) (*RemoteActor, error)
          TranslateActivity(apActivity APActivity) (*FederationActivity, error)
          
          // ドメインオブジェクトを外部形式に変換
          ToActivityPubActor(actor *LocalActor) (APActor, error)
          ToActivityPubActivity(activity *LocalActivity) (APActivity, error)
      }
      ```
  - **SignatureVerificationService**: HTTP Signatures検証ロジックを実装するドメインサービス
    - 責務: HTTP署名の検証、公開鍵の取得と管理、署名アルゴリズムの選択
    - メソッド:
      ```go
      type SignatureVerificationService interface {
          VerifyHTTPSignature(request HTTPRequest, publicKey PublicKey) error
          FetchPublicKey(actorURI ActorURI) (PublicKey, error)
          ValidateSignatureHeaders(headers map[string]string) error
          DetermineSignatureAlgorithm(keyType string) SignatureAlgorithm
      }
      ```
  - **ActivityBuilder**: ActivityPubアクティビティ生成ロジックを実装するドメインサービス
    - 責務: 各種アクティビティの構築、JSONLDコンテキストの管理、オブジェクトのシリアライズ
    - メソッド:
      ```go
      type ActivityBuilder interface {
          BuildCreateActivity(actor Actor, object ActivityObject) Activity
          BuildFollowActivity(actor Actor, targetActor Actor) Activity
          BuildLikeActivity(actor Actor, targetObject ActivityObject) Activity
          BuildAnnounceActivity(actor Actor, targetObject ActivityObject) Activity
          BuildUndoActivity(actor Actor, targetActivity Activity) Activity
          BuildJoinActivity(actor Actor, targetGroup Actor) Activity
          BuildLeaveActivity(actor Actor, targetGroup Actor) Activity
          BuildInviteActivity(actor Actor, targetActor Actor, targetGroup Actor) Activity
          BuildAddActivity(actor Actor, targetActor Actor, targetGroup Actor, role string) Activity
          BuildRemoveActivity(actor Actor, targetActor Actor, targetGroup Actor) Activity
          SerializeActivity(activity Activity) ([]byte, error)
          SerializeActivityWithContext(activity Activity, context []interface{}) ([]byte, error)
      }
      ```
  - **PlatformDetectionService**: プラットフォーム検出を実装するドメインサービス
    - 責務: NodeInfo、WebFinger、Actorパターンからプラットフォームを特定
    - メソッド:
      ```go
      type PlatformDetectionService interface {
          DetectPlatform(domain string) Platform
          DetectViaNodeInfo(domain string) Platform
          DetectViaWebFinger(domain string) Platform
          DetectViaActorPattern(domain string) Platform
          IsMastodon(domain string) bool
          IsMisskey(domain string) bool
          IsLemmy(domain string) bool
          SupportGroupActor(platform Platform) bool
          SupportCustomEmoji(platform Platform) bool
          GetPlatformCapabilities(platform Platform) Capabilities
      }
      ```
  - **PlatformAdaptationService**: プラットフォーム別のアクティビティ変換を実装するドメインサービス
    - 責務: 各プラットフォームに最適化されたアクティビティを生成
    - メソッド:
      ```go
      type PlatformAdaptationService interface {
          AdaptCreateActivity(activity Activity, platform Platform) Activity
          AdaptGroupActor(group GroupActor, platform Platform) Actor
          FallbackToPersonActor(group GroupActor) PersonActor
          AddMastodonFields(activity Activity) Activity
          AddMisskeyExtensions(activity Activity) Activity
          AddLemmyGroupFields(actor Actor) Actor
          SimplifyForUnsupportedPlatform(activity Activity) Activity
          RemoveUnsupportedFields(activity Activity, platform Platform) Activity
      }
      ```
  - **CommunityActivityService**: コミュニティ固有のアクティビティ処理を実装するドメインサービス
    - 責務: Group Actorの管理、メンバーシップ処理、コミュニティ固有の配信制御
    - メソッド:
      ```go
      type CommunityActivityService interface {
          ProcessJoinRequest(actor Actor, community CommunityActor) error
          ProcessLeaveRequest(actor Actor, community CommunityActor) error
          ProcessInvitation(inviter Actor, invitee Actor, community CommunityActor) error
          PromoteMember(actor Actor, targetActor Actor, community CommunityActor, role CommunityRole) error
          DemoteMember(actor Actor, targetActor Actor, community CommunityActor) error
          DistributeToMembers(activity Activity, community CommunityActor) error
          FilterAudienceByTopic(audience []Actor, topic CommunityTopic) []Actor
          ValidateCommunityPermission(actor Actor, community CommunityActor, action string) error
          BuildCommunityContext() []interface{}
          TranslateWithAvionNamespace(activity Activity) Activity
      }
      ```
  - **FederationDeliveryPolicyService**: 配送ポリシー、リトライ戦略、サーキットブレーカー制御を決定するドメインサービス
    - 責務: ドメイン別リトライ戦略の決定、サーキットブレーカーの管理、配送優先度の判定
    - メソッド:
      ```go
      type FederationDeliveryPolicyService interface {
          DetermineRetryStrategy(attempt DeliveryAttempt, targetDomain string) RetryPolicy
          ManageCircuitBreaker(domain string, result DeliveryResult) CircuitBreakerState
          CalculateBackoffDelay(attemptCount int, baseDelay time.Duration) time.Duration
          ShouldRetryDelivery(failure DeliveryFailure, domain string) bool
          PrioritizeDeliveryQueue(tasks []FederationDelivery, constraints ResourceConstraints) []FederationDelivery
          OptimizeDeliveryBatching(tasks []FederationDelivery, targetDomain string) []DeliveryBatch
          CheckDomainHealth(domain string) DomainHealthStatus
          EstimateDeliveryTime(task FederationDelivery, currentLoad int) time.Time
          HandlePermanentFailure(task FederationDelivery, reason string) error
          UpdateDeliveryMetrics(domain string, metrics DeliveryMetrics) error
      }
      ```
  - **ActivityValidator**: 受信アクティビティのビジネスルール検証を実装するドメインサービス
    - 責務: アクティビティの妥当性検証、スパム判定、ブロックルールの適用
    - メソッド:
      ```go
      type ActivityValidator interface {
          ValidateIncomingActivity(activity Activity) error
          CheckActivitySpam(activity Activity) (bool, SpamScore)
          IsActorBlocked(actor Actor) bool
          ValidateActivitySemantics(activity Activity) error
          CheckRateLimits(actor Actor, activityType string) error
      }
      ```
  - **ActorResolutionService**: リモートActorの解決と管理を実装するドメインサービス
    - 責務: Actor情報の取得、WebFinger解決、Actor情報のキャッシュ戦略
    - メソッド:
      ```go
      type ActorResolutionService interface {
          ResolveActorFromURI(uri ActorURI) (Actor, error)
          ResolveWebFinger(resource string) (WebFingerResource, error)
          DetermineActorCacheDuration(actor Actor) time.Duration
          ValidateActorIntegrity(actor Actor) error
          MergeActorUpdates(existing Actor, updated Actor) Actor
      }
      ```
  - **FederationPolicyService**: 連合ポリシーを実装するドメインサービス
    - 責務: インスタンスレベルのポリシー適用、連合許可リストの管理、アクセス制御
    - メソッド:
      ```go
      type FederationPolicyService interface {
          IsInstanceAllowed(domain string) bool
          DetermineInstancePolicy(domain string) InstancePolicy
          ApplyFederationRules(activity Activity) error
          CheckInstanceReputation(domain string) ReputationScore
          HandlePolicyViolation(violation PolicyViolation) error
      }
      ```
  - **ContentModerationService**: コンテンツモデレーションを実装するドメインサービス
    - 責務: 通報処理、コンテンツフィルタリング、モデレーション判定
    - メソッド:
      ```go
      type ContentModerationService interface {
          ProcessContentReport(report ReportedContent) ModerationDecision
          FilterInappropriateContent(content ActivityContent) (bool, FilterReason)
          DetermineQuarantinePolicy(actor Actor, content ActivityContent) QuarantinePolicy
          NotifyModerators(report ReportedContent) error
          ApplyModerationAction(decision ModerationDecision) error
      }
      ```
  - **ActivityMigrationService**: アカウント移行処理を実装するドメインサービス
    - 責務: 移行の妥当性検証、フォロー関係の移行、移行通知の生成
    - メソッド:
      ```go
      type ActivityMigrationService interface {
          ValidateMigration(fromActor Actor, toActor Actor) error
          ProcessFollowerMigration(fromActor Actor, toActor Actor) error
          GenerateMoveActivity(fromActor Actor, toActor Actor) Activity
          VerifyMigrationClaim(actor Actor, moveTarget MoveTarget) error
          UpdateFollowingAfterMove(follower Actor, movedActor Actor, newActor Actor) error
      }
      ```
- **Repository Interfaces:**
  - RemoteActorRepository
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_remote_actor_repository.go -package=mocks
    ```
  - OutboxDeliveryTaskRepository
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_outbox_delivery_task_repository.go -package=mocks
    ```
  - RemoteObjectRepository
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_remote_object_repository.go -package=mocks
    ```
  - BlockedActorRepository
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_blocked_actor_repository.go -package=mocks
    ```
  - ReportedContentRepository
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_reported_content_repository.go -package=mocks
    ```

#### Use Case Layer (ユースケース層)
- **Command Use Cases (更新系):**
  - ReceiveInboxActivityCommandUseCase: Inbox受信処理（POSTリクエスト用）
  - ProcessOutboxDeliveryCommandUseCase: Outbox配送処理（イベントハンドラ用）
  - FetchRemoteActorCommandUseCase: リモートActor情報取得・保存（イベントハンドラ用）
  - CreateOutboxTaskCommandUseCase: Outboxタスク作成（イベントハンドラ用）
  - RetryDeliveryCommandUseCase: 配送リトライ処理（ワーカー用）
  - ProcessInboxBlockCommandUseCase: Blockアクティビティ受信処理
  - CreateOutboxBlockCommandUseCase: Blockアクティビティ送信処理
  - ProcessInboxUnblockCommandUseCase: Unblockアクティビティ受信処理
  - CreateOutboxUnblockCommandUseCase: Unblockアクティビティ送信処理
  - ProcessInboxFlagCommandUseCase: 通報受信処理
  - CreateOutboxFlagCommandUseCase: 通報送信処理
  - ProcessInboxMoveCommandUseCase: アカウント移行通知受信
  - CreateOutboxMoveCommandUseCase: アカウント移行通知送信
  - UpdateFollowingAfterMoveCommandUseCase: 移行後のフォロー更新
  - ProcessInboxQuestionCommandUseCase: 投票受信処理
  - ProcessInboxAnswerCommandUseCase: 投票回答受信処理
  - CreateOutboxAnswerCommandUseCase: 投票回答送信処理
  - RefreshRemoteActorCommandUseCase: リモートActor情報の定期更新
  - CleanupStaleActorsCommandUseCase: 古いActor情報のクリーンアップ
  - HandleTemporaryDeliveryFailureCommandUseCase: 一時的な配送失敗の処理
  - HandlePermanentDeliveryFailureCommandUseCase: 恒久的な配送失敗の処理
  - **他サービス連携用UseCase:**
    - ProcessDropCreatedCommandUseCase: Drop作成イベント処理（avion-drop連携）
    - ProcessDropDeletedCommandUseCase: Drop削除イベント処理（avion-drop連携）
    - ProcessReactionCreatedCommandUseCase: リアクション作成処理（avion-drop連携）
    - ProcessFollowCreatedCommandUseCase: フォロー作成処理（avion-user連携）
    - ProcessUserBlockedCommandUseCase: ユーザーブロック処理（avion-user連携）
    - CacheRemoteMediaCommandUseCase: リモートメディアキャッシュ（avion-media連携）
    - ProcessModerationReportCommandUseCase: モデレーション通報処理（avion-moderation連携）
    - UpdateGlobalTimelineCommandUseCase: グローバルタイムライン更新（avion-timeline連携）
  - **コミュニティ連合用UseCase:**
    - ProcessCommunityCreatedCommandUseCase: コミュニティ作成イベント処理（avion-community連携）
    - ProcessInboxJoinCommandUseCase: Joinアクティビティ受信処理
    - ProcessInboxLeaveCommandUseCase: Leaveアクティビティ受信処理
    - ProcessInboxInviteCommandUseCase: Inviteアクティビティ受信処理
    - ProcessInboxAddCommandUseCase: Addアクティビティ受信（モデレーター任命）
    - ProcessInboxRemoveCommandUseCase: Removeアクティビティ受信（モデレーター解任）
    - CreateOutboxJoinCommandUseCase: Joinアクティビティ送信処理
    - CreateOutboxLeaveCommandUseCase: Leaveアクティビティ送信処理
    - CreateOutboxInviteCommandUseCase: Inviteアクティビティ送信処理
    - ProcessCommunityDropCreatedCommandUseCase: コミュニティ投稿作成処理
    - ProcessCommunityEventCreatedCommandUseCase: コミュニティイベント作成処理
    - DistributeToCommunityMembersCommandUseCase: コミュニティメンバーへの配信
- **Query Use Cases (参照系):**
  - GetRemoteActorQueryUseCase: リモートActor情報取得（GETリクエスト用）
  - ResolveWebFingerQueryUseCase: WebFinger解決（GETリクエスト用）
  - GetLocalActorQueryUseCase: ローカルActor情報取得（GETリクエスト用）
  - GetOutboxQueryUseCase: Outbox情報取得（GETリクエスト用）
  - GetReportedContentQueryUseCase: 通報内容の取得
  - GetFeaturedCollectionQueryUseCase: 注目の投稿コレクション取得
  - GetFollowersCollectionQueryUseCase: フォロワーコレクション取得
  - GetFollowingCollectionQueryUseCase: フォローコレクション取得
  - GetDeliveryFailureReportQueryUseCase: 配送失敗レポート取得
  - GetCommunityActorQueryUseCase: コミュニティGroup Actor情報取得
  - GetCommunityMembersCollectionQueryUseCase: コミュニティメンバーコレクション取得
  - GetCommunityTopicsCollectionQueryUseCase: コミュニティトピックコレクション取得
- **Query Service Interfaces:**
  - RemoteActorQueryService: リモートActor情報参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_remote_actor_query_service.go -package=mocks
    ```
  - RemoteObjectQueryService: リモートオブジェクト参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_remote_object_query_service.go -package=mocks
    ```
  - WebFingerQueryService: WebFinger情報参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_webfinger_query_service.go -package=mocks
    ```
- **DTOs:**
  - InboxActivityDTO, OutboxDeliveryDTO, RemoteActorDTO, WebFingerResourceDTO等
- **External Service Interfaces:**
  - UserServiceClient: avion-authとの連携
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_user_service_client.go -package=mocks
    ```
  - MediaServiceClient: avion-mediaとの連携
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_media_service_client.go -package=mocks
    ```
  - DropServiceClient: avion-dropとの連携
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_drop_service_client.go -package=mocks
    ```
  - EventPublisher: Redis Pub/Subイベント発行
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_event_publisher.go -package=mocks
    ```
  - CommunityServiceClient: avion-communityとの連携
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_community_service_client.go -package=mocks
    ```

#### Infrastructure Layer (インフラストラクチャ層)

- **Repository Implementations (更新系):**
  - PostgreSQLRemoteActorRepository: RemoteActor永続化実装
    - マスター・スレーブ構成でのread/write分離対応
    - Connection pooling とトランザクション管理
    - Deadlock detection と自動リトライ
  - PostgreSQLOutboxDeliveryTaskRepository: OutboxDeliveryTask永続化実装
    - 配送タスクキューのatomic操作保証
    - Bulk insert/update最適化
    - Index最適化による高速検索
  - PostgreSQLRemoteObjectRepository: RemoteObject永続化実装
    - JSONB型を活用した効率的なActivityPub object格納
    - GIN indexによる高速検索対応
  - PostgreSQLBlockedActorRepository: ブロック情報永続化実装
  - PostgreSQLReportedContentRepository: 通報情報永続化実装

- **Query Service Implementations (参照系):**
  - PostgreSQLRemoteActorQueryService: RemoteActor参照専用実装
    - Read replica使用による負荷分散
    - Prepared statement活用
    - Connection pooling最適化
  - PostgreSQLRemoteObjectQueryService: RemoteObject参照専用実装
  - CachedRemoteActorQueryService: Redis使用のキャッシュ付き参照実装
    - LRU eviction policy適用
    - Cache warming戦略実装
    - TTL管理と自動更新
  - CachedWebFingerQueryService: Redis使用のWebFingerキャッシュ付き実装
  - PostgreSQLBlockedActorQueryService: ブロック情報参照実装
  - PostgreSQLReportedContentQueryService: 通報情報参照実装

- **External Service Implementations:**
  - GRPCUserServiceClient: avion-userサービス連携実装
    - Connection pooling とload balancing
    - Circuit breaker pattern適用
    - Retry policy with exponential backoff
    - Request/response logging
  - GRPCMediaServiceClient: avion-mediaサービス連携実装
  - GRPCDropServiceClient: avion-dropサービス連携実装
  - GRPCCommunityServiceClient: avion-communityサービス連携実装
    - Group Actor情報取得
    - コミュニティメンバーシップ管理
    - トピック/イベント情報連携
  - RedisEventPublisher: イベント発行実装
    - Pub/Sub channel management
    - Message serialization/deserialization
    - Event ordering 保証

- **Message Queue:**
  - RedisStreamOutboxQueue: Outbox配送キュー管理
    - Consumer group management
    - Dead letter queue handling
    - Message acknowledgment tracking
    - Stream trimming policy
  - RedisPubSubSubscriber: イベント購読
    - Channel subscription management
    - Connection recovery handling
    - Message deduplication

- **HTTP Clients:**
  - ActivityPubHTTPClient: ActivityPub通信実装
    - Connection pooling とkeep-alive
    - プラットフォーム別ヘッダー調整
    - Timeout configuration（connect, read, write）
    - User-Agent header管理
    - Content-Type negotiation
    - Response size limitation
    - SSL/TLS証明書検証
  - HTTPSignatureService: HTTP Signatures署名・検証実装
    - RSA-SHA256 signature algorithm
    - Signature header parsing/generation  
    - Key rotation support
    - Signature expiration validation
    
    **詳細実装仕様:**
    ```go
    // HTTP Signature実装詳細
    type HTTPSignatureConfig struct {
        Algorithm       string        // "rsa-sha256"
        Headers         []string      // ["(request-target)", "host", "date", "digest"]
        MaxAge          time.Duration // 300秒（署名有効期限）
        ClockSkew       time.Duration // 60秒（時刻ズレ許容範囲）
        DigestAlgorithm string        // "SHA-256"
    }
    
    // 署名生成プロセス
    func (s *HTTPSignatureService) Sign(req *http.Request, keyID string, privateKey *rsa.PrivateKey) error {
        // 1. Digest header生成（POSTリクエストの場合）
        if req.Body != nil {
            bodyBytes, _ := io.ReadAll(req.Body)
            req.Body = io.NopCloser(bytes.NewReader(bodyBytes))
            digest := sha256.Sum256(bodyBytes)
            req.Header.Set("Digest", fmt.Sprintf("SHA-256=%s", base64.StdEncoding.EncodeToString(digest[:])))
        }
        
        // 2. Date header設定
        req.Header.Set("Date", time.Now().UTC().Format(http.TimeFormat))
        
        // 3. Signature base string構築
        signatureBase := s.buildSignatureBase(req)
        
        // 4. RSA-SHA256署名
        signature := s.rsaSign(signatureBase, privateKey)
        
        // 5. Signature header構築
        req.Header.Set("Signature", s.formatSignatureHeader(keyID, signature))
        
        return nil
    }
    
    // 署名検証プロセス
    func (s *HTTPSignatureService) Verify(req *http.Request, publicKey *rsa.PublicKey) error {
        // 1. Signature header解析
        sig := s.parseSignatureHeader(req.Header.Get("Signature"))
        
        // 2. 署名期限チェック
        if s.isExpired(req.Header.Get("Date")) {
            return ErrSignatureExpired
        }
        
        // 3. Digest検証（POSTリクエストの場合）
        if req.Body != nil {
            if err := s.verifyDigest(req); err != nil {
                return err
            }
        }
        
        // 4. Signature base string再構築
        signatureBase := s.buildSignatureBase(req)
        
        // 5. RSA署名検証
        return s.rsaVerify(signatureBase, sig.Signature, publicKey)
    }
    ```
    
  - WebFingerClient: WebFinger解決実装
    **最適化戦略:**
    ```go
    type WebFingerOptimization struct {
        // キャッシュ戦略
        CacheConfig struct {
            TTL           time.Duration // 24時間
            NegativeTTL   time.Duration // 1時間（解決失敗のキャッシュ）
            MaxEntries    int          // 10000エントリー
        }
        
        // 並列解決
        ConcurrentResolve struct {
            MaxWorkers    int          // 10並列
            Timeout       time.Duration // 5秒/リクエスト
        }
        
        // バッチ処理
        BatchResolve struct {
            MaxBatchSize  int          // 100件
            BatchInterval time.Duration // 100ms
        }
        
        // フォールバック戦略
        FallbackStrategy struct {
            UseHTTP       bool         // HTTPSが失敗した場合
            UseCached     bool         // 期限切れキャッシュの利用
            UseDefault    bool         // デフォルト推測
        }
    }
    
    func (c *WebFingerClient) ResolveOptimized(acct string) (*WebFingerResource, error) {
        // 1. キャッシュチェック
        if cached := c.cache.Get(acct); cached != nil {
            return cached, nil
        }
        
        // 2. バッチキューに追加（複数リクエストをまとめる）
        if c.batchEnabled {
            return c.batchResolve(acct)
        }
        
        // 3. 通常解決
        resource, err := c.resolve(acct)
        if err != nil {
            // 4. フォールバック戦略適用
            if fallback := c.tryFallback(acct, err); fallback != nil {
                return fallback, nil
            }
            // 5. ネガティブキャッシュ
            c.cache.SetNegative(acct, c.config.NegativeTTL)
            return nil, err
        }
        
        // 6. 成功キャッシュ
        c.cache.Set(acct, resource, c.config.TTL)
        return resource, nil
    }
    ```
    
    **プラットフォーム別WebFinger実装:**
    詳細は[Federation Strategy](./federation-strategy.md#webfinger)を参照
    
  - DeliveryRetryStrategy: 連合配信のリトライ戦略
    **実装詳細:**
    ```go
    type DeliveryRetryConfig struct {
        // 基本設定
        MaxAttempts     int           // 最大10回
        InitialDelay    time.Duration // 初回1分
        MaxDelay        time.Duration // 最大24時間
        BackoffFactor   float64       // 2.0（指数バックオフ）
        
        // サーキットブレーカー
        CircuitBreaker struct {
            ErrorThreshold   float64      // 50%エラー率でOpen
            VolumeThreshold  int          // 最小10リクエスト
            SleepWindow      time.Duration // 5分間のOpen状態
            BucketSize       time.Duration // 10秒のバケット
        }
        
        // 優先度管理
        PriorityConfig struct {
            HighPriority    []string     // 重要なドメインリスト
            LowPriority     []string     // 低優先度ドメイン
            RateLimits      map[string]int // ドメイン別レート制限
        }
        
        // エラー別戦略
        ErrorStrategies map[int]RetryStrategy {
            400: NoRetry,           // Bad Request - リトライ不要
            401: NoRetry,           // Unauthorized - リトライ不要
            403: NoRetry,           // Forbidden - リトライ不要
            404: DelayedRetry,      // Not Found - 遅延リトライ
            429: ExponentialBackoff, // Too Many Requests - 指数バックオフ
            500: ExponentialBackoff, // Internal Server Error
            502: ExponentialBackoff, // Bad Gateway
            503: ExponentialBackoff, // Service Unavailable
            504: ExponentialBackoff, // Gateway Timeout
        }
    }
    
    func (r *RetryManager) ShouldRetry(attempt int, lastError error) (bool, time.Duration) {
        // 1. 最大試行回数チェック
        if attempt >= r.config.MaxAttempts {
            return false, 0
        }
        
        // 2. エラータイプ別戦略
        if httpErr, ok := lastError.(*HTTPError); ok {
            strategy := r.config.ErrorStrategies[httpErr.StatusCode]
            if strategy == NoRetry {
                return false, 0
            }
        }
        
        // 3. サーキットブレーカー状態確認
        if r.circuitBreaker.IsOpen() {
            return false, r.config.CircuitBreaker.SleepWindow
        }
        
        // 4. 次回リトライまでの待機時間計算
        delay := r.calculateDelay(attempt)
        
        return true, delay
    }
    ```
    
    **プラットフォーム別リトライ戦略:**
    詳細は[Federation Strategy](./federation-strategy.md#retry-strategy)を参照

- **Time Service:**
  - CtxTimeService: github.com/newmo-oss/ctxtime使用
    - テスト可能な時刻取得
    - Timezone handling
    - Time formatting utilities

- **Logging Infrastructure:**
  - StructuredLogger: slog使用の構造化ログ
    - JSON format output
    - Trace correlation
    - Log level management
    - Sensitive information masking

- **Monitoring Infrastructure:**
  - PrometheusMetrics: メトリクス収集
    - Request counters and histograms
    - Error rate tracking
    - Queue depth monitoring
    - Circuit breaker status
  - OpenTelemetryTracer: 分散トレーシング
    - Span creation and propagation
    - Attribute management
    - Cross-service tracing

#### Handler Layer (ハンドラー層)

- **HTTP Command Handlers (更新系):**
  - InboxCommandHandler: ユーザー別Inboxエンドポイント（POST /users/{username}/inbox）
    - HTTP Signature検証
    - Request body validation
    - ActivityPub activity parsing
    - Rate limiting適用
    - Error response handling
  - SharedInboxCommandHandler: 共有Inboxエンドポイント（POST /inbox）
    - Bulk activity processing
    - Domain-level authentication
    - Load balancing対応
    - Activity deduplication

- **HTTP Query Handlers (参照系):**
  - WebFingerQueryHandler: WebFingerエンドポイント（GET /.well-known/webfinger）
    - Resource parameter validation
    - Cache-Control header management
    - CORS header設定
    - Content-Type negotiation
  - ActorQueryHandler: Actorエンドポイント（GET /users/{username}）
    - Accept header validation（application/activity+json）
    - Actor information formatting
    - Privacy setting respect
    - ETag/Last-Modified対応
  - OutboxQueryHandler: Outboxエンドポイント（GET /users/{username}/outbox）
    - Collection pagination
    - Activity filtering
    - Privacy control
  - FollowersCollectionQueryHandler: フォロワーコレクション（GET /users/{username}/followers）
  - FollowingCollectionQueryHandler: フォローコレクション（GET /users/{username}/following）
  - FeaturedCollectionQueryHandler: 注目投稿コレクション（GET /users/{username}/featured）

- **gRPC Handlers:**
  - ActivityPubServiceHandler: 内部サービス連携gRPC API
    - GetRemoteActor: リモートActor情報取得
    - GetRemoteObject: リモートオブジェクト取得
    - GetDeliveryStats: 配送統計取得
    - ListBlockedActors: ブロック済みActor一覧
    - GetReportedContent: 通報コンテンツ取得

- **Event Handlers (Redis Pub/Sub):**
  - DropCreatedEventHandler: Drop作成イベント処理
    - Visibility確認（public/unlisted のみ連合）
    - Create activity生成
    - Outbox delivery task作成
  - FollowEventHandler: フォローイベント処理
    - Follow activity生成
    - フォローリクエスト配送
  - ReactionEventHandler: リアクションイベント処理
    - Like/Announce activity生成
    - 対象確認とactivity配送
  - BlockEventHandler: ブロックイベント処理
    - Block activity生成
    - 既存配送タスクの停止
  - ReportEventHandler: 通報イベント処理
    - Flag activity生成
    - モデレーター通知
  - AccountMoveEventHandler: アカウント移行処理
    - Move activity生成
    - フォロー関係移行
  - CommunityCreatedEventHandler: コミュニティ作成イベント処理
    - Group Actor生成
    - WebFingerリソース登録
    - コミュニティエンドポイント設定
  - CommunityMemberJoinedEventHandler: メンバー参加イベント処理
    - Accept activity生成
    - メンバーコレクション更新
  - CommunityDropCreatedEventHandler: コミュニティ投稿イベント処理
    - Audience設定（コミュニティメンバー）
    - コミュニティコンテキスト付与
    - 最適化配信処理

- **Background Workers:**
  - OutboxDeliveryWorker: 配送ワーカー
    - Redis Stream consumer group参加
    - Concurrent delivery processing
    - Retry/circuit breaker logic
    - Delivery metrics recording
  - RemoteActorFetchWorker: リモートActor取得ワーカー
    - Activity signature検証時の公開鍵取得
    - Actor information refresh
    - Error handling and retry
  - ActorRefreshWorker: Actor情報定期更新ワーカー
    - Scheduled actor refresh（6時間間隔）
    - Stale actor detection
    - Batch processing optimization
  - StaleActorCleanupWorker: 古いActor情報クリーンアップワーカー
    - 90日以上アクセスなしのactor削除
    - Cache eviction
  - DeliveryFailureHandlerWorker: 配送失敗処理ワーカー
    - Dead letter queue processing
    - Circuit breaker state management
    - Failure analysis and alerting

- **Middleware:**
  - AuthenticationMiddleware: 認証処理
    - HTTP Signature validation
    - Bearer token validation（内部API用）
  - RateLimitingMiddleware: レート制限
    - IP-based rate limiting
    - Actor-based rate limiting
  - RequestLoggingMiddleware: リクエストログ
    - Structured request/response logging
    - Performance metrics
  - ErrorHandlingMiddleware: エラーハンドリング
    - ActivityPub error format
    - HTTP status code mapping
    - Error response standardization

> **注意:** エラーコードは[共通エラーコード標準](../common/errors/error-codes.md)に準拠します。このサービスではプレフィックス `APB` を使用します。

### 5.2. 主要コンポーネント

- **主要コンポーネント:**
    - `avion-activitypub (Go, Kubernetes Deployment)`: 本サービス。HTTPサーバー、Redis Pub/Sub購読者、非同期Outboxワーカ (Redis Stream Consumer)。
    - `avion-gateway (Go)`: HTTPリクエストのルーティング元。
    - `avion-user (Go)`: Actor情報生成、フォロー関係連携、HTTP Signatures鍵管理・署名/検証API提供 (gRPC)。
    - `avion-post (Go)`: Drop情報連携 (gRPC or イベント経由)。
    - `avion-media (Go)`: リモートメディアキャッシュ依頼 (gRPC)。
    - `PostgreSQL`: リモートActor/Object情報、DLQ情報などを永続化。
    - `Redis`: ローカルイベント購読 (Pub/Sub)、Outbox配送キュー (Stream)、リモート情報キャッシュ、公開鍵キャッシュ。
    - `Observability Stack`: メトリクス、トレース、ログ収集。
    - `Other Terminal`: 通信相手のActivityPubサーバー。
- **構成図:** (アーキテクチャ概要図を参照)
    - [Avion アーキテクチャ概要](../common/architecture.md)
- **ポイント:**
    - HTTPエンドポイントで外部サーバーと通信。
    - 内部サービスとはgRPCおよびRedis Pub/Sub/Streamで連携。
    - Inbox処理は同期的に受け付け、実際の処理は非同期で行う場合がある。
    - Outbox処理はRedis StreamとConsumer Groupを用いた非同期処理。
    - HTTP Signaturesの鍵管理・操作は `avion-user` に委任。
    - ステートレス設計 (配送キューの状態などはRedis/Postgresで管理)。

## データベースマイグレーション

このサービスでは、[共通マイグレーション戦略](../common/database-migration-strategy.md)に従って、Gooseを使用したマイグレーション管理を行います。

### マイグレーション戦略

- **ツール**: Goose v3
- **ディレクトリ**: `./migrations/`
- **命名規則**: `[sequence_number]_[description].sql`
- **実行方法**: `make migrate-up` / `make migrate-down`

### avion-activitypub固有の考慮事項

- **フェデレーション整合性**: 外部サーバーとの連携データの整合性を保証
- **配送キュー保護**: 未配送のActivityが消失しないよう配送キューデータを保護
- **HTTP署名鍵**: 署名鍵の移行時は外部サーバーとの認証に影響しないよう注意
- **ActivityPubオブジェクト**: JSONフォーマットのActivity/Objectデータの完全性を維持
- **配送再試行**: 移行中の配送失敗に対する適切な再試行メカニズム

### 標準テンプレート参照

マイグレーションファイル作成時は[マイグレーション設定テンプレート](../templates/migration-setup-template.md)を参照してください。

## 7. コミュニティ連合の互換性制限

### プラットフォーム別互換性状況

Avionのコミュニティ機能（Group Actor）は、ActivityPub標準に完全準拠していますが、各プラットフォームの実装状況により互換性に制限があります。

#### Mastodonとの互換性: ❌ **非互換**
- **問題**: MastodonはGroup Actor型を未実装（Person型のみサポート）
- **影響**:
  - AvionコミュニティをMastodonからフォロー不可
  - Join/Leave/Invite等のGroup関連アクティビティは無視される
  - コミュニティ投稿の直接配信不可
- **回避策**:
  ```go
  // Person Actorへのフォールバック実装
  func (s *CommunityActivityService) FallbackToPersonActor(community CommunityActor) Actor {
      return Actor{
          Type: "Person", // Group未対応プラットフォーム向け
          Name: fmt.Sprintf("%s (Community)", community.Name),
          PreferredUsername: community.Handle,
          Summary: fmt.Sprintf("Community: %s", community.Description),
      }
  }
  ```

#### Misskeyとの互換性: ⚠️ **部分的互換**
- **問題**: Misskeyは独自のチャンネル実装（標準Group型ではない）
- **影響**:
  - コミュニティの完全な相互運用不可
  - MisskeyチャンネルとAvionコミュニティの統合不可
- **部分対応**:
  ```go
  // Misskey拡張フィールド対応
  func (s *ActivityBuilder) AddMisskeyExtensions(activity Activity) Activity {
      activity.Extensions["_misskey_community"] = activity.CommunityID
      activity.Extensions["_misskey_topic"] = activity.TopicID
      return activity
  }
  ```

#### Lemmy/PeerTubeとの互換性: ✅ **完全互換**
- **状況**: Group Actor型を正式サポート
- **可能な機能**:
  - コミュニティの相互フォロー
  - Join/Leaveアクティビティの正常処理
  - メンバーシップ管理の完全連携
  - コミュニティ投稿の直接配信

### 配信戦略の実装

```go
// プラットフォーム別配信戦略
func (s *FederationDeliveryService) DetermineDeliveryStrategy(targetDomain string) DeliveryStrategy {
    platform := s.detectPlatform(targetDomain)
    
    switch platform {
    case "mastodon":
        // Group未対応のためPerson Actorにフォールバック
        return PersonActorFallbackStrategy{
            ConvertGroupToPerson: true,
            IgnoreGroupActivities: true,
        }
    case "misskey":
        // 独自拡張フィールドを追加
        return MisskeyExtensionStrategy{
            AddCustomFields: true,
            UseChannelMapping: false, // チャンネル統合は不可
        }
    case "lemmy", "peertube":
        // 完全互換のため標準Group Actorで配信
        return FullGroupActorStrategy{
            UseStandardGroup: true,
            EnableAllFeatures: true,
        }
    default:
        // ActivityPub標準に準拠した配信
        return StandardActivityPubStrategy{}
    }
}
```

### 現実的な制限事項

1. **Mastodonユーザー向け**:
   - Avionコミュニティは「通常のユーザー」として表示される
   - コミュニティ固有の機能（トピック、イベント等）は利用不可
   - メンバーシップ管理はローカルのみ

2. **Misskeyユーザー向け**:
   - チャンネルとコミュニティの相互変換不可
   - カスタム絵文字・リアクションの部分的サポートのみ

3. **将来的な改善可能性**:
   - MastodonがGroup型を実装した場合、完全互換が可能に
   - FEP（Fediverse Enhancement Proposals）によるGroup標準化の進展を追跡

> **注意**: これらの制限はActivityPub標準の問題ではなく、各プラットフォームの実装状況によるものです。AvionはActivityPub標準に完全準拠しています。

### 詳細な配信戦略

各プラットフォームとの詳細な相互運用性戦略については、[ActivityPub Federation Strategy](./federation-strategy.md)を参照してください。

このドキュメントでは以下をカバーしています：
- プラットフォーム検出ロジック（NodeInfo、WebFinger、Actorパターン分析）
- ユースケース別配信戦略（投稿、コミュニティ、リアクション、メディア）
- セキュリティ・認証戦略（HTTP Signatures、Authorized Fetch）
- エラーハンドリングとフォールバック
- 監視・メトリクス収集

## 8. Use Cases / Key Flows (主な使い方・処理の流れ)

- **フロー 1: InboxへのActivity受信 (例: Follow) (Command)**
    1. Other Terminal → Gateway: `POST /users/alice/inbox` (Activity: Follow, Signatureヘッダー)
    2. Gateway → InboxCommandHandler: `POST /users/alice/inbox` (HTTP転送)
    3. InboxCommandHandler: ReceiveInboxActivityCommandUseCaseを呼び出し
    4. ReceiveInboxActivityCommandUseCase: SignatureVerificationService (Domain Service) でHTTP Signature検証
    5. SignatureVerificationService: CachedRemoteActorQueryServiceから公開鍵取得
    6. (検証成功) ReceiveInboxActivityCommandUseCase: ActivityValidator (Domain Service) でアクティビティのビジネスルール検証
    7. (検証成功) ReceiveInboxActivityCommandUseCase: RemoteActor Aggregateを更新または作成
    8. ReceiveInboxActivityCommandUseCase: RemoteActorRepositoryを通じてRemoteActorを永続化
    9. ReceiveInboxActivityCommandUseCase: ActivityReceived Domain Eventを発行
    10. ReceiveInboxActivityCommandUseCase: EventPublisherを通じて `ap_follow_received` イベントを発行
    11. InboxCommandHandler → Gateway: `202 Accepted`
    12. (非同期) `avion-auth` がイベントを購読し、フォロー承認処理へ。

- **フロー 1.1: プラットフォーム別Activity受信 (Command)**
    1. InboxCommandHandler: PlatformDetectionServiceで送信元プラットフォームを検出
    2. PlatformDetectionService: NodeInfoまたはActorパターンからプラットフォームを特定
    3. ActivityValidator: プラットフォーム固有のバリデーションルールを適用
    4. (例: Misskey) カスタム絵文字リアクションの解釈
    5. (例: Lemmy) Group Actorからのアクティビティ処理
- **フロー 2: ローカルDrop作成イベント受信 & Outbox処理 (Command)**
    1. DropCreatedEventHandler: Redis Pub/Subチャネル `drop_created` からイベント受信
    2. DropCreatedEventHandler: CreateOutboxTaskCommandUseCaseを呼び出し
    3. CreateOutboxTaskCommandUseCase: visibilityが連合可能か確認
    4. CreateOutboxTaskCommandUseCase: UserServiceClientでリモートフォロワーリスト取得
    5. CreateOutboxTaskCommandUseCase: ActivityBuilder (Domain Service) で `Create(Note)` アクティビティを生成
    6. CreateOutboxTaskCommandUseCase: RemoteActorQueryServiceから各フォロワーのInbox URL取得
    7. CreateOutboxTaskCommandUseCase: PlatformDetectionServiceで各フォロワーのプラットフォームを検出
    8. CreateOutboxTaskCommandUseCase: PlatformAdaptationServiceでプラットフォーム別にActivityを最適化
    9. CreateOutboxTaskCommandUseCase: OutboxDeliveryTask Aggregateを生成（プラットフォーム情報付き）
    10. CreateOutboxTaskCommandUseCase: OutboxDeliveryTaskRepositoryを通じてタスクをキューに追加
- **フロー 3: Outbox配送ワーカ (Command)**
    1. OutboxDeliveryWorker: Redis Stream `outbox_delivery_queue` から配送タスクを取得
    2. OutboxDeliveryWorker: ProcessOutboxDeliveryCommandUseCaseを呼び出し
    3. ProcessOutboxDeliveryCommandUseCase: OutboxDeliveryTaskRepositoryからTask Aggregate取得
    4. ProcessOutboxDeliveryCommandUseCase: DeliveryPolicy (Domain Service) で配送戦略を決定
    5. ProcessOutboxDeliveryCommandUseCase: CircuitBreakerStateを確認（ターゲットドメインごと）
    6. ProcessOutboxDeliveryCommandUseCase: UserServiceClientでHTTP署名を依頼
    7. ProcessOutboxDeliveryCommandUseCase: ActivityPubHTTPClientでActivityを送信
    8. (成功時) ProcessOutboxDeliveryCommandUseCase: DeliveryStatusを'delivered'に更新、DeliverySucceeded Domain Event発行
    9. (失敗時) ProcessOutboxDeliveryCommandUseCase: DeliveryPolicyに基づきリトライ判断、DeliveryFailed Domain Event発行
    10. (サーキットブレーカー発動時) CircuitBreakerStateChanged Domain Event発行
    11. OutboxDeliveryWorker: タスクをACK

- **フロー 3.1: コミュニティ活動のプラットフォーム別配送 (Command)**
    1. CommunityCreatedEventHandler: `community_created` イベントを受信
    2. PlatformDetectionService: 各フォロワーのプラットフォームを検出
    3. プラットフォーム別処理:
       - Mastodon: Person Actorへのフォールバック
       - Misskey: カスタム名前空間で部分対応
       - Lemmy/PeerTube: 完全なGroup Actor配信
    4. 配送タスク作成とキューイング
- **フロー 4: WebFinger解決 (Query)**
    1. Client → WebFingerQueryHandler: `GET /.well-known/webfinger?resource=acct:alice@example.com`
    2. WebFingerQueryHandler: ResolveWebFingerQueryUseCaseを呼び出し
    3. ResolveWebFingerQueryUseCase: CachedWebFingerQueryServiceからWebFingerResourceDTO取得を試行
    4. (キャッシュヒット) WebFingerResourceDTOを返却
    5. (キャッシュミス) UserServiceClientでローカルユーザー情報取得
    6. ResolveWebFingerQueryUseCase: WebFingerResource Value Objectを生成
    7. WebFingerQueryHandler → Client: WebFingerレスポンスを返却

## 8. Endpoints (API)

- **HTTP Endpoints:**
    - **Query Operations (参照系):**
        - `GET /.well-known/webfinger?resource=acct:{username}@{domain}` // WebFinger解決
        - `GET /users/{username}` (Accept: application/activity+json) // Actor情報取得
        - `GET /users/{username}/outbox` // Outbox取得（読み取り専用、実装優先度低）
        - `GET /users/{username}/followers` // フォロワーコレクション取得
        - `GET /users/{username}/following` // フォローコレクション取得
        - `GET /users/{username}/featured` // 注目の投稿コレクション取得
    - `GET /communities/{communityname}` (Accept: application/activity+json) // コミュニティGroup Actor情報取得
    - `GET /communities/{communityname}/members` // コミュニティメンバーコレクション取得
    - `GET /communities/{communityname}/topics` // コミュニティトピックコレクション取得
    - `GET /communities/{communityname}/outbox` // コミュニティOutbox取得
    - **Command Operations (更新系):**
        - `POST /inbox` // 共有Inboxへのアクティビティ送信
        - `POST /users/{username}/inbox` // ユーザー別Inboxへのアクティビティ送信
        - `POST /communities/{communityname}/inbox` // コミュニティInboxへのアクティビティ送信
- **gRPC Services (`avion.ActivityPubService`):** (内部連携用)
    - **Query Operations (参照系):**
        - `GetRemoteActor(GetRemoteActorRequest) returns (GetRemoteActorResponse)` // GET相当
        - `GetRemoteObject(GetRemoteObjectRequest) returns (GetRemoteObjectResponse)` // GET相当
        - `GetBlockedActors(GetBlockedActorsRequest) returns (GetBlockedActorsResponse)` // ブロック中のActor一覧
        - `GetReportedContent(GetReportedContentRequest) returns (GetReportedContentResponse)` // 通報コンテンツ一覧
        - `GetDeliveryStats(GetDeliveryStatsRequest) returns (GetDeliveryStatsResponse)` // 配送統計情報
    - **Command Operations (更新系):**
        - `FetchRemoteActor(FetchRemoteActorRequest) returns (FetchRemoteActorResponse)` // POST相当
- Proto定義は別途管理する。

## 9. Data Design (データ)

### 8.1. Domain Model (ドメインモデル)

#### Aggregates (集約)

##### RemoteActor (リモートアクター集約)
- **責務:** リモートActorの情報と状態を管理する集約
- **集約ルート:** RemoteActor
- **構成要素:**
  - RemoteActorID (Value Object): リモートActorの一意識別子
  - ActorURI (Value Object): ActivityPub Actor URI
  - ActorProfile (Value Object): プロフィール情報（名前、説明、アイコンURL等）
  - PublicKey (Value Object): HTTP Signatures用の公開鍵
  - InboxURL (Value Object): Actor個別のInbox URL
  - SharedInboxURL (Value Object): 共有Inbox URL（Optional）
  - LastFetchedAt (Value Object): 最終取得日時

##### OutboxDeliveryTask (Outbox配送タスク集約)
- **責務:** Outbox配送タスクの状態と配送履歴を管理する集約
- **集約ルート:** OutboxDeliveryTask
- **構成要素:**
  - DeliveryTaskID (Value Object): 配送タスクの一意識別子
  - Activity (Entity): 配送するActivityPubアクティビティ
    - ActivityID (Value Object): アクティビティID
    - ActivityType (Value Object): アクティビティタイプ（Create, Follow等）
    - ActivityContent (Value Object): アクティビティの内容（JSON-LD）
  - TargetInboxURL (Value Object): 配送先InboxのURL
  - DeliveryStatus (Value Object): 配送状態（pending, delivering, delivered, failed）
  - RetryCount (Value Object): リトライ回数
  - DeliveryAttempts (Entity Collection): 配送試行履歴
    - AttemptedAt (Value Object): 試行日時
    - StatusCode (Value Object): HTTPステータスコード
    - ErrorMessage (Value Object): エラーメッセージ

#### Entities (エンティティ)

##### RemoteObject (リモートオブジェクト)
- **責務:** リモートのActivityPubオブジェクト（Note等）を表現
- **所属集約:** なし（独立したエンティティ）
- **属性:**
  - RemoteObjectID (Value Object): オブジェクトの一意識別子
  - ObjectURI (Value Object): ActivityPub Object URI
  - ObjectType (Value Object): オブジェクトタイプ（Note, Image等）
  - AuthorActorID (Value Object): 作成者のActor ID
  - Content (Value Object): オブジェクトの内容
  - PublishedAt (Value Object): 公開日時
  - LastUpdatedAt (Value Object): 最終更新日時

#### Value Objects (値オブジェクト)

##### ActivityPubSignature (HTTP Signature情報)
- **責務:** HTTP Signaturesの署名情報を表現
- **属性:**
  - KeyID: 署名に使用された鍵のID
  - Algorithm: 署名アルゴリズム
  - Headers: 署名対象のヘッダー
  - Signature: 署名値

##### WebFingerResource (WebFingerリソース)
- **責務:** WebFingerのリソース情報を表現
- **属性:**
  - Subject: リソースの主体（acct:user@domain）
  - Links: 関連リンクのリスト
  - Aliases: エイリアスのリスト

##### RetryPolicy (リトライポリシー)
- **責務:** 配送リトライの戦略を表現
- **属性:**
  - MaxRetries: 最大リトライ回数
  - InitialDelay: 初回リトライまでの遅延
  - MaxDelay: 最大遅延時間
  - BackoffMultiplier: バックオフ倍率
- **不変性:** 完全に不変

##### CircuitBreakerState (サーキットブレーカー状態)
- **責務:** ドメインごとのサーキットブレーカー状態を表現
- **属性:**
  - State: CLOSED（正常）、OPEN（遮断）、HALF_OPEN（半開）
  - FailureCount: 連続失敗回数
  - LastFailureTime: 最終失敗時刻
  - NextRetryTime: 次回リトライ可能時刻
- **不変性:** 完全に不変

#### Domain Services (ドメインサービス)

##### DeliveryPolicy
- **責務:** 配送ポリシーとリトライ戦略を決定
- **主要メソッド:**
  - ShouldRetry(attempt: DeliveryAttempt, policy: RetryPolicy): bool
  - CalculateNextRetryTime(attempt: DeliveryAttempt, policy: RetryPolicy): Time
  - DetermineCircuitBreakerState(domain: string, failures: []DeliveryAttempt): CircuitBreakerState
  - CanDeliver(domain: string, state: CircuitBreakerState): bool

##### ActivityValidator
- **責務:** 受信アクティビティのビジネスルール検証
- **主要メソッド:**
  - ValidateActivity(activity: ActivityContent, actorURI: ActorURI): ValidationResult
  - ValidateFollowActivity(follow: FollowActivity): ValidationResult
  - ValidateCreateActivity(create: CreateActivity): ValidationResult
  - CheckBlockList(actorDomain: string): bool

### 8.2. Infrastructure Layer (インフラストラクチャ層)

- **PostgreSQL:**
    - `remote_actors` table: RemoteActor集約の永続化
    - `remote_objects` table: RemoteObjectエンティティの永続化
    - `outbox_delivery_tasks` table: OutboxDeliveryTask集約の永続化
    - `delivery_attempts` table: 配送試行履歴の永続化
    
    **データベース最適化戦略:**
    
    #### JSONB インデックス戦略
    ```sql
    -- remote_objects テーブルのJSONB最適化
    CREATE TABLE remote_objects (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        object_uri TEXT NOT NULL UNIQUE,
        object_type TEXT NOT NULL,
        object_data JSONB NOT NULL,
        actor_uri TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        
        -- GINインデックスによるJSONB検索最適化
        CONSTRAINT valid_object_data CHECK (jsonb_typeof(object_data) = 'object')
    );
    
    -- 汎用JSONBインデックス（全フィールド検索可能）
    CREATE INDEX idx_remote_objects_data_gin ON remote_objects USING GIN (object_data);
    
    -- 特定フィールドの最適化インデックス
    CREATE INDEX idx_remote_objects_type ON remote_objects ((object_data->>'type'));
    CREATE INDEX idx_remote_objects_published ON remote_objects ((object_data->>'published'));
    CREATE INDEX idx_remote_objects_in_reply_to ON remote_objects ((object_data->>'inReplyTo')) 
        WHERE object_data->>'inReplyTo' IS NOT NULL;
    CREATE INDEX idx_remote_objects_attributed_to ON remote_objects ((object_data->>'attributedTo'));
    
    -- 複合インデックス（頻繁なクエリパターン用）
    CREATE INDEX idx_remote_objects_actor_type ON remote_objects (actor_uri, object_type);
    CREATE INDEX idx_remote_objects_type_created ON remote_objects (object_type, created_at DESC);
    
    -- パーシャルインデックス（特定条件の高速化）
    CREATE INDEX idx_remote_objects_recent_notes ON remote_objects (created_at DESC)
        WHERE object_type = 'Note' AND created_at > NOW() - INTERVAL '7 days';
    ```
    
    #### パーティショニング計画
    ```sql
    -- 時系列データのパーティショニング（月単位）
    CREATE TABLE outbox_delivery_tasks (
        id UUID NOT NULL,
        activity_id TEXT NOT NULL,
        target_inbox TEXT NOT NULL,
        activity_data JSONB NOT NULL,
        status TEXT NOT NULL,
        attempt_count INT NOT NULL DEFAULT 0,
        next_retry_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    ) PARTITION BY RANGE (created_at);
    
    -- パーティション自動作成関数
    CREATE OR REPLACE FUNCTION create_monthly_partitions()
    RETURNS void AS $$
    DECLARE
        start_date date;
        end_date date;
        partition_name text;
    BEGIN
        -- 3ヶ月先まで自動作成
        FOR i IN 0..3 LOOP
            start_date := date_trunc('month', CURRENT_DATE + (i || ' months')::interval);
            end_date := start_date + '1 month'::interval;
            partition_name := 'outbox_delivery_tasks_' || to_char(start_date, 'YYYY_MM');
            
            -- パーティションが存在しない場合のみ作成
            IF NOT EXISTS (
                SELECT 1 FROM pg_class WHERE relname = partition_name
            ) THEN
                EXECUTE format(
                    'CREATE TABLE %I PARTITION OF outbox_delivery_tasks 
                    FOR VALUES FROM (%L) TO (%L)',
                    partition_name, start_date, end_date
                );
                
                -- パーティション固有のインデックス
                EXECUTE format(
                    'CREATE INDEX idx_%I_status_retry ON %I (status, next_retry_at) 
                    WHERE status IN (''pending'', ''retry'')',
                    partition_name, partition_name
                );
            END IF;
        END LOOP;
    END;
    $$ LANGUAGE plpgsql;
    
    -- 月次cronジョブでパーティション作成
    SELECT cron.schedule('create-partitions', '0 0 1 * *', 'SELECT create_monthly_partitions()');
    ```
    
    #### アーカイブ戦略
    ```sql
    -- アーカイブテーブル（コールドストレージ）
    CREATE TABLE archived_remote_objects (
        LIKE remote_objects INCLUDING ALL
    ) TABLESPACE archive_storage;
    
    -- アーカイブ関数
    CREATE OR REPLACE FUNCTION archive_old_remote_objects()
    RETURNS void AS $$
    BEGIN
        -- 90日以上前のデータをアーカイブ
        WITH moved AS (
            DELETE FROM remote_objects
            WHERE created_at < NOW() - INTERVAL '90 days'
                AND NOT EXISTS (
                    -- アクティブな参照がないことを確認
                    SELECT 1 FROM active_references ar
                    WHERE ar.object_id = remote_objects.id
                )
            RETURNING *
        )
        INSERT INTO archived_remote_objects
        SELECT * FROM moved;
        
        -- 統計情報更新
        ANALYZE remote_objects;
        ANALYZE archived_remote_objects;
    END;
    $$ LANGUAGE plpgsql;
    
    -- 週次アーカイブジョブ
    SELECT cron.schedule('archive-remote-objects', '0 2 * * 0', 'SELECT archive_old_remote_objects()');
    
    -- アーカイブデータの圧縮
    ALTER TABLE archived_remote_objects SET (
        autovacuum_enabled = false,
        toast_compression = pglz
    );
    
    -- パーティション削除戦略（6ヶ月以上前）
    CREATE OR REPLACE FUNCTION drop_old_partitions()
    RETURNS void AS $$
    DECLARE
        partition_name text;
    BEGIN
        FOR partition_name IN
            SELECT tablename
            FROM pg_tables
            WHERE tablename LIKE 'outbox_delivery_tasks_%'
                AND tablename < 'outbox_delivery_tasks_' || 
                    to_char(CURRENT_DATE - INTERVAL '6 months', 'YYYY_MM')
        LOOP
            -- アーカイブ確認後削除
            EXECUTE format('DROP TABLE IF EXISTS %I', partition_name);
            RAISE NOTICE 'Dropped partition: %', partition_name;
        END LOOP;
    END;
    $$ LANGUAGE plpgsql;
    ```
    
    #### クエリ最適化のベストプラクティス
    ```sql
    -- 効率的なJSONBクエリ例
    
    -- 1. 演算子の使用（インデックス活用）
    SELECT * FROM remote_objects
    WHERE object_data @> '{"type": "Note"}'::jsonb
        AND object_data @> '{"attributedTo": "https://example.com/users/alice"}'::jsonb;
    
    -- 2. パス演算子（特定フィールドインデックス活用）
    SELECT * FROM remote_objects
    WHERE object_data->>'type' = 'Note'
        AND created_at > NOW() - INTERVAL '24 hours'
    ORDER BY created_at DESC
    LIMIT 50;
    
    -- 3. EXISTS句による効率的な存在確認
    SELECT * FROM remote_actors ra
    WHERE EXISTS (
        SELECT 1 FROM remote_objects ro
        WHERE ro.actor_uri = ra.actor_uri
            AND ro.object_type = 'Note'
            AND ro.created_at > NOW() - INTERVAL '7 days'
    );
    
    -- 4. CTEによる複雑クエリの最適化
    WITH recent_activities AS (
        SELECT actor_uri, COUNT(*) as activity_count
        FROM remote_objects
        WHERE created_at > NOW() - INTERVAL '24 hours'
        GROUP BY actor_uri
        HAVING COUNT(*) > 10
    )
    SELECT ra.*, ra_stats.activity_count
    FROM remote_actors ra
    JOIN recent_activities ra_stats ON ra.actor_uri = ra_stats.actor_uri;
    ```
    
- **Redis:**
    - Pub/Sub Channels: `drop_created`, ... (購読), `ap_follow_received`, ... (発行)
    - Outbox配送キュー (Stream): `outbox_delivery_queue` (Consumer Group: `activitypub_workers`)
    - リモート情報キャッシュ: `remote_actor:{actor_id}`, `remote_object:{object_id}` (TTL設定)
    - WebFingerキャッシュ: `webfinger:{acct_uri}` (TTL設定)
    - 公開鍵キャッシュ: `public_key:{actor_id}` (TTL設定)

## 10. Operations & Monitoring (運用と監視)

- **主なオペレーション:**
    - DBマイグレーション。
    - Redis接続情報、Pub/Sub/Stream設定。
    - Outboxワーカ数、Consumer Groupの調整。
    - DLQの監視と対応。
    - リモート情報DB/キャッシュの削除ジョブ運用。
    - ドメインブロックリストの管理。
- **監視/アラート:**
    - **メトリクス:**
        - HTTPリクエスト数、レイテンシ、エラーレート (Inbox, Actor, WebFinger別)。
        - gRPCリクエスト数、レイテンシ、エラーレート (内部連携)。
        - Pub/Subイベント処理遅延、エラーレート。
        - Outboxキュー長、処理時間、成功/失敗/リトライ/DLQレート。
        - HTTP Signatures検証/署名エラーレート。
        - リモートサーバーへの配送エラーレート (宛先ドメイン別)。
        - Redisキャッシュヒット率。
        - Domain Events発行数 (RemoteActorDiscovered, ActivityReceived, DeliverySucceeded, DeliveryFailed, CircuitBreakerStateChanged別)。
        - サーキットブレーカー状態 (ドメイン別、状態別)。
        - アクティビティ検証エラー率 (ActivityValidator)。
    - **ログ:** Inbox/Outbox処理ログ、アクティビティ送受信ログ、HTTP Signatures検証/署名結果、エラーログ、DLQ投入ログ。
    - **トレース:** リクエスト処理、イベント処理、配送処理、他サービス連携のトレース。
    - **アラート:** HTTP/gRPCエラーレート急増、高レイテンシ、Pub/Sub処理遅延大、Outboxキュー滞留、配送失敗レート高騰、DLQ増加、特定リモートドメインへの接続エラー多発。

## 11. 構造化ログ戦略

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
    Service     string    `json:"service"`     // "avion-activitypub"
    Version     string    `json:"version"`     // サービスバージョン
    TraceID     string    `json:"trace_id"`    // OpenTelemetry TraceID
    SpanID      string    `json:"span_id"`     // OpenTelemetry SpanID
    
    // コンテキストフィールド
    UserID      string    `json:"user_id,omitempty"`
    ActorURI    string    `json:"actor_uri,omitempty"`
    ActivityID  string    `json:"activity_id,omitempty"`
    RequestID   string    `json:"request_id,omitempty"`
    Method      string    `json:"method,omitempty"`      // HTTP method or gRPC method
    Path        string    `json:"path,omitempty"`        // HTTP path
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
logger.Info("inbox request received",
    slog.String("method", "POST"),
    slog.String("path", "/users/alice/inbox"),
    slog.String("trace_id", traceID),
    slog.String("activity_type", activityType),
    slog.String("layer", "handler"),
)

logger.Error("inbox processing failed",
    slog.String("path", "/users/alice/inbox"),
    slog.String("trace_id", traceID),
    slog.String("error", err.Error()),
    slog.String("error_code", "SIGNATURE_VERIFICATION_FAILED"),
    slog.Int64("duration_ms", duration),
)
```

#### Use Case層
```go
logger.Info("signature verification started",
    slog.String("trace_id", ctx.Value("trace_id").(string)),
    slog.String("key_id", keyID),
    slog.String("algorithm", algorithm),
    slog.String("layer", "usecase"),
)

logger.Info("activity validation",
    slog.String("activity_id", activityID),
    slog.String("activity_type", activityType),
    slog.String("actor_uri", actorURI),
    slog.Bool("is_blocked", isBlocked),
    slog.String("layer", "usecase"),
)
```

#### Infrastructure層
```go
logger.Debug("remote actor fetch",
    slog.String("actor_uri", actorURI),
    slog.String("cache_status", "miss"),
    slog.Int64("fetch_duration_ms", fetchDuration),
    slog.String("layer", "infra"),
)

logger.Warn("outbox delivery failed",
    slog.String("target_inbox", targetInbox),
    slog.String("domain", domain),
    slog.Int("status_code", statusCode),
    slog.String("error", err.Error()),
    slog.String("layer", "infra"),
)
```

### HTTP Signature処理のログ
```go
// 署名検証
logger.Info("http signature verification",
    slog.String("event", "signature_verify"),
    slog.String("key_id", keyID),
    slog.String("actor_uri", actorURI),
    slog.Bool("cache_hit", cacheHit),
    slog.Bool("valid", valid),
)

// 署名生成
logger.Debug("http signature created",
    slog.String("event", "signature_create"),
    slog.String("target_host", targetHost),
    slog.String("key_id", keyID),
    slog.String("headers", strings.Join(headers, ",")),
)
```

### Outbox配送のログ
```go
// 配送タスク作成
logger.Info("outbox task created",
    slog.String("event", "outbox_task_create"),
    slog.String("activity_type", activityType),
    slog.String("activity_id", activityID),
    slog.Int("target_count", len(targets)),
    slog.String("delivery_strategy", strategy),
)

// 配送試行
logger.Info("delivery attempt",
    slog.String("event", "delivery_attempt"),
    slog.String("task_id", taskID),
    slog.String("target_inbox", targetInbox),
    slog.String("domain", domain),
    slog.Int("retry_count", retryCount),
    slog.Int64("duration_ms", duration),
)

// サーキットブレーカー
logger.Warn("circuit breaker state changed",
    slog.String("event", "circuit_breaker"),
    slog.String("domain", domain),
    slog.String("old_state", oldState),
    slog.String("new_state", newState),
    slog.Int("failure_count", failureCount),
)
```

### アクティビティ処理のログ
```go
// Follow受信
logger.Info("follow activity received",
    slog.String("event", "activity_received"),
    slog.String("activity_type", "Follow"),
    slog.String("actor", actorURI),
    slog.String("object", objectURI),
    slog.String("activity_id", activityID),
)

// Create(Note)配送
logger.Info("note activity delivered",
    slog.String("event", "activity_delivered"),
    slog.String("activity_type", "Create"),
    slog.String("object_type", "Note"),
    slog.String("activity_id", activityID),
    slog.Int("recipient_count", recipientCount),
)
```

### WebFinger処理のログ
```go
logger.Info("webfinger resolution",
    slog.String("event", "webfinger_resolve"),
    slog.String("resource", resource),
    slog.String("acct", acct),
    slog.Bool("found", found),
    slog.Bool("cache_hit", cacheHit),
)
```

### エラーログの詳細化
```go
logger.Error("failed to fetch remote actor",
    slog.String("actor_uri", actorURI),
    slog.String("error", err.Error()),
    slog.String("error_type", fmt.Sprintf("%T", err)),
    slog.Int("http_status", httpStatus),
    slog.String("response_body", responseBody),
    slog.String("stack_trace", string(debug.Stack())),
    slog.String("layer", "infra"),
)
```

### CRITICALレベルログの例
```go
// 署名検証系全体障害時
logger.With(slog.String("level", "CRITICAL")).Error("signature verification system failure",
    slog.String("component", "http_signature"),
    slog.String("error", "all_public_keys_unreachable"),
    slog.Int("failed_verifications", failedCount),
    slog.String("action", "emergency_maintenance_required"),
)

// Outboxキュー完全停止時
logger.With(slog.String("level", "CRITICAL")).Error("outbox delivery system failure",
    slog.String("queue_name", "outbox_delivery_queue"),
    slog.String("error", "all_workers_failed"),
    slog.Int("queued_tasks", queuedTasks),
    slog.String("impact", "federation_stopped"),
)

// 連合データ破損時
logger.With(slog.String("level", "CRITICAL")).Error("remote actor data corruption",
    slog.String("actor_uri", actorURI),
    slog.String("corruption_type", "key_mismatch"),
    slog.String("action", "immediate_cache_purge_required"),
    slog.String("impact", "federation_security_breach"),
)
```

### メトリクスログ
```go
// 配送統計
logger.Info("delivery statistics",
    slog.String("event", "delivery_stats"),
    slog.String("period", "5m"),
    slog.Int("delivered", delivered),
    slog.Int("failed", failed),
    slog.Int("retrying", retrying),
    slog.Float64("success_rate", successRate),
)

// ドメイン別エラー率
logger.Warn("high error rate for domain",
    slog.String("event", "domain_error_rate"),
    slog.String("domain", domain),
    slog.Float64("error_rate", errorRate),
    slog.Int("total_attempts", totalAttempts),
    slog.Int("failures", failures),
)
```

### ログ集約とクエリ
- **出力先**: 標準出力（Kubernetes環境ではFluentd/Fluent Bitが収集）
- **集約先**: Elasticsearch、CloudWatch Logs、またはLoki
- **クエリ例**:
  ```
  service="avion-activitypub" AND event="signature_verify" AND valid=false
  service="avion-activitypub" AND event="delivery_attempt" AND domain="example.com"
  service="avion-activitypub" AND event="circuit_breaker" AND new_state="OPEN"
  service="avion-activitypub" AND activity_type="Follow" AND layer="usecase"
  service="avion-activitypub" AND level="CRITICAL"
  ```

### セキュリティ考慮事項
- 署名値や秘密鍵は絶対にログに含めない
- HTTP Signatureのヘッダー名のみ記録し、値は記録しない
- Actorのプライベートなプロフィール情報は最小限に留める
- 外部サーバーからのレスポンスボディは必要最小限の場合のみ記録

## 12. ドメインオブジェクトとActivityPub JSON-LDのマッピング

ActivityPubプロトコルでは、すべてのオブジェクトはJSON-LD形式で表現されます。本サービスでは、ドメインオブジェクトとActivityPub JSON-LD表現間の変換を明確に定義します。

### Actor オブジェクトのマッピング

#### RemoteActor → ActivityPub Actor

```go
// Domain Object
type RemoteActor struct {
    ID               RemoteActorID
    ActorURI         ActorURI
    Username         string
    Domain           string
    DisplayName      *string
    Summary          *string
    IconURL          *string
    HeaderURL        *string
    PublicKeyID      string
    PublicKeyPEM     string
    InboxURL         InboxURL
    SharedInboxURL   *SharedInboxURL
    OutboxURL        *string
    FollowersURL     *string
    FollowingURL     *string
    FeaturedURL      *string
    LastFetchedAt    time.Time
    IsSuspended      bool
    MovedToActorURI  *ActorURI
}

// ActivityPub JSON-LD Representation
func (ra *RemoteActor) ToActivityPubActor() map[string]interface{} {
    actor := map[string]interface{}{
        "@context": []interface{}{
            "https://www.w3.org/ns/activitystreams",
            "https://w3id.org/security/v1",
        },
        "id":                string(ra.ActorURI),
        "type":              "Person",
        "preferredUsername": ra.Username,
        "inbox":             string(ra.InboxURL),
        "publicKey": map[string]interface{}{
            "id":           ra.PublicKeyID,
            "owner":        string(ra.ActorURI),
            "publicKeyPem": ra.PublicKeyPEM,
        },
    }
    
    if ra.DisplayName != nil {
        actor["name"] = *ra.DisplayName
    }
    
    if ra.Summary != nil {
        actor["summary"] = *ra.Summary
    }
    
    if ra.IconURL != nil {
        actor["icon"] = map[string]interface{}{
            "type":      "Image",
            "mediaType": "image/jpeg",
            "url":       *ra.IconURL,
        }
    }
    
    if ra.HeaderURL != nil {
        actor["image"] = map[string]interface{}{
            "type":      "Image", 
            "mediaType": "image/jpeg",
            "url":       *ra.HeaderURL,
        }
    }
    
    if ra.SharedInboxURL != nil {
        actor["endpoints"] = map[string]interface{}{
            "sharedInbox": string(*ra.SharedInboxURL),
        }
    }
    
    if ra.OutboxURL != nil {
        actor["outbox"] = *ra.OutboxURL
    }
    
    if ra.FollowersURL != nil {
        actor["followers"] = *ra.FollowersURL
    }
    
    if ra.FollowingURL != nil {
        actor["following"] = *ra.FollowingURL
    }
    
    if ra.FeaturedURL != nil {
        actor["featured"] = *ra.FeaturedURL
    }
    
    // Handle account move
    if ra.MovedToActorURI != nil {
        actor["movedTo"] = string(*ra.MovedToActorURI)
    }
    
    return actor
}

// Parse from ActivityPub JSON-LD
func ParseActivityPubActor(data map[string]interface{}) (*RemoteActor, error) {
    actorURI, ok := data["id"].(string)
    if !ok {
        return nil, ErrActivityInvalid
    }
    
    actorType, ok := data["type"].(string)
    if !ok || (actorType != "Person" && actorType != "Service" && actorType != "Organization") {
        return nil, ErrActivityUnsupported
    }
    
    username, ok := data["preferredUsername"].(string)
    if !ok {
        return nil, ErrActivityInvalid
    }
    
    inboxURL, ok := data["inbox"].(string)
    if !ok {
        return nil, ErrActivityInvalid
    }
    
    // Parse public key
    publicKeyData, ok := data["publicKey"].(map[string]interface{})
    if !ok {
        return nil, ErrActivityInvalid
    }
    
    publicKeyID, ok := publicKeyData["id"].(string)
    if !ok {
        return nil, ErrActivityInvalid
    }
    
    publicKeyPEM, ok := publicKeyData["publicKeyPem"].(string)
    if !ok {
        return nil, ErrActivityInvalid
    }
    
    domain := extractDomainFromURI(actorURI)
    
    actor := &RemoteActor{
        ActorURI:      ActorURI(actorURI),
        Username:      username,
        Domain:        domain,
        PublicKeyID:   publicKeyID,
        PublicKeyPEM:  publicKeyPEM,
        InboxURL:      InboxURL(inboxURL),
        LastFetchedAt: time.Now(),
        IsSuspended:   false,
    }
    
    // Optional fields
    if name, ok := data["name"].(string); ok {
        actor.DisplayName = &name
    }
    
    if summary, ok := data["summary"].(string); ok {
        actor.Summary = &summary
    }
    
    if iconData, ok := data["icon"].(map[string]interface{}); ok {
        if iconURL, ok := iconData["url"].(string); ok {
            actor.IconURL = &iconURL
        }
    }
    
    if imageData, ok := data["image"].(map[string]interface{}); ok {
        if imageURL, ok := imageData["url"].(string); ok {
            actor.HeaderURL = &imageURL
        }
    }
    
    if endpoints, ok := data["endpoints"].(map[string]interface{}); ok {
        if sharedInbox, ok := endpoints["sharedInbox"].(string); ok {
            sharedInboxURL := SharedInboxURL(sharedInbox)
            actor.SharedInboxURL = &sharedInboxURL
        }
    }
    
    if outbox, ok := data["outbox"].(string); ok {
        actor.OutboxURL = &outbox
    }
    
    if followers, ok := data["followers"].(string); ok {
        actor.FollowersURL = &followers
    }
    
    if following, ok := data["following"].(string); ok {
        actor.FollowingURL = &following
    }
    
    if featured, ok := data["featured"].(string); ok {
        actor.FeaturedURL = &featured
    }
    
    if movedTo, ok := data["movedTo"].(string); ok {
        movedToURI := ActorURI(movedTo)
        actor.MovedToActorURI = &movedToURI
    }
    
    return actor, nil
}
```

### Activity オブジェクトのマッピング

#### OutboxDeliveryTask → ActivityPub Activities

```go
// Create Activity
func BuildCreateActivity(actorURI string, objectData map[string]interface{}) map[string]interface{} {
    return map[string]interface{}{
        "@context": "https://www.w3.org/ns/activitystreams",
        "id":       fmt.Sprintf("%s/activities/%s", actorURI, generateActivityID()),
        "type":     "Create",
        "actor":    actorURI,
        "object":   objectData,
        "published": time.Now().UTC().Format(time.RFC3339),
        "to":       []string{"https://www.w3.org/ns/activitystreams#Public"},
        "cc":       []string{fmt.Sprintf("%s/followers", actorURI)},
    }
}

// Follow Activity
func BuildFollowActivity(actorURI string, targetActorURI string) map[string]interface{} {
    return map[string]interface{}{
        "@context": "https://www.w3.org/ns/activitystreams",
        "id":       fmt.Sprintf("%s/activities/%s", actorURI, generateActivityID()),
        "type":     "Follow",
        "actor":    actorURI,
        "object":   targetActorURI,
        "published": time.Now().UTC().Format(time.RFC3339),
    }
}

// Like Activity
func BuildLikeActivity(actorURI string, objectURI string) map[string]interface{} {
    return map[string]interface{}{
        "@context": "https://www.w3.org/ns/activitystreams",
        "id":       fmt.Sprintf("%s/activities/%s", actorURI, generateActivityID()),
        "type":     "Like",
        "actor":    actorURI,
        "object":   objectURI,
        "published": time.Now().UTC().Format(time.RFC3339),
    }
}

// Announce Activity (Boost/Renote)
func BuildAnnounceActivity(actorURI string, objectURI string) map[string]interface{} {
    return map[string]interface{}{
        "@context": "https://www.w3.org/ns/activitystreams",
        "id":       fmt.Sprintf("%s/activities/%s", actorURI, generateActivityID()),
        "type":     "Announce",
        "actor":    actorURI,
        "object":   objectURI,
        "published": time.Now().UTC().Format(time.RFC3339),
        "to":       []string{"https://www.w3.org/ns/activitystreams#Public"},
        "cc":       []string{fmt.Sprintf("%s/followers", actorURI)},
    }
}

// Undo Activity
func BuildUndoActivity(actorURI string, targetActivity map[string]interface{}) map[string]interface{} {
    return map[string]interface{}{
        "@context": "https://www.w3.org/ns/activitystreams",
        "id":       fmt.Sprintf("%s/activities/%s", actorURI, generateActivityID()),
        "type":     "Undo",
        "actor":    actorURI,
        "object":   targetActivity,
        "published": time.Now().UTC().Format(time.RFC3339),
    }
}

// Block Activity
func BuildBlockActivity(actorURI string, targetActorURI string) map[string]interface{} {
    return map[string]interface{}{
        "@context": "https://www.w3.org/ns/activitystreams",
        "id":       fmt.Sprintf("%s/activities/%s", actorURI, generateActivityID()),
        "type":     "Block",
        "actor":    actorURI,
        "object":   targetActorURI,
        "published": time.Now().UTC().Format(time.RFC3339),
    }
}

// Flag Activity (Report)
func BuildFlagActivity(actorURI string, targetObjectURI string, reason string) map[string]interface{} {
    return map[string]interface{}{
        "@context": "https://www.w3.org/ns/activitystreams",
        "id":       fmt.Sprintf("%s/activities/%s", actorURI, generateActivityID()),
        "type":     "Flag",
        "actor":    actorURI,
        "object":   targetObjectURI,
        "content":  reason,
        "published": time.Now().UTC().Format(time.RFC3339),
    }
}

// Move Activity
func BuildMoveActivity(actorURI string, targetActorURI string) map[string]interface{} {
    return map[string]interface{}{
        "@context": "https://www.w3.org/ns/activitystreams",
        "id":       fmt.Sprintf("%s/activities/%s", actorURI, generateActivityID()),
        "type":     "Move",
        "actor":    actorURI,
        "object":   actorURI,
        "target":   targetActorURI,
        "published": time.Now().UTC().Format(time.RFC3339),
    }
}
```

### Object マッピング

#### RemoteObject → ActivityPub Objects

```go
// Note Object (Drop/Post)
func BuildNoteObject(content string, actorURI string, attachments []map[string]interface{}) map[string]interface{} {
    note := map[string]interface{}{
        "@context":    "https://www.w3.org/ns/activitystreams",
        "id":          fmt.Sprintf("%s/objects/%s", extractBaseURL(actorURI), generateObjectID()),
        "type":        "Note",
        "attributedTo": actorURI,
        "content":     content,
        "published":   time.Now().UTC().Format(time.RFC3339),
        "to":          []string{"https://www.w3.org/ns/activitystreams#Public"},
        "cc":          []string{fmt.Sprintf("%s/followers", actorURI)},
    }
    
    if len(attachments) > 0 {
        note["attachment"] = attachments
    }
    
    return note
}

// Image Object (Media Attachment)
func BuildImageObject(url string, mediaType string, name *string) map[string]interface{} {
    image := map[string]interface{}{
        "type":      "Image",
        "url":       url,
        "mediaType": mediaType,
    }
    
    if name != nil {
        image["name"] = *name
    }
    
    return image
}

// Question Object (Poll)
func BuildQuestionObject(content string, options []string, endTime time.Time, actorURI string) map[string]interface{} {
    oneOfOptions := make([]map[string]interface{}, len(options))
    for i, option := range options {
        oneOfOptions[i] = map[string]interface{}{
            "type": "Note",
            "name": option,
            "replies": map[string]interface{}{
                "type":       "Collection",
                "totalItems": 0,
            },
        }
    }
    
    return map[string]interface{}{
        "@context":    "https://www.w3.org/ns/activitystreams",
        "id":          fmt.Sprintf("%s/questions/%s", extractBaseURL(actorURI), generateObjectID()),
        "type":        "Question",
        "attributedTo": actorURI,
        "content":     content,
        "oneOf":       oneOfOptions,
        "endTime":     endTime.UTC().Format(time.RFC3339),
        "published":   time.Now().UTC().Format(time.RFC3339),
        "to":          []string{"https://www.w3.org/ns/activitystreams#Public"},
        "cc":          []string{fmt.Sprintf("%s/followers", actorURI)},
    }
}
```

### Collection マッピング

#### Collections (Outbox, Followers, etc.)

```go
// OrderedCollection for Outbox
func BuildOutboxCollection(actorURI string, totalItems int, firstPageURI *string) map[string]interface{} {
    collection := map[string]interface{}{
        "@context":   "https://www.w3.org/ns/activitystreams",
        "id":         fmt.Sprintf("%s/outbox", actorURI),
        "type":       "OrderedCollection",
        "totalItems": totalItems,
    }
    
    if firstPageURI != nil {
        collection["first"] = *firstPageURI
    }
    
    return collection
}

// OrderedCollectionPage for pagination
func BuildOrderedCollectionPage(collectionURI string, items []map[string]interface{}, nextPageURI *string, prevPageURI *string) map[string]interface{} {
    page := map[string]interface{}{
        "@context":     "https://www.w3.org/ns/activitystreams",
        "type":         "OrderedCollectionPage",
        "partOf":       collectionURI,
        "orderedItems": items,
    }
    
    if nextPageURI != nil {
        page["next"] = *nextPageURI
    }
    
    if prevPageURI != nil {
        page["prev"] = *prevPageURI
    }
    
    return page
}

// Collection for Followers/Following
func BuildFollowersCollection(actorURI string, totalItems int, firstPageURI *string) map[string]interface{} {
    collection := map[string]interface{}{
        "@context":   "https://www.w3.org/ns/activitystreams",
        "id":         fmt.Sprintf("%s/followers", actorURI),
        "type":       "Collection",
        "totalItems": totalItems,
    }
    
    if firstPageURI != nil {
        collection["first"] = *firstPageURI
    }
    
    return collection
}
```

### WebFinger リソースマッピング

```go
// WebFinger Resource
func BuildWebFingerResource(username string, domain string, actorURI string) map[string]interface{} {
    subject := fmt.Sprintf("acct:%s@%s", username, domain)
    
    return map[string]interface{}{
        "subject": subject,
        "aliases": []string{actorURI},
        "links": []map[string]interface{}{
            {
                "rel":  "self",
                "type": "application/activity+json",
                "href": actorURI,
            },
            {
                "rel":      "http://webfinger.net/rel/profile-page",
                "type":     "text/html",
                "href":     actorURI,
                "template": fmt.Sprintf("https://%s/@%s", domain, username),
            },
        },
    }
}
```

### バリデーション関数

```go
// Activity JSON-LD validation
func ValidateActivityPubObject(data map[string]interface{}) error {
    // Check @context
    if _, ok := data["@context"]; !ok {
        return ErrActivityMalformed
    }
    
    // Check required fields
    if _, ok := data["type"]; !ok {
        return ErrActivityMalformed
    }
    
    if _, ok := data["id"]; !ok {
        return ErrActivityMalformed
    }
    
    // Type-specific validation
    objectType, ok := data["type"].(string)
    if !ok {
        return ErrActivityMalformed
    }
    
    switch objectType {
    case "Create", "Update", "Delete", "Follow", "Accept", "Reject", "Add", "Remove", "Like", "Announce", "Undo", "Block", "Flag", "Move":
        return validateActivity(data)
    case "Note", "Article", "Image", "Video", "Audio", "Document", "Page", "Question":
        return validateObject(data)
    case "Person", "Service", "Organization", "Group":
        return validateActor(data)
    default:
        return ErrActivityUnsupported
    }
}

func validateActivity(data map[string]interface{}) error {
    if _, ok := data["actor"]; !ok {
        return ErrActivityMalformed
    }
    return nil
}

func validateObject(data map[string]interface{}) error {
    if _, ok := data["attributedTo"]; !ok {
        return ErrActivityMalformed
    }
    return nil
}

func validateActor(data map[string]interface{}) error {
    if _, ok := data["inbox"]; !ok {
        return ErrActivityMalformed
    }
    if _, ok := data["publicKey"]; !ok {
        return ErrActivityMalformed
    }
    return nil
}
```

## 13. ドメインオブジェクトとDBスキーマのマッピング

### RemoteActor Aggregate → remote_actors テーブル

```sql
CREATE TABLE remote_actors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_uri TEXT NOT NULL UNIQUE,
    username TEXT NOT NULL,
    domain TEXT NOT NULL,
    display_name TEXT,
    summary TEXT,
    icon_url TEXT,
    public_key_id TEXT NOT NULL,
    public_key_pem TEXT NOT NULL,
    inbox_url TEXT NOT NULL,
    shared_inbox_url TEXT,
    outbox_url TEXT,
    followers_url TEXT,
    following_url TEXT,
    featured_url TEXT,
    last_fetched_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_suspended BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT remote_actors_username_domain_key UNIQUE (username, domain),
    INDEX idx_remote_actors_domain (domain),
    INDEX idx_remote_actors_last_fetched_at (last_fetched_at)
);
```

### OutboxDeliveryTask Aggregate → outbox_delivery_tasks テーブル

```sql
CREATE TABLE outbox_delivery_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    activity_id TEXT NOT NULL,
    activity_type TEXT NOT NULL,
    activity_content JSONB NOT NULL,
    actor_id UUID NOT NULL REFERENCES users(id),
    target_inbox_url TEXT NOT NULL,
    target_domain TEXT NOT NULL,
    delivery_status TEXT NOT NULL CHECK (delivery_status IN ('pending', 'delivering', 'delivered', 'failed', 'dead_letter')),
    retry_count INTEGER NOT NULL DEFAULT 0,
    max_retries INTEGER NOT NULL DEFAULT 5,
    next_retry_at TIMESTAMP WITH TIME ZONE,
    last_attempt_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_delivery_tasks_status (delivery_status, next_retry_at),
    INDEX idx_delivery_tasks_domain (target_domain),
    INDEX idx_delivery_tasks_activity_id (activity_id)
);
```

### DeliveryAttempt Entity → delivery_attempts テーブル

```sql
CREATE TABLE delivery_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delivery_task_id UUID NOT NULL REFERENCES outbox_delivery_tasks(id) ON DELETE CASCADE,
    attempt_number INTEGER NOT NULL,
    attempted_at TIMESTAMP WITH TIME ZONE NOT NULL,
    status_code INTEGER,
    error_message TEXT,
    response_headers JSONB,
    duration_ms INTEGER,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT delivery_attempts_task_attempt_unique UNIQUE (delivery_task_id, attempt_number),
    INDEX idx_delivery_attempts_task_id (delivery_task_id)
);
```

### RemoteObject Entity → remote_objects テーブル

```sql
CREATE TABLE remote_objects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    object_uri TEXT NOT NULL UNIQUE,
    object_type TEXT NOT NULL,
    author_actor_id UUID REFERENCES remote_actors(id),
    content JSONB NOT NULL,
    published_at TIMESTAMP WITH TIME ZONE,
    last_updated_at TIMESTAMP WITH TIME ZONE,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_remote_objects_type (object_type),
    INDEX idx_remote_objects_author (author_actor_id),
    INDEX idx_remote_objects_published_at (published_at DESC)
);
```

### CircuitBreakerState → circuit_breaker_states テーブル

```sql
CREATE TABLE circuit_breaker_states (
    domain TEXT PRIMARY KEY,
    state TEXT NOT NULL CHECK (state IN ('CLOSED', 'OPEN', 'HALF_OPEN')),
    failure_count INTEGER NOT NULL DEFAULT 0,
    success_count INTEGER NOT NULL DEFAULT 0,
    last_failure_time TIMESTAMP WITH TIME ZONE,
    last_success_time TIMESTAMP WITH TIME ZONE,
    next_retry_time TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_circuit_breaker_state (state),
    INDEX idx_circuit_breaker_retry_time (next_retry_time)
);
```

### ProcessedActivity → processed_activities テーブル（重複排除用）

```sql
CREATE TABLE processed_activities (
    activity_id TEXT PRIMARY KEY,
    activity_type TEXT NOT NULL,
    actor_uri TEXT NOT NULL,
    received_at TIMESTAMP WITH TIME ZONE NOT NULL,
    processed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_processed_activities_received_at (received_at),
    INDEX idx_processed_activities_actor (actor_uri)
);
```

### WebFingerCache → webfinger_cache テーブル

```sql
CREATE TABLE webfinger_cache (
    resource TEXT PRIMARY KEY,
    subject TEXT NOT NULL,
    aliases JSONB,
    links JSONB NOT NULL,
    cached_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    INDEX idx_webfinger_cache_expires_at (expires_at)
);
```

### Value Objectの一時保存（Redis）

```redis
# HTTP Signature公開鍵キャッシュ
KEY: public_key:{actor_uri}
VALUE: {
    "keyId": "https://example.com/users/alice#main-key",
    "publicKeyPem": "-----BEGIN PUBLIC KEY-----...",
    "algorithm": "rsa-sha256"
}
TTL: 3600 (1時間)

# リモートActorキャッシュ
KEY: remote_actor:{actor_uri}
VALUE: RemoteActorのJSON表現
TTL: 300 (5分)

# 配送サーキットブレーカー状態
KEY: circuit_breaker:{domain}
VALUE: {
    "state": "OPEN",
    "failureCount": 5,
    "lastFailureTime": "2025-01-01T00:00:00Z",
    "nextRetryTime": "2025-01-01T00:05:00Z"
}
TTL: 600 (10分)
```


## 13. エラーハンドリング戦略

> **注意:** エラーコードは[共通エラーコード標準](../common/errors/error-codes.md)に準拠します。このサービスではプレフィックス `APB` を使用します。

### エラーコード体系

本サービスは、Avionプラットフォーム標準のエラーコード体系に準拠します。

- **命名規則**: `[SERVICE]_[LAYER]_[ERROR_TYPE]`形式
- **エラーカタログ**: [error-catalog.md](./error-catalog.md)
- **実装ガイド**: [共通エラー実装ガイド](../common/errors/implementation-guide.md)
- **標準仕様**: [エラーコード標準化ガイドライン](../common/errors/error-standards.md)

詳細なエラーコード定義とマッピングについては、上記のドキュメントを参照してください。

ActivityPub連合においては、外部サーバーとの通信エラーやプロトコルレベルのエラーが発生するため、堅牢なエラーハンドリング戦略が重要です。

### ActivityPub固有エラー分類

#### 連合通信エラー
- **リモートサーバーエラー**: HTTP 5xx、タイムアウト、DNS解決失敗
- **プロトコルエラー**: 無効なActivityPub形式、署名検証失敗
- **認証エラー**: HTTP Signatures不正、Actor認証失敗

#### データ整合性エラー
- **オブジェクト参照エラー**: 存在しないActor/Object参照
- **タイムスタンプエラー**: 未来または古すぎるActivity
- **重複配送エラー**: 同一Activityの重複受信

### エラー回復戦略

- **指数バックオフリトライ**: 一時的なネットワークエラー
- **DLQ管理**: 恒久的な配送失敗Activity
- **サーキットブレーカー**: 障害サーバーへの配送停止
- **フォールバック処理**: 部分的な機能低下での継続運用

## 14. Integration Specifications (連携仕様)

### 13.1. avion-user との連携

**Purpose:** ユーザー認証情報、プロフィール情報、および秘密鍵による署名処理の連携

**Integration Method:** gRPC

**Data Flow:**
1. ActorQueryHandler がローカルユーザー情報を取得
2. UserServiceClient 経由でユーザープロフィールを取得
3. HTTP Signatures生成時に秘密鍵での署名を依頼
4. 公開鍵情報の取得とキャッシュ更新

**Error Handling:** サービス不可用時はcodes.Unavailable、認証失敗時はcodes.Unauthenticatedを返却

### 13.2. avion-media との連携

**Purpose:** リモートメディアファイルのキャッシュ処理

**Integration Method:** gRPC

**Data Flow:**
1. リモートActivityにメディア添付がある場合
2. MediaServiceClient にキャッシュ依頼を送信
3. 非同期でメディアダウンロードとキャッシュ実行
4. キャッシュ完了通知を受信

**Error Handling:** メディアキャッシュ失敗は警告ログのみ、処理は継続

### 13.3. Event Publishing

**Events Published:**
- `ap_activity_received`: ActivityPub アクティビティ受信時
- `ap_actor_discovered`: 新しいリモートActor発見時
- `ap_delivery_succeeded`: 配送成功時
- `ap_delivery_failed`: 配送失敗時

**Event Schema:**
```go
type ActivityReceivedEvent struct {
    ActivityID   string    `json:"activity_id"`
    ActivityType string    `json:"activity_type"`
    ActorURI     string    `json:"actor_uri"`
    ObjectURI    string    `json:"object_uri,omitempty"`
    Timestamp    time.Time `json:"timestamp"`
}
```


## 15. Concerns / Open Questions (懸念事項・相談したいこと)

### 技術的リスク・課題

- **プロトコルの複雑性と互換性維持:**
  - ActivityPub仕様の解釈差異やサーバー固有拡張への対応
  - Mastodon、Misskey、Pleroma等の実装差異
  - 相互運用性テストの継続的実施が必要

- **非同期処理の複雑性:**
  - Redis StreamとConsumer Groupによる配送処理の堅牢性
  - DLQ管理と障害時の手動介入プロセス
  - 配送順序保証が必要なケースの識別と対応

- **リモート情報管理のスケーラビリティ:**
  - 大量のリモートActor/Object情報の効率的管理
  - キャッシュ戦略の最適化（TTL、容量制限）
  - データ保持期間とGDPR準拠

- **セキュリティとスパム対策:**
  - HTTP Signatures検証の堅牢性確保
  - 悪意のあるアクティビティ・スパムの自動検出
  - レート制限とDDoS対策の実装

### 未解決事項・意思決定待ち

- **使用ライブラリ・フレームワーク:**
  - ActivityPubライブラリの選定（自作 vs 既存ライブラリ）
  - HTTP Signaturesライブラリの選定
  - JSON-LD処理ライブラリの選定

- **運用・監視戦略:**
  - 配送失敗時のアラート・エスカレーション基準
  - リモートサーバー障害時の自動復旧戦略
  - ドメインブロックリストの管理プロセス

- **相互運用性・テスト戦略:**
  - 他のActivityPub実装との互換性テスト方法
  - 継続的な相互運用性検証プロセス
  - エッジケース・異常系のテストカバレッジ

- **パフォーマンス・キャパシティ:**
  - 大規模インスタンス（100万ユーザー）での配送戦略
  - バッチ配送とリアルタイム配送の使い分け基準
  - OutboxキューとConsumer Groupの最適な設定値

### 将来的な拡張・改善項目

- **ActivityPub仕様拡張対応:**
  - Client-to-Server (C2S) プロトコル実装時期
  - リレーサーバー機能の実装要否
  - 新しいActivityPubエクステンションへの追従方針

- **高度なモデレーション機能:**
  - 機械学習ベースのスパム・不正検出
  - コミュニティベースのモデレーション機能
  - 自動的なコンテンツフィルタリング

- **パフォーマンス最適化:**
  - 配送処理の並列化・最適化
  - データベースのパーティショニング戦略
  - CDN活用によるメディア配信最適化

## Service-Specific Test Strategy

### Overview

avion-activitypub requires comprehensive testing due to its complex federation requirements and interoperability with diverse ActivityPub implementations. This section outlines detailed testing strategies specific to ActivityPub federation protocols.

### Core Testing Areas

#### 1. HTTP Signature Generation and Verification Testing

HTTP Signatures are critical for ActivityPub federation security. Testing must cover both signature generation and verification across different implementations.

```go
package signature_test

import (
    "crypto/rand"
    "crypto/rsa"
    "crypto/sha256"
    "crypto/x509"
    "encoding/pem"
    "net/http"
    "strings"
    "testing"
    "time"

    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestHTTPSignatureGeneration(t *testing.T) {
    tests := []struct {
        name           string
        method         string
        uri            string
        headers        map[string]string
        body           string
        expectedFields []string
    }{
        {
            name:   "POST with body signature",
            method: "POST",
            uri:    "https://example.com/inbox",
            headers: map[string]string{
                "Host":         "example.com",
                "Date":         "Tue, 07 Jun 2014 20:51:35 GMT",
                "Content-Type": "application/activity+json",
            },
            body: `{"type":"Create","actor":"https://our.instance.com/users/alice"}`,
            expectedFields: []string{
                "(request-target)", "host", "date", "digest", "content-type",
            },
        },
        {
            name:   "GET without body",
            method: "GET",
            uri:    "https://example.com/users/bob",
            headers: map[string]string{
                "Host": "example.com",
                "Date": "Tue, 07 Jun 2014 20:51:35 GMT",
            },
            expectedFields: []string{
                "(request-target)", "host", "date",
            },
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Generate test RSA key
            privateKey, err := rsa.GenerateKey(rand.Reader, 2048)
            require.NoError(t, err)

            // Create signature generator
            signer := NewHTTPSignatureSigner(privateKey, "https://our.instance.com/users/alice#main-key")

            // Create request
            req, err := http.NewRequest(tt.method, tt.uri, strings.NewReader(tt.body))
            require.NoError(t, err)

            for k, v := range tt.headers {
                req.Header.Set(k, v)
            }

            // Generate signature
            signature, err := signer.Sign(req)
            require.NoError(t, err)

            // Verify signature structure
            assert.Contains(t, signature, "keyId=")
            assert.Contains(t, signature, "algorithm=\"rsa-sha256\"")
            assert.Contains(t, signature, "headers=")
            assert.Contains(t, signature, "signature=")

            // Verify headers field contains expected fields
            for _, field := range tt.expectedFields {
                assert.Contains(t, signature, field)
            }
        })
    }
}

func TestHTTPSignatureVerification(t *testing.T) {
    tests := []struct {
        name          string
        signature     string
        publicKeyPEM  string
        requestTarget string
        headers       map[string]string
        body          string
        shouldVerify  bool
    }{
        {
            name: "valid signature with digest",
            signature: `keyId="https://mastodon.social/users/alice#main-key",algorithm="rsa-sha256",headers="(request-target) host date digest content-type",signature="..."`,
            requestTarget: "post /inbox",
            headers: map[string]string{
                "Host":         "our.instance.com",
                "Date":         "Tue, 07 Jun 2014 20:51:35 GMT",
                "Digest":       "SHA-256=X48E9qOokqqrvdts8nOJRJN3OWDUoyWxBf7kbu9DBPE=",
                "Content-Type": "application/activity+json",
            },
            body:         `{"type":"Create","actor":"https://mastodon.social/users/alice"}`,
            shouldVerify: true,
        },
        {
            name: "invalid signature - tampered body",
            signature: `keyId="https://mastodon.social/users/alice#main-key",algorithm="rsa-sha256",headers="(request-target) host date digest",signature="..."`,
            requestTarget: "post /inbox",
            headers: map[string]string{
                "Host":   "our.instance.com",
                "Date":   "Tue, 07 Jun 2014 20:51:35 GMT",
                "Digest": "SHA-256=X48E9qOokqqrvdts8nOJRJN3OWDUoyWxBf7kbu9DBPE=",
            },
            body:         `{"type":"Delete","actor":"https://mastodon.social/users/alice"}`, // Different body
            shouldVerify: false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            verifier := NewHTTPSignatureVerifier()
            
            // Mock public key fetcher
            verifier.SetPublicKeyFetcher(func(keyId string) (*rsa.PublicKey, error) {
                return generateTestPublicKey(), nil
            })

            result := verifier.Verify(tt.signature, tt.requestTarget, tt.headers, tt.body)
            assert.Equal(t, tt.shouldVerify, result)
        })
    }
}
```

#### 2. Activity Validation Testing

JSON-LD format validation and ActivityPub activity structure validation are essential for proper federation.

```go
package activity_test

import (
    "encoding/json"
    "testing"

    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestActivityValidation(t *testing.T) {
    tests := []struct {
        name        string
        activity    map[string]interface{}
        shouldValid bool
        errorType   string
    }{
        {
            name: "valid Create activity",
            activity: map[string]interface{}{
                "@context": []interface{}{
                    "https://www.w3.org/ns/activitystreams",
                    "https://w3id.org/security/v1",
                },
                "type":   "Create",
                "id":     "https://example.com/activities/123",
                "actor":  "https://example.com/users/alice",
                "to":     []string{"https://www.w3.org/ns/activitystreams#Public"},
                "object": map[string]interface{}{
                    "type":    "Note",
                    "id":      "https://example.com/notes/456",
                    "content": "Hello, ActivityPub!",
                    "attributedTo": "https://example.com/users/alice",
                },
                "published": "2024-01-15T10:30:00Z",
            },
            shouldValid: true,
        },
        {
            name: "invalid - missing required fields",
            activity: map[string]interface{}{
                "@context": "https://www.w3.org/ns/activitystreams",
                "type":     "Create",
                // Missing id, actor, object
            },
            shouldValid: false,
            errorType:   "MissingRequiredField",
        },
        {
            name: "invalid - malformed actor IRI",
            activity: map[string]interface{}{
                "@context": "https://www.w3.org/ns/activitystreams",
                "type":     "Follow",
                "id":       "https://example.com/activities/789",
                "actor":    "not-a-valid-iri",
                "object":   "https://mastodon.social/users/bob",
            },
            shouldValid: false,
            errorType:   "InvalidIRI",
        },
        {
            name: "unknown activity type handling",
            activity: map[string]interface{}{
                "@context": "https://www.w3.org/ns/activitystreams",
                "type":     "CustomActivity",
                "id":       "https://example.com/activities/custom",
                "actor":    "https://example.com/users/alice",
                "object":   "https://example.com/objects/123",
            },
            shouldValid: true, // Should accept unknown activities
        },
    }

    validator := NewActivityValidator()

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            activityJSON, err := json.Marshal(tt.activity)
            require.NoError(t, err)

            result, err := validator.Validate(activityJSON)
            
            if tt.shouldValid {
                assert.NoError(t, err)
                assert.True(t, result.IsValid)
            } else {
                assert.Error(t, err)
                if tt.errorType != "" {
                    assert.Contains(t, err.Error(), tt.errorType)
                }
            }
        })
    }
}

func TestActivityNormalization(t *testing.T) {
    tests := []struct {
        name     string
        input    string
        expected map[string]interface{}
    }{
        {
            name: "expand compact IRI in context",
            input: `{
                "@context": "https://www.w3.org/ns/activitystreams",
                "type": "Create",
                "actor": "https://example.com/users/alice",
                "object": {
                    "type": "Note",
                    "content": "Hello!"
                }
            }`,
            expected: map[string]interface{}{
                "@context": []interface{}{
                    "https://www.w3.org/ns/activitystreams",
                },
                "type":   "Create",
                "actor":  "https://example.com/users/alice",
                "object": map[string]interface{}{
                    "type":    "Note",
                    "content": "Hello!",
                },
            },
        },
    }

    normalizer := NewActivityNormalizer()

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result, err := normalizer.Normalize([]byte(tt.input))
            require.NoError(t, err)

            // Compare normalized structure
            assert.Equal(t, tt.expected["type"], result["type"])
            assert.Equal(t, tt.expected["actor"], result["actor"])
        })
    }
}
```

#### 3. WebFinger Discovery Testing

WebFinger protocol is essential for actor discovery and must handle various server implementations.

```go
package webfinger_test

import (
    "encoding/json"
    "net/http"
    "net/http/httptest"
    "testing"

    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestWebFingerDiscovery(t *testing.T) {
    tests := []struct {
        name           string
        acct           string
        serverResponse string
        statusCode     int
        expectedActor  string
        shouldError    bool
    }{
        {
            name: "valid Mastodon WebFinger response",
            acct: "alice@mastodon.social",
            serverResponse: `{
                "subject": "acct:alice@mastodon.social",
                "links": [
                    {
                        "rel": "self",
                        "type": "application/activity+json",
                        "href": "https://mastodon.social/users/alice"
                    },
                    {
                        "rel": "http://webfinger.net/rel/profile-page",
                        "type": "text/html",
                        "href": "https://mastodon.social/@alice"
                    }
                ]
            }`,
            statusCode:    200,
            expectedActor: "https://mastodon.social/users/alice",
            shouldError:   false,
        },
        {
            name: "valid Misskey WebFinger response",
            acct: "bob@misskey.io",
            serverResponse: `{
                "subject": "acct:bob@misskey.io",
                "links": [
                    {
                        "rel": "self",
                        "type": "application/activity+json",
                        "href": "https://misskey.io/users/9abcdef123456789"
                    }
                ]
            }`,
            statusCode:    200,
            expectedActor: "https://misskey.io/users/9abcdef123456789",
            shouldError:   false,
        },
        {
            name:           "user not found",
            acct:           "nonexistent@example.com",
            serverResponse: `{"error": "User not found"}`,
            statusCode:     404,
            shouldError:    true,
        },
        {
            name: "malformed response",
            acct: "malformed@example.com",
            serverResponse: `{
                "subject": "acct:malformed@example.com"
                // Missing links array
            }`,
            statusCode:  200,
            shouldError: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Create mock server
            server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
                assert.Equal(t, "/.well-known/webfinger", r.URL.Path)
                assert.Equal(t, "acct:"+tt.acct, r.URL.Query().Get("resource"))
                
                w.Header().Set("Content-Type", "application/jrd+json")
                w.WriteHeader(tt.statusCode)
                w.Write([]byte(tt.serverResponse))
            }))
            defer server.Close()

            client := NewWebFingerClient()
            client.SetBaseURL(server.URL)

            result, err := client.Discover(tt.acct)

            if tt.shouldError {
                assert.Error(t, err)
            } else {
                require.NoError(t, err)
                assert.Equal(t, tt.expectedActor, result.ActorURL)
                assert.Equal(t, "acct:"+tt.acct, result.Subject)
            }
        })
    }
}

func TestWebFingerCaching(t *testing.T) {
    callCount := 0
    server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        callCount++
        response := map[string]interface{}{
            "subject": "acct:alice@example.com",
            "links": []map[string]string{
                {
                    "rel":  "self",
                    "type": "application/activity+json",
                    "href": "https://example.com/users/alice",
                },
            },
        }
        json.NewEncoder(w).Encode(response)
    }))
    defer server.Close()

    client := NewWebFingerClient()
    client.SetBaseURL(server.URL)
    client.EnableCaching(5 * 60) // 5 minutes cache

    // First call
    result1, err := client.Discover("alice@example.com")
    require.NoError(t, err)
    assert.Equal(t, 1, callCount)

    // Second call should use cache
    result2, err := client.Discover("alice@example.com")
    require.NoError(t, err)
    assert.Equal(t, 1, callCount) // No additional HTTP call
    assert.Equal(t, result1.ActorURL, result2.ActorURL)
}
```

#### 4. Interoperability Testing with Different ActivityPub Implementations

Testing compatibility with major ActivityPub implementations ensures broad federation support.

```go
package interop_test

import (
    "encoding/json"
    "net/http"
    "net/http/httptest"
    "testing"

    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestMastodonCompatibility(t *testing.T) {
    tests := []struct {
        name         string
        activityType string
        payload      map[string]interface{}
        expectAccept bool
    }{
        {
            name:         "Mastodon Create Note",
            activityType: "Create",
            payload: map[string]interface{}{
                "@context": []interface{}{
                    "https://www.w3.org/ns/activitystreams",
                    map[string]interface{}{
                        "ostatus":      "http://ostatus.org#",
                        "atomUri":      "ostatus:atomUri",
                        "inReplyToAtomUri": "ostatus:inReplyToAtomUri",
                        "conversation": "ostatus:conversation",
                        "sensitive":    "as:sensitive",
                        "toot":         "http://joinmastodon.org/ns#",
                        "votersCount":  "toot:votersCount",
                    },
                },
                "id":     "https://mastodon.social/users/alice/statuses/123/activity",
                "type":   "Create",
                "actor":  "https://mastodon.social/users/alice",
                "published": "2024-01-15T10:30:00Z",
                "to": []string{"https://www.w3.org/ns/activitystreams#Public"},
                "cc": []string{"https://mastodon.social/users/alice/followers"},
                "object": map[string]interface{}{
                    "id":           "https://mastodon.social/users/alice/statuses/123",
                    "type":         "Note",
                    "summary":      nil,
                    "inReplyTo":    nil,
                    "published":    "2024-01-15T10:30:00Z",
                    "url":          "https://mastodon.social/@alice/123",
                    "attributedTo": "https://mastodon.social/users/alice",
                    "to": []string{"https://www.w3.org/ns/activitystreams#Public"},
                    "cc": []string{"https://mastodon.social/users/alice/followers"},
                    "sensitive":    false,
                    "atomUri":      "https://mastodon.social/users/alice/statuses/123",
                    "conversation": "tag:mastodon.social,2024-01-15:objectId=123:objectType=Conversation",
                    "content":      "<p>Hello from Mastodon!</p>",
                    "contentMap": map[string]string{
                        "en": "<p>Hello from Mastodon!</p>",
                    },
                    "attachment": []interface{}{},
                    "tag":        []interface{}{},
                },
            },
            expectAccept: true,
        },
        {
            name:         "Mastodon Follow with extensions",
            activityType: "Follow",
            payload: map[string]interface{}{
                "@context": []interface{}{
                    "https://www.w3.org/ns/activitystreams",
                    "https://w3id.org/security/v1",
                },
                "id":     "https://mastodon.social/users/alice#follows/456",
                "type":   "Follow",
                "actor":  "https://mastodon.social/users/alice",
                "object": "https://our.instance.com/users/bob",
            },
            expectAccept: true,
        },
    }

    processor := NewActivityProcessor()

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            activityJSON, err := json.Marshal(tt.payload)
            require.NoError(t, err)

            result, err := processor.ProcessInboxActivity(activityJSON)

            if tt.expectAccept {
                assert.NoError(t, err)
                assert.True(t, result.Accepted)
            } else {
                assert.Error(t, err)
            }
        })
    }
}

func TestMisskeyCompatibility(t *testing.T) {
    // Misskey uses different object structures and extensions
    misskeyNote := map[string]interface{}{
        "@context": []interface{}{
            "https://www.w3.org/ns/activitystreams",
            "https://misskey-hub.net/ns#",
        },
        "id":     "https://misskey.io/notes/9abcdef123456789",
        "type":   "Create",
        "actor":  "https://misskey.io/users/9uvwxyz987654321",
        "object": map[string]interface{}{
            "id":           "https://misskey.io/notes/9abcdef123456789",
            "type":         "Note",
            "attributedTo": "https://misskey.io/users/9uvwxyz987654321",
            "content":      "Hello from Misskey! 🎉",
            "_misskey_quote": "https://misskey.io/notes/9fedcba987654321",
            "_misskey_reaction": map[string]interface{}{
                "👍": 5,
                "❤️": 3,
            },
        },
    }

    processor := NewActivityProcessor()
    
    activityJSON, err := json.Marshal(misskeyNote)
    require.NoError(t, err)

    result, err := processor.ProcessInboxActivity(activityJSON)
    assert.NoError(t, err)
    assert.True(t, result.Accepted)
    
    // Verify Misskey-specific fields are preserved
    assert.Contains(t, result.ProcessedActivity, "_misskey_quote")
}

func TestPleromaCompatibility(t *testing.T) {
    pleromaActivity := map[string]interface{}{
        "@context": []interface{}{
            "https://www.w3.org/ns/activitystreams",
            "https://pleroma.social/schemas/litepub-0.1.jsonld",
        },
        "id":     "https://pleroma.example/activities/123",
        "type":   "Create",
        "actor":  "https://pleroma.example/users/alice",
        "object": map[string]interface{}{
            "id":           "https://pleroma.example/objects/456",
            "type":         "Note",
            "content":      "Hello from Pleroma!",
            "emoji":        map[string]string{
                ":custom_emoji:": "https://pleroma.example/emoji/custom.png",
            },
            "pleroma": map[string]interface{}{
                "expires_at":       "2024-12-31T23:59:59Z",
                "local":           false,
                "conversation_id": 789,
            },
        },
    }

    processor := NewActivityProcessor()
    
    activityJSON, err := json.Marshal(pleromaActivity)
    require.NoError(t, err)

    result, err := processor.ProcessInboxActivity(activityJSON)
    assert.NoError(t, err)
    assert.True(t, result.Accepted)
}
```

#### 5. Delivery Queue and Retry Logic Testing

Robust testing of outbox delivery and retry mechanisms is crucial for reliable federation.

```go
package delivery_test

import (
    "context"
    "net/http"
    "net/http/httptest"
    "sync/atomic"
    "testing"
    "time"

    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestDeliveryQueueProcessing(t *testing.T) {
    tests := []struct {
        name                string
        queueSize          int
        concurrentWorkers  int
        expectedDeliveries int
        serverDelay        time.Duration
    }{
        {
            name:               "small queue fast processing",
            queueSize:          10,
            concurrentWorkers:  2,
            expectedDeliveries: 10,
            serverDelay:        10 * time.Millisecond,
        },
        {
            name:               "large queue parallel processing",
            queueSize:          100,
            concurrentWorkers:  5,
            expectedDeliveries: 100,
            serverDelay:        5 * time.Millisecond,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            var deliveryCount int64

            // Mock inbox server
            server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
                time.Sleep(tt.serverDelay)
                atomic.AddInt64(&deliveryCount, 1)
                w.WriteHeader(http.StatusOK)
            }))
            defer server.Close()

            // Create delivery queue
            queue := NewDeliveryQueue(tt.concurrentWorkers)
            
            // Add tasks to queue
            for i := 0; i < tt.queueSize; i++ {
                task := &DeliveryTask{
                    ID:          fmt.Sprintf("task-%d", i),
                    InboxURL:    server.URL + "/inbox",
                    Activity:    `{"type":"Create","id":"test"}`,
                    ActorKeyID:  "https://our.instance.com/users/alice#main-key",
                    MaxRetries:  3,
                }
                queue.Enqueue(task)
            }

            // Process queue
            ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
            defer cancel()

            err := queue.ProcessAll(ctx)
            require.NoError(t, err)

            // Verify all deliveries completed
            assert.Equal(t, int64(tt.expectedDeliveries), atomic.LoadInt64(&deliveryCount))
        })
    }
}

func TestRetryLogicWithExponentialBackoff(t *testing.T) {
    tests := []struct {
        name           string
        failureCount   int
        maxRetries     int
        serverResponses []int
        expectedRetries int
        shouldSucceed  bool
    }{
        {
            name:           "succeed on second attempt",
            maxRetries:     3,
            serverResponses: []int{500, 200},
            expectedRetries: 2,
            shouldSucceed:  true,
        },
        {
            name:           "fail after max retries",
            maxRetries:     2,
            serverResponses: []int{500, 502, 503},
            expectedRetries: 2,
            shouldSucceed:  false,
        },
        {
            name:           "succeed immediately",
            maxRetries:     3,
            serverResponses: []int{200},
            expectedRetries: 1,
            shouldSucceed:  true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            attemptCount := 0
            var attemptTimes []time.Time

            server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
                attemptTimes = append(attemptTimes, time.Now())
                statusCode := tt.serverResponses[attemptCount]
                attemptCount++
                w.WriteHeader(statusCode)
            }))
            defer server.Close()

            retryPolicy := NewExponentialBackoffRetryPolicy()
            retryPolicy.SetBaseDelay(100 * time.Millisecond)
            retryPolicy.SetMaxDelay(1 * time.Second)
            retryPolicy.SetMultiplier(2.0)

            deliverer := NewActivityDeliverer()
            deliverer.SetRetryPolicy(retryPolicy)

            task := &DeliveryTask{
                ID:         "test-retry",
                InboxURL:   server.URL + "/inbox",
                Activity:   `{"type":"Create","id":"test"}`,
                ActorKeyID: "https://our.instance.com/users/alice#main-key",
                MaxRetries: tt.maxRetries,
            }

            ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
            defer cancel()

            result, err := deliverer.Deliver(ctx, task)

            assert.Equal(t, tt.expectedRetries, attemptCount)

            if tt.shouldSucceed {
                require.NoError(t, err)
                assert.True(t, result.Success)
            } else {
                assert.Error(t, err)
                assert.False(t, result.Success)
            }

            // Verify exponential backoff timing
            if len(attemptTimes) > 1 {
                for i := 1; i < len(attemptTimes); i++ {
                    delay := attemptTimes[i].Sub(attemptTimes[i-1])
                    expectedMinDelay := time.Duration(100*float64(i)) * time.Millisecond
                    assert.GreaterOrEqual(t, delay, expectedMinDelay)
                }
            }
        })
    }
}

func TestDomainBlockingAndCircuitBreaker(t *testing.T) {
    tests := []struct {
        name           string
        domain         string
        isBlocked      bool
        failureCount   int
        shouldAttempt  bool
        shouldTriggerCB bool
    }{
        {
            name:          "normal delivery to allowed domain",
            domain:        "mastodon.social",
            isBlocked:     false,
            failureCount:  0,
            shouldAttempt: true,
        },
        {
            name:          "blocked domain delivery",
            domain:        "spam.example.com",
            isBlocked:     true,
            shouldAttempt: false,
        },
        {
            name:            "circuit breaker triggers after failures",
            domain:          "unreliable.example.com",
            isBlocked:       false,
            failureCount:    5,
            shouldAttempt:   true,
            shouldTriggerCB: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            failureCounter := 0
            server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
                if failureCounter < tt.failureCount {
                    failureCounter++
                    w.WriteHeader(http.StatusInternalServerError)
                    return
                }
                w.WriteHeader(http.StatusOK)
            }))
            defer server.Close()

            domainBlocker := NewDomainBlocker()
            if tt.isBlocked {
                domainBlocker.BlockDomain(tt.domain)
            }

            circuitBreaker := NewCircuitBreaker()
            circuitBreaker.SetFailureThreshold(3)
            circuitBreaker.SetRecoveryTime(5 * time.Minute)

            deliverer := NewActivityDeliverer()
            deliverer.SetDomainBlocker(domainBlocker)
            deliverer.SetCircuitBreaker(circuitBreaker)

            task := &DeliveryTask{
                ID:         "test-blocking",
                InboxURL:   "https://" + tt.domain + "/inbox",
                Activity:   `{"type":"Create","id":"test"}`,
                ActorKeyID: "https://our.instance.com/users/alice#main-key",
                MaxRetries: 1,
            }

            ctx := context.Background()

            if !tt.shouldAttempt {
                _, err := deliverer.Deliver(ctx, task)
                assert.Error(t, err)
                assert.Contains(t, err.Error(), "domain blocked")
                return
            }

            // Simulate multiple failures to trigger circuit breaker
            for i := 0; i < tt.failureCount; i++ {
                deliverer.Deliver(ctx, task)
            }

            if tt.shouldTriggerCB {
                state := circuitBreaker.GetState(tt.domain)
                assert.Equal(t, "OPEN", state.Status)
            }
        })
    }
}
```

### Performance and Load Testing

#### Concurrent Delivery Testing

```go
func TestConcurrentDeliveryPerformance(t *testing.T) {
    const (
        numTasks = 1000
        numWorkers = 10
        maxLatency = 5 * time.Second
    )

    var completedTasks int64
    var totalLatency time.Duration

    server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Simulate processing time
        time.Sleep(10 * time.Millisecond)
        atomic.AddInt64(&completedTasks, 1)
        w.WriteHeader(http.StatusOK)
    }))
    defer server.Close()

    queue := NewDeliveryQueue(numWorkers)
    
    startTime := time.Now()

    // Enqueue tasks
    for i := 0; i < numTasks; i++ {
        task := &DeliveryTask{
            ID:         fmt.Sprintf("perf-test-%d", i),
            InboxURL:   server.URL + "/inbox",
            Activity:   `{"type":"Create","id":"test"}`,
            ActorKeyID: "https://our.instance.com/users/alice#main-key",
        }
        queue.Enqueue(task)
    }

    // Process all tasks
    ctx, cancel := context.WithTimeout(context.Background(), maxLatency)
    defer cancel()

    err := queue.ProcessAll(ctx)
    require.NoError(t, err)

    totalLatency = time.Since(startTime)

    // Assertions
    assert.Equal(t, int64(numTasks), atomic.LoadInt64(&completedTasks))
    assert.Less(t, totalLatency, maxLatency)
    
    // Calculate throughput
    throughput := float64(numTasks) / totalLatency.Seconds()
    t.Logf("Processed %d tasks in %v (%.2f tasks/sec)", numTasks, totalLatency, throughput)
    
    // Minimum expected throughput
    assert.Greater(t, throughput, float64(200)) // At least 200 tasks/sec
}
```

### Test Execution Guidelines

1. **Continuous Integration**: All tests must pass in CI/CD pipeline
2. **Test Data Isolation**: Use test databases and mock servers
3. **Coverage Requirements**: Minimum 95% coverage for federation logic
4. **Performance Benchmarks**: Regular performance regression testing
5. **Integration Testing**: Weekly tests against live ActivityPub instances (Mastodon test server)

### Mock Strategy

- **HTTP Signature Keys**: Generate ephemeral RSA keys for testing
- **Remote Servers**: Use httptest.Server for ActivityPub endpoint simulation
- **Time**: Use controllable time mocks for retry logic testing
- **Database**: Use transaction rollback for test isolation
- **Redis**: Use separate Redis database numbers for test isolation

## 16. Configuration Management

This service follows the unified configuration pattern defined in [Common Environment Variables](../common/infrastructure/environment-variables.md).

### Environment Variables

#### Required Variables
- `DATABASE_URL`: PostgreSQL connection string for ActivityPub data storage
- `REDIS_URL`: Redis connection string for outbox/inbox queues and caching
- `DOMAIN`: Federation domain name for this instance

#### Optional Variables (with defaults)
- `PORT`: HTTP server port (default: 8085)
- `GRPC_PORT`: gRPC server port (default: 9095)
- `FEDERATION_ENABLED`: Enable/disable federation (default: true)
- `INBOX_QUEUE_SIZE`: Maximum inbox queue size (default: 10000)
- `OUTBOX_QUEUE_SIZE`: Maximum outbox queue size (default: 10000)

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
    
    // データベース設定
    Database DatabaseConfig
    
    // Redis設定
    Redis RedisConfig
    
    // ActivityPub特有設定
    ActivityPub ActivityPubConfig
    
    // 監視設定
    Observability ObservabilityConfig
}

type ServerConfig struct {
    Port        int           `env:"PORT" required:"false" default:"8085"`
    GRPCPort    int           `env:"GRPC_PORT" required:"false" default:"9095"`
    Environment string        `env:"ENVIRONMENT" required:"false" default:"development"`
    LogLevel    string        `env:"LOG_LEVEL" required:"false" default:"info"`
    Timeout     time.Duration `env:"SERVER_TIMEOUT" required:"false" default:"30s"`
}

type DatabaseConfig struct {
    URL string `env:"DATABASE_URL" required:"true"`
}

type RedisConfig struct {
    URL      string `env:"REDIS_URL" required:"true"`
    Password string `env:"REDIS_PASSWORD" required:"false" secret:"true"`
    DB       int    `env:"REDIS_DB" required:"false" default:"0"`
}

type ActivityPubConfig struct {
    Domain               string `env:"DOMAIN" required:"true"`
    FederationEnabled    bool   `env:"FEDERATION_ENABLED" required:"false" default:"true"`
    InboxQueueSize       int    `env:"INBOX_QUEUE_SIZE" required:"false" default:"10000"`
    OutboxQueueSize      int    `env:"OUTBOX_QUEUE_SIZE" required:"false" default:"10000"`
    
    // 内部設定（デフォルト値のみ）
    SignatureValidation  bool          `env:"SIGNATURE_VALIDATION" required:"false" default:"true"`
    DeliveryTimeout      time.Duration `env:"DELIVERY_TIMEOUT" required:"false" default:"10s"`
    RetryMaxAttempts     int          `env:"RETRY_MAX_ATTEMPTS" required:"false" default:"3"`
    RetryBackoffInitial  time.Duration `env:"RETRY_BACKOFF_INITIAL" required:"false" default:"1s"`
}

type ObservabilityConfig struct {
    MetricsEnabled bool   `env:"METRICS_ENABLED" required:"false" default:"true"`
    TracingEnabled bool   `env:"TRACING_ENABLED" required:"false" default:"true"`
    LogFormat      string `env:"LOG_FORMAT" required:"false" default:"json"`
}
```

### Usage Example

```go
// cmd/server/main.go
func main() {
    // 環境変数の読み込み（必須環境変数が不足していればここで失敗）
    cfg := config.MustLoad()
    
    logger := initLogger(cfg.Server.LogLevel)
    
    logger.Info("Starting avion-activitypub server",
        "environment", cfg.Server.Environment,
        "port", cfg.Server.Port,
        "grpc_port", cfg.Server.GRPCPort,
        "domain", cfg.ActivityPub.Domain,
        "federation_enabled", cfg.ActivityPub.FederationEnabled,
    )
    
    // データベース接続の初期化
    db := initDatabase(cfg.Database)
    
    // Redis接続の初期化
    redis := initRedis(cfg.Redis)
    
    // ActivityPubサーバーの起動
    // ...
}
```

## 17. セキュリティ実装ガイドライン

本サービスのセキュリティ実装は、以下の共通セキュリティガイドラインに準拠します：

### 適用セキュリティガイドライン

#### XSS防止
[XSS防止ガイドライン](../common/security/xss-prevention.md)に従い、以下を実装：

- **連合コンテンツサニタイゼーション**:
  - リモート投稿（Note、Article等）のHTML/Markdownコンテンツの厳格なサニタイゼーション
  - カスタム絵文字・リアクション名のエスケープ処理
  - Actor プロフィール（bio、displayName）のサニタイゼーション
  - メディア添付のaltテキスト・説明文のエスケープ

- **JSON-LD処理**:
  - ActivityPub JSON-LDコンテンツの安全な解析
  - 不正なスクリプトタグの除去
  - Content-Typeヘッダーの厳格な検証

#### SQLインジェクション防止
[SQLインジェクション防止ガイドライン](../common/security/sql-injection-prevention.md)に従い、以下を実装：

- **パラメータバインディング**:
  - WebFinger検索での`resource`パラメータのバインディング
  - Actor検索クエリでのプリペアドステートメント使用
  - アクティビティフィルタリングでの安全なクエリ構築
  - 統計情報取得での集計クエリのパラメータ化

#### TLS設定
[TLS設定ガイドライン](../common/security/tls-configuration.md)に従い、以下を実装：

- **連合通信のTLS設定**:
  - リモートサーバーとの通信でTLS 1.2以上を強制
  - 証明書チェーンの完全な検証
  - 自己署名証明書の拒否（開発環境を除く）
  - 重要インスタンスでの証明書ピンニング実装

- **HTTP Signatures送信**:
  - TLS 1.3の優先使用
  - 強力な暗号スイートの選択
  - セッション再利用による性能最適化

#### セキュリティヘッダー
[セキュリティヘッダーガイドライン](../common/security/security-headers.md)に従い、以下を実装：

- **ActivityPub エンドポイント**:
  - CSP: `default-src 'none'; frame-ancestors 'none'`（JSON-LD専用）
  - X-Content-Type-Options: `nosniff`
  - X-Frame-Options: `DENY`
  - Referrer-Policy: `same-origin`

- **WebFinger エンドポイント**:
  - CORS設定: 必要最小限のオリジン許可
  - Access-Control-Allow-Methods: `GET, OPTIONS`
  - Access-Control-Max-Age: 適切なキャッシュ期間

### 実装チェックリスト

- [ ] 全ての外部入力に対するサニタイゼーション実装
- [ ] SQL クエリでのプリペアドステートメント使用
- [ ] TLS 証明書検証の実装とテスト
- [ ] セキュリティヘッダーの設定と検証
- [ ] HTTP Signatures の署名・検証処理
- [ ] レート制限の実装（インバウンド・アウトバウンド）
- [ ] 監査ログの実装（セキュリティイベント記録）

---

**Note**: このドキュメントは実装進行に伴い継続的に更新されます。技術的な意思決定や仕様変更があった場合は、適切にバージョン管理し、関係者に共有してください。
