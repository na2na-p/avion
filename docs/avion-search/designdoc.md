# Design Doc: avion-search

**Author:** Cline
**Last Updated:** 2026/03/15

## 関連ドキュメント

本 DesignDoc は目的別に分割されています。以下のドキュメントも併せて参照してください。

| ドキュメント | 内容 |
|---|---|
| [designdoc.md](./designdoc.md)（本文書） | 概要、ドメインモデル（Aggregate/Entity/ValueObject）、API定義、アーキテクチャ、決定事項 |
| [designdoc-indexing.md](./designdoc-indexing.md) | インデックス管理、MeiliSearch設定・マッピング、PostgreSQLフォールバック、SearchBackend Interface、クエリ最適化 |
| [designdoc-trending.md](./designdoc-trending.md) | トレンド分析、ハッシュタグ集計、推薦アルゴリズム、ドメインモデル詳細実装 |
| [designdoc-infra-testing.md](./designdoc-infra-testing.md) | インフラ層実装詳細、構造化ログ戦略、エラーハンドリング、テスト戦略、モック設計、E2Eテスト |
| [error-catalog.md](./error-catalog.md) | エラーコード定義一覧 |
| [prd.md](./prd.md) | プロダクト要件定義 |

---

## 1. Summary (これは何？)

- **一言で:** Avionにおける投稿（Drop）やユーザーの検索機能を提供するマイクロサービスを実装します。
- **目的:** 主にMeiliSearchを使用した高速な全文検索を提供し、将来的な拡張性のためにPostgreSQL全文検索（FTS）への切り替えも可能な設計とします。1stリリースではMeiliSearchを実装し、インターフェースレベルでPostgreSQL FTSへの対応も準備します。Drop/Userの変更イベントを購読し、MeiliSearchインデックスを更新します。

## 2. テスト戦略

このサービスでは、[共通テスト戦略](../common/testing-strategy.md)に従ってテストを実装します。

### テスト方針
- **TDD必須**: インターフェース定義 → テスト作成 → 実装の順序を厳守
- **カバレッジ目標**: ユニットテスト85%以上、クリティカルパス95%以上
- **テーブル駆動テスト**: 全テストで必須
- **モック生成**: `go.uber.org/mock/gomock`使用

詳細は[共通テスト戦略ドキュメント](../common/testing-strategy.md)を参照してください。

### 検索サービス特有のテスト要件
- **MeiliSearch統合テスト**: testcontainersを使用した実際のMeiliSearchインスタンスでのテスト
- **検索精度テスト**: 日本語検索クエリの精度と適合率の検証
- **インデックス更新の冪等性テスト**: 同一イベントの重複処理時の整合性確認
- **パフォーマンステスト**: レスポンス時間とスループットの測定
- **アクセス制御テスト**: ユーザー権限に基づく検索結果フィルタリングの検証

### E2Eテスト

このサービスのE2Eテストは、[共通E2Eテスト戦略](../common/e2e-testing-strategy.md)に従って実装します。

#### 主要なE2Eテストシナリオ
- Drop投稿からMeiliSearchインデックス更新までの完全フロー
- 日本語テキスト検索での適合率と再現率の確認
- ハッシュタグ検索機能とリアルタイム更新の確認
- ユーザー検索機能とプロフィール情報連携の確認
- プライバシー設定による検索結果フィルタリング
- 検索クエリのオートコンプリート機能
- 複数条件での詳細検索機能
- 大量データでの検索性能とレスポンス時間測定

詳細は[共通E2Eテスト戦略ドキュメント](../common/e2e-testing-strategy.md)を参照してください。

## 3. 技術スタック

このサービスでは、[共通Goバックエンド技術スタックガイドライン](../common/architecture/go-backend-framework.md)に従った実装を行います。

### 主要技術
- **言語:** Go 1.25.1
- **HTTPルーティング:** Chi v5
- **RPC:** ConnectRPC
- **ミドルウェア:** 標準net/httpベースの共通ミドルウェア
- **検索関連:** MeiliSearch v1.9+（日本語トークナイザー: 内蔵Lindera、IPA辞書ベース）、PostgreSQL FTSフォールバック機能
- **データベース:** PostgreSQL 17
- **キャッシュ:** Redis 8+
- **メッセージング:** NATS JetStream

詳細な実装パターンおよびライブラリの使用方法については、[ガイドライン](../common/architecture/go-backend-framework.md)を参照してください。

## 4. Background & Links (背景と関連リンク)

- ユーザーが必要な情報（Drop、ユーザー）を効率的に発見できるようにするため。
- 検索という専門的な処理を分離し、外部検索エンジン (MeiliSearch) やDB機能を利用するため。
- [PRD: avion-search](./prd.md)
- [Avion アーキテクチャ概要](../common/architecture.md)

## 5. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

#### 基本機能 (Phase 0)
- Drop/User作成・更新・削除イベント (NATS JetStream) を購読。
- イベントに基づき、MeiliSearchにドキュメントを追加・更新・削除する機能の実装 (冪等性確保)。
- MeiliSearchを利用したDrop検索API (gRPC) の実装（1stリリース）。
- MeiliSearchを利用したユーザー検索API (gRPC) の実装（1stリリース）。
- SearchBackend interfaceを定義し、MeiliSearchとPostgreSQL FTSの両方に対応可能な設計（PostgreSQL FTS実装は2ndリリース以降）。
- 検索結果に対するアクセス制御フィルタリング (呼び出し元ユーザーの権限を考慮、MeiliSearchフィルタ優先)。
- 日本語検索に最適化された設定の実装: **MeiliSearch v1.9 内蔵 Lindera**（IPA辞書ベース、Viterbiアルゴリズムによる形態素解析）を使用。Docker設定で `--features japanese` カスタムビルドオプションを指定し、漢字誤検出対策を含む高精度な日本語トークナイゼーションを実現する。
- Go言語で実装し、Kubernetes上でのステートレス運用を前提とする。
- OpenTelemetryによるトレーシング・メトリクス・ロギング対応。

#### 拡張機能 (Phase 1: 高優先度)
- 検索プライバシー制御機能 (GDPR対応、オプトイン/オプトアウト)。
- ハッシュタグ検索機能とトレンディングハッシュタグ表示。
- メンション検索機能 (自分へのメンション/他者へのメンション)。

#### 拡張機能 (Phase 2: 中優先度)
- 検索履歴管理とサジェスト機能。
- 保存検索機能と新着マッチ通知。
- リアクションベース検索。

#### 拡張機能 (Phase 3: 低優先度)
- フェデレーション検索 (リモートインスタンス検索)。
- コレクション内検索 (ブックマーク、リスト等)。

### Non-Goals (やらないこと)

- **検索エンジン/DB自体の運用:** MeiliSearch/PostgreSQLの運用は対象外。
- **データの永続化:** 本サービスはステートレス。インデックスはMeiliSearch、元データはPostgreSQLが保持。
- **リアルタイムインデックス (厳密な意味で):** MeiliSearchへの反映遅延は許容。完全なリアルタイム整合性は保証しない。ただし、**インデックス反映SLO: 投稿から検索可能になるまで5秒以内**を目標とする。
- **複雑な検索構文 (初期):** AND/OR/NOT等の高度な検索演算子は初期段階では実装しない。
- **検索結果のパーソナライズ (初期):** ユーザーの嗜好に基づくランキング調整は行わない。
- **E2E暗号化メッセージの本文検索:** E2E暗号化メッセージはサーバー側で復号不可のため、本サービスのスコープ外。クライアントサイドインデックスにより実行される。非暗号化メタデータ（送信者名、タイムスタンプ等）の検索のみ本サービスが担当する。

> **サービス間責務境界（決定済み）**:
>
> - **検索の一元管理**: avion-search はAvionプラットフォームにおける検索インフラの中央管理サービスである。MeiliSearch および PostgreSQL FTS を用いた全文検索機能を一元的に提供する。各サービスはインデックス更新イベントを NATS JetStream 経由で発行し、検索クエリの実行は avion-search の gRPC API を呼び出す形で統一する。
> - **テキスト解析**: テキスト解析（ハッシュタグ・メンション抽出・正規化）ロジックはGo共有パッケージ（`pkg/textanalysis`）として切り出す。本サービスの `HashtagExtractor` / `MentionExtractor` と `avion-drop` の `extractHashtags()` / `extractMentions()` は共に共有パッケージの呼び出しに置き換える。
> - **トレンドハッシュタグ集計**: 本サービスの `GetTrendingHashtagsQueryUseCase` が正。`avion-drop` の `GetTrendingHashtagsQueryHandler` は廃止。
> - **avion-message との検索責務境界**: E2E暗号化メッセージの本文検索はサーバー側で復号不可のため、本サービスのスコープ外とする。E2E暗号化メッセージの検索はクライアントサイドインデックスにより実行される。非暗号化メタデータ（送信者名、日時、会話名、添付ファイル種類等）の検索インデックス管理は本サービスに委譲する。avion-message はメッセージ本文を本サービスに送信しない。

## 5-1. セキュリティ実装ガイドライン

avion-searchサービスでは、以下のセキュリティガイドラインに従って実装を行います：

### 必須セキュリティ実装

1. **SQLインジェクション防止** ([SQL Injection Prevention](../common/security/sql-injection-prevention.md))
   - 検索クエリでの Prepared Statements 使用
   - PostgreSQL FTS での安全な tsquery 構築
   - MeiliSearch への安全なクエリパラメータ渡し
   - 特殊文字のエスケープ処理

2. **XSS防止** ([XSS Prevention Guidelines](../common/security/xss-prevention.md))
   - 検索結果のHTMLエスケープ
   - ハイライト表示での安全な処理
   - 検索サジェストのサニタイゼーション
   - JSON出力のエンコーディング

### セキュリティガイドライン参照

- [XSS対策](../common/security/xss-prevention.md)
- [SQLインジェクション対策](../common/security/sql-injection-prevention.md)
- [TLS設定](../common/security/tls-configuration.md)

### セキュリティ実装チェックリスト

- [ ] 検索クエリのSQLインジェクション対策
- [ ] 検索結果表示でのXSS対策
- [ ] MeiliSearchクエリの入力検証
- [ ] PostgreSQL FTSクエリの安全な構築
- [ ] 検索履歴の適切な匿名化
- [ ] アクセス制御の実装

## 6. Architecture (どうやって作る？)

### 6.1. レイヤードアーキテクチャ (DDD準拠)

#### Domain Layer (ドメイン層)
- **Aggregates:**
  - SearchIndex: 検索インデックスのライフサイクルと整合性を管理
  - IndexOperation: インデックス操作のトランザクション境界を管理
  - HashtagIndex (新規): ハッシュタグごとの検索インデックスを管理
  - SearchHistory (新規): ユーザーごとの検索履歴を管理
- **Entities:**
  - DropSearchDocument: Drop検索ドキュメント (Hashtags, Mentions追加)
  - UserSearchDocument: User検索ドキュメント (SearchPrivacySettings追加)
  - ProcessedEvent: 処理済みイベントの記録
  - SavedSearch (新規): 保存された検索条件
  - MentionIndex (新規): メンション関係のインデックス
- **Value Objects:**
  - SearchQuery, SearchResult, EventID, IndexType, Visibility等
  - SearchFilter: 検索フィルタ条件
  - SearchableText: 検索対象テキスト
  - RelevanceScore: 関連性スコア
  - SearchableContentSettings (新規): 検索可能性設定
  - Hashtag (新規): 正規化されたハッシュタグ
  - TrendingScore (新規): トレンド度
  - SearchName (新規): 保存検索の名前
  - MentionContext (新規): メンション周辺のコンテキスト
- **Domain Services:**
  - **SearchPolicy**: 検索のビジネスルールを実装するドメインサービス
    - 責務: 検索クエリの妥当性検証、検索戦略の決定、検索結果のフィルタリング
    - メソッド:
      ```go
      type SearchPolicy interface {
          ValidateSearchQuery(query SearchQuery) error
          DetermineSearchStrategy(query SearchQuery, indexType IndexType) SearchStrategy
          ApplyBusinessRules(results []SearchResult, userContext UserContext) []SearchResult
          CalculateRelevanceBoost(doc SearchDocument, query SearchQuery) float64
      }
      ```
  - **AccessControlPolicy**: アクセス制御ルールを実装するドメインサービス
    - 責務: ユーザーの権限に基づく検索結果のフィルタリング、検索可能範囲の決定
    - メソッド:
      ```go
      type AccessControlPolicy interface {
          DetermineSearchableScope(userID UserID, searchType SearchType) SearchScope
          CreateAccessFilter(userID UserID, visibility []Visibility) SearchFilter
          CanUserSearchContent(userID UserID, content SearchableContent) bool
          FilterSearchResults(results []SearchResult, userID UserID) []SearchResult
      }
      ```
  - **DocumentFactory**: 検索ドキュメント生成ロジックを実装するドメインサービス
    - 責務: エンティティから検索ドキュメントへの変換、検索可能フィールドの抽出
    - メソッド:
      ```go
      type DocumentFactory interface {
          CreateDropSearchDocument(drop Drop, author User) (DropSearchDocument, error)
          CreateUserSearchDocument(user User, privacy SearchPrivacySettings) (UserSearchDocument, error)
          ExtractSearchableFields(entity interface{}) map[string]interface{}
          NormalizeSearchableText(text string, language Language) SearchableText
      }
      ```
  - **SearchPrivacyPolicy** (新規): 検索プライバシーポリシーを実装するドメインサービス
    - 責務: GDPR準拠の検索プライバシー制御、オプトイン/オプトアウト管理
    - メソッド:
      ```go
      type SearchPrivacyPolicy interface {
          ValidatePrivacySettings(settings SearchPrivacySettings) error
          DetermineSearchability(user User, settings SearchPrivacySettings) Searchability
          ApplyPrivacyRules(documents []SearchDocument, privacySettings map[UserID]SearchPrivacySettings) []SearchDocument
          GeneratePrivacyCompliantDocument(original SearchDocument, settings SearchPrivacySettings) SearchDocument
      }
      ```
  - **HashtagExtractor** (新規): ハッシュタグ抽出を実装するドメインサービス
    - 責務: テキストからのハッシュタグ抽出、正規化、バリデーション
    - メソッド:
      ```go
      type HashtagExtractor interface {
          ExtractHashtags(text SearchableText) []Hashtag
          NormalizeHashtag(hashtag string) (Hashtag, error)
          ValidateHashtag(hashtag Hashtag) error
          ExtractHashtagContext(text SearchableText, hashtag Hashtag) HashtagContext
      }
      ```
  - **TrendingCalculator** (新規): トレンドスコア計算を実装するドメインサービス
    - 責務: ハッシュタグやコンテンツのトレンド度計算、ランキング生成
    - メソッド:
      ```go
      type TrendingCalculator interface {
          CalculateTrendingScore(hashtag Hashtag, metrics TrendingMetrics) TrendingScore
          GenerateTrendingRanking(scores map[Hashtag]TrendingScore, limit int) []TrendingItem
          DecayTrendingScore(currentScore TrendingScore, timeSinceLastUse time.Duration) TrendingScore
          AdjustScoreByVelocity(baseScore TrendingScore, usageVelocity float64) TrendingScore
      }
      ```
  - **MentionExtractor** (新規): メンション抽出を実装するドメインサービス
    - 責務: テキストからのメンション抽出、バリデーション、コンテキスト解析
    - メソッド:
      ```go
      type MentionExtractor interface {
          ExtractMentions(text SearchableText) []Mention
          ValidateMention(mention string) (Mention, error)
          ExtractMentionContext(text SearchableText, mention Mention) MentionContext
          ClassifyMentionType(mention Mention, text SearchableText) MentionType
      }
      ```
  - **RankingAlgorithm**: 検索結果のランキングアルゴリズムを実装するドメインサービス
    - 責務: 検索結果の関連性スコアリング、ランキング最適化
    - メソッド:
      ```go
      type RankingAlgorithm interface {
          CalculateRelevanceScore(doc SearchDocument, query SearchQuery) RelevanceScore
          ApplyTemporalDecay(score RelevanceScore, age time.Duration) RelevanceScore
          CombineScores(textScore, socialScore, temporalScore float64) RelevanceScore
          OptimizeRanking(results []SearchResult, userPreferences UserPreferences) []SearchResult
      }
      ```
- **Repository Interfaces:**
  - SearchIndexRepository: SearchIndex集約の永続化インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_search_index_repository.go -package=mocks
    ```
  - IndexOperationRepository: IndexOperation集約の永続化インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_index_operation_repository.go -package=mocks
    ```
  - EventRepository: ProcessedEventエンティティの永続化インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_event_repository.go -package=mocks
    ```
  - SearchQueryRepository: 検索クエリ履歴の永続化インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_search_query_repository.go -package=mocks
    ```
  - HashtagIndexRepository (新規): HashtagIndex集約の永続化インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_hashtag_index_repository.go -package=mocks
    ```
  - SearchHistoryRepository (新規): SearchHistory集約の永続化インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_search_history_repository.go -package=mocks
    ```
  - SavedSearchRepository (新規): SavedSearchエンティティの永続化インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_saved_search_repository.go -package=mocks
    ```

#### Use Case Layer (ユースケース層)
- **Command Use Cases (更新系):**
  - IndexDropDocumentCommandUseCase: Dropドキュメントのインデックス処理（イベントハンドラ用）
  - IndexUserDocumentCommandUseCase: Userドキュメントのインデックス処理（イベントハンドラ用）
  - ProcessIndexEventCommandUseCase: インデックスイベント処理（イベントハンドラ用）
  - RebuildIndexCommandUseCase: インデックス再構築処理（POSTリクエスト用）
  - UpdateSearchPrivacyCommandUseCase (新規): 検索プライバシー設定更新
  - SaveSearchCommandUseCase (新規): 検索条件保存
  - DeleteSavedSearchCommandUseCase (新規): 保存検索削除
  - RequestRemoteSearchCommandUseCase (新規): リモート検索要求
- **Query Use Cases (参照系):**
  - SearchDropsQueryUseCase: Drop検索処理（GETリクエスト用）
  - SearchUsersQueryUseCase: User検索処理（GETリクエスト用）
  - GetIndexStatusQueryUseCase: インデックス状態取得処理（GETリクエスト用）
  - SearchByHashtagQueryUseCase (新規): ハッシュタグ検索
  - SearchMentionsQueryUseCase (新規): メンション検索
  - GetSearchHistoryQueryUseCase (新規): 検索履歴取得
  - GetSavedSearchesQueryUseCase (新規): 保存検索一覧取得
  - GetTrendingHashtagsQueryUseCase (新規): トレンディングハッシュタグ取得
  - SearchInCollectionQueryUseCase (新規): コレクション内検索
- **Query Service Interfaces:**
  - DropSearchQueryService: Drop検索参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_drop_search_query_service.go -package=mocks
    ```
  - UserSearchQueryService: User検索参照専用インターフェース
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_user_search_query_service.go -package=mocks
    ```
  - HashtagSearchQueryService (新規): ハッシュタグ検索参照専用
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_hashtag_search_query_service.go -package=mocks
    ```
  - SearchHistoryQueryService (新規): 検索履歴参照専用
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_search_history_query_service.go -package=mocks
    ```
- **DTOs:**
  - SearchRequest, SearchResponse, IndexEvent等
  - HashtagSearchRequest, HashtagSearchResponse (新規)
  - SearchHistoryResponse, SavedSearchResponse (新規)
  - SearchPrivacyUpdateRequest (新規)
- **External Service Interfaces:**
  - DropServiceClient: avion-dropとの連携
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_drop_service_client.go -package=mocks
    ```
  - UserServiceClient: avion-userとの連携
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_user_service_client.go -package=mocks
    ```
  - RemoteSearchClient (新規): リモートインスタンス検索連携
    ```go
    //go:generate mockgen -source=$GOFILE -destination=../../../tests/mocks/mock_remote_search_client.go -package=mocks
    ```

#### Infrastructure Layer (インフラストラクチャ層)

- **Repository Implementations (更新系):**
  - SearchIndexRepository: SearchIndex集約の永続化実装 (GORMを使用)
  - IndexOperationRepository: IndexOperation集約の永続化実装 (GORMを使用)
  - HashtagIndexRepository: HashtagIndex集約の永続化実装 (GORMを使用)
  - SearchHistoryRepository: SearchHistory集約の永続化実装 (GORMを使用)
  - SavedSearchRepository: SavedSearchエンティティの永続化実装 (GORMを使用)
  - EventRepository: ProcessedEventエンティティの永続化実装 (GORMを使用)

- **DAOs (Data Access Objects):**
  - SearchIndexDAO: search_indexesテーブルとのマッピング用struct
  - IndexOperationDAO: index_operationsテーブルとのマッピング用struct
  - HashtagIndexDAO: hashtag_indexesテーブルとのマッピング用struct
  - SearchHistoryDAO: search_historiesテーブルとのマッピング用struct
  - SavedSearchDAO: saved_searchesテーブルとのマッピング用struct
  - ProcessedEventDAO: processed_eventsテーブルとのマッピング用struct

- **Query Service Implementations (参照系):**
  - DropSearchQueryService: Drop検索参照実装 (GORMを使用)
  - UserSearchQueryService: User検索参照実装 (GORMを使用)
  - HashtagSearchQueryService: ハッシュタグ検索参照実装 (GORMを使用)
  - SearchHistoryQueryService: 検索履歴参照実装 (GORMを使用)

- **External Service Implementations:**
  - GRPCDropServiceClient: avion-dropサービスとのgRPC連携実装
  - GRPCUserServiceClient: avion-userサービスとのgRPC連携実装（ユーザー情報取得）
  - RemoteSearchClient: リモートインスタンス検索連携実装
  - MeiliSearchAdapter: MeiliSearch検索エンジン連携実装
  - PostgreSQLFTSAdapter: PostgreSQL全文検索連携実装
  - NATSJetStreamConsumer: NATS JetStream購読実装
  - EventPublisher: NATS JetStreamイベント発行実装

#### Handler Layer (ハンドラー層)

- **gRPC Handlers:**
  - AvionSearchServiceHandler: avion-search gRPCサービス実装
    - SearchDrops: Drop検索処理
    - SearchUsers: ユーザー検索処理
    - GetIndexStatus: インデックス状態取得処理
    - RebuildIndex: インデックス再構築処理
    - SearchByHashtag: ハッシュタグ検索処理
    - SearchMentions: メンション検索処理
    - GetSearchHistory: 検索履歴取得処理
    - GetSavedSearches: 保存検索一覧取得処理
    - SaveSearch: 検索条件保存処理
    - DeleteSavedSearch: 保存検索削除処理
    - UpdateSearchPrivacy: 検索プライバシー設定更新処理
    - GetTrendingHashtags: トレンディングハッシュタグ取得処理
  - EventConsumerHandler: NATS JetStreamイベント購読ハンドラー
    - ProcessDropEvent: Drop関連イベント処理
    - ProcessUserEvent: ユーザー関連イベント処理
    - ProcessPrivacyEvent: プライバシー設定変更イベント処理

### 6.2. CQRSパターン実装詳細

#### Command側（コマンド側）の責務と実装

**責務**: データの変更操作とビジネスロジックの実行、イベントの発行

##### コマンドハンドラー実装
```go
// internal/usecase/command/index_drop_document.go
type IndexDropDocumentCommand struct {
    DropID      string
    AuthorID    string
    Content     string
    Visibility  string
    Hashtags    []string
    Mentions    []string
    MediaURLs   []string
    CreatedAt   time.Time
    EventID     string // 冪等性保証用
}

type IndexDropDocumentCommandHandler struct {
    searchIndexRepo    domain.SearchIndexRepository
    eventRepo         domain.EventRepository
    searchBackend     infrastructure.SearchBackend
    eventPublisher    infrastructure.EventPublisher
    documentFactory   domain.DocumentFactory
    hashtagExtractor  domain.HashtagExtractor
    mentionExtractor  domain.MentionExtractor
    logger           *slog.Logger
}

func (h *IndexDropDocumentCommandHandler) Handle(ctx context.Context, cmd IndexDropDocumentCommand) error {
    // 1. 冪等性チェック（イベントソーシング）
    processed, err := h.eventRepo.IsEventProcessed(ctx, cmd.EventID)
    if err != nil {
        return fmt.Errorf("failed to check event processing: %w", err)
    }
    if processed {
        h.logger.Info("Event already processed", "event_id", cmd.EventID)
        return nil // 冪等性保証
    }

    // 2. ドメインオブジェクト生成
    drop := domain.NewDrop(cmd.DropID, cmd.AuthorID, cmd.Content, cmd.Visibility)

    // 3. ハッシュタグ・メンション抽出（ドメインサービス利用）
    searchableText := domain.NewSearchableText(cmd.Content)
    hashtags := h.hashtagExtractor.ExtractHashtags(searchableText)
    mentions := h.mentionExtractor.ExtractMentions(searchableText)

    // 4. 検索ドキュメント生成（ドメインサービス利用）
    doc, err := h.documentFactory.CreateDropSearchDocument(drop, hashtags, mentions)
    if err != nil {
        return fmt.Errorf("failed to create search document: %w", err)
    }

    // 5. トランザクション開始
    tx := h.searchIndexRepo.BeginTransaction(ctx)
    defer tx.Rollback()

    // 6. SearchIndex集約の更新
    searchIndex := domain.NewSearchIndex(domain.IndexTypeDrop)
    operation := searchIndex.AddDocument(doc)

    if err := h.searchIndexRepo.Save(ctx, tx, searchIndex); err != nil {
        return fmt.Errorf("failed to save search index: %w", err)
    }

    // 7. 検索バックエンド更新
    if err := h.searchBackend.IndexDocument(ctx, doc); err != nil {
        return fmt.Errorf("failed to index document in search backend: %w", err)
    }

    // 8. イベント処理記録（イベントソーシング）
    event := domain.NewProcessedEvent(cmd.EventID, "IndexDropDocument", cmd)
    if err := h.eventRepo.RecordProcessedEvent(ctx, tx, event); err != nil {
        return fmt.Errorf("failed to record processed event: %w", err)
    }

    // 9. ドメインイベント発行
    indexedEvent := domain.NewDropIndexedEvent(cmd.DropID, doc.ID, time.Now())
    if err := h.eventPublisher.Publish(ctx, indexedEvent); err != nil {
        // イベント発行失敗は警告のみ（最終的整合性）
        h.logger.Warn("Failed to publish indexed event", "error", err)
    }

    // 10. トランザクションコミット
    if err := tx.Commit(); err != nil {
        return fmt.Errorf("failed to commit transaction: %w", err)
    }

    h.logger.Info("Successfully indexed drop document",
        "drop_id", cmd.DropID,
        "event_id", cmd.EventID,
        "hashtags", len(hashtags),
        "mentions", len(mentions))

    return nil
}
```

##### コマンドバス実装
```go
// internal/usecase/command/command_bus.go
type CommandBus struct {
    handlers map[reflect.Type]CommandHandler
    logger   *slog.Logger
}

func (b *CommandBus) Register(cmdType interface{}, handler CommandHandler) {
    b.handlers[reflect.TypeOf(cmdType)] = handler
}

func (b *CommandBus) Dispatch(ctx context.Context, cmd interface{}) error {
    handler, exists := b.handlers[reflect.TypeOf(cmd)]
    if !exists {
        return fmt.Errorf("no handler registered for command type: %T", cmd)
    }

    // OpenTelemetryトレーシング
    span := trace.SpanFromContext(ctx)
    span.SetAttributes(
        attribute.String("command.type", fmt.Sprintf("%T", cmd)),
    )

    return handler.Handle(ctx, cmd)
}
```

#### Query側（クエリ側）の責務と実装

**責務**: データの参照操作に特化、高速な読み取り専用モデルの提供

##### クエリハンドラー実装
```go
// internal/usecase/query/search_drops.go
type SearchDropsQuery struct {
    UserID      string
    Query       string
    Filters     SearchFilters
    Pagination  PaginationParams
    SortBy      SortOption
}

type SearchDropsQueryHandler struct {
    queryService      infrastructure.DropSearchQueryService
    accessPolicy      domain.AccessControlPolicy
    rankingAlgorithm  domain.RankingAlgorithm
    cache            infrastructure.CacheService
    logger           *slog.Logger
}

func (h *SearchDropsQueryHandler) Handle(ctx context.Context, query SearchDropsQuery) (*SearchDropsResult, error) {
    // 1. キャッシュチェック（読み取り最適化）
    cacheKey := h.generateCacheKey(query)
    if cached, found := h.cache.Get(ctx, cacheKey); found {
        h.logger.Debug("Cache hit", "key", cacheKey)
        return cached.(*SearchDropsResult), nil
    }

    // 2. アクセス制御フィルタ生成
    accessFilter := h.accessPolicy.CreateAccessFilter(query.UserID, []string{"public", "unlisted"})

    // 3. 検索クエリ構築
    searchQuery := infrastructure.SearchQuery{
        Text:    query.Query,
        Filters: h.mergeFilters(query.Filters, accessFilter),
        Limit:   query.Pagination.Limit,
        Offset:  query.Pagination.Offset,
        Sort:    query.SortBy,
    }

    // 4. クエリサービス実行（読み取り専用）
    results, err := h.queryService.SearchDrops(ctx, searchQuery)
    if err != nil {
        return nil, fmt.Errorf("failed to search drops: %w", err)
    }

    // 5. ランキング最適化
    rankedResults := h.rankingAlgorithm.OptimizeRanking(results, query.UserID)

    // 6. レスポンス構築
    response := &SearchDropsResult{
        Drops:      rankedResults,
        TotalCount: len(results),
        Query:      query.Query,
        Filters:    query.Filters,
    }

    // 7. キャッシュ更新（TTL: 5分）
    h.cache.Set(ctx, cacheKey, response, 5*time.Minute)

    h.logger.Info("Search completed",
        "query", query.Query,
        "results", len(rankedResults),
        "user_id", query.UserID)

    return response, nil
}
```

##### 読み取りモデル投影（Projection）
```go
// internal/infrastructure/projection/drop_search_projection.go
type DropSearchProjection struct {
    db            *gorm.DB
    searchBackend SearchBackend
    logger        *slog.Logger
}

// イベントハンドラー（イベントソーシングからの投影）
func (p *DropSearchProjection) OnDropCreated(event DropCreatedEvent) error {
    // 読み取り専用モデルの更新
    model := &DropSearchModel{
        ID:         event.DropID,
        AuthorID:   event.AuthorID,
        Content:    event.Content,
        Hashtags:   event.Hashtags,
        Mentions:   event.Mentions,
        CreatedAt:  event.CreatedAt,
        UpdatedAt:  event.CreatedAt,
    }

    // 非正規化データの保存（読み取り最適化）
    if err := p.db.Create(model).Error; err != nil {
        return fmt.Errorf("failed to create projection: %w", err)
    }

    // 検索インデックス更新
    return p.searchBackend.IndexDocument(context.Background(), model.ToSearchDocument())
}

func (p *DropSearchProjection) OnDropUpdated(event DropUpdatedEvent) error {
    // 読み取りモデルの更新
    updates := map[string]interface{}{
        "content":    event.NewContent,
        "updated_at": event.UpdatedAt,
    }

    if err := p.db.Model(&DropSearchModel{}).
        Where("id = ?", event.DropID).
        Updates(updates).Error; err != nil {
        return fmt.Errorf("failed to update projection: %w", err)
    }

    // 検索インデックス更新
    return p.searchBackend.UpdateDocument(context.Background(), event.DropID, updates)
}
```

### 6.3. イベントソーシング実装詳細

#### イベントストア実装
```go
// internal/domain/event/event_store.go
type EventStore interface {
    // イベントの永続化
    Append(ctx context.Context, streamID string, events []Event) error
    // イベントストリームの読み取り
    Load(ctx context.Context, streamID string, fromVersion int) ([]Event, error)
    // スナップショット保存
    SaveSnapshot(ctx context.Context, aggregateID string, snapshot Snapshot) error
    // スナップショット取得
    GetSnapshot(ctx context.Context, aggregateID string) (*Snapshot, error)
}

type Event struct {
    ID            string
    StreamID      string
    Type          string
    Version       int
    Payload       json.RawMessage
    Metadata      EventMetadata
    OccurredAt    time.Time
}

type EventMetadata struct {
    UserID       string
    CorrelationID string
    CausationID   string
    TraceID       string
}
```

#### イベントソーシング集約実装
```go
// internal/domain/aggregate/search_index_aggregate.go
type SearchIndexAggregate struct {
    ID              string
    Version         int
    IndexType       IndexType
    Documents       map[string]SearchDocument
    LastUpdated     time.Time
    uncommittedEvents []domain.Event
}

// イベントソーシング: イベントから状態を再構築
func (a *SearchIndexAggregate) LoadFromHistory(events []domain.Event) error {
    for _, event := range events {
        if err := a.Apply(event); err != nil {
            return fmt.Errorf("failed to apply event: %w", err)
        }
    }
    return nil
}

// コマンド処理: ビジネスロジック実行とイベント生成
func (a *SearchIndexAggregate) AddDocument(doc SearchDocument) error {
    // ビジネスルール検証
    if err := a.validateDocument(doc); err != nil {
        return fmt.Errorf("invalid document: %w", err)
    }

    // イベント生成
    event := DocumentAddedEvent{
        AggregateID: a.ID,
        DocumentID:  doc.ID,
        Document:    doc,
        AddedAt:     time.Now(),
    }

    // イベント適用
    a.Apply(event)
    a.uncommittedEvents = append(a.uncommittedEvents, event)

    return nil
}

// イベント適用: 状態変更
func (a *SearchIndexAggregate) Apply(event domain.Event) error {
    switch e := event.(type) {
    case DocumentAddedEvent:
        a.Documents[e.DocumentID] = e.Document
        a.LastUpdated = e.AddedAt
        a.Version++

    case DocumentUpdatedEvent:
        if doc, exists := a.Documents[e.DocumentID]; exists {
            // 既存ドキュメントの更新
            doc.UpdateContent(e.NewContent)
            doc.UpdatedAt = e.UpdatedAt
            a.Documents[e.DocumentID] = doc
            a.LastUpdated = e.UpdatedAt
            a.Version++
        }

    case DocumentDeletedEvent:
        delete(a.Documents, e.DocumentID)
        a.LastUpdated = e.DeletedAt
        a.Version++

    default:
        return fmt.Errorf("unknown event type: %T", e)
    }

    return nil
}

// スナップショット生成
func (a *SearchIndexAggregate) CreateSnapshot() Snapshot {
    return Snapshot{
        AggregateID: a.ID,
        Version:    a.Version,
        State:      a.toSnapshotState(),
        CreatedAt:  time.Now(),
    }
}
```

#### イベントプロジェクション管理
```go
// internal/infrastructure/projection/projection_manager.go
type ProjectionManager struct {
    eventStore    domain.EventStore
    projections   []Projection
    checkpointer  Checkpointer
    logger        *slog.Logger
}

func (m *ProjectionManager) Start(ctx context.Context) error {
    // 各プロジェクションの最終処理位置を取得
    for _, projection := range m.projections {
        checkpoint, err := m.checkpointer.GetCheckpoint(projection.Name())
        if err != nil {
            return fmt.Errorf("failed to get checkpoint: %w", err)
        }

        // イベントストリームの購読開始
        go m.processEvents(ctx, projection, checkpoint)
    }

    return nil
}

func (m *ProjectionManager) processEvents(ctx context.Context, projection Projection, fromPosition int64) {
    stream := m.eventStore.Subscribe(ctx, fromPosition)

    for {
        select {
        case event := <-stream:
            // プロジェクション更新
            if err := projection.Handle(event); err != nil {
                m.logger.Error("Failed to handle event", "error", err)
                continue
            }

            // チェックポイント更新
            if err := m.checkpointer.SaveCheckpoint(projection.Name(), event.Position); err != nil {
                m.logger.Error("Failed to save checkpoint", "error", err)
            }

        case <-ctx.Done():
            return
        }
    }
}
```

#### イベント再生とリビルド
```go
// internal/usecase/command/rebuild_projection.go
type RebuildProjectionCommandHandler struct {
    eventStore      domain.EventStore
    projectionRepo  infrastructure.ProjectionRepository
    searchBackend   infrastructure.SearchBackend
    logger          *slog.Logger
}

func (h *RebuildProjectionCommandHandler) Handle(ctx context.Context, cmd RebuildProjectionCommand) error {
    h.logger.Info("Starting projection rebuild", "projection", cmd.ProjectionName)

    // 1. 既存プロジェクションをクリア
    if err := h.projectionRepo.Clear(ctx, cmd.ProjectionName); err != nil {
        return fmt.Errorf("failed to clear projection: %w", err)
    }

    // 2. 全イベントを取得
    events, err := h.eventStore.LoadAllEvents(ctx, cmd.FromTimestamp)
    if err != nil {
        return fmt.Errorf("failed to load events: %w", err)
    }

    // 3. バッチ処理でイベント再生
    const batchSize = 1000
    for i := 0; i < len(events); i += batchSize {
        end := i + batchSize
        if end > len(events) {
            end = len(events)
        }

        batch := events[i:end]
        if err := h.processBatch(ctx, batch); err != nil {
            return fmt.Errorf("failed to process batch: %w", err)
        }

        h.logger.Info("Processed batch",
            "from", i,
            "to", end,
            "total", len(events))
    }

    // 4. 検索インデックス最適化
    if err := h.searchBackend.Optimize(ctx); err != nil {
        return fmt.Errorf("failed to optimize search index: %w", err)
    }

    h.logger.Info("Projection rebuild completed",
        "projection", cmd.ProjectionName,
        "events_processed", len(events))

    return nil
}
```

### 6.4. イベント駆動アーキテクチャ詳細

#### イベント駆動での検索インデックス更新

##### イベントフロー全体像
```
[avion-drop/avion-user] → [NATS JetStream] → [avion-search Consumer] → [MeiliSearch/PostgreSQL]
                                ↓
                          [Event Store]
                                ↓
                          [Projections]
```

##### NATS JetStreamベースのイベント配信
```go
// internal/infrastructure/event/nats_jetstream_consumer.go
type NATSJetStreamConsumer struct {
    conn            *nats.Conn
    js              nats.JetStreamContext
    consumerName    string
    commandBus      *usecase.CommandBus
    eventMapper     EventMapper
    logger          *slog.Logger
}

func (c *NATSJetStreamConsumer) Start(ctx context.Context) error {
    subjects := []string{
        "avion.drop.>",
        "avion.user.>",
    }

    for _, subject := range subjects {
        // Durable Consumer作成（冪等）
        c.createDurableConsumer(subject)

        // サブスクリプション開始
        go c.consumeSubject(ctx, subject)
    }

    return nil
}

func (c *NATSJetStreamConsumer) consumeSubject(ctx context.Context, subject string) {
    sub, err := c.js.PullSubscribe(subject, c.consumerName,
        nats.AckExplicit(),
        nats.MaxDeliver(3),
    )
    if err != nil {
        c.logger.Error("Failed to subscribe", "subject", subject, "error", err)
        return
    }

    for {
        select {
        case <-ctx.Done():
            return
        default:
            msgs, err := sub.Fetch(10, nats.MaxWait(5*time.Second))
            if err != nil {
                if !errors.Is(err, nats.ErrTimeout) {
                    c.logger.Error("Failed to fetch messages", "error", err)
                }
                continue
            }

            for _, msg := range msgs {
                c.processMessage(ctx, subject, msg)
            }
        }
    }
}

func (c *NATSJetStreamConsumer) processMessage(ctx context.Context, subject string, msg *nats.Msg) {
    // スパン作成（分散トレーシング）
    ctx, span := otel.Tracer("search").Start(ctx, "process_event",
        trace.WithAttributes(
            attribute.String("subject", subject),
        ))
    defer span.End()

    // イベントマッピング
    event, err := c.eventMapper.MapFromNATSMessage(msg)
    if err != nil {
        c.handleError(ctx, subject, msg, err)
        return
    }

    // コマンド生成と実行
    cmd := c.createCommand(event)
    if err := c.commandBus.Dispatch(ctx, cmd); err != nil {
        c.handleError(ctx, subject, msg, err)
        return
    }

    // ACK送信
    if err := msg.Ack(); err != nil {
        c.logger.Error("Failed to ack message", "error", err)
    }
}

func (c *NATSJetStreamConsumer) handleError(ctx context.Context, subject string, msg *nats.Msg, err error) {
    c.logger.Error("Failed to process message",
        "subject", subject,
        "error", err)

    // MaxDeliver超過時はNATS JetStreamが自動的にDLQへ移動
    // Nak送信でリトライを要求
    if nakErr := msg.Nak(); nakErr != nil {
        c.logger.Error("Failed to nak message", "error", nakErr)
    }
}
```

##### イベントタイプと処理マッピング
```go
// internal/domain/event/event_types.go
type EventType string

const (
    // Drop関連イベント
    DropCreated   EventType = "avion.drop.drop.created"
    DropUpdated   EventType = "avion.drop.drop.updated"
    DropDeleted   EventType = "avion.drop.drop.deleted"
    DropReacted   EventType = "avion.drop.reaction.created"

    // User関連イベント
    UserCreated   EventType = "avion.user.profile.created"
    UserUpdated   EventType = "avion.user.profile.updated"
    UserDeleted   EventType = "avion.user.profile.deleted"
    UserBlocked   EventType = "avion.user.block.created"

    // Hashtag関連イベント
    HashtagCreated EventType = "avion.drop.hashtag.created"
    HashtagTrending EventType = "avion.drop.hashtag.trending"
)

// イベント基底構造
type BaseEvent struct {
    ID            string          `json:"id"`
    Type          EventType       `json:"type"`
    AggregateID   string          `json:"aggregate_id"`
    AggregateType string          `json:"aggregate_type"`
    Version       int             `json:"version"`
    OccurredAt    time.Time       `json:"occurred_at"`
    Metadata      EventMetadata   `json:"metadata"`
}

// Drop作成イベント
type DropCreatedEvent struct {
    BaseEvent
    DropID     string   `json:"drop_id"`
    AuthorID   string   `json:"author_id"`
    Content    string   `json:"content"`
    Hashtags   []string `json:"hashtags"`
    Mentions   []string `json:"mentions"`
    MediaURLs  []string `json:"media_urls"`
    Visibility string   `json:"visibility"`
}
```

##### イベントハンドラー登録と処理
```go
// internal/handler/event/event_handler_registry.go
type EventHandlerRegistry struct {
    handlers map[EventType][]EventHandler
    logger   *slog.Logger
}

func NewEventHandlerRegistry() *EventHandlerRegistry {
    registry := &EventHandlerRegistry{
        handlers: make(map[EventType][]EventHandler),
    }

    // ハンドラー登録
    registry.registerHandlers()

    return registry
}

func (r *EventHandlerRegistry) registerHandlers() {
    // Drop作成イベントハンドラー
    r.Register(DropCreated,
        &IndexDropHandler{},
        &UpdateHashtagIndexHandler{},
        &ExtractMentionsHandler{},
    )

    // Drop更新イベントハンドラー
    r.Register(DropUpdated,
        &UpdateDropIndexHandler{},
        &RecalculateHashtagsHandler{},
    )

    // User更新イベントハンドラー
    r.Register(UserUpdated,
        &UpdateUserIndexHandler{},
        &PropagateUserChangeHandler{},
    )

    // Privacy更新イベントハンドラー
    r.Register(PrivacyUpdated,
        &UpdateSearchabilityHandler{},
        &RemoveFromPublicIndexHandler{},
    )
}

func (r *EventHandlerRegistry) Handle(ctx context.Context, event Event) error {
    handlers, exists := r.handlers[event.Type()]
    if !exists {
        r.logger.Warn("No handlers registered for event type", "type", event.Type())
        return nil
    }

    // 並列実行用のエラーグループ
    g, ctx := errgroup.WithContext(ctx)

    for _, handler := range handlers {
        h := handler // キャプチャ
        g.Go(func() error {
            return h.Handle(ctx, event)
        })
    }

    return g.Wait()
}
```

##### 冪等性保証メカニズム
```go
// internal/infrastructure/event/idempotency_manager.go
type IdempotencyManager struct {
    cache  *redis.Client
    db     *gorm.DB
    logger *slog.Logger
}

func (m *IdempotencyManager) EnsureIdempotent(ctx context.Context, eventID string, fn func() error) error {
    // 1. 分散ロック取得
    lockKey := fmt.Sprintf("event:lock:%s", eventID)
    lock := m.cache.SetNX(ctx, lockKey, "locked", 10*time.Second)
    if !lock.Val() {
        m.logger.Debug("Event processing already in progress", "event_id", eventID)
        return ErrEventInProgress
    }
    defer m.cache.Del(ctx, lockKey)

    // 2. 処理済みチェック（キャッシュ）
    processedKey := fmt.Sprintf("event:processed:%s", eventID)
    if exists := m.cache.Exists(ctx, processedKey).Val(); exists > 0 {
        m.logger.Debug("Event already processed (cache)", "event_id", eventID)
        return nil
    }

    // 3. 処理済みチェック（DB）
    var count int64
    m.db.Model(&ProcessedEvent{}).Where("event_id = ?", eventID).Count(&count)
    if count > 0 {
        // キャッシュに追加
        m.cache.Set(ctx, processedKey, "1", 24*time.Hour)
        m.logger.Debug("Event already processed (db)", "event_id", eventID)
        return nil
    }

    // 4. 処理実行
    if err := fn(); err != nil {
        return fmt.Errorf("failed to process event: %w", err)
    }

    // 5. 処理済み記録
    processedEvent := &ProcessedEvent{
        EventID:     eventID,
        ProcessedAt: time.Now(),
    }

    if err := m.db.Create(processedEvent).Error; err != nil {
        return fmt.Errorf("failed to record processed event: %w", err)
    }

    // 6. キャッシュ更新
    m.cache.Set(ctx, processedKey, "1", 24*time.Hour)

    m.logger.Info("Event processed successfully", "event_id", eventID)
    return nil
}
```

##### サーキットブレーカーパターン実装
```go
// internal/infrastructure/resilience/circuit_breaker.go
type CircuitBreaker struct {
    name            string
    maxFailures     int
    resetTimeout    time.Duration
    halfOpenMax     int

    mu              sync.RWMutex
    state           State
    failures        int
    lastFailureTime time.Time
    successCount    int
}

type State int

const (
    StateClosed State = iota
    StateOpen
    StateHalfOpen
)

func (cb *CircuitBreaker) Execute(ctx context.Context, fn func() error) error {
    if !cb.canExecute() {
        return ErrCircuitBreakerOpen
    }

    err := fn()
    cb.recordResult(err)

    return err
}

func (cb *CircuitBreaker) canExecute() bool {
    cb.mu.RLock()
    defer cb.mu.RUnlock()

    switch cb.state {
    case StateClosed:
        return true

    case StateOpen:
        // タイムアウト経過確認
        if time.Since(cb.lastFailureTime) > cb.resetTimeout {
            cb.mu.RUnlock()
            cb.mu.Lock()
            cb.state = StateHalfOpen
            cb.successCount = 0
            cb.mu.Unlock()
            cb.mu.RLock()
            return true
        }
        return false

    case StateHalfOpen:
        // 半開状態での実行制限
        return cb.successCount < cb.halfOpenMax

    default:
        return false
    }
}

func (cb *CircuitBreaker) recordResult(err error) {
    cb.mu.Lock()
    defer cb.mu.Unlock()

    if err != nil {
        cb.failures++
        cb.lastFailureTime = time.Now()

        if cb.failures >= cb.maxFailures {
            cb.state = StateOpen
        }
    } else {
        if cb.state == StateHalfOpen {
            cb.successCount++
            if cb.successCount >= cb.halfOpenMax {
                cb.state = StateClosed
                cb.failures = 0
            }
        } else if cb.state == StateClosed {
            cb.failures = 0
        }
    }
}
```

##### イベント順序保証
```go
// internal/infrastructure/event/event_sequencer.go
type EventSequencer struct {
    sequences map[string]*SequenceTracker
    mu        sync.RWMutex
    logger    *slog.Logger
}

type SequenceTracker struct {
    LastProcessed int64
    Pending       map[int64]Event
    mu            sync.Mutex
}

func (s *EventSequencer) ProcessInOrder(ctx context.Context, event Event) error {
    aggregateID := event.GetAggregateID()
    version := event.GetVersion()

    tracker := s.getOrCreateTracker(aggregateID)
    tracker.mu.Lock()
    defer tracker.mu.Unlock()

    // 期待するバージョンか確認
    expectedVersion := tracker.LastProcessed + 1

    if version == expectedVersion {
        // 順序通りなので処理
        if err := s.processEvent(ctx, event); err != nil {
            return err
        }
        tracker.LastProcessed = version

        // ペンディングイベントの処理
        s.processPendingEvents(ctx, tracker)

    } else if version > expectedVersion {
        // 順序が前後しているのでペンディング
        tracker.Pending[version] = event
        s.logger.Debug("Event queued for later processing",
            "aggregate_id", aggregateID,
            "version", version,
            "expected", expectedVersion)

    } else {
        // 既に処理済み
        s.logger.Debug("Event already processed",
            "aggregate_id", aggregateID,
            "version", version)
    }

    return nil
}

func (s *EventSequencer) processPendingEvents(ctx context.Context, tracker *SequenceTracker) {
    for {
        nextVersion := tracker.LastProcessed + 1
        event, exists := tracker.Pending[nextVersion]
        if !exists {
            break
        }

        if err := s.processEvent(ctx, event); err != nil {
            s.logger.Error("Failed to process pending event", "error", err)
            break
        }

        delete(tracker.Pending, nextVersion)
        tracker.LastProcessed = nextVersion
    }
}
```

### 6.5. 主要コンポーネント

- **主要コンポーネント:**
    - `avion-search (Go, Kubernetes Deployment)`: 本サービス。gRPCサーバー、NATS JetStream Consumer。
    - `avion-gateway (Go)`: gRPCリクエストのルーティング元。
    - `MeiliSearch`: プライマリ全文検索エンジン。
    - `PostgreSQL`: (オプション) 全文検索機能を利用。元データ参照元。
    - `avion-drop (Go)`: Dropデータ参照元 (gRPC)。
    - `avion-user (Go)`: Userデータ参照元 (gRPC)。
    - `NATS JetStream`: イベント配信・購読。
    - `Redis`: キャッシュ、処理済みイベント管理。
    - `Observability Stack`: メトリクス、トレース、ログ収集。
- **構成図:** (アーキテクチャ概要図を参照)
    - [Avion アーキテクチャ概要](../common/architecture.md)
- **ポイント:**
    - イベント駆動で検索インデックスを更新。
    - 複数の検索バックエンドをサポート。
    - アクセス制御を適用した検索結果提供。
    - 冪等性を保証したイベント処理。
    - ステートレス設計でスケーラビリティを確保。

## 6-1. データベースマイグレーション

このサービスでは、[共通マイグレーション戦略](../common/database-migration-strategy.md)に従って、Gooseを使用したマイグレーション管理を行います。

### マイグレーション戦略

- **ツール**: Goose v3
- **ディレクトリ**: `./migrations/`
- **命名規則**: `[sequence_number]_[description].sql`
- **実行方法**: `make migrate-up` / `make migrate-down`

### avion-search固有の考慮事項

- **検索インデックス再構築**: PostgreSQLスキーマ変更時はMeiliSearchインデックスの再構築
- **検索フォールバック**: MeiliSearch更新中はPostgreSQLフォールバック検索を活用
- **同期処理継続**: 他サービスからの検索データ同期処理を中断させない
- **検索設定保持**: カスタム検索設定（ランキング、フィルタ）を移行時も保持
- **大量データ再インデックス**: 全文検索データの大量更新は段階的に処理

### 標準テンプレート参照

マイグレーションファイル作成時は[マイグレーション設定テンプレート](../templates/migration-setup-template.md)を参照してください。

## 7. Use Cases / Key Flows (主な使い方・処理の流れ)

- **フロー 1: MeiliSearchインデックス更新 (Command)**
    1. IndexEventHandler: NATS JetStream `avion.drop.>` / `avion.user.>` からDurable Consumer経由でイベント取得
    2. IndexEventHandler: ProcessIndexEventCommandUseCaseを呼び出し
    3. ProcessIndexEventCommandUseCase: EventID Value Objectを生成し、冪等性チェック
    4. ProcessIndexEventCommandUseCase: EventRepositoryでProcessedEvent Entityを確認
    5. ProcessIndexEventCommandUseCase: IndexOperation Aggregateを生成
    6. DocumentFactory (Domain Service): イベントデータからDropSearchDocument Entityを生成
    7. SearchIndex Aggregate: DropSearchDocumentを追加し、整合性を保証
    8. ProcessIndexEventCommandUseCase: SearchIndexRepositoryを通じてSearchIndexを永続化
    9. ProcessIndexEventCommandUseCase: EventRepositoryを通じてProcessedEventを記録
    10. IndexEventHandler: イベントをACK。エラー時はリトライ/DLQ
- **フロー 2: Drop検索 (Query)**
    1. Gateway → SearchDropsQueryHandler: `SearchDrops` gRPC Call (query, limit, offset, Metadata: X-User-ID, Trace Context)
    2. SearchDropsQueryHandler: SearchDropsQueryUseCaseを呼び出し
    3. SearchDropsQueryUseCase: SearchQuery Value Objectを生成・検証
    4. AccessControlPolicy (Domain Service): UserIDに基づくSearchFilter Value Objectを生成
    5. SearchDropsQueryUseCase: DropSearchQueryServiceを通じてMeiliSearchに問い合わせ
    6. DropSearchQueryService: SearchResult Value Objectを返却（items, totalCount, relevanceScore）
    7. SearchDropsQueryUseCase: DropServiceClientで必要に応じて追加情報を取得
    8. SearchDropsQueryHandler → Gateway: `SearchDropsResponse { results: [...] }`
- **フロー 3: User検索 (Query)**
    1. Gateway → SearchUsersQueryHandler: `SearchUsers` gRPC Call (query, backend, limit, offset)
    2. SearchUsersQueryHandler: SearchUsersQueryUseCaseを呼び出し
    3. SearchUsersQueryUseCase: SearchQuery Value Objectを生成
    4. SearchPolicy (Domain Service): ユーザー検索のビジネスルールを適用
    5. SearchUsersQueryUseCase: UserSearchQueryServiceを通じて検索実行
    6. UserSearchQueryService: SearchResult Value Objectを返却
    7. SearchUsersQueryUseCase: UserServiceClientで必要に応じて追加情報を取得
    8. SearchUsersQueryHandler → Gateway: `SearchUsersResponse { results: [...] }`

- **フロー 4: インデックス再構築 (Command)**
    1. Gateway → RebuildIndexCommandHandler: `RebuildIndex` gRPC Call (index_type)
    2. RebuildIndexCommandHandler: RebuildIndexCommandUseCaseを呼び出し
    3. RebuildIndexCommandUseCase: SearchIndex Aggregateを生成
    4. SearchIndex Aggregate: IndexStatusをREBUILDINGに変更
    5. RebuildIndexCommandUseCase: DropServiceClient/UserServiceClientから全データをバッチ取得
    6. DocumentFactory: 各データからSearchDocumentを生成
    7. RebuildIndexCommandUseCase: SearchIndexRepositoryを通じて新しいインデックスを作成し、切り替え
    8. SearchIndex Aggregate: IndexStatusをACTIVEに変更

- **フロー 5: 検索プライバシー設定更新 (Command)**
    1. User → Gateway → UpdateSearchPrivacyCommandHandler: `UpdateSearchPrivacy` gRPC Call
    2. UpdateSearchPrivacyCommandHandler: UpdateSearchPrivacyCommandUseCaseを呼び出し
    3. UpdateSearchPrivacyCommandUseCase: SearchableContentSettings Value Objectを生成
    4. SearchPrivacyPolicy (Domain Service): 既存Dropのインデックス更新判定
    5. UpdateSearchPrivacyCommandUseCase: 設定に基づいてインデックスの追加/削除を実行
    6. UpdateSearchPrivacyCommandUseCase: UserSearchPrivacyUpdatedイベントを発行

- **フロー 6: ハッシュタグ検索 (Query)**
    1. Gateway → SearchByHashtagQueryHandler: `SearchByHashtag` gRPC Call (#tag, limit, offset)
    2. SearchByHashtagQueryHandler: SearchByHashtagQueryUseCaseを呼び出し
    3. SearchByHashtagQueryUseCase: Hashtag Value Objectを生成・正規化
    4. HashtagSearchQueryService: HashtagIndexからDropIDリストを取得
    5. DropSearchQueryService: DropIDリストから詳細情報を取得
    6. TrendingCalculator (Domain Service): TrendingScoreを計算
    7. SearchByHashtagQueryHandler → Gateway: `HashtagSearchResponse { results: [...], trending_score: ... }`

- **フロー 7: 保存検索の実行 (Query)**
    1. Gateway → ExecuteSavedSearchQueryHandler: `ExecuteSavedSearch` gRPC Call (saved_search_id)
    2. ExecuteSavedSearchQueryHandler: ExecuteSavedSearchQueryUseCaseを呼び出し
    3. SavedSearchRepository: SavedSearch Entityを取得
    4. ExecuteSavedSearchQueryUseCase: 保存されたSearchQueryとSearchFilterで検索実行
    5. ExecuteSavedSearchQueryUseCase: 新着があれば通知イベントを発行
    6. ExecuteSavedSearchQueryHandler → Gateway: `SearchResponse { results: [...], new_matches: ... }`

## 8. Endpoints (API)

- **gRPC Services (`avion.SearchService`):**
    - **Query Operations (参照系):**
        - `SearchDrops(SearchDropsRequest) returns (SearchDropsResponse)` // GET相当
        - `SearchUsers(SearchUsersRequest) returns (SearchUsersResponse)` // GET相当
        - `SearchByHashtag(SearchByHashtagRequest) returns (HashtagSearchResponse)` // GET相当
        - `SearchMentions(SearchMentionsRequest) returns (SearchMentionsResponse)` // GET相当
        - `GetSearchHistory(GetSearchHistoryRequest) returns (SearchHistoryResponse)` // GET相当
        - `GetSavedSearches(GetSavedSearchesRequest) returns (SavedSearchesResponse)` // GET相当
        - `GetTrendingHashtags(GetTrendingHashtagsRequest) returns (TrendingHashtagsResponse)` // GET相当
        - `GetIndexStatus(GetIndexStatusRequest) returns (IndexStatusResponse)` // GET相当
        - (Requestには `query`, `backend` (enum: MEILISEARCH, POSTGRES), `limit`, `offset` などを含む)
        - (Responseには検索結果のリストを含む)
    - **Command Operations (更新系):**
        - `RebuildIndex(RebuildIndexRequest) returns (RebuildIndexResponse)` // POST相当
        - `UpdateSearchPrivacy(UpdateSearchPrivacyRequest) returns (UpdateSearchPrivacyResponse)` // PUT相当
        - `SaveSearch(SaveSearchRequest) returns (SaveSearchResponse)` // POST相当
        - `DeleteSavedSearch(DeleteSavedSearchRequest) returns (DeleteSavedSearchResponse)` // DELETE相当
        - (管理用API、インデックス再構築時に使用)
- Proto定義は別途管理する。

## 9. Data Design (データ)

### 9.1. Domain Model (ドメインモデル)

#### Aggregates (集約)

##### SearchIndex (検索インデックス集約)
- **責務:** 検索インデックスの整合性とライフサイクルを管理
- **集約ルート:** SearchIndex
- **構成要素:**
  - IndexID (Value Object): インデックスの一意識別子
  - IndexType (Value Object): DROPS, USERS
  - IndexStatus (Value Object): ACTIVE, REBUILDING, FAILED
  - LastSyncTimestamp (Value Object): 最終同期日時
  - DocumentCount (Value Object): ドキュメント数
- **不変条件:**
  - IndexTypeは一度設定されたら変更不可（データ整合性保護）
  - REBUILDING状態では新規ドキュメント追加不可（整合性確保）
  - DocumentCountは非負の数（論理的制約）
  - 同時実行可能なREBUILD操作は1つまで（排他制御）
  - インデックスの最大ドキュメント数制限遵守（リソース保護）

##### IndexOperation (インデックス操作集約)
- **責務:** インデックス操作のトランザクション境界を管理
- **集約ルート:** IndexOperation
- **構成要素:**
  - OperationID (Value Object): 操作の一意識別子
  - OperationType (Value Object): ADD, UPDATE, DELETE, REBUILD
  - TargetIndex (SearchIndex): 対象インデックス
  - Documents (Entity Collection): 操作対象ドキュメント
  - OperationStatus (Value Object): PENDING, IN_PROGRESS, COMPLETED, FAILED
- **不変条件:**
  - 一度開始した操作は完了または失敗まで継続（操作の原子性）
  - REBUILD操作中は他の操作不可（排他制御）
  - 同一EventIDの操作は重複不可（冪等性保証）
  - 操作タイムアウト時間内での完了必須（リソース管理）
  - 操作対象ドキュメントの検証必須（データ品質）

##### SearchQuery (検索クエリ集約)
- **責務:** 検索クエリの構築、検証、実行を管理し、複雑な検索条件とフィルタリングルールの整合性を保証
- **集約ルート:** SearchQuery
- **構成要素:**
  - SearchQueryID (Value Object): UUID v7形式の一意識別子
  - SearchKeyword (Value Object): キーワード文字列（最大256文字）
  - SearchFilter (Value Object): 検索フィルタ条件
  - PaginationInfo (Value Object): ページネーション情報
  - SearchTarget (Value Object): 検索対象タイプ（Drop/User）
- **不変条件:**
  - 検索キーワードは最大256文字まで
  - ページサイズは1-100の範囲内
  - フィルタ条件は矛盾しない組み合わせ
  - 検索対象タイプ（Drop/User）は明確に指定
  - プライバシーフィルタは検索実行者の権限に基づく

##### HashtagIndex (ハッシュタグインデックス集約)
- **責務:** ハッシュタグごとの検索インデックスとトレンド情報を管理し、リアルタイムトレンド計算の基盤を提供
- **集約ルート:** HashtagIndex
- **構成要素:**
  - Hashtag (Value Object): 正規化されたハッシュタグ
  - DropCount (Value Object): ハッシュタグに関連するDrop数
  - TrendingScore (Value Object): トレンドスコア（0.0-1.0）
  - LastUsedAt (Value Object): 最終使用日時
- **不変条件:**
  - Hashtagは正規化された形式（小文字、#除去）
  - DropCountは非負の整数値
  - TrendingScoreは0.0から1.0の範囲
  - 24時間以上未使用のハッシュタグは自動アーカイブ
  - 1つのHashtagに対するDrop数上限は10万件

##### SearchHistory (検索履歴集約)
- **責務:** ユーザーごとの検索履歴とサジェスト機能を管理し、プライバシー保護と利便性向上を両立
- **集約ルート:** SearchHistory
- **構成要素:**
  - UserID (Value Object): ユーザーの一意識別子
  - QueryEntries (Entity Collection): 検索クエリ履歴エントリ
  - PrivacySettings (Value Object): 履歴記録のプライバシー設定
- **不変条件:**
  - 履歴は最大1000件まで保持（FIFO方式で古いものを削除）
  - 同一クエリの連続記録は防止（重複排除）
  - プライバシー設定に従い記録可否を制御
  - 検索履歴は30日間で自動削除
  - ユーザーが削除した場合は即座に全削除

##### UserRecommendation (ユーザー推薦集約)
- **責務:** ユーザー推薦アルゴリズムと推薦結果を管理し、パーソナライゼーションと多様性のバランスを調整
- **集約ルート:** UserRecommendation
- **構成要素:**
  - UserID (Value Object): 推薦対象ユーザーの識別子
  - RecommendationScore (Value Object): 推薦スコア（0.0-1.0）
  - RecommendationReason (Value Object): 推薦理由
  - GeneratedAt (Value Object): 推薦生成日時
- **不変条件:**
  - 推薦対象ユーザーは有効なアカウントのみ
  - 自己推薦は除外
  - ブロックされたユーザーは推薦対象外
  - 推薦スコアは0.0から1.0の範囲
  - 推薦理由は明確に記録

#### Entities (エンティティ)

##### DropSearchDocument (Drop検索ドキュメント)
- **責務:** Drop検索ドキュメントの情報を保持
- **所属集約:** SearchIndex
- **属性:**
  - DropID (Value Object): Dropの一意識別子
  - SearchableText (Value Object): 検索対象テキスト
  - Visibility (Value Object): public, private, followers_only
  - AuthorID (Value Object): 作成者UserID
  - CreatedAt (Value Object): 作成日時
  - SearchMetadata (Value Object): 追加検索メタデータ
  - Hashtags (Entity Collection): 抽出されたハッシュタグ
  - Mentions (Entity Collection): 抽出されたメンション
- **ビジネスルール:**
  - SearchableTextは最大5000文字（検索性能保護）
  - Visibilityに応じた検索可能性制御（プライバシー保護）
  - 削除されたDropは検索インデックスから除外（データ整合性）
  - センシティブコンテンツのフィルタリング対応（コンテンツ管理）
  - ハッシュタグ・メンション自動抽出と正規化（検索精度向上）

##### UserSearchDocument (User検索ドキュメント)
- **責務:** User検索ドキュメントの情報を保持
- **所属集約:** SearchIndex
- **属性:**
  - UserID (Value Object): Userの一意識別子
  - Username (Value Object): ユーザー名
  - DisplayName (Value Object): 表示名
  - Bio (Value Object): 自己紹介
  - SearchableFields (Value Object): 検索対象フィールドの集合
  - SearchPrivacySettings (Value Object): 検索プライバシー設定
- **ビジネスルール:**
  - SearchPrivacySettingsに従う検索可能性制御（GDPR準拠）
  - 停止・凍結されたユーザーは検索対象外（安全性確保）
  - ユーザー名の一意性検証（データ整合性）
  - プロフィール完成度による検索優先度調整（ユーザー体験向上）
  - ボットアカウントの適切な分類とフィルタリング（検索品質向上）

##### ProcessedEvent (処理済みイベント)
- **責務:** 処理済みイベントの記録を管理
- **属性:**
  - EventID (Value Object): イベントの一意識別子
  - ProcessedAt (Value Object): 処理日時
  - OperationType (Value Object): 実行した操作種別
  - Result (Value Object): 処理結果

##### SavedSearch (保存検索)
- **責務:** 保存された検索条件を管理し、再実行と新着マッチ通知の基盤を提供
- **所属集約:** SearchHistory
- **属性:**
  - SavedSearchID (Value Object): UUID v7の一意識別子
  - UserID (Value Object): 所有者ID
  - SearchName (Value Object): 検索名（最大100文字）
  - SearchQuery (Value Object): 保存された検索条件
  - SearchFilters (Value Object): 適用されたフィルタ条件
  - NotificationEnabled (Value Object): 新着マッチ通知設定
  - LastExecutedAt (Value Object): 最終実行日時
  - CreatedAt, UpdatedAt (Value Object): 作成・更新日時
- **ビジネスルール:**
  - SearchNameは100文字以内で一意性を保持
  - 1ユーザー最大50件まで保存可能
  - 30日間未実行の保存検索は自動削除候補

##### TrendingHashtag (トレンディングハッシュタグ)
- **責務:** トレンディングハッシュタグの状態を管理し、トレンド表示機能を支援
- **所属集約:** HashtagIndex
- **属性:**
  - HashtagID (Value Object): 正規化されたハッシュタグ文字列
  - NormalizedValue (Value Object): 小文字・記号除去済み
  - TrendingScore (Value Object): 0.0-1.0のトレンドスコア
  - UsageCount24h (Value Object): 24時間以内の使用回数
  - UsageCount7d (Value Object): 7日間以内の使用回数
  - GrowthRate (Value Object): 前日比成長率
  - LastCalculatedAt (Value Object): スコア計算日時
  - Region (Value Object): 地域区分（JP/US/GLOBAL）
- **ビジネスルール:**
  - TrendingScoreは0.0-1.0の範囲を厳守
  - UsageCountは非負の整数値を維持
  - 24時間未更新のスコアは無効とする

##### MentionIndex (メンションインデックス)
- **責務:** メンション関係のインデックスを管理し、効率的なメンション検索を提供
- **所属集約:** SearchIndex
- **属性:**
  - MentionID (Value Object): UUID v7の一意識別子
  - DropID (Value Object): メンションを含むDrop
  - MentionedUserID (Value Object): メンションされたユーザー
  - MentionerUserID (Value Object): メンションしたユーザー
  - Context (Value Object): メンション前後のテキスト（前後50文字）
  - MentionType (Value Object): DIRECT/REPLY/QUOTE
  - CreatedAt (Value Object): メンション作成日時
- **ビジネスルール:**
  - 自己メンションは除外（MentionedUserID != MentionerUserID）
  - Contextは前後50文字に制限
  - MentionTypeは有効な種別のみ許可

#### Value Objects (値オブジェクト)

##### SearchQuery
- **責務:** 検索クエリを表現
- **属性:** queryText, filters, pagination
- **不変性:** 完全に不変

##### SearchResult
- **責務:** 検索結果を表現
- **属性:** items, totalCount, relevanceScores
- **不変性:** 完全に不変

##### EventID
- **責務:** イベントの一意識別子を表現
- **属性:** value (UUID v7形式)
- **不変性:** 完全に不変

##### SearchFilter
- **責務:** 検索フィルタ条件を表現
- **属性:** field, operator, value
- **不変性:** 完全に不変

##### SearchableText
- **責務:** 検索対象テキストを表現
- **属性:** text, language
- **不変性:** 完全に不変

##### RelevanceScore
- **責務:** 検索結果の関連性スコアを表現
- **属性:** score (0.0-1.0)
- **不変性:** 完全に不変

### 9.2. Infrastructure Layer (インフラストラクチャ層)

- **MeiliSearch Index:**
    - `drops` index: DropSearchDocument Entityに対応
        - Filterable attributes: visibility, author_id, created_at, searchable
        - Searchable attributes: text, metadata, hashtags, mentions
        - Sortable attributes: created_at, relevance
    - `users` index: UserSearchDocument Entityに対応
        - Filterable attributes: user_id, searchable_profile
        - Searchable attributes: username, display_name, bio
    - `hashtags` index: HashtagIndex Aggregateに対応
        - Filterable attributes: trending_score
        - Searchable attributes: hashtag, normalized_hashtag
        - Sortable attributes: drop_count, trending_score, last_used_at
    - 日本語設定（トークナイザー）を有効化
- **PostgreSQL:** (参照のみ)
    - 全文検索インデックス (`GIN` or `GiST`) を活用
    - `to_tsvector('japanese', text)` で日本語対応
    - 追加テーブル:
        - `search_history`: 検索履歴保存
        - `saved_searches`: 保存検索条件
        - `mention_index`: メンションインデックス
- **NATS JetStream:**
    - Stream: `DROP` / `USER` / `MESSAGE` (Subject: `avion.drop.>` / `avion.user.>` / `avion.message.>`)
    - Durable Consumer: `search-drop-consumer` / `search-user-consumer` / `search-message-metadata-consumer`
    - Dead Letter Queue: DLQ Stream
    - **注意:** avion-message からはメッセージ本文を含まない非暗号化メタデータ（送信者、日時、会話名、添付ファイル種類等）のみを受信する。E2E暗号化メッセージの本文は送信されない
- **Redis:**
    - Processed Events Set: `processed_events:{index_type}` (EventIDを保存)
    - Operation Lock: `index_operation:{index_type}` (REBUILD時の排他制御)
    - Search History: `search_history:{user_id}` (最近の検索クエリ)
    - Trending Hashtags: `trending_hashtags` (Sorted Set)
    - Search Privacy Settings: `search_privacy:{user_id}` (ユーザー設定キャッシュ)

## 10. Operations & Monitoring (運用と監視)

- **主なオペレーション:**
    - MeiliSearch/PostgreSQLの接続情報管理。
    - Redis接続情報（キャッシュ用）。
    - NATS JetStream接続情報、Stream/Consumer設定。
    - MeiliSearchインデックス設定の管理・更新。
    - (必要に応じて) MeiliSearchインデックスの再構築。
    - DLQの監視と対応。
- **監視/アラート:**
    - **メトリクス:**
        - gRPCリクエスト数、レイテンシ、エラーレート。
        - MeiliSearch/PostgreSQLクエリ実行時間、エラーレート。
        - NATS JetStream処理遅延、エラーレート、Pending数。
    - **ログ:** API処理ログ、イベント処理ログ (冪等性チェック結果含む)、MeiliSearch/PostgreSQL連携ログ、エラーログ、DLQ投入ログ。
    - **トレース:** API呼び出し、イベント処理、MeiliSearch/PostgreSQLアクセスのトレース。
    - **アラート:** gRPCエラーレート急増、高レイテンシ、MeiliSearch/PostgreSQL接続障害、NATS JetStream処理遅延大/Pending数増加、インデックス更新失敗。

## 11. 構造化ログ戦略

> 詳細は [designdoc-infra-testing.md](./designdoc-infra-testing.md) を参照してください。

## 12. エラーハンドリング戦略

> 詳細は [designdoc-infra-testing.md](./designdoc-infra-testing.md) を参照してください。
>
> **注意:** エラーコードは[共通エラーコード標準](../common/errors/error-codes.md)に準拠します。このサービスではプレフィックス `SRC` を使用します。エラーコード定義とマッピングについては、[error-catalog.md](./error-catalog.md) を参照してください。

## 13. ドメインオブジェクトとMeiliSearchマッピング戦略

> 詳細は [designdoc-indexing.md](./designdoc-indexing.md) を参照してください。

## 14. ドメインモデル詳細設計

> 詳細は [designdoc-trending.md](./designdoc-trending.md) を参照してください。

## 15. ドメインオブジェクトとDBスキーマのマッピング

> 詳細は [designdoc-indexing.md](./designdoc-indexing.md) を参照してください。

## 16. 検索特化アーキテクチャと最適化戦略

> 詳細は [designdoc-indexing.md](./designdoc-indexing.md) を参照してください。

## 17. Concerns / Open Questions (懸念事項・相談したいこと)

### 17.1. 技術的負債リスク
- **インデックス整合性:** イベント処理の信頼性向上策（Stream, 冪等性）を講じるが、完全なリアルタイム整合性は保証しない。不整合発生リスクは残り、解消のための定期的な差分同期や限定的な再インデックスの実装・運用コストが発生する可能性がある。
- **アクセス制御の複雑性とパフォーマンス:** MeiliSearchフィルタで表現できない複雑な権限が必要になった場合、アプリ層フィルタリングによるパフォーマンス低下リスクがある。
- **検索エンジン/DB依存:** MeiliSearchやPostgreSQL FTSのバージョンアップや仕様変更への追従コスト。
- **イベント処理の信頼性:** イベントロストや重複処理はインデックス不整合に直結するため、冪等性確保や堅牢なエラーハンドリングが不可欠。

### 17.2. 検索特有の技術課題

#### MeiliSearchの最適化課題
- **日本語処理最適化（決定済み）**: MeiliSearch v1.9 内蔵 Lindera（IPA辞書ベース、Viterbiアルゴリズム）を採用。Docker設定で `--features japanese` カスタムビルドオプションを指定し、漢字誤検出を防止する。ひらがな・カタカナの統一正規化はアプリケーション層の `JapaneseTextProcessor` で実施
- **ランキング精度**: ユーザー行動データを活用したランキングアルゴリズム調整
- **スケーラビリティ**: 大規模データセット（数百万投稿）でのパフォーマンス維持
- **リアルタイム性**: インデックス反映SLOとして投稿から検索可能になるまで5秒以内を目標。完全なリアルタイム整合性は保証しない

#### 検索品質とパフォーマンスのトレードオフ
- **精度 vs 速度**: 検索精度向上（シノニム、関連語）によるレスポンス時間への影響
- **新鮮さ vs 処理負荷**: リアルタイム性向上のためのインデックス更新頻度増加
- **パーソナライゼーション vs キャッシュ効率**: ユーザー別カスタマイズとキャッシュ戦略

#### セキュリティとプライバシーの課題
- **検索ログの機密性**: 検索クエリからの個人情報推測リスク
- **GDPR準拠の完全性**: 忘れられる権利の検索インデックスからの完全削除保証
- **アクセス制御の複雑性**: フォロー関係、ブロック、ミュート状態の高速フィルタリング

#### 将来の拡張性課題
- **フェデレーション検索**: 外部インスタンスとの検索結果統合手法
- **マルチメディア検索**: 画像・動画コンテンツの検索対応
- **AI活用**: 検索意図理解とセマンティック検索の導入可能性

## 18. Configuration Management (設定管理)

このサービスは、[共通環境変数管理パターン](../common/infrastructure/environment-variables.md)に従って設定管理を実装します。

### 18.1. 環境変数一覧

#### 必須環境変数
- `DATABASE_URL`: PostgreSQL接続URL
- `REDIS_URL`: Redis接続URL（キャッシュ用）
- `NATS_URL`: NATS接続URL（イベント配信用）
- `MEILISEARCH_URL`: MeiliSearch接続URL
- `MEILISEARCH_MASTER_KEY`: MeiliSearchマスターキー

#### オプション環境変数（デフォルト値あり）
- `PORT`: HTTPサーバーポート (デフォルト: 8088)
- `GRPC_PORT`: gRPCサーバーポート (デフォルト: 9098)
- `INDEX_BATCH_SIZE`: インデックス更新のバッチサイズ (デフォルト: 100)
- `SYNC_INTERVAL`: 同期間隔 (デフォルト: 1m)

### 18.2. Config構造体実装例

```go
// internal/infrastructure/config/config.go
package config

import (
    "time"
)

type Config struct {
    // 共通設定
    Server   ServerConfig
    Database DatabaseConfig
    Redis    RedisConfig
    NATS     NATSConfig

    // avion-search固有設定
    MeiliSearch MeiliSearchConfig
    Search      SearchConfig
}

type NATSConfig struct {
    URL string `env:"NATS_URL" required:"true"`
}

type MeiliSearchConfig struct {
    URL       string `env:"MEILISEARCH_URL" required:"true"`
    MasterKey string `env:"MEILISEARCH_MASTER_KEY" required:"true" secret:"true"`
}

type SearchConfig struct {
    IndexBatchSize int           `env:"INDEX_BATCH_SIZE" required:"false" default:"100"`
    SyncInterval   time.Duration `env:"SYNC_INTERVAL" required:"false" default:"1m"`
}
```

### 18.3. 設定の検証と初期化

```go
// cmd/server/main.go
func main() {
    // 環境変数の読み込み（必須環境変数が不足していればここで失敗）
    cfg := config.MustLoad()

    logger.Info("Starting avion-search server",
        "environment", cfg.Server.Environment,
        "port", cfg.Server.Port,
        "grpc_port", cfg.Server.GRPCPort,
        "meilisearch_url", cfg.MeiliSearch.URL,
        "index_batch_size", cfg.Search.IndexBatchSize,
        "sync_interval", cfg.Search.SyncInterval,
    )

    // MeiliSearchクライアントの初期化
    searchClient := meilisearch.NewClient(meilisearch.ClientConfig{
        Host:   cfg.MeiliSearch.URL,
        APIKey: cfg.MeiliSearch.MasterKey,
    })

    // その他の依存関係初期化...
}
```

この設定管理により、サービス起動時に必須環境変数の不足を早期検出し、設定エラーによる問題を防止します。

## 19. Release Plan

### Phase 0: 基本検索機能（MVP）
**期間**: 4-6週間
**実装内容**:
- Drop/User基本検索機能
- MeiliSearchインデックス管理
- イベント駆動インデックス更新（NATS JetStream）
- アクセス制御基盤
- SearchBackend interfaceによる抽象化

**成果物**:
- `SearchDrops`, `SearchUsers` API
- 基本的なインデックス更新機能
- 構造化ログ基盤
- 日本語検索最適化設定（MeiliSearch v1.9 内蔵 Lindera、`--features japanese` カスタムビルド）
- インデックス反映SLO: 投稿から検索可能になるまで5秒以内

### Phase 1: プライバシーと基本拡張機能
**期間**: 3-4週間
**実装内容**:
- 検索プライバシー制御（GDPR対応）
- ハッシュタグ検索機能
- メンション検索機能
- トレンディングハッシュタグ

**成果物**:
- `UpdateSearchPrivacy` API
- `SearchByHashtag`, `SearchMentions` API
- `GetTrendingHashtags` API

### Phase 2: ユーザー体験向上機能
**期間**: 3-4週間
**実装内容**:
- 検索履歴管理
- サジェスト機能
- 保存検索機能
- リアクションベース検索

**成果物**:
- `GetSearchHistory` API
- `SaveSearch`, `GetSavedSearches` API
- 検索サジェスト機能

### Phase 3: 高度な検索機能
**期間**: 4-5週間
**実装内容**:
- フェデレーション検索
- コレクション内検索
- 高度な検索構文サポート
- パフォーマンス最適化

**成果物**:
- リモートインスタンス検索機能
- コレクション検索API
- キャッシュ戦略実装

### 各フェーズ共通タスク
- [共通テスト戦略](../common/testing-strategy.md)に従ったテスト実装
- ドキュメント更新
- セキュリティレビュー

## 20. SearchBackend Interface 設計

> 詳細は [designdoc-indexing.md](./designdoc-indexing.md) を参照してください。

## 21. Test Strategy

> 詳細は [designdoc-infra-testing.md](./designdoc-infra-testing.md) を参照してください。
