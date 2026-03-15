# Design Doc: avion-notification - インフラ層実装・テスト戦略

> **本文書は [designdoc.md](./designdoc.md) から分割されたドキュメントです。**
>
> **関連ドキュメント:**
> - [メインDesignDoc](./designdoc.md) - 概要、ドメインモデル、API定義
> - [通知配信チャネル](./designdoc-channels.md) - SSE配信、WebPush実装、チャネル選択ロジック
> - [通知グループ化・優先度](./designdoc-grouping.md) - グループ化、優先度計算、バッチ処理

---

## 12. 構造化ログ戦略

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
    Service     string    `json:"service"`     // "avion-notification"
    Version     string    `json:"version"`     // サービスバージョン
    TraceID     string    `json:"trace_id"`    // OpenTelemetry TraceID
    SpanID      string    `json:"span_id"`     // OpenTelemetry SpanID

    // コンテキストフィールド
    UserID      string    `json:"user_id,omitempty"`
    NotificationID string `json:"notification_id,omitempty"`
    EventID     string    `json:"event_id,omitempty"`
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
    slog.String("method", "GetNotifications"),
    slog.String("trace_id", traceID),
    slog.String("user_id", userID),
    slog.String("layer", "handler"),
)

logger.Error("gRPC request failed",
    slog.String("method", "MarkAsRead"),
    slog.String("trace_id", traceID),
    slog.String("error", err.Error()),
    slog.String("error_code", "NOTIFICATION_NOT_FOUND"),
    slog.Int64("duration_ms", duration),
)
```

#### Use Case層
```go
logger.Info("notification processing started",
    slog.String("trace_id", ctx.Value("trace_id").(string)),
    slog.String("event_type", eventType),
    slog.String("recipient_user_id", recipientUserID),
    slog.String("layer", "usecase"),
)

logger.Info("notification created",
    slog.String("notification_id", notificationID),
    slog.String("notification_type", notificationType),
    slog.String("recipient_user_id", recipientUserID),
    slog.String("actor_user_id", actorUserID),
    slog.String("layer", "usecase"),
)
```

#### Infrastructure層
```go
logger.Debug("database query executed",
    slog.String("query", "INSERT INTO notifications"),
    slog.String("table", "notifications"),
    slog.Int64("duration_ms", queryDuration),
    slog.String("layer", "infra"),
)

logger.Warn("nats jetstream event processing delay",
    slog.String("stream", "NOTIFICATIONS"),
    slog.String("consumer", "notification_workers"),
    slog.Int64("lag_ms", lagMs),
    slog.String("layer", "infra"),
)
```

### 通知イベント処理のログ
```go
// イベント受信
logger.Info("notification event received",
    slog.String("event", "event_received"),
    slog.String("event_id", eventID),
    slog.String("event_type", eventType),
    slog.String("source", "nats_jetstream"),
    slog.Bool("idempotency_check", isProcessed),
)

// 通知生成
logger.Info("notification generated",
    slog.String("event", "notification_generated"),
    slog.String("notification_type", notificationType),
    slog.String("recipient_user_id", recipientUserID),
    slog.String("actor_user_id", actorUserID),
    slog.String("target_drop_id", targetDropID),
)

// 投票通知
logger.Info("poll notification generated",
    slog.String("event", "poll_notification_generated"),
    slog.String("poll_id", pollID),
    slog.String("voter_user_id", voterUserID),
    slog.String("poll_owner_id", pollOwnerID),
    slog.String("selected_option", selectedOption),
)

// フォローリクエスト通知
logger.Info("follow request notification generated",
    slog.String("event", "follow_request_notification_generated"),
    slog.String("requester_user_id", requesterUserID),
    slog.String("target_user_id", targetUserID),
    slog.Bool("is_private_account", isPrivateAccount),
)

// 冪等性処理
logger.Debug("idempotency check",
    slog.String("event_id", eventID),
    slog.Bool("already_processed", alreadyProcessed),
    slog.String("processed_at", processedAt),
)
```

### SSE処理のログ
```go
// SSE接続確立
logger.Info("SSE connection established",
    slog.String("event", "sse_connected"),
    slog.String("user_id", userID),
    slog.String("connection_id", connID),
    slog.String("client_ip", clientIP),
)

// 通知イベント配信
logger.Debug("SSE notification sent",
    slog.String("connection_id", connID),
    slog.String("event_type", "new_notification"),
    slog.String("notification_id", notificationID),
    slog.Int("active_connections", activeConnections),
)

// 接続切断
logger.Info("SSE connection closed",
    slog.String("event", "sse_disconnected"),
    slog.String("connection_id", connID),
    slog.String("reason", reason),
    slog.Int64("duration_seconds", duration),
)
```

### Web Push処理のログ
```go
// サブスクリプション登録
logger.Info("web push subscription registered",
    slog.String("event", "push_subscription_registered"),
    slog.String("user_id", userID),
    slog.String("endpoint", maskEndpoint(endpoint)),
    slog.String("browser", browser),
)

// プッシュ通知送信
logger.Info("web push sent",
    slog.String("event", "push_sent"),
    slog.String("notification_id", notificationID),
    slog.String("user_id", userID),
    slog.Int("payload_size", payloadSize),
    slog.Bool("encrypted", true),
)

// 送信失敗
logger.Warn("web push failed",
    slog.String("event", "push_failed"),
    slog.String("endpoint", maskEndpoint(endpoint)),
    slog.Int("status_code", statusCode),
    slog.String("error", err.Error()),
    slog.Bool("subscription_invalid", isInvalid),
)
```

### 既読処理のログ
```go
logger.Info("notifications marked as read",
    slog.String("event", "notifications_read"),
    slog.String("user_id", userID),
    slog.Int("count", len(notificationIDs)),
    slog.String("notification_ids", strings.Join(notificationIDs, ",")),
)
```

### バッチ処理のログ
```go
// 古い通知削除
logger.Info("old notifications cleanup",
    slog.String("event", "cleanup_started"),
    slog.Time("cutoff_date", cutoffDate),
    slog.String("criteria", "read_and_older_than_90_days"),
)

logger.Info("old notifications deleted",
    slog.String("event", "cleanup_completed"),
    slog.Int("deleted_count", deletedCount),
    slog.Int64("duration_ms", duration),
)
```

### エラーログの詳細化
```go
logger.Error("failed to send web push",
    slog.String("user_id", userID),
    slog.String("endpoint", maskEndpoint(endpoint)),
    slog.String("error", err.Error()),
    slog.String("error_type", fmt.Sprintf("%T", err)),
    slog.String("stack_trace", string(debug.Stack())),
    slog.String("layer", "infra"),
)
```

### CRITICALレベルログの例
```go
// 通知システム全体停止時
logger.With(slog.String("level", "CRITICAL")).Error("notification system failure",
    slog.String("component", "notification_processor"),
    slog.String("error", "all_event_consumers_failed"),
    slog.Int("pending_events", pendingEventCount),
    slog.String("action", "emergency_restart_required"),
)

// データベース接続完全失敗時
logger.With(slog.String("level", "CRITICAL")).Error("database connection failure",
    slog.String("database", "notifications_db"),
    slog.String("error", "all_connections_exhausted"),
    slog.String("impact", "notification_read_write_stopped"),
    slog.String("action", "immediate_intervention_required"),
)

// Web Pushサービス系全体障害時
logger.With(slog.String("level", "CRITICAL")).Error("web push service outage",
    slog.String("component", "webpush_client"),
    slog.Float64("failure_rate", 1.0),
    slog.Int("failed_notifications", failedCount),
    slog.String("impact", "push_notifications_completely_stopped"),
)
```

### メトリクスログ
```go
// 通知統計
logger.Info("notification statistics",
    slog.String("event", "notification_stats"),
    slog.String("period", "5m"),
    slog.Int("created", created),
    slog.Int("delivered_sse", deliveredSSE),
    slog.Int("delivered_push", deliveredPush),
    slog.Int("read", read),
)

// 未読件数
logger.Debug("unread count calculated",
    slog.String("user_id", userID),
    slog.Int("unread_count", unreadCount),
    slog.Int64("query_duration_ms", queryDuration),
)
```

### ログ集約とクエリ
- **出力先**: 標準出力（Kubernetes環境ではFluentd/Fluent Bitが収集）
- **集約先**: Elasticsearch、CloudWatch Logs、またはLoki
- **クエリ例**:
  ```
  service="avion-notification" AND event="event_received" AND event_type="reaction_created"
  service="avion-notification" AND event="push_failed" AND subscription_invalid=true
  service="avion-notification" AND event="sse_connected" AND client_ip="192.168.*"
  service="avion-notification" AND layer="usecase" AND duration_ms>500
  service="avion-notification" AND level="CRITICAL"
  ```

### セキュリティ考慮事項
- Web Pushエンドポイントは部分的にマスク（最初と最後の数文字のみ表示）
- 暗号化キー（p256dh、auth）は絶対にログに含めない
- 通知の詳細内容は最小限に留める
- クライアントIPは必要最小限の場合のみ記録

## 13. エラーハンドリング戦略

> **注意:** エラーコードは[共通エラーコード標準](../common/errors/error-codes.md)に準拠します。このサービスではプレフィックス `NOTIFICATION_` を使用します。詳細は[エラーカタログ](./error-catalog.md)を参照してください。

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

// 通知関連エラー
var (
    ErrNotificationNotFound         = errors.New("notification not found")
    ErrNotificationAlreadyRead      = errors.New("notification already read")
    ErrInvalidNotificationType      = errors.New("invalid notification type")
    ErrInvalidRecipient             = errors.New("invalid recipient")
    ErrNotificationExpired          = errors.New("notification expired")
    ErrCannotDeleteNotification     = errors.New("cannot delete notification")
)

// イベント処理関連エラー
var (
    ErrEventAlreadyProcessed        = errors.New("event already processed")
    ErrInvalidEventType             = errors.New("invalid event type")
    ErrInvalidEventData             = errors.New("invalid event data")
    ErrEventProcessingFailed        = errors.New("event processing failed")
    ErrMissingRecipient             = errors.New("missing recipient in event")
    ErrPollNotFound                 = errors.New("poll not found")
    ErrPollAlreadyEnded             = errors.New("poll already ended")
    ErrInvalidPollVote              = errors.New("invalid poll vote")
    ErrFollowRequestNotAllowed      = errors.New("follow request not allowed for public account")
    ErrDropNotFound                 = errors.New("drop not found")
    ErrNoUsersToNotify              = errors.New("no users to notify for drop update")
)

// Web Push関連エラー
var (
    ErrWebPushSubscriptionNotFound  = errors.New("web push subscription not found")
    ErrInvalidWebPushEndpoint       = errors.New("invalid web push endpoint")
    ErrInvalidWebPushKeys           = errors.New("invalid web push keys")
    ErrWebPushSubscriptionExpired   = errors.New("web push subscription expired")
    ErrWebPushDeliveryFailed        = errors.New("web push delivery failed")
    ErrWebPushPayloadTooLarge       = errors.New("web push payload too large")
    ErrWebPushEncryptionFailed      = errors.New("web push encryption failed")
)

// SSE関連エラー
var (
    ErrSSEConnectionLimitExceeded   = errors.New("SSE connection limit exceeded")
    ErrSSEConnectionNotFound        = errors.New("SSE connection not found")
    ErrSSEConnectionTimeout         = errors.New("SSE connection timeout")
    ErrSSEBroadcastFailed           = errors.New("SSE broadcast failed")
)

// 通知設定関連エラー
var (
    ErrNotificationPreferenceNotFound = errors.New("notification preference not found")
    ErrCannotDisableSystemNotification = errors.New("cannot disable system notification")
    ErrInvalidDeliveryChannel       = errors.New("invalid delivery channel")
)

// 権限関連エラー
var (
    ErrUnauthorizedAccess           = errors.New("unauthorized access")
    ErrNotificationOwnerMismatch    = errors.New("notification owner mismatch")
)

// グループ化関連エラー
var (
    ErrInvalidGroupType             = errors.New("invalid group type")
    ErrGroupNotFound                = errors.New("notification group not found")
    ErrCannotGroupDifferentTypes    = errors.New("cannot group notifications of different types")
    ErrGroupLimitExceeded           = errors.New("group limit exceeded")
)

// 特定ユーザー通知設定関連エラー
var (
    ErrUserNotificationPreferenceNotFound = errors.New("user notification preference not found")
    ErrCannotNotifyBlockedUser      = errors.New("cannot set notification for blocked user")
    ErrDuplicateUserPreference      = errors.New("duplicate user notification preference")
)

// アナウンス関連エラー
var (
    ErrAnnouncementNotFound         = errors.New("announcement not found")
    ErrAnnouncementExpired          = errors.New("announcement expired")
    ErrInvalidAnnouncementPeriod    = errors.New("invalid announcement period")
    ErrUnauthorizedAnnouncement     = errors.New("unauthorized to create announcement")
)

// 管理者通知関連エラー
var (
    ErrAdminNotificationFailed      = errors.New("admin notification failed")
    ErrNoAdminUsersFound            = errors.New("no admin users found")
)
```

### 各層でのエラーハンドリング

#### Handler層
- ドメインエラーを適切なgRPCステータスコードに変換
- クライアントに適切なエラーメッセージを返す
- 構造化ログでエラー詳細を記録

```go
func (h *MarkAsReadCommandHandler) MarkNotificationsAsRead(ctx context.Context, req *pb.MarkNotificationsAsReadRequest) (*pb.MarkNotificationsAsReadResponse, error) {
    output, err := h.useCase.Execute(ctx, input)
    if err != nil {
        switch {
        case errors.Is(err, domain.ErrNotificationNotFound):
            return nil, status.Error(codes.NotFound, "notification not found")
        case errors.Is(err, domain.ErrNotificationAlreadyRead):
            return nil, status.Error(codes.FailedPrecondition, "notification already read")
        case errors.Is(err, domain.ErrUnauthorizedAccess):
            return nil, status.Error(codes.PermissionDenied, "unauthorized access")
        default:
            h.logger.Error("unexpected error",
                slog.String("error", err.Error()),
                slog.String("trace_id", traceID),
            )
            return nil, status.Error(codes.Internal, "internal server error")
        }
    }
    return response, nil
}
```

#### UseCase層
- ドメインエラーをそのまま上位層に伝播
- トランザクション境界でのロールバック処理
- 必要に応じてコンテキスト情報を追加

```go
func (u *ProcessNotificationEventCommandUseCase) Execute(ctx context.Context, input ProcessNotificationEventInput) error {
    // 冪等性チェック
    processed, err := u.eventRepo.IsProcessed(ctx, input.EventID)
    if err != nil {
        return fmt.Errorf("failed to check event processing status: %w", err)
    }
    if processed {
        return domain.ErrEventAlreadyProcessed
    }

    // 通知生成
    notification, err := u.notificationFactory.Create(ctx, input.EventData)
    if err != nil {
        if errors.Is(err, domain.ErrInvalidEventType) {
            // 無効なイベントタイプはスキップ（エラー扱いしない）
            u.logger.Warn("skipping invalid event type",
                slog.String("event_type", input.EventType),
            )
            return nil
        }
        return fmt.Errorf("failed to create notification: %w", err)
    }

    // 永続化
    if err := u.notificationRepo.Save(ctx, notification); err != nil {
        return fmt.Errorf("failed to save notification: %w", err)
    }

    return nil
}
```

#### Infrastructure層
- 外部システムのエラーをドメインエラーに変換
- リトライ可能なエラーとそうでないエラーを区別
- データベースの制約違反を適切なドメインエラーにマッピング

```go
func (r *PostgreSQLNotificationRepository) FindByID(ctx context.Context, id domain.NotificationID) (*domain.Notification, error) {
    row := r.db.QueryRowContext(ctx, query, id.Value())

    var notification domain.Notification
    err := row.Scan(&notification.ID, &notification.RecipientUserID, ...)
    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, domain.ErrNotificationNotFound
        }
        return nil, fmt.Errorf("failed to query notification: %w", err)
    }

    return &notification, nil
}

func (c *HTTPWebPushClient) Send(ctx context.Context, subscription *domain.WebPushSubscription, payload []byte) error {
    resp, err := c.httpClient.Do(req)
    if err != nil {
        return fmt.Errorf("failed to send web push: %w", err)
    }
    defer resp.Body.Close()

    switch resp.StatusCode {
    case http.StatusCreated:
        return nil
    case http.StatusGone:
        // サブスクリプションが無効
        return domain.ErrWebPushSubscriptionExpired
    case http.StatusRequestEntityTooLarge:
        return domain.ErrWebPushPayloadTooLarge
    case http.StatusTooManyRequests:
        // リトライ可能
        return fmt.Errorf("rate limited: retry after %s", resp.Header.Get("Retry-After"))
    default:
        return domain.ErrWebPushDeliveryFailed
    }
}
```

### エラーリカバリー戦略

#### イベント処理のリトライ
```go
func (h *NotificationEventHandler) handleEvent(ctx context.Context, event domain.NotificationEvent) error {
    maxRetries := 3
    backoff := time.Second

    for i := 0; i < maxRetries; i++ {
        err := h.processEvent(ctx, event)
        if err == nil {
            return nil
        }

        // リトライ不可能なエラーは即座に返す
        if errors.Is(err, domain.ErrEventAlreadyProcessed) ||
           errors.Is(err, domain.ErrInvalidEventType) ||
           errors.Is(err, domain.ErrMissingRecipient) {
            return err
        }

        // リトライ可能なエラーの場合、バックオフ付きリトライ
        time.Sleep(backoff)
        backoff *= 2
    }

    // 最大リトライ回数を超えた場合、DLQへ
    return h.sendToDLQ(ctx, event)
}
```

#### Web Push配信のフォールバック
```go
func (u *SendWebPushCommandUseCase) Execute(ctx context.Context, input SendWebPushInput) error {
    // プライマリ送信試行
    err := u.webPushClient.Send(ctx, input.Subscription, input.Payload)
    if err == nil {
        return nil
    }

    // エラーハンドリング
    switch {
    case errors.Is(err, domain.ErrWebPushSubscriptionExpired):
        // 無効なサブスクリプションを削除
        return u.subscriptionRepo.Delete(ctx, input.Subscription.ID)
    case errors.Is(err, domain.ErrWebPushPayloadTooLarge):
        // ペイロードを縮小して再試行
        smallerPayload := u.createMinimalPayload(input.Notification)
        return u.webPushClient.Send(ctx, input.Subscription, smallerPayload)
    default:
        // その他のエラーはログに記録
        u.logger.Warn("web push delivery failed",
            slog.String("error", err.Error()),
            slog.String("endpoint", input.Subscription.Endpoint.Mask()),
        )
        return err
    }
}
```

### クライアントへのエラー通知

#### SSE経由のエラー通知
```go
func (h *NotificationSSEHandler) sendError(w http.ResponseWriter, errMsg string) {
    event := domain.SSEEvent{
        Event: "error",
        Data:  fmt.Sprintf(`{"error":"%s"}`, errMsg),
    }
    fmt.Fprintf(w, "event: %s\ndata: %s\n\n", event.Event, event.Data)
    w.(http.Flusher).Flush()
}
```

## 14. ドメインオブジェクトとデータベース/キューのマッピング

通知サービスでは、DDDの戦術的パターンに基づいて、ドメインオブジェクトをデータベースおよびキューシステムに以下のようにマッピングします：

### 14.1. PostgreSQLマッピング

#### Notification Aggregate → notifications テーブル
```sql
CREATE TABLE notifications (
    id UUID PRIMARY KEY,                                -- NotificationID Value Object (UUID v7)
    recipient_user_id UUID NOT NULL,                    -- RecipientUserID Value Object
    type VARCHAR(50) NOT NULL,                          -- NotificationType Value Object
    actor_user_id UUID,                                 -- ActorUserID Value Object (nullable)
    target_drop_id UUID,                                -- TargetDropID Value Object (nullable)
    target_user_id UUID,                                -- TargetUserID Value Object (nullable)
    read_status BOOLEAN DEFAULT FALSE NOT NULL,         -- ReadStatus Value Object
    read_at TIMESTAMP WITH TIME ZONE,                   -- ReadAt Value Object (nullable)
    notification_data JSONB,                            -- NotificationData Value Object
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),  -- CreatedAt Value Object
    expires_at TIMESTAMP WITH TIME ZONE,                -- ExpiresAt Value Object
    group_id UUID,                                      -- グループ化用
    CONSTRAINT chk_read_at CHECK (read_at IS NULL OR read_status = TRUE)
);

-- インデックス
CREATE INDEX idx_notifications_recipient_read ON notifications (recipient_user_id, read_status, created_at);
CREATE INDEX idx_notifications_created_at ON notifications (created_at);
CREATE INDEX idx_notifications_expires_at ON notifications (expires_at);
```

**集約不変条件のDB制約による強制:**
- `recipient_user_id` は NOT NULL (RecipientUserIDは変更不可)
- `type` は NOT NULL (NotificationTypeは作成後変更不可)
- `read_status` のデフォルト値は FALSE
- CHECK制約で `read_at` は `read_status = TRUE` の場合のみ設定可能

#### WebPushSubscription Aggregate → webpush_subscriptions テーブル
```sql
CREATE TABLE webpush_subscriptions (
    id UUID PRIMARY KEY,                                -- SubscriptionID Value Object (UUID v7)
    user_id UUID NOT NULL,                              -- UserID Value Object
    endpoint TEXT UNIQUE NOT NULL,                       -- WebPushEndpoint Value Object
    p256dh_key VARCHAR(128) NOT NULL,                    -- WebPushKeys Value Object
    auth_key VARCHAR(64) NOT NULL,                       -- WebPushKeys Value Object
    browser_info JSONB,                                 -- BrowserInfo Value Object
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),  -- CreatedAt Value Object
    last_used_at TIMESTAMP WITH TIME ZONE               -- LastUsedAt Value Object
);

-- インデックス
CREATE INDEX idx_webpush_user_id ON webpush_subscriptions (user_id);
```

**集約不変条件のDB制約による強制:**
- `endpoint` はUNIQUE制約 (同一エンドポイントは1つのみ)
- 定期的なクリーンアップジョブで無効なサブスクリプションを削除

### 14.2. Redisマッピング

#### NotificationEvent Aggregate → NATS JetStream
```
# Stream: NOTIFICATION
# Subject: avion.notification.events.*
# Durable Consumer: notification_workers

# メッセージPayload例:
{
  "event_id": "018e3e28-5c42-7xxx-xxxx-xxxxxxxxxxxx",  # EventID Value Object (UUID v7)
  "event_type": "avion.drop.reaction.created",            # EventType Value Object
  "event_data": {                                       # EventData Value Object
    "actor_user_id": "018e3e28-aaaa-7xxx-xxxx-xxxxxxxxxxxx",
    "target_drop_id": "018e3e28-bbbb-7xxx-xxxx-xxxxxxxxxxxx",
    "recipient_user_id": "018e3e28-cccc-7xxx-xxxx-xxxxxxxxxxxx",
    "emoji_code": "thumbs_up"
  },
  "timestamp": "2025-03-30T12:00:00Z",
  "trace_id": "abc123"
}
```

#### 冪等性管理 → Redis Hash
```
# Key Pattern: processed_event:{event_id}
# TTL: 1時間（重複処理防止に十分な期間）
# Value: JSON with processing metadata
{
  "processed_at": "2025-03-30T12:00:01Z",
  "status": "completed",
  "notification_id": "987654321"
}
```

#### SSE接続管理 → Redis Hash/Set
```
# ユーザー別接続管理
# Key: sse_connections:user:{user_id}
# Type: Hash
# TTL: 1時間（heartbeatで更新）
{
  "connection_count": "3",
  "last_heartbeat": "2025-03-30T12:00:00Z"
}

# 個別接続情報
# Key: sse_connection:{connection_id}
# Type: Hash
# TTL: 15秒（heartbeatで更新）
{
  "user_id": "123",
  "established_at": "2025-03-30T11:50:00Z",
  "user_agent": "Mozilla/5.0...",
  "ip_address": "192.168.1.100"
}
```

#### キャッシュ → Redis Hash
```
# 未読件数キャッシュ
# Key: unread_count:{user_id}
# TTL: 5分
{
  "count": "42",
  "updated_at": "2025-03-30T12:00:00Z"
}

# 通知設定キャッシュ
# Key: notification_prefs:{user_id}
# TTL: 30分
{
  "follow": "true",
  "mention": "true",
  "reaction": "false",
  "delivery_channels": ["sse", "push"]
}
```

### 14.3. マッピング戦略

#### 集約境界の保持
- **Notification Aggregate**: 単一テーブル `notifications` で完全に表現
- **WebPushSubscription Aggregate**: `webpush_subscriptions` テーブルと関連するRedisキャッシュで管理
- **NotificationEvent Aggregate**: NATS JetStreamメッセージと冪等性チェック用Redis Hashで表現
- **SSEConnectionManager Aggregate**: 複数のRedisキーで分散管理（パフォーマンス重視）

#### Value Objectの永続化
- **Primitive Value Objects**: そのままカラムにマッピング
- **Complex Value Objects**: JSON形式で永続化（例：NotificationData、BrowserInfo）
- **Enumeration Value Objects**: VARCHAR制約またはENUM型で制限

#### Repository実装での集約再構築
```go
// PostgreSQLから集約を再構築する例
func (r *PostgreSQLNotificationRepository) FindByID(ctx context.Context, id domain.NotificationID) (*domain.Notification, error) {
    var row struct {
        ID               string          // UUID v7
        RecipientUserID  string          // UUID v7
        Type             string
        ActorUserID      sql.NullString  // UUID v7 (nullable)
        TargetDropID     sql.NullString  // UUID v7 (nullable)
        ReadStatus       bool
        ReadAt           sql.NullTime
        NotificationData json.RawMessage
        CreatedAt        time.Time
        ExpiresAt        sql.NullTime
    }

    // データベースからの読み取り
    err := r.db.QueryRowContext(ctx, query, id.Value()).Scan(
        &row.ID, &row.RecipientUserID, &row.Type,
        &row.ActorUserID, &row.TargetDropID,
        &row.ReadStatus, &row.ReadAt,
        &row.NotificationData, &row.CreatedAt, &row.ExpiresAt,
    )

    // Value Objectsの再構築
    notificationID := domain.NewNotificationID(row.ID)
    recipientUserID := domain.NewRecipientUserID(row.RecipientUserID)
    notificationType := domain.NewNotificationTypeFromString(row.Type)

    // 集約の再構築
    return domain.ReconstructNotification(
        notificationID,
        recipientUserID,
        notificationType,
        // ... その他のパラメーター
    ), nil
}
```

## 20. サービス固有のテスト戦略

このサービスでは、[共通テスト戦略](../common/testing-strategy.md)に加えて、以下のサービス固有のテスト要件を実装します。

### 20.1 WebPush/SSE配信テスト

#### 20.1.1 WebPush暗号化テスト（RFC 8291準拠）

```go
package webpush_test

import (
    "errors"
    "testing"

    "github.com/google/go-cmp/cmp"
    domain "github.com/avion/avion-notification/internal/domain/webpush"
)

// WebPush暗号化のテスト
func TestWebPushEncryption_EncryptPayload(t *testing.T) {
    t.Parallel()

    validSubscription := &domain.WebPushSubscription{
        Endpoint: "https://fcm.googleapis.com/fcm/send/xxx",
        Keys: domain.WebPushKeys{
            P256dh: "validP256dhKey",
            Auth:   "validAuthKey",
        },
    }

    tests := []struct {
        name         string
        payload      string
        subscription *domain.WebPushSubscription
        wantEncoding string
        wantErr      error
    }{
        {
            name:         "正常系: 小さいペイロードの暗号化が成功する",
            payload:      `{"title":"Test","body":"Hello"}`,
            subscription: validSubscription,
            wantEncoding: "aes128gcm",
            wantErr:      nil,
        },
        {
            name:         "正常系: 最大サイズペイロード（4KB）の暗号化が成功する",
            payload:      generateLargePayload(4096),
            subscription: validSubscription,
            wantEncoding: "aes128gcm",
            wantErr:      nil,
        },
        {
            name:         "異常系: ペイロードサイズ超過でエラーを返す",
            payload:      generateLargePayload(4097),
            subscription: validSubscription,
            wantErr:      domain.ErrWebPushPayloadTooLarge,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()

            encrypted, err := domain.EncryptWebPushPayload(
                []byte(tt.payload),
                tt.subscription,
            )

            if !errors.Is(err, tt.wantErr) {
                t.Errorf("error = %v, wantErr %v", err, tt.wantErr)
                return
            }

            if tt.wantErr == nil {
                if encrypted.CipherText == nil {
                    t.Error("CipherText should not be nil")
                }
                if diff := cmp.Diff(tt.wantEncoding, encrypted.ContentEncoding); diff != "" {
                    t.Errorf("ContentEncoding mismatch (-want +got):\n%s", diff)
                }
            }
        })
    }
}

// VAPID署名生成テスト
func TestVAPIDSignature(t *testing.T) {
    privateKey, publicKey := generateVAPIDKeys(t)

    tests := []struct {
        name     string
        endpoint string
        exp      int64
        wantErr  bool
    }{
        {
            name:     "正常系: 有効な署名",
            endpoint: "https://fcm.googleapis.com/fcm/send/xxx",
            exp:      time.Now().Add(12 * time.Hour).Unix(),
            wantErr:  false,
        },
        {
            name:     "異常系: 期限切れ",
            endpoint: "https://fcm.googleapis.com/fcm/send/xxx",
            exp:      time.Now().Add(-1 * time.Hour).Unix(),
            wantErr:  true,
        },
        {
            name:     "異常系: 期限が24時間超",
            endpoint: "https://fcm.googleapis.com/fcm/send/xxx",
            exp:      time.Now().Add(25 * time.Hour).Unix(),
            wantErr:  true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            token, err := GenerateVAPIDToken(
                tt.endpoint,
                privateKey,
                publicKey,
                tt.exp,
            )

            if (err != nil) != tt.wantErr {
                t.Errorf("GenerateVAPIDToken() error = %v, wantErr %v",
                    err, tt.wantErr)
                return
            }

            if !tt.wantErr {
                // JWT形式の検証
                parts := strings.Split(token, ".")
                require.Len(t, parts, 3)
            }
        })
    }
}
```

#### 20.1.2 SSE接続管理テスト

```go
// SSE接続ライフサイクルテスト
func TestSSEConnectionLifecycle(t *testing.T) {
    manager := NewSSEConnectionManager()

    tests := []struct {
        name           string
        connections    int
        disconnections int
        expectedActive int
    }{
        {
            name:           "100接続の追加と管理",
            connections:    100,
            disconnections: 0,
            expectedActive: 100,
        },
        {
            name:           "50接続の切断",
            connections:    0,
            disconnections: 50,
            expectedActive: 50,
        },
        {
            name:           "全接続の切断",
            connections:    0,
            disconnections: 50,
            expectedActive: 0,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // 接続追加
            for i := 0; i < tt.connections; i++ {
                conn := &SSEConnection{
                    ID:     fmt.Sprintf("conn-%d", i),
                    UserID: fmt.Sprintf("user-%d", i%10),
                    Events: make(chan *SSEEvent, 100),
                }
                manager.AddConnection(conn)
            }

            // 接続切断
            for i := 0; i < tt.disconnections; i++ {
                manager.RemoveConnection(fmt.Sprintf("conn-%d", i))
            }

            // アクティブ接続数の確認
            require.Equal(t, tt.expectedActive, manager.ActiveConnections())
        })
    }
}

// SSEイベント配信テスト
func TestSSEEventDelivery(t *testing.T) {
    manager := NewSSEConnectionManager()

    // 1000接続を作成
    connections := make([]*SSEConnection, 1000)
    for i := 0; i < 1000; i++ {
        conn := &SSEConnection{
            ID:     fmt.Sprintf("conn-%d", i),
            UserID: fmt.Sprintf("user-%d", i%100),
            Events: make(chan *SSEEvent, 10),
        }
        connections[i] = conn
        manager.AddConnection(conn)
    }

    // イベント配信
    event := &SSEEvent{
        Type: "notification",
        Data: map[string]interface{}{
            "title": "Test Notification",
            "body":  "This is a test",
        },
    }

    start := time.Now()
    delivered := manager.BroadcastToUsers(
        generateUserIDs(100),
        event,
    )
    duration := time.Since(start)

    // パフォーマンス検証
    require.Equal(t, 1000, delivered)
    require.Less(t, duration, 100*time.Millisecond,
        "1000接続への配信は100ms以内で完了すべき")

    // 各接続でイベント受信確認
    for _, conn := range connections {
        select {
        case received := <-conn.Events:
            require.Equal(t, event.Type, received.Type)
        case <-time.After(1 * time.Second):
            t.Fatal("イベントが受信されませんでした")
        }
    }
}
```

### 20.2 イベント駆動処理テスト

#### 20.2.1 NATS JetStreamイベント消費テスト

```go
// イベント重複排除テスト
func TestEventDeduplication(t *testing.T) {
    ctx := context.Background()
    processor := NewNotificationEventProcessor()

    // 同一イベントを複数回送信
    event := &NotificationEvent{
        EventID:   "evt-123",
        UserID:    "user-456",
        Type:      "follow",
        CreatedAt: time.Now(),
    }

    // 5回同じイベントを処理
    var processedCount int
    for i := 0; i < 5; i++ {
        processed, err := processor.ProcessEvent(ctx, event)
        require.NoError(t, err)
        if processed {
            processedCount++
        }
    }

    // イデンポテンシー確認（1回のみ処理）
    require.Equal(t, 1, processedCount,
        "同一EventIDは1回のみ処理されるべき")
}

// NATS JetStream消費パフォーマンステスト
func TestNATSJetStreamConsumption(t *testing.T) {
    if testing.Short() {
        t.Skip("Skipping integration test")
    }

    ctx := context.Background()

    // NATSコンテナ起動
    natsServer := setupNATSContainer(t)
    defer natsServer.Terminate(ctx)

    nc := setupNATSClient(t, natsServer)
    js, err := nc.JetStream()
    require.NoError(t, err)

    // Streamとコンシューマーのセットアップ
    _, err = js.AddStream(&nats.StreamConfig{
        Name:     "NOTIFICATION",
        Subjects: []string{"avion.notification.events.*"},
    })
    require.NoError(t, err)

    consumer := NewJetStreamConsumer(js, "NOTIFICATION", "notification_workers")

    // 10,000イベントを投入
    for i := 0; i < 10000; i++ {
        payload, _ := json.Marshal(map[string]interface{}{
            "event_id": fmt.Sprintf("evt-%d", i),
            "user_id":  fmt.Sprintf("user-%d", i%100),
            "type":     "notification",
        })
        _, err := js.Publish("avion.notification.events.created", payload)
        require.NoError(t, err)
    }

    // 消費開始
    var consumed int32
    start := time.Now()

    go func() {
        err := consumer.Consume(ctx, func(msg *nats.Msg) error {
            atomic.AddInt32(&consumed, 1)
            return msg.Ack()
        })
        require.NoError(t, err)
    }()

    // 全イベント消費まで待機
    require.Eventually(t, func() bool {
        return atomic.LoadInt32(&consumed) == 10000
    }, 10*time.Second, 100*time.Millisecond)

    duration := time.Since(start)
    throughput := float64(10000) / duration.Seconds()

    t.Logf("Consumed 10,000 events in %v (%.2f events/sec)",
        duration, throughput)
    require.Greater(t, throughput, 1000.0,
        "スループットは1000イベント/秒以上必要")
}
```

### 20.3 通知配信リトライテスト

```go
// 指数バックオフリトライテスト
func TestNotificationRetryWithBackoff(t *testing.T) {
    tests := []struct {
        name           string
        failureCount   int
        expectedDelay  time.Duration
        shouldGiveUp   bool
    }{
        {
            name:          "1回目の失敗",
            failureCount:  1,
            expectedDelay: 1 * time.Second,
            shouldGiveUp:  false,
        },
        {
            name:          "3回目の失敗",
            failureCount:  3,
            expectedDelay: 4 * time.Second,
            shouldGiveUp:  false,
        },
        {
            name:          "5回目の失敗（最大リトライ）",
            failureCount:  5,
            expectedDelay: 16 * time.Second,
            shouldGiveUp:  true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            retrier := NewExponentialBackoffRetrier()

            delay, giveUp := retrier.NextDelay(tt.failureCount)

            require.Equal(t, tt.shouldGiveUp, giveUp)
            if !giveUp {
                require.Equal(t, tt.expectedDelay, delay)
            }
        })
    }
}

// エンドポイント無効化検出テスト
func TestEndpointInvalidation(t *testing.T) {
    notifier := NewWebPushNotifier()

    tests := []struct {
        name           string
        statusCode     int
        shouldInvalidate bool
    }{
        {
            name:           "410 Gone - 無効化すべき",
            statusCode:     410,
            shouldInvalidate: true,
        },
        {
            name:           "404 Not Found - 無効化すべき",
            statusCode:     404,
            shouldInvalidate: true,
        },
        {
            name:           "500 Server Error - リトライ",
            statusCode:     500,
            shouldInvalidate: false,
        },
        {
            name:           "429 Too Many Requests - リトライ",
            statusCode:     429,
            shouldInvalidate: false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := &WebPushError{
                StatusCode: tt.statusCode,
                Endpoint:   "https://example.com/push",
            }

            shouldInvalidate := notifier.ShouldInvalidateEndpoint(err)
            require.Equal(t, tt.shouldInvalidate, shouldInvalidate)
        })
    }
}
```

### 20.4 通知優先度とバッチングテスト

```go
// 通知優先度管理テスト
func TestNotificationPriority(t *testing.T) {
    queue := NewPriorityNotificationQueue()

    // 異なる優先度の通知を追加
    notifications := []struct {
        id       string
        priority NotificationPriority
    }{
        {"n1", PriorityLow},
        {"n2", PriorityHigh},
        {"n3", PriorityNormal},
        {"n4", PriorityCritical},
        {"n5", PriorityNormal},
    }

    for _, n := range notifications {
        queue.Add(&Notification{
            ID:       n.id,
            Priority: n.priority,
        })
    }

    // 優先度順に取得
    expected := []string{"n4", "n2", "n3", "n5", "n1"}
    for _, expectedID := range expected {
        notification := queue.Pop()
        require.Equal(t, expectedID, notification.ID)
    }
}

// 通知バッチング最適化テスト
func TestNotificationBatching(t *testing.T) {
    batcher := NewNotificationBatcher(
        100,              // バッチサイズ
        100*time.Millisecond, // バッチタイムアウト
    )

    // 500通知を送信
    var wg sync.WaitGroup
    wg.Add(500)

    for i := 0; i < 500; i++ {
        go func(id int) {
            defer wg.Done()
            notification := &Notification{
                ID:     fmt.Sprintf("n-%d", id),
                UserID: fmt.Sprintf("user-%d", id%50),
            }
            batcher.Add(notification)
        }(i)
    }

    // バッチ処理
    var batchCount int
    var totalProcessed int

    go func() {
        for batch := range batcher.Batches() {
            batchCount++
            totalProcessed += len(batch)

            // バッチサイズ検証
            require.LessOrEqual(t, len(batch), 100)
        }
    }()

    wg.Wait()
    time.Sleep(200 * time.Millisecond) // バッチタイムアウト待機
    batcher.Close()

    // 結果検証
    require.Equal(t, 500, totalProcessed)
    require.GreaterOrEqual(t, batchCount, 5)
    require.LessOrEqual(t, batchCount, 10)
}
```

### 20.5 パフォーマンステスト基準

| テスト項目 | 目標値 | 測定方法 |
|-----------|--------|----------|
| SSE同時接続数 | 100,000接続 | 負荷テスト |
| SSEイベント配信遅延 | p99 < 100ms | レイテンシ測定 |
| WebPush配信スループット | 10,000/秒 | ベンチマーク |
| NATS JetStream消費速度 | 5,000イベント/秒 | 統合テスト |
| 通知バッチ処理 | 1,000通知/バッチ | 最適化テスト |

### 20.6 CI/CD固有の設定

```yaml
# avion-notification固有のCI設定
notification-service-tests:
  services:
    redis:
      image: redis:8-alpine
      command: redis-server --appendonly yes

    postgres:
      image: postgres:17
      env:
        POSTGRES_DB: notification_test
        POSTGRES_PASSWORD: test

  env:
    # WebPush設定
    VAPID_PRIVATE_KEY: test-private-key
    VAPID_PUBLIC_KEY: test-public-key

    # SSE設定
    MAX_SSE_CONNECTIONS: 100000
    SSE_KEEPALIVE_INTERVAL: 15s

    # パフォーマンス閾値
    MAX_NOTIFICATION_LATENCY_MS: 100
    MIN_THROUGHPUT_PER_SEC: 1000

  timeout: 20m  # SSE/WebPushテストは時間がかかる
```

### 20.7 テスト実行マトリクス

| テストタイプ | 実行タイミング | 実行時間目標 | 必須/任意 |
|------------|--------------|-------------|----------|
| Unit Tests | Every commit | < 2min | 必須 |
| Integration | Every PR | < 5min | 必須 |
| E2E (WebPush/SSE) | Before merge | < 15min | 必須 |
| Load Tests | Nightly | < 30min | 必須 |
| Stress Tests | Weekly | < 1hr | 任意 |
