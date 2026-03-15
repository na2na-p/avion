# Design Doc: avion-search - インデックス管理・MeiliSearch設定

> **本文書は [designdoc.md](./designdoc.md) から分割されたドキュメントです。**
> メイン DesignDoc に戻る場合は [designdoc.md](./designdoc.md) を参照してください。
>
> **関連ドキュメント:**
> - [designdoc-trending.md](./designdoc-trending.md) - トレンド分析、推薦アルゴリズム、ドメインモデル詳細
> - [designdoc-infra-testing.md](./designdoc-infra-testing.md) - インフラ層実装、テスト戦略、エラーハンドリング

---

## 13. ドメインオブジェクトとMeiliSearchマッピング戦略

このセクションでは、ドメインオブジェクトとMeiliSearchインデックス間の詳細なマッピング戦略を定義します。

### 13.1. MeiliSearchインデックス設計

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

### 13.2. ドメインオブジェクトマッピング実装

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

### 13.3. 日本語検索最適化

#### 日本語トークナイザー（決定事項）

- **採用技術**: MeiliSearch v1.9 内蔵 **Lindera**（IPA辞書ベース、Viterbiアルゴリズムによる形態素解析）
- **Dockerビルド設定**: `--features japanese` カスタムビルドオプションを指定し、漢字誤検出対策を含む高精度な日本語トークナイゼーションを有効化
- **アプリケーション層の前処理**: `JapaneseTextProcessor` により全角→半角変換、Unicode正規化（NFKC）、ストップワード除去を実施
- **PostgreSQL FTSフォールバック時の検索精度**: MeiliSearch（Lindera）の精度を100%とした場合、PostgreSQL FTSは70-80%程度の精度で許容する。フォールバックは一時的な措置であり、MeiliSearch復旧後は速やかに切り戻す

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

### 13.4. インデックス最適化とクエリ戦略

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


## 15. ドメインオブジェクトとDBスキーマのマッピング

### 15.1. PostgreSQL データベーススキーマ

検索サービスは主にMeiliSearchを使用しますが、メタデータとキャッシュのためにPostgreSQLも使用します：

```sql
-- Search history table
CREATE TABLE search_histories (
    id UUID PRIMARY KEY, -- UUID v7 (Backend採番)
    user_id BIGINT NOT NULL,
    query TEXT NOT NULL,
    search_type VARCHAR(20) NOT NULL, -- 'drop', 'user', 'hashtag'
    result_count INT NOT NULL,
    searched_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_search_histories_user_id ON search_histories (user_id);
CREATE INDEX idx_search_histories_searched_at ON search_histories (searched_at);

-- Saved searches table
CREATE TABLE saved_searches (
    id UUID PRIMARY KEY, -- UUID v7 (Backend採番)
    user_id BIGINT NOT NULL,
    name VARCHAR(100) NOT NULL,
    query TEXT NOT NULL,
    filters JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_saved_searches_user_name UNIQUE (user_id, name)
);

-- Trending hashtags table
CREATE TABLE trending_hashtags (
    id UUID PRIMARY KEY, -- UUID v7 (Backend採番)
    hashtag VARCHAR(100) NOT NULL,
    score DOUBLE PRECISION NOT NULL,
    drop_count INT NOT NULL,
    user_count INT NOT NULL,
    calculated_at TIMESTAMPTZ NOT NULL,
    region VARCHAR(10),
    CONSTRAINT uk_trending_hashtag_region UNIQUE (hashtag, region, calculated_at)
);

CREATE INDEX idx_trending_calculated_at ON trending_hashtags (calculated_at);

-- Search indexing status table
CREATE TABLE indexing_status (
    id UUID PRIMARY KEY, -- UUID v7 (Backend採番)
    entity_type VARCHAR(20) NOT NULL, -- 'drop', 'user'
    entity_id BIGINT NOT NULL,
    indexed_at TIMESTAMPTZ NOT NULL,
    version INT NOT NULL DEFAULT 1,
    status VARCHAR(20) NOT NULL, -- 'indexed', 'pending', 'failed'
    error_message TEXT,
    CONSTRAINT uk_indexing_entity UNIQUE (entity_type, entity_id)
);
```

### 15.2. MeiliSearch インデックススキーマ

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

### 15.3. ドメインオブジェクトとインデックスのマッピング

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

### 15.4. Repository実装でのマッピング

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

### 16.1. クエリ最適化戦略

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

### 16.2. インデックス管理最適化

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


## 20. SearchBackend Interface 設計

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

### PostgreSQL FTS実装（将来対応・フォールバック用）

> **フォールバック時の検索精度（決定事項）**: MeiliSearch（Lindera）の検索精度を100%とした場合、PostgreSQL FTSは**70-80%程度の精度で許容する**。PostgreSQL FTSはMeiliSearch障害時の一時的なフォールバック措置であり、MeiliSearch復旧後は速やかに切り戻す。精度低下の主な要因は、日本語形態素解析の品質差（Lindera vs MeCab/pg_bigm）およびランキングアルゴリズムの差異である。

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

