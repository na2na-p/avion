# DDD Improvement Guide: avion-timeline

## Overview

This document provides a comprehensive guide for improving the Domain-Driven Design (DDD) implementation in avion-timeline service, addressing the architectural issues identified in the compliance review and ensuring adherence to the Single Responsibility Principle (SRP).

## Current Issues and Solutions

### 1. Domain Service SRP Violations

#### Issue
The current domain services violate SRP by handling multiple concerns:
- `TimelineGenerationService` handles both generation and validation
- `FanoutStrategyService` manages strategy selection and execution
- Services mix business rules with technical implementation

#### Solution: Service Decomposition

**Before (Violating SRP)**
```go
type TimelineGenerationService interface {
    GenerateHomeTimeline(userID UserID) (*Timeline, error)
    ValidateTimelineEntry(entry TimelineEntry) error
    DetermineRelevance(entry TimelineEntry, userPrefs UserPreferences) float64
    ApplyFilters(entries []TimelineEntry, filters []Filter) []TimelineEntry
    RankEntries(entries []TimelineEntry) []TimelineEntry
}
```

**After (Following SRP)**

```go
// 1. Timeline Generation (Core responsibility)
type TimelineGenerationService interface {
    GenerateHomeTimeline(ctx context.Context, userID UserID) (*Timeline, error)
    GenerateListTimeline(ctx context.Context, listID UserListID) (*Timeline, error)
    GenerateUserTimeline(ctx context.Context, userID UserID) (*Timeline, error)
    RegenerateTimeline(ctx context.Context, timelineID TimelineID) (*Timeline, error)
}

// 2. Entry Validation (Validation concern)
type TimelineEntryValidationService interface {
    ValidateEntry(entry TimelineEntry) error
    ValidateEntryForUser(entry TimelineEntry, userID UserID) error
    ValidateBatchEntries(entries []TimelineEntry) []error
    IsEntryExpired(entry TimelineEntry) bool
}

// 3. Relevance Calculation (Scoring concern)
type RelevanceCalculationService interface {
    CalculateRelevance(entry TimelineEntry, userPrefs UserPreferences) RelevanceScore
    CalculateEngagementScore(entry TimelineEntry, userHistory UserHistory) float64
    CalculateRecencyScore(entry TimelineEntry, currentTime time.Time) float64
    CalculateAffinityScore(entry TimelineEntry, userRelations UserRelations) float64
}

// 4. Timeline Filtering (Filter concern)
type TimelineFilteringService interface {
    ApplyContentFilters(entries []TimelineEntry, filters []ContentFilter) []TimelineEntry
    ApplyUserFilters(entries []TimelineEntry, blockedUsers []UserID, mutedUsers []UserID) []TimelineEntry
    ApplyTimeFilters(entries []TimelineEntry, startTime, endTime time.Time) []TimelineEntry
    ApplyLanguageFilters(entries []TimelineEntry, languages []Language) []TimelineEntry
}

// 5. Entry Ranking (Ranking concern)
type TimelineRankingService interface {
    RankByRelevance(entries []TimelineEntry, scores map[TimelineEntryID]RelevanceScore) []TimelineEntry
    RankByTime(entries []TimelineEntry) []TimelineEntry
    RankByEngagement(entries []TimelineEntry) []TimelineEntry
    ApplyDiversityRanking(entries []TimelineEntry) []TimelineEntry
}
```

### 2. Aggregate Boundary Issues

#### Issue
Current aggregates have unclear boundaries and excessive responsibilities:
- `Timeline` aggregate manages too many concerns
- Missing clear invariant enforcement
- Weak encapsulation of business rules

#### Solution: Refined Aggregate Design

```go
// Timeline Aggregate - Focused on timeline state and invariants
type Timeline struct {
    id           TimelineID
    timelineType TimelineType
    ownerID      OwnerID
    entries      timelineEntries // Private collection with invariants
    metadata     TimelineMetadata
    version      Version
}

// Invariants enforced at aggregate level
func (t *Timeline) AddEntry(entry TimelineEntry) error {
    // Invariant 1: Maximum entries limit
    if t.entries.Count() >= MaxTimelineEntries {
        return ErrTimelineCapacityExceeded
    }
    
    // Invariant 2: No duplicate entries
    if t.entries.Contains(entry.ID()) {
        return ErrDuplicateEntry
    }
    
    // Invariant 3: Entry must be valid for timeline type
    if !t.isValidEntryType(entry) {
        return ErrInvalidEntryType
    }
    
    // Invariant 4: Chronological ordering for certain timeline types
    if t.requiresChronologicalOrder() && !t.canInsertAtTime(entry.Timestamp()) {
        return ErrChronologicalViolation
    }
    
    t.entries.Add(entry)
    t.recordEvent(NewTimelineEntryAddedEvent(t.id, entry.ID()))
    return nil
}

// UserList Aggregate - Focused on list membership and settings
type UserList struct {
    id          UserListID
    ownerID     UserID
    name        ListName
    description ListDescription
    visibility  ListVisibility
    members     listMembers // Private collection with invariants
    settings    ListSettings
    createdAt   time.Time
    updatedAt   time.Time
    version     Version
}

// Invariants enforced at aggregate level
func (l *UserList) AddMember(userID UserID) error {
    // Invariant 1: Maximum members limit
    if l.members.Count() >= MaxListMembers {
        return ErrListCapacityExceeded
    }
    
    // Invariant 2: No duplicate members
    if l.members.Contains(userID) {
        return ErrDuplicateMember
    }
    
    // Invariant 3: Cannot add blocked users
    if l.isUserBlocked(userID) {
        return ErrBlockedUser
    }
    
    // Invariant 4: Visibility rules
    if !l.canAddMember(userID) {
        return ErrMembershipDenied
    }
    
    l.members.Add(userID)
    l.updatedAt = time.Now()
    l.recordEvent(NewListMemberAddedEvent(l.id, userID))
    return nil
}
```

### 3. Value Object Improvements

#### Issue
Some value objects are too simple or missing validation

#### Solution: Rich Value Objects with Validation

```go
// Enhanced Value Objects with business rules
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

### 4. Domain Event Implementation

#### Issue
Missing proper domain event handling and event sourcing capabilities

#### Solution: Comprehensive Event System

```go
// Base Domain Event
type DomainEvent interface {
    AggregateID() string
    EventType() string
    OccurredAt() time.Time
    Version() int
}

// Timeline Domain Events
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

// Event Recording in Aggregates
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

### 5. Repository Pattern Enhancement

#### Issue
Repository interfaces mixing query and command concerns

#### Solution: CQRS-Aligned Repository Pattern

```go
// Command Repository (Write Model)
type TimelineCommandRepository interface {
    Save(ctx context.Context, timeline *Timeline) error
    Delete(ctx context.Context, id TimelineID) error
    NextIdentity() TimelineID
    
    // Event Sourcing Support
    SaveEvents(ctx context.Context, events []DomainEvent) error
    GetEventStream(ctx context.Context, aggregateID string) ([]DomainEvent, error)
}

// Query Repository (Read Model)
type TimelineQueryRepository interface {
    FindByID(ctx context.Context, id TimelineID) (*TimelineReadModel, error)
    FindByOwnerAndType(ctx context.Context, ownerID OwnerID, timelineType TimelineType) (*TimelineReadModel, error)
    FindEntriesWithPagination(ctx context.Context, id TimelineID, cursor Cursor, limit int) ([]*TimelineEntryReadModel, Cursor, error)
    CountEntries(ctx context.Context, id TimelineID) (int, error)
    
    // Specialized Queries
    FindRecentEntries(ctx context.Context, id TimelineID, since time.Time) ([]*TimelineEntryReadModel, error)
    FindPopularEntries(ctx context.Context, id TimelineID, threshold int) ([]*TimelineEntryReadModel, error)
}
```

### 6. Use Case Layer Improvements

#### Issue
Use cases not clearly separated between commands and queries

#### Solution: Explicit CQRS Implementation

```go
// Command Use Cases
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
    // Create new timeline aggregate
    timeline, err := Timeline.Create(cmd.OwnerID, cmd.TimelineType)
    if err != nil {
        return fmt.Errorf("failed to create timeline: %w", err)
    }
    
    // Generate initial entries
    if cmd.TimelineType == TimelineTypeHome {
        entries, err := h.generationService.GenerateInitialEntries(ctx, cmd.OwnerID)
        if err != nil {
            return fmt.Errorf("failed to generate initial entries: %w", err)
        }
        
        for _, entry := range entries {
            if err := h.validationService.ValidateEntry(entry); err != nil {
                continue // Skip invalid entries
            }
            timeline.AddEntry(entry)
        }
    }
    
    // Save aggregate and publish events
    if err := h.repo.Save(ctx, timeline); err != nil {
        return fmt.Errorf("failed to save timeline: %w", err)
    }
    
    for _, event := range timeline.GetUncommittedEvents() {
        if err := h.eventPublisher.Publish(ctx, event); err != nil {
            // Log but don't fail
            log.Error("failed to publish event", "event", event)
        }
    }
    
    return nil
}

// Query Use Cases
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
    // Try cache first
    cacheKey := fmt.Sprintf("timeline:%s:%s", query.UserID, query.TimelineType)
    if cached, err := h.cacheService.Get(ctx, cacheKey); err == nil {
        return cached.(*TimelineDTO), nil
    }
    
    // Fetch from read model
    timeline, err := h.queryRepo.FindByOwnerAndType(ctx, query.UserID, query.TimelineType)
    if err != nil {
        return nil, fmt.Errorf("failed to fetch timeline: %w", err)
    }
    
    // Fetch entries with pagination
    entries, nextCursor, err := h.queryRepo.FindEntriesWithPagination(
        ctx, 
        timeline.ID, 
        query.Cursor, 
        query.Limit,
    )
    if err != nil {
        return nil, fmt.Errorf("failed to fetch entries: %w", err)
    }
    
    // Apply runtime filtering
    filtered := h.filteringService.ApplyUserFilters(entries, query.UserID)
    
    // Apply ranking
    ranked := h.rankingService.RankByRelevance(filtered)
    
    // Build DTO
    dto := &TimelineDTO{
        ID:           timeline.ID,
        OwnerID:      timeline.OwnerID,
        Type:         timeline.Type,
        Entries:      toEntryDTOs(ranked),
        NextCursor:   nextCursor,
        LastUpdated:  timeline.LastUpdated,
    }
    
    // Cache result
    h.cacheService.Set(ctx, cacheKey, dto, 5*time.Minute)
    
    return dto, nil
}
```

## Implementation Roadmap

### Phase 1: Foundation (Week 1-2)
1. Refactor domain services following SRP
2. Implement proper value objects with validation
3. Create focused aggregates with clear boundaries
4. Add comprehensive unit tests for domain layer

### Phase 2: CQRS Implementation (Week 3-4)
1. Separate command and query repositories
2. Implement command handlers with event publishing
3. Implement query handlers with caching
4. Add integration tests for use case layer

### Phase 3: Event Sourcing (Week 5-6)
1. Implement domain event system
2. Add event store infrastructure
3. Create event projections for read models
4. Implement event replay capabilities

### Phase 4: Performance Optimization (Week 7-8)
1. Implement advanced caching strategies
2. Optimize database queries with proper indexes
3. Add batch processing for timeline generation
4. Implement circuit breakers for external services

## Testing Strategy

### Unit Tests for Domain Services
```go
func TestRelevanceCalculationService(t *testing.T) {
    tests := []struct {
        name     string
        entry    TimelineEntry
        prefs    UserPreferences
        expected RelevanceScore
    }{
        {
            name: "high relevance for followed user",
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
        // More test cases...
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

### Integration Tests for Use Cases
```go
func TestCreateTimelineCommandHandler(t *testing.T) {
    // Setup
    repo := mock.NewMockTimelineCommandRepository(ctrl)
    genService := mock.NewMockTimelineGenerationService(ctrl)
    valService := mock.NewMockTimelineEntryValidationService(ctrl)
    publisher := mock.NewMockEventPublisher(ctrl)
    
    handler := NewCreateTimelineCommandHandler(repo, genService, valService, publisher)
    
    // Test
    cmd := CreateTimelineCommand{
        OwnerID:      UserID("user-1"),
        TimelineType: TimelineTypeHome,
    }
    
    // Expectations
    repo.EXPECT().Save(gomock.Any(), gomock.Any()).Return(nil)
    genService.EXPECT().GenerateInitialEntries(gomock.Any(), cmd.OwnerID).Return([]TimelineEntry{}, nil)
    publisher.EXPECT().Publish(gomock.Any(), gomock.Any()).AnyTimes()
    
    // Execute
    err := handler.Handle(context.Background(), cmd)
    
    // Assert
    assert.NoError(t, err)
}
```

## Monitoring and Metrics

### Key Metrics to Track
```go
// Domain Layer Metrics
timeline_aggregate_operations_total{operation="create|update|delete"}
timeline_domain_events_total{event_type="created|updated|regenerated"}
timeline_invariant_violations_total{invariant="max_entries|duplicate|chronological"}

// Use Case Layer Metrics
timeline_command_duration_seconds{command="create|update|regenerate"}
timeline_query_duration_seconds{query="get|list|search"}
timeline_cache_hit_ratio

// Performance Metrics
timeline_generation_duration_seconds
timeline_ranking_duration_seconds
timeline_filtering_duration_seconds
```

## Best Practices

### 1. Domain Service Guidelines
- Each service should have a single, clear responsibility
- Services should be stateless
- Dependencies should be explicitly declared
- Avoid circular dependencies between services

### 2. Aggregate Guidelines
- Keep aggregates small and focused
- Enforce invariants at the aggregate boundary
- Use domain events to communicate changes
- Avoid references between aggregates (use IDs instead)

### 3. Value Object Guidelines
- Make value objects immutable
- Include validation in constructors
- Provide meaningful methods for business operations
- Use value objects for type safety

### 4. Repository Guidelines
- Keep repository interfaces in the domain layer
- Separate read and write repositories (CQRS)
- Don't leak persistence concerns into domain
- Use specification pattern for complex queries

### 5. Use Case Guidelines
- One use case per user intent
- Clear separation between commands and queries
- Handle cross-cutting concerns (logging, auth) at handler level
- Return DTOs, not domain objects

## Common Pitfalls to Avoid

1. **Anemic Domain Model**: Ensure business logic is in domain, not in services
2. **Large Aggregates**: Keep aggregates focused on maintaining invariants
3. **Leaky Abstractions**: Don't expose infrastructure details in domain
4. **Over-Engineering**: Start simple, refactor when complexity emerges
5. **Ignoring Performance**: Consider performance implications of domain design

## Migration Strategy

### Phase 1: Prepare (Week 1)
- Create feature branch for refactoring
- Set up parallel implementations (old and new)
- Add feature flags for gradual rollout

### Phase 2: Implement (Week 2-6)
- Implement new domain services with SRP
- Create new aggregates with proper boundaries
- Build CQRS handlers
- Write comprehensive tests

### Phase 3: Migrate (Week 7-8)
- Gradually migrate traffic using feature flags
- Monitor metrics and performance
- Fix issues as they arise
- Complete migration once stable

### Phase 4: Clean Up (Week 9)
- Remove old implementations
- Update documentation
- Conduct knowledge sharing sessions
- Archive migration artifacts

## Success Criteria

### Technical Metrics
- [ ] 95% test coverage for domain layer
- [ ] 90% test coverage for use case layer
- [ ] Zero SRP violations in domain services
- [ ] All aggregates under 500 lines of code
- [ ] Response time improvement of 20%

### Business Metrics
- [ ] No increase in error rates during migration
- [ ] Timeline generation latency < 100ms (p99)
- [ ] SSE connection stability > 99.9%
- [ ] Cache hit ratio > 80%

### Quality Metrics
- [ ] All code reviews pass without major issues
- [ ] Documentation completeness > 95%
- [ ] Zero critical bugs in production
- [ ] Reduced cognitive complexity score

## Conclusion

This guide provides a comprehensive approach to improving the DDD implementation in avion-timeline. By following these patterns and practices, the service will achieve:

- Better separation of concerns through SRP
- Clearer business logic encapsulation
- Improved testability and maintainability
- Better performance through CQRS
- Enhanced scalability through event-driven architecture

The refactoring should be done incrementally, with each phase delivering value while maintaining system stability.