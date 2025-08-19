# エラーカタログ: avion-auth

**Last Updated:** 2025/08/19  
**Service:** Authentication & Authorization Service

## 概要

avion-authサービスで発生する可能性のあるエラーコード一覧とその対処法です。

## ドメイン層エラー

### User関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| AUTH_DOMAIN_USER_NOT_FOUND | 404 | NOT_FOUND | ユーザーが見つかりません | ユーザーIDを確認してください |
| AUTH_DOMAIN_USER_ALREADY_EXISTS | 409 | ALREADY_EXISTS | ユーザーが既に存在します | 別のユーザー名を選択してください |
| AUTH_DOMAIN_INVALID_PASSWORD | 401 | UNAUTHENTICATED | パスワードが正しくありません | パスワードを確認してください |
| AUTH_DOMAIN_ACCOUNT_LOCKED | 403 | PERMISSION_DENIED | アカウントがロックされています | 管理者に連絡してください |
| AUTH_DOMAIN_ACCOUNT_DISABLED | 403 | PERMISSION_DENIED | アカウントが無効化されています | 管理者に連絡してください |
| AUTH_DOMAIN_EMAIL_NOT_VERIFIED | 403 | PERMISSION_DENIED | メールアドレスが確認されていません | メール認証を完了してください |

### Token関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| AUTH_DOMAIN_TOKEN_EXPIRED | 401 | UNAUTHENTICATED | トークンが期限切れです | トークンを更新してください |
| AUTH_DOMAIN_INVALID_TOKEN | 401 | UNAUTHENTICATED | トークンが不正です | 有効なトークンを使用してください |
| AUTH_DOMAIN_TOKEN_REVOKED | 401 | UNAUTHENTICATED | トークンが無効化されています | 再認証を行ってください |
| AUTH_DOMAIN_REFRESH_TOKEN_EXPIRED | 401 | UNAUTHENTICATED | リフレッシュトークンが期限切れです | 再ログインしてください |
| AUTH_DOMAIN_TOKEN_BLACKLISTED | 401 | UNAUTHENTICATED | トークンがブラックリストに登録されています | 新しいトークンを取得してください |

### Session関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| AUTH_DOMAIN_SESSION_NOT_FOUND | 404 | NOT_FOUND | セッションが見つかりません | 再ログインしてください |
| AUTH_DOMAIN_SESSION_EXPIRED | 401 | UNAUTHENTICATED | セッションが期限切れです | 再ログインしてください |
| AUTH_DOMAIN_MAX_SESSIONS_EXCEEDED | 429 | RESOURCE_EXHAUSTED | 最大セッション数を超過しました | 他のセッションを終了してください |
| AUTH_DOMAIN_SESSION_HIJACKED | 403 | PERMISSION_DENIED | セッションハイジャックが検出されました | セキュリティ確認を行ってください |

### Password関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| AUTH_DOMAIN_PASSWORD_POLICY_VIOLATION | 400 | INVALID_ARGUMENT | パスワードポリシー違反 | パスワード要件を確認してください |
| AUTH_DOMAIN_PASSWORD_REUSE_DETECTED | 400 | INVALID_ARGUMENT | パスワードの再利用が検出されました | 新しいパスワードを設定してください |
| AUTH_DOMAIN_PASSWORD_EXPIRED | 401 | UNAUTHENTICATED | パスワードが期限切れです | パスワードを更新してください |
| AUTH_DOMAIN_WEAK_PASSWORD | 400 | INVALID_ARGUMENT | パスワードが脆弱です | より強固なパスワードを設定してください |

### MFA関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| AUTH_DOMAIN_TOTP_INVALID | 401 | UNAUTHENTICATED | TOTP認証コードが不正です | 認証アプリのコードを確認してください |
| AUTH_DOMAIN_TOTP_EXPIRED | 401 | UNAUTHENTICATED | TOTP認証コードが期限切れです | 新しいコードを入力してください |
| AUTH_DOMAIN_TOTP_NOT_SETUP | 412 | FAILED_PRECONDITION | TOTP認証が設定されていません | TOTP認証を設定してください |
| AUTH_DOMAIN_BACKUP_CODE_INVALID | 401 | UNAUTHENTICATED | バックアップコードが不正です | 正しいバックアップコードを入力してください |
| AUTH_DOMAIN_BACKUP_CODE_USED | 409 | ALREADY_EXISTS | バックアップコードは既に使用済みです | 別のバックアップコードを使用してください |

### Passkey関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| AUTH_DOMAIN_PASSKEY_NOT_FOUND | 404 | NOT_FOUND | パスキーが見つかりません | パスキーを確認してください |
| AUTH_DOMAIN_PASSKEY_INVALID | 401 | UNAUTHENTICATED | パスキーが不正です | 正しいパスキーを使用してください |
| AUTH_DOMAIN_PASSKEY_ALREADY_EXISTS | 409 | ALREADY_EXISTS | パスキーが既に存在します | 既存のパスキーを確認してください |
| AUTH_DOMAIN_PASSKEY_REGISTRATION_FAILED | 400 | INVALID_ARGUMENT | パスキー登録に失敗しました | 再度登録を試行してください |

### Permission関連

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| AUTH_DOMAIN_PERMISSION_DENIED | 403 | PERMISSION_DENIED | 権限が拒否されました | 必要な権限を確認してください |
| AUTH_DOMAIN_INSUFFICIENT_SCOPE | 403 | PERMISSION_DENIED | スコープが不足しています | 適切なスコープを要求してください |
| AUTH_DOMAIN_ROLE_NOT_FOUND | 404 | NOT_FOUND | ロールが見つかりません | ロール設定を確認してください |
| AUTH_DOMAIN_POLICY_VIOLATION | 403 | PERMISSION_DENIED | ポリシー違反 | ポリシー要件を確認してください |

## ユースケース層エラー

### 入力検証エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| AUTH_USECASE_INVALID_INPUT | 400 | INVALID_ARGUMENT | 入力値が不正です | 入力値を確認してください |
| AUTH_USECASE_MISSING_REQUIRED | 400 | INVALID_ARGUMENT | 必須項目が不足しています | 必須項目を入力してください |
| AUTH_USECASE_INVALID_EMAIL | 400 | INVALID_ARGUMENT | メールアドレスが不正です | メールアドレス形式を確認してください |
| AUTH_USECASE_INVALID_USERNAME | 400 | INVALID_ARGUMENT | ユーザー名が不正です | ユーザー名の規則を確認してください |

### 認証フローエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| AUTH_USECASE_LOGIN_FAILED | 401 | UNAUTHENTICATED | ログインに失敗しました | 認証情報を確認してください |
| AUTH_USECASE_LOGOUT_FAILED | 500 | INTERNAL | ログアウトに失敗しました | 再試行してください |
| AUTH_USECASE_PASSWORD_RESET_FAILED | 500 | INTERNAL | パスワードリセットに失敗しました | 再試行してください |
| AUTH_USECASE_EMAIL_VERIFICATION_FAILED | 500 | INTERNAL | メール認証に失敗しました | 認証メールを再送してください |

### レート制限エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| AUTH_USECASE_LOGIN_RATE_LIMIT | 429 | RESOURCE_EXHAUSTED | ログイン試行制限を超過しました | しばらく待ってから再試行してください |
| AUTH_USECASE_PASSWORD_RESET_RATE_LIMIT | 429 | RESOURCE_EXHAUSTED | パスワードリセット制限を超過しました | しばらく待ってから再試行してください |
| AUTH_USECASE_EMAIL_SEND_RATE_LIMIT | 429 | RESOURCE_EXHAUSTED | メール送信制限を超過しました | しばらく待ってから再試行してください |

### OAuth関連エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| AUTH_USECASE_OAUTH_CODE_INVALID | 400 | INVALID_ARGUMENT | OAuth認証コードが不正です | 認証フローを再開してください |
| AUTH_USECASE_OAUTH_STATE_MISMATCH | 400 | INVALID_ARGUMENT | OAuthステートが一致しません | CSRF攻撃の可能性があります |
| AUTH_USECASE_OAUTH_PROVIDER_ERROR | 502 | INTERNAL | OAuthプロバイダーエラー | プロバイダーの状態を確認してください |

## インフラストラクチャ層エラー

### データベースエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| AUTH_INFRA_DATABASE_CONNECTION_FAILED | 503 | UNAVAILABLE | データベース接続失敗 | 接続設定を確認してください |
| AUTH_INFRA_DATABASE_QUERY_FAILED | 500 | INTERNAL | クエリ実行失敗 | クエリを確認してください |
| AUTH_INFRA_DATABASE_TRANSACTION_FAILED | 500 | INTERNAL | トランザクション失敗 | 再試行してください |
| AUTH_INFRA_DATABASE_CONSTRAINT_VIOLATION | 409 | ABORTED | データベース制約違反 | データの整合性を確認してください |

### キャッシュエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| AUTH_INFRA_CACHE_CONNECTION_FAILED | 503 | UNAVAILABLE | キャッシュ接続失敗 | 接続設定を確認してください |
| AUTH_INFRA_CACHE_OPERATION_FAILED | 500 | INTERNAL | キャッシュ操作失敗 | 再試行してください |
| AUTH_INFRA_CACHE_SESSION_STORE_FAILED | 500 | INTERNAL | セッションストア失敗 | セッションストアを確認してください |

### 暗号化エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| AUTH_INFRA_ENCRYPTION_FAILED | 500 | INTERNAL | 暗号化に失敗しました | 暗号化設定を確認してください |
| AUTH_INFRA_DECRYPTION_FAILED | 500 | INTERNAL | 復号化に失敗しました | データの整合性を確認してください |
| AUTH_INFRA_KEY_ROTATION_FAILED | 500 | INTERNAL | キーローテーションに失敗しました | キー管理システムを確認してください |

### 外部サービスエラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| AUTH_INFRA_EMAIL_SERVICE_ERROR | 502 | INTERNAL | メールサービスエラー | メールサービスの状態を確認してください |
| AUTH_INFRA_SMS_SERVICE_ERROR | 502 | INTERNAL | SMSサービスエラー | SMSサービスの状態を確認してください |
| AUTH_INFRA_OAUTH_PROVIDER_ERROR | 502 | INTERNAL | OAuthプロバイダーエラー | プロバイダーの状態を確認してください |

### ハンドラー層エラー

| エラーコード | HTTPステータス | gRPCステータス名 | 説明 | 対処法 |
|------------|--------------|--------------|------|--------|
| AUTH_HANDLER_BAD_REQUEST | 400 | INVALID_ARGUMENT | 不正なリクエスト | リクエスト形式を確認してください |
| AUTH_HANDLER_INVALID_CREDENTIALS | 401 | UNAUTHENTICATED | 認証情報が不正です | 認証情報を確認してください |
| AUTH_HANDLER_CSRF_TOKEN_INVALID | 403 | PERMISSION_DENIED | CSRFトークンが不正です | CSRFトークンを確認してください |
| AUTH_HANDLER_RATE_LIMIT_EXCEEDED | 429 | RESOURCE_EXHAUSTED | レート制限を超過しました | しばらく待ってから再試行してください |

## 関連ドキュメント

- [Avion エラーコード標準化ガイドライン](../common/errors/error-standards.md)
- [avion-auth PRD](./prd.md)
- [avion-auth Design Doc](./designdoc.md)