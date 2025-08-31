# PRD: avion-web

## 概要

AvionのWebフロントエンドとBFF機能を統合したNext.jsアプリケーションを実装する。ReactとTypeScriptを使用したCSR（Client-Side Rendering）ベースのSPAとして構築し、API RoutesでGraphQL APIとSSEによるリアルタイム更新を提供する。Progressive Web App（PWA）として実装し、Web Pushによるプッシュ通知にも対応する。

## 背景

ユーザーがAvionの各種機能を直感的に利用できるWebインターフェースと、マイクロサービスアーキテクチャの複雑性を吸収するBFF層が必要である。新規開発であることを考慮し、Next.jsを採用してフロントエンドとBFFを統合することで、開発効率の向上と運用コストの削減を図る。モダンなWeb技術（Next.js、TypeScript、GraphQL、PWA、SSE、Web Push）を採用し、開発効率とメンテナンス性、そしてネイティブアプリに近いユーザー体験を実現する。

## Scientific Merits

*   **開発効率の最大化:** フロントエンドとBFFの統合により、型定義の共有、ホットリロードの統一、単一リポジトリでの開発が可能となり、開発速度が30-40%向上する。
*   **パフォーマンスの最適化:** ネットワークホップの削減（4→2）、GraphQLによる必要なデータのみの取得、DataLoaderパターンによるN+1問題の解決により、レイテンシとトラフィックを削減。
*   **ユーザー体験の向上:** CSRによるスムーズな画面遷移、SSEによるリアルタイム更新、PWA化によるインストール可能性により、ネイティブアプリに近い体験を提供。
*   **運用効率の向上:** 管理するサービス数の削減、統一された技術スタック（TypeScript）により、運用コストとメンテナンス負荷を軽減。
*   **ドメインモデルの統一:** フロントエンドとBFFで共通のドメインモデルを使用することで、ビジネスロジックの一貫性を保証。

## Design Doc

[Design Doc: avion-web](./designdoc.md)

## 参考ドキュメント

*   [Avion アーキテクチャ概要](./../common/architecture.md)
*   [avion-gateway PRD](./../avion-gateway/prd-api-gateway-only.md)

## 製品原則

*   **直感的で使いやすい:** ユーザーが迷うことなく、主要な機能を簡単に見つけて操作できること。
*   **高速なレスポンス:** CSRによる画面遷移やデータ読み込みがスムーズで、ストレスなく利用できること。
*   **効率的なデータ取得:** GraphQLとDataLoaderによる最適化されたデータフェッチング。
*   **リアルタイム性:** SSEにより新しい情報（Drop、通知）がリアルタイムで反映されること。
*   **インストール可能:** PWAとしてデバイスにインストールして利用できること。
*   **一貫性のあるデザイン:** アプリケーション全体で統一感のあるデザイン言語と操作性を提供。
*   **アクセシビリティ:** 様々なユーザーが利用できるよう、アクセシビリティ標準（WCAG）への配慮。
*   **ドメイン駆動設計:** 統一されたドメインモデルを定義し、ビジネスロジックとUIロジックを適切に分離。

## やること/やらないこと

### やること

#### フロントエンド機能
*   **主要画面の実装:**
    *   ログイン/新規登録画面
    *   タイムライン表示画面（ホーム、ローカル、グローバルタブ切り替え、無限スクロール、SSEによるリアルタイム更新）
    *   Drop作成フォーム（テキスト入力、メディア添付UI、公開範囲選択）
    *   Drop詳細表示画面（Drop本体、リアクション表示/操作、返信表示）
    *   ユーザープロフィール画面（ユーザー情報、Drop一覧、フォロー/フォロワー表示）
    *   プロフィール編集画面
    *   通知一覧画面（SSEによる更新通知）
    *   検索画面（Drop検索、ユーザー検索）
    *   基本的な設定画面（パスワード変更、Passkey管理、TOTP管理、通知設定、Bot管理）
*   **PWA対応:** Web App Manifest、Service Worker実装
*   **Web Push購読/受信:** プッシュ通知の実装
*   **レスポンシブデザイン:** デスクトップ、タブレット、スマートフォン対応
*   **基本的なアクセシビリティ対応:** セマンティックHTML、キーボード操作、適切なコントラスト

#### BFF機能（API Routes）
*   **GraphQL API実装:**
    *   Query（タイムライン、プロフィール、通知等）
    *   Mutation（Drop作成、リアクション、フォロー等）
    *   GraphQL Playground（開発環境）
*   **SSEエンドポイント:** リアルタイム更新配信
*   **データ集約:** 複数バックエンドサービスからのデータ取得と集約
*   **DataLoaderパターン:** バッチング最適化
*   **キャッシング戦略:** 効率的なデータキャッシュ
*   **エラーハンドリング:** 統一されたエラー処理

### やらないこと

*   **SSR/SSG:** CSRベースのSPAとして実装（SEO要件は将来検討）
*   **ネイティブモバイルアプリ:** Webアプリケーションに特化
*   **直接的なデータ永続化:** バックエンドサービスに委譲
*   **複雑なビジネスロジック:** バックエンドサービスが担当
*   **高度な管理機能:** 管理者向けダッシュボードは対象外
*   **高度なオフライン機能（初期）:** 基本的なキャッシュのみ
*   **WebSocket:** SSEで十分なため実装しない

## 対象ユーザ

*   Avion エンドユーザー
*   Avion Web開発者
*   GraphQL APIを利用するサードパーティ開発者（将来的）

## ドメインモデル (DDD戦術的パターン)

### Aggregates (集約)

#### ViewState Aggregate
**責務**: アプリケーション全体の表示状態を管理し、UIの一貫性を保証
- **集約ルート**: ViewState
- **不変条件**:
  - 現在のルートと表示内容が一致する
  - 認証状態と表示可能な画面が一致する（未認証時は公開画面のみ）
  - ローディング状態とデータ取得状態が同期する
  - モーダルは同時に1つまでしか表示されない
  - タブの選択状態は定義された値のいずれか
  - 画面遷移履歴は最大100件まで保持
  - エラー状態とローディング状態は同時に存在しない
  - フォーカス要素は画面内に存在する要素のみ
  - スクロール位置は0以上、コンテンツ高さ以下
  - テーマ（light/dark/auto）は定義された値のいずれか
  - 言語設定はサポート言語リストに含まれる
  - レスポンシブブレークポイントは定義された値のいずれか
- **ドメインロジック**:
  - `navigate(route)`: ルート遷移と履歴管理
  - `openModal(modalType, data)`: モーダル表示制御
  - `setLoading(key, value)`: ローディング状態の更新
  - `setError(error)`: エラー状態の設定
  - `updateTheme(theme)`: テーマ切り替え
  - `canAccess(route)`: ルートアクセス権限判定
  - `recordInteraction(event)`: ユーザー操作の記録
  - `restoreScrollPosition(route)`: スクロール位置の復元

#### UserSession Aggregate
**責務**: ユーザーの認証情報とセッション状態を安全に管理
- **集約ルート**: UserSession
- **不変条件**:
  - SessionIDは一意でUUID v4形式
  - AuthTokenは有効期限内である（最大24時間）
  - RefreshTokenは有効期限内である（最大30日）
  - UserIDとAuthTokenのユーザーIDが一致する
  - セッション作成時刻は現在時刻以前
  - 最終アクティブ時刻は作成時刻以降
  - 認証方法（password/passkey/totp）は定義された値のいずれか
  - デバイスフィンガープリントは32文字のハッシュ値
  - IPアドレスは有効なIPv4またはIPv6形式
  - UserAgentは1000文字以内
  - セッションステータスは（active/expired/revoked）のいずれか
  - 同時ログインセッション数は最大5つまで
- **ドメインロジック**:
  - `authenticate(credentials)`: 認証処理
  - `refresh()`: トークンリフレッシュ
  - `revoke()`: セッション無効化
  - `updateActivity()`: 最終アクティブ時刻更新
  - `isValid()`: セッション有効性検証
  - `canRefresh()`: リフレッシュ可能判定
  - `verifyDevice(fingerprint)`: デバイス検証
  - `rotateTokens()`: トークンローテーション
  - `exportForStorage()`: セッション情報のエクスポート
  - `importFromStorage(data)`: セッション情報のインポート

#### GraphQLContext Aggregate
**責務**: GraphQLリクエストの実行コンテキストを管理し、効率的なデータフェッチを保証
- **集約ルート**: GraphQLContext
- **不変条件**:
  - RequestIDは一意でUUID v4形式
  - 認証されたユーザーのコンテキストを持つ（ゲストも可）
  - DataLoaderインスタンスはリクエストごとに一意
  - トレースIDは分散トレーシング形式（W3C Trace Context）
  - 実行開始時刻は現在時刻以前
  - タイムアウトは100ms以上30秒以内
  - クエリ深度は最大10レベルまで
  - クエリ複雑度は最大1000ポイントまで
  - バッチサイズは最大100件
  - 同時実行リゾルバ数は最大50まで
  - エラー配列のサイズは最大100件
  - 拡張フィールドのサイズは最大10KB
- **ドメインロジック**:
  - `executeQuery(query, variables)`: クエリ実行
  - `executeMutation(mutation, variables)`: ミューテーション実行
  - `batchLoad(keys)`: バッチローディング
  - `addError(error)`: エラー追加
  - `checkComplexity(query)`: クエリ複雑度チェック
  - `validateDepth(query)`: クエリ深度検証
  - `cacheResult(key, value)`: 結果キャッシュ
  - `getCached(key)`: キャッシュ取得
  - `startTrace(operation)`: トレース開始
  - `endTrace(result)`: トレース終了

#### SSEConnection Aggregate
**責務**: クライアントとのSSE接続を管理し、リアルタイムイベント配信を制御
- **集約ルート**: SSEConnection
- **不変条件**:
  - ConnectionIDは一意でUUID v4形式
  - UserIDと認証トークンのユーザーIDが一致
  - 接続確立時刻は現在時刻以前
  - 最終ping時刻は接続確立時刻以降
  - ステータスは（connecting/connected/disconnected）のいずれか
  - 再接続試行回数は最大10回まで
  - イベントバッファサイズは最大1000件
  - Keep-Alive間隔は30秒以上5分以内
  - イベントフィルタは最大50個まで
  - 送信レートは1秒あたり最大100イベント
  - 接続タイムアウトは1時間
  - クライアントバージョンはサポートバージョンに含まれる
- **ドメインロジック**:
  - `establish(token)`: 接続確立
  - `sendEvent(event)`: イベント送信
  - `heartbeat()`: ハートビート送信
  - `reconnect()`: 再接続処理
  - `applyFilter(filter)`: フィルタ適用
  - `bufferEvent(event)`: イベントバッファリング
  - `flushBuffer()`: バッファフラッシュ
  - `checkHealth()`: 接続ヘルスチェック
  - `close(reason)`: 接続クローズ
  - `isAlive()`: 接続生存確認

#### FormState Aggregate
**責務**: フォームの入力状態とバリデーション状態を管理
- **集約ルート**: FormState
- **不変条件**:
  - FormIDは一意で、画面内で重複しない
  - フィールド名は英数字とアンダースコアのみ
  - バリデーションエラーは対応するフィールドが存在する
  - ダーティフラグは初期値からの変更有無と一致
  - サブミット中は入力変更不可
  - バリデーション実行中は追加バリデーション不可
  - フィールド値の型は定義された型と一致
  - 依存フィールドの更新は連鎖的に処理される
  - フォームステータスは（idle/validating/submitting/submitted/error）のいずれか
  - エラーメッセージは最大500文字
  - タッチ済みフィールドは存在するフィールドのみ
  - 最大フィールド数は100個まで
- **ドメインロジック**:
  - `setValue(field, value)`: フィールド値設定
  - `validate(field?)`: バリデーション実行
  - `submit()`: フォーム送信
  - `reset()`: フォームリセット
  - `setError(field, error)`: エラー設定
  - `clearError(field)`: エラークリア
  - `isDirty()`: 変更有無判定
  - `isValid()`: フォーム有効性判定
  - `touchField(field)`: フィールドタッチ
  - `getValues()`: 全フィールド値取得

### Entities (エンティティ)

#### TimelineViewState Entity
**所属**: ViewState Aggregate
**責務**: タイムラインの表示状態と取得状態を管理
- **属性**:
  - TimelineID（Entity識別子）
  - TimelineType（home/local/global/user/list）
  - Items（表示中のDropリスト）
  - CursorPosition（現在のカーソル位置）
  - HasMore（追加データの有無）
  - IsLoading（読み込み中フラグ）
  - LastFetchedAt（最終取得時刻）
  - ScrollPosition（スクロール位置）
  - AutoRefreshEnabled（自動更新有効フラグ）
- **ビジネスルール**:
  - Itemsは最大500件まで保持
  - 古いアイテムは自動的に削除
  - スクロール位置は保存される

#### NotificationState Entity
**所属**: ViewState Aggregate
**責務**: 通知の表示状態と既読状態を管理
- **属性**:
  - NotificationID（Entity識別子）
  - UnreadCount（未読数）
  - Items（通知リスト）
  - LastReadAt（最終既読時刻）
  - FilterType（all/mentions/follows等）
  - IsVisible（表示中フラグ）
- **ビジネスルール**:
  - UnreadCountは0以上
  - 既読マークは不可逆

#### ModalState Entity
**所属**: ViewState Aggregate
**責務**: モーダルダイアログの状態を管理
- **属性**:
  - ModalID（Entity識別子）
  - ModalType（種別）
  - IsOpen（表示状態）
  - Data（モーダル固有データ）
  - ZIndex（重なり順序）
  - CanClose（閉じることが可能か）
- **ビジネスルール**:
  - ZIndexは1以上
  - 重要なモーダルはCanCloseがfalse

#### DataLoaderBatch Entity
**所属**: GraphQLContext Aggregate
**責務**: バッチリクエストの管理と実行
- **属性**:
  - BatchID（Entity識別子）
  - Keys（リクエストキーのリスト）
  - Status（pending/loading/completed/error）
  - Results（結果マップ）
  - CreatedAt（作成時刻）
  - ExecutedAt（実行時刻）
- **ビジネスルール**:
  - Keysは最大100個まで
  - 同一キーの重複は除外

#### ConsentSession Entity
**所属**: UserSession Aggregate
**責務**: OAuth同意セッションの管理
- **属性**:
  - ConsentID（Entity識別子）
  - ClientID（OAuthクライアントID）
  - Scopes（要求スコープリスト）
  - State（認可状態パラメータ）
  - ConsentedAt（同意時刻）
  - ExpiresAt（有効期限）
- **ビジネスルール**:
  - 有効期限は10分以内
  - Stateは一意で推測困難

#### EventBuffer Entity
**所属**: SSEConnection Aggregate
**責務**: 送信待ちイベントのバッファリング
- **属性**:
  - BufferID（Entity識別子）
  - Events（イベントリスト）
  - Size（バッファサイズ）
  - OldestEventAt（最古イベント時刻）
  - FlushScheduledAt（フラッシュ予定時刻）
- **ビジネスルール**:
  - 最大1000イベントまで保持
  - 古いイベントから削除

#### FieldState Entity
**所属**: FormState Aggregate
**責務**: 個別フィールドの状態を管理
- **属性**:
  - FieldName（Entity識別子）
  - Value（現在値）
  - InitialValue（初期値）
  - Errors（エラーリスト）
  - IsTouched（タッチ済みフラグ）
  - IsValidating（検証中フラグ）
  - Dependencies（依存フィールドリスト）
- **ビジネスルール**:
  - エラーは最大10個まで
  - 循環依存は禁止

#### CacheEntry Entity
**所属**: GraphQLContext Aggregate
**責務**: クエリ結果のキャッシュエントリを管理
- **属性**:
  - CacheKey（Entity識別子）
  - Value（キャッシュ値）
  - CachedAt（キャッシュ時刻）
  - TTL（有効期限）
  - HitCount（ヒット回数）
  - Tags（キャッシュタグ）
- **ビジネスルール**:
  - TTLは最大1時間
  - サイズは最大1MBまで

### Value Objects (値オブジェクト)

**認証・セッション関連**
- **SessionID**: セッションの一意識別子（UUID v4）
- **AuthToken**: JWT形式の認証トークン
  - Header、Payload、Signatureを含む
  - 有効期限、発行者、対象者を検証
- **RefreshToken**: リフレッシュトークン（ランダム256ビット）
- **DeviceFingerprint**: デバイス識別用ハッシュ値（SHA-256）
- **IPAddress**: IPv4/IPv6アドレス
- **UserAgent**: ブラウザ識別文字列（最大1000文字）
- **AuthMethod**: 認証方法（password/passkey/totp/oauth）

**GraphQL関連**
- **RequestID**: リクエストの一意識別子（UUID v4）
- **GraphQLQuery**: GraphQLクエリ文字列
  - 最大10KB
  - 構文的に有効なGraphQL
- **GraphQLVariables**: クエリ変数（JSON形式、最大100KB）
- **OperationName**: 実行する操作名（最大100文字）
- **QueryComplexity**: クエリ複雑度（1-1000の整数）
- **QueryDepth**: クエリ深度（1-10の整数）
- **TraceID**: 分散トレーシングID（W3C Trace Context形式）
- **ExecutionResult**: 実行結果
  - data、errors、extensionsフィールドを含む

**SSE/リアルタイム関連**
- **ConnectionID**: SSE接続の一意識別子（UUID v4）
- **SSEEvent**: Server-Sent Eventデータ
  - id、event、data、retryフィールド
  - 最大64KBまで
- **EventType**: イベント種別
  - drop_created、reaction_added、notification等
- **EventFilter**: イベントフィルタ条件
  - 種別、ユーザー、タグによるフィルタリング
- **HeartbeatInterval**: ハートビート間隔（30-300秒）
- **ReconnectDelay**: 再接続遅延（1-60秒、指数バックオフ）

**UI/表示関連**
- **Route**: ルーティングパス（/から始まる、最大500文字）
- **RouteParams**: ルートパラメータ（key-valueマップ）
- **ScrollPosition**: スクロール位置（x: 0以上、y: 0以上）
- **Theme**: テーマ設定（light/dark/auto）
- **Language**: 言語設定（ISO 639-1コード）
- **Breakpoint**: レスポンシブブレークポイント（xs/sm/md/lg/xl）
- **ModalType**: モーダル種別
  - compose、profile_edit、settings、confirm等
- **ZIndex**: 重なり順序（1-9999の整数）

**フォーム関連**
- **FormID**: フォームの一意識別子
- **FieldName**: フィールド名（英数字とアンダースコア、最大50文字）
- **FieldValue**: フィールド値（any型、最大10MB）
- **ValidationError**: バリデーションエラー
  - code、message、pathを含む
- **FormStatus**: フォーム状態（idle/validating/submitting/submitted/error）
- **DirtyFlag**: 変更フラグ（boolean）

**時刻・期間関連**
- **Timestamp**: UTC時刻（ミリ秒精度）
- **Duration**: 期間（ISO 8601 duration形式）
- **TTL**: Time To Live（秒単位、1-86400）
- **ExpiresAt**: 有効期限（UTC）

**ページネーション関連**
- **CursorToken**: ページネーションカーソル
  - Base64エンコードされた位置情報
  - 最大200文字
- **PageSize**: ページサイズ（1-100の整数）
- **HasMore**: 追加データ有無（boolean）

**通知関連**
- **NotificationID**: 通知の一意識別子（UUID v4）
- **NotificationType**: 通知種別
  - mention、follow、reaction、system等
- **UnreadCount**: 未読数（0以上の整数、最大9999）
- **PushSubscription**: Web Push購読情報
  - endpoint、keys、expirationTimeを含む

## ユースケース

### ログインとセッション確立

1.  ユーザーはログイン画面で認証情報を入力
2.  FormStateから認証情報を取得し、GraphQL Mutationを送信
3.  avion-gateway経由でavion-authに認証リクエスト
4.  成功時、UserSession AggregateがAuthToken Value Objectを保存
5.  ViewState Aggregateを更新し、ホーム画面へ遷移

### タイムライン取得（GraphQL Query）

1.  GraphQLQuery Value Objectを生成
2.  API RoutesのGraphQLエンドポイントへリクエスト
3.  GraphQLContext AggregateでDataLoaderを初期化
4.  avion-timeline、avion-dropからデータを集約
5.  TimelineViewState Entityを更新

### Drop作成（GraphQL Mutation）

1.  FormState Entityから入力データを取得
2.  ValidationServiceで内容を検証
3.  GraphQL MutationをAPI Routes経由でavion-dropへ送信
4.  楽観的更新でViewState Aggregateを即座に更新
5.  SSE経由で他ユーザーへリアルタイム配信

### SSEによるリアルタイム更新

1.  SSEConnection Aggregateを生成し、API RoutesのSSEエンドポイントに接続
2.  Redis Pub/Sub経由でバックエンドイベントを受信
3.  EventFilter Domain Serviceでユーザー関連イベントをフィルタリング
4.  SSEEvent Value Objectとしてクライアントへ送信
5.  UIEvent Value Objectに変換してViewStateを更新

### Web Push購読

1.  ブラウザのPush APIを使用して通知許可を要求
2.  PushSubscription情報をGraphQL Mutationでavion-notificationへ送信
3.  NotificationState EntityのPushSubscriptionStatusを更新
4.  Service Workerでプッシュ通知を受信・表示

### プロファイル編集フロー

**前提条件:**
- ユーザーが認証済み状態である
- プロファイル編集画面にアクセス可能である

**メインフロー:**
1. ユーザーがプロファイル編集画面を開く
2. 現在のプロファイル情報をGraphQL Queryで取得
3. FormState Aggregateで編集フォームを初期化
4. ユーザーが表示名、自己紹介文、アバター画像を編集
5. ValidationServiceでリアルタイム入力検証
6. 変更内容をGraphQL Mutationでavion-userサービスに送信
7. 楽観的更新でViewState Aggregateを更新
8. 保存完了通知を表示

**代替フロー:**
- 画像アップロード時: MediaUploadServiceで画像処理
- フォーム離脱時: 未保存変更の確認ダイアログ表示
- 自動保存: 30秒間隔でドラフト保存

**エラーハンドリング:**
- 画像サイズ超過: ファイルサイズ制限エラー表示とリサイズ提案
- 不適切な内容: コンテンツポリシー違反警告
- ネットワークエラー: オフライン状態検知と再試行オプション
- バリデーションエラー: フィールド単位のエラーメッセージ表示

**完了条件:**
- プロファイル情報が正常に更新される
- 他画面でも更新後の情報が反映される
- 変更履歴がローカルストレージに保存される

### 検索フロー（Drop・ユーザー）

**前提条件:**
- 検索画面にアクセス可能である
- avion-searchサービスが稼働している

**メインフロー:**
1. ユーザーが検索画面を開く
2. 検索クエリを入力フィールドに入力
3. 300ms のデバウンスでリアルタイム検索実行
4. GraphQL Queryでavion-searchサービスに検索リクエスト
5. 検索結果（Drop・ユーザー）をタブ分けして表示
6. 無限スクロールで追加結果を読み込み
7. フィルタ・ソートオプションで結果を絞り込み

**代替フロー:**
- 検索履歴表示: 過去の検索クエリから選択
- おすすめ検索: トレンドキーワードの提案
- 詳細検索: 日付範囲、ユーザー種別等の高度なフィルタ

**エラーハンドリング:**
- 検索サービス障害: PostgreSQL フォールバック検索実行
- クエリ不正: 入力内容のサニタイゼーションとエラー表示
- タイムアウト: 部分結果表示と再試行オプション
- レート制限: 検索頻度制限の警告表示

**完了条件:**
- 関連する検索結果が適切に表示される
- 検索履歴に保存される
- パフォーマンス指標（検索時間）が記録される

### 設定管理フロー

**前提条件:**
- ユーザーが認証済み状態である
- 設定画面にアクセス可能である

**メインフロー:**
1. ユーザーが設定画面を開く
2. 現在の設定値をGraphQL Queryで取得
3. 通知設定セクションで各種通知の有効/無効を切り替え
4. 表示設定でランゲージとタイムゾーンを選択
5. アカウント設定でパスワード変更、TOTP設定を管理
6. 各設定変更をリアルタイムでGraphQL Mutationで保存
7. 設定変更完了の通知を表示

**代替フロー:**
- 設定のエクスポート/インポート: JSON形式での設定データ管理
- デフォルト設定リセット: 初期値への復元
- 設定の段階的適用: 一部設定のプレビュー機能

**エラーハンドリング:**
- 設定保存失敗: ローカルキャッシュへの一時保存と再試行
- 無効な設定値: バリデーションエラーとデフォルト値の提案
- 権限不足: 管理者権限が必要な設定の制限表示

**完了条件:**
- 設定が正常に保存される
- 変更が即座にUI/UXに反映される
- 設定変更ログが記録される

### 通知管理フロー

**前提条件:**
- ユーザーが認証済み状態である
- SSE接続が確立されている

**メインフロー:**
1. ユーザーが通知一覧画面を開く
2. NotificationState Entityから未読通知数を取得
3. GraphQL Queryで通知履歴を取得
4. 通知を種別（メンション、フォロー、リアクション等）でフィルタリング
5. 個別通知の既読マーク操作
6. 一括既読マーク機能
7. SSE経由でリアルタイム通知受信

**代替フロー:**
- 通知設定へのクイックアクセス: 通知種別ごとの設定変更
- 通知の詳細表示: 関連するDropやユーザープロフィールへの遷移
- 通知の削除: 不要な通知の個別/一括削除

**エラーハンドリング:**
- 通知取得失敗: ローカルキャッシュからの表示と再試行
- SSE接続断: 自動再接続とポーリングフォールバック
- 既読マーク失敗: 楽観的更新とエラー時のロールバック

**完了条件:**
- 通知一覧が正確に表示される
- 未読/既読状態が正しく管理される
- リアルタイム更新が機能する

### ダークモード切り替えフロー

**前提条件:**
- ブラウザがCSS custom propertiesをサポートしている
- テーマ設定がローカルストレージに保存可能である

**メインフロー:**
1. ユーザーがテーマ切り替えボタンをクリック
2. ViewState AggregateのTheme Value Objectを更新
3. CSS custom propertiesを動的に変更
4. テーマ設定をローカルストレージに永続化
5. 全コンポーネントのテーマが即座に切り替わる
6. システム設定連動の場合はprefers-color-schemeを監視

**代替フロー:**
- カスタムテーマ: ユーザー定義カラーパレットの適用
- アクセシビリティテーマ: 高コントラスト、大文字サイズ等
- 時間ベース自動切り替え: 日没/日出時間による自動変更

**エラーハンドリング:**
- テーマ適用失敗: フォールバックテーマの適用
- カスタムプロパティ不対応: 従来のCSSクラス切り替え
- ローカルストレージエラー: セッション内のみの設定保持

**完了条件:**
- テーマが即座に切り替わる
- 設定が永続化される
- パフォーマンスに影響しない

### メディアアップロードフロー

**前提条件:**
- ユーザーが認証済み状態である
- avion-mediaサービスが稼働している

**メインフロー:**
1. ユーザーがファイル選択ダイアログを開く
2. 画像/動画ファイルを選択
3. ファイル形式・サイズのクライアントサイド検証
4. プレビュー表示と編集UI（クロップ、回転、フィルタ）の提供
5. 編集完了後、avion-mediaサービスへのアップロード開始
6. アップロード進捗をプログレスバーで表示
7. アップロード完了後、メディアURLを取得
8. FormState Aggregateにメディア情報を追加

**代替フロー:**
- ドラッグ&ドロップ: ファイル直接ドロップでのアップロード
- カメラ撮影: デバイスカメラでの直接撮影
- 複数ファイル: バッチアップロード機能

**エラーハンドリング:**
- ファイル形式エラー: サポート形式の明示と変換提案
- サイズ超過: 自動リサイズオプションの提供
- アップロード失敗: 再試行機能と詳細エラー情報
- ネットワーク切断: 一時停止と再開機能

**完了条件:**
- メディアが正常にアップロードされる
- メディアURLが取得できる
- アップロード履歴が記録される

### フォロー/アンフォローフロー

**前提条件:**
- ユーザーが認証済み状態である
- 対象ユーザーが存在する

**メインフロー:**
1. ユーザーがプロフィール画面でフォローボタンをクリック
2. UserSession Aggregateから認証情報を取得
3. GraphQL Mutationでavion-userサービスにフォローリクエスト送信
4. プライベートアカウントの場合は承認待ち状態に設定
5. 楽観的更新でUI状態を即座に変更
6. 相手ユーザーに通知を送信（SSE経由）
7. フォロー/フォロワー数の更新

**代替フロー:**
- フォロー承認/拒否: プライベートアカウントからの応答処理
- 相互フォロー検知: 相互フォロー状態の表示
- フォローリスト管理: フォロー/フォロワー一覧の表示と管理

**エラーハンドリング:**
- ネットワークエラー: オフライン状態検知と同期待ちキュー
- 重複フォロー: 既存フォロー状態の確認とエラー回避
- ブロック状態: フォロー不可の理由表示
- レート制限: フォロー頻度制限の警告

**完了条件:**
- フォロー関係が正しく設定される
- 関連する通知が送信される
- UI状態が正確に更新される

### ブロック/ミュートフロー

**前提条件:**
- ユーザーが認証済み状態である
- 対象ユーザーまたはキーワードが指定されている

**メインフロー:**
1. ユーザーがブロック/ミュートオプションを選択
2. 確認ダイアログで操作を確認
3. GraphQL Mutationでavion-userサービスに設定送信
4. 既存のフォロー関係がある場合は自動解除
5. ブロック/ミュートリストに追加
6. 楽観的更新でUI要素を即座に非表示化
7. キーワードミュートの場合は正規表現パターンを保存

**代替フロー:**
- 期間限定ミュート: 自動解除タイマーの設定
- カテゴリ別ミュート: 通知のみ、表示のみ等の部分的制御
- 高度なフィルタ: 正規表現によるキーワードマッチング

**エラーハンドリング:**
- 設定保存失敗: ローカルフィルタとして一時適用
- 無効なパターン: 正規表現エラーの検証と修正提案
- 自己ブロック防止: 自分自身への操作制限

**完了条件:**
- ブロック/ミュート設定が有効になる
- 関連コンテンツが適切にフィルタされる
- 設定リストが更新される

### アクセシビリティナビゲーションフロー

**前提条件:**
- ブラウザがアクセシビリティAPIをサポートしている
- キーボード、スクリーンリーダー等の支援技術が利用可能

**メインフロー:**
1. ユーザーがキーボードまたは支援技術でページにアクセス
2. フォーカス管理システムで適切な要素順序を設定
3. ARIAラベルとランドマークによる構造化ナビゲーション
4. Tab, Shift+Tab, Arrow keys等でのキーボード操作
5. スクリーンリーダーでの音声読み上げ対応
6. 高コントラストモード切り替えオプション
7. フォントサイズ調整とズーム対応

**代替フロー:**
- ショートカットキー: 主要機能への直接アクセス
- スキップリンク: コンテンツエリアへの直接ジャンプ
- 読み上げ速度調整: スクリーンリーダー用の最適化

**エラーハンドリング:**
- フォーカストラップ失敗: モーダル内でのフォーカス管理エラー
- ARIA属性不整合: 動的コンテンツ更新時の支援技術対応
- キーボード操作無効: マウス依存機能の代替手段提供

**完了条件:**
- WCAG 2.1 Level AA要件を満たす
- 支援技術での完全な操作が可能
- アクセシビリティテストをパスする

## 機能要求

### フロントエンド要求

*   **状態管理:** ViewStateAggregate、UserSessionAggregate を中心とした状態管理
*   **ルーティング:** Next.js App Router によるクライアントサイドルーティング
*   **UIコンポーネント:** 再利用可能で一貫性のあるコンポーネント設計
*   **レスポンシブ:** 様々な画面幅での適切なレイアウト
*   **PWA:** Service Worker、Web App Manifest の実装

### BFF要求（API Routes）

*   **GraphQLスキーマ:** 型安全なスキーマ定義（SDL）とカスタムスカラー型
*   **リゾルバ実装:** 効率的なデータフェッチングとエラーハンドリング
*   **DataLoader:** N+1問題の解決とバッチング最適化
*   **SSE管理:** 長時間接続の維持と自動再接続
*   **キャッシング:** 効率的なクエリ結果キャッシュ

## セキュリティ実装ガイドライン

このサービスは以下のセキュリティガイドラインに準拠する必要がある：

### XSS防止
- **ガイドライン**: [../common/security/xss-prevention.md](../common/security/xss-prevention.md)
- **実装要件**: クライアントサイドアプリケーションとして、avion-webは包括的なXSS防止を実装する必要がある。これには、適切なReactコンポーネントのサニタイゼーション、厳格なContent Security Policyヘッダー、ユーザー生成コンテンツの安全な処理、およびすべての外部データソースの検証が含まれる。マークダウンコンテンツのサニタイゼーション、DOMベースのXSSの防止、動的HTMLレンダリングのセキュア化に特別な注意を払う必要がある。

### CSRF保護
- **ガイドライン**: [../common/security/csrf-protection.md](../common/security/csrf-protection.md)
- **実装要件**: すべての状態変更操作に対してダブルサブミットクッキーパターンを実装し、API Routesでオリジンヘッダーを検証し、SameSiteクッキー属性を使用し、GraphQLミューテーションにCSRFトークンが含まれることを確認する。BFF層はバックエンドサービスにリクエストを転送する前にトークンを検証する必要がある。

### セキュリティヘッダー
- **ガイドライン**: [../common/security/security-headers.md](../common/security/security-headers.md)
- **実装要件**: X-Frame-Options、X-Content-Type-Options、Referrer-Policy、Permissions-Policyを含む適切なセキュリティヘッダーを送信するようNext.jsを設定する。スクリプト、スタイル、接続に必要なソースのみを許可する厳格なContent Security Policyを実装する。ヘッダーはフロントエンドアプリケーションとAPI Routesの両方で設定する必要がある。

## 技術的要求

### パフォーマンス

*   **Core Web Vitals:**
    *   LCP: 2.5秒以内
    *   FID: 100ミリ秒以内
    *   CLS: 0.1未満
*   **API レスポンス:**
    *   GraphQL Query: P99 < 200ms
    *   SSE イベント配信: < 100ms
*   **バンドルサイズ:** 初回ロード時のJavaScript < 200KB（gzip後）

### スケーラビリティ

*   同時SSE接続: 10,000+
*   水平スケーリング対応（Kubernetes）
*   CDN対応（静的アセット）

### セキュリティ

*   XSS対策: React のデフォルト保護 + 適切なエスケープ
*   CSRF対策: AuthToken の適切な管理
*   依存関係の脆弱性管理
*   Content Security Policy の実装

### アクセシビリティ

*   WCAG 2.1 Level AA 準拠を目標
*   キーボードナビゲーション対応
*   スクリーンリーダー対応
*   適切なコントラスト比

### 技術スタック

*   **フレームワーク:** Next.js 14 (App Router)
*   **言語:** TypeScript 5+
*   **UI:** Tailwind CSS + shadcn/ui（または同等）
*   **状態管理:** Zustand または Jotai
*   **GraphQL クライアント:** Apollo Client または urql
*   **GraphQL サーバー:** GraphQL Yoga
*   **バリデーション:** Zod
*   **テスト:** Vitest + Playwright
*   **リンター/フォーマッター:** Biome または ESLint + Prettier

### Domain Services (ドメインサービス)

#### EventFilterService
**責務**: SSEイベントのフィルタリングとルーティング
- **主要メソッド**:
  - `shouldDeliverToUser(event, userID)`: ユーザーへの配信判定
  - `applyPrivacyRules(event, viewer)`: プライバシールール適用
  - `filterBySubscription(events, filters)`: 購読条件によるフィルタリング
  - `prioritizeEvents(events)`: イベント優先度付け

#### DataAggregationService
**責務**: 複数データソースからの情報集約
- **主要メソッド**:
  - `aggregateTimelineData(sources)`: タイムラインデータ集約
  - `mergeUserProfiles(profiles)`: プロファイル情報マージ
  - `combineNotifications(notifications)`: 通知統合
  - `deduplicateData(items)`: 重複データ除去

#### ValidationService
**責務**: 入力データの検証とサニタイゼーション
- **主要メソッド**:
  - `validateDropContent(content)`: Drop内容検証
  - `sanitizeHTML(html)`: HTML無害化
  - `checkContentPolicy(content)`: コンテンツポリシー確認
  - `validateMediaFiles(files)`: メディアファイル検証

#### CacheStrategyService
**責務**: キャッシュ戦略の決定と実行
- **主要メソッド**:
  - `determineCacheability(query)`: キャッシュ可否判定
  - `calculateTTL(dataType)`: TTL計算
  - `invalidateRelated(key)`: 関連キャッシュ無効化
  - `warmupCache(predictions)`: キャッシュ事前温め

#### OptimisticUpdateService
**責務**: 楽観的更新の管理とロールバック
- **主要メソッド**:
  - `applyOptimisticUpdate(action)`: 楽観的更新適用
  - `confirmUpdate(id, result)`: 更新確定
  - `rollbackUpdate(id, error)`: 更新ロールバック
  - `reconcileState(local, remote)`: 状態調整

## UI/UXデザイン要件

### Design System仕様

#### カラーパレット
- **Primary Colors**: ブランドアイデンティティを反映したメインカラー（3-5色）
- **Semantic Colors**: 成功、警告、エラー、情報を表現する機能的カラー
- **Neutral Colors**: テキスト、背景、ボーダー用のグレースケール（8-12段階）
- **Interactive Colors**: ホバー、フォーカス、アクティブ状態のカラーバリエーション
- **Dark/Light Mode**: 各モード対応の完全なカラーセット定義

#### タイポグラフィ
- **Font Family**: システムフォント優先（Inter, -apple-system, BlinkMacSystemFont等）
- **Font Scale**: Modular Scale（1.25倍率）による8段階のフォントサイズ定義
- **Line Height**: 可読性を考慮した適切な行間設定（1.4-1.6）
- **Font Weight**: Regular（400）、Medium（500）、Semibold（600）、Bold（700）の使い分け
- **Letter Spacing**: フォントサイズに応じた字間調整

#### スペーシング
- **Base Unit**: 8pxベースのスペーシングシステム
- **Scale**: 4px, 8px, 12px, 16px, 24px, 32px, 48px, 64px, 96px
- **Component Spacing**: 内部余白（padding）の一貫性確保
- **Layout Spacing**: 外部余白（margin）とギャップの標準化

### コンポーネントライブラリ要件

#### 基本コンポーネント
- **Button**: Primary、Secondary、Tertiary、Destructive バリエーション
- **Input**: Text、Email、Password、Search、Textarea の各種入力フィールド
- **Select**: Single、Multi、Searchable セレクトボックス
- **Checkbox/Radio**: 単一選択・複数選択コンポーネント
- **Modal**: 確認ダイアログ、フォームモーダル、フルスクリーンモーダル
- **Toast**: 成功、エラー、警告、情報通知の表示

#### レイアウトコンポーネント
- **Container**: 最大幅制御とセンタリング
- **Grid**: Flexbox/CSS Gridベースのレスポンシブグリッド
- **Stack**: 垂直・水平スタックレイアウト
- **Sidebar**: 折りたたみ可能なサイドバーナビゲーション

#### 複合コンポーネント
- **Navigation**: ヘッダーナビゲーションとタブナビゲーション
- **Card**: コンテンツカード（Drop表示、プロフィールカード等）
- **Timeline**: 無限スクロール対応のタイムライン表示
- **UserAvatar**: ユーザーアバター表示（サイズバリエーション、オンライン状態）

### レスポンシブデザイン戦略

#### ブレークポイント定義
- **Mobile**: 320px - 767px（モバイルファースト）
- **Tablet**: 768px - 1023px（タブレット対応）
- **Desktop**: 1024px - 1439px（デスクトップ標準）
- **Wide**: 1440px以上（大画面対応）

#### グリッドシステム
- **Mobile**: 4カラム、16px ガター
- **Tablet**: 8カラム、24px ガター
- **Desktop**: 12カラム、32px ガター
- **Wide**: 12カラム、40px ガター

#### レスポンシブ戦略
- **Content-First**: コンテンツに基づいたブレークポイント設定
- **Progressive Enhancement**: モバイルから段階的な機能拡張
- **Flexible Layouts**: Fixed幅を避けた柔軟なレイアウト設計
- **Touch Optimization**: タッチデバイス向けの操作領域確保（44px以上）

### アニメーション・トランジション仕様

#### 基本トランジション
- **Duration**: Fast（150ms）、Normal（250ms）、Slow（400ms）
- **Easing**: ease-out（UI要素の登場）、ease-in（UI要素の退場）、ease-in-out（状態変化）
- **Properties**: transform、opacity の組み合わせによる軽量アニメーション

#### マイクロインタラクション
- **Button Hover**: 100ms ease-out でのカラー変化
- **Focus States**: 150ms ease-out でのボーダー・シャドウ変化
- **Loading States**: パルスアニメーション、スケルトン画面
- **Form Validation**: エラー状態の視覚的フィードバック

#### ページトランジション
- **Route Changes**: 200ms ease-in-out でのフェードイン・アウト
- **Modal Appearance**: スケール + フェードイン（250ms ease-out）
- **Drawer Slides**: translate3d による滑らかなスライドイン

#### パフォーマンス配慮
- **GPU Acceleration**: transform、opacity のみを使用
- **Reduced Motion**: prefers-reduced-motionメディアクエリ対応
- **Animation Budget**: 同時実行アニメーション数の制限

### アクセシビリティ要件（WCAG 2.1 AA準拠）

#### 色とコントラスト
- **Color Contrast**: 通常テキスト 4.5:1、大文字テキスト 3:1 以上
- **Color Independence**: 色のみに依存しない情報伝達
- **Focus Indicators**: キーボードフォーカスの明確な視覚表示

#### キーボードナビゲーション
- **Tab Order**: 論理的なタブ順序の実装
- **Skip Links**: メインコンテンツへのスキップリンク
- **Keyboard Shortcuts**: 主要機能への短縮キー提供
- **Focus Management**: モーダル内でのフォーカストラップ

#### セマンティックHTML
- **Landmark Roles**: header、nav、main、aside、footer の適切な使用
- **Heading Structure**: 階層的な見出し構造（h1-h6）
- **Lists and Tables**: 適切なリスト・テーブル要素の使用
- **Form Labels**: すべての入力要素への適切なラベル付け

#### 支援技術対応
- **ARIA Attributes**: 適切なaria-label、aria-describedby の使用
- **Live Regions**: 動的コンテンツ更新の通知
- **Screen Reader**: スクリーンリーダーでの完全な操作可能性
- **Alternative Text**: 画像・アイコンの代替テキスト提供

## 決まっていないこと

*   UIデザインシステムの詳細
*   状態管理ライブラリの最終選定（Zustand vs Jotai）
*   UIコンポーネントライブラリの選定
*   GraphQLクライアントの選定（Apollo vs urql）
*   キャッシュ戦略の詳細（TTL、無効化ポリシー）
*   国際化（i18n）対応の時期と方法
*   SEO対応の将来的な実装方法（部分的なSSG/ISR導入）
*   GraphQL Subscriptionの実装時期（現在はSSEを使用）
*   パフォーマンス監視ツールの選定