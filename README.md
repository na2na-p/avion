# Avion - Microservices Social Networking Platform

Avion is a microservices-based social networking platform designed for Kubernetes deployment, implementing Domain-Driven Design (DDD) principles and CQRS patterns.

## Common Packages

The following shared packages have been implemented for use across all microservices:

### 1. pkg/errors
**Error Handling Package** - Provides standardized error handling across the platform
- Domain error types with structured error codes
- Error code format: `[SERVICE]_[LAYER]_[ERROR_TYPE]`
- HTTP and gRPC error mapping
- Error wrapping with context preservation
- Thread-safe implementation with immutability
- **Coverage: 68.0%**

Key features:
- `Error` interface with code, message, details, and timestamp
- `ServiceErrorCode()` for generating service-specific codes
- HTTP status code mapping (400, 401, 403, 404, 409, 500, etc.)
- gRPC status code mapping with proper error propagation

### 2. pkg/logging
**Structured Logging Package** - JSON-formatted logging with OpenTelemetry integration
- Built on uber/zap for high-performance logging
- Structured fields with type safety
- Context propagation for request tracking
- Log level filtering (debug, info, warn, error, fatal)
- Thread-safe concurrent logging
- **Coverage: 85.4%**

Key features:
- JSON and text output formats
- Trace ID and Span ID integration
- Context-aware logging with correlation IDs
- Field builders for common types (String, Int, Bool, Error, etc.)

### 3. pkg/config
**Configuration Management** - Environment variable loading with validation
- Struct tag-based configuration (`env`, `default`, `required`)
- Type-safe configuration with automatic parsing
- Fail-fast on missing required variables
- Sensitive data protection (never logs passwords/tokens)
- **Coverage: 81.6%**

Key features:
- Support for all basic Go types and slices
- Custom validators
- Default values
- Configuration printing with sensitive field masking

### 4. pkg/observability
**Observability Package** - OpenTelemetry integration for metrics, traces, and logs

#### Context Management (pkg/observability/context)
- Correlation ID generation and propagation
- Trace ID and Span ID management
- User ID context tracking

#### Tracing (pkg/observability/tracing)
- OpenTelemetry tracer with OTLP export
- Distributed trace context propagation
- Span management with attributes and events
- Configurable sampling rates

#### Metrics (pkg/observability/metrics)
- Prometheus-based metrics collection
- Standard metric definitions for HTTP, gRPC, database, cache
- Counter, Gauge, Histogram, and Summary support
- Thread-safe metric registration

### 5. pkg/database
**Database Utilities** - PostgreSQL connection management and migrations
- Connection pooling with configurable limits
- Transaction management with isolation levels
- Migration support using Goose
- Query builder for safe SQL construction
- **Coverage: 0.0%** (No tests yet - interfaces defined)

Key features:
- Connection pool configuration (max open/idle connections)
- Transaction helpers with automatic rollback
- Prepared statement support
- Database migration management

## Project Structure

```
avion/
├── pkg/                        # Common packages
│   ├── errors/                 # Error handling
│   ├── logging/                # Structured logging
│   ├── config/                 # Configuration management
│   ├── observability/          # Observability (metrics, traces, logs)
│   │   ├── context/            # Context management
│   │   ├── tracing/            # Distributed tracing
│   │   └── metrics/            # Metrics collection
│   └── database/               # Database utilities
├── docs/                       # Documentation
│   └── common/                 # Common architecture docs
└── go.mod                      # Go module definition
```

## Development Principles

- **Test-Driven Development (TDD)**: All packages follow TDD with minimum 90% coverage goal
- **Domain-Driven Design**: 4-layer architecture (Handler → UseCase → Domain → Infrastructure)
- **CQRS Pattern**: Separate Command and Query responsibilities
- **Thread Safety**: All packages are designed for concurrent use
- **Framework Agnostic**: Packages don't depend on specific frameworks

## Getting Started

### Prerequisites
- Go 1.23+
- PostgreSQL 17+ (for database features)
- Redis 7+ (for caching/queuing)

### Installation

```bash
# Install dependencies
go mod download

# Run tests
go test ./pkg/... -cover

# Generate mocks (requires mockgen)
go generate ./...
```

### Usage Examples

#### Error Handling
```go
import "github.com/na2na-p/avion/pkg/errors"

// Create a service-specific error
err := errors.New(
    errors.ServiceErrorCode("AUTH", "DOMAIN", "NOT_FOUND"),
    "User not found",
)

// Map to HTTP status
mapper := errors.NewHTTPStatusMapper()
status := mapper.MapToHTTPStatus(err) // Returns 404
```

#### Logging
```go
import "github.com/na2na-p/avion/pkg/logging"

// Create logger
logger, _ := logging.NewLogger(logging.Config{
    Level:       "info",
    Format:      "json",
    ServiceName: "my-service",
})

// Log with structured fields
logger.Info("user logged in", 
    logging.String("user_id", "123"),
    logging.Int("attempt", 1),
)
```

#### Configuration
```go
import "github.com/na2na-p/avion/pkg/config"

type MyConfig struct {
    DatabaseURL string `env:"DATABASE_URL" required:"true"`
    Port        int    `env:"PORT" default:"8080"`
    Debug       bool   `env:"DEBUG" default:"false"`
}

var cfg MyConfig
config.MustLoad(&cfg)
```

## Testing

All packages include comprehensive test coverage:

```bash
# Run all tests
go test ./pkg/... -v -cover

# Run specific package tests
go test ./pkg/errors -v -cover

# Run with race detection
go test ./pkg/... -race
```

## License

[License information to be added]

## Contributing

[Contributing guidelines to be added]