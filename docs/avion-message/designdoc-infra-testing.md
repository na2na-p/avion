# Design Doc: avion-message - インフラ層実装・テスト戦略

> **本文書は [designdoc.md](./designdoc.md) から分割されたドキュメントです。**
>
> エラーハンドリング、構造化ログ、エラー復旧パターン、Operations & Monitoring、およびテスト戦略に関する詳細設計を記載します。

## 関連ドキュメント

- [designdoc.md](./designdoc.md) - メインDesign Doc（概要、ドメインモデル、API定義、決定事項）
- [designdoc-encryption.md](./designdoc-encryption.md) - E2E暗号化、Signal Protocol、鍵管理、デバイス同期

---

## 1. エラーハンドリング戦略

> **注意:** エラーコードは[エラーコード標準化ガイドライン](../common/errors/error-standards.md)に準拠します。このサービスではプレフィックス `MESSAGE` を使用します。

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
    slog.String("error_code", "MESSAGE_INFRA_MESSAGE_LOSS"),
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
    slog.String("error_code", "MESSAGE_INFRA_DELIVERY_EXHAUSTED"),
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

## 2. エラー復旧パターン

### WebSocket再接続

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

### メッセージ再送

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

### Dead Letter Queue (DLQ) 処理

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
  "error_code": "MESSAGE_INFRA_DELIVERY_EXHAUSTED",
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

## 3. Operations & Monitoring

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
errors_total{type="domain|infra|handler", code="MESSAGE_*"}
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

## 4. テスト計画

### 4.1. ユニットテスト

- ドメインロジックのテスト（85%カバレッジ必須、クリティカルパスは95%）
- 暗号化機能のテスト
- バリデーションロジックのテスト
- リポジトリ層のテスト

### 4.2. 統合テスト

- API エンドポイントのテスト
- WebSocket通信のテスト
- データベース連携テスト
- 外部サービス連携テスト

### 4.3. E2Eテスト

- メッセージ送受信の完全フロー
- グループチャット作成から削除まで
- 暗号化メッセージの送受信
- オフライン/オンライン切り替え

### 4.4. パフォーマンステスト

- 10,000メッセージ/秒の負荷テスト
- 100万同時WebSocket接続テスト
- メッセージ検索のレスポンステスト
- 暗号化処理のベンチマーク

### 4.5. セキュリティテスト

- ペネトレーションテスト
- 暗号化強度の検証
- SQLインジェクション対策確認
- XSS/CSRF対策確認
