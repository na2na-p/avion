# Design Doc: avion-bff-web

**Author:** Cline
**Last Updated:** 2025/03/30

## 1. Summary (これは何？)

- **一言で:** AvionのWebフロントエンド (`avion-web`) 専用のBackend for Frontend (BFF) サービスを実装します。
- **目的:** `avion-web` が必要とするGraphQL APIを提供し、バックエンドのマイクロサービス群 (`avion-gateway` 経由のgRPC) との通信を仲介・最適化します。SSEストリームもプロキシします。

## 2. Background & Links (背景と関連リンク)

- フロントエンド開発を効率化し、バックエンドサービスとの結合度を下げるため。
- `avion-web` の表示要件に特化したAPIを提供するため。
- [PRD: avion-bff-web](./prd.md)
- [Avion アーキテクチャ概要](../architecture.md)
- [PRD: avion-web](../avion-web/prd.md)

## 3. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

- `avion-web` 向けのGraphQL APIスキーマ定義と実装 (Go言語、`graphql-go` ライブラリ等利用)。
    - タイムライン表示用クエリ (Drop, User, Reaction情報を結合)。
    - プロフィール表示用クエリ。
    - Drop作成/リアクション追加などのミューテーション。
    - Web Pushサブスクリプション用ミューテーション。
    - Bot管理用クエリ/ミューテーション。
- バックエンドサービス連携: `avion-gateway` を介して、各マイクロサービスへgRPCでリクエスト。DataLoaderパターンを適用しN+1問題を回避。
- データ集約と変換: 複数のgRPCレスポンスを組み合わせ、GraphQLスキーマに合わせた形式に加工。
- 認証情報の伝播: `avion-web` から受け取った認証情報 (HTTPヘッダーのJWTなど) をgRPCメタデータに付与して `avion-gateway` に渡す。
- SSEプロキシ: バックエンド (`avion-timeline`, `avion-notification`) のSSEエンドポイントへの接続を仲介し、`avion-web` へ単一のSSEエンドポイントを提供する。
- Go言語で実装し、Kubernetes上でのステートレス運用を前提とする。
- OpenTelemetryによるトレーシング・メトリクス・ロギング対応。
- GraphQLスキーマとバックエンドProto定義の整合性をCI等でチェックする仕組みを導入。

### Non-Goals (やらないこと)

- **コアビジネスロジックの実装。**
- **データの永続化 (キャッシュ除く)。**
- **認証・認可チェック:** Gateway/Authz/Userが担当。
- **汎用APIの提供。**
- **複雑なBFF層キャッシュ (初期):** まずはDataLoaderによる最適化を優先。

## 4. Architecture (どうやって作る？)

- **主要コンポーネント:**
    - `avion-bff-web (Go, Kubernetes Deployment)`: 本サービス。GraphQLサーバー、SSEプロキシ。
    - `avion-web (React, TS)`: GraphQLクライアント、SSEクライアント。
    - `avion-gateway (Go)`: gRPCリクエストのルーティング先。
    - 各バックエンドサービス: Gateway経由でのデータ提供元。
    - `Redis`: (オプション) 短期キャッシュ。
    - `Observability Stack`: メトリクス、トレース、ログ収集。
- **構成図:** (アーキテクチャ概要図を参照)
    - [Avion アーキテクチャ概要](../architecture.md)
- **ポイント:**
    - `avion-web` とのインターフェースはGraphQL。SSEもBFF経由で提供。
    - バックエンドサービスとは `avion-gateway` 経由でgRPC通信。DataLoaderで効率化。
    - データ集約とフロントエンド向け形式への変換を行う。
    - ステートレス設計。

## 5. Use Cases / Key Flows (主な使い方・処理の流れ)

- **フロー 1: ホームタイムライン表示 (GraphQL Query)**
    1. WebClient → BFF: GraphQL Query (`getHomeTimeline { drops { id text author { id name } reactions { emoji count } } }`, HTTP Header: Authorization=Bearer {JWT})
    2. BFF: クエリ解析。認証情報をgRPCメタデータに設定。DataLoader初期化。
    3. BFF (Resolver): Gateway経由で `GetHomeTimeline` gRPC Call。
    4. (レスポンス受信) BFF (Resolver): `drop_ids` を取得。
    5. BFF (Resolver): DataLoaderに `drop_ids`, `author_ids`, `drop_ids` (for reactions) を登録。
    6. BFF (DataLoader): Gateway経由でバックエンドにバッチリクエスト (例: `GetDrops`, `GetUsers`, `GetReactionsBatch`)。
    7. (レスポンス受信) BFF (DataLoader): 結果をキャッシュ。
    8. BFF (Resolver): DataLoaderから取得した情報をマージし、GraphQLレスポンス構築。
    9. BFF → WebClient: GraphQL Response (JSON)
- **フロー 2: Drop作成 (GraphQL Mutation)**
    1. WebClient → BFF: GraphQL Mutation (`createDrop(input: { text: "...", visibility: "public" }) { id }`, HTTP Header: Auth)
    2. BFF: ミューテーション解析。認証情報をgRPCメタデータに設定。
    3. BFF → Gateway: `CreateDrop` gRPC Call (text, visibility, Metadata: Auth, Trace)
    4. Gateway → PostService: (認証・認可後) `CreateDrop` gRPC Call
    5. PostService → Gateway: `CreateDropResponse { drop_id: "..." }`
    6. Gateway → BFF: `CreateDropResponse { drop_id: "..." }`
    7. BFF → WebClient: GraphQL Response (`{ "data": { "createDrop": { "id": "..." } } }`)
- **フロー 3: SSE接続 (BFFプロキシ)**
    1. WebClient → BFF: SSE接続リクエスト (`/events`, Authヘッダー)
    2. BFF: 認証情報検証 (Gateway経由 or User連携)。ユーザーID取得。
    3. BFF: 内部でバックエンド (`avion-timeline`, `avion-notification`) のSSEエンドポイントに接続。
    4. BFF: クライアント接続を管理。
    5. (バックエンドSSEからイベント受信) BFF: イベントを加工・フィルタリングし、対応するWebClient接続へ転送。

## 6. Endpoints (API)

- **GraphQL Endpoint:**
    - `/graphql`: GraphQLクエリ/ミューテーションを受け付ける単一エンドポイント。
- **SSE Endpoint:**
    - `/events`: バックエンドからのSSEストリームをプロキシするエンドポイント。
- GraphQLスキーマ定義 (SDL) は別途管理する。

## 7. Data Design (データ)

- BFF自体は原則データを永続化しない。
- (オプション) **Redis Cache:**
    - 短期間のデータキャッシュに利用検討。DataLoaderのキャッシュ機構を優先。
    - Key例: `bff_cache:user:{user_id}`
    - TTL: 短め (数秒〜1分程度)

## 8. Operations & Monitoring (運用と監視)

- **主なオペレーション:**
    - デプロイ、スケーリング。
    - (キャッシュ利用時) Redis接続情報管理。
    - GraphQLスキーマ管理。
- **監視/アラート:**
    - **メトリクス:**
        - GraphQLリクエスト数、レイテンシ、エラーレート (Query/Mutation別)。
        - gRPCクライアントリクエスト数、レイテンシ、エラーレート (宛先サービス別)。
        - SSE接続数。
        - (キャッシュ利用時) Redisキャッシュヒット率、コマンド実行時間。
    - **ログ:** API処理ログ、バックエンド連携ログ、エラーログ、SSEプロキシログ。
    - **トレース:** GraphQLリクエストからバックエンドgRPC呼び出しまでの全体のトレース。
    - **アラート:** GraphQLエラーレート急増、高レイテンシ、Gateway/バックエンドサービス接続エラー、SSE接続エラー、(キャッシュ利用時) Redis接続障害。

## 9. Concerns / Open Questions (懸念事項・相談したいこと)

- **技術的負債リスク:**
    - **BFFの肥大化・複雑化:** 機能追加に伴うロジック複雑化リスク。適切なモジュール分割と設計が重要。
    - **N+1問題:** DataLoader導入は必須だが、実装の複雑性やキャッシュ戦略が課題。
    - **スキーマ同期と契約:** GraphQLスキーマとProto定義の乖離リスク。CI等でのチェック体制が必要。
    - **密結合リスク:** BFFが `avion-web` に強く依存するため、UI変更がBFF変更を誘発しやすい。
- **実装言語:** Goを採用。
- **GraphQLライブラリ選定 (Go):** `graphql-go`, `gqlgen` など。
- **DataLoader実装:** ライブラリ利用 or 自前実装。
- SSEプロキシの実装詳細とスケーラビリティ。
- BFF層でのキャッシュ戦略の詳細と無効化。
- エラーハンドリング: gRPCエラーのGraphQLエラーへのマッピング詳細。

---
