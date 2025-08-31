# SQL Injection Prevention Guidelines

**Last Updated:** 2025/08/30  
**Status:** Security Implementation Guide  
**Scope:** All Avion microservices using GORM

## Overview

This document provides comprehensive guidelines for preventing SQL injection vulnerabilities in the Avion platform. All services using GORM must follow these practices to ensure data security and integrity.

## Quick Reference

### Critical Rules
1. **NEVER** concatenate user input directly into SQL queries
2. **ALWAYS** use parameterized queries or GORM's built-in methods
3. **VALIDATE** all input before processing
4. **ESCAPE** special characters when raw SQL is unavoidable
5. **AUDIT** all database queries in code reviews

## GORM-Specific Prevention Techniques

### 1. Safe Query Methods

#### Using GORM's Built-in Methods (Recommended)

```go
// ✅ SAFE: Using GORM's method chaining
func (r *UserRepository) FindByUsername(ctx context.Context, username string) (*User, error) {
    var user User
    err := r.db.WithContext(ctx).
        Where("username = ?", username).
        First(&user).Error
    
    if err != nil {
        if errors.Is(err, gorm.ErrRecordNotFound) {
            return nil, ErrUserNotFound
        }
        return nil, fmt.Errorf("find user by username: %w", err)
    }
    return &user, nil
}

// ✅ SAFE: Using struct for conditions
func (r *UserRepository) FindByEmail(ctx context.Context, email string) (*User, error) {
    var user User
    err := r.db.WithContext(ctx).
        Where(&User{Email: email}).
        First(&user).Error
    
    return &user, err
}

// ✅ SAFE: Using map for conditions
func (r *UserRepository) FindByStatus(ctx context.Context, status string) ([]*User, error) {
    var users []*User
    err := r.db.WithContext(ctx).
        Where(map[string]interface{}{"status": status}).
        Find(&users).Error
    
    return users, err
}
```

#### Unsafe Patterns to Avoid

```go
// ❌ UNSAFE: String concatenation
func (r *UserRepository) UnsafeFindByUsername(username string) (*User, error) {
    var user User
    // NEVER DO THIS!
    query := fmt.Sprintf("SELECT * FROM users WHERE username = '%s'", username)
    err := r.db.Raw(query).Scan(&user).Error
    return &user, err
}

// ❌ UNSAFE: Direct interpolation in Where clause
func (r *UserRepository) UnsafeSearch(searchTerm string) ([]*User, error) {
    var users []*User
    // NEVER DO THIS!
    err := r.db.Where("name LIKE '%" + searchTerm + "%'").Find(&users).Error
    return users, err
}
```

### 2. Complex Query Patterns

#### Safe Dynamic Query Building

```go
// ✅ SAFE: Dynamic query with parameterized inputs
func (r *UserRepository) SearchUsers(ctx context.Context, filters UserSearchFilters) ([]*User, error) {
    query := r.db.WithContext(ctx).Model(&User{})
    
    // Safe dynamic conditions
    if filters.Username != "" {
        query = query.Where("username LIKE ?", "%"+filters.Username+"%")
    }
    
    if filters.Email != "" {
        query = query.Where("email = ?", filters.Email)
    }
    
    if filters.Status != "" {
        query = query.Where("status = ?", filters.Status)
    }
    
    if len(filters.Roles) > 0 {
        query = query.Where("role IN ?", filters.Roles)
    }
    
    // Safe sorting
    if filters.SortBy != "" {
        // Validate sort field against whitelist
        if isValidSortField(filters.SortBy) {
            order := filters.SortBy
            if filters.SortDesc {
                order += " DESC"
            }
            query = query.Order(order)
        }
    }
    
    // Safe pagination
    if filters.Limit > 0 {
        query = query.Limit(filters.Limit)
    }
    
    if filters.Offset > 0 {
        query = query.Offset(filters.Offset)
    }
    
    var users []*User
    err := query.Find(&users).Error
    return users, err
}

// Whitelist validation for sort fields
func isValidSortField(field string) bool {
    validFields := map[string]bool{
        "created_at": true,
        "updated_at": true,
        "username":   true,
        "email":      true,
        "status":     true,
    }
    return validFields[field]
}
```

#### Safe Raw SQL Queries

```go
// ✅ SAFE: When raw SQL is necessary, use parameterized queries
func (r *UserRepository) GetUserStatistics(ctx context.Context, startDate, endDate time.Time) (*UserStats, error) {
    var stats UserStats
    
    query := `
        SELECT 
            COUNT(*) as total_users,
            COUNT(CASE WHEN status = ? THEN 1 END) as active_users,
            COUNT(CASE WHEN created_at BETWEEN ? AND ? THEN 1 END) as new_users
        FROM users
        WHERE deleted_at IS NULL
    `
    
    err := r.db.WithContext(ctx).
        Raw(query, "active", startDate, endDate).
        Scan(&stats).Error
    
    return &stats, err
}

// ✅ SAFE: Named parameters for complex queries
func (r *UserRepository) GetUserActivity(ctx context.Context, userID string, days int) ([]Activity, error) {
    var activities []Activity
    
    query := `
        SELECT 
            u.id as user_id,
            u.username,
            COUNT(d.id) as drop_count,
            COUNT(f.follower_id) as follower_count
        FROM users u
        LEFT JOIN drops d ON u.id = d.user_id 
            AND d.created_at > NOW() - INTERVAL '@days days'
        LEFT JOIN follows f ON u.id = f.followed_id
            AND f.created_at > NOW() - INTERVAL '@days days'
        WHERE u.id = @userID
        GROUP BY u.id, u.username
    `
    
    err := r.db.WithContext(ctx).
        Raw(query, sql.Named("userID", userID), sql.Named("days", days)).
        Scan(&activities).Error
    
    return activities, err
}
```

### 3. Input Validation Layer

#### Comprehensive Input Validation

```go
package validation

import (
    "regexp"
    "strings"
    "unicode/utf8"
)

// UserInputValidator validates user inputs before database operations
type UserInputValidator struct {
    // Precompiled regex patterns for efficiency
    usernameRegex *regexp.Regexp
    emailRegex    *regexp.Regexp
    uuidRegex     *regexp.Regexp
}

func NewUserInputValidator() *UserInputValidator {
    return &UserInputValidator{
        usernameRegex: regexp.MustCompile(`^[a-zA-Z0-9_-]{3,30}$`),
        emailRegex:    regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`),
        uuidRegex:     regexp.MustCompile(`^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$`),
    }
}

// ValidateUsername ensures username is safe for database operations
func (v *UserInputValidator) ValidateUsername(username string) error {
    if username == "" {
        return ErrUsernameRequired
    }
    
    if !utf8.ValidString(username) {
        return ErrInvalidUTF8
    }
    
    if len(username) < 3 || len(username) > 30 {
        return ErrUsernameLengthInvalid
    }
    
    if !v.usernameRegex.MatchString(username) {
        return ErrUsernameFormatInvalid
    }
    
    // Check for SQL keywords (defense in depth)
    if containsSQLKeywords(username) {
        return ErrSuspiciousInput
    }
    
    return nil
}

// ValidateSearchTerm validates search input
func (v *UserInputValidator) ValidateSearchTerm(term string) error {
    if term == "" {
        return ErrSearchTermEmpty
    }
    
    if !utf8.ValidString(term) {
        return ErrInvalidUTF8
    }
    
    if len(term) > 100 {
        return ErrSearchTermTooLong
    }
    
    // Remove potentially dangerous characters
    cleaned := sanitizeSearchTerm(term)
    if cleaned != term {
        return ErrInvalidSearchCharacters
    }
    
    return nil
}

// ValidateUUID ensures UUID format is correct
func (v *UserInputValidator) ValidateUUID(id string) error {
    if !v.uuidRegex.MatchString(strings.ToLower(id)) {
        return ErrInvalidUUID
    }
    return nil
}

// containsSQLKeywords checks for common SQL injection patterns
func containsSQLKeywords(input string) bool {
    suspicious := []string{
        "SELECT", "INSERT", "UPDATE", "DELETE", "DROP",
        "UNION", "EXEC", "EXECUTE", "--", "/*", "*/",
        "xp_", "sp_", "0x", "\\x", "CAST", "CONVERT",
    }
    
    upperInput := strings.ToUpper(input)
    for _, keyword := range suspicious {
        if strings.Contains(upperInput, keyword) {
            return true
        }
    }
    return false
}

// sanitizeSearchTerm removes potentially dangerous characters
func sanitizeSearchTerm(term string) string {
    // Allow only alphanumeric, spaces, and basic punctuation
    allowed := regexp.MustCompile(`[^a-zA-Z0-9\s\-_.@]+`)
    return allowed.ReplaceAllString(term, "")
}
```

### 4. Repository Implementation Pattern

```go
package repository

import (
    "context"
    "fmt"
    "gorm.io/gorm"
)

// BaseRepository provides safe database operations
type BaseRepository struct {
    db        *gorm.DB
    validator *validation.UserInputValidator
}

func NewBaseRepository(db *gorm.DB) *BaseRepository {
    return &BaseRepository{
        db:        db,
        validator: validation.NewUserInputValidator(),
    }
}

// SafeFindByID validates ID before query
func (r *BaseRepository) SafeFindByID(ctx context.Context, id string, dest interface{}) error {
    // Validate UUID format
    if err := r.validator.ValidateUUID(id); err != nil {
        return fmt.Errorf("invalid id format: %w", err)
    }
    
    return r.db.WithContext(ctx).
        Where("id = ?", id).
        First(dest).Error
}

// SafeSearch performs validated search
func (r *BaseRepository) SafeSearch(ctx context.Context, searchTerm string, dest interface{}) error {
    // Validate search term
    if err := r.validator.ValidateSearchTerm(searchTerm); err != nil {
        return fmt.Errorf("invalid search term: %w", err)
    }
    
    // Use parameterized LIKE query
    pattern := "%" + searchTerm + "%"
    return r.db.WithContext(ctx).
        Where("name LIKE ? OR description LIKE ?", pattern, pattern).
        Find(dest).Error
}

// SafeBulkOperation validates all IDs before operation
func (r *BaseRepository) SafeBulkOperation(ctx context.Context, ids []string, operation func(*gorm.DB) error) error {
    // Validate all IDs
    for _, id := range ids {
        if err := r.validator.ValidateUUID(id); err != nil {
            return fmt.Errorf("invalid id in bulk operation: %w", err)
        }
    }
    
    // Execute operation in transaction
    return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
        query := tx.Where("id IN ?", ids)
        return operation(query)
    })
}
```

## Testing SQL Injection Prevention

### Unit Tests for Validation

```go
package repository_test

import (
    "testing"
    "github.com/stretchr/testify/assert"
)

func TestSQLInjectionPrevention(t *testing.T) {
    tests := []struct {
        name      string
        input     string
        shouldErr bool
        testFunc  func(string) error
    }{
        {
            name:      "Valid username",
            input:     "john_doe123",
            shouldErr: false,
        },
        {
            name:      "SQL injection attempt - DROP TABLE",
            input:     "admin'; DROP TABLE users; --",
            shouldErr: true,
        },
        {
            name:      "SQL injection attempt - UNION SELECT",
            input:     "' UNION SELECT * FROM passwords --",
            shouldErr: true,
        },
        {
            name:      "SQL injection attempt - OR 1=1",
            input:     "admin' OR '1'='1",
            shouldErr: true,
        },
        {
            name:      "SQL injection attempt - Hex encoding",
            input:     "0x27206F722027313227203D202731",
            shouldErr: true,
        },
        {
            name:      "SQL injection attempt - Comment",
            input:     "admin'--",
            shouldErr: true,
        },
        {
            name:      "SQL injection attempt - Semicolon",
            input:     "admin'; DELETE FROM users",
            shouldErr: true,
        },
    }
    
    validator := validation.NewUserInputValidator()
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := validator.ValidateUsername(tt.input)
            if tt.shouldErr {
                assert.Error(t, err, "Expected error for input: %s", tt.input)
            } else {
                assert.NoError(t, err, "Expected no error for input: %s", tt.input)
            }
        })
    }
}

func TestSearchTermSanitization(t *testing.T) {
    tests := []struct {
        name     string
        input    string
        expected string
    }{
        {
            name:     "Clean search term",
            input:    "hello world",
            expected: "hello world",
        },
        {
            name:     "Search with special chars",
            input:    "hello@example.com",
            expected: "hello@example.com",
        },
        {
            name:     "SQL injection characters removed",
            input:    "hello'; DROP TABLE--",
            expected: "hello DROP TABLE",
        },
        {
            name:     "Script tags removed",
            input:    "<script>alert('xss')</script>",
            expected: "scriptalertxssscript",
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := sanitizeSearchTerm(tt.input)
            assert.Equal(t, tt.expected, result)
        })
    }
}
```

### Integration Tests

```go
func TestRepositorySQLInjectionProtection(t *testing.T) {
    // Setup test database
    db := setupTestDB(t)
    repo := NewUserRepository(db)
    
    // Create test data
    testUser := &User{
        ID:       "550e8400-e29b-41d4-a716-446655440000",
        Username: "testuser",
        Email:    "test@example.com",
    }
    require.NoError(t, repo.Create(context.Background(), testUser))
    
    // Test various injection attempts
    injectionTests := []struct {
        name        string
        method      string
        payload     string
        shouldError bool
    }{
        {
            name:        "FindByUsername with injection",
            method:      "username",
            payload:     "testuser' OR '1'='1",
            shouldError: true,
        },
        {
            name:        "Search with UNION injection",
            method:      "search",
            payload:     "' UNION SELECT * FROM users--",
            shouldError: true,
        },
        {
            name:        "FindByID with malformed UUID",
            method:      "id",
            payload:     "550e8400-e29b-41d4-a716-446655440000' OR '1'='1",
            shouldError: true,
        },
    }
    
    for _, tt := range injectionTests {
        t.Run(tt.name, func(t *testing.T) {
            var result *User
            var err error
            
            switch tt.method {
            case "username":
                result, err = repo.FindByUsername(context.Background(), tt.payload)
            case "search":
                var results []*User
                results, err = repo.Search(context.Background(), tt.payload)
                if len(results) > 0 {
                    result = results[0]
                }
            case "id":
                result, err = repo.FindByID(context.Background(), tt.payload)
            }
            
            if tt.shouldError {
                assert.Error(t, err)
                assert.Nil(t, result)
            } else {
                assert.NoError(t, err)
            }
        })
    }
}
```

## Advanced GORM Patterns

### Safe Joins and Preloading

```go
// ✅ SAFE: Joins with parameterized conditions
func (r *DropRepository) GetDropsWithUserInfo(ctx context.Context, userID string) ([]*DropWithUser, error) {
    var drops []*DropWithUser
    
    // Validate UUID first
    if err := r.validator.ValidateUUID(userID); err != nil {
        return nil, fmt.Errorf("invalid user ID: %w", err)
    }
    
    err := r.db.WithContext(ctx).
        Table("drops").
        Select("drops.*, users.username, users.avatar_url").
        Joins("LEFT JOIN users ON users.id = drops.user_id").
        Where("drops.user_id = ? AND drops.deleted_at IS NULL", userID).
        Scan(&drops).Error
    
    return drops, err
}

// ✅ SAFE: Preloading with conditions
func (r *UserRepository) GetUserWithFollowers(ctx context.Context, userID string, limit int) (*User, error) {
    var user User
    
    // Validate inputs
    if err := r.validator.ValidateUUID(userID); err != nil {
        return nil, err
    }
    
    if limit <= 0 || limit > 100 {
        limit = 20 // Safe default
    }
    
    err := r.db.WithContext(ctx).
        Preload("Followers", func(db *gorm.DB) *gorm.DB {
            return db.Where("status = ?", "active").Limit(limit)
        }).
        Where("id = ?", userID).
        First(&user).Error
    
    return &user, err
}

// ❌ UNSAFE: Dynamic table names without validation
func (r *BaseRepository) UnsafeGetFromTable(tableName string, id string) error {
    // NEVER DO THIS!
    query := fmt.Sprintf("SELECT * FROM %s WHERE id = ?", tableName)
    return r.db.Raw(query, id).Error
}

// ✅ SAFE: Table names from whitelist
func (r *BaseRepository) SafeGetFromTable(tableName string, id string) error {
    allowedTables := map[string]bool{
        "users": true,
        "drops": true,
        "follows": true,
    }
    
    if !allowedTables[tableName] {
        return ErrInvalidTableName
    }
    
    if err := r.validator.ValidateUUID(id); err != nil {
        return err
    }
    
    // Safe to use after validation
    return r.db.Table(tableName).Where("id = ?", id).Error
}
```

### Safe Transactions and Batch Operations

```go
// ✅ SAFE: Batch operations with validation
func (r *UserRepository) BulkUpdateStatus(ctx context.Context, userIDs []string, newStatus string) error {
    // Validate all inputs
    for _, id := range userIDs {
        if err := r.validator.ValidateUUID(id); err != nil {
            return fmt.Errorf("invalid UUID in batch: %w", err)
        }
    }
    
    // Validate status against whitelist
    validStatuses := map[string]bool{
        "active": true,
        "inactive": true,
        "suspended": true,
    }
    
    if !validStatuses[newStatus] {
        return ErrInvalidStatus
    }
    
    // Safe batch update
    return r.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
        return tx.Model(&User{}).
            Where("id IN ?", userIDs).
            Update("status", newStatus).Error
    })
}

// ✅ SAFE: Complex aggregation with proper escaping
func (r *StatsRepository) GetAggregatedStats(ctx context.Context, groupBy string, startDate, endDate time.Time) ([]Stats, error) {
    // Whitelist for GROUP BY fields
    validGroupBy := map[string]string{
        "day":   "DATE(created_at)",
        "week":  "DATE_TRUNC('week', created_at)",
        "month": "DATE_TRUNC('month', created_at)",
        "user":  "user_id",
    }
    
    groupByClause, ok := validGroupBy[groupBy]
    if !ok {
        return nil, ErrInvalidGroupBy
    }
    
    var stats []Stats
    
    // Safe query with validated GROUP BY
    query := `
        SELECT 
            ? as period,
            COUNT(*) as count,
            COUNT(DISTINCT user_id) as unique_users
        FROM drops
        WHERE created_at BETWEEN ? AND ?
        GROUP BY ?
        ORDER BY ? DESC
    `
    
    err := r.db.WithContext(ctx).
        Raw(query, groupByClause, startDate, endDate, gorm.Expr(groupByClause), gorm.Expr(groupByClause)).
        Scan(&stats).Error
    
    return stats, err
}
```

## Code Review Checklist

### Required Checks
- [ ] All user inputs are validated before use in queries
- [ ] No string concatenation in SQL queries
- [ ] All queries use parameterized statements or GORM methods
- [ ] Input length limits are enforced
- [ ] Special characters are properly escaped or rejected
- [ ] UUID formats are validated
- [ ] Search terms are sanitized
- [ ] Whitelisting is used for dynamic field names (ORDER BY, etc.)
- [ ] Table names are never dynamically constructed from user input
- [ ] JOIN conditions use parameterized values
- [ ] Subqueries are properly parameterized

### Recommended Checks
- [ ] Input validation happens at multiple layers
- [ ] Error messages don't reveal database structure
- [ ] Database user has minimal required permissions
- [ ] Prepared statements are reused where possible
- [ ] Query logging doesn't expose sensitive data
- [ ] Rate limiting is applied to prevent abuse
- [ ] Audit logging tracks suspicious queries
- [ ] GORM hooks don't construct dynamic SQL
- [ ] Custom SQL functions are reviewed for injection risks

## Linter Configuration

### golangci-lint Configuration

```yaml
# .golangci.yml - Complete SQL injection prevention configuration
linters:
  enable:
    - gosec           # Security checks including SQL injection
    - sqlclosecheck   # Ensure sql.Rows are closed
    - rowserrcheck    # Check sql.Rows.Err()
    - noctx          # Require context.Context in database calls
    
linters-settings:
  gosec:
    # Severity of issues
    severity: medium
    # Confidence threshold
    confidence: medium
    # Exclude generated files
    excludes:
      - G304 # File path provided as taint input
      - G307 # Deferring unsafe method
    # Include specific SQL injection rules
    rules:
      - G201 # SQL query construction using format string
      - G202 # SQL query construction using string concatenation
    # Check specific functions
    includes:
      - fmt.Sprintf
      - strings.Join
      - strings.Builder
  
  # Custom linter rules
  custom:
    sql-checker:
      # Patterns to flag as errors
      patterns:
        - 'fmt\.Sprintf.*SELECT'
        - 'fmt\.Sprintf.*INSERT'
        - 'fmt\.Sprintf.*UPDATE'
        - 'fmt\.Sprintf.*DELETE'
        - '"\s*\+.*SELECT'
        - '"\s*\+.*INSERT'
        - '"\s*\+.*UPDATE'
        - '"\s*\+.*DELETE'
        - 'strings\.Join.*WHERE'
        - 'strings\.Builder.*FROM'

# Run configuration
run:
  # Timeout for analysis
  timeout: 5m
  # Include test files
  tests: true
  # Check generated files
  skip-generated: false
```

### Custom Linter Rules

```go
// tools/sqllinter/main.go - Custom SQL injection linter
package main

import (
    "go/ast"
    "go/token"
    "strings"
    
    "golang.org/x/tools/go/analysis"
)

var Analyzer = &analysis.Analyzer{
    Name: "sqlinject",
    Doc:  "Checks for potential SQL injection vulnerabilities",
    Run:  run,
}

func run(pass *analysis.Pass) (interface{}, error) {
    for _, file := range pass.Files {
        ast.Inspect(file, func(n ast.Node) bool {
            // Check for string concatenation in GORM calls
            if call, ok := n.(*ast.CallExpr); ok {
                if isGORMMethod(call) {
                    checkGORMCall(pass, call)
                }
            }
            
            // Check for fmt.Sprintf with SQL keywords
            if call, ok := n.(*ast.CallExpr); ok {
                if isFmtSprintf(call) {
                    checkSprintfSQL(pass, call)
                }
            }
            
            return true
        })
    }
    return nil, nil
}

func isGORMMethod(call *ast.CallExpr) bool {
    methodNames := []string{"Where", "Having", "Group", "Order", "Raw", "Exec"}
    if sel, ok := call.Fun.(*ast.SelectorExpr); ok {
        for _, name := range methodNames {
            if sel.Sel.Name == name {
                return true
            }
        }
    }
    return false
}

func checkGORMCall(pass *analysis.Pass, call *ast.CallExpr) {
    for _, arg := range call.Args {
        // Check for binary expressions (concatenation)
        if binExpr, ok := arg.(*ast.BinaryExpr); ok {
            if binExpr.Op == token.ADD {
                pass.Reportf(binExpr.Pos(), "potential SQL injection: avoid string concatenation in GORM queries")
            }
        }
        
        // Check for fmt.Sprintf calls
        if callExpr, ok := arg.(*ast.CallExpr); ok {
            if isFmtSprintf(callExpr) {
                pass.Reportf(callExpr.Pos(), "potential SQL injection: avoid fmt.Sprintf in GORM queries")
            }
        }
    }
}

func isFmtSprintf(call *ast.CallExpr) bool {
    if sel, ok := call.Fun.(*ast.SelectorExpr); ok {
        if ident, ok := sel.X.(*ast.Ident); ok {
            return ident.Name == "fmt" && sel.Sel.Name == "Sprintf"
        }
    }
    return false
}

func checkSprintfSQL(pass *analysis.Pass, call *ast.CallExpr) {
    if len(call.Args) > 0 {
        if lit, ok := call.Args[0].(*ast.BasicLit); ok {
            if lit.Kind == token.STRING {
                value := strings.ToUpper(lit.Value)
                sqlKeywords := []string{"SELECT", "INSERT", "UPDATE", "DELETE", "DROP", "CREATE", "ALTER"}
                for _, keyword := range sqlKeywords {
                    if strings.Contains(value, keyword) {
                        pass.Reportf(call.Pos(), "potential SQL injection: fmt.Sprintf used with SQL keyword '%s'", keyword)
                        break
                    }
                }
            }
        }
    }
}
```

### Pre-commit Hook Configuration

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/golangci/golangci-lint
    rev: v1.61.0
    hooks:
      - id: golangci-lint
        args: ['--config=.golangci.yml']
        
  - repo: local
    hooks:
      - id: sql-injection-check
        name: SQL Injection Check
        entry: scripts/check-sql-injection.sh
        language: script
        files: '\.go$'
        
      - id: gorm-pattern-check
        name: GORM Pattern Check
        entry: go run tools/sqllinter/main.go
        language: golang
        files: 'repository.*\.go$'
```

## Security Testing Tools

### Static Analysis Tools

#### Semgrep Rules for GORM

```yaml
# .semgrep/sql-injection.yml
rules:
  - id: gorm-string-concatenation
    pattern-either:
      - pattern: |
          $DB.Where($X + $Y, ...)
      - pattern: |
          $DB.Where(fmt.Sprintf(...), ...)
      - pattern: |
          $DB.Raw($X + $Y, ...)
      - pattern: |
          $DB.Raw(fmt.Sprintf(...), ...)
    message: "Potential SQL injection via string concatenation in GORM query"
    languages: [go]
    severity: ERROR
    
  - id: gorm-exec-dynamic-sql
    pattern-either:
      - pattern: |
          $DB.Exec($VAR)
      - pattern: |
          $DB.Exec($X + $Y)
    message: "Dynamic SQL execution detected - use parameterized queries"
    languages: [go]
    severity: ERROR
    
  - id: unsafe-order-by
    pattern: |
      $DB.Order($VAR)
    message: "Dynamic ORDER BY clause - ensure input is validated against whitelist"
    languages: [go]
    severity: WARNING
```

#### CodeQL Custom Queries

```ql
// codeql/sql-injection-gorm.ql
import go

class GormSqlInjection extends TaintTracking::Configuration {
  GormSqlInjection() { this = "GormSqlInjection" }
  
  override predicate isSource(DataFlow::Node source) {
    // User input sources
    exists(Function f |
      f.getName() = ["GetQueryParam", "GetFormValue", "GetHeader", "GetParam"] and
      source = f.getACall().getResult()
    )
  }
  
  override predicate isSink(DataFlow::Node sink) {
    // GORM method sinks
    exists(MethodCallExpr mce |
      mce.getReceiver().getType().getName() = "DB" and
      mce.getMethodName() = ["Where", "Having", "Group", "Order", "Raw", "Exec"] and
      sink = mce.getAnArgument()
    )
  }
}

from GormSqlInjection config, DataFlow::PathNode source, DataFlow::PathNode sink
where config.hasFlowPath(source, sink)
select sink.getNode(), source, sink,
  "Potential SQL injection: user input flows to GORM query at $@.", source.getNode(), "source"
```

### Dynamic Testing

#### Automated SQL Injection Testing Script

```bash
#!/bin/bash
# scripts/check-sql-injection.sh

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
API_BASE_URL="${API_BASE_URL:-http://localhost:8080}"
VERBOSE="${VERBOSE:-false}"

# Comprehensive SQL injection payloads
declare -A PAYLOADS=(
    ["basic_or"]="' OR '1'='1"
    ["union_select"]="' UNION SELECT * FROM users--"
    ["drop_table"]="'; DROP TABLE users; --"
    ["comment_bypass"]="admin'--"
    ["time_based"]="' OR SLEEP(5)--"
    ["boolean_blind"]="' AND 1=1--"
    ["stacked_queries"]="'; INSERT INTO users VALUES('hacker')--"
    ["hex_encoding"]="0x27206F722027313227203D202731"
    ["unicode_bypass"]="' OR U&'\\0027=\\0027"
    ["nested_select"]="' AND (SELECT COUNT(*) FROM users) > 0--"
    ["case_variation"]="' Or '1'='1"
    ["whitespace_bypass"]="'/**/OR/**/1=1--"
    ["double_encoding"]="%2527%2520OR%25201%253D1--"
    ["null_byte"]="' OR 1=1\x00--"
)

# Endpoints to test
ENDPOINTS=(
    "/api/v1/users/search?q="
    "/api/v1/drops/search?term="
    "/api/v1/users/profile?username="
    "/api/v1/timeline?user_id="
)

# Function to test a single payload
test_payload() {
    local endpoint=$1
    local payload_name=$2
    local payload=$3
    
    # URL encode the payload
    encoded_payload=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$payload'))")
    
    # Make request
    response=$(curl -s -w "\n%{http_code}" "${API_BASE_URL}${endpoint}${encoded_payload}" 2>/dev/null)
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    # Check for signs of successful injection
    if [[ "$body" == *"syntax error"* ]] || \
       [[ "$body" == *"SQL"* ]] || \
       [[ "$body" == *"mysql_"* ]] || \
       [[ "$body" == *"mysqli_"* ]] || \
       [[ "$body" == *"pg_"* ]] || \
       [[ "$body" == *"ORA-"* ]]; then
        echo -e "${RED}✗ VULNERABLE${NC}: $endpoint with $payload_name"
        echo "  Response contained SQL error information"
        return 1
    fi
    
    # Check if request was properly rejected
    if [[ "$http_code" == "400" ]] || [[ "$http_code" == "422" ]]; then
        echo -e "${GREEN}✓ PROTECTED${NC}: $endpoint blocked $payload_name"
        return 0
    fi
    
    # Check if response seems normal (might need refinement based on actual API)
    if [[ "$http_code" == "200" ]]; then
        # Additional checks for unexpected data
        if [[ $(echo "$body" | jq -r '.data | length' 2>/dev/null) -gt 100 ]]; then
            echo -e "${YELLOW}⚠ WARNING${NC}: $endpoint returned excessive data with $payload_name"
            return 1
        fi
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        echo "  HTTP $http_code for $payload_name"
    fi
    
    return 0
}

# Function to test time-based blind SQL injection
test_time_based() {
    local endpoint=$1
    
    echo "Testing time-based blind SQL injection on $endpoint..."
    
    # Baseline request
    start_time=$(date +%s%N)
    curl -s "${API_BASE_URL}${endpoint}normal" > /dev/null 2>&1
    baseline=$(($(date +%s%N) - start_time))
    
    # Time-based payload
    start_time=$(date +%s%N)
    curl -s "${API_BASE_URL}${endpoint}' AND SLEEP(3)--" > /dev/null 2>&1
    delayed=$(($(date +%s%N) - start_time))
    
    # Check if delay is significant (> 2.5 seconds)
    if [[ $((delayed - baseline)) -gt 2500000000 ]]; then
        echo -e "${RED}✗ VULNERABLE${NC}: Time-based SQL injection detected on $endpoint"
        return 1
    else
        echo -e "${GREEN}✓ PROTECTED${NC}: No time-based SQL injection on $endpoint"
        return 0
    fi
}

# Main testing loop
main() {
    echo "==================================="
    echo "SQL Injection Security Testing"
    echo "==================================="
    echo "Target: $API_BASE_URL"
    echo ""
    
    failed=0
    total=0
    
    for endpoint in "${ENDPOINTS[@]}"; do
        echo "Testing endpoint: $endpoint"
        echo "---------------------------------"
        
        for payload_name in "${!PAYLOADS[@]}"; do
            ((total++))
            if ! test_payload "$endpoint" "$payload_name" "${PAYLOADS[$payload_name]}"; then
                ((failed++))
            fi
        done
        
        # Test time-based attacks
        ((total++))
        if ! test_time_based "$endpoint"; then
            ((failed++))
        fi
        
        echo ""
    done
    
    echo "==================================="
    echo "Test Summary"
    echo "==================================="
    echo "Total tests: $total"
    echo "Passed: $((total - failed))"
    echo "Failed: $failed"
    
    if [[ $failed -gt 0 ]]; then
        echo -e "${RED}SECURITY RISK: SQL injection vulnerabilities detected!${NC}"
        exit 1
    else
        echo -e "${GREEN}All SQL injection tests passed successfully!${NC}"
        exit 0
    fi
}

# Run main function
main
```

### Penetration Testing with SQLMap

```bash
#!/bin/bash
# scripts/sqlmap-test.sh

# Automated SQLMap testing for CI/CD
API_URL="http://localhost:8080/api/v1"

# Test each endpoint with SQLMap
endpoints=(
    "/users/search?q=test"
    "/drops/search?term=hello"
    "/users/profile?username=admin"
)

for endpoint in "${endpoints[@]}"; do
    echo "Testing $endpoint with SQLMap..."
    
    sqlmap -u "${API_URL}${endpoint}" \
        --batch \
        --risk=3 \
        --level=5 \
        --technique=BEUSTQ \
        --tamper=space2comment \
        --random-agent \
        --output-dir=./sqlmap-results \
        --flush-session
    
    if [ $? -eq 0 ]; then
        echo "WARNING: Potential vulnerability found in $endpoint"
        exit 1
    fi
done

echo "All endpoints passed SQLMap testing"
```

## Compliance and Monitoring

### Logging Requirements

```go
// Log all validation failures for security monitoring
func (v *UserInputValidator) logValidationFailure(input string, reason string) {
    logger.Warn("Input validation failed",
        slog.String("reason", reason),
        slog.String("input_length", fmt.Sprintf("%d", len(input))),
        slog.String("input_hash", hashInput(input)), // Hash for privacy
        slog.String("trace_id", trace.SpanFromContext(ctx).SpanContext().TraceID().String()),
    )
}
```

### Metrics Collection

```go
// Track injection attempt metrics
var (
    sqlInjectionAttempts = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "sql_injection_attempts_total",
            Help: "Total number of detected SQL injection attempts",
        },
        []string{"service", "endpoint", "type"},
    )
)
```

## Best Practices Summary

### DO's and DON'Ts

#### ✅ DO - Safe Practices

```go
// DO: Use parameterized queries
db.Where("username = ?", userInput)
db.Where("age > ? AND age < ?", minAge, maxAge)

// DO: Use struct conditions
db.Where(&User{Username: userInput})

// DO: Validate all inputs
if err := validator.ValidateUUID(id); err != nil {
    return err
}

// DO: Use whitelists for dynamic fields
validFields := map[string]bool{"created_at": true, "name": true}
if validFields[sortField] {
    db.Order(sortField)
}

// DO: Use GORM's built-in methods
db.First(&user, "id = ?", id)
db.Find(&users).Where("status = ?", status)

// DO: Escape special characters in LIKE queries
pattern := "%" + strings.ReplaceAll(search, "%", "\\%") + "%"
db.Where("name LIKE ?", pattern)
```

#### ❌ DON'T - Unsafe Practices

```go
// DON'T: Concatenate strings
db.Where("username = '" + userInput + "'")

// DON'T: Use fmt.Sprintf for queries
db.Where(fmt.Sprintf("age > %d", userAge))

// DON'T: Trust user input for table/column names
db.Table(userInput).Find(&results)

// DON'T: Use Raw() with concatenation
db.Raw("SELECT * FROM users WHERE id = " + id)

// DON'T: Build queries with string builders
var query strings.Builder
query.WriteString("WHERE status = ")
query.WriteString(status)
db.Where(query.String())

// DON'T: Use Exec with dynamic SQL
db.Exec("DELETE FROM " + tableName)
```

### Implementation Checklist

#### Initial Setup
- [ ] Configure golangci-lint with SQL injection rules
- [ ] Set up pre-commit hooks for SQL pattern checking
- [ ] Implement input validation layer
- [ ] Create repository base classes with safe methods
- [ ] Configure database user with minimal permissions

#### Development Phase
- [ ] Review all database queries during code review
- [ ] Run static analysis on every commit
- [ ] Test with SQL injection payloads
- [ ] Document any raw SQL usage with justification
- [ ] Validate all user inputs at handler level

#### Testing Phase
- [ ] Run automated SQL injection tests
- [ ] Perform penetration testing with SQLMap
- [ ] Test with various encoding techniques
- [ ] Verify error messages don't leak information
- [ ] Check audit logs for suspicious patterns

#### Production Deployment
- [ ] Enable query logging for security monitoring
- [ ] Set up alerts for SQL injection attempts
- [ ] Implement rate limiting on search endpoints
- [ ] Regular security audits
- [ ] Keep GORM and dependencies updated

### Common Pitfalls to Avoid

1. **Trusting Frontend Validation**
   - Always validate on backend, even if frontend validates
   - Frontend validation is for UX, not security

2. **Assuming ORM Safety**
   - GORM is safe only when used correctly
   - Raw queries and string concatenation break safety

3. **Inadequate Input Length Limits**
   - Set reasonable maximum lengths
   - Prevent buffer overflow and DoS attacks

4. **Exposing Database Errors**
   - Never return raw database errors to users
   - Log detailed errors internally, return generic messages

5. **Insufficient Logging**
   - Log all validation failures
   - Track patterns of suspicious activity
   - Include request context in logs

### Security Layers

```
┌─────────────────────────────────────┐
│         API Gateway Layer           │
│    • Rate limiting                   │
│    • Request validation              │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│         Handler Layer               │
│    • Input sanitization             │
│    • Type validation                │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│         UseCase Layer               │
│    • Business logic validation      │
│    • Authorization checks           │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│       Repository Layer              │
│    • Parameterized queries          │
│    • Final validation               │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│         Database Layer              │
│    • Prepared statements            │
│    • Stored procedures              │
└─────────────────────────────────────┘
```

## Summary

Following these SQL injection prevention guidelines ensures the security of the Avion platform's data layer. Key principles:

1. **Never trust user input** - Always validate and sanitize
2. **Use parameterized queries** - GORM's methods or prepared statements
3. **Defense in depth** - Multiple validation layers
4. **Whitelist over blacklist** - Define allowed values explicitly
5. **Monitor and audit** - Track suspicious patterns
6. **Test continuously** - Automated security testing in CI/CD

Regular security audits and penetration testing should verify these measures remain effective as the codebase evolves.

## Additional Resources

- [OWASP SQL Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
- [GORM Security Best Practices](https://gorm.io/docs/security.html)
- [CWE-89: SQL Injection](https://cwe.mitre.org/data/definitions/89.html)
- [NIST Guidelines on Database Security](https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-123.pdf)