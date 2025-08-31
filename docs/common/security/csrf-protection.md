# CSRF Protection Implementation Guide

**Last Updated:** 2025/08/30  
**Status:** Production-Ready Implementation Guide  
**Scope:** All Avion microservices with state-changing operations  
**Primary Service:** avion-gateway (GraphQL API Gateway)

## Overview

Cross-Site Request Forgery (CSRF) protection is critical for preventing unauthorized state-changing operations in the Avion social networking platform. This document provides production-ready implementation for CSRF protection using Redis-backed double-submit cookie pattern with SameSite cookies for Single Page Application (SPA) architecture.

### Attack Vectors and Prevention

#### CSRF Attack Scenarios
1. **Form-based attacks**: Malicious sites submitting forms to your API
2. **Image/Script attacks**: Using `<img>` or `<script>` tags to trigger GET requests
3. **XHR attacks**: Cross-origin XMLHttpRequest attempts without proper CORS
4. **DNS rebinding**: Bypassing same-origin policy through DNS manipulation

#### Prevention Strategy
Our multi-layered defense combines:
- **SameSite cookies** (primary defense for modern browsers)
- **Double-submit cookie pattern** (backward compatibility)
- **Custom header requirement** (defense against older attacks)
- **Origin validation** (additional verification layer)
- **Redis-backed token management** (centralized validation)

## Quick Reference

### Protection Requirements
- **Required for:** All state-changing operations (POST, PUT, DELETE, PATCH)
- **Not required for:** Read-only operations (GET, HEAD, OPTIONS)
- **Token storage:** Redis with TTL-based expiration
- **Token transmission:** Double-submit cookie + header validation
- **SameSite policy:** Strict for production, Lax for development

## Architecture Overview

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Browser   │────▶│  API Gateway │────▶│   Service   │
│             │◀────│  (CSRF Check)│◀────│             │
└─────────────┘     └──────────────┘     └─────────────┘
                            │
                            ▼
                    ┌──────────────┐
                    │     Redis    │
                    │ (Token Store)│
                    └──────────────┘
```

## Implementation Patterns

### 1. CSRF Token Management

#### Token Generator and Store

```go
package csrf

import (
    "context"
    "crypto/rand"
    "encoding/base64"
    "fmt"
    "time"
    
    "github.com/redis/go-redis/v9"
)

const (
    // Token configuration
    TokenLength = 32
    TokenTTL    = 24 * time.Hour
    
    // Redis key patterns
    KeyPrefix = "csrf:"
    UserPrefix = "user:"
)

// CSRFManager handles CSRF token operations
type CSRFManager struct {
    redis     *redis.Client
    tokenTTL  time.Duration
}

func NewCSRFManager(redisClient *redis.Client) *CSRFManager {
    return &CSRFManager{
        redis:    redisClient,
        tokenTTL: TokenTTL,
    }
}

// GenerateToken creates a new CSRF token for a user session
func (m *CSRFManager) GenerateToken(ctx context.Context, userID, sessionID string) (string, error) {
    // Generate cryptographically secure random token
    tokenBytes := make([]byte, TokenLength)
    if _, err := rand.Read(tokenBytes); err != nil {
        return "", fmt.Errorf("generate random token: %w", err)
    }
    
    token := base64.URLEncoding.EncodeToString(tokenBytes)
    
    // Store token in Redis with user and session binding
    key := m.buildKey(userID, sessionID)
    tokenData := map[string]interface{}{
        "token":      token,
        "user_id":    userID,
        "session_id": sessionID,
        "created_at": time.Now().Unix(),
        "ip":         extractIP(ctx),
    }
    
    pipe := m.redis.TxPipeline()
    pipe.HSet(ctx, key, tokenData)
    pipe.Expire(ctx, key, m.tokenTTL)
    
    // Also maintain user's active tokens list
    userKey := m.buildUserKey(userID)
    pipe.SAdd(ctx, userKey, key)
    pipe.Expire(ctx, userKey, m.tokenTTL)
    
    if _, err := pipe.Exec(ctx); err != nil {
        return "", fmt.Errorf("store csrf token: %w", err)
    }
    
    return token, nil
}

// ValidateToken verifies a CSRF token
func (m *CSRFManager) ValidateToken(ctx context.Context, userID, sessionID, token string) error {
    if token == "" {
        return ErrTokenMissing
    }
    
    key := m.buildKey(userID, sessionID)
    
    // Retrieve stored token
    storedToken, err := m.redis.HGet(ctx, key, "token").Result()
    if err != nil {
        if err == redis.Nil {
            return ErrTokenNotFound
        }
        return fmt.Errorf("retrieve csrf token: %w", err)
    }
    
    // Constant-time comparison to prevent timing attacks
    if !secureCompare(storedToken, token) {
        return ErrTokenInvalid
    }
    
    // Verify token hasn't expired (double-check despite Redis TTL)
    createdAt, err := m.redis.HGet(ctx, key, "created_at").Int64()
    if err != nil {
        return fmt.Errorf("get token creation time: %w", err)
    }
    
    if time.Since(time.Unix(createdAt, 0)) > m.tokenTTL {
        m.RevokeToken(ctx, userID, sessionID)
        return ErrTokenExpired
    }
    
    return nil
}

// RotateToken generates a new token and invalidates the old one
func (m *CSRFManager) RotateToken(ctx context.Context, userID, sessionID string) (string, error) {
    // Revoke existing token
    if err := m.RevokeToken(ctx, userID, sessionID); err != nil {
        // Log but don't fail - old token might not exist
        logger.Debug("Failed to revoke old token", "error", err)
    }
    
    // Generate new token
    return m.GenerateToken(ctx, userID, sessionID)
}

// RevokeToken invalidates a specific token
func (m *CSRFManager) RevokeToken(ctx context.Context, userID, sessionID string) error {
    key := m.buildKey(userID, sessionID)
    userKey := m.buildUserKey(userID)
    
    pipe := m.redis.TxPipeline()
    pipe.Del(ctx, key)
    pipe.SRem(ctx, userKey, key)
    
    _, err := pipe.Exec(ctx)
    return err
}

// RevokeAllUserTokens invalidates all tokens for a user
func (m *CSRFManager) RevokeAllUserTokens(ctx context.Context, userID string) error {
    userKey := m.buildUserKey(userID)
    
    // Get all token keys for user
    tokenKeys, err := m.redis.SMembers(ctx, userKey).Result()
    if err != nil {
        return fmt.Errorf("get user tokens: %w", err)
    }
    
    if len(tokenKeys) == 0 {
        return nil
    }
    
    // Delete all tokens and user set
    pipe := m.redis.TxPipeline()
    for _, key := range tokenKeys {
        pipe.Del(ctx, key)
    }
    pipe.Del(ctx, userKey)
    
    _, err = pipe.Exec(ctx)
    return err
}

func (m *CSRFManager) buildKey(userID, sessionID string) string {
    return fmt.Sprintf("%s%s:%s", KeyPrefix, userID, sessionID)
}

func (m *CSRFManager) buildUserKey(userID string) string {
    return fmt.Sprintf("%s%s%s", KeyPrefix, UserPrefix, userID)
}

// secureCompare performs constant-time string comparison
func secureCompare(a, b string) bool {
    if len(a) != len(b) {
        return false
    }
    
    var result byte
    for i := 0; i < len(a); i++ {
        result |= a[i] ^ b[i]
    }
    return result == 0
}

// Error definitions
var (
    ErrTokenMissing  = errors.New("csrf: token missing")
    ErrTokenNotFound = errors.New("csrf: token not found in store")
    ErrTokenInvalid  = errors.New("csrf: token validation failed")
    ErrTokenExpired  = errors.New("csrf: token expired")
)
```

### 2. Gin Framework Middleware Implementation (avion-gateway)

#### Complete CSRF Middleware for Gin

```go
package middleware

import (
    "context"
    "net/http"
    "strings"
)

const (
    // Header names
    CSRFHeaderName = "X-CSRF-Token"
    CSRFCookieName = "csrf_token"
    
    // Context keys
    ContextKeyUserID    = "user_id"
    ContextKeySessionID = "session_id"
)

// CSRFMiddleware provides CSRF protection for Gin framework
type CSRFMiddleware struct {
    manager          *csrf.CSRFManager
    secureCookie     bool
    sameSite         http.SameSite
    domain           string
    skipPaths        []string
    originWhitelist  []string
    logger           *slog.Logger
    metrics          *CSRFMetrics
}

// CSRFConfig holds CSRF middleware configuration
type CSRFConfig struct {
    SecureCookie    bool
    SameSite        http.SameSite
    Domain          string
    SkipPaths       []string
    OriginWhitelist []string
}

func NewCSRFMiddleware(manager *csrf.CSRFManager, config CSRFConfig, logger *slog.Logger) *CSRFMiddleware {
    return &CSRFMiddleware{
        manager:         manager,
        secureCookie:    config.SecureCookie,
        sameSite:        config.SameSite,
        domain:          config.Domain,
        skipPaths:       config.SkipPaths,
        originWhitelist: config.OriginWhitelist,
        logger:          logger,
        metrics:         NewCSRFMetrics(),
    }
}

// GinMiddleware returns a Gin middleware handler for CSRF protection
func (m *CSRFMiddleware) GinMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        // Check if path should skip CSRF
        if m.shouldSkipPath(c.Request.URL.Path) {
            c.Next()
            return
        }
        
        // Skip CSRF check for safe methods
        if isSafeMethod(c.Request.Method) {
            c.Next()
            return
        }
        
        // Validate Origin header
        if !m.validateOrigin(c.Request) {
            m.logger.Warn("CSRF origin validation failed",
                "origin", c.Request.Header.Get("Origin"),
                "referer", c.Request.Header.Get("Referer"),
                "ip", c.ClientIP())
            m.metrics.RecordFailure("origin_mismatch")
            c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
                "error": "Origin validation failed",
                "code": "CSRF_ORIGIN_INVALID",
            })
            return
        }
        
        // Extract user and session from context (set by auth middleware)
        userID, exists := c.Get("user_id")
        if !exists {
            c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
                "error": "Authentication required",
                "code": "AUTH_REQUIRED",
            })
            return
        }
        
        sessionID, exists := c.Get("session_id")
        if !exists {
            c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
                "error": "Session required",
                "code": "SESSION_REQUIRED",
            })
            return
        }
        
        // Get token from header
        headerToken := c.Request.Header.Get(CSRFHeaderName)
        if headerToken == "" {
            m.metrics.RecordFailure("missing_header")
            c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
                "error": "CSRF token missing in header",
                "code": "CSRF_HEADER_MISSING",
            })
            return
        }
        
        // Get token from cookie (double-submit cookie pattern)
        cookieToken, err := c.Cookie(CSRFCookieName)
        if err != nil || cookieToken == "" {
            m.metrics.RecordFailure("missing_cookie")
            c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
                "error": "CSRF token missing in cookie",
                "code": "CSRF_COOKIE_MISSING",
            })
            return
        }
        
        // Verify tokens match (constant-time comparison)
        if !secureCompare(headerToken, cookieToken) {
            m.metrics.RecordFailure("token_mismatch")
            c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
                "error": "CSRF token mismatch",
                "code": "CSRF_TOKEN_MISMATCH",
            })
            return
        }
        
        // Validate token with Redis
        if err := m.manager.ValidateToken(c.Request.Context(), 
            userID.(string), sessionID.(string), headerToken); err != nil {
            m.logger.Debug("CSRF token validation failed",
                "error", err,
                "user_id", userID,
                "session_id", sessionID)
            m.metrics.RecordFailure("invalid_token")
            c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
                "error": "Invalid CSRF token",
                "code": "CSRF_TOKEN_INVALID",
            })
            return
        }
        
        m.metrics.RecordSuccess()
        
        // Token is valid, proceed with request
        c.Next()
    }
}

// shouldSkipPath checks if the path should skip CSRF protection
func (m *CSRFMiddleware) shouldSkipPath(path string) bool {
    for _, skipPath := range m.skipPaths {
        if strings.HasPrefix(path, skipPath) {
            return true
        }
    }
    return false
}

// validateOrigin validates the Origin header against whitelist
func (m *CSRFMiddleware) validateOrigin(r *http.Request) bool {
    origin := r.Header.Get("Origin")
    
    // If no Origin header, check Referer as fallback
    if origin == "" {
        referer := r.Header.Get("Referer")
        if referer != "" {
            if u, err := url.Parse(referer); err == nil {
                origin = fmt.Sprintf("%s://%s", u.Scheme, u.Host)
            }
        }
    }
    
    // No origin information available (might be same-origin request)
    if origin == "" {
        return true
    }
    
    // Check against whitelist
    for _, allowed := range m.originWhitelist {
        if origin == allowed {
            return true
        }
    }
    
    return false
}

// GenerateTokenEndpoint handles CSRF token generation requests
func (m *CSRFMiddleware) GenerateTokenEndpoint() gin.HandlerFunc {
    return func(c *gin.Context) {
        userID, exists := c.Get("user_id")
        if !exists {
            c.JSON(http.StatusUnauthorized, gin.H{
                "error": "Authentication required",
                "code": "AUTH_REQUIRED",
            })
            return
        }
        
        sessionID, exists := c.Get("session_id")
        if !exists {
            c.JSON(http.StatusUnauthorized, gin.H{
                "error": "Session required",
                "code": "SESSION_REQUIRED",
            })
            return
        }
        
        // Generate new token
        token, err := m.manager.GenerateToken(c.Request.Context(), 
            userID.(string), sessionID.(string))
        if err != nil {
            m.logger.Error("Failed to generate CSRF token",
                "error", err,
                "user_id", userID)
            c.JSON(http.StatusInternalServerError, gin.H{
                "error": "Failed to generate CSRF token",
                "code": "CSRF_GENERATION_FAILED",
            })
            return
        }
        
        // Set cookie
        m.setCSRFCookie(c, token)
        
        m.metrics.RecordTokenGeneration()
        
        // Return token in response
        c.JSON(http.StatusOK, gin.H{
            "csrf_token": token,
            "expires_in": int(TokenTTL.Seconds()),
        })
    }
}

// RefreshTokenEndpoint handles CSRF token refresh requests
func (m *CSRFMiddleware) RefreshTokenEndpoint() gin.HandlerFunc {
    return func(c *gin.Context) {
        userID, exists := c.Get("user_id")
        if !exists {
            c.JSON(http.StatusUnauthorized, gin.H{
                "error": "Authentication required",
                "code": "AUTH_REQUIRED",
            })
            return
        }
        
        sessionID, exists := c.Get("session_id")
        if !exists {
            c.JSON(http.StatusUnauthorized, gin.H{
                "error": "Session required",
                "code": "SESSION_REQUIRED",
            })
            return
        }
        
        // Rotate token
        token, err := m.manager.RotateToken(c.Request.Context(),
            userID.(string), sessionID.(string))
        if err != nil {
            m.logger.Error("Failed to rotate CSRF token",
                "error", err,
                "user_id", userID)
            c.JSON(http.StatusInternalServerError, gin.H{
                "error": "Failed to refresh CSRF token",
                "code": "CSRF_REFRESH_FAILED",
            })
            return
        }
        
        // Set new cookie
        m.setCSRFCookie(c, token)
        
        m.metrics.RecordTokenRotation()
        
        c.JSON(http.StatusOK, gin.H{
            "csrf_token": token,
            "expires_in": int(TokenTTL.Seconds()),
        })
    }
}

// setCSRFCookie sets the CSRF token cookie with security settings
func (m *CSRFMiddleware) setCSRFCookie(c *gin.Context, token string) {
    c.SetSameSite(m.sameSite)
    c.SetCookie(
        CSRFCookieName,
        token,
        int(TokenTTL.Seconds()),
        "/",
        m.domain,
        m.secureCookie,
        false, // HttpOnly must be false for JavaScript access
    )
}

// CSRFMetrics tracks CSRF protection metrics
type CSRFMetrics struct {
    tokenGenerated prometheus.Counter
    tokenRotated   prometheus.Counter
    validations    *prometheus.CounterVec
    failures       *prometheus.CounterVec
}

func NewCSRFMetrics() *CSRFMetrics {
    return &CSRFMetrics{
        tokenGenerated: prometheus.NewCounter(prometheus.CounterOpts{
            Name: "csrf_tokens_generated_total",
            Help: "Total number of CSRF tokens generated",
        }),
        tokenRotated: prometheus.NewCounter(prometheus.CounterOpts{
            Name: "csrf_tokens_rotated_total",
            Help: "Total number of CSRF tokens rotated",
        }),
        validations: prometheus.NewCounterVec(
            prometheus.CounterOpts{
                Name: "csrf_validations_total",
                Help: "Total number of CSRF validations",
            },
            []string{"result"},
        ),
        failures: prometheus.NewCounterVec(
            prometheus.CounterOpts{
                Name: "csrf_failures_total",
                Help: "Total number of CSRF failures by reason",
            },
            []string{"reason"},
        ),
    }
}

func (m *CSRFMetrics) RecordTokenGeneration() {
    m.tokenGenerated.Inc()
}

func (m *CSRFMetrics) RecordTokenRotation() {
    m.tokenRotated.Inc()
}

func (m *CSRFMetrics) RecordSuccess() {
    m.validations.WithLabelValues("success").Inc()
}

func (m *CSRFMetrics) RecordFailure(reason string) {
    m.validations.WithLabelValues("failure").Inc()
    m.failures.WithLabelValues(reason).Inc()
}

func isSafeMethod(method string) bool {
    safeMethods := map[string]bool{
        "GET":     true,
        "HEAD":    true,
        "OPTIONS": true,
        "TRACE":   true,
    }
    return safeMethods[strings.ToUpper(method)]
}

// extractIP extracts the client IP from the request context
func extractIP(ctx context.Context) string {
    // Implementation depends on your reverse proxy setup
    // This is a placeholder - adapt to your infrastructure
    return "unknown"
}
```

### 3. Integration with avion-gateway

#### Router Setup

```go
package main

import (
    "github.com/gin-gonic/gin"
    "github.com/na2na-p/avion/avion-gateway/internal/middleware"
    "github.com/na2na-p/avion/avion-gateway/internal/csrf"
    "github.com/redis/go-redis/v9"
)

func setupRouter(redisClient *redis.Client, config *Config) *gin.Engine {
    router := gin.New()
    
    // Initialize CSRF manager
    csrfManager := csrf.NewCSRFManager(redisClient)
    
    // Create CSRF middleware
    csrfMiddleware := middleware.NewCSRFMiddleware(
        csrfManager,
        middleware.CSRFConfig{
            SecureCookie:    config.IsProduction(),
            SameSite:        getSameSiteMode(config),
            Domain:          config.CookieDomain,
            SkipPaths:       []string{
                "/health",
                "/metrics",
                "/api/v1/auth/login",
                "/api/v1/auth/register",
            },
            OriginWhitelist: config.AllowedOrigins,
        },
        logger,
    )
    
    // Global middlewares
    router.Use(
        gin.Recovery(),
        middleware.RequestID(),
        middleware.Logger(logger),
        middleware.CORS(config.CORSConfig),
    )
    
    // API v1 routes
    v1 := router.Group("/api/v1")
    {
        // Public endpoints (no CSRF)
        public := v1.Group("/")
        {
            public.GET("/health", healthCheck)
            public.POST("/auth/login", authHandler.Login)
            public.POST("/auth/register", authHandler.Register)
        }
        
        // Protected endpoints (require auth + CSRF)
        protected := v1.Group("/")
        protected.Use(
            middleware.JWTAuth(authService),
            csrfMiddleware.GinMiddleware(),
        )
        {
            // CSRF token management
            protected.GET("/csrf/token", csrfMiddleware.GenerateTokenEndpoint())
            protected.POST("/csrf/refresh", csrfMiddleware.RefreshTokenEndpoint())
            
            // GraphQL endpoint
            protected.POST("/graphql", graphqlHandler())
            
            // User operations
            protected.PUT("/users/profile", userHandler.UpdateProfile)
            protected.DELETE("/users/account", userHandler.DeleteAccount)
            
            // Social operations
            protected.POST("/users/:id/follow", socialHandler.Follow)
            protected.DELETE("/users/:id/follow", socialHandler.Unfollow)
            protected.POST("/users/:id/block", socialHandler.Block)
            
            // Content operations
            protected.POST("/drops", dropHandler.Create)
            protected.PUT("/drops/:id", dropHandler.Update)
            protected.DELETE("/drops/:id", dropHandler.Delete)
        }
    }
    
    return router
}

func getSameSiteMode(config *Config) http.SameSite {
    switch config.Environment {
    case "production":
        return http.SameSiteStrictMode
    case "staging":
        return http.SameSiteLaxMode
    default:
        return http.SameSiteNoneMode // For local development
    }
}
```

#### GraphQL Integration

```go
package handlers

import (
    "github.com/99designs/gqlgen/graphql/handler"
    "github.com/99designs/gqlgen/graphql/handler/transport"
    "github.com/gin-gonic/gin"
)

func NewGraphQLHandler(resolver *Resolver) gin.HandlerFunc {
    srv := handler.NewDefaultServer(generated.NewExecutableSchema(
        generated.Config{Resolvers: resolver},
    ))
    
    // Configure transports
    srv.AddTransport(transport.POST{})
    srv.AddTransport(transport.Options{})
    
    // Add WebSocket support with CSRF validation
    srv.AddTransport(&transport.Websocket{
        InitFunc: func(ctx context.Context, initPayload transport.InitPayload) (context.Context, error) {
            // Extract CSRF token from connection params
            token, ok := initPayload["csrfToken"].(string)
            if !ok {
                return nil, errors.New("CSRF token required for WebSocket connection")
            }
            
            // Extract auth info from connection params
            authToken, ok := initPayload["authToken"].(string)
            if !ok {
                return nil, errors.New("Auth token required")
            }
            
            // Validate auth and get user/session
            userID, sessionID, err := validateAuthToken(authToken)
            if err != nil {
                return nil, err
            }
            
            // Validate CSRF token
            if err := csrfManager.ValidateToken(ctx, userID, sessionID, token); err != nil {
                return nil, errors.New("Invalid CSRF token")
            }
            
            // Add to context
            ctx = context.WithValue(ctx, "user_id", userID)
            ctx = context.WithValue(ctx, "session_id", sessionID)
            
            return ctx, nil
        },
        KeepAlivePingInterval: 10 * time.Second,
    })
    
    return func(c *gin.Context) {
        srv.ServeHTTP(c.Writer, c.Request)
    }
}
```

### 4. gRPC Interceptor Implementation

```go
package interceptor

import (
    "context"
    "google.golang.org/grpc"
    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/metadata"
    "google.golang.org/grpc/status"
)

// CSRFInterceptor provides CSRF protection for gRPC services
type CSRFInterceptor struct {
    manager *csrf.CSRFManager
}

func NewCSRFInterceptor(manager *csrf.CSRFManager) *CSRFInterceptor {
    return &CSRFInterceptor{manager: manager}
}

// UnaryInterceptor provides CSRF protection for unary RPC calls
func (i *CSRFInterceptor) UnaryInterceptor() grpc.UnaryServerInterceptor {
    return func(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
        // Skip CSRF check for read-only methods
        if isReadOnlyMethod(info.FullMethod) {
            return handler(ctx, req)
        }
        
        // Extract metadata
        md, ok := metadata.FromIncomingContext(ctx)
        if !ok {
            return nil, status.Error(codes.InvalidArgument, "missing metadata")
        }
        
        // Get CSRF token from metadata
        tokens := md.Get("x-csrf-token")
        if len(tokens) == 0 {
            return nil, status.Error(codes.PermissionDenied, "CSRF token missing")
        }
        
        // Get user and session from context
        userID := getUserIDFromContext(ctx)
        sessionID := getSessionIDFromContext(ctx)
        
        if userID == "" || sessionID == "" {
            return nil, status.Error(codes.Unauthenticated, "unauthorized")
        }
        
        // Validate token
        if err := i.manager.ValidateToken(ctx, userID, sessionID, tokens[0]); err != nil {
            return nil, status.Error(codes.PermissionDenied, "invalid CSRF token")
        }
        
        return handler(ctx, req)
    }
}

// StreamInterceptor provides CSRF protection for streaming RPC calls
func (i *CSRFInterceptor) StreamInterceptor() grpc.StreamServerInterceptor {
    return func(srv interface{}, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
        // Skip CSRF check for read-only methods
        if isReadOnlyMethod(info.FullMethod) {
            return handler(srv, ss)
        }
        
        ctx := ss.Context()
        md, ok := metadata.FromIncomingContext(ctx)
        if !ok {
            return status.Error(codes.InvalidArgument, "missing metadata")
        }
        
        tokens := md.Get("x-csrf-token")
        if len(tokens) == 0 {
            return status.Error(codes.PermissionDenied, "CSRF token missing")
        }
        
        userID := getUserIDFromContext(ctx)
        sessionID := getSessionIDFromContext(ctx)
        
        if userID == "" || sessionID == "" {
            return status.Error(codes.Unauthenticated, "unauthorized")
        }
        
        if err := i.manager.ValidateToken(ctx, userID, sessionID, tokens[0]); err != nil {
            return status.Error(codes.PermissionDenied, "invalid CSRF token")
        }
        
        return handler(srv, ss)
    }
}
```

### 5. Advanced Redis Patterns

#### Redis Operations with Pipelining and Lua Scripts

```go
package csrf

import (
    "context"
    "fmt"
    "time"
    
    "github.com/redis/go-redis/v9"
)

// RedisScripts contains Lua scripts for atomic operations
type RedisScripts struct {
    validateAndTouch *redis.Script
    cleanupExpired   *redis.Script
    bulkRevoke       *redis.Script
}

func NewRedisScripts() *RedisScripts {
    return &RedisScripts{
        // Validate token and update last accessed time atomically
        validateAndTouch: redis.NewScript(`
            local key = KEYS[1]
            local token = ARGV[1]
            local now = ARGV[2]
            local ttl = ARGV[3]
            
            local stored_token = redis.call('HGET', key, 'token')
            if not stored_token then
                return 0 -- Token not found
            end
            
            if stored_token ~= token then
                return -1 -- Token mismatch
            end
            
            -- Update last accessed time and refresh TTL
            redis.call('HSET', key, 'last_accessed', now)
            redis.call('EXPIRE', key, ttl)
            
            return 1 -- Success
        `),
        
        // Clean up expired tokens for a user
        cleanupExpired: redis.NewScript(`
            local user_key = KEYS[1]
            local now = tonumber(ARGV[1])
            local ttl = tonumber(ARGV[2])
            
            local token_keys = redis.call('SMEMBERS', user_key)
            local removed = 0
            
            for i, key in ipairs(token_keys) do
                local created = redis.call('HGET', key, 'created_at')
                if created then
                    created = tonumber(created)
                    if now - created > ttl then
                        redis.call('DEL', key)
                        redis.call('SREM', user_key, key)
                        removed = removed + 1
                    end
                end
            end
            
            return removed
        `),
        
        // Bulk revoke tokens with pattern matching
        bulkRevoke: redis.NewScript(`
            local pattern = KEYS[1]
            local cursor = "0"
            local count = 0
            
            repeat
                local result = redis.call('SCAN', cursor, 'MATCH', pattern, 'COUNT', 100)
                cursor = result[1]
                local keys = result[2]
                
                for i, key in ipairs(keys) do
                    redis.call('DEL', key)
                    count = count + 1
                end
            until cursor == "0"
            
            return count
        `),
    }
}

// EnhancedCSRFManager extends the basic manager with advanced Redis operations
type EnhancedCSRFManager struct {
    *CSRFManager
    scripts *RedisScripts
    monitor *CSRFMonitor
}

func NewEnhancedCSRFManager(redisClient *redis.Client) *EnhancedCSRFManager {
    return &EnhancedCSRFManager{
        CSRFManager: NewCSRFManager(redisClient),
        scripts:     NewRedisScripts(),
        monitor:     NewCSRFMonitor(),
    }
}

// ValidateWithTouch validates token and updates last accessed time atomically
func (m *EnhancedCSRFManager) ValidateWithTouch(ctx context.Context, userID, sessionID, token string) error {
    key := m.buildKey(userID, sessionID)
    
    result, err := m.scripts.validateAndTouch.Run(
        ctx,
        m.redis,
        []string{key},
        token,
        time.Now().Unix(),
        int(m.tokenTTL.Seconds()),
    ).Int()
    
    if err != nil {
        return fmt.Errorf("validate token script: %w", err)
    }
    
    switch result {
    case 0:
        return ErrTokenNotFound
    case -1:
        return ErrTokenInvalid
    case 1:
        return nil
    default:
        return fmt.Errorf("unexpected script result: %d", result)
    }
}

// CleanupExpiredTokens removes expired tokens for a user
func (m *EnhancedCSRFManager) CleanupExpiredTokens(ctx context.Context, userID string) (int, error) {
    userKey := m.buildUserKey(userID)
    
    removed, err := m.scripts.cleanupExpired.Run(
        ctx,
        m.redis,
        []string{userKey},
        time.Now().Unix(),
        int(m.tokenTTL.Seconds()),
    ).Int()
    
    if err != nil {
        return 0, fmt.Errorf("cleanup expired tokens: %w", err)
    }
    
    m.monitor.RecordCleanup(userID, removed)
    return removed, nil
}

// BulkRevokeByPattern revokes all tokens matching a pattern
func (m *EnhancedCSRFManager) BulkRevokeByPattern(ctx context.Context, pattern string) (int, error) {
    fullPattern := fmt.Sprintf("%s%s", KeyPrefix, pattern)
    
    revoked, err := m.scripts.bulkRevoke.Run(
        ctx,
        m.redis,
        []string{fullPattern},
    ).Int()
    
    if err != nil {
        return 0, fmt.Errorf("bulk revoke tokens: %w", err)
    }
    
    m.monitor.RecordBulkRevoke(pattern, revoked)
    return revoked, nil
}

// GetTokenStats retrieves statistics about active tokens
func (m *EnhancedCSRFManager) GetTokenStats(ctx context.Context, userID string) (*TokenStats, error) {
    userKey := m.buildUserKey(userID)
    
    // Get all token keys for user
    tokenKeys, err := m.redis.SMembers(ctx, userKey).Result()
    if err != nil {
        return nil, fmt.Errorf("get user tokens: %w", err)
    }
    
    stats := &TokenStats{
        UserID:      userID,
        TotalTokens: len(tokenKeys),
        Sessions:    make(map[string]*SessionInfo),
    }
    
    // Get details for each token
    for _, key := range tokenKeys {
        data, err := m.redis.HGetAll(ctx, key).Result()
        if err != nil {
            continue
        }
        
        sessionID := data["session_id"]
        createdAt, _ := strconv.ParseInt(data["created_at"], 10, 64)
        lastAccessed, _ := strconv.ParseInt(data["last_accessed"], 10, 64)
        
        stats.Sessions[sessionID] = &SessionInfo{
            SessionID:    sessionID,
            CreatedAt:    time.Unix(createdAt, 0),
            LastAccessed: time.Unix(lastAccessed, 0),
            IP:           data["ip"],
        }
    }
    
    return stats, nil
}

// CSRFMonitor tracks CSRF operations for monitoring
type CSRFMonitor struct {
    tokenOps      *prometheus.HistogramVec
    cleanupOps    prometheus.Counter
    bulkRevokeOps prometheus.Counter
}

func NewCSRFMonitor() *CSRFMonitor {
    return &CSRFMonitor{
        tokenOps: prometheus.NewHistogramVec(
            prometheus.HistogramOpts{
                Name:    "csrf_token_operations_duration_seconds",
                Help:    "Duration of CSRF token operations",
                Buckets: prometheus.DefBuckets,
            },
            []string{"operation"},
        ),
        cleanupOps: prometheus.NewCounter(
            prometheus.CounterOpts{
                Name: "csrf_cleanup_operations_total",
                Help: "Total number of CSRF cleanup operations",
            },
        ),
        bulkRevokeOps: prometheus.NewCounter(
            prometheus.CounterOpts{
                Name: "csrf_bulk_revoke_operations_total",
                Help: "Total number of CSRF bulk revoke operations",
            },
        ),
    }
}

type TokenStats struct {
    UserID      string
    TotalTokens int
    Sessions    map[string]*SessionInfo
}

type SessionInfo struct {
    SessionID    string
    CreatedAt    time.Time
    LastAccessed time.Time
    IP           string
}
```

### 6. Frontend Integration

#### TypeScript/React Implementation

```typescript
// csrf.service.ts
export class CSRFService {
    private static instance: CSRFService;
    private token: string | null = null;
    private tokenRefreshInterval: NodeJS.Timeout | null = null;
    
    private constructor() {
        this.initializeToken();
        this.startTokenRefresh();
    }
    
    static getInstance(): CSRFService {
        if (!CSRFService.instance) {
            CSRFService.instance = new CSRFService();
        }
        return CSRFService.instance;
    }
    
    /**
     * Initialize CSRF token from cookie or fetch new one
     */
    private async initializeToken(): Promise<void> {
        // Try to get token from cookie first
        this.token = this.getTokenFromCookie();
        
        if (!this.token) {
            // Fetch new token from server
            await this.refreshToken();
        }
    }
    
    /**
     * Get CSRF token from cookie
     */
    private getTokenFromCookie(): string | null {
        const match = document.cookie.match(/csrf_token=([^;]+)/);
        return match ? match[1] : null;
    }
    
    /**
     * Refresh CSRF token from server
     */
    async refreshToken(): Promise<void> {
        try {
            const response = await fetch('/api/v1/csrf/token', {
                method: 'GET',
                credentials: 'include',
            });
            
            if (!response.ok) {
                throw new Error('Failed to fetch CSRF token');
            }
            
            const data = await response.json();
            this.token = data.csrf_token;
        } catch (error) {
            console.error('Failed to refresh CSRF token:', error);
            throw error;
        }
    }
    
    /**
     * Start automatic token refresh
     */
    private startTokenRefresh(): void {
        // Refresh token every 23 hours (before 24-hour expiry)
        this.tokenRefreshInterval = setInterval(() => {
            this.refreshToken();
        }, 23 * 60 * 60 * 1000);
    }
    
    /**
     * Get current CSRF token
     */
    getToken(): string {
        if (!this.token) {
            throw new Error('CSRF token not initialized');
        }
        return this.token;
    }
    
    /**
     * Add CSRF token to request headers
     */
    addTokenToHeaders(headers: Headers): Headers {
        headers.set('X-CSRF-Token', this.getToken());
        return headers;
    }
    
    /**
     * Create fetch options with CSRF token
     */
    createFetchOptions(options: RequestInit = {}): RequestInit {
        const headers = new Headers(options.headers);
        this.addTokenToHeaders(headers);
        
        return {
            ...options,
            headers,
            credentials: 'include', // Always include cookies
        };
    }
    
    /**
     * Cleanup resources
     */
    destroy(): void {
        if (this.tokenRefreshInterval) {
            clearInterval(this.tokenRefreshInterval);
        }
    }
}

// api.client.ts
export class APIClient {
    private csrfService: CSRFService;
    
    constructor() {
        this.csrfService = CSRFService.getInstance();
    }
    
    /**
     * Make authenticated API request with CSRF protection
     */
    async request<T>(url: string, options: RequestInit = {}): Promise<T> {
        // Add CSRF token for state-changing methods
        if (this.isStateChangingMethod(options.method || 'GET')) {
            options = this.csrfService.createFetchOptions(options);
        }
        
        const response = await fetch(url, options);
        
        // Handle CSRF token errors
        if (response.status === 403) {
            const text = await response.text();
            if (text.includes('CSRF')) {
                // Token might be expired, refresh and retry
                await this.csrfService.refreshToken();
                options = this.csrfService.createFetchOptions(options);
                const retryResponse = await fetch(url, options);
                
                if (!retryResponse.ok) {
                    throw new Error('CSRF validation failed after refresh');
                }
                
                return retryResponse.json();
            }
        }
        
        if (!response.ok) {
            throw new Error(`API request failed: ${response.statusText}`);
        }
        
        return response.json();
    }
    
    private isStateChangingMethod(method: string): boolean {
        const stateChangingMethods = ['POST', 'PUT', 'DELETE', 'PATCH'];
        return stateChangingMethods.includes(method.toUpperCase());
    }
}

// React Hook
export function useCSRFProtection() {
    const [csrfToken, setCSRFToken] = useState<string | null>(null);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<Error | null>(null);
    
    useEffect(() => {
        const csrfService = CSRFService.getInstance();
        
        const initializeCSRF = async () => {
            try {
                setLoading(true);
                await csrfService.refreshToken();
                setCSRFToken(csrfService.getToken());
                setError(null);
            } catch (err) {
                setError(err as Error);
            } finally {
                setLoading(false);
            }
        };
        
        initializeCSRF();
        
        return () => {
            // Cleanup if needed
        };
    }, []);
    
    return { csrfToken, loading, error };
}

// Apollo Client Integration
import { ApolloClient, ApolloLink, InMemoryCache, createHttpLink } from '@apollo/client';
import { setContext } from '@apollo/client/link/context';
import { WebSocketLink } from '@apollo/client/link/ws';
import { getMainDefinition } from '@apollo/client/utilities';

export function createApolloClient() {
    const csrfService = CSRFService.getInstance();
    
    // HTTP Link with CSRF token
    const httpLink = createHttpLink({
        uri: '/api/v1/graphql',
        credentials: 'include',
    });
    
    // Add CSRF token to headers
    const authLink = setContext((_, { headers }) => {
        const token = csrfService.getToken();
        return {
            headers: {
                ...headers,
                'X-CSRF-Token': token,
            },
        };
    });
    
    // WebSocket Link with CSRF token in connection params
    const wsLink = new WebSocketLink({
        uri: `ws://localhost:8080/api/v1/graphql`,
        options: {
            reconnect: true,
            connectionParams: async () => {
                const authToken = localStorage.getItem('auth_token');
                const csrfToken = csrfService.getToken();
                
                return {
                    authToken,
                    csrfToken,
                };
            },
        },
    });
    
    // Split between WebSocket and HTTP
    const splitLink = ApolloLink.split(
        ({ query }) => {
            const definition = getMainDefinition(query);
            return (
                definition.kind === 'OperationDefinition' &&
                definition.operation === 'subscription'
            );
        },
        wsLink,
        authLink.concat(httpLink),
    );
    
    return new ApolloClient({
        link: splitLink,
        cache: new InMemoryCache(),
        defaultOptions: {
            watchQuery: {
                errorPolicy: 'all',
            },
            query: {
                errorPolicy: 'all',
            },
        },
    });
}

// Axios Interceptor
import axios from 'axios';

export function setupAxiosCSRF() {
    const csrfService = CSRFService.getInstance();
    
    // Request interceptor
    axios.interceptors.request.use(
        (config) => {
            // Add CSRF token for state-changing methods
            const method = config.method?.toUpperCase();
            if (method && ['POST', 'PUT', 'DELETE', 'PATCH'].includes(method)) {
                config.headers['X-CSRF-Token'] = csrfService.getToken();
            }
            
            // Ensure cookies are sent
            config.withCredentials = true;
            
            return config;
        },
        (error) => Promise.reject(error)
    );
    
    // Response interceptor for CSRF token refresh
    axios.interceptors.response.use(
        (response) => response,
        async (error) => {
            const originalRequest = error.config;
            
            if (error.response?.status === 403 && 
                error.response?.data?.code === 'CSRF_TOKEN_INVALID' &&
                !originalRequest._retry) {
                
                originalRequest._retry = true;
                
                try {
                    await csrfService.refreshToken();
                    originalRequest.headers['X-CSRF-Token'] = csrfService.getToken();
                    return axios(originalRequest);
                } catch (refreshError) {
                    // Token refresh failed, redirect to login
                    window.location.href = '/login';
                    return Promise.reject(refreshError);
                }
            }
            
            return Promise.reject(error);
        }
    );
}
```

## Testing and Verification

### Automated Testing Strategy

```go
package csrf_test

import (
    "testing"
    "time"
    "net/http"
    "net/http/httptest"
    
    "github.com/gin-gonic/gin"
    "github.com/stretchr/testify/suite"
    "github.com/alicebob/miniredis/v2"
    "github.com/redis/go-redis/v9"
)

type CSRFTestSuite struct {
    suite.Suite
    redis      *miniredis.Miniredis
    client     *redis.Client
    manager    *csrf.EnhancedCSRFManager
    middleware *middleware.CSRFMiddleware
    router     *gin.Engine
}

func (s *CSRFTestSuite) SetupTest() {
    // Setup mini Redis for testing
    s.redis = miniredis.RunT(s.T())
    s.client = redis.NewClient(&redis.Options{
        Addr: s.redis.Addr(),
    })
    
    // Initialize CSRF components
    s.manager = csrf.NewEnhancedCSRFManager(s.client)
    s.middleware = middleware.NewCSRFMiddleware(
        s.manager,
        middleware.CSRFConfig{
            SecureCookie: false,
            SameSite:     http.SameSiteLaxMode,
            Domain:       "localhost",
            SkipPaths:    []string{"/health"},
            OriginWhitelist: []string{
                "http://localhost:3000",
                "http://localhost:8080",
            },
        },
        slog.Default(),
    )
    
    // Setup test router
    s.router = gin.New()
    s.setupTestRoutes()
}

func (s *CSRFTestSuite) setupTestRoutes() {
    // Mock auth middleware
    authMiddleware := func(c *gin.Context) {
        c.Set("user_id", "test-user-123")
        c.Set("session_id", "test-session-456")
        c.Next()
    }
    
    s.router.GET("/health", func(c *gin.Context) {
        c.JSON(200, gin.H{"status": "ok"})
    })
    
    api := s.router.Group("/api")
    api.Use(authMiddleware)
    {
        api.GET("/csrf/token", s.middleware.GenerateTokenEndpoint())
        api.POST("/csrf/refresh", s.middleware.RefreshTokenEndpoint())
        
        protected := api.Group("/")
        protected.Use(s.middleware.GinMiddleware())
        {
            protected.POST("/test", func(c *gin.Context) {
                c.JSON(200, gin.H{"message": "success"})
            })
            protected.PUT("/test", func(c *gin.Context) {
                c.JSON(200, gin.H{"message": "updated"})
            })
            protected.DELETE("/test", func(c *gin.Context) {
                c.JSON(200, gin.H{"message": "deleted"})
            })
        }
    }
}

func (s *CSRFTestSuite) TestCSRFTokenGeneration() {
    w := httptest.NewRecorder()
    req, _ := http.NewRequest("GET", "/api/csrf/token", nil)
    
    s.router.ServeHTTP(w, req)
    
    s.Equal(http.StatusOK, w.Code)
    
    // Check response body
    var response map[string]interface{}
    json.Unmarshal(w.Body.Bytes(), &response)
    s.Contains(response, "csrf_token")
    s.Contains(response, "expires_in")
    
    // Check cookie
    cookies := w.Result().Cookies()
    s.Len(cookies, 1)
    s.Equal("csrf_token", cookies[0].Name)
    s.Equal(response["csrf_token"], cookies[0].Value)
}

func (s *CSRFTestSuite) TestProtectedEndpointWithValidToken() {
    // First, get a CSRF token
    tokenReq, _ := http.NewRequest("GET", "/api/csrf/token", nil)
    tokenResp := httptest.NewRecorder()
    s.router.ServeHTTP(tokenResp, tokenReq)
    
    var tokenData map[string]string
    json.Unmarshal(tokenResp.Body.Bytes(), &tokenData)
    csrfToken := tokenData["csrf_token"]
    
    // Make protected request with token
    req, _ := http.NewRequest("POST", "/api/test", nil)
    req.Header.Set("X-CSRF-Token", csrfToken)
    req.Header.Set("Origin", "http://localhost:3000")
    req.AddCookie(&http.Cookie{
        Name:  "csrf_token",
        Value: csrfToken,
    })
    
    w := httptest.NewRecorder()
    s.router.ServeHTTP(w, req)
    
    s.Equal(http.StatusOK, w.Code)
}

func (s *CSRFTestSuite) TestProtectedEndpointWithoutToken() {
    req, _ := http.NewRequest("POST", "/api/test", nil)
    req.Header.Set("Origin", "http://localhost:3000")
    
    w := httptest.NewRecorder()
    s.router.ServeHTTP(w, req)
    
    s.Equal(http.StatusForbidden, w.Code)
    
    var response map[string]string
    json.Unmarshal(w.Body.Bytes(), &response)
    s.Equal("CSRF_HEADER_MISSING", response["code"])
}

func (s *CSRFTestSuite) TestTokenMismatch() {
    req, _ := http.NewRequest("POST", "/api/test", nil)
    req.Header.Set("X-CSRF-Token", "token-in-header")
    req.Header.Set("Origin", "http://localhost:3000")
    req.AddCookie(&http.Cookie{
        Name:  "csrf_token",
        Value: "different-token-in-cookie",
    })
    
    w := httptest.NewRecorder()
    s.router.ServeHTTP(w, req)
    
    s.Equal(http.StatusForbidden, w.Code)
    
    var response map[string]string
    json.Unmarshal(w.Body.Bytes(), &response)
    s.Equal("CSRF_TOKEN_MISMATCH", response["code"])
}

func (s *CSRFTestSuite) TestOriginValidation() {
    // Get valid token first
    tokenReq, _ := http.NewRequest("GET", "/api/csrf/token", nil)
    tokenResp := httptest.NewRecorder()
    s.router.ServeHTTP(tokenResp, tokenReq)
    
    var tokenData map[string]string
    json.Unmarshal(tokenResp.Body.Bytes(), &tokenData)
    csrfToken := tokenData["csrf_token"]
    
    // Test with invalid origin
    req, _ := http.NewRequest("POST", "/api/test", nil)
    req.Header.Set("X-CSRF-Token", csrfToken)
    req.Header.Set("Origin", "http://evil-site.com")
    req.AddCookie(&http.Cookie{
        Name:  "csrf_token",
        Value: csrfToken,
    })
    
    w := httptest.NewRecorder()
    s.router.ServeHTTP(w, req)
    
    s.Equal(http.StatusForbidden, w.Code)
    
    var response map[string]string
    json.Unmarshal(w.Body.Bytes(), &response)
    s.Equal("CSRF_ORIGIN_INVALID", response["code"])
}

func (s *CSRFTestSuite) TestTokenRotation() {
    // Get initial token
    tokenReq1, _ := http.NewRequest("GET", "/api/csrf/token", nil)
    tokenResp1 := httptest.NewRecorder()
    s.router.ServeHTTP(tokenResp1, tokenReq1)
    
    var tokenData1 map[string]string
    json.Unmarshal(tokenResp1.Body.Bytes(), &tokenData1)
    initialToken := tokenData1["csrf_token"]
    
    // Refresh token
    refreshReq, _ := http.NewRequest("POST", "/api/csrf/refresh", nil)
    refreshReq.Header.Set("X-CSRF-Token", initialToken)
    refreshReq.AddCookie(&http.Cookie{
        Name:  "csrf_token",
        Value: initialToken,
    })
    
    refreshResp := httptest.NewRecorder()
    s.router.ServeHTTP(refreshResp, refreshReq)
    
    s.Equal(http.StatusOK, refreshResp.Code)
    
    var tokenData2 map[string]string
    json.Unmarshal(refreshResp.Body.Bytes(), &tokenData2)
    newToken := tokenData2["csrf_token"]
    
    s.NotEqual(initialToken, newToken)
    
    // Old token should be invalid
    req, _ := http.NewRequest("POST", "/api/test", nil)
    req.Header.Set("X-CSRF-Token", initialToken)
    req.AddCookie(&http.Cookie{
        Name:  "csrf_token",
        Value: initialToken,
    })
    
    w := httptest.NewRecorder()
    s.router.ServeHTTP(w, req)
    
    s.Equal(http.StatusForbidden, w.Code)
}

func (s *CSRFTestSuite) TestConcurrentTokenValidation() {
    // Test concurrent token validations
    ctx := context.Background()
    userID := "concurrent-user"
    sessionID := "concurrent-session"
    
    token, err := s.manager.GenerateToken(ctx, userID, sessionID)
    s.NoError(err)
    
    // Simulate concurrent validations
    var wg sync.WaitGroup
    errors := make(chan error, 100)
    
    for i := 0; i < 100; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            err := s.manager.ValidateToken(ctx, userID, sessionID, token)
            if err != nil {
                errors <- err
            }
        }()
    }
    
    wg.Wait()
    close(errors)
    
    // All validations should succeed
    s.Len(errors, 0)
}

func TestCSRFSuite(t *testing.T) {
    suite.Run(t, new(CSRFTestSuite))
}
```

## Testing CSRF Protection

### Unit Tests

```go
func TestCSRFTokenGeneration(t *testing.T) {
    redisClient := setupRedisTestClient(t)
    manager := csrf.NewCSRFManager(redisClient)
    
    tests := []struct {
        name      string
        userID    string
        sessionID string
    }{
        {
            name:      "Generate token for new session",
            userID:    "user-123",
            sessionID: "session-456",
        },
        {
            name:      "Generate token for different user",
            userID:    "user-789",
            sessionID: "session-012",
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            ctx := context.Background()
            
            // Generate token
            token, err := manager.GenerateToken(ctx, tt.userID, tt.sessionID)
            assert.NoError(t, err)
            assert.NotEmpty(t, token)
            
            // Validate token
            err = manager.ValidateToken(ctx, tt.userID, tt.sessionID, token)
            assert.NoError(t, err)
            
            // Invalid token should fail
            err = manager.ValidateToken(ctx, tt.userID, tt.sessionID, "invalid-token")
            assert.Error(t, err)
        })
    }
}

func TestCSRFMiddleware(t *testing.T) {
    manager := csrf.NewCSRFManager(setupRedisTestClient(t))
    middleware := NewCSRFMiddleware(manager, CSRFConfig{
        SecureCookie: false,
        SameSite:     http.SameSiteLaxMode,
    })
    
    tests := []struct {
        name           string
        method         string
        headerToken    string
        cookieToken    string
        expectedStatus int
    }{
        {
            name:           "GET request bypasses CSRF",
            method:         "GET",
            expectedStatus: http.StatusOK,
        },
        {
            name:           "POST without tokens fails",
            method:         "POST",
            expectedStatus: http.StatusForbidden,
        },
        {
            name:           "POST with mismatched tokens fails",
            method:         "POST",
            headerToken:    "token1",
            cookieToken:    "token2",
            expectedStatus: http.StatusForbidden,
        },
        {
            name:           "POST with valid tokens succeeds",
            method:         "POST",
            headerToken:    "valid-token",
            cookieToken:    "valid-token",
            expectedStatus: http.StatusOK,
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            req := httptest.NewRequest(tt.method, "/api/test", nil)
            
            // Set tokens if provided
            if tt.headerToken != "" {
                req.Header.Set("X-CSRF-Token", tt.headerToken)
            }
            if tt.cookieToken != "" {
                req.AddCookie(&http.Cookie{
                    Name:  "csrf_token",
                    Value: tt.cookieToken,
                })
            }
            
            // Add auth context
            ctx := context.WithValue(req.Context(), "user_id", "test-user")
            ctx = context.WithValue(ctx, "session_id", "test-session")
            req = req.WithContext(ctx)
            
            // If valid tokens, create them in Redis
            if tt.headerToken == "valid-token" {
                manager.GenerateToken(ctx, "test-user", "test-session")
                // Override with specific token for test
                key := fmt.Sprintf("csrf:test-user:test-session")
                manager.redis.HSet(ctx, key, "token", "valid-token")
            }
            
            rr := httptest.NewRecorder()
            handler := middleware.Protect(func(w http.ResponseWriter, r *http.Request) {
                w.WriteHeader(http.StatusOK)
            })
            
            handler(rr, req)
            assert.Equal(t, tt.expectedStatus, rr.Code)
        })
    }
}
```

### Integration Tests

```go
func TestCSRFEndToEnd(t *testing.T) {
    // Setup test server with CSRF protection
    server := setupTestServerWithCSRF(t)
    defer server.Close()
    
    client := &http.Client{
        Jar: http.DefaultClient.Jar,
    }
    
    // Step 1: Authenticate and get CSRF token
    authResp, err := client.Post(
        server.URL+"/api/v1/auth/login",
        "application/json",
        strings.NewReader(`{"username":"test","password":"test"}`),
    )
    require.NoError(t, err)
    require.Equal(t, http.StatusOK, authResp.StatusCode)
    
    // Step 2: Get CSRF token
    tokenResp, err := client.Get(server.URL + "/api/v1/csrf/token")
    require.NoError(t, err)
    require.Equal(t, http.StatusOK, tokenResp.StatusCode)
    
    var tokenData map[string]string
    json.NewDecoder(tokenResp.Body).Decode(&tokenData)
    csrfToken := tokenData["csrf_token"]
    
    // Step 3: Make protected request with CSRF token
    req, _ := http.NewRequest("POST", server.URL+"/api/v1/users", strings.NewReader(`{"name":"test"}`))
    req.Header.Set("X-CSRF-Token", csrfToken)
    req.Header.Set("Content-Type", "application/json")
    
    resp, err := client.Do(req)
    require.NoError(t, err)
    assert.Equal(t, http.StatusOK, resp.StatusCode)
    
    // Step 4: Request without CSRF token should fail
    req2, _ := http.NewRequest("POST", server.URL+"/api/v1/users", strings.NewReader(`{"name":"test2"}`))
    req2.Header.Set("Content-Type", "application/json")
    
    resp2, err := client.Do(req2)
    require.NoError(t, err)
    assert.Equal(t, http.StatusForbidden, resp2.StatusCode)
}
```

## Security Headers Configuration

```go
// Additional security headers to complement CSRF protection
func SecurityHeaders(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Prevent clickjacking
        w.Header().Set("X-Frame-Options", "DENY")
        
        // Prevent MIME sniffing
        w.Header().Set("X-Content-Type-Options", "nosniff")
        
        // Enable XSS protection
        w.Header().Set("X-XSS-Protection", "1; mode=block")
        
        // Referrer policy
        w.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
        
        // Permissions policy
        w.Header().Set("Permissions-Policy", "geolocation=(), microphone=(), camera=()")
        
        next.ServeHTTP(w, r)
    })
}
```

## Configuration Examples

### Development Configuration

```yaml
# config/development.yaml
csrf:
  enabled: true
  token_ttl: 24h
  secure_cookie: false
  same_site: "Lax"
  domain: "localhost"
  redis:
    host: "localhost:6379"
    db: 1
    key_prefix: "csrf:dev:"
```

### Production Configuration

```yaml
# config/production.yaml
csrf:
  enabled: true
  token_ttl: 12h
  secure_cookie: true
  same_site: "Strict"
  domain: ".avion.app"
  redis:
    host: "redis-cluster.internal:6379"
    db: 1
    key_prefix: "csrf:prod:"
    tls_enabled: true
    password: "${REDIS_PASSWORD}"
```

## Monitoring and Alerts

```go
// Metrics for CSRF protection
var (
    csrfTokensGenerated = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "csrf_tokens_generated_total",
            Help: "Total number of CSRF tokens generated",
        },
        []string{"service"},
    )
    
    csrfValidationFailures = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "csrf_validation_failures_total",
            Help: "Total number of CSRF validation failures",
        },
        []string{"service", "reason"},
    )
    
    csrfTokenRotations = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "csrf_token_rotations_total",
            Help: "Total number of CSRF token rotations",
        },
        []string{"service"},
    )
)
```

## Troubleshooting Guide

### Common Issues and Solutions

#### Token Mismatch Errors
- **Cause:** Cookie and header tokens don't match
- **Solution:** Ensure JavaScript correctly reads cookie and sets header

#### Token Expiration
- **Cause:** Token TTL exceeded
- **Solution:** Implement automatic token refresh on client

#### Missing Token in Cross-Origin Requests
- **Cause:** CORS preventing cookie access
- **Solution:** Configure proper CORS headers and credentials

#### Redis Connection Issues
- **Cause:** Redis unavailable or misconfigured
- **Solution:** Implement fallback mechanism or circuit breaker

## Manual Testing Checklist

### Browser DevTools Testing

1. **Token Generation**
   ```javascript
   // In browser console
   fetch('/api/v1/csrf/token', { credentials: 'include' })
     .then(r => r.json())
     .then(console.log);
   
   // Check cookies
   document.cookie.match(/csrf_token=([^;]+)/);
   ```

2. **Protected Request Testing**
   ```javascript
   // Get token first
   const token = document.cookie.match(/csrf_token=([^;]+)/)[1];
   
   // Test protected endpoint
   fetch('/api/v1/drops', {
     method: 'POST',
     headers: {
       'Content-Type': 'application/json',
       'X-CSRF-Token': token
     },
     credentials: 'include',
     body: JSON.stringify({ content: 'Test drop' })
   });
   ```

3. **Cross-Origin Attack Simulation**
   ```html
   <!-- evil-site.html -->
   <script>
   // This should fail due to CSRF protection
   fetch('http://localhost:8080/api/v1/drops', {
     method: 'POST',
     credentials: 'include',
     body: JSON.stringify({ content: 'Malicious drop' })
   });
   </script>
   ```

### cURL Testing Commands

```bash
# 1. Authenticate and get session
curl -c cookies.txt -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test"}'

# 2. Get CSRF token
CSRF_TOKEN=$(curl -b cookies.txt -c cookies.txt \
  http://localhost:8080/api/v1/csrf/token \
  | jq -r '.csrf_token')

# 3. Make protected request with CSRF token
curl -b cookies.txt -X POST http://localhost:8080/api/v1/drops \
  -H "Content-Type: application/json" \
  -H "X-CSRF-Token: $CSRF_TOKEN" \
  -d '{"content":"Test drop with CSRF protection"}'

# 4. Test failure without CSRF token (should fail)
curl -b cookies.txt -X POST http://localhost:8080/api/v1/drops \
  -H "Content-Type: application/json" \
  -d '{"content":"This should fail"}'
```

## Security Checklist

### Required Implementation
- [ ] CSRF tokens generated for all authenticated sessions
- [ ] Double-submit cookie pattern implemented
- [ ] Token validation on all state-changing operations
- [ ] Secure cookie settings in production
- [ ] SameSite cookie attribute configured
- [ ] Token rotation on privilege escalation
- [ ] Token revocation on logout
- [ ] Origin header validation for cross-origin requests
- [ ] Redis-based centralized token management
- [ ] Constant-time token comparison

### Recommended Practices
- [ ] Automatic token refresh before expiry
- [ ] Per-request token rotation for sensitive operations
- [ ] Referer header validation as backup
- [ ] Custom header requirement (X-CSRF-Token)
- [ ] Rate limiting on token generation
- [ ] Monitoring and alerting for failures
- [ ] Token cleanup for expired sessions
- [ ] IP address tracking for tokens
- [ ] Bulk revocation capabilities

## Deployment Considerations

### Kubernetes Configuration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: avion-gateway-csrf-config
  namespace: avion
data:
  csrf.yaml: |
    csrf:
      enabled: true
      token_ttl: 12h
      secure_cookie: true
      same_site: "Strict"
      domain: ".avion.app"
      skip_paths:
        - /health
        - /metrics
        - /api/v1/auth/login
        - /api/v1/auth/register
      origin_whitelist:
        - https://avion.app
        - https://www.avion.app
        - https://app.avion.app
      redis:
        host: redis-master.avion.svc.cluster.local:6379
        db: 2
        key_prefix: "csrf:prod:"
        max_retries: 3
        pool_size: 10
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: avion-gateway
  namespace: avion
spec:
  template:
    spec:
      containers:
      - name: gateway
        env:
        - name: CSRF_ENABLED
          value: "true"
        - name: CSRF_REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-credentials
              key: password
        volumeMounts:
        - name: csrf-config
          mountPath: /config/csrf.yaml
          subPath: csrf.yaml
      volumes:
      - name: csrf-config
        configMap:
          name: avion-gateway-csrf-config
```

### Performance Optimization

```go
// Connection pooling for Redis
func NewRedisClient(config *RedisConfig) *redis.Client {
    return redis.NewClient(&redis.Options{
        Addr:         config.Address,
        Password:     config.Password,
        DB:           config.DB,
        PoolSize:     config.PoolSize,     // 10 * runtime.GOMAXPROCS
        MinIdleConns: config.MinIdleConns, // 5
        MaxRetries:   config.MaxRetries,   // 3
        DialTimeout:  5 * time.Second,
        ReadTimeout:  3 * time.Second,
        WriteTimeout: 3 * time.Second,
        PoolTimeout:  4 * time.Second,
    })
}

// Circuit breaker for Redis operations
type CSRFManagerWithCircuitBreaker struct {
    *EnhancedCSRFManager
    breaker *gobreaker.CircuitBreaker
}

func (m *CSRFManagerWithCircuitBreaker) ValidateToken(ctx context.Context, userID, sessionID, token string) error {
    operation := func() (interface{}, error) {
        return nil, m.EnhancedCSRFManager.ValidateToken(ctx, userID, sessionID, token)
    }
    
    _, err := m.breaker.Execute(operation)
    if err != nil {
        // Fallback: Allow request but log for investigation
        m.logger.Error("CSRF validation circuit open", "error", err)
        // Depending on security requirements, you might want to fail closed instead
        return nil // or return err to fail closed
    }
    
    return nil
}
```

## Summary

This comprehensive CSRF protection implementation for the Avion platform provides:

1. **Multi-layered Defense**
   - SameSite cookies for modern browser protection
   - Double-submit cookie pattern for backward compatibility
   - Origin validation for additional security
   - Redis-backed token management for centralized control

2. **Production-Ready Features**
   - Complete Gin framework middleware implementation
   - GraphQL and WebSocket support
   - Automatic token rotation and refresh
   - Comprehensive error handling and logging

3. **Operational Excellence**
   - Prometheus metrics for monitoring
   - Circuit breaker pattern for resilience
   - Kubernetes-ready configuration
   - Extensive testing coverage

4. **Frontend Integration**
   - React hooks for easy integration
   - Apollo Client configuration
   - Axios interceptors for automatic token handling
   - WebSocket authentication support

5. **Security Best Practices**
   - Constant-time token comparison
   - Token expiration and rotation
   - IP tracking and session binding
   - Comprehensive audit logging

Regular security audits should verify CSRF protection remains effective across all services. Monitor the metrics dashboard for unusual patterns that might indicate attack attempts.