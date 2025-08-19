# Design Doc: avion-system-admin

**Author:** Claude Code
**Last Updated:** 2025/08/13
**Review Status:** .cursor/rules準拠

## 1. Summary (これは何？)

- **一言で:** Avionにおけるシステム管理機能（設定管理、アナウンス、統計、レート制限、バックアップ）を提供するマイクロサービスを実装します。
- **目的:** プラットフォーム全体の安定運用、設定の一元管理、メトリクス収集と分析、運用タスクの自動化、災害復旧体制の確立を提供します。

## テスト戦略

このサービスでは、[共通テスト戦略](../common/testing-strategy.md)に従ってテストを実装します。

### テスト方針
- **TDD必須**: インターフェース定義 → テスト作成 → 実装の順序を厳守
- **カバレッジ目標**: ユニットテスト85%以上、クリティカルパス95%以上
- **テーブル駆動テスト**: 全テストで必須
- **モック生成**: `go.uber.org/mock/gomock`使用

詳細は[共通テスト戦略ドキュメント](../common/testing-strategy.md)を参照してください。

### システム管理サービス特有のテスト要件
- **管理者権限テスト**: 特別なタグ付きテストスイート (`admin_tests`) での権限制御テスト
- **セキュリティテスト**: 認証・認可・リスクアセスメントのテスト (`security_tests`)
- **監査ログ完全性テスト**: 管理者操作の監査証跡生成の完全性検証
- **コンプライアンステスト**: 特別なタグ付きテストスイート (`compliance_tests`) でのコンプライアンス要件確認
- **危険操作安全性テスト**: システム全体に影響する操作の安全性検証
- **バックアップ・リストア統合テスト**: データの完全性とリストア可能性の検証

### E2Eテスト

このサービスのE2Eテストは、[共通E2Eテスト戦略](../common/e2e-testing-strategy.md)に従って実装します。

#### 主要なE2Eテストシナリオ
- システム管理者ログインから管理ダッシュボード表示まで
- ユーザー管理機能（制裁、アカウント操作）の完全実行
- インスタンス設定変更と全サービスへの反映確認
- システム統計とメトリクス収集・表示機能
- バックアップ実行からリストア完了までの完全サイクル
- 監査ログ生成と検索・エクスポート機能
- 緊急時システム停止・復旧機能の実行確認
- コンプライアンスレポート生成と出力確認

詳細は[共通E2Eテスト戦略ドキュメント](../common/e2e-testing-strategy.md)を参照してください。

## 3. 技術スタック

このサービスでは、[共通Goバックエンド技術スタックガイドライン](../common/architecture/go-backend-framework.md)に従った実装を行います。

### 主要技術
- **HTTPルーティング:** Chi v5
- **RPC:** ConnectRPC
- **ミドルウェア:** 標準net/httpベースの共通ミドルウェア

詳細な実装パターンおよびライブラリの使用方法については、[ガイドライン](../common/architecture/go-backend-framework.md)を参照してください。

## 4. Configuration Management (設定管理)

このサービスでは、[共通環境変数管理パターン](../common/infrastructure/environment-variables.md)に従って設定管理を実装します。

### 4.1. Environment Variables (環境変数)

#### Required Variables (必須環境変数)
- `DATABASE_URL`: PostgreSQL接続URL
- `REDIS_URL`: Redis接続URL  
- `ADMIN_API_KEY`: 管理者APIアクセスキー

#### Optional Variables (オプション環境変数)
- `PORT`: HTTPサーバーポート (default: 8090)
- `GRPC_PORT`: gRPCサーバーポート (default: 9100)
- `METRICS_PORT`: メトリクスサーバーポート (default: 9200)
- `LOG_LEVEL`: ログレベル (default: info)

### 4.2. Config Struct Implementation (設定構造体実装)

```go
// internal/infrastructure/config/config.go
package config

type Config struct {
    Server      ServerConfig
    Database    DatabaseConfig
    Redis       RedisConfig
    Admin       AdminConfig
    Metrics     MetricsConfig
    Logging     LoggingConfig
}

type ServerConfig struct {
    Port     int    `env:"PORT" required:"false" default:"8090"`
    GRPCPort int    `env:"GRPC_PORT" required:"false" default:"9100"`
}

type DatabaseConfig struct {
    URL string `env:"DATABASE_URL" required:"true"`
}

type RedisConfig struct {
    URL string `env:"REDIS_URL" required:"true"`
}

type AdminConfig struct {
    APIKey string `env:"ADMIN_API_KEY" required:"true" secret:"true"`
}

type MetricsConfig struct {
    Port int `env:"METRICS_PORT" required:"false" default:"9200"`
}

type LoggingConfig struct {
    Level string `env:"LOG_LEVEL" required:"false" default:"info"`
}
```

### 4.3. Configuration Loading (設定読み込み)

設定の読み込みと検証は、サービス起動時に実行され、必須環境変数が不足している場合は早期失敗（Fail Fast）します。

```go
func LoadConfig() (*Config, error) {
    loader := NewDefaultEnvironmentLoader()
    config := &Config{}
    
    if err := LoadFromEnvironment(loader, config); err != nil {
        return nil, fmt.Errorf("failed to load configuration: %w", err)
    }
    
    if err := ValidateConfig(config); err != nil {
        return nil, fmt.Errorf("configuration validation failed: %w", err)
    }
    
    return config, nil
}
```

## 5. Background & Links (背景と関連リンク)

- SNSプラットフォームの安定運用はサービス品質とユーザー信頼の基盤。
- システム管理機能をモデレーションから分離し、インフラ運用に特化したサービスを構築。
- データ駆動による意思決定と自動化により、運用負荷を軽減し効率化を実現。
- [PRD: avion-system-admin](./prd.md)
- [Avion アーキテクチャ概要](../common/architecture.md)
- [avion-moderation Design Doc](../avion-moderation/designdoc.md)
- [avion-gateway Design Doc](../avion-gateway/designdoc.md)

---

## 6. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

- アナウンスの作成、配信、管理を行うgRPC APIの実装
- システム設定の管理と配信を行うgRPC APIの実装
- レート制限ルールの管理と評価を行うgRPC APIの実装
- メトリクス収集と統計分析を行うgRPC APIの実装
- バックアップ・リストア機能の実装
- 管理者権限と監査ログの管理
- システムデータのPostgreSQLへの永続化
- 設定とメトリクスのRedisキャッシュ
- システムイベントの発行（Redis Pub/Sub）
- 管理ダッシュボード用REST APIの提供
- Go言語で実装し、Kubernetes上でのステートレス運用
- OpenTelemetryによるトレーシング・メトリクス・ロギング対応

### Non-Goals (やらないこと)

- **コンテンツモデレーション:** `avion-moderation` が担当
- **通報処理:** `avion-moderation` が担当
- **違反対応:** `avion-moderation` が担当
- **ユーザー認証:** `avion-auth` が担当
- **コンテンツ作成:** `avion-drop` が担当
- **メディア処理:** `avion-media` が担当
- **直接的な通知配信:** `avion-notification` が担当
- **検索インデックス管理:** `avion-search` が担当

## 7. Architecture (どうやって作る？)

### 5.1. レイヤードアーキテクチャ (DDD準拠)

> **重要**: 本アーキテクチャは[Avion共通開発ガイドライン - ドメイン駆動設計（DDD）](../common/development-guidelines.md#2-ドメイン駆動設計ddd)に完全準拠し、Handler/UseCase/Domain/Infrastructureの4層構造を厳守します。

#### Domain Layer (ドメイン層)

システム管理機能に特化したドメインモデル。監査証跡、権限管理、危険操作の制御、コンプライアンス要件を中心とした設計。

##### Aggregates (集約)

###### Announcement Aggregate
**責務**: アナウンスのライフサイクルと整合性を管理する中核的な集約
- **集約ルート**: Announcement
- **不変条件**:
  - AnnouncementIDは一意（UUID v4形式）
  - 配信済みアナウンスの内容変更不可（承認フロー必須）
  - 期間設定の妥当性（publishAt < expireAt、未来の日時のみ）
  - 対象ユーザーの整合性（存在しないユーザー・グループは除外）
  - 重要度レベルは定義された値（info, warning, critical）のいずれか
  - Titleは最大200文字、Contentは最大5000文字（HTMLタグ検証含む）
  - TargetTypeは定義された値（all, group, individual）のいずれか
  - 下書き状態からのみ公開可能（状態遷移の厳密性）
  - critical重要度の場合は必ず承認が必要
  - システムメンテナンス期間中は緊急アナウンスのみ配信可能
- **ドメインロジック**:
  - `draft(title, content, targetType, createdBy)`: 下書き作成（権限チェック含む）
  - `publish(publishAt, approvedBy)`: アナウンス配信（承認者検証）
  - `schedule(publishAt, expireAt)`: 配信スケジュール設定（時間窓検証）
  - `trackReadRate(readCount, totalTargets)`: 既読率追跡（統計更新）
  - `expire()`: 期限切れ処理（自動アーカイブ）
  - `translate(languageCode, translatedTitle, translatedContent)`: 多言語版追加
  - `canBeEditedBy(adminID, adminRole)`: 編集権限の判定（階層権限モデル）
  - `shouldNotify()`: 通知すべきかの判定（スパム防止・重複排除）
  - `validate()`: Announcement全体の妥当性検証（セキュリティスキャン含む）
  - `requiresApproval()`: 承認要否の判定（内容・対象・重要度ベース）
  - `auditEdit(adminID, changes, reason)`: 編集操作の監査記録

###### SystemConfiguration Aggregate
**責務**: システム設定の管理（危険操作制御・段階的適用・ロールバック機能）
- **集約ルート**: SystemConfiguration
- **不変条件**:
  - ConfigurationID は一意（設定キー単位）
  - 設定値の妥当性検証（型・範囲・依存関係）
  - 設定変更の権限チェック（階層権限・リソースレベル権限）
  - バックアップ作成必須（変更前の状態保存）
  - バージョン管理の一貫性（順次採番・重複不可）
  - 機密設定の暗号化必須（パスワード・APIキー等）
  - 本番環境の設定変更は承認必須
  - サービス再起動が必要な設定は計画的変更のみ
- **ドメインロジック**:
  - `updateSetting(key, value, changedBy, reason)`: 設定更新（承認フロー統合）
  - `validateConfiguration(key, value)`: 設定検証（依存関係・制約チェック）
  - `createBackup()`: バックアップ作成（整合性チェック付き）
  - `rollback(targetVersion, authorizedBy)`: 設定のロールバック（安全確認）
  - `applyGradually(percentage, monitoringEnabled)`: 段階的適用（カナリア配信）
  - `compareVersions(v1, v2)`: バージョン比較（diff生成）
  - `isDangerous()`: 危険操作判定（サービス停止リスク評価）
  - `calculateImpact()`: 影響範囲分析（依存サービス・ユーザー影響）
  - `requiresApproval()`: 承認要否判定（設定種別・環境・影響度）
  - `encryptSensitiveValues()`: 機密情報の暗号化
  - `auditConfigChange(adminID, before, after, reason)`: 設定変更の監査記録

###### RateLimitRule Aggregate
**責務**: レート制限ルールの管理（動的調整・効果測定・DDoS対策）
- **集約ルート**: RateLimitRule
- **不変条件**:
  - RuleID は一意（エンドポイント・制限タイプ組み合わせ単位）
  - 制限値の妥当性（最小値1/秒、最大値10000/秒）
  - ルールの優先順位の一意性（同一エンドポイント内）
  - 時間窓の妥当性（1秒以上、24時間以下）
  - バースト制限 <= 通常制限 * 10（現実的な範囲）
  - ホワイトリストとブラックリストの相互排他性
  - 緊急時ルールは管理者権限のみ設定可能
- **ドメインロジック**:
  - `applyRule(request, context)`: ルール適用（リアルタイム判定）
  - `evaluateLimit(clientID, endpoint)`: 制限評価（現在状況確認）
  - `adjustLimit(newLimit, reason, adjustedBy)`: 動的調整（自動・手動）
  - `calculateBurst(baseRate, peakMultiplier)`: バースト許容量計算
  - `mergeRules(rules)`: ルール統合（競合解決）
  - `isWhitelisted(clientID, ip)`: ホワイトリスト判定
  - `isBlacklisted(clientID, ip)`: ブラックリスト判定
  - `detectAnomalousTraffic()`: 異常トラフィック検知
  - `activateEmergencyMode()`: 緊急制限モード（DDoS対応）
  - `measureEffectiveness()`: 制限効果測定（統計分析）
  - `auditRuleChange(adminID, before, after, reason)`: ルール変更の監査記録

###### AdminUser Aggregate
**責務**: 管理者ユーザーの管理（権限階層・監査・セキュリティ制御）
- **集約ルート**: AdminUser
- **不変条件**:
  - AdminID は一意（システム全体でユニーク）
  - 最低1名のスーパー管理者必須（システム保護）
  - 権限の階層制約（下位権限者は上位権限者を変更不可）
  - 二要素認証の強制（super_admin, adminロール）
  - パスワード複雑性要件（大文字・小文字・数字・記号）
  - セッション有効期限の強制（最大24時間）
  - 連続ログイン失敗によるアカウントロック（5回で15分）
  - 管理者権限の定期見直し必須（90日間未使用で無効化検討）
- **ドメインロジック**:
  - `grantPermission(resource, action, scope, grantedBy)`: 権限付与（階層チェック）
  - `revokePermission(resource, action, revokedBy)`: 権限剥奪（影響評価）
  - `canPerform(operation, resource, context)`: アクション可否判定（動的権限）
  - `enforce2FA()`: 二要素認証強制（セキュリティレベル向上）
  - `auditAction(operation, result, risk)`: 操作監査（完全ログ記録）
  - `validatePasswordStrength(password)`: パスワード強度検証
  - `trackLoginAttempt(ip, userAgent, success)`: ログイン試行追跡
  - `calculateRiskScore(behavior, context)`: リスクスコア計算（異常行動検知）
  - `suspendAccount(reason, suspendedBy)`: アカウント停止（緊急時）
  - `requireApprovalFor(operation)`: 承認要求操作判定（高リスク操作）
  - `generateAuditReport()`: 監査レポート生成（コンプライアンス対応）

###### SystemMetrics Aggregate
**責務**: システムメトリクスの収集と分析（異常検知・予測・アラート）
- **集約ルート**: SystemMetrics
- **不変条件**:
  - MetricID は一意（名前・タイムスタンプ・ラベル組み合わせ）
  - 時系列データの順序性（タイムスタンプ昇順）
  - 集計期間の整合性（開始 < 終了、重複なし）
  - メトリクス値の妥当性（数値型、非負値）
  - データ保持期間の制約（詳細90日、集計3年）
  - 重要メトリクスの欠損許容時間（5分以内）
- **ドメインロジック**:
  - `collect(source, metrics, timestamp)`: メトリクス収集（重複排除）
  - `aggregate(timeRange, granularity, method)`: データ集計（統計処理）
  - `analyze(pattern, algorithm)`: トレンド分析（機械学習活用）
  - `forecast(horizon, confidence)`: 予測（容量計画支援）
  - `detectAnomaly(threshold, sensitivity)`: 異常検知（統計的・ML手法）
  - `generateAlert(condition, severity)`: アラート生成（通知制御）
  - `calculateSLA(metrics, targets)`: SLA計算（可用性・性能）
  - `identifyBottlenecks()`: ボトルネック特定（パフォーマンス最適化）
  - `correlateMetrics(primary, secondary)`: メトリクス相関分析
  - `archiveOldData(cutoffDate)`: 古いデータのアーカイブ（保持期間管理）

###### BackupPolicy Aggregate
**責務**: バックアップポリシーの管理（品質保証・暗号化・災害復旧）
- **集約ルート**: BackupPolicy
- **不変条件**:
  - PolicyID は一意（ポリシー名単位）
  - スケジュールの妥当性（cron式検証・重複回避）
  - 保持期間の制約（最低7日、最大10年）
  - ストレージ容量の確認（使用量 < 制限の80%）
  - 暗号化の強制（機密データ含む場合）
  - 3-2-1バックアップルールの遵守（3コピー、2種メディア、1オフサイト）
  - テストリストアの定期実行（月1回以上）
- **ドメインロジック**:
  - `executeBackup(type, scope)`: バックアップ実行（品質チェック付き）
  - `verifyIntegrity(backupID)`: 整合性検証（チェックサム・部分復元）
  - `rotateBackups(policy)`: 世代管理（保持期間・容量最適化）
  - `calculateStorage(data, compression)`: 必要容量計算（圧縮効果含む）
  - `restoreData(backupID, targetScope, authorized)`: データ復元（権限確認）
  - `testRestore(backupID, scope)`: リストアテスト（定期品質確認）
  - `encryptBackup(data, keyVersion)`: バックアップ暗号化（KMS連携）
  - `distributeBackup(locations)`: 地理的分散（災害対策）
  - `monitorBackupHealth()`: バックアップ健全性監視
  - `generateRecoveryPlan()`: 復旧計画生成（RTO/RPO最適化）
  - `auditBackupAccess(adminID, operation, backupID)`: バックアップアクセス監査

##### Entities (エンティティ)

###### AnnouncementTarget
**所属**: Announcement Aggregate
**責務**: アナウンス対象の管理（精密なターゲティング・除外制御）
- **不変条件**: 対象・除外の重複チェック、存在確認
- **属性**: TargetType、TargetIDs、Conditions、ExclusionList、EstimatedReach

###### ConfigurationVersion  
**所属**: SystemConfiguration Aggregate
**責務**: 設定バージョンの管理（変更履歴・承認フロー・ロールバック支援）
- **不変条件**: バージョン順序性、承認者権限、変更理由必須
- **属性**: VersionID、ConfigData、ChangedBy、ChangedAt、ChangeLog、ApprovalStatus

###### RateLimitWindow
**所属**: RateLimitRule Aggregate  
**責務**: レート制限の時間窓管理（アルゴリズム実装・パフォーマンス最適化）
- **不変条件**: 時間窓タイプ整合性、補充レート妥当性
- **属性**: WindowType、Duration、BurstSize、RefillRate、CurrentUsage

###### Permission
**所属**: AdminUser Aggregate
**責務**: 権限情報の管理（詳細権限・条件付きアクセス・時間制限）
- **不変条件**: 権限階層整合性、リソース存在確認
- **属性**: Resource、Action、Scope、Constraints、ExpiresAt、GrantedBy

###### MetricDataPoint
**所属**: SystemMetrics Aggregate
**責務**: メトリクスデータポイントの管理（時系列最適化・集計支援）
- **不変条件**: 時刻順序性、値の妥当性、ラベル整合性
- **属性**: Timestamp、Value、Tags、Aggregation、Reliability、Source

###### BackupRecord
**所属**: BackupPolicy Aggregate
**責務**: バックアップ履歴の管理（品質追跡・復旧支援・監査証跡）
- **不変条件**: 整合性確認済み、暗号化済み、複製確認済み
- **属性**: BackupID、BackupType、Status、Location、Size、Checksum、EncryptionKey

##### Value Objects (値オブジェクト)

**システム管理特化の値オブジェクト設計**

**識別子関連**（UUID v4、改竄検知機能付き）
- AnnouncementID, ConfigurationID, RuleID, AdminID, MetricID, BackupID

**権限・セキュリティ関連**
- Role（super_admin > admin > operator > viewer）
- PermissionLevel（manage > delete > write > read）
- ResourceType（system, user, data, config, backup）
- SecurityContext（IP制限、時間制限、MFA要求）

**設定・制御関連**  
- ConfigurationKey（型安全・検証ルール内蔵）
- ConfigurationValue（型付き・暗号化対応）
- FeatureFlag（有効/無効/段階的・対象条件付き）
- MaintenanceWindow（計画停止・緊急停止・影響範囲）

**レート制限・保護関連**
- RateLimit（適応制御・異常検知）
- BurstLimit（攻撃対応・正常使用保護）  
- ThrottleStrategy（段階的制限・回復制御）
- EmergencyMode（DDoS対応・システム保護）

**監視・分析関連**
- TimeRange（時区管理・サマータイム対応）
- AggregationType（統計手法・信頼区間）
- MetricValue（単位変換・精度管理）
- AlertThreshold（動的調整・False Positive抑制）

**バックアップ・復旧関連**
- BackupSchedule（cron拡張・競合回避）
- RetentionPolicy（法的要件・コスト最適化）
- StorageLocation（地理的分散・アクセス制御）
- RecoveryObjective（RTO/RPO・優先度管理）

##### Domain Services (ドメインサービス)

###### ConfigurationValidationService
**責務**: 設定値の妥当性検証（複雑な依存関係・セキュリティ検証）
- `validateSetting(key, value, context)`: 個別設定の検証（型・範囲・形式）
- `validateConsistency(configSet)`: 設定間の整合性検証（依存関係解析）
- `checkDependencies(key, value)`: 依存関係チェック（循環参照検出）
- `simulateChange(changes)`: 変更影響シミュレーション（リスク評価）
- `validateSecurity(config)`: セキュリティポリシー検証（脆弱性検査）

###### MetricsAnalysisService  
**責務**: メトリクスの高度な分析（機械学習・予測・最適化提案）
- `detectTrend(timeSeries, algorithm)`: トレンド検出（統計的・ML手法）
- `forecastUsage(metrics, horizon)`: 使用量予測（容量計画）
- `identifyBottleneck(systemMetrics)`: ボトルネック特定（相関分析）
- `recommendOptimization(analysis)`: 最適化提案（AI支援）
- `calculateSLI(metrics, objectives)`: SLI計算（信頼性工学）

###### BackupOrchestrationService
**責務**: バックアップ処理の調整（複雑な依存関係・品質保証）
- `scheduleBackup(policy, dependencies)`: バックアップスケジューリング（依存解決）
- `coordinateBackup(components)`: バックアップ調整（一貫性保証）
- `verifyBackup(backupID, depth)`: バックアップ検証（多段階確認）
- `testRestore(strategy, scope)`: リストアテスト（定期品質確認）
- `optimizeStorage(usage, cost)`: ストレージ最適化（コスト効率）

###### AdminSecurityService
**責務**: 管理者のセキュリティ制御（脅威検知・アクセス制御・監査）
- `authenticateAdmin(credentials, context)`: 管理者認証（多要素・リスク評価）
- `authorizeOperation(admin, operation, resource)`: 操作認可（動的権限）
- `detectSuspiciousBehavior(admin, activity)`: 異常行動検知（AI支援）
- `enforceSecurityPolicy(context)`: セキュリティポリシー強制
- `generateComplianceReport(period, regulations)`: コンプライアンスレポート

###### AnnouncementSecurityService
**責務**: アナウンスのセキュリティ検証（コンテンツ検査・配信制御）
- `scanContent(title, content)`: コンテンツスキャン（XSS・悪意コード検出）
- `validateTargeting(targets, permissions)`: ターゲティング妥当性（権限確認）
- `checkSpamRisk(content, frequency)`: スパムリスク評価（頻度・パターン分析）
- `enforceApprovalPolicy(announcement)`: 承認ポリシー強制（階層・内容ベース）

- **Repository Interfaces:**
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../tests/domain/repository/mock_announcement_repository.go -package=repository
  type AnnouncementRepository interface {
      Create(ctx context.Context, announcement *Announcement) error
      FindByID(ctx context.Context, id AnnouncementID) (*Announcement, error)
      FindActive(ctx context.Context, currentTime time.Time) ([]*Announcement, error)
      Update(ctx context.Context, announcement *Announcement) error
      Delete(ctx context.Context, id AnnouncementID) error
      FindByAdminID(ctx context.Context, adminID AdminID) ([]*Announcement, error)
      FindPendingApproval(ctx context.Context) ([]*Announcement, error)
  }
  ```

## 概要

本ドキュメントは、avion-system-adminサービスの技術設計を定義する。avion-system-adminはプラットフォーム全体のシステム管理機能を提供し、設定管理、アナウンス配信、統計収集、レート制限、バックアップ管理を通じて、安定したプラットフォーム運営を実現する。

#### Use Case Layer (ユースケース層)
- **Command Use Cases:**
  - CreateAnnouncementCommandUseCase: アナウンス作成
  - UpdateSystemConfigurationCommandUseCase: システム設定更新
  - SetRateLimitRuleCommandUseCase: レート制限設定
  - ExecuteBackupCommandUseCase: バックアップ実行
  - RestoreBackupCommandUseCase: バックアップリストア
  - CreateAdminUserCommandUseCase: 管理者作成
- **Query Use Cases:**
  - GetAnnouncementsQueryUseCase: アナウンス一覧取得
  - GetSystemConfigurationQueryUseCase: システム設定取得
  - GetSystemMetricsQueryUseCase: システムメトリクス取得
  - GetBackupHistoryQueryUseCase: バックアップ履歴取得
  - GetAdminAuditLogQueryUseCase: 監査ログ取得
  - GetRateLimitMetricsQueryUseCase: レート制限メトリクス取得
- **Query Service Interfaces:**
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../tests/usecase/query/mock_metrics_query_service.go -package=query
  type MetricsQueryService interface {
      GetSystemMetrics(ctx context.Context, period TimeRange) (*MetricsDTO, error)
      GetUserStatistics(ctx context.Context, period TimeRange) (*UserStatsDTO, error)
      GetStorageStatistics(ctx context.Context) (*StorageStatsDTO, error)
  }
  ```
- **External Service Interfaces:**
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../tests/usecase/external/mock_storage_service.go -package=external
  type StorageService interface {
      Upload(ctx context.Context, key string, data io.Reader) error
      Download(ctx context.Context, key string) (io.ReadCloser, error)
      Delete(ctx context.Context, key string) error
  }
  ```

#### CQRS Pattern Implementation (CQRS パターン実装)

本サービスはCQRS（Command Query Responsibility Segregation）パターンを厳密に実装し、システム操作（Command）とデータ参照（Query）を完全に分離します。

##### Command Side Implementation (コマンド側実装)

**Command Handler インターfaces:**
```go
//go:generate mockgen -source=$GOFILE -destination=../../tests/usecase/command/mock_command_handler.go -package=command

// System Operations Command Handlers
type CreateAnnouncementCommandHandler interface {
    Handle(ctx context.Context, cmd *CreateAnnouncementCommand) (*CreateAnnouncementResult, error)
}

type UpdateSystemConfigurationCommandHandler interface {
    Handle(ctx context.Context, cmd *UpdateSystemConfigurationCommand) (*UpdateSystemConfigurationResult, error)
}

type SetRateLimitRuleCommandHandler interface {
    Handle(ctx context.Context, cmd *SetRateLimitRuleCommand) (*SetRateLimitRuleResult, error)
}

type ExecuteBackupCommandHandler interface {
    Handle(ctx context.Context, cmd *ExecuteBackupCommand) (*ExecuteBackupResult, error)
}

type RestoreBackupCommandHandler interface {
    Handle(ctx context.Context, cmd *RestoreBackupCommand) (*RestoreBackupResult, error)
}

type CreateAdminUserCommandHandler interface {
    Handle(ctx context.Context, cmd *CreateAdminUserCommand) (*CreateAdminUserResult, error)
}
```

**Command DTOs (Data Transfer Objects):**
```go
// System Configuration Command
type UpdateSystemConfigurationCommand struct {
    ConfigKey    string                 `json:"config_key" validate:"required"`
    ConfigValue  interface{}            `json:"config_value" validate:"required"`
    ValueType    string                 `json:"value_type" validate:"required,oneof=string number boolean object array"`
    Description  string                 `json:"description"`
    AdminID      string                 `json:"admin_id" validate:"required"`
    Reason       string                 `json:"reason" validate:"required"`
    Environment  string                 `json:"environment" validate:"required,oneof=development staging production"`
}

type UpdateSystemConfigurationResult struct {
    ConfigKey         string                 `json:"config_key"`
    PreviousValue     interface{}            `json:"previous_value"`
    NewValue          interface{}            `json:"new_value"`
    ChangeHistoryID   string                 `json:"change_history_id"`
    PropagationStatus []ServicePropagation   `json:"propagation_status"`
    Success           bool                   `json:"success"`
}

// Announcement Command
type CreateAnnouncementCommand struct {
    Title           string                      `json:"title" validate:"required,max=200"`
    Content         string                      `json:"content" validate:"required,max=10000"`
    ContentFormat   string                      `json:"content_format" validate:"required,oneof=markdown html plain"`
    TargetType      string                      `json:"target_type" validate:"required,oneof=all users admins service"`
    TargetCriteria  map[string]interface{}      `json:"target_criteria"`
    Severity        string                      `json:"severity" validate:"required,oneof=info warning critical"`
    DisplayType     string                      `json:"display_type" validate:"required,oneof=banner modal toast"`
    ScheduledAt     *time.Time                  `json:"scheduled_at"`
    ExpiresAt       *time.Time                  `json:"expires_at"`
    Translations    []AnnouncementTranslation   `json:"translations"`
    AdminID         string                      `json:"admin_id" validate:"required"`
}

// Rate Limit Rule Command
type SetRateLimitRuleCommand struct {
    RuleName        string                 `json:"rule_name" validate:"required,max=100"`
    TargetType      string                 `json:"target_type" validate:"required,oneof=endpoint user ip api_key"`
    TargetPattern   string                 `json:"target_pattern" validate:"required"`
    RateLimit       int                    `json:"rate_limit" validate:"required,min=1"`
    WindowSizeMs    int                    `json:"window_size_ms" validate:"required,min=1000"`
    BurstAllowance  int                    `json:"burst_allowance" validate:"min=0"`
    Priority        int                    `json:"priority" validate:"required,min=1,max=100"`
    Enabled         bool                   `json:"enabled"`
    AdminID         string                 `json:"admin_id" validate:"required"`
}
```

**Command Handler実装例:**
```go
// System Configuration Command Handler Implementation
type UpdateSystemConfigurationCommandHandlerImpl struct {
    useCase         UpdateSystemConfigurationCommandUseCase
    validator       *validator.Validate
    auditLogger     AuditLogger
    eventPublisher  ConfigurationEventPublisher
}

func (h *UpdateSystemConfigurationCommandHandlerImpl) Handle(
    ctx context.Context, 
    cmd *UpdateSystemConfigurationCommand,
) (*UpdateSystemConfigurationResult, error) {
    // 1. Command Validation
    if err := h.validator.Struct(cmd); err != nil {
        h.auditLogger.LogFailure(ctx, "CONFIG_VALIDATION_FAILED", cmd.AdminID, err)
        return nil, fmt.Errorf("command validation failed: %w", err)
    }
    
    // 2. UseCase実行
    result, err := h.useCase.Execute(ctx, &UpdateSystemConfigurationUseCaseInput{
        ConfigKey:    cmd.ConfigKey,
        ConfigValue:  cmd.ConfigValue,
        ValueType:    cmd.ValueType,
        Description:  cmd.Description,
        AdminID:      cmd.AdminID,
        Reason:       cmd.Reason,
        Environment:  cmd.Environment,
    })
    
    if err != nil {
        h.auditLogger.LogFailure(ctx, "CONFIG_UPDATE_FAILED", cmd.AdminID, err)
        return nil, fmt.Errorf("configuration update failed: %w", err)
    }
    
    // 3. Event Publishing
    event := &SystemConfigUpdatedEvent{
        ConfigID:     result.ConfigKey,
        Key:          cmd.ConfigKey,
        OldValue:     result.PreviousValue,
        NewValue:     result.NewValue,
        AdminID:      cmd.AdminID,
        Reason:       cmd.Reason,
        Timestamp:    time.Now(),
    }
    
    if err := h.eventPublisher.PublishConfigUpdated(ctx, event); err != nil {
        // Event publishingの失敗はログのみ（メイン処理は成功）
        log.Error("Failed to publish config update event", "error", err, "config_key", cmd.ConfigKey)
    }
    
    // 4. Success Audit Log
    h.auditLogger.LogSuccess(ctx, "CONFIG_UPDATE_SUCCESS", cmd.AdminID, map[string]interface{}{
        "config_key": cmd.ConfigKey,
        "change_id":  result.ChangeHistoryID,
    })
    
    return &UpdateSystemConfigurationResult{
        ConfigKey:         result.ConfigKey,
        PreviousValue:     result.PreviousValue,
        NewValue:          result.NewValue,
        ChangeHistoryID:   result.ChangeHistoryID,
        PropagationStatus: result.PropagationStatus,
        Success:           true,
    }, nil
}
```

##### Query Side Implementation (クエリ側実装)

**Query Handler Interfaces:**
```go
//go:generate mockgen -source=$GOFILE -destination=../../tests/usecase/query/mock_query_handler.go -package=query

// System Monitoring Query Handlers
type GetSystemMetricsQueryHandler interface {
    Handle(ctx context.Context, query *GetSystemMetricsQuery) (*GetSystemMetricsResult, error)
}

type GetSystemConfigurationQueryHandler interface {
    Handle(ctx context.Context, query *GetSystemConfigurationQuery) (*GetSystemConfigurationResult, error)
}

type GetAnnouncementsQueryHandler interface {
    Handle(ctx context.Context, query *GetAnnouncementsQuery) (*GetAnnouncementsResult, error)
}

type GetBackupHistoryQueryHandler interface {
    Handle(ctx context.Context, query *GetBackupHistoryQuery) (*GetBackupHistoryResult, error)
}

type GetAdminAuditLogQueryHandler interface {
    Handle(ctx context.Context, query *GetAdminAuditLogQuery) (*GetAdminAuditLogResult, error)
}

type GetRateLimitMetricsQueryHandler interface {
    Handle(ctx context.Context, query *GetRateLimitMetricsQuery) (*GetRateLimitMetricsResult, error)
}
```

**Query DTOs:**
```go
// System Metrics Query
type GetSystemMetricsQuery struct {
    MetricTypes    []string    `json:"metric_types" validate:"required"` // cpu, memory, disk, network, response_time
    TimeRange      TimeRange   `json:"time_range" validate:"required"`
    Granularity    string      `json:"granularity" validate:"required,oneof=1m 5m 15m 1h 6h 24h"`
    Services       []string    `json:"services"` // Optional service filter
    Environment    string      `json:"environment" validate:"required,oneof=development staging production"`
}

type GetSystemMetricsResult struct {
    MetricsData    []MetricDataPoint  `json:"metrics_data"`
    Summary        MetricsSummary     `json:"summary"`
    AlertStatus    []ActiveAlert      `json:"alert_status"`
    CacheHitRate   float64           `json:"cache_hit_rate"`
    QueryDuration  time.Duration     `json:"query_duration"`
}

// System Configuration Query
type GetSystemConfigurationQuery struct {
    ConfigKeys     []string  `json:"config_keys"` // Empty means all configs
    Environment    string    `json:"environment" validate:"required"`
    IncludeHistory bool      `json:"include_history"`
    AdminID        string    `json:"admin_id" validate:"required"`
}

type GetSystemConfigurationResult struct {
    Configurations  []SystemConfigurationView  `json:"configurations"`
    ChangeHistory   []ConfigurationChange      `json:"change_history,omitempty"`
    LastSyncTime    time.Time                 `json:"last_sync_time"`
    SyncStatus      []ServiceSyncStatus       `json:"sync_status"`
}

// Audit Log Query  
type GetAdminAuditLogQuery struct {
    AdminID        *string    `json:"admin_id"`
    OperationType  *string    `json:"operation_type"`
    DateRange      TimeRange  `json:"date_range" validate:"required"`
    Severity       *string    `json:"severity"` // info, warning, error, critical
    IncludeDetails bool       `json:"include_details"`
    Pagination     Pagination `json:"pagination" validate:"required"`
}
```

**Query Handler実装例:**
```go
// System Metrics Query Handler Implementation
type GetSystemMetricsQueryHandlerImpl struct {
    queryService    MetricsQueryService
    cacheService    CacheService
    circuitBreaker  *CircuitBreaker
}

func (h *GetSystemMetricsQueryHandlerImpl) Handle(
    ctx context.Context,
    query *GetSystemMetricsQuery,
) (*GetSystemMetricsResult, error) {
    // 1. Query Validation
    if err := validator.New().Struct(query); err != nil {
        return nil, fmt.Errorf("query validation failed: %w", err)
    }
    
    // 2. Cache Check (Read側はキャッシュを積極活用)
    cacheKey := h.buildCacheKey(query)
    if cached, err := h.cacheService.Get(ctx, cacheKey); err == nil {
        var result GetSystemMetricsResult
        if json.Unmarshal(cached, &result) == nil {
            result.CacheHitRate = 1.0 // Cache hit
            return &result, nil
        }
    }
    
    // 3. Circuit Breaker Check
    if h.circuitBreaker.State() == CircuitBreakerOpen {
        return h.getFallbackMetrics(ctx, query)
    }
    
    // 4. Query Service実行
    startTime := time.Now()
    metricsData, err := h.queryService.GetSystemMetrics(ctx, MetricsQueryInput{
        MetricTypes: query.MetricTypes,
        TimeRange:   query.TimeRange,
        Granularity: query.Granularity,
        Services:    query.Services,
        Environment: query.Environment,
    })
    
    if err != nil {
        h.circuitBreaker.RecordFailure()
        return h.getFallbackMetrics(ctx, query)
    }
    
    h.circuitBreaker.RecordSuccess()
    
    // 5. Response組み立て
    result := &GetSystemMetricsResult{
        MetricsData:   metricsData.DataPoints,
        Summary:       metricsData.Summary,
        AlertStatus:   metricsData.ActiveAlerts,
        CacheHitRate:  0.0, // No cache hit
        QueryDuration: time.Since(startTime),
    }
    
    // 6. Cache Storage (非同期)
    go func() {
        if data, err := json.Marshal(result); err == nil {
            h.cacheService.Set(context.Background(), cacheKey, data, 5*time.Minute)
        }
    }()
    
    return result, nil
}

func (h *GetSystemMetricsQueryHandlerImpl) getFallbackMetrics(
    ctx context.Context, 
    query *GetSystemMetricsQuery,
) (*GetSystemMetricsResult, error) {
    // Fallback to cached data or minimal dataset
    return &GetSystemMetricsResult{
        MetricsData:  []MetricDataPoint{}, // Empty but valid response
        Summary:      MetricsSummary{Status: "degraded"},
        AlertStatus:  []ActiveAlert{{Message: "Metrics service temporarily unavailable"}},
        CacheHitRate: 0.0,
    }, nil
}
```

##### Write/Read Model Separation (書き込み・読み取りモデル分離)

**Write Models (Command Side):**
```go
// Command Side - Write Models (Domain Aggregates)
type SystemConfiguration struct {
    configKey       ConfigurationKey
    configValue     interface{}
    valueType       ValueType
    description     string
    environment     Environment
    adminID         AdminID
    changeReason    string
    createdAt       time.Time
    updatedAt       time.Time
    
    // Domain Logic
    history         []ConfigurationChange
    validationRules []ValidationRule
}

// Write operations focus on business rules and consistency
func (sc *SystemConfiguration) UpdateValue(newValue interface{}, adminID AdminID, reason string) error {
    // Business rule validation
    if err := sc.validateValueChange(newValue); err != nil {
        return fmt.Errorf("value change validation failed: %w", err)
    }
    
    // Record change history
    change := ConfigurationChange{
        ChangeID:     NewChangeID(),
        ConfigKey:    sc.configKey,
        OldValue:     sc.configValue,
        NewValue:     newValue,
        AdminID:      adminID,
        Reason:       reason,
        Timestamp:    time.Now(),
    }
    
    sc.history = append(sc.history, change)
    sc.configValue = newValue
    sc.updatedAt = time.Now()
    
    return nil
}
```

**Read Models (Query Side):**
```go
// Query Side - Read Models (Optimized for queries)
type SystemConfigurationView struct {
    ConfigKey         string                 `json:"config_key" db:"config_key"`
    ConfigValue       string                 `json:"config_value" db:"config_value"` // JSON serialized
    ValueType         string                 `json:"value_type" db:"value_type"`
    Description       string                 `json:"description" db:"description"`
    Environment       string                 `json:"environment" db:"environment"`
    LastUpdatedBy     string                 `json:"last_updated_by" db:"last_updated_by"`
    LastUpdatedAt     time.Time             `json:"last_updated_at" db:"last_updated_at"`
    ChangeCount       int                    `json:"change_count" db:"change_count"`
    SyncStatus        []ServiceSyncStatus   `json:"sync_status"` // Computed field
}

type ConfigurationSummaryView struct {
    Environment         string                    `json:"environment" db:"environment"`
    TotalConfigurations int                      `json:"total_configurations" db:"total_configurations"`
    LastSyncTime        time.Time                `json:"last_sync_time" db:"last_sync_time"`
    FailedSyncs         int                      `json:"failed_syncs" db:"failed_syncs"`
    ConfigsByCategory   map[string]int          `json:"configs_by_category"`
    RecentChanges       []RecentConfigChange    `json:"recent_changes"`
}

// Read models are optimized for query performance
type MetricsAggregateView struct {
    ServiceName       string          `json:"service_name" db:"service_name"`
    MetricType        string          `json:"metric_type" db:"metric_type"`
    AggregateValue    float64         `json:"aggregate_value" db:"aggregate_value"`
    AggregateType     string          `json:"aggregate_type" db:"aggregate_type"` // avg, sum, max, min
    TimeWindow        string          `json:"time_window" db:"time_window"`
    SampleCount       int             `json:"sample_count" db:"sample_count"`
    Timestamp         time.Time       `json:"timestamp" db:"timestamp"`
    AlertThreshold    *float64        `json:"alert_threshold" db:"alert_threshold"`
    IsAbnormal        bool            `json:"is_abnormal" db:"is_abnormal"`
}
```

**CQRS Event Flow:**
```go
// Event-driven synchronization between Write and Read sides
type SystemAdminEventHandler struct {
    readModelUpdater  ReadModelUpdater
    cacheInvalidator  CacheInvalidator
    notificationSvc   NotificationService
}

func (h *SystemAdminEventHandler) HandleSystemConfigUpdated(ctx context.Context, event *SystemConfigUpdatedEvent) error {
    // 1. Update Read Models
    if err := h.readModelUpdater.UpdateConfigurationView(ctx, event); err != nil {
        return fmt.Errorf("failed to update read model: %w", err)
    }
    
    // 2. Invalidate related caches
    cacheKeys := []string{
        fmt.Sprintf("config:%s:%s", event.Environment, event.Key),
        fmt.Sprintf("config:all:%s", event.Environment),
        fmt.Sprintf("config:summary:%s", event.Environment),
    }
    
    if err := h.cacheInvalidator.InvalidateMultiple(ctx, cacheKeys); err != nil {
        log.Error("Cache invalidation failed", "error", err, "keys", cacheKeys)
    }
    
    // 3. Send notifications for critical configurations
    if event.IsCritical {
        notification := &ConfigurationChangeNotification{
            ConfigKey:    event.Key,
            Environment:  event.Environment,
            ChangedBy:    event.AdminID,
            ChangeReason: event.Reason,
            Timestamp:    event.Timestamp,
        }
        
        if err := h.notificationSvc.SendCriticalConfigChange(ctx, notification); err != nil {
            log.Error("Failed to send config change notification", "error", err)
        }
    }
    
    return nil
}
```

#### Infrastructure Layer (インフラストラクチャ層)
- **Repository Implementations:**
  - AnnouncementRepositoryImpl (PostgreSQL)
  - SystemConfigurationRepositoryImpl (PostgreSQL)
  - RateLimitRuleRepositoryImpl (PostgreSQL)
  - AdminUserRepositoryImpl (PostgreSQL)
  - BackupPolicyRepositoryImpl (PostgreSQL)
  - SystemMetricsRepositoryImpl (TimescaleDB)
- **Query Service Implementations:**
  - MetricsQueryServiceImpl (TimescaleDB + Redisキャッシュ)
  - AnnouncementQueryServiceImpl (PostgreSQL + Redis)
  - ConfigurationQueryServiceImpl (PostgreSQL + Redis)
  - BackupQueryServiceImpl (PostgreSQL)
- **External Service Implementations:**
  - S3StorageService (AWS S3 / MinIO)
  - PrometheusMetricsService (Prometheus)
  - OpenTelemetryService (OpenTelemetry)
- **Event Publishers:**
  - AnnouncementEventPublisher (Redis Pub/Sub)
  - ConfigurationEventPublisher (Redis Pub/Sub)
  - BackupEventPublisher (Redis Pub/Sub)
  - MetricsEventPublisher (Redis Pub/Sub)

#### Handler Layer (ハンドラー層)
- **gRPC Handlers:**
  - AnnouncementHandler: アナウンス関連RPCハンドラー
  - ConfigurationHandler: 設定管理RPCハンドラー
  - RateLimitHandler: レート制限RPCハンドラー
  - BackupHandler: バックアップRPCハンドラー
  - MetricsHandler: メトリクスRPCハンドラー
  - AdminHandler: 管理者管理RPCハンドラー
- **REST API Handlers (管理画面用):**
  - DashboardHandler: ダッシュボードAPI
  - AnnouncementAPIHandler: アナウンスAPI
  - ConfigAPIHandler: 設定API
  - MetricsAPIHandler: メトリクスAPI
- **WebSocket Handlers:**
  - MetricsStreamHandler: リアルタイムメトリクス配信
  - AnnouncementStreamHandler: アナウンスリアルタイム配信
- **Batch Job Handlers:**
  - MetricsAggregationJob: メトリクス集計
  - AnnouncementDeliveryJob: アナウンス配信
  - BackupExecutionJob: バックアップ実行
  - ConfigurationSyncJob: 設定同期
  - HealthCheckJob: ヘルスチェック

### 5.2. システム構成

```
┌─────────────────────────────────────────┐
│          Handler Layer                   │
│  - gRPC Handlers                        │
│  - REST API Handlers                    │
│  - WebSocket Handlers                   │
│  - Batch Job Handlers                   │
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐
│         Use Case Layer                   │
│  - Command Use Cases                     │
│  - Query Use Cases                       │
│  - Configuration Services               │
│  - Metrics Services                     │
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐
│          Domain Layer                    │
│  - Aggregates                           │
│  - Domain Services                      │
│  - Policy Engine                        │
│  - Analytics Engine                     │
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐
│       Infrastructure Layer               │
│  - Repositories                         │
│  - External Services                    │
│  - Storage Services                     │
│  - Cache                                │
└─────────────────────────────────────────┘
```

#### 主要コンポーネント構成

#### 管理機能
- **AnnouncementAggregate**: アナウンス管理
- **SystemConfigurationAggregate**: システム設定
- **RateLimitRuleAggregate**: レート制限
- **AdminUserAggregate**: 管理者権限
- **BackupPolicyAggregate**: バックアップポリシー

#### 分析・監視
- **SystemMetricsAggregate**: メトリクス収集
- **MetricsAnalysisService**: メトリクス分析
- **AnomalyDetector**: 異常検知
- **TrendAnalyzer**: トレンド分析

#### 処理エンジン
- **ConfigurationEngine**: 設定管理エンジン
- **BackupOrchestrator**: バックアップ調整
- **RateLimitEvaluator**: レート制限評価
- **NotificationDispatcher**: 通知配信

## データベースマイグレーション

このサービスでは、[共通マイグレーション戦略](../common/database-migration-strategy.md)に従って、Gooseを使用したマイグレーション管理を行います。

### マイグレーション戦略

- **ツール**: Goose v3
- **ディレクトリ**: `./migrations/`
- **命名規則**: `[sequence_number]_[description].sql`
- **実行方法**: `make migrate-up` / `make migrate-down`

### avion-system-admin固有の考慮事項

- **システム設定継続**: 移行中もシステム全体の設定が適用され続けるよう保証
- **管理者権限継承**: 管理者のアクセス権限と役割を正確に移行
- **アナウンス配信継続**: 進行中のアナウンス配信スケジュールを中断させない
- **監視データ保持**: システム監視に必要な履歴データを完全に保持
- **バックアップ整合性**: バックアップ・リストア機能に影響を与えない移行

### 標準テンプレート参照

マイグレーションファイル作成時は[マイグレーション設定テンプレート](../templates/migration-setup-template.md)を参照してください。

## 7. Endpoints (API)

### 7.1. gRPC Service Definition

```protobuf
service SystemAdminService {
  // Announcement management
  rpc CreateAnnouncement(CreateAnnouncementRequest) returns (CreateAnnouncementResponse);
  rpc GetAnnouncements(GetAnnouncementsRequest) returns (GetAnnouncementsResponse);
  rpc UpdateAnnouncement(UpdateAnnouncementRequest) returns (UpdateAnnouncementResponse);
  rpc DeleteAnnouncement(DeleteAnnouncementRequest) returns (DeleteAnnouncementResponse);
  
  // System configuration
  rpc UpdateConfiguration(UpdateConfigurationRequest) returns (UpdateConfigurationResponse);
  rpc GetConfiguration(GetConfigurationRequest) returns (GetConfigurationResponse);
  rpc RollbackConfiguration(RollbackConfigurationRequest) returns (RollbackConfigurationResponse);
  
  // Admin user management
  rpc CreateAdminUser(CreateAdminUserRequest) returns (CreateAdminUserResponse);
  rpc UpdateAdminPermissions(UpdateAdminPermissionsRequest) returns (UpdateAdminPermissionsResponse);
  rpc AuditAdminActions(AuditAdminActionsRequest) returns (AuditAdminActionsResponse);
  
  // Rate limiting
  rpc SetRateLimitRule(SetRateLimitRuleRequest) returns (SetRateLimitRuleResponse);
  rpc EvaluateRateLimit(EvaluateRateLimitRequest) returns (EvaluateRateLimitResponse);
  
  // Metrics and monitoring
  rpc GetSystemMetrics(GetSystemMetricsRequest) returns (GetSystemMetricsResponse);
  rpc GetAnomalies(GetAnomaliesRequest) returns (GetAnomaliesResponse);
  
  // Backup management
  rpc ExecuteBackup(ExecuteBackupRequest) returns (ExecuteBackupResponse);
  rpc RestoreBackup(RestoreBackupRequest) returns (RestoreBackupResponse);
  rpc GetBackupStatus(GetBackupStatusRequest) returns (GetBackupStatusResponse);
}

message CreateAnnouncementRequest {
  string title = 1;
  string content = 2;
  AnnouncementPriority priority = 3;
  repeated string target_user_ids = 4;
  google.protobuf.Timestamp publish_at = 5;
  google.protobuf.Timestamp expire_at = 6;
}

message CreateAnnouncementResponse {
  string announcement_id = 1;
  AnnouncementStatus status = 2;
}
```

### 7.2. Error Codes

- `INVALID_ARGUMENT`: Invalid request parameters or business rule violations
- `NOT_FOUND`: Requested resource not found (announcement, configuration, admin user)
- `PERMISSION_DENIED`: Insufficient permissions for admin operation
- `ALREADY_EXISTS`: Resource already exists (duplicate configuration key, admin email)
- `FAILED_PRECONDITION`: Operation cannot be performed in current state
- `RESOURCE_EXHAUSTED`: Rate limit exceeded or resource quota exceeded
- `UNAVAILABLE`: External service unavailable (backup service, notification service)
- `INTERNAL`: Unexpected server error, database connection issues

## 8. Data Design (データ設計)

### 6.1. API設計

#### gRPC API 定義

```protobuf
service SystemAdminService {
  // アナウンス管理
  rpc CreateAnnouncement(CreateAnnouncementRequest) returns (CreateAnnouncementResponse);
  rpc UpdateAnnouncement(UpdateAnnouncementRequest) returns (UpdateAnnouncementResponse);
  rpc DeleteAnnouncement(DeleteAnnouncementRequest) returns (DeleteAnnouncementResponse);
  rpc GetAnnouncements(GetAnnouncementsRequest) returns (GetAnnouncementsResponse);
  rpc ScheduleAnnouncement(ScheduleAnnouncementRequest) returns (ScheduleAnnouncementResponse);
  rpc GetAnnouncementMetrics(GetAnnouncementMetricsRequest) returns (GetAnnouncementMetricsResponse);
  
  // システム設定
  rpc UpdateSystemConfiguration(UpdateSystemConfigurationRequest) returns (UpdateSystemConfigurationResponse);
  rpc GetSystemConfiguration(GetSystemConfigurationRequest) returns (GetSystemConfigurationResponse);
  rpc RollbackConfiguration(RollbackConfigurationRequest) returns (RollbackConfigurationResponse);
  rpc GetConfigurationHistory(GetConfigurationHistoryRequest) returns (GetConfigurationHistoryResponse);
  rpc ValidateConfiguration(ValidateConfigurationRequest) returns (ValidateConfigurationResponse);
  
  // レート制限
  rpc SetRateLimitRule(SetRateLimitRuleRequest) returns (SetRateLimitRuleResponse);
  rpc GetRateLimitRules(GetRateLimitRulesRequest) returns (GetRateLimitRulesResponse);
  rpc EvaluateRateLimit(EvaluateRateLimitRequest) returns (EvaluateRateLimitResponse);
  rpc GetRateLimitMetrics(GetRateLimitMetricsRequest) returns (GetRateLimitMetricsResponse);
  
  // 統計・メトリクス
  rpc GetSystemMetrics(GetSystemMetricsRequest) returns (GetSystemMetricsResponse);
  rpc GetUserStatistics(GetUserStatisticsRequest) returns (GetUserStatisticsResponse);
  rpc GetContentStatistics(GetContentStatisticsRequest) returns (GetContentStatisticsResponse);
  rpc GetStorageStatistics(GetStorageStatisticsRequest) returns (GetStorageStatisticsResponse);
  rpc GenerateAnalyticsReport(GenerateAnalyticsReportRequest) returns (GenerateAnalyticsReportResponse);
  
  // バックアップ管理
  rpc CreateBackupPolicy(CreateBackupPolicyRequest) returns (CreateBackupPolicyResponse);
  rpc ExecuteBackup(ExecuteBackupRequest) returns (ExecuteBackupResponse);
  rpc RestoreBackup(RestoreBackupRequest) returns (RestoreBackupResponse);
  rpc GetBackupHistory(GetBackupHistoryRequest) returns (GetBackupHistoryResponse);
  rpc VerifyBackup(VerifyBackupRequest) returns (VerifyBackupResponse);
  
  // 管理者管理
  rpc CreateAdminUser(CreateAdminUserRequest) returns (CreateAdminUserResponse);
  rpc UpdateAdminPermissions(UpdateAdminPermissionsRequest) returns (UpdateAdminPermissionsResponse);
  rpc GetAdminUsers(GetAdminUsersRequest) returns (GetAdminUsersResponse);
  rpc RevokeAdminAccess(RevokeAdminAccessRequest) returns (RevokeAdminAccessResponse);
  rpc GetAdminAuditLog(GetAdminAuditLogRequest) returns (GetAdminAuditLogResponse);
  
  // メンテナンス
  rpc SetMaintenanceMode(SetMaintenanceModeRequest) returns (SetMaintenanceModeResponse);
  rpc GetMaintenanceStatus(GetMaintenanceStatusRequest) returns (GetMaintenanceStatusResponse);
  rpc ScheduleMaintenance(ScheduleMaintenanceRequest) returns (ScheduleMaintenanceResponse);
  
  // ヘルスチェック
  rpc GetServiceHealth(GetServiceHealthRequest) returns (GetServiceHealthResponse);
  rpc GetSystemStatus(GetSystemStatusRequest) returns (GetSystemStatusResponse);
  rpc RunDiagnostics(RunDiagnosticsRequest) returns (RunDiagnosticsResponse);
}
```

#### REST API (管理画面用)

```yaml
paths:
  /api/admin/dashboard:
    get:
      summary: ダッシュボード情報取得
      responses:
        200:
          description: ダッシュボードデータ
          
  /api/admin/announcements:
    get:
      summary: アナウンス一覧取得
    post:
      summary: アナウンス作成
      
  /api/admin/config:
    get:
      summary: システム設定取得
    put:
      summary: システム設定更新
      
  /api/admin/metrics:
    get:
      summary: メトリクス取得
      parameters:
        - name: period
        - name: metrics[]
        
  /api/admin/backup:
    post:
      summary: バックアップ実行
    get:
      summary: バックアップ履歴取得
```

### 6.2. データモデル

### アナウンス管理

```sql
-- アナウンス
CREATE TABLE announcements (
    announcement_id UUID PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    content_format TEXT DEFAULT 'markdown',
    target_type TEXT NOT NULL CHECK (target_type IN ('all', 'group', 'individual')),
    target_criteria JSONB,
    severity TEXT NOT NULL CHECK (severity IN ('info', 'warning', 'critical')),
    display_type TEXT NOT NULL CHECK (display_type IN ('banner', 'modal', 'notification')),
    publish_at TIMESTAMP NOT NULL,
    expire_at TIMESTAMP,
    created_by UUID NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT true,
    is_draft BOOLEAN DEFAULT false,
    read_count INT DEFAULT 0,
    dismiss_count INT DEFAULT 0
);

-- アナウンス多言語対応
CREATE TABLE announcement_translations (
    announcement_id UUID REFERENCES announcements(announcement_id) ON DELETE CASCADE,
    language_code TEXT NOT NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    translated_by UUID,
    translated_at TIMESTAMP NOT NULL,
    PRIMARY KEY (announcement_id, language_code)
);

-- アナウンス対象
CREATE TABLE announcement_targets (
    target_id UUID PRIMARY KEY,
    announcement_id UUID REFERENCES announcements(announcement_id) ON DELETE CASCADE,
    target_type TEXT NOT NULL,
    target_value TEXT NOT NULL,
    exclusion_list TEXT[],
    created_at TIMESTAMP NOT NULL
);

-- アナウンス既読管理
CREATE TABLE announcement_reads (
    announcement_id UUID REFERENCES announcements(announcement_id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    read_at TIMESTAMP NOT NULL,
    dismissed_at TIMESTAMP,
    PRIMARY KEY (announcement_id, user_id)
);

CREATE INDEX idx_announcements_active ON announcements(publish_at, expire_at) WHERE is_active = true;
CREATE INDEX idx_announcement_reads_user ON announcement_reads(user_id, read_at DESC);
```

### システム設定管理

```sql
-- システム設定
CREATE TABLE system_configurations (
    config_key TEXT PRIMARY KEY,
    config_value JSONB NOT NULL,
    value_type TEXT NOT NULL CHECK (value_type IN ('string', 'number', 'boolean', 'json', 'array')),
    description TEXT,
    category TEXT NOT NULL,
    is_sensitive BOOLEAN DEFAULT false,
    is_readonly BOOLEAN DEFAULT false,
    validation_rules JSONB,
    updated_by UUID NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    version INT DEFAULT 1
);

-- 設定履歴
CREATE TABLE configuration_history (
    history_id UUID PRIMARY KEY,
    config_key TEXT NOT NULL,
    old_value JSONB,
    new_value JSONB NOT NULL,
    changed_by UUID NOT NULL,
    changed_at TIMESTAMP NOT NULL,
    change_reason TEXT,
    rollback_id UUID REFERENCES configuration_history(history_id)
);

-- 機能フラグ
CREATE TABLE feature_flags (
    flag_name TEXT PRIMARY KEY,
    is_enabled BOOLEAN DEFAULT false,
    rollout_percentage INT DEFAULT 0 CHECK (rollout_percentage >= 0 AND rollout_percentage <= 100),
    target_groups TEXT[],
    conditions JSONB,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

-- 設定テンプレート
CREATE TABLE configuration_templates (
    template_id UUID PRIMARY KEY,
    template_name TEXT NOT NULL UNIQUE,
    description TEXT,
    config_set JSONB NOT NULL,
    created_by UUID NOT NULL,
    created_at TIMESTAMP NOT NULL,
    is_default BOOLEAN DEFAULT false
);

CREATE INDEX idx_configuration_history_key ON configuration_history(config_key, changed_at DESC);
CREATE INDEX idx_feature_flags_enabled ON feature_flags(flag_name) WHERE is_enabled = true;
```

### レート制限管理

```sql
-- レート制限ルール
CREATE TABLE rate_limit_rules (
    rule_id UUID PRIMARY KEY,
    rule_name TEXT NOT NULL UNIQUE,
    target_type TEXT NOT NULL CHECK (target_type IN ('endpoint', 'user', 'ip', 'api_key')),
    target_pattern TEXT NOT NULL,
    limit_value INT NOT NULL,
    window_seconds INT NOT NULL,
    burst_size INT DEFAULT 0,
    window_type TEXT DEFAULT 'fixed' CHECK (window_type IN ('fixed', 'sliding')),
    action TEXT NOT NULL CHECK (action IN ('throttle', 'reject', 'captcha', 'queue')),
    priority INT DEFAULT 0,
    conditions JSONB,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

-- レート制限カウンター（Redisに保存、ここは監査用）
CREATE TABLE rate_limit_violations (
    violation_id UUID PRIMARY KEY,
    rule_id UUID REFERENCES rate_limit_rules(rule_id),
    target_identifier TEXT NOT NULL,
    violation_count INT DEFAULT 1,
    first_violation_at TIMESTAMP NOT NULL,
    last_violation_at TIMESTAMP NOT NULL,
    action_taken TEXT NOT NULL
);

-- レート制限ホワイトリスト
CREATE TABLE rate_limit_whitelist (
    whitelist_id UUID PRIMARY KEY,
    target_type TEXT NOT NULL,
    target_value TEXT NOT NULL,
    reason TEXT,
    added_by UUID NOT NULL,
    added_at TIMESTAMP NOT NULL,
    expires_at TIMESTAMP,
    UNIQUE(target_type, target_value)
);

CREATE INDEX idx_rate_limit_rules_active ON rate_limit_rules(priority DESC) WHERE is_active = true;
CREATE INDEX idx_rate_limit_violations_time ON rate_limit_violations(last_violation_at DESC);
```

### 統計・メトリクス

```sql
-- システムメトリクス
CREATE TABLE system_metrics (
    metric_id UUID PRIMARY KEY,
    metric_type TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    metric_value JSONB NOT NULL,
    tags JSONB,
    recorded_at TIMESTAMP NOT NULL,
    aggregation_period TEXT NOT NULL CHECK (aggregation_period IN ('minute', 'hour', 'day', 'week', 'month')),
    aggregation_type TEXT CHECK (aggregation_type IN ('sum', 'avg', 'max', 'min', 'p50', 'p95', 'p99'))
);

-- ユーザー統計
CREATE TABLE user_statistics (
    stat_id UUID PRIMARY KEY,
    period_start TIMESTAMP NOT NULL,
    period_end TIMESTAMP NOT NULL,
    total_users INT NOT NULL,
    new_users INT NOT NULL,
    active_users INT NOT NULL,
    churned_users INT DEFAULT 0,
    user_segments JSONB,
    calculated_at TIMESTAMP NOT NULL
);

-- コンテンツ統計
CREATE TABLE content_statistics (
    stat_id UUID PRIMARY KEY,
    period_start TIMESTAMP NOT NULL,
    period_end TIMESTAMP NOT NULL,
    total_posts INT NOT NULL,
    new_posts INT NOT NULL,
    total_reactions INT NOT NULL,
    content_types JSONB,
    trending_topics JSONB,
    calculated_at TIMESTAMP NOT NULL
);

-- ストレージ統計
CREATE TABLE storage_statistics (
    stat_id UUID PRIMARY KEY,
    measured_at TIMESTAMP NOT NULL,
    total_size_bytes BIGINT NOT NULL,
    used_size_bytes BIGINT NOT NULL,
    media_size_bytes BIGINT NOT NULL,
    database_size_bytes BIGINT NOT NULL,
    cache_size_bytes BIGINT NOT NULL,
    backup_size_bytes BIGINT NOT NULL,
    growth_rate_daily FLOAT,
    estimated_days_remaining INT
);

CREATE INDEX idx_system_metrics_type_time ON system_metrics(metric_type, recorded_at DESC);
CREATE INDEX idx_user_statistics_period ON user_statistics(period_end DESC);
CREATE INDEX idx_content_statistics_period ON content_statistics(period_end DESC);
```

### バックアップ管理

```sql
-- バックアップポリシー
CREATE TABLE backup_policies (
    policy_id UUID PRIMARY KEY,
    policy_name TEXT NOT NULL UNIQUE,
    backup_type TEXT NOT NULL CHECK (backup_type IN ('full', 'incremental', 'differential')),
    schedule_cron TEXT NOT NULL,
    retention_days INT NOT NULL,
    target_components TEXT[] NOT NULL,
    storage_location TEXT NOT NULL,
    encryption_enabled BOOLEAN DEFAULT true,
    compression_type TEXT DEFAULT 'gzip',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

-- バックアップ記録
CREATE TABLE backup_records (
    backup_id UUID PRIMARY KEY,
    policy_id UUID REFERENCES backup_policies(policy_id),
    backup_type TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('running', 'completed', 'failed', 'cancelled')),
    location TEXT,
    size_bytes BIGINT,
    checksum TEXT,
    started_at TIMESTAMP NOT NULL,
    completed_at TIMESTAMP,
    error_message TEXT,
    metadata JSONB
);

-- バックアップ検証
CREATE TABLE backup_verifications (
    verification_id UUID PRIMARY KEY,
    backup_id UUID REFERENCES backup_records(backup_id),
    verification_type TEXT NOT NULL CHECK (verification_type IN ('checksum', 'restore_test', 'integrity')),
    status TEXT NOT NULL CHECK (status IN ('pending', 'running', 'passed', 'failed')),
    started_at TIMESTAMP NOT NULL,
    completed_at TIMESTAMP,
    details JSONB
);

-- リストア履歴
CREATE TABLE restore_history (
    restore_id UUID PRIMARY KEY,
    backup_id UUID REFERENCES backup_records(backup_id),
    restore_type TEXT NOT NULL CHECK (restore_type IN ('full', 'partial', 'selective')),
    target_components TEXT[],
    status TEXT NOT NULL CHECK (status IN ('running', 'completed', 'failed')),
    started_at TIMESTAMP NOT NULL,
    completed_at TIMESTAMP,
    restored_by UUID NOT NULL,
    restore_reason TEXT
);

CREATE INDEX idx_backup_records_policy ON backup_records(policy_id, started_at DESC);
CREATE INDEX idx_backup_records_status ON backup_records(status) WHERE status = 'running';
```

### 管理者管理

```sql
-- 管理者ユーザー
CREATE TABLE admin_users (
    admin_id UUID PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE,
    role TEXT NOT NULL CHECK (role IN ('viewer', 'operator', 'admin', 'owner')),
    permissions JSONB NOT NULL DEFAULT '{}',
    two_factor_enabled BOOLEAN DEFAULT false,
    two_factor_secret TEXT,
    last_login_at TIMESTAMP,
    failed_login_count INT DEFAULT 0,
    locked_until TIMESTAMP,
    created_by UUID NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT true
);

-- 権限グループ
CREATE TABLE permission_groups (
    group_id UUID PRIMARY KEY,
    group_name TEXT NOT NULL UNIQUE,
    description TEXT,
    permissions JSONB NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

-- 管理者グループ割り当て
CREATE TABLE admin_group_assignments (
    admin_id UUID REFERENCES admin_users(admin_id) ON DELETE CASCADE,
    group_id UUID REFERENCES permission_groups(group_id) ON DELETE CASCADE,
    assigned_by UUID NOT NULL,
    assigned_at TIMESTAMP NOT NULL,
    PRIMARY KEY (admin_id, group_id)
);

-- 監査ログ
CREATE TABLE admin_audit_logs (
    log_id UUID PRIMARY KEY,
    admin_id UUID NOT NULL,
    action TEXT NOT NULL,
    resource_type TEXT NOT NULL,
    resource_id TEXT,
    details JSONB,
    ip_address INET,
    user_agent TEXT,
    performed_at TIMESTAMP NOT NULL,
    hash TEXT NOT NULL,
    previous_hash TEXT
);

CREATE INDEX idx_admin_audit_logs_admin ON admin_audit_logs(admin_id, performed_at DESC);
CREATE INDEX idx_admin_audit_logs_action ON admin_audit_logs(action, performed_at DESC);
```

### メンテナンス管理

```sql
-- メンテナンススケジュール
CREATE TABLE maintenance_schedules (
    schedule_id UUID PRIMARY KEY,
    maintenance_type TEXT NOT NULL CHECK (maintenance_type IN ('planned', 'emergency')),
    title TEXT NOT NULL,
    description TEXT,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    affected_services TEXT[],
    maintenance_mode TEXT NOT NULL CHECK (maintenance_mode IN ('readonly', 'offline', 'limited')),
    created_by UUID NOT NULL,
    created_at TIMESTAMP NOT NULL,
    is_cancelled BOOLEAN DEFAULT false
);

-- メンテナンス通知
CREATE TABLE maintenance_notifications (
    notification_id UUID PRIMARY KEY,
    schedule_id UUID REFERENCES maintenance_schedules(schedule_id),
    notification_time TIMESTAMP NOT NULL,
    notification_type TEXT NOT NULL CHECK (notification_type IN ('advance', 'start', 'end', 'update')),
    sent_at TIMESTAMP,
    recipients_count INT DEFAULT 0
);
```

### 6.3. キャッシュ戦略

```
# システム設定キャッシュ
config:{key} -> configuration value
TTL: 10分

# 機能フラグキャッシュ
feature:{flag_name} -> flag state
TTL: 5分

# レート制限ルールキャッシュ
ratelimit:rules -> List of active rules (sorted by priority)
TTL: 5分

# レート制限カウンター
ratelimit:{rule_id}:{target} -> counter
TTL: window_seconds

# アナウンスキャッシュ
announcements:active -> List of active announcements
TTL: 5分

# メトリクスキャッシュ
metrics:{type}:{period} -> aggregated metrics
TTL: 1分（minute）、5分（hour）、1時間（day）

# 管理者権限キャッシュ
admin:permissions:{admin_id} -> permissions object
TTL: 30分

# バックアップステータスキャッシュ
backup:status:{backup_id} -> backup status
TTL: 30秒

# ダッシュボードキャッシュ
dashboard:stats -> dashboard statistics
TTL: 1分

# サービスヘルスキャッシュ
health:{service_name} -> health status
TTL: 30秒
```

### 6.4. バッチ処理

### 定期処理

```yaml
# メトリクス集計（1分ごと）
metrics_aggregation:
  interval: 1m
  tasks:
    - リアルタイムメトリクスの収集
    - 1分間隔の集計
    - 異常値検出

# 統計計算（1時間ごと）
statistics_calculation:
  interval: 1h
  tasks:
    - ユーザー統計の計算
    - コンテンツ統計の計算
    - ストレージ使用量の計算
    - トレンド分析

# アナウンス配信（1分ごと）
announcement_delivery:
  interval: 1m
  tasks:
    - スケジュールされたアナウンスの配信
    - 期限切れアナウンスのアーカイブ
    - 既読率の更新

# バックアップ実行（スケジュール依存）
backup_execution:
  schedule: cron
  tasks:
    - ポリシーに基づくバックアップ実行
    - 増分/差分バックアップの処理
    - バックアップ検証
    - 古い世代の削除

# レート制限評価（5分ごと）
rate_limit_evaluation:
  interval: 5m
  tasks:
    - 動的レート制限の調整
    - 違反パターンの分析
    - ホワイトリストの期限チェック

# 設定同期（10秒ごと）
configuration_sync:
  interval: 10s
  tasks:
    - 設定変更の検出
    - 各サービスへの配信
    - 適用状態の確認

# ヘルスチェック（30秒ごと）
health_check:
  interval: 30s
  tasks:
    - 全サービスのヘルスチェック
    - 依存関係の確認
    - アラート判定

# クリーンアップ（日次）
daily_cleanup:
  schedule: "0 3 * * *"
  tasks:
    - 古いメトリクスのアーカイブ
    - 期限切れデータの削除
    - ログローテーション

# レポート生成（月次）
monthly_report:
  schedule: "0 0 1 * *"
  tasks:
    - 月次統計レポート生成
    - 成長分析レポート
    - キャパシティプランニングレポート
```

### 6.5. 外部サービス連携

### 監視サービス

```go
type MonitoringService interface {
    SendMetric(ctx context.Context, metric *Metric) error
    SendAlert(ctx context.Context, alert *Alert) error
    GetDashboard(ctx context.Context, dashboardID string) (*Dashboard, error)
}

type Metric struct {
    Name      string
    Value     float64
    Tags      map[string]string
    Timestamp time.Time
}

type Alert struct {
    Level    string // info, warning, critical
    Title    string
    Message  string
    Source   string
    Metadata map[string]interface{}
}
```

### ストレージサービス

```go
type StorageService interface {
    Upload(ctx context.Context, key string, data io.Reader) error
    Download(ctx context.Context, key string) (io.ReadCloser, error)
    Delete(ctx context.Context, key string) error
    List(ctx context.Context, prefix string) ([]StorageObject, error)
    GetMetadata(ctx context.Context, key string) (*ObjectMetadata, error)
}

type StorageObject struct {
    Key          string
    Size         int64
    LastModified time.Time
    StorageClass string
}
```

### 6.6. セキュリティ設計

### 権限管理

```yaml
roles:
  viewer:
    - view_dashboard
    - view_statistics
    - view_configurations
    
  operator:
    - inherit: viewer
    - manage_announcements
    - execute_backup
    - view_audit_logs
    
  admin:
    - inherit: operator
    - manage_configurations
    - manage_rate_limits
    - manage_users
    - restore_backup
    
  owner:
    - inherit: admin
    - manage_admins
    - delete_data
    - emergency_shutdown
```

### 監査ログ

```go
type AuditLog struct {
    LogID        string
    Timestamp    time.Time
    AdminID      string
    AdminRole    string
    Action       string
    ResourceType string
    ResourceID   string
    OldValue     interface{}
    NewValue     interface{}
    IPAddress    string
    UserAgent    string
    SessionID    string
    Hash         string // SHA-256(previous_hash + current_data)
    PreviousHash string
}

// 改竄防止のためのハッシュチェーン実装
func (l *AuditLog) CalculateHash(previousHash string) string {
    data := fmt.Sprintf("%s:%s:%s:%s:%v:%v",
        l.Timestamp.Format(time.RFC3339),
        l.AdminID,
        l.Action,
        l.ResourceType,
        l.OldValue,
        l.NewValue,
    )
    h := sha256.Sum256([]byte(previousHash + data))
    return hex.EncodeToString(h[:])
}
```

### 6.7. パフォーマンス最適化

### 並列処理

```go
// メトリクス並列収集
type ParallelMetricsCollector struct {
    workers   int
    sources   []MetricsSource
    resultsCh chan *MetricData
    errorsCh  chan error
}

// バックアップ並列処理
type ParallelBackupExecutor struct {
    maxConcurrent int
    chunkSize     int64
    compression   CompressionType
}

// 設定配信の並列化
type ConfigurationBroadcaster struct {
    services      []ServiceEndpoint
    maxConcurrent int
    timeout       time.Duration
}
```

### インデックス

```sql
-- アナウンス最適化
CREATE INDEX idx_announcements_schedule ON announcements(publish_at, expire_at) WHERE is_active = true AND is_draft = false;
CREATE INDEX idx_announcement_reads_unread ON announcement_reads(user_id) WHERE read_at IS NULL;

-- 設定最適化
CREATE INDEX idx_system_configurations_category ON system_configurations(category);
CREATE INDEX idx_configuration_history_recent ON configuration_history(changed_at DESC);

-- レート制限最適化
CREATE INDEX idx_rate_limit_rules_pattern ON rate_limit_rules(target_pattern) WHERE is_active = true;
CREATE INDEX idx_rate_limit_violations_recent ON rate_limit_violations(last_violation_at DESC);

-- メトリクス最適化
CREATE INDEX idx_system_metrics_recent ON system_metrics(metric_type, recorded_at DESC);
CREATE INDEX idx_system_metrics_aggregation ON system_metrics(aggregation_period, recorded_at DESC);

-- バックアップ最適化
CREATE INDEX idx_backup_records_running ON backup_records(status) WHERE status = 'running';
CREATE INDEX idx_backup_records_recent ON backup_records(started_at DESC);

-- 監査ログ最適化
CREATE INDEX idx_admin_audit_logs_resource ON admin_audit_logs(resource_type, resource_id, performed_at DESC);
```

## 7. Operations (運用)

### メトリクス

```yaml
system_metrics:
  - config_update_latency
  - announcement_delivery_time
  - backup_duration
  - restore_duration
  - metric_collection_lag

availability_metrics:
  - api_uptime
  - config_service_availability
  - backup_success_rate
  - dashboard_availability

performance_metrics:
  - dashboard_load_time_p50
  - dashboard_load_time_p95
  - dashboard_load_time_p99
  - api_response_time
  - batch_job_duration

volume_metrics:
  - configurations_per_day
  - announcements_per_month
  - backups_per_week
  - metrics_points_per_minute
  - admin_actions_per_hour
```

### アラート

```yaml
critical_alerts:
  - backup_failure
  - config_corruption
  - admin_lockout
  - service_down > 5min
  - storage_full > 90%

warning_alerts:
  - backup_delay > 1hour
  - config_rollback_triggered
  - high_error_rate > 5%
  - storage_usage > 80%
  - metric_collection_failure

info_alerts:
  - maintenance_scheduled
  - backup_completed
  - config_updated
  - new_admin_added
  - monthly_report_ready
```

## 6. Use Cases / Key Flows (主な使い方・処理の流れ)

### 6.1. アナウンス管理フロー

#### アナウンス作成と配信
1. **アナウンス作成**
   - Admin → CreateAnnouncementCommandHandler: アナウンス作成要求
   - CreateAnnouncementCommandHandler: CreateAnnouncementCommandUseCaseを呼び出し
   - CreateAnnouncementCommandUseCase: AnnouncementAggregate生成、バリデーション実行
   - AnnouncementValidationService: コンテンツ、ターゲット、スケジュールの検証
   - AnnouncementRepository: アナウンスデータの永続化
   - 多言語対応: AnnouncementTranslationエンティティの作成

#### スケジュール配信
2. **自動配信処理**
   - AnnouncementDeliveryJob: 定期実行（1分ごと）
   - GetScheduledAnnouncementsQueryService: 配信時刻が到来したアナウンスを取得
   - AnnouncementPublisher: ターゲット条件に基づく配信先決定
   - AnnouncementEventPublisher: `system.announcement.published` イベント発行
   - NotificationService: 各チャネルへの通知配信（SSE、プッシュ、メール）

#### 既読管理
3. **既読状態管理**
   - User → MarkAnnouncementReadCommandHandler: 既読マーク
   - AnnouncementReadsRepository: 既読情報の永続化
   - GetUnreadAnnouncementsQueryService: 未読アナウンス一覧取得
   - GetAnnouncementMetricsQueryService: 既読率、エンゲージメント統計

### 6.2. システム設定管理フロー

#### 設定更新
1. **設定変更処理**
   - Admin → UpdateSystemConfigurationCommandHandler: 設定更新要求
   - UpdateSystemConfigurationCommandHandler: UpdateSystemConfigurationCommandUseCaseを呼び出し
   - ConfigurationValidationService: 新しい設定値のバリデーション
   - SystemConfigurationAggregate: 設定変更の適用、履歴保存
   - ConfigurationHistoryEntity: 変更履歴の記録（前後の値、変更理由）
   - ConfigurationEventPublisher: `system.config.updated` イベント発行

#### 設定配信
2. **各サービスへの設定同期**
   - ConfigurationSyncJob: 定期実行（10秒ごと）
   - ConfigurationBroadcaster: 並列配信処理
   - ServiceEndpoint: 各サービスへのgRPC呼び出し
   - ConfigurationQueryService: キャッシュからの設定取得
   - エラーハンドリング: 失敗サービスのリトライ、アラート通知

#### 設定ロールバック
3. **緊急ロールバック**
   - Admin → RollbackConfigurationCommandHandler: ロールバック要求
   - ConfigurationHistoryRepository: 指定バージョンの設定取得
   - SystemConfigurationAggregate: 前回設定の適用
   - ConfigurationSyncJob: 全サービスへの緊急配信

### 6.3. レート制限管理フロー

#### ルール設定と評価
1. **レート制限ルール作成**
   - Admin → SetRateLimitRuleCommandHandler: ルール作成要求
   - SetRateLimitRuleCommandHandler: SetRateLimitRuleCommandUseCaseを呼び出し
   - RateLimitRuleAggregate: ルールの作成、優先度設定
   - RateLimitEvaluator: ルールの整合性チェック
   - RateLimitRuleRepository: ルール設定の永続化
   - RateLimitEventPublisher: `system.ratelimit.updated` イベント発行

#### リアルタイム評価
2. **APIリクエストのレート制限評価**
   - Gateway → EvaluateRateLimitHandler: レート制限チェック
   - EvaluateRateLimitQueryService: Redisカウンターとルールの照合
   - RateLimitEvaluator: 時間窓ベースのカウンター管理
   - 違反検知: 制限超過時のアクション（スロットリング、拒否）
   - ViolationRecorder: 違反履歴の記録

#### 動的調整
3. **適応的レート制限**
   - RateLimitEvaluationJob: 定期実行（5分ごと）
   - TrafficAnalyzer: トラフィックパターンの分析
   - DynamicRateLimitAdjuster: 負荷に応じた制限値の自動調整
   - AnomalyDetector: 異常トラフィックの検知と緊急制限

### 6.4. メトリクス収集と統計フロー

#### リアルタイム収集
1. **メトリクス収集**
   - MetricsAggregationJob: 定期実行（1分ごと）
   - ParallelMetricsCollector: 並列メトリクス収集
   - PrometheusMetricsService: Prometheusからのメトリクス取得
   - SystemMetricsAggregate: 時間窓別の集約処理
   - TimescaleDBRepository: 時系列データの永続化

#### 統計算出
2. **定期統計計算**
   - StatisticsCalculationJob: 定期実行（1時間ごと）
   - UserStatisticsCalculator: ユーザー統計の算出
   - ContentStatisticsCalculator: コンテンツ統計の算出
   - StorageStatisticsCalculator: ストレージ使用量の算出
   - TrendAnalyzer: 成長トレンドと予測の算出

#### ダッシュボード更新
3. **管理ダッシュボード**
   - DashboardHandler: REST APIエンドポイント
   - DashboardQueryService: キャッシュされた統計情報取得
   - MetricsStreamHandler: WebSocketベースのリアルタイム更新
   - AlertIntegration: アラート状態のリアルタイム表示

### 6.5. バックアップ・リストアフロー

#### バックアップ実行
1. **スケジュールバックアップ**
   - BackupExecutionJob: cronスケジュールで実行
   - BackupPolicyAggregate: バックアップポリシーの管理
   - BackupOrchestrationService: バックアップ処理の統制
   - ParallelBackupExecutor: 複数コンポーネントの並列バックアップ
   - S3StorageService: オブジェクトストレージへのアップロード
   - BackupRecordEntity: バックアップ履歴の記録

#### 検証とリストア
2. **バックアップ検証**
   - BackupVerificationJob: バックアップ後の自動検証
   - IntegrityChecker: チェックサム検証、ファイル整合性チェック
   - RestoreTestExecutor: サンプルデータのリストアテスト
   - BackupVerificationEntity: 検証結果の記録

3. **緊急リストア**
   - Admin → RestoreBackupCommandHandler: リストア要求
   - RestoreBackupCommandUseCase: リストア処理の実行
   - BackupRecordRepository: 対象バックアップの選択と検証
   - RestoreExecutor: コンポーネント別の段階的リストア
   - RestoreHistoryEntity: リストア履歴の記録
   - BackupEventPublisher: `system.backup.restored` イベント発行

### 6.6. 管理者権限管理フロー

#### 管理者作成と権限設定
1. **管理者登録**
   - Owner → CreateAdminUserCommandHandler: 管理者作成要求
   - CreateAdminUserCommandHandler: CreateAdminUserCommandUseCaseを呼び出し
   - AdminUserAggregate: 管理者アカウントの作成
   - PermissionValidator: ロールと権限の検証
   - TwoFactorSetup: 2FAの初期設定（オプション）
   - AdminUserRepository: 管理者情報の永続化

#### ログインとセッション管理
2. **管理者認証**
   - AdminLoginHandler: 管理者ログイン処理
   - AuthenticationService: 認証情報の検証（パスワード + 2FA）
   - SessionManager: 管理者セッションの管理
   - PermissionCache: 権限情報のRedisキャッシュ
   - AuditLogger: ログイン試行の監査ログ記録

#### 監査ログ管理
3. **操作ログ記録**
   - AdminActionInterceptor: 全管理操作のインターセプト
   - AuditLogエンティティ: 操作詳細の記録（ハッシュチェーン付き）
   - LogIntegrityService: 改竄防止のためのハッシュチェーン管理
   - AdminAuditLogRepository: 監査ログの永続化
   - LogRetentionPolicy: ログの保存期限管理（5年保存）

## 8. Data Design (データ設計)

### 8.1. Domain Model (ドメインモデル)

#### Announcement Aggregate (アナウンス集約)
```go
type Announcement struct {
    announcementID AnnouncementID
    title          string
    content        string
    contentFormat  ContentFormat
    targetType     TargetType
    targetCriteria map[string]interface{}
    severity       AnnouncementSeverity
    displayType    DisplayType
    publishAt      time.Time
    expireAt       *time.Time
    createdBy      AdminID
    isActive       bool
    isDraft        bool
    translations   []AnnouncementTranslation
    readCount      int
    dismissCount   int
}

func (a *Announcement) Publish() error {
    if a.isDraft {
        return ErrAnnouncementIsDraft
    }
    if a.publishAt.After(time.Now()) {
        return ErrPublishTimeNotReached
    }
    a.isActive = true
    return nil
}

func (a *Announcement) AddTranslation(language string, title, content string, translatorID AdminID) error {
    // 重複チェック
    for _, t := range a.translations {
        if t.LanguageCode == language {
            return ErrTranslationAlreadyExists
        }
    }
    
    translation := AnnouncementTranslation{
        AnnouncementID: a.announcementID,
        LanguageCode:   language,
        Title:          title,
        Content:        content,
        TranslatedBy:   translatorID,
        TranslatedAt:   time.Now(),
    }
    
    a.translations = append(a.translations, translation)
    return nil
}

func (a *Announcement) IncrementReadCount() {
    a.readCount++
}

func (a *Announcement) CheckExpiry() bool {
    if a.expireAt != nil && time.Now().After(*a.expireAt) {
        a.isActive = false
        return true
    }
    return false
}
```

#### SystemConfiguration Aggregate (システム設定集約)
```go
type SystemConfiguration struct {
    configKey       ConfigurationKey
    configValue     interface{}
    valueType       ValueType
    description     string
    category        ConfigurationCategory
    isSensitive     bool
    isReadonly      bool
    validationRules map[string]interface{}
    updatedBy       AdminID
    version         int
    history         []ConfigurationHistory
}

func (sc *SystemConfiguration) UpdateValue(newValue interface{}, updatedBy AdminID, reason string) error {
    if sc.isReadonly {
        return ErrConfigurationReadonly
    }
    
    // バリデーション実行
    if err := sc.validateValue(newValue); err != nil {
        return fmt.Errorf("validation failed: %w", err)
    }
    
    // 履歴保存
    history := ConfigurationHistory{
        ConfigKey:    sc.configKey,
        OldValue:     sc.configValue,
        NewValue:     newValue,
        ChangedBy:    updatedBy,
        ChangedAt:    time.Now(),
        ChangeReason: reason,
    }
    sc.history = append(sc.history, history)
    
    // 値更新
    sc.configValue = newValue
    sc.updatedBy = updatedBy
    sc.version++
    
    return nil
}

func (sc *SystemConfiguration) validateValue(value interface{}) error {
    // タイプチェック
    if !sc.isValidType(value) {
        return ErrInvalidValueType
    }
    
    // バリデーションルール適用
    for ruleName, ruleValue := range sc.validationRules {
        if err := applyValidationRule(ruleName, value, ruleValue); err != nil {
            return err
        }
    }
    
    return nil
}

func (sc *SystemConfiguration) Rollback(targetVersion int, adminID AdminID) error {
    if targetVersion >= sc.version {
        return ErrInvalidRollbackVersion
    }
    
    // 目標バージョンの設定を検索
    var targetValue interface{}
    for _, h := range sc.history {
        if h.Version == targetVersion {
            targetValue = h.NewValue
            break
        }
    }
    
    if targetValue == nil {
        return ErrVersionNotFound
    }
    
    return sc.UpdateValue(targetValue, adminID, fmt.Sprintf("Rollback to version %d", targetVersion))
}
```

#### RateLimitRule Aggregate (レート制限ルール集約)
```go
type RateLimitRule struct {
    ruleID       RuleID
    ruleName     string
    targetType   TargetType  // endpoint, user, ip, api_key
    targetPattern string
    limitValue   int
    windowSeconds int
    burstSize    int
    windowType   WindowType  // fixed, sliding
    action       LimitAction // throttle, reject, captcha, queue
    priority     int
    conditions   map[string]interface{}
    isActive     bool
    violations   []RateLimitViolation
    effectiveness float64
}

func (rlr *RateLimitRule) EvaluateLimit(target string, currentCount int, windowStart time.Time) (*LimitEvaluation, error) {
    if !rlr.isActive {
        return &LimitEvaluation{Allowed: true}, nil
    }
    
    // ターゲットマッチング
    if !rlr.matchesTarget(target) {
        return &LimitEvaluation{Allowed: true}, nil
    }
    
    // 制限判定
    allowed := currentCount < rlr.limitValue
    
    evaluation := &LimitEvaluation{
        RuleID:        rlr.ruleID,
        Target:        target,
        CurrentCount:  currentCount,
        LimitValue:    rlr.limitValue,
        WindowStart:   windowStart,
        Allowed:       allowed,
        Action:        rlr.action,
        RemainingRequests: max(0, rlr.limitValue - currentCount),
        ResetTime:     windowStart.Add(time.Duration(rlr.windowSeconds) * time.Second),
    }
    
    // 違反記録
    if !allowed {
        violation := RateLimitViolation{
            RuleID:      rlr.ruleID,
            Target:      target,
            ViolatedAt:  time.Now(),
            Count:       currentCount,
            ActionTaken: rlr.action,
        }
        rlr.violations = append(rlr.violations, violation)
    }
    
    return evaluation, nil
}

func (rlr *RateLimitRule) matchesTarget(target string) bool {
    matched, err := filepath.Match(rlr.targetPattern, target)
    if err != nil {
        return false
    }
    return matched
}

func (rlr *RateLimitRule) UpdateEffectiveness() {
    if len(rlr.violations) == 0 {
        rlr.effectiveness = 1.0
        return
    }
    
    // 最近24時間の違反率を基に効果性を計算
    recent := time.Now().Add(-24 * time.Hour)
    recentViolations := 0
    
    for _, v := range rlr.violations {
        if v.ViolatedAt.After(recent) {
            recentViolations++
        }
    }
    
    // 違反率が低いほど効果的
    rlr.effectiveness = 1.0 - (float64(recentViolations) / 1000.0) // 最大1000件で正規化
    if rlr.effectiveness < 0 {
        rlr.effectiveness = 0
    }
}
```

### 8.2. Infrastructure Model (インフラモデル)

#### Database Schema Extensions
```sql
-- アナウンス管理拡張
ALTER TABLE announcements 
ADD COLUMN scheduled_delivery_time TIMESTAMP,
ADD COLUMN delivery_status TEXT DEFAULT 'pending',
ADD COLUMN delivery_channels TEXT[] DEFAULT '{}',
ADD COLUMN engagement_metrics JSONB DEFAULT '{}';

-- メトリクス集約テーブル
CREATE TABLE metric_aggregations (
    aggregation_id UUID PRIMARY KEY,
    metric_type TEXT NOT NULL,
    aggregation_level TEXT NOT NULL, -- minute, hour, day
    time_bucket TIMESTAMP NOT NULL,
    metric_values JSONB NOT NULL,
    sample_count INT NOT NULL,
    calculated_at TIMESTAMP NOT NULL
);

-- レート制限カウンター（Redisバックアップ用）
CREATE TABLE rate_limit_counters_backup (
    backup_id UUID PRIMARY KEY,
    rule_id UUID REFERENCES rate_limit_rules(rule_id),
    target_identifier TEXT NOT NULL,
    window_start TIMESTAMP NOT NULL,
    current_count INT NOT NULL,
    created_at TIMESTAMP NOT NULL,
    expires_at TIMESTAMP NOT NULL
);

-- システムヘルスチェック結果
CREATE TABLE system_health_checks (
    check_id UUID PRIMARY KEY,
    service_name TEXT NOT NULL,
    check_type TEXT NOT NULL,
    status TEXT NOT NULL, -- healthy, degraded, unhealthy
    response_time_ms INT,
    error_message TEXT,
    details JSONB,
    checked_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_metric_aggregations_type_time ON metric_aggregations(metric_type, time_bucket DESC);
CREATE INDEX idx_health_checks_service_time ON system_health_checks(service_name, checked_at DESC);
```

#### Cache Schema Extensions
```
# リアルタイムメトリクス
metrics:realtime:{service}:{metric} -> Current value with timestamp
metrics:alerts:active -> Set of active alert names
metrics:dashboard:cache -> Serialized dashboard data (TTL: 30s)

# システムステータス
maintenance:status -> Current maintenance mode status
maintenance:schedule -> Upcoming maintenance windows
health:services -> Hash of service_name -> health_status

# 設定同期ステータス
config:sync:status:{service} -> Last sync status and timestamp
config:sync:pending -> List of services pending configuration sync
config:version:current -> Current configuration version across all services
```

## 10. エラーハンドリング戦略

> **注意:** エラーコードは[共通エラーコード標準](../common/errors/error-codes.md)に準拠します。このサービスではプレフィックス `SYS` を使用します。

### エラーコード体系

本サービスは、Avionプラットフォーム標準のエラーコード体系に準拠します。

- **命名規則**: `[SERVICE]_[LAYER]_[ERROR_TYPE]`形式
- **エラーカタログ**: [error-catalog.md](./error-catalog.md)
- **実装ガイド**: [共通エラー実装ガイド](../common/errors/implementation-guide.md)
- **標準仕様**: [エラーコード標準化ガイドライン](../common/errors/error-standards.md)

詳細なエラーコード定義とマッピングについては、上記のドキュメントを参照してください。

### 10.1. エラーカテゴリと戦略

#### System Administration Errors (システム管理エラー)
```go
// システム管理領域のドメインエラー
var (
    // アナウンス関連
    ErrAnnouncementIsDraft        = NewDomainError("ANNOUNCEMENT_IS_DRAFT", "下書き状態のアナウンスは公開できません")
    ErrPublishTimeNotReached      = NewDomainError("PUBLISH_TIME_NOT_REACHED", "公開時刻に達していません")
    ErrTranslationAlreadyExists   = NewDomainError("TRANSLATION_ALREADY_EXISTS", "指定言語の翻訳が既に存在します")
    
    // 設定関連
    ErrConfigurationReadonly      = NewDomainError("CONFIGURATION_READONLY", "読み取り専用の設定です")
    ErrInvalidValueType          = NewDomainError("INVALID_VALUE_TYPE", "設定値のタイプが不正です")
    ErrInvalidRollbackVersion    = NewDomainError("INVALID_ROLLBACK_VERSION", "無効なロールバックバージョンです")
    
    // バックアップ関連
    ErrBackupPolicyNotFound      = NewDomainError("BACKUP_POLICY_NOT_FOUND", "バックアップポリシーが見つかりません")
    ErrBackupInProgress          = NewDomainError("BACKUP_IN_PROGRESS", "バックアップが実行中です")
    ErrRestoreNotAuthorized      = NewDomainError("RESTORE_NOT_AUTHORIZED", "リストアの実行権限がありません")
    
    // 管理者関連
    ErrInsufficientPermissions   = NewDomainError("INSUFFICIENT_PERMISSIONS", "操作に必要な権限がありません")
    ErrAdminAccountLocked        = NewDomainError("ADMIN_ACCOUNT_LOCKED", "管理者アカウントがロックされています")
    ErrTwoFactorRequired         = NewDomainError("TWO_FACTOR_REQUIRED", "二段階認証が必要です")
)

// エラーコンテキスト付きドメインエラー
type SystemAdminError struct {
    Code        string                 `json:"code"`
    Message     string                 `json:"message"`
    AdminID     string                 `json:"admin_id,omitempty"`
    Resource    string                 `json:"resource,omitempty"`
    Operation   string                 `json:"operation,omitempty"`
    Context     map[string]interface{} `json:"context,omitempty"`
    Timestamp   time.Time              `json:"timestamp"`
}

func (e SystemAdminError) Error() string {
    return fmt.Sprintf("%s: %s (admin: %s, resource: %s)", 
        e.Code, e.Message, e.AdminID, e.Resource)
}
```

#### Infrastructure Errors with Recovery
```go
// インフラストラクチャエラー
var (
    // ストレージエラー
    ErrS3ConnectionFailed        = NewInfraError("S3_CONNECTION_FAILED", "S3ストレージへの接続が失敗しました", true)
    ErrBackupUploadFailed        = NewInfraError("BACKUP_UPLOAD_FAILED", "バックアップファイルのアップロードに失敗しました", true)
    
    // メトリクスエラー
    ErrPrometheusUnavailable     = NewInfraError("PROMETHEUS_UNAVAILABLE", "Prometheusサーバーが利用できません", true)
    ErrTimescaleDBWriteFailed    = NewInfraError("TIMESCALEDB_WRITE_FAILED", "TimescaleDBへの書き込みに失敗しました", true)
    
    // 通知エラー
    ErrNotificationServiceDown   = NewInfraError("NOTIFICATION_SERVICE_DOWN", "通知サービスが停止しています", false)
    ErrEmailDeliveryFailed       = NewInfraError("EMAIL_DELIVERY_FAILED", "メール配信に失敗しました", true)
)

type InfraErrorWithRecovery struct {
    Code         string    `json:"code"`
    Message      string    `json:"message"`
    Retryable    bool      `json:"retryable"`
    Component    string    `json:"component"`
    RecoveryHint string    `json:"recovery_hint,omitempty"`
    Cause        error     `json:"-"`
    Timestamp    time.Time `json:"timestamp"`
}

func (e InfraErrorWithRecovery) Error() string {
    return fmt.Sprintf("%s: %s [component: %s, retryable: %v]", 
        e.Code, e.Message, e.Component, e.Retryable)
}
```

### 10.2. 特殊なエラーハンドリング

#### バックアップ・リストアエラー対策
```go
type BackupErrorHandler struct {
    storage         StorageService
    notificationSvc NotificationService
    alertManager    AlertManager
}

func (beh *BackupErrorHandler) HandleBackupFailure(backupID string, err error) error {
    backupError := &BackupError{
        BackupID:  backupID,
        Error:     err,
        Timestamp: time.Now(),
        Severity:  beh.classifyErrorSeverity(err),
    }
    
    switch backupError.Severity {
    case SeverityCritical:
        // 緊急アラート送信
        alert := &Alert{
            Level:   "critical",
            Title:   "バックアップ処理の重大な失敗",
            Message: fmt.Sprintf("バックアップ %s が重大エラーで失敗しました: %v", backupID, err),
            Metadata: map[string]interface{}{
                "backup_id": backupID,
                "error_type": reflect.TypeOf(err).Name(),
            },
        }
        beh.alertManager.SendAlert(alert)
        
        // 緊急連絡
        beh.notificationSvc.SendEmergencyNotification("backup-failure", alert.Message)
        
    case SeverityHigh:
        // 自動リトライ
        go beh.scheduleBackupRetry(backupID, 3) // 3回リトライ
        
    case SeverityMedium:
        // メトリクス記録とログ出力
        beh.recordBackupFailureMetrics(backupError)
        
    default:
        // ログ出力のみ
    }
    
    // 失敗履歴の記録
    return beh.recordBackupFailure(backupError)
}

func (beh *BackupErrorHandler) scheduleBackupRetry(backupID string, maxAttempts int) {
    for attempt := 1; attempt <= maxAttempts; attempt++ {
        delay := time.Duration(attempt*attempt) * time.Minute // 指数バックオフ
        time.Sleep(delay)
        
        if err := beh.retryBackup(backupID); err == nil {
            beh.notificationSvc.SendSuccessNotification(
                fmt.Sprintf("バックアップ %s が%d回目のリトライで成功しました", backupID, attempt))
            return
        }
    }
    
    // 最終的に失敗
    beh.alertManager.SendAlert(&Alert{
        Level:   "critical",
        Title:   "バックアップリトライの完全失敗",
        Message: fmt.Sprintf("バックアップ %s が%d回のリトライですべて失敗しました", backupID, maxAttempts),
    })
}
```

#### メトリクス収集エラー対策
```go
type MetricsErrorHandler struct {
    fallbackStorage FallbackMetricsStorage
    circuitBreaker  *CircuitBreaker
    degradedMode    bool
}

func (meh *MetricsErrorHandler) HandleMetricsCollectionFailure(source string, err error) {
    // サーキットブレーカーの状態更新
    meh.circuitBreaker.RecordFailure(source)
    
    // 縮退モードの有効化
    if !meh.degradedMode {
        meh.enableDegradedMode()
    }
    
    // フォールバックストレージにエラー情報を記録
    failureRecord := MetricsFailureRecord{
        Source:    source,
        Error:     err.Error(),
        Timestamp: time.Now(),
        Severity:  meh.assessFailureImpact(source, err),
    }
    
    meh.fallbackStorage.RecordFailure(failureRecord)
    
    // 重大なメトリクスソースの失敗時はアラート
    if meh.isCriticalMetricsSource(source) {
        alert := &Alert{
            Level:   "warning",
            Title:   "重要メトリクス収集の失敗",
            Message: fmt.Sprintf("メトリクスソース %s のデータ収集が失敗しています", source),
            Metadata: map[string]interface{}{
                "source": source,
                "error":  err.Error(),
                "degraded_mode": meh.degradedMode,
            },
        }
        // アラート送信はベストエフォートで実行（失敗してもシステムを停止させない）
        go func() {
            if alertErr := meh.sendAlert(alert); alertErr != nil {
                log.Printf("Failed to send metrics failure alert: %v", alertErr)
            }
        }()
    }
}

func (meh *MetricsErrorHandler) enableDegradedMode() {
    meh.degradedMode = true
    
    // 縮退モードの設定
    // - メトリクス収集頻度を減らす
    // - 非重要メトリクスの収集を停止
    // - キャッシュフォールバックを有効化
    
    log.Println("メトリクス収集が縮退モードに切り替わりました")
    
    // 一定時間後に回復を試行
    time.AfterFunc(10*time.Minute, meh.attemptRecovery)
}
```

### 10.3. エラーモニタリングとアラート

#### 統合エラー監視
```yaml
# Prometheus Alert Rules for System Admin
groups:
  - name: system-admin.errors
    rules:
      - alert: HighSystemAdminErrorRate
        expr: rate(system_admin_errors_total[5m]) > 0.05
        for: 2m
        labels:
          severity: warning
          component: system-admin
        annotations:
          summary: "システム管理エラー率が高くなっています"
          description: "過去5分間のシステム管理エラー率が{{ $value }}です"
          
      - alert: BackupFailureCritical
        expr: increase(backup_failures_total{severity="critical"}[1h]) > 0
        for: 0m
        labels:
          severity: critical
          component: backup
        annotations:
          summary: "バックアップの重大失敗が発生しました"
          description: "バックアップ処理で重大な失敗が{{ $value }}件発生しています"
          
      - alert: ConfigSyncFailure
        expr: increase(config_sync_failures_total[15m]) > 3
        for: 1m
        labels:
          severity: warning
          component: configuration
        annotations:
          summary: "設定同期の繰り返し失敗"
          description: "15分間で設定同期が{{ $value }}回失敗しています"
          
      - alert: MetricsCollectionDegraded
        expr: system_admin_degraded_mode{component="metrics"} == 1
        for: 5m
        labels:
          severity: warning
          component: metrics
        annotations:
          summary: "メトリクス収集が縮退モードで動作しています"
          
      - alert: AdminAccountLockout
        expr: increase(admin_login_failures_total[1h]) > 10
        for: 0m
        labels:
          severity: critical
          component: admin-auth
        annotations:
          summary: "管理者アカウントのログイン失敗が多発しています"
```

## 12. ドメインオブジェクトとDBスキーマのマッピング

### 12.1. 複合エンティティのマッピング

#### Announcement Aggregate ⇔ announcements + announcement_translations
```go
type AnnouncementEntity struct {
    // Primary announcement data
    AnnouncementID string                      `db:"announcement_id" json:"announcement_id"`
    Title          string                      `db:"title" json:"title"`
    Content        string                      `db:"content" json:"content"`
    ContentFormat  string                      `db:"content_format" json:"content_format"`
    TargetType     string                      `db:"target_type" json:"target_type"`
    TargetCriteria string                      `db:"target_criteria" json:"target_criteria"` // JSON
    Severity       string                      `db:"severity" json:"severity"`
    DisplayType    string                      `db:"display_type" json:"display_type"`
    PublishAt      time.Time                   `db:"publish_at" json:"publish_at"`
    ExpireAt       *time.Time                  `db:"expire_at" json:"expire_at,omitempty"`
    CreatedBy      string                      `db:"created_by" json:"created_by"`
    CreatedAt      time.Time                   `db:"created_at" json:"created_at"`
    UpdatedAt      time.Time                   `db:"updated_at" json:"updated_at"`
    IsActive       bool                        `db:"is_active" json:"is_active"`
    IsDraft        bool                        `db:"is_draft" json:"is_draft"`
    ReadCount      int                         `db:"read_count" json:"read_count"`
    DismissCount   int                         `db:"dismiss_count" json:"dismiss_count"`
    
    // Related entities (loaded separately)
    Translations   []AnnouncementTranslationEntity `json:"translations,omitempty"`
    Targets        []AnnouncementTargetEntity      `json:"targets,omitempty"`
}

type AnnouncementTranslationEntity struct {
    AnnouncementID string    `db:"announcement_id" json:"announcement_id"`
    LanguageCode   string    `db:"language_code" json:"language_code"`
    Title          string    `db:"title" json:"title"`
    Content        string    `db:"content" json:"content"`
    TranslatedBy   string    `db:"translated_by" json:"translated_by"`
    TranslatedAt   time.Time `db:"translated_at" json:"translated_at"`
}

// Domain Objectへの変換
func (ae *AnnouncementEntity) ToDomain() (*Announcement, error) {
    announcementID, err := ParseAnnouncementID(ae.AnnouncementID)
    if err != nil {
        return nil, fmt.Errorf("invalid announcement ID: %w", err)
    }
    
    // Target criteriaのJSONデコード
    var targetCriteria map[string]interface{}
    if ae.TargetCriteria != "" {
        if err := json.Unmarshal([]byte(ae.TargetCriteria), &targetCriteria); err != nil {
            return nil, fmt.Errorf("failed to decode target criteria: %w", err)
        }
    }
    
    announcement := &Announcement{
        announcementID: announcementID,
        title:          ae.Title,
        content:        ae.Content,
        contentFormat:  ContentFormat(ae.ContentFormat),
        targetType:     TargetType(ae.TargetType),
        targetCriteria: targetCriteria,
        severity:       AnnouncementSeverity(ae.Severity),
        displayType:    DisplayType(ae.DisplayType),
        publishAt:      ae.PublishAt,
        expireAt:       ae.ExpireAt,
        createdBy:      AdminID(ae.CreatedBy),
        isActive:       ae.IsActive,
        isDraft:        ae.IsDraft,
        readCount:      ae.ReadCount,
        dismissCount:   ae.DismissCount,
    }
    
    // 翻訳データの変換
    for _, te := range ae.Translations {
        translation := AnnouncementTranslation{
            AnnouncementID: announcementID,
            LanguageCode:   te.LanguageCode,
            Title:          te.Title,
            Content:        te.Content,
            TranslatedBy:   AdminID(te.TranslatedBy),
            TranslatedAt:   te.TranslatedAt,
        }
        announcement.translations = append(announcement.translations, translation)
    }
    
    return announcement, nil
}

// Domain Objectからの変換
func NewAnnouncementEntity(announcement *Announcement) (*AnnouncementEntity, error) {
    targetCriteriaJSON, err := json.Marshal(announcement.targetCriteria)
    if err != nil {
        return nil, fmt.Errorf("failed to encode target criteria: %w", err)
    }
    
    entity := &AnnouncementEntity{
        AnnouncementID: string(announcement.announcementID),
        Title:          announcement.title,
        Content:        announcement.content,
        ContentFormat:  string(announcement.contentFormat),
        TargetType:     string(announcement.targetType),
        TargetCriteria: string(targetCriteriaJSON),
        Severity:       string(announcement.severity),
        DisplayType:    string(announcement.displayType),
        PublishAt:      announcement.publishAt,
        ExpireAt:       announcement.expireAt,
        CreatedBy:      string(announcement.createdBy),
        IsActive:       announcement.isActive,
        IsDraft:        announcement.isDraft,
        ReadCount:      announcement.readCount,
        DismissCount:   announcement.dismissCount,
    }
    
    // 翻訳データの変換
    for _, translation := range announcement.translations {
        te := AnnouncementTranslationEntity{
            AnnouncementID: string(translation.AnnouncementID),
            LanguageCode:   translation.LanguageCode,
            Title:          translation.Title,
            Content:        translation.Content,
            TranslatedBy:   string(translation.TranslatedBy),
            TranslatedAt:   translation.TranslatedAt,
        }
        entity.Translations = append(entity.Translations, te)
    }
    
    return entity, nil
}
```

#### SystemConfiguration with History Tracking
```go
type SystemConfigurationEntity struct {
    ConfigKey       string                           `db:"config_key" json:"config_key"`
    ConfigValue     string                           `db:"config_value" json:"config_value"` // JSON
    ValueType       string                           `db:"value_type" json:"value_type"`
    Description     string                           `db:"description" json:"description"`
    Category        string                           `db:"category" json:"category"`
    IsSensitive     bool                             `db:"is_sensitive" json:"is_sensitive"`
    IsReadonly      bool                             `db:"is_readonly" json:"is_readonly"`
    ValidationRules string                           `db:"validation_rules" json:"validation_rules"` // JSON
    UpdatedBy       string                           `db:"updated_by" json:"updated_by"`
    UpdatedAt       time.Time                        `db:"updated_at" json:"updated_at"`
    Version         int                              `db:"version" json:"version"`
    
    // History (loaded separately)
    History         []ConfigurationHistoryEntity     `json:"history,omitempty"`
}

type ConfigurationHistoryEntity struct {
    HistoryID    string     `db:"history_id" json:"history_id"`
    ConfigKey    string     `db:"config_key" json:"config_key"`
    OldValue     *string    `db:"old_value" json:"old_value,omitempty"`    // JSON
    NewValue     string     `db:"new_value" json:"new_value"`             // JSON
    ChangedBy    string     `db:"changed_by" json:"changed_by"`
    ChangedAt    time.Time  `db:"changed_at" json:"changed_at"`
    ChangeReason string     `db:"change_reason" json:"change_reason"`
    Version      int        `db:"version" json:"version"`
    RollbackID   *string    `db:"rollback_id" json:"rollback_id,omitempty"`
}

func (sce *SystemConfigurationEntity) ToDomain() (*SystemConfiguration, error) {
    // JSONデコード
    var configValue interface{}
    if err := json.Unmarshal([]byte(sce.ConfigValue), &configValue); err != nil {
        return nil, fmt.Errorf("failed to decode config value: %w", err)
    }
    
    var validationRules map[string]interface{}
    if sce.ValidationRules != "" {
        if err := json.Unmarshal([]byte(sce.ValidationRules), &validationRules); err != nil {
            return nil, fmt.Errorf("failed to decode validation rules: %w", err)
        }
    }
    
    config := &SystemConfiguration{
        configKey:       ConfigurationKey(sce.ConfigKey),
        configValue:     configValue,
        valueType:       ValueType(sce.ValueType),
        description:     sce.Description,
        category:        ConfigurationCategory(sce.Category),
        isSensitive:     sce.IsSensitive,
        isReadonly:      sce.IsReadonly,
        validationRules: validationRules,
        updatedBy:       AdminID(sce.UpdatedBy),
        version:         sce.Version,
    }
    
    // 履歴データの変換
    for _, he := range sce.History {
        var oldValue interface{}
        if he.OldValue != nil {
            json.Unmarshal([]byte(*he.OldValue), &oldValue)
        }
        
        var newValue interface{}
        json.Unmarshal([]byte(he.NewValue), &newValue)
        
        history := ConfigurationHistory{
            ConfigKey:    ConfigurationKey(he.ConfigKey),
            OldValue:     oldValue,
            NewValue:     newValue,
            ChangedBy:    AdminID(he.ChangedBy),
            ChangedAt:    he.ChangedAt,
            ChangeReason: he.ChangeReason,
            Version:      he.Version,
        }
        config.history = append(config.history, history)
    }
    
    return config, nil
}
```

### 12.2. メトリクスデータのマッピング

#### TimescaleDB 時系列データ
```go
type SystemMetricsEntity struct {
    MetricID         string                 `db:"metric_id" json:"metric_id"`
    MetricType       string                 `db:"metric_type" json:"metric_type"`
    MetricName       string                 `db:"metric_name" json:"metric_name"`
    MetricValue      string                 `db:"metric_value" json:"metric_value"` // JSONB
    Tags             string                 `db:"tags" json:"tags"`                 // JSONB
    RecordedAt       time.Time              `db:"recorded_at" json:"recorded_at"`
    AggregationPeriod string                `db:"aggregation_period" json:"aggregation_period"`
    AggregationType  *string                `db:"aggregation_type" json:"aggregation_type,omitempty"`
}

type MetricAggregationEntity struct {
    AggregationID    string                 `db:"aggregation_id" json:"aggregation_id"`
    MetricType       string                 `db:"metric_type" json:"metric_type"`
    AggregationLevel string                 `db:"aggregation_level" json:"aggregation_level"` // minute, hour, day
    TimeBucket       time.Time              `db:"time_bucket" json:"time_bucket"`
    MetricValues     string                 `db:"metric_values" json:"metric_values"` // JSONB
    SampleCount      int                    `db:"sample_count" json:"sample_count"`
    CalculatedAt     time.Time              `db:"calculated_at" json:"calculated_at"`
}

func (sme *SystemMetricsEntity) ToDomain() (*SystemMetrics, error) {
    var metricValue interface{}
    if err := json.Unmarshal([]byte(sme.MetricValue), &metricValue); err != nil {
        return nil, fmt.Errorf("failed to decode metric value: %w", err)
    }
    
    var tags map[string]string
    if sme.Tags != "" {
        if err := json.Unmarshal([]byte(sme.Tags), &tags); err != nil {
            return nil, fmt.Errorf("failed to decode tags: %w", err)
        }
    }
    
    return &SystemMetrics{
        metricID:         MetricID(sme.MetricID),
        metricType:       sme.MetricType,
        metricName:       sme.MetricName,
        metricValue:      metricValue,
        tags:             tags,
        recordedAt:       sme.RecordedAt,
        aggregationPeriod: AggregationPeriod(sme.AggregationPeriod),
        aggregationType:  (*AggregationType)(sme.AggregationType),
    }, nil
}
```

### 12.3. Repository 実装のトランザクション管理

```go
// 複雑な集約の保存処理
func (r *PostgreSQLAnnouncementRepository) Create(ctx context.Context, announcement *Announcement) error {
    entity, err := NewAnnouncementEntity(announcement)
    if err != nil {
        return fmt.Errorf("failed to convert to entity: %w", err)
    }
    
    tx, err := r.db.BeginTx(ctx, &sql.TxOptions{Isolation: sql.LevelReadCommitted})
    if err != nil {
        return fmt.Errorf("failed to begin transaction: %w", err)
    }
    defer func() {
        if p := recover(); p != nil {
            tx.Rollback()
            panic(p)
        } else if err != nil {
            tx.Rollback()
        } else {
            err = tx.Commit()
        }
    }()
    
    // メインアナウンステーブルに挿入
    announcementQuery := `
        INSERT INTO announcements (
            announcement_id, title, content, content_format, target_type, target_criteria,
            severity, display_type, publish_at, expire_at, created_by, created_at, updated_at,
            is_active, is_draft, read_count, dismiss_count
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
    `
    
    _, err = tx.ExecContext(ctx, announcementQuery,
        entity.AnnouncementID, entity.Title, entity.Content, entity.ContentFormat,
        entity.TargetType, entity.TargetCriteria, entity.Severity, entity.DisplayType,
        entity.PublishAt, entity.ExpireAt, entity.CreatedBy, entity.CreatedAt,
        entity.UpdatedAt, entity.IsActive, entity.IsDraft, entity.ReadCount,
        entity.DismissCount,
    )
    if err != nil {
        return fmt.Errorf("failed to insert announcement: %w", err)
    }
    
    // 翻訳データの挿入
    for _, translation := range entity.Translations {
        translationQuery := `
            INSERT INTO announcement_translations (
                announcement_id, language_code, title, content, translated_by, translated_at
            ) VALUES ($1, $2, $3, $4, $5, $6)
        `
        
        _, err = tx.ExecContext(ctx, translationQuery,
            translation.AnnouncementID, translation.LanguageCode,
            translation.Title, translation.Content,
            translation.TranslatedBy, translation.TranslatedAt,
        )
        if err != nil {
            return fmt.Errorf("failed to insert translation: %w", err)
        }
    }
    
    // ターゲット設定の挿入
    for _, target := range entity.Targets {
        targetQuery := `
            INSERT INTO announcement_targets (
                target_id, announcement_id, target_type, target_value, exclusion_list, created_at
            ) VALUES ($1, $2, $3, $4, $5, $6)
        `
        
        exclusionList := pq.Array(target.ExclusionList)
        _, err = tx.ExecContext(ctx, targetQuery,
            target.TargetID, target.AnnouncementID,
            target.TargetType, target.TargetValue,
            exclusionList, target.CreatedAt,
        )
        if err != nil {
            return fmt.Errorf("failed to insert target: %w", err)
        }
    }
    
    return nil
}
```

このマッピング設計により、ドメインモデルの複雑さを保ちながら、効率的なデータ永続化と整合性保証を実現します。

### 7.1. イベント設計

### 発行イベント

```json
// アナウンス配信
{
  "event_type": "system.announcement.published",
  "announcement_id": "uuid",
  "target_type": "all|group",
  "severity": "info|warning|critical",
  "published_at": "2025-01-01T00:00:00Z"
}

// システム設定変更
{
  "event_type": "system.config.updated",
  "config_key": "string",
  "old_value": "any",
  "new_value": "any",
  "updated_by": "uuid",
  "updated_at": "2025-01-01T00:00:00Z"
}

// レート制限更新
{
  "event_type": "system.ratelimit.updated",
  "rule_id": "uuid",
  "rule_name": "string",
  "limit_value": 100,
  "window_seconds": 60,
  "updated_at": "2025-01-01T00:00:00Z"
}

// バックアップ完了
{
  "event_type": "system.backup.completed",
  "backup_id": "uuid",
  "backup_type": "full|incremental",
  "size_bytes": 1000000,
  "duration_seconds": 300,
  "completed_at": "2025-01-01T00:00:00Z"
}

// メンテナンスモード
{
  "event_type": "system.maintenance.activated",
  "maintenance_type": "planned|emergency",
  "start_time": "2025-01-01T00:00:00Z",
  "estimated_end_time": "2025-01-01T01:00:00Z",
  "affected_services": ["service1", "service2"]
}
```

### 購読イベント

```json
// サービス起動（設定取得）
{
  "event_type": "service.started",
  "service_name": "string",
  "instance_id": "string",
  "started_at": "2025-01-01T00:00:00Z"
}

// メトリクス収集対象
{
  "event_type": "metrics.data.available",
  "source": "string",
  "metric_type": "string",
  "timestamp": "2025-01-01T00:00:00Z"
}
```

## 8. Technical Stack (技術スタック)

- 言語: Go 1.21+
- フレームワーク: なし（標準ライブラリ中心）
- gRPC: google.golang.org/grpc
- REST: net/http + gorilla/mux
- DB: PostgreSQL 15+
- キャッシュ: Redis 7+
- タイムシリーズDB: TimescaleDB（メトリクス用）
- オブジェクトストレージ: S3互換（MinIO/AWS S3）
- メッセージキュー: Redis Pub/Sub
- ジョブスケジューラ: robfig/cron
- 監視: OpenTelemetry, Prometheus
- ログ: uber-go/zap

## 9. Non-Functional Requirements (非機能要件)

### 可用性
- SLA: 99.95%
- RTO: 5分
- RPO: 1分

### パフォーマンス
- ダッシュボード表示: p99 < 500ms
- 統計データ取得: p99 < 200ms
- 設定変更反映: p99 < 1秒
- メトリクス集計: p99 < 300ms
- バックアップ開始: p99 < 5秒
- スループット: 5,000 req/s

### データ保持
- 設定履歴: 無期限
- 統計データ: 3年
- メトリクス: 90日（分）、1年（時）、3年（日）
- バックアップ: 30世代
- 監査ログ: 5年
- アナウンス: 1年

## 10. エラーハンドリング戦略（システム管理特化）

システム管理機能における高い信頼性要求に対応するため、管理操作特有のエラーシナリオに特化した包括的なエラーハンドリング戦略を定義する。

### 10.1. 管理操作エラー分類

#### 権限・認証エラー
- **AdminAuthenticationError**: 管理者認証失敗
  - 多要素認証失敗の場合は即座にセッション終了
  - 連続失敗時は一時的なアカウントロック（15分間）
  - アラート発生と管理者チームへの緊急通知
- **AdminAuthorizationError**: 権限不足エラー
  - 操作権限の詳細な説明とエスカレーション手順を提示
  - 権限変更要求の自動チケット作成
- **PrivilegeEscalationAttempt**: 権限昇格試行の検知
  - セキュリティチームへの即座のアラート
  - 該当セッションの即座終了とIPアドレス記録
  - 自動的な脅威インテリジェンス連携

#### 設定・操作エラー
- **ConfigurationValidationError**: 設定検証エラー
  - 詳細な検証エラー理由と推奨値を提示
  - 設定項目間の依存関係エラーの可視化
  - 安全な設定値の推奨とワンクリック適用
- **ConfigurationConflictError**: 設定競合エラー
  - 他の管理者による同時変更の検知
  - 楽観的ロック機能による競合回避
  - マージ候補の自動生成
- **DangerousOperationError**: 危険操作エラー
  - サービス停止リスクのある操作の事前警告
  - 確認フローの強制（「DELETE」文字列の手動入力等）
  - 操作影響範囲のシミュレーション結果表示

#### システムリソースエラー
- **InsufficientStorageError**: ストレージ不足
  - 自動的な容量拡張提案
  - 古いデータの自動アーカイブ候補提示
  - クラウドプロバイダーとの自動連携による拡張
- **MemoryPressureError**: メモリ圧迫
  - キャッシュの最適化と自動クリア
  - 実行中処理の優先度調整
  - スケールアウトの自動提案
- **DatabaseConnectionError**: データベース接続エラー
  - 接続プール設定の最適化提案
  - レプリケーション状態の自動確認
  - 緊急時のリードオンリーモード切り替え

#### 外部サービス連携エラー
- **ExternalServiceError**: 外部サービス障害
  - サーキットブレーカーによる自動遮断
  - フォールバック処理の自動実行
  - SLA違反アラートの発生
- **BackupServiceError**: バックアップサービスエラー
  - 代替ストレージへの自動切り替え
  - 緊急時のローカルバックアップ作成
  - ランサムウェア対策のエアギャップ処理

### 10.2. エラー回復戦略

#### 自動回復（Auto-Recovery）
```go
type AutoRecoveryConfig struct {
    MaxRetries       int           `json:"max_retries"`
    BackoffStrategy  string        `json:"backoff_strategy"`  // exponential, linear, constant
    CircuitBreaker   bool          `json:"circuit_breaker"`
    FallbackEnabled  bool          `json:"fallback_enabled"`
    AlertThreshold   int           `json:"alert_threshold"`
}

// 自動回復対象エラー
var autoRecoverableErrors = map[error]AutoRecoveryConfig{
    &TransientNetworkError{}: {
        MaxRetries:      3,
        BackoffStrategy: "exponential",
        CircuitBreaker:  true,
    },
    &TemporaryDatabaseError{}: {
        MaxRetries:      5,
        BackoffStrategy: "linear",
        FallbackEnabled: true,
    },
}
```

#### 手動介入（Manual Intervention）
- **高リスク操作**: 管理者の明示的承認が必要
- **設定変更**: 段階的ロールアウトと検証フェーズ
- **データ操作**: 必須のバックアップ確認と復旧テスト

#### 緊急時モード（Emergency Mode）
- **災害時自動起動**: RTO/RPO要件に基づく自動切り替え
- **読み取り専用モード**: データ保護優先の制限モード
- **緊急ロールバック**: ワンクリックでの安全な状態への復帰

### 10.3. エラー通知・エスカレーション

#### 通知レベル定義
- **CRITICAL**: 即座の対応が必要（サービス停止リスク）
  - PagerDutyでの24時間体制アラート
  - 管理責任者への電話・SMS通知
  - エスカレーションフローの自動実行
- **HIGH**: 1時間以内の対応が必要
  - Slackでのメンション付き通知
  - メール通知とダッシュボードアラート
- **MEDIUM**: 営業時間内の対応で可
  - ダッシュボード表示とメール通知
- **LOW**: ログ記録のみ

#### コンテキスト情報の付与
```go
type SystemAdminError struct {
    ErrorCode        string                 `json:"error_code"`
    ErrorMessage     string                 `json:"error_message"`
    AdminID          string                 `json:"admin_id"`
    OperationType    string                 `json:"operation_type"`
    AffectedServices []string               `json:"affected_services"`
    ImpactLevel      string                 `json:"impact_level"`
    Context          map[string]interface{} `json:"context"`
    RecoveryActions  []string               `json:"recovery_actions"`
    EscalationLevel  int                    `json:"escalation_level"`
    Timestamp        time.Time              `json:"timestamp"`
}
```

### 10.4. コンプライアンス対応

#### 規制要件対応
- **SOX法対応**: 監査証跡の改竄防止とアクセス制御
- **GDPR対応**: データ処理エラー時の自動通知機能
- **ISO27001対応**: セキュリティインシデントの分類と記録

#### 監査要件
- **操作履歴**: すべてのエラーを含む完全な操作ログ
- **承認フロー**: 高リスク操作の承認プロセス記録
- **変更管理**: 設定変更の前後状態とロールバック情報

## 11. 構造化ログ戦略（管理者活動中心）

システム管理機能における監査証跡、コンプライアンス要件、セキュリティ監視を目的とした包括的なログ戦略を定義する。

### 11.1. 管理者操作ログ（Admin Activity Logs）

#### 認証・セッション管理
```json
{
  "timestamp": "2025-01-15T10:30:00.123Z",
  "level": "INFO",
  "component": "authentication",
  "event_type": "admin_login_attempt",
  "admin_id": "admin_12345",
  "session_id": "sess_67890",
  "source_ip": "192.168.1.100",
  "user_agent": "Mozilla/5.0...",
  "mfa_method": "totp",
  "mfa_status": "success",
  "geo_location": {
    "country": "JP",
    "region": "Tokyo",
    "city": "Tokyo"
  },
  "risk_score": 0.15,
  "login_result": "success",
  "previous_login": "2025-01-15T09:00:00Z",
  "correlation_id": "corr_abc123"
}
```

#### 設定変更操作
```json
{
  "timestamp": "2025-01-15T10:35:00.456Z",
  "level": "WARN",
  "component": "configuration",
  "event_type": "system_config_update",
  "admin_id": "admin_12345",
  "session_id": "sess_67890",
  "operation": "UPDATE_RATE_LIMIT",
  "resource_id": "rate_limit_api_posts",
  "resource_type": "RATE_LIMIT_RULE",
  "before_state": {
    "limit": 100,
    "window_seconds": 3600,
    "enabled": true
  },
  "after_state": {
    "limit": 150,
    "window_seconds": 3600,
    "enabled": true
  },
  "change_reason": "Increased limit due to legitimate user growth",
  "approval_required": false,
  "impact_assessment": {
    "risk_level": "MEDIUM",
    "affected_users": "ALL",
    "rollback_available": true
  },
  "correlation_id": "corr_def456"
}
```

#### 危険操作・特権操作
```json
{
  "timestamp": "2025-01-15T11:00:00.789Z",
  "level": "CRITICAL",
  "component": "dangerous_operations",
  "event_type": "admin_dangerous_operation",
  "admin_id": "admin_12345",
  "session_id": "sess_67890",
  "operation": "BULK_USER_DELETE",
  "operation_params": {
    "target_users": 25,
    "selection_criteria": "inactive_90days",
    "confirmation_token": "DELETE_USERS_20250115"
  },
  "approval_status": {
    "required": true,
    "approver_id": "super_admin_001",
    "approved_at": "2025-01-15T10:55:00Z",
    "approval_reason": "Data cleanup as per retention policy"
  },
  "execution_result": {
    "status": "SUCCESS",
    "affected_records": 23,
    "errors": 2,
    "duration_ms": 15000
  },
  "rollback_info": {
    "backup_created": true,
    "backup_location": "s3://backups/user_deletion_20250115.sql",
    "rollback_available_until": "2025-02-15T11:00:00Z"
  },
  "correlation_id": "corr_ghi789"
}
```

### 11.2. システム監視ログ（System Monitoring Logs）

#### パフォーマンス監視
```json
{
  "timestamp": "2025-01-15T10:00:00.000Z",
  "level": "INFO",
  "component": "metrics_collection",
  "event_type": "system_metrics_collected",
  "metrics": {
    "cpu_usage": 45.7,
    "memory_usage": 68.2,
    "disk_usage": 34.1,
    "active_connections": 1250,
    "request_rate": 850.5,
    "error_rate": 0.02
  },
  "thresholds": {
    "cpu_warning": 70.0,
    "memory_warning": 80.0,
    "disk_warning": 85.0
  },
  "alerts_triggered": [],
  "collection_duration_ms": 250
}
```

#### バックアップ操作
```json
{
  "timestamp": "2025-01-15T02:00:00.000Z",
  "level": "INFO",
  "component": "backup_system",
  "event_type": "backup_execution",
  "backup_id": "backup_20250115_020000",
  "backup_type": "incremental",
  "triggered_by": "SCHEDULE",
  "policy_id": "daily_incremental_policy",
  "execution_details": {
    "start_time": "2025-01-15T02:00:00Z",
    "end_time": "2025-01-15T02:35:17Z",
    "duration_seconds": 2117,
    "data_size_bytes": 2456789123,
    "compressed_size_bytes": 1234567890,
    "compression_ratio": 0.502
  },
  "storage_details": {
    "primary_location": "s3://avion-backups/2025/01/15/",
    "secondary_location": "azure://avion-backups-dr/2025/01/15/",
    "checksum_sha256": "a1b2c3d4e5f6...",
    "encryption_key_version": "v2025.01"
  },
  "verification": {
    "integrity_check": "PASSED",
    "test_restore": "SCHEDULED",
    "retention_policy_applied": true
  }
}
```

### 11.3. セキュリティ監視ログ（Security Monitoring Logs）

#### 異常アクセス検知
```json
{
  "timestamp": "2025-01-15T14:22:33.567Z",
  "level": "WARN",
  "component": "security_monitor",
  "event_type": "anomalous_admin_behavior",
  "admin_id": "admin_98765",
  "session_id": "sess_xyz123",
  "anomaly_type": "UNUSUAL_ACCESS_PATTERN",
  "anomaly_details": {
    "typical_access_hours": "09:00-18:00 JST",
    "current_access_hour": "14:22 JST",
    "typical_locations": ["Tokyo", "Osaka"],
    "current_location": "Singapore",
    "risk_factors": [
      "access_from_new_location",
      "high_privilege_operations_attempted",
      "rapid_successive_operations"
    ]
  },
  "security_measures": {
    "additional_mfa_required": true,
    "session_timeout_reduced": "15_minutes",
    "high_risk_operations_blocked": true
  },
  "correlation_id": "sec_alert_001"
}
```

#### 権限昇格試行検知
```json
{
  "timestamp": "2025-01-15T15:45:00.123Z",
  "level": "CRITICAL",
  "component": "security_monitor",
  "event_type": "privilege_escalation_attempt",
  "admin_id": "admin_54321",
  "session_id": "sess_def456",
  "escalation_details": {
    "current_role": "operator",
    "requested_operation": "DELETE_ALL_USERS",
    "required_role": "super_admin",
    "attempt_method": "api_parameter_manipulation"
  },
  "security_response": {
    "session_terminated": true,
    "account_temporarily_locked": true,
    "security_team_notified": true,
    "incident_ticket_created": "SEC-2025-0115-001"
  },
  "forensic_data": {
    "source_ip": "203.0.113.42",
    "request_headers": {
      "user-agent": "curl/7.68.0",
      "x-forwarded-for": "198.51.100.123"
    },
    "request_payload_hash": "b2a3c4d5e6f7..."
  }
}
```

### 11.4. コンプライアンス監査ログ（Compliance Audit Logs）

#### データアクセス記録（GDPR対応）
```json
{
  "timestamp": "2025-01-15T16:30:00.000Z",
  "level": "INFO",
  "component": "data_access",
  "event_type": "personal_data_access",
  "admin_id": "admin_11111",
  "session_id": "sess_compliance_001",
  "data_subject_id": "user_target_123",
  "access_purpose": "GDPR_DATA_EXPORT_REQUEST",
  "legal_basis": "Article 15 - Right of access",
  "accessed_data_types": [
    "profile_information",
    "posts_content",
    "interaction_history",
    "system_logs"
  ],
  "data_volume": {
    "records_accessed": 1247,
    "data_size_mb": 15.7
  },
  "retention_notice": "Data exported for subject rights request - 30 day retention",
  "compliance_officer_notified": true
}
```

#### 設定変更承認フロー
```json
{
  "timestamp": "2025-01-15T17:00:00.000Z",
  "level": "INFO",
  "component": "approval_workflow",
  "event_type": "configuration_change_approval",
  "change_request_id": "CR-2025-0115-007",
  "requester_id": "admin_22222",
  "approver_id": "super_admin_003",
  "change_description": "Update data retention policy from 3 years to 5 years",
  "approval_process": {
    "submission_time": "2025-01-15T16:30:00Z",
    "review_time": "2025-01-15T16:50:00Z",
    "approval_time": "2025-01-15T17:00:00Z",
    "approval_reason": "Regulatory compliance requirement update"
  },
  "impact_assessment": {
    "affected_data_categories": ["user_posts", "system_logs", "analytics_data"],
    "storage_impact_gb": 2500.5,
    "cost_impact_monthly": "$450"
  },
  "implementation_scheduled": "2025-01-20T00:00:00Z"
}
```

### 11.5. ログ保護・整合性確保

#### ハッシュチェーンによる改竄防止
```go
type AuditLogEntry struct {
    ID           string    `json:"id"`
    Timestamp    time.Time `json:"timestamp"`
    LogData      string    `json:"log_data"`
    PreviousHash string    `json:"previous_hash"`
    CurrentHash  string    `json:"current_hash"`
    Signature    string    `json:"signature"`  // Digital signature
}

func (entry *AuditLogEntry) CalculateHash() string {
    hasher := sha256.New()
    hasher.Write([]byte(entry.ID + entry.Timestamp.String() + entry.LogData + entry.PreviousHash))
    return hex.EncodeToString(hasher.Sum(nil))
}

func (entry *AuditLogEntry) VerifyIntegrity(previousEntry *AuditLogEntry) bool {
    expectedHash := entry.CalculateHash()
    return entry.CurrentHash == expectedHash && entry.PreviousHash == previousEntry.CurrentHash
}
```

### 11.6. ログ分析・アラート設定

#### 自動脅威検知
- **異常ログイン**: 地理的・時間的異常パターン
- **権限濫用**: 過度な権限使用パターン
- **データ大量アクセス**: 通常範囲を超えるデータアクセス
- **設定変更頻度**: 短時間での大量設定変更

#### メトリクス・ダッシュボード
- **管理者活動サマリ**: 操作種別・時間帯・頻度分析
- **セキュリティ状況**: 脅威レベル・インシデント発生率
- **コンプライアンス状況**: 監査要件充足率・違反発生状況

## 12. ドメインオブジェクトとDBスキーマのマッピング

システム管理機能に特化したドメインオブジェクトとデータベーススキーマ間のマッピング定義。管理者操作の監査証跡、権限管理、コンプライアンス要件を重視した設計。

### 12.1. Announcement Aggregate → announcements テーブル

```sql
CREATE TABLE announcements (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title                VARCHAR(200) NOT NULL,
    content              TEXT NOT NULL,
    target_type          VARCHAR(20) NOT NULL CHECK (target_type IN ('all', 'group', 'individual')),
    target_ids           JSONB, -- 対象ユーザーやグループのIDリスト
    exclusion_ids        JSONB, -- 除外対象のIDリスト
    priority_level       VARCHAR(20) NOT NULL DEFAULT 'info' CHECK (priority_level IN ('info', 'warning', 'critical')),
    status               VARCHAR(20) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'scheduled', 'published', 'expired')),
    publish_at           TIMESTAMPTZ,
    expire_at            TIMESTAMPTZ,
    created_by           UUID NOT NULL REFERENCES admin_users(id),
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    published_at         TIMESTAMPTZ,
    read_count           INTEGER DEFAULT 0,
    target_count         INTEGER DEFAULT 0,
    delivery_stats       JSONB, -- 配信統計情報
    approval_required    BOOLEAN DEFAULT false,
    approved_by          UUID REFERENCES admin_users(id),
    approved_at          TIMESTAMPTZ,
    version              INTEGER NOT NULL DEFAULT 1
);

-- 管理者操作履歴（発表関連）
CREATE TABLE announcement_audit_logs (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    announcement_id      UUID NOT NULL REFERENCES announcements(id),
    admin_id            UUID NOT NULL REFERENCES admin_users(id),
    operation           VARCHAR(50) NOT NULL, -- CREATE, UPDATE, DELETE, PUBLISH, EXPIRE
    before_state        JSONB,
    after_state         JSONB,
    operation_reason    TEXT,
    ip_address          INET,
    user_agent          TEXT,
    session_id          VARCHAR(255),
    correlation_id      VARCHAR(255),
    timestamp           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- 改竄防止のためのハッシュチェーン
    previous_log_hash   VARCHAR(64),
    current_log_hash    VARCHAR(64) NOT NULL,
    integrity_signature TEXT
);
```

**マッピング戦略:**
- `Announcement.ID` → `announcements.id` (UUID)
- `Announcement.TargetType` → `announcements.target_type` (ENUM制約)
- `Announcement.DeliveryStats` → `announcements.delivery_stats` (JSONB構造化データ)
- 監査証跡は別テーブルで完全性を保証

### 12.2. SystemConfiguration Aggregate → system_configurations テーブル

```sql
CREATE TABLE system_configurations (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config_key          VARCHAR(255) NOT NULL UNIQUE,
    config_value        JSONB NOT NULL,
    config_type         VARCHAR(50) NOT NULL, -- STRING, NUMBER, BOOLEAN, OBJECT, ARRAY
    category            VARCHAR(100) NOT NULL, -- security, performance, ui, notification
    description         TEXT,
    default_value       JSONB,
    validation_rules    JSONB, -- バリデーションルール定義
    is_sensitive        BOOLEAN DEFAULT false, -- 機密設定項目フラグ
    requires_restart    BOOLEAN DEFAULT false, -- サービス再起動要否
    environment         VARCHAR(50) DEFAULT 'production', -- development, staging, production
    created_by          UUID NOT NULL REFERENCES admin_users(id),
    updated_by          UUID NOT NULL REFERENCES admin_users(id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    version             INTEGER NOT NULL DEFAULT 1,
    
    -- 段階的ロールアウト制御
    rollout_status      VARCHAR(20) DEFAULT 'inactive', -- inactive, canary, partial, full
    rollout_percentage  INTEGER DEFAULT 0 CHECK (rollout_percentage BETWEEN 0 AND 100),
    rollout_started_at  TIMESTAMPTZ
);

-- 設定変更履歴（バージョン管理）
CREATE TABLE configuration_versions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config_id          UUID NOT NULL REFERENCES system_configurations(id),
    version            INTEGER NOT NULL,
    config_value       JSONB NOT NULL,
    changed_by         UUID NOT NULL REFERENCES admin_users(id),
    change_reason      TEXT,
    change_type        VARCHAR(50), -- CREATE, UPDATE, DELETE, ROLLBACK
    impact_assessment  JSONB, -- 影響分析結果
    approval_status    VARCHAR(20) DEFAULT 'pending', -- pending, approved, rejected
    approved_by        UUID REFERENCES admin_users(id),
    approved_at        TIMESTAMPTZ,
    applied_at         TIMESTAMPTZ,
    rollback_info      JSONB, -- ロールバック情報
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(config_id, version)
);
```

**マッピング戦略:**
- `SystemConfiguration.ConfigurationKey` → `system_configurations.config_key`
- `SystemConfiguration.ConfigurationValue` → `system_configurations.config_value` (型付きJSONB)
- バージョン履歴は`ConfigurationVersion`エンティティとして分離
- 段階的ロールアウト情報を直接テーブルに格納

### 12.3. RateLimitRule Aggregate → rate_limit_rules テーブル

```sql
CREATE TABLE rate_limit_rules (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_name          VARCHAR(100) NOT NULL,
    description        TEXT,
    endpoint_pattern   VARCHAR(500) NOT NULL, -- APIエンドポイントパターン
    http_method        VARCHAR(10), -- GET, POST, PUT, DELETE, ALL
    limit_type         VARCHAR(20) NOT NULL CHECK (limit_type IN ('ip', 'user', 'api_key', 'global')),
    window_type        VARCHAR(20) NOT NULL CHECK (window_type IN ('fixed', 'sliding', 'token_bucket')),
    window_duration    INTEGER NOT NULL, -- 時間窓（秒）
    request_limit      INTEGER NOT NULL, -- リクエスト制限数
    burst_limit        INTEGER, -- バースト制限
    refill_rate        DECIMAL(10,2), -- トークン補充レート
    priority           INTEGER NOT NULL DEFAULT 100, -- ルール適用優先度
    is_active          BOOLEAN NOT NULL DEFAULT true,
    whitelist_ips      INET[], -- 除外IPアドレス
    blacklist_ips      INET[], -- ブロック対象IPアドレス
    whitelist_users    UUID[], -- 除外ユーザー
    created_by         UUID NOT NULL REFERENCES admin_users(id),
    updated_by         UUID NOT NULL REFERENCES admin_users(id),
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_from     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    effective_until    TIMESTAMPTZ,
    
    -- レート制限効果測定
    applied_count      BIGINT DEFAULT 0, -- 適用回数
    blocked_count      BIGINT DEFAULT 0, -- ブロック回数
    last_applied_at    TIMESTAMPTZ,
    
    INDEX idx_rate_limit_endpoint (endpoint_pattern),
    INDEX idx_rate_limit_priority (priority DESC),
    INDEX idx_rate_limit_active (is_active, effective_from, effective_until)
);

-- レート制限イベントログ
CREATE TABLE rate_limit_events (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id           UUID NOT NULL REFERENCES rate_limit_rules(id),
    event_type        VARCHAR(20) NOT NULL, -- APPLIED, BLOCKED, EXCEEDED
    client_identifier VARCHAR(255), -- IP or User ID or API Key
    endpoint          VARCHAR(500),
    current_count     INTEGER,
    limit_exceeded_by INTEGER,
    timestamp         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    request_info      JSONB, -- リクエスト詳細情報
    
    INDEX idx_rate_limit_events_timestamp (timestamp),
    INDEX idx_rate_limit_events_client (client_identifier)
);
```

**マッピング戦略:**
- `RateLimitRule.RateLimit` → `rate_limit_rules.request_limit`
- `RateLimitWindow` → `rate_limit_rules.window_*`フィールド群
- 効果測定メトリクスをテーブルに直接格納
- イベントログは別テーブルでパフォーマンス最適化

### 12.4. AdminUser Aggregate → admin_users テーブル

```sql
CREATE TABLE admin_users (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username             VARCHAR(100) NOT NULL UNIQUE,
    email                VARCHAR(255) NOT NULL UNIQUE,
    full_name            VARCHAR(200),
    role                 VARCHAR(50) NOT NULL CHECK (role IN ('super_admin', 'admin', 'operator', 'viewer')),
    status               VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'inactive')),
    
    -- 認証・セキュリティ
    password_hash        VARCHAR(255), -- NULL for external auth
    mfa_enabled          BOOLEAN NOT NULL DEFAULT false,
    mfa_secret           VARCHAR(255), -- TOTP secret (encrypted)
    backup_codes         TEXT[], -- 緊急時バックアップコード (encrypted)
    last_login_at        TIMESTAMPTZ,
    last_login_ip        INET,
    failed_login_count   INTEGER DEFAULT 0,
    locked_until         TIMESTAMPTZ,
    
    -- セッション管理
    current_session_id   VARCHAR(255),
    session_expires_at   TIMESTAMPTZ,
    max_concurrent_sessions INTEGER DEFAULT 1,
    
    -- 権限・制約
    permissions          JSONB, -- 詳細権限設定
    ip_restrictions      INET[], -- アクセス許可IP範囲
    time_restrictions    JSONB, -- アクセス許可時間帯
    resource_restrictions JSONB, -- アクセス可能リソース制限
    
    -- 運用情報
    created_by           UUID REFERENCES admin_users(id),
    created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_by           UUID REFERENCES admin_users(id),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    password_updated_at  TIMESTAMPTZ,
    must_change_password BOOLEAN DEFAULT false,
    
    -- 監査情報
    last_activity_at     TIMESTAMPTZ,
    total_logins         INTEGER DEFAULT 0,
    risk_score           DECIMAL(5,3) DEFAULT 0.000,
    
    INDEX idx_admin_users_email (email),
    INDEX idx_admin_users_role (role),
    INDEX idx_admin_users_status (status)
);

-- 管理者操作監査ログ（全操作）
CREATE TABLE admin_audit_logs (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id            UUID NOT NULL REFERENCES admin_users(id),
    session_id          VARCHAR(255) NOT NULL,
    operation_type      VARCHAR(100) NOT NULL,
    resource_type       VARCHAR(100),
    resource_id         VARCHAR(255),
    operation_details   JSONB NOT NULL,
    result_status       VARCHAR(20) NOT NULL, -- SUCCESS, FAILURE, PARTIAL
    error_details       JSONB,
    
    -- リクエスト情報
    ip_address          INET NOT NULL,
    user_agent          TEXT,
    referer             TEXT,
    correlation_id      VARCHAR(255),
    
    -- セキュリティ情報
    risk_level          VARCHAR(20) DEFAULT 'low', -- low, medium, high, critical
    geo_location        JSONB,
    device_fingerprint  TEXT,
    
    -- 影響分析
    affected_records    INTEGER,
    impact_scope        VARCHAR(100),
    rollback_available  BOOLEAN DEFAULT false,
    
    timestamp           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- 改竄防止
    previous_log_hash   VARCHAR(64),
    current_log_hash    VARCHAR(64) NOT NULL,
    digital_signature   TEXT,
    
    INDEX idx_admin_audit_admin (admin_id, timestamp DESC),
    INDEX idx_admin_audit_operation (operation_type, timestamp DESC),
    INDEX idx_admin_audit_risk (risk_level, timestamp DESC)
);
```

**マッピング戦略:**
- `AdminUser.Role` → `admin_users.role` (ENUM制約)
- `Permission` → `admin_users.permissions` (JSONB構造化)
- セッション管理情報を直接格納
- 全操作の監査証跡を別テーブルで完全記録

### 12.5. SystemMetrics Aggregate → system_metrics テーブル (TimescaleDB)

```sql
-- メトリクスデータ（時系列特化）
CREATE TABLE system_metrics (
    time                TIMESTAMPTZ NOT NULL,
    metric_name        VARCHAR(100) NOT NULL,
    metric_type        VARCHAR(50) NOT NULL, -- counter, gauge, histogram, summary
    value              DOUBLE PRECISION NOT NULL,
    labels             JSONB, -- メトリクスラベル
    source_service     VARCHAR(100),
    source_instance    VARCHAR(100),
    
    -- 集計情報（histogram/summary用）
    bucket_bounds      DOUBLE PRECISION[],
    bucket_counts      BIGINT[],
    quantiles          JSONB, -- {p50: 0.123, p95: 0.456, p99: 0.789}
    
    -- メタデータ
    collection_method  VARCHAR(50), -- push, pull, calculated
    reliability_score  DECIMAL(3,2) DEFAULT 1.00, -- データ信頼性スコア
    
    PRIMARY KEY (time, metric_name, labels)
);

-- TimescaleDB拡張（時系列DB最適化）
SELECT create_hypertable('system_metrics', 'time', chunk_time_interval => INTERVAL '1 hour');
CREATE INDEX idx_system_metrics_name_time ON system_metrics (metric_name, time DESC);
CREATE INDEX idx_system_metrics_service_time ON system_metrics (source_service, time DESC);

-- メトリクス集計結果キャッシュ
CREATE TABLE metrics_aggregates (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    metric_name       VARCHAR(100) NOT NULL,
    aggregation_type  VARCHAR(20) NOT NULL, -- sum, avg, max, min, p50, p95, p99
    time_range_start  TIMESTAMPTZ NOT NULL,
    time_range_end    TIMESTAMPTZ NOT NULL,
    granularity       VARCHAR(20) NOT NULL, -- minute, hour, day, week, month
    aggregated_value  DOUBLE PRECISION NOT NULL,
    data_points_count INTEGER NOT NULL,
    labels           JSONB,
    calculated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at       TIMESTAMPTZ,
    
    UNIQUE(metric_name, aggregation_type, time_range_start, time_range_end, granularity, labels)
);
```

**マッピング戦略:**
- `SystemMetrics` → TimescaleDBによる時系列最適化
- `MetricDataPoint` → `system_metrics`の各行
- 集計結果は別テーブルでキャッシュ化
- ラベル情報はJSONBで柔軟性を確保

### 12.6. BackupPolicy Aggregate → backup_policies テーブル

```sql
CREATE TABLE backup_policies (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_name        VARCHAR(100) NOT NULL UNIQUE,
    description        TEXT,
    backup_type        VARCHAR(20) NOT NULL CHECK (backup_type IN ('full', 'incremental', 'differential')),
    
    -- スケジュール設定
    schedule_cron      VARCHAR(100) NOT NULL, -- cron式
    timezone           VARCHAR(50) DEFAULT 'UTC',
    enabled            BOOLEAN NOT NULL DEFAULT true,
    
    -- バックアップ範囲
    target_databases   TEXT[] NOT NULL, -- 対象データベース
    target_schemas     TEXT[], -- 対象スキーマ
    excluded_tables    TEXT[], -- 除外テーブル
    include_media      BOOLEAN DEFAULT true,
    
    -- 保存設定
    retention_days     INTEGER NOT NULL DEFAULT 30,
    max_backup_count   INTEGER DEFAULT 50,
    storage_class      VARCHAR(50) DEFAULT 'standard', -- standard, ia, glacier
    compression_type   VARCHAR(20) DEFAULT 'gzip', -- none, gzip, lz4, zstd
    encryption_enabled BOOLEAN NOT NULL DEFAULT true,
    
    -- 品質保証
    verification_enabled BOOLEAN NOT NULL DEFAULT true,
    test_restore_enabled BOOLEAN DEFAULT false,
    integrity_check_enabled BOOLEAN NOT NULL DEFAULT true,
    
    -- 通知設定
    notification_on_success BOOLEAN DEFAULT false,
    notification_on_failure BOOLEAN NOT NULL DEFAULT true,
    notification_channels JSONB, -- slack, email, webhook
    
    created_by         UUID NOT NULL REFERENCES admin_users(id),
    updated_by         UUID NOT NULL REFERENCES admin_users(id),
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_executed_at   TIMESTAMPTZ,
    next_execution_at  TIMESTAMPTZ
);

-- バックアップ実行履歴
CREATE TABLE backup_executions (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    policy_id         UUID NOT NULL REFERENCES backup_policies(id),
    backup_type       VARCHAR(20) NOT NULL,
    status            VARCHAR(20) NOT NULL DEFAULT 'running' 
                     CHECK (status IN ('running', 'completed', 'failed', 'cancelled')),
    
    -- 実行情報
    started_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at      TIMESTAMPTZ,
    duration_seconds  INTEGER,
    
    -- データ統計
    total_size_bytes       BIGINT,
    compressed_size_bytes  BIGINT,
    compression_ratio      DECIMAL(5,4),
    files_backed_up        INTEGER,
    
    -- ストレージ情報
    storage_location       TEXT, -- S3 path, etc.
    storage_provider       VARCHAR(50),
    checksum_sha256        VARCHAR(64),
    encryption_key_id      VARCHAR(255),
    
    -- 品質情報
    integrity_verified     BOOLEAN DEFAULT false,
    test_restore_passed    BOOLEAN,
    verification_details   JSONB,
    
    -- エラー情報
    error_message         TEXT,
    error_code           VARCHAR(50),
    retry_count          INTEGER DEFAULT 0,
    
    -- 運用情報
    triggered_by          VARCHAR(20) DEFAULT 'schedule', -- schedule, manual, event
    triggered_by_admin    UUID REFERENCES admin_users(id),
    
    INDEX idx_backup_executions_policy (policy_id, started_at DESC),
    INDEX idx_backup_executions_status (status, started_at DESC)
);
```

**マッピング戦略:**
- `BackupPolicy.BackupSchedule` → `backup_policies.schedule_cron`
- `BackupRecord` → `backup_executions`テーブル
- 品質保証情報を構造化して記録
- 暗号化・圧縮情報の完全な監査証跡

### 12.7. Redis キャッシュ戦略

```go
// システム設定キャッシュ
type ConfigurationCache struct {
    Key   string      `redis:"key"`
    Value interface{} `redis:"value"`
    TTL   int         `redis:"ttl"` // seconds
}

// キャッシュキー設計
var cacheKeys = map[string]string{
    "system_config":     "sys:config:{key}",           // TTL: 300s
    "rate_limit":        "rl:rule:{endpoint}:{type}",  // TTL: 60s
    "admin_permissions": "admin:perms:{admin_id}",     // TTL: 900s
    "metrics_aggregate": "metrics:agg:{name}:{range}", // TTL: 180s
    "backup_status":     "backup:status:{policy_id}",  // TTL: 30s
}

// 分散ロック（設定変更時の排他制御）
type DistributedLock struct {
    Key       string `redis:"key"`
    Token     string `redis:"token"`
    ExpiresAt int64  `redis:"expires_at"`
}
```

### 12.8. 監査証跡の改竄防止機構

```sql
-- 監査ログのハッシュチェーンテーブル
CREATE TABLE audit_hash_chain (
    id               BIGSERIAL PRIMARY KEY,
    table_name      VARCHAR(100) NOT NULL, -- 対象テーブル名
    record_id       UUID NOT NULL, -- 監査対象レコードID
    sequence_number BIGINT NOT NULL, -- ハッシュチェーンのシーケンス番号
    previous_hash   VARCHAR(64), -- 前のハッシュ
    current_hash    VARCHAR(64) NOT NULL, -- 現在のハッシュ
    record_data     JSONB NOT NULL, -- レコードデータ
    timestamp       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    UNIQUE(table_name, sequence_number)
);

-- デジタル署名検証用公開鍵ストア
CREATE TABLE audit_signing_keys (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key_version    VARCHAR(20) NOT NULL,
    public_key     TEXT NOT NULL, -- PEM形式公開鍵
    algorithm      VARCHAR(50) NOT NULL DEFAULT 'RSA-SHA256',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at     TIMESTAMPTZ,
    revoked_at     TIMESTAMPTZ,
    status         VARCHAR(20) NOT NULL DEFAULT 'active'
                   CHECK (status IN ('active', 'expired', 'revoked'))
);
```

この設計により、システム管理機能の高い信頼性要求、コンプライアンス要件、セキュリティ監視要求を満たすデータ構造を実現する。

## 13. システム管理特化設計の統合

本設計では、一般的なマイクロサービス設計を超えて、システム管理特有の要求事項に特化した包括的なアプローチを採用しています。

### 13.1. 監査証跡・コンプライアンス統合アーキテクチャ

#### 完全な操作追跡
- **全管理者操作の記録**: すべての操作が改竄防止機能付きの監査ログに記録
- **ハッシュチェーン**: ログの連続性と整合性を暗号学的に保証
- **デジタル署名**: 監査ログの認証性を確保
- **GDPR/SOX法対応**: 法的要件を満たす証跡管理

#### 権限管理の階層設計
- **役割ベース権限制御**: super_admin > admin > operator > viewer
- **リソースレベル権限**: 操作対象リソース単位の細かな権限制御
- **時間・場所制限**: IP制限・時間帯制限による追加セキュリティ層
- **動的権限評価**: コンテキストベースの権限判定

### 13.2. 危険操作制御・安全性確保

#### リスク分析エンジン
- **操作危険度評価**: システム停止・データ損失リスクの自動評価
- **承認フロー統合**: 高リスク操作の強制的な承認プロセス
- **影響範囲分析**: 変更による影響を事前にシミュレーション
- **ロールバック機能**: 安全な状態への復帰を常に保証

#### 段階的制御機構
- **カナリアデプロイメント**: 設定変更の段階的適用
- **自動異常検知**: メトリクス監視による異常状態の早期検出
- **緊急停止機能**: 問題発生時の即座な処理停止
- **セルフヒーリング**: 可能な範囲での自動修復機能

## 13. Integration Specifications (連携仕様)

### 13.1. avion-auth との連携

**Purpose:** 管理者認証と権限管理の統合

**Integration Method:** gRPC

**Data Flow:**
1. avion-system-admin が管理者認証要求を avion-auth に送信
2. avion-auth が認証結果と権限情報を返却
3. avion-system-admin が操作権限を検証
4. 操作実行後、avion-auth に監査ログを送信

**Error Handling:** 認証サービス障害時はローカルセッション管理にフォールバック

### 13.2. avion-notification との連携

**Purpose:** システム管理アラートとアナウンス配信

**Integration Method:** gRPC + Events

**Data Flow:**
1. システム異常検知時に avion-notification にアラート送信
2. アナウンス作成時に配信対象ユーザー情報を取得
3. アナウンス配信指示を avion-notification に送信
4. 配信結果をイベントで受信

**Error Handling:** 通知配信失敗時はリトライ機構とエスカレーション

### 13.3. Event Publishing

**Events Published:**
- `system.config.updated`: システム設定変更時
- `system.announcement.created`: アナウンス作成時
- `system.backup.completed`: バックアップ完了時
- `system.admin.action`: 管理者操作実行時
- `system.security.alert`: セキュリティアラート発生時

**Event Schema:**
```go
type SystemConfigUpdatedEvent struct {
    ConfigID    string                 `json:"config_id"`
    Key         string                 `json:"key"`
    OldValue    interface{}            `json:"old_value"`
    NewValue    interface{}            `json:"new_value"`
    UpdatedBy   string                 `json:"updated_by"`
    Timestamp   time.Time              `json:"timestamp"`
    AffectedServices []string          `json:"affected_services"`
}

type AnnouncementCreatedEvent struct {
    AnnouncementID string       `json:"announcement_id"`
    Title         string       `json:"title"`
    Priority      string       `json:"priority"`
    TargetType    string       `json:"target_type"`
    TargetCount   int          `json:"target_count"`
    CreatedBy     string       `json:"created_by"`
    PublishAt     time.Time    `json:"publish_at"`
    Timestamp     time.Time    `json:"timestamp"`
}
```

## 14. Concerns / Open Questions (懸念事項・相談したいこと)

### 技術的懸念
- **バックアップパフォーマンス**: 大容量データのバックアップ時間が目標(RTO 5分)を超過する可能性
- **メトリクス収集負荷**: 全サービスからのメトリクス収集がシステムに与える負荷影響
- **権限管理複雑性**: 細粒度権限制御の実装と運用の複雑さのバランス
- **監査ログ整合性**: 分散環境での監査ログの完全性保証メカニズム

### パフォーマンス懸念
- **ダッシュボード応答性**: リアルタイムメトリクス表示とデータベース負荷のバランス
- **設定変更伝播遅延**: 多数のサービスへの設定配信時の遅延とタイムアウト処理
- **レート制限評価負荷**: 高頻度APIリクエストでのレート制限判定処理の影響

### セキュリティ懸念
- **管理者権限エスカレーション**: 権限昇格攻撃に対する多層防御の有効性
- **監査証跡改竄防止**: ログ改竄に対する暗号学的保証の実装方式
- **秘匿設定管理**: 機密設定値の暗号化と鍵管理の運用安全性

### 今後の検討事項
- **AIベース異常検知**: 機械学習による高度な異常検知アルゴリズムの導入
- **自動復旧範囲**: どこまでの障害を自動復旧対象とするかの境界線
- **コンプライアンス自動化**: GDPR/SOX法要求への完全自動対応の実現可能性
- **マルチクラウド対応**: 複数クラウドプロバイダーでの運用時の課題と対策

### 13.3. セキュリティファースト設計

#### 多層防御アーキテクチャ
- **多要素認証**: 管理者アクセスの強制的なMFA
- **異常行動検知**: AIベースの管理者行動分析
- **セッション管理**: 厳格なセッション制御とタイムアウト
- **暗号化**: 機密データの end-to-end 暗号化

#### 脅威対応システム
- **リアルタイム監視**: 24/7のセキュリティ監視
- **自動インシデント対応**: 脅威検知時の自動的な保護措置
- **フォレンジック支援**: インシデント調査のための詳細証跡
- **外部脅威連携**: 脅威インテリジェンス情報との自動連携

### 13.4. 可用性・災害復旧

#### レジリエント設計
- **無停止運用**: システムを停止させない変更管理
- **フェイルセーフ**: 障害時の安全側への自動制御
- **冗長化**: 単一障害点の排除
- **自動フェイルオーバー**: 障害時の自動的なサービス継続

#### 災害復旧戦略
- **3-2-1バックアップ**: 地理的分散による災害対策
- **定期的復旧訓練**: RTO/RPO要件の実践的検証
- **段階的復旧計画**: 優先度ベースの体系的復旧手順
- **依存関係管理**: サービス間依存関係を考慮した復旧計画

### 13.5. 運用効率化・自動化

#### インテリジェントオートメーション
- **予測分析**: 機械学習による障害予兆検知
- **自動最適化**: システム負荷に応じた動的調整
- **容量管理**: 使用状況に基づく自動スケーリング
- **コスト最適化**: リソース使用効率の継続的改善

#### 意思決定支援
- **メトリクス駆動**: 客観的データに基づく運用判断
- **ダッシュボード**: 重要指標のリアルタイム可視化
- **アラート管理**: 重要度別の適切な通知制御
- **レポート自動生成**: 定期的な運用状況報告

### 13.6. 将来拡張性・保守性

#### モジュラー設計
- **プラグアーキテクチャ**: 機能追加のための拡張ポイント
- **API駆動**: 外部システムとの柔軟な連携
- **設定駆動**: コード変更不要な機能調整
- **バージョン管理**: 下位互換性を保った機能進化

#### 技術負債管理
- **コード品質**: 自動化されたコード品質管理
- **依存関係管理**: ライブラリ・フレームワークの定期更新
- **パフォーマンス監視**: 継続的な性能向上活動
- **リファクタリング**: 計画的な技術負債解消

この統合設計により、avion-system-adminは単なるシステム管理機能を超えて、企業レベルのガバナンス・リスク・コンプライアンス要求に対応する堅牢な基盤として機能します。

## 14. Service-Specific Test Strategy

### 14.1. Overview

avion-system-adminは企業システムの重要な運用機能を管理するため、特に厳格なテスト戦略が必要です。本セクションでは、システム管理特有の要求事項に対応するための包括的なテスト手法を定義します。

### 14.2. Critical Test Areas

#### 14.2.1. Dangerous Operation Approval Workflow Testing

危険操作の承認ワークフローは、システム安全性の要となるため、以下のシナリオを網羅的にテストします：

```go
package dangerous_operation_test

import (
    "context"
    "testing"
    "time"

    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/mock"
    "github.com/newmo-oss/ctxtime"
    
    "avion/internal/domain/dangerous_operation"
    "avion/internal/usecase/approval"
    "avion/tests/mocks"
)

func TestDangerousOperationApprovalWorkflow(t *testing.T) {
    tests := []struct {
        name           string
        operation      dangerous_operation.Operation
        approvers      []string
        requiredCount  int
        timeout        time.Duration
        setupMocks     func(*mocks.MockApprovalRepository, *mocks.MockNotificationService)
        expectError    bool
        expectedStatus dangerous_operation.Status
    }{
        {
            name: "successful_mass_deletion_approval",
            operation: dangerous_operation.Operation{
                Type:        dangerous_operation.TypeMassDeletion,
                Target:      "users.inactive_accounts",
                Parameters:  map[string]interface{}{"threshold": "90_days"},
                RequestedBy: "admin@example.com",
                Reason:      "Compliance requirement for data retention",
            },
            approvers:      []string{"security@example.com", "legal@example.com"},
            requiredCount:  2,
            timeout:        30 * time.Minute,
            setupMocks: func(repo *mocks.MockApprovalRepository, notif *mocks.MockNotificationService) {
                repo.EXPECT().CreateApprovalRequest(mock.Anything, mock.Anything).Return(nil)
                notif.EXPECT().SendApprovalRequest(mock.Anything, mock.Anything).Return(nil).Times(2)
                repo.EXPECT().RecordApproval(mock.Anything, mock.Anything, mock.Anything).Return(nil).Times(2)
                repo.EXPECT().GetApprovalStatus(mock.Anything, mock.Anything).Return(
                    &dangerous_operation.ApprovalStatus{
                        Approved:       2,
                        Required:       2,
                        RemainingTime:  25 * time.Minute,
                        Status:         dangerous_operation.StatusApproved,
                    }, nil)
            },
            expectError:    false,
            expectedStatus: dangerous_operation.StatusApproved,
        },
        {
            name: "timeout_rejection",
            operation: dangerous_operation.Operation{
                Type:        dangerous_operation.TypeSystemShutdown,
                Target:      "production.all_services",
                RequestedBy: "ops@example.com",
                Reason:      "Emergency maintenance",
            },
            approvers:     []string{"cto@example.com"},
            requiredCount: 1,
            timeout:       1 * time.Minute,
            setupMocks: func(repo *mocks.MockApprovalRepository, notif *mocks.MockNotificationService) {
                repo.EXPECT().CreateApprovalRequest(mock.Anything, mock.Anything).Return(nil)
                notif.EXPECT().SendApprovalRequest(mock.Anything, mock.Anything).Return(nil)
                // Simulate timeout without approval
                repo.EXPECT().GetApprovalStatus(mock.Anything, mock.Anything).Return(
                    &dangerous_operation.ApprovalStatus{
                        Approved:      0,
                        Required:      1,
                        RemainingTime: 0,
                        Status:        dangerous_operation.StatusTimeout,
                    }, nil)
                repo.EXPECT().MarkAsTimedOut(mock.Anything, mock.Anything).Return(nil)
            },
            expectError:    false,
            expectedStatus: dangerous_operation.StatusTimeout,
        },
        {
            name: "insufficient_approvals",
            operation: dangerous_operation.Operation{
                Type:        dangerous_operation.TypeConfigurationChange,
                Target:      "security.authentication_policy",
                Parameters:  map[string]interface{}{"mfa_required": true},
                RequestedBy: "security@example.com",
                Reason:      "Enhanced security requirements",
            },
            approvers:     []string{"admin1@example.com", "admin2@example.com", "admin3@example.com"},
            requiredCount: 3,
            timeout:       15 * time.Minute,
            setupMocks: func(repo *mocks.MockApprovalRepository, notif *mocks.MockNotificationService) {
                repo.EXPECT().CreateApprovalRequest(mock.Anything, mock.Anything).Return(nil)
                notif.EXPECT().SendApprovalRequest(mock.Anything, mock.Anything).Return(nil).Times(3)
                repo.EXPECT().RecordApproval(mock.Anything, mock.Anything, mock.Anything).Return(nil).Times(2)
                repo.EXPECT().GetApprovalStatus(mock.Anything, mock.Anything).Return(
                    &dangerous_operation.ApprovalStatus{
                        Approved:      2,
                        Required:      3,
                        RemainingTime: 10 * time.Minute,
                        Status:        dangerous_operation.StatusPending,
                    }, nil)
            },
            expectError:    false,
            expectedStatus: dangerous_operation.StatusPending,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Setup mocks
            mockRepo := new(mocks.MockApprovalRepository)
            mockNotif := new(mocks.MockNotificationService)
            mockAudit := new(mocks.MockAuditLogger)
            
            tt.setupMocks(mockRepo, mockNotif)
            
            // Create service with time mocking
            ctx := ctxtime.WithTime(context.Background(), time.Now())
            service := approval.NewService(mockRepo, mockNotif, mockAudit)
            
            // Execute test
            result, err := service.RequestApproval(ctx, &approval.Request{
                Operation:     tt.operation,
                Approvers:     tt.approvers,
                RequiredCount: tt.requiredCount,
                Timeout:       tt.timeout,
            })
            
            // Assertions
            if tt.expectError {
                assert.Error(t, err)
            } else {
                assert.NoError(t, err)
                assert.Equal(t, tt.expectedStatus, result.Status)
            }
            
            // Verify all mocks were called as expected
            mockRepo.AssertExpectations(t)
            mockNotif.AssertExpectations(t)
        })
    }
}

func TestDangerousOperationValidation(t *testing.T) {
    tests := []struct {
        name        string
        operation   dangerous_operation.Operation
        expectError bool
        errorType   string
    }{
        {
            name: "valid_bulk_operation",
            operation: dangerous_operation.Operation{
                Type:        dangerous_operation.TypeBulkUpdate,
                Target:      "users.email_verification_status",
                Parameters:  map[string]interface{}{"verified": true, "batch_size": 1000},
                RequestedBy: "admin@example.com",
                Reason:      "Migration to verified status",
            },
            expectError: false,
        },
        {
            name: "invalid_empty_reason",
            operation: dangerous_operation.Operation{
                Type:        dangerous_operation.TypeMassDeletion,
                Target:      "posts.spam_content",
                RequestedBy: "admin@example.com",
                Reason:      "",
            },
            expectError: true,
            errorType:   "validation.reason_required",
        },
        {
            name: "invalid_unauthorized_requester",
            operation: dangerous_operation.Operation{
                Type:        dangerous_operation.TypeSystemShutdown,
                Target:      "production.all_services",
                RequestedBy: "user@example.com",
                Reason:      "Testing shutdown procedure",
            },
            expectError: true,
            errorType:   "authorization.insufficient_privileges",
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            validator := dangerous_operation.NewValidator()
            
            err := validator.Validate(tt.operation)
            
            if tt.expectError {
                assert.Error(t, err)
                assert.Contains(t, err.Error(), tt.errorType)
            } else {
                assert.NoError(t, err)
            }
        })
    }
}
```

#### 14.2.2. Bulk Operation Transaction Testing

大量データ操作のトランザクション整合性テスト：

```go
package bulk_operation_test

import (
    "context"
    "database/sql"
    "testing"

    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
    
    "avion/internal/usecase/bulk_operation"
    "avion/internal/infrastructure/database"
)

func TestBulkOperationTransactionIntegrity(t *testing.T) {
    tests := []struct {
        name           string
        operation      bulk_operation.Config
        setupData      func(*sql.DB) error
        simulateError  bool
        errorAt        int
        expectedResult bulk_operation.Result
    }{
        {
            name: "successful_bulk_user_update",
            operation: bulk_operation.Config{
                Type:      "user_status_update",
                BatchSize: 100,
                Target:    "users",
                Conditions: map[string]interface{}{
                    "last_login_before": "2023-01-01",
                    "status":           "active",
                },
                Updates: map[string]interface{}{
                    "status":      "inactive",
                    "archived_at": "NOW()",
                },
                DryRun: false,
            },
            setupData: func(db *sql.DB) error {
                // Insert test users
                for i := 0; i < 250; i++ {
                    _, err := db.Exec(`
                        INSERT INTO users (email, status, last_login_at) 
                        VALUES ($1, 'active', '2022-12-01')
                    `, fmt.Sprintf("user%d@example.com", i))
                    if err != nil {
                        return err
                    }
                }
                return nil
            },
            simulateError: false,
            expectedResult: bulk_operation.Result{
                TotalProcessed: 250,
                Successful:     250,
                Failed:         0,
                Batches:        3,
                Status:         "completed",
            },
        },
        {
            name: "rollback_on_batch_failure",
            operation: bulk_operation.Config{
                Type:      "post_content_update",
                BatchSize: 50,
                Target:    "posts",
                Conditions: map[string]interface{}{
                    "content_type": "text",
                },
                Updates: map[string]interface{}{
                    "sanitized": true,
                },
                DryRun: false,
            },
            setupData: func(db *sql.DB) error {
                for i := 0; i < 150; i++ {
                    _, err := db.Exec(`
                        INSERT INTO posts (content, content_type, user_id) 
                        VALUES ($1, 'text', 1)
                    `, fmt.Sprintf("Post content %d", i))
                    if err != nil {
                        return err
                    }
                }
                return nil
            },
            simulateError: true,
            errorAt:       2, // Fail on second batch
            expectedResult: bulk_operation.Result{
                TotalProcessed: 50,  // Only first batch should remain
                Successful:     50,
                Failed:         100, // Remaining records
                Batches:        1,   // Only first batch succeeded
                Status:         "partial_failure",
            },
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Setup test database
            db := database.SetupTestDB(t)
            defer database.CleanupTestDB(t, db)
            
            // Setup test data
            require.NoError(t, tt.setupData(db))
            
            // Create service
            service := bulk_operation.NewService(db)
            
            // Execute operation
            ctx := context.Background()
            result, err := service.Execute(ctx, tt.operation)
            
            // Verify results
            if tt.simulateError {
                assert.Error(t, err)
            } else {
                assert.NoError(t, err)
            }
            
            assert.Equal(t, tt.expectedResult.TotalProcessed, result.TotalProcessed)
            assert.Equal(t, tt.expectedResult.Successful, result.Successful)
            assert.Equal(t, tt.expectedResult.Status, result.Status)
            
            // Verify database state consistency
            verifyDatabaseConsistency(t, db, tt.operation, result)
        })
    }
}

func verifyDatabaseConsistency(t *testing.T, db *sql.DB, operation bulk_operation.Config, result bulk_operation.Result) {
    // Check that successful records were actually updated
    var updatedCount int
    query := fmt.Sprintf("SELECT COUNT(*) FROM %s WHERE updated_at IS NOT NULL", operation.Target)
    err := db.QueryRow(query).Scan(&updatedCount)
    require.NoError(t, err)
    assert.Equal(t, result.Successful, updatedCount)
    
    // Check transaction log entries
    var logEntries int
    err = db.QueryRow("SELECT COUNT(*) FROM operation_audit_log WHERE operation_id = $1", result.OperationID).Scan(&logEntries)
    require.NoError(t, err)
    assert.Greater(t, logEntries, 0, "Audit log should contain operation records")
}
```

#### 14.2.3. Configuration Propagation Testing

設定変更の全サービス伝播テスト：

```go
package config_propagation_test

import (
    "context"
    "sync"
    "testing"
    "time"

    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/mock"
    
    "avion/internal/usecase/config_management"
    "avion/internal/domain/service_registry"
    "avion/tests/mocks"
)

func TestConfigurationPropagationAcrossServices(t *testing.T) {
    tests := []struct {
        name                string
        configChange        config_management.Change
        targetServices      []string
        setupMocks          func(*mocks.MockServiceRegistry, *mocks.MockConfigDistributor)
        expectedPropagation map[string]config_management.PropagationStatus
        expectError         bool
    }{
        {
            name: "rate_limit_config_update",
            configChange: config_management.Change{
                Key:       "rate_limit.requests_per_minute",
                Value:     "1000",
                Scope:     "global",
                Priority:  config_management.PriorityHigh,
                AppliedBy: "admin@example.com",
                Reason:    "Increase capacity for peak hours",
            },
            targetServices: []string{"avion-gateway", "avion-auth", "avion-user", "avion-drop"},
            setupMocks: func(registry *mocks.MockServiceRegistry, distributor *mocks.MockConfigDistributor) {
                // Mock service discovery
                services := []*service_registry.Service{
                    {Name: "avion-gateway", Status: "healthy", Endpoint: "gateway:9090"},
                    {Name: "avion-auth", Status: "healthy", Endpoint: "auth:9091"},
                    {Name: "avion-user", Status: "healthy", Endpoint: "user:9092"},
                    {Name: "avion-drop", Status: "healthy", Endpoint: "drop:9093"},
                }
                registry.EXPECT().GetActiveServices(mock.Anything).Return(services, nil)
                
                // Mock successful distribution
                for _, service := range services {
                    distributor.EXPECT().
                        PushConfig(mock.Anything, service.Endpoint, mock.Anything).
                        Return(nil)
                }
                
                // Mock status tracking
                distributor.EXPECT().GetPropagationStatus(mock.Anything, mock.Anything).Return(
                    map[string]config_management.PropagationStatus{
                        "avion-gateway": config_management.StatusSuccess,
                        "avion-auth":    config_management.StatusSuccess,
                        "avion-user":    config_management.StatusSuccess,
                        "avion-drop":    config_management.StatusSuccess,
                    }, nil)
            },
            expectedPropagation: map[string]config_management.PropagationStatus{
                "avion-gateway": config_management.StatusSuccess,
                "avion-auth":    config_management.StatusSuccess,
                "avion-user":    config_management.StatusSuccess,
                "avion-drop":    config_management.StatusSuccess,
            },
            expectError: false,
        },
        {
            name: "partial_propagation_failure",
            configChange: config_management.Change{
                Key:      "database.connection_pool_size",
                Value:    "50",
                Scope:    "data_services",
                Priority: config_management.PriorityMedium,
            },
            targetServices: []string{"avion-user", "avion-drop", "avion-timeline"},
            setupMocks: func(registry *mocks.MockServiceRegistry, distributor *mocks.MockConfigDistributor) {
                services := []*service_registry.Service{
                    {Name: "avion-user", Status: "healthy", Endpoint: "user:9092"},
                    {Name: "avion-drop", Status: "healthy", Endpoint: "drop:9093"},
                    {Name: "avion-timeline", Status: "degraded", Endpoint: "timeline:9094"},
                }
                registry.EXPECT().GetActiveServices(mock.Anything).Return(services, nil)
                
                // Successful for first two services
                distributor.EXPECT().PushConfig(mock.Anything, "user:9092", mock.Anything).Return(nil)
                distributor.EXPECT().PushConfig(mock.Anything, "drop:9093", mock.Anything).Return(nil)
                
                // Failure for timeline service
                distributor.EXPECT().
                    PushConfig(mock.Anything, "timeline:9094", mock.Anything).
                    Return(errors.New("service unavailable"))
                
                distributor.EXPECT().GetPropagationStatus(mock.Anything, mock.Anything).Return(
                    map[string]config_management.PropagationStatus{
                        "avion-user":     config_management.StatusSuccess,
                        "avion-drop":     config_management.StatusSuccess,
                        "avion-timeline": config_management.StatusFailed,
                    }, nil)
            },
            expectedPropagation: map[string]config_management.PropagationStatus{
                "avion-user":     config_management.StatusSuccess,
                "avion-drop":     config_management.StatusSuccess,
                "avion-timeline": config_management.StatusFailed,
            },
            expectError: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Setup mocks
            mockRegistry := new(mocks.MockServiceRegistry)
            mockDistributor := new(mocks.MockConfigDistributor)
            mockAudit := new(mocks.MockAuditLogger)
            
            tt.setupMocks(mockRegistry, mockDistributor)
            
            // Create service
            service := config_management.NewService(mockRegistry, mockDistributor, mockAudit)
            
            // Execute propagation
            ctx := context.Background()
            result, err := service.PropagateConfiguration(ctx, tt.configChange)
            
            // Verify results
            if tt.expectError {
                assert.Error(t, err)
            } else {
                assert.NoError(t, err)
            }
            
            // Check propagation status for each service
            for serviceName, expectedStatus := range tt.expectedPropagation {
                actualStatus, exists := result.ServiceStatus[serviceName]
                assert.True(t, exists, "Service %s should be in result", serviceName)
                assert.Equal(t, expectedStatus, actualStatus, "Status mismatch for service %s", serviceName)
            }
            
            // Verify mocks
            mockRegistry.AssertExpectations(t)
            mockDistributor.AssertExpectations(t)
        })
    }
}

func TestConfigurationRollbackMechanism(t *testing.T) {
    tests := []struct {
        name                string
        originalConfig      map[string]string
        failedChange        config_management.Change
        rollbackTimeout     time.Duration
        setupMocks          func(*mocks.MockConfigDistributor, *mocks.MockConfigBackup)
        expectedRollback    bool
        expectError         bool
    }{
        {
            name: "successful_automatic_rollback",
            originalConfig: map[string]string{
                "database.connection_timeout": "30s",
                "cache.ttl":                  "300s",
            },
            failedChange: config_management.Change{
                Key:   "database.connection_timeout",
                Value: "invalid_value",
                Scope: "global",
            },
            rollbackTimeout: 30 * time.Second,
            setupMocks: func(distributor *mocks.MockConfigDistributor, backup *mocks.MockConfigBackup) {
                // Mock backup retrieval
                backup.EXPECT().
                    GetLastValidConfig(mock.Anything, "database.connection_timeout").
                    Return("30s", nil)
                
                // Mock rollback distribution
                distributor.EXPECT().
                    PushConfig(mock.Anything, mock.Anything, mock.MatchedBy(func(config config_management.Change) bool {
                        return config.Key == "database.connection_timeout" && config.Value == "30s"
                    })).
                    Return(nil).
                    Times(4) // Assume 4 services
                
                // Mock verification
                distributor.EXPECT().
                    VerifyConfigApplication(mock.Anything, mock.Anything, mock.Anything).
                    Return(true, nil).
                    Times(4)
            },
            expectedRollback: true,
            expectError:      false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            mockDistributor := new(mocks.MockConfigDistributor)
            mockBackup := new(mocks.MockConfigBackup)
            
            tt.setupMocks(mockDistributor, mockBackup)
            
            rollback := config_management.NewRollbackService(mockDistributor, mockBackup)
            
            ctx := context.Background()
            result, err := rollback.ExecuteRollback(ctx, tt.failedChange, tt.rollbackTimeout)
            
            if tt.expectError {
                assert.Error(t, err)
            } else {
                assert.NoError(t, err)
                assert.Equal(t, tt.expectedRollback, result.Success)
            }
            
            mockDistributor.AssertExpectations(t)
            mockBackup.AssertExpectations(t)
        })
    }
}
```

#### 14.2.4. Metrics Collection and Aggregation Testing

Prometheusメトリクス収集・集約テスト：

```go
package metrics_test

import (
    "context"
    "testing"
    "time"

    "github.com/prometheus/client_golang/api"
    "github.com/prometheus/client_golang/api/prometheus/v1"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/mock"
    
    "avion/internal/usecase/metrics"
    "avion/internal/domain/sli"
    "avion/tests/mocks"
)

func TestMetricsCollectionAndAggregation(t *testing.T) {
    tests := []struct {
        name            string
        timeRange       metrics.TimeRange
        services        []string
        expectedQueries []string
        mockResponse    map[string]interface{}
        setupMocks      func(*mocks.MockPrometheusClient)
        expectedSLI     *sli.Metrics
        expectError     bool
    }{
        {
            name: "service_availability_collection",
            timeRange: metrics.TimeRange{
                Start: time.Now().Add(-1 * time.Hour),
                End:   time.Now(),
                Step:  time.Minute,
            },
            services: []string{"avion-gateway", "avion-auth", "avion-user"},
            expectedQueries: []string{
                `avg_over_time(up{job=~"avion-gateway|avion-auth|avion-user"}[1h])`,
                `rate(http_requests_total{job=~"avion-gateway|avion-auth|avion-user"}[5m])`,
                `rate(http_requests_total{job=~"avion-gateway|avion-auth|avion-user",code!~"2.."}[5m])`,
                `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job=~"avion-gateway|avion-auth|avion-user"}[5m]))`,
            },
            mockResponse: map[string]interface{}{
                "availability": 0.999,
                "error_rate":   0.001,
                "p95_latency":  0.150,
                "throughput":   1500.0,
            },
            setupMocks: func(client *mocks.MockPrometheusClient) {
                // Mock availability query
                client.EXPECT().
                    Query(mock.Anything, mock.MatchedBy(func(query string) bool {
                        return strings.Contains(query, "avg_over_time(up")
                    }), mock.Anything).
                    Return(mockPrometheusResult(0.999), nil, nil)
                
                // Mock error rate query
                client.EXPECT().
                    Query(mock.Anything, mock.MatchedBy(func(query string) bool {
                        return strings.Contains(query, "code!~\"2..\"")
                    }), mock.Anything).
                    Return(mockPrometheusResult(0.001), nil, nil)
                
                // Mock latency query
                client.EXPECT().
                    Query(mock.Anything, mock.MatchedBy(func(query string) bool {
                        return strings.Contains(query, "histogram_quantile(0.95")
                    }), mock.Anything).
                    Return(mockPrometheusResult(0.150), nil, nil)
                
                // Mock throughput query
                client.EXPECT().
                    Query(mock.Anything, mock.MatchedBy(func(query string) bool {
                        return strings.Contains(query, "rate(http_requests_total")
                    }), mock.Anything).
                    Return(mockPrometheusResult(1500.0), nil, nil)
            },
            expectedSLI: &sli.Metrics{
                Availability: 99.9,
                ErrorRate:    0.1,
                P95Latency:   150 * time.Millisecond,
                Throughput:   1500.0,
                Timestamp:    time.Now(),
            },
            expectError: false,
        },
        {
            name: "sli_slo_compliance_check",
            timeRange: metrics.TimeRange{
                Start: time.Now().Add(-24 * time.Hour),
                End:   time.Now(),
                Step:  time.Hour,
            },
            services: []string{"avion-gateway"},
            expectedQueries: []string{
                `avg_over_time(up{job="avion-gateway"}[24h])`,
                `1 - (increase(http_requests_total{job="avion-gateway",code!~"2.."}[24h]) / increase(http_requests_total{job="avion-gateway"}[24h]))`,
            },
            mockResponse: map[string]interface{}{
                "availability": 0.995,  // Below SLO of 99.9%
                "error_rate":   0.005,  // Above SLO of 0.1%
            },
            setupMocks: func(client *mocks.MockPrometheusClient) {
                client.EXPECT().
                    Query(mock.Anything, mock.Anything, mock.Anything).
                    Return(mockPrometheusResult(0.995), nil, nil).
                    Times(2)
            },
            expectedSLI: &sli.Metrics{
                Availability:   99.5,
                ErrorRate:      0.5,
                SLOCompliance:  false,
                SLOViolations:  []string{"availability", "error_rate"},
            },
            expectError: false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            mockClient := new(mocks.MockPrometheusClient)
            tt.setupMocks(mockClient)
            
            collector := metrics.NewCollector(mockClient)
            
            ctx := context.Background()
            result, err := collector.CollectSLIMetrics(ctx, metrics.CollectionRequest{
                Services:  tt.services,
                TimeRange: tt.timeRange,
                Metrics:   []string{"availability", "error_rate", "latency", "throughput"},
            })
            
            if tt.expectError {
                assert.Error(t, err)
            } else {
                assert.NoError(t, err)
                assert.InDelta(t, tt.expectedSLI.Availability, result.Availability, 0.1)
                assert.InDelta(t, tt.expectedSLI.ErrorRate, result.ErrorRate, 0.01)
            }
            
            mockClient.AssertExpectations(t)
        })
    }
}

func TestAlertingRulesEvaluation(t *testing.T) {
    tests := []struct {
        name           string
        alertRule      metrics.AlertRule
        currentMetrics map[string]float64
        expectedAlert  bool
        alertSeverity  string
    }{
        {
            name: "critical_availability_alert",
            alertRule: metrics.AlertRule{
                Name:        "ServiceAvailabilityLow",
                Query:       `avg_over_time(up{job="avion-gateway"}[5m]) < 0.99`,
                Threshold:   0.99,
                Duration:    5 * time.Minute,
                Severity:    "critical",
                Description: "Gateway availability is below 99%",
            },
            currentMetrics: map[string]float64{
                "availability": 0.985,
            },
            expectedAlert: true,
            alertSeverity: "critical",
        },
        {
            name: "error_rate_warning",
            alertRule: metrics.AlertRule{
                Name:        "HighErrorRate",
                Query:       `rate(http_requests_total{code!~"2.."}[5m]) > 0.01`,
                Threshold:   0.01,
                Duration:    2 * time.Minute,
                Severity:    "warning",
                Description: "Error rate is above 1%",
            },
            currentMetrics: map[string]float64{
                "error_rate": 0.015,
            },
            expectedAlert: true,
            alertSeverity: "warning",
        },
        {
            name: "no_alert_within_threshold",
            alertRule: metrics.AlertRule{
                Name:        "ResponseTimeHigh",
                Query:       `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 0.5`,
                Threshold:   0.5,
                Duration:    3 * time.Minute,
                Severity:    "warning",
            },
            currentMetrics: map[string]float64{
                "p95_latency": 0.3,
            },
            expectedAlert: false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            evaluator := metrics.NewAlertEvaluator()
            
            ctx := context.Background()
            alertResult := evaluator.EvaluateRule(ctx, tt.alertRule, tt.currentMetrics)
            
            assert.Equal(t, tt.expectedAlert, alertResult.ShouldAlert)
            if tt.expectedAlert {
                assert.Equal(t, tt.alertSeverity, alertResult.Severity)
                assert.Contains(t, alertResult.Description, tt.alertRule.Description)
            }
        })
    }
}

func mockPrometheusResult(value float64) model.Value {
    return model.Vector{
        &model.Sample{
            Value:     model.SampleValue(value),
            Timestamp: model.Time(time.Now().Unix()),
        },
    }
}
```

#### 14.2.5. Backup and Restore Operations Testing

バックアップ・リストア機能の包括的テスト：

```go
package backup_restore_test

import (
    "context"
    "io"
    "os"
    "testing"
    "time"

    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
    
    "avion/internal/usecase/backup"
    "avion/internal/domain/storage"
    "avion/tests/mocks"
)

func TestBackupOperations(t *testing.T) {
    tests := []struct {
        name            string
        backupConfig    backup.Config
        dataSize        int64
        setupMocks      func(*mocks.MockStorageProvider, *mocks.MockEncryption)
        expectedResult  backup.Result
        expectError     bool
    }{
        {
            name: "full_database_backup_with_encryption",
            backupConfig: backup.Config{
                Type:        backup.TypeFull,
                Source:      "postgresql://primary",
                Destination: "s3://backup-bucket/avion/",
                Encryption:  true,
                Compression: true,
                Retention:   30 * 24 * time.Hour,
                Incremental: false,
            },
            dataSize: 5 * 1024 * 1024 * 1024, // 5GB
            setupMocks: func(storage *mocks.MockStorageProvider, encryption *mocks.MockEncryption) {
                // Mock successful backup creation
                storage.EXPECT().
                    CreateBackup(mock.Anything, mock.MatchedBy(func(req *storage.BackupRequest) bool {
                        return req.Source == "postgresql://primary"
                    })).
                    Return(&storage.BackupMetadata{
                        ID:           "backup-001",
                        Size:         5 * 1024 * 1024 * 1024,
                        Checksum:     "sha256:abc123...",
                        CreatedAt:    time.Now(),
                        Encrypted:    true,
                        Compressed:   true,
                    }, nil)
                
                // Mock encryption process
                encryption.EXPECT().
                    EncryptStream(mock.Anything, mock.Anything).
                    Return(nil)
                
                // Mock upload to storage
                storage.EXPECT().
                    Upload(mock.Anything, mock.Anything, mock.Anything).
                    Return(nil)
                
                // Mock verification
                storage.EXPECT().
                    VerifyBackup(mock.Anything, "backup-001").
                    Return(true, nil)
            },
            expectedResult: backup.Result{
                BackupID:    "backup-001",
                Size:        5 * 1024 * 1024 * 1024,
                Duration:    time.Minute * 15,
                Status:      backup.StatusCompleted,
                Encrypted:   true,
                Compressed:  true,
                Verified:    true,
            },
            expectError: false,
        },
        {
            name: "incremental_backup_with_retention_cleanup",
            backupConfig: backup.Config{
                Type:        backup.TypeIncremental,
                Source:      "postgresql://primary",
                Destination: "s3://backup-bucket/avion/",
                Encryption:  true,
                Retention:   7 * 24 * time.Hour,
                Incremental: true,
                BaseBackup:  "backup-000",
            },
            dataSize: 100 * 1024 * 1024, // 100MB incremental
            setupMocks: func(storage *mocks.MockStorageProvider, encryption *mocks.MockEncryption) {
                // Mock incremental backup
                storage.EXPECT().
                    CreateIncrementalBackup(mock.Anything, mock.MatchedBy(func(req *storage.IncrementalBackupRequest) bool {
                        return req.BaseBackupID == "backup-000"
                    })).
                    Return(&storage.BackupMetadata{
                        ID:           "backup-inc-001",
                        Size:         100 * 1024 * 1024,
                        Type:         storage.TypeIncremental,
                        BaseBackupID: "backup-000",
                        CreatedAt:    time.Now(),
                    }, nil)
                
                encryption.EXPECT().EncryptStream(mock.Anything, mock.Anything).Return(nil)
                storage.EXPECT().Upload(mock.Anything, mock.Anything, mock.Anything).Return(nil)
                storage.EXPECT().VerifyBackup(mock.Anything, "backup-inc-001").Return(true, nil)
                
                // Mock retention cleanup
                oldBackups := []*storage.BackupMetadata{
                    {ID: "backup-old-001", CreatedAt: time.Now().Add(-10 * 24 * time.Hour)},
                    {ID: "backup-old-002", CreatedAt: time.Now().Add(-8 * 24 * time.Hour)},
                }
                storage.EXPECT().
                    ListBackupsOlderThan(mock.Anything, mock.Anything).
                    Return(oldBackups, nil)
                storage.EXPECT().
                    DeleteBackup(mock.Anything, "backup-old-001").
                    Return(nil)
                storage.EXPECT().
                    DeleteBackup(mock.Anything, "backup-old-002").
                    Return(nil)
            },
            expectedResult: backup.Result{
                BackupID:      "backup-inc-001",
                Size:          100 * 1024 * 1024,
                Type:          backup.TypeIncremental,
                Status:        backup.StatusCompleted,
                CleanedCount:  2,
            },
            expectError: false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            mockStorage := new(mocks.MockStorageProvider)
            mockEncryption := new(mocks.MockEncryption)
            mockAudit := new(mocks.MockAuditLogger)
            
            tt.setupMocks(mockStorage, mockEncryption)
            
            service := backup.NewService(mockStorage, mockEncryption, mockAudit)
            
            ctx := context.Background()
            result, err := service.CreateBackup(ctx, tt.backupConfig)
            
            if tt.expectError {
                assert.Error(t, err)
            } else {
                assert.NoError(t, err)
                assert.Equal(t, tt.expectedResult.BackupID, result.BackupID)
                assert.Equal(t, tt.expectedResult.Status, result.Status)
                assert.Equal(t, tt.expectedResult.Size, result.Size)
            }
            
            mockStorage.AssertExpectations(t)
            mockEncryption.AssertExpectations(t)
        })
    }
}

func TestRestoreOperations(t *testing.T) {
    tests := []struct {
        name           string
        restoreConfig  backup.RestoreConfig
        setupMocks     func(*mocks.MockStorageProvider, *mocks.MockEncryption, *mocks.MockDatabase)
        expectedResult backup.RestoreResult
        expectError    bool
    }{
        {
            name: "point_in_time_recovery",
            restoreConfig: backup.RestoreConfig{
                BackupID:        "backup-001",
                TargetTime:      time.Now().Add(-2 * time.Hour),
                Destination:     "postgresql://recovery",
                RestoreType:     backup.RestoreTypePointInTime,
                VerifyIntegrity: true,
            },
            setupMocks: func(storage *mocks.MockStorageProvider, encryption *mocks.MockEncryption, db *mocks.MockDatabase) {
                // Mock backup retrieval
                backupMeta := &storage.BackupMetadata{
                    ID:        "backup-001",
                    Size:      1024 * 1024 * 1024,
                    CreatedAt: time.Now().Add(-1 * time.Hour),
                    Encrypted: true,
                }
                storage.EXPECT().
                    GetBackupMetadata(mock.Anything, "backup-001").
                    Return(backupMeta, nil)
                
                // Mock WAL files for point-in-time recovery
                walFiles := []string{"000000010000000000000001", "000000010000000000000002"}
                storage.EXPECT().
                    GetWALFiles(mock.Anything, mock.Anything, mock.Anything).
                    Return(walFiles, nil)
                
                // Mock download and decryption
                storage.EXPECT().
                    Download(mock.Anything, "backup-001").
                    Return(mockBackupStream(), nil)
                encryption.EXPECT().
                    DecryptStream(mock.Anything, mock.Anything).
                    Return(nil)
                
                // Mock database restoration
                db.EXPECT().
                    RestoreFromBackup(mock.Anything, mock.MatchedBy(func(req *backup.RestoreRequest) bool {
                        return req.BackupID == "backup-001"
                    })).
                    Return(nil)
                
                // Mock WAL replay for point-in-time recovery
                db.EXPECT().
                    ReplayWALToTime(mock.Anything, mock.Anything).
                    Return(nil)
                
                // Mock integrity verification
                db.EXPECT().
                    VerifyIntegrity(mock.Anything).
                    Return(&backup.IntegrityResult{
                        Valid:  true,
                        Issues: []string{},
                    }, nil)
            },
            expectedResult: backup.RestoreResult{
                RestoreID:    "restore-001",
                BackupID:     "backup-001",
                Status:       backup.RestoreStatusCompleted,
                Duration:     time.Minute * 10,
                RecoveredTo:  time.Now().Add(-2 * time.Hour),
                Verified:     true,
            },
            expectError: false,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            mockStorage := new(mocks.MockStorageProvider)
            mockEncryption := new(mocks.MockEncryption)
            mockDB := new(mocks.MockDatabase)
            mockAudit := new(mocks.MockAuditLogger)
            
            tt.setupMocks(mockStorage, mockEncryption, mockDB)
            
            service := backup.NewRestoreService(mockStorage, mockEncryption, mockDB, mockAudit)
            
            ctx := context.Background()
            result, err := service.RestoreFromBackup(ctx, tt.restoreConfig)
            
            if tt.expectError {
                assert.Error(t, err)
            } else {
                assert.NoError(t, err)
                assert.Equal(t, tt.expectedResult.Status, result.Status)
                assert.Equal(t, tt.expectedResult.BackupID, result.BackupID)
                assert.Equal(t, tt.expectedResult.Verified, result.Verified)
            }
            
            mockStorage.AssertExpectations(t)
            mockEncryption.AssertExpectations(t)
            mockDB.AssertExpectations(t)
        })
    }
}

func mockBackupStream() io.ReadCloser {
    // Create a mock backup stream with dummy data
    return io.NopCloser(strings.NewReader("mock backup data"))
}
```

### 14.3. Integration Testing Strategy

#### 14.3.1. End-to-End Workflow Testing

システム管理のエンドツーエンドワークフローテスト：

- **災害復旧シナリオ**: データセンター障害からの完全復旧
- **セキュリティインシデント対応**: 侵害検知から復旧まで
- **大規模データ移行**: サービス継続性を保った移行作業
- **コンプライアンス監査**: 監査証跡の完全性検証

#### 14.3.2. Performance and Load Testing

- **大量ユーザー操作**: 同時管理者操作の負荷テスト
- **バックアップ性能**: 大容量データのバックアップ時間測定
- **メトリクス収集負荷**: 高頻度メトリクス収集の影響評価
- **設定変更伝播**: 全サービスへの同時設定反映性能

#### 14.3.3. Security and Compliance Testing

- **監査ログ改ざん防止**: ログの暗号化・署名検証
- **アクセス制御**: 権限昇格攻撃の検知・防止
- **データ保護**: GDPR等のデータ削除要求への対応
- **秘密情報保護**: 設定情報の暗号化・マスキング

### 14.4. Test Coverage Requirements

- **ユニットテスト**: 95%以上のコードカバレッジ
- **統合テスト**: 全クリティカルパスの実行確認
- **エンドツーエンドテスト**: 主要ワークフローの完全検証
- **パフォーマンステスト**: SLA要件の継続的検証
- **セキュリティテスト**: 脆弱性・攻撃シナリオの定期検証

### 14.5. Test Environment Management

#### 14.5.1. Test Data Management

- **匿名化された本番データ**: リアルなテストシナリオの実現
- **合成データ生成**: 大規模テスト用のデータセット作成
- **データ世代管理**: テスト間でのデータ状態管理
- **秘密情報除去**: 本番データからの機密情報完全削除

#### 14.5.2. Environment Isolation

- **サンドボックス環境**: 危険操作の安全な実行環境
- **マルチテナント分離**: テスト間の相互影響防止
- **リソース制限**: テスト実行時のリソース使用制御
- **クリーンアップ自動化**: テスト後の環境初期化

この包括的なテスト戦略により、avion-system-adminの信頼性・安全性・性能を継続的に保証し、企業レベルの運用要件に対応します。