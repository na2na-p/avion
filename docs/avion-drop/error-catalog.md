# エラーカタログ: avion-drop

**Last Updated:** 2026/03/15
**Service:** Content Management Service

## 概要

avion-dropサービスで発生する可能性のあるエラーコード一覧とその対処法です。

エラーコードの命名規則は `[SERVICE]_[LAYER]_[ERROR_TYPE]` 形式に準拠します（[エラーコード標準化ガイドライン](../common/errors/error-standards.md)参照）。

## ドメイン層エラー

### Drop関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_DOMAIN_DROP_NOT_FOUND | 404 | NOT_FOUND | Dropが見つかりません | DropIDを確認してください |
| DROP_DOMAIN_DROP_ALREADY_EXISTS | 409 | ALREADY_EXISTS | Dropが既に存在します | 既存のDropを確認してください |
| DROP_DOMAIN_INVALID_CONTENT | 400 | INVALID_ARGUMENT | コンテンツが不正です | コンテンツを確認してください |
| DROP_DOMAIN_CONTENT_TOO_LONG | 400 | INVALID_ARGUMENT | コンテンツが長すぎます（最大500文字） | 文字数制限を確認してください |
| DROP_DOMAIN_EMPTY_CONTENT | 400 | INVALID_ARGUMENT | コンテンツが空です | コンテンツを入力してください |
| DROP_DOMAIN_DROP_DELETED | 404 | NOT_FOUND | Dropが削除されています | 削除されたDropにはアクセスできません |
| DROP_DOMAIN_INVALID_VISIBILITY | 400 | INVALID_ARGUMENT | 公開範囲設定が不正です | public, unlisted, followers_only, direct, private のいずれかを指定してください |
| DROP_DOMAIN_EDIT_TIME_EXPIRED | 400 | FAILED_PRECONDITION | 編集可能期間（30分）を超過しました | 編集期限内に操作してください |
| DROP_DOMAIN_EDIT_LIMIT_EXCEEDED | 400 | FAILED_PRECONDITION | 編集回数の上限に達しました | これ以上の編集はできません |

### ContentWarning（コンテンツ警告）関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_DOMAIN_INVALID_CONTENT_WARNING | 400 | INVALID_ARGUMENT | コンテンツ警告の内容が不正です | コンテンツ警告テキストの形式を確認してください |
| DROP_DOMAIN_CONTENT_WARNING_TOO_LONG | 400 | INVALID_ARGUMENT | コンテンツ警告テキストが長すぎます（最大100文字） | コンテンツ警告テキストを100文字以内に短縮してください |

### EditHistory（編集履歴）関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_DOMAIN_EDIT_HISTORY_CORRUPTED | 500 | INTERNAL | 編集履歴の整合性エラーが検出されました。編集番号の連続性やリビジョンデータに矛盾があります | システム管理者に連絡してください。CRITICALレベルでログ記録され、データ整合性の調査が必要です |
| DROP_DOMAIN_EDIT_WINDOW_EXPIRED | 400 | FAILED_PRECONDITION | 編集可能期間（30分）が経過しました。Drop作成後30分を超えると新しいリビジョンを作成できません | 編集期限内に操作してください。新規Dropとして再投稿することを検討してください |

### Reaction関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_DOMAIN_REACTION_NOT_FOUND | 404 | NOT_FOUND | リアクションが見つかりません | リアクションIDを確認してください |
| DROP_DOMAIN_ALREADY_REACTED | 409 | ALREADY_EXISTS | 既にリアクションしています | 既存のリアクションを確認してください |
| DROP_DOMAIN_NOT_REACTED | 404 | NOT_FOUND | リアクションしていません | リアクション状態を確認してください |
| DROP_DOMAIN_INVALID_EMOJI_CODE | 400 | INVALID_ARGUMENT | 絵文字コードが不正です | 有効なUnicode絵文字またはカスタム絵文字コードを使用してください |
| DROP_DOMAIN_SELF_REACTION_FORBIDDEN | 403 | PERMISSION_DENIED | 自分のDropにはリアクションできません | 他のユーザーのDropにリアクションしてください |
| DROP_DOMAIN_REACTION_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | リアクション制限を超過しました | 制限がリセットされるまで待ってください |

### Reply関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_DOMAIN_REPLY_NOT_FOUND | 404 | NOT_FOUND | 返信が見つかりません | 返信IDを確認してください |
| DROP_DOMAIN_REPLY_DEPTH_EXCEEDED | 400 | INVALID_ARGUMENT | 返信の階層が深すぎます | 階層制限を確認してください |
| DROP_DOMAIN_REPLY_TARGET_NOT_FOUND | 404 | NOT_FOUND | 返信先のDropが見つかりません | 返信先のDropIDを確認してください |

### Poll（投票）関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_DOMAIN_POLL_NOT_FOUND | 404 | NOT_FOUND | 投票が見つかりません | PollIDを確認してください |
| DROP_DOMAIN_POLL_EXPIRED | 400 | FAILED_PRECONDITION | 投票期限が切れています | 期限切れの投票には参加できません |
| DROP_DOMAIN_ALREADY_VOTED | 409 | ALREADY_EXISTS | 既に投票済みです | 同一投票への重複投票はできません |
| DROP_DOMAIN_INVALID_POLL_OPTION | 400 | INVALID_ARGUMENT | 投票選択肢が不正です | 有効な選択肢IDを指定してください |
| DROP_DOMAIN_TOO_FEW_OPTIONS | 400 | INVALID_ARGUMENT | 投票選択肢が少なすぎます | 選択肢は2個以上必要です |
| DROP_DOMAIN_TOO_MANY_OPTIONS | 400 | INVALID_ARGUMENT | 投票選択肢が多すぎます | 選択肢は10個以下にしてください |
| DROP_DOMAIN_INVALID_POLL_DURATION | 400 | INVALID_ARGUMENT | 投票期間が不正です | 投票期間は5分以上7日以内に設定してください |

### Bookmark（ブックマーク）関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_DOMAIN_BOOKMARK_NOT_FOUND | 404 | NOT_FOUND | ブックマークが見つかりません | ブックマークIDを確認してください |
| DROP_DOMAIN_ALREADY_BOOKMARKED | 409 | ALREADY_EXISTS | 既にブックマーク済みです | 既存のブックマークを確認してください |

### Renote（リポスト/引用）関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_DOMAIN_RENOTE_NOT_FOUND | 404 | NOT_FOUND | リノートが見つかりません | リノートIDを確認してください |
| DROP_DOMAIN_ALREADY_RENOTED | 409 | ALREADY_EXISTS | 既にリノート済みです | 既存のリノートを確認してください |
| DROP_DOMAIN_CANNOT_RENOTE_OWN_DROP | 400 | INVALID_ARGUMENT | 自分のDropはリノートできません | 他のユーザーのDropをリノートしてください |
| DROP_DOMAIN_CANNOT_RENOTE_PRIVATE | 403 | PERMISSION_DENIED | プライベートDropはリノートできません | 公開範囲を確認してください |

### ScheduledDrop（予約投稿/下書き）関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_DOMAIN_SCHEDULED_DROP_NOT_FOUND | 404 | NOT_FOUND | 予約投稿が見つかりません | ScheduledDropIDを確認してください |
| DROP_DOMAIN_INVALID_SCHEDULE_TIME | 400 | INVALID_ARGUMENT | 予約日時が不正です | 現在時刻より5分以上先、30日以内の日時を指定してください |
| DROP_DOMAIN_SCHEDULE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | 予約投稿数の上限に達しました | 不要な予約投稿を削除してください |
| DROP_DOMAIN_PAST_SCHEDULE_TIME | 400 | INVALID_ARGUMENT | 予約日時が過去です | 未来の日時を指定してください |
| DROP_DOMAIN_SCHEDULED_DROP_ALREADY_PUBLISHED | 400 | FAILED_PRECONDITION | 公開済みの予約投稿です | 公開済みの予約投稿は編集できません |
| DROP_DOMAIN_SCHEDULED_DROP_CANCELLED | 400 | FAILED_PRECONDITION | キャンセル済みの予約投稿です | キャンセル済みの予約投稿は操作できません |

### Draft（下書き）関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_DOMAIN_DRAFT_NOT_FOUND | 404 | NOT_FOUND | 下書きが見つかりません | DraftIDを確認してください |
| DROP_DOMAIN_DRAFT_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | 下書き数の上限（100件）に達しました | 不要な下書きを削除してください |
| DROP_DOMAIN_INVALID_DRAFT_CONTENT | 400 | INVALID_ARGUMENT | 下書きの内容が不正です | 内容を確認してください |

### Media関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_DOMAIN_MEDIA_NOT_FOUND | 404 | NOT_FOUND | メディアが見つかりません | メディアIDを確認してください |
| DROP_DOMAIN_INVALID_MEDIA_TYPE | 400 | INVALID_ARGUMENT | メディアタイプが不正です | 対応するメディアタイプを使用してください |
| DROP_DOMAIN_MEDIA_TOO_LARGE | 413 | INVALID_ARGUMENT | メディアサイズが大きすぎます | ファイルサイズを小さくしてください |
| DROP_DOMAIN_MEDIA_COUNT_EXCEEDED | 400 | INVALID_ARGUMENT | メディア数が上限（4つ）を超過しました | メディア数を減らしてください |
| DROP_DOMAIN_MEDIA_PROCESSING_FAILED | 422 | INTERNAL | メディア処理に失敗しました | メディアファイルを確認してください |

### Tag（ハッシュタグ/メンション）関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_DOMAIN_TAG_NOT_FOUND | 404 | NOT_FOUND | タグが見つかりません | タグ名を確認してください |
| DROP_DOMAIN_INVALID_TAG | 400 | INVALID_ARGUMENT | タグが不正です | タグの形式を確認してください |
| DROP_DOMAIN_TAG_TOO_LONG | 400 | INVALID_ARGUMENT | タグが長すぎます | タグの長さを短くしてください |
| DROP_DOMAIN_TOO_MANY_TAGS | 400 | INVALID_ARGUMENT | タグ数が多すぎます（最大10個） | タグ数を減らしてください |
| DROP_DOMAIN_DUPLICATE_TAG | 400 | INVALID_ARGUMENT | 重複したタグがあります | 重複を除去してください |
| DROP_DOMAIN_TOO_MANY_MENTIONS | 400 | INVALID_ARGUMENT | メンション数が多すぎます（最大20ユーザー） | メンション数を減らしてください |
| DROP_DOMAIN_INVALID_MENTION | 400 | INVALID_ARGUMENT | メンションが不正です | メンションの形式を確認してください |

### Privacy関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_DOMAIN_PRIVATE_DROP | 403 | PERMISSION_DENIED | プライベートなDropです | アクセス権限を確認してください |
| DROP_DOMAIN_RESTRICTED_ACCESS | 403 | PERMISSION_DENIED | アクセスが制限されています | 制限条件を確認してください |
| DROP_DOMAIN_INVALID_PRIVACY_SETTING | 400 | INVALID_ARGUMENT | プライバシー設定が不正です | 設定値を確認してください |

### Report（通報）関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_DOMAIN_REPORT_NOT_FOUND | 404 | NOT_FOUND | 通報が見つかりません | ReportIDを確認してください |
| DROP_DOMAIN_ALREADY_REPORTED | 409 | ALREADY_EXISTS | 既に通報済みです | 同一ユーザーによる同一Dropへの重複通報はできません |
| DROP_DOMAIN_INVALID_REPORT_REASON | 400 | INVALID_ARGUMENT | 通報理由が不正です | 有効な通報理由を指定してください |
| DROP_DOMAIN_REPORT_ALREADY_RESOLVED | 400 | FAILED_PRECONDITION | 通報は解決済みです | 解決済みの通報は変更できません |

## ユースケース層エラー

### 入力検証エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_USECASE_INVALID_INPUT | 400 | INVALID_ARGUMENT | 入力値が不正です | 入力値を確認してください |
| DROP_USECASE_MISSING_REQUIRED | 400 | INVALID_ARGUMENT | 必須項目が不足しています | 必須項目を入力してください |
| DROP_USECASE_INVALID_DROP_ID | 400 | INVALID_ARGUMENT | DropIDが不正です | DropIDの形式を確認してください |
| DROP_USECASE_INVALID_USER_ID | 400 | INVALID_ARGUMENT | ユーザーIDが不正です | ユーザーIDの形式を確認してください |

### 認証・認可エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_USECASE_UNAUTHORIZED | 401 | UNAUTHENTICATED | 認証が必要です | ログインしてください |
| DROP_USECASE_FORBIDDEN | 403 | PERMISSION_DENIED | アクセスが禁止されています | アクセス権限を確認してください |
| DROP_USECASE_INSUFFICIENT_PERMISSION | 403 | PERMISSION_DENIED | 権限が不足しています | 必要な権限を確認してください |
| DROP_USECASE_NOT_OWNER | 403 | PERMISSION_DENIED | Dropの所有者ではありません | 所有者のみが実行できる操作です |

### ビジネスロジックエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_USECASE_CONFLICT | 409 | ABORTED | リソースの競合が発生しました | 時間をおいて再試行してください |
| DROP_USECASE_PRECONDITION_FAILED | 412 | FAILED_PRECONDITION | 事前条件を満たしていません | 事前条件を確認してください |
| DROP_USECASE_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |
| DROP_USECASE_QUOTA_EXCEEDED | 429 | RESOURCE_EXHAUSTED | クォータを超過しました | 使用量を確認してください |

### コンテンツ処理エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ~~DROP_USECASE_CONTENT_FILTERING_FAILED~~ | ~~422~~ | ~~INTERNAL~~ | **廃止（2026/03/15）**: コンテンツフィルタリングはavion-moderationサービスへの非同期移譲方式に移行したため廃止。avion-dropはDrop作成時に `DropCreatedEvent` を NATS JetStream に発行し、avion-moderationが非同期でコンテンツを検査する。違反検出時はavion-moderationが事後削除・制限アクション（コンテンツ削除、アカウント凍結等）を実行する。avion-drop側では同期的なコンテンツフィルタリングは行わない | - |
| DROP_USECASE_SPAM_DETECTED | 422 | INVALID_ARGUMENT | スパムコンテンツが検出されました | コンテンツを見直してください |
| DROP_USECASE_INAPPROPRIATE_CONTENT | 422 | INVALID_ARGUMENT | 不適切なコンテンツが検出されました | コンテンツを修正してください |

## インフラストラクチャ層エラー

### データベースエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_INFRA_DATABASE_CONNECTION_FAILED | 503 | UNAVAILABLE | データベース接続失敗 | 接続設定を確認してください |
| DROP_INFRA_DATABASE_QUERY_FAILED | 500 | INTERNAL | クエリ実行失敗 | クエリを確認してください |
| DROP_INFRA_DATABASE_TRANSACTION_FAILED | 500 | INTERNAL | トランザクション失敗 | 再試行してください |
| DROP_INFRA_DATABASE_CONSTRAINT_VIOLATION | 409 | ABORTED | データベース制約違反 | データの整合性を確認してください |

### キャッシュエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_INFRA_CACHE_CONNECTION_FAILED | 503 | UNAVAILABLE | キャッシュ接続失敗 | 接続設定を確認してください |
| DROP_INFRA_CACHE_OPERATION_FAILED | 500 | INTERNAL | キャッシュ操作失敗 | 再試行してください |
| DROP_INFRA_CACHE_INVALIDATION_FAILED | 500 | INTERNAL | キャッシュ無効化失敗 | キャッシュシステムを確認してください |

### ストレージエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_INFRA_STORAGE_UPLOAD_FAILED | 500 | INTERNAL | アップロード失敗 | 再試行してください |
| DROP_INFRA_STORAGE_DELETE_FAILED | 500 | INTERNAL | 削除失敗 | 再試行してください |
| DROP_INFRA_STORAGE_QUOTA_EXCEEDED | 507 | RESOURCE_EXHAUSTED | ストレージ容量超過 | 不要なファイルを削除してください |

### 外部サービスエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_INFRA_MEDIA_SERVICE_ERROR | 502 | INTERNAL | メディアサービスエラー | メディアサービスの状態を確認してください |
| DROP_INFRA_SEARCH_SERVICE_ERROR | 502 | INTERNAL | 検索サービスエラー | 検索サービスの状態を確認してください |
| DROP_INFRA_MODERATION_SERVICE_ERROR | 502 | INTERNAL | モデレーションサービスエラー | モデレーションサービスの状態を確認してください |
| DROP_INFRA_EVENT_PUBLISH_FAILED | 500 | INTERNAL | イベント発行失敗（NATS JetStream） | メッセージングシステムの状態を確認してください |

## ハンドラー層エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| DROP_HANDLER_BAD_REQUEST | 400 | INVALID_ARGUMENT | 不正なリクエスト | リクエスト形式を確認してください |
| DROP_HANDLER_PAYLOAD_TOO_LARGE | 413 | INVALID_ARGUMENT | ペイロードサイズ超過 | リクエストサイズを小さくしてください |
| DROP_HANDLER_UNSUPPORTED_MEDIA_TYPE | 415 | INVALID_ARGUMENT | サポートされないメディアタイプ | Content-Typeを確認してください |
| DROP_HANDLER_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |

## 変更履歴

| 日付 | 変更内容 |
|------|---------|
| 2026/03/15 | ContentWarning関連エラー（DROP_DOMAIN_INVALID_CONTENT_WARNING, DROP_DOMAIN_CONTENT_WARNING_TOO_LONG）を追加、EditHistory整合性エラー（DROP_DOMAIN_EDIT_HISTORY_CORRUPTED, DROP_DOMAIN_EDIT_WINDOW_EXPIRED）を追加、DROP_USECASE_CONTENT_FILTERING_FAILEDの廃止理由にavion-moderationへの非同期移譲を明記、Comment関連エラーをReply関連に改称、Poll/Bookmark/Renote/ScheduledDrop/Draft/Report関連エラーを追加、DROP_INFRA_EVENT_PUBLISH_FAILEDを追加、メンション関連エラーを追加、Drop編集関連エラーを追加 |
| 2025/08/19 | 初版作成 |

## 関連ドキュメント

- [Avion エラーコード標準化ガイドライン](../common/errors/error-standards.md)
- [Avion エラーコード一覧](../common/errors/error-codes.md)
- [エラー実装ガイド](../common/errors/implementation-guide.md)
- [avion-drop PRD](./prd.md)
- [avion-drop Design Doc](./designdoc.md)
