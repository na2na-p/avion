# Design Doc: avion-message

**Author:** Claude
**Last Updated:** 2025/08/31

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
- メッセージ送信、配信、既読時のイベント発行（Redis Pub/Sub）
- Go言語で実装し、Kubernetes上でのステートレス運用
- OpenTelemetryによるトレーシング・メトリクス・ロギング対応

### Non-Goals (やらないこと)

- **音声/ビデオ通話:** リアルタイム通信は将来的に別サービスで実装
- **公開チャンネル:** パブリックな会話はavion-dropとavion-communityが担当
- **決済機能:** 送金や支払い機能は実装しない
- **ボット/自動応答:** チャットボット機能は将来的な拡張
- **AIによる内容分析:** E2E暗号化のため、サーバー側での分析は不可能
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
    PostgreSQL      Redis Streams    avion-media
   (永続化)      (イベント/キャッシュ)  (ファイル)
```

### 5.2. データモデル

#### PostgreSQL スキーマ

```sql
-- 会話テーブル
CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
    id BIGSERIAL PRIMARY KEY, -- Snowflake ID
    conversation_id UUID NOT NULL REFERENCES conversations(id),
    sender_id UUID NOT NULL,
    type VARCHAR(20) NOT NULL, -- 'text', 'image', 'file', etc.
    content TEXT, -- 平文（E2E暗号化されていない場合）
    encrypted_content TEXT, -- 暗号化されたコンテンツ
    reply_to_id BIGINT REFERENCES messages(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    edited_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    metadata JSONB NOT NULL DEFAULT '{}',
    INDEX idx_conversation_created (conversation_id, created_at DESC),
    INDEX idx_sender (sender_id)
);

-- メッセージ配信状態テーブル
CREATE TABLE message_deliveries (
    message_id BIGINT NOT NULL REFERENCES messages(id),
    user_id UUID NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- 'pending', 'sent', 'delivered', 'read'
    delivered_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ,
    PRIMARY KEY (message_id, user_id)
);

-- メッセージリアクションテーブル
CREATE TABLE message_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id BIGINT NOT NULL REFERENCES messages(id),
    user_id UUID NOT NULL,
    emoji VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(message_id, user_id, emoji)
);

-- 暗号化鍵テーブル
CREATE TABLE encryption_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id BIGINT NOT NULL REFERENCES messages(id),
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
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
    metadata JSONB NOT NULL DEFAULT '{}',
    INDEX idx_scheduled_at (scheduled_at, status)
);

-- 管理者アクションログテーブル
CREATE TABLE admin_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL,
    action_type VARCHAR(50) NOT NULL, -- 'force_delete', 'content_review', 'user_investigation'
    target_type VARCHAR(50) NOT NULL, -- 'message', 'conversation', 'user'
    target_id TEXT NOT NULL,
    reason TEXT NOT NULL,
    legal_reference TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata JSONB NOT NULL DEFAULT '{}',
    INDEX idx_admin_actions (admin_id, created_at DESC)
);

-- 一括操作履歴テーブル
CREATE TABLE bulk_operations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    operation_type VARCHAR(50) NOT NULL, -- 'delete', 'archive', 'mark_read', 'forward', 'export'
    target_count INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- 'pending', 'processing', 'completed', 'failed'
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    error_message TEXT,
    metadata JSONB NOT NULL DEFAULT '{}',
    INDEX idx_bulk_operations_user (user_id, created_at DESC)
);

-- デバイス管理テーブル
CREATE TABLE user_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
    last_synced_message_id BIGINT,
    last_sync_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sync_status VARCHAR(20) NOT NULL DEFAULT 'synced', -- 'synced', 'pending', 'failed'
    PRIMARY KEY (device_id, conversation_id)
);

-- メッセージ下書きテーブル
CREATE TABLE message_drafts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    conversation_id UUID NOT NULL REFERENCES conversations(id),
    device_id UUID REFERENCES user_devices(id),
    content TEXT NOT NULL,
    reply_to_id BIGINT REFERENCES messages(id),
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
```

### 5.3. API設計

#### gRPC API定義

```protobuf
syntax = "proto3";

package avion.message.v1;

import "google/protobuf/timestamp.proto";
import "google/protobuf/empty.proto";

service MessageService {
  // メッセージ送信
  rpc SendMessage(SendMessageRequest) returns (SendMessageResponse);
  
  // メッセージ取得
  rpc GetMessages(GetMessagesRequest) returns (GetMessagesResponse);
  
  // メッセージ編集
  rpc EditMessage(EditMessageRequest) returns (EditMessageResponse);
  
  // メッセージ削除
  rpc DeleteMessage(DeleteMessageRequest) returns (DeleteMessageResponse);
  
  // 既読マーク
  rpc MarkAsRead(MarkAsReadRequest) returns (MarkAsReadResponse);
  
  // リアクション追加
  rpc AddReaction(AddReactionRequest) returns (AddReactionResponse);
  
  // リアクション削除
  rpc RemoveReaction(RemoveReactionRequest) returns (RemoveReactionResponse);
}

service ConversationService {
  // 会話作成
  rpc CreateConversation(CreateConversationRequest) returns (CreateConversationResponse);
  
  // 会話取得
  rpc GetConversation(GetConversationRequest) returns (GetConversationResponse);
  
  // 会話リスト取得
  rpc ListConversations(ListConversationsRequest) returns (ListConversationsResponse);
  
  // 参加者追加
  rpc AddParticipant(AddParticipantRequest) returns (AddParticipantResponse);
  
  // 参加者削除
  rpc RemoveParticipant(RemoveParticipantRequest) returns (RemoveParticipantResponse);
  
  // 会話設定更新
  rpc UpdateConversationSettings(UpdateConversationSettingsRequest) returns (UpdateConversationSettingsResponse);
  
  // 会話アーカイブ
  rpc ArchiveConversation(ArchiveConversationRequest) returns (ArchiveConversationResponse);
}

service EncryptionService {
  // 公開鍵登録
  rpc RegisterPublicKey(RegisterPublicKeyRequest) returns (RegisterPublicKeyResponse);
  
  // 公開鍵取得
  rpc GetPublicKeys(GetPublicKeysRequest) returns (GetPublicKeysResponse);
  
  // 鍵ローテーション
  rpc RotateKeys(RotateKeysRequest) returns (RotateKeysResponse);
}

service ScheduledMessageService {
  // スケジュールメッセージ作成
  rpc ScheduleMessage(ScheduleMessageRequest) returns (ScheduleMessageResponse);
  
  // スケジュールメッセージ更新
  rpc UpdateScheduledMessage(UpdateScheduledMessageRequest) returns (UpdateScheduledMessageResponse);
  
  // スケジュールメッセージキャンセル
  rpc CancelScheduledMessage(CancelScheduledMessageRequest) returns (CancelScheduledMessageResponse);
  
  // スケジュールメッセージ一覧取得
  rpc ListScheduledMessages(ListScheduledMessagesRequest) returns (ListScheduledMessagesResponse);
}

service AdminService {
  // メッセージ強制削除
  rpc ForceDeleteMessage(ForceDeleteMessageRequest) returns (ForceDeleteMessageResponse);
  
  // メッセージ内容調査
  rpc InvestigateMessages(InvestigateMessagesRequest) returns (InvestigateMessagesResponse);
  
  // 監査ログ取得
  rpc GetAuditLogs(GetAuditLogsRequest) returns (GetAuditLogsResponse);
  
  // ユーザー報告対応
  rpc HandleUserReport(HandleUserReportRequest) returns (HandleUserReportResponse);
}

service BulkOperationService {
  // 一括削除
  rpc BulkDeleteMessages(BulkDeleteMessagesRequest) returns (BulkDeleteMessagesResponse);
  
  // 一括アーカイブ
  rpc BulkArchiveConversations(BulkArchiveConversationsRequest) returns (BulkArchiveConversationsResponse);
  
  // 一括既読
  rpc BulkMarkAsRead(BulkMarkAsReadRequest) returns (BulkMarkAsReadResponse);
  
  // 一括転送
  rpc BulkForwardMessages(BulkForwardMessagesRequest) returns (BulkForwardMessagesResponse);
}

service DeviceSyncService {
  // デバイス登録
  rpc RegisterDevice(RegisterDeviceRequest) returns (RegisterDeviceResponse);
  
  // デバイス一覧取得
  rpc ListDevices(ListDevicesRequest) returns (ListDevicesResponse);
  
  // デバイス削除
  rpc RevokeDevice(RevokeDeviceRequest) returns (RevokeDeviceResponse);
  
  // 同期状態取得
  rpc GetSyncStatus(GetSyncStatusRequest) returns (GetSyncStatusResponse);
  
  // 下書き同期
  rpc SyncDraft(SyncDraftRequest) returns (SyncDraftResponse);
}

// メッセージ型定義
message Message {
  int64 id = 1;
  string conversation_id = 2;
  string sender_id = 3;
  MessageType type = 4;
  string content = 5;
  bytes encrypted_content = 6;
  int64 reply_to_id = 7;
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
  // メッセージ送信
  "message:send": {
    conversationId: string;
    content: string;
    encryptedContent?: string;
    attachments?: Attachment[];
    replyToId?: string;
  };
  
  // タイピング通知
  "typing:start": {
    conversationId: string;
  };
  
  // タイピング停止
  "typing:stop": {
    conversationId: string;
  };
  
  // 既読通知
  "message:read": {
    conversationId: string;
    messageIds: string[];
  };
}

// サーバー → クライアント  
interface ServerEvents {
  // 新着メッセージ
  "message:new": {
    message: Message;
  };
  
  // メッセージ更新
  "message:updated": {
    message: Message;
  };
  
  // メッセージ削除
  "message:deleted": {
    messageId: string;
    conversationId: string;
  };
  
  // タイピング通知
  "typing:update": {
    conversationId: string;
    userId: string;
    isTyping: boolean;
  };
  
  // 既読通知
  "message:read:update": {
    conversationId: string;
    userId: string;
    lastReadMessageId: string;
  };
  
  // プレゼンス更新
  "presence:update": {
    userId: string;
    status: "online" | "offline" | "away";
    lastSeen?: string;
  };
}
```

### 5.4. E2E暗号化実装

#### Signal Protocol実装概要

```go
// 鍵交換（X3DH）
type KeyExchange struct {
    IdentityKey    PublicKey
    SignedPreKey   SignedPreKey
    OneTimePreKey  PublicKey
    EphemeralKey   PublicKey
}

// Double Ratchetアルゴリズム
type DoubleRatchet struct {
    RootKey        SymmetricKey
    SendChainKey   ChainKey
    ReceiveChainKey ChainKey
    SendMessageKey  MessageKey
    ReceiveMessageKey MessageKey
}

// メッセージ暗号化
func (e *EncryptionService) EncryptMessage(
    plaintext []byte,
    recipientKeys []PublicKey,
) ([]byte, error) {
    // 1. セッション鍵の導出
    sessionKey := e.deriveSessionKey(recipientKeys)
    
    // 2. AES-GCMで暗号化
    ciphertext, nonce := e.encryptAESGCM(plaintext, sessionKey)
    
    // 3. HMACで認証タグ生成
    authTag := e.generateHMAC(ciphertext, sessionKey)
    
    // 4. Double Ratchetで鍵を更新
    e.ratchetKeys()
    
    return e.packMessage(ciphertext, nonce, authTag), nil
}
```

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

### 5.7. デバイス同期メカニズム

```go
// デバイス同期マネージャー
type DeviceSyncManager struct {
    deviceRepo  DeviceRepository
    messageRepo MessageRepository
    draftRepo   DraftRepository
    syncQueue   *SyncQueue
}

// 新規デバイス登録と初期同期
func (m *DeviceSyncManager) RegisterAndSync(ctx context.Context, userID, deviceID string) error {
    // 1. デバイス登録
    device := &Device{
        UserID:     userID,
        DeviceID:   deviceID,
        DeviceType: m.detectDeviceType(ctx),
        Platform:   m.detectPlatform(ctx),
    }
    if err := m.deviceRepo.Register(ctx, device); err != nil {
        return err
    }
    
    // 2. 既存会話の同期対象選定
    conversations, err := m.getRecentConversations(ctx, userID, 30) // 直近30日
    if err != nil {
        return err
    }
    
    // 3. バッチ同期ジョブをキューに追加
    for _, conv := range conversations {
        job := &SyncJob{
            DeviceID:       deviceID,
            ConversationID: conv.ID,
            SyncType:       "initial",
            Priority:       m.calculatePriority(conv),
        }
        m.syncQueue.Enqueue(job)
    }
    
    // 4. 設定の同期
    return m.syncUserSettings(ctx, userID, deviceID)
}

// リアルタイム同期
func (m *DeviceSyncManager) SyncMessage(ctx context.Context, msg *Message) error {
    // 1. ユーザーの全デバイス取得
    devices, err := m.deviceRepo.GetActiveDevices(ctx, msg.SenderID)
    if err != nil {
        return err
    }
    
    // 2. 送信元デバイス以外に同期
    var wg sync.WaitGroup
    for _, device := range devices {
        if device.ID == msg.DeviceID {
            continue // 送信元はスキップ
        }
        
        wg.Add(1)
        go func(d *Device) {
            defer wg.Done()
            
            // E2E暗号化の場合はデバイス固有の鍵で再暗号化
            if msg.IsEncrypted {
                msg = m.reencryptForDevice(msg, d)
            }
            
            // デバイスに配信
            m.deliverToDevice(ctx, d, msg)
            
            // 同期状態更新
            m.updateSyncState(ctx, d.ID, msg.ConversationID, msg.ID)
        }(device)
    }
    
    wg.Wait()
    return nil
}

// 下書き同期
func (m *DeviceSyncManager) SyncDraft(ctx context.Context, draft *Draft) error {
    devices, err := m.deviceRepo.GetActiveDevices(ctx, draft.UserID)
    if err != nil {
        return err
    }
    
    // 全デバイスに下書きを配信
    for _, device := range devices {
        if device.ID == draft.DeviceID {
            continue
        }
        
        // 下書きをデバイスローカルストレージに保存
        if err := m.draftRepo.SaveForDevice(ctx, device.ID, draft); err != nil {
            continue // エラーは無視して続行
        }
        
        // リアルタイム通知
        m.notifyDraftUpdate(ctx, device.ID, draft)
    }
    
    return nil
}

// 設定同期
type DeviceSettings struct {
    NotificationSettings map[string]interface{}
    MuteSettings        []MutedConversation
    CustomSounds        map[string]string
    Theme              string
    Language           string
}

func (m *DeviceSyncManager) SyncSettings(ctx context.Context, userID string, settings *DeviceSettings) error {
    devices, err := m.deviceRepo.GetActiveDevices(ctx, userID)
    if err != nil {
        return err
    }
    
    // 設定をマスターに保存
    if err := m.saveSettingsToMaster(ctx, userID, settings); err != nil {
        return err
    }
    
    // 全デバイスに配信
    for _, device := range devices {
        m.pushSettingsToDevice(ctx, device, settings)
    }
    
    return nil
}
```

### 5.8. 管理者APIのエンドポイント設計

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
- **WebSocketクラスタリング**: Redis Pub/Subでクラスタ間同期
- **メッセージキュー**: Redis Streamsで配信キュー管理
- **負荷分散**: ConsistentHashによるWebSocket接続の分散

### 6.3. 信頼性確保

- **配信保証**: At-least-once配信、重複排除
- **再送メカニズム**: 指数バックオフでの自動再送
- **障害検知**: ヘルスチェックとサーキットブレーカー
- **データバックアップ**: 定期的なPostgreSQLバックアップ

## 7. セキュリティ考慮事項

### 7.1. 暗号化

- **E2E暗号化**: Signal Protocolの完全実装
- **鍵管理**: 秘密鍵はクライアントのみ保持
- **Forward Secrecy**: メッセージごとの鍵更新
- **暗号化アルゴリズム**: AES-256-GCM + HMAC-SHA256

### 7.2. アクセス制御

- **認証**: JWT認証（avion-authと連携）
- **認可**: 会話参加者のみアクセス可能
- **レート制限**: ユーザー単位での送信制限
- **IPホワイトリスト**: 管理APIへのアクセス制限

### 7.3. データ保護

- **保存時暗号化**: PostgreSQLのTransparent Data Encryption
- **通信暗号化**: TLS 1.3による通信路暗号化
- **ログマスキング**: 個人情報のログ出力禁止
- **監査ログ**: アクセスログの完全記録

### 7.4. スパム対策

- **メッセージリクエスト**: 未承認ユーザーからの隔離
- **スパムスコアリング**: 機械学習によるスパム検出
- **ブロックリスト**: 既知のスパマーのブロック
- **レポート機能**: ユーザー通報システム

## 8. 作業計画

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

## 9. テスト計画

### 9.1. ユニットテスト

- ドメインロジックのテスト（90%カバレッジ目標）
- 暗号化機能のテスト
- バリデーションロジックのテスト
- リポジトリ層のテスト

### 9.2. 統合テスト

- API エンドポイントのテスト
- WebSocket通信のテスト
- データベース連携テスト
- 外部サービス連携テスト

### 9.3. E2Eテスト

- メッセージ送受信の完全フロー
- グループチャット作成から削除まで
- 暗号化メッセージの送受信
- オフライン/オンライン切り替え

### 9.4. パフォーマンステスト

- 10,000メッセージ/秒の負荷テスト
- 100万同時WebSocket接続テスト
- メッセージ検索のレスポンステスト
- 暗号化処理のベンチマーク

### 9.5. セキュリティテスト

- ペネトレーションテスト
- 暗号化強度の検証
- SQLインジェクション対策確認
- XSS/CSRF対策確認

## 10. その他の検討事項

### 10.1. 移行戦略

- 既存DMシステムからの段階的移行
- データマイグレーションツールの開発
- 並行稼働期間の設定
- ロールバック計画

### 10.2. 運用考慮事項

- 24/7監視体制
- アラート設定（レイテンシ、エラー率）
- 自動スケーリング設定
- バックアップ/リストア手順

### 10.3. 将来の拡張性

- 音声/ビデオ通話統合への準備
- AIアシスタント機能の追加余地
- 他のメッセージングプロトコル対応
- フェデレーション機能の実装

### 10.4. コンプライアンス

- GDPR準拠（データ削除、エクスポート）
- 各国のプライバシー法規制対応
- 暗号化規制への対応
- データ保持ポリシーの策定

## 11. リスクと緩和策

### 11.1. 技術的リスク

| リスク | 影響度 | 発生確率 | 緩和策 |
|--------|--------|----------|--------|
| E2E暗号化の実装複雑性 | 高 | 中 | Signal Protocolライブラリの活用、段階的実装 |
| WebSocketスケーラビリティ | 高 | 中 | クラスタリング、負荷分散の早期実装 |
| メッセージ配信遅延 | 中 | 低 | キャッシュ戦略、非同期処理の最適化 |
| データ喪失 | 高 | 低 | レプリケーション、定期バックアップ |

### 11.2. セキュリティリスク

| リスク | 影響度 | 発生確率 | 緩和策 |
|--------|--------|----------|--------|
| 暗号化鍵の漏洩 | 高 | 低 | HSM使用、鍵ローテーション |
| スパム攻撃 | 中 | 中 | レート制限、機械学習フィルタ |
| DDoS攻撃 | 高 | 低 | CDN活用、レート制限 |
| 内部脅威 | 高 | 低 | 最小権限原則、監査ログ |

### 11.3. ビジネスリスク

| リスク | 影響度 | 発生確率 | 緩和策 |
|--------|--------|----------|--------|
| ユーザー採用の遅れ | 中 | 中 | 段階的ロールアウト、フィードバック収集 |
| 規制変更 | 中 | 低 | 柔軟なアーキテクチャ、法務との連携 |
| 競合他社の機能追加 | 低 | 高 | アジャイル開発、継続的改善 |

## 12. 成功指標

### 12.1. 技術指標

- メッセージ送信成功率: > 99.9%
- 平均配信レイテンシ: < 100ms
- WebSocket接続成功率: > 99.5%
- 暗号化処理時間: < 20ms
- システム稼働率: > 99.95%

### 12.2. ビジネス指標

- DAU（Daily Active Users）: 100万人
- メッセージ送信数: 1000万/日
- グループチャット作成数: 10万/日
- ユーザー満足度: > 4.5/5
- サポート問い合わせ率: < 0.1%

### 12.3. セキュリティ指標

- セキュリティインシデント: 0件/月
- スパムメッセージ率: < 0.01%
- 暗号化メッセージ率: > 95%
- 不正アクセス検知率: > 99%

## 13. 依存関係

### 13.1. 内部サービス

- **avion-auth**: ユーザー認証、JWT検証
- **avion-user**: ユーザー情報、ブロック状態
- **avion-media**: ファイルアップロード、ストレージ
- **avion-notification**: プッシュ通知送信
- **avion-gateway**: クライアント接続管理

### 13.2. 外部ライブラリ

- **libsignal-protocol-go**: Signal Protocol実装
- **gorilla/websocket**: WebSocket通信
- **go-redis/redis**: Redis クライアント
- **jackc/pgx**: PostgreSQL ドライバ
- **grpc-go**: gRPC フレームワーク

### 13.3. インフラストラクチャ

- **PostgreSQL 15+**: メッセージデータ永続化
- **Redis 7+**: キャッシュ、キュー、Pub/Sub
- **Kubernetes**: コンテナオーケストレーション
- **AWS S3互換**: メディアファイルストレージ

## 14. 承認と合意

このDesign Docは以下の関係者によってレビューされ、承認される必要があります：

- [ ] テクニカルリード
- [ ] セキュリティチーム
- [ ] インフラチーム
- [ ] プロダクトマネージャー
- [ ] 法務・コンプライアンス

## 15. 参考資料

- [Signal Protocol Documentation](https://signal.org/docs/)
- [Double Ratchet Algorithm Specification](https://signal.org/docs/specifications/doubleratchet/)
- [X3DH Key Agreement Protocol](https://signal.org/docs/specifications/x3dh/)
- [WebSocket Protocol RFC 6455](https://tools.ietf.org/html/rfc6455)
- [Matrix Specification](https://spec.matrix.org/)
- [XMPP Protocol](https://xmpp.org/rfcs/)
- [ActivityPub Specification](https://www.w3.org/TR/activitypub/)