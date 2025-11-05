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

# Define repository URLs
declare -A REPO_URLS=(
    ["portal"]="https://github.com/hotosm/portal.git"
    ["drone-tm"]="https://github.com/hotosm/drone-tm.git"
    ["auth-libs"]="https://github.com/LawalCoop/hot-auth-libs.git"
    ["login"]="https://github.com/LawalCoop/login.git"
)

declare -A REPO_URLS_SSH=(
    ["portal"]="git@github.com:hotosm/portal.git"
    ["drone-tm"]="git@github.com:hotosm/drone-tm.git"
    ["auth-libs"]="git@github.com:LawalCoop/hot-auth-libs.git"
    ["login"]="git@github.com:LawalCoop/login.git"
)

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

    # Ask user if they want to clone
    read -p "Would you like to clone the missing repositories? (y/n): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Ask for clone method
        echo ""
        echo "Choose clone method:"
        echo "  1) HTTPS (works everywhere)"
        echo "  2) SSH (requires SSH key setup)"
        read -p "Enter choice (1 or 2): " -n 1 -r CLONE_METHOD
        echo ""
        echo ""

        # Clone missing repos
        cd ..
        for repo in "${MISSING_REPOS[@]}"; do
            echo "→ Cloning $repo..."
            if [[ $CLONE_METHOD == "2" ]]; then
                git clone "${REPO_URLS_SSH[$repo]}" "$repo"
            else
                git clone "${REPO_URLS[$repo]}" "$repo"
            fi

            if [[ $? -eq 0 ]]; then
                echo "  ✓ Successfully cloned $repo"
            else
                echo "  ✗ Failed to clone $repo"
                exit 1
            fi
        done
        cd hot-dev-env
        echo ""
        echo "  ✓ All repositories cloned successfully"
        echo ""
    else
        echo ""
        echo "Setup cannot continue without the required repositories."
        echo "Please clone them manually or run setup again."
        exit 1
    fi
else
    echo "  ✓ All repositories present (portal, drone-tm, auth-libs, login)"
    echo ""
fi

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

# Create hanko-config.yaml for login service
echo ""
echo "→ Setting up Hanko configuration file..."

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
