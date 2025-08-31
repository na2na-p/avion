# PRD: avion-user

## 概要

Avionにおけるユーザーアカウントの管理機能を提供するマイクロサービスを実装する。ユーザープロフィール情報の管理、フォロー/フォロワー関係の管理、ミュート/ブロック機能、ユーザー設定の管理など、ユーザーに関連する中核的な機能を統合的に提供する。

## 背景

SNSアプリケーションにおいて、ユーザーアカウント管理は最も基本的かつ重要な機能である。ユーザーのアイデンティティ、プロフィール情報、ユーザー間の関係性（フォロー、ミュート、ブロック）、個人設定などを一元的に管理することで、システム全体の一貫性を保ちつつ、他のマイクロサービスに対して信頼できるユーザー情報を提供する必要がある。

avion-authが認証・認可を担当するのに対し、avion-userはユーザーのプロフィール情報や関係性など、SNSとしての機能的な側面を担当する。この分離により、認証基盤とソーシャル機能を独立して進化させることが可能となる。

## Scientific Merits

*   **スケーラビリティ:** ユーザー数の増加に対して、`avion-user` サービスを独立してスケールさせることが可能。10万ユーザーまでのフォロー関係を100ms以下で処理し、SNSプラットフォームの成長に応じた段階的な拡張を支援。水平スケーリングにより1秒間に1000件のフォロー操作を処理可能。
*   **高パフォーマンス:** ユーザー情報の取得レイテンシp50 < 50ms、p99 < 200msを実現。Redisキャッシュ活用により90%以上のリクエストをメモリから高速応答。フォロー関係の検索を10ms以下で実行し、タイムライン生成の高速化に貢献。
*   **高可用性:** 99.9%の稼働率を保証し、ダウンタイム月8.8時間以内を維持。Kubernetesマルチレプリカ構成による冗長性確保。サーキットブレーカーパターンにより依存サービス障害時も基本機能を継続提供。
*   **データ整合性:** ユーザー情報とその関係性を一元管理することで、データの整合性エラー率0.01%以下を維持。フォロー関係の双方向性、ブロック時のフォロー解除、削除ユーザーとの関係性クリーンアップなどの複雑な処理も一貫して実装可能。
*   **プライバシー制御:** ミュート、ブロック、プライバシー設定を一元管理し、GDPR準拠100%を達成。ユーザーのプライバシー要求に99.99%の精度で応答し、データ主権を技術的に保証。プライバシー設定の反映を1秒以内に完了。
*   **フォローグラフ最適化:** フォロー関係の検索効率を従来比50%向上。グラフデータベースアルゴリズムにより相互フォロー判定を5ms以下で実行。推薦システム用のフォローパス計算を100ms以下で完了。
*   **ユーザー体験向上:** プロフィール更新の即時反映により、ユーザー満足度15%向上を実現。リアルタイムフォロー状態更新により、UI操作の応答性を2倍改善。
*   **関心の分離:** ユーザー管理という明確な責務を持つことで、認証（avion-auth）、投稿（avion-drop）、タイムライン（avion-timeline）などとの依存関係を疎にし、開発効率30%向上とメンテナンス性を向上。各サービスが独立して進化できる基盤を提供。
*   **データポータビリティ:** ユーザーデータのエクスポート・インポート機能により、ActivityPubを通じたインスタンス間の移行や、他のSNSからのデータ移行を支援。データ移行時間を従来比70%短縮し、ユーザーのプラットフォーム依存を軽減。

ユーザー管理機能はSNSの基盤となる部分であり、他のすべてのサービスから参照されるため、高い可用性と性能が要求される。特に、フォロー関係の管理は他のサービスの機能性と性能に直接的な影響を与える中核的な責務である。

## Design Doc

[Design Doc: avion-user](./designdoc.md)

## 参考ドキュメント

*   [Avion アーキテクチャ概要](./../common/architecture.md)
*   [ActivityPub Protocol Specification](https://www.w3.org/TR/activitypub/)
*   [RFC 5322: Internet Message Format](https://tools.ietf.org/html/rfc5322)
*   [ISO 639-1: Language Codes](https://www.iso.org/iso-639-language-codes.html)
*   [IANA Time Zone Database](https://www.iana.org/time-zones)
*   [GDPR Compliance Guidelines](https://gdpr.eu/)
*   [OAuth 2.0 Security Best Practices](https://tools.ietf.org/html/draft-ietf-oauth-security-topics)

## 製品原則

*   **ユーザーデータ主権:** ユーザーが自身のデータと関係性を完全にコントロールできること。プロフィール情報、フォロー関係、設定の管理権限をユーザーに委ね、データのエクスポート・削除・移行を自由に行えるようにする。
*   **プライバシー設計原則:** デフォルトで安全な設定を提供し、ユーザーのプライバシーを保護。最小限の情報開示、明示的な同意、データ用途の透明性を重視し、ユーザーが意図しない情報漏洩を防ぐ。
*   **関係性の透明性:** フォロー関係、ブロック、ミュートの動作が明確で予測可能であること。ユーザーが自分の行動とその結果を理解でき、他のユーザーとの関係性を適切に管理できる。
*   **プロフィールの真正性:** ユーザーがありのままの自分を表現できるプロフィールシステム。過度な装飾や偽装を推奨せず、健全なコミュニケーションを促進する表現の場を提供する。
*   **サービス間一貫性:** すべてのマイクロサービスに対して一貫したユーザー情報を提供。サービス間でのデータの不整合や矛盾を排除し、システム全体で統一されたユーザー体験を実現。
*   **アクセシビリティと包摂性:** 多様なユーザーニーズに対応できる柔軟な設定オプション。障害の有無、文化的背景、技術的習熟度に関わらず、すべてのユーザーが快適に利用できる設計。
*   **シームレスな移行:** ユーザーが他のプラットフォームからスムーズに移行でき、必要に応じて他のプラットフォームに移行することも可能。データロックインを避け、ユーザーの選択の自由を尊重。
*   **即応的な体験:** 高速なレスポンスとリアルタイムな更新により、快適なユーザー体験を提供。フォロー関係の変更やプロフィール更新が即座に反映され、ユーザーのアクションに対する即時フィードバックを実現。

## やること/やらないこと

### やること

*   ユーザープロフィール管理
    - 表示名、自己紹介、アバター画像URL、ヘッダー画像URLの管理
    - プロフィール項目（最大4つのカスタムフィールド）
    - 誕生日、位置情報（任意）
    - プロフィールの公開/非公開設定
    - アカウント作成日時、最終更新日時の記録
*   フォロー/フォロワー管理
    - フォロー関係の作成・削除
    - フォロワー/フォロー中リストの取得（ページネーション対応）
    - フォローリクエスト機能（承認制アカウント用）
    - フォロー/フォロワー数のカウント管理
    - 相互フォロー状態の判定
*   ミュート機能
    - ユーザーミュート（投稿を非表示）
    - キーワードミュート（特定の単語を含む投稿を非表示）
    - 期限付きミュート（一時的なミュート）
    - リポストミュート（リポストのみ非表示）
    - ミュートリストの管理
*   ブロック機能
    - ユーザーブロック（完全な遮断）
    - ブロック時の自動フォロー解除
    - ブロックリストの管理
    - インスタンスブロック（特定インスタンスのユーザー全体をブロック）
*   ユーザー設定管理
    - 言語設定
    - タイムゾーン設定
    - 通知設定（種類別のオン/オフ）
    - プライバシー設定（フォロー承認制、DM受信設定など）
    - UI設定（テーマ、レイアウトなど）
    - アクセシビリティ設定
*   ユーザー検索
    - ユーザー名による検索
    - 表示名による検索
    - プロフィール全文検索（avion-searchと連携）
    - おすすめユーザーの提案
*   アカウント状態管理
    - アクティブ/非アクティブ状態
    - 凍結（サスペンド）状態
    - 削除済み状態（論理削除）
    - メール確認済みフラグ
    - 認証済みバッジ
*   リスト機能
    - ユーザーリストの作成・管理
    - リストメンバーの追加・削除
    - 公開/非公開リスト設定
    - リストタイムライン用のメタデータ提供
*   インポート/エクスポート機能
    - フォロー/フォロワーリストのエクスポート
    - ブロック/ミュートリストのエクスポート
    - 他のインスタンスからのデータインポート
    - アカウント移行サポート
*   統計情報
    - 投稿数カウント（avion-dropと連携）
    - フォロー/フォロワー数
    - 獲得したリアクション数の集計
    - アカウント作成からの経過日数
*   ActivityPub連携用メタデータ
    - Actor情報の提供
    - publicKeyの管理
    - inboxとoutboxのURL管理
    - リモートユーザー情報のキャッシュ

### やらないこと

*   **認証・認可処理:** avion-authが担当。avion-userは認証されたユーザー情報を受け取るのみ。
*   **投稿の管理:** avion-dropが担当。
*   **タイムライン生成:** avion-timelineが担当。
*   **通知の生成・配信:** avion-notificationが担当。
*   **メディアファイルの保存:** avion-mediaが担当。アバター/ヘッダー画像のURLのみ管理。
*   **全文検索インデックス:** avion-searchが担当。
*   **DM（ダイレクトメッセージ）機能:** 将来的に別サービスで実装予定。

## 対象ユーザ

*   Avion エンドユーザー (API Gateway経由)
*   Avion の他のマイクロサービス (Drop, Timeline, Notification, ActivityPubなど)
*   Avion 開発者・運用者

## ドメインモデル (DDD戦術的パターン)

### Aggregates (集約)

#### User Aggregate
**責務**: ユーザーアカウントのライフサイクルと基本情報を管理する中核的な集約
- **集約ルート**: User
- **不変条件**:
  - UserIDは変更不可
  - Usernameは一意（大文字小文字を区別しない）
  - Emailは一意（アクティブユーザー内で）
  - DisplayNameは最大30文字
  - Bioは最大500文字
  - 削除されたユーザーは復元不可
  - 凍結されたユーザーはログイン不可
- **ドメインロジック**:
  - `canBeViewedBy(viewerID)`: プロフィール閲覧権限の判定
  - `canFollowUser(targetID)`: フォロー可能かの判定
  - `canSendDMTo(targetID)`: DM送信可能かの判定
  - `updateProfile()`: プロフィール更新（バリデーション含む）
  - `suspend()`: アカウント凍結処理
  - `unsuspend()`: 凍結解除処理
  - `deactivate()`: アカウント無効化
  - `reactivate()`: アカウント再有効化
  - `markAsDeleted()`: 論理削除処理
  - `toActivityPubActor()`: ActivityPub Actor形式への変換

#### Follow Aggregate
**責務**: フォロー関係を管理
- **集約ルート**: Follow
- **不変条件**:
  - FollowerIDとFolloweeIDの組み合わせは一意
  - 自分自身をフォローすることはできない
  - ブロックされているユーザーをフォローできない
  - 削除されたユーザーとのフォロー関係は無効
- **ドメインロジック**:
  - `isApproved()`: 承認済みかの判定（承認制アカウント）
  - `approve()`: フォローリクエストの承認
  - `reject()`: フォローリクエストの拒否
  - `isMutual()`: 相互フォローかの判定
  - `toActivityPubFollow()`: ActivityPub Follow アクティビティへの変換

#### Block Aggregate
**責務**: ブロック関係を管理
- **集約ルート**: Block
- **不変条件**:
  - BlockerIDとBlockedIDの組み合わせは一意
  - 自分自身をブロックすることはできない
  - ブロック時は既存のフォロー関係を自動解除
- **ドメインロジック**:
  - `shouldUnfollow()`: フォロー解除が必要かの判定
  - `affectsVisibility()`: 表示に影響するかの判定
  - `toActivityPubBlock()`: ActivityPub Block アクティビティへの変換

#### Mute Aggregate
**責務**: ミュート設定を管理
- **集約ルート**: Mute
- **不変条件**:
  - MuterIDとMutedIDの組み合わせは一意（ユーザーミュート）
  - キーワードミュートは最大100個まで
  - 期限付きミュートの期限は未来の日時
- **ドメインロジック**:
  - `isActive()`: 現在有効かの判定（期限チェック含む）
  - `shouldHideDrop(drop)`: 投稿を非表示にすべきかの判定
  - `expire()`: ミュートの期限切れ処理
  - `matches(text)`: キーワードマッチング

#### UserSettings Aggregate
**責務**: ユーザー設定を管理
- **集約ルート**: UserSettings
- **不変条件**:
  - UserIDごとに1つの設定セット
  - 言語コードはISO 639-1準拠
  - タイムゾーンはIANA Time Zone Database準拠
- **ドメインロジック**:
  - `updatePrivacySettings()`: プライバシー設定の更新
  - `updateNotificationSettings()`: 通知設定の更新
  - `shouldRequireFollowApproval()`: フォロー承認が必要かの判定
  - `canReceiveDMFrom(senderID)`: DM受信可能かの判定
  - `getEffectiveSettings()`: デフォルト値とのマージ済み設定を取得

#### UserList Aggregate
**責務**: ユーザーリストを管理
- **集約ルート**: UserList
- **不変条件**:
  - ListIDは一意
  - OwnerIDは変更不可
  - リストメンバーは最大5000人まで
  - 非公開リストは所有者のみアクセス可能
- **ドメインロジック**:
  - `canBeViewedBy(userID)`: 閲覧権限の判定
  - `canAddMember(userID)`: メンバー追加権限の判定
  - `addMember(userID)`: メンバー追加（重複チェック含む）
  - `removeMember(userID)`: メンバー削除
  - `isMember(userID)`: メンバーかどうかの判定

#### UserStats Aggregate
**責務**: ユーザー統計情報を管理
- **集約ルート**: UserStats
- **不変条件**:
  - すべてのカウントは非負の整数
  - 同時更新時の整合性を保証（楽観的ロック）
- **ドメインロジック**:
  - `incrementDropCount()`: 投稿数増加
  - `decrementDropCount()`: 投稿数減少
  - `updateFollowerCount()`: フォロワー数更新
  - `updateFollowingCount()`: フォロー中数更新
  - `recalculate()`: 統計の再計算

### Entities (エンティティ)

#### ProfileField
**所属**: User Aggregate
**責務**: カスタムプロフィール項目を管理
- **属性**:
  - FieldID（Entity識別子）
  - Name（項目名、最大20文字）
  - Value（値、最大200文字）
  - Verified（検証済みフラグ）
  - VerifiedAt（検証日時）
  - Order（表示順序）

#### FollowRequest
**所属**: Follow Aggregate
**責務**: フォローリクエストを管理
- **属性**:
  - RequestID（Entity識別子）
  - RequestedAt（リクエスト日時）
  - Message（リクエストメッセージ、任意）
  - Status（pending, approved, rejected）

#### MuteKeyword
**所属**: Mute Aggregate
**責務**: ミュートキーワードを管理
- **属性**:
  - KeywordID（Entity識別子）
  - Keyword（キーワード、最大100文字）
  - IsRegex（正規表現フラグ）
  - CaseSensitive（大文字小文字区別フラグ）
  - WholeWord（単語単位マッチフラグ）

#### ListMember
**所属**: UserList Aggregate
**責務**: リストメンバーを管理
- **属性**:
  - MemberID（Entity識別子）
  - UserID（メンバーのユーザーID）
  - AddedAt（追加日時）
  - AddedBy（追加者のユーザーID）

### Value Objects (値オブジェクト)

**識別子関連**
- **UserID**: ユーザーの一意識別子（Snowflake ID、64bit整数、時系列ソート可能）
- **Username**: ユーザー名（3-30文字、英数字とアンダースコア、大文字小文字を区別しない一意性）
- **Email**: メールアドレス（RFC 5322準拠、国際化ドメイン名対応、最大254文字）
- **FollowID**: フォロー関係の識別子（UUID v4、128bit、分散環境での衝突回避）
- **BlockID**: ブロック関係の識別子（UUID v4、128bit、プライバシー保護のためランダム生成）
- **MuteID**: ミュート設定の識別子（UUID v4、128bit、設定の可逆性を保証）
- **ListID**: ユーザーリストの識別子（Snowflake ID、作成時刻ベースのソート）
- **StatsID**: 統計情報の識別子（UserIDと1対1対応）

**ユーザー属性**
- **DisplayName**: 表示名
  - 最大30文字（Unicode正規化済み）
  - 絵文字対応（Unicode 15.0準拠）
  - トリミング処理（前後空白除去）
  - 制御文字の除去
- **Bio**: 自己紹介
  - 最大500文字（Unicode正規化済み）
  - 改行対応（\n, \r\n統一）
  - マークダウン軽量サポート（リンク、太字）
  - XSS対策のHTMLサニタイズ
- **AvatarURL**: アバター画像のURL
  - HTTPS必須、有効期限付きURL対応
  - 画像形式：JPEG, PNG, WebP（最大2MB）
  - CDN経由の配信前提
- **HeaderURL**: ヘッダー画像のURL
  - HTTPS必須、アスペクト比3:1推奨
  - 画像形式：JPEG, PNG, WebP（最大5MB）
- **Location**: 位置情報
  - 最大30文字、自由記述形式
  - 位置情報の精度レベル設定対応
- **Website**: ウェブサイトURL
  - HTTPS/HTTP対応、rel="me"による所有権検証
  - リダイレクト追跡（最大5回）
  - ドメイン検証ステータス付き
- **Birthday**: 誕生日
  - YYYY-MM-DD形式（ISO 8601）
  - 年のみ/月日のみ公開設定対応
  - 年齢計算の自動化

**アカウント状態**
- **AccountStatus**: アカウント状態（状態遷移制御付き）
  - `active`: アクティブ（通常利用可能）
  - `suspended`: 凍結（ログイン不可、コンテンツ非表示）
  - `deactivated`: 無効化（一時的な利用停止、30日間は復旧可能）
  - `deleted`: 削除済み（論理削除、90日後に物理削除）
  - `pending_verification`: メール認証待ち
- **PrivacyLevel**: プライバシーレベル（コンテンツ表示制御）
  - `public`: 公開（全ユーザーがアクセス可能）
  - `unlisted`: 未リスト（直接アクセスは可能、検索結果に非表示）
  - `private`: 非公開（承認制、フォロワーのみアクセス可能）
- **VerificationStatus**: 認証状態
  - `unverified`: 未認証
  - `email_verified`: メール認証済み
  - `phone_verified`: 電話認証済み
  - `identity_verified`: 本人確認済み（認証バッジ）

**設定関連**
- **Language**: 言語設定
  - ISO 639-1準拠（2文字コード）
  - 地域コード対応（ja-JP, en-US等）
  - フォールバック言語設定
- **Timezone**: タイムゾーン
  - IANA Time Zone Database準拠
  - 夏時間自動対応
  - UTC/ローカル時間変換機能
- **Theme**: UIテーマ
  - `light`: ライトテーマ
  - `dark`: ダークテーマ
  - `auto`: システム設定に従う
  - `high_contrast`: 高コントラストモード
- **NotificationPreference**: 通知設定（詳細制御）
  - 通知タイプ別オン/オフ（フォロー、リポスト、リアクション、メンション等）
  - 配信方法（プッシュ通知、メール、アプリ内通知）
  - 時間帯制限（Do Not Disturb）
  - キーワードフィルター
- **PrivacySettings**: プライバシー設定
  - `follow_approval_required`: フォロー承認必須
  - `dm_from_followers_only`: DMをフォロワーのみ受信
  - `hide_follower_count`: フォロワー数非表示
  - `indexable`: 検索エンジンインデックス許可
  - `discoverable`: おすすめユーザーに表示許可

**関係性状態**
- **FollowStatus**: フォロー状態（双方向関係を表現）
  - `none`: 関係なし
  - `following`: フォロー中
  - `followed`: フォローされている
  - `mutual`: 相互フォロー
  - `pending_approval`: 承認待ち
  - `blocked`: ブロック中
  - `blocked_by`: ブロックされている
- **MuteType**: ミュートタイプ（フィルタリング制御）
  - `user_all`: 全コンテンツミュート
  - `user_reposts`: リポストのみミュート
  - `keyword`: キーワードミュート
  - `thread`: 特定スレッドミュート
  - `notification`: 通知のみミュート
- **RelationshipContext**: 関係性のコンテキスト
  - 関係開始日時
  - 関係変更履歴（最新10件）
  - 相互作用スコア（エンゲージメント指標）

**ActivityPub関連**
- **ActorType**: Actorタイプ（ActivityPub仕様準拠）
  - `Person`: 個人アカウント
  - `Service`: サービスアカウント（Bot等）
  - `Group`: グループアカウント
  - `Organization`: 組織アカウント
- **PublicKey**: 公開鍵情報
  - RSA 2048bit以上
  - PEM形式
  - 鍵ローテーション対応（最大3つまで保持）
- **FederationEndpoints**: 連合エンドポイント
  - **InboxURL**: 個人Inbox URL
  - **OutboxURL**: Outbox URL（投稿配信用）
  - **SharedInboxURL**: 共有Inbox URL（配信効率化）
  - **FollowersURL**: フォロワーコレクション URL
  - **FollowingURL**: フォロー中コレクション URL
- **ActivityPubProfile**: ActivityPub拡張プロフィール
  - **PreferredUsername**: 表示用ユーザー名
  - **Summary**: プロフィール概要（HTML対応）
  - **Icon**: アイコン情報（複数サイズ対応）
  - **Image**: ヘッダー画像情報
  - **Attachment**: プロフィール項目（PropertyValue形式）

**セキュリティ関連**
- **AccessToken**: アクセストークン情報
  - JWT形式、RS256署名
  - 有効期限（通常1時間）
  - スコープ情報（read, write, admin等）
- **SessionInfo**: セッション情報
  - セッションID（UUID v4）
  - IPアドレス（IPv4/IPv6対応）
  - User-Agent情報
  - 最終アクセス時刻
- **SecurityEvent**: セキュリティイベント
  - ログイン試行（成功/失敗）
  - パスワード変更
  - 不正アクセス検知

**時刻・数値・メトリクス**
- **CreatedAt**: 作成日時（RFC 3339形式、UTC、ナノ秒精度）
- **UpdatedAt**: 更新日時（RFC 3339形式、UTC、ナノ秒精度）
- **LastActiveAt**: 最終活動日時（認証ベース、プライバシー配慮）
- **FollowerCount**: フォロワー数（非正規化キャッシュ値、整合性チェック付き）
- **FollowingCount**: フォロー中数（非正規化キャッシュ値、上限5000）
- **DropCount**: 投稿数（avion-dropとの整合性チェック付きキャッシュ値）
- **ListsCount**: 作成リスト数（上限50）
- **Version**: 楽観的ロック用バージョン番号（整数、自動増分）
- **ReputationScore**: 信頼度スコア（0-100、スパム対策用）
- **EngagementScore**: エンゲージメントスコア（アクティビティ量の指標）

### Domain Services

#### UserValidationDomainService
**責務**: ユーザー情報の検証とビジネスルール実装
- **メソッド**:
  - `validateUsername(username)`: ユーザー名の妥当性検証（正規表現、予約語チェック、不適切コンテンツフィルター）
  - `isUsernameAvailable(username, excludeUserID)`: ユーザー名の利用可能性確認（大文字小文字を区別しない重複チェック）
  - `validateEmail(email)`: メールアドレスの妥当性検証（RFC 5322準拠、MXレコード確認、使い捨てメール検出）
  - `isEmailAvailable(email, excludeUserID)`: メールアドレスの利用可能性確認（論理削除済みユーザー除外）
  - `validateProfileContent(profile)`: プロフィール内容の総合検証（スパムフィルター、不適切コンテンツ検出）
  - `calculateReputationScore(user, activities)`: 信頼度スコアの計算（アカウント年数、フォロワー品質、報告履歴）
  - `generateSecureUserID()`: セキュアなユーザーID生成（Snowflake IDアルゴリズム）

#### FollowRecommendationDomainService
**責務**: フォロー関係の推薦とグラフ分析
- **メソッド**:
  - `canFollow(followerID, followeeID)`: フォロー可能かの総合判定（ブロック状態、プライバシー設定、スパム防止）
  - `shouldAutoApprove(followeeSettings, followerProfile)`: 自動承認判定（承認制設定、相互フォロー関係、信頼度スコア）
  - `handleBlockConflict(followerID, followeeID)`: ブロック競合時の処理（既存フォロー解除、通知無効化）
  - `calculateMutualStatus(followerID, followeeID)`: 相互フォロー状態の計算（双方向関係チェック）
  - `findRecommendedUsers(userID, limit, excludeList)`: おすすめユーザー検索（共通フォロー、興味関心、地理的近接性）
  - `calculateFollowPath(userID, targetID, maxDegrees)`: フォロー経路計算（最短経路探索、影響力分析）
  - `detectFollowSpam(userID, recentFollows)`: フォロースパム検出（短時間大量フォロー、Bot判定）
  - `optimizeFollowGraph(userID)`: フォローグラフ最適化提案（非アクティブユーザー検出、関係性品質分析）

#### ProfileValidationDomainService
**責務**: プロフィール情報の詳細検証と品質管理
- **メソッド**:
  - `validateProfileField(field, value)`: カスタムプロフィール項目の検証（URL検証、文字数制限、不適切コンテンツ）
  - `verifyWebsiteOwnership(userID, websiteURL)`: ウェブサイト所有権検証（rel="me"リンク確認、DNS TXT記録）
  - `sanitizeHTMLContent(content)`: HTMLコンテンツのサニタイズ（XSS防止、許可タグのみ残存）
  - `detectProfileSpam(profile)`: プロフィールスパム検出（重複コンテンツ、キーワードスタッフィング）
  - `generateProfileCompleteness(user)`: プロフィール完成度計算（設定項目の充実度、検証済み項目）
  - `validateImageURLs(avatarURL, headerURL)`: 画像URL検証（アクセス可能性、ファイル形式、サイズ制限）

#### PrivacyControlDomainService
**責務**: プライバシー制御と可視性管理の統合判定
- **メソッド**:
  - `canViewProfile(viewerID, targetID)`: プロフィール閲覧可否（プライバシーレベル、ブロック状態、認証状況）
  - `canViewDrops(viewerID, targetID)`: 投稿閲覧可否（非公開設定、フォロー関係、ミュート状態）
  - `canViewFollowers(viewerID, targetID)`: フォロワーリスト閲覧可否（設定、関係性、管理者権限）
  - `canViewFollowing(viewerID, targetID)`: フォロー中リスト閲覧可否（同上）
  - `shouldHideFromTimeline(viewerSettings, targetUser, content)`: タイムライン非表示判定（ミュート設定、キーワードフィルター）
  - `canSendDirectMessage(senderID, recipientID)`: DM送信可否（設定、フォロー関係、ブロック状態）
  - `filterUserList(viewerID, userList)`: ユーザーリストのプライバシーフィルター（一括可視性判定）
  - `applyContentFilter(viewerID, contentList)`: コンテンツフィルター適用（ミュート、ブロック、センシティブコンテンツ）

#### UserStatsDomainService
**責務**: ユーザー統計情報の管理と整合性保証
- **メソッド**:
  - `recalculateUserStats(userID)`: ユーザー統計の再計算（フォロー数、投稿数、いいね数の整合性確認）
  - `incrementFollowerCount(userID, delta)`: フォロワー数の増減（原子的操作、上限チェック）
  - `updateEngagementScore(userID, recentActivity)`: エンゲージメントスコア更新（投稿頻度、反応率、フォロワー増加率）
  - `detectStatisticsAnomaly(userID, stats)`: 統計異常検出（急激な変化、不自然なパターン、Bot疑い）
  - `generateUserInsights(userID, period)`: ユーザーインサイト生成（活動分析、成長傾向、推薦改善）
  - `consolidatePeriodicStats(userID, period)`: 定期統計の集約（日次、週次、月次の活動サマリー）

## ユースケース

### ユーザー登録

1.  ユーザーは登録フォームにユーザー名、メールアドレス、パスワードを入力
2.  フロントエンドは入力値の基本的な検証を実行（文字数、形式チェック）
3.  フロントエンドは `avion-gateway` 経由で `avion-auth` に登録リクエストを送信（認証JWT不要）
4.  avion-authで認証情報を作成後、`avion-user` にユーザー作成イベントを送信（Redis Stream）
5.  CreateUserCommandUseCase がイベントを処理
6.  UserDomainService でユーザー名の妥当性を検証（3-30文字、英数字とアンダースコアのみ）
7.  UserDomainService でメールアドレスの妥当性を検証（RFC 5322準拠）
8.  UserRepository でユーザー名とメールアドレスの一意性を確認（排他制御付き）
9.  UserFactory で User Aggregate を生成（初期プロフィール情報含む）
10. UserSettingsFactory でデフォルト設定を生成（プライバシー設定、通知設定等）
11. UserStatsFactory で初期統計を生成（フォロー数0、投稿数0等）
12. トランザクション内で以下を実行：
    - UserRepository でユーザー情報を永続化
    - UserSettingsRepository で設定を永続化
    - UserStatsRepository で統計を永続化
13. UserEventPublisher で `user_created` イベントを Redis Stream に発行
14. (非同期) EventHandler が以下のサービスにイベントを伝播：
    - avion-search: ユーザー検索インデックスへの追加
    - avion-activitypub: Actor情報の登録
15. CreateUserResponse DTO を返却（UserID、作成日時を含む）

(UIモック: 登録フォーム)

### プロフィール更新

1.  ユーザーはプロフィール編集画面で情報を更新（表示名、自己紹介、アバター、ヘッダー等）
2.  フロントエンドは入力値の基本検証を実行（文字数制限、画像形式等）
3.  メディアファイルがある場合、先に `avion-media` にアップロード
4.  フロントエンドは `avion-gateway` 経由で更新リクエストを送信（認証JWT必須）
5.  UpdateProfileCommandUseCase がリクエストを処理
6.  UserRepository から User Aggregate を取得（排他ロック付き）
7.  ProfileValidationService で入力値を詳細検証：
    - DisplayName: 最大30文字、絵文字対応
    - Bio: 最大500文字、改行対応
    - カスタムフィールド: 最大4つ、各項目名20文字・値200文字
8.  MediaService でアバター/ヘッダー画像のURLを検証（存在確認、アクセス権限）
9.  User.updateProfile() でプロフィール情報を更新
10. UserRepository で永続化（楽観的ロックでバージョン管理）
11. UserCacheService でキャッシュを更新（Redis）
12. UserEventPublisher で `profile_updated` イベントを Redis Stream に発行
13. (非同期) EventHandler が以下のサービスにイベントを伝播：
    - avion-search: ユーザー検索インデックスの更新
    - avion-activitypub: Actor情報の更新
    - avion-timeline: 関連するタイムラインのキャッシュ無効化
14. UpdateProfileResponse DTO を返却（更新されたプロフィール情報を含む）

(UIモック: プロフィール編集画面)

### フォロー処理

1.  ユーザーは他のユーザーのプロフィールで「フォロー」ボタンをクリック
2.  フロントエンドは楽観的更新でUIを即座に反映（フォロー中状態に変更）
3.  フロントエンドは `avion-gateway` 経由でフォローリクエストを送信（認証JWT必須）
4.  FollowUserCommandUseCase がリクエストを処理
5.  FollowDomainService.canFollow() でフォロー可能かを確認：
    - 自分自身をフォローしていないか
    - 既にフォローしていないか
    - 削除されたユーザーではないか
6.  BlockRepository でブロック関係をチェック（相互ブロック確認）
7.  UserSettingsRepository から対象ユーザーの設定を取得（承認制かどうか）
8.  FollowFactory で Follow Aggregate を生成
9.  承認制アカウントの場合：
    - FollowRequestFactory で FollowRequest Entity を生成
    - Status を 'pending' に設定
10. 非承認制アカウントの場合：
    - Status を 'approved' に設定
11. トランザクション内で以下を実行：
    - FollowRepository で Follow を永続化
    - UserStatsService でフォロー数・フォロワー数を更新（カウンター増加）
12. FollowEventPublisher で `follow_created` イベントを Redis Stream に発行
13. (非同期) EventHandler が以下のサービスにイベントを伝播：
    - avion-notification: フォロー通知の送信（承認制の場合はリクエスト通知）
    - avion-timeline: フォロワーのタイムラインキャッシュ更新
    - avion-activitypub: Follow アクティビティ送信
14. FollowResponse DTO を返却（フォロー状態、承認待ちフラグを含む）

(UIモック: フォローボタン)

### ユーザーブロック

1.  ユーザーは他のユーザーのメニューから「ブロック」を選択
2.  確認ダイアログで「ブロックしますか？フォロー関係も解除されます」と表示
3.  「ブロックする」ボタンをクリック
4.  フロントエンドは `avion-gateway` 経由でブロックリクエストを送信（認証JWT必須）
5.  BlockUserCommandUseCase がリクエストを処理
6.  Block Aggregate の不変条件を確認（自分自身をブロックしていないか）
7.  既存ブロック関係の重複チェック（冪等性のため200で返却）
8.  BlockFactory で Block Aggregate を生成
9.  トランザクション内で以下を実行：
    - BlockRepository で Block を永続化
    - FollowCleanupService で双方向のフォロー関係を解除
    - FollowRepository から関連する Follow レコードを削除
    - UserStatsService でフォロー数・フォロワー数を調整
10. UserListCleanupService でリストから対象ユーザーを除外：
    - 自分のリストから対象ユーザーを削除
    - 対象ユーザーのリストから自分を削除
11. BlockEventPublisher で `block_created` イベントを Redis Stream に発行
12. BlockCacheService でキャッシュを更新（Redis、ブロック関係の高速参照用）
13. (非同期) EventHandler が以下のサービスにイベントを伝播：
    - avion-timeline: タイムラインから対象ユーザーの投稿を除外
    - avion-activitypub: Block アクティビティ送信（プライベート）
    - avion-notification: 関連する通知の無効化
14. BlockResponse DTO を返却（ブロック完了を通知）

(UIモック: ブロック確認ダイアログ)

### ミュート設定

1.  ユーザーはミュート設定画面を開く
2.  「ユーザーミュート」または「キーワードミュート」タブを選択
3.  ユーザーミュートの場合：対象ユーザーを検索・選択、期限設定（オプション）
4.  キーワードミュートの場合：キーワード入力、正規表現フラグ設定、期限設定（オプション）
5.  「ミュートを追加」ボタンをクリック
6.  フロントエンドは `avion-gateway` 経由でミュート設定リクエストを送信（認証JWT必須）
7.  CreateMuteCommandUseCase がリクエストを処理
8.  MuteValidationService で設定を検証：
    - ユーザーミュート: 対象ユーザーの存在確認、自分自身でないことを確認
    - キーワードミュート: キーワード長（最大100文字）、正規表現の妥当性
    - 期限: 未来の日時であることを確認（最大1年先まで）
9.  Mute Aggregate の制約を確認（ユーザーごとに最大1000件のミュート）
10. 既存ミュート設定の重複チェック（冪等性のため200で返却）
11. MuteFactory で Mute Aggregate を生成：
    - ユーザーミュートまたはキーワードミュート種別
    - 期限付きの場合は ExpiresAt を設定
    - リポストミュートなどの詳細設定
12. MuteRepository で永続化
13. MuteCacheService でキャッシュを更新（Redis、高速フィルタリング用）
14. MuteEventPublisher で `mute_created` イベントを Redis Stream に発行
15. (非同期) EventHandler が以下のサービスにイベントを伝播：
    - avion-timeline: ミュート設定の反映（キャッシュ更新）
16. CreateMuteResponse DTO を返却（設定されたミュート情報を含む）

(UIモック: ミュート設定画面)

### ユーザー検索

1.  ユーザーは検索ボックスにキーワードを入力（リアルタイム検索対応）
2.  フロントエンドは入力後300ms後に検索を実行（デバウンス処理）
3.  フロントエンドは `avion-gateway` 経由で検索リクエストを送信（認証JWT任意）
4.  SearchUsersQueryUseCase がリクエストを処理
5.  SearchCacheService で検索結果キャッシュを確認（キーワード単位でキャッシュ）
6.  キャッシュミスの場合、UserSearchService で検索を実行：
    - ユーザー名（@username）での完全一致検索
    - 表示名での部分一致検索（大文字小文字を区別しない）
    - プロフィール全文検索（avion-searchサービスと連携）
7.  検索結果の前処理：
    - 削除済みユーザーを除外
    - 凍結済みユーザーを除外（管理者は除く）
8.  BlockFilterService で相互ブロック関係をフィルタ（認証ユーザーのみ）
9.  PrivacyFilterService で非公開アカウントをフィルタ：
    - 公開アカウント: 全員に表示
    - 非公開アカウント: フォロワーのみに表示
10. SearchResultEnrichmentService でプロフィール情報を補完：
    - アバター画像URL、表示名、自己紹介の取得
    - フォロー・フォロワー数の取得
11. FollowStatusBatchService で各ユーザーとのフォロー状態を取得（認証ユーザーのみ）
12. 関連度スコアによるソート（ユーザー名完全一致 > 表示名前方一致 > 部分一致）
13. 上位20件に制限してページネーション対応
14. UserSearchResultDTO を生成（各ユーザーの基本情報、フォロー状態を含む）
15. SearchCacheService でキャッシュを保存（TTL: 5分）
16. フロントエンドは検索結果をリスト表示（無限スクロール対応）

(UIモック: ユーザー検索結果)

### ユーザーリスト作成

1.  ユーザーはリスト管理画面で「新規リスト作成」ボタンをクリック
2.  リスト作成フォームが表示される
3.  リスト名（最大50文字）、説明（最大200文字、任意）、公開設定を入力
4.  公開設定の選択肢：
    - 公開：誰でも閲覧可能
    - 非公開：所有者のみ閲覧可能
5.  「リストを作成」ボタンをクリック
6.  フロントエンドは入力値の基本検証を実行（必須フィールド、文字数制限）
7.  フロントエンドは `avion-gateway` 経由でリスト作成リクエストを送信（認証JWT必須）
8.  CreateUserListCommandUseCase がリクエストを処理
9.  UserListLimitChecker で作成制限を確認（ユーザーごとに最大50リスト）
10. UserListValidationService でリスト名を検証：
    - 同一ユーザー内でのリスト名重複チェック
    - 禁止ワードチェック
    - 特殊文字の制限
11. UserListFactory で UserList Aggregate を生成（空のメンバーリストで初期化）
12. UserListRepository で永続化
13. UserListEventPublisher で `list_created` イベントを Redis Stream に発行
14. CreateUserListResponse DTO を返却（ListID、作成日時、初期設定を含む）
15. フロントエンドは作成完了を表示し、リスト管理画面に遷移

(UIモック: リスト作成フォーム)

### リストメンバー追加

1.  ユーザーはリスト詳細画面で「メンバーを追加」ボタンをクリック
2.  ユーザー検索ダイアログが表示される
3.  ユーザーは検索ボックスで追加したいユーザーを検索・選択
4.  「リストに追加」ボタンをクリック
5.  フロントエンドは楽観的更新でUIを即座に反映（メンバーカウント増加）
6.  フロントエンドは `avion-gateway` 経由でメンバー追加リクエストを送信（認証JWT必須）
7.  AddListMemberCommandUseCase がリクエストを処理
8.  UserListRepository から UserList Aggregate を取得（排他ロック付き）
9.  UserList.canAddMember() で追加権限を確認：
    - リスト所有者であること
    - 対象ユーザーが既にメンバーでないこと
    - 対象ユーザーが削除済みでないこと
10. BlockRepository でブロック関係を確認（相互ブロックのユーザーは追加不可）
11. ListMemberLimitChecker で上限チェック（リストごとに最大5000メンバー）
12. ListMemberFactory で ListMember Entity を生成（追加日時、追加者を記録）
13. UserList.addMember() でメンバーを追加（重複チェック含む）
14. UserListRepository で永続化（リストメタデータとメンバー情報を同時更新）
15. UserListEventPublisher で `list_member_added` イベントを Redis Stream に発行
16. (非同期) EventHandler が以下のサービスにイベントを伝播：
    - avion-timeline: リストタイムラインのキャッシュ更新
17. AddListMemberResponse DTO を返却（更新されたメンバー数を含む）

(UIモック: リストメンバー管理画面)

### フォロワーリスト表示

1.  ユーザーはプロフィールページでフォロワータブを選択（フォロワー数が表示されている）
2.  フロントエンドは `avion-gateway` 経由でフォロワーリスト取得リクエストを送信（認証JWT任意）
3.  GetFollowersQueryUseCase がリクエストを処理
4.  PaginationValidator で limit（最大50）と cursor の妥当性を検証
5.  FollowerCacheService でキャッシュを確認（ユーザー単位でキャッシュ）
6.  PrivacyDomainService.canViewFollowers() で閲覧権限を確認：
    - 自分のフォロワー: 常に閲覧可能
    - 他人のフォロワー: プライバシー設定に依存
    - 非公開アカウント: フォロワーのみ閲覧可能
7.  FollowQueryService でフォロワーリストを取得（CreatedAt降順、カーソルベース）
8.  UserBatchQueryService で各フォロワーのプロフィール情報を一括取得：
    - アバター、表示名、自己紹介、フォロー・フォロワー数
9.  BlockFilterService で相互ブロック関係をフィルタ（認証ユーザーのみ）
10. 閲覧可能なフォロワーのみをフィルタリング
11. FollowStatusBatchService で閲覧者と各フォロワーとの関係を取得（認証ユーザーのみ）
12. FollowerListDTO を生成（各フォロワーのDTO配列、次ページカーソルを含む）
13. FollowerCacheService でキャッシュを保存（TTL: 1分）
14. フロントエンドは無限スクロールでフォロワーリストを表示
15. 各フォロワーにフォローボタンやメニューを表示（関係性に応じて）

(UIモック: フォロワーリスト)

### 設定更新

1.  ユーザーは設定画面で各種設定を変更（プライバシー、通知、UI、アクセシビリティ等）
2.  設定項目によってセクションが分かれ、それぞれの設定を変更
3.  「変更を保存」ボタンをクリック（リアルタイム保存またはバッチ保存）
4.  フロントエンドは入力値の基本検証を実行（必須項目、形式チェック）
5.  フロントエンドは `avion-gateway` 経由で設定更新リクエストを送信（認証JWT必須）
6.  UpdateSettingsCommandUseCase がリクエストを処理
7.  UserSettingsRepository から UserSettings Aggregate を取得（排他ロック付き）
8.  SettingsValidationService で設定値を詳細検証：
    - 言語コード: ISO 639-1準拠
    - タイムゾーン: IANA Time Zone Database準拠
    - メールアドレス: 通知用メールアドレスの妥当性確認
    - DM受信設定: 列挙値のチェック
9.  設定種別に応じて適切な更新メソッドを呼び出し：
    - UserSettings.updatePrivacySettings(): プライバシー設定
    - UserSettings.updateNotificationSettings(): 通知設定
    - UserSettings.updateUISettings(): UI設定
    - UserSettings.updateAccessibilitySettings(): アクセシビリティ設定
10. UserSettingsRepository で永続化（楽観的ロックでバージョン管理）
11. SettingsCacheService でキャッシュを更新（Redis、高速アクセス用）
12. SettingsEventPublisher で `settings_updated` イベントを Redis Stream に発行
13. (非同期) EventHandler が以下のサービスにイベントを伝播：
    - avion-timeline: プライバシー設定変更の反映
    - avion-notification: 通知設定変更の反映
    - avion-activitypub: Actor情報の更新
14. UpdateSettingsResponse DTO を返却（更新された設定情報を含む）
15. フロントエンドは「設定を保存しました」と表示

(UIモック: 設定画面)

### アカウント凍結（管理者機能）

1.  管理者は管理画面でユーザーを選択し「凍結」を実行
2.  フロントエンドは `avion-gateway` 経由で凍結リクエストを送信
3.  SuspendUserCommandUseCase がリクエストを処理
4.  AdminAuthorizationService で管理者権限を確認
5.  UserRepository から User Aggregate を取得
6.  User.suspend() で凍結処理
7.  SuspensionReason を記録
8.  UserRepository で永続化
9.  SessionInvalidationService でセッションを無効化
10. SuspensionEventPublisher で `user_suspended` イベントを発行
11. (非同期) avion-notification で凍結通知を送信
12. SuspendUserResponse DTO を返却

(UIモック: 管理者画面)

### データエクスポート（GDPR対応）

**事前条件:**
- ユーザーがログイン済み
- 前回のエクスポートから24時間経過
- システムがメンテナンスモードでない

**正常フロー:**
1.  ユーザーは設定画面で「データエクスポート」を選択
2.  エクスポート対象（フォロー、ブロック、投稿、設定等）を選択
3.  エクスポート形式（JSON、CSV、ActivityPub形式）を選択
4.  フロントエンドは `avion-gateway` 経由でエクスポートリクエストを送信
5.  ExportDataCommandUseCase がリクエストを処理
6.  RateLimitService で24時間制限を確認
7.  ExportQueueService でエクスポートジョブをキューに追加
8.  (非同期) ExportWorker がジョブを処理
9.  各リポジトリから対象データを取得
10. GDPRComplianceService で個人情報の処理
11. ExportFormatter で指定形式に変換（JSON/CSV/ActivityPub）
12. 暗号化してavion-media に一時ファイルとして保存
13. 署名付きダウンロードURLを生成（48時間有効）
14. DataExportEventPublisher で `DataExportRequestedEvent` 発行
15. avion-notification でダウンロード準備完了を通知
16. ExportDataResponse DTO を返却

**エラーケース:**
- E1: レート制限違反 → RateLimitException（429）
- E2: ストレージ容量不足 → StorageException（507）
- E3: データ収集失敗 → DataCollectionException（500）

**事後条件:**
- エクスポートタスクが記録されている
- 監査ログに記録されている
- 48時間後に自動削除される

(UIモック: データエクスポート画面)

### アカウント削除（GDPR対応）

**事前条件:**
- ユーザーがログイン済み
- 過去30日以内に作成されたアカウントでない
- 管理者権限を持っていない

**正常フロー:**
1.  ユーザーは設定画面で「アカウントを削除」を選択
2.  削除理由の選択（任意）とフィードバック入力
3.  重要な警告メッセージを表示（復元不可、データ削除）
4.  パスワード再入力による本人確認
5.  「アカウントを完全に削除」ボタンをクリック
6.  DeleteAccountCommandUseCase がリクエストを処理
7.  AuthenticationService でパスワード検証
8.  UserRepository から User Aggregate を取得
9.  User.canBeDeleted() で削除可能性を確認
10. 30日間の猶予期間を設定（soft delete）
11. User.deactivate() でアカウントを非活性化
12. DeletionScheduleService で30日後の完全削除をスケジュール
13. UserEventPublisher で `UserDeactivatedEvent` 発行
14. 関連サービスへのカスケード処理：
    - avion-drop: 投稿の非表示化
    - avion-timeline: タイムラインからの除外
    - avion-notification: 通知の停止
15. DeleteAccountResponse DTO を返却

**代替フロー（削除取り消し）:**
1. 30日以内にユーザーがログイン試行
2. 「アカウント削除をキャンセル」オプション表示
3. キャンセルを選択
4. User.reactivate() でアカウント復活
5. UserEventPublisher で `UserReactivatedEvent` 発行

**事後条件:**
- アカウントが非活性化されている
- 30日後の完全削除がスケジュールされている
- GDPRコンプライアンスログが記録されている

(UIモック: アカウント削除確認画面)

### 二要素認証設定

**事前条件:**
- ユーザーがログイン済み
- MFA未設定または追加設定可能

**正常フロー:**
1.  ユーザーは設定画面で「二要素認証」を選択
2.  認証方法を選択（TOTP、SMS、ハードウェアキー）
3.  SetupMFACommandUseCase がリクエストを処理
4.  avion-auth と連携してMFA設定を開始
5.  TOTP選択時：
    - QRコード生成
    - 認証アプリでスキャン
    - 6桁コードで検証
6.  SMS選択時：
    - 電話番号入力
    - 検証コード送信
    - コード入力で検証
7.  リカバリーコード生成（8個）
8.  UserSettings.enableMFA() で設定有効化
9.  MFAEventPublisher で設定変更イベント発行
10. SetupMFAResponse DTO を返却（リカバリーコード含む）

**エラーケース:**
- E1: 無効な認証コード → InvalidCodeException（400）
- E2: 電話番号検証失敗 → PhoneVerificationException（400）
- E3: MFA上限到達 → MFALimitException（400）

**事後条件:**
- MFAが有効化されている
- リカバリーコードが生成されている
- セキュリティログが記録されている

(UIモック: 二要素認証設定画面)

### プライバシー設定変更

**事前条件:**
- ユーザーがログイン済み
- 変更権限がある

**正常フロー:**
1.  ユーザーは設定画面で「プライバシー」を選択
2.  各種プライバシー設定を変更：
    - アカウント公開/非公開
    - フォロー承認制の有効/無効
    - DM受信設定（全員/フォロー中/無効）
    - 検索エンジンインデックス許可
    - データ分析オプトアウト
3.  UpdatePrivacyCommandUseCase がリクエストを処理
4.  UserSettings Aggregate を取得
5.  PrivacyValidationService で設定の整合性確認
6.  UserSettings.updatePrivacySettings() で更新
7.  PrivacyCacheService でキャッシュ更新
8.  PrivacyEventPublisher で `PrivacySettingsChangedEvent` 発行
9.  関連サービスへの伝播：
    - avion-search: インデックス設定更新
    - avion-timeline: 公開範囲反映
    - avion-activitypub: Actor情報更新
10. UpdatePrivacyResponse DTO を返却

**エラーケース:**
- E1: 矛盾する設定 → ValidationException（400）
- E2: 保護されたアカウント → ProtectedAccountException（403）

**事後条件:**
- プライバシー設定が更新されている
- 関連サービスに変更が伝播されている
- 監査ログが記録されている

(UIモック: プライバシー設定画面)

## 機能要求

### ドメインロジック要求

*   **User管理:**
    *   ユーザーを集約として管理し、ライフサイクル全体の整合性を保つ
    *   ユーザー名とメールアドレスの一意性保証
    *   プロフィール情報のバリデーション
    *   アカウント状態の遷移管理

*   **Follow管理:**
    *   フォロー関係の一貫性保証
    *   承認制アカウントのリクエスト管理
    *   相互フォロー状態の自動計算
    *   ブロック時の自動フォロー解除

*   **Privacy管理:**
    *   ミュート、ブロックの効果的な適用
    *   プライバシー設定に基づくアクセス制御
    *   キーワードミュートの高速マッチング

### APIエンドポイント要求

*   **User API:**
    *   ユーザーのCRUD操作のためのgRPC APIを提供
    *   認証が必要なエンドポイントはメタデータでユーザーIDを受け取る
    *   バッチ取得API（複数ユーザーの情報を一度に取得）

*   **Follow API:**
    *   フォロー関係の作成、削除、一覧取得のためのgRPC APIを提供
    *   フォローリクエストの承認/拒否API
    *   相互フォロー状態の確認API

*   **Settings API:**
    *   ユーザー設定の取得、更新のためのgRPC APIを提供
    *   設定のインポート/エクスポートAPI

### データ要求

*   **ユーザー名:** 3-30文字、英数字とアンダースコアのみ、大文字小文字を区別しない一意性
*   **メールアドレス:** RFC 5322準拠、アクティブユーザー内で一意
*   **プロフィール:** 表示名30文字、自己紹介500文字、カスタムフィールド4つまで
*   **フォロー関係:** 双方向の関係を効率的に検索可能
*   **ミュート設定:** ユーザーごとに最大1000件のミュート、キーワード100個まで
*   **リスト:** ユーザーごとに最大50リスト、1リスト最大5000メンバー

## セキュリティ実装ガイドライン

avion-userサービスは、プロフィール情報やユーザー設定など多くの個人識別情報（PII）を扱うため、以下のセキュリティガイドラインに従って実装します：

### 必須実装項目

1. **XSS防止** ([XSS防止ガイドライン](../common/security/xss-prevention.md))
   - プロフィールの表示名、自己紹介文、カスタムフィールドのサニタイゼーション
   - HTMLタグの完全除去またはエスケープ処理
   - コンテキストを考慮した出力エンコーディング（HTML、JSON、JavaScriptコンテキスト）
   - CSPヘッダーの適切な設定

2. **CSRF保護** ([CSRF保護ガイドライン](../common/security/csrf-protection.md))
   - プロフィール更新、フォロー/アンフォロー操作でのCSRFトークン検証
   - SameSite Cookie属性の設定
   - ダブルサブミットCookieパターンの実装
   - Origin/Refererヘッダーの検証

3. **SQLインジェクション防止** ([SQLインジェクション防止](../common/security/sql-injection-prevention.md))
   - 全てのデータベースクエリでプリペアドステートメントを使用
   - ユーザー名、メールアドレス検索でのパラメータ化クエリ
   - ORMレイヤーでの自動エスケープ機能の活用
   - 動的クエリ生成の回避

4. **個人情報の暗号化** ([暗号化ガイドライン](../common/security/encryption-guidelines.md))
   - メールアドレス、電話番号の保存時暗号化（AES-256-GCM）
   - プロフィール情報の選択的暗号化（センシティブデータ）
   - 暗号化キーの安全な管理（AWS KMS/HashiCorp Vault）
   - 削除済みユーザーデータの完全な暗号化消去

### 実装時の注意事項

- **入力検証**: プロフィール更新時の全フィールドで厳格な入力検証
- **出力エンコーディング**: ユーザー生成コンテンツの表示時に必ず適切なエスケープ
- **認証状態の確認**: 全ての変更操作でJWT検証とユーザー権限確認
- **監査ログ**: プロフィール変更、プライバシー設定変更の全履歴を記録
- **レート制限**: フォロー操作、プロフィール更新の頻度制限
- **セッション管理**: 重要な変更操作での再認証要求

## 技術的要求

### レイテンシ

*   **ユーザー情報取得**: 平均 50ms 以下, p99 200ms 以下（キャッシュヒット率95%以上）
*   **フォロー/アンフォロー**: 平均 100ms 以下, p99 300ms 以下（DB書き込み + イベント発行含む）
*   **ユーザー検索**: 平均 200ms 以下, p99 500ms 以下（10,000件/秒の検索処理能力）
*   **フォロワーリスト取得**: 平均 150ms 以下, p99 400ms 以下（ページネーション50件単位）
*   **設定更新**: 平均 100ms 以下, p99 250ms 以下（楽観的ロック競合対応）
*   **プロフィール更新**: 平均 200ms 以下, p99 600ms 以下（画像URL検証含む）
*   **バッチユーザー情報取得**: 最大100ユーザーを300ms 以下で処理
*   **フォロー関係チェック**: 平均 10ms 以下（キャッシュベース高速判定）

### 可用性

*   **稼働率**: 99.9%（月間ダウンタイム43.2分以内）
*   **Kubernetes構成**: 最小3レプリカによる冗長構成、異なるノードへの分散配置
*   **ヘルスチェック**: Readiness/Liveness Probeによる自動復旧（チェック間隔10秒）
*   **グレースフルシャットダウン**: 30秒以内での安全な停止処理
*   **サーキットブレーカー**: 依存サービス障害時の自動遮断（閾値：エラー率50%超過）
*   **フェイルオーバー**: 主要依存サービス障害時もRead-only modeで基本機能継続
*   **災害復旧**: RTO 15分、RPO 5分以内でのサービス復旧

### スケーラビリティ

*   **処理能力**: 10,000リクエスト/秒の処理（ピーク時20,000リクエスト/秒まで対応）
*   **ユーザー規模**: 100万ユーザーまでのスケーラブル対応
*   **フォロー関係**: 10億件のフォロー関係を効率的に管理（グラフDB活用）
*   **水平スケーリング**: CPU使用率70%超過時の自動スケールアウト（最大20レプリカ）
*   **データベース**: リードレプリカによる読み取り負荷分散（最大5台）
*   **キャッシュ戦略**: Redis Clusterによる分散キャッシュ（16GB×3ノード）
*   **インデックス設計**: フォロー関係の複合インデックス（follower_id, followee_id, created_at）
*   **パーティショニング**: ユーザーIDベースの水平分割（将来的な実装予定）

### セキュリティ

*   **アクセス制御**:
     - JWTベースの認証（RSA256署名、1時間有効期限）
     - スコープベースの認可（read, write, admin権限）
     - プライバシー設定に基づく動的アクセス制御
*   **入力検証**:
     - SQLインジェクション対策（PreparedStatement使用）
     - XSS対策（HTMLサニタイゼーション、CSP headers）
     - CSRF保護（SameSite Cookie、CSRF token）
*   **データ保護**:
     - 個人情報の暗号化保存（AES-256-GCM）
     - PII（個人識別情報）の適切なマスキング
     - メールアドレス等の機密情報のログ出力禁止
*   **監査ログ**:
     - 全ての重要操作の監査ログ記録（改竄検知機能付き）
     - セキュリティイベントの自動検知とアラート
*   **削除処理**:
     - 論理削除されたユーザー情報の完全な非表示化
     - 90日後の物理削除による完全データ消去
*   **レート制限**:
     - ユーザー単位：100req/min、IP単位：1000req/min
     - フォロー操作：10回/min（スパム防止）

### データ整合性

*   **ACID準拠**: PostgreSQLトランザクションによる強整合性保証
*   **楽観的ロック**: バージョン番号による同時更新競合回避
*   **統計整合性**: フォロー数カウンターの定期的な再計算（毎時実行）
*   **関係整合性**: 外部キー制約による参照整合性保証
*   **イベント順序**: Redis Streamによる順序保証されたイベント配信
*   **補償トランザクション**: 分散処理失敗時の自動ロールバック
*   **データ検証**: 定期的なデータ整合性チェック（日次実行）
*   **ブロック処理**: ブロック時のフォロー関係自動解除（原子的操作）

### その他技術要件

*   **ステートレス設計**: 
     - サービスインスタンスに状態を持たない完全ステートレス
     - セッション状態はRedisで外部管理
     - 任意のインスタンスでリクエスト処理可能
*   **Observability**: 
     - OpenTelemetry SDKによる分散トレーシング
     - Prometheusメトリクス（応答時間、エラー率、リソース使用量）
     - 構造化ログ出力（JSON形式、ログレベル適切設定）
     - カスタムメトリクス（DAU、フォロー作成率、検索成功率）
*   **キャッシュ戦略**: 
     - L1キャッシュ：アプリケーション内メモリ（1分TTL）
     - L2キャッシュ：Redis（5分TTL、LRU eviction）
     - キャッシュウォーミング：定期的な人気ユーザー情報プリロード
     - キャッシュ無効化：Write-through パターンによる即座反映
*   **構成管理**:
     - Kubernetes ConfigMapによる環境別設定管理
     - 秘匿情報はKubernetes Secretで管理
     - 設定変更の Hot-reload 対応
*   **テスト要件**:
     - 単体テストカバレッジ85%以上
     - 結合テストによる主要ユースケース検証
     - パフォーマンステスト（負荷テスト、ストレステスト）
     - カオスエンジニアリングによる障害耐性検証
     
     テスト実装については[共通テスト戦略](../common/testing-strategy.md)を参照。
*   **デプロイ要件**:
     - Blue-Green デプロイによる無停止デプロイ
     - カナリアリリース対応（段階的ロールアウト）
     - 自動ロールバック機能（ヘルスチェック失敗時）

## イベント駆動アーキテクチャ

### 発行イベント定義

#### ユーザー関連イベント
- **UserCreatedEvent**: 新規ユーザー登録時
  - ペイロード: userID, username, email, createdAt
  - 購読サービス: avion-notification, avion-timeline, avion-activitypub
  
- **UserUpdatedEvent**: プロフィール更新時
  - ペイロード: userID, changedFields[], updatedAt
  - 購読サービス: avion-search, avion-timeline, avion-activitypub

- **UserDeactivatedEvent**: アカウント非活性化時
  - ペイロード: userID, reason, deactivatedAt, scheduledDeletionAt
  - 購読サービス: avion-drop, avion-timeline, avion-notification, avion-activitypub

- **UserReactivatedEvent**: アカウント再活性化時
  - ペイロード: userID, reactivatedAt
  - 購読サービス: avion-drop, avion-timeline, avion-notification

- **UserDeletedEvent**: アカウント完全削除時
  - ペイロード: userID, deletedAt, isGDPRDeletion
  - 購読サービス: 全サービス（カスケード削除）

#### フォロー関連イベント
- **FollowCreatedEvent**: フォロー関係確立時
  - ペイロード: followerID, followeeID, createdAt, isPending
  - 購読サービス: avion-notification, avion-timeline, avion-activitypub

- **FollowRemovedEvent**: フォロー解除時
  - ペイロード: followerID, followeeID, removedAt
  - 購読サービス: avion-timeline, avion-activitypub

#### プライバシー関連イベント
- **PrivacySettingsChangedEvent**: プライバシー設定変更時
  - ペイロード: userID, changedSettings{}, oldValues{}, newValues{}
  - 購読サービス: avion-search, avion-timeline, avion-activitypub

- **BlockCreatedEvent**: ブロック設定時
  - ペイロード: blockerID, blockedID, createdAt
  - 購読サービス: avion-timeline, avion-notification, avion-activitypub

- **MuteCreatedEvent**: ミュート設定時
  - ペイロード: muterID, mutedID, duration, createdAt
  - 購読サービス: avion-timeline

#### データ管理イベント
- **DataExportRequestedEvent**: データエクスポート要求時
  - ペイロード: userID, exportID, format, requestedAt
  - 購読サービス: avion-notification

- **DataExportCompletedEvent**: データエクスポート完了時
  - ペイロード: userID, exportID, downloadURL, expiresAt
  - 購読サービス: avion-notification

#### 設定関連イベント
- **MFAEnabledEvent**: 二要素認証有効化時
  - ペイロード: userID, mfaType, enabledAt
  - 購読サービス: avion-auth, avion-notification

- **MFADisabledEvent**: 二要素認証無効化時
  - ペイロード: userID, disabledAt
  - 購読サービス: avion-auth, avion-notification

### イベント配信保証

- **配信方式**: Redis Streams使用
- **順序保証**: ユーザーIDベースのパーティショニング
- **重複排除**: イベントIDによる冪等性保証
- **リトライ**: 指数バックオフ（最大3回）
- **Dead Letter Queue**: 失敗イベントの隔離と手動処理

## 決まっていないこと

*   **ユーザー名変更機能**: 実装有無、変更頻度制限（年1回など）、履歴管理の方法
*   **アカウント削除ポリシー**: 即座の完全削除 vs 30日間の猶予期間付きソフトデリート（現在は30日猶予を採用）
*   **統計情報の可視性**: 非公開アカウントでのフォロー/フォロワー数表示制御
*   **リモートユーザー管理**: ActivityPub他インスタンスユーザーの情報同期頻度とキャッシュ戦略
*   **認証バッジシステム**: 付与基準（本人確認レベル）、管理者承認フロー、取り消し条件
*   **アカウント移行機能**: データ移行範囲、移行期間中の動作、旧アカウントの扱い
*   **スパム対策**: 自動検出アルゴリズム、機械学習モデルの導入、誤検出時の復旧プロセス
*   **推薦システム**: フォロー推薦アルゴリズム（協調フィルタリング vs 深層学習）、プライバシー配慮
*   **プロフィール検証**: ウェブサイト所有権確認の自動化レベル、検証済みマークの表示方法
*   **多要素認証連携**: avion-authとの連携方式、TOTP/SMS/ハードウェアキーサポート範囲
*   **国際化対応**: 右から左に読む言語（RTL）のUI対応、地域固有のプライバシー法規制
*   **アクセシビリティ**: スクリーンリーダー最適化レベル、キーボードナビゲーション対応範囲
*   **データエクスポート形式**: JSON/CSV以外の形式（ActivityPub標準形式など）対応
*   **企業アカウント**: 個人アカウントとの差別化機能、組織管理者システム
*   **API versioning**: gRPC APIのバージョン管理戦略、後方互換性維持期間