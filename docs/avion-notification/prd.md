# PRD: avion-notification

## 概要

Avionにおけるユーザーへの通知（メンション、フォロー、リアクション、リポストなど）を生成、管理、および配信する機能を提供するマイクロサービスを実装する。Server-Sent Events (SSE)によるリアルタイム配信、Web Push通知、メール通知などの多様な配信チャネルを統合し、ユーザーエンゲージメント向上とタイムリーな情報伝達を実現する。

## 背景

SNSにおいて、ユーザーが自身に関連する重要なイベント（誰かにフォローされた、自分の投稿にリアクションが付いた、メンションされたなど）を適時に知ることは、エンゲージメントを維持し、コミュニケーションを促進する上で不可欠である。これらの通知イベントを集約し、ユーザーごとに管理・配信する専門のマイクロサービスを設けることで、通知ロジックを他のサービスから分離し、効率的な通知システムを構築する。

## Scientific Merits

*   **ユーザーエンゲージメント向上**: リアルタイム通知により日間アクティブユーザー（DAU）を15%向上、平均セッション時間を20%延長することを目標とする。通知開封率98%以上、通知からのアクション率25%以上を維持。
*   **高速配信保証**: SSE通知配信レイテンシp50 < 100ms、p99 < 500msを実現。Web Push通知送信成功率95%以上、メール通知到達率98%以上を保証。
*   **スケーラブル処理**: 毎秒10,000件の通知生成、同時SSE接続10,000セッションの処理能力。イベント処理遅延を平均2秒以内に維持。
*   **マルチチャネル配信**: SSE、Web Push、メール通知の統合配信により、通知到達率99%以上を実現。配信失敗時の自動リトライによる配信保証。
*   **関心の分離**: 通知生成ロジックの中央集約により、他サービスの開発速度を30%向上。通知関連のコード変更箇所を90%削減。
*   **運用効率**: OpenTelemetryによる包括的監視、自動アラート、セルフヒーリング機能により運用コストを40%削減。
*   **データドリブン最適化**: 通知効果測定、A/Bテスト基盤により、通知効果を継続的に改善。ユーザー離脱率を15%削減。

通知はユーザー体験の質に直接影響する重要な機能であり、その生成と配信を効率的かつ確実に行うための専門サービスは高い価値を提供する。

## Design Doc

[Design Doc: avion-notification](./designdoc.md)

## 参考ドキュメント

*   [Avion アーキテクチャ概要](./../common/architecture.md)

## 製品原則

*   **関連性の高い通知:** ユーザーにとって意味のある、自身に関連するイベントのみを通知する。
*   **タイムリーな配信:** イベント発生から可能な限り短い遅延で通知を届ける。
*   **明確な情報:** 何に関する通知なのか（誰が何をしたか）を分かりやすく伝える。
*   **管理可能な通知:** ユーザーが通知を確認し、既読状態を管理できるようにする。

## やること/やらないこと

### やること

*   各種イベント（フォローされた、メンションされた、自分のDropにリアクションされた、自分のDropがリポストされた、引用リポストされた、投票された、投票が終了した、フォローリクエストを受信した、フォローリクエストが承認された、自分が関与したDropが更新されたなど）に基づく通知データの生成。
*   特定ユーザーの投稿通知（通知を有効にしたユーザーが新規投稿した際の通知）。
*   生成された通知の永続化 (ユーザーごと)。
*   ユーザー向けの通知リスト取得APIの提供 (未読・既読、ページネーション付き)。
*   通知の既読状態管理 (個別既読、一括既読)。
*   未読通知件数の取得APIの提供。
*   Server-Sent Events (SSE) によるリアルタイム通知配信 (例: 新しい通知があることをクライアントに伝える)。
*   Web Pushによるプッシュ通知連携 (PWAを前提)。
*   通知設定 (どの種類の通知を受け取るか、特定ユーザーの投稿通知の有効/無効)。
*   管理者向け通知 (新規ユーザー登録、通報受信など)。
*   モデレーション関連通知（モデレーターからの警告、関係切断通知）。
*   サーバーアナウンス配信機能。
*   通知のグループ化（大量の同種通知を集約表示）。
*   通知フィルタリング機能
    - 通知種別ごとの有効/無効設定
    - フォロワーのみ通知オプション
    - キーワードベースフィルタ
    - 静音モード（時間帯指定）
*   重要イベントのメール通知（将来拡張）
    - フォローリクエスト、アカウント関連イベント
    - ダイジェストメール（週次・月次）
    - メール頻度設定
    - メール通知のオプトアウト

### やらないこと

*   **イベント発生元のビジネスロジック:** フォロー処理自体 (`avion-user`) やリアクション処理自体 (`avion-reaction`) は担当しない。イベントを受け取って通知を生成するのみ。
*   **通知内容の完全な詳細データ保持:** 通知にはイベントの概要と関連エンティティへの参照 (ユーザーID, Drop IDなど) を含めるが、Drop本文全文などを複製して保持することは避ける (必要に応じて関連サービスに問い合わせる)。
*   **通知の優先度付け (初期):** 全ての通知を同等に扱う。将来的に重要度レベルの実装を検討。
*   **高頻度イベントのメール通知:** リアクション、リポストなどの頻繁に発生するイベントのメール通知は避ける。
*   **リアルタイムイベントのメール送信:** メール送信はバッチ処理または別サービスでの実装を推奨。

## ドメインモデル (DDD戦術的パターン)

### Aggregates (集約)

#### Notification Aggregate
**責務**: ユーザーへの通知を管理する中核的な集約
- **集約ルート**: Notification
- **不変条件**:
  - RecipientUserIDは変更不可
  - NotificationTypeは作成後変更不可
  - ReadStatusは未読から既読への一方向のみ変更可能
  - 既読化日時は既読化時点で自動設定
  - 削除は既読かつ30日以上経過した通知のみ可能
- **ドメインロジック**:
  - `markAsRead()`: 既読化処理（冪等性あり）
  - `canBeDeleted()`: 削除可否判定
  - `shouldNotify()`: 通知すべきかの判定（NotificationPreferenceを考慮）
  - `toSSEEvent()`: SSE配信用イベントへの変換
  - `toWebPushPayload()`: Web Push用ペイロードへの変換

#### WebPushSubscription Aggregate
**責務**: Web Pushサブスクリプションを管理
- **集約ルート**: WebPushSubscription
- **不変条件**:
  - 同一エンドポイントのサブスクリプションは1つのみ
  - 無効なサブスクリプションは自動的に削除
  - VAPIDキーは環境変数から取得（集約内では保持しない）
- **ドメインロジック**:
  - `isValid()`: サブスクリプションの有効性検証
  - `shouldSendPush()`: プッシュ送信可否判定
  - `encrypt(payload)`: ペイロードの暗号化（RFC 8291準拠）
  - `handleDeliveryFailure()`: 配信失敗時の処理

#### NotificationEvent Aggregate
**責務**: 通知イベント処理を管理
- **集約ルート**: NotificationEvent
- **不変条件**:
  - EventIDは一意（冪等性保証）
  - 同一EventIDの重複処理は拒否
  - イベント処理は成功/失敗の二値
- **ドメインロジック**:
  - `shouldProcess()`: 処理すべきイベントかの判定
  - `toNotification()`: Notification Aggregateへの変換
  - `extractRecipients()`: 通知対象ユーザーの抽出

#### NotificationPreference Aggregate
**責務**: ユーザーごとの通知設定を管理
- **集約ルート**: NotificationPreference
- **不変条件**:
  - UserIDごとに1つのみ存在
  - デフォルト設定は全通知有効
  - 無効な設定値は拒否
- **ドメインロジック**:
  - `shouldNotify(type, source)`: 通知可否判定
  - `applyFilter(notification)`: フィルタリング適用
  - `updateSettings()`: 設定更新（バリデーション含む）
  - `hasMutedKeyword()`: キーワードミュート判定
  - `validate()`: イベントデータの妥当性検証

#### SSEConnectionManager Aggregate
**責務**: SSE接続のライフサイクル管理
- **集約ルート**: SSEConnectionManager
- **不変条件**:
  - 同一ユーザーの複数接続を許可（マルチデバイス対応）
  - タイムアウトした接続は自動的にクローズ
  - 接続数には上限を設定（DoS対策）
- **ドメインロジック**:
  - `establishConnection()`: 新規接続の確立
  - `heartbeat()`: 接続の生存確認
  - `broadcast()`: 特定ユーザーへのイベント配信
  - `cleanup()`: タイムアウト接続の削除

### Entities (エンティティ)

#### NotificationPreference
**所属**: Notification Aggregate
**責務**: ユーザーの通知設定を管理
- **属性**:
  - PreferenceID（Entity識別子）
  - NotificationType（通知種別）
  - IsEnabled（有効/無効フラグ）
  - DeliveryChannels（配信チャネルのリスト）
  - UpdatedAt（最終更新日時）
- **ビジネスルール**:
  - システム通知は無効化不可
  - デフォルトは全通知有効

#### SSEConnection
**所属**: SSEConnectionManager Aggregate
**責務**: アクティブなSSE接続情報を保持
- **属性**:
  - ConnectionID（Entity識別子）
  - UserID（接続ユーザー）
  - EstablishedAt（接続確立時刻）
  - LastHeartbeatAt（最終生存確認時刻）
  - UserAgent（クライアント情報）
  - IPAddress（接続元IP）
- **ビジネスルール**:
  - 30秒以上heartbeatがない接続は無効
  - 同一IPからの接続数制限（10接続まで）

#### WebPushCredential
**所属**: WebPushSubscription Aggregate
**責務**: Web Push認証情報を管理
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

#### NotificationGroup
**所属**: Notification Aggregate
**責務**: 通知のグルーピング情報を管理
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

#### UserNotificationPreference
**所属**: Notification Aggregate
**責務**: 特定ユーザーに対する通知設定を管理
- **属性**:
  - PreferenceID（Entity識別子）
  - TargetUserID（通知対象ユーザー）
  - IsEnabled（投稿通知の有効/無効）
  - CreatedAt（設定作成日時）
  - UpdatedAt（最終更新日時）
- **ビジネスルール**:
  - 同一ターゲットユーザーへの設定は1つのみ
  - ブロック中のユーザーへの通知設定は無効

#### Announcement
**所属**: 独立したAggregate
**責務**: サーバーアナウンスを管理
- **属性**:
  - AnnouncementID（Entity識別子）
  - Title（アナウンスタイトル）
  - Content（アナウンス内容）
  - TargetUsers（対象ユーザーリスト、nullで全員）
  - IsActive（有効/無効フラグ）
  - StartAt（配信開始日時）
  - EndAt（配信終了日時）
  - CreatedBy（作成管理者ID）
- **ビジネスルール**:
  - 期間外のアナウンスは配信されない
  - 既読管理は通知と同様

### Value Objects (値オブジェクト)

**識別子関連**
- **NotificationID**: 通知の一意識別子（UUID v4）
- **EventID**: イベントの一意識別子（冪等性保証用、Snowflake ID）
- **RecipientUserID**: 通知受信者のユーザーID
- **ActorUserID**: アクション実行者のユーザーID（システム通知の場合はnull）
- **TargetDropID**: 関連するDropのID（Drop関連通知の場合）
- **TargetUserID**: 関連するユーザーのID（フォロー通知等の場合）
- **UserID**: 汎用的なユーザーID
- **ConnectionID**: SSE接続の一意識別子
- **SubscriptionID**: Web Pushサブスクリプションの一意識別子

**通知属性**
- **NotificationType**: 通知種別を表す列挙型
  - `follow`: フォロー通知
  - `mention`: メンション通知
  - `reaction`: リアクション通知
  - `repost`: リポスト通知
  - `quote_repost`: 引用リポスト通知
  - `reply`: 返信通知
  - `poll_vote`: 投票通知
  - `poll_end`: 投票終了通知
  - `follow_request`: フォローリクエスト通知
  - `follow_request_accepted`: フォローリクエスト承認通知
  - `drop_updated`: 投稿更新通知
  - `status`: 特定ユーザーの新規投稿通知
  - `system`: システム通知
  - `admin_user_registered`: 管理者向け新規ユーザー登録通知
  - `admin_report_created`: 管理者向け通報受信通知
  - `moderation_warning`: モデレーション警告通知
  - `severed_relationships`: 関係切断通知
  - `announcement`: アナウンス通知
- **EventType**: イベント種別を表す列挙型
  - `follow_created`, `mention_created`, `reaction_created`, `repost_created`, `quote_repost_created`, `reply_created`
  - `poll_voted`, `poll_ended`
  - `follow_request_created`, `follow_request_accepted`
  - `drop_updated`, `drop_created`
  - `user_registered`, `report_created`
  - `moderation_action_taken`, `relationships_severed`
  - `announcement_published`
- **ReadStatus**: 既読/未読状態（boolean with timestamp）
- **NotificationData**: 通知の詳細情報（JSON形式、最大1KB）
  - リアクションの場合: emoji_code
  - メンションの場合: drop_preview（最初の100文字）
  - 引用リポストの場合: quote_text（引用テキスト）
  - 投票の場合: poll_option（選択された選択肢）
  - 投票終了の場合: poll_results（投票結果サマリー）
  - 投稿更新の場合: update_summary（更新内容の要約）
- **EventData**: イベントの生データ（処理前の情報）

**Web Push関連**
- **WebPushEndpoint**: プッシュサービスのエンドポイントURL
- **WebPushKeys**: p256dhとauthキーのペア（暗号化用）
- **VAPIDKeys**: アプリケーションサーバーの公開鍵/秘密鍵ペア
- **PushPayload**: 暗号化されたプッシュ通知ペイロード（最大4KB）
- **BrowserInfo**: ブラウザ種別とバージョン情報

**SSE関連**
- **SSEConnectionID**: SSE接続の識別子（UUID）
- **SSEEvent**: SSEで送信するイベント構造体
  - event: イベント名（"notification", "heartbeat"）
  - data: JSON形式のデータ
  - id: イベントID（再接続時の継続用）
- **SSEConnectionStatus**: 接続状態（connected, disconnected, error）

**数値・時刻**
- **UnreadCount**: 未読通知件数（0以上の整数）
- **CreatedAt**: 作成日時（UTC）
- **ProcessedAt**: 処理完了日時（UTC）
- **ReadAt**: 既読化日時（UTC）
- **ExpiresAt**: 有効期限（古い通知の削除用）

### Domain Services

#### NotificationChannelSelector
**責務**: ユーザー設定と通知特性に基づく最適な配信チャネルの選択と優先順位付け
- **メソッド**:
  - `selectChannels(notification, userPreference)`: 通知とユーザー設定から配信チャネルを決定
  - `calculatePriority(notificationType, userContext)`: 通知種別とユーザーコンテキストから配信優先度を算出
  - `shouldFallback(channel, failureHistory)`: 配信失敗履歴から代替チャネルへのフォールバックを判定

#### NotificationRetryStrategy
**責務**: 配信失敗時のリトライ戦略の決定と実行制御
- **メソッド**:
  - `calculateNextRetry(attemptCount, notificationType)`: 次回リトライタイミングを指数バックオフで算出
  - `shouldRetry(deliveryResult, notification)`: 配信結果から再試行すべきかを判定
  - `markAsExpired(notification)`: 配信期限切れ通知の状態更新とクリーンアップ

#### NotificationGroupingService
**責務**: 類似通知のグループ化による表示最適化とスパム防止
- **メソッド**:
  - `shouldGroup(newNotification, existingNotifications)`: 新規通知の既存グループへの結合可否判定
  - `createGroup(notifications, groupType)`: 通知グループの生成と管理情報設定
  - `updateGroupSummary(group)`: グループサマリーの動的更新（アクター数、最新情報）

#### NotificationContentEnrichment
**責務**: 通知表示に必要な外部データの取得と組み立て
- **メソッド**:
  - `enrichWithUserData(notifications)`: ユーザー情報（名前、アバター等）の付与
  - `enrichWithDropData(notifications)`: Drop詳細情報の取得と要約生成
  - `generatePreviewText(notification)`: 通知プレビューテキストの生成（多言語対応）

#### NotificationPermissionService
**責務**: 通知配信権限の検証とプライバシー保護制御
- **メソッド**:
  - `canNotify(actorUser, recipientUser, notificationType)`: 通知送信権限の総合判定
  - `applyPrivacyFilters(notifications, recipientUser)`: ブロック・ミュート設定による通知フィルタリング
  - `validateDeliveryPermission(channel, user)`: 配信チャネルごとの権限検証

## 対象ユーザ

*   **Avion エンドユーザー**: API Gateway経由でWeb/モバイルアプリから通知の受信・管理を行う
*   **Avion マイクロサービス**: イベント発行元として通知をトリガーする（avion-user、avion-drop、avion-activitypub、avion-moderation等）
*   **システム管理者**: 通知システムの運用監視、アナウンス配信、通知設定の管理を担当
*   **開発者**: 通知APIの利用、新しい通知タイプの実装、デバッグ・テストを実施

## ユースケース

### 通知リストの表示

1.  ユーザーが通知タブ/ページを開く
2.  フロントエンドは `avion-gateway` 経由で `avion-notification` に通知リスト取得リクエストを送信
3.  GetNotificationsQueryUseCase がリクエストを処理
4.  NotificationPreferenceRepository から ユーザーの通知設定を取得
5.  NotificationQueryService 経由で RecipientUserID の Notification を取得
6.  NotificationPreference.applyFilter() で通知フィルタリングを適用
7.  AccessControlService でユーザーの権限を確認（ブロックユーザーからの通知を除外）
8.  NotificationGroupingService で同種の通知をグループ化
9.  NotificationEnrichmentService で ActorUser、TargetDrop の詳細情報を取得
10. NotificationDTO のリストを生成して返却
11. フロントエンドは ReadStatus に基づいて未読/既読を区別表示

(UIモック: 通知一覧画面 - 未読は背景色で強調、既読は通常表示)

### 未読通知件数の表示

1.  フロントエンドはアプリケーションのヘッダーに未読通知件数を表示
2.  `avion-gateway` 経由で `avion-notification` に未読通知件数取得リクエストを送信
3.  GetUnreadCountQueryUseCase がリクエストを処理
4.  NotificationQueryService で RecipientUserID かつ ReadStatus=false をカウント
5.  UnreadCountCache を確認し、キャッシュヒットなら即座に返却
6.  キャッシュミスの場合、DB から集計して UnreadCount Value Object を生成
7.  キャッシュを更新（TTL: 1分）
8.  フロントエンドは UnreadCount をバッジ表示（99+ で表示）

(UIモック: ヘッダーの通知アイコンとバッジ - 未読がある場合は赤いバッジ)

### 通知の既読化

1.  ユーザーが通知リストを開く、または特定の通知をクリック
2.  フロントエンドは `avion-gateway` 経由で既読化リクエストを送信
3.  MarkAsReadCommandUseCase がリクエストを処理
4.  NotificationRepository から NotificationID で Notification Aggregate を取得
5.  Notification Aggregate の markAsRead() メソッドを呼び出し（冪等性あり）
6.  ReadStatus と ReadAt を更新して Repository 経由で永続化
7.  NotificationEventPublisher で `notification_read` イベントを発行
8.  UnreadCountCache を無効化

### イベント発生と通知生成 (例: リアクション)

1.  ユーザーBがユーザーAのDropにリアクション (`avion-drop` が処理)
2.  `avion-drop` が EventType='reaction_created' の DomainEvent を Redis Stream に発行
3.  NotificationEventHandler が Redis Stream から Consumer Group 経由でイベントを取得
4.  ProcessNotificationEventCommandUseCase がイベントを処理
5.  EventRepository で EventID の冪等性チェック（処理済みなら Skip）
6.  NotificationFactory (Domain Service) で NotificationEvent から Notification を生成
7.  NotificationPreferenceService で受信者の通知設定を確認
8.  通知が有効な場合、Notification Aggregate を生成して永続化
9.  SSEBroadcaster で該当ユーザーの全接続に SSEEvent を配信
10. WebPushService で購読中のデバイスに Push 通知を送信

### 投票関連の通知生成

1.  ユーザーBがユーザーAの投票に参加 (`avion-drop` が処理)
2.  `avion-drop` が EventType='poll_voted' の DomainEvent を Redis Stream に発行
3.  NotificationEventHandler がイベントを処理（上記と同様のフロー）
4.  投票作成者（ユーザーA）に通知を生成

### フォローリクエスト通知生成

1.  ユーザーBが非公開アカウントのユーザーAをフォローリクエスト (`avion-user` が処理)
2.  `avion-user` が EventType='follow_request_created' の DomainEvent を発行
3.  NotificationEventHandler がイベントを処理
4.  非公開アカウントユーザーAに通知を生成

### 投稿更新通知生成

1.  ユーザーAが自分のDropを編集 (`avion-drop` が処理)
2.  `avion-drop` が EventType='drop_updated' の DomainEvent を発行
3.  NotificationEventHandler がイベントを処理
4.  該当Dropにリアクション、リポスト、返信したユーザーを特定
5.  影響を受けるユーザー全員に通知を生成（バッチ処理）

### SSE 接続の確立と管理

1.  フロントエンドが `/api/events` エンドポイントに接続
2.  EstablishSSEConnectionCommandUseCase が新規接続を処理
3.  SSEConnectionManager Aggregate で接続数制限をチェック
4.  新規 SSEConnection Entity を生成（ConnectionID、UserID、EstablishedAt）
5.  SSEConnectionRepository に接続情報を保存
6.  定期的に heartbeat イベントを送信（15秒間隔）
7.  クライアントからの切断または timeout で接続をクリーンアップ

### Web Push サブスクリプション登録

1.  ユーザーがプッシュ通知を許可
2.  フロントエンドが Push API でサブスクリプション情報を取得
3.  SubscribeWebPushCommandUseCase がサブスクリプションを処理
4.  WebPushSubscription Aggregate を生成（エンドポイントの一意性を検証）
5.  WebPushCredential Entity に p256dh、auth キーを保存
6.  VAPIDKeyService から公開鍵を取得してクライアントに返却
7.  以降の通知で Web Push 配信が有効化

### 特定ユーザーの投稿通知設定

1.  ユーザーAがユーザーBのプロフィールページで「投稿を通知」を有効化
2.  `avion-gateway` 経由で通知設定更新リクエストを送信
3.  UpdateUserNotificationPreferenceCommandUseCase がリクエストを処理
4.  UserNotificationPreference Entity を生成または更新
5.  以降、ユーザーBが新規投稿した際にユーザーAに通知

### モデレーション関連通知

1.  モデレーターがユーザーに対して警告アクションを実行
2.  `avion-admin` が EventType='moderation_action_taken' のイベントを発行
3.  NotificationEventHandler がイベントを処理
4.  対象ユーザーに moderation_warning 通知を生成
5.  通知内容に警告理由と対処方法を含める

### 通知設定の更新

1.  ユーザーが通知設定画面を開く
2.  通知種別ごとの有効/無効を切り替え
3.  UpdateNotificationPreferenceCommandUseCase がリクエストを処理
4.  NotificationPreference Aggregate を更新
5.  フィルタリングルール（キーワード、フォロワーのみ等）を設定
6.  静音モード（時間帯指定）を設定
7.  設定は即座に反映され、以降の通知生成時に適用

(UIモック: 通知設定画面)

### メール通知の配信（将来拡張）

1.  重要イベント（フォローリクエスト等）が発生
2.  NotificationEventHandler が通知を生成
3.  EmailNotificationService がメール送信対象かチェック
4.  ユーザーのメール通知設定を確認
5.  メールテンプレートを生成
6.  EmailQueueService でメール送信をキューイング
7.  バッチ処理でメール送信（外部メールサービス連携）
8.  配信失敗時はリトライ処理

### サーバーアナウンス配信

1.  管理者がアナウンスを作成（全体向けまたは特定ユーザー向け）
2.  PublishAnnouncementCommandUseCase がアナウンスを処理
3.  Announcement Aggregate を生成（期間、対象ユーザー設定）
4.  対象ユーザー全員に announcement 通知を生成
5.  SSE/Web Push で即座に配信

### 通知のグループ化

1.  短時間に同一投稿への大量のリアクション/リポストが発生
2.  ProcessNotificationEventCommandUseCase が既存のグループを確認
3.  NotificationGroup Entity が存在する場合、グループに追加
4.  グループが存在しない場合、新規グループを作成
5.  フロントエンドには「○人がリアクションしました」形式で表示

## 機能要求

### ドメインロジック要求

*   **通知生成**: 17種類の通知タイプに対応し、各通知の優先度・配信チャネル・グループ化ルールを適切に適用すること
*   **配信制御**: ユーザー設定、プライバシー制御、スパム防止機能を統合した配信可否判定ロジック
*   **リアルタイム配信**: SSE接続管理、heartbeat制御、複数デバイス対応による即座の通知配信
*   **耐障害性**: イベント重複処理防止、配信失敗時の自動リトライ、グレースフルデグラデーション
*   **データ整合性**: 通知の冪等性保証、既読状態の一貫性維持、削除されたエンティティ参照の適切な処理

### APIエンドポイント要求

*   **GraphQL/REST API**: 通知CRUD操作、リアルタイム購読、バッチ操作をサポートするハイブリッドAPI
*   **認証・認可**: JWT-based認証、ユーザーごとの通知アクセス制御、管理者権限の階層管理
*   **ページネーション**: カーソルベースページネーション（100件/ページ上限）、フィルタリング、ソート機能
*   **レート制限**: ユーザーあたり1000req/min、管理者10000req/min、DDoS攻撃対策を含む
*   **エラーハンドリング**: 標準化されたエラーレスポンス、詳細なエラーコード、国際化対応メッセージ

### データ要求

*   **通知データ**: JSON形式（最大4KB）、必須フィールド検証、スキーマバージョニング対応
*   **設定データ**: ユーザー設定の階層化、デフォルト値管理、一括更新・エクスポート機能
*   **履歴データ**: 90日間の通知保持、段階的アーカイブ、GDPR対応の完全削除機能
*   **メタデータ**: パフォーマンス測定、配信結果追跡、A/Bテスト用の拡張属性管理

## 技術的要求

### レイテンシ

*   **通知リスト取得**: 平均150ms以下、p99 500ms以下（キャッシュヒット時50ms以下）
*   **未読件数取得**: 平均30ms以下、p99 100ms以下（Redis Cache活用）
*   **既読化処理**: 平均80ms以下、p99 200ms以下（バッチ既読は500ms以下）
*   **SSE通知配信**: 平均100ms以下、p99 500ms以下（イベント受信から配信完了まで）
*   **Web Push送信**: 平均2秒以下、p99 10秒以下（外部Push service依存）
*   **イベント処理**: 平均2秒以下、p99 5秒以下（イベント受信から通知生成・永続化完了まで）
*   **通知グループ化**: 平均500ms以下（複雑なグルーピングロジック含む）

### 可用性

*   **目標可用性**: 99.9%（年間停止時間8.76時間以下）
*   **Kubernetes構成**: 最小3レプリカ、ローリングアップデート対応、自動スケーリング（HPA/VPA）
*   **ヘルスチェック**: /health、/ready エンドポイント、依存サービス監視、自動復旧機能
*   **障害対応**: サーキットブレーカー、フォールバック機能、グレースフルシャットダウン（30秒）
*   **データ冗長性**: プライマリ・レプリカDB構成、自動フェイルオーバー、バックアップ自動実行（日次・週次）
*   **監視・アラート**: Prometheus/Grafana による監視、PagerDuty連携、SLA違反時の自動エスカレーション

### スケーラビリティ

*   **処理能力**: 毎秒10,000通知生成、同時SSE接続10,000セッション、Web Push送信5,000件/秒
*   **データベース**: 読み取りレプリカによる負荷分散、パーティショニング（ユーザーID、作成日時）、インデックス最適化
*   **水平スケーリング**: イベント処理ワーカーの動的スケーリング、Redis Cluster、メッセージキューのパーティション分散
*   **キャッシュ戦略**: L1キャッシュ（メモリ）、L2キャッシュ（Redis）、CDN活用による静的コンテンツ配信
*   **リソース管理**: CPU使用率70%、メモリ使用率80%をトリガーとした自動スケーリング
*   **負荷テスト**: 想定負荷の3倍まで定期的な負荷テスト実施、ボトルネック特定と改善

### セキュリティ

*   **入力検証**: 全API入力のサニタイゼーション、SQLインジェクション対策、XSS防止
*   **アクセス制御**: JWT認証、ロールベースアクセス制御（RBAC）、API Key管理
*   **データ保護**: 通知内容のTLS暗号化、機密情報のマスキング、PII（個人識別情報）の最小化
*   **監査ログ**: 全API呼び出し、設定変更、管理操作の監査ログ記録、改ざん検知
*   **コンプライアンス**: GDPR準拠、データ削除要求対応、プライバシーポリシー遵守

### データ整合性

*   **トランザクション管理**: ACID特性保証、分散トランザクション（Saga Pattern）、補償処理実装
*   **イベント冪等性**: EventIDによる重複検知、処理済みイベントのスキップ、リトライ安全性確保
*   **参照整合性**: 外部キー制約、削除ユーザー・Drop参照の自動クリーンアップ、依存データの整合性チェック
*   **結果整合性**: 非同期処理での最終一貫性保証、競合状態の検知と解決、データ修復機能
*   **バックアップ・復旧**: 毎日のフルバックアップ、ポイントインタイムリカバリ、災害復旧計画（RTO: 1時間、RPO: 15分）

### その他技術要件

*   **ステートレス設計**: 完全ステートレスサービス、セッション情報の外部化（Redis）、12-Factor App準拠
*   **可観測性**: OpenTelemetry完全統合、分散トレーシング、構造化ログ、カスタムメトリクス、SLI/SLO監視
*   **設定管理**: 環境別設定、機密情報の安全な管理（Vault/K8s Secrets）、設定変更の無停止適用
*   **外部依存**: 外部サービス（Push providers、SMTP）のSLA管理、フォールバック機能、依存関係の監視
*   **テスト**: ユニットテスト90%以上、統合テスト、E2Eテスト、カオスエンジニアリング、パフォーマンステスト
    
    テスト実装については[共通テスト戦略](../common/testing-strategy.md)を参照。

## 決まっていないこと

*   **メール通知の詳細設計**: メールテンプレートの国際化、送信頻度制御、ダイジェスト機能の実装方法
*   **通知優先度アルゴリズム**: ユーザーのアクティビティパターン、関係性、コンテンツ種別に基づく動的優先度付け
*   **AIフィルタリング**: スパム通知、不適切なコンテンツの自動検知とフィルタリング機能の導入
*   **パーソナライズド通知**: ユーザーの行動履歴、趣向、ソーシャルグラフに基づく通知のカスタマイズ
*   **クロスプラットフォーム連携**: モバイルアプリ、デスクトップ通知、スマートウォッチ連携の詳細仕様
*   **A/Bテスト基盤**: 通知コンテンツ、配信タイミング、チャネル選択の実験フレームワーク
*   **リーガルコンプライアンス**: 地域別のデータ保護法、プライバシー法への対応方法
*   **コスト最適化**: 外部Pushサービス料金、メール送信コスト、ストレージコストの最適化戦略
