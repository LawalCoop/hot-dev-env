# uMap Integration in hot-dev-env

This document describes the integration of the HOT uMap instance into the hot-dev-env orchestration.

## Overview

- **Service Name**: `umap-app` and `umap-db`
- **Local URL**: `https://umap.hotosm.test` (development)
- **Production URL**: `https://umap-dev.hotosm.org`
- **Branch**: `login_hanko` (auto-switched by setup.sh)
- **Auth Provider**: Supports both `legacy` (OSM OAuth) and `hanko` (SSO)

## Setup

### 1. Automatic Setup

Run `make setup` which will:
- Clone the uMap repository if missing
- Switch to the `login_hanko` branch
- Create `.env` from `env.docker.sample`
- Add `umap.hotosm.test` to `/etc/hosts`

### 2. Manual Installation

```bash
# Install uMap backend dependencies
cd ../umap/app
uv sync
```

## Development

### Start Only uMap

```bash
make dev-umap
```

This starts:
- `umap-db` - PostgreSQL with PostGIS
- `umap-app` - Django application
- `hanko` - SSO service (shared)
- `hanko-db` - Hanko database (shared)
- `mailhog` - Email testing (shared)
- `traefik` - Reverse proxy (shared)

### Start All Services

```bash
make dev
```

## Configuration

### Environment Variables

Set in `.env` or `docker-compose.yml`:

**Development Mode** (default):
```bash
AUTH_PROVIDER=legacy                    # Use OSM OAuth
UMAP_SECRET_KEY=dev-secret-key-change
UMAP_DB_HOST=umap-db
UMAP_DB_USER=umap
UMAP_DB_PASSWORD=umap123456
```

**Hanko SSO Mode**:
```bash
AUTH_PROVIDER=hanko
HANKO_API_URL=http://hanko:8000
JWT_ISSUER=https://login.hotosm.test
COOKIE_SECRET=32-byte-secret-key-change-me
COOKIE_DOMAIN=.hotosm.test
COOKIE_SECURE=false                     # true in production
```

### Database

- **Host**: `umap-db`
- **Port**: 5432
- **Name**: umap
- **User**: umap
- **Password**: umap123456 (change in production)

Volume: `umap-db-data`

## URLs

### Local Development

```
https://umap.hotosm.test
```

### Production

```
https://umap-dev.hotosm.org
```

## Hanko Authentication

When `AUTH_PROVIDER=hanko`:

1. User receives SSO token from Hanko
2. HankoAuthMiddleware injects `request.hotosm` object
3. Views can access:
   - `request.hotosm.user` - HankoUser object
   - `request.hotosm.osm` - OSMConnection object (or None)

### Protected Views Example

```python
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

class ProtectedMapView(APIView):
    def get(self, request):
        if not hasattr(request, 'hotosm') or not request.hotosm.user:
            return Response(
                {"error": "Not authenticated"},
                status=status.HTTP_401_UNAUTHORIZED
            )
        
        user = request.hotosm.user
        return Response({
            "user_id": user.id,
            "email": user.email,
        })
```

### User Filtering

Use `HankoUserFilterMixin` to filter querysets by authenticated user:

```python
from custom.hanko_helpers import HankoUserFilterMixin
from rest_framework import viewsets

class MapViewSet(HankoUserFilterMixin, viewsets.ModelViewSet):
    queryset = Map.objects.all()
    serializer_class = MapSerializer
```

The mixin automatically filters by the mapped user ID for the "umap" app.

## Health Check

Check if uMap is running:

```bash
make health
```

Or manually:

```bash
curl -f https://umap.hotosm.test
```

## Logs

View logs:

```bash
docker compose logs umap-app
docker compose logs -f umap-app    # Follow logs
```

## Troubleshooting

### uMap won't start

1. Check logs: `docker compose logs umap-app`
2. Verify database is healthy: `docker compose logs umap-db`
3. Ensure `umap.hotosm.test` is in `/etc/hosts`
4. Restart services: `make restart`

### Database connection error

```bash
# Reset database
docker compose down -v  # WARNING: This removes all data!
make dev-umap
```

### Hanko authentication not working

1. Verify `hanko` container is running
2. Check HANKO_API_URL points to correct service
3. Verify JWT_ISSUER matches Hanko configuration
4. Check HankoAuthMiddleware is before AuthenticationMiddleware in settings.py

## Production Deployment

For production on `umap-dev.hotosm.org`:

1. Update URLs in DNS/reverse proxy
2. Set `COOKIE_SECURE=true`
3. Update `COOKIE_DOMAIN` to `.hotosm.org`
4. Generate proper COOKIE_SECRET (32+ bytes)
5. Use production HANKO_API_URL
6. Enable HTTPS with valid certificate

### Environment Template

```bash
# Production .env
AUTH_PROVIDER=hanko
UMAP_SITE_URL=https://umap-dev.hotosm.org
UMAP_SECRET_KEY=<generate-with-secrets.token_urlsafe(32)>
UMAP_DB_HOST=umap-db-prod
UMAP_DB_NAME=umap
UMAP_DB_USER=<secure-username>
UMAP_DB_PASSWORD=<secure-password>

HANKO_API_URL=https://login.hotosm.org
JWT_ISSUER=https://login.hotosm.org
COOKIE_SECRET=<generate-with-secrets.token_urlsafe(32)>
COOKIE_DOMAIN=.hotosm.org
COOKIE_SECURE=true

DEBUG=false
ALLOWED_HOSTS=umap-dev.hotosm.org
CSRF_TRUSTED_ORIGINS=https://umap-dev.hotosm.org
```

## Related Services

- **Hanko Auth**: https://login.hotosm.test
- **Portal**: https://portal.hotosm.test
- **Traefik Dashboard**: https://traefik.hotosm.test:8080

## File Structure

```
hot-dev-env/
├── docker-compose.yml       # Service definitions (umap-app, umap-db)
├── Makefile                 # make dev-umap target
├── scripts/
│   ├── setup.sh            # Repository cloning and branch switching
│   └── add-hosts.sh         # /etc/hosts configuration
└── UMAP_INTEGRATION.md      # This file

../umap/
├── app/                     # Django application
│   ├── pyproject.toml       # Dependencies (includes hotosm-auth)
│   ├── settings.py          # Django settings (Hanko config)
│   ├── urls.py              # URL routing (admin mappings)
│   ├── custom/
│   │   └── hanko_helpers.py # Hanko utilities
│   └── Dockerfile           # Application container
├── docker-compose.yml       # Standalone compose (not used in hot-dev-env)
├── docker-compose.dev.yml   # Dev compose (not used in hot-dev-env)
└── env.docker.sample        # Environment template
```

## Make Targets

```bash
make setup              # Setup repositories and configuration
make install            # Install all dependencies (includes umap/app)
make dev                # Start all services (includes umap)
make dev-umap           # Start umap only
make stop               # Stop all services
make restart            # Restart all services
make logs               # Show all logs
make health             # Check service health (includes umap)
make update             # Git pull all repos (includes umap)
make load-dump APP=umap URL=<file-or-url>  # Load database dump
```

## See Also

- `/home/andre/hotosm/umap/HANKO_IMPLEMENTATION.md` - Backend Hanko configuration
- `/home/andre/hotosm/hot-dev-env/Makefile` - Available make targets
- `/home/andre/hotosm/hot-dev-env/docker-compose.yml` - Full service definitions
