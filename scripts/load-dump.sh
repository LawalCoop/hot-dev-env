#!/bin/bash
# Load a database dump into a HOTOSM app database
#
# Usage: ./scripts/load-dump.sh <app> <dump_url>
#
# Examples:
#   ./scripts/load-dump.sh dronetm https://example.com/dtm_dump.sql
#   ./scripts/load-dump.sh fair https://example.com/fair_dump.sql.gz
#   ./scripts/load-dump.sh portal /path/to/local/dump.sql

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# App configurations: container, user, database
declare -A APP_CONFIG
APP_CONFIG["portal"]="hotosm-portal-db:portal:portal"
APP_CONFIG["dronetm"]="hotosm-dronetm-db:dtm:dtm_db"
APP_CONFIG["fair"]="hotosm-fair-db:fair:fair"
APP_CONFIG["oam"]="hotosm-oam-db:postgres:postgres"
APP_CONFIG["hanko"]="hotosm-hanko-db:hanko:hanko"
APP_CONFIG["umap"]="hotosm-umap-db:umap:umap"
APP_CONFIG["export-tool"]="hotosm-export-tool-db:exports:exports"

# Backend containers (to stop before dropping DB)
declare -A BACKEND_CONFIG
BACKEND_CONFIG["portal"]="hotosm-portal-backend"
BACKEND_CONFIG["dronetm"]="hotosm-dronetm-backend"
BACKEND_CONFIG["fair"]="hotosm-fair-backend"
BACKEND_CONFIG["oam"]="hotosm-oam-backend"
BACKEND_CONFIG["umap"]="hotosm-umap-app"
BACKEND_CONFIG["export-tool"]="hotosm-export-tool-app"
# hanko has no separate backend

usage() {
    echo -e "${YELLOW}Usage:${NC} $0 <app> <dump_url_or_path>"
    echo ""
    echo "Apps: portal, dronetm, fair, oam, hanko, umap, export-tool"
    echo ""
    echo "Examples:"
    echo "  $0 dronetm https://example.com/dtm_dump.sql"
    echo "  $0 fair https://example.com/fair_dump.sql.gz"
    echo "  $0 portal /path/to/local/dump.sql"
    exit 1
}

# Check arguments
if [ $# -ne 2 ]; then
    usage
fi

APP=$1
DUMP_SOURCE=$2

# Validate app
if [ -z "${APP_CONFIG[$APP]}" ]; then
    echo -e "${RED}Error:${NC} Unknown app '$APP'"
    echo "Valid apps: ${!APP_CONFIG[@]}"
    exit 1
fi

# Parse config
IFS=':' read -r CONTAINER DB_USER DB_NAME <<< "${APP_CONFIG[$APP]}"

echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Loading Database Dump${NC}"
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo ""
echo -e "App:       ${YELLOW}$APP${NC}"
echo -e "Container: ${YELLOW}$CONTAINER${NC}"
echo -e "Database:  ${YELLOW}$DB_NAME${NC}"
echo -e "User:      ${YELLOW}$DB_USER${NC}"
echo -e "Source:    ${YELLOW}$DUMP_SOURCE${NC}"
echo ""

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo -e "${RED}Error:${NC} Container '$CONTAINER' is not running"
    echo "Start it with: make dev-$APP (or make dev)"
    exit 1
fi

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

DUMP_FILE="$TEMP_DIR/dump.sql"

# Download or copy dump file
if [[ "$DUMP_SOURCE" == http* ]]; then
    echo -e "${YELLOW}→ Downloading dump...${NC}"

    # Check if it's gzipped
    if [[ "$DUMP_SOURCE" == *.gz ]]; then
        curl -fSL "$DUMP_SOURCE" | gunzip > "$DUMP_FILE"
    else
        curl -fSL "$DUMP_SOURCE" -o "$DUMP_FILE"
    fi
else
    # Local file
    if [ ! -f "$DUMP_SOURCE" ]; then
        echo -e "${RED}Error:${NC} File not found: $DUMP_SOURCE"
        exit 1
    fi

    echo -e "${YELLOW}→ Copying local dump...${NC}"

    if [[ "$DUMP_SOURCE" == *.gz ]]; then
        gunzip -c "$DUMP_SOURCE" > "$DUMP_FILE"
    else
        cp "$DUMP_SOURCE" "$DUMP_FILE"
    fi
fi

echo -e "${GREEN}✓${NC} Dump file ready ($(du -h "$DUMP_FILE" | cut -f1))"

# Confirm before proceeding
echo ""
echo -e "${RED}WARNING: This will DROP and recreate the '$DB_NAME' database!${NC}"
echo -e "All existing data will be lost."
echo ""
read -p "Continue? [y/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Copy dump to container
echo -e "${YELLOW}→ Copying dump to container...${NC}"
docker cp "$DUMP_FILE" "$CONTAINER:/tmp/dump.sql"

# Stop backend if running (to release DB connections)
BACKEND="${BACKEND_CONFIG[$APP]}"
RESTART_BACKEND=false
if [ -n "$BACKEND" ] && docker ps --format '{{.Names}}' | grep -q "^${BACKEND}$"; then
    echo -e "${YELLOW}→ Stopping backend to release DB connections...${NC}"
    docker stop "$BACKEND" > /dev/null
    RESTART_BACKEND=true
fi

# Drop and recreate database, then restore
echo -e "${YELLOW}→ Dropping and recreating database...${NC}"
docker exec "$CONTAINER" psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;"
docker exec "$CONTAINER" psql -U "$DB_USER" -d postgres -c "CREATE DATABASE $DB_NAME;"

# Check if PostGIS is needed
if [[ "$APP" == "portal" || "$APP" == "dronetm" || "$APP" == "fair" || "$APP" == "umap" || "$APP" == "export-tool" ]]; then
    echo -e "${YELLOW}→ Enabling PostGIS extension...${NC}"
    docker exec "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS postgis;"
fi

# Restore dump
echo -e "${YELLOW}→ Restoring dump...${NC}"
docker exec "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -f /tmp/dump.sql

# Cleanup
docker exec "$CONTAINER" rm /tmp/dump.sql

# Restart backend if we stopped it
if [ "$RESTART_BACKEND" = true ]; then
    echo -e "${YELLOW}→ Restarting backend...${NC}"
    docker start "$BACKEND" > /dev/null
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ Database restored successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo ""
