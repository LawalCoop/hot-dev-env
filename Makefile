# HOTOSM Development Environment
# Orchestrates Portal, Drone-TM, and shared services

.PHONY: help setup setup-https install dev dev-fair dev-tm dev-umap dev-export-tool dev-raw-data-api dev-field stop restart logs logs-follow ps health auth-libs link-auth-libs unlink-auth-libs link-hotosm-ui unlink-hotosm-ui clean load-dump setup-test-users deploy-status dev-oam-pipeline oam-cluster oam-pipeline-images oam-cluster-destroy

# Enable BuildKit for Docker builds (required for SSH forwarding)
export DOCKER_BUILDKIT := 1
export COMPOSE_DOCKER_CLI_BUILD := 1

# Reusable compose command for the Field-TM project, kept here to avoid repetition
FIELD_TM_COMPOSE := cd ../field-tm && docker compose -f compose.yaml -f $(CURDIR)/docker-compose.field-tm.yml --env-file .env -p field-tm

# OAM with upload processing (Argo on OAM's local Talos cluster)
OAM_PIPELINE_COMPOSE := docker compose -f docker-compose.yml -f docker-compose.oam-pipeline.yml
OAM_SERVICES := oam-frontend oam-backend oam-db oam-stac-browser oam-uploader-api oam-uploader-migrations oam-uploader-db oam-rustfs oam-rustfs-init login-frontend login-backend hanko hanko-db mailhog traefik

# curl does not read the macOS Keychain, so health checks pass mkcert's CA
# explicitly; without mkcert they skip verification.
CURL_CHECK := curl -f -s $(shell f="$$(mkcert -CAROOT 2>/dev/null)/rootCA.pem"; [ -f "$$f" ] && printf -- '--cacert "%s"' "$$f" || printf -- '-k')

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
	@echo "  make dev-oam-pipeline - OpenAerialMap with upload processing"
	@echo "  make dev-fair       - Start fAIr only"
	@echo "  make dev-umap       - Start uMap only"
	@echo "  make dev-chatmap    - Start ChatMap only"
	@echo "  make dev-tm          - Start Tasking Manager only"
	@echo "  make dev-export-tool - Start Export Tool only"
	@echo "  make dev-raw-data-api - Start Raw Data API only"
	@echo "  make dev-field       - Start Field-TM only"
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
	@echo "@hotosm/ui Development:"
	@echo "  make link-hotosm-ui   - Link local @hotosm/ui for development"
	@echo "  make unlink-hotosm-ui - Unlink local @hotosm/ui"
	@echo ""
	@echo "Maintenance:"
	@echo "  make auth-libs      - Update auth-libs in all projects"
	@echo "  make clean          - Stop and remove all containers/volumes"
	@echo "  make update         - Git pull all repos"
	@echo "  make deploy-status  - Show CI/CD deploy status for all apps"
	@echo ""
	@echo "Database:"
	@echo "  make load-dump APP=<app> URL=<url> - Load database dump"
	@echo "    Apps: portal, dronetm, fair, oam, hanko, tm"
	@echo "  make setup-test-users [APP=<app>]  - Setup test users for Hanko SSO"
	@echo "    Run after load-dump to assign users with data to test team"
	@echo ""
	@echo "URLs (after make dev):"
	@echo "  Portal:          https://portal.hotosm.test"
	@echo "  Login:           https://login.hotosm.test"
	@echo "  Drone-TM:        https://dronetm.hotosm.test"
	@echo "  fAIr:            https://fair.hotosm.test"
	@echo "  OpenAerialMap:   https://openaerialmap.hotosm.test"
	@echo "  OAM Uploader:    https://oam-upload.hotosm.test"
	@echo "  OAM Browser:     https://oam-browser.hotosm.test"
	@echo "  uMap:            https://umap.hotosm.test"
	@echo "  ChatMap:         https://chatmap.hotosm.test"
	@echo "  Tasking Manager:     https://tm.hotosm.test"
	@echo "  Export Tool:     https://export-tool.hotosm.test"
	@echo "  Raw Data API:    https://raw-data-api.hotosm.test"
	@echo "  Field-TM:        https://field.hotosm.test"
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
	@echo "→ @hotosm/ui..."
	@cd ../ui && pnpm install
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
	@cd ../osm-export-tool/ui && yarn install --ignore-engines
	@echo ""
	@if [ -d "../chatmap/chatmap-ui" ]; then \
		echo "→ ChatMap frontend..."; \
		cd ../chatmap/chatmap-ui && yarn install --ignore-engines; \
	fi
	@if [ -d "../chatmap/chatmap-api" ]; then \
		echo "→ ChatMap backend..."; \
		cd ../chatmap/chatmap-api && uv sync || echo "   ⚠ Some deps may fail (OK - runs in Docker)"; \
	fi
	@echo ""
	@if [ -d "../tasking-manager/frontend" ]; then \
		echo "→ Tasking Manager frontend..."; \
		cd ../tasking-manager/frontend && yarn install --ignore-engines; \
	fi
	@if [ -d "../tasking-manager" ]; then \
		echo "→ Tasking Manager backend..."; \
		cd ../tasking-manager && uv sync || echo "   ⚠ Some deps require system libraries (OK - runs in Docker)"; \
	fi
	@echo ""
	@if [ -d "../raw-data-api" ]; then \
		echo "→ Raw Data API..."; \
		cd ../raw-data-api && pip install -e . 2>/dev/null || echo "   ⚠ Some deps require GDAL/system libs (OK - runs in Docker)"; \
	fi
	@echo ""
	@if [ -d "../field-tm/src/backend" ]; then \
		echo "→ Field-TM backend..."; \
		cd ../field-tm/src/backend && uv sync || echo "   ⚠ Some deps may fail (OK - runs in Docker)"; \
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
	@./scripts/init-field-tm-env.sh 2>/dev/null || true
	@docker compose up --build -d
	@if [ -d "../field-tm" ]; then \
		echo ""; \
		echo "Starting Field-TM..."; \
		$(FIELD_TM_COMPOSE) up --build -d; \
	fi
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
	@echo "  OAM Uploader:    https://oam-upload.hotosm.test"
	@echo "  OAM Browser:     https://oam-browser.hotosm.test"
	@echo "  uMap:            https://umap.hotosm.test"
	@echo "  ChatMap:         https://chatmap.hotosm.test"
	@echo "  Tasking Mgr:     https://tm.hotosm.test"
	@echo "  Export Tool:     https://export-tool.hotosm.test"
	@echo "  Raw Data API:    https://raw-data-api.hotosm.test"
	@echo "  Field-TM:        https://field.hotosm.test"
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
	docker compose up $(OAM_SERVICES) --build

# Same services, with uploads processed by OAM's real pipeline. Creates (or
# reuses) OAM's local Talos + Argo cluster first; needs `just` and ../openaerialmap.
dev-oam-pipeline: oam-cluster
	@echo "Starting OpenAerialMap services with upload processing..."
	$(OAM_PIPELINE_COMPOSE) up $(OAM_SERVICES) --build

oam-cluster:
	@./scripts/oam-cluster.sh

# Build the pipeline images from ../openaerialmap so workflows run your local
# changes. Without this, the cluster pulls the published images from ghcr.io.
oam-pipeline-images:
	cd ../openaerialmap && just test _build-pipeline-images

# Frees the cluster's memory. Uploads stop being processed until oam-cluster.
oam-cluster-destroy:
	cd ../openaerialmap && PATH="$(CURDIR)/.bin:$$PATH" just k8s cluster-destroy
	@# Emptied, not deleted: a running uploader keeps reading a deleted file.
	@if [ -f .oam-kubeconfig ]; then : > .oam-kubeconfig; fi

dev-fair:
	@echo "Starting fAIr services..."
	docker compose up fair-frontend fair-backend fair-worker fair-db fair-redis hanko hanko-db mailhog traefik --build

dev-umap:
	@echo "Starting uMap services..."
	docker compose up umap-app umap-db hanko hanko-db mailhog traefik --build

dev-chatmap:
	@echo "Starting ChatMap services..."
	docker compose up chatmap-frontend chatmap-backend chatmap-db chatmap-go redis hanko hanko-db mailhog traefik --build

dev-tm:
	@echo "Starting Tasking Manager services..."
	docker compose up tm-frontend tm-backend tm-db tm-migration tm-cron-jobs mailhog traefik --build

dev-export-tool:
	@echo "Starting Export Tool services (with Raw Data API)..."
	docker compose up export-tool-app export-tool-worker export-tool-db export-tool-redis raw-data-api raw-data-api-db raw-data-api-worker redis mailhog traefik --build

dev-raw-data-api:
	@echo "Starting Raw Data API services..."
	docker compose up raw-data-api raw-data-api-db raw-data-api-worker redis traefik --build

dev-field:
	@echo "Starting Field-TM services..."
	@./scripts/init-field-tm-env.sh
	@$(FIELD_TM_COMPOSE) up --build -d

# ==================
# Management
# ==================

stop:
	@echo "Stopping all services..."
	@if [ -d "../field-tm" ]; then \
		$(FIELD_TM_COMPOSE) down 2>/dev/null || true; \
	fi
	docker compose down

restart:
	@echo "Restarting all services..."
	@docker compose restart
	@if [ -d "../field-tm" ]; then \
		$(FIELD_TM_COMPOSE) restart; \
	fi

logs:
	@docker compose logs
	@if [ -d "../field-tm" ]; then \
		echo ""; \
		echo "── Field-TM logs ──"; \
		$(FIELD_TM_COMPOSE) logs; \
	fi

logs-follow:
	@if [ -d "../field-tm" ]; then \
		docker compose logs -f & \
		($(FIELD_TM_COMPOSE) logs -f) & \
		wait; \
	else \
		docker compose logs -f; \
	fi

ps:
	@docker compose ps
	@if [ -d "../field-tm" ]; then \
		echo ""; \
		echo "── Field-TM ──"; \
		$(FIELD_TM_COMPOSE) ps; \
	fi

health:
	@echo "════════════════════════════════════════════════"
	@echo "  Service Health Check"
	@echo "════════════════════════════════════════════════"
	@echo ""
	@echo "Portal:"
	@$(CURL_CHECK) https://portal.hotosm.test > /dev/null && echo "  ✓ Frontend" || echo "  ✗ Frontend"
	@$(CURL_CHECK) https://portal.hotosm.test/api/health > /dev/null && echo "  ✓ Backend API" || echo "  ✗ Backend API"
	@echo ""
	@echo "Drone-TM:"
	@$(CURL_CHECK) https://dronetm.hotosm.test > /dev/null && echo "  ✓ Frontend" || echo "  ✗ Frontend"
	@$(CURL_CHECK) https://dronetm.hotosm.test/api/health > /dev/null && echo "  ✓ Backend API" || echo "  ✗ Backend API"
	@echo ""
	@echo "OpenAerialMap:"
	@$(CURL_CHECK) https://openaerialmap.hotosm.test > /dev/null && echo "  ✓ Frontend" || echo "  ✗ Frontend"
	@$(CURL_CHECK) https://openaerialmap.hotosm.test/api > /dev/null && echo "  ✓ Backend API" || echo "  ✗ Backend API"
	@$(CURL_CHECK) https://oam-upload.hotosm.test/__lbheartbeat__ > /dev/null && echo "  ✓ Uploader" || echo "  ✗ Uploader"
	@$(CURL_CHECK) https://oam-browser.hotosm.test > /dev/null && echo "  ✓ STAC Browser" || echo "  ✗ STAC Browser"
	@echo ""
	@echo "fAIr:"
	@$(CURL_CHECK) https://fair.hotosm.test > /dev/null && echo "  ✓ Frontend" || echo "  ✗ Frontend"
	@$(CURL_CHECK) https://fair.hotosm.test/api/v1/ > /dev/null && echo "  ✓ Backend API" || echo "  ✗ Backend API"
	@echo ""
	@echo "uMap:"
	@$(CURL_CHECK) https://umap.hotosm.test > /dev/null && echo "  ✓ Frontend" || echo "  ✗ Frontend"
	@echo ""
	@echo "ChatMap:"
	@$(CURL_CHECK) https://chatmap.hotosm.test > /dev/null && echo "  ✓ Frontend" || echo "  ✗ Frontend"
	@echo ""
	@echo "Export Tool:"
	@$(CURL_CHECK) https://export-tool.hotosm.test > /dev/null && echo "  ✓ App" || echo "  ✗ App"
	@echo ""
	@echo "Raw Data API:"
	@$(CURL_CHECK) https://raw-data-api.hotosm.test/v1 > /dev/null && echo "  ✓ API" || echo "  ✗ API"
	@echo ""
	@echo "Tasking Manager:"
	@$(CURL_CHECK) https://tm.hotosm.test > /dev/null && echo "  ✓ Frontend" || echo "  ✗ Frontend"
	@$(CURL_CHECK) https://tm.hotosm.test/api/docs > /dev/null && echo "  ✓ Backend API" || echo "  ✗ Backend API"
	@echo ""
	@echo "Field-TM:"
	@$(CURL_CHECK) https://field.hotosm.test > /dev/null && echo "  ✓ App" || echo "  ✗ App"
	@echo ""
	@echo "Shared:"
	@$(CURL_CHECK) https://login.hotosm.test/.well-known/jwks.json > /dev/null && echo "  ✓ Hanko Auth" || echo "  ✗ Hanko Auth"
	@$(CURL_CHECK) https://minio.hotosm.test > /dev/null && echo "  ✓ MinIO Console" || echo "  ✗ MinIO Console"
	@$(CURL_CHECK) https://traefik.hotosm.test > /dev/null && echo "  ✓ Traefik Dashboard" || echo "  ✗ Traefik Dashboard"
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

# Note: the first time you run this (right after adding the /hotosm-ui-src mount
# to docker-compose.yml) the container must be recreated so the new volume is
# attached: docker compose up -d --force-recreate portal-frontend
# A plain restart does NOT pick up a newly added mount.
link-hotosm-ui:
	@echo "════════════════════════════════════════════════"
	@echo "  Linking local @hotosm/ui for development"
	@echo "════════════════════════════════════════════════"
	@echo ""
	@for container in hotosm-portal-frontend; do \
		echo "  → $$container"; \
		docker exec $$container sh -c "rm -rf /app/node_modules/@hotosm/ui && ln -s /hotosm-ui-src /app/node_modules/@hotosm/ui && rm -rf /app/node_modules/.vite" 2>/dev/null && echo "    ✓ linked" || echo "    (not running)"; \
	done
	@echo ""
	@echo "Restarting containers to load linked version..."
	@docker compose restart portal-frontend 2>/dev/null || true
	@echo ""
	@echo "Done! Now you can:"
	@echo "  1. Edit code in ../ui/src/"
	@echo "  2. Build: cd ../ui && pnpm build"
	@echo "  3. Refresh browser"

unlink-hotosm-ui:
	@echo "════════════════════════════════════════════════"
	@echo "  Unlinking @hotosm/ui"
	@echo "════════════════════════════════════════════════"
	@echo ""
	@for container in hotosm-portal-frontend; do \
		echo "  → $$container"; \
		docker exec $$container sh -c "rm -rf /app/node_modules/@hotosm/ui /app/node_modules/.vite" 2>/dev/null && echo "    ✓ unlinked" || echo "    (not running)"; \
	done
	@echo ""
	@echo "Restarting containers to clear Vite memory cache..."
	@docker compose restart portal-frontend 2>/dev/null || true
	@echo ""
	@echo "Note: unlike auth-libs, @hotosm/ui is not (yet) a package.json dependency"
	@echo "of portal, so there is no npm version to restore - this only removes the"
	@echo "local symlink."

clean:
	@echo "Cleaning all containers and volumes..."
	@if [ -d "../field-tm" ]; then \
		$(FIELD_TM_COMPOSE) down -v 2>/dev/null || true; \
	fi
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
	@cd ../raw-data-api && git pull && echo "  ✓ Raw Data API"
	@cd ../tasking-manager && git pull && echo "  ✓ Tasking Manager"
	@cd ../auth-libs && git pull && echo "  ✓ Auth-libs"
	@cd ../field-tm && git pull && echo "  ✓ Field-TM"
	@echo ""
	@echo "✓ Updated. Run 'make install' if dependencies changed."

deploy-status:
	@command -v uv >/dev/null 2>&1 || { echo "Error: 'uv' not found. Install with: curl -LsSf https://astral.sh/uv/install.sh | sh"; exit 1; }
	@command -v gh >/dev/null 2>&1 || { echo "Error: 'gh' (GitHub CLI) not found."; echo "  Mac: brew install gh && gh auth login"; echo "  Linux: sudo apt install gh && gh auth login"; exit 1; }
	@if [ "$$(uname)" = "Linux" ]; then \
		command -v xclip >/dev/null 2>&1 || command -v xsel >/dev/null 2>&1 || command -v wl-copy >/dev/null 2>&1 || { \
			echo "Installing xclip for clipboard support..."; \
			sudo apt-get install -y xclip; \
		}; \
	elif [ "$$(uname)" = "Darwin" ]; then \
		command -v pbcopy >/dev/null 2>&1 || { echo "Warning: pbcopy not found (should be built-in on macOS)"; }; \
	fi
	@cd tools/deploy-status && uv run deploy-status

# ==================
# Database
# ==================

load-dump:
	@if [ -z "$(APP)" ] || [ -z "$(URL)" ]; then \
		echo "Usage: make load-dump APP=<app> URL=<dump_url_or_path>"; \
		echo ""; \
		echo "Apps: portal, dronetm, fair, oam, umap, hanko, tm"; \
		echo ""; \
		echo "Examples:"; \
		echo "  make load-dump APP=dronetm URL=https://example.com/dtm_dump.sql"; \
		echo "  make load-dump APP=fair URL=/path/to/local/dump.sql.gz"; \
		exit 1; \
	fi
	@./scripts/load-dump.sh $(APP) $(URL)

setup-test-users:
	@./scripts/setup-test-users.sh $(or $(APP),all)
