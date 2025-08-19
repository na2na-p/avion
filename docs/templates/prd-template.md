# PRD: [Service Name]

<!-- Replace [Service Name] with the actual microservice name (e.g., avion-analytics) -->
<!-- Follow the naming convention: avion-[domain] -->

## 概要

<!-- 
Brief 2-3 sentence overview of the microservice and its core functionality.
What does this service do? What is its primary responsibility in the Avion ecosystem?
Example: "Avionにおける[機能名]を提供するマイクロサービスを実装する。[具体的な機能1]、[具体的な機能2]、[具体的な機能3]などの機能を統合し、[システム全体への価値]を実現する。"
-->

## 背景

<!-- 
Detailed background explaining:
- Why this service is needed
- What problems it solves
- How it fits into the broader Avion architecture
- Business context and user needs
- Integration points with other services

Aim for 3-4 paragraphs explaining the motivation and context.
-->

## Scientific Merits

<!-- 
Technical and business benefits of this service. Include specific metrics where possible.
Format as bullet points with bold headers:

* **Performance Benefit**: Specific improvement with metrics
* **Scalability**: How the service scales and handles growth
* **Reliability**: Availability and fault tolerance characteristics  
* **User Experience**: Impact on user satisfaction and engagement
* **Technical Excellence**: Architecture benefits, maintainability
* **Operational Excellence**: Monitoring, deployment, maintenance benefits

Include quantitative targets where possible (e.g., "99.9% uptime", "p50 < 100ms")
-->

## Design Doc

[Design Doc: [Service Name]](./designdoc.md)

## 参考ドキュメント

<!-- 
List relevant external documentation and standards:
* [Avion アーキテクチャ概要](./../common/architecture.md)
* Add any relevant RFCs, specifications, or external documentation
* Include links to related services' documentation
-->

## 製品原則

<!-- 
Core principles that guide this service's design and implementation.
Format as bullet points with principles that are specific to this service's domain.
Examples:
* **Data Integrity**: Ensure data consistency and prevent corruption
* **Performance First**: Optimize for speed without sacrificing reliability
* **Security by Design**: Implement security controls at every layer
* **User Privacy**: Protect user data with minimal collection and transparent usage
* **Developer Experience**: Provide intuitive APIs and clear error messages
-->

## やること/やらないこと

### やること

<!-- 
Detailed list of features and functionalities this service WILL implement.
Organize by functional areas with sub-bullets for specific capabilities.
Be specific about:
- Core business functions
- API endpoints and operations
- Data management responsibilities
- Integration points
- Non-functional requirements (caching, monitoring, etc.)

Example categories:
#### Core [Domain] Operations
* Feature 1 with specific details
* Feature 2 with constraints and limits
* Feature 3 with configuration options

#### Integration & Events
* Event publishing/consuming
* API integrations
* Data synchronization

#### Performance & Reliability
* Caching strategies
* Monitoring and observability
* Error handling and retry logic
-->

### やらないこと

<!-- 
Clear boundaries of what this service will NOT do.
Reference other services that handle these responsibilities.
Format: 
* **Responsibility**: Service that handles this (e.g., avion-user handles user management)
* **Another Responsibility**: Why it's out of scope

This prevents scope creep and clarifies service boundaries.
-->

## 対象ユーザ

<!-- 
Who uses this service? Include:
* Other Avion microservices (specify which ones and how)
* External API consumers (if applicable)
* System administrators and operators
* End users (via API Gateway if applicable)
-->

## ドメインモデル (DDD戦術的パターン)

### Aggregates (集約)

<!-- 
Define 3-6 core aggregates that represent the main business concepts.
For each aggregate, include:
-->

#### [Aggregate Name] Aggregate
**責務**: [Brief description of the aggregate's responsibility and what it manages]
- **集約ルート**: [Root Entity Name]
- **不変条件**:
  <!-- List 5-10 business invariants that must always be true -->
  - [Invariant 1 - specific constraint with validation rule]
  - [Invariant 2 - relationship constraint]
  - [Invariant 3 - data integrity rule]
  - [Invariant 4 - business rule constraint]
  - [Invariant 5 - access control constraint]
- **ドメインロジック**:
  <!-- List 8-12 key domain methods with brief descriptions -->
  - `methodName(parameters)`: [Description of what this method does and when to use it]
  - `validateSomething()`: [Validation logic description]
  - `canPerformAction(context)`: [Authorization/permission check]
  - `processBusinessRule()`: [Core business logic method]
  - `toExternalFormat()`: [Conversion or export method]

<!-- Repeat this pattern for 3-6 aggregates total -->

### Entities (エンティティ)

<!-- 
Define entities that belong to aggregates but have their own identity.
For each entity:
-->

#### [Entity Name]
**所属**: [Parent Aggregate Name] Aggregate
**責務**: [What this entity manages and represents]
- **属性**:
  - [AttributeName] ([Type/Format] - [Description])
  - [AnotherAttribute] ([Constraints])
- **ビジネスルール**:
  - [Business rule 1]
  - [Business rule 2]
  - [Business rule 3]

<!-- Repeat for 5-10 entities total -->

### Value Objects (値オブジェクト)

<!-- 
Group value objects by category for better organization:
-->

**識別子関連**
- **[EntityID]**: [Description of ID format and generation strategy]
- **[AnotherID]**: [Format description, e.g., Snowflake ID, UUID v4]

**[Domain] 属性**
- **[ValueObject]**: [Description and constraints]
  - [Specific constraint 1]
  - [Specific constraint 2]
  - [Format or validation rule]

**時刻・数値**
- **CreatedAt**: 作成日時（UTC、ミリ秒精度）
- **UpdatedAt**: 更新日時（UTC、ミリ秒精度）
- **[DomainSpecificTime]**: [Description with precision and timezone]

<!-- Add more categories as needed for your domain -->

### Domain Services

<!-- 
Define 3-5 domain services that encapsulate complex business logic:
-->

#### [ServiceName]
**責務**: [What this service is responsible for coordinating]
- **メソッド**:
  - `methodName(parameters)`: [Description of complex business logic]
  - `anotherMethod(parameters)`: [Description of coordination logic]
  - `validateComplexRule(context)`: [Multi-aggregate validation logic]

<!-- Repeat for other domain services -->

## ユースケース

<!-- 
Define 8-15 detailed use cases covering the main user journeys.
For each use case, include:
- Step-by-step process flow
- Error conditions and handling
- UI mockup references
- Integration points with other services
-->

### [Use Case Name]

1. [User/System action that initiates the flow]
2. [System validation and processing step]
3. [Business logic execution with specific service calls]
4. [Data persistence and consistency measures]
5. [Event publishing for other services]
6. [Response generation and return]
7. [Asynchronous processing steps if applicable]

<!-- Include error scenarios and edge cases -->
<!-- Reference UI mockups: (UIモック: [Description]) -->

<!-- Repeat for all major use cases -->

## 機能要求

### ドメインロジック要求

<!-- 
Technical requirements for domain logic implementation:
* **[Business Area]**: Specific requirements and constraints
* **[Another Area]**: Implementation requirements
* **[Data Management]**: Persistence and consistency requirements
* **[Integration]**: Requirements for service communication
-->

### APIエンドポイント要求

<!-- 
Requirements for API design and implementation:
* **[API Category] API**: gRPC/REST API requirements
* **Authentication**: Required authentication and authorization
* **Pagination**: Support requirements and limits
* **Rate Limiting**: Throttling and protection measures
* **Error Handling**: Consistent error response format
-->

### データ要求

<!-- 
Data storage and management requirements:
* **[Data Type]**: Format, constraints, and validation rules
* **[Another Data Type]**: Storage requirements and access patterns
* **Relationships**: How entities relate and reference constraints
* **Archival**: Data retention and cleanup policies
* **Migration**: Schema evolution and backward compatibility
-->

## 技術的要求

### レイテンシ

<!-- 
Performance targets for key operations:
* [Operation 1]: 平均 [target]ms 以下, p99 [target]ms 以下
* [Operation 2]: 平均 [target]ms 以下, p99 [target]ms 以下
* [Batch Operation]: [target] items/second processing rate
* [Complex Operation]: 平均 [target]ms 以下 (with caching)
-->

### 可用性

<!-- 
Availability requirements and implementation approach:
* Target availability percentage (e.g., 99.9%)
* Kubernetes deployment strategy (replicas, rolling updates)
* Fault tolerance mechanisms
* Health check endpoints
* Graceful shutdown procedures
-->

### スケーラビリティ

<!-- 
Scalability requirements and strategies:
* Expected load patterns and growth
* Horizontal scaling approach
* Resource utilization targets
* Bottleneck identification and mitigation
* Performance testing requirements
-->

### セキュリティ

<!-- 
Security requirements and measures:
* **Input Validation**: Sanitization and validation requirements
* **Access Control**: Authentication and authorization measures
* **Data Protection**: Encryption at rest and in transit
* **Audit Logging**: Security event tracking requirements
* **Compliance**: Regulatory and standard compliance needs
-->

### データ整合性

<!-- 
Data consistency and integrity requirements:
* Transactional boundaries and ACID requirements
* Eventual consistency tolerance for distributed operations
* Conflict resolution strategies
* Data validation and constraint enforcement
* Backup and recovery procedures
-->

### その他技術要件

<!-- 
Additional technical requirements:
* **Stateless Design**: State management approach
* **Observability**: Monitoring, tracing, and logging requirements
* **Configuration**: Environment-based configuration management
* **Dependencies**: External service dependencies and SLA requirements
* **Testing**: Unit, integration, and performance testing requirements
-->

## 決まっていないこと

<!-- 
Open questions and future decisions needed:
* [Technical decision that needs research or discussion]
* [Feature scope that requires product input]
* [Integration approach that depends on other services]
* [Performance optimization strategy pending load testing]
* [Security measure pending threat modeling]

Mark resolved items with strikethrough:
* ~~[Previously open question]~~ → [How it was resolved]
-->

---

<!-- Template Metadata (remove this section when creating actual PRDs) -->

## Template Usage Guidelines

**When using this template:**

1. **Replace all placeholder text** in square brackets with service-specific content
2. **Remove example comments** and guidance text in HTML comments
3. **Adapt sections** based on your service's complexity (some services may need more aggregates, others fewer)
4. **Include specific metrics** and quantitative targets where possible
5. **Reference related services** accurately and maintain consistency with existing PRDs
6. **Validate domain model** with domain experts before finalizing
7. **Keep use cases realistic** and testable
8. **Ensure technical requirements** are measurable and achievable

**Section sizing guidelines:**
- **Aggregates**: 3-6 for most services, more for complex domains
- **Entities**: 5-10 depending on domain complexity  
- **Use Cases**: 8-15 covering all major user journeys
- **Value Objects**: Group by category, include all domain-specific types
- **Domain Services**: 3-5 for most services, focus on complex coordination logic

**Quality checklist:**
- [ ] All business invariants are specific and testable
- [ ] Domain logic methods have clear responsibilities
- [ ] Use cases include error handling and edge cases
- [ ] Technical requirements include specific metrics
- [ ] Integration points with other services are clearly defined
- [ ] Security and data protection measures are comprehensive
- [ ] Open questions are tracked and assigned owners