# XSS Prevention and CSP Implementation Guide

**Last Updated:** 2025/08/30  
**Status:** Security Implementation Guide  
**Scope:** API Gateway, all microservices, and React SPA

## Overview

This document provides comprehensive XSS (Cross-Site Scripting) prevention strategies and Content Security Policy (CSP) implementation for the Avion platform, with specific focus on API responses, SPA security, and nonce-based CSP with Redis integration.

## Table of Contents

1. [XSS Attack Vectors in APIs and SPAs](#xss-attack-vectors-in-apis-and-spas)
2. [Content Security Policy Implementation](#content-security-policy-implementation)
3. [Nonce-Based CSP with Redis](#nonce-based-csp-with-redis)
4. [Output Encoding for Different Contexts](#output-encoding-for-different-contexts)
5. [Avion Gateway Implementation](#avion-gateway-implementation)
6. [React Frontend Integration](#react-frontend-integration)
7. [Testing Strategy](#testing-strategy)
8. [CSP Violation Reporting](#csp-violation-reporting)

## XSS Attack Vectors in APIs and SPAs

### API-Specific Attack Vectors

1. **JSON Response Injection**
   - Malicious content in API responses rendered without sanitization
   - JavaScript execution through improper JSON parsing
   - DOM-based XSS through client-side template injection

2. **GraphQL Query Injection**
   - Malicious payloads in GraphQL queries/mutations
   - Unsafe field resolution leading to script injection
   - Subscription-based real-time XSS attacks

3. **WebSocket Message Injection**
   - Real-time message payloads containing scripts
   - Event-driven XSS through SSE (Server-Sent Events)

4. **File Upload Vectors**
   - SVG files with embedded scripts
   - HTML files served with incorrect Content-Type
   - Polyglot files exploiting content sniffing

### SPA-Specific Vulnerabilities

1. **Client-Side Routing XSS**
   - Hash-based routing manipulation
   - Query parameter injection
   - History API manipulation

2. **State Management XSS**
   - Redux/Context state pollution
   - LocalStorage/SessionStorage injection
   - IndexedDB manipulation

3. **Third-Party Integration Risks**
   - CDN compromise
   - npm package vulnerabilities
   - Analytics script injection

## Content Security Policy Implementation

### CSP Strategy for Avion

```go
package middleware

import (
    "context"
    "crypto/rand"
    "encoding/base64"
    "encoding/json"
    "fmt"
    "net/http"
    "strings"
    "time"
    
    "github.com/redis/go-redis/v9"
)

// CSPConfig defines comprehensive CSP configuration
type CSPConfig struct {
    // Core directives
    DefaultSrc     []string `json:"default_src"`
    ScriptSrc      []string `json:"script_src"`
    StyleSrc       []string `json:"style_src"`
    ImgSrc         []string `json:"img_src"`
    FontSrc        []string `json:"font_src"`
    ConnectSrc     []string `json:"connect_src"`
    MediaSrc       []string `json:"media_src"`
    ObjectSrc      []string `json:"object_src"`
    FrameSrc       []string `json:"frame_src"`
    WorkerSrc      []string `json:"worker_src"`
    ManifestSrc    []string `json:"manifest_src"`
    
    // Navigation directives
    FrameAncestors []string `json:"frame_ancestors"`
    BaseURI        []string `json:"base_uri"`
    FormAction     []string `json:"form_action"`
    
    // Security features
    UpgradeInsecureRequests bool `json:"upgrade_insecure_requests"`
    BlockAllMixedContent    bool `json:"block_all_mixed_content"`
    
    // Trusted Types (for modern browsers)
    RequireTrustedTypesFor []string `json:"require_trusted_types_for"`
    TrustedTypes          []string `json:"trusted_types"`
    
    // Reporting
    ReportURI  string `json:"report_uri"`
    ReportTo   string `json:"report_to"`
    
    // Nonce configuration
    UseNonce      bool          `json:"use_nonce"`
    NonceLength   int           `json:"nonce_length"`
    NonceTTL      time.Duration `json:"nonce_ttl"`
    
    // Mode
    ReportOnly bool `json:"report_only"`
    Enabled    bool `json:"enabled"`
}

// CSPMiddleware implements advanced CSP with Redis-backed nonce management
type CSPMiddleware struct {
    config      CSPConfig
    redisClient *redis.Client
    nonceCache  *NonceCache
}

// NonceCache manages CSP nonces with Redis
type NonceCache struct {
    client *redis.Client
    prefix string
    ttl    time.Duration
}

func NewNonceCache(client *redis.Client, ttl time.Duration) *NonceCache {
    return &NonceCache{
        client: client,
        prefix: "csp:nonce:",
        ttl:    ttl,
    }
}

func (nc *NonceCache) Generate(ctx context.Context) (string, error) {
    // Generate cryptographically secure nonce
    b := make([]byte, 16)
    if _, err := rand.Read(b); err != nil {
        return "", fmt.Errorf("failed to generate nonce: %w", err)
    }
    
    nonce := base64.StdEncoding.EncodeToString(b)
    
    // Store in Redis with TTL
    key := nc.prefix + nonce
    if err := nc.client.Set(ctx, key, time.Now().Unix(), nc.ttl).Err(); err != nil {
        return "", fmt.Errorf("failed to store nonce: %w", err)
    }
    
    return nonce, nil
}

func (nc *NonceCache) Validate(ctx context.Context, nonce string) (bool, error) {
    key := nc.prefix + nonce
    
    // Check if nonce exists
    exists, err := nc.client.Exists(ctx, key).Result()
    if err != nil {
        return false, fmt.Errorf("failed to validate nonce: %w", err)
    }
    
    if exists == 0 {
        return false, nil
    }
    
    // Delete after validation (one-time use)
    nc.client.Del(ctx, key)
    
    return true, nil
}

func NewCSPMiddleware(config CSPConfig, redisClient *redis.Client) *CSPMiddleware {
    if config.NonceLength == 0 {
        config.NonceLength = 16
    }
    if config.NonceTTL == 0 {
        config.NonceTTL = 15 * time.Minute
    }
    
    return &CSPMiddleware{
        config:      config,
        redisClient: redisClient,
        nonceCache:  NewNonceCache(redisClient, config.NonceTTL),
    }
}

func (m *CSPMiddleware) Handler(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        if !m.config.Enabled {
            next.ServeHTTP(w, r)
            return
        }
        
        ctx := r.Context()
        
        // Generate nonce if enabled
        var nonce string
        if m.config.UseNonce {
            var err error
            nonce, err = m.nonceCache.Generate(ctx)
            if err != nil {
                // Log error but continue without nonce
                fmt.Printf("CSP nonce generation failed: %v\n", err)
            } else {
                // Store nonce in context for use in templates/responses
                ctx = context.WithValue(ctx, CSPNonceKey, nonce)
                r = r.WithContext(ctx)
                
                // Add nonce to response header for SPA
                w.Header().Set("X-CSP-Nonce", nonce)
            }
        }
        
        // Build and set CSP header
        policy := m.buildPolicy(nonce)
        headerName := "Content-Security-Policy"
        if m.config.ReportOnly {
            headerName = "Content-Security-Policy-Report-Only"
        }
        w.Header().Set(headerName, policy)
        
        // Set additional security headers
        m.setSecurityHeaders(w)
        
        // Set Report-To header if configured
        if m.config.ReportTo != "" {
            m.setReportToHeader(w)
        }
        
        next.ServeHTTP(w, r)
    })
}

func (m *CSPMiddleware) buildPolicy(nonce string) string {
    var directives []string
    
    // Helper function to build directive with nonce
    buildDirective := func(name string, sources []string, includeNonce bool) string {
        if len(sources) == 0 {
            return ""
        }
        
        values := make([]string, len(sources))
        copy(values, sources)
        
        if includeNonce && nonce != "" {
            values = append(values, fmt.Sprintf("'nonce-%s'", nonce))
        }
        
        return fmt.Sprintf("%s %s", name, strings.Join(values, " "))
    }
    
    // Core directives
    if dir := buildDirective("default-src", m.config.DefaultSrc, false); dir != "" {
        directives = append(directives, dir)
    }
    
    // Script and style with nonce support
    if dir := buildDirective("script-src", m.config.ScriptSrc, true); dir != "" {
        directives = append(directives, dir)
    }
    
    if dir := buildDirective("style-src", m.config.StyleSrc, true); dir != "" {
        directives = append(directives, dir)
    }
    
    // Resource directives
    if dir := buildDirective("img-src", m.config.ImgSrc, false); dir != "" {
        directives = append(directives, dir)
    }
    
    if dir := buildDirective("font-src", m.config.FontSrc, false); dir != "" {
        directives = append(directives, dir)
    }
    
    if dir := buildDirective("connect-src", m.config.ConnectSrc, false); dir != "" {
        directives = append(directives, dir)
    }
    
    if dir := buildDirective("media-src", m.config.MediaSrc, false); dir != "" {
        directives = append(directives, dir)
    }
    
    if dir := buildDirective("object-src", m.config.ObjectSrc, false); dir != "" {
        directives = append(directives, dir)
    }
    
    if dir := buildDirective("frame-src", m.config.FrameSrc, false); dir != "" {
        directives = append(directives, dir)
    }
    
    if dir := buildDirective("worker-src", m.config.WorkerSrc, false); dir != "" {
        directives = append(directives, dir)
    }
    
    if dir := buildDirective("manifest-src", m.config.ManifestSrc, false); dir != "" {
        directives = append(directives, dir)
    }
    
    // Navigation directives
    if dir := buildDirective("frame-ancestors", m.config.FrameAncestors, false); dir != "" {
        directives = append(directives, dir)
    }
    
    if dir := buildDirective("base-uri", m.config.BaseURI, false); dir != "" {
        directives = append(directives, dir)
    }
    
    if dir := buildDirective("form-action", m.config.FormAction, false); dir != "" {
        directives = append(directives, dir)
    }
    
    // Trusted Types (experimental but important for XSS prevention)
    if len(m.config.RequireTrustedTypesFor) > 0 {
        directives = append(directives, fmt.Sprintf("require-trusted-types-for %s", 
            strings.Join(m.config.RequireTrustedTypesFor, " ")))
    }
    
    if len(m.config.TrustedTypes) > 0 {
        directives = append(directives, fmt.Sprintf("trusted-types %s",
            strings.Join(m.config.TrustedTypes, " ")))
    }
    
    // Security features
    if m.config.UpgradeInsecureRequests {
        directives = append(directives, "upgrade-insecure-requests")
    }
    
    if m.config.BlockAllMixedContent {
        directives = append(directives, "block-all-mixed-content")
    }
    
    // Reporting
    if m.config.ReportURI != "" {
        directives = append(directives, fmt.Sprintf("report-uri %s", m.config.ReportURI))
    }
    
    if m.config.ReportTo != "" {
        directives = append(directives, fmt.Sprintf("report-to %s", m.config.ReportTo))
    }
    
    return strings.Join(directives, "; ")
}

func (m *CSPMiddleware) setSecurityHeaders(w http.ResponseWriter) {
    // Prevent MIME type sniffing
    w.Header().Set("X-Content-Type-Options", "nosniff")
    
    // Prevent clickjacking
    w.Header().Set("X-Frame-Options", "DENY")
    
    // XSS Protection (legacy but still useful for older browsers)
    w.Header().Set("X-XSS-Protection", "1; mode=block")
    
    // Referrer Policy
    w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
    
    // Permissions Policy (replaces Feature Policy)
    w.Header().Set("Permissions-Policy", "geolocation=(), microphone=(), camera=()")
    
    // HSTS for production
    if !m.config.ReportOnly {
        w.Header().Set("Strict-Transport-Security", "max-age=63072000; includeSubDomains; preload")
    }
}

func (m *CSPMiddleware) setReportToHeader(w http.ResponseWriter) {
    reportTo := map[string]interface{}{
        "group": m.config.ReportTo,
        "max_age": 10886400, // 126 days
        "endpoints": []map[string]string{
            {
                "url": m.config.ReportURI,
            },
        },
        "include_subdomains": true,
    }
    
    reportToJSON, _ := json.Marshal([]interface{}{reportTo})
    w.Header().Set("Report-To", string(reportToJSON))
}

// CSPNonceKey is the context key for CSP nonce
type contextKey string

const CSPNonceKey contextKey = "csp-nonce"

// GetCSPNonce retrieves the CSP nonce from context
func GetCSPNonce(ctx context.Context) string {
    if nonce, ok := ctx.Value(CSPNonceKey).(string); ok {
        return nonce
    }
    return ""
}
```

## Nonce-Based CSP with Redis

### Redis-Backed Nonce Management

```go
package security

import (
    "context"
    "crypto/subtle"
    "fmt"
    "time"
    
    "github.com/redis/go-redis/v9"
)

// NonceManager provides comprehensive nonce management with Redis
type NonceManager struct {
    redis       *redis.Client
    prefix      string
    ttl         time.Duration
    maxAttempts int
}

func NewNonceManager(redisClient *redis.Client) *NonceManager {
    return &NonceManager{
        redis:       redisClient,
        prefix:      "avion:csp:nonce:",
        ttl:         15 * time.Minute,
        maxAttempts: 3,
    }
}

// GenerateNonceWithMetadata generates a nonce with associated metadata
func (nm *NonceManager) GenerateNonceWithMetadata(ctx context.Context, metadata NonceMetadata) (*Nonce, error) {
    nonce := &Nonce{
        Value:     generateSecureNonce(),
        CreatedAt: time.Now(),
        ExpiresAt: time.Now().Add(nm.ttl),
        Metadata:  metadata,
    }
    
    // Store in Redis with metadata
    key := nm.prefix + nonce.Value
    data, err := json.Marshal(nonce)
    if err != nil {
        return nil, fmt.Errorf("failed to marshal nonce: %w", err)
    }
    
    if err := nm.redis.Set(ctx, key, data, nm.ttl).Err(); err != nil {
        return nil, fmt.Errorf("failed to store nonce: %w", err)
    }
    
    // Track active nonces for monitoring
    nm.trackNonce(ctx, nonce.Value)
    
    return nonce, nil
}

// ValidateAndConsume validates a nonce and marks it as consumed
func (nm *NonceManager) ValidateAndConsume(ctx context.Context, nonceValue string) (*Nonce, error) {
    key := nm.prefix + nonceValue
    
    // Get nonce data
    data, err := nm.redis.Get(ctx, key).Bytes()
    if err == redis.Nil {
        return nil, ErrNonceNotFound
    }
    if err != nil {
        return nil, fmt.Errorf("failed to get nonce: %w", err)
    }
    
    var nonce Nonce
    if err := json.Unmarshal(data, &nonce); err != nil {
        return nil, fmt.Errorf("failed to unmarshal nonce: %w", err)
    }
    
    // Check expiration
    if time.Now().After(nonce.ExpiresAt) {
        nm.redis.Del(ctx, key)
        return nil, ErrNonceExpired
    }
    
    // Check if already consumed
    if nonce.ConsumedAt != nil {
        return nil, ErrNonceAlreadyUsed
    }
    
    // Mark as consumed
    now := time.Now()
    nonce.ConsumedAt = &now
    
    // Update in Redis (keep for audit trail)
    updatedData, _ := json.Marshal(nonce)
    nm.redis.Set(ctx, key, updatedData, time.Until(nonce.ExpiresAt))
    
    return &nonce, nil
}

// CleanupExpiredNonces removes expired nonces from Redis
func (nm *NonceManager) CleanupExpiredNonces(ctx context.Context) error {
    pattern := nm.prefix + "*"
    iter := nm.redis.Scan(ctx, 0, pattern, 100).Iterator()
    
    var expiredKeys []string
    for iter.Next(ctx) {
        key := iter.Val()
        data, err := nm.redis.Get(ctx, key).Bytes()
        if err != nil {
            continue
        }
        
        var nonce Nonce
        if err := json.Unmarshal(data, &nonce); err != nil {
            expiredKeys = append(expiredKeys, key)
            continue
        }
        
        if time.Now().After(nonce.ExpiresAt) {
            expiredKeys = append(expiredKeys, key)
        }
    }
    
    if len(expiredKeys) > 0 {
        return nm.redis.Del(ctx, expiredKeys...).Err()
    }
    
    return nil
}

// trackNonce tracks nonce usage for monitoring
func (nm *NonceManager) trackNonce(ctx context.Context, nonce string) {
    // Add to sorted set for monitoring
    nm.redis.ZAdd(ctx, "avion:csp:active_nonces", redis.Z{
        Score:  float64(time.Now().Unix()),
        Member: nonce,
    })
    
    // Clean old entries (older than TTL)
    cutoff := float64(time.Now().Add(-nm.ttl).Unix())
    nm.redis.ZRemRangeByScore(ctx, "avion:csp:active_nonces", "0", fmt.Sprintf("%f", cutoff))
}

// Nonce represents a CSP nonce with metadata
type Nonce struct {
    Value      string         `json:"value"`
    CreatedAt  time.Time      `json:"created_at"`
    ExpiresAt  time.Time      `json:"expires_at"`
    ConsumedAt *time.Time     `json:"consumed_at,omitempty"`
    Metadata   NonceMetadata  `json:"metadata"`
}

// NonceMetadata contains additional nonce information
type NonceMetadata struct {
    RequestID   string `json:"request_id"`
    UserID      string `json:"user_id,omitempty"`
    SessionID   string `json:"session_id,omitempty"`
    IPAddress   string `json:"ip_address"`
    UserAgent   string `json:"user_agent"`
    RequestPath string `json:"request_path"`
}

func generateSecureNonce() string {
    b := make([]byte, 24) // 192 bits of entropy
    if _, err := rand.Read(b); err != nil {
        panic(fmt.Sprintf("failed to generate nonce: %v", err))
    }
    return base64.URLEncoding.EncodeToString(b)
}

// Errors
var (
    ErrNonceNotFound    = fmt.Errorf("nonce not found")
    ErrNonceExpired     = fmt.Errorf("nonce expired")
    ErrNonceAlreadyUsed = fmt.Errorf("nonce already used")
)
```

## Output Encoding for Different Contexts

### Context-Aware Encoding Implementation

```go
package security

import (
    "bytes"
    "encoding/json"
    "fmt"
    "html"
    "html/template"
    "net/url"
    "regexp"
    "strings"
    "unicode/utf8"
)

// OutputEncoder provides context-aware encoding for XSS prevention
type OutputEncoder struct {
    htmlEscaper      *strings.Replacer
    jsEscaper        *strings.Replacer
    cssEscaper       *regexp.Regexp
    urlValidator     *regexp.Regexp
}

func NewOutputEncoder() *OutputEncoder {
    return &OutputEncoder{
        htmlEscaper: strings.NewReplacer(
            "&", "&amp;",
            "<", "&lt;",
            ">", "&gt;",
            "\"", "&quot;",
            "'", "&#39;",
            "/", "&#x2F;",
        ),
        jsEscaper: strings.NewReplacer(
            "\\", "\\\\",
            "\n", "\\n",
            "\r", "\\r",
            "\t", "\\t",
            "\"", "\\\"",
            "'", "\\'",
            "<", "\\u003C",
            ">", "\\u003E",
            "&", "\\u0026",
            "=", "\\u003D",
            "-", "\\u002D",
            ";", "\\u003B",
            "\u2028", "\\u2028", // Line separator
            "\u2029", "\\u2029", // Paragraph separator
        ),
        cssEscaper:   regexp.MustCompile(`[^a-zA-Z0-9]`),
        urlValidator: regexp.MustCompile(`^https?://[^\s<>"{}|\\^\x00-\x1f]*$`),
    }
}

// EncodeForHTML encodes content for HTML context
func (e *OutputEncoder) EncodeForHTML(input string) string {
    if input == "" {
        return ""
    }
    return e.htmlEscaper.Replace(input)
}

// EncodeForHTMLAttribute encodes content for HTML attribute context
func (e *OutputEncoder) EncodeForHTMLAttribute(input string) string {
    if input == "" {
        return ""
    }
    
    // First HTML encode
    encoded := e.EncodeForHTML(input)
    
    // Additional encoding for attributes
    encoded = strings.ReplaceAll(encoded, "`", "&#96;")
    encoded = strings.ReplaceAll(encoded, "=", "&#61;")
    
    return encoded
}

// EncodeForJavaScript encodes content for JavaScript context
func (e *OutputEncoder) EncodeForJavaScript(input string) string {
    if input == "" {
        return ""
    }
    
    // Use the JavaScript escaper
    encoded := e.jsEscaper.Replace(input)
    
    // Handle Unicode characters
    var buf bytes.Buffer
    for _, r := range encoded {
        if r < 0x20 || r > 0x7E {
            fmt.Fprintf(&buf, "\\u%04X", r)
        } else {
            buf.WriteRune(r)
        }
    }
    
    return buf.String()
}

// EncodeForJSON safely encodes content for JSON responses
func (e *OutputEncoder) EncodeForJSON(input interface{}) (string, error) {
    // Use json.Marshal which handles escaping
    data, err := json.Marshal(input)
    if err != nil {
        return "", fmt.Errorf("failed to encode JSON: %w", err)
    }
    
    // Additional safety: ensure no raw script tags
    encoded := string(data)
    encoded = strings.ReplaceAll(encoded, "</script>", "<\\/script>")
    encoded = strings.ReplaceAll(encoded, "<!--", "\\u003C!--")
    
    return encoded, nil
}

// EncodeForURL encodes content for URL context
func (e *OutputEncoder) EncodeForURL(input string) string {
    return url.QueryEscape(input)
}

// EncodeForCSS encodes content for CSS context
func (e *OutputEncoder) EncodeForCSS(input string) string {
    if input == "" {
        return ""
    }
    
    var buf bytes.Buffer
    for _, r := range input {
        if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') {
            buf.WriteRune(r)
        } else {
            // CSS hex escape
            fmt.Fprintf(&buf, "\\%06X ", r)
        }
    }
    
    return strings.TrimSpace(buf.String())
}

// ValidateAndSanitizeURL validates and sanitizes URLs to prevent XSS
func (e *OutputEncoder) ValidateAndSanitizeURL(rawURL string) (string, error) {
    if rawURL == "" {
        return "", fmt.Errorf("empty URL")
    }
    
    // Parse URL
    u, err := url.Parse(rawURL)
    if err != nil {
        return "", fmt.Errorf("invalid URL: %w", err)
    }
    
    // Check for dangerous schemes
    if !isAllowedScheme(u.Scheme) {
        return "", fmt.Errorf("disallowed URL scheme: %s", u.Scheme)
    }
    
    // Check for javascript: and data: URLs (case-insensitive)
    lowerURL := strings.ToLower(rawURL)
    if strings.HasPrefix(lowerURL, "javascript:") || 
       strings.HasPrefix(lowerURL, "data:") ||
       strings.HasPrefix(lowerURL, "vbscript:") {
        return "", fmt.Errorf("dangerous URL scheme detected")
    }
    
    // Validate host (prevent SSRF)
    if err := validateHost(u.Host); err != nil {
        return "", fmt.Errorf("invalid host: %w", err)
    }
    
    // Rebuild URL to ensure consistency
    return u.String(), nil
}

func isAllowedScheme(scheme string) bool {
    allowedSchemes := []string{"http", "https", "mailto", "tel"}
    scheme = strings.ToLower(scheme)
    for _, allowed := range allowedSchemes {
        if scheme == allowed {
            return true
        }
    }
    return false
}

func validateHost(host string) error {
    if host == "" {
        return fmt.Errorf("empty host")
    }
    
    // Check for localhost and private IPs (SSRF prevention)
    privateHosts := []string{
        "localhost",
        "127.0.0.1",
        "0.0.0.0",
        "::1",
    }
    
    for _, private := range privateHosts {
        if strings.Contains(strings.ToLower(host), private) {
            return fmt.Errorf("private/local host not allowed")
        }
    }
    
    // Check for private IP ranges
    if isPrivateIP(host) {
        return fmt.Errorf("private IP range not allowed")
    }
    
    return nil
}

func isPrivateIP(host string) bool {
    // Extract IP from host:port if necessary
    if idx := strings.LastIndex(host, ":"); idx != -1 {
        host = host[:idx]
    }
    
    privateRanges := []string{
        "10.",
        "172.16.", "172.17.", "172.18.", "172.19.",
        "172.20.", "172.21.", "172.22.", "172.23.",
        "172.24.", "172.25.", "172.26.", "172.27.",
        "172.28.", "172.29.", "172.30.", "172.31.",
        "192.168.",
        "169.254.", // Link-local
    }
    
    for _, prefix := range privateRanges {
        if strings.HasPrefix(host, prefix) {
            return true
        }
    }
    
    return false
}
```

## Avion Gateway Implementation

### Complete Middleware Setup for avion-gateway

```go
// cmd/avion-gateway/main.go
package main

import (
    "context"
    "log"
    "net/http"
    "os"
    "time"
    
    "github.com/redis/go-redis/v9"
    "github.com/avion/avion-gateway/internal/middleware"
    "github.com/avion/avion-gateway/internal/security"
)

func main() {
    // Initialize Redis client
    redisClient := redis.NewClient(&redis.Options{
        Addr:     os.Getenv("REDIS_ADDR"),
        Password: os.Getenv("REDIS_PASSWORD"),
        DB:       0,
    })
    
    // Initialize security components
    xssProtector := security.NewXSSProtector()
    outputEncoder := security.NewOutputEncoder()
    nonceManager := security.NewNonceManager(redisClient)
    
    // Configure CSP for production
    cspConfig := getCSPConfig()
    cspMiddleware := middleware.NewCSPMiddleware(cspConfig, redisClient)
    
    // Initialize XSS prevention middleware
    xssMiddleware := middleware.NewXSSPreventionMiddleware(xssProtector, outputEncoder)
    
    // Setup HTTP server with middleware chain
    handler := setupMiddlewareChain(
        cspMiddleware,
        xssMiddleware,
        // Other middleware...
    )
    
    server := &http.Server{
        Addr:         ":8080",
        Handler:      handler,
        ReadTimeout:  15 * time.Second,
        WriteTimeout: 15 * time.Second,
        IdleTimeout:  60 * time.Second,
    }
    
    log.Printf("Starting Avion Gateway on %s", server.Addr)
    if err := server.ListenAndServe(); err != nil {
        log.Fatal(err)
    }
}

func getCSPConfig() middleware.CSPConfig {
    env := os.Getenv("ENVIRONMENT")
    
    if env == "production" {
        return middleware.CSPConfig{
            Enabled:    true,
            ReportOnly: false,
            UseNonce:   true,
            NonceTTL:   15 * time.Minute,
            
            DefaultSrc: []string{"'none'"},
            ScriptSrc: []string{
                "'self'",
                "'strict-dynamic'",
                "https://cdn.avion.app",
            },
            StyleSrc: []string{
                "'self'",
                "https://cdn.avion.app",
            },
            ImgSrc: []string{
                "'self'",
                "https://cdn.avion.app",
                "https://media.avion.app",
                "data:",
                "blob:",
            },
            FontSrc: []string{
                "'self'",
                "https://cdn.avion.app",
            },
            ConnectSrc: []string{
                "'self'",
                "https://api.avion.app",
                "wss://ws.avion.app",
                "https://graphql.avion.app",
            },
            MediaSrc: []string{
                "'self'",
                "https://media.avion.app",
            },
            WorkerSrc: []string{
                "'self'",
                "blob:",
            },
            ManifestSrc: []string{
                "'self'",
            },
            ObjectSrc:      []string{"'none'"},
            FrameSrc:       []string{"'none'"},
            FrameAncestors: []string{"'none'"},
            BaseURI:        []string{"'self'"},
            FormAction:     []string{"'self'"},
            
            UpgradeInsecureRequests: true,
            BlockAllMixedContent:    true,
            
            RequireTrustedTypesFor: []string{"'script'"},
            TrustedTypes:          []string{"avion-sanitizer", "'none'"},
            
            ReportURI: "https://api.avion.app/api/v1/security/csp-report",
            ReportTo:  "csp-endpoint",
        }
    }
    
    // Development configuration
    return middleware.CSPConfig{
        Enabled:    true,
        ReportOnly: true,
        UseNonce:   true,
        NonceTTL:   15 * time.Minute,
        
        DefaultSrc: []string{"'self'"},
        ScriptSrc: []string{
            "'self'",
            "'unsafe-inline'",
            "'unsafe-eval'",
            "http://localhost:*",
        },
        StyleSrc: []string{
            "'self'",
            "'unsafe-inline'",
        },
        ConnectSrc: []string{
            "'self'",
            "ws://localhost:*",
            "http://localhost:*",
        },
        ImgSrc: []string{
            "'self'",
            "data:",
            "blob:",
            "http://localhost:*",
        },
        
        ReportURI: "http://localhost:8080/api/v1/security/csp-report",
    }
}

// XSSPreventionMiddleware applies XSS protection to all responses
type XSSPreventionMiddleware struct {
    xssProtector  *security.XSSProtector
    outputEncoder *security.OutputEncoder
}

func NewXSSPreventionMiddleware(xssProtector *security.XSSProtector, encoder *security.OutputEncoder) *XSSPreventionMiddleware {
    return &XSSPreventionMiddleware{
        xssProtector:  xssProtector,
        outputEncoder: encoder,
    }
}

func (m *XSSPreventionMiddleware) Handler(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Wrap response writer to intercept and sanitize responses
        wrapped := &xssResponseWriter{
            ResponseWriter: w,
            xssProtector:  m.xssProtector,
            outputEncoder: m.outputEncoder,
            request:       r,
        }
        
        next.ServeHTTP(wrapped, r)
    })
}

// xssResponseWriter wraps http.ResponseWriter to sanitize responses
type xssResponseWriter struct {
    http.ResponseWriter
    xssProtector  *security.XSSProtector
    outputEncoder *security.OutputEncoder
    request       *http.Request
    buffer        bytes.Buffer
    status        int
}

func (w *xssResponseWriter) Write(b []byte) (int, error) {
    // Buffer the response for processing
    return w.buffer.Write(b)
}

func (w *xssResponseWriter) WriteHeader(status int) {
    w.status = status
    w.ResponseWriter.WriteHeader(status)
}

func (w *xssResponseWriter) Flush() {
    // Process buffered content based on content type
    contentType := w.Header().Get("Content-Type")
    
    var processedContent []byte
    if strings.Contains(contentType, "application/json") {
        processedContent = w.processJSON(w.buffer.Bytes())
    } else if strings.Contains(contentType, "text/html") {
        processedContent = w.processHTML(w.buffer.Bytes())
    } else {
        processedContent = w.buffer.Bytes()
    }
    
    // Write processed content
    w.ResponseWriter.Write(processedContent)
    
    // Flush if supported
    if flusher, ok := w.ResponseWriter.(http.Flusher); ok {
        flusher.Flush()
    }
}

func (w *xssResponseWriter) processJSON(data []byte) []byte {
    // Parse JSON and sanitize string fields
    var content interface{}
    if err := json.Unmarshal(data, &content); err != nil {
        return data // Return original if parsing fails
    }
    
    // Recursively sanitize JSON content
    sanitized := w.sanitizeJSONValue(content)
    
    // Re-encode with proper escaping
    result, err := w.outputEncoder.EncodeForJSON(sanitized)
    if err != nil {
        return data
    }
    
    return []byte(result)
}

func (w *xssResponseWriter) sanitizeJSONValue(v interface{}) interface{} {
    switch value := v.(type) {
    case string:
        // Sanitize string values
        return w.xssProtector.SanitizeHTML(value, security.ContextUserContent)
    case map[string]interface{}:
        // Recursively process map
        for k, v := range value {
            value[k] = w.sanitizeJSONValue(v)
        }
        return value
    case []interface{}:
        // Recursively process array
        for i, item := range value {
            value[i] = w.sanitizeJSONValue(item)
        }
        return value
    default:
        return value
    }
}

func (w *xssResponseWriter) processHTML(data []byte) []byte {
    // For HTML responses, ensure proper encoding
    content := string(data)
    
    // Add CSP nonce to inline scripts if present
    if nonce := middleware.GetCSPNonce(w.request.Context()); nonce != "" {
        content = w.injectCSPNonce(content, nonce)
    }
    
    return []byte(content)
}

func (w *xssResponseWriter) injectCSPNonce(html, nonce string) string {
    // Inject nonce into script tags
    html = strings.ReplaceAll(html, "<script>", fmt.Sprintf(`<script nonce="%s">`, nonce))
    html = strings.ReplaceAll(html, "<style>", fmt.Sprintf(`<style nonce="%s">`, nonce))
    
    return html
}
```

### GraphQL-Specific XSS Prevention

```go
// internal/graphql/security.go
package graphql

import (
    "context"
    "github.com/99designs/gqlgen/graphql"
    "github.com/avion/avion-gateway/internal/security"
)

// XSSPreventionExtension implements GraphQL extension for XSS prevention
type XSSPreventionExtension struct {
    xssProtector *security.XSSProtector
    encoder      *security.OutputEncoder
}

func NewXSSPreventionExtension(protector *security.XSSProtector, encoder *security.OutputEncoder) *XSSPreventionExtension {
    return &XSSPreventionExtension{
        xssProtector: protector,
        encoder:      encoder,
    }
}

// ExtensionName returns the extension name
func (e *XSSPreventionExtension) ExtensionName() string {
    return "XSSPrevention"
}

// Validate is called when adding the extension
func (e *XSSPreventionExtension) Validate(schema graphql.ExecutableSchema) error {
    return nil
}

// InterceptField sanitizes field values before returning them
func (e *XSSPreventionExtension) InterceptField(ctx context.Context, next graphql.Resolver) (interface{}, error) {
    result, err := next(ctx)
    if err != nil {
        return nil, err
    }
    
    // Sanitize string results
    if str, ok := result.(string); ok {
        fieldContext := graphql.GetFieldContext(ctx)
        
        // Determine sanitization based on field name
        if shouldSanitizeField(fieldContext.Field.Name) {
            return e.xssProtector.SanitizeHTML(str, security.ContextUserContent), nil
        }
    }
    
    return result, nil
}

func shouldSanitizeField(fieldName string) bool {
    // List of fields that contain user-generated content
    sanitizeFields := []string{
        "content",
        "description",
        "bio",
        "message",
        "text",
        "comment",
        "reply",
    }
    
    for _, field := range sanitizeFields {
        if fieldName == field {
            return true
        }
    }
    
    return false
}

// GraphQL Input Validation
type InputValidator struct {
    xssProtector *security.XSSProtector
}

func (v *InputValidator) ValidateCreateDropInput(input CreateDropInput) error {
    // Check for XSS patterns in input
    if v.containsXSSPatterns(input.Content) {
        return fmt.Errorf("potentially malicious content detected")
    }
    
    // Validate URLs in content
    urls := extractURLs(input.Content)
    for _, url := range urls {
        if _, err := v.xssProtector.ValidateURL(url); err != nil {
            return fmt.Errorf("invalid URL in content: %w", err)
        }
    }
    
    return nil
}

func (v *InputValidator) containsXSSPatterns(content string) bool {
    patterns := []string{
        "<script",
        "javascript:",
        "onerror=",
        "onload=",
        "onclick=",
        "<iframe",
        "data:text/html",
    }
    
    lower := strings.ToLower(content)
    for _, pattern := range patterns {
        if strings.Contains(lower, pattern) {
            return true
        }
    }
    
    return false
}
```

## React Frontend Integration

### React CSP Integration with Nonce Support

```tsx
// src/security/CSPProvider.tsx
import React, { createContext, useContext, useEffect, useState } from 'react';
import { SecurityService } from '../services/SecurityService';

interface CSPContextValue {
  nonce: string | null;
  reportViolation: (violation: CSPViolation) => void;
  trustedTypes: TrustedTypePolicy | null;
}

const CSPContext = createContext<CSPContextValue | null>(null);

export const CSPProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [nonce, setNonce] = useState<string | null>(null);
  const [trustedTypes, setTrustedTypes] = useState<TrustedTypePolicy | null>(null);

  useEffect(() => {
    // Get nonce from meta tag or header
    const nonceFromMeta = document.querySelector('meta[name="csp-nonce"]')?.getAttribute('content');
    const nonceFromHeader = window.__CSP_NONCE__; // Set by server-rendered HTML
    
    setNonce(nonceFromMeta || nonceFromHeader || null);

    // Initialize Trusted Types if supported
    if (window.trustedTypes && window.trustedTypes.createPolicy) {
      try {
        const policy = window.trustedTypes.createPolicy('avion-sanitizer', {
          createHTML: (input: string) => {
            return DOMPurify.sanitize(input, {
              RETURN_TRUSTED_TYPE: true,
            });
          },
          createScript: (input: string) => {
            // Only allow scripts with valid nonce
            if (nonce && input.includes(`nonce="${nonce}"`)) {
              return input;
            }
            throw new Error('Script creation blocked by Trusted Types policy');
          },
          createScriptURL: (input: string) => {
            // Validate script URLs
            const allowedOrigins = [
              'https://cdn.avion.app',
              'https://api.avion.app',
            ];
            
            const url = new URL(input);
            if (allowedOrigins.some(origin => url.origin === origin)) {
              return input;
            }
            throw new Error('Script URL blocked by Trusted Types policy');
          },
        });
        
        setTrustedTypes(policy);
      } catch (error) {
        console.error('Failed to create Trusted Types policy:', error);
      }
    }

    // Setup CSP violation reporter
    setupCSPViolationReporter();
  }, []);

  const setupCSPViolationReporter = () => {
    // Listen for SecurityPolicyViolation events
    document.addEventListener('securitypolicyviolation', (event: SecurityPolicyViolationEvent) => {
      reportViolation({
        documentUri: event.documentURI,
        violatedDirective: event.violatedDirective,
        effectiveDirective: event.effectiveDirective,
        originalPolicy: event.originalPolicy,
        blockedUri: event.blockedURI,
        lineNumber: event.lineNumber,
        columnNumber: event.columnNumber,
        sourceFile: event.sourceFile,
        sample: event.sample,
        disposition: event.disposition,
        statusCode: event.statusCode,
      });
    });
  };

  const reportViolation = async (violation: CSPViolation) => {
    try {
      await SecurityService.reportCSPViolation(violation);
    } catch (error) {
      console.error('Failed to report CSP violation:', error);
    }
  };

  return (
    <CSPContext.Provider value={{ nonce, reportViolation, trustedTypes }}>
      {children}
    </CSPContext.Provider>
  );
};

export const useCSP = () => {
  const context = useContext(CSPContext);
  if (!context) {
    throw new Error('useCSP must be used within CSPProvider');
  }
  return context;
};

// Safe Script Component
export const SafeScript: React.FC<{
  src?: string;
  children?: string;
  async?: boolean;
  defer?: boolean;
}> = ({ src, children, async, defer }) => {
  const { nonce, trustedTypes } = useCSP();
  const scriptRef = React.useRef<HTMLScriptElement>(null);

  useEffect(() => {
    if (!scriptRef.current) return;

    const script = scriptRef.current;

    if (src) {
      // External script
      script.src = src;
      if (nonce) {
        script.nonce = nonce;
      }
      script.async = async || false;
      script.defer = defer || false;
    } else if (children) {
      // Inline script
      if (nonce) {
        script.nonce = nonce;
      }
      
      if (trustedTypes) {
        // Use Trusted Types if available
        script.innerHTML = trustedTypes.createHTML(children) as string;
      } else {
        // Fallback to textContent (safer than innerHTML)
        script.textContent = children;
      }
    }

    document.head.appendChild(script);

    return () => {
      if (script.parentNode) {
        script.parentNode.removeChild(script);
      }
    };
  }, [src, children, nonce, async, defer, trustedTypes]);

  return <script ref={scriptRef} />;
};

// Safe Style Component
export const SafeStyle: React.FC<{ children: string }> = ({ children }) => {
  const { nonce } = useCSP();

  return (
    <style
      nonce={nonce || undefined}
      dangerouslySetInnerHTML={{
        __html: DOMPurify.sanitize(children, {
          ALLOWED_TAGS: [],
          ALLOWED_ATTR: [],
          KEEP_CONTENT: true,
        }),
      }}
    />
  );
};
```

### XSS-Safe Components

```tsx
// src/components/XSSSafeComponents.tsx
import React, { useMemo } from 'react';
import DOMPurify from 'dompurify';
import { useCSP } from '../security/CSPProvider';

interface SafeHTMLProps {
  content: string;
  allowedTags?: string[];
  allowedAttributes?: string[];
  className?: string;
}

export const SafeHTML: React.FC<SafeHTMLProps> = ({
  content,
  allowedTags,
  allowedAttributes,
  className,
}) => {
  const { trustedTypes } = useCSP();

  const sanitizedContent = useMemo(() => {
    const config: DOMPurify.Config = {
      ALLOWED_TAGS: allowedTags || [
        'p', 'br', 'strong', 'em', 'u', 'blockquote',
        'ul', 'ol', 'li', 'a', 'code', 'pre', 'span', 'div',
      ],
      ALLOWED_ATTR: allowedAttributes || ['href', 'target', 'rel', 'class'],
      ALLOW_DATA_ATTR: false,
      RETURN_TRUSTED_TYPE: !!trustedTypes,
    };

    // Add hook to set target="_blank" and rel="noopener noreferrer" on links
    DOMPurify.addHook('afterSanitizeAttributes', (node) => {
      if ('target' in node) {
        node.setAttribute('target', '_blank');
        node.setAttribute('rel', 'noopener noreferrer');
      }
    });

    return DOMPurify.sanitize(content, config);
  }, [content, allowedTags, allowedAttributes, trustedTypes]);

  if (trustedTypes) {
    // Use Trusted Types if available
    return (
      <div
        className={className}
        dangerouslySetInnerHTML={{ __html: sanitizedContent as string }}
      />
    );
  }

  // Fallback for browsers without Trusted Types
  return (
    <div
      className={className}
      dangerouslySetInnerHTML={{ __html: sanitizedContent }}
    />
  );
};

// User-generated content component with additional safety measures
export const UserContent: React.FC<{
  content: string;
  maxLength?: number;
  className?: string;
}> = ({ content, maxLength = 10000, className }) => {
  const processedContent = useMemo(() => {
    // Truncate if too long (prevent DoS)
    let processed = content;
    if (processed.length > maxLength) {
      processed = processed.substring(0, maxLength) + '...';
    }

    // Auto-link URLs (safely)
    processed = linkifyURLs(processed);

    // Process @mentions and #hashtags
    processed = processMentionsAndHashtags(processed);

    return processed;
  }, [content, maxLength]);

  return (
    <SafeHTML
      content={processedContent}
      className={`user-content ${className || ''}`}
    />
  );
};

// Safe link component
export const SafeLink: React.FC<{
  href: string;
  children: React.ReactNode;
  className?: string;
  onClick?: (e: React.MouseEvent) => void;
}> = ({ href, children, className, onClick }) => {
  const sanitizedHref = useMemo(() => {
    try {
      const url = new URL(href);
      
      // Only allow safe protocols
      if (!['http:', 'https:', 'mailto:', 'tel:'].includes(url.protocol)) {
        return '#';
      }
      
      // Check for localhost/private IPs (SSRF prevention)
      const privatePatterns = [
        /^localhost$/i,
        /^127\./,
        /^10\./,
        /^172\.(1[6-9]|2[0-9]|3[0-1])\./,
        /^192\.168\./,
      ];
      
      if (privatePatterns.some(pattern => pattern.test(url.hostname))) {
        return '#';
      }
      
      return url.toString();
    } catch {
      // Invalid URL
      return '#';
    }
  }, [href]);

  const handleClick = (e: React.MouseEvent) => {
    if (sanitizedHref === '#') {
      e.preventDefault();
      console.warn('Blocked potentially dangerous URL:', href);
      return;
    }
    
    if (onClick) {
      onClick(e);
    }
  };

  return (
    <a
      href={sanitizedHref}
      className={className}
      onClick={handleClick}
      target="_blank"
      rel="noopener noreferrer"
    >
      {children}
    </a>
  );
};

// Helper functions
function linkifyURLs(text: string): string {
  const urlRegex = /(https?:\/\/[^\s<>"{}|\\^`\[\]]+)/g;
  return text.replace(urlRegex, (url) => {
    const encoded = encodeHTML(url);
    return `<a href="${encoded}" target="_blank" rel="noopener noreferrer">${encoded}</a>`;
  });
}

function processMentionsAndHashtags(text: string): string {
  // Process @mentions
  text = text.replace(/@(\w+)/g, (match, username) => {
    const encoded = encodeHTML(username);
    return `<a href="/u/${encoded}" class="mention">@${encoded}</a>`;
  });
  
  // Process #hashtags
  text = text.replace(/#(\w+)/g, (match, hashtag) => {
    const encoded = encodeHTML(hashtag);
    return `<a href="/hashtag/${encoded}" class="hashtag">#${encoded}</a>`;
  });
  
  return text;
}

function encodeHTML(str: string): string {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}
```

## Testing Strategy

### Comprehensive XSS Testing Suite

```go
// tests/security/xss_test.go
package security_test

import (
    "bytes"
    "encoding/json"
    "net/http"
    "net/http/httptest"
    "testing"
    
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

func TestXSSPrevention(t *testing.T) {
    // XSS test vectors
    xssVectors := []struct {
        name        string
        input       string
        expectBlock bool
        description string
    }{
        // Basic XSS
        {
            name:        "basic_script_tag",
            input:       `<script>alert('XSS')</script>`,
            expectBlock: true,
            description: "Basic script tag injection",
        },
        {
            name:        "img_onerror",
            input:       `<img src=x onerror="alert('XSS')">`,
            expectBlock: true,
            description: "IMG tag with onerror event",
        },
        {
            name:        "svg_onload",
            input:       `<svg onload="alert('XSS')">`,
            expectBlock: true,
            description: "SVG with onload event",
        },
        
        // Advanced XSS
        {
            name:        "nested_encoding",
            input:       `<img src=x onerror="&#97;&#108;&#101;&#114;&#116;('XSS')">`,
            expectBlock: true,
            description: "HTML entity encoded payload",
        },
        {
            name:        "javascript_protocol",
            input:       `<a href="javascript:alert('XSS')">Click</a>`,
            expectBlock: true,
            description: "JavaScript protocol in href",
        },
        {
            name:        "data_uri_script",
            input:       `<script src="data:text/javascript,alert('XSS')"></script>`,
            expectBlock: true,
            description: "Data URI with JavaScript",
        },
        {
            name:        "dom_clobbering",
            input:       `<form name="body"><img src=x name="attributes">`,
            expectBlock: true,
            description: "DOM clobbering attack",
        },
        
        // Mutation XSS
        {
            name:        "mutation_xss",
            input:       `<noscript><p title="</noscript><img src=x onerror=alert(1)>">`,
            expectBlock: true,
            description: "mXSS via noscript",
        },
        
        // Polyglot XSS
        {
            name:        "polyglot",
            input:       `javascript:/*--></title></style></textarea></script></xmp><svg/onload='+/"/+/onmouseover=1/+/[*/[]/+alert(1)//'>`,
            expectBlock: true,
            description: "Polyglot XSS payload",
        },
        
        // Safe content
        {
            name:        "safe_html",
            input:       `<p>This is <strong>safe</strong> content</p>`,
            expectBlock: false,
            description: "Safe HTML content",
        },
        {
            name:        "safe_link",
            input:       `<a href="https://example.com">Safe Link</a>`,
            expectBlock: false,
            description: "Safe external link",
        },
    }
    
    for _, vector := range xssVectors {
        t.Run(vector.name, func(t *testing.T) {
            // Test input sanitization
            result := testXSSInput(t, vector.input)
            
            if vector.expectBlock {
                assert.NotContains(t, result, "<script")
                assert.NotContains(t, result, "alert(")
                assert.NotContains(t, result, "onerror")
                assert.NotContains(t, result, "javascript:")
            } else {
                // Safe content should be preserved
                assert.NotEmpty(t, result)
            }
        })
    }
}

func TestCSPHeaders(t *testing.T) {
    handler := setupTestHandler()
    
    req := httptest.NewRequest("GET", "/", nil)
    rec := httptest.NewRecorder()
    
    handler.ServeHTTP(rec, req)
    
    // Check CSP header
    csp := rec.Header().Get("Content-Security-Policy")
    require.NotEmpty(t, csp)
    
    // Verify essential directives
    assert.Contains(t, csp, "default-src")
    assert.Contains(t, csp, "script-src")
    assert.Contains(t, csp, "style-src")
    assert.Contains(t, csp, "frame-ancestors 'none'")
    
    // Check for nonce
    nonce := rec.Header().Get("X-CSP-Nonce")
    if nonce != "" {
        assert.Contains(t, csp, fmt.Sprintf("'nonce-%s'", nonce))
    }
    
    // Verify other security headers
    assert.Equal(t, "nosniff", rec.Header().Get("X-Content-Type-Options"))
    assert.Equal(t, "DENY", rec.Header().Get("X-Frame-Options"))
    assert.Equal(t, "1; mode=block", rec.Header().Get("X-XSS-Protection"))
    assert.NotEmpty(t, rec.Header().Get("Referrer-Policy"))
}

func TestNonceValidation(t *testing.T) {
    nonceManager := setupNonceManager()
    ctx := context.Background()
    
    // Generate nonce
    nonce, err := nonceManager.GenerateNonceWithMetadata(ctx, NonceMetadata{
        RequestID: "test-request",
        IPAddress: "127.0.0.1",
    })
    require.NoError(t, err)
    require.NotEmpty(t, nonce.Value)
    
    // Validate nonce
    validated, err := nonceManager.ValidateAndConsume(ctx, nonce.Value)
    require.NoError(t, err)
    assert.Equal(t, nonce.Value, validated.Value)
    
    // Try to reuse nonce (should fail)
    _, err = nonceManager.ValidateAndConsume(ctx, nonce.Value)
    assert.Error(t, err)
    assert.Equal(t, ErrNonceAlreadyUsed, err)
}

func TestOutputEncoding(t *testing.T) {
    encoder := NewOutputEncoder()
    
    tests := []struct {
        name     string
        input    string
        context  string
        validate func(t *testing.T, output string)
    }{
        {
            name:    "html_context",
            input:   `<script>alert('XSS')</script>`,
            context: "html",
            validate: func(t *testing.T, output string) {
                assert.Contains(t, output, "&lt;script&gt;")
                assert.NotContains(t, output, "<script>")
            },
        },
        {
            name:    "javascript_context",
            input:   `</script><script>alert('XSS')</script>`,
            context: "javascript",
            validate: func(t *testing.T, output string) {
                assert.Contains(t, output, "\\u003C")
                assert.NotContains(t, output, "</script>")
            },
        },
        {
            name:    "url_context",
            input:   `<script>alert('XSS')</script>`,
            context: "url",
            validate: func(t *testing.T, output string) {
                assert.Contains(t, output, "%3Cscript%3E")
                assert.NotContains(t, output, "<script>")
            },
        },
        {
            name:    "css_context",
            input:   `background: url("javascript:alert('XSS')")`,
            context: "css",
            validate: func(t *testing.T, output string) {
                assert.NotContains(t, output, "javascript:")
                assert.Contains(t, output, "\\")
            },
        },
    }
    
    for _, test := range tests {
        t.Run(test.name, func(t *testing.T) {
            var output string
            
            switch test.context {
            case "html":
                output = encoder.EncodeForHTML(test.input)
            case "javascript":
                output = encoder.EncodeForJavaScript(test.input)
            case "url":
                output = encoder.EncodeForURL(test.input)
            case "css":
                output = encoder.EncodeForCSS(test.input)
            }
            
            test.validate(t, output)
        })
    }
}

// Benchmark tests
func BenchmarkXSSSanitization(b *testing.B) {
    protector := NewXSSProtector()
    input := `<p>This is <script>alert('XSS')</script> content with <a href="javascript:alert('XSS')">link</a></p>`
    
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        _ = protector.SanitizeHTML(input, ContextUserContent)
    }
}

func BenchmarkNonceGeneration(b *testing.B) {
    manager := setupNonceManager()
    ctx := context.Background()
    
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        _, _ = manager.GenerateNonceWithMetadata(ctx, NonceMetadata{
            RequestID: fmt.Sprintf("req-%d", i),
        })
    }
}
```

## CSP Violation Reporting

### Violation Report Handler

```go
// internal/handlers/csp_report.go
package handlers

import (
    "encoding/json"
    "net/http"
    "time"
    
    "github.com/prometheus/client_golang/prometheus"
    "go.uber.org/zap"
)

// CSPViolationReport represents a CSP violation report
type CSPViolationReport struct {
    DocumentURI        string `json:"document-uri"`
    Referrer          string `json:"referrer"`
    ViolatedDirective string `json:"violated-directive"`
    EffectiveDirective string `json:"effective-directive"`
    OriginalPolicy    string `json:"original-policy"`
    Disposition       string `json:"disposition"`
    BlockedURI        string `json:"blocked-uri"`
    LineNumber        int    `json:"line-number"`
    ColumnNumber      int    `json:"column-number"`
    SourceFile        string `json:"source-file"`
    StatusCode        int    `json:"status-code"`
    ScriptSample      string `json:"script-sample"`
}

// CSPReportHandler handles CSP violation reports
type CSPReportHandler struct {
    logger  *zap.Logger
    metrics *CSPMetrics
    store   ViolationStore
}

// CSPMetrics tracks CSP violations
type CSPMetrics struct {
    violations *prometheus.CounterVec
    blocked    *prometheus.CounterVec
}

func NewCSPMetrics() *CSPMetrics {
    return &CSPMetrics{
        violations: prometheus.NewCounterVec(
            prometheus.CounterOpts{
                Name: "csp_violations_total",
                Help: "Total number of CSP violations",
            },
            []string{"directive", "disposition", "blocked_uri_type"},
        ),
        blocked: prometheus.NewCounterVec(
            prometheus.CounterOpts{
                Name: "csp_blocked_resources_total",
                Help: "Total number of blocked resources",
            },
            []string{"resource_type", "directive"},
        ),
    }
}

func (h *CSPReportHandler) HandleReport(w http.ResponseWriter, r *http.Request) {
    if r.Method != http.MethodPost {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        return
    }
    
    var report struct {
        CSPReport CSPViolationReport `json:"csp-report"`
    }
    
    if err := json.NewDecoder(r.Body).Decode(&report); err != nil {
        h.logger.Error("Failed to decode CSP report", zap.Error(err))
        http.Error(w, "Invalid report format", http.StatusBadRequest)
        return
    }
    
    // Process the violation report
    h.processViolation(r, report.CSPReport)
    
    // Return 204 No Content
    w.WriteHeader(http.StatusNoContent)
}

func (h *CSPReportHandler) processViolation(r *http.Request, report CSPViolationReport) {
    // Extract additional context
    userAgent := r.Header.Get("User-Agent")
    ip := getClientIP(r)
    
    // Log the violation
    h.logger.Warn("CSP violation detected",
        zap.String("document_uri", report.DocumentURI),
        zap.String("violated_directive", report.ViolatedDirective),
        zap.String("blocked_uri", report.BlockedURI),
        zap.String("source_file", report.SourceFile),
        zap.Int("line_number", report.LineNumber),
        zap.String("disposition", report.Disposition),
        zap.String("user_agent", userAgent),
        zap.String("client_ip", ip),
    )
    
    // Update metrics
    h.updateMetrics(report)
    
    // Store violation for analysis
    h.storeViolation(report, userAgent, ip)
    
    // Check for patterns that might indicate attacks
    if h.isLikelyAttack(report) {
        h.handlePotentialAttack(report, ip)
    }
}

func (h *CSPReportHandler) updateMetrics(report CSPViolationReport) {
    blockedType := categorizeBlockedURI(report.BlockedURI)
    
    h.metrics.violations.WithLabelValues(
        report.ViolatedDirective,
        report.Disposition,
        blockedType,
    ).Inc()
    
    if report.Disposition == "enforce" {
        h.metrics.blocked.WithLabelValues(
            blockedType,
            report.ViolatedDirective,
        ).Inc()
    }
}

func (h *CSPReportHandler) isLikelyAttack(report CSPViolationReport) bool {
    // Check for common XSS patterns
    suspiciousPatterns := []string{
        "javascript:",
        "data:text/html",
        "vbscript:",
        "onclick",
        "onerror",
        "onload",
        "<script",
    }
    
    for _, pattern := range suspiciousPatterns {
        if strings.Contains(strings.ToLower(report.BlockedURI), pattern) ||
           strings.Contains(strings.ToLower(report.ScriptSample), pattern) {
            return true
        }
    }
    
    return false
}

func (h *CSPReportHandler) handlePotentialAttack(report CSPViolationReport, clientIP string) {
    h.logger.Error("Potential XSS attack detected",
        zap.String("blocked_uri", report.BlockedURI),
        zap.String("script_sample", report.ScriptSample),
        zap.String("client_ip", clientIP),
        zap.String("document_uri", report.DocumentURI),
    )
    
    // Could implement rate limiting or blocking here
    // For example, temporarily block the IP or increase scrutiny
}

func categorizeBlockedURI(uri string) string {
    lower := strings.ToLower(uri)
    
    switch {
    case strings.HasPrefix(lower, "inline"):
        return "inline"
    case strings.HasPrefix(lower, "eval"):
        return "eval"
    case strings.HasPrefix(lower, "data:"):
        return "data_uri"
    case strings.HasPrefix(lower, "blob:"):
        return "blob"
    case strings.HasPrefix(lower, "javascript:"):
        return "javascript_protocol"
    case strings.HasPrefix(lower, "http://"):
        return "http"
    case strings.HasPrefix(lower, "https://"):
        return "https"
    default:
        return "unknown"
    }
}

// ViolationStore interface for storing violations
type ViolationStore interface {
    Store(violation CSPViolationRecord) error
    GetRecent(limit int) ([]CSPViolationRecord, error)
    GetByIP(ip string, since time.Time) ([]CSPViolationRecord, error)
}

type CSPViolationRecord struct {
    ID                string    `json:"id"`
    Timestamp         time.Time `json:"timestamp"`
    DocumentURI       string    `json:"document_uri"`
    ViolatedDirective string    `json:"violated_directive"`
    BlockedURI        string    `json:"blocked_uri"`
    SourceFile        string    `json:"source_file"`
    LineNumber        int       `json:"line_number"`
    Disposition       string    `json:"disposition"`
    UserAgent         string    `json:"user_agent"`
    ClientIP          string    `json:"client_ip"`
    ScriptSample      string    `json:"script_sample"`
}
```

## Security Checklist

### Implementation Requirements

#### Core XSS Prevention
- [ ] Input validation on all user inputs
- [ ] Context-aware output encoding
- [ ] HTML sanitization using DOMPurify/bluemonday
- [ ] URL validation and sanitization
- [ ] File upload MIME type validation
- [ ] GraphQL input/output sanitization

#### Content Security Policy
- [ ] CSP headers on all responses
- [ ] Nonce-based CSP for inline scripts/styles
- [ ] Redis-backed nonce management
- [ ] CSP violation reporting endpoint
- [ ] Report-To header configuration
- [ ] Trusted Types policy (where supported)

#### API Security
- [ ] JSON response sanitization
- [ ] GraphQL field-level sanitization
- [ ] WebSocket message sanitization
- [ ] SSE event sanitization
- [ ] Proper Content-Type headers
- [ ] X-Content-Type-Options: nosniff

#### Frontend Security
- [ ] React CSP integration
- [ ] Safe component wrappers
- [ ] DOMPurify integration
- [ ] Trusted Types support
- [ ] CSP nonce propagation
- [ ] XSS-safe routing

#### Testing & Monitoring
- [ ] XSS test suite with attack vectors
- [ ] CSP header validation tests
- [ ] Nonce generation/validation tests
- [ ] Output encoding tests
- [ ] Performance benchmarks
- [ ] CSP violation monitoring
- [ ] Security metrics dashboard

## Summary

This comprehensive XSS prevention and CSP implementation guide provides:

1. **Defense in Depth**: Multiple layers of protection from input validation to CSP
2. **Context-Aware Security**: Different encoding strategies for different output contexts
3. **Modern Standards**: Support for Trusted Types, CSP Level 3, and nonce-based policies
4. **Performance Optimization**: Redis-backed nonce caching, efficient sanitization
5. **Complete Implementation**: Ready-to-use code for avion-gateway and frontend
6. **Comprehensive Testing**: Full test suite covering various XSS vectors
7. **Monitoring & Reporting**: CSP violation tracking and analysis

Regular security audits and updates to the XSS prevention mechanisms ensure continued protection against evolving threats.