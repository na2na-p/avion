# イベントスキーマ定義

**Last Updated:** 2026/03/15
**Author:** Claude Code
**Status:** 採用済み
**Compliance:** Production Ready

## 概要

本ドキュメントは、Avion プラットフォームにおける全サービスのドメインイベントスキーマを一元的に定義します。各サービスが NATS JetStream を通じて発行・購読するイベントの構造を標準化し、サービス間連携の信頼性と開発効率を向上させることを目的としています。

### 本ドキュメントの位置付け

- **NATS JetStream 設計**: Subject 命名規則、Stream/Consumer 設計は [nats-jetstream-design.md](../infrastructure/nats-jetstream-design.md) を参照
- **キャッシュ無効化**: イベント駆動キャッシュ無効化は [redis-cache-strategy.md](../infrastructure/redis-cache-strategy.md) を参照
- **DDD パターン**: Aggregate とイベントの関係は [ddd-patterns.md](../architecture/ddd-patterns.md) を参照

---

## 目次

1. [共通イベントエンベロープ](#1-共通イベントエンベロープ)
2. [イベント分類](#2-イベント分類)
3. [サービス別イベントスキーマ](#3-サービス別イベントスキーマ)
4. [イベントバージョニング戦略](#4-イベントバージョニング戦略)
5. [べき等性保証メカニズム](#5-べき等性保証メカニズム)
6. [NATS JetStream Subject マッピング](#6-nats-jetstream-subject-マッピング)
7. [Producer-Consumer マトリクス](#7-producer-consumer-マトリクス)

---

## 1. 共通イベントエンベロープ

すべてのドメインイベントは、以下の共通エンベロープ構造でラップされます。この構造により、イベントのトレーサビリティ、べき等処理、バージョン管理が保証されます。

### 1.1 Go 構造体定義

```go
// internal/domain/event/envelope.go
package event

import "time"

// Envelope はすべてのドメインイベントに共通するメタデータを保持する
type Envelope struct {
    // EventID はイベントの一意識別子（UUID v7）
    // べき等処理の判定キーとして使用される
    // NATS JetStream の MsgID としても利用し、重複排除ウィンドウ内の二重配信を防止する
    EventID string `json:"event_id"`

    // EventType はイベントの種別を示す完全修飾名
    // 形式: avion.{service}.{aggregate}.{event_type}
    EventType string `json:"event_type"`

    // AggregateID はイベント発生元の集約ルートID
    AggregateID string `json:"aggregate_id"`

    // Source はイベント発行元のサービス名
    // 形式: avion-{service}
    Source string `json:"source"`

    // OccurredAt はイベントが発生した時刻（UTC）
    OccurredAt time.Time `json:"occurred_at"`

    // TraceID は分散トレーシング用の識別子
    // OpenTelemetry の trace_id と対応する
    TraceID string `json:"trace_id"`

    // Version はイベントスキーマのバージョン番号
    // 後方互換性のない変更時にインクリメントされる
    Version int `json:"version"`
}
```

### 1.2 JSON 表現

```json
{
  "event_id": "019a1b2c-3d4e-7f5a-8b9c-0d1e2f3a4b5c",
  "event_type": "avion.drop.drop.created",
  "aggregate_id": "019a1b2c-3d4e-7f5a-8b9c-0d1e2f3a4b5d",
  "source": "avion-drop",
  "occurred_at": "2026-03-15T10:30:00Z",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "version": 1,
  "data": { ... }
}
```

### 1.3 フィールド仕様

| フィールド | 型 | 必須 | 説明 |
|:--|:--|:--|:--|
| `event_id` | string (UUID v7) | 必須 | イベントの一意識別子。NATS JetStream の重複排除（MsgID）にも使用 |
| `event_type` | string | 必須 | `avion.{service}.{aggregate}.{event_type}` 形式の完全修飾名 |
| `aggregate_id` | string (UUID v7) | 必須 | イベント発生元の集約ルート ID |
| `source` | string | 必須 | イベント発行元サービス名（`avion-{service}` 形式） |
| `occurred_at` | string (RFC 3339) | 必須 | イベント発生時刻（UTC） |
| `trace_id` | string | 必須 | OpenTelemetry 準拠の分散トレース ID |
| `version` | int | 必須 | イベントスキーマバージョン（初期値: 1） |

### 1.4 EventID の生成ルール

- **形式**: UUID v7（タイムスタンプベース、ソート可能）
- **生成タイミング**: イベント発行時に Producer 側で生成する
- **一意性**: グローバルに一意であることを保証する
- **用途**: NATS JetStream の `MsgID` オプションに設定し、重複排除ウィンドウ（2分間）内の二重配信を防止する

---

## 2. イベント分類

各イベントは以下の 3 カテゴリに分類されます。

| カテゴリ | 説明 | 安定性 | 例 |
|:--|:--|:--|:--|
| **Core** | 外部サービスが購読する主要イベント。後方互換性を厳格に維持する | 安定 | `drop.created`, `user.follow.created` |
| **Internal** | サービス内部またはインフラ層で使用されるイベント。スキーマ変更の制約は緩い | 準安定 | `fanout.completed`, `cache.invalidated` |
| **Future** | 将来の拡張のために予約されたイベント。現時点では未実装 | 不安定 | `trend.calculated`, `recommendation.generated` |

---

## 3. サービス別イベントスキーマ

### 3.1 avion-drop

Drop（投稿）のライフサイクルとエンゲージメントに関するイベントを発行します。

#### DropCreatedEvent [Core]

Drop が作成され、タイムラインへの配信が可能になったことを示すイベント。

```go
// Subject: avion.drop.drop.created
type DropCreatedEvent struct {
    Envelope
    Data DropCreatedData `json:"data"`
}

type DropCreatedData struct {
    DropID            string    `json:"drop_id"`
    AuthorID          string    `json:"author_id"`
    Text              string    `json:"text"`
    Visibility        string    `json:"visibility"` // public, unlisted, private, direct
    MediaIDs          []string  `json:"media_ids,omitempty"`
    ExtractedHashtags []string  `json:"extracted_hashtags,omitempty"`
    ExtractedMentions []string  `json:"extracted_mentions,omitempty"`
    ReplyToDropID     string    `json:"reply_to_drop_id,omitempty"`
    SensitiveFlag     bool      `json:"sensitive_flag"`
    CreatedAt         time.Time `json:"created_at"`
}
```

**購読サービス:** avion-timeline, avion-search, avion-activitypub, avion-notification, avion-user, avion-moderation

#### DropEditedEvent [Core]

Drop のコンテンツが編集されたことを示すイベント。

```go
// Subject: avion.drop.drop.updated
type DropEditedEvent struct {
    Envelope
    Data DropEditedData `json:"data"`
}

type DropEditedData struct {
    DropID    string    `json:"drop_id"`
    AuthorID  string    `json:"author_id"`
    Text      string    `json:"text"`
    MediaIDs  []string  `json:"media_ids,omitempty"`
    UpdatedAt time.Time `json:"updated_at"`
}
```

**購読サービス:** avion-timeline, avion-search, avion-activitypub, avion-notification

#### DropDeletedEvent [Core]

Drop が削除され、関連データの整理が必要であることを示すイベント。

```go
// Subject: avion.drop.drop.deleted
type DropDeletedEvent struct {
    Envelope
    Data DropDeletedData `json:"data"`
}

type DropDeletedData struct {
    DropID    string   `json:"drop_id"`
    AuthorID  string   `json:"author_id"`
    MediaIDs  []string `json:"media_ids,omitempty"`
    DeletedAt time.Time `json:"deleted_at"`
}
```

**購読サービス:** avion-timeline, avion-search, avion-activitypub, avion-user, avion-media

#### ReactionAddedEvent [Core]

Drop にリアクション（絵文字）が追加されたことを示すイベント。

```go
// Subject: avion.drop.reaction.created
type ReactionAddedEvent struct {
    Envelope
    Data ReactionAddedData `json:"data"`
}

type ReactionAddedData struct {
    DropID      string    `json:"drop_id"`
    UserID      string    `json:"user_id"`
    EmojiCode   string    `json:"emoji_code"`
    EmojiType   string    `json:"emoji_type"` // unicode, custom
    CreatedAt   time.Time `json:"created_at"`
}
```

**購読サービス:** avion-notification, avion-activitypub, avion-user

#### ReactionRemovedEvent [Core]

Drop からリアクションが削除されたことを示すイベント。

```go
// Subject: avion.drop.reaction.deleted
type ReactionRemovedEvent struct {
    Envelope
    Data ReactionRemovedData `json:"data"`
}

type ReactionRemovedData struct {
    DropID    string    `json:"drop_id"`
    UserID    string    `json:"user_id"`
    EmojiCode string    `json:"emoji_code"`
    DeletedAt time.Time `json:"deleted_at"`
}
```

**購読サービス:** avion-activitypub, avion-user

#### BookmarkAddedEvent [Internal]

ユーザーが Drop をブックマークしたことを示すイベント。

```go
// Subject: avion.drop.bookmark.created
type BookmarkAddedEvent struct {
    Envelope
    Data BookmarkAddedData `json:"data"`
}

type BookmarkAddedData struct {
    BookmarkID string    `json:"bookmark_id"`
    DropID     string    `json:"drop_id"`
    UserID     string    `json:"user_id"`
    CreatedAt  time.Time `json:"created_at"`
}
```

#### BookmarkRemovedEvent [Internal]

ブックマークが解除されたことを示すイベント。

```go
// Subject: avion.drop.bookmark.deleted
type BookmarkRemovedEvent struct {
    Envelope
    Data BookmarkRemovedData `json:"data"`
}

type BookmarkRemovedData struct {
    BookmarkID string    `json:"bookmark_id"`
    DropID     string    `json:"drop_id"`
    UserID     string    `json:"user_id"`
    DeletedAt  time.Time `json:"deleted_at"`
}
```

#### PollVotedEvent [Core]

投票に参加したことを示すイベント。

```go
// Subject: avion.drop.poll.voted
type PollVotedEvent struct {
    Envelope
    Data PollVotedData `json:"data"`
}

type PollVotedData struct {
    PollID    string    `json:"poll_id"`
    UserID    string    `json:"user_id"`
    OptionIDs []string  `json:"option_ids"`
    CreatedAt time.Time `json:"created_at"`
}
```

**購読サービス:** avion-notification, avion-activitypub

#### PollClosedEvent [Core]

投票が終了し結果が確定したことを示すイベント。

```go
// Subject: avion.drop.poll.closed
type PollClosedEvent struct {
    Envelope
    Data PollClosedData `json:"data"`
}

type PollClosedData struct {
    PollID   string    `json:"poll_id"`
    DropID   string    `json:"drop_id"`
    ClosedAt time.Time `json:"closed_at"`
}
```

**購読サービス:** avion-notification, avion-activitypub

#### DropRepostedEvent [Core]

Drop がリポストされたことを示すイベント。

```go
// Subject: avion.drop.renote.created
type DropRepostedEvent struct {
    Envelope
    Data DropRepostedData `json:"data"`
}

type DropRepostedData struct {
    RenoteID  string    `json:"renote_id"`
    DropID    string    `json:"drop_id"`
    UserID    string    `json:"user_id"`
    Comment   string    `json:"comment,omitempty"` // 引用リノートの場合
    CreatedAt time.Time `json:"created_at"`
}
```

**購読サービス:** avion-notification, avion-timeline, avion-activitypub

---

### 3.2 avion-user

ユーザーアカウントのライフサイクルとソーシャルグラフに関するイベントを発行します。

#### UserCreatedEvent [Core]

新規ユーザーが作成されたことを示すイベント。

```go
// Subject: avion.user.profile.created
type UserCreatedEvent struct {
    Envelope
    Data UserCreatedData `json:"data"`
}

type UserCreatedData struct {
    UserID    string    `json:"user_id"`
    Username  string    `json:"username"`
    Email     string    `json:"email"`
    IsBot     bool      `json:"is_bot"`
    CreatedAt time.Time `json:"created_at"`
}
```

**購読サービス:** avion-search, avion-moderation, avion-activitypub

#### UserUpdatedEvent [Core]

ユーザープロフィールが更新されたことを示すイベント。

```go
// Subject: avion.user.profile.updated
type UserUpdatedEvent struct {
    Envelope
    Data UserUpdatedData `json:"data"`
}

type UserUpdatedData struct {
    UserID  string            `json:"user_id"`
    Changes map[string]string `json:"changes"` // 変更されたフィールドと新しい値
    UpdatedAt time.Time       `json:"updated_at"`
}
```

**購読サービス:** avion-search, avion-activitypub

#### UserDeletedEvent [Core]

ユーザーアカウントが削除されたことを示すイベント。ユーザー削除カスケードのトリガーとなる。

```go
// Subject: avion.user.profile.deleted
type UserDeletedEvent struct {
    Envelope
    Data UserDeletedData `json:"data"`
}

type UserDeletedData struct {
    UserID    string    `json:"user_id"`
    DeletedAt time.Time `json:"deleted_at"`
}
```

**購読サービス:** avion-search, avion-activitypub, avion-drop, avion-media, avion-moderation, avion-notification

#### FollowCreatedEvent [Core]

フォロー関係が作成されたことを示すイベント。

```go
// Subject: avion.user.follow.created
type FollowCreatedEvent struct {
    Envelope
    Data FollowCreatedData `json:"data"`
}

type FollowCreatedData struct {
    FollowerID string    `json:"follower_id"`
    FolloweeID string    `json:"followee_id"`
    IsApproved bool      `json:"is_approved"`
    CreatedAt  time.Time `json:"created_at"`
}
```

**購読サービス:** avion-timeline, avion-notification, avion-activitypub

#### FollowRemovedEvent [Core]

フォロー関係が解除されたことを示すイベント。

```go
// Subject: avion.user.follow.deleted
type FollowRemovedEvent struct {
    Envelope
    Data FollowRemovedData `json:"data"`
}

type FollowRemovedData struct {
    FollowerID string    `json:"follower_id"`
    FolloweeID string    `json:"followee_id"`
    DeletedAt  time.Time `json:"deleted_at"`
}
```

**購読サービス:** avion-timeline, avion-activitypub

#### UserBlockedEvent [Core]

ユーザーがブロックされたことを示すイベント。

```go
// Subject: avion.user.block.created
type UserBlockedEvent struct {
    Envelope
    Data UserBlockedData `json:"data"`
}

type UserBlockedData struct {
    BlockerID string    `json:"blocker_id"`
    BlockedID string    `json:"blocked_id"`
    CreatedAt time.Time `json:"created_at"`
}
```

**購読サービス:** avion-timeline, avion-activitypub

#### UserUnblockedEvent [Core]

ブロックが解除されたことを示すイベント。

```go
// Subject: avion.user.block.deleted
type UserUnblockedEvent struct {
    Envelope
    Data UserUnblockedData `json:"data"`
}

type UserUnblockedData struct {
    BlockerID string    `json:"blocker_id"`
    BlockedID string    `json:"blocked_id"`
    DeletedAt time.Time `json:"deleted_at"`
}
```

**購読サービス:** avion-timeline, avion-activitypub

#### MuteCreatedEvent [Core]

ミュート設定が作成されたことを示すイベント。

```go
// Subject: avion.user.mute.created
type MuteCreatedEvent struct {
    Envelope
    Data MuteCreatedData `json:"data"`
}

type MuteCreatedData struct {
    MuterID   string    `json:"muter_id"`
    MutedID   string    `json:"muted_id"`
    MuteType  string    `json:"mute_type"` // user, keyword, domain
    ExpiresAt time.Time `json:"expires_at,omitempty"`
    CreatedAt time.Time `json:"created_at"`
}
```

**購読サービス:** avion-timeline, avion-notification

#### MuteRemovedEvent [Core]

ミュート設定が解除されたことを示すイベント。

```go
// Subject: avion.user.mute.deleted
type MuteRemovedEvent struct {
    Envelope
    Data MuteRemovedData `json:"data"`
}

type MuteRemovedData struct {
    MuterID   string    `json:"muter_id"`
    MutedID   string    `json:"muted_id"`
    MuteType  string    `json:"mute_type"` // user, keyword, domain
    DeletedAt time.Time `json:"deleted_at"`
}
```

**購読サービス:** avion-timeline, avion-notification

#### BlockListChangedEvent [Internal]

ブロックリストが変更されたことを示すイベント。キャッシュ無効化のトリガーとして使用。

```go
// Subject: avion.user.block.created / avion.user.block.deleted
// 注: UserBlockedEvent / UserUnblockedEvent と同一の Subject を共有する
// キャッシュ無効化用途では、UserBlockedEvent / UserUnblockedEvent を購読して処理する
```

---

### 3.3 avion-auth

認証・認可のライフサイクルとセキュリティイベントを発行します。

#### SessionCreatedEvent [Core]

認証セッションが作成された（ログイン成功）ことを示すイベント。

```go
// Subject: avion.auth.session.created
type SessionCreatedEvent struct {
    Envelope
    Data SessionCreatedData `json:"data"`
}

type SessionCreatedData struct {
    UserID            string    `json:"user_id"`
    SessionID         string    `json:"session_id"`
    AuthMethod        string    `json:"auth_method"` // password, passkey, totp
    IPAddress         string    `json:"ip_address"`
    DeviceFingerprint string    `json:"device_fingerprint"`
    CreatedAt         time.Time `json:"created_at"`
}
```

**購読サービス:** avion-gateway, avion-notification

#### SessionRevokedEvent [Core]

セッションが無効化された（ログアウトまたは強制失効）ことを示すイベント。

```go
// Subject: avion.auth.session.revoked
type SessionRevokedEvent struct {
    Envelope
    Data SessionRevokedData `json:"data"`
}

type SessionRevokedData struct {
    SessionID string    `json:"session_id"`
    UserID    string    `json:"user_id"`
    Reason    string    `json:"reason"` // user_logout, forced_revoke, expired
    RevokedAt time.Time `json:"revoked_at"`
}
```

**購読サービス:** avion-gateway

#### RoleAssignedEvent [Core]

ユーザーにロールが付与または変更されたことを示すイベント。

```go
// Subject: avion.auth.role.changed
type RoleAssignedEvent struct {
    Envelope
    Data RoleAssignedData `json:"data"`
}

type RoleAssignedData struct {
    UserID    string     `json:"user_id"`
    Action    string     `json:"action"` // grant, revoke
    RoleID    string     `json:"role_id"`
    GrantedBy string     `json:"granted_by"`
    ExpiresAt *time.Time `json:"expires_at,omitempty"`
    ChangedAt time.Time  `json:"changed_at"`
}
```

**購読サービス:** avion-notification

#### PolicyUpdatedEvent [Core]

認可ポリシーが更新されたことを示すイベント。

```go
// Subject: avion.auth.policy.updated
type PolicyUpdatedEvent struct {
    Envelope
    Data PolicyUpdatedData `json:"data"`
}

type PolicyUpdatedData struct {
    PolicyID  string    `json:"policy_id"`
    Action    string    `json:"action"`    // created, updated, deleted
    UpdatedBy string    `json:"updated_by"`
    UpdatedAt time.Time `json:"updated_at"`
}
```

**購読サービス:** avion-gateway

#### PasskeyRegisteredEvent [Internal]

Passkey が登録されたことを示すイベント。

```go
// Subject: avion.auth.passkey.registered
type PasskeyRegisteredEvent struct {
    Envelope
    Data PasskeyRegisteredData `json:"data"`
}

type PasskeyRegisteredData struct {
    UserID       string    `json:"user_id"`
    CredentialID string    `json:"credential_id"`
    DeviceName   string    `json:"device_name"`
    RegisteredAt time.Time `json:"registered_at"`
}
```

#### PasswordChangedEvent [Internal]

パスワードが変更されたことを示すイベント。

```go
// Subject: avion.auth.account.password_changed
type PasswordChangedEvent struct {
    Envelope
    Data PasswordChangedData `json:"data"`
}

type PasswordChangedData struct {
    UserID    string    `json:"user_id"`
    ChangedAt time.Time `json:"changed_at"`
}
```

#### AccountLockedEvent [Core]

アカウントがロックされたことを示すイベント。

```go
// Subject: avion.auth.account.locked
type AccountLockedEvent struct {
    Envelope
    Data AccountLockedData `json:"data"`
}

type AccountLockedData struct {
    UserID      string    `json:"user_id"`
    LockedUntil time.Time `json:"locked_until"`
    Reason      string    `json:"reason"` // too_many_attempts, admin_action
    LockedAt    time.Time `json:"locked_at"`
}
```

**購読サービス:** avion-notification

#### AnomalousLoginDetectedEvent [Core]

異常なログインが検知されたことを示すイベント。

```go
// Subject: avion.auth.security.anomalous_login
type AnomalousLoginDetectedEvent struct {
    Envelope
    Data AnomalousLoginDetectedData `json:"data"`
}

type AnomalousLoginDetectedData struct {
    UserID     string   `json:"user_id"`
    RiskScore  int      `json:"risk_score"`
    Indicators []string `json:"indicators"` // new_location, new_device, etc.
    IPAddress  string   `json:"ip_address"`
    Location   string   `json:"location"`
    DetectedAt time.Time `json:"detected_at"`
}
```

**購読サービス:** avion-notification

---

### 3.4 avion-activitypub

ActivityPub プロトコルに関するイベントを発行します。リモートサーバーとの連携状態を通知します。

#### APFollowReceivedEvent [Core]

リモートサーバーからフォローアクティビティを受信したことを示すイベント。

```go
// Subject: avion.activitypub.follow.received
type APFollowReceivedEvent struct {
    Envelope
    Data APFollowReceivedData `json:"data"`
}

type APFollowReceivedData struct {
    ActivityID string    `json:"activity_id"`
    ActorURI   string    `json:"actor_uri"`
    ObjectURI  string    `json:"object_uri"`
    ReceivedAt time.Time `json:"received_at"`
}
```

**購読サービス:** avion-user, avion-notification

#### APCreateReceivedEvent [Core]

リモートサーバーから Create アクティビティ（投稿等）を受信したことを示すイベント。

```go
// Subject: avion.activitypub.activity.received
type APCreateReceivedEvent struct {
    Envelope
    Data APCreateReceivedData `json:"data"`
}

type APCreateReceivedData struct {
    ActivityID   string    `json:"activity_id"`
    ActivityType string    `json:"activity_type"`
    ActorURI     string    `json:"actor_uri"`
    ObjectURI    string    `json:"object_uri,omitempty"`
    ReceivedAt   time.Time `json:"received_at"`
}
```

**購読サービス:** avion-drop, avion-timeline

#### APBlockReceivedEvent [Core]

リモートサーバーからブロックアクティビティを受信したことを示すイベント。

```go
// Subject: avion.activitypub.block.received
type APBlockReceivedEvent struct {
    Envelope
    Data APBlockReceivedData `json:"data"`
}

type APBlockReceivedData struct {
    ActivityID string    `json:"activity_id"`
    ActorURI   string    `json:"actor_uri"`
    ObjectURI  string    `json:"object_uri"`
    ReceivedAt time.Time `json:"received_at"`
}
```

**購読サービス:** avion-user

#### APAnnounceReceivedEvent [Core]

リモートサーバーから Announce アクティビティ（ブースト/リポスト）を受信したことを示すイベント。

```go
// Subject: avion.activitypub.announce.received
type APAnnounceReceivedEvent struct {
    Envelope
    Data APAnnounceReceivedData `json:"data"`
}

type APAnnounceReceivedData struct {
    ActivityID string    `json:"activity_id"`
    ActorURI   string    `json:"actor_uri"`
    ObjectURI  string    `json:"object_uri"`
    ReceivedAt time.Time `json:"received_at"`
}
```

**購読サービス:** avion-timeline, avion-notification

---

### 3.5 avion-moderation

コンテンツモデレーションに関するイベントを発行します。

#### ReportCreatedEvent [Core]

通報が作成されたことを示すイベント。

```go
// Subject: avion.moderation.report.created
type ReportCreatedEvent struct {
    Envelope
    Data ReportCreatedData `json:"data"`
}

type ReportCreatedData struct {
    ReportID   string    `json:"report_id"`
    ReporterID string    `json:"reporter_id"`
    TargetType string    `json:"target_type"` // user, drop, media, instance
    TargetID   string    `json:"target_id"`
    Reason     string    `json:"reason"`      // spam, harassment, violence, illegal, etc.
    Priority   int       `json:"priority"`
    CreatedAt  time.Time `json:"created_at"`
}
```

**購読サービス:** avion-notification (管理者通知)

#### ModerationActionExecutedEvent [Core]

モデレーションアクションが実行されたことを示すイベント。

```go
// Subject: avion.moderation.action.executed
type ModerationActionExecutedEvent struct {
    Envelope
    Data ModerationActionExecutedData `json:"data"`
}

type ModerationActionExecutedData struct {
    ActionID    string     `json:"action_id"`
    ActionType  string     `json:"action_type"` // warn, delete_content, suspend_account, ban_account, shadowban, restrict_reach
    TargetType  string     `json:"target_type"` // user, drop, media
    TargetID    string     `json:"target_id"`
    ModeratorID string     `json:"moderator_id"`
    Severity    string     `json:"severity"`    // low, medium, high, critical
    ExpiresAt   *time.Time `json:"expires_at,omitempty"`
    ExecutedAt  time.Time  `json:"executed_at"`
}
```

**購読サービス:** avion-notification, avion-user, avion-drop

#### ContentFilterTriggeredEvent [Core]

コンテンツフィルターがトリガーされたことを示すイベント。

```go
// Subject: avion.moderation.filter.updated
type ContentFilterTriggeredEvent struct {
    Envelope
    Data ContentFilterTriggeredData `json:"data"`
}

type ContentFilterTriggeredData struct {
    FilterID    string  `json:"filter_id"`
    ContentType string  `json:"content_type"` // drop, comment
    ContentID   string  `json:"content_id"`
    Action      string  `json:"action"`       // flag, hold, reject, shadowban, auto_delete
    Confidence  float64 `json:"confidence"`
    CreatedAt   time.Time `json:"created_at"`
}
```

**購読サービス:** avion-notification (管理者通知)

#### InstancePolicyChangedEvent [Core]

インスタンスポリシーが変更されたことを示すイベント。

```go
// Subject: avion.moderation.instance_policy.changed
type InstancePolicyChangedEvent struct {
    Envelope
    Data InstancePolicyChangedData `json:"data"`
}

type InstancePolicyChangedData struct {
    Domain     string    `json:"domain"`
    PolicyType string    `json:"policy_type"` // block, silence, media_removal, reject_reports, quarantine
    Reason     string    `json:"reason"`
    AppliedAt  time.Time `json:"applied_at"`
}
```

**購読サービス:** avion-activitypub

---

### 3.6 avion-media

メディアファイルの処理に関するイベントを発行します。

#### MediaUploadCompletedEvent [Core]

メディアアップロードが完了したことを示すイベント。

```go
// Subject: avion.media.upload.completed
type MediaUploadCompletedEvent struct {
    Envelope
    Data MediaUploadCompletedData `json:"data"`
}

type MediaUploadCompletedData struct {
    MediaID   string    `json:"media_id"`
    UserID    string    `json:"user_id"`
    MediaType string    `json:"media_type"` // image, video, audio
    FileSize  int64     `json:"file_size"`
    UploadedAt time.Time `json:"uploaded_at"`
}
```

**購読サービス:** avion-drop

#### MediaProcessingCompletedEvent [Internal]

メディア処理（サムネイル生成、トランスコード等）が完了したことを示すイベント。

```go
// Subject: avion.media.processing.completed
type MediaProcessingCompletedEvent struct {
    Envelope
    Data MediaProcessingCompletedData `json:"data"`
}

type MediaProcessingCompletedData struct {
    MediaID        string   `json:"media_id"`
    ProcessingType string   `json:"processing_type"` // thumbnail, audio_transcode, etc.
    Success        bool     `json:"success"`
    ThumbnailURLs  []string `json:"thumbnail_urls,omitempty"`
    Error          string   `json:"error,omitempty"`
    CompletedAt    time.Time `json:"completed_at"`
}
```

**購読サービス:** avion-notification

#### MediaProcessingFailedEvent [Internal]

メディア処理が失敗したことを示すイベント。

```go
// Subject: avion.media.processing.failed
type MediaProcessingFailedEvent struct {
    Envelope
    Data MediaProcessingFailedData `json:"data"`
}

type MediaProcessingFailedData struct {
    MediaID        string    `json:"media_id"`
    ProcessingType string    `json:"processing_type"` // thumbnail, audio_transcode, etc.
    ErrorCode      string    `json:"error_code"`
    ErrorMessage   string    `json:"error_message"`
    RetryCount     int       `json:"retry_count"`
    FailedAt       time.Time `json:"failed_at"`
}
```

**購読サービス:** avion-notification

#### MediaDeletedEvent [Core]

メディアが削除されたことを示すイベント。

```go
// Subject: avion.media.upload.deleted
type MediaDeletedEvent struct {
    Envelope
    Data MediaDeletedData `json:"data"`
}

type MediaDeletedData struct {
    MediaID      string   `json:"media_id"`
    UserID       string   `json:"user_id"`
    DeleteReason string   `json:"delete_reason"`
    StorageKeys  []string `json:"storage_keys"`
    DeletedAt    time.Time `json:"deleted_at"`
}
```

#### NSFWFlagChangedEvent [Internal]

メディアの NSFW フラグが変更されたことを示すイベント。

```go
// Subject: avion.media.usage.updated
type NSFWFlagChangedEvent struct {
    Envelope
    Data NSFWFlagChangedData `json:"data"`
}

type NSFWFlagChangedData struct {
    MediaID   string    `json:"media_id"`
    IsNSFW    bool      `json:"is_nsfw"`
    ChangedBy string    `json:"changed_by"` // user_id or system
    ChangedAt time.Time `json:"changed_at"`
}
```

---

### 3.7 avion-timeline

タイムラインの生成と管理に関するイベントを発行します。

#### FanoutCompletedEvent [Internal]

Fan-out 処理が完了したことを示すイベント。

```go
// Subject: avion.timeline.fanout.completed (将来的に定義)
type FanoutCompletedEvent struct {
    Envelope
    Data FanoutCompletedData `json:"data"`
}

type FanoutCompletedData struct {
    DropID         string    `json:"drop_id"`
    TargetCount    int       `json:"target_count"`
    Strategy       string    `json:"strategy"` // fan_out_on_write, fan_out_on_read, hybrid
    CompletedAt    time.Time `json:"completed_at"`
}
```

#### ListCreatedEvent [Internal]

タイムラインリストが作成されたことを示すイベント。

```go
// Subject: avion.timeline.list.created (将来的に定義)
type ListCreatedEvent struct {
    Envelope
    Data ListCreatedData `json:"data"`
}

type ListCreatedData struct {
    ListID    string    `json:"list_id"`
    UserID    string    `json:"user_id"`
    ListName  string    `json:"list_name"`
    CreatedAt time.Time `json:"created_at"`
}
```

#### ListUpdatedEvent [Internal]

タイムラインリストが更新されたことを示すイベント。

```go
// Subject: avion.timeline.list.updated (将来的に定義)
type ListUpdatedEvent struct {
    Envelope
    Data ListUpdatedData `json:"data"`
}

type ListUpdatedData struct {
    ListID    string    `json:"list_id"`
    UserID    string    `json:"user_id"`
    ListName  string    `json:"list_name"`
    UpdatedAt time.Time `json:"updated_at"`
}
```

#### ListDeletedEvent [Internal]

タイムラインリストが削除されたことを示すイベント。

```go
// Subject: avion.timeline.list.deleted (将来的に定義)
type ListDeletedEvent struct {
    Envelope
    Data ListDeletedData `json:"data"`
}

type ListDeletedData struct {
    ListID    string    `json:"list_id"`
    UserID    string    `json:"user_id"`
    DeletedAt time.Time `json:"deleted_at"`
}
```

---

### 3.8 avion-notification

通知の作成と配信に関するイベントを発行します。

#### NotificationCreatedEvent [Internal]

通知が生成されたことを示すイベント。

```go
// Subject: avion.notification.notification.created (将来的に定義)
type NotificationCreatedEvent struct {
    Envelope
    Data NotificationCreatedData `json:"data"`
}

type NotificationCreatedData struct {
    NotificationID string    `json:"notification_id"`
    RecipientID    string    `json:"recipient_id"`
    Type           string    `json:"type"` // follow, mention, reaction, repost, etc.
    ActorID        string    `json:"actor_id"`
    TargetID       string    `json:"target_id,omitempty"`
    CreatedAt      time.Time `json:"created_at"`
}
```

#### NotificationDeliveredEvent [Internal]

通知が配信されたことを示すイベント。

```go
// Subject: avion.notification.notification.delivered (将来的に定義)
type NotificationDeliveredEvent struct {
    Envelope
    Data NotificationDeliveredData `json:"data"`
}

type NotificationDeliveredData struct {
    NotificationID string    `json:"notification_id"`
    RecipientID    string    `json:"recipient_id"`
    Channel        string    `json:"channel"` // sse, web_push, email
    DeliveredAt    time.Time `json:"delivered_at"`
}
```

---

### 3.9 avion-community

コミュニティのライフサイクルとメンバーシップに関するイベントを発行します。

#### CommunityCreatedEvent [Core]

コミュニティが作成されたことを示すイベント。

```go
// Subject: avion.community.group.created
type CommunityCreatedEvent struct {
    Envelope
    Data CommunityCreatedData `json:"data"`
}

type CommunityCreatedData struct {
    CommunityID   string    `json:"community_id"`
    OwnerUserID   string    `json:"owner_user_id"`
    CommunityName string    `json:"community_name"`
    Category      string    `json:"category"`
    Visibility    string    `json:"visibility"` // public, private
    CreatedAt     time.Time `json:"created_at"`
}
```

**購読サービス:** avion-activitypub, avion-search

#### CommunityUpdatedEvent [Core]

コミュニティ情報が更新されたことを示すイベント。

```go
// Subject: avion.community.group.updated
type CommunityUpdatedEvent struct {
    Envelope
    Data CommunityUpdatedData `json:"data"`
}

type CommunityUpdatedData struct {
    CommunityID   string            `json:"community_id"`
    Changes       map[string]string `json:"changes"` // 変更されたフィールドと新しい値
    UpdatedAt     time.Time         `json:"updated_at"`
}
```

**購読サービス:** avion-activitypub, avion-search

#### CommunityEventCreatedEvent [Core]

コミュニティイベントが作成されたことを示すイベント。

```go
// Subject: avion.community.event.created
type CommunityEventCreatedEvent struct {
    Envelope
    Data CommunityEventCreatedData `json:"data"`
}

type CommunityEventCreatedData struct {
    EventID     string    `json:"event_id"`
    CommunityID string    `json:"community_id"`
    Title       string    `json:"title"`
    StartsAt    time.Time `json:"starts_at"`
    CreatedAt   time.Time `json:"created_at"`
}
```

**購読サービス:** avion-notification, avion-activitypub

#### MemberJoinedEvent [Core]

メンバーがコミュニティに参加したことを示すイベント。

```go
// Subject: avion.community.member.joined
type MemberJoinedEvent struct {
    Envelope
    Data MemberJoinedData `json:"data"`
}

type MemberJoinedData struct {
    CommunityID      string    `json:"community_id"`
    UserID           string    `json:"user_id"`
    MembershipStatus string    `json:"membership_status"` // active, pending
    Role             string    `json:"role"`              // member, moderator, admin
    JoinedAt         time.Time `json:"joined_at"`
}
```

**購読サービス:** avion-notification, avion-activitypub

#### MemberLeftEvent [Core]

メンバーがコミュニティから脱退したことを示すイベント。

```go
// Subject: avion.community.member.left
type MemberLeftEvent struct {
    Envelope
    Data MemberLeftData `json:"data"`
}

type MemberLeftData struct {
    CommunityID string    `json:"community_id"`
    UserID      string    `json:"user_id"`
    LeftAt      time.Time `json:"left_at"`
}
```

**購読サービス:** avion-activitypub

---

### 3.10 avion-message

ダイレクトメッセージに関するイベントを発行します。

#### MessageSentEvent [Core]

メッセージが送信されたことを示すイベント。

```go
// Subject: avion.message.message.sent
type MessageSentEvent struct {
    Envelope
    Data MessageSentData `json:"data"`
}

type MessageSentData struct {
    MessageID      string    `json:"message_id"`
    ConversationID string    `json:"conversation_id"`
    SenderID       string    `json:"sender_id"`
    SentAt         time.Time `json:"sent_at"`
}
```

**購読サービス:** avion-notification, avion-search

#### ConversationCreatedEvent [Core]

会話が作成されたことを示すイベント。

```go
// Subject: avion.message.conversation.created
type ConversationCreatedEvent struct {
    Envelope
    Data ConversationCreatedData `json:"data"`
}

type ConversationCreatedData struct {
    ConversationID string   `json:"conversation_id"`
    CreatorID      string   `json:"creator_id"`
    ParticipantIDs []string `json:"participant_ids"`
    CreatedAt      time.Time `json:"created_at"`
}
```

**購読サービス:** avion-notification

#### ConversationUpdatedEvent [Internal]

会話が更新されたことを示すイベント。

```go
// Subject: avion.message.conversation.updated
type ConversationUpdatedEvent struct {
    Envelope
    Data ConversationUpdatedData `json:"data"`
}

type ConversationUpdatedData struct {
    ConversationID string    `json:"conversation_id"`
    UpdatedAt      time.Time `json:"updated_at"`
}
```

#### ConversationDeletedEvent [Internal]

会話が削除されたことを示すイベント。

```go
// Subject: avion.message.conversation.deleted
type ConversationDeletedEvent struct {
    Envelope
    Data ConversationDeletedData `json:"data"`
}

type ConversationDeletedData struct {
    ConversationID string    `json:"conversation_id"`
    DeletedAt      time.Time `json:"deleted_at"`
}
```

#### MessageUpdatedEvent [Internal]

メッセージが編集されたことを示すイベント。

```go
// Subject: avion.message.message.updated
type MessageUpdatedEvent struct {
    Envelope
    Data MessageUpdatedData `json:"data"`
}

type MessageUpdatedData struct {
    MessageID      string    `json:"message_id"`
    ConversationID string    `json:"conversation_id"`
    UpdatedAt      time.Time `json:"updated_at"`
}
```

#### MessageDeletedEvent [Internal]

メッセージが削除されたことを示すイベント。

```go
// Subject: avion.message.message.deleted
type MessageDeletedEvent struct {
    Envelope
    Data MessageDeletedData `json:"data"`
}

type MessageDeletedData struct {
    MessageID      string    `json:"message_id"`
    ConversationID string    `json:"conversation_id"`
    DeletedAt      time.Time `json:"deleted_at"`
}
```

#### ParticipantJoinedEvent [Internal]

会話に参加者が追加されたことを示すイベント。

```go
// Subject: avion.message.participant.joined
type ParticipantJoinedEvent struct {
    Envelope
    Data ParticipantJoinedData `json:"data"`
}

type ParticipantJoinedData struct {
    ConversationID string    `json:"conversation_id"`
    UserID         string    `json:"user_id"`
    JoinedAt       time.Time `json:"joined_at"`
}
```

#### ParticipantLeftEvent [Internal]

会話から参加者が退出したことを示すイベント。

```go
// Subject: avion.message.participant.left
type ParticipantLeftEvent struct {
    Envelope
    Data ParticipantLeftData `json:"data"`
}

type ParticipantLeftData struct {
    ConversationID string    `json:"conversation_id"`
    UserID         string    `json:"user_id"`
    LeftAt         time.Time `json:"left_at"`
}
```

#### DeliveryReadEvent [Internal]

メッセージが既読になったことを示すイベント。

```go
// Subject: avion.message.delivery.read
type DeliveryReadEvent struct {
    Envelope
    Data DeliveryReadData `json:"data"`
}

type DeliveryReadData struct {
    ConversationID string    `json:"conversation_id"`
    UserID         string    `json:"user_id"`
    LastReadAt     time.Time `json:"last_read_at"`
}
```

---

### 3.11 avion-search

検索インデックスに関するイベントを発行します。

#### IndexUpdatedEvent [Internal]

検索インデックスが更新されたことを示すイベント。

```go
// Subject: avion.search.index.updated (将来的に定義)
type IndexUpdatedEvent struct {
    Envelope
    Data IndexUpdatedData `json:"data"`
}

type IndexUpdatedData struct {
    IndexType  string    `json:"index_type"` // drop, user, community
    DocumentID string    `json:"document_id"`
    Action     string    `json:"action"`     // add, update, delete
    UpdatedAt  time.Time `json:"updated_at"`
}
```

#### TrendCalculatedEvent [Future]

トレンド計算が完了したことを示すイベント。

```go
// Subject: avion.search.trend.calculated (将来的に定義)
type TrendCalculatedEvent struct {
    Envelope
    Data TrendCalculatedData `json:"data"`
}

type TrendCalculatedData struct {
    TrendType    string    `json:"trend_type"` // hashtag, topic
    Period       string    `json:"period"`     // hourly, daily
    CalculatedAt time.Time `json:"calculated_at"`
}
```

---

### 3.12 avion-system-admin

システム管理に関するイベントを発行します。管理者操作の通知と設定変更の伝播に使用されます。

#### SystemConfigUpdatedEvent [Core]

システム設定が更新されたことを示すイベント。

```go
// Subject: avion.system.config.updated
type SystemConfigUpdatedEvent struct {
    Envelope
    Data SystemConfigUpdatedData `json:"data"`
}

type SystemConfigUpdatedData struct {
    ConfigKey   string    `json:"config_key"`
    Environment string    `json:"environment"`
    OldValue    string    `json:"old_value,omitempty"`
    NewValue    string    `json:"new_value"`
    AdminID     string    `json:"admin_id"`
    Reason      string    `json:"reason,omitempty"`
    IsCritical  bool      `json:"is_critical"`
    UpdatedAt   time.Time `json:"updated_at"`
}
```

**購読サービス:** avion-gateway, avion-notification

#### AnnouncementCreatedEvent [Core]

アナウンスが作成されたことを示すイベント。

```go
// Subject: avion.system.announcement.created
type AnnouncementCreatedEvent struct {
    Envelope
    Data AnnouncementCreatedData `json:"data"`
}

type AnnouncementCreatedData struct {
    AnnouncementID string    `json:"announcement_id"`
    Title          string    `json:"title"`
    Content        string    `json:"content"`
    TargetType     string    `json:"target_type"` // all, group
    TargetGroupIDs []string  `json:"target_group_ids,omitempty"`
    Priority       string    `json:"priority"` // low, medium, high, critical
    CreatedAt      time.Time `json:"created_at"`
}
```

**購読サービス:** avion-notification, avion-gateway (SSE配信用)

#### RateLimitUpdatedEvent [Internal]

レート制限ルールが更新されたことを示すイベント。

```go
// Subject: avion.system.ratelimit.updated
type RateLimitUpdatedEvent struct {
    Envelope
    Data RateLimitUpdatedData `json:"data"`
}

type RateLimitUpdatedData struct {
    RuleID    string    `json:"rule_id"`
    RuleName  string    `json:"rule_name"`
    Action    string    `json:"action"` // created, updated, deleted
    UpdatedAt time.Time `json:"updated_at"`
}
```

**購読サービス:** avion-gateway

#### BackupCompletedEvent [Internal]

バックアップが完了したことを示すイベント。

```go
// Subject: avion.system.backup.completed
type BackupCompletedEvent struct {
    Envelope
    Data BackupCompletedData `json:"data"`
}

type BackupCompletedData struct {
    BackupID    string    `json:"backup_id"`
    BackupType  string    `json:"backup_type"` // full, incremental
    Status      string    `json:"status"`      // success, partial_failure
    SizeBytes   int64     `json:"size_bytes"`
    CompletedAt time.Time `json:"completed_at"`
}
```

#### MaintenanceActivatedEvent [Core]

メンテナンスモードが有効化されたことを示すイベント。

```go
// Subject: avion.system.maintenance.activated
type MaintenanceActivatedEvent struct {
    Envelope
    Data MaintenanceActivatedData `json:"data"`
}

type MaintenanceActivatedData struct {
    MaintenanceType string    `json:"maintenance_type"` // planned, emergency
    StartTime       time.Time `json:"start_time"`
    ExpectedEndTime time.Time `json:"expected_end_time"`
    Message         string    `json:"message"`
    ActivatedAt     time.Time `json:"activated_at"`
}
```

**購読サービス:** avion-gateway, avion-notification

#### SecurityAlertEvent [Core]

セキュリティアラートが発生したことを示すイベント。

```go
// Subject: avion.system.security.alert
type SecurityAlertEvent struct {
    Envelope
    Data SecurityAlertData `json:"data"`
}

type SecurityAlertData struct {
    AlertType  string    `json:"alert_type"`  // brute_force, privilege_escalation, anomalous_behavior
    Severity   string    `json:"severity"`    // low, medium, high, critical
    TargetID   string    `json:"target_id,omitempty"`
    Details    string    `json:"details"`
    DetectedAt time.Time `json:"detected_at"`
}
```

**購読サービス:** avion-notification

---

## 4. イベントバージョニング戦略

### 4.1 バージョニング方針

イベントスキーマの変更は以下の方針に従います。

| 変更種別 | バージョン | 例 |
|:--|:--|:--|
| **後方互換（フィールド追加）** | バージョン据え置き | 新しい `optional` フィールドの追加 |
| **後方非互換（フィールド削除・型変更）** | バージョンインクリメント | フィールドの削除、型の変更 |
| **新規イベント追加** | 初期バージョン (v1) | 新しいイベントタイプの追加 |

### 4.2 後方互換の維持ルール

1. **フィールドの追加**: 新しいフィールドは常に `omitempty` タグを付与し、Consumer が未知のフィールドを無視できるようにする
2. **フィールドの削除禁止**: Core カテゴリのイベントからフィールドを削除する場合は、非推奨期間（最低 2 リリース）を設ける
3. **型の変更禁止**: 既存フィールドの型変更は行わない。必要な場合は新しいフィールドとして追加する
4. **Consumer の寛容性**: Consumer は未知のフィールドを無視し、未知のイベントタイプをスキップする（Postel's Law）

### 4.3 非推奨フィールドの扱い

```go
type DropCreatedData struct {
    DropID string `json:"drop_id"`
    // Deprecated: AuthorID を使用してください。v3 で削除予定。
    UserID   string `json:"user_id,omitempty"`
    AuthorID string `json:"author_id"`
}
```

### 4.4 バージョン移行の手順

1. 新バージョンのスキーマを定義
2. Producer が新旧両方のフィールドを含むイベントを発行（移行期間）
3. Consumer を新バージョンに対応させる
4. 移行期間終了後、旧フィールドの発行を停止

---

## 5. べき等性保証メカニズム

イベント駆動アーキテクチャにおいて、At-Least-Once 配信では同一イベントが複数回配信される可能性があります。本セクションでは、Avion プラットフォームにおけるべき等性保証の仕組みを定義します。

### 5.1 二重配信防止（Producer 側）

NATS JetStream の重複排除機能を利用して、Producer 側での二重 Publish を防止します。

```go
// EventID を MsgID として設定し、重複排除ウィンドウ内の二重配信を防止
_, err = js.Publish(ctx, subject, data,
    jetstream.WithMsgID(event.EventID),
)
```

- **重複排除ウィンドウ**: 各 Stream で `Duplicates: 2 * time.Minute` に設定（[nats-jetstream-design.md](../infrastructure/nats-jetstream-design.md) 参照）
- **MsgID**: エンベロープの `event_id`（UUID v7）を使用

### 5.2 べき等処理（Consumer 側）

Consumer は以下の戦略で重複メッセージを安全に処理します。

#### 5.2.1 処理済みイベントの追跡

```go
// Consumer 側のべき等処理パターン
func (h *EventHandler) Handle(ctx context.Context, event Event) error {
    // 1. 処理済みチェック（event_id で判定）
    processed, err := h.idempotencyStore.IsProcessed(ctx, event.EventID)
    if err != nil {
        return fmt.Errorf("failed to check idempotency: %w", err)
    }
    if processed {
        // 既に処理済みのため、Ack して終了
        return nil
    }

    // 2. ビジネスロジックの実行
    if err := h.processEvent(ctx, event); err != nil {
        return err
    }

    // 3. 処理済みとして記録
    if err := h.idempotencyStore.MarkProcessed(ctx, event.EventID); err != nil {
        // 記録失敗はログのみ（次回配信時に再処理されても安全な設計）
        slog.Warn("failed to mark event as processed", "event_id", event.EventID)
    }

    return nil
}
```

#### 5.2.2 べき等性の保証方法

| 方法 | 説明 | 使用場面 |
|:--|:--|:--|
| **EventID による重複チェック** | 処理済みの `event_id` を Redis またはデータベースに記録し、二重処理を防止 | 副作用のある処理（通知送信、外部 API 呼び出しなど） |
| **Upsert パターン** | INSERT 時に ON CONFLICT DO UPDATE を使用し、同一データの重複挿入を防止 | データの作成・更新処理 |
| **自然べき等性** | 処理自体が何度実行しても同じ結果になる設計 | キャッシュ無効化、検索インデックス更新など |

#### 5.2.3 べき等性ストアの実装

```go
// Redis を使用したべき等性ストア
type RedisIdempotencyStore struct {
    client *redis.Client
    ttl    time.Duration // 通常 7 日間（Stream の最大保持期間以上）
}

func (s *RedisIdempotencyStore) IsProcessed(ctx context.Context, eventID string) (bool, error) {
    key := fmt.Sprintf("idempotency:%s", eventID)
    exists, err := s.client.Exists(ctx, key).Result()
    return exists > 0, err
}

func (s *RedisIdempotencyStore) MarkProcessed(ctx context.Context, eventID string) error {
    key := fmt.Sprintf("idempotency:%s", eventID)
    return s.client.Set(ctx, key, "1", s.ttl).Err()
}
```

### 5.3 べき等性の判定基準

| イベントカテゴリ | べき等性戦略 | 理由 |
|:--|:--|:--|
| データ作成系（`*.created`） | Upsert + EventID チェック | 重複作成を防止しつつ、リトライを安全に処理 |
| データ更新系（`*.updated`） | 自然べき等性 + 最終更新タイムスタンプ比較 | 古いイベントによる上書きを防止 |
| データ削除系（`*.deleted`） | 自然べき等性 | 存在しないデータの削除は無操作 |
| 通知系 | EventID チェック必須 | 重複通知はユーザー体験を損なう |
| キャッシュ無効化 | 自然べき等性 | 何度無効化しても同じ結果 |

---

## 6. NATS JetStream Subject マッピング

イベントスキーマと NATS JetStream Subject の対応表です。Subject 命名規則の詳細は [nats-jetstream-design.md](../infrastructure/nats-jetstream-design.md) を参照してください。

### 6.1 Subject 命名規則

```
avion.{service}.{aggregate}.{event_type}
```

| セグメント | 説明 | 例 |
|:--|:--|:--|
| `avion` | プラットフォーム共通プレフィクス | `avion` |
| `{service}` | イベント発行元サービス名 | `auth`, `user`, `drop`, `system` |
| `{aggregate}` | ドメインの集約名 | `session`, `profile`, `follow`, `drop` |
| `{event_type}` | イベントの種別 | `created`, `updated`, `deleted` |

### 6.2 全 Subject 一覧

#### avion-drop (Stream: DROP)

| Subject | イベント | カテゴリ |
|:--|:--|:--|
| `avion.drop.drop.created` | DropCreatedEvent | Core |
| `avion.drop.drop.updated` | DropEditedEvent | Core |
| `avion.drop.drop.deleted` | DropDeletedEvent | Core |
| `avion.drop.reaction.created` | ReactionAddedEvent | Core |
| `avion.drop.reaction.deleted` | ReactionRemovedEvent | Core |
| `avion.drop.bookmark.created` | BookmarkAddedEvent | Internal |
| `avion.drop.bookmark.deleted` | BookmarkRemovedEvent | Internal |
| `avion.drop.poll.voted` | PollVotedEvent | Core |
| `avion.drop.poll.closed` | PollClosedEvent | Core |
| `avion.drop.renote.created` | DropRepostedEvent | Core |

#### avion-user (Stream: USER)

| Subject | イベント | カテゴリ |
|:--|:--|:--|
| `avion.user.profile.created` | UserCreatedEvent | Core |
| `avion.user.profile.updated` | UserUpdatedEvent | Core |
| `avion.user.profile.deleted` | UserDeletedEvent | Core |
| `avion.user.follow.created` | FollowCreatedEvent | Core |
| `avion.user.follow.deleted` | FollowRemovedEvent | Core |
| `avion.user.block.created` | UserBlockedEvent | Core |
| `avion.user.block.deleted` | UserUnblockedEvent | Core |
| `avion.user.mute.created` | MuteCreatedEvent | Core |
| `avion.user.mute.deleted` | MuteRemovedEvent | Core |

#### avion-auth (Stream: AUTH)

| Subject | イベント | カテゴリ |
|:--|:--|:--|
| `avion.auth.session.created` | SessionCreatedEvent | Core |
| `avion.auth.session.revoked` | SessionRevokedEvent | Core |
| `avion.auth.role.changed` | RoleAssignedEvent | Core |
| `avion.auth.policy.updated` | PolicyUpdatedEvent | Core |
| `avion.auth.passkey.registered` | PasskeyRegisteredEvent | Internal |
| `avion.auth.account.password_changed` | PasswordChangedEvent | Internal |
| `avion.auth.account.locked` | AccountLockedEvent | Core |
| `avion.auth.security.anomalous_login` | AnomalousLoginDetectedEvent | Core |

#### avion-activitypub (Stream: なし - 直接配信)

ActivityPub イベントは NATS Core（JetStream 非使用）で配信されます。リモートサーバーからのリアルタイム処理が主目的であり、永続化よりも低レイテンシを優先するためです。

| Subject | イベント | カテゴリ |
|:--|:--|:--|
| `avion.activitypub.follow.received` | APFollowReceivedEvent | Core |
| `avion.activitypub.activity.received` | APCreateReceivedEvent | Core |
| `avion.activitypub.block.received` | APBlockReceivedEvent | Core |
| `avion.activitypub.announce.received` | APAnnounceReceivedEvent | Core |

> **注**: 将来的に配信信頼性の要件が高まった場合、ACTIVITYPUB Stream の導入を検討します。

#### avion-moderation (Stream: MODERATION)

| Subject | イベント | カテゴリ |
|:--|:--|:--|
| `avion.moderation.report.created` | ReportCreatedEvent | Core |
| `avion.moderation.action.executed` | ModerationActionExecutedEvent | Core |
| `avion.moderation.filter.updated` | ContentFilterTriggeredEvent | Core |
| `avion.moderation.instance_policy.changed` | InstancePolicyChangedEvent | Core |

#### avion-media (Stream: MEDIA)

| Subject | イベント | カテゴリ |
|:--|:--|:--|
| `avion.media.upload.completed` | MediaUploadCompletedEvent | Core |
| `avion.media.processing.completed` | MediaProcessingCompletedEvent | Internal |
| `avion.media.processing.failed` | MediaProcessingFailedEvent | Internal |
| `avion.media.upload.deleted` | MediaDeletedEvent | Core |
| `avion.media.usage.updated` | NSFWFlagChangedEvent | Internal |

#### avion-message (Stream: MESSAGE)

| Subject | イベント | カテゴリ |
|:--|:--|:--|
| `avion.message.message.sent` | MessageSentEvent | Core |
| `avion.message.message.updated` | MessageUpdatedEvent | Internal |
| `avion.message.message.deleted` | MessageDeletedEvent | Internal |
| `avion.message.conversation.created` | ConversationCreatedEvent | Core |
| `avion.message.conversation.updated` | ConversationUpdatedEvent | Internal |
| `avion.message.conversation.deleted` | ConversationDeletedEvent | Internal |
| `avion.message.participant.joined` | ParticipantJoinedEvent | Internal |
| `avion.message.participant.left` | ParticipantLeftEvent | Internal |
| `avion.message.delivery.read` | DeliveryReadEvent | Internal |

#### avion-community (Stream: COMMUNITY)

| Subject | イベント | カテゴリ |
|:--|:--|:--|
| `avion.community.group.created` | CommunityCreatedEvent | Core |
| `avion.community.group.updated` | CommunityUpdatedEvent | Core |
| `avion.community.event.created` | CommunityEventCreatedEvent | Core |
| `avion.community.member.joined` | MemberJoinedEvent | Core |
| `avion.community.member.left` | MemberLeftEvent | Core |

#### avion-system-admin (Stream: SYSTEM)

| Subject | イベント | カテゴリ |
|:--|:--|:--|
| `avion.system.config.updated` | SystemConfigUpdatedEvent | Core |
| `avion.system.announcement.created` | AnnouncementCreatedEvent | Core |
| `avion.system.ratelimit.updated` | RateLimitUpdatedEvent | Internal |
| `avion.system.backup.completed` | BackupCompletedEvent | Internal |
| `avion.system.maintenance.activated` | MaintenanceActivatedEvent | Core |
| `avion.system.security.alert` | SecurityAlertEvent | Core |

### 6.3 ワイルドカード購読パターン

```
avion.drop.>              # avion-drop の全イベント
avion.drop.drop.*         # Drop 集約の全イベント（created, updated, deleted）
avion.*.*.created         # 全サービスの created イベント（監査用）
avion.user.follow.*       # フォロー関連の全イベント
avion.moderation.>        # モデレーション関連の全イベント
avion.system.>            # システム管理関連の全イベント
avion.auth.>              # 認証関連の全イベント
```

---

## 7. Producer-Consumer マトリクス

各イベントの発行元サービスと購読先サービスの対応関係を示します。

### 7.1 イベントフロー概要

```
Producer (発行) → NATS JetStream → Consumer (購読)
```

### 7.2 サービス別 Consumer マトリクス

以下の表は、各 Consumer サービスがどの Producer のイベントを購読するかを示します。

| Consumer サービス | 購読する Producer イベント |
|:--|:--|
| **avion-timeline** | drop.drop.*, drop.renote.created, user.follow.*, user.block.*, user.mute.*, activitypub.activity.received, activitypub.announce.received |
| **avion-search** | drop.drop.*, user.profile.*, message.message.sent, community.group.created, community.group.updated |
| **avion-notification** | drop.drop.created, drop.drop.updated, drop.reaction.created, drop.poll.*, drop.renote.created, user.follow.created, user.mute.created, auth.session.created, auth.account.locked, auth.security.anomalous_login, auth.role.changed, moderation.report.created, moderation.action.executed, moderation.filter.updated, media.processing.completed, media.processing.failed, message.message.sent, message.conversation.created, community.member.joined, community.event.created, activitypub.follow.received, activitypub.announce.received, system.announcement.created, system.config.updated, system.security.alert, system.maintenance.activated |
| **avion-activitypub** | drop.drop.*, drop.reaction.*, drop.poll.*, drop.renote.created, user.profile.*, user.follow.*, user.block.*, moderation.instance_policy.changed, community.group.*, community.event.created, community.member.* |
| **avion-gateway** | auth.session.*, auth.policy.updated, system.config.updated, system.announcement.created, system.ratelimit.updated, system.maintenance.activated |
| **avion-user** | drop.drop.created, drop.drop.deleted, drop.reaction.*, activitypub.follow.received, activitypub.block.received, moderation.action.executed |
| **avion-drop** | media.upload.completed, activitypub.activity.received, user.profile.deleted, moderation.action.executed |
| **avion-media** | drop.drop.deleted |
| **avion-moderation** | drop.drop.created, user.profile.created |

### 7.3 NATS Consumer Group 名の命名規則

Consumer Group 名は以下の形式に従います。詳細な設定は [nats-jetstream-design.md](../infrastructure/nats-jetstream-design.md) のセクション 4 を参照してください。

```
{consumer-service}-{producer-stream}-consumer
```

例: `timeline-drop-consumer`, `notification-user-consumer`, `gateway-auth-consumer`

---

## まとめ

本ドキュメントにより、以下を実現します。

1. **スキーマの標準化**: 共通エンベロープにより、すべてのイベントが統一的なメタデータを持つ
2. **べき等処理の保証**: `event_id` による重複検出と Consumer 側のべき等性確保（セクション 5 参照）
3. **トレーサビリティ**: `trace_id` による分散トレーシングとイベント追跡
4. **バージョン管理**: 後方互換性を維持しつつ、スキーマの段階的な進化を可能にする
5. **カテゴリ分類**: Core / Internal / Future の分類により、安定性の期待値を明確化
6. **Subject マッピング**: NATS JetStream の Subject とイベントスキーマの一対一対応を保証
7. **Producer-Consumer 可視化**: サービス間のイベントフロー全体像をマトリクスで把握可能
