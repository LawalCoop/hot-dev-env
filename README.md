# HOTOSM Development Environment

Unified development environment for HOTOSM applications using subdomain routing that mirrors production architecture.

## Overview

This repo orchestrates multiple HOTOSM applications:
- **Portal** - Main application portal
- **Login** - Authentication & SSO service
- **Drone-TM** - Drone Tasking Manager
- **Auth-libs** - Shared authentication libraries

All services run locally with subdomain routing (just like production):
```
http://portal.localhost        → Portal
http://dronetm.localhost       → Drone-TM
http://login.localhost         → Hanko SSO
http://minio.localhost         → MinIO Console
http://traefik.localhost       → Traefik Dashboard
```

## Quick Start

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose
- [pnpm](https://pnpm.io/installation) for JavaScript dependencies
- [uv](https://docs.astral.sh/uv/) for Python dependencies

### 1. Clone Repositories

```bash
cd /home/willaru/dev/HOT

# Clone all repos as siblings
git clone https://github.com/hotosm/hot-dev-env.git
git clone https://github.com/hotosm/portal.git
git clone https://github.com/hotosm/login.git
git clone https://github.com/hotosm/drone-tm.git
git clone https://github.com/hotosm/auth-libs.git

# Your directory structure should look like:
# HOT/
# ├── hot-dev-env/
# ├── portal/
# ├── login/
# ├── drone-tm/
# └── auth-libs/
```

### 2. Setup

```bash
cd hot-dev-env

# Run setup (checks repos, configures hosts)
make setup

# Review and update .env file
cp .env.example .env
nano .env  # Add your OSM OAuth credentials

# Also review individual app .env files
nano ../portal/.env
nano ../drone-tm/.env
```

### 3. Install Dependencies

```bash
make install
```

This will:
- Build and distribute auth-libs
- Install Portal frontend and backend deps
- Install Drone-TM frontend and backend deps

### 4. Start Everything

```bash
make dev
```

Open in your browser:
- **Portal:** http://portal.localhost
- **Drone-TM:** http://dronetm.localhost
- **Hanko Auth:** http://login.localhost
- **MinIO Console:** http://minio.localhost (admin/password)
- **Traefik Dashboard:** http://traefik.localhost

Press `Ctrl+C` to stop.

## HTTPS Setup (Recommended)

Modern web features like **WebAuthn/Passkeys** (used by Hanko) and **Service Workers** require HTTPS. Set up local HTTPS in 2 minutes:

```bash
# Automated setup (installs mkcert, generates certificates)
./scripts/setup-https.sh
```

This will:
1. Install `mkcert` (if not already installed)
2. Install a local Certificate Authority in your browser
3. Generate SSL certificates for `*.localhost` and `*.hotosm.test`
4. Configure Traefik to use HTTPS

After setup, access services via HTTPS:
- **Portal:** https://portal.localhost
- **Drone-TM:** https://dronetm.localhost
- **Hanko Auth:** https://login.localhost
- **MinIO Console:** https://minio.localhost
- **Traefik Dashboard:** https://traefik.localhost

Your browser will show a **valid certificate** with no warnings.

**See [docs/HTTPS_SETUP.md](docs/HTTPS_SETUP.md) for detailed documentation and troubleshooting.**

## Common Commands

```bash
# Development
make dev              # Start all services
make dev-portal       # Start Portal only
make dev-login        # Start Login only (when frontend/backend exist)
make dev-dronetm      # Start Drone-TM only
make stop             # Stop all services
make restart          # Restart all services

# Logs
make logs             # Show all logs
make logs-follow      # Follow all logs (live)

# Management
make ps               # Show running services
make health           # Check service health
make auth-libs        # Update auth-libs after changes
make update           # Git pull all repos

# Cleanup
make clean            # Stop and remove all containers/volumes
```

## Architecture

### Subdomain Routing with Traefik

All services are accessed via subdomains:

```
┌─────────────────────────────────────────┐
│  Browser: http://portal.localhost       │
└───────────────┬─────────────────────────┘
                │
       ┌────────▼────────┐
       │    Traefik      │  (Port 80)
       │  Reverse Proxy  │
       └────────┬────────┘
                │
        ┌───────┴───────┬──────────────┬──────────────┐
        │               │              │              │
   ┌────▼────┐    ┌────▼────┐   ┌────▼────┐   ┌────▼────┐
   │ Portal  │    │Drone-TM │   │  Hanko  │   │  MinIO  │
   │ :5173   │    │  :3040  │   │  :8000  │   │  :9090  │
   └─────────┘    └─────────┘   └─────────┘   └─────────┘
```

This mirrors production architecture where:
- `portal.hotosm.org` → Portal
- `dronetm.hotosm.org` → Drone-TM
- `login.hotosm.org` → Hanko SSO

### Repository Structure

```
HOT/
├── hot-dev-env/          # This repo (orchestration only)
│   ├── docker-compose.yml
│   ├── Makefile
│   ├── scripts/
│   └── traefik/
│
├── portal/               # Portal repo (independent)
├── login/                # Login/SSO repo (independent)
├── drone-tm/             # Drone-TM repo (independent)
└── auth-libs/            # Auth-libs repo (independent)
```

Each app repo maintains its own:
- Git history
- CI/CD pipelines
- `.env` files
- Dependencies

The `hot-dev-env` repo only contains orchestration config (docker-compose, Makefile, scripts).

### Services

| Service | URL | Port | Description |
|---------|-----|------|-------------|
| Portal Frontend | http://portal.localhost | 5173 | React app (Vite) |
| Portal Backend | http://portal.localhost/api | 8000 | FastAPI |
| Drone-TM Frontend | http://dronetm.localhost | 3040 | React app (Vite) |
| Drone-TM Backend | http://dronetm.localhost/api | 8000 | FastAPI |
| Hanko Auth | http://login.localhost | 8000 | Hanko SSO |
| MinIO Console | http://minio.localhost | 9090 | S3 storage UI |
| Traefik Dashboard | http://traefik.localhost | 8080 | Routing config |

### Shared Services

- **Hanko** - Centralized SSO authentication
- **PostgreSQL** - Separate databases for Portal, Drone-TM, and Hanko
- **Redis** - Cache and task queue for Drone-TM
- **MinIO** - S3-compatible storage for drone imagery
- **NodeODM** - Imagery processing

## Development Workflow

### Working on Portal

```bash
# Start only Portal services
make dev-portal

# In another terminal, you can also run Portal locally
cd ../portal
make dev-frontend  # Frontend on :5173
make dev-backend   # Backend on :8000
```

### Working on Login

The Login service works in two modes:

**Mode 1: Hanko Only (default)**
- When `login/frontend/` and `login/backend/` don't exist
- Only Hanko authentication service runs
- Used initially, before custom login page is created

**Mode 2: Custom Login (when migrated)**
- When `login/frontend/` and `login/backend/` exist
- Custom React login page + FastAPI backend
- Hanko runs as backend service for JWT validation

```bash
# Start only Login services (requires frontend/backend)
make dev-login

# Or run locally
cd ../login
cd frontend && pnpm dev  # Frontend on :5174
cd backend && uv run uvicorn app.main:app --reload  # Backend on :8000
```

### Working on Drone-TM

```bash
# Start only Drone-TM services
make dev-dronetm

# Or run locally
cd ../drone-tm
pnpm --filter frontend dev  # Frontend on :3040
cd src/backend && uv run uvicorn app.main:app --reload  # Backend on :8000
```

### Updating Auth-libs

When you make changes to auth-libs:

```bash
# 1. Edit source in ../auth-libs/

# 2. Build and distribute
make auth-libs

# 3. Restart services to pick up changes
make restart
```

## Configuration

### Environment Variables

Main `.env` file (this repo):
```bash
COOKIE_SECRET=...           # Shared session secret
OSM_CLIENT_ID=...          # OSM OAuth
OSM_CLIENT_SECRET=...      # OSM OAuth
```

Also configure individual app `.env` files:
- `../portal/.env`
- `../drone-tm/.env`

### OSM OAuth Setup

1. Register OAuth app at: https://www.openstreetmap.org/oauth2/applications/new
2. Set redirect URI: `http://login.localhost/oauth/callback`
3. Add Client ID and Secret to `.env`

### /etc/hosts

The setup script will prompt you to add these entries:

```
127.0.0.1 portal.localhost
127.0.0.1 dronetm.localhost
127.0.0.1 login.localhost
127.0.0.1 minio.localhost
127.0.0.1 nodeodm.localhost
127.0.0.1 traefik.localhost
```

## Troubleshooting

### Services won't start

```bash
# Check Docker is running
docker ps

# Check ports aren't already in use
lsof -i :80
lsof -i :5432

# Clean and restart
make clean
make dev
```

### Can't access *.localhost URLs

1. Check /etc/hosts has entries
2. Try http://127.0.0.1 instead
3. Check Traefik is running: `docker ps | grep traefik`
4. View Traefik dashboard: http://traefik.localhost

### Portal can't connect to Drone-TM

- Check both services are running: `make ps`
- Check Traefik routing: http://traefik.localhost
- Check Docker network: `docker network inspect hotosm-dev`

### Hot reload not working

- Ensure volumes are mounted correctly in docker-compose.yml
- Restart the specific service: `docker compose restart portal-frontend`
- Check file permissions on host

### Database connection errors

```bash
# Check databases are running
make ps

# View logs
make logs-follow | grep postgres

# Reset databases
make clean
make dev
```

## Contributing

When making changes:

1. Each app stays in its own repo
2. Only orchestration config lives in `hot-dev-env`
3. Commit changes in the appropriate repo
4. Test with `make dev` before pushing

## License

Same as individual projects (typically AGPL-3.0 for HOTOSM projects).
