# PRD: avion-community

## 概要

Avionにおけるコミュニティ機能として、グループ作成・管理、トピックベースのディスカッション、コミュニティモデレーション、メンバー管理、共同作業スペースなどの機能を提供するマイクロサービスを実装する。

## 背景

現代のSNSプラットフォームでは、単一のタイムラインだけでなく、興味関心や目的に基づいた小さなコミュニティでの交流が重要となっている。Discordのサーバー機能やRedditのsubreddit、TwitterのCommunity機能のように、特定のテーマや興味に基づいてユーザーが集まり、より深いディスカッションや交流を行える場所が求められる。

avion-communityは、ユーザーが共通の興味や目的を持つ小さなグループを作成し、トピック別に整理された議論を行い、コミュニティ固有のルールやモデレーション機能を持つことで、より価値のあるソーシャル体験を提供する。

## Scientific Merits

### パフォーマンス指標
*   **コミュニティ作成時間:** < 500ms（画像アップロード含む）
*   **メンバー参加処理:** < 200ms（権限設定、通知送信含む）
*   **コミュニティ検索:** p50 < 100ms, p99 < 300ms
*   **権限チェック:** < 30ms（キャッシュヒット率 > 95%）
*   **トピック投稿:** < 150ms（リアルタイム配信含む）

### エンゲージメント指標
*   **エンゲージメント率向上:** 25%向上（コミュニティ機能導入後3ヶ月）
*   **アクティブコミュニティ率:** 60%以上（月間1投稿以上）
*   **平均メンバー数:** 150人/コミュニティ
*   **メンバー定着率:** 70%以上（参加後30日間）
*   **日次アクティブ率:** 40%以上（コミュニティメンバーの日次訪問率）

### スケーラビリティ指標
*   **最大コミュニティ数:** 100,000コミュニティ
*   **最大メンバー数/コミュニティ:** 100,000人
*   **同時アクティブコミュニティ:** 10,000コミュニティ
*   **同時接続数:** 50,000ユーザー/コミュニティ機能
*   **トピック作成スループット:** 1,000 topics/秒

### ビジネス価値
*   **ユーザー滞在時間:** 35%増加（コミュニティ参加ユーザー）
*   **投稿数増加:** 50%増加（コミュニティ内投稿）
*   **新規ユーザー獲得:** 20%増加（コミュニティ招待経由）
*   **チャーン率削減:** 30%削減（コミュニティ参加ユーザー）
*   **モデレーションコスト:** 40%削減（自治機能による）

### 品質指標
*   **コンテンツ品質スコア:** 平均4.0/5.0以上
*   **モデレーション応答時間:** < 1時間（重要度高）
*   **スパム検出率:** 95%以上
*   **誤検知率:** < 1%
*   **ユーザー満足度:** NPS 40以上

コミュニティ機能はユーザーの帰属意識と継続利用を高める重要な要素であり、プラットフォームの差別化と競争力向上に貢献する。

## Design Doc

[Design Doc: avion-community](./designdoc.md)

## 参考ドキュメント

*   [Avion アーキテクチャ概要](./../common/architecture.md)

## 製品原則

*   **オープンな参加:** 誰でも新しいコミュニティを作成し、興味のあるコミュニティに参加できること。
*   **自治と自由度:** 各コミュニティが独自のルール、文化、モデレーション方針を持てること。
*   **透明性:** コミュニティのルール、モデレーションポリシー、メンバー構成が透明であること。
*   **発見可能性:** 興味関心に基づいてコミュニティを発見しやすい仕組みがあること。
*   **品質重視:** 建設的で価値のある議論を促進する機能とUIを提供すること。
*   **プライバシー尊重:** プライベートコミュニティでの議論内容が適切に保護されること。

## やること/やらないこと

### やること

*   **コミュニティ管理:**
    - 新しいコミュニティの作成 (名前、説明、公開設定、カテゴリ)
    - コミュニティ情報の編集・更新
    - コミュニティアバター・ヘッダー画像の設定
    - コミュニティの削除・アーカイブ
    - コミュニティ検索・発見機能
    - 人気/推奨コミュニティの表示
    - コミュニティの統計情報（メンバー数、アクティビティ）

*   **メンバーシップ管理:**
    - コミュニティへの参加申請・承認システム
    - メンバーの役割管理（オーナー、モデレーター、一般メンバー）
    - メンバーの招待機能（招待リンク、個別招待）
    - メンバーの退会・除名処理
    - メンバー一覧の表示・検索
    - 参加履歴の管理

*   **権限・役割システム:**
    - 役割別権限の設定（投稿、モデレーション、設定変更など）
    - カスタム役割の作成・編集
    - 権限の階層構造（オーナー > モデレーター > メンバー）
    - 一時的な権限付与（期間限定モデレーター等）
    - 権限変更の監査ログ

*   **トピック・チャンネル管理:**
    - コミュニティ内トピック（チャンネル）の作成・編集・削除
    - トピック別権限設定（読み取り専用、特定役割限定等）
    - トピックのカテゴリ分類・並び替え
    - トピックの説明・ピン留め投稿
    - アーカイブされたトピックの管理

*   **コミュニティルール・ガイドライン:**
    - コミュニティルールの設定・編集
    - 参加時のルール確認・同意機能
    - ルール違反報告システム
    - 自動モデレーション設定（キーワードフィルタ等）
    - 違反者への段階的制裁機能（警告、一時停止、永久追放）

*   **モデレーション機能:**
    - 投稿・コメントの削除・非表示
    - ユーザーの一時停止・永久追放
    - 報告された内容の確認・対処
    - モデレーションログの記録・閲覧
    - 自動フィルタリング（スパム、不適切コンテンツ）
    - メンバー間の紛争調停支援

*   **コミュニティイベント:**
    - コミュニティイベントの作成・管理
    - イベント参加者の管理
    - イベントリマインダー・通知
    - 定期イベントの設定
    - イベント履歴・アーカイブ

*   **通知・アナウンス:**
    - コミュニティ全体へのアナウンス機能
    - 重要な通知のピン留め
    - メンバー参加・退会通知
    - ルール更新・変更通知
    - 通知設定のカスタマイズ

*   **統計・分析:**
    - メンバー数・アクティビティの推移
    - 人気投稿・トピックの分析
    - エンゲージメント指標の測定
    - 成長率・参加率の追跡
    - モデレーション活動の統計

*   **プライベートコミュニティ:**
    - 招待制プライベートコミュニティ
    - 承認制コミュニティ（申請→承認）
    - 秘匿コミュニティ（検索結果に表示されない）
    - プライベート内容の外部流出防止

*   **外部連携:**
    - ActivityPub対応（他のインスタンスのコミュニティとの連携）
    - 他サービス（avion-drop、avion-timeline）との連携
    - Webhooks（外部ボット、自動化ツールとの連携）

### やらないこと

*   **メッセージング機能:** リアルタイムチャット機能は将来的な拡張として、初期実装では対象外
*   **ファイル共有:** ファイル管理機能は `avion-media` が担当
*   **ビデオ・音声通話:** リアルタイムコミュニケーション機能は対象外
*   **外部SNS連携:** 他のSNSプラットフォーム（Twitter、Discord等）との直接連携は対象外
*   **高度な分析・BI:** 詳細な分析機能は専門の分析サービスが担当
*   **コンテンツ生成:** AIによるコンテンツ生成・推奨機能は対象外

## 対象ユーザ

*   Avion エンドユーザー (API Gateway経由)
    - コミュニティを作成・管理したいユーザー
    - 特定のトピックに興味を持つユーザー
    - 専門分野での議論を求めるユーザー
    - モデレーター・管理者としてコミュニティを運営したいユーザー
*   Avion の他のマイクロサービス (Timeline, Notification, Drop, Searchなど)
*   Avion 開発者・運用者

## ドメインモデル (DDD戦略的パターン)

### Aggregates (集約)

#### Community Aggregate
**責務**: コミュニティのライフサイクルと基本設定を管理する中核的な集約
- **集約ルート**: Community
- **不変条件**:
  - CommunityNameは2-50文字以内、重複不可
  - OwnerUserIDは変更不可（所有権譲渡は別操作）
  - CreatedAtは作成後変更不可
  - Visibilityは定義された値（public, private, invite_only）のいずれか
  - 削除されたコミュニティは復元不可
  - MemberCountは実際のメンバー数と一致
  - Categoryは定義されたカテゴリのいずれか
- **ドメインロジック**:
  - `canBeEditedBy(userID, role)`: 編集権限の判定（オーナーまたは権限を持つモデレーター）
  - `canBeDeletedBy(userID)`: 削除権限の判定（オーナーのみ）
  - `canBeViewedBy(userID, membership)`: 閲覧権限の判定（公開設定に基づく）
  - `canJoin(userID)`: 参加可能性の判定（公開/招待制/申請制）
  - `updateMemberCount(delta)`: メンバー数の更新
  - `archive()`: アーカイブ処理（投稿停止、読み取り専用化）
  - `validate()`: コミュニティ全体の妥当性検証
  - `transferOwnership(currentOwnerID, newOwnerID)`: 所有権譲渡（検証と権限移譲）
  - `generateInviteLink(expiresAt, maxUses)`: 招待リンク生成（有効期限と使用回数制限付き）
  - `updateActivityScore(score)`: アクティビティスコア更新（トレンド計算用）

#### Membership Aggregate
**責務**: コミュニティへの参加状態と役割を管理
- **集約ルート**: Membership
- **不変条件**:
  - UserIDとCommunityIDの組み合わせは一意
  - Statusは定義された値（active, pending, suspended, banned, left）のいずれか
  - Roleは定義された値（owner, moderator, member, custom_role）のいずれか
  - 同一コミュニティにOwnerは1人のみ
  - Ownerは自分自身をbanやleaveできない
  - JoinedAtは参加承認時に設定
- **ドメインロジック**:
  - `canModerate(targetMembership)`: モデレーション権限の判定（階層チェック）
  - `canChangeRole(targetMembership, newRole)`: 役割変更権限の判定
  - `hasPermission(permission)`: 特定権限の保有確認
  - `canLeave()`: 退会可否の判定（オーナーの場合は所有権譲渡が必要）
  - `applyPenalty(penaltyType)`: 制裁措置の適用
  - `promote(newRole)`: 昇格処理
  - `demote(newRole)`: 降格処理
  - `promoteToModerator()`: モデレーター昇格（権限付与と通知）
  - `demoteFromModerator()`: モデレーター降格（権限剥奪と理由記録）
  - `suspendMember(duration, reason)`: メンバー一時停止（期間と理由を記録）

#### Topic Aggregate  
**責務**: コミュニティ内のトピック（チャンネル）を管理
- **集約ルート**: Topic
- **不変条件**:
  - TopicNameはコミュニティ内で一意、2-30文字以内
  - CommunityIDは変更不可
  - CreatedByUserIDは変更不可
  - TypeはValidated値（general, announcement, archived）のいずれか
  - Archivedの場合は新規投稿不可
  - DisplayOrderは正の整数
- **ドメインロジック**:
  - `canBeAccessedBy(userID, membership)`: アクセス権限の判定
  - `canPost(userID, membership)`: 投稿権限の判定
  - `canModerate(userID, membership)`: モデレーション権限の判定
  - `archive()`: アーカイブ化処理
  - `pin(postID)`: 投稿のピン留め
  - `updateDisplayOrder(newOrder)`: 表示順序の更新

#### CommunityRule Aggregate
**責務**: コミュニティのルールとモデレーションポリシーを管理
- **集約ルート**: CommunityRule
- **不変条件**:
  - RuleNumberはコミュニティ内で一意、正の整数
  - RuleTitleは1-100文字以内
  - RuleDescriptionは最大1000文字
  - Enforcementは定義された値（warning, temp_suspend, permanent_ban）のいずれか
  - IsActiveはtrue/false
  - CreatedByはモデレーター権限以上
- **ドメインロジック**:
  - `canBeEditedBy(userID, membership)`: 編集権限の判定
  - `applyEnforcement(violatorID, membership)`: ルール違反への制裁適用
  - `checkViolation(content)`: コンテンツのルール違反チェック
  - `activate()`: ルールの有効化
  - `deactivate()`: ルールの無効化

#### CommunityInvitation Aggregate
**責務**: コミュニティへの招待を管理
- **集約ルート**: CommunityInvitation
- **不変条件**:
  - InviteCodeは一意、URL-safe文字列
  - ExpiresAtは未来の日時（最大30日後）
  - UsageCountは非負の整数
  - MaxUsageは正の整数または無制限(-1)
  - CreatedByは招待権限を持つメンバー
  - IsActiveはtrue/false
- **ドメインロジック**:
  - `canBeUsed()`: 使用可能性の判定（期限、回数制限）
  - `use(userID)`: 招待の使用（参加処理）
  - `canBeCreatedBy(userID, membership)`: 招待作成権限の判定
  - `revoke()`: 招待の取り消し
  - `extend(newExpiresAt)`: 有効期限の延長

#### CommunityEvent Aggregate
**責務**: コミュニティイベントとスケジュールを管理
- **集約ルート**: CommunityEvent
- **不変条件**:
  - EventTitleは1-100文字以内
  - StartTimeは未来の日時
  - EndTimeはStartTime以降
  - CreatedByはイベント作成権限を持つメンバー
  - MaxParticipantsは正の整数または無制限(-1)
  - Statusは定義された値（scheduled, ongoing, completed, cancelled）のいずれか
- **ドメインロジック**:
  - `canParticipate(userID, membership)`: 参加可否の判定
  - `joinEvent(userID)`: イベント参加処理
  - `leaveEvent(userID)`: イベント退会処理
  - `canManage(userID, membership)`: イベント管理権限の判定
  - `start()`: イベント開始処理
  - `complete()`: イベント完了処理
  - `cancel()`: イベント中止処理

### Entities (エンティティ)

#### MembershipRole Entity
**所属**: Membership Aggregate
**責務**: カスタム役割の定義を管理
- **属性**:
  - RoleID（Entity識別子）
  - RoleName（役割名、コミュニティ内で一意）
  - RoleColor（表示色）
  - Permissions（権限のビットマスク）
  - IsDefault（デフォルト役割かどうか）
  - DisplayOrder（表示順序）
  - CreatedAt（作成日時）
- **ビジネスルール**:
  - RoleNameは2-20文字以内
  - デフォルト役割は削除不可
  - 権限の階層性を保持

#### CommunityModerationLog Entity
**所属**: Community Aggregate
**責務**: モデレーション活動のログを管理
- **属性**:
  - LogID（Entity識別子）
  - ModeratorUserID（モデレーター）
  - TargetUserID（対象ユーザー）
  - ActionType（処理種別）
  - Reason（理由）
  - Evidence（証拠）
  - CreatedAt（実行日時）
- **ビジネスルール**:
  - 削除・編集不可（監査証跡）
  - Reasonは必須
  - ActionTypeは定義された値のみ

#### TopicPin Entity
**所属**: Topic Aggregate
**責務**: トピック内のピン留め投稿を管理
- **属性**:
  - PinID（Entity識別子）
  - PostID（投稿ID）
  - PinnedBy（ピン留めした人）
  - PinnedAt（ピン留め日時）
  - DisplayOrder（表示順序）
- **ビジネスルール**:
  - 同一トピック内でPostIDは一意
  - DisplayOrderで表示順を制御
  - 最大ピン留め数の制限（例：5個まで）

#### EventParticipant Entity
**所属**: CommunityEvent Aggregate
**責務**: イベント参加者を管理
- **属性**:
  - ParticipantID（Entity識別子）
  - UserID（参加者）
  - ParticipantStatus（参加状態）
  - JoinedAt（参加日時）
  - RSVP（出席予定）
- **ビジネスルール**:
  - UserIDはイベント内で一意
  - 定員制限のチェック
  - キャンセル期限の制御

#### CommunityStatistics Entity
**所属**: Community Aggregate（パフォーマンス最適化）
**責務**: コミュニティの統計情報をキャッシュ
- **属性**:
  - StatID（Entity識別子）
  - MemberCount（メンバー数）
  - ActiveMemberCount（アクティブメンバー数）
  - PostCount（投稿数）
  - TopicCount（トピック数）
  - LastActivity（最終アクティビティ日時）
  - UpdatedAt（更新日時）
- **ビジネスルール**:
  - 定期的な再計算
  - 一定期間でのキャッシュ更新

### Value Objects (値オブジェクト)

**識別子関連**
- **CommunityID**: コミュニティの一意識別子（Snowflake ID）
- **MembershipID**: メンバーシップの一意識別子（UUID v4）
- **TopicID**: トピックの一意識別子（Snowflake ID）  
- **InviteCode**: 招待コードの一意識別子（URL-safe文字列）
- **EventID**: イベントの一意識別子（Snowflake ID）
- **RuleID**: ルールの一意識別子（UUID v4）

**コミュニティ属性**
- **CommunityName**: コミュニティ名を表現
  - 2-50文字、Unicode対応
  - 特殊文字の制限あり
  - プラットフォーム全体で一意
- **CommunityDescription**: コミュニティ説明
  - 最大500文字、改行対応
  - マークダウン記法サポート
- **CommunityVisibility**: 公開範囲を表現
  - `public`: 完全公開
  - `private`: 非公開（メンバーのみ）
  - `invite_only`: 招待制
- **CommunityCategory**: カテゴリを表現
  - `technology`: 技術
  - `gaming`: ゲーム
  - `art`: アート・創作
  - `music`: 音楽
  - `sports`: スポーツ
  - `lifestyle`: ライフスタイル
  - `education`: 教育・学習
  - `business`: ビジネス
  - `general`: その他

**メンバーシップ属性**
- **MembershipStatus**: メンバーシップ状態
  - `active`: アクティブ
  - `pending`: 承認待ち
  - `suspended`: 一時停止
  - `banned`: 追放
  - `left`: 退会済み
- **MembershipRole**: 役割
  - `owner`: オーナー（最高権限）
  - `moderator`: モデレーター
  - `member`: 一般メンバー
  - `custom`: カスタム役割
- **MemberPermissions**: 権限セット
  - ビットマスクによる権限管理
  - `can_post`, `can_moderate`, `can_invite`等

**トピック属性**
- **TopicName**: トピック名
  - 2-30文字、絵文字対応
  - コミュニティ内で一意
- **TopicType**: トピック種別
  - `general`: 一般ディスカッション
  - `announcement`: お知らせ
  - `archived`: アーカイブ
- **TopicVisibility**: トピック公開設定
  - `public`: 全メンバー閲覧可
  - `restricted`: 特定役割のみ
  - `private`: 管理者のみ

**時刻・数値**
- **CreatedAt**: 作成日時（UTC、ミリ秒精度）
- **UpdatedAt**: 更新日時（UTC、ミリ秒精度）
- **JoinedAt**: 参加日時（UTC、ミリ秒精度）
- **LastActiveAt**: 最終アクティビティ日時
- **MemberCount**: メンバー数（0以上の整数）
- **DisplayOrder**: 表示順序（1から始まる整数）
- **Version**: 楽観的ロック用バージョン番号

**イベント関連**
- **EventTitle**: イベント名（1-100文字）
- **EventDescription**: イベント説明（最大1000文字）
- **EventStatus**: イベント状態
  - `scheduled`: 予定
  - `ongoing`: 進行中  
  - `completed`: 完了
  - `cancelled`: 中止
- **EventDateTime**: イベント日時（UTC、開始・終了時刻）
- **ParticipantLimit**: 参加者上限（正の整数または無制限）

**ルール関連**
- **RuleTitle**: ルール名（1-100文字）
- **RuleDescription**: ルール説明（最大1000文字）
- **RuleEnforcement**: 違反時の処罰
  - `warning`: 警告
  - `temp_suspend`: 一時停止
  - `permanent_ban`: 永久追放
- **RulePriority**: ルールの優先度（1-100、高いほど重要）

### Domain Services

#### CommunityPermissionService
**責務**: コミュニティ内での権限チェックと認可処理
- **メソッド**:
  - `hasPermission(userID, communityID, permission)`: 特定権限の保有確認
  - `canModerate(moderatorID, targetID, communityID)`: モデレーション権限の判定
  - `getEffectivePermissions(userID, communityID)`: 有効権限の取得
  - `validateRoleHierarchy(fromRole, toRole)`: 役割階層の妥当性確認

#### CommunityDiscoveryService
**責務**: コミュニティの発見と推薦
- **メソッド**:
  - `findRecommendedCommunities(userID, category)`: 推薦コミュニティの取得
  - `searchCommunities(query, filters)`: コミュニティ検索
  - `getTrendingCommunities(timeRange)`: トレンドコミュニティの取得
  - `getSimilarCommunities(communityID)`: 類似コミュニティの取得

#### CommunityModerationService
**責務**: モデレーション処理の支援
- **メソッド**:
  - `applyPenalty(violatorID, communityID, penaltyType, reason)`: 制裁措置の実行
  - `checkAutoModeration(content, communityRules)`: 自動モデレーションチェック
  - `escalateReport(reportID, moderatorID)`: 報告のエスカレーション
  - `generateModerationReport(communityID, timeRange)`: モデレーションレポート生成

## ユースケース

### コミュニティの作成

1. ユーザーは「新しいコミュニティを作成」ボタンをクリック
2. 作成フォームでコミュニティ名、説明、カテゴリ、公開設定を入力
3. コミュニティアバター・ヘッダー画像をアップロード（オプション）
4. 初期ルールとモデレーションポリシーを設定
5. フロントエンドは `avion-gateway` 経由で `avion-community` にコミュニティ作成リクエストを送信
6. CreateCommunityCommandUseCase がリクエストを処理
7. CommunityValidationService でコミュニティ名の重複、文字数制限をチェック
8. CommunityFactory で Community Aggregate を生成
9. Community Aggregate の validate() メソッドで全体の妥当性を確認
10. CommunityRepository 経由でデータベースに永続化
11. MembershipFactory でオーナーのメンバーシップを生成
12. MembershipRepository で永続化
13. CommunityEventPublisher で `community_created` イベントを発行
14. CreateCommunityResponse DTO を返却
15. (非同期) EventHandler が以下のサービスにイベントを伝播:
    - avion-timeline: コミュニティ作成をタイムラインに反映
    - avion-search: コミュニティをインデックスに追加

### コミュニティへの参加

1. ユーザーがコミュニティページで「参加」ボタンをクリック
2. 公開設定に応じて処理が分岐:
   - public: 即座に参加
   - invite_only: エラー表示（招待が必要）
   - private: 参加申請フォーム表示
3. フロントエンドは `avion-gateway` 経由で参加リクエストを送信
4. JoinCommunityCommandUseCase がリクエストを処理
5. CommunityRepository から Community Aggregate を取得
6. Community.canJoin(userID) で参加可否を判定
7. 既存メンバーシップの確認（重複参加防止）
8. MembershipFactory で新規 Membership Aggregate を生成
9. 公開設定に応じてステータスを設定:
   - public: active
   - private: pending
10. MembershipRepository で永続化
11. Community.updateMemberCount(+1) でメンバー数を更新（activeの場合）
12. CommunityEventPublisher でイベントを発行
13. JoinCommunityResponse DTO を返却
14. (非同期) 承認待ちの場合、モデレーターに通知を送信

### トピックの作成

1. コミュニティメンバーが「新しいトピック」ボタンをクリック
2. トピック作成フォームでトピック名、説明、公開設定を入力
3. フロントエンドは `avion-gateway` 経由でトピック作成リクエストを送信
4. CreateTopicCommandUseCase がリクエストを処理
5. MembershipQueryService でユーザーのメンバーシップと権限を確認
6. CommunityPermissionService.hasPermission() でトピック作成権限をチェック
7. TopicFactory で Topic Aggregate を生成
8. Topic.validate() で妥当性検証（名前重複チェック含む）
9. TopicRepository で永続化
10. CommunityEventPublisher で `topic_created` イベントを発行
11. CreateTopicResponse DTO を返却
12. (非同期) コミュニティメンバーに新トピック作成通知

### コミュニティルールの設定

1. コミュニティオーナーが「ルール管理」画面を開く
2. 新規ルール追加フォームでルール内容、違反時の処罰を設定
3. フロントエンドは `avion-gateway` 経由でルール作成リクエストを送信
4. CreateCommunityRuleCommandUseCase がリクエストを処理
5. MembershipQueryService でオーナー/モデレーター権限を確認
6. CommunityRuleFactory で CommunityRule Aggregate を生成
7. CommunityRule.validate() で妥当性検証
8. CommunityRuleRepository で永続化
9. CommunityEventPublisher で `rule_created` イベントを発行
10. CreateRuleResponse DTO を返却
11. (非同期) コミュニティメンバーにルール更新通知

### メンバーのモデレーション（一時停止）

1. モデレーターが問題行為をしたメンバーのプロフィールから「一時停止」を選択
2. 停止期間と理由を入力するダイアログが表示
3. フロントエンドは `avion-gateway` 経由で一時停止リクエストを送信
4. SuspendMemberCommandUseCase がリクエストを処理
5. MembershipQueryService でモデレーターと対象者のメンバーシップを取得
6. CommunityPermissionService.canModerate() でモデレーション権限を確認
7. 対象メンバーの Membership.applyPenalty(temp_suspend) を実行
8. CommunityModerationLogFactory でモデレーションログを生成
9. MembershipRepository とログを永続化
10. CommunityEventPublisher で `member_suspended` イベントを発行
11. SuspendMemberResponse DTO を返却
12. (非同期) 対象者に停止通知、他のモデレーターに処理完了通知

### コミュニティイベントの作成

1. メンバーが「イベント作成」ボタンをクリック
2. イベント作成フォームで名前、日時、説明、参加者上限を設定
3. フロントエンドは `avion-gateway` 経由でイベント作成リクエストを送信
4. CreateCommunityEventCommandUseCase がリクエストを処理
5. MembershipQueryService でイベント作成権限を確認
6. CommunityEventFactory で CommunityEvent Aggregate を生成
7. CommunityEvent.validate() で妥当性検証（日時の妥当性等）
8. CommunityEventRepository で永続化
9. CommunityEventPublisher で `event_created` イベントを発行
10. CreateEventResponse DTO を返却
11. (非同期) コミュニティメンバーにイベント作成通知

### コミュニティの検索・発見

1. ユーザーが「コミュニティを探す」画面を開く
2. 検索キーワード、カテゴリフィルターを設定
3. フロントエンドは `avion-gateway` 経由で検索リクエストを送信
4. SearchCommunitiesQueryUseCase がリクエストを処理
5. CommunityDiscoveryService.searchCommunities() で検索を実行
6. 公開コミュニティのみをフィルタリング
7. ユーザーの興味関心に基づく推薦スコア算出（オプション）
8. CommunityListDTO を生成（各コミュニティの概要情報）
9. SearchCommunitiesResponse DTO を返却
10. フロントエンドは検索結果をカード形式で表示

### 招待リンクの作成・使用

1. コミュニティメンバーが「メンバーを招待」ボタンをクリック
2. 招待設定（有効期限、使用回数制限）を設定
3. フロントエンドは `avion-gateway` 経由で招待作成リクエストを送信
4. CreateInvitationCommandUseCase がリクエストを処理
5. MembershipQueryService で招待権限を確認
6. CommunityInvitationFactory で CommunityInvitation Aggregate を生成
7. 一意のInviteCodeを生成（URL-safe文字列）
8. CommunityInvitationRepository で永続化
9. CreateInvitationResponse DTO を返却（招待URLを含む）
10. (招待リンク使用時) AcceptInvitationCommandUseCase が処理
11. CommunityInvitation.canBeUsed() で使用可能性を確認
12. CommunityInvitation.use(userID) で招待を使用し、メンバーシップを作成
13. 使用回数を更新、上限に達した場合は無効化

## 機能要求

### ドメインロジック要求

*   **Community管理:**
    - コミュニティを集約として管理し、ライフサイクル全体の整合性を保つ
    - 名前の一意性、公開範囲制御、アクセス権限の検証をドメインロジックで実装
    - 削除時の関連データのカスケード処理（メンバーシップ、トピック、イベント等）
    - メンバー数の整合性維持

*   **Membership管理:**
    - メンバーシップを集約として管理し、役割と権限の整合性を保つ
    - 権限の階層構造と委譲関係の検証
    - モデレーション処理の権限チェックと処罰履歴管理
    - 参加・退会時の状態遷移制御

*   **Topic管理:**
    - トピックを集約として管理し、アクセス制御と投稿権限を制御
    - トピック内でのピン留め機能と表示順序管理
    - アーカイブ処理と復元制限

*   **Rule管理:**
    - コミュニティルールを集約として管理し、違反処理の一貫性を保つ
    - 自動モデレーションルールの適用と例外処理
    - ルール変更履歴と適用範囲の管理

### APIエンドポイント要求

*   **Community API:**
    - コミュニティのCRUD操作のためのgRPC APIを提供
    - 検索・発見・推薦機能のAPI
    - 統計情報取得API
    - 認証が必要なエンドポイントはメタデータでユーザーIDを受け取る

*   **Membership API:**
    - メンバーシップのCRUD操作とステータス管理API
    - 権限確認・役割変更API
    - モデレーション処理API（警告、一時停止、追放）

*   **Topic API:**
    - トピックのCRUD操作API
    - トピック別権限管理API
    - ピン留め機能API

*   **Event API:**
    - コミュニティイベントのCRUD操作API
    - イベント参加・退会API
    - イベント通知・リマインダーAPI

### データ要求

*   **基本情報:** コミュニティ名（2-50文字、一意）、説明（最大500文字）、カテゴリ分類
*   **公開範囲:** public, private, invite_only の3段階設定
*   **メンバーシップ:** ユーザーとコミュニティの関連、役割、権限、参加日時
*   **一意なID:** 各エンティティにシステム全体で一意なIDが付与されること
*   **タイムスタンプ:** 作成日時、更新日時、最終アクティビティ日時を記録
*   **権限システム:** 階層構造を持つ役割と権限のマッピング
*   **モデレーション:** 処理履歴、制裁措置、復帰条件の管理
*   **統計情報:** メンバー数、アクティブ率、投稿数等の集計

## 技術的要求

### パフォーマンス要件

#### レスポンスタイム
*   コミュニティ作成: p50 < 300ms, p99 < 500ms
*   コミュニティ検索: p50 < 100ms, p99 < 300ms
*   メンバーシップ確認: p50 < 30ms, p99 < 50ms（キャッシュヒット率 > 95%）
*   権限チェック: p50 < 20ms, p99 < 30ms（キャッシュ活用時）
*   トピック作成: p50 < 150ms, p99 < 200ms
*   モデレーション処理: p50 < 300ms, p99 < 500ms
*   メンバー参加処理: p50 < 150ms, p99 < 200ms

#### スループット
*   コミュニティ作成: 100 communities/秒
*   メンバー参加: 1,000 joins/秒
*   投稿作成: 5,000 posts/秒
*   権限チェック: 50,000 checks/秒

### 可用性

*   **SLA**: 99.9%（月間ダウンタイム < 43.2分）
*   **エラー率**: < 0.1%
*   **レプリケーション**: 最小3レプリカ、最大20レプリカ
*   **自動スケーリング**: CPU使用率60%でスケールアウト
*   **フェイルオーバー**: < 30秒

### スケーラビリティ

#### 容量制限
*   **最大コミュニティ数**: 100,000コミュニティ
*   **最大メンバー数/コミュニティ**: 100,000人
*   **同時アクティブコミュニティ**: 10,000コミュニティ
*   **最大トピック数/コミュニティ**: 1,000トピック
*   **最大同時接続数**: 50,000ユーザー

#### データ成長対応
*   大規模コミュニティ（10万メンバー以上）でも性能劣化しないこと
*   メンバーシップクエリの効率的なインデックス設計（複合インデックス活用）
*   統計情報の非同期集計とキャッシュ活用（Redis使用）
*   ページネーション必須（最大100件/ページ）

### セキュリティ

*   **アクセス制御:** コミュニティの公開範囲設定に基づく厳密なアクセス制御
*   **権限管理:** 役割と権限の整合性検証、特権昇格の防止
*   **データ保護:** プライベートコミュニティの情報漏洩防止
*   **モデレーション:** 悪意のあるユーザーへの適切な制裁措置

### データ整合性

*   メンバー数と実際のメンバーシップ数の整合性維持
*   権限変更時の影響範囲の整合性確保
*   カスケード削除の適切な実装

### その他技術要件

*   **ステートレス:** サービス自体は状態を持たず、水平スケールが可能
*   **Observability:** OpenTelemetry SDKでトレース・メトリクス・ログを出力
*   **キャッシュ戦略:** Redis活用による権限情報・統計情報のキャッシュ
*   **テスト戦略:** TDD必須、80%以上のカバレッジ目標
    - テスト実装については[共通テスト戦略](../common/testing-strategy.md)を参照

## 決まっていないこと

*   高度な自動モデレーション機能の具体的な実装方法
*   カスタム役割の詳細な権限体系
*   コミュニティ統合・分割機能の実装有無
*   外部ボット・Webhook機能の仕様
*   リアルタイムチャット機能との統合方法
*   大規模コミュニティでの階層構造（サブコミュニティ）の実装
*   コミュニティ間の連携機能（提携、姉妹コミュニティ等）
*   高度な分析・レポート機能の範囲
*   外部SNSとの連携機能

## セキュリティ実装ガイドライン

本サービスのセキュリティ実装は、以下の共通セキュリティガイドラインに準拠します：

### 適用セキュリティガイドライン

* **[XSS防止](../common/security/xss-prevention.md)**
  - コミュニティ投稿コンテンツのサニタイゼーション
  - ユーザー生成コンテンツ（プロフィール、説明文）のエスケープ
  - カスタム絵文字・リアクションの安全な処理
  - Markdownレンダリング時のXSS対策

* **[SQLインジェクション防止](../common/security/sql-injection-prevention.md)**
  - コミュニティ検索クエリのパラメータバインディング
  - メンバー検索での安全なクエリ構築
  - 統計情報取得でのプリペアドステートメント使用
  - フィルタリング条件のサニタイゼーション

* **[セキュリティヘッダー](../common/security/security-headers.md)**
  - コミュニティAPIエンドポイントでのCSP設定
  - ユーザー生成コンテンツ配信時のセキュリティヘッダー
  - X-Content-Type-Options設定による型混同防止
  - クリックジャッキング対策のX-Frame-Options設定

### 実装要件

各開発フェーズにおいて、上記セキュリティガイドラインの実装を必須とします。特に以下の点に注意：

1. **ユーザー生成コンテンツ**: 全てのユーザー入力を信頼せず、必ずサニタイゼーション処理を実施
2. **権限管理**: コミュニティのロールベースアクセス制御を厳格に実装
3. **プライバシー保護**: プライベートコミュニティのコンテンツアクセス制御を確実に実装
4. **モデレーション**: 不適切コンテンツの検出と防止機能を組み込む