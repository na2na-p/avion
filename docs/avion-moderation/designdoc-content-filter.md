# Design Doc: avion-moderation - コンテンツフィルタリング・AI分析

> **本文書は [designdoc.md](./designdoc.md) から分割されたドキュメントです。**
>
> コンテンツフィルタリングエンジン、AI/ML分類器、NSFW判定、スパム検出、自動モデレーションに関する詳細設計を記載します。

## 関連ドキュメント

- [designdoc.md](./designdoc.md) - メインDesign Doc（概要、ドメインモデル、API定義、決定事項）
- [designdoc-infra-testing.md](./designdoc-infra-testing.md) - インフラ層実装、テスト戦略

---

## 1. フィルタリングエンジン

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
   ├─ MLスコアリング（ONNX Runtime）
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

## 2. キャッシュ戦略

```
# フィルタールールキャッシュ
filters:active -> List of active filters (sorted by priority)
TTL: 5分

# NGワードキャッシュ（Trie構造）
ngwords:trie:{lang} -> Serialized Trie structure
TTL: 10分

# インスタンスポリシーキャッシュ
instance:policy:{domain} -> Policy details
TTL: 30分

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

## 3. バッチ処理

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
  schedule: "0 3 * * *"
  tasks:
    - 古いログのアーカイブ
    - 処理済み通報の圧縮
    - キャッシュの最適化

# コンプライアンスレポート（月次）
compliance_report:
  schedule: "0 0 1 * *"
  tasks:
    - 月次統計レポート生成
    - 法的要求対応レポート
    - トレンド分析レポート
```

## 4. セキュリティ設計

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

## 5. ML分類器フォールバック戦略

```go
type MLClassifierWithFallback struct {
    primaryML      MLClassifier
    secondaryML    MLClassifier
    ruleBasedML    RuleBasedClassifier
    circuitBreaker *CircuitBreaker
}

func (ml *MLClassifierWithFallback) ClassifyContent(ctx context.Context, content *Content) (*Classification, error) {
    // プライマリML分類器試行
    if classification, err := ml.tryPrimaryClassifier(ctx, content); err == nil {
        return classification, nil
    }

    // セカンダリML分類器試行
    if classification, err := ml.trySecondaryClassifier(ctx, content); err == nil {
        classification.Confidence *= 0.9
        return classification, nil
    }

    // ルールベース分類器にフォールバック
    classification := ml.ruleBasedML.Classify(content)
    classification.Confidence *= 0.7
    classification.FallbackUsed = true

    ml.sendFallbackAlert("ML_CLASSIFIER_DEGRADED")

    return classification, nil
}
```
