# Design Doc: [SERVICE_NAME]

**Author:** [Author Name]
**Last Updated:** [YYYY/MM/DD]

## 1. Summary (これは何？)

<!-- 
Brief overview of the service:
- One-sentence description in Japanese
- Purpose and main functionality
- Key value proposition
-->

- **一言で:** [Service in one sentence]
- **目的:** [Service purpose and core functionality]

## 2. テスト戦略

<!-- 
Reference to common testing strategy
- Service-specific test requirements
- Performance test targets
- Special test considerations
-->

このサービスでは、[共通テスト戦略](../common/testing-strategy.md)に従ってテストを実装します。

### テスト方針
- **TDD必須**: インターフェース定義 → テスト作成 → 実装の順序を厳守
- **カバレッジ目標**: ユニットテスト85%以上、クリティカルパス95%以上
- **テーブル駆動テスト**: 全テストで必須
- **モック生成**: `go.uber.org/mock/gomock`使用

### サービス固有のテスト要件
<!-- ここにサービス固有のテスト要件を記載 -->

詳細は[共通テスト戦略ドキュメント](../common/testing-strategy.md)を参照してください。

### 生成対象インターフェース
<!-- List all interfaces that need mocks -->
- Repository Interfaces (Domain Layer)
- Query Service Interfaces (Use Case Layer)  
- External Service Interfaces (Use Case Layer)

### 実行方法
```bash
go generate ./...
```

## 3. Background & Links (背景と関連リンク)

<!-- 
Context and rationale:
- Why this service is needed
- Business requirements it addresses
- Links to related documentation
-->

- [Service background and justification]
- [PRD: [SERVICE_NAME]](./prd.md)
- [Avion アーキテクチャ概要](../common/architecture.md)

## 4. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

<!-- 
What this service WILL do:
- Core functionality
- APIs to be implemented
- Data management responsibilities
- Integration requirements
- Non-functional requirements (observability, etc.)
-->

- [Core API functionality]
- [Data persistence requirements]
- [Event publishing/consuming]
- [Integration with other services]
- Go言語で実装し、Kubernetes上でのステートレス運用を前提とする
- OpenTelemetryによるトレーシング・メトリクス・ロギング対応

### Non-Goals (やらないこと)

<!-- 
What this service will NOT do:
- Responsibilities of other services
- Features deferred to later phases
- Explicitly excluded functionality
-->

- **[Other service responsibility]:** `[other-service]` が担当
- **[Excluded feature]:** [Reason for exclusion]

## 5. Architecture (どうやって作る？)

### 5.1. レイヤードアーキテクチャ (DDD準拠)

#### Domain Layer (ドメイン層)

<!-- 
Domain-driven design components:
- Aggregates and their responsibilities
- Entities within aggregates
- Value Objects
- Domain Services
- Repository Interfaces with mock generation directives
-->

- **Aggregates:**
  - [AggregateRoot]: [Aggregate responsibility]
  <!-- Add more aggregates as needed -->

- **Entities:**
  - [Entity]: [Entity purpose]
  <!-- Add more entities as needed -->

- **Value Objects:**
  - [ValueObject]: [Value object description]
  <!-- Add more value objects as needed -->

- **Domain Services:**
  - [DomainService]: [Business rules this service handles]
  <!-- Add more domain services as needed -->

- **Repository Interfaces:**
  - [Repository]: [Repository responsibility]
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_[repository_name].go -package=mocks
    ```
  <!-- Add more repositories as needed -->

#### Use Case Layer (ユースケース層)

<!-- 
Application business logic:
- Command Use Cases (write operations)
- Query Use Cases (read operations) 
- Query Service Interfaces with mock generation
- DTOs for data transfer
- External Service Interfaces
-->

- **Command Use Cases (更新系):**
  - [CommandUseCase]: [Command description] (POSTリクエスト用)
  <!-- Add more command use cases -->

- **Query Use Cases (参照系):**
  - [QueryUseCase]: [Query description] (GETリクエスト用)
  <!-- Add more query use cases -->

- **Query Service Interfaces:**
  - [QueryService]: [Query service responsibility]
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_[query_service_name].go -package=mocks
    ```
  <!-- Add more query services -->

- **DTOs:**
  - [InputDTO], [OutputDTO]
  <!-- Add more DTOs -->

- **External Service Interfaces:**
  - [ExternalService]: [External service integration purpose]
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_[external_service_name].go -package=mocks
    ```
  <!-- Add more external services -->

#### Infrastructure Layer (インフラストラクチャ層)

<!-- 
Technical implementation details:
- Repository implementations
- DAOs for database mapping
- Query service implementations
- External service implementations
-->

- **Repository Implementations (更新系):**
  - [Repository]: [Implementation details] (GORMを使用)
  <!-- Add more repository implementations -->

- **DAOs (Data Access Objects):**
  - [DAO]: [table_name]テーブルとのマッピング用struct
  <!-- Add more DAOs -->

- **Query Service Implementations (参照系):**
  - [QueryService]: [Implementation details] (GORMを使用)
  <!-- Add more query service implementations -->

- **External Service Implementations:**
  - [ExternalService]: [Integration implementation details]
  <!-- Add more external service implementations -->

#### Handler Layer (ハンドラ層)

<!-- 
API endpoint handlers:
- gRPC service implementations
- HTTP handlers (if any)
- Request/response mapping
-->

- **gRPC Handlers:**
  - [ServiceHandler]: [Service responsibility]
  <!-- Add more handlers -->

### 5.2. Database Design

<!-- 
Database schema and design decisions:
- Primary data stores
- Caching strategy
- Data relationships
-->

- **Primary Database:** PostgreSQL
- **Cache:** Redis (Hash, Set, Sorted Set)
- **Message Queue:** Redis Pub/Sub

### 5.3. External Dependencies

<!-- 
External systems this service depends on:
- Other Avion services
- Third-party services
- Infrastructure components
-->

- **[ExternalSystem]:** [Purpose and usage]
<!-- Add more dependencies -->

## 6. Use Cases / Key Flows (主な使い方・処理の流れ)

<!-- 
Main user flows and system interactions:
- Primary use case scenarios
- Step-by-step flows
- Error handling paths
- Integration points with other services
-->

### 6.1. [Primary Use Case]

**Goal:** [Use case objective]

**Actors:** [Who initiates this flow]

**Preconditions:** [What must be true before this flow starts]

**Flow:**
1. [Step 1]
2. [Step 2]
3. [Step 3]
<!-- Add more steps -->

**Postconditions:** [What should be true after successful completion]

**Error Scenarios:**
- [Error condition]: [How it's handled]
<!-- Add more error scenarios -->

<!-- Add more use cases as needed -->

## 7. Endpoints (API)

<!-- 
API specifications:
- gRPC service definitions
- HTTP endpoints (if any)
- Request/response schemas
- Error codes
-->

### 7.1. gRPC Service Definition

```protobuf
service [ServiceName] {
  // [Operation description]
  rpc [MethodName]([RequestType]) returns ([ResponseType]);
  // Add more methods
}

message [RequestType] {
  // Request fields
}

message [ResponseType] {
  // Response fields
}
```

### 7.2. Error Codes

<!-- Standard error codes this service returns -->
- `INVALID_ARGUMENT`: [When this error occurs]
- `NOT_FOUND`: [When this error occurs]
- `PERMISSION_DENIED`: [When this error occurs]
<!-- Add more error codes -->

## 8. Data Design (データ)

<!-- 
Data model and storage design:
- Database schemas
- Data relationships
- Indexing strategy
- Cache design
-->

### 8.1. Database Schema

```sql
-- Primary table for [main entity]
CREATE TABLE [table_name] (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Add table columns
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- Add indexes
    INDEX idx_[table_name]_[column] ([column])
);

-- Add more tables
```

### 8.2. Cache Design

<!-- 
Caching strategy:
- What data is cached
- Cache keys and structure
- TTL policies
- Cache invalidation
-->

**Redis Key Patterns:**
- `[entity]:[id]`: [Cache purpose]
<!-- Add more cache patterns -->

**TTL:** [Cache expiration policy]

## 9. Operations & Monitoring (運用と監視)

<!-- 
Operational concerns:
- Health checks
- Metrics to track
- Alerts and SLOs
- Logging strategy
-->

### 9.1. Health Checks
- `/health`: Basic liveness check
- `/ready`: Readiness check (database connectivity, etc.)

### 9.2. Key Metrics
- [Metric name]: [Metric purpose]
<!-- Add more metrics -->

### 9.3. Alerts
- [Alert condition]: [When to alert and why]
<!-- Add more alerts -->

## 10. エラーハンドリング戦略

<!-- 
Comprehensive error handling approach:
- Domain error definitions
- Error categories by functional area
- Error propagation strategy
- Client error mapping
-->

### ドメインエラーの定義

```go
// domain/error/errors.go
package error

import "errors"

// [Entity]関連エラー
var (
    Err[Entity]NotFound        = errors.New("[entity] not found")
    Err[Entity]AlreadyExists   = errors.New("[entity] already exists")
    ErrInvalid[Entity]         = errors.New("invalid [entity]")
    ErrUnauthorizedAccess      = errors.New("unauthorized access")
    // Add more domain errors
)

// システム関連エラー
var (
    ErrDatabaseConnection      = errors.New("database connection failed")
    ErrCacheUpdate            = errors.New("cache update failed")
    ErrDataInconsistency      = errors.New("data inconsistency detected")
    // Add more system errors
)
```

### エラーの分類

<!-- Error categorization and handling strategy -->
- **Domain Errors:** ビジネスロジック違反
- **Infrastructure Errors:** 外部システム連携エラー
- **System Errors:** アプリケーション基盤エラー

### Use Case Layer でのエラーハンドリング

```go
func (u *[UseCase]) Execute(ctx context.Context, input [Input]) (*[Output], error) {
    // Validation errors
    if err := u.validateInput(input); err != nil {
        return nil, fmt.Errorf("validation failed: %w", err)
    }
    
    // Domain errors
    entity, err := u.repository.FindByID(ctx, input.ID)
    if err != nil {
        if errors.Is(err, domain.Err[Entity]NotFound) {
            return nil, err // Propagate domain error as-is
        }
        return nil, fmt.Errorf("failed to find [entity]: %w", err)
    }
    
    // System errors with context
    if err := u.externalService.CallAPI(ctx, data); err != nil {
        return nil, fmt.Errorf("external service call failed: %w", err)
    }
    
    return result, nil
}
```

### Handler Layer でのエラーマッピング

```go
func (h *[Handler]) [Method](ctx context.Context, req *pb.[Request]) (*pb.[Response], error) {
    result, err := h.useCase.Execute(ctx, convertToInput(req))
    if err != nil {
        return nil, h.mapToGRPCError(err)
    }
    return convertToResponse(result), nil
}

func (h *[Handler]) mapToGRPCError(err error) error {
    switch {
    case errors.Is(err, domain.Err[Entity]NotFound):
        return status.Error(codes.NotFound, err.Error())
    case errors.Is(err, domain.ErrUnauthorizedAccess):
        return status.Error(codes.PermissionDenied, err.Error())
    case errors.Is(err, domain.ErrInvalid[Entity]):
        return status.Error(codes.InvalidArgument, err.Error())
    default:
        return status.Error(codes.Internal, "internal server error")
    }
}
```

## 11. 構造化ログ戦略

<!-- 
Structured logging approach:
- Log framework and format
- Standard log fields
- Layer-specific logging examples
- Log aggregation and querying
- Security considerations
-->

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
    Service     string    `json:"service"`     // "[service-name]"
    Version     string    `json:"version"`     // サービスバージョン
    TraceID     string    `json:"trace_id"`    // OpenTelemetry TraceID
    SpanID      string    `json:"span_id"`     // OpenTelemetry SpanID
    
    // コンテキストフィールド
    UserID      string    `json:"user_id,omitempty"`
    [EntityID]  string    `json:"[entity_id],omitempty"`
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
    slog.String("method", "[MethodName]"),
    slog.String("trace_id", traceID),
    slog.String("user_id", userID),
    slog.String("layer", "handler"),
)

logger.Error("gRPC request failed",
    slog.String("method", "[MethodName]"),
    slog.String("trace_id", traceID),
    slog.String("error", err.Error()),
    slog.String("error_code", "INVALID_ARGUMENT"),
    slog.Int64("duration_ms", duration),
)
```

#### Use Case層
```go
logger.Info("[operation] started",
    slog.String("trace_id", ctx.Value("trace_id").(string)),
    slog.String("user_id", userID),
    slog.String("[context_field]", value),
    slog.String("layer", "usecase"),
)

logger.Info("[operation] completed successfully",
    slog.String("[entity_id]", entityID),
    slog.String("user_id", userID),
    slog.String("layer", "usecase"),
)
```

#### Infrastructure層
```go
logger.Debug("database query executed",
    slog.String("query", "SELECT FROM [table]"),
    slog.String("table", "[table]"),
    slog.Int64("duration_ms", queryDuration),
    slog.String("layer", "infra"),
)

logger.Warn("cache miss",
    slog.String("key", fmt.Sprintf("[cache_pattern]:%s", id)),
    slog.String("cache_type", "[cache_type]"),
    slog.String("layer", "infra"),
)
```

### エラーログの詳細化
```go
logger.Error("failed to [operation]",
    slog.String("[entity_id]", entityID),
    slog.String("error", err.Error()),
    slog.String("error_type", fmt.Sprintf("%T", err)),
    slog.String("stack_trace", string(debug.Stack())),
    slog.String("layer", "infra"),
)
```

### CRITICALレベルのログ
```go
// データ整合性の致命的エラー
logger.Critical("data integrity violation detected",
    slog.String("event", "critical_integrity_error"),
    slog.String("[entity_id]", entityID),
    slog.String("error", "[specific error description]"),
    slog.String("action", "initiating_panic"),
)

// システムリソースの枯渇
logger.Critical("system resource exhausted",
    slog.String("event", "critical_resource_error"),
    slog.String("resource", "[resource_type]"),
    slog.String("action", "service_shutdown_required"),
)
```

### ログ集約とクエリ
- **出力先**: 標準出力（Kubernetes環境ではFluentd/Fluent Bitが収集）
- **集約先**: Elasticsearch、CloudWatch Logs、またはLoki
- **クエリ例**:
  ```
  service="[service-name]" AND layer="usecase" AND error_code="PERMISSION_DENIED"
  service="[service-name]" AND method="[MethodName]" AND duration_ms>100
  service="[service-name]" AND level="CRITICAL"
  ```

### セキュリティ考慮事項
- パスワードやトークンなどの機密情報は絶対にログに含めない
- 個人情報（メールアドレス等）は必要最小限に留める
- ユーザーIDは含めるが、ユーザー名などの識別可能な情報は避ける

## 12. ドメインオブジェクトとDBスキーマのマッピング

<!-- 
Detailed mapping between domain objects and database schema:
- Aggregate to table mappings
- Entity relationships
- Value object storage
- Index strategies
- Constraint definitions
-->

### [Aggregate] → [table_name] テーブル

```sql
CREATE TABLE [table_name] (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Add aggregate fields mapped to columns
    -- Include audit fields
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- Add indexes for performance
    INDEX idx_[table_name]_[field] ([field]),
    -- Add constraints for data integrity
    CONSTRAINT [constraint_name] CHECK ([condition])
);
```

### [Entity] → [entity_table] テーブル

```sql
CREATE TABLE [entity_table] (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    [aggregate_id] UUID NOT NULL REFERENCES [aggregate_table](id) ON DELETE CASCADE,
    -- Add entity fields
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- Add unique constraints
    CONSTRAINT [entity_table]_[unique_constraint] UNIQUE ([field1], [field2]),
    -- Add indexes
    INDEX idx_[entity_table]_[aggregate_id] ([aggregate_id])
);
```

### [ValueObject] マッピング

<!-- Document how value objects are mapped to database columns -->
- **[ValueObject]**: [table].[column] として格納
- **制約**: [Validation rules and database constraints]

### Domain Object 変換例

```go
// DAO → Domain Object
func (dao *[Entity]DAO) ToDomain() *domain.[Entity] {
    return &domain.[Entity]{
        ID:          domain.[Entity]ID(dao.ID),
        // Map other fields
        CreatedAt:   dao.CreatedAt,
        UpdatedAt:   dao.UpdatedAt,
    }
}

// Domain Object → DAO
func [Entity]ToDAO(entity *domain.[Entity]) *[Entity]DAO {
    return &[Entity]DAO{
        ID:          string(entity.ID),
        // Map other fields
        CreatedAt:   entity.CreatedAt,
        UpdatedAt:   entity.UpdatedAt,
    }
}
```

## 13. Integration Specifications (連携仕様)

<!-- 
How this service integrates with other services:
- Service dependencies
- Event publishing/consuming
- API contracts
- Data consistency requirements
-->

### 13.1. [Other Service] との連携

**Purpose:** [Why this integration is needed]

**Integration Method:** [gRPC/HTTP/Events]

**Data Flow:**
1. [Step 1 of integration]
2. [Step 2 of integration]
<!-- Add more steps -->

**Error Handling:** [How integration failures are handled]

### 13.2. Event Publishing

**Events Published:**
- `[event_type]`: [When this event is published and what data it contains]
<!-- Add more events -->

**Event Schema:**
```go
type [Event]Data struct {
    [EventID]   string    `json:"[event_id]"`
    UserID      string    `json:"user_id"`
    // Add event-specific fields
    Timestamp   time.Time `json:"timestamp"`
}
```

## 14. Concerns / Open Questions (懸念事項・相談したいこと)

<!-- 
Areas that need discussion or decisions:
- Technical uncertainties
- Performance concerns
- Integration challenges
- Resource requirements
-->

### 技術的懸念
- **[Technical concern]:** [Description of the concern]
<!-- Add more technical concerns -->

### パフォーマンス懸念
- **[Performance concern]:** [Description and potential impact]
<!-- Add more performance concerns -->

### 今後の検討事項
- **[Future consideration]:** [What needs to be considered later]
<!-- Add more future considerations -->

---

## Template Usage Notes

<!-- 
Instructions for using this template:
1. Replace all placeholders in [BRACKETS] with actual values
2. Remove sections not relevant to your service
3. Add service-specific sections as needed
4. Keep the DDD structure and patterns consistent
5. Ensure all mock generation directives are properly configured
6. Update the error handling and logging sections for your domain
7. Customize the database schema for your entities
8. Document all integrations and dependencies
-->

**Instructions for using this template:**
1. **Replace Placeholders:** All text in `[BRACKETS]` should be replaced with actual service-specific content
2. **Remove Irrelevant Sections:** Delete any sections that don't apply to your service
3. **Add Service-Specific Content:** Add additional sections as needed for your service's unique requirements
4. **Maintain DDD Patterns:** Keep the layered architecture and DDD patterns consistent
5. **Configure Mocks:** Ensure all `//go:generate` directives are properly configured for your interfaces
6. **Customize Error Handling:** Update error definitions for your specific domain
7. **Adapt Logging:** Customize the structured logging fields for your service context
8. **Define Database Schema:** Create appropriate tables and relationships for your entities
9. **Document Integrations:** Clearly specify all external dependencies and integration points
10. **Review and Validate:** Ensure the design is consistent with the overall Avion architecture