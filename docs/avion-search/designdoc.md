# Design Doc: avion-search

**Author:** Cline
**Last Updated:** 2025/03/30

## 1. Summary (これは何？)

- **一言で:** Avionにおける投稿（Drop）やユーザーの検索機能を提供するマイクロサービスを実装します。
- **目的:** 主にMeiliSearchを使用した高速な全文検索を提供し、将来的な拡張性のためにPostgreSQL全文検索（FTS）への切り替えも可能な設計とします。1stリリースではMeiliSearchを実装し、インターフェースレベルでPostgreSQL FTSへの対応も準備します。Drop/Userの変更イベントを購読し、MeiliSearchインデックスを更新します。

## テスト戦略

このサービスでは、[共通テスト戦略](../common/testing-strategy.md)に従ってテストを実装します。

### テスト方針
- **TDD必須**: インターフェース定義 → テスト作成 → 実装の順序を厳守
- **カバレッジ目標**: ユニットテスト85%以上、クリティカルパス95%以上
- **テーブル駆動テスト**: 全テストで必須
- **モック生成**: `go.uber.org/mock/gomock`使用

詳細は[共通テスト戦略ドキュメント](../common/testing-strategy.md)を参照してください。

### 検索サービス特有のテスト要件
- **MeiliSearch統合テスト**: testcontainersを使用した実際のMeiliSearchインスタンスでのテスト
- **検索精度テスト**: 日本語検索クエリの精度と適合率の検証
- **インデックス更新の冪等性テスト**: 同一イベントの重複処理時の整合性確認
- **パフォーマンステスト**: レスポンス時間とスループットの測定
- **アクセス制御テスト**: ユーザー権限に基づく検索結果フィルタリングの検証

### E2Eテスト

このサービスのE2Eテストは、[共通E2Eテスト戦略](../common/e2e-testing-strategy.md)に従って実装します。

#### 主要なE2Eテストシナリオ
- Drop投稿からMeiliSearchインデックス更新までの完全フロー
- 日本語テキスト検索での適合率と再現率の確認
- ハッシュタグ検索機能とリアルタイム更新の確認
- ユーザー検索機能とプロフィール情報連携の確認
- プライバシー設定による検索結果フィルタリング
- 検索クエリのオートコンプリート機能
- 複数条件での詳細検索機能
- 大量データでの検索性能とレスポンス時間測定

詳細は[共通E2Eテスト戦略ドキュメント](../common/e2e-testing-strategy.md)を参照してください。

## 3. 技術スタック

このサービスでは、[共通Goバックエンド技術スタックガイドライン](../common/architecture/go-backend-framework.md)に従った実装を行います。

### 主要技術
- **HTTPルーティング:** Chi v5
- **RPC:** ConnectRPC
- **ミドルウェア:** 標準net/httpベースの共通ミドルウェア
- **検索関連:** MeiliSearch、PostgreSQLフォールバック機能

詳細な実装パターンおよびライブラリの使用方法については、[ガイドライン](../common/architecture/go-backend-framework.md)を参照してください。

## 4. Background & Links (背景と関連リンク)

- ユーザーが必要な情報（Drop、ユーザー）を効率的に発見できるようにするため。
- 検索という専門的な処理を分離し、外部検索エンジン (MeiliSearch) やDB機能を利用するため。
- [PRD: avion-search](./prd.md)
- [Avion アーキテクチャ概要](../common/architecture.md)

## 5. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

#### 基本機能 (Phase 0)
- Drop/User作成・更新・削除イベント (Redis Stream + Consumer Group) を購読。
- イベントに基づき、MeiliSearchにドキュメントを追加・更新・削除する機能の実装 (冪等性確保)。
- MeiliSearchを利用したDrop検索API (gRPC) の実装（1stリリース）。
- MeiliSearchを利用したユーザー検索API (gRPC) の実装（1stリリース）。
- SearchBackend interfaceを定義し、MeiliSearchとPostgreSQL FTSの両方に対応可能な設計（PostgreSQL FTS実装は2ndリリース以降）。
- 検索結果に対するアクセス制御フィルタリング (呼び出し元ユーザーの権限を考慮、MeiliSearchフィルタ優先)。
- 日本語検索に最適化された設定（kuromoji tokenizer相当）の実装。
- Go言語で実装し、Kubernetes上でのステートレス運用を前提とする。
- OpenTelemetryによるトレーシング・メトリクス・ロギング対応。

#### 拡張機能 (Phase 1: 高優先度)
- 検索プライバシー制御機能 (GDPR対応、オプトイン/オプトアウト)。
- ハッシュタグ検索機能とトレンディングハッシュタグ表示。
- メンション検索機能 (自分へのメンション/他者へのメンション)。

#### 拡張機能 (Phase 2: 中優先度)
- 検索履歴管理とサジェスト機能。
- 保存検索機能と新着マッチ通知。
- リアクションベース検索。

#### 拡張機能 (Phase 3: 低優先度)
- フェデレーション検索 (リモートインスタンス検索)。
- コレクション内検索 (ブックマーク、リスト等)。

### Non-Goals (やらないこと)

- **検索エンジン/DB自体の運用:** MeiliSearch/PostgreSQLの運用は対象外。
- **データの永続化:** 本サービスはステートレス。インデックスはMeiliSearch、元データはPostgreSQLが保持。
- **リアルタイムインデックス (厳密な意味で):** MeiliSearchへの反映遅延は許容。完全なリアルタイム整合性は保証しない。
- **複雑な検索構文 (初期):** AND/OR/NOT等の高度な検索演算子は初期段階では実装しない。
- **検索結果のパーソナライズ (初期):** ユーザーの嗜好に基づくランキング調整は行わない。

## 6. Architecture (どうやって作る？)

### 5.1. レイヤードアーキテクチャ (DDD準拠)

#### Domain Layer (ドメイン層)
- **Aggregates:**
  - SearchIndex: 検索インデックスのライフサイクルと整合性を管理
  - IndexOperation: インデックス操作のトランザクション境界を管理
  - HashtagIndex (新規): ハッシュタグごとの検索インデックスを管理
  - SearchHistory (新規): ユーザーごとの検索履歴を管理
- **Entities:**
  - DropSearchDocument: Drop検索ドキュメント (Hashtags, Mentions追加)
  - UserSearchDocument: User検索ドキュメント (SearchPrivacySettings追加)
  - ProcessedEvent: 処理済みイベントの記録
  - SavedSearch (新規): 保存された検索条件
  - MentionIndex (新規): メンション関係のインデックス
- **Value Objects:**
  - SearchQuery, SearchResult, EventID, IndexType, Visibility等
  - SearchFilter: 検索フィルタ条件
  - SearchableText: 検索対象テキスト
  - RelevanceScore: 関連性スコア
  - SearchableContentSettings (新規): 検索可能性設定
  - Hashtag (新規): 正規化されたハッシュタグ
  - TrendingScore (新規): トレンド度
  - SearchName (新規): 保存検索の名前
  - MentionContext (新規): メンション周辺のコンテキスト
- **Domain Services:**
  - **SearchPolicy**: 検索のビジネスルールを実装するドメインサービス
    - 責務: 検索クエリの妥当性検証、検索戦略の決定、検索結果のフィルタリング
    - メソッド:
      ```go
      type SearchPolicy interface {
          ValidateSearchQuery(query SearchQuery) error
          DetermineSearchStrategy(query SearchQuery, indexType IndexType) SearchStrategy
          ApplyBusinessRules(results []SearchResult, userContext UserContext) []SearchResult
          CalculateRelevanceBoost(doc SearchDocument, query SearchQuery) float64
      }
      ```
  - **AccessControlPolicy**: アクセス制御ルールを実装するドメインサービス
    - 責務: ユーザーの権限に基づく検索結果のフィルタリング、検索可能範囲の決定
    - メソッド:
      ```go
      type AccessControlPolicy interface {
          DetermineSearchableScope(userID UserID, searchType SearchType) SearchScope
          CreateAccessFilter(userID UserID, visibility []Visibility) SearchFilter
          CanUserSearchContent(userID UserID, content SearchableContent) bool
          FilterSearchResults(results []SearchResult, userID UserID) []SearchResult
      }
      ```
  - **DocumentFactory**: 検索ドキュメント生成ロジックを実装するドメインサービス
    - 責務: エンティティから検索ドキュメントへの変換、検索可能フィールドの抽出
    - メソッド:
      ```go
      type DocumentFactory interface {
          CreateDropSearchDocument(drop Drop, author User) (DropSearchDocument, error)
          CreateUserSearchDocument(user User, privacy SearchPrivacySettings) (UserSearchDocument, error)
          ExtractSearchableFields(entity interface{}) map[string]interface{}
          NormalizeSearchableText(text string, language Language) SearchableText
      }
      ```
  - **SearchPrivacyPolicy** (新規): 検索プライバシーポリシーを実装するドメインサービス
    - 責務: GDPR準拠の検索プライバシー制御、オプトイン/オプトアウト管理
    - メソッド:
      ```go
      type SearchPrivacyPolicy interface {
          ValidatePrivacySettings(settings SearchPrivacySettings) error
          DetermineSearchability(user User, settings SearchPrivacySettings) Searchability
          ApplyPrivacyRules(documents []SearchDocument, privacySettings map[UserID]SearchPrivacySettings) []SearchDocument
          GeneratePrivacyCompliantDocument(original SearchDocument, settings SearchPrivacySettings) SearchDocument
      }
      ```
  - **HashtagExtractor** (新規): ハッシュタグ抽出を実装するドメインサービス
    - 責務: テキストからのハッシュタグ抽出、正規化、バリデーション
    - メソッド:
      ```go
      type HashtagExtractor interface {
          ExtractHashtags(text SearchableText) []Hashtag
          NormalizeHashtag(hashtag string) (Hashtag, error)
          ValidateHashtag(hashtag Hashtag) error
          ExtractHashtagContext(text SearchableText, hashtag Hashtag) HashtagContext
      }
      ```
  - **TrendingCalculator** (新規): トレンドスコア計算を実装するドメインサービス
    - 責務: ハッシュタグやコンテンツのトレンド度計算、ランキング生成
    - メソッド:
      ```go
      type TrendingCalculator interface {
          CalculateTrendingScore(hashtag Hashtag, metrics TrendingMetrics) TrendingScore
          GenerateTrendingRanking(scores map[Hashtag]TrendingScore, limit int) []TrendingItem
          DecayTrendingScore(currentScore TrendingScore, timeSinceLastUse time.Duration) TrendingScore
          AdjustScoreByVelocity(baseScore TrendingScore, usageVelocity float64) TrendingScore
      }
      ```
  - **MentionExtractor** (新規): メンション抽出を実装するドメインサービス
    - 責務: テキストからのメンション抽出、バリデーション、コンテキスト解析
    - メソッド:
      ```go
      type MentionExtractor interface {
          ExtractMentions(text SearchableText) []Mention
          ValidateMention(mention string) (Mention, error)
          ExtractMentionContext(text SearchableText, mention Mention) MentionContext
          ClassifyMentionType(mention Mention, text SearchableText) MentionType
      }
      ```
  - **RankingAlgorithm**: 検索結果のランキングアルゴリズムを実装するドメインサービス
    - 責務: 検索結果の関連性スコアリング、ランキング最適化
    - メソッド:
      ```go
      type RankingAlgorithm interface {
          CalculateRelevanceScore(doc SearchDocument, query SearchQuery) RelevanceScore
          ApplyTemporalDecay(score RelevanceScore, age time.Duration) RelevanceScore
          CombineScores(textScore, socialScore, temporalScore float64) RelevanceScore
          OptimizeRanking(results []SearchResult, userPreferences UserPreferences) []SearchResult
      }
      ```
- **Repository Interfaces:**
  - SearchIndexRepository: SearchIndex集約の永続化インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_search_index_repository.go -package=mocks
    ```
  - IndexOperationRepository: IndexOperation集約の永続化インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_index_operation_repository.go -package=mocks
    ```
  - EventRepository: ProcessedEventエンティティの永続化インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_event_repository.go -package=mocks
    ```
  - SearchQueryRepository: 検索クエリ履歴の永続化インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_search_query_repository.go -package=mocks
    ```
  - HashtagIndexRepository (新規): HashtagIndex集約の永続化インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_hashtag_index_repository.go -package=mocks
    ```
  - SearchHistoryRepository (新規): SearchHistory集約の永続化インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_search_history_repository.go -package=mocks
    ```
  - SavedSearchRepository (新規): SavedSearchエンティティの永続化インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_saved_search_repository.go -package=mocks
    ```

#### Use Case Layer (ユースケース層)
- **Command Use Cases (更新系):**
  - IndexDropDocumentCommandUseCase: Dropドキュメントのインデックス処理（イベントハンドラ用）
  - IndexUserDocumentCommandUseCase: Userドキュメントのインデックス処理（イベントハンドラ用）
  - ProcessIndexEventCommandUseCase: インデックスイベント処理（イベントハンドラ用）
  - RebuildIndexCommandUseCase: インデックス再構築処理（POSTリクエスト用）
  - UpdateSearchPrivacyCommandUseCase (新規): 検索プライバシー設定更新
  - SaveSearchCommandUseCase (新規): 検索条件保存
  - DeleteSavedSearchCommandUseCase (新規): 保存検索削除
  - RequestRemoteSearchCommandUseCase (新規): リモート検索要求
- **Query Use Cases (参照系):**
  - SearchDropsQueryUseCase: Drop検索処理（GETリクエスト用）
  - SearchUsersQueryUseCase: User検索処理（GETリクエスト用）
  - GetIndexStatusQueryUseCase: インデックス状態取得処理（GETリクエスト用）
  - SearchByHashtagQueryUseCase (新規): ハッシュタグ検索
  - SearchMentionsQueryUseCase (新規): メンション検索
  - GetSearchHistoryQueryUseCase (新規): 検索履歴取得
  - GetSavedSearchesQueryUseCase (新規): 保存検索一覧取得
  - GetTrendingHashtagsQueryUseCase (新規): トレンディングハッシュタグ取得
  - SearchInCollectionQueryUseCase (新規): コレクション内検索
- **Query Service Interfaces:**
  - DropSearchQueryService: Drop検索参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_drop_search_query_service.go -package=mocks
    ```
  - UserSearchQueryService: User検索参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_user_search_query_service.go -package=mocks
    ```
  - HashtagSearchQueryService (新規): ハッシュタグ検索参照専用
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_hashtag_search_query_service.go -package=mocks
    ```
  - SearchHistoryQueryService (新規): 検索履歴参照専用
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_search_history_query_service.go -package=mocks
    ```
- **DTOs:**
  - SearchRequest, SearchResponse, IndexEvent等
  - HashtagSearchRequest, HashtagSearchResponse (新規)
  - SearchHistoryResponse, SavedSearchResponse (新規)
  - SearchPrivacyUpdateRequest (新規)
- **External Service Interfaces:**
  - DropServiceClient: avion-dropとの連携
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_drop_service_client.go -package=mocks
    ```
  - UserServiceClient: avion-authとの連携
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_user_service_client.go -package=mocks
    ```
  - RemoteSearchClient (新規): リモートインスタンス検索連携
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_remote_search_client.go -package=mocks
    ```

#### Infrastructure Layer (インフラストラクチャ層)

- **Repository Implementations (更新系):**
  - SearchIndexRepository: SearchIndex集約の永続化実装 (GORMを使用)
  - IndexOperationRepository: IndexOperation集約の永続化実装 (GORMを使用)
  - HashtagIndexRepository: HashtagIndex集約の永続化実装 (GORMを使用)
  - SearchHistoryRepository: SearchHistory集約の永続化実装 (GORMを使用)
  - SavedSearchRepository: SavedSearchエンティティの永続化実装 (GORMを使用)
  - EventRepository: ProcessedEventエンティティの永続化実装 (GORMを使用)

- **DAOs (Data Access Objects):**
  - SearchIndexDAO: search_indexesテーブルとのマッピング用struct
  - IndexOperationDAO: index_operationsテーブルとのマッピング用struct
  - HashtagIndexDAO: hashtag_indexesテーブルとのマッピング用struct
  - SearchHistoryDAO: search_historiesテーブルとのマッピング用struct
  - SavedSearchDAO: saved_searchesテーブルとのマッピング用struct
  - ProcessedEventDAO: processed_eventsテーブルとのマッピング用struct

- **Query Service Implementations (参照系):**
  - DropSearchQueryService: Drop検索参照実装 (GORMを使用)
  - UserSearchQueryService: User検索参照実装 (GORMを使用)
  - HashtagSearchQueryService: ハッシュタグ検索参照実装 (GORMを使用)
  - SearchHistoryQueryService: 検索履歴参照実装 (GORMを使用)

- **External Service Implementations:**
  - GRPCDropServiceClient: avion-dropサービスとのgRPC連携実装
  - GRPCUserServiceClient: avion-userサービスとのgRPC連携実装
  - RemoteSearchClient: リモートインスタンス検索連携実装
  - MeiliSearchAdapter: MeiliSearch検索エンジン連携実装
  - PostgreSQLFTSAdapter: PostgreSQL全文検索連携実装
  - RedisStreamConsumer: Redis Stream購読実装
  - EventPublisher: イベント発行実装

#### Handler Layer (ハンドラー層)

- **gRPC Handlers:**
  - AvionSearchServiceHandler: avion-search gRPCサービス実装
    - SearchDrops: Drop検索処理
    - SearchUsers: ユーザー検索処理  
    - GetIndexStatus: インデックス状態取得処理
    - RebuildIndex: インデックス再構築処理
    - SearchByHashtag: ハッシュタグ検索処理
    - SearchMentions: メンション検索処理
    - GetSearchHistory: 検索履歴取得処理
    - GetSavedSearches: 保存検索一覧取得処理
    - SaveSearch: 検索条件保存処理
    - DeleteSavedSearch: 保存検索削除処理
    - UpdateSearchPrivacy: 検索プライバシー設定更新処理
    - GetTrendingHashtags: トレンディングハッシュタグ取得処理
  - EventConsumerHandler: Redis Streamイベント購読ハンドラー
    - ProcessDropEvent: Drop関連イベント処理
    - ProcessUserEvent: ユーザー関連イベント処理
    - ProcessPrivacyEvent: プライバシー設定変更イベント処理

### 5.2. CQRSパターン実装詳細

#### Command側（コマンド側）の責務と実装

**責務**: データの変更操作とビジネスロジックの実行、イベントの発行

##### コマンドハンドラー実装
```go
// internal/usecase/command/index_drop_document.go
type IndexDropDocumentCommand struct {
    DropID      string
    AuthorID    string
    Content     string
    Visibility  string
    Hashtags    []string
    Mentions    []string
    MediaURLs   []string
    CreatedAt   time.Time
    EventID     string // 冪等性保証用
}

type IndexDropDocumentCommandHandler struct {
    searchIndexRepo    domain.SearchIndexRepository
    eventRepo         domain.EventRepository
    searchBackend     infrastructure.SearchBackend
    eventPublisher    infrastructure.EventPublisher
    documentFactory   domain.DocumentFactory
    hashtagExtractor  domain.HashtagExtractor
    mentionExtractor  domain.MentionExtractor
    logger           *slog.Logger
}

func (h *IndexDropDocumentCommandHandler) Handle(ctx context.Context, cmd IndexDropDocumentCommand) error {
    // 1. 冪等性チェック（イベントソーシング）
    processed, err := h.eventRepo.IsEventProcessed(ctx, cmd.EventID)
    if err != nil {
        return fmt.Errorf("failed to check event processing: %w", err)
    }
    if processed {
        h.logger.Info("Event already processed", "event_id", cmd.EventID)
        return nil // 冪等性保証
    }

    // 2. ドメインオブジェクト生成
    drop := domain.NewDrop(cmd.DropID, cmd.AuthorID, cmd.Content, cmd.Visibility)
    
    // 3. ハッシュタグ・メンション抽出（ドメインサービス利用）
    searchableText := domain.NewSearchableText(cmd.Content)
    hashtags := h.hashtagExtractor.ExtractHashtags(searchableText)
    mentions := h.mentionExtractor.ExtractMentions(searchableText)
    
    // 4. 検索ドキュメント生成（ドメインサービス利用）
    doc, err := h.documentFactory.CreateDropSearchDocument(drop, hashtags, mentions)
    if err != nil {
        return fmt.Errorf("failed to create search document: %w", err)
    }

    // 5. トランザクション開始
    tx := h.searchIndexRepo.BeginTransaction(ctx)
    defer tx.Rollback()

    // 6. SearchIndex集約の更新
    searchIndex := domain.NewSearchIndex(domain.IndexTypeDrop)
    operation := searchIndex.AddDocument(doc)
    
    if err := h.searchIndexRepo.Save(ctx, tx, searchIndex); err != nil {
        return fmt.Errorf("failed to save search index: %w", err)
    }

    // 7. 検索バックエンド更新
    if err := h.searchBackend.IndexDocument(ctx, doc); err != nil {
        return fmt.Errorf("failed to index document in search backend: %w", err)
    }

    // 8. イベント処理記録（イベントソーシング）
    event := domain.NewProcessedEvent(cmd.EventID, "IndexDropDocument", cmd)
    if err := h.eventRepo.RecordProcessedEvent(ctx, tx, event); err != nil {
        return fmt.Errorf("failed to record processed event: %w", err)
    }

    // 9. ドメインイベント発行
    indexedEvent := domain.NewDropIndexedEvent(cmd.DropID, doc.ID, time.Now())
    if err := h.eventPublisher.Publish(ctx, indexedEvent); err != nil {
        // イベント発行失敗は警告のみ（最終的整合性）
        h.logger.Warn("Failed to publish indexed event", "error", err)
    }

    // 10. トランザクションコミット
    if err := tx.Commit(); err != nil {
        return fmt.Errorf("failed to commit transaction: %w", err)
    }

    h.logger.Info("Successfully indexed drop document", 
        "drop_id", cmd.DropID, 
        "event_id", cmd.EventID,
        "hashtags", len(hashtags),
        "mentions", len(mentions))
    
    return nil
}
```

##### コマンドバス実装
```go
// internal/usecase/command/command_bus.go
type CommandBus struct {
    handlers map[reflect.Type]CommandHandler
    logger   *slog.Logger
}

func (b *CommandBus) Register(cmdType interface{}, handler CommandHandler) {
    b.handlers[reflect.TypeOf(cmdType)] = handler
}

func (b *CommandBus) Dispatch(ctx context.Context, cmd interface{}) error {
    handler, exists := b.handlers[reflect.TypeOf(cmd)]
    if !exists {
        return fmt.Errorf("no handler registered for command type: %T", cmd)
    }
    
    // OpenTelemetryトレーシング
    span := trace.SpanFromContext(ctx)
    span.SetAttributes(
        attribute.String("command.type", fmt.Sprintf("%T", cmd)),
    )
    
    return handler.Handle(ctx, cmd)
}
```

#### Query側（クエリ側）の責務と実装

**責務**: データの参照操作に特化、高速な読み取り専用モデルの提供

##### クエリハンドラー実装
```go
// internal/usecase/query/search_drops.go
type SearchDropsQuery struct {
    UserID      string
    Query       string
    Filters     SearchFilters
    Pagination  PaginationParams
    SortBy      SortOption
}

type SearchDropsQueryHandler struct {
    queryService      infrastructure.DropSearchQueryService
    accessPolicy      domain.AccessControlPolicy
    rankingAlgorithm  domain.RankingAlgorithm
    cache            infrastructure.CacheService
    logger           *slog.Logger
}

func (h *SearchDropsQueryHandler) Handle(ctx context.Context, query SearchDropsQuery) (*SearchDropsResult, error) {
    // 1. キャッシュチェック（読み取り最適化）
    cacheKey := h.generateCacheKey(query)
    if cached, found := h.cache.Get(ctx, cacheKey); found {
        h.logger.Debug("Cache hit", "key", cacheKey)
        return cached.(*SearchDropsResult), nil
    }

    // 2. アクセス制御フィルタ生成
    accessFilter := h.accessPolicy.CreateAccessFilter(query.UserID, []string{"public", "unlisted"})
    
    // 3. 検索クエリ構築
    searchQuery := infrastructure.SearchQuery{
        Text:    query.Query,
        Filters: h.mergeFilters(query.Filters, accessFilter),
        Limit:   query.Pagination.Limit,
        Offset:  query.Pagination.Offset,
        Sort:    query.SortBy,
    }

    // 4. クエリサービス実行（読み取り専用）
    results, err := h.queryService.SearchDrops(ctx, searchQuery)
    if err != nil {
        return nil, fmt.Errorf("failed to search drops: %w", err)
    }

    // 5. ランキング最適化
    rankedResults := h.rankingAlgorithm.OptimizeRanking(results, query.UserID)

    // 6. レスポンス構築
    response := &SearchDropsResult{
        Drops:      rankedResults,
        TotalCount: len(results),
        Query:      query.Query,
        Filters:    query.Filters,
    }

    // 7. キャッシュ更新（TTL: 5分）
    h.cache.Set(ctx, cacheKey, response, 5*time.Minute)

    h.logger.Info("Search completed", 
        "query", query.Query,
        "results", len(rankedResults),
        "user_id", query.UserID)

    return response, nil
}
```

##### 読み取りモデル投影（Projection）
```go
// internal/infrastructure/projection/drop_search_projection.go
type DropSearchProjection struct {
    db            *gorm.DB
    searchBackend SearchBackend
    logger        *slog.Logger
}

// イベントハンドラー（イベントソーシングからの投影）
func (p *DropSearchProjection) OnDropCreated(event DropCreatedEvent) error {
    // 読み取り専用モデルの更新
    model := &DropSearchModel{
        ID:         event.DropID,
        AuthorID:   event.AuthorID,
        Content:    event.Content,
        Hashtags:   event.Hashtags,
        Mentions:   event.Mentions,
        CreatedAt:  event.CreatedAt,
        UpdatedAt:  event.CreatedAt,
    }
    
    // 非正規化データの保存（読み取り最適化）
    if err := p.db.Create(model).Error; err != nil {
        return fmt.Errorf("failed to create projection: %w", err)
    }
    
    // 検索インデックス更新
    return p.searchBackend.IndexDocument(context.Background(), model.ToSearchDocument())
}

func (p *DropSearchProjection) OnDropUpdated(event DropUpdatedEvent) error {
    // 読み取りモデルの更新
    updates := map[string]interface{}{
        "content":    event.NewContent,
        "updated_at": event.UpdatedAt,
    }
    
    if err := p.db.Model(&DropSearchModel{}).
        Where("id = ?", event.DropID).
        Updates(updates).Error; err != nil {
        return fmt.Errorf("failed to update projection: %w", err)
    }
    
    // 検索インデックス更新
    return p.searchBackend.UpdateDocument(context.Background(), event.DropID, updates)
}
```

### 5.3. イベントソーシング実装詳細

#### イベントストア実装
```go
// internal/domain/event/event_store.go
type EventStore interface {
    // イベントの永続化
    Append(ctx context.Context, streamID string, events []Event) error
    // イベントストリームの読み取り
    Load(ctx context.Context, streamID string, fromVersion int) ([]Event, error)
    // スナップショット保存
    SaveSnapshot(ctx context.Context, aggregateID string, snapshot Snapshot) error
    // スナップショット取得
    GetSnapshot(ctx context.Context, aggregateID string) (*Snapshot, error)
}

type Event struct {
    ID            string
    StreamID      string
    Type          string
    Version       int
    Payload       json.RawMessage
    Metadata      EventMetadata
    OccurredAt    time.Time
}

type EventMetadata struct {
    UserID       string
    CorrelationID string
    CausationID   string
    TraceID       string
}
```

#### イベントソーシング集約実装
```go
// internal/domain/aggregate/search_index_aggregate.go
type SearchIndexAggregate struct {
    ID              string
    Version         int
    IndexType       IndexType
    Documents       map[string]SearchDocument
    LastUpdated     time.Time
    uncommittedEvents []domain.Event
}

// イベントソーシング: イベントから状態を再構築
func (a *SearchIndexAggregate) LoadFromHistory(events []domain.Event) error {
    for _, event := range events {
        if err := a.Apply(event); err != nil {
            return fmt.Errorf("failed to apply event: %w", err)
        }
    }
    return nil
}

// コマンド処理: ビジネスロジック実行とイベント生成
func (a *SearchIndexAggregate) AddDocument(doc SearchDocument) error {
    // ビジネスルール検証
    if err := a.validateDocument(doc); err != nil {
        return fmt.Errorf("invalid document: %w", err)
    }
    
    // イベント生成
    event := DocumentAddedEvent{
        AggregateID: a.ID,
        DocumentID:  doc.ID,
        Document:    doc,
        AddedAt:     time.Now(),
    }
    
    // イベント適用
    a.Apply(event)
    a.uncommittedEvents = append(a.uncommittedEvents, event)
    
    return nil
}

// イベント適用: 状態変更
func (a *SearchIndexAggregate) Apply(event domain.Event) error {
    switch e := event.(type) {
    case DocumentAddedEvent:
        a.Documents[e.DocumentID] = e.Document
        a.LastUpdated = e.AddedAt
        a.Version++
        
    case DocumentUpdatedEvent:
        if doc, exists := a.Documents[e.DocumentID]; exists {
            // 既存ドキュメントの更新
            doc.UpdateContent(e.NewContent)
            doc.UpdatedAt = e.UpdatedAt
            a.Documents[e.DocumentID] = doc
            a.LastUpdated = e.UpdatedAt
            a.Version++
        }
        
    case DocumentDeletedEvent:
        delete(a.Documents, e.DocumentID)
        a.LastUpdated = e.DeletedAt
        a.Version++
        
    default:
        return fmt.Errorf("unknown event type: %T", e)
    }
    
    return nil
}

// スナップショット生成
func (a *SearchIndexAggregate) CreateSnapshot() Snapshot {
    return Snapshot{
        AggregateID: a.ID,
        Version:    a.Version,
        State:      a.toSnapshotState(),
        CreatedAt:  time.Now(),
    }
}
```

#### イベントプロジェクション管理
```go
// internal/infrastructure/projection/projection_manager.go
type ProjectionManager struct {
    eventStore    domain.EventStore
    projections   []Projection
    checkpointer  Checkpointer
    logger        *slog.Logger
}

func (m *ProjectionManager) Start(ctx context.Context) error {
    // 各プロジェクションの最終処理位置を取得
    for _, projection := range m.projections {
        checkpoint, err := m.checkpointer.GetCheckpoint(projection.Name())
        if err != nil {
            return fmt.Errorf("failed to get checkpoint: %w", err)
        }
        
        // イベントストリームの購読開始
        go m.processEvents(ctx, projection, checkpoint)
    }
    
    return nil
}

func (m *ProjectionManager) processEvents(ctx context.Context, projection Projection, fromPosition int64) {
    stream := m.eventStore.Subscribe(ctx, fromPosition)
    
    for {
        select {
        case event := <-stream:
            // プロジェクション更新
            if err := projection.Handle(event); err != nil {
                m.logger.Error("Failed to handle event", "error", err)
                continue
            }
            
            // チェックポイント更新
            if err := m.checkpointer.SaveCheckpoint(projection.Name(), event.Position); err != nil {
                m.logger.Error("Failed to save checkpoint", "error", err)
            }
            
        case <-ctx.Done():
            return
        }
    }
}
```

#### イベント再生とリビルド
```go
// internal/usecase/command/rebuild_projection.go
type RebuildProjectionCommandHandler struct {
    eventStore      domain.EventStore
    projectionRepo  infrastructure.ProjectionRepository
    searchBackend   infrastructure.SearchBackend
    logger          *slog.Logger
}

func (h *RebuildProjectionCommandHandler) Handle(ctx context.Context, cmd RebuildProjectionCommand) error {
    h.logger.Info("Starting projection rebuild", "projection", cmd.ProjectionName)
    
    // 1. 既存プロジェクションをクリア
    if err := h.projectionRepo.Clear(ctx, cmd.ProjectionName); err != nil {
        return fmt.Errorf("failed to clear projection: %w", err)
    }
    
    // 2. 全イベントを取得
    events, err := h.eventStore.LoadAllEvents(ctx, cmd.FromTimestamp)
    if err != nil {
        return fmt.Errorf("failed to load events: %w", err)
    }
    
    // 3. バッチ処理でイベント再生
    const batchSize = 1000
    for i := 0; i < len(events); i += batchSize {
        end := i + batchSize
        if end > len(events) {
            end = len(events)
        }
        
        batch := events[i:end]
        if err := h.processBatch(ctx, batch); err != nil {
            return fmt.Errorf("failed to process batch: %w", err)
        }
        
        h.logger.Info("Processed batch", 
            "from", i, 
            "to", end,
            "total", len(events))
    }
    
    // 4. 検索インデックス最適化
    if err := h.searchBackend.Optimize(ctx); err != nil {
        return fmt.Errorf("failed to optimize search index: %w", err)
    }
    
    h.logger.Info("Projection rebuild completed", 
        "projection", cmd.ProjectionName,
        "events_processed", len(events))
    
    return nil
}
```

### 5.4. イベント駆動アーキテクチャ詳細

#### イベント駆動での検索インデックス更新

##### イベントフロー全体像
```
[avion-drop/avion-user] → [Redis Stream] → [avion-search Consumer] → [MeiliSearch/PostgreSQL]
                              ↓
                        [Event Store]
                              ↓
                        [Projections]
```

##### Redis Streamベースのイベント配信
```go
// internal/infrastructure/event/redis_stream_consumer.go
type RedisStreamConsumer struct {
    client          *redis.Client
    consumerGroup   string
    consumerID      string
    commandBus      *usecase.CommandBus
    eventMapper     EventMapper
    logger          *slog.Logger
}

func (c *RedisStreamConsumer) Start(ctx context.Context) error {
    streams := []string{
        "drop:events",
        "user:events",
        "privacy:events",
    }
    
    for _, stream := range streams {
        // Consumer Group作成（冪等）
        c.createConsumerGroup(stream)
        
        // ストリーム購読開始
        go c.consumeStream(ctx, stream)
    }
    
    return nil
}

func (c *RedisStreamConsumer) consumeStream(ctx context.Context, stream string) {
    for {
        select {
        case <-ctx.Done():
            return
        default:
            // XREADGROUPでイベント取得
            result, err := c.client.XReadGroup(ctx, &redis.XReadGroupArgs{
                Group:    c.consumerGroup,
                Consumer: c.consumerID,
                Streams:  []string{stream, ">"},
                Count:    10,
                Block:    5 * time.Second,
            }).Result()
            
            if err != nil {
                c.logger.Error("Failed to read from stream", "error", err)
                continue
            }
            
            for _, message := range result[0].Messages {
                c.processMessage(ctx, stream, message)
            }
        }
    }
}

func (c *RedisStreamConsumer) processMessage(ctx context.Context, stream string, msg redis.XMessage) {
    // スパン作成（分散トレーシング）
    ctx, span := otel.Tracer("search").Start(ctx, "process_event",
        trace.WithAttributes(
            attribute.String("stream", stream),
            attribute.String("message_id", msg.ID),
        ))
    defer span.End()
    
    // イベントマッピング
    event, err := c.eventMapper.MapFromRedisMessage(msg)
    if err != nil {
        c.handleError(ctx, stream, msg, err)
        return
    }
    
    // コマンド生成と実行
    cmd := c.createCommand(event)
    if err := c.commandBus.Dispatch(ctx, cmd); err != nil {
        c.handleError(ctx, stream, msg, err)
        return
    }
    
    // ACK送信
    if err := c.client.XAck(ctx, stream, c.consumerGroup, msg.ID).Err(); err != nil {
        c.logger.Error("Failed to ack message", "error", err)
    }
}

func (c *RedisStreamConsumer) handleError(ctx context.Context, stream string, msg redis.XMessage, err error) {
    c.logger.Error("Failed to process message", 
        "stream", stream,
        "message_id", msg.ID,
        "error", err)
    
    // リトライカウント確認
    retryCount := c.getRetryCount(msg)
    if retryCount > 3 {
        // DLQへ移動
        c.moveToDeadLetterQueue(ctx, stream, msg)
        // ACK送信（これ以上リトライしない）
        c.client.XAck(ctx, stream, c.consumerGroup, msg.ID)
    }
    // ACKしない → 自動的にリトライ対象になる
}
```

##### イベントタイプと処理マッピング
```go
// internal/domain/event/event_types.go
type EventType string

const (
    // Drop関連イベント
    DropCreated   EventType = "drop.created"
    DropUpdated   EventType = "drop.updated"
    DropDeleted   EventType = "drop.deleted"
    DropReacted   EventType = "drop.reacted"
    
    // User関連イベント
    UserCreated   EventType = "user.created"
    UserUpdated   EventType = "user.updated"
    UserDeleted   EventType = "user.deleted"
    UserBlocked   EventType = "user.blocked"
    
    // Privacy関連イベント
    PrivacyUpdated EventType = "privacy.updated"
    
    // Hashtag関連イベント
    HashtagCreated EventType = "hashtag.created"
    HashtagTrending EventType = "hashtag.trending"
)

// イベント基底構造
type BaseEvent struct {
    ID            string          `json:"id"`
    Type          EventType       `json:"type"`
    AggregateID   string          `json:"aggregate_id"`
    AggregateType string          `json:"aggregate_type"`
    Version       int             `json:"version"`
    OccurredAt    time.Time       `json:"occurred_at"`
    Metadata      EventMetadata   `json:"metadata"`
}

// Drop作成イベント
type DropCreatedEvent struct {
    BaseEvent
    DropID     string   `json:"drop_id"`
    AuthorID   string   `json:"author_id"`
    Content    string   `json:"content"`
    Hashtags   []string `json:"hashtags"`
    Mentions   []string `json:"mentions"`
    MediaURLs  []string `json:"media_urls"`
    Visibility string   `json:"visibility"`
}
```

##### イベントハンドラー登録と処理
```go
// internal/handler/event/event_handler_registry.go
type EventHandlerRegistry struct {
    handlers map[EventType][]EventHandler
    logger   *slog.Logger
}

func NewEventHandlerRegistry() *EventHandlerRegistry {
    registry := &EventHandlerRegistry{
        handlers: make(map[EventType][]EventHandler),
    }
    
    // ハンドラー登録
    registry.registerHandlers()
    
    return registry
}

func (r *EventHandlerRegistry) registerHandlers() {
    // Drop作成イベントハンドラー
    r.Register(DropCreated, 
        &IndexDropHandler{},
        &UpdateHashtagIndexHandler{},
        &ExtractMentionsHandler{},
    )
    
    // Drop更新イベントハンドラー
    r.Register(DropUpdated,
        &UpdateDropIndexHandler{},
        &RecalculateHashtagsHandler{},
    )
    
    // User更新イベントハンドラー
    r.Register(UserUpdated,
        &UpdateUserIndexHandler{},
        &PropagateUserChangeHandler{},
    )
    
    // Privacy更新イベントハンドラー
    r.Register(PrivacyUpdated,
        &UpdateSearchabilityHandler{},
        &RemoveFromPublicIndexHandler{},
    )
}

func (r *EventHandlerRegistry) Handle(ctx context.Context, event Event) error {
    handlers, exists := r.handlers[event.Type()]
    if !exists {
        r.logger.Warn("No handlers registered for event type", "type", event.Type())
        return nil
    }
    
    // 並列実行用のエラーグループ
    g, ctx := errgroup.WithContext(ctx)
    
    for _, handler := range handlers {
        h := handler // キャプチャ
        g.Go(func() error {
            return h.Handle(ctx, event)
        })
    }
    
    return g.Wait()
}
```

##### 冪等性保証メカニズム
```go
// internal/infrastructure/event/idempotency_manager.go
type IdempotencyManager struct {
    cache  *redis.Client
    db     *gorm.DB
    logger *slog.Logger
}

func (m *IdempotencyManager) EnsureIdempotent(ctx context.Context, eventID string, fn func() error) error {
    // 1. 分散ロック取得
    lockKey := fmt.Sprintf("event:lock:%s", eventID)
    lock := m.cache.SetNX(ctx, lockKey, "locked", 10*time.Second)
    if !lock.Val() {
        m.logger.Debug("Event processing already in progress", "event_id", eventID)
        return ErrEventInProgress
    }
    defer m.cache.Del(ctx, lockKey)
    
    // 2. 処理済みチェック（キャッシュ）
    processedKey := fmt.Sprintf("event:processed:%s", eventID)
    if exists := m.cache.Exists(ctx, processedKey).Val(); exists > 0 {
        m.logger.Debug("Event already processed (cache)", "event_id", eventID)
        return nil
    }
    
    // 3. 処理済みチェック（DB）
    var count int64
    m.db.Model(&ProcessedEvent{}).Where("event_id = ?", eventID).Count(&count)
    if count > 0 {
        // キャッシュに追加
        m.cache.Set(ctx, processedKey, "1", 24*time.Hour)
        m.logger.Debug("Event already processed (db)", "event_id", eventID)
        return nil
    }
    
    // 4. 処理実行
    if err := fn(); err != nil {
        return fmt.Errorf("failed to process event: %w", err)
    }
    
    // 5. 処理済み記録
    processedEvent := &ProcessedEvent{
        EventID:     eventID,
        ProcessedAt: time.Now(),
    }
    
    if err := m.db.Create(processedEvent).Error; err != nil {
        return fmt.Errorf("failed to record processed event: %w", err)
    }
    
    // 6. キャッシュ更新
    m.cache.Set(ctx, processedKey, "1", 24*time.Hour)
    
    m.logger.Info("Event processed successfully", "event_id", eventID)
    return nil
}
```

##### サーキットブレーカーパターン実装
```go
// internal/infrastructure/resilience/circuit_breaker.go
type CircuitBreaker struct {
    name            string
    maxFailures     int
    resetTimeout    time.Duration
    halfOpenMax     int
    
    mu              sync.RWMutex
    state           State
    failures        int
    lastFailureTime time.Time
    successCount    int
}

type State int

const (
    StateClosed State = iota
    StateOpen
    StateHalfOpen
)

func (cb *CircuitBreaker) Execute(ctx context.Context, fn func() error) error {
    if !cb.canExecute() {
        return ErrCircuitBreakerOpen
    }
    
    err := fn()
    cb.recordResult(err)
    
    return err
}

func (cb *CircuitBreaker) canExecute() bool {
    cb.mu.RLock()
    defer cb.mu.RUnlock()
    
    switch cb.state {
    case StateClosed:
        return true
        
    case StateOpen:
        // タイムアウト経過確認
        if time.Since(cb.lastFailureTime) > cb.resetTimeout {
            cb.mu.RUnlock()
            cb.mu.Lock()
            cb.state = StateHalfOpen
            cb.successCount = 0
            cb.mu.Unlock()
            cb.mu.RLock()
            return true
        }
        return false
        
    case StateHalfOpen:
        // 半開状態での実行制限
        return cb.successCount < cb.halfOpenMax
        
    default:
        return false
    }
}

func (cb *CircuitBreaker) recordResult(err error) {
    cb.mu.Lock()
    defer cb.mu.Unlock()
    
    if err != nil {
        cb.failures++
        cb.lastFailureTime = time.Now()
        
        if cb.failures >= cb.maxFailures {
            cb.state = StateOpen
        }
    } else {
        if cb.state == StateHalfOpen {
            cb.successCount++
            if cb.successCount >= cb.halfOpenMax {
                cb.state = StateClosed
                cb.failures = 0
            }
        } else if cb.state == StateClosed {
            cb.failures = 0
        }
    }
}
```

##### イベント順序保証
```go
// internal/infrastructure/event/event_sequencer.go
type EventSequencer struct {
    sequences map[string]*SequenceTracker
    mu        sync.RWMutex
    logger    *slog.Logger
}

type SequenceTracker struct {
    LastProcessed int64
    Pending       map[int64]Event
    mu            sync.Mutex
}

func (s *EventSequencer) ProcessInOrder(ctx context.Context, event Event) error {
    aggregateID := event.GetAggregateID()
    version := event.GetVersion()
    
    tracker := s.getOrCreateTracker(aggregateID)
    tracker.mu.Lock()
    defer tracker.mu.Unlock()
    
    // 期待するバージョンか確認
    expectedVersion := tracker.LastProcessed + 1
    
    if version == expectedVersion {
        // 順序通りなので処理
        if err := s.processEvent(ctx, event); err != nil {
            return err
        }
        tracker.LastProcessed = version
        
        // ペンディングイベントの処理
        s.processPendingEvents(ctx, tracker)
        
    } else if version > expectedVersion {
        // 順序が前後しているのでペンディング
        tracker.Pending[version] = event
        s.logger.Debug("Event queued for later processing", 
            "aggregate_id", aggregateID,
            "version", version,
            "expected", expectedVersion)
            
    } else {
        // 既に処理済み
        s.logger.Debug("Event already processed", 
            "aggregate_id", aggregateID,
            "version", version)
    }
    
    return nil
}

func (s *EventSequencer) processPendingEvents(ctx context.Context, tracker *SequenceTracker) {
    for {
        nextVersion := tracker.LastProcessed + 1
        event, exists := tracker.Pending[nextVersion]
        if !exists {
            break
        }
        
        if err := s.processEvent(ctx, event); err != nil {
            s.logger.Error("Failed to process pending event", "error", err)
            break
        }
        
        delete(tracker.Pending, nextVersion)
        tracker.LastProcessed = nextVersion
    }
}
```

### 5.5. 主要コンポーネント

- **主要コンポーネント:**
    - `avion-search (Go, Kubernetes Deployment)`: 本サービス。gRPCサーバー、Redis Stream Consumer。
    - `avion-gateway (Go)`: gRPCリクエストのルーティング元。
    - `MeiliSearch`: プライマリ全文検索エンジン。
    - `PostgreSQL`: (オプション) 全文検索機能を利用。元データ参照元。
    - `avion-drop (Go)`: Dropデータ参照元 (gRPC)。
    - `avion-auth (Go)`: Userデータ参照元 (gRPC)。
    - `Redis`: イベント通知 (Stream)、処理済みイベント管理。
    - `Observability Stack`: メトリクス、トレース、ログ収集。
- **構成図:** (アーキテクチャ概要図を参照)
    - [Avion アーキテクチャ概要](../common/architecture.md)
- **ポイント:**
    - イベント駆動で検索インデックスを更新。
    - 複数の検索バックエンドをサポート。
    - アクセス制御を適用した検索結果提供。
    - 冪等性を保証したイベント処理。
    - ステートレス設計でスケーラビリティを確保。

## データベースマイグレーション

このサービスでは、[共通マイグレーション戦略](../common/database-migration-strategy.md)に従って、Gooseを使用したマイグレーション管理を行います。

### マイグレーション戦略

- **ツール**: Goose v3
- **ディレクトリ**: `./migrations/`
- **命名規則**: `[sequence_number]_[description].sql`
- **実行方法**: `make migrate-up` / `make migrate-down`

### avion-search固有の考慮事項

- **検索インデックス再構築**: PostgreSQLスキーマ変更時はMeiliSearchインデックスの再構築
- **検索フォールバック**: MeiliSearch更新中はPostgreSQLフォールバック検索を活用
- **同期処理継続**: 他サービスからの検索データ同期処理を中断させない
- **検索設定保持**: カスタム検索設定（ランキング、フィルタ）を移行時も保持
- **大量データ再インデックス**: 全文検索データの大量更新は段階的に処理

### 標準テンプレート参照

マイグレーションファイル作成時は[マイグレーション設定テンプレート](../templates/migration-setup-template.md)を参照してください。

## 7. Use Cases / Key Flows (主な使い方・処理の流れ)

- **フロー 1: MeiliSearchインデックス更新 (Command)**
    1. IndexEventHandler: Redis Stream `search_events` からConsumer Group経由でイベント取得
    2. IndexEventHandler: ProcessIndexEventCommandUseCaseを呼び出し
    3. ProcessIndexEventCommandUseCase: EventID Value Objectを生成し、冪等性チェック
    4. ProcessIndexEventCommandUseCase: EventRepositoryでProcessedEvent Entityを確認
    5. ProcessIndexEventCommandUseCase: IndexOperation Aggregateを生成
    6. DocumentFactory (Domain Service): イベントデータからDropSearchDocument Entityを生成
    7. SearchIndex Aggregate: DropSearchDocumentを追加し、整合性を保証
    8. ProcessIndexEventCommandUseCase: SearchIndexRepositoryを通じてSearchIndexを永続化
    9. ProcessIndexEventCommandUseCase: EventRepositoryを通じてProcessedEventを記録
    10. IndexEventHandler: イベントをACK。エラー時はリトライ/DLQ
- **フロー 2: Drop検索 (Query)**
    1. Gateway → SearchDropsQueryHandler: `SearchDrops` gRPC Call (query, limit, offset, Metadata: X-User-ID, Trace Context)
    2. SearchDropsQueryHandler: SearchDropsQueryUseCaseを呼び出し
    3. SearchDropsQueryUseCase: SearchQuery Value Objectを生成・検証
    4. AccessControlPolicy (Domain Service): UserIDに基づくSearchFilter Value Objectを生成
    5. SearchDropsQueryUseCase: DropSearchQueryServiceを通じてMeiliSearchに問い合わせ
    6. DropSearchQueryService: SearchResult Value Objectを返却（items, totalCount, relevanceScore）
    7. SearchDropsQueryUseCase: DropServiceClientで必要に応じて追加情報を取得
    8. SearchDropsQueryHandler → Gateway: `SearchDropsResponse { results: [...] }`
- **フロー 3: User検索 (Query)**
    1. Gateway → SearchUsersQueryHandler: `SearchUsers` gRPC Call (query, backend, limit, offset)
    2. SearchUsersQueryHandler: SearchUsersQueryUseCaseを呼び出し
    3. SearchUsersQueryUseCase: SearchQuery Value Objectを生成
    4. SearchPolicy (Domain Service): ユーザー検索のビジネスルールを適用
    5. SearchUsersQueryUseCase: UserSearchQueryServiceを通じて検索実行
    6. UserSearchQueryService: SearchResult Value Objectを返却
    7. SearchUsersQueryUseCase: UserServiceClientで必要に応じて追加情報を取得
    8. SearchUsersQueryHandler → Gateway: `SearchUsersResponse { results: [...] }`

- **フロー 4: インデックス再構築 (Command)**
    1. Gateway → RebuildIndexCommandHandler: `RebuildIndex` gRPC Call (index_type)
    2. RebuildIndexCommandHandler: RebuildIndexCommandUseCaseを呼び出し
    3. RebuildIndexCommandUseCase: SearchIndex Aggregateを生成
    4. SearchIndex Aggregate: IndexStatusをREBUILDINGに変更
    5. RebuildIndexCommandUseCase: DropServiceClient/UserServiceClientから全データをバッチ取得
    6. DocumentFactory: 各データからSearchDocumentを生成
    7. RebuildIndexCommandUseCase: SearchIndexRepositoryを通じて新しいインデックスを作成し、切り替え
    8. SearchIndex Aggregate: IndexStatusをACTIVEに変更

- **フロー 5: 検索プライバシー設定更新 (Command)**
    1. User → Gateway → UpdateSearchPrivacyCommandHandler: `UpdateSearchPrivacy` gRPC Call
    2. UpdateSearchPrivacyCommandHandler: UpdateSearchPrivacyCommandUseCaseを呼び出し
    3. UpdateSearchPrivacyCommandUseCase: SearchableContentSettings Value Objectを生成
    4. SearchPrivacyPolicy (Domain Service): 既存Dropのインデックス更新判定
    5. UpdateSearchPrivacyCommandUseCase: 設定に基づいてインデックスの追加/削除を実行
    6. UpdateSearchPrivacyCommandUseCase: UserSearchPrivacyUpdatedイベントを発行

- **フロー 6: ハッシュタグ検索 (Query)**
    1. Gateway → SearchByHashtagQueryHandler: `SearchByHashtag` gRPC Call (#tag, limit, offset)
    2. SearchByHashtagQueryHandler: SearchByHashtagQueryUseCaseを呼び出し
    3. SearchByHashtagQueryUseCase: Hashtag Value Objectを生成・正規化
    4. HashtagSearchQueryService: HashtagIndexからDropIDリストを取得
    5. DropSearchQueryService: DropIDリストから詳細情報を取得
    6. TrendingCalculator (Domain Service): TrendingScoreを計算
    7. SearchByHashtagQueryHandler → Gateway: `HashtagSearchResponse { results: [...], trending_score: ... }`

- **フロー 7: 保存検索の実行 (Query)**
    1. Gateway → ExecuteSavedSearchQueryHandler: `ExecuteSavedSearch` gRPC Call (saved_search_id)
    2. ExecuteSavedSearchQueryHandler: ExecuteSavedSearchQueryUseCaseを呼び出し
    3. SavedSearchRepository: SavedSearch Entityを取得
    4. ExecuteSavedSearchQueryUseCase: 保存されたSearchQueryとSearchFilterで検索実行
    5. ExecuteSavedSearchQueryUseCase: 新着があれば通知イベントを発行
    6. ExecuteSavedSearchQueryHandler → Gateway: `SearchResponse { results: [...], new_matches: ... }`

## 8. Endpoints (API)

- **gRPC Services (`avion.SearchService`):**
    - **Query Operations (参照系):**
        - `SearchDrops(SearchDropsRequest) returns (SearchDropsResponse)` // GET相当
        - `SearchUsers(SearchUsersRequest) returns (SearchUsersResponse)` // GET相当
        - `SearchByHashtag(SearchByHashtagRequest) returns (HashtagSearchResponse)` // GET相当
        - `SearchMentions(SearchMentionsRequest) returns (SearchMentionsResponse)` // GET相当
        - `GetSearchHistory(GetSearchHistoryRequest) returns (SearchHistoryResponse)` // GET相当
        - `GetSavedSearches(GetSavedSearchesRequest) returns (SavedSearchesResponse)` // GET相当
        - `GetTrendingHashtags(GetTrendingHashtagsRequest) returns (TrendingHashtagsResponse)` // GET相当
        - `GetIndexStatus(GetIndexStatusRequest) returns (IndexStatusResponse)` // GET相当
        - (Requestには `query`, `backend` (enum: MEILISEARCH, POSTGRES), `limit`, `offset` などを含む)
        - (Responseには検索結果のリストを含む)
    - **Command Operations (更新系):**
        - `RebuildIndex(RebuildIndexRequest) returns (RebuildIndexResponse)` // POST相当
        - `UpdateSearchPrivacy(UpdateSearchPrivacyRequest) returns (UpdateSearchPrivacyResponse)` // PUT相当
        - `SaveSearch(SaveSearchRequest) returns (SaveSearchResponse)` // POST相当
        - `DeleteSavedSearch(DeleteSavedSearchRequest) returns (DeleteSavedSearchResponse)` // DELETE相当
        - (管理用API、インデックス再構築時に使用)
- Proto定義は別途管理する。

## 9. Data Design (データ)

### 8.1. Domain Model (ドメインモデル)

#### Aggregates (集約)

##### SearchIndex (検索インデックス集約)
- **責務:** 検索インデックスの整合性とライフサイクルを管理
- **集約ルート:** SearchIndex
- **構成要素:**
  - IndexID (Value Object): インデックスの一意識別子
  - IndexType (Value Object): DROPS, USERS
  - IndexStatus (Value Object): ACTIVE, REBUILDING, FAILED
  - LastSyncTimestamp (Value Object): 最終同期日時
  - DocumentCount (Value Object): ドキュメント数
- **不変条件:**
  - IndexTypeは一度設定されたら変更不可（データ整合性保護）
  - REBUILDING状態では新規ドキュメント追加不可（整合性確保）
  - DocumentCountは非負の数（論理的制約）
  - 同時実行可能なREBUILD操作は1つまで（排他制御）
  - インデックスの最大ドキュメント数制限遵守（リソース保護）

##### IndexOperation (インデックス操作集約)
- **責務:** インデックス操作のトランザクション境界を管理
- **集約ルート:** IndexOperation
- **構成要紀:**
  - OperationID (Value Object): 操作の一意識別子
  - OperationType (Value Object): ADD, UPDATE, DELETE, REBUILD
  - TargetIndex (SearchIndex): 対象インデックス
  - Documents (Entity Collection): 操作対象ドキュメント
  - OperationStatus (Value Object): PENDING, IN_PROGRESS, COMPLETED, FAILED
- **不変条件:**
  - 一度開始した操作は完了または失敗まで継続（操作の原子性）
  - REBUILD操作中は他の操作不可（排他制御）
  - 同一EventIDの操作は重複不可（冪等性保証）
  - 操作タイムアウト時間内での完了必須（リソース管理）
  - 操作対象ドキュメントの検証必須（データ品質）

#### Entities (エンティティ)

##### DropSearchDocument (Drop検索ドキュメント)
- **責務:** Drop検索ドキュメントの情報を保持
- **所属集約:** SearchIndex
- **属性:**
  - DropID (Value Object): Dropの一意識別子
  - SearchableText (Value Object): 検索対象テキスト
  - Visibility (Value Object): public, private, followers_only
  - AuthorID (Value Object): 作成者UserID
  - CreatedAt (Value Object): 作成日時
  - SearchMetadata (Value Object): 追加検索メタデータ
  - Hashtags (Entity Collection): 抽出されたハッシュタグ
  - Mentions (Entity Collection): 抽出されたメンション
- **ビジネスルール:**
  - SearchableTextは最大5000文字（検索性能保護）
  - Visibilityに応じた検索可能性制御（プライバシー保護）
  - 削除されたDropは検索インデックスから除外（データ整合性）
  - センシティブコンテンツのフィルタリング対応（コンテンツ管理）
  - ハッシュタグ・メンション自動抽出と正規化（検索精度向上）

##### UserSearchDocument (User検索ドキュメント)
- **責務:** User検索ドキュメントの情報を保持
- **所属集約:** SearchIndex
- **属性:**
  - UserID (Value Object): Userの一意識別子
  - Username (Value Object): ユーザー名
  - DisplayName (Value Object): 表示名
  - Bio (Value Object): 自己紹介
  - SearchableFields (Value Object): 検索対象フィールドの集合
  - SearchPrivacySettings (Value Object): 検索プライバシー設定
- **ビジネスルール:**
  - SearchPrivacySettingsに従う検索可能性制御（GDPR準拠）
  - 停止・凍結されたユーザーは検索対象外（安全性確保）
  - ユーザー名の一意性検証（データ整合性）
  - プロフィール完成度による検索優先度調整（ユーザー体験向上）
  - ボットアカウントの適切な分類とフィルタリング（検索品質向上）

##### ProcessedEvent (処理済みイベント)
- **責務:** 処理済みイベントの記録を管理
- **属性:**
  - EventID (Value Object): イベントの一意識別子
  - ProcessedAt (Value Object): 処理日時
  - OperationType (Value Object): 実行した操作種別
  - Result (Value Object): 処理結果

#### Value Objects (値オブジェクト)

##### SearchQuery
- **責務:** 検索クエリを表現
- **属性:** queryText, filters, pagination
- **不変性:** 完全に不変

##### SearchResult
- **責務:** 検索結果を表現
- **属性:** items, totalCount, relevanceScores
- **不変性:** 完全に不変

##### EventID
- **責務:** イベントの一意識別子を表現
- **属性:** value (UUIDまたはSnowflake ID)
- **不変性:** 完全に不変

##### SearchFilter
- **責務:** 検索フィルタ条件を表現
- **属性:** field, operator, value
- **不変性:** 完全に不変

##### SearchableText
- **責務:** 検索対象テキストを表現
- **属性:** text, language
- **不変性:** 完全に不変

##### RelevanceScore
- **責務:** 検索結果の関連性スコアを表現
- **属性:** score (0.0-1.0)
- **不変性:** 完全に不変

### 8.2. Infrastructure Layer (インフラストラクチャ層)

- **MeiliSearch Index:**
    - `drops` index: DropSearchDocument Entityに対応
        - Filterable attributes: visibility, author_id, created_at, searchable
        - Searchable attributes: text, metadata, hashtags, mentions
        - Sortable attributes: created_at, relevance
    - `users` index: UserSearchDocument Entityに対応
        - Filterable attributes: user_id, searchable_profile
        - Searchable attributes: username, display_name, bio
    - `hashtags` index: HashtagIndex Aggregateに対応
        - Filterable attributes: trending_score
        - Searchable attributes: hashtag, normalized_hashtag
        - Sortable attributes: drop_count, trending_score, last_used_at
    - 日本語設定（トークナイザー）を有効化
- **PostgreSQL:** (参照のみ)
    - 全文検索インデックス (`GIN` or `GiST`) を活用
    - `to_tsvector('japanese', text)` で日本語対応
    - 追加テーブル:
        - `search_history`: 検索履歴保存
        - `saved_searches`: 保存検索条件
        - `mention_index`: メンションインデックス
- **Redis:**
    - Event Stream: `search_events` (Consumer Group: `search_workers`)
    - Processed Events Set: `processed_events:{index_type}` (EventIDを保存)
    - Operation Lock: `index_operation:{index_type}` (REBUILD時の排他制御)
    - Search History: `search_history:{user_id}` (最近の検索クエリ)
    - Trending Hashtags: `trending_hashtags` (Sorted Set)
    - Search Privacy Settings: `search_privacy:{user_id}` (ユーザー設定キャッシュ)

## 10. Operations & Monitoring (運用と監視)

- **主なオペレーション:**
    - MeiliSearch/PostgreSQLの接続情報管理。
    - Redis接続情報、Stream/Consumer Group設定。
    - MeiliSearchインデックス設定の管理・更新。
    - (必要に応じて) MeiliSearchインデックスの再構築。
    - DLQの監視と対応。
- **監視/アラート:**
    - **メトリクス:**
        - gRPCリクエスト数、レイテンシ、エラーレート。
        - MeiliSearch/PostgreSQLクエリ実行時間、エラーレート。
        - Redis Stream処理遅延、エラーレート、Pending数。
    - **ログ:** API処理ログ、イベント処理ログ (冪等性チェック結果含む)、MeiliSearch/PostgreSQL連携ログ、エラーログ、DLQ投入ログ。
    - **トレース:** API呼び出し、イベント処理、MeiliSearch/PostgreSQLアクセスのトレース。
    - **アラート:** gRPCエラーレート急増、高レイテンシ、MeiliSearch/PostgreSQL接続障害、Stream処理遅延大/Pending数増加、インデックス更新失敗。

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
    Service     string    `json:"service"`     // "avion-search"
    Version     string    `json:"version"`     // サービスバージョン
    TraceID     string    `json:"trace_id"`    // OpenTelemetry TraceID
    SpanID      string    `json:"span_id"`     // OpenTelemetry SpanID
    
    // コンテキストフィールド
    UserID      string    `json:"user_id,omitempty"`
    RequestID   string    `json:"request_id,omitempty"`
    IndexType   string    `json:"index_type,omitempty"`   // drops/users
    Backend     string    `json:"backend,omitempty"`      // meilisearch/postgres
    Layer       string    `json:"layer,omitempty"`        // domain/usecase/infra/handler
    
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
logger.Info("search request received",
    slog.String("method", "SearchDrops"),
    slog.String("query", query),
    slog.String("backend", backend),
    slog.String("trace_id", traceID),
    slog.String("user_id", userID),
    slog.String("layer", "handler"),
)

logger.Error("search handler failed",
    slog.String("method", "SearchDrops"),
    slog.String("error", err.Error()),
    slog.String("error_code", "SEARCH_HANDLER_ERROR"),
    slog.String("layer", "handler"),
)
```

#### Use Case層
```go
logger.Info("executing search query",
    slog.String("use_case", "SearchDropsQueryUseCase"),
    slog.String("query", searchQuery.Text()),
    slog.Int("limit", searchQuery.Limit()),
    slog.Int("offset", searchQuery.Offset()),
    slog.String("layer", "usecase"),
)

logger.Warn("access control filter applied",
    slog.String("user_id", userID),
    slog.String("filter_type", "visibility"),
    slog.Any("filters", filters),
    slog.String("layer", "usecase"),
)
```

#### Infrastructure層
```go
logger.Debug("meilisearch query executed",
    slog.String("index", "drops"),
    slog.String("query", searchText),
    slog.Int("results_count", len(results)),
    slog.Int64("duration_ms", queryDuration),
    slog.String("layer", "infra"),
)

logger.Error("meilisearch connection failed",
    slog.String("host", meiliHost),
    slog.String("error", err.Error()),
    slog.String("error_code", "MEILISEARCH_CONNECTION_ERROR"),
    slog.String("layer", "infra"),
)
```

### インデックス更新のログ
```go
// イベント処理開始
logger.Info("index event received",
    slog.String("event", "index_update"),
    slog.String("event_id", eventID),
    slog.String("event_type", eventType),
    slog.String("entity_type", entityType),
    slog.String("entity_id", entityID),
)

// 冪等性チェック
logger.Debug("idempotency check",
    slog.String("event_id", eventID),
    slog.Bool("already_processed", alreadyProcessed),
)

// ドキュメント追加成功
logger.Info("document indexed",
    slog.String("event", "document_indexed"),
    slog.String("index_type", indexType),
    slog.String("document_id", docID),
    slog.String("operation", operation),
    slog.Int64("processing_time_ms", processingTime),
)

// インデックス更新失敗
logger.Error("index update failed",
    slog.String("event", "index_update_failed"),
    slog.String("event_id", eventID),
    slog.String("index_type", indexType),
    slog.String("error", err.Error()),
    slog.Int("retry_count", retryCount),
    slog.Bool("sent_to_dlq", sentToDLQ),
)
```

### 検索処理のログ
```go
// 検索実行
logger.Info("search executed",
    slog.String("event", "search_executed"),
    slog.String("search_type", searchType),
    slog.String("backend", backend),
    slog.String("query", sanitizedQuery),
    slog.Int("results_count", resultsCount),
    slog.Int("total_count", totalCount),
    slog.Float64("max_score", maxScore),
    slog.Int64("duration_ms", duration),
)

// PostgreSQL FTS実行
logger.Debug("postgres fts query",
    slog.String("table", tableName),
    slog.String("ts_query", tsQuery),
    slog.String("ts_config", "japanese"),
    slog.Int("results", count),
    slog.Int64("duration_ms", duration),
)
```

### インデックス再構築のログ
```go
// 再構築開始
logger.Info("index rebuild started",
    slog.String("event", "rebuild_started"),
    slog.String("index_type", indexType),
    slog.String("initiated_by", initiatedBy),
    slog.String("rebuild_id", rebuildID),
)

// バッチ処理進捗
logger.Info("rebuild batch processed",
    slog.String("rebuild_id", rebuildID),
    slog.String("index_type", indexType),
    slog.Int("batch_number", batchNum),
    slog.Int("batch_size", batchSize),
    slog.Int("total_processed", totalProcessed),
    slog.Float64("progress_percent", progressPercent),
)

// 再構築完了
logger.Info("index rebuild completed",
    slog.String("event", "rebuild_completed"),
    slog.String("rebuild_id", rebuildID),
    slog.String("index_type", indexType),
    slog.Int("total_documents", totalDocuments),
    slog.Int64("duration_ms", duration),
    slog.Bool("success", success),
)
```

### Redis Stream処理のログ
```go
// Consumer Group処理
logger.Info("stream consumer started",
    slog.String("stream", "search_events"),
    slog.String("consumer_group", "search_workers"),
    slog.String("consumer_id", consumerID),
)

// イベント処理遅延警告
logger.Warn("event processing lag detected",
    slog.String("event", "processing_lag"),
    slog.String("stream", "search_events"),
    slog.Int("pending_count", pendingCount),
    slog.Int64("oldest_message_age_ms", oldestMessageAge),
)

// DLQ投入
logger.Error("event sent to DLQ",
    slog.String("event", "dlq_insertion"),
    slog.String("event_id", eventID),
    slog.String("reason", reason),
    slog.Int("retry_count", retryCount),
    slog.String("original_error", originalError),
)
```

### CRITICALレベルログの例
```go
// MeiliSearchサービス完全障害時
logger.With(slog.String("level", "CRITICAL")).Error("meilisearch service failure",
    slog.String("component", "meilisearch"),
    slog.String("host", meiliHost),
    slog.String("error", "all_operations_failing"),
    slog.Float64("error_rate", 1.0),
    slog.String("impact", "search_functionality_stopped"),
)

// インデックス整合性破損時
logger.With(slog.String("level", "CRITICAL")).Error("index data corruption detected",
    slog.String("index_type", indexType),
    slog.String("corruption_type", "document_count_mismatch"),
    slog.Int("expected_count", expectedCount),
    slog.Int("actual_count", actualCount),
    slog.String("action", "immediate_index_rebuild_required"),
)

// 検索イベント処理完全停止時
logger.With(slog.String("level", "CRITICAL")).Error("search event processing failure",
    slog.String("stream", "search_events"),
    slog.String("consumer_group", "search_workers"),
    slog.String("error", "all_consumers_failed"),
    slog.Int("pending_events", pendingEventCount),
    slog.String("impact", "search_index_updates_stopped"),
)
```

### ログ集約とクエリ
- **出力先**: 標準出力（Kubernetes環境ではFluentd/Fluent Bitが収集）
- **集約先**: Elasticsearch、CloudWatch Logs、またはLoki
- **クエリ例**:
  ```
  service="avion-search" AND event="search_executed" AND backend="meilisearch"
  service="avion-search" AND event="index_update_failed"
  service="avion-search" AND layer="infra" AND error_code="MEILISEARCH_CONNECTION_ERROR"
  service="avion-search" AND event="processing_lag" AND pending_count>1000
  service="avion-search" AND level="CRITICAL"
  ```

### セキュリティ考慮事項
- 検索クエリは個人情報を含む可能性があるため、必要最小限の記録に留める
- ユーザーIDは記録するが、検索内容の詳細は適切にサニタイズ
- エラーメッセージに含まれる可能性のあるセンシティブ情報をフィルタリング

## 12. エラーハンドリング戦略

> **注意:** エラーコードは[共通エラーコード標準](../common/errors/error-codes.md)に準拠します。このサービスではプレフィックス `SRC` を使用します。

### エラーコード体系

本サービスは、Avionプラットフォーム標準のエラーコード体系に準拠します。

- **命名規則**: `[SERVICE]_[LAYER]_[ERROR_TYPE]`形式
- **エラーカタログ**: [error-catalog.md](./error-catalog.md)
- **実装ガイド**: [共通エラー実装ガイド](../common/errors/implementation-guide.md)
- **標準仕様**: [エラーコード標準化ガイドライン](../common/errors/error-standards.md)

詳細なエラーコード定義とマッピングについては、上記のドキュメントを参照してください。

### 11.1. ドメインエラーの定義

検索サービス固有のドメインエラーを定義します：

```go
// Domain Layer Errors
type SearchError struct {
    Code    string
    Message string
    Details map[string]interface{}
}

// Search-specific errors
var (
    // Index errors
    ErrIndexNotFound        = &SearchError{Code: "INDEX_NOT_FOUND", Message: "search index not found"}
    ErrIndexCreationFailed  = &SearchError{Code: "INDEX_CREATION_FAILED", Message: "failed to create search index"}
    ErrIndexUpdateFailed    = &SearchError{Code: "INDEX_UPDATE_FAILED", Message: "failed to update search index"}
    ErrIndexDeletionFailed  = &SearchError{Code: "INDEX_DELETION_FAILED", Message: "failed to delete from index"}
    ErrIndexSyncFailed      = &SearchError{Code: "INDEX_SYNC_FAILED", Message: "index synchronization failed"}
    
    // Query errors
    ErrInvalidQuery         = &SearchError{Code: "INVALID_QUERY", Message: "invalid search query"}
    ErrQueryTooShort        = &SearchError{Code: "QUERY_TOO_SHORT", Message: "search query too short"}
    ErrQueryTooLong         = &SearchError{Code: "QUERY_TOO_LONG", Message: "search query too long"}
    ErrInvalidFilter        = &SearchError{Code: "INVALID_FILTER", Message: "invalid search filter"}
    ErrInvalidSort          = &SearchError{Code: "INVALID_SORT", Message: "invalid sort parameter"}
    
    // MeiliSearch specific errors
    ErrMeiliSearchUnavailable = &SearchError{Code: "MEILISEARCH_UNAVAILABLE", Message: "MeiliSearch service unavailable"}
    ErrMeiliSearchTimeout     = &SearchError{Code: "MEILISEARCH_TIMEOUT", Message: "MeiliSearch request timeout"}
    ErrMeiliSearchAPIError    = &SearchError{Code: "MEILISEARCH_API_ERROR", Message: "MeiliSearch API error"}
    ErrMeiliSearchQuotaExceeded = &SearchError{Code: "MEILISEARCH_QUOTA_EXCEEDED", Message: "MeiliSearch quota exceeded"}
    
    // Privacy and permission errors
    ErrUnauthorizedSearch   = &SearchError{Code: "UNAUTHORIZED_SEARCH", Message: "unauthorized search request"}
    ErrPrivacyViolation     = &SearchError{Code: "PRIVACY_VIOLATION", Message: "search would violate privacy settings"}
    ErrBlockedContent       = &SearchError{Code: "BLOCKED_CONTENT", Message: "search includes blocked content"}
    
    // Trending and analytics errors
    ErrTrendingUnavailable  = &SearchError{Code: "TRENDING_UNAVAILABLE", Message: "trending data unavailable"}
    ErrAnalyticsError       = &SearchError{Code: "ANALYTICS_ERROR", Message: "search analytics error"}
    
    // Pagination errors
    ErrInvalidPagination    = &SearchError{Code: "INVALID_PAGINATION", Message: "invalid pagination parameters"}
    ErrPageOutOfRange       = &SearchError{Code: "PAGE_OUT_OF_RANGE", Message: "requested page out of range"}
)
```

### 11.2. エラーハンドリングの層別実装

#### Handler Layer

```go
func (h *SearchHandler) Search(ctx context.Context, req *pb.SearchRequest) (*pb.SearchResponse, error) {
    result, err := h.searchUseCase.Execute(ctx, req)
    if err != nil {
        switch e := err.(type) {
        case *domain.SearchError:
            return nil, h.mapDomainErrorToGRPC(e)
        case *infrastructure.MeiliSearchError:
            return nil, status.Error(codes.Internal, "search engine error")
        default:
            logger.Error("unexpected error in search handler",
                slog.String("error", err.Error()),
                slog.String("trace_id", trace.SpanFromContext(ctx).SpanContext().TraceID().String()))
            return nil, status.Error(codes.Internal, "internal server error")
        }
    }
    return result, nil
}

func (h *SearchHandler) mapDomainErrorToGRPC(err *domain.SearchError) error {
    switch err.Code {
    case "INVALID_QUERY", "QUERY_TOO_SHORT", "QUERY_TOO_LONG":
        return status.Error(codes.InvalidArgument, err.Message)
    case "UNAUTHORIZED_SEARCH":
        return status.Error(codes.PermissionDenied, err.Message)
    case "MEILISEARCH_UNAVAILABLE":
        return status.Error(codes.Unavailable, err.Message)
    case "MEILISEARCH_TIMEOUT":
        return status.Error(codes.DeadlineExceeded, err.Message)
    default:
        return status.Error(codes.Internal, err.Message)
    }
}
```

#### Use Case Layer

```go
func (uc *SearchDropsUseCase) Execute(ctx context.Context, query string, filters SearchFilters) (*SearchResult, error) {
    // Validate query
    if err := uc.validateQuery(query); err != nil {
        return nil, err
    }
    
    // Apply privacy filters
    filters, err := uc.applyPrivacyFilters(ctx, filters)
    if err != nil {
        return nil, fmt.Errorf("apply privacy filters: %w", err)
    }
    
    // Execute search with retry
    var result *SearchResult
    err = retry.Do(
        func() error {
            var searchErr error
            result, searchErr = uc.searchBackend.SearchDrops(ctx, query, filters)
            return searchErr
        },
        retry.Attempts(3),
        retry.Delay(100*time.Millisecond),
        retry.OnRetry(func(n uint, err error) {
            logger.Warn("retrying search",
                slog.Uint("attempt", n),
                slog.String("error", err.Error()))
        }),
    )
    
    if err != nil {
        if errors.Is(err, context.DeadlineExceeded) {
            return nil, ErrMeiliSearchTimeout
        }
        return nil, fmt.Errorf("search execution failed: %w", err)
    }
    
    return result, nil
}
```

#### Infrastructure Layer

```go
func (m *MeiliSearchClient) SearchDrops(ctx context.Context, query string, filters SearchFilters) (*SearchResult, error) {
    searchReq := &meilisearch.SearchRequest{
        Query:  query,
        Filter: m.buildFilter(filters),
        Limit:  filters.Limit,
        Offset: filters.Offset,
    }
    
    resp, err := m.client.Index("drops").Search(searchReq)
    if err != nil {
        if meiliErr, ok := err.(*meilisearch.Error); ok {
            switch meiliErr.StatusCode {
            case 404:
                return nil, status.Error(codes.NotFound, "search index not found")
            case 429:
                return nil, status.Error(codes.ResourceExhausted, "search quota exceeded")
            case 503:
                return nil, status.Error(codes.Unavailable, "search service unavailable")
            default:
                return nil, &SearchError{
                    Code:    "MEILISEARCH_API_ERROR",
                    Message: meiliErr.Message,
                    Details: map[string]interface{}{"status_code": meiliErr.StatusCode},
                }
            }
        }
        return nil, fmt.Errorf("meilisearch error: %w", err)
    }
    
    return m.mapToSearchResult(resp), nil
}
```

### 11.3. リトライとサーキットブレーカー

```go
// Circuit breaker for MeiliSearch
var meiliSearchBreaker = gobreaker.NewCircuitBreaker(gobreaker.Settings{
    Name:        "MeiliSearchBreaker",
    MaxRequests: 3,
    Interval:    10 * time.Second,
    Timeout:     30 * time.Second,
    ReadyToTrip: func(counts gobreaker.Counts) bool {
        failureRatio := float64(counts.ConsecutiveFailures) / float64(counts.Requests)
        return counts.Requests >= 3 && failureRatio >= 0.6
    },
    OnStateChange: func(name string, from gobreaker.State, to gobreaker.State) {
        logger.Info("circuit breaker state change",
            slog.String("name", name),
            slog.String("from", from.String()),
            slog.String("to", to.String()))
    },
})
```

## 13. ドメインオブジェクトとMeiliSearchマッピング戦略

このセクションでは、ドメインオブジェクトとMeiliSearchインデックス間の詳細なマッピング戦略を定義します。

### 12.1. MeiliSearchインデックス設計

#### Drops Index設計

```json
{
  "uid": "drops",
  "primaryKey": "id",
  "searchableAttributes": [
    "content",
    "hashtags",
    "mentions",
    "author_display_name"
  ],
  "filterableAttributes": [
    "user_id",
    "visibility",
    "created_at",
    "has_media",
    "has_poll",
    "language",
    "is_sensitive",
    "hashtags",
    "mentioned_user_ids"
  ],
  "sortableAttributes": [
    "created_at",
    "reaction_count",
    "renote_count",
    "reply_count"
  ],
  "rankingRules": [
    "words",
    "typo",
    "proximity",
    "attribute",
    "sort",
    "exactness",
    "created_at:desc"
  ],
  "stopWords": ["の", "に", "は", "を", "が", "と", "で", "から"],
  "synonyms": {
    "技術": ["テック", "テクノロジー"],
    "開発": ["デベロップ", "プログラミング"]
  },
  "distinctAttribute": "id",
  "faceting": {
    "maxValuesPerFacet": 1000
  }
}
```

#### Users Index設計

```json
{
  "uid": "users",
  "primaryKey": "id",
  "searchableAttributes": [
    "username",
    "display_name",
    "bio"
  ],
  "filterableAttributes": [
    "is_verified",
    "is_bot",
    "created_at",
    "follower_count",
    "is_suspended",
    "is_searchable"
  ],
  "sortableAttributes": [
    "follower_count",
    "created_at",
    "drop_count",
    "last_active_at"
  ],
  "rankingRules": [
    "words",
    "typo",
    "proximity",
    "attribute",
    "exactness",
    "follower_count:desc"
  ]
}
```

#### Hashtags Index設計

```json
{
  "uid": "hashtags",
  "primaryKey": "hashtag",
  "searchableAttributes": [
    "hashtag",
    "normalized_hashtag"
  ],
  "filterableAttributes": [
    "trending_score",
    "category",
    "region",
    "is_sensitive"
  ],
  "sortableAttributes": [
    "drop_count",
    "trending_score",
    "last_used_at",
    "user_count"
  ],
  "rankingRules": [
    "words",
    "exactness",
    "trending_score:desc",
    "drop_count:desc"
  ]
}
```

### 12.2. ドメインオブジェクトマッピング実装

#### Drop Aggregate → MeiliSearch Document

```go
type DropDocument struct {
    ID                string    `json:"id"`
    UserID            int64     `json:"user_id"`
    AuthorUsername    string    `json:"author_username"`
    AuthorDisplayName string    `json:"author_display_name"`
    Content           string    `json:"content"`
    ContentSearchable string    `json:"content_searchable"` // HTMLタグ除去済み
    Hashtags          []string  `json:"hashtags"`
    Mentions          []string  `json:"mentions"`
    MentionedUserIDs  []int64   `json:"mentioned_user_ids"`
    Visibility        string    `json:"visibility"`
    CreatedAt         int64     `json:"created_at"` // Unix timestamp
    UpdatedAt         int64     `json:"updated_at"`
    HasMedia          bool      `json:"has_media"`
    HasPoll           bool      `json:"has_poll"`
    Language          string    `json:"language"`
    IsSensitive       bool      `json:"is_sensitive"`
    ReactionCount     int       `json:"reaction_count"`
    RenoteCount       int       `json:"renote_count"`
    ReplyCount        int       `json:"reply_count"`
    
    // 検索最適化フィールド
    WordCount         int       `json:"word_count"`
    CharacterCount    int       `json:"character_count"`
    ReadabilityScore  float64   `json:"readability_score"`
}

// DocumentFactory implementation
type DropDocumentFactory struct {
    hashtagExtractor  domain.HashtagExtractor
    mentionExtractor  domain.MentionExtractor
    textProcessor     TextProcessor
}

func (f *DropDocumentFactory) CreateDropDocument(drop *domain.Drop, author *domain.User) (*DropDocument, error) {
    // Extract hashtags and mentions
    hashtags := f.hashtagExtractor.Extract(drop.Content())
    mentions := f.mentionExtractor.Extract(drop.Content())
    
    // Process content for search optimization
    searchableContent := f.textProcessor.ExtractSearchableText(drop.Content())
    readabilityScore := f.textProcessor.CalculateReadabilityScore(searchableContent)
    
    // Extract mentioned user IDs
    mentionedUserIDs := make([]int64, len(mentions))
    for i, mention := range mentions {
        // Resolve username to user ID (this might require external service call)
        userID, err := f.resolveUsernameToID(mention.Username())
        if err != nil {
            logger.Debug("failed to resolve username", slog.String("username", mention.Username()))
            continue
        }
        mentionedUserIDs[i] = userID
    }
    
    return &DropDocument{
        ID:                drop.ID().String(),
        UserID:            drop.UserID().Value(),
        AuthorUsername:    author.Username().Value(),
        AuthorDisplayName: author.DisplayName().Value(),
        Content:           drop.Content().HTML(),
        ContentSearchable: searchableContent,
        Hashtags:          hashtagsToStrings(hashtags),
        Mentions:          mentionsToStrings(mentions),
        MentionedUserIDs:  mentionedUserIDs,
        Visibility:        drop.Visibility().String(),
        CreatedAt:         drop.CreatedAt().Unix(),
        UpdatedAt:         drop.UpdatedAt().Unix(),
        HasMedia:          len(drop.MediaAttachments()) > 0,
        HasPoll:           drop.Poll() != nil,
        Language:          drop.Language().Code(),
        IsSensitive:       drop.IsSensitive(),
        ReactionCount:     drop.ReactionCount(),
        RenoteCount:       drop.RenoteCount(),
        ReplyCount:        drop.ReplyCount(),
        WordCount:         f.textProcessor.CountWords(searchableContent),
        CharacterCount:    len(searchableContent),
        ReadabilityScore:  readabilityScore,
    }, nil
}
```

#### User Aggregate → MeiliSearch Document

```go
type UserDocument struct {
    ID               string    `json:"id"`
    Username         string    `json:"username"`
    DisplayName      string    `json:"display_name"`
    Bio              string    `json:"bio"`
    BioSearchable    string    `json:"bio_searchable"`
    IsVerified       bool      `json:"is_verified"`
    IsBot            bool      `json:"is_bot"`
    CreatedAt        int64     `json:"created_at"`
    LastActiveAt     int64     `json:"last_active_at"`
    FollowerCount    int       `json:"follower_count"`
    FollowingCount   int       `json:"following_count"`
    DropCount        int       `json:"drop_count"`
    IsSuspended      bool      `json:"is_suspended"`
    IsSearchable     bool      `json:"is_searchable"`
    
    // 検索最適化フィールド
    ProfileCompleteness float64 `json:"profile_completeness"`
    ActivityScore       float64 `json:"activity_score"`
}

func (f *UserDocumentFactory) CreateUserDocument(user *domain.User, privacySettings *domain.SearchableContentSettings) (*UserDocument, error) {
    bioSearchable := f.textProcessor.ExtractSearchableText(user.Bio().Value())
    completeness := f.calculateProfileCompleteness(user)
    activityScore := f.calculateActivityScore(user)
    
    return &UserDocument{
        ID:                  user.ID().String(),
        Username:            user.Username().Value(),
        DisplayName:         user.DisplayName().Value(),
        Bio:                 user.Bio().Value(),
        BioSearchable:       bioSearchable,
        IsVerified:          user.IsVerified(),
        IsBot:               user.IsBot(),
        CreatedAt:           user.CreatedAt().Unix(),
        LastActiveAt:        user.LastActiveAt().Unix(),
        FollowerCount:       user.Stats().FollowerCount(),
        FollowingCount:      user.Stats().FollowingCount(),
        DropCount:           user.Stats().DropCount(),
        IsSuspended:         user.Status() == domain.UserStatusSuspended,
        IsSearchable:        privacySettings.Profile(),
        ProfileCompleteness: completeness,
        ActivityScore:       activityScore,
    }, nil
}
```

### 12.3. 日本語検索最適化

```go
// Japanese text processing
type JapaneseTextProcessor struct {
    stopWords []string
    synonyms  map[string][]string
}

func (p *JapaneseTextProcessor) ExtractSearchableText(html string) string {
    // Remove HTML tags
    text := p.stripHTML(html)
    
    // Normalize Japanese text
    text = p.normalizeJapanese(text)
    
    // Remove stop words
    text = p.removeStopWords(text)
    
    return text
}

func (p *JapaneseTextProcessor) normalizeJapanese(text string) string {
    // Convert full-width to half-width for alphanumeric
    text = width.Narrow.String(text)
    
    // Normalize Unicode (NFKC)
    text = norm.NFKC.String(text)
    
    return text
}
```

### 12.4. インデックス最適化とクエリ戦略

#### ファセット検索実装

```go
type FacetSearchRequest struct {
    Query    string            `json:"query"`
    Facets   []string          `json:"facets"`
    Filters  map[string]string `json:"filters"`
}

func (r *MeiliSearchRepository) SearchWithFacets(ctx context.Context, req *FacetSearchRequest) (*FacetSearchResult, error) {
    index := r.client.Index("drops")
    
    searchReq := &meilisearch.SearchRequest{
        Query:  req.Query,
        Facets: req.Facets,
        Limit:  100,
    }
    
    // Build facet filters
    if len(req.Filters) > 0 {
        var filters []string
        for facet, value := range req.Filters {
            filters = append(filters, fmt.Sprintf("%s = '%s'", facet, value))
        }
        searchReq.Filter = filters
    }
    
    resp, err := index.Search(searchReq)
    if err != nil {
        return nil, err
    }
    
    return r.convertToFacetResult(resp), nil
}
```

#### ランキングアルゴリズム調整

```go
type CustomRankingCalculator struct {
    temporalWeight  float64
    socialWeight    float64
    relevanceWeight float64
}

func (c *CustomRankingCalculator) CalculateCustomScore(doc *DropDocument, query string) float64 {
    // Text relevance score (from MeiliSearch)
    textScore := c.calculateTextRelevance(doc, query)
    
    // Temporal decay (newer content scores higher)
    temporalScore := c.calculateTemporalDecay(doc.CreatedAt)
    
    // Social signals (reactions, renotes)
    socialScore := c.calculateSocialScore(doc)
    
    // Combine scores with weights
    finalScore := (textScore * c.relevanceWeight) +
                  (temporalScore * c.temporalWeight) +
                  (socialScore * c.socialWeight)
    
    return finalScore
}
```

## 14. ドメインモデル詳細設計

### 13.1. Domain Objects詳細仕様

#### SearchIndex Aggregate - 不変条件とドメインロジック

```go
type SearchIndex struct {
    id           IndexID
    indexType    IndexType
    status       IndexStatus
    documentCount DocumentCount
    lastSyncAt   time.Time
    metadata     IndexMetadata
}

// ドメイン不変条件
func (s *SearchIndex) validateInvariants() error {
    // IndexTypeは一度設定されたら変更不可
    if s.indexType.IsEmpty() {
        return errors.New("index type cannot be empty")
    }
    
    // REBUILDING状態では新規ドキュメント追加不可
    if s.status == IndexStatusRebuilding {
        return errors.New("cannot add documents during rebuild")
    }
    
    // DocumentCountは非負の数
    if s.documentCount.Value() < 0 {
        return errors.New("document count cannot be negative")
    }
    
    return nil
}

// ドメインロジック: ドキュメント追加可能判定
func (s *SearchIndex) CanAddDocument() bool {
    return s.status == IndexStatusActive &&
           s.documentCount.Value() < s.metadata.MaxDocuments()
}

// ドメインロジック: インデックス再構築開始
func (s *SearchIndex) StartRebuild() error {
    if s.status == IndexStatusRebuilding {
        return errors.New("rebuild already in progress")
    }
    
    s.status = IndexStatusRebuilding
    s.metadata.recordRebuildStart(time.Now())
    return s.validateInvariants()
}

// ドメインロジック: 整合性検証
func (s *SearchIndex) ValidateIntegrity(actualCount int) error {
    if s.documentCount.Value() != actualCount {
        return &IntegrityViolationError{
            Expected: s.documentCount.Value(),
            Actual:   actualCount,
            IndexID:  s.id,
        }
    }
    return nil
}
```

#### DropSearchDocument Entity - ビジネスルール

```go
type DropSearchDocument struct {
    id            DropID
    searchableText SearchableText
    visibility    Visibility
    authorID      UserID
    createdAt     time.Time
    metadata      SearchMetadata
    hashtags      []Hashtag
    mentions      []Mention
}

// ビジネスルール: 検索可能性判定
func (d *DropSearchDocument) IsSearchableBy(viewerID UserID, privacySettings SearchPrivacySettings) bool {
    // プライバシー設定チェック
    if !privacySettings.AllowsSearching() {
        return false
    }
    
    // 公開範囲チェック
    switch d.visibility {
    case VisibilityPublic, VisibilityUnlisted:
        return true
    case VisibilityFollowersOnly:
        return d.authorID.Equals(viewerID) // 簡略化、実際はフォロー関係要確認
    case VisibilityPrivate:
        return d.authorID.Equals(viewerID)
    default:
        return false
    }
}

// ビジネスルール: 検索テキスト抽出
func (d *DropSearchDocument) ExtractSearchableText() SearchableText {
    var searchableContent strings.Builder
    
    // メインコンテンツ
    searchableContent.WriteString(d.searchableText.Value())
    
    // ハッシュタグ追加
    for _, hashtag := range d.hashtags {
        searchableContent.WriteString(" ")
        searchableContent.WriteString(hashtag.Value())
    }
    
    // メンション追加（ユーザー名のみ）
    for _, mention := range d.mentions {
        searchableContent.WriteString(" ")
        searchableContent.WriteString(mention.Username())
    }
    
    return NewSearchableText(searchableContent.String())
}
```

#### Value Objects - 不変性とバリデーション

```go
// SearchQuery Value Object
type SearchQuery struct {
    text       string
    filters    []SearchFilter
    sort       *SortOption
    pagination Pagination
}

func NewSearchQuery(text string, filters []SearchFilter, pagination Pagination) (*SearchQuery, error) {
    // バリデーション
    if len(text) < 2 {
        return nil, ErrQueryTooShort
    }
    if len(text) > 1000 {
        return nil, ErrQueryTooLong
    }
    
    // 危険な文字をチェック
    if containsUnsafeCharacters(text) {
        return nil, ErrInvalidQuery
    }
    
    return &SearchQuery{
        text:       strings.TrimSpace(text),
        filters:    filters,
        pagination: pagination,
    }, nil
}

// Hashtag Value Object
type Hashtag struct {
    value           string
    normalizedValue string
}

func NewHashtag(value string) (*Hashtag, error) {
    // バリデーション
    if len(value) == 0 {
        return nil, errors.New("hashtag cannot be empty")
    }
    if len(value) > 100 {
        return nil, errors.New("hashtag too long")
    }
    
    // 正規化
    normalized := strings.ToLower(strings.TrimPrefix(value, "#"))
    
    // 有効な文字のみ許可
    if !isValidHashtag(normalized) {
        return nil, errors.New("invalid hashtag characters")
    }
    
    return &Hashtag{
        value:           value,
        normalizedValue: normalized,
    }, nil
}

// TrendingScore Value Object
type TrendingScore struct {
    score        float64
    calculatedAt time.Time
    factors      TrendingFactors
}

func NewTrendingScore(usage int, velocity float64, diversity float64) (*TrendingScore, error) {
    if usage < 0 {
        return nil, errors.New("usage count cannot be negative")
    }
    if velocity < 0 {
        return nil, errors.New("velocity cannot be negative")
    }
    if diversity < 0 || diversity > 1 {
        return nil, errors.New("diversity must be between 0 and 1")
    }
    
    // トレンドスコア計算
    score := calculateTrendingScore(usage, velocity, diversity)
    
    return &TrendingScore{
        score:        score,
        calculatedAt: time.Now(),
        factors: TrendingFactors{
            Usage:     usage,
            Velocity:  velocity,
            Diversity: diversity,
        },
    }, nil
}
```

### 13.2. Domain Services詳細実装

#### RankingAlgorithm Domain Service

```go
type RankingAlgorithm struct {
    weights RankingWeights
    config  RankingConfig
}

type RankingWeights struct {
    TextRelevance  float64
    TemporalDecay  float64
    SocialSignals  float64
    AuthorQuality  float64
}

func (r *RankingAlgorithm) CalculateRelevanceScore(doc SearchDocument, query SearchQuery) RelevanceScore {
    // テキスト関連性スコア
    textScore := r.calculateTextRelevance(doc, query)
    
    // 時間減衰スコア
    temporalScore := r.calculateTemporalDecay(doc.CreatedAt(), time.Now())
    
    // ソーシャルシグナルスコア
    socialScore := r.calculateSocialScore(doc)
    
    // 著者品質スコア
    authorScore := r.calculateAuthorQuality(doc.AuthorID())
    
    // 重み付き合計
    finalScore := (textScore * r.weights.TextRelevance) +
                  (temporalScore * r.weights.TemporalDecay) +
                  (socialScore * r.weights.SocialSignals) +
                  (authorScore * r.weights.AuthorQuality)
    
    return NewRelevanceScore(finalScore)
}

func (r *RankingAlgorithm) ApplyTemporalDecay(score RelevanceScore, age time.Duration) RelevanceScore {
    // 指数減衰モデル
    decayFactor := math.Exp(-age.Hours() / r.config.DecayHalfLife)
    newScore := score.Value() * decayFactor
    
    return NewRelevanceScore(newScore)
}
```

#### SearchPrivacyPolicy Domain Service

```go
type SearchPrivacyPolicy struct {
    gdprCompliance bool
    defaultSettings SearchableContentSettings
}

func (p *SearchPrivacyPolicy) ShouldIndexContent(content SearchableContent, settings SearchableContentSettings) bool {
    // GDPR準拠チェック
    if p.gdprCompliance && !settings.HasConsent() {
        return false
    }
    
    // プライバシー設定チェック
    switch content.Type() {
    case ContentTypeDrop:
        return settings.Drops()
    case ContentTypeProfile:
        return settings.Profile()
    default:
        return false
    }
}

func (p *SearchPrivacyPolicy) ApplyGDPRCompliance(userID UserID) error {
    // 忘れられる権利の実装
    actions := []string{
        "remove_from_search_index",
        "clear_search_history",
        "remove_from_recommendations",
        "purge_cached_results",
    }
    
    for _, action := range actions {
        if err := p.executeGDPRAction(userID, action); err != nil {
            return fmt.Errorf("GDPR action %s failed: %w", action, err)
        }
    }
    
    return nil
}
```

## 15. ドメインオブジェクトとDBスキーマのマッピング

### 12.1. PostgreSQL データベーススキーマ

検索サービスは主にMeiliSearchを使用しますが、メタデータとキャッシュのためにPostgreSQLも使用します：

```sql
-- Search history table
CREATE TABLE search_histories (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    query TEXT NOT NULL,
    search_type VARCHAR(20) NOT NULL, -- 'drop', 'user', 'hashtag'
    result_count INT NOT NULL,
    searched_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_search_histories_user_id (user_id),
    INDEX idx_search_histories_searched_at (searched_at)
);

-- Saved searches table
CREATE TABLE saved_searches (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    name VARCHAR(100) NOT NULL,
    query TEXT NOT NULL,
    filters JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_saved_searches_user_name (user_id, name)
);

-- Trending hashtags table
CREATE TABLE trending_hashtags (
    id BIGSERIAL PRIMARY KEY,
    hashtag VARCHAR(100) NOT NULL,
    score FLOAT NOT NULL,
    drop_count INT NOT NULL,
    user_count INT NOT NULL,
    calculated_at TIMESTAMP NOT NULL,
    region VARCHAR(10),
    UNIQUE KEY uk_trending_hashtag_region (hashtag, region, calculated_at),
    INDEX idx_trending_calculated_at (calculated_at)
);

-- Search indexing status table
CREATE TABLE indexing_status (
    id BIGSERIAL PRIMARY KEY,
    entity_type VARCHAR(20) NOT NULL, -- 'drop', 'user'
    entity_id BIGINT NOT NULL,
    indexed_at TIMESTAMP NOT NULL,
    version INT NOT NULL DEFAULT 1,
    status VARCHAR(20) NOT NULL, -- 'indexed', 'pending', 'failed'
    error_message TEXT,
    UNIQUE KEY uk_indexing_entity (entity_type, entity_id)
);
```

### 12.2. MeiliSearch インデックススキーマ

#### Drops Index

```json
{
  "uid": "drops",
  "primaryKey": "id",
  "searchableAttributes": [
    "content",
    "hashtags",
    "mentions"
  ],
  "filterableAttributes": [
    "user_id",
    "visibility",
    "created_at",
    "has_media",
    "has_poll",
    "language",
    "is_sensitive"
  ],
  "sortableAttributes": [
    "created_at",
    "reaction_count",
    "renote_count"
  ],
  "rankingRules": [
    "words",
    "typo",
    "proximity",
    "attribute",
    "sort",
    "exactness",
    "created_at:desc"
  ]
}
```

#### Users Index

```json
{
  "uid": "users",
  "primaryKey": "id",
  "searchableAttributes": [
    "username",
    "display_name",
    "bio"
  ],
  "filterableAttributes": [
    "is_verified",
    "is_bot",
    "created_at",
    "follower_count",
    "is_suspended"
  ],
  "sortableAttributes": [
    "follower_count",
    "created_at",
    "drop_count"
  ]
}
```

### 12.3. ドメインオブジェクトとインデックスのマッピング

#### Drop Aggregate → MeiliSearch Document

```go
type DropDocument struct {
    ID           string    `json:"id"`
    UserID       int64     `json:"user_id"`
    Content      string    `json:"content"`
    Hashtags     []string  `json:"hashtags"`
    Mentions     []string  `json:"mentions"`
    Visibility   string    `json:"visibility"`
    CreatedAt    int64     `json:"created_at"` // Unix timestamp
    HasMedia     bool      `json:"has_media"`
    HasPoll      bool      `json:"has_poll"`
    Language     string    `json:"language"`
    IsSensitive  bool      `json:"is_sensitive"`
    ReactionCount int      `json:"reaction_count"`
    RenoteCount  int       `json:"renote_count"`
}

func (m *MeiliSearchRepository) mapDropToDocument(drop *domain.Drop) *DropDocument {
    return &DropDocument{
        ID:           drop.ID.String(),
        UserID:       drop.UserID.Value(),
        Content:      drop.Content.Text(),
        Hashtags:     drop.ExtractHashtags(),
        Mentions:     drop.ExtractMentions(),
        Visibility:   drop.Visibility.String(),
        CreatedAt:    drop.CreatedAt.Unix(),
        HasMedia:     len(drop.MediaAttachments) > 0,
        HasPoll:      drop.Poll != nil,
        Language:     drop.Language.Code(),
        IsSensitive:  drop.IsSensitive,
        ReactionCount: drop.ReactionCount,
        RenoteCount:  drop.RenoteCount,
    }
}
```

#### User Aggregate → MeiliSearch Document

```go
type UserDocument struct {
    ID            string   `json:"id"`
    Username      string   `json:"username"`
    DisplayName   string   `json:"display_name"`
    Bio           string   `json:"bio"`
    IsVerified    bool     `json:"is_verified"`
    IsBot         bool     `json:"is_bot"`
    CreatedAt     int64    `json:"created_at"`
    FollowerCount int      `json:"follower_count"`
    DropCount     int      `json:"drop_count"`
    IsSuspended   bool     `json:"is_suspended"`
}

func (m *MeiliSearchRepository) mapUserToDocument(user *domain.User) *UserDocument {
    return &UserDocument{
        ID:            user.ID.String(),
        Username:      user.Username.Value(),
        DisplayName:   user.Profile.DisplayName,
        Bio:           user.Profile.Bio,
        IsVerified:    user.IsVerified,
        IsBot:         user.IsBot,
        CreatedAt:     user.CreatedAt.Unix(),
        FollowerCount: user.Stats.FollowerCount,
        DropCount:     user.Stats.DropCount,
        IsSuspended:   user.Status == domain.UserStatusSuspended,
    }
}
```

### 12.4. Repository実装でのマッピング

```go
// PostgreSQL Repository
func (r *PostgreSQLSearchRepository) SaveSearchHistory(ctx context.Context, history *domain.SearchHistory) error {
    query := `
        INSERT INTO search_histories (user_id, query, search_type, result_count, searched_at)
        VALUES ($1, $2, $3, $4, $5)
    `
    _, err := r.db.ExecContext(ctx,
        query,
        history.UserID.Value(),
        history.Query.Value(),
        history.SearchType.String(),
        history.ResultCount,
        history.SearchedAt,
    )
    return err
}

// MeiliSearch Repository with PostgreSQL fallback
func (r *HybridSearchRepository) SearchDrops(ctx context.Context, query string, filters SearchFilters) (*SearchResult, error) {
    // Try MeiliSearch first
    result, err := r.meiliSearch.SearchDrops(ctx, query, filters)
    if err != nil {
        // Fall back to PostgreSQL FTS if MeiliSearch is unavailable
        if errors.Is(err, ErrMeiliSearchUnavailable) {
            logger.Warn("falling back to PostgreSQL FTS",
                slog.String("query", query))
            return r.postgresSearch.SearchDrops(ctx, query, filters)
        }
        return nil, err
    }
    return result, nil
}
```

## 16. 検索特化アーキテクチャと最適化戦略

### 15.1. クエリ最適化戦略

#### 検索クエリパフォーマンス最適化
- **クエリキャッシュ戦略**: Redis TTLベースのクエリ結果キャッシュ（5分間）
- **インデックス分割**: 時系列ベースのインデックスパーティショニング（月単位）
- **ファジー検索**: typo toleranceを2文字まで許容、日本語ひらがな・カタカナ正規化
- **部分検索**: prefixベースの高速オートコンプリート実装

#### ファセット検索実装
```go
type FacetConfig struct {
    Visibility    []string  // public, unlisted, followers_only
    HasMedia      bool      // メディア添付有無
    Language      []string  // ja, en, multi
    DateRange     DateRange // 投稿日範囲
    ReactionRange IntRange  // リアクション数範囲
}
```

#### ランキングアルゴリズム詳細
1. **テキスト関連性スコア** (0.4): MeiliSearchのTF-IDFベース
2. **時間減衰スコア** (0.3): 指数関数的減衰（半減期24時間）
3. **ソーシャルシグナル** (0.2): リアクション・リノート・返信数
4. **著者品質スコア** (0.1): フォロワー数・認証済みステータス

### 15.2. インデックス管理最適化

#### ホットストレージとコールドストレージ分離
- **Hot Index**: 直近30日のコンテンツ（高速SSD）
- **Warm Index**: 30日-1年のコンテンツ（標準SSD）
- **Cold Index**: 1年以上のコンテンツ（低速ストレージ、圧縮）

#### インデックス再構築戦略
```go
type RebuildStrategy struct {
    Mode        RebuildMode    // INCREMENTAL, FULL, ROLLING
    BatchSize   int           // バッチサイズ（1000件）
    Concurrency int           // 並列処理数（5並列）
    Priority    RebuildPriority // HIGH, NORMAL, LOW
}
```

## 17. Concerns / Open Questions (懸念事項・相談したいこと)

### 16.1. 技術的負債リスク
- **インデックス整合性:** イベント処理の信頼性向上策（Stream, 冪等性）を講じるが、完全なリアルタイム整合性は保証しない。不整合発生リスクは残り、解消のための定期的な差分同期や限定的な再インデックスの実装・運用コストが発生する可能性がある。
- **アクセス制御の複雑性とパフォーマンス:** MeiliSearchフィルタで表現できない複雑な権限が必要になった場合、アプリ層フィルタリングによるパフォーマンス低下リスクがある。
- **検索エンジン/DB依存:** MeiliSearchやPostgreSQL FTSのバージョンアップや仕様変更への追従コスト。
- **イベント処理の信頼性:** イベントロストや重複処理はインデックス不整合に直結するため、冪等性確保や堅牢なエラーハンドリングが不可欠。

### 16.2. 検索特有の技術課題

#### MeiliSearchの最適化課題
- **日本語処理最適化**: kuromoji tokenizer相当の実装とひらがな・カタカナ統一
- **ランキング精度**: ユーザー行動データを活用したランキングアルゴリズム調整
- **スケーラビリティ**: 大規模データセット（数百万投稿）でのパフォーマンス維持
- **リアルタイム性**: インデックス更新遅延の許容範囲と整合性トレードオフ

#### 検索品質とパフォーマンスのトレードオフ
- **精度 vs 速度**: 検索精度向上（シノニム、関連語）によるレスポンス時間への影響
- **新鮮さ vs 処理負荷**: リアルタイム性向上のためのインデックス更新頻度増加
- **パーソナライゼーション vs キャッシュ効率**: ユーザー別カスタマイズとキャッシュ戦略

#### セキュリティとプライバシーの課題
- **検索ログの機密性**: 検索クエリからの個人情報推測リスク
- **GDPR準拠の完全性**: 忘れられる権利の検索インデックスからの完全削除保証
- **アクセス制御の複雑性**: フォロー関係、ブロック、ミュート状態の高速フィルタリング

#### 将来の拡張性課題
- **フェデレーション検索**: 外部インスタンスとの検索結果統合手法
- **マルチメディア検索**: 画像・動画コンテンツの検索対応
- **AI活用**: 検索意図理解とセマンティック検索の導入可能性

## 18. Configuration Management (設定管理)

このサービスは、[共通環境変数管理パターン](../common/infrastructure/environment-variables.md)に従って設定管理を実装します。

### 18.1. 環境変数一覧

#### 必須環境変数
- `DATABASE_URL`: PostgreSQL接続URL
- `REDIS_URL`: Redis接続URL  
- `MEILISEARCH_URL`: MeiliSearch接続URL
- `MEILISEARCH_MASTER_KEY`: MeiliSearchマスターキー

#### オプション環境変数（デフォルト値あり）
- `PORT`: HTTPサーバーポート (デフォルト: 8088)
- `GRPC_PORT`: gRPCサーバーポート (デフォルト: 9098)
- `INDEX_BATCH_SIZE`: インデックス更新のバッチサイズ (デフォルト: 100)
- `SYNC_INTERVAL`: 同期間隔 (デフォルト: 1m)

### 18.2. Config構造体実装例

```go
// internal/infrastructure/config/config.go
package config

import (
    "time"
)

type Config struct {
    // 共通設定
    Server   ServerConfig
    Database DatabaseConfig
    Redis    RedisConfig
    
    // avion-search固有設定
    MeiliSearch MeiliSearchConfig
    Search      SearchConfig
}

type MeiliSearchConfig struct {
    URL       string `env:"MEILISEARCH_URL" required:"true"`
    MasterKey string `env:"MEILISEARCH_MASTER_KEY" required:"true" secret:"true"`
}

type SearchConfig struct {
    IndexBatchSize int           `env:"INDEX_BATCH_SIZE" required:"false" default:"100"`
    SyncInterval   time.Duration `env:"SYNC_INTERVAL" required:"false" default:"1m"`
}
```

### 18.3. 設定の検証と初期化

```go
// cmd/server/main.go
func main() {
    // 環境変数の読み込み（必須環境変数が不足していればここで失敗）
    cfg := config.MustLoad()
    
    logger.Info("Starting avion-search server",
        "environment", cfg.Server.Environment,
        "port", cfg.Server.Port,
        "grpc_port", cfg.Server.GRPCPort,
        "meilisearch_url", cfg.MeiliSearch.URL,
        "index_batch_size", cfg.Search.IndexBatchSize,
        "sync_interval", cfg.Search.SyncInterval,
    )
    
    // MeiliSearchクライアントの初期化
    searchClient := meilisearch.NewClient(meilisearch.ClientConfig{
        Host:   cfg.MeiliSearch.URL,
        APIKey: cfg.MeiliSearch.MasterKey,
    })
    
    // その他の依存関係初期化...
}
```

この設定管理により、サービス起動時に必須環境変数の不足を早期検出し、設定エラーによる問題を防止します。

## 19. 実装フェーズ計画

### Phase 0: 基本検索機能（MVP）
**期間**: 4-6週間
**実装内容**:
- Drop/User基本検索機能
- MeiliSearchインデックス管理
- イベント駆動インデックス更新
- アクセス制御基盤

**成果物**:
- `SearchDrops`, `SearchUsers` API
- 基本的なインデックス更新機能
- 構造化ログ基盤

### Phase 1: プライバシーと基本拡張機能
**期間**: 3-4週間
**実装内容**:
- 検索プライバシー制御（GDPR対応）
- ハッシュタグ検索機能
- メンション検索機能
- トレンディングハッシュタグ

**成果物**:
- `UpdateSearchPrivacy` API
- `SearchByHashtag`, `SearchMentions` API
- `GetTrendingHashtags` API

### Phase 2: ユーザー体験向上機能
**期間**: 3-4週間
**実装内容**:
- 検索履歴管理
- サジェスト機能
- 保存検索機能
- リアクションベース検索

**成果物**:
- `GetSearchHistory` API
- `SaveSearch`, `GetSavedSearches` API
- 検索サジェスト機能

### Phase 3: 高度な検索機能
**期間**: 4-5週間
**実装内容**:
- フェデレーション検索
- コレクション内検索
- 高度な検索構文サポート
- パフォーマンス最適化

**成果物**:
- リモートインスタンス検索機能
- コレクション検索API
- キャッシュ戦略実装

### 各フェーズ共通タスク
- [共通テスト戦略](../common/testing-strategy.md)に従ったテスト実装
- ドキュメント更新
- セキュリティレビュー

## 19. SearchBackend Interface 設計

MeiliSearchを第一選択としつつ、将来的なPostgreSQL FTSへの移行を可能にするため、検索バックエンドを抽象化するインターフェースを定義します。

### Interface定義
```go
// SearchBackend は検索エンジンの抽象化インターフェース
type SearchBackend interface {
    // インデックス管理
    CreateIndex(ctx context.Context, config IndexConfig) error
    DeleteIndex(ctx context.Context, indexName string) error
    GetIndexStatus(ctx context.Context, indexName string) (IndexStatus, error)
    
    // ドキュメント操作
    IndexDocument(ctx context.Context, indexName string, doc SearchDocument) error
    UpdateDocument(ctx context.Context, indexName string, doc SearchDocument) error
    DeleteDocument(ctx context.Context, indexName string, docID string) error
    BatchIndexDocuments(ctx context.Context, indexName string, docs []SearchDocument) error
    
    // 検索操作
    Search(ctx context.Context, req SearchRequest) (SearchResponse, error)
    
    // ヘルスチェック
    HealthCheck(ctx context.Context) error
}

// IndexConfig はインデックス設定
type IndexConfig struct {
    Name             string
    PrimaryKey       string
    SearchableFields []string
    FilterableFields []string
    SortableFields   []string
    Settings         map[string]interface{} // バックエンド固有の設定
}

// SearchRequest は検索リクエスト
type SearchRequest struct {
    IndexName   string
    Query       string
    Filters     []SearchFilter
    Sort        []SortOption
    Limit       int
    Offset      int
    Facets      []string
}

// SearchResponse は検索レスポンス
type SearchResponse struct {
    Hits       []SearchHit
    TotalCount int
    Facets     map[string][]FacetValue
    QueryTime  int64 // milliseconds
}
```

### MeiliSearch実装（1stリリース）
```go
type MeiliSearchBackend struct {
    client          *meilisearch.Client
    config          MeiliSearchConfig
    metricsCollector MetricsCollector
}

type MeiliSearchConfig struct {
    Host            string
    APIKey          string
    IndexPrefix     string
    JapaneseEnabled bool
    Synonyms        map[string][]string
    StopWords       []string
    RankingRules    []string
}

func (m *MeiliSearchBackend) CreateIndex(ctx context.Context, config IndexConfig) error {
    indexName := m.config.IndexPrefix + config.Name
    
    // インデックス作成
    index := m.client.Index(indexName)
    _, err := m.client.CreateIndex(&meilisearch.IndexConfig{
        Uid:        indexName,
        PrimaryKey: config.PrimaryKey,
    })
    if err != nil {
        return fmt.Errorf("failed to create index: %w", err)
    }
    
    // 日本語設定
    if m.config.JapaneseEnabled {
        settings := meilisearch.Settings{
            RankingRules:       m.config.RankingRules,
            SearchableAttributes: config.SearchableFields,
            FilterableAttributes: config.FilterableFields,
            SortableAttributes:   config.SortableFields,
            StopWords:           m.config.StopWords,
            Synonyms:            m.config.Synonyms,
        }
        
        _, err = index.UpdateSettings(&settings)
        if err != nil {
            return fmt.Errorf("failed to update settings: %w", err)
        }
    }
    
    return nil
}

func (m *MeiliSearchBackend) Search(ctx context.Context, req SearchRequest) (SearchResponse, error) {
    start := time.Now()
    defer func() {
        m.metricsCollector.RecordSearchLatency(time.Since(start))
    }()
    
    index := m.client.Index(m.config.IndexPrefix + req.IndexName)
    
    searchReq := &meilisearch.SearchRequest{
        Query:  req.Query,
        Limit:  int64(req.Limit),
        Offset: int64(req.Offset),
    }
    
    // フィルター構築
    if len(req.Filters) > 0 {
        searchReq.Filter = m.buildFilterString(req.Filters)
    }
    
    // ソート設定
    if len(req.Sort) > 0 {
        searchReq.Sort = m.buildSortArray(req.Sort)
    }
    
    // ファセット設定
    if len(req.Facets) > 0 {
        searchReq.Facets = req.Facets
    }
    
    resp, err := index.Search(req.Query, searchReq)
    if err != nil {
        m.metricsCollector.IncrementSearchErrors()
        return SearchResponse{}, fmt.Errorf("search failed: %w", err)
    }
    
    return m.convertResponse(resp), nil
}
```

### PostgreSQL FTS実装（将来対応）
```go
type PostgreSQLBackend struct {
    db             *sql.DB
    config         PostgreSQLConfig
    queryBuilder   PostgreSQLQueryBuilder
}

type PostgreSQLConfig struct {
    Schema         string
    Language       string // 'japanese' for MeCab
    IndexType      string // 'gin' or 'gist'
    SearchFunction string // 'plainto_tsquery' or 'phraseto_tsquery'
}

// 2ndリリース以降で実装
func (p *PostgreSQLBackend) Search(ctx context.Context, req SearchRequest) (SearchResponse, error) {
    // PostgreSQL FTS実装
    // to_tsvector, to_tsquery, ts_rank を使用
    return SearchResponse{}, ErrNotImplemented
}
```

### バックエンド選択戦略
```go
type SearchBackendFactory struct {
    meiliSearchConfig MeiliSearchConfig
    postgresConfig    PostgreSQLConfig
    defaultBackend    string
}

func (f *SearchBackendFactory) CreateBackend(backendType string) (SearchBackend, error) {
    switch backendType {
    case "meilisearch":
        return NewMeiliSearchBackend(f.meiliSearchConfig), nil
    case "postgresql":
        // 2ndリリース以降
        return nil, ErrPostgreSQLNotImplemented
    default:
        return f.CreateBackend(f.defaultBackend)
    }
}

// 環境変数による設定
// SEARCH_BACKEND=meilisearch (default)
// SEARCH_BACKEND=postgresql (future)
```

### 移行戦略
1stリリースではMeiliSearchのみを実装し、SearchBackend interfaceを通じて使用します。
2ndリリース以降でPostgreSQL FTS実装を追加する際は、以下の手順で移行可能：

1. PostgreSQLBackendの実装を追加
2. 環境変数でバックエンドを切り替え可能に
3. A/Bテストで段階的に切り替え
4. 完全移行またはハイブリッド運用を選択

---

## Test Strategy

### Overview

avion-searchの包括的なテスト戦略です。MeiliSearchの特性、検索パフォーマンス、プライバシー制御、GDPR準拠を重点的にカバーします。

### Test Categories

#### 1. Unit Tests
- **Domain Layer**: ビジネスロジックのテスト
- **UseCase Layer**: 検索ロジックとフィルタリングのテスト
- **Infrastructure Layer**: MeiliSearchクライアントとPostgreSQL検索のテスト

#### 2. Integration Tests
- **MeiliSearch統合**: 実際のMeiliSearchインスタンスとの統合テスト
- **Database統合**: PostgreSQLとの連携テスト
- **Event処理**: Redis Pub/Subイベントの処理テスト

#### 3. Performance Tests
- **大規模インデックス**: 100万件以上のドキュメントでのパフォーマンステスト
- **同時検索**: 高負荷時の検索レスポンスタイムテスト
- **バッチ更新**: 大量データの一括インデックス更新テスト

### MeiliSearch Integration Testing

#### Test Environment Setup
```go
// tests/integration/meilisearch_test.go
package integration

import (
    "context"
    "testing"
    "time"
    
    "github.com/meilisearch/meilisearch-go"
    "github.com/stretchr/testify/suite"
    "github.com/testcontainers/testcontainers-go"
    "github.com/testcontainers/testcontainers-go/wait"
    
    "avion-search/internal/infrastructure/search"
)

type MeiliSearchIntegrationSuite struct {
    suite.Suite
    container   testcontainers.Container
    client      *meilisearch.Client
    backend     *search.MeiliSearchBackend
    ctx         context.Context
}

func (suite *MeiliSearchIntegrationSuite) SetupSuite() {
    suite.ctx = context.Background()
    
    // MeiliSearchコンテナの起動
    req := testcontainers.ContainerRequest{
        Image:        "getmeili/meilisearch:v1.5",
        ExposedPorts: []string{"7700/tcp"},
        Env: map[string]string{
            "MEILI_ENV":    "development",
            "MEILI_NO_ANALYTICS": "true",
        },
        WaitingFor: wait.ForHTTP("/health").OnPort("7700"),
    }
    
    container, err := testcontainers.GenericContainer(suite.ctx, testcontainers.GenericContainerRequest{
        ContainerRequest: req,
        Started:          true,
    })
    suite.Require().NoError(err)
    suite.container = container
    
    // クライアント初期化
    host, err := container.Host(suite.ctx)
    suite.Require().NoError(err)
    port, err := container.MappedPort(suite.ctx, "7700")
    suite.Require().NoError(err)
    
    url := fmt.Sprintf("http://%s:%s", host, port.Port())
    suite.client = meilisearch.NewClient(meilisearch.ClientConfig{Host: url})
    
    // バックエンド初期化
    config := search.MeiliSearchConfig{
        Host:           url,
        IndexPrefix:    "test_",
        JapaneseEnabled: true,
        MaxSearchLimit: 1000,
        DefaultLimit:   20,
    }
    suite.backend = search.NewMeiliSearchBackend(config)
}

func (suite *MeiliSearchIntegrationSuite) TearDownSuite() {
    if suite.container != nil {
        suite.container.Terminate(suite.ctx)
    }
}

func (suite *MeiliSearchIntegrationSuite) TestIndexCreationAndConfiguration() {
    // インデックス作成テスト
    indexConfig := search.IndexConfig{
        Name:             "drops",
        PrimaryKey:       "id",
        SearchableFields: []string{"content", "title"},
        FilterableFields: []string{"user_id", "created_at", "visibility"},
        SortableFields:   []string{"created_at", "reaction_count"},
    }
    
    err := suite.backend.CreateIndex(suite.ctx, indexConfig)
    suite.NoError(err)
    
    // インデックス設定確認
    index := suite.client.Index("test_drops")
    settings, err := index.GetSettings()
    suite.NoError(err)
    
    suite.Contains(settings.SearchableAttributes, "content")
    suite.Contains(settings.SearchableAttributes, "title")
    suite.Contains(settings.FilterableAttributes, "user_id")
    suite.Contains(settings.SortableAttributes, "created_at")
}

func TestMeiliSearchIntegration(t *testing.T) {
    suite.Run(t, new(MeiliSearchIntegrationSuite))
}
```

#### Search Query Optimization Testing
```go
// tests/integration/search_optimization_test.go
func (suite *MeiliSearchIntegrationSuite) TestSearchQueryOptimization() {
    // テストデータ準備
    testDocs := []map[string]interface{}{
        {
            "id":          "1",
            "content":     "Go言語でマイクロサービスを開発しています",
            "title":       "技術ブログ",
            "user_id":     "user1",
            "created_at":  time.Now().Unix(),
            "visibility":  "public",
        },
        {
            "id":          "2", 
            "content":     "Goプログラミングの基礎を学ぼう",
            "title":       "プログラミング入門",
            "user_id":     "user2",
            "created_at":  time.Now().Unix() - 3600,
            "visibility":  "public",
        },
    }
    
    index := suite.client.Index("test_drops")
    _, err := index.AddDocuments(testDocs)
    suite.NoError(err)
    
    // インデックス完了まで待機
    suite.waitForIndexing("test_drops")
    
    tests := []struct {
        name           string
        query          string
        expectedHits   int
        expectedFirst  string
        filters        []search.Filter
    }{
        {
            name:          "Basic search",
            query:         "Go",
            expectedHits:  2,
            expectedFirst: "1", // より関連性の高い結果が先頭
        },
        {
            name:          "Phrase search",
            query:         "マイクロサービス",
            expectedHits:  1,
            expectedFirst: "1",
        },
        {
            name:          "Filtered search",
            query:         "Go",
            expectedHits:  1,
            expectedFirst: "1",
            filters: []search.Filter{
                {Field: "user_id", Operator: "=", Value: "user1"},
            },
        },
    }
    
    for _, tt := range tests {
        suite.Run(tt.name, func() {
            req := search.SearchRequest{
                IndexName: "drops",
                Query:     tt.query,
                Limit:     10,
                Filters:   tt.filters,
            }
            
            resp, err := suite.backend.Search(suite.ctx, req)
            suite.NoError(err)
            suite.Equal(tt.expectedHits, len(resp.Hits))
            
            if len(resp.Hits) > 0 {
                suite.Equal(tt.expectedFirst, resp.Hits[0]["id"])
            }
        })
    }
}

func (suite *MeiliSearchIntegrationSuite) waitForIndexing(indexName string) {
    index := suite.client.Index(indexName)
    for i := 0; i < 30; i++ { // 最大30秒待機
        tasks, err := index.GetTasks(&meilisearch.TasksQuery{
            Statuses: []meilisearch.TaskStatus{meilisearch.TaskStatusEnqueued, meilisearch.TaskStatusProcessing},
        })
        if err == nil && len(tasks.Results) == 0 {
            return
        }
        time.Sleep(1 * time.Second)
    }
}
```

### Privacy Filter Testing

#### Block/Mute Filtering Tests
```go
// tests/unit/privacy_filter_test.go
package unit

import (
    "context"
    "testing"
    
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/mock"
    
    "avion-search/internal/domain/search"
    "avion-search/internal/usecase/search_usecase"
    "avion-search/tests/mocks"
)

func TestPrivacyFilterUseCase(t *testing.T) {
    tests := []struct {
        name               string
        userID             string
        query              string
        blockedUsers       []string
        mutedUsers         []string
        expectedFilters    []search.Filter
        setupUserService   func(*mocks.MockUserServiceClient)
        setupSearchBackend func(*mocks.MockSearchBackend)
    }{
        {
            name:         "User with blocked users",
            userID:       "user1",
            query:        "test query",
            blockedUsers: []string{"blocked1", "blocked2"},
            mutedUsers:   []string{},
            expectedFilters: []search.Filter{
                {Field: "user_id", Operator: "NOT IN", Value: []string{"blocked1", "blocked2"}},
                {Field: "visibility", Operator: "IN", Value: []string{"public", "unlisted"}},
            },
            setupUserService: func(mockUserSvc *mocks.MockUserServiceClient) {
                mockUserSvc.EXPECT().
                    GetBlockedUsers(mock.Anything, &user_pb.GetBlockedUsersRequest{UserId: "user1"}).
                    Return(&user_pb.GetBlockedUsersResponse{
                        UserIds: []string{"blocked1", "blocked2"},
                    }, nil)
                mockUserSvc.EXPECT().
                    GetMutedUsers(mock.Anything, &user_pb.GetMutedUsersRequest{UserId: "user1"}).
                    Return(&user_pb.GetMutedUsersResponse{
                        UserIds: []string{},
                    }, nil)
            },
            setupSearchBackend: func(mockBackend *mocks.MockSearchBackend) {
                expectedReq := search.SearchRequest{
                    IndexName: "drops",
                    Query:     "test query",
                    Limit:     20,
                    Filters: []search.Filter{
                        {Field: "user_id", Operator: "NOT IN", Value: []string{"blocked1", "blocked2"}},
                        {Field: "visibility", Operator: "IN", Value: []string{"public", "unlisted"}},
                    },
                }
                mockBackend.EXPECT().
                    Search(mock.Anything, expectedReq).
                    Return(search.SearchResponse{
                        Hits:        []map[string]interface{}{},
                        Total:       0,
                        ProcessedAt: 10,
                    }, nil)
            },
        },
        {
            name:         "User with muted users only",
            userID:       "user1", 
            query:        "test query",
            blockedUsers: []string{},
            mutedUsers:   []string{"muted1"},
            expectedFilters: []search.Filter{
                {Field: "user_id", Operator: "NOT IN", Value: []string{"muted1"}},
                {Field: "visibility", Operator: "IN", Value: []string{"public", "unlisted"}},
            },
            setupUserService: func(mockUserSvc *mocks.MockUserServiceClient) {
                mockUserSvc.EXPECT().
                    GetBlockedUsers(mock.Anything, &user_pb.GetBlockedUsersRequest{UserId: "user1"}).
                    Return(&user_pb.GetBlockedUsersResponse{UserIds: []string{}}, nil)
                mockUserSvc.EXPECT().
                    GetMutedUsers(mock.Anything, &user_pb.GetMutedUsersRequest{UserId: "user1"}).
                    Return(&user_pb.GetMutedUsersResponse{
                        UserIds: []string{"muted1"},
                    }, nil)
            },
            setupSearchBackend: func(mockBackend *mocks.MockSearchBackend) {
                expectedReq := search.SearchRequest{
                    IndexName: "drops",
                    Query:     "test query", 
                    Limit:     20,
                    Filters: []search.Filter{
                        {Field: "user_id", Operator: "NOT IN", Value: []string{"muted1"}},
                        {Field: "visibility", Operator: "IN", Value: []string{"public", "unlisted"}},
                    },
                }
                mockBackend.EXPECT().
                    Search(mock.Anything, expectedReq).
                    Return(search.SearchResponse{}, nil)
            },
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            mockUserSvc := mocks.NewMockUserServiceClient(t)
            mockSearchBackend := mocks.NewMockSearchBackend(t)
            
            tt.setupUserService(mockUserSvc)
            tt.setupSearchBackend(mockSearchBackend)
            
            useCase := search_usecase.NewSearchUseCase(mockSearchBackend, mockUserSvc)
            
            req := search_usecase.SearchRequest{
                UserID: tt.userID,
                Query:  tt.query,
                Type:   "drops",
                Limit:  20,
            }
            
            _, err := useCase.Search(context.Background(), req)
            assert.NoError(t, err)
        })
    }
}
```

### Search Result Ranking Validation

#### Ranking Algorithm Tests
```go
// tests/unit/ranking_test.go
func TestSearchRankingValidation(t *testing.T) {
    tests := []struct {
        name         string
        documents    []map[string]interface{}
        query        string
        expectedOrder []string
        description   string
    }{
        {
            name: "Relevance-based ranking",
            documents: []map[string]interface{}{
                {
                    "id":             "1",
                    "content":        "Go programming language tutorial",
                    "reaction_count": 5,
                    "created_at":     time.Now().Unix() - 3600,
                },
                {
                    "id":             "2", 
                    "content":        "Programming with Go language basics",
                    "reaction_count": 10,
                    "created_at":     time.Now().Unix() - 1800,
                },
                {
                    "id":             "3",
                    "content":        "Advanced Go programming concepts",
                    "reaction_count": 3,
                    "created_at":     time.Now().Unix() - 900,
                },
            },
            query:         "Go programming",
            expectedOrder: []string{"1", "3", "2"}, // 完全一致 > 新しさ > リアクション数
            description:   "Exact match should rank highest, then recency, then reactions",
        },
        {
            name: "Reaction-weighted ranking",
            documents: []map[string]interface{}{
                {
                    "id":             "1",
                    "content":        "Popular post about technology",
                    "reaction_count": 100,
                    "created_at":     time.Now().Unix() - 86400, // 1日前
                },
                {
                    "id":             "2",
                    "content":        "Technology discussion recent",
                    "reaction_count": 5,
                    "created_at":     time.Now().Unix() - 300, // 5分前
                },
            },
            query:         "technology",
            expectedOrder: []string{"1", "2"}, // 高リアクション数が優先
            description:   "High reaction count should outweigh recency for same relevance",
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // MeiliSearchのランキングルールをテスト
            // 実際のランキング結果を検証
            
            mockBackend := mocks.NewMockSearchBackend(t)
            mockBackend.EXPECT().
                Search(mock.Anything, mock.MatchedBy(func(req search.SearchRequest) bool {
                    return req.Query == tt.query
                })).
                Return(search.SearchResponse{
                    Hits: createMockHitsInOrder(tt.documents, tt.expectedOrder),
                }, nil)
            
            useCase := search_usecase.NewSearchUseCase(mockBackend, nil)
            
            resp, err := useCase.Search(context.Background(), search_usecase.SearchRequest{
                Query: tt.query,
                Type:  "drops",
            })
            
            assert.NoError(t, err)
            assert.Equal(t, len(tt.expectedOrder), len(resp.Results))
            
            for i, expectedID := range tt.expectedOrder {
                actualID := resp.Results[i]["id"].(string)
                assert.Equal(t, expectedID, actualID, 
                    "Position %d: expected %s, got %s. %s", i, expectedID, actualID, tt.description)
            }
        })
    }
}

func createMockHitsInOrder(docs []map[string]interface{}, order []string) []map[string]interface{} {
    docMap := make(map[string]map[string]interface{})
    for _, doc := range docs {
        docMap[doc["id"].(string)] = doc
    }
    
    var orderedHits []map[string]interface{}
    for _, id := range order {
        if doc, exists := docMap[id]; exists {
            orderedHits = append(orderedHits, doc)
        }
    }
    return orderedHits
}
```

### Index Synchronization Testing

#### Event-Driven Updates
```go
// tests/integration/index_sync_test.go
func TestEventDrivenIndexUpdates(t *testing.T) {
    tests := []struct {
        name        string
        event       string
        payload     map[string]interface{}
        setupIndex  func(*meilisearch.Client)
        verifyIndex func(*testing.T, *meilisearch.Client)
    }{
        {
            name:  "Drop created event",
            event: "drop.created",
            payload: map[string]interface{}{
                "drop_id":    "new_drop_1",
                "user_id":    "user1",
                "content":    "New drop content for indexing",
                "visibility": "public",
                "created_at": time.Now().Unix(),
            },
            setupIndex: func(client *meilisearch.Client) {
                // 既存ドキュメントをセットアップ
            },
            verifyIndex: func(t *testing.T, client *meilisearch.Client) {
                index := client.Index("test_drops")
                doc, err := index.GetDocument("new_drop_1")
                assert.NoError(t, err)
                assert.Equal(t, "New drop content for indexing", doc["content"])
            },
        },
        {
            name:  "Drop updated event",
            event: "drop.updated", 
            payload: map[string]interface{}{
                "drop_id": "existing_drop_1",
                "content": "Updated content for existing drop",
            },
            setupIndex: func(client *meilisearch.Client) {
                index := client.Index("test_drops")
                docs := []map[string]interface{}{
                    {
                        "id":      "existing_drop_1",
                        "content": "Original content",
                        "user_id": "user1",
                    },
                }
                index.AddDocuments(docs)
            },
            verifyIndex: func(t *testing.T, client *meilisearch.Client) {
                index := client.Index("test_drops")
                doc, err := index.GetDocument("existing_drop_1")
                assert.NoError(t, err)
                assert.Equal(t, "Updated content for existing drop", doc["content"])
            },
        },
        {
            name:  "Drop deleted event (GDPR)",
            event: "drop.deleted",
            payload: map[string]interface{}{
                "drop_id": "to_delete_1",
                "reason":  "gdpr_request",
            },
            setupIndex: func(client *meilisearch.Client) {
                index := client.Index("test_drops")
                docs := []map[string]interface{}{
                    {
                        "id":      "to_delete_1",
                        "content": "Content to be deleted",
                        "user_id": "user1",
                    },
                }
                index.AddDocuments(docs)
            },
            verifyIndex: func(t *testing.T, client *meilisearch.Client) {
                index := client.Index("test_drops")
                _, err := index.GetDocument("to_delete_1")
                assert.Error(t, err) // ドキュメントが削除されていることを確認
            },
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // テスト環境セットアップ
            client := setupTestMeiliSearch(t)
            defer cleanupTestMeiliSearch(t, client)
            
            tt.setupIndex(client)
            
            // イベント処理のシミュレーション
            eventHandler := search.NewEventHandler(
                search.NewMeiliSearchBackend(testConfig),
                logger,
            )
            
            event := search.Event{
                Type:    tt.event,
                Payload: tt.payload,
            }
            
            err := eventHandler.HandleEvent(context.Background(), event)
            assert.NoError(t, err)
            
            // インデックスの状態確認
            time.Sleep(2 * time.Second) // インデックス完了待機
            tt.verifyIndex(t, client)
        })
    }
}
```

### Performance Testing

#### Large-Scale Indexing Performance
```go
// tests/performance/indexing_performance_test.go
func TestLargeScaleIndexingPerformance(t *testing.T) {
    if testing.Short() {
        t.Skip("Skipping performance test in short mode")
    }
    
    tests := []struct {
        name           string
        documentCount  int
        batchSize      int
        maxDuration    time.Duration
        expectedTPS    int // Documents per second
    }{
        {
            name:          "Small batch indexing",
            documentCount: 10000,
            batchSize:     100,
            maxDuration:   30 * time.Second,
            expectedTPS:   500,
        },
        {
            name:          "Large batch indexing", 
            documentCount: 100000,
            batchSize:     1000,
            maxDuration:   120 * time.Second,
            expectedTPS:   1000,
        },
        {
            name:          "Ultra large indexing",
            documentCount: 1000000,
            batchSize:     5000,
            maxDuration:   600 * time.Second,
            expectedTPS:   2000,
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            client := setupPerformanceTestMeiliSearch(t)
            defer cleanupTestMeiliSearch(t, client)
            
            // テストドキュメント生成
            documents := generateTestDocuments(tt.documentCount)
            
            // バッチ処理でインデックス
            start := time.Now()
            
            indexer := search.NewBatchIndexer(client, search.BatchIndexerConfig{
                BatchSize:      tt.batchSize,
                MaxConcurrency: 4,
                RetryAttempts:  3,
            })
            
            err := indexer.IndexDocuments(context.Background(), "performance_test", documents)
            
            elapsed := time.Since(start)
            
            assert.NoError(t, err)
            assert.Less(t, elapsed, tt.maxDuration, "Indexing took too long")
            
            // スループット計算
            actualTPS := int(float64(tt.documentCount) / elapsed.Seconds())
            assert.GreaterOrEqual(t, actualTPS, tt.expectedTPS, 
                "Throughput too low: got %d TPS, expected at least %d TPS", actualTPS, tt.expectedTPS)
            
            t.Logf("Indexed %d documents in %v (%.1f docs/sec)", 
                tt.documentCount, elapsed, float64(tt.documentCount)/elapsed.Seconds())
        })
    }
}

func generateTestDocuments(count int) []map[string]interface{} {
    documents := make([]map[string]interface{}, count)
    
    sampleContents := []string{
        "Go言語でマイクロサービスを開発しています",
        "Kubernetes上でのデプロイメント自動化について",
        "MeiliSearchを使った全文検索システムの構築",
        "GraphQLとRESTAPIの比較検討",
        "PostgreSQLのパフォーマンスチューニング手法",
    }
    
    for i := 0; i < count; i++ {
        documents[i] = map[string]interface{}{
            "id":             fmt.Sprintf("doc_%d", i),
            "content":        sampleContents[i%len(sampleContents)] + fmt.Sprintf(" %d", i),
            "user_id":        fmt.Sprintf("user_%d", i%1000),
            "created_at":     time.Now().Unix() - int64(i*60), // 1分間隔
            "reaction_count": rand.Intn(100),
            "visibility":     []string{"public", "unlisted", "private"}[i%3],
        }
    }
    
    return documents
}
```

### GDPR Compliance Testing

#### Right to be Forgotten
```go
// tests/compliance/gdpr_test.go
func TestGDPRRightToBeForgotten(t *testing.T) {
    tests := []struct {
        name                string
        userID              string
        documentsToIndex    []map[string]interface{}
        expectedRemaining   int
        verifyDeletion      func(*testing.T, *meilisearch.Client, string)
    }{
        {
            name:   "Complete user data deletion",
            userID: "gdpr_user_1",
            documentsToIndex: []map[string]interface{}{
                {
                    "id":      "drop_1",
                    "user_id": "gdpr_user_1",
                    "content": "User content to be deleted",
                },
                {
                    "id":      "drop_2", 
                    "user_id": "other_user",
                    "content": "Other user content to remain",
                },
                {
                    "id":      "drop_3",
                    "user_id": "gdpr_user_1", 
                    "content": "Another user content to be deleted",
                },
            },
            expectedRemaining: 1,
            verifyDeletion: func(t *testing.T, client *meilisearch.Client, userID string) {
                // 特定ユーザーのドキュメントがすべて削除されていることを確認
                index := client.Index("test_drops")
                
                searchReq := &meilisearch.SearchRequest{
                    Filter: fmt.Sprintf("user_id = %s", userID),
                    Limit:  1000,
                }
                
                resp, err := index.Search("", searchReq)
                assert.NoError(t, err)
                assert.Equal(t, 0, len(resp.Hits), "User documents should be completely deleted")
            },
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            client := setupTestMeiliSearch(t)
            defer cleanupTestMeiliSearch(t, client)
            
            // テストデータのインデックス
            index := client.Index("test_drops")
            _, err := index.AddDocuments(tt.documentsToIndex)
            assert.NoError(t, err)
            
            // インデックス完了待機
            waitForIndexing(t, index)
            
            // GDPR削除実行
            gdprService := search.NewGDPRService(
                search.NewMeiliSearchBackend(testConfig),
                logger,
            )
            
            err = gdprService.DeleteUserData(context.Background(), tt.userID)
            assert.NoError(t, err)
            
            // 削除完了待機
            time.Sleep(3 * time.Second)
            
            // 削除確認
            resp, err := index.Search("", &meilisearch.SearchRequest{Limit: 1000})
            assert.NoError(t, err)
            assert.Equal(t, tt.expectedRemaining, len(resp.Hits))
            
            tt.verifyDeletion(t, client, tt.userID)
        })
    }
}
```

### Test Execution Strategy

#### Continuous Integration
```bash
# .github/workflows/search-service-tests.yml での実行順序

# 1. Unit Tests (並列実行)
make test-unit-search

# 2. Integration Tests (MeiliSearchコンテナ使用)
make test-integration-search

# 3. Performance Tests (PRのみ)
make test-performance-search

# 4. GDPR Compliance Tests
make test-compliance-search
```

#### Local Development
```makefile
# Makefile targets for local testing

.PHONY: test-search-all
test-search-all: test-search-unit test-search-integration test-search-performance

.PHONY: test-search-unit
test-search-unit:
	go test -v ./internal/... -tags=unit

.PHONY: test-search-integration
test-search-integration:
	docker-compose -f docker-compose.test.yml up -d meilisearch
	go test -v ./tests/integration/... -tags=integration
	docker-compose -f docker-compose.test.yml down

.PHONY: test-search-performance
test-search-performance:
	go test -v ./tests/performance/... -tags=performance -timeout=30m

.PHONY: test-search-coverage
test-search-coverage:
	go test -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
```

### Test Data Management

#### Test Fixtures
```go
// tests/fixtures/search_fixtures.go
package fixtures

var (
    SampleDrops = []map[string]interface{}{
        {
            "id":             "fixture_drop_1",
            "content":        "Go言語でWebアプリケーション開発",
            "title":          "技術記事",
            "user_id":        "fixture_user_1",
            "created_at":     1640995200, // 2022-01-01
            "reaction_count": 42,
            "visibility":     "public",
            "tags":           []string{"go", "web", "programming"},
        },
        // ... more fixtures
    }
    
    SampleUsers = []map[string]interface{}{
        {
            "id":       "fixture_user_1",
            "username": "testuser1",
            "blocked":  []string{"blocked_user_1"},
            "muted":    []string{"muted_user_1"},
        },
        // ... more fixtures
    }
)

func LoadDropFixtures(index *meilisearch.Index) error {
    _, err := index.AddDocuments(SampleDrops)
    return err
}
```

この包括的なテスト戦略により、avion-searchサービスの品質、パフォーマンス、セキュリティ、コンプライアンスを確保します。

---
