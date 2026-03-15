# Design Doc: avion-moderation - インフラ層実装・テスト戦略

> **本文書は [designdoc.md](./designdoc.md) から分割されたドキュメントです。**
>
> エラーハンドリング、構造化ログ、監査ログ、およびサービス固有テスト戦略に関する詳細設計を記載します。

## 関連ドキュメント

- [designdoc.md](./designdoc.md) - メインDesign Doc（概要、ドメインモデル、API定義、決定事項）
- [designdoc-content-filter.md](./designdoc-content-filter.md) - コンテンツフィルタリング、AI分析、自動モデレーション

---

## 1. エラーハンドリング戦略

このサービスでは、[共通エラー標準化ガイドライン](../common/errors/error-standards.md)に従ってエラーハンドリングを実装します。

### エラーコード体系
- サービスプレフィックス: `MODERATION`
- 命名規則: `MODERATION_[LAYER]_[ERROR_TYPE]`（[共通エラー標準化ガイドライン](../common/errors/error-standards.md)準拠）
- 例: `MODERATION_DOMAIN_REPORT_NOT_FOUND`, `MODERATION_USECASE_UNAUTHORIZED`
- 完全なエラーコード一覧は[エラーカタログ](./error-catalog.md)を参照

### 主要なエラーコード

| エラーコード | gRPCステータス | 説明 |
|------------|--------------|------|
| MODERATION_DOMAIN_REPORT_NOT_FOUND | codes.NotFound | 通報が見つからない |
| MODERATION_DOMAIN_REPORT_DUPLICATE | codes.AlreadyExists | 24時間以内に重複通報 |
| MODERATION_DOMAIN_ACTION_INVALID | codes.InvalidArgument | 無効なモデレーションアクション |
| MODERATION_DOMAIN_APPEAL_EXPIRED | codes.FailedPrecondition | 異議申し立て期限切れ |
| MODERATION_DOMAIN_APPEAL_ALREADY_EXISTS | codes.AlreadyExists | 既に異議申し立て済み |
| MODERATION_DOMAIN_AI_CONSENT_REQUIRED | codes.PermissionDenied | AI分析にユーザー同意が必要 |
| MODERATION_DOMAIN_OPTIMISTIC_LOCK_FAILURE | codes.Aborted | 楽観的ロック競合 |
| MODERATION_USECASE_UNAUTHORIZED | codes.Unauthenticated | 認証エラー |
| MODERATION_USECASE_FORBIDDEN | codes.PermissionDenied | モデレーター権限不足 |
| MODERATION_INFRA_ONNX_MODEL_UNAVAILABLE | codes.Unavailable | ONNXモデルが利用できない |
| MODERATION_INFRA_DATABASE_CONNECTION_FAILED | codes.Unavailable | データベース接続エラー |

#### Domain Errors (ドメインエラー)
```go
var (
	ErrReportDuplicate          = NewDomainError("MODERATION_DOMAIN_REPORT_DUPLICATE", "24時間以内の同一対象への重複通報")
	ErrReportNotPending         = NewDomainError("MODERATION_DOMAIN_REPORT_NOT_PENDING", "通報は処理待ち状態ではありません")
	ErrAppealDeadlineExpired    = NewDomainError("MODERATION_DOMAIN_APPEAL_EXPIRED", "異議申し立て期限が過ぎています")
	ErrModerationUnauthorized   = NewDomainError("MODERATION_USECASE_UNAUTHORIZED", "モデレーション権限が不足しています")
	ErrActionNotReversible      = NewDomainError("MODERATION_DOMAIN_ACTION_NOT_REVERSIBLE", "このアクションは取り消しできません")
	ErrActionAlreadyActive      = NewDomainError("MODERATION_DOMAIN_ACTION_ALREADY_ACTIVE", "モデレーションアクションは既に有効です")
	ErrFilterInactive           = NewDomainError("MODERATION_DOMAIN_FILTER_INACTIVE", "フィルターが無効化されています")
	ErrFilterPriorityConflict   = NewDomainError("MODERATION_DOMAIN_FILTER_PRIORITY_CONFLICT", "フィルター優先度が競合しています")
	ErrInstanceSelfModeration   = NewDomainError("MODERATION_DOMAIN_INSTANCE_SELF_MODERATION", "自インスタンスはモデレーション対象外です")
	ErrEscalationRequired       = NewDomainError("MODERATION_DOMAIN_ESCALATION_REQUIRED", "上級モデレーターへのエスカレーションが必要です")
	ErrOptimisticLockFailure    = NewDomainError("MODERATION_DOMAIN_OPTIMISTIC_LOCK_FAILURE", "楽観的ロックの競合が発生しました")
)

type ModerationDomainError struct {
	Code      string                 `json:"code"`
	Message   string                 `json:"message"`
	Details   map[string]interface{} `json:"details,omitempty"`
	Severity  string                 `json:"severity"`
	Retryable bool                   `json:"retryable"`
}

func (e ModerationDomainError) Error() string {
	return fmt.Sprintf("%s: %s", e.Code, e.Message)
}
```

#### Infrastructure Errors (インフラエラー)
```go
var (
	ErrMLClassifierUnavailable = NewInfraError("MODERATION_INFRA_ONNX_MODEL_UNAVAILABLE", "ONNX Runtimeモデルが利用できません", true)
	ErrImageModerationTimeout  = NewInfraError("MODERATION_INFRA_ONNX_INFERENCE_TIMEOUT", "ONNX推論がタイムアウトしました", true)
	ErrAuditLogCorruption      = NewInfraError("MODERATION_DOMAIN_AUDIT_LOG_CORRUPTION", "監査ログの改竄が検出されました", false)
	ErrQueueServiceDown        = NewInfraError("MODERATION_INFRA_QUEUE_CONNECTION_FAILED", "モデレーションキューサービスが停止しています", true)
	ErrDatabaseConnection      = NewInfraError("MODERATION_INFRA_DATABASE_CONNECTION_FAILED", "データベース接続エラー", true)
	ErrRedisConnectionLost     = NewInfraError("MODERATION_INFRA_CACHE_CONNECTION_FAILED", "Redisサーバーとの接続が切断されました", true)
	ErrEventPublishFailed      = NewInfraError("MODERATION_INFRA_QUEUE_PUBLISH_FAILED", "イベント発行に失敗しました", true)
)
```

詳細は[共通エラー標準化ガイドライン](../common/errors/error-standards.md)を参照してください。

## 2. 構造化ログ戦略

このサービスでは、[共通Observabilityパッケージ設計](../common/observability/observability-package-design.md)に従って構造化ログを実装します。

### ログレベル定義
- `DEBUG`: 開発時の詳細情報（フィルタリング条件、MLスコア等）
- `INFO`: 正常な処理フロー（通報受付、モデレーション実行等）
- `WARN`: 予期された異常（重複通報、期限切れ等）
- `ERROR`: 予期しないエラー（ML API失敗、DB接続失敗等）
- `CRITICAL`: システム停止レベルの重大エラー（監査ログ改竄検出、データ整合性崩壊等）

### 標準ログフォーマット

```go
// LogContext - モデレーション操作の構造化ログコンテキスト
type LogContext struct {
	Timestamp    time.Time            `json:"timestamp"`
	Level        string               `json:"level"`
	Service      string               `json:"service"`
	TraceID      string               `json:"trace_id"`
	SpanID       string               `json:"span_id"`
	Layer        string               `json:"layer"`
	Method       string               `json:"method"`
	DurationMs   int64                `json:"duration_ms"`
	Message      string               `json:"message"`

	// モデレーション固有フィールド
	ModeratorID  string               `json:"moderator_id,omitempty"`
	ReportID     *string              `json:"report_id,omitempty"`
	ActionType   string               `json:"action_type,omitempty"`
	ActionID     string               `json:"action_id,omitempty"`
	TargetType   string               `json:"target_type,omitempty"`
	TargetID     string               `json:"target_id,omitempty"`
	Reason       string               `json:"reason,omitempty"`
	Severity     string               `json:"severity,omitempty"`

	// 実行結果
	Success      bool                 `json:"success"`
	ErrorCode    *string              `json:"error_code,omitempty"`

	// コンプライアンス情報
	LegalBasis   string               `json:"legal_basis,omitempty"`
	DataRetention string              `json:"data_retention,omitempty"`

	// 追加メタデータ
	Metadata     map[string]interface{} `json:"metadata,omitempty"`
}
```

```json
{
  "timestamp": "2026-03-14T10:30:00Z",
  "level": "INFO",
  "service": "avion-moderation",
  "trace_id": "abc123def456",
  "span_id": "span789",
  "layer": "usecase",
  "method": "ExecuteModerationAction",
  "duration_ms": 150,
  "action_type": "suspend_account",
  "action_id": "01953a1e-...",
  "report_id": "01953a1d-...",
  "moderator_id": "mod-uuid-789",
  "target_type": "user",
  "target_id": "user-uuid-101",
  "reason": "ハラスメント行為の繰り返し",
  "severity": "high",
  "success": true,
  "legal_basis": "community_guidelines_violation",
  "data_retention": "7_years",
  "metadata": {
    "previous_violations": 3,
    "appeal_deadline": "2026-03-21T10:30:00Z"
  }
}
```

### 監査ログ
モデレーション操作は全て監査ログとして記録され、改竄防止のためハッシュチェーンで保護されます。

```go
type AuditTrailLog struct {
	AuditID         string        `json:"audit_id"`
	EventType       string        `json:"event_type"`
	Timestamp       time.Time     `json:"timestamp"`
	ActorID         string        `json:"actor_id"`
	ActorType       string        `json:"actor_type"` // human, system, api
	Action          string        `json:"action"`
	ResourceType    string        `json:"resource_type"`
	ResourceID      string        `json:"resource_id"`
	Changes         []ChangeRecord `json:"changes"`
	HashValue       string        `json:"hash_value"`
	PreviousHash    string        `json:"previous_hash"`
	RetentionPeriod string        `json:"retention_period"`
	LegalBasis      string        `json:"legal_basis"`
}

type ChangeRecord struct {
	Field      string      `json:"field"`
	OldValue   interface{} `json:"old_value"`
	NewValue   interface{} `json:"new_value"`
	ChangeType string      `json:"change_type"` // create, update, delete
}
```

詳細は[共通Observabilityパッケージ設計](../common/observability/observability-package-design.md)を参照してください。


## 3. Service-Specific Test Strategy (サービス固有テスト戦略)

### 3.1. Overview (概要)

avion-moderationサービスでは、AI/MLモデルを使った高度なコンテンツ分析、複雑な通報処理ワークフロー、および不正改竄検出機能を持つ監査システムが中核機能となります。これらの特殊性を考慮した専門的なテスト戦略が必要です。

### 3.2. Content Filtering Test Strategy (コンテンツフィルタリングテスト)

```go
func TestContentFilterUseCase_AnalyzeContent(t *testing.T) {
    ctrl := gomock.NewController(t)
    defer ctrl.Finish()

    mockMLService := mocks.NewMockMLAnalysisService(ctrl)
    mockFilterRepo := mocks.NewMockContentFilterRepository(ctrl)

    tests := []struct {
        name    string
        setup   func()
        input   domain.ContentAnalysisRequest
        want    domain.ContentModerationResult
        wantErr error
    }{
        {
            name: "正常系: 安全なコンテンツは許可",
            setup: func() {
                mockMLService.EXPECT().
                    AnalyzeContent(gomock.Any(), gomock.Any()).
                    Return(domain.MLAnalysisResult{ToxicityScore: 0.05, Confidence: 0.98}, nil)
            },
            input: domain.ContentAnalysisRequest{ContentID: "content-123", Text: "安全なメッセージ"},
            want:  domain.ContentModerationResult{Action: domain.ActionAllow, Confidence: 0.98},
        },
        {
            name: "正常系: 高毒性コンテンツは人間レビューへ",
            setup: func() {
                mockMLService.EXPECT().
                    AnalyzeContent(gomock.Any(), gomock.Any()).
                    Return(domain.MLAnalysisResult{ToxicityScore: 0.92, Confidence: 0.94}, nil)
            },
            input: domain.ContentAnalysisRequest{ContentID: "content-789", Text: "有害なメッセージ"},
            want:  domain.ContentModerationResult{Action: domain.ActionHumanReview, Confidence: 0.94},
        },
        {
            name: "異常系: MLサービス障害時はキーワードフィルターにフォールバック",
            setup: func() {
                mockMLService.EXPECT().
                    AnalyzeContent(gomock.Any(), gomock.Any()).
                    Return(domain.MLAnalysisResult{}, errors.New("ML service timeout"))
            },
            input: domain.ContentAnalysisRequest{ContentID: "content-err", Text: "テスト"},
            want:  domain.ContentModerationResult{Action: domain.ActionFallbackFilter, Confidence: 0.70},
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            tt.setup()
            uc := usecase.NewContentFilterUseCase(mockMLService, mockFilterRepo)
            got, err := uc.AnalyzeContent(context.Background(), tt.input)

            if !errors.Is(err, tt.wantErr) {
                t.Errorf("error = %v, wantErr %v", err, tt.wantErr)
            }
            if diff := cmp.Diff(tt.want.Action, got.Action); diff != "" {
                t.Errorf("Action mismatch (-want +got):\n%s", diff)
            }
        })
    }
}
```

### 3.3. Audit Trail Integrity Testing (監査証跡整合性テスト)

```go
func TestAuditHashChain_IntegrityVerification(t *testing.T) {
    tests := []struct {
        name        string
        setupChain  func() *domain.AuditHashChain
        tamperFunc  func(*domain.AuditHashChain)
        expectValid bool
        wantErr     error
    }{
        {
            name: "正常系: 有効なハッシュチェーン",
            setupChain: func() *domain.AuditHashChain {
                chain := domain.NewAuditHashChain()
                chain.AddEntry(domain.AuditEntry{Action: "content_removed", ActorID: "mod-123"})
                chain.AddEntry(domain.AuditEntry{Action: "user_warned", ActorID: "system"})
                return chain
            },
            expectValid: true,
        },
        {
            name: "異常系: 改竄されたエントリを検出",
            setupChain: func() *domain.AuditHashChain {
                chain := domain.NewAuditHashChain()
                chain.AddEntry(domain.AuditEntry{Action: "content_removed", ActorID: "mod-123"})
                return chain
            },
            tamperFunc: func(chain *domain.AuditHashChain) {
                entries := chain.GetEntries()
                entries[0].Action = "content_approved"
            },
            expectValid: false,
            wantErr:     domain.ErrAuditLogCorruption,
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
                if !valid {
                    t.Error("expected valid chain but got invalid")
                }
                if err != nil {
                    t.Errorf("unexpected error: %v", err)
                }
            } else {
                if valid {
                    t.Error("expected invalid chain but got valid")
                }
                if !errors.Is(err, tt.wantErr) {
                    t.Errorf("error = %v, wantErr %v", err, tt.wantErr)
                }
            }
        })
    }
}
```
