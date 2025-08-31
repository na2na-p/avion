# ID生成ガイドライン

**Last Updated:** 2025/08/31  
**Compliance:** Backend採番によるID生成戦略

## 概要

Avionプラットフォームにおける統一的なID生成戦略を定義します。すべてのマイクロサービスはBackend採番によるID生成を行い、データベースの自動採番機能（AUTO_INCREMENT等）は使用しません。これにより、各サービスが独立してIDを生成でき、分散環境での整合性とパフォーマンスを両立します。

## 目次

1. [基本方針](#1-基本方針)
2. [推奨ID形式](#2-推奨id形式)
3. [実装ガイドライン](#3-実装ガイドライン)
4. [サービス別ID実装例](#4-サービス別id実装例)
5. [パフォーマンス考慮事項](#5-パフォーマンス考慮事項)
6. [セキュリティ考慮事項](#6-セキュリティ考慮事項)
7. [テスト戦略](#7-テスト戦略)

---

## 1. 基本方針

### Backend採番の原則

1. **データベース非依存**: データベースの自動採番機能（AUTO_INCREMENT、SERIAL等）は使用しない
2. **サービス独立性**: 各マイクロサービスが他のサービスに依存せずIDを生成できる
3. **グローバルユニーク性**: システム全体で一意性が保証される
4. **ソート可能性**: 時系列でのソートが可能（ULIDやSnowflakeID推奨）
5. **URL安全性**: URLパラメータとして使用可能な文字列形式

### 採番タイミング

- **Entity生成時**: ドメイン層でEntityやAggregateを生成する際にIDを採番
- **Repository保存前**: IDが設定された状態でRepositoryに渡す
- **イベント発行時**: IDを含めてイベントを発行し、イベントソーシングに対応

---

## 2. 推奨ID形式

### 優先順位と選定基準

| 優先順位 | ID形式 | 長所 | 短所 | 推奨用途 |
|---------|--------|------|------|----------|
| 1 | ULID | ソート可能、コンパクト、時刻情報含む | 実装がやや複雑 | 時系列データ（Drop、Timeline） |
| 2 | UUID v7 | ソート可能、標準仕様、時刻情報含む | 長い（36文字） | 標準準拠が必要な場合 |
| 3 | Snowflake ID | 数値型、高性能、ソート可能 | インスタンス管理が必要 | 高頻度生成が必要な場合 |
| 4 | UUID v4 | 実装簡単、衝突確率極小 | ソート不可、長い | 順序が不要な場合 |

### 形式別の特性

#### ULID (Universally Unique Lexicographically Sortable Identifier)
```
01ARZ3NDEKTSV4RRFFQ69G5FAV
```
- **長さ**: 26文字（Base32エンコード）
- **構成**: タイムスタンプ（48bit） + ランダム（80bit）
- **ソート**: 辞書順ソート可能
- **衝突確率**: 1ミリ秒内で2^80分の1

#### UUID v7 (RFC 9562)
```
018e3e28-5c42-7xxx-xxxx-xxxxxxxxxxxx
```
- **長さ**: 36文字（ハイフン含む）
- **構成**: Unixタイムスタンプ（48bit） + バージョン/ランダム
- **ソート**: 時系列ソート可能
- **標準**: RFC 9562準拠

#### Snowflake ID (Twitter方式)
```
1234567890123456789
```
- **長さ**: 最大19桁の数値（int64）
- **構成**: タイムスタンプ（41bit） + ワーカーID（10bit） + シーケンス（12bit）
- **ソート**: 時系列ソート可能
- **スループット**: 1ワーカーあたり4096 ID/ミリ秒

---

## 3. 実装ガイドライン

### パッケージ構造

```
avion-[service-name]/
└── internal/
    ├── domain/
    │   ├── value/
    │   │   ├── id.go           # ID値オブジェクト
    │   │   └── id_test.go      # IDテスト
    │   └── service/
    │       ├── id_generator.go # IDジェネレーター
    │       └── id_generator_test.go
    └── infrastructure/
        └── id/
            ├── ulid_generator.go    # ULID実装
            ├── uuid_generator.go    # UUID実装
            └── snowflake_generator.go # Snowflake実装
```

### インターフェース定義

```go
// internal/domain/service/id_generator.go
package service

import (
    "context"
    "github.com/avion/avion-[service-name]/internal/domain/value"
)

//go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/domain/service/mock_id_generator.go -package=service
type IDGenerator interface {
    // Generate は新しいIDを生成する
    Generate(ctx context.Context) (value.ID, error)
    
    // GenerateBatch は複数のIDを一括生成する
    GenerateBatch(ctx context.Context, count int) ([]value.ID, error)
}
```

### 値オブジェクトの実装

```go
// internal/domain/value/id.go
package value

import (
    "errors"
    "regexp"
)

var (
    ErrInvalidID     = errors.New("invalid ID format")
    ErrEmptyID       = errors.New("ID cannot be empty")
    ErrIDTooLong     = errors.New("ID exceeds maximum length")
)

const MaxIDLength = 36 // UUID v7の最大長

// ID はエンティティの識別子を表す値オブジェクト
type ID struct {
    value string
}

// NewID はIDを生成する
func NewID(value string) (ID, error) {
    if value == "" {
        return ID{}, ErrEmptyID
    }
    
    if len(value) > MaxIDLength {
        return ID{}, ErrIDTooLong
    }
    
    // 基本的な文字列検証（英数字とハイフン、アンダースコアのみ）
    if !isValidIDFormat(value) {
        return ID{}, ErrInvalidID
    }
    
    return ID{value: value}, nil
}

// String はIDの文字列表現を返す
func (id ID) String() string {
    return id.value
}

// Equal は他のIDと等しいか判定する
func (id ID) Equal(other ID) bool {
    return id.value == other.value
}

// IsZero はゼロ値かどうかを判定する
func (id ID) IsZero() bool {
    return id.value == ""
}

func isValidIDFormat(s string) bool {
    // 英数字、ハイフン、アンダースコアのみ許可
    pattern := `^[a-zA-Z0-9_-]+$`
    matched, _ := regexp.MatchString(pattern, s)
    return matched
}
```

---

## 4. サービス別ID実装例

### ULID実装例

```go
// internal/infrastructure/id/ulid_generator.go
package id

import (
    "context"
    "crypto/rand"
    "sync"
    "time"
    
    "github.com/oklog/ulid/v2"
    "github.com/avion/avion-[service-name]/internal/domain/service"
    "github.com/avion/avion-[service-name]/internal/domain/value"
)

// ULIDGenerator はULIDを使用したID生成の実装
type ULIDGenerator struct {
    entropy *ulid.MonotonicEntropy
    mu      sync.Mutex
}

// NewULIDGenerator はULIDGeneratorを生成する
func NewULIDGenerator() service.IDGenerator {
    return &ULIDGenerator{
        entropy: ulid.Monotonic(rand.Reader, 0),
    }
}

// Generate は新しいULIDを生成する
func (g *ULIDGenerator) Generate(ctx context.Context) (value.ID, error) {
    g.mu.Lock()
    defer g.mu.Unlock()
    
    ms := ulid.Timestamp(time.Now())
    id, err := ulid.New(ms, g.entropy)
    if err != nil {
        return value.ID{}, err
    }
    
    return value.NewID(id.String())
}

// GenerateBatch は複数のULIDを一括生成する
func (g *ULIDGenerator) GenerateBatch(ctx context.Context, count int) ([]value.ID, error) {
    if count <= 0 {
        return nil, errors.New("count must be positive")
    }
    
    ids := make([]value.ID, 0, count)
    for i := 0; i < count; i++ {
        id, err := g.Generate(ctx)
        if err != nil {
            return nil, err
        }
        ids = append(ids, id)
    }
    
    return ids, nil
}
```

### UUID v7実装例

```go
// internal/infrastructure/id/uuid_generator.go
package id

import (
    "context"
    
    "github.com/google/uuid"
    "github.com/avion/avion-[service-name]/internal/domain/service"
    "github.com/avion/avion-[service-name]/internal/domain/value"
)

// UUIDGenerator はUUID v7を使用したID生成の実装
type UUIDGenerator struct{}

// NewUUIDGenerator はUUIDGeneratorを生成する
func NewUUIDGenerator() service.IDGenerator {
    // UUID v7のサポートを有効化
    uuid.EnableRandPool()
    return &UUIDGenerator{}
}

// Generate は新しいUUID v7を生成する
func (g *UUIDGenerator) Generate(ctx context.Context) (value.ID, error) {
    // UUID v7を生成（時刻ベース + ランダム）
    id, err := uuid.NewV7()
    if err != nil {
        return value.ID{}, err
    }
    
    return value.NewID(id.String())
}

// GenerateBatch は複数のUUID v7を一括生成する
func (g *UUIDGenerator) GenerateBatch(ctx context.Context, count int) ([]value.ID, error) {
    if count <= 0 {
        return nil, errors.New("count must be positive")
    }
    
    ids := make([]value.ID, 0, count)
    for i := 0; i < count; i++ {
        id, err := g.Generate(ctx)
        if err != nil {
            return nil, err
        }
        ids = append(ids, id)
    }
    
    return ids, nil
}
```

### Snowflake ID実装例

```go
// internal/infrastructure/id/snowflake_generator.go
package id

import (
    "context"
    "errors"
    "fmt"
    "sync"
    "time"
    
    "github.com/avion/avion-[service-name]/internal/domain/service"
    "github.com/avion/avion-[service-name]/internal/domain/value"
)

const (
    // Snowflake IDのビット配分
    timestampBits = 41
    workerIDBits  = 10
    sequenceBits  = 12
    
    // 最大値
    maxWorkerID = -1 ^ (-1 << workerIDBits)
    maxSequence = -1 ^ (-1 << sequenceBits)
    
    // ビットシフト量
    timestampShift = workerIDBits + sequenceBits
    workerIDShift  = sequenceBits
    
    // カスタムエポック（2024年1月1日 00:00:00 UTC）
    customEpoch = int64(1704067200000)
)

// SnowflakeGenerator はSnowflake IDを使用したID生成の実装
type SnowflakeGenerator struct {
    mu          sync.Mutex
    workerID    int64
    sequence    int64
    lastTimestamp int64
}

// NewSnowflakeGenerator はSnowflakeGeneratorを生成する
func NewSnowflakeGenerator(workerID int64) (service.IDGenerator, error) {
    if workerID < 0 || workerID > maxWorkerID {
        return nil, fmt.Errorf("worker ID must be between 0 and %d", maxWorkerID)
    }
    
    return &SnowflakeGenerator{
        workerID: workerID,
    }, nil
}

// Generate は新しいSnowflake IDを生成する
func (g *SnowflakeGenerator) Generate(ctx context.Context) (value.ID, error) {
    g.mu.Lock()
    defer g.mu.Unlock()
    
    timestamp := g.currentTimestamp()
    
    if timestamp < g.lastTimestamp {
        return value.ID{}, errors.New("clock moved backwards")
    }
    
    if timestamp == g.lastTimestamp {
        g.sequence = (g.sequence + 1) & maxSequence
        if g.sequence == 0 {
            // シーケンスがオーバーフローした場合、次のミリ秒まで待機
            timestamp = g.waitNextMillis(timestamp)
        }
    } else {
        g.sequence = 0
    }
    
    g.lastTimestamp = timestamp
    
    // IDを構築
    id := ((timestamp - customEpoch) << timestampShift) |
          (g.workerID << workerIDShift) |
          g.sequence
    
    return value.NewID(fmt.Sprintf("%d", id))
}

// GenerateBatch は複数のSnowflake IDを一括生成する
func (g *SnowflakeGenerator) GenerateBatch(ctx context.Context, count int) ([]value.ID, error) {
    if count <= 0 {
        return nil, errors.New("count must be positive")
    }
    
    ids := make([]value.ID, 0, count)
    for i := 0; i < count; i++ {
        id, err := g.Generate(ctx)
        if err != nil {
            return nil, err
        }
        ids = append(ids, id)
    }
    
    return ids, nil
}

func (g *SnowflakeGenerator) currentTimestamp() int64 {
    return time.Now().UnixMilli()
}

func (g *SnowflakeGenerator) waitNextMillis(lastTimestamp int64) int64 {
    timestamp := g.currentTimestamp()
    for timestamp <= lastTimestamp {
        time.Sleep(time.Millisecond)
        timestamp = g.currentTimestamp()
    }
    return timestamp
}
```

### ユースケースでの使用例

```go
// internal/usecase/command/create_user_use_case.go
package command

import (
    "context"
    "fmt"
    
    "github.com/avion/avion-user/internal/domain/aggregate"
    "github.com/avion/avion-user/internal/domain/repository"
    "github.com/avion/avion-user/internal/domain/service"
    "github.com/avion/avion-user/internal/domain/value"
)

type CreateUserUseCase struct {
    userRepo    repository.UserRepository
    idGenerator service.IDGenerator
    logger      Logger
}

func NewCreateUserUseCase(
    userRepo repository.UserRepository,
    idGenerator service.IDGenerator,
    logger Logger,
) *CreateUserUseCase {
    return &CreateUserUseCase{
        userRepo:    userRepo,
        idGenerator: idGenerator,
        logger:      logger,
    }
}

func (uc *CreateUserUseCase) Execute(ctx context.Context, input CreateUserInput) (*CreateUserOutput, error) {
    // IDを生成
    userID, err := uc.idGenerator.Generate(ctx)
    if err != nil {
        uc.logger.Error("failed to generate user ID", "error", err)
        return nil, fmt.Errorf("ID generation failed: %w", err)
    }
    
    // ユーザー集約を作成
    user, err := aggregate.NewUser(
        userID,
        value.Username(input.Username),
        value.Email(input.Email),
    )
    if err != nil {
        return nil, fmt.Errorf("user creation failed: %w", err)
    }
    
    // リポジトリに保存
    if err := uc.userRepo.Save(ctx, user); err != nil {
        return nil, fmt.Errorf("user save failed: %w", err)
    }
    
    uc.logger.Info("user created", "user_id", userID.String())
    
    return &CreateUserOutput{
        UserID:    userID.String(),
        Username:  input.Username,
        Email:     input.Email,
        CreatedAt: user.CreatedAt(),
    }, nil
}
```

---

## 5. パフォーマンス考慮事項

### ID生成パフォーマンス比較

| ID形式 | 生成速度（ops/sec） | メモリ使用量 | 並行処理対応 |
|--------|-------------------|-------------|-------------|
| ULID | ~500,000 | 低 | Mutex必要 |
| UUID v7 | ~1,000,000 | 最低 | ロックフリー |
| UUID v4 | ~2,000,000 | 最低 | ロックフリー |
| Snowflake | ~4,000,000 | 低 | Mutex必要 |

### 最適化テクニック

#### バッチ生成
```go
// 大量のIDが必要な場合は一括生成
ids, err := idGenerator.GenerateBatch(ctx, 1000)
```

#### プール化
```go
// IDプールを事前生成して高速化
type IDPool struct {
    generator service.IDGenerator
    pool      chan value.ID
    refillSize int
}

func NewIDPool(generator service.IDGenerator, poolSize, refillSize int) *IDPool {
    pool := &IDPool{
        generator:  generator,
        pool:      make(chan value.ID, poolSize),
        refillSize: refillSize,
    }
    pool.refill(context.Background())
    return pool
}

func (p *IDPool) Get(ctx context.Context) (value.ID, error) {
    select {
    case id := <-p.pool:
        if len(p.pool) < p.refillSize {
            go p.refill(ctx)
        }
        return id, nil
    case <-ctx.Done():
        return value.ID{}, ctx.Err()
    default:
        return p.generator.Generate(ctx)
    }
}

func (p *IDPool) refill(ctx context.Context) {
    ids, err := p.generator.GenerateBatch(ctx, p.refillSize)
    if err != nil {
        return
    }
    for _, id := range ids {
        select {
        case p.pool <- id:
        default:
            return
        }
    }
}
```

### データベースインデックス最適化

```sql
-- ULIDやUUID v7の場合（B-treeインデックス）
CREATE INDEX idx_users_id ON users(id);

-- 時系列クエリが多い場合
CREATE INDEX idx_drops_created_at_id ON drops(created_at, id);

-- パーティショニングとの組み合わせ
CREATE TABLE drops (
    id VARCHAR(26) PRIMARY KEY,
    created_at TIMESTAMP NOT NULL,
    -- その他のカラム
) PARTITION BY RANGE (created_at);
```

---

## 6. セキュリティ考慮事項

### ID予測可能性の回避

1. **連番IDの禁止**: 推測可能な連番は使用しない
2. **タイムスタンプの隠蔽**: Snowflake IDの場合、外部APIではハッシュ化を検討
3. **ランダム性の確保**: 暗号学的に安全な乱数生成器を使用

### アクセス制御での利用

```go
// IDの検証とアクセス制御
func (uc *GetUserUseCase) Execute(ctx context.Context, requestorID, targetID string) (*UserOutput, error) {
    // IDフォーマット検証
    reqID, err := value.NewID(requestorID)
    if err != nil {
        return nil, ErrInvalidRequestorID
    }
    
    tgtID, err := value.NewID(targetID)
    if err != nil {
        return nil, ErrInvalidTargetID
    }
    
    // アクセス権限チェック
    if !uc.authService.CanAccess(ctx, reqID, tgtID) {
        return nil, ErrAccessDenied
    }
    
    // データ取得
    user, err := uc.userRepo.FindByID(ctx, tgtID)
    // ...
}
```

---

## 7. テスト戦略

### ID生成のテスト

```go
// internal/domain/service/id_generator_test.go
package service_test

import (
    "context"
    "sync"
    "testing"
    
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
    
    "github.com/avion/avion-[service-name]/internal/infrastructure/id"
)

func TestIDGenerator_Generate(t *testing.T) {
    tests := []struct {
        name      string
        generator func() service.IDGenerator
    }{
        {
            name: "ULID Generator",
            generator: func() service.IDGenerator {
                return id.NewULIDGenerator()
            },
        },
        {
            name: "UUID Generator",
            generator: func() service.IDGenerator {
                return id.NewUUIDGenerator()
            },
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            gen := tt.generator()
            ctx := context.Background()
            
            // 単一ID生成テスト
            id1, err := gen.Generate(ctx)
            require.NoError(t, err)
            assert.NotEmpty(t, id1.String())
            
            // ユニーク性テスト
            id2, err := gen.Generate(ctx)
            require.NoError(t, err)
            assert.NotEqual(t, id1, id2)
        })
    }
}

func TestIDGenerator_Uniqueness(t *testing.T) {
    gen := id.NewULIDGenerator()
    ctx := context.Background()
    
    const numIDs = 10000
    idMap := make(map[string]bool, numIDs)
    
    // 並行生成でのユニーク性テスト
    var wg sync.WaitGroup
    var mu sync.Mutex
    errors := make([]error, 0)
    
    for i := 0; i < numIDs; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            
            id, err := gen.Generate(ctx)
            if err != nil {
                mu.Lock()
                errors = append(errors, err)
                mu.Unlock()
                return
            }
            
            mu.Lock()
            if idMap[id.String()] {
                errors = append(errors, fmt.Errorf("duplicate ID: %s", id.String()))
            }
            idMap[id.String()] = true
            mu.Unlock()
        }()
    }
    
    wg.Wait()
    
    assert.Empty(t, errors, "ID generation errors")
    assert.Len(t, idMap, numIDs, "All IDs should be unique")
}

func TestIDGenerator_Sortability(t *testing.T) {
    gen := id.NewULIDGenerator()
    ctx := context.Background()
    
    // 時系列でID生成
    ids := make([]string, 0, 100)
    for i := 0; i < 100; i++ {
        id, err := gen.Generate(ctx)
        require.NoError(t, err)
        ids = append(ids, id.String())
        time.Sleep(time.Millisecond) // 時間差を作る
    }
    
    // ソート順序の検証
    for i := 1; i < len(ids); i++ {
        assert.Less(t, ids[i-1], ids[i], "IDs should be sortable")
    }
}
```

### モックを使用したテスト

```go
// internal/usecase/command/create_user_use_case_test.go
package command_test

import (
    "context"
    "testing"
    
    "github.com/golang/mock/gomock"
    "github.com/stretchr/testify/assert"
    
    "github.com/avion/avion-user/internal/domain/value"
    mock_service "github.com/avion/avion-user/tests/mocks/domain/service"
)

func TestCreateUserUseCase_Execute(t *testing.T) {
    ctrl := gomock.NewController(t)
    defer ctrl.Finish()
    
    mockIDGen := mock_service.NewMockIDGenerator(ctrl)
    
    testID, _ := value.NewID("test_user_123")
    
    // モックの期待値設定
    mockIDGen.EXPECT().
        Generate(gomock.Any()).
        Return(testID, nil)
    
    // ユースケース実行
    uc := NewCreateUserUseCase(mockUserRepo, mockIDGen, mockLogger)
    
    output, err := uc.Execute(context.Background(), CreateUserInput{
        Username: "testuser",
        Email:    "test@example.com",
    })
    
    assert.NoError(t, err)
    assert.Equal(t, "test_user_123", output.UserID)
}
```

---

## まとめ

このガイドラインに従うことで：

1. **一貫性**: すべてのサービスで統一されたID生成戦略
2. **独立性**: 各サービスが自律的にID生成可能
3. **拡張性**: 水平スケーリングに対応
4. **パフォーマンス**: 用途に応じた最適なID形式の選択
5. **テスタビリティ**: モックを使用した確実なテスト

各サービス開発時は、このガイドラインを参照し、適切なID生成戦略を実装してください。

## 関連ドキュメント

- [開発ガイドライン](./architecture/development-guidelines.md)
- [エラー標準化](./errors/error-standards.md)
- [環境変数管理](./infrastructure/environment-variables.md)