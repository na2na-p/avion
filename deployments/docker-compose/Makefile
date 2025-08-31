# Makefile for Avion Docker Compose Development Environment

.PHONY: help up down restart logs ps clean build shell db-shell redis-cli test health

# Default target
help: ## Show this help message
	@echo "Avion Docker Compose Management"
	@echo "================================"
	@echo ""
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Basic operations
up: ## Start all services (infrastructure + microservices)
	docker compose up -d
	@echo "Waiting for services to be healthy..."
	@sleep 5
	@make health

up-infra: ## Start only infrastructure services
	docker compose up -d postgres redis meilisearch minio
	@echo "Infrastructure services started"

down: ## Stop all services
	docker compose down

down-infra: ## Stop only infrastructure services
	docker compose stop postgres redis meilisearch minio

restart: ## Restart all services
	@make down
	@make up

restart-service: ## Restart a specific service (usage: make restart-service SERVICE=avion-auth)
	docker compose restart $(SERVICE)

# Logging and monitoring
logs: ## Show logs for all services
	docker compose logs -f

logs-service: ## Show logs for a specific service (usage: make logs-service SERVICE=avion-auth)
	docker compose logs -f $(SERVICE)

ps: ## List all running services
	docker compose ps

health: ## Check health status of all services
	@echo "Checking service health..."
	@docker compose ps | grep -E "(healthy|unhealthy|starting)"
	@echo ""
	@echo "Service URLs:"
	@echo "  Web App:        http://localhost:3000"
	@echo "  GraphQL:        http://localhost:8080"
	@echo "  Grafana:        http://localhost:3001"
	@echo "  Jaeger:         http://localhost:16686"
	@echo "  MeiliSearch:    http://localhost:7700"
	@echo "  MinIO Console:  http://localhost:9001"
	@echo "  Redis Commander: http://localhost:8091"

# Building
build: ## Rebuild all service images
	docker compose build

build-service: ## Rebuild a specific service (usage: make build-service SERVICE=avion-auth)
	docker compose build $(SERVICE)

build-no-cache: ## Rebuild all images without cache
	docker compose build --no-cache

# Database operations
db-shell: ## Access PostgreSQL shell
	docker compose exec postgres psql -U avion -d avion

db-backup: ## Backup PostgreSQL database
	@mkdir -p backups
	docker compose exec postgres pg_dump -U avion avion > backups/avion_backup_$$(date +%Y%m%d_%H%M%S).sql
	@echo "Database backed up to backups/"

db-restore: ## Restore PostgreSQL database (usage: make db-restore FILE=backup.sql)
	docker compose exec -T postgres psql -U avion avion < $(FILE)
	@echo "Database restored from $(FILE)"

db-migrate: ## Run database migrations (example for auth service)
	docker compose exec avion-auth migrate -path /app/migrations -database "postgresql://avion:avion_dev@postgres:5432/avion?sslmode=disable&search_path=auth" up

# Redis operations
redis-cli: ## Access Redis CLI
	docker compose exec redis redis-cli -a ""

redis-flush: ## Flush all Redis data
	docker compose exec redis redis-cli -a "" FLUSHALL
	@echo "Redis data flushed"

# Shell access
shell: ## Access shell of a service (usage: make shell SERVICE=avion-auth)
	docker compose exec $(SERVICE) sh

shell-web: ## Access Next.js container shell
	docker compose exec avion-web sh

# Testing
test: ## Run tests for all services
	@echo "Running tests for all services..."
	@for service in avion-auth avion-user avion-drop avion-timeline avion-gateway; do \
		echo "Testing $$service..."; \
		docker compose exec $$service go test ./... || true; \
	done

test-service: ## Run tests for a specific service (usage: make test-service SERVICE=avion-auth)
	docker compose exec $(SERVICE) go test ./...

# Cleanup
clean: ## Stop all services and remove volumes (WARNING: Deletes all data)
	@echo "WARNING: This will delete all data. Press Ctrl+C to cancel, or Enter to continue."
	@read confirm
	docker compose down -v
	@echo "All services stopped and volumes removed"

prune: ## Remove all unused Docker resources
	docker system prune -a --volumes -f
	@echo "Docker system pruned"

# Environment setup
env-setup: ## Copy .env.example to .env if it doesn't exist
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo ".env file created from .env.example"; \
		echo "Please edit .env with your configuration"; \
	else \
		echo ".env file already exists"; \
	fi

# Development helpers
dev-setup: ## Complete development environment setup
	@make env-setup
	@echo "Starting infrastructure services..."
	@make up-infra
	@sleep 10
	@echo "Starting application services..."
	@make up
	@echo "Development environment is ready!"
	@make health

stop-all: ## Stop all Avion containers
	@docker ps -q --filter "name=avion" | xargs -r docker stop
	@echo "All Avion containers stopped"

remove-all: ## Remove all Avion containers
	@docker ps -aq --filter "name=avion" | xargs -r docker rm -f
	@echo "All Avion containers removed"

# Monitoring
grafana-import: ## Import Grafana dashboards
	@echo "Importing Grafana dashboards..."
	@echo "Access Grafana at http://localhost:3001 (admin/admin)"

prometheus-targets: ## Check Prometheus targets
	@echo "Prometheus targets:"
	@curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .job, instance: .instance, health: .health}'

# Utility
ports: ## Show port mappings
	@echo "Service Port Mappings:"
	@echo "====================="
	@docker compose ps --format "table {{.Service}}\t{{.Ports}}"

validate: ## Validate docker-compose configuration
	docker compose config --quiet
	@echo "Docker Compose configuration is valid"
