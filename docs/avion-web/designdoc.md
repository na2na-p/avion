# Design Doc: avion-web

**Author:** Cline
**Last Updated:** 2025/08/02

## 1. Summary (これは何？)

- **一言で:** AvionのWebフロントエンドとBFF機能を統合したNext.jsアプリケーションを構築し、フロントエンドはCDN経由で配信し、API RoutesでGraphQLとSSEを提供します。
- **目的:** ユーザーに直感的なインターフェースを提供し、フロントエンドとBFFの統合による開発効率の向上と、マイクロサービスの複雑性を吸収した優れたユーザー体験を実現します。

## 2. モック生成戦略

このサービスでは、TypeScriptベースの開発においてテスト容易性を向上させるため、Apollo ClientのSchemaLinkを活用したGraphQLモック戦略を採用します。

### TypeScriptモック戦略
- **クライアントサイド（React）**: `@testing-library/react` と `vitest` のモック機能を使用
- **GraphQL**: Apollo Client `SchemaLink` でスキーマベースの型安全なモック実装
- **SSE**: EventSource APIのカスタムモック実装

### モック生成ルール
- GraphQLスキーマから自動的に型生成（`@graphql-codegen/typescript`）
- `tests/mocks/` ディレクトリに配置し、元ファイルのディレクトリ構造を反映
- TypeScript型定義を活用した型安全なモック生成
- 実行時とテスト時で異なる実装を注入可能な設計

### 生成対象インターフェース
- Repository Interfaces (Domain Layer)
- Query Service Interfaces (Use Case Layer)  
- External Service Interfaces (Use Case Layer)
- GraphQL Client Interfaces
- SSE Client Interfaces

### SchemaLinkを使用したGraphQLモック実装
```typescript
// GraphQLスキーマベースのモック実装
import { ApolloClient, InMemoryCache } from '@apollo/client';
import { SchemaLink } from '@apollo/client/link/schema';
import { makeExecutableSchema } from '@graphql-tools/schema';
import { addMocksToSchema } from '@graphql-tools/mock';

// スキーマ定義（実際のスキーマファイルから読み込み）
const typeDefs = /* GraphQL */ `
  type Query {
    homeTimeline(first: Int!, after: String): TimelineConnection!
    user(id: ID!): User
  }
  # ... 他の型定義
`;

// モックリゾルバーの定義
const mocks = {
  Query: () => ({
    homeTimeline: (_, { first, after }) => ({
      edges: Array(first).fill(null).map((_, i) => ({
        node: {
          id: `drop-${i}`,
          content: `Test drop content ${i}`,
          createdAt: new Date().toISOString(),
        },
        cursor: `cursor-${i}`,
      })),
      pageInfo: {
        hasNextPage: true,
        endCursor: `cursor-${first}`,
      },
    }),
    user: (_, { id }) => ({
      id,
      username: `user-${id}`,
      displayName: `User ${id}`,
    }),
  }),
  Mutation: () => ({
    createDrop: (_, { input }) => ({
      id: 'new-drop-id',
      content: input.content,
      createdAt: new Date().toISOString(),
    }),
  }),
};

// テスト用Apollo Clientの作成
export const createMockApolloClient = (customMocks = {}) => {
  const schema = makeExecutableSchema({ typeDefs });
  const schemaWithMocks = addMocksToSchema({
    schema,
    mocks: {
      ...mocks,
      ...customMocks,
    },
    preserveResolvers: false,
  });

  return new ApolloClient({
    link: new SchemaLink({ schema: schemaWithMocks }),
    cache: new InMemoryCache(),
    defaultOptions: {
      watchQuery: { fetchPolicy: 'no-cache' },
      query: { fetchPolicy: 'no-cache' },
    },
  });
};

// Repository のモックファクトリー例
export const createMockAuthRepository = (): AuthRepository => ({
  saveToken: vi.fn().mockResolvedValue(undefined),
  getToken: vi.fn().mockResolvedValue(null),
  clearToken: vi.fn().mockResolvedValue(undefined),
  refreshToken: vi.fn().mockResolvedValue(mockAuthToken),
});

// SSEモックの実装
export class MockEventSource implements EventSourceLike {
  private listeners = new Map<string, Set<EventListener>>();
  
  constructor(public url: string) {}
  
  addEventListener(type: string, listener: EventListener): void {
    if (!this.listeners.has(type)) {
      this.listeners.set(type, new Set());
    }
    this.listeners.get(type)!.add(listener);
  }
  
  emit(type: string, data: any): void {
    const event = new MessageEvent(type, { data: JSON.stringify(data) });
    this.listeners.get(type)?.forEach(listener => listener(event));
  }
  
  close(): void {
    this.listeners.clear();
  }
}
```

### テストでの使用例
```typescript
import { render, screen } from '@testing-library/react';
import { ApolloProvider } from '@apollo/client';
import { createMockApolloClient } from '@/tests/mocks/apollo';
import { Timeline } from '@/components/Timeline';

describe('Timeline', () => {
  it('should render timeline items', async () => {
    const mockClient = createMockApolloClient({
      Query: () => ({
        homeTimeline: () => ({
          edges: [
            { node: { id: '1', content: 'Custom test drop' } },
          ],
        }),
      }),
    });

    render(
      <ApolloProvider client={mockClient}>
        <Timeline />
      </ApolloProvider>
    );

    expect(await screen.findByText('Custom test drop')).toBeInTheDocument();
  });
});
```

### 実行方法
```bash
# GraphQL型生成
npm run codegen

# テスト実行（モック自動使用）
npm test

# 特定のモックファクトリー生成
npm run generate:mocks
```

## 3. Background & Links (背景と関連リンク)

- Next.jsを採用してフロントエンドとBFFを統合し、開発効率と運用コストの最適化を実現。
- React + TypeScriptの採用により、型安全な開発体験と保守性の高いコードを実現。
- [PRD: avion-web](./prd.md)
- [Avion アーキテクチャ概要](../common/architecture.md)
- [avion-gateway Design Doc](../avion-gateway/designdoc.md)

## 4. Configuration Management (設定管理)

このサービスでは、[共通環境変数管理パターン](../common/infrastructure/environment-variables.md)に従って設定管理を実装します。フロントエンドアプリケーションでは、Viteの環境変数機能を使用してビルド時設定を管理します。

### 4.1. Environment Variables (環境変数)

#### Required Variables (必須環境変数)
- `VITE_API_URL`: GraphQL APIエンドポイントURL
- `VITE_WS_URL`: WebSocket/SSEエンドポイントURL
- `VITE_CDN_URL`: メディアファイル配信用CDN URL

#### Optional Variables (オプション環境変数)
- `VITE_SENTRY_DSN`: Sentry Error Tracking DSN (default: undefined)
- `VITE_ENVIRONMENT`: 実行環境 (default: production)
- `VITE_ENABLE_PWA`: PWA機能の有効化 (default: true)

### 4.2. Config Implementation (設定実装)

```typescript
// src/infrastructure/config/AppConfig.ts
export interface AppConfig {
  readonly apiUrl: string;
  readonly wsUrl: string;
  readonly cdnUrl: string;
  readonly sentryDsn?: string;
  readonly environment: Environment;
  readonly enablePwa: boolean;
}

export type Environment = 'development' | 'staging' | 'production';

export class ConfigLoader {
  static load(): AppConfig {
    const requiredVars = ['VITE_API_URL', 'VITE_WS_URL', 'VITE_CDN_URL'];
    const missing = requiredVars.filter(key => !import.meta.env[key]);
    
    if (missing.length > 0) {
      throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
    }

    return {
      apiUrl: import.meta.env.VITE_API_URL,
      wsUrl: import.meta.env.VITE_WS_URL,
      cdnUrl: import.meta.env.VITE_CDN_URL,
      sentryDsn: import.meta.env.VITE_SENTRY_DSN,
      environment: (import.meta.env.VITE_ENVIRONMENT as Environment) || 'production',
      enablePwa: import.meta.env.VITE_ENABLE_PWA !== 'false',
    };
  }
}
```

### 4.3. Configuration Validation (設定検証)

```typescript
// src/infrastructure/config/ConfigValidator.ts
export class ConfigValidator {
  static validate(config: AppConfig): void {
    // URL validation
    if (!this.isValidUrl(config.apiUrl)) {
      throw new Error('Invalid VITE_API_URL: must be a valid URL');
    }
    
    if (!this.isValidUrl(config.wsUrl)) {
      throw new Error('Invalid VITE_WS_URL: must be a valid URL');
    }
    
    if (!this.isValidUrl(config.cdnUrl)) {
      throw new Error('Invalid VITE_CDN_URL: must be a valid URL');
    }

    // Environment validation
    const validEnvs: Environment[] = ['development', 'staging', 'production'];
    if (!validEnvs.includes(config.environment)) {
      throw new Error(`Invalid VITE_ENVIRONMENT: must be one of ${validEnvs.join(', ')}`);
    }

    // Sentry DSN validation (if provided)
    if (config.sentryDsn && !this.isValidSentryDsn(config.sentryDsn)) {
      throw new Error('Invalid VITE_SENTRY_DSN: must be a valid Sentry DSN');
    }
  }

  private static isValidUrl(url: string): boolean {
    try {
      new URL(url);
      return true;
    } catch {
      return false;
    }
  }

  private static isValidSentryDsn(dsn: string): boolean {
    return dsn.startsWith('https://') && dsn.includes('@sentry.io');
  }
}
```

### 4.4. Environment Files (環境ファイル)

```bash
# .env.example
VITE_API_URL=http://localhost:8080/graphql
VITE_WS_URL=ws://localhost:8080/subscriptions
VITE_CDN_URL=http://localhost:9000
VITE_SENTRY_DSN=
VITE_ENVIRONMENT=development
VITE_ENABLE_PWA=true
```

```bash
# .env.production
VITE_API_URL=https://api.avion.social/graphql
VITE_WS_URL=wss://api.avion.social/subscriptions
VITE_CDN_URL=https://cdn.avion.social
VITE_ENVIRONMENT=production
VITE_ENABLE_PWA=true
```

## 5. Goals / Non-Goals (やること / やらないこと)

### Goals (やること)

#### フロントエンド機能
- React + React RouterによるCSRベースのSPA構築。
- 主要画面（タイムライン、投稿、プロフィール、通知、設定等）の実装。
- クライアントサイドの状態管理（ViewState、UserSession）。
- レスポンシブデザインによるマルチデバイス対応。
- PWA対応（Web App Manifest、Service Worker）。
- Web Push APIを利用したプッシュ通知。
- PasskeyおよびTOTPの登録・認証UIフロー。
- OAuth 2.0/OpenID Connect同意画面の提供。
- 基本的なアクセシビリティ対応（WCAG 2.1 AA目標）。

#### BFF機能（API Routes）
- GraphQL APIの実装と複数バックエンドサービスからのデータ集約。
- SSEエンドポイントによるリアルタイム更新配信。
- DataLoaderパターンによるバッチング最適化。
- キャッシュ戦略の実装（Apollo Cache等）。
- 楽観的更新の実装。
- エラーハンドリングとリトライ。

#### 技術要件
- TypeScriptによる型安全な実装。
- 効率的なキャッシング戦略。
- OpenTelemetryによるトレーシング。
- 包括的なテスト戦略。

### Non-Goals (やらないこと)

- **SSR/SSG:** CSRベースのSPAとして実装。
- **ネイティブモバイルアプリ:** Web専用。
- **バックエンドマイクロサービスの直接呼び出し:** avion-gateway経由で通信。
- **認証・認可の実装:** avion-gatewayとavion-iamが担当。
- **レート制限:** avion-gatewayが担当。
- **データの永続化:** バックエンドサービスに委譲。
- **WebSocket:** SSEで十分なため実装しない。
- **高度なオフライン機能（初期）。**
- **国際化（i18n）対応（初期）。**

## 6. Architecture (どうやって作る？)

### 5.1. レイヤードアーキテクチャ (DDD準拠)

#### Domain Layer (ドメイン層)

**Aggregates (集約):**
- ViewState: アプリケーション全体の表示状態を管理
- UserSession: ユーザーセッション情報と認証状態を管理
- GraphQLClient: GraphQLクライアント状態とキャッシュを管理
- SSEClient: SSE接続状態とイベントストリームを管理
- FormState: フォームの入力状態とバリデーションを管理

**Entities (エンティティ):**
- TimelineViewState: タイムライン表示状態
- NotificationState: 通知状態と未読数
- ModalState: モーダルダイアログ状態
- CacheEntry: クライアントサイドキャッシュエントリ
- ConsentSession: OAuth同意セッション
- EventBuffer: SSEイベントバッファ
- FieldState: フォームフィールド状態
- ScrollState: スクロール位置状態
- TabState: タブ切り替え状態
- OptimisticUpdate: 楽観的更新状態

**Value Objects (値オブジェクト):**
認証・セッション関連:
- SessionID, AuthToken, RefreshToken, DeviceFingerprint
- IPAddress, UserAgent, AuthMethod

GraphQL関連:
- GraphQLQuery, GraphQLVariables, OperationName
- CacheKey, CacheTTL, QueryID

SSE/リアルタイム関連:
- ConnectionID, SSEEvent, EventType, EventFilter
- HeartbeatInterval, ReconnectDelay

UI/表示関連:
- Route, RouteParams, ScrollPosition, Theme, Language
- Breakpoint, ModalType, ZIndex

フォーム関連:
- FormID, FieldName, FieldValue, ValidationError
- FormStatus, DirtyFlag

時刻・期間関連:
- Timestamp, Duration, TTL, ExpiresAt

ページネーション関連:
- CursorToken, PageSize, HasMore

通知関連:
- NotificationID, NotificationType, UnreadCount, PushSubscription

**Domain Services (ドメインサービス):**
- EventProcessingService: SSEイベントの処理とUI更新
- ValidationService: 入力データの検証とサニタイゼーション
- CacheStrategyService: キャッシュ戦略の決定と実行
- OptimisticUpdateService: 楽観的更新の管理とロールバック
- AuthenticationService: 認証トークン管理とリフレッシュ

**Repository Interfaces (リポジトリインターフェース):**
※注: DDDの原則により、RepositoryはAggregate単位でのみ取得・更新を行い、更新系UseCaseからのみ呼び出されます。
- ViewStateRepository: ViewState Aggregateの永続化（SessionStorage）
- UserSessionRepository: UserSession Aggregateの永続化（LocalStorage）
- SSEClientRepository: SSEClient Aggregateの永続化（メモリ/SessionStorage）
- OAuthConsentRepository: OAuthConsent Aggregateの永続化（SessionStorage）

#### Use Case Layer (ユースケース層)

**Command Use Cases (更新系):**
- LoginCommandUseCase: ログイン処理とセッション確立
- LogoutCommandUseCase: ログアウト処理とセッション破棄
- RefreshTokenCommandUseCase: トークンリフレッシュ
- CreateDropCommandUseCase: Drop作成と楽観的更新
- DeleteDropCommandUseCase: Drop削除
- AddReactionCommandUseCase: リアクション追加
- RemoveReactionCommandUseCase: リアクション削除
- FollowUserCommandUseCase: フォロー処理
- UnfollowUserCommandUseCase: アンフォロー処理
- UpdateProfileCommandUseCase: プロフィール更新
- EstablishSSEConnectionCommandUseCase: SSE接続確立
- CloseSSEConnectionCommandUseCase: SSE接続クローズ
- RegisterPushSubscriptionCommandUseCase: Push通知購読
- UnregisterPushSubscriptionCommandUseCase: Push通知購読解除
- GrantOAuthConsentCommandUseCase: OAuth同意処理
- DenyOAuthConsentCommandUseCase: OAuth拒否処理
- UpdateFormFieldCommandUseCase: フォームフィールド更新
- SubmitFormCommandUseCase: フォーム送信
- NavigateCommandUseCase: ルート遷移
- UpdateThemeCommandUseCase: テーマ変更

**Query Use Cases (参照系):**
- GetTimelineQueryUseCase: タイムライン取得（ホーム/ローカル/グローバル）
- GetUserProfileQueryUseCase: プロフィール取得
- GetDropDetailQueryUseCase: Drop詳細取得
- GetNotificationsQueryUseCase: 通知一覧取得
- GetFollowersQueryUseCase: フォロワー一覧取得
- GetFollowingQueryUseCase: フォロー一覧取得
- SearchDropsQueryUseCase: Drop検索
- SearchUsersQueryUseCase: ユーザー検索
- GetOAuthSessionQueryUseCase: OAuth認可セッション情報取得
- GetOAuthClientInfoQueryUseCase: OAuthクライアント情報取得
- GetCurrentSessionQueryUseCase: 現在のセッション情報取得
- GetCachedDataQueryUseCase: キャッシュデータ取得

**Query Service Interfaces (クエリサービスインターフェース):**
※注: 参照系(GET)処理からのみ呼び出され、DTOを返すメソッドのみを備えます。
- TimelineQueryService: タイムラインデータの高速取得（DTOを返却）
- UserQueryService: ユーザー情報の高速取得（DTOを返却）
- NotificationQueryService: 通知情報の高速取得（DTOを返却）
- SearchQueryService: 検索クエリの実行（DTOを返却）
- AuthQueryService: 認証トークンの参照（DTOを返却）
- PreferenceQueryService: ユーザー設定の参照（DTOを返却）

**External Service Interfaces (外部サービスインターフェース):**
※注: 外部APIを直接呼び出すためのインターフェースです。
- GatewayGraphQLExternal: GatewayのGraphQLエンドポイントとの通信
- GatewaySSEExternal: GatewayのSSEエンドポイントとの通信
- MediaUploadExternal: メディアアップロード処理
- WebPushExternal: Web Push API との通信
- ServiceWorkerExternal: Service Worker API との通信

**DTOs (データ転送オブジェクト):**
- LoginDTO, LogoutDTO, TokenRefreshDTO
- TimelineDTO, TimelineItemDTO, TimelinePageDTO
- UserProfileDTO, UserSummaryDTO, UserStatsDTO
- DropDTO, DropCreateDTO, DropUpdateDTO
- ReactionDTO, ReactionSummaryDTO
- NotificationDTO, NotificationPageDTO
- SearchResultDTO, SearchQueryDTO
- OAuthConsentDTO, OAuthClientDTO
- FormSubmissionDTO, ValidationResultDTO

#### Infrastructure Layer (インフラストラクチャ層)
- **Repository実装:**
  - SessionStorageViewStateRepository: ViewStateの一時保存
  - LocalStorageUserSessionRepository: UserSessionの永続化
  - InMemorySSEClientRepository: SSEClientのメモリ管理
  - SessionStorageOAuthConsentRepository: OAuthConsentの一時保存
- **QueryService実装:**
  - GraphQLTimelineQueryService: GraphQL経由でのタイムライン取得
  - GraphQLUserQueryService: GraphQL経由でのユーザー情報取得
  - GraphQLNotificationQueryService: GraphQL経由での通知取得
  - GraphQLSearchQueryService: GraphQL経由での検索
  - LocalStorageAuthQueryService: LocalStorageからの認証情報取得
  - LocalStoragePreferenceQueryService: LocalStorageからの設定取得
- **External Service実装:**
  - ApolloGatewayGraphQLExternal: Apollo Clientを使用したGraphQL通信
  - EventSourceGatewaySSEExternal: EventSource APIを使用したSSE通信
  - FetchMediaUploadExternal: Fetch APIを使用したメディアアップロード
  - NativeWebPushExternal: ネイティブWeb Push APIのラップ
  - NativeServiceWorkerExternal: ネイティブService Worker APIのラップ
- **Cache:**
  - ApolloCache: Apollo Clientのキャッシュ機能
  - ServiceWorkerCache: Service Workerによるキャッシュ

#### Handler Layer (ハンドラー層)

Container-Presentationパターンを適用し、ビジネスロジックとUIロジックを分離します。

- **Container Components:** ビジネスロジック担当（UseCase呼び出し、状態管理）
- **Presentational Components:** UI表示担当（読み取り専用プロパティ、UIロジックのみ）
- **Event Handlers:** ユーザーインタラクション、SSEイベント受信、エラーハンドリング

### 5.2. ディレクトリ構造

```
avion-web/
├── src/
│   ├── domain/                 # Domain Layer
│   │   ├── aggregates/
│   │   ├── entities/
│   │   ├── value-objects/
│   │   └── services/
│   ├── use-cases/             # Use Case Layer
│   │   ├── command/
│   │   └── query/
│   ├── infrastructure/        # Infrastructure Layer
│   │   ├── repositories/
│   │   ├── services/
│   │   └── cache/
│   ├── presentation/          # Presentation Layer
│   │   ├── components/
│   │   ├── pages/
│   │   ├── hooks/
│   │   └── providers/
│   └── routes/                # React Router設定
│       └── index.tsx
├── public/                    # 静的ファイル
├── tests/                     # テスト
├── index.html                 # エントリーHTML
├── vite.config.ts            # Vite設定
└── package.json
```

### 5.3. 主要技術スタック

- **Framework:** React 18+
- **Routing:** React Router v6
- **Language:** TypeScript 5+
- **UI:** Tailwind CSS + shadcn/ui
- **State Management:** Zustand or Jotai
- **GraphQL Client:** Apollo Client or urql
- **SSE Client:** EventSource API
- **Validation:** Zod
- **Testing:** Vitest + Playwright
- **Build Tool:** Vite
- **Service Worker:** Workbox

### 5.4. Frontend CQRS Implementation (フロントエンドCQRS実装)

avion-webでは、CQRS（Command Query Responsibility Segregation）パターンをフロントエンドに適用し、GraphQLのMutationとQueryを明確に分離します。これにより、更新系処理（Command）と参照系処理（Query）の責任を分離し、最適化された状態管理とキャッシュ戦略を実現します。

#### 5.4.1. CQRS Pattern Overview

```typescript
// CQRS Commandパターン: 状態変更を伴う処理
interface Command<TInput, TOutput> {
  execute(input: TInput): Promise<TOutput>;
  rollback?(input: TInput): Promise<void>;
}

// CQRS Queryパターン: 状態変更を伴わない参照処理
interface Query<TInput, TOutput> {
  execute(input: TInput): Promise<TOutput>;
  getCacheKey(input: TInput): string;
}

// GraphQL Mutation（Command側）
interface GraphQLCommand<TInput, TOutput> extends Command<TInput, TOutput> {
  mutation: DocumentNode;
  optimisticUpdate?: (input: TInput) => TOutput;
  updateCache?: (cache: ApolloCache<any>, result: TOutput) => void;
}

// GraphQL Query（Query側）
interface GraphQLQuery<TInput, TOutput> extends Query<TInput, TOutput> {
  query: DocumentNode;
  fetchPolicy: WatchQueryFetchPolicy;
  errorPolicy?: ErrorPolicy;
}
```

#### 5.4.2. Command Implementation（更新系実装）

```typescript
// CreateDropCommand実装例
export class CreateDropCommand implements GraphQLCommand<CreateDropInput, DropDTO> {
  constructor(
    private apolloClient: ApolloClient<any>,
    private optimisticService: OptimisticUpdateService
  ) {}

  mutation = gql`
    mutation CreateDrop($input: CreateDropInput!) {
      createDrop(input: $input) {
        id
        content
        author {
          id
          username
          displayName
        }
        createdAt
        reactionsCount
        redropsCount
      }
    }
  `;

  async execute(input: CreateDropInput): Promise<DropDTO> {
    // 1. 楽観的更新の準備
    const optimisticDrop = this.optimisticService.createOptimisticDrop(input);
    
    try {
      // 2. GraphQL Mutation実行（楽観的更新付き）
      const result = await this.apolloClient.mutate({
        mutation: this.mutation,
        variables: { input },
        optimisticResponse: {
          createDrop: optimisticDrop,
        },
        update: (cache, { data }) => {
          if (!data?.createDrop) return;
          
          // 3. キャッシュ更新戦略
          this.updateTimelineCache(cache, data.createDrop);
          this.updateUserProfileCache(cache, data.createDrop);
        },
      });

      return result.data.createDrop;
    } catch (error) {
      // 4. 楽観的更新のロールバック
      await this.rollback(input);
      throw error;
    }
  }

  async rollback(input: CreateDropInput): Promise<void> {
    // 楽観的更新をロールバック
    await this.optimisticService.rollbackOptimisticDrop(input.tempId);
  }

  private updateTimelineCache(cache: ApolloCache<any>, newDrop: DropDTO) {
    // ホームタイムラインキャッシュ更新
    const timelineQuery = gql`
      query GetHomeTimeline($first: Int!, $after: String) {
        homeTimeline(first: $first, after: $after) {
          edges {
            node {
              id
              content
              author { id username displayName }
              createdAt
            }
          }
          pageInfo {
            hasNextPage
            endCursor
          }
        }
      }
    `;

    try {
      const existingData = cache.readQuery({
        query: timelineQuery,
        variables: { first: 20, after: null },
      });

      if (existingData) {
        cache.writeQuery({
          query: timelineQuery,
          variables: { first: 20, after: null },
          data: {
            homeTimeline: {
              ...existingData.homeTimeline,
              edges: [
                { node: newDrop, __typename: 'TimelineEdge' },
                ...existingData.homeTimeline.edges,
              ],
            },
          },
        });
      }
    } catch (error) {
      console.warn('Failed to update timeline cache:', error);
    }
  }
}

// AddReactionCommand実装例
export class AddReactionCommand implements GraphQLCommand<AddReactionInput, ReactionDTO> {
  constructor(private apolloClient: ApolloClient<any>) {}

  mutation = gql`
    mutation AddReaction($input: AddReactionInput!) {
      addReaction(input: $input) {
        id
        emoji
        user {
          id
          username
        }
        drop {
          id
          reactionsCount
          userReaction
        }
      }
    }
  `;

  async execute(input: AddReactionInput): Promise<ReactionDTO> {
    return await this.apolloClient.mutate({
      mutation: this.mutation,
      variables: { input },
      optimisticResponse: {
        addReaction: {
          id: `temp-reaction-${Date.now()}`,
          emoji: input.emoji,
          user: this.getCurrentUser(),
          drop: {
            id: input.dropId,
            reactionsCount: this.getCurrentReactionsCount(input.dropId) + 1,
            userReaction: input.emoji,
            __typename: 'Drop',
          },
          __typename: 'Reaction',
        },
      },
    });
  }
}
```

#### 5.4.3. Query Implementation（参照系実装）

```typescript
// GetTimelineQuery実装例
export class GetTimelineQuery implements GraphQLQuery<GetTimelineInput, TimelineDTO> {
  constructor(
    private apolloClient: ApolloClient<any>,
    private cacheStrategy: CacheStrategyService
  ) {}

  query = gql`
    query GetTimeline($type: TimelineType!, $first: Int!, $after: String) {
      timeline(type: $type, first: $first, after: $after) {
        edges {
          node {
            id
            content
            author {
              id
              username
              displayName
              avatar
            }
            createdAt
            reactionsCount
            redropsCount
            userReaction
            media {
              id
              type
              url
              thumbnail
            }
          }
          cursor
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  `;

  fetchPolicy: WatchQueryFetchPolicy = 'cache-and-network';
  errorPolicy: ErrorPolicy = 'all';

  async execute(input: GetTimelineInput): Promise<TimelineDTO> {
    const { data } = await this.apolloClient.query({
      query: this.query,
      variables: {
        type: input.type,
        first: input.first || 20,
        after: input.after || null,
      },
      fetchPolicy: this.fetchPolicy,
      errorPolicy: this.errorPolicy,
    });

    return data.timeline;
  }

  getCacheKey(input: GetTimelineInput): string {
    return `timeline:${input.type}:${input.first}:${input.after}`;
  }
}

// GetUserProfileQuery実装例
export class GetUserProfileQuery implements GraphQLQuery<GetUserProfileInput, UserProfileDTO> {
  constructor(private apolloClient: ApolloClient<any>) {}

  query = gql`
    query GetUserProfile($userId: ID!) {
      user(id: $userId) {
        id
        username
        displayName
        bio
        avatar
        banner
        followersCount
        followingCount
        dropsCount
        isFollowing
        isBlocked
        isPrivate
        createdAt
      }
    }
  `;

  fetchPolicy: WatchQueryFetchPolicy = 'cache-first';

  async execute(input: GetUserProfileInput): Promise<UserProfileDTO> {
    const { data } = await this.apolloClient.query({
      query: this.query,
      variables: { userId: input.userId },
      fetchPolicy: this.fetchPolicy,
    });

    return data.user;
  }

  getCacheKey(input: GetUserProfileInput): string {
    return `user:${input.userId}`;
  }
}
```

#### 5.4.4. State Management with CQRS（状態管理とCQRS）

```typescript
// CQRS-based State Management with Zustand
interface CQRSState {
  // Command State（更新系状態）
  pendingCommands: Set<string>;
  optimisticUpdates: Map<string, any>;
  commandHistory: CommandHistoryEntry[];
  
  // Query State（参照系状態）
  queryCache: Map<string, CachedQuery>;
  querySubscriptions: Map<string, QuerySubscription>;
  
  // Command Actions
  executeCommand: <T>(command: Command<any, T>, input: any) => Promise<T>;
  rollbackCommand: (commandId: string) => Promise<void>;
  
  // Query Actions
  executeQuery: <T>(query: Query<any, T>, input: any) => Promise<T>;
  invalidateQuery: (cacheKey: string) => void;
  subscribeToQuery: (cacheKey: string, callback: (data: any) => void) => void;
}

export const useCQRSStore = create<CQRSState>()(
  devtools(
    immer((set, get) => ({
      pendingCommands: new Set(),
      optimisticUpdates: new Map(),
      commandHistory: [],
      queryCache: new Map(),
      querySubscriptions: new Map(),

      executeCommand: async (command, input) => {
        const commandId = `cmd-${Date.now()}-${Math.random()}`;
        
        set(state => {
          state.pendingCommands.add(commandId);
          state.commandHistory.push({
            id: commandId,
            command: command.constructor.name,
            input,
            timestamp: new Date(),
            status: 'pending',
          });
        });

        try {
          const result = await command.execute(input);
          
          set(state => {
            state.pendingCommands.delete(commandId);
            const historyEntry = state.commandHistory.find(h => h.id === commandId);
            if (historyEntry) {
              historyEntry.status = 'success';
              historyEntry.result = result;
            }
          });

          return result;
        } catch (error) {
          set(state => {
            state.pendingCommands.delete(commandId);
            const historyEntry = state.commandHistory.find(h => h.id === commandId);
            if (historyEntry) {
              historyEntry.status = 'failed';
              historyEntry.error = error;
            }
          });

          throw error;
        }
      },

      rollbackCommand: async (commandId) => {
        const historyEntry = get().commandHistory.find(h => h.id === commandId);
        if (!historyEntry || !historyEntry.command.rollback) {
          throw new Error('Cannot rollback command');
        }

        try {
          await historyEntry.command.rollback(historyEntry.input);
          
          set(state => {
            historyEntry.status = 'rolled-back';
          });
        } catch (error) {
          set(state => {
            historyEntry.status = 'rollback-failed';
            historyEntry.rollbackError = error;
          });
          throw error;
        }
      },

      executeQuery: async (query, input) => {
        const cacheKey = query.getCacheKey(input);
        const cachedQuery = get().queryCache.get(cacheKey);

        // キャッシュヒット判定
        if (cachedQuery && !cachedQuery.isExpired()) {
          return cachedQuery.data;
        }

        try {
          const result = await query.execute(input);
          
          set(state => {
            state.queryCache.set(cacheKey, {
              data: result,
              timestamp: new Date(),
              ttl: 5 * 60 * 1000, // 5分
              isExpired: function() {
                return Date.now() - this.timestamp.getTime() > this.ttl;
              },
            });
          });

          // サブスクライバーに通知
          const subscription = get().querySubscriptions.get(cacheKey);
          if (subscription) {
            subscription.callbacks.forEach(callback => callback(result));
          }

          return result;
        } catch (error) {
          console.error(`Query ${cacheKey} failed:`, error);
          throw error;
        }
      },

      invalidateQuery: (cacheKey) => {
        set(state => {
          state.queryCache.delete(cacheKey);
        });
      },

      subscribeToQuery: (cacheKey, callback) => {
        set(state => {
          const existing = state.querySubscriptions.get(cacheKey);
          if (existing) {
            existing.callbacks.add(callback);
          } else {
            state.querySubscriptions.set(cacheKey, {
              callbacks: new Set([callback]),
            });
          }
        });
      },
    }))
  )
);
```

#### 5.4.5. React Hooks for CQRS（CQRSのためのReactフック）

```typescript
// Command Hook
export function useCommand<TInput, TOutput>(
  CommandClass: new (...args: any[]) => GraphQLCommand<TInput, TOutput>
) {
  const apolloClient = useApolloClient();
  const optimisticService = useOptimisticService();
  const cqrsStore = useCQRSStore();
  
  const command = useMemo(
    () => new CommandClass(apolloClient, optimisticService),
    [CommandClass, apolloClient, optimisticService]
  );

  const execute = useCallback(
    async (input: TInput): Promise<TOutput> => {
      return await cqrsStore.executeCommand(command, input);
    },
    [command, cqrsStore]
  );

  const isPending = cqrsStore.pendingCommands.has(command.constructor.name);

  return [execute, { isPending }] as const;
}

// Query Hook
export function useQuery<TInput, TOutput>(
  QueryClass: new (...args: any[]) => GraphQLQuery<TInput, TOutput>,
  input: TInput,
  options: {
    enabled?: boolean;
    refetchOnWindowFocus?: boolean;
    staleTime?: number;
  } = {}
) {
  const apolloClient = useApolloClient();
  const cacheStrategy = useCacheStrategy();
  const cqrsStore = useCQRSStore();
  
  const query = useMemo(
    () => new QueryClass(apolloClient, cacheStrategy),
    [QueryClass, apolloClient, cacheStrategy]
  );

  const [data, setData] = useState<TOutput | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const execute = useCallback(async () => {
    if (!options.enabled) return;

    try {
      setLoading(true);
      setError(null);
      const result = await cqrsStore.executeQuery(query, input);
      setData(result);
    } catch (err) {
      setError(err as Error);
    } finally {
      setLoading(false);
    }
  }, [query, input, cqrsStore, options.enabled]);

  // 初回実行とinputの変更時に再実行
  useEffect(() => {
    execute();
  }, [execute]);

  // クエリキャッシュの監視
  useEffect(() => {
    const cacheKey = query.getCacheKey(input);
    const unsubscribe = cqrsStore.subscribeToQuery(cacheKey, (newData) => {
      setData(newData);
    });

    return () => unsubscribe?.();
  }, [query, input, cqrsStore]);

  const refetch = useCallback(() => {
    const cacheKey = query.getCacheKey(input);
    cqrsStore.invalidateQuery(cacheKey);
    return execute();
  }, [query, input, cqrsStore, execute]);

  return {
    data,
    loading,
    error,
    refetch,
  };
}

// Example Usage in Components
export const CreateDropForm: React.FC = () => {
  const [createDrop, { isPending }] = useCommand(CreateDropCommand);
  const [content, setContent] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    try {
      await createDrop({
        content,
        tempId: `temp-${Date.now()}`, // 楽観的更新用の一時ID
      });
      
      setContent(''); // フォームリセット
    } catch (error) {
      console.error('Failed to create drop:', error);
      // エラーハンドリング
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <textarea
        value={content}
        onChange={(e) => setContent(e.target.value)}
        placeholder="What's happening?"
        disabled={isPending}
      />
      <button type="submit" disabled={isPending || !content.trim()}>
        {isPending ? 'Posting...' : 'Post'}
      </button>
    </form>
  );
};

export const TimelinePage: React.FC = () => {
  const { data: timeline, loading, error, refetch } = useQuery(
    GetTimelineQuery,
    { type: 'home', first: 20 },
    { enabled: true, refetchOnWindowFocus: true }
  );

  if (loading) return <TimelineSkeleton />;
  if (error) return <ErrorMessage error={error} onRetry={refetch} />;
  if (!timeline) return <EmptyTimeline />;

  return (
    <div>
      {timeline.edges.map(({ node: drop }) => (
        <DropCard key={drop.id} drop={drop} />
      ))}
    </div>
  );
};
```

#### 5.4.6. Optimistic Updates（楽観的更新）

```typescript
export class OptimisticUpdateService {
  private optimisticUpdates = new Map<string, OptimisticUpdate>();
  
  createOptimisticDrop(input: CreateDropInput): DropDTO {
    const optimisticDrop: DropDTO = {
      id: input.tempId,
      content: input.content,
      author: this.getCurrentUser(),
      createdAt: new Date().toISOString(),
      reactionsCount: 0,
      redropsCount: 0,
      userReaction: null,
      media: input.media || [],
      isOptimistic: true, // 楽観的更新フラグ
    };

    this.optimisticUpdates.set(input.tempId, {
      type: 'create-drop',
      data: optimisticDrop,
      timestamp: Date.now(),
    });

    return optimisticDrop;
  }

  async rollbackOptimisticDrop(tempId: string): Promise<void> {
    const update = this.optimisticUpdates.get(tempId);
    if (!update) return;

    // Apollo Cacheから楽観的更新を削除
    const apolloClient = getApolloClient();
    const cache = apolloClient.cache;

    // タイムラインキャッシュから削除
    try {
      const timelineData = cache.readQuery({
        query: GET_HOME_TIMELINE_QUERY,
        variables: { first: 20, after: null },
      });

      if (timelineData) {
        cache.writeQuery({
          query: GET_HOME_TIMELINE_QUERY,
          variables: { first: 20, after: null },
          data: {
            homeTimeline: {
              ...timelineData.homeTimeline,
              edges: timelineData.homeTimeline.edges.filter(
                edge => edge.node.id !== tempId
              ),
            },
          },
        });
      }
    } catch (error) {
      console.warn('Failed to rollback optimistic update:', error);
    }

    this.optimisticUpdates.delete(tempId);
  }
}
```

#### 5.4.7. Cache Invalidation Strategy（キャッシュ無効化戦略）

```typescript
export class CacheInvalidationService {
  constructor(private apolloClient: ApolloClient<any>) {}

  // Drop作成時のキャッシュ無効化
  invalidateAfterDropCreation(newDrop: DropDTO) {
    // 1. 関連するタイムラインを無効化
    this.apolloClient.cache.evict({
      fieldName: 'homeTimeline',
    });
    
    // 2. ユーザーのDrop数を更新
    this.apolloClient.cache.modify({
      id: this.apolloClient.cache.identify({
        __typename: 'User',
        id: newDrop.author.id,
      }),
      fields: {
        dropsCount: (existing) => existing + 1,
      },
    });

    // 3. 関連クエリの再取得をトリガー
    this.apolloClient.refetchQueries({
      include: ['GetHomeTimeline', 'GetUserProfile'],
    });
  }

  // リアクション追加時のキャッシュ無効化
  invalidateAfterReactionAdd(reaction: ReactionDTO) {
    this.apolloClient.cache.modify({
      id: this.apolloClient.cache.identify({
        __typename: 'Drop',
        id: reaction.drop.id,
      }),
      fields: {
        reactionsCount: (existing) => existing + 1,
        userReaction: () => reaction.emoji,
      },
    });
  }
}
```

このCQRS実装により、フロントエンドでは以下の利点が得られます：

1. **明確な責任分離**: 更新系（Command）と参照系（Query）の処理が明確に分離される
2. **最適化されたキャッシュ戦略**: 参照系は積極的にキャッシュ、更新系は即座に反映
3. **楽観的更新**: ユーザー体験の向上とレスポンシブな操作感
4. **エラーハンドリング**: Command失敗時の自動ロールバック機能
5. **テスタビリティ**: Command/Queryが独立してテスト可能

### 5.5. Domain Service インターフェース詳細

```typescript
// EventFilterService
export interface EventFilterService {
  shouldDeliverToUser(event: SSEEvent, userID: string): boolean;
  applyPrivacyRules(event: SSEEvent, viewer: User): SSEEvent | null;
  filterBySubscription(events: SSEEvent[], filters: EventFilter[]): SSEEvent[];
  prioritizeEvents(events: SSEEvent[]): SSEEvent[];
  checkEventRelevance(event: SSEEvent, context: UserContext): boolean;
  createEventFilter(criteria: FilterCriteria): EventFilter;
}

// DataAggregationService
export interface DataAggregationService {
  aggregateTimelineData(sources: TimelineSource[]): TimelineDTO;
  mergeUserProfiles(profiles: UserProfile[]): UserProfileDTO;
  combineNotifications(notifications: Notification[]): NotificationDTO[];
  deduplicateData(items: any[]): any[];
  enrichWithMetadata(data: any, metadata: Metadata): any;
  resolveReferences(data: any, references: Map<string, any>): any;
}

// ValidationService
export interface ValidationService {
  validateDropContent(content: string): ValidationResult;
  sanitizeHTML(html: string): string;
  checkContentPolicy(content: string): PolicyCheckResult;
  validateMediaFiles(files: File[]): ValidationResult[];
  validateUsername(username: string): ValidationResult;
  validateEmail(email: string): ValidationResult;
  validateFormData(data: FormData, schema: ValidationSchema): ValidationResult;
  validateGraphQLQuery(query: string): ValidationResult;
}

// CacheStrategyService
export interface CacheStrategyService {
  determineCacheability(query: GraphQLQuery): CacheDecision;
  calculateTTL(dataType: string): number;
  invalidateRelated(key: string): Promise<void>;
  warmupCache(predictions: CachePrediction[]): Promise<void>;
  getCacheKey(operation: string, variables: any): string;
  shouldBypassCache(context: RequestContext): boolean;
  updateCacheMetrics(hit: boolean, key: string): void;
}

// OptimisticUpdateService
export interface OptimisticUpdateService {
  applyOptimisticUpdate(action: OptimisticAction): OptimisticResult;
  confirmUpdate(id: string, result: any): void;
  rollbackUpdate(id: string, error: Error): void;
  reconcileState(local: any, remote: any): any;
  queueOptimisticAction(action: OptimisticAction): void;
  getPendingUpdates(): OptimisticAction[];
  clearPendingUpdates(): void;
}
```

### 5.5. Repository インターフェース詳細

```typescript
// ViewStateRepository (ViewState Aggregate専用)
export interface ViewStateRepository {
  save(viewState: ViewState): Promise<void>;
  findByUserId(userId: string): Promise<ViewState | null>;
  update(viewState: ViewState): Promise<void>;
  delete(userId: string): Promise<void>;
}
// Mock Factory: tests/mocks/domain/repository/mock_view_state_repository.ts
export const createMockViewStateRepository = (): ViewStateRepository => ({
  save: vi.fn().mockResolvedValue(undefined),
  findByUserId: vi.fn().mockResolvedValue(null),
  update: vi.fn().mockResolvedValue(undefined),
  delete: vi.fn().mockResolvedValue(undefined),
});

// UserSessionRepository (UserSession Aggregate専用)
export interface UserSessionRepository {
  save(session: UserSession): Promise<void>;
  findBySessionId(sessionId: string): Promise<UserSession | null>;
  update(session: UserSession): Promise<void>;
  delete(sessionId: string): Promise<void>;
}
// Mock Factory: tests/mocks/domain/repository/mock_user_session_repository.ts
export const createMockUserSessionRepository = (): UserSessionRepository => ({
  save: vi.fn().mockResolvedValue(undefined),
  findBySessionId: vi.fn().mockResolvedValue(null),
  update: vi.fn().mockResolvedValue(undefined),
  delete: vi.fn().mockResolvedValue(undefined),
});

// SSEClientRepository (SSEClient Aggregate専用)
export interface SSEClientRepository {
  save(client: SSEClient): Promise<void>;
  findByConnectionId(connectionId: string): Promise<SSEClient | null>;
  update(client: SSEClient): Promise<void>;
  delete(connectionId: string): Promise<void>;
}

// OAuthConsentRepository (OAuthConsent Aggregate専用)
export interface OAuthConsentRepository {
  save(consent: OAuthConsent): Promise<void>;
  findBySessionId(sessionId: string): Promise<OAuthConsent | null>;
  update(consent: OAuthConsent): Promise<void>;
  delete(sessionId: string): Promise<void>;
}
```

### 5.6. Query Service インターフェース詳細

```typescript
// TimelineQueryService (参照系UseCaseからのみ呼び出し)
export interface TimelineQueryService {
  getHomeTimelineDTO(userId: string, cursor?: string): Promise<TimelineDTO>;
  getGlobalTimelineDTO(cursor?: string): Promise<TimelineDTO>;
  getLocalTimelineDTO(instanceId: string, cursor?: string): Promise<TimelineDTO>;
}
// Mock Factory: tests/mocks/usecase/query/mock_timeline_query_service.ts
export const createMockTimelineQueryService = (): TimelineQueryService => ({
  getHomeTimelineDTO: vi.fn().mockResolvedValue(mockTimelineDTO),
  getGlobalTimelineDTO: vi.fn().mockResolvedValue(mockTimelineDTO),
  getLocalTimelineDTO: vi.fn().mockResolvedValue(mockTimelineDTO),
});

// UserQueryService (参照系UseCaseからのみ呼び出し)
export interface UserQueryService {
  getUserDTO(userId: string): Promise<UserProfileDTO | null>;
  getUserByUsernameDTO(username: string): Promise<UserProfileDTO | null>;
  getFollowersDTO(userId: string, cursor?: string): Promise<UserPageDTO>;
  getFollowingDTO(userId: string, cursor?: string): Promise<UserPageDTO>;
}

// NotificationQueryService (参照系UseCaseからのみ呼び出し)
export interface NotificationQueryService {
  getNotificationsDTO(userId: string, cursor?: string): Promise<NotificationPageDTO>;
  getUnreadCountDTO(userId: string): Promise<number>;
}

// SearchQueryService (参照系UseCaseからのみ呼び出し)
export interface SearchQueryService {
  searchDropsDTO(query: string, options?: SearchOptions): Promise<SearchResultDTO>;
  searchUsersDTO(query: string, options?: SearchOptions): Promise<SearchResultDTO>;
}

// AuthQueryService (参照系UseCaseからのみ呼び出し) 
export interface AuthQueryService {
  getCurrentSessionDTO(): Promise<SessionDTO | null>;
  getStoredTokenDTO(): Promise<TokenDTO | null>;
}

// PreferenceQueryService (参照系UseCaseからのみ呼び出し)
export interface PreferenceQueryService {
  getPreferencesDTO(userId: string): Promise<PreferencesDTO>;
  getThemeDTO(): Promise<ThemeDTO>;
}
```

### 5.7. External Service インターフェース詳細

```typescript
// GatewayGraphQLExternal (外部API: Gateway GraphQLエンドポイント)
export interface GatewayGraphQLExternal {
  query<T>(query: string, variables?: any): Promise<T>;
  mutate<T>(mutation: string, variables?: any): Promise<T>;
  subscribe<T>(subscription: string, variables?: any): AsyncIterator<T>;
}
// Mock Factory: tests/mocks/usecase/external/mock_gateway_graphql_external.ts
export const createMockGatewayGraphQLExternal = (): GatewayGraphQLExternal => ({
  query: vi.fn().mockResolvedValue({}),
  mutate: vi.fn().mockResolvedValue({}),
  subscribe: vi.fn().mockReturnValue(mockAsyncIterator),
});

// GatewaySSEExternal (外部API: Gateway SSEエンドポイント)
export interface GatewaySSEExternal {
  connect(endpoint: string, token: string): EventSource;
  disconnect(eventSource: EventSource): void;
  addEventListener(eventSource: EventSource, event: string, handler: EventHandler): void;
  removeEventListener(eventSource: EventSource, event: string, handler: EventHandler): void;
}

// MediaUploadExternal (外部API: メディアアップロード)
export interface MediaUploadExternal {
  upload(file: File, options?: UploadOptions): Promise<MediaUploadResponse>;
  uploadMultiple(files: File[], options?: UploadOptions): Promise<MediaUploadResponse[]>;
  getUploadUrl(type: string): Promise<string>;
}

// WebPushExternal (外部API: Web Push通知)
export interface WebPushExternal {
  requestPermission(): Promise<NotificationPermission>;
  subscribe(options: PushSubscriptionOptions): Promise<PushSubscription>;
  unsubscribe(subscription: PushSubscription): Promise<void>;
}

// ServiceWorkerExternal (外部API: Service Worker)
export interface ServiceWorkerExternal {
  register(scriptUrl: string): Promise<ServiceWorkerRegistration>;
  unregister(registration: ServiceWorkerRegistration): Promise<boolean>;
  postMessage(message: any): void;
  addEventListener(event: string, handler: EventHandler): void;
}
```

### 5.7. エラーハンドリング戦略

> **注意:** エラーコードは[共通エラーコード標準](../common/errors/error-codes.md)に準拠します。このサービスではプレフィックス `WEB` を使用します。

### エラーコード体系

本サービスは、Avionプラットフォーム標準のエラーコード体系に準拠します。

- **命名規則**: `[SERVICE]_[LAYER]_[ERROR_TYPE]`形式
- **エラーカタログ**: [error-catalog.md](./error-catalog.md)
- **実装ガイド**: [共通エラー実装ガイド](../common/errors/implementation-guide.md)
- **標準仕様**: [エラーコード標準化ガイドライン](../common/errors/error-standards.md)

詳細なエラーコード定義とマッピングについては、上記のドキュメントを参照してください。

**ドメインエラー定義:**
```typescript
// 認証・セッション関連エラー
export class InvalidTokenError extends Error {
  constructor(message: string = 'Token is invalid') {
    super(message);
    this.name = 'InvalidTokenError';
  }
}
export class TokenExpiredError extends Error {
  constructor(expiredAt: Date) {
    super(`Token expired at ${expiredAt.toISOString()}`);
    this.name = 'TokenExpiredError';
  }
}
export class SessionNotFoundError extends Error {}
export class UnauthorizedError extends Error {}
export class InsufficientPermissionsError extends Error {}

// GraphQL関連エラー
export class InvalidQueryError extends Error {
  constructor(public query: string, public reason: string) {
    super(`Invalid GraphQL query: ${reason}`);
    this.name = 'InvalidQueryError';
  }
}
export class QueryComplexityError extends Error {
  constructor(public complexity: number, public limit: number) {
    super(`Query complexity ${complexity} exceeds limit ${limit}`);
    this.name = 'QueryComplexityError';
  }
}
export class QueryDepthError extends Error {}

// SSE/リアルタイム関連エラー
export class InvalidEventError extends Error {}
export class ConnectionClosedError extends Error {}
export class ConnectionLimitExceededError extends Error {}
export class EventBufferOverflowError extends Error {}

// バリデーション関連エラー
export class ValidationError extends Error {
  constructor(
    public field: string,
    public reason: string,
    public code?: string
  ) {
    super(`Validation failed for ${field}: ${reason}`);
    this.name = 'ValidationError';
  }
}
export class ContentPolicyViolationError extends Error {}
export class MediaValidationError extends Error {}

// ビジネスロジックエラー
export class OptimisticUpdateConflictError extends Error {}
export class ConcurrentModificationError extends Error {}
export class ResourceNotFoundError extends Error {}
export class RateLimitExceededError extends Error {}
```

**各層でのエラーハンドリング:**

**Domain層**:
- ビジネスルール違反時にドメインエラーをthrow
- 不変条件違反時に適切なエラーをthrow
- エラーは回復可能性を考慮して設計

**Use Case層**:
- ドメインエラーをキャッチし、適切なDTOエラーに変換
- 複数のエラーを集約してレスポンス
- リトライ可能なエラーは自動リトライ

**Infrastructure層**:
- 外部サービスエラーをドメインエラーに変換
- ネットワークエラーの適切なラッピング
- タイムアウトとサーキットブレーカーの実装

**Handler層**:
- エラーを適切なHTTPステータスコードに変換
- GraphQLエラーフォーマットへの変換
- クライアント向けエラーメッセージの生成
- React Error Boundaryによるクライアントサイドエラーの捕捉

### 5.7.1. React Error Boundary実装

フロントエンドでは、React Error Boundaryを使用して予期しないエラーを捕捉し、ユーザーに適切なフィードバックを提供します。

**Error Boundary基底クラス:**
```typescript
import React, { Component, ErrorInfo, ReactNode } from 'react';

interface ErrorBoundaryState {
  hasError: boolean;
  error: Error | null;
  errorInfo: ErrorInfo | null;
  errorId: string | null;
}

interface ErrorBoundaryProps {
  children: ReactNode;
  fallback?: React.ComponentType<ErrorFallbackProps>;
  onError?: (error: Error, errorInfo: ErrorInfo, errorId: string) => void;
  isolate?: boolean; // trueの場合、エラーを上位に伝播させない
  resetKeys?: Array<string | number>; // これらのキーが変更されたらエラー状態をリセット
  resetOnPropsChange?: boolean;
  enableErrorReporting?: boolean; // エラーレポーティングを有効にするか
}

export interface ErrorFallbackProps {
  error: Error;
  errorInfo: ErrorInfo | null;
  resetError: () => void;
  errorId: string;
}

export class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  private resetTimeoutId: number | null = null;
  private errorCounter = 0;

  constructor(props: ErrorBoundaryProps) {
    super(props);
    this.state = {
      hasError: false,
      error: null,
      errorInfo: null,
      errorId: null,
    };
  }

  static getDerivedStateFromError(error: Error): Partial<ErrorBoundaryState> {
    const errorId = `error-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    return {
      hasError: true,
      error,
      errorId,
    };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    const { onError, enableErrorReporting } = this.props;
    const { errorId } = this.state;

    // エラーカウンターを増やす（無限ループ検出用）
    this.errorCounter++;
    if (this.errorCounter > 3) {
      console.error('Error Boundary: Too many errors, stopping error reporting');
      return;
    }

    // カスタムエラーハンドラーを呼び出し
    if (onError && errorId) {
      onError(error, errorInfo, errorId);
    }

    // エラーレポーティング（オプトイン）
    if (enableErrorReporting && errorId) {
      this.reportError(error, errorInfo, errorId);
    }

    // エラー情報を状態に保存
    this.setState({ errorInfo });

    // 5秒後にエラーカウンターをリセット
    if (this.resetTimeoutId) {
      clearTimeout(this.resetTimeoutId);
    }
    this.resetTimeoutId = window.setTimeout(() => {
      this.errorCounter = 0;
    }, 5000);
  }

  componentDidUpdate(prevProps: ErrorBoundaryProps) {
    const { resetKeys, resetOnPropsChange } = this.props;
    const { hasError } = this.state;
    
    // resetKeysが変更されたらエラー状態をリセット
    if (hasError && prevProps.resetKeys !== resetKeys) {
      if (resetKeys?.some((key, idx) => key !== prevProps.resetKeys?.[idx])) {
        this.resetError();
      }
    }
    
    // props変更時のリセット
    if (hasError && resetOnPropsChange && prevProps.children !== this.props.children) {
      this.resetError();
    }
  }

  componentWillUnmount() {
    if (this.resetTimeoutId) {
      clearTimeout(this.resetTimeoutId);
    }
  }

  private reportError = async (error: Error, errorInfo: ErrorInfo, errorId: string) => {
    try {
      // エラーレポーティングサービスへの送信（設定されている場合）
      const errorReporter = await this.getErrorReporter();
      if (errorReporter) {
        await errorReporter.report({
          error,
          errorInfo,
          errorId,
          url: window.location.href,
          userAgent: navigator.userAgent,
          timestamp: new Date().toISOString(),
          componentStack: errorInfo.componentStack,
        });
      }
    } catch (reportingError) {
      // レポーティング自体のエラーは握りつぶす（ユーザー体験を損なわないため）
      console.error('Failed to report error:', reportingError);
    }
  };

  private getErrorReporter = async (): Promise<ErrorReporter | null> => {
    // 環境変数でエラーレポーティングが有効化されているかチェック
    if (!process.env.NEXT_PUBLIC_ERROR_REPORTING_ENABLED) {
      return null;
    }

    // 動的インポートでエラーレポーターを取得（オプトイン）
    try {
      const { ErrorReporter } = await import('@/lib/error-reporter');
      return ErrorReporter.getInstance();
    } catch {
      return null;
    }
  };

  resetError = () => {
    this.errorCounter = 0;
    this.setState({
      hasError: false,
      error: null,
      errorInfo: null,
      errorId: null,
    });
  };

  render() {
    const { hasError, error, errorInfo, errorId } = this.state;
    const { children, fallback: Fallback = DefaultErrorFallback, isolate } = this.props;

    if (hasError && error && errorId) {
      // isolateがfalseの場合、エラーを上位に再スロー
      if (!isolate && this.errorCounter > 2) {
        throw error;
      }

      return (
        <Fallback
          error={error}
          errorInfo={errorInfo}
          resetError={this.resetError}
          errorId={errorId}
        />
      );
    }

    return children;
  }
}

// デフォルトのエラーフォールバックコンポーネント
const DefaultErrorFallback: React.FC<ErrorFallbackProps> = ({
  error,
  resetError,
  errorId,
}) => (
  <div className="error-boundary-fallback">
    <h2>エラーが発生しました</h2>
    <details style={{ whiteSpace: 'pre-wrap' }}>
      <summary>詳細情報</summary>
      <p>エラーID: {errorId}</p>
      <p>{error?.toString()}</p>
    </details>
    <button onClick={resetError}>再試行</button>
  </div>
);
```

**エラーレポーター実装（オプトイン）:**
```typescript
// lib/error-reporter.ts
interface ErrorReport {
  error: Error;
  errorInfo: ErrorInfo;
  errorId: string;
  url: string;
  userAgent: string;
  timestamp: string;
  componentStack: string;
}

export interface ErrorReporter {
  report(errorReport: ErrorReport): Promise<void>;
}

// Sentryを使用する場合の実装例（オプトイン）
class SentryErrorReporter implements ErrorReporter {
  private initialized = false;

  async initialize() {
    if (this.initialized) return;
    
    const dsn = process.env.NEXT_PUBLIC_SENTRY_DSN;
    if (!dsn) {
      console.log('Sentry DSN not configured, error reporting disabled');
      return;
    }

    try {
      const Sentry = await import('@sentry/nextjs');
      Sentry.init({
        dsn,
        environment: process.env.NODE_ENV,
        beforeSend(event) {
          // プライバシー保護: 個人情報を除去
          if (event.request) {
            delete event.request.cookies;
            delete event.request.headers;
          }
          return event;
        },
      });
      this.initialized = true;
    } catch (error) {
      console.error('Failed to initialize Sentry:', error);
    }
  }

  async report(errorReport: ErrorReport): Promise<void> {
    await this.initialize();
    if (!this.initialized) return;

    const Sentry = await import('@sentry/nextjs');
    Sentry.withScope((scope) => {
      scope.setTag('errorBoundary', true);
      scope.setContext('errorInfo', {
        errorId: errorReport.errorId,
        componentStack: errorReport.componentStack,
        url: errorReport.url,
      });
      Sentry.captureException(errorReport.error);
    });
  }
}

// カスタムレポーター実装例（内部ログ収集）
class InternalErrorReporter implements ErrorReporter {
  async report(errorReport: ErrorReport): Promise<void> {
    try {
      await fetch('/api/errors', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          errorId: errorReport.errorId,
          message: errorReport.error.message,
          stack: errorReport.error.stack,
          componentStack: errorReport.componentStack,
          url: errorReport.url,
          timestamp: errorReport.timestamp,
        }),
      });
    } catch (error) {
      console.error('Failed to report error internally:', error);
    }
  }
}

// エラーレポーターのファクトリー
export class ErrorReporter {
  private static instance: ErrorReporter | null = null;

  static getInstance(): ErrorReporter {
    if (!this.instance) {
      // 環境変数で選択可能
      const reporterType = process.env.NEXT_PUBLIC_ERROR_REPORTER_TYPE || 'internal';
      
      switch (reporterType) {
        case 'sentry':
          this.instance = new SentryErrorReporter();
          break;
        case 'internal':
        default:
          this.instance = new InternalErrorReporter();
          break;
      }
    }
    return this.instance;
  }
}
```

**階層的Error Boundary構成:**
```typescript
// app/layout.tsx
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <body>
        {/* アプリケーション全体のError Boundary */}
        <ErrorBoundary
          fallback={GlobalErrorFallback}
          enableErrorReporting={process.env.NEXT_PUBLIC_ERROR_REPORTING_ENABLED === 'true'}
          onError={(error, errorInfo, errorId) => {
            console.error(`Global error caught: ${errorId}`, error);
          }}
        >
          {/* 認証エラー専用のError Boundary */}
          <ErrorBoundary
            fallback={AuthErrorFallback}
            isolate={true}
            resetOnPropsChange={true}
          >
            <AuthProvider>
              {/* ページレベルのError Boundary */}
              <ErrorBoundary
                fallback={PageErrorFallback}
                isolate={true}
              >
                {children}
              </ErrorBoundary>
            </AuthProvider>
          </ErrorBoundary>
        </ErrorBoundary>
      </body>
    </html>
  );
}
```

**特殊なエラーフォールバック:**
```typescript
// 認証エラー用フォールバック
const AuthErrorFallback: React.FC<ErrorFallbackProps> = ({ error, resetError }) => {
  const router = useRouter();
  
  if (error.name === 'UnauthorizedError' || error.name === 'TokenExpiredError') {
    return (
      <div className="auth-error-fallback">
        <h2>認証エラー</h2>
        <p>セッションの有効期限が切れました。再度ログインしてください。</p>
        <button onClick={() => router.push('/login')}>ログインページへ</button>
      </div>
    );
  }
  
  return <DefaultErrorFallback error={error} errorInfo={null} resetError={resetError} errorId="" />;
};

// GraphQLエラー用フォールバック
const GraphQLErrorFallback: React.FC<ErrorFallbackProps> = ({ error, resetError }) => {
  if (error.name === 'NetworkError') {
    return (
      <div className="network-error-fallback">
        <h2>ネットワークエラー</h2>
        <p>サーバーとの通信に失敗しました。</p>
        <button onClick={resetError}>再試行</button>
      </div>
    );
  }
  
  return <DefaultErrorFallback error={error} errorInfo={null} resetError={resetError} errorId="" />;
};
```

**非同期エラーの捕捉:**
```typescript
// hooks/useAsyncError.ts
export const useAsyncError = () => {
  const [, setError] = useState();
  
  return useCallback(
    (error: Error) => {
      setError(() => {
        throw error;
      });
    },
    [setError]
  );
};

// 使用例
const MyComponent = () => {
  const throwError = useAsyncError();
  
  const handleAsyncOperation = async () => {
    try {
      await someAsyncOperation();
    } catch (error) {
      // Error Boundaryで捕捉される
      throwError(error as Error);
    }
  };
};
```

**エラーマッピング例:**
```typescript
// Use Case層でのエラー変換
catch (error) {
  if (error instanceof TokenExpiredError) {
    return { success: false, errorCode: 'AUTH_TOKEN_EXPIRED', grpcCode: codes.Unauthenticated };
  }
  if (error instanceof ValidationError) {
    return { success: false, errorCode: 'VALIDATION_ERROR', field: error.field, grpcCode: codes.InvalidArgument };
  }
  if (error instanceof ResourceNotFoundError) {
    return { success: false, errorCode: 'NOT_FOUND', grpcCode: codes.NotFound };
  }
  // 予期しないエラー
  logger.error({ error, message: 'Unexpected error in use case' });
  return { success: false, errorCode: 'INTERNAL_ERROR', grpcCode: codes.Internal };
}
```

## データベースマイグレーション

このサービスでは、[共通マイグレーション戦略](../common/database-migration-strategy.md)に従って、Gooseを使用したマイグレーション管理を行います。

### マイグレーション戦略

- **ツール**: Goose v3
- **ディレクトリ**: `./migrations/`
- **命名規則**: `[sequence_number]_[description].sql`
- **実行方法**: `make migrate-up` / `make migrate-down`

### avion-web固有の考慮事項

- **セッション状態保持**: ユーザーのフロントエンド状態（ログイン状態、設定など）を適切に保持
- **PWAデータ整合性**: Service WorkerやIndexedDBに保存されたオフラインデータとの整合性
- **OAuth設定継承**: 外部アプリ連携のクライアント設定を正確に移行
- **最小限データベース利用**: 主にクライアントサイドアプリのため、データベース依存は最小限
- **CDNキャッシュ更新**: 静的アセット更新時のCDNキャッシュ戦略との連携

### 標準テンプレート参照

マイグレーションファイル作成時は[マイグレーション設定テンプレート](../templates/migration-setup-template.md)を参照してください。

## 6. Use Cases / Key Flows (主な使い方・処理の流れ)

### フロー 1: 初回アクセスとログイン
1. User → CDN: 静的アセット（HTML/JS/CSS）配信
2. Client: React アプリケーション起動
3. Client: CSRでLoginページ表示
4. User: 認証情報入力
5. LoginCommandUseCase: FormStateから入力取得
6. Client → Gateway (GraphQL): 認証Mutation実行
7. Gateway → IAM Service: 認証処理
8. UserSessionAggregate: AuthToken保存（LocalStorage）
9. ViewStateAggregate: ホーム画面へ遷移

### フロー 2: タイムライン取得（GraphQL Query）
1. GetTimelineQueryUseCase: GraphQLQuery生成
2. Client → Gateway `/graphql`: Query送信（Authorizationヘッダー付き）
3. Gateway: JWT検証、DataLoader初期化
4. Gateway → Backend Services: 並列データ取得
   - Timeline Service: タイムラインデータ
   - Drop Service: Drop詳細（バッチ）
   - User Service: ユーザー情報（バッチ）
5. Gateway: データ集約・変換
6. Client: Apollo Cacheに保存
7. ViewStateAggregate: UI更新

### フロー 3: Drop作成（GraphQL Mutation）
1. CreateDropCommandUseCase: FormStateから入力取得
2. OptimisticUpdateService: 楽観的更新準備
3. Client → Gateway `/graphql`: Mutation送信
4. Client: 楽観的更新でViewState即座に反映
5. Gateway → Drop Service: Drop作成
6. Gateway: 作成結果を返却
7. OptimisticUpdateService: 実データで確定更新
8. Gateway: SSE経由で他ユーザーへイベント配信

### フロー 4: SSEリアルタイム更新
1. EstablishSSEConnectionCommandUseCase: 接続確立
2. Client → Gateway `/sse/timeline`: EventSource接続（JWT付き）
3. Gateway: JWT検証、ユーザー別チャンネル購読
4. Backend Service → Redis → Gateway: イベント受信
5. Gateway: ユーザー関連イベントフィルタリング
6. Gateway → Client: SSEでイベント送信
7. EventProcessingService: イベント処理
8. ViewStateAggregate: UI自動更新

### フロー 5: PWAインストールとWeb Push
1. Service Worker: 登録・有効化
2. SubscribeToPushUseCase: 通知許可要求
3. Client → Push Service: 購読
4. RegisterPushSubscriptionUseCase: エンドポイント送信
5. Service Worker: バックグラウンドでプッシュ受信
6. NotificationState: 通知表示・更新

### フロー 6: OAuth同意画面（外部アプリ認可）
1. External App → Gateway → IAM: 認可リクエスト
2. IAM: 認可セッション作成、session_id発行
3. Gateway → avion-web: `/consent?session_id=xxx&client_id=yyy`へリダイレクト
4. ConsentPage: セッション検証、クライアント情報取得
5. OAuthConsentAggregate: 同意画面表示
   - クライアント名、ロゴ表示
   - 要求スコープの説明表示
   - 同意/拒否ボタン表示
6. User: 同意または拒否選択
7. GrantOAuthConsentCommandUseCase または DenyOAuthConsentCommandUseCase:
   - Client → API Routes → Gateway → IAM: 同意結果送信
8. IAM: 同意結果に基づいて処理
   - 同意の場合: 認可コード発行
   - 拒否の場合: エラーレスポンス
9. avion-web → External App: コールバックURLへリダイレクト

## 7. UI/UX Specifications

### 7.1. Design Tokens

#### Color System
Design tokens for the Avion brand implemented as CSS custom properties for dynamic theming support.

```css
:root {
  /* Primary Brand Colors */
  --color-primary-50: hsl(210, 100%, 98%);
  --color-primary-100: hsl(210, 100%, 95%);
  --color-primary-500: hsl(210, 100%, 50%);
  --color-primary-600: hsl(210, 100%, 45%);
  --color-primary-700: hsl(210, 100%, 40%);
  --color-primary-900: hsl(210, 100%, 20%);

  /* Semantic Colors */
  --color-success-50: hsl(142, 76%, 96%);
  --color-success-500: hsl(142, 76%, 36%);
  --color-success-700: hsl(142, 76%, 30%);
  
  --color-warning-50: hsl(48, 100%, 96%);
  --color-warning-500: hsl(48, 100%, 50%);
  --color-warning-700: hsl(48, 100%, 40%);
  
  --color-error-50: hsl(0, 86%, 97%);
  --color-error-500: hsl(0, 86%, 59%);
  --color-error-700: hsl(0, 86%, 50%);

  /* Neutral Colors */
  --color-neutral-0: hsl(0, 0%, 100%);
  --color-neutral-50: hsl(210, 20%, 98%);
  --color-neutral-100: hsl(210, 20%, 95%);
  --color-neutral-200: hsl(210, 16%, 88%);
  --color-neutral-300: hsl(210, 14%, 83%);
  --color-neutral-400: hsl(210, 14%, 71%);
  --color-neutral-500: hsl(210, 11%, 57%);
  --color-neutral-600: hsl(210, 12%, 45%);
  --color-neutral-700: hsl(210, 15%, 34%);
  --color-neutral-800: hsl(210, 19%, 24%);
  --color-neutral-900: hsl(210, 24%, 16%);
  --color-neutral-950: hsl(210, 33%, 9%);
}

/* Dark Mode Override */
[data-theme="dark"] {
  --color-neutral-0: hsl(210, 33%, 9%);
  --color-neutral-50: hsl(210, 24%, 16%);
  --color-neutral-100: hsl(210, 19%, 24%);
  --color-neutral-900: hsl(210, 20%, 95%);
  --color-neutral-950: hsl(0, 0%, 100%);
}
```

#### Typography Scale
Modular scale (1.25 ratio) with system font stack for optimal performance.

```css
:root {
  /* Font Families */
  --font-sans: "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  --font-mono: "SF Mono", Monaco, "Cascadia Code", "Roboto Mono", Consolas, "Courier New", monospace;

  /* Font Sizes */
  --text-xs: 0.75rem;    /* 12px */
  --text-sm: 0.875rem;   /* 14px */
  --text-base: 1rem;     /* 16px */
  --text-lg: 1.125rem;   /* 18px */
  --text-xl: 1.25rem;    /* 20px */
  --text-2xl: 1.5rem;    /* 24px */
  --text-3xl: 1.875rem;  /* 30px */
  --text-4xl: 2.25rem;   /* 36px */

  /* Line Heights */
  --leading-tight: 1.25;
  --leading-normal: 1.5;
  --leading-relaxed: 1.625;

  /* Font Weights */
  --font-normal: 400;
  --font-medium: 500;
  --font-semibold: 600;
  --font-bold: 700;

  /* Letter Spacing */
  --tracking-tight: -0.025em;
  --tracking-normal: 0;
  --tracking-wide: 0.025em;
}
```

#### Spacing System
8px base grid system for consistent spacing throughout the application.

```css
:root {
  /* Spacing Scale (8px base) */
  --space-1: 0.25rem;   /* 4px */
  --space-2: 0.5rem;    /* 8px */
  --space-3: 0.75rem;   /* 12px */
  --space-4: 1rem;      /* 16px */
  --space-6: 1.5rem;    /* 24px */
  --space-8: 2rem;      /* 32px */
  --space-12: 3rem;     /* 48px */
  --space-16: 4rem;     /* 64px */
  --space-24: 6rem;     /* 96px */

  /* Component-specific spacing */
  --padding-xs: var(--space-2) var(--space-3);
  --padding-sm: var(--space-3) var(--space-4);
  --padding-md: var(--space-4) var(--space-6);
  --padding-lg: var(--space-6) var(--space-8);
}
```

#### Shadow and Elevation System
Layered shadow system for component depth hierarchy.

```css
:root {
  /* Shadow System */
  --shadow-sm: 0 1px 2px 0 rgb(0 0 0 / 0.05);
  --shadow-md: 0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1);
  --shadow-lg: 0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1);
  --shadow-xl: 0 20px 25px -5px rgb(0 0 0 / 0.1), 0 8px 10px -6px rgb(0 0 0 / 0.1);
  --shadow-2xl: 0 25px 50px -12px rgb(0 0 0 / 0.25);

  /* Focus Ring */
  --ring-offset: 2px;
  --ring-width: 2px;
  --ring-color: var(--color-primary-500);
  --ring-shadow: 0 0 0 var(--ring-offset) var(--color-neutral-0), 
                 0 0 0 calc(var(--ring-width) + var(--ring-offset)) var(--ring-color);
}
```

### 7.2. Component Library Specifications

#### Base Components

**Button Component**
```typescript
interface ButtonProps {
  variant: 'primary' | 'secondary' | 'tertiary' | 'destructive';
  size: 'sm' | 'md' | 'lg';
  loading?: boolean;
  disabled?: boolean;
  children: React.ReactNode;
  onClick?: () => void;
}

// States and styling
const buttonVariants = {
  primary: {
    default: 'bg-primary-500 text-white border-primary-500',
    hover: 'bg-primary-600 border-primary-600',
    focus: 'ring-primary-500',
    active: 'bg-primary-700',
    disabled: 'bg-neutral-200 text-neutral-400 cursor-not-allowed'
  },
  secondary: {
    default: 'bg-transparent text-primary-500 border-primary-500',
    hover: 'bg-primary-50 border-primary-600',
    focus: 'ring-primary-500',
    active: 'bg-primary-100'
  }
};
```

**Input Component**
```typescript
interface InputProps {
  type: 'text' | 'email' | 'password' | 'search';
  placeholder?: string;
  error?: string;
  label?: string;
  required?: boolean;
  disabled?: boolean;
  value: string;
  onChange: (value: string) => void;
}

// State variations with visual feedback
const inputStates = {
  default: 'border-neutral-300 focus:border-primary-500 focus:ring-primary-500',
  error: 'border-error-500 focus:border-error-500 focus:ring-error-500',
  disabled: 'bg-neutral-100 border-neutral-200 cursor-not-allowed'
};
```

**Card Component**
```typescript
interface CardProps {
  variant: 'default' | 'elevated' | 'outlined';
  padding: 'sm' | 'md' | 'lg';
  children: React.ReactNode;
  interactive?: boolean;
}

// Card styling with hover states for interactive cards
const cardVariants = {
  default: 'bg-white border border-neutral-200',
  elevated: 'bg-white shadow-md',
  outlined: 'bg-transparent border-2 border-neutral-300'
};
```

#### Composite Components

**Navigation Component**
```typescript
interface NavigationProps {
  items: NavItem[];
  activeItem: string;
  onItemClick: (itemId: string) => void;
  variant: 'horizontal' | 'vertical';
  collapsible?: boolean;
}

interface NavItem {
  id: string;
  label: string;
  icon?: React.ComponentType;
  badge?: number;
  href?: string;
}
```

**Timeline Component**
```typescript
interface TimelineProps {
  items: TimelineItem[];
  loading?: boolean;
  onLoadMore: () => void;
  hasMore: boolean;
  emptyState?: React.ReactNode;
}

interface TimelineItem {
  id: string;
  content: React.ReactNode;
  timestamp: Date;
  author: UserInfo;
  interactions: InteractionData;
}
```

### 7.3. Responsive Design Strategy

#### Breakpoint Definitions
```typescript
const breakpoints = {
  mobile: '320px',   // 320px - 767px
  tablet: '768px',   // 768px - 1023px
  desktop: '1024px', // 1024px - 1439px
  wide: '1440px'     // 1440px+
} as const;

// Tailwind CSS configuration
module.exports = {
  theme: {
    screens: {
      'sm': '768px',
      'md': '1024px',
      'lg': '1440px',
    },
    container: {
      center: true,
      padding: {
        DEFAULT: '1rem',
        sm: '2rem',
        lg: '4rem',
      },
    },
  },
};
```

#### Grid System Specifications
```css
/* Container max-widths */
.container {
  width: 100%;
  margin-left: auto;
  margin-right: auto;
}

@media (min-width: 768px) {
  .container { max-width: 768px; }
}

@media (min-width: 1024px) {
  .container { max-width: 1024px; }
}

@media (min-width: 1440px) {
  .container { max-width: 1440px; }
}

/* Grid columns */
.grid {
  display: grid;
  gap: 1rem;
  grid-template-columns: repeat(4, 1fr); /* Mobile: 4 columns */
}

@media (min-width: 768px) {
  .grid {
    gap: 1.5rem;
    grid-template-columns: repeat(8, 1fr); /* Tablet: 8 columns */
  }
}

@media (min-width: 1024px) {
  .grid {
    gap: 2rem;
    grid-template-columns: repeat(12, 1fr); /* Desktop: 12 columns */
  }
}
```

#### Responsive Component Behaviors
```typescript
// Layout component with responsive behavior
const Layout: React.FC = ({ children }) => {
  const [isMobile, setIsMobile] = useState(false);
  
  useEffect(() => {
    const checkIsMobile = () => {
      setIsMobile(window.innerWidth < 768);
    };
    
    checkIsMobile();
    window.addEventListener('resize', checkIsMobile);
    return () => window.removeEventListener('resize', checkIsMobile);
  }, []);

  return (
    <div className="min-h-screen bg-neutral-50">
      {isMobile ? (
        <MobileNavigation />
      ) : (
        <DesktopSidebar />
      )}
      <main className={`
        ${isMobile ? 'pt-16' : 'pl-64'} 
        transition-all duration-300
      `}>
        {children}
      </main>
    </div>
  );
};
```

### 7.4. Animation Guidelines

#### Transition Durations and Easing Functions
```css
:root {
  /* Duration tokens */
  --duration-fast: 150ms;
  --duration-normal: 250ms;
  --duration-slow: 400ms;

  /* Easing functions */
  --ease-in: cubic-bezier(0.4, 0, 1, 1);
  --ease-out: cubic-bezier(0, 0, 0.2, 1);
  --ease-in-out: cubic-bezier(0.4, 0, 0.2, 1);
}

/* Common transition patterns */
.transition-colors {
  transition: background-color var(--duration-fast) var(--ease-out),
              color var(--duration-fast) var(--ease-out),
              border-color var(--duration-fast) var(--ease-out);
}

.transition-transform {
  transition: transform var(--duration-normal) var(--ease-out);
}

.transition-opacity {
  transition: opacity var(--duration-fast) var(--ease-out);
}
```

#### Micro-interactions Specifications
```typescript
// Button hover animation
const AnimatedButton: React.FC<ButtonProps> = ({ children, ...props }) => {
  return (
    <button
      className="
        transform transition-all duration-150 ease-out
        hover:scale-105 hover:shadow-md
        active:scale-95 active:shadow-sm
        focus:ring-2 focus:ring-primary-500 focus:ring-offset-2
      "
      {...props}
    >
      {children}
    </button>
  );
};

// Loading state skeleton animation
const SkeletonLoader: React.FC = () => {
  return (
    <div className="animate-pulse space-y-4">
      <div className="h-4 bg-neutral-200 rounded w-3/4"></div>
      <div className="h-4 bg-neutral-200 rounded w-1/2"></div>
      <div className="h-4 bg-neutral-200 rounded w-5/6"></div>
    </div>
  );
};
```

#### Page Transition Animations
```typescript
// Route transition with Framer Motion
const PageTransition: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -20 }}
      transition={{
        duration: 0.2,
        ease: "easeOut"
      }}
    >
      {children}
    </motion.div>
  );
};

// Modal entrance animation
const Modal: React.FC<ModalProps> = ({ isOpen, children, onClose }) => {
  return (
    <AnimatePresence>
      {isOpen && (
        <>
          <motion.div
            className="fixed inset-0 bg-black bg-opacity-50"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={onClose}
          />
          <motion.div
            className="fixed inset-0 flex items-center justify-center p-4"
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.95 }}
            transition={{ duration: 0.25, ease: "easeOut" }}
          >
            {children}
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
};
```

### 7.5. Accessibility Implementation

#### ARIA Attributes Usage
```typescript
// Comprehensive button with ARIA support
const AccessibleButton: React.FC<{
  children: React.ReactNode;
  onClick: () => void;
  loading?: boolean;
  disabled?: boolean;
  ariaLabel?: string;
  ariaDescribedBy?: string;
}> = ({ children, onClick, loading, disabled, ariaLabel, ariaDescribedBy }) => {
  return (
    <button
      onClick={onClick}
      disabled={disabled || loading}
      aria-label={ariaLabel}
      aria-describedby={ariaDescribedBy}
      aria-busy={loading}
      className="focus:ring-2 focus:ring-primary-500 focus:ring-offset-2"
    >
      {loading && (
        <span className="sr-only">Loading...</span>
      )}
      {children}
    </button>
  );
};

// Form field with proper labeling
const AccessibleInput: React.FC<{
  id: string;
  label: string;
  error?: string;
  required?: boolean;
  value: string;
  onChange: (value: string) => void;
}> = ({ id, label, error, required, value, onChange }) => {
  const errorId = error ? `${id}-error` : undefined;
  
  return (
    <div>
      <label 
        htmlFor={id}
        className="block text-sm font-medium text-neutral-700"
      >
        {label}
        {required && <span aria-label="required">*</span>}
      </label>
      <input
        id={id}
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        aria-describedby={errorId}
        aria-invalid={error ? 'true' : 'false'}
        className={`
          mt-1 block w-full rounded-md border px-3 py-2
          focus:ring-2 focus:ring-primary-500 focus:border-primary-500
          ${error ? 'border-error-500' : 'border-neutral-300'}
        `}
      />
      {error && (
        <p id={errorId} role="alert" className="mt-1 text-sm text-error-600">
          {error}
        </p>
      )}
    </div>
  );
};
```

#### Keyboard Navigation Patterns
```typescript
// Skip link implementation
const SkipLink: React.FC = () => {
  return (
    <a
      href="#main-content"
      className="
        sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4
        bg-primary-500 text-white px-4 py-2 rounded-md
        focus:ring-2 focus:ring-primary-300 focus:ring-offset-2
      "
    >
      Skip to main content
    </a>
  );
};

// Modal with focus management
const AccessibleModal: React.FC<{
  isOpen: boolean;
  onClose: () => void;
  children: React.ReactNode;
  title: string;
}> = ({ isOpen, onClose, children, title }) => {
  const modalRef = useRef<HTMLDivElement>(null);
  const previousFocusRef = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (isOpen) {
      previousFocusRef.current = document.activeElement as HTMLElement;
      modalRef.current?.focus();
    } else {
      previousFocusRef.current?.focus();
    }
  }, [isOpen]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      onClose();
    }
  };

  if (!isOpen) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center"
      role="dialog"
      aria-modal="true"
      aria-labelledby="modal-title"
    >
      <div
        ref={modalRef}
        className="bg-white rounded-lg p-6 shadow-xl max-w-md w-full mx-4"
        tabIndex={-1}
        onKeyDown={handleKeyDown}
      >
        <h2 id="modal-title" className="text-lg font-semibold mb-4">
          {title}
        </h2>
        {children}
        <button
          onClick={onClose}
          className="mt-4 px-4 py-2 bg-neutral-200 rounded focus:ring-2 focus:ring-primary-500"
        >
          Close
        </button>
      </div>
    </div>
  );
};
```

#### Screen Reader Optimization
```typescript
// Live region for dynamic content updates
const LiveRegion: React.FC<{
  message: string;
  priority: 'polite' | 'assertive';
}> = ({ message, priority }) => {
  return (
    <div
      aria-live={priority}
      aria-atomic="true"
      className="sr-only"
    >
      {message}
    </div>
  );
};

// Timeline with screen reader optimization
const AccessibleTimeline: React.FC<{
  items: TimelineItem[];
}> = ({ items }) => {
  return (
    <div role="feed" aria-label="Timeline">
      {items.map((item, index) => (
        <article
          key={item.id}
          role="article"
          aria-posinset={index + 1}
          aria-setsize={items.length}
          className="border-b border-neutral-200 py-4"
        >
          <header>
            <h3 className="sr-only">
              Post by {item.author.displayName}
            </h3>
            <div aria-label={`Posted ${formatDate(item.timestamp)}`}>
              <UserAvatar user={item.author} />
              <span className="font-medium">{item.author.displayName}</span>
              <time dateTime={item.timestamp.toISOString()}>
                {formatRelativeTime(item.timestamp)}
              </time>
            </div>
          </header>
          <div className="mt-2">
            {item.content}
          </div>
          <footer className="mt-2 flex space-x-4">
            <button
              aria-label={`Like this post. Currently ${item.likes} likes`}
              className="flex items-center space-x-1"
            >
              <HeartIcon />
              <span>{item.likes}</span>
            </button>
          </footer>
        </article>
      ))}
    </div>
  );
};
```

#### Color Contrast Requirements
```css
/* Ensure WCAG AA compliance for all text */
:root {
  /* High contrast text combinations */
  --text-primary: var(--color-neutral-900);     /* 21:1 ratio on white */
  --text-secondary: var(--color-neutral-700);   /* 8.6:1 ratio on white */
  --text-tertiary: var(--color-neutral-600);    /* 6.8:1 ratio on white */
  
  /* Interactive element contrasts */
  --link-color: var(--color-primary-600);       /* 4.5:1 ratio on white */
  --link-hover: var(--color-primary-700);       /* 5.7:1 ratio on white */
  
  /* Status colors with sufficient contrast */
  --success-text: hsl(142, 76%, 26%);          /* 4.5:1 ratio */
  --warning-text: hsl(48, 100%, 30%);          /* 4.6:1 ratio */
  --error-text: hsl(0, 86%, 45%);              /* 4.5:1 ratio */
}

/* High contrast mode support */
@media (prefers-contrast: high) {
  :root {
    --text-primary: var(--color-neutral-950);
    --border-color: var(--color-neutral-900);
    --ring-color: var(--color-primary-700);
  }
}

/* Reduced motion support */
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

## 8. Data Design (データ)

### 7.1. GraphQL Schema (主要型)

```graphql
type Query {
  # ユーザー
  me: User!
  user(id: ID!): User
  
  # タイムライン
  homeTimeline(first: Int!, after: String): TimelineConnection!
  globalTimeline(first: Int!, after: String): TimelineConnection!
  
  # 通知
  notifications(first: Int!, after: String): NotificationConnection!
  
  # OAuth
  oauthConsentSession(sessionId: ID!): OAuthConsentSession
}

type Mutation {
  # 認証
  login(input: LoginInput!): AuthPayload!
  logout: Boolean!
  
  # Drop操作
  createDrop(input: CreateDropInput!): Drop!
  deleteDrop(id: ID!): DeleteDropPayload!
  
  # リアクション
  addReaction(dropId: ID!, emoji: String!): Reaction!
  removeReaction(dropId: ID!, emoji: String!): Boolean!
  
  # フォロー
  followUser(userId: ID!): User!
  unfollowUser(userId: ID!): User!
  
  # OAuth同意
  grantOAuthConsent(sessionId: ID!): OAuthConsentResult!
  denyOAuthConsent(sessionId: ID!): OAuthConsentResult!
}

type Drop {
  id: ID!
  content: String!
  author: User!
  createdAt: DateTime!
  reactions: [Reaction!]!
  reactionCount: Int!
  visibility: Visibility!
}

type User {
  id: ID!
  username: String!
  displayName: String!
  bio: String
  avatarUrl: String
  followersCount: Int!
  followingCount: Int!
  isFollowing: Boolean!
}

# OAuth同意画面関連型
type OAuthConsentSession {
  sessionId: ID!
  client: OAuthClient!
  requestedScopes: [OAuthScope!]!
  state: String!
  codeChallenge: String
  codeChallengeMethod: String
}

type OAuthClient {
  clientId: ID!
  clientName: String!
  clientUri: String
  logoUri: String
  description: String
  trusted: Boolean!
}

type OAuthScope {
  name: String!
  description: String!
  required: Boolean!
}

type OAuthConsentResult {
  success: Boolean!
  redirectUri: String
  error: String
}
```

### 7.2. Domain Model States

```typescript
// ViewState Aggregate
interface ViewState {
  currentRoute: RouteParams;
  timeline: TimelineViewState;
  notification: NotificationState;
  forms: Map<string, FormState>;
  modals: ModalState;
}

// UserSession Aggregate
interface UserSession {
  authToken: AuthToken | null;
  user: User | null;
  preferences: UserPreferences;
  authMethods: AuthMethod[];
}

// SSEConnection Aggregate
interface SSEConnection {
  connectionId: ConnectionID;
  userId: UserID;
  status: ConnectionStatus;
  subscriptions: EventSubscription[];
  lastEventId: string;
}

// OAuthConsent Aggregate
interface OAuthConsent {
  sessionId: SessionID;
  client: OAuthClient;
  requestedScopes: OAuthScope[];
  state: string;
  codeChallenge?: string;
  codeChallengeMethod?: string;
  consentStatus: ConsentStatus; // 'pending' | 'granted' | 'denied'
}
```

### 7.3. Value Object 実装例

```typescript
// AuthToken Value Object
export class AuthToken {
  private readonly token: string;
  private readonly expiresAt: Date;

  constructor(token: string, expiresAt: Date) {
    if (!token || token.length < 10) {
      throw new InvalidTokenError('Token is invalid');
    }
    if (expiresAt <= new Date()) {
      throw new TokenExpiredError('Token is already expired');
    }
    this.token = token;
    this.expiresAt = new Date(expiresAt);
  }

  getValue(): string { return this.token; }
  getExpiresAt(): Date { return new Date(this.expiresAt); }
  isExpired(): boolean { return this.expiresAt <= new Date(); }
}

// CursorToken Value Object
export class CursorToken {
  private readonly value: string;

  constructor(value: string) {
    if (!this.isValidBase64(value)) {
      throw new Error('Invalid cursor format');
    }
    this.value = value;
  }

  private isValidBase64(str: string): boolean {
    try {
      return btoa(atob(str)) === str;
    } catch {
      return false;
    }
  }

  toString(): string { return this.value; }
  decode(): string { return atob(this.value); }
}

// RouteParams Value Object
export class RouteParams {
  constructor(
    private readonly path: string,
    private readonly params: Record<string, string>,
    private readonly query: URLSearchParams
  ) {
    if (!path.startsWith('/')) {
      throw new Error('Path must start with /');
    }
  }

  getPath(): string { return this.path; }
  getParam(key: string): string | undefined { return this.params[key]; }
  getQuery(key: string): string | null { return this.query.get(key); }
}
```

### 7.4. Cache Strategy

- **GraphQL Query Cache:** 1-5分（クエリタイプによる）
- **DataLoader Cache:** リクエスト期間中
- **Auth Token:** セッション期間中（LocalStorage）
- **Service Worker Cache:** 静的アセットは長期、APIレスポンスは短期

## 8. API Design (Gateway経由のエンドポイント)

### GraphQL Endpoint (Gateway)
- `POST https://api.avion.example/graphql`: GraphQL Query/Mutation
- `GET https://api.avion.example/graphql-playground`: GraphQL Playground（開発環境）

### SSE Endpoints (Gateway)
- `GET https://api.avion.example/sse/timeline`: タイムライン更新ストリーム
- `GET https://api.avion.example/sse/notifications`: 通知ストリーム
- `GET https://api.avion.example/sse/drops/{dropId}`: 特定投稿の更新ストリーム

### OAuth Consent Pages (Client)
- `GET /consent`: OAuth同意画面表示（React Router）
- 同意/拒否はGraphQL Mutation経由でGatewayへ送信

## 9. Operations & Monitoring (運用と監視)

### デプロイメント
- **ビルド:** `npm run build` でViteによる静的アセット生成
- **配信:** CDN経由で静的ファイル配信（S3 + CloudFront等）
- **キャッシュ:** 長期キャッシュ（immutable assets）とバージョニング
- **更新:** CI/CDパイプラインでCDNへ自動デプロイ

### 監視項目
- **メトリクス:**
  - Core Web Vitals (LCP, FID, CLS)
  - GraphQL Query/Mutation レイテンシ
  - SSE接続数、イベント配信数
  - API Routes エラー率
  - DataLoader効率（ヒット率、バッチサイズ）
- **ログ:**
  - クライアントエラー（Sentry等）
  - APIリクエストログ
  - SSE接続ログ
- **トレース:**
  - エンドツーエンドのリクエストフロー
  - GraphQLリゾルバ実行時間
  - バックエンドサービス呼び出し

### アラート
- エラー率上昇（> 5%）
- 高レイテンシ（P99 > 500ms）
- SSE接続エラー急増
- メモリ使用率異常

## 10. Security Considerations (セキュリティ考慮事項)

- **XSS対策:** Reactのデフォルト保護 + CSP実装
- **CSRF対策:** SameSite Cookie + CSRF Token
- **認証:** JWT検証はavion-gateway層で実施
- **GraphQL:** クエリ深度制限、複雑度制限
- **依存関係:** 定期的な脆弱性スキャン
- **環境変数:** サーバーサイドのみでシークレット使用

## 11. Testing Strategy (テスト戦略)

### TDD アプローチ
1. **インターフェース/型定義を最初に作成**
2. **テストを先に記述**（Vitest for unit tests, Playwright for E2E）
3. **テストが通るように実装**
4. **すべてのテストが通ることを確認してから次のファイルへ**

### Unit Tests
- Domain層: Aggregates、Entities、Value Objectsの振る舞い
- Use Case層: ビジネスロジックの検証
- Utility関数: 純粋関数のテスト
- React Components: コンポーネントの振る舞いとProps検証

### Integration Tests
- API Routes: GraphQL、SSEエンドポイント
- Repository層: 外部サービスとの連携
- GraphQL Resolvers: データフェッチングとエラーハンドリング

### E2E Tests

このサービスのE2Eテストは、[共通E2Eテスト戦略](../common/e2e-testing-strategy.md)に従って実装します。

#### 主要なE2Eテストシナリオ
- ユーザー認証フロー（ログイン、ログアウト、登録）
- Drop投稿・編集・削除の完全ワークフロー
- フォロー・アンフォロー機能とタイムライン反映
- リアルタイム通知受信とSSE接続の確認
- PWA機能（インストール、プッシュ通知、オフライン動作）
- レスポンシブデザインと各種デバイスサイズ対応
- ダークモード・ライトモードの切り替え機能
- アクセシビリティ要件（WAI-ARIA、キーボードナビゲーション）

詳細は[共通E2Eテスト戦略ドキュメント](../common/e2e-testing-strategy.md)を参照してください。

### Performance Tests
- Lighthouse CI: Core Web Vitals監視
- Load Testing: GraphQL、SSEエンドポイント
- Bundle Size Analysis: JavaScriptバンドルサイズの監視

## 12. 構造化ログ戦略

このサービスでは、クライアントサイドの構造化ログを採用し、ユーザー体験の監視とデバッグ効率を向上させます。

### ログフレームワーク

- **使用ライブラリ**: カスタムロガー + Sentry/DataDog RUM
- **出力形式**: 構造化オブジェクト（本番環境では外部サービスへ送信）
- **ログレベル**: Debug, Info, Warn, Error（本番環境ではDebug無効）
- **収集方法**: バッチングして定期送信

### ログ構造の標準フィールド

```typescript
// クライアントサイドログ構造
interface ClientLogContext {
  timestamp: string;
  level: string;
  component: string;   // コンポーネント名
  action: string;      // ユーザーアクション
  
  // コンテキスト
  userId?: string;
  sessionId?: string;
  page?: string;
  route?: string;      // React Router のルート
  
  // エラー情報
  error?: string;
  errorBoundary?: string;
  errorCode?: string;
  stackTrace?: string;
  
  // パフォーマンス
  renderTime?: number;
  apiLatency?: number;
  cacheHit?: boolean;
  
  // デバイス情報
  userAgent?: string;
  viewport?: { width: number; height: number };
  connectionType?: string;
  
  // カスタムフィールド
  extra?: Record<string, unknown>;
}
```


### クライアントサイドログ

#### ユーザーアクション
```typescript
clientLogger.info({
  message: 'User action',
  component: 'CreateDropForm',
  action: 'submit_drop',
  userId,
  dropLength: content.length,
  hasMedia: !!mediaFiles.length,
});

clientLogger.error({
  message: 'Form validation failed',
  component: 'LoginForm',
  action: 'submit',
  field: validationError.field,
  reason: validationError.reason,
});
```

#### パフォーマンス監視
```typescript
// React Component rendering
clientLogger.info({
  message: 'Slow component render',
  component: 'Timeline',
  renderTime: performance.now() - startTime,
  itemCount: items.length,
  page: window.location.pathname,
});

// API呼び出し
clientLogger.warn({
  message: 'Slow API response',
  endpoint: '/api/graphql',
  operation: operationName,
  durationMs: endTime - startTime,
  responseSize: response.length,
});
```

#### エラーバウンダリー
```typescript
class ErrorBoundary extends Component {
  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    clientLogger.error({
      message: 'React error boundary triggered',
      error: error.message,
      errorBoundary: this.constructor.name,
      componentStack: errorInfo.componentStack,
      page: window.location.pathname,
    });
  }
}
```

### GraphQLクライアントログ

```typescript
// Query実行
clientLogger.info({
  message: 'GraphQL query executed',
  component: 'GraphQLClient',
  action: 'query',
  operationName,
  cacheHit: fromCache,
  apiLatency: endTime - startTime,
});

// Mutation実行
clientLogger.info({
  message: 'GraphQL mutation executed',
  component: 'GraphQLClient',
  action: 'mutation',
  operationName,
  optimisticUpdate: hasOptimisticUpdate,
  apiLatency: endTime - startTime,
});

// エラーハンドリング
clientLogger.error({
  message: 'GraphQL error',
  component: 'GraphQLClient',
  action: 'error',
  operationName,
  error: error.message,
  errorCode: error.extensions?.code,
});
```

### SSEクライアントログ

```typescript
// 接続管理
clientLogger.info({
  message: 'SSE connection established',
  component: 'SSEClient',
  action: 'connect',
  endpoint,
  reconnectAttempt,
});

// イベント受信
clientLogger.debug({
  message: 'SSE event received',
  component: 'SSEClient',
  action: 'event',
  eventType,
  eventId,
});

// エラーハンドリング
clientLogger.error({
  message: 'SSE connection error',
  component: 'SSEClient',
  action: 'error',
  error: error.message,
  willReconnect: true,
  reconnectDelay,
});
```

### Service Worker のログ

```typescript
// Push通知
self.addEventListener('push', (event) => {
  console.log({
    message: 'Push notification received',
    event: 'push_received',
    hasData: !!event.data,
    timestamp: new Date().toISOString(),
  });
});

// キャッシュ戦略
self.addEventListener('fetch', (event) => {
  if (event.request.url.includes('/api/')) {
    console.log({
      message: 'API request intercepted',
      url: event.request.url,
      method: event.request.method,
      cacheMode: event.request.cache,
    });
  }
});
```

### クライアントサイドログの収集

```typescript
// プロダクション環境での外部サービス送信
class ClientLogger {
  private queue: ClientLogContext[] = [];
  
  log(context: ClientLogContext) {
    if (process.env.NODE_ENV === 'production') {
      // バッチ送信のためキューに追加
      this.queue.push(context);
      this.scheduleFlush();
    } else {
      // 開発環境ではコンソール出力
      console.log(context);
    }
  }
  
  private async flush() {
    if (this.queue.length === 0) return;
    
    const logs = [...this.queue];
    this.queue = [];
    
    try {
      await fetch('/api/logs', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ logs }),
      });
    } catch (error) {
      // ログ送信失敗時は諦める（無限ループ防止）
      console.error('Failed to send logs', error);
    }
  }
}
```


### ログ集約とクエリ

- **収集方法**: バッチ送信またはSentry/DataDog RUM
- **分析ツール**: Sentry、DataDog、LogRocket等
- **クエリ例**:
  ```
  component="Timeline" AND renderTime>1000
  action="submit_drop" AND error IS NOT NULL
  errorBoundary IS NOT NULL AND route="/home"
  component="GraphQLClient" AND apiLatency>2000
  component="SSEClient" AND action="error"
  ```

### セキュリティ考慮事項
- パスワードや認証トークンは絶対にログに含めない
- 個人情報（メールアドレス等）はマスキング
- GraphQL変数に含まれる機密データはフィルタリング
- クライアントIPアドレスは必要最小限の記録
- クライアントサイドログはユーザーが改ざん可能な前提で扱う

## 13. GraphQL Schema 詳細設計

### 13.1. Query Types

```graphql
# User関連
type UserConnection {
  edges: [UserEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

type UserEdge {
  cursor: String!
  node: User!
}

type UserProfile {
  id: ID!
  username: String!
  displayName: String!
  bio: String
  avatarUrl: String
  headerUrl: String
  location: String
  website: String
  joinedAt: DateTime!
  stats: UserStats!
  settings: UserSettings!
  isBot: Boolean!
  isLocked: Boolean!
  isSuspended: Boolean!
  relationships: UserRelationships!
}

type UserStats {
  dropsCount: Int!
  followersCount: Int!
  followingCount: Int!
  listsCount: Int!
  favoritesCount: Int!
}

type UserRelationships {
  isFollowing: Boolean!
  isFollowedBy: Boolean!
  isMuting: Boolean!
  isBlocking: Boolean!
  isBlockedBy: Boolean!
  hasFollowRequest: Boolean!
  hasPendingFollowRequest: Boolean!
}

# Drop関連
type DropConnection {
  edges: [DropEdge!]!
  pageInfo: PageInfo!
  totalCount: Int
}

type DropEdge {
  cursor: String!
  node: Drop!
}

type Drop {
  id: ID!
  content: String!
  author: User!
  createdAt: DateTime!
  updatedAt: DateTime
  visibility: DropVisibility!
  sensitive: Boolean!
  spoilerText: String
  language: String
  media: [Media!]!
  mentions: [User!]!
  hashtags: [Hashtag!]!
  emojis: [CustomEmoji!]!
  reactions: ReactionConnection!
  replyToId: ID
  replyTo: Drop
  repliesCount: Int!
  redropCount: Int!
  favoritesCount: Int!
  viewerContext: DropViewerContext!
  source: DropSource!
}

type DropViewerContext {
  hasReacted: Boolean!
  hasRedropped: Boolean!
  hasFavorited: Boolean!
  isMuted: Boolean!
  canEdit: Boolean!
  canDelete: Boolean!
}

type ReactionConnection {
  edges: [ReactionEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
  byEmoji: [ReactionGroup!]!
}

type ReactionGroup {
  emoji: String!
  count: Int!
  users(first: Int, after: String): UserConnection!
  hasReacted: Boolean!
}

# Timeline関連
type TimelineConnection {
  edges: [TimelineEdge!]!
  pageInfo: PageInfo!
  filters: TimelineFilters!
}

type TimelineEdge {
  cursor: String!
  node: TimelineItem!
}

type TimelineItem {
  id: ID!
  type: TimelineItemType!
  drop: Drop
  activity: Activity
  announcement: Announcement
  insertedAt: DateTime!
}

enum TimelineItemType {
  DROP
  REDROP
  REACTION
  FOLLOW
  ANNOUNCEMENT
}

type TimelineFilters {
  includeReplies: Boolean!
  includeRedrops: Boolean!
  onlyMedia: Boolean!
  languages: [String!]!
}

# Notification関連
type NotificationConnection {
  edges: [NotificationEdge!]!
  pageInfo: PageInfo!
  unreadCount: Int!
}

type NotificationEdge {
  cursor: String!
  node: Notification!
}

type Notification {
  id: ID!
  type: NotificationType!
  createdAt: DateTime!
  isRead: Boolean!
  actor: User
  drop: Drop
  follow: FollowActivity
  reaction: Reaction
  mention: Mention
}

enum NotificationType {
  FOLLOW
  FOLLOW_REQUEST
  MENTION
  REPLY
  REDROP
  REACTION
  POLL_ENDED
  ANNOUNCEMENT
}

# Media関連
type Media {
  id: ID!
  type: MediaType!
  url: String!
  thumbnailUrl: String!
  previewUrl: String!
  blurhash: String
  width: Int
  height: Int
  duration: Float
  description: String
  attachmentType: AttachmentType!
}

enum MediaType {
  IMAGE
  VIDEO
  AUDIO
  DOCUMENT
}

enum AttachmentType {
  ORIGINAL
  THUMBNAIL
  PREVIEW
}

# Search関連
type SearchResults {
  drops: DropConnection!
  users: UserConnection!
  hashtags: HashtagConnection!
  suggestions: [SearchSuggestion!]!
}

type SearchSuggestion {
  type: SearchSuggestionType!
  value: String!
  score: Float!
}

enum SearchSuggestionType {
  USER
  HASHTAG
  KEYWORD
}
```

### 13.2. Mutation Types

```graphql
# Authentication
input LoginInput {
  username: String!
  password: String!
  totpCode: String
  deviceFingerprint: String!
}

type AuthPayload {
  token: String!
  refreshToken: String!
  user: User!
  expiresIn: Int!
}

input RefreshTokenInput {
  refreshToken: String!
  deviceFingerprint: String!
}

# Drop Operations
input CreateDropInput {
  content: String!
  visibility: DropVisibility
  sensitive: Boolean
  spoilerText: String
  mediaIds: [ID!]
  replyToId: ID
  pollOptions: [String!]
  pollExpiresIn: Int
  language: String
  scheduledAt: DateTime
}

input UpdateDropInput {
  dropId: ID!
  content: String
  sensitive: Boolean
  spoilerText: String
}

type DeleteDropPayload {
  success: Boolean!
  deletedId: ID!
}

# Reaction Operations
input AddReactionInput {
  dropId: ID!
  emoji: String!
  customEmojiId: ID
}

input RemoveReactionInput {
  dropId: ID!
  emoji: String!
}

type ReactionPayload {
  reaction: Reaction!
  drop: Drop!
}

# User Operations
input UpdateProfileInput {
  displayName: String
  bio: String
  location: String
  website: String
  avatarId: ID
  headerId: ID
  isLocked: Boolean
  isBot: Boolean
}

input FollowUserInput {
  userId: ID!
  notify: Boolean
}

input UnfollowUserInput {
  userId: ID!
}

type FollowPayload {
  user: User!
  relationship: UserRelationships!
}

# Notification Operations
input MarkNotificationsReadInput {
  notificationIds: [ID!]
  markAllAsRead: Boolean
}

input UpdateNotificationSettingsInput {
  enablePush: Boolean
  enableEmail: Boolean
  enableDesktop: Boolean
  mutedWords: [String!]
  mutedUsers: [ID!]
}

# Push Subscription
input RegisterPushSubscriptionInput {
  endpoint: String!
  p256dh: String!
  auth: String!
  userAgent: String
}

input UnregisterPushSubscriptionInput {
  endpoint: String!
}

type PushSubscriptionPayload {
  success: Boolean!
  subscription: PushSubscription
}

type PushSubscription {
  id: ID!
  endpoint: String!
  createdAt: DateTime!
  lastUsedAt: DateTime
  userAgent: String
}
```

### 13.3. Subscription Types (SSE経由)

```graphql
type Subscription {
  # Timeline Updates
  timelineUpdates(filters: TimelineSubscriptionFilters): TimelineUpdate!
  
  # Drop Updates
  dropUpdates(dropId: ID!): DropUpdate!
  
  # Notification Stream
  notificationStream: NotificationUpdate!
  
  # User Status Updates
  userStatusUpdates(userIds: [ID!]!): UserStatusUpdate!
  
  # System Announcements
  systemAnnouncements: SystemAnnouncement!
}

input TimelineSubscriptionFilters {
  timelineType: TimelineType!
  includeReplies: Boolean
  includeRedrops: Boolean
}

type TimelineUpdate {
  type: TimelineUpdateType!
  item: TimelineItem
  removedId: ID
  position: TimelinePosition
}

enum TimelineUpdateType {
  ITEM_ADDED
  ITEM_UPDATED
  ITEM_REMOVED
  TIMELINE_CLEARED
}

type DropUpdate {
  type: DropUpdateType!
  drop: Drop!
  reaction: Reaction
  reply: Drop
}

enum DropUpdateType {
  CONTENT_UPDATED
  REACTION_ADDED
  REACTION_REMOVED
  REPLY_ADDED
  DELETED
}

type NotificationUpdate {
  type: NotificationUpdateType!
  notification: Notification
  unreadCount: Int!
}

enum NotificationUpdateType {
  NEW_NOTIFICATION
  NOTIFICATION_READ
  ALL_READ
}

type UserStatusUpdate {
  userId: ID!
  status: UserStatus!
  lastSeenAt: DateTime
}

enum UserStatus {
  ONLINE
  IDLE
  OFFLINE
  DO_NOT_DISTURB
}
```

## 14. Apollo Client Configuration

### 14.1. Client Setup

```typescript
import { ApolloClient, InMemoryCache, split } from '@apollo/client';
import { WebSocketLink } from '@apollo/client/link/ws';
import { getMainDefinition } from '@apollo/client/utilities';
import { createUploadLink } from 'apollo-upload-client';
import { setContext } from '@apollo/client/link/context';
import { onError } from '@apollo/client/link/error';
import { RetryLink } from '@apollo/client/link/retry';

// Auth Link
const authLink = setContext((_, { headers }) => {
  const token = localStorage.getItem('authToken');
  return {
    headers: {
      ...headers,
      authorization: token ? `Bearer ${token}` : "",
    }
  };
});

// Error Link
const errorLink = onError(({
  graphQLErrors,
  networkError,
  operation,
  forward
}) => {
  if (graphQLErrors) {
    graphQLErrors.forEach(({
      message,
      locations,
      path,
      extensions
    }) => {
      // Handle token expiration
      if (extensions?.code === 'UNAUTHENTICATED') {
        // Trigger token refresh
        return refreshToken().then(() => forward(operation));
      }
      
      clientLogger.error({
        message: 'GraphQL error',
        operation: operation.operationName,
        error: message,
        locations,
        path,
        code: extensions?.code,
      });
    });
  }
  
  if (networkError) {
    clientLogger.error({
      message: 'Network error',
      operation: operation.operationName,
      error: networkError.message,
    });
  }
});

// Retry Link
const retryLink = new RetryLink({
  delay: {
    initial: 300,
    max: Infinity,
    jitter: true
  },
  attempts: {
    max: 5,
    retryIf: (error, _operation) => {
      return !!error && (
        error.grpcCode === codes.Unavailable ||
        error.grpcCode === codes.DeadlineExceeded ||
        error.grpcCode === codes.ResourceExhausted
      );
    }
  }
});

// HTTP Link for uploads
const uploadLink = createUploadLink({
  uri: process.env.REACT_APP_GRAPHQL_ENDPOINT || 'https://api.avion.example/graphql',
  credentials: 'include',
});

// WebSocket Link for subscriptions (SSE fallback)
const wsLink = new WebSocketLink({
  uri: process.env.REACT_APP_WS_ENDPOINT || 'wss://api.avion.example/graphql',
  options: {
    reconnect: true,
    connectionParams: () => ({
      authToken: localStorage.getItem('authToken'),
    }),
  },
});

// Split Link
const splitLink = split(
  ({ query }) => {
    const definition = getMainDefinition(query);
    return (
      definition.kind === 'OperationDefinition' &&
      definition.operation === 'subscription'
    );
  },
  wsLink,
  uploadLink,
);

// Cache Configuration
const cache = new InMemoryCache({
  typePolicies: {
    Query: {
      fields: {
        homeTimeline: {
          keyArgs: false,
          merge(existing = { edges: [] }, incoming) {
            return {
              ...incoming,
              edges: [...existing.edges, ...incoming.edges],
            };
          },
        },
        notifications: {
          keyArgs: false,
          merge(existing = { edges: [] }, incoming) {
            return {
              ...incoming,
              edges: [...existing.edges, ...incoming.edges],
            };
          },
        },
      },
    },
    Drop: {
      fields: {
        reactions: {
          merge(existing, incoming) {
            return incoming;
          },
        },
      },
    },
    User: {
      keyFields: ['id'],
      fields: {
        relationships: {
          merge(existing, incoming) {
            return { ...existing, ...incoming };
          },
        },
      },
    },
  },
});

// Apollo Client
export const apolloClient = new ApolloClient({
  link: authLink.concat(errorLink).concat(retryLink).concat(splitLink),
  cache,
  defaultOptions: {
    watchQuery: {
      fetchPolicy: 'cache-and-network',
      nextFetchPolicy: 'cache-first',
    },
  },
});
```

### 14.2. Optimistic Updates

```typescript
// Drop作成の楽観的更新
const createDropWithOptimisticUpdate = async (
  content: string,
  options?: CreateDropOptions
) => {
  const tempId = `temp-${Date.now()}`;
  const optimisticDrop = {
    __typename: 'Drop',
    id: tempId,
    content,
    author: currentUser,
    createdAt: new Date().toISOString(),
    reactions: { edges: [], totalCount: 0 },
    repliesCount: 0,
    redropCount: 0,
    favoritesCount: 0,
    visibility: options?.visibility || 'PUBLIC',
    viewerContext: {
      hasReacted: false,
      hasRedropped: false,
      hasFavorited: false,
      canEdit: true,
      canDelete: true,
    },
  };
  
  try {
    const result = await apolloClient.mutate({
      mutation: CREATE_DROP_MUTATION,
      variables: { input: { content, ...options } },
      optimisticResponse: {
        createDrop: optimisticDrop,
      },
      update: (cache, { data }) => {
        if (!data?.createDrop) return;
        
        // Update home timeline
        const timeline = cache.readQuery({
          query: GET_HOME_TIMELINE_QUERY,
        });
        
        if (timeline) {
          cache.writeQuery({
            query: GET_HOME_TIMELINE_QUERY,
            data: {
              homeTimeline: {
                ...timeline.homeTimeline,
                edges: [
                  {
                    __typename: 'TimelineEdge',
                    cursor: tempId,
                    node: {
                      __typename: 'TimelineItem',
                      id: tempId,
                      type: 'DROP',
                      drop: data.createDrop,
                      insertedAt: new Date().toISOString(),
                    },
                  },
                  ...timeline.homeTimeline.edges,
                ],
              },
            },
          });
        }
      },
    });
    
    return result.data.createDrop;
  } catch (error) {
    // Rollback on error
    apolloClient.cache.evict({ id: `Drop:${tempId}` });
    throw error;
  }
};

// リアクション追加の楽観的更新
const addReactionWithOptimisticUpdate = async (
  dropId: string,
  emoji: string
) => {
  const optimisticReaction = {
    __typename: 'Reaction',
    id: `temp-reaction-${Date.now()}`,
    emoji,
    user: currentUser,
    createdAt: new Date().toISOString(),
  };
  
  return apolloClient.mutate({
    mutation: ADD_REACTION_MUTATION,
    variables: { input: { dropId, emoji } },
    optimisticResponse: {
      addReaction: {
        reaction: optimisticReaction,
        drop: {
          __typename: 'Drop',
          id: dropId,
          viewerContext: {
            hasReacted: true,
          },
        },
      },
    },
    update: (cache, { data }) => {
      if (!data?.addReaction) return;
      
      // Update drop's reaction count
      const dropId = cache.identify({
        __typename: 'Drop',
        id: dropId,
      });
      
      cache.modify({
        id: dropId,
        fields: {
          reactions(existing) {
            return {
              ...existing,
              totalCount: existing.totalCount + 1,
              edges: [
                {
                  __typename: 'ReactionEdge',
                  cursor: optimisticReaction.id,
                  node: optimisticReaction,
                },
                ...existing.edges,
              ],
            };
          },
        },
      });
    },
  });
};
```

## 15. SSE Client Implementation

### 15.1. SSE Connection Manager

```typescript
export class SSEConnectionManager {
  private connections: Map<string, EventSource> = new Map();
  private reconnectTimers: Map<string, NodeJS.Timeout> = new Map();
  private eventHandlers: Map<string, Set<EventHandler>> = new Map();
  private reconnectDelay = 1000;
  private maxReconnectDelay = 30000;
  private reconnectMultiplier = 1.5;
  
  constructor(
    private config: SSEConfig,
    private logger: ClientLogger
  ) {}
  
  connect(endpoint: string, options?: SSEConnectionOptions): SSEConnection {
    const url = new URL(endpoint, this.config.baseUrl);
    const token = this.getAuthToken();
    
    if (token) {
      url.searchParams.set('token', token);
    }
    
    if (options?.lastEventId) {
      url.searchParams.set('lastEventId', options.lastEventId);
    }
    
    const eventSource = new EventSource(url.toString());
    const connectionId = this.generateConnectionId();
    
    this.connections.set(connectionId, eventSource);
    this.setupEventHandlers(connectionId, eventSource, endpoint, options);
    
    return {
      id: connectionId,
      endpoint,
      status: 'connecting',
      close: () => this.disconnect(connectionId),
      addEventListener: (type: string, handler: EventHandler) => {
        this.addEventListener(connectionId, type, handler);
      },
      removeEventListener: (type: string, handler: EventHandler) => {
        this.removeEventListener(connectionId, type, handler);
      },
    };
  }
  
  private setupEventHandlers(
    connectionId: string,
    eventSource: EventSource,
    endpoint: string,
    options?: SSEConnectionOptions
  ) {
    eventSource.onopen = () => {
      this.logger.info({
        message: 'SSE connection opened',
        component: 'SSEConnectionManager',
        connectionId,
        endpoint,
      });
      
      // Reset reconnect delay on successful connection
      this.reconnectDelay = 1000;
      
      // Clear reconnect timer if exists
      const timer = this.reconnectTimers.get(connectionId);
      if (timer) {
        clearTimeout(timer);
        this.reconnectTimers.delete(connectionId);
      }
    };
    
    eventSource.onerror = (error) => {
      this.logger.error({
        message: 'SSE connection error',
        component: 'SSEConnectionManager',
        connectionId,
        endpoint,
        error: error.toString(),
      });
      
      // Attempt reconnection with exponential backoff
      this.scheduleReconnect(connectionId, endpoint, options);
    };
    
    eventSource.onmessage = (event) => {
      this.handleMessage(connectionId, event);
    };
    
    // Setup custom event listeners
    const eventTypes = [
      'timeline-update',
      'notification',
      'drop-update',
      'user-status',
      'system-announcement',
    ];
    
    eventTypes.forEach(type => {
      eventSource.addEventListener(type, (event) => {
        this.handleCustomEvent(connectionId, type, event);
      });
    });
  }
  
  private handleMessage(connectionId: string, event: MessageEvent) {
    try {
      const data = JSON.parse(event.data);
      
      this.logger.debug({
        message: 'SSE message received',
        component: 'SSEConnectionManager',
        connectionId,
        eventId: event.lastEventId,
        dataType: data.type,
      });
      
      // Store last event ID for reconnection
      if (event.lastEventId) {
        this.storeLastEventId(connectionId, event.lastEventId);
      }
      
      // Dispatch to registered handlers
      this.dispatchEvent(connectionId, 'message', data);
    } catch (error) {
      this.logger.error({
        message: 'Failed to parse SSE message',
        component: 'SSEConnectionManager',
        connectionId,
        error: error.message,
        rawData: event.data,
      });
    }
  }
  
  private handleCustomEvent(
    connectionId: string,
    type: string,
    event: Event
  ) {
    const messageEvent = event as MessageEvent;
    
    try {
      const data = JSON.parse(messageEvent.data);
      
      this.logger.debug({
        message: 'SSE custom event received',
        component: 'SSEConnectionManager',
        connectionId,
        eventType: type,
        eventId: messageEvent.lastEventId,
      });
      
      // Process based on event type
      switch (type) {
        case 'timeline-update':
          this.handleTimelineUpdate(data);
          break;
        case 'notification':
          this.handleNotification(data);
          break;
        case 'drop-update':
          this.handleDropUpdate(data);
          break;
        case 'user-status':
          this.handleUserStatus(data);
          break;
        case 'system-announcement':
          this.handleSystemAnnouncement(data);
          break;
      }
      
      // Dispatch to registered handlers
      this.dispatchEvent(connectionId, type, data);
    } catch (error) {
      this.logger.error({
        message: 'Failed to handle SSE custom event',
        component: 'SSEConnectionManager',
        connectionId,
        eventType: type,
        error: error.message,
      });
    }
  }
  
  private handleTimelineUpdate(data: TimelineUpdateData) {
    // Update Apollo cache
    apolloClient.cache.modify({
      fields: {
        homeTimeline(existing) {
          if (data.type === 'ITEM_ADDED') {
            return {
              ...existing,
              edges: [data.item, ...existing.edges],
            };
          }
          if (data.type === 'ITEM_REMOVED') {
            return {
              ...existing,
              edges: existing.edges.filter(
                edge => edge.node.id !== data.removedId
              ),
            };
          }
          return existing;
        },
      },
    });
  }
  
  private handleNotification(data: NotificationData) {
    // Update notification store
    notificationStore.addNotification(data);
    
    // Show browser notification if permitted
    if (Notification.permission === 'granted' && data.showDesktop) {
      new Notification(data.title, {
        body: data.body,
        icon: data.icon,
        tag: data.id,
      });
    }
  }
  
  private scheduleReconnect(
    connectionId: string,
    endpoint: string,
    options?: SSEConnectionOptions
  ) {
    // Clear existing timer
    const existingTimer = this.reconnectTimers.get(connectionId);
    if (existingTimer) {
      clearTimeout(existingTimer);
    }
    
    // Schedule new reconnection attempt
    const timer = setTimeout(() => {
      this.logger.info({
        message: 'Attempting SSE reconnection',
        component: 'SSEConnectionManager',
        connectionId,
        endpoint,
        delay: this.reconnectDelay,
      });
      
      // Close existing connection
      const connection = this.connections.get(connectionId);
      if (connection) {
        connection.close();
      }
      
      // Reconnect with last event ID
      const lastEventId = this.getLastEventId(connectionId);
      this.connect(endpoint, { ...options, lastEventId });
      
      // Increase delay for next attempt
      this.reconnectDelay = Math.min(
        this.reconnectDelay * this.reconnectMultiplier,
        this.maxReconnectDelay
      );
    }, this.reconnectDelay);
    
    this.reconnectTimers.set(connectionId, timer);
  }
  
  disconnect(connectionId: string) {
    const connection = this.connections.get(connectionId);
    if (connection) {
      connection.close();
      this.connections.delete(connectionId);
    }
    
    const timer = this.reconnectTimers.get(connectionId);
    if (timer) {
      clearTimeout(timer);
      this.reconnectTimers.delete(connectionId);
    }
    
    this.eventHandlers.delete(connectionId);
    
    this.logger.info({
      message: 'SSE connection closed',
      component: 'SSEConnectionManager',
      connectionId,
    });
  }
  
  disconnectAll() {
    this.connections.forEach((_, connectionId) => {
      this.disconnect(connectionId);
    });
  }
}
```

## 16. Service Worker Implementation

### 16.1. Service Worker Registration

```typescript
// src/serviceWorkerRegistration.ts
export async function register() {
  if (!('serviceWorker' in navigator)) {
    console.warn('Service Worker not supported');
    return;
  }
  
  try {
    const registration = await navigator.serviceWorker.register(
      '/service-worker.js',
      { scope: '/' }
    );
    
    console.log('Service Worker registered:', registration);
    
    // Check for updates periodically
    setInterval(() => {
      registration.update();
    }, 60 * 60 * 1000); // Every hour
    
    // Handle updates
    registration.addEventListener('updatefound', () => {
      const newWorker = registration.installing;
      if (!newWorker) return;
      
      newWorker.addEventListener('statechange', () => {
        if (
          newWorker.state === 'installed' &&
          navigator.serviceWorker.controller
        ) {
          // New service worker available
          if (confirm('New version available! Reload to update?')) {
            window.location.reload();
          }
        }
      });
    });
    
    return registration;
  } catch (error) {
    console.error('Service Worker registration failed:', error);
    throw error;
  }
}
```

### 16.2. Service Worker Implementation

```javascript
// public/service-worker.js
import { precacheAndRoute } from 'workbox-precaching';
import { registerRoute } from 'workbox-routing';
import {
  NetworkFirst,
  StaleWhileRevalidate,
  CacheFirst,
} from 'workbox-strategies';
import { ExpirationPlugin } from 'workbox-expiration';
import { CacheableResponsePlugin } from 'workbox-cacheable-response';

// Precache all static assets
precacheAndRoute(self.__WB_MANIFEST);

// Cache strategies
const ONE_HOUR = 60 * 60;
const ONE_DAY = 24 * ONE_HOUR;
const ONE_WEEK = 7 * ONE_DAY;

// API GraphQL responses - Network First
registerRoute(
  ({ url }) => url.pathname === '/graphql',
  new NetworkFirst({
    cacheName: 'api-cache',
    networkTimeoutSeconds: 5,
    plugins: [
      new CacheableResponsePlugin({
        statuses: [0, 200],
      }),
      new ExpirationPlugin({
        maxEntries: 50,
        maxAgeSeconds: 5 * 60, // 5 minutes
      }),
    ],
  }),
  'POST'
);

// Media assets - Cache First
registerRoute(
  ({ request }) => request.destination === 'image',
  new CacheFirst({
    cacheName: 'media-cache',
    plugins: [
      new CacheableResponsePlugin({
        statuses: [0, 200],
      }),
      new ExpirationPlugin({
        maxEntries: 100,
        maxAgeSeconds: ONE_WEEK,
        purgeOnQuotaError: true,
      }),
    ],
  })
);

// Static assets - Stale While Revalidate
registerRoute(
  ({ request }) =>
    request.destination === 'style' ||
    request.destination === 'script' ||
    request.destination === 'font',
  new StaleWhileRevalidate({
    cacheName: 'static-cache',
    plugins: [
      new CacheableResponsePlugin({
        statuses: [0, 200],
      }),
      new ExpirationPlugin({
        maxEntries: 30,
        maxAgeSeconds: ONE_DAY,
      }),
    ],
  })
);

// Push notifications
self.addEventListener('push', (event) => {
  const data = event.data?.json() || {};
  
  const options = {
    body: data.body || 'New notification',
    icon: data.icon || '/icon-192.png',
    badge: data.badge || '/badge-72.png',
    vibrate: data.vibrate || [200, 100, 200],
    data: data.data || {},
    actions: data.actions || [],
    tag: data.tag || 'default',
    renotify: data.renotify || false,
    requireInteraction: data.requireInteraction || false,
  };
  
  event.waitUntil(
    self.registration.showNotification(
      data.title || 'Avion',
      options
    )
  );
});

// Notification click handler
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  
  const action = event.action;
  const notification = event.notification;
  const data = notification.data || {};
  
  let url = '/';
  
  if (action === 'view') {
    url = data.url || '/';
  } else if (action === 'dismiss') {
    return;
  } else {
    // Default action
    url = data.url || '/';
  }
  
  event.waitUntil(
    clients.matchAll({ type: 'window' }).then((clientList) => {
      // Check if there's already a window/tab open
      for (const client of clientList) {
        if (client.url === url && 'focus' in client) {
          return client.focus();
        }
      }
      // Open new window if not found
      if (clients.openWindow) {
        return clients.openWindow(url);
      }
    })
  );
});

// Background sync for offline actions
self.addEventListener('sync', (event) => {
  if (event.tag === 'sync-drops') {
    event.waitUntil(syncOfflineDrops());
  } else if (event.tag === 'sync-reactions') {
    event.waitUntil(syncOfflineReactions());
  }
});

async function syncOfflineDrops() {
  const cache = await caches.open('offline-drops');
  const requests = await cache.keys();
  
  for (const request of requests) {
    try {
      const response = await fetch(request);
      if (response.ok) {
        await cache.delete(request);
      }
    } catch (error) {
      console.error('Failed to sync drop:', error);
    }
  }
}

async function syncOfflineReactions() {
  const cache = await caches.open('offline-reactions');
  const requests = await cache.keys();
  
  for (const request of requests) {
    try {
      const response = await fetch(request);
      if (response.ok) {
        await cache.delete(request);
      }
    } catch (error) {
      console.error('Failed to sync reaction:', error);
    }
  }
}

// Skip waiting and claim clients
self.addEventListener('message', (event) => {
  if (event.data?.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

self.addEventListener('activate', (event) => {
  event.waitUntil(clients.claim());
});
```

## 17. Concerns / Open Questions (懸念事項・相談したいこと)

### 技術的負債リスク
- **バンドルサイズ:** 大規模SPAによる初期ロード時間への影響
- **メモリ管理:** 長時間のSSE接続とSPA状態管理によるメモリ使用量
- **型の同期:** Gateway GraphQLスキーマとクライアント型定義の同期

### 未決定事項
- 状態管理ライブラリの最終選定（Zustand vs Jotai）
- GraphQLクライアントの選定（Apollo vs urql）
- UIコンポーネントライブラリの詳細
- キャッシュ無効化戦略の詳細設計
- 将来的なSEO対応の必要性と実装方法

## 18. React Component Architecture

### 18.1. Component Hierarchy

```typescript
// App Component Structure
App
├── Providers
│   ├── ApolloProvider
│   ├── AuthProvider
│   ├── ThemeProvider
│   ├── NotificationProvider
│   └── SSEProvider
├── Router
│   ├── PublicRoute
│   ├── PrivateRoute
│   └── OAuthRoute
├── Layout
│   ├── Header
│   │   ├── Navigation
│   │   ├── SearchBar
│   │   ├── NotificationBell
│   │   └── UserMenu
│   ├── Sidebar
│   │   ├── NavigationMenu
│   │   ├── TrendingSection
│   │   └── FooterLinks
│   └── MainContent
└── ErrorBoundary
```

### 18.2. Core Components

```typescript
// Timeline Component
export const Timeline: React.FC<TimelineProps> = ({
  type = 'home',
  filters,
  onLoadMore,
}) => {
  const { data, loading, error, fetchMore } = useQuery(
    GET_TIMELINE_QUERY,
    {
      variables: { type, first: 20, filters },
      notifyOnNetworkStatusChange: true,
    }
  );
  
  const [optimisticDrops, setOptimisticDrops] = useState<Drop[]>([]);
  const observerRef = useInfiniteScroll(onLoadMore);
  
  // Subscribe to real-time updates
  useSSESubscription('timeline-update', (event) => {
    if (event.type === 'ITEM_ADDED') {
      setOptimisticDrops(prev => [event.item, ...prev]);
    }
  });
  
  if (loading && !data) return <TimelineSkeleton />;
  if (error) return <ErrorMessage error={error} />;
  
  const items = [
    ...optimisticDrops,
    ...(data?.timeline?.edges || []).map(edge => edge.node),
  ];
  
  return (
    <div className="timeline">
      <TimelineHeader type={type} filters={filters} />
      <VirtualList
        items={items}
        renderItem={(item) => (
          <TimelineItem key={item.id} item={item} />
        )}
        onEndReached={fetchMore}
        endReachedThreshold={0.8}
      />
      <div ref={observerRef} />
    </div>
  );
};

// Drop Component with Reactions
export const DropCard: React.FC<DropCardProps> = ({ drop }) => {
  const [addReaction] = useMutation(ADD_REACTION_MUTATION);
  const [isExpanded, setIsExpanded] = useState(false);
  const { user } = useAuth();
  
  const handleReaction = useCallback(async (emoji: string) => {
    try {
      await addReaction({
        variables: { dropId: drop.id, emoji },
        optimisticResponse: {
          addReaction: {
            __typename: 'ReactionPayload',
            reaction: {
              __typename: 'Reaction',
              id: `temp-${Date.now()}`,
              emoji,
              user,
              createdAt: new Date().toISOString(),
            },
            drop: {
              ...drop,
              viewerContext: {
                ...drop.viewerContext,
                hasReacted: true,
              },
            },
          },
        },
      });
    } catch (error) {
      toast.error('Failed to add reaction');
    }
  }, [drop.id, user]);
  
  return (
    <Card className="drop-card">
      <CardHeader>
        <UserAvatar user={drop.author} />
        <div className="user-info">
          <Link to={`/users/${drop.author.username}`}>
            {drop.author.displayName}
          </Link>
          <span className="username">@{drop.author.username}</span>
        </div>
        <DropMenu drop={drop} />
      </CardHeader>
      
      <CardContent>
        <DropContent
          content={drop.content}
          expanded={isExpanded}
          onToggle={() => setIsExpanded(!isExpanded)}
        />
        {drop.media.length > 0 && (
          <MediaGallery media={drop.media} />
        )}
      </CardContent>
      
      <CardFooter>
        <ReactionPicker
          reactions={drop.reactions}
          onReaction={handleReaction}
          hasReacted={drop.viewerContext.hasReacted}
        />
        <DropActions drop={drop} />
      </CardFooter>
    </Card>
  );
};

// Notification Component
export const NotificationList: React.FC = () => {
  const { data, loading, error, fetchMore } = useQuery(
    GET_NOTIFICATIONS_QUERY,
    { variables: { first: 20 } }
  );
  
  const [markAsRead] = useMutation(MARK_AS_READ_MUTATION);
  
  // Auto-mark as read when viewed
  useEffect(() => {
    if (data?.notifications?.edges) {
      const unreadIds = data.notifications.edges
        .filter(edge => !edge.node.isRead)
        .map(edge => edge.node.id);
      
      if (unreadIds.length > 0) {
        markAsRead({ variables: { ids: unreadIds } });
      }
    }
  }, [data]);
  
  if (loading) return <NotificationSkeleton />;
  if (error) return <ErrorMessage error={error} />;
  
  return (
    <div className="notification-list">
      <NotificationHeader
        unreadCount={data?.notifications?.unreadCount || 0}
      />
      {data?.notifications?.edges.map(({ node }) => (
        <NotificationItem
          key={node.id}
          notification={node}
        />
      ))}
      {data?.notifications?.pageInfo.hasNextPage && (
        <LoadMoreButton onClick={() => fetchMore()} />
      )}
    </div>
  );
};
```

### 18.3. Custom Hooks

```typescript
// useAuth Hook
export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};

// useSSE Hook
export const useSSESubscription = (
  eventType: string,
  handler: (event: SSEEvent) => void
) => {
  const { connection } = useSSE();
  
  useEffect(() => {
    if (!connection) return;
    
    connection.addEventListener(eventType, handler);
    
    return () => {
      connection.removeEventListener(eventType, handler);
    };
  }, [connection, eventType, handler]);
};

// useInfiniteScroll Hook
export const useInfiniteScroll = (
  callback: () => void,
  options?: IntersectionObserverInit
) => {
  const observerRef = useRef<HTMLDivElement>(null);
  
  useEffect(() => {
    if (!observerRef.current) return;
    
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting) {
          callback();
        }
      },
      { threshold: 0.1, ...options }
    );
    
    observer.observe(observerRef.current);
    
    return () => observer.disconnect();
  }, [callback]);
  
  return observerRef;
};

// useOptimisticUpdate Hook
export const useOptimisticUpdate = <T>(
  initialValue: T
): [T, (update: Partial<T>) => void, () => void] => {
  const [value, setValue] = useState(initialValue);
  const [backup, setBackup] = useState(initialValue);
  
  const update = useCallback((update: Partial<T>) => {
    setBackup(value);
    setValue(prev => ({ ...prev, ...update }));
  }, [value]);
  
  const rollback = useCallback(() => {
    setValue(backup);
  }, [backup]);
  
  return [value, update, rollback];
};

// useDebounce Hook
export const useDebounce = <T>(
  value: T,
  delay: number
): T => {
  const [debouncedValue, setDebouncedValue] = useState(value);
  
  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);
    
    return () => clearTimeout(timer);
  }, [value, delay]);
  
  return debouncedValue;
};

// useLocalStorage Hook
export const useLocalStorage = <T>(
  key: string,
  initialValue: T
): [T, (value: T) => void] => {
  const [storedValue, setStoredValue] = useState<T>(() => {
    try {
      const item = window.localStorage.getItem(key);
      return item ? JSON.parse(item) : initialValue;
    } catch (error) {
      console.error(`Error reading localStorage key "${key}":`, error);
      return initialValue;
    }
  });
  
  const setValue = useCallback((value: T) => {
    try {
      setStoredValue(value);
      window.localStorage.setItem(key, JSON.stringify(value));
    } catch (error) {
      console.error(`Error setting localStorage key "${key}":`, error);
    }
  }, [key]);
  
  return [storedValue, setValue];
};
```

### 18.4. Screen Transitions and UI/UX Design

詳細な画面遷移設計とUI/UXフローについては、以下のドキュメントを参照してください：

- **[包括的画面遷移設計](./comprehensive-screen-transitions.md)**: 全体的な画面遷移設計と不足しているユースケースの実装ガイド
  - 認証・セキュリティフロー（MFA、セッション管理、Bot管理）
  - ユーザープロフィール・ソーシャル機能の詳細設計
  - コンテンツ作成・管理機能（Poll、予約投稿、下書き管理）
  - タイムライン・ディスカバリー機能
  - コミュニティ管理機能
  - モデレーション・安全性機能
  - メディア管理機能
  - 通知システム
  - フェデレーション・ActivityPub機能
  - システム管理機能

- **[ユーザープロフィール・ソーシャル画面遷移](./user-profile-social-screen-transitions.md)**: プロフィール管理とソーシャル機能の詳細な画面設計
  - カスタムフィールド編集
  - ウェブサイト検証フロー
  - フォローシステム管理
  - ユーザーリスト機能
  - ブロック・ミュートシステム
  - データ管理（エクスポート/インポート、アカウント削除）

- **[画面遷移設計ドキュメント](./screen-transitions-design.md)**: コンテンツ作成とコミュニティ機能の画面設計
  - 高度な投稿機能（Poll作成、予約投稿）
  - ブックマークシステム
  - メディア管理
  - タイムライン機能
  - コミュニティ管理
  - モデレーションシステム
  - ディスカバリー機能
  - 管理者機能

これらのドキュメントは、Container-Presentationパターンに従い、DDDの原則とCQRSアーキテクチャを実装しています。各画面遷移は`.cursor/rules`の仕様に完全準拠して設計されています。

## 19. State Management with Zustand

### 19.1. Store Configuration

```typescript
import { create } from 'zustand';
import { devtools, persist } from 'zustand/middleware';
import { immer } from 'zustand/middleware/immer';

// Auth Store
interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  login: (credentials: LoginCredentials) => Promise<void>;
  logout: () => Promise<void>;
  refreshToken: () => Promise<void>;
  updateUser: (user: Partial<User>) => void;
}

export const useAuthStore = create<AuthState>()(
  devtools(
    persist(
      immer((set, get) => ({
        user: null,
        token: null,
        isAuthenticated: false,
        
        login: async (credentials) => {
          try {
            const response = await authService.login(credentials);
            set(state => {
              state.user = response.user;
              state.token = response.token;
              state.isAuthenticated = true;
            });
            
            // Set Apollo Client auth header
            apolloClient.setLink(
              setContext((_, { headers }) => ({
                headers: {
                  ...headers,
                  authorization: `Bearer ${response.token}`,
                },
              }))
            );
          } catch (error) {
            console.error('Login failed:', error);
            throw error;
          }
        },
        
        logout: async () => {
          try {
            await authService.logout();
            set(state => {
              state.user = null;
              state.token = null;
              state.isAuthenticated = false;
            });
            
            // Clear Apollo cache
            apolloClient.clearStore();
          } catch (error) {
            console.error('Logout failed:', error);
          }
        },
        
        refreshToken: async () => {
          const currentToken = get().token;
          if (!currentToken) return;
          
          try {
            const response = await authService.refresh(currentToken);
            set(state => {
              state.token = response.token;
            });
          } catch (error) {
            console.error('Token refresh failed:', error);
            get().logout();
          }
        },
        
        updateUser: (updates) => {
          set(state => {
            if (state.user) {
              Object.assign(state.user, updates);
            }
          });
        },
      })),
      {
        name: 'auth-storage',
        partialize: (state) => ({
          token: state.token,
          user: state.user,
        }),
      }
    )
  )
);

// UI Store
interface UIState {
  theme: 'light' | 'dark' | 'system';
  sidebarOpen: boolean;
  modalStack: Modal[];
  toasts: Toast[];
  setTheme: (theme: 'light' | 'dark' | 'system') => void;
  toggleSidebar: () => void;
  openModal: (modal: Modal) => void;
  closeModal: (id: string) => void;
  showToast: (toast: Omit<Toast, 'id'>) => void;
  dismissToast: (id: string) => void;
}

export const useUIStore = create<UIState>()(
  devtools(
    immer((set) => ({
      theme: 'system',
      sidebarOpen: true,
      modalStack: [],
      toasts: [],
      
      setTheme: (theme) => {
        set(state => {
          state.theme = theme;
        });
        
        // Apply theme to document
        if (theme === 'dark' || 
            (theme === 'system' && 
             window.matchMedia('(prefers-color-scheme: dark)').matches)) {
          document.documentElement.classList.add('dark');
        } else {
          document.documentElement.classList.remove('dark');
        }
      },
      
      toggleSidebar: () => {
        set(state => {
          state.sidebarOpen = !state.sidebarOpen;
        });
      },
      
      openModal: (modal) => {
        set(state => {
          state.modalStack.push({
            ...modal,
            id: modal.id || `modal-${Date.now()}`,
          });
        });
      },
      
      closeModal: (id) => {
        set(state => {
          state.modalStack = state.modalStack.filter(m => m.id !== id);
        });
      },
      
      showToast: (toast) => {
        const id = `toast-${Date.now()}`;
        set(state => {
          state.toasts.push({ ...toast, id });
        });
        
        // Auto dismiss after duration
        if (toast.duration !== Infinity) {
          setTimeout(() => {
            set(state => {
              state.toasts = state.toasts.filter(t => t.id !== id);
            });
          }, toast.duration || 5000);
        }
      },
      
      dismissToast: (id) => {
        set(state => {
          state.toasts = state.toasts.filter(t => t.id !== id);
        });
      },
    }))
  )
);

// Timeline Store
interface TimelineState {
  timelines: Record<string, TimelineData>;
  activeTimeline: string;
  filters: TimelineFilters;
  loadTimeline: (type: string) => Promise<void>;
  appendItems: (type: string, items: TimelineItem[]) => void;
  prependItems: (type: string, items: TimelineItem[]) => void;
  removeItem: (type: string, itemId: string) => void;
  setFilters: (filters: Partial<TimelineFilters>) => void;
  clearTimeline: (type: string) => void;
}

export const useTimelineStore = create<TimelineState>()(
  devtools(
    immer((set, get) => ({
      timelines: {},
      activeTimeline: 'home',
      filters: {
        includeReplies: true,
        includeRedrops: true,
        onlyMedia: false,
        languages: [],
      },
      
      loadTimeline: async (type) => {
        try {
          const response = await timelineService.getTimeline(
            type,
            get().filters
          );
          
          set(state => {
            state.timelines[type] = response;
            state.activeTimeline = type;
          });
        } catch (error) {
          console.error('Failed to load timeline:', error);
          throw error;
        }
      },
      
      appendItems: (type, items) => {
        set(state => {
          if (!state.timelines[type]) {
            state.timelines[type] = {
              items: [],
              hasMore: true,
              cursor: null,
            };
          }
          state.timelines[type].items.push(...items);
        });
      },
      
      prependItems: (type, items) => {
        set(state => {
          if (!state.timelines[type]) {
            state.timelines[type] = {
              items: [],
              hasMore: true,
              cursor: null,
            };
          }
          state.timelines[type].items.unshift(...items);
        });
      },
      
      removeItem: (type, itemId) => {
        set(state => {
          if (state.timelines[type]) {
            state.timelines[type].items = 
              state.timelines[type].items.filter(item => item.id !== itemId);
          }
        });
      },
      
      setFilters: (filters) => {
        set(state => {
          Object.assign(state.filters, filters);
        });
      },
      
      clearTimeline: (type) => {
        set(state => {
          delete state.timelines[type];
        });
      },
    }))
  )
);
```

## 20. Performance Optimization

### 20.1. Code Splitting

```typescript
import { lazy, Suspense } from 'react';
import { Routes, Route } from 'react-router-dom';

// Lazy load route components
const Timeline = lazy(() => import('./pages/Timeline'));
const Profile = lazy(() => import('./pages/Profile'));
const Settings = lazy(() => import('./pages/Settings'));
const Notifications = lazy(() => import('./pages/Notifications'));
const Search = lazy(() => import('./pages/Search'));
const DropDetail = lazy(() => import('./pages/DropDetail'));
const OAuthConsent = lazy(() => import('./pages/OAuthConsent'));

export const AppRoutes = () => {
  return (
    <Suspense fallback={<PageLoader />}>
      <Routes>
        <Route path="/" element={<Timeline />} />
        <Route path="/home" element={<Timeline type="home" />} />
        <Route path="/local" element={<Timeline type="local" />} />
        <Route path="/global" element={<Timeline type="global" />} />
        <Route path="/notifications" element={<Notifications />} />
        <Route path="/search" element={<Search />} />
        <Route path="/users/:username" element={<Profile />} />
        <Route path="/drops/:id" element={<DropDetail />} />
        <Route path="/settings/*" element={<Settings />} />
        <Route path="/consent" element={<OAuthConsent />} />
      </Routes>
    </Suspense>
  );
};
```

### 20.2. Virtual Scrolling

```typescript
import { VirtualList } from '@tanstack/react-virtual';

export const VirtualTimeline: React.FC<VirtualTimelineProps> = ({
  items,
  renderItem,
  onEndReached,
}) => {
  const parentRef = useRef<HTMLDivElement>(null);
  
  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 150, // Estimated item height
    overscan: 5,
  });
  
  // Trigger load more when near end
  useEffect(() => {
    const [lastItem] = virtualizer.getVirtualItems().slice(-1);
    
    if (
      lastItem &&
      lastItem.index >= items.length - 5 &&
      onEndReached
    ) {
      onEndReached();
    }
  }, [virtualizer.getVirtualItems(), items.length, onEndReached]);
  
  return (
    <div ref={parentRef} className="virtual-timeline">
      <div
        style={{
          height: `${virtualizer.getTotalSize()}px`,
          width: '100%',
          position: 'relative',
        }}
      >
        {virtualizer.getVirtualItems().map((virtualItem) => (
          <div
            key={virtualItem.key}
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              width: '100%',
              height: `${virtualItem.size}px`,
              transform: `translateY(${virtualItem.start}px)`,
            }}
          >
            {renderItem(items[virtualItem.index], virtualItem.index)}
          </div>
        ))}
      </div>
    </div>
  );
};
```

### 20.3. Image Optimization

```typescript
export const OptimizedImage: React.FC<OptimizedImageProps> = ({
  src,
  alt,
  width,
  height,
  blurhash,
  className,
}) => {
  const [isLoaded, setIsLoaded] = useState(false);
  const [error, setError] = useState(false);
  const imgRef = useRef<HTMLImageElement>(null);
  
  // Use Intersection Observer for lazy loading
  useEffect(() => {
    if (!imgRef.current) return;
    
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting) {
          // Start loading the image
          const img = new Image();
          img.src = src;
          img.onload = () => setIsLoaded(true);
          img.onerror = () => setError(true);
        }
      },
      { threshold: 0.01 }
    );
    
    observer.observe(imgRef.current);
    
    return () => observer.disconnect();
  }, [src]);
  
  if (error) {
    return (
      <div className={`image-error ${className}`}>
        <ImageIcon />
        <span>Failed to load image</span>
      </div>
    );
  }
  
  return (
    <div className={`optimized-image ${className}`}>
      {blurhash && !isLoaded && (
        <Blurhash
          hash={blurhash}
          width={width}
          height={height}
          className="blurhash-placeholder"
        />
      )}
      <img
        ref={imgRef}
        src={isLoaded ? src : undefined}
        alt={alt}
        width={width}
        height={height}
        loading="lazy"
        decoding="async"
        className={`actual-image ${isLoaded ? 'loaded' : ''}`}
      />
    </div>
  );
};
```

### 20.4. Memo and Callback Optimization

```typescript
// Memoized Drop Component
export const MemoizedDrop = React.memo<DropProps>(
  ({ drop, onReaction, onReply }) => {
    // Heavy computation memoized
    const processedContent = useMemo(
      () => processDropContent(drop.content),
      [drop.content]
    );
    
    // Callbacks memoized
    const handleReaction = useCallback(
      (emoji: string) => {
        onReaction(drop.id, emoji);
      },
      [drop.id, onReaction]
    );
    
    const handleReply = useCallback(() => {
      onReply(drop.id);
    }, [drop.id, onReply]);
    
    return (
      <DropCard
        drop={drop}
        content={processedContent}
        onReaction={handleReaction}
        onReply={handleReply}
      />
    );
  },
  // Custom comparison function
  (prevProps, nextProps) => {
    return (
      prevProps.drop.id === nextProps.drop.id &&
      prevProps.drop.updatedAt === nextProps.drop.updatedAt &&
      prevProps.drop.reactions.totalCount === 
        nextProps.drop.reactions.totalCount
    );
  }
);
```

## 21. Service-Specific Test Strategy

### 21.1. Overview

The avion-web frontend requires comprehensive testing covering GraphQL integration, PWA functionality, performance metrics, and user interactions. Testing follows a pyramid approach with extensive unit tests, focused integration tests, and critical E2E scenarios.

#### Testing Philosophy
- **Test-Driven Development**: Write tests before implementation
- **Real-World Scenarios**: Test actual user workflows
- **Performance First**: Validate Core Web Vitals and bundle sizes
- **Offline Resilience**: Ensure PWA functionality works reliably
- **GraphQL Integration**: Mock and test Apollo Client interactions

### 21.2. GraphQL Integration Testing

#### 21.2.1. Apollo Client Mock Setup

```typescript
// tests/utils/apollo-mock.ts
import { MockedProvider } from '@apollo/client/testing';
import { GraphQLError } from 'graphql';
import { GET_TIMELINE, CREATE_DROP } from '../src/graphql/queries';

export const createMockProvider = (mocks: any[] = []) => {
  return ({ children }: { children: React.ReactNode }) => (
    <MockedProvider mocks={mocks} addTypename={false}>
      {children}
    </MockedProvider>
  );
};

// Example mock for timeline query
export const timelineMock = {
  request: {
    query: GET_TIMELINE,
    variables: { first: 20, after: null },
  },
  result: {
    data: {
      timeline: {
        edges: [
          {
            node: {
              id: 'drop-1',
              content: 'Test drop content',
              author: { id: 'user-1', username: 'testuser' },
              createdAt: '2024-01-01T00:00:00Z',
              reactions: { totalCount: 5 },
            },
            cursor: 'cursor-1',
          },
        ],
        pageInfo: {
          hasNextPage: true,
          endCursor: 'cursor-1',
        },
      },
    },
  },
};

// Error mock for testing error boundaries
export const timelineErrorMock = {
  request: {
    query: GET_TIMELINE,
    variables: { first: 20, after: null },
  },
  error: new GraphQLError('Network error occurred'),
};
```

#### 21.2.2. Optimistic Updates Testing

```typescript
// tests/components/CreateDrop.test.tsx
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { CreateDrop } from '../../src/components/CreateDrop';
import { createMockProvider } from '../utils/apollo-mock';

describe('CreateDrop Optimistic Updates', () => {
  test('should show optimistic drop immediately', async () => {
    const createDropMock = {
      request: {
        query: CREATE_DROP,
        variables: { content: 'New drop content' },
      },
      result: {
        data: {
          createDrop: {
            id: 'new-drop-id',
            content: 'New drop content',
            author: { id: 'current-user', username: 'me' },
            createdAt: '2024-01-01T00:00:00Z',
          },
        },
      },
      delay: 1000, // Simulate network delay
    };

    const MockProvider = createMockProvider([createDropMock]);
    
    render(
      <MockProvider>
        <CreateDrop />
      </MockProvider>
    );

    // Type and submit
    const textarea = screen.getByRole('textbox');
    fireEvent.change(textarea, { target: { value: 'New drop content' } });
    fireEvent.click(screen.getByRole('button', { name: /post/i }));

    // Should show optimistic update immediately
    expect(screen.getByText('New drop content')).toBeInTheDocument();
    expect(screen.getByText('Posting...')).toBeInTheDocument();

    // Wait for actual response
    await waitFor(() => {
      expect(screen.queryByText('Posting...')).not.toBeInTheDocument();
    });
  });

  test('should handle optimistic update rollback on error', async () => {
    const failedCreateMock = {
      request: {
        query: CREATE_DROP,
        variables: { content: 'Failed drop' },
      },
      error: new GraphQLError('Creation failed'),
    };

    const MockProvider = createMockProvider([failedCreateMock]);
    
    render(
      <MockProvider>
        <CreateDrop />
      </MockProvider>
    );

    const textarea = screen.getByRole('textbox');
    fireEvent.change(textarea, { target: { value: 'Failed drop' } });
    fireEvent.click(screen.getByRole('button', { name: /post/i }));

    // Optimistic update appears
    expect(screen.getByText('Failed drop')).toBeInTheDocument();

    // Wait for rollback
    await waitFor(() => {
      expect(screen.queryByText('Failed drop')).not.toBeInTheDocument();
      expect(screen.getByText(/failed to post/i)).toBeInTheDocument();
    });
  });
});
```

#### 21.2.3. Cache Invalidation Testing

```typescript
// tests/hooks/useTimelineCache.test.ts
import { renderHook, act } from '@testing-library/react';
import { useTimelineCache } from '../../src/hooks/useTimelineCache';
import { createMockProvider } from '../utils/apollo-mock';

describe('Timeline Cache Management', () => {
  test('should invalidate cache on new drop creation', async () => {
    const MockProvider = createMockProvider([timelineMock]);
    
    const { result } = renderHook(() => useTimelineCache(), {
      wrapper: MockProvider,
    });

    // Initial load
    await act(async () => {
      await result.current.fetchTimeline();
    });

    expect(result.current.drops).toHaveLength(1);

    // Simulate new drop creation
    act(() => {
      result.current.invalidateTimeline();
    });

    expect(result.current.isStale).toBe(true);
  });

  test('should merge cached data with new pagination', async () => {
    const page1Mock = { ...timelineMock };
    const page2Mock = {
      request: {
        query: GET_TIMELINE,
        variables: { first: 20, after: 'cursor-1' },
      },
      result: {
        data: {
          timeline: {
            edges: [
              {
                node: {
                  id: 'drop-2',
                  content: 'Second drop',
                  author: { id: 'user-2', username: 'user2' },
                  createdAt: '2024-01-01T01:00:00Z',
                  reactions: { totalCount: 3 },
                },
                cursor: 'cursor-2',
              },
            ],
            pageInfo: {
              hasNextPage: false,
              endCursor: 'cursor-2',
            },
          },
        },
      },
    };

    const MockProvider = createMockProvider([page1Mock, page2Mock]);
    
    const { result } = renderHook(() => useTimelineCache(), {
      wrapper: MockProvider,
    });

    // Load first page
    await act(async () => {
      await result.current.fetchTimeline();
    });

    expect(result.current.drops).toHaveLength(1);

    // Load second page
    await act(async () => {
      await result.current.fetchMore();
    });

    expect(result.current.drops).toHaveLength(2);
    expect(result.current.hasNextPage).toBe(false);
  });
});
```

### 21.3. PWA Functionality Testing

#### 21.3.1. Service Worker Update Testing

```typescript
// tests/pwa/service-worker.test.ts
import { setupWorker } from 'msw';
import { rest } from 'msw';

// Mock service worker for testing
const worker = setupWorker(
  rest.get('/api/timeline', (req, res, ctx) => {
    return res(ctx.json({ drops: [] }));
  })
);

describe('Service Worker Updates', () => {
  beforeAll(() => worker.listen());
  afterEach(() => worker.resetHandlers());
  afterAll(() => worker.close());

  test('should detect service worker updates', async () => {
    // Mock service worker registration
    const mockRegistration = {
      waiting: {
        postMessage: jest.fn(),
        addEventListener: jest.fn(),
      },
      addEventListener: jest.fn(),
      update: jest.fn(),
    };

    Object.defineProperty(navigator, 'serviceWorker', {
      value: {
        register: jest.fn().mockResolvedValue(mockRegistration),
        ready: Promise.resolve(mockRegistration),
        addEventListener: jest.fn(),
      },
      writable: true,
    });

    const { useServiceWorkerUpdate } = await import('../../src/hooks/useServiceWorkerUpdate');
    const { result } = renderHook(() => useServiceWorkerUpdate());

    // Simulate update available
    act(() => {
      const updateAvailableCallback = mockRegistration.addEventListener.mock.calls
        .find(call => call[0] === 'updatefound')?.[1];
      updateAvailableCallback?.();
    });

    expect(result.current.updateAvailable).toBe(true);

    // Test skip waiting
    act(() => {
      result.current.skipWaiting();
    });

    expect(mockRegistration.waiting.postMessage).toHaveBeenCalledWith({
      type: 'SKIP_WAITING',
    });
  });

  test('should handle offline mode gracefully', async () => {
    // Mock offline state
    Object.defineProperty(navigator, 'onLine', {
      value: false,
      writable: true,
    });

    const { useOfflineMode } = await import('../../src/hooks/useOfflineMode');
    const { result } = renderHook(() => useOfflineMode());

    expect(result.current.isOffline).toBe(true);

    // Simulate going online
    act(() => {
      Object.defineProperty(navigator, 'onLine', { value: true });
      window.dispatchEvent(new Event('online'));
    });

    expect(result.current.isOffline).toBe(false);
  });
});
```

#### 21.3.2. Push Notification Testing

```typescript
// tests/pwa/push-notifications.test.ts
import { render, screen, fireEvent } from '@testing-library/react';
import { PushNotificationManager } from '../../src/components/PushNotificationManager';

describe('Push Notifications', () => {
  beforeEach(() => {
    // Mock Notification API
    global.Notification = {
      permission: 'default',
      requestPermission: jest.fn().mockResolvedValue('granted'),
    } as any;

    // Mock Push API
    global.navigator.serviceWorker = {
      ready: Promise.resolve({
        pushManager: {
          subscribe: jest.fn().mockResolvedValue({
            endpoint: 'https://fcm.googleapis.com/fcm/send/test',
            getKey: jest.fn().mockReturnValue(new ArrayBuffer(8)),
          }),
          getSubscription: jest.fn().mockResolvedValue(null),
        },
      }),
    } as any;
  });

  test('should request notification permission', async () => {
    render(<PushNotificationManager />);

    const enableButton = screen.getByRole('button', { name: /enable notifications/i });
    fireEvent.click(enableButton);

    await waitFor(() => {
      expect(Notification.requestPermission).toHaveBeenCalled();
    });
  });

  test('should subscribe to push notifications', async () => {
    global.Notification.permission = 'granted';
    
    render(<PushNotificationManager />);

    const subscribeButton = screen.getByRole('button', { name: /subscribe/i });
    fireEvent.click(subscribeButton);

    await waitFor(() => {
      expect(navigator.serviceWorker.ready).toHaveBeenCalled();
    });
  });

  test('should handle push notification reception', async () => {
    const mockServiceWorker = {
      addEventListener: jest.fn(),
      postMessage: jest.fn(),
    };

    const pushEvent = new MessageEvent('push', {
      data: JSON.stringify({
        title: 'New Drop',
        body: 'Someone posted a new drop',
        icon: '/icon-192.png',
        badge: '/badge-72.png',
        data: { dropId: 'drop-123' },
      }),
    });

    const pushHandler = mockServiceWorker.addEventListener.mock.calls
      .find(call => call[0] === 'push')?.[1];

    expect(pushHandler).toBeDefined();

    // Simulate push event
    pushHandler(pushEvent);

    // Verify notification was shown
    expect(mockServiceWorker.postMessage).toHaveBeenCalledWith({
      type: 'SHOW_NOTIFICATION',
      data: expect.objectContaining({
        title: 'New Drop',
        body: 'Someone posted a new drop',
      }),
    });
  });
});
```

#### 21.3.3. Installation Flow Testing

```typescript
// tests/pwa/install-flow.test.ts
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { InstallPrompt } from '../../src/components/InstallPrompt';

describe('PWA Installation Flow', () => {
  test('should show install prompt when available', async () => {
    const mockPromptEvent = {
      prompt: jest.fn().mockResolvedValue({ outcome: 'accepted' }),
      userChoice: Promise.resolve({ outcome: 'accepted' }),
      preventDefault: jest.fn(),
    };

    render(<InstallPrompt />);

    // Simulate beforeinstallprompt event
    act(() => {
      window.dispatchEvent(
        Object.assign(new Event('beforeinstallprompt'), mockPromptEvent)
      );
    });

    await waitFor(() => {
      expect(screen.getByText(/install app/i)).toBeInTheDocument();
    });

    // Test install button click
    fireEvent.click(screen.getByRole('button', { name: /install/i }));

    await waitFor(() => {
      expect(mockPromptEvent.prompt).toHaveBeenCalled();
    });
  });

  test('should track installation analytics', async () => {
    const mockAnalytics = {
      track: jest.fn(),
    };

    jest.doMock('../../src/utils/analytics', () => mockAnalytics);

    const { InstallPrompt } = await import('../../src/components/InstallPrompt');
    
    render(<InstallPrompt />);

    // Simulate app installed event
    act(() => {
      window.dispatchEvent(new Event('appinstalled'));
    });

    expect(mockAnalytics.track).toHaveBeenCalledWith('pwa_installed', {
      source: 'browser_prompt',
      timestamp: expect.any(String),
    });
  });
});
```

### 21.4. Component Testing with React Testing Library

#### 21.4.1. Error Boundary Testing

```typescript
// tests/components/ErrorBoundary.test.tsx
import { render, screen } from '@testing-library/react';
import { ErrorBoundary } from '../../src/components/ErrorBoundary';

const ThrowError = ({ shouldThrow }: { shouldThrow: boolean }) => {
  if (shouldThrow) {
    throw new Error('Test error');
  }
  return <div>No error</div>;
};

describe('ErrorBoundary', () => {
  test('should render children when no error', () => {
    render(
      <ErrorBoundary>
        <ThrowError shouldThrow={false} />
      </ErrorBoundary>
    );

    expect(screen.getByText('No error')).toBeInTheDocument();
  });

  test('should render error UI when error occurs', () => {
    // Suppress console.error for this test
    const consoleSpy = jest.spyOn(console, 'error').mockImplementation();

    render(
      <ErrorBoundary>
        <ThrowError shouldThrow={true} />
      </ErrorBoundary>
    );

    expect(screen.getByText(/something went wrong/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /try again/i })).toBeInTheDocument();

    consoleSpy.mockRestore();
  });

  test('should reset error state when retry clicked', () => {
    const consoleSpy = jest.spyOn(console, 'error').mockImplementation();

    const { rerender } = render(
      <ErrorBoundary>
        <ThrowError shouldThrow={true} />
      </ErrorBoundary>
    );

    expect(screen.getByText(/something went wrong/i)).toBeInTheDocument();

    // Retry should reset the error boundary
    fireEvent.click(screen.getByRole('button', { name: /try again/i }));

    rerender(
      <ErrorBoundary>
        <ThrowError shouldThrow={false} />
      </ErrorBoundary>
    );

    expect(screen.getByText('No error')).toBeInTheDocument();

    consoleSpy.mockRestore();
  });
});
```

#### 21.4.2. Virtual Scrolling Testing

```typescript
// tests/components/VirtualTimeline.test.tsx
import { render, screen, fireEvent } from '@testing-library/react';
import { VirtualTimeline } from '../../src/components/VirtualTimeline';

describe('VirtualTimeline', () => {
  const mockDrops = Array.from({ length: 1000 }, (_, i) => ({
    id: `drop-${i}`,
    content: `Drop content ${i}`,
    author: { id: `user-${i}`, username: `user${i}` },
    createdAt: new Date().toISOString(),
  }));

  test('should render only visible items', () => {
    render(
      <div style={{ height: '400px' }}>
        <VirtualTimeline drops={mockDrops} itemHeight={100} />
      </div>
    );

    // Should only render visible items (4-5 items for 400px height)
    const visibleItems = screen.getAllByTestId(/drop-item/);
    expect(visibleItems.length).toBeLessThan(10);
    expect(visibleItems.length).toBeGreaterThan(3);
  });

  test('should update visible items on scroll', () => {
    const { container } = render(
      <div style={{ height: '400px' }}>
        <VirtualTimeline drops={mockDrops} itemHeight={100} />
      </div>
    );

    const scrollContainer = container.querySelector('[data-testid="virtual-scroll"]');
    
    // Initial state
    expect(screen.getByText('Drop content 0')).toBeInTheDocument();
    expect(screen.queryByText('Drop content 10')).not.toBeInTheDocument();

    // Scroll down
    fireEvent.scroll(scrollContainer!, { target: { scrollTop: 1000 } });

    // Should show different items
    expect(screen.queryByText('Drop content 0')).not.toBeInTheDocument();
    expect(screen.getByText('Drop content 10')).toBeInTheDocument();
  });

  test('should maintain scroll position on data updates', () => {
    const { rerender, container } = render(
      <div style={{ height: '400px' }}>
        <VirtualTimeline drops={mockDrops.slice(0, 500)} itemHeight={100} />
      </div>
    );

    const scrollContainer = container.querySelector('[data-testid="virtual-scroll"]');
    
    // Scroll to middle
    fireEvent.scroll(scrollContainer!, { target: { scrollTop: 1000 } });

    // Add new data
    rerender(
      <div style={{ height: '400px' }}>
        <VirtualTimeline drops={mockDrops} itemHeight={100} />
      </div>
    );

    // Scroll position should be maintained
    expect(scrollContainer!.scrollTop).toBe(1000);
  });
});
```

### 21.5. Performance Testing

#### 21.5.1. Lighthouse CI Testing

```typescript
// tests/performance/lighthouse.config.js
module.exports = {
  ci: {
    collect: {
      url: [
        'http://localhost:3000',
        'http://localhost:3000/timeline',
        'http://localhost:3000/profile/testuser',
      ],
      numberOfRuns: 3,
      settings: {
        chromeFlags: '--no-sandbox --headless',
      },
    },
    assert: {
      assertions: {
        'categories:performance': ['error', { minScore: 0.9 }],
        'categories:accessibility': ['error', { minScore: 0.95 }],
        'categories:best-practices': ['error', { minScore: 0.9 }],
        'categories:seo': ['error', { minScore: 0.8 }],
        'categories:pwa': ['error', { minScore: 0.9 }],
        
        // Core Web Vitals
        'largest-contentful-paint': ['error', { maxNumericValue: 2500 }],
        'cumulative-layout-shift': ['error', { maxNumericValue: 0.1 }],
        'first-contentful-paint': ['error', { maxNumericValue: 1800 }],
        'speed-index': ['error', { maxNumericValue: 3000 }],
        'interactive': ['error', { maxNumericValue: 3800 }],
        
        // Bundle size assertions
        'total-byte-weight': ['error', { maxNumericValue: 1000000 }], // 1MB
        'unused-javascript': ['warn', { maxNumericValue: 200000 }], // 200KB
        'unused-css-rules': ['warn', { maxNumericValue: 50000 }], // 50KB
      },
    },
    upload: {
      target: 'temporary-public-storage',
    },
  },
};
```

#### 21.5.2. Bundle Size Monitoring

```typescript
// tests/performance/bundle-size.test.ts
import { execSync } from 'child_process';
import path from 'path';

describe('Bundle Size Monitoring', () => {
  const MAX_BUNDLE_SIZE = 1024 * 1024; // 1MB
  const MAX_CHUNK_SIZE = 512 * 1024; // 512KB

  test('should not exceed maximum bundle size', () => {
    // Build the application
    execSync('npm run build', { cwd: process.cwd() });

    // Get build stats
    const buildDir = path.join(process.cwd(), 'dist');
    const stats = execSync(`du -sb ${buildDir}/static/js/*.js`, { encoding: 'utf8' });
    
    const files = stats.trim().split('\n').map(line => {
      const [size, filepath] = line.split('\t');
      return {
        size: parseInt(size, 10),
        name: path.basename(filepath),
      };
    });

    // Check total bundle size
    const totalSize = files.reduce((sum, file) => sum + file.size, 0);
    expect(totalSize).toBeLessThan(MAX_BUNDLE_SIZE);

    // Check individual chunk sizes
    files.forEach(file => {
      if (!file.name.includes('vendor')) {
        expect(file.size).toBeLessThan(MAX_CHUNK_SIZE);
      }
    });
  });

  test('should have effective code splitting', () => {
    const buildDir = path.join(process.cwd(), 'dist');
    const files = execSync(`ls ${buildDir}/static/js/`, { encoding: 'utf8' })
      .trim()
      .split('\n');

    // Should have multiple chunks
    expect(files.length).toBeGreaterThan(3);

    // Should have vendor chunk
    const hasVendorChunk = files.some(file => file.includes('vendor'));
    expect(hasVendorChunk).toBe(true);

    // Should have main chunk
    const hasMainChunk = files.some(file => file.includes('main'));
    expect(hasMainChunk).toBe(true);
  });
});
```

#### 21.5.3. Core Web Vitals Testing

```typescript
// tests/performance/core-web-vitals.test.ts
import { getCLS, getFID, getFCP, getLCP, getTTFB } from 'web-vitals';

describe('Core Web Vitals', () => {
  test('should measure and report vitals', (done) => {
    const vitals: { [key: string]: number } = {};
    let metricsReceived = 0;
    const expectedMetrics = 4; // CLS, FCP, LCP, TTFB (FID requires interaction)

    const handleMetric = (metric: any) => {
      vitals[metric.name] = metric.value;
      metricsReceived++;

      if (metricsReceived === expectedMetrics) {
        // Assert Core Web Vitals thresholds
        expect(vitals.CLS).toBeLessThan(0.1); // Good: < 0.1
        expect(vitals.FCP).toBeLessThan(1800); // Good: < 1.8s
        expect(vitals.LCP).toBeLessThan(2500); // Good: < 2.5s
        expect(vitals.TTFB).toBeLessThan(800); // Good: < 0.8s

        done();
      }
    };

    // Measure vitals
    getCLS(handleMetric);
    getFCP(handleMetric);
    getLCP(handleMetric);
    getTTFB(handleMetric);

    // Set timeout to prevent hanging
    setTimeout(() => {
      if (metricsReceived < expectedMetrics) {
        done();
      }
    }, 5000);
  });

  test('should track performance with analytics', () => {
    const mockAnalytics = {
      track: jest.fn(),
    };

    const vitalsReporter = (metric: any) => {
      mockAnalytics.track('web_vital', {
        name: metric.name,
        value: metric.value,
        delta: metric.delta,
        id: metric.id,
        rating: metric.rating,
      });
    };

    getCLS(vitalsReporter);
    getFCP(vitalsReporter);
    getLCP(vitalsReporter);
    getTTFB(vitalsReporter);

    // Verify analytics calls (after a brief delay)
    setTimeout(() => {
      expect(mockAnalytics.track).toHaveBeenCalledWith(
        'web_vital',
        expect.objectContaining({
          name: expect.any(String),
          value: expect.any(Number),
        })
      );
    }, 1000);
  });
});
```

### 21.6. E2E Testing with Playwright

#### 21.6.1. Timeline Flow Testing

```typescript
// tests/e2e/timeline.spec.ts
import { test, expect } from '@playwright/test';

test.describe('Timeline Flow', () => {
  test.beforeEach(async ({ page }) => {
    // Mock GraphQL responses
    await page.route('**/graphql', async route => {
      const request = route.request();
      const postData = JSON.parse(request.postData() || '{}');

      if (postData.operationName === 'GetTimeline') {
        await route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({
            data: {
              timeline: {
                edges: [
                  {
                    node: {
                      id: 'drop-1',
                      content: 'Test timeline drop',
                      author: { id: 'user-1', username: 'testuser' },
                      createdAt: '2024-01-01T00:00:00Z',
                      reactions: { totalCount: 5 },
                    },
                    cursor: 'cursor-1',
                  },
                ],
                pageInfo: {
                  hasNextPage: true,
                  endCursor: 'cursor-1',
                },
              },
            },
          }),
        });
      }
    });

    await page.goto('/timeline');
  });

  test('should load and display timeline', async ({ page }) => {
    await expect(page.locator('[data-testid="timeline"]')).toBeVisible();
    await expect(page.locator('text=Test timeline drop')).toBeVisible();
  });

  test('should create new drop', async ({ page }) => {
    // Click create drop button
    await page.click('[data-testid="create-drop-button"]');

    // Fill drop content
    await page.fill('[data-testid="drop-content"]', 'New test drop');

    // Submit drop
    await page.click('[data-testid="submit-drop"]');

    // Verify optimistic update
    await expect(page.locator('text=New test drop')).toBeVisible();
  });

  test('should infinite scroll timeline', async ({ page }) => {
    // Scroll to bottom
    await page.evaluate(() => {
      window.scrollTo(0, document.body.scrollHeight);
    });

    // Wait for more content to load
    await expect(page.locator('[data-testid="loading-indicator"]')).toBeVisible();
    
    // Verify new content loaded
    await expect(page.locator('[data-testid="drop-item"]')).toHaveCount(2);
  });

  test('should handle reactions', async ({ page }) => {
    // Click reaction button
    await page.click('[data-testid="reaction-button"]');

    // Select emoji
    await page.click('[data-testid="emoji-👍"]');

    // Verify reaction count updated
    await expect(page.locator('[data-testid="reaction-count"]')).toContainText('6');
  });
});
```

#### 21.6.2. PWA E2E Testing

```typescript
// tests/e2e/pwa.spec.ts
import { test, expect } from '@playwright/test';

test.describe('PWA Functionality', () => {
  test('should work offline', async ({ page, context }) => {
    // Load page online first
    await page.goto('/timeline');
    await expect(page.locator('[data-testid="timeline"]')).toBeVisible();

    // Go offline
    await context.setOffline(true);

    // Navigate to cached page
    await page.goto('/profile');
    await expect(page.locator('[data-testid="offline-indicator"]')).toBeVisible();

    // Verify cached content still accessible
    await expect(page.locator('[data-testid="profile-content"]')).toBeVisible();
  });

  test('should install as PWA', async ({ page }) => {
    await page.goto('/');

    // Trigger install prompt
    await page.evaluate(() => {
      window.dispatchEvent(new Event('beforeinstallprompt'));
    });

    // Verify install button appears
    await expect(page.locator('[data-testid="install-button"]')).toBeVisible();

    // Click install
    await page.click('[data-testid="install-button"]');

    // Verify install process initiated
    await expect(page.locator('[data-testid="install-success"]')).toBeVisible();
  });

  test('should receive push notifications', async ({ page, context }) => {
    // Grant notification permission
    await context.grantPermissions(['notifications']);

    await page.goto('/settings');

    // Enable notifications
    await page.click('[data-testid="enable-notifications"]');

    // Simulate push notification
    await page.evaluate(() => {
      navigator.serviceWorker.ready.then(registration => {
        registration.showNotification('Test Notification', {
          body: 'Test notification body',
          icon: '/icon-192.png',
        });
      });
    });

    // Verify notification shown (browser-dependent)
    // This is mainly for testing the subscription flow
    await expect(page.locator('[data-testid="notification-status"]')).toContainText('enabled');
  });
});
```

### 21.7. Test Configuration and Scripts

#### 21.7.1. Jest Configuration

```typescript
// jest.config.js
module.exports = {
  testEnvironment: 'jsdom',
  setupFilesAfterEnv: ['<rootDir>/tests/setup.ts'],
  moduleNameMapping: {
    '^@/(.*)$': '<rootDir>/src/$1',
    '\\.(css|less|scss|sass)$': 'identity-obj-proxy',
  },
  collectCoverageFrom: [
    'src/**/*.{ts,tsx}',
    '!src/**/*.d.ts',
    '!src/index.tsx',
    '!src/serviceWorker.ts',
  ],
  coverageThreshold: {
    global: {
      branches: 90,
      functions: 90,
      lines: 90,
      statements: 90,
    },
    './src/components/': {
      branches: 95,
      functions: 95,
      lines: 95,
      statements: 95,
    },
  },
  testMatch: [
    '<rootDir>/tests/**/*.test.{ts,tsx}',
    '<rootDir>/tests/**/*.spec.{ts,tsx}',
  ],
  transform: {
    '^.+\\.(ts|tsx)$': 'ts-jest',
  },
  moduleFileExtensions: ['ts', 'tsx', 'js', 'jsx', 'json'],
};
```

#### 21.7.2. Test Scripts

```json
{
  "scripts": {
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage",
    "test:e2e": "playwright test",
    "test:e2e:ui": "playwright test --ui",
    "test:lighthouse": "lhci autorun",
    "test:performance": "npm run test -- tests/performance",
    "test:all": "npm run test:coverage && npm run test:e2e && npm run test:lighthouse"
  }
}
```

This comprehensive test strategy ensures avion-web maintains high quality across all frontend concerns, from GraphQL integration to PWA functionality and performance metrics.

---