# Security Headers Configuration Guide

**Last Updated:** 2025/08/30  
**Status:** Production-Ready Implementation Guide  
**Scope:** All Avion microservices with HTTP endpoints  
**Primary Service:** avion-gateway (API Gateway)

## Overview

Security headers are HTTP response headers that provide an additional layer of security by instructing browsers how to behave when handling your site's content. This document provides production-ready implementation for comprehensive security headers in the Avion social networking platform, with environment-specific configurations and ready-to-use Gin middleware implementations.

### Defense-in-Depth Strategy

Security headers implement multiple layers of protection:
1. **Content Security Policy (CSP)**: Prevents XSS and data injection attacks
2. **Frame Options**: Prevents clickjacking attacks
3. **Transport Security**: Enforces HTTPS usage
4. **Content Type Options**: Prevents MIME type sniffing
5. **Permissions Policy**: Controls browser features and APIs

## Quick Reference

### Essential Security Headers
| Header | Purpose | Priority |
|--------|---------|----------|
| Content-Security-Policy | XSS protection, data injection prevention | Critical |
| X-Frame-Options | Clickjacking protection | Critical |
| Strict-Transport-Security | HTTPS enforcement | Critical |
| X-Content-Type-Options | MIME sniffing prevention | High |
| X-XSS-Protection | Legacy XSS protection | Medium |
| Referrer-Policy | Referrer information control | Medium |
| Permissions-Policy | Feature/API access control | Medium |

## Complete Security Headers List

### 1. Content-Security-Policy (CSP)

**Purpose:** Prevents XSS attacks by controlling which resources can be loaded and executed.

```go
// CSP directives for different environments
type CSPConfig struct {
    DefaultSrc     []string
    ScriptSrc      []string
    StyleSrc       []string
    ImgSrc         []string
    FontSrc        []string
    ConnectSrc     []string
    MediaSrc       []string
    ObjectSrc      []string
    FrameSrc       []string
    FrameAncestors []string
    BaseURI        []string
    FormAction     []string
    ReportURI      string
    ReportOnly     bool
}

func (c *CSPConfig) String() string {
    var directives []string
    
    if len(c.DefaultSrc) > 0 {
        directives = append(directives, fmt.Sprintf("default-src %s", strings.Join(c.DefaultSrc, " ")))
    }
    if len(c.ScriptSrc) > 0 {
        directives = append(directives, fmt.Sprintf("script-src %s", strings.Join(c.ScriptSrc, " ")))
    }
    if len(c.StyleSrc) > 0 {
        directives = append(directives, fmt.Sprintf("style-src %s", strings.Join(c.StyleSrc, " ")))
    }
    if len(c.ImgSrc) > 0 {
        directives = append(directives, fmt.Sprintf("img-src %s", strings.Join(c.ImgSrc, " ")))
    }
    if len(c.FontSrc) > 0 {
        directives = append(directives, fmt.Sprintf("font-src %s", strings.Join(c.FontSrc, " ")))
    }
    if len(c.ConnectSrc) > 0 {
        directives = append(directives, fmt.Sprintf("connect-src %s", strings.Join(c.ConnectSrc, " ")))
    }
    if len(c.MediaSrc) > 0 {
        directives = append(directives, fmt.Sprintf("media-src %s", strings.Join(c.MediaSrc, " ")))
    }
    if len(c.ObjectSrc) > 0 {
        directives = append(directives, fmt.Sprintf("object-src %s", strings.Join(c.ObjectSrc, " ")))
    }
    if len(c.FrameSrc) > 0 {
        directives = append(directives, fmt.Sprintf("frame-src %s", strings.Join(c.FrameSrc, " ")))
    }
    if len(c.FrameAncestors) > 0 {
        directives = append(directives, fmt.Sprintf("frame-ancestors %s", strings.Join(c.FrameAncestors, " ")))
    }
    if len(c.BaseURI) > 0 {
        directives = append(directives, fmt.Sprintf("base-uri %s", strings.Join(c.BaseURI, " ")))
    }
    if len(c.FormAction) > 0 {
        directives = append(directives, fmt.Sprintf("form-action %s", strings.Join(c.FormAction, " ")))
    }
    if c.ReportURI != "" {
        directives = append(directives, fmt.Sprintf("report-uri %s", c.ReportURI))
    }
    
    // Add security enhancements
    directives = append(directives, "upgrade-insecure-requests")
    directives = append(directives, "block-all-mixed-content")
    
    return strings.Join(directives, "; ")
}
```

### 2. Strict-Transport-Security (HSTS)

**Purpose:** Forces browsers to use HTTPS connections.

```go
type HSTSConfig struct {
    MaxAge            int    // Seconds
    IncludeSubDomains bool
    Preload           bool
}

func (h *HSTSConfig) String() string {
    value := fmt.Sprintf("max-age=%d", h.MaxAge)
    if h.IncludeSubDomains {
        value += "; includeSubDomains"
    }
    if h.Preload {
        value += "; preload"
    }
    return value
}
```

### 3. X-Frame-Options

**Purpose:** Prevents clickjacking attacks by controlling iframe embedding.

```go
type FrameOptions string

const (
    FrameOptionsDeny       FrameOptions = "DENY"
    FrameOptionsSameOrigin FrameOptions = "SAMEORIGIN"
)
```

### 4. X-Content-Type-Options

**Purpose:** Prevents browsers from MIME-sniffing responses.

```go
const ContentTypeOptionsNoSniff = "nosniff"
```

### 5. X-XSS-Protection

**Purpose:** Legacy XSS protection for older browsers.

```go
type XSSProtection struct {
    Enabled   bool
    ModeBlock bool
    ReportURI string
}

func (x *XSSProtection) String() string {
    if !x.Enabled {
        return "0"
    }
    value := "1"
    if x.ModeBlock {
        value += "; mode=block"
    }
    if x.ReportURI != "" {
        value += fmt.Sprintf("; report=%s", x.ReportURI)
    }
    return value
}
```

### 6. Referrer-Policy

**Purpose:** Controls how much referrer information is sent with requests.

```go
type ReferrerPolicy string

const (
    ReferrerPolicyNoReferrer                  ReferrerPolicy = "no-referrer"
    ReferrerPolicyNoReferrerWhenDowngrade     ReferrerPolicy = "no-referrer-when-downgrade"
    ReferrerPolicyOrigin                      ReferrerPolicy = "origin"
    ReferrerPolicyOriginWhenCrossOrigin       ReferrerPolicy = "origin-when-cross-origin"
    ReferrerPolicySameOrigin                  ReferrerPolicy = "same-origin"
    ReferrerPolicyStrictOrigin                ReferrerPolicy = "strict-origin"
    ReferrerPolicyStrictOriginWhenCrossOrigin ReferrerPolicy = "strict-origin-when-cross-origin"
    ReferrerPolicyUnsafeURL                   ReferrerPolicy = "unsafe-url"
)
```

### 7. Permissions-Policy

**Purpose:** Controls which browser features and APIs can be used.

```go
type PermissionsPolicy struct {
    Accelerometer    []string
    Camera           []string
    Geolocation      []string
    Gyroscope        []string
    Magnetometer     []string
    Microphone       []string
    Payment          []string
    USB              []string
    PublicKeyCredentials []string
}

func (p *PermissionsPolicy) String() string {
    var policies []string
    
    addPolicy := func(name string, origins []string) {
        if len(origins) > 0 {
            policies = append(policies, fmt.Sprintf("%s=(%s)", name, strings.Join(origins, " ")))
        }
    }
    
    addPolicy("accelerometer", p.Accelerometer)
    addPolicy("camera", p.Camera)
    addPolicy("geolocation", p.Geolocation)
    addPolicy("gyroscope", p.Gyroscope)
    addPolicy("magnetometer", p.Magnetometer)
    addPolicy("microphone", p.Microphone)
    addPolicy("payment", p.Payment)
    addPolicy("usb", p.USB)
    addPolicy("publickey-credentials-get", p.PublicKeyCredentials)
    
    return strings.Join(policies, ", ")
}
```

## Gin Middleware Implementation

### Complete Security Headers Middleware

```go
package middleware

import (
    "crypto/rand"
    "encoding/base64"
    "fmt"
    "log/slog"
    "net/http"
    "strings"
    
    "github.com/gin-gonic/gin"
)

// SecurityHeadersConfig holds all security header configurations
type SecurityHeadersConfig struct {
    CSP               *CSPConfig
    HSTS              *HSTSConfig
    FrameOptions      FrameOptions
    ContentTypeOptions bool
    XSSProtection     *XSSProtection
    ReferrerPolicy    ReferrerPolicy
    PermissionsPolicy *PermissionsPolicy
    CustomHeaders     map[string]string
    EnableNonce       bool // For CSP nonce generation
}

// SecurityHeadersMiddleware provides comprehensive security headers
type SecurityHeadersMiddleware struct {
    config  SecurityHeadersConfig
    logger  *slog.Logger
    metrics *SecurityMetrics
}

func NewSecurityHeadersMiddleware(config SecurityHeadersConfig, logger *slog.Logger) *SecurityHeadersMiddleware {
    return &SecurityHeadersMiddleware{
        config:  config,
        logger:  logger,
        metrics: NewSecurityMetrics(),
    }
}

// GinMiddleware returns a Gin middleware handler for security headers
func (m *SecurityHeadersMiddleware) GinMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        // Generate nonce for CSP if enabled
        var nonce string
        if m.config.EnableNonce && m.config.CSP != nil {
            nonce = m.generateNonce()
            c.Set("csp-nonce", nonce)
        }
        
        // Apply Content-Security-Policy
        if m.config.CSP != nil {
            cspValue := m.config.CSP.String()
            if nonce != "" {
                // Add nonce to script-src and style-src
                cspValue = m.addNonceToCSP(cspValue, nonce)
            }
            
            if m.config.CSP.ReportOnly {
                c.Header("Content-Security-Policy-Report-Only", cspValue)
            } else {
                c.Header("Content-Security-Policy", cspValue)
            }
        }
        
        // Apply HSTS (only on HTTPS)
        if m.config.HSTS != nil && m.isHTTPS(c.Request) {
            c.Header("Strict-Transport-Security", m.config.HSTS.String())
        }
        
        // Apply X-Frame-Options
        if m.config.FrameOptions != "" {
            c.Header("X-Frame-Options", string(m.config.FrameOptions))
        }
        
        // Apply X-Content-Type-Options
        if m.config.ContentTypeOptions {
            c.Header("X-Content-Type-Options", ContentTypeOptionsNoSniff)
        }
        
        // Apply X-XSS-Protection
        if m.config.XSSProtection != nil {
            c.Header("X-XSS-Protection", m.config.XSSProtection.String())
        }
        
        // Apply Referrer-Policy
        if m.config.ReferrerPolicy != "" {
            c.Header("Referrer-Policy", string(m.config.ReferrerPolicy))
        }
        
        // Apply Permissions-Policy
        if m.config.PermissionsPolicy != nil {
            c.Header("Permissions-Policy", m.config.PermissionsPolicy.String())
        }
        
        // Apply custom headers
        for name, value := range m.config.CustomHeaders {
            c.Header(name, value)
        }
        
        // Record metrics
        m.metrics.RecordHeadersApplied(c.Request.URL.Path)
        
        c.Next()
    }
}

// generateNonce creates a cryptographically secure nonce for CSP
func (m *SecurityHeadersMiddleware) generateNonce() string {
    nonceBytes := make([]byte, 16)
    if _, err := rand.Read(nonceBytes); err != nil {
        m.logger.Error("Failed to generate CSP nonce", "error", err)
        return ""
    }
    return base64.StdEncoding.EncodeToString(nonceBytes)
}

// addNonceToCSP adds nonce to script-src and style-src directives
func (m *SecurityHeadersMiddleware) addNonceToCSP(csp, nonce string) string {
    nonceValue := fmt.Sprintf("'nonce-%s'", nonce)
    
    // Add to script-src
    if strings.Contains(csp, "script-src") {
        csp = strings.Replace(csp, "script-src", fmt.Sprintf("script-src %s", nonceValue), 1)
    }
    
    // Add to style-src
    if strings.Contains(csp, "style-src") {
        csp = strings.Replace(csp, "style-src", fmt.Sprintf("style-src %s", nonceValue), 1)
    }
    
    return csp
}

// isHTTPS checks if the request is over HTTPS
func (m *SecurityHeadersMiddleware) isHTTPS(r *http.Request) bool {
    // Check direct TLS
    if r.TLS != nil {
        return true
    }
    
    // Check X-Forwarded-Proto header (from reverse proxy)
    if r.Header.Get("X-Forwarded-Proto") == "https" {
        return true
    }
    
    // Check scheme
    return r.URL.Scheme == "https"
}

// SecurityMetrics tracks security header metrics
type SecurityMetrics struct {
    headersApplied   *prometheus.CounterVec
    cspViolations    *prometheus.CounterVec
    nonceGenerated   prometheus.Counter
    hstsApplied      prometheus.Counter
}

func NewSecurityMetrics() *SecurityMetrics {
    return &SecurityMetrics{
        headersApplied: prometheus.NewCounterVec(
            prometheus.CounterOpts{
                Name: "security_headers_applied_total",
                Help: "Total number of security headers applied",
            },
            []string{"path"},
        ),
        cspViolations: prometheus.NewCounterVec(
            prometheus.CounterOpts{
                Name: "csp_violations_total",
                Help: "Total number of CSP violations reported",
            },
            []string{"directive", "blocked_uri"},
        ),
        nonceGenerated: prometheus.NewCounter(
            prometheus.CounterOpts{
                Name: "csp_nonce_generated_total",
                Help: "Total number of CSP nonces generated",
            },
        ),
        hstsApplied: prometheus.NewCounter(
            prometheus.CounterOpts{
                Name: "hsts_headers_applied_total",
                Help: "Total number of HSTS headers applied",
            },
        ),
    }
}
```

### CSP Report Handler

```go
// CSPReportHandler handles Content-Security-Policy violation reports
type CSPReportHandler struct {
    logger  *slog.Logger
    metrics *SecurityMetrics
    store   CSPViolationStore
}

type CSPViolation struct {
    DocumentURI        string `json:"document-uri"`
    Referrer           string `json:"referrer"`
    BlockedURI         string `json:"blocked-uri"`
    ViolatedDirective  string `json:"violated-directive"`
    EffectiveDirective string `json:"effective-directive"`
    OriginalPolicy     string `json:"original-policy"`
    Disposition        string `json:"disposition"`
    StatusCode         int    `json:"status-code"`
    ScriptSample       string `json:"script-sample"`
    LineNumber         int    `json:"line-number"`
    ColumnNumber       int    `json:"column-number"`
    SourceFile         string `json:"source-file"`
}

func (h *CSPReportHandler) HandleReport() gin.HandlerFunc {
    return func(c *gin.Context) {
        var report struct {
            CSPReport CSPViolation `json:"csp-report"`
        }
        
        if err := c.ShouldBindJSON(&report); err != nil {
            h.logger.Error("Failed to parse CSP report", "error", err)
            c.Status(http.StatusBadRequest)
            return
        }
        
        violation := report.CSPReport
        
        // Log violation
        h.logger.Warn("CSP violation reported",
            "document_uri", violation.DocumentURI,
            "blocked_uri", violation.BlockedURI,
            "violated_directive", violation.ViolatedDirective,
            "source_file", violation.SourceFile,
            "line_number", violation.LineNumber,
        )
        
        // Store violation for analysis
        if h.store != nil {
            h.store.Store(c.Request.Context(), violation)
        }
        
        // Update metrics
        h.metrics.cspViolations.WithLabelValues(
            violation.ViolatedDirective,
            violation.BlockedURI,
        ).Inc()
        
        c.Status(http.StatusNoContent)
    }
}
```

## Environment-Specific Configurations

### Development Configuration

```go
func GetDevelopmentSecurityHeaders() SecurityHeadersConfig {
    return SecurityHeadersConfig{
        CSP: &CSPConfig{
            DefaultSrc:     []string{"'self'"},
            ScriptSrc:      []string{"'self'", "'unsafe-inline'", "'unsafe-eval'", "http://localhost:*"},
            StyleSrc:       []string{"'self'", "'unsafe-inline'", "http://localhost:*"},
            ImgSrc:         []string{"'self'", "data:", "blob:", "http://localhost:*"},
            FontSrc:        []string{"'self'", "data:"},
            ConnectSrc:     []string{"'self'", "http://localhost:*", "ws://localhost:*"},
            MediaSrc:       []string{"'self'", "blob:"},
            ObjectSrc:      []string{"'none'"},
            FrameSrc:       []string{"'none'"},
            FrameAncestors: []string{"'none'"},
            BaseURI:        []string{"'self'"},
            FormAction:     []string{"'self'"},
            ReportURI:      "/api/v1/csp-report",
            ReportOnly:     true, // Report-only mode in development
        },
        HSTS: nil, // No HSTS in development (HTTP allowed)
        FrameOptions: FrameOptionsSameOrigin,
        ContentTypeOptions: true,
        XSSProtection: &XSSProtection{
            Enabled:   true,
            ModeBlock: true,
        },
        ReferrerPolicy: ReferrerPolicyStrictOriginWhenCrossOrigin,
        PermissionsPolicy: &PermissionsPolicy{
            Camera:      []string{},
            Microphone:  []string{},
            Geolocation: []string{},
            Payment:     []string{},
        },
        EnableNonce: false, // Disabled for development convenience
    }
}
```

### Staging Configuration

```go
func GetStagingSecurityHeaders() SecurityHeadersConfig {
    return SecurityHeadersConfig{
        CSP: &CSPConfig{
            DefaultSrc:     []string{"'self'"},
            ScriptSrc:      []string{"'self'", "'unsafe-inline'", "https://cdn.avion-staging.app"},
            StyleSrc:       []string{"'self'", "'unsafe-inline'", "https://cdn.avion-staging.app"},
            ImgSrc:         []string{"'self'", "data:", "https:", "blob:"},
            FontSrc:        []string{"'self'", "data:", "https://fonts.gstatic.com"},
            ConnectSrc:     []string{"'self'", "https://api.avion-staging.app", "wss://api.avion-staging.app"},
            MediaSrc:       []string{"'self'", "blob:", "https://media.avion-staging.app"},
            ObjectSrc:      []string{"'none'"},
            FrameSrc:       []string{"'none'"},
            FrameAncestors: []string{"'none'"},
            BaseURI:        []string{"'self'"},
            FormAction:     []string{"'self'"},
            ReportURI:      "https://api.avion-staging.app/api/v1/csp-report",
            ReportOnly:     false,
        },
        HSTS: &HSTSConfig{
            MaxAge:            86400, // 1 day for staging
            IncludeSubDomains: true,
            Preload:           false,
        },
        FrameOptions:       FrameOptionsDeny,
        ContentTypeOptions: true,
        XSSProtection: &XSSProtection{
            Enabled:   true,
            ModeBlock: true,
            ReportURI: "https://api.avion-staging.app/api/v1/xss-report",
        },
        ReferrerPolicy: ReferrerPolicyStrictOriginWhenCrossOrigin,
        PermissionsPolicy: &PermissionsPolicy{
            Camera:      []string{},
            Microphone:  []string{},
            Geolocation: []string{},
            Payment:     []string{},
        },
        EnableNonce: true,
    }
}
```

### Production Configuration

```go
func GetProductionSecurityHeaders() SecurityHeadersConfig {
    return SecurityHeadersConfig{
        CSP: &CSPConfig{
            DefaultSrc:     []string{"'self'"},
            ScriptSrc:      []string{"'self'", "https://cdn.avion.app"},
            StyleSrc:       []string{"'self'", "https://cdn.avion.app"},
            ImgSrc:         []string{"'self'", "data:", "https:", "blob:"},
            FontSrc:        []string{"'self'", "data:", "https://fonts.gstatic.com"},
            ConnectSrc:     []string{"'self'", "https://api.avion.app", "wss://api.avion.app"},
            MediaSrc:       []string{"'self'", "blob:", "https://media.avion.app"},
            ObjectSrc:      []string{"'none'"},
            FrameSrc:       []string{"'none'"},
            FrameAncestors: []string{"'none'"},
            BaseURI:        []string{"'self'"},
            FormAction:     []string{"'self'"},
            ReportURI:      "https://api.avion.app/api/v1/csp-report",
            ReportOnly:     false,
        },
        HSTS: &HSTSConfig{
            MaxAge:            31536000, // 1 year
            IncludeSubDomains: true,
            Preload:           true,
        },
        FrameOptions:       FrameOptionsDeny,
        ContentTypeOptions: true,
        XSSProtection: &XSSProtection{
            Enabled:   true,
            ModeBlock: true,
            ReportURI: "https://api.avion.app/api/v1/xss-report",
        },
        ReferrerPolicy: ReferrerPolicyStrictOrigin,
        PermissionsPolicy: &PermissionsPolicy{
            Camera:               []string{},
            Microphone:           []string{},
            Geolocation:          []string{},
            Payment:              []string{"'self'"},
            PublicKeyCredentials: []string{"'self'"}, // For passkey support
        },
        CustomHeaders: map[string]string{
            "X-Permitted-Cross-Domain-Policies": "none",
            "X-Download-Options":                "noopen",
            "X-DNS-Prefetch-Control":            "off",
        },
        EnableNonce: true,
    }
}
```

## Implementation in avion-gateway

### Router Setup with Security Headers

```go
package main

import (
    "github.com/gin-gonic/gin"
    "github.com/na2na-p/avion/avion-gateway/internal/middleware"
)

func setupRouter(config *Config) *gin.Engine {
    router := gin.New()
    
    // Get environment-specific security headers
    var securityConfig middleware.SecurityHeadersConfig
    switch config.Environment {
    case "production":
        securityConfig = middleware.GetProductionSecurityHeaders()
    case "staging":
        securityConfig = middleware.GetStagingSecurityHeaders()
    default:
        securityConfig = middleware.GetDevelopmentSecurityHeaders()
    }
    
    // Create security headers middleware
    securityMiddleware := middleware.NewSecurityHeadersMiddleware(
        securityConfig,
        logger,
    )
    
    // Global middlewares (order matters!)
    router.Use(
        gin.Recovery(),
        middleware.RequestID(),
        middleware.Logger(logger),
        securityMiddleware.GinMiddleware(), // Apply security headers early
        middleware.CORS(config.CORSConfig),
        middleware.RateLimit(config.RateLimitConfig),
    )
    
    // CSP violation reporting endpoint
    cspHandler := middleware.NewCSPReportHandler(logger, metrics, violationStore)
    router.POST("/api/v1/csp-report", cspHandler.HandleReport())
    
    // API routes
    v1 := router.Group("/api/v1")
    {
        // GraphQL endpoint with nonce support
        v1.POST("/graphql", func(c *gin.Context) {
            // Pass nonce to GraphQL context if needed
            if nonce, exists := c.Get("csp-nonce"); exists {
                c.Set("graphql-csp-nonce", nonce)
            }
            graphqlHandler(c)
        })
    }
    
    return router
}
```

### Dynamic CSP for GraphQL Playground

```go
// GraphQL Playground with CSP nonce support
func GraphQLPlaygroundHandler(config PlaygroundConfig) gin.HandlerFunc {
    return func(c *gin.Context) {
        nonce, _ := c.Get("csp-nonce")
        nonceStr, _ := nonce.(string)
        
        html := fmt.Sprintf(`
<!DOCTYPE html>
<html>
<head>
    <meta charset=utf-8/>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>GraphQL Playground</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/graphql-playground-react/build/static/css/index.css" />
    <script nonce="%s" src="https://cdn.jsdelivr.net/npm/graphql-playground-react/build/static/js/middleware.js"></script>
</head>
<body>
    <div id="root"></div>
    <script nonce="%s">
        window.addEventListener('load', function (event) {
            GraphQLPlayground.init(document.getElementById('root'), {
                endpoint: '%s',
                subscriptionEndpoint: '%s',
                settings: {
                    'request.credentials': 'include',
                }
            })
        })
    </script>
</body>
</html>`, nonceStr, nonceStr, config.Endpoint, config.SubscriptionEndpoint)
        
        c.Data(http.StatusOK, "text/html; charset=utf-8", []byte(html))
    }
}
```

## Browser Compatibility Considerations

### Compatibility Matrix

| Header | Chrome | Firefox | Safari | Edge | IE11 |
|--------|--------|---------|--------|------|------|
| CSP Level 3 | 59+ | 58+ | 15.4+ | 79+ | No |
| CSP Level 2 | 40+ | 31+ | 10+ | 15+ | No |
| HSTS | 4+ | 4+ | 7+ | 12+ | 11 |
| X-Frame-Options | All | All | All | All | 8+ |
| X-Content-Type-Options | All | 50+ | All | All | 8+ |
| Referrer-Policy | 61+ | 87+ | 15+ | 79+ | No |
| Permissions-Policy | 88+ | 74+ | No | 88+ | No |

### Feature Detection and Fallbacks

```javascript
// Frontend: Detect CSP support
function hasCSPSupport() {
    try {
        return 'securityPolicy' in document || 
               'SecurityPolicyViolationEvent' in window;
    } catch (e) {
        return false;
    }
}

// Detect and handle CSP violations
if (hasCSPSupport()) {
    document.addEventListener('securitypolicyviolation', (e) => {
        console.error('CSP Violation:', {
            blockedURI: e.blockedURI,
            violatedDirective: e.violatedDirective,
            originalPolicy: e.originalPolicy
        });
        
        // Send to analytics
        if (window.analytics) {
            window.analytics.track('CSP Violation', {
                directive: e.violatedDirective,
                blocked: e.blockedURI
            });
        }
    });
}

// Feature detection for Permissions Policy
function hasPermissionsPolicySupport() {
    return 'permissions' in navigator || 'featurePolicy' in document;
}
```

## Testing with Automated Tools

### Security Headers Test Script

```go
package security_test

import (
    "net/http"
    "net/http/httptest"
    "testing"
    
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/suite"
)

type SecurityHeadersTestSuite struct {
    suite.Suite
    server *httptest.Server
    client *http.Client
}

func (s *SecurityHeadersTestSuite) SetupSuite() {
    // Setup test server with security headers
    router := setupTestRouter()
    s.server = httptest.NewServer(router)
    s.client = &http.Client{}
}

func (s *SecurityHeadersTestSuite) TestProductionHeaders() {
    tests := []struct {
        name           string
        headerName     string
        expectedValue  string
        shouldContain  bool
    }{
        {
            name:          "CSP header present",
            headerName:    "Content-Security-Policy",
            expectedValue: "default-src 'self'",
            shouldContain: true,
        },
        {
            name:          "HSTS header present",
            headerName:    "Strict-Transport-Security",
            expectedValue: "max-age=31536000",
            shouldContain: true,
        },
        {
            name:          "Frame options deny",
            headerName:    "X-Frame-Options",
            expectedValue: "DENY",
            shouldContain: false,
        },
        {
            name:          "Content type options",
            headerName:    "X-Content-Type-Options",
            expectedValue: "nosniff",
            shouldContain: false,
        },
        {
            name:          "XSS protection",
            headerName:    "X-XSS-Protection",
            expectedValue: "1; mode=block",
            shouldContain: false,
        },
        {
            name:          "Referrer policy",
            headerName:    "Referrer-Policy",
            expectedValue: "strict-origin",
            shouldContain: false,
        },
    }
    
    resp, err := s.client.Get(s.server.URL + "/api/v1/test")
    s.NoError(err)
    defer resp.Body.Close()
    
    for _, tt := range tests {
        s.Run(tt.name, func() {
            headerValue := resp.Header.Get(tt.headerName)
            s.NotEmpty(headerValue, "Header %s should be present", tt.headerName)
            
            if tt.shouldContain {
                s.Contains(headerValue, tt.expectedValue)
            } else {
                s.Equal(tt.expectedValue, headerValue)
            }
        })
    }
}

func (s *SecurityHeadersTestSuite) TestCSPNonceGeneration() {
    resp1, _ := s.client.Get(s.server.URL + "/api/v1/test")
    csp1 := resp1.Header.Get("Content-Security-Policy")
    
    resp2, _ := s.client.Get(s.server.URL + "/api/v1/test")
    csp2 := resp2.Header.Get("Content-Security-Policy")
    
    // Extract nonces
    nonce1 := extractNonce(csp1)
    nonce2 := extractNonce(csp2)
    
    // Nonces should be different for each request
    s.NotEqual(nonce1, nonce2)
    s.Len(nonce1, 24) // Base64 encoded 16 bytes
}

func (s *SecurityHeadersTestSuite) TestCSPReportEndpoint() {
    report := `{
        "csp-report": {
            "document-uri": "https://avion.app/",
            "referrer": "",
            "violated-directive": "script-src",
            "effective-directive": "script-src",
            "original-policy": "default-src 'self'",
            "blocked-uri": "https://evil.com/script.js",
            "status-code": 200
        }
    }`
    
    resp, err := s.client.Post(
        s.server.URL+"/api/v1/csp-report",
        "application/csp-report",
        strings.NewReader(report),
    )
    
    s.NoError(err)
    s.Equal(http.StatusNoContent, resp.StatusCode)
}

func TestSecurityHeadersSuite(t *testing.T) {
    suite.Run(t, new(SecurityHeadersTestSuite))
}
```

### Automated Security Scanner Integration

```go
// Integration with security scanning tools
type SecurityScanner struct {
    client  *http.Client
    baseURL string
    logger  *slog.Logger
}

func (s *SecurityScanner) ScanHeaders(endpoint string) (*SecurityReport, error) {
    resp, err := s.client.Get(s.baseURL + endpoint)
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()
    
    report := &SecurityReport{
        Endpoint:   endpoint,
        Timestamp:  time.Now(),
        Headers:    make(map[string]HeaderAnalysis),
    }
    
    // Analyze each security header
    s.analyzeCSP(resp.Header, report)
    s.analyzeHSTS(resp.Header, report)
    s.analyzeFrameOptions(resp.Header, report)
    s.analyzeContentTypeOptions(resp.Header, report)
    s.analyzeXSSProtection(resp.Header, report)
    s.analyzeReferrerPolicy(resp.Header, report)
    s.analyzePermissionsPolicy(resp.Header, report)
    
    // Calculate security score
    report.Score = s.calculateScore(report)
    report.Grade = s.calculateGrade(report.Score)
    
    return report, nil
}

func (s *SecurityScanner) analyzeCSP(headers http.Header, report *SecurityReport) {
    csp := headers.Get("Content-Security-Policy")
    if csp == "" {
        csp = headers.Get("Content-Security-Policy-Report-Only")
    }
    
    analysis := HeaderAnalysis{
        Present: csp != "",
        Value:   csp,
    }
    
    if csp != "" {
        // Check for unsafe directives
        if strings.Contains(csp, "'unsafe-inline'") {
            analysis.Warnings = append(analysis.Warnings, "Contains 'unsafe-inline'")
        }
        if strings.Contains(csp, "'unsafe-eval'") {
            analysis.Warnings = append(analysis.Warnings, "Contains 'unsafe-eval'")
        }
        if !strings.Contains(csp, "default-src") {
            analysis.Warnings = append(analysis.Warnings, "Missing default-src directive")
        }
        
        analysis.Score = s.scoreCSP(csp)
    }
    
    report.Headers["Content-Security-Policy"] = analysis
}

type SecurityReport struct {
    Endpoint   string
    Timestamp  time.Time
    Headers    map[string]HeaderAnalysis
    Score      int
    Grade      string
    Warnings   []string
    Critical   []string
}

type HeaderAnalysis struct {
    Present  bool
    Value    string
    Score    int
    Warnings []string
}
```

### Command-Line Testing Tools

```bash
#!/bin/bash
# security-headers-test.sh

URL="${1:-http://localhost:8080}"

echo "Testing Security Headers for: $URL"
echo "=================================="

# Function to check header
check_header() {
    local header_name=$1
    local expected_value=$2
    local actual_value=$(curl -s -I "$URL" | grep -i "^$header_name:" | cut -d' ' -f2-)
    
    if [ -z "$actual_value" ]; then
        echo "❌ $header_name: MISSING"
        return 1
    elif [ -n "$expected_value" ] && [[ "$actual_value" != *"$expected_value"* ]]; then
        echo "⚠️  $header_name: $actual_value (expected: $expected_value)"
        return 1
    else
        echo "✅ $header_name: $actual_value"
        return 0
    fi
}

# Test essential headers
check_header "Content-Security-Policy" "default-src"
check_header "X-Frame-Options" "DENY"
check_header "X-Content-Type-Options" "nosniff"
check_header "Strict-Transport-Security" "max-age="
check_header "X-XSS-Protection" "1; mode=block"
check_header "Referrer-Policy" ""
check_header "Permissions-Policy" ""

# Test with Mozilla Observatory
echo ""
echo "Running Mozilla Observatory scan..."
curl -X POST "https://http-observatory.security.mozilla.org/api/v1/analyze?host=$URL" \
    -H "Content-Type: application/json" \
    -d '{"hidden": true}'

# Test with securityheaders.com API
echo ""
echo "Running securityheaders.com scan..."
curl -X GET "https://securityheaders.com/?q=$URL&followRedirects=on"
```

## Common Issues and Troubleshooting

### Issue 1: CSP Blocking Legitimate Resources

**Symptoms:**
- Scripts or styles not loading
- Console errors about CSP violations
- Broken functionality in production

**Solution:**
```go
// Implement CSP report-only mode first
func EnableCSPReportOnly(config *CSPConfig) {
    config.ReportOnly = true
    config.ReportURI = "/api/v1/csp-report"
}

// Analyze reports before enforcing
func AnalyzeCSPReports(reports []CSPViolation) map[string]int {
    violations := make(map[string]int)
    for _, report := range reports {
        key := fmt.Sprintf("%s:%s", report.ViolatedDirective, report.BlockedURI)
        violations[key]++
    }
    return violations
}

// Gradually tighten CSP
func MigrateCSPPolicy(current *CSPConfig) *CSPConfig {
    // Start with permissive policy
    if current == nil {
        return &CSPConfig{
            DefaultSrc: []string{"'self'", "*"},
            ReportOnly: true,
        }
    }
    
    // Gradually restrict
    if contains(current.DefaultSrc, "*") {
        current.DefaultSrc = []string{"'self'", "https:"}
    } else if contains(current.DefaultSrc, "https:") {
        current.DefaultSrc = []string{"'self'"}
    }
    
    return current
}
```

### Issue 2: HSTS Causing Access Issues

**Symptoms:**
- Users unable to access site after HSTS is enabled
- Certificate errors preventing access
- Development environment issues

**Solution:**
```go
// Gradual HSTS rollout
func GetHSTSConfig(environment string, week int) *HSTSConfig {
    switch environment {
    case "production":
        // Gradually increase max-age
        maxAges := []int{
            300,      // 5 minutes (week 1)
            3600,     // 1 hour (week 2)
            86400,    // 1 day (week 3)
            604800,   // 1 week (week 4)
            2592000,  // 30 days (week 5)
            31536000, // 1 year (week 6+)
        }
        
        maxAge := maxAges[min(week-1, len(maxAges)-1)]
        
        return &HSTSConfig{
            MaxAge:            maxAge,
            IncludeSubDomains: week > 4,
            Preload:           week > 8,
        }
    default:
        return nil // No HSTS in development
    }
}
```

### Issue 3: Nonce Generation Performance

**Symptoms:**
- Increased latency per request
- High CPU usage
- Memory allocation issues

**Solution:**
```go
// Nonce pool for performance
type NoncePool struct {
    pool chan string
    size int
}

func NewNoncePool(size int) *NoncePool {
    p := &NoncePool{
        pool: make(chan string, size),
        size: size,
    }
    
    // Pre-generate nonces
    go p.refill()
    
    return p
}

func (p *NoncePool) Get() string {
    select {
    case nonce := <-p.pool:
        return nonce
    default:
        // Generate on demand if pool is empty
        return generateNonce()
    }
}

func (p *NoncePool) refill() {
    for {
        select {
        case p.pool <- generateNonce():
            // Added to pool
        default:
            // Pool is full, wait
            time.Sleep(100 * time.Millisecond)
        }
    }
}
```

### Issue 4: Permissions Policy Breaking Features

**Symptoms:**
- Camera/microphone not working
- Geolocation features disabled
- Payment APIs blocked

**Solution:**
```go
// Feature-based Permissions Policy
func GetPermissionsPolicy(features []string) *PermissionsPolicy {
    policy := &PermissionsPolicy{
        // Default: deny all
        Camera:      []string{},
        Microphone:  []string{},
        Geolocation: []string{},
        Payment:     []string{},
    }
    
    // Enable requested features
    for _, feature := range features {
        switch feature {
        case "camera":
            policy.Camera = []string{"'self'"}
        case "microphone":
            policy.Microphone = []string{"'self'"}
        case "geolocation":
            policy.Geolocation = []string{"'self'"}
        case "payment":
            policy.Payment = []string{"'self'"}
        }
    }
    
    return policy
}
```

## Monitoring and Metrics

### Prometheus Metrics

```go
// Security headers monitoring
var (
    securityHeadersApplied = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "security_headers_applied_total",
            Help: "Total number of times security headers were applied",
        },
        []string{"header_type"},
    )
    
    cspViolations = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "csp_violations_total",
            Help: "Total number of CSP violations reported",
        },
        []string{"directive", "source"},
    )
    
    hstsUpgrades = prometheus.NewCounter(
        prometheus.CounterOpts{
            Name: "hsts_upgrades_total",
            Help: "Total number of HTTP to HTTPS upgrades due to HSTS",
        },
    )
    
    securityScore = prometheus.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "security_headers_score",
            Help: "Current security headers score (0-100)",
        },
        []string{"endpoint"},
    )
)
```

### Grafana Dashboard Configuration

```json
{
  "dashboard": {
    "title": "Security Headers Monitoring",
    "panels": [
      {
        "title": "Security Headers Score",
        "type": "gauge",
        "targets": [
          {
            "expr": "security_headers_score"
          }
        ]
      },
      {
        "title": "CSP Violations",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(csp_violations_total[5m])"
          }
        ]
      },
      {
        "title": "HSTS Upgrades",
        "type": "stat",
        "targets": [
          {
            "expr": "increase(hsts_upgrades_total[1h])"
          }
        ]
      }
    ]
  }
}
```

## Security Checklist

### Required Headers
- [ ] Content-Security-Policy configured and tested
- [ ] Strict-Transport-Security enabled in production
- [ ] X-Frame-Options set to DENY or SAMEORIGIN
- [ ] X-Content-Type-Options set to nosniff
- [ ] X-XSS-Protection configured (for legacy browsers)
- [ ] Referrer-Policy configured appropriately
- [ ] Permissions-Policy restricting unnecessary features

### Implementation Tasks
- [ ] Environment-specific configurations implemented
- [ ] CSP report endpoint configured and monitored
- [ ] Nonce generation for inline scripts/styles
- [ ] HSTS preload submission (production only)
- [ ] Security headers testing in CI/CD pipeline
- [ ] Monitoring and alerting configured
- [ ] Documentation for developers
- [ ] Regular security header audits scheduled

### Testing Requirements
- [ ] Unit tests for all header configurations
- [ ] Integration tests for each environment
- [ ] Browser compatibility testing completed
- [ ] Performance impact assessed
- [ ] CSP report-only mode tested before enforcement
- [ ] Automated security scanning integrated
- [ ] Manual penetration testing performed

## Summary

This comprehensive security headers implementation for the Avion platform provides:

1. **Complete Header Coverage**: All essential security headers with proper configurations
2. **Environment-Specific Settings**: Tailored configurations for development, staging, and production
3. **Production-Ready Code**: Full Gin middleware implementation with metrics and monitoring
4. **CSP Management**: Advanced CSP with nonce support and violation reporting
5. **Testing Strategy**: Comprehensive testing tools and automated validation
6. **Troubleshooting Guide**: Solutions for common issues and gradual rollout strategies
7. **Monitoring**: Prometheus metrics and Grafana dashboards for visibility

Regular security audits should verify that headers remain effective and properly configured. Monitor CSP violation reports to identify and address legitimate resource blocking issues before they impact users.