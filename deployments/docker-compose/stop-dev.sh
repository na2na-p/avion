#!/bin/bash
# Development environment shutdown script for Docker Compose V2

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
    print_error "Docker is not running."
    exit 1
fi

# Parse command line arguments
REMOVE_VOLUMES=false
REMOVE_IMAGES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--volumes)
            REMOVE_VOLUMES=true
            shift
            ;;
        -i|--images)
            REMOVE_IMAGES=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -v, --volumes    Remove volumes (data will be lost)"
            echo "  -i, --images     Remove images (will need to rebuild)"
            echo "  -h, --help       Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

print_info "Stopping all services..."

# Stop all services (compose.override.yml is automatically loaded)
docker compose down

if [ "$REMOVE_VOLUMES" = true ]; then
    print_warning "Removing volumes (all data will be lost)..."
    docker compose down -v
fi

if [ "$REMOVE_IMAGES" = true ]; then
    print_warning "Removing images..."
    docker compose down --rmi local
fi

print_info "All services stopped."

# Show remaining containers
REMAINING=$(docker compose ps -q)
if [ -n "$REMAINING" ]; then
    print_warning "Some containers are still running:"
    docker compose ps
else
    print_info "No containers are running."
fi