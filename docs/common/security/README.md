# セキュリティガイドライン

**最終更新日:** 2025/08/31  
**ステータス:** 本番環境対応  
**スコープ:** Avionプラットフォーム全体のセキュリティ実装

## 概要

このドキュメントはAvionマイクロサービスプラットフォームにおけるセキュリティ実装の包括的なガイドラインを提供します。すべての開発者は、これらのガイドラインに従って安全なコードを実装する必要があります。

## セキュリティガイドライン一覧

### 1. CSRF保護 (Cross-Site Request Forgery Protection)
**ファイル:** [csrf-protection.md](./csrf-protection.md)

**概要:** クロスサイトリクエストフォージェリ攻撃から保護するための実装ガイド

**使用場面:**
- すべての状態変更操作（POST、PUT、DELETE、PATCH）
- GraphQL mutations
- WebSocket接続の確立時
- 認証済みユーザーのアクション

**主な実装内容:**
- ダブルサブミットクッキーパターン
- Redis を使用したトークン管理
- SameSite Cookie属性の設定
- Origin ヘッダーの検証

### 2. SQLインジェクション防止 (SQL Injection Prevention)
**ファイル:** [sql-injection-prevention.md](./sql-injection-prevention.md)

**概要:** SQLインジェクション脆弱性を防ぐためのGORM実装ガイドライン

**使用場面:**
- データベースクエリの実装時
- 動的なSQL条件の構築時
- ユーザー入力を含むクエリ処理
- Raw SQLの使用が必要な場合

**主な防御策:**
- パラメータ化クエリの使用
- GORM の安全なメソッドチェーン
- 入力値の検証とサニタイゼーション
- プリペアドステートメントの活用

### 3. XSS防止 (Cross-Site Scripting Prevention)
**ファイル:** [xss-prevention.md](./xss-prevention.md)

**概要:** クロスサイトスクリプティング攻撃を防ぐための実装方針

**使用場面:**
- HTMLコンテンツの生成時
- ユーザー生成コンテンツの表示
- GraphQL レスポンスの処理
- フロントエンドでのデータレンダリング

**主な対策:**
- 出力エスケーピング
- Content Security Policy (CSP) の設定
- HTMLサニタイゼーション
- React の安全なレンダリング手法

### 4. セキュリティヘッダー (Security Headers)
**ファイル:** [security-headers.md](./security-headers.md)

**概要:** HTTPセキュリティヘッダーの設定ガイドライン

**使用場面:**
- すべてのHTTPレスポンス
- API Gateway の設定
- 静的ファイルの配信
- WebSocketのアップグレード

**必須ヘッダー:**
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `X-XSS-Protection: 1; mode=block`
- `Strict-Transport-Security` (HTTPS環境)
- `Content-Security-Policy`

### 5. 暗号化ガイドライン (Encryption Guidelines)
**ファイル:** [encryption-guidelines.md](./encryption-guidelines.md)

**概要:** データ暗号化と鍵管理のベストプラクティス

**使用場面:**
- パスワードの保存（bcrypt/Argon2）
- 個人情報の暗号化
- APIキーとトークンの管理
- データベース暗号化
- 通信の暗号化

**実装項目:**
- 保存時暗号化（Encryption at Rest）
- 転送時暗号化（Encryption in Transit）
- 鍵のローテーション戦略
- HSM/KMS の活用

### 6. TLS設定 (TLS Configuration)
**ファイル:** [tls-configuration.md](./tls-configuration.md)

**概要:** Transport Layer Security の適切な設定

**使用場面:**
- すべてのHTTPS通信
- gRPCサービス間通信
- Redis/PostgreSQLへの接続
- 外部APIとの通信

**設定要件:**
- TLS 1.2以上の使用
- 安全な暗号スイートの選択
- 証明書の検証
- HSTS の有効化

## セキュリティチェックリストテンプレート

新機能の実装やコードレビュー時に使用するチェックリストです。

### 開発時チェックリスト

#### 入力検証
- [ ] すべてのユーザー入力を検証している
- [ ] 型とフォーマットのチェックを実装している
- [ ] 長さ制限を設定している
- [ ] 特殊文字を適切に処理している

#### 認証・認可
- [ ] 適切な認証メカニズムを使用している
- [ ] JWTトークンの有効期限を設定している
- [ ] リフレッシュトークンのローテーションを実装している
- [ ] ロールベースアクセス制御（RBAC）を実装している

#### データ保護
- [ ] 機密データを暗号化している
- [ ] パスワードを適切にハッシュ化している
- [ ] 個人情報を最小限に抑えている
- [ ] ログに機密情報を出力していない

#### エラーハンドリング
- [ ] エラーメッセージに技術的詳細を含めていない
- [ ] スタックトレースを本番環境で表示していない
- [ ] 適切なHTTPステータスコードを返している
- [ ] エラーログを適切に記録している

#### セッション管理
- [ ] セッションタイムアウトを設定している
- [ ] ログアウト時にセッションを破棄している
- [ ] 同時セッション数を制限している
- [ ] セッション固定攻撃対策を実装している

### コードレビューチェックリスト

#### SQLクエリ
- [ ] パラメータ化クエリを使用している
- [ ] GORM の安全なメソッドを使用している
- [ ] Raw SQL使用時に適切なエスケープを行っている
- [ ] クエリの実行権限を最小限にしている

#### API実装
- [ ] CSRF保護を実装している
- [ ] レート制限を設定している
- [ ] 適切なCORSポリシーを設定している
- [ ] APIキーの管理が適切である

#### フロントエンド
- [ ] XSS対策を実装している
- [ ] CSPヘッダーを設定している
- [ ] 機密データをローカルストレージに保存していない
- [ ] HTTPS通信を強制している

## セキュリティレビュープロセス

### 1. 設計フェーズ
**目的:** セキュリティ要件の早期特定

**アクション:**
- 脅威モデリングの実施
- セキュリティ要件の文書化
- リスク評価の実施
- 必要なセキュリティコントロールの特定

### 2. 実装フェーズ
**目的:** セキュアコーディングの実践

**アクション:**
- セキュリティガイドラインの遵守
- 静的コード解析ツールの使用
- 依存関係の脆弱性チェック
- ユニットテストでのセキュリティテスト

### 3. テストフェーズ
**目的:** 脆弱性の発見と修正

**アクション:**
- セキュリティテストケースの実行
- ペネトレーションテスト
- OWASP Top 10 の確認
- セキュリティログの検証

### 4. デプロイフェーズ
**目的:** 本番環境のセキュリティ確保

**アクション:**
- セキュリティ設定の確認
- シークレット管理の検証
- アクセス制御の設定
- モニタリングとアラートの設定

### 5. 運用フェーズ
**目的:** 継続的なセキュリティ維持

**アクション:**
- セキュリティパッチの適用
- ログの定期的な監査
- インシデント対応計画の更新
- セキュリティトレーニングの実施

## セキュリティツールと自動化

### 静的解析ツール

```bash
# Go セキュリティチェック
gosec ./...

# 依存関係の脆弱性チェック
nancy sleuth

# ライセンスチェック
golicense -verbose ./...
```

### 動的解析ツール

```bash
# OWASP ZAP でのスキャン
zap-cli quick-scan --self-contained \
  --start-options '-config api.disablekey=true' \
  http://localhost:8080

# SQLMap でのSQLインジェクションテスト
sqlmap -u "http://localhost:8080/api/v1/users?id=1" \
  --batch --random-agent
```

### CI/CDパイプライン統合

```yaml
# .github/workflows/security.yml
name: Security Checks

on:
  pull_request:
    branches: [main, develop]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run Gosec
        uses: securego/gosec@master
        with:
          args: ./...
      
      - name: Run Trivy
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          
      - name: Dependency Check
        uses: dependency-check/Dependency-Check_Action@main
        with:
          project: 'avion'
          path: '.'
          format: 'HTML'
```

## インシデント対応

### セキュリティインシデント発生時の対応手順

1. **検知と初期対応**
   - インシデントの特定と記録
   - 影響範囲の初期評価
   - 緊急対応チームへの通知

2. **封じ込め**
   - 影響を受けたシステムの隔離
   - アクセスの一時的な制限
   - 証拠の保全

3. **根絶**
   - 脆弱性の修正
   - マルウェアの除去
   - システムの強化

4. **回復**
   - システムの復旧
   - 通常運用への移行
   - モニタリングの強化

5. **事後分析**
   - インシデントレポートの作成
   - 教訓の文書化
   - プロセスの改善

## セキュリティトレーニング

### 必須トレーニング項目

1. **OWASP Top 10**
   - 最新の脆弱性トレンド
   - 各脆弱性の防御方法
   - 実践的な対策

2. **セキュアコーディング**
   - 言語固有のセキュリティ機能
   - フレームワークのセキュリティ機能
   - コードレビューのベストプラクティス

3. **認証・認可**
   - OAuth 2.0 / OpenID Connect
   - JWT のセキュリティ
   - MFA の実装

4. **暗号化**
   - 暗号化アルゴリズムの選択
   - 鍵管理のベストプラクティス
   - TLS/SSL の設定

## リソースとリファレンス

### 外部リソース
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE/SANS Top 25](https://cwe.mitre.org/top25/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [Go Security Guidelines](https://golang.org/doc/security)

### 内部ドキュメント
- [Avion認証アーキテクチャ](../architecture/authentication.md)
- [データ保護ポリシー](../policies/data-protection.md)
- [インシデント対応計画](../incident-response/plan.md)

## サポート

セキュリティに関する質問や懸念事項がある場合は、以下のチャンネルを通じて連絡してください：

- **Slack:** #avion-security
- **Email:** security@avion.app
- **緊急時:** セキュリティホットライン（内部Wiki参照）

## 更新履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|----------|
| 2025/08/31 | 1.0 | 初版作成 |

---

**注意:** このドキュメントは定期的に更新されます。常に最新版を参照してください。