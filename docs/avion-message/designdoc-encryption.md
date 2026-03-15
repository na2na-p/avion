# Design Doc: avion-message - E2E暗号化・鍵管理・デバイス同期

> **本文書は [designdoc.md](./designdoc.md) から分割されたドキュメントです。**
>
> E2E暗号化（Signal Protocol）、鍵管理、暗号化フロー、マルチデバイス鍵同期、デバイス同期メカニズム、セキュリティ考慮事項に関する詳細設計を記載します。

## 関連ドキュメント

- [designdoc.md](./designdoc.md) - メインDesign Doc（概要、ドメインモデル、API定義、決定事項）
- [designdoc-infra-testing.md](./designdoc-infra-testing.md) - インフラ層実装、テスト戦略

---

## 1. E2E暗号化実装

### libsignal (Rust) + CGo バインディング

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

### Signal Protocol実装概要

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

## 2. マルチデバイス鍵同期

libsignalのSender Key Distribution Messageパターンを採用し、マルチデバイス環境での鍵管理を実現します。

### デバイスごとの独立した鍵ペア

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

### Sender Key: グループメッセージ用の対称鍵配布

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

### 新デバイス追加時の鍵転送フロー

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

## 3. デバイス同期メカニズム

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

## 4. セキュリティ考慮事項

### 4.1. 暗号化

- **E2E暗号化**: Signal Protocolの完全実装
- **鍵管理**: 秘密鍵はクライアントのみ保持
- **Forward Secrecy**: メッセージごとの鍵更新
- **暗号化アルゴリズム**: AES-256-GCM + HMAC-SHA256

### 4.2. アクセス制御

- **認証**: JWT認証（avion-authと連携）
- **認可**: 会話参加者のみアクセス可能
- **レート制限**: ユーザー単位での送信制限
- **IPホワイトリスト**: 管理APIへのアクセス制限

### 4.3. データ保護

- **保存時暗号化**: PostgreSQLのTransparent Data Encryption
- **通信暗号化**: TLS 1.3による通信路暗号化
- **ログマスキング**: 個人情報のログ出力禁止
- **監査ログ**: アクセスログの完全記録

### 4.4. スパム対策

- **メッセージリクエスト**: 未承認ユーザーからの隔離
- **スパムスコアリング**: 機械学習によるスパム検出
- **ブロックリスト**: 既知のスパマーのブロック
- **レポート機能**: ユーザー通報システム
