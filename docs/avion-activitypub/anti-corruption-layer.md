# Anti-Corruption Layer Specification (アンチコラプションレイヤー仕様)

**Author:** Claude
**Last Updated:** 2025-01-16
**Version:** 1.0

## 1. 概要

本ドキュメントは、avion-activitypubサービスにおけるアンチコラプションレイヤー（ACL）の完全な仕様を定義します。ACLは外部システム（他のActivityPub実装）とドメインモデル間の変換と保護を提供し、ドメインの純粋性を保ちます。

## 2. アーキテクチャ概要

```
[External World]
       ↓
┌─────────────────────────────────────────┐
│  Anti-Corruption Layer (ACL)            │
├─────────────────────────────────────────┤
│  • Platform Adapters                    │
│  • Protocol Translators                 │
│  • Schema Validators                    │
│  • Security Filters                     │
└─────────────────────────────────────────┘
       ↓
[Domain Model]
```

## 3. Platform Adapters (プラットフォームアダプター)

### 3.1 基底アダプター

```go
package anticorruption

import (
    "context"
    "github.com/avion/activitypub/domain"
)

// PlatformAdapter は外部プラットフォームとの変換を行う基底インターフェース
type PlatformAdapter interface {
    // 外部形式からドメインモデルへの変換
    ToDomainActor(externalActor map[string]interface{}) (*domain.RemoteActor, error)
    ToDomainActivity(externalActivity map[string]interface{}) (*domain.Activity, error)
    ToDomainObject(externalObject map[string]interface{}) (domain.Object, error)
    
    // ドメインモデルから外部形式への変換
    FromDomainActor(actor *domain.RemoteActor) (map[string]interface{}, error)
    FromDomainActivity(activity *domain.Activity) (map[string]interface{}, error)
    FromDomainObject(object domain.Object) (map[string]interface{}, error)
    
    // プラットフォーム固有の処理
    ValidateIncoming(data map[string]interface{}) error
    EnrichOutgoing(data map[string]interface{}) map[string]interface{}
    GetPlatformName() string
    GetSupportedVersion() string
}

// BasePlatformAdapter は共通処理を提供する基底実装
type BasePlatformAdapter struct {
    platformName    string
    version        string
    namespaces     map[string]string
    logger         Logger
    metrics        MetricsCollector
}

func (a *BasePlatformAdapter) validateRequiredFields(data map[string]interface{}, fields []string) error {
    for _, field := range fields {
        if _, exists := data[field]; !exists {
            return &ValidationError{
                Field:   field,
                Message: fmt.Sprintf("required field '%s' is missing", field),
            }
        }
    }
    return nil
}

func (a *BasePlatformAdapter) sanitizeString(input string) string {
    // XSS対策、制御文字の除去など
    sanitized := strings.TrimSpace(input)
    sanitized = html.EscapeString(sanitized)
    sanitized = removeControlCharacters(sanitized)
    return sanitized
}
```

### 3.2 Mastodonアダプター

```go
// MastodonAdapter はMastodon固有の変換を処理
type MastodonAdapter struct {
    BasePlatformAdapter
    emojiConverter     *EmojiConverter
    mediaTypeMapper    *MediaTypeMapper
}

func NewMastodonAdapter() *MastodonAdapter {
    return &MastodonAdapter{
        BasePlatformAdapter: BasePlatformAdapter{
            platformName: "mastodon",
            version:     "4.2",
            namespaces: map[string]string{
                "toot": "http://joinmastodon.org/ns#",
                "schema": "http://schema.org#",
            },
        },
        emojiConverter:  NewEmojiConverter(),
        mediaTypeMapper: NewMediaTypeMapper(),
    }
}

func (a *MastodonAdapter) ToDomainActor(external map[string]interface{}) (*domain.RemoteActor, error) {
    // Mastodon固有のフィールドを正規化
    actor := &domain.RemoteActor{}
    
    // 基本フィールドのマッピング
    if id, ok := external["id"].(string); ok {
        actor.ActorURI = id
    }
    
    if preferredUsername, ok := external["preferredUsername"].(string); ok {
        actor.Username = a.sanitizeString(preferredUsername)
    }
    
    // Mastodon固有: featuredフィールド（ピン留め投稿）
    if featured, ok := external["featured"].(string); ok {
        actor.SetMetadata("featured_collection", featured)
    }
    
    // Mastodon固有: カスタム絵文字の処理
    if emojis, ok := external["tag"].([]interface{}); ok {
        customEmojis := a.extractCustomEmojis(emojis)
        actor.SetMetadata("custom_emojis", customEmojis)
    }
    
    // Mastodon固有: bot フラグ
    if botFlag, ok := external["toot:bot"].(bool); ok {
        actor.IsBot = botFlag
    }
    
    // 公開鍵の取得（Mastodon形式）
    if publicKey, ok := external["publicKey"].(map[string]interface{}); ok {
        if pem, ok := publicKey["publicKeyPem"].(string); ok {
            actor.PublicKeyPEM = pem
        }
    }
    
    return actor, nil
}

func (a *MastodonAdapter) FromDomainActivity(activity *domain.Activity) (map[string]interface{}, error) {
    result := make(map[string]interface{})
    
    // 基本ActivityPub構造
    result["@context"] = a.buildContext()
    result["type"] = activity.Type
    result["id"] = activity.ID
    result["actor"] = activity.Actor
    
    // Mastodon固有の処理
    switch activity.Type {
    case "Create":
        // Noteオブジェクトの処理
        if note, ok := activity.Object.(*domain.Note); ok {
            result["object"] = a.buildMastodonNote(note)
        }
        
    case "Announce":
        // Boost（再共有）の処理
        result["object"] = activity.Object.GetID()
        result["published"] = activity.Published
        
    case "Group":
        // MastodonはGroup Actorをサポートしないため、Personにフォールバック
        return a.fallbackGroupToPerson(activity)
    }
    
    // Mastodon固有のメタデータ追加
    result["toot:visibility"] = a.mapVisibility(activity.Visibility)
    
    return result, nil
}

func (a *MastodonAdapter) fallbackGroupToPerson(activity *domain.Activity) (map[string]interface{}, error) {
    // Group ActivityをPerson互換形式に変換
    result := make(map[string]interface{})
    result["@context"] = a.buildContext()
    result["type"] = "Person"
    result["name"] = fmt.Sprintf("%s (Community)", activity.Actor)
    result["summary"] = "This is a community account (Group Actor not supported)"
    
    // コミュニティ情報をメタデータとして保持
    result["toot:featured"] = map[string]interface{}{
        "type": "Collection",
        "name": "Community Information",
    }
    
    return result, nil
}

func (a *MastodonAdapter) extractCustomEmojis(tags []interface{}) []map[string]string {
    emojis := []map[string]string{}
    for _, tag := range tags {
        if emoji, ok := tag.(map[string]interface{}); ok {
            if emoji["type"] == "Emoji" {
                emojis = append(emojis, map[string]string{
                    "name": emoji["name"].(string),
                    "icon": emoji["icon"].(map[string]interface{})["url"].(string),
                })
            }
        }
    }
    return emojis
}
```

### 3.3 Misskeyアダプター

```go
// MisskeyAdapter はMisskey固有の変換を処理
type MisskeyAdapter struct {
    BasePlatformAdapter
    reactionMapper     *ReactionMapper
    mfmParser         *MFMParser  // Misskey Flavored Markdown
}

func NewMisskeyAdapter() *MisskeyAdapter {
    return &MisskeyAdapter{
        BasePlatformAdapter: BasePlatformAdapter{
            platformName: "misskey",
            version:     "2024.11",
            namespaces: map[string]string{
                "misskey": "https://misskey-hub.net/ns#",
                "toot": "http://joinmastodon.org/ns#",
            },
        },
        reactionMapper: NewReactionMapper(),
        mfmParser:     NewMFMParser(),
    }
}

func (a *MisskeyAdapter) ToDomainActivity(external map[string]interface{}) (*domain.Activity, error) {
    activity := &domain.Activity{}
    
    // Misskey固有: リアクション（絵文字リアクション）の処理
    if external["type"] == "EmojiReact" {
        return a.handleEmojiReaction(external)
    }
    
    // Misskey固有: 引用Renote
    if external["type"] == "Announce" {
        if quote, exists := external["misskey:quote"]; exists {
            activity.Type = "Quote"  // 内部的にQuote型として扱う
            activity.SetMetadata("quoted_content", quote)
        }
    }
    
    // Misskey固有: MFMコンテンツの処理
    if content, ok := external["content"].(string); ok {
        plainText, formatted := a.mfmParser.Parse(content)
        activity.Content = plainText
        activity.SetMetadata("mfm_formatted", formatted)
    }
    
    // Misskey固有: isCat（猫化）フラグ
    if isCat, ok := external["misskey:isCat"].(bool); ok && isCat {
        activity.SetMetadata("is_cat", true)
    }
    
    return activity, nil
}

func (a *MisskeyAdapter) handleEmojiReaction(external map[string]interface{}) (*domain.Activity, error) {
    // Misskey独自のEmojiReactをLike相当として処理
    activity := &domain.Activity{
        Type: "Like",  // 内部的にはLikeとして扱う
    }
    
    // リアクション絵文字の取得
    if emoji, ok := external["misskey:reaction"].(string); ok {
        activity.SetMetadata("reaction_emoji", emoji)
        
        // カスタム絵文字の場合の処理
        if strings.HasPrefix(emoji, ":") && strings.HasSuffix(emoji, ":") {
            activity.SetMetadata("is_custom_emoji", true)
        }
    }
    
    return activity, nil
}

func (a *MisskeyAdapter) FromDomainObject(object domain.Object) (map[string]interface{}, error) {
    result := make(map[string]interface{})
    
    switch obj := object.(type) {
    case *domain.Note:
        // Misskey形式のNoteを構築
        result["type"] = "Note"
        result["content"] = a.mfmParser.Format(obj.Content)
        
        // Misskey固有: 公開範囲の詳細設定
        result["misskey:visibility"] = obj.Visibility
        if obj.Visibility == "specified" {
            result["misskey:visibleUserIds"] = obj.VisibleUserIDs
        }
        
        // Misskey固有: リアクション受け入れ設定
        result["misskey:reactionAcceptance"] = obj.GetMetadata("reaction_acceptance", "likeOnly")
        
    case *domain.Community:
        // Misskey固有のコミュニティ表現
        result["type"] = "Group"
        result["misskey:communityType"] = "open"  // Misskeyのコミュニティタイプ
    }
    
    return result, nil
}
```

### 3.4 Lemmyアダプター

```go
// LemmyAdapter はLemmy（Redditクローン）固有の変換を処理
type LemmyAdapter struct {
    BasePlatformAdapter
    communityMapper    *CommunityMapper
    votingHandler     *VotingHandler
}

func NewLemmyAdapter() *LemmyAdapter {
    return &LemmyAdapter{
        BasePlatformAdapter: BasePlatformAdapter{
            platformName: "lemmy",
            version:     "0.19",
            namespaces: map[string]string{
                "lemmy": "https://join-lemmy.org/ns#",
            },
        },
        communityMapper: NewCommunityMapper(),
        votingHandler:  NewVotingHandler(),
    }
}

func (a *LemmyAdapter) ToDomainObject(external map[string]interface{}) (domain.Object, error) {
    objectType := external["type"].(string)
    
    switch objectType {
    case "Group":
        // LemmyのコミュニティをDomainのCommunityに変換
        return a.toDomainCommunity(external)
        
    case "Page":
        // Lemmyの投稿（Page型）をDomainのPostに変換
        return a.toDomainPost(external)
        
    case "Note":
        // Lemmyのコメントを処理
        return a.toDomainComment(external)
    }
    
    return nil, fmt.Errorf("unsupported Lemmy object type: %s", objectType)
}

func (a *LemmyAdapter) toDomainCommunity(external map[string]interface{}) (*domain.Community, error) {
    community := &domain.Community{}
    
    // Lemmy固有: モデレーターのコレクション
    if moderators, ok := external["lemmy:moderators"].(string); ok {
        community.SetMetadata("moderators_collection", moderators)
    }
    
    // Lemmy固有: NSFW（成人向け）フラグ
    if nsfw, ok := external["lemmy:nsfw"].(bool); ok {
        community.IsNSFW = nsfw
    }
    
    // Lemmy固有: 投稿言語制限
    if languages, ok := external["lemmy:postingRestrictedToLanguages"].([]interface{}); ok {
        langs := make([]string, len(languages))
        for i, lang := range languages {
            langs[i] = lang.(string)
        }
        community.AllowedLanguages = langs
    }
    
    return community, nil
}

func (a *LemmyAdapter) FromDomainActivity(activity *domain.Activity) (map[string]interface{}, error) {
    result := make(map[string]interface{})
    
    // Lemmy固有: 投票（upvote/downvote）の処理
    if activity.Type == "Vote" {
        voteType := activity.GetMetadata("vote_type", "upvote").(string)
        if voteType == "upvote" {
            result["type"] = "Like"
        } else {
            result["type"] = "Dislike"
        }
        result["object"] = activity.Object.GetID()
    }
    
    // Lemmy固有: クロスポスト（他コミュニティへの共有）
    if activity.Type == "Announce" && activity.GetMetadata("is_crosspost", false).(bool) {
        result["lemmy:crosspost"] = true
        result["lemmy:originalCommunity"] = activity.GetMetadata("original_community", "")
    }
    
    return result, nil
}
```

## 4. Protocol Translators (プロトコル変換器)

### 4.1 HTTPシグネチャ変換器

```go
// HTTPSignatureTranslator はHTTP Signature認証を処理
type HTTPSignatureTranslator struct {
    keyStore        KeyStore
    signatureAlgos  []string
    clockSkew       time.Duration
}

func (t *HTTPSignatureTranslator) ValidateIncomingSignature(req *http.Request) (*domain.Actor, error) {
    // Signatureヘッダーの解析
    signature := req.Header.Get("Signature")
    if signature == "" {
        return nil, ErrMissingSignature
    }
    
    params := t.parseSignatureHeader(signature)
    
    // keyIdからActorを特定
    actor, err := t.keyStore.GetActorByKeyID(params["keyId"])
    if err != nil {
        return nil, fmt.Errorf("failed to get actor for keyId: %w", err)
    }
    
    // 署名検証
    if err := t.verifySignature(req, params, actor.PublicKey); err != nil {
        return nil, fmt.Errorf("signature verification failed: %w", err)
    }
    
    // Date/Digestヘッダーの検証
    if err := t.validateHeaders(req); err != nil {
        return nil, err
    }
    
    return actor, nil
}

func (t *HTTPSignatureTranslator) SignOutgoingRequest(req *http.Request, privateKey *rsa.PrivateKey) error {
    // Dateヘッダーの追加
    req.Header.Set("Date", time.Now().UTC().Format(http.TimeFormat))
    
    // Digestヘッダーの計算と追加
    if req.Body != nil {
        bodyBytes, _ := io.ReadAll(req.Body)
        req.Body = io.NopCloser(bytes.NewReader(bodyBytes))
        
        digest := t.calculateDigest(bodyBytes)
        req.Header.Set("Digest", fmt.Sprintf("SHA-256=%s", digest))
    }
    
    // 署名の生成
    signature := t.generateSignature(req, privateKey)
    req.Header.Set("Signature", signature)
    
    return nil
}

func (t *HTTPSignatureTranslator) validateHeaders(req *http.Request) error {
    // Dateヘッダーの検証（クロックスキュー考慮）
    dateStr := req.Header.Get("Date")
    if dateStr == "" {
        return ErrMissingDateHeader
    }
    
    date, err := http.ParseTime(dateStr)
    if err != nil {
        return fmt.Errorf("invalid date header: %w", err)
    }
    
    if time.Since(date).Abs() > t.clockSkew {
        return ErrClockSkewExceeded
    }
    
    // Digestヘッダーの検証（POSTの場合）
    if req.Method == "POST" {
        expectedDigest := req.Header.Get("Digest")
        if expectedDigest == "" {
            return ErrMissingDigestHeader
        }
        
        bodyBytes, _ := io.ReadAll(req.Body)
        req.Body = io.NopCloser(bytes.NewReader(bodyBytes))
        
        actualDigest := t.calculateDigest(bodyBytes)
        if !strings.Contains(expectedDigest, actualDigest) {
            return ErrDigestMismatch
        }
    }
    
    return nil
}
```

### 4.2 JSON-LD変換器

```go
// JSONLDTranslator はJSON-LD形式の変換を処理
type JSONLDTranslator struct {
    contextCache    map[string]interface{}
    compactor      *jsonld.Compactor
    expander       *jsonld.Expander
}

func (t *JSONLDTranslator) Expand(data map[string]interface{}) (map[string]interface{}, error) {
    // @contextを展開して完全なURIに変換
    expanded, err := t.expander.Expand(data)
    if err != nil {
        return nil, fmt.Errorf("failed to expand JSON-LD: %w", err)
    }
    
    return expanded.(map[string]interface{}), nil
}

func (t *JSONLDTranslator) Compact(data map[string]interface{}, context interface{}) (map[string]interface{}, error) {
    // 指定されたcontextでコンパクト化
    compacted, err := t.compactor.Compact(data, context)
    if err != nil {
        return nil, fmt.Errorf("failed to compact JSON-LD: %w", err)
    }
    
    return compacted.(map[string]interface{}), nil
}

func (t *JSONLDTranslator) NormalizeContext(data map[string]interface{}) map[string]interface{} {
    // @contextの正規化
    context := data["@context"]
    
    switch ctx := context.(type) {
    case string:
        // 単一のcontext
        data["@context"] = []interface{}{ctx}
        
    case []interface{}:
        // 複数のcontext（既に配列）
        // そのまま
        
    case map[string]interface{}:
        // インラインcontext定義
        data["@context"] = []interface{}{
            "https://www.w3.org/ns/activitystreams",
            ctx,
        }
    }
    
    return data
}

func (t *JSONLDTranslator) BuildContext(platform string) interface{} {
    // プラットフォーム別のcontext構築
    baseContext := []interface{}{
        "https://www.w3.org/ns/activitystreams",
        "https://w3id.org/security/v1",
    }
    
    switch platform {
    case "mastodon":
        baseContext = append(baseContext, map[string]interface{}{
            "toot": "http://joinmastodon.org/ns#",
            "featured": "toot:featured",
            "featuredTags": "toot:featuredTags",
            "discoverable": "toot:discoverable",
        })
        
    case "misskey":
        baseContext = append(baseContext, map[string]interface{}{
            "misskey": "https://misskey-hub.net/ns#",
            "isCat": "misskey:isCat",
            "reaction": "misskey:reaction",
            "quote": "misskey:quote",
        })
        
    case "avion":
        baseContext = append(baseContext, map[string]interface{}{
            "avion": "https://avion.social/ns#",
            "Community": "avion:Community",
            "Topic": "avion:Topic",
            "communityRole": "avion:communityRole",
        })
    }
    
    return baseContext
}
```

## 5. Schema Validators (スキーマ検証器)

### 5.1 ActivityPubスキーマ検証器

```go
// ActivityPubValidator はActivityPub仕様準拠を検証
type ActivityPubValidator struct {
    schemaLoader    *SchemaLoader
    strictMode      bool
    customRules     []ValidationRule
}

func (v *ActivityPubValidator) ValidateActivity(data map[string]interface{}) error {
    // 必須フィールドの検証
    if err := v.validateRequiredFields(data); err != nil {
        return err
    }
    
    // 型の検証
    activityType, ok := data["type"].(string)
    if !ok {
        return ErrInvalidActivityType
    }
    
    // アクティビティタイプ別の検証
    switch activityType {
    case "Create", "Update", "Delete":
        return v.validateObjectActivity(data)
        
    case "Follow", "Accept", "Reject":
        return v.validateRelationshipActivity(data)
        
    case "Like", "Announce", "Undo":
        return v.validateInteractionActivity(data)
        
    default:
        if v.strictMode {
            return fmt.Errorf("unknown activity type: %s", activityType)
        }
    }
    
    // カスタムルールの適用
    for _, rule := range v.customRules {
        if err := rule.Validate(data); err != nil {
            return fmt.Errorf("custom validation failed: %w", err)
        }
    }
    
    return nil
}

func (v *ActivityPubValidator) validateObjectActivity(data map[string]interface{}) error {
    // objectフィールドの検証
    object, exists := data["object"]
    if !exists {
        return ErrMissingObject
    }
    
    switch obj := object.(type) {
    case string:
        // URIとしての検証
        if !isValidURI(obj) {
            return ErrInvalidObjectURI
        }
        
    case map[string]interface{}:
        // インラインオブジェクトの検証
        if err := v.ValidateObject(obj); err != nil {
            return fmt.Errorf("invalid inline object: %w", err)
        }
        
    default:
        return ErrInvalidObjectType
    }
    
    return nil
}

func (v *ActivityPubValidator) ValidateActor(data map[string]interface{}) error {
    // Actor必須フィールド
    requiredFields := []string{"id", "type", "inbox", "publicKey"}
    
    for _, field := range requiredFields {
        if _, exists := data[field]; !exists {
            return fmt.Errorf("missing required actor field: %s", field)
        }
    }
    
    // Actor型の検証
    actorType := data["type"].(string)
    validTypes := []string{"Person", "Application", "Service", "Group", "Organization"}
    
    if !contains(validTypes, actorType) {
        return fmt.Errorf("invalid actor type: %s", actorType)
    }
    
    // 公開鍵の検証
    publicKey, ok := data["publicKey"].(map[string]interface{})
    if !ok {
        return ErrInvalidPublicKey
    }
    
    if _, exists := publicKey["publicKeyPem"]; !exists {
        return ErrMissingPublicKeyPem
    }
    
    return nil
}
```

### 5.2 セキュリティバリデーター

```go
// SecurityValidator はセキュリティ関連の検証を実施
type SecurityValidator struct {
    maxContentLength   int
    blockedDomains    []string
    suspiciousPatterns []*regexp.Regexp
    rateLimiter       *RateLimiter
}

func (v *SecurityValidator) ValidateIncoming(data map[string]interface{}, sourceIP string) error {
    // レート制限チェック
    if !v.rateLimiter.Allow(sourceIP) {
        return ErrRateLimitExceeded
    }
    
    // コンテンツサイズ制限
    if err := v.validateContentSize(data); err != nil {
        return err
    }
    
    // 悪意のあるパターンの検出
    if err := v.detectMaliciousPatterns(data); err != nil {
        return err
    }
    
    // ドメインブロックリストのチェック
    if err := v.checkBlockedDomains(data); err != nil {
        return err
    }
    
    // XSS/SQLインジェクション対策
    if err := v.sanitizeContent(data); err != nil {
        return err
    }
    
    return nil
}

func (v *SecurityValidator) detectMaliciousPatterns(data map[string]interface{}) error {
    content := extractTextContent(data)
    
    for _, pattern := range v.suspiciousPatterns {
        if pattern.MatchString(content) {
            return ErrSuspiciousContent
        }
    }
    
    // JavaScript検出
    if strings.Contains(strings.ToLower(content), "<script") {
        return ErrScriptInjectionAttempt
    }
    
    // 大量のメンション検出（スパム対策）
    mentionCount := strings.Count(content, "@")
    if mentionCount > 50 {
        return ErrTooManyMentions
    }
    
    return nil
}

func (v *SecurityValidator) sanitizeContent(data map[string]interface{}) error {
    // HTMLサニタイズ
    if content, ok := data["content"].(string); ok {
        sanitized := v.sanitizeHTML(content)
        data["content"] = sanitized
    }
    
    // 再帰的にオブジェクト内をサニタイズ
    for key, value := range data {
        switch v := value.(type) {
        case string:
            data[key] = v.sanitizeString(v)
        case map[string]interface{}:
            v.sanitizeContent(v)
        }
    }
    
    return nil
}
```

## 6. Domain Protection Services (ドメイン保護サービス)

### 6.1 境界コンテキスト保護

```go
// BoundaryProtector はドメイン境界を保護
type BoundaryProtector struct {
    domainInvariants []InvariantRule
    valueObjects     map[string]ValueObjectFactory
    aggregateRules   map[string][]BusinessRule
}

func (p *BoundaryProtector) ProtectIncoming(externalData interface{}) (interface{}, error) {
    // 外部データをドメインモデルに変換する前の保護処理
    
    // 1. 型安全性の確保
    validated, err := p.ensureTypeSafety(externalData)
    if err != nil {
        return nil, fmt.Errorf("type safety violation: %w", err)
    }
    
    // 2. ビジネス不変条件の事前チェック
    if err := p.checkInvariants(validated); err != nil {
        return nil, fmt.Errorf("invariant violation: %w", err)
    }
    
    // 3. 値オブジェクトの生成
    domainData, err := p.createValueObjects(validated)
    if err != nil {
        return nil, fmt.Errorf("value object creation failed: %w", err)
    }
    
    // 4. 集約ルールの適用
    if err := p.applyAggregateRules(domainData); err != nil {
        return nil, fmt.Errorf("aggregate rule violation: %w", err)
    }
    
    return domainData, nil
}

func (p *BoundaryProtector) ProtectOutgoing(domainData interface{}) (interface{}, error) {
    // ドメインモデルを外部形式に変換する際の保護処理
    
    // 1. 機密情報の除去
    sanitized := p.removeSensitiveData(domainData)
    
    // 2. 外部システム向けの正規化
    normalized := p.normalizeForExternal(sanitized)
    
    // 3. 必須フィールドの確認
    if err := p.ensureRequiredFields(normalized); err != nil {
        return nil, err
    }
    
    return normalized, nil
}

func (p *BoundaryProtector) checkInvariants(data interface{}) error {
    for _, rule := range p.domainInvariants {
        if err := rule.Check(data); err != nil {
            return fmt.Errorf("invariant '%s' violated: %w", rule.Name(), err)
        }
    }
    return nil
}
```

### 6.2 型変換サービス

```go
// TypeConverter は型安全な変換を提供
type TypeConverter struct {
    converters map[string]Converter
    fallbacks  map[string]interface{}
}

func (c *TypeConverter) ConvertToRemoteActor(external map[string]interface{}) (*domain.RemoteActor, error) {
    actor := &domain.RemoteActor{}
    
    // 必須フィールドの変換
    actor.ActorURI = c.ToString(external["id"], "")
    actor.Username = c.ToString(external["preferredUsername"], "unknown")
    actor.Domain = c.extractDomain(actor.ActorURI)
    
    // オプションフィールドの安全な変換
    actor.DisplayName = c.ToString(external["name"], actor.Username)
    actor.Summary = c.ToString(external["summary"], "")
    actor.IconURL = c.ToStringPtr(external["icon"])
    actor.HeaderURL = c.ToStringPtr(external["image"])
    
    // ネストされたオブジェクトの変換
    if publicKey, ok := external["publicKey"].(map[string]interface{}); ok {
        actor.PublicKeyPEM = c.ToString(publicKey["publicKeyPem"], "")
        actor.PublicKeyID = c.ToString(publicKey["id"], "")
    }
    
    // コレクションの変換
    actor.Followers = c.ToString(external["followers"], "")
    actor.Following = c.ToString(external["following"], "")
    actor.Inbox = c.ToString(external["inbox"], "")
    actor.Outbox = c.ToString(external["outbox"], "")
    
    // SharedInboxの処理（オプション）
    if sharedInbox, exists := external["endpoints"]; exists {
        if endpoints, ok := sharedInbox.(map[string]interface{}); ok {
            actor.SharedInbox = c.ToStringPtr(endpoints["sharedInbox"])
        }
    }
    
    return actor, nil
}

func (c *TypeConverter) ToString(value interface{}, defaultValue string) string {
    switch v := value.(type) {
    case string:
        return v
    case fmt.Stringer:
        return v.String()
    case nil:
        return defaultValue
    default:
        return fmt.Sprintf("%v", v)
    }
}

func (c *TypeConverter) ToStringPtr(value interface{}) *string {
    if value == nil {
        return nil
    }
    str := c.ToString(value, "")
    if str == "" {
        return nil
    }
    return &str
}
```

## 7. Error Transformation (エラー変換)

```go
// ErrorTransformer は外部エラーをドメインエラーに変換
type ErrorTransformer struct {
    errorMappings map[string]error
    fallbackError error
}

func (t *ErrorTransformer) TransformIncoming(externalErr error) error {
    // HTTP status codeからドメインエラーへの変換
    if httpErr, ok := externalErr.(*HTTPError); ok {
        switch httpErr.StatusCode {
        case 400:
            return domain.ErrInvalidRequest
        case 401:
            return domain.ErrUnauthorized
        case 403:
            return domain.ErrForbidden
        case 404:
            return domain.ErrActorNotFound
        case 410:
            return domain.ErrActorGone
        case 429:
            return domain.ErrRateLimited
        case 500, 502, 503, 504:
            return domain.ErrTemporaryFailure
        default:
            return t.fallbackError
        }
    }
    
    // ActivityPubエラーの変換
    if apErr, ok := externalErr.(*ActivityPubError); ok {
        if mapped, exists := t.errorMappings[apErr.Code]; exists {
            return mapped
        }
    }
    
    return fmt.Errorf("external error: %w", externalErr)
}

func (t *ErrorTransformer) TransformOutgoing(domainErr error) (int, map[string]interface{}) {
    // ドメインエラーをHTTPレスポンスに変換
    var statusCode int
    var errorBody map[string]interface{}
    
    switch {
    case errors.Is(domainErr, domain.ErrActorNotFound):
        statusCode = 404
        errorBody = map[string]interface{}{
            "error": "Actor not found",
            "code": "ACTOR_NOT_FOUND",
        }
        
    case errors.Is(domainErr, domain.ErrInvalidSignature):
        statusCode = 401
        errorBody = map[string]interface{}{
            "error": "Invalid HTTP signature",
            "code": "INVALID_SIGNATURE",
        }
        
    case errors.Is(domainErr, domain.ErrDomainBlocked):
        statusCode = 403
        errorBody = map[string]interface{}{
            "error": "Domain is blocked",
            "code": "DOMAIN_BLOCKED",
        }
        
    default:
        statusCode = 500
        errorBody = map[string]interface{}{
            "error": "Internal server error",
            "code": "INTERNAL_ERROR",
        }
    }
    
    return statusCode, errorBody
}
```

## 8. 統合テスト戦略

```go
// ACLIntegrationTest はACL層の統合テストを実施
func TestACLMastodonIntegration(t *testing.T) {
    acl := NewAntiCorruptionLayer()
    adapter := NewMastodonAdapter()
    
    t.Run("Group Actor to Person fallback", func(t *testing.T) {
        // Groupアクターを含むActivityの入力
        input := map[string]interface{}{
            "@context": "https://www.w3.org/ns/activitystreams",
            "type": "Group",
            "id": "https://avion.social/communities/tech",
            "name": "Tech Community",
            "inbox": "https://avion.social/communities/tech/inbox",
        }
        
        // ACLを通じた変換
        output, err := acl.TransformForPlatform(input, "mastodon")
        assert.NoError(t, err)
        
        // Person型にフォールバックされていることを確認
        assert.Equal(t, "Person", output["type"])
        assert.Contains(t, output["name"], "(Community)")
        assert.Contains(t, output["summary"], "Group Actor not supported")
    })
    
    t.Run("Custom emoji handling", func(t *testing.T) {
        input := map[string]interface{}{
            "content": "Hello :custom_emoji:",
            "tag": []interface{}{
                map[string]interface{}{
                    "type": "Emoji",
                    "name": ":custom_emoji:",
                    "icon": map[string]interface{}{
                        "url": "https://example.com/emoji.png",
                    },
                },
            },
        }
        
        domainObj, err := adapter.ToDomainObject(input)
        assert.NoError(t, err)
        
        // カスタム絵文字が適切に処理されていることを確認
        emojis := domainObj.GetMetadata("custom_emojis")
        assert.NotNil(t, emojis)
    })
}

func TestACLSecurityValidation(t *testing.T) {
    validator := NewSecurityValidator()
    
    t.Run("XSS prevention", func(t *testing.T) {
        maliciousInput := map[string]interface{}{
            "content": "<script>alert('XSS')</script>Hello",
        }
        
        err := validator.ValidateIncoming(maliciousInput, "192.168.1.1")
        assert.Error(t, err)
        assert.Contains(t, err.Error(), "script injection")
    })
    
    t.Run("Rate limiting", func(t *testing.T) {
        input := map[string]interface{}{"content": "Normal content"}
        sourceIP := "192.168.1.100"
        
        // 制限内のリクエスト
        for i := 0; i < 10; i++ {
            err := validator.ValidateIncoming(input, sourceIP)
            assert.NoError(t, err)
        }
        
        // 制限超過
        err := validator.ValidateIncoming(input, sourceIP)
        assert.Error(t, err)
        assert.Contains(t, err.Error(), "rate limit")
    })
}
```

## 9. パフォーマンス最適化

```go
// CachingAdapter はキャッシュ機能を持つアダプター
type CachingAdapter struct {
    PlatformAdapter
    cache           Cache
    cacheTTL        time.Duration
    cacheKeyPrefix  string
}

func (a *CachingAdapter) ToDomainActor(external map[string]interface{}) (*domain.RemoteActor, error) {
    // キャッシュキーの生成
    cacheKey := a.generateCacheKey("actor", external["id"])
    
    // キャッシュからの取得試行
    if cached, found := a.cache.Get(cacheKey); found {
        return cached.(*domain.RemoteActor), nil
    }
    
    // 基底アダプターで変換
    actor, err := a.PlatformAdapter.ToDomainActor(external)
    if err != nil {
        return nil, err
    }
    
    // キャッシュに保存
    a.cache.Set(cacheKey, actor, a.cacheTTL)
    
    return actor, nil
}

// BatchTranslator はバッチ処理最適化を提供
type BatchTranslator struct {
    translator      PlatformAdapter
    batchSize       int
    concurrency     int
}

func (t *BatchTranslator) TransformBatch(items []map[string]interface{}) ([]domain.Object, error) {
    results := make([]domain.Object, len(items))
    errors := make([]error, len(items))
    
    // 並行処理用のワーカープール
    sem := make(chan struct{}, t.concurrency)
    var wg sync.WaitGroup
    
    for i := range items {
        wg.Add(1)
        sem <- struct{}{}
        
        go func(index int) {
            defer wg.Done()
            defer func() { <-sem }()
            
            obj, err := t.translator.ToDomainObject(items[index])
            results[index] = obj
            errors[index] = err
        }(i)
    }
    
    wg.Wait()
    
    // エラー集約
    var errs []error
    for _, err := range errors {
        if err != nil {
            errs = append(errs, err)
        }
    }
    
    if len(errs) > 0 {
        return results, fmt.Errorf("batch transformation had %d errors", len(errs))
    }
    
    return results, nil
}
```

## 10. まとめ

このアンチコラプションレイヤーにより：

1. **ドメインモデルの純粋性**が保たれる
2. **プラットフォーム差異**が吸収される
3. **セキュリティ脅威**から保護される
4. **型安全性**が保証される
5. **テスト可能性**が向上する

各プラットフォーム固有の複雑性はACL内に封じ込められ、ドメインロジックは外部システムの詳細から完全に分離されます。