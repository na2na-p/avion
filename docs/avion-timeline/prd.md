# PRD: avion-timeline

## 概要

Avionにおける7種類のタイムライン（HOME、LOCAL、GLOBAL、SOCIAL、LIST、HASHTAG、MEDIA）の生成および取得機能を提供するマイクロサービスを実装する。リアルタイム更新（SSE）、ハイブリッドFan-out戦略、高性能キャッシング機能を統合し、スケーラブルなソーシャルメディア体験を実現する。

## 背景

SNSの主要な体験として、ユーザーは自身がフォローしているユーザーの投稿（ホームタイムライン）、自身が所属するサーバー内の公開投稿（ローカルタイムライン）、および連合しているサーバーを含む広範囲の公開投稿（グローバルタイムライン、または連合タイムライン）を時系列などで閲覧したい。これらのタイムラインを効率的に生成し、高速に提供するための専用サービスが必要となる。特にホームタイムラインはユーザーごとにパーソナライズされるため、スケーラブルな設計が求められる。

## Scientific Merits

* **パフォーマンス**: Redisキャッシング戦略により、タイムライン取得レスポンスタイムを平均200ms以下、p99 500ms以下に短縮。キャッシュヒット率95%以上を維持し、データベースアクセスを大幅削減。
* **スケーラビリティ**: ハイブリッドFan-out戦略により、フォロワー数10万人以上のアカウントでも安定した投稿配信を実現。水平スケーリングにより、100万同時接続のSSEをサポート。
* **可用性**: 99.9%の稼働率を実現。Kubernetesクラスターでの複数レプリカ構成により、単一障害点を排除。Redisクラスターによるキャッシュ層の冗長化。
* **ユーザーエクスペリエンス**: リアルタイム更新（平均遅延3秒以下）により、ユーザーエンゲージメント率を30%向上。7種類の多様なタイムライン体験を提供。
* **技術的優位性**: DDDパターンによる明確なドメインモデル設計。独立したサービス境界により、他サービスへの影響を最小化。
* **運用効率**: OpenTelemetryによる包括的な監視。自動スケーリングとキャッシュ最適化により、運用コストを40%削減。

タイムラインはユーザーが最も頻繁にアクセスする機能（全アクセスの60%）であり、そのパフォーマンスとスケーラビリティはプラットフォーム全体のユーザー体験を決定づける重要な要素である。

## Design Doc

[Design Doc: avion-timeline](./designdoc.md)

## 参考ドキュメント

* [Avion アーキテクチャ概要](./../common/architecture.md)
* [avion-drop PRD](../avion-drop/prd.md) - 投稿データとイベント連携
* [avion-user PRD](../avion-user/prd.md) - ユーザー関係・フォロー・ミュート管理
* [avion-gateway PRD](../avion-gateway/prd.md) - API Gateway・GraphQL・SSE配信
* [avion-search PRD](../avion-search/prd.md) - ハッシュタグ検索・全文検索連携
* [ActivityPub Specification](https://www.w3.org/TR/activitypub/) - 連合タイムライン仕様
* [Server-Sent Events Specification](https://html.spec.whatwg.org/multipage/server-sent-events.html) - SSE実装標準

## 製品原則

* **関連性の高い情報**: ユーザーの関心（フォロー、同サーバー、リスト）に基づく適切なコンテンツ配信を優先し、ノイズを最小化
* **新鮮性の保証**: 新規投稿のリアルタイム反映（平均3秒以内）により、ライブ感のあるソーシャル体験を提供
* **快適な閲覧体験**: 高速レスポンス（平均150ms以下）とスムーズなページネーション、直感的なフィルタリングによる優れたUX
* **スケーラビリティ優先**: 100万同時接続、1日1億投稿に対応できるアーキテクチャで、成長に対応
* **プライバシー尊重**: ミュート・ブロック設定の即時反映、可視性制御の厳密な実装でユーザーの意思を最優先
* **開発者体験**: 明確なAPI設計、包括的なドキュメント、適切なエラーハンドリングで開発・運用効率を最大化
* **可用性重視**: 99.9%稼働率目標、グレースフルな障害処理、フォールバック機能で安定したサービス提供

## やること/やらないこと

### やること

#### コアタイムライン機能
* **ホームタイムライン**: フォロー中ユーザーの投稿を時系列表示、ミュート設定反映
* **ローカルタイムライン**: サーバー内公開投稿の時系列表示、フィルタリング機能
* **グローバルタイムライン**: ActivityPub連合サーバーを含む公開投稿の統合表示
* **ソーシャルタイムライン**: ホーム + ローカルの効率的なマージ表示
* **リストタイムライン**: ユーザー定義リスト（最大100個、メンバー500人）の管理・表示
* **ハッシュタグタイムライン**: `avion-search` 連携による検索結果ベース表示
* **メディアタイムライン**: 画像・動画付き投稿のみの特化表示

#### リアルタイム機能・配信
* **Server-Sent Events (SSE)**: 全タイムライン種別対応、100万接続スケーリング
  - HTTP/2サポートによる効率的なストリーミング
  - イベントID管理による重複配信防止
  - Last-Event-IDによる再接続時の継続性保証
  - Keep-Aliveメッセージによる接続維持（30秒間隔）
* **ハイブリッドFan-out戦略**: フォロワー数別最適配信
  - Push型: フォロワー数1,000人未満（即座に全フォロワーのタイムラインに配信）
  - Pull型: フォロワー数10,000人以上（オンデマンドで取得）
  - Hybrid型: 1,000〜10,000人（アクティブユーザーにPush、その他はPull）
* **リアルタイム更新**: 平均3秒以内での新規投稿反映
  - Redis Pub/Subによる低遅延イベント配信
  - バッチ処理による効率的な更新（100件/バッチ）
  - 優先度付きキューによる重要更新の優先処理
* **接続管理**: SSE接続の自動タイムアウト、リコネクト、状態監視
  - 接続プール管理（Pod毎に最大10,000接続）
  - 自動再接続メカニズム（指数バックオフ付き）
  - 接続状態モニタリング（Prometheus メトリクス）
  - Pod間接続分散によるロードバランシング
* **イベント配信**: 追加・削除・更新イベントの順序保証配信
  - イベントタイプ: ADD_DROP、REMOVE_DROP、UPDATE_DROP、REFRESH_TIMELINE
  - イベントキューイング（最大100イベント/接続）
  - 順序保証アルゴリズム（タイムスタンプベース）
  - 失敗時の自動リトライ（最大3回）

#### パフォーマンス・スケーリング
* **Redisキャッシュ戦略**: 全タイムライン種別、Sorted Set最適化、24時間TTL
* **カーソルベースページネーション**: 前方・後方読み込み、最大100件/リクエスト
* **動的フィルタリング**: メディアのみ、リモートのみ、ミュート適用のリアルタイム処理
* **キャッシュ最適化**: LRU Eviction、メモリ使用量監視、自動クリーンアップ
* **パフォーマンス監視**: レイテンシ・スループット監視、アラート機能

#### 統合・連携
* **マイクロサービス連携**: avion-drop（投稿データ）、avion-user（フォロー・ミュート）、avion-search（ハッシュタグ）
* **イベント駆動アーキテクチャ**: Redis Pub/Sub による非同期イベント処理
* **認証・認可**: JWT Bearer 認証、スコープベースアクセス制御
* **API設計**: gRPC エンドポイント、構造化エラーレスポンス、レート制限

### やらないこと

* **投稿データ永続化**: Drop自体の保存は `avion-drop` が担当、IDリストのみキャッシュ
* **ユーザー関係管理**: フォロー・ブロック・ミュート設定は `avion-user` が管理
* **複雑ランキング算出**: エンゲージメント・関連性スコアは将来的検討、初期は時系列のみ
* **全文検索機能**: 投稿内容検索は `avion-search` が専門担当
* **WebSocket実装**: 双方向通信は不要、SSE で十分
* **高度フィルタリング**: アンテナ・チャンネル機能（Misskey相当）は将来的検討
* **推薦アルゴリズム**: おすすめタイムライン・アルゴリズム表示は別サービス予定
* **メディア処理**: 画像・動画の変換・最適化は `avion-media` が担当
* **通知機能**: プッシュ通知・メール通知は `avion-notification` が担当
* **分析・統計**: ユーザー行動分析・ダッシュボードは将来の分析サービス予定

## 対象ユーザ

* **Avion エンドユーザー**: API Gateway経由でタイムライン機能を利用
* **avion-gateway**: GraphQL/RESTエンドポイント経由でのタイムライン取得
* **avion-drop**: 投稿作成時のタイムライン更新イベント連携
* **avion-user**: ユーザーフォロー関係とミュート設定の参照
* **avion-search**: ハッシュタグタイムラインでの検索結果連携
* **Avion 開発者・運用者**: システム監視、パフォーマンス分析、デバッグ

## ドメインモデル (DDD戦術的パターン)

### Aggregates (集約)

#### Timeline Aggregate
**責務**: 特定のタイムライン種別における投稿エントリーの集合と表示順序を管理する、タイムラインドメインの中核となる集約

- **集約ルート**: Timeline Entity
- **不変条件** (10個):
  1. TimelineIDは一意であり、ユーザーIDとタイムライン種別の組み合わせで決まる
  2. TimelineEntryは時系列順（降順）で並んでいる必要がある
  3. 同一DropIDのTimelineEntryは1つのTimelineに1つまで
  4. TimelineEntryのTotalCountは実際のエントリー数と一致する
  5. キャッシュされたTimelineの有効期限は最大24時間
  6. ページネーション用のカーソルは単調増加する値である
  7. ミュートされたユーザーのDropはタイムラインに含まれない
  8. 削除されたDropはTimelineから自動的に除外される
  9. タイムラインのエントリー数は最大1000件まで
  10. タイムラインの更新はイベントソーシングにより追跡可能

- **ドメインロジック** (12個):
  1. `addEntry(timelineEntry)`: 新しい投稿エントリーを時系列順に挿入
  2. `removeEntry(dropId)`: 指定された投稿エントリーを削除
  3. `getEntriesWithCursor(cursor, limit)`: カーソルベースでエントリーを取得
  4. `isExpired()`: キャッシュの有効期限をチェック
  5. `canAddEntry(entry, muteSettings)`: ミュート設定を考慮した追加可否判定
  6. `refreshFromSource()`: ソースデータからタイムラインを再構築
  7. `applyFilter(filter)`: 動的フィルターを適用
  8. `mergeEntries(otherTimeline)`: 他のタイムラインとエントリーをマージ
  9. `validateConsistency()`: データ整合性を検証
  10. `toSSEEvent()`: SSE配信用イベントに変換
  11. `truncateOldEntries()`: 古いエントリーを削除して容量制限を維持
  12. `calculateScore(entry)`: エントリーのスコアを計算

#### UserList Aggregate
**責務**: ユーザーが作成するカスタムタイムラインリストの管理と、リストメンバーのライフサイクル管理

- **集約ルート**: UserList Entity
- **不変条件** (10個):
  1. ListIDは一意であり、UUID v4形式である
  2. ListMemberは最大500人まで
  3. 1ユーザーあたりのList作成数は最大100個
  4. Listの可視性設定は PRIVATE、PUBLIC、UNLISTED のいずれか
  5. 削除されたListはタイムラインからも削除される
  6. リスト名は1-100文字の範囲内
  7. リスト説明は0-500文字の範囲内
  8. 同一ユーザーは1つのリストに1回のみ追加可能
  9. リスト作成者は必ずownerIDを持つ
  10. リストの更新は作成者のみ可能

- **ドメインロジック** (10個):
  1. `addMember(userId)`: リストメンバーを追加（上限チェック付き）
  2. `removeMember(userId)`: リストメンバーを削除  
  3. `updateVisibility(visibility)`: 可視性設定を更新
  4. `canViewList(requesterId)`: リスト閲覧権限をチェック
  5. `generateTimeline()`: リストメンバーの投稿からタイムラインを生成
  6. `updateMetadata(name, description)`: リストのメタデータを更新
  7. `isOwner(userId)`: 指定ユーザーがオーナーか判定
  8. `getMemberCount()`: 現在のメンバー数を取得
  9. `canAddMember()`: メンバー追加可能か判定
  10. `exportMembers()`: メンバーリストをエクスポート

#### RealtimeConnection Aggregate  
**責務**: リアルタイム更新のためのSSE接続状態管理と、イベント配信の順序性保証

- **集約ルート**: RealtimeConnection Entity
- **不変条件** (12個):
  1. ConnectionIDは一意でありUUID v4形式である
  2. 1ユーザーあたりの同時接続数は最大10個
  3. 非アクティブな接続は30分でタイムアウト
  4. 購読するTimelineTypeは有効な値のみ
  5. 接続状態は ACTIVE、INACTIVE、CLOSED のいずれか
  6. ハートビート間隔は30秒以内
  7. イベントの順序性が保証される（EventID単調増加）
  8. 購読タイムライン種別は最大5つまで
  9. イベントキューは最大100イベントまで
  10. 接続はPod名を記録し、Pod間で分散される
  11. Last-Event-IDによる再接続時の継続性を保証
  12. Keep-Aliveメッセージは30秒間隔で送信

- **ドメインロジック** (12個):
  1. `subscribe(timelineTypes)`: 指定されたタイムライン種別を購読
  2. `unsubscribe(timelineType)`: 購読を解除
  3. `sendEvent(event)`: SSEイベントを送信（順序保証付き）
  4. `isActive()`: 接続がアクティブかチェック
  5. `updateHeartbeat()`: ハートビートを更新
  6. `close()`: 接続をクローズ
  7. `getSubscribedTypes()`: 購読中のタイムライン種別を取得
  8. `isExpired()`: 接続が期限切れかチェック
  9. `queueEvent(event)`: イベントをキューに追加
  10. `flushEventQueue()`: キュー内のイベントを送信
  11. `handleReconnect(lastEventId)`: 再接続を処理
  12. `broadcastKeepAlive()`: Keep-Aliveメッセージを送信

#### FanoutOperation Aggregate
**責務**: 投稿のFan-out処理におけるトランザクション境界の管理と、配信戦略の実行

- **集約ルート**: FanoutOperation Entity  
- **不変条件** (10個):
  1. 一度開始した更新は完了または失敗まで継続
  2. トランザクション境界を保証する
  3. 更新対象のタイムラインIDは重複しない
  4. 更新ステータスは PENDING、PROCESSING、COMPLETED、FAILED のみ
  5. 更新処理は冪等性を保証
  6. タイムアウトは5分で自動失敗
  7. リトライは最大3回まで
  8. Fan-out戦略はフォロワー数により自動決定
  9. 処理済みタイムライン数は総数以下
  10. バッチ処理は100件単位で実行

- **ドメインロジック** (11個):
  1. `startFanout(dropEvent)`: Fan-out処理を開始
  2. `completeFanout()`: Fan-out処理を完了
  3. `failFanout(reason)`: Fan-out処理を失敗として記録
  4. `addTargetTimeline(timelineId)`: 配信対象タイムラインを追加
  5. `canProcessEvent(event)`: イベントが処理可能かチェック
  6. `getProgress()`: 配信の進捗状況を取得
  7. `shouldRetry()`: リトライが必要か判定
  8. `markAsDelivered(timelineId)`: タイムラインを配信済みにマーク
  9. `selectStrategy(followerCount)`: Fan-out戦略を選択
  10. `processBatch(batch)`: バッチ単位で処理
  11. `calculatePriority()`: 配信優先度を計算

#### CacheManagement Aggregate
**責務**: Redisキャッシュの管理と最適化、キャッシュ戦略の実行

- **集約ルート**: CacheManagement Entity
- **不変条件** (8個):
  1. キャッシュキーは一意でタイムラインIDと対応
  2. キャッシュTTLは最大24時間
  3. キャッシュサイズは1タイムラインあたり最大1000エントリー
  4. LRU Eviction戦略に従う
  5. メモリ使用量は80%以下を維持
  6. キャッシュヒット率は監視される
  7. 無効化は即座に反映される
  8. バックアップキャッシュとの整合性を保つ

- **ドメインロジック** (10個):
  1. `cacheTimeline(timeline)`: タイムラインをキャッシュに保存
  2. `getCachedTimeline(timelineId)`: キャッシュからタイムラインを取得
  3. `invalidateCache(timelineId)`: キャッシュを無効化
  4. `updateCacheEntry(timelineId, entry)`: キャッシュエントリを更新
  5. `evictExpiredCaches()`: 期限切れキャッシュを削除
  6. `warmupCache(timelineIds)`: キャッシュをウォームアップ
  7. `getHitRate()`: キャッシュヒット率を取得
  8. `optimizeCacheSize()`: キャッシュサイズを最適化
  9. `backupCache()`: キャッシュをバックアップ
  10. `restoreFromBackup()`: バックアップから復元

### Entities (エンティティ)

#### TimelineEntry Entity
**所属**: Timeline Aggregate
**責務**: タイムライン上の個別投稿エントリーを表現し、表示順序とアクセス制御を管理

- **属性**:
  - EntryID (エントリーの一意識別子)
  - DropID (Snowflake ID - 投稿の一意識別子)
  - Timestamp (投稿作成日時、ソート基準)
  - AuthorID (投稿者のユーザーID)
  - Visibility (投稿の可視性設定)
  - Position (タイムライン内での位置)
  - Score (ソート用スコア、タイムスタンプベース)
  - HasMedia (メディア添付有無)
  - IsRepost (リポスト判定)
  - OriginalAuthorID (リポスト元の投稿者ID)

- **ビジネスルール**:
  - DropIDは必須かつ一意
  - Timestampは有効な過去の時刻
  - Scoreは正の値でタイムスタンプに基づく
  - 削除された投稿は自動的にエントリーからも除外される
  - ミュートされた投稿者の投稿は表示対象外
  - Positionは0から始まる連続した整数

- **ドメインロジック**:
  - `isExpired()`: エントリが期限切れかチェック
  - `getScore()`: ソート用スコアを取得
  - `compareTo(other)`: 他のエントリと比較
  - `canBeViewedBy(userId)`: ユーザーが閲覧可能かチェック
  - `shouldBeFiltered(filter)`: フィルター条件に合致するか判定
  - `toDTO()`: DTOに変換

#### ListMember Entity
**所属**: UserList Aggregate
**責務**: リストに属するユーザーメンバーの状態と権限を管理

- **属性**:
  - MemberID (メンバーエントリーの一意識別子)
  - UserID (メンバーのユーザーID)
  - ListID (所属リストID)
  - AddedAt (リストに追加された日時)
  - AddedBy (追加実行者のユーザーID)
  - Status (ACTIVE、INACTIVE、PENDING)
  - NotificationEnabled (リスト更新通知の有効/無効)

- **ビジネスルール**:
  - 同一ユーザーは1つのListに1回のみ追加可能
  - 削除されたユーザーは自動的にメンバーから除外
  - INACTIVEステータスのメンバーはタイムライン生成対象外
  - PENDINGステータスは承認待ち状態を表す

- **ドメインロジック**:
  - `activate()`: メンバーをアクティブ化
  - `deactivate()`: メンバーを非アクティブ化
  - `isActive()`: アクティブ状態をチェック
  - `shouldReceiveNotification()`: 通知を受け取るべきか判定

#### TimelineEvent Entity
**所属**: RealtimeConnection Aggregate  
**責務**: タイムライン更新イベントの表現と配信管理

- **属性**:
  - EventID (イベントの一意識別子、単調増加)
  - EventType (ADD_DROP、REMOVE_DROP、UPDATE_DROP、REFRESH_TIMELINE)
  - TimelineType (更新対象のタイムライン種別)
  - DropID (関連する投稿ID、オプショナル)
  - Timestamp (イベント発生日時)
  - Payload (イベントペイロード、JSON)
  - RetryCount (配信リトライ回数)
  - DeliveryStatus (PENDING、DELIVERED、FAILED)

- **ビジネスルール**:
  - EventIDは単調増加する
  - 購読していないTimelineTypeのイベントは送信しない
  - イベントの順序性を保持する
  - リトライは最大3回まで
  - ペイロードサイズは最大64KB

- **ドメインロジック**:
  - `incrementRetry()`: リトライカウントを増加
  - `markAsDelivered()`: 配信済みにマーク
  - `markAsFailed()`: 配信失敗にマーク
  - `shouldRetry()`: リトライすべきか判定
  - `toSSEFormat()`: SSE形式に変換

#### CacheEntry Entity
**所属**: CacheManagement Aggregate
**責務**: 個別のキャッシュエントリーとそのメタデータを管理

- **属性**:
  - CacheKey (キャッシュキー、timelineId:version形式)
  - TimelineID (対応するタイムラインID)
  - Data (キャッシュデータ、シリアライズ済み)
  - CreatedAt (キャッシュ作成日時)
  - ExpiredAt (有効期限)
  - HitCount (ヒット回数)
  - Size (データサイズ、バイト)
  - Version (キャッシュバージョン)

- **ビジネスルール**:
  - キャッシュキーは一意
  - 有効期限は最大24時間
  - サイズは最大1MB
  - バージョンは更新のたびに増加

- **ドメインロジック**:
  - `isExpired()`: 有効期限切れをチェック
  - `incrementHitCount()`: ヒット回数を増加
  - `shouldEvict()`: 削除すべきか判定
  - `updateData(data)`: データを更新

### Value Objects (値オブジェクト)

**識別子関連**
- **TimelineID**: ユーザーIDとTimelineTypeの組み合わせ（例: "user123:HOME"）
- **ListID**: UUID v4形式のリスト識別子
- **ConnectionID**: SSE接続の一意識別子（UUID v4）
- **DropID**: Snowflake ID形式の投稿識別子

**タイムライン属性**
- **TimelineType**: HOME、LOCAL、GLOBAL、SOCIAL、LIST、HASHTAG、MEDIA の7種類
  - 各タイプに応じた収集ルールと表示条件を定義
  - リスト型の場合はListIDが必要
  - ハッシュタグ型の場合はハッシュタグ名が必要
- **TimelineCursor**: ページネーション用のカーソル
  - 時刻ベース（ISO 8601フォーマット）
  - 前方・後方ページング対応
  - カーソルベースの重複排除機能
- **TimelineFilter**: 動的フィルタリング条件
  - メディア付き投稿のみ（MEDIA_ONLY）
  - リモートサーバーのみ（REMOTE_ONLY）
  - ミュート設定適用（APPLY_MUTE）

**時刻・数値**
- **CreatedAt**: 作成日時（UTC、ミリ秒精度）
- **UpdatedAt**: 更新日時（UTC、ミリ秒精度）
- **CacheExpiredAt**: キャッシュ有効期限（UTC）
- **Position**: タイムライン内での位置（0から始まる整数）

**設定・状態**
- **Visibility**: PUBLIC、UNLISTED、FOLLOWERS_ONLY、PRIVATE の可視性設定
- **ConnectionStatus**: ACTIVE、INACTIVE、CLOSED のSSE接続状態
- **ListVisibility**: PRIVATE、PUBLIC、UNLISTED のリスト公開設定

#### PageCursor Entity
**所属**: Timeline Aggregate
**責務**: ページネーション用カーソルの管理と検証

- **属性**:
  - CursorValue (カーソル値、Base64エンコード)
  - Timestamp (カーソル位置のタイムスタンプ)
  - DropID (カーソル位置のDropID)
  - Direction (FORWARD、BACKWARD)
  - Limit (取得件数上限)

- **ビジネスルール**:
  - カーソル値は有効なBase64文字列
  - Limitは1-100の範囲
  - タイムスタンプは有効な日時

- **ドメインロジック**:
  - `encode()`: カーソル値をエンコード
  - `decode()`: カーソル値をデコード
  - `validate()`: カーソルの妥当性を検証
  - `next(entries)`: 次のカーソルを生成

### Domain Services (ドメインサービス)

#### TimelineBuilder
**責務**: 各タイムライン種別に応じた複雑なタイムライン構築ロジックを管理
- **メソッド**:
  - `buildHomeTimeline(userId, cursor, limit)`: フォロー関係を元にホームタイムラインを構築
  - `buildLocalTimeline(serverId, cursor, limit)`: サーバー内公開投稿からローカルタイムラインを構築
  - `buildGlobalTimeline(cursor, limit)`: 連合サーバー含むグローバルタイムラインを構築
  - `buildSocialTimeline(userId, cursor, limit)`: ホーム+ローカルをマージしたソーシャルタイムラインを構築
  - `buildListTimeline(listId, cursor, limit)`: リストメンバーからリストタイムラインを構築
  - `buildHashtagTimeline(hashtag, cursor, limit)`: ハッシュタグタイムラインを構築
  - `buildMediaTimeline(userId, cursor, limit)`: メディア付き投稿のタイムラインを構築
  - `applyMuteSettings(timeline, muteSettings)`: ミュート設定を適用

#### TimelineFanOutService
**責務**: 投稿のFan-out処理を管理
- **メソッド**:
  - `fanOut(drop)`: 投稿を関連タイムラインに配信
  - `fanOutToFollowers(drop, followerIds)`: フォロワーのホームタイムラインに配信
  - `fanOutToLocal(drop)`: ローカルタイムラインに配信
  - `fanOutToGlobal(drop)`: グローバルタイムラインに配信
  - `determineFanOutStrategy(followerCount)`: Fan-out戦略を決定（Push/Pull/Hybrid）

#### SSEEventDispatcher
**責務**: SSEイベントの配信を管理
- **メソッド**:
  - `dispatchEvent(event, connections)`: イベントを接続中のクライアントに配信
  - `broadcastTimelineUpdate(timelineType, dropId)`: タイムライン更新をブロードキャスト
  - `sendHeartbeat(connections)`: ハートビートを送信
  - `cleanupStaleConnections()`: 古い接続をクリーンアップ

#### TimelineCacheManager
**責務**: Redisキャッシュの管理
- **メソッド**:
  - `cacheTimeline(timeline)`: タイムラインをキャッシュに保存
  - `getCachedTimeline(timelineId)`: キャッシュからタイムラインを取得
  - `invalidateCache(timelineId)`: キャッシュを無効化
  - `updateCacheEntry(timelineId, entry)`: キャッシュエントリを更新
  - `evictExpiredCaches()`: 期限切れキャッシュを削除
  - `mergeAndSort(timelines)`: 複数タイムラインのマージとソート処理

#### FanoutStrategy
**責務**: 投稿作成時のタイムライン配信戦略を決定・実行
- **メソッド**:
  - `determineFanoutType(authorId, followerCount)`: フォロワー数に応じてFan-out方式を決定
  - `executePushFanout(dropEvent)`: Push型Fan-out実行（フォロワー < 1000人）
  - `executePullFanout(dropEvent)`: Pull型Fan-out実行（フォロワー >= 1000人）
  - `executeHybridFanout(dropEvent)`: ハイブリッド型Fan-out実行
  - `prioritizeActiveUsers(followers)`: アクティブユーザーの優先配信

#### TimelinePolicy
**責務**: タイムライン表示・更新ルールの複雑な判定ロジック
- **メソッド**:
  - `shouldIncludeInTimeline(drop, timelineType, userId)`: 投稿をタイムラインに含めるかの判定
  - `applyMuteRules(entries, muteSettings)`: ミュート設定に基づくフィルタリング
  - `validateVisibilityAccess(drop, requesterId)`: 可視性設定に基づくアクセス権判定
  - `determineUpdateTargets(dropEvent)`: 投稿イベントの更新対象タイムライン決定

#### SSEEventPublisher
**責務**: リアルタイム更新イベントの配信管理とコネクション管理
- **メソッド**:
  - `publishTimelineUpdate(event, connections)`: タイムライン更新イベントの配信
  - `manageConnectionLifecycle(connection)`: SSE接続のライフサイクル管理
  - `broadcastToSubscribers(timelineType, event)`: 特定タイムライン購読者への一斉配信
  - `cleanupInactiveConnections()`: 非アクティブ接続のクリーンアップ

## ユースケース

### ホームタイムライン表示

1. ユーザーがAvionアプリを開き、ホームタイムラインを表示する。
2. `avion-gateway` 経由で `avion-timeline` の`GetHomeTimeline` gRPC APIにリクエストが送られる。
3. TimelineHandler（Handler層）がリクエストを受信し、GetHomeTimelineUseCase（Use Case層）に委譲。
4. GetHomeTimelineUseCaseがTimelineIDとTimelineCursor Value Objectを生成・検証。
5. TimelineRepository（Domain層インターフェース）を通じてTimeline Aggregateを取得。
6. Timeline Aggregateが指定されたカーソル位置のTimelineEntry Entityリストを返却。
7. キャッシュミスの場合、新しいTimeline Aggregateを生成し、TimelineBuilder（Domain Service）で再構築。
8. TimelinePolicy（Domain Service）でミュート設定を適用し、表示対象外のエントリーを除外。
9. フロントエンドは受け取ったDropIDリストをもとにホームタイムラインを表示する。

**SSEリアルタイム更新フロー:**
10. フロントエンドはホームタイムライン用のSSEエンドポイントに接続する。
11. SSEHandlerがEstablishSSEConnectionUseCaseを通じてSSEConnection Entityを生成・管理。
12. 新しいDropが追加されると、SSEEventPublisher（Domain Service）がTimelineUpdateEvent Value Objectを生成。
13. SSEEventPublisherが該当ユーザーのSSEConnectionにイベントを送信。
14. フロントエンドはイベントを受信し、タイムライン表示をリアルタイム更新。

(UIモック: ホームタイムライン画面 - リアルタイム更新とページネーション対応)

### ローカルタイムライン表示

1. ユーザーがローカルタイムラインタブを選択する。
2. `avion-gateway` 経由で `avion-timeline` の`GetLocalTimeline` gRPC APIにリクエストが送られる。
3. TimelineHandlerがリクエストを受信し、GetLocalTimelineUseCaseに委譲。
4. GetLocalTimelineUseCaseがTimelineID Value Object（TimelineType: LOCAL）を生成。
5. TimelineRepositoryがローカルTimeline Aggregateを取得。
6. キャッシュミスの場合、TimelinePolicy（Domain Service）が公開Dropの収集ルールを適用。
7. TimelineBuilder（Domain Service）がTimelineEntry Entityを生成し、Timeline Aggregateに追加。
8. TimelineFilter Value Objectに基づき動的フィルタリング（メディアのみ、リモートのみ等）を実行。
9. フロントエンドは受け取った情報をもとにローカルタイムラインを表示する。

(UIモック: ローカルタイムライン画面 - フィルタリング機能付き)

### グローバル/連合タイムライン表示

1. ユーザーがグローバルタイムラインタブを選択する。
2. `avion-gateway` 経由で `avion-timeline` の`GetGlobalTimeline` gRPC APIにリクエストが送られる。
3. TimelineHandlerがリクエストを受信し、GetGlobalTimelineUseCaseに委譲。
4. GetGlobalTimelineUseCaseがTimelineID Value Object（TimelineType: GLOBAL）を生成。
5. TimelineRepositoryがグローバルTimeline Aggregateを取得。
6. キャッシュミスの場合、ローカルとActivityPub経由の公開Dropを収集。
7. TimelineBuilder（Domain Service）がTimelineEntry Entityリストを生成・ソート。
8. ActivityPub連合サーバーからの投稿配信遅延を考慮した整合性チェック。
9. フロントエンドは受け取った情報をもとにグローバルタイムラインを表示する。

(UIモック: グローバルタイムライン画面 - 連合サーバー表示付き)

### ソーシャルタイムライン表示 (統合ビュー)

1. ユーザーがソーシャルタイムラインタブを選択する。
2. `avion-gateway` 経由で `avion-timeline` の`GetSocialTimeline` gRPC APIにリクエストが送られる。
3. TimelineHandlerがリクエストを受信し、GetSocialTimelineUseCaseに委譲。
4. GetSocialTimelineUseCaseがTimelineBuilder（Domain Service）を使用。
5. TimelineBuilderがホームとローカルのTimelineEntry Entityを効率的にマージ。
6. 重複除去アルゴリズムと時系列ソートを実行（O(n log n)の最適化）。
7. TimelineFilter Value Objectに基づく追加フィルタリング。
8. フロントエンドは統合されたタイムラインを表示する。

(UIモック: ソーシャルタイムライン画面 - ホーム+ローカル統合表示)

### リストタイムライン管理と表示

1. ユーザーが新しいリストを作成する。
2. `avion-gateway` 経由で `avion-timeline` の`CreateList` gRPC APIにリクエストが送られる。
3. CreateListCommandHandlerがCreateListCommandUseCaseに委譲。
4. List Aggregateが生成され、ビジネスルール（最大100リスト制限）を検証。
5. ListRepositoryで永続化し、ListID Value Objectを生成。
6. ユーザーがリストにメンバーを追加（最大500人制限）。
7. UpdateListCommandUseCaseがList Aggregateを更新し、不変条件を検証。
8. リストタイムライン表示時、GetListTimelineUseCaseがリストメンバーのDropを収集。
9. TimelineBuilder（Domain Service）がリスト専用タイムラインを構築。
10. フロントエンドはカスタマイズされたタイムラインを表示する。

(UIモック: リストタイムライン画面 - リスト管理機能付き)

### ハッシュタグタイムライン表示

1. ユーザーがハッシュタグをクリックまたは検索する。
2. `avion-gateway` 経由で `avion-timeline` の`GetHashtagTimeline` gRPC APIにリクエストが送られる。
3. TimelineHandlerがリクエストを受信し、GetHashtagTimelineUseCaseに委譲。
4. `avion-search` サービスと連携してハッシュタグ付き投稿を検索。
5. 検索結果をTimelineEntry Entityに変換し、Timeline Aggregateを構築。
6. キャッシュ戦略（短時間キャッシュ）でパフォーマンスを最適化。
7. フロントエンドはハッシュタグタイムラインを表示する。

(UIモック: ハッシュタグタイムライン画面)

### メディアタイムライン表示

1. ユーザーがメディアフィルターを有効にする。
2. 各タイムラインタイプでTimelineFilter Value Object（MEDIA_ONLY）を適用。
3. TimelinePolicy（Domain Service）がメディア付き投稿のみを抽出。
4. `avion-media` サービスと連携してメディア情報を取得。
5. メディアプレビューと最適化された表示形式でタイムラインを構築。
6. フロントエンドはメディア特化タイムラインを表示する。

(UIモック: メディアタイムライン画面 - 画像・動画グリッド表示)

### タイムライン更新処理 (ハイブリッドFan-out)

1. ユーザーAが新しいDropを作成する (`avion-drop` が処理)。
2. `avion-drop` がDropEvent Value ObjectをRedis Pub/Subに発行。
3. DropEventHandler（Handler層）がDropEventを受信し、ProcessDropEventUseCaseに委譲。
4. ProcessDropEventUseCaseがTimelineUpdateContext Aggregateを生成。
5. FanoutStrategy（Domain Service）がフォロワー数に基づき配信方式を決定：
   - < 1000フォロワー: Push型（即座に全フォロワーのタイムラインを更新）
   - >= 1000フォロワー: Pull型（リクエスト時に動的生成）
   - >= 10000フォロワー: ハイブリッド型（アクティブユーザーのみPush）
6. TimelinePolicy（Domain Service）がVisibilityとミュート設定に基づき更新対象を判断。
7. SSEEventPublisher（Domain Service）がTimelineUpdateEventを該当ユーザーに配信。
8. 非同期でキャッシュ整合性を確保し、不要なキャッシュエントリをクリーンアップ。

### SSE接続管理とリアルタイム通知

1. フロントエンドがSSE接続を確立する。
2. EstablishSSEConnectionUseCaseがSSEConnection Aggregateを生成。
3. 購読するTimelineTypeを指定し、接続状態を管理。
4. ハートビート機能で接続状態を監視（30秒間隔）。
5. タイムライン更新時、SSEEventPublisher（Domain Service）が該当接続にイベント配信。
6. 接続タイムアウト（30分）またはクライアント切断時、接続をクリーンアップ。
7. 1ユーザーあたり最大10同時接続の制限を実装。

### エラーハンドリングとフォールバック

1. キャッシュ障害時、データベースから直接タイムラインを再構築。
2. 外部サービス（avion-drop、avion-user）障害時、古いキャッシュデータで継続動作。
3. SSE接続障害時、自動再接続とイベント補完機能。
4. タイムライン構築エラー時、空のタイムラインと適切なエラーメッセージを返却。
5. レート制限到達時、適切なHTTPステータスコードとRetry-Afterヘッダーを返却。

## 機能要求

### ドメインロジック要求

* **Timeline Aggregate管理**: 7種類のTimelineType（HOME、LOCAL、GLOBAL、SOCIAL、LIST、HASHTAG、MEDIA）による統合的なタイムライン管理
* **TimelineEntry整合性**: 時系列順序保証、重複排除、削除投稿の自動除外
* **List Aggregate制約**: ユーザーあたり最大100リスト、リストあたり最大500メンバー
* **SSEConnection管理**: ユーザーあたり最大10同時接続、30分タイムアウト、自動クリーンアップ
* **Fan-out戦略**: フォロワー数に応じたハイブリッド配信（Push < 1000、Pull >= 1000、Hybrid >= 10000）
* **ミュート機能**: ユーザーミュート・ワードミュートのリアルタイム反映
* **可視性制御**: PUBLIC、UNLISTED、FOLLOWERS_ONLY、PRIVATE に基づくアクセス制御

### APIエンドポイント要求

* **Timeline取得API**: gRPC エンドポイント群（GetHomeTimeline、GetLocalTimeline等）
* **認証・認可**: JWT Bearer認証、ユーザーコンテキスト検証
* **ページネーション**: カーソルベース、前方・後方読み込み、1回あたり最大100件
* **レート制限**: ユーザーあたり 600req/10min、IP あたり 1200req/10min
* **エラーハンドリング**: gRPC Status Code、構造化エラーレスポンス、リトライ可能エラーの明示
* **SSEエンドポイント**: Keep-alive、自動再接続、イベント順序保証

### データ要求

* **TimelineEntry**: DropID（Snowflake）、Timestamp（UTC、ミリ秒精度）、AuthorID、Position
* **Timeline キャッシュ**: Redis Sorted Set、24時間 TTL、LRU Eviction
* **List データ**: PostgreSQL永続化、リスト名（1-100文字）、説明（0-500文字）
* **SSE Connection**: Redis管理、接続メタデータ、購読チャンネル情報
* **関連性制約**: 削除されたユーザー・投稿の参照整合性自動維持
* **アーカイブ**: 古いタイムラインエントリの自動クリーンアップ（7日経過後）
* **マイグレーション**: スキーマ変更時の下位互換性、段階的移行対応

## セキュリティ実装ガイドライン

avion-timelineサービスは、多くのユーザーデータを集約・配信するため、以下のセキュリティガイドラインに従って実装します：

### 必須実装項目

1. **SQLインジェクション防止** ([SQLインジェクション防止](../common/security/sql-injection-prevention.md))
   - タイムライン取得クエリでのパラメータ化クエリ使用
   - フィルタリング条件の安全な構築
   - カーソルベースページネーションでの入力検証
   - 動的SQL生成の完全禁止

2. **XSS防止** ([XSS防止ガイドライン](../common/security/xss-prevention.md))
   - SSEイベントデータのエスケープ処理
   - タイムラインコンテンツの適切なサニタイゼーション
   - イベントメッセージのJSONエンコーディング
   - CSPヘッダーの適切な設定

3. **TLS設定** ([TLS設定ガイドライン](../common/security/tls-configuration.md))
   - SSE接続のTLS必須化
   - TLS 1.2以上のみサポート
   - 強力な暗号スイートの使用
   - HSTS ヘッダーの設定

4. **暗号化** ([暗号化ガイドライン](../common/security/encryption-guidelines.md))
   - センシティブなタイムラインデータのキャッシュ暗号化
   - 一時データの暗号化保存
   - キャッシュキーのハッシュ化

### 実装時の注意事項

- **アクセス制御**: プライベートタイムラインへの厳格なアクセス制御
- **入力検証**: ハッシュタグ、リストID、カーソルの妥当性検証
- **レート制限**: タイムライン取得リクエストの頻度制限
- **キャッシュポイズニング防止**: キャッシュデータの整合性検証
- **SSE接続管理**: 異常な接続パターンの検出と遮断
- **監査ログ**: アクセスパターンの記録と異常検知

## 技術的要求

### レイテンシ

* **タイムライン取得**: 平均 150ms 以下、p99 500ms 以下（キャッシュヒット時）
* **タイムライン取得 (キャッシュミス)**: 平均 800ms 以下、p99 2000ms 以下
* **タイムライン更新配信**: 平均 3秒以下でSSE通知、p99 10秒以下
* **リスト操作**: 平均 100ms 以下、p99 300ms 以下
* **SSE接続確立**: 平均 50ms 以下、p99 200ms 以下
* **ページネーション**: 次ページ取得 平均 120ms 以下、p99 400ms 以下
* **ハッシュタグタイムライン**: 平均 300ms 以下、p99 1000ms 以下（検索連携）

### 可用性

* **目標稼働率**: 99.9%（月間43分以内のダウンタイム）
* **Kubernetesクラスター**: 最小3レプリカ、複数AZ分散配置
* **Redis高可用性**: Redis Cluster 3マスター + 3スレーブ構成
* **ヘルスチェック**: /health（簡易）、/health/ready（詳細依存関係チェック）
* **グレースフルシャットダウン**: 30秒以内での安全な停止処理
* **サーキットブレーカー**: 外部サービス障害時の自動フェイルオーバー
* **フォールバック**: キャッシュ障害時のデータベース直接アクセス

### スケーラビリティ

* **同時接続数**: 100万SSE接続対応、水平スケーリング
* **タイムライン処理**: 100万ユーザー、1日1億投稿対応
* **Fan-out性能**: 10万フォロワーアカウントで3秒以内配信完了
* **Redis使用量**: 総メモリ使用量 < 80%、キー数 < 1億
* **CPU使用率**: 平均 < 70%、ピーク時 < 90%
* **水平スケーリング**: HPA（CPU 70%、メモリ 80%）で自動スケール
* **垂直スケーリング**: インスタンス最大16CPU、64GB RAM対応

### セキュリティ

* **入力検証**: 全パラメータの型・範囲・長さ検証、SQLi/XSS対策
* **認証・認可**: JWT Bearer認証、スコープベースアクセス制御
* **データ暗号化**: TLS 1.3（transit）、AES-256（rest）
* **監査ログ**: セキュリティ関連イベント（認証失敗、権限エラー等）
* **レート制限**: IP/ユーザー別、DDoS攻撃対策
* **CORS設定**: 許可ドメインのホワイトリスト管理

### データ整合性

* **トランザクション境界**: Aggregate単位での整合性保証
* **結果整合性**: 分散環境での最終的な整合性（最大5分許容）
* **競合解決**: 楽観的ロック、バージョン管理
* **データ検証**: 定期的な整合性チェック（日次バッチ）
* **バックアップ**: Redis RDB + AOF、PostgreSQL 日次バックアップ
* **リカバリ**: RPO < 1時間、RTO < 30分

### その他技術要件

* **ステートレス設計**:
  - ドメインモデルは永続化せず、外部システムに状態を委譲
  - Timeline Aggregateは状態管理のみを担当
  - SSEConnection EntityもRedisで管理
* **DDDアーキテクチャ**:
  - Handler層: gRPC/SSEエンドポイント
  - Use Case層: ビジネスロジックの調整
  - Domain層: Aggregate、Entity、Value Object、Domain Service
  - Infrastructure層: Redis、他サービスとの統合
* **Observability**:
  - OpenTelemetry SDK（トレース、メトリクス、ログ）
  - 分散トレーシング（Jaeger）
  - メトリクス収集（Prometheus）
  - ログ集約（ELK Stack）
  - アラート設定（レイテンシ、エラー率、可用性）
* **構成管理**:
  - 環境別設定（開発、ステージング、本番）
  - Kubernetes ConfigMap + Secret
  - 動的設定変更（一部パラメータ）
* **テスト要件**:
  - ユニットテスト カバレッジ > 90%
  - 結合テスト（Redis、他サービス連携）
  - パフォーマンステスト（負荷、ストレス）
  - カオスエンジニアリング（障害注入テスト）
  
  テスト実装については[共通テスト戦略](../common/testing-strategy.md)を参照。

---

## 決まっていないこと

* **Timeline Entry永続化**: Redis Sorted Setでの具体的な実装パターン（複合インデックス、メモリ使用量最適化）
* **SSE Connection スケーリング**: 100万接続時のConnection Entity分散戦略とロードバランシング
* **TimelineUpdateEvent フォーマット**: JSON Schema定義、バージョン管理、下位互換性
* **キャッシュ再構築戦略**: 障害時の自動復旧、増分更新 vs 全量更新の判定ロジック
* **Timeline収集範囲**: ActivityPub連合タイムラインの範囲（どこまでの連合サーバーを含むか）
* **トランザクション境界**: TimelineUpdateContext Aggregateでの分散トランザクション管理
* **リスト共有機能**: パブリックリスト、フォロー可能リスト、リスト推薦機能の実装方針
* **ハッシュタグキャッシュ**: avion-searchとの連携頻度、キャッシュ無効化戦略
* **ミュート責務分担**: avion-userでの永続化 vs avion-timelineでのキャッシュ、整合性保証
* **パフォーマンス最適化**: ソーシャルタイムライン（HOME + LOCAL）の最適なマージアルゴリズム
* **国際化対応**: 多言語環境でのタイムライン表示順序（文字エンコーディング、タイムゾーン）
* **アルゴリズム拡張**: 時系列以外のランキング（エンゲージメント、関連性）の将来的実装
* **GDPR対応**: ユーザーデータ削除時のタイムラインからの完全除去保証
* **監査要件**: タイムライン表示・更新の詳細ログ、コンプライアンス対応
* **マイグレーション戦略**: 既存タイムラインデータの新フォーマットへの移行手順
