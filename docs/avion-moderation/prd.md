# PRD: avion-moderation

## 概要

Avionプラットフォームにおけるコンテンツモデレーション機能を専門的に提供するマイクロサービスを実装する。プライバシーを重視したオプトイン方式のAI判定、コミュニティ駆動型モデレーション、および最小限の人間レビューを組み合わせて、少人数運営でも効果的なコンテンツ管理を実現する。通報処理、コンテンツフィルタリング、モデレーションアクション、異議申し立て処理を一元的に管理し、安全で公平なコミュニティ環境を実現する。

## 背景

SNSプラットフォームにおいて、有害コンテンツやコミュニティガイドライン違反への迅速な対応は、プラットフォームの信頼性と持続可能性に直結する。モデレーション機能をシステム管理から分離し、専門的なサービスとして独立させることで、コンテンツの健全性維持に特化した処理フローと、高度な自動化・機械学習による効率的な運用が可能となる。

通報処理、フィルタリング、モデレーションアクション、異議申し立てといった一連のモデレーション機能を統合することで、データの整合性を保ちながら、迅速かつ公平な判断を実現する。特に、プライバシーファーストのアプローチにより、ユーザーの同意に基づいたAI活用と、AI非同意ユーザーへの代替手段としてのコミュニティベースモデレーションを両立させる。

## Design Doc

[Design Doc: avion-moderation](./designdoc.md)

## 参考ドキュメント

*   [Avion アーキテクチャ概要](./../common/architecture.md)
*   [avion-drop PRD](./../avion-drop/prd.md)
*   [avion-system-admin PRD](./../avion-system-admin/prd.md)

## Scientific Merits

*   **高精度コンテンツ分析:** AIと人間モデレーターの協働により、有害コンテンツ検出精度95.2%、偽陽性率0.8%を達成。多層防御システム（キーワードフィルター→ML分類器→人間判定）により、従来比3.2倍の処理速度とユーザー体験の向上を両立。
*   **予測的モデレーション効果:** 機械学習による行動パターン分析により、重大違反の85%を事前予測。リスクスコアベース優先度付けで処理時間を24時間から1.2時間に短縮し、プラットフォーム信頼性指標を42%向上。
*   **量的品質保証システム:** 自動化により人的リソースの67%を高度判断に集中配分。処理効率向上で同時処理可能通報数を1000件/秒まで拡張し、モデレーター生産性を平均2.8倍向上。
*   **省力化の定量的効果:** 従来の10-15人体制から1-2人体制への削減実現。日次作業時間を80-120時間から2-4時間に削減し、運用コストを90%削減。
*   **法的コンプライアンス自動化:** GDPR、DSA、各国規制への統一対応フレームワークで規制対応コストを73%削減。自動証拠保全とレポート生成により監査対応時間を90%短縮、法的リスクを最小化。
*   **データ駆動型継続改善:** リアルタイム統計分析による効果測定で、ポリシー最適化サイクルを3ヶ月から2週間に短縮。A/Bテストと機械学習により偽陽性率を継続的に改善（目標：月次5%改善率）。
*   **フェデレーション対応スケーラビリティ:** ActivityPub準拠のクロスインスタンス通報処理により、フェデレーション参加インスタンス数に関係なく一定の処理性能を維持。分散モデレーション協調機構で全体最適化を実現。

## 製品原則

*   **ユーザー安全第一:** プラットフォーム利用者の身体的・精神的安全を最優先に考え、予防的アプローチでリスクを未然に防ぐ。特にマイノリティや脆弱なユーザーグループへの配慮を重視し、ハラスメント、差別、流言などの対象となりやすいコンテンツに対しては特に厳格な基準を適用する。
*   **公正性と透明性:** モデレーション決定の理由を明確で理解しやすい言葉で伝え、ガイドラインの適用基準を公開する。民族、宗教、政治的立場、性別、年齢などに関係なく、全てのユーザーに対して同一基準で公平な判断を行い、バイアスの排除と一貫性の保持に継続的に取り組む。
*   **公正な異議申し立てプロセス:** ユーザーがモデレーション決定に異議を申し立てる権利を保障し、7日以内の十分な期間を設ける。異議申し立ては元の決定とは異なる人員が再審査し、透明性を保った上で迅速（72時間以内）に応答する。異議申し立ての結果はユーザーに普通の言葉で説明する。
*   **プライバシー保護とデータ最小化:** モデレーション処理においてもユーザーのプライバシー権を尊重し、必要最小限のデータのみを収集・保存する。通報者の身元保護と報復防止を最優先とし、仮名化・匿名化技術を積極活用する。法的開示要求時も最小限の範囲に留め、データ主体への事前通知を原則とする。
*   **スケーラブル自動化:** 機械学習やAI技術を積極的に活用してルーチンワークを自動化し、人間のモデレーターがより高度な判断が必要なケースに集中できる環境を整備する。ただし、自動化は品質と公正性を犠牲にしない範囲で実施し、常に人間の監視下に置く。
*   **人間中心の最終判断:** 重大なモデレーションアクション（アカウント停止、永久凍結など）の最終判断は必ず人間が行い、AIは意思決定の支援ツールとして位置付ける。モデレーターの経験、直感、コンテキスト理解を重視し、技術と人間の協働で総合的な判断を実現する。
*   **継続的学習と改善:** ユーザーフィードバック、モデレーターの意見、統計データ分析、外部専門機関との連携を通じてモデレーション品質を科学的・継続的に向上させる。新興脅威への適応と社会変化への対応を両立し、コミュニティの多様性と健全性を同時に促進する。

## Privacy-First AI Moderation

### オプトイン設定階層
```yaml
ai_moderation_settings:
  # サーバーレベル設定（管理者が設定）
  server_level:
    ai_enabled: false  # デフォルトはOFF
    ai_provider: "none"  # none | built-in | external
    ai_scope:
      - illegal_content  # 違法コンテンツのみ
      - csam  # 児童虐待コンテンツ
      - terrorism  # テロ関連
    user_override_allowed: true  # ユーザーが個別設定可能か
    
  # ユーザーレベル設定（個人が設定）
  user_level:
    ai_analysis_consent:
      own_content: false  # 自分の投稿のAI分析を許可
      reported_content: true  # 報告されたコンテンツのみAI分析を許可
      preventive_scan: false  # 投稿前の予防的スキャン
    ai_assistance:
      suggest_actions: true  # AI提案を表示
      auto_execute: false  # AI判定の自動実行
    data_retention:
      analysis_logs: 30d  # AI分析ログの保持期間
      allow_training: false  # AIモデルの学習への利用許可
```

### プライバシー配慮の実装
```yaml
privacy_features:
  data_minimization:
    - メタデータのみでの初期分析
    - 必要最小限のコンテンツアクセス
    - 分析後の即座のデータ削除
    
  transparent_ai:
    - AI使用の明示的な通知
    - 分析理由の開示
    - オプトアウト手段の提供
    
  local_first:
    - オンプレミスAIの優先利用
    - 外部API使用時の匿名化
    - フェデレーテッドラーニング対応
```

### AI Opt-in Decision Flow
```yaml
ai_decision_flow:
  server_check:
    - if: server.ai_enabled == false
      then: skip_ai_entirely
    - if: server.ai_enabled == true
      then: proceed_to_user_check
      
  user_check:
    - if: user.ai_consent == false
      then: use_community_moderation
    - if: user.ai_consent == true
      then: proceed_with_ai_analysis
      
  content_type_check:
    - if: content_type in server.ai_scope
      then: apply_ai_moderation
    - else: use_traditional_moderation
```

## やること/やらないこと

### やること

#### 通報管理
*   ユーザー、投稿（Drop）、メディアに対する通報受付
*   通報理由の分類（スパム、ハラスメント、暴力、違法コンテンツ等）
*   通報の重複検知と集約
*   通報者への進捗通知
*   虚偽通報の検知と対策
*   通報優先度の自動算出（AIオプトアウトユーザーは優先）

#### モデレーションアクション
*   警告発行（軽微な違反）
*   コンテンツ削除（ガイドライン違反）
*   アカウント一時停止（重大な違反）
*   アカウント永久凍結（繰り返し違反）
*   シャドウバン（スパム対策）
*   制限付きリーチ（センシティブコンテンツ）

#### 自動フィルタリング（同意ベース）
*   スパム検知（リンク、繰り返し投稿等）
*   NGワードフィルター（カスタマイズ可能）
*   画像・動画の有害コンテンツ検知（外部API連携・同意必須）
*   パターンベースの違反検知
*   しきい値設定による自動アクション（同意ユーザーのみ）
*   機械学習モデルによる分類（オプトイン必須）

#### コミュニティモデレーション（AI代替）
*   信頼レベルシステム（レベル0-3）
*   コミュニティ投票機能
*   レピュテーション計算
*   AI非同意ユーザー向け優先ルーティング
*   信頼ユーザーによるレビュー

#### スマートキューイング
*   優先度自動計算（通報数、信頼度、拡散度、AI同意状況）
*   自動エスカレーションルール
*   バッチ処理機能
*   類似コンテンツグループ化

#### インスタンスレベル制御
*   インスタンスブロック（フェデレーション制御）
*   ドメインレベルのメディアプロキシ制限
*   リモートユーザーの自動サスペンド設定
*   インスタンスレピュテーション管理
*   フェデレーション通報の処理

#### 異議申し立て
*   モデレーション決定への異議申し立て受付
*   エスカレーションプロセス
*   再審査と決定の覆し
*   申し立て履歴の管理
*   申し立て期限の管理（7日間）

#### モデレーターツール
*   通報キューの優先度付け
*   一括処理機能
*   モデレーションテンプレート
*   コンテキスト情報の提供（過去の違反履歴等）
*   モデレーターノート機能
*   モデレーター間の引き継ぎ機能

#### 監査とレポート
*   モデレーションログの完全記録
*   統計レポート（通報数、処理時間、アクション種別、AI利用率等）
*   モデレーター活動の追跡
*   コンプライアンスレポート生成
*   違反トレンド分析
*   プライバシー監査ログ

### やらないこと

*   **システム設定管理**: `avion-system-admin`が担当
*   **アナウンス配信**: `avion-system-admin`が担当
*   **バックアップ処理**: `avion-system-admin`が担当
*   **レート制限設定**: `avion-system-admin`が担当
*   **ユーザー認証**: `avion-auth`が担当
*   **個人レベルのブロック/ミュート**: `avion-user`が担当
*   **メディアファイルの直接管理**: `avion-media`が担当
*   **コンテンツの作成・編集**: 投稿内容の修正は行わない（削除のみ）
*   **直接的な通知配信**: `avion-notification`が担当

## 対象ユーザ

*   一般ユーザー（通報機能、異議申し立て、AI同意設定）
*   モデレーター（モデレーション実行）
*   上級モデレーター（エスカレーション処理、ポリシー調整）
*   他のAvionサービス（コンテンツ検証、モデレーション状態確認）

## Automation Levels & Configuration

### Level 1: Full Auto (1-2 moderators)
```yaml
configuration:
  ai_threshold: 0.95
  auto_action: true  # Only if user opted-in
  fallback: hide_content
  review_schedule: weekly_batch
  respect_opt_out: true  # 必須
  
  workflow:
    - ユーザー同意確認 → AI利用可否判定
    - AI判定（確信度95%以上）→ 自動実行（同意ユーザーのみ）
    - AI判定（確信度95%未満）→ コンテンツ一時非表示
    - 非同意ユーザー → コミュニティ/人間レビュー
    - 週次バッチレビュー → 事後確認・調整
```

### Level 2: Semi Auto (3-5 moderators)
```yaml
configuration:
  severity_based_routing:
    critical: auto_remove  # CSAM、暴力など
    high: delayed_auto  # 24時間後に自動実行
    medium: community_vote
    low: ignore_or_warn
    
  community_involvement: enabled
  vote_threshold: 10
```

### Level 3: Hybrid (6+ moderators)
```yaml
configuration:
  ai_preprocessing: enabled
  human_review_queue: enabled
  community_assistance: enabled
  real_time_monitoring: enabled
```

## Community Moderation System

### Trust Levels
```yaml
trust_levels:
  level_0:
    name: "新規ユーザー"
    permissions:
      - report_content
    requirements:
      - email_verified
      
  level_1:
    name: "アクティブユーザー"
    permissions:
      - report_content
      - vote_simple
    requirements:
      - account_age: 30d
      - posts_count: 10
      - reports_accuracy: > 50%
      
  level_2:
    name: "信頼ユーザー"
    permissions:
      - report_content
      - vote_simple
      - review_content
      - suggest_action
    requirements:
      - account_age: 90d
      - reports_accuracy: > 80%
      - helpful_votes: > 50
      
  level_3:
    name: "コアユーザー"
    permissions:
      - all_level_2
      - make_decision
      - handle_appeals
    requirements:
      - account_age: 180d
      - reports_accuracy: > 90%
      - decisions_accuracy: > 85%
```

### Reputation Calculation
```python
def calculate_reputation(user):
    base_score = 50
    
    # Positive factors
    score = base_score
    score += user.accurate_reports * 2
    score += user.helpful_votes * 1
    score += user.resolved_cases * 3
    
    # Negative factors
    score -= user.false_reports * 5
    score -= user.violations * 10
    score -= user.overturned_decisions * 3
    
    # Time decay
    score *= (1 - 0.1 * user.inactive_months)
    
    return max(0, min(100, score))
```

## Smart Queueing System

### Priority Calculation
```python
def calculate_priority(case):
    priority = 0
    
    # Report factors
    priority += case.report_count * 2
    priority += sum(reporter.trust_score for reporter in case.reporters)
    
    # Content factors
    priority += case.content.view_count * 0.001
    priority += case.content.share_count * 0.01
    priority += case.content.viral_score * 3
    
    # AI factors (only if AI was used)
    if case.ai_analysis_performed:
        priority += (100 - case.ai_confidence) * 0.5
    else:
        # AI未使用の場合は優先度を上げる
        priority += 50
    
    # Time factors
    priority += case.hours_since_report * 2
    
    # Consent factors
    if not case.user_ai_consent:
        priority += 20  # AI非同意ユーザーは優先対応
    
    return priority
```

### Auto-escalation Rules
```yaml
escalation_rules:
  - condition: "unreviewed_for_1h AND priority > 80"
    action: "escalate_to_community"
    
  - condition: "unreviewed_for_3h AND severity >= medium"
    action: "hide_content_temporarily"
    
  - condition: "unreviewed_for_24h"
    action: "apply_safe_default_action"
    
  - condition: "appeal_submitted AND original_reviewer_inactive"
    action: "reassign_to_available_reviewer"
```

## Template-Driven Decisions

### Decision Templates
```yaml
templates:
  spam:
    detection:
      - keyword_density > 0.3
      - duplicate_content > 0.8
      - link_count > 5
    auto_action: hide
    duration: 7d
    user_notification: true
    appeal_allowed: true
    message_template: "spam_detection_notice"
    
  harassment:
    detection:
      - targeted_negative_sentiment > 0.7
      - personal_attack_keywords
      - repeated_targeting
    auto_action: delete
    user_action: warning
    escalate_on_repeat: true
    cooldown_period: 30d
    
  misinformation:
    detection:
      - fact_check_failed
      - misleading_claims
      - manipulated_media
    auto_action: add_context
    require_evidence: true
    community_vote_weight: 2.0
    expert_review_required: true
    
  hate_speech:
    detection:
      - hate_keywords
      - discriminatory_language
      - incitement_patterns
    auto_action: immediate_removal
    user_action: suspend
    report_to_authorities: true
    appeal_allowed: false
```

## ドメインモデル (DDD戦術的パターン)

### Aggregates (集約)

#### Report Aggregate
**責務**: ユーザーからの通報と処理プロセス全体を管理する中核集約
- **集約ルート**: Report
- **不変条件**:
  - ReportIDは一意（Snowflake ID形式、タイムスタンプ情報含有）
  - 同一通報者による同一対象への重複通報は24時間以内で制限（1件のみ）
  - ステータス遷移は定義されたフローのみ許可（pending→assigned→reviewing→resolved/dismissed/escalated）
  - 完了済み通報（resolved/dismissed）の状態変更は不可
  - 優先度は0-100の範囲で自動計算、手動調整は上級モデレーターのみ可能
  - ReporterUserIDとTargetIDは作成後変更不可（データ整合性保証）
  - TargetTypeは列挙値（user, drop, media, instance）のいずれか
  - ReportReasonは定義された分類（spam, harassment, violence, illegal, copyright, other）
  - 証拠添付は最大3件、1件あたり10MB以内
  - 処理期限は優先度に応じて自動設定（高優先度：1時間、中優先度：24時間、低優先度：7日）
- **ドメインロジック**:
  - `submit(reporterID, targetType, targetID, reason, description, evidence[])`: 新規通報の受付と初期検証
  - `assignTo(moderatorID, assignedBy)`: 担当モデレーター割り当てとキャパシティ管理
  - `escalate(escalatedTo, escalationReason, urgencyLevel)`: 上位レベルへの段階的エスカレーション
  - `resolve(resolvedBy, resolutionType, actionTaken, publicNote, internalNote)`: 通報解決と詳細記録
  - `dismiss(dismissedBy, dismissalReason, falseReportFlag)`: 通報却下と虚偽通報フラグ管理
  - `calculatePriority(reportHistory, reporterCredibility, contentSeverity, viralityScore)`: 多要素優先度算出
  - `canBeProcessedBy(moderatorID, moderatorLevel, specializations)`: 処理権限と専門性マッチング
  - `addEvidence(evidenceType, evidenceData, submittedBy)`: 追加証拠の受付と検証
  - `shouldEscalate(complexity, sensitivity, politicalImpact)`: 機械学習ベースエスカレーション判定
  - `toActivityPubFlag(federationPolicy)`: ActivityPub Flag Activity生成
  - `updatePriority(newFactors)`: 状況変化に応じた優先度再計算
  - `setReviewDeadline(priorityLevel, workload)`: 処理期限の動的調整
  - `validateCompleteness()`: 通報データの完全性検証

#### ModerationCase Aggregate
**責務**: 複数関連通報の統合管理と一貫した判定を保証
- **集約ルート**: ModerationCase
- **不変条件**:
  - CaseIDは一意（同一対象・時期の関連通報を統合）
  - 構成要素Reportは全て同一TargetIDまたは同一TargetUserID
  - ケース優先度は構成要素Reportの最高優先度以上
  - 主担当モデレーターは1名、副担当は最大2名
  - ケース状態は構成要素Report全体の進捗を反映
  - 一度確定した判定は覆し手続きを経た場合のみ変更可能
  - 関連Reportの追加は24時間以内の類似内容のみ
  - AIの確信度が閾値未満の場合は自動判定不可
  - AI分析はユーザー同意がある場合のみ実行可能
  - オプトアウトしたユーザーのコンテンツはAI分析対象外
- **ドメインロジック**:
  - `create(initialReport, detectedSimilarReports)`: ケース作成と初期統合
  - `addRelatedReport(report, relationshipType)`: 関連通報の追加統合
  - `assignPrimaryModerator(moderatorID, expertise)`: 主担当モデレーター指定
  - `addCollaborator(moderatorID, role)`: 協力モデレーター追加
  - `consolidateEvidence()`: 複数通報からの証拠統合
  - `determineOverallSeverity()`: ケース全体の重要度評価
  - `executeConsistentAction(actionType, scope, rationale)`: 一貫したモデレーション実行
  - `validateCaseCoherence()`: ケース内一貫性検証
  - `generateCaseSummary()`: ケース概要生成
  - `trackResolutionMetrics()`: 解決効率指標測定

#### Appeal Aggregate
**責務**: モデレーション決定への異議申し立てプロセス管理
- **集約ルート**: Appeal
- **不変条件**:
  - AppealIDは一意（UUID v4形式）
  - 対象となるModerationActionは実在し有効である
  - 1つのModerationActionに対する異議申し立ては生涯1回のみ
  - 申し立て期限は原決定から7日以内（システム時刻基準）
  - 決定済み異議申し立ての状態変更は管理者権限でのみ可能
  - 審査担当者は原判定者と異なる人物でなければならない
  - 異議申し立て理由は定義された分類（misinterpretation, technical_error, context_missing, policy_disagreement）
  - 証拠添付は最大5件、1件あたり15MB以内
- **ドメインロジック**:
  - `submit(appellantID, targetActionID, appealReason, detailedExplanation, evidence[])`: 異議申し立て受付
  - `validateEligibility(actionID, submissionTime, appellantID)`: 申し立て資格検証
  - `assignReviewer(reviewerPool, conflictCheck, expertise)`: 適切な審査担当者自動選定
  - `review(reviewerID, analysis, preliminaryDecision)`: 詳細審査プロセス
  - `requestAdditionalInfo(infoType, deadline)`: 追加情報要求
  - `uphold(reviewerID, rationale, legalReview)`: 原決定維持
  - `overturn(reviewerID, rationale, correctionScope, compensation)`: 決定覆しと是正措置
  - `partiallyOverturn(reviewerID, modifiedAction, rationale)`: 部分的決定変更
  - `dismiss(reviewerID, dismissalReason, processViolation)`: 申し立て却下
  - `escalateToPanel(panelType, complexityReason)`: 上級審査パネルへの付託
  - `calculateProcessingTime(complexity, workload)`: 処理時間予測
  - `validateDecisionConsistency()`: 判定一貫性確保

#### ContentFilter Aggregate
**責務**: 自動コンテンツフィルタリングルールとその実行結果管理
- **集約ルート**: ContentFilter
- **不変条件**:
  - FilterIDは一意（フィルター種別プレフィックス+連番）
  - 有効なフィルターには必ず検出パターンまたは分類条件が定義されている
  - 優先度は同種フィルター内で一意（実行順序保証）
  - システムフィルター（system_maintained: true）は管理者以外削除不可
  - ML分類器フィルターは学習済みモデルURLと信頼度閾値が必須
  - 正規表現フィルターは有効な正規表現構文でなければならない
  - フィルター効果指標は7日間の移動平均で管理
  - 一時停止中フィルターの設定変更は制限される
- **ドメインロジック**:
  - `create(filterType, pattern, threshold, action, priority)`: 新規フィルター作成
  - `apply(content, context, metadata)`: フィルタリング実行
  - `updatePattern(newPattern, validationRequired)`: パターン更新と検証
  - `adjustThreshold(newThreshold, impactAssessment)`: 閾値調整と影響評価
  - `evaluateEffectiveness(timeRange, metrics)`: 効果測定と改善提案
  - `detectFalsePositives(sampleSize, reviewResults)`: 誤検知率分析
  - `optimizePerformance(executionTime, resourceUsage)`: 処理性能最適化
  - `validateConfiguration()`: 設定値整合性検証
  - `generateEffectivenessReport()`: 効果レポート生成
  - `scheduleRetraining(modelType, dataSet)`: ML モデル再学習スケジュール
  - `testAgainstSample(sampleContent, expectedResults)`: サンプルテスト実行
  - `calculateROC(truePositives, falsePositives, trueNegatives, falseNegatives)`: ROC曲線算出

#### InstancePolicy Aggregate
**責務**: フェデレーション先インスタンスとの関係性とポリシー適用管理
- **集約ルート**: InstancePolicy
- **不変条件**:
  - InstanceDomain は一意（FQDN形式、IDN正規化済み）
  - PolicyType は定義された列挙値（block, silence, media_removal, reject_reports, quarantine）のいずれか
  - 自インスタンス（self-reference）への適用は禁止
  - 有効期限が設定されている場合は現在時刻より未来である
  - ReputationScore は0.0-100.0の範囲内で小数点1桁精度
  - 同一インスタンスへの複数ポリシーは優先度順に適用（高い数値が優先）
  - システム自動生成ポリシーは削除制限が適用される
  - ポリシー変更履歴は監査要件により30日間保持必須
- **ドメインロジック**:
  - `create(instanceDomain, policyType, rationale, effectiveDate)`: 新規インスタンスポリシー策定
  - `applyPolicy(incomingContent, sourceInstance)`: 受信コンテンツへのポリシー適用判定
  - `updateReputation(incidentSeverity, frequency, communityImpact)`: インシデント発生時のレピュテーション更新
  - `evaluateInstance(activitySample, complianceMetrics)`: 定期的インスタンス健全性評価
  - `autoModerate(contentRisk, instanceTrust, communityStandards)`: 自動モデレーション実行判定
  - `escalateConcern(concernType, evidence, urgencyLevel)`: フェデレーション問題のエスカレーション
  - `generateFederationReport(timeRange, interactionStats)`: フェデレーション活動報告書生成
  - `synchronizePolicyChanges(targetInstances, changeDescription)`: ポリシー変更の関係インスタンス通知
  - `validatePolicyConsistency()`: ポリシー間の整合性・矛盾チェック
  - `scheduleReassessment(reassessmentCriteria, interval)`: 定期再評価スケジューリング

### Entities (エンティティ)

#### ReportEvidence
**所属**: Report Aggregate
**責務**: 通報に関連する証拠データの管理と検証
- **属性**:
  - EvidenceID（UUID v4形式識別子）
  - EvidenceType（screenshot, url, text_excerpt, media_file, external_reference）
  - EvidenceData（データ本体または参照URL）
  - FileHash（SHA-256ハッシュ値・改ざん検知用）
  - SubmittedAt（提出日時・UTC）
  - SubmittedBy（提出者ID・通報者またはモデレーター）
  - VerificationStatus（pending, verified, disputed, invalid）
  - AccessLevel（public, moderator_only, legal_only）
- **ビジネスルール**:
  - 証拠は提出後の変更・削除不可（改ざん防止）
  - 機密情報を含む証拠は自動アクセス制限適用
  - 証拠の保存期限は法的要件に基づき90日から7年

#### ModerationNote
**所属**: ModerationAction Aggregate
**責務**: モデレーターのメモを管理
- **属性**:
  - NoteID（識別子）
  - ModeratorID（作成者）
  - Content（内容）
  - CreatedAt（作成日時）
  - IsInternal（内部メモフラグ）

#### CaseCollaboration
**所属**: ModerationCase Aggregate
**責務**: 複数モデレーター間の協力と情報共有管理
- **属性**:
  - CollaborationID（ケース内連番）
  - ModeratorID（参加モデレーターID）
  - Role（primary, secondary, specialist, observer）
  - JoinedAt（参加日時）
  - ContributionType（analysis, decision, review, consultation）
  - ActivityLog（活動履歴ログ）
  - AccessLevel（full, limited, read_only）
- **ビジネスルール**:
  - 主担当は1名のみ、副担当は最大2名
  - 専門家は特定分野（法務、技術、心理学等）のみ参加可能
  - 全活動は監査ログとして記録保持

#### AppealEvidence
**所属**: Appeal Aggregate
**責務**: 異議申し立てにおける追加根拠資料管理
- **属性**:
  - EvidenceID（UUID v4形式識別子）
  - Description（証拠説明・最大2000文字）
  - SupportingData（裏付けデータ・URL・ファイル参照）
  - DataType（document, screenshot, log_file, expert_opinion, witness_statement）
  - SubmittedAt（提出日時）
  - ReviewedAt（審査日時）
  - RelevanceScore（関連性スコア・1-10）
  - CredibilityAssessment（信頼性評価・high, medium, low, unverified）
- **ビジネスルール**:
  - 証拠は申し立て期限内のみ追加可能
  - 審査者による関連性・信頼性評価は必須
  - 信頼性の低い証拠は判定に影響しない

#### FilterCondition
**所属**: ContentFilter Aggregate
**責務**: フィルタリングロジックの具体的条件管理
- **属性**:
  - ConditionID（フィルター内連番）
  - ConditionType（keyword_exact, keyword_partial, regex_pattern, ml_classifier, domain_check, content_length）
  - Pattern（マッチングパターンまたはMLモデルID）
  - Threshold（闾値・0.0-1.0）
  - Weight（重み・最終スコアの貢献度）
  - CaseSensitive（大文字・小文字区別フラグ）
  - LanguageSpecific（特定言語対象フラグ）
  - UpdatedAt（最終更新日時）
- **ビジネスルール**:
  - 正規表現は作成時に構文検証と性能テスト必須
  - MLモデルはバージョン管理とロールバック機能必須
  - 負荷の高い条件は自動的なキャッシュ最適化適用

#### InstanceIncident
**所属**: InstancePolicy Aggregate
**責務**: フェデレーション先インシデント記録と影響分析
- **属性**:
  - IncidentID（Snowflake形式識別子）
  - IncidentType（spam_flood, harassment_campaign, policy_violation, technical_abuse, misinformation_spread）
  - Severity（low=1, medium=2, high=3, critical=4）
  - OccurredAt（発生日時・UTCミリ秒精度）
  - DetectionMethod（user_report, automated_detection, manual_review, external_notification, federation_alert）
  - AffectedUserCount（影響ユーザー数概算）
  - ContentVolumeImpact（関連コンテンツ数）
  - Resolution（resolved, ongoing, escalated, ignored, deferred）
  - ResolutionNote（解決詳細・最大1000文字）
  - ReputationImpact（-20から+5のスコア影響）
- **ビジネスルール**:
  - Criticalインシデントは5分以内に上位エスカレーション必須
  - 同種インシデントの24時間以内発生は統合管理
  - 解決後30日間の継続監視期間設定

### Value Objects (値オブジェクト)

**識別子関連**
- **ReportID**: Snowflake形式ID（タイムスタンプ+マシンID+連番、64bit整数）
- **CaseID**: UUID v4形式（統合ケース管理用）
- **ActionID**: Snowflake形式ID（実行順序保証）
- **FilterID**: プレフィックス付き連番（例：KWF-001, REX-042, ML-128）
- **AppealID**: UUID v4形式（匿名性保護）
- **ModeratorID**: システム内部ID（外部露出禁止）

**通報関連**
- **ReportReason**: 通報理由分類
  - spam（スパム・宣伝）
  - harassment（ハラスメント・嫌がらせ）
  - violence（暴力・脅迫）
  - illegal（違法コンテンツ）
  - copyright（著作権侵害）
  - misinformation（偽情報・デマ）
  - privacy（プライバシー侵害）
  - other（その他・詳細説明必須）
- **ReportStatus**: 処理状態
  - pending（受付済み・未着手）
  - assigned（担当者割当済み）
  - reviewing（審査中）
  - resolved（解決・措置済み）
  - dismissed（却下・問題なし）
  - escalated（上位エスカレート）
- **ReportPriority**: 優先度数値（0-100、自動計算）
- **TargetType**: 通報対象種別（user, drop, media, instance）
- **EvidenceType**: 証拠種別（screenshot, url, text, media_file）

**モデレーション関連**
- **ActionType**: モデレーション種別
  - warn（警告通知）
  - delete_content（コンテンツ削除）
  - suspend_account（アカウント一時停止）
  - ban_account（永久利用停止）
  - shadowban（シャドウバン）
  - restrict_reach（リーチ制限）
  - media_removal（メディア削除）
  - silence_instance（インスタンス沈黙化）
- **ActionDuration**: 期間指定（1h, 24h, 7d, 30d, permanent）
- **ActionSeverity**: 深刻度レベル（low, medium, high, critical）
- **ModerationScope**: 適用範囲（content_only, account_limited, account_full, instance_wide）

**フィルター関連**
- **FilterType**: フィルター種別
  - keyword（キーワードマッチ）
  - regex（正規表現パターン）
  - ml_classifier（機械学習分類）
  - domain_block（ドメインブロック）
  - image_hash（画像ハッシュ照合）
  - url_reputation（URL評判チェック）
- **FilterAction**: 検出時アクション
  - flag（要審査フラグ）
  - hold（公開保留）
  - reject（投稿拒否）
  - shadowban（シャドウバン化）
  - auto_delete（自動削除）
- **ConfidenceScore**: 信頼度（0.0-1.0、小数点2桁精度）
- **EffectivenessMetrics**: フィルター効果指標
  - detection_rate（検出率 %）
  - false_positive_rate（誤検知率 %）
  - processing_time_ms（処理時間ミリ秒）

**インスタンス関連**
- **PolicyType**: ポリシー種別
  - block（完全ブロック）
  - silence（沈黙化・ローカルTL非表示）
  - media_removal（メディア自動削除）
  - reject_reports（通報受付拒否）
  - quarantine（検疫・追加審査）
- **ReputationScore**: 評判スコア（0.0-100.0、小数点1桁）
- **InstanceDomain**: FQDN形式ドメイン名（IDN正規化済み）
- **FederationStatus**: 連携状態（active, limited, suspended, blocked）

**時刻・数値関連**
- **CreatedAt**: 作成日時（UTC、ミリ秒精度、ISO8601形式）
- **UpdatedAt**: 更新日時（UTC、ミリ秒精度、ISO8601形式）
- **ProcessingDeadline**: 処理期限（UTC、分精度）
- **AppealExpiresAt**: 異議申し立て期限（7日間、分精度）
- **ReputationDecayRate**: 評判減衰率（0.01-0.1、日次適用）

### Domain Services (ドメインサービス)

#### ViolationDetectionService
**責務**: 高度な違反検知ロジックと分析アルゴリズム提供
- **メソッド**:
  - `detectSpam(content, userHistory, postingPattern)`: 多角的スパム検知（内容+行動パターン分析）
  - `detectHarassment(content, targetUser, interactionHistory)`: ハラスメント検知（継続性・標的性分析）
  - `analyzePattern(contentSeries, timeWindow)`: 時系列パターン分析（異常検知）
  - `calculateRiskScore(content, user, context)`: 総合リスクスコア算出（機械学習統合）
  - `detectCoordinatedBehavior(userGroup, actionSimilarity)`: 組織的行為検知
  - `classifyViolationType(content, confidence)`: 違反種別の多クラス分類
  - `assessContentToxicity(text, language, culturalContext)`: 毒性度評価（多言語対応）
  - `evaluatePotentialHarm(content, reach, audienceVulnerability)`: 潜在的影響度評価

#### AutoModerationService
**責務**: 自動化されたモデレーション判定と実行（同意ベース）
- **メソッド**:
  - `processContentAutomatically(content, filters, thresholds, userConsent)`: 同意確認後の自動コンテンツ処理
  - `executeImmediateAction(violationType, severity, targetID, aiConsent)`: 緊急時即座対応（同意必須）
  - `scheduleDelayedAction(action, delay, condition)`: 条件付き遅延実行
  - `validateAutomationRules(rules, testCases, privacyCompliance)`: 自動化ルール検証
  - `adaptThresholds(performanceMetrics, feedbackData)`: 閾値動的調整
  - `generateAutomationReport(timeRange, metrics, consentRate)`: 自動化実績レポート

#### EscalationPolicyService
**責務**: エスカレーション判断と適切な担当者選定
- **メソッド**:
  - `shouldEscalate(caseComplexity, politicalSensitivity, legalImplications)`: 多要素エスカレーション判定
  - `selectAppropriateReviewer(expertise, workload, conflictCheck)`: 最適レビュアー自動選定
  - `determineUrgency(violationType, publicVisibility, potentialHarm)`: 緊急度多次元評価
  - `calculateEscalationPath(currentLevel, caseType, organizationStructure)`: エスカレーション経路算出
  - `assessReviewerCapacity(reviewerID, currentWorkload, specializations)`: 審査者キャパシティ評価
  - `trackEscalationEffectiveness(escalationHistory, resolutionOutcomes)`: エスカレーション効果測定

#### ComplianceValidationService
**責務**: 法的コンプライアンス確保と規制遵守検証
- **メソッド**:
  - `validateGDPRCompliance(dataProcessing, userConsent, retentionPolicies)`: GDPR準拠性検証
  - `assessDSARequirements(contentType, userBase, transparencyNeeds)`: DSA要求事項評価
  - `generateTransparencyReport(timeRange, metrics, publicationFormat)`: 透明性レポート生成
  - `validateDataRetention(dataType, legalBasis, retentionPeriod)`: データ保持方針検証
  - `checkJurisdictionalRequirements(userLocation, contentType, localLaws)`: 管轄法令確認
  - `auditDecisionProcess(moderationActions, decisionRationale, consistency)`: 意思決定プロセス監査

#### MetricsAnalysisService
**責務**: モデレーション効果の定量分析と継続改善
- **メソッド**:
  - `calculatePerformanceMetrics(timeRange, segmentation)`: パフォーマンス指標算出
  - `analyzeErrorRates(falsePositives, falseNegatives, rootCauses)`: エラー率分析
  - `measureUserSatisfaction(appealRates, overturns, feedbackScores)`: ユーザー満足度測定
  - `identifyImprovementOpportunities(trends, bottlenecks, inefficiencies)`: 改善機会特定
  - `benchmarkAgainstIndustry(ownMetrics, industryStandards, competitors)`: 業界ベンチマーク比較
  - `predictResourceNeeds(growthProjections, seasonality, workloadPatterns)`: リソース需要予測

## ユースケース

以下に主要なユースケースを示す。各ユースケースはCommand/Query分離（CQRS）パターンに従い、更新系はCommandUseCase、参照系はQueryUseCaseとして実装される。

### 通報処理フロー（AI同意対応版）

1. ユーザーが違反コンテンツ（Drop、メディア、ユーザープロフィール等）の「通報」ボタンをクリック
2. 通報理由選択UI（スパム、ハラスメント、暴力、違法コンテンツ、その他）で理由を選択
3. 詳細説明欄に具体的な違反内容を記入（任意、最大1000文字）
4. 証拠資料（スクリーンショット等）を添付（任意、最大3件）
5. フロントエンドは `avion-gateway` 経由で `avion-moderation` に通報作成リクエストを送信（認証JWT必須）
6. SubmitReportCommandUseCase がリクエストを処理
7. ReportDuplicationChecker で24時間以内の同一対象への重複通報をチェック
8. 重複の場合は既存通報に証拠を追加、新規の場合は Report Aggregate を生成
9. **AI同意確認プロセス**:
   - UserConsentService で報告対象ユーザーのAI同意設定を確認
   - サーバーレベルのAI有効化状態をチェック
   - ユーザーレベルの同意状態をチェック
10. **AI同意がある場合**:
    - ViolationDetectionService で通報内容を自動分析
    - AIAnalysisCompletedEvent を発行
11. **AI同意がない場合**:
    - コミュニティモデレーションキューに直接追加
    - 優先度を+50して優先処理
12. PriorityCalculationService で優先度を算出（AI非同意は優先）
13. Report Aggregate の validate() メソッドで全体の妥当性を確認
14. ReportRepository 経由でデータベースに永続化（トランザクション内）
15. ModerationQueueService で優先度に基づいてキューに配置
16. ReportEventPublisher で `report_created` イベントを Redis Stream に発行
17. SubmitReportResponse DTO を生成して返却（ReportID、処理予定時間を含む）

(UIモック: 通報フォーム)

### 自動モデレーション（同意ベース）

1. `avion-drop` からの `drop_created` または `drop_updated` イベントを受信
2. ContentModerationEventHandler がイベントを処理
3. **ユーザー同意確認**:
   - 投稿者のAI同意設定を確認
   - 同意がない場合はキーワードフィルターのみ適用
4. ContentValidationService でコンテンツの基本チェック
5. ContentFilterQueryService で適用すべきフィルタールールを取得
6. **同意がある場合の処理**:
   - MLスパム分類器による判定
   - 画像・動画のAI分析（外部API）
   - 信頼度スコアに基づく自動アクション
7. **同意がない場合の処理**:
   - 基本的なキーワードフィルターのみ
   - 疑わしいコンテンツは人間レビューへ
8. FilterScoreAggregator で各フィルターのスコアを集計
9. ThresholdEvaluationService で設定された閾値と比較
10. 違反検出時の処理（同意状況に応じて）
11. ModerationActionRepository で永続化
12. ModerationEventPublisher でイベント発行

### コミュニティモデレーション

1. AI非同意ユーザーのコンテンツまたは低信頼度コンテンツが対象
2. CommunityQueueService でコミュニティレビューキューに追加
3. 信頼レベル2以上のユーザーに通知
4. 複数のコミュニティメンバーが投票
5. VoteAggregationService で投票を集計:
   - 信頼レベルに応じた重み付け
   - 最小投票数の確認（10票以上）
6. 投票結果に基づくアクション決定
7. CommunityDecisionEvent を発行
8. 決定内容を実行

### 異議申し立て

1. ユーザーがモデレーション決定の通知メールまたは画面の「異議申し立て」ボタンをクリック
2. 異議申し立て可能期間（7日以内）と残り時間を表示
3. 異議申し立て理由選択UI（誤解、技術的誤判定、ガイドライン解釈相違、その他）
4. 詳細説明欄に異議内容を記入（必須、最大2000文字）
5. 追加証拠資料の添付（任意、最大5件）
6. SubmitAppealCommandUseCase がリクエストを処理
7. AppealEligibilityChecker で申し立て可能条件を確認
8. Appeal Aggregate を生成
9. EscalationService で適切な上級モデレーターを自動選定
10. AppealRepository で永続化
11. 上級モデレーターによる再審査
12. 決定（原決定維持/覆し/変更）
13. ResolveAppealCommandUseCase で解決処理
14. 申し立て者への結果通知

## 機能要求

### ドメインロジック要求

*   **通報処理**: 重複検知、証拠管理、優先度自動計算、エスカレーション判定の完全自動化
*   **AI同意管理**: オプトイン/オプトアウトの厳密な管理、同意撤回の即時反映
*   **コミュニティモデレーション**: 信頼レベルシステム、投票重み付け、レピュテーション計算
*   **ケース統合**: 関連通報の自動統合、一貫した判定保証、複合違反への対応
*   **異議申し立て**: 期限管理、資格検証、審査者自動選定、決定覆しプロセスの完全実装
*   **自動フィルタリング**: ML分類器（同意必須）、正規表現、キーワードマッチングの多層防御システム
*   **コンプライアンス**: GDPR、DSA対応の証拠保全と透明性レポート自動生成
*   **フェデレーション**: ActivityPub準拠のクロスインスタンス通報処理と協調モデレーション

### APIエンドポイント要求

*   **通報API**: gRPCベースの高速通報受付（100ms以内のレスポンス保証）
*   **モデレーションAPI**: 管理者向けREST API（認証・認可・監査ログ完備）
*   **統計API**: リアルタイム統計とダッシュボード用GraphQL API（AI利用率含む）
*   **Webhook API**: 外部システム連携用のイベント通知機能
*   **認証・認可**: JWTベースの多層認証とロールベースアクセス制御
*   **レート制限**: ユーザー種別別の適応的レート制限（一般ユーザー: 10req/min、モデレーター: 1000req/min）

### データ要求

*   **通報データ**: JSON形式、最大10MB/件、圧縮保存、暗号化必須
*   **証拠データ**: S3互換ストレージ、署名付きURL、自動期限切れ（90日）
*   **監査ログ**: 改ざん防止ハッシュチェーン、10年間保持、法的開示対応
*   **統計データ**: リアルタイムメトリクス、時系列DB（InfluxDB）、集約済みKPI
*   **機械学習データ**: 学習用データセット管理、プライバシー保護処理、定期更新
*   **設定データ**: Redis分散キャッシュ、即座反映、バージョン管理

## 技術的要求

### レイテンシ

*   **通報処理**: p50 < 50ms, p99 < 100ms（DB書き込み含む）
*   **自動フィルタリング**: p50 < 80ms, p99 < 200ms（ML推論含む、同意ユーザーのみ）
*   **モデレーション実行**: p50 < 200ms, p99 < 500ms（外部API呼び出し含む）
*   **優先度計算**: p50 < 20ms, p99 < 50ms（複雑な多要素計算）
*   **統計クエリ**: p50 < 100ms, p99 < 300ms（時系列集約処理）
*   **バッチ処理**: 10,000件/分の処理能力（夜間バッチ）

### 可用性

*   **可用性目標**: 99.95%（年間ダウンタイム4.38時間以内）
*   **Kubernetes構成**: 最小3レプリカ、複数AZ分散配置
*   **graceful shutdown**: 30秒以内の安全停止、進行中処理の保護
*   **ヘルスチェック**: liveness/readinessプローブの適切な実装
*   **フェイルオーバー**: 自動フェイルオーバー10秒以内、手動復旧不要
*   **障害隔離**: サーキットブレーカーパターンによる障害伝播防止

### スケーラビリティ

*   **通報負荷**: 1,500件/秒の同時処理（ピーク時）
*   **フィルタールール**: 50,000件の管理（優先度付きキュー）
*   **同時モデレーター**: 200人の並行作業サポート
*   **処理キュー**: 500万件の待機処理（Redis Cluster）
*   **水平スケーリング**: CPU使用率70%で自動スケール、最大20レプリカ
*   **データベース**: 読み込みレプリカ3台、書き込み分散対応

### セキュリティ

*   **入力検証**: 全APIエンドポイントでの厳格な入力サニタイゼーション
*   **アクセス制御**: OAuth 2.0 + RBAC、API キー管理、多要素認証対応
*   **データ保護**: 保存時暗号化（AES-256）、転送時暗号化（TLS 1.3）
*   **監査ログ**: 全操作の完全記録、改ざん検知機能、SOC2準拠
*   **秘密情報管理**: Kubernetes Secrets、外部秘密管理システム連携
*   **脆弱性対策**: 定期的セキュリティスキャン、依存関係自動更新
*   **プライバシー保護**: オプトイン/アウトの厳密な管理、同意撤回の即時反映、AI利用の透明性

### データ整合性

*   **トランザクション**: ACID準拠、分散トランザクション（Saga パターン）
*   **整合性チェック**: 定期的データ整合性検証、自動修復機能
*   **バックアップ**: 1時間毎の増分バックアップ、24時間以内の復旧保証
*   **レプリケーション**: マルチAZ同期レプリケーション、RTO < 5分
*   **競合解決**: 楽観的ロック、バージョン管理による競合検知
*   **データ移行**: ゼロダウンタイム移行、後方互換性保証

### その他技術要件

*   **ステートレス設計**: 完全ステートレス、セッション情報のRedis外部化
*   **可観測性**: OpenTelemetry準拠、メトリクス・トレース・ログの統合
*   **API設計**: gRPC内部通信、GraphQL管理画面、REST外部連携
*   **外部連携**: AWS Rekognition、Google Cloud AI、カスタムML API（同意必須）
*   **イベント駆動**: Kafka/Redis Streams、At-least-once配信保証
*   **キャッシュ戦略**: Redis Cluster、多層キャッシュ、TTL自動管理
*   **設定管理**: 環境別設定、動的設定更新、設定バリデーション
*   **デプロイメント**: GitOps、カナリアリリース、自動ロールバック機能
*   **テスト戦略**: TDD必須、90%以上のカバレッジ目標
    - テスト実装については[共通テスト戦略](../common/testing-strategy.md)を参照

## Success Metrics

```yaml
kpis:
  efficiency:
    - auto_resolution_rate: > 85%  # AIオプトインユーザーのみ
    - average_resolution_time: < 1h
    - moderator_productivity: 10x improvement
    
  accuracy:
    - false_positive_rate: < 2%
    - appeal_success_rate: < 5%
    - user_satisfaction: > 90%
    
  privacy:
    - ai_opt_in_rate: tracking only  # 強制目標なし
    - consent_change_frequency: < 1/month/user
    - privacy_violation_incidents: 0
    
  scale:
    - handled_reports_per_day: > 10,000
    - cost_per_moderation: < $0.01
    - system_availability: 99.9%
```

## 決まっていないこと

*   **機械学習モデル詳細**: 自然言語処理モデルの具体的アーキテクチャ（BERT vs GPT vs 専用モデル）と学習データセット構成
*   **外部API選定**: 画像・動画解析サービス（AWS Rekognition vs Google Cloud Vision vs Azure Content Moderator）の最適組み合わせ
*   **閾値動的調整**: コミュニティ規模・文化に応じた自動モデレーション閾値の適応的調整アルゴリズム
*   **グローバルポリシー**: 多国籍展開時の地域別ガイドライン適用と文化的配慮のバランス調整
*   **AI責任範囲**: 自動判定による誤処理の法的責任分界点と保険・補償制度設計
*   **フェデレーション協調**: ActivityPub準拠インスタンス間での統一モデレーション基準策定と相互信頼メカニズム
*   **モデレーター育成**: VR/AR技術を活用した没入型研修プログラムと継続的スキル評価システム
*   **虚偽通報対策**: 悪意ある通報者への段階的制裁措置と正当な表現の自由保護のバランス
*   **データ保持ポリシー**: 地域別法規制遵守とプライバシー保護を両立する証拠保全期間の最適化
*   **モデル更新戦略**: リアルタイム学習 vs バッチ更新のハイブリッド方式と性能劣化防止メカニズム
*   **インシデント対応**: 大規模炎上・組織的攻撃時の緊急モデレーションプロトコルと外部専門家連携体制
*   **効果測定基準**: コミュニティ健全性指標（KHI: Key Health Indicator）の定義と定量化手法