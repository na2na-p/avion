# Avion アーキテクチャ概要

Avionはマイクロサービスアーキテクチャを採用し、Kubernetes上での運用を前提としています。主要なコンポーネント間の関係を以下に示します。

```mermaid
graph TD
    %% User Interaction
    subgraph "User Interaction"
        User["End User"]
    end

    %% Edge & BFF
    subgraph "Edge & BFF"
        CDN["CDN (Cloudflare/CloudFrontなど)"]
        BFF["avion-bff-web Web BFF"]
        Gateway["avion-gateway API Gateway"]
    end

    %% Backend Services (Kubernetes上のステートレスPod群)
    subgraph "Backend Services (Kubernetes上のステートレスPod群)"
        UserService["avion-user User Service"]
        PostService["avion-post Post Service"]
        TimelineService["avion-timeline Timeline Service"]
        ActivityPubService["avion-activitypub ActivityPub Service"]
        ReactionService["avion-reaction Reaction Service"]
        NotificationService["avion-notification Notification Service"]
        MediaService["avion-media Media Service"]
        SearchService["avion-search Search Service"]
        AuthzService["avion-authz Authorization Service"]
    end

    %% Data Stores & External Systems
    subgraph "Data Stores & External Systems"
        Postgres[("PostgreSQL DB")]
        Redis[("Redis Cache/Queue")]
        S3[("S3互換 Object Storage")]
        MeiliSearch[("MeiliSearch")]
        OtherTerminal["他のActivityPubサーバー (Terminal)"]
    end

    %% Observability (Optional but Recommended)
    subgraph "Observability (Optional but Recommended)"
        Tracing["Trace Collector (Jaeger/Tempo)"]
        Metrics["Metrics Collector (Prometheus)"]
        Logging["Log Aggregator (Loki/EFK)"]
    end

    %% Connections
    User -- HTTPS --> CDN
    CDN -- HTTPS --> BFF

    BFF -- "gRPC/HTTP" --> Gateway

    Gateway -- "gRPC/HTTP" --> UserService
    Gateway -- "gRPC/HTTP" --> PostService
    Gateway -- "gRPC/HTTP" --> TimelineService
    Gateway -- "gRPC/HTTP" --> ActivityPubService
    Gateway -- "gRPC/HTTP" --> ReactionService
    Gateway -- "gRPC/HTTP" --> NotificationService
    Gateway -- "gRPC/HTTP" --> MediaService
    Gateway -- "gRPC/HTTP" --> SearchService
    Gateway -- "Authorize Request" --> AuthzService

    UserService -- CRUD --> Postgres
    UserService -- "Auth Info" --> Redis
    UserService -- "Publishes Events" --> Redis
    UserService -- "Follow Request" --> ActivityPubService

    PostService -- CRUD --> Postgres
    PostService -- "Publishes Events" --> Redis
    PostService -- "Media Info" --> MediaService

    TimelineService -- "Reads Follows" --> UserService
    TimelineService -- "Reads Posts" --> PostService
    TimelineService -- "Reads/Writes Cache" --> Redis
    TimelineService -- "Listens Events" --> Redis
    TimelineService -- "Reads Remote Posts" --> ActivityPubService

    ActivityPubService -- "Reads/Writes Actor/Follow" --> UserService
    ActivityPubService -- "Reads/Writes Remote Data" --> Postgres
    ActivityPubService -- "Reads/Writes Cache/Queue" --> Redis
    ActivityPubService -- "Sends/Receives Activities" --> OtherTerminal
    ActivityPubService -- "Publishes Events" --> Redis
    ActivityPubService -- "Media Cache" --> MediaService

    ReactionService -- CRUD --> Postgres
    ReactionService -- "Reads/Writes Cache" --> Redis
    ReactionService -- "Publishes Events" --> Redis

    NotificationService -- "Reads User Prefs" --> UserService
    NotificationService -- "Reads Events" --> Redis
    NotificationService -- CRUD --> Postgres
    NotificationService -- "Reads/Writes Cache" --> Redis
    NotificationService -- "Sends Web Push" --> User
    NotificationService -- "Sends SSE" --> User

    MediaService -- "Upload/Metadata" --> S3
    MediaService -- "Reads/Writes Cache" --> Redis
    MediaService -- "Publishes Events" --> Redis
    MediaService -- "Serves Media via CDN" --> CDN

    SearchService -- "Reads Events" --> Redis
    SearchService -- "Indexes/Searches" --> MeiliSearch
    SearchService -- "Reads Data" --> PostService
    SearchService -- "Reads Data" --> UserService

    AuthzService -- "Reads Policies/Client Info" --> Postgres
    AuthzService -- "Reads Cache" --> Redis

    %% Observability Connections
    Gateway -- Trace --> Tracing
    Gateway -- Metrics --> Metrics
    Gateway -- Logs --> Logging

    UserService -- Trace --> Tracing
    UserService -- Metrics --> Metrics
    UserService -- Logs --> Logging

    PostService -- Trace --> Tracing
    PostService -- Metrics --> Metrics
    PostService -- Logs --> Logging

    TimelineService -- Trace --> Tracing
    TimelineService -- Metrics --> Metrics
    TimelineService -- Logs --> Logging

    ActivityPubService -- Trace --> Tracing
    ActivityPubService -- Metrics --> Metrics
    ActivityPub
