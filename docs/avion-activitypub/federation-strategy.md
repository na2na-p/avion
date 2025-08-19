# ActivityPub Federation Strategy (配信戦略)

**Author:** Claude
**Last Updated:** 2025-01-16
**Version:** 1.0

## 1. 概要

本ドキュメントは、avion-activitypubサービスにおける各プラットフォームとの相互運用性を最大化するための包括的な配信戦略を定義します。2024-2025年の最新実装状況に基づき、各ユースケースにおける最適な配信方法を規定します。

## 2. プラットフォーム検出ロジック

### 2.1 検出戦略

```go
package federation

import (
    "strings"
    "regexp"
    "net/http"
    "encoding/json"
)

type Platform string

const (
    PlatformMastodon   Platform = "mastodon"
    PlatformMisskey    Platform = "misskey"
    PlatformLemmy      Platform = "lemmy"
    PlatformPeerTube   Platform = "peertube"
    PlatformPixelfed   Platform = "pixelfed"
    PlatformPleroma    Platform = "pleroma"
    PlatformAkkoma     Platform = "akkoma"
    PlatformFriendica  Platform = "friendica"
    PlatformFirefish   Platform = "firefish"  // EOL but may still exist
    PlatformUnknown    Platform = "unknown"
)

type PlatformDetector struct {
    httpClient *http.Client
    cache      map[string]Platform
    logger     Logger
}

// DetectPlatform は複数の手法を組み合わせてプラットフォームを検出
func (d *PlatformDetector) DetectPlatform(domain string) Platform {
    // 1. キャッシュチェック
    if cached, exists := d.cache[domain]; exists {
        return cached
    }
    
    // 2. NodeInfo 2.0/2.1 チェック（最も信頼性が高い）
    if platform := d.detectViaNodeInfo(domain); platform != PlatformUnknown {
        d.cache[domain] = platform
        return platform
    }
    
    // 3. WebFinger レスポンスパターン分析
    if platform := d.detectViaWebFinger(domain); platform != PlatformUnknown {
        d.cache[domain] = platform
        return platform
    }
    
    // 4. Actor オブジェクトパターン分析
    if platform := d.detectViaActorPattern(domain); platform != PlatformUnknown {
        d.cache[domain] = platform
        return platform
    }
    
    // 5. HTTPヘッダー分析（フォールバック）
    if platform := d.detectViaHeaders(domain); platform != PlatformUnknown {
        d.cache[domain] = platform
        return platform
    }
    
    d.cache[domain] = PlatformUnknown
    return PlatformUnknown
}

// NodeInfo による検出（推奨）
func (d *PlatformDetector) detectViaNodeInfo(domain string) Platform {
    // NodeInfo discovery
    wellKnownURL := fmt.Sprintf("https://%s/.well-known/nodeinfo", domain)
    resp, err := d.httpClient.Get(wellKnownURL)
    if err != nil {
        return PlatformUnknown
    }
    defer resp.Body.Close()
    
    var discovery NodeInfoDiscovery
    if err := json.NewDecoder(resp.Body).Decode(&discovery); err != nil {
        return PlatformUnknown
    }
    
    // NodeInfo 2.0/2.1 優先
    for _, link := range discovery.Links {
        if strings.Contains(link.Rel, "nodeinfo/2") {
            nodeInfo, err := d.fetchNodeInfo(link.Href)
            if err != nil {
                continue
            }
            
            return d.parseSoftwareName(nodeInfo.Software.Name)
        }
    }
    
    return PlatformUnknown
}

// ソフトウェア名からプラットフォーム判定
func (d *PlatformDetector) parseSoftwareName(software string) Platform {
    software = strings.ToLower(software)
    
    switch {
    case strings.Contains(software, "mastodon"):
        return PlatformMastodon
    case strings.Contains(software, "misskey"):
        return PlatformMisskey
    case strings.Contains(software, "firefish"):
        return PlatformFirefish
    case strings.Contains(software, "lemmy"):
        return PlatformLemmy
    case strings.Contains(software, "peertube"):
        return PlatformPeerTube
    case strings.Contains(software, "pixelfed"):
        return PlatformPixelfed
    case strings.Contains(software, "pleroma"):
        return PlatformPleroma
    case strings.Contains(software, "akkoma"):
        return PlatformAkkoma
    case strings.Contains(software, "friendica"):
        return PlatformFriendica
    default:
        return PlatformUnknown
    }
}

// Actor パターンによる検出
func (d *PlatformDetector) detectViaActorPattern(domain string) Platform {
    // テストアカウントでActorオブジェクト取得
    testActor := d.fetchActorSample(domain)
    if testActor == nil {
        return PlatformUnknown
    }
    
    // プラットフォーム固有のフィールドチェック
    if _, hasMisskeyContent := testActor["_misskey_content"]; hasMisskeyContent {
        return PlatformMisskey
    }
    
    if endpoints, ok := testActor["endpoints"].(map[string]interface{}); ok {
        if _, hasSharedInbox := endpoints["sharedInbox"]; hasSharedInbox {
            // Featured collection チェック（Mastodon特有）
            if featured, hasFeatured := testActor["featured"]; hasFeatured {
                if strings.Contains(featured.(string), "/featured") {
                    return PlatformMastodon
                }
            }
        }
    }
    
    // Group Actor サポートチェック
    if actorType, ok := testActor["type"].(string); ok && actorType == "Group" {
        // Lemmy/PeerTube/Pixelfed候補
        if _, hasOutbox := testActor["outbox"]; hasOutbox {
            if _, hasFollowers := testActor["followers"]; hasFollowers {
                // さらに詳細な判定が必要
                return d.detectGroupPlatform(domain, testActor)
            }
        }
    }
    
    return PlatformUnknown
}
```

## 3. ユースケース別配信戦略

### 3.1 基本投稿（Create Activity）配信

```go
type CreateActivityStrategy struct {
    platformDetector *PlatformDetector
    activityBuilder  *ActivityBuilder
    logger           Logger
}

func (s *CreateActivityStrategy) PrepareActivity(
    drop *Drop,
    actor *Actor,
    targetDomain string,
) (*Activity, error) {
    platform := s.platformDetector.DetectPlatform(targetDomain)
    
    switch platform {
    case PlatformMastodon:
        return s.prepareMastodonCreate(drop, actor)
    case PlatformMisskey, PlatformFirefish:
        return s.prepareMisskeyCreate(drop, actor)
    case PlatformLemmy:
        return s.prepareLemmyCreate(drop, actor)
    case PlatformPixelfed:
        return s.preparePixelfedCreate(drop, actor)
    default:
        return s.prepareStandardCreate(drop, actor)
    }
}

// Mastodon向けCreate Activity
func (s *CreateActivityStrategy) prepareMastodonCreate(drop *Drop, actor *Actor) (*Activity, error) {
    activity := &Activity{
        Context: []interface{}{
            "https://www.w3.org/ns/activitystreams",
            map[string]interface{}{
                "ostatus":           "http://ostatus.org#",
                "atomUri":           "ostatus:atomUri",
                "inReplyToAtomUri":  "ostatus:inReplyToAtomUri",
                "conversation":      "ostatus:conversation",
                "sensitive":         "as:sensitive",
                "toot":              "http://joinmastodon.org/ns#",
                "votersCount":       "toot:votersCount",
                "blurhash":          "toot:blurhash",
                "focalPoint":        map[string]string{"@container": "@list", "@id": "toot:focalPoint"},
                "Hashtag":           "as:Hashtag",
                "Emoji":             "toot:Emoji",
            },
        },
        Type:      "Create",
        ID:        s.generateActivityID(),
        Actor:     actor.URI,
        Published: time.Now().Format(time.RFC3339),
        To:        s.determineAudience(drop),
        CC:        []string{actor.FollowersURI},
        Object:    s.buildMastodonNote(drop, actor),
    }
    
    return activity, nil
}

// Mastodon用Note オブジェクト
func (s *CreateActivityStrategy) buildMastodonNote(drop *Drop, actor *Actor) map[string]interface{} {
    note := map[string]interface{}{
        "type":         "Note",
        "id":           drop.URI,
        "attributedTo": actor.URI,
        "content":      s.convertToMastodonHTML(drop.Content),
        "published":    drop.CreatedAt.Format(time.RFC3339),
        "to":           s.determineAudience(drop),
        "cc":           []string{actor.FollowersURI},
        "sensitive":    drop.IsSensitive,
        "summary":      drop.ContentWarning, // CW対応
        "url":          drop.URL,
        "atomUri":      drop.URI, // Mastodon互換性
        "conversation": drop.ConversationURI,
    }
    
    // メンション処理
    if mentions := s.extractMentions(drop.Content); len(mentions) > 0 {
        note["tag"] = s.buildMastodonMentions(mentions)
    }
    
    // ハッシュタグ処理
    if hashtags := s.extractHashtags(drop.Content); len(hashtags) > 0 {
        tags := note["tag"].([]interface{})
        for _, tag := range s.buildMastodonHashtags(hashtags) {
            tags = append(tags, tag)
        }
        note["tag"] = tags
    }
    
    // カスタム絵文字処理
    if emojis := s.extractCustomEmojis(drop.Content); len(emojis) > 0 {
        tags := note["tag"].([]interface{})
        for _, emoji := range s.buildMastodonEmojis(emojis) {
            tags = append(tags, emoji)
        }
        note["tag"] = tags
    }
    
    // メディア添付
    if len(drop.Attachments) > 0 {
        note["attachment"] = s.buildMastodonAttachments(drop.Attachments)
    }
    
    // 投票機能
    if drop.Poll != nil {
        note["oneOf"] = s.buildMastodonPollOptions(drop.Poll)
        note["votersCount"] = drop.Poll.VotersCount
        note["endTime"] = drop.Poll.ExpiresAt.Format(time.RFC3339)
    }
    
    return note
}

// Misskey向けCreate Activity
func (s *CreateActivityStrategy) prepareMisskeyCreate(drop *Drop, actor *Actor) (*Activity, error) {
    activity := &Activity{
        Context: []interface{}{
            "https://www.w3.org/ns/activitystreams",
            "https://w3id.org/security/v1",
            map[string]interface{}{
                "misskey":           "https://misskey-hub.net/ns#",
                "_misskey_content":  "misskey:_misskey_content",
                "_misskey_quote":    "misskey:_misskey_quote",
                "_misskey_reaction": "misskey:_misskey_reaction",
                "_misskey_votes":    "misskey:_misskey_votes",
                "_misskey_summary":  "misskey:_misskey_summary",
                "isCat":             "misskey:isCat",
                "Hashtag":           "as:Hashtag",
                "sensitive":         "as:sensitive",
                "Emoji":             "toot:Emoji",
                "toot":              "http://joinmastodon.org/ns#",
            },
        },
        Type:      "Create",
        ID:        s.generateActivityID(),
        Actor:     actor.URI,
        Published: time.Now().Format(time.RFC3339),
        To:        s.determineAudience(drop),
        CC:        []string{actor.FollowersURI},
        Object:    s.buildMisskeyNote(drop, actor),
    }
    
    return activity, nil
}

// Misskey用Note オブジェクト
func (s *CreateActivityStrategy) buildMisskeyNote(drop *Drop, actor *Actor) map[string]interface{} {
    note := map[string]interface{}{
        "type":               "Note",
        "id":                 drop.URI,
        "attributedTo":       actor.URI,
        "content":            s.convertToMisskeyHTML(drop.Content),
        "_misskey_content":   drop.RawContent, // MFM保存
        "published":          drop.CreatedAt.Format(time.RFC3339),
        "to":                 s.determineAudience(drop),
        "cc":                 []string{actor.FollowersURI},
        "sensitive":          drop.IsSensitive,
        "_misskey_summary":   drop.ContentWarning,
        "url":                drop.URL,
    }
    
    // 引用投稿対応
    if drop.QuoteTargetURI != "" {
        note["_misskey_quote"] = drop.QuoteTargetURI
        note["quoteUrl"] = drop.QuoteTargetURI // 互換性
    }
    
    // カスタム絵文字リアクション用メタデータ
    if drop.AllowsReactions {
        note["_misskey_reaction"] = true
    }
    
    // 猫モード（ユーザー属性）
    if actor.IsCat {
        note["isCat"] = true
    }
    
    // 投票機能（Misskey形式）
    if drop.Poll != nil {
        note["_misskey_votes"] = s.buildMisskeyPollData(drop.Poll)
    }
    
    return note
}
```

### 3.2 コミュニティ機能（Group Actor）配信

```go
type CommunityActivityStrategy struct {
    platformDetector *PlatformDetector
    activityBuilder  *ActivityBuilder
    logger           Logger
}

// コミュニティ作成通知
func (s *CommunityActivityStrategy) PrepareCommunityAnnouncement(
    community *Community,
    targetDomain string,
) (*Activity, error) {
    platform := s.platformDetector.DetectPlatform(targetDomain)
    
    switch platform {
    case PlatformMastodon:
        // Mastodon: Group未対応のためPerson Actorとして配信
        return s.prepareMastodonFallback(community)
    
    case PlatformMisskey, PlatformFirefish:
        // Misskey: 部分的対応（チャンネル連携なし）
        return s.prepareMisskeyPartial(community)
    
    case PlatformLemmy:
        // Lemmy: 完全互換
        return s.prepareLemmyGroup(community)
    
    case PlatformPeerTube:
        // PeerTube: 完全互換（チャンネルとして解釈）
        return s.preparePeerTubeGroup(community)
    
    case PlatformPixelfed:
        // Pixelfed: グループ機能サポート（FEP-400e, FEP-1b12）
        return s.preparePixelfedGroup(community)
    
    case PlatformFriendica:
        // Friendica: グループ完全サポート
        return s.prepareFriendicaGroup(community)
    
    default:
        // 標準Group Actor配信
        return s.prepareStandardGroup(community)
    }
}

// Mastodon向けフォールバック（Person型として配信）
func (s *CommunityActivityStrategy) prepareMastodonFallback(community *Community) (*Activity, error) {
    // コミュニティをPerson型Actorとして表現
    personActor := map[string]interface{}{
        "@context": []interface{}{
            "https://www.w3.org/ns/activitystreams",
            "https://w3id.org/security/v1",
        },
        "type":              "Person", // Group未対応のためPerson
        "id":                community.ActorURI,
        "preferredUsername": community.Handle,
        "name":              fmt.Sprintf("%s (Community)", community.Name),
        "summary":           fmt.Sprintf("📚 Community: %s\n👥 Members: %d\n%s", 
                                        community.Name, 
                                        community.MemberCount, 
                                        community.Description),
        "url":               community.URL,
        "inbox":             community.InboxURI,
        "outbox":            community.OutboxURI,
        "followers":         community.FollowersURI,
        "following":         community.FollowingURI,
        "manuallyApprovesFollowers": community.RequiresApproval,
        "discoverable":      true,
        "publicKey": map[string]interface{}{
            "id":           community.ActorURI + "#main-key",
            "owner":        community.ActorURI,
            "publicKeyPem": community.PublicKey,
        },
        "icon": map[string]interface{}{
            "type":      "Image",
            "mediaType": "image/png",
            "url":       community.IconURL,
        },
        "image": map[string]interface{}{
            "type":      "Image",
            "mediaType": "image/jpeg",
            "url":       community.HeaderURL,
        },
        "endpoints": map[string]interface{}{
            "sharedInbox": "https://avion.social/inbox",
        },
        // カスタムプロパティ（Mastodonのprofile fieldsとして）
        "attachment": []interface{}{
            map[string]interface{}{
                "type":  "PropertyValue",
                "name":  "Type",
                "value": "Community Group",
            },
            map[string]interface{}{
                "type":  "PropertyValue",
                "name":  "Topics",
                "value": fmt.Sprintf("%d topics", len(community.Topics)),
            },
            map[string]interface{}{
                "type":  "PropertyValue",
                "name":  "Join",
                "value": fmt.Sprintf("<a href=\"%s/join\">Join Community</a>", community.URL),
            },
        },
    }
    
    return &Activity{
        Type:   "Update",
        ID:     s.generateActivityID(),
        Actor:  community.ActorURI,
        Object: personActor,
        To:     []string{"https://www.w3.org/ns/activitystreams#Public"},
        CC:     []string{community.FollowersURI},
    }, nil
}

// Lemmy向け完全Group Actor
func (s *CommunityActivityStrategy) prepareLemmyGroup(community *Community) (*Activity, error) {
    groupActor := map[string]interface{}{
        "@context": []interface{}{
            "https://www.w3.org/ns/activitystreams",
            "https://w3id.org/security/v1",
            map[string]interface{}{
                "lemmy": "https://join-lemmy.org/ns#",
                "sensitive": "as:sensitive",
                "moderators": "lemmy:moderators",
                "postingRestrictedToMods": "lemmy:postingRestrictedToMods",
            },
        },
        "type":              "Group", // Lemmy完全対応
        "id":                community.ActorURI,
        "preferredUsername": community.Handle,
        "name":              community.Name,
        "summary":           community.Description,
        "sensitive":         community.IsNSFW,
        "url":               community.URL,
        "inbox":             community.InboxURI,
        "outbox":            community.OutboxURI,
        "followers":         community.FollowersURI,
        "featured":          community.FeaturedURI,
        "moderators":        community.ModeratorsCollectionURI,
        "postingRestrictedToMods": community.RestrictedPosting,
        "publicKey": map[string]interface{}{
            "id":           community.ActorURI + "#main-key",
            "owner":        community.ActorURI,
            "publicKeyPem": community.PublicKey,
        },
        "endpoints": map[string]interface{}{
            "sharedInbox": "https://avion.social/inbox",
        },
    }
    
    if community.Icon != nil {
        groupActor["icon"] = map[string]interface{}{
            "type":      "Image",
            "url":       community.IconURL,
        }
    }
    
    if community.Banner != nil {
        groupActor["image"] = map[string]interface{}{
            "type":      "Image",
            "url":       community.BannerURL,
        }
    }
    
    return &Activity{
        Type:   "Announce",
        ID:     s.generateActivityID(),
        Actor:  community.ActorURI,
        Object: groupActor,
        To:     []string{"https://www.w3.org/ns/activitystreams#Public"},
        CC:     []string{community.FollowersURI},
    }, nil
}
```

### 3.3 リアクション配信

```go
type ReactionActivityStrategy struct {
    platformDetector *PlatformDetector
    activityBuilder  *ActivityBuilder
}

func (s *ReactionActivityStrategy) PrepareReaction(
    reaction *Reaction,
    targetDomain string,
) (*Activity, error) {
    platform := s.platformDetector.DetectPlatform(targetDomain)
    
    switch platform {
    case PlatformMastodon:
        // Mastodon: Like のみ（カスタム絵文字リアクション未対応）
        return s.prepareMastodonLike(reaction)
    
    case PlatformMisskey, PlatformFirefish:
        // Misskey: カスタム絵文字リアクション完全対応
        return s.prepareMisskeyReaction(reaction)
    
    case PlatformPleroma, PlatformAkkoma:
        // Pleroma/Akkoma: EmojiReact対応
        return s.preparePleromaEmojiReact(reaction)
    
    case PlatformPixelfed:
        // Pixelfed: Like + カスタム絵文字サポート
        return s.preparePixelfedReaction(reaction)
    
    default:
        // 標準Like
        return s.prepareStandardLike(reaction)
    }
}

// Misskey向けカスタム絵文字リアクション
func (s *ReactionActivityStrategy) prepareMisskeyReaction(reaction *Reaction) (*Activity, error) {
    activity := &Activity{
        Context: []interface{}{
            "https://www.w3.org/ns/activitystreams",
            map[string]interface{}{
                "misskey": "https://misskey-hub.net/ns#",
                "_misskey_reaction": "misskey:_misskey_reaction",
            },
        },
        Type:   "Like",
        ID:     s.generateActivityID(),
        Actor:  reaction.ActorURI,
        Object: reaction.TargetURI,
    }
    
    // カスタム絵文字リアクション
    if reaction.IsCustomEmoji {
        activity.Content = reaction.EmojiCode // :emoji_name:
        activity.Extensions = map[string]interface{}{
            "_misskey_reaction": reaction.EmojiCode,
        }
        
        // 絵文字定義を含める
        activity.Tag = []interface{}{
            map[string]interface{}{
                "type": "Emoji",
                "name": reaction.EmojiCode,
                "icon": map[string]interface{}{
                    "type":      "Image",
                    "mediaType": "image/png",
                    "url":       reaction.EmojiImageURL,
                },
            },
        }
    }
    
    return activity, nil
}

// Pleroma/Akkoma向けEmojiReact
func (s *ReactionActivityStrategy) preparePleromaEmojiReact(reaction *Reaction) (*Activity, error) {
    if reaction.IsCustomEmoji {
        return &Activity{
            Context: "https://www.w3.org/ns/activitystreams",
            Type:    "EmojiReact", // Pleroma独自
            ID:      s.generateActivityID(),
            Actor:   reaction.ActorURI,
            Object:  reaction.TargetURI,
            Content: reaction.EmojiCode,
            Tag: []interface{}{
                map[string]interface{}{
                    "type": "Emoji",
                    "name": reaction.EmojiCode,
                    "icon": map[string]interface{}{
                        "type": "Image",
                        "url":  reaction.EmojiImageURL,
                    },
                },
            },
        }, nil
    }
    
    // 通常のLike
    return s.prepareStandardLike(reaction)
}
```

### 3.4 メンション・返信配信

```go
type MentionReplyStrategy struct {
    platformDetector *PlatformDetector
    activityBuilder  *ActivityBuilder
}

func (s *MentionReplyStrategy) PrepareReply(
    reply *Drop,
    targetDomain string,
) (*Activity, error) {
    platform := s.platformDetector.DetectPlatform(targetDomain)
    
    note := s.buildBaseReplyNote(reply)
    
    switch platform {
    case PlatformMastodon:
        s.addMastodonReplyFields(note, reply)
    
    case PlatformMisskey:
        s.addMisskeyReplyFields(note, reply)
    
    case PlatformLemmy:
        s.addLemmyCommentFields(note, reply)
    
    case PlatformFriendica:
        s.addFriendicaThreadFields(note, reply)
    }
    
    return s.wrapInCreateActivity(note), nil
}

// Mastodon向け返信フィールド
func (s *MentionReplyStrategy) addMastodonReplyFields(note map[string]interface{}, reply *Drop) {
    note["inReplyTo"] = reply.InReplyToURI
    note["inReplyToAtomUri"] = reply.InReplyToURI // 互換性
    note["conversation"] = reply.ConversationURI
    
    // メンション処理（必須）
    mentions := []interface{}{}
    for _, mention := range reply.Mentions {
        mentions = append(mentions, map[string]interface{}{
            "type": "Mention",
            "href": mention.ActorURI,
            "name": mention.Handle, // @username@domain
        })
    }
    
    if tags, ok := note["tag"].([]interface{}); ok {
        note["tag"] = append(tags, mentions...)
    } else {
        note["tag"] = mentions
    }
}

// Lemmy向けコメントフィールド
func (s *MentionReplyStrategy) addLemmyCommentFields(note map[string]interface{}, reply *Drop) {
    // LemmyではコメントはNoteとして扱われる
    note["inReplyTo"] = reply.InReplyToURI
    
    // コミュニティコンテキストが必要
    if reply.CommunityURI != "" {
        note["audience"] = reply.CommunityURI
        note["to"] = []string{reply.CommunityURI}
        note["cc"] = append(note["cc"].([]string), "https://www.w3.org/ns/activitystreams#Public")
    }
}
```

### 3.5 メディア配信戦略

```go
type MediaAttachmentStrategy struct {
    platformDetector *PlatformDetector
    mediaProcessor   *MediaProcessor
}

func (s *MediaAttachmentStrategy) PrepareAttachments(
    attachments []Media,
    targetDomain string,
) []interface{} {
    platform := s.platformDetector.DetectPlatform(targetDomain)
    
    switch platform {
    case PlatformMastodon:
        return s.prepareMastodonAttachments(attachments)
    
    case PlatformPixelfed:
        return s.preparePixelfedAttachments(attachments)
    
    case PlatformPeerTube:
        return s.preparePeerTubeAttachments(attachments)
    
    default:
        return s.prepareStandardAttachments(attachments)
    }
}

// Mastodon向けメディア
func (s *MediaAttachmentStrategy) prepareMastodonAttachments(attachments []Media) []interface{} {
    result := []interface{}{}
    
    for _, media := range attachments {
        attachment := map[string]interface{}{
            "type":      s.getAttachmentType(media),
            "mediaType": media.MimeType,
            "url":       media.URL,
            "name":      media.Description, // alt text
        }
        
        // Blurhash（プレビュー）
        if media.Blurhash != "" {
            attachment["blurhash"] = media.Blurhash
        }
        
        // フォーカルポイント（画像の重要部分）
        if media.FocalPoint != nil {
            attachment["focalPoint"] = []float64{
                media.FocalPoint.X,
                media.FocalPoint.Y,
            }
        }
        
        // 動画の場合
        if media.Type == MediaTypeVideo {
            attachment["width"] = media.Width
            attachment["height"] = media.Height
            attachment["duration"] = media.Duration
        }
        
        result = append(result, attachment)
    }
    
    return result
}

// PeerTube向け動画メディア
func (s *MediaAttachmentStrategy) preparePeerTubeAttachments(attachments []Media) []interface{} {
    result := []interface{}{}
    
    for _, media := range attachments {
        if media.Type == MediaTypeVideo {
            // PeerTubeは複数解像度をサポート
            attachment := map[string]interface{}{
                "type":      "Video",
                "mediaType": media.MimeType,
                "url": []interface{}{
                    map[string]interface{}{
                        "type":      "Link",
                        "mediaType": "video/mp4",
                        "href":      media.URL,
                        "height":    media.Height,
                        "width":     media.Width,
                        "size":      media.Size,
                        "fps":       media.FPS,
                    },
                },
                "duration": fmt.Sprintf("PT%dS", media.Duration),
                "views":    media.ViewCount,
                "support":  media.SupportURL, // 投げ銭URL
            }
            
            // 字幕トラック
            if len(media.Subtitles) > 0 {
                subtitles := []interface{}{}
                for _, sub := range media.Subtitles {
                    subtitles = append(subtitles, map[string]interface{}{
                        "type":         "Link",
                        "mediaType":    "text/vtt",
                        "href":         sub.URL,
                        "hreflang":     sub.Language,
                        "name":         sub.Label,
                    })
                }
                attachment["subtitleLanguage"] = subtitles
            }
            
            result = append(result, attachment)
        } else {
            // 動画以外は標準形式
            result = append(result, s.prepareStandardAttachment(media))
        }
    }
    
    return result
}
```

## 4. セキュリティ・認証戦略

```go
type SecurityStrategy struct {
    platformDetector *PlatformDetector
    keyManager       *KeyManager
}

// HTTP Signature戦略
func (s *SecurityStrategy) PrepareHTTPSignature(
    request *http.Request,
    targetDomain string,
) error {
    platform := s.platformDetector.DetectPlatform(targetDomain)
    
    // 基本的なヘッダー
    headers := []string{"(request-target)", "host", "date"}
    
    switch platform {
    case PlatformMastodon:
        // Mastodon: Digest必須
        headers = append(headers, "digest")
        if request.Method == "POST" {
            s.addDigestHeader(request)
        }
    
    case PlatformPixelfed:
        // Pixelfed: 厳格な検証
        headers = append(headers, "digest", "content-type")
        s.addDigestHeader(request)
    
    case PlatformLemmy:
        // Lemmy: 標準的な実装
        if request.Method == "POST" {
            headers = append(headers, "digest")
            s.addDigestHeader(request)
        }
    }
    
    return s.signRequest(request, headers)
}

// Authorized Fetch（Mastodon Secure Mode）対応
func (s *SecurityStrategy) PrepareAuthorizedFetch(
    request *http.Request,
    targetDomain string,
) error {
    platform := s.platformDetector.DetectPlatform(targetDomain)
    
    // Mastodon Secure Mode チェック
    if platform == PlatformMastodon {
        if s.isSecureMode(targetDomain) {
            // GETリクエストにも署名が必要
            return s.PrepareHTTPSignature(request, targetDomain)
        }
    }
    
    return nil
}
```

## 5. エラーハンドリング・フォールバック戦略

```go
type FallbackStrategy struct {
    platformDetector *PlatformDetector
    logger           Logger
}

// 配信失敗時のフォールバック
func (s *FallbackStrategy) HandleDeliveryFailure(
    activity *Activity,
    targetDomain string,
    err error,
) (*Activity, error) {
    platform := s.platformDetector.DetectPlatform(targetDomain)
    
    // エラーコード解析
    httpErr, isHTTPError := err.(*HTTPError)
    if !isHTTPError {
        return nil, err
    }
    
    switch httpErr.StatusCode {
    case 400: // Bad Request
        // フォーマット問題の可能性
        return s.simplifyActivity(activity, platform)
    
    case 401: // Unauthorized
        // 認証問題
        if platform == PlatformMastodon {
            // Secure Mode の可能性
            return nil, ErrRequiresAuthorizedFetch
        }
    
    case 422: // Unprocessable Entity
        // バリデーションエラー
        return s.removeUnsupportedFields(activity, platform)
    
    case 406: // Not Acceptable
        // Content-Type問題
        return s.adjustContentType(activity, platform)
    }
    
    return nil, err
}

// アクティビティの簡素化
func (s *FallbackStrategy) simplifyActivity(
    activity *Activity,
    platform Platform,
) (*Activity, error) {
    simplified := &Activity{
        Context: "https://www.w3.org/ns/activitystreams",
        Type:    activity.Type,
        ID:      activity.ID,
        Actor:   activity.Actor,
        Object:  activity.Object,
        To:      activity.To,
        CC:      activity.CC,
    }
    
    // プラットフォーム別の必須フィールドのみ保持
    switch platform {
    case PlatformMastodon:
        // 最小限のフィールドセット
        if note, ok := simplified.Object.(map[string]interface{}); ok {
            minimalNote := map[string]interface{}{
                "type":         note["type"],
                "id":           note["id"],
                "attributedTo": note["attributedTo"],
                "content":      note["content"],
                "published":    note["published"],
                "to":           note["to"],
                "cc":           note["cc"],
            }
            simplified.Object = minimalNote
        }
    }
    
    return simplified, nil
}
```

## 6. 監視・メトリクス戦略

```go
type MetricsStrategy struct {
    platformDetector *PlatformDetector
    metricsCollector *MetricsCollector
}

// プラットフォーム別メトリクス収集
func (s *MetricsStrategy) RecordDelivery(
    platform Platform,
    activityType string,
    success bool,
    duration time.Duration,
) {
    labels := prometheus.Labels{
        "platform":      string(platform),
        "activity_type": activityType,
        "status":        s.getStatus(success),
    }
    
    // 配信成功率
    s.metricsCollector.DeliveryRate.With(labels).Inc()
    
    // レイテンシ
    s.metricsCollector.DeliveryDuration.With(labels).Observe(duration.Seconds())
    
    // プラットフォーム別の特殊メトリクス
    switch platform {
    case PlatformMastodon:
        if activityType == "Create" {
            s.metricsCollector.MastodonNoteDeliveries.Inc()
        }
    
    case PlatformLemmy:
        if activityType == "Group" {
            s.metricsCollector.LemmyCommunityActivities.Inc()
        }
    }
}

// エラー率の追跡
func (s *MetricsStrategy) RecordError(
    platform Platform,
    errorType string,
    errorCode int,
) {
    labels := prometheus.Labels{
        "platform":    string(platform),
        "error_type":  errorType,
        "error_code":  fmt.Sprintf("%d", errorCode),
    }
    
    s.metricsCollector.ErrorRate.With(labels).Inc()
    
    // アラート閾値チェック
    if s.shouldAlert(platform, errorType) {
        s.triggerAlert(platform, errorType, errorCode)
    }
}
```

## 7. テスト戦略

```go
package federation_test

import (
    "testing"
    "github.com/stretchr/testify/assert"
)

func TestPlatformDetection(t *testing.T) {
    tests := []struct {
        name     string
        domain   string
        expected Platform
    }{
        {
            name:     "Mastodon instance",
            domain:   "mastodon.social",
            expected: PlatformMastodon,
        },
        {
            name:     "Misskey instance",
            domain:   "misskey.io",
            expected: PlatformMisskey,
        },
        {
            name:     "Lemmy instance",
            domain:   "lemmy.ml",
            expected: PlatformLemmy,
        },
    }
    
    detector := NewPlatformDetector()
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := detector.DetectPlatform(tt.domain)
            assert.Equal(t, tt.expected, result)
        })
    }
}

func TestActivityPreparation(t *testing.T) {
    // 各プラットフォーム向けのアクティビティ生成テスト
    platforms := []Platform{
        PlatformMastodon,
        PlatformMisskey,
        PlatformLemmy,
        PlatformPeerTube,
        PlatformPixelfed,
    }
    
    for _, platform := range platforms {
        t.Run(string(platform), func(t *testing.T) {
            strategy := NewCreateActivityStrategy()
            drop := &Drop{
                Content: "Test content",
                // ... other fields
            }
            
            activity, err := strategy.PrepareActivity(drop, &Actor{}, "test.domain")
            
            assert.NoError(t, err)
            assert.NotNil(t, activity)
            
            // プラットフォーム固有のフィールド検証
            switch platform {
            case PlatformMastodon:
                assert.Contains(t, activity.Context, "ostatus")
            case PlatformMisskey:
                assert.Contains(t, activity.Context, "misskey")
            }
        })
    }
}
```

## 8. 実装優先順位

### Phase 1: Core Platforms (必須)
1. **Mastodon**: 最大のユーザーベース
2. **Misskey**: 日本市場で重要
3. **Lemmy**: Group機能のリファレンス実装

### Phase 2: Extended Platforms (推奨)
1. **Pixelfed**: 画像共有
2. **PeerTube**: 動画共有
3. **Pleroma/Akkoma**: 軽量実装

### Phase 3: Additional Platforms (オプション)
1. **Friendica**: 多プロトコル対応
2. **BookWyrm**: 書籍レビュー
3. **Mobilizon**: イベント管理

## 9. まとめ

本配信戦略により、avion-activitypubは主要なActivityPubプラットフォームとの最大限の相互運用性を実現します。プラットフォーム検出、適応的なアクティビティ生成、エラーハンドリング、メトリクス収集を通じて、堅牢で拡張可能な連合システムを構築します。