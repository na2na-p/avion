# Avion エラーコード実装ガイドライン

**Last Updated:** 2025/08/19  
**Status:** 実装ガイド

## 概要

本ドキュメントは、Avionプラットフォームのエラーコード体系を実装する際の具体的な手順とベストプラクティスを提供します。
すべての開発者は、このガイドラインに従って統一されたエラーハンドリングを実装してください。

## クイックスタート

### 1. ディレクトリ構造

各サービスで以下のディレクトリ構造を作成：

```
avion-[service]/
├── internal/
│   ├── common/
│   │   └── errors/
│   │       ├── error.go          # 基本エラーインターフェース
│   │       ├── codes.go          # エラーコード定義
│   │       └── factory.go        # エラー生成ファクトリ
│   ├── domain/
│   │   └── errors/
│   │       └── domain_errors.go  # ドメイン層エラー
│   ├── usecase/
│   │   └── errors/
│   │       └── usecase_errors.go # ユースケース層エラー
│   ├── infrastructure/
│   │   └── errors/
│   │       └── infra_errors.go   # インフラ層エラー
│   └── handler/
│       └── errors/
│           ├── grpc_mapper.go    # gRPCエラーマッピング
│           └── http_mapper.go    # HTTPエラーマッピング
```

### 2. 基本実装テンプレート

#### Step 1: 基本エラーインターフェース (`internal/common/errors/error.go`)

```go
package errors

import (
    "fmt"
    "time"
)

// ErrorCode represents a unique error code
type ErrorCode string

// Error is the base error interface for the service
type Error interface {
    error
    Code() ErrorCode
    Message() string
    Details() map[string]interface{}
    Timestamp() time.Time
    Wrap(err error) Error
    WithDetails(key string, value interface{}) Error
}

// BaseError implements the Error interface
type BaseError struct {
    code      ErrorCode
    message   string
    details   map[string]interface{}
    timestamp time.Time
    cause     error
}

func (e *BaseError) Error() string {
    if e.cause != nil {
        return fmt.Sprintf("[%s] %s: %v", e.code, e.message, e.cause)
    }
    return fmt.Sprintf("[%s] %s", e.code, e.message)
}

func (e *BaseError) Code() ErrorCode { return e.code }
func (e *BaseError) Message() string { return e.message }
func (e *BaseError) Details() map[string]interface{} { return e.details }
func (e *BaseError) Timestamp() time.Time { return e.timestamp }

func (e *BaseError) Wrap(err error) Error {
    e.cause = err
    return e
}

func (e *BaseError) WithDetails(key string, value interface{}) Error {
    if e.details == nil {
        e.details = make(map[string]interface{})
    }
    e.details[key] = value
    return e
}

// New creates a new error
func New(code ErrorCode, message string) Error {
    return &BaseError{
        code:      code,
        message:   message,
        details:   make(map[string]interface{}),
        timestamp: time.Now(),
    }
}
```

#### Step 2: サービス固有エラーコード (`internal/common/errors/codes.go`)

```go
package errors

// Service-specific error codes following [SERVICE]_[LAYER]_[ERROR_TYPE] format
const (
    // Domain layer errors
    USER_DOMAIN_NOT_FOUND        ErrorCode = "USER_DOMAIN_NOT_FOUND"
    USER_DOMAIN_ALREADY_EXISTS   ErrorCode = "USER_DOMAIN_ALREADY_EXISTS"
    USER_DOMAIN_INVALID_STATE    ErrorCode = "USER_DOMAIN_INVALID_STATE"
    USER_DOMAIN_VALIDATION_FAILED ErrorCode = "USER_DOMAIN_VALIDATION_FAILED"
    
    // UseCase layer errors
    USER_USECASE_INVALID_INPUT   ErrorCode = "USER_USECASE_INVALID_INPUT"
    USER_USECASE_UNAUTHORIZED    ErrorCode = "USER_USECASE_UNAUTHORIZED"
    USER_USECASE_FORBIDDEN       ErrorCode = "USER_USECASE_FORBIDDEN"
    USER_USECASE_CONFLICT        ErrorCode = "USER_USECASE_CONFLICT"
    
    // Infrastructure layer errors
    USER_INFRA_DATABASE_ERROR    ErrorCode = "USER_INFRA_DATABASE_ERROR"
    USER_INFRA_CACHE_ERROR       ErrorCode = "USER_INFRA_CACHE_ERROR"
    USER_INFRA_NETWORK_ERROR     ErrorCode = "USER_INFRA_NETWORK_ERROR"
    USER_INFRA_TIMEOUT           ErrorCode = "USER_INFRA_TIMEOUT"
    
    // Handler layer errors
    USER_HANDLER_BAD_REQUEST     ErrorCode = "USER_HANDLER_BAD_REQUEST"
    USER_HANDLER_RATE_LIMIT      ErrorCode = "USER_HANDLER_RATE_LIMIT"
)
```

#### Step 3: エラーファクトリ (`internal/common/errors/factory.go`)

```go
package errors

// Domain error factories
func NewUserNotFound(userID string) Error {
    return New(USER_DOMAIN_NOT_FOUND, "User not found").
        WithDetails("user_id", userID)
}

func NewUserAlreadyExists(username string) Error {
    return New(USER_DOMAIN_ALREADY_EXISTS, "User already exists").
        WithDetails("username", username)
}

// UseCase error factories
func NewInvalidInput(field, reason string) Error {
    return New(USER_USECASE_INVALID_INPUT, "Invalid input").
        WithDetails("field", field).
        WithDetails("reason", reason)
}

func NewUnauthorized(reason string) Error {
    return New(USER_USECASE_UNAUTHORIZED, "Unauthorized access").
        WithDetails("reason", reason)
}

// Infrastructure error factories
func NewDatabaseError(operation string, err error) Error {
    return New(USER_INFRA_DATABASE_ERROR, "Database operation failed").
        WithDetails("operation", operation).
        Wrap(err)
}

func NewCacheError(key string, err error) Error {
    return New(USER_INFRA_CACHE_ERROR, "Cache operation failed").
        WithDetails("key", key).
        Wrap(err)
}
```

### 3. レイヤー別実装例

#### ドメイン層での使用例

```go
package domain

import (
    "avion-user/internal/common/errors"
)

type User struct {
    ID       string
    Username string
    Email    string
}

type UserRepository interface {
    FindByID(ctx context.Context, id string) (*User, error)
    Save(ctx context.Context, user *User) error
}

// Domain service implementation
type UserDomainService struct {
    repo UserRepository
}

func (s *UserDomainService) GetUser(ctx context.Context, userID string) (*User, error) {
    user, err := s.repo.FindByID(ctx, userID)
    if err != nil {
        // Check if it's a not found error from infrastructure
        if isNotFoundError(err) {
            return nil, errors.NewUserNotFound(userID)
        }
        // Wrap infrastructure error
        return nil, errors.NewDatabaseError("find_user", err)
    }
    return user, nil
}

func (s *UserDomainService) ValidateUser(user *User) error {
    if user.Username == "" {
        return errors.New(
            errors.USER_DOMAIN_VALIDATION_FAILED,
            "Username is required",
        ).WithDetails("field", "username")
    }
    if !isValidEmail(user.Email) {
        return errors.New(
            errors.USER_DOMAIN_VALIDATION_FAILED,
            "Invalid email format",
        ).WithDetails("field", "email").
            WithDetails("value", user.Email)
    }
    return nil
}
```

#### ユースケース層での使用例

```go
package usecase

import (
    "avion-user/internal/common/errors"
    "avion-user/internal/domain"
)

type CreateUserInput struct {
    Username string
    Email    string
    Password string
}

type CreateUserUseCase struct {
    userService *domain.UserDomainService
    authService *domain.AuthDomainService
}

func (uc *CreateUserUseCase) Execute(ctx context.Context, input CreateUserInput) (*domain.User, error) {
    // Input validation
    if err := uc.validateInput(input); err != nil {
        return nil, err
    }
    
    // Check authorization
    if !uc.authService.CanCreateUser(ctx) {
        return nil, errors.NewUnauthorized("insufficient permissions to create user")
    }
    
    // Create user
    user := &domain.User{
        Username: input.Username,
        Email:    input.Email,
    }
    
    // Validate domain rules
    if err := uc.userService.ValidateUser(user); err != nil {
        return nil, err
    }
    
    // Save user
    if err := uc.userService.Save(ctx, user); err != nil {
        // Check for conflict
        if isConflictError(err) {
            return nil, errors.New(
                errors.USER_USECASE_CONFLICT,
                "User with this username or email already exists",
            )
        }
        return nil, err
    }
    
    return user, nil
}

func (uc *CreateUserUseCase) validateInput(input CreateUserInput) error {
    if input.Username == "" {
        return errors.NewInvalidInput("username", "username is required")
    }
    if len(input.Username) < 3 {
        return errors.NewInvalidInput("username", "username must be at least 3 characters")
    }
    if input.Password == "" {
        return errors.NewInvalidInput("password", "password is required")
    }
    if len(input.Password) < 8 {
        return errors.NewInvalidInput("password", "password must be at least 8 characters")
    }
    return nil
}
```

### 4. エラーマッピング実装

#### gRPCエラーマッピング (`internal/handler/errors/grpc_mapper.go`)

```go
package errors

import (
    "strings"
    "avion-user/internal/common/errors"
    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"
)

// ToGRPCError converts application error to gRPC status
func ToGRPCError(err error) error {
    if err == nil {
        return nil
    }
    
    appErr, ok := err.(errors.Error)
    if !ok {
        return status.Error(codes.Internal, "Internal server error")
    }
    
    code := string(appErr.Code())
    message := appErr.Message()
    
    // Create status with details
    st := status.New(getGRPCCode(code), message)
    
    // Add error details if available
    if details := appErr.Details(); len(details) > 0 {
        // Convert details to proto message if needed
        // st = st.WithDetails(...)
    }
    
    return st.Err()
}

func getGRPCCode(errorCode string) codes.Code {
    switch {
    // Domain layer mappings
    case strings.Contains(errorCode, "_NOT_FOUND"):
        return codes.NotFound
    case strings.Contains(errorCode, "_ALREADY_EXISTS"):
        return codes.AlreadyExists
    case strings.Contains(errorCode, "_VALIDATION_FAILED"):
        return codes.InvalidArgument
    case strings.Contains(errorCode, "_INVALID_STATE"):
        return codes.FailedPrecondition
        
    // UseCase layer mappings
    case strings.Contains(errorCode, "_INVALID_INPUT"):
        return codes.InvalidArgument
    case strings.Contains(errorCode, "_UNAUTHORIZED"):
        return codes.Unauthenticated
    case strings.Contains(errorCode, "_FORBIDDEN"):
        return codes.PermissionDenied
    case strings.Contains(errorCode, "_CONFLICT"):
        return codes.Aborted
        
    // Infrastructure layer mappings
    case strings.Contains(errorCode, "_DATABASE_ERROR"):
        return codes.Internal
    case strings.Contains(errorCode, "_TIMEOUT"):
        return codes.DeadlineExceeded
    case strings.Contains(errorCode, "_NETWORK_ERROR"):
        return codes.Unavailable
        
    // Handler layer mappings
    case strings.Contains(errorCode, "_BAD_REQUEST"):
        return codes.InvalidArgument
    case strings.Contains(errorCode, "_RATE_LIMIT"):
        return codes.ResourceExhausted
        
    default:
        return codes.Internal
    }
}
```

#### HTTPエラーマッピング (`internal/handler/errors/http_mapper.go`)

```go
package errors

import (
    "encoding/json"
    "net/http"
    "strings"
    "time"
    "avion-user/internal/common/errors"
)

// HTTPErrorResponse represents the error response structure
type HTTPErrorResponse struct {
    Error HTTPErrorDetail `json:"error"`
}

type HTTPErrorDetail struct {
    Code      string                 `json:"code"`
    Message   string                 `json:"message"`
    Details   map[string]interface{} `json:"details,omitempty"`
    Timestamp string                 `json:"timestamp"`
    TraceID   string                 `json:"trace_id,omitempty"`
}

// WriteHTTPError writes error response to HTTP response writer
func WriteHTTPError(w http.ResponseWriter, r *http.Request, err error) {
    if err == nil {
        return
    }
    
    appErr, ok := err.(errors.Error)
    if !ok {
        writeInternalError(w, r, err)
        return
    }
    
    statusCode := getHTTPStatusCode(string(appErr.Code()))
    
    response := HTTPErrorResponse{
        Error: HTTPErrorDetail{
            Code:      string(appErr.Code()),
            Message:   appErr.Message(),
            Details:   appErr.Details(),
            Timestamp: appErr.Timestamp().Format(time.RFC3339),
            TraceID:   getTraceID(r),
        },
    }
    
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(statusCode)
    json.NewEncoder(w).Encode(response)
}

func getHTTPStatusCode(errorCode string) int {
    switch {
    // Domain layer mappings
    case strings.Contains(errorCode, "_NOT_FOUND"):
        return http.StatusNotFound
    case strings.Contains(errorCode, "_ALREADY_EXISTS"):
        return http.StatusConflict
    case strings.Contains(errorCode, "_VALIDATION_FAILED"):
        return http.StatusBadRequest
    case strings.Contains(errorCode, "_INVALID_STATE"):
        return http.StatusConflict
        
    // UseCase layer mappings
    case strings.Contains(errorCode, "_INVALID_INPUT"):
        return http.StatusBadRequest
    case strings.Contains(errorCode, "_UNAUTHORIZED"):
        return http.StatusUnauthorized
    case strings.Contains(errorCode, "_FORBIDDEN"):
        return http.StatusForbidden
    case strings.Contains(errorCode, "_CONFLICT"):
        return http.StatusConflict
        
    // Infrastructure layer mappings
    case strings.Contains(errorCode, "_TIMEOUT"):
        return http.StatusRequestTimeout
    case strings.Contains(errorCode, "_DATABASE_ERROR"):
        return http.StatusInternalServerError
    case strings.Contains(errorCode, "_NETWORK_ERROR"):
        return http.StatusServiceUnavailable
        
    // Handler layer mappings
    case strings.Contains(errorCode, "_BAD_REQUEST"):
        return http.StatusBadRequest
    case strings.Contains(errorCode, "_RATE_LIMIT"):
        return http.StatusTooManyRequests
        
    default:
        return http.StatusInternalServerError
    }
}

func writeInternalError(w http.ResponseWriter, r *http.Request, err error) {
    response := HTTPErrorResponse{
        Error: HTTPErrorDetail{
            Code:      "INTERNAL_ERROR",
            Message:   "An internal error occurred",
            Timestamp: time.Now().Format(time.RFC3339),
            TraceID:   getTraceID(r),
        },
    }
    
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusInternalServerError)
    json.NewEncoder(w).Encode(response)
}

func getTraceID(r *http.Request) string {
    return r.Header.Get("X-Trace-ID")
}
```

### 5. ロギング統合

```go
package errors

import (
    "context"
    "log/slog"
    "avion-user/internal/common/errors"
)

// LogError logs error with structured format
func LogError(ctx context.Context, err error, logger *slog.Logger) {
    if err == nil {
        return
    }
    
    appErr, ok := err.(errors.Error)
    if !ok {
        logger.ErrorContext(ctx, "Unknown error",
            slog.String("error", err.Error()),
        )
        return
    }
    
    attrs := []slog.Attr{
        slog.String("error_code", string(appErr.Code())),
        slog.String("message", appErr.Message()),
        slog.Time("timestamp", appErr.Timestamp()),
    }
    
    // Add details if present
    if details := appErr.Details(); len(details) > 0 {
        attrs = append(attrs, slog.Any("details", details))
    }
    
    // Add trace ID from context
    if traceID := ctx.Value("trace_id"); traceID != nil {
        attrs = append(attrs, slog.String("trace_id", traceID.(string)))
    }
    
    logger.ErrorContext(ctx, "Application error", attrs...)
}
```

## テスト実装

### エラーハンドリングのユニットテスト

```go
package errors_test

import (
    "testing"
    "avion-user/internal/common/errors"
    "github.com/stretchr/testify/assert"
)

func TestErrorCreation(t *testing.T) {
    tests := []struct {
        name     string
        factory  func() errors.Error
        wantCode errors.ErrorCode
        wantMsg  string
    }{
        {
            name: "User not found error",
            factory: func() errors.Error {
                return errors.NewUserNotFound("user123")
            },
            wantCode: errors.USER_DOMAIN_NOT_FOUND,
            wantMsg:  "User not found",
        },
        {
            name: "Invalid input error",
            factory: func() errors.Error {
                return errors.NewInvalidInput("email", "invalid format")
            },
            wantCode: errors.USER_USECASE_INVALID_INPUT,
            wantMsg:  "Invalid input",
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := tt.factory()
            assert.Equal(t, tt.wantCode, err.Code())
            assert.Equal(t, tt.wantMsg, err.Message())
            assert.NotNil(t, err.Details())
            assert.NotZero(t, err.Timestamp())
        })
    }
}

func TestErrorMapping(t *testing.T) {
    tests := []struct {
        name           string
        errorCode      string
        wantHTTPStatus int
        wantGRPCCode   codes.Code
    }{
        {
            name:           "Not found maps to 404",
            errorCode:      "USER_DOMAIN_NOT_FOUND",
            wantHTTPStatus: 404,
            wantGRPCCode:   codes.NotFound,
        },
        {
            name:           "Unauthorized maps to 401",
            errorCode:      "USER_USECASE_UNAUTHORIZED",
            wantHTTPStatus: 401,
            wantGRPCCode:   codes.Unauthenticated,
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            httpStatus := getHTTPStatusCode(tt.errorCode)
            assert.Equal(t, tt.wantHTTPStatus, httpStatus)
            
            grpcCode := getGRPCCode(tt.errorCode)
            assert.Equal(t, tt.wantGRPCCode, grpcCode)
        })
    }
}
```

## ベストプラクティス

### 1. エラーの適切なレイヤー配置

```go
// ✅ 良い例：適切なレイヤーでエラーを生成
func (s *UserDomainService) ValidateAge(age int) error {
    if age < 13 {
        // ドメイン層でビジネスルール違反を検出
        return errors.New(
            errors.USER_DOMAIN_BUSINESS_RULE_VIOLATION,
            "User must be at least 13 years old",
        )
    }
    return nil
}

// ❌ 悪い例：不適切なレイヤーでエラーを生成
func (s *UserDomainService) ValidateAge(age int) error {
    if age < 13 {
        // ドメイン層でHTTP固有のエラーを生成（レイヤー違反）
        return errors.New(
            errors.USER_HANDLER_BAD_REQUEST,
            "Invalid age",
        )
    }
    return nil
}
```

### 2. エラーのラッピング

```go
// ✅ 良い例：元のエラーをラップして文脈を保持
func (r *UserRepository) FindByID(ctx context.Context, id string) (*User, error) {
    var user User
    err := r.db.QueryRowContext(ctx, query, id).Scan(&user)
    if err != nil {
        if err == sql.ErrNoRows {
            return nil, errors.NewUserNotFound(id)
        }
        // 元のエラーをラップ
        return nil, errors.NewDatabaseError("find_by_id", err)
    }
    return &user, nil
}

// ❌ 悪い例：元のエラー情報を失う
func (r *UserRepository) FindByID(ctx context.Context, id string) (*User, error) {
    var user User
    err := r.db.QueryRowContext(ctx, query, id).Scan(&user)
    if err != nil {
        // 元のエラー情報が失われる
        return nil, errors.New(
            errors.USER_INFRA_DATABASE_ERROR,
            "Database error",
        )
    }
    return &user, nil
}
```

### 3. エラー詳細の適切な追加

```go
// ✅ 良い例：デバッグに有用な詳細を追加
func (s *UserService) UpdateEmail(userID, newEmail string) error {
    if !isValidEmail(newEmail) {
        return errors.New(
            errors.USER_DOMAIN_VALIDATION_FAILED,
            "Invalid email format",
        ).WithDetails("user_id", userID).
          WithDetails("email", sanitizeEmail(newEmail)).
          WithDetails("validation_rule", "RFC5322")
    }
    return nil
}

// ❌ 悪い例：機密情報を含む
func (s *UserService) UpdatePassword(userID, newPassword string) error {
    if !isValidPassword(newPassword) {
        return errors.New(
            errors.USER_DOMAIN_VALIDATION_FAILED,
            "Invalid password",
        ).WithDetails("user_id", userID).
          WithDetails("password", newPassword) // 機密情報を含むべきではない
    }
    return nil
}
```

### 4. エラーメッセージの国際化

```go
// i18n/errors.go
type ErrorMessages struct {
    locale string
    messages map[errors.ErrorCode]string
}

var errorMessages = map[string]map[errors.ErrorCode]string{
    "en": {
        errors.USER_DOMAIN_NOT_FOUND: "User not found",
        errors.USER_DOMAIN_ALREADY_EXISTS: "User already exists",
    },
    "ja": {
        errors.USER_DOMAIN_NOT_FOUND: "ユーザーが見つかりません",
        errors.USER_DOMAIN_ALREADY_EXISTS: "ユーザーは既に存在します",
    },
}

func GetLocalizedMessage(code errors.ErrorCode, locale string) string {
    if messages, ok := errorMessages[locale]; ok {
        if msg, ok := messages[code]; ok {
            return msg
        }
    }
    // Fallback to English
    return errorMessages["en"][code]
}
```

## トラブルシューティング

### よくある問題と解決方法

#### 1. エラーコードの重複

**問題**: 異なる意味で同じエラーコードを使用
```go
// ❌ 同じエラーコードを異なる意味で使用
const USER_DOMAIN_INVALID = "USER_DOMAIN_INVALID" // 曖昧
```

**解決**: 具体的で一意なエラーコードを使用
```go
// ✅ 具体的なエラーコード
const USER_DOMAIN_INVALID_EMAIL = "USER_DOMAIN_INVALID_EMAIL"
const USER_DOMAIN_INVALID_USERNAME = "USER_DOMAIN_INVALID_USERNAME"
```

#### 2. エラーの過度な詳細化

**問題**: エラーコードが細かすぎて管理困難
```go
// ❌ 過度に詳細なエラーコード
const USER_DOMAIN_USERNAME_TOO_SHORT_LESS_THAN_3 = "..."
const USER_DOMAIN_USERNAME_TOO_LONG_MORE_THAN_50 = "..."
```

**解決**: 適切な粒度でグループ化
```go
// ✅ 適切な粒度
const USER_DOMAIN_VALIDATION_FAILED = "USER_DOMAIN_VALIDATION_FAILED"
// 詳細はDetailsで提供
err.WithDetails("field", "username").
    WithDetails("constraint", "length").
    WithDetails("min", 3).
    WithDetails("max", 50)
```

#### 3. エラーハンドリングの一貫性欠如

**問題**: サービス間でエラーハンドリングが異なる
```go
// サービスAではパニック
if err != nil {
    panic(err)
}

// サービスBではログのみ
if err != nil {
    log.Println(err)
}
```

**解決**: 統一されたエラーハンドリングパターン
```go
// ✅ 統一されたパターン
if err != nil {
    LogError(ctx, err, logger)
    return ToGRPCError(err)
}
```

## 移行チェックリスト

### Phase 1: 準備（Day 1-2）
- [ ] エラーパッケージ構造の作成
- [ ] 基本エラーインターフェースの実装
- [ ] エラーコード定義の作成
- [ ] エラーファクトリの実装

### Phase 2: 実装（Day 3-5）
- [ ] ドメイン層エラーの実装
- [ ] ユースケース層エラーの実装
- [ ] インフラストラクチャ層エラーの実装
- [ ] ハンドラー層エラーマッピングの実装

### Phase 3: 統合（Day 6-7）
- [ ] 既存コードのリファクタリング
- [ ] ロギング統合
- [ ] モニタリング統合
- [ ] エラーカタログの更新

### Phase 4: 検証（Day 8-10）
- [ ] ユニットテストの実装
- [ ] 統合テストの実装
- [ ] エラーハンドリングの動作確認
- [ ] ドキュメントの最終確認

## まとめ

このガイドラインに従うことで、Avionプラットフォーム全体で一貫性のある、保守性の高いエラーハンドリングを実装できます。
重要なポイント：

1. **命名規則の厳守**: `[SERVICE]_[LAYER]_[ERROR_TYPE]`形式を必ず使用
2. **適切なレイヤー配置**: 各レイヤーで適切なエラーを生成
3. **エラーの文脈保持**: Wrap機能を使用して元のエラー情報を保持
4. **一貫したマッピング**: HTTP/gRPCステータスコードへの統一マッピング
5. **構造化ログ**: エラー情報を構造化してログ出力

質問や改善提案がある場合は、プラットフォームチームまでご連絡ください。