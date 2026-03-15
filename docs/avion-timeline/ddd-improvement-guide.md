# DDD改善ガイド: avion-timeline

## 概要

本ドキュメントは、avion-timelineサービスにおけるDomain-Driven Design (DDD) 実装の改善に関する包括的なガイドです。コンプライアンスレビューで特定されたアーキテクチャ上の課題に対処し、Single Responsibility Principle (SRP) への準拠を確保します。

## 現状の課題と解決策

### 1. Domain ServiceのSRP違反

#### 課題
現在のDomain ServiceはSRPに違反し、複数の関心事を同時に処理している:
- `TimelineGenerationService`が生成とバリデーションの両方を担当
- `FanoutStrategyService`が戦略の選択と実行を管理
- サービスがビジネスルールと技術的実装を混在

#### 解決策: サービスの分解

**変更前（SRP違反）**
```go
type TimelineGenerationService interface {
    GenerateHomeTimeline(userID UserID) (*Timeline, error)
    ValidateTimelineEntry(entry TimelineEntry) error
    DetermineRelevance(entry TimelineEntry, userPrefs UserPreferences) float64
    ApplyFilters(entries []TimelineEntry, filters []Filter) []TimelineEntry
    RankEntries(entries []TimelineEntry) []TimelineEntry
}
```

**変更後（SRP準拠）**

```go
// 1. タイムライン生成（コア責務）
type TimelineGenerationService interface {
    GenerateHomeTimeline(ctx context.Context, userID UserID) (*Timeline, error)
    GenerateListTimeline(ctx context.Context, listID UserListID) (*Timeline, error)
    GenerateUserTimeline(ctx context.Context, userID UserID) (*Timeline, error)
    RegenerateTimeline(ctx context.Context, timelineID TimelineID) (*Timeline, error)
}

// 2. エントリーバリデーション（検証の関心事）
type TimelineEntryValidationService interface {
    ValidateEntry(entry TimelineEntry) error
    ValidateEntryForUser(entry TimelineEntry, userID UserID) error
    ValidateBatchEntries(entries []TimelineEntry) []error
    IsEntryExpired(entry TimelineEntry) bool
}

// 3. 関連度計算（スコアリングの関心事）
type RelevanceCalculationService interface {
    CalculateRelevance(entry TimelineEntry, userPrefs UserPreferences) RelevanceScore
    CalculateEngagementScore(entry TimelineEntry, userHistory UserHistory) float64
    CalculateRecencyScore(entry TimelineEntry, currentTime time.Time) float64
    CalculateAffinityScore(entry TimelineEntry, userRelations UserRelations) float64
}

// 4. タイムラインフィルタリング（フィルターの関心事）
type TimelineFilteringService interface {
    ApplyContentFilters(entries []TimelineEntry, filters []ContentFilter) []TimelineEntry
    ApplyUserFilters(entries []TimelineEntry, blockedUsers []UserID, mutedUsers []UserID) []TimelineEntry
    ApplyTimeFilters(entries []TimelineEntry, startTime, endTime time.Time) []TimelineEntry
    ApplyLanguageFilters(entries []TimelineEntry, languages []Language) []TimelineEntry
}

// 5. エントリーランキング（ランキングの関心事）
type TimelineRankingService interface {
    RankByRelevance(entries []TimelineEntry, scores map[TimelineEntryID]RelevanceScore) []TimelineEntry
    RankByTime(entries []TimelineEntry) []TimelineEntry
    RankByEngagement(entries []TimelineEntry) []TimelineEntry
    ApplyDiversityRanking(entries []TimelineEntry) []TimelineEntry
}
```

### 2. Aggregate境界の問題

#### 課題
現在のAggregateは境界が不明確で、責務が過大である:
- `Timeline` Aggregateが多くの関心事を管理
- 明確な不変条件の強制が欠如
- ビジネスルールのカプセル化が不十分

#### 解決策: 洗練されたAggregate設計

```go
// Timeline Aggregate - タイムラインの状態と不変条件に焦点を当てた設計
type Timeline struct {
    id           TimelineID
    timelineType TimelineType
    ownerID      OwnerID
    entries      timelineEntries // 不変条件を持つプライベートコレクション
    metadata     TimelineMetadata
    version      Version
}

// Aggregateレベルで不変条件を強制
func (t *Timeline) AddEntry(entry TimelineEntry) error {
    // 不変条件1: エントリー数の上限制限
    if t.entries.Count() >= MaxTimelineEntries {
        return ErrTimelineCapacityExceeded
    }

    // 不変条件2: 重複エントリーの禁止
    if t.entries.Contains(entry.ID()) {
        return ErrDuplicateEntry
    }

    // 不変条件3: タイムラインタイプに対して有効なエントリーであること
    if !t.isValidEntryType(entry) {
        return ErrInvalidEntryType
    }

    // 不変条件4: 特定のタイムラインタイプでは時系列順序を保証
    if t.requiresChronologicalOrder() && !t.canInsertAtTime(entry.Timestamp()) {
        return ErrChronologicalViolation
    }

    t.entries.Add(entry)
    t.recordEvent(NewTimelineEntryAddedEvent(t.id, entry.ID()))
    return nil
}

// UserList Aggregate - リストメンバーシップと設定に焦点を当てた設計
type UserList struct {
    id          UserListID
    ownerID     UserID
    name        ListName
    description ListDescription
    visibility  ListVisibility
    members     listMembers // 不変条件を持つプライベートコレクション
    settings    ListSettings
    createdAt   time.Time
    updatedAt   time.Time
    version     Version
}

// Aggregateレベルで不変条件を強制
func (l *UserList) AddMember(userID UserID) error {
    // 不変条件1: メンバー数の上限制限
    if l.members.Count() >= MaxListMembers {
        return ErrListCapacityExceeded
    }

    // 不変条件2: 重複メンバーの禁止
    if l.members.Contains(userID) {
        return ErrDuplicateMember
    }

    // 不変条件3: ブロック済みユーザーは追加不可
    if l.isUserBlocked(userID) {
        return ErrBlockedUser
    }

    // 不変条件4: 可視性ルール
    if !l.canAddMember(userID) {
        return ErrMembershipDenied
    }

    l.members.Add(userID)
    l.updatedAt = time.Now()
    l.recordEvent(NewListMemberAddedEvent(l.id, userID))
    return nil
}
```

### 3. Value Objectの改善

#### 課題
一部のValue Objectが単純すぎるか、バリデーションが不足している

#### 解決策: バリデーション付きの豊かなValue Object

```go
// ビジネスルールを備えた拡張Value Object
type TimelineID struct {
    ownerID      string
    timelineType string
}

func NewTimelineID(ownerID string, timelineType TimelineType) (TimelineID, error) {
    if ownerID == "" {
        return TimelineID{}, ErrInvalidOwnerID
    }
    if !timelineType.IsValid() {
        return TimelineID{}, ErrInvalidTimelineType
    }
    return TimelineID{
        ownerID:      ownerID,
        timelineType: timelineType.String(),
    }, nil
}

func (id TimelineID) String() string {
    return fmt.Sprintf("%s:%s", id.ownerID, id.timelineType)
}

type RelevanceScore struct {
    value float64
}

func NewRelevanceScore(value float64) (RelevanceScore, error) {
    if value < 0.0 || value > 1.0 {
        return RelevanceScore{}, ErrInvalidRelevanceScore
    }
    return RelevanceScore{value: value}, nil
}

func (s RelevanceScore) Value() float64 {
    return s.value
}

func (s RelevanceScore) IsHighRelevance() bool {
    return s.value >= 0.7
}

func (s RelevanceScore) Combine(other RelevanceScore, weight float64) RelevanceScore {
    combined := s.value*(1-weight) + other.value*weight
    score, _ := NewRelevanceScore(combined)
    return score
}
```

### 4. Domain Eventの実装

#### 課題
適切なDomain Eventの処理とEvent Sourcingの機能が不足している

#### 解決策: 包括的なイベントシステム

```go
// 基底Domain Event
type DomainEvent interface {
    AggregateID() string
    EventType() string
    OccurredAt() time.Time
    Version() int
}

// Timeline Domain Event群
type TimelineCreatedEvent struct {
    timelineID   TimelineID
    ownerID      OwnerID
    timelineType TimelineType
    occurredAt   time.Time
    version      int
}

type TimelineEntryAddedEvent struct {
    timelineID TimelineID
    entryID    TimelineEntryID
    dropID     DropID
    occurredAt time.Time
    version    int
}

type TimelineRegeneratedEvent struct {
    timelineID    TimelineID
    oldEntryCount int
    newEntryCount int
    strategy      FanoutStrategy
    occurredAt    time.Time
    version       int
}

// Aggregateにおけるイベント記録
type AggregateRoot struct {
    events []DomainEvent
}

func (a *AggregateRoot) recordEvent(event DomainEvent) {
    a.events = append(a.events, event)
}

func (a *AggregateRoot) GetUncommittedEvents() []DomainEvent {
    return a.events
}

func (a *AggregateRoot) MarkEventsAsCommitted() {
    a.events = []DomainEvent{}
}
```

### 5. Repositoryパターンの強化

#### 課題
RepositoryインターフェースがQueryとCommandの関心事を混在させている

#### 解決策: CQRSに整合したRepositoryパターン

```go
// Command Repository（書き込みモデル）
type TimelineCommandRepository interface {
    Save(ctx context.Context, timeline *Timeline) error
    Delete(ctx context.Context, id TimelineID) error
    NextIdentity() TimelineID

    // Event Sourcingサポート
    SaveEvents(ctx context.Context, events []DomainEvent) error
    GetEventStream(ctx context.Context, aggregateID string) ([]DomainEvent, error)
}

// Query Repository（読み取りモデル）
type TimelineQueryRepository interface {
    FindByID(ctx context.Context, id TimelineID) (*TimelineReadModel, error)
    FindByOwnerAndType(ctx context.Context, ownerID OwnerID, timelineType TimelineType) (*TimelineReadModel, error)
    FindEntriesWithPagination(ctx context.Context, id TimelineID, cursor Cursor, limit int) ([]*TimelineEntryReadModel, Cursor, error)
    CountEntries(ctx context.Context, id TimelineID) (int, error)

    // 特化クエリ
    FindRecentEntries(ctx context.Context, id TimelineID, since time.Time) ([]*TimelineEntryReadModel, error)
    FindPopularEntries(ctx context.Context, id TimelineID, threshold int) ([]*TimelineEntryReadModel, error)
}
```

### 6. UseCase層の改善

#### 課題
UseCaseがCommandとQueryの間で明確に分離されていない

#### 解決策: 明示的なCQRS実装

```go
// Command UseCase群
package command

type CreateTimelineCommand struct {
    OwnerID      OwnerID
    TimelineType TimelineType
}

type CreateTimelineCommandHandler struct {
    repo                   TimelineCommandRepository
    generationService      TimelineGenerationService
    validationService      TimelineEntryValidationService
    eventPublisher         EventPublisher
}

func (h *CreateTimelineCommandHandler) Handle(ctx context.Context, cmd CreateTimelineCommand) error {
    // 新しいTimeline Aggregateを生成
    timeline, err := Timeline.Create(cmd.OwnerID, cmd.TimelineType)
    if err != nil {
        return fmt.Errorf("failed to create timeline: %w", err)
    }

    // 初期エントリーの生成
    if cmd.TimelineType == TimelineTypeHome {
        entries, err := h.generationService.GenerateInitialEntries(ctx, cmd.OwnerID)
        if err != nil {
            return fmt.Errorf("failed to generate initial entries: %w", err)
        }

        for _, entry := range entries {
            if err := h.validationService.ValidateEntry(entry); err != nil {
                continue // 無効なエントリーはスキップ
            }
            timeline.AddEntry(entry)
        }
    }

    // Aggregateの保存とイベント発行
    if err := h.repo.Save(ctx, timeline); err != nil {
        return fmt.Errorf("failed to save timeline: %w", err)
    }

    for _, event := range timeline.GetUncommittedEvents() {
        if err := h.eventPublisher.Publish(ctx, event); err != nil {
            // ログ記録のみで処理は継続
            log.Error("failed to publish event", "event", event)
        }
    }

    return nil
}

// Query UseCase群
package query

type GetTimelineQuery struct {
    UserID       UserID
    TimelineType TimelineType
    Cursor       *Cursor
    Limit        int
}

type GetTimelineQueryHandler struct {
    queryRepo         TimelineQueryRepository
    cacheService      CacheService
    rankingService    TimelineRankingService
    filteringService  TimelineFilteringService
}

func (h *GetTimelineQueryHandler) Handle(ctx context.Context, query GetTimelineQuery) (*TimelineDTO, error) {
    // まずキャッシュを確認
    cacheKey := fmt.Sprintf("timeline:%s:%s", query.UserID, query.TimelineType)
    if cached, err := h.cacheService.Get(ctx, cacheKey); err == nil {
        return cached.(*TimelineDTO), nil
    }

    // 読み取りモデルから取得
    timeline, err := h.queryRepo.FindByOwnerAndType(ctx, query.UserID, query.TimelineType)
    if err != nil {
        return nil, fmt.Errorf("failed to fetch timeline: %w", err)
    }

    // ページネーション付きでエントリーを取得
    entries, nextCursor, err := h.queryRepo.FindEntriesWithPagination(
        ctx,
        timeline.ID,
        query.Cursor,
        query.Limit,
    )
    if err != nil {
        return nil, fmt.Errorf("failed to fetch entries: %w", err)
    }

    // 実行時フィルタリングを適用
    filtered := h.filteringService.ApplyUserFilters(entries, query.UserID)

    // ランキングを適用
    ranked := h.rankingService.RankByRelevance(filtered)

    // DTOを構築
    dto := &TimelineDTO{
        ID:           timeline.ID,
        OwnerID:      timeline.OwnerID,
        Type:         timeline.Type,
        Entries:      toEntryDTOs(ranked),
        NextCursor:   nextCursor,
        LastUpdated:  timeline.LastUpdated,
    }

    // 結果をキャッシュ
    h.cacheService.Set(ctx, cacheKey, dto, 5*time.Minute)

    return dto, nil
}
```

## 実装ロードマップ

### Phase 1: 基盤構築（第1-2週）
1. SRPに従ってDomain Serviceをリファクタリング
2. バリデーション付きの適切なValue Objectを実装
3. 明確な境界を持つ焦点を絞ったAggregateを作成
4. Domain層の包括的なユニットテストを追加

### Phase 2: CQRS実装（第3-4週）
1. CommandとQuery用のRepositoryを分離
2. イベント発行機能付きのCommand Handlerを実装
3. キャッシュ機能付きのQuery Handlerを実装
4. UseCase層の統合テストを追加

### Phase 3: Event Sourcing（第5-6週）
1. Domain Eventシステムを実装
2. Event Storeインフラストラクチャを追加
3. 読み取りモデル用のイベントプロジェクションを作成
4. イベントリプレイ機能を実装

### Phase 4: パフォーマンス最適化（第7-8週）
1. 高度なキャッシュ戦略を実装
2. 適切なインデックスによるデータベースクエリの最適化
3. タイムライン生成のバッチ処理を追加
4. 外部サービス向けのサーキットブレーカーを実装

## テスト戦略

### Domain Serviceのユニットテスト
```go
func TestRelevanceCalculationService(t *testing.T) {
    tests := []struct {
        name     string
        entry    TimelineEntry
        prefs    UserPreferences
        expected RelevanceScore
    }{
        {
            name: "正常系: フォロー中ユーザーの場合は高い関連度",
            entry: NewTimelineEntry(
                DropID("drop-1"),
                UserID("followed-user"),
                time.Now(),
            ),
            prefs: UserPreferences{
                FollowedUsers: []UserID{"followed-user"},
            },
            expected: NewRelevanceScore(0.9),
        },
        // その他のテストケース...
    }

    service := NewRelevanceCalculationService()
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := service.CalculateRelevance(tt.entry, tt.prefs)
            assert.Equal(t, tt.expected, result)
        })
    }
}
```

### UseCase層の統合テスト
```go
func TestCreateTimelineCommandHandler(t *testing.T) {
    // セットアップ
    repo := mock.NewMockTimelineCommandRepository(ctrl)
    genService := mock.NewMockTimelineGenerationService(ctrl)
    valService := mock.NewMockTimelineEntryValidationService(ctrl)
    publisher := mock.NewMockEventPublisher(ctrl)

    handler := NewCreateTimelineCommandHandler(repo, genService, valService, publisher)

    // テストデータ
    cmd := CreateTimelineCommand{
        OwnerID:      UserID("user-1"),
        TimelineType: TimelineTypeHome,
    }

    // 期待値の設定
    repo.EXPECT().Save(gomock.Any(), gomock.Any()).Return(nil)
    genService.EXPECT().GenerateInitialEntries(gomock.Any(), cmd.OwnerID).Return([]TimelineEntry{}, nil)
    publisher.EXPECT().Publish(gomock.Any(), gomock.Any()).AnyTimes()

    // 実行
    err := handler.Handle(context.Background(), cmd)

    // 検証
    assert.NoError(t, err)
}
```

## 監視とメトリクス

### 追跡すべき主要メトリクス
```go
// Domain層メトリクス
timeline_aggregate_operations_total{operation="create|update|delete"}
timeline_domain_events_total{event_type="created|updated|regenerated"}
timeline_invariant_violations_total{invariant="max_entries|duplicate|chronological"}

// UseCase層メトリクス
timeline_command_duration_seconds{command="create|update|regenerate"}
timeline_query_duration_seconds{query="get|list|search"}
timeline_cache_hit_ratio

// パフォーマンスメトリクス
timeline_generation_duration_seconds
timeline_ranking_duration_seconds
timeline_filtering_duration_seconds
```

## ベストプラクティス

### 1. Domain Serviceガイドライン
- 各サービスは単一かつ明確な責務を持つこと
- サービスはステートレスであること
- 依存関係は明示的に宣言すること
- サービス間の循環依存を避けること

### 2. Aggregateガイドライン
- Aggregateは小さく焦点を絞った設計にすること
- Aggregate境界で不変条件を強制すること
- 変更の伝達にはDomain Eventを使用すること
- Aggregate間の参照を避けること（代わりにIDを使用）

### 3. Value Objectガイドライン
- Value Objectはイミュータブルにすること
- コンストラクタにバリデーションを含めること
- ビジネス操作のための意味のあるメソッドを提供すること
- 型安全性のためにValue Objectを使用すること

### 4. Repositoryガイドライン
- RepositoryインターフェースはDomain層に配置すること
- 読み取りと書き込みのRepositoryを分離すること（CQRS）
- 永続化の関心事をDomainに漏洩させないこと
- 複雑なクエリにはSpecificationパターンを使用すること

### 5. UseCaseガイドライン
- 1つのUseCaseにつき1つのユーザーインテントを扱うこと
- CommandとQueryの明確な分離を行うこと
- 横断的関心事（ログ、認証）はHandler層で処理すること
- Domain Objectではなく、DTOを返却すること

## 避けるべき一般的なアンチパターン

1. **貧血ドメインモデル**: ビジネスロジックがサービスではなくDomainに存在することを確認する
2. **巨大なAggregate**: Aggregateは不変条件の維持に焦点を絞って設計する
3. **抽象化の漏洩**: Domainにインフラストラクチャの詳細を露出させない
4. **過剰設計**: シンプルに始め、複雑さが生じた時にリファクタリングする
5. **パフォーマンスの無視**: Domain設計のパフォーマンスへの影響を考慮する

## 移行戦略

### Phase 1: 準備（第1週）
- リファクタリング用のFeatureブランチを作成
- 並行実装（旧・新）のセットアップ
- 段階的ロールアウト用のFeature Flagを追加

### Phase 2: 実装（第2-6週）
- SRPに従った新しいDomain Serviceを実装
- 適切な境界を持つ新しいAggregateを作成
- CQRS Handlerを構築
- 包括的なテストを作成

### Phase 3: 移行（第7-8週）
- Feature Flagを使用してトラフィックを段階的に移行
- メトリクスとパフォーマンスを監視
- 発生する問題に対処
- 安定したら移行を完了

### Phase 4: クリーンアップ（第9週）
- 旧実装を削除
- ドキュメントを更新
- ナレッジ共有セッションを実施
- 移行アーティファクトをアーカイブ

## 成功基準

### 技術的メトリクス
- [ ] Domain層のテストカバレッジ 95%
- [ ] UseCase層のテストカバレッジ 85%
- [ ] Domain ServiceのSRP違反がゼロ
- [ ] 全てのAggregateが500行以下
- [ ] レスポンスタイムが20%改善

### ビジネスメトリクス
- [ ] 移行中のエラー率増加なし
- [ ] タイムライン生成レイテンシ < 100ms (p99)
- [ ] SSE接続安定性 > 99.9%
- [ ] キャッシュヒット率 > 80%

### 品質メトリクス
- [ ] 全てのコードレビューが重大な問題なく通過
- [ ] ドキュメント完全性 > 95%
- [ ] 本番環境でのクリティカルバグがゼロ
- [ ] 認知的複雑度スコアの低減

## まとめ

本ガイドは、avion-timelineにおけるDDD実装の改善に対する包括的なアプローチを提供します。これらのパターンとプラクティスに従うことで、サービスは以下を達成できます:

- SRPによる関心の分離の向上
- ビジネスロジックのカプセル化の明確化
- テスト容易性と保守性の改善
- CQRSによるパフォーマンスの向上
- イベント駆動アーキテクチャによるスケーラビリティの強化

リファクタリングは段階的に実施し、各Phase でシステムの安定性を維持しながら価値を提供します。
