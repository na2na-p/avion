# Design Doc: avion-message

**Author:** Claude
**Last Updated:** 2026/03/15

## 関連ドキュメント

- [designdoc-encryption.md](./designdoc-encryption.md) - E2E暗号化、Signal Protocol、鍵管理、暗号化フロー、デバイス同期、セキュリティ考慮事項
- [designdoc-infra-testing.md](./designdoc-infra-testing.md) - インフラ層実装（エラーハンドリング、構造化ログ、エラー復旧パターン）、テスト戦略
- [PRD: avion-message](./prd.md)
- [エラーカタログ](./error-catalog.md)

---

## 1. Summary (これは何？)

- **一言で:** Avionにおけるダイレクトメッセージ（DM）機能、グループチャット、エンドツーエンド暗号化、リアルタイム配信、添付ファイル対応などを提供するマイクロサービスを実装します。
- **目的:** プライベートな会話の作成と管理、メッセージの暗号化送受信、リアルタイム配信、既読管理、メッセージ検索、スパム対策などの包括的なメッセージング機能を提供します。他のサービス（User, Notification, ActivityPubなど）へのイベント通知も行います。

## 2. 用語定義

- **Conversation（会話）**: 2人以上のユーザー間でメッセージを交換するためのコンテナ。1対1またはグループ形式。
- **Message（メッセージ）**: 会話内で送信される個々のコンテンツ。テキスト、画像、ファイルなど。
- **Participant（参加者）**: 会話に参加しているユーザー。役割（owner, admin, member）を持つ。
- **E2E暗号化**: エンドツーエンド暗号化。送信者と受信者のみがメッセージを読める暗号化方式。
- **Signal Protocol**: WhatsAppやSignalで使用される暗号化プロトコル。Forward Secrecyを提供。
- **Double Ratchet**: メッセージごとに暗号化鍵を更新するアルゴリズム。
- **X3DH**: Extended Triple Diffie-Hellman。非同期な鍵交換プロトコル。
- **Message Request**: 未承認ユーザーからのメッセージ。スパム対策機能。
- **Delivery Status**: メッセージの配信状態（sent, delivered, read）。
- **Typing Indicator**: 相手が入力中であることを示すリアルタイム通知。
- **Read Receipt**: 既読通知。メッセージが読まれたことを送信者に通知。
- **Archive**: 会話を非表示にする機能。データは保持される。
- **Forward Secrecy**: 過去の鍵が漏洩しても過去のメッセージが解読できない性質。
- **Searchable Encryption**: 暗号化されたデータを復号せずに検索可能にする技術。

## 3. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

- 個人間およびグループメッセージングのgRPC/WebSocket APIの実装
- Signal Protocolベースのエンドツーエンド暗号化の実装
- メッセージデータのPostgreSQLへの永続化と配信状態管理
- WebSocketによるリアルタイムメッセージ配信
- 既読/未読状態の管理とリアルタイム同期
- タイピングインジケーターのリアルタイム配信
- メッセージの編集・削除機能（時間制限付き）
- 添付ファイル対応（avion-mediaとの連携）
- メッセージリアクション機能
- スパム対策とメッセージリクエスト機能
- 会話のアーカイブ・ミュート機能
- メッセージ検索（検索可能暗号化）
- メッセージエクスポート機能（GDPR対応）
- プレゼンス管理（オンライン/オフライン状態）
- メッセージ送信、配信、既読時のイベント発行（NATS JetStream）
- Go言語で実装し、Kubernetes上でのステートレス運用
- OpenTelemetryによるトレーシング・メトリクス・ロギング対応

### Non-Goals (やらないこと)

- **音声/ビデオ通話:** リアルタイム通信は将来的に別サービスで実装
- **公開チャンネル:** パブリックな会話はavion-dropとavion-communityが担当
- **決済機能:** 送金や支払い機能は実装しない
- **ボット/自動応答:** チャットボット機能は将来的な拡張
- **AIによる内容分析:** E2E暗号化有効時はサーバー側での分析は不可能。サーバーサイド暗号化モードではメタデータ分析のみ許可
- **広告配信:** メッセージ内への広告挿入は行わない
- **メッセージのパブリック公開:** DMは常にプライベート

## 4. User Stories (ユーザーストーリー)

1. **友人とのプライベートな会話**
   - ユーザーAとして、友人Bとプライベートなメッセージを交換したい
   - メッセージは暗号化され、第三者に読まれないようにしたい
   - 相手がメッセージを読んだかどうか確認したい

2. **グループでの計画立て**
   - イベント主催者として、参加者全員とグループチャットで連絡を取りたい
   - ファイルや画像を共有して、詳細を伝えたい
   - 重要なメッセージはピン留めして、後から参照しやすくしたい

3. **ビジネス上の機密情報共有**
   - ビジネスパートナーと機密情報を安全に共有したい
   - メッセージは完全に暗号化され、一定期間後に自動削除されるようにしたい
   - 送信後に誤りに気づいたら、すぐに削除できるようにしたい

4. **海外の友人との多言語コミュニケーション**
   - 異なる言語を話す友人とメッセージを交換したい
   - 自動翻訳機能で、相手の言語でメッセージを理解したい
   - 音声メッセージで発音も確認したい

5. **スパムからの保護**
   - 知らない人からの迷惑メッセージを受け取りたくない
   - メッセージリクエストを確認してから、会話を始めるか決めたい
   - 不適切なユーザーをブロックして、二度と連絡が来ないようにしたい

6. **オフライン時のメッセージ受信**
   - インターネット接続がない時に送られたメッセージも、後で受信したい
   - 重要なメッセージを見逃さないようにしたい
   - 複数デバイスで同じメッセージにアクセスしたい

7. **過去の会話の検索**
   - 数ヶ月前に共有された重要な情報を検索したい
   - 特定の人との会話履歴を簡単に見つけたい
   - 添付ファイルだけをフィルタリングして表示したい

8. **プライバシー重視のコミュニケーション**
   - 既読を付けずにメッセージを読みたい時がある
   - 特定の会話を他人に見られないようアーカイブしたい
   - メッセージの保存期間を自分で設定したい

9. **リアルタイムコラボレーション**
   - 相手が入力中かどうか見て、会話のタイミングを計りたい
   - 位置情報を共有して、待ち合わせをスムーズにしたい
   - リアクションで素早く反応を示したい

10. **データのポータビリティ**
    - 自分のメッセージ履歴をエクスポートして保管したい
    - 他のプラットフォームからメッセージ履歴をインポートしたい
    - アカウント削除時にすべてのメッセージが完全に削除されることを確認したい

11. **ビジネスユーザーとしてのスケジュール送信**
    - 営業時間外に作成したメッセージを翌朝に送信したい
    - 定期的なリマインダーメッセージを自動送信したい
    - タイムゾーンの異なる相手に適切な時間にメッセージを届けたい
    - 予約したメッセージを送信前に編集・キャンセルしたい

12. **システム管理者としてのコンプライアンス対応**
    - 法的要求に基づいてメッセージ内容を調査したい
    - 利用規約違反のメッセージを強制削除したい
    - ユーザーからの通報に迅速に対応したい
    - 監査ログを保持してコンプライアンスを証明したい

13. **効率的な一括操作**
    - 複数のメッセージを一度に削除して整理したい
    - 未読メッセージをまとめて既読にしたい
    - 重要な会話を選択してバックアップしたい
    - 不要な会話を一括でアーカイブしたい

14. **シームレスなマルチデバイス体験**
    - すべてのデバイスで同じメッセージ履歴を見たい
    - スマートフォンで書いた下書きをPCで完成させたい
    - デバイスごとに通知設定をカスタマイズしたい
    - 不要になったデバイスのアクセスを安全に削除したい

## 5. 詳細設計

### 5.1. アーキテクチャ概要

```
┌─────────────────────────────────────────────────────────────┐
│                         Client Apps                         │
│                    (Web, iOS, Android)                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                    WebSocket/HTTPS
                         │
┌────────────────────────┴────────────────────────────────────┐
│                     avion-gateway                           │
│                  (GraphQL + WebSocket)                      │
└────────────────────────┬────────────────────────────────────┘
                         │
                        gRPC
                         │
┌────────────────────────┴────────────────────────────────────┐
│                    avion-message                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                  Handler Layer                        │  │
│  │  - gRPC Handlers                                     │  │
│  │  - WebSocket Handlers                                │  │
│  │  - Event Handlers                                    │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                 UseCase Layer                         │  │
│  │  - SendMessageUseCase                                │  │
│  │  - CreateConversationUseCase                         │  │
│  │  - MarkAsReadUseCase                                 │  │
│  │  - EncryptMessageUseCase                             │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                  Domain Layer                         │  │
│  │  - Message Aggregate                                 │  │
│  │  - Conversation Aggregate                            │  │
│  │  - EncryptionKey Aggregate                          │  │
│  │  - Domain Services                                   │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Infrastructure Layer                     │  │
│  │  - PostgreSQL Repositories                           │  │
│  │  - Redis Cache/Queue                                 │  │
│  │  - WebSocket Manager                                 │  │
│  │  - Event Publisher                                   │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
    PostgreSQL    NATS JetStream    avion-media
   (永続化)      (イベント配信)       (ファイル)
```

### 5.2. データモデル

#### PostgreSQL スキーマ

```sql
-- 会話テーブル
CREATE TABLE conversations (
    id UUID PRIMARY KEY, -- UUID v7 (Backend採番)
    type VARCHAR(20) NOT NULL, -- 'direct', 'group'
    name VARCHAR(100), -- グループ名（グループのみ）
    avatar_url TEXT, -- グループアイコン
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    archived_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    settings JSONB NOT NULL DEFAULT '{}',
    encryption_enabled BOOLEAN NOT NULL DEFAULT true,
    metadata JSONB NOT NULL DEFAULT '{}'
);

-- 参加者テーブル
CREATE TABLE participants (
    id UUID PRIMARY KEY, -- UUID v7 (Backend採番)
    conversation_id UUID NOT NULL REFERENCES conversations(id),
    user_id UUID NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'member', -- 'owner', 'admin', 'member'
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    left_at TIMESTAMPTZ,
    last_read_at TIMESTAMPTZ,
    unread_count INTEGER NOT NULL DEFAULT 0,
    muted_until TIMESTAMPTZ,
    settings JSONB NOT NULL DEFAULT '{}',
    UNIQUE(conversation_id, user_id)
);

-- メッセージテーブル
CREATE TABLE messages (
    id UUID PRIMARY KEY, -- UUID v7 (Backend採番)
    conversation_id UUID NOT NULL REFERENCES conversations(id),
    sender_id UUID NOT NULL,
    type VARCHAR(20) NOT NULL, -- 'text', 'image', 'file', etc.
    content TEXT, -- 平文（サーバーサイド暗号化モードの場合）
    encrypted_content TEXT, -- E2E暗号化されたコンテンツ
    reply_to_id UUID REFERENCES messages(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    edited_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    metadata JSONB NOT NULL DEFAULT '{}'
);

-- メッセージ配信状態テーブル
CREATE TABLE message_deliveries (
    message_id UUID NOT NULL REFERENCES messages(id),
    user_id UUID NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- 'pending', 'sent', 'delivered', 'read'
    delivered_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ,
    PRIMARY KEY (message_id, user_id)
);

-- メッセージリアクションテーブル
CREATE TABLE message_reactions (
    id UUID PRIMARY KEY, -- UUID v7 (Backend採番)
    message_id UUID NOT NULL REFERENCES messages(id),
    user_id UUID NOT NULL,
    emoji VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(message_id, user_id, emoji)
);

-- 暗号化鍵テーブル
CREATE TABLE encryption_keys (
    id UUID PRIMARY KEY, -- UUID v7 (Backend採番)
    user_id UUID NOT NULL,
    device_id VARCHAR(100) NOT NULL,
    public_key TEXT NOT NULL,
    key_fingerprint VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    UNIQUE(user_id, device_id)
);

-- メッセージリクエストテーブル
CREATE TABLE message_requests (
    id UUID PRIMARY KEY, -- UUID v7 (Backend採番)
    sender_id UUID NOT NULL,
    recipient_id UUID NOT NULL,
    initial_message TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ NOT NULL,
    spam_score FLOAT,
    UNIQUE(sender_id, recipient_id)
);

-- 添付ファイルテーブル
CREATE TABLE message_attachments (
    id UUID PRIMARY KEY, -- UUID v7 (Backend採番)
    message_id UUID NOT NULL REFERENCES messages(id),
    file_id UUID NOT NULL, -- avion-mediaのファイルID
    file_name TEXT NOT NULL,
    file_size BIGINT NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    thumbnail_url TEXT,
    order_index INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- スケジュール送信テーブル
CREATE TABLE scheduled_messages (
    id UUID PRIMARY KEY, -- UUID v7 (Backend採番)
    conversation_id UUID NOT NULL REFERENCES conversations(id),
    sender_id UUID NOT NULL,
    content TEXT NOT NULL,
    encrypted_content TEXT,
    scheduled_at TIMESTAMPTZ NOT NULL,
    timezone VARCHAR(50) NOT NULL DEFAULT 'UTC',
    recurrence_rule TEXT, -- RFC 5545 RRULE形式
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- 'pending', 'sent', 'cancelled', 'failed'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sent_at TIMESTAMPTZ,
    metadata JSONB NOT NULL DEFAULT '{}'
);

-- 管理者アクションログテーブル
CREATE TABLE admin_actions (
    id UUID PRIMARY KEY, -- UUID v7 (Backend採番)
    admin_id UUID NOT NULL,
    action_type VARCHAR(50) NOT NULL, -- 'force_delete', 'content_review', 'user_investigation'
    target_type VARCHAR(50) NOT NULL, -- 'message', 'conversation', 'user'
    target_id TEXT NOT NULL,
    reason TEXT NOT NULL,
    legal_reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata JSONB NOT NULL DEFAULT '{}'
);

-- 一括操作履歴テーブル
CREATE TABLE bulk_operations (
    id UUID PRIMARY KEY, -- UUID v7 (Backend採番)
    user_id UUID NOT NULL,
    operation_type VARCHAR(50) NOT NULL, -- 'delete', 'archive', 'mark_read', 'forward', 'export'
    target_count INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- 'pending', 'processing', 'completed', 'failed'
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    error_message TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'
);

-- デバイス管理テーブル
CREATE TABLE user_devices (
    id UUID PRIMARY KEY, -- UUID v7 (Backend採番)
    user_id UUID NOT NULL,
    device_id VARCHAR(100) NOT NULL,
    device_name VARCHAR(100),
    device_type VARCHAR(50), -- 'mobile', 'desktop', 'tablet', 'web'
    platform VARCHAR(50), -- 'ios', 'android', 'windows', 'macos', 'linux', 'web'
    last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sync_enabled BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ,
    UNIQUE(user_id, device_id)
);

-- デバイス同期状態テーブル
CREATE TABLE device_sync_state (
    device_id UUID NOT NULL REFERENCES user_devices(id),
    conversation_id UUID NOT NULL REFERENCES conversations(id),
    last_synced_message_id UUID,
    last_sync_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sync_status VARCHAR(20) NOT NULL DEFAULT 'synced', -- 'synced', 'pending', 'failed'
    PRIMARY KEY (device_id, conversation_id)
);

-- メッセージ下書きテーブル
CREATE TABLE message_drafts (
    id UUID PRIMARY KEY, -- UUID v7 (Backend採番)
    user_id UUID NOT NULL,
    conversation_id UUID NOT NULL REFERENCES conversations(id),
    device_id UUID REFERENCES user_devices(id),
    content TEXT NOT NULL,
    reply_to_id UUID REFERENCES messages(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, conversation_id)
);

-- インデックス
CREATE INDEX idx_participants_user ON participants(user_id);
CREATE INDEX idx_messages_conversation ON messages(conversation_id, created_at DESC);
CREATE INDEX idx_deliveries_user ON message_deliveries(user_id, read_at);
CREATE INDEX idx_reactions_message ON message_reactions(message_id);
CREATE INDEX idx_requests_recipient ON message_requests(recipient_id, status);
CREATE INDEX idx_keys_user ON encryption_keys(user_id, expires_at);
CREATE INDEX idx_user_devices ON user_devices(user_id, last_active_at DESC);
CREATE INDEX idx_device_sync ON device_sync_state(device_id, last_sync_at);
CREATE INDEX idx_messages_conversation_created ON messages(conversation_id, created_at DESC);
CREATE INDEX idx_messages_sender ON messages(sender_id);
CREATE INDEX idx_scheduled_at_status ON scheduled_messages(scheduled_at, status);
CREATE INDEX idx_admin_actions_admin ON admin_actions(admin_id, created_at DESC);
CREATE INDEX idx_bulk_operations_user ON bulk_operations(user_id, created_at DESC);
```

### 5.3. API設計

#### gRPC API定義

```protobuf
syntax = "proto3";

package avion.message.v1;

import "google/protobuf/timestamp.proto";
import "google/protobuf/empty.proto";

service MessageService {
  rpc SendMessage(SendMessageRequest) returns (SendMessageResponse);
  rpc GetMessages(GetMessagesRequest) returns (GetMessagesResponse);
  rpc EditMessage(EditMessageRequest) returns (EditMessageResponse);
  rpc DeleteMessage(DeleteMessageRequest) returns (DeleteMessageResponse);
  rpc MarkAsRead(MarkAsReadRequest) returns (MarkAsReadResponse);
  rpc AddReaction(AddReactionRequest) returns (AddReactionResponse);
  rpc RemoveReaction(RemoveReactionRequest) returns (RemoveReactionResponse);
}

service ConversationService {
  rpc CreateConversation(CreateConversationRequest) returns (CreateConversationResponse);
  rpc GetConversation(GetConversationRequest) returns (GetConversationResponse);
  rpc ListConversations(ListConversationsRequest) returns (ListConversationsResponse);
  rpc AddParticipant(AddParticipantRequest) returns (AddParticipantResponse);
  rpc RemoveParticipant(RemoveParticipantRequest) returns (RemoveParticipantResponse);
  rpc UpdateConversationSettings(UpdateConversationSettingsRequest) returns (UpdateConversationSettingsResponse);
  rpc ArchiveConversation(ArchiveConversationRequest) returns (ArchiveConversationResponse);
}

service EncryptionService {
  rpc RegisterPublicKey(RegisterPublicKeyRequest) returns (RegisterPublicKeyResponse);
  rpc GetPublicKeys(GetPublicKeysRequest) returns (GetPublicKeysResponse);
  rpc RotateKeys(RotateKeysRequest) returns (RotateKeysResponse);
}

service ScheduledMessageService {
  rpc ScheduleMessage(ScheduleMessageRequest) returns (ScheduleMessageResponse);
  rpc UpdateScheduledMessage(UpdateScheduledMessageRequest) returns (UpdateScheduledMessageResponse);
  rpc CancelScheduledMessage(CancelScheduledMessageRequest) returns (CancelScheduledMessageResponse);
  rpc ListScheduledMessages(ListScheduledMessagesRequest) returns (ListScheduledMessagesResponse);
}

service AdminService {
  rpc ForceDeleteMessage(ForceDeleteMessageRequest) returns (ForceDeleteMessageResponse);
  rpc InvestigateMessages(InvestigateMessagesRequest) returns (InvestigateMessagesResponse);
  rpc HandleReportWithDecryptedContent(HandleReportWithDecryptedContentRequest) returns (HandleReportWithDecryptedContentResponse);
  rpc GetAuditLogs(GetAuditLogsRequest) returns (GetAuditLogsResponse);
  rpc HandleUserReport(HandleUserReportRequest) returns (HandleUserReportResponse);
}

service BulkOperationService {
  rpc BulkDeleteMessages(BulkDeleteMessagesRequest) returns (BulkDeleteMessagesResponse);
  rpc BulkArchiveConversations(BulkArchiveConversationsRequest) returns (BulkArchiveConversationsResponse);
  rpc BulkMarkAsRead(BulkMarkAsReadRequest) returns (BulkMarkAsReadResponse);
  rpc BulkForwardMessages(BulkForwardMessagesRequest) returns (BulkForwardMessagesResponse);
}

service DeviceSyncService {
  rpc RegisterDevice(RegisterDeviceRequest) returns (RegisterDeviceResponse);
  rpc ListDevices(ListDevicesRequest) returns (ListDevicesResponse);
  rpc RevokeDevice(RevokeDeviceRequest) returns (RevokeDeviceResponse);
  rpc GetSyncStatus(GetSyncStatusRequest) returns (GetSyncStatusResponse);
  rpc SyncDraft(SyncDraftRequest) returns (SyncDraftResponse);
}

// メッセージ型定義
message Message {
  string id = 1; // UUID v7
  string conversation_id = 2;
  string sender_id = 3;
  MessageType type = 4;
  string content = 5;
  bytes encrypted_content = 6;
  string reply_to_id = 7; // UUID v7
  google.protobuf.Timestamp created_at = 8;
  google.protobuf.Timestamp edited_at = 9;
  repeated Attachment attachments = 10;
  repeated Reaction reactions = 11;
  DeliveryStatus delivery_status = 12;
}

enum MessageType {
  MESSAGE_TYPE_UNSPECIFIED = 0;
  MESSAGE_TYPE_TEXT = 1;
  MESSAGE_TYPE_IMAGE = 2;
  MESSAGE_TYPE_VIDEO = 3;
  MESSAGE_TYPE_AUDIO = 4;
  MESSAGE_TYPE_FILE = 5;
  MESSAGE_TYPE_LOCATION = 6;
}

enum DeliveryStatus {
  DELIVERY_STATUS_UNSPECIFIED = 0;
  DELIVERY_STATUS_PENDING = 1;
  DELIVERY_STATUS_SENT = 2;
  DELIVERY_STATUS_DELIVERED = 3;
  DELIVERY_STATUS_READ = 4;
  DELIVERY_STATUS_FAILED = 5;
}
```

#### WebSocket イベント

```typescript
// クライアント → サーバー
interface ClientEvents {
  "message:send": {
    conversationId: string;
    content: string;
    encryptedContent?: string;
    attachments?: Attachment[];
    replyToId?: string;
  };
  "typing:start": {
    conversationId: string;
  };
  "typing:stop": {
    conversationId: string;
  };
  "message:read": {
    conversationId: string;
    messageIds: string[];
  };
}

// サーバー → クライアント
interface ServerEvents {
  "message:new": {
    message: Message;
  };
  "message:updated": {
    message: Message;
  };
  "message:deleted": {
    messageId: string;
    conversationId: string;
  };
  "typing:update": {
    conversationId: string;
    userId: string;
    isTyping: boolean;
  };
  "message:read:update": {
    conversationId: string;
    userId: string;
    lastReadMessageId: string;
  };
  "presence:update": {
    userId: string;
    status: "online" | "offline" | "away";
    lastSeen?: string;
  };
}
```

### 5.4. E2E暗号化実装

> **詳細は [designdoc-encryption.md](./designdoc-encryption.md) を参照してください。**

### 5.5. スケジュール送信のバッチ処理アーキテクチャ

```go
// スケジュールメッセージプロセッサー
type ScheduledMessageProcessor struct {
    repo        ScheduledMessageRepository
    messageUC   SendMessageUseCase
    ticker      *time.Ticker
}

// バッチ処理実行（1分ごと）
func (p *ScheduledMessageProcessor) ProcessScheduledMessages(ctx context.Context) error {
    // 1. 送信予定のメッセージを取得
    messages, err := p.repo.GetPendingMessages(ctx, time.Now())
    if err != nil {
        return err
    }

    // 2. 並列処理で送信
    var wg sync.WaitGroup
    semaphore := make(chan struct{}, 10) // 同時実行数制限

    for _, msg := range messages {
        wg.Add(1)
        semaphore <- struct{}{}

        go func(scheduled *ScheduledMessage) {
            defer wg.Done()
            defer func() { <-semaphore }()

            // タイムゾーン考慮
            loc, _ := time.LoadLocation(scheduled.Timezone)
            if !p.shouldSendNow(scheduled.ScheduledAt, loc) {
                return
            }

            // メッセージ送信
            if err := p.sendScheduledMessage(ctx, scheduled); err != nil {
                p.handleError(scheduled, err)
                return
            }

            // ステータス更新
            p.repo.UpdateStatus(ctx, scheduled.ID, "sent")

            // 定期送信の場合は次回をスケジュール
            if scheduled.RecurrenceRule != "" {
                p.scheduleNext(ctx, scheduled)
            }
        }(msg)
    }

    wg.Wait()
    return nil
}

// 定期実行設定
func (p *ScheduledMessageProcessor) Start(ctx context.Context) {
    p.ticker = time.NewTicker(1 * time.Minute)
    go func() {
        for {
            select {
            case <-p.ticker.C:
                p.ProcessScheduledMessages(ctx)
            case <-ctx.Done():
                p.ticker.Stop()
                return
            }
        }
    }()
}
```

### 5.6. リアルタイム配信アーキテクチャ

```go
// WebSocketマネージャー
type WebSocketManager struct {
    connections map[string]*WebSocketConnection
    hub         *Hub
    mu          sync.RWMutex
}

// メッセージ配信
func (m *WebSocketManager) DeliverMessage(msg *Message) error {
    // 1. 配信対象の取得
    recipients := m.getRecipients(msg.ConversationID)

    // 2. 並列配信
    var wg sync.WaitGroup
    errors := make(chan error, len(recipients))

    for _, recipientID := range recipients {
        wg.Add(1)
        go func(userID string) {
            defer wg.Done()

            conn := m.getConnection(userID)
            if conn == nil {
                // オフライン: キューに保存
                m.queueOfflineMessage(userID, msg)
                return
            }

            // WebSocket送信
            if err := conn.Send(msg); err != nil {
                errors <- err
            }
        }(recipientID)
    }

    wg.Wait()
    close(errors)

    // エラー処理
    for err := range errors {
        if err != nil {
            return err
        }
    }

    return nil
}
```

### 5.7. WebSocket K8s Pod間接続状態共有

Kubernetes上での複数Pod運用時、WebSocket接続状態をPod間で共有し、メッセージを正しいPodにルーティングする設計です。

#### 接続状態管理（Redis Hash）

```
# Redis Hash: ユーザーの接続先Pod情報
KEY: ws:connections:{user_id}
FIELD: {device_id}
VALUE: {pod_id}
TTL: 300s (ハートビートで延長)

# 例:
HSET ws:connections:user-123 device-abc pod-avion-message-0
HSET ws:connections:user-123 device-def pod-avion-message-2
EXPIRE ws:connections:user-123 300
```

#### メッセージルーティング（NATS JetStream Pod間転送）

```go
// Pod間メッセージルーティング
type PodAwareMessageRouter struct {
    redisClient *redis.Client
    natsConn    *nats.Conn
    localPodID  string
    wsManager   *WebSocketManager
}

// メッセージを受信者の接続先Podに転送
func (r *PodAwareMessageRouter) RouteMessage(ctx context.Context, msg *Message, recipientID string) error {
    // 1. 受信者の接続先Pod情報を取得
    podIDs, err := r.redisClient.HGetAll(ctx, fmt.Sprintf("ws:connections:%s", recipientID)).Result()
    if err != nil {
        return fmt.Errorf("failed to get connection info: %w", err)
    }

    if len(podIDs) == 0 {
        // オフライン: メッセージキューに保存
        return r.queueOfflineMessage(ctx, recipientID, msg)
    }

    // 2. 各デバイスの接続先Podにメッセージを転送
    for deviceID, podID := range podIDs {
        if podID == r.localPodID {
            // ローカルPod: 直接WebSocket配信
            r.wsManager.DeliverToDevice(recipientID, deviceID, msg)
        } else {
            // リモートPod: NATS JetStream経由で転送
            subject := fmt.Sprintf("ws.deliver.%s", podID)
            payload := &PodDeliveryPayload{
                RecipientID: recipientID,
                DeviceID:    deviceID,
                Message:     msg,
            }
            r.natsConn.Publish(subject, payload.Marshal())
        }
    }
    return nil
}

// 他Podからの転送メッセージを受信するサブスクライバー
func (r *PodAwareMessageRouter) StartPodSubscriber(ctx context.Context) error {
    subject := fmt.Sprintf("ws.deliver.%s", r.localPodID)
    _, err := r.natsConn.Subscribe(subject, func(natsMsg *nats.Msg) {
        var payload PodDeliveryPayload
        payload.Unmarshal(natsMsg.Data)
        r.wsManager.DeliverToDevice(payload.RecipientID, payload.DeviceID, payload.Message)
    })
    return err
}
```

#### Pod再起動時の再接続フロー

```
Pod再起動時のフロー:

1. Pod がシャットダウンシグナル (SIGTERM) を受信
2. 既存WebSocket接続にclose frameを送信（code: 1012 Service Restart）
3. Redis Hashから該当Podのエントリを削除
4. Graceful shutdown完了

クライアント側再接続:
1. close frame受信後、Exponential Backoffで再接続を試行
2. 新しいPodに接続（Kubernetes Serviceのロードバランシング）
3. 接続成功時、Redis Hashに新しいPod IDでエントリを登録
4. 未受信メッセージのキャッチアップ（last_received_message_id以降を取得）
```

#### Kubernetes Service設定（Sticky Session）

```yaml
apiVersion: v1
kind: Service
metadata:
  name: avion-message-ws
spec:
  selector:
    app: avion-message
  ports:
    - port: 8085
      targetPort: 8085
      name: websocket
  sessionAffinity: ClientIP
  sessionAffinityConfig:
    clientIP:
      timeoutSeconds: 3600  # 1時間
```

### 5.8. デバイス同期メカニズム

> **詳細は [designdoc-encryption.md](./designdoc-encryption.md) を参照してください。**

### 5.9. 管理者APIのエンドポイント設計

```go
// 管理者権限チェックミドルウェア
func AdminAuthMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // JWTから管理者権限を確認
        claims := r.Context().Value("claims").(*JWTClaims)
        if !claims.IsAdmin {
            http.Error(w, "Forbidden", http.StatusForbidden)
            return
        }

        // 監査ログ記録
        LogAdminAccess(r, claims.UserID)

        next.ServeHTTP(w, r)
    })
}

// 管理者APIハンドラー
type AdminHandler struct {
    messageUC MessageUseCase
    auditUC   AuditUseCase
}

// メッセージ強制削除
func (h *AdminHandler) ForceDeleteMessage(w http.ResponseWriter, r *http.Request) {
    var req ForceDeleteRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, err.Error(), http.StatusBadRequest)
        return
    }

    // 削除理由の必須チェック
    if req.Reason == "" || req.LegalReference == "" {
        http.Error(w, "Reason and legal reference required", http.StatusBadRequest)
        return
    }

    // 削除実行
    adminID := r.Context().Value("userID").(string)
    if err := h.messageUC.ForceDelete(r.Context(), req.MessageID, adminID, req.Reason); err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    // 監査ログ記録
    h.auditUC.LogAction(r.Context(), &AuditLog{
        AdminID:        adminID,
        ActionType:     "force_delete",
        TargetType:     "message",
        TargetID:       req.MessageID,
        Reason:         req.Reason,
        LegalReference: req.LegalReference,
    })

    w.WriteHeader(http.StatusNoContent)
}
```

## 6. 技術的検討事項

### 6.1. パフォーマンス最適化

- **メッセージキャッシュ**: 最新100メッセージをRedisにキャッシュ
- **バッチ処理**: 既読マークや配信状態更新をバッチ化
- **インデックス戦略**: conversation_id + created_at の複合インデックス
- **接続プーリング**: PostgreSQL/Redisの接続プール管理
- **非同期処理**: メッセージ配信を非同期化

### 6.2. スケーラビリティ対策

- **水平分割**: ConversationIDベースでのデータベースシャーディング
- **WebSocketクラスタリング**: NATS JetStreamでクラスタ間同期
- **メッセージキュー**: NATS JetStreamで配信キュー管理
- **負荷分散**: ConsistentHashによるWebSocket接続の分散

### 6.3. 信頼性確保

- **配信保証**: At-least-once配信、重複排除
- **再送メカニズム**: 指数バックオフでの自動再送
- **障害検知**: ヘルスチェックとサーキットブレーカー
- **データバックアップ**: 定期的なPostgreSQLバックアップ

## 7. セキュリティ考慮事項

> **暗号化関連の詳細は [designdoc-encryption.md](./designdoc-encryption.md) を参照してください。**

### セキュリティガイドライン参照

- [SQLインジェクション対策](../common/security/sql-injection-prevention.md)
- [暗号化ガイドライン](../common/security/encryption-guidelines.md)
- [TLS設定](../common/security/tls-configuration.md)
- [XSS対策](../common/security/xss-prevention.md)

## 8. エラーハンドリング戦略

> **詳細は [designdoc-infra-testing.md](./designdoc-infra-testing.md) を参照してください。**

## 9. Operations & Monitoring

> **詳細は [designdoc-infra-testing.md](./designdoc-infra-testing.md) を参照してください。**

## 10. Release Plan

### Phase 1: サーバーサイド暗号化 (at-rest encryption)

**目的:** 管理者が法的要求やユーザー通報に基づいてメッセージ内容を調査可能な状態で、まず安全なメッセージングの基盤をリリースする。

**含まれる機能:**
- 基本的なメッセージ送受信（1対1・グループ）
- WebSocketによるリアルタイム配信
- サーバーサイド暗号化（AES-256-GCM at-rest encryption）
- 既読/未読管理
- タイピングインジケーター
- メッセージリアクション
- 添付ファイル対応
- メッセージ検索（サーバーサイド全文検索）
- 管理者による `InvestigateMessages` RPC（メッセージ内容へのフルアクセス可能）
- スパム対策・メッセージリクエスト機能

**暗号化モデル:**
- 通信路: TLS 1.3
- 保存時: PostgreSQL Transparent Data Encryption + アプリケーション層AES-256-GCM
- サーバーが暗号化鍵を管理 → 法的要求時にメッセージ内容を復号可能

### Phase 2: E2E暗号化のオプトイン

**目的:** プライバシーを重視するユーザー向けに、会話単位でE2E暗号化をオプトインで提供する。

**含まれる機能:**
- Signal Protocolベースのエンドツーエンド暗号化（会話単位でオプトイン）
- X3DH鍵交換、Double Ratchetアルゴリズム
- Forward Secrecy
- マルチデバイス鍵同期
- 暗号化ステータスの可視化（UI上で錠前アイコン表示）
- 検索可能暗号化（クライアントサイドインデックス）

**E2E暗号化有効時の管理者調査制限:**
- `InvestigateMessages` RPC はメタデータのみ返却（送信者、受信者、時刻、メッセージ頻度、添付ファイルの有無・サイズ）
- メッセージ本文へのアクセスは不可

### Phase 1→2 移行戦略

Phase 1（AES-256-GCM at-rest encryption）からPhase 2（libsignal E2E暗号化）への移行時、以下の方針で既存データとの互換性を維持します。

**メッセージ暗号化バージョン管理:**

| `encryption_version` | 暗号化方式 | 説明 |
|:--|:--|:--|
| 1 | AES-256-GCM (at-rest) | Phase 1で作成されたメッセージ。サーバーが鍵を管理 |
| 2 | libsignal E2E | Phase 2以降でE2E暗号化が有効な会話で作成されたメッセージ |

**移行ルール:**
- **既存メッセージ（Phase 1）:** Phase 1のAES-256-GCM暗号化のまま保持する。再暗号化は行わない
- **新規メッセージ（Phase 2以降）:** E2E暗号化がオプトインされた会話では、libsignal E2Eで暗号化する
- **暗号化バージョン識別:** messagesテーブルに `encryption_version` カラム（INTEGER NOT NULL DEFAULT 1）を追加し、メッセージごとに暗号化方式を識別する
- **復号ルーティング:** クライアントは `encryption_version` を参照し、適切な復号パスを選択する
  - `encryption_version = 1`: サーバーから復号済みテキストを受信（従来通り）
  - `encryption_version = 2`: クライアント側でlibsignalを使用して復号

**スキーマ変更:**
```sql
-- Phase 2 移行時に追加
ALTER TABLE messages ADD COLUMN encryption_version INTEGER NOT NULL DEFAULT 1;
-- 1 = AES-256-GCM (at-rest, Phase 1)
-- 2 = libsignal E2E (Phase 2)

CREATE INDEX idx_messages_encryption_version ON messages(encryption_version);
```

### ハイブリッド通報フロー

E2E暗号化が有効な会話でも、ユーザー通報に対応するためにSignal方式のハイブリッドフローを採用します。

```
通報フロー（E2E暗号化有効時）:

1. 被害ユーザーが問題のメッセージを選択して「通報」をタップ
2. クライアントアプリが以下を添付して通報を送信:
   ├─ 復号済みメッセージテキスト（クライアント側で復号したもの）
   ├─ メッセージのメタデータ（送信者ID、時刻、会話ID）
   ├─ 前後のコンテキストメッセージ（任意、通報者が選択）
   └─ 通報理由（ハラスメント、スパム、違法コンテンツ等）
3. サーバーは通報内容を受理し、モデレーションキューに追加
4. モデレーターが通報内容を確認し、対応を決定
   ├─ 該当メッセージの強制削除（メタデータベースで特定）
   ├─ 送信者へのペナルティ（警告、一時停止、アカウント凍結）
   └─ 通報者への結果通知

注意: サーバーはE2E暗号化メッセージを直接復号する能力を持たない。
通報内容の真正性はメタデータとの照合により検証する。
```

**`HandleReportWithDecryptedContent` RPC:**
```protobuf
message HandleReportWithDecryptedContentRequest {
  string reporter_id = 1;
  string conversation_id = 2;
  string reported_message_id = 3;
  string decrypted_content = 4; // クライアントが復号した本文
  repeated string context_message_ids = 5; // コンテキストメッセージID
  repeated string context_decrypted_contents = 6; // コンテキストメッセージの復号本文
  string report_reason = 7;
  string report_category = 8; // harassment, spam, illegal_content, etc.
}

message HandleReportWithDecryptedContentResponse {
  string report_id = 1;
  string status = 2; // accepted, under_review
}
```

## 11. 作業計画

### Phase 1: 基盤実装（2週間）

- [ ] プロジェクト構造のセットアップ
- [ ] データベーススキーマの実装
- [ ] ドメインモデルの実装
- [ ] 基本的なCRUD操作の実装

### Phase 2: メッセージング機能（3週間）

- [ ] メッセージ送受信API実装
- [ ] 会話管理API実装
- [ ] WebSocket接続管理
- [ ] リアルタイム配信実装

### Phase 3: 暗号化実装（3週間）

- [ ] Signal Protocol統合
- [ ] 鍵交換メカニズム
- [ ] メッセージ暗号化/復号化
- [ ] 鍵管理システム

### Phase 4: 高度な機能（2週間）

- [ ] メッセージ検索実装
- [ ] ファイル添付機能
- [ ] リアクション機能
- [ ] タイピングインジケーター

### Phase 5: 最適化とテスト（2週間）

- [ ] パフォーマンス最適化
- [ ] 負荷テスト
- [ ] セキュリティ監査
- [ ] ドキュメント整備

## 12. テスト計画

> **詳細は [designdoc-infra-testing.md](./designdoc-infra-testing.md) を参照してください。**

## 13. その他の検討事項

### 13.1. 移行戦略

- 既存DMシステムからの段階的移行
- データマイグレーションツールの開発
- 並行稼働期間の設定
- ロールバック計画

### 13.2. 運用考慮事項

- 24/7監視体制
- アラート設定（レイテンシ、エラー率）
- 自動スケーリング設定
- バックアップ/リストア手順

### 13.3. 将来の拡張性

- 音声/ビデオ通話統合への準備
- AIアシスタント機能の追加余地
- 他のメッセージングプロトコル対応
- フェデレーション機能の実装

### 13.4. コンプライアンス

- GDPR準拠（データ削除、エクスポート）
- 各国のプライバシー法規制対応
- 暗号化規制への対応
- データ保持ポリシーの策定

## 14. リスクと緩和策

### 14.1. 技術的リスク

| リスク | 影響度 | 発生確率 | 緩和策 |
|--------|--------|----------|--------|
| E2E暗号化の実装複雑性 | 高 | 中 | libsignal (Rust) + CGoバインディングの活用、段階的実装 |
| WebSocketスケーラビリティ | 高 | 中 | クラスタリング、負荷分散の早期実装 |
| メッセージ配信遅延 | 中 | 低 | キャッシュ戦略、非同期処理の最適化 |
| データ喪失 | 高 | 低 | レプリケーション、定期バックアップ |

### 14.2. セキュリティリスク

| リスク | 影響度 | 発生確率 | 緩和策 |
|--------|--------|----------|--------|
| 暗号化鍵の漏洩 | 高 | 低 | HSM使用、鍵ローテーション |
| スパム攻撃 | 中 | 中 | レート制限、機械学習フィルタ |
| DDoS攻撃 | 高 | 低 | CDN活用、レート制限 |
| 内部脅威 | 高 | 低 | 最小権限原則、監査ログ |

### 14.3. ビジネスリスク

| リスク | 影響度 | 発生確率 | 緩和策 |
|--------|--------|----------|--------|
| ユーザー採用の遅れ | 中 | 中 | 段階的ロールアウト、フィードバック収集 |
| 規制変更 | 中 | 低 | 柔軟なアーキテクチャ、法務との連携 |
| 競合他社の機能追加 | 低 | 高 | アジャイル開発、継続的改善 |

## 15. 成功指標

### 15.1. 技術指標

- メッセージ送信成功率: > 99.9%
- 平均配信レイテンシ: < 100ms
- WebSocket接続成功率: > 99.5%
- 暗号化処理時間: < 20ms
- システム稼働率: > 99.95%

### 15.2. ビジネス指標

- DAU（Daily Active Users）: 100万人
- メッセージ送信数: 1000万/日
- グループチャット作成数: 10万/日
- ユーザー満足度: > 4.5/5
- サポート問い合わせ率: < 0.1%

### 15.3. セキュリティ指標

- セキュリティインシデント: 0件/月
- スパムメッセージ率: < 0.01%
- 暗号化メッセージ率: > 95%
- 不正アクセス検知率: > 99%

## 16. 依存関係

### 16.1. 内部サービス

- **avion-auth**: ユーザー認証、JWT検証
- **avion-user**: ユーザー情報、ブロック状態
- **avion-media**: ファイルアップロード、ストレージ
- **avion-notification**: プッシュ通知送信
- **avion-gateway**: クライアント接続管理

### 16.2. 外部ライブラリ

- **libsignal (Rust CGo bindings)**: Signal Protocol実装（Rust製libsignal-ffiをCGoバインディング経由で利用）
  - 参考実装: [gwillem/signal-go](https://github.com/gwillem/signal-go), [Beeper Signal bridge](https://github.com/mautrix/signal) パターン
  - avion-mediaのbimg/libvipsと同様のCGo依存パターンを踏襲
- **gorilla/websocket**: WebSocket通信
- **go-redis/redis**: Redis クライアント
- **jackc/pgx**: PostgreSQL ドライバ
- **grpc-go**: gRPC フレームワーク

### 16.3. インフラストラクチャ

- **PostgreSQL 17**: メッセージデータ永続化
- **Redis 8+**: キャッシュ、キュー
- **Kubernetes**: コンテナオーケストレーション
- **AWS S3互換**: メディアファイルストレージ

## 17. 承認と合意

このDesign Docは以下の関係者によってレビューされ、承認される必要があります：

- [ ] テクニカルリード
- [ ] セキュリティチーム
- [ ] インフラチーム
- [ ] プロダクトマネージャー
- [ ] 法務・コンプライアンス

## 18. 参考資料

- [Signal Protocol Documentation](https://signal.org/docs/)
- [libsignal (Rust)](https://github.com/nicegram/nicegram-libsignal) - Signal Protocol公式Rust実装
- [gwillem/signal-go](https://github.com/gwillem/signal-go) - Go + libsignal FFI参考実装
- [Beeper Signal bridge (mautrix/signal)](https://github.com/mautrix/signal) - GoからlibsignalをCGo経由で利用するパターン
- [Double Ratchet Algorithm Specification](https://signal.org/docs/specifications/doubleratchet/)
- [X3DH Key Agreement Protocol](https://signal.org/docs/specifications/x3dh/)
- [WebSocket Protocol RFC 6455](https://tools.ietf.org/html/rfc6455)
- [Matrix Specification](https://spec.matrix.org/)
- [XMPP Protocol](https://xmpp.org/rfcs/)
- [ActivityPub Specification](https://www.w3.org/TR/activitypub/)
