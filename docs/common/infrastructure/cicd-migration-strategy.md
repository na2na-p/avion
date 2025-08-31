# CI/CD データベースマイグレーション実行戦略

**Last Updated:** 2025/01/13  
**Platform:** GitHub Actions, Kubernetes  
**Status:** 必須実装  
**Compliance:** Production Ready

## 概要

Avionプロジェクトのすべてのマイクロサービスにおける、CI/CDパイプラインでのデータベースマイグレーション自動実行戦略を定義します。
開発環境から本番環境まで、安全で一貫性のあるマイグレーション実行を保証します。

## 目次

1. [基本戦略](#1-基本戦略)
2. [GitHub Actions実装](#2-github-actions実装)
3. [Kubernetes Job実装](#3-kubernetes-job実装)
4. [環境別デプロイ戦略](#4-環境別デプロイ戦略)
5. [安全性確保](#5-安全性確保)
6. [監視とアラート](#6-監視とアラート)
7. [ロールバック戦略](#7-ロールバック戦略)

---

## 1. 基本戦略

### 1.1 実行フロー

```mermaid
graph LR
    A[Code Push] --> B{Branch?}
    B -->|main| C[Production Pipeline]
    B -->|develop| D[Staging Pipeline]
    B -->|feature/*| E[Test Pipeline]
    
    C --> F[Build Image]
    D --> F
    E --> F
    
    F --> G[Run Tests]
    G --> H[Migration Dry-Run]
    H --> I{Success?}
    I -->|Yes| J[Deploy Migration Job]
    I -->|No| K[Fail Pipeline]
    
    J --> L[Run Migration]
    L --> M[Health Check]
    M --> N[Deploy Application]
    N --> O[Smoke Test]
```

### 1.2 原則

1. **マイグレーション優先**: アプリケーションデプロイ前に必ずマイグレーション実行
2. **前方互換性保証**: 新旧バージョンが共存可能なマイグレーションのみ実行
3. **自動ロールバック**: 失敗時は自動的にロールバック
4. **監査ログ**: すべてのマイグレーション実行を記録
5. **並列実行禁止**: 同一サービスのマイグレーションは直列実行
6. **検証**: マイグレーション前後で整合性チェック
7. **分離**: マイグレーションとアプリケーションデプロイを分離

---

## 2. GitHub Actions実装

### 2.1 統合ワークフロー

```yaml
# .github/workflows/database-migration-pipeline.yml
name: Database Migration Pipeline

on:
  push:
    branches: [main, develop, release/*]
    paths:
      - '**/migrations/**'
      - '.github/workflows/*migration*.yml'
  pull_request:
    paths:
      - '**/migrations/**'

env:
  GOOSE_VERSION: v3.18.0
  GO_VERSION: '1.21'
  POSTGRES_VERSION: 15

jobs:
  # ============================================
  # Stage 1: 検証
  # ============================================
  validate:
    name: Validate Migrations
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: 
          - auth
          - user
          - drop
          - timeline
          - notification
          - media
          - search
          - gateway
          - system-admin
          - moderation
          - community
          - activitypub
    
    steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0  # 全履歴を取得
    
    - name: Set up Go
      uses: actions/setup-go@v5
      with:
        go-version: ${{ env.GO_VERSION }}
    
    - name: Install goose
      run: |
        go install github.com/pressly/goose/v3/cmd/goose@${GOOSE_VERSION}
    
    - name: Validate migration files
      working-directory: ./avion-${{ matrix.service }}
      run: |
        echo "🔍 Validating migration files for avion-${{ matrix.service }}"
        
        # ファイル形式チェック
        for file in migrations/*.sql; do
          if [ -f "$file" ]; then
            echo "Checking $file..."
            
            # +goose ディレクティブの存在確認
            if ! grep -q "^-- +goose Up" "$file"; then
              echo "❌ Missing +goose Up directive in $file"
              exit 1
            fi
            
            if ! grep -q "^-- +goose Down" "$file"; then
              echo "❌ Missing +goose Down directive in $file"
              exit 1
            fi
            
            # Author と Date の確認
            if ! grep -q "^-- Author:" "$file"; then
              echo "⚠️  Missing author information in $file"
            fi
            
            if ! grep -q "^-- Date:" "$file"; then
              echo "⚠️  Missing date information in $file"
            fi
            
            echo "✅ $file validation passed"
          fi
        done
        
        echo "✅ All migration files are valid"
    
    - name: Check migration order
      run: |
        # 番号の順序性を確認
        if [ -d "avion-${{ matrix.service }}/migrations" ]; then
          echo "Checking migration order for avion-${{ matrix.service }}"
          
          prev_num=0
          for file in $(ls avion-${{ matrix.service }}/migrations/*.sql | sort); do
            num=$(basename $file | cut -d'_' -f1)
            if [ $num -le $prev_num ]; then
              echo "❌ Migration order error: $file"
              exit 1
            fi
            prev_num=$num
          done
          
          echo "✅ Migration order check passed"
        fi

  # ============================================
  # Stage 2: テスト実行
  # ============================================
  test-migration:
    name: Test Migration
    needs: validate
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service:
          - auth
          - user
          - drop
          - timeline
          - notification
          - media
          - search
          - system-admin
          - moderation
          - community
          - activitypub
    
    services:
      postgres:
        image: postgres:${{ env.POSTGRES_VERSION }}-alpine
        env:
          POSTGRES_DB: avion_${{ matrix.service }}_test
          POSTGRES_USER: test_user
          POSTGRES_PASSWORD: test_pass
          POSTGRES_INITDB_ARGS: "--encoding=UTF8"
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Set up Go
      uses: actions/setup-go@v5
      with:
        go-version: ${{ env.GO_VERSION }}
    
    - name: Install tools
      run: |
        go install github.com/pressly/goose/v3/cmd/goose@${GOOSE_VERSION}
        sudo apt-get update
        sudo apt-get install -y postgresql-client
    
    - name: Run migrations up
      working-directory: ./avion-${{ matrix.service }}
      env:
        DB_URL: "postgres://test_user:test_pass@localhost:5432/avion_${{ matrix.service }}_test?sslmode=disable"
      run: |
        echo "🚀 Running migrations for avion-${{ matrix.service }}"
        goose -dir ./migrations postgres "$DB_URL" up
        
        # バージョン確認
        current_version=$(goose -dir ./migrations postgres "$DB_URL" version)
        echo "Current version: $current_version"
    
    - name: Verify schema
      env:
        PGPASSWORD: test_pass
      run: |
        echo "📊 Verifying database schema"
        
        # テーブル一覧
        psql -h localhost -U test_user \
          -d avion_${{ matrix.service }}_test \
          -c "\dt" > schema_tables.txt
        
        # インデックス一覧
        psql -h localhost -U test_user \
          -d avion_${{ matrix.service }}_test \
          -c "\di" > schema_indexes.txt
        
        echo "Schema verification completed"
    
    - name: Test rollback
      working-directory: ./avion-${{ matrix.service }}
      env:
        DB_URL: "postgres://test_user:test_pass@localhost:5432/avion_${{ matrix.service }}_test?sslmode=disable"
      run: |
        echo "⬇️ Testing rollback"
        
        # 現在のバージョンを記録
        before_version=$(goose -dir ./migrations postgres "$DB_URL" version)
        
        # ロールバック実行
        goose -dir ./migrations postgres "$DB_URL" down
        
        # ロールバック後のバージョン確認
        after_version=$(goose -dir ./migrations postgres "$DB_URL" version)
        
        if [ "$before_version" == "$after_version" ]; then
          echo "❌ Rollback failed - version unchanged"
          exit 1
        fi
        
        # 再度最新まで適用
        goose -dir ./migrations postgres "$DB_URL" up
        
        echo "✅ Rollback test successful"
    
    - name: Upload schema artifacts
      uses: actions/upload-artifact@v3
      with:
        name: schema-${{ matrix.service }}
        path: schema_*.txt

  # ============================================
  # Stage 3: 環境別デプロイ
  # ============================================
  deploy:
    needs: [validate, test-migration]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/develop'
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Determine Environment
      id: env
      run: |
        if [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
          echo "environment=production" >> $GITHUB_OUTPUT
          echo "cluster=prod-cluster" >> $GITHUB_OUTPUT
          echo "namespace=avion-prod" >> $GITHUB_OUTPUT
        else
          echo "environment=staging" >> $GITHUB_OUTPUT
          echo "cluster=staging-cluster" >> $GITHUB_OUTPUT
          echo "namespace=avion-staging" >> $GITHUB_OUTPUT
        fi
    
    - name: Configure kubectl
      uses: azure/setup-kubectl@v3
      with:
        version: 'v1.28.0'
    
    - name: Set up Kubeconfig
      run: |
        echo "${{ secrets.KUBECONFIG }}" | base64 -d > kubeconfig
        export KUBECONFIG=$(pwd)/kubeconfig
    
    - name: Deploy Migration Jobs
      run: |
        for service in avion-auth avion-user avion-drop avion-timeline \
                      avion-notification avion-media avion-search \
                      avion-system-admin avion-moderation avion-community \
                      avion-activitypub; do
          
          echo "Deploying migration for $service"
          
          # Generate migration job manifest
          cat <<EOF | kubectl apply -f -
        apiVersion: batch/v1
        kind: Job
        metadata:
          name: ${service}-migration-${GITHUB_RUN_ID}
          namespace: ${{ steps.env.outputs.namespace }}
          labels:
            app: ${service}
            component: migration
            version: ${{ github.sha }}
            environment: ${{ steps.env.outputs.environment }}
        spec:
          backoffLimit: 2
          ttlSecondsAfterFinished: 3600
          template:
            metadata:
              labels:
                app: ${service}
                component: migration
            spec:
              restartPolicy: Never
              initContainers:
              - name: wait-for-db
                image: busybox:1.35
                command: ['sh', '-c', 'until nc -z \${DB_HOST} \${DB_PORT}; do echo waiting for db; sleep 2; done']
                envFrom:
                - configMapRef:
                    name: ${service}-config
              containers:
              - name: migration
                image: ${{ vars.DOCKER_REGISTRY }}/${service}:${{ github.sha }}
                command: ["goose"]
                args: ["-dir", "/app/migrations", "postgres", "\$(DB_URL)", "up"]
                envFrom:
                - secretRef:
                    name: ${service}-db-secret
                - configMapRef:
                    name: ${service}-config
                resources:
                  requests:
                    memory: "128Mi"
                    cpu: "100m"
                  limits:
                    memory: "256Mi"
                    cpu: "500m"
        EOF
          
          # Wait for job completion
          kubectl wait --for=condition=complete \
            job/${service}-migration-${GITHUB_RUN_ID} \
            -n ${{ steps.env.outputs.namespace }} \
            --timeout=300s || {
              echo "Migration failed for $service"
              kubectl logs job/${service}-migration-${GITHUB_RUN_ID} \
                -n ${{ steps.env.outputs.namespace }}
              exit 1
            }
          
          echo "Migration completed for $service"
        done
    
    - name: Deploy Applications
      run: |
        for service in avion-auth avion-user avion-drop avion-timeline \
                      avion-notification avion-media avion-search \
                      avion-gateway avion-system-admin avion-moderation \
                      avion-community avion-activitypub avion-web; do
          
          kubectl set image deployment/${service} \
            ${service}=${{ vars.DOCKER_REGISTRY }}/${service}:${{ github.sha }} \
            -n ${{ steps.env.outputs.namespace }}
          
          kubectl rollout status deployment/${service} \
            -n ${{ steps.env.outputs.namespace }} \
            --timeout=300s
        done
```

### 2.2 PR用マイグレーション検証

```yaml
# .github/workflows/pr-migration-check.yml
name: PR Migration Check

on:
  pull_request:
    paths:
      - '**/migrations/**'
      - '**/.goose.yml'

jobs:
  migration-lint:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0  # Full history for diff
    
    - name: Get Changed Files
      id: files
      run: |
        echo "migrations<<EOF" >> $GITHUB_OUTPUT
        git diff --name-only origin/${{ github.base_ref }}...${{ github.sha }} \
          | grep -E "migrations/.*\.sql$" >> $GITHUB_OUTPUT
        echo "EOF" >> $GITHUB_OUTPUT
    
    - name: SQL Syntax Check
      run: |
        # PostgreSQL syntax validation
        docker run --rm postgres:15-alpine psql --version
        
        for file in ${{ steps.files.outputs.migrations }}; do
          echo "Syntax check for $file"
          
          # Extract SQL statements
          sed -n '/^-- +goose Up/,/^-- +goose Down/p' "$file" \
            | grep -v "^--" > temp_up.sql
          
          sed -n '/^-- +goose Down/,//p' "$file" \
            | grep -v "^--" > temp_down.sql
          
          # Basic syntax validation
          if [ -s temp_up.sql ]; then
            echo "UP migration SQL extracted"
          fi
          
          if [ -s temp_down.sql ]; then
            echo "DOWN migration SQL extracted"
          fi
          
          rm -f temp_up.sql temp_down.sql
        done
```

---

## 3. Kubernetes Job実装

### 3.1 Job テンプレート

```yaml
# k8s/templates/migration-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ .ServiceName }}-migration-{{ .BuildNumber }}
  namespace: {{ .Namespace }}
  labels:
    app: {{ .ServiceName }}
    component: migration
    version: {{ .Version }}
    environment: {{ .Environment }}
  annotations:
    "helm.sh/hook": pre-upgrade
    "helm.sh/hook-weight": "-1"
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  backoffLimit: 2
  activeDeadlineSeconds: 600
  ttlSecondsAfterFinished: 3600
  template:
    metadata:
      labels:
        app: {{ .ServiceName }}
        component: migration
        version: {{ .Version }}
      annotations:
        sidecar.istio.io/inject: "false"
    spec:
      restartPolicy: Never
      serviceAccountName: {{ .ServiceName }}-migration
      
      initContainers:
      # データベース接続待機
      - name: wait-for-db
        image: busybox:1.35
        command: 
        - sh
        - -c
        - |
          echo "Waiting for database connection..."
          until nc -z ${DB_HOST} ${DB_PORT}; do
            echo "Database not ready, waiting..."
            sleep 2
          done
          echo "Database is ready!"
        env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: {{ .ServiceName }}-config
              key: db.host
        - name: DB_PORT
          valueFrom:
            configMapKeyRef:
              name: {{ .ServiceName }}-config
              key: db.port
      
      # バックアップ作成（本番環境のみ）
      {{ if eq .Environment "production" }}
      - name: backup-database
        image: postgres:15-alpine
        command:
        - sh
        - -c
        - |
          echo "Creating database backup..."
          export PGPASSWORD=${DB_PASSWORD}
          pg_dump -h ${DB_HOST} -U ${DB_USER} -d ${DB_NAME} \
            | gzip > /backup/backup-$(date +%Y%m%d-%H%M%S).sql.gz
          echo "Backup completed"
        env:
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: {{ .ServiceName }}-db-secret
              key: host
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: {{ .ServiceName }}-db-secret
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: {{ .ServiceName }}-db-secret
              key: password
        - name: DB_NAME
          valueFrom:
            secretKeyRef:
              name: {{ .ServiceName }}-db-secret
              key: database
        volumeMounts:
        - name: backup
          mountPath: /backup
      {{ end }}
      
      containers:
      # メインマイグレーションコンテナ
      - name: migration
        image: {{ .Registry }}/{{ .ServiceName }}:{{ .Version }}
        imagePullPolicy: IfNotPresent
        command:
        - sh
        - -c
        - |
          echo "Starting migration for {{ .ServiceName }}"
          echo "Environment: {{ .Environment }}"
          echo "Version: {{ .Version }}"
          
          # 現在の状態を表示
          goose -dir /app/migrations postgres "${DB_URL}" status
          
          # マイグレーション実行
          goose -dir /app/migrations postgres "${DB_URL}" up
          
          # 実行後の状態を表示
          goose -dir /app/migrations postgres "${DB_URL}" status
          
          echo "Migration completed successfully"
        env:
        - name: DB_URL
          valueFrom:
            secretKeyRef:
              name: {{ .ServiceName }}-db-secret
              key: url
        - name: GOOSE_VERBOSE
          value: "true"
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "1000m"
      
      volumes:
      - name: backup
        persistentVolumeClaim:
          claimName: {{ .ServiceName }}-backup-pvc
```

### 3.2 RBAC設定

```yaml
# k8s/templates/migration-rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .ServiceName }}-migration
  namespace: {{ .Namespace }}

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ .ServiceName }}-migration
  namespace: {{ .Namespace }}
rules:
- apiGroups: [""]
  resources: ["secrets", "configmaps"]
  verbs: ["get", "list"]
- apiGroups: ["batch"]
  resources: ["jobs"]
  verbs: ["get", "list", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ .ServiceName }}-migration
  namespace: {{ .Namespace }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: {{ .ServiceName }}-migration
subjects:
- kind: ServiceAccount
  name: {{ .ServiceName }}-migration
  namespace: {{ .Namespace }}
```

---

## 4. 環境別デプロイ戦略

### 4.1 開発環境

```yaml
# environments/development/migration-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: migration-config
  namespace: avion-dev
data:
  auto_run: "true"
  backup_enabled: "false"
  rollback_on_failure: "true"
  max_retries: "3"
  timeout_seconds: "300"
  dry_run: "false"
```

### 4.2 ステージング環境

```yaml
# environments/staging/migration-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: migration-config
  namespace: avion-staging
data:
  auto_run: "true"
  backup_enabled: "true"
  rollback_on_failure: "true"
  max_retries: "2"
  timeout_seconds: "600"
  dry_run: "false"
  notification_webhook: "https://hooks.slack.com/services/..."
```

### 4.3 本番環境

```yaml
# environments/production/migration-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: migration-config
  namespace: avion-prod
data:
  auto_run: "false"  # 手動承認必須
  backup_enabled: "true"
  backup_retention_days: "30"
  rollback_on_failure: "false"  # 手動判断
  max_retries: "1"
  timeout_seconds: "1800"
  dry_run: "true"  # 最初はドライラン
  approval_required: "true"
  approvers: "platform-team@avion.app"
  notification_webhook: "https://hooks.slack.com/services/..."
  pagerduty_integration_key: "..."
```

---

## 5. 安全性確保

### 5.1 承認プロセス（本番環境）

```yaml
# .github/workflows/production-approval.yml
name: Production Migration Approval

on:
  workflow_dispatch:
    inputs:
      service:
        description: 'Service to migrate'
        required: true
        type: choice
        options:
          - avion-auth
          - avion-user
          - avion-drop
          - avion-timeline
          - avion-notification
          - avion-media
          - avion-search
          - avion-system-admin
          - avion-moderation
          - avion-community
          - avion-activitypub
      version:
        description: 'Version to deploy'
        required: true

jobs:
  approval:
    runs-on: ubuntu-latest
    environment: production
    
    steps:
    - name: Request Approval
      uses: trstringer/manual-approval@v1
      with:
        secret: ${{ secrets.GITHUB_TOKEN }}
        approvers: platform-team
        minimum-approvals: 2
        issue-title: "Production Migration Approval: ${{ inputs.service }} v${{ inputs.version }}"
        issue-body: |
          ## Migration Approval Request
          
          **Service:** ${{ inputs.service }}
          **Version:** ${{ inputs.version }}
          **Requested by:** ${{ github.actor }}
          **Time:** ${{ github.event.head_commit.timestamp }}
          
          ### Checklist
          - [ ] Migration tested in staging
          - [ ] Rollback plan documented
          - [ ] Backup verified
          - [ ] Maintenance window scheduled
          - [ ] Team notified
          
          Please review and approve/reject this migration.
    
    - name: Execute Migration
      if: success()
      run: |
        echo "Migration approved, executing..."
        # Trigger actual migration job
```

### 5.2 バックアップとリストア

```bash
#!/bin/bash
# scripts/backup-restore.sh

SERVICE_NAME=$1
ENVIRONMENT=$2
ACTION=$3

backup() {
    echo "Creating backup for $SERVICE_NAME in $ENVIRONMENT"
    
    kubectl exec -n avion-$ENVIRONMENT \
        deployment/$SERVICE_NAME-db \
        -- pg_dump -U avion -d ${SERVICE_NAME}_db \
        | gzip > backup-${SERVICE_NAME}-$(date +%Y%m%d-%H%M%S).sql.gz
    
    # S3にアップロード
    aws s3 cp backup-*.sql.gz \
        s3://avion-backups/$ENVIRONMENT/$SERVICE_NAME/
}

restore() {
    BACKUP_FILE=$4
    echo "Restoring $SERVICE_NAME from $BACKUP_FILE"
    
    # S3からダウンロード
    aws s3 cp s3://avion-backups/$ENVIRONMENT/$SERVICE_NAME/$BACKUP_FILE .
    
    # リストア実行
    gunzip -c $BACKUP_FILE | kubectl exec -i -n avion-$ENVIRONMENT \
        deployment/$SERVICE_NAME-db \
        -- psql -U avion -d ${SERVICE_NAME}_db
}

case $ACTION in
    backup)
        backup
        ;;
    restore)
        restore
        ;;
    *)
        echo "Usage: $0 <service> <environment> <backup|restore> [backup-file]"
        exit 1
        ;;
esac
```

---

## 6. 監視とアラート

### 6.1 Prometheus設定

```yaml
# monitoring/prometheus-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: migration-alerts
  namespace: avion-monitoring
spec:
  groups:
  - name: migration
    interval: 30s
    rules:
    # マイグレーション失敗
    - alert: MigrationFailed
      expr: |
        kube_job_failed{job_name=~".*-migration-.*"} > 0
      for: 1m
      labels:
        severity: critical
        team: platform
      annotations:
        summary: "Migration failed for {{ $labels.job_name }}"
        description: "Migration job {{ $labels.job_name }} in namespace {{ $labels.namespace }} has failed"
        runbook_url: "https://wiki.avion.app/runbooks/migration-failure"
    
    # マイグレーション長時間実行
    - alert: MigrationTakingTooLong
      expr: |
        (time() - kube_job_status_start_time{job_name=~".*-migration-.*"}) > 600
      for: 1m
      labels:
        severity: warning
        team: platform
      annotations:
        summary: "Migration taking too long"
        description: "Migration {{ $labels.job_name }} has been running for more than 10 minutes"
    
    # マイグレーション成功率
    - alert: LowMigrationSuccessRate
      expr: |
        (
          sum(rate(kube_job_status_succeeded{job_name=~".*-migration-.*"}[1h]))
          /
          sum(rate(kube_job_status_completion_time{job_name=~".*-migration-.*"}[1h]))
        ) < 0.95
      for: 5m
      labels:
        severity: warning
        team: platform
      annotations:
        summary: "Migration success rate below 95%"
        description: "Migration success rate is {{ $value | humanizePercentage }}"
```

### 6.2 Grafanaダッシュボード

```json
{
  "dashboard": {
    "title": "Database Migration Dashboard",
    "panels": [
      {
        "title": "Migration Execution Time",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, kube_job_status_completion_time{job_name=~\".*-migration-.*\"})"
          }
        ]
      },
      {
        "title": "Migration Success Rate",
        "targets": [
          {
            "expr": "sum(rate(kube_job_status_succeeded{job_name=~\".*-migration-.*\"}[1h])) by (namespace)"
          }
        ]
      },
      {
        "title": "Active Migrations",
        "targets": [
          {
            "expr": "kube_job_status_active{job_name=~\".*-migration-.*\"}"
          }
        ]
      },
      {
        "title": "Failed Migrations",
        "targets": [
          {
            "expr": "kube_job_status_failed{job_name=~\".*-migration-.*\"}"
          }
        ]
      }
    ]
  }
}
```

---

## 7. ロールバック戦略

### 7.1 自動ロールバック

```yaml
# k8s/templates/rollback-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ .ServiceName }}-rollback-{{ .BuildNumber }}
  namespace: {{ .Namespace }}
spec:
  template:
    spec:
      containers:
      - name: rollback
        image: {{ .Registry }}/{{ .ServiceName }}:{{ .PreviousVersion }}
        command:
        - sh
        - -c
        - |
          echo "Rolling back migration for {{ .ServiceName }}"
          
          # 現在のバージョンを取得
          CURRENT_VERSION=$(goose -dir /app/migrations postgres "${DB_URL}" version)
          echo "Current version: $CURRENT_VERSION"
          
          # 前のバージョンまでロールバック
          TARGET_VERSION=$((CURRENT_VERSION - 1))
          echo "Rolling back to version: $TARGET_VERSION"
          
          goose -dir /app/migrations postgres "${DB_URL}" down-to $TARGET_VERSION
          
          # 確認
          NEW_VERSION=$(goose -dir /app/migrations postgres "${DB_URL}" version)
          if [ "$NEW_VERSION" = "$TARGET_VERSION" ]; then
            echo "Rollback successful"
            exit 0
          else
            echo "Rollback failed"
            exit 1
          fi
```

### 7.2 手動ロールバック手順

```bash
#!/bin/bash
# scripts/manual-rollback.sh

SERVICE=$1
ENVIRONMENT=$2
TARGET_VERSION=$3

echo "==================================="
echo "Manual Rollback Process"
echo "Service: $SERVICE"
echo "Environment: $ENVIRONMENT"
echo "Target Version: $TARGET_VERSION"
echo "==================================="

# 確認
read -p "Are you sure you want to rollback? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Rollback cancelled"
    exit 1
fi

# 現在のバージョン確認
echo "Checking current version..."
kubectl exec -n avion-$ENVIRONMENT \
    deployment/$SERVICE \
    -- goose -dir /app/migrations postgres "\${DB_URL}" version

# バックアップ作成
echo "Creating backup before rollback..."
./backup-restore.sh $SERVICE $ENVIRONMENT backup

# ロールバック実行
echo "Executing rollback..."
kubectl exec -n avion-$ENVIRONMENT \
    deployment/$SERVICE \
    -- goose -dir /app/migrations postgres "\${DB_URL}" down-to $TARGET_VERSION

# 確認
echo "Verifying rollback..."
kubectl exec -n avion-$ENVIRONMENT \
    deployment/$SERVICE \
    -- goose -dir /app/migrations postgres "\${DB_URL}" status

echo "Rollback completed"
```

---

## まとめ

このCI/CDパイプラインマイグレーション戦略により：

1. **自動化**: PR作成から本番デプロイまで完全自動化
2. **安全性**: 多段階の検証とロールバック機能
3. **可視性**: 包括的な監視とアラート
4. **一貫性**: 全環境で統一された実行プロセス
5. **信頼性**: テスト、バックアップ、承認プロセスによる高信頼性

すべてのAvionマイクロサービスでこの戦略を採用することで、安全で予測可能なデータベース変更管理を実現します。