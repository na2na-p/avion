# Design Doc: avion-reaction

**Author:** Cline
**Last Updated:** 2025/03/30

## 1. Summary (これは何？)

- **一言で:** Avionにおける投稿（Drop）に対する絵文字リアクション機能を提供するマイクロサービスを実装します。
- **目的:** ユーザーによるDropへの絵文字リアクションの追加・削除、およびリアクション情報の集計・取得機能を提供します。

## 2. Background & Links (背景と関連リンク)

- Misskeyライクな表現豊かなインタラクションを実現するため。
- リアクション機能のロジックとデータを他のサービスから分離し、スケーラビリティを確保するため。
- [PRD: avion-reaction](./prd.md)
- [Avion アーキテクチャ概要](../architecture.md)

## 3. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

- Dropへの絵文字リアクション追加API (gRPC) の実装。
- リアクション削除API (gRPC) の実装。
- 特定Dropのリアクション集計取得API (gRPC) の実装 (絵文字ごとのカウント、自身がリアクションしたか)。
- リアクションデータのPostgreSQLへの永続化。
- リアクション追加/削除時にイベントを発行 (Redis Pub/Sub) し、他サービス (`avion-notification`, `avion-activitypub`) と連携する。
- リアクション集計結果のRedisキャッシュ (HashおよびSet)。
- Go言語で実装し、Kubernetes上でのステートレス運用を前提とする。
- OpenTelemetryによるトレーシング・メトリクス・ロギング対応。

### Non-Goals (やらないこと)

- **絵文字自体の管理 (カスタム絵文字含む):** 初期段階では対象外。
- **リアクションに基づく通知生成:** `avion-notification` が担当。
- **リアクションに基づくタイムラインソート:** `avion-timeline` の将来的な拡張。
- **リアクション履歴の詳細ログ永続化:** 集計結果の保持を主とする。

## 4. Architecture (どうやって作る？)

- **主要コンポーネント:**
    - `avion-reaction (Go, Kubernetes Deployment)`: 本サービス。gRPCサーバー、Redis Pub/Sub発行者。
    - `avion-gateway (Go)`: gRPCリクエストのルーティング元。
    - `PostgreSQL`: リアクションデータを永続化 (主にリカバリ用)。
    - `Redis`: リアクション集計キャッシュ (Hash)、ユーザー別リアクションキャッシュ (Set)、イベント通知 (Pub/Sub)。
    - `Observability Stack`: メトリクス、トレース、ログ収集。
    - イベント購読者 (`avion-notification`, `avion-activitypub`)。
- **構成図:** (アーキテクチャ概要図を参照)
    - [Avion アーキテクチャ概要](../architecture.md)
- **ポイント:**
    - リアクションの追加・削除と集計取得を行う。
    - 集計情報は主にRedisキャッシュから提供し、DBは永続化とキャッシュミス時のリカバリに利用。
    - 状態変更時にイベントを発行。
    - ステートレス設計。

## 5. Use Cases / Key Flows (主な使い方・処理の流れ)

- **フロー 1: リアクション追加**
    1. Gateway → `AddReaction` gRPC Call (drop_id, emoji_code, Metadata: X-User-ID, Trace Context)
    2. ReactionService: リクエスト検証。
    3. ReactionService: DBにリアクション情報 (drop_id, user_id, emoji_code) をINSERT (重複は無視 or エラー)。
    4. ReactionService: Redisの集計キャッシュ (`reaction_counts:{drop_id}`) を更新 (`HINCRBY emoji_code 1`)。TTLを再設定 (例: 24h)。
    5. ReactionService: Redisのユーザー別キャッシュ (`user_reactions:{drop_id}:{user_id}`) を更新 (`SADD emoji_code`)。TTLを再設定 (例: 24h)。
    6. ReactionService: Redis Pub/Subチャネル `reaction_created` にイベント発行 (Payload: { drop_id, user_id, emoji_code, target_user_id })。
    7. ReactionService → Gateway: `AddReactionResponse {}`
- **フロー 2: リアクション削除**
    1. Gateway → `RemoveReaction` gRPC Call (drop_id, emoji_code, Metadata: X-User-ID, Trace Context)
    2. ReactionService: DBからリアクション情報 (drop_id, user_id, emoji_code) をDELETE。
    3. ReactionService: Redisの集計キャッシュ (`reaction_counts:{drop_id}`) を更新 (`HINCRBY emoji_code -1`)。結果が0以下なら `HDEL emoji_code`。TTLを再設定。
    4. ReactionService: Redisのユーザー別キャッシュ (`user_reactions:{drop_id}:{user_id}`) を更新 (`SREM emoji_code`)。TTLを再設定。
    5. ReactionService: Redis Pub/Subチャネル `reaction_deleted` にイベント発行 (Payload: { drop_id, user_id, emoji_code })。
    6. ReactionService → Gateway: `RemoveReactionResponse {}`
- **フロー 3: リアクション集計取得 (キャッシュヒット)**
    1. Gateway → `GetReactions` gRPC Call (drop_id, Metadata: X-User-ID, Trace Context)
    2. ReactionService: Redisで `reaction_counts:{drop_id}` (Hash) を検索 (`HGETALL`)。
    3. ReactionService: Redisで `user_reactions:{drop_id}:{user_id}` (Set) を検索 (`SMEMBERS`)。
    4. ReactionService: キャッシュデータからレスポンスを生成。
    5. ReactionService → Gateway: `GetReactionsResponse { reactions: [...], user_reacted_emojis: [...] }`
- **フロー 4: リアクション集計取得 (キャッシュミス)**
    1. Gateway → `GetReactions` gRPC Call (drop_id, ...)
    2. ReactionService: Redisキャッシュ検索 (ミス)。
    3. ReactionService: DBから `drop_id` でリアクションをGROUP BY emoji_codeしてカウント集計。
    4. ReactionService: DBから `drop_id` と `user_id` で自身がリアクションした絵文字リストを取得。
    5. ReactionService: 取得結果をRedisキャッシュ (`reaction_counts:{drop_id}` に `HMSET`、`user_reactions:{drop_id}:{user_id}` に `SADD` (複数)) に保存。TTLを設定 (例: 24h)。
    6. ReactionService: レスポンスを生成。
    7. ReactionService → Gateway: `GetReactionsResponse { ... }`

## 6. Endpoints (API)

- **gRPC Services (`avion.ReactionService`):**
    - `AddReaction(AddReactionRequest) returns (AddReactionResponse)`
    - `RemoveReaction(RemoveReactionRequest) returns (RemoveReactionResponse)`
    - `GetReactions(GetReactionsRequest) returns (GetReactionsResponse)`
    - (Requestには `drop_id`, `emoji_code` などを含む)
    - (Responseには絵文字ごとのカウント、自身がリアクションした絵文字リストなどを含む)
- Proto定義は別途管理する。

## 7. Data Design (データ)

- **PostgreSQL:**
    - `reactions` table:
        - `drop_id (BIGINT, PK, FK to drops.id)`
        - `user_id (BIGINT, PK, FK to users.id)`
        - `emoji_code (VARCHAR, PK)`: Unicode文字 or カスタム絵文字コード
        - `created_at (TIMESTAMP)`
        - Index: `(user_id, drop_id)` // ユーザーがDropにリアクションしたか確認用
- **Redis:**
    - **集計キャッシュ (Hash):**
        - `reaction_counts:{drop_id}` (Field: emoji_code, Value: count)
        - TTL: 24時間 (補助的)
    - **ユーザー別リアクションキャッシュ (Set):**
        - `user_reactions:{drop_id}:{user_id}` (Member: emoji_code)
        - TTL: 24時間 (補助的)
    - **Pub/Sub Channels:** `reaction_created`, `reaction_deleted` (発行)

## 8. Operations & Monitoring (運用と監視)

- **主なオペレーション:**
    - DBマイグレーション。
    - Redis接続情報、Pub/Sub設定。
    - (必要に応じて) キャッシュの手動クリア。
- **監視/アラート:**
    - **メトリクス:**
        - gRPCリクエスト数、レイテンシ、エラーレート。
        - Redisキャッシュヒット率、コマンド実行時間、メモリ使用量。
        - DB接続エラー、クエリ実行時間 (特に集計クエリ)。
        - Pub/Sub発行エラー/遅延。
    - **ログ:** API処理ログ、エラーログ。
    - **トレース:** API呼び出し、DBアクセス、キャッシュアクセス、イベント発行のトレース。
    - **アラート:** gRPCエラーレート急増、高レイテンシ、DB/Redis接続障害、Pub/Sub発行失敗、高負荷時のDB集計クエリ遅延。

## 9. Concerns / Open Questions (懸念事項・相談したいこと)

- **技術的負債リスク:**
    - **集計パフォーマンス:** リアクション数が非常に多いDropに対するRedisキャッシュ更新(HINCRBY)や、キャッシュミス時のDB集計クエリが高負荷時にボトルネックとなる可能性がある。よりスケーラブルな集計方法（近似カウンタ等）への移行検討が将来的に必要になる可能性がある。
    - **キャッシュ整合性:** イベント駆動更新とTTLの組み合わせでは、DBとの完全な整合性は保証されない（結果整合性）。整合性が重要なケースがあれば、より複雑なキャッシュ無効化戦略が必要になる。
    - **データモデル:** 現在の `reactions` テーブルは集計クエリのパフォーマンスに限界がある。将来的に集計パフォーマンスが問題となった場合、データモデル変更が必要となり、大きな変更コストが発生する可能性がある。
- カスタム絵文字を将来的にどう扱うか。`emoji_code` の設計。
- ActivityPub連携 (`Like(Note)`) で絵文字情報をどう表現するか（拡張フィールド？）。
- キャッシュTTLの適切な値。

---
