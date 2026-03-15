# GraphQL スキーマ設計ガイドライン

**Last Updated:** 2026/03/15
**Author:** Claude Code
**Status:** 採用済み
**Compliance:** Production Ready

## 概要

本ドキュメントは、Avion プラットフォームにおける GraphQL スキーマの設計・運用ガイドラインを定義します。avion-gateway が gqlgen を用いて GraphQL エンドポイントを提供し、バックエンドの gRPC サービス群を集約するアーキテクチャにおいて、スキーマの構造化、命名規則、型設計、エラーハンドリング、パフォーマンス最適化の統一方針を規定します。

### 基本原則

1. **スキーマファースト**: gqlgen のスキーマファーストアプローチに従い、`.graphql` ファイルでスキーマを定義してからコードを生成する
2. **Relay 準拠**: ページネーションは Relay Connection 仕様に準拠する
3. **単一エンドポイント**: `/graphql` エンドポイントを唯一の GraphQL エントリーポイントとする
4. **スキーマ進化**: URL ベースのバージョニングではなく、`@deprecated` ディレクティブによるスキーマ進化戦略を採用する（[api-versioning-strategy.md](./api-versioning-strategy.md) 参照）
5. **ドメイン駆動**: スキーマはバックエンドの DDD モデルに整合させるが、クライアントの利便性を優先する

### 関連ドキュメント

- **API バージョニング戦略**: [api-versioning-strategy.md](./api-versioning-strategy.md) - GraphQL スキーマ進化戦略
- **Go バックエンドフレームワーク**: [go-backend-framework.md](./go-backend-framework.md) - gqlgen の技術スタック
- **全体アーキテクチャ**: [architecture.md](./architecture.md) - システム全体の構成と通信プロトコル
- **エラー標準**: [../errors/error-standards.md](../errors/error-standards.md) - エラーコード体系
- **DDD パターン**: [ddd-patterns.md](./ddd-patterns.md) - Aggregate 設計と Value Object

---

## 目次

1. [スキーマ構造](#1-スキーマ構造)
2. [命名規則](#2-命名規則)
3. [型設計](#3-型設計)
4. [エラーハンドリング](#4-エラーハンドリング)
5. [N+1 問題対策](#5-n1-問題対策)
6. [セキュリティ](#6-セキュリティ)
7. [パフォーマンス](#7-パフォーマンス)
8. [gqlgen 固有の実装ガイドライン](#8-gqlgen-固有の実装ガイドライン)

---

## 1. スキーマ構造

### 1.1 ファイル分割戦略

GraphQL スキーマはドメイン単位でファイルを分割します。gqlgen は複数の `.graphql` ファイルを自動的にマージするため、ドメインの凝集度を維持しつつスキーマの見通しを良くします。

```
services/avion-gateway/
  graph/
    schema/
      schema.graphql          # ルート型（Query, Mutation, Subscription）のエントリーポイント
      scalars.graphql          # カスタムスカラー型
      directives.graphql       # カスタムディレクティブ
      interfaces.graphql       # 共通インターフェース（Node 等）
      pagination.graphql       # ページネーション共通型（Connection, Edge, PageInfo）
      user.graphql             # ユーザー関連の型・Query・Mutation
      drop.graphql             # Drop 関連の型・Query・Mutation
      timeline.graphql         # タイムライン関連の型・Query
      notification.graphql     # 通知関連の型・Query・Mutation・Subscription
      search.graphql           # 検索関連の型・Query
      community.graphql        # コミュニティ関連の型・Query・Mutation
      auth.graphql             # 認証関連の Mutation
      media.graphql            # メディア関連の型・Mutation
      message.graphql          # メッセージ関連の型・Query・Mutation・Subscription
      moderation.graphql       # モデレーション関連の型・Mutation
    generated/
      generated.go             # gqlgen 自動生成コード
    model/
      models_gen.go            # gqlgen 自動生成モデル
      models.go                # カスタムモデル定義
    resolver/
      resolver.go              # ルートリゾルバ
      user.resolvers.go        # ユーザーリゾルバ
      drop.resolvers.go        # Drop リゾルバ
      timeline.resolvers.go    # タイムラインリゾルバ
      ...
    dataloader/
      user_loader.go           # ユーザー DataLoader
      drop_loader.go           # Drop DataLoader
      ...
```

### 1.2 ファイル分割ルール

| ルール | 説明 |
|:--|:--|
| **ドメイン単位** | 1 つのバックエンドサービスに対応するドメインごとに 1 ファイル |
| **共通型は独立** | スカラー型、ディレクティブ、ページネーション型は専用ファイルに分離 |
| **ルート型はエントリーポイント** | `schema.graphql` は `extend type Query` / `extend type Mutation` で各ドメインファイルを参照 |
| **最大行数目安** | 1 ファイルあたり 300 行を超える場合はサブドメインでの分割を検討 |

### 1.3 ルート型の定義

`schema.graphql` ではルート型の骨格のみを定義し、各ドメインファイルで `extend` により拡張します。

```graphql
# schema.graphql
type Query
type Mutation
type Subscription
```

```graphql
# user.graphql
extend type Query {
  """自分自身のユーザー情報を取得する"""
  me: User!

  """指定された ID のユーザーを取得する"""
  user(id: ID!): User

  """ユーザー一覧をページネーション付きで取得する"""
  users(first: Int!, after: Cursor): UserConnection!
}

extend type Mutation {
  """ユーザープロフィールを更新する"""
  updateProfile(input: UpdateProfileInput!): UpdateProfilePayload!
}
```

### 1.4 gqlgen 設定

```yaml
# gqlgen.yml
schema:
  - graph/schema/*.graphql

exec:
  filename: graph/generated/generated.go
  package: generated

model:
  filename: graph/model/models_gen.go
  package: model

resolver:
  layout: follow-schema
  dir: graph/resolver
  package: resolver

autobind:
  - "github.com/na2na-p/avion/services/avion-gateway/graph/model"

models:
  ID:
    model:
      - github.com/99designs/gqlgen/graphql.ID
  DateTime:
    model:
      - github.com/99designs/gqlgen/graphql.Time
  Cursor:
    model:
      - github.com/na2na-p/avion/services/avion-gateway/graph/model.Cursor
  Node:
    model:
      - github.com/na2na-p/avion/services/avion-gateway/graph/model.Node
```

---

## 2. 命名規則

### 2.1 型名

| カテゴリ | 規則 | 例 |
|:--|:--|:--|
| **オブジェクト型** | PascalCase、ドメインの名詞 | `User`, `Drop`, `Community` |
| **入力型** | `<動詞><名詞>Input` | `CreateDropInput`, `UpdateProfileInput` |
| **ペイロード型** | `<動詞><名詞>Payload` | `CreateDropPayload`, `UpdateProfilePayload` |
| **Connection 型** | `<名詞>Connection` | `UserConnection`, `DropConnection` |
| **Edge 型** | `<名詞>Edge` | `UserEdge`, `DropEdge` |
| **Enum 型** | PascalCase、名詞 | `Visibility`, `TimelineType`, `NotificationType` |
| **Enum 値** | SCREAMING_SNAKE_CASE | `PUBLIC`, `UNLISTED`, `PRIVATE`, `DIRECT` |

### 2.2 フィールド名

| 規則 | 例 | 備考 |
|:--|:--|:--|
| camelCase | `displayName`, `createdAt` | GraphQL の慣例に従う |
| Boolean は `is` / `has` プレフィックス | `isVerified`, `hasMedia` | 状態を明示する |
| リストは複数形 | `drops`, `reactions`, `mediaAttachments` | 単数形は単一オブジェクト |
| 日時は `At` サフィックス | `createdAt`, `updatedAt`, `deletedAt` | Timestamp を明示する |
| 数量は `Count` サフィックス | `followerCount`, `dropCount` | カウンター値を明示する |

### 2.3 Query 名

| パターン | 形式 | 例 | 用途 |
|:--|:--|:--|:--|
| **単一取得** | `<名詞>(id: ID!)` | `user(id: ID!)`, `drop(id: ID!)` | ID による単一リソース取得 |
| **一覧取得** | `<複数形名詞>(...)` | `users(first: Int!, after: Cursor)` | ページネーション付き一覧 |
| **自分自身** | `me` | `me: User!` | 認証済みユーザー自身の情報 |
| **タイムライン** | `<修飾>Timeline(...)` | `homeTimeline(...)`, `globalTimeline(...)` | タイムライン系 Query |
| **検索** | `search<複数形名詞>(...)` | `searchDrops(query: String!, ...)` | 検索系 Query |

### 2.4 Mutation 名

| パターン | 形式 | 例 |
|:--|:--|:--|
| **作成** | `create<名詞>` | `createDrop`, `createCommunity` |
| **更新** | `update<名詞>` | `updateProfile`, `updateDrop` |
| **削除** | `delete<名詞>` | `deleteDrop`, `deleteCommunity` |
| **状態変更** | `<動詞><名詞>` | `followUser`, `unfollowUser`, `blockUser` |
| **バッチ操作** | `<動詞><複数形名詞>` | `markNotificationsAsRead` |

### 2.5 Subscription 名

| パターン | 形式 | 例 |
|:--|:--|:--|
| **リアルタイム更新** | `<名詞><Updated/Created>` | `dropUpdated`, `notificationCreated` |
| **ストリーム** | `<名詞>Stream` | `timelineStream` |

---

## 3. 型設計

### 3.1 Node インターフェース

Relay の Global Object Identification 仕様に準拠し、すべてのリソース型は `Node` インターフェースを実装します。

```graphql
# interfaces.graphql
"""Relay Global Object Identification 準拠の Node インターフェース"""
interface Node {
  """グローバルに一意な識別子"""
  id: ID!
}
```

```graphql
# user.graphql
"""Avion プラットフォームのユーザー"""
type User implements Node {
  id: ID!
  displayName: String!
  handle: String!
  bio: String
  avatarUrl: String
  headerUrl: String
  isVerified: Boolean!
  createdAt: DateTime!

  # 関連データ（リゾルバで解決）
  followerCount: Int!
  followingCount: Int!
  dropCount: Int!
  drops(first: Int!, after: Cursor): DropConnection!
}
```

**ルール**:
- `id` フィールドはバックエンドの内部 ID をそのまま返さず、型プレフィックスを付与してグローバルに一意にする
- 例: `User:01HXYZ...` → Base64 エンコード → `VXNlcjowMUhYWVou...`

### 3.2 Connection パターン（Relay 準拠ページネーション）

すべてのリスト型は Relay Connection 仕様に準拠します。

```graphql
# pagination.graphql
"""Relay Connection 仕様に準拠したページ情報"""
type PageInfo {
  """次のページが存在するか"""
  hasNextPage: Boolean!

  """前のページが存在するか"""
  hasPreviousPage: Boolean!

  """最初のエッジのカーソル"""
  startCursor: Cursor

  """最後のエッジのカーソル"""
  endCursor: Cursor
}
```

```graphql
# drop.graphql
"""Drop の Connection 型"""
type DropConnection {
  """エッジの配列"""
  edges: [DropEdge!]!

  """ページ情報"""
  pageInfo: PageInfo!

  """全件数（オプション: パフォーマンスコストを考慮し、明示的にリクエストされた場合のみ計算）"""
  totalCount: Int
}

"""Drop の Edge 型"""
type DropEdge {
  """カーソル"""
  cursor: Cursor!

  """ノード"""
  node: Drop!
}
```

**Connection パターンの適用基準**:

| 条件 | パターン | 例 |
|:--|:--|:--|
| 件数が多い・ページネーション必須 | Connection | `drops(first: Int!, after: Cursor): DropConnection!` |
| 件数が少ない・固定長 | 配列 | `reactions: [Reaction!]!` |
| 件数が少ないが将来増加する可能性あり | Connection | 拡張性を優先 |

### 3.3 入力型の設計

Mutation の引数は単一の `Input` 型にまとめます。

```graphql
# drop.graphql
"""Drop 作成の入力"""
input CreateDropInput {
  """投稿内容（最大 500 文字）"""
  content: String!

  """公開範囲"""
  visibility: Visibility = PUBLIC

  """メディア ID の配列（最大 4 件）"""
  mediaIds: [ID!]

  """返信先 Drop の ID"""
  replyToId: ID

  """コンテンツ警告テキスト"""
  contentWarning: String

  """投票の入力"""
  poll: CreatePollInput
}

"""投票作成の入力"""
input CreatePollInput {
  """選択肢（2 件以上 4 件以下）"""
  options: [String!]!

  """投票期限（秒単位、最小 300 秒、最大 604800 秒）"""
  expiresInSeconds: Int!
}
```

**入力型設計ルール**:

| ルール | 説明 |
|:--|:--|
| **フラットよりネスト** | 論理的にグループ化できるフィールドはネストした Input 型にまとめる |
| **デフォルト値の活用** | オプショナルフィールドには適切なデフォルト値を設定する |
| **バリデーション制約の記述** | 制約事項はスキーマのドキュメントコメントに明記する |
| **ID はオペランド** | 更新・削除対象の ID は Input 型に含めず、Mutation の引数として分離する |

### 3.4 ペイロード型の設計

Mutation の戻り値はペイロード型を使用し、操作結果の詳細を返します。

```graphql
# drop.graphql
"""Drop 作成のペイロード"""
type CreateDropPayload {
  """作成された Drop"""
  drop: Drop!
}

"""Drop 削除のペイロード"""
type DeleteDropPayload {
  """削除された Drop の ID"""
  deletedDropId: ID!
}

"""フォロー操作のペイロード"""
type FollowUserPayload {
  """フォロー対象のユーザー（更新後の状態）"""
  user: User!

  """フォロー関係の状態"""
  followStatus: FollowStatus!
}
```

**ペイロード型設計ルール**:

| ルール | 説明 |
|:--|:--|
| **操作結果を含める** | 作成・更新されたリソースを返す |
| **ドメインエラーはペイロードに含めない** | エラーは GraphQL errors で返す（セクション 4 参照） |
| **関連データを返す** | クライアントのキャッシュ更新に必要なデータを含める |

### 3.5 Enum 型の設計

```graphql
# drop.graphql
"""投稿の公開範囲"""
enum Visibility {
  """全員に公開"""
  PUBLIC

  """タイムラインには表示しないが、URL で閲覧可能"""
  UNLISTED

  """フォロワーのみ"""
  PRIVATE

  """指定ユーザーのみ"""
  DIRECT
}

"""タイムラインの種類"""
enum TimelineType {
  """ホームタイムライン"""
  HOME

  """ローカルタイムライン"""
  LOCAL

  """グローバルタイムライン"""
  GLOBAL
}
```

### 3.6 Union 型の活用

検索結果のように複数の型を返す場合は Union 型を使用します。

```graphql
# search.graphql
"""検索結果"""
union SearchResult = User | Drop | Community

"""検索結果の Connection"""
type SearchResultConnection {
  edges: [SearchResultEdge!]!
  pageInfo: PageInfo!
  totalCount: Int
}

type SearchResultEdge {
  cursor: Cursor!
  node: SearchResult!
}

extend type Query {
  """統合検索"""
  search(
    query: String!
    type: SearchType
    first: Int!
    after: Cursor
  ): SearchResultConnection!
}
```

### 3.7 カスタムスカラー型

```graphql
# scalars.graphql
"""ISO 8601 形式の日時（例: 2026-03-15T10:30:00Z）"""
scalar DateTime

"""Relay ページネーションカーソル（Base64 エンコード文字列）"""
scalar Cursor

"""URL 文字列"""
scalar URL
```

---

## 4. エラーハンドリング

### 4.1 エラー変換の基本方針

avion-gateway は、バックエンド gRPC サービスから受け取った ConnectRPC エラーを GraphQL エラーに変換します。ドメインエラーは GraphQL の `errors` フィールドで返し、ペイロード内にはエラー情報を含めません。

### 4.2 エラーコードマッピング

ConnectRPC のエラーコードから GraphQL エラーの `extensions.code` へのマッピングを定義します。

| ConnectRPC Code | GraphQL extensions.code | HTTP ステータス | 説明 |
|:--|:--|:--|:--|
| `NotFound` | `NOT_FOUND` | 200 | リソースが見つからない |
| `InvalidArgument` | `BAD_USER_INPUT` | 200 | 入力値不正 |
| `PermissionDenied` | `FORBIDDEN` | 200 | 認可エラー |
| `Unauthenticated` | `UNAUTHENTICATED` | 200 | 認証エラー |
| `AlreadyExists` | `CONFLICT` | 200 | リソースが既に存在 |
| `FailedPrecondition` | `PRECONDITION_FAILED` | 200 | 事前条件違反 |
| `ResourceExhausted` | `RATE_LIMITED` | 200 | レート制限超過 |
| `Internal` | `INTERNAL_SERVER_ERROR` | 200 | 内部エラー |
| `Unavailable` | `SERVICE_UNAVAILABLE` | 200 | サービス利用不可 |

### 4.3 エラーレスポンス形式

```json
{
  "data": {
    "createDrop": null
  },
  "errors": [
    {
      "message": "投稿内容は 500 文字以内で入力してください",
      "path": ["createDrop"],
      "extensions": {
        "code": "BAD_USER_INPUT",
        "avionCode": "DROP_DOMAIN_VALIDATION_FAILED",
        "field": "content",
        "timestamp": "2026-03-15T10:30:00Z"
      }
    }
  ]
}
```

**エラーレスポンスルール**:

| ルール | 説明 |
|:--|:--|
| **`extensions.code`** | GraphQL 標準のエラーコード（クライアントのハンドリング用） |
| **`extensions.avionCode`** | Avion 固有のエラーコード（[error-standards.md](../errors/error-standards.md) 準拠） |
| **`message`** | ユーザー向けの説明メッセージ（技術的詳細は含めない） |
| **`path`** | エラーが発生した GraphQL パス |
| **`extensions.field`** | バリデーションエラーの場合、該当フィールド名 |

### 4.4 gqlgen でのエラー変換実装

```go
package resolver

import (
    "context"
    "errors"
    "log/slog"
    "time"

    "connectrpc.com/connect"
    "github.com/99designs/gqlgen/graphql"
    "github.com/vektah/gqlparser/v2/gqlerror"
)

// connectErrorToGraphQL は ConnectRPC エラーを GraphQL エラーに変換する
func connectErrorToGraphQL(ctx context.Context, err error) error {
    if err == nil {
        return nil
    }

    var connectErr *connect.Error
    if !errors.As(err, &connectErr) {
        // ConnectRPC エラー以外は内部エラーとして返す
        return internalError(ctx, err)
    }

    code := mapConnectCodeToGraphQL(connectErr.Code())

    gqlErr := &gqlerror.Error{
        Message: connectErr.Message(),
        Path:    graphql.GetPath(ctx),
        Extensions: map[string]interface{}{
            "code":      code,
            "timestamp": time.Now().UTC().Format(time.RFC3339),
        },
    }

    // Avion 固有のエラーコードがメタデータに含まれている場合
    if avionCode := connectErr.Meta().Get("avion-error-code"); avionCode != "" {
        gqlErr.Extensions["avionCode"] = avionCode
    }

    // フィールド情報がある場合
    if field := connectErr.Meta().Get("field"); field != "" {
        gqlErr.Extensions["field"] = field
    }

    return gqlErr
}

// mapConnectCodeToGraphQL は ConnectRPC コードを GraphQL エラーコードに変換する
func mapConnectCodeToGraphQL(code connect.Code) string {
    switch code {
    case connect.CodeNotFound:
        return "NOT_FOUND"
    case connect.CodeInvalidArgument:
        return "BAD_USER_INPUT"
    case connect.CodePermissionDenied:
        return "FORBIDDEN"
    case connect.CodeUnauthenticated:
        return "UNAUTHENTICATED"
    case connect.CodeAlreadyExists:
        return "CONFLICT"
    case connect.CodeFailedPrecondition:
        return "PRECONDITION_FAILED"
    case connect.CodeResourceExhausted:
        return "RATE_LIMITED"
    case connect.CodeUnavailable:
        return "SERVICE_UNAVAILABLE"
    default:
        return "INTERNAL_SERVER_ERROR"
    }
}

func internalError(ctx context.Context, err error) error {
    // 技術的詳細はログに記録し、ユーザーにはジェネリックなメッセージを返す
    slog.ErrorContext(ctx, "internal error in GraphQL resolver",
        "error", err,
    )
    return &gqlerror.Error{
        Message: "内部エラーが発生しました。時間をおいて再度お試しください。",
        Path:    graphql.GetPath(ctx),
        Extensions: map[string]interface{}{
            "code":      "INTERNAL_SERVER_ERROR",
            "timestamp": time.Now().UTC().Format(time.RFC3339),
        },
    }
}
```

---

## 5. N+1 問題対策

### 5.1 DataLoader パターンの適用方針

GraphQL リゾルバのネストされたフィールド解決における N+1 問題を DataLoader パターンで解決します。

**DataLoader を適用すべきケース**:

| ケース | 例 |
|:--|:--|
| 一覧内の関連リソース | Drop 一覧の各 `author: User!` フィールド |
| ネストされた参照 | Notification の `actor: User!` フィールド |
| 多対多の関連 | Drop の `reactions: [Reaction!]!` フィールド |

**DataLoader を適用しないケース**:

| ケース | 理由 |
|:--|:--|
| ルートレベルの単一リソース取得 | バッチの必要なし（例: `user(id: ID!)`） |
| ルートレベルの Connection | gRPC 側で一括取得可能 |
| 低頻度アクセスのフィールド | DataLoader のオーバーヘッドが不要 |

### 5.2 DataLoader 実装パターン

```go
package dataloader

import (
    "context"
    "time"

    "connectrpc.com/connect"
    userv1 "github.com/na2na-p/avion/proto/avion/user/v1"
    "github.com/na2na-p/avion/proto/avion/user/v1/userv1connect"
)

// UserLoader はユーザー情報のバッチ取得を行う DataLoader
type UserLoader struct {
    maxBatch int
    wait     time.Duration
    fetch    func(ctx context.Context, keys []string) ([]*User, []error)
}

// NewUserLoader は UserLoader を生成する
func NewUserLoader(client userv1connect.UserServiceClient) *UserLoader {
    return &UserLoader{
        maxBatch: 100,
        wait:     2 * time.Millisecond,
        fetch: func(ctx context.Context, userIDs []string) ([]*User, []error) {
            // gRPC バッチ取得 API を呼び出す
            req := connect.NewRequest(&userv1.BatchGetUsersRequest{
                UserIds: userIDs,
            })

            resp, err := client.BatchGetUsers(ctx, req)
            if err != nil {
                errors := make([]error, len(userIDs))
                for i := range errors {
                    errors[i] = err
                }
                return nil, errors
            }

            // レスポンスをリクエスト順に並べ替え
            userMap := make(map[string]*userv1.UserResponse)
            for _, u := range resp.Msg.Users {
                userMap[u.UserId] = u
            }

            users := make([]*User, len(userIDs))
            errs := make([]error, len(userIDs))
            for i, id := range userIDs {
                if u, ok := userMap[id]; ok {
                    users[i] = toGraphQLUser(u)
                } else {
                    errs[i] = fmt.Errorf("user not found: %s", id)
                }
            }

            return users, errs
        },
    }
}
```

### 5.3 DataLoader のミドルウェア登録

DataLoader はリクエストスコープで生成し、Context に注入します。

```go
package middleware

import (
    "context"
    "net/http"
)

type contextKey string

const dataLoaderKey contextKey = "dataloaders"

// Loaders はリクエストスコープの DataLoader 群
type Loaders struct {
    UserLoader *dataloader.UserLoader
    DropLoader *dataloader.DropLoader
}

// DataLoaderMiddleware は DataLoader をリクエストコンテキストに注入するミドルウェア
func DataLoaderMiddleware(loaders *Loaders) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            ctx := context.WithValue(r.Context(), dataLoaderKey, loaders)
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}

// GetLoaders はコンテキストから DataLoader 群を取得する
func GetLoaders(ctx context.Context) *Loaders {
    return ctx.Value(dataLoaderKey).(*Loaders)
}
```

### 5.4 リゾルバでの DataLoader 使用

```go
package resolver

import "context"

// Author は Drop の author フィールドを解決するリゾルバ
func (r *dropResolver) Author(ctx context.Context, obj *model.Drop) (*model.User, error) {
    loaders := middleware.GetLoaders(ctx)
    return loaders.UserLoader.Load(ctx, obj.AuthorID)
}
```

### 5.5 バックエンド gRPC サービスのバッチ API 要件

DataLoader が効果を発揮するためには、バックエンド gRPC サービスにバッチ取得 API が必要です。

```protobuf
// avion-user サービスのバッチ取得 API
service UserService {
  rpc GetUser(GetUserRequest) returns (GetUserResponse);
  // DataLoader 向けバッチ取得 API
  rpc BatchGetUsers(BatchGetUsersRequest) returns (BatchGetUsersResponse);
}

message BatchGetUsersRequest {
  repeated string user_ids = 1; // 最大 100 件
}

message BatchGetUsersResponse {
  repeated UserResponse users = 1;
}
```

---

## 6. セキュリティ

### 6.1 クエリ深度制限

ネストの深いクエリによる DoS 攻撃を防止するため、クエリの最大深度を制限します。

| 設定 | 値 | 根拠 |
|:--|:--|:--|
| **最大深度** | 10 | 通常の UI 操作で必要な最大ネスト数 + マージン |
| **Introspection クエリ** | 開発環境のみ許可 | 本番環境ではスキーマの漏洩を防止 |

```go
package security

import (
    "github.com/99designs/gqlgen/graphql/handler/extension"
)

// SetupQueryComplexity は GraphQL サーバーにクエリ制限を設定する
func SetupQueryComplexity(srv *handler.Server) {
    // クエリ深度制限
    srv.Use(extension.FixedComplexityLimit(500))
}
```

### 6.2 クエリ複雑度制限

フィールドごとに複雑度コストを割り当て、クエリ全体の複雑度を制限します。

| フィールドカテゴリ | 複雑度コスト | 例 |
|:--|:--|:--|
| **スカラーフィールド** | 0 | `displayName`, `bio` |
| **単一オブジェクト** | 1 | `author: User!` |
| **Connection（ページネーション）** | first 引数 * 子の複雑度 | `drops(first: 20): DropConnection!` → 20 * 子の合計 |
| **計算を伴うフィールド** | 5 | `followerCount`（集計クエリ） |

```graphql
# directives.graphql
"""フィールドの複雑度コストを指定するディレクティブ"""
directive @complexity(
  """固定の複雑度コスト"""
  value: Int!

  """乗数として使用する引数名（Connection の first 引数等）"""
  multiplier: String
) on FIELD_DEFINITION
```

```graphql
# user.graphql
type User implements Node {
  id: ID!
  displayName: String!
  drops(first: Int!, after: Cursor): DropConnection! @complexity(value: 1, multiplier: "first")
  followerCount: Int! @complexity(value: 5)
}
```

**複雑度制限値**:

| 環境 | 最大複雑度 | 根拠 |
|:--|:--|:--|
| 一般ユーザー | 500 | 標準的な画面描画に必要な複雑度 |
| Bot クライアント | 200 | API の濫用防止 |
| 管理者 | 1000 | 管理画面の複雑なクエリに対応 |

### 6.3 レート制限

GraphQL エンドポイントへのレート制限は avion-gateway のミドルウェアレベルで適用します。

| 対象 | 制限 | 期間 |
|:--|:--|:--|
| **認証済みユーザー** | 300 リクエスト | 1 分間 |
| **未認証リクエスト** | 30 リクエスト | 1 分間 |
| **Bot クライアント** | 100 リクエスト | 1 分間 |
| **Mutation 専用** | 60 リクエスト | 1 分間 |

### 6.4 Introspection の制御

```go
package security

import (
    "os"

    "github.com/99designs/gqlgen/graphql/handler"
    "github.com/99designs/gqlgen/graphql/handler/extension"
)

// ConfigureIntrospection は環境に応じて Introspection を制御する
func ConfigureIntrospection(srv *handler.Server) {
    env := os.Getenv("APP_ENV")
    if env == "production" {
        // 本番環境では Introspection を無効化
        srv.Use(extension.DisableIntrospection{})
    }
    // 開発・ステージング環境では Introspection を有効のまま
}
```

### 6.5 入力バリデーション

GraphQL レイヤーでの入力バリデーションは、gqlgen のディレクティブを活用して宣言的に行います。バックエンドサービスでも二重にバリデーションを行い、防御的プログラミングを実践します。

```graphql
# directives.graphql
"""文字列の長さ制約"""
directive @length(min: Int = 0, max: Int!) on INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION

"""数値の範囲制約"""
directive @range(min: Int, max: Int) on INPUT_FIELD_DEFINITION | ARGUMENT_DEFINITION
```

```graphql
# drop.graphql
input CreateDropInput {
  content: String! @length(min: 1, max: 500)
  mediaIds: [ID!] @length(max: 4)
}

input CreatePollInput {
  options: [String!]! @length(min: 2, max: 4)
  expiresInSeconds: Int! @range(min: 300, max: 604800)
}
```

---

## 7. パフォーマンス

### 7.1 キャッシュ戦略

GraphQL レスポンスのキャッシュは、クライアントサイドキャッシュ（Apollo Client）とサーバーサイドキャッシュ（Redis）の 2 層で構成します。

#### クライアントサイドキャッシュ（Apollo Client）

| 戦略 | 対象 | 説明 |
|:--|:--|:--|
| **Normalized Cache** | 全リソース | `Node` インターフェースの `id` フィールドを用いた正規化キャッシュ |
| **Cache-First** | ユーザープロフィール、Drop 詳細 | キャッシュ優先で取得し、バックグラウンドで更新 |
| **Network-Only** | タイムライン、通知 | 常にサーバーから最新データを取得 |
| **Cache-and-Network** | 検索結果 | キャッシュを即座に表示し、ネットワーク結果で更新 |

#### サーバーサイドキャッシュ

GraphQL レスポンス全体のキャッシュは行わず、gRPC 呼び出し結果をリソース単位でキャッシュします。キャッシュ戦略の詳細は [redis-cache-strategy.md](../infrastructure/redis-cache-strategy.md) を参照してください。

| キャッシュ対象 | TTL | 無効化トリガー |
|:--|:--|:--|
| ユーザープロフィール | 5 分 | `UserUpdatedEvent` |
| Drop コンテンツ | 5 分 | `DropUpdatedEvent`, `DropDeletedEvent` |
| フォロー/フォロワー数 | 1 分 | `FollowCreatedEvent`, `FollowDeletedEvent` |
| コミュニティ情報 | 10 分 | `CommunityUpdatedEvent` |

### 7.2 永続化クエリ（Persisted Queries）

クエリ文字列の転送コストを削減し、ホワイトリストによるセキュリティを向上させるため、Automatic Persisted Queries（APQ）を採用します。

```go
package server

import (
    "github.com/99designs/gqlgen/graphql/handler"
    "github.com/99designs/gqlgen/graphql/handler/extension"
    "github.com/99designs/gqlgen/graphql/handler/transport"
)

// NewGraphQLServer は GraphQL サーバーを構築する
func NewGraphQLServer(resolver *resolver.Resolver) *handler.Server {
    srv := handler.New(generated.NewExecutableSchema(generated.Config{
        Resolvers: resolver,
    }))

    // トランスポート設定
    srv.AddTransport(transport.Options{})
    srv.AddTransport(transport.GET{})
    srv.AddTransport(transport.POST{})

    // Automatic Persisted Queries
    srv.Use(extension.AutomaticPersistedQuery{
        Cache: NewRedisAPQCache(), // Redis ベースの APQ キャッシュ
    })

    return srv
}
```

**APQ のフロー**:

```
1. クライアントが SHA256 ハッシュのみでリクエスト送信
2. サーバーがキャッシュを検索
   a. キャッシュヒット → クエリを実行
   b. キャッシュミス → PersistedQueryNotFound エラーを返す
3. クライアントがクエリ文字列とハッシュを含む完全なリクエストを再送信
4. サーバーがクエリをキャッシュに保存し、実行
```

### 7.3 クエリ実行の最適化

```go
// フィールド選択に基づく gRPC リクエストの最適化
func (r *queryResolver) User(ctx context.Context, id string) (*model.User, error) {
    // リクエストされたフィールドを取得
    fields := graphql.CollectFieldsCtx(ctx, nil)

    // 必要なフィールドに応じて gRPC リクエストを最適化
    req := connect.NewRequest(&userv1.GetUserRequest{
        UserId: id,
    })

    // 関連データのプリフェッチが必要か判定
    for _, field := range fields {
        switch field.Name {
        case "drops":
            req.Header().Set("X-Prefetch-Drops", "true")
        case "followerCount", "followingCount":
            req.Header().Set("X-Prefetch-Stats", "true")
        }
    }

    resp, err := r.userClient.GetUser(ctx, req)
    if err != nil {
        return nil, connectErrorToGraphQL(ctx, err)
    }

    return toGraphQLUser(resp.Msg), nil
}
```

### 7.4 バッチリクエストの制限

複数の GraphQL オペレーションを単一の HTTP リクエストで送信するバッチリクエストには、以下の制限を適用します。

| 設定 | 値 | 根拠 |
|:--|:--|:--|
| **最大バッチサイズ** | 10 | 過度な負荷を防止 |
| **バッチ全体の複雑度上限** | 2000 | 個別クエリの複雑度上限 * バッチサイズを超えない |

---

## 8. gqlgen 固有の実装ガイドライン

### 8.1 リゾルバの構造

```go
package resolver

import (
    "github.com/na2na-p/avion/proto/avion/drop/v1/dropv1connect"
    "github.com/na2na-p/avion/proto/avion/user/v1/userv1connect"
)

// Resolver はルートリゾルバ。gRPC クライアントを保持する。
type Resolver struct {
    userClient     userv1connect.UserServiceClient
    dropClient     dropv1connect.DropServiceClient
    timelineClient timelinev1connect.TimelineServiceClient
    // 他のサービスクライアント...
}

// NewResolver は Resolver を生成する
func NewResolver(
    userClient userv1connect.UserServiceClient,
    dropClient dropv1connect.DropServiceClient,
) *Resolver {
    return &Resolver{
        userClient: userClient,
        dropClient: dropClient,
    }
}
```

### 8.2 モデルマッピング

gRPC のレスポンスを GraphQL モデルに変換するマッピング関数は、リゾルバとは別のパッケージに配置します。

```go
package mapper

import (
    "encoding/base64"
    "fmt"

    "github.com/na2na-p/avion/services/avion-gateway/graph/model"
    userv1 "github.com/na2na-p/avion/proto/avion/user/v1"
)

// ToGraphQLUser は gRPC の UserResponse を GraphQL の User モデルに変換する
func ToGraphQLUser(u *userv1.UserResponse) *model.User {
    return &model.User{
        ID:          EncodeGlobalID("User", u.UserId),
        DisplayName: u.DisplayName,
        Handle:      u.Handle,
        Bio:         ptrString(u.Bio),
        AvatarURL:   ptrString(u.AvatarUrl),
        HeaderURL:   ptrString(u.HeaderUrl),
        IsVerified:  u.IsVerified,
        CreatedAt:   u.CreatedAt.AsTime(),
    }
}

// EncodeGlobalID は型名と内部 ID から Relay Global ID を生成する
func EncodeGlobalID(typeName, id string) string {
    return base64.StdEncoding.EncodeToString(
        []byte(fmt.Sprintf("%s:%s", typeName, id)),
    )
}

// DecodeGlobalID は Relay Global ID を型名と内部 ID にデコードする
func DecodeGlobalID(globalID string) (typeName, id string, err error) {
    decoded, err := base64.StdEncoding.DecodeString(globalID)
    if err != nil {
        return "", "", fmt.Errorf("invalid global ID: %w", err)
    }

    parts := strings.SplitN(string(decoded), ":", 2)
    if len(parts) != 2 {
        return "", "", fmt.Errorf("invalid global ID format: %s", globalID)
    }

    return parts[0], parts[1], nil
}

func ptrString(s string) *string {
    if s == "" {
        return nil
    }
    return &s
}
```

### 8.3 カスタムディレクティブの実装

```go
package directive

import (
    "context"
    "fmt"

    "github.com/99designs/gqlgen/graphql"
)

// Length はフィールドの文字列長を検証するディレクティブ実装
func Length(ctx context.Context, obj interface{}, next graphql.Resolver, min int, max int) (interface{}, error) {
    val, err := next(ctx)
    if err != nil {
        return nil, err
    }

    str, ok := val.(string)
    if !ok {
        return val, nil
    }

    length := len([]rune(str))
    if length < min {
        return nil, fmt.Errorf("入力は %d 文字以上である必要があります", min)
    }
    if length > max {
        return nil, fmt.Errorf("入力は %d 文字以内である必要があります", max)
    }

    return val, nil
}
```

### 8.4 Subscription の実装（SSE ベース）

avion-gateway は SSE（Server-Sent Events）を用いて GraphQL Subscription を実装します。

```go
package server

import (
    "github.com/99designs/gqlgen/graphql/handler"
    "github.com/99designs/gqlgen/graphql/handler/transport"
)

func setupSubscription(srv *handler.Server) {
    // SSE トランスポートを追加
    srv.AddTransport(transport.SSE{})
}
```

```go
package resolver

import (
    "context"
)

// NotificationCreated は新しい通知の Subscription リゾルバ
func (r *subscriptionResolver) NotificationCreated(ctx context.Context) (<-chan *model.Notification, error) {
    userID := middleware.GetUserID(ctx)

    ch := make(chan *model.Notification, 1)

    // NATS JetStream からリアルタイムイベントを受信
    go func() {
        defer close(ch)

        sub, err := r.natsConn.Subscribe(
            fmt.Sprintf("notification.user.%s", userID),
            func(msg *nats.Msg) {
                notification, err := decodeNotification(msg.Data)
                if err != nil {
                    slog.ErrorContext(ctx, "failed to decode notification", "error", err)
                    return
                }
                select {
                case ch <- notification:
                case <-ctx.Done():
                    return
                }
            },
        )
        if err != nil {
            slog.ErrorContext(ctx, "failed to subscribe", "error", err)
            return
        }
        defer sub.Unsubscribe()

        <-ctx.Done()
    }()

    return ch, nil
}
```

### 8.5 テスト戦略

GraphQL リゾルバのテストは、gRPC クライアントをモックして行います。

```go
package resolver_test

import (
    "context"
    "testing"

    "github.com/google/go-cmp/cmp"
    "go.uber.org/mock/gomock"
)

func TestQueryResolver_User(t *testing.T) {
    type args struct {
        id string
    }
    tests := []struct {
        name    string
        args    args
        mockFn  func(ctrl *gomock.Controller) *mocks.MockUserServiceClient
        want    *model.User
        wantErr error
    }{
        {
            name: "正常系: 存在するユーザーを取得",
            args: args{id: "VXNlcjowMUhYWVo="},
            mockFn: func(ctrl *gomock.Controller) *mocks.MockUserServiceClient {
                mock := mocks.NewMockUserServiceClient(ctrl)
                mock.EXPECT().
                    GetUser(gomock.Any(), gomock.Any()).
                    Return(connect.NewResponse(&userv1.GetUserResponse{
                        User: &userv1.UserResponse{
                            UserId:      "01HXYZ",
                            DisplayName: "テストユーザー",
                            Handle:      "testuser",
                        },
                    }), nil)
                return mock
            },
            want: &model.User{
                ID:          "VXNlcjowMUhYWVo=",
                DisplayName: "テストユーザー",
                Handle:      "testuser",
            },
            wantErr: nil,
        },
        {
            name: "異常系: 存在しないユーザー",
            args: args{id: "VXNlcjpub25leGlzdGVudA=="},
            mockFn: func(ctrl *gomock.Controller) *mocks.MockUserServiceClient {
                mock := mocks.NewMockUserServiceClient(ctrl)
                mock.EXPECT().
                    GetUser(gomock.Any(), gomock.Any()).
                    Return(nil, connect.NewError(connect.CodeNotFound, fmt.Errorf("user not found")))
                return mock
            },
            want:    nil,
            wantErr: &gqlerror.Error{Extensions: map[string]interface{}{"code": "NOT_FOUND"}},
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            ctrl := gomock.NewController(t)
            defer ctrl.Finish()

            mockClient := tt.mockFn(ctrl)
            resolver := NewResolver(mockClient, nil)
            queryResolver := resolver.Query()

            got, err := queryResolver.User(context.Background(), tt.args.id)

            if diff := cmp.Diff(tt.want, got); diff != "" {
                t.Errorf("User() mismatch (-want +got):\n%s", diff)
            }

            if tt.wantErr != nil {
                if err == nil {
                    t.Errorf("User() expected error but got nil")
                }
            }
        })
    }
}
```

---

## 付録

### A. スキーマ変更チェックリスト

スキーマを変更する際に確認すべき項目:

- [ ] 命名規則に準拠しているか（セクション 2 参照）
- [ ] Connection パターンの適用基準を満たしているか（セクション 3.2 参照）
- [ ] 入力型に適切なバリデーションディレクティブが設定されているか
- [ ] DataLoader の適用が必要なフィールドがないか（セクション 5 参照）
- [ ] フィールドの複雑度コストが設定されているか
- [ ] 既存フィールドの削除・型変更は `@deprecated` で段階的に行っているか
- [ ] スキーマのドキュメントコメントが記載されているか
- [ ] `graphql-inspector` による互換性チェックを CI で実行しているか（[api-versioning-strategy.md](./api-versioning-strategy.md) 参照）

### B. フロントエンド（Apollo Client）との連携

| 項目 | 方針 |
|:--|:--|
| **コード生成** | `graphql-codegen` で TypeScript の型定義とフックを自動生成 |
| **Fragment Colocation** | コンポーネントが使用するフィールドを Fragment として定義し、コンポーネントと同じファイルに配置 |
| **キャッシュキー** | `Node` インターフェースの `id` フィールドを `__typename:id` 形式でキャッシュキーに使用 |
| **Optimistic Update** | Mutation の結果を楽観的にキャッシュに反映し、サーバーレスポンスで補正 |
| **Error Handling** | `extensions.code` に基づくエラーハンドリングロジックをクライアント側に実装 |

### C. スキーマドキュメントコメントの記述規則

すべての型、フィールド、引数にはドキュメントコメントを記述します。

```graphql
"""
Avion プラットフォームのユーザー。
ローカルユーザーとリモートユーザー（ActivityPub 連携）の両方を含む。
"""
type User implements Node {
  """グローバルに一意な識別子"""
  id: ID!

  """表示名（1 文字以上 50 文字以下）"""
  displayName: String!

  """ハンドル名（@username 形式、変更不可）"""
  handle: String!

  """自己紹介文（最大 500 文字）"""
  bio: String
}
```

| ルール | 説明 |
|:--|:--|
| **型コメント** | 型の概要と用途を記述する |
| **フィールドコメント** | フィールドの意味と制約を記述する |
| **引数コメント** | 引数の目的、デフォルト値、有効範囲を記述する |
| **非推奨コメント** | `@deprecated` の `reason` に移行先と削除予定日を明記する |
