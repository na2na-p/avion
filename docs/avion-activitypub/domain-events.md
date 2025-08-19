# Domain Events Specification (ドメインイベント仕様)

**Author:** Claude
**Last Updated:** 2025-01-16
**Version:** 1.0

## 1. 概要

本ドキュメントは、avion-activitypubサービスにおけるドメインイベントの完全な仕様を定義します。DDD（Domain-Driven Design）の原則に従い、ビジネスロジックの状態変更を明確に表現します。

## 2. ドメインイベント階層

```go
package domain

import (
    "time"
    "github.com/avion/common/event"
)

// BaseEvent はすべてのドメインイベントの基底型
type BaseEvent struct {
    EventID      string    `json:"event_id"`      // UUID v4
    AggregateID  string    `json:"aggregate_id"`  // 集約ルートID
    EventType    string    `json:"event_type"`    // イベント型名
    OccurredAt   time.Time `json:"occurred_at"`   // 発生時刻（UTC）
    Version      int       `json:"version"`       // イベントバージョン
    CorrelationID string   `json:"correlation_id"` // 相関ID（トレーシング用）
}

func (e BaseEvent) GetEventID() string      { return e.EventID }
func (e BaseEvent) GetAggregateID() string  { return e.AggregateID }
func (e BaseEvent) GetEventType() string    { return e.EventType }
func (e BaseEvent) GetOccurredAt() time.Time { return e.OccurredAt }
func (e BaseEvent) GetVersion() int         { return e.Version }
func (e BaseEvent) GetCorrelationID() string { return e.CorrelationID }
```

## 3. RemoteActor関連イベント

### 3.1 RemoteActorDiscovered

```go
// RemoteActorDiscovered は新しいリモートActorが発見された際に発行される
type RemoteActorDiscovered struct {
    BaseEvent
    ActorURI        string            `json:"actor_uri"`
    Username        string            `json:"username"`
    Domain          string            `json:"domain"`
    ActorType       string            `json:"actor_type"` // Person, Group, Application, Service
    PublicKeyPEM    string            `json:"public_key_pem"`
    InboxURL        string            `json:"inbox_url"`
    SharedInboxURL  *string           `json:"shared_inbox_url,omitempty"`
    Platform        string            `json:"platform"` // mastodon, misskey, lemmy等
    Capabilities    map[string]bool   `json:"capabilities"`
    DiscoverySource string            `json:"discovery_source"` // webfinger, nodeinfo, actor_fetch
}

// Validate はイベントの妥当性を検証
func (e *RemoteActorDiscovered) Validate() error {
    if e.ActorURI == "" {
        return ErrInvalidActorURI
    }
    if e.PublicKeyPEM == "" {
        return ErrMissingPublicKey
    }
    if !IsValidHTTPSURL(e.InboxURL) {
        return ErrInvalidInboxURL
    }
    return nil
}

// ToAggregate はイベントからRemoteActor集約を生成
func (e *RemoteActorDiscovered) ToAggregate() (*RemoteActor, error) {
    return NewRemoteActor(
        e.ActorURI,
        e.Username,
        e.Domain,
        e.PublicKeyPEM,
        e.InboxURL,
        e.SharedInboxURL,
    )
}
```

### 3.2 RemoteActorUpdated

```go
// RemoteActorUpdated はリモートActorの情報が更新された際に発行される
type RemoteActorUpdated struct {
    BaseEvent
    ActorURI        string                 `json:"actor_uri"`
    UpdatedFields   map[string]interface{} `json:"updated_fields"`
    PreviousValues  map[string]interface{} `json:"previous_values"`
    UpdateReason    string                 `json:"update_reason"`
}

func (e *RemoteActorUpdated) GetChangedFields() []string {
    fields := make([]string, 0, len(e.UpdatedFields))
    for field := range e.UpdatedFields {
        fields = append(fields, field)
    }
    return fields
}
```

### 3.3 RemoteActorSuspended

```go
// RemoteActorSuspended はリモートActorが停止された際に発行される
type RemoteActorSuspended struct {
    BaseEvent
    ActorURI        string    `json:"actor_uri"`
    SuspendReason   string    `json:"suspend_reason"`
    SuspendedBy     string    `json:"suspended_by"` // 管理者ID
    SuspendedUntil  *time.Time `json:"suspended_until,omitempty"` // nil = 永久停止
    AutoSuspended   bool      `json:"auto_suspended"` // 自動停止かどうか
}
```

### 3.4 RemoteActorUnsuspended

```go
// RemoteActorUnsuspended はリモートActorの停止が解除された際に発行される
type RemoteActorUnsuspended struct {
    BaseEvent
    ActorURI       string `json:"actor_uri"`
    UnsuspendedBy  string `json:"unsuspended_by"`
    UnsuspendReason string `json:"unsuspend_reason"`
}
```

### 3.5 RemoteActorMoved

```go
// RemoteActorMoved はリモートActorが移行した際に発行される
type RemoteActorMoved struct {
    BaseEvent
    OldActorURI     string    `json:"old_actor_uri"`
    NewActorURI     string    `json:"new_actor_uri"`
    MovedAt         time.Time `json:"moved_at"`
    AlsoKnownAs     []string  `json:"also_known_as"`
    MoveVerified    bool      `json:"move_verified"`
}
```

## 4. FederationDelivery関連イベント

### 4.1 DeliveryTaskCreated

```go
// DeliveryTaskCreated は配送タスクが作成された際に発行される
type DeliveryTaskCreated struct {
    BaseEvent
    TaskID          string    `json:"task_id"`
    ActivityType    string    `json:"activity_type"`
    ActivityContent string    `json:"activity_content"` // JSON-LD
    TargetInboxURL  string    `json:"target_inbox_url"`
    TargetDomain    string    `json:"target_domain"`
    TargetPlatform  string    `json:"target_platform"`
    Priority        int       `json:"priority"` // 1-10
    ScheduledAt     time.Time `json:"scheduled_at"`
}
```

### 4.2 DeliveryAttempted

```go
// DeliveryAttempted は配送試行が実行された際に発行される
type DeliveryAttempted struct {
    BaseEvent
    TaskID         string        `json:"task_id"`
    AttemptNumber  int           `json:"attempt_number"`
    HTTPStatusCode int           `json:"http_status_code"`
    ResponseTime   time.Duration `json:"response_time"`
    ErrorMessage   *string       `json:"error_message,omitempty"`
}
```

### 4.3 DeliverySucceeded

```go
// DeliverySucceeded は配送が成功した際に発行される
type DeliverySucceeded struct {
    BaseEvent
    TaskID         string        `json:"task_id"`
    DeliveredAt    time.Time     `json:"delivered_at"`
    TotalAttempts  int           `json:"total_attempts"`
    TotalDuration  time.Duration `json:"total_duration"`
}
```

### 4.4 DeliveryFailed

```go
// DeliveryFailed は配送が失敗した際に発行される
type DeliveryFailed struct {
    BaseEvent
    TaskID         string    `json:"task_id"`
    FailureType    string    `json:"failure_type"` // temporary, permanent
    FailureReason  string    `json:"failure_reason"`
    TotalAttempts  int       `json:"total_attempts"`
    LastAttemptAt  time.Time `json:"last_attempt_at"`
    WillRetry      bool      `json:"will_retry"`
    NextRetryAt    *time.Time `json:"next_retry_at,omitempty"`
}
```

### 4.5 DeliveryMovedToDeadLetter

```go
// DeliveryMovedToDeadLetter はタスクがDLQに移動された際に発行される
type DeliveryMovedToDeadLetter struct {
    BaseEvent
    TaskID        string    `json:"task_id"`
    MovedAt       time.Time `json:"moved_at"`
    MovedReason   string    `json:"moved_reason"`
    TotalAttempts int       `json:"total_attempts"`
    CanRecover    bool      `json:"can_recover"` // 手動リカバリ可能か
}
```

## 5. ActivityPub Activity関連イベント

### 5.1 ActivityReceived

```go
// ActivityReceived はActivityPubアクティビティを受信した際に発行される
type ActivityReceived struct {
    BaseEvent
    ActivityID      string                 `json:"activity_id"`
    ActivityType    string                 `json:"activity_type"`
    ActorURI        string                 `json:"actor_uri"`
    ObjectURI       *string                `json:"object_uri,omitempty"`
    InboxType       string                 `json:"inbox_type"` // shared, user, community
    SourcePlatform  string                 `json:"source_platform"`
    RawActivity     map[string]interface{} `json:"raw_activity"`
    SignatureValid  bool                   `json:"signature_valid"`
}
```

### 5.2 ActivityProcessed

```go
// ActivityProcessed はアクティビティの処理が完了した際に発行される
type ActivityProcessed struct {
    BaseEvent
    ActivityID      string        `json:"activity_id"`
    ProcessingTime  time.Duration `json:"processing_time"`
    ResultStatus    string        `json:"result_status"` // accepted, rejected, ignored
    SideEffects     []string      `json:"side_effects"` // 発生した副作用のリスト
}
```

### 5.3 ActivityRejected

```go
// ActivityRejected はアクティビティが拒否された際に発行される
type ActivityRejected struct {
    BaseEvent
    ActivityID      string `json:"activity_id"`
    RejectionReason string `json:"rejection_reason"`
    RejectionCode   string `json:"rejection_code"` // APB-xxx エラーコード
    IsRetryable     bool   `json:"is_retryable"`
}
```

## 6. Community Federation関連イベント

### 6.1 CommunityActorCreated

```go
// CommunityActorCreated はコミュニティのGroup Actorが作成された際に発行される
type CommunityActorCreated struct {
    BaseEvent
    CommunityID     string   `json:"community_id"`
    ActorURI        string   `json:"actor_uri"`
    ActorType       string   `json:"actor_type"` // Group or Person (fallback)
    FallbackMode    bool     `json:"fallback_mode"` // Mastodon等への対応
    SupportedPlatforms []string `json:"supported_platforms"`
}
```

### 6.2 CommunityMemberJoinedViaFederation

```go
// CommunityMemberJoinedViaFederation はリモートユーザーがコミュニティに参加した際に発行される
type CommunityMemberJoinedViaFederation struct {
    BaseEvent
    CommunityID     string    `json:"community_id"`
    MemberActorURI  string    `json:"member_actor_uri"`
    MemberPlatform  string    `json:"member_platform"`
    JoinMethod      string    `json:"join_method"` // direct, invite, request
    ApprovedBy      *string   `json:"approved_by,omitempty"`
    JoinedAt        time.Time `json:"joined_at"`
}
```

### 6.3 CommunityActivityDistributed

```go
// CommunityActivityDistributed はコミュニティ活動が配信された際に発行される
type CommunityActivityDistributed struct {
    BaseEvent
    CommunityID      string   `json:"community_id"`
    ActivityID       string   `json:"activity_id"`
    ActivityType     string   `json:"activity_type"`
    TopicID          *string  `json:"topic_id,omitempty"`
    RecipientCount   int      `json:"recipient_count"`
    PlatformBreakdown map[string]int `json:"platform_breakdown"` // platform -> count
}
```

## 7. Security & Moderation関連イベント

### 7.1 ActorBlocked

```go
// ActorBlocked はActorがブロックされた際に発行される
type ActorBlocked struct {
    BaseEvent
    BlockedActorURI string    `json:"blocked_actor_uri"`
    BlockedBy       string    `json:"blocked_by"`
    BlockReason     string    `json:"block_reason"`
    BlockType       string    `json:"block_type"` // silence, suspend, reject
    BlockScope      string    `json:"block_scope"` // instance, user
    ExpiresAt       *time.Time `json:"expires_at,omitempty"`
}
```

### 7.2 DomainBlocked

```go
// DomainBlocked はドメインがブロックされた際に発行される
type DomainBlocked struct {
    BaseEvent
    Domain          string    `json:"domain"`
    BlockedBy       string    `json:"blocked_by"`
    BlockReason     string    `json:"block_reason"`
    BlockType       string    `json:"block_type"`
    AffectedActors  int       `json:"affected_actors"`
    ExpiresAt       *time.Time `json:"expires_at,omitempty"`
}
```

### 7.3 ContentReported

```go
// ContentReported はコンテンツが通報された際に発行される
type ContentReported struct {
    BaseEvent
    ReportID        string    `json:"report_id"`
    ReportedURI     string    `json:"reported_uri"`
    ReporterURI     string    `json:"reporter_uri"`
    ReportReason    string    `json:"report_reason"`
    ReportDetails   string    `json:"report_details"`
    TargetPlatform  string    `json:"target_platform"`
    ForwardedTo     []string  `json:"forwarded_to"` // 転送先インスタンス
}
```

## 8. Circuit Breaker関連イベント

### 8.1 CircuitBreakerOpened

```go
// CircuitBreakerOpened はサーキットブレーカーが開いた際に発行される
type CircuitBreakerOpened struct {
    BaseEvent
    Domain          string    `json:"domain"`
    FailureRate     float64   `json:"failure_rate"`
    FailureCount    int       `json:"failure_count"`
    ObservationWindow time.Duration `json:"observation_window"`
    WillRetryAt     time.Time `json:"will_retry_at"`
}
```

### 8.2 CircuitBreakerClosed

```go
// CircuitBreakerClosed はサーキットブレーカーが閉じた際に発行される
type CircuitBreakerClosed struct {
    BaseEvent
    Domain          string        `json:"domain"`
    RecoveryTime    time.Duration `json:"recovery_time"`
    SuccessRate     float64       `json:"success_rate"`
}
```

## 9. Platform Detection関連イベント

### 9.1 PlatformDetected

```go
// PlatformDetected はプラットフォームが検出された際に発行される
type PlatformDetected struct {
    BaseEvent
    Domain          string            `json:"domain"`
    Platform        string            `json:"platform"`
    Version         string            `json:"version"`
    DetectionMethod string            `json:"detection_method"` // nodeinfo, webfinger, actor_pattern
    Capabilities    map[string]bool   `json:"capabilities"`
    CustomNamespaces []string         `json:"custom_namespaces"`
}
```

### 9.2 PlatformCapabilitiesUpdated

```go
// PlatformCapabilitiesUpdated はプラットフォーム機能が更新された際に発行される
type PlatformCapabilitiesUpdated struct {
    BaseEvent
    Domain          string          `json:"domain"`
    Platform        string          `json:"platform"`
    AddedCapabilities   []string    `json:"added_capabilities"`
    RemovedCapabilities []string    `json:"removed_capabilities"`
    UpdatedVersion  string          `json:"updated_version"`
}
```

## 10. イベントハンドラーインターフェース

```go
// EventHandler はドメインイベントを処理するインターフェース
type EventHandler interface {
    HandleEvent(event DomainEvent) error
    CanHandle(eventType string) bool
    GetHandlerName() string
}

// EventPublisher はドメインイベントを発行するインターフェース
type EventPublisher interface {
    Publish(ctx context.Context, event DomainEvent) error
    PublishBatch(ctx context.Context, events []DomainEvent) error
}

// EventStore はドメインイベントを永続化するインターフェース
type EventStore interface {
    Save(ctx context.Context, event DomainEvent) error
    GetByAggregateID(ctx context.Context, aggregateID string) ([]DomainEvent, error)
    GetByEventType(ctx context.Context, eventType string, limit int) ([]DomainEvent, error)
    GetAfter(ctx context.Context, timestamp time.Time) ([]DomainEvent, error)
}
```

## 11. イベントバスの実装

```go
// EventBus はイベントの配信を管理
type EventBus struct {
    handlers    map[string][]EventHandler
    publisher   EventPublisher
    store       EventStore
    logger      Logger
    metrics     MetricsCollector
    mu          sync.RWMutex
}

func NewEventBus(publisher EventPublisher, store EventStore) *EventBus {
    return &EventBus{
        handlers:  make(map[string][]EventHandler),
        publisher: publisher,
        store:     store,
    }
}

func (bus *EventBus) Register(eventType string, handler EventHandler) {
    bus.mu.Lock()
    defer bus.mu.Unlock()
    
    bus.handlers[eventType] = append(bus.handlers[eventType], handler)
}

func (bus *EventBus) Emit(ctx context.Context, event DomainEvent) error {
    // 1. イベントストアに保存
    if err := bus.store.Save(ctx, event); err != nil {
        return fmt.Errorf("failed to store event: %w", err)
    }
    
    // 2. 同期ハンドラーの実行
    bus.mu.RLock()
    handlers := bus.handlers[event.GetEventType()]
    bus.mu.RUnlock()
    
    for _, handler := range handlers {
        if err := handler.HandleEvent(event); err != nil {
            bus.logger.Error("handler failed", 
                "handler", handler.GetHandlerName(),
                "event", event.GetEventID(),
                "error", err)
            // エラーを記録するが処理は継続
        }
    }
    
    // 3. 非同期配信（他サービスへ）
    if err := bus.publisher.Publish(ctx, event); err != nil {
        bus.logger.Error("failed to publish event",
            "event", event.GetEventID(),
            "error", err)
    }
    
    // 4. メトリクス記録
    bus.metrics.IncrementEventCount(event.GetEventType())
    
    return nil
}
```

## 12. イベントソーシング対応

```go
// EventSourcedAggregate はイベントソーシングをサポートする集約
type EventSourcedAggregate interface {
    GetID() string
    GetVersion() int
    GetUncommittedEvents() []DomainEvent
    MarkEventsAsCommitted()
    ApplyEvent(event DomainEvent) error
}

// RemoteActorAggregate のイベントソーシング実装例
type RemoteActorAggregate struct {
    id               string
    version          int
    uncommittedEvents []DomainEvent
    
    // 状態
    actorURI         string
    username         string
    domain           string
    publicKeyPEM     string
    suspended        bool
    trustScore       float64
}

func (a *RemoteActorAggregate) ApplyEvent(event DomainEvent) error {
    switch e := event.(type) {
    case *RemoteActorDiscovered:
        a.actorURI = e.ActorURI
        a.username = e.Username
        a.domain = e.Domain
        a.publicKeyPEM = e.PublicKeyPEM
        
    case *RemoteActorSuspended:
        a.suspended = true
        
    case *RemoteActorUnsuspended:
        a.suspended = false
        
    default:
        return fmt.Errorf("unknown event type: %T", e)
    }
    
    a.version++
    return nil
}

func (a *RemoteActorAggregate) Suspend(reason string, suspendedBy string) error {
    if a.suspended {
        return ErrAlreadySuspended
    }
    
    event := &RemoteActorSuspended{
        BaseEvent: NewBaseEvent(a.id, "RemoteActorSuspended"),
        ActorURI: a.actorURI,
        SuspendReason: reason,
        SuspendedBy: suspendedBy,
    }
    
    if err := a.ApplyEvent(event); err != nil {
        return err
    }
    
    a.uncommittedEvents = append(a.uncommittedEvents, event)
    return nil
}
```

## 13. メトリクスとモニタリング

```go
// EventMetrics はイベント関連のメトリクスを収集
type EventMetrics struct {
    eventCounter      *prometheus.CounterVec
    eventDuration     *prometheus.HistogramVec
    eventErrors       *prometheus.CounterVec
    uncommittedEvents *prometheus.GaugeVec
}

func (m *EventMetrics) RecordEvent(eventType string, duration time.Duration, err error) {
    labels := prometheus.Labels{
        "event_type": eventType,
        "status":     m.getStatus(err),
    }
    
    m.eventCounter.With(labels).Inc()
    m.eventDuration.With(labels).Observe(duration.Seconds())
    
    if err != nil {
        m.eventErrors.With(prometheus.Labels{
            "event_type": eventType,
            "error_type": m.classifyError(err),
        }).Inc()
    }
}
```

## 14. テスト戦略

```go
// EventTestHelper はイベントのテストを支援
type EventTestHelper struct {
    capturedEvents []DomainEvent
    mu            sync.Mutex
}

func (h *EventTestHelper) CaptureEvent(event DomainEvent) {
    h.mu.Lock()
    defer h.mu.Unlock()
    h.capturedEvents = append(h.capturedEvents, event)
}

func (h *EventTestHelper) AssertEventPublished(t *testing.T, eventType string) {
    h.mu.Lock()
    defer h.mu.Unlock()
    
    for _, event := range h.capturedEvents {
        if event.GetEventType() == eventType {
            return
        }
    }
    
    t.Errorf("expected event %s was not published", eventType)
}

// テストケース例
func TestRemoteActorSuspension(t *testing.T) {
    helper := &EventTestHelper{}
    aggregate := NewRemoteActorAggregate("actor-123")
    
    err := aggregate.Suspend("spam", "admin-001")
    assert.NoError(t, err)
    
    events := aggregate.GetUncommittedEvents()
    assert.Len(t, events, 1)
    
    suspendedEvent, ok := events[0].(*RemoteActorSuspended)
    assert.True(t, ok)
    assert.Equal(t, "spam", suspendedEvent.SuspendReason)
    assert.Equal(t, "admin-001", suspendedEvent.SuspendedBy)
}
```

## 15. まとめ

このドメインイベント仕様により、avion-activitypubサービスは：

1. **完全なイベント駆動アーキテクチャ**を実現
2. **監査ログとイベントソーシング**をサポート
3. **他サービスとの疎結合**を維持
4. **テスト可能性**を向上
5. **可観測性**を確保

すべてのビジネスロジックの重要な状態変更がイベントとして記録され、システム全体の透明性と追跡可能性が保証されます。