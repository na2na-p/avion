# エラーカタログ: avion-web

**Last Updated:** 2025/08/19  
**Service:** Client-side React SPA with PWA

## 概要

avion-webアプリケーションで発生する可能性のあるエラーコード一覧とその対処法です。

## ドメイン層エラー

### State Management関連

| エラーコード | HTTPステータス | 説明 | 対処法 |
|------------|--------------|------|--------|
| WEB_DOMAIN_STATE_NOT_FOUND | 404 | アプリケーション状態が見つかりません | 状態を初期化してください |
| WEB_DOMAIN_INVALID_STATE | 400 | アプリケーション状態が不正です | 状態を確認してください |
| WEB_DOMAIN_STATE_CORRUPTION | 422 | アプリケーション状態が破損しています | 状態をリセットしてください |
| WEB_DOMAIN_STATE_SYNC_FAILED | 500 | 状態同期に失敗しました | ネットワーク接続を確認してください |

### Navigation関連

| エラーコード | HTTPステータス | 説明 | 対処法 |
|------------|--------------|------|--------|
| WEB_DOMAIN_ROUTE_NOT_FOUND | 404 | ページが見つかりません | URLを確認してください |
| WEB_DOMAIN_INVALID_ROUTE | 400 | ルートが不正です | ナビゲーションを確認してください |
| WEB_DOMAIN_NAVIGATION_BLOCKED | 403 | ナビゲーションがブロックされました | アクセス権限を確認してください |
| WEB_DOMAIN_NAVIGATION_TIMEOUT | 504 | ナビゲーションがタイムアウトしました | ネットワーク接続を確認してください |

### Form Validation関連

| エラーコード | HTTPステータス | 説明 | 対処法 |
|------------|--------------|------|--------|
| WEB_DOMAIN_VALIDATION_FAILED | 400 | フォーム検証に失敗しました | 入力値を確認してください |
| WEB_DOMAIN_REQUIRED_FIELD_MISSING | 400 | 必須フィールドが不足しています | 必須項目を入力してください |
| WEB_DOMAIN_INVALID_FORMAT | 400 | フォーマットが不正です | 入力形式を確認してください |
| WEB_DOMAIN_VALUE_OUT_OF_RANGE | 400 | 値が範囲外です | 有効な範囲内の値を入力してください |

### Component関連

| エラーコード | HTTPステータス | 説明 | 対処法 |
|------------|--------------|------|--------|
| WEB_DOMAIN_COMPONENT_NOT_FOUND | 404 | コンポーネントが見つかりません | コンポーネントを確認してください |
| WEB_DOMAIN_COMPONENT_LOAD_FAILED | 500 | コンポーネント読み込みに失敗しました | ページを再読み込みしてください |
| WEB_DOMAIN_COMPONENT_RENDER_ERROR | 500 | コンポーネント描画エラー | エラー詳細を確認してください |
| WEB_DOMAIN_COMPONENT_PROPS_INVALID | 400 | コンポーネントプロパティが不正です | プロパティを確認してください |

### Media関連

| エラーコード | HTTPステータス | 説明 | 対処法 |
|------------|--------------|------|--------|
| WEB_DOMAIN_MEDIA_NOT_FOUND | 404 | メディアが見つかりません | メディアURLを確認してください |
| WEB_DOMAIN_MEDIA_LOAD_FAILED | 500 | メディア読み込みに失敗しました | ネットワーク接続を確認してください |
| WEB_DOMAIN_UNSUPPORTED_MEDIA_FORMAT | 415 | サポートされないメディア形式です | 対応形式のファイルを使用してください |
| WEB_DOMAIN_MEDIA_TOO_LARGE | 413 | メディアサイズが大きすぎます | ファイルサイズを小さくしてください |

## ユースケース層エラー

### API Communication関連

| エラーコード | HTTPステータス | 説明 | 対処法 |
|------------|--------------|------|--------|
| WEB_USECASE_API_REQUEST_FAILED | 500 | APIリクエストに失敗しました | ネットワーク接続を確認してください |
| WEB_USECASE_API_TIMEOUT | 504 | APIタイムアウト | しばらく待ってから再試行してください |
| WEB_USECASE_API_RATE_LIMITED | 429 | APIレート制限を超過しました | しばらく待ってから再試行してください |
| WEB_USECASE_API_UNAUTHORIZED | 401 | API認証エラー | ログインし直してください |
| WEB_USECASE_API_FORBIDDEN | 403 | APIアクセス拒否 | アクセス権限を確認してください |

### Authentication関連

| エラーコード | HTTPステータス | 説明 | 対処法 |
|------------|--------------|------|--------|
| WEB_USECASE_AUTH_TOKEN_EXPIRED | 401 | 認証トークンが期限切れです | 再ログインしてください |
| WEB_USECASE_AUTH_TOKEN_INVALID | 401 | 認証トークンが不正です | 再ログインしてください |
| WEB_USECASE_AUTH_REFRESH_FAILED | 401 | トークン更新に失敗しました | 再ログインしてください |
| WEB_USECASE_AUTH_LOGOUT_FAILED | 500 | ログアウトに失敗しました | 再試行してください |

### Data Management関連

| エラーコード | HTTPステータス | 説明 | 対処法 |
|------------|--------------|------|--------|
| WEB_USECASE_DATA_FETCH_FAILED | 500 | データ取得に失敗しました | 再試行してください |
| WEB_USECASE_DATA_SAVE_FAILED | 500 | データ保存に失敗しました | 再試行してください |
| WEB_USECASE_DATA_CONFLICT | 409 | データ競合が発生しました | 最新データで再試行してください |
| WEB_USECASE_DATA_VALIDATION_FAILED | 400 | データ検証に失敗しました | 入力データを確認してください |

### File Upload関連

| エラーコード | HTTPステータス | 説明 | 対処法 |
|------------|--------------|------|--------|
| WEB_USECASE_UPLOAD_FAILED | 500 | ファイルアップロードに失敗しました | 再試行してください |
| WEB_USECASE_UPLOAD_TIMEOUT | 504 | アップロードがタイムアウトしました | ファイルサイズを確認してください |
| WEB_USECASE_UPLOAD_QUOTA_EXCEEDED | 507 | アップロード容量を超過しました | 不要なファイルを削除してください |
| WEB_USECASE_INVALID_FILE_TYPE | 415 | サポートされないファイルタイプです | 対応形式のファイルを使用してください |

### Real-time Communication関連

| エラーコード | HTTPステータス | 説明 | 対処法 |
|------------|--------------|------|--------|
| WEB_USECASE_WEBSOCKET_CONNECTION_FAILED | 503 | WebSocket接続に失敗しました | ネットワーク接続を確認してください |
| WEB_USECASE_SSE_CONNECTION_FAILED | 503 | SSE接続に失敗しました | ネットワーク接続を確認してください |
| WEB_USECASE_REALTIME_SYNC_FAILED | 500 | リアルタイム同期に失敗しました | 接続を再確立してください |

## インフラストラクチャ層エラー

### Network関連

| エラーコード | HTTPステータス | 説明 | 対処法 |
|------------|--------------|------|--------|
| WEB_INFRA_NETWORK_ERROR | 503 | ネットワークエラー | インターネット接続を確認してください |
| WEB_INFRA_CONNECTION_TIMEOUT | 504 | 接続タイムアウト | ネットワーク環境を確認してください |
| WEB_INFRA_DNS_ERROR | 503 | DNS解決エラー | DNS設定を確認してください |
| WEB_INFRA_CORS_ERROR | 403 | CORS エラー | サーバー設定を確認してください |

### Storage関連

| エラーコード | HTTPステータス | 説明 | 対処法 |
|------------|--------------|------|--------|
| WEB_INFRA_LOCALSTORAGE_ERROR | 500 | ローカルストレージエラー | ブラウザの設定を確認してください |
| WEB_INFRA_SESSIONSTORAGE_ERROR | 500 | セッションストレージエラー | ブラウザの設定を確認してください |
| WEB_INFRA_INDEXEDDB_ERROR | 500 | IndexedDBエラー | ブラウザのデータベースを確認してください |
| WEB_INFRA_STORAGE_QUOTA_EXCEEDED | 507 | ストレージ容量超過 | 不要なデータを削除してください |

### Browser API関連

| エラーコード | HTTPステータス | 説明 | 対処法 |
|------------|--------------|------|--------|
| WEB_INFRA_GEOLOCATION_ERROR | 400 | 位置情報取得エラー | 位置情報の許可を確認してください |
| WEB_INFRA_CAMERA_ACCESS_DENIED | 403 | カメラアクセス拒否 | カメラの許可を確認してください |
| WEB_INFRA_MICROPHONE_ACCESS_DENIED | 403 | マイクアクセス拒否 | マイクの許可を確認してください |
| WEB_INFRA_NOTIFICATION_PERMISSION_DENIED | 403 | 通知許可拒否 | 通知の許可を確認してください |

### PWA関連

| エラーコード | HTTPステータス | 説明 | 対処法 |
|------------|--------------|------|--------|
| WEB_INFRA_SERVICE_WORKER_ERROR | 500 | Service Workerエラー | Service Workerを再登録してください |
| WEB_INFRA_CACHE_ERROR | 500 | キャッシュエラー | キャッシュをクリアしてください |
| WEB_INFRA_OFFLINE_MODE | 503 | オフラインモード | インターネット接続を確認してください |
| WEB_INFRA_UPDATE_AVAILABLE | 200 | アップデートが利用可能です | ページを再読み込みしてください |

### Performance関連

| エラーコード | HTTPステータス | 説明 | 対処法 |
|------------|--------------|------|--------|
| WEB_INFRA_MEMORY_LEAK | 500 | メモリリークが検出されました | ページを再読み込みしてください |
| WEB_INFRA_PERFORMANCE_DEGRADED | 503 | パフォーマンスが低下しています | 不要なタブを閉じてください |
| WEB_INFRA_BUNDLE_LOAD_FAILED | 500 | バンドル読み込みに失敗しました | ページを再読み込みしてください |

### GraphQL関連

| エラーコード | HTTPステータス | 説明 | 対処法 |
|------------|--------------|------|--------|
| WEB_INFRA_GRAPHQL_PARSE_ERROR | 400 | GraphQL解析エラー | クエリ構文を確認してください |
| WEB_INFRA_GRAPHQL_VALIDATION_ERROR | 400 | GraphQL検証エラー | クエリをスキーマに対して確認してください |
| WEB_INFRA_GRAPHQL_NETWORK_ERROR | 503 | GraphQLネットワークエラー | ネットワーク接続を確認してください |
| WEB_INFRA_APOLLO_CACHE_ERROR | 500 | Apollo キャッシュエラー | キャッシュをリセットしてください |

## ハンドラー層エラー

### UI/UX関連

| エラーコード | HTTPステータス | 説明 | 対処法 |
|------------|--------------|------|--------|
| WEB_HANDLER_RENDER_ERROR | 500 | 描画エラー | ページを再読み込みしてください |
| WEB_HANDLER_EVENT_HANDLER_ERROR | 500 | イベントハンドラーエラー | 操作を再試行してください |
| WEB_HANDLER_ANIMATION_ERROR | 500 | アニメーションエラー | アニメーションを無効にしてください |
| WEB_HANDLER_ACCESSIBILITY_ERROR | 400 | アクセシビリティエラー | ブラウザ設定を確認してください |

### Input/Output関連

| エラーコード | HTTPステータス | 説明 | 対処法 |
|------------|--------------|------|--------|
| WEB_HANDLER_INPUT_ERROR | 400 | 入力エラー | 入力内容を確認してください |
| WEB_HANDLER_CLIPBOARD_ERROR | 400 | クリップボードエラー | クリップボードの許可を確認してください |
| WEB_HANDLER_DRAG_DROP_ERROR | 400 | ドラッグ&ドロップエラー | ファイルドロップを再試行してください |
| WEB_HANDLER_KEYBOARD_SHORTCUT_ERROR | 400 | キーボードショートカットエラー | ショートカットを確認してください |

### Modal/Dialog関連

| エラーコード | HTTPステータス | 説明 | 対処法 |
|------------|--------------|------|--------|
| WEB_HANDLER_MODAL_ERROR | 500 | モーダルエラー | モーダルを閉じて再試行してください |
| WEB_HANDLER_DIALOG_ERROR | 500 | ダイアログエラー | ダイアログを閉じて再試行してください |
| WEB_HANDLER_POPUP_BLOCKED | 403 | ポップアップがブロックされました | ポップアップブロッカーを確認してください |

### Theme/Styling関連

| エラーコード | HTTPステータス | 説明 | 対処法 |
|------------|--------------|------|--------|
| WEB_HANDLER_THEME_LOAD_ERROR | 500 | テーマ読み込みエラー | テーマ設定を確認してください |
| WEB_HANDLER_CSS_ERROR | 500 | CSSエラー | スタイルシートを確認してください |
| WEB_HANDLER_RESPONSIVE_ERROR | 400 | レスポンシブエラー | 画面サイズを確認してください |

### Error Boundary関連

| エラーコード | HTTPステータス | 説明 | 対処法 |
|------------|--------------|------|--------|
| WEB_HANDLER_UNHANDLED_ERROR | 500 | 未処理エラー | ページを再読み込みしてください |
| WEB_HANDLER_ERROR_BOUNDARY_TRIGGERED | 500 | エラーバウンダリが作動しました | エラー詳細を確認してください |
| WEB_HANDLER_FALLBACK_COMPONENT_ERROR | 500 | フォールバックコンポーネントエラー | ページを再読み込みしてください |

## 関連ドキュメント

- [Avion エラーコード標準化ガイドライン](../common/errors/error-standards.md)
- [avion-web PRD](./prd.md)
- [avion-web Design Doc](./designdoc.md)
- [avion-web Screen Transitions Design](./screen-transitions-design.md)