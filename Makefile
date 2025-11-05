# HOTOSM Development Environment
# Orchestrates Portal, Drone-TM, and shared services

.PHONY: help setup setup-https install dev stop restart logs health auth-libs clean

# Enable BuildKit for Docker builds (required for SSH forwarding)
export DOCKER_BUILDKIT := 1
export COMPOSE_DOCKER_CLI_BUILD := 1

# Default target
help:
	@echo "════════════════════════════════════════════════"
	@echo "  HOTOSM Development Environment"
	@echo "════════════════════════════════════════════════"
	@echo ""
	@echo "Setup (first time):"
	@echo "  make setup          - Check repos and configure hosts"
	@echo "  make setup-https    - Setup HTTPS with mkcert (recommended)"
	@echo "  make install        - Install all dependencies"
	@echo ""
	@echo "Development:"
	@echo "  make dev            - Start all services"
	@echo "  make dev-portal     - Start Portal only"
	@echo "  make dev-login      - Start Login only (requires frontend/backend)"
	@echo "  make dev-dronetm    - Start Drone-TM only"
	@echo ""
	@echo "Management:"
	@echo "  make stop           - Stop all services"
	@echo "  make restart        - Restart all services"
	@echo "  make logs           - Show all logs"
	@echo "  make logs-follow    - Follow all logs"
	@echo "  make ps             - Show running services"
	@echo "  make health         - Check service health"
	@echo ""
	@echo "Maintenance:"
	@echo "  make auth-libs      - Update auth-libs in all projects"
	@echo "  make clean          - Stop and remove all containers/volumes"
	@echo "  make update         - Git pull all repos"
	@echo ""
	@echo "URLs (after make dev):"
	@echo "  Portal:        http://portal.localhost"
	@echo "  Drone-TM:      http://dronetm.localhost"
	@echo "  Hanko Auth:    http://login.localhost"
	@echo "  MinIO Console: http://minio.localhost"
	@echo "  Traefik:       http://traefik.localhost"
	@echo ""

# ==================
# Setup (First Time)
# ==================

setup:
	@echo "════════════════════════════════════════════════"
	@echo "  HOTOSM Development Environment Setup"
	@echo "════════════════════════════════════════════════"
	@echo ""
	@./scripts/setup.sh

setup-https:
	@echo "════════════════════════════════════════════════"
	@echo "  HTTPS Setup with mkcert"
	@echo "════════════════════════════════════════════════"
	@echo ""
	@./scripts/setup-https.sh

install:
	@echo "Installing dependencies..."
	@echo ""
	@echo "→ Auth-libs (installed from GitHub)..."
	@echo "   Using: git+ssh://git@github.com/LawalCoop/hot-auth-libs.git"
	@echo ""
	@echo "→ Portal frontend..."
	@cd ../portal/frontend && pnpm install
	@echo ""
	@echo "→ Portal backend..."
	@cd ../portal/backend && uv sync --all-extras
	@echo ""
	@if [ -d "../login/frontend" ]; then \
		echo "→ Login frontend..."; \
		cd ../login/frontend && pnpm install; \
	fi
	@if [ -d "../login/backend" ]; then \
		echo "→ Login backend..."; \
		cd ../login/backend && uv sync; \
	fi
	@echo ""
	@echo "→ Drone-TM frontend..."
	@cd ../drone-tm/src/frontend && pnpm install
	@echo ""
	@echo "→ Drone-TM backend..."
	@cd ../drone-tm/src/backend && uv sync
	@echo ""
	@echo "✓ All dependencies installed"
	@echo ""
	@echo "Next: make dev"

# ==================
# Development
# ==================

dev:
	@echo "════════════════════════════════════════════════"
	@echo "  Starting HOTOSM Development Environment"
	@echo "════════════════════════════════════════════════"
	@echo ""
	@echo "Building and starting services..."
	@echo ""
	@docker compose up --build -d
	@echo ""
	@echo "════════════════════════════════════════════════"
	@echo "  Services are starting..."
	@echo "════════════════════════════════════════════════"
	@echo ""
	@echo "Waiting for services to be ready..."
	@sleep 10
	@echo ""
	@echo "════════════════════════════════════════════════"
	@echo "  ✓ HOTOSM Development Environment Ready!"
	@echo "════════════════════════════════════════════════"
	@echo ""
	@echo "Available services:"
	@echo ""
	@echo "  Portal:        http://portal.localhost"
	@echo "  Login:         http://login.localhost"
	@echo "  Drone-TM:      http://dronetm.localhost"
	@echo "  MinIO Console: http://minio.localhost"
	@echo "  Traefik:       http://traefik.localhost"
	@echo ""
	@echo "Useful commands:"
	@echo "  make logs-follow - Follow logs (live)"
	@echo "  make logs        - View all logs"
	@echo "  make ps          - Show running services"
	@echo "  make stop        - Stop all services"
	@echo ""

dev-portal:
	@echo "Starting Portal services..."
	docker compose up portal-frontend portal-backend portal-db hanko hanko-db --build

dev-login:
	@echo "Starting Login services..."
	@if [ -d "../login/frontend" ] && [ -d "../login/backend" ]; then \
		docker compose --profile login up login-frontend login-backend hanko hanko-db --build; \
	else \
		echo "Error: login/frontend or login/backend not found"; \
		echo "Create these directories first, then run make install"; \
		exit 1; \
	fi

dev-dronetm:
	@echo "Starting Drone-TM services..."
	docker compose up dronetm-frontend dronetm-backend dronetm-db minio redis nodeodm --build

# ==================
# Management
# ==================

stop:
	@echo "Stopping all services..."
	docker compose down

restart: stop dev

logs:
	docker compose logs

logs-follow:
	docker compose logs -f

ps:
	docker compose ps

health:
	@echo "════════════════════════════════════════════════"
	@echo "  Service Health Check"
	@echo "════════════════════════════════════════════════"
	@echo ""
	@echo "Portal:"
	@curl -f -s http://portal.localhost > /dev/null && echo "  ✓ Frontend" || echo "  ✗ Frontend"
	@curl -f -s http://portal.localhost/api/health > /dev/null && echo "  ✓ Backend API" || echo "  ✗ Backend API"
	@echo ""
	@echo "Drone-TM:"
	@curl -f -s http://dronetm.localhost > /dev/null && echo "  ✓ Frontend" || echo "  ✗ Frontend"
	@curl -f -s http://dronetm.localhost/api/health > /dev/null && echo "  ✓ Backend API" || echo "  ✗ Backend API"
	@echo ""
	@echo "Shared:"
	@curl -f -s http://login.localhost/.well-known/jwks.json > /dev/null && echo "  ✓ Hanko Auth" || echo "  ✗ Hanko Auth"
	@curl -f -s http://minio.localhost > /dev/null && echo "  ✓ MinIO Console" || echo "  ✗ MinIO Console"
	@curl -f -s http://traefik.localhost > /dev/null && echo "  ✓ Traefik Dashboard" || echo "  ✗ Traefik Dashboard"
	@echo ""

# ==================
# Maintenance
# ==================

auth-libs:
	@echo "════════════════════════════════════════════════"
	@echo "  Updating Auth-libs"
	@echo "════════════════════════════════════════════════"
	@./scripts/update-auth-libs.sh

clean:
	@echo "Cleaning all containers and volumes..."
	docker compose down -v
	@echo "✓ Cleaned"

update:
	@echo "Updating all repositories..."
	@cd ../portal && git pull && echo "  ✓ Portal"
	@cd ../drone-tm && git pull && echo "  ✓ Drone-TM"
	@cd ../auth-libs && git pull && echo "  ✓ Auth-libs"
	@echo ""
	@echo "✓ Updated. Run 'make install' if dependencies changed."
