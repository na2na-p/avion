# Goバックエンド共通技術スタックガイドライン

## 概要

本ドキュメントは、Avionプロジェクトのすべてのバックエンドサービスで共通して使用するGo言語の技術スタックと実装ガイドラインを定義します。

## 技術スタック決定

### 採用技術

| カテゴリ | 技術 | バージョン | 理由 |
|---------|------|-----------|------|
| HTTPルーティング | [Chi](https://github.com/go-chi/chi) | v5 | 標準net/httpとの完全互換性、クリーンアーキテクチャとの親和性 |
| gRPC/HTTP統合 | [ConnectRPC](https://connectrpc.com/connect) | latest | gRPC/HTTP/gRPC-Webの統一的な処理、単一ポート運用 |
| GraphQL | [gqlgen](https://github.com/99designs/gqlgen) | latest | 型安全性、コード生成による開発効率 |

### 採用理由

#### 1. アーキテクチャ整合性
- **DDD/CQRS原則との調和**: Chiは標準`http.Handler`と`context.Context`のみを使用し、フレームワーク依存を最小化
- **関心の分離**: ドメイン層がWebフレームワークを一切意識しない実装が可能
- **クリーンアーキテクチャ**: インフラストラクチャ層の詳細として扱える軽量性

#### 2. 開発者体験
- **統一されたContext**: 標準`context.Context`によるシームレスなデータ伝播
- **エコシステム互換性**: 標準net/httpミドルウェアの完全サポート
- **簡潔性**: 追加の抽象化層を導入しない、Goらしいイディオマティックな実装

#### 3. 運用効率
- **単一ポート運用**: ConnectRPCによりgRPC/HTTP/gRPC-Webを統一的に処理
- **簡素化されたデプロイ**: リバースプロキシ層が不要
- **統一されたミドルウェア**: HTTPとgRPCで同じミドルウェアチェーンを使用可能

## プロジェクト構造

### ディレクトリレイアウト

```
/cmd
  /[service-name]         # エントリーポイント
    main.go
/internal
  /application           # アプリケーション層 (CQRS)
    /command            # コマンドハンドラ
    /query              # クエリハンドラ
  /domain               # ドメイン層
    /entity            # エンティティ
    /valueobject       # 値オブジェクト
    /repository        # リポジトリインターフェース
    /service           # ドメインサービス
  /infrastructure       # インフラストラクチャ層
    /config            # 設定管理
    /persistence       # データ永続化実装
    /grpc              # gRPC/ConnectRPCクライアント
  /ports                # ポート層
    /http              # HTTPハンドラ (Chi)
    /rpc               # RPCハンドラ (ConnectRPC)
/pkg                    # 外部パッケージとして公開する共通コード
```

## 実装ガイドライン

### HTTPサーバー実装

#### 基本的なサーバー初期化

```go
package main

import (
    "net/http"
    
    "github.com/go-chi/chi/v5"
    "github.com/go-chi/chi/v5/middleware"
    "connectrpc.com/connect"
)

func NewRouter() *chi.Mux {
    r := chi.NewRouter()
    
    // 標準ミドルウェア
    r.Use(middleware.RequestID)
    r.Use(middleware.RealIP)
    r.Use(middleware.Logger)
    r.Use(middleware.Recoverer)
    r.Use(middleware.Compress(5))
    
    // カスタムミドルウェア
    r.Use(TraceIDMiddleware)
    r.Use(AuthMiddleware)
    
    return r
}

func main() {
    router := NewRouter()
    
    // ヘルスチェックエンドポイント
    router.Get("/health", HealthHandler)
    
    // ConnectRPCハンドラのマウント
    path, handler := NewConnectHandler()
    router.Mount(path, handler)
    
    // サーバー起動
    http.ListenAndServe(":8080", router)
}
```

### ConnectRPC実装

#### サービス実装例

```go
package rpc

import (
    "context"
    
    "connectrpc.com/connect"
    userv1 "path/to/gen/user/v1"
    "path/to/gen/user/v1/userv1connect"
)

type UserService struct {
    userv1connect.UnimplementedUserServiceHandler
    app *application.Application  // CQRS層への参照
}

func (s *UserService) GetUser(
    ctx context.Context,
    req *connect.Request[userv1.GetUserRequest],
) (*connect.Response[userv1.GetUserResponse], error) {
    // コンテキストからTraceID等を取得
    traceID := middleware.GetTraceID(ctx)
    
    // CQRSクエリハンドラの呼び出し
    query := &application.GetUserQuery{
        UserID: req.Msg.UserId,
    }
    
    user, err := s.app.Queries.GetUser.Handle(ctx, query)
    if err != nil {
        return nil, connect.NewError(connect.CodeNotFound, err)
    }
    
    // レスポンス構築
    return connect.NewResponse(&userv1.GetUserResponse{
        User: toProtoUser(user),
    }), nil
}
```

#### ハンドラ登録

```go
func NewConnectHandler() (string, http.Handler) {
    userService := &UserService{
        app: application.New(/* dependencies */),
    }
    
    path, handler := userv1connect.NewUserServiceHandler(
        userService,
        connect.WithInterceptors(
            LoggingInterceptor(),
            ValidatingInterceptor(),
            MetricsInterceptor(),
        ),
    )
    
    return path, handler
}
```

### ミドルウェア実装

#### 認証ミドルウェア

```go
package middleware

import (
    "context"
    "net/http"
    
    "github.com/go-chi/jwtauth/v5"
)

func AuthMiddleware(tokenAuth *jwtauth.JWTAuth) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            // JWT検証
            token, _, err := jwtauth.FromContext(r.Context())
            
            if err != nil {
                http.Error(w, "Unauthorized", http.StatusUnauthorized)
                return
            }
            
            // コンテキストに認証情報を追加
            ctx := context.WithValue(r.Context(), "user", token.Claims)
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}
```

#### レート制限ミドルウェア

```go
package middleware

import (
    "net/http"
    "time"
    
    "github.com/go-chi/httprate"
)

func RateLimiter() func(http.Handler) http.Handler {
    return httprate.Limit(
        100,              // リクエスト数
        1*time.Minute,    // 時間窓
        httprate.WithKeyFuncs(httprate.KeyByIP, httprate.KeyByEndpoint),
    )
}
```

### コンテキスト管理

#### TraceID伝播

```go
package middleware

import (
    "context"
    "net/http"
    
    "github.com/google/uuid"
)

type contextKey string

const TraceIDKey contextKey = "trace_id"

func TraceIDMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        traceID := r.Header.Get("X-Trace-ID")
        if traceID == "" {
            traceID = uuid.New().String()
        }
        
        ctx := context.WithValue(r.Context(), TraceIDKey, traceID)
        w.Header().Set("X-Trace-ID", traceID)
        
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}

func GetTraceID(ctx context.Context) string {
    if v := ctx.Value(TraceIDKey); v != nil {
        return v.(string)
    }
    return ""
}
```

## 推奨ライブラリ

### コアライブラリ

| 用途 | ライブラリ | インポートパス |
|-----|-----------|--------------|
| HTTPルーティング | Chi | `github.com/go-chi/chi/v5` |
| RPC | ConnectRPC | `connectrpc.com/connect` |
| GraphQL | gqlgen | `github.com/99designs/gqlgen` |

### ミドルウェア・ユーティリティ

| 用途 | ライブラリ | インポートパス |
|-----|-----------|--------------|
| JWT認証 | jwtauth | `github.com/go-chi/jwtauth/v5` |
| レート制限 | httprate | `github.com/go-chi/httprate` |
| サーキットブレーカー | gobreaker | `github.com/sony/gobreaker` |
| ロギング | zerolog | `github.com/rs/zerolog` |
| バリデーション | validator | `github.com/go-playground/validator/v10` |
| 時刻モック | ctxtime | `github.com/newmo-oss/ctxtime` |

### データベース・ストレージ

| 用途 | ライブラリ | インポートパス |
|-----|-----------|--------------|
| PostgreSQL | pgx | `github.com/jackc/pgx/v5` |
| Redis | go-redis | `github.com/redis/go-redis/v9` |
| S3 | AWS SDK | `github.com/aws/aws-sdk-go-v2` |

## サービス別実装例

### avion-gateway

```go
// GraphQLとgRPCクライアントの統合
func NewResolver(clients *Clients) *Resolver {
    return &Resolver{
        userClient:     clients.User,     // ConnectRPCクライアント
        dropClient:     clients.Drop,
        timelineClient: clients.Timeline,
    }
}

// GraphQLリゾルバ実装
func (r *queryResolver) User(ctx context.Context, id string) (*model.User, error) {
    // ConnectRPCクライアントを使用
    req := connect.NewRequest(&userv1.GetUserRequest{
        UserId: id,
    })
    
    // コンテキストからTraceIDを伝播
    req.Header().Set("X-Trace-ID", middleware.GetTraceID(ctx))
    
    resp, err := r.userClient.GetUser(ctx, req)
    if err != nil {
        return nil, err
    }
    
    return toGraphQLUser(resp.Msg.User), nil
}
```

### バックエンドサービス

```go
// avion-user, avion-drop等の実装
func main() {
    // 設定読み込み
    cfg := config.Load()
    
    // 依存関係の初期化
    db := persistence.NewPostgreSQL(cfg.Database)
    cache := persistence.NewRedis(cfg.Redis)
    
    // アプリケーション層の初期化
    app := application.New(db, cache)
    
    // RPCサービスの初期化
    service := rpc.NewUserService(app)
    
    // ルーター設定
    router := chi.NewRouter()
    router.Use(middleware.Logger)
    router.Use(middleware.Recoverer)
    
    // ヘルスチェック
    router.Get("/health", handlers.Health)
    
    // ConnectRPCハンドラのマウント
    path, handler := userv1connect.NewUserServiceHandler(service)
    router.Mount(path, handler)
    
    // サーバー起動
    log.Printf("Starting server on %s", cfg.Server.Address)
    http.ListenAndServe(cfg.Server.Address, router)
}
```

## テスト実装

### ハンドラテスト

```go
func TestUserHandler(t *testing.T) {
    // モックの準備
    ctrl := gomock.NewController(t)
    defer ctrl.Finish()
    
    mockApp := mocks.NewMockApplication(ctrl)
    
    // テーブルドリブンテスト
    tests := []struct {
        name     string
        request  *userv1.GetUserRequest
        mockFunc func()
        want     *userv1.GetUserResponse
        wantErr  bool
    }{
        {
            name: "正常系",
            request: &userv1.GetUserRequest{
                UserId: "user123",
            },
            mockFunc: func() {
                mockApp.EXPECT().
                    GetUser(gomock.Any(), "user123").
                    Return(&domain.User{ID: "user123"}, nil)
            },
            want: &userv1.GetUserResponse{
                User: &userv1.User{Id: "user123"},
            },
            wantErr: false,
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            tt.mockFunc()
            
            service := &UserService{app: mockApp}
            req := connect.NewRequest(tt.request)
            
            resp, err := service.GetUser(context.Background(), req)
            
            if tt.wantErr {
                assert.Error(t, err)
            } else {
                assert.NoError(t, err)
                assert.Equal(t, tt.want, resp.Msg)
            }
        })
    }
}
```

## 移行ガイド

### 既存コードからの移行手順

1. **依存関係の更新**
   ```bash
   go get github.com/go-chi/chi/v5
   go get connectrpc.com/connect
   go get github.com/bufbuild/buf/cmd/buf
   go get github.com/bufbuild/connect-go/cmd/protoc-gen-connect-go
   ```

2. **Proto定義の作成**
   ```protobuf
   syntax = "proto3";
   package user.v1;
   
   service UserService {
     rpc GetUser(GetUserRequest) returns (GetUserResponse);
   }
   ```

3. **コード生成**
   ```bash
   buf generate
   ```

4. **ハンドラの実装**
   - 既存のビジネスロジックをCQRS層に移動
   - ConnectRPCハンドラでCQRS層を呼び出し

5. **ミドルウェアの移行**
   - フレームワーク固有のミドルウェアを標準http.Handlerベースに変換

## パフォーマンス考慮事項

### 接続プーリング

```go
// PostgreSQL接続プール
config := pgxpool.Config{
    MaxConns:        30,
    MinConns:        5,
    MaxConnLifetime: time.Hour,
    MaxConnIdleTime: time.Minute * 30,
}

// Redis接続プール
client := redis.NewClient(&redis.Options{
    PoolSize:     100,
    MinIdleConns: 10,
    MaxRetries:   3,
})
```

### タイムアウト設定

```go
// HTTPクライアントタイムアウト
client := &http.Client{
    Timeout: 30 * time.Second,
}

// コンテキストタイムアウト
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()
```

## セキュリティ考慮事項

### 入力検証

```go
// バリデーション例
type CreateUserRequest struct {
    Email    string `validate:"required,email"`
    Password string `validate:"required,min=8"`
}

func ValidateRequest(req interface{}) error {
    validate := validator.New()
    return validate.Struct(req)
}
```

### レート制限

```go
// IPベースとユーザーベースの組み合わせ
limiter := httprate.Limit(
    100,
    1*time.Minute,
    httprate.WithKeyFuncs(
        httprate.KeyByIP,
        httprate.KeyByHeader("X-User-ID"),
    ),
)
```

## トラブルシューティング

### よくある問題と解決策

| 問題 | 原因 | 解決策 |
|-----|------|-------|
| コンテキストが伝播しない | 独自Contextの使用 | 標準context.Contextを使用 |
| ミドルウェアが動作しない | 登録順序の誤り | 認証→ロギング→ビジネスロジックの順で登録 |
| gRPCエラーが不明瞭 | エラーハンドリング不足 | connect.NewErrorで適切なコードを返す |
| パフォーマンス低下 | 接続プール未設定 | DB/Redis接続プールを適切に設定 |

## 参考リンク

- [Chi Documentation](https://github.com/go-chi/chi)
- [ConnectRPC Documentation](https://connectrpc.com/docs/go/getting-started)
- [gqlgen Documentation](https://gqlgen.com/)
- [Avion Architecture Overview](../architecture.md)
- [Avion Testing Strategy](../testing-strategy.md)