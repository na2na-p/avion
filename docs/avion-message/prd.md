# PRD: avion-message

## 概要

Avionにおけるダイレクトメッセージ（DM）機能を提供するマイクロサービスを実装する。個人間およびグループでのプライベートメッセージング、エンドツーエンド暗号化、リアルタイム配信、メッセージ履歴管理、添付ファイル対応など、現代的なメッセージングプラットフォームに必要な包括的な機能を統合的に提供する。

## 背景

SNSプラットフォームにおいて、パブリックな投稿とは別に、プライベートなコミュニケーションチャネルは必須の機能である。ユーザー間の信頼関係構築、コミュニティ形成、ビジネス連携など、様々な用途でダイレクトメッセージが活用される。プライバシーとセキュリティを最優先しつつ、リアルタイム性と利便性を両立させるメッセージングサービスが求められている。

avion-dropが公開投稿を管理するのに対し、avion-messageはプライベートな会話を管理する。この分離により、異なるセキュリティ要件とスケーリング戦略を適用でき、それぞれの特性に最適化された実装が可能となる。特にE2E暗号化や会話の永続性、配信保証など、メッセージング特有の要件に特化した設計が実現できる。

## Scientific Merits

*   **スケーラビリティ:** メッセージ量の増加に対して、`avion-message` サービスを独立してスケールさせることが可能。1秒間に10,000メッセージの送受信を処理し、100万同時接続をサポート。水平スケーリングにより、ピーク時には50,000メッセージ/秒まで対応可能。
*   **高パフォーマンス:** メッセージ送信レイテンシp50 < 100ms、p99 < 500msを実現。WebSocketによるリアルタイム配信で95%のメッセージを200ms以内に配信。メッセージ検索を50ms以下で実行し、会話履歴の高速表示を実現。
*   **高可用性:** 99.95%の稼働率を保証し、ダウンタイム月2.2時間以内を維持。Kubernetesマルチレプリカ構成とメッセージキューによる配信保証。オフライン時のメッセージバッファリングにより、接続復帰時の100%配信を保証。
*   **データ整合性:** メッセージの順序保証とat-least-once配信を実現し、メッセージ喪失率0.001%以下を維持。分散トランザクションによる会話状態の一貫性保証。既読状態の最終的整合性を5秒以内に達成。
*   **プライバシー保護:** E2E暗号化により、サーバー側でもメッセージ内容を読めない完全なプライバシー保護を実現。前方秘匿性（Forward Secrecy）により過去のメッセージの安全性を保証。メッセージの自動削除機能により、GDPR準拠100%を達成。
*   **リアルタイム性:** WebSocketとServer-Sent Eventsの併用により、99%のメッセージをリアルタイム配信。タイピングインジケーターと既読通知を100ms以内に伝播。プレゼンス状態（オンライン/オフライン）を1秒以内に反映。
*   **検索効率:** メッセージ全文検索を100ms以内で実行。暗号化メッセージの検索可能暗号化（Searchable Encryption）により、プライバシーを保ちながら高速検索を実現。会話のコンテキスト検索により関連メッセージを効率的に発見。
*   **ストレージ最適化:** メッセージの階層的アーカイブにより、アクティブデータのアクセス速度を維持しながらストレージコストを70%削減。メディアファイルの重複排除により、ストレージ使用量を30%削減。
*   **相互運用性:** ActivityPubプロトコルによる他インスタンスとのメッセージ交換をサポート。標準的なメッセージングプロトコル（XMPP互換）により、サードパーティクライアントとの連携を実現。

## Design Doc

[Design Doc: avion-message](./designdoc.md)

## 参考ドキュメント

*   [Avion アーキテクチャ概要](./../common/architecture.md)
*   [Signal Protocol Specification](https://signal.org/docs/)
*   [Matrix Specification](https://spec.matrix.org/)
*   [RFC 7519: JSON Web Token (JWT)](https://tools.ietf.org/html/rfc7519)
*   [RFC 6455: The WebSocket Protocol](https://tools.ietf.org/html/rfc6455)
*   [GDPR Compliance Guidelines](https://gdpr.eu/)
*   [Double Ratchet Algorithm](https://signal.org/docs/specifications/doubleratchet/)
*   [X3DH Key Agreement Protocol](https://signal.org/docs/specifications/x3dh/)

## 製品原則

*   **プライバシーファースト:** エンドツーエンド暗号化をデフォルトとし、ユーザーのプライベートな会話を完全に保護。メッセージ内容はサーバー側でも読めず、メタデータの収集も最小限に抑える。
*   **信頼性の確保:** メッセージの確実な配信を保証し、オフライン時でも後から受信可能。順序保証と重複排除により、会話の一貫性を維持。障害時も自動リトライで配信を完遂。
*   **リアルタイム体験:** 低レイテンシのメッセージ配信により、対面会話に近い自然な体験を提供。タイピングインジケーターや既読通知により、相手の状態を即座に把握可能。
*   **直感的な操作性:** シンプルで分かりやすいUIにより、技術に詳しくないユーザーでも安心して利用可能。会話の検索、フィルタリング、アーカイブなどの機能を直感的に操作できる。
*   **柔軟な会話形式:** 1対1の会話からグループチャットまで、様々な形式のコミュニケーションをサポート。音声メッセージ、ファイル共有、位置情報共有など、多様な表現手段を提供。
*   **データ主権の尊重:** ユーザーが自身のメッセージデータを完全にコントロール可能。エクスポート、削除、保存期間の設定など、データのライフサイクルをユーザーが決定。
*   **スパム対策の徹底:** 未承認のメッセージ送信を防ぎ、スパムやハラスメントから利用者を保護。機械学習によるスパム検出と、ユーザー報告システムの組み合わせで安全な環境を維持。
*   **アクセシビリティ重視:** スクリーンリーダー対応、キーボードナビゲーション、高コントラストモードなど、すべてのユーザーが平等にメッセージング機能を利用できる設計。

## やること/やらないこと

### やること

*   個人間メッセージ送受信
    - テキストメッセージの送信・受信
    - 絵文字リアクション機能
    - メッセージの引用返信
    - メッセージ転送機能
    - 送信取り消し機能（時間制限付き）
*   グループメッセージ機能
    - グループ作成・管理（最大100人）
    - メンバー招待・退出・除外
    - グループ名・アイコン設定
    - 管理者権限の付与・剥奪
    - グループ設定（参加承認制、メッセージ削除権限等）
*   エンドツーエンド暗号化（E2E）
    - Signal Protocolベースの実装
    - 鍵交換と管理（X3DH）
    - Forward Secrecy（前方秘匿性）
    - デバイス間の鍵同期
    - 暗号化状態の可視化
*   既読/未読管理
    - 既読マーカーの送信・表示
    - 未読数カウント
    - 既読者リスト表示（グループ）
    - 既読通知のオン/オフ設定
*   タイピングインジケーター
    - リアルタイムタイピング状態の送信
    - 複数人の同時タイピング表示
    - タイピングタイムアウト処理
*   メッセージ検索
    - 会話内全文検索
    - 送信者・日付でのフィルタリング
    - 添付ファイル種別での検索
    - 検索可能暗号化（クライアントサイド）
*   添付ファイル対応
    - 画像・動画・音声ファイルの送受信
    - ドキュメントファイルの共有
    - ファイルサイズ制限（100MB）
    - サムネイル自動生成
    - ウイルススキャン連携
*   メッセージの編集・削除
    - 送信後15分以内の編集
    - メッセージ削除（自分のみ/全員）
    - 編集履歴の表示
    - 削除メッセージの痕跡表示
*   メッセージリアクション
    - 絵文字リアクションの追加・削除
    - カスタム絵文字対応
    - リアクション通知
    - リアクション集計表示
*   通知設定
    - 会話単位のミュート設定
    - 通知音のカスタマイズ
    - Do Not Disturb設定
    - メンション通知の優先度設定
*   スパム対策
    - メッセージリクエスト機能
    - スパムフィルタリング
    - ユーザーブロック連携
    - 通報機能
*   メッセージアーカイブ
    - 会話のアーカイブ・復元
    - 自動アーカイブ設定
    - アーカイブ済み会話の検索
*   メッセージエクスポート
    - JSON/CSV形式でのエクスポート
    - メディアファイル含む完全バックアップ
    - 暗号化エクスポート
*   プレゼンス管理
    - オンライン/オフライン状態
    - 最終既読時刻
    - カスタムステータス設定
*   音声/ビデオメッセージ
    - 音声メッセージの録音・送信
    - ビデオメッセージの録画・送信
    - 再生速度調整
    - 自動文字起こし（オプション）
*   位置情報共有
    - 現在地の共有
    - ライブロケーション共有
    - 地図プレビュー表示
*   メッセージ翻訳
    - 自動翻訳機能
    - 言語検出
    - 原文/翻訳文の切り替え表示
*   一時的メッセージ
    - 自動削除タイマー設定
    - スクリーンショット検出通知
    - 閲覧回数制限
*   メッセージピン留め
    - 重要メッセージのピン留め
    - ピン留めメッセージ一覧
    - グループでの共有ピン留め
*   スケジュール送信機能
    - メッセージの予約送信（最大30日先まで）
    - 予約メッセージの編集・キャンセル
    - 予約メッセージ一覧表示
    - タイムゾーン対応
    - 定期送信設定（毎日/毎週/毎月）
*   管理者機能
    - システム管理者によるメッセージの強制削除
    - コンプライアンス監査ログ
    - 不適切コンテンツの一括削除
    - ユーザー報告への対応機能
    - メッセージ内容の検査（法的要求時のみ）
    - 違反ユーザーのメッセージ履歴調査
*   一括操作機能
    - メッセージの一括選択・削除
    - 会話の一括アーカイブ
    - 未読メッセージの一括既読
    - 複数メッセージの一括転送
    - 複数会話への同時送信
    - 選択メッセージのエクスポート
*   デバイス同期の強化
    - マルチデバイスでのメッセージ完全同期
    - デバイス間での下書き同期
    - 設定の同期（ミュート、通知設定、カスタマイズ等）
    - デバイス管理画面（接続デバイス一覧、削除、名前設定）
    - デバイス固有の暗号化鍵管理
    - 新規デバイス追加時の既存メッセージ同期

### やらないこと

*   **公開チャンネル機能:** パブリックな会話はavion-dropとavion-communityが担当。
*   **音声/ビデオ通話:** リアルタイム通信は将来的に別サービスで実装予定。
*   **決済機能:** 送金や支払い機能は実装しない。
*   **ボット/自動応答:** チャットボット機能は将来的な拡張として検討。
*   **メッセージのパブリック公開:** DMは常にプライベートな会話として扱う。
*   **広告配信:** メッセージ内への広告挿入は行わない。
*   **AIによる内容分析:** E2E暗号化のため、サーバー側でのメッセージ内容分析は不可能。

## 対象ユーザー

*   Avion エンドユーザー (API Gateway経由)
*   Avion の他のマイクロサービス (User, Notification, ActivityPubなど)
*   Avion 開発者・運用者

## ドメインモデル (DDD戦術的パターン)

### Aggregates (集約)

#### Conversation Aggregate
**責務**: 会話のライフサイクルと参加者を管理する中核的な集約
- **集約ルート**: Conversation
- **不変条件**:
  - ConversationIDは変更不可
  - 参加者は最低1人、最大100人（グループの場合）
  - 1対1会話は参加者の追加不可
  - 削除された会話は復元不可
  - E2E暗号化が有効な場合は無効化不可
- **ドメインロジック**:
  - `canSendMessage(senderID)`: メッセージ送信権限の判定
  - `canAddParticipant(inviterID, inviteeID)`: 参加者追加権限の判定
  - `canRemoveParticipant(removerID, targetID)`: 参加者削除権限の判定
  - `shouldEncrypt()`: 暗号化要否の判定
  - `archive()`: 会話のアーカイブ処理
  - `mute(duration)`: 通知のミュート設定
  - `updateSettings()`: 会話設定の更新
  - `calculateUnreadCount(userID)`: 未読数の計算

#### Message Aggregate
**責務**: 個々のメッセージとその配信状態を管理
- **集約ルート**: Message
- **不変条件**:
  - MessageIDは変更不可
  - SenderIDは変更不可
  - 送信時刻は変更不可
  - 暗号化されたメッセージは復号なしに編集不可
  - 削除されたメッセージは復元不可
  - 編集は送信後15分以内のみ
- **ドメインロジック**:
  - `canBeEditedBy(userID, currentTime)`: 編集権限の判定
  - `canBeDeletedBy(userID)`: 削除権限の判定
  - `encrypt(publicKey)`: メッセージの暗号化
  - `addReaction(userID, emoji)`: リアクション追加
  - `markAsRead(userID)`: 既読マーク
  - `shouldNotify(userSettings)`: 通知要否の判定
  - `toActivityPubNote()`: ActivityPub形式への変換

#### Participant Aggregate
**責務**: 会話参加者の権限と状態を管理
- **集約ルート**: Participant
- **不変条件**:
  - UserIDとConversationIDの組み合わせは一意
  - 管理者は最低1人必要（グループの場合）
  - 退出した参加者は再参加時に新規扱い
- **ドメインロジック**:
  - `hasPermission(action)`: 権限チェック
  - `updateRole(role)`: ロール更新
  - `updateLastRead()`: 最終既読位置更新
  - `leave()`: 会話から退出
  - `rejoin()`: 会話に再参加

#### EncryptionKey Aggregate
**責務**: E2E暗号化の鍵を管理
- **集約ルート**: EncryptionKey
- **不変条件**:
  - 秘密鍵は絶対にサーバーに保存しない
  - 公開鍵は改竄不可
  - 鍵の有効期限切れ後は使用不可
- **ドメインロジック**:
  - `rotateKeys()`: 鍵のローテーション
  - `deriveSessionKey()`: セッション鍵の導出
  - `validateSignature()`: 署名検証
  - `isExpired()`: 有効期限チェック

#### MessageRequest Aggregate
**責務**: 未承認のメッセージリクエストを管理
- **集約ルート**: MessageRequest
- **不変条件**:
  - 承認/拒否後は変更不可
  - スパム判定されたリクエストは自動拒否
  - 有効期限切れ後は自動削除
- **ドメインロジック**:
  - `approve()`: リクエスト承認
  - `reject()`: リクエスト拒否
  - `isSpam()`: スパム判定
  - `shouldAutoExpire()`: 自動期限切れ判定

#### MessageDelivery Aggregate
**責務**: メッセージの配信状態を管理
- **集約ルート**: MessageDelivery
- **不変条件**:
  - 配信状態は後戻りしない（sent→delivered→read）
  - 配信失敗は規定回数まで再試行
- **ドメインロジック**:
  - `markAsDelivered()`: 配信完了マーク
  - `markAsRead()`: 既読マーク
  - `shouldRetry()`: 再送判定
  - `calculateDeliveryLatency()`: 配信遅延計算

### Entities (エンティティ)

#### MessageContent
**所属**: Message Aggregate
**責務**: メッセージの内容を管理
- **属性**:
  - ContentID（Entity識別子）
  - Text（メッセージテキスト）
  - EncryptedContent（暗号化コンテンツ）
  - ContentType（text, image, file等）
  - Metadata（ファイルサイズ、MIME type等）

#### MessageReaction
**所属**: Message Aggregate
**責務**: メッセージへのリアクションを管理
- **属性**:
  - ReactionID（Entity識別子）
  - UserID（リアクションしたユーザー）
  - Emoji（絵文字コード）
  - CreatedAt（作成日時）

#### ConversationSettings
**所属**: Conversation Aggregate
**責務**: 会話の設定を管理
- **属性**:
  - SettingsID（Entity識別子）
  - AllowNewMembers（新規メンバー許可）
  - RequireApproval（承認必須）
  - MessageRetention（メッセージ保持期間）
  - EncryptionEnabled（暗号化有効）

#### ParticipantSettings
**所属**: Participant Aggregate
**責務**: 参加者個別の設定を管理
- **属性**:
  - SettingsID（Entity識別子）
  - NotificationEnabled（通知有効）
  - MutedUntil（ミュート期限）
  - CustomNotificationSound（カスタム通知音）

### Value Objects (値オブジェクト)

**識別子関連**
- **ConversationID**: 会話の一意識別子（UUID v4）
- **MessageID**: メッセージの一意識別子（Snowflake ID、時系列ソート可能）
- **ParticipantID**: 参加者の識別子（UserIDとConversationIDの複合）
- **RequestID**: メッセージリクエストの識別子（UUID v4）
- **DeliveryID**: 配信状態の識別子（MessageIDとUserIDの複合）

**メッセージ属性**
- **MessageText**: メッセージテキスト
  - 最大10,000文字（Unicode正規化済み）
  - 絵文字対応（Unicode 15.0準拠）
  - メンション、URL自動検出
- **MessageType**: メッセージタイプ
  - `text`: テキストメッセージ
  - `image`: 画像
  - `video`: 動画
  - `audio`: 音声
  - `file`: ファイル
  - `location`: 位置情報
- **DeliveryStatus**: 配信状態
  - `pending`: 送信中
  - `sent`: 送信済み
  - `delivered`: 配信済み
  - `read`: 既読
  - `failed`: 失敗

**会話属性**
- **ConversationType**: 会話タイプ
  - `direct`: 1対1
  - `group`: グループ
  - `broadcast`: ブロードキャスト（将来実装）
- **ParticipantRole**: 参加者の役割
  - `owner`: 所有者
  - `admin`: 管理者
  - `member`: メンバー
  - `guest`: ゲスト（限定参加）
- **ConversationStatus**: 会話の状態
  - `active`: アクティブ
  - `archived`: アーカイブ済み
  - `deleted`: 削除済み

**暗号化関連**
- **PublicKey**: 公開鍵（PEM形式、RSA 2048bit以上）
- **KeyFingerprint**: 鍵のフィンガープリント（SHA-256）
- **SessionKey**: セッション鍵（AES-256）
- **EncryptionProtocol**: 暗号化プロトコル
  - `signal`: Signal Protocol
  - `none`: 暗号化なし

**時刻・数値**
- **CreatedAt**: 作成日時（RFC 3339形式、UTC）
- **UpdatedAt**: 更新日時（RFC 3339形式、UTC）
- **LastReadAt**: 最終既読日時
- **TypingTimeout**: タイピングタイムアウト（3秒）
- **MessageRetentionDays**: メッセージ保持日数（1-∞）
- **UnreadCount**: 未読数（0以上の整数）

### Domain Services

#### MessageEncryptionService
**責務**: メッセージの暗号化・復号化処理
- **メソッド**:
  - `encryptMessage(message, recipientKeys)`: メッセージ暗号化
  - `generateSessionKey()`: セッション鍵生成
  - `rotateKeys(conversation)`: 鍵ローテーション
  - `verifyMessageIntegrity(message)`: メッセージ完全性検証

#### ConversationManagementService
**責務**: 会話の作成・管理ルール
- **メソッド**:
  - `canCreateConversation(creatorID, participantIDs)`: 会話作成可否判定
  - `validateParticipantLimit(count)`: 参加者数制限チェック
  - `mergeConversations(conv1, conv2)`: 会話のマージ
  - `splitConversation(conv, participantGroups)`: 会話の分割

#### MessageDeliveryService
**責務**: メッセージ配信の制御
- **メソッド**:
  - `routeMessage(message, recipients)`: メッセージルーティング
  - `prioritizeDelivery(message)`: 配信優先度決定
  - `handleOfflineDelivery(userID, messages)`: オフライン配信処理
  - `ensureDeliveryOrder(messages)`: 配信順序保証

#### SpamDetectionService
**責務**: スパムメッセージの検出と防止
- **メソッド**:
  - `analyzeMessage(message)`: メッセージ分析
  - `calculateSpamScore(content, sender)`: スパムスコア計算
  - `shouldQuarantine(message)`: 隔離判定
  - `updateSenderReputation(senderID, action)`: 送信者評価更新

#### NotificationService
**責務**: 通知の生成と配信制御
- **メソッド**:
  - `shouldNotify(message, recipient)`: 通知要否判定
  - `generateNotificationContent(message)`: 通知内容生成
  - `respectDoNotDisturb(userSettings)`: DND設定確認
  - `batchNotifications(messages)`: 通知のバッチ処理

## ユースケース

### 個人間メッセージ送信

1. ユーザーは受信者を選択し、メッセージ作成画面を開く
2. テキストや添付ファイルを入力
3. 送信ボタンをクリック
4. フロントエンドはメッセージをE2E暗号化（Signal Protocol使用）
5. `avion-gateway` 経由で送信リクエストを送信（認証JWT必須）
6. SendMessageCommandUseCase がリクエストを処理
7. ConversationRepository で会話を取得または作成
8. MessageValidationService でコンテンツを検証
9. SpamDetectionService でスパムチェック
10. Message Aggregate を生成し永続化
11. MessageDeliveryService で配信処理
12. WebSocketで受信者にリアルタイム配信
13. DeliveryStatusを更新
14. MessageEventPublisher で `message_sent` イベントを発行
15. SendMessageResponse DTO を返却

### グループチャット作成

1. ユーザーはグループ作成画面でメンバーを選択
2. グループ名、アイコン、設定を入力
3. 「グループを作成」ボタンをクリック
4. CreateGroupCommandUseCase がリクエストを処理
5. 参加者の権限とブロック関係を確認
6. Conversation Aggregate（type: group）を生成
7. 各参加者のParticipant Aggregateを作成
8. E2E暗号化用のグループ鍵を生成・配布
9. ConversationRepository で永続化
10. 招待通知を各メンバーに送信
11. GroupCreatedEvent を発行
12. CreateGroupResponse DTO を返却

### メッセージの既読処理

1. ユーザーが会話を開く
2. 表示されたメッセージIDをクライアントが収集
3. MarkAsReadCommandUseCase がバッチ処理
4. MessageDeliveryRepository で配信状態を更新
5. LastReadAt を更新
6. UnreadCount を再計算
7. WebSocketで送信者に既読通知を送信
8. ReadReceiptEvent を発行
9. MarkAsReadResponse DTO を返却

### E2E暗号化の鍵交換

1. 新規会話開始時に鍵交換を開始
2. X3DHプロトコルに従い、事前鍵を交換
3. InitiateKeyExchangeCommandUseCase が処理
4. EncryptionKeyRepository から公開鍵を取得
5. セッション鍵を導出（Double Ratchetアルゴリズム）
6. 暗号化パラメータを保存
7. KeyExchangeCompletedEvent を発行
8. 以降のメッセージは自動的に暗号化

### メッセージ検索

1. ユーザーは検索ボックスにキーワードを入力
2. SearchMessagesQueryUseCase が処理
3. クライアントサイドで検索インデックスを参照
4. 暗号化メッセージは検索可能暗号化で処理
5. 日付、送信者、ファイルタイプでフィルタリング
6. 関連度スコアでソート
7. ページネーション処理
8. SearchResultDTO を返却

### タイピングインジケーター

1. ユーザーがメッセージ入力を開始
2. SendTypingIndicatorCommandUseCase が処理
3. WebSocketで会話参加者に通知
4. 3秒後に自動的にタイムアウト
5. 複数人の同時タイピングを管理
6. TypingStatusDTO を返却

### メッセージリクエスト処理

1. 未承認ユーザーからメッセージ受信
2. MessageRequest Aggregate を生成
3. 受信者に通知（リクエスト保留中）
4. 受信者が承認/拒否を選択
5. ProcessMessageRequestCommandUseCase が処理
6. 承認時は通常の会話に昇格
7. 拒否時はメッセージを削除
8. MessageRequestProcessedEvent を発行

### ファイル添付送信

1. ユーザーがファイルを選択
2. avion-media にアップロード
3. ウイルススキャン実行
4. サムネイル生成（画像/動画の場合）
5. SendFileMessageCommandUseCase が処理
6. ファイルメタデータを暗号化
7. Message Aggregate（type: file）を生成
8. 配信処理
9. FileMessageSentEvent を発行

### 会話のアーカイブ

1. ユーザーが会話をアーカイブ選択
2. ArchiveConversationCommandUseCase が処理
3. Conversation.archive() を実行
4. アーカイブフラグを設定
5. 会話リストから非表示化
6. 新着メッセージ時の通知設定を確認
7. ConversationArchivedEvent を発行
8. ArchiveResponse DTO を返却

## 機能要求

### ドメインロジック要求

*   **Conversation管理:**
    * 会話のライフサイクル全体の整合性を保つ
    * 参加者の追加・削除の権限管理
    * グループ設定の一貫性保証
    * アーカイブ・削除処理の完全性

*   **Message管理:**
    * メッセージの順序保証
    * 編集・削除の時間制限と権限管理
    * 暗号化メッセージの完全性検証
    * 配信状態の正確な追跡

*   **Encryption管理:**
    * E2E暗号化の透過的な処理
    * 鍵のセキュアな管理と配布
    * Forward Secrecyの実装
    * 複数デバイス間の鍵同期

### APIエンドポイント要求

*   **Message API:**
    * メッセージ送信、取得、編集、削除のgRPC API
    * リアルタイム配信用WebSocket API
    * バッチ既読処理API

*   **Conversation API:**
    * 会話の作成、更新、削除のgRPC API
    * 参加者管理API
    * 会話設定管理API

*   **Encryption API:**
    * 公開鍵の登録・取得API
    * 鍵交換プロトコルAPI
    * 暗号化ステータス確認API

### データ要求

*   **メッセージ:** 最大10,000文字、Unicode対応
*   **グループ:** 最大100人、グループ名50文字まで
*   **ファイル:** 最大100MB、同時アップロード5ファイルまで
*   **会話履歴:** デフォルト90日保持、設定により無期限可能
*   **暗号化鍵:** RSA 2048bit以上、定期的なローテーション
*   **検索インデックス:** 最新1000メッセージ分をクライアントキャッシュ

## セキュリティ実装ガイドライン

avion-messageサービスは、プライベートな会話を扱うため、以下のセキュリティガイドラインに従って実装します：

### 必須実装項目

1. **エンドツーエンド暗号化** ([暗号化ガイドライン](../common/security/encryption-guidelines.md))
   - Signal Protocolの完全実装
   - 鍵の安全な管理と配布
   - Forward Secrecyによる過去メッセージの保護
   - メタデータの最小化

2. **XSS防止** ([XSS防止ガイドライン](../common/security/xss-prevention.md))
   - メッセージ内容の厳格なサニタイゼーション
   - リンクプレビューの安全な生成
   - ファイル名のエスケープ処理
   - CSPヘッダーの適切な設定

3. **CSRF保護** ([CSRF保護ガイドライン](../common/security/csrf-protection.md))
   - メッセージ送信時のCSRFトークン検証
   - WebSocket接続時の認証
   - SameSite Cookie属性の設定

4. **SQLインジェクション防止** ([SQLインジェクション防止](../common/security/sql-injection-prevention.md))
   - 全データベースクエリでプリペアドステートメント使用
   - メッセージ検索クエリのパラメータ化
   - ORMレイヤーでの自動エスケープ

### 実装時の注意事項

- **メッセージの暗号化**: E2E暗号化をデフォルトで有効化
- **鍵管理**: 秘密鍵は絶対にサーバーに送信しない
- **認証強化**: メッセージ送信には必ず認証を要求
- **レート制限**: スパム防止のための送信頻度制限
- **監査ログ**: アクセスログの記録（メッセージ内容は除く）
- **データ保護**: 削除されたメッセージの完全消去

## 技術的要求

### レイテンシ

*   **メッセージ送信**: 平均 100ms 以下, p99 500ms 以下
*   **メッセージ受信（WebSocket）**: 平均 50ms 以下, p99 200ms 以下
*   **会話リスト取得**: 平均 150ms 以下, p99 400ms 以下
*   **メッセージ検索**: 平均 100ms 以下, p99 300ms 以下（ローカル検索）
*   **既読処理**: 平均 50ms 以下, p99 150ms 以下
*   **タイピングインジケーター**: 平均 30ms 以下（リアルタイム）
*   **ファイルアップロード**: 1MB/秒以上のスループット
*   **暗号化/復号化**: 平均 20ms 以下（クライアントサイド）

### 可用性

*   **稼働率**: 99.95%（月間ダウンタイム2.2時間以内）
*   **Kubernetes構成**: 最小5レプリカによる冗長構成
*   **メッセージキュー**: Redis Streamsによる配信保証
*   **WebSocket接続**: 自動再接続とセッション復元
*   **オフライン対応**: メッセージバッファリングと後日配信
*   **災害復旧**: RTO 10分、RPO 1分以内

### スケーラビリティ

*   **処理能力**: 10,000メッセージ/秒（ピーク時50,000メッセージ/秒）
*   **同時接続数**: 100万WebSocket接続
*   **会話数**: 1000万会話を効率的に管理
*   **メッセージ保存**: 100億メッセージの保存と検索
*   **水平スケーリング**: CPU使用率60%で自動スケールアウト
*   **データベースシャーディング**: ConversationIDベースの分割

### セキュリティ

*   **E2E暗号化**: Signal Protocolによる完全な暗号化
*   **認証**: JWT + WebSocket認証
*   **認可**: 会話参加者のみアクセス可能
*   **監査ログ**: 全アクセスの記録（内容は除く）
*   **データ保護**: 保存時暗号化（AES-256-GCM）
*   **ネットワーク**: TLS 1.3による通信暗号化
*   **レート制限**: ユーザー単位100msg/min、IP単位1000msg/min

### データ整合性

*   **メッセージ順序**: ConversationIDとTimestampによる厳密な順序保証
*   **配信保証**: At-least-once配信、重複排除機能付き
*   **トランザクション**: メッセージ送信と配信状態更新の原子性
*   **既読同期**: 最終的整合性、5秒以内に全デバイス同期
*   **暗号化整合性**: HMACによるメッセージ改竄検出
*   **会話状態**: 楽観的ロックによる同時更新制御

### その他技術要件

*   **リアルタイム通信**:
     - WebSocketとSSEの併用
     - 自動再接続とセッション管理
     - ハートビートによる接続監視
*   **Observability**:
     - OpenTelemetryによる分散トレーシング
     - メッセージ配信メトリクス
     - WebSocket接続メトリクス
*   **キャッシュ戦略**:
     - 会話メタデータ: Redis（TTL 5分）
     - 最新メッセージ: アプリケーションメモリ（100件）
     - 暗号化鍵: セキュアメモリ（セッション期間）
*   **ストレージ最適化**:
     - メッセージの階層的アーカイブ
     - メディアファイルの重複排除
     - 古いメッセージの圧縮保存

## イベント駆動アーキテクチャ

### 発行イベント定義

#### メッセージ関連イベント
- **MessageSentEvent**: メッセージ送信時
  - ペイロード: messageID, conversationID, senderID, timestamp
  - 購読サービス: avion-notification, avion-activitypub

- **MessageDeliveredEvent**: メッセージ配信完了時
  - ペイロード: messageID, recipientID, deliveredAt
  - 購読サービス: avion-notification

- **MessageReadEvent**: メッセージ既読時
  - ペイロード: messageID, readerID, readAt
  - 購読サービス: avion-notification

- **MessageEditedEvent**: メッセージ編集時
  - ペイロード: messageID, editorID, editedAt, previousContent
  - 購読サービス: avion-notification

- **MessageDeletedEvent**: メッセージ削除時
  - ペイロード: messageID, deleterID, deletedAt, deleteType
  - 購読サービス: avion-notification

#### 会話関連イベント
- **ConversationCreatedEvent**: 会話作成時
  - ペイロード: conversationID, creatorID, participantIDs, type
  - 購読サービス: avion-notification, avion-user

- **ParticipantAddedEvent**: 参加者追加時
  - ペイロード: conversationID, participantID, addedBy
  - 購読サービス: avion-notification

- **ParticipantRemovedEvent**: 参加者削除時
  - ペイロード: conversationID, participantID, removedBy
  - 購読サービス: avion-notification

- **ConversationArchivedEvent**: 会話アーカイブ時
  - ペイロード: conversationID, archivedBy, archivedAt
  - 購読サービス: avion-notification

#### 暗号化関連イベント
- **KeyRotationEvent**: 鍵ローテーション時
  - ペイロード: conversationID, newKeyFingerprint, rotatedAt
  - 購読サービス: 内部処理のみ

- **EncryptionStatusChangedEvent**: 暗号化状態変更時
  - ペイロード: conversationID, encryptionEnabled, changedAt
  - 購読サービス: avion-notification

#### スケジュール送信関連イベント
- **MessageScheduledEvent**: メッセージスケジュール作成時
  - ペイロード: scheduledMessageID, conversationID, scheduledAt, timezone
  - 購読サービス: 内部処理のみ

- **ScheduledMessageSentEvent**: スケジュールメッセージ送信完了時
  - ペイロード: scheduledMessageID, messageID, sentAt
  - 購読サービス: avion-notification

- **ScheduledMessageCancelledEvent**: スケジュールメッセージキャンセル時
  - ペイロード: scheduledMessageID, cancelledBy, cancelledAt
  - 購読サービス: 内部処理のみ

#### 管理者アクション関連イベント
- **MessageForcefullyDeletedEvent**: 管理者による強制削除時
  - ペイロード: messageID, adminID, reason, deletedAt
  - 購読サービス: avion-notification, avion-system-admin

- **ComplianceActionTakenEvent**: コンプライアンス対応実行時
  - ペイロード: actionType, targetID, adminID, legalReference
  - 購読サービス: avion-system-admin

#### 一括操作関連イベント
- **BulkOperationStartedEvent**: 一括操作開始時
  - ペイロード: operationID, operationType, targetCount, startedAt
  - 購読サービス: 内部処理のみ

- **BulkOperationCompletedEvent**: 一括操作完了時
  - ペイロード: operationID, successCount, failureCount, completedAt
  - 購読サービス: avion-notification

#### デバイス同期関連イベント
- **DeviceRegisteredEvent**: 新規デバイス登録時
  - ペイロード: deviceID, userID, deviceType, platform
  - 購読サービス: avion-notification

- **DeviceSyncRequestedEvent**: デバイス同期要求時
  - ペイロード: deviceID, conversationIDs, requestedAt
  - 購読サービス: 内部処理のみ

- **DraftSyncedEvent**: 下書き同期時
  - ペイロード: draftID, deviceID, conversationID, syncedAt
  - 購読サービス: 内部処理のみ

- **DeviceRevokedEvent**: デバイス削除時
  - ペイロード: deviceID, userID, revokedAt
  - 購読サービス: avion-notification, avion-auth

### イベント配信保証

- **配信方式**: Redis Streams使用
- **順序保証**: ConversationIDベースのパーティショニング
- **重複排除**: イベントIDによる冪等性保証
- **リトライ**: 指数バックオフ（最大5回）
- **Dead Letter Queue**: 失敗イベントの隔離と手動処理

## 決まっていないこと

*   **音声/ビデオ通話統合**: WebRTC実装の詳細、シグナリングサーバーの設計
*   **メッセージの自動翻訳**: 翻訳APIの選定、プライバシー保護との両立方法
*   **AIアシスタント機能**: チャットボット統合の可否、E2E暗号化との互換性
*   **メッセージのバックアップ**: クラウドバックアップの実装、暗号化キーの管理
*   **クロスプラットフォーム同期**: 複数デバイス間でのメッセージ同期方法
*   **リアクション通知**: リアクション時の通知粒度、バッチ処理のタイミング
*   **メディアファイルの圧縮**: 自動圧縮のしきい値、品質設定
*   **オフライン期間**: オフラインメッセージの保持期間（現在は30日想定）
*   **グループの最大人数**: 100人以上のグループサポート、パフォーマンスへの影響
*   **メッセージのインポート/エクスポート形式**: 他サービスからの移行対応
*   **ビジネスアカウント対応**: 自動応答、営業時間設定などの機能
*   **メッセージのスレッド化**: Slack形式のスレッド返信機能
*   **既読回避モード**: 既読を付けずにメッセージを読む機能
*   **メッセージのピン留め数制限**: グループでのピン留め可能数
*   **ファイル保存期間**: 添付ファイルの自動削除ポリシー