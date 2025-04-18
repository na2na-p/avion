# PRD: avion-search

## 概要

Avionにおける投稿（Drop）やユーザーの検索機能を提供するマイクロサービスを実装する。MeiliSearchと連携した全文検索、およびオプションとしてPostgreSQLの全文検索機能を利用した検索を提供し、効率的な検索を実現する。

## 背景

ユーザー数や投稿数が増加するにつれて、特定の情報（過去のDrop、特定のユーザー）を見つけ出すことが困難になる。キーワードによる検索機能を提供することで、ユーザーは目的の情報に素早くアクセスできるようになり、プラットフォームの利便性が向上する。検索処理は専門的な技術（形態素解析、転置インデックス、ランキング）を要するため、独立したステートレスなマイクロサービスとして実装し、外部の全文検索エンジン (MeiliSearch) やデータベース (PostgreSQL) の検索機能を利用するのが適切である。

## Scientific Merits

*   **利便性の向上:** ユーザーが必要な情報（Drop、ユーザー）を簡単に見つけられるようになり、ユーザー満足度が向上する。
*   **情報発見の促進:** 検索を通じて、ユーザーは新たなユーザーや興味深いDropを発見する機会を得られる。
*   **関心の分離:** 検索という専門的な処理を他のサービスから分離し、各サービスの責務を明確にする。MeiliSearchやPostgreSQLとの連携ロジックを集約できる。
*   **スケーラビリティ:** 検索クエリの負荷に応じて本サービスをスケールさせることが可能。検索エンジン (MeiliSearch) やデータベース (PostgreSQL) も独立してスケール可能。
*   **ステートレス:** 本サービス自体はデータを持たず、状態を外部 (MeiliSearch, PostgreSQL, Redis) に依存するため、デプロイやスケールが容易になる。

検索機能は必須ではないものの、ユーザー体験を大幅に向上させる重要な機能であり、特に大規模なSNSにおいてはその価値が高い。

## Design Doc

後で書く

## 参考ドキュメント

*   [Avion アーキテクチャ概要](./../architecture.md)

## 製品原則

*   **関連性の高い結果:** 検索キーワードに対して、最も関連性の高いDropやユーザーを上位に表示する。
*   **高速な応答:** 検索クエリに対して、迅速に結果を返す。
*   **簡単な操作:** シンプルなキーワード入力で検索を実行できること。

## やること/やらないこと

### やること

*   **MeiliSearch連携:**
    *   Drop/Userの作成・更新・削除イベントをリッスンし、MeiliSearchにドキュメントを追加・更新・削除する。
    *   キーワードを受け取り、MeiliSearchに検索クエリを発行するAPIを提供。
*   **(オプション) PostgreSQL全文検索連携:**
    *   キーワードを受け取り、PostgreSQLの全文検索機能 (`tsvector`, `tsquery`) を使ってDrop/Userを検索するAPIを提供。
*   **検索APIの提供:**
    *   検索バックエンド (MeiliSearch or PostgreSQL) を選択可能な統一検索APIを提供。
    *   Drop検索API (キーワード、ページネーション、フィルタ)。
    *   ユーザー検索API (キーワード、ページネーション、フィルタ)。
*   **アクセス制御:** 検索結果には、検索を実行したユーザーが閲覧権限を持つもののみが含まれるように、検索クエリ発行時または結果取得後にフィルタリングを行う。

### やらないこと

*   **検索エンジン/DB自体の運用:** MeiliSearchやPostgreSQLの運用管理は本サービスの範囲外とする。
*   **データの永続化:** 本サービスはステートレスであり、検索インデックスや元データは保持しない。
*   **リアルタイムインデックス (厳密な意味で):** MeiliSearchへのインデックス反映には若干の遅延が発生することを許容する。PostgreSQL検索は比較的リアルタイム性が高い。
*   **複雑な検索構文のサポート (初期):** 初期リリースでは単純なキーワード検索を主とする。
*   **検索結果のパーソナライズ (初期):** ユーザーごとに検索結果を最適化するような高度なパーソナライズは初期段階では行わない。
*   **タイムラインの代替:** 検索機能はタイムライン表示を代替するものではない。

## 対象ユーザ

*   Avion エンドユーザー (API Gateway経由)
*   Avion の他のマイクロサービス (イベント発行元として: Post, User)
*   Avion 開発者・運用者

## ユースケース

### Dropの検索 (MeiliSearch利用時)

1.  ユーザーが検索ボックスにキーワードを入力し、Drop検索を実行する。
2.  フロントエンドは `avion-gateway` 経由で `avion-search` に検索リクエスト (キーワード, ページネーション情報, 認証JWT, backend=meilisearch) を送信する。
3.  `avion-search` は受け取ったキーワードでMeiliSearchにDrop検索クエリを発行する。アクセス制御のためのフィルタ条件 (例: `visibility = 'public' OR followers CONTAINS 'user_id'`) を付与する。
4.  MeiliSearchから返されたDropドキュメント (IDやスコアを含む) を取得する。
5.  (必要に応じて) `avion-post` から追加のDrop詳細情報を取得する。
6.  検索結果を整形し、フロントエンドに返す。
7.  フロントエンドは検索結果一覧を表示する。

(UIモック: 検索結果画面 - Dropタブ)

### ユーザーの検索 (MeiliSearch利用時)

1.  ユーザーが検索ボックスにキーワードを入力し、ユーザー検索を実行する。
2.  フロントエンドは `avion-gateway` 経由で `avion-search` に検索リクエスト (キーワード, ページネーション情報, 認証JWT, backend=meilisearch) を送信する。
3.  `avion-search` は受け取ったキーワードでMeiliSearchにユーザー検索クエリ (ユーザー名、表示名、プロフィールなどを対象) を発行する。
4.  MeiliSearchから返されたユーザードキュメント (IDやスコアを含む) を取得する。
5.  (必要に応じて) `avion-user` から追加のユーザー詳細情報を取得する。
6.  検索結果を整形し、フロントエンドに返す。
7.  フロントエンドは検索結果一覧を表示する。

(UIモック: 検索結果画面 - ユーザータブ)

### MeiliSearchインデックスの更新 (例: Drop作成)

1.  ユーザーが新しいDropを作成する (`avion-post` が処理)。
2.  `avion-post` はDrop作成イベントを発行する。イベントにはDrop ID, 本文, 作成者ID, 公開範囲などの情報が含まれる。
3.  `avion-search` はイベントを受信する (Redisキュー経由など)。
4.  `avion-search` はイベント情報をもとに、MeiliSearch用のドキュメントを作成する。アクセス制御に必要な情報 (作成者ID, 公開範囲) も含める。
5.  作成したドキュメントをMeiliSearchに追加/更新するリクエストを送る。

## 機能要求

*   **検索対象:** Dropの本文、ユーザーのユーザー名、表示名、プロフィールを検索対象とすること。
*   **MeiliSearchインデックス更新:** Dropやユーザーの作成・更新・削除イベントに応じて、MeiliSearchインデックスが準リアルタイムで更新されること。
*   **キーワード検索:** ユーザーが入力したキーワードに基づいて関連性の高い結果を返すこと。MeiliSearchの日本語設定を利用する。PostgreSQL検索の場合は適切な設定を行う。
*   **ページネーション:** 検索結果をページ単位で取得できること。
*   **アクセス制御:** 検索結果には、検索を実行したユーザーが閲覧権限を持つもののみが含まれること。
*   **API:** Drop検索用、ユーザー検索用の統一RESTful APIを提供すること。バックエンド選択パラメータ (`backend=meilisearch` or `backend=postgres`) を持つ。認証が必要な場合がある。

## 技術的要求

### レイテンシ

*   検索APIの応答時間: 平均 500ms 以下 (MeiliSearch/PostgreSQLの性能に依存)
*   MeiliSearchインデックス更新の遅延: 平均 1分 以下

### 可用性

*   検索APIは比較的高可用性が求められる。MeiliSearch/PostgreSQLの可用性に依存する。Kubernetes上での運用を前提とし、複数レプリカによる冗長構成をとる。
*   MeiliSearchへのインデックス更新処理は一時的に停止しても、後で追従できれば許容される場合がある (イベントキューで担保)。

### スケーラビリティ

*   検索クエリ数の増加に対応できるよう、本サービスのレプリカ数を調整可能にすること。
*   MeiliSearch/PostgreSQLがデータ量やクエリ負荷に応じてスケール可能であることを前提とする。
*   MeiliSearchへのインデックス更新処理のスループットがデータ増加に追従できること (ワーカー数を調整)。

### データ整合性

*   MeiliSearchインデックスと元のデータソース (PostgreSQL) の間に不整合が生じる可能性があるため、定期的な再インデックスや差分同期の仕組みを検討すること。
*   削除されたデータが検索結果に残り続けないように、削除イベントを確実に処理すること。

### その他技術要件

*   **ステートレス:** 本サービス自体は状態を持たず、水平スケールが可能であること。
*   **Observability:** OpenTelemetry SDKを導入し、トレース・メトリクス・ログを出力可能にすること。API Gatewayやイベント経由でトレースコンテキストを受け取り、MeiliSearch/PostgreSQLへの問い合わせ時にも伝播すること。

## 決まっていないこと

*   MeiliSearchの具体的な設定 (トークナイザー、ランキングルールなど)。
*   PostgreSQL全文検索の具体的な設定 (辞書、インデックスタイプなど)。
*   アクセス制御の実装詳細 (MeiliSearchのフィルタ vs アプリケーション層でのフィルタ)。
*   MeiliSearch/PostgreSQLのスキーマ詳細設計。
*   再インデックスや差分同期の具体的な戦略と実装方法。
*   イベントキューシステムの選定。
