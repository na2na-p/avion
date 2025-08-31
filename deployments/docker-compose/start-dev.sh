#!/bin/bash
# Development environment startup script for Docker Compose V2

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker first."
    exit 1
fi

# Check Docker Compose V2
if ! docker compose version > /dev/null 2>&1; then
    print_error "Docker Compose V2 is not available. Please install Docker Desktop or Docker Compose V2."
    exit 1
fi

print_info "Docker Compose V2 detected: $(docker compose version)"

# Check if .env file exists
if [ ! -f .env ]; then
    print_warning ".env file not found. Copying from .env.example..."
    cp .env.example .env
    print_info ".env file created. Please review and update the configuration if needed."
fi

# Start infrastructure services first
print_info "Starting infrastructure services..."
docker compose up -d postgres redis meilisearch minio

# Wait for PostgreSQL to be ready
print_info "Waiting for PostgreSQL to be ready..."
until docker compose exec -T postgres pg_isready -U ${POSTGRES_USER:-avion} > /dev/null 2>&1; do
    sleep 1
done
print_info "PostgreSQL is ready!"

# Wait for Redis to be ready
print_info "Waiting for Redis to be ready..."
until docker compose exec -T redis redis-cli ping > /dev/null 2>&1; do
    sleep 1
done
print_info "Redis is ready!"

# Start observability services
print_info "Starting observability services..."
docker compose up -d jaeger prometheus grafana

# Start development services with override (compose.override.yml is automatically loaded)
print_info "Starting development services..."
docker compose up -d

# Show running services
print_info "All services started. Current status:"
docker compose ps

# Show service URLs
echo ""
print_info "Service URLs:"
echo "  PostgreSQL:        localhost:5432"
echo "  Redis:             localhost:6379"
echo "  MeiliSearch:       http://localhost:7700"
echo "  MinIO Console:     http://localhost:9001"
echo "  Jaeger UI:         http://localhost:16686"
echo "  Prometheus:        http://localhost:9090"
echo "  Grafana:           http://localhost:3001"
echo "  Gateway (GraphQL): http://localhost:8080"
echo "  Web App:           http://localhost:3000"
echo "  Redis Commander:   http://localhost:8091"

echo ""
print_info "To view logs: docker compose logs -f [service-name]"
print_info "To stop all services: docker compose down"