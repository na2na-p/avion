# Design Doc: avion-drop

**Author:** Cline
**Last Updated:** 2025/03/30

## 1. Summary (これは何？)

- **一言で:** Avionにおける投稿（Drop）の作成、取得、削除などのライフサイクル管理、および投稿に対する絵文字リアクション機能を提供するマイクロサービスを実装します。
- **目的:** Dropデータの永続化、基本的なアクセス制御（公開範囲に基づく）、関連操作（削除）、およびリアクション機能（追加・削除・集計）を提供します。他のサービス（Timeline, Search, ActivityPub, Notificationなど）へのイベント通知も行います。

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
- Drop作成から公開、表示までの完全なライフサイクル
- プライバシー設定（公開範囲）による表示制御の確認
- 絵文字リアクション追加・削除・集計機能の完全テスト
- Drop削除と関連データの整合性確認
- メディア添付Dropの作成と表示フロー
- リプライ機能とスレッド構造の管理
- Drop検索とインデックス更新の連携確認
- ActivityPub連携による他インスタンスとの投稿同期

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

- SNSの根幹機能である投稿管理機能を提供するため。
- Misskeyライクな表現豊かなインタラクションを実現するため。
- マイクロサービスアーキテクチャにおいて、投稿関連の機能を独立させることで、変更容易性とスケーラビリティを確保する。
- 投稿とリアクションを統合することで、データ整合性とパフォーマンスを向上させる。
- [PRD: avion-drop](./prd.md)
- [Avion アーキテクチャ概要](../common/architecture.md)

## 5. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

- Dropの作成、取得、編集、物理削除を行うgRPC APIの実装。
- DropデータのPostgreSQLへの永続化。
- Dropへの絵文字リアクション追加API (gRPC) の実装。
- リアクション削除API (gRPC) の実装。
- 特定Dropのリアクション集計取得API (gRPC) の実装 (絵文字ごとのカウント、自身がリアクションしたか)。
- リアクションデータのPostgreSQLへの永続化。
- リアクション集計結果のRedisキャッシュ (HashおよびSet)。
- Drop作成、編集、削除、リアクション追加/削除時にイベントを発行 (Redis Pub/Sub) し、他のサービス (Timeline, Search, ActivityPub, Notification) と連携する。
- Dropの公開範囲 (`visibility`) に基づいた基本的なアクセス制御チェック (取得時)。
- 添付メディア情報 (`avion-media` が管理するID/URL) の関連付け。
- Go言語で実装し、Kubernetes上でのステートレス運用を前提とする。
- OpenTelemetryによるトレーシング・メトリクス・ロギング対応。

### Non-Goals (やらないこと)
- **タイムライン生成:** `avion-timeline` が担当。
- **通知生成:** `avion-notification` が担当。
- **メディアファイルの保存・配信:** `avion-media` が担当。
- **全文検索インデックス作成:** `avion-search` が担当 (本サービスはイベント発行のみ)。
- **ハッシュタグ/メンション解析 (初期)。**
- **複雑なアクセス制御ロジック:** フォロワー関係に基づくアクセス判定などは行わない。呼び出し元 (Gateway/Authz) が事前に行う前提。
- **削除済みDropの復元機能。**
- **絵文字自体の管理 (カスタム絵文字含む):** 初期段階では対象外。
- **リアクションに基づくタイムラインソート:** `avion-timeline` の将来的な拡張。
- **リアクション履歴の詳細ログ永続化:** 集計結果の保持を主とする。

## 5.5. セキュリティ実装ガイドライン

avion-dropサービスでは、以下のセキュリティガイドラインに従って実装を行います：

### 必須セキュリティ実装

1. **XSS防止** ([XSS防止ガイドライン](../common/security/xss-prevention.md))
   - 投稿本文のHTMLサニタイゼーション処理
   - カスタム絵文字名のエスケープ
   - メディア埋め込み時のセキュアな処理
   - CSPヘッダーの適切な設定

2. **SQLインジェクション防止** ([SQLインジェクション防止](../common/security/sql-injection-prevention.md))
   - 全クエリでPrepared Statementsを使用
   - 動的クエリ生成の完全禁止
   - ハッシュタグ検索の安全な実装

3. **セキュリティヘッダー** ([セキュリティヘッダーガイドライン](../common/security/security-headers.md))
   - X-Content-Type-Options設定
   - X-Frame-Options設定
   - CSP設定による防御の多層化

### セキュリティ実装チェックリスト

- [ ] 投稿作成時の入力検証とサニタイゼーション
- [ ] リアクション追加時の絵文字検証
- [ ] 投稿検索でのSQLインジェクション対策
- [ ] メディアURL検証とサニタイゼーション
- [ ] 削除権限の厳格な確認
- [ ] セキュリティヘッダーの設定

## 6. Architecture (どうやって作る？)

### 5.1. レイヤードアーキテクチャ (DDD準拠)

#### Domain Layer (ドメイン層)

**Aggregates:**
- Drop: 投稿の基本的なコンテンツとメタデータを管理する純粋なコンテンツ集約
- Reaction: ユーザーの感情表現とエンゲージメントを管理する独立した集約
- MediaAttachment: 投稿に関連するメディアコンテンツを独立して管理
- Poll: コミュニティの意見収集と民主的な意思決定を支援する独立した集約
- Bookmark: 個人的な情報整理とコンテンツキュレーションを支援する独立した集約
- ContentWarning: コンテンツの安全な閲覧環境を提供する独立した集約
- EditHistory: コンテンツの変更履歴と透明性を管理する独立した集約
- Thread: スレッド形式のコンテンツ管理とDrop順序制御
- Reply: 返信の管理と会話スレッドの構築
- ContentRelation: コンテンツ間の関係（メンション、ハッシュタグ、引用）管理

**Entities:**
- MediaAttachment: 投稿に添付されたメディア情報
- EditRevision: 投稿の編集履歴
- PollOption: 投票の個別選択肢
- PollVote: ユーザーの投票情報
- ContentWarning: コンテンツ警告情報
- Renote: リノート（引用投稿）情報
- ReactionDetail: 個別リアクション詳細
- DropReport: 投稿に対する通報情報
- ThreadItem: スレッド内の個別アイテム
- ThreadOrder: スレッド内のDrop順序
- ThreadMetadata: スレッドのメタデータ
- ReplyChain: 返信チェーン情報
- ConversationContext: 会話コンテキスト
- QuoteRelation: 引用関係情報

**Value Objects:**
- DropID, UserID, ReactionID, PollID, BookmarkID, DraftID, ScheduledDropID, ReportID
- ThreadID, ReplyID, RelationID, ConversationID
- DropText, DropContent, ContentType
- Visibility, ReplyToDropID, RenoteDropID
- EmojiCode, ReactionType, ReactionCount
- PollOptionID, PollOptionText, VoteCount, PollExpiry, PollStatus
- MediaID, MediaType, MediaURL, MediaOrder, AltText
- ScheduledAt, PublishedAt, EditedAt
- DropStatus, DraftStatus, ReportReason, ReportStatus
- HashTag, Mention, URL
- CreatedAt, UpdatedAt, DeletedAt
- RetryCount, ErrorMessage, ProcessingStatus
- ThreadStatus, ThreadType, MaxThreadItems, ThreadPosition
- ReplyDepth, MaxReplyDepth, ConversationStatus
- RelationType, RelationStrength, SourceDropID, TargetDropID

**Domain Events (ビジネス意味を持つイベント):**
- DropCreatedEvent: コンテンツが公開され配信可能になった
  ```go
  type DropCreatedEvent struct {
      AggregateID DropID
      AuthorID    UserID
      Content     DropContent
      Visibility  Visibility
      OccurredAt  time.Time
  }
  ```
- DropEditedEvent: コンテンツが修正され信頼性が更新された
- DropDeletedEvent: コンテンツが利用不可になり関連データの整理が必要
- ReactionAddedEvent: エンゲージメントが発生し感情表現が記録された
- ReactionRemovedEvent: エンゲージメントが取り消され感情表現が撤回された
- PollVotedEvent: 民主的意思決定への参加が記録された
- PollClosedEvent: 意思決定プロセスが完了し結果が確定した
- MediaAttachedEvent: ビジュアルコンテンツが追加され表現が豊かになった
- DropLikedEvent: Dropいいねイベント
- DropUnlikedEvent: いいね取り消しイベント
- DropSharedEvent: Drop共有イベント
- DropBookmarkedEvent: Dropブックマークイベント
- DropUnbookmarkedEvent: ブックマーク解除イベント
- DropRepostedEvent: Dropリポストイベント
- ReactionAggregatedEvent: リアクション集計完了イベント
- ThreadCreatedEvent: スレッド作成イベント
- ThreadUpdatedEvent: スレッド更新イベント
- DropAddedToThreadEvent: スレッドにDrop追加イベント
- ThreadReorderedEvent: スレッド順序変更イベント
- ThreadSplitEvent: スレッド分割イベント
- ThreadMergedEvent: スレッド結合イベント
- ThreadClosedEvent: スレッド閉鎖イベント
- ReplyCreatedEvent: 返信作成イベント
- ReplyDeletedEvent: 返信削除イベント
- QuoteDropCreatedEvent: 引用Drop作成イベント
- MentionAddedEvent: メンション追加イベント
- HashtagAddedEvent: ハッシュタグ追加イベント
- LinkAttachedEvent: リンク添付イベント
- MediaReferencedEvent: メディア参照イベント
- DraftSavedEvent: 下書き保存イベント
- DraftDiscardedEvent: 下書き破棄イベント
- DraftPublishedEvent: 下書き公開イベント
- EditHistoryRecordedEvent: 編集履歴記録イベント
- VersionCreatedEvent: バージョン作成イベント
- VersionRestoredEvent: バージョン復元イベント
- PollCreatedEvent: 投票作成イベント
- PollVotedEvent: 投票実行イベント
- PollClosedEvent: 投票終了イベント
- DropPinnedEvent: Drop固定イベント
- DropUnpinnedEvent: Drop固定解除イベント
- DropReportedEvent: Drop通報イベント
- ReportResolvedEvent: 通報解決イベント
- DropImpressionRecordedEvent: Drop閲覧記録イベント
- DropMarkedAsSensitiveEvent: センシティブマーク付与イベント
- DropUnmarkedAsSensitiveEvent: センシティブマーク解除イベント

**Domain Services (クロス集約のビジネスロジック):**
- ContentPolicyService: コンテンツポリシーの適用と検証
  - `validateContentCompliance(content)`: コンテンツのコンプライアンス検証
  - `applyContentModeration(drop)`: モデレーションルールの適用
  - `checkCulturalAppropriateness(content)`: 文化的適切性のチェック
- EngagementAnalysisService: エンゲージメント分析とスコアリング
  - `calculateEngagementScore(drop)`: エンゲージメントスコアの算出
  - `analyzeReactionPatterns(reactions)`: リアクションパターンの分析
  - `predictViralPotential(drop)`: バイラル可能性の予測
- PrivacyEnforcementService: プライバシーポリシーの実施
  - `enforcePrivacyPolicy(drop, viewer)`: プライバシーポリシーの適用
  - `anonymizeDeletedContent(drop)`: 削除コンテンツの匿名化
  - `validateDataRetention(drop)`: データ保持ポリシーの検証
- ThreadService: スレッド管理と順序制御のビジネスルール統括
- ReplyService: 返信と会話スレッド管理のビジネスルール統括
- ContentRelationService: コンテンツ間関係管理のビジネスルール統括
**Repository Interfaces (集約ごとの単一責任):**
- DropRepository: Drop集約専用の永続化インターフェース
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_drop_repository.go -package=mocks
  type DropRepository interface {
      Save(ctx context.Context, drop *Drop) error
      FindByID(ctx context.Context, id DropID) (*Drop, error)
      Delete(ctx context.Context, id DropID) error
      // Drop集約のみを扱う、他の集約は扱わない
  }
  ```
- ReactionRepository: Reaction集約専用の永続化インターフェース
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_reaction_repository.go -package=mocks
  type ReactionRepository interface {
      Save(ctx context.Context, reaction *Reaction) error
      FindByUserAndDrop(ctx context.Context, userID UserID, dropID DropID) (*Reaction, error)
      Delete(ctx context.Context, id ReactionID) error
      // Reaction集約のみを扱う
  }
  ```
- MediaAttachmentRepository: MediaAttachment集約専用の永続化インターフェース
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_media_attachment_repository.go -package=mocks
  type MediaAttachmentRepository interface {
      Save(ctx context.Context, media *MediaAttachment) error
      FindByDropID(ctx context.Context, dropID DropID) ([]*MediaAttachment, error)
      Delete(ctx context.Context, id MediaAttachmentID) error
      // MediaAttachment集約のみを扱う
  }
  ```
- PollRepository: Poll集約専用の永続化インターフェース
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_poll_repository.go -package=mocks
  type PollRepository interface {
      Save(ctx context.Context, poll *Poll) error
      FindByID(ctx context.Context, id PollID) (*Poll, error)
      Update(ctx context.Context, poll *Poll) error
      // Poll集約のみを扱う
  }
  ```
- BookmarkRepository: Bookmark集約専用の永続化インターフェース
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_bookmark_repository.go -package=mocks
  type BookmarkRepository interface {
      Save(ctx context.Context, bookmark *Bookmark) error
      FindByUserID(ctx context.Context, userID UserID) ([]*Bookmark, error)
      Delete(ctx context.Context, id BookmarkID) error
      // Bookmark集約のみを扱う
  }
  ```
- ContentWarningRepository: ContentWarning集約専用の永続化インターフェース
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_content_warning_repository.go -package=mocks
  ```
- EditHistoryRepository: EditHistory集約専用の永続化インターフェース
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_edit_history_repository.go -package=mocks
  ```
- ThreadRepository: Thread集約の永続化インターフェース
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_thread_repository.go -package=mocks
  ```
- ReplyRepository: Reply集約の永続化インターフェース
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_reply_repository.go -package=mocks
  ```
- ContentRelationRepository: ContentRelation集約の永続化インターフェース
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_content_relation_repository.go -package=mocks
  ```

#### Use Case Layer (ユースケース層)
- **Command Use Cases (更新系):**
  - CreateDropCommandUseCase: Drop作成処理（POSTリクエスト用）
  - UpdateDropCommandUseCase: Drop編集処理（PATCHリクエスト用）
  - DeleteDropCommandUseCase: Drop削除処理（DELETEリクエスト用）
  - AddReactionCommandUseCase: リアクション追加処理（POSTリクエスト用）
  - RemoveReactionCommandUseCase: リアクション削除処理（DELETEリクエスト用）
  - RenoteDropCommandUseCase: リノート処理（POSTリクエスト用）
  - UnrenoteDropCommandUseCase: リノート解除処理（DELETEリクエスト用）
  - BookmarkDropCommandUseCase: ブックマーク追加処理（POSTリクエスト用）
  - UnbookmarkDropCommandUseCase: ブックマーク解除処理（DELETEリクエスト用）
  - PinDropCommandUseCase: Drop固定処理（POSTリクエスト用）
  - UnpinDropCommandUseCase: Drop固定解除処理（DELETEリクエスト用）
  - CreatePollCommandUseCase: 投票作成処理（POSTリクエスト用）
  - VotePollCommandUseCase: 投票処理（POSTリクエスト用）
  - FavoriteDropCommandUseCase: お気に入り追加処理（POSTリクエスト用）
  - UnfavoriteDropCommandUseCase: お気に入り解除処理（DELETEリクエスト用）
  - SaveDraftCommandUseCase: 下書き保存処理（POSTリクエスト用）
  - UpdateDraftCommandUseCase: 下書き更新処理（PATCHリクエスト用）
  - DeleteDraftCommandUseCase: 下書き削除処理（DELETEリクエスト用）
  - PublishDraftCommandUseCase: 下書きから投稿処理（POSTリクエスト用）
  - ScheduleDropCommandUseCase: 予約投稿作成処理（POSTリクエスト用）
  - UpdateScheduledDropCommandUseCase: 予約投稿更新処理（PATCHリクエスト用）
  - CancelScheduledDropCommandUseCase: 予約投稿キャンセル処理（DELETEリクエスト用）
  - ReportDropCommandUseCase: Drop通報処理（POSTリクエスト用）
  - ResolveReportCommandUseCase: 通報解決処理（PATCHリクエスト用）
  - RecordDropImpressionCommandUseCase: Drop閲覧記録処理（POSTリクエスト用）
  - MarkDropAsSensitiveCommandUseCase: センシティブマーク付与処理（PATCHリクエスト用）
  - UnmarkDropAsSensitiveCommandUseCase: センシティブマーク解除処理（PATCHリクエスト用）
  - CreateThreadCommandUseCase: スレッド作成処理（POSTリクエスト用）
  - AddToThreadCommandUseCase: スレッドへDrop追加処理（POSTリクエスト用）
  - ReorderThreadCommandUseCase: スレッド順序変更処理（PATCHリクエスト用）
  - SplitThreadCommandUseCase: スレッド分割処理（POSTリクエスト用）
  - MergeThreadCommandUseCase: スレッド結合処理（POSTリクエスト用）
  - CloseThreadCommandUseCase: スレッド閉鎖処理（PATCHリクエスト用）
  - CreateReplyCommandUseCase: 返信作成処理（POSTリクエスト用）
  - DeleteReplyCommandUseCase: 返信削除処理（DELETEリクエスト用）
  - QuoteDropCommandUseCase: Drop引用処理（POSTリクエスト用）
  - AddMentionCommandUseCase: メンション追加処理（POSTリクエスト用）
  - AddHashtagCommandUseCase: ハッシュタグ追加処理（POSTリクエスト用）
- **Query Use Cases (参照系):**
  - GetDropQueryUseCase: Drop取得処理（GETリクエスト用）
  - GetDropsByUserIDQueryUseCase: ユーザー別Drop取得処理（GETリクエスト用）
  - GetReactionSummaryQueryUseCase: リアクション集計取得（GETリクエスト用）
  - GetDropRepliesQueryUseCase: Drop返信一覧取得（GETリクエスト用）
  - GetDropRenotesQueryUseCase: Dropリノート一覧取得（GETリクエスト用）
  - GetBookmarkedDropsQueryUseCase: ブックマーク済みDrop一覧取得（GETリクエスト用）
  - GetPinnedDropsQueryUseCase: 固定Drop一覧取得（GETリクエスト用）
  - GetPollResultsQueryUseCase: 投票結果取得（GETリクエスト用）
  - GetDropThreadQueryUseCase: スレッド（会話）取得（GETリクエスト用）
  - GetFavoriteDropsQueryUseCase: お気に入りDrop一覧取得（GETリクエスト用）
  - GetDropFavoritesQueryUseCase: Dropのお気に入りユーザー取得（GETリクエスト用）
  - GetDraftsQueryUseCase: 下書き一覧取得（GETリクエスト用）
  - GetDraftQueryUseCase: 下書き詳細取得（GETリクエスト用）
  - GetScheduledDropsQueryUseCase: 予約投稿一覧取得（GETリクエスト用）
  - GetDropReportsQueryUseCase: Drop通報一覧取得（GETリクエスト用）
  - GetReportDetailsQueryUseCase: 通報詳細取得（GETリクエスト用）
  - GetDropImpressionCountQueryUseCase: Drop閲覧数取得（GETリクエスト用）
  - GetDropAnalyticsQueryUseCase: Drop分析データ取得（GETリクエスト用）
  - GetDropsByHashtagQueryUseCase: ハッシュタグ別Drop取得（GETリクエスト用）
  - GetDropMentionsQueryUseCase: メンション一覧取得（GETリクエスト用）
  - GetTrendingHashtagsQueryUseCase: トレンドハッシュタグ取得（GETリクエスト用）
  - GetDropEditHistoryQueryUseCase: Drop編集履歴取得（GETリクエスト用）
  - GetThreadQueryUseCase: スレッド詳細取得（GETリクエスト用）
  - GetThreadDropsQueryUseCase: スレッド内Drop一覧取得（GETリクエスト用）
  - GetUserThreadsQueryUseCase: ユーザーのスレッド一覧取得（GETリクエスト用）
  - GetReplyChainQueryUseCase: 返信チェーン取得（GETリクエスト用）
  - GetConversationContextQueryUseCase: 会話コンテキスト取得（GETリクエスト用）
  - GetQuotedDropsQueryUseCase: 引用Drop一覧取得（GETリクエスト用）
  - GetDropRelationsQueryUseCase: Drop関係情報取得（GETリクエスト用）
- **Query Service Interfaces:**
  - DropQueryService: Drop参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_drop_query_service.go -package=mocks
    ```
  - ReactionSummaryQueryService: リアクション集計参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_reaction_summary_query_service.go -package=mocks
    ```
  - RenoteQueryService: リノート参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_renote_query_service.go -package=mocks
    ```
  - BookmarkQueryService: ブックマーク参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_bookmark_query_service.go -package=mocks
    ```
  - PollQueryService: 投票参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_poll_query_service.go -package=mocks
    ```
  - FavoriteQueryService: お気に入り参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_favorite_query_service.go -package=mocks
    ```
  - DraftQueryService: 下書き参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_draft_query_service.go -package=mocks
    ```
  - ScheduledDropQueryService: 予約投稿参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_scheduled_drop_query_service.go -package=mocks
    ```
  - DropReportQueryService: Drop通報参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_drop_report_query_service.go -package=mocks
    ```
  - DropAnalyticsQueryService: Drop分析参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_drop_analytics_query_service.go -package=mocks
    ```
  - HashtagQueryService: ハッシュタグ参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_hashtag_query_service.go -package=mocks
    ```
- **DTOs:**
  - CreateDropInput, DropOutput, ReactionSummaryOutput
  - RenoteInput, RenoteOutput
  - BookmarkInput, BookmarkOutput
  - PollInput, PollOutput, VoteInput
  - PinDropInput, ThreadOutput
  - FavoriteInput, FavoriteOutput
  - DraftInput, DraftOutput
  - ScheduledDropInput, ScheduledDropOutput
  - DropReportInput, DropReportOutput
  - DropImpressionInput, DropAnalyticsOutput
  - HashtagOutput, MentionOutput
- **External Service Interfaces:**
  - EventPublisher: イベント発行
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_event_publisher.go -package=mocks
    ```
  - MediaServiceClient: avion-mediaとの連携
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_media_service_client.go -package=mocks
    ```

#### Infrastructure Layer (インフラストラクチャ層)
- **Repository Implementations (更新系):**
  - DropRepository: Drop永続化実装（GORMを使用）
  - ReactionRepository: リアクション永続化実装（GORMを使用）
  - ReactionSummaryRepository: リアクション集計永続化実装（GORMを使用）
  - RenoteRepository: リノート永続化実装（GORMを使用）
  - BookmarkRepository: ブックマーク永続化実装（GORMを使用）
  - PollRepository: 投票永続化実装（GORMを使用）
  - FavoriteRepository: お気に入り永続化実装（GORMを使用）
  - DraftRepository: 下書き永続化実装（GORMを使用）
  - ScheduledDropRepository: 予約投稿永続化実装（GORMを使用）
  - DropReportRepository: Drop通報永続化実装（GORMを使用）
- **DAOs (Data Access Objects):**
  - DropDAO: dropsテーブルとのマッピング用struct
  - ReactionDAO: reactionsテーブルとのマッピング用struct
  - ReactionSummaryDAO: reaction_summariesテーブルとのマッピング用struct
  - RenoteDAO: renotesテーブルとのマッピング用struct
  - BookmarkDAO: bookmarksテーブルとのマッピング用struct
  - PollDAO: pollsテーブルとのマッピング用struct
  - PollOptionDAO: poll_optionsテーブルとのマッピング用struct
  - PollVoteDAO: poll_votesテーブルとのマッピング用struct
  - FavoriteDAO: favoritesテーブルとのマッピング用struct
  - DraftDAO: draftsテーブルとのマッピング用struct
  - ScheduledDropDAO: scheduled_dropsテーブルとのマッピング用struct
  - DropReportDAO: drop_reportsテーブルとのマッピング用struct
  - DropImpressionDAO: drop_impressionsテーブルとのマッピング用struct
- **Query Service Implementations (参照系):**
  - DropQueryService: Drop参照専用実装（GORMを使用）
  - ReactionSummaryQueryService: リアクション集計参照専用実装（reaction_summariesテーブル使用、GORMを使用）
  - CachedReactionQueryService: Redis使用のキャッシュ付き参照実装
  - RenoteQueryService: リノート参照専用実装（GORMを使用）
  - BookmarkQueryService: ブックマーク参照専用実装（GORMを使用）
  - PollQueryService: 投票参照専用実装（GORMを使用）
  - FavoriteQueryService: お気に入り参照専用実装（GORMを使用）
  - DraftQueryService: 下書き参照専用実装（GORMを使用）
  - ScheduledDropQueryService: 予約投稿参照専用実装（GORMを使用）
  - DropReportQueryService: Drop通報参照専用実装（GORMを使用）
  - DropAnalyticsQueryService: Drop分析参照専用実装（GORMを使用）
  - HashtagQueryService: ハッシュタグ参照専用実装（GORMを使用）
- **External Service Implementations:**
  - RedisEventPublisher: イベント発行実装
  - GRPCMediaServiceClient: メディアサービス連携実装
- **Cache Components:**
  - RedisReactionCountCache: リアクション集計キャッシュ（永続的）
  - RedisUserReactionCache: ユーザー別リアクションキャッシュ
  - RedisHotDropCache: 人気Dropキャッシュ
  - RedisBookmarkCache: ユーザー別ブックマークキャッシュ
  - RedisPollResultCache: 投票結果キャッシュ
  - RedisThreadCache: スレッド（会話）キャッシュ
  - RedisFavoriteCache: ユーザー別お気に入りキャッシュ
  - RedisDraftCache: ユーザー別下書きキャッシュ
  - RedisScheduledDropCache: 予約投稿キャッシュ
  - RedisHashtagTrendCache: トレンドハッシュタグキャッシュ
  - RedisDropAnalyticsCache: Drop分析データキャッシュ
- **Background Jobs:**
  - ReactionAggregationJob: 集計更新ジョブ（Redis Streamから読み取り、キャッシュ更新を実行）
  - ScheduledDropPublishJob: 予約投稿公開ジョブ（定期実行）
  - HashtagTrendAggregationJob: ハッシュタグトレンド集計ジョブ
  - DropAnalyticsAggregationJob: Drop分析データ集計ジョブ

#### Handler Layer (ハンドラー層)
- **Command Handlers (更新系):**
  - CreateDropCommandHandler: Drop作成エンドポイント（POST）
  - UpdateDropCommandHandler: Drop編集エンドポイント（PATCH）
  - DeleteDropCommandHandler: Drop削除エンドポイント（DELETE）
  - AddReactionCommandHandler: リアクション追加エンドポイント（POST）
  - RemoveReactionCommandHandler: リアクション削除エンドポイント（DELETE）
  - RenoteDropCommandHandler: リノートエンドポイント（POST）
  - UnrenoteDropCommandHandler: リノート解除エンドポイント（DELETE）
  - BookmarkDropCommandHandler: ブックマーク追加エンドポイント（POST）
  - UnbookmarkDropCommandHandler: ブックマーク解除エンドポイント（DELETE）
  - PinDropCommandHandler: Drop固定エンドポイント（POST）
  - UnpinDropCommandHandler: Drop固定解除エンドポイント（DELETE）
  - CreatePollCommandHandler: 投票作成エンドポイント（POST）
  - VotePollCommandHandler: 投票エンドポイント（POST）
  - FavoriteDropCommandHandler: お気に入り追加エンドポイント（POST）
  - UnfavoriteDropCommandHandler: お気に入り解除エンドポイント（DELETE）
  - SaveDraftCommandHandler: 下書き保存エンドポイント（POST）
  - UpdateDraftCommandHandler: 下書き更新エンドポイント（PATCH）
  - DeleteDraftCommandHandler: 下書き削除エンドポイント（DELETE）
  - PublishDraftCommandHandler: 下書きから投稿エンドポイント（POST）
  - ScheduleDropCommandHandler: 予約投稿作成エンドポイント（POST）
  - UpdateScheduledDropCommandHandler: 予約投稿更新エンドポイント（PATCH）
  - CancelScheduledDropCommandHandler: 予約投稿キャンセルエンドポイント（DELETE）
  - ReportDropCommandHandler: Drop通報エンドポイント（POST）
  - ResolveReportCommandHandler: 通報解決エンドポイント（PATCH）
  - RecordDropImpressionCommandHandler: Drop閲覧記録エンドポイント（POST）
  - MarkDropAsSensitiveCommandHandler: センシティブマーク付与エンドポイント（PATCH）
  - UnmarkDropAsSensitiveCommandHandler: センシティブマーク解除エンドポイント（PATCH）
- **Query Handlers (参照系):**
  - GetDropQueryHandler: Drop取得エンドポイント（GET）
  - GetDropsByUserIDQueryHandler: ユーザー別Drop取得エンドポイント（GET）
  - GetReactionSummaryQueryHandler: リアクション集計取得エンドポイント（GET）
  - GetDropRepliesQueryHandler: Drop返信一覧取得エンドポイント（GET）
  - GetDropRenotesQueryHandler: Dropリノート一覧取得エンドポイント（GET）
  - GetBookmarkedDropsQueryHandler: ブックマーク済みDrop一覧取得エンドポイント（GET）
  - GetPinnedDropsQueryHandler: 固定Drop一覧取得エンドポイント（GET）
  - GetPollResultsQueryHandler: 投票結果取得エンドポイント（GET）
  - GetDropThreadQueryHandler: スレッド（会話）取得エンドポイント（GET）
  - GetFavoriteDropsQueryHandler: お気に入りDrop一覧取得エンドポイント（GET）
  - GetDropFavoritesQueryHandler: Dropのお気に入りユーザー取得エンドポイント（GET）
  - GetDraftsQueryHandler: 下書き一覧取得エンドポイント（GET）
  - GetDraftQueryHandler: 下書き詳細取得エンドポイント（GET）
  - GetScheduledDropsQueryHandler: 予約投稿一覧取得エンドポイント（GET）
  - GetDropReportsQueryHandler: Drop通報一覧取得エンドポイント（GET）
  - GetReportDetailsQueryHandler: 通報詳細取得エンドポイント（GET）
  - GetDropImpressionCountQueryHandler: Drop閲覧数取得エンドポイント（GET）
  - GetDropAnalyticsQueryHandler: Drop分析データ取得エンドポイント（GET）
  - GetDropsByHashtagQueryHandler: ハッシュタグ別Drop取得エンドポイント（GET）
  - GetDropMentionsQueryHandler: メンション一覧取得エンドポイント（GET）
  - GetTrendingHashtagsQueryHandler: トレンドハッシュタグ取得エンドポイント（GET）
  - GetDropEditHistoryQueryHandler: Drop編集履歴取得エンドポイント（GET）

### 5.2. 詳細ドメインモデル（DDD戦術パターン）

本セクションでは、PRDで定義された要件を基に、DDDの戦術的パターンを適用した詳細なドメインモデルを示します。各集約とエンティティには厳密な不変条件とドメインロジックが定義されています。

#### Drop Aggregate (投稿集約)

**責務**: 投稿のライフサイクル全体と関連情報を管理する中核集約
- **集約ルート**: Drop
- **不変条件**:
  - DropIDは変更不可（Snowflake ID）
  - 投稿テキストは最大500文字（Unicode準拠、絵文字対応）
  - 公開範囲（Visibility）の変更は作成者のみ可能
  - 削除されたDropは復元不可（論理削除後30日で物理削除）
  - 編集は投稿から24時間以内、最大5回まで
  - メディア添付は最大4つまで
  - リプライ元が削除された場合もリプライは残る
  - Renote元が削除された場合、Renoteも非表示化
  - ハッシュタグは最大10個まで
  - メンションは最大20ユーザーまで

- **ドメインロジック**:
  - `canBeViewedBy(viewerID, viewerContext)`: 投稿閲覧権限の判定（公開範囲、ブロック、フォロー状態を考慮）
  - `canBeEditedBy(editorID, currentTime)`: 編集権限の判定（作成者確認、時間制限、回数制限）
  - `canBeDeletedBy(deleterID, adminContext)`: 削除権限の判定（作成者または管理者）
  - `addReaction(userID, emojiCode)`: リアクション追加（重複防止、ブロック確認）
  - `removeReaction(userID, emojiCode)`: リアクション削除（存在確認、権限確認）
  - `renote(renoteUserID, comment)`: Renote処理（自己Renote防止、引用許可確認）
  - `updateVisibility(newVisibility, updaterID)`: 公開範囲変更（権限確認、依存関係チェック）
  - `extractHashtags()`: ハッシュタグ抽出（正規化、重複除去）
  - `extractMentions()`: メンション抽出（ユーザー存在確認）
  - `validateMediaAttachments(mediaList)`: メディア検証（形式、サイズ、個数）
  - `markAsSensitive(moderatorID)`: センシティブマーク付与（権限確認）
  - `calculateEngagement()`: エンゲージメント率計算（閲覧数、リアクション、Renote考慮）
  - `toActivityPubNote()`: ActivityPub Note形式への変換
  - `applyContentWarning(warning)`: コンテンツ警告の適用
  - `schedulePublication(scheduledTime)`: 予約投稿設定（時刻妥当性検証）

#### Reaction Aggregate (リアクション集約)

**責務**: ユーザーのリアクション情報と集計を管理
- **集約ルート**: Reaction
- **不変条件**:
  - UserIDとDropIDの組み合わせで一意のリアクション
  - 同一ユーザーは同一Dropに複数のリアクション可能（異なる絵文字）
  - 削除されたDropへのリアクションは自動削除
  - ブロックされたユーザーのリアクションは非表示
  - カスタム絵文字は事前登録必須
  - リアクション総数は非負整数

- **ドメインロジック**:
  - `isValidEmoji(emojiCode)`: 絵文字コードの妥当性検証
  - `canReactTo(dropID, userID)`: リアクション可能判定（ブロック、プライバシー確認）
  - `aggregateByEmoji()`: 絵文字別集計
  - `getUserReactions(userID)`: ユーザーのリアクション一覧取得
  - `notifyReaction()`: リアクション通知イベント生成

#### Poll Aggregate (投票集約)

**責務**: 投票機能とその結果を統合管理
- **集約ルート**: Poll
- **不変条件**:
  - PollIDは変更不可
  - 投票選択肢は2〜10個
  - 投票期限は作成から最大7日間
  - 一度投票したら変更不可（単一選択）
  - 複数選択可の場合は最大選択数まで
  - 期限切れ後の投票は不可
  - 投票結果は期限前でも閲覧可能設定可
  - 削除されたDropの投票は無効化

- **ドメインロジック**:
  - `canVote(userID, currentTime)`: 投票可能判定（期限、既投票確認）
  - `recordVote(userID, optionIDs)`: 投票記録（重複防止、選択数検証）
  - `calculateResults()`: 結果集計（パーセンテージ計算）
  - `isExpired(currentTime)`: 期限切れ判定
  - `extendDeadline(newExpiry, extenderID)`: 期限延長（作成者のみ、最大期限内）
  - `closeEarly(closerID)`: 早期締切（作成者のみ）
  - `getWinningOptions()`: 勝利選択肢の判定

#### Bookmark Aggregate (ブックマーク集約)

**責務**: ユーザーのブックマーク情報を管理
- **集約ルート**: Bookmark
- **不変条件**:
  - UserIDとDropIDの組み合わせで一意
  - 削除されたDropのブックマークは自動削除
  - プライベートな情報（他ユーザー非公開）
  - ブックマーク数に上限なし（実用上は監視）

- **ドメインロジック**:
  - `canBookmark(dropID, userID)`: ブックマーク可能判定
  - `isBookmarkedBy(userID)`: ブックマーク済み判定
  - `sortByDate()`: 日付順ソート
  - `exportToJSON()`: エクスポート形式への変換

#### Draft Aggregate (下書き集約)

**責務**: 投稿下書きのライフサイクルを管理
- **集約ルート**: Draft
- **不変条件**:
  - DraftIDは変更不可
  - ユーザーごとに最大100件まで
  - 30日間更新がない下書きは自動削除
  - 下書きから投稿への変換は1回のみ
  - 下書きはプライベート（作成者のみアクセス可）

- **ドメインロジック**:
  - `canAccess(accessorID)`: アクセス権限判定（作成者確認）
  - `updateContent(newContent)`: 内容更新（最終更新日時記録）
  - `publish()`: 投稿への変換（一度のみ実行可能）
  - `isStale(currentTime)`: 古い下書き判定
  - `autoSave(content)`: 自動保存処理
  - `validateBeforePublish()`: 投稿前検証

#### ScheduledDrop Aggregate (予約投稿集約)

**責務**: 予約投稿のスケジュール管理
- **集約ルート**: ScheduledDrop
- **不変条件**:
  - ScheduledDropIDは変更不可
  - 予約時刻は現在時刻より未来
  - 予約可能期間は最大30日先まで
  - ユーザーごとに最大30件まで
  - 公開後はScheduledDropから通常のDropへ変換
  - キャンセル後の再スケジュール不可

- **ドメインロジック**:
  - `canSchedule(scheduledTime, currentTime)`: スケジュール可能判定
  - `reschedule(newTime, reschedulerID)`: 再スケジュール（権限、時刻検証）
  - `cancel(cancellerID)`: キャンセル処理（権限確認）
  - `publish()`: 投稿処理（時刻到達確認）
  - `isReadyToPublish(currentTime)`: 公開準備完了判定
  - `validateScheduledContent()`: 予約内容の事前検証
  - `notifyUpcoming()`: 公開直前通知

### 5.3. 主要コンポーネント

- **主要コンポーネント:**
    - `avion-drop (Go, Kubernetes Deployment)`: 本サービス。gRPCサーバー、Redis Pub/Sub発行者。
    - `avion-gateway (Go)`: gRPCリクエストのルーティング元。
    - `avion-media (Go)`: メディア情報の関連付けで連携。
    - `PostgreSQL`: Dropデータおよびリアクションデータを永続化。
    - `Redis`: リアクション集計キャッシュ (Hash)、ユーザー別リアクションキャッシュ (Set)、イベント通知 (Pub/Sub)。
    - `Observability Stack`: メトリクス、トレース、ログ収集。
    - イベント購読者 (`avion-timeline`, `avion-search`, `avion-activitypub`, `avion-notification`)。
- **構成図:** (アーキテクチャ概要図を参照)
    - [Avion アーキテクチャ概要](../common/architecture.md)
- **ポイント:**
    - Dropの作成、取得、物理削除とデータ永続化を行う。
    - リアクションの追加・削除と集計取得を行う。
    - 集計情報は主にRedisキャッシュから提供し、DBは永続化とキャッシュミス時のリカバリに利用。
    - 状態変更時にイベントを発行し、他サービスとの連携を疎結合に保つ。
    - ステートレス設計。

## データベースマイグレーション

このサービスでは、[共通マイグレーション戦略](../common/database-migration-strategy.md)に従って、Gooseを使用したマイグレーション管理を行います。

### マイグレーション戦略

- **ツール**: Goose v3
- **ディレクトリ**: `./migrations/`
- **命名規則**: `[sequence_number]_[description].sql`
- **実行方法**: `make migrate-up` / `make migrate-down`

### avion-drop固有の考慮事項

- **コンテンツ完全性保証**: Drop本文やメディア参照の整合性を移行時も維持
- **リアクション集計再計算**: reaction_summariesテーブルの変更時は集計値を再計算
- **大量コンテンツ移行**: Dropデータの大量移行時は、バッチ処理で段階的に実施
- **キャッシュ整合性**: スキーマ変更後はRedisキャッシュの無効化・更新
- **ActivityPub連携**: 外部サービスとの連携データの整合性を保証

### 標準テンプレート参照

マイグレーションファイル作成時は[マイグレーション設定テンプレート](../templates/migration-setup-template.md)を参照してください。

## 7. Configuration Management (設定管理)

このサービスは[Common Environment Variables](../common/infrastructure/environment-variables.md)で定義された統一設定パターンに従います。

### 7.1. 必須環境変数

- `DATABASE_URL` (required): PostgreSQLデータベース接続URL
- `REDIS_URL` (required): Redis接続URL
- `MEDIA_SERVICE_URL` (required): avion-mediaサービスのエンドポイントURL

### 7.2. オプション環境変数

- `PORT` (default: 8083): HTTPサーバーポート
- `GRPC_PORT` (default: 9093): gRPCサーバーポート
- `MAX_DROP_LENGTH` (default: 500): Drop本文の最大文字数
- `DROP_RATE_LIMIT` (default: 30/hour): ユーザーあたりのDrop投稿レート制限

### 7.3. Config構造体実装例

```go
// internal/infrastructure/config/config.go
package config

type Config struct {
    // 共通設定
    Server   ServerConfig
    Database DatabaseConfig
    Redis    RedisConfig
    
    // Drop固有設定
    Drop    DropConfig
    Media   MediaConfig
}

type DropConfig struct {
    MaxLength     int    `env:"MAX_DROP_LENGTH" required:"false" default:"500"`
    RateLimit     string `env:"DROP_RATE_LIMIT" required:"false" default:"30/hour"`
}

type MediaConfig struct {
    ServiceURL string `env:"MEDIA_SERVICE_URL" required:"true"`
}

// Load は環境変数から設定を読み込む
func Load(loader EnvironmentLoader) (*Config, error) {
    validator := NewValidator(loader)
    
    cfg := &Config{}
    
    if err := validator.ValidateAndLoad(&cfg.Server); err != nil {
        return nil, fmt.Errorf("server config: %w", err)
    }
    
    if err := validator.ValidateAndLoad(&cfg.Database); err != nil {
        return nil, fmt.Errorf("database config: %w", err)
    }
    
    if err := validator.ValidateAndLoad(&cfg.Redis); err != nil {
        return nil, fmt.Errorf("redis config: %w", err)
    }
    
    if err := validator.ValidateAndLoad(&cfg.Drop); err != nil {
        return nil, fmt.Errorf("drop config: %w", err)
    }
    
    if err := validator.ValidateAndLoad(&cfg.Media); err != nil {
        return nil, fmt.Errorf("media config: %w", err)
    }
    
    return cfg, nil
}

// MustLoad は環境変数から設定を読み込み、エラーの場合はパニックする
func MustLoad() *Config {
    cfg, err := Load(&OSEnvironmentLoader{})
    if err != nil {
        panic(fmt.Sprintf("failed to load config: %v", err))
    }
    return cfg
}
```

### 7.4. 設定検証の実装

早期失敗原則に従い、サービス起動時に必須環境変数の検証を行います：

```go
// cmd/server/main.go
func main() {
    // 環境変数の読み込み（必須環境変数が不足していればここで失敗）
    cfg := config.MustLoad()
    
    logger := initLogger(cfg.Server.LogLevel)
    logger.Info("Starting avion-drop server",
        "environment", cfg.Server.Environment,
        "port", cfg.Server.Port,
        "grpc_port", cfg.Server.GRPCPort,
        "max_drop_length", cfg.Drop.MaxLength,
    )
    
    // 依存関係の初期化
    db := initDatabase(cfg.Database)
    redis := initRedis(cfg.Redis)
    
    // サーバーの起動...
}
```

## 8. Use Cases / Key Flows (主な使い方・処理の流れ)

- **フロー 1: Drop作成 (Command)**
    1. Gateway → CreateDropCommandHandler: `CreateDrop` gRPC Call (text, visibility, media_ids, Metadata: X-User-ID, Trace Context)
    2. CreateDropCommandHandler: CreateDropCommandUseCaseを呼び出し
    3. CreateDropCommandUseCase: Drop Aggregateを生成し、DropDomainServiceでビジネスルール検証
    4. CreateDropCommandUseCase: DropRepositoryを通じてDrop Aggregateを永続化
    5. CreateDropCommandUseCase: EventPublisherを通じて `drop_created` イベントを発行
    6. CreateDropCommandHandler → Gateway: `CreateDropResponse { drop_id: "..." }`
- **フロー 2: Drop取得 (Query)**
    1. Gateway → GetDropQueryHandler: `GetDrop` gRPC Call (drop_id, Metadata: X-User-ID, Trace Context)
    2. GetDropQueryHandler: GetDropQueryUseCaseを呼び出し
    3. GetDropQueryUseCase: DropQueryServiceを通じてDropのDTOを取得
    4. GetDropQueryUseCase: Visibility値に基づくアクセス権限チェック
    5. (アクセス不可の場合) GetDropQueryHandler → Gateway: gRPC Error (PermissionDenied or NotFound)
    6. (アクセス可の場合) GetDropQueryHandler → Gateway: `GetDropResponse { drop: { ... } }`
- **フロー 3: Drop削除 (Command)**
    1. Gateway → DeleteDropCommandHandler: `DeleteDrop` gRPC Call (drop_id, Metadata: X-User-ID, Trace Context)
    2. DeleteDropCommandHandler: DeleteDropCommandUseCaseを呼び出し
    3. DeleteDropCommandUseCase: DropRepositoryからDrop Aggregateを取得
    4. DeleteDropCommandUseCase: Drop Aggregate内で所有者検証
    5. (不一致の場合) DeleteDropCommandHandler → Gateway: gRPC Error (PermissionDenied)
    6. (一致の場合) DeleteDropCommandUseCase: DropRepositoryを通じてDrop Aggregateを削除
    7. DeleteDropCommandUseCase: ReactionSummaryRepositoryを通じて関連するリアクション集計を削除
    8. DeleteDropCommandUseCase: EventPublisherを通じて `drop_deleted` イベントを発行
    9. DeleteDropCommandHandler → Gateway: `DeleteDropResponse {}`
- **フロー 4: リアクション追加 (Command)**
    1. Gateway → AddReactionCommandHandler: `AddReaction` gRPC Call (drop_id, emoji_code, Metadata: X-User-ID, Trace Context)
    2. AddReactionCommandHandler: AddReactionCommandUseCaseを呼び出し
    3. AddReactionCommandUseCase: Reaction Aggregateを生成し、ReactionDomainServiceで重複チェック
    4. AddReactionCommandUseCase: ReactionRepositoryを通じてReaction Aggregateを永続化
    5. AddReactionCommandUseCase: ReactionSummaryRepositoryを通じてReactionSummary Aggregateを更新 (count+1)
    6. AddReactionCommandUseCase: Redis Stream `reaction_aggregation_queue` に集計更新タスクを追加
    7. AddReactionCommandUseCase: EventPublisherを通じて `reaction_created` イベントを発行
    8. AddReactionCommandHandler → Gateway: `AddReactionResponse {}`
    9. (非同期) ReactionAggregationJob: Redisキャッシュを更新、ホットDropリストを更新
- **フロー 5: リアクション削除 (Command)**
    1. Gateway → RemoveReactionCommandHandler: `RemoveReaction` gRPC Call (drop_id, emoji_code, Metadata: X-User-ID, Trace Context)
    2. RemoveReactionCommandHandler: RemoveReactionCommandUseCaseを呼び出し
    3. RemoveReactionCommandUseCase: ReactionRepositoryからReaction Aggregateを取得
    4. RemoveReactionCommandUseCase: Reaction Aggregate内で所有者検証
    5. RemoveReactionCommandUseCase: ReactionRepositoryを通じてReaction Aggregateを削除
    6. RemoveReactionCommandUseCase: EventPublisherを通じて `reaction_deleted` イベントを発行（キャッシュ更新はイベントハンドラが処理）
    7. RemoveReactionCommandHandler → Gateway: `RemoveReactionResponse {}`
- **フロー 6: リアクション集計取得 (Query)**
    1. Gateway → GetReactionSummaryQueryHandler: `GetReactions` gRPC Call (drop_id, Metadata: X-User-ID, Trace Context)
    2. GetReactionSummaryQueryHandler: GetReactionSummaryQueryUseCaseを呼び出し
    3. GetReactionSummaryQueryUseCase: CachedReactionQueryServiceを通じて集計データ取得を試行
    4. CachedReactionQueryService: Redisキャッシュチェック（ほぼ100%ヒット率）
    5. (キャッシュヒット) ReactionSummaryDTOを返却
    6. (キャッシュミス) reaction_summariesテーブルから直接取得（高速）、Redisにキャッシュ
    7. GetReactionSummaryQueryUseCase: ユーザー別リアクション情報をRedis/DBから取得
    8. GetReactionSummaryQueryHandler → Gateway: `GetReactionsResponse { reactions: [...], user_reacted_emojis: [...] }`
- **フロー 7: スケジュール投稿作成 (Command)**
    1. Gateway → ScheduleDropCommandHandler: `ScheduleDrop` gRPC Call (text, visibility, scheduled_at, media_ids, Metadata: X-User-ID, Trace Context)
    2. ScheduleDropCommandHandler: ScheduleDropCommandUseCaseを呼び出し
    3. ScheduleDropCommandUseCase: ScheduledDropDomainServiceで予約日時の妥当性検証（5分以上先、30日以内）
    4. ScheduleDropCommandUseCase: ScheduledDrop Aggregateを生成（status: scheduled）
    5. ScheduleDropCommandUseCase: ScheduledDropRepositoryを通じてScheduledDrop Aggregateを永続化
    6. ScheduleDropCommandUseCase: EventPublisherを通じて `scheduled_drop_created` イベントを発行
    7. ScheduleDropCommandHandler → Gateway: `ScheduleDropResponse { scheduled_drop_id: "...", scheduled_at: "..." }`
- **フロー 8: 下書き保存 (Command)**
    1. Gateway → SaveDraftCommandHandler: `SaveDraft` gRPC Call (text, visibility, media_ids, Metadata: X-User-ID, Trace Context)
    2. SaveDraftCommandHandler: SaveDraftCommandUseCaseを呼び出し
    3. SaveDraftCommandUseCase: DraftDomainServiceでコンテンツの妥当性検証
    4. SaveDraftCommandUseCase: ScheduledDrop Aggregateを生成（status: draft）
    5. SaveDraftCommandUseCase: ScheduledDropRepositoryを通じて下書きを永続化
    6. SaveDraftCommandHandler → Gateway: `SaveDraftResponse { draft_id: "..." }`
- **フロー 9: スケジュール投稿一覧取得 (Query)**
    1. Gateway → GetScheduledDropsQueryHandler: `GetScheduledDrops` gRPC Call (status_filter, Metadata: X-User-ID, Trace Context)
    2. GetScheduledDropsQueryHandler: GetScheduledDropsQueryUseCaseを呼び出し
    3. GetScheduledDropsQueryUseCase: ScheduledDropQueryServiceを通じてユーザーのスケジュール投稿を取得
    4. GetScheduledDropsQueryUseCase: ステータスでフィルタリング（draft, scheduled）
    5. GetScheduledDropsQueryUseCase: 予約日時の昇順でソート
    6. GetScheduledDropsQueryHandler → Gateway: `GetScheduledDropsResponse { scheduled_drops: [...] }`
- **フロー 10: スケジュール投稿自動実行 (Background Job)**
    1. ScheduledDropPublishJob: 定期実行（1分ごと）
    2. ScheduledDropPublishJob: ScheduledDropRepositoryから公開時刻に達した投稿を検索
    3. ScheduledDropPublishJob: 各スケジュール投稿に対して:
        - ScheduledDropDomainService.shouldBePublished()で実行確認
        - DraftContentをDrop Aggregateに変換
        - DropRepositoryを通じてDropを永続化
        - ScheduledDropのstatusをpublishedに更新
        - EventPublisherを通じて `drop_created` イベントを発行
        - EventPublisherを通じて `scheduled_drop_published` イベントを発行
    4. ScheduledDropPublishJob: 失敗した場合はリトライ処理とエラー通知

## 9. Endpoints (API)

- **gRPC Services (`avion.DropService`):**
    - **Command Operations (更新系):**
        - `CreateDrop(CreateDropRequest) returns (CreateDropResponse)` // POST相当
        - `UpdateDrop(UpdateDropRequest) returns (UpdateDropResponse)` // PATCH相当
        - `DeleteDrop(DeleteDropRequest) returns (DeleteDropResponse)` // DELETE相当
        - `AddReaction(AddReactionRequest) returns (AddReactionResponse)` // POST相当
        - `RemoveReaction(RemoveReactionRequest) returns (RemoveReactionResponse)` // DELETE相当
        - `RenoteDrop(RenoteDropRequest) returns (RenoteDropResponse)` // POST相当
        - `UnrenoteDrop(UnrenoteDropRequest) returns (UnrenoteDropResponse)` // DELETE相当
        - `BookmarkDrop(BookmarkDropRequest) returns (BookmarkDropResponse)` // POST相当
        - `UnbookmarkDrop(UnbookmarkDropRequest) returns (UnbookmarkDropResponse)` // DELETE相当
        - `PinDrop(PinDropRequest) returns (PinDropResponse)` // POST相当
        - `UnpinDrop(UnpinDropRequest) returns (UnpinDropResponse)` // DELETE相当
        - `CreatePoll(CreatePollRequest) returns (CreatePollResponse)` // POST相当
        - `VotePoll(VotePollRequest) returns (VotePollResponse)` // POST相当
        - `FavoriteDrop(FavoriteDropRequest) returns (FavoriteDropResponse)` // POST相当
        - `UnfavoriteDrop(UnfavoriteDropRequest) returns (UnfavoriteDropResponse)` // DELETE相当
        - `SaveDraft(SaveDraftRequest) returns (SaveDraftResponse)` // POST相当
        - `UpdateDraft(UpdateDraftRequest) returns (UpdateDraftResponse)` // PATCH相当
        - `DeleteDraft(DeleteDraftRequest) returns (DeleteDraftResponse)` // DELETE相当
        - `PublishDraft(PublishDraftRequest) returns (PublishDraftResponse)` // POST相当
        - `ScheduleDrop(ScheduleDropRequest) returns (ScheduleDropResponse)` // POST相当
        - `UpdateScheduledDrop(UpdateScheduledDropRequest) returns (UpdateScheduledDropResponse)` // PATCH相当
        - `CancelScheduledDrop(CancelScheduledDropRequest) returns (CancelScheduledDropResponse)` // DELETE相当
        - `ReportDrop(ReportDropRequest) returns (ReportDropResponse)` // POST相当
        - `ResolveReport(ResolveReportRequest) returns (ResolveReportResponse)` // PATCH相当
        - `RecordDropImpression(RecordDropImpressionRequest) returns (RecordDropImpressionResponse)` // POST相当
        - `MarkDropAsSensitive(MarkDropAsSensitiveRequest) returns (MarkDropAsSensitiveResponse)` // PATCH相当
        - `UnmarkDropAsSensitive(UnmarkDropAsSensitiveRequest) returns (UnmarkDropAsSensitiveResponse)` // PATCH相当
    - **Query Operations (参照系):**
        - `GetDrop(GetDropRequest) returns (GetDropResponse)` // GET相当
        - `GetDropsByUserID(GetDropsByUserIDRequest) returns (GetDropsByUserIDResponse)` // GET相当
        - `GetReactions(GetReactionsRequest) returns (GetReactionsResponse)` // GET相当
        - `GetDropReplies(GetDropRepliesRequest) returns (GetDropRepliesResponse)` // GET相当
        - `GetDropRenotes(GetDropRenotesRequest) returns (GetDropRenotesResponse)` // GET相当
        - `GetBookmarkedDrops(GetBookmarkedDropsRequest) returns (GetBookmarkedDropsResponse)` // GET相当
        - `GetPinnedDrops(GetPinnedDropsRequest) returns (GetPinnedDropsResponse)` // GET相当
        - `GetPollResults(GetPollResultsRequest) returns (GetPollResultsResponse)` // GET相当
        - `GetDropThread(GetDropThreadRequest) returns (GetDropThreadResponse)` // GET相当
        - `GetFavoriteDrops(GetFavoriteDropsRequest) returns (GetFavoriteDropsResponse)` // GET相当
        - `GetDropFavorites(GetDropFavoritesRequest) returns (GetDropFavoritesResponse)` // GET相当
        - `GetDrafts(GetDraftsRequest) returns (GetDraftsResponse)` // GET相当
        - `GetDraft(GetDraftRequest) returns (GetDraftResponse)` // GET相当
        - `GetScheduledDrops(GetScheduledDropsRequest) returns (GetScheduledDropsResponse)` // GET相当
        - `GetDropReports(GetDropReportsRequest) returns (GetDropReportsResponse)` // GET相当
        - `GetReportDetails(GetReportDetailsRequest) returns (GetReportDetailsResponse)` // GET相当
        - `GetDropImpressionCount(GetDropImpressionCountRequest) returns (GetDropImpressionCountResponse)` // GET相当
        - `GetDropAnalytics(GetDropAnalyticsRequest) returns (GetDropAnalyticsResponse)` // GET相当
        - `GetDropsByHashtag(GetDropsByHashtagRequest) returns (GetDropsByHashtagResponse)` // GET相当
        - `GetDropMentions(GetDropMentionsRequest) returns (GetDropMentionsResponse)` // GET相当
        - `GetTrendingHashtags(GetTrendingHashtagsRequest) returns (GetTrendingHashtagsResponse)` // GET相当
        - `GetDropEditHistory(GetDropEditHistoryRequest) returns (GetDropEditHistoryResponse)` // GET相当
- Proto定義は別途管理する。
- リアクション関連のRequest/Responseには `drop_id`, `emoji_code` などを含む。
- GetReactionsResponseには絵文字ごとのカウント、自身がリアクションした絵文字リストなどを含む。

## 10. Data Design (データ)

### 8.1. Domain Model (ドメインモデル)

#### Aggregates (集約)

##### Drop (投稿集約)
- **責務:** 投稿のライフサイクルと整合性を管理する集約
- **集約ルート:** Drop
- **構成要素:**
  - DropID (Value Object): 投稿の一意識別子
  - UserID (Value Object): 作成者ID
  - DropText (Value Object): 投稿テキスト
  - Visibility (Value Object): 公開範囲
  - MediaAttachments (Value Object Collection): 添付メディア情報
  - CreatedAt (Value Object): 作成日時
  - UpdatedAt (Value Object): 更新日時
- **不変条件:**
  - テキストは最大文字数制限内
  - 作成者のみが編集・削除可能
  - 公開範囲は定義された値のいずれか

##### Reaction (リアクション集約)
- **責務:** Dropに対するリアクションを管理する集約
- **集約ルート:** Reaction
- **構成要素:**
  - DropID (Value Object): 対象DropのID
  - UserID (Value Object): リアクションしたユーザーID
  - EmojiCode (Value Object): 絵文字コード
  - CreatedAt (Value Object): リアクション作成日時
- **不変条件:**
  - 1ユーザーは1つのDropに対して同じ絵文字で1回まで
  - リアクションしたユーザーのみが削除可能

##### ReactionSummary (リアクション集計集約)
- **責務:** Dropごとのリアクション集計情報を管理する集約
- **集約ルート:** ReactionSummary
- **構成要素:**
  - DropID (Value Object): 対象DropのID
  - EmojiCode (Value Object): 絵文字コード
  - Count (Value Object): リアクション数
  - UpdatedAt (Value Object): 最終更新日時
- **不変条件:**
  - カウントは非負の整数
  - 同時更新時の整合性を保証
  - DropIDとEmojiCodeの組み合わせは一意

##### Renote (リノート集約)
- **責務:** Dropのリノート（ブースト）情報を管理する集約
- **集約ルート:** Renote
- **構成要素:**
  - RenoteID (Value Object): リノートの一意識別子
  - DropID (Value Object): リノート対象のDropID
  - UserID (Value Object): リノートしたユーザーID
  - Comment (Value Object): 引用リノート時のコメント（オプション）
  - CreatedAt (Value Object): リノート作成日時
- **不変条件:**
  - 同じユーザーは同じDropを複数回リノートできない
  - 自分のDropはリノートできない

##### Bookmark (ブックマーク集約)
- **責務:** ユーザーのDropブックマーク情報を管理する集約
- **集約ルート:** Bookmark
- **構成要素:**
  - BookmarkID (Value Object): ブックマークの一意識別子
  - DropID (Value Object): ブックマーク対象のDropID
  - UserID (Value Object): ブックマークしたユーザーID
  - CreatedAt (Value Object): ブックマーク作成日時
- **不変条件:**
  - 同じユーザーは同じDropを複数回ブックマークできない

##### Poll (投票集約)
- **責務:** Dropに関連付けられた投票機能を管理する集約
- **集約ルート:** Poll
- **構成要素:**
  - PollID (Value Object): 投票の一意識別子
  - DropID (Value Object): 関連するDropのID
  - Options (Entity Collection): 投票選択肢のコレクション
  - ExpiresAt (Value Object): 投票期限
  - MultipleChoice (Value Object): 複数選択可否
  - CreatedAt (Value Object): 投票作成日時
- **不変条件:**
  - 選択肢は2つ以上必要
  - 投票期限は作成時点より未来
  - 期限切れ後は投票不可

##### Favorite (お気に入り集約)
- **責務:** Dropのお気に入り情報を管理する集約
- **集約ルート:** Favorite
- **構成要素:**
  - FavoriteID (Value Object): お気に入りの一意識別子
  - DropID (Value Object): お気に入り対象のDropID
  - UserID (Value Object): お気に入りしたユーザーID
  - CreatedAt (Value Object): お気に入り作成日時
- **不変条件:**
  - 同じユーザーは同じDropを複数回お気に入りできない

##### Draft (下書き集約)
- **責務:** 投稿の下書き情報を管理する集約
- **集約ルート:** Draft
- **構成要素:**
  - DraftID (Value Object): 下書きの一意識別子
  - UserID (Value Object): 作成者ID
  - DraftText (Value Object): 下書きテキスト
  - Visibility (Value Object): 公開範囲（下書き）
  - MediaAttachments (Value Object Collection): 添付メディア情報
  - CreatedAt (Value Object): 作成日時
  - UpdatedAt (Value Object): 更新日時
- **不変条件:**
  - 作成者のみが編集・削除・公開可能
  - 下書きは本人のみ閲覧可能

##### ScheduledDrop (予約投稿集約)
- **責務:** スケジュール投稿・下書きの管理と実行制御を行う集約
- **集約ルート:** ScheduledDrop
- **構成要素:**
  - ScheduledDropID (Value Object): 予約投稿の一意識別子
  - UserID (Value Object): 作成者ID
  - DraftContent (Entity): 下書きコンテンツ情報
    - DropText (Value Object): 投稿テキスト
    - Visibility (Value Object): 公開範囲
    - MediaAttachments (Value Object Collection): 添付メディア情報
    - Poll (Value Object): 投票設定（オプション）
    - ContentWarning (Value Object): CW設定（オプション）
  - ScheduledAt (Value Object): 予約投稿日時（下書きの場合はnull）
  - Status (Value Object): ステータス（draft, scheduled, published, cancelled）
  - PublishedDropID (Value Object): 公開後のDropID（公開後のみ）
  - RetryCount (Value Object): リトライ回数（自動実行失敗時）
  - CreatedAt (Value Object): 作成日時
  - UpdatedAt (Value Object): 更新日時
- **不変条件:**
  - ScheduledAtは現在時刻より5分以上先、30日以内（scheduledステータス時）
  - Statusは定義された値（draft, scheduled, published, cancelled）のいずれか
  - 公開済み（published）のスケジュール投稿は編集不可
  - 作成者のみが編集・削除可能
  - draftステータスの場合、ScheduledAtはnull
  - scheduledステータスの場合、ScheduledAtは必須

##### DropReport (投稿通報集約)
- **責務:** Dropの通報情報を管理する集約
- **集約ルート:** DropReport
- **構成要素:**
  - ReportID (Value Object): 通報の一意識別子
  - DropID (Value Object): 通報対象のDropID
  - ReporterID (Value Object): 通報者のユーザーID
  - Reason (Value Object): 通報理由
  - Description (Value Object): 詳細説明
  - Status (Value Object): 通報ステータス（pending/resolved/rejected）
  - ResolvedBy (Value Object): 解決した管理者ID（オプション）
  - ResolvedAt (Value Object): 解決日時（オプション）
  - CreatedAt (Value Object): 通報作成日時
- **不変条件:**
  - 同じユーザーは同じDropを複数回通報できない
  - 解決済みの通報は再度変更できない

#### Entities (エンティティ)

##### MediaAttachment (メディア添付エンティティ)
- **責務:** Dropに添付されたメディア情報を表現
- **所属集約:** Drop
- **属性:**
  - MediaID (Value Object): avion-mediaで管理されるメディアID
  - MediaType (Value Object): メディアタイプ（image, video等）
  - MediaOrder (Value Object): 表示順序
  - AltText (Value Object): 代替テキスト
- **不変条件:** メディアIDは不変、順序はユニーク

##### EditRevision (編集履歴エンティティ)
- **責務:** Dropの編集履歴を表現
- **所属集約:** Drop
- **属性:**
  - RevisionID (Value Object): リビジョンID
  - PreviousText (Value Object): 編集前テキスト
  - EditedAt (Value Object): 編集日時
  - EditReason (Value Object): 編集理由
- **不変条件:** 完全に不変

##### PollOption (投票選択肢エンティティ)
- **責務:** 投票の選択肢を表現
- **所属集約:** Poll
- **属性:**
  - PollOptionID (Value Object): 選択肢ID
  - OptionText (Value Object): 選択肢テキスト
  - VoteCount (Value Object): 投票数
  - DisplayOrder (Value Object): 表示順序
- **不変条件:** 選択肢テキストは不変、投票数は非負

##### PollVote (投票結果エンティティ)
- **責務:** ユーザーの投票を表現
- **所属集約:** Poll
- **属性:**
  - UserID (Value Object): 投票者ID
  - PollOptionID (Value Object): 選択した選択肢ID
  - VotedAt (Value Object): 投票日時
- **不変条件:** 完全に不変

##### ContentWarning (コンテンツ警告エンティティ)
- **責務:** Dropのコンテンツ警告を表現
- **所属集約:** Drop, ScheduledDrop
- **属性:**
  - WarningText (Value Object): 警告テキスト
  - WarningType (Value Object): 警告タイプ
- **不変条件:** 完全に不変

#### Value Objects (値オブジェクト)

##### 識別子系Value Objects

###### DropID
- **責務:** Dropの一意識別子を表現
- **属性:** ID値（Snowflake ID）
- **不変性:** 完全に不変
- **バリデーション:** 正しいSnowflake ID形式

###### UserID
- **責務:** ユーザーの一意識別子を表現
- **属性:** ID値（Snowflake ID）
- **不変性:** 完全に不変
- **バリデーション:** 正しいSnowflake ID形式

###### ReactionID
- **責務:** リアクションの一意識別子を表現
- **属性:** 複合キー（DropID + UserID + EmojiCode）
- **不変性:** 完全に不変

###### BookmarkID, PollID, FavoriteID, DraftID, ScheduledDropID, ReportID
- 各集約の一意識別子を表現
- Snowflake ID形式
- 完全に不変

##### テキスト系Value Objects

###### DropText
- **責務:** Dropのテキスト内容を表現
- **属性:** テキスト本文
- **制約:** 最大500文字
- **不変性:** 完全に不変
- **バリデーション:** 文字数制限、禁止文字チェック

###### OptionText
- **責務:** 投票選択肢テキストを表現
- **属性:** テキスト
- **制約:** 最大100文字
- **不変性:** 完全に不変

###### WarningText
- **責務:** コンテンツ警告テキストを表現
- **属性:** 警告テキスト
- **制約:** 最大200文字
- **不変性:** 完全に不変

###### AltText
- **責務:** メディアの代替テキストを表現
- **属性:** 代替テキスト
- **制約:** 最大1000文字
- **不変性:** 完全に不変

##### ステータス系Value Objects

###### Visibility
- **責務:** Dropの公開範囲を表現
- **値:** public, followers_only, private, direct
- **不変性:** 完全に不変
- **バリデーション:** 定義された値のみ

###### DropStatus
- **責務:** 予約投稿のステータスを表現
- **値:** draft, scheduled, published, cancelled
- **不変性:** 完全に不変

###### ReportStatus
- **責務:** 通報のステータスを表現
- **値:** pending, reviewing, resolved, rejected
- **不変性:** 完全に不変

###### WarningType
- **責務:** コンテンツ警告タイプを表現
- **値:** nsfw, violence, spoiler, other
- **不変性:** 完全に不変

##### メディア系Value Objects

###### MediaID
- **責務:** メディアの一意識別子を表現
- **属性:** avion-mediaで管理されるID
- **不変性:** 完全に不変

###### MediaType
- **責務:** メディアタイプを表現
- **値:** image, video, audio, document
- **不変性:** 完全に不変

###### MediaOrder
- **責務:** メディアの表示順序を表現
- **属性:** 順序番号（1から開始）
- **制約:** 1以上の整数
- **不変性:** 完全に不変

##### リアクション系Value Objects

###### EmojiCode
- **責務:** リアクションの絵文字を表現
- **属性:** Unicode文字またはカスタム絵文字コード
- **不変性:** 完全に不変
- **バリデーション:** 有効なUnicode絵文字またはカスタム絵文字コード

###### ReactionCount
- **責務:** リアクション数を表現
- **属性:** カウント値
- **制約:** 0以上の整数
- **不変性:** 完全に不変

##### 数値系Value Objects

###### VoteCount
- **責務:** 投票数を表現
- **属性:** カウント値
- **制約:** 0以上の整数
- **不変性:** 完全に不変

###### DisplayOrder
- **責務:** 表示順序を表現
- **属性:** 順序番号
- **制約:** 1以上の整数
- **不変性:** 完全に不変

###### RetryCount
- **責務:** リトライ回数を表現
- **属性:** 回数
- **制約:** 0以上の整数、最大3回
- **不変性:** 完全に不変

##### 日時系Value Objects

###### CreatedAt
- **責務:** 作成日時を表現
- **属性:** UTCタイムスタンプ
- **不変性:** 完全に不変

###### UpdatedAt
- **責務:** 更新日時を表現
- **属性:** UTCタイムスタンプ
- **不変性:** 完全に不変

###### DeletedAt
- **責務:** 削除日時を表現（ソフトデリート）
- **属性:** UTCタイムスタンプまたはnull
- **不変性:** 完全に不変

###### ScheduledAt
- **責務:** 予約投稿日時を表現
- **属性:** UTCタイムスタンプ
- **制約:** 現在時刻よ5分以上先、30日以内
- **不変性:** 完全に不変

###### PollExpiry
- **責務:** 投票期限を表現
- **属性:** UTCタイムスタンプ
- **制約:** 作成時刻より未来
- **不変性:** 完全に不変

##### その他Value Objects

###### ReportReason
- **責務:** 通報理由を表現
- **属性:** 理由テキスト
- **制約:** 最大500文字
- **不変性:** 完全に不変

###### ErrorMessage
- **責務:** エラーメッセージを表現
- **属性:** エラーテキスト
- **制約:** 最大1000文字
- **不変性:** 完全に不変

###### EditReason
- **責務:** 編集理由を表現
- **属性:** 理由テキスト
- **制約:** 最大200文字
- **不変性:** 完全に不変

### 8.2. Infrastructure Layer (インフラストラクチャ層)

- **PostgreSQL:**
    - `drops` table:
        - `id (BIGINT, PK)`
        - `user_id (BIGINT, FK to users.id, INDEX)`
        - `text (TEXT)`
        - `visibility (ENUM('public', 'followers_only', ...))`
        - `media_ids (BIGINT[])`: `avion-media` で管理されるメディアIDの配列
        - `created_at (TIMESTAMP)`
        - `updated_at (TIMESTAMP)`
        - `is_edited (BOOLEAN DEFAULT FALSE)`
        - Index: `(user_id, created_at)`, `created_at`
    - `reactions` table:
        - `drop_id (BIGINT, PK, FK to drops.id)`
        - `user_id (BIGINT, PK, FK to users.id)`
        - `emoji_code (VARCHAR, PK)`: Unicode文字 or カスタム絵文字コード
        - `created_at (TIMESTAMP)`
        - Index: `(user_id, drop_id)` // ユーザーがDropにリアクションしたか確認用
    - `reaction_summaries` table: // 集計専用テーブル（非正規化）
        - `drop_id (BIGINT, PK, FK to drops.id)`
        - `emoji_code (VARCHAR, PK)`
        - `count (INTEGER, DEFAULT 0)` // リアクション数
        - `updated_at (TIMESTAMP)`
        - Index: `(drop_id)` // Drop単位での高速取得
    - `scheduled_drops` table:
        - `id (BIGINT, PK)`
        - `user_id (BIGINT, FK to users.id, INDEX)`
        - `text (TEXT)`
        - `visibility (ENUM('public', 'followers_only', ...))`
        - `media_ids (BIGINT[])`: `avion-media` で管理されるメディアIDの配列
        - `poll_config (JSONB)`: 投票設定（オプション）
        - `content_warning (JSONB)`: CW設定（オプション）
        - `scheduled_at (TIMESTAMP, INDEX)`: 投稿予定日時（下書きの場合NULL）
        - `status (ENUM('draft', 'scheduled', 'published', 'cancelled'), INDEX)`
        - `published_drop_id (BIGINT)`: 公開後のDropID（公開後のみ）
        - `retry_count (INTEGER DEFAULT 0)`: リトライ回数
        - `last_error (TEXT)`: 最後のエラーメッセージ
        - `created_at (TIMESTAMP)`
        - `updated_at (TIMESTAMP)`
        - Index: `(user_id, status)`, `(scheduled_at, status)` // ユーザー別一覧と実行対象検索用
- **Redis:**
    - **集計キャッシュ (Hash):**
        - `reaction_counts:{drop_id}` (Field: emoji_code, Value: count)
        - TTL: なし（永続的キャッシュ、イベント駆動で更新）
        - 人気のDropは優先的にメモリに保持
    - **ユーザー別リアクションキャッシュ (Set):**
        - `user_reactions:{drop_id}:{user_id}` (Member: emoji_code)
        - TTL: 1時間（アクセスパターンに応じて延長）
    - **ホットDropキャッシュ (Sorted Set):**
        - `hot_drops` (Score: リアクション総数, Member: drop_id)
        - 上位1000件のみ保持
    - **Pub/Sub Channels:** `drop_created`, `drop_updated`, `drop_deleted`, `reaction_created`, `reaction_deleted`
    - **Stream:** `reaction_aggregation_queue` // 集計更新タスクキュー

#### 8.2.3 イベントペイロード設計

- **drop_created/drop_updated/drop_deleted:**
  ```json
  {
    "drop_id": "123456789",
    "user_id": "987654321",
    "text": "Drop本文",
    "visibility": "public",
    "media_ids": [456, 789],
    "created_at": "2025-03-30T12:00:00Z",
    "updated_at": "2025-03-30T12:00:00Z"
  }
  ```

- **reaction_created/reaction_deleted:**
  ```json
  {
    "drop_id": "123456789",
    "user_id": "987654321",
    "emoji_code": "👍",
    "emoji_type": "unicode",  // "unicode" or "custom"
    "custom_emoji": {          // customの場合のみ（ドメインに閉じた情報）
      "shortcode": "custom_emoji",
      "url": "https://example.com/emoji/custom_emoji.png"
    },
    "created_at": "2025-03-30T12:00:00Z"
  }
  ```

- **drop_renoted/drop_unrenoted:**
  ```json
  {
    "renote_id": "111111111",
    "drop_id": "123456789",
    "user_id": "987654321",
    "comment": "これは良い投稿だ！",  // 引用リノートの場合のみ
    "created_at": "2025-03-30T12:00:00Z"
  }
  ```

- **drop_bookmarked/drop_unbookmarked:**
  ```json
  {
    "bookmark_id": "222222222",
    "drop_id": "123456789",
    "user_id": "987654321",
    "created_at": "2025-03-30T12:00:00Z"
  }
  ```

- **drop_pinned/drop_unpinned:**
  ```json
  {
    "drop_id": "123456789",
    "user_id": "987654321",
    "pinned_at": "2025-03-30T12:00:00Z"
  }
  ```

- **poll_created:**
  ```json
  {
    "poll_id": "333333333",
    "drop_id": "123456789",
    "options": [
      {"id": "opt1", "text": "選択肢1", "index": 0},
      {"id": "opt2", "text": "選択肢2", "index": 1}
    ],
    "multiple_choice": false,
    "expires_at": "2025-03-31T12:00:00Z",
    "created_at": "2025-03-30T12:00:00Z"
  }
  ```

- **poll_voted:**
  ```json
  {
    "poll_id": "333333333",
    "user_id": "987654321",
    "option_ids": ["opt1"],
    "created_at": "2025-03-30T12:00:00Z"
  }
  ```

- **drop_favorited/drop_unfavorited:**
  ```json
  {
    "favorite_id": "444444444",
    "drop_id": "123456789",
    "user_id": "987654321",
    "created_at": "2025-03-30T12:00:00Z"
  }
  ```

- **draft_saved/draft_updated/draft_deleted:**
  ```json
  {
    "draft_id": "555555555",
    "user_id": "987654321",
    "text": "下書き本文",
    "visibility": "public",
    "media_ids": [456, 789],
    "created_at": "2025-03-30T12:00:00Z",
    "updated_at": "2025-03-30T12:00:00Z"
  }
  ```

- **scheduled_drop_created/scheduled_drop_updated/scheduled_drop_cancelled:**
  ```json
  {
    "scheduled_drop_id": "666666666",
    "user_id": "987654321",
    "text": "予約投稿本文",
    "visibility": "public",
    "media_ids": [456, 789],
    "poll_config": { /* 投票設定 */ },
    "content_warning": { /* CW設定 */ },
    "scheduled_at": "2025-03-31T12:00:00Z",
    "status": "scheduled",
    "created_at": "2025-03-30T12:00:00Z",
    "updated_at": "2025-03-30T12:00:00Z"
  }
  ```

- **scheduled_drop_published:**
  ```json
  {
    "scheduled_drop_id": "666666666",
    "drop_id": "777777777",
    "user_id": "987654321",
    "published_at": "2025-03-31T12:00:00Z"
  }
  ```

- **drop_reported/report_resolved:**
  ```json
  {
    "report_id": "777777777",
    "drop_id": "123456789",
    "reporter_id": "987654321",
    "reason": "spam",
    "description": "スパム投稿です",
    "status": "pending",
    "resolved_by": "admin123",  // report_resolvedの場合のみ
    "resolved_at": "2025-03-30T13:00:00Z",  // report_resolvedの場合のみ
    "created_at": "2025-03-30T12:00:00Z"
  }
  ```

- **drop_impression_recorded:**
  ```json
  {
    "drop_id": "123456789",
    "user_id": "987654321",  // 匿名の場合はnull
    "impression_type": "view",  // view, timeline_appear等
    "created_at": "2025-03-30T12:00:00Z"
  }
  ```

- **drop_marked_sensitive/drop_unmarked_sensitive:**
  ```json
  {
    "drop_id": "123456789",
    "marked_by": "admin123",
    "reason": "inappropriate_content",
    "created_at": "2025-03-30T12:00:00Z"
  }
  ```

#### 8.2.4 avion-dropとavion-activitypubの責務分離

- **avion-dropの責務（ドメインに閉じる）:**
  - リアクションの追加・削除・集計
  - 絵文字コード（Unicode/カスタム）の管理
  - ドメインイベントの発行（上記のペイロード形式）
  - 絵文字の妥当性検証（存在確認、使用可否）

- **avion-activitypubの責務（プロトコル変換）:**
  - 対向サーバーの識別（nodeinfoから取得）
  - ActivityPubフォーマットへの変換
  - 対向先別のフィールドマッピング
    - Misskey系: `_misskey_reaction`フィールドに絵文字を格納
    - Pleroma系: `EmojiReact`アクティビティタイプを使用
    - Avion: 独自の`_avion_reaction`フィールドを使用
    - その他: 標準の`Like`アクティビティ
  - 受信したActivityをドメインイベントに変換
  
- **責務分離の利点:**
  - avion-dropはActivityPubプロトコルの詳細を知らない
  - 新しいプロトコル（AT Protocol等）への対応が容易
  - テストの独立性が保たれる
  - ドメインロジックとプロトコル変換が明確に分離

## 11. Operations & Monitoring (運用と監視)

- **主なオペレーション:**
    - DBマイグレーション。
    - Redis接続情報、Pub/Sub設定。
    - (必要に応じて) リアクション集計キャッシュの手動クリア。
- **監視/アラート:**
    - **メトリクス:**
        - gRPCリクエスト数、レイテンシ、エラーレート。
        - DB接続エラー、クエリ実行時間 (特にreaction_summariesテーブルアクセス)。
        - Redisキャッシュヒット率 (目標: 99%以上)、コマンド実行時間、メモリ使用量。
        - Pub/Sub発行エラー/遅延。
        - 集計更新タスクのキュー長、処理時間。
        - ホットDropのキャッシュメモリ使用量。
    - **ログ:** CRUD操作ログ、リアクション操作ログ、エラーログ。
    - **トレース:** API呼び出し、DBアクセス、キャッシュアクセス、イベント発行のトレース。
    - **アラート:** gRPCエラーレート急増、高レイテンシ、DB/Redis接続障害、Pub/Sub発行失敗、高負荷時のDB集計クエリ遅延。

## 12. エラーハンドリング戦略

> **注意:** エラーコードは[共通エラーコード標準](../common/errors/error-codes.md)に準拠します。このサービスではプレフィックス `DRP` を使用します。

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

// Drop関連エラー
var (
    ErrDropNotFound          = errors.New("drop not found")
    ErrDropAlreadyExists     = errors.New("drop already exists")
    ErrInvalidDropContent    = errors.New("invalid drop content")
    ErrDropTextTooLong       = errors.New("drop text too long")
    ErrDropDeleted           = errors.New("drop has been deleted")
    ErrInvalidVisibility     = errors.New("invalid visibility")
    ErrUnauthorizedAccess    = errors.New("unauthorized access")
    ErrCannotEditDrop        = errors.New("cannot edit drop")
)

// リアクション関連エラー
var (
    ErrReactionNotFound      = errors.New("reaction not found")
    ErrAlreadyReacted        = errors.New("already reacted with this emoji")
    ErrInvalidEmojiCode      = errors.New("invalid emoji code")
    ErrReactionLimitExceeded = errors.New("reaction limit exceeded")
    ErrCannotReactToOwnDrop  = errors.New("cannot react to own drop")
)

// メディア関連エラー
var (
    ErrInvalidMediaType      = errors.New("invalid media type")
    ErrMediaNotFound         = errors.New("media not found")
    ErrMediaSizeTooLarge     = errors.New("media size too large")
    ErrTooManyAttachments    = errors.New("too many attachments")
)

// 集計関連エラー
var (
    ErrAggregationFailed     = errors.New("aggregation failed")
    ErrCacheUpdateFailed     = errors.New("cache update failed")
    ErrDataInconsistency     = errors.New("data inconsistency detected")
)

// リノート関連エラー
var (
    ErrRenoteNotFound        = errors.New("renote not found")
    ErrAlreadyRenoted        = errors.New("already renoted")
    ErrCannotRenoteOwnDrop   = errors.New("cannot renote own drop")
    ErrCannotRenotePrivate   = errors.New("cannot renote private drop")
)

// ブックマーク関連エラー
var (
    ErrBookmarkNotFound      = errors.New("bookmark not found")
    ErrAlreadyBookmarked     = errors.New("already bookmarked")
    ErrBookmarkLimitExceeded = errors.New("bookmark limit exceeded")
)

// 投票関連エラー
var (
    ErrPollNotFound          = errors.New("poll not found")
    ErrPollExpired           = errors.New("poll has expired")
    ErrAlreadyVoted          = errors.New("already voted")
    ErrInvalidPollOption     = errors.New("invalid poll option")
    ErrTooFewOptions         = errors.New("poll must have at least 2 options")
    ErrTooManyOptions        = errors.New("poll has too many options")
)

// ピン留め関連エラー
var (
    ErrAlreadyPinned         = errors.New("already pinned")
    ErrNotPinned             = errors.New("not pinned")
    ErrPinLimitExceeded      = errors.New("pin limit exceeded")
)

// お気に入り関連エラー
var (
    ErrFavoriteNotFound      = errors.New("favorite not found")
    ErrAlreadyFavorited      = errors.New("already favorited")
    ErrFavoriteLimitExceeded = errors.New("favorite limit exceeded")
)

// 下書き関連エラー
var (
    ErrDraftNotFound         = errors.New("draft not found")
    ErrDraftLimitExceeded    = errors.New("draft limit exceeded")
    ErrInvalidDraftContent   = errors.New("invalid draft content")
)

// 予約投稿関連エラー
var (
    ErrScheduledDropNotFound = errors.New("scheduled drop not found")
    ErrInvalidScheduleTime   = errors.New("invalid schedule time")
    ErrScheduleLimitExceeded = errors.New("schedule limit exceeded")
    ErrPastScheduleTime      = errors.New("schedule time is in the past")
)

// 通報関連エラー
var (
    ErrReportNotFound        = errors.New("report not found")
    ErrAlreadyReported       = errors.New("already reported")
    ErrInvalidReportReason   = errors.New("invalid report reason")
    ErrReportAlreadyResolved = errors.New("report already resolved")
)

// 分析・インプレッション関連エラー
var (
    ErrImpressionNotFound    = errors.New("impression not found")
    ErrAnalyticsNotAvailable = errors.New("analytics not available")
)

// ハッシュタグ・メンション関連エラー
var (
    ErrInvalidHashtag        = errors.New("invalid hashtag")
    ErrInvalidMention        = errors.New("invalid mention")
    ErrTooManyHashtags       = errors.New("too many hashtags")
    ErrTooManyMentions       = errors.New("too many mentions")
)
```

### 各層でのエラーハンドリング

#### Handler層
- ドメインエラーを適切なgRPCステータスコードに変換
- クライアントに適切なエラーメッセージを返す

```go
func (h *CreateDropCommandHandler) CreateDrop(ctx context.Context, req *pb.CreateDropRequest) (*pb.CreateDropResponse, error) {
    output, err := h.useCase.Execute(ctx, input)
    if err != nil {
        switch {
        case errors.Is(err, domain.ErrDropTextTooLong):
            return nil, status.Error(codes.InvalidArgument, "drop text exceeds maximum length")
        case errors.Is(err, domain.ErrInvalidVisibility):
            return nil, status.Error(codes.InvalidArgument, "invalid visibility setting")
        case errors.Is(err, domain.ErrTooManyAttachments):
            return nil, status.Error(codes.InvalidArgument, "too many media attachments")
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
func (u *AddReactionCommandUseCase) Execute(ctx context.Context, input *AddReactionInput) (*AddReactionOutput, error) {
    // Dropの取得
    drop, err := u.dropRepo.FindByID(ctx, input.DropID)
    if err != nil {
        if errors.Is(err, repository.ErrNotFound) {
            return nil, domain.ErrDropNotFound
        }
        return nil, fmt.Errorf("find drop: %w", err)
    }
    
    // ビジネスルールの検証
    if drop.AuthorID == input.UserID {
        return nil, domain.ErrCannotReactToOwnDrop
    }
    
    // リアクションの追加
    if err := u.reactionRepo.Create(ctx, reaction); err != nil {
        if errors.Is(err, repository.ErrAlreadyExists) {
            return nil, domain.ErrAlreadyReacted
        }
        return nil, fmt.Errorf("create reaction: %w", err)
    }
    
    return output, nil
}
```

#### Infrastructure層
- データベースの制約違反を適切なドメインエラーにマッピング
- 外部システムのエラーをドメインエラーに変換

```go
func (r *PostgreSQLDropRepository) Create(ctx context.Context, drop *domain.Drop) error {
    _, err := r.db.ExecContext(ctx, query, args...)
    if err != nil {
        var pgErr *pgconn.PgError
        if errors.As(err, &pgErr) {
            switch pgErr.Code {
            case "23505": // unique_violation
                return domain.ErrDropAlreadyExists
            case "23514": // check_violation
                if pgErr.ConstraintName == "drops_text_length_check" {
                    return domain.ErrDropTextTooLong
                }
            }
        }
        return fmt.Errorf("insert drop: %w", err)
    }
    return nil
}
```

## 13. 構造化ログ戦略

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
    Service     string    `json:"service"`     // "avion-drop"
    Version     string    `json:"version"`     // サービスバージョン
    TraceID     string    `json:"trace_id"`    // OpenTelemetry TraceID
    SpanID      string    `json:"span_id"`     // OpenTelemetry SpanID
    
    // コンテキストフィールド
    UserID      string    `json:"user_id,omitempty"`
    DropID      string    `json:"drop_id,omitempty"`
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
    slog.String("method", "CreateDrop"),
    slog.String("trace_id", traceID),
    slog.String("user_id", userID),
    slog.String("layer", "handler"),
)

logger.Error("gRPC request failed",
    slog.String("method", "CreateDrop"),
    slog.String("trace_id", traceID),
    slog.String("error", err.Error()),
    slog.String("error_code", "INVALID_ARGUMENT"),
    slog.Int64("duration_ms", duration),
)
```

#### Use Case層
```go
logger.Info("drop creation started",
    slog.String("trace_id", ctx.Value("trace_id").(string)),
    slog.String("user_id", userID),
    slog.String("visibility", visibility),
    slog.String("layer", "usecase"),
)

logger.Info("reaction added successfully",
    slog.String("drop_id", dropID),
    slog.String("user_id", userID),
    slog.String("emoji_code", emojiCode),
    slog.String("layer", "usecase"),
)
```

#### Infrastructure層
```go
logger.Debug("database query executed",
    slog.String("query", "INSERT INTO drops"),
    slog.String("table", "drops"),
    slog.Int64("duration_ms", queryDuration),
    slog.String("layer", "infra"),
)

logger.Warn("redis cache miss",
    slog.String("key", fmt.Sprintf("reaction_counts:%s", dropID)),
    slog.String("cache_type", "reaction_summary"),
    slog.String("layer", "infra"),
)
```

### リアクション処理のログ
```go
// リアクション追加時
logger.Info("reaction processing",
    slog.String("event", "reaction_added"),
    slog.String("drop_id", dropID),
    slog.String("user_id", userID),
    slog.String("emoji_code", emojiCode),
    slog.Int("total_reactions", totalCount),
    slog.Bool("is_hot_drop", isHotDrop),
)

// 集計更新時
logger.Info("reaction aggregation updated",
    slog.String("drop_id", dropID),
    slog.String("emoji_code", emojiCode),
    slog.Int("old_count", oldCount),
    slog.Int("new_count", newCount),
    slog.Int64("update_duration_ms", duration),
)
```

### イベント発行のログ
```go
logger.Info("event published",
    slog.String("event_type", "drop_created"),
    slog.String("channel", "drop_events"),
    slog.String("drop_id", dropID),
    slog.Any("payload_size", len(payload)),
)
```

### エラーログの詳細化
```go
logger.Error("failed to update reaction summary",
    slog.String("drop_id", dropID),
    slog.String("emoji_code", emojiCode),
    slog.String("error", err.Error()),
    slog.String("error_type", fmt.Sprintf("%T", err)),
    slog.String("stack_trace", string(debug.Stack())),
    slog.String("layer", "infra"),
)
```

### CRITICALレベルのログ
```go
// データ整合性の致命的エラー
logger.Critical("data integrity violation detected",
    slog.String("event", "critical_integrity_error"),
    slog.String("drop_id", dropID),
    slog.String("error", "reaction count mismatch between DB and cache"),
    slog.Int("db_count", dbCount),
    slog.Int("cache_count", cacheCount),
    slog.String("action", "initiating_panic"),
)
// この後panicを発生させる

// システムリソースの枯渇
logger.Critical("system resource exhausted",
    slog.String("event", "critical_resource_error"),
    slog.String("resource", "database_connections"),
    slog.Int("max_connections", maxConn),
    slog.Int("current_connections", currentConn),
    slog.String("action", "service_shutdown_required"),
)
```

### ログ集約とクエリ
- **出力先**: 標準出力（Kubernetes環境ではFluentd/Fluent Bitが収集）
- **集約先**: Elasticsearch、CloudWatch Logs、またはLoki
- **クエリ例**:
  ```
  service="avion-drop" AND layer="usecase" AND error_code="PERMISSION_DENIED"
  service="avion-drop" AND method="GetReactionSummary" AND duration_ms>100
  service="avion-drop" AND event="reaction_added" AND is_hot_drop=true
  service="avion-drop" AND level="CRITICAL"
  ```

### セキュリティ考慮事項
- パスワードやトークンなどの機密情報は絶対にログに含めない
- 個人情報（メールアドレス等）は必要最小限に留める
- ユーザーIDは含めるが、ユーザー名などの識別可能な情報は避ける

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
    Service     string    `json:"service"`     // "avion-drop"
    Version     string    `json:"version"`     // サービスバージョン
    TraceID     string    `json:"trace_id"`    // OpenTelemetry TraceID
    SpanID      string    `json:"span_id"`     // OpenTelemetry SpanID
    
    // コンテキストフィールド
    UserID      string    `json:"user_id,omitempty"`
    DropID      string    `json:"drop_id,omitempty"`
    ReactionID  string    `json:"reaction_id,omitempty"`
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
    slog.String("method", "CreateDrop"),
    slog.String("trace_id", traceID),
    slog.String("user_id", userID),
    slog.String("visibility", visibility),
    slog.Int("text_length", len(text)),
    slog.String("layer", "handler"),
)

logger.Error("gRPC request failed",
    slog.String("method", "GetDrop"),
    slog.String("trace_id", traceID),
    slog.String("drop_id", dropID),
    slog.String("error", err.Error()),
    slog.String("error_code", "DROP_NOT_FOUND"),
    slog.Int64("duration_ms", duration),
    slog.String("layer", "handler"),
)
```

#### Use Case層
```go
logger.Info("drop creation processing",
    slog.String("trace_id", ctx.Value("trace_id").(string)),
    slog.String("user_id", userID),
    slog.String("visibility", visibility),
    slog.Int("media_count", len(mediaIDs)),
    slog.String("layer", "usecase"),
)

logger.Info("reaction processing",
    slog.String("trace_id", ctx.Value("trace_id").(string)),
    slog.String("drop_id", dropID),
    slog.String("user_id", userID),
    slog.String("emoji_code", emojiCode),
    slog.String("action", "add"), // add/remove
    slog.String("layer", "usecase"),
)
```

#### Infrastructure層
```go
logger.Debug("database query executed",
    slog.String("table", "drops"),
    slog.String("operation", "insert"),
    slog.Int64("duration_ms", queryDuration),
    slog.String("layer", "infra"),
)

logger.Warn("redis cache miss",
    slog.String("cache_type", "reaction_summary"),
    slog.String("drop_id", dropID),
    slog.String("layer", "infra"),
)
```

### Drop操作のログ
```go
// Drop作成成功
logger.Info("drop created",
    slog.String("event", "drop_created"),
    slog.String("drop_id", dropID),
    slog.String("user_id", userID),
    slog.String("visibility", visibility),
    slog.Int("text_length", textLength),
    slog.Int("media_count", mediaCount),
    slog.Bool("has_hashtags", hasHashtags),
)

// Drop削除
logger.Info("drop deleted",
    slog.String("event", "drop_deleted"),
    slog.String("drop_id", dropID),
    slog.String("user_id", userID),
    slog.String("deleted_by", deletedByUserID),
    slog.Int("reaction_count", reactionCount),
    slog.Int64("age_seconds", ageSeconds),
)

// Drop編集
logger.Info("drop edited",
    slog.String("event", "drop_edited"),
    slog.String("drop_id", dropID),
    slog.String("user_id", userID),
    slog.Int("old_text_length", oldTextLength),
    slog.Int("new_text_length", newTextLength),
    slog.Int64("edit_time_seconds", editTimeSeconds),
)

// アクセス拒否
logger.Warn("drop access denied",
    slog.String("event", "access_denied"),
    slog.String("drop_id", dropID),
    slog.String("user_id", userID),
    slog.String("visibility", visibility),
    slog.String("reason", "not_follower"),
)
```

### リアクション操作のログ
```go
// リアクション追加
logger.Info("reaction added",
    slog.String("event", "reaction_added"),
    slog.String("drop_id", dropID),
    slog.String("user_id", userID),
    slog.String("emoji_code", emojiCode),
    slog.String("emoji_type", emojiType), // unicode/custom
    slog.Bool("is_hot_drop", isHotDrop),
)

// リアクション削除
logger.Info("reaction removed",
    slog.String("event", "reaction_removed"),
    slog.String("drop_id", dropID),
    slog.String("user_id", userID),
    slog.String("emoji_code", emojiCode),
)

// 重複リアクション
logger.Warn("duplicate reaction attempt",
    slog.String("event", "duplicate_reaction"),
    slog.String("drop_id", dropID),
    slog.String("user_id", userID),
    slog.String("emoji_code", emojiCode),
)

// リアクション集計取得
logger.Debug("reaction summary fetched",
    slog.String("event", "reaction_summary_fetched"),
    slog.String("drop_id", dropID),
    slog.Int("emoji_count", emojiCount),
    slog.Int("total_reactions", totalReactions),
    slog.Bool("cache_hit", cacheHit),
    slog.Int64("fetch_time_ms", fetchTimeMs),
)
```

### イベント発行のログ
```go
// イベント発行成功
logger.Info("event published",
    slog.String("event", "event_published"),
    slog.String("channel", channel),
    slog.String("event_type", eventType),
    slog.String("drop_id", dropID),
    slog.Int("payload_size", payloadSize),
)

// イベント発行エラー
logger.Error("event publish failed",
    slog.String("event", "event_publish_failed"),
    slog.String("channel", channel),
    slog.String("event_type", eventType),
    slog.String("error", err.Error()),
    slog.Bool("will_retry", willRetry),
)
```

### キャッシュ操作のログ
```go
// キャッシュ更新
logger.Debug("cache updated",
    slog.String("event", "cache_updated"),
    slog.String("cache_type", "reaction_summary"),
    slog.String("drop_id", dropID),
    slog.String("operation", operation), // set/delete/increment
    slog.Int64("ttl_seconds", ttlSeconds),
)

// キャッシュヒット率
logger.Info("cache statistics",
    slog.String("event", "cache_stats"),
    slog.String("period", "5m"),
    slog.Float64("hit_rate", hitRate),
    slog.Int("total_requests", totalRequests),
    slog.Int("cache_hits", cacheHits),
    slog.Int("cache_misses", cacheMisses),
)
```

### パフォーマンス関連のログ
```go
// 遅いクエリ
logger.Warn("slow query detected",
    slog.String("event", "slow_query"),
    slog.String("query_type", "get_user_drops"),
    slog.String("user_id", userID),
    slog.Int64("duration_ms", duration),
    slog.Int("result_count", resultCount),
    slog.Int("page_size", pageSize),
)

// ホットDrop検出
logger.Info("hot drop detected",
    slog.String("event", "hot_drop"),
    slog.String("drop_id", dropID),
    slog.Int("reaction_rate_per_minute", reactionRate),
    slog.Int("total_reactions", totalReactions),
    slog.String("action", "cache_priority_increased"),
)

// 処理統計
logger.Info("processing statistics",
    slog.String("event", "processing_stats"),
    slog.String("period", "5m"),
    slog.Int("drops_created", dropsCreated),
    slog.Int("drops_deleted", dropsDeleted),
    slog.Int("reactions_added", reactionsAdded),
    slog.Int("reactions_removed", reactionsRemoved),
    slog.Float64("avg_drop_creation_ms", avgDropCreationMs),
    slog.Float64("avg_reaction_add_ms", avgReactionAddMs),
)
```

### エラー処理のログ
```go
// バリデーションエラー
logger.Warn("validation failed",
    slog.String("event", "validation_error"),
    slog.String("field", fieldName),
    slog.String("reason", reason),
    slog.Any("value", value),
    slog.String("layer", layer),
)

// リトライ可能エラー
logger.Warn("retryable error occurred",
    slog.String("event", "retryable_error"),
    slog.String("operation", operation),
    slog.String("error", err.Error()),
    slog.Int("retry_count", retryCount),
    slog.Int("max_retries", maxRetries),
    slog.Int64("backoff_ms", backoffMs),
)

// 致命的エラー
logger.Error("fatal error",
    slog.String("event", "fatal_error"),
    slog.String("component", component),
    slog.String("error", err.Error()),
    slog.String("stack_trace", string(debug.Stack())),
    slog.String("action", "service_degraded"),
)
```

### CRITICALレベルログの例
```go
// データ整合性エラー
logger.With(slog.String("level", "CRITICAL")).Error("data integrity violation",
    slog.String("event", "data_corruption"),
    slog.String("table", "reaction_summaries"),
    slog.String("drop_id", dropID),
    slog.String("inconsistency", "count_mismatch"),
    slog.Int("db_count", dbCount),
    slog.Int("cache_count", cacheCount),
    slog.String("action", "immediate_reconciliation_required"),
)

// リアクションシステム完全障害
logger.With(slog.String("level", "CRITICAL")).Error("reaction system failure",
    slog.String("component", "reaction_service"),
    slog.String("error", "all_operations_failing"),
    slog.Float64("error_rate", 1.0),
    slog.String("impact", "reactions_completely_disabled"),
    slog.String("action", "emergency_maintenance_required"),
)

// Redisキャッシュ完全喪失
logger.With(slog.String("level", "CRITICAL")).Error("cache system failure",
    slog.String("component", "redis_cache"),
    slog.String("error", "connection_pool_exhausted"),
    slog.String("impact", "severe_performance_degradation"),
    slog.Int("affected_drops", affectedDropCount),
    slog.String("action", "cache_rebuild_required"),
)

// Drop削除の連鎖障害
logger.With(slog.String("level", "CRITICAL")).Error("cascade deletion failure",
    slog.String("event", "deletion_failure"),
    slog.String("drop_id", dropID),
    slog.String("error", "orphaned_reactions_detected"),
    slog.Int("orphaned_count", orphanedCount),
    slog.String("action", "manual_cleanup_required"),
)
```

### ログ集約とクエリ
- **出力先**: 標準出力（Kubernetes環境ではFluentd/Fluent Bitが収集）
- **集約先**: Elasticsearch、CloudWatch Logs、またはLoki
- **クエリ例**:
  ```
  service="avion-drop" AND event="drop_created" AND visibility="public"
  service="avion-drop" AND event="reaction_added" AND emoji_code=":heart:"
  service="avion-drop" AND event="hot_drop" AND reaction_rate_per_minute>100
  service="avion-drop" AND event="access_denied" AND user_id="12345"
  service="avion-drop" AND layer="infra" AND duration_ms>1000
  service="avion-drop" AND level="CRITICAL"
  ```

### セキュリティ考慮事項
- Drop本文の内容は最小限の情報のみ記録（文字数など）
- 個人情報やセンシティブな内容は記録しない
- ユーザーIDは記録するが、他の識別可能情報は避ける
- 削除されたDropの内容は復元できないようにする
- IPアドレスなどのネットワーク情報は必要最小限に

## 14. ドメインオブジェクトとDBスキーマのマッピング

### Drop Aggregate → drops テーブル

```sql
CREATE TABLE drops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id UUID NOT NULL REFERENCES users(id),
    text TEXT NOT NULL CHECK (char_length(text) <= 500),
    visibility TEXT NOT NULL CHECK (visibility IN ('public', 'unlisted', 'followers', 'direct')),
    reply_to_drop_id UUID REFERENCES drops(id),
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    edit_count INTEGER NOT NULL DEFAULT 0,
    last_edited_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_drops_author_id (author_id),
    INDEX idx_drops_created_at (created_at DESC),
    INDEX idx_drops_visibility (visibility) WHERE is_deleted = FALSE,
    INDEX idx_drops_reply_to (reply_to_drop_id) WHERE reply_to_drop_id IS NOT NULL
);
```

### Reaction Aggregate → reactions テーブル

```sql
CREATE TABLE reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    drop_id UUID NOT NULL REFERENCES drops(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    emoji_code TEXT NOT NULL CHECK (length(emoji_code) <= 64),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT reactions_drop_user_emoji_unique UNIQUE (drop_id, user_id, emoji_code),
    INDEX idx_reactions_drop_id (drop_id),
    INDEX idx_reactions_user_id (user_id),
    INDEX idx_reactions_created_at (created_at DESC)
);
```

### ReactionSummary Aggregate → reaction_summaries テーブル

```sql
CREATE TABLE reaction_summaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    drop_id UUID NOT NULL REFERENCES drops(id) ON DELETE CASCADE,
    emoji_code TEXT NOT NULL CHECK (length(emoji_code) <= 64),
    count INTEGER NOT NULL DEFAULT 0 CHECK (count >= 0),
    last_updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT reaction_summaries_drop_emoji_unique UNIQUE (drop_id, emoji_code),
    INDEX idx_reaction_summaries_drop_id (drop_id),
    INDEX idx_reaction_summaries_count (count DESC) WHERE count > 0
);
```

### MediaAttachment Value Object → drop_media_attachments テーブル

```sql
CREATE TABLE drop_media_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    drop_id UUID NOT NULL REFERENCES drops(id) ON DELETE CASCADE,
    media_id UUID NOT NULL,
    media_type TEXT NOT NULL CHECK (media_type IN ('image', 'video', 'audio')),
    media_url TEXT NOT NULL,
    thumbnail_url TEXT,
    alt_text TEXT,
    order_index INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT drop_media_attachments_drop_order_unique UNIQUE (drop_id, order_index),
    INDEX idx_drop_media_attachments_drop_id (drop_id)
);
```

### Drop編集履歴 → drop_edit_history テーブル

```sql
CREATE TABLE drop_edit_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    drop_id UUID NOT NULL REFERENCES drops(id) ON DELETE CASCADE,
    edit_number INTEGER NOT NULL,
    old_text TEXT NOT NULL,
    new_text TEXT NOT NULL,
    edited_by UUID NOT NULL REFERENCES users(id),
    edited_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT drop_edit_history_drop_edit_unique UNIQUE (drop_id, edit_number),
    INDEX idx_drop_edit_history_drop_id (drop_id)
);
```

### Renote Aggregate → renotes テーブル

```sql
CREATE TABLE renotes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    drop_id UUID NOT NULL REFERENCES drops(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    comment TEXT, -- 引用リノート時のコメント
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT renotes_drop_user_unique UNIQUE (drop_id, user_id),
    INDEX idx_renotes_drop_id (drop_id),
    INDEX idx_renotes_user_id (user_id),
    INDEX idx_renotes_created_at (created_at DESC)
);
```

### Bookmark Aggregate → bookmarks テーブル

```sql
CREATE TABLE bookmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    drop_id UUID NOT NULL REFERENCES drops(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT bookmarks_drop_user_unique UNIQUE (drop_id, user_id),
    INDEX idx_bookmarks_user_id_created_at (user_id, created_at DESC),
    INDEX idx_bookmarks_drop_id (drop_id)
);
```

### Poll Aggregate → polls テーブル

```sql
CREATE TABLE polls (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    drop_id UUID NOT NULL REFERENCES drops(id) ON DELETE CASCADE,
    multiple_choice BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT polls_drop_unique UNIQUE (drop_id),
    INDEX idx_polls_expires_at (expires_at)
);
```

### PollOption Entity → poll_options テーブル

```sql
CREATE TABLE poll_options (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id UUID NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
    option_text TEXT NOT NULL CHECK (char_length(option_text) <= 100),
    option_index INTEGER NOT NULL,
    vote_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT poll_options_poll_index_unique UNIQUE (poll_id, option_index),
    INDEX idx_poll_options_poll_id (poll_id)
);
```

### PollVote Entity → poll_votes テーブル

```sql
CREATE TABLE poll_votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    poll_id UUID NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    option_id UUID NOT NULL REFERENCES poll_options(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT poll_votes_poll_user_option_unique UNIQUE (poll_id, user_id, option_id),
    INDEX idx_poll_votes_poll_id (poll_id),
    INDEX idx_poll_votes_user_id (user_id)
);
```

### Pin情報 → pinned_drops テーブル

```sql
CREATE TABLE pinned_drops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    drop_id UUID NOT NULL REFERENCES drops(id) ON DELETE CASCADE,
    pinned_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pinned_drops_user_drop_unique UNIQUE (user_id, drop_id),
    INDEX idx_pinned_drops_user_id (user_id)
);
```

### Favorite Aggregate → favorites テーブル

```sql
CREATE TABLE favorites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    drop_id UUID NOT NULL REFERENCES drops(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT favorites_drop_user_unique UNIQUE (drop_id, user_id),
    INDEX idx_favorites_user_id_created_at (user_id, created_at DESC),
    INDEX idx_favorites_drop_id (drop_id)
);
```

### Draft Aggregate → drafts テーブル

```sql
CREATE TABLE drafts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    text TEXT NOT NULL,
    visibility TEXT NOT NULL CHECK (visibility IN ('public', 'unlisted', 'followers', 'direct')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_drafts_user_id_updated_at (user_id, updated_at DESC)
);
```

### Draft媒体添付 → draft_media_attachments テーブル

```sql
CREATE TABLE draft_media_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    draft_id UUID NOT NULL REFERENCES drafts(id) ON DELETE CASCADE,
    media_id UUID NOT NULL,
    media_type TEXT NOT NULL CHECK (media_type IN ('image', 'video', 'audio')),
    order_index INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT draft_media_attachments_draft_order_unique UNIQUE (draft_id, order_index),
    INDEX idx_draft_media_attachments_draft_id (draft_id)
);
```

### ScheduledDrop Aggregate → scheduled_drops テーブル

```sql
CREATE TABLE scheduled_drops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    text TEXT NOT NULL CHECK (char_length(text) <= 500),
    visibility TEXT NOT NULL CHECK (visibility IN ('public', 'unlisted', 'followers', 'direct')),
    scheduled_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'published', 'canceled')),
    published_drop_id UUID REFERENCES drops(id),
    INDEX idx_scheduled_drops_user_id (user_id),
    INDEX idx_scheduled_drops_scheduled_at (scheduled_at) WHERE status = 'pending'
);
```

### ScheduledDrop媒体添付 → scheduled_drop_media_attachments テーブル

```sql
CREATE TABLE scheduled_drop_media_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scheduled_drop_id UUID NOT NULL REFERENCES scheduled_drops(id) ON DELETE CASCADE,
    media_id UUID NOT NULL,
    media_type TEXT NOT NULL CHECK (media_type IN ('image', 'video', 'audio')),
    order_index INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT scheduled_drop_media_scheduled_order_unique UNIQUE (scheduled_drop_id, order_index),
    INDEX idx_scheduled_drop_media_scheduled_drop_id (scheduled_drop_id)
);
```

### DropReport Aggregate → drop_reports テーブル

```sql
CREATE TABLE drop_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    drop_id UUID NOT NULL REFERENCES drops(id) ON DELETE CASCADE,
    reporter_id UUID NOT NULL REFERENCES users(id),
    reason TEXT NOT NULL CHECK (reason IN ('spam', 'abuse', 'inappropriate_content', 'copyright', 'other')),
    description TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'resolved', 'rejected')),
    resolved_by UUID REFERENCES users(id),
    resolved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT drop_reports_drop_reporter_unique UNIQUE (drop_id, reporter_id),
    INDEX idx_drop_reports_status (status),
    INDEX idx_drop_reports_created_at (created_at DESC) WHERE status = 'pending'
);
```

### Drop閲覧記録 → drop_impressions テーブル

```sql
CREATE TABLE drop_impressions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    drop_id UUID NOT NULL REFERENCES drops(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id), -- NULLの場合は匿名閲覧
    impression_type TEXT NOT NULL CHECK (impression_type IN ('view', 'timeline_appear', 'detail_view')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_drop_impressions_drop_id (drop_id),
    INDEX idx_drop_impressions_created_at (created_at DESC)
);
```

### Drop分析集計 → drop_analytics テーブル

```sql
CREATE TABLE drop_analytics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    drop_id UUID NOT NULL REFERENCES drops(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    view_count INTEGER NOT NULL DEFAULT 0,
    timeline_appear_count INTEGER NOT NULL DEFAULT 0,
    detail_view_count INTEGER NOT NULL DEFAULT 0,
    reaction_count INTEGER NOT NULL DEFAULT 0,
    renote_count INTEGER NOT NULL DEFAULT 0,
    reply_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT drop_analytics_drop_date_unique UNIQUE (drop_id, date),
    INDEX idx_drop_analytics_drop_id (drop_id),
    INDEX idx_drop_analytics_date (date)
);
```

### ハッシュタグ → hashtags テーブル

```sql
CREATE TABLE hashtags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    normalized_name TEXT NOT NULL, -- 正規化されたハッシュタグ名（小文字）
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT hashtags_normalized_name_unique UNIQUE (normalized_name),
    INDEX idx_hashtags_name (name)
);
```

### Dropハッシュタグ関連 → drop_hashtags テーブル

```sql
CREATE TABLE drop_hashtags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    drop_id UUID NOT NULL REFERENCES drops(id) ON DELETE CASCADE,
    hashtag_id UUID NOT NULL REFERENCES hashtags(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT drop_hashtags_drop_hashtag_unique UNIQUE (drop_id, hashtag_id),
    INDEX idx_drop_hashtags_drop_id (drop_id),
    INDEX idx_drop_hashtags_hashtag_id (hashtag_id)
);
```

### メンション → drop_mentions テーブル

```sql
CREATE TABLE drop_mentions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    drop_id UUID NOT NULL REFERENCES drops(id) ON DELETE CASCADE,
    mentioned_user_id UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT drop_mentions_drop_user_unique UNIQUE (drop_id, mentioned_user_id),
    INDEX idx_drop_mentions_drop_id (drop_id),
    INDEX idx_drop_mentions_mentioned_user_id (mentioned_user_id)
);
```

### センシティブマーク → drop_sensitive_marks テーブル

```sql
CREATE TABLE drop_sensitive_marks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    drop_id UUID NOT NULL REFERENCES drops(id) ON DELETE CASCADE,
    marked_by UUID NOT NULL REFERENCES users(id),
    reason TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT drop_sensitive_marks_drop_unique UNIQUE (drop_id)
);
```

### Value Objectの一時保存（Redis）

```redis
# リアクション集計キャッシュ
KEY: reaction_counts:{drop_id}
VALUE: {
    "reactions": {
        "\ud83d\udc4d": 10,
        "\u2764\ufe0f": 5,
        "\ud83d\ude02": 3
    },
    "total_count": 18,
    "updated_at": "2025-01-01T00:00:00Z"
}
TTL: 3600 (1時間)

# ホットDropキャッシュ
KEY: hot_drop:{drop_id}
VALUE: DropのJSON表現
TTL: 300 (5分)

# ユーザーリアクション状態
KEY: user_reactions:{user_id}:{drop_id}
VALUE: ["\ud83d\udc4d", "\u2764\ufe0f"]
TTL: 3600 (1時間)

# ユーザーブックマーク
KEY: user_bookmarks:{user_id}
VALUE: Sorted Set (score: timestamp, member: drop_id)
TTL: なし（永続的）

# 投票結果キャッシュ
KEY: poll_results:{poll_id}
VALUE: {
    "options": [
        {"id": "opt1", "text": "選択肢1", "votes": 10},
        {"id": "opt2", "text": "選択肢2", "votes": 5}
    ],
    "total_votes": 15,
    "expires_at": "2025-01-02T00:00:00Z"
}
TTL: 投票期限まで

# ユーザーの投票状態
KEY: user_poll_votes:{user_id}:{poll_id}
VALUE: ["option_id1", "option_id2"]
TTL: 投票期限まで

# スレッドキャッシュ
KEY: drop_thread:{drop_id}
VALUE: 会話ツリーのJSON表現
TTL: 3600 (1時間)

# ユーザーの固定Drop
KEY: user_pinned_drops:{user_id}
VALUE: Sorted Set (score: pinned_at timestamp, member: drop_id)
TTL: なし（永続的）

# ユーザーのお気に入り
KEY: user_favorites:{user_id}
VALUE: Sorted Set (score: timestamp, member: drop_id)
TTL: なし（永続的）

# Dropのお気に入りユーザー
KEY: drop_favorites:{drop_id}
VALUE: Set (member: user_id)
TTL: 3600 (1時間)

# ユーザーの下書き
KEY: user_drafts:{user_id}
VALUE: Sorted Set (score: updated_at timestamp, member: draft_id)
TTL: なし（永続的）

# 下書き詳細
KEY: draft:{draft_id}
VALUE: DraftのJSON表現
TTL: なし（永続的）

# 予約投稿
KEY: scheduled_drops
VALUE: Sorted Set (score: scheduled_at timestamp, member: scheduled_drop_id)
TTL: なし（永続的）

# 予約投稿詳細
KEY: scheduled_drop:{scheduled_drop_id}
VALUE: ScheduledDropのJSON表現
TTL: なし（永続的）

# Drop閲覧数キャッシュ
KEY: drop_impressions:{drop_id}
VALUE: {
    "view_count": 100,
    "timeline_appear_count": 500,
    "detail_view_count": 50,
    "last_updated": "2025-01-01T00:00:00Z"
}
TTL: 3600 (1時間)

# Drop分析データキャッシュ
KEY: drop_analytics:{drop_id}:{date}
VALUE: {
    "view_count": 100,
    "timeline_appear_count": 500,
    "detail_view_count": 50,
    "reaction_count": 20,
    "renote_count": 5,
    "reply_count": 10
}
TTL: 86400 (24時間)

# トレンドハッシュタグ
KEY: trending_hashtags
VALUE: Sorted Set (score: 使用回数, member: hashtag_id)
TTL: 300 (5分)

# ハッシュタグ情報
KEY: hashtag:{hashtag_id}
VALUE: {
    "name": "技術",
    "normalized_name": "技術",
    "usage_count": 1000
}
TTL: 3600 (1時間)

# Dropのハッシュタグ
KEY: drop_hashtags:{drop_id}
VALUE: Set (member: hashtag_id)
TTL: 3600 (1時間)

# 通報キュー
KEY: pending_reports
VALUE: List (member: report_id)
TTL: なし（永続的）

# センシティブマーク付きDrop
KEY: sensitive_drops
VALUE: Set (member: drop_id)
TTL: なし（永続的）
```

## 15. avion-activitypubサービスとの連携仕様

### 11.1 イベント連携
avion-dropはRedis Pub/Subを通じて以下のイベントを発行します。avion-activitypubはこれらのイベントを購読し、適切なActivityPubアクティビティに変換します。

- `drop_created`: Createアクティビティに変換
- `drop_updated`: Updateアクティビティに変換
- `drop_deleted`: Deleteアクティビティに変換
- `reaction_created`: Like/EmojiReactアクティビティに変換（対向先に応じて）
- `reaction_deleted`: Undo(Like/EmojiReact)アクティビティに変換
- `drop_renoted`: Announceアクティビティに変換
- `drop_unrenoted`: Undo(Announce)アクティビティに変換
- `poll_created`: Questionアクティビティに変換
- `poll_voted`: CreateアクティビティでNoteを送信（投票結果を含む）

### 11.2 プロトコル変換の責務
avion-activitypubサービスが以下の全ての責務を担います：

1. **サーバータイプの識別**
   - nodeinfoからの情報取得
   - サーバータイプのキャッシュ管理

2. **アクティビティフォーマットの選択**
   - Misskey系: `_misskey_reaction`フィールド使用
   - Pleroma系: `EmojiReact`アクティビティタイプ使用
   - Avion: 独自の`_avion_reaction`フィールド使用
   - その他: 標準`Like`アクティビティ

3. **カスタム絵文字の処理**
   - 送信時のtag配列への変換
   - 受信時の絵文字情報抽出
   - フォールバック処理

### 11.3 インターフェース設計の原則
- avion-dropは純粋なドメインイベントのみを発行
- ActivityPubプロトコルの詳細はavion-activitypubに完全に隠蔽
- 将来的な他プロトコル（AT Protocol等）への対応を容易にする設計

## 16. Drop編集機能の詳細設計

### 12.1 編集可能な項目
- **テキスト本文のみ:** 誤字脱字修正や内容の明確化を目的とする
- **編集不可:** visibility、media_ids（これらの変更は再投稿として扱う）

### 12.2 編集履歴
- **編集フラグ:** dropsテーブルに`is_edited (BOOLEAN DEFAULT FALSE)`を追加
- **編集日時:** `updated_at`で追跡（初回作成時は`created_at`と同一）
- **履歴保存:** v1では実装しない（将来的に別テーブルで管理を検討）

### 12.3 編集制限
- **時間制限:** 作成後5分間のみ編集可能（設定可能）
- **回数制限:** v1では無制限（将来的に検討）

### 12.4 ActivityPub連携
- `drop_updated`イベント発行時、avion-activitypubが`Update`アクティビティを生成
- 完全なオブジェクトを含む（ActivityPub仕様に準拠）

## 17. スケジュール投稿実行の詳細設計

### 13.1 実行メカニズム

#### 実装方式の選択肢
1. **Kubernetes CronJob（推奨）**
   - 1分ごとにJobを起動
   - 環境変数で実行間隔を調整可能
   - Kubernetesネイティブな監視・ログ収集
   - 自動リトライとフェイルオーバー

2. **専用ワーカープロセス**
   - 常駐プロセスとして動作
   - より細かい実行間隔の制御が可能
   - 追加のプロセス管理が必要

### 13.2 実行フロー

```go
// infrastructure/job/scheduled_drop_publisher.go
type ScheduledDropPublisher struct {
    scheduledDropRepo repository.ScheduledDropRepository
    dropRepo         repository.DropRepository
    eventPublisher   event.EventPublisher
    logger          *slog.Logger
}

func (p *ScheduledDropPublisher) Execute(ctx context.Context) error {
    // 1. 公開時刻に達したスケジュール投稿を取得
    now := time.Now()
    dueDrops, err := p.scheduledDropRepo.FindDueDrops(ctx, now)
    if err != nil {
        return fmt.Errorf("find due drops: %w", err)
    }
    
    // 2. 各投稿を並行処理
    var wg sync.WaitGroup
    semaphore := make(chan struct{}, 10) // 同時実行数制限
    
    for _, scheduledDrop := range dueDrops {
        wg.Add(1)
        semaphore <- struct{}{}
        
        go func(sd *domain.ScheduledDrop) {
            defer wg.Done()
            defer func() { <-semaphore }()
            
            if err := p.publishDrop(ctx, sd); err != nil {
                p.logger.Error("failed to publish scheduled drop",
                    slog.String("scheduled_drop_id", sd.ID.String()),
                    slog.Error(err),
                )
            }
        }(scheduledDrop)
    }
    
    wg.Wait()
    return nil
}
```

### 13.3 エラーハンドリングとリトライ

```go
func (p *ScheduledDropPublisher) publishDrop(ctx context.Context, sd *domain.ScheduledDrop) error {
    // トランザクション内で実行
    return p.db.Transaction(func(tx *gorm.DB) error {
        // 1. Drop Aggregateを作成
        drop, err := sd.ToDropAggregate()
        if err != nil {
            return p.handlePublishError(ctx, sd, err)
        }
        
        // 2. Dropを永続化
        if err := p.dropRepo.Create(ctx, drop); err != nil {
            return p.handlePublishError(ctx, sd, err)
        }
        
        // 3. ScheduledDropのステータスを更新
        sd.MarkAsPublished(drop.ID)
        if err := p.scheduledDropRepo.Update(ctx, sd); err != nil {
            return fmt.Errorf("update scheduled drop: %w", err)
        }
        
        // 4. イベントを発行
        if err := p.eventPublisher.Publish(ctx, &event.DropCreated{
            DropID: drop.ID,
            UserID: drop.UserID,
            // ... その他のフィールド
        }); err != nil {
            return fmt.Errorf("publish event: %w", err)
        }
        
        if err := p.eventPublisher.Publish(ctx, &event.ScheduledDropPublished{
            ScheduledDropID: sd.ID,
            DropID:         drop.ID,
            PublishedAt:    time.Now(),
        }); err != nil {
            return fmt.Errorf("publish scheduled drop event: %w", err)
        }
        
        return nil
    })
}

func (p *ScheduledDropPublisher) handlePublishError(ctx context.Context, sd *domain.ScheduledDrop, err error) error {
    sd.IncrementRetryCount()
    sd.SetLastError(err.Error())
    
    // リトライ上限チェック
    if sd.RetryCount >= 3 {
        sd.MarkAsFailed()
        // 失敗通知イベントを発行
        p.eventPublisher.Publish(ctx, &event.ScheduledDropFailed{
            ScheduledDropID: sd.ID,
            UserID:         sd.UserID,
            Error:          err.Error(),
        })
    }
    
    return p.scheduledDropRepo.Update(ctx, sd)
}
```

### 13.4 パフォーマンス最適化

1. **バッチ処理**
   - 複数のスケジュール投稿を一度に取得（最大100件）
   - 並行処理による高速化

2. **インデックス最適化**
   - `(scheduled_at, status)` の複合インデックス
   - 実行対象の高速検索

3. **実行時間窓**
   - ±1分の実行時間窓を設定
   - 実行タイミングの柔軟性

### 13.5 監視項目

- **メトリクス**
  - スケジュール投稿の実行成功/失敗数
  - 実行遅延時間（scheduled_at vs actual_published_at）
  - リトライ回数
  - 実行時間

- **アラート**
  - 実行失敗率が閾値を超過
  - 実行遅延が5分を超過
  - リトライ上限到達

### 13.6 将来の拡張性

1. **繰り返し投稿**
   - cron式による繰り返しスケジュール
   - 定期投稿テンプレート

2. **タイムゾーン対応**
   - ユーザーのローカルタイムゾーンでの設定
   - サマータイム自動調整

3. **優先度制御**
   - VIPユーザーの優先実行
   - 負荷に応じた実行調整

## 18. Concerns / Open Questions (懸念事項・相談したいこと)

- **技術的負債リスク:**
    - **物理削除の非可逆性:** 物理削除はシンプルだが、誤削除時の復旧や将来的な「ゴミ箱」機能などの要求変更に対応できない。これは設計上のトレードオフ。
    - **イベントペイロード:** `drop_created` で全データを含めるのは、データサイズが大きい場合にネットワーク帯域や受信側サービスの負荷になる可能性がある。必要な情報のみに絞るか検討が必要。
    - ~~**リアクション集計パフォーマンス:**~~ **解決済:** reaction_summariesテーブルと永続的Redisキャッシュにより、数万リアクションでもO(1)で取得可能。ホットDropは優先的にメモリに保持。
    - **キャッシュ整合性:** イベント駆動更新と永続的キャッシュにより、整合性が大幅に改善。トランザクション内でDBとキュー更新を実施。
    - ~~**データモデル:**~~ **解決済:** reaction_summariesテーブルの導入により、集計クエリのパフォーマンス問題を解決。非正規化によるトレードオフを受け入れる。
- 引用/リポストのデータモデルを将来的にどう統合するか。
- カスタム絵文字を将来的にどう扱うか。`emoji_code` の設計。
- ~~**ActivityPub連携での絵文字リアクション:**~~ **解決済:** 対向先別の実装を採用。Misskey系には`_misskey_reaction`、Pleroma系には`EmojiReact`、Avionには独自の`_avion_reaction`フィールドを使用。
- リアクションキャッシュTTLの適切な値。
- Drop編集時のリアクションの扱い（維持するか、リセットするか）。
- Avion独自の`reaction_group`フィールドの活用方法（positive/negative/neutralなどの感情分類）。
- **スケジュール投稿実行の具体的な実装方法**（Kubernetes CronJob vs 専用ワーカー）の最終決定。
- **スケジュール投稿の最大保持期間**（公開後の履歴をどの程度保持するか）。
- **タイムゾーン対応**の実装時期（v1では全てUTCで統一、v2でユーザータイムゾーン対応）。
- **スケジュール投稿実行失敗時の通知方法**（avion-notificationとの連携仕様）。

## 19. Service-Specific Test Strategy (avion-drop固有テスト戦略)

### 15.1. テスト方針

avion-dropサービスは投稿システムの中核であり、高い信頼性とパフォーマンスが要求される。特に以下の領域において徹底的なテスト戦略を実装する：

- **Drop Aggregate不変条件の検証**
- **リアクション冪等性の保証**
- **投票ロジックの正確性**
- **スケジュール投稿の実行精度**
- **メディア添付制限の適切な処理**

### 15.2. Drop作成の包括的テスト

#### 15.2.1. 可視性設定テスト

```go
func TestDropAggregate_CreateDrop_VisibilitySettings(t *testing.T) {
    tests := []struct {
        name       string
        visibility domain.Visibility
        userID     domain.UserID
        wantErr    bool
        errType    error
    }{
        {
            name:       "公開投稿_正常系",
            visibility: domain.VisibilityPublic,
            userID:     domain.NewUserID("user123"),
            wantErr:    false,
        },
        {
            name:       "フォロワー限定投稿_正常系",
            visibility: domain.VisibilityFollowersOnly,
            userID:     domain.NewUserID("user123"),
            wantErr:    false,
        },
        {
            name:       "DM投稿_正常系",
            visibility: domain.VisibilityDirect,
            userID:     domain.NewUserID("user123"),
            wantErr:    false,
        },
        {
            name:       "不正な可視性設定",
            visibility: domain.Visibility("invalid"),
            userID:     domain.NewUserID("user123"),
            wantErr:    true,
            errType:    domain.ErrInvalidVisibility,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Given
            dropText := domain.NewDropText("テスト投稿")
            createdAt := ctxtime.Now()

            // When
            drop, err := domain.NewDrop(
                domain.GenerateDropID(),
                tt.userID,
                dropText,
                tt.visibility,
                createdAt,
            )

            // Then
            if tt.wantErr {
                assert.Error(t, err)
                assert.ErrorIs(t, err, tt.errType)
                assert.Nil(t, drop)
            } else {
                assert.NoError(t, err)
                assert.NotNil(t, drop)
                assert.Equal(t, tt.visibility, drop.Visibility())
                assert.Equal(t, tt.userID, drop.UserID())
            }
        })
    }
}
```

#### 15.2.2. Drop不変条件テスト

```go
func TestDropAggregate_Invariants(t *testing.T) {
    t.Run("メディア添付数制限", func(t *testing.T) {
        // Given
        dropID := domain.GenerateDropID()
        userID := domain.NewUserID("user123")
        dropText := domain.NewDropText("メディア投稿テスト")
        drop, _ := domain.NewDrop(dropID, userID, dropText, domain.VisibilityPublic, ctxtime.Now())

        // 許可される最大数のメディアを追加
        for i := 0; i < domain.MaxMediaAttachments; i++ {
            mediaID := domain.NewMediaID(fmt.Sprintf("media%d", i))
            mediaType := domain.MediaTypeImage
            altText := domain.NewAltText(fmt.Sprintf("画像%d", i))
            order := domain.NewMediaOrder(i)
            
            attachment := domain.NewMediaAttachment(mediaID, mediaType, altText, order)
            err := drop.AddMediaAttachment(attachment)
            assert.NoError(t, err)
        }

        // When: 制限を超えるメディアを追加
        extraMediaID := domain.NewMediaID("extra_media")
        extraAttachment := domain.NewMediaAttachment(
            extraMediaID, 
            domain.MediaTypeImage, 
            domain.NewAltText("余分な画像"), 
            domain.NewMediaOrder(domain.MaxMediaAttachments),
        )
        err := drop.AddMediaAttachment(extraAttachment)

        // Then
        assert.Error(t, err)
        assert.ErrorIs(t, err, domain.ErrTooManyMediaAttachments)
        assert.Len(t, drop.MediaAttachments(), domain.MaxMediaAttachments)
    })

    t.Run("テキストと投票の同時制限", func(t *testing.T) {
        // Given
        dropID := domain.GenerateDropID()
        userID := domain.NewUserID("user123")
        emptyText := domain.NewDropText("")
        drop, _ := domain.NewDrop(dropID, userID, emptyText, domain.VisibilityPublic, ctxtime.Now())

        // When: テキストなしで投票も設定されていない場合
        err := drop.Validate()

        // Then
        assert.Error(t, err)
        assert.ErrorIs(t, err, domain.ErrDropContentRequired)
    })
}
```

### 15.3. リアクション管理と冪等性テスト

#### 15.3.1. リアクション冪等性テスト

```go
func TestReactionAggregate_Idempotency(t *testing.T) {
    tests := []struct {
        name      string
        setup     func() (*domain.Reaction, domain.UserID, domain.EmojiCode)
        operation string
        wantErr   bool
    }{
        {
            name: "同一ユーザーが同じ絵文字で複数回リアクション",
            setup: func() (*domain.Reaction, domain.UserID, domain.EmojiCode) {
                dropID := domain.GenerateDropID()
                userID := domain.NewUserID("user123")
                emojiCode := domain.NewEmojiCode("👍")
                reaction, _ := domain.NewReaction(
                    domain.GenerateReactionID(),
                    dropID,
                    userID,
                    emojiCode,
                    ctxtime.Now(),
                )
                return reaction, userID, emojiCode
            },
            operation: "duplicate_add",
            wantErr:   true,
        },
        {
            name: "存在しないリアクションを削除",
            setup: func() (*domain.Reaction, domain.UserID, domain.EmojiCode) {
                dropID := domain.GenerateDropID()
                userID := domain.NewUserID("user123")
                emojiCode := domain.NewEmojiCode("👍")
                reaction, _ := domain.NewReaction(
                    domain.GenerateReactionID(),
                    dropID,
                    userID,
                    emojiCode,
                    ctxtime.Now(),
                )
                return reaction, domain.NewUserID("other_user"), emojiCode
            },
            operation: "remove_nonexistent",
            wantErr:   true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Given
            reaction, userID, emojiCode := tt.setup()

            // When & Then
            switch tt.operation {
            case "duplicate_add":
                // 既存のリアクションに対して同じユーザーが同じ絵文字でリアクション
                err := reaction.ValidateUserReaction(userID, emojiCode)
                if tt.wantErr {
                    assert.Error(t, err)
                    assert.ErrorIs(t, err, domain.ErrDuplicateReaction)
                } else {
                    assert.NoError(t, err)
                }
            case "remove_nonexistent":
                // 存在しないリアクションの削除
                err := reaction.ValidateRemoval(userID, emojiCode)
                if tt.wantErr {
                    assert.Error(t, err)
                    assert.ErrorIs(t, err, domain.ErrReactionNotFound)
                } else {
                    assert.NoError(t, err)
                }
            }
        })
    }
}

func TestReactionSummary_ConcurrentUpdates(t *testing.T) {
    t.Run("並行リアクション処理", func(t *testing.T) {
        // Given
        dropID := domain.GenerateDropID()
        summary := domain.NewReactionSummary(dropID)
        emojiCode := domain.NewEmojiCode("👍")

        // When: 複数ゴルーチンで同時にリアクション追加
        const numGoroutines = 100
        var wg sync.WaitGroup
        wg.Add(numGoroutines)

        for i := 0; i < numGoroutines; i++ {
            go func(index int) {
                defer wg.Done()
                userID := domain.NewUserID(fmt.Sprintf("user%d", index))
                summary.AddReaction(emojiCode, userID)
            }(i)
        }

        wg.Wait()

        // Then
        count := summary.GetReactionCount(emojiCode)
        assert.Equal(t, domain.NewReactionCount(numGoroutines), count)
    })
}
```

### 15.4. 投票機能の包括的テスト

#### 15.4.1. 投票ロジックと期限管理

```go
func TestPollAggregate_VotingLogic(t *testing.T) {
    t.Run("投票期限チェック", func(t *testing.T) {
        tests := []struct {
            name       string
            expiresAt  time.Time
            voteTime   time.Time
            wantErr    bool
        }{
            {
                name:      "期限内投票_正常系",
                expiresAt: ctxtime.Now().Add(1 * time.Hour),
                voteTime:  ctxtime.Now(),
                wantErr:   false,
            },
            {
                name:      "期限切れ投票_エラー",
                expiresAt: ctxtime.Now().Add(-1 * time.Hour),
                voteTime:  ctxtime.Now(),
                wantErr:   true,
            },
        }

        for _, tt := range tests {
            t.Run(tt.name, func(t *testing.T) {
                // Given
                pollID := domain.GeneratePollID()
                dropID := domain.GenerateDropID()
                expiry := domain.NewPollExpiry(tt.expiresAt)
                
                options := []domain.PollOption{
                    *domain.NewPollOption(domain.NewOptionText("選択肢1"), domain.NewDisplayOrder(0)),
                    *domain.NewPollOption(domain.NewOptionText("選択肢2"), domain.NewDisplayOrder(1)),
                }
                
                poll, _ := domain.NewPoll(pollID, dropID, options, expiry, false, ctxtime.Now())

                // When
                userID := domain.NewUserID("voter123")
                optionIndex := 0
                
                ctxtime.SetTime(tt.voteTime)
                defer ctxtime.Reset()
                
                err := poll.Vote(userID, optionIndex)

                // Then
                if tt.wantErr {
                    assert.Error(t, err)
                    assert.ErrorIs(t, err, domain.ErrPollExpired)
                } else {
                    assert.NoError(t, err)
                    votes := poll.GetVotesForOption(optionIndex)
                    assert.Contains(t, votes, userID)
                }
            })
        }
    })

    t.Run("複数選択投票の制約", func(t *testing.T) {
        // Given
        pollID := domain.GeneratePollID()
        dropID := domain.GenerateDropID()
        expiry := domain.NewPollExpiry(ctxtime.Now().Add(24 * time.Hour))
        
        options := []domain.PollOption{
            *domain.NewPollOption(domain.NewOptionText("選択肢1"), domain.NewDisplayOrder(0)),
            *domain.NewPollOption(domain.NewOptionText("選択肢2"), domain.NewDisplayOrder(1)),
            *domain.NewPollOption(domain.NewOptionText("選択肢3"), domain.NewDisplayOrder(2)),
        }
        
        // 単一選択投票
        singleChoicePoll, _ := domain.NewPoll(pollID, dropID, options, expiry, false, ctxtime.Now())
        // 複数選択投票
        multipleChoicePoll, _ := domain.NewPoll(pollID, dropID, options, expiry, true, ctxtime.Now())

        userID := domain.NewUserID("voter123")

        // When & Then: 単一選択投票で複数投票を試行
        err1 := singleChoicePoll.Vote(userID, 0)
        assert.NoError(t, err1)
        
        err2 := singleChoicePoll.Vote(userID, 1)
        assert.Error(t, err2)
        assert.ErrorIs(t, err2, domain.ErrAlreadyVoted)

        // When & Then: 複数選択投票で複数投票
        err3 := multipleChoicePoll.Vote(userID, 0)
        assert.NoError(t, err3)
        
        err4 := multipleChoicePoll.Vote(userID, 1)
        assert.NoError(t, err4)
        
        // 同じ選択肢への重複投票はエラー
        err5 := multipleChoicePoll.Vote(userID, 0)
        assert.Error(t, err5)
        assert.ErrorIs(t, err5, domain.ErrDuplicateVote)
    })
}

func TestPoll_ResultCalculation(t *testing.T) {
    t.Run("投票結果の正確な集計", func(t *testing.T) {
        // Given
        pollID := domain.GeneratePollID()
        dropID := domain.GenerateDropID()
        expiry := domain.NewPollExpiry(ctxtime.Now().Add(24 * time.Hour))
        
        options := []domain.PollOption{
            *domain.NewPollOption(domain.NewOptionText("選択肢A"), domain.NewDisplayOrder(0)),
            *domain.NewPollOption(domain.NewOptionText("選択肢B"), domain.NewDisplayOrder(1)),
        }
        
        poll, _ := domain.NewPoll(pollID, dropID, options, expiry, false, ctxtime.Now())

        // When: 複数ユーザーが投票
        voters := []string{"user1", "user2", "user3", "user4", "user5"}
        votes := []int{0, 0, 1, 0, 1} // A:3票, B:2票

        for i, voterID := range voters {
            userID := domain.NewUserID(voterID)
            err := poll.Vote(userID, votes[i])
            assert.NoError(t, err)
        }

        // Then
        results := poll.CalculateResults()
        assert.Equal(t, 3, results[0].VoteCount) // 選択肢A
        assert.Equal(t, 2, results[1].VoteCount) // 選択肢B
        assert.Equal(t, 5, poll.TotalVotes())
    })
}
```

### 15.5. スケジュール投稿テスト

#### 15.5.1. 予約投稿実行テスト

```go
func TestScheduledDrop_Publishing(t *testing.T) {
    t.Run("予定時刻での自動投稿", func(t *testing.T) {
        // Given
        scheduledID := domain.GenerateScheduledDropID()
        userID := domain.NewUserID("user123")
        content := domain.NewDropText("予約投稿テスト")
        scheduledAt := domain.NewScheduledAt(ctxtime.Now().Add(1 * time.Hour))
        
        scheduledDrop, _ := domain.NewScheduledDrop(
            scheduledID,
            userID,
            content,
            domain.VisibilityPublic,
            scheduledAt,
            ctxtime.Now(),
        )

        // When: 予定時刻に達した状態をシミュレート
        publishTime := scheduledAt.Value()
        ctxtime.SetTime(publishTime)
        defer ctxtime.Reset()

        canPublish := scheduledDrop.CanPublish(ctxtime.Now())
        assert.True(t, canPublish)

        // Then: 投稿実行
        drop, err := scheduledDrop.Publish(domain.GenerateDropID(), ctxtime.Now())
        assert.NoError(t, err)
        assert.NotNil(t, drop)
        assert.Equal(t, content, drop.Text())
        assert.Equal(t, userID, drop.UserID())
    })

    t.Run("実行失敗時のリトライ制御", func(t *testing.T) {
        // Given
        scheduledID := domain.GenerateScheduledDropID()
        userID := domain.NewUserID("user123")
        content := domain.NewDropText("リトライテスト")
        scheduledAt := domain.NewScheduledAt(ctxtime.Now().Add(-1 * time.Hour))
        
        scheduledDrop, _ := domain.NewScheduledDrop(
            scheduledID,
            userID,
            content,
            domain.VisibilityPublic,
            scheduledAt,
            ctxtime.Now(),
        )

        // When: 最大リトライ回数に達するまで失敗を記録
        maxRetries := domain.MaxScheduledDropRetries
        for i := 0; i < maxRetries; i++ {
            scheduledDrop.RecordFailure("テスト失敗")
        }

        // Then: これ以上リトライしない
        canRetry := scheduledDrop.CanRetry()
        assert.False(t, canRetry)
        assert.Equal(t, maxRetries, scheduledDrop.RetryCount().Value())
    })
}
```

### 15.6. ブックマーク操作テスト

```go
func TestBookmarkAggregate_Operations(t *testing.T) {
    t.Run("ブックマーク追加と削除", func(t *testing.T) {
        tests := []struct {
            name      string
            operation string
            setup     func() (*domain.Bookmark, domain.UserID, domain.DropID)
            wantErr   bool
            errType   error
        }{
            {
                name:      "新規ブックマーク追加_正常系",
                operation: "add",
                setup: func() (*domain.Bookmark, domain.UserID, domain.DropID) {
                    userID := domain.NewUserID("user123")
                    dropID := domain.GenerateDropID()
                    return nil, userID, dropID
                },
                wantErr: false,
            },
            {
                name:      "重複ブックマーク追加_エラー",
                operation: "add_duplicate",
                setup: func() (*domain.Bookmark, domain.UserID, domain.DropID) {
                    userID := domain.NewUserID("user123")
                    dropID := domain.GenerateDropID()
                    bookmark, _ := domain.NewBookmark(
                        domain.GenerateBookmarkID(),
                        userID,
                        dropID,
                        ctxtime.Now(),
                    )
                    return bookmark, userID, dropID
                },
                wantErr: true,
                errType: domain.ErrBookmarkAlreadyExists,
            },
        }

        for _, tt := range tests {
            t.Run(tt.name, func(t *testing.T) {
                // Given
                existingBookmark, userID, dropID := tt.setup()

                // When
                var err error
                switch tt.operation {
                case "add":
                    _, err = domain.NewBookmark(
                        domain.GenerateBookmarkID(),
                        userID,
                        dropID,
                        ctxtime.Now(),
                    )
                case "add_duplicate":
                    // 既存のブックマークがある場合の重複チェック
                    if existingBookmark != nil {
                        err = domain.ErrBookmarkAlreadyExists
                    }
                }

                // Then
                if tt.wantErr {
                    assert.Error(t, err)
                    if tt.errType != nil {
                        assert.ErrorIs(t, err, tt.errType)
                    }
                } else {
                    assert.NoError(t, err)
                }
            })
        }
    })
}
```

### 15.7. 下書きと内容抽出テスト

```go
func TestDraftAggregate_ContentExtraction(t *testing.T) {
    t.Run("メンションとハッシュタグの抽出", func(t *testing.T) {
        tests := []struct {
            name            string
            content         string
            expectedMentions []string
            expectedHashtags []string
        }{
            {
                name:            "メンションとハッシュタグを含むテキスト",
                content:         "@alice こんにちは！ #テスト #avion で投稿します @bob",
                expectedMentions: []string{"alice", "bob"},
                expectedHashtags: []string{"テスト", "avion"},
            },
            {
                name:            "メンションのみ",
                content:         "@user1 @user2 メンションテスト",
                expectedMentions: []string{"user1", "user2"},
                expectedHashtags: []string{},
            },
            {
                name:            "ハッシュタグのみ",
                content:         "ハッシュタグテスト #技術 #開発",
                expectedMentions: []string{},
                expectedHashtags: []string{"技術", "開発"},
            },
            {
                name:            "何も含まない",
                content:         "普通のテキストです",
                expectedMentions: []string{},
                expectedHashtags: []string{},
            },
        }

        for _, tt := range tests {
            t.Run(tt.name, func(t *testing.T) {
                // Given
                draftID := domain.GenerateDraftID()
                userID := domain.NewUserID("author123")
                content := domain.NewDropText(tt.content)
                
                draft, _ := domain.NewDraft(
                    draftID,
                    userID,
                    content,
                    domain.VisibilityPublic,
                    ctxtime.Now(),
                )

                // When
                mentions := draft.ExtractMentions()
                hashtags := draft.ExtractHashtags()

                // Then
                assert.ElementsMatch(t, tt.expectedMentions, mentions)
                assert.ElementsMatch(t, tt.expectedHashtags, hashtags)
            })
        }
    })

    t.Run("下書きから投稿への変換", func(t *testing.T) {
        // Given
        draftID := domain.GenerateDraftID()
        userID := domain.NewUserID("author123")
        content := domain.NewDropText("下書きから投稿への変換テスト")
        
        draft, _ := domain.NewDraft(
            draftID,
            userID,
            content,
            domain.VisibilityPublic,
            ctxtime.Now(),
        )

        // When
        drop, err := draft.ConvertToDrop(domain.GenerateDropID(), ctxtime.Now())

        // Then
        assert.NoError(t, err)
        assert.NotNil(t, drop)
        assert.Equal(t, content, drop.Text())
        assert.Equal(t, userID, drop.UserID())
        assert.Equal(t, domain.VisibilityPublic, drop.Visibility())
    })
}
```

### 15.8. パフォーマンステスト

```go
func TestPerformance_ReactionAggregation(t *testing.T) {
    t.Run("大量リアクションの集計性能", func(t *testing.T) {
        // Given
        dropID := domain.GenerateDropID()
        summary := domain.NewReactionSummary(dropID)
        emojiCodes := []domain.EmojiCode{
            domain.NewEmojiCode("👍"),
            domain.NewEmojiCode("❤️"),
            domain.NewEmojiCode("😂"),
            domain.NewEmojiCode("😮"),
            domain.NewEmojiCode("😢"),
        }

        // When: 10,000件のリアクション追加
        const numReactions = 10000
        start := time.Now()
        
        for i := 0; i < numReactions; i++ {
            userID := domain.NewUserID(fmt.Sprintf("user%d", i))
            emojiCode := emojiCodes[i%len(emojiCodes)]
            summary.AddReaction(emojiCode, userID)
        }
        
        elapsed := time.Since(start)

        // Then: 性能要件の確認
        assert.Less(t, elapsed, 1*time.Second, "10,000件のリアクション追加は1秒以内で完了すべき")
        
        // 集計結果の確認
        totalCount := 0
        for _, emojiCode := range emojiCodes {
            count := summary.GetReactionCount(emojiCode)
            totalCount += count.Value()
        }
        assert.Equal(t, numReactions, totalCount)
    })
}
```

### 15.9. 統合テスト戦略

#### 15.9.1. E2Eシナリオテスト

```go
func TestE2E_DropLifecycle(t *testing.T) {
    t.Run("投稿のライフサイクル全体", func(t *testing.T) {
        // Given: テストデータベースとRedisの準備
        db := setupTestDB(t)
        redis := setupTestRedis(t)
        
        dropRepo := persistence.NewDropRepository(db, redis)
        reactionRepo := persistence.NewReactionRepository(db, redis)
        
        dropUseCase := usecase.NewDropUseCase(dropRepo, reactionRepo)

        // When: 1. 投稿作成
        createCmd := command.CreateDropCommand{
            UserID:     "user123",
            Text:       "E2Eテスト投稿",
            Visibility: "public",
        }
        
        dropID, err := dropUseCase.CreateDrop(context.Background(), createCmd)
        assert.NoError(t, err)
        assert.NotEmpty(t, dropID)

        // When: 2. リアクション追加
        reactionCmd := command.AddReactionCommand{
            DropID:    dropID,
            UserID:    "reactor123",
            EmojiCode: "👍",
        }
        
        err = dropUseCase.AddReaction(context.Background(), reactionCmd)
        assert.NoError(t, err)

        // When: 3. 投稿取得とリアクション確認
        query := query.GetDropQuery{DropID: dropID}
        drop, err := dropUseCase.GetDrop(context.Background(), query)
        assert.NoError(t, err)
        assert.NotNil(t, drop)
        assert.Equal(t, "E2Eテスト投稿", drop.Text)
        assert.Contains(t, drop.ReactionSummary, "👍")

        // When: 4. 投稿削除
        deleteCmd := command.DeleteDropCommand{
            DropID: dropID,
            UserID: "user123",
        }
        
        err = dropUseCase.DeleteDrop(context.Background(), deleteCmd)
        assert.NoError(t, err)

        // Then: 5. 削除確認
        _, err = dropUseCase.GetDrop(context.Background(), query)
        assert.Error(t, err)
        assert.ErrorIs(t, err, domain.ErrDropNotFound)
    })
}
```

### 15.10. テストカバレッジ目標

- **Domain Layer**: 95%以上（ビジネスロジックの完全カバレッジ）
- **UseCase Layer**: 90%以上（エラーケースを含む包括的テスト）
- **Infrastructure Layer**: 85%以上（外部依存を含む統合テスト）
- **Handler Layer**: 90%以上（APIエンドポイントの全パターン）

### 15.11. テスト実行戦略

```bash
# 単体テスト実行
go test ./domain/... -v -race -count=1

# 統合テスト実行（Dockerコンテナ必要）
go test ./infrastructure/... -v -tags=integration

# カバレッジレポート生成
go test ./... -coverprofile=coverage.out
go tool cover -html=coverage.out -o coverage.html

# パフォーマンステスト
go test ./... -bench=. -benchmem
```

---
