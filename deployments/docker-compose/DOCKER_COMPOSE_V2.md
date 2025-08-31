# Docker Compose V2 環境セットアップ

## 概要

このDocker Compose設定は、Docker Compose V2を使用してAvionプラットフォームの完全な開発環境を提供します。

## 前提条件

- Docker Desktop（Docker Compose V2含む）またはDocker EngineとDocker Compose V2プラグイン
- Dockerに最低8GBのRAMを割り当て
- 20GB以上の空きディスク容量

## クイックスタート

### 1. 環境変数の設定

```bash
# サンプル環境ファイルをコピー
cp .env.example .env

# .envファイルを編集して設定をカスタマイズ（オプション）
# デフォルト値は開発に適しています
```

### 2. 全サービスの起動

```bash
# インフラストラクチャと開発サービスをすべて起動
./start-dev.sh

# またはDocker Compose V2で手動実行
docker compose up -d  # 全サービスを起動（compose.override.ymlは自動的に読み込まれます）
```

### 3. サービスの確認

```bash
# サービスステータスの確認
docker compose ps

# 特定サービスのログを表示
docker compose logs -f <service-name>

# 例：authサービスのログを表示
docker compose logs -f avion-auth
```

### 4. サービスへのアクセス

| サービス | URL | 認証情報（デフォルト） |
|---------|-----|----------------------|
| PostgreSQL | `localhost:5432` | ユーザー: avion, パスワード: avion_dev |
| Redis | `localhost:6379` | パスワードなし |
| MeiliSearch | `http://localhost:7700` | マスターキー: development_master_key_must_be_at_least_16_bytes |
| MinIO コンソール | `http://localhost:9001` | ユーザー: minioadmin, パスワード: minioadmin |
| Jaeger UI | `http://localhost:16686` | - |
| Prometheus | `http://localhost:9090` | - |
| Grafana | `http://localhost:3001` | ユーザー: admin, パスワード: admin |
| Gateway (GraphQL) | `http://localhost:8080` | - |
| Webアプリケーション | `http://localhost:3000` | - |
| Redis Commander | `http://localhost:8181` | ユーザー: admin, パスワード: admin |

### 5. 各サービスのポート一覧

| サービス | HTTPポート | gRPCポート |
|---------|-----------|-----------|
| avion-gateway | 8080 | 9090 |
| avion-auth | 8081 | 9091 |
| avion-user | 8082 | 9092 |
| avion-drop | 8083 | 9093 |
| avion-timeline | 8084 | 9094 |
| avion-activitypub | 8085 | 9095 |
| avion-notification | 8086 | 9096 |
| avion-media | 8087 | 9097 |
| avion-search | 8088 | 9098 |
| avion-system-admin | 8089 | 9099 |
| avion-moderation | 8090 | 9100 |
| avion-community | 8091 | 9101 |
| avion-message | 8092 | 9102 |

## Docker Compose V2 コマンド

すべてのコマンドは新しい`docker compose`構文を使用します（ハイフンではなくスペース）：

```bash
# サービスの起動
docker compose up -d

# サービスの停止
docker compose down

# ボリュームも含めて停止・削除（警告：データが削除されます）
docker compose down -v

# ログの表示
docker compose logs -f [service-name]

# コンテナ内でコマンドを実行
docker compose exec [service-name] [command]

# サービスの再ビルド
docker compose build [service-name]

# サービスのスケーリング
docker compose up -d --scale [service-name]=3
```

## 開発ワークフロー

### ホットリロード

すべてのGoサービスはホットリロードにAirを使用しています。ソースコードを変更すると、サービスは自動的に再ビルドされ、再起動されます。

### 新しいサービスの追加

1. サービスディレクトリに`Dockerfile.dev`を作成
2. `compose.override.yml`にサービス設定を追加
3. `.env.example`に新しい環境変数を追加
4. 環境を再起動

### データベースマイグレーション

```bash
# サービスのマイグレーションを実行
docker compose exec avion-auth migrate -path=/app/migrations -database="postgresql://..." up

# 新しいマイグレーションを作成
docker compose exec avion-auth migrate create -ext sql -dir /app/migrations -seq [migration_name]
```

### テスト

```bash
# サービスのテストを実行
docker compose exec avion-auth go test ./...

# カバレッジ付きで実行
docker compose exec avion-auth go test -cover ./...
```

## トラブルシューティング

### サービスが起動しない

1. Dockerが実行中か確認: `docker info`
2. Docker Compose V2を確認: `docker compose version`
3. ログを確認: `docker compose logs [service-name]`
4. ポートが使用中でないか確認: `lsof -i :[port]`

### データベース接続の問題

1. PostgreSQLが準備完了するまで待つ
2. `.env`ファイルの認証情報を確認
3. ネットワーク接続を確認: `docker compose exec [service] ping postgres`

### ホットリロードが動作しない

1. ボリュームマウントが正しいか確認
2. `.air.toml`のAir設定を確認
3. ファイルパーミッションを確認

### メモリの問題

Docker Desktop設定でDockerのメモリ割り当てを増やす（最低4GB推奨）。

## クリーンアップ

```bash
# すべてのサービスを停止
./stop-dev.sh

# ボリュームも含めて停止・削除（警告：すべてのデータが削除されます）
./stop-dev.sh --volumes

# イメージも削除（再ビルドが必要）
./stop-dev.sh --images

# 完全なクリーンアップ
docker compose down -v --rmi all
```

## 注意事項

- この設定は開発専用です。本番環境では使用しないでください。
- `.env.example`のすべてのパスワードとキーは開発用のデフォルト値です。
- サービスは依存関係が準備できていない場合、高速失敗するように設定されています。
- Docker Compose V2が必要です（Docker Desktopに含まれています）。
- 全サービスがCLAUDE.mdに記載されているAvionプラットフォームの仕様に準拠しています。
