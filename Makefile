# HOTOSM Development Environment
# Orchestrates Portal, Drone-TM, and shared services

.PHONY: help setup setup-https install dev dev-umap dev-export-tool stop restart logs health auth-libs link-auth-libs unlink-auth-libs clean load-dump setup-test-users deploy-status

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
	@echo "  make dev-oam        - Start OpenAerialMap only"
	@echo "  make dev-umap       - Start uMap only"
	@echo "  make dev-chatmap    - Start ChatMap only"
	@echo "  make dev-export-tool - Start Export Tool only"
	@echo ""
	@echo "Management:"
	@echo "  make stop           - Stop all services"
	@echo "  make restart        - Restart all services"
	@echo "  make logs           - Show all logs"
	@echo "  make logs-follow    - Follow all logs"
	@echo "  make ps             - Show running services"
	@echo "  make health         - Check service health"
	@echo ""
	@echo "Auth-libs Development:"
	@echo "  make link-auth-libs   - Link local auth-libs for development"
	@echo "  make unlink-auth-libs - Unlink and use npm versions"
	@echo ""
	@echo "Maintenance:"
	@echo "  make auth-libs      - Update auth-libs in all projects"
	@echo "  make clean          - Stop and remove all containers/volumes"
	@echo "  make update         - Git pull all repos"
	@echo "  make deploy-status  - Show CI/CD deploy status for all apps"
	@echo ""
	@echo "Database:"
	@echo "  make load-dump APP=<app> URL=<url> - Load database dump"
	@echo "    Apps: portal, dronetm, fair, oam, hanko"
	@echo "  make setup-test-users [APP=<app>]  - Setup test users for Hanko SSO"
	@echo "    Run after load-dump to assign users with data to test team"
	@echo ""
	@echo "URLs (after make dev):"
	@echo "  Portal:          https://portal.hotosm.test"
	@echo "  Login:           https://login.hotosm.test"
	@echo "  Drone-TM:        https://dronetm.hotosm.test"
	@echo "  fAIr:            https://fair.hotosm.test"
	@echo "  OpenAerialMap:   https://openaerialmap.hotosm.test"
	@echo "  uMap:            https://umap.hotosm.test"
	@echo "  ChatMap:         https://chatmap.hotosm.test"
	@echo "  Export Tool:     https://export-tool.hotosm.test"
	@echo "  MinIO Console:   https://minio.hotosm.test"
	@echo "  Traefik:         https://traefik.hotosm.test"
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
	@cd ../drone-tm/src/backend && uv sync || echo "   ⚠ GDAL no disponible localmente (OK - corre en Docker)"
	@echo ""
	@echo "→ uMap backend..."
	@cd ../umap/app && uv sync
	@echo ""
	@echo "→ OpenAerialMap frontend..."
	@cd ../openaerialmap/frontend && pnpm install
	@echo ""
	@echo "→ OpenAerialMap backend..."
	@cd ../openaerialmap/backend/stac-api && uv sync --python 3.13
	@echo ""
	@echo "→ fAIr frontend..."
	@cd ../fAIr/frontend && pnpm install
	@echo ""
	@echo "→ fAIr backend..."
	@cd ../fAIr/backend && uv sync
	@echo ""
	@echo "→ Export Tool backend..."
	@cd ../osm-export-tool && pip install -r requirements.txt 2>/dev/null || echo "   ⚠ Some deps require GDAL (OK - runs in Docker)"
	@echo ""
	@echo "→ Export Tool frontend..."
	@cd ../osm-export-tool/ui && yarn install
	@echo ""
	@if [ -d "../chatmap/chatmap-ui" ]; then \
		echo "→ ChatMap frontend..."; \
		cd ../chatmap/chatmap-ui && yarn install; \
	fi
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
	@echo "  Portal:          https://portal.hotosm.test"
	@echo "  Login:           https://login.hotosm.test"
	@echo "  Drone-TM:        https://dronetm.hotosm.test"
	@echo "  fAIr:            https://fair.hotosm.test"
	@echo "  OpenAerialMap:   https://openaerialmap.hotosm.test"
	@echo "  uMap:            https://umap.hotosm.test"
	@echo "  ChatMap:         https://chatmap.hotosm.test"
	@echo "  Export Tool:     https://export-tool.hotosm.test"
	@echo "  MinIO Console:   https://minio.hotosm.test"
	@echo "  Traefik:         https://traefik.hotosm.test"
	@echo ""
	@echo "Useful commands:"
	@echo "  make logs-follow - Follow logs (live)"
	@echo "  make logs        - View all logs"
	@echo "  make ps          - Show running services"
	@echo "  make stop        - Stop all services"
	@echo ""

dev-portal:
	@echo "Starting Portal services..."
	docker compose up portal-frontend portal-backend portal-db hanko hanko-db mailhog traefik --build

dev-login:
	@echo "Starting Login services..."
	@if [ -d "../login/frontend" ] && [ -d "../login/backend" ]; then \
		docker compose --profile login up login-frontend login-backend hanko hanko-db mailhog traefik --build; \
	else \
		echo "Error: login/frontend or login/backend not found"; \
		echo "Create these directories first, then run make install"; \
		exit 1; \
	fi

dev-dronetm:
	@echo "Starting Drone-TM services..."
	docker compose up dronetm-frontend dronetm-backend dronetm-db minio redis nodeodm hanko hanko-db mailhog traefik --build

dev-oam:
	@echo "Starting OpenAerialMap services..."
	docker compose up oam-frontend oam-backend oam-db hanko hanko-db mailhog traefik --build

dev-umap:
	@echo "Starting uMap services..."
	docker compose up umap-app umap-db hanko hanko-db mailhog traefik --build

dev-chatmap:
	@echo "Starting ChatMap services..."
	docker compose up chatmap-frontend hanko hanko-db mailhog traefik --build

dev-export-tool:
	@echo "Starting Export Tool services..."
	docker compose up export-tool-app export-tool-worker export-tool-db export-tool-redis mailhog traefik --build

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
	@curl -f -s https://portal.hotosm.test > /dev/null && echo "  ✓ Frontend" || echo "  ✗ Frontend"
	@curl -f -s https://portal.hotosm.test/api/health > /dev/null && echo "  ✓ Backend API" || echo "  ✗ Backend API"
	@echo ""
	@echo "Drone-TM:"
	@curl -f -s https://dronetm.hotosm.test > /dev/null && echo "  ✓ Frontend" || echo "  ✗ Frontend"
	@curl -f -s https://dronetm.hotosm.test/api/health > /dev/null && echo "  ✓ Backend API" || echo "  ✗ Backend API"
	@echo ""
	@echo "OpenAerialMap:"
	@curl -f -s https://openaerialmap.hotosm.test > /dev/null && echo "  ✓ Frontend" || echo "  ✗ Frontend"
	@curl -f -s https://openaerialmap.hotosm.test/api > /dev/null && echo "  ✓ Backend API" || echo "  ✗ Backend API"
	@echo ""
	@echo "fAIr:"
	@curl -f -s https://fair.hotosm.test > /dev/null && echo "  ✓ Frontend" || echo "  ✗ Frontend"
	@curl -f -s https://fair.hotosm.test/api/v1/ > /dev/null && echo "  ✓ Backend API" || echo "  ✗ Backend API"
	@echo ""
	@echo "uMap:"
	@curl -f -s https://umap.hotosm.test > /dev/null && echo "  ✓ Frontend" || echo "  ✗ Frontend"
	@echo ""
	@echo "ChatMap:"
	@curl -f -s https://chatmap.hotosm.test > /dev/null && echo "  ✓ Frontend" || echo "  ✗ Frontend"
	@echo ""
	@echo "Export Tool:"
	@curl -f -s https://export-tool.hotosm.test > /dev/null && echo "  ✓ App" || echo "  ✗ App"
	@echo ""
	@echo "Shared:"
	@curl -f -s https://login.hotosm.test/.well-known/jwks.json > /dev/null && echo "  ✓ Hanko Auth" || echo "  ✗ Hanko Auth"
	@curl -f -s https://minio.hotosm.test > /dev/null && echo "  ✓ MinIO Console" || echo "  ✗ MinIO Console"
	@curl -f -s https://traefik.hotosm.test > /dev/null && echo "  ✓ Traefik Dashboard" || echo "  ✗ Traefik Dashboard"
	@echo ""

# ==================
# Maintenance
# ==================

auth-libs:
	@echo "════════════════════════════════════════════════"
	@echo "  Updating Auth-libs"
	@echo "════════════════════════════════════════════════"
	@./scripts/update-auth-libs.sh

link-auth-libs:
	@echo "════════════════════════════════════════════════"
	@echo "  Linking local auth-libs for development"
	@echo "════════════════════════════════════════════════"
	@echo ""
	@for container in hotosm-portal-frontend hotosm-login-frontend hotosm-dronetm-frontend hotosm-fair-frontend hotosm-oam-frontend; do \
		echo "  → $$container"; \
		docker exec $$container sh -c "rm -rf /app/node_modules/@hotosm/hanko-auth && ln -s /auth-libs-src /app/node_modules/@hotosm/hanko-auth && rm -rf /app/node_modules/.vite" 2>/dev/null && echo "    ✓ linked" || echo "    (not running)"; \
	done
	@echo ""
	@echo "Restarting containers to load linked version..."
	@docker compose restart portal-frontend login-frontend dronetm-frontend fair-frontend oam-frontend 2>/dev/null || true
	@echo ""
	@echo "Done! Now you can:"
	@echo "  1. Edit code in ../login/auth-libs/web-component/src/"
	@echo "  2. Build: cd ../login/auth-libs/web-component && pnpm build"
	@echo "  3. Refresh browser"

unlink-auth-libs:
	@echo "════════════════════════════════════════════════"
	@echo "  Unlinking auth-libs (restoring npm versions)"
	@echo "════════════════════════════════════════════════"
	@echo ""
	@for container in hotosm-portal-frontend hotosm-login-frontend hotosm-dronetm-frontend hotosm-fair-frontend hotosm-oam-frontend; do \
		echo "  → $$container"; \
		docker exec $$container sh -c "rm -rf /app/node_modules/@hotosm/hanko-auth /app/node_modules/.vite && CI=true pnpm install --prefer-offline" 2>/dev/null && echo "    ✓ restored from lockfile" || echo "    (not running)"; \
	done
	@echo ""
	@echo "Restarting containers to clear Vite memory cache..."
	@docker compose restart portal-frontend login-frontend dronetm-frontend fair-frontend oam-frontend 2>/dev/null || true
	@echo ""
	@echo "Done! npm versions restored and containers restarted."

clean:
	@echo "Cleaning all containers and volumes..."
	docker compose down -v
	@echo "✓ Cleaned"

update:
	@echo "Updating all repositories..."
	@cd ../portal && git pull && echo "  ✓ Portal"
	@cd ../login && git pull && echo "  ✓ Login"
	@cd ../drone-tm && git pull && echo "  ✓ Drone-TM"
	@cd ../fAIr && git pull && echo "  ✓ fAIr"
	@cd ../openaerialmap && git pull && echo "  ✓ OpenAerialMap"
	@cd ../umap && git pull && echo "  ✓ uMap"
	@cd ../chatmap && git pull && echo "  ✓ ChatMap"
	@cd ../osm-export-tool && git pull && echo "  ✓ Export Tool"
	@cd ../auth-libs && git pull && echo "  ✓ Auth-libs"
	@echo ""
	@echo "✓ Updated. Run 'make install' if dependencies changed."

deploy-status:
	@echo "════════════════════════════════════════════════"
	@echo "  Deploy Status (Latest CI/CD Runs)"
	@echo "════════════════════════════════════════════════"
	@echo ""
	@./scripts/deploy-status.sh

# ==================
# Database
# ==================

load-dump:
	@if [ -z "$(APP)" ] || [ -z "$(URL)" ]; then \
		echo "Usage: make load-dump APP=<app> URL=<dump_url_or_path>"; \
		echo ""; \
		echo "Apps: portal, dronetm, fair, oam, umap, hanko"; \
		echo ""; \
		echo "Examples:"; \
		echo "  make load-dump APP=dronetm URL=https://example.com/dtm_dump.sql"; \
		echo "  make load-dump APP=fair URL=/path/to/local/dump.sql.gz"; \
		exit 1; \
	fi
	@./scripts/load-dump.sh $(APP) $(URL)

setup-test-users:
	@./scripts/setup-test-users.sh $(or $(APP),all)
