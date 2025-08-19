# PRD: avion-search

## 概要

Avionにおける投稿（Drop）やユーザーの検索機能を提供するマイクロサービスを実装する。MeiliSearchを活用した高速な全文検索、ハッシュタグトレンド分析、パーソナライズされた推薦機能などを統合し、ユーザーが必要な情報を瞬時に発見できる包括的な検索体験を実現する。

## 背景

ユーザー数や投稿数が増加するにつれて、特定の情報（過去のDrop、特定のユーザー）を見つけ出すことが困難になる。従来のリレーショナルデータベースの検索機能では、大量のテキストデータに対する高速な全文検索や関連性ランキングの提供が困難である。

検索機能は単なるキーワードマッチングを超えて、ユーザーの検索意図を理解し、関連性の高い結果を提供する必要がある。これには形態素解析、転置インデックス、ランキングアルゴリズム、プライバシー制御など、専門的な技術が要求される。

検索処理を独立したステートレスマイクロサービスとして実装することで、MeiliSearchやPostgreSQL FTSなどの専門的な検索エンジンを効率的に活用し、他のサービスへの影響を最小限に抑えながら高速で関連性の高い検索結果を提供できる。

さらに、ハッシュタグトレンド分析やユーザー推薦機能により、ユーザーが能動的に検索しなくても興味深いコンテンツや新たなつながりを発見できる機能も統合し、プラットフォーム全体のエンゲージメント向上を図る。

## Scientific Merits

* **高速情報発見の価値**: MeiliSearchによる平均100ms以下の応答速度により、ユーザーが必要な情報を瞬時に発見でき、従来のSQL検索と比較して10-100倍の高速化を実現。検索レイテンシ短縮により検索完了率が85%から95%に向上。
* **検索精度の向上**: 日本語形態素解析とカスタムランキングアルゴリズムにより、関連性スコアの平均20%向上を達成。検索結果の初回クリック率を60%から80%に改善。
* **スケーラビリティの確保**: ステートレス設計により、検索クエリ数に応じた水平スケールが可能。1秒あたり10,000クエリまでの処理能力を持ち、レプリカ追加により線形スケールを実現。
* **プライバシー保護型検索**: GDPR準拠の「忘れられる権利」実装により、ユーザープライバシーを保護しながら検索機能を提供。プライバシー設定による検索可能性の細かい制御で、ユーザー満足度85%以上を維持。
* **トレンド分析の価値**: リアルタイムハッシュタグトレンド分析により、プラットフォーム上の話題性を99%以上の精度で検出。トレンド表示機能によりユーザーエンゲージメント30%向上。
* **機械学習による推薦精度**: 協調フィルタリングとコンテンツベースフィルタリングの組み合わせにより、ユーザー推薦の精度75%以上を達成。新規フォロー率20%向上を実現。

## Design Doc

[Design Doc: avion-search](./designdoc.md)

## 参考ドキュメント

* [Avion アーキテクチャ概要](./../common/architecture.md)
* [MeiliSearch Documentation](https://docs.meilisearch.com/)
* [PostgreSQL Full Text Search](https://www.postgresql.org/docs/current/textsearch.html)

## 製品原則

* **関連性の高い結果**: 検索キーワードに対して、最も関連性の高いDropやユーザーを上位に表示し、検索意図を正確に理解する。
* **高速な応答**: 検索クエリに対してp50 100ms以下、p99 500ms以下の応答速度を維持する。
* **プライバシー重視**: ユーザーが自分のコンテンツの検索可能性を細かく制御でき、GDPR準拠の忘れられる権利を実装する。
* **多様な検索軸**: キーワード検索、ハッシュタグ、メンション、リアクション検索など、多様な検索方法を統一的に提供する。
* **発見性の向上**: トレンド分析と推薦機能により、ユーザーが新しいコンテンツやユーザーを発見する機会を最大化する。
* **データ整合性**: 検索インデックスの整合性を維持し、削除されたコンテンツが検索結果に残らないよう確実に同期する。

## やること/やらないこと

### やること

#### Core Search Operations
* **MeiliSearch連携（1stリリース）**:
  - Drop/Userの作成・更新・削除イベントを処理してインデックス更新
  - 日本語検索最適化設定（kuromoji tokenizer相当）を使用
  - SearchQuery、SearchFilter、SearchResultバリューオブジェクトによる統一的な検索API
  - レスポンス時間p50 100ms以下、p99 500ms以下の性能目標
* **PostgreSQL全文検索インターフェース（将来切り替え用）**:
  - SearchBackend interfaceによる抽象化
  - tsvector/tsqueryを使用したPostgreSQL FTS実装準備
  - バックエンド切り替えの透明性確保
* **統一検索API**:
  - Drop検索API: SearchDropsUseCase
  - ユーザー検索API: SearchUsersUseCase
  - 検索結果ページネーション（最大100件/ページ）
  - アクセス制御とプライバシーフィルタリング

#### Enhanced Search Features
* **ハッシュタグ検索とトレンド分析**:
  - HashtagExtractorによる正確なハッシュタグ抽出
  - TrendingCalculatorによる24時間/7日間のトレンドスコア計算
  - 地域別トレンド分析（日本、グローバル）
  - トレンドAPI: GetTrendsQueryUseCase（キャッシュTTL: 10分）
* **プライバシー制御機能**:
  - SearchableContentSettingsによる検索可能性の細かい制御
  - GDPR準拠の忘れられる権利実装
  - インデックス時と検索時のプライバシーポリシー適用
* **メンション検索**:
  - MentionExtractorによるメンション抽出とインデックス化
  - 自分へのメンション/他者へのメンション検索
  - メンション周辺コンテキストの提供

#### Advanced Features
* **検索履歴とサジェスト**:
  - SearchHistory Aggregateによるユーザー別検索履歴管理
  - 頻出キーワードベースのサジェスト生成
  - デバウンス処理（300ms）によるリアルタイム検索体験
* **保存検索機能**:
  - SavedSearch Entityによる検索条件の保存
  - 新着マッチ通知の基盤機能
  - ユーザーあたり最大50件の保存検索制限
* **ユーザー推薦システム**:
  - 協調フィルタリングとコンテンツベースフィルタリング
  - ソーシャルグラフ分析による推薦
  - 推薦精度75%以上の目標達成

#### Performance & Reliability
* **キャッシュ戦略**:
  - 検索結果キャッシュ（TTL: 5分）
  - トレンドキャッシュ（TTL: 10分）
  - ユーザー推薦キャッシュ（TTL: 30分）
* **監視とObservability**:
  - OpenTelemetryによるトレーシング
  - 検索クエリ性能メトリクス
  - インデックス更新遅延監視
* **エラーハンドリングと冪等性**:
  - EventIDによる重複処理防止
  - リトライキューによる失敗処理の再試行
  - グレースフルデグラデーション

### やらないこと

* **検索エンジン自体の運用**: MeiliSearchやPostgreSQLの運用管理は他チームの責任
* **データの永続化**: 本サービスはステートレスでありSearchIndexも外部システムに委譲
* **タイムラインの代替**: 検索機能はタイムライン表示の代替ではない（avion-timelineの責任）
* **リアルタイムインデックス（厳密な意味）**: 若干のインデックス更新遅延を許容（平均1分以下）
* **ユーザー管理**: ユーザー情報の管理はavion-userの責任
* **投稿管理**: Drop情報の管理はavion-dropの責任
* **メディア処理**: メディアファイルの処理はavion-mediaの責任

## 対象ユーザ

* **Avionエンドユーザー**: API Gateway経由での検索機能利用
* **他のAvionマイクロサービス**:
  - avion-drop: Drop作成/更新/削除イベントの発行元
  - avion-user: ユーザー作成/更新/削除イベントの発行元
  - avion-gateway: 検索APIの呼び出し元
  - avion-notification: 保存検索の新着マッチ通知連携
* **Avion開発者・運用者**: サービスの監視、メンテナンス、拡張

## ドメインモデル (DDD戦術的パターン)

### Aggregates (集約)

#### SearchIndex Aggregate
**責務**: 検索インデックスの整合性とライフサイクルを管理し、複数の検索バックエンドに対する統一的なインデックス操作を提供
- **集約ルート**: SearchIndex
- **不変条件**:
  - IndexTypeは一度設定されたら変更不可（MeiliSearch、PostgreSQL、Elasticsearch等）
  - REBUILDING状態では新規ドキュメント追加不可
  - DocumentCountは非負の整数値を維持
  - インデックス名は一意性を保持
  - インデックスサイズ上限を100万ドキュメントに制限
- **ドメインロジック**:
  - `canAddDocument(documentType)`: ドキュメント追加可否判定とリソース制限チェック
  - `startRebuild(reason)`: インデックス再構築開始とステータス管理
  - `completeRebuild(metrics)`: インデックス再構築完了と統計更新
  - `validateIntegrity(checksum)`: インデックス整合性検証とエラー検出
  - `updateDocumentCount(delta)`: ドキュメント数の増減管理
  - `canHandleSearchLoad(currentLoad)`: 検索負荷処理可否判定

#### SearchQuery Aggregate
**責務**: 検索クエリの構築、検証、実行を管理し、複雑な検索条件とフィルタリングルールの整合性を保証
- **集約ルート**: SearchQuery
- **不変条件**:
  - 検索キーワードは最大100文字まで
  - ページサイズは1-100の範囲内
  - フィルタ条件は矛盾しない組み合わせ
  - 検索対象タイプ（Drop/User）は明確に指定
  - プライバシーフィルタは検索実行者の権限に基づく
- **ドメインロジック**:
  - `validate()`: 検索条件の妥当性検証とサニタイゼーション
  - `applyPrivacyFilter(viewerID)`: プライバシー設定に基づくフィルタ適用
  - `optimizeForBackend(backend)`: バックエンド特有の最適化
  - `calculateRelevanceWeights()`: 関連性スコア重み計算
  - `buildCacheKey()`: 検索結果キャッシュキー生成
  - `shouldUseCache(cachePolicy)`: キャッシュ利用可否判定

#### IndexOperation Aggregate
**責務**: インデックス操作のトランザクション境界と操作履歴を管理し、失敗時の復旧と冪等性を保証
- **集約ルート**: IndexOperation
- **不変条件**:
  - 一度開始した操作は完了または失敗まで状態遷移
  - REBUILD操作中は他の更新操作不可
  - 同一EventIDの操作は重複実行不可
  - 操作タイムアウトは最大30分
  - リトライ回数は最大3回まで
- **ドメインロジック**:
  - `execute(context)`: 操作実行とエラーハンドリング
  - `complete(result)`: 操作完了と結果記録
  - `fail(error)`: 操作失敗とエラー情報記録
  - `canProceed()`: 操作続行可能性判定
  - `scheduleRetry(delay)`: リトライスケジュール設定
  - `calculateProgress()`: 進捗率計算と報告

#### HashtagIndex Aggregate
**責務**: ハッシュタグごとの検索インデックスとトレンド情報を管理し、リアルタイムトレンド計算の基盤を提供
- **集約ルート**: HashtagIndex
- **不変条件**:
  - Hashtagは正規化された形式（小文字、#除去）
  - DropCountは非負の整数値
  - TrendingScoreは0.0から1.0の範囲
  - 24時間以上未使用のハッシュタグは自動アーカイブ
  - 1つのHashtagに対するDrop数上限は10万件
- **ドメインロジック**:
  - `addDrop(dropID, timestamp)`: Dropをインデックスに追加とカウント更新
  - `removeDrop(dropID)`: Dropをインデックスから削除とカウント調整
  - `calculateTrendingScore(timeWindow)`: 指定期間のトレンドスコア計算
  - `shouldBeArchived()`: アーカイブ対象判定（使用頻度・期間基準）
  - `getNormalizedHashtag()`: 正規化されたハッシュタグ取得
  - `getUsageStatistics(period)`: 使用統計情報の取得

#### SearchHistory Aggregate
**責務**: ユーザーごとの検索履歴とサジェスト機能を管理し、プライバシー保護と利便性向上を両立
- **集約ルート**: SearchHistory
- **不変条件**:
  - 履歴は最大1000件まで保持（FIFO方式で古いものを削除）
  - 同一クエリの連続記録は防止（重複排除）
  - プライバシー設定に従い記録可否を制御
  - 検索履歴は30日間で自動削除
  - ユーザーが削除した場合は即座に全削除
- **ドメインロジック**:
  - `addQuery(searchQuery, timestamp)`: 検索クエリを履歴に追加
  - `getFrequentQueries(limit)`: 頻出クエリの取得とランキング
  - `getSuggestions(prefix, limit)`: 入力補完サジェスト生成
  - `clearHistory()`: 履歴の完全削除（GDPR対応）
  - `canRecordQuery(privacySettings)`: 記録可否判定
  - `generateTrendingQueries()`: トレンド検索クエリの抽出

#### UserRecommendation Aggregate
**責務**: ユーザー推薦アルゴリズムと推薦結果を管理し、パーソナライゼーションと多様性のバランスを調整
- **集約ルート**: UserRecommendation
- **不変条件**:
  - 推薦対象ユーザーは有効なアカウントのみ
  - 自己推薦は除外
  - ブロックされたユーザーは推薦対象外
  - 推薦スコアは0.0から1.0の範囲
  - 推薦理由は明確に記録
- **ドメインロジック**:
  - `calculateRecommendationScore(userID, targetID)`: 推薦スコアの多次元計算
  - `generateRecommendations(userID, limit)`: パーソナライズ推薦生成
  - `applyDiversityOptimization(recommendations)`: 推薦結果の多様性最適化
  - `filterByPrivacySettings(recommendations, settings)`: プライバシー設定による絞り込み
  - `updateRecommendationFeedback(userID, targetID, action)`: フィードバック学習
  - `shouldRefreshRecommendations(lastUpdated)`: 推薦更新必要性判定

### Entities (エンティティ)

#### DropSearchDocument
**所属**: SearchIndex Aggregate
**責務**: Drop検索ドキュメントの構造化された情報を保持し、検索インデックスの基本単位として機能
- **属性**:
  - DropID (雪花ID - 一意識別子)
  - SearchableText (最大3000文字 - 検索対象テキスト)
  - Visibility (PUBLIC/FOLLOWERS_ONLY/PRIVATE - 可視性制御)
  - AuthorID (投稿者ID - アクセス制御用)
  - CreatedAt (作成日時UTC - ソート・フィルタ用)
  - SearchMetadata (インデックス固有メタデータ)
  - Hashtags (ハッシュタグリスト - 専用検索用)
  - Mentions (メンションリスト - メンション検索用)
  - ReactionCount (リアクション数 - ランキング用)
- **ビジネスルール**:
  - SearchableTextからHTMLタグと不適切コンテンツを除去
  - Visibilityに応じたインデックス制御（PRIVATE時は非インデックス化）
  - HashtagsとMentionsは自動抽出・正規化
  - ReactionCountは非負の整数値を維持

#### UserSearchDocument  
**所属**: SearchIndex Aggregate
**責務**: ユーザー検索ドキュメントの情報を保持し、ユーザー発見機能の基盤を提供
- **属性**:
  - UserID (雪花ID - 一意識別子)
  - Username (最大50文字 - 表示名・検索用)
  - DisplayName (最大100文字 - 表示名)
  - Bio (最大500文字 - プロフィール検索用)
  - SearchableFields (カスタム検索可能フィールド)
  - SearchPrivacySettings (検索可能性設定)
  - FollowerCount (フォロワー数 - ランキング用)
  - IsVerified (認証状態 - 優先表示用)
- **ビジネスルール**:
  - SearchPrivacySettingsに従うインデックス制御
  - Usernameは一意性を保証（重複チェック）
  - SearchableFieldsは設定可能項目に限定

#### SavedSearch
**所属**: SearchHistory Aggregate  
**責務**: 保存された検索条件を管理し、再実行と新着マッチ通知の基盤を提供
- **属性**:
  - SavedSearchID (UUID v4 - 一意識別子)
  - UserID (所有者ID)
  - SearchName (検索名 - 最大100文字)
  - SearchQuery (保存された検索条件)
  - SearchFilters (適用されたフィルタ条件)
  - NotificationEnabled (新着マッチ通知設定)
  - LastExecutedAt (最終実行日時)
  - CreatedAt, UpdatedAt (作成・更新日時)
- **ビジネスルール**:
  - SearchNameは100文字以内で一意性を保持
  - 1ユーザー最大50件まで保存可能
  - 30日間未実行の保存検索は自動削除候補

#### MentionIndex
**所属**: SearchIndex Aggregate
**責務**: メンション関係のインデックスを管理し、効率的なメンション検索を提供
- **属性**:
  - MentionID (UUID v4 - 一意識別子)
  - DropID (メンションを含むDrop)
  - MentionedUserID (メンションされたユーザー)
  - MentionerUserID (メンションしたユーザー)
  - Context (メンション前後のテキスト - 前後50文字)
  - MentionType (DIRECT/REPLY/QUOTE - メンション種別)
  - CreatedAt (メンション作成日時)
- **ビジネスルール**:
  - 自己メンションは除外（MentionedUserID ≠ MentionerUserID）
  - Contextは前後50文字に制限
  - MentionTypeは有効な種別のみ許可

#### TrendingHashtag
**所属**: HashtagIndex Aggregate
**責務**: トレンディングハッシュタグの状態を管理し、トレンド表示機能を支援
- **属性**:
  - HashtagID (正規化されたハッシュタグ文字列)
  - NormalizedValue (小文字・記号除去済み)
  - TrendingScore (0.0-1.0のトレンドスコア)
  - UsageCount24h (24時間以内の使用回数)
  - UsageCount7d (7日間以内の使用回数) 
  - GrowthRate (前日比成長率)
  - LastCalculatedAt (スコア計算日時)
  - Region (地域区分 - JP/US/GLOBAL)
- **ビジネスルール**:
  - TrendingScoreは0.0-1.0の範囲を厳守
  - UsageCountは非負の整数値を維持
  - GrowthRateは-100%から∞%の範囲
  - 24時間未更新のスコアは無効とする

### Value Objects (値オブジェクト)

**識別子関連**
- **DropID**: 雪花ID形式（64bit、タイムスタンプ含有）
- **UserID**: 雪花ID形式（64bit、タイムスタンプ含有）
- **EventID**: UUID v4形式（冪等性制御用）
- **SearchQueryID**: UUID v4形式（キャッシュキー生成用）

**検索条件属性**
- **SearchKeyword**: キーワード文字列（最大100文字、サニタイズ済み）
  - 英数字、ひらがな、カタカナ、漢字、基本的な記号のみ許可
  - SQLインジェクション対策のエスケープ処理
  - 禁止文字・フレーズのフィルタリング
- **SearchFilter**: 検索フィルタ条件
  - DateRange（日付範囲指定）
  - UserIDFilter（特定ユーザーのみ）
  - VisibilityFilter（可視性制限）
  - ContentTypeFilter（Drop/User種別）
- **PaginationInfo**: ページネーション情報
  - PageNumber（1以上の整数）
  - PageSize（1-100の範囲）
  - TotalCount（検索結果総数）

**検索結果属性**
- **RelevanceScore**: 関連性スコア（0.0-1.0、小数点以下3桁）
- **SearchResult**: 検索結果コンテナ
  - ResultItems（検索結果アイテムリスト）
  - TotalCount（総件数）
  - SearchMetrics（検索性能メトリクス）
- **SearchRanking**: 検索結果ランキング情報
  - Position（順位）
  - Score（スコア値）
  - RankingFactors（ランキング要因）

**プライバシー関連**  
- **SearchableContentSettings**: 検索可能性設定
  - Drops（投稿の検索可能性 - boolean）
  - Profile（プロフィールの検索可能性 - boolean）
  - AllowInPublicTimeline（公開タイムラインでの表示 - boolean）
  - AllowInRecommendations（推薦機能での表示 - boolean）
- **PrivacyLevel**: プライバシーレベル（PUBLIC/FRIENDS/PRIVATE）

**ハッシュタグ関連**
- **Hashtag**: 正規化ハッシュタグ
  - Value（#を除いた文字列、最大100文字）
  - NormalizedValue（小文字化・記号除去済み）
  - 日本語・英語・数字・基本記号のみ許可
- **TrendingScore**: トレンドスコア（0.0-1.0、小数点以下4桁精度）
- **UsageStatistics**: 使用統計情報
  - Count24h（24時間以内使用回数）
  - Count7d（7日間以内使用回数）
  - GrowthRate（成長率パーセント）

**時刻・数値**
- **CreatedAt**: 作成日時（UTC、ミリ秒精度）
- **UpdatedAt**: 更新日時（UTC、ミリ秒精度）
- **SearchExecutedAt**: 検索実行日時（UTC、パフォーマンス分析用）
- **IndexLastUpdatedAt**: インデックス最終更新日時（同期管理用）

### Domain Services

#### SearchPrivacyPolicy
**責務**: 検索プライバシーポリシーを適用し、GDPR準拠の検索可能性制御を統一的に管理
- **メソッド**:
  - `shouldIndex(settings SearchableContentSettings, content Content)`: コンテンツのインデックス対象可否判定
  - `filterResults(results []SearchResult, viewerID UserID)`: 検索結果のプライバシーフィルタリング
  - `applyGDPRCompliance(userID UserID)`: GDPR準拠処理と忘れられる権利の実装
  - `canViewInSearchResults(content Content, viewer User)`: 検索結果での表示可否判定
  - `validatePrivacySettings(settings SearchableContentSettings)`: プライバシー設定の妥当性検証

#### HashtagExtractor
**責務**: テキストからハッシュタグを抽出・正規化し、統一的なハッシュタグ処理を提供
- **メソッド**:
  - `extract(text string) []Hashtag`: テキストからハッシュタグを抽出
  - `normalize(hashtag string) string`: ハッシュタグの正規化処理
  - `validate(hashtag string) bool`: ハッシュタグの妥当性検証
  - `deduplicateHashtags(hashtags []Hashtag) []Hashtag`: 重複ハッシュタグの除去

#### TrendingCalculator  
**責務**: ハッシュタグのトレンドスコアを多次元で計算し、リアルタイムトレンド分析を提供
- **メソッド**:
  - `calculate(usage UsageStatistics, timeWindow TimeWindow) TrendingScore`: 多次元トレンドスコア計算
  - `getTopTrending(limit int, region string) []TrendingHashtag`: 地域別トップトレンド取得
  - `shouldUpdateScore(lastCalculated time.Time) bool`: スコア更新必要性判定
  - `calculateGrowthRate(current, previous int) float64`: 成長率計算
  - `applyTimeDecay(score float64, age time.Duration) float64`: 時間減衰の適用

#### QueryOptimizer
**責務**: 検索クエリの最適化と検索バックエンドに応じた最適な実行戦略の選択
- **メソッド**:
  - `optimizeForMeiliSearch(query SearchQuery) OptimizedQuery`: MeiliSearch用クエリ最適化
  - `optimizeForPostgreSQL(query SearchQuery) OptimizedQuery`: PostgreSQL FTS用クエリ最適化
  - `selectBestBackend(query SearchQuery, backends []SearchBackend) SearchBackend`: 最適バックエンド選択
  - `analyzeQueryComplexity(query SearchQuery) ComplexityScore`: クエリ複雑度分析
  - `generateExecutionPlan(query SearchQuery) ExecutionPlan`: 実行プラン生成

#### RankingAlgorithm
**責務**: 検索結果の関連性ランキングアルゴリズムを実装し、多要素によるスコア計算を管理
- **メソッド**:
  - `calculateRelevanceScore(document SearchDocument, query SearchQuery) RelevanceScore`: 関連性スコア計算
  - `applyPersonalization(results []SearchResult, userID UserID) []SearchResult`: パーソナライゼーション適用
  - `combineRankingFactors(factors RankingFactors) float64`: ランキング要因の統合
  - `adjustForRecency(score float64, createdAt time.Time) float64`: 新しさ要因の調整
  - `boostPopularContent(score float64, engagement EngagementMetrics) float64`: 人気コンテンツのブースト

## ユースケース

### Core Search Use Cases

#### Drop検索実行 (MeiliSearch)

1. ユーザーが検索ボックスに「新年の抱負」などのキーワードを入力し、Drop検索を実行
2. フロントエンドはデバウンス処理（300ms）を実行し、リアルタイム検索UXを向上
3. avion-gateway経由でavion-searchのSearchDrops gRPC APIにリクエスト送信（JWT認証必須）
4. SearchHandlerがリクエストを受信し、RequestID重複チェックで冪等性を確保
5. DropSearchUseCaseが処理を受け取り、ビジネスロジック調整を開始
6. SearchQueryValidatorがキーワード長（最大100文字）、禁止文字、インジェクション攻撃をチェック
7. QueryOptimizerがMeiliSearch用に検索クエリを最適化
8. SearchPrivacyPolicyがSearchableContentSettingsを適用し、検索可能Dropをフィルタリング
9. AccessControlServiceがユーザー権限に基づくSearchFilterを生成
10. SearchResultCacheで同一クエリのキャッシュを確認（TTL: 5分）
11. DropSearchRepositoryがMeiliSearchに検索実行（検索時間測定）
12. RankingAlgorithmが関連性スコアを計算し、結果を順序付け
13. SearchResultFactoryがSearchResultバリューオブジェクトを構築
14. SearchHistoryにクエリを記録（プライバシー設定考慮）
15. 検索結果をgRPCレスポンスに変換しクライアントに返却

#### ユーザー検索実行 (MeiliSearch)

1. ユーザーが検索ボックスに「@tanaka」や「田中太郎」を入力しユーザー検索実行
2. フロントエンドがデバウンス処理（300ms）でリアルタイム検索体験を提供
3. avion-gateway経由でSearchUsers gRPC APIにリクエスト送信
4. UserSearchUseCaseがリクエスト処理とビジネスロジック調整を開始
5. SearchQueryValidatorがユーザー名パターン、文字制限、特殊文字を検証
6. QueryOptimizerがユーザー検索用のクエリ最適化を実行
7. UserPrivacyPolicyが検索可能性設定を確認し、対象ユーザーをフィルタリング
8. UserSearchCacheでキャッシュ確認（TTL: 2分）
9. UserSearchRepositoryがMeiliSearchでUserSearchDocumentを検索
10. RankingAlgorithmがフォロワー数、活動度、関係性を考慮したスコアリング実行
11. BlockedUserFilterでブロック済みユーザーを除外
12. UserEnrichmentServiceが追加情報（プロフィール画像、フォロワー数）を並行取得
13. 検索結果をキャッシュに保存し、gRPCレスポンスとして返却

#### インデックス更新処理 (Drop作成時)

1. ユーザーが新しいDropを作成（avion-dropで処理）
2. avion-dropがDrop作成完了後、drop_createdイベントをRedis Streamに発行
3. EventConsumerHandlerが専用Consumer Groupでイベントを購読
4. EventDeduplicationServiceがEventIDで重複チェック実行
5. IndexUpdateUseCaseがイベント処理とビジネスロジック調整を開始
6. EventValidatorがイベントデータの形式・必須フィールドを検証
7. DropSearchDocumentFactoryがイベントからDropSearchDocumentを生成
8. HashtagExtractorがDrop本文からハッシュタグを抽出・正規化
9. MentionExtractorがメンション情報を抽出してMentionIndexを構築
10. SearchPrivacyPolicyでユーザーのプライバシー設定を確認
11. 対象の場合、SearchIndexRepositoryでDropSearchDocumentをMeiliSearchに永続化
12. HashtagIndexを更新してハッシュタグ別のDrop数を集計
13. TrendingCalculatorでハッシュタグのTrendingScoreを再計算
14. IndexOperationRepositoryで操作履歴をEvent Sourcingパターンで記録
15. 処理完了メトリクスを記録（平均処理時間200ms以下の目標）

### Extended Use Cases

#### トレンドハッシュタグ表示

1. ユーザーがメインページでトレンドセクションを表示
2. フロントエンドがavion-gateway経由でGetTrends APIにリクエスト送信
3. GetTrendsQueryUseCaseがトレンド取得ビジネスロジックを調整
4. TrendsCacheServiceでキャッシュ確認（TTL: 10分）
5. TrendingCalculatorが過去24時間のハッシュタグ使用頻度を集計
6. 過去7日間との比較で急上昇トレンドを検出
7. 地域別（日本、グローバル）トレンド分析を実行
8. BotDetectorでスパムハッシュタグをフィルタリング
9. TrendScoreCalculatorが多次元スコア計算（使用頻度、成長率、多様性、時間減衰）
10. RegionalTrendAnalyzerでユーザー地域に応じたローカライゼーション
11. TrendingContentEnricherで代表的なDropサンプルを取得
12. TrendFilterPolicyでNSFW・政治的センシティブトレンドをフィルタ
13. 上位20件のトレンドを選定（地域別・全体別）
14. レスポンス形式に変換（ハッシュタグ、スコア、使用回数、成長率、サンプルDrop、地域）
15. フロントエンドにトレンドリストを返却（クリック可能、成長率表示）

#### ユーザー推薦表示

1. ユーザーがサイドバーでおすすめユーザーセクションを表示
2. フロントエンドがGetRecommendedUsers APIにリクエスト送信
3. GetRecommendedUsersQueryUseCaseが推薦ビジネスロジックを調整
4. UserRecommendationCacheでパーソナライズキャッシュ確認（TTL: 30分）
5. RecommendationContextBuilderでユーザーコンテキスト情報を構築（フォロー関係、Drop内容、検索履歴、リアクション傾向）
6. UserRecommendationEngineが以下アルゴリズムで分析実行：
   - 協調フィルタリング（類似フォロー傾向）
   - コンテンツベースフィルタリング（興味関心類似性）
   - ソーシャルグラフ分析（Friend of Friends）
   - アクティビティ相関（同一ハッシュタグ、同一Dropリアクション）
7. UserInteractionAnalyzerで過去インタラクション分析（メンション、リアクション、検索クリック履歴）
8. RecommendationScorerで多次元スコアリング（興味マッチ度、活動レベル、フォロワー品質、地理的近接性）
9. DiversityOptimizerで推薦多様性確保（同一クラスタ偏重防止）
10. AlreadyConnectedFilterで既フォローユーザーを除外
11. BlockedUserFilterでブロック済み・ブロックされたユーザーを除外
12. 上位30件から20件をランダムサンプリング（セレンディピティ向上）
13. UserEnrichmentServiceで追加情報並行取得（プロフィール画像、最新Drop、フォロワー数、共通フォロー数）
14. レスポンス形式に変換（推薦理由、信頼度スコア含む）
15. フロントエンドにおすすめユーザーリスト表示（フォローボタン、推薦理由付き）

#### プライバシー設定更新

1. ユーザーが設定画面で検索可能性オプションを変更
2. avion-userが設定更新後、UserSearchPrivacyUpdatedイベントをRedis Streamに発行
3. SearchPrivacyHandlerが専用Consumer Groupでイベントを受信
4. EventDeduplicationServiceで重複処理防止
5. UpdateSearchPrivacyCommandUseCaseがプライバシー更新ビジネスロジックを調整
6. SearchableContentSettingsValidatorで設定値妥当性検証
7. SettingsChangeAnalyzerで前回設定との差分分析
8. UserSearchPrivacyRepositoryでSearchableContentSettingsを更新・永続化
9. 設定変更に応じたインデックス更新処理実行：
   - drops: false→true時は過去Dropをバッチインデックス追加
   - drops: true→false時は既存Dropをインデックスから一括削除
   - profile: false→true時はUserSearchDocumentをインデックス追加
   - profile: true→false時はUserSearchDocumentをインデックス削除
10. PrivacyImpactCalculatorで影響範囲計算（対象Drop数、推定処理時間）
11. 大量データの場合はBatchProcessingQueueでバックグラウンド処理スケジュール
12. SearchPrivacyPolicyを既存インデックスデータに適用
13. UserRecommendationIndexから該当ユーザーを追加/除外
14. SearchHistoryCleanerで他ユーザー検索履歴から該当ユーザー削除（GDPR対応）
15. ProcessingStatusNotifierで処理完了をユーザーに通知

#### 検索履歴とサジェスト

1. ユーザーが検索ボックスで文字入力開始
2. フロントエンドがGetSearchSuggestions APIを呼び出し
3. GetSearchSuggestionsQueryUseCaseがサジェスト生成ビジネスロジック調整
4. SearchHistoryから該当ユーザーの検索履歴を取得
5. 入力文字列に基づくマッチング実行（前方一致・部分一致）
6. 頻出キーワード分析で使用頻度によるスコアリング
7. TrendingHashtagsから人気ハッシュタグをサジェスト候補に追加
8. PersonalizationEngineでユーザーの興味関心に基づくカスタマイズ
9. DuplicateRemoverで重複サジェストを除去
10. 上位10件のサジェストを選定・スコア順でソート
11. サジェストリストをクライアントに返却
12. フロントエンドがリアルタイムサジェスト表示（キーボードナビゲーション対応）

#### 保存検索実行

1. ユーザーが保存した検索条件を選択
2. ExecuteSavedSearchQueryUseCaseが起動・ビジネスロジック調整
3. SavedSearchEntityから検索条件とフィルタを取得
4. 保存されたSearchQueryとSearchFilterを使用して検索実行
5. 前回実行時からの新着結果を識別
6. 新着マッチがある場合は通知イベント発行（avion-notification連携）
7. LastExecutedAtタイムスタンプを更新
8. 検索結果とともに新着件数情報をクライアントに返却

## 機能要求

### ドメインロジック要求

* **検索処理の統合**: SearchQueryとSearchFilterバリューオブジェクトによる統一的な検索条件管理と、複数バックエンド（MeiliSearch/PostgreSQL）の透明な切り替え
* **インデックス管理**: SearchIndexAggregateによる整合性保証と、IndexOperationAggregateを使用したトランザクション境界管理
* **プライバシー制御**: SearchableContentSettingsによる細かい検索可能性制御と、GDPR準拠の忘れられる権利実装
* **トレンド分析**: HashtagIndexAggregateによるリアルタイムトレンド計算と、TrendingCalculatorによる多次元スコアリング
* **推薦システム**: UserRecommendationAggregateによる協調フィルタリング・コンテンツベースフィルタリング・ソーシャルグラフ分析の統合

### APIエンドポイント要求

* **Drop検索API**: SearchDrops gRPC API（認証必須、ページネーション対応、最大100件/ページ）
* **ユーザー検索API**: SearchUsers gRPC API（認証必須、ページネーション対応、最大100件/ページ）
* **トレンドAPI**: GetTrends gRPC API（地域フィルタ対応、キャッシュTTL: 10分）
* **推薦API**: GetRecommendedUsers gRPC API（パーソナライゼーション、最大20件）
* **エラーハンドリング**: 統一的なエラーレスポンス形式（エラーコード、メッセージ、リクエストID）
* **レート制限**: ユーザーあたり300req/min、バーストで600req/min許可

### データ要求

* **SearchDocument**: DropSearchDocumentとUserSearchDocumentのバリデーション（最大文字数、必須フィールド）
* **インデックスデータ**: MeiliSearchとPostgreSQLでの一貫したデータ形式と、検索バックエンド間での透明な移行
* **履歴データ**: SearchHistoryは最大1000件、30日間保持、GDPR準拠の削除機能
* **キャッシュデータ**: Redis使用、検索結果（TTL: 5分）、トレンド（TTL: 10分）、推薦（TTL: 30分）
* **アーカイブポリシー**: 24時間以上未使用のハッシュタグ自動アーカイブ、削除データの確実な同期

## 技術的要求

### レイテンシ

* **検索API応答時間**: p50 100ms以下、p99 500ms以下（MeiliSearch性能に依存）
* **インデックス更新遅延**: 平均1分以下、p99で5分以下
* **トレンド計算**: リアルタイム更新、10分間隔でのバッチ処理
* **推薦生成**: 初回30秒以内、キャッシュヒット時100ms以下
* **バッチ処理**: インデックス再構築で1万件/分の処理性能

### 可用性

* **目標可用性**: 99.9%（年間8.76時間のダウンタイム）
* **Kubernetes戦略**: 最小3レプリカ、Rolling Update戦略採用
* **障害対応**: MeiliSearch障害時のPostgreSQL FTSへの自動フェイルオーバー
* **ヘルスチェック**: /health、/readinessエンドポイント提供
* **グレースフルシャットダウン**: 30秒以内の安全な停止処理

### スケーラビリティ

* **クエリ処理能力**: 1秒あたり10,000クエリまで処理、水平スケールで線形拡張
* **インデックス処理**: 1秒あたり1,000件のインデックス操作をサポート
* **メモリ使用量**: 1レプリカあたり512MB-2GB、クエリ負荷に応じた動的調整
* **CPUリソース**: 1レプリカあたり0.5-2vCPU、検索負荷に応じたオートスケール
* **ストレージ**: インデックスサイズの線形増加に対応、圧縮率70%以上維持

### セキュリティ

* **入力検証**: SQLインジェクション・XSS対策、最大文字数制限、禁止文字フィルタ
* **アクセス制御**: JWT認証必須、ユーザー権限に基づくフィルタリング
* **データ保護**: 検索履歴のハッシュ化、機密情報の暗号化（AES-256）
* **監査ログ**: 検索クエリ・プライバシー設定変更・管理操作のログ記録
* **GDPR準拠**: 忘れられる権利の実装、データポータビリティ対応

### データ整合性

* **インデックス同期**: 元データ（PostgreSQL）との定期的整合性チェック、差分検出・自動修復
* **トランザクション境界**: IndexOperationAggregateによる操作の原子性保証
* **冪等性**: EventIDによる重複処理防止、リトライ時の副作用排除  
* **削除同期**: データ削除イベントの確実な処理、削除データの検索結果からの即座除外
* **バックアップ**: インデックスデータの日次バックアップ、ポイントインタイム復旧対応

### その他技術要件

* **ステートレス設計**: アプリケーション状態の外部依存、水平スケール対応
* **Observability**: OpenTelemetryによるトレーシング・メトリクス・構造化ログ
* **構成管理**: 環境変数による設定、Kubernetes ConfigMap/Secret活用
* **外部依存性**: MeiliSearch（99.5% SLA）、PostgreSQL（99.9% SLA）、Redis（99.5% SLA）
* **テスト要件**: 単体テスト80%以上、統合テスト、性能テスト（負荷・ストレステスト）
  - テスト実装については[共通テスト戦略](../common/testing-strategy.md)を参照

## 決まっていないこと

### 基本機能に関する未決定事項

* **MeiliSearch詳細設定**:
  - 日本語トークナイザーの具体的な選択（kuromoji相当の最適設定）
  - ランキングルールのカスタマイズ戦略（関連性、人気度、新しさの重み付け）
  - 同義語辞書の構築・メンテナンス方法
  - SearchIndexRepositoryの実装詳細とエラーハンドリング戦略
* **PostgreSQL FTS設定（2ndリリース以降）**:
  - pg_bigm vs pg_trgmの選択基準と性能比較
  - 日本語辞書（MeCab連携）の設定・更新プロセス
  - インデックスタイプ（GIN vs GiST）の選択と最適化
  - PostgreSQLSearchRepositoryの実装詳細
* **検索バックエンド切り替え**:
  - バックエンド切り替えのタイミングとトリガー条件
  - 設定ベースの切り替えメカニズムの実装詳細
  - パフォーマンス劣化時の自動フェイルバック戦略

### 拡張機能に関する未決定事項

* **ハッシュタグトレンド機能**:
  - TrendingCalculatorのアルゴリズム詳細（時間減衰係数、重み付け戦略）
  - HashtagIndexのデータ保存先選択（MeiliSearch内 vs 外部Redis/PostgreSQL）
  - 地域別トレンド分析の地域区分定義と判定ロジック
* **プライバシー・GDPR対応**:
  - SearchPrivacyPolicyの具体的実装とGDPR削除処理フロー
  - 「忘れられる権利」実行時の関連データ特定・削除範囲
  - プライバシー設定変更時の大量インデックス更新の性能最適化
* **推薦システム**:
  - 協調フィルタリングアルゴリズムの詳細選択（Matrix Factorization vs Item-based）
  - 推薦結果の多様性確保アルゴリズム（MMRなど）
  - A/Bテストによる推薦アルゴリズム評価・改善プロセス
* **運用・監視**:
  - 検索結果品質の定量的監視指標とアラート設定
  - インデックス再構築の実行タイミングと自動化戦略
  - 検索性能劣化時の自動調整メカニズム