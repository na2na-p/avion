# Avion データベースマイグレーション戦略

**Last Updated:** 2025/01/13  
**Status:** 必須実装項目  
**Compliance:** `.cursor/rules`準拠

## 概要

Avionプロジェクトの全マイクロサービスにおける、一貫性のあるデータベースマイグレーション戦略を定義します。
本ドキュメントは、マイグレーションツールの選定、ディレクトリ構造、実行戦略、ロールバック手順、CI/CD統合について規定します。

## 目次

1. [基本方針](#1-基本方針)
2. [マイグレーション管理方式](#2-マイグレーション管理方式)
3. [ツール選定と設定](#3-ツール選定と設定)
4. [ディレクトリ構造](#4-ディレクトリ構造)
5. [マイグレーションファイル命名規則](#5-マイグレーションファイル命名規則)
6. [実行戦略](#6-実行戦略)
7. [ロールバック戦略](#7-ロールバック戦略)
8. [CI/CD統合](#8-cicd統合)
9. [ベストプラクティス](#9-ベストプラクティス)
10. [トラブルシューティング](#10-トラブルシューティング)

---

## 1. 基本方針

### 1.1 原則

1. **サービス独立性**: 各マイクロサービスが独自のデータベースとマイグレーションを管理
2. **前方互換性**: マイグレーションは常に前方互換性を保つ
3. **ロールバック可能性**: すべてのマイグレーションは安全にロールバック可能
4. **自動化**: マイグレーションはCI/CDパイプラインで自動実行
5. **監査可能性**: すべてのマイグレーション履歴を記録

### 1.2 採用する管理方式

**分散管理方式**を採用します：
- 各マイクロサービスが独自のマイグレーションを管理
- サービス間の独立性を最大化
- デプロイの独立性を確保

---

## 2. マイグレーション管理方式

### 2.1 分散管理アーキテクチャ

```
avion/
├── avion-auth/
│   ├── migrations/          # avion-auth専用マイグレーション
│   │   ├── 00001_init_schema.sql
│   │   ├── 00002_add_mfa_tables.sql
│   │   └── ...
│   └── ...
├── avion-user/
│   ├── migrations/          # avion-user専用マイグレーション
│   │   ├── 00001_init_schema.sql
│   │   ├── 00002_add_profile_fields.sql
│   │   └── ...
│   └── ...
└── [other services...]
```

### 2.2 データベース分離

各サービスは独自のデータベース（またはスキーマ）を持ちます：

```yaml
# 環境変数設定例
avion-auth:
  DB_NAME: avion_auth_db
  DB_SCHEMA: public

avion-user:
  DB_NAME: avion_user_db
  DB_SCHEMA: public

avion-drop:
  DB_NAME: avion_drop_db
  DB_SCHEMA: public
```

---

## 3. ツール選定と設定

### 3.1 マイグレーションツール: Goose

[Goose](https://github.com/pressly/goose) を標準マイグレーションツールとして採用。

**選定理由:**
- Go言語ネイティブ（プロジェクト技術スタックと統一）
- SQLとGoコードの両方でマイグレーション記述可能
- ロールバックサポート
- 軽量で依存関係が少ない

### 3.2 インストールと設定

#### インストール
```bash
# 開発環境
go install github.com/pressly/goose/v3/cmd/goose@latest

# Docker環境（各サービスのDockerfile）
FROM golang:1.21-alpine AS builder
RUN go install github.com/pressly/goose/v3/cmd/goose@latest

FROM alpine:latest
COPY --from=builder /go/bin/goose /usr/local/bin/goose
```

#### 設定ファイル（各サービスのルート）
```yaml
# .goose.yml
driver: postgres
dir: ./migrations
table: goose_db_version
```

---

## 4. ディレクトリ構造

### 4.1 標準ディレクトリ構造

各マイクロサービスで以下の構造を採用：

```
avion-[service-name]/
├── migrations/
│   ├── 00001_init_schema.sql
│   ├── 00002_add_[feature]_tables.sql
│   ├── 00003_create_indexes.sql
│   ├── 00004_add_[feature]_columns.sql
│   └── ...
├── migrations-seed/              # 開発・テスト用シードデータ
│   ├── 00001_test_users.sql
│   ├── 00002_sample_data.sql
│   └── ...
├── scripts/
│   ├── migrate.sh               # マイグレーション実行スクリプト
│   ├── rollback.sh              # ロールバックスクリプト
│   └── reset.sh                 # 開発用リセットスクリプト
└── Makefile
```

### 4.2 Makefile テンプレート

```makefile
# データベースマイグレーション関連タスク
.PHONY: migrate migrate-up migrate-down migrate-status migrate-create migrate-reset

# 環境変数
DB_URL ?= postgres://$(DB_USER):$(DB_PASSWORD)@$(DB_HOST):$(DB_PORT)/$(DB_NAME)?sslmode=$(DB_SSL_MODE)
GOOSE_CMD = goose -dir ./migrations postgres "$(DB_URL)"

# マイグレーション実行（最新まで）
migrate-up:
	@echo "Running database migrations..."
	$(GOOSE_CMD) up
	@echo "Migrations completed successfully"

# 1つロールバック
migrate-down:
	@echo "Rolling back last migration..."
	$(GOOSE_CMD) down
	@echo "Rollback completed"

# マイグレーションステータス確認
migrate-status:
	@echo "Current migration status:"
	$(GOOSE_CMD) status

# 新規マイグレーション作成
migrate-create:
	@read -p "Enter migration name: " name; \
	$(GOOSE_CMD) create $$name sql

# 開発環境用: データベースリセット
migrate-reset:
	@echo "⚠️  WARNING: This will drop and recreate the database!"
	@read -p "Are you sure? (y/N): " confirm; \
	if [ "$$confirm" = "y" ]; then \
		$(GOOSE_CMD) reset; \
		$(GOOSE_CMD) up; \
		echo "Database reset completed"; \
	else \
		echo "Reset cancelled"; \
	fi

# テスト環境用: シードデータ投入
migrate-seed:
	@echo "Loading seed data..."
	$(GOOSE_CMD) -dir ./migrations-seed up
	@echo "Seed data loaded"

# CI/CD用: バージョン指定マイグレーション
migrate-to-version:
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION is required"; \
		exit 1; \
	fi
	$(GOOSE_CMD) up-to $(VERSION)

# ヘルスチェック用: DB接続確認
migrate-ping:
	$(GOOSE_CMD) version
```

---

## 5. マイグレーションファイル命名規則

### 5.1 ファイル名フォーマット

```
[sequence_number]_[description].sql
```

**例:**
- `00001_init_schema.sql`
- `00002_add_user_profile_tables.sql`
- `00003_create_timeline_indexes.sql`
- `00004_add_notification_preferences.sql`

### 5.2 シーケンス番号ルール

- 5桁の連番（00001から開始）
- 環境間での一貫性を保つため、タイムスタンプは使用しない
- マージコンフリクトを防ぐため、開発時は番号を100単位で確保

```
開発者A: 00100_*, 00101_*, ...
開発者B: 00200_*, 00201_*, ...
開発者C: 00300_*, 00301_*, ...
```

### 5.3 マイグレーション内容のテンプレート

```sql
-- +goose Up
-- +goose StatementBegin

-- =====================================================
-- Migration: [Brief description]
-- Author: [Developer name or team]
-- Date: [YYYY-MM-DD]
-- Purpose: [Detailed explanation of changes]
-- =====================================================

-- スキーマ変更
CREATE TABLE IF NOT EXISTS user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    token VARCHAR(255) NOT NULL UNIQUE,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- インデックス作成
CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_token ON user_sessions(token);
CREATE INDEX idx_user_sessions_expires_at ON user_sessions(expires_at);

-- 外部キー制約
ALTER TABLE user_sessions
    ADD CONSTRAINT fk_user_sessions_user_id
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

-- ロールバック処理
DROP TABLE IF EXISTS user_sessions CASCADE;

-- +goose StatementEnd
```

---

## 6. 実行戦略

### 6.1 環境別実行戦略

#### 開発環境 (Development)
```bash
# 自動実行（アプリケーション起動時）
make migrate-up

# 手動実行（必要に応じて）
make migrate-status
make migrate-reset  # データリセット含む
```

#### ステージング環境 (Staging)
```bash
# CI/CDパイプラインで自動実行
# デプロイ前にマイグレーション実行
make migrate-up

# ロールバックテスト
make migrate-down
make migrate-up
```

#### 本番環境 (Production)
```yaml
# Kubernetes Job として実行
apiVersion: batch/v1
kind: Job
metadata:
  name: avion-auth-migration-${BUILD_NUMBER}
spec:
  template:
    spec:
      containers:
      - name: migration
        image: avion-auth:${VERSION}
        command: ["goose"]
        args: ["-dir", "/migrations", "postgres", "$(DB_URL)", "up"]
        env:
        - name: DB_URL
          valueFrom:
            secretKeyRef:
              name: avion-auth-db-secret
              key: url
      restartPolicy: Never
  backoffLimit: 3
```

### 6.2 Blue-Greenデプロイ戦略

```mermaid
sequenceDiagram
    participant Blue as Blue環境(現行)
    participant DB as Database
    participant Green as Green環境(新規)
    participant LB as Load Balancer
    
    Note over Blue,DB: Step 1: 現行運用中
    Blue->>DB: 読み書き
    
    Note over DB,Green: Step 2: マイグレーション実行
    Green->>DB: マイグレーション（前方互換性保証）
    
    Note over Blue,Green: Step 3: 両環境共存
    Blue->>DB: 旧スキーマで動作
    Green->>DB: 新スキーマで動作（互換性維持）
    
    Note over LB,Green: Step 4: トラフィック切り替え
    LB->>Green: トラフィック移行
    
    Note over Blue: Step 5: Blue環境停止
    Blue->>Blue: Shutdown
```

### 6.3 ゼロダウンタイムマイグレーション

#### Phase 1: 追加のみ（Additive Changes）
```sql
-- 新しいカラムを追加（NULL許可またはデフォルト値付き）
ALTER TABLE users ADD COLUMN email_verified BOOLEAN DEFAULT false;

-- 新しいテーブルを追加
CREATE TABLE user_preferences (...);

-- 新しいインデックスを追加（CONCURRENTLY）
CREATE INDEX CONCURRENTLY idx_users_email_verified ON users(email_verified);
```

#### Phase 2: デュアルライト（Dual Write）
```go
// アプリケーションコードで新旧両方に書き込み
func UpdateUser(user *User) error {
    // 旧カラムに書き込み
    user.IsVerified = user.EmailVerified
    
    // 新カラムにも書き込み
    user.EmailVerified = user.IsVerified
    
    return db.Save(user)
}
```

#### Phase 3: 移行（Migration）
```sql
-- データ移行（バッチ処理）
UPDATE users 
SET email_verified = is_verified 
WHERE email_verified IS NULL;
```

#### Phase 4: 切り替え（Switch）
```go
// アプリケーションコードを新カラムのみ使用に更新
func UpdateUser(user *User) error {
    return db.Save(user)  // email_verifiedのみ使用
}
```

#### Phase 5: クリーンアップ（Cleanup）
```sql
-- 旧カラムを削除
ALTER TABLE users DROP COLUMN is_verified;
```

---

## 7. ロールバック戦略

### 7.1 ロールバック可能性の確保

#### 必須チェックリスト
- [ ] すべてのUPマイグレーションに対応するDOWNマイグレーションが存在
- [ ] データ削除を伴う変更は段階的に実施
- [ ] 外部キー制約の削除は慎重に計画
- [ ] インデックス削除の影響を事前評価

### 7.2 ロールバック手順

#### 手動ロールバック
```bash
# 現在のバージョン確認
make migrate-status

# 1つ前のバージョンにロールバック
make migrate-down

# 特定バージョンにロールバック
VERSION=00003 make migrate-to-version
```

#### 自動ロールバック（デプロイ失敗時）
```yaml
# Kubernetes Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: avion-auth
spec:
  revisionHistoryLimit: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
```

### 7.3 ロールバック不可能な変更の扱い

#### Point of No Return の明示
```sql
-- +goose Up
-- ⚠️ WARNING: This migration cannot be rolled back!
-- Point of No Return: データ変換を伴うため、ロールバック不可
-- 実行前に必ずバックアップを取得すること

-- +goose StatementBegin
-- 複雑なデータ変換処理
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
SELECT 'Rollback not supported for this migration';
-- +goose StatementEnd
```

---

## 8. CI/CD統合

### 8.1 GitHub Actions ワークフロー

```yaml
# .github/workflows/database-migration.yml
name: Database Migration

on:
  push:
    branches: [main, develop]
    paths:
      - '**/migrations/**'
  pull_request:
    paths:
      - '**/migrations/**'

jobs:
  validate-migration:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: [auth, user, drop, timeline, notification]
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Go
      uses: actions/setup-go@v4
      with:
        go-version: '1.21'
    
    - name: Install goose
      run: go install github.com/pressly/goose/v3/cmd/goose@latest
    
    - name: Start PostgreSQL
      run: |
        docker run -d \
          --name postgres \
          -e POSTGRES_PASSWORD=test \
          -e POSTGRES_DB=avion_${{ matrix.service }}_test \
          -p 5432:5432 \
          postgres:15-alpine
    
    - name: Wait for PostgreSQL
      run: |
        until docker exec postgres pg_isready; do
          sleep 1
        done
    
    - name: Run migrations up
      working-directory: ./avion-${{ matrix.service }}
      run: |
        export DB_URL="postgres://postgres:test@localhost:5432/avion_${{ matrix.service }}_test?sslmode=disable"
        goose -dir ./migrations postgres "$DB_URL" up
    
    - name: Test rollback
      working-directory: ./avion-${{ matrix.service }}
      run: |
        export DB_URL="postgres://postgres:test@localhost:5432/avion_${{ matrix.service }}_test?sslmode=disable"
        goose -dir ./migrations postgres "$DB_URL" down
        goose -dir ./migrations postgres "$DB_URL" up
    
    - name: Validate schema
      run: |
        docker exec postgres psql -U postgres -d avion_${{ matrix.service }}_test \
          -c "\dt" \
          -c "\di" \
          -c "\dv"

  deploy-migration:
    needs: validate-migration
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    
    steps:
    - name: Deploy to Kubernetes
      run: |
        kubectl apply -f k8s/migrations/job.yaml
        kubectl wait --for=condition=complete job/migration --timeout=300s
```

### 8.2 マイグレーション監視

```yaml
# monitoring/alerts.yaml
groups:
- name: database_migration
  rules:
  - alert: MigrationFailed
    expr: |
      kube_job_status_failed{job_name=~".*-migration-.*"} > 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Database migration failed for {{ $labels.job_name }}"
      description: "Migration job {{ $labels.job_name }} has failed. Immediate action required."
  
  - alert: MigrationTakingTooLong
    expr: |
      time() - kube_job_status_start_time{job_name=~".*-migration-.*"} > 600
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "Database migration taking too long"
      description: "Migration job {{ $labels.job_name }} has been running for more than 10 minutes."
```

---

## 9. ベストプラクティス

### 9.1 マイグレーション設計原則

#### DO's ✅
1. **小さな変更**: 1つのマイグレーションで1つの概念的変更
2. **前方互換性**: 新旧両方のアプリケーションバージョンが動作可能
3. **冪等性**: 同じマイグレーションを複数回実行しても安全
4. **トランザクション**: 可能な限りトランザクション内で実行
5. **バックアップ**: 重要な変更前は必ずバックアップ

#### DON'Ts ❌
1. **データ削除**: 即座にデータを削除せず、まずは非表示化
2. **カラム名変更**: 直接変更せず、新規追加→移行→削除の順
3. **大量データ更新**: オンラインで大量更新せず、バッチ処理
4. **制約の即時追加**: 既存データの検証後に制約を追加
5. **手動実行**: 本番環境での手動マイグレーションは禁止

### 9.2 パフォーマンス考慮事項

#### インデックス作成
```sql
-- CONCURRENTLYオプションを使用（PostgreSQL）
CREATE INDEX CONCURRENTLY idx_large_table_column ON large_table(column);

-- 進捗モニタリング
SELECT 
    pid,
    query,
    state,
    wait_event_type,
    wait_event
FROM pg_stat_activity 
WHERE query LIKE '%CREATE INDEX%';
```

#### 大規模テーブルの変更
```sql
-- バッチ更新（1000行ずつ）
DO $$
DECLARE
    batch_size INTEGER := 1000;
    offset_val INTEGER := 0;
    total_rows INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_rows FROM large_table;
    
    WHILE offset_val < total_rows LOOP
        UPDATE large_table 
        SET new_column = calculated_value
        WHERE id IN (
            SELECT id FROM large_table 
            ORDER BY id 
            LIMIT batch_size 
            OFFSET offset_val
        );
        
        offset_val := offset_val + batch_size;
        
        -- CPU負荷軽減のための待機
        PERFORM pg_sleep(0.1);
        
        RAISE NOTICE 'Processed % of % rows', offset_val, total_rows;
    END LOOP;
END $$;
```

### 9.3 テスト戦略

#### ユニットテスト
```go
// migrations_test.go
package migrations_test

import (
    "testing"
    "database/sql"
    "github.com/pressly/goose/v3"
)

func TestMigrations(t *testing.T) {
    db, err := sql.Open("postgres", testDBURL)
    if err != nil {
        t.Fatal(err)
    }
    defer db.Close()
    
    // すべてのマイグレーションをUp
    if err := goose.Up(db, "migrations"); err != nil {
        t.Fatalf("Failed to run migrations up: %v", err)
    }
    
    // スキーマ検証
    var tableCount int
    err = db.QueryRow(`
        SELECT COUNT(*) 
        FROM information_schema.tables 
        WHERE table_schema = 'public'
    `).Scan(&tableCount)
    
    if err != nil {
        t.Fatal(err)
    }
    
    if tableCount == 0 {
        t.Error("No tables created after migration")
    }
    
    // すべてのマイグレーションをDown
    if err := goose.DownTo(db, "migrations", 0); err != nil {
        t.Fatalf("Failed to run migrations down: %v", err)
    }
}
```

#### 統合テスト
```go
func TestMigrationCompatibility(t *testing.T) {
    // 旧バージョンのアプリケーションでテスト
    oldApp := startOldVersion()
    defer oldApp.Stop()
    
    // マイグレーション実行
    runMigrations()
    
    // 旧バージョンが動作することを確認
    if err := oldApp.HealthCheck(); err != nil {
        t.Errorf("Old version failed after migration: %v", err)
    }
    
    // 新バージョンのアプリケーションでテスト
    newApp := startNewVersion()
    defer newApp.Stop()
    
    // 新バージョンが動作することを確認
    if err := newApp.HealthCheck(); err != nil {
        t.Errorf("New version failed after migration: %v", err)
    }
}
```

---

## 10. トラブルシューティング

### 10.1 よくある問題と解決策

#### 問題: マイグレーションが途中で失敗
```bash
# 現状確認
goose status

# 手動で問題のあるマイグレーションを修正
psql -d $DATABASE_URL -f fix.sql

# goose_db_versionテーブルを手動更新
UPDATE goose_db_version SET is_applied = true WHERE version = 5;

# 続きから再実行
goose up
```

#### 問題: 本番環境でのロールバック必要
```bash
# 1. 現在のバージョンを確認
kubectl exec -it avion-auth-pod -- goose status

# 2. バックアップ取得
pg_dump $PROD_DB_URL > backup_$(date +%Y%m%d_%H%M%S).sql

# 3. ロールバック実行
kubectl exec -it avion-auth-pod -- goose down

# 4. アプリケーションを前のバージョンにロールバック
kubectl rollout undo deployment/avion-auth
```

#### 問題: マイグレーション順序の競合
```sql
-- 開発ブランチでの競合解決
-- 1. 競合しているマイグレーションを一時的にリネーム
mv migrations/00005_feature_a.sql migrations/00005_feature_a.sql.backup
mv migrations/00005_feature_b.sql migrations/00006_feature_b.sql

-- 2. goose fixコマンドで順序を修正
goose fix

-- 3. テスト環境で検証
goose reset
goose up
```

### 10.2 緊急時対応手順

#### 本番データベース破損時
```bash
#!/bin/bash
# emergency_recovery.sh

# 1. アプリケーショントラフィック停止
kubectl scale deployment/avion-auth --replicas=0

# 2. 最新バックアップからリストア
pg_restore -d $PROD_DB_URL < latest_backup.sql

# 3. マイグレーション状態を確認
goose status

# 4. 必要に応じて手動修正
psql -d $PROD_DB_URL -c "..."

# 5. アプリケーション再開
kubectl scale deployment/avion-auth --replicas=3

# 6. ヘルスチェック
curl https://api.avion.app/health
```

### 10.3 監視とアラート

#### Datadogダッシュボード設定
```yaml
# datadog/dashboard.yaml
widgets:
  - title: "Migration Execution Time"
    type: timeseries
    requests:
      - q: "avg:avion.migration.duration{service:$service}"
  
  - title: "Migration Success Rate"
    type: query_value
    requests:
      - q: "sum:avion.migration.success{*}.as_rate()"
  
  - title: "Database Schema Version"
    type: table
    requests:
      - q: "avg:avion.db.schema_version{*} by {service}"
```

---

## 付録A: サービス別マイグレーション要件

### avion-auth
```yaml
special_requirements:
  - セキュリティ監査ログの保持
  - パスワードハッシュアルゴリズムの移行
  - セッション無効化の考慮
  - JWTトークンのローテーション
```

### avion-user
```yaml
special_requirements:
  - プロフィール画像URLの移行
  - フォロー関係の整合性維持
  - プライバシー設定の保持
  - 大規模ユーザーデータの段階的移行
```

### avion-drop
```yaml
special_requirements:
  - コンテンツの完全性保証
  - メディア参照の整合性
  - リアクション集計の再計算
  - 削除済みコンテンツのアーカイブ
```

### avion-timeline
```yaml
special_requirements:
  - Redisキャッシュの無効化
  - タイムライン再構築ジョブ
  - ファンアウト戦略の変更対応
  - リアルタイム更新の一時停止
```

### avion-notification
```yaml
special_requirements:
  - 未読通知の保持
  - 配信ステータスの移行
  - プッシュ通知トークンの更新
  - 通知設定の細分化
```

---

## 付録B: マイグレーションチェックリスト

### 開発時チェックリスト
- [ ] UPマイグレーションを作成
- [ ] DOWNマイグレーションを作成
- [ ] ローカル環境でテスト
- [ ] ユニットテストを追加
- [ ] ドキュメントを更新
- [ ] PRレビューを依頼

### デプロイ前チェックリスト
- [ ] ステージング環境でテスト完了
- [ ] ロールバック手順を文書化
- [ ] バックアップスケジュール確認
- [ ] 影響を受けるサービスの特定
- [ ] メンテナンスウィンドウの設定（必要な場合）
- [ ] 監視アラートの設定

### デプロイ後チェックリスト
- [ ] マイグレーション成功を確認
- [ ] アプリケーションヘルスチェック
- [ ] パフォーマンス指標の確認
- [ ] エラーログの確認
- [ ] ユーザー影響の評価
- [ ] ドキュメント更新

---

## まとめ

本戦略により、Avionプロジェクトの全マイクロサービスで一貫性のあるデータベースマイグレーション管理を実現します。各サービスは独立してマイグレーションを管理しながら、共通のツール（Goose）と手順を使用することで、運用の複雑性を最小限に抑えます。

**重要なポイント:**
1. 各サービスが独自のマイグレーションを管理（分散管理）
2. Gooseを統一ツールとして採用
3. 前方互換性とロールバック可能性を常に確保
4. CI/CDパイプラインでの自動実行
5. ゼロダウンタイムデプロイを実現する段階的移行

この戦略に従うことで、安全で予測可能なデータベース変更管理を実現できます。