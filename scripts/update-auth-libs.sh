#!/bin/bash
set -e

echo "════════════════════════════════════════════════"
echo "  Updating Auth-libs"
echo "════════════════════════════════════════════════"

if [[ ! -d "../auth-libs" ]]; then
    echo "Error: auth-libs directory not found at ../auth-libs"
    exit 1
fi

cd ../auth-libs

echo ""
echo "→ Building auth-libs..."
./scripts/build.sh

echo ""
echo "→ Distributing to projects..."
./scripts/distribute.sh

echo ""
echo "→ Updating uv.lock files (hash refresh)..."

# Update lock files for projects using local wheel files
BACKEND_DIRS=(
    "../drone-tm/src/backend"
    "../openaerialmap/backend/stac-api"
    "../fAIr/backend"
)

for dir in "${BACKEND_DIRS[@]}"; do
    if [[ -d "$dir" ]] && [[ -f "$dir/uv.lock" ]]; then
        echo "  → $(basename $(dirname $(dirname $dir)))/$(basename $(dirname $dir))/$(basename $dir)"
        cd "$dir"
        uv lock --upgrade-package hotosm-auth 2>/dev/null || true
        cd - > /dev/null
    fi
done

echo "  ✓ Lock files updated"

echo ""
echo "════════════════════════════════════════════════"
echo "  Auth-libs Updated!"
echo "════════════════════════════════════════════════"
echo ""
echo "Updated locations:"
echo "  ✓ portal/frontend/auth-libs/web-component/dist/"
echo "  ✓ portal/backend/auth-libs/python/dist/"
echo "  ✓ drone-tm/src/backend/auth-libs/dist/"
echo "  ✓ openaerialmap/backend/stac-api/auth-libs/dist/"
echo "  ✓ fAIr/backend/auth-libs/dist/"
echo ""
echo "If services are running, restart them to use updated auth-libs:"
echo "  cd ../hot-dev-env && make restart"
echo ""
