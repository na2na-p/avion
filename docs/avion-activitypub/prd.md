# PRD: avion-activitypub

## 概要

AvionをActivityPubプロトコルに対応させ、他の互換サーバー（Misskey、Mastodon、Pleroma等）との連合（Federation）を実現するマイクロサービスを実装する。ActivityPubアクティビティの送受信（Inbox/Outbox）、Actor情報の提供（WebFinger含む）、HTTP Signaturesによる認証・検証、リモート情報の管理・キャッシュを行う。

## 背景

現在のSNSエコシステムは分散型プロトコルへの移行が進んでおり、特にActivityPubを基盤とするFediverse（連合宇宙）が急速に成長している。Avionが単なるSNSプラットフォームではなく、分散型ソーシャルネットワークの一部として機能することで、ユーザーは他のサーバーのユーザーとも自由にコミュニケーションを取ることができ、プラットフォームの境界を超えた真のオープンなソーシャル体験を提供できる。

また、ActivityPub対応により、プラットフォーム固有の制限から解放され、ユーザーがデータの主権を持ちながら自由にコミュニケーションを行える環境を実現する。複雑なActivityPubプロトコル処理を専用のマイクロサービスとして分離することで、コアサービスへの影響を最小限に抑えながら、堅牢で拡張性の高い連合機能を提供する。

## Scientific Merits

* **Federation Performance**: ActivityPub標準プロトコルへの準拠により、10,000 deliveries/min以上の配送処理能力でMastodon、Misskey、Pleroma等との相互運用性を確保し、ユーザーベースの拡大を実現する
* **Protocol Compliance**: W3C ActivityPub勧告100%準拠により、既存Fediverseエコシステムとの完全互換性を保証し、即座に100万規模のネットワーク効果を活用できる
* **Scalable Federation**: Redis StreamとConsumer Groupを活用した非同期処理により、水平スケーリングで1,000並行配送タスクを処理し、連合ネットワークの成長に対応する
* **Security Excellence**: HTTP Signaturesによる厳格な認証機構（99%検証成功率）により、なりすましや不正なアクティビティを防止し、分散環境でのセキュリティを確保する
* **High Availability**: 99.9%以上のサービス可用性と95%以上の配送成功率により、安定した連合機能を提供し、ユーザー体験を向上させる
* **Operational Excellence**: OpenTelemetry統合による完全な可観測性とCircuit Breaker機構により、障害時の自動回復と運用効率の向上を実現する
* **Developer Experience**: 専用マイクロサービス化により、コアビジネスロジックとプロトコル処理を分離し、開発・保守性を大幅に向上させる

連合機能はSNSプラットフォームの差別化要因として重要性が増しており、定量的な性能指標に基づくオープンスタンダードへの対応により、長期的な競争優位性とユーザーロイヤリティを確保できる。

## Design Doc

[Design Doc: avion-activitypub](./designdoc.md)

## 参考ドキュメント

* [Avion アーキテクチャ概要](./../common/architecture.md)
* [ActivityPub W3C Recommendation](https://www.w3.org/TR/activitypub/)
* [ActivityStreams 2.0](https://www.w3.org/TR/activitystreams-core/)
* [WebFinger RFC 7033](https://tools.ietf.org/html/rfc7033)
* [HTTP Signatures Draft](https://tools.ietf.org/html/draft-cavage-http-signatures-12)

## 製品原則

* **オープンスタンダード準拠**: W3C ActivityPub仕様に忠実に準拠し、他のサーバーとの完全な相互運用性を保証すること。
* **堅牢なセキュリティ**: HTTP Signaturesによる厳格な認証とアクティビティ検証により、分散環境でのセキュリティを確保すること。
* **高い可用性**: 連合機能の障害が他のサービスに影響しないよう、独立性を保ちながら高可用性を実現すること。
* **効率的な配送**: Outbox配送における適切なリトライ機構とサーキットブレーカーにより、ネットワーク障害時でも安定した配送を保証すること。
* **透明な処理**: アクティビティの送受信状況をログとメトリクスで透明化し、運用性とトラブルシューティング性を確保すること。
* **プライバシー尊重**: ユーザーの公開範囲設定を厳格に遵守し、意図しない情報漏洩を防止すること。

## やること/やらないこと

### やること

* **ActivityPub Actor情報の提供**:
  * Actor エンドポイント (`/users/{username}`) による プロフィール情報の提供
  * WebFingerエンドポイント (`/.well-known/webfinger`) による リソース解決
  * Outbox、Followers、Following、Featured コレクションの提供
* **Inbox処理（サーバー間通信受信）**:
  * 共有Inbox (`/inbox`) およびユーザー別Inbox (`/users/{username}/inbox`) の実装
  * HTTP Signatures検証による認証（公開鍵は `avion-user` またはキャッシュから取得）
  * 受信アクティビティの解釈と関連サービスへのイベント発行
  * サポートアクティビティ: Create, Update, Delete, Follow, Accept, Reject, Announce, Like, Undo, Block, Flag, Move, Question, Answer, Join, Leave, Invite, Add, Remove
* **Outbox処理（サーバー間通信送信）**:
  * ローカルイベント（Drop作成、フォロー、リアクション等）の購読
  * ActivityPubアクティビティの生成と配送
  * HTTP Signaturesによる署名（秘密鍵は `avion-user` に問い合わせ）
  * 対象リモートActorのInboxへの配送（共有Inbox利用含む）
  * 指数バックオフによるリトライ機構とデッドレターキュー（DLQ）
  * サーキットブレーカーによる障害ドメインの自動遮断
* **リモート情報管理**:
  * リモートActor/Object情報のキャッシュとDB保存
  * Actor情報の定期更新と古い情報のクリーンアップ
  * リモートメディアのキャッシュ依頼（`avion-media` へ）
* **セキュリティ機能**:
  * Actor/インスタンスレベルのブロック機能
  * コンテンツ通報（Flag アクティビティ）の送受信
  * アクティビティ検証とスパムフィルタリング
  * ドメインレベルのアクセス制御
* **移行機能**:
  * アカウント移行（Move アクティビティ）の送受信
  * フォロー関係の移行処理
* **投票機能**:
  * 投票（Question アクティビティ）の受信と配送
  * 投票回答（Answer アクティビティ）の処理
* **コミュニティ連合機能**:
  * Group Actorとしてのコミュニティ公開
  * Join/Leave アクティビティによるメンバーシップ管理
  * コミュニティ内投稿の連合配信（Audienceベース）
  * トピック（Collection）の公開と管理
  * コミュニティイベント（Event）の連合
  * Invite アクティビティによる招待処理
  * Add/Remove アクティビティによるモデレーター管理
  * カスタム名前空間による拡張属性（avion:communityRole、avion:joinMode等）
* **監視・運用機能**:
  * OpenTelemetryによるトレーシング・メトリクス・ロギング対応
  * 配送統計とエラー率の監視
  * 構造化ログによる詳細な処理追跡

### やらないこと

* **ActivityPub Client-to-Server (C2S) プロトコル**: クライアントアプリケーションとの直接的なActivityPub通信は `avion-gateway` が担当する。
* **全てのActivityPubアクティビティ/オブジェクトタイプの完全サポート**: 初期実装では主要なアクティビティタイプに限定し、段階的に拡張する。
* **複雑なActivityPubアクセス制御ロジック**: 高度なアクセス制御は将来的な拡張として位置づけ、基本的な公開範囲制御のみ実装する。
* **リレーサーバー機能**: 専用のリレーサーバーとしての機能は実装せず、必要に応じて将来的に検討する。
* **高度なスパム/不正行為対策**: 基本的な検証機能は実装するが、機械学習ベースの高度な対策は `avion-moderation` に委ねる。
* **Outbox処理における厳密な順序保証**: パフォーマンスを優先し、順序保証が必要な場合は将来的な拡張として検討する。
* **ActivityPub拡張仕様への対応**: Mastodon固有拡張やMisskey固有拡張への対応は、相互運用性を損なわない範囲で段階的に実装する。
* **コミュニティ固有のアクセス制御**: コミュニティメンバーシップとロールベースの詳細アクセス制御は`avion-community`サービスが担当する。

## 対象ユーザー

* **リモートActivityPubサーバー**: Mastodon、Misskey、Pleroma、その他ActivityPub対応サーバー
* **Avionの他のマイクロサービス**: Timeline、Notification、Drop、User、Media等のサービス（gRPC経由）
* **外部クライアントアプリケーション**: WebFingerによるリソース発見を行うクライアント
* **Avion運用者・開発者**: 連合機能の監視・運用・デバッグを行う技術者

## ドメインモデル (DDD戦術的パターン)

### Aggregates (集約)

#### RemoteActor Aggregate
**責務**: リモートActivityPub Actorの情報、認証状態、連合関係を管理する中核的な集約
- **集約ルート**: RemoteActor
- **不変条件**:
  - ActorURIは一意かつ変更不可（W3C ActivityPub仕様準拠）
  - PublicKeyPEMは有効なRSA公開鍵（2048bit以上）
  - InboxURLとOutboxURLは有効なHTTPS URL（RFC 3986準拠）
  - LastFetchedAtは取得後必須更新（キャッシュ無効化制御）
  - UsernameとDomainの組み合わせは一意（WebFinger準拠）
  - SuspendedActorは全アクティビティ受信を停止
  - FederationStatusは定義された値（active, suspended, migrated, deleted）のいずれか
  - Followersカウントは負値不可
  - PreferredUsernameはWebFinger仕様に準拠
  - TrustScoreは0.0〜1.0の範囲（スパム対策用）
  - LastActivityTypeは有効なActivityType値
- **ドメインロジック**:
  - `canReceiveActivity(activityType)`: アクティビティ受信可能かの判定（タイプ別制御）
  - `needsRefresh(cachePolicy)`: 情報更新が必要かの判定（TTL・ポリシーベース）
  - `updateProfile(actorDocument)`: プロフィール情報の差分更新とバージョン管理
  - `verifySignature(httpSignature)`: HTTP Signature検証（draft-cavage-http-signatures-12準拠）
  - `suspend(reason)`: アクター停止処理（理由記録付き）
  - `unsuspend()`: アクター復旧処理（履歴記録）
  - `markAsUnreachable(errorInfo)`: 到達不能マーク（エラー情報付き）
  - `refreshFromRemote()`: リモートサーバーからの最新情報取得
  - `toActivityPubActor()`: ActivityPub Actor形式への変換（JSON-LD）
  - `canFollow(targetActor)`: フォロー関係構築可能性の判定
  - `recordLastActivity(activityType)`: 最終アクティビティ記録（統計用）
  - `calculateTrustScore()`: 信頼度スコア算出（スパム対策）
  - `validateInvariants()`: 不変条件の実行時検証（防御的プログラミング）
  - `shouldAutoSuspend()`: 自動停止判定（Trust Score・違反回数ベース）

#### FederationDelivery Aggregate
**責務**: ActivityPub配送タスクの状態、配送履歴、信頼性制御を管理する集約
- **集約ルート**: FederationDelivery
- **不変条件**:
  - DeliveryStatusは定義された値（pending, delivering, delivered, failed, dead_letter）のいずれか
  - RetryCountはMaxRetries（5回）を超えない
  - DeliveredAtは配送成功時のみ設定（UTC精度）
  - NextRetryAtは失敗時のみ設定（指数バックオフ）
  - ActivityContentは有効なActivityPubアクティビティ（JSON-LD）
  - Priorityは1-10の範囲（1=highest, 10=lowest）
  - TargetInboxURLは有効なHTTPS URL
  - CreatedAtは現在時刻以前
  - CircuitBreakerStateは各ドメインごとに管理
- **ドメインロジック**:
  - `canRetry()`: リトライ可能かの判定（最大回数・時間制限チェック）
  - `scheduleRetry(backoffStrategy)`: 次回リトライのスケジューリング（指数バックオフ）
  - `markAsDelivered(responseInfo)`: 配送成功の記録（レスポンス情報付き）
  - `markAsFailed(errorInfo)`: 配送失敗の記録（詳細エラー情報）
  - `moveToDeadLetter(reason)`: デッドレターキューへの移動（理由記録）
  - `shouldCircuitBreak(domain)`: ドメイン別サーキットブレーカー発動判定
  - `calculateBackoffDelay(attemptNumber)`: バックオフ遅延計算（最大24時間）
  - `updatePriority(newPriority)`: 配送優先度の動的更新
  - `canBatch(otherDelivery)`: バッチ配送可能性の判定
  - `recordDeliveryMetrics()`: 配送統計の記録
  - `estimateRetryTime()`: 次回配送予定時刻の算出
  - `shouldUpgradePriority()`: 優先度昇格の判定（緊急配送）

#### ActivityPubObject Aggregate
**責務**: リモートActivityPubオブジェクト（Note、Image等）のライフサイクルと参照整合性を管理する集約
- **集約ルート**: ActivityPubObject
- **不変条件**:
  - ObjectURIは一意かつ変更不可（ActivityPub ID仕様準拠）
  - ObjectTypeは定義された値（Note、Image、Video、Audio、Document等）のいずれか
  - AuthorActorURIは有効なActor URI
  - PublishedAtは現在時刻以前かつ変更不可
  - UpdatedAtはPublishedAt以降
  - IsDeletedの場合は削除理由が必須
  - ReplyToObjectURIは存在する場合は有効なObject URI
  - AttributedToは必須（作成者情報）
  - LocalCachedAtは初回キャッシュ時刻
- **ドメインロジック**:
  - `canUpdate(actorURI)`: オブジェクト更新権限の確認（作成者のみ）
  - `delete(reason)`: オブジェクト削除処理（Tombstone生成）
  - `update(newContent)`: オブジェクト内容更新（履歴記録）
  - `isExpired(ttlPolicy)`: キャッシュ有効期限の確認
  - `refreshFromRemote()`: リモートサーバーからの再取得
  - `extractMentions()`: メンション情報の抽出
  - `extractHashtags()`: ハッシュタグ情報の抽出
  - `extractMediaAttachments()`: メディア添付の抽出
  - `toLocalFormat()`: Avion内部形式への変換
  - `validateContent()`: コンテンツの妥当性検証
  - `calculateContentHash()`: 内容ハッシュの算出（改ざん検知）
  - `needsModeration()`: モデレーション必要性の判定

#### BlockedDomain Aggregate
**責務**: ドメインレベルのブロック制御とポリシー管理を行う集約
- **集約ルート**: BlockedDomain
- **不変条件**:
  - DomainNameは有効なDNS名（RFC 1035準拠）
  - BlockReasonは定義された値（spam、illegal_content、harassment等）のいずれか
  - BlockedAtは設定後変更不可
  - BlockTypeは定義された値（silence、suspend、media_only）のいずれか
  - IsActiveはブロック状態を正確に表現
  - 同一ドメインの重複ブロックは不可
  - Expirationはブロック開始時刻以降（永続ブロックの場合はnull）
- **ドメインロジック**:
  - `isBlocked(checkType)`: ドメインブロック状態の確認（タイプ別）
  - `shouldRejectActivity(activityType)`: アクティビティタイプ別拒否判定
  - `canUnblock()`: ブロック解除可能かの判定（権限・条件チェック）
  - `unblock(reason)`: ブロック解除処理（理由記録）
  - `upgradeBlockLevel(newType)`: ブロックレベルの昇格
  - `isExpired()`: ブロック期限切れの確認
  - `autoExpire()`: 自動期限切れ処理
  - `recordViolation(violationType)`: 違反記録の追加
  - `calculateRiskScore()`: リスクスコアの算出
  - `shouldEscalate()`: エスカレーション必要性の判定

### Entities (エンティティ)

#### FederationActivity
**所属**: FederationDelivery Aggregate
**責務**: 配送するActivityPubアクティビティの詳細情報と配送履歴を管理
- **属性**:
  - ActivityID（Snowflake ID、分散環境対応）
  - ActivityType（25種類のActivityPub標準タイプ）
  - ActivityContent（JSON-LD形式、gzip圧縮対応）
  - ActorURI（アクティビティ実行者、検証済みURI）
  - ObjectURI（対象オブジェクト、参照整合性保証）
  - PublishedAt（ISO 8601、UTC、ミリ秒精度）
  - AudienceTargets（配送対象、To/Cc/Bcc分離）
  - SignatureInfo（HTTP Signature メタデータ）
  - ContentHash（SHA-256、改ざん検知用）
- **ビジネスルール**:
  - ActivityIDは全システム一意（Snowflake生成）
  - ActivityTypeはW3C ActivityStreams語彙準拠
  - PublishedAtは現在時刻以前（クロックスキュー考慮）
  - ActorURIとObjectURIの権限関係検証必須
  - ContentHashによる改ざん検出・冪等性保証

#### DeliveryAttempt
**所属**: FederationDelivery Aggregate
**責務**: 配送試行の詳細記録と分析データを管理
- **属性**:
  - AttemptID（UUID v4、トレーシング対応）
  - AttemptNumber（1-5、リトライ制限内）
  - AttemptedAt（UTC、マイクロ秒精度）
  - TargetEndpoint（配送先URL、正規化済み）
  - HTTPStatusCode（100-599、RFC準拠）
  - ResponseHeaders（重要ヘッダーのみ保存）
  - ResponseBody（エラー詳細、最大1KB制限）
  - Duration（レスポンス時間、ミリ秒）
  - NetworkMetrics（DNS解決時間、接続時間、TLS時間）
  - FailureCategory（temporary/permanent/network/auth）
- **ビジネスルール**:
  - AttemptNumberは1から始まる連続番号
  - 同一配送タスク内でAttemptNumberは重複不可
  - HTTPStatusCodeは有効範囲（100-599）
  - Durationは実測値（0以上）
  - NetworkMetricsは配送最適化に活用

#### ActivityPubObject
**所属**: ActivityPubObject Aggregate
**責務**: リモートActivityPubオブジェクトのライフサイクルと参照管理
- **属性**:
  - ObjectID（Snowflake ID、グローバル一意）
  - ObjectURI（正規化済みURI、重複排除キー）
  - ObjectType（Note/Image/Video/Audio/Document等）
  - AuthorActorURI（作成者Actor、検証済み）
  - Content（JSON-LD正規化、圧縮保存）
  - ContentText（プレーンテキスト抽出、検索用）
  - MediaAttachments（メディアファイル参照、CDN URL）
  - Mentions（メンション対象、Actor URI配列）
  - Hashtags（ハッシュタグ、正規化済み）
  - PublishedAt（作成日時、ISO 8601）
  - UpdatedAt（最終更新日時、バージョン管理）
  - LocalCachedAt（初回キャッシュ日時、TTL制御）
  - IsDeleted（論理削除フラグ、Tombstone生成）
  - DeletedReason（削除理由、監査用）
  - ReplyToObjectURI（返信元オブジェクト、スレッド構築）
  - ContentWarning（内容警告、フィルタリング）
  - Visibility（公開範囲、ActivityPub準拠）
- **ビジネスルール**:
  - ObjectURIは全システム一意（重複検出必須）
  - ObjectTypeはActivityPub Core Types準拠
  - AuthorActorURIは存在するActor（外部キー制約）
  - 削除されたオブジェクトはTombstoneで管理
  - ReplyToObjectURIは循環参照禁止
  - ContentHashで改ざん検出対応
  - Visibilityに基づくアクセス制御必須

#### WebFingerResource
**所属**: 独立エンティティ
**責務**: WebFingerプロトコルによるリソース解決情報の管理
- **属性**:
  - ResourceID（UUID v4、内部管理用）
  - Subject（acct:username@domain形式）
  - ActorURI（対応するActivityPub Actor URI）
  - Links（rel/type/href構造、JSON配列）
  - Aliases（代替URI、配列形式）
  - Properties（拡張プロパティ、Key-Value）
  - CachedAt（キャッシュ作成日時）
  - ExpiresAt（キャッシュ有効期限、TTL制御）
  - LastAccessedAt（最終アクセス日時、LRU用）
- **ビジネスルール**:
  - SubjectはRFC 7033準拠形式
  - ActorURIは有効なHTTPS URI
  - LinksはWebFinger仕様準拠構造
  - ExpiresAtによる自動キャッシュ無効化
  - 高アクセス頻度リソースの優先キャッシュ

### Value Objects (値オブジェクト)

**ActivityPub Protocol Objects**
- **ActorURI**: ActivityPub Actor URI（RFC 3986準拠、https://スキーム必須）
  - 形式: `https://domain.com/users/username`
  - バリデーション: 有効なHTTPS URI、ホスト名検証
  - 最大長: 2048文字
- **ActivityType**: ActivityPubアクティビティタイプ
  - 値: Create、Update、Delete、Follow、Accept、Reject、Like、Announce、Undo、Block、Flag、Move、Question、Answer
  - バリデーション: W3C ActivityStreams語彙に準拠
- **ObjectType**: ActivityPubオブジェクトタイプ
  - 値: Note、Image、Video、Audio、Document、Person、Organization、Service
  - バリデーション: ActivityStreams Core Types準拠
- **ActivityContent**: アクティビティ内容（JSON-LD形式）
  - バリデーション: 有効なJSON-LD、@contextフィールド必須
  - 圧縮: gzip圧縮対応、最大10MB
- **WebFingerResource**: WebFingerリソース識別子
  - 形式: `acct:username@domain.com`または`https://domain.com/users/username`
  - バリデーション: RFC 7033準拠

**Federation Delivery Objects**
- **DeliveryStatus**: 配送状態列挙値
  - 値: pending、delivering、delivered、failed、dead_letter
  - 遷移ルール: pending→delivering→(delivered|failed)→dead_letter
- **InboxURL**: 個別Inbox URL
  - 形式: `https://domain.com/users/username/inbox`
  - バリデーション: HTTPS必須、Actor URIとの整合性確認
- **SharedInboxURL**: 共有Inbox URL（Optional）
  - 形式: `https://domain.com/inbox`
  - 利点: 配送効率化（単一サーバーへの集約配送）
- **RetryPolicy**: リトライポリシー設定
  - MaxRetries: 5回（設定値）
  - BackoffStrategy: 指数バックオフ（2^n * base_delay）
  - MaxDelay: 24時間
- **CircuitBreakerState**: サーキットブレーカー状態
  - 値: CLOSED（正常）、OPEN（遮断）、HALF_OPEN（試行）
  - 閾値: 失敗率50%、観測期間5分
- **DeliveryPriority**: 配送優先度
  - 範囲: 1-10（1=highest、5=normal、10=lowest）
  - 用途: Follow/Accept=1、Create=3、Like=5、Delete=2

**Security Objects**
- **HTTPSignature**: HTTP Signatures署名情報
  - アルゴリズム: rsa-sha256（必須）、ed25519（将来対応）
  - ヘッダー: (request-target)、host、date、digest、content-type
  - 有効期限: 5分以内（クロックスキュー許容: ±30秒）
- **PublicKey**: 公開鍵情報
  - 形式: PEM形式、RSA 2048bit以上
  - 検証: 鍵ペア整合性、証明書チェーン（将来対応）
  - キャッシュTTL: 24時間
- **BlockReason**: ブロック理由分類
  - 値: spam、harassment、illegal_content、copyright_violation、terms_violation、manual_review
  - スコープ: Actor単位、Domain単位
- **ReportReason**: 通報理由分類
  - 値: spam、harassment、misinformation、hate_speech、violence、adult_content、copyright
  - 処理: avion-moderationサービスに転送
- **TrustScore**: Actor信頼度スコア
  - 範囲: 0.0-1.0（1.0=完全信頼）
  - 算出: アクティビティ履歴、レポート数、ドメイン信頼度
  - 更新: リアルタイム（アクティビティごと）

**Temporal & Identity Objects**
- **ActivityPubTimestamp**: ActivityPub準拠タイムスタンプ
  - 形式: ISO 8601（UTC、ミリ秒精度）
  - バリデーション: 未来日付拒否、妥当性確認
- **FederationID**: 連合処理用一意識別子
  - 形式: Snowflake ID（分散ID生成）
  - 構成: タイムスタンプ(41bit) + ワーカーID(10bit) + シーケンス(12bit)
- **DeliveryToken**: 配送追跡トークン
  - 形式: UUID v4
  - 用途: 配送状況追跡、デバッグ支援
- **CacheKey**: Redis キャッシュキー
  - 形式: `ap:{type}:{identifier}:{version}`
  - TTL管理: タイプ別TTL設定
- **ContentHash**: コンテンツハッシュ値
  - アルゴリズム: SHA-256
  - 用途: 改ざん検知、重複検出

### Domain Services

#### アンチコラプションレイヤー (Anti-Corruption Layer)
**責務**: 外部ActivityPubプロトコルとAvion内部ドメインモデル間の変換と保護境界を提供
- **実装**:
  ```go
  // domain/adapter/activitypub_translator.go
  type ActivityPubTranslator interface {
      // 外部ActivityPubオブジェクトをドメインオブジェクトに変換
      TranslateActor(apActor APActor) (*RemoteActor, error)
      TranslateActivity(apActivity APActivity) (*FederationActivity, error)
      TranslateObject(apObject APObject) (*ActivityPubObject, error)
      
      // ドメインオブジェクトを外部形式に変換
      ToActivityPubActor(actor *LocalActor) (APActor, error)
      ToActivityPubActivity(activity *LocalActivity) (APActivity, error)
      ToActivityPubObject(object *LocalObject) (APObject, error)
      
      // プロトコル固有の変換（Mastodon/Misskey拡張対応）
      HandleVendorExtensions(activity APActivity) (VendorData, error)
  }
  ```

#### SignatureVerificationService
**責務**: HTTP Signatures検証とActivityPub認証を実装するドメインサービス
- **メソッド**:
  - `VerifyHTTPSignature(request, signature, publicKey)`: HTTP署名の包括的検証（draft-cavage-http-signatures-12準拠）
  - `FetchActorPublicKey(actorURI)`: Actor公開鍵の取得と自動更新（キャッシュ戦略付き）
  - `ValidateSignatureHeaders(headers)`: 必須署名ヘッダーの検証と整合性確認
  - `DetermineSignatureAlgorithm(keyInfo)`: 署名アルゴリズムの自動選択（RSA-SHA256優先）
  - `CheckSignatureExpiry(timestamp, tolerance)`: 署名有効期限の検証（クロックスキュー考慮）
  - `ValidateDigestHeader(body, digestValue)`: リクエストボディのダイジェスト検証
  - `IsSignatureReplay(signatureId, timestamp)`: リプレイ攻撃の検出と防止
  - `RecordSignatureMetrics(result, latency)`: 署名検証の統計記録

#### FederationActivityBuilder
**責務**: ActivityPubアクティビティ生成とJSON-LD形式変換を実装するドメインサービス
- **メソッド**:
  - `BuildCreateActivity(actor, object, audience)`: Create アクティビティの構築（可視性制御付き）
  - `BuildFollowActivity(actor, targetActor, context)`: Follow アクティビティの構築（コンテキスト付き）
  - `BuildAcceptActivity(actor, followActivity)`: Accept アクティビティの構築（承認処理）
  - `BuildLikeActivity(actor, targetObject, visibility)`: Like アクティビティの構築（可視性制御）
  - `BuildAnnounceActivity(actor, targetObject, comment)`: Announce アクティビティの構築（コメント付きブースト）
  - `BuildUndoActivity(actor, targetActivity, reason)`: Undo アクティビティの構築（理由記録）
  - `BuildDeleteActivity(actor, targetObject)`: Delete アクティビティの構築（Tombstone生成）
  - `BuildMoveActivity(actor, newActor, verification)`: Move アクティビティの構築（移行検証）
  - `BuildBlockActivity(actor, targetActor)`: Block アクティビティの構築
  - `SerializeToJsonLD(activity, context)`: JSON-LD形式への正規化シリアライズ
  - `ValidateActivityStructure(activity)`: アクティビティ構造の事前検証
  - `AddDigitalSignature(activity, privateKey)`: デジタル署名の付与（将来実装）

#### FederationDeliveryPolicyService
**責務**: 配送ポリシー、リトライ戦略、サーキットブレーカー制御を決定するドメインサービス
- **メソッド**:
  - `DetermineRetryStrategy(attempt, targetDomain)`: ドメイン別リトライ戦略の決定
  - `ManageCircuitBreaker(domain, result)`: ドメイン単位サーキットブレーカーの制御
  - `CalculateBackoffDelay(attemptCount, baseDelay)`: 指数バックオフ遅延の精密計算
  - `ShouldRetryDelivery(failure, domain)`: 失敗タイプとドメイン状況に基づくリトライ判定
  - `PrioritizeDeliveryQueue(tasks, constraints)`: 配送キューの動的優先順位制御
  - `OptimizeDeliveryBatching(tasks, targetDomain)`: 共有Inbox活用による配送最適化
  - `CheckDomainHealth(domain)`: ドメイン健全性の監視と評価
  - `EstimateDeliveryTime(task, currentLoad)`: 配送完了予定時刻の算出
  - `HandlePermanentFailure(task, reason)`: 永続的失敗の処理とDLQ移動
  - `UpdateDeliveryMetrics(domain, metrics)`: 配送統計の更新と異常検知

#### ActivityPubProtocolConverter
**責務**: Avion内部形式とActivityPub標準形式間の相互変換を実装するドメインサービス
- **メソッド**:
  - `ConvertDropToNote(drop, actor, context)`: Avion DropをActivityPub Noteに変換
  - `ConvertNoteToInternalFormat(note, sourceActor)`: ActivityPub NoteをAvion内部形式に変換
  - `ConvertUserToActor(user, endpoints)`: AvionユーザーをActivityPub Actorに変換
  - `ConvertActorToUserProfile(actor)`: ActivityPub ActorをAvionユーザープロフィールに変換
  - `ConvertReactionToLike(reaction, context)`: Avion ReactionをLikeアクティビティに変換
  - `ConvertMediaAttachments(media, baseURL)`: メディア添付の形式変換とURL変換
  - `HandleCustomEmojis(content, emojiMap)`: カスタム絵文字の変換処理
  - `NormalizeContentType(contentType)`: コンテンツタイプの正規化
  - `ApplyContentWarnings(content, warnings)`: コンテンツ警告の適用
  - `ExtractAndValidateMentions(content, actor)`: メンション抽出と検証

#### ActivityPubValidator
**責務**: 受信アクティビティの包括的バリデーションとセキュリティチェックを実装するドメインサービス
- **メソッド**:
  - `ValidateIncomingActivity(activity, source)`: アクティビティの多層検証（構文・意味・セキュリティ）
  - `CheckActorAuthorization(activity, actor)`: アクター権限の検証（操作権限確認）
  - `DetectSpamPatterns(activity, history)`: スパムパターンの機械学習ベース検出
  - `ValidateActivitySemantics(activity, context)`: ActivityPub仕様に基づく意味論検証
  - `CheckRateLimits(actor, activityType, window)`: 時間窓ベースレート制限チェック
  - `ValidateObjectReferences(activity)`: オブジェクト参照の整合性検証
  - `CheckContentPolicy(content, policy)`: コンテンツポリシー違反の検出
  - `DetectAnomalousActivity(activity, baseline)`: 異常なアクティビティパターンの検出
  - `ValidateTimestamp(timestamp, tolerance)`: タイムスタンプの妥当性検証
  - `CheckDomainReputation(domain, activity)`: ドメイン評判に基づく信頼性判定
  - `ValidateAudience(activity, expectedAudience)`: 配信対象の検証

## ユースケース

<!-- 以下のユースケースは、ActivityPub federation の主要なユーザージャーニーと他マイクロサービスとの連携を包括的にカバーしています。 -->

### 他マイクロサービスとの連携ユースケース

#### avion-dropサービス連携

**Drop作成時のCreate activity送信**
1. `avion-drop`から`drop_created`イベントを受信（Redis Pub/Sub）
2. Drop情報を取得し、可視性（public/unlisted）を確認
3. ActivityBuilderでCreate(Note)アクティビティ生成
4. フォロワーのリモートインスタンスに配送タスク作成
5. 共有Inboxを利用した効率的な配送実行

**Drop削除時のDelete activity送信**
1. `avion-drop`から`drop_deleted`イベントを受信
2. Delete(Tombstone)アクティビティ生成
3. 元の配送先に削除通知を配送

**リアクション時のLike activity送信**
1. `avion-drop`から`reaction_created`イベントを受信
2. 対象Dropがリモート投稿の場合、Likeアクティビティ生成
3. 元の投稿者のInboxに配送

#### avion-userサービス連携

**ユーザー登録時のActor情報提供**
1. `avion-user`から`user_created`イベントを受信
2. Actor情報（プロフィール、公開鍵）を生成・キャッシュ
3. WebFingerリソースを登録

**フォロー時のFollow activity送信**
1. `avion-user`から`follow_created`イベントを受信
2. Followアクティビティ生成
3. 対象ActorのInboxに配送
4. Accept/Rejectの受信待機

**ブロック時のBlock activity送信**
1. `avion-user`から`user_blocked`イベントを受信
2. Blockアクティビティ生成（プライベート配送）
3. ブロック対象からの今後のアクティビティを拒否設定

**データエクスポート対応**
1. `avion-user`からエクスポート要求を受信
2. ActivityPub形式でのActor情報、Following/Followers情報を提供
3. Move activityの準備情報を生成

#### avion-mediaサービス連携

**リモートメディアのキャッシュ**
1. 受信したActivityにメディア添付を検出
2. `avion-media`にキャッシュ要求を送信
3. CDN URLの生成と返却を受信
4. ローカル表示用URLに変換

#### avion-timelineサービス連携

**グローバルタイムライン更新**
1. パブリックなリモート投稿を受信
2. `timeline_update`イベントを発行
3. `avion-timeline`がグローバルタイムラインに統合

#### avion-moderationサービス連携

**Flag activity処理**
1. リモートからFlag（通報）アクティビティ受信
2. `moderation_report`イベントを発行
3. `avion-moderation`が内容を審査
4. 必要に応じてActorやドメインをブロック

**連合モデレーション協調**
1. ローカルでの違反検出時、Flag activityを生成
2. 違反コンテンツの発信元インスタンスに通報
3. インスタンス間での信頼スコア更新

#### avion-communityサービス連携（将来実装）

**コミュニティの連合対応**
1. Group Actorとしてコミュニティを公開
2. リモートユーザーのコミュニティ参加受付
3. コミュニティ内投稿の連合配信

### WebFinger解決（リモートユーザー発見）

1. リモートサーバーまたはクライアントが `GET /.well-known/webfinger?resource=acct:alice@avion.example.com` にリクエスト
2. WebFingerQueryHandler が ResolveWebFingerQueryUseCaseを呼び出し
3. CachedWebFingerQueryService でキャッシュからWebFingerResourceDTO取得を試行
4. キャッシュヒットの場合、WebFingerResourceDTOを返却
5. キャッシュミスの場合、UserServiceClient でローカルユーザー情報取得
6. ユーザーが存在しない場合は WebFingerResourceNotFoundException
7. WebFingerResource Value Object を生成（subject、links、aliasesを含む）
8. キャッシュに保存（TTL: 1時間）
9. JSON-LD形式のWebFingerレスポンスを返却

### Actor情報の提供

1. リモートサーバーが `GET /users/alice` (Accept: application/activity+json) にリクエスト
2. ActorQueryHandler が GetLocalActorQueryUseCaseを呼び出し
3. UserServiceClient でローカルユーザー情報取得
4. ユーザーが存在しない場合は ActorNotFoundException（404）
5. ActivityBuilder で Actor オブジェクトを生成:
   - プロフィール情報（名前、説明、アイコン）
   - 公開鍵情報
   - Inbox、Outbox、Followers、Following、Featured の各エンドポイント
6. JSON-LD形式のActorレスポンスを返却

### Follow アクティビティの受信

1. リモートサーバーが `POST /users/alice/inbox` に Follow アクティビティを送信（HTTP Signature付き）
2. InboxCommandHandler が ReceiveInboxActivityCommandUseCaseを呼び出し
3. SignatureVerificationService で HTTP Signature検証:
   - keyId からリモートActorを特定
   - CachedRemoteActorQueryService で公開鍵取得（キャッシュまたはフェッチ）
   - 署名の妥当性確認
4. 署名が無効な場合は SignatureVerificationFailed（401）
5. ActivityValidator でアクティビティのビジネスルール検証:
   - Follow アクティビティの形式チェック
   - リモートActorのブロック状態確認
   - レート制限チェック
   - TrustScore基準チェック
6. RemoteActor Aggregate の更新または作成:
   - 不変条件の検証（validateInvariants）
   - TrustScoreの更新
   - LastActivityの記録
7. RemoteActorRepository を通じて永続化
8. EventPublisher で `ap_follow_received` イベントを発行
9. 202 Accepted を返却
10. (非同期) `avion-user` がイベントを購読し、フォロー承認処理実行

### ローカルDrop作成時のCreate アクティビティ配送

1. DropCreatedEventHandler が Redis Pub/Sub チャネル `drop_created` からイベント受信
2. CreateOutboxTaskCommandUseCase を呼び出し
3. Drop の visibility が連合可能か確認（public、unlisted のみ）
4. UserServiceClient でフォロワーリスト取得（リモートフォロワーのみ）
5. ActivityPubProtocolConverterでDrop→Note変換:
   - Drop の内容を Note オブジェクトに変換
   - メディア添付があれば Attachment として含める
   - メンション、ハッシュタグの処理
   - カスタム絵文字の変換
6. FederationDelivery Aggregate を生成:
   - 共有Inboxが利用可能な場合は集約最適化
   - 配送優先度の動的設定（FollowUp=高、通常投稿=中）
   - CircuitBreakerStateの事前確認
7. OutboxDeliveryTaskRepository でタスクをキューに追加
8. Redis Stream `outbox_delivery_queue` にタスクを送信

### Outbox配送ワーカーによるアクティビティ配送

1. OutboxDeliveryWorker が Redis Stream `outbox_delivery_queue` から配送タスクを取得
2. ProcessOutboxDeliveryCommandUseCase を呼び出し
3. OutboxDeliveryTaskRepository から OutboxDeliveryTask Aggregate 取得
4. DeliveryPolicy で配送戦略を決定:
   - サーキットブレーカー状態確認（ターゲットドメインごと）
   - リトライ回数とバックオフ遅延計算
5. サーキットブレーカーが OPEN の場合は一時的にスキップ
6. UserServiceClient で HTTP 署名を依頼:
   - 署名対象ヘッダーの指定（date、digest、host、(request-target)）
   - 秘密鍵による署名生成
7. ActivityPubHTTPClient でアクティビティを送信:
   - Content-Type: application/activity+json
   - HTTP Signature ヘッダー付き
   - タイムアウト設定（30秒）
8. 配送成功時（200/202）:
   - DeliveryStatus を 'delivered' に更新
   - DeliveredAt に現在時刻設定
   - DeliverySucceeded Domain Event 発行
9. 配送失敗時:
   - DeliveryAttempt Entity を追加（エラー詳細記録）
   - DeliveryPolicy でリトライ判断
   - リトライ可能な場合は NextRetryAt 設定
   - 最大リトライ超過時は DLQ に移動
   - DeliveryFailed Domain Event 発行
10. サーキットブレーカー状態更新（失敗率に基づく）
11. タスクを ACK してキューから削除

### Create アクティビティの受信（リモート投稿）

1. リモートサーバーが `POST /inbox` に Create(Note) アクティビティを送信
2. SharedInboxCommandHandler が ReceiveInboxActivityCommandUseCaseを呼び出し
3. HTTP Signature検証とアクティビティ検証（前述同様）
4. Create アクティビティから Note オブジェクトを抽出
5. RemoteObject Entity を生成:
   - ObjectURI、ObjectType、AuthorActorID の設定
   - Content の保存（JSON-LD形式）
6. RemoteObjectRepository で永続化
7. メディア添付がある場合は MediaServiceClient にキャッシュ依頼
8. EventPublisher で `ap_create_received` イベントを発行
9. (非同期) `avion-timeline` がイベントを購読し、タイムライン更新
10. (非同期) `avion-search` がイベントを購読し、検索インデックス更新

### Like アクティビティの送受信

**送信時:**
1. ReactionEventHandler が `reaction_created` イベントを受信
2. 対象 Drop が連合可能かつリモート投稿への反応の場合
3. ActivityBuilder で Like アクティビティを生成
4. OutboxDeliveryTask を作成し配送キューに追加

**受信時:**
1. Like アクティビティを Inbox で受信
2. アクティビティ検証後、object URI から対象投稿を特定
3. EventPublisher で `ap_like_received` イベントを発行
4. (非同期) `avion-drop` がリアクション情報を更新

### Block アクティビティの送受信

**送信時:**
1. BlockEventHandler が `user_blocked` イベントを受信
2. ActivityBuilder で Block アクティビティを生成
3. 対象リモートActorに Block アクティビティを配送

**受信時:**
1. Block アクティビティを受信
2. BlockedActor Aggregate を生成・更新
3. 該当リモートActorからの今後のアクティビティを拒否
4. EventPublisher で `ap_block_received` イベントを発行

### Move アクティビティによるアカウント移行

**受信時:**
1. Move アクティビティを受信（移行元 → 移行先の通知）
2. ActivityMigrationService で移行の妥当性検証
3. 移行先Actorが移行を承認しているか確認
4. 循環移行でないことを確認
5. EventPublisher で `ap_move_received` イベントを発行
6. (非同期) `avion-user` がフォロー関係を移行先に更新

### 定期的なリモートActor情報更新

1. ActorRefreshWorker が定期実行（例：6時間ごと）
2. RefreshRemoteActorCommandUseCase を呼び出し
3. LastFetchedAt が古いリモートActorを検索
4. 各リモートActorのActor情報を再取得
5. プロフィール、公開鍵、エンドポイント情報を更新
6. 到達不能なActorは一時的にマーク
7. 更新されたActor情報をキャッシュに保存

## 機能要求

<!-- 以下の機能要求は、ActivityPub仕様準拠とAvionアーキテクチャ統合の両立を目的としています。 -->

### ドメインロジック要求

* **ActivityPub標準準拠**:
  * W3C ActivityPub勧告およびActivityStreams 2.0仕様への完全準拠
  * JSON-LD形式でのアクティビティ・オブジェクト表現
  * Actor、Activity、Object の正確なスキーマ実装
  * Content-Type、Accept ヘッダーの適切な処理

* **HTTP Signatures認証**:
  * draft-cavage-http-signatures-12 準拠の実装
  * RSA-SHA256 署名アルゴリズムのサポート
  * 署名対象ヘッダー: (request-target), host, date, digest
  * 公開鍵のキャッシュと自動更新
  * 署名の有効期限検証（5分以内）

* **アクティビティ検証**:
  * アクティビティの構文・意味論的妥当性検証
  * Actor の権限検証（自身のオブジェクトのみ操作可能）
  * 重複アクティビティの検出と冪等性保証
  * スパムフィルタリングとレート制限

* **配送信頼性**:
  * 指数バックオフによるリトライ機構（最大5回）
  * サーキットブレーカーによる障害ドメイン制御
  * デッドレターキューによる永続的失敗処理
  * 配送優先度による効率的なキュー処理

### APIエンドポイント要求

* **ActivityPub エンドポイント**:
  * Actor情報提供のための HTTP API
  * WebFinger リソース解決のための HTTP API
  * Inbox アクティビティ受信のための HTTP API
  * Collection（Outbox、Followers等）提供のための HTTP API

* **内部連携API**:
  * リモート情報取得のための gRPC API
  * 配送統計取得のための gRPC API
  * ブロック・通報管理のための gRPC API

* **認証・認可**:
  * HTTP Signatures による アクティビティ認証
  * Bearer Token による 内部サービス認証
  * Actor レベルの権限制御

### データ要求

* **Actor情報**:
  * プロフィール情報（名前、説明、アイコン、ヘッダー）の保存
  * 公開鍵情報の安全な管理とキャッシュ
  * エンドポイント情報（Inbox、Outbox等）の管理
  * Actor の状態管理（active、suspended、moved）

* **アクティビティ管理**:
  * アクティビティの一意識別子管理
  * アクティビティタイプごとの適切な処理
  * 処理済みアクティビティの重複排除
  * アクティビティの有効期限管理

* **配送管理**:
  * 配送タスクの状態追跡
  * 配送試行履歴の詳細記録
  * 失敗原因の分類と統計
  * 配送優先度とスケジューリング

* **キャッシュ戦略**:
  * リモートActor情報の効率的キャッシュ（TTL: 1時間）
  * 公開鍵情報の長期キャッシュ（TTL: 24時間）
  * WebFingerレスポンスのキャッシュ（TTL: 1時間）
  * 配送先エンドポイントのキャッシュ

## 技術的要求

### レイテンシ

* **WebFinger解決**: 平均 200ms 以下、p99 500ms 以下（キャッシュヒット時: 平均 50ms、p99 100ms）
* **Actor情報取得**: 平均 150ms 以下、p99 400ms 以下（キャッシュヒット時: 平均 30ms、p99 80ms）
* **Inbox アクティビティ受信**: 平均 300ms 以下、p99 800ms 以下（署名検証・バリデーション含む）
* **HTTP Signature検証**: 平均 100ms 以下、p99 250ms 以下（キャッシュヒット時: 平均 20ms、p99 50ms）
* **Outbox配送処理**: 平均 2秒 以下、p99 5秒 以下（リモートサーバー応答時間とリトライ含む）
* **アクティビティ検証**: 平均 50ms 以下、p99 150ms 以下（スパム検出・ポリシーチェック含む）
* **バッチ配送最適化**: 共有Inbox利用時に配送レイテンシ30%削減

### 可用性

* **サービス可用性**: 99.9% 以上（年間ダウンタイム8.76時間以内）
* **Kubernetes可用性**: 3レプリカでのローリングアップデート、ゼロダウンタイム保証
* **配送成功率**: 95% 以上（一時的な障害除く）、最終配送成功率: 99% 以上（リトライ含む）
* **HTTP Signature検証成功率**: 99% 以上（正当な署名のみ）
* **キャッシュヒット率**: Actor情報 80% 以上、公開鍵 90% 以上、WebFingerレスポンス 85% 以上
* **Circuit Breaker効果**: 障害ドメイン自動遮断により全体可用性を保護
* **Graceful Shutdown**: 30秒以内での正常終了、進行中タスクの完了保証

### スケーラビリティ

* **水平スケーリング**: ステートレス設計によるKubernetes HPA対応（CPU・メモリベース）
* **処理能力**: リモートActor 100万件以上、配送タスクキュー 100万件以上の管理
* **同時処理**: 1,000並行配送タスク、1,000同時接続リモートサーバー対応
* **スループット拡張性**: インスタンス数に比例したリニアスケーリング（I/Oボトルネック除く）
* **データベース最適化**: インデックス戦略とクエリ最適化によりレスポンス時間の線形増加抑制
* **Redis Cluster対応**: 分散キャッシュとストリーム処理による水平スケール
* **負荷分散**: 配送対象ドメインによるシャーディングで処理分散

### Federation Performance Metrics

* **配送スループット**: 10,000 deliveries/min 以上（単一インスタンス）、50,000 deliveries/min（5インスタンス構成）
* **Inbox処理能力**: 1,000 requests/min 以上（単一インスタンス）、線形スケールアップ対応
* **WebFinger解決**: 500 requests/min 以上（キャッシュ効果により実質無制限）
* **Actor情報取得**: 1,000 requests/min 以上（キャッシュヒット時は10倍のスループット）
* **バッチ処理効率**: 共有Inbox利用により配送効率を200%向上
* **メモリ使用量**: 1インスタンス当たり最大2GB（100万Actor情報キャッシュ含む）
* **CPU使用率**: 通常時30%以下、ピーク時80%以下（署名検証による負荷）

### セキュリティ

* **認証セキュリティ**:
  * HTTP Signatures の厳格な検証
  * 署名の有効期限チェック（最大5分）
  * なりすまし攻撃の防止
  * リプレイ攻撃の防止

* **アクセス制御**:
  * Actor/ドメインレベルのブロック機能
  * アクティビティタイプ別の権限制御
  * レート制限による DoS 攻撃対策
  * 入力値の厳格なバリデーション

* **データ保護**:
  * 秘密鍵の安全な管理（`avion-user` に委任）
  * 通信の TLS 暗号化強制
  * ログでの機密情報マスキング
  * GDPR 準拠のデータ削除対応

### データ整合性

* **Transaction Management**:
  * **ACID準拠**: 重要な操作（フォロー関係、ブロック処理）での厳格なトランザクション境界
  * **分散トランザクション**: Saga パターンによる長期間トランザクション、補償操作対応
  * **Isolation Level**: Read Committed基本、必要時Serializable、デッドロック回避
  * **Atomic Operations**: アクティビティ受信→検証→永続化→イベント発行の原子性保証

* **Consistency Models**:
  * **Strong Consistency**: Actor状態、ブロック情報、認証データは強一貫性
  * **Eventual Consistency**: 配送統計、キャッシュデータは結果整合性許容
  * **Causal Consistency**: アクティビティ順序の因果関係保証（Follow→Accept等）
  * **Session Consistency**: 同一セッション内での一貫した読み取り保証

* **Conflict Resolution**:
  * **Last-Writer-Wins**: Actor情報更新での基本戦略、タイムスタンプベース
  * **Version Vectors**: 並行更新検出、自動マージ、手動介入フラグ
  * **Business Rules**: ドメイン知識に基づく競合解決（削除>更新>作成の優先度）
  * **Compensation Logic**: 失敗時の補償処理、Undo操作、状態巻き戻し

* **Validation & Constraints**:
  * **Schema Validation**: JSON Schema厳格適用、拡張フィールド許容設定
  * **Business Rules**: ドメイン固有制約（自己フォロー禁止、循環参照防止）
  * **Referential Integrity**: 外部キー制約、CASCADE DELETE、孤立レコード防止
  * **Data Quality**: 重複検出、異常値検出、自動修正ルール

* **Backup & Recovery**:
  * **Backup Strategy**: 日次フルバックアップ、WAL連続バックアップ、増分バックアップ
  * **RTO/RPO**: RTO 1時間以内、RPO 15分以内、自動フェイルオーバー
  * **Point-in-Time Recovery**: 任意時点復旧、操作ログ再生、段階的復旧
  * **Disaster Recovery**: 地理的分散バックアップ、クロスリージョン複製、BCP対応
  * **Testing**: 月次復旧テスト、年次DR訓練、復旧手順書保守

### その他技術要件

* **ステートレス設計**:
  * アプリケーション状態の外部化（Redis、PostgreSQL）
  * Kubernetes での水平スケーリング対応
  * ローリングアップデートでのゼロダウンタイム

* **Observability**:
  * OpenTelemetry SDK による分散トレーシング
  * Prometheus メトリクス による監視
  * 構造化ログ による詳細分析
  * ヘルスチェックエンドポイント提供

* **フォルトトレラント**:
  * サーキットブレーカーによる障害伝播防止
  * 指数バックオフリトライによる回復力
  * デッドレターキューによる確実な失敗処理
  * グレースフルシャットダウン対応

## テスト戦略

本サービスは共通テスト戦略に従い、TDD（テストファースト）開発を採用します。

### テスト要件

* **カバレッジ目標**:
  * ユニットテスト: 90%以上
  * クリティカルパス（フェデレーション通信、署名検証、アクター管理）: 95%以上
  * 統合テスト: 主要なユースケースの100%カバー

* **テストパターン**:
  * table-drivenテスト必須（Go標準）
  * 時刻処理には`github.com/newmo-oss/ctxtime`使用
  * 外部依存はモックで分離

* **モック生成戦略**:
  * ツール: `go.uber.org/mock/gomock`
  * 配置先: `tests/mocks/[original-package-path]`
  * インターフェースに`//go:generate mockgen`ディレクティブ必須

### 環境管理

* **Type Safety**:
  * 設定構造体による型安全な環境変数管理
  * バリデーション付き設定ローダー実装
  * 必須項目のタグ付け（`required:"true"`）

* **Early Failure**:
  * 必須環境変数の起動時検証
  * 不正な設定値での即座の終了
  * 明確なエラーメッセージ出力

### ActivityPub固有テスト

* **プロトコルテスト**:
  * HTTP Signature検証テスト
  * JSON-LD正規化テスト
  * ActivityStreams 2.0準拠性テスト

* **相互運用性テスト**:
  * Mastodon互換性テストスイート
  * Misskey互換性テストスイート
  * Pleroma互換性テストスイート

* **フェデレーションテスト**:
  * アクター探索シナリオテスト
  * アクティビティ配送テスト
  * エラー処理・リトライテスト

## 決まっていないこと

* **ActivityPub拡張仕様への対応**:
  * Mastodon独自拡張（カスタム絵文字、投票、ブックマーク等）への対応範囲
  * Misskey独自拡張（Renote、リアクション、チャンネル等）への対応範囲
  * 他のActivityPub実装固有機能への対応優先順位

* **高度なモデレーション機能**:
  * 自動スパム検出アルゴリズムの実装詳細
  * コンテンツフィルタリングルールの設定方法
  * 機械学習ベースの不正検出システムとの連携

* **パフォーマンス最適化**:
  * 大規模インスタンス（100万ユーザー以上）での配送戦略
  * バッチ配送とリアルタイム配送の使い分け基準
  * キャッシュ戦略の詳細調整（TTL、容量制限等）

* **相互運用性テスト**:
  * 他のActivityPub実装との互換性テスト戦略
  * エッジケースでの動作保証範囲
  * プロトコル仕様解釈の違いへの対処方針
  
  テスト実装については[共通テスト戦略](../common/testing-strategy.md)を参照。

* **運用面での詳細**:
  * リモート情報のデータ保持ポリシー（GDPR対応）
  * 配送失敗時の通知・アラート方法
  * ドメインブロックリストの管理・更新プロセス
  * インシデント時のフェイルオーバー戦略

* **将来的な拡張**:
  * ActivityPub Client-to-Server (C2S) プロトコル対応時期
  * リレーサーバー機能実装の要否
  * 新しいActivityPub仕様（Extensions）への追従方針
  * 他の分散プロトコル（AT Protocol等）との併用可能性
