# エラーカタログ: avion-system-admin

**Last Updated:** 2025/08/13  
**Service:** System Administration Service

## 概要

avion-system-adminサービスで発生する可能性のあるエラーコード一覧とその対処法です。

## ドメイン層エラー

### AdminOperation関連

| エラーコード | gRPCステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ADMIN_DOMAIN_OPERATION_NOT_FOUND | codes.NotFound | NOT_FOUND | 管理操作が見つかりません | 操作IDを確認してください |
| ADMIN_DOMAIN_OPERATION_ALREADY_EXISTS | codes.AlreadyExists | ALREADY_EXISTS | 管理操作が既に存在します | 既存の操作を確認してください |
| ADMIN_DOMAIN_DANGEROUS_OPERATION | 412 | FAILED_PRECONDITION | 危険な操作には承認が必要です | 上位管理者の承認を取得してください |
| ADMIN_DOMAIN_OPERATION_NOT_APPROVED | 412 | FAILED_PRECONDITION | 操作が承認されていません | 必要な承認を取得してください |
| ADMIN_DOMAIN_COOLDOWN_PERIOD_ACTIVE | 412 | FAILED_PRECONDITION | クールダウン期間中です | 指定時間後に再試行してください |

### SystemAudit関連

| エラーコード | gRPCステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ADMIN_DOMAIN_AUDIT_RECORD_NOT_FOUND | codes.NotFound | NOT_FOUND | 監査記録が見つかりません | 記録IDを確認してください |
| ADMIN_DOMAIN_AUDIT_CHAIN_BROKEN | 422 | DATA_LOSS | 監査チェーンが破損しています | システム管理者に連絡してください |
| ADMIN_DOMAIN_AUDIT_TAMPERING_DETECTED | 422 | DATA_LOSS | 監査ログの改竄が検出されました | セキュリティチームに即座に報告してください |

### PermissionSet関連

| エラーコード | gRPCステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ADMIN_DOMAIN_PERMISSION_NOT_FOUND | codes.NotFound | NOT_FOUND | 権限が見つかりません | 権限IDを確認してください |
| ADMIN_DOMAIN_PERMISSION_ALREADY_EXISTS | codes.AlreadyExists | ALREADY_EXISTS | 権限が既に存在します | 既存の権限を確認してください |
| ADMIN_DOMAIN_PERMISSION_DENIED | codes.PermissionDenied | PERMISSION_DENIED | 権限が拒否されました | 必要な権限を確認してください |
| ADMIN_DOMAIN_NO_OWNER_PERMISSION | codes.PermissionDenied | PERMISSION_DENIED | オーナー権限が必要です | オーナー権限を持つ管理者に依頼してください |
| ADMIN_DOMAIN_CIRCULAR_PERMISSION | codes.InvalidArgument | INVALID_ARGUMENT | 権限の循環参照が検出されました | 権限階層を見直してください |

### Announcement関連

| エラーコード | gRPCステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ADMIN_DOMAIN_ANNOUNCEMENT_NOT_FOUND | codes.NotFound | NOT_FOUND | アナウンスが見つかりません | アナウンスIDを確認してください |
| ADMIN_DOMAIN_ANNOUNCEMENT_ALREADY_SENT | codes.AlreadyExists | ALREADY_EXISTS | アナウンスは既に送信済みです | 新しいアナウンスを作成してください |
| ADMIN_DOMAIN_ANNOUNCEMENT_EXPIRED | 412 | FAILED_PRECONDITION | アナウンスの有効期限が切れています | 有効期限を更新してください |
| ADMIN_DOMAIN_INVALID_ANNOUNCEMENT | codes.InvalidArgument | INVALID_ARGUMENT | アナウンスの内容が不正です | アナウンス内容を修正してください |

### SystemConfiguration関連

| エラーコード | gRPCステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ADMIN_DOMAIN_CONFIG_NOT_FOUND | codes.NotFound | NOT_FOUND | 設定が見つかりません | 設定キーを確認してください |
| ADMIN_DOMAIN_CONFIG_READONLY | codes.PermissionDenied | PERMISSION_DENIED | 設定は読み取り専用です | 別の設定を使用してください |
| ADMIN_DOMAIN_CONFIG_INVALID_VALUE | codes.InvalidArgument | INVALID_ARGUMENT | 設定値が不正です | 設定値の形式を確認してください |
| ADMIN_DOMAIN_CONFIG_DEPENDENCY_ERROR | 412 | FAILED_PRECONDITION | 設定の依存関係エラー | 依存する設定を先に変更してください |
| ADMIN_DOMAIN_CONFIG_ROLLBACK_FAILED | codes.Internal | INTERNAL | 設定のロールバックに失敗しました | システム管理者に連絡してください |

### BackupPolicy関連

| エラーコード | gRPCステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ADMIN_DOMAIN_BACKUP_NOT_FOUND | codes.NotFound | NOT_FOUND | バックアップが見つかりません | バックアップIDを確認してください |
| ADMIN_DOMAIN_BACKUP_IN_PROGRESS | 423 | ALREADY_EXISTS | バックアップ実行中です | 完了を待ってから再試行してください |
| ADMIN_DOMAIN_BACKUP_CORRUPTED | 422 | DATA_LOSS | バックアップが破損しています | 別のバックアップを使用してください |
| ADMIN_DOMAIN_RESTORE_FAILED | codes.DataLoss | DATA_LOSS | リストアに失敗しました | ログを確認し、再試行してください |

### SystemMetrics関連

| エラーコード | gRPCステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ADMIN_DOMAIN_METRICS_NOT_AVAILABLE | codes.NotFound | NOT_FOUND | メトリクスが利用できません | 期間を変更してください |
| ADMIN_DOMAIN_INVALID_TIME_RANGE | codes.InvalidArgument | INVALID_ARGUMENT | 無効な時間範囲です | 開始時刻と終了時刻を確認してください |
| ADMIN_DOMAIN_ANOMALY_DETECTED | 412 | FAILED_PRECONDITION | 異常が検出されました | システム状態を確認してください |

## ユースケース層エラー

### 入力検証エラー

| エラーコード | gRPCステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ADMIN_USECASE_INVALID_INPUT | codes.InvalidArgument | INVALID_ARGUMENT | 入力値が不正です | 入力値を確認してください |
| ADMIN_USECASE_MISSING_REQUIRED | codes.InvalidArgument | INVALID_ARGUMENT | 必須項目が不足しています | 必須項目を入力してください |
| ADMIN_USECASE_INVALID_TIME_RANGE | codes.InvalidArgument | INVALID_ARGUMENT | 無効な時間範囲です | 時間範囲を修正してください |

### 認証・認可エラー

| エラーコード | gRPCステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ADMIN_USECASE_UNAUTHORIZED | codes.Unauthenticated | UNAUTHENTICATED | 認証が必要です | ログインしてください |
| ADMIN_USECASE_FORBIDDEN | codes.PermissionDenied | PERMISSION_DENIED | アクセスが禁止されています | アクセス権限を確認してください |
| ADMIN_USECASE_INSUFFICIENT_PRIVILEGE | codes.PermissionDenied | PERMISSION_DENIED | 権限が不足しています | 上位権限者に依頼してください |
| ADMIN_USECASE_SESSION_EXPIRED | codes.Unauthenticated | UNAUTHENTICATED | セッションが期限切れです | 再ログインしてください |

### ビジネスロジックエラー

| エラーコード | gRPCステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ADMIN_USECASE_CONFLICT | codes.Aborted | ABORTED | リソースの競合が発生しました | 時間をおいて再試行してください |
| ADMIN_USECASE_PRECONDITION_FAILED | 412 | FAILED_PRECONDITION | 事前条件を満たしていません | 事前条件を確認してください |
| ADMIN_USECASE_OPERATION_LIMIT | codes.ResourceExhausted | RESOURCE_EXHAUSTED | 操作制限に達しました | 制限がリセットされるまで待ってください |
| ADMIN_USECASE_APPROVAL_REQUIRED | 412 | FAILED_PRECONDITION | 承認が必要です | 承認者に承認を依頼してください |

### システム管理特有のエラー

| エラーコード | gRPCステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ADMIN_USECASE_MAINTENANCE_MODE | codes.Unavailable | UNAVAILABLE | メンテナンスモード中です | メンテナンス終了まで待ってください |
| ADMIN_USECASE_EMERGENCY_MODE | codes.Unavailable | UNAVAILABLE | 緊急モード中です | システム管理者の対応を待ってください |
| ADMIN_USECASE_ROLLBACK_REQUIRED | 412 | FAILED_PRECONDITION | ロールバックが必要です | ロールバック手順を実行してください |
| ADMIN_USECASE_DEPENDENCY_FAILURE | 412 | FAILED_PRECONDITION | 依存サービスの障害 | 依存サービスの復旧を待ってください |

## インフラストラクチャ層エラー

### データベースエラー

| エラーコード | gRPCステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ADMIN_INFRA_DATABASE_CONNECTION_FAILED | codes.Unavailable | UNAVAILABLE | データベース接続失敗 | 接続設定を確認してください |
| ADMIN_INFRA_DATABASE_QUERY_FAILED | codes.Internal | INTERNAL | クエリ実行失敗 | クエリを確認してください |
| ADMIN_INFRA_DATABASE_TRANSACTION_FAILED | codes.Internal | INTERNAL | トランザクション失敗 | 再試行してください |
| ADMIN_INFRA_DATABASE_DEADLOCK | 423 | ABORTED | デッドロック検出 | 時間をおいて再試行してください |
| ADMIN_INFRA_DATABASE_CONSTRAINT_VIOLATION | codes.InvalidArgument | INVALID_ARGUMENT | 制約違反 | データを確認してください |

### キャッシュエラー

| エラーコード | gRPCステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ADMIN_INFRA_CACHE_CONNECTION_FAILED | codes.Unavailable | UNAVAILABLE | キャッシュ接続失敗 | 接続設定を確認してください |
| ADMIN_INFRA_CACHE_OPERATION_FAILED | codes.Internal | INTERNAL | キャッシュ操作失敗 | 再試行してください |
| ADMIN_INFRA_CACHE_KEY_NOT_FOUND | codes.NotFound | NOT_FOUND | キャッシュキーが見つかりません | キャッシュが再生成されるまで待ってください |
| ADMIN_INFRA_CACHE_LOCK_FAILED | codes.Internal | INTERNAL | キャッシュロック取得失敗 | 時間をおいて再試行してください |

### ストレージエラー

| エラーコード | gRPCステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ADMIN_INFRA_STORAGE_CONNECTION_FAILED | codes.Unavailable | UNAVAILABLE | ストレージ接続失敗 | 接続設定を確認してください |
| ADMIN_INFRA_STORAGE_UPLOAD_FAILED | codes.Internal | INTERNAL | アップロード失敗 | 再試行してください |
| ADMIN_INFRA_STORAGE_DOWNLOAD_FAILED | codes.Internal | INTERNAL | ダウンロード失敗 | 再試行してください |
| ADMIN_INFRA_STORAGE_DELETE_FAILED | codes.Internal | INTERNAL | 削除失敗 | 再試行してください |
| ADMIN_INFRA_STORAGE_QUOTA_EXCEEDED | 507 | RESOURCE_EXHAUSTED | ストレージ容量超過 | 不要なファイルを削除してください |

### 外部サービスエラー

| エラーコード | gRPCステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ADMIN_INFRA_EXTERNAL_SERVICE_ERROR | codes.Internal | INTERNAL | 外部サービスエラー | サービス状態を確認してください |
| ADMIN_INFRA_EXTERNAL_SERVICE_TIMEOUT | 408 | DEADLINE_EXCEEDED | 外部サービスタイムアウト | 時間をおいて再試行してください |
| ADMIN_INFRA_EXTERNAL_SERVICE_UNAVAILABLE | codes.Unavailable | UNAVAILABLE | 外部サービス利用不可 | サービス復旧を待ってください |

### その他のインフラエラー

| エラーコード | gRPCステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| ADMIN_INFRA_METRICS_COLLECTION_FAILED | codes.Internal | INTERNAL | メトリクス収集失敗 | メトリクスソースを確認してください |
| ADMIN_INFRA_EVENT_PUBLISH_FAILED | codes.Internal | INTERNAL | イベント発行失敗 | イベントバスの状態を確認してください |
| ADMIN_INFRA_NETWORK_TIMEOUT | 408 | DEADLINE_EXCEEDED | ネットワークタイムアウト | ネットワーク接続を確認してください |
| ADMIN_INFRA_NETWORK_CONNECTION_REFUSED | codes.Unavailable | UNAVAILABLE | 接続拒否 | 対象サービスの状態を確認してください |

## 関連ドキュメント

- [Avion エラーコード標準化ガイドライン](../common/errors/error-standards.md)
- [avion-system-admin PRD](./prd.md)
- [avion-system-admin Design Doc](./designdoc.md)