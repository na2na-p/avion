# Error Hierarchy Specification (エラー階層仕様)

**Author:** Claude
**Last Updated:** 2025-01-16
**Version:** 1.0

## 1. 概要

本ドキュメントは、avion-activitypubサービスにおける標準化されたエラー階層を定義します。DDD原則に従い、ドメイン層、アプリケーション層、インフラストラクチャ層それぞれに適切なエラー型を配置します。

## 2. エラー階層構造

```
Error (interface)
├── DomainError (ドメイン層)
│   ├── BusinessRuleViolation
│   ├── InvariantViolation
│   └── EntityNotFound
├── ApplicationError (アプリケーション層)
│   ├── ValidationError
│   ├── AuthorizationError
│   └── ConcurrencyError
└── InfrastructureError (インフラ層)
    ├── NetworkError
    ├── PersistenceError
    └── ExternalServiceError
```

## 3. Base Error Interface

```go
package errors

import (
    "fmt"
    "time"
)

// Error はすべてのエラーが実装すべき基底インターフェース
type Error interface {
    error
    
    // エラーコード（一意識別子）
    Code() string
    
    // エラーカテゴリ
    Category() ErrorCategory
    
    // 重要度レベル
    Severity() SeverityLevel
    
    // リトライ可能かどうか
    IsRetryable() bool
    
    // ユーザー向けメッセージ
    UserMessage() string
    
    // 詳細情報
    Details() map[string]interface{}
    
    // タイムスタンプ
    OccurredAt() time.Time
    
    // スタックトレース
    StackTrace() []string
}

// ErrorCategory はエラーの分類
type ErrorCategory string

const (
    CategoryDomain         ErrorCategory = "DOMAIN"
    CategoryApplication    ErrorCategory = "APPLICATION"
    CategoryInfrastructure ErrorCategory = "INFRASTRUCTURE"
    CategorySecurity       ErrorCategory = "SECURITY"
    CategoryValidation     ErrorCategory = "VALIDATION"
)

// SeverityLevel はエラーの重要度
type SeverityLevel string

const (
    SeverityCritical SeverityLevel = "CRITICAL"  // システム停止レベル
    SeverityHigh     SeverityLevel = "HIGH"      // 重要機能の障害
    SeverityMedium   SeverityLevel = "MEDIUM"    // 部分的な機能障害
    SeverityLow      SeverityLevel = "LOW"       // 軽微な問題
    SeverityInfo     SeverityLevel = "INFO"      // 情報レベル
)

// BaseError は共通実装を提供する基底構造体
type BaseError struct {
    code        string
    category    ErrorCategory
    severity    SeverityLevel
    message     string
    userMessage string
    details     map[string]interface{}
    retryable   bool
    occurredAt  time.Time
    stackTrace  []string
    cause       error
}

func (e *BaseError) Error() string {
    if e.cause != nil {
        return fmt.Sprintf("[%s] %s: %s (caused by: %v)", e.code, e.category, e.message, e.cause)
    }
    return fmt.Sprintf("[%s] %s: %s", e.code, e.category, e.message)
}

func (e *BaseError) Code() string                     { return e.code }
func (e *BaseError) Category() ErrorCategory          { return e.category }
func (e *BaseError) Severity() SeverityLevel          { return e.severity }
func (e *BaseError) IsRetryable() bool                { return e.retryable }
func (e *BaseError) UserMessage() string              { return e.userMessage }
func (e *BaseError) Details() map[string]interface{}  { return e.details }
func (e *BaseError) OccurredAt() time.Time            { return e.occurredAt }
func (e *BaseError) StackTrace() []string             { return e.stackTrace }
func (e *BaseError) Unwrap() error                    { return e.cause }

// Is はerrors.Is()のサポート
func (e *BaseError) Is(target error) bool {
    if targetErr, ok := target.(*BaseError); ok {
        return e.code == targetErr.code
    }
    return false
}

// WithDetails は詳細情報を追加
func (e *BaseError) WithDetails(key string, value interface{}) *BaseError {
    if e.details == nil {
        e.details = make(map[string]interface{})
    }
    e.details[key] = value
    return e
}

// Wrap は原因となるエラーをラップ
func (e *BaseError) Wrap(cause error) *BaseError {
    e.cause = cause
    return e
}
```

## 4. Domain Layer Errors (ドメイン層エラー)

### 4.1 ビジネスルール違反

```go
package domain

// BusinessRuleViolation はビジネスルールの違反を表す
type BusinessRuleViolation struct {
    BaseError
    Rule        string
    AggregateID string
    Invariant   string
}

// NewBusinessRuleViolation はビジネスルール違反エラーを生成
func NewBusinessRuleViolation(rule string, message string) *BusinessRuleViolation {
    return &BusinessRuleViolation{
        BaseError: BaseError{
            code:        fmt.Sprintf("BRV-%s", generateHash(rule)),
            category:    CategoryDomain,
            severity:    SeverityMedium,
            message:     message,
            userMessage: "The requested operation violates business rules",
            retryable:   false,
            occurredAt:  time.Now(),
            stackTrace:  captureStackTrace(),
        },
        Rule: rule,
    }
}

// 具体的なビジネスルール違反
var (
    // RemoteActor関連
    ErrActorAlreadySuspended = NewBusinessRuleViolation(
        "ACTOR_SUSPENSION",
        "Actor is already suspended",
    )
    
    ErrActorNotVerified = NewBusinessRuleViolation(
        "ACTOR_VERIFICATION",
        "Actor verification failed",
    )
    
    ErrInvalidActorType = NewBusinessRuleViolation(
        "ACTOR_TYPE",
        "Invalid actor type for this operation",
    )
    
    // Community関連
    ErrCommunityMemberLimitExceeded = NewBusinessRuleViolation(
        "COMMUNITY_MEMBER_LIMIT",
        "Community member limit exceeded",
    )
    
    ErrCommunityJoinModeViolation = NewBusinessRuleViolation(
        "COMMUNITY_JOIN_MODE",
        "Join mode does not allow direct joining",
    )
    
    ErrCommunityTopicLimitExceeded = NewBusinessRuleViolation(
        "COMMUNITY_TOPIC_LIMIT",
        "Maximum number of topics exceeded",
    )
    
    // Delivery関連
    ErrDeliveryRetryLimitExceeded = NewBusinessRuleViolation(
        "DELIVERY_RETRY_LIMIT",
        "Maximum delivery retry attempts exceeded",
    )
    
    ErrDeliveryToBlockedDomain = NewBusinessRuleViolation(
        "DELIVERY_BLOCKED_DOMAIN",
        "Cannot deliver to blocked domain",
    )
)
```

### 4.2 不変条件違反

```go
// InvariantViolation は集約の不変条件違反を表す
type InvariantViolation struct {
    BaseError
    Aggregate   string
    Invariant   string
    ActualValue interface{}
}

func NewInvariantViolation(aggregate, invariant string, actual interface{}) *InvariantViolation {
    return &InvariantViolation{
        BaseError: BaseError{
            code:        fmt.Sprintf("INV-%s-%s", aggregate, generateHash(invariant)),
            category:    CategoryDomain,
            severity:    SeverityHigh,
            message:     fmt.Sprintf("Invariant '%s' violated in %s", invariant, aggregate),
            userMessage: "Data consistency error detected",
            retryable:   false,
            occurredAt:  time.Now(),
            stackTrace:  captureStackTrace(),
        },
        Aggregate:   aggregate,
        Invariant:   invariant,
        ActualValue: actual,
    }
}

// 具体的な不変条件違反
var (
    ErrActorURIMustBeUnique = NewInvariantViolation(
        "RemoteActor",
        "ActorURI must be unique",
        nil,
    )
    
    ErrPublicKeyRequired = NewInvariantViolation(
        "RemoteActor",
        "Public key is required for all actors",
        nil,
    )
    
    ErrDeliveryTaskMustHaveTarget = NewInvariantViolation(
        "DeliveryTask",
        "Delivery task must have target inbox",
        nil,
    )
)
```

### 4.3 エンティティ未発見

```go
// EntityNotFound はエンティティが見つからないエラー
type EntityNotFound struct {
    BaseError
    EntityType string
    EntityID   string
    SearchCriteria map[string]interface{}
}

func NewEntityNotFound(entityType, entityID string) *EntityNotFound {
    return &EntityNotFound{
        BaseError: BaseError{
            code:        fmt.Sprintf("ENF-%s", entityType),
            category:    CategoryDomain,
            severity:    SeverityLow,
            message:     fmt.Sprintf("%s with ID '%s' not found", entityType, entityID),
            userMessage: fmt.Sprintf("The requested %s could not be found", entityType),
            retryable:   false,
            occurredAt:  time.Now(),
            stackTrace:  captureStackTrace(),
        },
        EntityType: entityType,
        EntityID:   entityID,
    }
}

// 具体的なエンティティ未発見エラー
var (
    ErrActorNotFound = NewEntityNotFound("RemoteActor", "")
    ErrCommunityNotFound = NewEntityNotFound("Community", "")
    ErrDeliveryTaskNotFound = NewEntityNotFound("DeliveryTask", "")
)
```

## 5. Application Layer Errors (アプリケーション層エラー)

### 5.1 検証エラー

```go
package application

// ValidationError は入力検証エラー
type ValidationError struct {
    BaseError
    Field       string
    Value       interface{}
    Constraint  string
}

func NewValidationError(field, constraint string, value interface{}) *ValidationError {
    return &ValidationError{
        BaseError: BaseError{
            code:        fmt.Sprintf("VAL-%s", field),
            category:    CategoryValidation,
            severity:    SeverityLow,
            message:     fmt.Sprintf("Validation failed for field '%s': %s", field, constraint),
            userMessage: fmt.Sprintf("Invalid value for %s", field),
            retryable:   false,
            occurredAt:  time.Now(),
            stackTrace:  captureStackTrace(),
        },
        Field:      field,
        Value:      value,
        Constraint: constraint,
    }
}

// ValidationErrors は複数の検証エラーを保持
type ValidationErrors struct {
    BaseError
    Errors []ValidationError
}

func (e *ValidationErrors) Add(field, constraint string, value interface{}) {
    e.Errors = append(e.Errors, *NewValidationError(field, constraint, value))
}

func (e *ValidationErrors) HasErrors() bool {
    return len(e.Errors) > 0
}

// 具体的な検証エラー
var (
    ErrInvalidActorURI = NewValidationError(
        "actor_uri",
        "must be a valid HTTPS URL",
        nil,
    )
    
    ErrInvalidPublicKey = NewValidationError(
        "public_key",
        "must be a valid PEM-encoded RSA public key",
        nil,
    )
    
    ErrInvalidActivityType = NewValidationError(
        "activity_type",
        "must be a valid ActivityPub activity type",
        nil,
    )
)
```

### 5.2 認可エラー

```go
// AuthorizationError は認可エラー
type AuthorizationError struct {
    BaseError
    Actor       string
    Resource    string
    Action      string
    Reason      string
}

func NewAuthorizationError(actor, resource, action, reason string) *AuthorizationError {
    return &AuthorizationError{
        BaseError: BaseError{
            code:        "AUTH-FORBIDDEN",
            category:    CategorySecurity,
            severity:    SeverityMedium,
            message:     fmt.Sprintf("Actor '%s' is not authorized to %s %s: %s", actor, action, resource, reason),
            userMessage: "You don't have permission to perform this action",
            retryable:   false,
            occurredAt:  time.Now(),
            stackTrace:  captureStackTrace(),
        },
        Actor:    actor,
        Resource: resource,
        Action:   action,
        Reason:   reason,
    }
}

// 具体的な認可エラー
var (
    ErrUnauthorizedAccess = NewAuthorizationError(
        "",
        "",
        "access",
        "insufficient privileges",
    )
    
    ErrSignatureVerificationFailed = NewAuthorizationError(
        "",
        "",
        "verify",
        "HTTP signature verification failed",
    )
    
    ErrDomainNotAllowed = NewAuthorizationError(
        "",
        "",
        "federate",
        "domain is not in allowlist",
    )
)
```

### 5.3 並行性エラー

```go
// ConcurrencyError は並行性制御エラー
type ConcurrencyError struct {
    BaseError
    EntityType      string
    EntityID        string
    ExpectedVersion int
    ActualVersion   int
}

func NewConcurrencyError(entityType, entityID string, expected, actual int) *ConcurrencyError {
    return &ConcurrencyError{
        BaseError: BaseError{
            code:        "CONC-CONFLICT",
            category:    CategoryApplication,
            severity:    SeverityMedium,
            message:     fmt.Sprintf("Optimistic lock failed for %s[%s]: expected version %d, got %d", entityType, entityID, expected, actual),
            userMessage: "The resource was modified by another process. Please retry.",
            retryable:   true,
            occurredAt:  time.Now(),
            stackTrace:  captureStackTrace(),
        },
        EntityType:      entityType,
        EntityID:        entityID,
        ExpectedVersion: expected,
        ActualVersion:   actual,
    }
}
```

## 6. Infrastructure Layer Errors (インフラストラクチャ層エラー)

### 6.1 ネットワークエラー

```go
package infrastructure

// NetworkError はネットワーク関連エラー
type NetworkError struct {
    BaseError
    Host           string
    Port           int
    Protocol       string
    Operation      string
    Timeout        time.Duration
    RetryCount     int
}

func NewNetworkError(host string, operation string, cause error) *NetworkError {
    return &NetworkError{
        BaseError: BaseError{
            code:        fmt.Sprintf("NET-%s", operation),
            category:    CategoryInfrastructure,
            severity:    SeverityMedium,
            message:     fmt.Sprintf("Network error during %s to %s: %v", operation, host, cause),
            userMessage: "Network connection error. Please try again later.",
            retryable:   true,
            occurredAt:  time.Now(),
            stackTrace:  captureStackTrace(),
            cause:       cause,
        },
        Host:      host,
        Operation: operation,
    }
}

// 具体的なネットワークエラー
var (
    ErrConnectionTimeout = NewNetworkError(
        "",
        "CONNECT",
        fmt.Errorf("connection timeout"),
    )
    
    ErrConnectionRefused = NewNetworkError(
        "",
        "CONNECT",
        fmt.Errorf("connection refused"),
    )
    
    ErrDNSResolutionFailed = NewNetworkError(
        "",
        "DNS_RESOLVE",
        fmt.Errorf("DNS resolution failed"),
    )
    
    ErrSSLHandshakeFailed = NewNetworkError(
        "",
        "SSL_HANDSHAKE",
        fmt.Errorf("SSL/TLS handshake failed"),
    )
)
```

### 6.2 永続化エラー

```go
// PersistenceError はデータ永続化エラー
type PersistenceError struct {
    BaseError
    Repository     string
    Operation      string
    Entity         string
    Constraint     string
}

func NewPersistenceError(repo, operation, entity string, cause error) *PersistenceError {
    retryable := isRetryableDBError(cause)
    severity := SeverityMedium
    if isDataCorruption(cause) {
        severity = SeverityCritical
    }
    
    return &PersistenceError{
        BaseError: BaseError{
            code:        fmt.Sprintf("PERSIST-%s-%s", repo, operation),
            category:    CategoryInfrastructure,
            severity:    severity,
            message:     fmt.Sprintf("Persistence error in %s.%s for %s: %v", repo, operation, entity, cause),
            userMessage: "Database operation failed. Please try again.",
            retryable:   retryable,
            occurredAt:  time.Now(),
            stackTrace:  captureStackTrace(),
            cause:       cause,
        },
        Repository: repo,
        Operation:  operation,
        Entity:     entity,
    }
}

// 具体的な永続化エラー
var (
    ErrDuplicateKey = NewPersistenceError(
        "",
        "INSERT",
        "",
        fmt.Errorf("duplicate key violation"),
    )
    
    ErrForeignKeyViolation = NewPersistenceError(
        "",
        "DELETE",
        "",
        fmt.Errorf("foreign key constraint violation"),
    )
    
    ErrDeadlock = NewPersistenceError(
        "",
        "UPDATE",
        "",
        fmt.Errorf("deadlock detected"),
    )
    
    ErrConnectionPoolExhausted = NewPersistenceError(
        "",
        "CONNECT",
        "",
        fmt.Errorf("connection pool exhausted"),
    )
)

func isRetryableDBError(err error) bool {
    // デッドロック、タイムアウト、一時的な接続エラーはリトライ可能
    errStr := err.Error()
    retryablePatterns := []string{
        "deadlock",
        "timeout",
        "connection reset",
        "temporary failure",
    }
    
    for _, pattern := range retryablePatterns {
        if strings.Contains(strings.ToLower(errStr), pattern) {
            return true
        }
    }
    return false
}
```

### 6.3 外部サービスエラー

```go
// ExternalServiceError は外部サービス連携エラー
type ExternalServiceError struct {
    BaseError
    Service        string
    Endpoint       string
    StatusCode     int
    ResponseBody   string
    RateLimitReset *time.Time
}

func NewExternalServiceError(service, endpoint string, statusCode int, body string) *ExternalServiceError {
    severity := SeverityMedium
    retryable := false
    userMessage := "External service temporarily unavailable"
    
    // HTTPステータスコードに基づく処理
    switch {
    case statusCode >= 500:
        retryable = true
        severity = SeverityHigh
    case statusCode == 429:
        retryable = true
        userMessage = "Rate limit exceeded. Please try again later."
    case statusCode >= 400 && statusCode < 500:
        severity = SeverityLow
        userMessage = "Invalid request to external service"
    }
    
    return &ExternalServiceError{
        BaseError: BaseError{
            code:        fmt.Sprintf("EXT-%s-%d", service, statusCode),
            category:    CategoryInfrastructure,
            severity:    severity,
            message:     fmt.Sprintf("External service error from %s at %s: HTTP %d", service, endpoint, statusCode),
            userMessage: userMessage,
            retryable:   retryable,
            occurredAt:  time.Now(),
            stackTrace:  captureStackTrace(),
        },
        Service:      service,
        Endpoint:     endpoint,
        StatusCode:   statusCode,
        ResponseBody: body,
    }
}

// 具体的な外部サービスエラー
var (
    ErrRemoteServerUnavailable = NewExternalServiceError(
        "",
        "",
        503,
        "Service temporarily unavailable",
    )
    
    ErrRemoteServerTimeout = NewExternalServiceError(
        "",
        "",
        504,
        "Gateway timeout",
    )
    
    ErrRateLimitExceeded = NewExternalServiceError(
        "",
        "",
        429,
        "Too many requests",
    )
)
```

## 7. Error Handler (エラーハンドラー)

```go
// ErrorHandler は各層でのエラー処理を統一
type ErrorHandler struct {
    logger         Logger
    metrics        MetricsCollector
    alerter        Alerter
    circuitBreaker CircuitBreaker
}

func (h *ErrorHandler) Handle(err error) error {
    // 型アサーションでエラーを分類
    var customErr Error
    switch e := err.(type) {
    case Error:
        customErr = e
    default:
        // 標準エラーをラップ
        customErr = &BaseError{
            code:        "UNKNOWN",
            category:    CategoryApplication,
            severity:    SeverityMedium,
            message:     err.Error(),
            userMessage: "An unexpected error occurred",
            retryable:   false,
            occurredAt:  time.Now(),
            stackTrace:  captureStackTrace(),
            cause:       err,
        }
    }
    
    // ログ記録
    h.logError(customErr)
    
    // メトリクス記録
    h.recordMetrics(customErr)
    
    // アラート送信（重要度に応じて）
    if customErr.Severity() == SeverityCritical || customErr.Severity() == SeverityHigh {
        h.sendAlert(customErr)
    }
    
    // サーキットブレーカーの更新
    if infErr, ok := customErr.(*ExternalServiceError); ok {
        h.updateCircuitBreaker(infErr)
    }
    
    return customErr
}

func (h *ErrorHandler) logError(err Error) {
    fields := map[string]interface{}{
        "error_code":  err.Code(),
        "category":    err.Category(),
        "severity":    err.Severity(),
        "retryable":   err.IsRetryable(),
        "occurred_at": err.OccurredAt(),
        "details":     err.Details(),
    }
    
    switch err.Severity() {
    case SeverityCritical:
        h.logger.Critical(err.Error(), fields)
    case SeverityHigh:
        h.logger.Error(err.Error(), fields)
    case SeverityMedium:
        h.logger.Warn(err.Error(), fields)
    case SeverityLow:
        h.logger.Info(err.Error(), fields)
    default:
        h.logger.Debug(err.Error(), fields)
    }
}

func (h *ErrorHandler) recordMetrics(err Error) {
    labels := prometheus.Labels{
        "error_code": err.Code(),
        "category":   string(err.Category()),
        "severity":   string(err.Severity()),
        "retryable":  fmt.Sprintf("%v", err.IsRetryable()),
    }
    
    h.metrics.IncrementErrorCount(labels)
    
    // カテゴリ別の詳細メトリクス
    switch err.Category() {
    case CategoryDomain:
        h.metrics.IncrementDomainErrors(err.Code())
    case CategoryInfrastructure:
        h.metrics.IncrementInfraErrors(err.Code())
    case CategorySecurity:
        h.metrics.IncrementSecurityErrors(err.Code())
    }
}
```

## 8. Error Recovery Strategy (エラー回復戦略)

```go
// ErrorRecovery はエラーからの回復戦略を実装
type ErrorRecovery struct {
    retryPolicy    RetryPolicy
    fallbackChain  []FallbackHandler
    compensator    Compensator
}

// Retry Policyの実装
type RetryPolicy struct {
    MaxAttempts     int
    InitialDelay    time.Duration
    MaxDelay        time.Duration
    BackoffFactor   float64
    JitterFactor    float64
}

func (r *ErrorRecovery) ExecuteWithRecovery(fn func() error) error {
    var lastErr error
    attempts := 0
    
    for attempts < r.retryPolicy.MaxAttempts {
        err := fn()
        if err == nil {
            return nil
        }
        
        // エラーがリトライ可能か確認
        if customErr, ok := err.(Error); ok {
            if !customErr.IsRetryable() {
                return err
            }
        }
        
        lastErr = err
        attempts++
        
        // 指数バックオフ with ジッター
        delay := r.calculateDelay(attempts)
        time.Sleep(delay)
    }
    
    // リトライが失敗した場合、フォールバック処理
    for _, fallback := range r.fallbackChain {
        if fallback.CanHandle(lastErr) {
            return fallback.Handle(lastErr)
        }
    }
    
    // 補償トランザクションの実行
    if r.compensator != nil {
        r.compensator.Compensate(lastErr)
    }
    
    return lastErr
}

func (r *ErrorRecovery) calculateDelay(attempt int) time.Duration {
    delay := float64(r.retryPolicy.InitialDelay) * math.Pow(r.retryPolicy.BackoffFactor, float64(attempt-1))
    
    // ジッターの追加
    jitter := (rand.Float64() - 0.5) * r.retryPolicy.JitterFactor
    delay = delay * (1 + jitter)
    
    // 最大遅延の制限
    if delay > float64(r.retryPolicy.MaxDelay) {
        delay = float64(r.retryPolicy.MaxDelay)
    }
    
    return time.Duration(delay)
}

// Fallback Handlerの例
type CacheFallbackHandler struct {
    cache Cache
}

func (h *CacheFallbackHandler) CanHandle(err error) bool {
    // ネットワークエラーや外部サービスエラーの場合、キャッシュにフォールバック
    switch err.(type) {
    case *NetworkError, *ExternalServiceError:
        return true
    }
    return false
}

func (h *CacheFallbackHandler) Handle(err error) error {
    // キャッシュから値を取得して返す
    // 実装は省略
    return nil
}
```

## 9. Testing Helpers (テストヘルパー)

```go
// ErrorTestHelper はエラーのテストを支援
type ErrorTestHelper struct {
    t *testing.T
}

func NewErrorTestHelper(t *testing.T) *ErrorTestHelper {
    return &ErrorTestHelper{t: t}
}

func (h *ErrorTestHelper) AssertErrorCode(err error, expectedCode string) {
    h.t.Helper()
    
    customErr, ok := err.(Error)
    if !ok {
        h.t.Errorf("error is not a custom Error type: %T", err)
        return
    }
    
    if customErr.Code() != expectedCode {
        h.t.Errorf("expected error code %s, got %s", expectedCode, customErr.Code())
    }
}

func (h *ErrorTestHelper) AssertErrorCategory(err error, expectedCategory ErrorCategory) {
    h.t.Helper()
    
    customErr, ok := err.(Error)
    if !ok {
        h.t.Errorf("error is not a custom Error type: %T", err)
        return
    }
    
    if customErr.Category() != expectedCategory {
        h.t.Errorf("expected error category %s, got %s", expectedCategory, customErr.Category())
    }
}

func (h *ErrorTestHelper) AssertRetryable(err error) {
    h.t.Helper()
    
    customErr, ok := err.(Error)
    if !ok {
        h.t.Errorf("error is not a custom Error type: %T", err)
        return
    }
    
    if !customErr.IsRetryable() {
        h.t.Error("expected error to be retryable, but it was not")
    }
}

// テストケース例
func TestBusinessRuleViolation(t *testing.T) {
    helper := NewErrorTestHelper(t)
    
    err := ErrActorAlreadySuspended
    
    helper.AssertErrorCode(err, "BRV-ACTOR_SUSPENSION")
    helper.AssertErrorCategory(err, CategoryDomain)
    assert.Equal(t, SeverityMedium, err.Severity())
    assert.False(t, err.IsRetryable())
    assert.Equal(t, "The requested operation violates business rules", err.UserMessage())
}

func TestNetworkErrorRetry(t *testing.T) {
    helper := NewErrorTestHelper(t)
    
    err := NewNetworkError("api.example.com", "POST", fmt.Errorf("connection timeout"))
    
    helper.AssertErrorCategory(err, CategoryInfrastructure)
    helper.AssertRetryable(err)
    assert.Contains(t, err.Error(), "api.example.com")
    assert.Contains(t, err.Error(), "connection timeout")
}
```

## 10. Error Transformation (エラー変換)

```go
// ErrorTransformer は層間でのエラー変換を実施
type ErrorTransformer struct {
    domainToApp    map[error]error
    appToPresenter map[error]HTTPError
}

// HTTPError はHTTPレスポンス用のエラー
type HTTPError struct {
    StatusCode int                    `json:"-"`
    Code       string                 `json:"code"`
    Message    string                 `json:"message"`
    Details    map[string]interface{} `json:"details,omitempty"`
    Timestamp  time.Time              `json:"timestamp"`
    TraceID    string                 `json:"trace_id"`
}

func (t *ErrorTransformer) ToHTTPError(err error, traceID string) HTTPError {
    // カスタムエラーの場合
    if customErr, ok := err.(Error); ok {
        return HTTPError{
            StatusCode: t.getHTTPStatusCode(customErr),
            Code:       customErr.Code(),
            Message:    customErr.UserMessage(),
            Details:    t.sanitizeDetails(customErr.Details()),
            Timestamp:  customErr.OccurredAt(),
            TraceID:    traceID,
        }
    }
    
    // 標準エラーの場合
    return HTTPError{
        StatusCode: 500,
        Code:       "INTERNAL_ERROR",
        Message:    "An unexpected error occurred",
        Timestamp:  time.Now(),
        TraceID:    traceID,
    }
}

func (t *ErrorTransformer) getHTTPStatusCode(err Error) int {
    switch err.Category() {
    case CategoryValidation:
        return 400 // Bad Request
    case CategorySecurity:
        if strings.Contains(err.Code(), "AUTH") {
            return 403 // Forbidden
        }
        return 401 // Unauthorized
    case CategoryDomain:
        if strings.Contains(err.Code(), "ENF") {
            return 404 // Not Found
        }
        return 422 // Unprocessable Entity
    case CategoryInfrastructure:
        if err.IsRetryable() {
            return 503 // Service Unavailable
        }
        return 500 // Internal Server Error
    default:
        return 500
    }
}

func (t *ErrorTransformer) sanitizeDetails(details map[string]interface{}) map[string]interface{} {
    // 機密情報を除外
    sanitized := make(map[string]interface{})
    sensitiveKeys := []string{"password", "token", "secret", "key", "credential"}
    
    for k, v := range details {
        isSensitive := false
        lowerKey := strings.ToLower(k)
        
        for _, sensitive := range sensitiveKeys {
            if strings.Contains(lowerKey, sensitive) {
                isSensitive = true
                break
            }
        }
        
        if !isSensitive {
            sanitized[k] = v
        }
    }
    
    return sanitized
}
```

## 11. まとめ

この標準化されたエラー階層により：

1. **一貫性のあるエラー処理**が実現される
2. **適切なエラー分類**により問題の特定が容易になる
3. **リトライ可能性**の明確化により自動回復が可能
4. **ユーザー向けメッセージ**の統一により UX が向上
5. **監視・アラート**の精度が向上する

各層で適切なエラー型を使用することで、システム全体の信頼性と保守性が大幅に向上します。