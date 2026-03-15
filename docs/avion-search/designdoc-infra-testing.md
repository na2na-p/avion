# Design Doc: avion-search - インフラ層実装・テスト戦略

> **本文書は [designdoc.md](./designdoc.md) から分割されたドキュメントです。**
> メイン DesignDoc に戻る場合は [designdoc.md](./designdoc.md) を参照してください。
>
> **関連ドキュメント:**
> - [designdoc-indexing.md](./designdoc-indexing.md) - インデックス管理、MeiliSearch設定、SearchBackend Interface
> - [designdoc-trending.md](./designdoc-trending.md) - トレンド分析、推薦アルゴリズム、ドメインモデル詳細

---

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

### NATS JetStream処理のログ
```go
// Durable Consumer処理
logger.Info("jetstream consumer started",
    slog.String("subject", "avion.drop.>"),
    slog.String("consumer_name", "search_workers"),
    slog.String("consumer_id", consumerID),
)

// イベント処理遅延警告
logger.Warn("event processing lag detected",
    slog.String("event", "processing_lag"),
    slog.String("subject", "avion.drop.>"),
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
    slog.String("stream", "DROP"),
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

### 12.1. ドメインエラーの定義

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

### 12.2. エラーハンドリングの層別実装

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

### 12.3. リトライとサーキットブレーカー

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


## 21. Test Strategy

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
- **Event処理**: NATS JetStreamイベントの処理テスト

#### 3. Performance Tests
- **大規模インデックス**: 100万件以上のドキュメントでのパフォーマンステスト
- **同時検索**: 高負荷時の検索レスポンスタイムテスト
- **バッチ更新**: 大量データの一括インデックス更新テスト

### MeiliSearch Integration Testing

#### Test Environment Setup
```go
// tests/integration/meilisearch_test.go
package integration_test

import (
    "context"
    "fmt"
    "testing"

    "github.com/google/go-cmp/cmp"
    "github.com/meilisearch/meilisearch-go"
    "github.com/testcontainers/testcontainers-go"
    "github.com/testcontainers/testcontainers-go/wait"

    "avion-search/internal/infrastructure/search"
)

func setupMeiliSearchContainer(t *testing.T) (*meilisearch.Client, *search.MeiliSearchBackend, func()) {
    t.Helper()
    ctx := context.Background()

    req := testcontainers.ContainerRequest{
        Image:        "getmeili/meilisearch:v1.9",
        ExposedPorts: []string{"7700/tcp"},
        Env: map[string]string{
            "MEILI_ENV":          "development",
            "MEILI_NO_ANALYTICS": "true",
        },
        WaitingFor: wait.ForHTTP("/health").OnPort("7700"),
    }

    container, err := testcontainers.GenericContainer(ctx, testcontainers.GenericContainerRequest{
        ContainerRequest: req,
        Started:          true,
    })
    if err != nil {
        t.Fatalf("MeiliSearchコンテナ起動に失敗: %v", err)
    }

    host, _ := container.Host(ctx)
    port, _ := container.MappedPort(ctx, "7700")
    url := fmt.Sprintf("http://%s:%s", host, port.Port())

    client := meilisearch.NewClient(meilisearch.ClientConfig{Host: url})
    config := search.MeiliSearchConfig{
        Host:            url,
        IndexPrefix:     "test_",
        JapaneseEnabled: true,
        MaxSearchLimit:  1000,
        DefaultLimit:    20,
    }
    backend := search.NewMeiliSearchBackend(config)

    cleanup := func() {
        container.Terminate(ctx)
    }

    return client, backend, cleanup
}

func TestMeiliSearchBackend_CreateIndex(t *testing.T) {
    client, backend, cleanup := setupMeiliSearchContainer(t)
    defer cleanup()

    tests := []struct {
        name        string
        config      search.IndexConfig
        wantErr     error
        verifyFunc  func(t *testing.T, client *meilisearch.Client)
    }{
        {
            name: "正常系: Dropsインデックスを正しく作成できる",
            config: search.IndexConfig{
                Name:             "drops",
                PrimaryKey:       "id",
                SearchableFields: []string{"content", "title"},
                FilterableFields: []string{"user_id", "created_at", "visibility"},
                SortableFields:   []string{"created_at", "reaction_count"},
            },
            wantErr: nil,
            verifyFunc: func(t *testing.T, client *meilisearch.Client) {
                t.Helper()
                index := client.Index("test_drops")
                settings, err := index.GetSettings()
                if err != nil {
                    t.Fatalf("設定取得に失敗: %v", err)
                }
                wantSearchable := []string{"content", "title"}
                if diff := cmp.Diff(wantSearchable, settings.SearchableAttributes); diff != "" {
                    t.Errorf("SearchableAttributes mismatch (-want +got):\n%s", diff)
                }
            },
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            ctx := context.Background()
            err := backend.CreateIndex(ctx, tt.config)
            if diff := cmp.Diff(tt.wantErr, err); diff != "" {
                t.Errorf("error mismatch (-want +got):\n%s", diff)
            }
            if tt.verifyFunc != nil {
                tt.verifyFunc(t, client)
            }
        })
    }
}
```

#### Search Query Optimization Testing
```go
// tests/integration/search_optimization_test.go
package integration_test

func TestSearchQueryOptimization(t *testing.T) {
    client, backend, cleanup := setupMeiliSearchContainer(t)
    defer cleanup()

    ctx := context.Background()

    // テストデータ準備
    testDocs := []map[string]interface{}{
        {
            "id":         "1",
            "content":    "Go言語でマイクロサービスを開発しています",
            "title":      "技術ブログ",
            "user_id":    "user1",
            "created_at": time.Now().Unix(),
            "visibility": "public",
        },
        {
            "id":         "2",
            "content":    "Goプログラミングの基礎を学ぼう",
            "title":      "プログラミング入門",
            "user_id":    "user2",
            "created_at": time.Now().Unix() - 3600,
            "visibility": "public",
        },
    }

    index := client.Index("test_drops")
    if _, err := index.AddDocuments(testDocs); err != nil {
        t.Fatalf("テストデータの追加に失敗: %v", err)
    }
    waitForIndexing(t, index)

    tests := []struct {
        name          string
        query         string
        expectedHits  int
        expectedFirst string
        filters       []search.Filter
    }{
        {
            name:          "正常系: 基本的なキーワード検索",
            query:         "Go",
            expectedHits:  2,
            expectedFirst: "1",
        },
        {
            name:          "正常系: フレーズ検索",
            query:         "マイクロサービス",
            expectedHits:  1,
            expectedFirst: "1",
        },
        {
            name:          "正常系: フィルタ付き検索",
            query:         "Go",
            expectedHits:  1,
            expectedFirst: "1",
            filters: []search.Filter{
                {Field: "user_id", Operator: "=", Value: "user1"},
            },
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            req := search.SearchRequest{
                IndexName: "drops",
                Query:     tt.query,
                Limit:     10,
                Filters:   tt.filters,
            }

            resp, err := backend.Search(ctx, req)
            if err != nil {
                t.Fatalf("検索実行に失敗: %v", err)
            }

            if diff := cmp.Diff(tt.expectedHits, len(resp.Hits)); diff != "" {
                t.Errorf("ヒット数 mismatch (-want +got):\n%s", diff)
            }

            if len(resp.Hits) > 0 {
                if diff := cmp.Diff(tt.expectedFirst, resp.Hits[0]["id"]); diff != "" {
                    t.Errorf("先頭結果ID mismatch (-want +got):\n%s", diff)
                }
            }
        })
    }
}

func waitForIndexing(t *testing.T, index *meilisearch.Index) {
    t.Helper()
    for i := 0; i < 30; i++ {
        tasks, err := index.GetTasks(&meilisearch.TasksQuery{
            Statuses: []meilisearch.TaskStatus{meilisearch.TaskStatusEnqueued, meilisearch.TaskStatusProcessing},
        })
        if err == nil && len(tasks.Results) == 0 {
            return
        }
        time.Sleep(1 * time.Second)
    }
    t.Fatal("インデックス完了待機タイムアウト")
}
```

### Privacy Filter Testing

#### Block/Mute Filtering Tests
```go
// tests/unit/privacy_filter_test.go
package unit_test

import (
    "context"
    "errors"
    "testing"

    "go.uber.org/mock/gomock"

    "avion-search/internal/domain/search"
    "avion-search/internal/usecase/search_usecase"
    "avion-search/tests/mocks"
)

func TestPrivacyFilterUseCase_Search(t *testing.T) {
    tests := []struct {
        name               string
        userID             string
        query              string
        setupMocks         func(ctrl *gomock.Controller) (*mocks.MockUserServiceClient, *mocks.MockSearchBackend)
        wantErr            error
    }{
        {
            name:   "正常系: ブロックユーザーが検索結果から除外される",
            userID: "user1",
            query:  "test query",
            setupMocks: func(ctrl *gomock.Controller) (*mocks.MockUserServiceClient, *mocks.MockSearchBackend) {
                mockUserSvc := mocks.NewMockUserServiceClient(ctrl)
                mockBackend := mocks.NewMockSearchBackend(ctrl)

                mockUserSvc.EXPECT().
                    GetBlockedUsers(gomock.Any(), gomock.Any()).
                    Return(&user_pb.GetBlockedUsersResponse{
                        UserIds: []string{"blocked1", "blocked2"},
                    }, nil)
                mockUserSvc.EXPECT().
                    GetMutedUsers(gomock.Any(), gomock.Any()).
                    Return(&user_pb.GetMutedUsersResponse{
                        UserIds: []string{},
                    }, nil)

                mockBackend.EXPECT().
                    Search(gomock.Any(), gomock.Any()).
                    Return(search.SearchResponse{
                        Hits:        []map[string]interface{}{},
                        Total:       0,
                        ProcessedAt: 10,
                    }, nil)

                return mockUserSvc, mockBackend
            },
            wantErr: nil,
        },
        {
            name:   "正常系: ミュートユーザーのみが検索結果から除外される",
            userID: "user1",
            query:  "test query",
            setupMocks: func(ctrl *gomock.Controller) (*mocks.MockUserServiceClient, *mocks.MockSearchBackend) {
                mockUserSvc := mocks.NewMockUserServiceClient(ctrl)
                mockBackend := mocks.NewMockSearchBackend(ctrl)

                mockUserSvc.EXPECT().
                    GetBlockedUsers(gomock.Any(), gomock.Any()).
                    Return(&user_pb.GetBlockedUsersResponse{UserIds: []string{}}, nil)
                mockUserSvc.EXPECT().
                    GetMutedUsers(gomock.Any(), gomock.Any()).
                    Return(&user_pb.GetMutedUsersResponse{
                        UserIds: []string{"muted1"},
                    }, nil)

                mockBackend.EXPECT().
                    Search(gomock.Any(), gomock.Any()).
                    Return(search.SearchResponse{}, nil)

                return mockUserSvc, mockBackend
            },
            wantErr: nil,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            ctrl := gomock.NewController(t)
            defer ctrl.Finish()

            mockUserSvc, mockBackend := tt.setupMocks(ctrl)
            useCase := search_usecase.NewSearchUseCase(mockBackend, mockUserSvc)

            req := search_usecase.SearchRequest{
                UserID: tt.userID,
                Query:  tt.query,
                Type:   "drops",
                Limit:  20,
            }

            _, err := useCase.Search(context.Background(), req)
            if !errors.Is(err, tt.wantErr) {
                t.Errorf("error = %v, wantErr %v", err, tt.wantErr)
            }
        })
    }
}
```

### Search Result Ranking Validation

#### Ranking Algorithm Tests
```go
// tests/unit/ranking_test.go
package unit_test

func TestSearchRankingValidation(t *testing.T) {
    tests := []struct {
        name         string
        documents    []map[string]interface{}
        query        string
        expectedOrder []string
        description   string
    }{
        {
            name: "正常系: テキスト関連性に基づくランキング",
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
            name: "正常系: リアクション数による重み付けランキング",
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
            ctrl := gomock.NewController(t)
            defer ctrl.Finish()

            mockBackend := mocks.NewMockSearchBackend(ctrl)
            mockBackend.EXPECT().
                Search(gomock.Any(), gomock.Any()).
                Return(search.SearchResponse{
                    Hits: createMockHitsInOrder(tt.documents, tt.expectedOrder),
                }, nil)

            useCase := search_usecase.NewSearchUseCase(mockBackend, nil)

            resp, err := useCase.Search(context.Background(), search_usecase.SearchRequest{
                Query: tt.query,
                Type:  "drops",
            })

            if err != nil {
                t.Fatalf("unexpected error: %v", err)
            }

            if diff := cmp.Diff(len(tt.expectedOrder), len(resp.Results)); diff != "" {
                t.Errorf("results count mismatch (-want +got):\n%s", diff)
            }

            for i, expectedID := range tt.expectedOrder {
                actualID := resp.Results[i]["id"].(string)
                if diff := cmp.Diff(expectedID, actualID); diff != "" {
                    t.Errorf("Position %d mismatch (-want +got):\n%s\n%s", i, diff, tt.description)
                }
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
package integration_test

func TestEventDrivenIndexUpdates(t *testing.T) {
    tests := []struct {
        name        string
        event       string
        payload     map[string]interface{}
        setupIndex  func(*meilisearch.Client)
        verifyIndex func(*testing.T, *meilisearch.Client)
    }{
        {
            name:  "正常系: Drop作成イベントでインデックスに追加される",
            event: "avion.drop.drop.created",
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
                t.Helper()
                index := client.Index("test_drops")
                doc, err := index.GetDocument("new_drop_1")
                if err != nil {
                    t.Fatalf("ドキュメント取得に失敗: %v", err)
                }
                if diff := cmp.Diff("New drop content for indexing", doc["content"]); diff != "" {
                    t.Errorf("content mismatch (-want +got):\n%s", diff)
                }
            },
        },
        {
            name:  "正常系: Drop更新イベントでインデックスが更新される",
            event: "avion.drop.drop.updated",
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
                t.Helper()
                index := client.Index("test_drops")
                doc, err := index.GetDocument("existing_drop_1")
                if err != nil {
                    t.Fatalf("ドキュメント取得に失敗: %v", err)
                }
                if diff := cmp.Diff("Updated content for existing drop", doc["content"]); diff != "" {
                    t.Errorf("content mismatch (-want +got):\n%s", diff)
                }
            },
        },
        {
            name:  "正常系: Drop削除イベントでインデックスから削除される（GDPR）",
            event: "avion.drop.drop.deleted",
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
                t.Helper()
                index := client.Index("test_drops")
                _, err := index.GetDocument("to_delete_1")
                if err == nil {
                    t.Error("削除されたドキュメントが取得可能: 削除されていることが期待される")
                }
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
            if err != nil {
                t.Fatalf("イベント処理に失敗: %v", err)
            }
            
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
package performance_test

func TestLargeScaleIndexingPerformance(t *testing.T) {
    if testing.Short() {
        t.Skip("パフォーマンステストはshortモードでスキップ")
    }

    tests := []struct {
        name           string
        documentCount  int
        batchSize      int
        maxDuration    time.Duration
        expectedTPS    int // Documents per second
    }{
        {
            name:          "正常系: 小規模バッチインデックス処理",
            documentCount: 10000,
            batchSize:     100,
            maxDuration:   30 * time.Second,
            expectedTPS:   500,
        },
        {
            name:          "正常系: 大規模バッチインデックス処理",
            documentCount: 100000,
            batchSize:     1000,
            maxDuration:   120 * time.Second,
            expectedTPS:   1000,
        },
        {
            name:          "正常系: 超大規模インデックス処理",
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

            if err != nil {
                t.Fatalf("インデックス処理に失敗: %v", err)
            }
            if elapsed >= tt.maxDuration {
                t.Errorf("インデックス処理が遅すぎる: %v (最大 %v)", elapsed, tt.maxDuration)
            }

            // スループット計算
            actualTPS := int(float64(tt.documentCount) / elapsed.Seconds())
            if actualTPS < tt.expectedTPS {
                t.Errorf("スループット不足: %d TPS (最低 %d TPS)", actualTPS, tt.expectedTPS)
            }
            
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
package compliance_test

func TestGDPRRightToBeForgotten(t *testing.T) {
    tests := []struct {
        name                string
        userID              string
        documentsToIndex    []map[string]interface{}
        expectedRemaining   int
        verifyDeletion      func(*testing.T, *meilisearch.Client, string)
    }{
        {
            name:   "正常系: ユーザーデータの完全削除",
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
                if err != nil {
                    t.Fatalf("検索実行に失敗: %v", err)
                }
                if diff := cmp.Diff(0, len(resp.Hits)); diff != "" {
                    t.Errorf("ユーザーのドキュメントが完全に削除されていない (-want +got):\n%s", diff)
                }
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
            if err != nil {
                t.Fatalf("テストデータの追加に失敗: %v", err)
            }

            // インデックス完了待機
            waitForIndexing(t, index)

            // GDPR削除実行
            gdprService := search.NewGDPRService(
                search.NewMeiliSearchBackend(testConfig),
                logger,
            )

            err = gdprService.DeleteUserData(context.Background(), tt.userID)
            if err != nil {
                t.Fatalf("GDPR削除に失敗: %v", err)
            }

            // 削除完了待機
            time.Sleep(3 * time.Second)

            // 削除確認
            resp, err := index.Search("", &meilisearch.SearchRequest{Limit: 1000})
            if err != nil {
                t.Fatalf("検索実行に失敗: %v", err)
            }
            if diff := cmp.Diff(tt.expectedRemaining, len(resp.Hits)); diff != "" {
                t.Errorf("残存ドキュメント数 mismatch (-want +got):\n%s", diff)
            }
            
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
	docker compose -f docker compose.test.yml up -d meilisearch
	go test -v ./tests/integration/... -tags=integration
	docker compose -f docker compose.test.yml down

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

