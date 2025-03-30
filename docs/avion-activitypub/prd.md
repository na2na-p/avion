# PRD: avion-activitypub

## 概要

AvionをActivityPubプロトコルに対応させ、他の互換サーバー（仕様書内の用語定義に基づき「Terminal」と呼ぶ）との連合（Federation）を実現するためのマイクロサービスを実装する。

## 背景

Avionを単一の独立したSNSではなく、Mastodonなどが存在する広大な分散型ソーシャルネットワーク（Fediverse）の一部として機能させるためには、ActivityPub標準への準拠が不可欠である。これにより、Avionユーザーは他のTerminalのユーザーをフォローしたり、投稿を共有したり、リアクションを送受信したりできるようになり、プラットフォームの価値とリーチが大幅に向上する。この連合機能を専門に扱うマイクロサービスを設けることで、複雑なプロトコル処理を他のコアサービスから分離する。

## Scientific Merits

*   **相互運用性の獲得:** ActivityPubに対応することで、既存の数十万〜数百万ユーザーを抱えるFediverseエコシステムとの接続が可能になる。
*   **ネットワーク効果の活用:** 他のTerminalのユーザーとのインタラクションを通じて、Avion自体のユーザーエンゲージメントを高めることができる。
*   **分散化と堅牢性:** 中央集権的なプラットフォームへの依存を減らし、よりオープンで検閲耐性のあるコミュニケーション基盤に貢献する。
*   **開発の焦点分離:** ActivityPubという専門的で複雑なプロトコル処理を本サービスに集約することで、他のサービスは自身のコアロジックに集中できる。

定量化は難しいものの、ActivityPub対応はAvionを現代的な分散型SNSとして位置づける上で戦略的に重要であり、ユーザー体験とプラットフォームの可能性を大きく広げる。

## Design Doc

後で書く

## 参考ドキュメント

*   ActivityPub W3C Recommendation: [https://www.w3.org/TR/activitypub/](https://www.w3.org/TR/activitypub/)
*   ActivityStreams 2.0: [https://www.w3.org/TR/activitystreams-core/](https://www.w3.org/TR/activitystreams-core/)
*   WebFinger: [https://tools.ietf.org/html/rfc7033](https://tools.ietf.org/html/rfc7033)
*   HTTP Signatures: [https://tools.ietf.org/html/draft-cavage-http-signatures-12](https://tools.ietf.org/html/draft-cavage-http-signatures-12) (Note: Newer versions exist, but this is commonly referenced)
*   [Avion アーキテクチャ概要](./../architecture.md)

## 製品原則

*   **標準への準拠:** ActivityPub Coreおよび関連仕様 (ActivityStreams, WebFinger, HTTP Signatures) に可能な限り準拠し、高い相互運用性を目指す。
*   **シームレスな連合体験:** ローカルユーザーとリモートユーザー（他のTerminalのユーザー）の間のインタラクションを、可能な限り自然で区別なく行えるようにする。
*   **堅牢かつ効率的な通信:** 他のTerminalとのアクティビティ送受信を、エラーや遅延を考慮しつつ、確実かつ効率的に行う。

## やること/やらないこと

### やること

*   **Actorモデルの提供:**
    *   ローカルユーザーに対応するActivityPub Actorオブジェクトの提供 (Personタイプ)。
    *   Actor情報取得のための専用エンドポイント (`/users/{username}`)。
    *   WebFinger (`/.well-known/webfinger`) によるActor発見のサポート。
*   **Inbox処理:**
    *   他のTerminalからのActivityPubアクティビティを受信するInboxエンドポイント (`/inbox`, `/users/{username}/inbox`)。
    *   受信したアクティビティのHTTP Signatures検証。
    *   主要なアクティビティ (Create, Update, Delete, Follow, Accept, Reject, Announce, Like, Undo) の解釈と、関連するローカルサービスへの通知/連携 (例: Follow受信 -> `avion-user` へ通知)。
    *   受信したリモートActorやObject (Drop) の情報をキャッシュ/保存。
*   **Outbox処理:**
    *   ローカルユーザーのアクション (Drop作成、フォロー、リアクション等) に基づき、ActivityPubアクティビティを生成。
    *   生成したアクティビティを、関連するリモートActor (フォロワー等) のInboxへ配送するOutbox処理 (`/users/{username}/outbox` は主に読み取り用、配送は非同期バックグラウンドで行う)。
    *   配送時のHTTP Signaturesによる署名。
    *   配送効率化のための共有Inbox (Shared Inbox) の利用。
*   **非同期処理:**
    *   Outboxからのアクティビティ配送は、時間がかかる可能性があるため非同期キュー (Redis Streamなど) を介して行う。
    *   配送失敗時のリトライ機構。
*   **リモート情報の管理:**
    *   取得したリモートActorやリモートObject (Drop) の情報をキャッシュまたはデータベースに保存し、ローカルサービスから参照可能にする。
    *   リモートDropに含まれるメディアについて、`avion-media` サービスにキャッシュを依頼する。

### やらないこと

*   **ActivityPub Client-to-Server (C2S) プロトコル:** C2Sは実装しない。Avionのフロントエンドは通常のAPI (`avion-gateway` 経由) を利用する。
*   **全てのActivityPubアクティビティ/オブジェクトタイプの完全サポート (初期):** 初期リリースでは、SNSとして基本的なインタラクションに必要なタイプ (上記「やること」参照) に絞る。Question, Event, Groupなどは対象外。
*   **複雑なアクセス制御ロジック:** ActivityPubレベルでの細かなアクセス制御 (例: 特定のフォロワーにのみ公開) は初期では簡略化する可能性あり。Dropの公開範囲は主にローカルの仕組み (`avion-post`) で制御する。
*   **リレーサーバー機能:** Avionインスタンス自体が他のサーバーの投稿を中継するリレーとして機能することは、初期段階では実装しない。
*   **高度なスパム/不正行為対策:** ActivityPubレベルでの高度な対策は将来的な課題とする (基本的な署名検証やドメインブロック等は実装)。

## 対象ユーザ

*   Avion の他のマイクロサービス (`avion-user`, `avion-post`, `avion-timeline`, `avion-notification`, `avion-reaction`)
*   他のActivityPub互換サーバー (Terminal)
*   Avion 開発者・運用者 (設定、監視、トラブルシューティング)

## ユースケース

### リモートユーザーの発見とプロフィール表示

1.  ローカルユーザーが検索窓などにリモートユーザーのハンドル (`@userB@remote.server`) を入力する。
2.  フロントエンドは `avion-gateway` 経由で、リモートユーザー情報の取得を試みるリクエストを送信 (例: `/api/remote-users/lookup?handle=@userB@remote.server`)。
3.  リクエストを受けたサービス (Gateway or User?) は `avion-activitypub` に処理を依頼。
4.  `avion-activitypub` はまずローカルキャッシュ/DBに情報がないか確認。
5.  なければ、`remote.server` の `/.well-known/webfinger` に問い合わせて、ユーザーBのActor URLを取得する。
6.  取得したActor URLにアクセスし、ユーザーBのActor情報 (プロフィール、Inbox URLなど) を取得する。
7.  取得した情報をキャッシュ/DBに保存し、フロントエンドに返す。
8.  フロントエンドは情報をもとにリモートユーザーのプロフィールページのようなものを表示する。

### ローカルユーザーがリモートユーザーをフォローする

1.  ローカルユーザーAがリモートユーザーBのプロフィール画面で「フォロー」ボタンを押す。
2.  フロントエンドは `avion-gateway` 経由でフォローリクエストを送信 (`avion-user` が担当)。
3.  `avion-user` はフォロー対象がリモートユーザーであることを認識し、`avion-activitypub` にリモートフォロー処理を依頼。
4.  `avion-activitypub` はリモートユーザーBのActor情報 (特にInbox URL) をキャッシュ/DBから取得 (なければWebFinger等で取得)。
5.  ローカルユーザーAをActorとする `Follow` アクティビティを生成する。
6.  生成したアクティビティにHTTP Signatureで署名し、リモートユーザーBのInbox URLへPOSTリクエストで送信する (非同期キュー経由)。
7.  `avion-user` 側では、フォロー状態を「リクエスト中」として記録する。

### リモートユーザーからのフォローリクエスト受信と承認

1.  リモートユーザーBがローカルユーザーAをフォローしようとし、リモートサーバーから `avion-activitypub` のInboxに `Follow` アクティビティが届く。
2.  `avion-activitypub` は受信したリクエストのHTTP Signatureを検証する。
3.  検証成功後、`Follow` アクティビティの内容 (Actor, Object) を解析する。
4.  `avion-user` に「ユーザーBからユーザーAへのフォローリクエストがあった」ことを通知する。
5.  `avion-user` (または設定に基づき `avion-activitypub`) がフォローを自動承認する場合:
    *   `Accept(Follow)` アクティビティ (元のFollowアクティビティを参照) を生成する。
    *   生成した `Accept` アクティビティに署名し、リモートユーザーBのInboxへ送信する (非同期キュー経由)。
    *   `avion-user` にフォロー関係が成立したことを通知する。

### ローカルDropのリモートフォロワーへの配信

1.  ローカルユーザーAが公開Dropを作成 (`avion-post` が処理)。
2.  `avion-post` はDrop作成イベントを発行。
3.  `avion-activitypub` はイベントを受信する。
4.  Drop情報とユーザーAのActor情報をもとに `Create(Note)` アクティビティを生成する。
5.  `avion-user` および `avion-activitypub` のキャッシュ/DBから、ユーザーAのリモートフォロワーのリストとそのInbox URL (またはShared Inbox URL) を取得する。
6.  各フォロワーのInbox (またはShared Inbox) 宛に、署名付きの `Create(Note)` アクティビティを非同期キューに入れて配送依頼する。

### リモートDropの受信とローカルタイムラインへの反映

1.  ローカルユーザーAがフォローしているリモートユーザーBがDropを作成し、その `Create(Note)` アクティビティがユーザーAのInbox (`avion-activitypub`) に届く。
2.  `avion-activitypub` は署名を検証し、アクティビティを解析する。
3.  リモートユーザーBの情報やDropの内容をローカルのキャッシュ/DBに保存・更新する (必要なら `avion-user`, `avion-post` と連携してローカル表現を作成)。
4.  `avion-timeline` に「ユーザーAのタイムラインにこの新しいリモートDropを追加すべき」というイベントを通知する。
5.  `avion-timeline` はイベントを受けて、ユーザーAのホームタイムラインキャッシュを更新する。
6.  (Dropが公開の場合) `avion-timeline` はグローバルタイムラインキャッシュも更新する。

## 機能要求

*   **WebFinger:** `/.well-known/webfinger` エンドポイントで `acct:` URIに対応し、ActorのプロファイルページのURLとActivityPub Actor URLを返すこと。
*   **Actorエンドポイント:** ユーザーのActor情報をActivityStreams 2.0形式 (JSON-LD) で返すこと。公開鍵情報を含むこと。
*   **Inboxエンドポイント:** POSTリクエストを受け付け、ActivityPubアクティビティを受信できること。共有Inbox (`/inbox`) とユーザー別Inbox (`/users/{username}/inbox`) をサポートすること。
*   **Outboxエンドポイント:** ユーザーのアクティビティ履歴をActivityStreams 2.0形式で提供すること (主にデバッグや他のサーバーからの参照用)。
*   **HTTP Signatures:** リクエストの署名・検証を正しく実装すること。鍵ペアはユーザーごとに生成・管理すること (`avion-user` と連携)。
*   **アクティビティ処理:** Create, Update, Delete, Follow, Accept, Reject, Announce, Like, Undo の各アクティビティを適切に送受信・解釈・処理できること。
*   **オブジェクト表現:** Note, Person, Activity の各オブジェクトタイプをActivityStreams 2.0形式で正しく表現できること。
*   **非同期配送:** Outboxからのアクティビティ配送を、リトライ可能な非同期キューで行うこと。
*   **キャッシュ:** リモートActor/Objectの情報を効率的にキャッシュし、外部への問い合わせを減らすこと。

## 技術的要求

### レイテンシ

*   WebFinger, Actorエンドポイント: 平均 500ms 以下
*   Inbox受信処理: 非同期で完了すれば良いが、ACK応答は速やかに行う (例: 100ms以内)。
*   Outbox配送: 非同期。数分程度の遅延は許容される場合があるが、インタラクションの即時性が重要なものは数秒以内を目指す。

### 可用性

*   Inboxエンドポイントは常に利用可能である必要がある。Kubernetes上での運用を前提とし、複数レプリカによる冗長構成をとる。
*   WebFinger, Actorエンドポイントも高い可用性が求められる。
*   Outboxの配送処理は一時的に停止しても、キューイングされていれば後で再開可能。

### スケーラビリティ

*   受信するアクティビティ数、配送するアクティビティ数が増加しても対応できるように、Inbox/Outboxの処理ワーカーをスケールアウト可能にすること。
*   リモート情報のキャッシュ/DBアクセスがボトルネックにならないようにすること。
*   非同期キューのスループットが十分であること。

### セキュリティ

*   **HTTP Signatures:** 署名の検証を厳密に行い、なりすましを防ぐ。秘密鍵を安全に管理する。
*   **入力検証:** 受信したアクティビティの内容を検証し、不正なデータやDoS攻撃に繋がる可能性のあるものを適切に処理する (例: HTMLサニタイズ、サイズの制限)。
*   **アクセス制御:** Inbox/Outboxへの不正アクセスを防ぐ。
*   **ドメインブロック:** 不審なTerminalからの通信を拒否する機能。

### 相互運用性

*   主要なActivityPub実装 (Mastodon等) との送受信テストを行い、互換性の問題を特定・修正する。

### その他技術要件

*   **ステートレス:** サービス自体は状態を持たず、水平スケールが可能であること。リモート情報のキャッシュや配送キューはRedis等で管理する。
*   **Observability:** OpenTelemetry SDKを導入し、トレース・メトリクス・ログを出力可能にすること。Inbox受信時やローカルイベント受信時にトレースを開始/継続し、他のサービスへの問い合わせやOutbox配送時にもコンテキストを伝播すること。

## 決まっていないこと

*   使用するGo言語のActivityPubライブラリ/フレームワークの選定。
*   HTTP Signaturesの鍵ローテーション戦略。
*   非同期キューイングシステムの具体的な選択 (Redis Stream, RabbitMQ, NATSなど)。
*   リモート情報のキャッシュ戦略とDBスキーマの詳細。
*   エラーハンドリング、リトライ、デッドレターキューの具体的な実装。
*   共有Inboxの利用ポリシー (どの程度のフォロワー数から利用するかなど)。
*   サポートするActivityPub拡張や独自拡張の有無。
