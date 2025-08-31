# TLS Configuration Guide

**Last Updated:** 2025/08/30  
**Status:** Production-Ready Implementation Guide  
**Scope:** All Avion microservices and Kubernetes infrastructure  
**Primary Components:** Kubernetes Ingress NGINX, cert-manager, internal service mesh

## Overview

Transport Layer Security (TLS) configuration is fundamental for securing all communications in the Avion social networking platform. This document provides production-ready implementation for comprehensive TLS/SSL configuration across Kubernetes infrastructure, including automated certificate management with cert-manager and Let's Encrypt, secure ingress configuration, and optional mutual TLS (mTLS) for internal service communication.

### Defense-in-Depth TLS Strategy

Our TLS implementation provides multiple layers of security:
1. **Edge Security**: TLS termination at ingress with modern cipher suites
2. **Certificate Automation**: cert-manager with Let's Encrypt for automatic renewal
3. **Internal Communication**: Optional mTLS for service-to-service authentication
4. **Certificate Monitoring**: Automated alerts for expiring certificates
5. **Compliance**: TLS 1.2+ enforcement with secure cipher suites

## Quick Reference

### TLS Components
| Component | Purpose | Scope |
|-----------|---------|-------|
| Ingress NGINX | Edge TLS termination | External traffic |
| cert-manager | Certificate lifecycle management | All certificates |
| Let's Encrypt | Free SSL certificates | Production domains |
| Service Mesh (optional) | mTLS for internal traffic | Service-to-service |
| Certificate Monitor | Expiration tracking | All certificates |

### Supported TLS Versions
| Version | Status | Usage |
|---------|--------|-------|
| TLS 1.3 | Preferred | Default for modern clients |
| TLS 1.2 | Supported | Minimum required version |
| TLS 1.1 | Disabled | Security vulnerabilities |
| TLS 1.0 | Disabled | Security vulnerabilities |
| SSL 3.0 | Disabled | POODLE vulnerability |

## TLS Version and Cipher Suite Configuration

### Recommended Cipher Suites

```yaml
# Modern cipher suite configuration (TLS 1.2+)
cipherSuites:
  # TLS 1.3 cipher suites (automatically included when TLS 1.3 is enabled)
  - TLS_AES_128_GCM_SHA256
  - TLS_AES_256_GCM_SHA384
  - TLS_CHACHA20_POLY1305_SHA256
  
  # TLS 1.2 cipher suites (ECDHE for forward secrecy)
  - ECDHE-ECDSA-AES128-GCM-SHA256
  - ECDHE-RSA-AES128-GCM-SHA256
  - ECDHE-ECDSA-AES256-GCM-SHA384
  - ECDHE-RSA-AES256-GCM-SHA384
  - ECDHE-ECDSA-CHACHA20-POLY1305
  - ECDHE-RSA-CHACHA20-POLY1305
  
  # Fallback cipher suites (for compatibility)
  - ECDHE-ECDSA-AES128-SHA256
  - ECDHE-RSA-AES128-SHA256
```

### Security Parameters

```yaml
# Key exchange parameters
dhParams: 4096  # DH parameter size
ecdhCurve: secp384r1  # ECDH curve

# Session management
sessionTimeout: 86400  # 24 hours
sessionTickets: false  # Disable for forward secrecy
sessionCache: "shared:SSL:10m"  # 10MB shared cache

# OCSP stapling
ocspStapling: true
ocspStaplingVerify: true

# HSTS configuration
hstsMaxAge: 31536000  # 1 year
hstsIncludeSubdomains: true
hstsPreload: true
```

## Kubernetes Ingress NGINX Setup

### 1. Install NGINX Ingress Controller

```yaml
# nginx-ingress-values.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-ingress-values
  namespace: ingress-nginx
data:
  controller:
    # Resource allocation
    resources:
      limits:
        cpu: 1000m
        memory: 1Gi
      requests:
        cpu: 500m
        memory: 512Mi
    
    # Replica configuration for HA
    replicaCount: 3
    
    # Anti-affinity for distribution
    affinity:
      podAntiAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
            - key: app.kubernetes.io/name
              operator: In
              values:
              - ingress-nginx
          topologyKey: kubernetes.io/hostname
    
    # Service configuration
    service:
      type: LoadBalancer
      annotations:
        # Cloud provider specific annotations
        service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
        service.beta.kubernetes.io/aws-load-balancer-backend-protocol: "tcp"
        service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
    
    # ConfigMap for global settings
    config:
      # TLS configuration
      ssl-protocols: "TLSv1.2 TLSv1.3"
      ssl-ciphers: "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305"
      ssl-prefer-server-ciphers: "true"
      ssl-dh-param: "ingress-nginx/dhparam"
      ssl-ecdh-curve: "secp384r1"
      
      # Session configuration
      ssl-session-cache: "shared:SSL:10m"
      ssl-session-cache-size: "10m"
      ssl-session-timeout: "24h"
      ssl-session-tickets: "false"
      
      # OCSP configuration
      ssl-stapling: "true"
      ssl-stapling-verify: "true"
      
      # Security headers
      hsts: "true"
      hsts-max-age: "31536000"
      hsts-include-subdomains: "true"
      hsts-preload: "true"
      
      # Additional security
      force-ssl-redirect: "true"
      ssl-redirect: "true"
      
      # Logging
      log-format-upstream: '$remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent" $request_time $upstream_response_time $pipe $ssl_protocol $ssl_cipher'
      
      # Rate limiting
      limit-rate: "100"
      limit-rate-after: "1000"
      limit-req-status-code: "429"
    
    # Metrics for monitoring
    metrics:
      enabled: true
      serviceMonitor:
        enabled: true
        namespace: monitoring
```

### 2. Deploy NGINX Ingress Controller

```bash
# Add NGINX Ingress Helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX Ingress Controller
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --values nginx-ingress-values.yaml

# Verify installation
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

### 3. Generate DH Parameters

```yaml
# dhparam-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: generate-dhparam
  namespace: ingress-nginx
spec:
  template:
    spec:
      containers:
      - name: dhparam-generator
        image: alpine/openssl:latest
        command:
        - sh
        - -c
        - |
          openssl dhparam -out /dhparam/dhparam.pem 4096
          kubectl create secret generic dhparam \
            --from-file=dhparam.pem=/dhparam/dhparam.pem \
            --namespace ingress-nginx \
            --dry-run=client -o yaml | kubectl apply -f -
        volumeMounts:
        - name: dhparam
          mountPath: /dhparam
      volumes:
      - name: dhparam
        emptyDir: {}
      restartPolicy: OnFailure
      serviceAccountName: dhparam-generator
```

## cert-manager Setup with Let's Encrypt

### 1. Install cert-manager

```yaml
# cert-manager-values.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cert-manager-values
  namespace: cert-manager
data:
  installCRDs: true
  
  global:
    priorityClassName: system-cluster-critical
    leaderElection:
      namespace: cert-manager
  
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 128Mi
  
  webhook:
    resources:
      limits:
        cpu: 100m
        memory: 128Mi
      requests:
        cpu: 10m
        memory: 32Mi
  
  cainjector:
    resources:
      limits:
        cpu: 100m
        memory: 256Mi
      requests:
        cpu: 10m
        memory: 64Mi
  
  prometheus:
    enabled: true
    servicemonitor:
      enabled: true
```

```bash
# Install cert-manager using Helm
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.16.0 \
  --values cert-manager-values.yaml

# Verify installation
kubectl get pods -n cert-manager
kubectl get crd | grep cert-manager
```

### 2. Configure Let's Encrypt Issuers

#### Staging Issuer (for testing)

```yaml
# letsencrypt-staging-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    # Let's Encrypt staging server
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: admin@avion.app
    
    # Private key for ACME account
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    
    # HTTP-01 challenge solver
    solvers:
    - http01:
        ingress:
          class: nginx
          podTemplate:
            metadata:
              labels:
                app: cert-manager-solver
            spec:
              priorityClassName: system-cluster-critical
              tolerations:
              - key: node-role.kubernetes.io/control-plane
                operator: Exists
                effect: NoSchedule
    
    # DNS-01 challenge solver (optional, for wildcard certificates)
    - dns01:
        cloudflare:
          email: admin@avion.app
          apiKeySecretRef:
            name: cloudflare-api-key
            key: api-key
        selector:
          dnsZones:
          - "avion.app"
          - "*.avion.app"
```

#### Production Issuer

```yaml
# letsencrypt-production-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    # Let's Encrypt production server
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@avion.app
    
    # Private key for ACME account
    privateKeySecretRef:
      name: letsencrypt-production-account-key
    
    # HTTP-01 challenge solver
    solvers:
    - http01:
        ingress:
          class: nginx
          podTemplate:
            metadata:
              labels:
                app: cert-manager-solver
            spec:
              priorityClassName: system-cluster-critical
              nodeSelector:
                node-role.kubernetes.io/worker: "true"
    
    # DNS-01 challenge solver for wildcard certificates
    - dns01:
        cloudflare:
          email: admin@avion.app
          apiKeySecretRef:
            name: cloudflare-api-key
            key: api-key
        selector:
          dnsZones:
          - "avion.app"
          - "*.avion.app"
```

### 3. Apply Issuers

```bash
# Create Cloudflare API key secret (if using DNS-01)
kubectl create secret generic cloudflare-api-key \
  --from-literal=api-key=<your-cloudflare-api-key> \
  --namespace cert-manager

# Apply issuers
kubectl apply -f letsencrypt-staging-issuer.yaml
kubectl apply -f letsencrypt-production-issuer.yaml

# Verify issuers
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-staging
kubectl describe clusterissuer letsencrypt-production
```

### 4. Certificate Resources

```yaml
# avion-app-certificate.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: avion-app-tls
  namespace: avion
spec:
  secretName: avion-app-tls-secret
  
  # Certificate details
  dnsNames:
  - avion.app
  - www.avion.app
  - api.avion.app
  - "*.avion.app"  # Wildcard certificate
  
  # Certificate properties
  duration: 2160h  # 90 days
  renewBefore: 720h  # 30 days before expiry
  
  # Key configuration
  privateKey:
    algorithm: ECDSA
    size: 256
    rotationPolicy: Always
  
  # Issuer reference
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer
    group: cert-manager.io
  
  # Additional settings
  usages:
  - digital signature
  - key encipherment
  - server auth
  - client auth
  
  # Certificate subject
  subject:
    organizations:
    - Avion Social Network
    countries:
    - US
    organizationalUnits:
    - Engineering
```

## Ingress Configuration with TLS

### 1. Basic Ingress with TLS

```yaml
# avion-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: avion-ingress
  namespace: avion
  annotations:
    # cert-manager annotations
    cert-manager.io/cluster-issuer: letsencrypt-production
    cert-manager.io/acme-challenge-type: http01
    
    # NGINX annotations
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"
    nginx.ingress.kubernetes.io/ssl-ciphers: "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384"
    nginx.ingress.kubernetes.io/ssl-prefer-server-ciphers: "true"
    
    # Security headers
    nginx.ingress.kubernetes.io/configuration-snippet: |
      more_set_headers "Strict-Transport-Security: max-age=31536000; includeSubDomains; preload";
      more_set_headers "X-Frame-Options: DENY";
      more_set_headers "X-Content-Type-Options: nosniff";
      more_set_headers "X-XSS-Protection: 1; mode=block";
      more_set_headers "Referrer-Policy: strict-origin-when-cross-origin";
    
    # Rate limiting
    nginx.ingress.kubernetes.io/limit-rps: "100"
    nginx.ingress.kubernetes.io/limit-rpm: "1000"
    nginx.ingress.kubernetes.io/limit-connections: "50"
    
    # Proxy settings
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
    
    # WebSocket support
    nginx.ingress.kubernetes.io/websocket-services: "avion-gateway"
    nginx.ingress.kubernetes.io/proxy-http-version: "1.1"
    
spec:
  ingressClassName: nginx
  
  tls:
  - hosts:
    - avion.app
    - www.avion.app
    - api.avion.app
    secretName: avion-app-tls-secret
  
  rules:
  # Main application
  - host: avion.app
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: avion-web
            port:
              number: 80
  
  # WWW redirect
  - host: www.avion.app
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: avion-web
            port:
              number: 80
  
  # API Gateway
  - host: api.avion.app
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: avion-gateway
            port:
              number: 8080
```

### 2. Separate API and Web Ingress

```yaml
# avion-api-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: avion-api-ingress
  namespace: avion
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-production
    nginx.ingress.kubernetes.io/backend-protocol: "GRPC"
    nginx.ingress.kubernetes.io/grpc-backend: "true"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"
    
    # API-specific rate limiting
    nginx.ingress.kubernetes.io/limit-rps: "1000"
    nginx.ingress.kubernetes.io/limit-burst-multiplier: "5"
    
    # CORS configuration
    nginx.ingress.kubernetes.io/cors-allow-origin: "https://avion.app"
    nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, OPTIONS"
    nginx.ingress.kubernetes.io/cors-allow-headers: "Authorization, Content-Type, X-CSRF-Token"
    nginx.ingress.kubernetes.io/cors-expose-headers: "X-Request-ID"
    nginx.ingress.kubernetes.io/cors-allow-credentials: "true"
    
spec:
  ingressClassName: nginx
  
  tls:
  - hosts:
    - api.avion.app
    secretName: avion-api-tls-secret
  
  rules:
  - host: api.avion.app
    http:
      paths:
      # GraphQL endpoint
      - path: /graphql
        pathType: Exact
        backend:
          service:
            name: avion-gateway
            port:
              number: 8080
      
      # gRPC services
      - path: /grpc
        pathType: Prefix
        backend:
          service:
            name: avion-gateway
            port:
              number: 9090
      
      # Health checks
      - path: /health
        pathType: Exact
        backend:
          service:
            name: avion-gateway
            port:
              number: 8080
```

## Internal Service TLS (mTLS)

### 1. Service Mesh Configuration (Istio)

```yaml
# istio-mesh-config.yaml
apiVersion: v1
data:
  mesh: |
    defaultConfig:
      proxyStatsMatcher:
        inclusionRegexps:
        - ".*outlier_detection.*"
        - ".*circuit_breakers.*"
        - ".*_tls.*"
    
    # mTLS configuration
    meshMTLS:
      minProtocolVersion: TLSV1_2
      cipherSuites:
      - ECDHE-ECDSA-AES128-GCM-SHA256
      - ECDHE-RSA-AES128-GCM-SHA256
      - ECDHE-ECDSA-AES256-GCM-SHA384
      - ECDHE-RSA-AES256-GCM-SHA384
    
    # Default mTLS mode
    defaultConfig:
      meshNetworks:
        default:
          endpoints:
          - fromRegistry: Kubernetes
          gateways:
          - service: istio-ingressgateway.istio-system.svc.cluster.local
            port: 443
kind: ConfigMap
metadata:
  name: istio
  namespace: istio-system
```

### 2. PeerAuthentication for mTLS

```yaml
# mtls-peer-authentication.yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: avion
spec:
  mtls:
    mode: STRICT  # Enforce mTLS for all services
---
# Allow permissive mode for specific services during migration
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: gateway-permissive
  namespace: avion
spec:
  selector:
    matchLabels:
      app: avion-gateway
  mtls:
    mode: PERMISSIVE  # Allow both mTLS and plain text
```

### 3. DestinationRule for mTLS

```yaml
# mtls-destination-rule.yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: avion-services-mtls
  namespace: avion
spec:
  host: "*.avion.svc.cluster.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL  # Use Istio's automatic mTLS
      sni: avion.local
      caCertificates: /etc/ssl/certs/ca-certificates.crt
      clientCertificate: /etc/certs/client-cert.pem
      privateKey: /etc/certs/client-key.pem
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http2MaxRequests: 1000
        maxRequestsPerConnection: 2
```

### 4. Manual mTLS Implementation (without Service Mesh)

```go
// tls_config.go
package tls

import (
    "crypto/tls"
    "crypto/x509"
    "fmt"
    "io/ioutil"
    "google.golang.org/grpc/credentials"
)

// TLSConfig holds TLS configuration for services
type TLSConfig struct {
    CertFile   string
    KeyFile    string
    CAFile     string
    ServerName string
    Mutual     bool
}

// LoadServerTLSConfig creates server TLS configuration
func LoadServerTLSConfig(config TLSConfig) (*tls.Config, error) {
    cert, err := tls.LoadX509KeyPair(config.CertFile, config.KeyFile)
    if err != nil {
        return nil, fmt.Errorf("load server certificates: %w", err)
    }
    
    tlsConfig := &tls.Config{
        Certificates: []tls.Certificate{cert},
        MinVersion:   tls.VersionTLS12,
        CipherSuites: []uint16{
            tls.TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,
            tls.TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,
            tls.TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,
            tls.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,
            tls.TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305,
            tls.TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305,
        },
        PreferServerCipherSuites: true,
        CurvePreferences: []tls.CurveID{
            tls.CurveP256,
            tls.X25519,
        },
    }
    
    // Configure mTLS if enabled
    if config.Mutual {
        caCert, err := ioutil.ReadFile(config.CAFile)
        if err != nil {
            return nil, fmt.Errorf("read CA certificate: %w", err)
        }
        
        caCertPool := x509.NewCertPool()
        if !caCertPool.AppendCertsFromPEM(caCert) {
            return nil, fmt.Errorf("parse CA certificate")
        }
        
        tlsConfig.ClientAuth = tls.RequireAndVerifyClientCert
        tlsConfig.ClientCAs = caCertPool
    }
    
    return tlsConfig, nil
}

// LoadClientTLSConfig creates client TLS configuration
func LoadClientTLSConfig(config TLSConfig) (*tls.Config, error) {
    tlsConfig := &tls.Config{
        ServerName: config.ServerName,
        MinVersion: tls.VersionTLS12,
    }
    
    // Load CA certificate
    if config.CAFile != "" {
        caCert, err := ioutil.ReadFile(config.CAFile)
        if err != nil {
            return nil, fmt.Errorf("read CA certificate: %w", err)
        }
        
        caCertPool := x509.NewCertPool()
        if !caCertPool.AppendCertsFromPEM(caCert) {
            return nil, fmt.Errorf("parse CA certificate")
        }
        
        tlsConfig.RootCAs = caCertPool
    }
    
    // Load client certificates for mTLS
    if config.CertFile != "" && config.KeyFile != "" {
        cert, err := tls.LoadX509KeyPair(config.CertFile, config.KeyFile)
        if err != nil {
            return nil, fmt.Errorf("load client certificates: %w", err)
        }
        
        tlsConfig.Certificates = []tls.Certificate{cert}
    }
    
    return tlsConfig, nil
}

// NewGRPCServerCredentials creates gRPC server credentials
func NewGRPCServerCredentials(config TLSConfig) (credentials.TransportCredentials, error) {
    tlsConfig, err := LoadServerTLSConfig(config)
    if err != nil {
        return nil, err
    }
    
    return credentials.NewTLS(tlsConfig), nil
}

// NewGRPCClientCredentials creates gRPC client credentials
func NewGRPCClientCredentials(config TLSConfig) (credentials.TransportCredentials, error) {
    tlsConfig, err := LoadClientTLSConfig(config)
    if err != nil {
        return nil, err
    }
    
    return credentials.NewTLS(tlsConfig), nil
}
```

## Certificate Rotation and Monitoring

### 1. Certificate Monitor Deployment

```yaml
# cert-monitor-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cert-monitor
  namespace: cert-manager
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cert-monitor
  template:
    metadata:
      labels:
        app: cert-monitor
    spec:
      serviceAccountName: cert-monitor
      containers:
      - name: cert-exporter
        image: enix/x509-certificate-exporter:latest
        args:
        - --watch-kube-secrets
        - --secret-namespace=avion
        - --secret-namespace=istio-system
        - --secret-namespace=cert-manager
        - --expose-per-cert-error-metrics
        - --max-cache-duration=24h
        ports:
        - containerPort: 9793
          name: metrics
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
          requests:
            cpu: 10m
            memory: 32Mi
---
apiVersion: v1
kind: Service
metadata:
  name: cert-monitor
  namespace: cert-manager
spec:
  selector:
    app: cert-monitor
  ports:
  - port: 9793
    targetPort: metrics
    name: metrics
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cert-monitor
  namespace: cert-manager
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cert-monitor
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cert-monitor
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cert-monitor
subjects:
- kind: ServiceAccount
  name: cert-monitor
  namespace: cert-manager
```

### 2. Prometheus Monitoring Rules

```yaml
# cert-monitoring-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: certificate-monitoring
  namespace: monitoring
spec:
  groups:
  - name: certificates
    interval: 1m
    rules:
    # Certificate expiration warning (30 days)
    - alert: CertificateExpiringIn30Days
      expr: |
        x509_cert_not_after - time() < 30 * 24 * 60 * 60
      for: 1h
      labels:
        severity: warning
        component: certificates
      annotations:
        summary: "Certificate expiring in less than 30 days"
        description: "Certificate {{ $labels.secret_name }} in namespace {{ $labels.secret_namespace }} expires in {{ $value | humanizeDuration }}"
    
    # Certificate expiration critical (7 days)
    - alert: CertificateExpiringIn7Days
      expr: |
        x509_cert_not_after - time() < 7 * 24 * 60 * 60
      for: 10m
      labels:
        severity: critical
        component: certificates
      annotations:
        summary: "Certificate expiring in less than 7 days"
        description: "Certificate {{ $labels.secret_name }} in namespace {{ $labels.secret_namespace }} expires in {{ $value | humanizeDuration }}"
    
    # Certificate expired
    - alert: CertificateExpired
      expr: |
        x509_cert_not_after - time() < 0
      for: 1m
      labels:
        severity: critical
        component: certificates
      annotations:
        summary: "Certificate has expired"
        description: "Certificate {{ $labels.secret_name }} in namespace {{ $labels.secret_namespace }} has expired"
    
    # cert-manager certificate ready status
    - alert: CertManagerCertificateNotReady
      expr: |
        certmanager_certificate_ready_status{condition="False"} == 1
      for: 10m
      labels:
        severity: warning
        component: cert-manager
      annotations:
        summary: "cert-manager certificate not ready"
        description: "Certificate {{ $labels.name }} in namespace {{ $labels.namespace }} is not ready"
    
    # cert-manager ACME order failures
    - alert: CertManagerACMEOrderFailed
      expr: |
        increase(certmanager_acmeorders_failed_total[1h]) > 0
      for: 10m
      labels:
        severity: warning
        component: cert-manager
      annotations:
        summary: "cert-manager ACME order failed"
        description: "ACME order failures detected: {{ $value }} failures in the last hour"
```

### 3. Grafana Dashboard

```json
{
  "dashboard": {
    "title": "TLS Certificate Monitoring",
    "panels": [
      {
        "title": "Certificate Expiration Timeline",
        "type": "graph",
        "targets": [
          {
            "expr": "(x509_cert_not_after - time()) / 86400",
            "legendFormat": "{{ secret_namespace }}/{{ secret_name }}"
          }
        ],
        "yaxes": [
          {
            "label": "Days until expiration",
            "format": "short"
          }
        ]
      },
      {
        "title": "Certificates by Status",
        "type": "stat",
        "targets": [
          {
            "expr": "count(x509_cert_not_after)",
            "legendFormat": "Total Certificates"
          },
          {
            "expr": "count(x509_cert_not_after - time() < 30 * 86400)",
            "legendFormat": "Expiring Soon"
          },
          {
            "expr": "count(x509_cert_not_after - time() < 0)",
            "legendFormat": "Expired"
          }
        ]
      },
      {
        "title": "cert-manager Certificate Status",
        "type": "table",
        "targets": [
          {
            "expr": "certmanager_certificate_ready_status",
            "format": "table",
            "instant": true
          }
        ]
      },
      {
        "title": "ACME Order Success Rate",
        "type": "gauge",
        "targets": [
          {
            "expr": "1 - (rate(certmanager_acmeorders_failed_total[1h]) / rate(certmanager_acmeorders_total[1h]))"
          }
        ]
      }
    ]
  }
}
```

## Testing TLS Configuration

### 1. TLS Configuration Test Script

```bash
#!/bin/bash
# test-tls-config.sh

DOMAIN="${1:-api.avion.app}"
PORT="${2:-443}"

echo "Testing TLS configuration for $DOMAIN:$PORT"
echo "============================================"

# Test TLS versions
echo -e "\n[TLS Version Support]"
for version in tls1 tls1_1 tls1_2 tls1_3; do
    echo -n "Testing $version: "
    if timeout 2 openssl s_client -connect "$DOMAIN:$PORT" -$version < /dev/null 2>/dev/null | grep -q "Cipher"; then
        echo "✅ Supported"
    else
        echo "❌ Not supported"
    fi
done

# Test cipher suites
echo -e "\n[Cipher Suite Analysis]"
nmap --script ssl-enum-ciphers -p "$PORT" "$DOMAIN" 2>/dev/null | grep -A 20 "ssl-enum-ciphers"

# Test certificate chain
echo -e "\n[Certificate Chain]"
openssl s_client -connect "$DOMAIN:$PORT" -showcerts < /dev/null 2>/dev/null | \
    awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/{print}' | \
    while read -r line; do
        echo "$line"
        if [[ "$line" == "-----END CERTIFICATE-----" ]]; then
            echo ""
        fi
    done

# Test OCSP stapling
echo -e "\n[OCSP Stapling]"
openssl s_client -connect "$DOMAIN:$PORT" -status < /dev/null 2>/dev/null | grep -A 10 "OCSP Response"

# Test session resumption
echo -e "\n[Session Resumption]"
(echo | openssl s_client -connect "$DOMAIN:$PORT" -sess_out session.pem) 2>/dev/null > /dev/null
if openssl s_client -connect "$DOMAIN:$PORT" -sess_in session.pem < /dev/null 2>/dev/null | grep -q "Reused"; then
    echo "✅ Session resumption supported"
else
    echo "❌ Session resumption not supported"
fi
rm -f session.pem

# Test with SSLyze
echo -e "\n[Comprehensive TLS Test with SSLyze]"
if command -v sslyze &> /dev/null; then
    sslyze --regular "$DOMAIN:$PORT"
else
    echo "SSLyze not installed. Install with: pip install sslyze"
fi
```

### 2. Kubernetes TLS Verification

```bash
#!/bin/bash
# verify-k8s-tls.sh

echo "Verifying Kubernetes TLS Configuration"
echo "======================================"

# Check Ingress TLS configuration
echo -e "\n[Ingress TLS Configuration]"
kubectl get ingress -n avion -o json | jq '.items[] | {name: .metadata.name, tls: .spec.tls}'

# Check certificates
echo -e "\n[Certificates Status]"
kubectl get certificate -A

# Check cert-manager issuers
echo -e "\n[cert-manager Issuers]"
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-production | grep -A 5 "Status:"

# Check certificate secrets
echo -e "\n[TLS Secrets]"
for secret in $(kubectl get secrets -n avion -o json | jq -r '.items[] | select(.type=="kubernetes.io/tls") | .metadata.name'); do
    echo "Secret: $secret"
    kubectl get secret "$secret" -n avion -o json | jq -r '.data."tls.crt"' | base64 -d | openssl x509 -noout -text | grep -E "Subject:|Not After"
    echo ""
done

# Test internal service TLS (if using Istio)
if kubectl get namespace istio-system &>/dev/null; then
    echo -e "\n[Istio mTLS Status]"
    istioctl authn tls-check $(kubectl get pod -n avion -l app=avion-gateway -o jsonpath='{.items[0].metadata.name}') -n avion
fi

# Check NGINX Ingress SSL configuration
echo -e "\n[NGINX Ingress SSL Configuration]"
kubectl get configmap nginx-configuration -n ingress-nginx -o yaml | grep -E "ssl-|hsts"
```

### 3. Performance Testing

```bash
#!/bin/bash
# tls-performance-test.sh

DOMAIN="${1:-api.avion.app}"
CONNECTIONS="${2:-1000}"
DURATION="${3:-30}"

echo "TLS Performance Testing for $DOMAIN"
echo "===================================="

# Test handshake performance
echo -e "\n[TLS Handshake Performance]"
for i in {1..10}; do
    time=$(openssl s_time -connect "$DOMAIN:443" -time 1 2>&1 | grep "connections" | awk '{print $1/$3*1000}')
    echo "Handshake $i: ${time}ms"
done

# Load test with TLS
echo -e "\n[Load Testing with TLS]"
if command -v ab &> /dev/null; then
    ab -n "$CONNECTIONS" -c 10 -k "https://$DOMAIN/"
else
    echo "Apache Bench not installed"
fi

# Test with wrk for more detailed metrics
echo -e "\n[Advanced Load Testing with wrk]"
if command -v wrk &> /dev/null; then
    wrk -t4 -c100 -d"${DURATION}s" --latency "https://$DOMAIN/"
else
    echo "wrk not installed. Install with: brew install wrk (macOS) or apt-get install wrk (Linux)"
fi
```

## Security Best Practices

### TLS Configuration Checklist

- [ ] **TLS Version**: Minimum TLS 1.2, prefer TLS 1.3
- [ ] **Cipher Suites**: Use only strong cipher suites with forward secrecy
- [ ] **Certificate Key**: Minimum 2048-bit RSA or 256-bit ECDSA
- [ ] **HSTS**: Enabled with minimum 1-year max-age
- [ ] **Certificate Validation**: Proper chain validation and OCSP stapling
- [ ] **Session Management**: Secure session tickets or disabled
- [ ] **DH Parameters**: Minimum 2048-bit, prefer 4096-bit
- [ ] **Certificate Transparency**: SCT included in certificates
- [ ] **CAA Records**: DNS CAA records configured
- [ ] **Monitoring**: Certificate expiration alerts configured

### DNS CAA Record Configuration

```bash
# Configure CAA records for Let's Encrypt
avion.app.              IN CAA 0 issue "letsencrypt.org"
avion.app.              IN CAA 0 issuewild "letsencrypt.org"
avion.app.              IN CAA 0 iodef "mailto:security@avion.app"
```

### Security Headers for TLS

```yaml
# Additional security headers for TLS endpoints
annotations:
  nginx.ingress.kubernetes.io/configuration-snippet: |
    # HSTS with preload
    more_set_headers "Strict-Transport-Security: max-age=31536000; includeSubDomains; preload";
    
    # Certificate Transparency
    more_set_headers "Expect-CT: max-age=86400, enforce";
    
    # Public Key Pinning (use with caution)
    # more_set_headers "Public-Key-Pins: pin-sha256=\"base64+primary==\"; pin-sha256=\"base64+backup==\"; max-age=2592000";
```

## Troubleshooting Guide

### Common Issues and Solutions

#### Issue 1: Certificate Not Renewing

**Symptoms:**
- Certificate approaching expiration
- cert-manager not creating new certificate
- ACME challenges failing

**Solutions:**
```bash
# Check cert-manager logs
kubectl logs -n cert-manager deploy/cert-manager

# Check certificate status
kubectl describe certificate avion-app-tls -n avion

# Check ACME order status
kubectl get order -n avion
kubectl describe order <order-name> -n avion

# Force certificate renewal
kubectl delete secret avion-app-tls-secret -n avion
kubectl delete certificate avion-app-tls -n avion
kubectl apply -f avion-app-certificate.yaml
```

#### Issue 2: TLS Handshake Failures

**Symptoms:**
- SSL handshake errors
- Connection timeouts
- Cipher suite mismatches

**Diagnostics:**
```bash
# Test specific cipher suite
openssl s_client -connect api.avion.app:443 -cipher ECDHE-RSA-AES128-GCM-SHA256

# Check supported ciphers
nmap --script ssl-enum-ciphers -p 443 api.avion.app

# Verify certificate chain
openssl s_client -connect api.avion.app:443 -showcerts

# Test with specific TLS version
openssl s_client -connect api.avion.app:443 -tls1_2
```

#### Issue 3: mTLS Authentication Failures

**Symptoms:**
- Service-to-service communication failures
- 403 Forbidden errors
- Certificate validation errors

**Solutions:**
```bash
# Check Istio mTLS configuration
istioctl proxy-config secret <pod-name> -n avion

# Verify PeerAuthentication
kubectl get peerauthentication -n avion
kubectl describe peerauthentication default -n avion

# Test mTLS connection
kubectl exec <client-pod> -n avion -- \
  openssl s_client -connect <service>:443 \
  -cert /etc/certs/client-cert.pem \
  -key /etc/certs/client-key.pem \
  -CAfile /etc/certs/ca-cert.pem
```

## Migration Strategy

### Phase 1: HTTP to HTTPS Migration

```yaml
# Step 1: Deploy with HTTP and HTTPS support
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: avion-migration-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"  # Allow HTTP initially
spec:
  rules:
  - host: avion.app
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: avion-web
            port:
              number: 80
```

### Phase 2: Enable HTTPS Redirect

```yaml
# Step 2: Force HTTPS after testing
metadata:
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
```

### Phase 3: Enable HSTS

```yaml
# Step 3: Add HSTS headers gradually
metadata:
  annotations:
    nginx.ingress.kubernetes.io/configuration-snippet: |
      # Start with short duration
      more_set_headers "Strict-Transport-Security: max-age=300";
      
      # Gradually increase to 1 year
      # more_set_headers "Strict-Transport-Security: max-age=31536000; includeSubDomains; preload";
```

## Summary

This comprehensive TLS configuration guide for the Avion platform provides:

1. **Modern TLS Configuration**: TLS 1.2+ with secure cipher suites
2. **Automated Certificate Management**: cert-manager with Let's Encrypt
3. **Kubernetes Integration**: NGINX Ingress with proper TLS termination
4. **Internal Security**: Optional mTLS for service-to-service communication
5. **Monitoring and Alerting**: Certificate expiration tracking and alerts
6. **Testing Tools**: Comprehensive verification scripts
7. **Security Best Practices**: HSTS, OCSP stapling, session management
8. **Troubleshooting Guide**: Common issues and solutions

Regular security audits should verify that TLS configurations remain secure and properly configured. Monitor certificate expiration and renewal processes to ensure continuous availability of services.