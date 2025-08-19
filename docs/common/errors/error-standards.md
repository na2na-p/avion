# Avion エラーコード標準化ガイドライン

**Last Updated:** 2025/08/13  
**Status:** 標準仕様書

## 概要

Avionプラットフォーム全体で統一されたエラーハンドリングを実現するための標準化ガイドラインです。
すべてのマイクロサービスは本ガイドラインに準拠したエラーコード体系とエラーハンドリング実装を行います。

## エラーコード命名規則

### 基本フォーマット
```
[SERVICE]_[LAYER]_[ERROR_TYPE]
```

### 構成要素

#### SERVICE（サービス識別子）
- `AUTH`: 認証サービス (avion-auth)
- `IAM`: アイデンティティ管理 (avion-iam)  
- `USER`: ユーザー管理 (avion-user)
- `DROP`: 投稿管理 (avion-drop)
- `TIMELINE`: タイムライン (avion-timeline)
- `MEDIA`: メディア管理 (avion-media)
- `NOTIFICATION`: 通知 (avion-notification)
- `GATEWAY`: APIゲートウェイ (avion-gateway)
- `MODERATION`: モデレーション (avion-moderation)
- `ADMIN`: システム管理 (avion-system-admin)
- `ACTIVITYPUB`: ActivityPub連携 (avion-activitypub)
- `SEARCH`: 検索 (avion-search)
- `COMMUNITY`: コミュニティ管理 (avion-community)

#### LAYER（レイヤー識別子）
- `DOMAIN`: ドメイン層のエラー
- `USECASE`: ユースケース層のエラー
- `INFRA`: インフラストラクチャ層のエラー
- `HANDLER`: ハンドラー層のエラー

#### ERROR_TYPE（エラー種別）
- ドメイン層
  - `NOT_FOUND`: リソースが見つからない
  - `ALREADY_EXISTS`: リソースが既に存在
  - `INVALID_STATE`: 不正な状態遷移
  - `VALIDATION_FAILED`: バリデーション失敗
  - `BUSINESS_RULE_VIOLATION`: ビジネスルール違反

- ユースケース層
  - `INVALID_INPUT`: 入力値不正
  - `UNAUTHORIZED`: 認証エラー
  - `FORBIDDEN`: 認可エラー
  - `CONFLICT`: 競合状態
  - `PRECONDITION_FAILED`: 事前条件違反

- インフラストラクチャ層
  - `DATABASE_ERROR`: データベースエラー
  - `CACHE_ERROR`: キャッシュエラー
  - `EXTERNAL_SERVICE_ERROR`: 外部サービスエラー
  - `NETWORK_ERROR`: ネットワークエラー
  - `TIMEOUT`: タイムアウト

- ハンドラー層
  - `BAD_REQUEST`: 不正なリクエスト
  - `RATE_LIMIT_EXCEEDED`: レート制限超過
  - `PAYLOAD_TOO_LARGE`: ペイロードサイズ超過
  - `UNSUPPORTED_MEDIA_TYPE`: サポートされないメディアタイプ

## 実装仕様

### 共通エラーインターフェース

```go
// internal/common/errors/error.go
package errors

import (
    "fmt"
    "time"
)

// ErrorCode はエラーコードの型定義
type ErrorCode string

// Error はAvionプラットフォーム共通のエラーインターフェース
type Error interface {
    error
    Code() ErrorCode
    Message() string
    Details() map[string]interface{}
    Timestamp() time.Time
    Wrap(err error) Error
}

// BaseError は基本エラー実装
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

func (e *BaseError) Code() ErrorCode {
    return e.code
}

func (e *BaseError) Message() string {
    return e.message
}

func (e *BaseError) Details() map[string]interface{} {
    return e.details
}

func (e *BaseError) Timestamp() time.Time {
    return e.timestamp
}

func (e *BaseError) Wrap(err error) Error {
    e.cause = err
    return e
}

// New creates a new error with the given code and message
func New(code ErrorCode, message string) Error {
    return &BaseError{
        code:      code,
        message:   message,
        details:   make(map[string]interface{}),
        timestamp: time.Now(),
    }
}

// NewWithDetails creates a new error with details
func NewWithDetails(code ErrorCode, message string, details map[string]interface{}) Error {
    return &BaseError{
        code:      code,
        message:   message,
        details:   details,
        timestamp: time.Now(),
    }
}
```

### レイヤー別エラー定義

#### ドメイン層エラー

```go
// internal/domain/errors/errors.go
package errors

import (
    "avion/internal/common/errors"
)

// DomainError はドメイン層のエラー
type DomainError struct {
    errors.Error
}

// エラーコード定義（例：認証サービス）
const (
    // User related errors
    AUTH_DOMAIN_USER_NOT_FOUND        errors.ErrorCode = "AUTH_DOMAIN_USER_NOT_FOUND"
    AUTH_DOMAIN_USER_ALREADY_EXISTS   errors.ErrorCode = "AUTH_DOMAIN_USER_ALREADY_EXISTS"
    AUTH_DOMAIN_INVALID_PASSWORD      errors.ErrorCode = "AUTH_DOMAIN_INVALID_PASSWORD"
    AUTH_DOMAIN_ACCOUNT_LOCKED        errors.ErrorCode = "AUTH_DOMAIN_ACCOUNT_LOCKED"
    
    // Token related errors
    AUTH_DOMAIN_TOKEN_EXPIRED         errors.ErrorCode = "AUTH_DOMAIN_TOKEN_EXPIRED"
    AUTH_DOMAIN_INVALID_TOKEN         errors.ErrorCode = "AUTH_DOMAIN_INVALID_TOKEN"
    
    // Business rule violations
    AUTH_DOMAIN_PASSWORD_POLICY_VIOLATION errors.ErrorCode = "AUTH_DOMAIN_PASSWORD_POLICY_VIOLATION"
    AUTH_DOMAIN_MAX_SESSIONS_EXCEEDED     errors.ErrorCode = "AUTH_DOMAIN_MAX_SESSIONS_EXCEEDED"
)

// NewUserNotFound creates a user not found error
func NewUserNotFound(userID string) errors.Error {
    return errors.NewWithDetails(
        AUTH_DOMAIN_USER_NOT_FOUND,
        "User not found",
        map[string]interface{}{
            "user_id": userID,
        },
    )
}

// NewInvalidPassword creates an invalid password error
func NewInvalidPassword() errors.Error {
    return errors.New(
        AUTH_DOMAIN_INVALID_PASSWORD,
        "Invalid password",
    )
}
```

#### ユースケース層エラー

```go
// internal/usecase/errors/errors.go
package errors

import (
    "avion/internal/common/errors"
)

// UseCaseError はユースケース層のエラー
type UseCaseError struct {
    errors.Error
}

const (
    // Input validation errors
    AUTH_USECASE_INVALID_INPUT        errors.ErrorCode = "AUTH_USECASE_INVALID_INPUT"
    AUTH_USECASE_MISSING_REQUIRED     errors.ErrorCode = "AUTH_USECASE_MISSING_REQUIRED"
    
    // Authorization errors
    AUTH_USECASE_UNAUTHORIZED         errors.ErrorCode = "AUTH_USECASE_UNAUTHORIZED"
    AUTH_USECASE_FORBIDDEN            errors.ErrorCode = "AUTH_USECASE_FORBIDDEN"
    
    // Business logic errors
    AUTH_USECASE_CONFLICT             errors.ErrorCode = "AUTH_USECASE_CONFLICT"
    AUTH_USECASE_PRECONDITION_FAILED  errors.ErrorCode = "AUTH_USECASE_PRECONDITION_FAILED"
)

// NewInvalidInput creates an invalid input error
func NewInvalidInput(field string, reason string) errors.Error {
    return errors.NewWithDetails(
        AUTH_USECASE_INVALID_INPUT,
        "Invalid input",
        map[string]interface{}{
            "field":  field,
            "reason": reason,
        },
    )
}

// NewUnauthorized creates an unauthorized error
func NewUnauthorized(reason string) errors.Error {
    return errors.NewWithDetails(
        AUTH_USECASE_UNAUTHORIZED,
        "Unauthorized",
        map[string]interface{}{
            "reason": reason,
        },
    )
}
```

#### インフラストラクチャ層エラー

```go
// internal/infrastructure/errors/errors.go
package errors

import (
    "avion/internal/common/errors"
)

// InfrastructureError はインフラストラクチャ層のエラー
type InfrastructureError struct {
    errors.Error
}

const (
    // Database errors
    AUTH_INFRA_DATABASE_CONNECTION_FAILED errors.ErrorCode = "AUTH_INFRA_DATABASE_CONNECTION_FAILED"
    AUTH_INFRA_DATABASE_QUERY_FAILED     errors.ErrorCode = "AUTH_INFRA_DATABASE_QUERY_FAILED"
    AUTH_INFRA_DATABASE_TRANSACTION_FAILED errors.ErrorCode = "AUTH_INFRA_DATABASE_TRANSACTION_FAILED"
    
    // Cache errors
    AUTH_INFRA_CACHE_CONNECTION_FAILED   errors.ErrorCode = "AUTH_INFRA_CACHE_CONNECTION_FAILED"
    AUTH_INFRA_CACHE_OPERATION_FAILED    errors.ErrorCode = "AUTH_INFRA_CACHE_OPERATION_FAILED"
    
    // External service errors
    AUTH_INFRA_EXTERNAL_SERVICE_ERROR    errors.ErrorCode = "AUTH_INFRA_EXTERNAL_SERVICE_ERROR"
    AUTH_INFRA_NETWORK_TIMEOUT          errors.ErrorCode = "AUTH_INFRA_NETWORK_TIMEOUT"
)

// NewDatabaseError creates a database error
func NewDatabaseError(operation string, err error) errors.Error {
    return errors.NewWithDetails(
        AUTH_INFRA_DATABASE_QUERY_FAILED,
        "Database operation failed",
        map[string]interface{}{
            "operation": operation,
        },
    ).Wrap(err)
}

// NewCacheError creates a cache error
func NewCacheError(operation string, err error) errors.Error {
    return errors.NewWithDetails(
        AUTH_INFRA_CACHE_OPERATION_FAILED,
        "Cache operation failed",
        map[string]interface{}{
            "operation": operation,
        },
    ).Wrap(err)
}
```

## エラーハンドリング実装

### gRPCエラーマッピング

```go
// internal/handler/grpc/error_handler.go
package grpc

import (
    "avion/internal/common/errors"
    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"
)

// ErrorToGRPCStatus converts domain error to gRPC status
func ErrorToGRPCStatus(err error) error {
    if err == nil {
        return nil
    }
    
    domainErr, ok := err.(errors.Error)
    if !ok {
        return status.Error(codes.Internal, err.Error())
    }
    
    code := domainErr.Code()
    
    // Map error codes to gRPC status codes
    switch {
    case isNotFound(code):
        return status.Error(codes.NotFound, domainErr.Message())
    case isAlreadyExists(code):
        return status.Error(codes.AlreadyExists, domainErr.Message())
    case isInvalidInput(code):
        return status.Error(codes.InvalidArgument, domainErr.Message())
    case isUnauthorized(code):
        return status.Error(codes.Unauthenticated, domainErr.Message())
    case isForbidden(code):
        return status.Error(codes.PermissionDenied, domainErr.Message())
    case isConflict(code):
        return status.Error(codes.Aborted, domainErr.Message())
    case isPreconditionFailed(code):
        return status.Error(codes.FailedPrecondition, domainErr.Message())
    case isTimeout(code):
        return status.Error(codes.DeadlineExceeded, domainErr.Message())
    case isRateLimitExceeded(code):
        return status.Error(codes.ResourceExhausted, domainErr.Message())
    default:
        return status.Error(codes.Internal, domainErr.Message())
    }
}

func isNotFound(code errors.ErrorCode) bool {
    return contains(string(code), "NOT_FOUND")
}

func isAlreadyExists(code errors.ErrorCode) bool {
    return contains(string(code), "ALREADY_EXISTS")
}

// ... other helper functions
```

### HTTPエラーレスポンス

```go
// internal/handler/http/error_handler.go
package http

import (
    "avion/internal/common/errors"
    "encoding/json"
    "net/http"
)

// ErrorResponse はHTTPエラーレスポンスの構造体
type ErrorResponse struct {
    Error ErrorDetail `json:"error"`
}

type ErrorDetail struct {
    Code      string                 `json:"code"`
    Message   string                 `json:"message"`
    Details   map[string]interface{} `json:"details,omitempty"`
    Timestamp string                 `json:"timestamp"`
}

// HandleError handles domain errors and writes HTTP response
func HandleError(w http.ResponseWriter, err error) {
    if err == nil {
        return
    }
    
    domainErr, ok := err.(errors.Error)
    if !ok {
        writeErrorResponse(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error(), nil)
        return
    }
    
    statusCode := getHTTPStatusCode(domainErr.Code())
    
    response := ErrorResponse{
        Error: ErrorDetail{
            Code:      string(domainErr.Code()),
            Message:   domainErr.Message(),
            Details:   domainErr.Details(),
            Timestamp: domainErr.Timestamp().Format(time.RFC3339),
        },
    }
    
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(statusCode)
    json.NewEncoder(w).Encode(response)
}

func getHTTPStatusCode(code errors.ErrorCode) int {
    switch {
    case isNotFound(code):
        return http.StatusNotFound
    case isAlreadyExists(code):
        return http.StatusConflict
    case isInvalidInput(code):
        return http.StatusBadRequest
    case isUnauthorized(code):
        return http.StatusUnauthorized
    case isForbidden(code):
        return http.StatusForbidden
    case isConflict(code):
        return http.StatusConflict
    case isPreconditionFailed(code):
        return http.StatusPreconditionFailed
    case isTimeout(code):
        return http.StatusRequestTimeout
    case isRateLimitExceeded(code):
        return http.StatusTooManyRequests
    default:
        return http.StatusInternalServerError
    }
}
```

## エラーカタログ

各サービスは以下の形式でエラーカタログを管理します。

### エラーカタログ例（認証サービス）

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| AUTH_DOMAIN_USER_NOT_FOUND | 404 | NOT_FOUND | ユーザーが見つかりません | ユーザーIDを確認してください |
| AUTH_DOMAIN_INVALID_PASSWORD | 401 | UNAUTHENTICATED | パスワードが正しくありません | パスワードを確認してください |
| AUTH_DOMAIN_ACCOUNT_LOCKED | 403 | PERMISSION_DENIED | アカウントがロックされています | 管理者に連絡してください |
| AUTH_USECASE_INVALID_INPUT | 400 | INVALID_ARGUMENT | 入力値が不正です | リクエストパラメータを確認してください |
| AUTH_INFRA_DATABASE_ERROR | 500 | INTERNAL | データベースエラー | システム管理者に連絡してください |

## 実装チェックリスト

### 各サービスでの実装手順

- [ ] 1. 共通エラーパッケージの作成
  - [ ] `internal/common/errors/error.go` の作成
  - [ ] 基本エラーインターフェースの実装

- [ ] 2. レイヤー別エラー定義
  - [ ] ドメイン層エラーの定義
  - [ ] ユースケース層エラーの定義
  - [ ] インフラストラクチャ層エラーの定義

- [ ] 3. エラーハンドリング層の実装
  - [ ] gRPCエラーマッピング
  - [ ] HTTPエラーレスポンス
  - [ ] ログ出力の統一

- [ ] 4. エラーカタログの作成
  - [ ] サービス固有のエラーコード一覧
  - [ ] エラー説明と対処法の文書化

- [ ] 5. テストの実装
  - [ ] エラーハンドリングのユニットテスト
  - [ ] エラーマッピングのテスト

## 移行計画

### Phase 1: 基盤整備（1週目）
- 共通エラーパッケージの作成
- 各サービスへの配布

### Phase 2: 段階的適用（2週目）
- 新規開発部分から適用開始
- 既存コードの段階的リファクタリング

### Phase 3: 完全移行
- すべてのエラーハンドリングを新方式に統一
- 旧エラーコードの廃止

## 参考資料

- [Avion共通開発ガイドライン](../development-guidelines.md)
- [Avionアーキテクチャ概要](../architecture.md)
- [gRPC Error Handling](https://grpc.io/docs/guides/error/)
- [HTTP Status Codes](https://httpstatuses.com/)