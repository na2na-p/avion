# Design Doc: avion-moderation

**Author:** Claude Code
**Last Updated:** 2026/03/15

## 関連ドキュメント

- [designdoc-content-filter.md](./designdoc-content-filter.md) - コンテンツフィルタリング、AI分析、NSFW判定、スパム検出、自動モデレーション
- [designdoc-infra-testing.md](./designdoc-infra-testing.md) - インフラ層実装（エラーハンドリング、構造化ログ、キャッシュ戦略）、テスト戦略
- [PRD: avion-moderation](./prd.md)
- [エラーカタログ](./error-catalog.md)

---

## 1. Summary (これは何？)

- **一言で:** Avionにおけるコンテンツモデレーション機能（通報処理、フィルタリング、モデレーションアクション、異議申し立て）を提供するマイクロサービスを実装します。
- **目的:** プラットフォームの健全性維持、有害コンテンツの検出・対処、コミュニティガイドラインの強制、公平かつ透明なモデレーションプロセスを提供し、監査証跡とコンプライアンス要求に対応します。

## 2. テスト戦略

このサービスでは、[共通テスト戦略](../common/testing-strategy.md)に従ってテストを実装します。

### テスト方針
- **TDD必須**: インターフェース定義 → テスト作成 → 実装の順序を厳守
- **カバレッジ目標**: ユニットテスト85%以上、クリティカルパス95%以上
- **テーブル駆動テスト**: 全テストで必須
- **モック生成**: `go.uber.org/mock/gomock`使用
- **アサーション**: `github.com/google/go-cmp/cmp` でのstruct比較、`errors.Is()` でのエラー検証
- **テスト名**: 日本語記述必須（例：`"正常系: 有効な通報を作成"`）

### テストコード例

```go
package usecase_test

import (
	"context"
	"errors"
	"testing"

	"github.com/google/go-cmp/cmp"
	"go.uber.org/mock/gomock"

	"avion-moderation/internal/domain"
	"avion-moderation/internal/usecase"
	"avion-moderation/tests/mocks"
)

func TestCreateReportCommandUseCase_Execute(t *testing.T) {
	type fields struct {
		reportRepo        *mocks.MockReportRepository
		violationDetector *mocks.MockViolationDetectionService
	}
	type args struct {
		ctx context.Context
		cmd usecase.CreateReportCommand
	}
	tests := []struct {
		name    string
		setup   func(f *fields)
		args    args
		want    domain.ReportID
		wantErr error
	}{
		{
			name: "正常系: 有効な通報を作成",
			setup: func(f *fields) {
				f.reportRepo.EXPECT().
					Create(gomock.Any(), gomock.Any()).
					Return(nil)
				f.violationDetector.EXPECT().
					DetectViolation(gomock.Any(), gomock.Any(), gomock.Any()).
					Return(domain.ViolationLevelMedium, &domain.DetectionResult{}, nil)
			},
			args: args{
				ctx: context.Background(),
				cmd: usecase.CreateReportCommand{
					ReporterID:  "user-123",
					TargetType:  domain.TargetTypeDrop,
					TargetID:    "drop-456",
					Reason:      domain.ReportReasonSpam,
					Description: "スパムコンテンツ",
				},
			},
			wantErr: nil,
		},
		{
			name: "異常系: 重複通報でエラー",
			setup: func(f *fields) {
				f.reportRepo.EXPECT().
					Create(gomock.Any(), gomock.Any()).
					Return(domain.ErrDuplicateReport)
			},
			args: args{
				ctx: context.Background(),
				cmd: usecase.CreateReportCommand{
					ReporterID: "user-123",
					TargetType: domain.TargetTypeDrop,
					TargetID:   "drop-456",
					Reason:     domain.ReportReasonSpam,
				},
			},
			wantErr: domain.ErrDuplicateReport,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ctrl := gomock.NewController(t)
			defer ctrl.Finish()

			f := &fields{
				reportRepo:        mocks.NewMockReportRepository(ctrl),
				violationDetector: mocks.NewMockViolationDetectionService(ctrl),
			}
			if tt.setup != nil {
				tt.setup(f)
			}

			uc := usecase.NewCreateReportCommandUseCase(f.reportRepo, f.violationDetector)
			got, err := uc.Execute(tt.args.ctx, tt.args.cmd)

			if !errors.Is(err, tt.wantErr) {
				t.Errorf("error = %v, wantErr %v", err, tt.wantErr)
			}
			if tt.wantErr == nil {
				if diff := cmp.Diff(tt.want, got); diff != "" {
					t.Errorf("mismatch (-want +got):\n%s", diff)
				}
			}
		})
	}
}
```

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

詳細は[共通E2Eテスト戦略ドキュメント](../common/e2e-testing-strategy.md)および[共通テスト戦略ドキュメント](../common/testing-strategy.md)を参照してください。

## 3. エラーハンドリング戦略

> **詳細は [designdoc-infra-testing.md](./designdoc-infra-testing.md) を参照してください。**

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

## 4. 構造化ログ戦略

> **詳細は [designdoc-infra-testing.md](./designdoc-infra-testing.md) を参照してください。**

このサービスでは、[共通Observabilityパッケージ設計](../common/observability/observability-package-design.md)に従って構造化ログを実装します。

## 5. 技術スタック

このサービスでは、[共通Goバックエンド技術スタックガイドライン](../common/architecture/go-backend-framework.md)に従った実装を行います。

### 主要技術
- **言語**: Go 1.25.1
- **HTTPルーティング**: Chi v5
- **RPC**: ConnectRPC
- **ミドルウェア**: 標準net/httpベースの共通ミドルウェア
- **DB**: PostgreSQL 17
- **キャッシュ**: Redis 8+
- **イベント配信**: NATS JetStream
- **ML Framework**: ONNX Runtime（自前モデルによる推論実行基盤）
- **画像認識**: ONNX Runtime + 自前トレーニング済みモデル
- **テキスト分析**: ONNX Runtime + 自前トレーニング済みモデル
- **全文検索**: PostgreSQL Full Text Search
- **監視**: OpenTelemetry

詳細な実装パターンおよびライブラリの使用方法については、[ガイドライン](../common/architecture/go-backend-framework.md)を参照してください。

## 6. Background & Links (背景と関連リンク)

- SNSプラットフォームの健全性維持はユーザー信頼とサービス持続性の基盤。
- モデレーション機能をシステム管理から分離し、専門サービス化することで、変更容易性とスケーラビリティを確保。
- 機械学習を活用した自動モデレーションにより、モデレーターの負担軽減と効率化を実現。
- [PRD: avion-moderation](./prd.md)
- [Avion アーキテクチャ概要](../common/architecture.md)
- [avion-drop Design Doc](../avion-drop/designdoc.md)
- [avion-system-admin Design Doc](../avion-system-admin/designdoc.md)

---

## 7. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

#### プラットフォーム全体モデレーション（グローバルルール）の責務

本サービスは **プラットフォーム全体のモデレーションポリシー** を担当し、以下の責務を持つ:

- **法的要件の遵守**: CSAM（児童性的虐待素材）、テロリズム関連コンテンツ等、法的に除去が義務付けられるコンテンツの検出・即時除去
- **プラットフォーム利用規約の適用**: プラットフォーム全体に適用される利用規約・コミュニティガイドラインの強制
- **スパム検知・対応**: クロスコミュニティのスパム検知、自動対応、スパムアカウントの制裁
- **クロスコミュニティの通報処理**: コミュニティをまたぐ通報や、コミュニティモデレーターからエスカレーションされた通報の処理

#### グローバルルールの優先度

- **グローバルルールはコミュニティのローカルルールより常に優先される**
- コミュニティオーナー・モデレーターは、プラットフォームのグローバルポリシーを緩和・無効化することはできない
- グローバルルール違反が検知された場合、コミュニティのローカルルール設定に関係なく即座にコンテンツ除去・制裁を実行する

#### ML/画像認識基盤

- **ONNX Runtime** を統一的なML推論基盤として採用
- テキスト分類・画像認識ともに自前トレーニング済みモデルをONNX形式でデプロイ
- 外部ML APIサービス（Google Vision、AWS Rekognition等）には依存しない

#### 機能実装

- 通報の受付、処理、追跡を行うConnectRPC APIの実装
- コンテンツフィルタリングエンジンの実装（NGワード、正規表現、ML分類器）
- モデレーションアクションのConnectRPC API実装（警告、削除、凍結等）
- 異議申し立てプロセスの実装
- インスタンスポリシー管理（ブロック、サイレンス等）
- モデレーションデータのPostgreSQLへの永続化
- フィルタールールとNGワードのRedisキャッシュ
- モデレーションイベントの発行（NATS JetStream）
- モデレーターダッシュボードとキュー管理
- Go言語で実装し、Kubernetes上でのステートレス運用
- OpenTelemetryによるトレーシング・メトリクス・ロギング対応

### Non-Goals (やらないこと)

- **システム設定管理:** `avion-system-admin` が担当
- **バックアップ処理:** `avion-system-admin` が担当
- **レート制限設定:** `avion-system-admin` が担当
- **ユーザー認証:** `avion-auth` が担当
- **個人レベルのブロック/ミュート:** `avion-user` が担当
- **メディアファイルの直接管理:** `avion-media` が担当
- **コンテンツの作成・編集:** 投稿内容の修正は行わない（削除のみ）
- **直接的な通知配信:** `avion-notification` が担当

> **サービス間責務境界（決定済み）**: (1) コンテンツフィルタリング: 非同期イベント検査方式。`avion-drop` が `DropCreatedEvent` を発行し、本サービスが非同期で検査する。違反検出時は本サービスが事後削除・制限アクションを実行する。(2) モデレーション階層構造: 本サービスのプラットフォーム全体ポリシーが `avion-community` の `auto_moderation_rules`（コミュニティローカル）を常に上回る。コミュニティオーナーはプラットフォームポリシーを緩和できない。(3) NSFW/センシティブ管理: 本サービスが最終決定権を持ち、`avion-media` のNSFWフラグおよび `avion-drop` のユーザー自己申告を上書き可能。優先度順: 本サービス > media ML検出 > ユーザー自己申告。(4) 監査ログ: 分離維持。本サービスはハッシュチェーン付きモデレーション監査ログを保持。`avion-system-admin` が統合検索APIを提供し横断検索を可能にする。(5) コンテンツモデレーション vs プライバシー制御: 本サービスはプラットフォーム全体のコンテンツ違反判定（スパム、ヘイトスピーチ、違法コンテンツ等）を担当する。個人のプライバシー制御（ブロック、ミュート等）は `avion-user` が担当する。本サービスの判定はプラットフォーム全体に適用され、個人設定に関係なく強制される。(6) 管理機能の範囲: 本サービスはコンテンツモデレーション固有の管理機能（通報処理、コンテンツ非表示、アカウント制限、フィルタリングルール管理、モデレーション監査ログ、異議申し立て処理、インスタンスポリシー管理）のみを保持する。システム横断的な設定・監査は `avion-system-admin` が担当する。

## 8. Architecture (どうやって作る？)

### 8.0. avion-community との連携フロー（モデレーション責務境界）

本サービス（グローバルルール）と avion-community（ローカルルール）は以下のフローで連携する:

1. **コンテンツ投稿時**: avion-community がコミュニティ固有のローカルルール判定を実行
2. **ローカルルール違反なし → グローバルルール判定**: avion-moderation が非同期でプラットフォーム全体のグローバルルール判定を実行（`DropCreatedEvent` 等のイベント駆動）
3. **グローバルルール違反検知 → 即座にコンテンツ除去**: コミュニティのローカルルール設定に関係なく、法的要件・プラットフォーム利用規約違反コンテンツは即座に除去される
4. **通報時**: avion-community のコミュニティモデレーターが最初に確認 → コミュニティスコープで解決できない場合やグローバルポリシー違反が疑われる場合は avion-moderation へエスカレーション

```
┌─────────────────────────────────────────────────────────┐
│                   コンテンツ投稿                         │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│  avion-community: ローカルルール判定                     │
│  (コミュニティ固有のキーワードフィルタ等)                  │
└─────────────────────┬───────────────────────────────────┘
                      │ 違反なし
                      ▼
┌─────────────────────────────────────────────────────────┐
│  avion-moderation: グローバルルール判定（非同期）          │
│  (法的要件、利用規約、スパム検知、ONNX Runtimeによる      │
│   ML分類)                                               │
└─────────────────────┬───────────────────────────────────┘
                      │ 違反検知
                      ▼
┌─────────────────────────────────────────────────────────┐
│  即座にコンテンツ除去・制裁実行                           │
│  (ローカルルール設定に関係なく強制)                       │
└─────────────────────────────────────────────────────────┘
```

```
┌─────────────────────────────────────────────────────────┐
│                    通報受付                              │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│  avion-community: コミュニティモデレーターが確認          │
│  (コミュニティローカルスコープでの対応)                   │
└─────────────────────┬───────────────────────────────────┘
                      │ エスカレーション
                      ▼
┌─────────────────────────────────────────────────────────┐
│  avion-moderation: グローバルスコープでの通報処理         │
│  (プラットフォーム全体ポリシーに基づく判定)               │
└─────────────────────────────────────────────────────────┘
```

### 8.1. レイヤードアーキテクチャ (DDD準拠)

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
  - **InstancePolicy**: インスタンスポリシーを管理。技術的な遮断実行はavion-activitypubに委譲する。ポリシー変更時にInstancePolicyChangedEvent（`moderation.instance_policy.changed`）を発行し、avion-activitypubのBlockedDomain Aggregateが同期する
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
    - *ビジネスルール*: 法的要求対応、証拠保全、データ保持期間管理（7年）
- **Entities:**
  - ReportEvidence: 通報証拠
  - ModerationNote: モデレーターメモ
  - FilterCondition: フィルター条件
  - AppealEvidence: 異議申し立て証拠
  - InstanceIncident: インスタンスインシデント
- **Value Objects:**
  - ReportID, ActionID, FilterID, AppealID, ModeratorID (UUID v7)
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
    reportID := domain.NewReportID() // UUID v7
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

    // 6. ドメインイベント発行（NATS JetStream）
    event := domain.NewReportCreatedEvent(reportID, cmd.ReporterID, cmd.TargetID, priority)
    err = h.eventPublisher.PublishReportCreated(ctx, event)
    if err != nil {
        log.Warn("Failed to publish report created event", zap.Error(err), zap.String("report_id", string(reportID)))
    }

    return reportID, nil
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
            time.Sleep(time.Duration(attempt+1) * 100 * time.Millisecond)
            continue
        }

        return err
    }

    return domain.ErrOptimisticLockFailure
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
  - ONNXRuntimeMLService (ONNX Runtime - テキスト分類・画像認識)
- **Event Publishers:**
  - ReportEventPublisher (NATS JetStream)
  - ModerationEventPublisher (NATS JetStream)
  - FilterEventPublisher (NATS JetStream)
  - AppealEventPublisher (NATS JetStream)

#### Handler Layer (ハンドラー層)
- **ConnectRPC Handlers:**
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

### 8.2. システム構成

```
┌─────────────────────────────────────────┐
│          Handler Layer                   │
│  - ConnectRPC Handlers                  │
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
│  - Repositories (PostgreSQL 17)         │
│  - External APIs                        │
│  - ML Services                          │
│  - Cache (Redis 8+)                     │
│  - Events (NATS JetStream)              │
└─────────────────────────────────────────┘
```

## 9. Use Cases / Key Flows (主な使い方・処理の流れ)

### 9.1. 通報処理フロー

#### 通報受付と初期処理
- **フロー 1: 通報作成 (Command)**
  1. Gateway → CreateReportCommandHandler: `CreateReport` ConnectRPC Call (reporter_id, target_type, target_id, reason, description)
  2. CreateReportCommandHandler: CreateReportCommandUseCaseを呼び出し
  3. CreateReportCommandUseCase: Report Aggregateを生成し、重複チェック実行
  4. ViolationDetectionService: 通報理由と対象コンテンツの自動評価
  5. PriorityCalculationService: 通報者信頼度とコンテンツ履歴から優先度計算
  6. ReportRepository: 通報データの永続化
  7. ReportEventPublisher: `avion.moderation.report.created` イベント発行（NATS JetStream）
  8. CreateReportCommandHandler → Gateway: `CreateReportResponse { report_id: "..." }`

- **フロー 2: 自動フィルタリング処理**
  1. ContentCreatedEventHandler: `avion.drop.drop.created` イベント受信
  2. FilterContentCommandUseCase: ContentFilter実行
  3. FilterEngine: 並列フィルター処理（NGワード、正規表現、ML分類）
  4. MLClassifier: 機械学習による有害コンテンツ判定
  5. 閾値判定: 自動アクション実行 or モデレーションキュー追加
  6. FilterEventPublisher: `avion.moderation.filter.updated` イベント発行

- **フロー 3: モデレーター処理**
  1. GetModerationQueueQueryHandler: 優先度順のキュー取得
  2. AssignReportCommandHandler: 通報の担当者割り当て
  3. GetReportDetailsQueryHandler: 通報詳細と証拠の取得
  4. GetViolationContextQueryHandler: 対象ユーザーの違反履歴取得
  5. ExecuteModerationActionCommandHandler: 判定とアクション実行
  6. ModerationEventPublisher: `avion.moderation.action.executed` イベント発行

### 9.2. 異議申し立てフロー

- **フロー 4: 異議申し立て作成 (Command)**
  1. User → CreateAppealCommandHandler: 異議申し立て作成
  2. CreateAppealCommandUseCase: AppealAggregate生成、期限設定
  3. AppealRepository: 異議申し立てデータ永続化
  4. AppealEventPublisher: `avion.moderation.appeal.created` イベント発行
  5. NotificationService: モデレーターへの通知送信

- **フロー 5: 異議申し立てレビュー (Command)**
  1. ReviewAppealCommandHandler: レビュー実行
  2. ReviewAppealCommandUseCase: 証拠評価と判定
  3. EscalationService: 複雑なケースのエスカレーション判断
  4. RevertModerationActionCommandHandler: 必要に応じてアクション取り消し
  5. AppealEventPublisher: `avion.moderation.appeal.resolved` イベント発行

### 9.3. インスタンスポリシー管理フロー

- **フロー 6: インスタンスポリシー設定 (Command)**
  1. SetInstancePolicyCommandHandler: ポリシー設定要求
  2. SetInstancePolicyCommandUseCase: InstancePolicyAggregate生成
  3. PolicyValidationService: ポリシーの妥当性検証
  4. InstancePolicyRepository: ポリシー設定の永続化
  5. InstancePolicyEventPublisher: `moderation.instance_policy.changed` イベント発行（avion-activitypubのBlockedDomain Aggregateが購読し技術的遮断を同期実行）

- **フロー 7: レピュテーション評価**
  1. ReputationUpdateJob: 定期的なレピュテーション計算
  2. InstanceReputationAggregate: スパムスコア、違反率の更新
  3. AutoPolicyService: 自動ポリシー適用判断
  4. InstancePolicyRepository: 自動ポリシーの永続化

### 9.4. バッチ処理フロー

- **フロー 8: 優先度再計算 (5分ごと)**
  1. PriorityRecalculationJob: 通報集約とSLA期限チェック
  2. ReportAggregate: 優先度値の更新
  3. ModerationQueue: キュー順序の再編成

- **フロー 9: 期限切れ処理 (1時間ごと)**
  1. ExpirationProcessingJob: 一時停止の自動解除
  2. ModerationActionAggregate: 期限切れアクションの無効化
  3. AppealAggregate: 期限切れ異議申し立ての自動却下

## 10. データベースマイグレーション戦略

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

標準テンプレートは[マイグレーション設定テンプレート](../templates/migration-setup-template.md)を参照してください。

## 11. Detailed Design (詳細設計)

### 11.1. API設計

#### ConnectRPC API 定義

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

### 11.2. データモデル

> **注意**: マイクロサービス設計に基づき、本サービスのDBスキーマは他サービスのテーブルへの外部キー制約を持ちません。`reporter_user_id`、`assigned_to`、`moderator_id` 等のユーザーIDは、アプリケーション層で `avion-user` サービスへのRPC呼び出しにより整合性を確認します。

#### 通報関連

```sql
-- 通報（UUID v7使用）
CREATE TABLE reports (
    report_id UUID PRIMARY KEY, -- UUID v7
    reporter_user_id UUID NOT NULL, -- アプリ層で整合性チェック
    target_type TEXT NOT NULL CHECK (target_type IN ('user', 'drop', 'media', 'instance')),
    target_id UUID NOT NULL,
    reason TEXT NOT NULL CHECK (reason IN ('spam', 'harassment', 'violence', 'illegal', 'misinformation', 'privacy', 'copyright', 'other')),
    description TEXT,
    status TEXT NOT NULL CHECK (status IN ('pending', 'assigned', 'reviewing', 'resolved', 'dismissed', 'escalated')),
    priority INT DEFAULT 0 CHECK (priority >= 0 AND priority <= 100),
    assigned_to UUID, -- アプリ層で整合性チェック
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMPTZ,
    resolved_by UUID,
    resolution_note TEXT,
    is_escalated BOOLEAN DEFAULT false,
    escalated_to UUID,
    escalated_at TIMESTAMPTZ,
    report_aggregation_id UUID,
    escalation_level INT DEFAULT 0,
    sla_deadline TIMESTAMPTZ,
    auto_flagged BOOLEAN DEFAULT false,
    version INT DEFAULT 1, -- 楽観的ロック用
    CONSTRAINT check_escalation_logic
        CHECK ((is_escalated = false AND escalated_to IS NULL AND escalated_at IS NULL) OR
               (is_escalated = true AND escalated_to IS NOT NULL AND escalated_at IS NOT NULL))
);

-- 通報証拠
CREATE TABLE report_evidences (
    evidence_id UUID PRIMARY KEY, -- UUID v7
    report_id UUID REFERENCES reports(report_id) ON DELETE CASCADE,
    evidence_type TEXT NOT NULL CHECK (evidence_type IN ('screenshot', 'url', 'text', 'media_file')),
    evidence_data JSONB NOT NULL,
    file_hash TEXT, -- SHA-256
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- モデレーションケース（複数通報の統合管理）
CREATE TABLE moderation_cases (
    case_id UUID PRIMARY KEY, -- UUID v7
    case_status TEXT NOT NULL CHECK (case_status IN ('open', 'investigating', 'resolved', 'escalated')),
    primary_moderator_id UUID,
    secondary_moderator_ids UUID[],
    overall_priority INT DEFAULT 0,
    overall_severity TEXT CHECK (overall_severity IN ('low', 'medium', 'high', 'critical')),
    ai_consent_status TEXT CHECK (ai_consent_status IN ('consented', 'not_consented', 'mixed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMPTZ,
    resolution_summary TEXT
);

-- ケースと通報の関連付け
CREATE TABLE case_reports (
    case_id UUID REFERENCES moderation_cases(case_id) ON DELETE CASCADE,
    report_id UUID REFERENCES reports(report_id) ON DELETE CASCADE,
    added_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (case_id, report_id)
);

-- 通報集約（同一対象への複数通報）
CREATE TABLE report_aggregations (
    target_type TEXT NOT NULL,
    target_id UUID NOT NULL,
    report_count INT DEFAULT 1,
    unique_reporters INT DEFAULT 1,
    first_reported_at TIMESTAMPTZ NOT NULL,
    last_reported_at TIMESTAMPTZ NOT NULL,
    aggregated_priority INT DEFAULT 0,
    PRIMARY KEY (target_type, target_id)
);

-- コミュニティ投票
CREATE TABLE community_votes (
    vote_id UUID PRIMARY KEY, -- UUID v7
    target_type TEXT NOT NULL,
    target_id UUID NOT NULL,
    voter_id UUID NOT NULL,
    vote_type TEXT NOT NULL CHECK (vote_type IN ('approve', 'reject', 'unsure')),
    voter_trust_level INT NOT NULL CHECK (voter_trust_level >= 0 AND voter_trust_level <= 3),
    vote_weight FLOAT DEFAULT 1.0,
    voted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
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
    decided_at TIMESTAMPTZ,
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
    last_activity_at TIMESTAMPTZ,
    level_updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
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
    consent_updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    consent_version TEXT NOT NULL
);

-- 通報者信頼度
CREATE TABLE reporter_credibility (
    user_id UUID PRIMARY KEY,
    total_reports INT DEFAULT 0,
    valid_reports INT DEFAULT 0,
    false_reports INT DEFAULT 0,
    credibility_score FLOAT DEFAULT 0.5 CHECK (credibility_score >= 0 AND credibility_score <= 1),
    last_updated TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

#### モデレーションアクション

```sql
-- モデレーションアクション
CREATE TABLE moderation_actions (
    action_id UUID PRIMARY KEY, -- UUID v7
    action_type TEXT NOT NULL CHECK (action_type IN ('warn', 'delete_content', 'suspend_account', 'ban_account', 'shadowban', 'restrict_reach', 'media_removal', 'silence_instance')),
    target_type TEXT NOT NULL,
    target_id UUID NOT NULL,
    moderator_id UUID, -- アプリ層で整合性チェック
    reason TEXT NOT NULL,
    details JSONB,
    severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    executed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true,
    reverted_at TIMESTAMPTZ,
    reverted_by UUID,
    revert_reason TEXT,
    report_ids UUID[] DEFAULT '{}'
);

-- モデレーションテンプレート
CREATE TABLE moderation_templates (
    template_id UUID PRIMARY KEY, -- UUID v7
    name TEXT NOT NULL UNIQUE,
    action_type TEXT NOT NULL,
    reason_template TEXT NOT NULL,
    default_duration INTERVAL,
    severity TEXT NOT NULL,
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    usage_count INT DEFAULT 0
);

-- モデレーターノート
CREATE TABLE moderator_notes (
    note_id UUID PRIMARY KEY, -- UUID v7
    target_type TEXT NOT NULL,
    target_id UUID NOT NULL,
    moderator_id UUID NOT NULL,
    note TEXT NOT NULL,
    is_internal BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ
);

-- 違反履歴
CREATE TABLE violation_history (
    user_id UUID NOT NULL,
    action_id UUID REFERENCES moderation_actions(action_id),
    action_type TEXT NOT NULL,
    severity TEXT NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, action_id)
);
```

#### フィルタリング

```sql
-- コンテンツフィルター
CREATE TABLE content_filters (
    filter_id UUID PRIMARY KEY, -- UUID v7
    filter_name TEXT NOT NULL UNIQUE,
    filter_type TEXT NOT NULL CHECK (filter_type IN ('keyword', 'regex', 'ml_classifier', 'domain_block', 'image_hash', 'url_reputation')),
    pattern TEXT,
    ml_model_id TEXT,
    severity TEXT NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    action TEXT NOT NULL CHECK (action IN ('flag', 'hold', 'reject', 'shadowban', 'auto_delete')),
    confidence_threshold FLOAT DEFAULT 0.7 CHECK (confidence_threshold >= 0.0 AND confidence_threshold <= 1.0),
    priority INT DEFAULT 0,
    is_system BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    effectiveness_score FLOAT DEFAULT 0.0 CHECK (effectiveness_score >= 0.0 AND effectiveness_score <= 1.0)
);

-- NGワード辞書
CREATE TABLE ng_words (
    word_id UUID PRIMARY KEY, -- UUID v7
    word TEXT NOT NULL UNIQUE,
    category TEXT NOT NULL,
    severity TEXT NOT NULL,
    language TEXT DEFAULT 'ja',
    added_by UUID NOT NULL,
    added_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    match_count INT DEFAULT 0,
    false_positive_count INT DEFAULT 0,
    CONSTRAINT check_word_not_empty CHECK (LENGTH(TRIM(word)) > 0)
);

-- フィルター条件
CREATE TABLE filter_conditions (
    condition_id UUID PRIMARY KEY, -- UUID v7
    filter_id UUID REFERENCES content_filters(filter_id) ON DELETE CASCADE,
    condition_type TEXT NOT NULL,
    pattern TEXT NOT NULL,
    threshold FLOAT,
    weight FLOAT DEFAULT 1.0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- フィルター適用ログ
CREATE TABLE filter_logs (
    log_id UUID PRIMARY KEY, -- UUID v7
    filter_id UUID REFERENCES content_filters(filter_id),
    content_type TEXT NOT NULL,
    content_id UUID NOT NULL,
    matched_text TEXT,
    confidence_score FLOAT,
    action_taken TEXT NOT NULL,
    is_false_positive BOOLEAN,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

#### インスタンスポリシー

```sql
-- インスタンスポリシー
CREATE TABLE instance_policies (
    domain TEXT PRIMARY KEY,
    policy_type TEXT NOT NULL CHECK (policy_type IN ('block', 'silence', 'media_removal', 'reject_reports', 'quarantine')),
    reason TEXT,
    expires_at TIMESTAMPTZ,
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
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
    last_incident_at TIMESTAMPTZ,
    reputation_score FLOAT DEFAULT 50.0 CHECK (reputation_score >= 0 AND reputation_score <= 100),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- インスタンスインシデント
CREATE TABLE instance_incidents (
    incident_id UUID PRIMARY KEY, -- UUID v7
    domain TEXT NOT NULL,
    incident_type TEXT NOT NULL,
    severity TEXT NOT NULL,
    description TEXT,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMPTZ,
    resolution TEXT
);
```

#### 異議申し立て

```sql
-- 異議申し立て
CREATE TABLE appeals (
    appeal_id UUID PRIMARY KEY, -- UUID v7
    action_id UUID REFERENCES moderation_actions(action_id),
    appellant_user_id UUID NOT NULL,
    appeal_reason TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'reviewing', 'upheld', 'overturned', 'dismissed')),
    priority INT DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deadline_at TIMESTAMPTZ NOT NULL,
    assigned_to UUID,
    reviewed_at TIMESTAMPTZ,
    reviewed_by UUID,
    review_note TEXT,
    outcome_reason TEXT
);

-- 異議申し立て証拠
CREATE TABLE appeal_evidences (
    evidence_id UUID PRIMARY KEY, -- UUID v7
    appeal_id UUID REFERENCES appeals(appeal_id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    supporting_data JSONB,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- エスカレーション履歴
CREATE TABLE escalations (
    escalation_id UUID PRIMARY KEY, -- UUID v7
    source_type TEXT NOT NULL CHECK (source_type IN ('report', 'appeal')),
    source_id UUID NOT NULL,
    escalated_from UUID NOT NULL,
    escalated_to UUID NOT NULL,
    escalation_reason TEXT NOT NULL,
    urgency TEXT NOT NULL CHECK (urgency IN ('low', 'medium', 'high', 'critical')),
    escalated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMPTZ,
    resolution_note TEXT
);
```

#### 監査ログ・モデレーションキュー

```sql
-- モデレーション監査ログ（パーティション対応）
CREATE TABLE moderation_logs (
    log_id UUID NOT NULL, -- UUID v7
    event_type TEXT NOT NULL,
    entity_type TEXT NOT NULL CHECK (entity_type IN ('report', 'action', 'appeal', 'filter', 'policy', 'user', 'content')),
    entity_id UUID NOT NULL,
    actor_type TEXT NOT NULL CHECK (actor_type IN ('user', 'moderator', 'admin', 'system', 'ml_classifier')),
    actor_id UUID,
    action_details JSONB NOT NULL,
    previous_state JSONB,
    new_state JSONB,
    ip_address INET,
    user_agent TEXT,
    session_id TEXT,
    trace_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    retention_until TIMESTAMPTZ NOT NULL DEFAULT (CURRENT_TIMESTAMP + INTERVAL '7 years'),
    PRIMARY KEY (log_id, created_at)
) PARTITION BY RANGE (created_at);

-- モデレーションキュー
CREATE TABLE moderation_queue (
    queue_id UUID PRIMARY KEY, -- UUID v7
    item_type TEXT NOT NULL CHECK (item_type IN ('report', 'appeal', 'auto_flagged')),
    item_id UUID NOT NULL,
    priority INT NOT NULL,
    category TEXT NOT NULL,
    assigned_to UUID,
    status TEXT NOT NULL CHECK (status IN ('pending', 'assigned', 'in_progress', 'completed')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    assigned_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    sla_deadline TIMESTAMPTZ,
    UNIQUE(item_type, item_id)
);

-- モデレーションワークフロー
CREATE TABLE moderation_workflows (
    workflow_id UUID PRIMARY KEY, -- UUID v7
    workflow_name TEXT NOT NULL,
    trigger_conditions JSONB NOT NULL,
    action_sequence JSONB NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- フィルター性能メトリクス
CREATE TABLE filter_metrics (
    metric_id UUID PRIMARY KEY, -- UUID v7
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

#### インデックス

```sql
-- 通報テーブル
CREATE INDEX idx_reports_status_priority ON reports(status, priority DESC, created_at) WHERE status IN ('pending', 'assigned', 'reviewing');
CREATE INDEX idx_reports_target ON reports(target_type, target_id);
CREATE INDEX idx_reports_reporter ON reports(reporter_user_id, created_at DESC);
CREATE INDEX idx_reports_assigned ON reports(assigned_to, status) WHERE assigned_to IS NOT NULL;
CREATE INDEX idx_reports_escalated ON reports(is_escalated, escalated_at) WHERE is_escalated = true;
CREATE INDEX idx_reports_sla ON reports(sla_deadline, status) WHERE status != 'resolved' AND sla_deadline IS NOT NULL;

-- モデレーションアクション
CREATE INDEX idx_moderation_actions_target ON moderation_actions(target_type, target_id, is_active);
CREATE INDEX idx_moderation_actions_moderator ON moderation_actions(moderator_id, executed_at DESC);
CREATE INDEX idx_moderation_actions_active ON moderation_actions(is_active, expires_at) WHERE is_active = true;
CREATE INDEX idx_moderation_actions_severity ON moderation_actions(severity, action_type, executed_at);

-- フィルター
CREATE INDEX idx_content_filters_active ON content_filters(is_active, priority DESC) WHERE is_active = true;
CREATE INDEX idx_ng_words_active ON ng_words(is_active, category, language) WHERE is_active = true;
CREATE INDEX idx_filter_logs_time ON filter_logs(created_at DESC);
CREATE INDEX idx_filter_logs_filter ON filter_logs(filter_id, created_at DESC);

-- 異議申し立て
CREATE INDEX idx_appeals_status ON appeals(status, deadline_at) WHERE status IN ('pending', 'reviewing');
CREATE INDEX idx_appeals_appellant ON appeals(appellant_user_id, created_at DESC);
CREATE INDEX idx_escalations_source ON escalations(source_type, source_id);

-- インスタンス
CREATE INDEX idx_instance_policies_active ON instance_policies(is_active, policy_type) WHERE is_active = true;
CREATE INDEX idx_instance_reputations_score ON instance_reputations(reputation_score, last_incident_at);
CREATE INDEX idx_instance_incidents_domain ON instance_incidents(domain, occurred_at DESC);

-- キュー
CREATE INDEX idx_queue_priority ON moderation_queue(status, priority DESC, created_at) WHERE status IN ('pending', 'assigned');
CREATE INDEX idx_queue_sla ON moderation_queue(sla_deadline) WHERE sla_deadline IS NOT NULL AND status != 'completed';

-- 監査ログ
CREATE INDEX idx_moderation_logs_entity ON moderation_logs(entity_type, entity_id, created_at DESC);
CREATE INDEX idx_moderation_logs_actor ON moderation_logs(actor_type, actor_id, created_at DESC);
CREATE INDEX idx_moderation_logs_retention ON moderation_logs(retention_until) WHERE retention_until <= CURRENT_TIMESTAMP;

-- 違反履歴
CREATE INDEX idx_violation_history_user ON violation_history(user_id, occurred_at DESC);
```

### 11.3. フィルタリングエンジン

> **詳細は [designdoc-content-filter.md](./designdoc-content-filter.md) を参照してください。**

## 12. イベント設計

### 発行イベント（NATS JetStream）

```json
// avion.moderation.report.created
{
  "event_type": "avion.moderation.report.created",
  "report_id": "01953a1d-...",
  "reporter_id": "01953a1c-...",
  "target_type": "user|drop|media|instance",
  "target_id": "01953a1b-...",
  "reason": "spam|harassment|violence|illegal|misinformation|privacy|copyright|other",
  "priority": 75,
  "created_at": "2026-03-14T00:00:00Z"
}

// avion.moderation.action.executed
{
  "event_type": "avion.moderation.action.executed",
  "action_id": "01953a1e-...",
  "action_type": "warn|delete_content|suspend_account|ban_account|shadowban|restrict_reach",
  "target_type": "user|drop|media",
  "target_id": "01953a1f-...",
  "moderator_id": "01953a20-...",
  "severity": "low|medium|high|critical",
  "expires_at": "2026-04-14T00:00:00Z",
  "executed_at": "2026-03-14T00:00:00Z"
}

// avion.moderation.filter.updated
{
  "event_type": "avion.moderation.filter.updated",
  "filter_id": "01953a21-...",
  "content_type": "drop|comment",
  "content_id": "01953a22-...",
  "action": "flag|hold|reject|shadowban|auto_delete",
  "confidence": 0.95,
  "created_at": "2026-03-14T00:00:00Z"
}

// avion.moderation.appeal.resolved
{
  "event_type": "avion.moderation.appeal.resolved",
  "appeal_id": "01953a23-...",
  "action_id": "01953a24-...",
  "outcome": "upheld|overturned|dismissed",
  "reviewer_id": "01953a25-...",
  "resolved_at": "2026-03-14T00:00:00Z"
}

// avion.moderation.instance_policy.changed
{
  "event_type": "avion.moderation.instance_policy.changed",
  "domain": "example.com",
  "policy_type": "block|silence|media_removal|reject_reports|quarantine",
  "reason": "spam|violation",
  "applied_at": "2026-03-14T00:00:00Z"
}
```

### 購読イベント

```json
// content.created（フィルタリング対象）
{
  "event_type": "avion.drop.drop.created",
  "content_type": "drop|comment",
  "content_id": "uuid",
  "user_id": "uuid",
  "content": "text content",
  "media_urls": ["url1", "url2"],
  "created_at": "2026-03-14T00:00:00Z"
}

// user.registered（レピュテーション初期化）
{
  "event_type": "avion.user.profile.created",
  "user_id": "uuid",
  "instance_domain": "example.com",
  "registered_at": "2026-03-14T00:00:00Z"
}
```

## 13. Integration Specifications (連携仕様)

### 13.1. avion-drop との連携

**Purpose:** コンテンツ削除・制限の実行

**Integration Method:** ConnectRPC

**Data Flow:**
1. モデレーションアクション決定
2. avion-drop.ContentService.DeleteContent() 呼び出し
3. 削除結果の確認と記録
4. イベント発行

**Error Handling:** 削除失敗時は手動確認キューに追加

### 13.2. avion-notification との連携

**Purpose:** モデレーション結果の通知配信

**Integration Method:** Events (NATS JetStream)

**Data Flow:**
1. モデレーションアクション完了
2. `avion.moderation.action.executed` イベント発行
3. avion-notification がイベントを購読
4. 対象ユーザーと通報者に通知配信

**Error Handling:** 通知失敗時は再試行キューに追加

## 14. Operations & Monitoring (運用と監視)

### 14.1. Health Checks
- `/health`: Basic liveness check
- `/ready`: Readiness check (database connectivity, Redis connection, ML service availability)

### 14.2. Key Metrics
- `moderation_reports_created_total`: Total reports created counter
- `moderation_actions_executed_total`: Total moderation actions executed counter
- `moderation_queue_size`: Current moderation queue size gauge
- `moderation_processing_duration_seconds`: Processing time histogram
- `moderation_filter_hits_total`: Content filter matches counter
- `moderation_ml_classification_duration_seconds`: ML classification time histogram
- `moderation_appeals_created_total`: Appeals created counter
- `moderation_sla_violations_total`: SLA deadline violations counter

### 14.3. Alerts
- **Critical**: Queue size > 10,000 items
- **Critical**: SLA breach rate > 5%
- **Critical**: ML service unavailable
- **Warning**: Processing delay > 1 hour
- **Warning**: False positive rate > 10%
- **Info**: Filter effectiveness degradation

## 15. Non-Functional Requirements (非機能要件)

### 15.1. 可用性
- SLA: 99.9%
- RTO: 10分
- RPO: 5分

### 15.2. パフォーマンス
- 通報作成: p99 < 100ms
- フィルタリング: p99 < 200ms
- モデレーションアクション: p99 < 500ms
- キュー取得: p99 < 100ms
- ML推論: p99 < 300ms
- スループット: 10,000 req/s

### 15.3. データ保持
- 通報記録: 1年
- モデレーションログ: 2年
- フィルターログ: 90日
- 削除コンテンツ: 90日（法的要求対応）
- 異議申し立て: 2年
- 監査ログ: 7年

## 16. Configuration Management (設定管理)

このサービスは、[共通環境変数管理パターン](../common/infrastructure/environment-variables.md)に従って設定管理を実装します。

### 16.1. 環境変数一覧

#### 必須環境変数
- `DATABASE_URL`: PostgreSQL接続URL
- `REDIS_URL`: Redis接続URL
- `NATS_URL`: NATS JetStream接続URL
- `ONNX_MODEL_PATH`: ONNX Runtimeモデルファイルのディレクトリパス（テキスト分類・画像認識用の自前トレーニング済みモデル）

#### オプション環境変数（デフォルト値あり）
- `PORT`: HTTPサーバーポート (デフォルト: 8089)
- `GRPC_PORT`: gRPCサーバーポート (デフォルト: 9099)
- `MODERATION_THRESHOLD`: モデレーション閾値 (デフォルト: 0.7)
- `AUTO_BAN_THRESHOLD`: 自動BANの閾値 (デフォルト: 0.95)
- `FILTER_WORD_LIST_PATH`: フィルターワードリストファイルパス (デフォルト: /etc/avion/filters.txt)

### 16.2. Config構造体実装例

```go
// internal/infrastructure/config/config.go
package config

type Config struct {
    Server   ServerConfig
    Database DatabaseConfig
    Redis    RedisConfig
    NATS     NATSConfig

    // avion-moderation固有設定
    AI         AIConfig
    Moderation ModerationConfig
}

type NATSConfig struct {
    URL string `env:"NATS_URL" required:"true"`
}

type AIConfig struct {
    ONNXModelPath string `env:"ONNX_MODEL_PATH" required:"true"`
}

type ModerationConfig struct {
    Threshold          float64 `env:"MODERATION_THRESHOLD" required:"false" default:"0.7"`
    AutoBanThreshold   float64 `env:"AUTO_BAN_THRESHOLD" required:"false" default:"0.95"`
    FilterWordListPath string  `env:"FILTER_WORD_LIST_PATH" required:"false" default:"/etc/avion/filters.txt"`
}
```

## 17. Release Plan

### Phase 1: Core Foundation (MVP)
- 通報受付・管理の基本CRUD API
- 基本的なキーワードフィルタリング（NGワード）
- モデレーションアクション実行（警告、削除、一時停止）
- 監査ログの基本記録
- ConnectRPC API実装

### Phase 2: Automation & Intelligence
- ML分類器によるコンテンツ自動分析（オプトイン）
- 優先度自動計算エンジン
- バッチ処理（優先度再計算、期限切れ処理）
- 正規表現フィルターおよびドメインブロック
- 異議申し立てプロセス実装

### Phase 3: Community & Scale
- コミュニティモデレーション（信頼レベル、投票）
- インスタンスポリシー管理（フェデレーション対応）
- モデレーターダッシュボード・統計API
- スマートキューイング・エスカレーション自動化
- パフォーマンス最適化（キャッシュ、読み取りレプリカ）

### Phase 4: Compliance & Advanced
- GDPR/DSA準拠のコンプライアンスレポート自動生成
- 高度なML分析（画像・動画、多言語対応）
- フェデレーション協調モデレーション
- A/Bテストによる閾値最適化
- 外部レビューサービス連携

## 18. Concerns / Open Questions (懸念事項・相談したいこと)

### 技術的懸念
- **ML分類器の精度向上**: 日本語コンテンツの文脈理解向上が必要
- **大量通報処理**: ピーク時の処理能力とキュー管理の最適化
- **フェデレーション対応**: ActivityPub準拠のクロスインスタンス通報処理の複雑性

### パフォーマンス懸念
- **ML推論レイテンシ**: ONNX Runtimeモデルの推論時間とGPU/CPUリソース管理
- **データベース負荷**: 大量の監査ログとフィルターログによる書き込み負荷

### 今後の検討事項
- **自動化レベル**: 人間の判断とAI判断のバランス調整
- **グローバル展開**: 地域別法規制とコンプライアンス対応
- **プライバシー保護**: GDPR/DSA準拠の証拠保全とデータ最小化

## 19. セキュリティガイドライン参照

- [SQLインジェクション対策](../common/security/sql-injection-prevention.md)
- [XSS対策](../common/security/xss-prevention.md)
- [TLS設定](../common/security/tls-configuration.md)
- [セキュリティヘッダ](../common/security/security-headers.md)

## 20. Service-Specific Test Strategy (サービス固有テスト戦略)

> **詳細は [designdoc-infra-testing.md](./designdoc-infra-testing.md) を参照してください。**
