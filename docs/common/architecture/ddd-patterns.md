# DDD 設計パターンガイドライン

**Last Updated:** 2026/03/15
**Author:** Claude Code
**Status:** 採用済み
**Compliance:** Production Ready

## 概要

本ドキュメントは、Avion プラットフォームにおける Domain-Driven Design（DDD）の戦術的パターンの適用ガイドラインを定義します。各サービスが一貫した設計判断を行うための基準を提供し、Aggregate、Entity、Value Object、Domain Service の設計指針を標準化します。

### 関連ドキュメント

- **全体アーキテクチャ**: [architecture.md](./architecture.md) - 4 層アーキテクチャの全体構成
- **イベントスキーマ**: [event-schemas.md](../events/event-schemas.md) - ドメインイベントの定義
- **テスト戦略**: CLAUDE.md - テスト方針とカバレッジ目標

---

## 目次

1. [Aggregate vs Entity 判断基準](#1-aggregate-vs-entity-判断基準)
2. [Aggregate 設計チェックリスト](#2-aggregate-設計チェックリスト)
3. [各サービスの Aggregate 一覧](#3-各サービスの-aggregate-一覧)
4. [Value Object 設計ガイドライン](#4-value-object-設計ガイドライン)
5. [Domain Service 利用基準](#5-domain-service-利用基準)

---

## 1. Aggregate vs Entity 判断基準

Aggregate と Entity の区別は DDD における最も重要な設計判断の一つです。以下の 3 つの基準に基づいて判断します。

### 1.1 トランザクション境界

**判断基準**: 一貫性を保つべき単位として独立しているか。

Aggregate はトランザクション境界を形成します。同一 Aggregate 内のすべての変更は単一のトランザクションで処理され、不変条件が保証されます。

```
[判断フロー]
  データ A とデータ B は常に同じトランザクションで更新される必要があるか?
    → Yes: 同一 Aggregate に所属させる
    → No:  別の Aggregate として分離する
```

**良い例**: avion-drop における Drop と MediaAttachment の分離

```go
// Drop Aggregate: 投稿のライフサイクルを管理
// MediaAttachment は Drop とは独立したトランザクションで管理可能
// → 別 Aggregate として分離
type Drop struct {
    ID         DropID
    AuthorID   UserID
    Content    DropContent
    Visibility Visibility
    // MediaAttachment は ID 参照のみ保持（Aggregate 間は ID で参照）
    MediaIDs   []MediaID
}
```

**悪い例**: 異なるライフサイクルを持つデータを同一 Aggregate に含める

```go
// アンチパターン: Drop に Reaction を直接含める
type Drop struct {
    ID        DropID
    Content   DropContent
    // Reaction は独立したライフサイクルを持つため、
    // Drop Aggregate に含めるべきではない
    Reactions []Reaction  // NG: 別 Aggregate にすべき
}
```

### 1.2 不変条件の独立性

**判断基準**: 他の Aggregate に依存しない独自の不変条件を持つか。

Aggregate は自身の不変条件を自律的に保証する責務を持ちます。不変条件の検証に他の Aggregate の状態が必要な場合は、Domain Service を介して調整します。

```
[判断フロー]
  このデータの整合性ルールは、他のデータの状態に依存せず自己完結するか?
    → Yes: Aggregate として独立させる
    → No:  上位の Aggregate の一部（Entity）とするか、Domain Service で調整する
```

**具体例**: avion-user における Follow Aggregate の独立性

```go
// Follow Aggregate: フォロー関係の不変条件を自律的に保証
// - 自分自身へのフォローは不可
// - 同一ペアの重複フォローは不可
// - ブロック状態との整合性は Domain Service で調整（他 Aggregate への依存）
type Follow struct {
    ID         FollowID
    FollowerID UserID
    FolloweeID UserID
    IsApproved bool
    CreatedAt  time.Time
}

// 自律的に検証可能な不変条件
func (f *Follow) Validate() error {
    if f.FollowerID == f.FolloweeID {
        return ErrSelfFollowNotAllowed
    }
    return nil
}
```

### 1.3 ライフサイクル独立性

**判断基準**: 独立して生成・削除が可能か。

Aggregate は独立したライフサイクルを持ちます。親 Aggregate の削除時に必ず同時削除される場合は、Entity として親 Aggregate に含めることを検討します。

```
[判断フロー]
  このデータは親データとは独立して生成・削除できるか?
    → Yes: Aggregate として独立させる
    → No:  親 Aggregate 内の Entity とする
```

**具体例**: avion-drop における Reaction の独立性

```go
// Reaction Aggregate: Drop とは独立したライフサイクル
// - Drop 作成後に任意のタイミングで追加・削除可能
// - Drop 削除時の Reaction 削除はイベント駆動で非同期処理
// → 独立した Aggregate として設計
type Reaction struct {
    ID        ReactionID
    DropID    DropID    // Drop Aggregate への ID 参照
    UserID    UserID
    EmojiCode EmojiCode
    CreatedAt time.Time
}
```

### 1.4 判断マトリクス

| 基準 | Aggregate（独立） | Entity（Aggregate 内） |
|:--|:--|:--|
| トランザクション境界 | 独立したトランザクションで更新可能 | 親 Aggregate と同一トランザクションで更新 |
| 不変条件 | 自律的に検証可能 | 親 Aggregate の文脈でのみ意味がある |
| ライフサイクル | 独立して生成・削除可能 | 親の生成・削除に従属 |
| ID | グローバルに一意な ID を持つ | 親 Aggregate 内でローカルに一意 |
| 参照方法 | 他の Aggregate からは ID で参照 | 親 Aggregate を経由してアクセス |

---

## 2. Aggregate 設計チェックリスト

新しい Aggregate を設計する際に、以下のチェックリストを使用して設計の妥当性を検証します。

### 2.1 構造の検証

- [ ] **集約ルートの明確化**: Aggregate の外部からのアクセスは、集約ルートを経由する
- [ ] **ID の一意性**: UUID v7 による一意な識別子を持つ
- [ ] **不変条件の定義**: Aggregate 内で保証すべき不変条件が明文化されている
- [ ] **適切なサイズ**: Aggregate が大きすぎないか（目安: Entity 数が 3-5 以下）

### 2.2 境界の検証

- [ ] **トランザクション境界**: 1 つの Command が 1 つの Aggregate のみを更新する
- [ ] **Aggregate 間参照**: 他の Aggregate への参照は ID のみで行う（オブジェクト参照は不可）
- [ ] **結果整合性**: Aggregate 間の整合性はドメインイベントによる結果整合性で保証する

### 2.3 ライフサイクルの検証

- [ ] **生成ルール**: Factory パターンまたはコンストラクタで生成時のバリデーションを行う
- [ ] **状態遷移**: 許可された状態遷移が明文化されている
- [ ] **削除ルール**: 論理削除か物理削除かが明確であり、関連データへの影響が設計されている

### 2.4 イベントの検証

- [ ] **ドメインイベント発行**: 状態変更時に適切なドメインイベントを発行する
- [ ] **イベントスキーマ**: [event-schemas.md](../events/event-schemas.md) に対応するスキーマが定義されている
- [ ] **NATS Subject**: [nats-jetstream-design.md](../infrastructure/nats-jetstream-design.md) に対応する Subject が定義されている

### 2.5 永続化の検証

- [ ] **Repository インターフェース**: Domain Layer に Repository インターフェースが定義されている
- [ ] **集約単位の操作**: Repository は Aggregate 単位で保存・取得する（Entity 単位では操作しない）
- [ ] **楽観的ロック**: 同時更新の競合を検出する仕組みがある

---

## 3. 各サービスの Aggregate 一覧

### 3.1 一覧テーブル

| サービス | Aggregate | 責務 | 主な不変条件 |
|:--|:--|:--|:--|
| **avion-drop** | Drop | 投稿のライフサイクルとコンテンツ管理 | 文字数上限、公開範囲の有効値 |
| | Reaction | リアクション（絵文字）管理 | 同一ユーザーの同一絵文字の重複不可 |
| | Poll | 投票機能の管理 | 選択肢数の上限、投票期限の整合性 |
| | Bookmark | ブックマーク管理 | 同一 Drop への重複ブックマーク不可 |
| | ContentWarning | コンテンツ警告管理 | 警告テキストの必須性 |
| | EditHistory | 編集履歴管理 | 時系列の整合性 |
| **avion-user** | User | ユーザーアカウントのライフサイクル管理 | ユーザー名の一意性、メールの一意性 |
| | Follow | フォロー関係管理 | 自己フォロー不可、重複フォロー不可 |
| | Block | ブロック関係管理 | 自己ブロック不可 |
| | Mute | ミュート管理 | ミュート期限の整合性 |
| | UserSettings | ユーザー設定管理 | 設定値の有効範囲 |
| | UserList | ユーザーリスト管理 | リスト名の一意性（ユーザー内） |
| | UserStats | ユーザー統計管理 | カウンターの非負制約 |
| **avion-auth** | AuthCredential | 認証情報の統合管理 | 認証方式ごとの整合性 |
| | Session | セッションと JWT 管理 | セッション有効期限、同時セッション数上限 |
| | SigningKey | JWT 署名鍵管理 | 鍵ローテーション期間の整合性 |
| | Authorization | 権限情報と認可判定 | ポリシー評価の一貫性 |
| | BotClient | Bot クライアント管理 | スコープの有効性 |
| | Role | ロール定義管理 | ロール名の一意性 |
| | Policy | 認可ポリシー管理 | ルールの一貫性 |
| **avion-activitypub** | RemoteActor | リモート Actor 情報管理 | URI の一意性、公開鍵の整合性 |
| | FederationDelivery | 配送タスク管理 | 配送状態遷移の整合性 |
| | BlockedActor | ブロック済み Actor 管理 | Actor URI の一意性 |
| | BlockedDomain | ブロック済みドメイン管理 | ドメイン名の一意性、自インスタンス対象外 |
| | ReportedContent | 通報コンテンツ管理 | 通報状態遷移の整合性 |
| **avion-moderation** | Report | 通報の受付と処理状態 | 24 時間以内の重複不可、状態遷移パスの制約 |
| | ModerationCase | 関連通報の統合管理 | 同一対象への統合の一貫性 |
| | ModerationAction | モデレーション操作管理 | 実行済みアクションの不変性 |
| | ContentFilter | フィルタリングルール管理 | 優先度の一意性、システムフィルター削除不可 |
| | Appeal | 異議申し立て管理 | 1 アクション 1 回のみ、期限 7 日 |
| | InstancePolicy | インスタンスポリシー管理 | ドメイン名一意性、自インスタンス対象外 |
| **avion-media** | Media | メディアファイル管理 | ファイルサイズ上限、MIME タイプの有効性 |
| | MediaProcessingTask | 非同期処理タスク管理 | 状態遷移の整合性 |
| | RemoteMediaCache | リモートメディアキャッシュ管理 | TTL の整合性 |
| | MediaBatch | バッチアップロード管理 | バッチサイズ上限 |
| | UserDrive | ユーザーメディアドライブ管理 | 容量上限の整合性 |
| **avion-timeline** | *(注)* | タイムラインは CQRS の Query 側に特化しており、明示的な Aggregate 定義よりもイベント駆動の投影（Projection）パターンを採用 | - |
| **avion-notification** | Notification | 通知のライフサイクル管理 | 同一 EventID から生成される通知は 1 つのみ |
| | WebPushSubscription | Web Push サブスクリプション管理 | エンドポイント URL の一意性 |
| | NotificationEvent | 通知イベント処理管理 | EventID の一意性（べき等処理） |
| | SSEConnectionManager | SSE 接続管理 | 接続 ID の一意性 |
| | Announcement | サーバーアナウンス管理 | 公開期間の整合性 |
| **avion-community** | Community | コミュニティのライフサイクル管理 | コミュニティ名の一意性 |
| | Membership | メンバーシップ管理 | 同一ユーザーの重複参加不可 |
| | Topic | トピック管理 | トピック名の一意性（コミュニティ内） |
| | CommunityRule | ルールとモデレーションポリシー管理 | ルール適用順序の整合性 |
| | CommunityInvitation | 招待管理 | 招待コードの一意性 |
| | CommunityEvent | イベントスケジュール管理 | スケジュールの競合不可 |
| **avion-message** | Message | メッセージのライフサイクル管理 | 暗号化整合性 |
| | Conversation | 会話管理 | 参加者構成の整合性 |
| | EncryptionKey | 暗号化鍵管理 | 鍵ペアの整合性 |
| **avion-search** | SearchIndex | 検索インデックス管理 | インデックス種別の有効性 |
| | IndexOperation | インデックス操作管理 | 操作のべき等性 |
| | HashtagIndex | ハッシュタグインデックス管理 | ハッシュタグの正規化ルール |
| | SearchHistory | 検索履歴管理 | ユーザーごとの履歴上限 |
| **avion-gateway** | RoutingRule | ルーティングルール管理 | ルール優先度の整合性 |
| | LoadBalancingPolicy | 負荷分散ポリシー管理 | ポリシー評価の一貫性 |
| | SecurityPolicy | セキュリティポリシー管理 | ルール適用順序の整合性 |
| | RequestContext | リクエストコンテキスト管理 | 認証情報の整合性 |
| | RateLimitBucket | レート制限管理 | バケットサイズの非負制約 |
| **avion-system-admin** | Announcement | アナウンス管理 | 公開期間の整合性 |
| | SystemConfiguration | システム設定管理 | 設定値の有効範囲 |
| | RateLimitRule | レート制限ルール管理 | ルール優先度の一意性 |
| | AdminUser | 管理者ユーザー管理 | 管理者権限の整合性 |
| | SystemMetrics | システムメトリクス管理 | メトリクス収集期間の整合性 |
| | BackupPolicy | バックアップポリシー管理 | スケジュールの整合性 |

### 3.2 設計上の注意点

#### Aggregate 間参照のルール

Aggregate 間は必ず ID で参照し、オブジェクト参照は行いません。

```go
// 正しい: ID による参照
type Drop struct {
    ID       DropID
    AuthorID UserID  // User Aggregate への ID 参照
}

// 誤り: オブジェクト参照
type Drop struct {
    ID     DropID
    Author User    // NG: Aggregate 間のオブジェクト参照
}
```

#### 結果整合性の適用

Aggregate 間の整合性は、ドメインイベントによる結果整合性で保証します。

```
[例: Drop 削除時のカスケード]
1. avion-drop: Drop Aggregate を削除 → DropDeletedEvent 発行
2. avion-media: イベント受信 → 関連メディアの遅延削除
3. avion-search: イベント受信 → 検索インデックスから削除
4. avion-user: イベント受信 → UserStats.DropCount をデクリメント
5. avion-timeline: イベント受信 → タイムラインキャッシュから削除
```

---

## 4. Value Object 設計ガイドライン

### 4.1 Value Object とは

Value Object は、属性の組み合わせによって意味を持つ不変のオブジェクトです。同一の属性を持つ Value Object は同一と見なされます（値の等価性）。

### 4.2 Value Object を適用すべきケース

| ケース | 判断基準 | 例 |
|:--|:--|:--|
| **Primitive Obsession の解消** | プリミティブ型（string, int）で表現されているが、ドメイン固有のバリデーションやルールが存在する | UserID, EmojiCode, Visibility |
| **関連する属性のグループ化** | 複数の属性が常にセットで扱われ、独立した不変条件を持つ | Dimension（width, height）, DateRange（start, end） |
| **単位を持つ値** | 値に単位や精度が伴い、演算ルールが存在する | FileSize, Duration |
| **列挙値** | 有限の選択肢から選択される値で、各選択肢にドメイン的意味がある | MembershipStatus, Visibility |

### 4.3 Go での Value Object 実装パターン

#### ID 型

```go
// internal/domain/model/user_id.go
package model

import (
    "fmt"

    "github.com/google/uuid"
)

// UserID はユーザーの一意識別子を表す Value Object
type UserID struct {
    value string
}

// NewUserID は UUID v7 から UserID を生成する
func NewUserID(id string) (UserID, error) {
    if _, err := uuid.Parse(id); err != nil {
        return UserID{}, fmt.Errorf("invalid user id: %w", err)
    }
    return UserID{value: id}, nil
}

// String は文字列表現を返す
func (id UserID) String() string {
    return id.value
}

// IsEmpty は空の UserID かどうかを判定する
func (id UserID) IsEmpty() bool {
    return id.value == ""
}

// Equals は同一性を判定する（値の等価性）
func (id UserID) Equals(other UserID) bool {
    return id.value == other.value
}
```

#### 列挙型

```go
// internal/domain/model/visibility.go
package model

import "fmt"

// Visibility は投稿の公開範囲を表す Value Object
type Visibility struct {
    value string
}

var (
    VisibilityPublic   = Visibility{value: "public"}
    VisibilityUnlisted = Visibility{value: "unlisted"}
    VisibilityPrivate  = Visibility{value: "private"}
    VisibilityDirect   = Visibility{value: "direct"}
)

// NewVisibility は文字列から Visibility を生成する
func NewVisibility(v string) (Visibility, error) {
    switch v {
    case "public", "unlisted", "private", "direct":
        return Visibility{value: v}, nil
    default:
        return Visibility{}, fmt.Errorf("invalid visibility: %s", v)
    }
}

// String は文字列表現を返す
func (v Visibility) String() string {
    return v.value
}

// IsPublic は公開投稿かどうかを判定する
func (v Visibility) IsPublic() bool {
    return v.value == "public"
}
```

#### 複合 Value Object

```go
// internal/domain/model/dimension.go
package model

import "fmt"

// Dimension は画像・動画の寸法を表す Value Object
type Dimension struct {
    width  int
    height int
}

// NewDimension は幅と高さから Dimension を生成する
func NewDimension(width, height int) (Dimension, error) {
    if width <= 0 || height <= 0 {
        return Dimension{}, fmt.Errorf("dimension must be positive: width=%d, height=%d", width, height)
    }
    return Dimension{width: width, height: height}, nil
}

// Width は幅を返す
func (d Dimension) Width() int {
    return d.width
}

// Height は高さを返す
func (d Dimension) Height() int {
    return d.height
}

// AspectRatio はアスペクト比を返す
func (d Dimension) AspectRatio() float64 {
    return float64(d.width) / float64(d.height)
}

// Equals は同一性を判定する
func (d Dimension) Equals(other Dimension) bool {
    return d.width == other.width && d.height == other.height
}
```

### 4.4 Value Object 設計の原則

1. **不変性**: 一度生成したら変更しない。変更が必要な場合は新しいインスタンスを生成する
2. **自己バリデーション**: 生成時にバリデーションを行い、不正な状態のオブジェクトが存在しないことを保証する
3. **値の等価性**: 属性値が同一であれば同一と見なす（ID による同一性判定ではなく値による等価性判定）
4. **副作用なし**: メソッドは新しい値を返すか、計算結果を返すのみで、外部状態を変更しない

---

## 5. Domain Service 利用基準

### 5.1 Domain Service とは

Domain Service は、特定の Aggregate に属さないドメインロジックを実装するステートレスなサービスです。以下の場合に使用します。

### 5.2 Domain Service を使用すべきケース

| ケース | 判断基準 | 例 |
|:--|:--|:--|
| **クロス Aggregate 操作** | 複数の Aggregate にまたがるビジネスルールの検証 | FollowDomainService: ブロック状態を考慮したフォロー許可判定 |
| **外部知識の変換** | 外部プロトコルやフォーマットとドメインモデル間の変換 | ActivityPubTranslator: ActivityPub オブジェクトとドメインモデルの相互変換 |
| **複雑な計算ロジック** | 単一 Aggregate に収まらない計算やスコアリング | EngagementAnalysisService: 複数指標に基づくエンゲージメントスコア計算 |
| **ポリシー適用** | ビジネスポリシーの適用と検証 | ContentPolicyService: コンテンツコンプライアンスの検証 |

### 5.3 Domain Service を使用すべきでないケース

| ケース | 代替手段 |
|:--|:--|
| Aggregate 内で完結するロジック | Aggregate のメソッドとして実装する |
| インフラ層の操作（DB, キャッシュ, 外部 API） | Infrastructure Layer で実装する |
| 単純な CRUD 操作 | UseCase Layer で実装する |
| 入力バリデーション | Value Object の生成時バリデーションで実装する |

### 5.4 Domain Service の実装パターン

```go
// internal/domain/service/follow_domain_service.go
package service

import (
    "context"
    "fmt"

    "avion-user/internal/domain/model"
    "avion-user/internal/domain/repository"
)

// FollowDomainService はフォロー関連のクロス Aggregate ビジネスロジックを実装する
//
//go:generate mockgen -source=$GOFILE -destination=../../tests/mocks/domain/service/mock_follow_domain_service.go -package=mocks
type FollowDomainService interface {
    // CanFollow はフォロー許可判定を行う
    // Block Aggregate の状態を考慮するため、Domain Service に配置
    CanFollow(ctx context.Context, followerID, followeeID model.UserID) error
}

type followDomainService struct {
    blockRepo repository.BlockRepository
}

// NewFollowDomainService は FollowDomainService を生成する
func NewFollowDomainService(blockRepo repository.BlockRepository) FollowDomainService {
    return &followDomainService{blockRepo: blockRepo}
}

func (s *followDomainService) CanFollow(ctx context.Context, followerID, followeeID model.UserID) error {
    // 自己フォローチェック（Follow Aggregate の不変条件）
    if followerID.Equals(followeeID) {
        return model.ErrSelfFollowNotAllowed
    }

    // ブロック状態チェック（Block Aggregate との調整 → Domain Service の責務）
    isBlocked, err := s.blockRepo.ExistsByPair(ctx, followerID, followeeID)
    if err != nil {
        return fmt.Errorf("failed to check block status: %w", err)
    }
    if isBlocked {
        return model.ErrBlockedUserCannotFollow
    }

    return nil
}
```

### 5.5 Avion プラットフォームにおける主要な Domain Service

| サービス | Domain Service | 責務 |
|:--|:--|:--|
| **avion-drop** | ContentPolicyService | コンテンツポリシーの適用と検証 |
| | EngagementAnalysisService | エンゲージメント分析とスコアリング |
| | PrivacyEnforcementService | プライバシーポリシーの実施 |
| | ThreadService | スレッド管理と順序制御 |
| | ReplyService | 返信と会話スレッド管理 |
| | ContentRelationService | コンテンツ間関係管理 |
| **avion-user** | FollowDomainService | ブロック状態を考慮したフォロー許可判定 |
| | UserDomainService | ユーザー名の一意性チェック等 |
| **avion-activitypub** | ActivityPubTranslator | ActivityPub プロトコルとドメインモデル間の変換（アンチコラプションレイヤー） |
| | SignatureVerificationService | HTTP Signatures の検証と公開鍵管理 |
| | ActivityBuilder | ActivityPub アクティビティの生成 |
| **avion-moderation** | PriorityCalculationService | 通報優先度の自動計算 |
| | EscalationService | エスカレーション判定 |
| **avion-notification** | NotificationFactory | イベントから通知オブジェクトの生成 |
| | NotificationPreferenceService | ユーザー設定に基づく通知フィルタリング |
| | SSEBroadcaster | SSE イベントのブロードキャスト |
| **avion-community** | CommunityPermissionService | 権限チェックと認可処理 |

---

## まとめ

本ドキュメントにより、以下を実現します。

1. **Aggregate 設計の一貫性**: 3 つの判断基準（トランザクション境界、不変条件の独立性、ライフサイクル独立性）による統一的な設計判断
2. **設計品質の担保**: チェックリストによる設計レビューの標準化
3. **全サービスの Aggregate 可視化**: 一覧テーブルによるサービス間のパターン共有と整合性確認
4. **Value Object の適切な活用**: Primitive Obsession の排除と型安全性の向上
5. **Domain Service の適用基準**: 過度な Domain Service 使用の防止と適切な責務配置
