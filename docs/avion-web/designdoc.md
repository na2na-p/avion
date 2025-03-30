# Design Doc: avion-web

**Author:** Cline
**Last Updated:** 2025/03/30

## 1. Summary (これは何？)

- **一言で:** Avionのユーザーインターフェースを提供するWebフロントエンドアプリケーション (PWA) を実装します。
- **目的:** ReactとTypeScriptを使用し、Web BFF (`avion-bff-web`) が提供するGraphQL APIを利用して、ユーザーがAvionの機能を直感的に操作できるインターフェースを提供します。SSEによるリアルタイム更新、Web Pushによる通知機能も実装します。

## 2. Background & Links (背景と関連リンク)

- ユーザーがAvionサービスを利用するための主要なインターフェースを提供するため。
- モダンなWeb技術を採用し、インタラクティブでネイティブアプリに近い体験を提供するため。
- [PRD: avion-web](./prd.md)
- [Avion アーキテクチャ概要](../architecture.md)
- [Design Doc: avion-bff-web](../avion-bff-web/designdoc.md)

## 3. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

- ReactとTypeScriptを用いたシングルページアプリケーション (SPA) の構築。
- 主要画面 (タイムライン、投稿、プロフィール、通知、設定など) のUIコンポーネント実装。
- `avion-bff-web` のGraphQL APIとの連携 (データ取得、ミューテーション実行)。
- クライアントサイドの状態管理 (認証状態、UI状態、取得データなど)。
- クライアントサイドルーティングの実装。
- レスポンシブデザインによるマルチデバイス対応。
- PWA対応 (Web App Manifest, Service Worker)。
- SSEクライアント実装によるリアルタイム更新の反映 (BFF経由)。
- Web Push APIを利用したプッシュ通知の購読と表示。
- Passkey (WebAuthn) およびTOTPの登録・認証に関わるUIフローの実装。
- 基本的なアクセシビリティ対応 (WCAG 2.1 AA目標)。
- 基本的なテスト戦略（Unit, Component, E2E）の定義と実装。
- (推奨/Stretch) OpenTelemetryによるフロントエンドトレーシング・メトリクス・ロギング対応。

### Non-Goals (やらないこと)

- **ネイティブモバイルアプリ開発。**
- **高度なオフライン機能 (初期)。**
- **サーバーサイドレンダリング (SSR) (初期):** クライアントサイドレンダリング (CSR) を基本とする。
- **複雑なテーマカスタマイズ (初期)。**
- **WebSocketクライアント実装。**
- **国際化 (i18n) / 地域化 (l10n) (v1)。**

## 4. Architecture (どうやって作る？)

- **主要技術スタック (推奨):**
    - `React`: UIライブラリ。
    - `TypeScript`: 静的型付け。
    - `GraphQL Client (Apollo Client or urql)`: BFFとの通信。
    - `State Management (Zustand or Jotai)`: クライアント状態管理 (シンプルさ重視)。
    - `Router (React Router)`: クライアントサイドルーティング。
    - `UI Library/Framework (Tailwind CSS + Headless UI or Chakra UI)`: UIコンポーネント構築支援。
    - `Build Tool (Vite)`: バンドル、開発サーバー (高速性重視)。
    - `Service Worker (Workbox)`: PWA機能、Web Push受信 (実装簡略化)。
    - `Testing (Vitest/Jest + React Testing Library, Playwright/Cypress)`: 各種テスト。
- **構成:**
    - `avion-web` は静的ファイル (HTML, CSS, JS) としてビルドされ、CDN経由で配信される。
    - ブラウザ上で動作し、`/graphql` エンドポイントを持つ `avion-bff-web` と通信する。
    - Service Workerがバックグラウンドで動作し、キャッシュ管理やプッシュ通知処理を行う。
    - SSE接続は `avion-bff-web` の `/events` エンドポイントに対して行う。
- **ポイント:**
    - BFFを介してバックエンドと通信する。
    - PWAとして動作し、インストールやプッシュ通知が可能。
    - SSEでリアルタイムな情報更新を実現。
    - モダンで開発効率とパフォーマンスのバランスが良い技術スタックを選定。

## 5. Use Cases / Key Flows (主な使い方・処理の流れ)

- (PRDのユースケースを参照)
- **フロー 1: 初期ロードとタイムライン表示** (変更なし)
    ...
- **フロー 2: Web Push受信 (アプリ非アクティブ時)** (変更なし)
    ...

## 6. Endpoints (API)

- `avion-bff-web` の `/graphql` エンドポイントを利用。
- `avion-bff-web` の `/events` SSEエンドポイントを利用。
- GraphQLスキーマは別途定義・管理する。

## 7. Data Design (データ)

- フロントエンドは基本的に状態を永続化しないが、以下をローカルに保存する。
    - **LocalStorage / SessionStorage:** JWT、ユーザー設定の一部、UI状態など。
    - **IndexedDB (Service Worker経由):** (将来的なオフライン対応用) キャッシュされたAPIレスポンスなど。Service WorkerのキャッシュAPI (Cache Storage) も利用。

## 8. Operations & Monitoring (運用と監視)

- **主なオペレーション:**
    - 静的ファイルのビルドとCDNへのデプロイ。
    - Service Workerの更新とキャッシュ管理戦略の適用。
- **監視/アラート:**
    - **フロントエンド監視 (Sentry, Datadog RUMなど):**
        - JavaScriptエラー。
        - パフォーマンスメトリクス (Core Web Vitals)。
        - API (GraphQL) コール失敗レート。
        - SSE接続エラー。
        - Web Push登録/受信エラー。
    - **ログ:** 主要なユーザー操作、エラー情報などを収集 (必要に応じてログ収集サービスへ送信)。
    - **トレース:** (OpenTelemetry導入時) フロントエンド操作からBFF/バックエンドへのリクエスト追跡。
    - **アラート:** JavaScriptエラーレート急増、Core Web Vitals悪化、GraphQL APIエラーレート上昇。

## 9. Concerns / Open Questions (懸念事項・相談したいこと)

- **技術的負債リスク:**
    - **状態管理の複雑化:** アプリケーション規模増大に伴うリスク。選択したライブラリ(Zustand/Jotai推奨)のベストプラクティス適用と適切なコンポーネント設計が重要。
    - **パフォーマンス:** 継続的な計測(Lighthouse, WebPageTest)と最適化(Code Splitting, Memoization, Lazy Loading, Efficient GraphQL Query)が必要。
    - **PWA/Service Workerの複雑性:** Workbox利用でリスク軽減を図るが、キャッシュ戦略や更新フローのテストは依然として重要。
    - **依存ライブラリ管理:** 定期的な `npm audit` や Dependabot 等による脆弱性チェックと更新プロセスが必要。
    - **ビルド/開発環境:** Vite採用でリスク軽減を図るが、設定が複雑化しないよう注意。
- **技術スタック最終決定:** 上記推奨スタックで進めるか、代替案を検討するか。
- **テスト戦略:** Unit/Component/E2Eの具体的なカバレッジ目標と実行環境。
- **Service Workerキャッシュ戦略詳細:** App Shellの範囲、APIキャッシュの具体的な戦略（NetworkFirst, StaleWhileRevalidateなど）。
- **OpenTelemetryフロントエンド実装:** v1での導入範囲（コアフローのみか、広範囲か）。

---
