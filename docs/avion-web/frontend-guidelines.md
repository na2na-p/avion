# Frontend開発ガイドライン (.cursor/rules準拠)

## 1. TypeScript/React固有の設計要件

### ドメインオブジェクトの実装方針
- **Pure TypeScript**: すべてのドメインロジックはフレームワーク非依存の純粋なTypeScriptで実装
- **フィールドの非公開性**: すべてのフィールドはprivate/readonlyで宣言
- **更新メソッド**: 状態の更新は専用のメソッドを通じてのみ可能
- **不変性**: Immutable更新パターンを使用（Immer等のライブラリ活用可）

### React Components as Domain Objects
`.cursor/rules/languages/react.mdc`に基づき、以下の置き換えを適用：
- 構造体 → コンポーネント
- フィールド → 状態変数（State）
- レシーバーメソッド → イベントハンドラまたはカスタムフック

### コンポーネント設計の原則
```typescript
// ❌ Bad: 外部から直接状態を更新
interface BadProps {
  timeline: TimelineState;
  setTimeline: (timeline: TimelineState) => void;
}

// ✅ Good: 専用のメソッドを通じた更新
interface GoodProps {
  timeline: TimelineState;
  onLoadMore: () => void;
  onRefresh: () => void;
  onItemClick: (itemId: string) => void;
}
```

## 2. TDD実践ガイド

### Step 1: インターフェース定義
```typescript
// 1. まず型定義を作成
export interface DropFormProps {
  onSubmit: (content: string, visibility: Visibility) => Promise<void>;
  maxLength?: number;
  disabled?: boolean;
}

export interface DropFormState {
  content: string;
  visibility: Visibility;
  isSubmitting: boolean;
  error?: string;
}
```

### Step 2: テスト実装
```typescript
// 2. テストを先に書く
describe('DropForm', () => {
  it('should validate content length', async () => {
    const onSubmit = vi.fn();
    const { getByRole, getByText } = render(
      <DropForm onSubmit={onSubmit} maxLength={280} />
    );
    
    const textarea = getByRole('textbox');
    const submitButton = getByRole('button', { name: /submit/i });
    
    // 281文字入力
    await userEvent.type(textarea, 'a'.repeat(281));
    await userEvent.click(submitButton);
    
    expect(onSubmit).not.toHaveBeenCalled();
    expect(getByText(/content too long/i)).toBeInTheDocument();
  });
});
```

### Step 3: プロダクトコード実装
```typescript
// 3. テストが通るように実装
export const DropForm: React.FC<DropFormProps> = ({ 
  onSubmit, 
  maxLength = 280, 
  disabled = false 
}) => {
  const [state, setState] = useState<DropFormState>({
    content: '',
    visibility: 'public',
    isSubmitting: false,
  });

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    
    if (state.content.length > maxLength) {
      setState(prev => ({ ...prev, error: 'Content too long' }));
      return;
    }
    
    setState(prev => ({ ...prev, isSubmitting: true, error: undefined }));
    
    try {
      await onSubmit(state.content, state.visibility);
      setState(prev => ({ ...prev, content: '', isSubmitting: false }));
    } catch (error) {
      setState(prev => ({ 
        ...prev, 
        error: error instanceof Error ? error.message : 'Unknown error',
        isSubmitting: false 
      }));
    }
  };
  
  // 実装の続き...
};
```

## 3. 状態管理パターン

### Aggregateパターンの適用
```typescript
// ViewState Aggregate の実装例
export class ViewStateAggregate {
  private constructor(
    private state: ViewState
  ) {}

  static create(): ViewStateAggregate {
    return new ViewStateAggregate({
      currentRoute: new RouteParams('/', {}, new URLSearchParams()),
      timeline: { drops: [], hasMore: true, isLoading: false },
      notification: { unreadCount: 0, lastCheckedAt: new Date() },
      forms: new Map(),
      modals: { isOpen: false }
    });
  }

  // 状態更新は専用メソッドのみ
  navigateTo(route: RouteParams): ViewStateAggregate {
    return new ViewStateAggregate({
      ...this.state,
      currentRoute: route
    });
  }

  updateTimeline(updater: (prev: TimelineViewState) => TimelineViewState): ViewStateAggregate {
    return new ViewStateAggregate({
      ...this.state,
      timeline: updater(this.state.timeline)
    });
  }

  // Getter methods
  getCurrentRoute(): RouteParams { return this.state.currentRoute; }
  getTimeline(): TimelineViewState { return this.state.timeline; }
}
```

### Custom Hook による Use Case 実装
```typescript
// GetTimelineQueryUseCase の実装例
export function useGetTimeline() {
  const [state, dispatch] = useReducer(timelineReducer, initialState);
  const client = useGraphQLClient();

  const execute = useCallback(async (cursor?: string) => {
    dispatch({ type: 'FETCH_START' });
    
    try {
      const query = new GraphQLQuery(GET_TIMELINE_QUERY, { cursor });
      const result = await client.query(query);
      
      dispatch({ 
        type: 'FETCH_SUCCESS', 
        payload: result.data.timeline 
      });
    } catch (error) {
      dispatch({ 
        type: 'FETCH_ERROR', 
        payload: error instanceof Error ? error : new Error('Unknown error')
      });
    }
  }, [client]);

  return { ...state, execute };
}
```

## 4. エラーハンドリング

### ドメインエラーの定義と使用
```typescript
// Domain Errors
export class ValidationError extends Error {
  constructor(public field: string, public reason: string) {
    super(`Validation failed for ${field}: ${reason}`);
    this.name = 'ValidationError';
  }
}

// Component での使用
const handleError = (error: unknown) => {
  if (error instanceof ValidationError) {
    setFieldError(error.field, error.reason);
  } else if (error instanceof TokenExpiredError) {
    redirectToLogin();
  } else {
    setGeneralError('An unexpected error occurred');
  }
};
```

## 5. テストファイルの配置

```
src/
├── domain/
│   ├── aggregates/
│   │   ├── ViewState.ts
│   │   └── ViewState.test.ts
│   └── value-objects/
│       ├── AuthToken.ts
│       └── AuthToken.test.ts
├── use-cases/
│   ├── timeline/
│   │   ├── GetTimelineUseCase.ts
│   │   └── GetTimelineUseCase.test.ts
│   └── auth/
│       ├── LoginUseCase.ts
│       └── LoginUseCase.test.ts
└── presentation/
    ├── components/
    │   ├── DropForm.tsx
    │   └── DropForm.test.tsx
    └── hooks/
        ├── useTimeline.ts
        └── useTimeline.test.ts
```

## 6. コミット時のチェックリスト

コミット前に必ず以下を確認：

- [ ] すべてのテストが成功 (`npm test`)
- [ ] E2Eテストが成功 (`npm run test:e2e`)
- [ ] リンターチェックをパス (`npm run lint`)
- [ ] 型チェックをパス (`npm run type-check`)
- [ ] ビルドが成功 (`npm run build`)
- [ ] ドメインオブジェクトのフィールドはすべてprivate/readonly
- [ ] 状態更新は専用メソッド経由のみ
- [ ] エラーハンドリングが適切に実装されている

## 7. PR作成時の必須事項

```markdown
## テスト結果

<details>
<summary>✅ Unit Test Results</summary>

\`\`\`sh
$ npm test
✓ src/domain/aggregates/ViewState.test.ts (12)
✓ src/domain/value-objects/AuthToken.test.ts (8)
✓ src/use-cases/timeline/GetTimelineUseCase.test.ts (6)
✓ src/presentation/components/DropForm.test.tsx (10)

Test Files  4 passed (4)
     Tests  36 passed (36)
\`\`\`
</details>

<details>
<summary>✅ E2E Test Results</summary>

\`\`\`sh
$ npm run test:e2e
Running 5 tests using 2 workers
  ✓  1 [chromium] › auth.spec.ts:10:7 › Authentication › should login successfully
  ✓  2 [chromium] › timeline.spec.ts:8:7 › Timeline › should display home timeline
  ...
\`\`\`
</details>

<details>
<summary>✅ Type Check Results</summary>

\`\`\`sh
$ npm run type-check
✨ No errors found
\`\`\`
</details>
```