# Avion プロジェクト ディレクトリ構造仕様書

このドキュメントは、Avionプロジェクトの現在の状態と完成後の目標ディレクトリ構造を定義し、`.cursor/rules`で定義されたDDD設計原則および開発ガイドラインに準拠した構成を示します。

## 現在のディレクトリ構造（2025年1月時点）

```
avion/
├── .cursor/                        # AI開発支援設定（Cursor用）
│   ├── guidelines.mdc              # 開発ガイドライン
│   ├── go-testing.mdc              # Goテスト規約
│   └── rules/                      # 設計ルール定義
├── docs/                           # プロジェクトドキュメント
│   ├── architecture/               # アーキテクチャ設計書
│   │   └── directory-structure.md  # 本ドキュメント
│   ├── common/                     # 共通設計・ガイドライン
│   ├── avion-[service]/            # サービス別ドキュメント（PRD、DesignDoc、エラーカタログ）
│   └── templates/                  # ドキュメントテンプレート
├── report/                         # 分析・レビューレポート
│   └── prd-designdoc-comprehensive-review.md
├── .gitignore                      # Git除外設定
└── CLAUDE.md                       # AI開発アシスタント向け指示書
```

## 完成後の目標ディレクトリ構造

```
avion/
├── .cursor/                        # AI開発支援設定（Cursor用）
│   ├── guidelines.mdc              # 開発ガイドライン（最優先ルール）
│   ├── go-testing.mdc              # Goテスト規約
│   └── rules/                      # 設計ルール定義
│       ├── core.mdc                # コアルール
│       ├── ddd/                    # DDD設計ルール
│       │   └── architecture/       # アーキテクチャ定義
│       ├── defect/                 # 欠陥分析ルール
│       ├── container-presentation/ # コンテナ・プレゼンテーション分離
│       ├── features-directory/     # 機能別ディレクトリ構成
│       └── languages/              # 言語固有ルール
├── services/                       # マイクロサービス群
│   ├── avion-gateway/              # APIゲートウェイ
│   ├── avion-auth/                 # 認証・認可サービス
│   ├── avion-user/                 # ユーザー管理サービス
│   ├── avion-drop/                 # 投稿管理サービス
│   ├── avion-timeline/             # タイムラインサービス
│   ├── avion-activitypub/          # ActivityPubフェデレーション
│   ├── avion-notification/         # 通知サービス
│   ├── avion-media/                # メディア管理サービス
│   ├── avion-search/               # 検索サービス
│   ├── avion-system-admin/         # システム管理サービス
│   ├── avion-moderation/           # モデレーションサービス
│   └── avion-community/            # コミュニティ機能サービス
├── frontend/                       # フロントエンドアプリケーション
│   └── avion-web/                  # React SPA
├── packages/                       # 共通パッケージ（各々独立したGoモジュール）
│   ├── observability/              # オブザーバビリティ共通実装
│   │   ├── go.mod
│   │   └── go.sum
│   ├── errors/                     # エラー定義・ハンドリング
│   │   ├── go.mod
│   │   └── go.sum
│   ├── grpc-interceptors/          # gRPC共通インターセプター
│   │   ├── go.mod
│   │   └── go.sum
│   ├── redis-client/               # Redis共通クライアント
│   │   ├── go.mod
│   │   └── go.sum
│   └── test-utils/                 # テストユーティリティ
│       ├── go.mod
│       └── go.sum
├── migrations/                     # データベースマイグレーション
│   ├── goose/                      # Gooseマイグレーション設定
│   └── scripts/                    # マイグレーションスクリプト
├── deployments/                    # デプロイメント設定
│   ├── helm/                       # Helm Charts
│   │   ├── avion/                  # Avion統合Chart
│   │   │   ├── charts/             # サブチャート
│   │   │   ├── templates/          # Kubernetesマニフェストテンプレート
│   │   │   ├── values.yaml         # デフォルト設定値
│   │   │   ├── values-dev.yaml     # 開発環境用設定
│   │   │   ├── values-staging.yaml # ステージング環境用設定
│   │   │   ├── values-prod.yaml    # 本番環境用設定
│   │   │   └── Chart.yaml          # Chartメタデータ
│   └── docker-compose/             # Docker Compose設定
│       ├── docker-compose.yml      # 基本構成
│       ├── docker-compose.dev.yml  # 開発環境用オーバーライド
│       └── .env.example            # 環境変数サンプル
├── scripts/                        # ビルド・デプロイスクリプト
│   ├── build/                      # ビルドスクリプト
│   ├── test/                       # テスト実行スクリプト
│   └── ci/                         # CI/CDスクリプト
├── tests/                          # クロスサービス統合テスト
│   └── integration/                # サービス間統合テスト
├── docs/                           # プロジェクトドキュメント
│   ├── architecture/               # アーキテクチャ設計書
│   ├── common/                     # 共通設計・ガイドライン
│   ├── avion-[service]/            # サービス別ドキュメント
│   ├── implementation-plan/        # 実装計画
│   ├── improvements/               # 改善提案
│   └── templates/                  # ドキュメントテンプレート
├── proto/                          # Protocol Buffers定義
│   └── avion/                      # サービス別proto定義
│       ├── auth/                   # 認証サービスproto
│       ├── user/                   # ユーザーサービスproto
│       └── ...                     # 他サービスproto
├── report/                         # 分析・コンプライアンスレポート
├── .github/                        # GitHub設定
│   ├── workflows/                  # GitHub Actions
│   └── ISSUE_TEMPLATE/             # Issueテンプレート
├── .gitignore                      # Git除外設定
├── Makefile                        # プロジェクト全体のビルド・タスク定義
├── README.md                       # プロジェクト概要
└── CLAUDE.md                       # AI開発アシスタント向け指示書

```

## 各サービスの内部構造（DDD準拠）

`.cursor/rules/ddd/architecture/`に定義されたレイヤードアーキテクチャに従い、各サービスは以下の4層構造を持ちます：

```
services/avion-[service]/
├── cmd/                            # エントリーポイント
│   └── server/
│       └── main.go                 # サーバー起動
├── internal/                       # 内部実装（外部非公開）
│   ├── handler/                    # Handler層（最上位）
│   │   ├── grpc/                   # gRPCハンドラー
│   │   ├── http/                   # HTTPハンドラー（必要な場合）
│   │   └── event/                  # イベントハンドラー
│   ├── usecase/                    # UseCase層
│   │   ├── command/                # コマンド（更新系）
│   │   ├── query/                  # クエリ（参照系）
│   │   ├── dto/                    # データ転送オブジェクト
│   │   └── interface/              # 外部サービスインターフェース
│   ├── domain/                     # Domain層（ビジネスロジック）
│   │   ├── model/                  # ドメインモデル
│   │   │   ├── aggregate/          # 集約
│   │   │   ├── entity/             # エンティティ
│   │   │   └── valueobject/        # 値オブジェクト
│   │   ├── repository/             # リポジトリインターフェース
│   │   ├── service/                # ドメインサービス
│   │   └── event/                  # ドメインイベント
│   └── infrastructure/             # Infrastructure層（最下位）
│       ├── persistence/            # 永続化実装
│       │   ├── postgres/           # PostgreSQL実装
│       │   ├── redis/              # Redis実装
│       │   └── dao/                # データアクセスオブジェクト
│       ├── external/               # 外部サービス実装
│       ├── config/                 # 設定管理
│       └── observability/          # 監視・ログ実装
├── pkg/                            # 外部公開パッケージ
│   └── api/                        # 公開API定義
├── migrations/                     # サービス固有マイグレーション
│   └── sql/                        # SQLマイグレーションファイル
├── test/                           # テストファイル
│   ├── unit/                       # 単体テスト
│   ├── integration/                # 統合テスト
│   ├── e2e/                        # E2Eテスト（サービス固有）
│   └── mocks/                      # 自動生成モック（gomock）
│       ├── domain/                 # ドメイン層モック
│       ├── usecase/                # UseCase層モック
│       └── infrastructure/        # Infrastructure層モック
├── Dockerfile                      # Dockerイメージ定義
├── Makefile                        # サービス固有タスク
├── go.mod                          # サービスモジュール定義
└── README.md                       # サービス説明書

```

## フロントエンド構造（React SPA）

```
frontend/avion-web/
├── src/
│   ├── components/                 # Reactコンポーネント
│   │   ├── common/                 # 共通コンポーネント
│   │   ├── features/               # 機能別コンポーネント
│   │   └── layouts/                # レイアウトコンポーネント
│   ├── hooks/                      # カスタムフック
│   ├── services/                   # APIクライアント・サービス
│   ├── store/                      # 状態管理（Redux/Zustand等）
│   ├── utils/                      # ユーティリティ関数
│   ├── graphql/                    # GraphQL定義
│   │   ├── queries/                # クエリ定義
│   │   ├── mutations/              # ミューテーション定義
│   │   └── fragments/              # フラグメント定義
│   ├── styles/                     # スタイル定義
│   ├── types/                      # TypeScript型定義
│   ├── App.tsx                     # アプリケーションルート
│   └── main.tsx                    # エントリーポイント
├── public/                         # 静的ファイル
├── tests/                          # テストファイル
│   ├── unit/                       # 単体テスト
│   ├── integration/                # 統合テスト
│   └── e2e/                        # E2Eテスト（フロントエンド固有）
├── .env.example                    # 環境変数サンプル
├── package.json                    # NPM設定
├── tsconfig.json                   # TypeScript設定
├── vite.config.ts                  # Vite設定
└── README.md                       # フロントエンド説明書

```

## Goモジュール管理戦略

Avionプロジェクトでは、マイクロサービスアーキテクチャの独立性を保つため、以下の戦略を採用：

1. **独立したGoモジュール**: 各サービスと共通パッケージは独立した`go.mod`を持つ
2. **バージョン管理**: 共通パッケージはセマンティックバージョニングで管理
3. **依存関係**: 各サービスは必要な共通パッケージのみを依存関係として宣言

例：
```go
// services/avion-auth/go.mod
module github.com/na2na-p/avion/services/avion-auth

require (
    github.com/na2na-p/avion/packages/observability v1.0.0
    github.com/na2na-p/avion/packages/errors v1.0.0
    // その他の依存関係
)
```

## 重要な設計原則

### 1. DDD 4層アーキテクチャ準拠

`.cursor/rules/ddd/architecture/architecture.md`に定義された以下の原則を厳守：

- **Handler層**: 外部からのリクエストを受け付ける最上位層
- **UseCase層**: ビジネスユースケースを実装（CQRS適用）
- **Domain層**: ビジネスロジックとドメインモデル
- **Infrastructure層**: 技術的実装の詳細

### 2. テスト駆動開発（TDD）とテスト戦略

`.cursor/guidelines.mdc`で定義されたTDDワークフロー：

1. インターフェース定義
2. テスト実装（失敗するテスト）
3. プロダクトコード実装
4. 検証と反復

**テストの配置戦略：**
- **単体テスト**: 各サービスの`test/unit/`に配置
- **統合テスト**: 各サービスの`test/integration/`に配置  
- **E2Eテスト**: 各サービスの`test/e2e/`に配置（サービス固有のエンドツーエンドテスト）
- **クロスサービステスト**: プロジェクトルートの`tests/integration/`に配置（複数サービス間の連携テスト）

### 3. モック生成戦略

Go言語のモックは`//go:generate`ディレクティブによる自動生成（各サービスディレクトリ内に配置）：

```go
//go:generate mockgen -source=$GOFILE -destination=../../test/mocks/[layer]/[package]/mock_[filename].go -package=[package]
```

例：
- ドメイン層のリポジトリインターフェース → `test/mocks/domain/repository/mock_user_repository.go`
- UseCase層の外部サービスインターフェース → `test/mocks/usecase/interface/mock_external_service.go`
- Infrastructure層のクライアント → `test/mocks/infrastructure/external/mock_ses_client.go`

### 4. コミット規約

Conventional Commits仕様に準拠：

```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

### 5. 環境変数管理

各サービスは環境変数による設定を行い、起動時に必須変数が欠けている場合は即座に失敗（fail-fast）します。

### 6. イベント駆動アーキテクチャ

サービス間通信：
- 同期通信: gRPC
- 非同期通信: Redis Pub/Sub
- リアルタイム配信: SSE (Server-Sent Events)

## デプロイメント戦略

### Helm Chartsによる本番デプロイ

Kubernetesへのデプロイは、Helm Chartsを使用して管理します：

- **統合Chart**: `deployments/helm/avion/`に全サービスを統合管理するChartを配置
- **環境別設定**: `values-{env}.yaml`で環境ごとの設定を管理
- **サブチャート**: 各マイクロサービスは個別のサブチャートとして管理

### Docker Composeによる開発環境

ローカル開発環境は、Docker Composeで構築：

- **基本構成**: `docker-compose.yml`で全サービスの基本設定
- **開発用オーバーライド**: `docker-compose.dev.yml`でホットリロードなどの開発機能を追加
- **環境変数**: `.env`ファイルで環境固有の設定を管理

### インフラストラクチャ管理

**注意**: Terraformなどのインフラストラクチャプロビジョニングツールは、本リポジトリのスコープ外です。
インフラ管理は別リポジトリで行い、本リポジトリはアプリケーションのデプロイメント定義のみを管理します。

## 開発環境セットアップ

### 必要なツール

- Go 1.25+
- Node.js 20+
- Docker & Docker Compose
- Kubernetes (開発用はMinikube/Kind)
- Helm 3.0+
- PostgreSQL 17
- Redis 7+
- MeiliSearch 1.0+

### 開発用ポート割り当て

| サービス | HTTP | gRPC |
|---------|------|------|
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

## 実装フェーズ計画

### Phase 0: 共通基盤（現在）
- ドキュメント整備 ✅
- アーキテクチャ設計 ✅
- 開発ガイドライン策定 ✅

### Phase 1: コアサービス実装
1. `packages/` - 共通パッケージの実装
2. `services/avion-auth/` - 認証サービス
3. `services/avion-user/` - ユーザー管理サービス
4. `services/avion-drop/` - 投稿管理サービス

### Phase 2: 機能拡張サービス
1. `services/avion-timeline/` - タイムラインサービス
2. `services/avion-notification/` - 通知サービス
3. `services/avion-search/` - 検索サービス
4. `services/avion-media/` - メディア管理サービス

### Phase 3: ソーシャル機能
1. `services/avion-activitypub/` - フェデレーション
2. `services/avion-community/` - コミュニティ機能
3. `services/avion-moderation/` - モデレーション

### Phase 4: 統合とフロントエンド
1. `services/avion-gateway/` - APIゲートウェイ
2. `frontend/avion-web/` - Webフロントエンド
3. `services/avion-system-admin/` - システム管理

## まとめ

このディレクトリ構造は、`.cursor/rules`で定義された設計原則を完全に反映し、以下を実現します：

1. **明確な責務分離**: DDDレイヤードアーキテクチャによる関心の分離
2. **スケーラビリティ**: マイクロサービスアーキテクチャによる独立したスケーリング
3. **保守性**: 統一された構造による高い保守性
4. **テスタビリティ**: TDDとモック自動生成による包括的なテスト
5. **開発効率**: AI支援開発（Cursor）との完全な互換性

現在はPhase 0の段階にあり、設計とドキュメントの整備が完了しています。次のステップはPhase 1のコアサービス実装となります。