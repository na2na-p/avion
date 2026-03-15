# Design Doc: avion-notification - 通知配信チャネル

> **本文書は [designdoc.md](./designdoc.md) から分割されたドキュメントです。**
>
> **関連ドキュメント:**
> - [メインDesignDoc](./designdoc.md) - 概要、ドメインモデル、API定義
> - [通知グループ化・優先度](./designdoc-grouping.md) - グループ化、優先度計算、バッチ処理
> - [インフラ層・テスト戦略](./designdoc-infra-testing.md) - インフラ実装、テスト戦略、モック設計

---

## 18. エラーハンドリング戦略 - 通知配信特有の課題への対応

通知システムは外部依存性が高く、配信失敗、再送制御、部分的障害への対応が重要です。以下の包括的なエラーハンドリング戦略を採用します：

### 18.1. 配信失敗パターンと対応戦略

#### Web Push配信失敗
```go
// WebPushDeliveryStrategy implements notification-specific retry logic
type WebPushDeliveryStrategy struct {
    maxRetries    int
    baseDelay     time.Duration
    maxDelay      time.Duration
    jitterPercent float64
}

func (s *WebPushDeliveryStrategy) HandleDeliveryFailure(ctx context.Context, failure WebPushFailure) error {
    switch failure.Type {
    case WebPushFailureSubscriptionExpired:
        // 無効なサブスクリプションを即座に削除
        return s.subscriptionRepo.Delete(ctx, failure.SubscriptionID)

    case WebPushFailurePayloadTooLarge:
        // ペイロードを最小限に縮小して再送
        minimalPayload := s.createMinimalPayload(failure.Notification)
        return s.retrySend(ctx, failure.SubscriptionID, minimalPayload)

    case WebPushFailureRateLimited:
        // Retry-Afterヘッダーに基づく遅延後再送
        delay := s.parseRetryAfter(failure.RetryAfter)
        return s.scheduleRetry(ctx, failure, delay)

    case WebPushFailureTemporary:
        // 指数バックオフによる再送（最大3回）
        if failure.AttemptCount >= s.maxRetries {
            return s.sendToDLQ(ctx, failure)
        }
        delay := s.calculateBackoffDelay(failure.AttemptCount)
        return s.scheduleRetry(ctx, failure, delay)

    default:
        // その他のエラーはログ記録後スキップ
        s.logger.Error("unhandled web push failure",
            slog.String("failure_type", failure.Type.String()),
            slog.String("endpoint", failure.Endpoint.Mask()),
            slog.String("error", failure.Error),
        )
        return nil
    }
}
```

#### SSE配信失敗
```go
// SSEBroadcastFailureHandler handles SSE-specific delivery failures
func (h *SSEBroadcastFailureHandler) HandleBroadcastFailure(ctx context.Context, failure SSEBroadcastFailure) {
    switch failure.Type {
    case SSEFailureConnectionClosed:
        // 閉じた接続をクリーンアップ
        h.connectionManager.CleanupConnection(ctx, failure.ConnectionID)

    case SSEFailureConnectionTimeout:
        // タイムアウト接続を無効化
        h.connectionManager.MarkConnectionInactive(ctx, failure.ConnectionID)

    case SSEFailureBufferOverflow:
        // バッファオーバーフロー時は接続を切断
        h.connectionManager.ForceDisconnect(ctx, failure.ConnectionID)
        h.metrics.RecordSSEBufferOverflow(failure.UserID)

    case SSEFailureNetworkError:
        // ネットワークエラーは接続状態をチェック
        if h.connectionManager.IsConnectionAlive(ctx, failure.ConnectionID) {
            h.scheduleRetry(ctx, failure)
        } else {
            h.connectionManager.CleanupConnection(ctx, failure.ConnectionID)
        }
    }
}
```

### 18.2. イベント処理の信頼性保証

#### NATS JetStreamイベント処理
```go
// EventProcessingReliabilityHandler ensures reliable event processing
func (h *EventProcessingReliabilityHandler) ProcessEventWithReliability(ctx context.Context, event NotificationEvent) error {
    // 冪等性チェック
    if processed, err := h.eventRepo.IsProcessed(ctx, event.ID); err != nil {
        return fmt.Errorf("idempotency check failed: %w", err)
    } else if processed {
        h.logger.Debug("event already processed, skipping",
            slog.String("event_id", event.ID.String()),
            slog.String("event_type", event.Type.String()),
        )
        return nil
    }

    // トランザクション境界での処理
    return h.txManager.WithTransaction(ctx, func(tx Transaction) error {
        // 通知生成
        notification, err := h.notificationFactory.CreateFromEvent(ctx, event)
        if err != nil {
            if errors.Is(err, domain.ErrInvalidEventType) {
                // 無効なイベントタイプはスキップ（エラーではない）
                return h.markEventAsSkipped(tx, event.ID)
            }
            return fmt.Errorf("notification creation failed: %w", err)
        }

        // 通知永続化
        if err := h.notificationRepo.Save(tx, notification); err != nil {
            return fmt.Errorf("notification persistence failed: %w", err)
        }

        // イベント処理完了マーク
        if err := h.eventRepo.MarkAsProcessed(tx, event.ID); err != nil {
            return fmt.Errorf("event completion marking failed: %w", err)
        }

        return nil
    })
}
```

#### Circuit Breaker パターン
```go
// CircuitBreakerConfig for external service calls
type CircuitBreakerConfig struct {
    FailureThreshold int
    RecoveryTimeout  time.Duration
    HalfOpenMaxCalls int
}

// WebPushClientWithCircuitBreaker wraps WebPush client with circuit breaker
type WebPushClientWithCircuitBreaker struct {
    client         WebPushClient
    circuitBreaker *gobreaker.CircuitBreaker
}

func (c *WebPushClientWithCircuitBreaker) Send(ctx context.Context, subscription WebPushSubscription, payload []byte) error {
    result, err := c.circuitBreaker.Execute(func() (interface{}, error) {
        return nil, c.client.Send(ctx, subscription, payload)
    })

    if err != nil {
        if err == gobreaker.ErrOpenState {
            // Circuit Breaker開放中はキューに保存
            return c.queueForLater(ctx, subscription, payload)
        }
        return err
    }

    return nil
}
```

### 18.3. 部分的障害への対応

#### Bulkhead パターンによる障害隔離
```go
// ResourcePool provides isolated resources for different notification types
type ResourcePool struct {
    webPushPool    chan struct{}
    ssePool        chan struct{}
    dbPool         chan struct{}
    processingPool chan struct{}
}

func NewResourcePool() *ResourcePool {
    return &ResourcePool{
        webPushPool:    make(chan struct{}, 100),    // Web Push専用リソース
        ssePool:        make(chan struct{}, 200),    // SSE専用リソース
        dbPool:         make(chan struct{}, 50),     // DB専用リソース
        processingPool: make(chan struct{}, 150),    // イベント処理専用リソース
    }
}

func (p *ResourcePool) ExecuteWithWebPushPool(ctx context.Context, fn func() error) error {
    select {
    case p.webPushPool <- struct{}{}:
        defer func() { <-p.webPushPool }()
        return fn()
    case <-ctx.Done():
        return ctx.Err()
    case <-time.After(5 * time.Second):
        return ErrResourcePoolTimeout
    }
}
```

### 18.4. 監視とアラート

#### メトリクスによる障害検知
```go
// NotificationMetrics tracks delivery success/failure rates
type NotificationMetrics struct {
    deliveryAttempts   *prometheus.CounterVec
    deliveryFailures   *prometheus.CounterVec
    deliveryLatency    *prometheus.HistogramVec
    retryQueueSize     *prometheus.GaugeVec
    circuitBreakerState *prometheus.GaugeVec
}

func (m *NotificationMetrics) RecordDeliveryFailure(deliveryType, failureReason string) {
    m.deliveryFailures.WithLabelValues(deliveryType, failureReason).Inc()

    // 失敗率が閾値を超えた場合のアラート
    failureRate := m.calculateFailureRate(deliveryType)
    if failureRate > 0.1 { // 10%以上の失敗率
        m.alertManager.TriggerAlert(AlertHighFailureRate, map[string]interface{}{
            "delivery_type": deliveryType,
            "failure_rate": failureRate,
            "timestamp":    time.Now(),
        })
    }
}
```
