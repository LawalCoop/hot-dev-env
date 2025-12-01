# HOTOSM Development Environment

Unified development environment for HOTOSM applications using subdomain routing that mirrors production architecture.

## Overview

This repo orchestrates multiple HOTOSM applications:
- **Portal** - Main application portal
- **Login** - Authentication & SSO service
- **Drone-TM** - Drone Tasking Manager
- **fAIr** - AI-assisted mapping tool
- **Auth-libs** - Shared authentication libraries

All services run locally with subdomain routing (just like production):
```
https://portal.hotosm.test        → Portal
https://dronetm.hotosm.test       → Drone-TM
https://fair.hotosm.test          → fAIr
https://login.hotosm.test         → Hanko SSO
https://minio.hotosm.test         → MinIO Console
https://traefik.hotosm.test       → Traefik Dashboard
```

## Quick Start

### Prerequisites

**All Platforms:**
- [Docker Desktop](https://docs.docker.com/get-docker/) (Windows, macOS, Linux)
- [pnpm](https://pnpm.io/installation) for JavaScript dependencies
- [uv](https://docs.astral.sh/uv/) for Python dependencies
- [Git Bash](https://git-scm.com/downloads) (Windows only)

**macOS Specific:**
- Bash 4+ required (macOS ships with 3.2)
  ```bash
  brew install bash
  sudo bash -c 'echo /usr/local/bin/bash >> /etc/shells'
  chsh -s /usr/local/bin/bash
  ```
  Then restart your terminal

### 1. Clone hot-dev-env

```bash
# Choose a parent directory (examples for each OS):
# Linux/macOS:  ~/dev/HOT  or  /home/username/dev/HOT
# Windows:      C:\dev\HOT  or  C:\Users\username\dev\HOT

cd <your-parent-directory>
git clone https://github.com/hotosm/hot-dev-env.git
cd hot-dev-env
```

### 2. Run Setup

```bash
# This will:
# - Check for/clone missing repos (portal, login, drone-tm, fAIr, auth-libs)
# - Switch portal and login to develop branch automatically
# - Create .env files from examples
# - Configure hosts file for *.hotosm.test domains
make setup
```

The setup script will guide you through:
1. **Cloning missing repositories** (if needed)
2. **Switching to develop branch** for portal and login
3. **Creating .env files** from .env.example templates
4. **Configuring hosts file** with instructions for your OS

Your final directory structure:
```
<parent-directory>/
├── hot-dev-env/
├── portal/          (on develop branch)
├── login/           (on develop branch)
├── drone-tm/
├── fAIr/
└── auth-libs/
```

### 3. Setup HTTPS (Recommended)

```bash
make setup-https
```

This installs mkcert and generates SSL certificates. Required for:
- WebAuthn/Passkeys (Hanko authentication)
- Service Workers and modern web features
- Testing production-like HTTPS environment

**Supports:**
- **macOS**: Auto-install via Homebrew
- **Linux**: Auto-install via wget
- **Windows**: Choose Chocolatey, Scoop, or manual installation

### 4. Install Dependencies

```bash
make install
```

This will:
- Build and distribute auth-libs
- Install Portal frontend and backend deps
- Install Login frontend and backend deps
- Install Drone-TM frontend and backend deps

### 5. Start Everything

```bash
make dev
```

Open in your browser:
- **Portal:** https://portal.hotosm.test
- **Drone-TM:** https://dronetm.hotosm.test
- **fAIr:** https://fair.hotosm.test
- **Login:** https://login.hotosm.test
- **MinIO Console:** https://minio.hotosm.test (admin/password)
- **Traefik Dashboard:** https://traefik.hotosm.test

Press `Ctrl+C` to stop all services.

## Platform-Specific Notes

### Windows
- Use **Git Bash** to run all make commands
- The setup script will guide you to edit `C:\Windows\System32\drivers\etc\hosts` manually
- For mkcert, choose Chocolatey (recommended) or Scoop during `make setup-https`

### macOS
- Requires **Bash 4+** (see Prerequisites section)
- mkcert installs automatically via Homebrew
- hosts entries added via `sudo` command provided by setup script

### Linux
- All automated - just run `make setup`
- mkcert downloads and installs automatically
- hosts entries added via `sudo` command provided by setup script

## Common Commands

```bash
# Development
make dev              # Start all services
make dev-portal       # Start Portal only
make dev-login        # Start Login only (when frontend/backend exist)
make dev-dronetm      # Start Drone-TM only
make dev-fair         # Start fAIr only
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
┌──────────────────────────────────────────────┐
│  Browser: https://portal.hotosm.test        │
└───────────────┬──────────────────────────────┘
                │
       ┌────────▼────────┐
       │    Traefik      │  (Port 443 HTTPS)
       │  Reverse Proxy  │  (Port 80 → 443 redirect)
       └────────┬────────┘
                │
        ┌───────┴───────┬──────────┬──────────┬──────────┐
        │               │          │          │          │
   ┌────▼────┐    ┌────▼────┐ ┌──▼───┐  ┌───▼───┐ ┌────▼────┐
   │ Portal  │    │Drone-TM │ │Login │  │ Hanko │ │  MinIO  │
   │ :5173   │    │  :3040  │ │:5174 │  │ :8000 │ │  :9090  │
   └─────────┘    └─────────┘ └──────┘  └───────┘ └─────────┘
                                           │ SSO
                                   ┌───────┴────────┐
                                   │  Hanko DB      │
                                   │  PostgreSQL    │
                                   └────────────────┘
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
├── fAIr/                 # fAIr repo (independent)
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
| Portal Frontend | https://portal.hotosm.test | 5173 | React app (Vite) |
| Portal Backend | https://portal.hotosm.test/api | 8000 | FastAPI |
| Drone-TM Frontend | https://dronetm.hotosm.test | 3040 | React app (Vite) |
| Drone-TM Backend | https://dronetm.hotosm.test/api | 8000 | FastAPI |
| fAIr Frontend | https://fair.hotosm.test | 3000 | React app (Vite) |
| fAIr Backend | https://fair.hotosm.test/api | 8000 | Django |
| Login Frontend | https://login.hotosm.test/app | 5174 | React app (Vite) |
| Login Backend | https://login.hotosm.test/api | 8000 | FastAPI |
| Hanko Auth | https://login.hotosm.test | 8000 | Hanko SSO (internal) |
| MinIO Console | https://minio.hotosm.test | 9090 | S3 storage UI |
| Traefik Dashboard | https://traefik.hotosm.test | 8080 | Routing config |

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

### Working on fAIr

```bash
# Start only fAIr services
make dev-fair

# Or run locally
cd ../fAIr
cd frontend && pnpm dev  # Frontend on :3000
cd backend && python manage.py runserver  # Backend on :8000
```

**Note:** fAIr uses an auto-install entrypoint. When `package.json` changes, just restart the container and dependencies will be reinstalled automatically:
```bash
docker compose restart fair-frontend
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
2. Set redirect URI: `https://login.hotosm.test/thirdparty/callback/openstreetmap`
3. Add Client ID and Secret to `../login/hanko-config.yaml`

### Hosts File Configuration

The setup script will detect your OS and provide instructions to add:

```
127.0.0.1 portal.hotosm.test
127.0.0.1 dronetm.hotosm.test
127.0.0.1 fair.hotosm.test
127.0.0.1 login.hotosm.test
127.0.0.1 minio.hotosm.test
127.0.0.1 traefik.hotosm.test
```

**File locations:**
- Linux/macOS: `/etc/hosts`
- Windows: `C:\Windows\System32\drivers\etc\hosts`

**Why?** The `.hotosm.test` domains match production (`hotosm.org`) for consistent development experience.

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

### Can't access *.hotosm.test URLs

1. **Verify hosts file entries:**
   - Linux/macOS: `cat /etc/hosts | grep hotosm.test`
   - Windows: `type C:\Windows\System32\drivers\etc\hosts | findstr hotosm.test`

2. **Test DNS resolution:**
   ```bash
   ping portal.hotosm.test
   # Should reply from 127.0.0.1
   ```

3. **Clear DNS cache:**
   - Linux: `sudo systemd-resolve --flush-caches`
   - macOS: `sudo dscacheutil -flushcache`
   - Windows: `ipconfig /flushdns`

4. **Check Traefik is running:**
   ```bash
   docker ps | grep traefik
   # View dashboard: https://traefik.hotosm.test
   ```

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
