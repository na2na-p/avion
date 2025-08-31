# Avion E2Eテスト戦略

**最終更新**: 2025-01-14  
**適用範囲**: 全マイクロサービスおよびフロントエンド

## 1. 概要

このドキュメントは、Avionプロジェクトのエンドツーエンド（E2E）テスト戦略を定義します。マイクロサービス環境での統合テストを効率的に実施するため、Kind ClusterとGoネイティブツールを中心に構成します。

## 2. テストツールスタック

### 2.1 フロントエンドE2E

#### Playwright
- **用途**: avion-webのReact SPA E2Eテスト
- **対象**: ユーザーインターフェース、GraphQL API連携
- **実行環境**: Chrome, Firefox, Safari

```typescript
// e2e/frontend/timeline.spec.ts
import { test, expect } from '@playwright/test';

test('ユーザーが投稿してタイムラインに表示される', async ({ page }) => {
  await page.goto('/');
  await page.fill('[data-testid="login-email"]', 'test@example.com');
  await page.fill('[data-testid="login-password"]', 'password');
  await page.click('[data-testid="login-submit"]');
  
  await page.fill('[data-testid="drop-content"]', 'Hello, Avion!');
  await page.click('[data-testid="drop-submit"]');
  
  await expect(page.locator('[data-testid="timeline-item"]')).toContainText('Hello, Avion!');
});
```

### 2.2 バックエンドE2E

#### Ginkgo + Gomega
- **用途**: Goマイクロサービスの統合テスト
- **特徴**: BDD形式、Go標準テストとの互換性
- **実行**: Kind cluster内の実サービスに対してテスト

```go
// e2e/backend/timeline_test.go
package e2e_test

import (
    . "github.com/onsi/ginkgo/v2"
    . "github.com/onsi/gomega"
)

var _ = Describe("Timeline Service E2E", func() {
    var (
        gatewayClient *GatewayClient
        userID        string
    )

    BeforeEach(func() {
        gatewayClient = NewGatewayClient(gatewayURL)
        userID = createTestUser(gatewayClient)
    })

    Context("タイムラインのファンアウト", func() {
        It("フォロワーのタイムラインに投稿が表示される", func() {
            // Arrange
            followerIDs := createFollowers(userID, 10)
            
            // Act
            dropID := createDrop(userID, "Test content")
            
            // Assert
            Eventually(func() bool {
                for _, followerID := range followerIDs {
                    timeline := getTimeline(followerID)
                    if !containsDrop(timeline, dropID) {
                        return false
                    }
                }
                return true
            }, "10s", "1s").Should(BeTrue())
        })
    })
})
```

### 2.3 インフラストラクチャ

#### Kind (Kubernetes in Docker)
- **用途**: ローカルKubernetes環境でのE2Eテスト
- **利点**: 本番同等の環境を軽量に再現

```yaml
# e2e/kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
networking:
  apiServerAddress: "127.0.0.1"
  apiServerPort: 6443
```

#### Helmfile
- **用途**: テスト環境の宣言的管理
- **特徴**: 依存関係の自動解決、環境別設定

```yaml
# e2e/helmfile.yaml
repositories:
  - name: bitnami
    url: https://charts.bitnami.com/bitnami

releases:
  # Infrastructure
  - name: postgresql
    namespace: avion
    chart: bitnami/postgresql
    values:
      - auth:
          database: avion_test
          username: avion
          password: testpassword
        persistence:
          enabled: false

  - name: redis
    namespace: avion
    chart: bitnami/redis
    values:
      - auth:
          enabled: false
        master:
          persistence:
            enabled: false

  # Avion Services
  - name: avion-gateway
    namespace: avion
    chart: ./charts/avion-gateway
    needs:
      - avion/avion-auth
    values:
      - image:
          tag: e2e-{{ env "GITHUB_SHA" | default "latest" }}
        config:
          logLevel: debug

  - name: avion-auth
    namespace: avion
    chart: ./charts/avion-auth
    needs:
      - avion/postgresql
      - avion/redis
```

### 2.4 負荷テスト

#### Vegeta
- **用途**: API負荷テスト
- **特徴**: Goネイティブ、シンプルな設定

```bash
# e2e/load-test/timeline.sh
#!/bin/bash

# タイムライン取得の負荷テスト
echo "GET http://gateway.avion:8080/graphql
Content-Type: application/json
Authorization: Bearer ${TEST_TOKEN}

{\"query\": \"{ timeline { id content } }\"}" | \
  vegeta attack -duration=30s -rate=100 | \
  vegeta report
```

## 3. E2Eテストレイヤー

### 3.1 ユニットE2E
- **対象**: 単一サービスの全機能
- **実行環境**: Dockerコンテナ
- **データストア**: テスト用PostgreSQL/Redis

### 3.2 統合E2E
- **対象**: 複数サービス連携
- **実行環境**: Kind cluster
- **テストケース**: 
  - サービス間gRPC通信
  - Redis Pub/Subイベント伝播
  - サーキットブレーカー動作

### 3.3 シナリオE2E
- **対象**: ユーザージャーニー全体
- **実行環境**: Kind cluster + Playwright
- **主要シナリオ**:
  - ユーザー登録 → プロフィール設定 → 投稿 → タイムライン表示
  - ActivityPub連携: 外部インスタンスとの相互フォロー/投稿共有
  - メディアアップロード → 処理 → CDN配信

## 4. テストデータ管理

### 4.1 シードデータ

```go
// e2e/fixtures/seeder.go
package fixtures

type E2ESeeder struct {
    db        *sql.DB
    redis     *redis.Client
    scenarios map[string]func()
}

func NewE2ESeeder(db *sql.DB, redis *redis.Client) *E2ESeeder {
    s := &E2ESeeder{db: db, redis: redis}
    s.scenarios = map[string]func(){
        "basic":              s.setupBasicScenario,
        "timeline_fanout":    s.setupTimelineFanout,
        "activitypub":        s.setupActivityPub,
        "heavy_load":         s.setupHeavyLoad,
    }
    return s
}

func (s *E2ESeeder) Setup(scenario string) error {
    // クリーンアップ
    s.cleanup()
    
    // シナリオ別データ投入
    if fn, ok := s.scenarios[scenario]; ok {
        fn()
    }
    return nil
}

func (s *E2ESeeder) setupTimelineFanout() {
    // 100人のユーザーを作成
    users := s.createUsers(100)
    
    // フォロー関係を構築（各ユーザーが10-20人をフォロー）
    s.createFollowNetwork(users)
    
    // 初期投稿を作成
    s.createInitialDrops(users[:10], 5)
}
```

### 4.2 テストデータ分離

```go
// e2e/helpers/isolation.go
func IsolateTestData(t *testing.T) (cleanup func()) {
    // テスト用namespace作成
    namespace := fmt.Sprintf("e2e-test-%s-%d", t.Name(), time.Now().Unix())
    
    // データベーススキーマ作成
    createSchema(namespace)
    
    // Redisプレフィックス設定
    redisPrefix := fmt.Sprintf("%s:", namespace)
    
    return func() {
        // テスト終了時のクリーンアップ
        dropSchema(namespace)
        clearRedisKeys(redisPrefix)
    }
}
```

## 5. CI/CD統合

### 5.1 GitHub Actions

```yaml
# .github/workflows/e2e.yml
name: E2E Tests

on:
  pull_request:
    types: [opened, synchronize]
  push:
    branches: [main]

jobs:
  build-images:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Build service images
        run: |
          for service in gateway auth user drop timeline; do
            docker build -t avion-$service:e2e-${{ github.sha }} ./services/avion-$service
          done
      
      - name: Save images
        run: |
          docker save $(docker images -q avion-*:e2e-*) | gzip > images.tar.gz
      
      - uses: actions/upload-artifact@v3
        with:
          name: docker-images
          path: images.tar.gz

  e2e-backend:
    needs: build-images
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/download-artifact@v3
        with:
          name: docker-images
      
      - name: Load images
        run: docker load < images.tar.gz
      
      - name: Create Kind cluster
        run: |
          kind create cluster --config=e2e/kind-config.yaml
          kubectl create namespace avion
      
      - name: Load images to Kind
        run: |
          for image in $(docker images --format "{{.Repository}}:{{.Tag}}" | grep e2e); do
            kind load docker-image $image
          done
      
      - name: Deploy services
        run: |
          helmfile -f e2e/helmfile.yaml sync
          kubectl -n avion wait --for=condition=Available deployments --all --timeout=5m
      
      - name: Run Ginkgo tests
        run: |
          export GATEWAY_URL=$(kubectl -n avion get svc avion-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
          go test -v ./e2e/backend/... -ginkgo.v -ginkgo.progress

  e2e-frontend:
    needs: e2e-backend
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      
      - name: Install dependencies
        working-directory: ./services/avion-web
        run: npm ci
      
      - name: Install Playwright
        run: npx playwright install --with-deps chromium
      
      - name: Run Playwright tests
        working-directory: ./services/avion-web
        run: |
          export GATEWAY_URL=http://localhost:8080
          kubectl -n avion port-forward svc/avion-gateway 8080:8080 &
          npx playwright test --project=chromium
      
      - uses: actions/upload-artifact@v3
        if: failure()
        with:
          name: playwright-report
          path: services/avion-web/playwright-report/

  load-test:
    needs: e2e-backend
    runs-on: ubuntu-latest
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Vegeta
        run: |
          wget https://github.com/tsenart/vegeta/releases/latest/download/vegeta_linux_amd64.tar.gz
          tar -xzf vegeta_linux_amd64.tar.gz
          sudo mv vegeta /usr/local/bin/
      
      - name: Run load tests
        run: |
          export GATEWAY_URL=$(kubectl -n avion get svc avion-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
          ./e2e/load-test/run-all.sh
      
      - name: Upload results
        uses: actions/upload-artifact@v3
        with:
          name: load-test-results
          path: e2e/load-test/results/
```

## 6. 監視とデバッグ

### 6.1 OpenTelemetry統合

```go
// e2e/helpers/tracing.go
package helpers

import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/trace"
)

var tracer trace.Tracer

func init() {
    if os.Getenv("E2E_TRACING_ENABLED") == "true" {
        tp := initTraceProvider()
        otel.SetTracerProvider(tp)
        tracer = otel.Tracer("e2e-tests")
    }
}

func TraceTest(t *testing.T) (context.Context, trace.Span) {
    ctx, span := tracer.Start(context.Background(), t.Name())
    t.Cleanup(func() { span.End() })
    return ctx, span
}
```

### 6.2 ログ収集

```go
// e2e/helpers/logs.go
func CollectServiceLogs(t *testing.T, service string) {
    t.Cleanup(func() {
        if t.Failed() {
            logs, _ := exec.Command("kubectl", "-n", "avion", "logs", 
                "-l", fmt.Sprintf("app=%s", service), 
                "--tail=100").Output()
            
            t.Logf("Logs from %s:\n%s", service, logs)
        }
    })
}
```

## 7. ベストプラクティス

### 7.1 テスト設計原則

1. **独立性**: 各テストは他のテストに依存しない
2. **冪等性**: 複数回実行しても同じ結果
3. **並列実行**: テスト間で競合しない設計
4. **高速性**: 必要最小限のデータとステップ

### 7.2 安定化戦略

```go
// リトライとタイムアウト
Eventually(func() bool {
    // 非同期処理の完了を待つ
    return checkCondition()
}, "30s", "1s").Should(BeTrue())

// フレーキーテストの対処
if os.Getenv("CI") == "true" {
    Skip("Flaky test - skipping in CI")
}
```

### 7.3 パフォーマンス最適化

- **並列実行**: `ginkgo -p` で並列テスト
- **リソース共有**: DB/Redisコネクションプール
- **キャッシュ**: テストデータのキャッシュ活用

## 8. トラブルシューティング

### 8.1 よくある問題

#### Kind clusterが起動しない
```bash
# Dockerリソース確認
docker system df
docker system prune -a

# Kind cluster再作成
kind delete cluster
kind create cluster --config=e2e/kind-config.yaml
```

#### テストがタイムアウトする
```go
// タイムアウト値の調整
Eventually(condition, "60s", "2s").Should(BeTrue())

// デバッグログ追加
GinkgoWriter.Printf("Current state: %v\n", getCurrentState())
```

### 8.2 デバッグ手法

```bash
# Kind cluster内のPod確認
kubectl -n avion get pods -o wide

# サービスログ確認
kubectl -n avion logs -f deployment/avion-gateway

# ポートフォワードでサービスアクセス
kubectl -n avion port-forward svc/avion-gateway 8080:8080

# E2Eテストをverboseモードで実行
go test -v ./e2e/... -ginkgo.v -ginkgo.progress
```

## 9. 今後の拡張計画

- [ ] Chaos Engineering（Litmus）導入
- [ ] ビジュアルリグレッションテスト（Percy）
- [ ] Contract Testing（Pact）
- [ ] セキュリティE2Eテスト（OWASP ZAP）
- [ ] マルチリージョンE2Eテスト

---

**関連ドキュメント**:
- [共通テスト戦略](./testing-strategy.md)
- [CI/CD移行戦略](./infrastructure/cicd-migration-strategy.md)
- [開発ガイドライン](./architecture/development-guidelines.md)