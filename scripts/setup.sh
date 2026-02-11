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

# Check bash version (need 4+ for associative arrays)
BASH_VERSION_NUM="${BASH_VERSION%%[^0-9]*}"
if [[ "$BASH_VERSION_NUM" -lt 4 ]]; then
    echo "Error: This script requires Bash 4 or higher (you have $BASH_VERSION)"
    echo ""
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macOS ships with Bash 3.2. To fix:"
        echo "  brew install bash"
        echo ""
        echo "Then run: bash scripts/setup.sh"
    fi
    exit 1
fi

# Check repositories
echo "→ Checking repositories..."
MISSING_REPOS=()

# Define repository URLs
declare -A REPO_URLS=(
    ["portal"]="https://github.com/hotosm/portal.git"
    ["drone-tm"]="https://github.com/hotosm/drone-tm.git"
    ["auth-libs"]="https://github.com/LawalCoop/hot-auth-libs.git"
    ["login"]="https://github.com/hotosm/login.git"
    ["openaerialmap"]="https://github.com/hotosm/openaerialmap.git"
    ["fAIr"]="https://github.com/hotosm/fAIr.git"
    ["umap"]="https://github.com/hotosm/umap.git"
    ["chatmap"]="https://github.com/hotosm/chatmap.git"
    ["osm-export-tool"]="https://github.com/hotosm/osm-export-tool.git"
    ["raw-data-api"]="https://github.com/hotosm/raw-data-api.git"
    ["tasking-manager"]="https://github.com/hotosm/tasking-manager.git"
)

declare -A REPO_URLS_SSH=(
    ["portal"]="git@github.com:hotosm/portal.git"
    ["drone-tm"]="git@github.com:hotosm/drone-tm.git"
    ["auth-libs"]="git@github.com:LawalCoop/hot-auth-libs.git"
    ["login"]="git@github.com:hotosm/login.git"
    ["openaerialmap"]="git@github.com:hotosm/openaerialmap.git"
    ["fAIr"]="git@github.com:hotosm/fAIr.git"
    ["umap"]="git@github.com:hotosm/umap.git"
    ["chatmap"]="git@github.com:hotosm/chatmap.git"
    ["osm-export-tool"]="git@github.com:hotosm/osm-export-tool.git"
    ["raw-data-api"]="git@github.com:hotosm/raw-data-api.git"
    ["tasking-manager"]="git@github.com:hotosm/tasking-manager.git"
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

if [[ ! -d "../openaerialmap" ]]; then
    MISSING_REPOS+=("openaerialmap")
fi

if [[ ! -d "../fAIr" ]]; then
    MISSING_REPOS+=("fAIr")
fi

if [[ ! -d "../chatmap" ]]; then
    MISSING_REPOS+=("chatmap")
fi

if [[ ! -d "../umap" ]]; then
    MISSING_REPOS+=("umap")
fi

if [[ ! -d "../osm-export-tool" ]]; then
    MISSING_REPOS+=("osm-export-tool")
fi

if [[ ! -d "../raw-data-api" ]]; then
    MISSING_REPOS+=("raw-data-api")
fi

if [[ ! -d "../tasking-manager" ]]; then
    MISSING_REPOS+=("tasking-manager")
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

                # Switch portal and login repos to develop branch
                if [[ "$repo" == "portal" ]] || [[ "$repo" == "login" ]]; then
                    echo "  → Switching to develop branch..."
                    cd "$repo"
                    git checkout develop
                    cd ..
                    echo "  ✓ $repo repo on develop branch"
                fi

                # Switch chatmap to feature/hotosm-auth branch
                if [[ "$repo" == "chatmap" ]]; then
                    cd "$repo"
                    BRANCH_NAME="feature/hotosm-auth"
                    echo "  → Switching to $BRANCH_NAME branch..."
                    git checkout -b $BRANCH_NAME origin/$BRANCH_NAME 2>/dev/null || git checkout $BRANCH_NAME
                    cd ..
                    echo "  ✓ $repo repo on $BRANCH_NAME branch"
                fi

                # Switch umap to login_hanko branch
                if [[ "$repo" == "umap" ]]; then
                    cd "$repo"
                    BRANCH_NAME="login_hanko"
                    echo "  → Switching to $BRANCH_NAME branch..."
                    git checkout -b $BRANCH_NAME origin/$BRANCH_NAME 2>/dev/null || git checkout $BRANCH_NAME
                    cd ..
                    echo "  ✓ $repo repo on $BRANCH_NAME branch"
                fi

                # Switch drone-tm to login-hanko branch, openaerialmap to login_hanko branch
                if [[ "$repo" == "drone-tm" ]]; then
                    cd "$repo"
                    BRANCH_NAME="login-hanko"
                    BRANCH_EXISTS=$(git show-ref --verify --quiet refs/heads/$BRANCH_NAME && echo "yes" || echo "no")
                    REMOTE_BRANCH_EXISTS=$(git show-ref --verify --quiet refs/remotes/origin/$BRANCH_NAME && echo "yes" || echo "no")

                    if [[ "$BRANCH_EXISTS" == "yes" ]]; then
                        echo "  → Switching to $BRANCH_NAME branch..."
                        git checkout $BRANCH_NAME 2>/dev/null
                        echo "  ✓ $repo repo on $BRANCH_NAME branch"
                    elif [[ "$REMOTE_BRANCH_EXISTS" == "yes" ]]; then
                        echo "  → Creating $BRANCH_NAME branch from origin..."
                        git checkout -b $BRANCH_NAME origin/$BRANCH_NAME 2>/dev/null
                        echo "  ✓ $repo repo on $BRANCH_NAME branch"
                    else
                        echo "  ⚠ $BRANCH_NAME branch not found in $repo (staying on $(git branch --show-current))"
                    fi
                    cd ..
                fi

                if [[ "$repo" == "openaerialmap" ]]; then
                    cd "$repo"
                    BRANCH_NAME="login_hanko"
                    BRANCH_EXISTS=$(git show-ref --verify --quiet refs/heads/$BRANCH_NAME && echo "yes" || echo "no")
                    REMOTE_BRANCH_EXISTS=$(git show-ref --verify --quiet refs/remotes/origin/$BRANCH_NAME && echo "yes" || echo "no")

                    if [[ "$BRANCH_EXISTS" == "yes" ]]; then
                        echo "  → Switching to $BRANCH_NAME branch..."
                        git checkout $BRANCH_NAME 2>/dev/null
                        echo "  ✓ $repo repo on $BRANCH_NAME branch"
                    elif [[ "$REMOTE_BRANCH_EXISTS" == "yes" ]]; then
                        echo "  → Creating $BRANCH_NAME branch from origin..."
                        git checkout -b $BRANCH_NAME origin/$BRANCH_NAME 2>/dev/null
                        echo "  ✓ $repo repo on $BRANCH_NAME branch"
                    else
                        echo "  ⚠ $BRANCH_NAME branch not found in $repo (staying on $(git branch --show-current))"
                    fi
                    cd ..
                fi
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
    echo "  ✓ All repositories present (portal, drone-tm, auth-libs, login, openaerialmap, fAIr, umap, chatmap, osm-export-tool, raw-data-api, tasking-manager)"
    echo ""

    # Ensure portal and login repos are on develop branch
    for repo in portal login; do
        if [[ -d "../$repo" ]]; then
            cd "../$repo"
            CURRENT_BRANCH=$(git branch --show-current)
            if [[ "$CURRENT_BRANCH" != "develop" ]]; then
                echo "→ Switching $repo repo to develop branch..."
                git checkout develop
                if [[ $? -eq 0 ]]; then
                    echo "  ✓ $repo repo now on develop branch"
                else
                    echo "  ⚠ Failed to checkout develop branch in $repo repo"
                    echo "    Please run: cd ../$repo && git checkout develop"
                fi
                echo ""
            fi
            cd ../hot-dev-env
        fi
    done

    # Ensure drone-tm, openaerialmap, fAIr, umap, y chatmap repos are on their dev branches
    # drone-tm uses login-hanko, chatmap uses feature/hotosm-auth, others use login_hanko
    for repo in drone-tm openaerialmap fAIr umap chatmap; do
        if [[ -d "../$repo" ]]; then
            cd "../$repo"
            CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)

            # Each repo has its own branch convention
            if [[ "$repo" == "drone-tm" ]]; then
                BRANCH_NAME="login-hanko"
            elif [[ "$repo" == "chatmap" ]]; then
                BRANCH_NAME="feature/hotosm-auth"
            else
                BRANCH_NAME="login_hanko"
            fi

            # Check if branch exists (local or remote)
            BRANCH_EXISTS=$(git show-ref --verify --quiet refs/heads/$BRANCH_NAME && echo "yes" || echo "no")
            REMOTE_BRANCH_EXISTS=$(git show-ref --verify --quiet refs/remotes/origin/$BRANCH_NAME && echo "yes" || echo "no")

            if [[ "$CURRENT_BRANCH" == "$BRANCH_NAME" ]]; then
                echo "  ✓ $repo repo already on $BRANCH_NAME branch"
            elif [[ "$BRANCH_EXISTS" == "yes" ]]; then
                echo "→ Switching $repo repo to $BRANCH_NAME branch..."
                git checkout $BRANCH_NAME 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    echo "  ✓ $repo repo now on $BRANCH_NAME branch"
                else
                    echo "  ⚠ Could not switch $repo to $BRANCH_NAME branch (current: $CURRENT_BRANCH)"
                fi
            elif [[ "$REMOTE_BRANCH_EXISTS" == "yes" ]]; then
                echo "→ Creating $BRANCH_NAME branch from origin in $repo..."
                git checkout -b $BRANCH_NAME origin/$BRANCH_NAME 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    echo "  ✓ $repo repo now on $BRANCH_NAME branch"
                else
                    echo "  ⚠ Could not create $BRANCH_NAME branch in $repo (current: $CURRENT_BRANCH)"
                fi
            else
                echo "  ⚠ $BRANCH_NAME branch not found in $repo repo (current: $CURRENT_BRANCH)"
            fi
            echo ""
            cd ../hot-dev-env
        fi
    done
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

if [[ ! -f "../openaerialmap/.env" ]]; then
    if [[ -f "../openaerialmap/.env.example" ]]; then
        cp ../openaerialmap/.env.example ../openaerialmap/.env
        echo "  ✓ Created ../openaerialmap/.env (please review and update)"
    fi
else
    echo "  ✓ ../openaerialmap/.env already exists"
fi

if [[ ! -f "../fAIr/backend/.env" ]]; then
    if [[ -f "../fAIr/backend/.env.example" ]]; then
        cp ../fAIr/backend/.env.example ../fAIr/backend/.env
        echo "  ✓ Created ../fAIr/backend/.env (please review and update)"
    fi
else
    echo "  ✓ ../fAIr/backend/.env already exists"
fi

if [[ ! -f "../umap/env.docker.sample" ]] || [[ ! -f "../umap/.env" ]]; then
    if [[ -f "../umap/env.docker.sample" ]]; then
        cp ../umap/env.docker.sample ../umap/.env
        echo "  ✓ Created ../umap/.env (please review and update)"
    fi
else
    echo "  ✓ ../umap/.env already exists"
fi

if [[ ! -f "../tasking-manager/tasking-manager.env" ]]; then
    if [[ -f "../tasking-manager/example.env" ]]; then
        cp ../tasking-manager/example.env ../tasking-manager/tasking-manager.env
        echo "  ✓ Created ../tasking-manager/tasking-manager.env (please review and update)"
    fi
else
    echo "  ✓ ../tasking-manager/tasking-manager.env already exists"
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
echo "     - ../openaerialmap/.env"
echo "     - ../fAIr/backend/.env"
echo "     - ../umap/.env"
echo "     - ../tasking-manager/tasking-manager.env"
echo ""
echo "  2. (Optional) Update Google OAuth credentials in:"
echo "     - ./config/hanko-config.yaml"
echo "     (Replace YOUR_GOOGLE_CLIENT_ID and YOUR_GOOGLE_CLIENT_SECRET)"
echo ""
echo "  3. Install dependencies:"
echo "     make install"
echo ""
echo "  4. Start development environment:"
echo "     make dev"
echo ""
echo "URLs will be:"
echo "  Portal:          https://portal.hotosm.test"
echo "  Drone-TM:        https://dronetm.hotosm.test"
echo "  fAIr:            https://fair.hotosm.test"
echo "  OpenAerialMap:   https://openaerialmap.hotosm.test"
echo "  uMap:            https://umap.hotosm.test"
echo "  ChatMap:         https://chatmap.hotosm.test"
echo "  Tasking Mgr:     https://tm.hotosm.test"
echo "  Export Tool:     https://export-tool.hotosm.test"
echo "  Raw Data API:    https://raw-data-api.hotosm.test"
echo "  Hanko Auth:      https://login.hotosm.test"
echo "  MinIO Console:   https://minio.hotosm.test"
echo "  Traefik:         https://traefik.hotosm.test"
echo ""
