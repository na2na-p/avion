# Phase 0: 共通基盤構築 詳細実装計画

## 概要

全サービスの基盤となる共通コンポーネント、インフラストラクチャ、開発環境を構築するフェーズです。このフェーズの完了なしには後続フェーズを開始できないため、最優先で実施します。

## タイムライン: 2週間（2025-01-20 〜 2025-02-02）

---

## Week 1: インフラ基盤とツールチェーン

### Day 1-2: Kubernetes環境構築

#### 作業内容
```yaml
infrastructure:
  kubernetes:
    - ローカル開発用: kind/minikube クラスター
    - ステージング用: EKS/GKE クラスター
    - 本番用: EKS/GKE クラスター（マルチAZ）
    
  networking:
    - Ingress Controller (nginx-ingress)
    - Service Mesh検討 (Istio - オプション)
    - Network Policy定義
    
  storage:
    - StorageClass定義
    - PersistentVolume設定
```

#### 成果物
- `infrastructure/kubernetes/` ディレクトリ構造
- クラスター接続確認
- kubectl設定ドキュメント

### Day 2-3: データストア構築

#### PostgreSQL
```yaml
postgresql:
  deployment:
    - PostgreSQL 17 クラスター（HA構成）
    - pgpool-II設定
    - 自動バックアップ設定
    
  databases:
    - avion_auth_db
    - avion_user_db
    - avion_drop_db
    - avion_timeline_db
    - avion_notification_db
    - avion_media_db
    - avion_search_db
    - avion_moderation_db
    - avion_community_db
    - avion_system_admin_db
```

#### Redis
```yaml
redis:
  deployment:
    - Redis 7+ クラスター
    - Sentinel設定（HA）
    - パーシステンス設定
    
  namespaces:
    - cache:*
    - session:*
    - pubsub:*
    - queue:*
```

### Day 3-4: オブジェクトストレージとCDN

```yaml
object_storage:
  s3_compatible:
    - MinIO（開発/ステージング）
    - AWS S3（本番）
    
  buckets:
    - avion-media-uploads
    - avion-media-processed
    - avion-backups
    - avion-logs
    
  cdn:
    - CloudFront設定（本番）
    - キャッシュポリシー定義
```

### Day 4-5: CI/CD パイプライン

```yaml
cicd:
  github_actions:
    - .github/workflows/ci.yml
    - .github/workflows/cd-staging.yml
    - .github/workflows/cd-production.yml
    
  pipeline_stages:
    - lint & format check
    - unit tests
    - build Docker image
    - integration tests
    - security scan
    - deploy to k8s
    
  artifacts:
    - Docker Registry設定
    - Helm Chart Repository
```

---

## Week 2: 共通ライブラリとテンプレート

### Day 6-7: Go共通パッケージ

#### ディレクトリ構造
```
pkg/
├── errors/
│   ├── domain.go         # ドメインエラー定義
│   ├── handler.go        # エラーハンドリング
│   └── codes.go          # エラーコード定義
├── logging/
│   ├── logger.go         # 構造化ログ実装
│   ├── middleware.go     # ログミドルウェア
│   └── config.go         # ログ設定
├── telemetry/
│   ├── tracing.go        # OpenTelemetry統合
│   ├── metrics.go        # メトリクス収集
│   └── provider.go       # プロバイダー設定
├── config/
│   ├── env.go            # 環境変数管理
│   ├── validator.go      # 設定検証
│   └── loader.go         # 設定ローダー
├── ddd/
│   ├── aggregate.go      # Aggregate基底
│   ├── entity.go         # Entity基底
│   ├── value_object.go   # ValueObject基底
│   └── repository.go     # Repository interface
├── cqrs/
│   ├── command.go        # Command基底
│   ├── query.go          # Query基底
│   ├── handler.go        # Handler interface
│   └── bus.go            # Command/Query Bus
└── grpc/
    ├── interceptor.go    # gRPCインターセプター
    ├── health.go         # ヘルスチェック
    └── middleware.go      # 共通ミドルウェア
```

#### 実装例: エラーハンドリング
```go
// pkg/errors/domain.go
package errors

type DomainError struct {
    Code    string                 `json:"code"`
    Message string                 `json:"message"`
    Details map[string]interface{} `json:"details,omitempty"`
    Cause   error                  `json:"-"`
}

func (e *DomainError) Error() string {
    return fmt.Sprintf("[%s] %s", e.Code, e.Message)
}

func NewDomainError(code, message string) *DomainError {
    return &DomainError{
        Code:    code,
        Message: message,
        Details: make(map[string]interface{}),
    }
}
```

### Day 8-9: サービステンプレート

#### Makefileテンプレート
```makefile
.PHONY: all build test clean

SERVICE_NAME := avion-service
VERSION := $(shell git describe --tags --always --dirty)
GO_FILES := $(shell find . -type f -name '*.go' -not -path "./vendor/*")

all: lint test build

build:
	@echo "Building $(SERVICE_NAME)..."
	@go build -ldflags "-X main.version=$(VERSION)" -o bin/$(SERVICE_NAME) cmd/server/main.go

test:
	@echo "Running tests..."
	@go test -v -cover -race ./...

test-coverage:
	@echo "Running tests with coverage..."
	@go test -v -coverprofile=coverage.out ./...
	@go tool cover -html=coverage.out -o coverage.html

lint:
	@echo "Running linter..."
	@golangci-lint run

generate:
	@echo "Generating code..."
	@go generate ./...

docker-build:
	@echo "Building Docker image..."
	@docker build -t $(SERVICE_NAME):$(VERSION) .

migrate-up:
	@echo "Running migrations..."
	@migrate -path migrations -database "$(DATABASE_URL)" up

clean:
	@echo "Cleaning..."
	@rm -rf bin/ coverage.* 
```

#### Dockerfileテンプレート
```dockerfile
# Build stage
FROM golang:1.21-alpine AS builder

RUN apk add --no-cache git make

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN make build

# Runtime stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app

COPY --from=builder /app/bin/avion-service /app/
COPY --from=builder /app/migrations /app/migrations

EXPOSE 8080 9090

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ["/app/avion-service", "health"]

USER nobody:nobody

ENTRYPOINT ["/app/avion-service"]
```

### Day 10: 監視・ログ基盤

```yaml
monitoring:
  prometheus:
    - Prometheus Operator デプロイ
    - ServiceMonitor CRD設定
    - アラートルール定義
    
  grafana:
    - Grafanaデプロイ
    - ダッシュボードテンプレート
    - データソース設定
    
  loki:
    - Loki Stack デプロイ
    - Promtail設定
    - ログ収集ルール
    
  alerts:
    - AlertManager設定
    - 通知チャンネル設定（Slack等）
```

### Day 11-12: データベースマイグレーション

#### Gooseセットアップ
```bash
# 各サービス用のマイグレーションディレクトリ
services/
├── avion-auth/
│   └── migrations/
│       ├── 00001_create_users_table.sql
│       └── 00002_create_sessions_table.sql
├── avion-user/
│   └── migrations/
│       ├── 00001_create_profiles_table.sql
│       └── 00002_create_follows_table.sql
└── ...
```

#### マイグレーションスクリプト例
```sql
-- +goose Up
-- +goose StatementBegin
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS users;
-- +goose StatementEnd
```

### Day 13-14: 開発環境とドキュメント

#### docker-compose.yml（ローカル開発用）
```yaml
version: '3.8'

services:
  postgres:
    image: postgres:17-alpine
    environment:
      POSTGRES_USER: avion
      POSTGRES_PASSWORD: avion_dev
      POSTGRES_DB: avion_dev
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  minio:
    image: minio/minio:latest
    ports:
      - "9000:9000"
      - "9001:9001"
    environment:
      MINIO_ROOT_USER: avion
      MINIO_ROOT_PASSWORD: avion_dev
    command: server /data --console-address ":9001"
    volumes:
      - minio_data:/data

  meilisearch:
    image: getmeili/meilisearch:latest
    ports:
      - "7700:7700"
    environment:
      MEILI_MASTER_KEY: avion_dev
    volumes:
      - meilisearch_data:/meili_data

volumes:
  postgres_data:
  redis_data:
  minio_data:
  meilisearch_data:
```

#### 開発環境セットアップスクリプト
```bash
#!/bin/bash
# scripts/setup-dev.sh

echo "🚀 Setting up Avion development environment..."

# Check prerequisites
command -v docker >/dev/null 2>&1 || { echo "Docker is required but not installed. Aborting." >&2; exit 1; }
command -v go >/dev/null 2>&1 || { echo "Go is required but not installed. Aborting." >&2; exit 1; }
command -v make >/dev/null 2>&1 || { echo "Make is required but not installed. Aborting." >&2; exit 1; }

# Start infrastructure
echo "Starting infrastructure services..."
docker-compose up -d

# Wait for services
echo "Waiting for services to be ready..."
sleep 10

# Run migrations
echo "Running database migrations..."
for service in services/*/; do
    if [ -d "$service/migrations" ]; then
        echo "Migrating $service..."
        cd $service && make migrate-up && cd -
    fi
done

# Install dependencies
echo "Installing Go dependencies..."
go mod download

# Generate code
echo "Generating code..."
make generate

echo "✅ Development environment setup complete!"
```

---

## 成果物チェックリスト

### インフラストラクチャ
- [ ] Kubernetesクラスター（開発/ステージング/本番）
- [ ] PostgreSQLクラスター
- [ ] Redisクラスター
- [ ] S3/MinIO設定
- [ ] MeiliSearch設定
- [ ] CI/CDパイプライン

### 共通ライブラリ
- [ ] エラーハンドリングパッケージ
- [ ] 構造化ログパッケージ
- [ ] OpenTelemetry統合
- [ ] 環境変数管理
- [ ] DDD基底クラス
- [ ] CQRS実装

### 開発ツール
- [ ] Makefileテンプレート
- [ ] Dockerfileテンプレート
- [ ] docker-compose.yml
- [ ] マイグレーションテンプレート
- [ ] 開発環境セットアップスクリプト

### ドキュメント
- [ ] インフラ構成図
- [ ] 開発環境構築ガイド
- [ ] 共通ライブラリAPI仕様
- [ ] CI/CD利用ガイド

---

## 並行作業の割り当て

```yaml
team_allocation:
  infrastructure_team:
    members: 3-4
    tasks:
      - Kubernetes構築
      - データストア構築
      - 監視基盤構築
    
  library_team:
    members: 2-3
    tasks:
      - 共通パッケージ実装
      - DDD/CQRS基底実装
      - テンプレート作成
    
  devops_team:
    members: 2
    tasks:
      - CI/CD構築
      - Docker/Helm設定
      - 開発環境整備
```

---

## リスクと対策

| リスク | 影響 | 対策 |
|--------|------|------|
| インフラ構築遅延 | 全フェーズに影響 | ローカル環境で先行開発 |
| 共通ライブラリの品質問題 | 全サービスに影響 | 徹底的なテストとレビュー |
| 環境差異 | デプロイ時の問題 | Infrastructure as Code徹底 |

---

## Phase 0 完了条件

1. 全インフラコンポーネントが稼働している
2. 共通ライブラリのテストカバレッジ90%以上
3. CI/CDパイプラインが動作している
4. 開発チーム全員が環境構築完了
5. ドキュメントが完備されている

この条件を満たした時点で、Phase 1（認証・ゲートウェイ基盤）の開発を開始します。