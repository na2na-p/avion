# Design Doc: Avion バリデーション共通パッケージ設計

**Last Updated:** 2026/03/15
**Author:** Claude Code
**Status:** 採用済み
**Compliance:** Production Ready

## 1. 概要

本ドキュメントは、Avion プラットフォームにおけるバリデーションの共通設計指針を定義します。DDD 4層アーキテクチャ（Handler, UseCase, Domain, Infrastructure）の各層でのバリデーション責務を明確化し、再利用可能なバリデーション共通パッケージ `pkg/validation` の設計仕様を提供します。

### 1.1. 設計原則

- **層ごとの責務分離**: 各層が担うバリデーションの種類を明確に定義し、責務の漏出を防止する
- **自己検証オブジェクト**: Value Object は生成時に自身の不変条件を検証する（DDD パターンガイドライン準拠）
- **早期失敗**: 不正なデータは可能な限り早い段階で検出・拒否する
- **エラー標準準拠**: バリデーションエラーは [error-standards.md](../errors/error-standards.md) のエラーコード体系に準拠する

### 1.2. 関連ドキュメント

- **DDD パターン**: [ddd-patterns.md](./ddd-patterns.md) - Aggregate, Value Object, Domain Service の設計指針
- **エラー標準**: [error-standards.md](../errors/error-standards.md) - エラーコード体系 `[SERVICE]_[LAYER]_[ERROR_TYPE]`
- **開発ガイドライン**: [development-guidelines.md](./development-guidelines.md) - TDD ワークフロー、テスト戦略
- **Observability パッケージ**: [observability-package-design.md](../observability/observability-package-design.md) - 横断的関心事の設計例
- **全体アーキテクチャ**: [architecture.md](./architecture.md) - 4層アーキテクチャ構成

---

## 2. 各層のバリデーション責務

### 2.1. バリデーション責務の全体像

```
リクエスト受信
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│ Handler 層: 形式バリデーション                             │
│  - 型チェック、必須項目、フォーマット、サイズ制限            │
│  - ConnectRPC/GraphQL スキーマに基づく構造検証             │
└─────────────────────┬───────────────────────────────────┘
                      │ DTO / Command / Query
                      ▼
┌─────────────────────────────────────────────────────────┐
│ UseCase 層: ビジネスルール検証                             │
│  - 権限チェック（認可）                                    │
│  - 状態遷移の妥当性検証                                    │
│  - クロス Aggregate 整合性（Domain Service 経由）          │
└─────────────────────┬───────────────────────────────────┘
                      │ Domain Model
                      ▼
┌─────────────────────────────────────────────────────────┐
│ Domain 層: ドメイン不変条件                                │
│  - Value Object の自己検証（生成時バリデーション）          │
│  - Aggregate の整合性保証                                  │
│  - ビジネスルール違反の検出                                │
└─────────────────────┬───────────────────────────────────┘
                      │ Repository / External
                      ▼
┌─────────────────────────────────────────────────────────┐
│ Infrastructure 層: 外部依存の検証                          │
│  - DB 制約違反の検出とドメインエラーへの変換               │
│  - 外部 API レスポンスの妥当性検証                         │
│  - キャッシュデータの整合性検証                            │
└─────────────────────────────────────────────────────────┘
```

### 2.2. Handler 層: リクエスト形式バリデーション

Handler 層は、外部から受信したリクエストの**形式的な正しさ**を検証します。ビジネスロジックには関与しません。

#### 責務

| 検証項目 | 説明 | 例 |
|:--|:--|:--|
| 型チェック | リクエストフィールドの型が期待通りであること | 数値フィールドに文字列が入っていないか |
| 必須項目 | 必須フィールドが存在し空でないこと | `username` が空文字でないか |
| フォーマット | 値が期待されるフォーマットに合致すること | メールアドレスの形式、UUID の形式 |
| サイズ制限 | 値の長さやサイズが許容範囲内であること | 文字列長、ファイルサイズ、配列要素数 |
| 構造検証 | リクエスト全体の構造が正しいこと | ConnectRPC の proto 定義との整合性 |

#### 実装パターン

```go
// internal/handler/connectrpc/drop_handler.go
package connectrpc

import (
    "context"

    "connectrpc.com/connect"

    dropv1 "avion-drop/gen/drop/v1"
    "avion-drop/pkg/validation"
)

// CreateDrop は Drop 作成リクエストを処理する
func (h *DropHandler) CreateDrop(
    ctx context.Context,
    req *connect.Request[dropv1.CreateDropRequest],
) (*connect.Response[dropv1.CreateDropResponse], error) {
    // Handler 層: 形式バリデーション
    if err := h.validateCreateDropRequest(req.Msg); err != nil {
        return nil, connect.NewError(connect.CodeInvalidArgument, err)
    }

    // UseCase 層へ委譲
    output, err := h.createDropUseCase.Execute(ctx, toCreateDropInput(req.Msg))
    if err != nil {
        return nil, mapUseCaseError(err)
    }

    return connect.NewResponse(toCreateDropResponse(output)), nil
}

// validateCreateDropRequest はリクエストの形式バリデーションを行う
func (h *DropHandler) validateCreateDropRequest(msg *dropv1.CreateDropRequest) error {
    v := validation.New()

    v.RequiredString("content", msg.GetContent())
    v.MaxLength("content", msg.GetContent(), 500)
    v.RequiredString("author_id", msg.GetAuthorId())
    v.UUID("author_id", msg.GetAuthorId())

    if msg.GetVisibility() != "" {
        v.OneOf("visibility", msg.GetVisibility(), []string{"public", "unlisted", "private", "direct"})
    }

    for i, mediaID := range msg.GetMediaIds() {
        v.UUID(validation.IndexedField("media_ids", i), mediaID)
    }
    v.MaxCount("media_ids", len(msg.GetMediaIds()), 4)

    return v.Validate()
}
```

#### Handler 層で行わないこと

- ユーザーの存在確認（UseCase 層の責務）
- 権限チェック（UseCase 層の責務）
- ドメイン固有のビジネスルール検証（Domain 層の責務）
- DB やキャッシュへの問い合わせ（Infrastructure 層の責務）

### 2.3. UseCase 層: ビジネスルール検証

UseCase 層は、アプリケーションのビジネスルールを検証します。単一 Aggregate 内で完結しない検証や、外部サービスとの連携を伴う検証を担います。

#### 責務

| 検証項目 | 説明 | 例 |
|:--|:--|:--|
| 権限チェック | 操作を実行する権限があること | 投稿の編集権限、コミュニティ管理者権限 |
| 状態遷移検証 | 操作が現在の状態で許可されること | 公開済み投稿のみ編集可能、ロック済みアカウントでのログイン不可 |
| 事前条件検証 | 操作の事前条件が満たされていること | フォロー先ユーザーが存在すること、投稿先コミュニティが存在すること |
| クロス Aggregate 整合性 | 複数 Aggregate にまたがるルール | ブロック状態でのフォロー不可（Domain Service 経由） |

#### 実装パターン

```go
// internal/usecase/command/create_drop_use_case.go
package command

import (
    "context"
    "fmt"

    "avion-drop/internal/domain/model"
    "avion-drop/internal/domain/repository"
    "avion-drop/internal/usecase/external"
)

// CreateDropInput は Drop 作成の入力
type CreateDropInput struct {
    AuthorID   string
    Content    string
    Visibility string
    MediaIDs   []string
}

// CreateDropUseCase は Drop 作成ユースケース
type CreateDropUseCase struct {
    dropRepo    repository.DropRepository
    userClient  external.UserServiceClient
    mediaClient external.MediaServiceClient
    idGenerator IDGenerator
}

// Execute は Drop 作成を実行する
func (uc *CreateDropUseCase) Execute(ctx context.Context, input CreateDropInput) (*CreateDropOutput, error) {
    // UseCase 層: 事前条件検証 - ユーザーの存在確認
    user, err := uc.userClient.GetUser(ctx, input.AuthorID)
    if err != nil {
        return nil, fmt.Errorf("failed to verify author: %w", err)
    }

    // UseCase 層: 権限チェック - アカウント状態の確認
    if user.IsSuspended {
        return nil, ErrAccountSuspended
    }

    // UseCase 層: 事前条件検証 - メディアの存在確認
    if len(input.MediaIDs) > 0 {
        if err := uc.mediaClient.VerifyMediaExists(ctx, input.MediaIDs); err != nil {
            return nil, fmt.Errorf("media verification failed: %w", err)
        }
    }

    // Domain 層: Value Object 生成（自己検証を含む）
    authorID, err := model.NewUserID(input.AuthorID)
    if err != nil {
        return nil, fmt.Errorf("invalid author ID: %w", err)
    }

    content, err := model.NewDropContent(input.Content)
    if err != nil {
        return nil, fmt.Errorf("invalid content: %w", err)
    }

    visibility, err := model.NewVisibility(input.Visibility)
    if err != nil {
        return nil, fmt.Errorf("invalid visibility: %w", err)
    }

    // Domain 層: Aggregate 生成（不変条件の検証を含む）
    dropID, err := uc.idGenerator.Generate(ctx)
    if err != nil {
        return nil, fmt.Errorf("ID generation failed: %w", err)
    }

    drop, err := model.NewDrop(dropID, authorID, content, visibility)
    if err != nil {
        return nil, fmt.Errorf("failed to create drop: %w", err)
    }

    // 永続化
    if err := uc.dropRepo.Save(ctx, drop); err != nil {
        return nil, fmt.Errorf("failed to save drop: %w", err)
    }

    return toCreateDropOutput(drop), nil
}
```

### 2.4. Domain 層: ドメイン不変条件の検証

Domain 層は、ドメインモデルの不変条件を自律的に保証します。Value Object は生成時に自己検証を行い、Aggregate は内部状態の整合性を維持します。

#### 責務

| 検証項目 | 説明 | 例 |
|:--|:--|:--|
| Value Object の自己検証 | 値の有効性を生成時に保証 | UserID の UUID 形式、DropContent の文字数制限 |
| Aggregate 不変条件 | Aggregate 内部の整合性ルール | 投票の選択肢数上限、フォローの自己フォロー不可 |
| 状態遷移ルール | 許可された状態遷移のみを受け入れ | Draft → Published は可、Deleted → Published は不可 |
| ビジネスルール | ドメイン固有のビジネスルール | 同一 Drop への重複リアクション不可 |

#### Value Object の自己検証パターン

[ddd-patterns.md](./ddd-patterns.md) の Value Object 設計ガイドラインに準拠し、生成時にバリデーションを実行します。

```go
// internal/domain/model/drop_content.go
package model

import (
    "fmt"
    "strings"
    "unicode/utf8"
)

// DropContent は投稿内容を表す Value Object
type DropContent struct {
    value string
}

const (
    dropContentMaxLength = 500
    dropContentMinLength = 1
)

// NewDropContent は文字列から DropContent を生成する
// 生成時に不変条件を自己検証する
func NewDropContent(content string) (DropContent, error) {
    trimmed := strings.TrimSpace(content)

    if utf8.RuneCountInString(trimmed) < dropContentMinLength {
        return DropContent{}, fmt.Errorf("drop content must not be empty")
    }

    if utf8.RuneCountInString(trimmed) > dropContentMaxLength {
        return DropContent{}, fmt.Errorf(
            "drop content exceeds maximum length: %d > %d",
            utf8.RuneCountInString(trimmed),
            dropContentMaxLength,
        )
    }

    return DropContent{value: trimmed}, nil
}

// String は文字列表現を返す
func (c DropContent) String() string {
    return c.value
}

// Length はルーン数を返す
func (c DropContent) Length() int {
    return utf8.RuneCountInString(c.value)
}

// Equals は同一性を判定する
func (c DropContent) Equals(other DropContent) bool {
    return c.value == other.value
}
```

#### Aggregate の不変条件検証パターン

```go
// internal/domain/model/poll.go
package model

import (
    "context"
    "fmt"
    "time"

    "github.com/newmo-oss/ctxtime"
)

// Poll は投票機能を表す Aggregate
type Poll struct {
    id        PollID
    dropID    DropID
    options   []PollOption
    expiresAt time.Time
    isMulti   bool
}

const (
    pollMinOptions = 2
    pollMaxOptions = 4
)

// NewPoll は新しい Poll を生成する
// Aggregate の不変条件を検証する
func NewPoll(ctx context.Context, id PollID, dropID DropID, options []PollOption, expiresAt time.Time, isMulti bool) (*Poll, error) {
    // 不変条件: 選択肢数の範囲
    if len(options) < pollMinOptions {
        return nil, fmt.Errorf(
            "poll must have at least %d options, got %d",
            pollMinOptions,
            len(options),
        )
    }

    if len(options) > pollMaxOptions {
        return nil, fmt.Errorf(
            "poll must have at most %d options, got %d",
            pollMaxOptions,
            len(options),
        )
    }

    // 不変条件: 有効期限は未来であること
    // テスト容易性のため ctxtime.Now(ctx) を使用する
    if !expiresAt.After(ctxtime.Now(ctx)) {
        return nil, fmt.Errorf("poll expiration must be in the future")
    }

    // 不変条件: 選択肢の重複不可
    seen := make(map[string]struct{})
    for _, opt := range options {
        if _, exists := seen[opt.Text()]; exists {
            return nil, fmt.Errorf("duplicate poll option: %s", opt.Text())
        }
        seen[opt.Text()] = struct{}{}
    }

    return &Poll{
        id:        id,
        dropID:    dropID,
        options:   options,
        expiresAt: expiresAt,
        isMulti:   isMulti,
    }, nil
}
```

### 2.5. Infrastructure 層: 外部依存の検証

Infrastructure 層は、外部システムとのやり取りにおける検証を担います。DB 制約違反や外部 API のレスポンス検証を行い、ドメインエラーに変換します。

#### 責務

| 検証項目 | 説明 | 例 |
|:--|:--|:--|
| DB 制約違反の変換 | 一意制約、外部キー制約のドメインエラーへの変換 | ユーザー名重複時の `ALREADY_EXISTS` エラー |
| 外部 API レスポンス検証 | 外部サービスの応答が期待通りであること | ステータスコード、レスポンスボディの構造 |
| データ整合性検証 | 取得したデータが期待する構造であること | NULL でないべきフィールドの確認 |
| キャッシュ整合性 | キャッシュデータの有効性検証 | TTL 切れ、データ形式の確認 |

#### 実装パターン

```go
// internal/infrastructure/repository/postgres_user_repository.go
package repository

import (
    "context"
    "errors"
    "fmt"

    "github.com/jackc/pgx/v5/pgconn"

    "avion-user/internal/domain/model"
    domainerrors "avion-user/internal/domain/errors"
)

// PostgresUserRepository は PostgreSQL を使用した UserRepository 実装
type PostgresUserRepository struct {
    db *DB
}

// Save はユーザーを保存する
func (r *PostgresUserRepository) Save(ctx context.Context, user *model.User) error {
    err := r.db.Insert(ctx, toDAO(user))
    if err != nil {
        // Infrastructure 層: DB 制約違反をドメインエラーに変換
        var pgErr *pgconn.PgError
        if errors.As(err, &pgErr) {
            switch pgErr.ConstraintName {
            case "users_username_key":
                return domainerrors.NewAlreadyExists("username", user.Username().String())
            case "users_email_key":
                return domainerrors.NewAlreadyExists("email", user.Email().String())
            }
        }
        return fmt.Errorf("failed to save user: %w", err)
    }
    return nil
}
```

---

## 3. 共通パッケージ設計: `pkg/validation`

### 3.1. 設計方針

`pkg/validation` は、主に Handler 層での形式バリデーションを支援する再利用可能なバリデータ群を提供します。

**重要な設計判断:**

- Domain 層のバリデーションは Value Object の自己検証として実装する（[ddd-patterns.md](./ddd-patterns.md) 準拠）
- `pkg/validation` は Domain 層には依存しない
- `pkg/validation` は技術的関心事として横断的に利用可能

### 3.2. パッケージ構造

```
pkg/
└── validation/
    ├── validator.go        # Validator 構造体とコアロジック
    ├── rules.go            # 組み込みバリデーションルール
    ├── errors.go           # バリデーションエラー型
    └── helpers.go          # ヘルパー関数（フィールド名生成など）
```

### 3.3. コアインターフェース

```go
// pkg/validation/validator.go
package validation

// Validator は複数のバリデーションルールを集約し、一括で検証結果を返す
type Validator struct {
    errors []FieldError
}

// New は新しい Validator を生成する
func New() *Validator {
    return &Validator{
        errors: make([]FieldError, 0),
    }
}

// Validate は蓄積されたバリデーションエラーを検証し、エラーがあれば ValidationError を返す
func (v *Validator) Validate() error {
    if len(v.errors) == 0 {
        return nil
    }
    return &ValidationError{
        Errors: v.errors,
    }
}

// HasErrors はバリデーションエラーが存在するかを返す
func (v *Validator) HasErrors() bool {
    return len(v.errors) > 0
}

// addError はバリデーションエラーを追加する
func (v *Validator) addError(field, rule, message string) {
    v.errors = append(v.errors, FieldError{
        Field:   field,
        Rule:    rule,
        Message: message,
    })
}
```

### 3.4. バリデーションルール

```go
// pkg/validation/rules.go
package validation

import (
    "fmt"
    "net/mail"
    "net/url"
    "regexp"
    "unicode/utf8"

    "github.com/google/uuid"
)

// --- 必須チェック ---

// RequiredString は文字列が空でないことを検証する
func (v *Validator) RequiredString(field, value string) {
    if value == "" {
        v.addError(field, "required", fmt.Sprintf("%s is required", field))
    }
}

// RequiredInt は整数がゼロでないことを検証する
func (v *Validator) RequiredInt(field string, value int) {
    if value == 0 {
        v.addError(field, "required", fmt.Sprintf("%s is required", field))
    }
}

// --- 文字列長 ---

// MinLength は文字列の最小長（ルーン数）を検証する
func (v *Validator) MinLength(field, value string, min int) {
    if utf8.RuneCountInString(value) < min {
        v.addError(field, "min_length", fmt.Sprintf("%s must be at least %d characters", field, min))
    }
}

// MaxLength は文字列の最大長（ルーン数）を検証する
func (v *Validator) MaxLength(field, value string, max int) {
    if utf8.RuneCountInString(value) > max {
        v.addError(field, "max_length", fmt.Sprintf("%s must be at most %d characters", field, max))
    }
}

// LengthBetween は文字列の長さが指定範囲内であることを検証する
func (v *Validator) LengthBetween(field, value string, min, max int) {
    length := utf8.RuneCountInString(value)
    if length < min || length > max {
        v.addError(field, "length_between", fmt.Sprintf("%s must be between %d and %d characters", field, min, max))
    }
}

// --- 数値範囲 ---

// IntMin は整数が最小値以上であることを検証する
func (v *Validator) IntMin(field string, value, min int) {
    if value < min {
        v.addError(field, "min", fmt.Sprintf("%s must be at least %d", field, min))
    }
}

// IntMax は整数が最大値以下であることを検証する
func (v *Validator) IntMax(field string, value, max int) {
    if value > max {
        v.addError(field, "max", fmt.Sprintf("%s must be at most %d", field, max))
    }
}

// IntBetween は整数が指定範囲内であることを検証する
func (v *Validator) IntBetween(field string, value, min, max int) {
    if value < min || value > max {
        v.addError(field, "between", fmt.Sprintf("%s must be between %d and %d", field, min, max))
    }
}

// --- コレクション ---

// MaxCount はスライスの要素数が上限以下であることを検証する
func (v *Validator) MaxCount(field string, count, max int) {
    if count > max {
        v.addError(field, "max_count", fmt.Sprintf("%s must have at most %d items", field, max))
    }
}

// MinCount はスライスの要素数が下限以上であることを検証する
func (v *Validator) MinCount(field string, count, min int) {
    if count < min {
        v.addError(field, "min_count", fmt.Sprintf("%s must have at least %d items", field, min))
    }
}

// --- フォーマット ---

// UUID は文字列が有効な UUID 形式であることを検証する
func (v *Validator) UUID(field, value string) {
    if value == "" {
        return // 空文字は RequiredString で検証する
    }
    if _, err := uuid.Parse(value); err != nil {
        v.addError(field, "uuid", fmt.Sprintf("%s must be a valid UUID", field))
    }
}

// Email は文字列が有効なメールアドレス形式であることを検証する
func (v *Validator) Email(field, value string) {
    if value == "" {
        return
    }
    if _, err := mail.ParseAddress(value); err != nil {
        v.addError(field, "email", fmt.Sprintf("%s must be a valid email address", field))
    }
}

// URL は文字列が有効な URL 形式であることを検証する
func (v *Validator) URL(field, value string) {
    if value == "" {
        return
    }
    u, err := url.Parse(value)
    if err != nil || u.Scheme == "" || u.Host == "" {
        v.addError(field, "url", fmt.Sprintf("%s must be a valid URL", field))
    }
}

// MatchesRegex は文字列が正規表現パターンに合致することを検証する
func (v *Validator) MatchesRegex(field, value string, pattern *regexp.Regexp, description string) {
    if value == "" {
        return
    }
    if !pattern.MatchString(value) {
        v.addError(field, "pattern", fmt.Sprintf("%s must match %s", field, description))
    }
}

// --- 列挙値 ---

// OneOf は値が許可された値の一覧に含まれることを検証する
func (v *Validator) OneOf(field, value string, allowed []string) {
    for _, a := range allowed {
        if value == a {
            return
        }
    }
    v.addError(field, "one_of", fmt.Sprintf("%s must be one of: %v", field, allowed))
}
```

### 3.5. エラー型

```go
// pkg/validation/errors.go
package validation

import (
    "errors"
    "fmt"
    "strings"
)

// FieldError は個別フィールドのバリデーションエラー
type FieldError struct {
    Field   string `json:"field"`
    Rule    string `json:"rule"`
    Message string `json:"message"`
}

// ValidationError は複数のフィールドエラーを集約するエラー型
type ValidationError struct {
    Errors []FieldError `json:"errors"`
}

// Error は error インターフェースを満たす
func (e *ValidationError) Error() string {
    if len(e.Errors) == 0 {
        return "validation failed"
    }

    messages := make([]string, 0, len(e.Errors))
    for _, fe := range e.Errors {
        messages = append(messages, fe.Message)
    }

    return fmt.Sprintf("validation failed: %s", strings.Join(messages, "; "))
}

// FieldErrors はフィールドエラーの一覧を返す
func (e *ValidationError) FieldErrors() []FieldError {
    return e.Errors
}

// HasField は指定フィールドにエラーがあるかを判定する
func (e *ValidationError) HasField(field string) bool {
    for _, fe := range e.Errors {
        if fe.Field == field {
            return true
        }
    }
    return false
}

// IsValidationError は error が ValidationError であるかを判定する
// errors.As を使用してエラーチェーンを辿る
func IsValidationError(err error) bool {
    var ve *ValidationError
    return errors.As(err, &ve)
}

// AsValidationError は error を ValidationError に変換する
// errors.As を使用してエラーチェーンを辿る
func AsValidationError(err error) (*ValidationError, bool) {
    var ve *ValidationError
    ok := errors.As(err, &ve)
    return ve, ok
}
```

### 3.6. ヘルパー関数

```go
// pkg/validation/helpers.go
package validation

import "fmt"

// IndexedField は配列フィールドのインデックス付き名前を生成する
// 例: IndexedField("media_ids", 0) => "media_ids[0]"
func IndexedField(field string, index int) string {
    return fmt.Sprintf("%s[%d]", field, index)
}

// NestedField はネストされたフィールド名を生成する
// 例: NestedField("address", "city") => "address.city"
func NestedField(parent, child string) string {
    return fmt.Sprintf("%s.%s", parent, child)
}
```

---

## 4. エラーマッピング

### 4.1. バリデーションエラーからエラーコードへの変換

各層のバリデーションエラーは、[error-standards.md](../errors/error-standards.md) のエラーコード体系に基づいて変換されます。

```
層                    エラーコードパターン                    プロトコルマッピング
─────────────────────────────────────────────────────────────────────────
Handler 層            [SERVICE]_HANDLER_BAD_REQUEST          HTTP 400 / gRPC InvalidArgument
UseCase 層            [SERVICE]_USECASE_INVALID_INPUT        HTTP 400 / gRPC InvalidArgument
                      [SERVICE]_USECASE_UNAUTHORIZED         HTTP 401 / gRPC Unauthenticated
                      [SERVICE]_USECASE_FORBIDDEN            HTTP 403 / gRPC PermissionDenied
                      [SERVICE]_USECASE_PRECONDITION_FAILED  HTTP 412 / gRPC FailedPrecondition
Domain 層             [SERVICE]_DOMAIN_VALIDATION_FAILED     HTTP 400 / gRPC InvalidArgument
                      [SERVICE]_DOMAIN_INVALID_STATE         HTTP 409 / gRPC Aborted
                      [SERVICE]_DOMAIN_BUSINESS_RULE_VIOLATION HTTP 422 / gRPC FailedPrecondition
Infrastructure 層     [SERVICE]_INFRA_DATABASE_ERROR         HTTP 500 / gRPC Internal
                      (制約違反はドメインエラーに変換)
```

### 4.2. Handler 層でのエラーマッピング実装

```go
// internal/handler/connectrpc/error_mapper.go
package connectrpc

import (
    "errors"

    "connectrpc.com/connect"

    domainerrors "avion-drop/internal/domain/errors"
    usecaseerrors "avion-drop/internal/usecase/errors"
    "avion-drop/pkg/validation"
)

// mapUseCaseError は UseCase 層のエラーを ConnectRPC エラーに変換する
func mapUseCaseError(err error) error {
    if err == nil {
        return nil
    }

    // バリデーションエラー
    var validationErr *validation.ValidationError
    if errors.As(err, &validationErr) {
        return connect.NewError(connect.CodeInvalidArgument, validationErr)
    }

    // ドメインエラー
    var domainErr domainerrors.DomainError
    if errors.As(err, &domainErr) {
        switch {
        case domainErr.IsNotFound():
            return connect.NewError(connect.CodeNotFound, domainErr)
        case domainErr.IsAlreadyExists():
            return connect.NewError(connect.CodeAlreadyExists, domainErr)
        case domainErr.IsInvalidState():
            return connect.NewError(connect.CodeFailedPrecondition, domainErr)
        case domainErr.IsValidationFailed():
            return connect.NewError(connect.CodeInvalidArgument, domainErr)
        }
    }

    // UseCase エラー
    var usecaseErr usecaseerrors.UseCaseError
    if errors.As(err, &usecaseErr) {
        switch {
        case usecaseErr.IsUnauthorized():
            return connect.NewError(connect.CodeUnauthenticated, usecaseErr)
        case usecaseErr.IsForbidden():
            return connect.NewError(connect.CodePermissionDenied, usecaseErr)
        case usecaseErr.IsPreconditionFailed():
            return connect.NewError(connect.CodeFailedPrecondition, usecaseErr)
        }
    }

    // デフォルト: 内部エラー
    return connect.NewError(connect.CodeInternal, err)
}
```

### 4.3. GraphQL エラーレスポンスへの変換

avion-gateway が GraphQL を公開するため、バリデーションエラーを GraphQL エラー拡張に変換するパターンも定義します。

```go
// internal/handler/graphql/error_presenter.go
package graphql

import (
    "context"
    "errors"

    "github.com/99designs/gqlgen/graphql"
    "github.com/vektah/gqlparser/v2/gqlerror"

    "avion-gateway/pkg/validation"
)

// ErrorPresenter は GraphQL エラーのカスタムプレゼンター
func ErrorPresenter(ctx context.Context, err error) *gqlerror.Error {
    var validationErr *validation.ValidationError
    if errors.As(err, &validationErr) {
        // バリデーションエラーをフィールドごとの拡張情報付きで返却
        fieldErrors := make([]map[string]interface{}, 0, len(validationErr.FieldErrors()))
        for _, fe := range validationErr.FieldErrors() {
            fieldErrors = append(fieldErrors, map[string]interface{}{
                "field":   fe.Field,
                "rule":    fe.Rule,
                "message": fe.Message,
            })
        }

        return &gqlerror.Error{
            Message: "Validation failed",
            Extensions: map[string]interface{}{
                "code":         "VALIDATION_ERROR",
                "field_errors": fieldErrors,
            },
        }
    }

    // デフォルトのエラーハンドリング
    return graphql.DefaultErrorPresenter(ctx, err)
}
```

---

## 5. テスト戦略

### 5.1. TDD 準拠ワークフロー

[development-guidelines.md](./development-guidelines.md) および CLAUDE.md に基づき、以下の TDD ワークフローに従います。

1. **Step 1**: バリデーションルールのインターフェース定義
2. **Step 2**: テーブル駆動テストの実装（テスト名は日本語）
3. **Step 3**: プロダクトコード実装
4. **Step 4**: `go test ./...` と `golangci-lint run` での検証

### 5.2. テスト例

```go
// pkg/validation/validator_test.go
package validation_test

import (
    "testing"

    "github.com/google/go-cmp/cmp"

    "avion/pkg/validation"
)

func TestValidator_RequiredString(t *testing.T) {
    tests := []struct {
        name       string
        field      string
        value      string
        wantErrors []validation.FieldError
    }{
        {
            name:       "正常系: 値が存在する場合はエラーなし",
            field:      "username",
            value:      "testuser",
            wantErrors: nil,
        },
        {
            name:  "異常系: 空文字の場合はエラー",
            field: "username",
            value: "",
            wantErrors: []validation.FieldError{
                {
                    Field:   "username",
                    Rule:    "required",
                    Message: "username is required",
                },
            },
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            v := validation.New()
            v.RequiredString(tt.field, tt.value)

            err := v.Validate()

            if tt.wantErrors == nil {
                if err != nil {
                    t.Errorf("unexpected error: %v", err)
                }
                return
            }

            ve, ok := validation.AsValidationError(err)
            if !ok {
                t.Fatalf("expected ValidationError, got %T", err)
            }

            if diff := cmp.Diff(tt.wantErrors, ve.FieldErrors()); diff != "" {
                t.Errorf("field errors mismatch (-want +got):\n%s", diff)
            }
        })
    }
}

func TestValidator_MaxLength(t *testing.T) {
    tests := []struct {
        name      string
        field     string
        value     string
        max       int
        wantError bool
    }{
        {
            name:      "正常系: 最大長以下の場合はエラーなし",
            field:     "content",
            value:     "hello",
            max:       10,
            wantError: false,
        },
        {
            name:      "正常系: 最大長ちょうどの場合はエラーなし",
            field:     "content",
            value:     "1234567890",
            max:       10,
            wantError: false,
        },
        {
            name:      "異常系: 最大長を超える場合はエラー",
            field:     "content",
            value:     "12345678901",
            max:       10,
            wantError: true,
        },
        {
            name:      "正常系: マルチバイト文字のルーン数で検証",
            field:     "content",
            value:     "あいうえお",
            max:       5,
            wantError: false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            v := validation.New()
            v.MaxLength(tt.field, tt.value, tt.max)

            err := v.Validate()

            if tt.wantError && err == nil {
                t.Error("expected error, got nil")
            }
            if !tt.wantError && err != nil {
                t.Errorf("unexpected error: %v", err)
            }
        })
    }
}

func TestValidator_UUID(t *testing.T) {
    tests := []struct {
        name      string
        field     string
        value     string
        wantError bool
    }{
        {
            name:      "正常系: 有効な UUID v4",
            field:     "user_id",
            value:     "550e8400-e29b-41d4-a716-446655440000",
            wantError: false,
        },
        {
            name:      "正常系: 空文字はスキップ（RequiredString で検証）",
            field:     "user_id",
            value:     "",
            wantError: false,
        },
        {
            name:      "異常系: 無効な UUID 形式",
            field:     "user_id",
            value:     "invalid-uuid",
            wantError: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            v := validation.New()
            v.UUID(tt.field, tt.value)

            err := v.Validate()

            if tt.wantError && err == nil {
                t.Error("expected error, got nil")
            }
            if !tt.wantError && err != nil {
                t.Errorf("unexpected error: %v", err)
            }
        })
    }
}

func TestValidator_MultipleRules(t *testing.T) {
    tests := []struct {
        name           string
        setup          func(v *validation.Validator)
        wantErrorCount int
    }{
        {
            name: "正常系: すべてのルールを満たす場合はエラーなし",
            setup: func(v *validation.Validator) {
                v.RequiredString("username", "testuser")
                v.MaxLength("username", "testuser", 20)
                v.UUID("user_id", "550e8400-e29b-41d4-a716-446655440000")
            },
            wantErrorCount: 0,
        },
        {
            name: "異常系: 複数のバリデーションエラーが蓄積される",
            setup: func(v *validation.Validator) {
                v.RequiredString("username", "")
                v.RequiredString("email", "")
                v.UUID("user_id", "invalid")
            },
            wantErrorCount: 3,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            v := validation.New()
            tt.setup(v)

            err := v.Validate()

            if tt.wantErrorCount == 0 {
                if err != nil {
                    t.Errorf("unexpected error: %v", err)
                }
                return
            }

            ve, ok := validation.AsValidationError(err)
            if !ok {
                t.Fatalf("expected ValidationError, got %T", err)
            }

            if len(ve.FieldErrors()) != tt.wantErrorCount {
                t.Errorf("expected %d errors, got %d", tt.wantErrorCount, len(ve.FieldErrors()))
            }
        })
    }
}
```

---

## 6. 実装チェックリスト

### 各サービスでのバリデーション実装手順

- [ ] 1. 共通パッケージの導入
  - [ ] `pkg/validation` パッケージをサービスに追加
  - [ ] テストの実行と確認

- [ ] 2. Handler 層のバリデーション実装
  - [ ] 各エンドポイントに `validate*Request` メソッドを実装
  - [ ] `pkg/validation` の Validator を使用
  - [ ] ConnectRPC エラーコードへのマッピング

- [ ] 3. UseCase 層のバリデーション実装
  - [ ] 事前条件検証の実装
  - [ ] 権限チェックの実装
  - [ ] 外部サービス連携を伴う検証の実装

- [ ] 4. Domain 層のバリデーション実装
  - [ ] Value Object の自己検証（NewXxx コンストラクタ）
  - [ ] Aggregate の不変条件検証
  - [ ] Domain Service によるクロス Aggregate 検証

- [ ] 5. Infrastructure 層のバリデーション実装
  - [ ] DB 制約違反のドメインエラーへの変換
  - [ ] 外部 API レスポンスの検証

- [ ] 6. テストの実装
  - [ ] 各層のバリデーションロジックに対するテーブル駆動テスト
  - [ ] エラーマッピングのテスト
  - [ ] カバレッジ 90% 以上の確認

---

## 7. 設計判断の記録

### 7.1. pkg/validation は Handler 層専用か

**判断**: Handler 層に限定しない。技術的なバリデーション（UUID 形式、文字列長など）は複数の層で必要になる可能性がある。ただし、Domain 層のバリデーションは Value Object の自己検証を優先し、`pkg/validation` に過度に依存しない。

**理由**: DDD パターンガイドラインでは Value Object が自身の不変条件を保証する責務を持つ。`pkg/validation` はあくまで技術的なユーティリティであり、ドメインロジックの置き場ではない。

### 7.2. バリデーションエラーの集約方式

**判断**: Fail-fast ではなく、すべてのエラーを収集してから一括返却する。

**理由**: クライアントに対して一度のリクエストですべての修正箇所を伝えることで、ユーザー体験を向上させる。API の利用効率も改善される。

### 7.3. カスタムバリデーションルールの拡張方法

**判断**: `Validator` に直接メソッドを追加するのではなく、`addError` を利用した独自検証関数の実装を推奨する。

**理由**: `pkg/validation` の肥大化を防ぎ、サービス固有のバリデーションルールは各サービス内で定義する。共通性の高いルールのみ `pkg/validation` に追加する。

---

## 8. 参考資料

- [Avion DDD 設計パターンガイドライン](./ddd-patterns.md)
- [Avion エラーコード標準化ガイドライン](../errors/error-standards.md)
- [Avion 共通開発ガイドライン](./development-guidelines.md)
- [Avion 共通 Observability パッケージ設計](../observability/observability-package-design.md)
- [Avion アーキテクチャ概要](./architecture.md)
