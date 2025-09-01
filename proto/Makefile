# Protocol Buffers operations
.PHONY: gen
gen:
	@echo "Generating proto files..."
	@buf generate

.PHONY: lint
lint:
	@echo "Linting proto files..."
	@buf lint

.PHONY: breaking
breaking:
	@echo "Checking breaking changes..."
	@buf breaking --against '.git#branch=main'

.PHONY: format
format:
	@echo "Formatting proto files..."
	@buf format -w

.PHONY: clean
clean:
	@echo "Cleaning generated files..."
	@rm -rf ../gen/go
	@rm -rf ../services/avion-web/src/gen

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  make gen      - Generate code from proto files"
	@echo "  make lint     - Lint proto files"
	@echo "  make breaking - Check for breaking changes"
	@echo "  make format   - Format proto files"
	@echo "  make clean    - Remove generated files"
	@echo "  make help     - Show this help message"