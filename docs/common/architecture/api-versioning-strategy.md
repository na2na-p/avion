# API バージョニング戦略

**Last Updated:** 2026/03/15
**Author:** Claude Code
**Status:** 採用済み
**Compliance:** Production Ready

## 概要

本ドキュメントは、Avion プラットフォームにおける API バージョニングの統一方針を定義します。gRPC/ConnectRPC（サービス間通信）、GraphQL（クライアント向け API）、REST API（Bot/外部連携向け）の 3 つの通信プロトコルそれぞれにおけるバージョン管理ルール、Breaking Change の検出・管理プロセス、移行期間のポリシーを規定します。

### 基本原則

1. **後方互換性の最大化**: API の変更は可能な限り後方互換を維持する
2. **段階的移行**: Breaking Change が必要な場合は十分な移行期間を設ける
3. **明示的な非推奨通知**: 廃止予定の API は事前に明示的に通知する
4. **プロトコル横断の一貫性**: gRPC、GraphQL、REST で共通のバージョニングポリシーを適用する
5. **Consumer 優先**: API 変更は Consumer（利用側）の負担を最小化する方向で判断する

### 関連ドキュメント

- **全体アーキテクチャ**: [architecture.md](./architecture.md) - システム全体の構成と通信プロトコル
- **イベントバージョニング**: [event-schemas.md](../events/event-schemas.md) - NATS JetStream イベントスキーマのバージョニング
- **Go バックエンドフレームワーク**: [go-backend-framework.md](./go-backend-framework.md) - ConnectRPC の技術スタック
- **エラー標準**: [error-standards.md](../errors/error-standards.md) - エラーコード体系

---

## 目次

1. [gRPC/ConnectRPC バージョニング](#1-grpcconnectrpc-バージョニング)
2. [GraphQL バージョニング](#2-graphql-バージョニング)
3. [REST API バージョニング](#3-rest-api-バージョニング)
4. [バージョン管理プロセス](#4-バージョン管理プロセス)
5. [サービス間通信のバージョニング方針](#5-サービス間通信のバージョニング方針)
6. [バージョンライフサイクル](#6-バージョンライフサイクル)

---

## 1. gRPC/ConnectRPC バージョニング

### 1.1 Proto パッケージバージョニング

Avion の各サービスは Proto パッケージ名にメジャーバージョンを含めます。既存の定義に合わせ、`avion.<service>.v<N>` の形式を使用します。

```protobuf
// avion-user サービスの v1 API
syntax = "proto3";
package avion.user.v1;

option go_package = "github.com/na2na-p/avion/proto/avion/user/v1;userv1";

service UserService {
  rpc GetUser(GetUserRequest) returns (GetUserResponse);
  rpc CreateUser(CreateUserRequest) returns (CreateUserResponse);
}
```

```protobuf
// v2 への移行が必要な場合、新しいパッケージを定義
syntax = "proto3";
package avion.user.v2;

option go_package = "github.com/na2na-p/avion/proto/avion/user/v2;userv2";

service UserService {
  rpc GetUser(GetUserRequest) returns (GetUserResponse);
  rpc CreateUser(CreateUserRequest) returns (CreateUserResponse);
  // v2 で追加された新しい RPC
  rpc GetUserWithRelations(GetUserWithRelationsRequest) returns (GetUserWithRelationsResponse);
}
```

### 1.2 ディレクトリ構成

```
proto/
  avion/
    user/
      v1/
        user_service.proto
        user_messages.proto
      v2/
        user_service.proto
        user_messages.proto
    drop/
      v1/
        drop_service.proto
        drop_messages.proto
    auth/
      v1/
        auth_service.proto
```

### 1.3 後方互換性ルール

Proto の変更を以下の 3 カテゴリに分類し、対応方針を定めます。

#### 後方互換な変更（バージョン据え置き）

| 変更種別 | 例 | 注意事項 |
|:--|:--|:--|
| 新しい RPC メソッドの追加 | `rpc GetUserStats(...)` の追加 | 既存 Consumer に影響なし |
| 新しいフィールドの追加 | `string bio = 10;` の追加 | フィールド番号は連番でなくてよい |
| 新しい enum 値の追加 | `STATUS_ARCHIVED = 4;` の追加 | Consumer は未知の値をハンドリングすべき |
| 新しいメッセージ型の定義 | `message UserStats { ... }` の追加 | 既存メッセージに影響なし |
| コメントの変更 | ドキュメントの修正 | コード生成に影響なし |

#### 後方非互換な変更（メジャーバージョンインクリメント必須）

| 変更種別 | 例 | 理由 |
|:--|:--|:--|
| フィールドの削除 | `string bio = 10;` の削除 | Consumer がフィールドを参照している可能性 |
| フィールドの型変更 | `int32` から `int64` への変更 | ワイヤフォーマットが非互換 |
| フィールド番号の変更 | `string name = 1;` を `string name = 3;` に変更 | デシリアライズが破壊される |
| RPC メソッドの削除 | `rpc GetUser(...)` の削除 | Consumer のコードが壊れる |
| RPC のリクエスト/レスポンス型の変更 | `GetUserRequest` から `GetUserByIDRequest` への差し替え | シグネチャの変更 |
| enum 値の削除 | `STATUS_ACTIVE = 1;` の削除 | Consumer が値に依存している可能性 |
| パッケージ名の変更 | `avion.user.v1` から `avion.account.v1` への変更 | 全 Consumer の再生成が必要 |

#### 注意を要する変更（ケースバイケース）

| 変更種別 | 判断基準 |
|:--|:--|
| フィールド名の変更 | JSON 表現が変わるため、ConnectRPC の JSON モードでは Breaking Change になる |
| デフォルト値の変更 | proto3 ではゼロ値がデフォルトのため、通常は問題ない |
| `optional` の追加 | proto3 では `optional` の追加はワイヤ互換だが、生成コードの API が変わる |
| `oneof` へのフィールド移動 | ワイヤフォーマットは互換だが、生成コードのアクセスパターンが変わる |

### 1.4 ConnectRPC 固有の考慮事項

ConnectRPC は gRPC、gRPC-Web、Connect Protocol の 3 つのプロトコルをサポートするため、以下の追加考慮が必要です。

```go
// ConnectRPC では JSON シリアライゼーションも使用されるため、
// フィールド名の変更は gRPC よりも影響範囲が広い
//
// 例: proto のフィールド名 "user_name" は
//   - gRPC (binary): フィールド番号でシリアライズ → フィールド名変更の影響なし
//   - Connect (JSON): "user_name" キーでシリアライズ → フィールド名変更は Breaking Change
```

**ルール**: ConnectRPC を使用する Avion では、フィールド名の変更も Breaking Change として扱います。

### 1.5 Reserved フィールドの活用

削除したフィールドは `reserved` で保護し、将来の意図しない再利用を防止します。

```protobuf
message UserResponse {
  // フィールド番号 3 と名前 "legacy_role" は使用禁止
  reserved 3;
  reserved "legacy_role";

  string user_id = 1;
  string display_name = 2;
  // フィールド番号 3 は欠番
  string role = 4;
}
```

---

## 2. GraphQL バージョニング

### 2.1 スキーマ進化戦略

GraphQL は本質的にバージョンレスなプロトコルです。Avion では URL ベースのバージョニングではなく、スキーマ進化（Schema Evolution）戦略を採用します。

**原則**: 単一エンドポイント (`/graphql`) を維持し、`@deprecated` ディレクティブによる段階的な移行を行う。

### 2.2 フィールドの追加

新しいフィールドの追加は常に後方互換です。既存の Query/Mutation に影響を与えません。

```graphql
type User {
  id: ID!
  displayName: String!
  bio: String
  # 新規追加 - 既存の Consumer には影響なし
  pronouns: String
  verifiedAt: DateTime
}
```

### 2.3 フィールド非推奨ポリシー

フィールドの廃止は以下のプロセスに従います。

#### Phase 1: 非推奨の宣言

```graphql
type User {
  id: ID!
  displayName: String!

  # Phase 1: @deprecated ディレクティブで非推奨を宣言
  "ユーザーの表示名（非推奨: displayName を使用してください）"
  name: String @deprecated(reason: "displayName フィールドに移行してください。2026-09 に削除予定。")

  bio: String
}
```

#### Phase 2: 移行期間中の並行運用

```go
// gqlgen のリゾルバで新旧フィールドの両方をサポート
func (r *userResolver) Name(ctx context.Context, obj *model.User) (*string, error) {
    // 非推奨フィールドの利用をメトリクスとして記録
    deprecationMetrics.WithLabelValues("User.name").Inc()
    // displayName と同じ値を返す
    return &obj.DisplayName, nil
}
```

#### Phase 3: フィールドの削除

移行期間終了後、スキーマからフィールドを削除します。

### 2.4 非推奨タイムライン

| フェーズ | 期間 | 状態 |
|:--|:--|:--|
| 宣言 | 移行開始 | `@deprecated` ディレクティブ追加、利用状況の計測開始 |
| 移行期間 | 最低 3 か月 | 新旧フィールド並行運用、利用 Consumer への通知 |
| 警告強化 | 移行期間の残り 1 か月 | レスポンスヘッダーに `Sunset` ヘッダー追加 |
| 削除 | 移行期間終了後 | スキーマからフィールドを削除 |

### 2.5 型の変更

既存フィールドの型変更は Breaking Change です。代わりに新しいフィールドを追加します。

```graphql
type Drop {
  id: ID!
  content: String!

  # 型変更が必要な場合: 旧フィールドを非推奨にし、新フィールドを追加
  "リアクション数（非推奨: reactionSummary を使用してください）"
  reactionCount: Int! @deprecated(reason: "reactionSummary に移行してください。")
  reactionSummary: ReactionSummary!
}

type ReactionSummary {
  total: Int!
  byType: [ReactionCount!]!
}
```

### 2.6 Query/Mutation の変更

```graphql
type Query {
  # 新しい引数の追加は後方互換（デフォルト値を設定）
  users(
    limit: Int = 20
    offset: Int = 0
    # 新規追加 - デフォルト値があるため後方互換
    sortBy: UserSortField = CREATED_AT
    sortOrder: SortOrder = DESC
  ): UserConnection!

  # 既存の Query を非推奨にして新しい Query に移行
  "非推奨: userTimeline を使用してください"
  timeline(userId: ID!): [Drop!]! @deprecated(reason: "userTimeline に移行してください。")
  userTimeline(userId: ID!, filter: TimelineFilter): TimelineConnection!
}
```

---

## 3. REST API バージョニング

### 3.1 URL パスベースのバージョニング

Bot/外部連携向けの REST API は URL パスにバージョンを含めます。

```
# バージョン付きエンドポイント
GET  /api/v1/users/{user_id}
POST /api/v1/drops
GET  /api/v1/timeline/home

# v2 への移行時
GET  /api/v2/users/{user_id}
POST /api/v2/drops
```

### 3.2 バージョン選択ルール

| ルール | 説明 |
|:--|:--|
| URL パスが唯一のバージョン指定方法 | ヘッダーベースのバージョニング (`Accept: application/vnd.avion.v1+json`) は採用しない |
| バージョン番号は整数 | `v1`, `v2`, `v3` のようにメジャーバージョンのみ |
| バージョンなし URL は最新版にリダイレクト | `/api/users/{id}` は `/api/v1/users/{id}` にリダイレクト |
| 各バージョンは独立したルーティング | avion-gateway のルーティング設定でバージョンごとに管理 |

### 3.3 REST API のバージョニング基準

#### 後方互換な変更（バージョン据え置き）

- レスポンスへの新しいフィールド追加
- 新しいエンドポイントの追加
- 新しいオプショナルなクエリパラメータの追加
- エラーメッセージの文言変更（エラーコードは不変）

#### Breaking Change（新バージョン作成）

- レスポンスからのフィールド削除
- レスポンスのフィールド型変更
- 必須パラメータの追加
- URL パスの構造変更
- HTTPメソッドの変更
- ステータスコードの意味変更

### 3.4 REST レスポンスのバージョン情報

レスポンスヘッダーに API バージョン情報を含めます。

```http
HTTP/1.1 200 OK
Content-Type: application/json
X-API-Version: v1
Sunset: Sat, 01 Mar 2027 00:00:00 GMT
Deprecation: true
Link: </api/v2/users/123>; rel="successor-version"
```

---

## 4. バージョン管理プロセス

### 4.1 Breaking Change 検出

#### Proto ファイルの互換性検査

CI パイプラインで [Buf](https://buf.build/) を使用して Proto ファイルの Breaking Change を自動検出します。

```yaml
# buf.yaml
version: v2
modules:
  - path: proto
    name: buf.build/na2na-p/avion
breaking:
  use:
    - FILE        # ファイル単位での互換性チェック
lint:
  use:
    - DEFAULT
    - COMMENTS    # コメント必須
  except:
    - PACKAGE_VERSION_SUFFIX  # v1, v2 形式を許容
```

```yaml
# CI パイプラインでの実行
# .github/workflows/proto-check.yml (抜粋)
steps:
  - name: Proto Breaking Change Check
    run: buf breaking --against '.git#branch=main'
  - name: Proto Lint
    run: buf lint
```

#### GraphQL スキーマの互換性検査

GraphQL スキーマの変更は `graphql-inspector` で検出します。

```yaml
# CI パイプラインでの実行
steps:
  - name: GraphQL Schema Check
    run: |
      npx graphql-inspector diff \
        'git:origin/main:schema.graphql' \
        'schema.graphql' \
        --rule suppressRemovalOfDeprecatedField
```

### 4.2 Breaking Change 承認フロー

Breaking Change が検出された場合、以下のフローで承認を得ます。

```
1. PR で Breaking Change が CI により検出される
2. PR 説明に以下を記載:
   - 変更理由
   - 影響を受ける Consumer の一覧
   - 移行計画（タイムライン、移行ガイド）
   - ロールバック計画
3. テックリードによるレビューと承認
4. 影響を受ける Consumer チームへの事前通知
5. マージ後、移行期間の開始
```

### 4.3 移行期間ポリシー

| API 種別 | 最小移行期間 | 推奨移行期間 | 備考 |
|:--|:--|:--|:--|
| 外部公開 REST API | 6 か月 | 12 か月 | Bot/外部連携への影響が大きい |
| GraphQL フィールド | 3 か月 | 6 か月 | `@deprecated` で段階的に移行 |
| 内部 gRPC API (サービス間) | 1 か月 | 3 か月 | デプロイの制御が可能 |
| イベントスキーマ | 2 リリース | 4 リリース | [event-schemas.md](../events/event-schemas.md) 参照 |

### 4.4 通知方法

| 対象 | 通知手段 | タイミング |
|:--|:--|:--|
| 外部開発者 | API ドキュメントの更新、メール通知 | 移行期間開始時、残り 1 か月、削除時 |
| 内部チーム | PR コメント、Slack 通知 | Breaking Change 検出時 |
| API Consumer | `Sunset` ヘッダー、`Deprecation` ヘッダー | 移行期間中の全レスポンス |
| GraphQL Consumer | `@deprecated` ディレクティブ、GraphQL Introspection | スキーマ更新時 |

---

## 5. サービス間通信のバージョニング方針

### 5.1 内部 gRPC API の原則

サービス間通信（avion-gateway と各バックエンドサービス間、バックエンドサービス同士）の gRPC API は以下の原則に従います。

| 原則 | 説明 |
|:--|:--|
| **バージョン固定** | 各サービスは特定のバージョンの Proto パッケージに依存する |
| **同時デプロイ不要** | 旧バージョンと新バージョンの API を一定期間並行稼働させる |
| **Consumer 駆動** | API の変更は Consumer（呼び出し側）の要件に基づいて行う |
| **最小公開面** | 不要な RPC メソッドやフィールドを公開しない |

### 5.2 サービス間の Proto 依存管理

```
# 各サービスが依存する Proto バージョンを明示的に管理
# buf.gen.yaml (各サービスの設定)
version: v2
plugins:
  - remote: buf.build/connectrpc/go
    out: gen/proto
    opt:
      - paths=source_relative
  - remote: buf.build/protocolbuffers/go
    out: gen/proto
    opt:
      - paths=source_relative
inputs:
  # 依存する Proto パッケージを明示的に指定
  - module: buf.build/na2na-p/avion
```

### 5.3 ローリングアップデート時の互換性

Kubernetes 上でのローリングアップデート中は、新旧バージョンの Pod が同時に稼働します。以下のルールで互換性を保証します。

```
デプロイ順序:
1. Proto 定義の更新（後方互換な変更のみ）
2. Consumer（呼び出し側）のデプロイ
   - 新しいフィールドを読み取れるようにする
3. Producer（提供側）のデプロイ
   - 新しいフィールドの送信を開始する

Breaking Change が必要な場合:
1. 新バージョン (v2) の Proto 定義を追加
2. Producer が v1 と v2 の両方を同時に提供
3. Consumer を v2 に移行
4. v1 の削除
```

### 5.4 ConnectRPC インターセプターによるバージョン追跡

```go
// バージョン情報をメタデータとして伝播するインターセプター
func VersionInterceptor() connect.UnaryInterceptorFunc {
    return func(next connect.UnaryFunc) connect.UnaryFunc {
        return func(ctx context.Context, req connect.AnyRequest) (connect.AnyResponse, error) {
            // リクエストにサービスバージョン情報を付与
            req.Header().Set("X-Service-Version", serviceVersion)
            req.Header().Set("X-Proto-Version", protoVersion)

            resp, err := next(ctx, req)

            // レスポンスのバージョン情報をログに記録
            if resp != nil {
                remoteVersion := resp.Header().Get("X-Service-Version")
                slog.DebugContext(ctx, "service call completed",
                    "remote_version", remoteVersion,
                    "proto_version", protoVersion,
                )
            }

            return resp, err
        }
    }
}
```

---

## 6. バージョンライフサイクル

### 6.1 バージョンの状態遷移

```
[Active] → [Deprecated] → [Sunset] → [Removed]
```

| 状態 | 説明 | 利用可否 |
|:--|:--|:--|
| **Active** | 現行バージョン。すべての機能が利用可能 | 利用可能 |
| **Deprecated** | 非推奨。新規利用は非推奨だが動作する | 利用可能（警告あり） |
| **Sunset** | 廃止予定。移行期間の最終段階 | 利用可能（エラーログ記録） |
| **Removed** | 削除済み。リクエストはエラーを返す | 利用不可 |

### 6.2 バージョンサポートポリシー

| API 種別 | 同時サポートバージョン数 | 根拠 |
|:--|:--|:--|
| 外部公開 REST API | 最大 2 バージョン (current + previous) | 外部 Consumer の移行期間を確保 |
| GraphQL | 1 バージョン（スキーマ進化で管理） | 非推奨フィールドの並行運用で対応 |
| 内部 gRPC API | 最大 2 バージョン (current + previous) | ローリングアップデートの安全性確保 |

### 6.3 バージョン管理チェックリスト

新しいバージョンを作成する際のチェックリスト:

- [ ] Breaking Change の内容と理由をドキュメント化した
- [ ] 影響を受ける Consumer を特定した
- [ ] 移行ガイドを作成した
- [ ] 移行期間を設定した（最小移行期間以上）
- [ ] CI で Breaking Change の自動検出を設定した
- [ ] 非推奨の通知を Consumer に送信した
- [ ] 新旧バージョンの並行運用テストを実施した
- [ ] 旧バージョンの削除予定日を明記した
- [ ] メトリクスによる旧バージョン利用率の追跡を設定した

---

## 付録

### A. Breaking Change 判定フローチャート

```
API を変更したい
  │
  ├─ フィールド/エンドポイントの追加？
  │   └─ YES → 後方互換。バージョン据え置き。
  │
  ├─ フィールドの削除/型変更？
  │   └─ YES → Breaking Change。新バージョン作成。
  │
  ├─ 必須パラメータの追加？
  │   └─ YES → Breaking Change。新バージョン作成。
  │          （代替: デフォルト値付きのオプショナルパラメータとして追加）
  │
  ├─ フィールド名の変更？（ConnectRPC/REST の場合）
  │   └─ YES → Breaking Change。新フィールド追加 + 旧フィールド非推奨。
  │
  ├─ レスポンス構造の変更？
  │   └─ YES → Breaking Change。新バージョン作成。
  │
  └─ その他
      └─ テックリードに相談。
```

### B. Proto スタイルガイド（Avion 固有）

```protobuf
// 1. パッケージ名: avion.<service>.v<N>
package avion.drop.v1;

// 2. サービス名: <Domain>Service
service DropService { ... }

// 3. メソッド名: 動詞 + 名詞
rpc CreateDrop(CreateDropRequest) returns (CreateDropResponse);
rpc GetDrop(GetDropRequest) returns (GetDropResponse);
rpc ListDrops(ListDropsRequest) returns (ListDropsResponse);
rpc UpdateDrop(UpdateDropRequest) returns (UpdateDropResponse);
rpc DeleteDrop(DeleteDropRequest) returns (google.protobuf.Empty);

// 4. メッセージ名: <Method>Request / <Method>Response
message CreateDropRequest {
  string content = 1;
  repeated string media_ids = 2;
  optional string reply_to_id = 3;
}

// 5. フィールド番号: 削除したフィールドは reserved で保護
message DropResponse {
  reserved 5;
  reserved "legacy_visibility";

  string drop_id = 1;
  string content = 2;
  string author_id = 3;
  google.protobuf.Timestamp created_at = 4;
  // フィールド番号 5 は欠番
  DropVisibility visibility = 6;
}
```
