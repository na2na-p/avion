# Avion 共通ドキュメント

このディレクトリには、Avionプラットフォーム全体で共有される設計ドキュメント、ガイドライン、標準仕様が含まれています。

## 📚 ドキュメント一覧

### 🏗️ アーキテクチャ
- **[architecture/](./architecture/)** - アーキテクチャ関連ドキュメント
  - **[architecture.md](./architecture/architecture.md)** - Avionプラットフォーム全体のアーキテクチャ概要
    - マイクロサービス構成
    - サービス間の関係図
    - データフロー
    - インフラストラクチャ構成
  - **[development-guidelines.md](./architecture/development-guidelines.md)** - 共通開発ガイドライン
    - テスト駆動開発（TDD）ワークフロー
    - DDD（ドメイン駆動設計）実装規約
    - モック生成戦略
    - Git操作ガイドライン
    - コミット規約（Conventional Commits）
    - ID生成戦略（Backend採番）
  - **[go-backend-framework.md](./architecture/go-backend-framework.md)** - Goバックエンド共通技術スタックガイドライン
    - 採用技術（Chi, ConnectRPC, gqlgen）
    - プロジェクト構造（ディレクトリレイアウト）
    - HTTPサーバー・ConnectRPC実装ガイドライン
    - ミドルウェア実装（認証、レート制限、TraceID伝播）
    - 推奨ライブラリ一覧
    - テスト・パフォーマンス・セキュリティ考慮事項
  - **[api-versioning-strategy.md](./architecture/api-versioning-strategy.md)** - APIバージョニング戦略
    - gRPC/ConnectRPC Protoパッケージバージョニング
    - GraphQLスキーマ進化戦略
    - REST API URLパスベースバージョニング
    - Breaking Change検出・管理プロセス
    - サービス間通信のバージョニング方針
    - バージョンライフサイクル管理
  - **[graphql-schema-guidelines.md](./architecture/graphql-schema-guidelines.md)** - GraphQLスキーマ設計ガイドライン
    - スキーマ構造（ファイル分割戦略、gqlgen設定）
    - 命名規則（型名、フィールド名、Query/Mutation名）
    - 型設計（Nodeインターフェース、Relay Connection、入力型・ペイロード型）
    - エラーハンドリング（ConnectRPC→GraphQLエラー変換）
    - N+1問題対策（DataLoaderパターン）
    - セキュリティ（クエリ深度・複雑度制限、レート制限）
    - パフォーマンス（キャッシュ戦略、永続化クエリ）
  - **[validation-package-design.md](./architecture/validation-package-design.md)** - バリデーション共通パッケージ設計
    - 各層（Handler/UseCase/Domain/Infrastructure）のバリデーション責務
    - `pkg/validation` パッケージ構造・API設計
    - Value Objectの自己検証パターン
    - エラーマッピング（ConnectRPC/GraphQL対応）
    - テスト戦略・テーブル駆動テスト例

### 🚀 インフラストラクチャ
- **[infrastructure/](./infrastructure/)** - インフラストラクチャ・CI/CD関連
  - **[cicd-migration-strategy.md](./infrastructure/cicd-migration-strategy.md)** - CI/CDデータベースマイグレーション実行戦略
    - GitHub Actions実装
    - Kubernetes Job実装
    - 環境別デプロイ戦略
    - ロールバック戦略
  - **[environment-variables.md](./infrastructure/environment-variables.md)** - 環境変数管理設計ガイドライン
    - 環境変数の命名規則
    - 必須環境変数の検証
    - 設定ファイルの構造
    - セキュリティベストプラクティス
  - **[service-mesh-guide.md](./infrastructure/service-mesh-guide.md)** - サービスメッシュ設定ガイド
    - mTLS（相互TLS）設定と証明書管理
    - gRPC対応L7ロードバランシング
    - カナリアリリース・トラフィック分割
    - OpenTelemetry/Prometheus連携
    - サーキットブレーカー・リトライ・タイムアウト
    - Kubernetesマニフェスト設定例
  - **[disaster-recovery-plan.md](./infrastructure/disaster-recovery-plan.md)** - 障害復旧（DR）計画
    - RTO/RPO目標（サービスティア別定義）
    - バックアップ戦略（PostgreSQL WAL/PITR、Redis RDB+AOF、S3クロスリージョン複製、NATS JetStreamレプリケーション）
    - 障害シナリオ（単一サービス、データベース、データセンター、ネットワーク分断）
    - 復旧手順（シナリオ別段階的復旧）
    - 定期テスト（Chaos Engineering、DRサイト切り替え）
    - エスカレーション（障害レベル別通知フロー）

### 🗄️ データベース
- **[database/](./database/)** - データベース・マイグレーション関連
  - **[database-migration-strategy.md](./database/database-migration-strategy.md)** - データベースマイグレーション戦略
    - Goose利用規約
    - 命名規則とバージョニング
    - 前方/後方互換性
  - **[goose-configuration-guide.md](./database/goose-configuration-guide.md)** - Goose設定ガイド
    - ファイル構造
    - マイグレーション作成手順
    - ロールバック戦略

### 📊 観測可能性
- **[observability/](./observability/)** - Observability（観測可能性）関連
  - **[observability-package-design.md](./observability/observability-package-design.md)** - 共通Observabilityパッケージ設計
    - エラーハンドリングパッケージ
    - 構造化ログパッケージ
    - 分散トレーシング（OpenTelemetry）
    - メトリクス収集（Prometheus）
    - コンテキスト管理

### ❌ エラーハンドリング
- **[errors/](./errors/)** - エラーコード標準化
  - **[error-standards.md](./errors/error-standards.md)** - エラーコード標準化ガイドライン（日本語）
    - 命名規則: `[SERVICE]_[LAYER]_[ERROR_TYPE]`
    - レイヤー別エラー定義
    - 実装ガイドライン
  - **[error-codes.md](./errors/error-codes.md)** - Error Code Standards（英語）
    - プロトコル間マッピング（HTTP/gRPC）
    - サービスプレフィックス定義
    - 標準エラーコード一覧

### 🔑 ID生成
- **[id-generation-guideline.md](./id-generation-guideline.md)** - ID生成ガイドライン
  - Backend採番の基本方針
  - 推奨ID形式（ULID、UUID v7、Snowflake ID）
  - 各サービスでの実装例
  - パフォーマンス最適化
  - セキュリティ考慮事項

### 🔧 DDD設計パターン
- **[domain-service-srp-refactoring.md](./domain-service-srp-refactoring.md)** - ドメインサービスSRPリファクタリングガイド
  - 単一責任原則（SRP）に基づくドメインサービス分解
  - avion-user / avion-media サービスの分解例
  - サービス命名規則とコンポジション
  - 移行戦略（フェーズ別）

## 🎯 ドキュメントの利用方法

### 新規サービス開発時
1. **[architecture/architecture.md](./architecture/architecture.md)** でシステム全体像を理解
2. **[architecture/development-guidelines.md](./architecture/development-guidelines.md)** で開発規約を確認
3. **[architecture/go-backend-framework.md](./architecture/go-backend-framework.md)** で技術スタックとフレームワーク構成を確認
4. **[infrastructure/environment-variables.md](./infrastructure/environment-variables.md)** で設定管理方法を確認
5. **[errors/error-standards.md](./errors/error-standards.md)** でエラーコード体系を理解
6. **[id-generation-guideline.md](./id-generation-guideline.md)** でID生成戦略を確認

### 実装時の参照
- **ID生成実装**: [id-generation-guideline.md](./id-generation-guideline.md)の実装例を参照
- **エラーハンドリング実装**: [errors/error-standards.md](./errors/error-standards.md)の実装例を参照
- **ログ・トレース実装**: [observability/observability-package-design.md](./observability/observability-package-design.md)の使用例を参照
- **環境変数追加**: [infrastructure/environment-variables.md](./infrastructure/environment-variables.md)の命名規則に従う
- **マイグレーション作成**: [database/goose-configuration-guide.md](./database/goose-configuration-guide.md)の手順に従う
- **CI/CDパイプライン設定**: [infrastructure/cicd-migration-strategy.md](./infrastructure/cicd-migration-strategy.md)を参照
- **技術スタック確認**: [architecture/go-backend-framework.md](./architecture/go-backend-framework.md)の推奨ライブラリに従う
- **APIバージョニング**: [architecture/api-versioning-strategy.md](./architecture/api-versioning-strategy.md)のバージョニングポリシーに従う
- **ドメインサービス設計**: [domain-service-srp-refactoring.md](./domain-service-srp-refactoring.md)のSRP分解パターンを参照
- **サービスメッシュ設定**: [infrastructure/service-mesh-guide.md](./infrastructure/service-mesh-guide.md)のmTLS・ロードバランシング設定を参照
- **障害復旧計画**: [infrastructure/disaster-recovery-plan.md](./infrastructure/disaster-recovery-plan.md)のRTO/RPO目標・バックアップ戦略・復旧手順を参照
- **GraphQLスキーマ設計**: [architecture/graphql-schema-guidelines.md](./architecture/graphql-schema-guidelines.md)の命名規則・型設計・DataLoaderパターンに従う
- **バリデーション実装**: [architecture/validation-package-design.md](./architecture/validation-package-design.md)の各層バリデーション責務・`pkg/validation`パッケージを参照

## 📋 ドキュメント管理ルール

### 更新時の注意事項
1. **互換性維持**: 既存仕様を変更する場合は後方互換性を考慮
2. **レビュー必須**: 共通仕様の変更は必ずレビューを受ける
3. **更新日記載**: 各ドキュメントの`Last Updated`を更新
4. **関連更新**: 変更が他のドキュメントに影響する場合は一緒に更新

### ドキュメント追加時
1. このREADME.mdに追加
2. 適切なカテゴリに分類
3. 簡潔な説明を記載
4. 関連ドキュメントとのリンクを設定

## 🔗 関連リンク

### プロジェクトルール
- [.cursor/guidelines.mdc](../../.cursor/guidelines.mdc) - Cursor AI開発ガイドライン
- [.cursor/rules/](../../.cursor/rules/) - DDDアーキテクチャルール

### サービス別ドキュメント
- [docs/avion-system-admin/](../avion-system-admin/) - システム管理サービス
- [docs/avion-auth/](../avion-auth/) - 認証・認可サービス
- [docs/avion-drop/](../avion-drop/) - 投稿管理サービス

## 📊 ドキュメント構造

```
docs/common/
├── README.md                                    # このファイル
├── architecture/                                # アーキテクチャ関連
│   ├── architecture.md                         # システムアーキテクチャ
│   ├── development-guidelines.md               # 開発ガイドライン
│   ├── go-backend-framework.md                 # Goバックエンド共通技術スタック
│   ├── api-versioning-strategy.md             # APIバージョニング戦略
│   ├── graphql-schema-guidelines.md           # GraphQLスキーマ設計ガイドライン
│   └── validation-package-design.md           # バリデーション共通パッケージ設計
├── infrastructure/                             # インフラストラクチャ・CI/CD関連
│   ├── cicd-migration-strategy.md             # CI/CDマイグレーション戦略
│   ├── environment-variables.md               # 環境変数管理
│   ├── service-mesh-guide.md                  # サービスメッシュ設定ガイド
│   └── disaster-recovery-plan.md             # 障害復旧（DR）計画
├── database/                                   # データベース関連
│   ├── database-migration-strategy.md         # マイグレーション戦略
│   └── goose-configuration-guide.md           # Goose設定ガイド
├── observability/                              # 観測可能性関連
│   └── observability-package-design.md        # Observabilityパッケージ設計
├── errors/                                     # エラー関連
│   ├── error-standards.md                      # エラー標準（日本語）
│   └── error-codes.md                          # エラーコード（英語）
├── domain-service-srp-refactoring.md           # ドメインサービスSRPリファクタリング
└── id-generation-guideline.md                  # ID生成ガイドライン
```

## 🚀 今後の追加予定

- [ ] 認証・認可共通パッケージ設計
- [x] バリデーション共通パッケージ設計
- [ ] キャッシング戦略ガイドライン
- [x] API バージョニング戦略
- [x] サービスメッシュ設定ガイド
- [x] 障害復旧（DR）計画
- [x] GraphQL スキーマ設計ガイドライン

---

**Last Updated:** 2026/03/15
**Maintainer:** Avion Platform Team