# hot-dev-env - HOTOSM Development Environment

This file provides guidance to Claude Code when working with the HOTOSM development environment orchestration.

## Overview

This repository **orchestrates** all HOTOSM applications for local development. It does NOT contain application source code - only Docker Compose configuration, scripts, and documentation.

**Key principle**: All HOTOSM apps live as **sibling repositories**, not submodules or nested folders.

## Directory Structure

```
/home/willaru/dev/HOT/
├── hot-dev-env/          # This repo (orchestration only)
│   ├── docker-compose.yml
│   ├── Makefile
│   └── scripts/
├── portal/               # Portal repo (independent)
├── login/                # Login/SSO repo (independent)
├── drone-tm/             # Drone-TM repo (independent)
└── auth-libs/            # Auth-libs repo (independent)
```

## Architecture: Subdomain Routing

Uses Traefik reverse proxy to mirror production architecture:

```
http://portal.localhost      → Portal (frontend + backend)
http://login.localhost       → Login (Hanko + custom page when ready)
http://dronetm.localhost     → Drone-TM (frontend + backend)
http://minio.localhost       → MinIO Console
http://traefik.localhost     → Traefik Dashboard
```

All services communicate via Docker network `hotosm-dev`.

## Key Files

### docker-compose.yml
- Defines all services with Traefik labels for subdomain routing
- References sibling repos via `build: context: ../portal/frontend`
- Uses profiles for optional services (e.g., `login` profile)
- Volume mounts for hot-reload: `../portal/frontend/src:/app/src`

### Makefile
- `make setup` - Checks repos exist, creates .env files, prompts /etc/hosts config
- `make install` - Installs deps in all repos (auth-libs, portal, login, drone-tm)
- `make dev` - Starts all services
- `make dev-portal` - Starts only Portal
- `make dev-login` - Starts only Login (when frontend/backend exist)
- `make dev-dronetm` - Starts only Drone-TM

### scripts/setup.sh
- Verifies all repos exist: portal, login, drone-tm, auth-libs
- Creates .env files from .env.example
- Checks prerequisites: docker, pnpm, uv
- Calls add-hosts.sh to configure /etc/hosts

### scripts/update-auth-libs.sh
- Builds auth-libs: `cd ../auth-libs && ./scripts/build.sh`
- Distributes to all projects: `./scripts/distribute.sh`
- Used when auth-libs source code changes

### scripts/add-hosts.sh
- Checks if *.localhost entries exist in /etc/hosts
- Prints instructions to add missing entries

## Services Overview

### Portal
- **Frontend**: React 19 + Vite (port 5173)
- **Backend**: FastAPI (port 8000)
- **DB**: PostgreSQL + PostGIS
- **Build context**: `../portal/frontend`, `../portal/backend`

### Login
**Custom Login Setup (current mode):**
- **Frontend**: React + Vite login page at `/app` (port 5174)
- **Backend**: FastAPI for custom auth logic at `/api` (port 8000)
- **Hanko**: Runs as internal SSO service for JWT (port 8000)
  - Exposed endpoints: `/.well-known`, `/login`, `/registration`, etc.
- **Routing**:
  - `/app/*` → Custom login frontend
  - `/api/*` → Custom login backend
  - `/*` (catch-all) → Hanko auth endpoints
- **Build context**: `../login/frontend`, `../login/backend`

### Drone-TM
- **Frontend**: React 19 + Vite (port 3040)
- **Backend**: FastAPI (port 8000)
- **DB**: PostgreSQL + PostGIS
- **MinIO**: S3 storage (ports 9000 API, 9090 Console)
- **Redis**: Cache + task queue
- **NodeODM**: Imagery processing
- **Build context**: `../drone-tm/src/frontend`, `../drone-tm/src/backend`

### Shared Services
- **Hanko**: SSO authentication (internal service)
- **Traefik**: Reverse proxy for subdomain routing
- **PostgreSQL**: Separate DBs for each app + Hanko

## Common Workflows

### Adding a New Service

1. Update `docker-compose.yml`:
```yaml
new-service:
  build:
    context: ../new-service/frontend
  networks:
    - hotosm
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.new.rule=Host(`new.localhost`)"
    - "traefik.http.services.new.loadbalancer.server.port=3000"
```

2. Update `scripts/setup.sh` to check for `../new-service` repo

3. Update `scripts/add-hosts.sh` to include `new.localhost`

4. Update `Makefile install` target to install deps

5. Update README.md with new service docs

### Updating Auth-libs

When auth-libs source changes:

```bash
make auth-libs
```

This:
1. Builds auth-libs (Python wheel + JS bundle)
2. Distributes to portal/backend, portal/frontend, drone-tm/backend
3. Restarts services to pick up changes

### Port Conflicts

**No port conflicts!** Traefik handles all routing on port 80.

Internal containers can use same ports (all use :8000 for backend) because they're in isolated Docker network.

External access is always via subdomain:
- `http://portal.localhost` → portal-backend:8000
- `http://dronetm.localhost/api` → dronetm-backend:8000

### Debugging

View Traefik routing config: `http://traefik.localhost`

Check service logs:
```bash
make logs-follow
docker compose logs -f portal-frontend
```

Connect to service:
```bash
docker exec -it hotosm-portal-backend bash
```

## Important Constraints

### DO NOT
- ❌ Add application source code to this repo
- ❌ Use git submodules (repos are siblings, not nested)
- ❌ Hardcode paths (use relative: `../portal`)
- ❌ Expose services on conflicting ports
- ❌ Modify individual app repos from here

### DO
- ✅ Only orchestration config in this repo (compose, Makefile, scripts)
- ✅ Reference repos as siblings: `../portal`, `../drone-tm`
- ✅ Use Traefik labels for subdomain routing
- ✅ Use profiles for optional services
- ✅ Keep documentation updated (README, this file)

## Environment Variables

### .env (this repo)
```bash
COOKIE_SECRET=...           # Shared session secret
OSM_CLIENT_ID=...          # OSM OAuth
OSM_CLIENT_SECRET=...      # OSM OAuth
```

### Individual app .env files
Each app maintains its own `.env`:
- `../portal/.env`
- `../login/.env`
- `../drone-tm/.env`

The `setup.sh` script copies `.env.example` → `.env` in each repo.

## Traefik Routing

Services are routed by:

1. **Host** - Subdomain (`portal.localhost`, `dronetm.localhost`)
2. **PathPrefix** - URL path (`/api`, `/.well-known`)
3. **Priority** - Higher number = checked first

Example:
```yaml
labels:
  - "traefik.http.routers.login-backend.rule=Host(`login.localhost`) && PathPrefix(`/api`)"
  - "traefik.http.routers.login-backend.priority=2"  # Higher priority
  - "traefik.http.routers.hanko.rule=Host(`login.localhost`) && PathPrefix(`/.well-known`)"
  - "traefik.http.routers.hanko.priority=3"  # Lower priority
```

This ensures `/api` requests go to login-backend, while `/.well-known` (JWT keys) go to Hanko.

## Testing Changes

1. **Before committing**: Test `make setup` on a clean environment
2. **Verify**: All services start with `make dev`
3. **Check**: Subdomain routing works in browser
4. **Confirm**: Hot reload works when editing app source code

## Future Enhancements

- Kubernetes dev setup (Tilt or Skaffold)
- Automated tests for orchestration
- Pre-commit hooks to validate compose file
- Dashboard showing all service status

## Related Documentation

- Main README: Quick start and user guide
- Individual app repos: See their CLAUDE.md for app-specific guidance
- Auth-libs: `/home/willaru/dev/HOT/auth-libs/CLAUDE.md`
- Portal: `/home/willaru/dev/HOT/portal/CLAUDE.md`

## Git Commit Messages

Keep commit messages simple and human-like:

**DO:**
- ✅ "Fix login redirect bug"
- ✅ "Add OSM logout endpoint"
- ✅ "Update deploy workflow secrets"

**DON'T:**
- ❌ Mention AI/Claude/automation
- ❌ Use robotic language
- ❌ Add unnecessary metadata

Write as if a developer typed it quickly - concise, clear, natural.
