# [Service Name] マイグレーション設定テンプレート

このテンプレートを使用して、各マイクロサービスのマイグレーション設定を標準化します。

## 使用方法

1. このファイルを `avion-[service-name]/docs/migration-setup.md` にコピー
2. `[Service Name]` を実際のサービス名に置換
3. サービス固有の要件を追加

---

## 初期セットアップ手順

### 1. ディレクトリ構造の作成

```bash
cd avion-[service-name]

# マイグレーション関連ディレクトリを作成
mkdir -p migrations
mkdir -p migrations-seed
mkdir -p scripts

# .gitkeepファイルを追加
touch migrations/.gitkeep
touch migrations-seed/.gitkeep
```

### 2. Goose設定ファイル

```yaml
# .goose.yml
driver: postgres
dir: ./migrations
table: goose_db_version
```

### 3. Makefile設定

```makefile
# Makefile に以下を追加

# データベースマイグレーション設定
DB_HOST ?= localhost
DB_PORT ?= 5432
DB_NAME ?= avion_[service_name]_db
DB_USER ?= avion_[service_name]
DB_PASSWORD ?= $(shell echo $$DB_PASSWORD)
DB_SSL_MODE ?= disable

# 本番環境では require に設定
ifeq ($(ENVIRONMENT),production)
	DB_SSL_MODE = require
endif

DB_URL = postgres://$(DB_USER):$(DB_PASSWORD)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)?sslmode=$(DB_SSL_MODE)
GOOSE_CMD = goose -dir ./migrations postgres "$(DB_URL)"

# マイグレーションタスク
.PHONY: migrate-up migrate-down migrate-status migrate-create migrate-reset migrate-seed

migrate-up:
	@echo "🚀 Running database migrations for avion-[service-name]..."
	@$(GOOSE_CMD) up
	@echo "✅ Migrations completed successfully"

migrate-down:
	@echo "⬇️  Rolling back last migration..."
	@$(GOOSE_CMD) down
	@echo "✅ Rollback completed"

migrate-status:
	@echo "📊 Current migration status:"
	@$(GOOSE_CMD) status

migrate-create:
	@read -p "Enter migration name (e.g., add_user_profile): " name; \
	$(GOOSE_CMD) create $$name sql
	@echo "✅ Created new migration file"

migrate-reset:
	@echo "⚠️  WARNING: This will drop and recreate the database!"
	@echo "Environment: $(ENVIRONMENT)"
	@if [ "$(ENVIRONMENT)" = "production" ]; then \
		echo "❌ Cannot reset production database!"; \
		exit 1; \
	fi
	@read -p "Are you sure? (y/N): " confirm; \
	if [ "$$confirm" = "y" ]; then \
		$(GOOSE_CMD) reset; \
		$(GOOSE_CMD) up; \
		echo "✅ Database reset completed"; \
	else \
		echo "❌ Reset cancelled"; \
	fi

migrate-seed:
	@if [ "$(ENVIRONMENT)" = "production" ]; then \
		echo "❌ Cannot run seed in production!"; \
		exit 1; \
	fi
	@echo "🌱 Loading seed data..."
	@$(GOOSE_CMD) -dir ./migrations-seed up
	@echo "✅ Seed data loaded"

migrate-validate:
	@echo "🔍 Validating migration files..."
	@for file in migrations/*.sql; do \
		echo "Checking $$file..."; \
		if ! grep -q "+goose Up" $$file; then \
			echo "❌ Missing +goose Up directive in $$file"; \
			exit 1; \
		fi; \
		if ! grep -q "+goose Down" $$file; then \
			echo "❌ Missing +goose Down directive in $$file"; \
			exit 1; \
		fi; \
	done
	@echo "✅ All migration files are valid"

# Docker環境用
migrate-docker-up:
	@docker-compose exec [service-name] make migrate-up

migrate-docker-down:
	@docker-compose exec [service-name] make migrate-down

migrate-docker-status:
	@docker-compose exec [service-name] make migrate-status
```

### 4. 環境変数設定

```bash
# .env.example
# Database Configuration for avion-[service-name]
DB_HOST=localhost
DB_PORT=5432
DB_NAME=avion_[service_name]_db
DB_USER=avion_[service_name]
DB_PASSWORD=changeme
DB_SSL_MODE=disable

# Migration Configuration
MIGRATION_AUTO_RUN=false
MIGRATION_TIMEOUT=300
```

### 5. Docker Compose設定

```yaml
# docker-compose.yml (追加部分)
services:
  [service-name]:
    build: .
    environment:
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_NAME=avion_[service_name]_db
      - DB_USER=avion_[service_name]
      - DB_PASSWORD=${DB_PASSWORD}
      - DB_SSL_MODE=disable
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - ./migrations:/app/migrations
      - ./migrations-seed:/app/migrations-seed
    command: |
      sh -c "
        make migrate-up &&
        ./bin/avion-[service-name]
      "

  postgres:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=avion_[service_name]_db
      - POSTGRES_USER=avion_[service_name]
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U avion_[service_name]"]
      interval: 5s
      timeout: 5s
      retries: 5
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

### 6. 初期マイグレーションファイル

```sql
-- migrations/00001_init_schema.sql
-- +goose Up
-- +goose StatementBegin

-- =====================================================
-- Migration: Initial schema for avion-[service-name]
-- Author: [Your Name]
-- Date: 2025-01-13
-- Purpose: Create base tables and indexes
-- =====================================================

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Create schema version tracking
CREATE TABLE IF NOT EXISTS schema_metadata (
    key VARCHAR(255) PRIMARY KEY,
    value TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO schema_metadata (key, value) 
VALUES ('version', '1.0.0')
ON CONFLICT (key) DO NOTHING;

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Example: Create main entity table
-- CREATE TABLE IF NOT EXISTS [entities] (
--     id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
--     -- Add columns here
--     created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
--     updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
-- );

-- CREATE TRIGGER update_[entities]_updated_at 
--     BEFORE UPDATE ON [entities]
--     FOR EACH ROW 
--     EXECUTE FUNCTION update_updated_at_column();

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

-- Drop triggers first
-- DROP TRIGGER IF EXISTS update_[entities]_updated_at ON [entities];

-- Drop tables
-- DROP TABLE IF EXISTS [entities] CASCADE;

-- Drop functions
DROP FUNCTION IF EXISTS update_updated_at_column CASCADE;

-- Drop metadata
DROP TABLE IF EXISTS schema_metadata CASCADE;

-- Drop extensions
DROP EXTENSION IF EXISTS "pg_trgm";
DROP EXTENSION IF EXISTS "uuid-ossp";

-- +goose StatementEnd
```

### 7. シードデータテンプレート

```sql
-- migrations-seed/00001_test_data.sql
-- +goose Up
-- +goose StatementBegin

-- =====================================================
-- Seed Data for avion-[service-name]
-- Purpose: Development and testing data
-- =====================================================

-- WARNING: Never run this in production!
DO $$
BEGIN
    IF current_setting('custom.environment', true) = 'production' THEN
        RAISE EXCEPTION 'Cannot run seed data in production environment';
    END IF;
END $$;

-- Insert test data
-- INSERT INTO [entities] (id, ...) VALUES
--     ('00000000-0000-0000-0000-000000000001', ...),
--     ('00000000-0000-0000-0000-000000000002', ...);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

-- Clean up test data
-- DELETE FROM [entities] WHERE id IN (
--     '00000000-0000-0000-0000-000000000001',
--     '00000000-0000-0000-0000-000000000002'
-- );

-- +goose StatementEnd
```

### 8. GitHub Actions設定

```yaml
# .github/workflows/[service-name]-migration.yml
name: avion-[service-name] Database Migration

on:
  push:
    branches: [main, develop]
    paths:
      - 'avion-[service-name]/migrations/**'
      - 'avion-[service-name]/.goose.yml'
  pull_request:
    paths:
      - 'avion-[service-name]/migrations/**'
      - 'avion-[service-name]/.goose.yml'

jobs:
  test-migration:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_DB: avion_[service_name]_test
          POSTGRES_USER: test_user
          POSTGRES_PASSWORD: test_pass
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Go
      uses: actions/setup-go@v4
      with:
        go-version: '1.21'
    
    - name: Install goose
      run: go install github.com/pressly/goose/v3/cmd/goose@latest
    
    - name: Run migrations up
      working-directory: ./avion-[service-name]
      env:
        DB_HOST: localhost
        DB_PORT: 5432
        DB_NAME: avion_[service_name]_test
        DB_USER: test_user
        DB_PASSWORD: test_pass
        DB_SSL_MODE: disable
      run: make migrate-up
    
    - name: Validate schema
      env:
        PGPASSWORD: test_pass
      run: |
        psql -h localhost -U test_user -d avion_[service_name]_test -c "\dt"
        psql -h localhost -U test_user -d avion_[service_name]_test -c "\di"
    
    - name: Test rollback
      working-directory: ./avion-[service-name]
      env:
        DB_HOST: localhost
        DB_PORT: 5432
        DB_NAME: avion_[service_name]_test
        DB_USER: test_user
        DB_PASSWORD: test_pass
        DB_SSL_MODE: disable
      run: |
        make migrate-down
        make migrate-up
    
    - name: Run seed data
      if: github.event_name == 'pull_request'
      working-directory: ./avion-[service-name]
      env:
        DB_HOST: localhost
        DB_PORT: 5432
        DB_NAME: avion_[service_name]_test
        DB_USER: test_user
        DB_PASSWORD: test_pass
        DB_SSL_MODE: disable
      run: make migrate-seed
```

### 9. Kubernetes Job設定

```yaml
# k8s/migrations/[service-name]-migration-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: avion-[service-name]-migration-${BUILD_NUMBER}
  namespace: avion
  labels:
    app: avion-[service-name]
    component: migration
    version: ${VERSION}
spec:
  backoffLimit: 3
  ttlSecondsAfterFinished: 3600
  template:
    metadata:
      labels:
        app: avion-[service-name]
        component: migration
    spec:
      restartPolicy: Never
      initContainers:
      - name: wait-for-db
        image: busybox:1.35
        command: ['sh', '-c', 'until nc -z ${DB_HOST} ${DB_PORT}; do echo waiting for db; sleep 2; done']
        env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: avion-[service-name]-config
              key: db.host
        - name: DB_PORT
          valueFrom:
            configMapKeyRef:
              name: avion-[service-name]-config
              key: db.port
      containers:
      - name: migration
        image: avion-[service-name]:${VERSION}
        command: ["goose"]
        args: ["-dir", "/app/migrations", "postgres", "$(DB_URL)", "up"]
        env:
        - name: DB_URL
          valueFrom:
            secretKeyRef:
              name: avion-[service-name]-db-secret
              key: url
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
```

### 10. 監視設定

```yaml
# monitoring/[service-name]-migration-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: avion-[service-name]-migration-alerts
  namespace: avion
spec:
  groups:
  - name: migration
    interval: 30s
    rules:
    - alert: MigrationFailed
      expr: |
        kube_job_status_failed{
          namespace="avion",
          job_name=~"avion-[service-name]-migration-.*"
        } > 0
      for: 1m
      labels:
        severity: critical
        service: avion-[service-name]
      annotations:
        summary: "Migration failed for avion-[service-name]"
        description: "Migration job {{ $labels.job_name }} has failed. Check logs for details."
    
    - alert: MigrationTakingTooLong
      expr: |
        (
          time() - kube_job_status_start_time{
            namespace="avion",
            job_name=~"avion-[service-name]-migration-.*"
          }
        ) > 600
      for: 1m
      labels:
        severity: warning
        service: avion-[service-name]
      annotations:
        summary: "Migration taking too long for avion-[service-name]"
        description: "Migration job {{ $labels.job_name }} has been running for more than 10 minutes."
```

## チェックリスト

### 初期セットアップ
- [ ] ディレクトリ構造を作成
- [ ] .goose.yml を配置
- [ ] Makefile にマイグレーションタスクを追加
- [ ] .env.example を作成
- [ ] docker-compose.yml を更新
- [ ] 初期マイグレーションファイルを作成

### CI/CD設定
- [ ] GitHub Actions ワークフローを作成
- [ ] Kubernetes Job マニフェストを作成
- [ ] 監視アラートを設定

### ドキュメント
- [ ] README.md にマイグレーション手順を追加
- [ ] CONTRIBUTING.md にマイグレーション作成ガイドを追加
- [ ] トラブルシューティングガイドを作成

## サービス固有の考慮事項

このセクションに、サービス固有の要件や注意点を記載してください。

### 例: avion-auth の場合
- セッションテーブルの定期クリーンアップ
- パスワードハッシュアルゴリズムの更新戦略
- 監査ログの保持期間

### 例: avion-timeline の場合
- Redis Sorted Set との同期
- 大量データの段階的移行
- インデックスの最適化戦略

---

## 参考リンク

- [Goose Documentation](https://github.com/pressly/goose)
- [PostgreSQL Best Practices](https://wiki.postgresql.org/wiki/Don't_Do_This)
- [Zero-Downtime Migrations](https://www.braintreepayments.com/blog/safe-operations-for-high-volume-postgresql/)