# Design Doc: avion-timeline

**Author:** Avion Team
**Last Updated:** 2025/01/19
**Status:** APPROVED

## 1. Summary

avion-timelineは、Avionプラットフォームにおける各種タイムライン（HOME、LOCAL、GLOBAL、SOCIAL、LIST、HASHTAG、MEDIA）の生成、取得、リアルタイム更新を担当するマイクロサービスです。DDD 4層アーキテクチャとCQRSパターンに厳密に準拠し、高性能かつスケーラブルなタイムライン機能を提供します。

### 主要な責務
- 7種類のタイムライン生成と管理
- ハイブリッドFan-out戦略による効率的な配信
- Server-Sent Events (SSE) によるリアルタイム更新
- Redisベースの高性能キャッシング
- カーソルベースページネーション

## 2. Architecture (4層アーキテクチャ)

### 2.1 Handler Layer (プレゼンテーション層)

#### gRPC Handlers

```go
// TimelineServiceHandler - gRPCサービスハンドラー
type TimelineServiceHandler struct {
    getHomeTimelineUseCase       query.GetHomeTimelineQueryUseCase
    getLocalTimelineUseCase      query.GetLocalTimelineQueryUseCase
    getGlobalTimelineUseCase     query.GetGlobalTimelineQueryUseCase
    getSocialTimelineUseCase     query.GetSocialTimelineQueryUseCase
    getListTimelineUseCase       query.GetListTimelineQueryUseCase
    getHashtagTimelineUseCase    query.GetHashtagTimelineQueryUseCase
    getMediaTimelineUseCase      query.GetMediaTimelineQueryUseCase
    createListCommandUseCase     command.CreateListCommandUseCase
    updateListCommandUseCase     command.UpdateListCommandUseCase
    deleteListCommandUseCase     command.DeleteListCommandUseCase
    logger                       *slog.Logger
    metricsCollector            *metrics.Collector
}

// GetHomeTimeline - ホームタイムライン取得エンドポイント
func (h *TimelineServiceHandler) GetHomeTimeline(
    ctx context.Context,
    req *pb.GetHomeTimelineRequest,
) (*pb.GetHomeTimelineResponse, error) {
    // 認証・認可チェック
    userID, err := auth.ExtractUserID(ctx)
    if err != nil {
        return nil, status.Error(codes.Unauthenticated, "unauthorized")
    }

    // Query UseCase呼び出し
    result, err := h.getHomeTimelineUseCase.Execute(ctx, query.GetHomeTimelineQuery{
        UserID: userID,
        Cursor: req.GetCursor(),
        Limit:  req.GetLimit(),
        Filter: convertFilter(req.GetFilter()),
    })
    
    if err != nil {
        return nil, handleError(err)
    }

    return &pb.GetHomeTimelineResponse{
        Entries:    convertEntries(result.Entries),
        NextCursor: result.NextCursor,
        HasMore:    result.HasMore,
    }, nil
}
```

#### SSE Handlers

```go
// SSEHandler - Server-Sent Events ハンドラー
type SSEHandler struct {
    establishConnectionUseCase   command.EstablishSSEConnectionCommandUseCase
    subscribeTimelineUseCase     command.SubscribeTimelineCommandUseCase
    unsubscribeTimelineUseCase   command.UnsubscribeTimelineCommandUseCase
    closeConnectionUseCase       command.CloseSSEConnectionCommandUseCase
    connectionManager            *sse.ConnectionManager
    logger                       *slog.Logger
}

// HandleSSE - SSE接続処理
func (h *SSEHandler) HandleSSE(w http.ResponseWriter, r *http.Request) {
    // SSEヘッダー設定
    w.Header().Set("Content-Type", "text/event-stream")
    w.Header().Set("Cache-Control", "no-cache")
    w.Header().Set("Connection", "keep-alive")
    
    // 接続確立
    connectionID, err := h.establishConnectionUseCase.Execute(r.Context(), command.EstablishSSEConnectionCommand{
        UserID:       extractUserID(r),
        LastEventID:  r.Header.Get("Last-Event-ID"),
        TimelineTypes: parseTimelineTypes(r.URL.Query().Get("types")),
    })
    
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    
    // イベントストリーミング
    h.streamEvents(w, r.Context(), connectionID)
}
```

### 2.2 UseCase Layer (アプリケーション層)

#### Command UseCases (CQRS Command側)

```go
// ProcessDropEventCommandUseCase - Drop作成イベント処理
type ProcessDropEventCommandUseCase struct {
    fanoutOperationRepo      repository.FanoutOperationRepository
    timelineRepo            repository.TimelineRepository
    fanoutStrategyService   domain.FanoutStrategyService
    timelinePolicyService   domain.TimelinePolicyService
    eventPublisher          event.Publisher
    logger                  *slog.Logger
}

func (uc *ProcessDropEventCommandUseCase) Execute(
    ctx context.Context,
    cmd ProcessDropEventCommand,
) error {
    // FanoutOperation集約の生成
    fanoutOp := domain.NewFanoutOperation(
        domain.NewFanoutOperationID(),
        cmd.DropEvent,
    )
    
    // Fan-out戦略の決定
    strategy := uc.fanoutStrategyService.DetermineStrategy(
        cmd.DropEvent.AuthorID,
        cmd.DropEvent.FollowerCount,
    )
    
    // 配信対象タイムラインの決定
    targets := uc.timelinePolicyService.DetermineUpdateTargets(
        cmd.DropEvent,
        strategy,
    )
    
    // Fan-out処理の実行
    if err := fanoutOp.StartFanout(cmd.DropEvent); err != nil {
        return err
    }
    
    for _, target := range targets {
        if err := uc.processTimelineUpdate(ctx, target, cmd.DropEvent); err != nil {
            fanoutOp.FailFanout(err.Error())
            return err
        }
        fanoutOp.MarkAsDelivered(target.TimelineID)
    }
    
    // 完了
    if err := fanoutOp.CompleteFanout(); err != nil {
        return err
    }
    
    // イベント発行
    uc.eventPublisher.Publish(ctx, domain.FanoutCompletedEvent{
        OperationID: fanoutOp.GetID(),
        ProcessedCount: len(targets),
    })
    
    return uc.fanoutOperationRepo.Save(ctx, fanoutOp)
}

// CreateListCommandUseCase - リスト作成
type CreateListCommandUseCase struct {
    userListRepo     repository.UserListRepository
    userService      external.UserService
    eventPublisher   event.Publisher
    logger          *slog.Logger
}

func (uc *CreateListCommandUseCase) Execute(
    ctx context.Context,
    cmd CreateListCommand,
) (*CreateListResult, error) {
    // ユーザーのリスト作成上限チェック
    existingLists, err := uc.userListRepo.FindByOwnerID(ctx, cmd.OwnerID)
    if err != nil {
        return nil, err
    }
    
    if len(existingLists) >= domain.MaxListsPerUser {
        return nil, domain.ErrMaxListsExceeded
    }
    
    // UserList集約の生成
    list := domain.NewUserList(
        domain.NewListID(),
        cmd.Name,
        cmd.Description,
        cmd.OwnerID,
        cmd.Visibility,
    )
    
    // 永続化
    if err := uc.userListRepo.Save(ctx, list); err != nil {
        return nil, err
    }
    
    // イベント発行
    uc.eventPublisher.Publish(ctx, domain.ListCreatedEvent{
        ListID:     list.GetID(),
        OwnerID:    list.GetOwnerID(),
        CreatedAt:  time.Now(),
    })
    
    return &CreateListResult{
        ListID: list.GetID(),
    }, nil
}
```

#### Query UseCases (CQRS Query側)

```go
// GetHomeTimelineQueryUseCase - ホームタイムライン取得
type GetHomeTimelineQueryUseCase struct {
    timelineQueryService    query.TimelineQueryService
    cacheQueryService      query.CacheQueryService
    userQueryService       external.UserQueryService
    dropQueryService       external.DropQueryService
    logger                 *slog.Logger
}

func (uc *GetHomeTimelineQueryUseCase) Execute(
    ctx context.Context,
    query GetHomeTimelineQuery,
) (*GetHomeTimelineResult, error) {
    // キャッシュチェック
    cached, err := uc.cacheQueryService.GetCachedTimeline(ctx, 
        fmt.Sprintf("home:%s", query.UserID))
    if err == nil && cached != nil {
        return uc.buildResultFromCache(cached, query.Cursor, query.Limit), nil
    }
    
    // キャッシュミス時は再構築
    followedUsers, err := uc.userQueryService.GetFollowedUserIDs(ctx, query.UserID)
    if err != nil {
        return nil, err
    }
    
    // タイムライン構築
    entries, err := uc.timelineQueryService.BuildHomeTimeline(ctx, TimelineBuildQuery{
        UserID:        query.UserID,
        FollowedUsers: followedUsers,
        Cursor:        query.Cursor,
        Limit:         query.Limit,
        Filter:        query.Filter,
    })
    
    if err != nil {
        return nil, err
    }
    
    // Drop詳細情報の取得
    dropIDs := extractDropIDs(entries)
    drops, err := uc.dropQueryService.GetDropsByIDs(ctx, dropIDs)
    if err != nil {
        return nil, err
    }
    
    // キャッシュ更新（非同期）
    go uc.updateCache(ctx, query.UserID, entries)
    
    return &GetHomeTimelineResult{
        Entries:    enrichEntries(entries, drops),
        NextCursor: generateNextCursor(entries),
        HasMore:    len(entries) == query.Limit,
    }, nil
}

// GetListTimelineQueryUseCase - リストタイムライン取得
type GetListTimelineQueryUseCase struct {
    listQueryService       query.ListQueryService
    timelineQueryService   query.TimelineQueryService
    cacheQueryService     query.CacheQueryService
    dropQueryService      external.DropQueryService
    logger               *slog.Logger
}

func (uc *GetListTimelineQueryUseCase) Execute(
    ctx context.Context,
    query GetListTimelineQuery,
) (*GetListTimelineResult, error) {
    // リストアクセス権限チェック
    list, err := uc.listQueryService.GetList(ctx, query.ListID)
    if err != nil {
        return nil, err
    }
    
    if !list.CanViewList(query.RequesterID) {
        return nil, domain.ErrListAccessDenied
    }
    
    // リストメンバーの取得
    memberIDs := list.GetMemberIDs()
    
    // タイムライン構築
    entries, err := uc.timelineQueryService.BuildListTimeline(ctx, TimelineBuildQuery{
        ListID:     query.ListID,
        MemberIDs:  memberIDs,
        Cursor:     query.Cursor,
        Limit:      query.Limit,
    })
    
    if err != nil {
        return nil, err
    }
    
    return &GetListTimelineResult{
        Entries:    entries,
        NextCursor: generateNextCursor(entries),
        HasMore:    len(entries) == query.Limit,
    }, nil
}
```

### 2.3 Domain Layer (ドメイン層)

#### Domain Services

```go
// FanoutStrategyService - Fan-out戦略決定サービス
type FanoutStrategyService struct {
    userStatsRepo repository.UserStatsRepository
    config        *FanoutConfig
}

func (s *FanoutStrategyService) DetermineStrategy(
    authorID UserID,
    followerCount int,
) FanoutStrategy {
    // フォロワー数に基づく戦略決定
    if followerCount < s.config.PushThreshold { // < 1000
        return PushFanout
    } else if followerCount > s.config.PullThreshold { // > 10000
        return PullFanout
    }
    return HybridFanout
}

func (s *FanoutStrategyService) ExecutePushFanout(
    ctx context.Context,
    dropEvent DropEvent,
    targetTimelines []TimelineID,
) error {
    // Push型: 即座に全フォロワーのタイムラインに配信
    for _, timelineID := range targetTimelines {
        timeline, err := s.loadTimeline(ctx, timelineID)
        if err != nil {
            continue
        }
        
        entry := NewTimelineEntry(
            dropEvent.DropID,
            dropEvent.Timestamp,
            dropEvent.AuthorID,
        )
        
        if err := timeline.AddEntry(entry); err != nil {
            return err
        }
        
        if err := s.saveTimeline(ctx, timeline); err != nil {
            return err
        }
    }
    return nil
}

// TimelinePolicyService - タイムライン表示ポリシー
type TimelinePolicyService struct {
    muteRepo       repository.MuteRepository
    blockRepo      repository.BlockRepository
    privacyService external.PrivacyService
}

func (s *TimelinePolicyService) ShouldIncludeInTimeline(
    drop Drop,
    timelineType TimelineType,
    viewerID UserID,
) bool {
    // ミュートチェック
    if s.isMuted(drop.AuthorID, viewerID) {
        return false
    }
    
    // ブロックチェック
    if s.isBlocked(drop.AuthorID, viewerID) {
        return false
    }
    
    // 可視性チェック
    switch drop.Visibility {
    case VisibilityPublic:
        return true
    case VisibilityUnlisted:
        return timelineType != TimelineTypeGlobal
    case VisibilityFollowersOnly:
        return s.isFollowing(viewerID, drop.AuthorID)
    case VisibilityPrivate:
        return drop.AuthorID == viewerID
    default:
        return false
    }
}

// TimelineBuilderService - タイムライン構築サービス
type TimelineBuilderService struct {
    dropRepo         repository.DropRepository
    followRepo       external.FollowRepository
    policyService    *TimelinePolicyService
    cacheService     *CacheManagementService
}

func (s *TimelineBuilderService) BuildHomeTimeline(
    ctx context.Context,
    userID UserID,
    cursor TimelineCursor,
    limit int,
) (*Timeline, error) {
    // フォロー中ユーザーの取得
    followedUsers, err := s.followRepo.GetFollowedUserIDs(ctx, userID)
    if err != nil {
        return nil, err
    }
    
    // Timeline集約の生成
    timeline := NewTimeline(
        NewTimelineID(userID, TimelineTypeHome),
        TimelineTypeHome,
        userID,
    )
    
    // 各フォローユーザーの最新投稿を収集
    for _, followedUserID := range followedUsers {
        drops, err := s.dropRepo.FindByAuthorID(ctx, followedUserID, cursor, limit)
        if err != nil {
            continue
        }
        
        for _, drop := range drops {
            if s.policyService.ShouldIncludeInTimeline(drop, TimelineTypeHome, userID) {
                entry := NewTimelineEntry(drop.ID, drop.Timestamp, drop.AuthorID)
                timeline.AddEntry(entry)
            }
        }
    }
    
    // ソートとトリミング
    timeline.SortByTimestamp()
    timeline.TruncateToLimit(limit)
    
    return timeline, nil
}
```

### 2.4 Infrastructure Layer (インフラストラクチャ層)

#### Repository Implementations

```go
// TimelineRepositoryImpl - Timeline集約のリポジトリ実装
type TimelineRepositoryImpl struct {
    redisClient  *redis.Client
    pgClient     *pgx.Pool
    serializer   Serializer
    logger       *slog.Logger
}

func (r *TimelineRepositoryImpl) FindByID(
    ctx context.Context,
    id domain.TimelineID,
) (*domain.Timeline, error) {
    // Redisから取得を試みる
    key := fmt.Sprintf("timeline:%s", id)
    data, err := r.redisClient.Get(ctx, key).Bytes()
    if err == nil {
        timeline := &domain.Timeline{}
        if err := r.serializer.Unmarshal(data, timeline); err == nil {
            return timeline, nil
        }
    }
    
    // キャッシュミスの場合はPostgreSQLから再構築
    return r.reconstructFromDB(ctx, id)
}

func (r *TimelineRepositoryImpl) Save(
    ctx context.Context,
    timeline *domain.Timeline,
) error {
    // Redis Sorted Setに保存
    key := fmt.Sprintf("timeline:%s", timeline.GetID())
    
    pipe := r.redisClient.Pipeline()
    
    // エントリーをSorted Setに追加
    for _, entry := range timeline.GetEntries() {
        score := float64(entry.GetTimestamp().Unix())
        member := entry.GetDropID().String()
        pipe.ZAdd(ctx, key, redis.Z{
            Score:  score,
            Member: member,
        })
    }
    
    // TTL設定（24時間）
    pipe.Expire(ctx, key, 24*time.Hour)
    
    _, err := pipe.Exec(ctx)
    return err
}

// UserListRepositoryImpl - UserList集約のリポジトリ実装
type UserListRepositoryImpl struct {
    db     *pgx.Pool
    logger *slog.Logger
}

func (r *UserListRepositoryImpl) Save(
    ctx context.Context,
    list *domain.UserList,
) error {
    query := `
        INSERT INTO user_lists (
            list_id, name, description, owner_id, 
            visibility, created_at, updated_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7)
        ON CONFLICT (list_id) DO UPDATE SET
            name = EXCLUDED.name,
            description = EXCLUDED.description,
            visibility = EXCLUDED.visibility,
            updated_at = EXCLUDED.updated_at
    `
    
    _, err := r.db.Exec(ctx, query,
        list.GetID(),
        list.GetName(),
        list.GetDescription(),
        list.GetOwnerID(),
        list.GetVisibility(),
        list.GetCreatedAt(),
        list.GetUpdatedAt(),
    )
    
    if err != nil {
        return err
    }
    
    // メンバーの保存
    return r.saveMembers(ctx, list.GetID(), list.GetMembers())
}

// SSEConnectionManagerImpl - SSE接続管理
type SSEConnectionManagerImpl struct {
    connections  sync.Map // ConnectionID -> *Connection
    redisClient  *redis.Client
    logger       *slog.Logger
}

func (m *SSEConnectionManagerImpl) AddConnection(
    ctx context.Context,
    conn *domain.RealtimeConnection,
) error {
    // メモリに保存
    m.connections.Store(conn.GetID(), conn)
    
    // Redisにメタデータを保存（Pod間共有用）
    key := fmt.Sprintf("sse:connection:%s", conn.GetID())
    data := map[string]interface{}{
        "user_id":     conn.GetUserID(),
        "pod_name":    conn.GetPodName(),
        "created_at":  conn.GetCreatedAt(),
        "subscribed":  conn.GetSubscribedTypes(),
    }
    
    return m.redisClient.HMSet(ctx, key, data).Err()
}

func (m *SSEConnectionManagerImpl) BroadcastEvent(
    ctx context.Context,
    event domain.TimelineEvent,
) error {
    // 該当するタイムラインタイプを購読している接続を検索
    m.connections.Range(func(key, value interface{}) bool {
        conn := value.(*domain.RealtimeConnection)
        if conn.IsSubscribedTo(event.GetTimelineType()) {
            if err := conn.SendEvent(event); err != nil {
                m.logger.Error("failed to send event",
                    "connection_id", conn.GetID(),
                    "error", err)
            }
        }
        return true
    })
    
    return nil
}
```

#### External Service Clients

```go
// UserServiceClient - avion-userサービスクライアント
type UserServiceClient struct {
    grpcClient pb.UserServiceClient
    cache      *cache.LRU
    logger     *slog.Logger
}

func (c *UserServiceClient) GetFollowedUserIDs(
    ctx context.Context,
    userID string,
) ([]string, error) {
    // キャッシュチェック
    if cached, ok := c.cache.Get(fmt.Sprintf("follows:%s", userID)); ok {
        return cached.([]string), nil
    }
    
    // gRPC呼び出し
    resp, err := c.grpcClient.GetFollows(ctx, &pb.GetFollowsRequest{
        UserId: userID,
    })
    
    if err != nil {
        return nil, fmt.Errorf("failed to get follows: %w", err)
    }
    
    followedIDs := make([]string, len(resp.Follows))
    for i, follow := range resp.Follows {
        followedIDs[i] = follow.FollowedUserId
    }
    
    // キャッシュ更新
    c.cache.Set(fmt.Sprintf("follows:%s", userID), followedIDs, 5*time.Minute)
    
    return followedIDs, nil
}

// DropServiceClient - avion-dropサービスクライアント
type DropServiceClient struct {
    grpcClient pb.DropServiceClient
    cache      *cache.LRU
    logger     *slog.Logger
}

func (c *DropServiceClient) GetDropsByIDs(
    ctx context.Context,
    dropIDs []string,
) (map[string]*Drop, error) {
    drops := make(map[string]*Drop)
    uncachedIDs := []string{}
    
    // キャッシュから取得
    for _, id := range dropIDs {
        if cached, ok := c.cache.Get(fmt.Sprintf("drop:%s", id)); ok {
            drops[id] = cached.(*Drop)
        } else {
            uncachedIDs = append(uncachedIDs, id)
        }
    }
    
    // キャッシュにないものをgRPCで取得
    if len(uncachedIDs) > 0 {
        resp, err := c.grpcClient.GetDropsByIds(ctx, &pb.GetDropsByIdsRequest{
            DropIds: uncachedIDs,
        })
        
        if err != nil {
            return nil, fmt.Errorf("failed to get drops: %w", err)
        }
        
        for _, pbDrop := range resp.Drops {
            drop := convertFromProto(pbDrop)
            drops[drop.ID] = drop
            c.cache.Set(fmt.Sprintf("drop:%s", drop.ID), drop, 10*time.Minute)
        }
    }
    
    return drops, nil
}
```

#### Event Subscribers

```go
// DropEventSubscriber - Drop作成イベントの購読
type DropEventSubscriber struct {
    redisClient              *redis.Client
    processDropEventUseCase  command.ProcessDropEventCommandUseCase
    logger                   *slog.Logger
}

func (s *DropEventSubscriber) Subscribe(ctx context.Context) error {
    pubsub := s.redisClient.Subscribe(ctx, "drops:created", "drops:deleted")
    defer pubsub.Close()
    
    ch := pubsub.Channel()
    for msg := range ch {
        go s.handleMessage(ctx, msg)
    }
    
    return nil
}

func (s *DropEventSubscriber) handleMessage(ctx context.Context, msg *redis.Message) {
    switch msg.Channel {
    case "drops:created":
        var event DropCreatedEvent
        if err := json.Unmarshal([]byte(msg.Payload), &event); err != nil {
            s.logger.Error("failed to unmarshal event", "error", err)
            return
        }
        
        if err := s.processDropEventUseCase.Execute(ctx, command.ProcessDropEventCommand{
            DropEvent: event,
        }); err != nil {
            s.logger.Error("failed to process drop event", "error", err)
        }
        
    case "drops:deleted":
        // Drop削除処理
        s.handleDropDeleted(ctx, msg.Payload)
    }
}
```

## 3. Database Schema

### PostgreSQL Schema

```sql
-- ユーザーリスト
CREATE TABLE user_lists (
    list_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500),
    owner_id VARCHAR(26) NOT NULL,
    visibility VARCHAR(20) NOT NULL CHECK (visibility IN ('PUBLIC', 'PRIVATE', 'UNLISTED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT fk_owner FOREIGN KEY (owner_id) 
        REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_owner_id (owner_id),
    INDEX idx_visibility (visibility),
    INDEX idx_created_at (created_at DESC)
);

-- リストメンバー
CREATE TABLE list_members (
    member_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    list_id UUID NOT NULL,
    user_id VARCHAR(26) NOT NULL,
    added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    added_by VARCHAR(26) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    notification_enabled BOOLEAN DEFAULT true,
    
    CONSTRAINT fk_list FOREIGN KEY (list_id) 
        REFERENCES user_lists(list_id) ON DELETE CASCADE,
    CONSTRAINT fk_user FOREIGN KEY (user_id) 
        REFERENCES users(user_id) ON DELETE CASCADE,
    UNIQUE KEY uk_list_user (list_id, user_id),
    INDEX idx_list_id (list_id),
    INDEX idx_user_id (user_id),
    INDEX idx_status (status)
);

-- Fan-out操作ログ
CREATE TABLE fanout_operations (
    operation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    drop_id VARCHAR(26) NOT NULL,
    strategy VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    failure_reason TEXT,
    processed_count INTEGER DEFAULT 0,
    retry_count INTEGER DEFAULT 0,
    
    INDEX idx_drop_id (drop_id),
    INDEX idx_status (status),
    INDEX idx_started_at (started_at DESC)
);

-- タイムラインメタデータ（バックアップ用）
CREATE TABLE timeline_metadata (
    timeline_id VARCHAR(100) PRIMARY KEY,
    timeline_type VARCHAR(20) NOT NULL,
    owner_id VARCHAR(26),
    last_updated TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    entry_count INTEGER DEFAULT 0,
    cache_version INTEGER DEFAULT 1,
    
    INDEX idx_owner_id (owner_id),
    INDEX idx_type (timeline_type),
    INDEX idx_last_updated (last_updated DESC)
);
```

### Redis Data Structures

```redis
# Timeline Sorted Set
# Key: timeline:{user_id}:{type}
# Score: timestamp (Unix epoch)
# Member: drop_id
ZADD timeline:user123:HOME 1704067200 "drop456"
ZRANGE timeline:user123:HOME 0 99 WITHSCORES

# SSE Connection Metadata
# Key: sse:connection:{connection_id}
HSET sse:connection:conn789 user_id "user123" pod_name "timeline-pod-1" 

# Cache Management
# Key: cache:timeline:{timeline_id}:meta
HSET cache:timeline:user123:HOME:meta hit_count 1523 size_bytes 45678

# List Timeline Members Cache
# Key: list:members:{list_id}
SADD list:members:list456 "user123" "user789"

# Active SSE Connections per User
# Key: sse:user:{user_id}:connections
SADD sse:user:user123:connections "conn789" "conn012"
```

## 4. API Specifications

### gRPC Service Definition

```protobuf
syntax = "proto3";
package timeline.v1;

service TimelineService {
    // Timeline Query Operations
    rpc GetHomeTimeline(GetHomeTimelineRequest) returns (GetHomeTimelineResponse);
    rpc GetLocalTimeline(GetLocalTimelineRequest) returns (GetLocalTimelineResponse);
    rpc GetGlobalTimeline(GetGlobalTimelineRequest) returns (GetGlobalTimelineResponse);
    rpc GetSocialTimeline(GetSocialTimelineRequest) returns (GetSocialTimelineResponse);
    rpc GetListTimeline(GetListTimelineRequest) returns (GetListTimelineResponse);
    rpc GetHashtagTimeline(GetHashtagTimelineRequest) returns (GetHashtagTimelineResponse);
    rpc GetMediaTimeline(GetMediaTimelineRequest) returns (GetMediaTimelineResponse);
    
    // List Management Operations
    rpc CreateList(CreateListRequest) returns (CreateListResponse);
    rpc UpdateList(UpdateListRequest) returns (UpdateListResponse);
    rpc DeleteList(DeleteListRequest) returns (DeleteListResponse);
    rpc AddListMember(AddListMemberRequest) returns (AddListMemberResponse);
    rpc RemoveListMember(RemoveListMemberRequest) returns (RemoveListMemberResponse);
    rpc GetUserLists(GetUserListsRequest) returns (GetUserListsResponse);
}

message GetHomeTimelineRequest {
    string cursor = 1;
    int32 limit = 2;
    TimelineFilter filter = 3;
}

message GetHomeTimelineResponse {
    repeated TimelineEntry entries = 1;
    string next_cursor = 2;
    bool has_more = 3;
}

message TimelineEntry {
    string entry_id = 1;
    string drop_id = 2;
    int64 timestamp = 3;
    string author_id = 4;
    bool has_media = 5;
    bool is_repost = 6;
    string original_author_id = 7;
}

message TimelineFilter {
    bool media_only = 1;
    bool remote_only = 2;
    bool apply_mute = 3;
}
```

### SSE Event Format

```typescript
// SSE Event Types
interface TimelineEvent {
    id: string;           // Event ID (単調増加)
    type: 'message';      // SSE event type
    data: {
        event: 'ADD_DROP' | 'REMOVE_DROP' | 'UPDATE_DROP' | 'REFRESH_TIMELINE';
        timeline: 'HOME' | 'LOCAL' | 'GLOBAL' | 'SOCIAL' | 'LIST' | 'HASHTAG' | 'MEDIA';
        payload: {
            dropId?: string;
            timestamp?: number;
            reason?: string;
        };
    };
    retry?: number;       // 再接続待機時間（ミリ秒）
}

// Example SSE Stream
id: 12345
event: message
data: {"event":"ADD_DROP","timeline":"HOME","payload":{"dropId":"drop789","timestamp":1704067200}}

id: 12346
event: message
data: {"event":"REMOVE_DROP","timeline":"HOME","payload":{"dropId":"drop456","reason":"deleted"}}
```

## 5. Error Handling

### Error Code Format

すべてのエラーは `TIMELINE_[LAYER]_[ERROR_TYPE]` 形式に従います。

```go
// Domain Layer Errors
var (
    ErrTimelineNotFound         = errors.New("TIMELINE_DOMAIN_NOT_FOUND")
    ErrTimelineExpired          = errors.New("TIMELINE_DOMAIN_EXPIRED")
    ErrMaxEntriesExceeded       = errors.New("TIMELINE_DOMAIN_MAX_ENTRIES_EXCEEDED")
    ErrInvalidCursor            = errors.New("TIMELINE_DOMAIN_INVALID_CURSOR")
    ErrMaxListsExceeded         = errors.New("TIMELINE_DOMAIN_MAX_LISTS_EXCEEDED")
    ErrMaxListMembersExceeded   = errors.New("TIMELINE_DOMAIN_MAX_MEMBERS_EXCEEDED")
    ErrListAccessDenied         = errors.New("TIMELINE_DOMAIN_ACCESS_DENIED")
    ErrDuplicateListMember      = errors.New("TIMELINE_DOMAIN_DUPLICATE_MEMBER")
)

// UseCase Layer Errors
var (
    ErrFanoutTimeout           = errors.New("TIMELINE_USECASE_FANOUT_TIMEOUT")
    ErrInvalidTimelineType     = errors.New("TIMELINE_USECASE_INVALID_TYPE")
    ErrConcurrentUpdate        = errors.New("TIMELINE_USECASE_CONCURRENT_UPDATE")
    ErrEventProcessingFailed   = errors.New("TIMELINE_USECASE_EVENT_PROCESSING_FAILED")
)

// Infrastructure Layer Errors
var (
    ErrRedisConnection         = errors.New("TIMELINE_INFRA_REDIS_CONNECTION")
    ErrDatabaseConnection      = errors.New("TIMELINE_INFRA_DATABASE_CONNECTION")
    ErrCacheCorrupted          = errors.New("TIMELINE_INFRA_CACHE_CORRUPTED")
    ErrSSEConnectionLost       = errors.New("TIMELINE_INFRA_SSE_CONNECTION_LOST")
    ErrExternalServiceTimeout  = errors.New("TIMELINE_INFRA_EXTERNAL_TIMEOUT")
)
```

## 6. Testing Strategy

### Unit Tests (90%+ coverage)

```go
func TestTimeline_AddEntry(t *testing.T) {
    tests := []struct {
        name        string
        timeline    *domain.Timeline
        entry       *domain.TimelineEntry
        wantErr     error
        wantCount   int
    }{
        {
            name:     "正常なエントリー追加",
            timeline: domain.NewTimeline(/*...*/),
            entry:    domain.NewTimelineEntry(/*...*/),
            wantErr:  nil,
            wantCount: 1,
        },
        {
            name:     "重複エントリー",
            timeline: timelineWithEntry,
            entry:    duplicateEntry,
            wantErr:  domain.ErrDuplicateEntry,
            wantCount: 1,
        },
        {
            name:     "最大エントリー数超過",
            timeline: fullTimeline,
            entry:    newEntry,
            wantErr:  domain.ErrMaxEntriesExceeded,
            wantCount: 1000,
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := tt.timeline.AddEntry(tt.entry)
            assert.Equal(t, tt.wantErr, err)
            assert.Equal(t, tt.wantCount, tt.timeline.GetEntryCount())
        })
    }
}
```

### Integration Tests

```go
func TestTimelineService_Integration(t *testing.T) {
    // テスト用のRedisとPostgreSQL
    redisContainer := setupRedisContainer(t)
    pgContainer := setupPostgreSQLContainer(t)
    
    // サービスの初期化
    timelineService := setupTimelineService(redisContainer, pgContainer)
    
    t.Run("Drop作成からタイムライン更新まで", func(t *testing.T) {
        // Drop作成イベントの発行
        event := createDropEvent()
        err := publishDropEvent(event)
        assert.NoError(t, err)
        
        // タイムライン更新の確認
        time.Sleep(100 * time.Millisecond)
        timeline, err := timelineService.GetHomeTimeline(ctx, userID)
        assert.NoError(t, err)
        assert.Contains(t, timeline.Entries, event.DropID)
    })
}
```

## 7. Performance Requirements

### レスポンスタイム
- タイムライン取得（キャッシュヒット）: p50 < 50ms, p99 < 150ms
- タイムライン取得（キャッシュミス）: p50 < 300ms, p99 < 800ms
- SSE接続確立: p50 < 30ms, p99 < 100ms
- Fan-out処理: 1000フォロワーで < 3秒

### スループット
- 同時接続数: 100万SSE接続
- タイムライン取得: 10,000 req/s
- イベント配信: 100,000 events/s

### リソース使用量
- Redis メモリ: < 80%
- CPU使用率: 平均 < 70%
- メモリ使用量: < 16GB/Pod

## 8. Security Considerations

### 8.1 セキュリティ実装ガイドライン

avion-timelineサービスでは、以下のセキュリティガイドラインに従って実装を行います：

#### 必須セキュリティ実装

1. **SQLインジェクション防止** ([SQLインジェクション防止](../common/security/sql-injection-prevention.md))
   - 全データベースクエリでPrepared Statementsを使用
   - カーソルベースページネーションの入力検証
   - フィルタリング条件の安全な構築
   - ORMのクエリビルダー使用

2. **XSS防止** ([XSS防止ガイドライン](../common/security/xss-prevention.md))
   - SSEイベントペイロードのエスケープ
   - タイムラインエントリのサニタイゼーション
   - JSONエンコーディングの適用
   - CSPヘッダー設定

3. **TLS設定** ([TLS設定ガイドライン](../common/security/tls-configuration.md))
   - SSE接続のTLS必須化
   - TLS 1.2以上のサポート
   - 強力な暗号スイート設定
   - HSTSヘッダー適用

4. **暗号化** ([暗号化ガイドライン](../common/security/encryption-guidelines.md))
   - プライベートタイムラインのキャッシュ暗号化
   - センシティブデータの暗号化
   - キャッシュキーのハッシュ化

#### セキュリティ実装チェックリスト

- [ ] タイムライン取得時のSQLインジェクション対策
- [ ] SSEペイロードのXSS対策
- [ ] TLS証明書の適切な設定
- [ ] キャッシュデータの暗号化実装
- [ ] アクセス制御の厳格な実装
- [ ] 監査ログの適切な記録

### 8.2 既存のセキュリティ考慮事項

### 認証・認可
- JWT Bearer Token認証
- タイムラインアクセス権限の検証
- リスト可視性設定の厳密な実装

### データ保護
- TLS 1.3による通信暗号化
- センシティブデータのログ出力禁止
- 適切なCORS設定

### レート制限
- ユーザー毎: 600 req/10min
- IP毎: 1200 req/10min
- SSE接続数: 10 connections/user

## 9. Monitoring & Observability

### メトリクス
```go
// Prometheusメトリクス
timeline_requests_total{method, status}
timeline_request_duration_seconds{method, quantile}
timeline_cache_hit_ratio
timeline_fanout_duration_seconds{strategy}
sse_active_connections
sse_events_sent_total{timeline_type}
```

### ログ
```json
{
    "timestamp": "2024-01-01T00:00:00Z",
    "level": "INFO",
    "service": "avion-timeline",
    "version": "1.0.0",
    "trace_id": "abc123",
    "span_id": "def456",
    "user_id": "user123",
    "method": "GetHomeTimeline",
    "duration_ms": 45,
    "cache_hit": true
}
```

### アラート
- エラー率 > 1%
- レスポンスタイム p99 > 1秒
- Redis接続エラー
- メモリ使用率 > 90%

## 10. Deployment Configuration

### Kubernetes Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: avion-timeline
  namespace: avion
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    spec:
      containers:
      - name: timeline
        image: avion/timeline:1.0.0
        resources:
          requests:
            cpu: "2"
            memory: "4Gi"
          limits:
            cpu: "4"
            memory: "8Gi"
        env:
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: timeline-secrets
              key: redis-url
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: timeline-secrets
              key: database-url
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

### HorizontalPodAutoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: avion-timeline-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: avion-timeline
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

## 11. Migration Strategy

### データ移行計画
1. 既存タイムラインデータのバックアップ
2. 新スキーマへの段階的移行
3. デュアルライト期間（新旧両方に書き込み）
4. 検証とロールバック計画

### 互換性維持
- APIバージョニング（v1, v2）
- 後方互換性の保証（最低6ヶ月）
- 段階的な機能デプロイ（Feature Flag使用）

## 12. Appendix

### 参考文献
- [Domain-Driven Design by Eric Evans](https://www.domainlanguage.com/ddd/)
- [Implementing Domain-Driven Design by Vaughn Vernon](https://www.informit.com/store/implementing-domain-driven-design-9780321834577)
- [CQRS Pattern](https://martinfowler.com/bliki/CQRS.html)
- [Server-Sent Events Specification](https://html.spec.whatwg.org/multipage/server-sent-events.html)

### 関連ドキュメント
- [PRD: avion-timeline](./prd.md)
- [Error Catalog: avion-timeline](./error-catalog.md)
- [DDD Improvement Guide](./ddd-improvement-guide.md)
- [Avion Architecture Overview](../common/architecture/architecture.md)