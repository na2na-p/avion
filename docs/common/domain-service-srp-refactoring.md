# Domain Service Single Responsibility Principle (SRP) Refactoring Guide

## Overview

This document outlines the refactoring approach for domain services across the Avion microservices architecture to ensure strict adherence to the Single Responsibility Principle (SRP). The refactoring addresses the issue where some domain services were handling multiple concerns, violating SRP and making the code harder to maintain and test.

## Problem Statement

Several domain services in the Avion architecture were found to be handling multiple responsibilities:

### Original Issues

1. **avion-user**: `UserValidationDomainService` was handling:
   - Username validation
   - Username availability checks
   - Email validation
   - Email availability checks
   - Profile content validation
   - Reputation score calculation

2. **avion-media**: Similar issues with services handling multiple validation concerns in a single interface

## Solution: Domain Service Decomposition

The solution involves decomposing large domain services into smaller, focused services that each handle a single responsibility.

### Design Principles

1. **Single Responsibility**: Each service handles exactly one concern
2. **High Cohesion**: All methods in a service are closely related
3. **Clear Naming**: Service names explicitly describe their responsibility
4. **Interface Segregation**: Clients only depend on the methods they need
5. **Testability**: Smaller services are easier to test in isolation

## Refactoring Examples

### avion-user Service Decomposition

#### Before (Violating SRP)
```go
type UserValidationDomainService interface {
    ValidateUsername(username Username) error
    IsUsernameAvailable(username Username) (bool, error)
    ValidateEmail(email Email) error
    IsEmailAvailable(email Email) (bool, error)
    ValidateProfileContent(profile Profile) error
    CalculateReputationScore(user User) ReputationScore
}
```

#### After (Following SRP)

**1. UsernameValidationService**
```go
type UsernameValidationService interface {
    ValidateUsername(username Username) error
    IsUsernameAvailable(username Username, excludeUserID *UserID) (bool, error)
}
```
Responsibility: All username-related validation logic

**2. EmailValidationService**
```go
type EmailValidationService interface {
    ValidateEmail(email Email) error
    IsEmailAvailable(email Email, excludeUserID *UserID) (bool, error)
    IsDomainAllowed(email Email) (bool, error)
}
```
Responsibility: All email-related validation logic

**3. ProfileValidationService**
```go
type ProfileValidationService interface {
    ValidateProfileContent(profile Profile) error
    DetectInappropriateContent(content string) (bool, error)
    ValidateDisplayName(displayName DisplayName) error
    ValidateBio(bio Bio) error
    ValidateProfileLinks(links []ProfileLink) error
}
```
Responsibility: All profile content validation logic

**4. ReputationCalculationService**
```go
type ReputationCalculationService interface {
    CalculateReputationScore(user User, activities UserActivities) ReputationScore
    CalculateActivityScore(activities UserActivities) float64
    CalculateEngagementScore(engagement UserEngagement) float64
    CalculateTrustScore(trustFactors TrustFactors) float64
}
```
Responsibility: All reputation calculation logic

### avion-media Service Decomposition

**1. MediaFormatValidationService**
```go
type MediaFormatValidationService interface {
    ValidateMediaFormat(mediaType MediaType, mimeType MimeType) error
    ValidateFileExtension(filename string, mimeType MimeType) error
    GetSupportedFormats(mediaType MediaType) []string
    IsMimeTypeSupported(mimeType MimeType) bool
}
```
Responsibility: Media format and MIME type validation

**2. MediaSizeValidationService**
```go
type MediaSizeValidationService interface {
    ValidateFileSize(size FileSize, mediaType MediaType) error
    ValidateImageDimensions(width, height int, mediaType MediaType) error
    ValidateVideoDuration(duration Duration, mediaType MediaType) error
    ValidateAudioDuration(duration Duration) error
    GetMaxFileSize(mediaType MediaType) FileSize
    GetMaxDimensions(mediaType MediaType) (width, height int)
}
```
Responsibility: Media size and dimension constraints

**3. MediaSecurityValidationService**
```go
type MediaSecurityValidationService interface {
    ValidateFileSignature(fileHeader []byte, mimeType MimeType) error
    ValidateContentHash(content []byte, expectedHash ContentHash) error
    ScanForMaliciousContent(content []byte, mediaType MediaType) error
    ValidateURL(url string) error
    GenerateContentHash(content []byte) ContentHash
}
```
Responsibility: Security-related media validation

**4. ThumbnailGenerationService**
```go
type ThumbnailGenerationService interface {
    DetermineThumbnailSizes(mediaType MediaType, originalDimensions Dimensions) []ThumbnailSpec
    ValidateThumbnailRequest(media Media, spec ThumbnailSpec) error
    CalculateThumbnailDimensions(original Dimensions, targetSize ThumbnailSize) Dimensions
    GenerateThumbnailFilename(originalFilename string, size ThumbnailSize) string
    ShouldRegenerateThumbnail(existing Thumbnail, newSpec ThumbnailSpec) bool
}
```
Responsibility: Thumbnail generation policies and rules

## Benefits of This Approach

### 1. Improved Maintainability
- Each service is focused on a single concern
- Changes to one validation type don't affect others
- Easier to locate and fix bugs

### 2. Enhanced Testability
- Smaller interfaces are easier to mock
- Tests are more focused and easier to write
- Better test coverage with isolated unit tests

### 3. Better Reusability
- Services can be composed as needed
- Clients only depend on what they use
- Services can be reused across different use cases

### 4. Clearer Dependencies
- Each use case declares exactly which services it needs
- Dependency injection is more explicit
- Easier to understand system architecture

### 5. Parallel Development
- Different team members can work on different services
- Reduced merge conflicts
- Clear ownership boundaries

## Implementation Guidelines

### 1. Service Naming Convention
```
[Domain]ValidationService     // For validation services
[Domain]CalculationService    // For calculation services
[Domain]GenerationService     // For generation services
[Domain]PolicyService         // For business policy services
```

### 2. Service Composition in Use Cases
```go
type CreateUserCommandUseCase struct {
    userRepository           UserRepository
    usernameValidation      UsernameValidationService
    emailValidation         EmailValidationService
    profileValidation       ProfileValidationService
    eventPublisher          DomainEventPublisher
}
```

### 3. Dependency Injection
```go
func NewCreateUserCommandUseCase(
    repo UserRepository,
    usernameVal UsernameValidationService,
    emailVal EmailValidationService,
    profileVal ProfileValidationService,
    publisher DomainEventPublisher,
) *CreateUserCommandUseCase {
    return &CreateUserCommandUseCase{
        userRepository:     repo,
        usernameValidation: usernameVal,
        emailValidation:    emailVal,
        profileValidation:  profileVal,
        eventPublisher:     publisher,
    }
}
```

### 4. Testing Strategy
```go
func TestUsernameValidation(t *testing.T) {
    // Test only username validation logic
    mockRepo := mock.NewMockUserRepository(ctrl)
    service := NewUsernameValidationService(mockRepo)
    
    // Table-driven tests for username validation
    testCases := []struct {
        name     string
        username string
        wantErr  bool
    }{
        // Test cases focused only on username validation
    }
}
```

## Migration Strategy

### Phase 1: Create New Services
1. Implement new focused domain services
2. Keep existing services temporarily for backward compatibility
3. Write comprehensive tests for new services

### Phase 2: Update Use Cases
1. Refactor use cases to use new services
2. Update dependency injection
3. Ensure all tests pass

### Phase 3: Remove Old Services
1. Mark old services as deprecated
2. Remove old services after migration complete
3. Update documentation

## Validation Checklist

- [ ] Each service has a single, clear responsibility
- [ ] Service name accurately describes its purpose
- [ ] All methods in a service are cohesive
- [ ] No service has more than 5-7 methods
- [ ] Services are independently testable
- [ ] Dependencies are explicitly declared
- [ ] No circular dependencies between services
- [ ] Clear separation between validation, calculation, and policy logic

## Common Pitfalls to Avoid

1. **God Services**: Services that try to do everything
2. **Leaky Abstractions**: Services that expose implementation details
3. **Circular Dependencies**: Services depending on each other
4. **Mixed Concerns**: Combining validation with business logic
5. **Over-Engineering**: Creating too many tiny services

## Conclusion

By refactoring domain services to follow SRP, the Avion architecture becomes more maintainable, testable, and scalable. Each service has a clear responsibility, making the codebase easier to understand and modify. This approach aligns with Domain-Driven Design principles and supports the long-term evolution of the system.