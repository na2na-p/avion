# エラーカタログ: avion-search

**Last Updated:** 2025/08/19  
**Service:** Full-text Search Service

## 概要

avion-searchサービスで発生する可能性のあるエラーコード一覧とその対処法です。

## ドメイン層エラー

### SearchIndex関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| SEARCH_DOMAIN_INDEX_NOT_FOUND | 404 | NOT_FOUND | 検索インデックスが見つかりません | インデックス名を確認してください |
| SEARCH_DOMAIN_INDEX_ALREADY_EXISTS | 409 | ALREADY_EXISTS | 検索インデックスが既に存在します | 既存のインデックスを確認してください |
| SEARCH_DOMAIN_INVALID_INDEX_NAME | 400 | INVALID_ARGUMENT | インデックス名が不正です | インデックス名の規則を確認してください |
| SEARCH_DOMAIN_INDEX_CORRUPTION | 422 | INTERNAL | インデックスが破損しています | インデックスの再構築が必要です |
| SEARCH_DOMAIN_INDEX_LOCKED | 423 | UNAVAILABLE | インデックスがロックされています | ロックが解除されるまで待ってください |

### SearchQuery関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| SEARCH_DOMAIN_INVALID_QUERY | 400 | INVALID_ARGUMENT | 検索クエリが不正です | クエリ構文を確認してください |
| SEARCH_DOMAIN_QUERY_TOO_COMPLEX | 400 | INVALID_ARGUMENT | 検索クエリが複雑すぎます | クエリを簡略化してください |
| SEARCH_DOMAIN_QUERY_TOO_LONG | 400 | INVALID_ARGUMENT | 検索クエリが長すぎます | クエリを短縮してください |
| SEARCH_DOMAIN_EMPTY_QUERY | 400 | INVALID_ARGUMENT | 検索クエリが空です | 検索語を入力してください |
| SEARCH_DOMAIN_UNSUPPORTED_QUERY_TYPE | 400 | INVALID_ARGUMENT | サポートされないクエリタイプです | 対応するクエリタイプを使用してください |

### SearchResult関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| SEARCH_DOMAIN_NO_RESULTS | 404 | NOT_FOUND | 検索結果が見つかりません | 検索条件を変更してください |
| SEARCH_DOMAIN_RESULT_SET_TOO_LARGE | 413 | INVALID_ARGUMENT | 結果セットが大きすぎます | 検索条件を絞り込んでください |
| SEARCH_DOMAIN_INVALID_SORT_FIELD | 400 | INVALID_ARGUMENT | ソートフィールドが不正です | ソート可能なフィールドを使用してください |
| SEARCH_DOMAIN_INVALID_FILTER | 400 | INVALID_ARGUMENT | フィルターが不正です | フィルター条件を確認してください |

### Document関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| SEARCH_DOMAIN_DOCUMENT_NOT_FOUND | 404 | NOT_FOUND | ドキュメントが見つかりません | ドキュメントIDを確認してください |
| SEARCH_DOMAIN_DOCUMENT_ALREADY_EXISTS | 409 | ALREADY_EXISTS | ドキュメントが既に存在します | 既存のドキュメントを確認してください |
| SEARCH_DOMAIN_INVALID_DOCUMENT | 400 | INVALID_ARGUMENT | ドキュメントが不正です | ドキュメント形式を確認してください |
| SEARCH_DOMAIN_DOCUMENT_TOO_LARGE | 413 | INVALID_ARGUMENT | ドキュメントが大きすぎます | ドキュメントサイズを小さくしてください |
| SEARCH_DOMAIN_DOCUMENT_SCHEMA_MISMATCH | 400 | INVALID_ARGUMENT | ドキュメントスキーマが一致しません | スキーマを確認してください |

### Facet関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| SEARCH_DOMAIN_FACET_NOT_FOUND | 404 | NOT_FOUND | ファセットが見つかりません | ファセット名を確認してください |
| SEARCH_DOMAIN_INVALID_FACET | 400 | INVALID_ARGUMENT | ファセットが不正です | ファセット定義を確認してください |
| SEARCH_DOMAIN_FACET_LIMIT_EXCEEDED | 400 | INVALID_ARGUMENT | ファセット制限を超過しました | ファセット数を減らしてください |
| SEARCH_DOMAIN_UNSUPPORTED_FACET_TYPE | 400 | INVALID_ARGUMENT | サポートされないファセットタイプです | 対応するファセットタイプを使用してください |

### Analyzer関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| SEARCH_DOMAIN_ANALYZER_NOT_FOUND | 404 | NOT_FOUND | アナライザーが見つかりません | アナライザー名を確認してください |
| SEARCH_DOMAIN_INVALID_ANALYZER | 400 | INVALID_ARGUMENT | アナライザーが不正です | アナライザー設定を確認してください |
| SEARCH_DOMAIN_ANALYZER_CONFIGURATION_ERROR | 422 | INTERNAL | アナライザー設定エラー | 設定を見直してください |

## ユースケース層エラー

### 入力検証エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| SEARCH_USECASE_INVALID_INPUT | 400 | INVALID_ARGUMENT | 入力値が不正です | 入力値を確認してください |
| SEARCH_USECASE_MISSING_REQUIRED | 400 | INVALID_ARGUMENT | 必須項目が不足しています | 必須項目を入力してください |
| SEARCH_USECASE_INVALID_PAGINATION | 400 | INVALID_ARGUMENT | ページネーションが不正です | ページ設定を確認してください |
| SEARCH_USECASE_INVALID_LIMIT | 400 | INVALID_ARGUMENT | 制限値が不正です | 制限値を確認してください |

### 認証・認可エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| SEARCH_USECASE_UNAUTHORIZED | 401 | UNAUTHENTICATED | 認証が必要です | ログインしてください |
| SEARCH_USECASE_FORBIDDEN | 403 | PERMISSION_DENIED | アクセスが禁止されています | アクセス権限を確認してください |
| SEARCH_USECASE_INSUFFICIENT_PERMISSION | 403 | PERMISSION_DENIED | 権限が不足しています | 必要な権限を確認してください |

### ビジネスロジックエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| SEARCH_USECASE_CONFLICT | 409 | ABORTED | リソースの競合が発生しました | 時間をおいて再試行してください |
| SEARCH_USECASE_PRECONDITION_FAILED | 412 | FAILED_PRECONDITION | 事前条件を満たしていません | 事前条件を確認してください |
| SEARCH_USECASE_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |
| SEARCH_USECASE_QUOTA_EXCEEDED | 429 | RESOURCE_EXHAUSTED | クォータを超過しました | 使用量を確認してください |

### 検索処理エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| SEARCH_USECASE_SEARCH_TIMEOUT | 504 | DEADLINE_EXCEEDED | 検索がタイムアウトしました | 検索条件を絞り込んでください |
| SEARCH_USECASE_SEARCH_FAILED | 500 | INTERNAL | 検索に失敗しました | 検索システムを確認してください |
| SEARCH_USECASE_INDEX_UNAVAILABLE | 503 | UNAVAILABLE | インデックスが利用できません | インデックス状態を確認してください |
| SEARCH_USECASE_REINDEX_IN_PROGRESS | 503 | UNAVAILABLE | 再インデックス中です | 完了まで待ってください |

### インデックス管理エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| SEARCH_USECASE_INDEX_CREATION_FAILED | 500 | INTERNAL | インデックス作成に失敗しました | 設定を確認してください |
| SEARCH_USECASE_INDEX_DELETION_FAILED | 500 | INTERNAL | インデックス削除に失敗しました | 再試行してください |
| SEARCH_USECASE_INDEX_UPDATE_FAILED | 500 | INTERNAL | インデックス更新に失敗しました | 更新内容を確認してください |
| SEARCH_USECASE_BULK_OPERATION_FAILED | 500 | INTERNAL | バルク操作に失敗しました | バッチ処理を確認してください |

## インフラストラクチャ層エラー

### MeiliSearchエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| SEARCH_INFRA_MEILISEARCH_CONNECTION_FAILED | 503 | UNAVAILABLE | MeiliSearch接続失敗 | 接続設定を確認してください |
| SEARCH_INFRA_MEILISEARCH_ERROR | 502 | INTERNAL | MeiliSearchエラー | MeiliSearchログを確認してください |
| SEARCH_INFRA_MEILISEARCH_TIMEOUT | 504 | DEADLINE_EXCEEDED | MeiliSearchタイムアウト | タイムアウト設定を確認してください |
| SEARCH_INFRA_MEILISEARCH_UNAVAILABLE | 503 | UNAVAILABLE | MeiliSearchが利用できません | サービス状態を確認してください |

### データベースエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| SEARCH_INFRA_DATABASE_CONNECTION_FAILED | 503 | UNAVAILABLE | データベース接続失敗 | 接続設定を確認してください |
| SEARCH_INFRA_DATABASE_QUERY_FAILED | 500 | INTERNAL | クエリ実行失敗 | クエリを確認してください |
| SEARCH_INFRA_DATABASE_TRANSACTION_FAILED | 500 | INTERNAL | トランザクション失敗 | 再試行してください |
| SEARCH_INFRA_DATABASE_TIMEOUT | 504 | DEADLINE_EXCEEDED | データベースタイムアウト | クエリの最適化を検討してください |

### キャッシュエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| SEARCH_INFRA_CACHE_CONNECTION_FAILED | 503 | UNAVAILABLE | キャッシュ接続失敗 | 接続設定を確認してください |
| SEARCH_INFRA_CACHE_OPERATION_FAILED | 500 | INTERNAL | キャッシュ操作失敗 | 再試行してください |
| SEARCH_INFRA_CACHE_MISS | 404 | NOT_FOUND | キャッシュミス | キャッシュの再生成を待ってください |
| SEARCH_INFRA_CACHE_INVALIDATION_FAILED | 500 | INTERNAL | キャッシュ無効化失敗 | キャッシュシステムを確認してください |

### メッセージキューエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| SEARCH_INFRA_QUEUE_CONNECTION_FAILED | 503 | UNAVAILABLE | キュー接続失敗 | 接続設定を確認してください |
| SEARCH_INFRA_QUEUE_PUBLISH_FAILED | 500 | INTERNAL | メッセージ発行失敗 | 再試行してください |
| SEARCH_INFRA_QUEUE_CONSUME_FAILED | 500 | INTERNAL | メッセージ消費失敗 | メッセージ形式を確認してください |
| SEARCH_INFRA_QUEUE_FULL | 503 | UNAVAILABLE | キューが満杯です | しばらく待ってから再試行してください |

### 外部サービスエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| SEARCH_INFRA_USER_SERVICE_ERROR | 502 | INTERNAL | ユーザーサービスエラー | ユーザーサービスの状態を確認してください |
| SEARCH_INFRA_DROP_SERVICE_ERROR | 502 | INTERNAL | Dropサービスエラー | Dropサービスの状態を確認してください |
| SEARCH_INFRA_COMMUNITY_SERVICE_ERROR | 502 | INTERNAL | コミュニティサービスエラー | コミュニティサービスの状態を確認してください |

### インデックス同期エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| SEARCH_INFRA_SYNC_FAILED | 500 | INTERNAL | インデックス同期に失敗しました | 同期設定を確認してください |
| SEARCH_INFRA_SYNC_TIMEOUT | 504 | DEADLINE_EXCEEDED | インデックス同期がタイムアウトしました | タイムアウト設定を確認してください |
| SEARCH_INFRA_SYNC_CONFLICT | 409 | ABORTED | インデックス同期で競合が発生しました | 競合解決を行ってください |
| SEARCH_INFRA_DELTA_SYNC_FAILED | 500 | INTERNAL | 差分同期に失敗しました | 差分データを確認してください |

### ストレージエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| SEARCH_INFRA_STORAGE_CONNECTION_FAILED | 503 | UNAVAILABLE | ストレージ接続失敗 | 接続設定を確認してください |
| SEARCH_INFRA_STORAGE_READ_FAILED | 500 | INTERNAL | ストレージ読み取り失敗 | 再試行してください |
| SEARCH_INFRA_STORAGE_WRITE_FAILED | 500 | INTERNAL | ストレージ書き込み失敗 | 再試行してください |
| SEARCH_INFRA_STORAGE_QUOTA_EXCEEDED | 507 | RESOURCE_EXHAUSTED | ストレージ容量超過 | 容量を確認してください |

### ハンドラー層エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| SEARCH_HANDLER_BAD_REQUEST | 400 | INVALID_ARGUMENT | 不正なリクエスト | リクエスト形式を確認してください |
| SEARCH_HANDLER_INVALID_QUERY_PARAMS | 400 | INVALID_ARGUMENT | クエリパラメータが不正です | パラメータを確認してください |
| SEARCH_HANDLER_UNSUPPORTED_MEDIA_TYPE | 415 | INVALID_ARGUMENT | サポートされないメディアタイプ | Content-Typeを確認してください |
| SEARCH_HANDLER_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |
| SEARCH_HANDLER_SEARCH_SYNTAX_ERROR | 400 | INVALID_ARGUMENT | 検索構文エラー | 検索構文を確認してください |

## 関連ドキュメント

- [Avion エラーコード標準化ガイドライン](../common/errors/error-standards.md)
- [avion-search PRD](./prd.md)
- [avion-search Design Doc](./designdoc.md)