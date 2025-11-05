#!/bin/bash
set -e

echo "════════════════════════════════════════════════"
echo "  HOTOSM Development Environment Setup"
echo "════════════════════════════════════════════════"
echo ""

# Check if we're in the right directory
if [[ ! -f "docker-compose.yml" ]]; then
    echo "Error: Run this script from the hot-dev-env directory"
    exit 1
fi

# Check prerequisites
echo "→ Checking prerequisites..."
command -v docker >/dev/null 2>&1 || { echo "  ✗ docker not installed"; exit 1; }
command -v pnpm >/dev/null 2>&1 || { echo "  ✗ pnpm not installed (https://pnpm.io/)"; exit 1; }
command -v uv >/dev/null 2>&1 || { echo "  ✗ uv not installed (https://docs.astral.sh/uv/)"; exit 1; }
echo "  ✓ docker, pnpm, uv found"
echo ""

# Check repositories
echo "→ Checking repositories..."
MISSING_REPOS=()

if [[ ! -d "../portal" ]]; then
    MISSING_REPOS+=("portal")
fi

if [[ ! -d "../drone-tm" ]]; then
    MISSING_REPOS+=("drone-tm")
fi

if [[ ! -d "../auth-libs" ]]; then
    MISSING_REPOS+=("auth-libs")
fi

if [[ ! -d "../login" ]]; then
    MISSING_REPOS+=("login")
fi

if [[ ${#MISSING_REPOS[@]} -gt 0 ]]; then
    echo "  ✗ Missing repositories:"
    for repo in "${MISSING_REPOS[@]}"; do
        echo "    - $repo"
    done
    echo ""
    echo "Please clone the missing repositories:"
    for repo in "${MISSING_REPOS[@]}"; do
        echo "  cd /home/willaru/dev/HOT && git clone https://github.com/hotosm/$repo.git"
    done
    exit 1
fi

echo "  ✓ All repositories present (portal, drone-tm, auth-libs, login)"
echo ""

# Create .env if it doesn't exist
echo "→ Setting up environment files..."

if [[ ! -f ".env" ]]; then
    if [[ -f ".env.example" ]]; then
        cp .env.example .env
        echo "  ✓ Created .env (please review and update)"
    else
        echo "  ⚠ .env.example not found, skipping .env creation"
    fi
else
    echo "  ✓ .env already exists"
fi

if [[ ! -f "../portal/.env" ]]; then
    if [[ -f "../portal/.env.example" ]]; then
        cp ../portal/.env.example ../portal/.env
        echo "  ✓ Created ../portal/.env (please review and update)"
    fi
else
    echo "  ✓ ../portal/.env already exists"
fi

if [[ ! -f "../drone-tm/.env" ]]; then
    if [[ -f "../drone-tm/.env.example" ]]; then
        cp ../drone-tm/.env.example ../drone-tm/.env
        echo "  ✓ Created ../drone-tm/.env (please review and update)"
    fi
else
    echo "  ✓ ../drone-tm/.env already exists"
fi

if [[ ! -f "../login/.env" ]]; then
    if [[ -f "../login/.env.example" ]]; then
        cp ../login/.env.example ../login/.env
        echo "  ✓ Created ../login/.env (please review and update)"
    fi
else
    echo "  ✓ ../login/.env already exists"
fi

# Create hanko-config.yaml files if they don't exist
echo ""
echo "→ Setting up Hanko configuration files..."

if [[ ! -f "../login/hanko-config.yaml" ]]; then
    if [[ -f "../login/hanko-config.yaml.example" ]]; then
        cp ../login/hanko-config.yaml.example ../login/hanko-config.yaml
        echo "  ✓ Created ../login/hanko-config.yaml (please update Google OAuth credentials)"
    else
        echo "  ⚠ ../login/hanko-config.yaml.example not found"
    fi
else
    echo "  ✓ ../login/hanko-config.yaml already exists"
fi

if [[ ! -f "../portal/hanko-config.yaml" ]]; then
    if [[ -f "../portal/hanko-config.yaml.example" ]]; then
        cp ../portal/hanko-config.yaml.example ../portal/hanko-config.yaml
        echo "  ✓ Created ../portal/hanko-config.yaml (please update Google OAuth credentials)"
    else
        echo "  ⚠ ../portal/hanko-config.yaml.example not found"
    fi
else
    echo "  ✓ ../portal/hanko-config.yaml already exists"
fi

echo ""

# Configure /etc/hosts
echo "→ Configuring /etc/hosts..."
./scripts/add-hosts.sh

echo ""
echo "════════════════════════════════════════════════"
echo "  Setup Complete!"
echo "════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  1. Review and update environment files:"
echo "     - .env"
echo "     - ../portal/.env"
echo "     - ../login/.env"
echo "     - ../drone-tm/.env"
echo ""
echo "  2. Update Google OAuth credentials in:"
echo "     - ../login/hanko-config.yaml"
echo "     - ../portal/hanko-config.yaml"
echo "     (Replace YOUR_GOOGLE_CLIENT_ID and YOUR_GOOGLE_CLIENT_SECRET)"
echo ""
echo "  3. Install dependencies:"
echo "     make install"
echo ""
echo "  4. Start development environment:"
echo "     make dev"
echo ""
echo "URLs will be:"
echo "  Portal:        http://portal.localhost"
echo "  Drone-TM:      http://dronetm.localhost"
echo "  Hanko Auth:    http://login.localhost"
echo "  MinIO Console: http://minio.localhost"
echo ""
