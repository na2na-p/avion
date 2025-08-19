# Design Doc: avion-moderation

**Author:** Claude Code
**Last Updated:** 2025/08/07

## 1. Summary (これは何？)

- **一言で:** Avionにおけるコンテンツモデレーション機能（通報処理、フィルタリング、モデレーションアクション、異議申し立て）を提供するマイクロサービスを実装します。
- **目的:** プラットフォームの健全性維持、有害コンテンツの検出・対処、コミュニティガイドラインの強制、公平かつ透明なモデレーションプロセスを提供し、監査証跡とコンプライアンス要求に対応します。

## テスト戦略

このサービスでは、[共通テスト戦略](../common/testing-strategy.md)に従ってテストを実装します。

### テスト方針
- **TDD必須**: インターフェース定義 → テスト作成 → 実装の順序を厳守
- **カバレッジ目標**: ユニットテスト85%以上、クリティカルパス95%以上
- **テーブル駆動テスト**: 全テストで必須
- **モック生成**: `go.uber.org/mock/gomock`使用

### E2Eテスト

このサービスのE2Eテストは、[共通E2Eテスト戦略](../common/e2e-testing-strategy.md)に従って実装します。

#### 主要なE2Eテストシナリオ
- Drop投稿から自動モデレーション実行までの完全フロー
- AIベースコンテンツ分析と人間モデレーターでのレビュー連携
- 通報機能から調査・対応完了までのワークフロー
- 違反コンテンツ検出と自動削除・警告機能の確認
- ユーザー制裁（警告、一時停止、永久停止）の実行と解除
- インスタンスブロック/許可機能の設定と効果確認
- モデレーションログの記録と管理機能
- 大量コンテンツでの自動モデレーション性能確認

詳細は[共通E2Eテスト戦略ドキュメント](../common/e2e-testing-strategy.md)を参照してください。

詳細は[共通テスト戦略ドキュメント](../common/testing-strategy.md)を参照してください。

## エラーハンドリング戦略

このサービスでは、[共通エラー標準化ガイドライン](../common/errors/error-standards.md)に従ってエラーハンドリングを実装します。

### エラーコード体系
- サービスプレフィックス: `MOD` (Moderation)
- 命名規則: `[MOD]_[LAYER]_[ERROR_TYPE]`
- 例: `MOD_DOMAIN_REPORT_NOT_FOUND`, `MOD_USECASE_UNAUTHORIZED`

### 主要なエラーコード

| エラーコード | gRPCステータス | 説明 |
|------------|--------------|------|
| MOD_DOMAIN_REPORT_NOT_FOUND | codes.NotFound | 通報が見つからない |
| MOD_DOMAIN_REPORT_DUPLICATE | codes.AlreadyExists | 24時間以内に重複通報 |
| MOD_DOMAIN_ACTION_INVALID | codes.InvalidArgument | 無効なモデレーションアクション |
| MOD_DOMAIN_APPEAL_EXPIRED | codes.FailedPrecondition | 異議申し立て期限切れ |
| MOD_DOMAIN_APPEAL_EXISTS | codes.AlreadyExists | 既に異議申し立て済み |
| MOD_USECASE_UNAUTHORIZED | codes.Unauthenticated | 認証エラー |
| MOD_USECASE_FORBIDDEN | codes.PermissionDenied | モデレーター権限不足 |
| MOD_INFRA_ML_SERVICE_ERROR | codes.Unavailable | ML分類サービスエラー |
| MOD_INFRA_DATABASE_ERROR | codes.Internal | データベースエラー |

詳細は[共通エラー標準化ガイドライン](../common/errors/error-standards.md)を参照してください。

## 構造化ログ戦略

このサービスでは、[共通Observabilityパッケージ設計](../common/observability/observability-package-design.md)に従って構造化ログを実装します。

### ログレベル定義
- `DEBUG`: 開発時の詳細情報（フィルタリング条件、MLスコア等）
- `INFO`: 正常な処理フロー（通報受付、モデレーション実行等）
- `WARN`: 予期された異常（重複通報、期限切れ等）
- `ERROR`: 予期しないエラー（ML API失敗、DB接続失敗等）
- `CRITICAL`: システム停止レベルの重大エラー

### 標準フィールド
```json
{
  "timestamp": "2025-08-15T10:00:00Z",
  "level": "INFO",
  "service": "avion-moderation",
  "trace_id": "123e4567-e89b-12d3-a456-426614174000",
  "span_id": "7891011",
  "moderator_id": "mod_123",
  "report_id": "report_456",
  "action_type": "content_removal",
  "layer": "usecase",
  "method": "ExecuteModerationAction",
  "duration_ms": 120,
  "message": "Moderation action executed successfully"
}
```

### 監査ログ
モデレーション操作は全て監査ログとして記録され、改竄防止のためハッシュチェーンで保護されます。

詳細は[共通Observabilityパッケージ設計](../common/observability/observability-package-design.md)を参照してください。

## 3. 技術スタック

このサービスでは、[共通Goバックエンド技術スタックガイドライン](../common/architecture/go-backend-framework.md)に従った実装を行います。

### 主要技術
- **HTTPルーティング:** Chi v5
- **RPC:** ConnectRPC
- **ミドルウェア:** 標準net/httpベースの共通ミドルウェア

詳細な実装パターンおよびライブラリの使用方法については、[ガイドライン](../common/architecture/go-backend-framework.md)を参照してください。

## 4. Background & Links (背景と関連リンク)

- SNSプラットフォームの健全性維持はユーザー信頼とサービス持続性の基盤。
- モデレーション機能をシステム管理から分離し、専門サービス化することで、変更容易性とスケーラビリティを確保。
- 機械学習を活用した自動モデレーションにより、モデレーターの負担軽減と効率化を実現。
- [PRD: avion-moderation](./prd.md)
- [Avion アーキテクチャ概要](../common/architecture.md)
- [avion-drop Design Doc](../avion-drop/designdoc.md)
- [avion-system-admin Design Doc](../avion-system-admin/designdoc.md)

---

## 5. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

- 通報の受付、処理、追跡を行うgRPC APIの実装
- コンテンツフィルタリングエンジンの実装（NGワード、正規表現、ML分類器）
- モデレーションアクションのgRPC API実装（警告、削除、凍結等）
- 異議申し立てプロセスの実装
- インスタンスポリシー管理（ブロック、サイレンス等）
- モデレーションデータのPostgreSQLへの永続化
- フィルタールールとNGワードのRedisキャッシュ
- モデレーションイベントの発行（Redis Pub/Sub）
- モデレーターダッシュボードとキュー管理
- Go言語で実装し、Kubernetes上でのステートレス運用
- OpenTelemetryによるトレーシング・メトリクス・ロギング対応

### Non-Goals (やらないこと)

- **システム設定管理:** `avion-system-admin` が担当
- **アナウンス配信:** `avion-system-admin` が担当
- **バックアップ処理:** `avion-system-admin` が担当
- **レート制限設定:** `avion-system-admin` が担当
- **ユーザー認証:** `avion-auth` が担当
- **個人レベルのブロック/ミュート:** `avion-user` が担当
- **メディアファイルの直接管理:** `avion-media` が担当
- **コンテンツの作成・編集:** 投稿内容の修正は行わない（削除のみ）
- **直接的な通知配信:** `avion-notification` が担当

## 6. Architecture (どうやって作る？)

### 5.1. レイヤードアーキテクチャ (DDD準拠)

Avion-moderationサービスは、Domain-Driven Design (DDD) の戦術的パターンに従った4層アーキテクチャを採用し、モデレーション固有のビジネスロジックとコンプライアンス要求を満たします。

#### Domain Layer (ドメイン層)

**Core Business Logic and Invariants**

**Aggregates:**
  - **Report**: 通報の受付と処理状態を管理
    - *不変条件*: 通報者と対象の組み合わせで24時間以内重複不可、ステータス遷移は定義されたパスのみ許可
    - *ビジネスルール*: 優先度自動計算、通報者信頼度による重み付け、SLA期限管理
  - **ModerationCase**: 複数関連通報の統合管理と一貫した判定を保証
    - *不変条件*: 同一対象への関連通報は単一ケースに統合、ケース判定の一貫性保証
    - *ビジネスルール*: 関連通報の自動検出と統合、エスカレーション判定、統合優先度計算
  - **ModerationAction**: モデレーション操作と履歴を管理
    - *不変条件*: 実行済みアクションは変更不可、期限付きアクションは期限必須、監査証跡完全性
    - *ビジネスルール*: 段階的制裁エスカレーション、アクション妥当性検証、権限チェック、取り消し可能性判定
  - **ContentFilter**: フィルタリングルールを管理
    - *不変条件*: フィルター優先度一意性、有効なパターン/条件必須、システムフィルター削除不可
    - *ビジネスルール*: 並列フィルター実行、スコア重み付け集計、閾値判定、効果測定
  - **Appeal**: 異議申し立てを管理
    - *不変条件*: 1アクションあたり1回のみ、申し立て期限7日、決定後状態変更不可
    - *ビジネスルール*: 独立した審査員選定、証拠評価、透明な判定プロセス
  - **InstancePolicy**: インスタンスポリシーを管理
    - *不変条件*: ドメイン名一意性、自インスタンス対象外、有効期限整合性
    - *ビジネスルール*: レピュテーション自動評価、段階的制裁適用、フェデレーション制御
  - **CommunityVote**: コミュニティモデレーション投票を管理
    - *不変条件*: 同一ユーザーは1つの対象に1票のみ、投票期限後の変更不可
    - *ビジネスルール*: 信頼レベルに応じた投票重み付け、最小投票数閾値、自動判定実行
  - **TrustLevel**: ユーザー信頼レベルと権限を管理
    - *不変条件*: レベルは0-3の範囲、降格は段階的のみ
    - *ビジネスルール*: 活動に応じた自動昇格、違反による降格、権限マッピング
  - **AuditTrail**: 監査証跡を管理
    - *不変条件*: ハッシュチェーン完全性、改竄検知、時系列順序保証
    - *ビジネスルール*: 法的要求対応、証拠保全、データ保持期間管理
- **Entities:**
  - ReportEvidence: 通報証拠
  - ModerationNote: モデレーターメモ
  - FilterCondition: フィルター条件
  - AppealEvidence: 異議申し立て証拠
  - InstanceIncident: インスタンスインシデント
- **Value Objects:**
  - ReportID, ActionID, FilterID, AppealID, ModeratorID
  - ReportReason, ReportStatus, ReportPriority
  - ActionType, ActionDuration, ActionSeverity
  - FilterType, FilterAction, ConfidenceScore
  - PolicyType, ReputationScore, InstanceDomain
- **Domain Services:**
  - ViolationDetectionService: 違反検知ロジック
  - PriorityCalculationService: 優先度計算
  - EscalationService: エスカレーション判断
  - FilterEngine: フィルタリングエンジン
  - MLClassifier: 機械学習分類器
- **Repository Interfaces:**
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../tests/mocks/report_repository_mock.go -package=mocks
  type ReportRepository interface {
      Create(ctx context.Context, report *Report) error
      FindByID(ctx context.Context, id ReportID) (*Report, error)
      FindByStatus(ctx context.Context, status ReportStatus, limit int) ([]*Report, error)
      Update(ctx context.Context, report *Report) error
      Delete(ctx context.Context, id ReportID) error
  }
  ```


#### Use Case Layer (ユースケース層)
- **Command Use Cases:**
  - CreateReportCommandUseCase: 通報作成
  - AssignModeratorCommandUseCase: モデレーター割り当て
  - EscalateCaseCommandUseCase: ケースエスカレーション
  - MergeCasesCommandUseCase: ケース統合
  - ExecuteModerationActionCommandUseCase: モデレーションアクション実行
  - RevertModerationActionCommandUseCase: アクション取り消し
  - FilterContentCommandUseCase: コンテンツフィルタリング
  - UpdateFilterCommandUseCase: フィルター更新
  - CreateAppealCommandUseCase: 異議申し立て作成
  - ReviewAppealCommandUseCase: 異議申し立てレビュー
  - SetInstancePolicyCommandUseCase: インスタンスポリシー設定
  - UpdateTrustLevelCommandUseCase: 信頼レベル更新
  - ProcessCommunityVoteCommandUseCase: コミュニティ投票処理
  - UpdateAIConsentCommandUseCase: AI同意設定更新
  - TrainMLModelCommandUseCase: MLモデルの学習・更新
  - ConfigureAutoModerationRulesCommandUseCase: 自動モデレーションルール設定
  - TestModerationRulesCommandUseCase: モデレーションルールのテスト実行
  - SetModeratorPermissionsCommandUseCase: モデレーター権限設定（権限付与・剥奪はavion-authが担当）
  - ExportModerationAuditLogCommandUseCase: モデレーション監査ログエクスポート
  - GenerateComplianceReportCommandUseCase: モデレーションコンプライアンスレポート生成
  - AnalyzeViolationPatternsCommandUseCase: 違反パターン分析
  - CreateViolationPatternCommandUseCase: 違反パターン登録
  - SubmitToExternalReviewCommandUseCase: 外部レビューサービス送信
  - ImportExternalBlocklistCommandUseCase: 外部ブロックリストインポート
  - PrepareFederationModerationDataCommandUseCase: フェデレーション共有データ準備（同期プロトコルはavion-activitypubが担当）
- **Query Use Cases:**
  - GetReportsQueryUseCase: 通報一覧取得
  - GetReportDetailsQueryUseCase: 通報詳細取得
  - GetModerationQueueQueryUseCase: モデレーションキュー取得
  - GetModerationHistoryQueryUseCase: モデレーション履歴取得
  - GetAppealsQueryUseCase: 異議申し立て一覧取得
  - GetModerationStatsQueryUseCase: モデレーション統計取得
  - GetAutoModerationEffectivenessQueryUseCase: 自動モデレーション効果測定
  - GetModeratorWorkloadQueryUseCase: モデレーター作業負荷取得
  - GetModeratorPerformanceQueryUseCase: モデレーターパフォーマンス評価
  - GetRegulatoryComplianceStatusQueryUseCase: 規制準拠状況確認
  - GetTrendingViolationsQueryUseCase: トレンド違反取得
  - GetRecidivistAnalysisQueryUseCase: 再犯者分析
- **Query Service Interfaces:**
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../tests/mocks/report_query_service_mock.go -package=mocks
  type ReportQueryService interface {
      GetPendingReports(ctx context.Context, limit int) ([]*ReportDTO, error)
      GetReportsByTarget(ctx context.Context, targetType string, targetID string) ([]*ReportDTO, error)
      GetReporterHistory(ctx context.Context, userID UserID) (*ReporterHistoryDTO, error)
  }
  ```
- **External Service Interfaces:**
  ```go
  //go:generate mockgen -source=$GOFILE -destination=../../tests/mocks/ml_service_mock.go -package=mocks
  type MLClassificationService interface {
      ClassifyText(ctx context.Context, text string) (*Classification, error)
      ClassifyImage(ctx context.Context, imageURL string) (*ImageClassification, error)
  }
  ```

#### CQRS Implementation Details (CQRS実装詳細)

**Command/Query Separation Pattern**: avion-moderationは厳格なCQRS分離を実装し、すべての状態変更操作（Command）と読み取り操作（Query）を明確に分離します。

##### Command Handlers (コマンドハンドラー)

**Command Handler Interface:**
```go
//go:generate mockgen -source=$GOFILE -destination=../../tests/mocks/command_handler_mock.go -package=mocks
type CommandHandler[TCommand any] interface {
    Handle(ctx context.Context, cmd TCommand) error
}

type CommandHandlerWithResult[TCommand any, TResult any] interface {
    Handle(ctx context.Context, cmd TCommand) (TResult, error)
}
```

**Primary Command Handlers:**

```go
// CreateReportCommandHandler - 通報作成コマンド処理
type CreateReportCommandHandler struct {
    reportRepo           domain.ReportRepository
    violationDetector    service.ViolationDetectionService
    priorityCalculator   service.PriorityCalculationService
    eventPublisher       infrastructure.ReportEventPublisher
    duplicateChecker     service.DuplicateReportChecker
}

type CreateReportCommand struct {
    ReporterID   domain.UserID
    TargetType   domain.ContentType
    TargetID     domain.ContentID
    Reason       domain.ViolationReason
    Description  string
    Evidence     []domain.ReportEvidence
}

func (h *CreateReportCommandHandler) Handle(ctx context.Context, cmd CreateReportCommand) (domain.ReportID, error) {
    // 1. ドメイン検証と重複チェック
    isDuplicate, existingReportID, err := h.duplicateChecker.CheckDuplicate(ctx, cmd.ReporterID, cmd.TargetID, cmd.Reason)
    if err != nil {
        return domain.ReportID{}, fmt.Errorf("duplicate check failed: %w", err)
    }
    
    if isDuplicate {
        return existingReportID, domain.ErrDuplicateReport
    }

    // 2. 通報Aggregateの生成
    reportID := domain.NewReportID()
    reportAggregate := domain.NewReport(
        reportID,
        cmd.ReporterID,
        cmd.TargetType,
        cmd.TargetID,
        cmd.Reason,
        cmd.Description,
        cmd.Evidence,
    )

    // 3. 自動違反検出
    violationLevel, detectionResult, err := h.violationDetector.DetectViolation(ctx, cmd.TargetID, cmd.Reason)
    if err != nil {
        return domain.ReportID{}, fmt.Errorf("violation detection failed: %w", err)
    }

    // 4. 優先度計算
    priority, err := h.priorityCalculator.CalculatePriority(ctx, cmd.ReporterID, violationLevel, detectionResult)
    if err != nil {
        return domain.ReportID{}, fmt.Errorf("priority calculation failed: %w", err)
    }

    reportAggregate.SetPriority(priority)
    reportAggregate.SetAutoDetectionResult(detectionResult)

    // 5. 永続化
    err = h.reportRepo.Save(ctx, reportAggregate)
    if err != nil {
        return domain.ReportID{}, fmt.Errorf("report save failed: %w", err)
    }

    // 6. ドメインイベント発行
    event := domain.NewReportCreatedEvent(reportID, cmd.ReporterID, cmd.TargetID, priority)
    err = h.eventPublisher.PublishReportCreated(ctx, event)
    if err != nil {
        // イベント発行失敗は警告レベル（既に永続化済みのため）
        log.Warn("Failed to publish report created event", zap.Error(err), zap.String("report_id", string(reportID)))
    }

    return reportID, nil
}
```

```go
// ExecuteModerationActionCommandHandler - モデレーションアクション実行
type ExecuteModerationActionCommandHandler struct {
    actionRepo       domain.ModerationActionRepository
    reportRepo       domain.ReportRepository
    policyEngine     service.PolicyEnforcementService
    auditLogger      service.AuditLogService
    eventPublisher   infrastructure.ModerationEventPublisher
}

type ExecuteModerationActionCommand struct {
    ModeratorID      domain.UserID
    ReportID         domain.ReportID
    ActionType       domain.ModerationActionType
    Reason           string
    Duration         *time.Duration // for temporary sanctions
    AdditionalData   map[string]interface{}
}

func (h *ExecuteModerationActionCommandHandler) Handle(ctx context.Context, cmd ExecuteModerationActionCommand) (domain.ModerationActionID, error) {
    // 1. 通報の存在確認と権限チェック
    report, err := h.reportRepo.FindByID(ctx, cmd.ReportID)
    if err != nil {
        return domain.ModerationActionID{}, fmt.Errorf("report not found: %w", err)
    }

    if !report.CanExecuteAction(cmd.ActionType) {
        return domain.ModerationActionID{}, domain.ErrInvalidActionForReportState
    }

    // 2. ポリシー検証
    isAllowed, policyViolation, err := h.policyEngine.ValidateAction(ctx, cmd.ModeratorID, cmd.ActionType, report)
    if err != nil {
        return domain.ModerationActionID{}, fmt.Errorf("policy validation failed: %w", err)
    }

    if !isAllowed {
        return domain.ModerationActionID{}, domain.NewPolicyViolationError(policyViolation)
    }

    // 3. ModerationActionAggregate生成
    actionID := domain.NewModerationActionID()
    action := domain.NewModerationAction(
        actionID,
        cmd.ReportID,
        cmd.ModeratorID,
        cmd.ActionType,
        cmd.Reason,
        cmd.Duration,
    )

    // 4. アクション実行前の状態保存（ロールバック用）
    previousState := report.CreateSnapshot()
    
    // 5. アクション適用
    err = report.ApplyModerationAction(action)
    if err != nil {
        return domain.ModerationActionID{}, fmt.Errorf("action application failed: %w", err)
    }

    // 6. 両方のAggregateを永続化（トランザクション内）
    err = h.performTransactionalSave(ctx, report, action, previousState)
    if err != nil {
        return domain.ModerationActionID{}, fmt.Errorf("transactional save failed: %w", err)
    }

    // 7. 監査ログ記録
    auditEntry := domain.NewAuditEntry(cmd.ModeratorID, action.ActionType(), action.TargetID(), cmd.Reason)
    err = h.auditLogger.LogModerationAction(ctx, auditEntry)
    if err != nil {
        log.Warn("Audit log failed", zap.Error(err), zap.String("action_id", string(actionID)))
    }

    // 8. ドメインイベント発行
    event := domain.NewModerationActionExecutedEvent(actionID, cmd.ReportID, cmd.ActionType, cmd.ModeratorID)
    err = h.eventPublisher.PublishActionExecuted(ctx, event)
    if err != nil {
        log.Warn("Failed to publish action executed event", zap.Error(err))
    }

    return actionID, nil
}

func (h *ExecuteModerationActionCommandHandler) performTransactionalSave(ctx context.Context, report *domain.Report, action *domain.ModerationAction, previousState *domain.ReportSnapshot) error {
    return h.actionRepo.WithTransaction(ctx, func(txRepo domain.ModerationActionRepository) error {
        // アクション保存
        if err := txRepo.Save(ctx, action); err != nil {
            return err
        }
        
        // 通報状態更新
        if err := h.reportRepo.Update(ctx, report); err != nil {
            return err
        }
        
        // ロールバック情報保存
        rollbackData := domain.NewRollbackData(action.ID(), previousState)
        return txRepo.SaveRollbackData(ctx, rollbackData)
    })
}
```

**Additional Command Handlers:**

```go
// FilterContentCommandHandler - リアルタイムコンテンツフィルタリング
type FilterContentCommandHandler struct {
    filterEngine     service.ContentFilterEngine
    mlService        service.MLClassificationService
    filterRepo       domain.ContentFilterRepository
    eventPublisher   infrastructure.FilterEventPublisher
}

type FilterContentCommand struct {
    ContentID   domain.ContentID
    ContentType domain.ContentType
    Content     string
    MediaURLs   []string
    AuthorID    domain.UserID
}

func (h *FilterContentCommandHandler) Handle(ctx context.Context, cmd FilterContentCommand) (*domain.FilterResult, error) {
    // 1. 並列フィルター実行
    filterTasks := []func() (*domain.FilterResult, error){
        func() (*domain.FilterResult, error) { return h.filterEngine.ApplyKeywordFilter(ctx, cmd.Content) },
        func() (*domain.FilterResult, error) { return h.filterEngine.ApplyRegexFilter(ctx, cmd.Content) },
        func() (*domain.FilterResult, error) { return h.mlService.ClassifyContent(ctx, cmd.Content) },
    }

    // 2. 並列実行とエラーハンドリング
    results := make([]*domain.FilterResult, len(filterTasks))
    errs := make([]error, len(filterTasks))
    
    var wg sync.WaitGroup
    for i, task := range filterTasks {
        wg.Add(1)
        go func(idx int, fn func() (*domain.FilterResult, error)) {
            defer wg.Done()
            results[idx], errs[idx] = fn()
        }(i, task)
    }
    wg.Wait()

    // 3. 結果統合
    finalResult := h.aggregateFilterResults(results, errs)
    
    // 4. フィルター結果永続化
    filter := domain.NewContentFilter(cmd.ContentID, cmd.AuthorID, finalResult)
    err := h.filterRepo.Save(ctx, filter)
    if err != nil {
        return nil, fmt.Errorf("filter save failed: %w", err)
    }

    // 5. 自動アクション判定
    if finalResult.ShouldAutoModerate() {
        autoActionEvent := domain.NewAutoModerationTriggeredEvent(cmd.ContentID, finalResult)
        h.eventPublisher.PublishAutoModerationTriggered(ctx, autoActionEvent)
    }

    return finalResult, nil
}
```

##### Query Handlers (クエリハンドラー)

**Query Handler Interface:**
```go
//go:generate mockgen -source=$GOFILE -destination=../../tests/mocks/query_handler_mock.go -package=mocks
type QueryHandler[TQuery any, TResult any] interface {
    Handle(ctx context.Context, query TQuery) (TResult, error)
}
```

**Primary Query Handlers:**

```go
// GetModerationQueueQueryHandler - モデレーションキュー取得
type GetModerationQueueQueryHandler struct {
    queryService     query.ModerationQueueQueryService
    cacheService     infrastructure.CacheService
    metricsCollector service.MetricsCollector
}

type GetModerationQueueQuery struct {
    ModeratorID     domain.UserID
    Priority        *domain.Priority
    ViolationType   *domain.ViolationReason
    Limit           int
    Cursor          *string
    FilterOptions   ModerationQueueFilter
}

type ModerationQueueFilter struct {
    AssignedOnly        bool
    UnassignedOnly      bool
    ExcludeEscalated    bool
    MinCreatedAt        *time.Time
    MaxCreatedAt        *time.Time
}

type ModerationQueueResponse struct {
    Reports        []*query.ModerationQueueItem
    NextCursor     *string
    TotalCount     int
    UnreadCount    int
    Metadata       ModerationQueueMetadata
}

type ModerationQueueMetadata struct {
    AverageWaitTime    time.Duration
    OldestUnresolved   *time.Time
    PriorityBreakdown  map[domain.Priority]int
}

func (h *GetModerationQueueQueryHandler) Handle(ctx context.Context, query GetModerationQueueQuery) (*ModerationQueueResponse, error) {
    // 1. パフォーマンス測定開始
    timer := h.metricsCollector.StartTimer("moderation_queue_query")
    defer timer.ObserveDuration()

    // 2. キャッシュ確認
    cacheKey := h.buildCacheKey(query)
    if cached, found := h.cacheService.Get(cacheKey); found {
        h.metricsCollector.IncCacheHit("moderation_queue")
        return cached.(*ModerationQueueResponse), nil
    }

    // 3. データベースクエリ実行
    dbQuery := h.buildDatabaseQuery(query)
    
    reports, nextCursor, err := h.queryService.GetModerationQueue(ctx, dbQuery)
    if err != nil {
        return nil, fmt.Errorf("queue query failed: %w", err)
    }

    // 4. メタデータ計算（並列実行）
    metadataChan := make(chan ModerationQueueMetadata, 1)
    errorChan := make(chan error, 1)
    
    go func() {
        metadata, err := h.calculateQueueMetadata(ctx, query.ModeratorID)
        if err != nil {
            errorChan <- err
            return
        }
        metadataChan <- metadata
    }()

    // 5. レスポンス構築
    var metadata ModerationQueueMetadata
    select {
    case metadata = <-metadataChan:
    case err := <-errorChan:
        log.Warn("Failed to calculate queue metadata", zap.Error(err))
        metadata = ModerationQueueMetadata{} // デフォルト値
    case <-time.After(5 * time.Second):
        log.Warn("Queue metadata calculation timeout")
        metadata = ModerationQueueMetadata{} // デフォルト値
    }

    response := &ModerationQueueResponse{
        Reports:     reports,
        NextCursor:  nextCursor,
        TotalCount:  len(reports),
        UnreadCount: h.countUnreadReports(reports),
        Metadata:    metadata,
    }

    // 6. キャッシュ保存（短期間）
    h.cacheService.SetWithTTL(cacheKey, response, 5*time.Minute)
    h.metricsCollector.IncCacheMiss("moderation_queue")

    return response, nil
}

func (h *GetModerationQueueQueryHandler) calculateQueueMetadata(ctx context.Context, moderatorID domain.UserID) (ModerationQueueMetadata, error) {
    // 統計クエリを並列実行
    var wg sync.WaitGroup
    var avgWaitTime time.Duration
    var oldestUnresolved *time.Time
    var priorityBreakdown map[domain.Priority]int
    var errs []error
    var mu sync.Mutex

    wg.Add(3)

    // 平均待機時間計算
    go func() {
        defer wg.Done()
        avg, err := h.queryService.GetAverageWaitTime(ctx, moderatorID)
        mu.Lock()
        if err != nil {
            errs = append(errs, err)
        } else {
            avgWaitTime = avg
        }
        mu.Unlock()
    }()

    // 最古の未解決報告
    go func() {
        defer wg.Done()
        oldest, err := h.queryService.GetOldestUnresolved(ctx, moderatorID)
        mu.Lock()
        if err != nil {
            errs = append(errs, err)
        } else {
            oldestUnresolved = oldest
        }
        mu.Unlock()
    }()

    // 優先度別集計
    go func() {
        defer wg.Done()
        breakdown, err := h.queryService.GetPriorityBreakdown(ctx, moderatorID)
        mu.Lock()
        if err != nil {
            errs = append(errs, err)
        } else {
            priorityBreakdown = breakdown
        }
        mu.Unlock()
    }()

    wg.Wait()

    if len(errs) > 0 {
        return ModerationQueueMetadata{}, fmt.Errorf("metadata calculation failed: %v", errs)
    }

    return ModerationQueueMetadata{
        AverageWaitTime:   avgWaitTime,
        OldestUnresolved:  oldestUnresolved,
        PriorityBreakdown: priorityBreakdown,
    }, nil
}
```

```go
// GetModerationStatsQueryHandler - 統計情報取得
type GetModerationStatsQueryHandler struct {
    statsService     query.ModerationStatsQueryService
    cacheService     infrastructure.CacheService
    metricsCollector service.MetricsCollector
}

type GetModerationStatsQuery struct {
    TimeRange    TimeRange
    Granularity  StatGranularity // hourly, daily, weekly, monthly
    ModeratorID  *domain.UserID  // specific moderator or nil for all
    Filters      StatsFilter
}

type TimeRange struct {
    From time.Time
    To   time.Time
}

type StatsFilter struct {
    ViolationTypes   []domain.ViolationReason
    ActionTypes      []domain.ModerationActionType
    IncludeAppealedActions bool
    ExcludeAutomatedActions bool
}

type ModerationStatsResponse struct {
    TimeSeries    []TimeSeriesPoint
    Summary       StatsSummary
    Comparisons   StatsComparison
    Trends        StatsTrend
}

type TimeSeriesPoint struct {
    Timestamp         time.Time
    ReportsCreated    int
    ActionsExecuted   int
    AppealsSubmitted  int
    AutoActionsCount  int
    ResolutionTime    time.Duration
}

type StatsSummary struct {
    TotalReports         int
    ResolvedReports      int
    PendingReports       int
    AverageResolutionTime time.Duration
    AccuracyRate         float64
    AppealRate           float64
    OverturnRate         float64
}

func (h *GetModerationStatsQueryHandler) Handle(ctx context.Context, query GetModerationStatsQuery) (*ModerationStatsResponse, error) {
    // 1. キャッシュキー生成
    cacheKey := h.generateStatsCacheKey(query)
    
    // 2. キャッシュ確認（統計は重い処理なので積極的にキャッシュ）
    if cached, found := h.cacheService.Get(cacheKey); found {
        h.metricsCollector.IncCacheHit("moderation_stats")
        return cached.(*ModerationStatsResponse), nil
    }

    // 3. 並列データ取得
    var wg sync.WaitGroup
    var timeSeries []TimeSeriesPoint
    var summary StatsSummary
    var comparison StatsComparison
    var trend StatsTrend
    var errs []error
    var mu sync.Mutex

    wg.Add(4)

    // 時系列データ
    go func() {
        defer wg.Done()
        data, err := h.statsService.GetTimeSeries(ctx, query.TimeRange, query.Granularity, query.Filters)
        mu.Lock()
        if err != nil {
            errs = append(errs, fmt.Errorf("timeseries fetch failed: %w", err))
        } else {
            timeSeries = data
        }
        mu.Unlock()
    }()

    // サマリー統計
    go func() {
        defer wg.Done()
        data, err := h.statsService.GetSummary(ctx, query.TimeRange, query.ModeratorID, query.Filters)
        mu.Lock()
        if err != nil {
            errs = append(errs, fmt.Errorf("summary fetch failed: %w", err))
        } else {
            summary = data
        }
        mu.Unlock()
    }()

    // 前期比較
    go func() {
        defer wg.Done()
        data, err := h.statsService.GetComparison(ctx, query.TimeRange, query.ModeratorID)
        mu.Lock()
        if err != nil {
            errs = append(errs, fmt.Errorf("comparison fetch failed: %w", err))
        } else {
            comparison = data
        }
        mu.Unlock()
    }()

    // トレンド分析
    go func() {
        defer wg.Done()
        data, err := h.statsService.GetTrends(ctx, query.TimeRange, query.Granularity)
        mu.Lock()
        if err != nil {
            errs = append(errs, fmt.Errorf("trend analysis failed: %w", err))
        } else {
            trend = data
        }
        mu.Unlock()
    }()

    wg.Wait()

    if len(errs) > 0 {
        return nil, fmt.Errorf("stats query failed: %v", errs)
    }

    response := &ModerationStatsResponse{
        TimeSeries:  timeSeries,
        Summary:     summary,
        Comparisons: comparison,
        Trends:      trend,
    }

    // 4. 長期間キャッシュ（統計データは更新頻度が低い）
    cacheTTL := h.determineCacheTTL(query.Granularity, query.TimeRange)
    h.cacheService.SetWithTTL(cacheKey, response, cacheTTL)
    h.metricsCollector.IncCacheMiss("moderation_stats")

    return response, nil
}
```

##### State Management Separation (状態管理分離)

**Command Side State Management:**
```go
// CommandStateManager - Command側での状態管理
type CommandStateManager struct {
    reportRepo      domain.ReportRepository
    actionRepo      domain.ModerationActionRepository
    lockService     infrastructure.DistributedLockService
    eventStore      infrastructure.EventStore
}

// 楽観的ロックによる並行制御
func (m *CommandStateManager) ExecuteWithOptimisticLock(ctx context.Context, reportID domain.ReportID, operation func(*domain.Report) error) error {
    maxRetries := 3
    for attempt := 0; attempt < maxRetries; attempt++ {
        report, err := m.reportRepo.FindByIDWithVersion(ctx, reportID)
        if err != nil {
            return fmt.Errorf("report fetch failed: %w", err)
        }

        originalVersion := report.Version()
        
        err = operation(report)
        if err != nil {
            return fmt.Errorf("operation failed: %w", err)
        }

        err = m.reportRepo.UpdateWithVersionCheck(ctx, report, originalVersion)
        if err == domain.ErrOptimisticLockFailure && attempt < maxRetries-1 {
            time.Sleep(time.Duration(attempt+1) * 100 * time.Millisecond) // exponential backoff
            continue
        }
        
        return err
    }
    
    return domain.ErrOptimisticLockFailure
}

// 分散ロックによる排他制御（重要な操作用）
func (m *CommandStateManager) ExecuteWithDistributedLock(ctx context.Context, reportID domain.ReportID, operation func(*domain.Report) error) error {
    lockKey := fmt.Sprintf("report_lock:%s", reportID)
    
    lock, err := m.lockService.AcquireLock(ctx, lockKey, 30*time.Second)
    if err != nil {
        return fmt.Errorf("lock acquisition failed: %w", err)
    }
    defer lock.Release()

    report, err := m.reportRepo.FindByID(ctx, reportID)
    if err != nil {
        return fmt.Errorf("report fetch failed: %w", err)
    }

    err = operation(report)
    if err != nil {
        return fmt.Errorf("operation failed: %w", err)
    }

    return m.reportRepo.Update(ctx, report)
}
```

**Query Side State Management:**
```go
// QueryStateManager - Query側での読み取り専用状態管理
type QueryStateManager struct {
    readOnlyDB      infrastructure.ReadOnlyDatabase
    cacheService    infrastructure.CacheService
    indexService    infrastructure.SearchIndexService
}

// 読み取り専用レプリカからのクエリ
func (m *QueryStateManager) QueryFromReplica(ctx context.Context, query interface{}) (interface{}, error) {
    // レプリカ遅延チェック
    replicationLag, err := m.readOnlyDB.GetReplicationLag(ctx)
    if err != nil {
        log.Warn("Failed to check replication lag", zap.Error(err))
    }

    if replicationLag > 5*time.Second {
        log.Warn("High replication lag detected", zap.Duration("lag", replicationLag))
        // 高い遅延の場合、キャッシュまたはプライマリへフォールバック
        return m.queryFromCacheOrPrimary(ctx, query)
    }

    return m.executeQuery(ctx, query)
}

// 複数データソースからの一貫性のある読み取り
func (m *QueryStateManager) QueryWithConsistency(ctx context.Context, query interface{}, consistencyLevel ConsistencyLevel) (interface{}, error) {
    switch consistencyLevel {
    case EventualConsistency:
        return m.QueryFromReplica(ctx, query)
    case StrongConsistency:
        return m.queryFromPrimary(ctx, query)
    case CacheFirst:
        return m.queryFromCacheWithFallback(ctx, query)
    default:
        return nil, fmt.Errorf("unsupported consistency level: %v", consistencyLevel)
    }
}
```

##### CQRS Architecture Pattern (CQRS アーキテクチャパターン)

**Overall CQRS Flow:**
```go
// ModerationServiceCoordinator - CQRS調整レイヤー
type ModerationServiceCoordinator struct {
    // Command側
    commandBus        infrastructure.CommandBus
    commandHandlers   map[string]interface{}
    
    // Query側  
    queryBus          infrastructure.QueryBus
    queryHandlers     map[string]interface{}
    
    // 共通
    eventBus          infrastructure.EventBus
    metricsCollector  service.MetricsCollector
}

func NewModerationServiceCoordinator(
    commandBus infrastructure.CommandBus,
    queryBus infrastructure.QueryBus,
    eventBus infrastructure.EventBus,
) *ModerationServiceCoordinator {
    coordinator := &ModerationServiceCoordinator{
        commandBus:      commandBus,
        queryBus:        queryBus,
        eventBus:        eventBus,
        commandHandlers: make(map[string]interface{}),
        queryHandlers:   make(map[string]interface{}),
    }
    
    coordinator.registerHandlers()
    return coordinator
}

func (c *ModerationServiceCoordinator) registerHandlers() {
    // Command handlers registration
    c.commandHandlers["CreateReport"] = &CreateReportCommandHandler{}
    c.commandHandlers["ExecuteModerationAction"] = &ExecuteModerationActionCommandHandler{}
    c.commandHandlers["FilterContent"] = &FilterContentCommandHandler{}
    c.commandHandlers["CreateAppeal"] = &CreateAppealCommandHandler{}
    c.commandHandlers["ReviewAppeal"] = &ReviewAppealCommandHandler{}
    
    // Query handlers registration  
    c.queryHandlers["GetModerationQueue"] = &GetModerationQueueQueryHandler{}
    c.queryHandlers["GetModerationStats"] = &GetModerationStatsQueryHandler{}
    c.queryHandlers["GetReportDetails"] = &GetReportDetailsQueryHandler{}
    c.queryHandlers["GetModerationHistory"] = &GetModerationHistoryQueryHandler{}
    c.queryHandlers["GetAppeals"] = &GetAppealsQueryHandler{}
}

// Command実行
func (c *ModerationServiceCoordinator) ExecuteCommand(ctx context.Context, commandName string, command interface{}) (interface{}, error) {
    timer := c.metricsCollector.StartTimer(fmt.Sprintf("command_%s", commandName))
    defer timer.ObserveDuration()

    handler, exists := c.commandHandlers[commandName]
    if !exists {
        return nil, fmt.Errorf("command handler not found: %s", commandName)
    }

    // Command実行
    result, err := c.commandBus.Execute(ctx, handler, command)
    if err != nil {
        c.metricsCollector.IncCommandError(commandName)
        return nil, fmt.Errorf("command execution failed: %w", err)
    }

    c.metricsCollector.IncCommandSuccess(commandName)
    return result, nil
}

// Query実行
func (c *ModerationServiceCoordinator) ExecuteQuery(ctx context.Context, queryName string, query interface{}) (interface{}, error) {
    timer := c.metricsCollector.StartTimer(fmt.Sprintf("query_%s", queryName))
    defer timer.ObserveDuration()

    handler, exists := c.queryHandlers[queryName]
    if !exists {
        return nil, fmt.Errorf("query handler not found: %s", queryName)
    }

    // Query実行
    result, err := c.queryBus.Execute(ctx, handler, query)
    if err != nil {
        c.metricsCollector.IncQueryError(queryName)
        return nil, fmt.Errorf("query execution failed: %w", err)
    }

    c.metricsCollector.IncQuerySuccess(queryName)
    return result, nil
}
```

**Event-Driven Synchronization:**
```go
// CommandQuerySynchronizer - Command/Query間の同期
type CommandQuerySynchronizer struct {
    eventBus         infrastructure.EventBus
    queryModelUpdater service.QueryModelUpdater
}

func (s *CommandQuerySynchronizer) HandleDomainEvent(ctx context.Context, event interface{}) error {
    switch e := event.(type) {
    case domain.ReportCreatedEvent:
        return s.updateReportQueryModel(ctx, e)
    case domain.ModerationActionExecutedEvent:
        return s.updateActionQueryModel(ctx, e)
    case domain.AppealCreatedEvent:
        return s.updateAppealQueryModel(ctx, e)
    default:
        log.Warn("Unhandled domain event", zap.String("event_type", fmt.Sprintf("%T", event)))
        return nil
    }
}

func (s *CommandQuerySynchronizer) updateReportQueryModel(ctx context.Context, event domain.ReportCreatedEvent) error {
    // Query側のモデルを更新
    queryModel := &query.ReportQueryModel{
        ReportID:     event.ReportID,
        ReporterID:   event.ReporterID,
        TargetID:     event.TargetID,
        Priority:     event.Priority,
        Status:       domain.ReportStatusPending,
        CreatedAt:    event.Timestamp,
    }
    
    return s.queryModelUpdater.UpdateReportModel(ctx, queryModel)
}
```

#### Infrastructure Layer (インフラストラクチャ層)
- **Repository Implementations:**
  - ReportRepositoryImpl (PostgreSQL)
  - ModerationActionRepositoryImpl (PostgreSQL)
  - ContentFilterRepositoryImpl (PostgreSQL)
  - AppealRepositoryImpl (PostgreSQL)
  - InstancePolicyRepositoryImpl (PostgreSQL)
- **Query Service Implementations:**
  - ReportQueryServiceImpl (PostgreSQL + Redisキャッシュ)
  - ModerationQueueQueryServiceImpl (PostgreSQL + Redis)
  - ModerationStatsQueryServiceImpl (PostgreSQL)
- **External Service Implementations:**
  - TensorFlowMLService (TensorFlow Serving)
  - GoogleVisionAPIService (Google Vision API)
  - TextAnalyticsAPIService (Azure Text Analytics)
- **Event Publishers:**
  - ReportEventPublisher (Redis Pub/Sub)
  - ModerationEventPublisher (Redis Pub/Sub)
  - FilterEventPublisher (Redis Pub/Sub)
  - AppealEventPublisher (Redis Pub/Sub)

#### Handler Layer (ハンドラー層)
- **gRPC Handlers:**
  - ReportHandler: 通報関連のRPCハンドラー
  - ModerationActionHandler: モデレーションアクションRPCハンドラー
  - ContentFilterHandler: フィルタリングRPCハンドラー
  - AppealHandler: 異議申し立てRPCハンドラー
  - InstancePolicyHandler: インスタンスポリシーRPCハンドラー
- **Event Handlers:**
  - ContentCreatedEventHandler: コンテンツ作成イベント処理
  - ContentUpdatedEventHandler: コンテンツ更新イベント処理
  - UserRegisteredEventHandler: ユーザー登録イベント処理
  - UserDeletedEventHandler: ユーザー削除イベント処理
  - MediaDeletedEventHandler: メディア削除イベント処理
  - FederationFlagReceivedEventHandler: フェデレーション通報受信処理
  - AIConsentChangedEventHandler: AI同意設定変更イベント処理
- **Batch Job Handlers:**
  - PriorityRecalculationJob: 優先度再計算
  - ExpirationProcessingJob: 期限切れ処理
  - StatisticsAggregationJob: 統計集計
  - ReputationUpdateJob: レピュテーション更新

### 5.2. システム構成

```
┌─────────────────────────────────────────┐
│          Handler Layer                   │
│  - gRPC Handlers                        │
│  - Event Handlers                       │
│  - Batch Job Handlers                   │
│  - Moderator API                        │
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐
│         Use Case Layer                   │
│  - Command Use Cases                     │
│  - Query Use Cases                       │
│  - Filter Services                      │
│  - Detection Services                   │
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐
│          Domain Layer                    │
│  - Aggregates                           │
│  - Domain Services                      │
│  - Filter Engine                        │
│  - ML Classifier                        │
└─────────────────────────────────────────┘
                    │
┌─────────────────────────────────────────┐
│       Infrastructure Layer               │
│  - Repositories                         │
│  - External APIs                        │
│  - ML Services                          │
│  - Cache                                │
└─────────────────────────────────────────┘
```

#### 主要コンポーネント構成

#### コア機能
- **ReportAggregate**: 通報の受付と処理
- **ModerationActionAggregate**: モデレーション操作
- **ContentFilterAggregate**: フィルタルール管理
- **AppealAggregate**: 異議申し立て管理
- **InstancePolicyAggregate**: インスタンスポリシー

#### エンジン・サービス
- **FilterEngine**: リアルタイムフィルタリング
- **MLClassifier**: 機械学習による分類
- **ViolationDetectionService**: 違反検知
- **PriorityCalculationService**: 優先度計算
- **EscalationService**: エスカレーション判断

#### 処理系
- **QueueManager**: モデレーションキュー管理
- **BatchProcessor**: バッチ処理
- **AuditLogger**: 監査ログ記録

## 7. Use Cases / Key Flows (主な使い方・処理の流れ)

### 6.1. 通報処理フロー

#### 通報受付と初期処理
- **フロー 1: 通報作成 (Command)**
  1. Gateway → CreateReportCommandHandler: `CreateReport` gRPC Call (reporter_id, target_type, target_id, reason, description)
  2. CreateReportCommandHandler: CreateReportCommandUseCaseを呼び出し
  3. CreateReportCommandUseCase: Report Aggregateを生成し、重複チェック実行
  4. ViolationDetectionService: 通報理由と対象コンテンツの自動評価
  5. PriorityCalculationService: 通報者信頼度とコンテンツ履歴から優先度計算
  6. ReportRepository: 通報データの永続化
  7. ReportEventPublisher: `moderation.report.created` イベント発行
  8. CreateReportCommandHandler → Gateway: `CreateReportResponse { report_id: "..." }`

- **フロー 2: 自動フィルタリング処理**
  1. ContentCreatedEventHandler: `content.created` イベント受信
  2. FilterContentCommandUseCase: ContentFilter実行
  3. FilterEngine: 並列フィルター処理（NGワード、正規表現、ML分類）
  4. MLClassifier: 機械学習による有害コンテンツ判定
  5. 閾値判定: 自動アクション実行 or モデレーションキュー追加
  6. FilterEventPublisher: `moderation.content.filtered` イベント発行

- **フロー 3: モデレーター処理**
  1. GetModerationQueueQueryHandler: 優先度順のキュー取得
  2. AssignReportCommandHandler: 通報の担当者割り当て
  3. GetReportDetailsQueryHandler: 通報詳細と証拠の取得
  4. GetViolationContextQueryHandler: 対象ユーザーの違反履歴取得
  5. ExecuteModerationActionCommandHandler: 判定とアクション実行
  6. ModerationEventPublisher: `moderation.action.executed` イベント発行

### 6.2. 異議申し立てフロー

#### 異議申し立て作成と処理
- **フロー 4: 異議申し立て作成 (Command)**
  1. User → CreateAppealCommandHandler: 異議申し立て作成
  2. CreateAppealCommandUseCase: AppealAggregate生成、期限設定
  3. AppealRepository: 異議申し立てデータ永続化
  4. AppealEventPublisher: `moderation.appeal.created` イベント発行
  5. NotificationService: モデレーターへの通知送信

- **フロー 5: 異議申し立てレビュー (Command)**
  1. ReviewAppealCommandHandler: レビュー実行
  2. ReviewAppealCommandUseCase: 証拠評価と判定
  3. EscalationService: 複雑なケースのエスカレーション判断
  4. RevertModerationActionCommandHandler: 必要に応じてアクション取り消し
  5. AppealEventPublisher: `moderation.appeal.resolved` イベント発行

### 6.3. インスタンスポリシー管理フロー

#### ポリシー設定と適用
- **フロー 6: インスタンスポリシー設定 (Command)**
  1. SetInstancePolicyCommandHandler: ポリシー設定要求
  2. SetInstancePolicyCommandUseCase: InstancePolicyAggregate生成
  3. PolicyValidationService: ポリシーの妥当性検証
  4. InstancePolicyRepository: ポリシー設定の永続化
  5. InstancePolicyEventPublisher: `moderation.instance.policy_applied` イベント発行

- **フロー 7: レピュテーション評価**
  1. ReputationUpdateJob: 定期的なレピュテーション計算
  2. InstanceReputationAggregate: スパムスコア、違反率の更新
  3. AutoPolicyService: 自動ポリシー適用判断
  4. InstancePolicyRepository: 自動ポリシーの永続化

### 6.4. バッチ処理フロー

#### 定期メンテナンス処理
- **フロー 8: 優先度再計算 (5分ごと)**
  1. PriorityRecalculationJob: 通報集約とSLA期限チェック
  2. ReportAggregate: 優先度値の更新
  3. ModerationQueue: キュー順序の再編成

- **フロー 9: 期限切れ処理 (1時間ごと)**
  1. ExpirationProcessingJob: 一時停止の自動解除
  2. ModerationActionAggregate: 期限切れアクションの無効化
  3. AppealAggregate: 期限切れ異議申し立ての自動却下

## データベースマイグレーション戦略

このサービスでは、[共通マイグレーション戦略](../common/database-migration-strategy.md)に従って、Gooseを使用したマイグレーション管理を行います。

### マイグレーション戦略詳細

- **ツール**: Goose v3
- **ディレクトリ**: `./migrations/`
- **命名規則**: `[sequence_number]_[description].sql`
- **実行方法**: `make migrate-up` / `make migrate-down`
- **センシティブデータ対応**: プライバシー配慮したスキーマ設計
- **監査対応**: 全マイグレーション実行の追跡可能性

### avion-moderation固有の考慮事項

- **通報データ完全性**: 通報内容や処理履歴の完全性を移行中も保証
- **モデレーションアクション継続**: 進行中のモデレーションアクション（一時停止など）を適切に継承
- **フィルタリングルール保持**: コンテンツフィルタリングルールや設定を正確に移行
- **監査ログ維持**: 法的要件を満たすため監査ログの完全性を保証
- **プライバシー保護**: 通報者・被通報者の個人情報保護を移行時も徹底

### 段階的マイグレーション実装例

#### Phase 1: 基本テーブル作成
```sql
-- 20250101000001_create_basic_tables.sql
-- +goose Up
-- +goose StatementBegin

-- 通報基本テーブル
CREATE TABLE reports (
    report_id UUID PRIMARY KEY,
    reporter_user_id UUID NOT NULL,
    target_type TEXT NOT NULL CHECK (target_type IN ('user', 'drop', 'media')),
    target_id UUID NOT NULL,
    reason TEXT NOT NULL CHECK (reason IN ('spam', 'harassment', 'violence', 'illegal', 'other')),
    description TEXT,
    status TEXT NOT NULL CHECK (status IN ('pending', 'reviewing', 'resolved', 'dismissed')),
    priority INT DEFAULT 0 CHECK (priority >= 0 AND priority <= 100),
    assigned_to UUID,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 基本インデックス
CREATE INDEX idx_reports_status ON reports(status, created_at) WHERE status IN ('pending', 'reviewing');
CREATE INDEX idx_reports_target ON reports(target_type, target_id);

-- 更新時間自動更新トリガー
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_reports_updated_at BEFORE UPDATE ON reports
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TRIGGER IF EXISTS update_reports_updated_at ON reports;
DROP FUNCTION IF EXISTS update_updated_at_column();
DROP TABLE IF EXISTS reports;
-- +goose StatementEnd
```

#### Phase 4: 監査・プライバシー保護機能
```sql
-- 20250101000004_add_privacy_audit.sql
-- +goose Up
-- +goose StatementBegin

-- 監査ログテーブル（パーティション対応）
CREATE TABLE moderation_logs (
    log_id UUID PRIMARY KEY,
    event_type TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    actor_type TEXT NOT NULL,
    actor_id UUID,
    action_details JSONB NOT NULL,
    ip_address INET, -- プライバシー考慮：必要な場合のみ記録
    user_agent TEXT, -- ハッシュ化推奨
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    retention_until TIMESTAMP NOT NULL DEFAULT (CURRENT_TIMESTAMP + INTERVAL '7 years')
) PARTITION BY RANGE (created_at);

-- GDPR対応機能
ALTER TABLE reports ADD COLUMN IF NOT EXISTS 
    data_retention_policy TEXT DEFAULT 'standard_7y',
    consent_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deletion_scheduled TIMESTAMP;

-- データ暗号化関数
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION encrypt_pii(data TEXT, key TEXT) 
RETURNS TEXT AS $$
BEGIN
    RETURN encode(pgp_sym_encrypt(data, key), 'base64');
END;
$$ LANGUAGE plpgsql;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP FUNCTION IF EXISTS encrypt_pii(TEXT, TEXT);
DROP TABLE IF EXISTS moderation_logs;
ALTER TABLE reports 
    DROP COLUMN IF EXISTS data_retention_policy,
    DROP COLUMN IF EXISTS consent_timestamp,
    DROP COLUMN IF EXISTS deletion_scheduled;
-- +goose StatementEnd
```

### プロダクション環境マイグレーション手順

```bash
# 1. バックアップ作成
pg_dump -h $DB_HOST -U $DB_USER -d avion_moderation > backup_$(date +%Y%m%d_%H%M%S).sql

# 2. マイグレーション実行（段階的）
make migrate-up-by-one  # 1つずつ確認しながら実行

# 3. データ整合性確認
make verify-data-integrity

# 4. ロールバック準備（緊急時）
make migrate-down-by-one
```

### 標準テンプレート参照

マイグレーションファイル作成時は[マイグレーション設定テンプレート](../templates/migration-setup-template.md)を参照してください。

## 7. Detailed Design (詳細設計)

### 6.1. API設計

#### gRPC API 定義

```protobuf
service ModerationService {
  // 通報管理
  rpc CreateReport(CreateReportRequest) returns (CreateReportResponse);
  rpc GetReports(GetReportsRequest) returns (GetReportsResponse);
  rpc GetReportDetails(GetReportDetailsRequest) returns (GetReportDetailsResponse);
  rpc UpdateReportStatus(UpdateReportStatusRequest) returns (UpdateReportStatusResponse);
  rpc AssignReport(AssignReportRequest) returns (AssignReportResponse);
  rpc EscalateReport(EscalateReportRequest) returns (EscalateReportResponse);
  
  // モデレーションアクション
  rpc ExecuteModerationAction(ExecuteModerationActionRequest) returns (ExecuteModerationActionResponse);
  rpc RevertModerationAction(RevertModerationActionRequest) returns (RevertModerationActionResponse);
  rpc GetModerationHistory(GetModerationHistoryRequest) returns (GetModerationHistoryResponse);
  rpc ExpireModerationAction(ExpireModerationActionRequest) returns (ExpireModerationActionResponse);
  
  // コンテンツフィルタリング
  rpc CheckContent(CheckContentRequest) returns (CheckContentResponse);
  rpc CreateFilter(CreateFilterRequest) returns (CreateFilterResponse);
  rpc UpdateFilter(UpdateFilterRequest) returns (UpdateFilterResponse);
  rpc DeleteFilter(DeleteFilterRequest) returns (DeleteFilterResponse);
  rpc GetFilters(GetFiltersRequest) returns (GetFiltersResponse);
  rpc TestFilter(TestFilterRequest) returns (TestFilterResponse);
  
  // 異議申し立て
  rpc CreateAppeal(CreateAppealRequest) returns (CreateAppealResponse);
  rpc ReviewAppeal(ReviewAppealRequest) returns (ReviewAppealResponse);
  rpc GetAppeals(GetAppealsRequest) returns (GetAppealsResponse);
  rpc GetAppealDetails(GetAppealDetailsRequest) returns (GetAppealDetailsResponse);
  
  // インスタンスポリシー
  rpc SetInstancePolicy(SetInstancePolicyRequest) returns (SetInstancePolicyResponse);
  rpc GetInstancePolicies(GetInstancePoliciesRequest) returns (GetInstancePoliciesResponse);
  rpc UpdateInstanceReputation(UpdateInstanceReputationRequest) returns (UpdateInstanceReputationResponse);
  
  // モデレーターツール
  rpc GetModerationQueue(GetModerationQueueRequest) returns (GetModerationQueueResponse);
  rpc CreateModeratorNote(CreateModeratorNoteRequest) returns (CreateModeratorNoteResponse);
  rpc GetModeratorNotes(GetModeratorNotesRequest) returns (GetModeratorNotesResponse);
  rpc GetViolationContext(GetViolationContextRequest) returns (GetViolationContextResponse);
  
  // 統計・レポート
  rpc GetModerationStats(GetModerationStatsRequest) returns (GetModerationStatsResponse);
  rpc GetModeratorActivity(GetModeratorActivityRequest) returns (GetModeratorActivityResponse);
  rpc GenerateComplianceReport(GenerateComplianceReportRequest) returns (GenerateComplianceReportResponse);
  rpc GetViolationTrends(GetViolationTrendsRequest) returns (GetViolationTrendsResponse);
}
```

### 6.2. データモデル

### 通報関連

```sql
-- 通報
CREATE TABLE reports (
    report_id UUID PRIMARY KEY,
    reporter_user_id UUID NOT NULL,
    target_type TEXT NOT NULL CHECK (target_type IN ('user', 'drop', 'media')),
    target_id UUID NOT NULL,
    reason TEXT NOT NULL CHECK (reason IN ('spam', 'harassment', 'violence', 'illegal', 'other')),
    description TEXT,
    status TEXT NOT NULL CHECK (status IN ('pending', 'reviewing', 'resolved', 'dismissed')),
    priority INT DEFAULT 0 CHECK (priority >= 0 AND priority <= 100),
    assigned_to UUID,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    resolved_at TIMESTAMP,
    resolved_by UUID,
    resolution_note TEXT,
    is_escalated BOOLEAN DEFAULT false,
    escalated_to UUID,
    escalated_at TIMESTAMP
);

-- 通報証拠
CREATE TABLE report_evidences (
    evidence_id UUID PRIMARY KEY,
    report_id UUID REFERENCES reports(report_id) ON DELETE CASCADE,
    evidence_type TEXT NOT NULL CHECK (evidence_type IN ('screenshot', 'url', 'text')),
    evidence_data JSONB NOT NULL,
    created_at TIMESTAMP NOT NULL
);

-- モデレーションケース（複数通報の統合管理）
CREATE TABLE moderation_cases (
    case_id UUID PRIMARY KEY,
    case_status TEXT NOT NULL CHECK (case_status IN ('open', 'investigating', 'resolved', 'escalated')),
    primary_moderator_id UUID,
    secondary_moderator_ids UUID[],
    overall_priority INT DEFAULT 0,
    overall_severity TEXT CHECK (overall_severity IN ('low', 'medium', 'high', 'critical')),
    ai_consent_status TEXT CHECK (ai_consent_status IN ('consented', 'not_consented', 'mixed')),
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    resolved_at TIMESTAMP,
    resolution_summary TEXT
);

-- ケースと通報の関連付け
CREATE TABLE case_reports (
    case_id UUID REFERENCES moderation_cases(case_id) ON DELETE CASCADE,
    report_id UUID REFERENCES reports(report_id) ON DELETE CASCADE,
    added_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (case_id, report_id)
);

-- 通報集約（同一対象への複数通報）
CREATE TABLE report_aggregations (
    target_type TEXT NOT NULL,
    target_id UUID NOT NULL,
    report_count INT DEFAULT 1,
    unique_reporters INT DEFAULT 1,
    first_reported_at TIMESTAMP NOT NULL,
    last_reported_at TIMESTAMP NOT NULL,
    aggregated_priority INT DEFAULT 0,
    PRIMARY KEY (target_type, target_id)
);

-- コミュニティ投票
CREATE TABLE community_votes (
    vote_id UUID PRIMARY KEY,
    target_type TEXT NOT NULL,
    target_id UUID NOT NULL,
    voter_id UUID NOT NULL,
    vote_type TEXT NOT NULL CHECK (vote_type IN ('approve', 'reject', 'unsure')),
    voter_trust_level INT NOT NULL CHECK (voter_trust_level >= 0 AND voter_trust_level <= 3),
    vote_weight FLOAT DEFAULT 1.0,
    voted_at TIMESTAMP NOT NULL,
    UNIQUE(target_type, target_id, voter_id)
);

-- コミュニティ投票集計
CREATE TABLE community_vote_results (
    target_type TEXT NOT NULL,
    target_id UUID NOT NULL,
    total_votes INT DEFAULT 0,
    approve_votes INT DEFAULT 0,
    reject_votes INT DEFAULT 0,
    unsure_votes INT DEFAULT 0,
    weighted_score FLOAT DEFAULT 0.0,
    decision TEXT CHECK (decision IN ('approved', 'rejected', 'pending', 'insufficient')),
    decided_at TIMESTAMP,
    PRIMARY KEY (target_type, target_id)
);

-- ユーザー信頼レベル
CREATE TABLE user_trust_levels (
    user_id UUID PRIMARY KEY,
    trust_level INT NOT NULL DEFAULT 0 CHECK (trust_level >= 0 AND trust_level <= 3),
    level_name TEXT NOT NULL,
    permissions JSONB NOT NULL,
    reports_accuracy FLOAT DEFAULT 0.0,
    helpful_votes INT DEFAULT 0,
    decisions_accuracy FLOAT DEFAULT 0.0,
    last_activity_at TIMESTAMP,
    level_updated_at TIMESTAMP NOT NULL,
    auto_promoted BOOLEAN DEFAULT false
);

-- AI同意設定
CREATE TABLE ai_consent_settings (
    user_id UUID PRIMARY KEY,
    own_content_analysis BOOLEAN DEFAULT false,
    reported_content_analysis BOOLEAN DEFAULT false,
    preventive_scan BOOLEAN DEFAULT false,
    suggest_actions BOOLEAN DEFAULT true,
    auto_execute BOOLEAN DEFAULT false,
    allow_training BOOLEAN DEFAULT false,
    consent_updated_at TIMESTAMP NOT NULL,
    consent_version TEXT NOT NULL
);

-- 通報者信頼度
CREATE TABLE reporter_credibility (
    user_id UUID PRIMARY KEY,
    total_reports INT DEFAULT 0,
    valid_reports INT DEFAULT 0,
    false_reports INT DEFAULT 0,
    credibility_score FLOAT DEFAULT 0.5 CHECK (credibility_score >= 0 AND credibility_score <= 1),
    last_updated TIMESTAMP NOT NULL
);
```

### モデレーションアクション

```sql
-- モデレーションアクション
CREATE TABLE moderation_actions (
    action_id UUID PRIMARY KEY,
    action_type TEXT NOT NULL CHECK (action_type IN ('warn', 'delete_content', 'suspend_account', 'ban_account', 'shadowban', 'restrict_reach')),
    target_type TEXT NOT NULL,
    target_id UUID NOT NULL,
    moderator_id UUID,
    reason TEXT NOT NULL,
    details JSONB,
    severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    executed_at TIMESTAMP NOT NULL,
    expires_at TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    reverted_at TIMESTAMP,
    reverted_by UUID,
    revert_reason TEXT,
    report_ids UUID[] DEFAULT '{}'
);

-- モデレーションテンプレート
CREATE TABLE moderation_templates (
    template_id UUID PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    action_type TEXT NOT NULL,
    reason_template TEXT NOT NULL,
    default_duration INTERVAL,
    severity TEXT NOT NULL,
    created_by UUID NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT true,
    usage_count INT DEFAULT 0
);

-- モデレーターノート
CREATE TABLE moderator_notes (
    note_id UUID PRIMARY KEY,
    target_type TEXT NOT NULL,
    target_id UUID NOT NULL,
    moderator_id UUID NOT NULL,
    note TEXT NOT NULL,
    is_internal BOOLEAN DEFAULT false,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP
);

-- 違反履歴
CREATE TABLE violation_history (
    user_id UUID NOT NULL,
    action_id UUID REFERENCES moderation_actions(action_id),
    action_type TEXT NOT NULL,
    severity TEXT NOT NULL,
    occurred_at TIMESTAMP NOT NULL,
    PRIMARY KEY (user_id, action_id)
);

CREATE INDEX idx_violation_history_user ON violation_history(user_id, occurred_at DESC);

-- 通報テーブル用インデックス
CREATE INDEX idx_reports_status_priority ON reports(status, priority DESC, created_at) WHERE status IN ('pending', 'reviewing');
CREATE INDEX idx_reports_target ON reports(target_type, target_id);
CREATE INDEX idx_reports_reporter ON reports(reporter_user_id, created_at DESC);
CREATE INDEX idx_reports_assigned_moderator ON reports(assigned_to, status) WHERE assigned_to IS NOT NULL;
CREATE INDEX idx_reports_escalated ON reports(is_escalated, escalated_at) WHERE is_escalated = true;
CREATE INDEX idx_reports_created_date ON reports(created_at) WHERE created_at >= CURRENT_DATE - INTERVAL '30 days';

-- 通報集約テーブル用インデックス
CREATE INDEX idx_report_aggregations_priority ON report_aggregations(aggregated_priority DESC, last_reported_at);
CREATE INDEX idx_report_aggregations_recent ON report_aggregations(last_reported_at) WHERE last_reported_at >= CURRENT_DATE - INTERVAL '7 days';

-- モデレーションアクション用インデックス
CREATE INDEX idx_moderation_actions_target ON moderation_actions(target_type, target_id, is_active);
CREATE INDEX idx_moderation_actions_moderator ON moderation_actions(moderator_id, executed_at DESC);
CREATE INDEX idx_moderation_actions_active ON moderation_actions(is_active, expires_at) WHERE is_active = true;
CREATE INDEX idx_moderation_actions_executed_date ON moderation_actions(executed_at DESC);
CREATE INDEX idx_moderation_actions_severity ON moderation_actions(severity, action_type, executed_at);

-- 外部キー制約
ALTER TABLE reports ADD CONSTRAINT fk_reports_assigned_to 
    FOREIGN KEY (assigned_to) REFERENCES users(user_id) ON DELETE SET NULL;
ALTER TABLE reports ADD CONSTRAINT fk_reports_escalated_to 
    FOREIGN KEY (escalated_to) REFERENCES users(user_id) ON DELETE SET NULL;
ALTER TABLE moderation_actions ADD CONSTRAINT fk_moderation_actions_moderator 
    FOREIGN KEY (moderator_id) REFERENCES users(user_id) ON DELETE SET NULL;

-- 制約とトリガー
ALTER TABLE reports ADD CONSTRAINT check_priority_range 
    CHECK (priority >= 0 AND priority <= 100);
ALTER TABLE reports ADD CONSTRAINT check_escalation_logic 
    CHECK ((is_escalated = false AND escalated_to IS NULL AND escalated_at IS NULL) OR 
           (is_escalated = true AND escalated_to IS NOT NULL AND escalated_at IS NOT NULL));
```

### フィルタリング

```sql
-- コンテンツフィルター
CREATE TABLE content_filters (
    filter_id UUID PRIMARY KEY,
    filter_name TEXT NOT NULL UNIQUE,
    filter_type TEXT NOT NULL CHECK (filter_type IN ('keyword', 'regex', 'ml_classifier', 'domain_block')),
    pattern TEXT,
    ml_model_id TEXT,
    severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    action TEXT NOT NULL CHECK (action IN ('flag', 'hold', 'reject', 'shadowban')),
    confidence_threshold FLOAT DEFAULT 0.7,
    priority INT DEFAULT 0,
    is_system BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_by UUID NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    effectiveness_score FLOAT DEFAULT 0.0
);

-- NGワード辞書
CREATE TABLE ng_words (
    word_id UUID PRIMARY KEY,
    word TEXT NOT NULL UNIQUE,
    category TEXT NOT NULL,
    severity TEXT NOT NULL,
    language TEXT DEFAULT 'ja',
    added_by UUID NOT NULL,
    added_at TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT true,
    match_count INT DEFAULT 0,
    false_positive_count INT DEFAULT 0
);

-- フィルター条件
CREATE TABLE filter_conditions (
    condition_id UUID PRIMARY KEY,
    filter_id UUID REFERENCES content_filters(filter_id) ON DELETE CASCADE,
    condition_type TEXT NOT NULL,
    pattern TEXT NOT NULL,
    threshold FLOAT,
    weight FLOAT DEFAULT 1.0,
    created_at TIMESTAMP NOT NULL
);

-- フィルター適用ログ
CREATE TABLE filter_logs (
    log_id UUID PRIMARY KEY,
    filter_id UUID REFERENCES content_filters(filter_id),
    content_type TEXT NOT NULL,
    content_id UUID NOT NULL,
    matched_text TEXT,
    confidence_score FLOAT,
    action_taken TEXT NOT NULL,
    is_false_positive BOOLEAN,
    created_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_filter_logs_time ON filter_logs(created_at DESC);
CREATE INDEX idx_filter_logs_filter ON filter_logs(filter_id, created_at DESC);

-- フィルター関連インデックス
CREATE INDEX idx_content_filters_active ON content_filters(is_active, priority DESC) WHERE is_active = true;
CREATE INDEX idx_content_filters_type ON content_filters(filter_type, severity);
CREATE INDEX idx_content_filters_effectiveness ON content_filters(effectiveness_score DESC, filter_type);
CREATE INDEX idx_ng_words_active ON ng_words(is_active, category, language) WHERE is_active = true;
CREATE INDEX idx_ng_words_match_count ON ng_words(match_count DESC, false_positive_count);
CREATE INDEX idx_filter_conditions_filter ON filter_conditions(filter_id);

-- フィルター制約
ALTER TABLE content_filters ADD CONSTRAINT check_confidence_threshold 
    CHECK (confidence_threshold >= 0.0 AND confidence_threshold <= 1.0);
ALTER TABLE content_filters ADD CONSTRAINT check_effectiveness_score 
    CHECK (effectiveness_score >= 0.0 AND effectiveness_score <= 1.0);
ALTER TABLE ng_words ADD CONSTRAINT check_word_not_empty 
    CHECK (LENGTH(TRIM(word)) > 0);
```

### インスタンスポリシー

```sql
-- インスタンスポリシー
CREATE TABLE instance_policies (
    domain TEXT PRIMARY KEY,
    policy_type TEXT NOT NULL CHECK (policy_type IN ('block', 'silence', 'media_removal', 'reject_reports')),
    reason TEXT,
    expires_at TIMESTAMP,
    created_by UUID NOT NULL,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT true
);

-- インスタンスレピュテーション
CREATE TABLE instance_reputations (
    domain TEXT PRIMARY KEY,
    spam_score FLOAT DEFAULT 0.0 CHECK (spam_score >= 0 AND spam_score <= 100),
    violation_count INT DEFAULT 0,
    total_reports INT DEFAULT 0,
    false_report_count INT DEFAULT 0,
    content_volume INT DEFAULT 0,
    last_incident_at TIMESTAMP,
    reputation_score FLOAT DEFAULT 50.0 CHECK (reputation_score >= 0 AND reputation_score <= 100),
    updated_at TIMESTAMP NOT NULL
);

-- インスタンスインシデント
CREATE TABLE instance_incidents (
    incident_id UUID PRIMARY KEY,
    domain TEXT NOT NULL,
    incident_type TEXT NOT NULL,
    severity TEXT NOT NULL,
    description TEXT,
    occurred_at TIMESTAMP NOT NULL,
    resolved_at TIMESTAMP,
    resolution TEXT
);

CREATE INDEX idx_instance_incidents_domain ON instance_incidents(domain, occurred_at DESC);

-- インスタンス関連インデックス
CREATE INDEX idx_instance_policies_active ON instance_policies(is_active, policy_type) WHERE is_active = true;
CREATE INDEX idx_instance_policies_expires ON instance_policies(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX idx_instance_reputations_score ON instance_reputations(reputation_score, last_incident_at);
CREATE INDEX idx_instance_reputations_spam ON instance_reputations(spam_score DESC) WHERE spam_score > 50;

-- インスタンス制約
ALTER TABLE instance_reputations ADD CONSTRAINT check_reputation_scores 
    CHECK (spam_score >= 0 AND spam_score <= 100 AND reputation_score >= 0 AND reputation_score <= 100);
```

### 異議申し立て

```sql
-- 異議申し立て
CREATE TABLE appeals (
    appeal_id UUID PRIMARY KEY,
    action_id UUID REFERENCES moderation_actions(action_id),
    appellant_user_id UUID NOT NULL,
    appeal_reason TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'reviewing', 'upheld', 'overturned', 'dismissed')),
    priority INT DEFAULT 0,
    created_at TIMESTAMP NOT NULL,
    deadline_at TIMESTAMP NOT NULL,
    assigned_to UUID,
    reviewed_at TIMESTAMP,
    reviewed_by UUID,
    review_note TEXT,
    outcome_reason TEXT
);

-- 異議申し立て証拠
CREATE TABLE appeal_evidences (
    evidence_id UUID PRIMARY KEY,
    appeal_id UUID REFERENCES appeals(appeal_id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    supporting_data JSONB,
    submitted_at TIMESTAMP NOT NULL
);

-- エスカレーション履歴
CREATE TABLE escalations (
    escalation_id UUID PRIMARY KEY,
    source_type TEXT NOT NULL CHECK (source_type IN ('report', 'appeal')),
    source_id UUID NOT NULL,
    escalated_from UUID NOT NULL,
    escalated_to UUID NOT NULL,
    escalation_reason TEXT NOT NULL,
    urgency TEXT NOT NULL CHECK (urgency IN ('low', 'medium', 'high', 'critical')),
    escalated_at TIMESTAMP NOT NULL,
    resolved_at TIMESTAMP,
    resolution_note TEXT
);

-- 異議申し立て関連インデックス
CREATE INDEX idx_appeals_status ON appeals(status, deadline_at) WHERE status IN ('pending', 'reviewing');
CREATE INDEX idx_appeals_appellant ON appeals(appellant_user_id, created_at DESC);
CREATE INDEX idx_appeals_assigned ON appeals(assigned_to, status) WHERE assigned_to IS NOT NULL;
CREATE INDEX idx_escalations_source ON escalations(source_type, source_id);
CREATE INDEX idx_escalations_pending ON escalations(urgency, escalated_at) WHERE resolved_at IS NULL;
```

### モデレーションキュー

```sql
-- モデレーションキュー
CREATE TABLE moderation_queue (
    queue_id UUID PRIMARY KEY,
    item_type TEXT NOT NULL CHECK (item_type IN ('report', 'appeal', 'auto_flagged')),
    item_id UUID NOT NULL,
    priority INT NOT NULL,
    category TEXT NOT NULL,
    assigned_to UUID,
    status TEXT NOT NULL CHECK (status IN ('pending', 'assigned', 'in_progress', 'completed')),
    created_at TIMESTAMP NOT NULL,
    assigned_at TIMESTAMP,
    completed_at TIMESTAMP,
    sla_deadline TIMESTAMP,
    UNIQUE(item_type, item_id)
);

CREATE INDEX idx_queue_priority ON moderation_queue(status, priority DESC, created_at) WHERE status IN ('pending', 'assigned');
CREATE INDEX idx_queue_assigned ON moderation_queue(assigned_to, status) WHERE assigned_to IS NOT NULL;
CREATE INDEX idx_queue_sla_deadline ON moderation_queue(sla_deadline) WHERE sla_deadline IS NOT NULL AND status != 'completed';
```

### 監査ログ・追跡可能性

```sql
-- モデレーション監査ログ（コンプライアンス対応）
CREATE TABLE moderation_logs (
    log_id UUID PRIMARY KEY,
    event_type TEXT NOT NULL CHECK (event_type IN (
        'report_created', 'report_assigned', 'report_resolved', 'report_escalated',
        'action_executed', 'action_reverted', 'action_expired',
        'appeal_created', 'appeal_assigned', 'appeal_resolved',
        'filter_applied', 'filter_updated', 'filter_disabled',
        'policy_created', 'policy_updated', 'policy_expired',
        'user_warned', 'user_suspended', 'user_banned', 'content_removed'
    )),
    entity_type TEXT NOT NULL CHECK (entity_type IN ('report', 'action', 'appeal', 'filter', 'policy', 'user', 'content')),
    entity_id UUID NOT NULL,
    actor_type TEXT NOT NULL CHECK (actor_type IN ('user', 'moderator', 'admin', 'system', 'ml_classifier')),
    actor_id UUID, -- NULLの場合はシステム実行
    action_details JSONB NOT NULL,
    previous_state JSONB, -- 変更前の状態（変更系のイベントの場合）
    new_state JSONB, -- 変更後の状態（変更系のイベントの場合）
    ip_address INET, -- プライバシー考慮：必要な場合のみ記録
    user_agent TEXT, -- プライバシー考慮：ハッシュ化推奨
    session_id TEXT, -- セッション追跡用
    trace_id TEXT, -- 分散トレーシング用
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    retention_until TIMESTAMP NOT NULL DEFAULT (CURRENT_TIMESTAMP + INTERVAL '7 years') -- 法定保持期間対応
);

-- パーティショニング設定（月次）
CREATE TABLE moderation_logs_y2025m01 PARTITION OF moderation_logs
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE moderation_logs_y2025m02 PARTITION OF moderation_logs
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
-- 以下同様に月次パーティション作成...

-- 監査ログ用インデックス
CREATE INDEX idx_moderation_logs_entity ON moderation_logs(entity_type, entity_id, created_at DESC);
CREATE INDEX idx_moderation_logs_actor ON moderation_logs(actor_type, actor_id, created_at DESC);
CREATE INDEX idx_moderation_logs_event ON moderation_logs(event_type, created_at DESC);
CREATE INDEX idx_moderation_logs_retention ON moderation_logs(retention_until) WHERE retention_until <= CURRENT_TIMESTAMP;
CREATE INDEX idx_moderation_logs_trace ON moderation_logs(trace_id) WHERE trace_id IS NOT NULL;

-- プライバシー保護のためのマスキング関数
CREATE OR REPLACE FUNCTION mask_sensitive_data(log_data JSONB) RETURNS JSONB AS $$
BEGIN
    -- IPアドレスの部分マスキング（例：192.168.1.xxx）
    -- 個人情報の除去・ハッシュ化
    RETURN jsonb_strip_nulls(log_data);
END;
$$ LANGUAGE plpgsql;

-- 自動パーティション作成関数
CREATE OR REPLACE FUNCTION create_monthly_partition(table_name TEXT, start_date DATE) RETURNS VOID AS $$
DECLARE
    partition_name TEXT;
    end_date DATE;
BEGIN
    partition_name := table_name || '_y' || EXTRACT(YEAR FROM start_date) || 'm' || LPAD(EXTRACT(MONTH FROM start_date)::TEXT, 2, '0');
    end_date := start_date + INTERVAL '1 month';
    
    EXECUTE format('CREATE TABLE %I PARTITION OF %I FOR VALUES FROM (%L) TO (%L)',
                   partition_name, table_name, start_date, end_date);
    
    EXECUTE format('CREATE INDEX %I ON %I(created_at DESC)', 
                   'idx_' || partition_name || '_created_at', partition_name);
END;
$$ LANGUAGE plpgsql;
```

### 6.3. フィルタリングエンジン

### 処理フロー

```
1. コンテンツ受信
   ↓
2. 前処理
   ├─ テキスト正規化
   ├─ トークン化
   └─ 言語検出
   ↓
3. 並列フィルター実行
   ├─ NGワードマッチング（Trie構造）
   ├─ 正規表現パターン（compiled regex）
   ├─ MLスコアリング（TensorFlow/PyTorch）
   ├─ ドメインチェック（Bloom Filter）
   └─ コンテキスト分析
   ↓
4. スコア集計
   ├─ 重み付け平均
   ├─ 閾値判定
   └─ 信頼度計算
   ↓
5. アクション決定
   ├─ 自動アクション実行
   ├─ キュー追加
   └─ ログ記録
```

### MLクラシファイア設計

```go
type MLClassifier interface {
    Classify(content string) (*Classification, error)
    UpdateModel(modelPath string) error
    GetConfidence() float64
}

type Classification struct {
    Category      string   // spam, harassment, violence, etc
    Confidence    float64  // 0.0 - 1.0
    SubCategories []string // 詳細カテゴリ
    Language      string   // 検出言語
    Explanation   string   // 判定理由
}
```

### キャッシュ戦略

```
# フィルタールールキャッシュ
filters:active -> List of active filters (sorted by priority)
TTL: 5分

# NGワードキャッシュ（Trie構造）
ngwords:trie:{lang} -> Serialized Trie structure
TTL: 10分

# コンパイル済み正規表現キャッシュ
regex:compiled:{filter_id} -> Compiled regex pattern
TTL: 30分

# インスタンスポリシーキャッシュ
instance:policy:{domain} -> Policy details
TTL: 30分

# インスタンスレピュテーションキャッシュ
instance:reputation:{domain} -> Reputation score
TTL: 1時間

# モデレーション履歴キャッシュ
user:violations:{user_id} -> Recent violations (last 30 days)
TTL: 1時間

# 通報者信頼度キャッシュ
reporter:credibility:{user_id} -> Credibility score
TTL: 6時間

# MLモデル推論キャッシュ
ml:inference:{content_hash} -> Classification result
TTL: 24時間

# モデレーションキューカウント
queue:count:{category} -> Queue size by category
TTL: 1分
```

### 6.4. バッチ処理

### 定期処理

```yaml
# 優先度再計算（5分ごと）
priority_recalculation:
  interval: 5m
  tasks:
    - 通報集約の更新
    - キュー優先度の再計算
    - SLA期限のチェック

# 期限切れ処理（1時間ごと）
expiration_processing:
  interval: 1h
  tasks:
    - 一時停止の自動解除
    - 期限切れポリシーの無効化
    - 古い異議申し立ての自動却下

# 統計集計（1時間ごと）
statistics_aggregation:
  interval: 1h
  tasks:
    - モデレーション統計の集計
    - モデレーター活動の集計
    - 違反トレンドの分析

# レピュテーション更新（6時間ごと）
reputation_update:
  interval: 6h
  tasks:
    - インスタンスレピュテーションの再計算
    - 通報者信頼度の更新
    - フィルター効果の評価

# クリーンアップ（日次）
daily_cleanup:
  schedule: "0 3 * * *"  # 毎日3:00 AM
  tasks:
    - 古いログのアーカイブ
    - 処理済み通報の圧縮
    - キャッシュの最適化

# コンプライアンスレポート（月次）
compliance_report:
  schedule: "0 0 1 * *"  # 毎月1日
  tasks:
    - 月次統計レポート生成
    - 法的要求対応レポート
    - トレンド分析レポート
```

### 6.5. 外部サービス連携

### 画像認識API

```go
type ImageModerationAPI interface {
    CheckImage(ctx context.Context, imageURL string) (*ImageCheckResult, error)
    CheckBatch(ctx context.Context, imageURLs []string) ([]*ImageCheckResult, error)
}

type ImageCheckResult struct {
    ImageURL       string
    IsAdult        bool
    AdultScore     float64
    IsViolent      bool
    ViolenceScore  float64
    IsSpam         bool
    SpamScore      float64
    Categories     []string
    Confidence     float64
    ProcessingTime time.Duration
}

// 実装例: Google Vision API, AWS Rekognition, Azure Content Moderator
```

### テキスト分類API

```go
type TextClassificationAPI interface {
    ClassifyText(ctx context.Context, text string) (*TextClassification, error)
    ClassifyBatch(ctx context.Context, texts []string) ([]*TextClassification, error)
}

type TextClassification struct {
    Text           string
    Category       string   // spam, harassment, hate_speech, etc
    SubCategories  []string
    Confidence     float64
    Language       string
    Sentiment      float64  // -1.0 (negative) to 1.0 (positive)
    Toxicity       float64  // 0.0 to 1.0
    Keywords       []string // 検出されたキーワード
}
```

### 6.6. セキュリティ設計

### 権限管理

```yaml
roles:
  viewer:
    - view_reports
    - view_statistics
    
  junior_moderator:
    - inherit: viewer
    - process_reports
    - issue_warnings
    - delete_content
    
  senior_moderator:
    - inherit: junior_moderator
    - suspend_accounts
    - handle_appeals
    - manage_filters
    
  lead_moderator:
    - inherit: senior_moderator
    - ban_accounts
    - manage_policies
    - access_audit_logs
    - manage_moderators
```

### 監査ログ

```go
type AuditLog struct {
    LogID        string
    Timestamp    time.Time
    ActorID      string
    ActorRole    string
    Action       string
    TargetType   string
    TargetID     string
    Details      map[string]interface{}
    IPAddress    string
    UserAgent    string
    Hash         string // 改竄防止用ハッシュ
    PreviousHash string // ハッシュチェーン
}
```

### 6.7. パフォーマンス最適化

### 並列処理

```go
// フィルター並列実行
type ParallelFilterExecutor struct {
    workers   int
    filters   []ContentFilter
    resultsCh chan FilterResult
}

// バッチ処理最適化
type BatchProcessor struct {
    batchSize     int
    maxConcurrent int
    timeout       time.Duration
}
```

### インデックス

```sql
-- 通報最適化
CREATE INDEX idx_reports_status_priority ON reports(status, priority DESC) WHERE status IN ('pending', 'reviewing');
CREATE INDEX idx_reports_target ON reports(target_type, target_id);
CREATE INDEX idx_reports_reporter ON reports(reporter_user_id, created_at DESC);
CREATE INDEX idx_report_aggregations ON report_aggregations(aggregated_priority DESC);

-- アクション最適化
CREATE INDEX idx_moderation_actions_target ON moderation_actions(target_type, target_id, executed_at DESC);
CREATE INDEX idx_moderation_actions_active ON moderation_actions(expires_at) WHERE is_active = true;

-- フィルター最適化
CREATE INDEX idx_filter_logs_created ON filter_logs(created_at DESC);
CREATE INDEX idx_filter_logs_content ON filter_logs(content_type, content_id);

-- 異議申し立て最適化
CREATE INDEX idx_appeals_status ON appeals(status, priority DESC) WHERE status IN ('pending', 'reviewing');
CREATE INDEX idx_appeals_deadline ON appeals(deadline_at) WHERE status = 'pending';

-- キュー最適化
CREATE INDEX idx_queue_sla ON moderation_queue(sla_deadline) WHERE status != 'completed';
```

## 7. Endpoints (API) - 運用メトリクス

### 7.8. メトリクス

```yaml
performance_metrics:
  - report_processing_time_p50
  - report_processing_time_p95
  - report_processing_time_p99
  - filter_execution_time
  - ml_inference_time
  - queue_wait_time
  - sla_compliance_rate

accuracy_metrics:
  - spam_detection_precision
  - spam_detection_recall
  - false_positive_rate
  - appeal_overturn_rate
  - moderator_agreement_rate

volume_metrics:
  - reports_per_minute
  - actions_per_hour
  - appeals_per_day
  - filter_matches_per_hour
  - queue_size_by_category

efficiency_metrics:
  - auto_moderation_rate
  - moderator_productivity
  - average_resolution_time
  - escalation_rate
```

### アラート

```yaml
critical_alerts:
  - queue_size > 10000
  - sla_breach_rate > 5%
  - false_positive_rate > 10%
  - ml_service_down
  - database_connection_pool_exhausted

warning_alerts:
  - report_spike (3x normal volume)
  - processing_delay > 1 hour
  - moderator_disagreement > 20%
  - cache_hit_rate < 50%
  - api_error_rate > 1%

info_alerts:
  - new_violation_pattern_detected
  - filter_effectiveness_degraded
  - instance_reputation_changed
  - compliance_report_ready
```

## 8. Data Design (データ設計)

### 8.1. Domain Model (ドメインモデル)

#### Report Aggregate (通報集約)
```go
type Report struct {
    reportID     ReportID
    reporterID   UserID
    target       ReportTarget
    reason       ReportReason
    description  string
    status       ReportStatus
    priority     int
    assignedTo   *ModeratorID
    createdAt    time.Time
    evidence     []ReportEvidence
}

func (r *Report) AssignModerator(moderatorID ModeratorID) error {
    if r.status != ReportStatusPending {
        return ErrReportNotPending
    }
    r.assignedTo = &moderatorID
    r.status = ReportStatusReviewing
    return nil
}

func (r *Report) Resolve(resolution ReportResolution, moderatorID ModeratorID) error {
    if r.assignedTo == nil || *r.assignedTo != moderatorID {
        return ErrUnauthorizedModerator
    }
    r.status = ReportStatusResolved
    r.resolvedAt = time.Now()
    r.resolution = resolution
    return nil
}
```

#### ModerationAction Aggregate (モデレーションアクション集約)
```go
type ModerationAction struct {
    actionID    ActionID
    actionType  ActionType
    target      ActionTarget
    moderatorID ModeratorID
    reason      string
    severity    ActionSeverity
    executedAt  time.Time
    expiresAt   *time.Time
    isActive    bool
    reportIDs   []ReportID
}

func (ma *ModerationAction) Execute() error {
    if ma.isActive {
        return ErrActionAlreadyActive
    }
    ma.executedAt = time.Now()
    ma.isActive = true
    return nil
}

func (ma *ModerationAction) Revert(reason string, moderatorID ModeratorID) error {
    if !ma.isActive {
        return ErrActionNotActive
    }
    ma.isActive = false
    ma.revertedAt = time.Now()
    ma.revertedBy = moderatorID
    ma.revertReason = reason
    return nil
}
```

#### ContentFilter Aggregate (コンテンツフィルター集約)
```go
type ContentFilter struct {
    filterID     FilterID
    filterName   string
    filterType   FilterType
    conditions   []FilterCondition
    action       FilterAction
    priority     int
    isActive     bool
    effectiveness float64
}

func (cf *ContentFilter) ApplyFilter(content string) (*FilterResult, error) {
    if !cf.isActive {
        return nil, ErrFilterInactive
    }
    
    result := &FilterResult{
        FilterID:   cf.filterID,
        Matched:    false,
        Confidence: 0.0,
    }
    
    for _, condition := range cf.conditions {
        if match, confidence := condition.Evaluate(content); match {
            result.Matched = true
            result.Confidence = max(result.Confidence, confidence)
            result.MatchedConditions = append(result.MatchedConditions, condition)
        }
    }
    
    return result, nil
}
```

#### ModerationCase Aggregate (モデレーションケース集約)
```go
type ModerationCase struct {
    caseID              CaseID
    reports             []Report
    caseStatus          CaseStatus
    primaryModerator    *ModeratorID
    secondaryModerators []ModeratorID
    overallPriority     int
    overallSeverity     Severity
    aiConsentStatus     ConsentStatus
    createdAt           time.Time
    updatedAt           time.Time
}

func (mc *ModerationCase) AddRelatedReport(report Report) error {
    // 同一対象への通報か確認
    if !mc.isRelatedTarget(report.target) {
        return ErrUnrelatedReport
    }
    mc.reports = append(mc.reports, report)
    mc.recalculatePriority()
    mc.updatedAt = time.Now()
    return nil
}

func (mc *ModerationCase) ExecuteConsistentAction(action ModerationAction) error {
    // 全ての関連通報に対して一貫したアクションを実行
    for _, report := range mc.reports {
        report.status = ReportStatusResolved
    }
    mc.caseStatus = CaseStatusResolved
    return nil
}
```

#### CommunityVote Aggregate (コミュニティ投票集約)
```go
type CommunityVote struct {
    voteID          VoteID
    targetType      string
    targetID        string
    votes           []Vote
    voteResult      VoteResult
    minimumVotes    int
    votingDeadline  time.Time
}

type Vote struct {
    voterID     UserID
    voteType    VoteType // approve, reject, unsure
    trustLevel  int
    voteWeight  float64
    votedAt     time.Time
}

func (cv *CommunityVote) AddVote(voterID UserID, voteType VoteType, trustLevel int) error {
    if cv.hasVoted(voterID) {
        return ErrAlreadyVoted
    }
    if time.Now().After(cv.votingDeadline) {
        return ErrVotingClosed
    }
    
    weight := cv.calculateWeight(trustLevel)
    vote := Vote{
        voterID:    voterID,
        voteType:   voteType,
        trustLevel: trustLevel,
        voteWeight: weight,
        votedAt:    time.Now(),
    }
    cv.votes = append(cv.votes, vote)
    cv.updateResult()
    return nil
}
```

#### TrustLevel Aggregate (信頼レベル集約)
```go
type TrustLevel struct {
    userID              UserID
    level               int // 0-3
    levelName           string
    permissions         []Permission
    reportsAccuracy     float64
    helpfulVotes        int
    decisionsAccuracy   float64
    lastActivityAt      time.Time
}

func (tl *TrustLevel) PromoteLevel() error {
    if tl.level >= 3 {
        return ErrMaxLevelReached
    }
    if !tl.meetsPromotionCriteria() {
        return ErrPromotionCriteriaNotMet
    }
    tl.level++
    tl.updatePermissions()
    return nil
}

func (tl *TrustLevel) DemoteLevel(reason string) error {
    if tl.level <= 0 {
        return ErrMinLevelReached
    }
    tl.level--
    tl.updatePermissions()
    return nil
}
```

#### Appeal Aggregate (異議申し立て集約)
```go
type Appeal struct {
    appealID        AppealID
    actionID        ActionID
    appellantID     UserID
    appealReason    string
    status          AppealStatus
    priority        int
    createdAt       time.Time
    deadlineAt      time.Time
    assignedTo      *ModeratorID
    reviewedAt      *time.Time
    reviewedBy      *ModeratorID
    outcome         *AppealOutcome
    evidence        []AppealEvidence
}

func (a *Appeal) AssignReviewer(moderatorID ModeratorID) error {
    if a.status != AppealStatusPending {
        return ErrAppealNotPending
    }
    a.assignedTo = &moderatorID
    a.status = AppealStatusReviewing
    return nil
}

func (a *Appeal) Resolve(outcome AppealOutcome, moderatorID ModeratorID, note string) error {
    if a.assignedTo == nil || *a.assignedTo != moderatorID {
        return ErrUnauthorizedModerator
    }
    now := time.Now()
    a.reviewedAt = &now
    a.reviewedBy = &moderatorID
    a.outcome = &outcome
    a.reviewNote = note
    a.status = AppealStatusResolved
    return nil
}
```

### 8.2. Database Schema Extensions
```sql
-- 通報集約テーブル（既存のreportsテーブル拡張）
ALTER TABLE reports 
ADD COLUMN report_aggregation_id UUID,
ADD COLUMN escalation_level INT DEFAULT 0,
ADD COLUMN sla_deadline TIMESTAMP,
ADD COLUMN auto_flagged BOOLEAN DEFAULT false;

-- モデレーションワークフロー
CREATE TABLE moderation_workflows (
    workflow_id UUID PRIMARY KEY,
    workflow_name TEXT NOT NULL,
    trigger_conditions JSONB NOT NULL,
    action_sequence JSONB NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP NOT NULL
);

-- フィルター性能メトリクス
CREATE TABLE filter_metrics (
    metric_id UUID PRIMARY KEY,
    filter_id UUID REFERENCES content_filters(filter_id),
    measurement_date DATE NOT NULL,
    true_positives INT DEFAULT 0,
    false_positives INT DEFAULT 0,
    true_negatives INT DEFAULT 0,
    false_negatives INT DEFAULT 0,
    precision_score FLOAT,
    recall_score FLOAT,
    f1_score FLOAT
);
```

### 8.3. Cache Schema Extensions
```
# モデレーションキューキャッシュ
queue:pending:{category} -> Sorted Set (score: priority, member: report_id)
queue:assigned:{moderator_id} -> List of assigned report IDs
queue:sla_alerts -> Sorted Set (score: deadline timestamp, member: report_id)

# フィルター結果キャッシュ
filter:result:{content_hash} -> FilterResult JSON (TTL: 1 hour)
filter:ml_cache:{model_version}:{content_hash} -> ML classification (TTL: 24 hours)

# レピュテーション計算キャッシュ
reputation:user_violations:{user_id} -> Recent violations summary (TTL: 6 hours)
reputation:instance_stats:{domain} -> Instance statistics (TTL: 1 hour)
```

## 11. エラーハンドリング戦略

> **注意:** エラーコードは[共通エラーコード標準](../common/errors/error-codes.md)に準拠します。このサービスではプレフィックス `MOD` を使用します。

### エラーコード体系

本サービスは、Avionプラットフォーム標準のエラーコード体系に準拠します。

- **命名規則**: `[SERVICE]_[LAYER]_[ERROR_TYPE]`形式
- **エラーカタログ**: [error-catalog.md](./error-catalog.md)
- **実装ガイド**: [共通エラー実装ガイド](../common/errors/implementation-guide.md)
- **標準仕様**: [エラーコード標準化ガイドライン](../common/errors/error-standards.md)

詳細なエラーコード定義とマッピングについては、上記のドキュメントを参照してください。

### 11.1. モデレーション固有エラーカテゴリ

#### Domain Errors (ドメインエラー)
```go
// モデレーションビジネスルール違反エラー
var (
    ErrReportDuplicate          = NewDomainError("REPORT_DUPLICATE", "24時間以内の同一対象への重複通報")
    ErrAppealDeadlineExpired    = NewDomainError("APPEAL_DEADLINE_EXPIRED", "異議申し立て期限が過ぎています")
    ErrModerationUnauthorized   = NewDomainError("MODERATION_UNAUTHORIZED", "モデレーション権限が不足しています")
    ErrActionNotReversible      = NewDomainError("ACTION_NOT_REVERSIBLE", "このアクションは取り消しできません")
    ErrFilterPriorityConflict   = NewDomainError("FILTER_PRIORITY_CONFLICT", "フィルター優先度が競合しています")
    ErrInstanceSelfModeration   = NewDomainError("INSTANCE_SELF_MODERATION", "自インスタンスはモデレーション対象外です")
    ErrEscalationRequired       = NewDomainError("ESCALATION_REQUIRED", "上級モデレーターへのエスカレーションが必要です")
)

type ModerationDomainError struct {
    Code        string                 `json:"code"`
    Message     string                 `json:"message"`
    Details     map[string]interface{} `json:"details,omitempty"`
    ActionID    *string               `json:"action_id,omitempty"`
    ReportID    *string               `json:"report_id,omitempty"`
    Severity    string                 `json:"severity"`
    Retryable   bool                  `json:"retryable"`
}
```

#### Infrastructure Errors (インフラエラー)
```go
// モデレーション基盤サービスエラー
var (
    ErrMLClassifierUnavailable = NewInfraError("ML_CLASSIFIER_UNAVAILABLE", "機械学習分類器が利用できません", true)
    ErrImageModerationTimeout  = NewInfraError("IMAGE_MODERATION_TIMEOUT", "画像解析がタイムアウトしました", true)
    ErrAuditLogCorruption     = NewInfraError("AUDIT_LOG_CORRUPTION", "監査ログの改竄が検出されました", false)
    ErrQueueServiceDown       = NewInfraError("QUEUE_SERVICE_DOWN", "モデレーションキューサービスが停止しています", true)
    ErrNotificationFailed     = NewInfraError("NOTIFICATION_FAILED", "モデレーション結果の通知に失敗しました", true)
)

type ModerationInfraError struct {
    Code         string    `json:"code"`
    Message      string    `json:"message"`
    Retryable    bool      `json:"retryable"`
    ServiceName  string    `json:"service_name"`
    ErrorTime    time.Time `json:"error_time"`
    RetryAfter   *time.Duration `json:"retry_after,omitempty"`
    Cause        error     `json:"cause,omitempty"`
}
```

### 11.2. エスカレーション失敗ハンドリング

#### エスカレーション障害時の対応
```go
type EscalationErrorHandler struct {
    fallbackModerator ModeratorID
    escalationQueue   EscalationQueue
    alertService      AlertService
}

func (h *EscalationErrorHandler) HandleEscalationFailure(
    ctx context.Context, 
    report *Report, 
    originalError error,
) error {
    // 1. エスカレーション失敗をログ記録
    h.logEscalationFailure(ctx, report, originalError)
    
    // 2. 緊急度に基づく代替処理
    switch report.Priority() {
    case PriorityUrgent:
        // 最高管理者に即座にエスカレート
        return h.escalateToAdmin(ctx, report)
        
    case PriorityHigh:
        // フォールバックモデレーターに割り当て
        return h.assignToFallback(ctx, report)
        
    default:
        // キューに戻して再試行
        return h.requeueWithDelay(ctx, report, 30*time.Minute)
    }
}

func (h *EscalationErrorHandler) escalateToAdmin(ctx context.Context, report *Report) error {
    adminModerators := h.getAdminModerators()
    if len(adminModerators) == 0 {
        // 緊急アラート送信
        h.alertService.SendCriticalAlert("NO_ADMIN_MODERATORS_AVAILABLE")
        return ErrNoAdminModerators
    }
    
    selectedAdmin := h.selectLeastBusyAdmin(adminModerators)
    return report.EscalateTo(selectedAdmin, "システムエスカレーション失敗による緊急割り当て")
}
```

### 11.3. ML分類器フォールバック戦略

#### 機械学習サービス障害時の代替処理
```go
type MLClassifierWithFallback struct {
    primaryML   MLClassifier
    secondaryML MLClassifier
    ruleBasedML RuleBasedClassifier
    circuitBreaker *CircuitBreaker
}

func (ml *MLClassifierWithFallback) ClassifyContent(
    ctx context.Context, 
    content *Content,
) (*Classification, error) {
    // プライマリML分類器試行
    if classification, err := ml.tryPrimaryClassifier(ctx, content); err == nil {
        return classification, nil
    }
    
    // セカンダリML分類器試行
    if classification, err := ml.trySecondaryClassifier(ctx, content); err == nil {
        classification.Confidence *= 0.9 // 信頼度を若干下げる
        return classification, nil
    }
    
    // ルールベース分類器にフォールバック
    classification := ml.ruleBasedML.Classify(content)
    classification.Confidence *= 0.7 // さらに信頼度を下げる
    classification.FallbackUsed = true
    
    // 分類精度低下アラート
    ml.sendFallbackAlert("ML_CLASSIFIER_DEGRADED")
    
    return classification, nil
}

func (ml *MLClassifierWithFallback) tryPrimaryClassifier(
    ctx context.Context, 
    content *Content,
) (*Classification, error) {
    return ml.circuitBreaker.Execute(func() (*Classification, error) {
        ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
        defer cancel()
        
        return ml.primaryML.Classify(ctx, content)
    })
}
```

## 12. 構造化ロギング戦略

### 12.1. モデレーションアクションログ

#### 標準ログフォーマット
```go
type ModerationActionLog struct {
    Timestamp    time.Time            `json:"timestamp"`
    Level        string               `json:"level"`
    Service      string               `json:"service"`
    TraceID      string               `json:"trace_id"`
    SpanID       string               `json:"span_id"`
    
    // モデレーション固有フィールド
    ActionType   string               `json:"action_type"`
    ActionID     string               `json:"action_id"`
    ReportID     *string              `json:"report_id,omitempty"`
    ModeratorID  string               `json:"moderator_id"`
    TargetType   string               `json:"target_type"`
    TargetID     string               `json:"target_id"`
    Reason       string               `json:"reason"`
    Severity     string               `json:"severity"`
    
    // 実行結果
    ExecutionTime time.Duration       `json:"execution_time"`
    Success      bool                 `json:"success"`
    ErrorCode    *string              `json:"error_code,omitempty"`
    
    // コンテキスト情報
    UserAgent    string               `json:"user_agent,omitempty"`
    IPAddress    string               `json:"ip_address,omitempty"`
    
    // コンプライアンス情報
    LegalBasis   string               `json:"legal_basis,omitempty"`
    DataRetention string              `json:"data_retention,omitempty"`
    
    // 追加メタデータ
    Metadata     map[string]interface{} `json:"metadata,omitempty"`
}

// 構造化ログ出力例
{
  "timestamp": "2025-08-07T10:30:00Z",
  "level": "INFO",
  "service": "avion-moderation",
  "trace_id": "abc123def456",
  "span_id": "span789",
  "action_type": "suspend_account",
  "action_id": "action-uuid-123",
  "report_id": "report-uuid-456",
  "moderator_id": "mod-uuid-789",
  "target_type": "user",
  "target_id": "user-uuid-101",
  "reason": "ハラスメント行為の繰り返し",
  "severity": "high",
  "execution_time": "150ms",
  "success": true,
  "user_agent": "Mozilla/5.0...",
  "ip_address": "192.168.1.100",
  "legal_basis": "community_guidelines_violation",
  "data_retention": "2_years",
  "metadata": {
    "previous_violations": 3,
    "appeal_deadline": "2025-08-14T10:30:00Z"
  }
}
```

#### 監査証跡ログ
```go
type AuditTrailLog struct {
    AuditID      string               `json:"audit_id"`
    EventType    string               `json:"event_type"`
    Timestamp    time.Time            `json:"timestamp"`
    ActorID      string               `json:"actor_id"`
    ActorType    string               `json:"actor_type"`     // human, system, api
    Action       string               `json:"action"`
    ResourceType string               `json:"resource_type"`
    ResourceID   string               `json:"resource_id"`
    
    // 変更内容
    Changes      []ChangeRecord       `json:"changes"`
    
    // セキュリティ情報
    IPAddress    string               `json:"ip_address"`
    UserAgent    string               `json:"user_agent"`
    SessionID    string               `json:"session_id"`
    
    // 完全性保証
    HashValue    string               `json:"hash_value"`
    PreviousHash string               `json:"previous_hash"`
    
    // コンプライアンス
    RetentionPeriod string            `json:"retention_period"`
    LegalBasis      string            `json:"legal_basis"`
}

type ChangeRecord struct {
    Field     string      `json:"field"`
    OldValue  interface{} `json:"old_value"`
    NewValue  interface{} `json:"new_value"`
    ChangeType string     `json:"change_type"` // create, update, delete
}
```

### 12.2. パフォーマンスログ

#### モデレーション処理時間追跡
```go
type ModerationPerformanceLog struct {
    RequestID       string        `json:"request_id"`
    OperationType   string        `json:"operation_type"`
    StartTime       time.Time     `json:"start_time"`
    EndTime         time.Time     `json:"end_time"`
    Duration        time.Duration `json:"duration"`
    
    // 処理段階別時間
    Timings struct {
        Validation    time.Duration `json:"validation"`
        MLClassification time.Duration `json:"ml_classification"`
        RuleEvaluation  time.Duration `json:"rule_evaluation"`
        DatabaseWrite   time.Duration `json:"database_write"`
        EventPublishing time.Duration `json:"event_publishing"`
    } `json:"timings"`
    
    // リソース使用量
    ResourceUsage struct {
        MemoryPeak    int64 `json:"memory_peak_bytes"`
        CPUTime       time.Duration `json:"cpu_time"`
        DatabaseCalls int   `json:"database_calls"`
        CacheHits     int   `json:"cache_hits"`
        CacheMisses   int   `json:"cache_misses"`
    } `json:"resource_usage"`
    
    // 結果メトリクス
    Success         bool   `json:"success"`
    ErrorCode       string `json:"error_code,omitempty"`
    RecordsProcessed int   `json:"records_processed"`
}
```

### 12.3. セキュリティログ

#### 不審なアクティビティの検出
```go
type SecurityLog struct {
    SecurityEventID string    `json:"security_event_id"`
    EventType       string    `json:"event_type"`
    Severity        string    `json:"severity"`
    Timestamp       time.Time `json:"timestamp"`
    
    // 関与者情報
    ActorID         string `json:"actor_id"`
    ActorRole       string `json:"actor_role"`
    IPAddress       string `json:"ip_address"`
    UserAgent       string `json:"user_agent"`
    Location        string `json:"location,omitempty"`
    
    // セキュリティイベント詳細
    Description     string `json:"description"`
    ThreatIndicators []string `json:"threat_indicators"`
    
    // 対応アクション
    ActionTaken     string `json:"action_taken"`
    AlertSent       bool   `json:"alert_sent"`
    
    // 関連情報
    RelatedEvents   []string `json:"related_events"`
    RiskScore       float64  `json:"risk_score"`
}

// セキュリティイベント例
{
  "security_event_id": "sec-event-123",
  "event_type": "suspicious_mass_moderation",
  "severity": "high",
  "timestamp": "2025-08-07T14:20:00Z",
  "actor_id": "mod-uuid-456",
  "actor_role": "moderator",
  "ip_address": "203.0.113.100",
  "user_agent": "ModBot/1.0",
  "description": "1分間で50件の連続モデレーションアクション",
  "threat_indicators": [
    "rapid_successive_actions",
    "unusual_time_pattern",
    "automated_user_agent"
  ],
  "action_taken": "account_temporarily_suspended",
  "alert_sent": true,
  "risk_score": 8.5
}
```

## 9. Use Cases / Key Flows (主な使い方・処理の流れ)

### 6.1. 通報処理フロー

#### 通報受付と初期処理
1. **通報作成要求**
   - Gateway → CreateReportCommandHandler: gRPC Call
   - CreateReportCommandHandler: CreateReportCommandUseCaseを呼び出し
   - CreateReportCommandUseCase: ReportAggregate生成、重複チェック実行
   - ViolationDetectionService: 通報理由と対象コンテンツの自動評価
   - PriorityCalculationService: 通報者信頼度とコンテンツ履歴から優先度計算
   - ReportRepository: 通報データの永続化
   - ReportEventPublisher: `moderation.report.created` イベント発行

#### 自動フィルタリング処理
2. **コンテンツ自動評価**
   - ContentCreatedEventHandler: `content.created` イベント受信
   - FilterContentCommandUseCase: ContentFilter実行
   - FilterEngine: 並列フィルター処理（NGワード、正規表現、ML分類）
   - MLClassifier: 機械学習による有害コンテンツ判定
   - 閾値判定: 自動アクション実行 or モデレーションキュー追加
   - FilterEventPublisher: `moderation.content.filtered` イベント発行

#### モデレーター処理
3. **キュー取得と処理**
   - GetModerationQueueQueryHandler: 優先度順のキュー取得
   - AssignReportCommandHandler: 通報の担当者割り当て
   - GetReportDetailsQueryHandler: 通報詳細と証拠の取得
   - GetViolationContextQueryHandler: 対象ユーザーの違反履歴取得
   - ExecuteModerationActionCommandHandler: 判定とアクション実行
   - ModerationEventPublisher: `moderation.action.executed` イベント発行

### 6.2. 異議申し立てフロー

#### 異議申し立て作成
1. **申し立て受付**
   - User → CreateAppealCommandHandler: 異議申し立て作成
   - CreateAppealCommandUseCase: AppealAggregate生成、期限設定
   - AppealRepository: 異議申し立てデータ永続化
   - AppealEventPublisher: `moderation.appeal.created` イベント発行
   - NotificationService: モデレーターへの通知送信

#### 異議申し立てレビュー
2. **レビューと判定**
   - ReviewAppealCommandHandler: レビュー実行
   - ReviewAppealCommandUseCase: 証拠評価と判定
   - EscalationService: 複雑なケースのエスカレーション判断
   - RevertModerationActionCommandHandler: 必要に応じてアクション取り消し
   - AppealEventPublisher: `moderation.appeal.resolved` イベント発行

### 6.3. インスタンスポリシー管理フロー

#### ポリシー設定
1. **インスタンスレピュテーション評価**
   - ReputationUpdateJob: 定期的なレピュテーション計算
   - InstanceReputationAggregate: スパムスコア、違反率の更新
   - SetInstancePolicyCommandHandler: 自動ポリシー適用判断
   - InstancePolicyRepository: ポリシー設定の永続化
   - InstancePolicyEventPublisher: `moderation.instance.policy_applied` イベント発行

### 6.4. バッチ処理フロー

#### 定期メンテナンス
1. **優先度再計算（5分ごと）**
   - PriorityRecalculationJob: 通報集約とSLA期限チェック
   - ReportAggregate: 優先度値の更新
   - ModerationQueue: キュー順序の再編成

2. **期限切れ処理（1時間ごと）**
   - ExpirationProcessingJob: 一時停止の自動解除
   - ModerationActionAggregate: 期限切れアクションの無効化
   - AppealAggregate: 期限切れ異議申し立ての自動却下

## 8. Data Design (データ設計)

### 8.1. Domain Model (ドメインモデル)

#### Report Aggregate (通報集約)
```go
type Report struct {
    reportID     ReportID
    reporterID   UserID
    target       ReportTarget
    reason       ReportReason
    description  string
    status       ReportStatus
    priority     int
    assignedTo   *ModeratorID
    createdAt    time.Time
    evidence     []ReportEvidence
}

func (r *Report) AssignModerator(moderatorID ModeratorID) error {
    if r.status != ReportStatusPending {
        return ErrReportNotPending
    }
    r.assignedTo = &moderatorID
    r.status = ReportStatusReviewing
    return nil
}

func (r *Report) Resolve(resolution ReportResolution, moderatorID ModeratorID) error {
    if r.assignedTo == nil || *r.assignedTo != moderatorID {
        return ErrUnauthorizedModerator
    }
    r.status = ReportStatusResolved
    r.resolvedAt = time.Now()
    r.resolution = resolution
    return nil
}
```

#### ModerationAction Aggregate (モデレーションアクション集約)
```go
type ModerationAction struct {
    actionID    ActionID
    actionType  ActionType
    target      ActionTarget
    moderatorID ModeratorID
    reason      string
    severity    ActionSeverity
    executedAt  time.Time
    expiresAt   *time.Time
    isActive    bool
    reportIDs   []ReportID
}

func (ma *ModerationAction) Execute() error {
    if ma.isActive {
        return ErrActionAlreadyActive
    }
    ma.executedAt = time.Now()
    ma.isActive = true
    return nil
}

func (ma *ModerationAction) Revert(reason string, moderatorID ModeratorID) error {
    if !ma.isActive {
        return ErrActionNotActive
    }
    ma.isActive = false
    ma.revertedAt = time.Now()
    ma.revertedBy = moderatorID
    ma.revertReason = reason
    return nil
}
```

#### ContentFilter Aggregate (コンテンツフィルター集約)
```go
type ContentFilter struct {
    filterID     FilterID
    filterName   string
    filterType   FilterType
    conditions   []FilterCondition
    action       FilterAction
    priority     int
    isActive     bool
    effectiveness float64
}

func (cf *ContentFilter) ApplyFilter(content string) (*FilterResult, error) {
    if !cf.isActive {
        return nil, ErrFilterInactive
    }
    
    result := &FilterResult{
        FilterID:   cf.filterID,
        Matched:    false,
        Confidence: 0.0,
    }
    
    for _, condition := range cf.conditions {
        if match, confidence := condition.Evaluate(content); match {
            result.Matched = true
            result.Confidence = max(result.Confidence, confidence)
            result.MatchedConditions = append(result.MatchedConditions, condition)
        }
    }
    
    return result, nil
}
```

### 8.2. Infrastructure Model (インフラモデル)

#### Database Schema Extensions
```sql
-- 通報集約テーブル（既存のreportsテーブル拡張）
ALTER TABLE reports 
ADD COLUMN report_aggregation_id UUID,
ADD COLUMN escalation_level INT DEFAULT 0,
ADD COLUMN sla_deadline TIMESTAMP,
ADD COLUMN auto_flagged BOOLEAN DEFAULT false;

-- モデレーションワークフロー
CREATE TABLE moderation_workflows (
    workflow_id UUID PRIMARY KEY,
    workflow_name TEXT NOT NULL,
    trigger_conditions JSONB NOT NULL,
    action_sequence JSONB NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP NOT NULL
);

-- フィルター性能メトリクス
CREATE TABLE filter_metrics (
    metric_id UUID PRIMARY KEY,
    filter_id UUID REFERENCES content_filters(filter_id),
    measurement_date DATE NOT NULL,
    true_positives INT DEFAULT 0,
    false_positives INT DEFAULT 0,
    true_negatives INT DEFAULT 0,
    false_negatives INT DEFAULT 0,
    precision_score FLOAT,
    recall_score FLOAT,
    f1_score FLOAT
);
```

#### Cache Schema Extensions
```
# モデレーションキューキャッシュ
queue:pending:{category} -> Sorted Set (score: priority, member: report_id)
queue:assigned:{moderator_id} -> List of assigned report IDs
queue:sla_alerts -> Sorted Set (score: deadline timestamp, member: report_id)

# フィルター結果キャッシュ
filter:result:{content_hash} -> FilterResult JSON (TTL: 1 hour)
filter:ml_cache:{model_version}:{content_hash} -> ML classification (TTL: 24 hours)

# レピュテーション計算キャッシュ
reputation:user_violations:{user_id} -> Recent violations summary (TTL: 6 hours)
reputation:instance_stats:{domain} -> Instance statistics (TTL: 1 hour)
```

## 10. エラーハンドリング戦略

### 10.1. エラーカテゴリ

#### Domain Errors (ドメインエラー)
```go
// ビジネスルール違反エラー
var (
    ErrReportNotPending       = NewDomainError("REPORT_NOT_PENDING", "通報は処理待ち状態ではありません")
    ErrUnauthorizedModerator  = NewDomainError("UNAUTHORIZED_MODERATOR", "この通報を処理する権限がありません")
    ErrActionAlreadyActive    = NewDomainError("ACTION_ALREADY_ACTIVE", "モデレーションアクションは既に有効です")
    ErrFilterInactive         = NewDomainError("FILTER_INACTIVE", "フィルターが無効化されています")
    ErrDuplicateReport        = NewDomainError("DUPLICATE_REPORT", "同じ対象に対する重複通報です")
    ErrAppealDeadlineExpired  = NewDomainError("APPEAL_DEADLINE_EXPIRED", "異議申し立て期限が過ぎています")
)

type DomainError struct {
    Code    string `json:"code"`
    Message string `json:"message"`
    Details map[string]interface{} `json:"details,omitempty"`
}

func (e DomainError) Error() string {
    return fmt.Sprintf("%s: %s", e.Code, e.Message)
}
```

#### Infrastructure Errors (インフラエラー)
```go
// 外部サービス連携エラー
var (
    ErrDatabaseConnection     = NewInfraError("DB_CONNECTION_ERROR", "データベース接続エラー")
    ErrMLServiceUnavailable   = NewInfraError("ML_SERVICE_UNAVAILABLE", "機械学習サービスが利用できません")
    ErrRedisConnectionLost    = NewInfraError("REDIS_CONNECTION_LOST", "Redisサーバーとの接続が切断されました")
    ErrEventPublishFailed     = NewInfraError("EVENT_PUBLISH_FAILED", "イベント発行に失敗しました")
)

type InfraError struct {
    Code      string `json:"code"`
    Message   string `json:"message"`
    Retryable bool   `json:"retryable"`
    Cause     error  `json:"cause,omitempty"`
}
```

### 10.2. エラーハンドリング戦略

#### リトライ戦略
```go
type RetryConfig struct {
    MaxAttempts    int           `json:"max_attempts"`
    BaseDelay      time.Duration `json:"base_delay"`
    MaxDelay       time.Duration `json:"max_delay"`
    BackoffFactor  float64       `json:"backoff_factor"`
    RetryableErrors []string      `json:"retryable_errors"`
}

// 指数バックオフによるリトライ実装
func WithExponentialBackoff(config RetryConfig, operation func() error) error {
    var lastErr error
    
    for attempt := 1; attempt <= config.MaxAttempts; attempt++ {
        if err := operation(); err == nil {
            return nil
        } else {
            lastErr = err
            
            // リトライ可能エラーかチェック
            if !isRetryableError(err, config.RetryableErrors) {
                return err
            }
            
            if attempt < config.MaxAttempts {
                delay := calculateBackoffDelay(config, attempt)
                time.Sleep(delay)
            }
        }
    }
    
    return fmt.Errorf("operation failed after %d attempts: %w", config.MaxAttempts, lastErr)
}
```

#### サーキットブレーカー
```go
type CircuitBreakerConfig struct {
    FailureThreshold   int           `json:"failure_threshold"`
    RecoveryTimeout    time.Duration `json:"recovery_timeout"`
    SuccessThreshold   int           `json:"success_threshold"`
    MonitoringWindow   time.Duration `json:"monitoring_window"`
}

type CircuitBreaker struct {
    state           CircuitState
    failureCount    int
    successCount    int
    lastFailureTime time.Time
    config          CircuitBreakerConfig
}

// ML分類サービス用サーキットブレーカー
func (cb *CircuitBreaker) Execute(operation func() error) error {
    switch cb.state {
    case CircuitOpen:
        if time.Since(cb.lastFailureTime) > cb.config.RecoveryTimeout {
            cb.state = CircuitHalfOpen
            cb.successCount = 0
        } else {
            return ErrCircuitOpen
        }
    case CircuitHalfOpen:
        // リカバリ試行中
    case CircuitClosed:
        // 正常状態
    }
    
    err := operation()
    if err != nil {
        cb.onFailure()
    } else {
        cb.onSuccess()
    }
    
    return err
}
```

### 10.3. エラー監視とアラート

#### メトリクス収集
```go
type ErrorMetrics struct {
    TotalErrors     prometheus.CounterVec   // エラー総数（タイプ別）
    ErrorRate       prometheus.GaugeVec     // エラー率
    RetryAttempts   prometheus.HistogramVec // リトライ回数分布
    CircuitState    prometheus.GaugeVec     // サーキットブレーカー状態
}

func (em *ErrorMetrics) RecordError(errorType, operation string) {
    em.TotalErrors.WithLabelValues(errorType, operation).Inc()
}

func (em *ErrorMetrics) UpdateErrorRate(operation string, rate float64) {
    em.ErrorRate.WithLabelValues(operation).Set(rate)
}
```

#### アラート設定
```yaml
# Prometheus Alert Rules
groups:
  - name: moderation.errors
    rules:
      - alert: HighModerationErrorRate
        expr: rate(moderation_errors_total[5m]) > 0.1
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "高いモデレーションエラー率が検出されました"
          
      - alert: MLServiceCircuitOpen
        expr: moderation_circuit_state{service="ml_classifier"} == 1
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "ML分類サービスのサーキットブレーカーが開いています"
          
      - alert: ModerationQueueBacklog
        expr: moderation_queue_pending_reports > 10000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "モデレーションキューに大量の未処理通報があります"
```

## 12. ドメインオブジェクトとDBスキーマのマッピング

### 12.1. Aggregate Root マッピング

#### Report Aggregate ⇔ reports テーブル
```go
type ReportEntity struct {
    // Primary Key
    ReportID    string    `db:"report_id" json:"report_id"`
    
    // Basic Information
    ReporterID  string    `db:"reporter_user_id" json:"reporter_id"`
    TargetType  string    `db:"target_type" json:"target_type"`
    TargetID    string    `db:"target_id" json:"target_id"`
    Reason      string    `db:"reason" json:"reason"`
    Description *string   `db:"description" json:"description,omitempty"`
    
    // Status Management
    Status      string    `db:"status" json:"status"`
    Priority    int       `db:"priority" json:"priority"`
    AssignedTo  *string   `db:"assigned_to" json:"assigned_to,omitempty"`
    
    // Timestamps
    CreatedAt   time.Time  `db:"created_at" json:"created_at"`
    UpdatedAt   time.Time  `db:"updated_at" json:"updated_at"`
    ResolvedAt  *time.Time `db:"resolved_at" json:"resolved_at,omitempty"`
    
    // Additional Fields
    IsEscalated   bool      `db:"is_escalated" json:"is_escalated"`
    EscalatedTo   *string   `db:"escalated_to" json:"escalated_to,omitempty"`
    SLADeadline   *time.Time `db:"sla_deadline" json:"sla_deadline,omitempty"`
}

// Domain Object への変換
func (re *ReportEntity) ToDomain() (*Report, error) {
    reportID, err := ParseReportID(re.ReportID)
    if err != nil {
        return nil, fmt.Errorf("invalid report ID: %w", err)
    }
    
    target := ReportTarget{
        Type: TargetType(re.TargetType),
        ID:   re.TargetID,
    }
    
    report := &Report{
        reportID:    reportID,
        reporterID:  UserID(re.ReporterID),
        target:      target,
        reason:      ReportReason(re.Reason),
        description: re.Description,
        status:      ReportStatus(re.Status),
        priority:    re.Priority,
        createdAt:   re.CreatedAt,
        updatedAt:   re.UpdatedAt,
    }
    
    if re.AssignedTo != nil {
        moderatorID := ModeratorID(*re.AssignedTo)
        report.assignedTo = &moderatorID
    }
    
    return report, nil
}

// Domain Object からの変換
func NewReportEntity(report *Report) *ReportEntity {
    entity := &ReportEntity{
        ReportID:    string(report.reportID),
        ReporterID:  string(report.reporterID),
        TargetType:  string(report.target.Type),
        TargetID:    report.target.ID,
        Reason:      string(report.reason),
        Description: &report.description,
        Status:      string(report.status),
        Priority:    report.priority,
        CreatedAt:   report.createdAt,
        UpdatedAt:   report.updatedAt,
        IsEscalated: report.isEscalated,
    }
    
    if report.assignedTo != nil {
        assignedTo := string(*report.assignedTo)
        entity.AssignedTo = &assignedTo
    }
    
    return entity
}
```

#### ModerationAction Aggregate ⇔ moderation_actions テーブル
```go
type ModerationActionEntity struct {
    ActionID    string     `db:"action_id" json:"action_id"`
    ActionType  string     `db:"action_type" json:"action_type"`
    TargetType  string     `db:"target_type" json:"target_type"`
    TargetID    string     `db:"target_id" json:"target_id"`
    ModeratorID string     `db:"moderator_id" json:"moderator_id"`
    Reason      string     `db:"reason" json:"reason"`
    Details     *string    `db:"details" json:"details,omitempty"` // JSON
    Severity    string     `db:"severity" json:"severity"`
    ExecutedAt  time.Time  `db:"executed_at" json:"executed_at"`
    ExpiresAt   *time.Time `db:"expires_at" json:"expires_at,omitempty"`
    IsActive    bool       `db:"is_active" json:"is_active"`
    ReportIDs   []string   `db:"report_ids" json:"report_ids"` // PostgreSQL Array
}

func (mae *ModerationActionEntity) ToDomain() (*ModerationAction, error) {
    actionID, err := ParseActionID(mae.ActionID)
    if err != nil {
        return nil, fmt.Errorf("invalid action ID: %w", err)
    }
    
    target := ActionTarget{
        Type: TargetType(mae.TargetType),
        ID:   mae.TargetID,
    }
    
    var details map[string]interface{}
    if mae.Details != nil {
        if err := json.Unmarshal([]byte(*mae.Details), &details); err != nil {
            return nil, fmt.Errorf("failed to unmarshal details: %w", err)
        }
    }
    
    reportIDs := make([]ReportID, len(mae.ReportIDs))
    for i, rid := range mae.ReportIDs {
        reportIDs[i] = ReportID(rid)
    }
    
    return &ModerationAction{
        actionID:    actionID,
        actionType:  ActionType(mae.ActionType),
        target:      target,
        moderatorID: ModeratorID(mae.ModeratorID),
        reason:      mae.Reason,
        details:     details,
        severity:    ActionSeverity(mae.Severity),
        executedAt:  mae.ExecutedAt,
        expiresAt:   mae.ExpiresAt,
        isActive:    mae.IsActive,
        reportIDs:   reportIDs,
    }, nil
}
```

### 12.2. Entity マッピング

#### ReportEvidence Entity ⇔ report_evidences テーブル
```go
type ReportEvidenceEntity struct {
    EvidenceID   string                 `db:"evidence_id" json:"evidence_id"`
    ReportID     string                 `db:"report_id" json:"report_id"`
    EvidenceType string                 `db:"evidence_type" json:"evidence_type"`
    EvidenceData map[string]interface{} `db:"evidence_data" json:"evidence_data"` // JSONB
    CreatedAt    time.Time              `db:"created_at" json:"created_at"`
}

func (ree *ReportEvidenceEntity) ToDomain() *ReportEvidence {
    return &ReportEvidence{
        evidenceID:   EvidenceID(ree.EvidenceID),
        reportID:     ReportID(ree.ReportID),
        evidenceType: EvidenceType(ree.EvidenceType),
        data:         ree.EvidenceData,
        createdAt:    ree.CreatedAt,
    }
}
```

### 12.3. Value Object マッピング

#### 識別子の変換
```go
// ReportID Value Object
type ReportID string

func ParseReportID(s string) (ReportID, error) {
    if len(s) == 0 {
        return "", errors.New("report ID cannot be empty")
    }
    if _, err := uuid.Parse(s); err != nil {
        return "", fmt.Errorf("invalid UUID format: %w", err)
    }
    return ReportID(s), nil
}

func (id ReportID) String() string {
    return string(id)
}

// ActionSeverity Value Object
type ActionSeverity string

const (
    SeverityLow      ActionSeverity = "low"
    SeverityMedium   ActionSeverity = "medium"
    SeverityHigh     ActionSeverity = "high"
    SeverityCritical ActionSeverity = "critical"
)

func ParseActionSeverity(s string) (ActionSeverity, error) {
    severity := ActionSeverity(s)
    switch severity {
    case SeverityLow, SeverityMedium, SeverityHigh, SeverityCritical:
        return severity, nil
    default:
        return "", fmt.Errorf("invalid action severity: %s", s)
    }
}
```

### 12.4. Repository実装パターン

#### PostgreSQL Repository実装
```go
type PostgreSQLReportRepository struct {
    db     *sql.DB
    mapper *ReportMapper
}

func (r *PostgreSQLReportRepository) Create(ctx context.Context, report *Report) error {
    entity := r.mapper.ToEntity(report)
    
    tx, err := r.db.BeginTx(ctx, nil)
    if err != nil {
        return fmt.Errorf("failed to begin transaction: %w", err)
    }
    defer tx.Rollback()
    
    // Main report record
    query := `
        INSERT INTO reports (
            report_id, reporter_user_id, target_type, target_id, reason, description,
            status, priority, created_at, updated_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
    `
    
    _, err = tx.ExecContext(ctx, query,
        entity.ReportID, entity.ReporterID, entity.TargetType, entity.TargetID,
        entity.Reason, entity.Description, entity.Status, entity.Priority,
        entity.CreatedAt, entity.UpdatedAt,
    )
    if err != nil {
        return fmt.Errorf("failed to insert report: %w", err)
    }
    
    // Evidence records
    for _, evidence := range report.evidence {
        evidenceEntity := r.mapper.EvidenceToEntity(evidence)
        
        evidenceQuery := `
            INSERT INTO report_evidences (evidence_id, report_id, evidence_type, evidence_data, created_at)
            VALUES ($1, $2, $3, $4, $5)
        `
        
        evidenceData, _ := json.Marshal(evidenceEntity.EvidenceData)
        _, err = tx.ExecContext(ctx, evidenceQuery,
            evidenceEntity.EvidenceID, evidenceEntity.ReportID,
            evidenceEntity.EvidenceType, evidenceData, evidenceEntity.CreatedAt,
        )
        if err != nil {
            return fmt.Errorf("failed to insert evidence: %w", err)
        }
    }
    
    return tx.Commit()
}

func (r *PostgreSQLReportRepository) FindByID(ctx context.Context, id ReportID) (*Report, error) {
    query := `
        SELECT r.report_id, r.reporter_user_id, r.target_type, r.target_id, r.reason, r.description,
               r.status, r.priority, r.assigned_to, r.created_at, r.updated_at, r.resolved_at,
               r.is_escalated, r.escalated_to, r.sla_deadline
        FROM reports r
        WHERE r.report_id = $1
    `
    
    var entity ReportEntity
    row := r.db.QueryRowContext(ctx, query, string(id))
    err := row.Scan(
        &entity.ReportID, &entity.ReporterID, &entity.TargetType, &entity.TargetID,
        &entity.Reason, &entity.Description, &entity.Status, &entity.Priority,
        &entity.AssignedTo, &entity.CreatedAt, &entity.UpdatedAt, &entity.ResolvedAt,
        &entity.IsEscalated, &entity.EscalatedTo, &entity.SLADeadline,
    )
    if err != nil {
        if err == sql.ErrNoRows {
            return nil, ErrReportNotFound
        }
        return nil, fmt.Errorf("failed to query report: %w", err)
    }
    
    // Load evidence
    evidenceQuery := `
        SELECT evidence_id, evidence_type, evidence_data, created_at
        FROM report_evidences
        WHERE report_id = $1
        ORDER BY created_at
    `
    
    rows, err := r.db.QueryContext(ctx, evidenceQuery, string(id))
    if err != nil {
        return nil, fmt.Errorf("failed to query evidence: %w", err)
    }
    defer rows.Close()
    
    var evidences []*ReportEvidence
    for rows.Next() {
        var evidenceEntity ReportEvidenceEntity
        var evidenceDataJSON []byte
        
        err := rows.Scan(
            &evidenceEntity.EvidenceID, &evidenceEntity.EvidenceType,
            &evidenceDataJSON, &evidenceEntity.CreatedAt,
        )
        if err != nil {
            return nil, fmt.Errorf("failed to scan evidence: %w", err)
        }
        
        json.Unmarshal(evidenceDataJSON, &evidenceEntity.EvidenceData)
        evidenceEntity.ReportID = entity.ReportID
        
        evidences = append(evidences, evidenceEntity.ToDomain())
    }
    
    report, err := entity.ToDomain()
    if err != nil {
        return nil, err
    }
    
    report.evidence = evidences
    return report, nil
}
```

この設計により、ドメインオブジェクトとデータベーススキーマ間で明確な境界を保ちながら、効率的なデータ変換と永続化を実現します。

## 13. ドメインオブジェクトとDBスキーママッピング詳細

### 13.1. モデレーション固有のマッピング戦略

#### プライバシー保護マッピング戦略

```go
// プライバシー考慮したドメインオブジェクト設計
type SensitiveDataHandler interface {
    MaskPersonalData() interface{}
    HashIdentifiers() interface{}
    AnonymizeForAnalytics() interface{}
}

// 個人情報を含むレポートデータの保護
type PrivacyAwareReportEntity struct {
    ReportEntity
    
    // 個人情報保護フィールド
    ReporterIPHash    *string `db:"reporter_ip_hash" json:"-"` // JSON出力時除外
    DeviceFingerprint *string `db:"device_fingerprint" json:"-"`
    UserAgentHash     *string `db:"user_agent_hash" json:"-"`
    
    // GDPR対応
    DataRetentionPolicy string    `db:"data_retention_policy" json:"data_retention_policy"`
    ConsentTimestamp    time.Time `db:"consent_timestamp" json:"consent_timestamp"`
    DeletionScheduled   *time.Time `db:"deletion_scheduled" json:"deletion_scheduled,omitempty"`
}

func (p *PrivacyAwareReportEntity) MaskPersonalData() *PrivacyAwareReportEntity {
    masked := *p
    
    // IPアドレスの部分マスキング
    if p.ReporterIPHash != nil {
        maskedIP := maskIPAddress(*p.ReporterIPHash)
        masked.ReporterIPHash = &maskedIP
    }
    
    // 説明文から個人情報除去
    if p.Description != nil {
        cleaned := removePII(*p.Description)
        masked.Description = &cleaned
    }
    
    return &masked
}

func (p *PrivacyAwareReportEntity) AnonymizeForAnalytics() map[string]interface{} {
    return map[string]interface{}{
        "report_type":    p.Reason,
        "target_type":    p.TargetType,
        "priority":       p.Priority,
        "status":         p.Status,
        "created_month":  p.CreatedAt.Format("2006-01"),
        "resolution_time": calculateResolutionTime(p.CreatedAt, p.ResolvedAt),
        // 個人特定可能情報は除外
    }
}

// 監査ログ用の暗号化マッピング
type AuditLogEntity struct {
    LogID         string                 `db:"log_id" json:"log_id"`
    EventType     string                 `db:"event_type" json:"event_type"`
    EntityType    string                 `db:"entity_type" json:"entity_type"`
    EntityID      string                 `db:"entity_id" json:"entity_id"`
    ActorType     string                 `db:"actor_type" json:"actor_type"`
    ActorID       *string                `db:"actor_id" json:"actor_id,omitempty"`
    ActionDetails EncryptedJSON          `db:"action_details" json:"action_details"`
    PreviousState *EncryptedJSON         `db:"previous_state" json:"previous_state,omitempty"`
    NewState      *EncryptedJSON         `db:"new_state" json:"new_state,omitempty"`
    IPAddress     *EncryptedString       `db:"ip_address" json:"-"`
    UserAgent     *EncryptedString       `db:"user_agent" json:"-"`
    SessionID     *string                `db:"session_id" json:"session_id,omitempty"`
    TraceID       *string                `db:"trace_id" json:"trace_id,omitempty"`
    CreatedAt     time.Time              `db:"created_at" json:"created_at"`
    RetentionUntil time.Time             `db:"retention_until" json:"retention_until"`
}

// 暗号化されたJSONフィールド型
type EncryptedJSON struct {
    CipherText string `json:"cipher_text"`
    Algorithm  string `json:"algorithm"`
    KeyID      string `json:"key_id"`
}

func (ej *EncryptedJSON) Decrypt(key []byte) (map[string]interface{}, error) {
    // 暗号化解除ロジック
    decrypted, err := aesDecrypt(ej.CipherText, key)
    if err != nil {
        return nil, fmt.Errorf("decryption failed: %w", err)
    }
    
    var result map[string]interface{}
    if err := json.Unmarshal(decrypted, &result); err != nil {
        return nil, fmt.Errorf("JSON unmarshal failed: %w", err)
    }
    
    return result, nil
}

func (ej *EncryptedJSON) Scan(value interface{}) error {
    if value == nil {
        return nil
    }
    
    switch v := value.(type) {
    case []byte:
        return json.Unmarshal(v, ej)
    case string:
        return json.Unmarshal([]byte(v), ej)
    default:
        return fmt.Errorf("cannot scan %T into EncryptedJSON", value)
    }
}

func (ej EncryptedJSON) Value() (driver.Value, error) {
    return json.Marshal(ej)
}
```

#### 大量データ対応マッピング戦略

```go
// バッチ処理用の軽量エンティティ
type ReportSummaryEntity struct {
    ReportID     string     `db:"report_id"`
    TargetType   string     `db:"target_type"`
    TargetID     string     `db:"target_id"`
    Status       string     `db:"status"`
    Priority     int        `db:"priority"`
    CreatedAt    time.Time  `db:"created_at"`
    ResolvedAt   *time.Time `db:"resolved_at"`
}

// ストリーミング処理用のカーソル型
type ModerationCursor struct {
    LastProcessedID string    `json:"last_processed_id"`
    LastTimestamp   time.Time `json:"last_timestamp"`
    BatchSize       int       `json:"batch_size"`
    Filters         map[string]interface{} `json:"filters"`
}

// 分析用集約データマッピング
type ModerationMetricsEntity struct {
    MetricDate          time.Time `db:"metric_date"`
    TotalReports        int       `db:"total_reports"`
    ResolvedReports     int       `db:"resolved_reports"`
    EscalatedReports    int       `db:"escalated_reports"`
    AvgResolutionTime   float64   `db:"avg_resolution_time_hours"`
    FalsePositiveRate   float64   `db:"false_positive_rate"`
    ModeratorWorkload   int       `db:"moderator_workload"`
    FilterEffectiveness float64   `db:"filter_effectiveness"`
}
```

#### Report Aggregate の永続化戦略
```go
type ReportAggregateMapper struct {
    evidenceMapper *ReportEvidenceMapper
    auditLogger    AuditLogger
}

// 複雑な集約の永続化（証拠、履歴を含む）
func (m *ReportAggregateMapper) PersistAggregate(
    ctx context.Context, 
    report *Report,
    tx *sql.Tx,
) error {
    // 1. メインエンティティの永続化
    if err := m.persistReportEntity(ctx, report, tx); err != nil {
        return fmt.Errorf("failed to persist report entity: %w", err)
    }
    
    // 2. 証拠の永続化
    for _, evidence := range report.Evidence() {
        if err := m.evidenceMapper.Persist(ctx, evidence, tx); err != nil {
            return fmt.Errorf("failed to persist evidence: %w", err)
        }
    }
    
    // 3. 変更履歴の記録
    changeLog := m.createChangeLog(report)
    if err := m.auditLogger.LogChange(ctx, changeLog, tx); err != nil {
        return fmt.Errorf("failed to log changes: %w", err)
    }
    
    // 4. 集約ハッシュの計算と保存
    aggregateHash := m.calculateAggregateHash(report)
    if err := m.storeAggregateHash(ctx, report.ID(), aggregateHash, tx); err != nil {
        return fmt.Errorf("failed to store aggregate hash: %w", err)
    }
    
    return nil
}
```

#### ContentFilter Aggregate のマッピング
```go
// フィルター条件の複雑なマッピング
type ContentFilterEntity struct {
    FilterID       string                   `db:"filter_id"`
    FilterName     string                   `db:"filter_name"`
    FilterType     string                   `db:"filter_type"`
    Priority       int                      `db:"priority"`
    IsActive       bool                     `db:"is_active"`
    
    // 複雑な条件はJSONBとして保存
    Conditions     FilterConditionsJSON     `db:"conditions"`
    
    // パフォーマンスメトリクス
    EffectivenessScore float64              `db:"effectiveness_score"`
    LastEffectivenessMeasurement time.Time `db:"last_effectiveness_measurement"`
    
    // メタデータ
    CreatedBy      string                   `db:"created_by"`
    CreatedAt      time.Time               `db:"created_at"`
    UpdatedAt      time.Time               `db:"updated_at"`
}

type FilterConditionsJSON struct {
    Patterns    []PatternCondition    `json:"patterns"`
    MLModels    []MLModelCondition    `json:"ml_models"`
    Thresholds  []ThresholdCondition  `json:"thresholds"`
    Weights     map[string]float64    `json:"weights"`
}

// カスタム JSON マーシャリング
func (fcj *FilterConditionsJSON) Scan(value interface{}) error {
    if value == nil {
        return nil
    }
    
    bytes, ok := value.([]byte)
    if !ok {
        return fmt.Errorf("cannot scan %T into FilterConditionsJSON", value)
    }
    
    return json.Unmarshal(bytes, fcj)
}

func (fcj FilterConditionsJSON) Value() (driver.Value, error) {
    return json.Marshal(fcj)
}
```

### 13.2. 監査証跡のマッピング

#### AuditTrail Aggregate の永続化
```go
type AuditTrailEntity struct {
    AuditID      string    `db:"audit_id"`
    EventType    string    `db:"event_type"`
    Timestamp    time.Time `db:"timestamp"`
    ActorID      string    `db:"actor_id"`
    ActorType    string    `db:"actor_type"`
    Action       string    `db:"action"`
    ResourceType string    `db:"resource_type"`
    ResourceID   string    `db:"resource_id"`
    
    // 変更内容 (JSONB)
    Changes      []byte    `db:"changes"`
    
    // 完全性保証
    DataHash     string    `db:"data_hash"`
    PreviousHash string    `db:"previous_hash"`
    ChainIndex   int64     `db:"chain_index"`
    
    // セキュリティコンテキスト
    IPAddress    string    `db:"ip_address"`
    UserAgent    string    `db:"user_agent"`
    SessionID    string    `db:"session_id"`
    
    // コンプライアンス
    RetentionPeriod string `db:"retention_period"`
    LegalBasis      string `db:"legal_basis"`
}

// ハッシュチェーン完全性の実装
func (ate *AuditTrailEntity) CalculateHash() string {
    data := fmt.Sprintf("%s|%s|%s|%s|%s|%s|%s|%s",
        ate.AuditID,
        ate.Timestamp.Format(time.RFC3339Nano),
        ate.ActorID,
        ate.Action,
        ate.ResourceType,
        ate.ResourceID,
        string(ate.Changes),
        ate.PreviousHash,
    )
    
    hash := sha256.Sum256([]byte(data))
    return hex.EncodeToString(hash[:])
}

func (ate *AuditTrailEntity) VerifyIntegrity() error {
    expectedHash := ate.CalculateHash()
    if ate.DataHash != expectedHash {
        return fmt.Errorf("audit trail integrity violation: expected %s, got %s", 
            expectedHash, ate.DataHash)
    }
    return nil
}
```

### 13.3. パフォーマンス最適化マッピング

#### バッチ処理対応のRepository
```go
type BatchReportRepository struct {
    db          *sql.DB
    batchSize   int
    mapper      *ReportMapper
}

// 大量レポートのバッチ処理
func (r *BatchReportRepository) CreateBatch(
    ctx context.Context, 
    reports []*Report,
) error {
    if len(reports) == 0 {
        return nil
    }
    
    tx, err := r.db.BeginTx(ctx, nil)
    if err != nil {
        return fmt.Errorf("failed to begin transaction: %w", err)
    }
    defer tx.Rollback()
    
    // バッチサイズごとに分割処理
    for i := 0; i < len(reports); i += r.batchSize {
        end := i + r.batchSize
        if end > len(reports) {
            end = len(reports)
        }
        
        batch := reports[i:end]
        if err := r.insertBatch(ctx, tx, batch); err != nil {
            return fmt.Errorf("failed to insert batch: %w", err)
        }
    }
    
    return tx.Commit()
}

func (r *BatchReportRepository) insertBatch(
    ctx context.Context, 
    tx *sql.Tx, 
    reports []*Report,
) error {
    // PostgreSQL COPY文による高速一括挿入
    stmt, err := tx.PrepareContext(ctx, pq.CopyIn(
        "reports",
        "report_id", "reporter_user_id", "target_type", "target_id",
        "reason", "description", "status", "priority",
        "created_at", "updated_at",
    ))
    if err != nil {
        return fmt.Errorf("failed to prepare copy statement: %w", err)
    }
    defer stmt.Close()
    
    for _, report := range reports {
        entity := r.mapper.ToEntity(report)
        _, err = stmt.ExecContext(ctx,
            entity.ReportID, entity.ReporterID, entity.TargetType, entity.TargetID,
            entity.Reason, entity.Description, entity.Status, entity.Priority,
            entity.CreatedAt, entity.UpdatedAt,
        )
        if err != nil {
            return fmt.Errorf("failed to add row to batch: %w", err)
        }
    }
    
    _, err = stmt.ExecContext(ctx)
    if err != nil {
        return fmt.Errorf("failed to execute batch insert: %w", err)
    }
    
    return nil
}
```

### 13.4. インデックス戦略・パフォーマンス最適化

#### モデレーション特化のインデックス設計

##### パーティショニング戦略（大量データ対応）

```sql
-- 月次パーティショニング（監査ログ）
CREATE TABLE moderation_logs_y2025m01 PARTITION OF moderation_logs
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE moderation_logs_y2025m02 PARTITION OF moderation_logs
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');

-- 年次パーティショニング（アクション履歴）
CREATE TABLE moderation_actions_2024 PARTITION OF moderation_actions_partitioned
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE moderation_actions_2025 PARTITION OF moderation_actions_partitioned
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

-- 自動パーティション管理
CREATE OR REPLACE FUNCTION create_monthly_partitions()
RETURNS void AS $$
DECLARE
    start_date date := date_trunc('month', CURRENT_DATE);
    end_date date;
    partition_name text;
BEGIN
    FOR i IN 0..12 LOOP
        end_date := start_date + INTERVAL '1 month';
        partition_name := 'moderation_logs_y' || EXTRACT(year FROM start_date) || 
                         'm' || LPAD(EXTRACT(month FROM start_date)::text, 2, '0');
        
        EXECUTE format('CREATE TABLE IF NOT EXISTS %I PARTITION OF moderation_logs
                       FOR VALUES FROM (%L) TO (%L)',
                       partition_name, start_date, end_date);
        
        start_date := end_date;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- パーティション自動作成cron
SELECT cron.schedule('create-partitions', '0 0 1 * *', 'SELECT create_monthly_partitions();');
```

##### 部分インデックス・複合インデックス最適化

```sql
-- ホットパス最適化インデックス
CREATE INDEX CONCURRENTLY idx_reports_active_queue 
    ON reports(priority DESC, created_at) 
    WHERE status IN ('pending', 'reviewing') AND priority > 50;

CREATE INDEX CONCURRENTLY idx_reports_escalation_candidates 
    ON reports(created_at, priority) 
    WHERE status = 'pending' AND assigned_to IS NULL 
    AND created_at < CURRENT_TIMESTAMP - INTERVAL '2 hours';

-- フィルター性能最適化
CREATE INDEX CONCURRENTLY idx_content_filters_ml 
    ON content_filters(ml_model_id, confidence_threshold, is_active) 
    WHERE filter_type = 'ml_classifier' AND is_active = true;

-- 時系列データ最適化
CREATE INDEX CONCURRENTLY idx_filter_logs_daily_stats 
    ON filter_logs(filter_id, date_trunc('day', created_at), confidence_score) 
    WHERE confidence_score >= 0.7;

-- カーディナリティベースの複合インデックス
CREATE INDEX CONCURRENTLY idx_moderation_actions_compound 
    ON moderation_actions(is_active, target_type, severity, executed_at DESC) 
    WHERE is_active = true;

-- 統計情報更新の自動化
CREATE OR REPLACE FUNCTION update_table_statistics()
RETURNS void AS $$
BEGIN
    ANALYZE reports;
    ANALYZE moderation_actions;
    ANALYZE moderation_logs;
    ANALYZE content_filters;
    ANALYZE filter_logs;
END;
$$ LANGUAGE plpgsql;

-- 統計情報自動更新cron（毎日4時実行）
SELECT cron.schedule('update-stats', '0 4 * * *', 'SELECT update_table_statistics();');
```

##### 接続プーリング・クエリ最適化

```go
// 接続プール設定（パフォーマンス最適化）
type DatabaseConfig struct {
    MaxOpenConns    int           `env:"DB_MAX_OPEN_CONNS" envDefault:"25"`
    MaxIdleConns    int           `env:"DB_MAX_IDLE_CONNS" envDefault:"5"`
    ConnMaxLifetime time.Duration `env:"DB_CONN_MAX_LIFETIME" envDefault:"300s"`
    ConnMaxIdleTime time.Duration `env:"DB_CONN_MAX_IDLE_TIME" envDefault:"60s"`
    
    // 読み取り専用レプリカ設定
    ReadReplicaURL    string `env:"DB_READ_REPLICA_URL"`
    ReadWriteRatio    int    `env:"DB_READ_WRITE_RATIO" envDefault:"80"` // 80% read, 20% write
}

// 読み書き分離実装
type ModerationRepository struct {
    writeDB *sql.DB
    readDB  *sql.DB
    readWriteRatio int
}

func (r *ModerationRepository) selectDB(isWrite bool) *sql.DB {
    if isWrite || r.readDB == nil {
        return r.writeDB
    }
    
    // 統計レポートや集約クエリは読み取り専用レプリカを使用
    return r.readDB
}

// バッチクエリ最適化
func (r *ModerationRepository) BatchCreateReports(ctx context.Context, reports []*Report) error {
    if len(reports) == 0 {
        return nil
    }
    
    // PostgreSQL COPY使用による高速一括挿入
    stmt, err := r.writeDB.PrepareContext(ctx, pq.CopyIn("reports", 
        "report_id", "reporter_user_id", "target_type", "target_id", 
        "reason", "description", "status", "priority", "created_at", "updated_at"))
    if err != nil {
        return fmt.Errorf("failed to prepare copy statement: %w", err)
    }
    defer stmt.Close()
    
    for _, report := range reports {
        _, err = stmt.ExecContext(ctx,
            report.ID(), report.ReporterID(), report.Target().Type, report.Target().ID,
            report.Reason(), report.Description(), report.Status(), report.Priority(),
            report.CreatedAt(), report.UpdatedAt())
        if err != nil {
            return fmt.Errorf("failed to add report to batch: %w", err)
        }
    }
    
    _, err = stmt.ExecContext(ctx)
    if err != nil {
        return fmt.Errorf("failed to execute batch insert: %w", err)
    }
    
    return nil
}

// 大量データ検索の最適化（カーソルベースページング）
func (r *ModerationRepository) FindReportsWithCursor(ctx context.Context, cursor *ModerationCursor) ([]*Report, *ModerationCursor, error) {
    query := `
        SELECT report_id, reporter_user_id, target_type, target_id, reason, description,
               status, priority, created_at, updated_at
        FROM reports
        WHERE ($1::timestamp IS NULL OR created_at > $1)
        ORDER BY created_at ASC, report_id ASC
        LIMIT $2
    `
    
    var cursorTime *time.Time
    if cursor != nil && !cursor.LastTimestamp.IsZero() {
        cursorTime = &cursor.LastTimestamp
    }
    
    batchSize := 100
    if cursor != nil && cursor.BatchSize > 0 {
        batchSize = cursor.BatchSize
    }
    
    rows, err := r.selectDB(false).QueryContext(ctx, query, cursorTime, batchSize+1)
    if err != nil {
        return nil, nil, fmt.Errorf("failed to query reports: %w", err)
    }
    defer rows.Close()
    
    var reports []*Report
    var nextCursor *ModerationCursor
    
    for rows.Next() {
        if len(reports) >= batchSize {
            // 次のページが存在する
            nextCursor = &ModerationCursor{
                LastTimestamp: reports[len(reports)-1].CreatedAt(),
                BatchSize:     batchSize,
            }
            break
        }
        
        var entity ReportEntity
        err := rows.Scan(&entity.ReportID, &entity.ReporterID, &entity.TargetType, 
                        &entity.TargetID, &entity.Reason, &entity.Description,
                        &entity.Status, &entity.Priority, &entity.CreatedAt, &entity.UpdatedAt)
        if err != nil {
            return nil, nil, fmt.Errorf("failed to scan report: %w", err)
        }
        
        report, err := entity.ToDomain()
        if err != nil {
            return nil, nil, fmt.Errorf("failed to convert to domain: %w", err)
        }
        
        reports = append(reports, report)
    }
    
    return reports, nextCursor, nil
}
```

##### モニタリング・メトリクス

```go
// データベースパフォーマンスメトリクス
type DBMetrics struct {
    QueryDuration     prometheus.HistogramVec
    ActiveConnections prometheus.Gauge
    IdleConnections   prometheus.Gauge
    QueryCount        prometheus.CounterVec
    SlowQueryCount    prometheus.Counter
}

func NewDBMetrics() *DBMetrics {
    return &DBMetrics{
        QueryDuration: prometheus.NewHistogramVec(
            prometheus.HistogramOpts{
                Name: "avion_moderation_db_query_duration_seconds",
                Help: "Database query duration in seconds",
                Buckets: []float64{0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0, 2.0, 5.0},
            },
            []string{"operation", "table"},
        ),
        ActiveConnections: prometheus.NewGauge(
            prometheus.GaugeOpts{
                Name: "avion_moderation_db_active_connections",
                Help: "Number of active database connections",
            },
        ),
        SlowQueryCount: prometheus.NewCounter(
            prometheus.CounterOpts{
                Name: "avion_moderation_db_slow_queries_total",
                Help: "Total number of slow database queries (>1s)",
            },
        ),
    }
}

// クエリ実行ラッパー（メトリクス記録付き）
func (r *ModerationRepository) execWithMetrics(ctx context.Context, operation, table string, query string, args ...interface{}) error {
    start := time.Now()
    defer func() {
        duration := time.Since(start)
        r.metrics.QueryDuration.WithLabelValues(operation, table).Observe(duration.Seconds())
        
        if duration > time.Second {
            r.metrics.SlowQueryCount.Inc()
            r.logger.Warn("Slow query detected",
                zap.String("operation", operation),
                zap.String("table", table),
                zap.Duration("duration", duration),
                zap.String("query", query))
        }
    }()
    
    _, err := r.writeDB.ExecContext(ctx, query, args...)
    return err
}
```
```sql
-- 通報処理効率化インデックス
CREATE INDEX CONCURRENTLY idx_reports_moderation_queue 
    ON reports(status, priority DESC, created_at) 
    WHERE status IN ('pending', 'reviewing');

-- モデレーター割り当て最適化
CREATE INDEX CONCURRENTLY idx_reports_assigned_moderator 
    ON reports(assigned_to, status, updated_at DESC) 
    WHERE assigned_to IS NOT NULL;

-- SLA監視インデックス
CREATE INDEX CONCURRENTLY idx_reports_sla_monitoring 
    ON reports(sla_deadline, status) 
    WHERE status != 'resolved' AND sla_deadline IS NOT NULL;

-- 通報集約インデックス
CREATE INDEX CONCURRENTLY idx_report_aggregations_target 
    ON report_aggregations(target_type, target_id, aggregated_priority DESC);

-- フィルターマッチングインデックス
CREATE INDEX CONCURRENTLY idx_filter_logs_effectiveness 
    ON filter_logs(filter_id, created_at DESC, is_false_positive) 
    WHERE created_at > NOW() - INTERVAL '30 days';

-- 監査ログ検索インデックス
CREATE INDEX CONCURRENTLY idx_audit_trails_actor_time 
    ON audit_trails(actor_id, timestamp DESC);

CREATE INDEX CONCURRENTLY idx_audit_trails_resource 
    ON audit_trails(resource_type, resource_id, timestamp DESC);

-- 部分インデックス（アクティブなポリシーのみ）
CREATE INDEX CONCURRENTLY idx_instance_policies_active 
    ON instance_policies(domain, policy_type) 
    WHERE is_active = true;

-- 複合インデックス（モデレーションアクション検索）
CREATE INDEX CONCURRENTLY idx_moderation_actions_search 
    ON moderation_actions(target_type, target_id, executed_at DESC) 
    WHERE is_active = true;
```

### 7.1. イベント設計

### 発行イベント

```json
// 通報作成
{
  "event_type": "moderation.report.created",
  "report_id": "uuid",
  "reporter_id": "uuid",
  "target_type": "user|drop|media",
  "target_id": "uuid",
  "reason": "spam|harassment|violence",
  "priority": 75,
  "created_at": "2025-01-01T00:00:00Z"
}

// モデレーションアクション実行
{
  "event_type": "moderation.action.executed",
  "action_id": "uuid",
  "action_type": "warn|delete|suspend|ban",
  "target_type": "user|drop|media",
  "target_id": "uuid",
  "moderator_id": "uuid",
  "severity": "low|medium|high|critical",
  "expires_at": "2025-01-01T00:00:00Z",
  "executed_at": "2025-01-01T00:00:00Z"
}

// コンテンツフィルター適用
{
  "event_type": "moderation.content.filtered",
  "filter_id": "uuid",
  "content_type": "drop|comment",
  "content_id": "uuid",
  "action": "flag|hold|reject",
  "confidence": 0.95,
  "created_at": "2025-01-01T00:00:00Z"
}

// 異議申し立て解決
{
  "event_type": "moderation.appeal.resolved",
  "appeal_id": "uuid",
  "action_id": "uuid",
  "outcome": "upheld|overturned|dismissed",
  "reviewer_id": "uuid",
  "resolved_at": "2025-01-01T00:00:00Z"
}

// インスタンスポリシー適用
{
  "event_type": "moderation.instance.policy_applied",
  "domain": "example.com",
  "policy_type": "block|silence|media_removal",
  "reason": "spam|violation",
  "applied_at": "2025-01-01T00:00:00Z"
}
```

### 購読イベント

```json
// コンテンツ作成（フィルタリング対象）
{
  "event_type": "content.created",
  "content_type": "drop|comment",
  "content_id": "uuid",
  "user_id": "uuid",
  "content": "text content",
  "media_urls": ["url1", "url2"],
  "created_at": "2025-01-01T00:00:00Z"
}

// ユーザー登録（レピュテーション初期化）
{
  "event_type": "user.registered",
  "user_id": "uuid",
  "instance_domain": "example.com",
  "registered_at": "2025-01-01T00:00:00Z"
}
```

## 13. Technical Stack (技術スタック)

- 言語: Go 1.21+
- フレームワーク: なし（標準ライブラリ中心）
- gRPC: google.golang.org/grpc
- DB: PostgreSQL 15+
- キャッシュ: Redis 7+
- ML Framework: TensorFlow Serving / ONNX Runtime
- 画像認識: Google Vision API / AWS Rekognition
- テキスト分析: Google Natural Language API / Azure Text Analytics
- イベントバス: Redis Pub/Sub
- 全文検索: PostgreSQL Full Text Search
- 監視: OpenTelemetry

## 9. Operations & Monitoring (運用と監視)

### 9.1. Health Checks
- `/health`: Basic liveness check
- `/ready`: Readiness check (database connectivity, Redis connection, ML service availability)

### 9.2. Key Metrics
- `moderation_reports_created_total`: Total reports created counter
- `moderation_actions_executed_total`: Total moderation actions executed counter
- `moderation_queue_size`: Current moderation queue size gauge
- `moderation_processing_duration_seconds`: Processing time histogram
- `moderation_filter_hits_total`: Content filter matches counter
- `moderation_ml_classification_duration_seconds`: ML classification time histogram
- `moderation_appeals_created_total`: Appeals created counter
- `moderation_sla_violations_total`: SLA deadline violations counter

### 9.3. Alerts
- **Critical**: Queue size > 10,000 items
- **Critical**: SLA breach rate > 5%
- **Critical**: ML service unavailable
- **Warning**: Processing delay > 1 hour
- **Warning**: False positive rate > 10%
- **Info**: Filter effectiveness degradation

## 10. Integration Specifications (連携仕様)

### 10.1. avion-drop との連携

**Purpose:** コンテンツ削除・制限の実行

**Integration Method:** gRPC

**Data Flow:**
1. モデレーションアクション決定
2. avion-drop.ContentService.DeleteContent() 呼び出し
3. 削除結果の確認と記録
4. イベント発行

**Error Handling:** 削除失敗時は手動確認キューに追加

### 10.2. avion-notification との連携

**Purpose:** モデレーション結果の通知配信

**Integration Method:** Events (Redis Pub/Sub)

**Data Flow:**
1. モデレーションアクション完了
2. `moderation.action.executed` イベント発行
3. avion-notification がイベントを購読
4. 対象ユーザーと通報者に通知配信

**Error Handling:** 通知失敗時は再試行キューに追加

### 10.3. Event Publishing

**Events Published:**
- `moderation.report.created`: 新規通報作成時
- `moderation.action.executed`: モデレーションアクション実行時
- `moderation.content.filtered`: コンテンツフィルター適用時
- `moderation.appeal.resolved`: 異議申し立て解決時
- `moderation.instance.policy_applied`: インスタンスポリシー適用時

**Event Schema:** (See section 7.1 for detailed schemas)

## 11. Non-Functional Requirements (非機能要件)

### 11.1. 可用性
- SLA: 99.9%
- RTO: 10分
- RPO: 5分

### 11.2. パフォーマンス
- 通報作成: p99 < 100ms
- フィルタリング: p99 < 200ms
- モデレーションアクション: p99 < 500ms
- キュー取得: p99 < 100ms
- ML推論: p99 < 300ms
- スループット: 10,000 req/s

### 11.3. データ保持
- 通報記録: 1年
- モデレーションログ: 2年
- フィルターログ: 90日
- 削除コンテンツ: 90日（法的要求対応）
- 異議申し立て: 2年
- 監査ログ: 5年

## 12. Configuration Management (設定管理)

このサービスは、[共通環境変数管理パターン](../common/infrastructure/environment-variables.md)に従って設定管理を実装します。

### 12.1. 環境変数一覧

#### 必須環境変数
- `DATABASE_URL`: PostgreSQL接続URL
- `REDIS_URL`: Redis接続URL
- `OPENAI_API_KEY`: AIモデレーションのためのOpenAI APIキー

#### オプション環境変数（デフォルト値あり）
- `PORT`: HTTPサーバーポート (デフォルト: 8089)
- `GRPC_PORT`: gRPCサーバーポート (デフォルト: 9099)
- `MODERATION_THRESHOLD`: モデレーション閾値 (デフォルト: 0.7)
- `AUTO_BAN_THRESHOLD`: 自動BANの閾値 (デフォルト: 0.95)
- `FILTER_WORD_LIST_PATH`: フィルターワードリストファイルパス (デフォルト: /etc/avion/filters.txt)

### 12.2. Config構造体実装例

```go
// internal/infrastructure/config/config.go
package config

type Config struct {
    // 共通設定
    Server   ServerConfig
    Database DatabaseConfig
    Redis    RedisConfig
    
    // avion-moderation固有設定
    AI         AIConfig
    Moderation ModerationConfig
}

type AIConfig struct {
    OpenAIAPIKey string `env:"OPENAI_API_KEY" required:"true" secret:"true"`
}

type ModerationConfig struct {
    Threshold         float64 `env:"MODERATION_THRESHOLD" required:"false" default:"0.7"`
    AutoBanThreshold  float64 `env:"AUTO_BAN_THRESHOLD" required:"false" default:"0.95"`
    FilterWordListPath string `env:"FILTER_WORD_LIST_PATH" required:"false" default:"/etc/avion/filters.txt"`
}
```

### 12.3. 設定の検証と初期化

```go
// cmd/server/main.go
func main() {
    // 環境変数の読み込み（必須環境変数が不足していればここで失敗）
    cfg := config.MustLoad()
    
    logger.Info("Starting avion-moderation server",
        "environment", cfg.Server.Environment,
        "port", cfg.Server.Port,
        "grpc_port", cfg.Server.GRPCPort,
        "moderation_threshold", cfg.Moderation.Threshold,
        "auto_ban_threshold", cfg.Moderation.AutoBanThreshold,
        "filter_word_list_path", cfg.Moderation.FilterWordListPath,
    )
    
    // OpenAI クライアントの初期化
    aiClient := openai.NewClient(cfg.AI.OpenAIAPIKey)
    
    // フィルターワードリストの読み込み検証
    if _, err := os.Stat(cfg.Moderation.FilterWordListPath); os.IsNotExist(err) {
        logger.Warn("Filter word list file not found", "path", cfg.Moderation.FilterWordListPath)
    }
    
    // その他の依存関係初期化...
}
```

この設定管理により、サービス起動時に必須環境変数の不足を早期検出し、モデレーション機能の適切な動作を保証します。

## 13. Concerns / Open Questions (懸念事項・相談したいこと)

### 技術的懸念
- **ML分類器の精度向上**: 日本語コンテンツの文脈理解向上が必要
- **大量通報処理**: ピーク時の処理能力とキュー管理の最適化
- **フェデレーション対応**: ActivityPub準拠のクロスインスタンス通報処理の複雑性

### パフォーマンス懸念
- **ML推論レイテンシ**: 外部API依存による処理時間の不安定性
- **データベース負荷**: 大量の監査ログとフィルターログによる書き込み負荷

### 今後の検討事項
- **自動化レベル**: 人間の判断とAI判断のバランス調整
- **グローバル展開**: 地域別法規制とコンプライアンス対応
- **プライバシー保護**: GDPR/DSA準拠の証拠保全とデータ最小化

## 14. Service-Specific Test Strategy (サービス固有テスト戦略)

### 14.1. Overview (概要)

avion-moderationサービスでは、AI/MLモデルを使った高度なコンテンツ分析、複雑な通報処理ワークフロー、および不正改竄検出機能を持つ監査システムが中核機能となります。これらの特殊性を考慮した専門的なテスト戦略が必要です。

### 14.2. Content Filtering Test Strategy (コンテンツフィルタリングテスト戦略)

#### 14.2.1. AI/ML Model Testing

プライバシー保護を重視したMLモデルのテスト実装：

```go
// tests/unit/usecase/content_filter_test.go
package usecase_test

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"go.uber.org/mock/gomock"
	"avion-moderation/domain/model"
	"avion-moderation/tests/mocks/domain/repository"
	"avion-moderation/tests/mocks/infrastructure/ml"
	"avion-moderation/usecase/content"
)

func TestContentFilterUseCase_AnalyzeContent(t *testing.T) {
	ctrl := gomock.NewController(t)
	defer ctrl.Finish()

	mockMLService := ml.NewMockMLAnalysisService(ctrl)
	mockFilterRepo := repository.NewMockContentFilterRepository(ctrl)

	tests := []struct {
		name           string
		input          model.ContentAnalysisRequest
		mockMLResponse model.MLAnalysisResult
		mockMLError    error
		expected       model.ContentModerationResult
		expectedError  string
	}{
		{
			name: "Safe content with low risk scores",
			input: model.ContentAnalysisRequest{
				ContentID:   "content-123",
				ContentType: model.ContentTypeText,
				Text:        "This is a normal, safe message",
				AuthorID:    "user-456",
			},
			mockMLResponse: model.MLAnalysisResult{
				ToxicityScore:    0.05,
				HateSpeechScore:  0.02,
				SpamScore:        0.01,
				SexualScore:      0.00,
				ViolenceScore:    0.00,
				Confidence:       0.98,
				ProcessingTimeMs: 45,
			},
			expected: model.ContentModerationResult{
				Action:     model.ActionAllow,
				Confidence: 0.98,
				Reasons:    []string{},
				Metadata: map[string]interface{}{
					"ml_analysis": true,
					"max_score":   0.05,
				},
			},
		},
		{
			name: "High toxicity content requiring human review",
			input: model.ContentAnalysisRequest{
				ContentID:   "content-789",
				ContentType: model.ContentTypeText,
				Text:        "Toxic message with harmful language",
				AuthorID:    "user-999",
			},
			mockMLResponse: model.MLAnalysisResult{
				ToxicityScore:    0.92,
				HateSpeechScore:  0.15,
				SpamScore:        0.05,
				SexualScore:      0.02,
				ViolenceScore:    0.08,
				Confidence:       0.94,
				ProcessingTimeMs: 67,
			},
			expected: model.ContentModerationResult{
				Action:     model.ActionHumanReview,
				Confidence: 0.94,
				Reasons:    []string{"high_toxicity", "threshold_exceeded"},
				Metadata: map[string]interface{}{
					"ml_analysis":    true,
					"max_score":      0.92,
					"review_queue":   "high_priority",
					"escalated_at":   "2024-01-15T10:30:00Z",
				},
			},
		},
		{
			name: "ML service failure with fallback to keyword filtering",
			input: model.ContentAnalysisRequest{
				ContentID:   "content-error",
				ContentType: model.ContentTypeText,
				Text:        "Message with suspicious keywords",
				AuthorID:    "user-111",
			},
			mockMLError: errors.New("ML service timeout"),
			expected: model.ContentModerationResult{
				Action:     model.ActionFallbackFilter,
				Confidence: 0.70,
				Reasons:    []string{"ml_service_failure", "fallback_applied"},
				Metadata: map[string]interface{}{
					"ml_analysis":     false,
					"fallback_method": "keyword_filter",
					"error":           "ML service timeout",
				},
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.mockMLError != nil {
				mockMLService.EXPECT().
					AnalyzeContent(gomock.Any(), tt.input).
					Return(model.MLAnalysisResult{}, tt.mockMLError)
			} else {
				mockMLService.EXPECT().
					AnalyzeContent(gomock.Any(), tt.input).
					Return(tt.mockMLResponse, nil)
			}

			useCase := content.NewContentFilterUseCase(mockMLService, mockFilterRepo)
			result, err := useCase.AnalyzeContent(context.Background(), tt.input)

			if tt.expectedError != "" {
				assert.Error(t, err)
				assert.Contains(t, err.Error(), tt.expectedError)
			} else {
				assert.NoError(t, err)
				assert.Equal(t, tt.expected.Action, result.Action)
				assert.Equal(t, tt.expected.Confidence, result.Confidence)
				assert.ElementsMatch(t, tt.expected.Reasons, result.Reasons)
			}
		})
	}
}
```

#### 14.2.2. Keyword Filter Accuracy Testing

```go
// tests/unit/domain/filter/keyword_filter_test.go
func TestRegexKeywordFilter_Performance(t *testing.T) {
	filter := domain.NewRegexKeywordFilter()
	
	// Load production-like keyword patterns
	patterns := []string{
		`(?i)(spam|scam|phishing)`,
		`(?i)hate\s*speech\s*pattern`,
		`(?i)violent\s*threat\s*keywords`,
	}
	
	for _, pattern := range patterns {
		filter.AddPattern(pattern, model.ViolationTypeSpam)
	}

	tests := []struct {
		name           string
		content        string
		expectedMatch  bool
		expectedType   model.ViolationType
		maxLatencyMs   int
	}{
		{
			name:          "Exact spam keyword match",
			content:       "This is a spam message",
			expectedMatch: true,
			expectedType:  model.ViolationTypeSpam,
			maxLatencyMs:  1,
		},
		{
			name:          "Case insensitive match",
			content:       "SPAM CONTENT HERE",
			expectedMatch: true,
			expectedType:  model.ViolationTypeSpam,
			maxLatencyMs:  1,
		},
		{
			name:          "No match for clean content",
			content:       "This is normal content",
			expectedMatch: false,
			maxLatencyMs:  1,
		},
		{
			name:          "Large content performance test",
			content:       strings.Repeat("Normal content. ", 1000) + "spam",
			expectedMatch: true,
			expectedType:  model.ViolationTypeSpam,
			maxLatencyMs:  10,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			start := time.Now()
			result := filter.CheckContent(tt.content)
			latency := time.Since(start).Milliseconds()

			if tt.expectedMatch {
				assert.True(t, result.HasViolation)
				assert.Equal(t, tt.expectedType, result.ViolationType)
			} else {
				assert.False(t, result.HasViolation)
			}
			
			assert.LessOrEqual(t, latency, int64(tt.maxLatencyMs))
		})
	}
}
```

### 14.3. Report Workflow State Testing (通報ワークフローテスト)

#### 14.3.1. State Transition Testing

```go
// tests/unit/usecase/report_workflow_test.go
func TestReportWorkflowUseCase_StateTransitions(t *testing.T) {
	ctrl := gomock.NewController(t)
	defer ctrl.Finish()

	mockRepo := repository.NewMockReportRepository(ctrl)
	mockNotifier := notification.NewMockNotificationService(ctrl)

	tests := []struct {
		name           string
		initialState   model.ReportStatus
		action         model.WorkflowAction
		expectedState  model.ReportStatus
		shouldNotify   bool
		expectedError  string
	}{
		{
			name:          "New report to under investigation",
			initialState:  model.ReportStatusNew,
			action:        model.ActionStartInvestigation,
			expectedState: model.ReportStatusUnderInvestigation,
			shouldNotify:  true,
		},
		{
			name:          "Investigation to resolved",
			initialState:  model.ReportStatusUnderInvestigation,
			action:        model.ActionResolveReport,
			expectedState: model.ReportStatusResolved,
			shouldNotify:  true,
		},
		{
			name:          "Investigation to escalated",
			initialState:  model.ReportStatusUnderInvestigation,
			action:        model.ActionEscalateReport,
			expectedState: model.ReportStatusEscalated,
			shouldNotify:  true,
		},
		{
			name:          "Invalid transition should fail",
			initialState:  model.ReportStatusResolved,
			action:        model.ActionStartInvestigation,
			expectedError: "invalid state transition",
		},
		{
			name:          "Appeal from resolved",
			initialState:  model.ReportStatusResolved,
			action:        model.ActionAppealDecision,
			expectedState: model.ReportStatusUnderAppeal,
			shouldNotify:  true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			report := &model.Report{
				ID:       "report-123",
				Status:   tt.initialState,
				ReporterID: "user-456",
				TargetID: "content-789",
			}

			if tt.expectedError == "" {
				mockRepo.EXPECT().
					UpdateReportStatus(gomock.Any(), report.ID, tt.expectedState).
					Return(nil)
				
				if tt.shouldNotify {
					mockNotifier.EXPECT().
						NotifyStatusUpdate(gomock.Any(), gomock.Any()).
						Return(nil)
				}
			}

			useCase := workflow.NewReportWorkflowUseCase(mockRepo, mockNotifier)
			err := useCase.ProcessAction(context.Background(), report, tt.action)

			if tt.expectedError != "" {
				assert.Error(t, err)
				assert.Contains(t, err.Error(), tt.expectedError)
			} else {
				assert.NoError(t, err)
				assert.Equal(t, tt.expectedState, report.Status)
			}
		})
	}
}
```

### 14.4. Escalation Priority Calculation Testing (エスカレーション優先度計算テスト)

```go
// tests/unit/domain/escalation/priority_calculator_test.go
func TestEscalationPriorityCalculator(t *testing.T) {
	calculator := domain.NewEscalationPriorityCalculator()

	tests := []struct {
		name               string
		reportContext      model.ReportContext
		userHistory        model.UserModerationHistory
		contentMetrics     model.ContentMetrics
		expectedPriority   model.EscalationPriority
		expectedScore      float64
	}{
		{
			name: "High priority - repeat offender with viral content",
			reportContext: model.ReportContext{
				ViolationType:    model.ViolationTypeHateSpeech,
				Severity:         model.SeverityHigh,
				ReportCount:      15,
				UniqueReporters:  12,
				TimeWindow:       time.Hour,
			},
			userHistory: model.UserModerationHistory{
				PreviousViolations: 3,
				LastViolationDays:  7,
				AccountAgeMonths:   2,
				TrustScore:         0.2,
			},
			contentMetrics: model.ContentMetrics{
				ViewCount:    50000,
				ShareCount:   1200,
				ReachScore:   0.95,
				ViralityRisk: 0.88,
			},
			expectedPriority: model.EscalationPriorityCritical,
			expectedScore:    0.92,
		},
		{
			name: "Medium priority - first offense with moderate reach",
			reportContext: model.ReportContext{
				ViolationType:    model.ViolationTypeSpam,
				Severity:         model.SeverityMedium,
				ReportCount:      3,
				UniqueReporters:  3,
				TimeWindow:       time.Hour * 6,
			},
			userHistory: model.UserModerationHistory{
				PreviousViolations: 0,
				LastViolationDays:  0,
				AccountAgeMonths:   24,
				TrustScore:         0.75,
			},
			contentMetrics: model.ContentMetrics{
				ViewCount:    500,
				ShareCount:   12,
				ReachScore:   0.3,
				ViralityRisk: 0.1,
			},
			expectedPriority: model.EscalationPriorityMedium,
			expectedScore:    0.45,
		},
		{
			name: "Low priority - minor violation from trusted user",
			reportContext: model.ReportContext{
				ViolationType:    model.ViolationTypeOffTopic,
				Severity:         model.SeverityLow,
				ReportCount:      1,
				UniqueReporters:  1,
				TimeWindow:       time.Hour * 24,
			},
			userHistory: model.UserModerationHistory{
				PreviousViolations: 0,
				LastViolationDays:  0,
				AccountAgeMonths:   48,
				TrustScore:         0.95,
			},
			contentMetrics: model.ContentMetrics{
				ViewCount:    25,
				ShareCount:   0,
				ReachScore:   0.05,
				ViralityRisk: 0.01,
			},
			expectedPriority: model.EscalationPriorityLow,
			expectedScore:    0.15,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			priority, score := calculator.CalculatePriority(
				tt.reportContext,
				tt.userHistory,
				tt.contentMetrics,
			)

			assert.Equal(t, tt.expectedPriority, priority)
			assert.InDelta(t, tt.expectedScore, score, 0.05)
		})
	}
}
```

### 14.5. Audit Trail Integrity Testing (監査証跡整合性テスト)

#### 14.5.1. Hash Chain Verification

```go
// tests/unit/domain/audit/hash_chain_test.go
func TestAuditHashChain_IntegrityVerification(t *testing.T) {
	tests := []struct {
		name           string
		setupChain     func() *domain.AuditHashChain
		tamperFunc     func(*domain.AuditHashChain)
		expectValid    bool
		expectedError  string
	}{
		{
			name: "Valid chain with multiple entries",
			setupChain: func() *domain.AuditHashChain {
				chain := domain.NewAuditHashChain()
				chain.AddEntry(model.AuditEntry{
					Action:    "content_removed",
					ActorID:   "moderator-123",
					TargetID:  "content-456",
					Timestamp: time.Now(),
					Metadata:  map[string]interface{}{"reason": "spam"},
				})
				chain.AddEntry(model.AuditEntry{
					Action:    "user_warned",
					ActorID:   "system",
					TargetID:  "user-789",
					Timestamp: time.Now().Add(time.Minute),
					Metadata:  map[string]interface{}{"warning_type": "first"},
				})
				return chain
			},
			expectValid: true,
		},
		{
			name: "Tampered entry should be detected",
			setupChain: func() *domain.AuditHashChain {
				chain := domain.NewAuditHashChain()
				chain.AddEntry(model.AuditEntry{
					Action:    "content_removed",
					ActorID:   "moderator-123",
					TargetID:  "content-456",
					Timestamp: time.Now(),
				})
				return chain
			},
			tamperFunc: func(chain *domain.AuditHashChain) {
				// Simulate tampering by modifying an entry
				entries := chain.GetEntries()
				entries[0].Action = "content_approved" // Changed action
			},
			expectValid:   false,
			expectedError: "hash chain integrity violation",
		},
		{
			name: "Missing entry should be detected",
			setupChain: func() *domain.AuditHashChain {
				chain := domain.NewAuditHashChain()
				chain.AddEntry(model.AuditEntry{Action: "action1"})
				chain.AddEntry(model.AuditEntry{Action: "action2"})
				chain.AddEntry(model.AuditEntry{Action: "action3"})
				return chain
			},
			tamperFunc: func(chain *domain.AuditHashChain) {
				// Remove middle entry
				entries := chain.GetEntries()
				chain.SetEntries(append(entries[:1], entries[2:]...))
			},
			expectValid:   false,
			expectedError: "missing entry detected",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			chain := tt.setupChain()
			
			if tt.tamperFunc != nil {
				tt.tamperFunc(chain)
			}

			valid, err := chain.VerifyIntegrity()

			if tt.expectValid {
				assert.True(t, valid)
				assert.NoError(t, err)
			} else {
				assert.False(t, valid)
				assert.Error(t, err)
				if tt.expectedError != "" {
					assert.Contains(t, err.Error(), tt.expectedError)
				}
			}
		})
	}
}
```

#### 14.5.2. Tamper Evidence Detection

```go
// tests/unit/domain/audit/tamper_detection_test.go
func TestTamperEvidenceDetector(t *testing.T) {
	detector := domain.NewTamperEvidenceDetector()

	tests := []struct {
		name              string
		auditLog          model.AuditLog
		suspiciousChanges []model.SuspiciousChange
		expectedTampered  bool
		expectedEvidence  []string
	}{
		{
			name: "Legitimate moderation sequence",
			auditLog: model.AuditLog{
				Entries: []model.AuditEntry{
					{
						Action:    "report_created",
						Timestamp: time.Now().Add(-time.Hour),
						ActorID:   "user-123",
					},
					{
						Action:    "investigation_started",
						Timestamp: time.Now().Add(-time.Minute * 45),
						ActorID:   "moderator-456",
					},
					{
						Action:    "content_removed",
						Timestamp: time.Now().Add(-time.Minute * 30),
						ActorID:   "moderator-456",
					},
				},
			},
			expectedTampered: false,
		},
		{
			name: "Timestamp manipulation detected",
			auditLog: model.AuditLog{
				Entries: []model.AuditEntry{
					{
						Action:    "report_created",
						Timestamp: time.Now(),
						ActorID:   "user-123",
					},
					{
						Action:    "content_removed",
						Timestamp: time.Now().Add(-time.Hour), // Earlier than creation
						ActorID:   "moderator-456",
					},
				},
			},
			expectedTampered: true,
			expectedEvidence: []string{"timestamp_inconsistency", "causality_violation"},
		},
		{
			name: "Suspicious rapid-fire actions",
			auditLog: model.AuditLog{
				Entries: []model.AuditEntry{
					{
						Action:    "report_created",
						Timestamp: time.Now(),
						ActorID:   "user-123",
					},
					{
						Action:    "investigation_started",
						Timestamp: time.Now().Add(time.Millisecond),
						ActorID:   "moderator-456",
					},
					{
						Action:    "content_removed",
						Timestamp: time.Now().Add(time.Millisecond * 2),
						ActorID:   "moderator-456",
					},
				},
			},
			expectedTampered: true,
			expectedEvidence: []string{"impossible_timing", "automated_pattern"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := detector.AnalyzeForTampering(tt.auditLog)

			assert.Equal(t, tt.expectedTampered, result.HasTampering)
			if tt.expectedTampered {
				assert.ElementsMatch(t, tt.expectedEvidence, result.Evidence)
			}
		})
	}
}
```

### 14.6. Automated Action Testing (自動アクション実行テスト)

```go
// tests/integration/automation/moderation_actions_test.go
func TestAutomatedModerationActions_Integration(t *testing.T) {
	// Integration test with real database and message queue
	testDB := setupTestDatabase(t)
	testQueue := setupTestMessageQueue(t)
	defer cleanupTest(testDB, testQueue)

	tests := []struct {
		name            string
		triggerEvent    model.ModerationEvent
		expectedActions []model.AutomatedAction
		verifyFunc      func(*testing.T, *sql.DB, chan model.QueueMessage)
	}{
		{
			name: "Spam content triggers removal and user warning",
			triggerEvent: model.ModerationEvent{
				Type:      model.EventContentFlagged,
				ContentID: "content-spam-123",
				UserID:    "user-456",
				Reason:    "automated_spam_detection",
				Confidence: 0.95,
			},
			expectedActions: []model.AutomatedAction{
				{Type: model.ActionRemoveContent, TargetID: "content-spam-123"},
				{Type: model.ActionWarnUser, TargetID: "user-456"},
				{Type: model.ActionUpdateScore, TargetID: "user-456"},
			},
			verifyFunc: func(t *testing.T, db *sql.DB, queue chan model.QueueMessage) {
				// Verify content is marked as removed
				var status string
				err := db.QueryRow("SELECT status FROM contents WHERE id = $1", "content-spam-123").Scan(&status)
				assert.NoError(t, err)
				assert.Equal(t, "removed", status)

				// Verify warning was sent
				var warningCount int
				err = db.QueryRow("SELECT COUNT(*) FROM user_warnings WHERE user_id = $1", "user-456").Scan(&warningCount)
				assert.NoError(t, err)
				assert.Equal(t, 1, warningCount)

				// Verify notification was queued
				select {
				case msg := <-queue:
					assert.Equal(t, "user_warning", msg.Type)
					assert.Equal(t, "user-456", msg.TargetID)
				case <-time.After(time.Second):
					t.Fatal("Expected notification message was not queued")
				}
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			automationEngine := automation.NewModerationAutomationEngine(testDB, testQueue)
			
			err := automationEngine.ProcessEvent(context.Background(), tt.triggerEvent)
			assert.NoError(t, err)

			// Allow some time for async processing
			time.Sleep(time.Millisecond * 100)

			tt.verifyFunc(t, testDB, testQueue)
		})
	}
}
```

### 14.7. Performance and Load Testing (パフォーマンステスト)

#### 14.7.1. High-Volume Content Analysis

```go
// tests/performance/content_analysis_bench_test.go
func BenchmarkContentAnalysis_HighVolume(b *testing.B) {
	service := setupBenchmarkService()
	
	testContents := generateTestContents(1000) // Pre-generate test data
	
	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			content := testContents[rand.Intn(len(testContents))]
			_, err := service.AnalyzeContent(context.Background(), content)
			if err != nil {
				b.Fatalf("Analysis failed: %v", err)
			}
		}
	})
}

func BenchmarkAuditLogWrite_Concurrent(b *testing.B) {
	auditService := setupAuditService()
	
	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			entry := model.AuditEntry{
				Action:    "benchmark_action",
				ActorID:   fmt.Sprintf("actor-%d", rand.Intn(1000)),
				TargetID:  fmt.Sprintf("target-%d", rand.Intn(10000)),
				Timestamp: time.Now(),
			}
			
			err := auditService.LogAction(context.Background(), entry)
			if err != nil {
				b.Fatalf("Audit log failed: %v", err)
			}
		}
	})
}
```

### 14.8. Test Data Management and Privacy (テストデータ管理とプライバシー)

#### 14.8.1. Synthetic Data Generation

```go
// tests/testdata/generator.go
type SyntheticDataGenerator struct {
	patterns []ContentPattern
	faker    *gofakeit.Faker
}

func (g *SyntheticDataGenerator) GenerateSafeContent(count int) []model.Content {
	var contents []model.Content
	for i := 0; i < count; i++ {
		contents = append(contents, model.Content{
			ID:   fmt.Sprintf("safe-content-%d", i),
			Text: g.faker.Sentence(rand.Intn(20) + 5),
			Type: model.ContentTypeText,
			Metadata: map[string]interface{}{
				"synthetic": true,
				"category":  "safe",
			},
		})
	}
	return contents
}

func (g *SyntheticDataGenerator) GenerateViolatingContent(violationType model.ViolationType, count int) []model.Content {
	patterns := g.getPatterns(violationType)
	var contents []model.Content
	
	for i := 0; i < count; i++ {
		pattern := patterns[rand.Intn(len(patterns))]
		contents = append(contents, model.Content{
			ID:   fmt.Sprintf("violation-%s-%d", violationType, i),
			Text: g.applyPattern(pattern),
			Type: model.ContentTypeText,
			Metadata: map[string]interface{}{
				"synthetic":      true,
				"violation_type": violationType,
				"pattern_id":     pattern.ID,
			},
		})
	}
	return contents
}
```

この詳細なテスト戦略により、avion-moderationサービスの複雑な機能を確実に検証し、高品質で信頼性の高いモデレーションシステムを構築できます。