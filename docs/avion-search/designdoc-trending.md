# Design Doc: avion-search - トレンド分析・推薦アルゴリズム

> **本文書は [designdoc.md](./designdoc.md) から分割されたドキュメントです。**
> メイン DesignDoc に戻る場合は [designdoc.md](./designdoc.md) を参照してください。
>
> **関連ドキュメント:**
> - [designdoc-indexing.md](./designdoc-indexing.md) - インデックス管理、MeiliSearch設定、SearchBackend Interface
> - [designdoc-infra-testing.md](./designdoc-infra-testing.md) - インフラ層実装、テスト戦略、エラーハンドリング

---

## 14. ドメインモデル詳細設計

### 14.1. Domain Objects詳細仕様

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
    if len(text) > 256 {
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

### 14.2. Domain Services詳細実装

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

