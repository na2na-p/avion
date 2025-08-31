# PRD: avion-drop

## 概要

Avionにおける投稿（Drop）の作成、取得、削除、編集（限定的）などの管理機能、および投稿に対する絵文字リアクション機能を提供するマイクロサービスを実装する。

## 背景

SNSアプリケーションの根幹となる機能として、ユーザーがテキストやメディアを含む投稿（Drop）を作成し、共有できる仕組みが必要となる。また、MisskeyライクなSNS体験の中核的な要素として、投稿に対して多様な絵文字で気軽に反応できる機能は、コミュニケーションを豊かにし、ユーザーエンゲージメントを高める上で重要である。

投稿データの管理、アクセス制御、関連操作（削除など）、およびリアクション機能を統合したマイクロサービスを設けることで、投稿のライフサイクル全体を一元管理し、データの整合性を保ちやすくする。

## Scientific Merits

*   **スケーラビリティ:** 投稿データ量やアクセス数の増加に対して、`avion-drop` サービスを独立してスケールさせることが可能。リアクションデータも投稿と一緒に管理することで、効率的なスケーリングが可能。
*   **関心の分離:** 投稿管理という明確な責務を持つことで、他のサービス（タイムライン生成、通知など）との依存関係を疎にし、開発効率とメンテナンス性を向上させる。
*   **データ整合性:** 投稿とリアクションの操作を一元管理することで、データの整合性を保ちやすくなる。投稿削除時のリアクションのカスケード削除なども簡潔に実装できる。
*   **パフォーマンス:** 投稿とリアクションを同一サービスで管理することで、サービス間通信のオーバーヘッドを削減し、レスポンスタイムを改善できる。
*   **ユーザーエンゲージメント向上:** 「いいね」よりも表現豊かなリアクション機能は、ユーザー間のインタラクションを促進し、プラットフォームへの滞在時間や満足度を高める可能性がある。
*   **生産性向上:** 下書き機能、予約投稿機能により、ユーザーは時間を効率的に使用し、計画的なコンテンツ発信が可能になる。
*   **情報整理:** ブックマーク機能により、ユーザーは重要な投稿を後から参照できるようになり、情報の再利用性が向上する。
*   **エンゲージメント分析:** 投票機能により、ユーザーの意見収集やコミュニティの傾向分析が容易になる。
*   **コンテンツ品質向上:** 編集履歴機能により、誤字脱字の修正が可能になり、コンテンツの品質を維持できる。

投稿機能はSNSの利用頻度が最も高い部分の一つであり、リアクション機能と統合することで、より価値の高いサービスとして性能と信頼性を確保できる。

## Design Doc

[Design Doc: avion-drop](./designdoc.md)

## 参考ドキュメント

*   [Avion アーキテクチャ概要](./../common/architecture.md)

## 製品原則

*   **自由な表現:** ユーザーがテキストや（将来的には）メディアを通じて自由に考えや情報を発信できること。
*   **確実な永続化:** 作成されたDropが確実に保存され、後から参照できること。
*   **適切なアクセス制御:** Dropの公開範囲設定に基づき、意図した範囲のユーザーのみが閲覧できるようにすること。
*   **表現豊かな反応:** ユーザーが多様な絵文字を使ってDropへの感情や反応を表現できること。
*   **簡単な操作:** 直感的で簡単な操作でリアクションを追加・削除できること。
*   **明確な集計:** どのDropにどの絵文字がいくつ付いているかを分かりやすく表示すること。

## やること/やらないこと

### やること

*   新しいDropの作成 (テキスト本文、公開範囲設定)
*   特定のDropの取得 (ID指定)
*   特定のユーザーが作成したDropのリスト取得 (ページネーション付き)
*   Dropの削除 (作成者本人のみ)
*   Dropの編集機能
    - 編集履歴の保存・表示
    - 編集通知の発行
    - 編集可能期間の設定（例：投稿後30分以内）
*   Dropの公開範囲設定 (公開、フォロワー限定、ダイレクトメッセージ、未リスト)
*   添付メディア情報の関連付け (メディア自体の管理は `avion-media` が担当)
*   引用Drop（Quote Post）機能
    - 引用元Dropへの参照管理
    - 引用通知の発行
    - 引用チェーンの表示
*   リポスト (Boost) 機能
*   投票（Poll）機能
    - 複数選択肢の設定（最大4つまで）
    - 複数回答可/単一回答の設定
    - 投票期限の設定
    - 投票結果の集計・表示
    - 投票終了通知
*   コンテンツ警告（CW: Content Warning）機能
    - CWラベルの設定
    - CW付きDropの折り畳み表示
    - ユーザーごとのCW自動展開設定
*   特定のDropに対する絵文字リアクションの追加
*   自身が行ったリアクションの削除 (取り消し)
*   特定のDropに付与されたリアクションの一覧と、各絵文字のカウント数の取得
*   特定のユーザーが特定のDropに対してリアクションしたかどうかの判定
*   カスタム絵文字リアクション
    - カスタム絵文字の登録・管理
    - インスタンス間での絵文字共有
    - カテゴリ別絵文字管理
*   ハッシュタグの抽出・管理（`avion-search`との連携用）
*   メンションの抽出・管理（通知用）
*   スケジュール投稿機能
    - 投稿予約（最大30日先まで）
    - 下書き保存・管理
    - 予約投稿の編集・キャンセル
    - 予約投稿一覧表示
    - 定期実行による自動投稿
*   ブックマーク機能
    - Dropのブックマーク追加・削除
    - ブックマーク一覧の取得（ページネーション付き）
    - ブックマーク済み判定
    - ブックマーク数の集計
*   下書き機能
    - 下書きの保存・更新・削除
    - 下書き一覧の取得
    - 下書きからの投稿作成
    - 自動保存機能
*   編集履歴機能
    - 編集履歴の保存・表示
    - 編集前後の差分表示
    - 編集回数の制限（設定可能）

### やらないこと

*   **タイムラインの生成:** ホームタイムラインやローカルタイムラインなどの生成は `avion-timeline` が担当する。
*   **通知の生成:** メンションやリポスト、リアクションに伴う通知は `avion-notification` が担当する。
*   **メディアファイルの保存・配信:** メディアファイルの実体は `avion-media` が管理する。`avion-drop` は関連付け情報 (URLなど) を持つのみ。
*   **全文検索:** Dropの検索機能は `avion-search` が担当する。
*   **リアクションに基づくタイムラインソート:** リアクション数を考慮したタイムラインの並び替えは `avion-timeline` の将来的な拡張。
*   **リアクションデータの永続的な履歴保存 (詳細レベル):** 誰がいつどのリアクションをしたかの完全なログは、パフォーマンスとストレージの観点から、必ずしも永続化しない可能性がある (集計結果は保持)。

## 対象ユーザ

*   Avion エンドユーザー (API Gateway経由)
*   Avion の他のマイクロサービス (Timeline, Notification, ActivityPubなど)
*   Avion 開発者・運用者

## ドメインモデル (DDD戦術的パターン)

### Aggregates (集約)

#### Drop Aggregate
**責務**: 投稿の基本的なコンテンツとメタデータを管理する純粋なコンテンツ集約
- **集約ルート**: Drop
- **不変条件**:
  - 投稿内容は読みやすさと表示パフォーマンスを保つために適切な長さに制限される（ビジネスルール：ユーザー体験の最適化）
  - 投稿者の身元は投稿の信頼性を保証するため変更不可（ビジネスルール：信頼性の確保）
  - 投稿時刻は時系列の整合性を保つため変更不可（ビジネスルール：履歴の一貫性）
  - 公開範囲は定義されたプライバシーレベルのいずれかである（ビジネスルール：プライバシー管理）
  - 投稿の所有権は作成者のみが持つ（ビジネスルール：所有権の明確化）
  - 削除された投稿は法的要件がない限り復元不可（ビジネスルール：忘れられる権利）
  - 投稿の修正は誤解を防ぐため時間制限内のみ許可（ビジネスルール：コンテンツの信頼性）
  - コンテンツ警告を設定する場合は明確な理由が必要（ビジネスルール：安全な閲覧環境）
- **ドメインロジック**:
  - `canBeDeletedBy(userID)`: 削除権限の判定（所有権に基づく）
  - `canBeEditedBy(userID, currentTime)`: 編集権限の判定（所有権と時間制限に基づく）
  - `canBeViewedBy(viewer ViewContext)`: 閲覧権限の判定（プライバシーポリシーに基づく）
  - `applyContentPolicy(policy ContentPolicy)`: コンテンツポリシーの適用
  - `validateContent()`: コンテンツの妥当性検証
  - `toExternalFormat(format ExportFormat)`: 外部形式への変換
  - `markAsDeleted(reason DeletionReason)`: 削除処理（理由の記録）
  - `createRevision(newContent DropContent)`: リビジョン作成（編集履歴）

#### Reaction Aggregate
**責務**: ユーザーの感情表現とエンゲージメントを管理する独立した集約
- **集約ルート**: Reaction
- **不変条件**:
  - ユーザーの感情表現は一意性を保つ（ビジネスルール：重複リアクションの防止）
  - リアクションの主体は記録の完全性のため変更不可（ビジネスルール：監査証跡）
  - リアクション対象は参照整合性のため変更不可（ビジネスルール：データ整合性）
  - リアクションの取り消しは本人のみ可能（ビジネスルール：自己決定権）
  - 対象コンテンツが削除された場合は関連データも削除（ビジネスルール：カスケード削除）
  - 絵文字は文化的に適切で有効なものである（ビジネスルール：文化的配慮）
- **ドメインロジック**:
  - `canBeRevokedBy(userID)`: 取り消し権限の判定（自己決定権に基づく）
  - `validateEmojiCulturalAppropriateness()`: 絵文字の文化的妥当性検証
  - `toEngagementMetric()`: エンゲージメント指標への変換
  - `shouldTriggerNotification(notificationPolicy)`: 通知ポリシーに基づく通知判定
  - `calculateEngagementScore()`: エンゲージメントスコアの算出

#### MediaAttachment Aggregate
**責務**: 投稿に関連するメディアコンテンツを独立して管理
- **集約ルート**: MediaAttachment
- **不変条件**:
  - メディアの視覚的魅力と読み込み性能のバランスを保つ（ビジネスルール：UX最適化）
  - メディアの順序は視覚的な物語性を保つ（ビジネスルール：コンテンツの一貫性）
  - アクセシビリティのため代替テキストが推奨される（ビジネスルール：包括的設計）
  - メディアタイプは適切なフォーマットである（ビジネスルール：互換性確保）
  - サムネイルは高速表示のため必須（ビジネスルール：パフォーマンス）
- **ドメインロジック**:
  - `validateMediaQuality()`: メディア品質の検証
  - `optimizeForDisplay(deviceContext)`: デバイスに応じた最適化
  - `generateAccessibilityMetadata()`: アクセシビリティメタデータ生成
  - `checkCopyrightCompliance()`: 著作権コンプライアンスチェック
  - `calculateDisplayPriority()`: 表示優先度の算出

#### Poll Aggregate
**責務**: コミュニティの意見収集と民主的な意思決定を支援する独立した集約
- **集約ルート**: Poll
- **不変条件**:
  - 選択肢は意味のある選択を可能にする数である（ビジネスルール：有効な選択）
  - 投票期間は十分な参加機会を確保する（ビジネスルール：公平な参加）
  - 投票の公正性を保つため終了後の変更は不可（ビジネスルール：投票の完全性）
  - 投票の重複制御は民主的原則に従う（ビジネスルール：一人一票の原則）
  - 投票結果の透明性を確保する（ビジネスルール：透明性の原則）
- **ドメインロジック**:
  - `submitVote(voter VoterContext, choice)`: 投票の提出（権限検証含む）
  - `validateVotingEligibility(voter)`: 投票資格の検証
  - `hasReachedQuorum()`: 定足数到達の判定
  - `calculateStatistics()`: 統計情報の算出（投票率、分布等）
  - `generateAnalytics()`: 投票分析レポートの生成
  - `ensureFairness()`: 公正性の検証

#### Bookmark Aggregate
**責務**: 個人的な情報整理とコンテンツキュレーションを支援する独立した集約
- **集約ルート**: Bookmark
- **不変条件**:
  - ブックマークは個人の情報整理のため重複不可（ビジネスルール：効率的な情報管理）
  - 対象コンテンツが削除された場合は参照整合性を保つ（ビジネスルール：データ整合性）
  - ブックマークの所有権は作成者のみ（ビジネスルール：プライバシー保護）
  - ブックマーク数には実用的な上限がある（ビジネスルール：リソース管理）
- **ドメインロジック**:
  - `canBeRemovedBy(userID)`: 削除権限判定（所有権に基づく）
  - `categorize(category)`: カテゴリ分類（整理の支援）
  - `addNote(note)`: 個人メモの追加（コンテキスト保存）
  - `validateUniqueness()`: 一意性の検証

#### ContentWarning Aggregate  
**責務**: コンテンツの安全な閲覧環境を提供する独立した集約
- **集約ルート**: ContentWarning
- **不変条件**:
  - 警告は閲覧者の安全のため明確である（ビジネスルール：安全な閲覧環境）
  - 警告レベルは段階的に設定される（ビジネスルール：きめ細かな制御）
  - 警告理由は説明可能である（ビジネスルール：透明性）
  - 文化的配慮が考慮される（ビジネスルール：グローバル対応）
- **ドメインロジック**:
  - `shouldDisplay(viewerPreferences)`: 表示判定（閲覧者設定に基づく）
  - `categorizeWarning(category)`: 警告カテゴリ分類
  - `validateCulturalContext(locale)`: 文化的文脈の検証
  - `generateWarningMessage(locale)`: ローカライズされた警告メッセージ生成

#### EditHistory Aggregate
**責務**: コンテンツの変更履歴と透明性を管理する独立した集約
- **集約ルート**: EditHistory
- **不変条件**:
  - 履歴は改竄防止のため不変である（ビジネスルール：監査証跡）
  - 編集は時系列順に記録される（ビジネスルール：履歴の一貫性）
  - 編集理由の記録が推奨される（ビジネスルール：透明性）
  - 一定期間後は圧縮可能（ビジネスルール：ストレージ最適化）
- **ドメインロジック**:
  - `addRevision(content, reason)`: リビジョン追加
  - `calculateDiff(fromVersion, toVersion)`: 差分計算
  - `getVersionAt(timestamp)`: 特定時点のバージョン取得
  - `compressOldRevisions(before)`: 古いリビジョンの圧縮

### Entities (エンティティ)

- **MediaAttachment**: 投稿に添付されたメディア情報
- **EditRevision**: 投稿の編集履歴
- **PollOption**: 投票の個別選択肢
- **PollVote**: ユーザーの投票情報
- **ContentWarning**: コンテンツ警告情報
- **Renote**: リノート（引用投稿）情報
- **ReactionDetail**: 個別リアクション詳細
- **DropReport**: 投稿に対する通報情報

### Value Objects (値オブジェクト)

#### 識別子系
- DropID, UserID, ReactionID, PollID, BookmarkID, DraftID, ScheduledDropID, ReportID

#### コンテンツ系
- DropText, DropContent, ContentType
- HashTag, Mention, URL
- MediaID, MediaType, MediaURL, MediaOrder, AltText

#### 権限・設定系
- Visibility, DropStatus, DraftStatus
- ReplyToDropID, RenoteDropID

#### リアクション系
- EmojiCode, ReactionType, ReactionCount

#### 投票系
- PollOptionID, PollOptionText, VoteCount, PollExpiry, PollStatus

#### 時刻系
- CreatedAt, UpdatedAt, DeletedAt, EditedAt
- ScheduledAt, PublishedAt

#### 処理状態系
- RetryCount, ErrorMessage, ProcessingStatus
- ReportReason, ReportStatus

### Domain Services (ドメインサービス)

- **DropService**: 投稿作成・更新・削除のビジネスルール統括
- **ReactionService**: リアクション追加・削除のビジネスルール統括
- **PollService**: 投票作成・投票処理のビジネスルール統括
- **BookmarkService**: ブックマーク管理のビジネスルール統括
- **DraftService**: 下書き管理のビジネスルール統括
- **ScheduledDropService**: 予約投稿のビジネスルール統括
- **ContentValidationService**: コンテンツ検証と正規化
- **VisibilityService**: 公開範囲判定のビジネスルール
  - `toNotificationEvent()`: 通知イベントへの変換
  - `toTimelineEvent()`: タイムラインイベントへの変換
  - `validate()`: イベントデータの妥当性検証

### Entities (エンティティ)

#### MediaAttachment
**所属**: Drop Aggregate
**責務**: Dropに添付されたメディア情報を管理
- **属性**:
  - AttachmentID（Entity識別子）
  - MediaID（メディアサービスの識別子）
  - MediaType（image, video, audio）
  - MediaURL（アクセスURL）
  - ThumbnailURL（サムネイルURL）
  - Order（表示順序）
  - AltText（代替テキスト）
  - Metadata（幅、高さ、長さ等）
- **ビジネスルール**:
  - Orderは1から始まる連番
  - 同一Drop内でOrderは一意
  - MediaTypeに応じた適切なMetadata

#### ReactionUser
**所属**: ReactionSummary Aggregate（将来実装）
**責務**: 特定の絵文字でリアクションしたユーザーリストを管理
- **属性**:
  - UserID（Entity識別子）
  - ReactedAt（リアクション日時）
  - DisplayOrder（表示順序）
- **ビジネスルール**:
  - 最新のリアクションが上位に表示
  - 最大表示数の制限（例：最新100件）

#### DropCache
**所属**: Drop Aggregate（パフォーマンス最適化）
**責務**: 頻繁にアクセスされるDropのキャッシュ情報を管理
- **属性**:
  - CacheID（Entity識別子）
  - CachedAt（キャッシュ生成時刻）
  - TTL（有効期限）
  - AccessCount（アクセス回数）
  - CacheData（シリアライズされたDrop情報）
- **ビジネスルール**:
  - TTL経過後は無効
  - 更新時は即座に無効化

#### PollOption Entity
**所属**: Poll Aggregate
**責務**: 投票選択肢を管理
- **属性**:
  - OptionID（Entity識別子）
  - Text（選択肢テキスト）
  - VoteCount（投票数）
  - Order（表示順序）
- **ビジネスルール**:
  - Textは50文字以内
  - VoteCountは0以上

#### EditRevision Entity
**所属**: EditHistory Aggregate
**責務**: 各編集バージョンを管理
- **属性**:
  - RevisionID（Entity識別子）
  - EditedAt（編集日時）
  - EditedBy（編集者UserID）
  - Content（編集後のコンテンツ）
  - EditReason（編集理由）

#### DraftContent Entity
**所属**: ScheduledDrop Aggregate
**責務**: 下書き/予約投稿のコンテンツを管理
- **属性**:
  - ContentID（Entity識別子）
  - Text（投稿テキスト）
  - Visibility（公開範囲）
  - MediaAttachments（添付メディア情報）
  - Poll（投票設定）
  - ContentWarning（CW設定）
  - UpdatedAt（最終更新日時）
- **ビジネスルール**:
  - Textは最大5000文字
  - MediaAttachmentsは最大4つ
  - 公開後は変更不可

#### Poll Aggregate
**責務**: 投票機能の管理
- **集約ルート**: Poll
- **不変条件**:
  - 選択肢は2～4個
  - 投票期限は5分以上7日以内
  - 期限切れ後は投票不可
  - 同一ユーザーの重複投票は設定に従う
- **ドメインロジック**:
  - `vote()`: 投票処理
  - `canVote()`: 投票可否判定
  - `isExpired()`: 期限切れ判定
  - `getResults()`: 結果集計

#### EditHistory Aggregate
**責務**: 投稿編集履歴の管理
- **集約ルート**: EditHistory
- **不変条件**:
  - 履歴は時系列順
  - 過去の履歴は変更不可
- **ドメインロジック**:
  - `addRevision()`: リビジョン追加
  - `getLatestRevision()`: 最新版取得
  - `getDiff()`: 差分取得

#### ScheduledDrop Aggregate
**責務**: スケジュール投稿の管理と実行制御
- **集約ルート**: ScheduledDrop
- **不変条件**:
  - ScheduledAtは現在時刻より未来（最大30日先）
  - Statusは定義された値（draft, scheduled, published, cancelled）のいずれか
  - 公開済みのスケジュール投稿は編集不可
  - AuthorUserIDは変更不可
- **ドメインロジック**:
  - `canBeEditedBy(userID)`: 編集権限の判定（作成者のみ、かつscheduledまたはdraft状態）
  - `canBeCancelledBy(userID)`: キャンセル権限の判定（作成者のみ、かつscheduled状態）
  - `schedule(scheduledAt)`: スケジュール設定（時刻検証含む）
  - `publish()`: 投稿実行（Drop Aggregateへの変換）
  - `cancel()`: スケジュールキャンセル
  - `updateContent(content)`: コンテンツ更新（状態チェック含む）
  - `shouldBePublished(currentTime)`: 公開すべきかの判定
  - `validate()`: スケジュール投稿全体の妥当性検証

### Value Objects (値オブジェクト)

**識別子関連**
- **DropID**: Dropの一意識別子（Snowflake ID）
- **ReactionID**: リアクションの一意識別子（UUID v4）
- **EventID**: イベントの一意識別子（冪等性保証用、Snowflake ID）
- **AuthorUserID**: Drop作成者のユーザーID
- **ReactorUserID**: リアクション実行者のユーザーID
- **UserID**: 汎用的なユーザーID
- **MediaID**: メディアサービスでの識別子
- **ScheduledDropID**: スケジュール投稿の一意識別子（Snowflake ID）

**Drop属性**
- **DropText**: Dropのテキスト内容を表現
  - 最大5000文字（設定可能）、Unicode対応
  - メンション、ハッシュタグ、URLを含む可能性
  - 改行やスペースの正規化
- **Visibility**: Dropの公開範囲を表現
  - `public`: 全体公開
  - `unlisted`: 未リスト（タイムラインに表示されない）
  - `followers_only`: フォロワーのみ
  - `private`: 非公開（下書き）
- **DropType**: Dropの種別を表す列挙型
  - `normal`: 通常の投稿
  - `reply`: 返信
  - `quote`: 引用
  - `repost`: リポスト
- **DropStatus**: Dropの状態を表現
  - `active`: アクティブ
  - `deleted`: 削除済み
  - `suspended`: 一時停止（モデレーション）
- **ContentWarning**: CW情報を表現
  - `enabled`: CW有効/無効
  - `text`: CWラベルテキスト（最大100文字）

**リアクション属性**
- **EmojiCode**: リアクションの絵文字を表現
  - Unicode絵文字またはカスタム絵文字コード
  - 形式: `:smile:` または実際のUnicode文字
  - カスタム絵文字の場合: `:custom_emoji_name:`
- **ReactionType**: リアクション種別を表す列挙型
  - `unicode`: 標準Unicode絵文字
  - `custom`: カスタム絵文字
- **ReactionCount**: 特定の絵文字のリアクション数
  - 0以上の整数
  - 最大値制限（例：999,999）

**メディア関連**
- **MediaType**: メディアの種類を表現
  - `image/jpeg`, `image/png`, `image/gif`, `image/webp`
  - `video/mp4`, `video/webm`
  - `audio/mpeg`, `audio/ogg`
- **MediaMetadata**: メディアのメタデータ
  - width, height（画像・動画）
  - duration（動画・音声）
  - fileSize（バイト数）
  - blurhash（プレビュー用）
- **MediaURL**: メディアのアクセスURLを表現
  - CDN経由の完全URL
  - 署名付きURLの場合は有効期限を含む

**イベント関連**
- **EventType**: イベント種別を表す列挙型
  - `drop_created`: Drop作成
  - `drop_deleted`: Drop削除
  - `reaction_created`: リアクション追加
  - `reaction_deleted`: リアクション削除
- **EventData**: イベントの詳細データ（JSON形式）
  - 最大サイズ: 10KB
  - イベント種別に応じた構造
- **EventStatus**: イベント処理状態
  - `pending`: 処理待ち
  - `processing`: 処理中
  - `completed`: 完了
  - `failed`: 失敗

**投票関連**
- **PollDuration**: 投票期間
  - 5分～7日の範囲
  - ISO 8601 duration形式
- **PollType**: 投票タイプ
  - `single`: 単一選択
  - `multiple`: 複数選択可
- **PollExpiredAt**: 投票期限（UTC）

**時刻・数値**
- **CreatedAt**: 作成日時（UTC、ミリ秒精度）
- **UpdatedAt**: 更新日時（UTC、ミリ秒精度）
- **DeletedAt**: 削除日時（UTC、ミリ秒精度）
- **ProcessedAt**: 処理完了日時（UTC）
- **EditedAt**: 編集日時（UTC、ミリ秒精度）
- **EditDeadline**: 編集期限（UTC）
- **Version**: 楽観的ロック用バージョン番号
- **DisplayOrder**: 表示順序（1から始まる整数）

**スケジュール投稿関連**
- **ScheduledAt**: 投稿予定日時
  - UTC、ミリ秒精度
  - 現在時刻より5分以上先、30日以内
- **ScheduledDropStatus**: スケジュール投稿の状態
  - `draft`: 下書き
  - `scheduled`: スケジュール済み
  - `published`: 公開済み
  - `cancelled`: キャンセル済み
- **ScheduleWindow**: スケジュール実行時間帯
  - 開始時刻と終了時刻のペア
  - 実行遅延許容範囲（デフォルト: ±1分）

### Domain Events (ドメインイベント)

#### DropCreatedEvent
**発生条件**: 新しいDropが正常に作成された時
- **ペイロード**:
  - AggregateID: DropID
  - AuthorID: UserID
  - Content: DropContent
  - Visibility: Visibility
  - MediaAttachmentIDs: []MediaID
  - OccurredAt: time.Time
- **ビジネス意味**: コンテンツが公開され、配信可能になった

#### DropEditedEvent
**発生条件**: Dropが編集された時
- **ペイロード**:
  - AggregateID: DropID
  - EditedBy: UserID
  - OldContent: DropContent
  - NewContent: DropContent
  - RevisionNumber: int
  - OccurredAt: time.Time
- **ビジネス意味**: コンテンツが修正され、信頼性が更新された

#### DropDeletedEvent
**発生条件**: Dropが削除された時
- **ペイロード**:
  - AggregateID: DropID
  - DeletedBy: UserID
  - DeletionReason: DeletionReason
  - OccurredAt: time.Time
- **ビジネス意味**: コンテンツが利用不可になり、関連データの整理が必要

#### ReactionAddedEvent
**発生条件**: リアクションが追加された時
- **ペイロード**:
  - ReactionID: ReactionID
  - DropID: DropID
  - ReactorID: UserID
  - EmojiCode: EmojiCode
  - OccurredAt: time.Time
- **ビジネス意味**: エンゲージメントが発生し、感情表現が記録された

#### ReactionRemovedEvent
**発生条件**: リアクションが削除された時
- **ペイロード**:
  - ReactionID: ReactionID
  - DropID: DropID
  - ReactorID: UserID
  - EmojiCode: EmojiCode
  - OccurredAt: time.Time
- **ビジネス意味**: エンゲージメントが取り消され、感情表現が撤回された

#### PollVotedEvent
**発生条件**: 投票が行われた時
- **ペイロード**:
  - PollID: PollID
  - VoterID: UserID
  - SelectedOptions: []PollOptionID
  - OccurredAt: time.Time
- **ビジネス意味**: 民主的意思決定への参加が記録された

#### PollClosedEvent
**発生条件**: 投票が終了した時
- **ペイロード**:
  - PollID: PollID
  - FinalResults: map[PollOptionID]VoteCount
  - TotalVotes: int
  - OccurredAt: time.Time
- **ビジネス意味**: 意思決定プロセスが完了し、結果が確定した

#### MediaAttachedEvent
**発生条件**: メディアがDropに添付された時
- **ペイロード**:
  - AttachmentID: MediaAttachmentID
  - DropID: DropID
  - MediaID: MediaID
  - MediaType: MediaType
  - Order: int
  - OccurredAt: time.Time
- **ビジネス意味**: ビジュアルコンテンツが追加され、表現が豊かになった

### Domain Services (ドメインサービス)

#### ContentPolicyService
**責務**: コンテンツポリシーの適用と検証
- **メソッド**:
  - `validateContentCompliance(content)`: コンテンツのコンプライアンス検証
  - `applyContentModeration(drop)`: モデレーションルールの適用
  - `checkCulturalAppropriateness(content)`: 文化的適切性のチェック

#### EngagementAnalysisService
**責務**: エンゲージメント分析とスコアリング
- **メソッド**:
  - `calculateEngagementScore(drop)`: エンゲージメントスコアの算出
  - `analyzeReactionPatterns(reactions)`: リアクションパターンの分析
  - `predictViralPotential(drop)`: バイラル可能性の予測

#### PrivacyEnforcementService
**責務**: プライバシーポリシーの実施
- **メソッド**:
  - `enforcePrivacyPolicy(drop, viewer)`: プライバシーポリシーの適用
  - `anonymizeDeletedContent(drop)`: 削除コンテンツの匿名化
  - `validateDataRetention(drop)`: データ保持ポリシーの検証

## ユースケース

### Dropの作成

1.  ユーザーは投稿フォームにテキストを入力し、公開範囲を選択して「Drop」ボタンを押す
2.  (オプション) CWを設定する場合、CWラベルを入力
3.  (オプション) 投票を追加する場合、選択肢、投票タイプ、期限を設定
4.  フロントエンドは `avion-gateway` 経由で `avion-drop` にDrop作成リクエストを送信（認証JWT必須）
5.  CreateDropCommandUseCase がリクエストを処理
6.  DropValidationService でテキスト長（最大5000文字）、文字エンコーディング、禁止語句をチェック
7.  PollValidationService で投票設定の検証（選択肢2-4個、期限5分-7日）
8.  MediaValidationService で添付メディアの検証（最大4つ、形式、サイズ）
9.  DropFactory (Domain Service) で Drop Aggregate を生成
10. Pollが含まれる場合、PollFactory で Poll Aggregate を生成
11. Drop Aggregate の validate() メソッドで全体の妥当性を確認
12. DropRepository 経由でデータベースに永続化（トランザクション内）
13. DropEventPublisher で `drop_created` イベントを Redis Stream に発行
14. CreateDropResponse DTO を生成して返却（DropID、作成日時を含む）
15. (非同期) EventHandler が以下のサービスにイベントを伝播:
    - avion-timeline: タイムライン更新
    - avion-activitypub: Create アクティビティ送信
    - avion-search: インデックス更新

(UIモック: 投稿フォーム)

### Dropの表示 (単一)

1.  ユーザーが特定のDropへのリンクをクリックする、または通知から遷移する
2.  フロントエンドは `avion-gateway` 経由で `avion-drop` に Drop ID を指定した取得リクエストを送信
3.  GetDropQueryUseCase がリクエストを処理
4.  DropCacheService でキャッシュを確認（ヒット率向上のため）
5.  キャッシュミスの場合、DropQueryService 経由で DropRepository から Drop Aggregate を取得
6.  AccessControlService で Drop.canBeViewedBy(userID, isFollower) を呼び出し、閲覧権限を確認
7.  権限がない場合は DropNotFoundException を投げる（403ではなく404で統一）
8.  MediaEnrichmentService で MediaAttachment の詳細情報を補完
9.  ReactionSummaryQueryService で該当Dropのリアクション集計を取得
10. UserReactionService でリクエストユーザーのリアクション状態を確認
11. DropDTO を生成（Drop本体、メディア情報、リアクション情報を統合）
12. DropCacheService にキャッシュを保存（TTL: 5分）
13. フロントエンドは受け取ったDTOをもとにDropを表示

(UIモック: Drop詳細表示)

### ユーザーのDrop一覧表示

1.  ユーザーが特定のユーザーのプロフィールページを開き、Drop一覧タブを選択
2.  フロントエンドは `avion-gateway` 経由で `avion-drop` に UserID と CursorToken を指定したリクエストを送信
3.  GetUserDropsQueryUseCase がリクエストを処理
4.  PaginationValidator で limit（最大50）と cursor の妥当性を検証
5.  UserDropsCacheService でキャッシュを確認（ユーザー単位でキャッシュ）
6.  FollowershipService で閲覧者と対象ユーザーのフォロー関係を確認
7.  DropQueryService でユーザーのDropを取得（CreatedAt降順、カーソルベース）
8.  各Dropに対して AccessControlService で閲覧権限をバッチチェック
9.  閲覧可能なDropのみをフィルタリング
10. ReactionSummaryBatchService で複数Dropのリアクション集計を一括取得
11. MediaBatchEnrichmentService でメディア情報を一括補完
12. DropListDTO を生成（各DropのDTO配列、次ページカーソルを含む）
13. UserDropsCacheService にキャッシュを保存（TTL: 1分）
14. フロントエンドは無限スクロールでDrop一覧を表示

(UIモック: プロフィールページのDropタブ)

### Dropの編集

1.  ユーザーは自身が作成したDropのメニューから「編集」を選択
2.  編集フォームに現在の内容が表示される
3.  ユーザーはテキストを修正して「更新」ボタンを押す
4.  フロントエンドは `avion-gateway` 経由で `avion-drop` に編集リクエストを送信
5.  EditDropCommandUseCase がリクエストを処理
6.  DropRepository から Drop Aggregate を取得（排他ロック付き）
7.  Drop.canBeEditedBy(userID) で編集権限と期限を確認
8.  EditHistoryFactory で EditRevision を生成
9.  Drop.edit() メソッドで編集を実行
10. DropRepository で永続化（編集履歴も含む）
11. DropEventPublisher で `drop_edited` イベントを発行
12. EditDropResponse DTO を返却（編集バージョンを含む）
13. (非同期) EventHandler が編集通知を配信

(UIモック: Drop編集フォーム)

### Dropの削除

1.  ユーザーは自身が作成したDropのメニューから「削除」を選択
2.  確認ダイアログで削除の意思を再確認
3.  フロントエンドは `avion-gateway` 経由で `avion-drop` に Drop ID を指定した削除リクエストを送信（認証JWT必須）
4.  DeleteDropCommandUseCase がリクエストを処理
5.  DropRepository から Drop Aggregate を取得（排他ロック付き）
6.  Drop.canBeDeletedBy(userID) で削除権限を確認（作成者のみ）
7.  権限がない場合は UnauthorizedDropDeletionException を投げる
8.  Drop.markAsDeleted() を呼び出し、DropStatus を deleted に変更
9.  DropRepository で論理削除を実行（DeletedAt に現在時刻を設定）
10. ReactionCleanupService で関連するすべてのReactionを物理削除
11. DropEventPublisher で `drop_deleted` イベントを Redis Stream に発行
12. DropCacheService から該当Dropのキャッシュを即座に削除
13. DeleteDropResponse DTO を返却（削除完了を通知）
14. (非同期) EventHandler が以下のサービスにイベントを伝播:
    - avion-timeline: タイムラインから削除
    - avion-activitypub: Delete アクティビティ送信
    - avion-notification: 関連通知の無効化
    - avion-search: インデックスから削除

(UIモック: Dropメニュー内の削除ボタン)

### Dropへのリアクション追加

1.  ユーザーはDropの下部のリアクションボタンをクリックし、絵文字ピッカーから絵文字を選択
2.  フロントエンドは楽観的更新でUIを即座に反映
3.  `avion-gateway` 経由で `avion-drop` にリアクション追加リクエストを送信（DropID、EmojiCode、認証JWT）
4.  AddReactionCommandUseCase がリクエストを処理
5.  EmojiValidationService で EmojiCode の妥当性を検証（Unicode絵文字またはカスタム絵文字）
6.  DropRepository から対象の Drop Aggregate を取得（存在確認）
7.  Drop.canBeViewedBy() で対象Dropへのアクセス権限を確認
8.  ReactionDuplicationChecker で同一ユーザー・同一Drop・同一絵文字の重複をチェック
9.  重複の場合は ReactionAlreadyExistsException を投げる（冪等性のため200で返却）
10. ReactionFactory で Reaction Aggregate を生成
11. ReactionRepository でトランザクション内で以下を実行:
    - Reaction の永続化
    - ReactionSummary の increment() 呼び出し（なければ新規作成）
12. ReactionEventPublisher で `reaction_created` イベントを Redis Stream に発行
13. AddReactionResponse DTO を返却（ReactionID、更新後のカウントを含む）
14. (非同期) EventHandler が以下のサービスにイベントを伝播:
    - avion-notification: Drop作成者への通知（セルフリアクション除く）
    - avion-activitypub: Like アクティビティ送信

(UIモック: Drop下のリアクションボタン/ピッカー)

### リアクションの削除 (取り消し)

1.  ユーザーは自身が追加したリアクション（ハイライト表示）を再度クリック
2.  フロントエンドは楽観的更新でUIを即座に反映
3.  `avion-gateway` 経由で `avion-drop` にリアクション削除リクエストを送信（DropID、EmojiCode、認証JWT）
4.  RemoveReactionCommandUseCase がリクエストを処理
5.  ReactionQueryService で ReactorUserID、DropID、EmojiCode の組み合わせで Reaction を検索
6.  Reaction が存在しない場合は ReactionNotFoundException（冪等性のため200で返却）
7.  Reaction.canBeDeletedBy(userID) で削除権限を確認（リアクション者本人のみ）
8.  権限がない場合は UnauthorizedReactionDeletionException を投げる
9.  ReactionRepository でトランザクション内で以下を実行:
    - Reaction の物理削除
    - ReactionSummary の decrement() 呼び出し
    - カウントが0になった場合は ReactionSummary も削除
10. ReactionEventPublisher で `reaction_deleted` イベントを Redis Stream に発行
11. RemoveReactionResponse DTO を返却（更新後のカウントを含む）
12. (非同期) EventHandler が以下のサービスにイベントを伝播:
    - avion-activitypub: Undo(Like) アクティビティ送信

(UIモック: 自身が付けたリアクションの表示)

### Dropのリアクション一覧表示

1.  フロントエンドがDropを表示する際、リアクション情報の取得が必要
2.  `avion-gateway` 経由で `avion-drop` にリアクション取得リクエストを送信（DropID）
3.  GetDropReactionsQueryUseCase がリクエストを処理
4.  ReactionSummaryCacheService でキャッシュを確認（DropID単位でキャッシュ）
5.  キャッシュミスの場合、ReactionSummaryQueryService で DropID に関連する ReactionSummary を取得
6.  各 ReactionSummary から EmojiCode と ReactionCount を抽出
7.  認証されたユーザーの場合、UserReactionQueryService で各絵文字への自身のリアクション状態を確認
8.  ReactionSummaryDTO のリストを生成:
    - emojiCode: 絵文字コード
    - count: リアクション数（999+で表示）
    - hasReacted: 現在のユーザーがリアクションしているか
    - recentUsers: 最近リアクションしたユーザー（オプション、最大3名）
9.  人気順（カウント降順）にソートして上位20個まで返却
10. ReactionSummaryCacheService にキャッシュを保存（TTL: 30秒）
11. フロントエンドは絵文字とカウントをDropの下部に表示

(UIモック: Drop下に表示されるリアクション集計)

### 引用Drop（Quote Post）の作成

1.  ユーザーは他のDropの「引用」ボタンをクリック
2.  引用フォームが開き、元のDropが引用プレビューとして表示される
3.  ユーザーは自身のコメントを追加して投稿
4.  フロントエンドは `avion-gateway` 経由で引用Drop作成リクエストを送信
5.  CreateQuoteDropCommandUseCase がリクエストを処理
6.  元のDropの存在確認とアクセス権限を検証
7.  QuoteDropFactory で Quote型の Drop Aggregate を生成
8.  DropRepository で永続化（引用元への参照を含む）
9.  DropEventPublisher で `drop_quoted` イベントを発行
10. (非同期) 引用元の作成者に通知を送信

(UIモック: 引用投稿フォーム)

### 投票（Poll）への参加

1.  ユーザーは投票付きDropの選択肢を選択
2.  「投票」ボタンをクリック
3.  フロントエンドは `avion-gateway` 経由で投票リクエストを送信
4.  VotePollCommandUseCase がリクエストを処理
5.  PollRepository から Poll Aggregate を取得
6.  Poll.canVote() で投票可能かチェック（期限、重複投票）
7.  Poll.vote() メソッドで投票を記録
8.  PollRepository で永続化
9.  PollEventPublisher で `poll_voted` イベントを発行
10. VotePollResponse DTOを返却（最新の集計結果を含む）

(UIモック: 投票UI)

### スケジュール投稿の作成

1.  ユーザーは投稿フォームで「予約投稿」オプションを選択
2.  日時選択UIで投稿予定日時を設定（5分以上先、30日以内）
3.  投稿内容、公開範囲、その他オプションを設定
4.  「予約する」ボタンをクリック
5.  フロントエンドは `avion-gateway` 経由で `avion-drop` にスケジュール投稿作成リクエストを送信
6.  CreateScheduledDropCommandUseCase がリクエストを処理
7.  ScheduleValidator で予約日時の妥当性を検証
8.  DraftContentFactory で DraftContent Entity を生成
9.  ScheduledDropFactory で ScheduledDrop Aggregate を生成（status: scheduled）
10. ScheduledDropRepository で永続化
11. ScheduledDropEventPublisher で `scheduled_drop_created` イベントを発行
12. CreateScheduledDropResponse DTO を返却（ScheduledDropID、予約日時を含む）

(UIモック: 予約投稿フォーム)

### 下書きの保存

1.  ユーザーは投稿フォームで内容を入力後、「下書き保存」ボタンをクリック
2.  フロントエンドは `avion-gateway` 経由で `avion-drop` に下書き保存リクエストを送信
3.  SaveDraftCommandUseCase がリクエストを処理
4.  DraftContentFactory で DraftContent Entity を生成
5.  ScheduledDropFactory で ScheduledDrop Aggregate を生成（status: draft）
6.  ScheduledDropRepository で永続化
7.  SaveDraftResponse DTO を返却（ScheduledDropIDを含む）
8.  フロントエンドは「下書きを保存しました」と表示

(UIモック: 下書き保存ボタン)

### スケジュール投稿の一覧表示

1.  ユーザーは「予約投稿」メニューを選択
2.  フロントエンドは `avion-gateway` 経由で `avion-drop` に一覧取得リクエストを送信
3.  GetScheduledDropsQueryUseCase がリクエストを処理
4.  ScheduledDropQueryService でユーザーのスケジュール投稿を取得
5.  状態別（draft, scheduled）にフィルタリング
6.  予約日時の昇順でソート
7.  ScheduledDropListDTO を生成（各投稿の概要、予約日時、状態を含む）
8.  フロントエンドはタブ形式で「下書き」「予約済み」を表示

(UIモック: 予約投稿一覧画面)

### スケジュール投稿の編集

1.  ユーザーは予約投稿一覧から編集したい投稿を選択
2.  編集フォームが開き、現在の内容と予約日時が表示される
3.  内容や予約日時を修正して「更新」ボタンをクリック
4.  フロントエンドは `avion-gateway` 経由で編集リクエストを送信
5.  UpdateScheduledDropCommandUseCase がリクエストを処理
6.  ScheduledDropRepository から ScheduledDrop Aggregate を取得
7.  ScheduledDrop.canBeEditedBy(userID) で編集権限を確認
8.  ScheduleValidator で新しい予約日時を検証（変更がある場合）
9.  ScheduledDrop.updateContent() と schedule() で更新
10. ScheduledDropRepository で永続化
11. ScheduledDropEventPublisher で `scheduled_drop_updated` イベントを発行
12. UpdateScheduledDropResponse DTO を返却

(UIモック: スケジュール投稿編集フォーム)

### スケジュール投稿のキャンセル

1.  ユーザーは予約投稿一覧から「キャンセル」を選択
2.  確認ダイアログで「この予約投稿をキャンセルしますか？」と表示
3.  「キャンセル」ボタンをクリック
4.  フロントエンドは `avion-gateway` 経由でキャンセルリクエストを送信
5.  CancelScheduledDropCommandUseCase がリクエストを処理
6.  ScheduledDropRepository から ScheduledDrop Aggregate を取得
7.  ScheduledDrop.canBeCancelledBy(userID) でキャンセル権限を確認
8.  ScheduledDrop.cancel() でステータスを cancelled に変更
9.  ScheduledDropRepository で永続化
10. ScheduledDropEventPublisher で `scheduled_drop_cancelled` イベントを発行
11. CancelScheduledDropResponse DTO を返却
12. フロントエンドは一覧を更新

(UIモック: キャンセル確認ダイアログ)

### スケジュール投稿の自動実行

1.  ScheduledDropExecutorService（cron job）が定期的に実行（例：1分ごと）
2.  ScheduledDropPublisher.findDueScheduledDrops() で公開時刻に達した投稿を検索
3.  各スケジュール投稿に対して以下を実行:
    - ScheduledDrop.shouldBePublished(currentTime) で実行確認
    - DraftContentConverter.toDrop() で Drop Aggregate を生成
    - DropRepository で Drop を永続化
    - ScheduledDrop.publish() でステータスを published に変更
    - ScheduledDropRepository で更新
4.  DropEventPublisher で `drop_created` イベントを発行（通常投稿と同じ）
5.  ScheduledDropEventPublisher で `scheduled_drop_published` イベントを発行
6.  失敗した場合は ScheduledDropPublisher.handlePublishFailure() で処理
    - リトライ回数をカウント
    - 最大リトライ回数を超えたら failed ステータスに変更
    - エラー通知を送信

(システムフロー図: スケジュール実行プロセス)

## 機能要求

### ドメインロジック要求

*   **Drop管理:**
    *   Dropを集約として管理し、ライフサイクル全体の整合性を保つ
    *   テキスト制限、公開範囲制御、アクセス権限の検証をドメインロジックで実装
    *   削除時の関連データのカスケード処理
    *   編集履歴の管理と編集期限の制御
    *   CW設定時の表示制御
    *   投票機能の統合管理

*   **Reaction管理:**
    *   Reactionを集約として管理し、重複リアクションの防止
    *   リアクション集計の効率的な管理
    *   ユーザーごとのリアクション状態の追跡

*   **ScheduledDrop管理:**
    *   スケジュール投稿を集約として管理し、ライフサイクル全体の整合性を保つ
    *   予約日時の検証（5分以上先、30日以内）
    *   下書きとスケジュール済み投稿の状態管理
    *   自動実行時のエラーハンドリングとリトライ機構
    *   公開後の編集不可制御

### APIエンドポイント要求

*   **Drop API:**
    *   DropのCRUD操作のためのgRPC APIを提供
    *   認証が必要なエンドポイントはメタデータでユーザーIDを受け取る
    *   ページネーションをサポート

*   **Reaction API:**
    *   リアクションの追加、削除、集計取得のためのgRPC APIを提供
    *   リアルタイムに近い集計情報の提供

*   **ScheduledDrop API:**
    *   スケジュール投稿のCRUD操作のためのgRPC APIを提供
    *   下書き保存、スケジュール設定、編集、キャンセル機能
    *   ユーザーごとのスケジュール投稿一覧取得（状態別フィルタリング対応）
    *   スケジュール実行結果の照会

### データ要求

*   **本文:** 最大文字数制限を設けること (5000文字、設定可能)。Unicode文字を正しく扱えること。
*   **公開範囲:** Dropごとに公開範囲 (public, unlisted, followers_only, private) を設定できること。デフォルト値を設定できること。
*   **一意なID:** 各Dropにはシステム全体で一意なIDが付与されること (例: UUID, Snowflake ID)。
*   **タイムスタンプ:** 作成日時、最終更新日時、編集日時を記録すること。
*   **編集機能:** 編集履歴の保存、編集期限の管理（作成後30分など）。
*   **CW機能:** コンテンツ警告ラベルの設定と表示制御。
*   **引用機能:** 引用元Dropへの参照管理、引用チェーンの追跡。
*   **投票機能:** 
    *   2-4個の選択肢、単一/複数選択対応
    *   投票期限5分-7日、投票結果の集計
    *   投票者の記録（誰が何に投票したか）
*   **リアクション対象:** Dropに対してリアクションできること。
*   **絵文字:** Unicode絵文字とカスタム絵文字をサポート。絵文字コード (例: `:smile:`, Unicode文字自体、`:custom_emoji:`) で識別できること。
*   **一意性:** 1ユーザーは1つのDropに対して同じ絵文字で複数回リアクションできないこと。
*   **集計:** Dropごとに、どの絵文字が何回リアクションされたかを効率的に集計できること。
*   **スケジュール投稿:**
    *   下書きとスケジュール済み投稿の永続化
    *   予約日時の記録（UTC、ミリ秒精度）
    *   ステータス管理（draft, scheduled, published, cancelled）
    *   1ユーザーあたりのスケジュール投稿数制限（例：最大100件）
    *   実行履歴とエラーログの記録

## セキュリティ実装ガイドライン

avion-dropサービスは、ユーザー生成コンテンツを扱うため、以下のセキュリティガイドラインに従って実装します：

### 必須実装項目

1. **XSS防止** ([XSS防止ガイドライン](../common/security/xss-prevention.md))
   - 投稿本文、引用、リプライのHTMLサニタイゼーション
   - カスタム絵文字名のエスケープ処理
   - ハッシュタグ、メンションの適切なエンコーディング
   - メディア埋め込み時のサニタイゼーション
   - CSPヘッダーによるインラインスクリプト実行防止

2. **SQLインジェクション防止** ([SQLインジェクション防止](../common/security/sql-injection-prevention.md))
   - 投稿検索、ハッシュタグ検索でのパラメータ化クエリ
   - タイムライン取得時のPrepared Statements使用
   - 投票集計処理でのSQLインジェクション対策
   - 動的フィルタリング条件の安全な構築

3. **セキュリティヘッダー** ([セキュリティヘッダーガイドライン](../common/security/security-headers.md))
   - X-Content-Type-Options: nosniff設定
   - X-Frame-Options: DENY設定（埋め込み防止）
   - Content-Security-Policy設定（XSS対策強化）
   - Referrer-Policy設定（情報漏洩防止）

### 実装時の注意事項

- **入力検証**: 投稿本文の文字数制限、メディアURL検証
- **出力エンコーディング**: 投稿表示時のコンテキストに応じたエスケープ
- **リアクション検証**: カスタム絵文字の存在確認とアクセス権限チェック
- **投票の整合性**: 二重投票防止、投票期限の厳格な管理
- **削除権限**: 投稿削除時の所有者確認
- **編集履歴**: 編集内容の監査ログ記録
- **レート制限**: 投稿作成、リアクション追加の頻度制限

## 技術的要求

### レイテンシ

*   Drop作成: 平均 200ms 以下
*   Drop取得 (単一): 平均 100ms 以下
*   ユーザーDrop一覧取得 (1ページあたり): 平均 300ms 以下
*   リアクション追加/削除: 平均 150ms 以下
*   リアクション集計取得: 平均 100ms 以下 (キャッシュ活用時)
*   スケジュール投稿作成/更新: 平均 200ms 以下
*   スケジュール投稿一覧取得: 平均 300ms 以下
*   スケジュール実行遅延: 予定時刻から最大 1分以内

### 可用性

*   Dropの作成と取得、およびリアクションの追加・削除・表示は高可用性が求められる。Kubernetes上での運用を前提とし、複数レプリカによる冗長構成をとる。

### スケーラビリティ

*   リアクション数はDrop数×ユーザー数に比例して増加する可能性があるため、データベースの書き込み・読み取り性能が重要。
*   リアクション集計クエリがボトルネックにならないように、適切なインデックス設計やキャッシュ戦略が必要。Redisによるカウントキャッシュなどが有効。

### セキュリティ

*   **入力検証:** Drop本文に含まれる可能性のある悪意のあるスクリプト等 (XSS) を適切にサニタイズ、または表示時にエスケープすること。
*   **アクセス制御:** Dropの公開範囲設定に基づき、不正なアクセスを防ぐこと。他人のDropを不正に編集・削除できないようにすること。他人になりすましてリアクションを追加・削除できないようにすること。
*   **削除処理:** 削除されたDropが意図せず参照されないようにすること (特にキャッシュなど)。削除されたDropに関連するリアクションデータも適切に処理すること。

### データ整合性

*   リアクションのカウント数と実際のリアクションレコードの整合性を保つこと。
*   削除されたDropやユーザーに関連するリアクションデータを適切に処理すること (例: カスケード削除、定期的なクリーンアップ)。

### その他技術要件

*   **ステートレス:** サービス自体は状態を持たず、水平スケールが可能であること。集計キャッシュはRedisで管理する。
*   **Observability:** OpenTelemetry SDKを導入し、トレース・メトリクス・ログを出力可能にすること。API Gatewayからトレースコンテキストを受け取り、他のサービスへのイベント発行時にもコンテキストを伝播すること。

### リアクション集計パフォーマンス要件

*   **高パフォーマンス集計:** 人気のあるDropに数千〜数万のリアクションが付いても、100ms以下で集計結果を返せること。
*   **リアルタイム性:** リアクション追加・削除時の集計更新が即座に反映されること。
*   **スケーラビリティ:** リアクション数に対して線形以下のパフォーマンス特性を維持すること。

## 決まっていないこと

*   Drop編集機能の具体的な仕様 (編集可能な期間、編集履歴の表示有無など)
*   引用Drop、リポスト (Boost) のデータモデルとAPI仕様
*   ハッシュタグの抽出・管理方法 (将来的に実装する場合)
*   メンションの抽出・管理方法 (将来的に実装する場合)
*   Dropの物理削除 vs 論理削除の方針
*   カスタム絵文字のサポート範囲と実装方法
*   ActivityPubでのリアクション表現方法 (`Like` を使うか、カスタムアクティビティか)
*   ~~リアクションデータの具体的なDBスキーマ設計 (集計効率を考慮)~~ → 専用集計テーブルを導入することで解決
*   ~~キャッシュ戦略の詳細 (どの情報をどのキーでキャッシュするか)~~ → 永続的なキャッシュとイベント駆動更新で解決
*   ~~大量リアクションが付いた場合の集計パフォーマンス対策~~ → 非正規化とインメモリキャッシュで解決
*   スケジュール実行の具体的な実装方法（Kubernetes CronJob、専用ワーカー等）
*   スケジュール投稿の最大保持期間（公開後の履歴保持期間）
*   タイムゾーン対応（ユーザーのローカルタイムゾーンでの表示）
*   繰り返し投稿機能の実装有無（定期投稿）
*   下書きの自動保存機能の実装詳細
*   スケジュール投稿実行失敗時の通知方法（メール、プッシュ通知等）
