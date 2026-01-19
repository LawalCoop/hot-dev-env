# uMap en hot-dev-env - Guía de Configuración

## Resumen de Cambios

Se ha integrado exitosamente **uMap** en el entorno de desarrollo `hot-dev-env` con soporte completo para:

- ✅ Instalación automatizada (`make setup`)
- ✅ URL local: `https://umap.hotosm.test`
- ✅ URL producción: `https://umap-dev.hotosm.org`
- ✅ Autenticación Hanko SSO (compartida con otros servicios)
- ✅ Branch automático: `login_hanko`
- ✅ Base de datos PostgreSQL + PostGIS dedicada
- ✅ Health checks configurados
- ✅ Traefik reverse proxy integrado

## Archivos Modificados

1. **Makefile**
   - Added: `dev-umap` target
   - Added: umap a help, install, update, health checks, load-dump

2. **scripts/setup.sh**
   - Added: umap a REPO_URLS (HTTPS y SSH)
   - Added: Verificación y clonación automática
   - Added: Branch switching a `login_hanko`
   - Added: Configuración de .env

3. **scripts/add-hosts.sh**
   - Added: Entry `127.0.0.1 umap.hotosm.test`

4. **docker-compose.yml**
   - Added: Volumen `umap-db-data`
   - Added: Servicio `umap-db` (PostgreSQL 14 + PostGIS)
   - Added: Servicio `umap-app` (Django con Hanko)

5. **UMAP_INTEGRATION.md** (nuevo)
   - Documentación completa de setup, desarrollo, y producción

## Quick Start

```bash
# 1. Setup inicial (clona repositorio, configura hosts, etc)
cd hot-dev-env
make setup

# 2. Instalar dependencias
make install

# 3. Iniciar solo uMap
make dev-umap

# O iniciar todos los servicios (incluyendo uMap)
make dev

# 4. Acceder a uMap
# https://umap.hotosm.test
```

## Configuración por Entorno

### Desarrollo (Local)

**URL**: `https://umap.hotosm.test`

**Autenticación Predeterminada**: OSM OAuth (legacy)

```bash
# En .env
AUTH_PROVIDER=legacy
DEBUG=true
```

**Autenticación Hanko** (opcional):

```bash
# En .env
AUTH_PROVIDER=hanko
HANKO_API_URL=http://hanko:8000
JWT_ISSUER=https://login.hotosm.test
COOKIE_SECRET=<32-bytes-random>
COOKIE_DOMAIN=.hotosm.test
COOKIE_SECURE=false
```

### Producción

**URL**: `https://umap-dev.hotosm.org`

**Configuración Requerida**:

```bash
# .env de producción
AUTH_PROVIDER=hanko
UMAP_SITE_URL=https://umap-dev.hotosm.org
UMAP_SECRET_KEY=<random-secret>
DEBUG=false

# Hanko Configuration
HANKO_API_URL=https://login.hotosm.org
JWT_ISSUER=https://login.hotosm.org
COOKIE_SECRET=<random-32-bytes>
COOKIE_DOMAIN=.hotosm.org
COOKIE_SECURE=true

# Database (external)
UMAP_DB_HOST=<production-db-host>
UMAP_DB_USER=<secure-user>
UMAP_DB_PASSWORD=<secure-password>
```

## Servicios Iniciados

Cuando ejecutas `make dev-umap` o `make dev`:

```
umap-app       ← Django application (puerto 8000)
│
└─ umap-db     ← PostgreSQL 14 + PostGIS (puerto 5432)

hanko          ← Shared SSO service (puerto 8000)
hanko-db       ← Hanko database (puerto 5432)
mailhog        ← Email testing (puerto 1025, 8025)
traefik        ← Reverse proxy (puerto 80, 443, 8080)
```

## URLs Disponibles

| Servicio | Desarrollo | Producción |
|----------|-----------|-----------|
| uMap | https://umap.hotosm.test | https://umap-dev.hotosm.org |
| Portal | https://portal.hotosm.test | https://portal.hotosm.org |
| Login | https://login.hotosm.test | https://login.hotosm.org |
| Traefik | https://traefik.hotosm.test:8080 | N/A |
| MinIO | https://minio.hotosm.test | N/A |

## Comandos Útiles

```bash
# Iniciar servicios
make dev              # Todos los servicios
make dev-umap         # Solo uMap + dependencias

# Gestión
make stop             # Detener todos
make restart          # Reiniciar todos
make logs -f          # Ver logs en vivo
make ps               # Ver contenedores
make health           # Health check

# Actualización
make update           # Git pull all repos
make install          # Reinstalar dependencias

# Base de datos
make load-dump APP=umap URL=<archivo.sql>

# Limpieza
make clean            # Eliminar containers y volumes
```

## Base de Datos

### Local (Desarrollo)

- **Host**: `umap-db` (en red Docker)
- **Puerto**: 5432
- **Base**: `umap`
- **Usuario**: `umap`
- **Contraseña**: `umap123456`
- **Volumen**: `umap-db-data`

### Acceso desde Host

```bash
# Desde el host (fuera de Docker)
psql -h localhost -p 5432 -U umap -d umap

# Dentro de contenedor
docker exec -it hotosm-umap-db psql -U umap -d umap
```

## Autenticación Hanko

Cuando `AUTH_PROVIDER=hanko`, uMap tiene acceso a:

```python
# En views/middleware
request.hotosm.user        # HankoUser (id, email, name)
request.hotosm.osm         # OSMConnection (o None)

# Ejemplo
if request.hotosm.user:
    user_id = request.hotosm.user.id
    email = request.hotosm.user.email
    has_osm = bool(request.hotosm.osm)
```

## Troubleshooting

### Error: "umap.hotosm.test not found"

```bash
# Verificar /etc/hosts
cat /etc/hosts | grep umap.hotosm.test

# O ejecutar setup nuevamente
./scripts/add-hosts.sh
```

### uMap no inicia

```bash
# Ver logs
docker compose logs umap-app

# Verificar database
docker compose logs umap-db

# Reiniciar
make restart
```

### Puerto 8000 ocupado

```bash
# Buscar el proceso
lsof -i :8000

# O cambiar puerto en docker-compose.yml
```

### Base de datos corrupta

```bash
# CUIDADO: Esto elimina todos los datos
make clean
make dev-umap
```

## Archivos Importantes

```
hot-dev-env/
├── Makefile                   # Targets (dev-umap, install, etc)
├── docker-compose.yml         # Servicios (umap-app, umap-db)
├── UMAP_INTEGRATION.md        # Documentación detallada
├── scripts/
│   ├── setup.sh              # Setup automation
│   └── add-hosts.sh           # /etc/hosts management
└── config/
    ├── hanko-config.yaml
    ├── traefik-tls.yml
    └── (otros servicios)

../umap/
├── app/                       # Aplicación Django
│   ├── settings.py            # Configuración Hanko
│   ├── urls.py                # URL routing
│   ├── custom/
│   │   └── hanko_helpers.py   # Utilidades Hanko
│   ├── pyproject.toml         # Dependencies
│   └── Dockerfile             # Container
├── env.docker.sample          # Template de .env
└── docker-compose.yml         # Compose standalone (no usado)
```

## Próximos Pasos

### 1. Setup Inicial

```bash
cd hot-dev-env
make setup
```

Esto hará:
- Clonar repositorio umap si no existe
- Cambiar a branch `login_hanko`
- Crear `.env` desde template
- Configurar `/etc/hosts`

### 2. Instalar Dependencias

```bash
make install
```

Instala:
- Frontend dependencies (Portal, OAM, fAIr, ChatMap)
- Backend dependencies (Portal, Drone-TM, uMap, OpenAerialMap, fAIr)

### 3. Iniciar Desarrollo

```bash
# Solo uMap
make dev-umap

# O todos
make dev
```

### 4. Validar

```bash
# Health checks
make health

# Verificar en navegador
# https://umap.hotosm.test
```

## Soporte y Documentación Adicional

- **Hanko Backend**: Ver `/home/andre/hotosm/umap/HANKO_IMPLEMENTATION.md`
- **Integración Completa**: Ver `/home/andre/hotosm/hot-dev-env/UMAP_INTEGRATION.md`
- **Makefile Targets**: `make help`
- **API Portal**: https://portal.hotosm.test/api/docs

---

**Nota**: Para producción en `umap-dev.hotosm.org`, actualizar valores en `.env` según la sección de "Producción" arriba.
