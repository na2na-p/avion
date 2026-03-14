# Design Doc: avion-message

**Author:** Claude
**Last Updated:** 2026/03/14

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

  // メッセージメタデータ調査（E2E暗号化有効時: メタデータのみ）
  rpc InvestigateMessages(InvestigateMessagesRequest) returns (InvestigateMessagesResponse);

  // ユーザー通報によるメッセージ内容調査（Signal方式: クライアントから復号済みメッセージ添付）
  rpc HandleReportWithDecryptedContent(HandleReportWithDecryptedContentRequest) returns (HandleReportWithDecryptedContentResponse);

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

#### libsignal (Rust) + CGo バインディング

E2E暗号化の実装には、Signal公式のRust製ライブラリ `libsignal` をCGoバインディング経由で利用します。Go向けの純粋な実装（`libsignal-protocol-go`）はメンテナンスが不十分であるため、Rust製の公式ライブラリを採用します。

**ビルド要件:**
- Rust toolchain (1.75+): libsignal-ffiのビルドに必要
- CGO_ENABLED=1: CGoバインディングのためGo側でCGoを有効化
- libsignal-ffiの共有ライブラリ (.so / .dylib): ランタイム依存

**Dockerマルチステージビルド:**

```dockerfile
# Stage 1: Rust - libsignal ビルド
FROM rust:1.75 AS signal-builder
WORKDIR /libsignal
RUN git clone --depth 1 --branch v0.x.x https://github.com/nicegram/nicegram-libsignal.git .
RUN cargo build --release -p libsignal-ffi

# Stage 2: Go - アプリケーションビルド
FROM golang:1.25 AS go-builder
WORKDIR /app
COPY --from=signal-builder /libsignal/target/release/libsignal_ffi.so /usr/lib/
COPY --from=signal-builder /libsignal/rust/bridge/ffi/src/signal_ffi.h /usr/include/
COPY . .
RUN CGO_ENABLED=1 go build -o /avion-message ./cmd/server

# Stage 3: ランタイム
FROM debian:bookworm-slim
COPY --from=signal-builder /libsignal/target/release/libsignal_ffi.so /usr/lib/
COPY --from=go-builder /avion-message /usr/local/bin/
RUN ldconfig
CMD ["/usr/local/bin/avion-message"]
```

**CGo依存パターン（avion-mediaのbimg/libvipsと同様）:**
- ビルド時: Rustツールチェーンでlibsignal-ffiをコンパイルし、共有ライブラリを生成
- リンク時: CGoを通じてGoバイナリに動的リンク
- ランタイム: 共有ライブラリをコンテナに含めて配布

**参考実装:**
- [gwillem/signal-go](https://github.com/gwillem/signal-go): Go + libsignal FFIバインディングの実装例
- [Beeper Signal bridge (mautrix/signal)](https://github.com/mautrix/signal): GoアプリケーションからlibsignalをCGo経由で呼び出すブリッジパターン

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

#### マルチデバイス鍵同期

libsignalのSender Key Distribution Messageパターンを採用し、マルチデバイス環境での鍵管理を実現します。

**デバイスごとの独立した鍵ペア:**

各デバイスは独立したIdentity Key Pair、Signed Pre Key、One-Time Pre Keysを生成・管理します。サーバーは各デバイスの公開鍵のみを保持し、秘密鍵はデバイスローカルに保管されます。

```
デバイス鍵構成:

Device A (iPhone)
├── Identity Key Pair (IK_A)
├── Signed Pre Key (SPK_A)
└── One-Time Pre Keys [OPK_A1, OPK_A2, ...]

Device B (Desktop)
├── Identity Key Pair (IK_B)
├── Signed Pre Key (SPK_B)
└── One-Time Pre Keys [OPK_B1, OPK_B2, ...]

サーバーが保持するのは各デバイスの公開鍵のみ。
秘密鍵は各デバイスのローカルストレージに保管。
```

**Sender Key: グループメッセージ用の対称鍵配布:**

グループメッセージでは、送信者が Sender Key を生成し、Sender Key Distribution Message (SKDM) を各参加者の全デバイスに個別に暗号化して配布します。これにより、グループメッセージの暗号化が O(1) で実行可能になります。

```go
// Sender Key配布フロー
type SenderKeyDistribution struct {
    GroupID       string
    SenderID      string
    SenderKey     []byte  // グループメッセージ暗号化用の対称鍵
    ChainID       uint32
    Iteration     uint32
}

// グループメッセージ送信時のSender Key配布
func (e *EncryptionService) DistributeSenderKey(
    ctx context.Context,
    groupID string,
    senderDeviceID string,
    participants []Participant,
) error {
    // 1. Sender Keyを生成
    senderKey := e.generateSenderKey()

    // 2. Sender Key Distribution Message (SKDM) を作成
    skdm := &SenderKeyDistributionMessage{
        GroupID:   groupID,
        SenderKey: senderKey,
        ChainID:   e.nextChainID(),
        Iteration: 0,
    }

    // 3. 各参加者の全デバイスにSKDMを個別暗号化して配布
    for _, participant := range participants {
        devices, _ := e.getDeviceKeys(ctx, participant.UserID)
        for _, device := range devices {
            // デバイスごとのセッションを使って個別に暗号化
            encryptedSKDM := e.encryptForDevice(skdm, device)
            e.deliverSKDM(ctx, participant.UserID, device.DeviceID, encryptedSKDM)
        }
    }
    return nil
}
```

**新デバイス追加時の鍵転送フロー:**

```
新デバイス追加時のフロー:

1. 新デバイスが Identity Key Pair, Signed Pre Key, One-Time Pre Keys を生成
2. 新デバイスが公開鍵をサーバーに登録
3. サーバーが既存デバイスに「新デバイス追加」通知を送信
4. 既存デバイスが新デバイスとX3DH鍵交換を実行
5. 既存デバイスが保有する各グループのSender Keyを
   新デバイス宛に個別暗号化して送信（SKDM経由）
6. 新デバイスがSender Keyを受信し、グループメッセージの復号が可能に

注意:
- 過去のメッセージは新デバイスでは復号不可（Forward Secrecyの原則）
- 新デバイス追加以降のメッセージのみ復号可能
- ユーザーが明示的に「メッセージ履歴の転送」を選択した場合のみ、
  既存デバイスから暗号化された履歴を転送（デバイス間直接通信）
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

## 8. エラーハンドリング戦略

> **注意:** エラーコードは[共通エラーコード標準](../common/errors/error-codes.md)に準拠します。このサービスではプレフィックス `MSG` を使用します。

### エラーコード体系

本サービスは、Avionプラットフォーム標準のエラーコード体系に準拠します。

- **命名規則**: `[SERVICE]_[LAYER]_[ERROR_TYPE]`形式
- **エラーカタログ**: [error-catalog.md](./error-catalog.md)
- **実装ガイド**: [共通エラー実装ガイド](../common/errors/implementation-guide.md)
- **標準仕様**: [エラーコード標準化ガイドライン](../common/errors/error-standards.md)

### ドメインエラーの定義

```go
// domain/error/errors.go
package error

import "errors"

// 会話関連エラー
var (
    ErrConversationNotFound     = errors.New("conversation not found")
    ErrConversationAlreadyExists = errors.New("conversation already exists")
    ErrConversationDeleted      = errors.New("conversation has been deleted")
    ErrConversationArchived     = errors.New("conversation is archived")
    ErrInvalidConversationType  = errors.New("invalid conversation type")
    ErrParticipantLimitExceeded = errors.New("participant limit exceeded")
    ErrDirectConversationFull   = errors.New("direct conversation cannot have more participants")
)

// メッセージ関連エラー
var (
    ErrMessageNotFound       = errors.New("message not found")
    ErrMessageTooLong        = errors.New("message text exceeds maximum length")
    ErrMessageEditExpired    = errors.New("message edit window has expired")
    ErrMessageAlreadyDeleted = errors.New("message has already been deleted")
    ErrEmptyMessageContent   = errors.New("message content cannot be empty")
    ErrInvalidMessageType    = errors.New("invalid message type")
    ErrMessageSendFailed     = errors.New("message send failed")
)

// 参加者関連エラー
var (
    ErrParticipantNotFound    = errors.New("participant not found")
    ErrAlreadyParticipant     = errors.New("user is already a participant")
    ErrNotParticipant         = errors.New("user is not a participant of this conversation")
    ErrCannotRemoveSelf       = errors.New("cannot remove yourself from conversation")
    ErrInsufficientPermission = errors.New("insufficient permission for this action")
    ErrLastAdmin              = errors.New("cannot remove the last admin")
)

// 暗号化関連エラー
var (
    ErrEncryptionKeyNotFound  = errors.New("encryption key not found")
    ErrKeyExpired             = errors.New("encryption key has expired")
    ErrKeyRevoked             = errors.New("encryption key has been revoked")
    ErrDecryptionFailed       = errors.New("message decryption failed")
    ErrKeyExchangeFailed      = errors.New("key exchange failed")
    ErrInvalidKeyFingerprint  = errors.New("invalid key fingerprint")
)

// 配信関連エラー
var (
    ErrDeliveryFailed         = errors.New("message delivery failed")
    ErrWebSocketDisconnected  = errors.New("WebSocket connection disconnected")
    ErrDeliveryTimeout        = errors.New("message delivery timed out")
    ErrDuplicateDelivery      = errors.New("duplicate message delivery")
)

// メッセージリクエスト関連エラー
var (
    ErrRequestNotFound        = errors.New("message request not found")
    ErrRequestAlreadyHandled  = errors.New("message request already handled")
    ErrRequestExpired         = errors.New("message request has expired")
    ErrSpamDetected           = errors.New("message flagged as spam")
    ErrUserBlocked            = errors.New("user has been blocked")
)

// スケジュール送信関連エラー
var (
    ErrScheduledMessageNotFound = errors.New("scheduled message not found")
    ErrScheduleInPast           = errors.New("cannot schedule message in the past")
    ErrScheduleTooFarAhead      = errors.New("schedule time exceeds maximum allowed")
    ErrScheduledAlreadySent     = errors.New("scheduled message has already been sent")
)

// 一括操作関連エラー
var (
    ErrBulkOperationFailed    = errors.New("bulk operation failed")
    ErrBulkLimitExceeded      = errors.New("bulk operation item limit exceeded")
)

// デバイス関連エラー
var (
    ErrDeviceNotFound         = errors.New("device not found")
    ErrDeviceAlreadyRegistered = errors.New("device already registered")
    ErrDeviceRevoked          = errors.New("device has been revoked")
    ErrSyncFailed             = errors.New("device sync failed")
)

// 認可関連エラー
var (
    ErrUnauthorizedAccess     = errors.New("unauthorized access")
    ErrPermissionDenied       = errors.New("permission denied")
    ErrAdminActionDenied      = errors.New("admin action denied")
)
```

### gRPCステータスマッピング

```go
func (h *SendMessageCommandHandler) SendMessage(ctx context.Context, req *pb.SendMessageRequest) (*pb.SendMessageResponse, error) {
    output, err := h.useCase.Execute(ctx, input)
    if err != nil {
        switch {
        // InvalidArgument (400)
        case errors.Is(err, domain.ErrEmptyMessageContent):
            return nil, status.Error(codes.InvalidArgument, "message content cannot be empty")
        case errors.Is(err, domain.ErrMessageTooLong):
            return nil, status.Error(codes.InvalidArgument, "message text exceeds maximum length")
        case errors.Is(err, domain.ErrInvalidMessageType):
            return nil, status.Error(codes.InvalidArgument, "invalid message type")

        // NotFound (404)
        case errors.Is(err, domain.ErrConversationNotFound):
            return nil, status.Error(codes.NotFound, "conversation not found")
        case errors.Is(err, domain.ErrParticipantNotFound):
            return nil, status.Error(codes.NotFound, "participant not found")

        // PermissionDenied (403)
        case errors.Is(err, domain.ErrNotParticipant):
            return nil, status.Error(codes.PermissionDenied, "not a participant of this conversation")
        case errors.Is(err, domain.ErrUserBlocked):
            return nil, status.Error(codes.PermissionDenied, "user has been blocked")
        case errors.Is(err, domain.ErrInsufficientPermission):
            return nil, status.Error(codes.PermissionDenied, "insufficient permission")

        // FailedPrecondition (412)
        case errors.Is(err, domain.ErrConversationDeleted):
            return nil, status.Error(codes.FailedPrecondition, "conversation has been deleted")
        case errors.Is(err, domain.ErrMessageEditExpired):
            return nil, status.Error(codes.FailedPrecondition, "edit window has expired")
        case errors.Is(err, domain.ErrKeyExpired):
            return nil, status.Error(codes.FailedPrecondition, "encryption key has expired")

        // ResourceExhausted (429)
        case errors.Is(err, domain.ErrSpamDetected):
            return nil, status.Error(codes.ResourceExhausted, "message flagged as spam")

        // Unavailable (503)
        case errors.Is(err, domain.ErrDeliveryFailed):
            return nil, status.Error(codes.Unavailable, "message delivery failed, please retry")

        // Internal (500)
        default:
            return nil, status.Error(codes.Internal, "internal server error")
        }
    }
    return response, nil
}
```

### ログレベル使い分け基準

| ログレベル | 用途 | メッセージサービス固有の例 |
|:--|:--|:--|
| **Debug** | 開発・デバッグ用の詳細情報 | WebSocket接続のハンドシェイク詳細、暗号化鍵導出の中間ステップ |
| **Info** | 正常な業務処理の記録 | メッセージ送信成功、会話作成、鍵ローテーション完了 |
| **Warn** | 異常だが自動回復可能な事象 | WebSocket再接続、メッセージ再送トリガー、スパムスコア高め |
| **Error** | 処理失敗で手動対応が必要な事象 | メッセージ配信最終失敗、鍵交換失敗、DB接続断 |
| **CRITICAL** | データ整合性の致命的破壊、即座の対応が必要 | メッセージ喪失検出、暗号化鍵の不整合、配信状態DB不整合 |

```go
// CRITICAL: メッセージ喪失が検出された場合（panicにして処理を停止）
logger.Error("CRITICAL: message loss detected",
    slog.String("trace_id", traceID),
    slog.String("conversation_id", conversationID),
    slog.String("message_id", messageID),
    slog.String("error_code", "MSG_INFRA_MESSAGE_LOSS"),
    slog.String("layer", "infra"),
    slog.Int("expected_count", expectedCount),
    slog.Int("actual_count", actualCount),
)

// Error: メッセージ配信が最大リトライ回数に達して失敗
logger.Error("message delivery permanently failed after max retries",
    slog.String("trace_id", traceID),
    slog.String("message_id", messageID),
    slog.String("recipient_id", recipientID),
    slog.Int("retry_count", maxRetries),
    slog.String("error_code", "MSG_INFRA_DELIVERY_EXHAUSTED"),
    slog.String("layer", "infra"),
)

// Warn: WebSocket再接続が発生
logger.Warn("WebSocket reconnection triggered",
    slog.String("trace_id", traceID),
    slog.String("user_id", userID),
    slog.String("device_id", deviceID),
    slog.String("reason", disconnectReason),
    slog.String("layer", "infra"),
)

// Info: メッセージ送信成功
logger.Info("message sent successfully",
    slog.String("trace_id", traceID),
    slog.String("conversation_id", conversationID),
    slog.String("sender_id", senderID),
    slog.String("message_type", messageType),
    slog.Bool("encrypted", isEncrypted),
    slog.Int64("duration_ms", durationMs),
    slog.String("layer", "usecase"),
)
```

### PIIマスク方針

avion-messageは暗号化メッセージを扱うため、メッセージ内容はログに一切出力しません。マスク対象はメタデータが中心です。

| データ種別 | マスク方針 | 例 |
|:--|:--|:--|
| メッセージ本文 | **絶対にログ出力しない** | - |
| 暗号化コンテンツ | **絶対にログ出力しない** | - |
| 暗号化鍵・秘密鍵 | **絶対にログ出力しない** | - |
| ユーザーID | そのまま出力（内部識別子） | `user_id: "550e8400-..."` |
| メッセージID | そのまま出力（内部識別子） | `message_id: "01234567-..."` |
| IPアドレス | 最後のオクテットをマスク | `192.168.1.xxx` |
| デバイス情報 | デバイスタイプのみ出力 | `device_type: "mobile"` |
| ファイル名 | ハッシュ化 | `file_hash: "sha256:abc..."` |
| 添付ファイルサイズ | そのまま出力 | `file_size: 1048576` |

### エラー復旧パターン

#### WebSocket再接続

```go
// WebSocket再接続のExponential Backoff
type WebSocketReconnectPolicy struct {
    InitialDelay    time.Duration // 1秒
    MaxDelay        time.Duration // 30秒
    BackoffFactor   float64       // 2.0
    MaxRetries      int           // 10
    JitterFactor    float64       // 0.1
}

func (p *WebSocketReconnectPolicy) NextDelay(attempt int) time.Duration {
    if attempt >= p.MaxRetries {
        return 0 // 再接続断念
    }
    delay := float64(p.InitialDelay) * math.Pow(p.BackoffFactor, float64(attempt))
    if delay > float64(p.MaxDelay) {
        delay = float64(p.MaxDelay)
    }
    // Jitter追加
    jitter := delay * p.JitterFactor * (rand.Float64()*2 - 1)
    return time.Duration(delay + jitter)
}
```

#### メッセージ再送

```go
// メッセージ再送ポリシー
type MessageRetryPolicy struct {
    MaxRetries    int           // 5
    InitialDelay  time.Duration // 500ms
    MaxDelay      time.Duration // 30秒
    BackoffFactor float64       // 2.0
}

// 再送フロー:
// 1. 送信失敗検出
// 2. 指数バックオフで再送（最大5回）
// 3. 全リトライ失敗時 → DLQ（Dead Letter Queue）に移動
// 4. DLQのメッセージは手動確認 or 定期バッチで再処理
```

#### Dead Letter Queue (DLQ) 処理

```go
// DLQ処理フロー
// 1. 最大リトライ回数超過のメッセージをDLQに移動
// 2. アラート発報（Error レベル）
// 3. オペレーターが手動確認
// 4. 原因特定後、再処理 or メッセージ破棄
// 5. 送信者に配信失敗通知

type DeadLetterMessage struct {
    OriginalMessageID string
    ConversationID    string
    SenderID          string
    FailureReason     string
    RetryCount        int
    FirstFailedAt     time.Time
    LastFailedAt      time.Time
    Metadata          map[string]interface{}
}
```

### 構造化ログ形式

```json
{
  "timestamp": "2026-01-15T10:30:00Z",
  "level": "ERROR",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "service": "avion-message",
  "layer": "infra",
  "error_code": "MSG_INFRA_DELIVERY_EXHAUSTED",
  "message": "message delivery permanently failed",
  "details": {
    "message_id": "01234567-89ab-cdef-0123-456789abcdef",
    "conversation_id": "fedcba98-7654-3210-fedc-ba9876543210",
    "recipient_id": "aabbccdd-eeff-1122-3344-556677889900",
    "retry_count": 5,
    "last_error": "connection timeout",
    "duration_ms": 30500
  }
}
```

## 9. Operations & Monitoring

### メトリクス (Prometheus形式)

```
# WebSocket接続
ws_active_connections_gauge{node="node-1"}
ws_connections_total{result="success|failure|timeout"}
ws_reconnections_total{reason="client_disconnect|server_error|heartbeat_timeout"}

# メッセージ配信
msg_sent_total{type="text|image|file|audio|video|location", encrypted="true|false"}
msg_delivery_duration_seconds{quantile="0.5|0.9|0.99"}
msg_delivery_status_total{status="delivered|failed|timeout|dlq"}

# E2E暗号化
e2e_key_exchange_total{result="success|failure"}
e2e_key_exchange_duration_seconds{quantile="0.5|0.9|0.99"}
e2e_key_rotation_total{result="success|failure"}
e2e_encryption_duration_seconds{quantile="0.5|0.9|0.99"}

# 会話管理
conversation_created_total{type="direct|group"}
conversation_participants_gauge{conversation_id="..."}

# メッセージリクエスト・スパム
msg_requests_total{status="approved|rejected|expired"}
spam_detected_total{action="quarantine|reject|review"}

# スケジュール送信
scheduled_messages_total{status="pending|sent|cancelled|failed"}
scheduled_message_delay_seconds{quantile="0.5|0.9|0.99"}

# 一括操作
bulk_operations_total{type="delete|archive|mark_read|forward", status="success|failure"}
bulk_operation_duration_seconds{quantile="0.5|0.9|0.99"}

# デバイス同期
device_sync_total{status="success|failure"}
device_sync_duration_seconds{quantile="0.5|0.9|0.99"}
active_devices_gauge{user_id="..."}

# エラー関連
errors_total{type="domain|infra|handler", code="MSG_*"}
dlq_messages_gauge
```

### アラート閾値

| メトリクス | WARN閾値 | CRITICAL閾値 | 対応アクション |
|:--|:--|:--|:--|
| メッセージ配信レイテンシ (p99) | > 500ms | > 2s | スケールアウト、配信キュー確認 |
| WebSocket接続エラー率 | > 1% (5分間) | > 5% (5分間) | ノード健全性確認、LB設定確認 |
| メッセージ配信失敗率 | > 0.1% (5分間) | > 1% (5分間) | DLQ確認、DB接続確認 |
| E2E鍵交換失敗率 | > 2% (5分間) | > 10% (5分間) | 鍵サーバー確認、クライアント互換性 |
| DLQメッセージ数 | > 100 | > 1000 | 手動確認、配信パイプライン調査 |
| WebSocket同時接続数 | > 80% キャパシティ | > 95% キャパシティ | 自動スケールアウト |
| DB接続プール使用率 | > 70% | > 90% | 接続プール拡張、スロークエリ調査 |
| スパム検出率 | > 5% (1時間) | > 15% (1時間) | スパムフィルタ調整、IP制限強化 |
| 暗号化処理時間 (p99) | > 50ms | > 200ms | 暗号化ライブラリ・ハードウェア確認 |
| スケジュール送信遅延 | > 60s | > 300s | バッチプロセッサ確認、リソース増強 |

### インシデント対応フロー

```
1. アラート検知
   └─ PagerDuty/Slack通知
       ├─ CRITICAL → オンコールエンジニアに即座にページ（5分以内に応答必須）
       └─ WARN → Slackチャンネルに通知、営業時間内に対応

2. 初動対応（5分以内）
   ├─ ダッシュボード確認（Grafana）
   ├─ 影響範囲の特定
   │   ├─ 影響ユーザー数
   │   ├─ 影響会話数
   │   └─ エラー種別の特定
   └─ ステータスページ更新（影響あり）

3. 障害切り分け
   ├─ WebSocket層の問題 → ノード再起動、LB再設定
   ├─ メッセージ配信の問題 → DLQ確認、キュー再処理
   ├─ DB層の問題 → コネクション確認、フェイルオーバー
   ├─ 暗号化層の問題 → 鍵サーバー確認、フォールバック
   └─ 外部サービスの問題 → サーキットブレーカー確認

4. 復旧作業
   ├─ 自動復旧：サーキットブレーカー、自動スケーリング
   ├─ 手動復旧：下記「手動回復手順」参照
   └─ DLQ再処理：未配信メッセージの再送

5. 事後対応
   ├─ ポストモーテム作成（24時間以内）
   ├─ 再発防止策の策定
   └─ モニタリング強化
```

### 手動回復手順

#### WebSocket接続の大量切断時

```bash
# 1. 影響ノードの特定
kubectl get pods -l app=avion-message -o wide

# 2. 問題ノードのdrainとrolling restart
kubectl rollout restart deployment/avion-message

# 3. WebSocket接続数の回復確認
kubectl exec -it <pod> -- curl localhost:9090/metrics | grep ws_active_connections

# 4. クライアント側の再接続確認（メトリクス監視）
```

#### DLQ (Dead Letter Queue) メッセージの再処理

```bash
# 1. DLQのメッセージ数確認
nats stream info MSG_DLQ

# 2. DLQメッセージの内容確認（メタデータのみ、本文は暗号化済み）
nats consumer next MSG_DLQ review --count=10

# 3. 原因特定後、再処理可能なメッセージを再送
# （専用CLIツールを使用）
avion-message-cli dlq reprocess --stream=MSG_DLQ --filter="delivery_timeout" --dry-run
avion-message-cli dlq reprocess --stream=MSG_DLQ --filter="delivery_timeout"

# 4. 復旧不可能なメッセージの処理
avion-message-cli dlq discard --stream=MSG_DLQ --filter="permanent_failure" --notify-senders
```

#### 暗号化鍵の不整合修復

```bash
# 1. 不整合検出
avion-message-cli keys verify --user=<user_id>

# 2. 影響を受ける会話の特定
avion-message-cli keys affected-conversations --user=<user_id>

# 3. 鍵の再同期（ユーザーのデバイスに鍵再生成をリクエスト）
avion-message-cli keys request-rekey --user=<user_id> --conversation=<conv_id>
```

#### メッセージ配信状態の整合性修復

```bash
# 1. 不整合の検出
avion-message-cli delivery audit --conversation=<conv_id> --since=24h

# 2. 配信状態の修正
avion-message-cli delivery fix --conversation=<conv_id> --dry-run
avion-message-cli delivery fix --conversation=<conv_id>
```

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

### 12.1. ユニットテスト

- ドメインロジックのテスト（90%カバレッジ必須、クリティカルパスは95%）
- 暗号化機能のテスト
- バリデーションロジックのテスト
- リポジトリ層のテスト

### 12.2. 統合テスト

- API エンドポイントのテスト
- WebSocket通信のテスト
- データベース連携テスト
- 外部サービス連携テスト

### 12.3. E2Eテスト

- メッセージ送受信の完全フロー
- グループチャット作成から削除まで
- 暗号化メッセージの送受信
- オフライン/オンライン切り替え

### 12.4. パフォーマンステスト

- 10,000メッセージ/秒の負荷テスト
- 100万同時WebSocket接続テスト
- メッセージ検索のレスポンステスト
- 暗号化処理のベンチマーク

### 12.5. セキュリティテスト

- ペネトレーションテスト
- 暗号化強度の検証
- SQLインジェクション対策確認
- XSS/CSRF対策確認

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