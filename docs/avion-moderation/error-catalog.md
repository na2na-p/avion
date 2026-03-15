# エラーカタログ: avion-moderation

**Last Updated:** 2026/03/15
**Service:** Content Moderation and Filtering Service

## 概要

avion-moderationサービスで発生する可能性のあるエラーコード一覧とその対処法です。

## ドメイン層エラー

### Report関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_DOMAIN_REPORT_NOT_FOUND | 404 | NOT_FOUND | 通報が見つかりません | 通報IDを確認してください |
| MODERATION_DOMAIN_REPORT_DUPLICATE | 409 | ALREADY_EXISTS | 24時間以内に同一対象への重複通報です | 既存の通報を確認してください |
| MODERATION_DOMAIN_REPORT_INVALID | 400 | INVALID_ARGUMENT | 通報内容が不正です | 通報理由・対象を確認してください |
| MODERATION_DOMAIN_REPORT_ALREADY_PROCESSED | 409 | ALREADY_EXISTS | 通報は既に処理済みです | 処理状態を確認してください |
| MODERATION_DOMAIN_REPORT_SELF_FORBIDDEN | 403 | PERMISSION_DENIED | 自分自身への通報はできません | 他のユーザーを対象にしてください |
| MODERATION_DOMAIN_REPORT_NOT_PENDING | 412 | FAILED_PRECONDITION | 通報は処理待ち状態ではありません | 現在のステータスを確認してください |
| MODERATION_DOMAIN_REPORT_INVALID_STATUS_TRANSITION | 400 | INVALID_ARGUMENT | 不正なステータス遷移です | 許可されたステータス遷移を確認してください |
| MODERATION_DOMAIN_REPORT_EVIDENCE_LIMIT_EXCEEDED | 400 | INVALID_ARGUMENT | 証拠添付数の上限（3件）を超えています | 証拠を3件以内に絞ってください |

### ModerationCase関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_DOMAIN_CASE_NOT_FOUND | 404 | NOT_FOUND | モデレーションケースが見つかりません | ケースIDを確認してください |
| MODERATION_DOMAIN_CASE_ALREADY_RESOLVED | 409 | ALREADY_EXISTS | ケースは既に解決済みです | 解決状態を確認してください |
| MODERATION_DOMAIN_CASE_REPORT_MISMATCH | 400 | INVALID_ARGUMENT | 関連通報のターゲットが一致しません | 同一対象の通報のみ統合できます |
| MODERATION_DOMAIN_CASE_REPORT_EXPIRED | 400 | INVALID_ARGUMENT | 24時間以上経過した通報は統合できません | 新規ケースを作成してください |

### ModerationAction関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_DOMAIN_ACTION_NOT_FOUND | 404 | NOT_FOUND | モデレーションアクションが見つかりません | アクションIDを確認してください |
| MODERATION_DOMAIN_ACTION_INVALID | 400 | INVALID_ARGUMENT | 無効なモデレーションアクションです | アクション定義を確認してください |
| MODERATION_DOMAIN_ACTION_ALREADY_ACTIVE | 409 | ALREADY_EXISTS | モデレーションアクションは既に有効です | 実行状態を確認してください |
| MODERATION_DOMAIN_ACTION_NOT_REVERSIBLE | 400 | INVALID_ARGUMENT | このアクションは取り消しできません | 取り消し可能なアクションを確認してください |
| MODERATION_DOMAIN_ACTION_EXECUTION_FAILED | 500 | INTERNAL | アクション実行に失敗しました | 実行エラーを確認してください |
| MODERATION_DOMAIN_UNSUPPORTED_ACTION_TYPE | 400 | INVALID_ARGUMENT | サポートされないアクションタイプです | 対応するアクションタイプを使用してください |
| MODERATION_DOMAIN_OPTIMISTIC_LOCK_FAILURE | 409 | ABORTED | 楽観的ロックの競合が発生しました | 時間をおいて再試行してください |

### ContentFilter関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_DOMAIN_FILTER_NOT_FOUND | 404 | NOT_FOUND | コンテンツフィルターが見つかりません | フィルターIDを確認してください |
| MODERATION_DOMAIN_FILTER_INVALID | 400 | INVALID_ARGUMENT | コンテンツフィルターが不正です | フィルター設定を確認してください |
| MODERATION_DOMAIN_FILTER_INACTIVE | 400 | INVALID_ARGUMENT | フィルターが無効化されています | フィルターを有効にしてください |
| MODERATION_DOMAIN_FILTER_PRIORITY_CONFLICT | 409 | ABORTED | フィルター優先度が競合しています | 優先度を調整してください |
| MODERATION_DOMAIN_FILTER_COMPILATION_FAILED | 422 | INVALID_ARGUMENT | フィルターパターンのコンパイルに失敗しました | 正規表現構文を確認してください |
| MODERATION_DOMAIN_FILTER_SYSTEM_DELETE_FORBIDDEN | 403 | PERMISSION_DENIED | システムフィルターは削除できません | 管理者に確認してください |

### Appeal関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_DOMAIN_APPEAL_NOT_FOUND | 404 | NOT_FOUND | 異議申し立てが見つかりません | 異議申し立てIDを確認してください |
| MODERATION_DOMAIN_APPEAL_ALREADY_EXISTS | 409 | ALREADY_EXISTS | 異議申し立てが既に存在します | 1つのアクションに対して申し立ては1回のみです |
| MODERATION_DOMAIN_APPEAL_INVALID | 400 | INVALID_ARGUMENT | 異議申し立て内容が不正です | 申し立て理由・説明を確認してください |
| MODERATION_DOMAIN_APPEAL_EXPIRED | 410 | FAILED_PRECONDITION | 異議申し立て期限（7日間）が切れています | 期限内に申し立てを行ってください |
| MODERATION_DOMAIN_APPEAL_ALREADY_PROCESSED | 409 | ALREADY_EXISTS | 異議申し立ては既に処理済みです | 処理状態を確認してください |
| MODERATION_DOMAIN_APPEAL_SAME_REVIEWER | 400 | INVALID_ARGUMENT | 原判定者と同一の審査者は割り当てできません | 別の審査者を選定してください |

### InstancePolicy関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_DOMAIN_INSTANCE_NOT_FOUND | 404 | NOT_FOUND | インスタンスポリシーが見つかりません | ドメイン名を確認してください |
| MODERATION_DOMAIN_INSTANCE_SELF_MODERATION | 400 | INVALID_ARGUMENT | 自インスタンスはモデレーション対象外です | 外部インスタンスを対象にしてください |
| MODERATION_DOMAIN_INSTANCE_POLICY_CONFLICT | 409 | ABORTED | ポリシーの競合が発生しました | 既存のポリシーを確認してください |
| MODERATION_DOMAIN_INSTANCE_INVALID_DOMAIN | 400 | INVALID_ARGUMENT | ドメイン名の形式が不正です | FQDN形式で入力してください |

### CommunityModeration関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_DOMAIN_VOTE_ALREADY_EXISTS | 409 | ALREADY_EXISTS | 同一対象に対して既に投票済みです | 投票は1回のみ可能です |
| MODERATION_DOMAIN_VOTE_INSUFFICIENT_TRUST | 403 | PERMISSION_DENIED | 投票に必要な信頼レベルが不足しています | 信頼レベルを確認してください |
| MODERATION_DOMAIN_VOTE_EXPIRED | 410 | FAILED_PRECONDITION | 投票期限が切れています | 投票期限内に投票してください |
| MODERATION_DOMAIN_VOTE_THRESHOLD_NOT_MET | 400 | INVALID_ARGUMENT | 最小投票数に達していません | 追加の投票を待ってください |

### AIConsent関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_DOMAIN_AI_CONSENT_NOT_FOUND | 404 | NOT_FOUND | AI同意設定が見つかりません | ユーザーの同意設定を確認してください |
| MODERATION_DOMAIN_AI_CONSENT_REQUIRED | 403 | PERMISSION_DENIED | AI分析にはユーザーの同意が必要です | ユーザーのオプトイン設定を確認してください |
| MODERATION_DOMAIN_AI_SERVER_DISABLED | 400 | INVALID_ARGUMENT | サーバーレベルでAI機能が無効です | サーバー設定を確認してください |

### Escalation関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_DOMAIN_ESCALATION_REQUIRED | 400 | INVALID_ARGUMENT | 上級モデレーターへのエスカレーションが必要です | エスカレーション手続きを行ってください |
| MODERATION_DOMAIN_ESCALATION_NO_REVIEWER | 404 | NOT_FOUND | 適切な審査者が見つかりません | 審査者の空き状況を確認してください |
| MODERATION_DOMAIN_ESCALATION_NO_AVAILABLE_REVIEWER | 503 | UNAVAILABLE | エスカレーション先のレビュアーが全員不在または対応不可です | レビュアーのシフト状況を確認し、時間をおいて再試行してください。緊急の場合は管理者に連絡してください |

### ContentClassification関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_DOMAIN_CLASSIFICATION_FAILED | 500 | INTERNAL | コンテンツ分類に失敗しました | 分類システムを確認してください |
| MODERATION_DOMAIN_CLASSIFICATION_CONFIDENCE_LOW | 422 | FAILED_PRECONDITION | 分類信頼度が低すぎます | 手動確認が必要です |
| MODERATION_DOMAIN_UNSUPPORTED_CONTENT_TYPE | 400 | INVALID_ARGUMENT | サポートされないコンテンツタイプです | 対応するコンテンツタイプを使用してください |

### ModerationQueue関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_DOMAIN_QUEUE_NOT_FOUND | 404 | NOT_FOUND | モデレーションキューが見つかりません | キューIDを確認してください |
| MODERATION_DOMAIN_QUEUE_FULL | 507 | RESOURCE_EXHAUSTED | モデレーションキューが満杯です | キューを処理してください |
| MODERATION_DOMAIN_QUEUE_ITEM_NOT_FOUND | 404 | NOT_FOUND | キューアイテムが見つかりません | アイテムIDを確認してください |

### AuditTrail関連

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_DOMAIN_AUDIT_LOG_CORRUPTION | 500 | INTERNAL | 監査ログの改竄が検出されました | セキュリティチームに即時報告してください |
| MODERATION_DOMAIN_AUDIT_HASH_CHAIN_BROKEN | 500 | INTERNAL | ハッシュチェーンの整合性が崩壊しています | データ整合性の復旧を行ってください |

## ユースケース層エラー

### 入力検証エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_USECASE_INVALID_INPUT | 400 | INVALID_ARGUMENT | 入力値が不正です | 入力値を確認してください |
| MODERATION_USECASE_MISSING_REQUIRED | 400 | INVALID_ARGUMENT | 必須項目が不足しています | 必須項目を入力してください |
| MODERATION_USECASE_INVALID_CONTENT_ID | 400 | INVALID_ARGUMENT | コンテンツIDが不正です | コンテンツIDの形式を確認してください |
| MODERATION_USECASE_INVALID_USER_ID | 400 | INVALID_ARGUMENT | ユーザーIDが不正です | ユーザーIDの形式を確認してください |

### 認証・認可エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_USECASE_UNAUTHORIZED | 401 | UNAUTHENTICATED | 認証が必要です | ログインしてください |
| MODERATION_USECASE_FORBIDDEN | 403 | PERMISSION_DENIED | アクセスが禁止されています | アクセス権限を確認してください |
| MODERATION_USECASE_INSUFFICIENT_PERMISSION | 403 | PERMISSION_DENIED | 権限が不足しています | モデレーター権限が必要です |
| MODERATION_USECASE_NOT_MODERATOR | 403 | PERMISSION_DENIED | モデレーター権限がありません | 権限を確認してください |

### ビジネスロジックエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_USECASE_CONFLICT | 409 | ABORTED | リソースの競合が発生しました | 時間をおいて再試行してください |
| MODERATION_USECASE_PRECONDITION_FAILED | 412 | FAILED_PRECONDITION | 事前条件を満たしていません | 事前条件を確認してください |
| MODERATION_USECASE_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |
| MODERATION_USECASE_QUOTA_EXCEEDED | 429 | RESOURCE_EXHAUSTED | クォータを超過しました | 使用量を確認してください |

### モデレーション処理エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_USECASE_MODERATION_FAILED | 500 | INTERNAL | モデレーションに失敗しました | モデレーションシステムを確認してください |
| MODERATION_USECASE_AUTO_MODERATION_FAILED | 500 | INTERNAL | 自動モデレーションに失敗しました | 自動処理システムを確認してください |
| MODERATION_USECASE_MANUAL_REVIEW_REQUIRED | 202 | OK | 手動レビューが必要です | モデレーターによる確認を待ってください |
| MODERATION_USECASE_ESCALATION_REQUIRED | 202 | OK | エスカレーションが必要です | 上位モデレーターによる確認を待ってください |

### NSFW管理エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_USECASE_NSFW_OVERRIDE_FAILED | 500 | INTERNAL | NSFW判定の上書き適用に失敗しました | avion-mediaまたはavion-dropへのNSFWフラグ上書き指示が失敗しています。対象サービスの状態を確認し再試行してください |

### コンテンツ処理エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_USECASE_CONTENT_ANALYSIS_FAILED | 500 | INTERNAL | コンテンツ分析に失敗しました | 分析システムを確認してください |
| MODERATION_USECASE_TOXIC_CONTENT_DETECTED | 422 | INVALID_ARGUMENT | 有害コンテンツが検出されました | コンテンツを修正してください |
| MODERATION_USECASE_SPAM_DETECTED | 422 | INVALID_ARGUMENT | スパムが検出されました | コンテンツを見直してください |
| MODERATION_USECASE_HATE_SPEECH_DETECTED | 422 | INVALID_ARGUMENT | ヘイトスピーチが検出されました | コンテンツを修正してください |

## インフラストラクチャ層エラー

### データベースエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_INFRA_DATABASE_CONNECTION_FAILED | 503 | UNAVAILABLE | データベース接続失敗 | 接続設定を確認してください |
| MODERATION_INFRA_DATABASE_QUERY_FAILED | 500 | INTERNAL | クエリ実行失敗 | クエリを確認してください |
| MODERATION_INFRA_DATABASE_TRANSACTION_FAILED | 500 | INTERNAL | トランザクション失敗 | 再試行してください |

### ONNX Runtimeエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_INFRA_ONNX_MODEL_LOAD_FAILED | 500 | INTERNAL | ONNXモデルの読み込みに失敗しました | モデルファイルパスと形式を確認してください |
| MODERATION_INFRA_ONNX_INFERENCE_FAILED | 500 | INTERNAL | ONNX推論実行に失敗しました | 入力データの形式を確認してください |
| MODERATION_INFRA_ONNX_INFERENCE_TIMEOUT | 504 | DEADLINE_EXCEEDED | ONNX推論がタイムアウトしました | タイムアウト設定を確認してください |
| MODERATION_INFRA_ONNX_MODEL_UNAVAILABLE | 503 | UNAVAILABLE | ONNXモデルが利用できません | モデルファイルの存在を確認してください |

### 画像解析エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_INFRA_IMAGE_ANALYSIS_ERROR | 500 | INTERNAL | 画像解析エラー | 画像解析システムを確認してください |
| MODERATION_INFRA_IMAGE_PROCESSING_FAILED | 422 | INVALID_ARGUMENT | 画像処理に失敗しました | 画像ファイルを確認してください |
| MODERATION_INFRA_NSFW_DETECTION_FAILED | 500 | INTERNAL | NSFW検出に失敗しました | 検出システムを確認してください |

### テキスト解析エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_INFRA_TEXT_ANALYSIS_ERROR | 500 | INTERNAL | テキスト解析エラー | テキスト解析システムを確認してください |
| MODERATION_INFRA_SENTIMENT_ANALYSIS_FAILED | 500 | INTERNAL | 感情分析に失敗しました | 分析システムを確認してください |
| MODERATION_INFRA_LANGUAGE_DETECTION_FAILED | 500 | INTERNAL | 言語検出に失敗しました | 検出システムを確認してください |

### キャッシュエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_INFRA_CACHE_CONNECTION_FAILED | 503 | UNAVAILABLE | キャッシュ接続失敗 | 接続設定を確認してください |
| MODERATION_INFRA_CACHE_OPERATION_FAILED | 500 | INTERNAL | キャッシュ操作失敗 | 再試行してください |
| MODERATION_INFRA_CACHE_INVALIDATION_FAILED | 500 | INTERNAL | キャッシュ無効化失敗 | キャッシュシステムを確認してください |

### メッセージキューエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_INFRA_QUEUE_CONNECTION_FAILED | 503 | UNAVAILABLE | キュー接続失敗 | 接続設定を確認してください |
| MODERATION_INFRA_QUEUE_PUBLISH_FAILED | 500 | INTERNAL | メッセージ発行失敗 | 再試行してください |
| MODERATION_INFRA_QUEUE_CONSUME_FAILED | 500 | INTERNAL | メッセージ消費失敗 | メッセージ形式を確認してください |
| MODERATION_INFRA_QUEUE_FULL | 503 | UNAVAILABLE | キューが満杯です | しばらく待ってから再試行してください |

### インスタンスポリシー同期エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_INFRA_INSTANCE_POLICY_SYNC_FAILED | 502 | UNAVAILABLE | インスタンスポリシーのavion-activitypubへの同期に失敗しました | NATS JetStreamの接続状態とavion-activitypubサービスの状態を確認してください。`moderation.instance_policy.changed`イベントの発行が失敗した場合、リトライキューで自動再試行されます |

### 外部サービスエラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_INFRA_USER_SERVICE_ERROR | 502 | UNAVAILABLE | ユーザーサービスエラー | ユーザーサービスの状態を確認してください |
| MODERATION_INFRA_DROP_SERVICE_ERROR | 502 | UNAVAILABLE | Dropサービスエラー | Dropサービスの状態を確認してください |
| MODERATION_INFRA_NOTIFICATION_SERVICE_ERROR | 502 | UNAVAILABLE | 通知サービスエラー | 通知サービスの状態を確認してください |
| MODERATION_INFRA_COMMUNITY_SERVICE_ERROR | 502 | UNAVAILABLE | コミュニティサービスエラー | コミュニティサービスの状態を確認してください |

## ハンドラー層エラー

| エラーコード | HTTPステータス | gRPCステータス | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| MODERATION_HANDLER_BAD_REQUEST | 400 | INVALID_ARGUMENT | 不正なリクエスト | リクエスト形式を確認してください |
| MODERATION_HANDLER_PAYLOAD_TOO_LARGE | 413 | INVALID_ARGUMENT | ペイロードサイズ超過 | リクエストサイズを小さくしてください |
| MODERATION_HANDLER_UNSUPPORTED_MEDIA_TYPE | 415 | INVALID_ARGUMENT | サポートされないメディアタイプ | Content-Typeを確認してください |
| MODERATION_HANDLER_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |

## 関連ドキュメント

- [Avion エラーコード標準化ガイドライン](../common/errors/error-standards.md)
- [avion-moderation PRD](./prd.md)
- [avion-moderation Design Doc](./designdoc.md)
