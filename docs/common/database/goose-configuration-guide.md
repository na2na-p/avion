# Goose マイグレーションツール統一設定ガイド

**Last Updated:** 2025/01/13  
**Tool Version:** Goose v3.x  
**Status:** 標準ツール

## 概要

Avionプロジェクト全体で使用するGooseマイグレーションツールの統一設定と使用方法を定義します。

## 目次

1. [Gooseとは](#1-gooseとは)
2. [インストール方法](#2-インストール方法)
3. [統一設定](#3-統一設定)
4. [コマンドリファレンス](#4-コマンドリファレンス)
5. [ベストプラクティス](#5-ベストプラクティス)
6. [トラブルシューティング](#6-トラブルシューティング)

---

## 1. Gooseとは

Gooseは、Go言語で書かれたデータベースマイグレーションツールです。以下の特徴があります：

- **シンプル**: 最小限の設定で動作
- **柔軟性**: SQLとGoコードの両方でマイグレーション記述可能
- **安全性**: トランザクション制御とロールバック機能
- **互換性**: PostgreSQL、MySQL、SQLite、SQL Serverをサポート

### なぜGooseを選んだか

1. **Go言語ネイティブ**: Avionのバックエンドと同じ言語
2. **軽量**: 依存関係が少ない
3. **CI/CD統合が容易**: バイナリ配布が簡単
4. **実績**: 多くのプロダクションで採用実績

---

## 2. インストール方法

### 2.1 開発環境

#### Go Modules経由（推奨）
```bash
# プロジェクトルートで実行
go install github.com/pressly/goose/v3/cmd/goose@v3.18.0

# バージョン確認
goose -version
```

#### Homebrew（macOS）
```bash
brew install goose
```

#### 直接ダウンロード
```bash
# Linux/macOS
curl -fsSL https://raw.githubusercontent.com/pressly/goose/master/install.sh | sh

# 特定バージョン指定
curl -fsSL https://raw.githubusercontent.com/pressly/goose/master/install.sh | sh -s v3.18.0
```

### 2.2 Docker環境

```dockerfile
# Dockerfile
FROM golang:1.21-alpine AS goose-builder
RUN go install github.com/pressly/goose/v3/cmd/goose@v3.18.0

FROM alpine:3.19
RUN apk add --no-cache postgresql-client
COPY --from=goose-builder /go/bin/goose /usr/local/bin/goose

# バージョン確認
RUN goose -version
```

### 2.3 CI/CD環境

#### GitHub Actions
```yaml
- name: Install Goose
  run: |
    go install github.com/pressly/goose/v3/cmd/goose@v3.18.0
    echo "$(go env GOPATH)/bin" >> $GITHUB_PATH
```

#### GitLab CI
```yaml
before_script:
  - go install github.com/pressly/goose/v3/cmd/goose@v3.18.0
  - export PATH=$PATH:$(go env GOPATH)/bin
```

---

## 3. 統一設定

### 3.1 設定ファイル (.goose.yml)

全サービスで以下の設定を使用：

```yaml
# .goose.yml
driver: postgres
dir: ./migrations
table: goose_db_version
verbose: false
sequential: true
```

#### 設定項目説明

| 項目 | 値 | 説明 |
|------|-----|------|
| driver | postgres | データベースドライバ |
| dir | ./migrations | マイグレーションファイルのディレクトリ |
| table | goose_db_version | バージョン管理テーブル名 |
| verbose | false | 詳細ログ出力（開発時はtrue） |
| sequential | true | 連番での実行を強制 |

### 3.2 環境変数設定

```bash
# .env
GOOSE_DRIVER=postgres
GOOSE_DBSTRING="user=avion password=secret dbname=avion_db sslmode=disable"
GOOSE_MIGRATION_DIR=./migrations
```

### 3.3 データベース接続文字列

#### PostgreSQL
```bash
# 標準形式
postgres://user:password@host:port/dbname?sslmode=disable

# キーバリュー形式
"user=avion password=secret host=localhost port=5432 dbname=avion_db sslmode=disable"

# 環境別設定
# 開発環境
postgres://avion:dev@localhost:5432/avion_dev?sslmode=disable

# ステージング環境
postgres://avion:stage@db.staging:5432/avion_stage?sslmode=require

# 本番環境
postgres://avion:prod@db.production:5432/avion_prod?sslmode=require
```

---

## 4. コマンドリファレンス

### 4.1 基本コマンド

#### status - 現在の状態確認
```bash
goose status

# 出力例
# Applied At                  Migration
# =======================================
# Mon Jan 15 14:00:00 2024    00001_init_schema.sql
# Mon Jan 15 14:01:00 2024    00002_add_user_table.sql
# Pending                      00003_add_indexes.sql
```

#### up - すべてのマイグレーション実行
```bash
goose up

# 特定バージョンまで実行
goose up-to 00003
```

#### up-by-one - 1つだけマイグレーション実行
```bash
goose up-by-one
```

#### down - 1つロールバック
```bash
goose down

# 特定バージョンまでロールバック
goose down-to 00001
```

#### redo - 再実行（down → up）
```bash
goose redo
```

#### reset - すべてロールバック
```bash
goose reset
```

#### version - 現在のバージョン表示
```bash
goose version
```

### 4.2 マイグレーション作成

#### SQLマイグレーション作成
```bash
goose create add_user_profile sql

# 生成されるファイル: 20240115120000_add_user_profile.sql
```

#### Goマイグレーション作成
```bash
goose create complex_migration go

# 生成されるファイル: 20240115120000_complex_migration.go
```

### 4.3 高度なコマンド

#### fix - シーケンス番号の修正
```bash
# タイムスタンプを連番に変換
goose fix
```

#### validate - マイグレーションファイルの検証
```bash
goose validate
```

---

## 5. ベストプラクティス

### 5.1 マイグレーションファイル作成

#### DO's ✅

```sql
-- 良い例: 明確な境界とコメント
-- +goose Up
-- +goose StatementBegin
-- =====================================================
-- Migration: Add user profile table
-- Author: John Doe
-- Date: 2024-01-15
-- Purpose: Store extended user information
-- =====================================================

CREATE TABLE user_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    bio TEXT,
    avatar_url VARCHAR(500),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_user_profiles_user_id ON user_profiles(user_id);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS user_profiles CASCADE;
-- +goose StatementEnd
```

#### DON'Ts ❌

```sql
-- 悪い例: コメントなし、ロールバックなし
-- +goose Up
CREATE TABLE profiles (id INT);

-- +goose Down
-- ロールバック未実装
```

### 5.2 トランザクション制御

#### 自動トランザクション（デフォルト）
```sql
-- +goose Up
-- 自動的にトランザクション内で実行される
CREATE TABLE users (...);
INSERT INTO users (...);
UPDATE settings SET ...;
```

#### 手動トランザクション制御
```sql
-- +goose Up
-- +goose NO TRANSACTION
-- インデックス作成など、トランザクション外で実行したい場合
CREATE INDEX CONCURRENTLY idx_large_table ON large_table(column);
```

### 5.3 条件付き実行

```sql
-- +goose Up
-- +goose StatementBegin
DO $$
BEGIN
    -- テーブルが存在しない場合のみ作成
    IF NOT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'users'
    ) THEN
        CREATE TABLE users (
            id UUID PRIMARY KEY
        );
    END IF;
END $$;
-- +goose StatementEnd
```

### 5.4 大規模データ操作

```sql
-- +goose Up
-- +goose NO TRANSACTION
-- +goose StatementBegin

-- バッチ処理で大量データを更新
DO $$
DECLARE
    batch_size INTEGER := 1000;
    updated_count INTEGER := 0;
    total_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_count FROM large_table;
    
    LOOP
        UPDATE large_table 
        SET new_column = calculated_value()
        WHERE new_column IS NULL
        LIMIT batch_size;
        
        GET DIAGNOSTICS updated_count = ROW_COUNT;
        EXIT WHEN updated_count = 0;
        
        -- 進捗ログ
        RAISE NOTICE 'Updated % rows', updated_count;
        
        -- CPU負荷軽減
        PERFORM pg_sleep(0.1);
    END LOOP;
END $$;

-- +goose StatementEnd
```

---

## 6. トラブルシューティング

### 6.1 よくあるエラーと対処法

#### エラー: "no such table: goose_db_version"
```bash
# 原因: バージョン管理テーブルが存在しない
# 解決方法:
goose up  # 自動的にテーブルが作成される
```

#### エラー: "migration files out of order"
```bash
# 原因: マイグレーションファイルの番号が順序通りでない
# 解決方法:
goose fix  # 番号を自動修正
```

#### エラー: "pq: current transaction is aborted"
```sql
-- 原因: 前のクエリでエラーが発生
-- 解決方法: StatementBegin/End を使用
-- +goose StatementBegin
CREATE TABLE ...;
-- +goose StatementEnd
```

#### エラー: "duplicate key value violates unique constraint"
```bash
# 原因: goose_db_versionテーブルに重複エントリ
# 解決方法:
psql -c "DELETE FROM goose_db_version WHERE version = 'duplicate_version';"
goose up
```

### 6.2 デバッグ方法

#### 詳細ログの有効化
```bash
# 環境変数で設定
export GOOSE_VERBOSE=true
goose up

# コマンドラインオプション
goose -v up
```

#### ドライラン（実行せずに確認）
```bash
# SQLを表示のみ（実行しない）
goose up -no-versioning
```

#### 手動でのバージョン設定
```sql
-- 緊急時の手動修正
INSERT INTO goose_db_version (version, is_applied, tstamp) 
VALUES (3, true, NOW());

-- または
UPDATE goose_db_version 
SET is_applied = true 
WHERE version = 3;
```

### 6.3 パフォーマンス問題

#### 大規模マイグレーションの最適化
```bash
# 1. maintenance_work_memを増やす
psql -c "SET maintenance_work_mem = '1GB';"

# 2. パラレル実行を有効化
psql -c "SET max_parallel_workers_per_gather = 4;"

# 3. 自動バキュームを一時的に無効化
psql -c "SET autovacuum = off;"
```

---

## 付録A: Goマイグレーション例

複雑なロジックが必要な場合はGoコードでマイグレーションを記述：

```go
// 00004_complex_data_migration.go
package migrations

import (
    "database/sql"
    "github.com/pressly/goose/v3"
)

func init() {
    goose.AddMigration(upComplexMigration, downComplexMigration)
}

func upComplexMigration(tx *sql.Tx) error {
    // 複雑なデータ変換ロジック
    rows, err := tx.Query("SELECT id, old_data FROM legacy_table")
    if err != nil {
        return err
    }
    defer rows.Close()
    
    for rows.Next() {
        var id int
        var oldData string
        if err := rows.Scan(&id, &oldData); err != nil {
            return err
        }
        
        // データ変換
        newData := transformData(oldData)
        
        _, err = tx.Exec("INSERT INTO new_table (id, data) VALUES ($1, $2)", 
            id, newData)
        if err != nil {
            return err
        }
    }
    
    return rows.Err()
}

func downComplexMigration(tx *sql.Tx) error {
    _, err := tx.Exec("DELETE FROM new_table")
    return err
}

func transformData(old string) string {
    // 変換ロジック
    return old + "_transformed"
}
```

---

## 付録B: 他ツールとの比較

| 機能 | Goose | Flyway | Liquibase | golang-migrate |
|------|-------|---------|-----------|----------------|
| 言語 | Go | Java | Java | Go |
| SQL対応 | ✅ | ✅ | ✅ | ✅ |
| コード対応 | ✅ Go | ✅ Java | ✅ Java/XML | ❌ |
| ロールバック | ✅ | ✅ | ✅ | ✅ |
| 軽量性 | ✅ | ❌ | ❌ | ✅ |
| CI/CD統合 | ✅ | ✅ | ✅ | ✅ |
| 設定の簡潔さ | ✅ | ⚠️ | ❌ | ✅ |

---

## 付録C: チートシート

```bash
# 基本操作
goose status                    # 状態確認
goose up                       # すべて実行
goose up-to VERSION           # 特定バージョンまで実行
goose down                    # 1つロールバック
goose down-to VERSION         # 特定バージョンまでロールバック
goose redo                    # 再実行
goose reset                   # すべてロールバック
goose version                 # 現在のバージョン

# マイグレーション作成
goose create NAME sql         # SQLマイグレーション
goose create NAME go          # Goマイグレーション

# メンテナンス
goose fix                     # 番号修正
goose validate               # 検証

# デバッグ
goose -v COMMAND             # 詳細ログ
goose status -env production # 環境指定
```

---

## まとめ

Gooseは、Avionプロジェクトのデータベースマイグレーション管理において、シンプルさと柔軟性を提供する理想的なツールです。本ガイドラインに従うことで、全サービスで一貫したマイグレーション管理を実現できます。