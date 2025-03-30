# Design Doc: avion-search

**Author:** Cline
**Last Updated:** 2025/03/30

## 1. Summary (これは何？)

- **一言で:** Avionにおける投稿（Drop）やユーザーの検索機能を提供するマイクロサービスを実装します。
- **目的:** MeiliSearchと連携した全文検索、およびオプションとしてPostgreSQLの全文検索機能を利用した検索APIを提供します。Drop/Userの変更イベントを購読し、MeiliSearchインデックスを更新します。

## 2. Background & Links (背景と関連リンク)

- ユーザーが必要な情報（Drop、ユーザー）を効率的に発見できるようにするため。
- 検索という専門的な処理を分離し、外部検索エンジン (MeiliSearch) やDB機能を利用するため。
- [PRD: avion-search](./prd.md)
- [Avion アーキテクチャ概要](../architecture.md)

## 3. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

- Drop/User作成・更新・削除イベント (Redis Stream + Consumer Group) を購読。
- イベントに基づき、MeiliSearchにドキュメントを追加・更新・削除する機能の実装 (冪等性確保)。
- MeiliSearchを利用したDrop検索API (gRPC) の実装。
- MeiliSearchを利用したユーザー検索API (gRPC) の実装。
- (オプション) PostgreSQL全文検索を利用したDrop/User検索API (gRPC) の実装。
- 検索結果に対するアクセス制御フィルタリング (呼び出し元ユーザーの権限を考慮、MeiliSearchフィルタ優先)。
- Go言語で実装し、Kubernetes上でのステートレス運用を前提とする。
- OpenTelemetryによるトレーシング・メトリクス・ロギング対応。

### Non-Goals (やらないこと)

- **検索エンジン/DB自体の運用:** MeiliSearch/PostgreSQLの運用は対象外。
- **データの永続化:** 本サービスはステートレス。インデックスはMeiliSearch、元データはPostgreSQLが保持。
- **リアルタイムインデックス (厳密な意味で):** MeiliSearchへの反映遅延は許容。完全なリアルタイム整合性は保証しない。
- **複雑な検索構文 (初期)。**
- **検索結果のパーソナライズ (初期)。**

## 4. Architecture (どうやって作る？)

- **主要コンポーネント:**
    - `avion-search (Go, Kubernetes Deployment)`: 本サービス。gRPCサーバー、Redis Stream Consumer。
    - `avion-gateway (Go)`: gRPCリクエストのルーティング元。
    - `MeiliSearch`: プライマリ全文検索エンジン。
    - `PostgreSQL`: (オプション) 全文検索機能を利用。元データ参照元。
    - `avion-post (Go)`: Dropデータ参照元 (gRPC)。
    - `avion-user (Go)`: Userデータ参照元 (gRPC)。
    - `Redis`: イベント通知 (Stream)。
    - `Observability Stack`: メトリクス、トレース、ログ収集。
- **構成図:** (アーキテクチャ概要図を参照)
    - [Avion アーキテクチャ概要](../architecture.md)
- **ポイント:**
    - イベントをRedis Streamから購読してMeiliSearchインデックスを更新。冪等性を確保。
    - gRPC APIで検索機能を提供。バックエンドとしてMeiliSearchまたはPostgreSQLを選択可能にする。
    - 検索結果のアクセス制御を行う (MeiliSearchフィルタ優先)。
    - ステートレス設計。

## 5. Use Cases / Key Flows (主な使い方・処理の流れ)

- **フロー 1: MeiliSearchインデックス更新 (Drop作成イベント)**
    1. SearchService (Consumer): Redis Stream `search_events` からConsumer Group経由でイベント取得 (`XREADGROUP`) (Payload: { event_id, type: "drop_created", data: { drop_id, user_id, text, visibility, ... } })。
    2. SearchService: `event_id` をキーに冪等性チェック (例: Redisに処理済みIDを短時間保存)。
    3. SearchService: イベント情報からMeiliSearch用ドキュメントを作成 (アクセス制御用情報も含む)。
    4. SearchService → MeiliSearch: Add/Update Documents API呼び出し。
    5. SearchService: イベントをACK (`XACK`)。エラー時はリトライ/DLQ。
- **フロー 2: Drop検索 (MeiliSearch利用)**
    1. Gateway → `SearchDrops` gRPC Call (query, backend="meilisearch", limit, offset, Metadata: X-User-ID, Trace Context)
    2. SearchService: MeiliSearchに検索クエリ発行。アクセス制御フィルタ (`filter = "visibility = public OR user_id = {X-User-ID}"` など) を付与。
    3. MeiliSearch → SearchService: 検索結果 (Dropドキュメントリスト) を取得。
    4. SearchService: (必要なら `avion-post` 等に追加情報問い合わせ) 結果を整形。
    5. SearchService → Gateway: `SearchDropsResponse { drops: [...] }`
- **フロー 3: Drop検索 (PostgreSQL FTS利用)**
    1. Gateway → `SearchDrops` gRPC Call (query, backend="postgres", ...)
    2. SearchService: PostgreSQLの `drops` テーブルに対し全文検索クエリ (`WHERE to_tsvector('japanese', text) @@ to_tsquery('japanese', {query}) AND (visibility = 'public' OR user_id = {X-User-ID})`) を実行。
    3. PostgreSQL → SearchService: 検索結果 (Dropレコードリスト) を取得。
    4. SearchService: 結果を整形。
    5. SearchService → Gateway: `SearchDropsResponse { drops: [...] }`

## 6. Endpoints (API)

- **gRPC Services (`avion.SearchService`):**
    - `SearchDrops(SearchDropsRequest) returns (SearchDropsResponse)`
    - `SearchUsers(SearchUsersRequest) returns (SearchUsersResponse)`
    - (Requestには `query`, `backend` (enum: MEILISEARCH, POSTGRES), `limit`, `offset` などを含む)
    - (Responseには検索結果のリストを含む)
- Proto定義は別途管理する。

## 7. Data Design (データ)

- 本サービスはデータを永続化しない。
- **MeiliSearch Index:**
    - `drops` index: `id`, `user_id`, `text`, `visibility`, `created_at`, ...
    - `users` index: `id`, `username`, `display_name`, `bio`, ...
    - 日本語設定を有効化。フィルタ可能な属性 (`visibility`, `user_id` など) を設定。
- **PostgreSQL:** (参照のみ)
    - `drops` テーブルの `text` カラム等に全文検索インデックス (`GIN` or `GiST`) を作成。
    - `users` テーブルの `username`, `display_name`, `bio` カラム等に全文検索インデックスを作成。
- **Redis:**
    - Event Stream: `search_events` (Consumer Group: `search_workers`)
    - Processed Event IDs (for idempotency): `processed_event:{event_id}` (Value: 1, TTL: short)

## 8. Operations & Monitoring (運用と監視)

- **主なオペレーション:**
    - MeiliSearch/PostgreSQLの接続情報管理。
    - Redis接続情報、Stream/Consumer Group設定。
    - MeiliSearchインデックス設定の管理・更新。
    - (必要に応じて) MeiliSearchインデックスの再構築。
    - DLQの監視と対応。
- **監視/アラート:**
    - **メトリクス:**
        - gRPCリクエスト数、レイテンシ、エラーレート。
        - MeiliSearch/PostgreSQLクエリ実行時間、エラーレート。
        - Redis Stream処理遅延、エラーレート、Pending数。
    - **ログ:** API処理ログ、イベント処理ログ (冪等性チェック結果含む)、MeiliSearch/PostgreSQL連携ログ、エラーログ、DLQ投入ログ。
    - **トレース:** API呼び出し、イベント処理、MeiliSearch/PostgreSQLアクセスのトレース。
    - **アラート:** gRPCエラーレート急増、高レイテンシ、MeiliSearch/PostgreSQL接続障害、Stream処理遅延大/Pending数増加、インデックス更新失敗。

## 9. Concerns / Open Questions (懸念事項・相談したいこと)

- **技術的負債リスク:**
    - **インデックス整合性:** イベント処理の信頼性向上策（Stream, 冪等性）を講じるが、完全なリアルタイム整合性は保証しない。不整合発生リスクは残り、解消のための定期的な差分同期や限定的な再インデックスの実装・運用コストが発生する可能性がある。
    - **アクセス制御の複雑性とパフォーマンス:** MeiliSearchフィルタで表現できない複雑な権限が必要になった場合、アプリ層フィルタリングによるパフォーマンス低下リスクがある。
    - **検索エンジン/DB依存:** MeiliSearchやPostgreSQL FTSのバージョンアップや仕様変更への追従コスト。
    - **イベント処理の信頼性:** イベントロストや重複処理はインデックス不整合に直結するため、冪等性確保や堅牢なエラーハンドリングが不可欠。
- MeiliSearchの具体的な設定 (トークナイザー、ランキングルール、フィルタ可能属性)。
- PostgreSQL全文検索の具体的な設定 (辞書、インデックスタイプ、`tsvector` 更新トリガーなど)。
- アクセス制御フィルタリングの具体的な実装方法とパフォーマンス影響。
- インデックス再構築の戦略と頻度。

---
