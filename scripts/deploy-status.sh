#!/bin/bash

# Deploy Status - Shows latest CI/CD run for each HOTOSM app
# Requires: gh CLI authenticated

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Track failed runs
declare -a FAILED_RUNS

# Check if gh is available
if ! command -v gh &> /dev/null; then
    echo "Error: gh CLI not installed. Install from https://cli.github.com/"
    exit 1
fi

# Function to get status with color and emoji
format_status() {
    local status="$1"
    case "$status" in
        "completed")
            echo -e "${GREEN}✓ success${NC}"
            ;;
        "success")
            echo -e "${GREEN}✓ success${NC}"
            ;;
        "failure")
            echo -e "${RED}✗ failed${NC}"
            ;;
        "in_progress")
            echo -e "${YELLOW}⏳ running${NC}"
            ;;
        "queued")
            echo -e "${YELLOW}⏳ queued${NC}"
            ;;
        *)
            echo "$status"
            ;;
    esac
}

# Function to check a repo
check_repo() {
    local name="$1"
    local repo="$2"
    local branch="$3"
    local env_name="$4"

    # Get latest run
    local result=$(gh run list -R "$repo" --branch "$branch" -L 1 --json status,conclusion,name,createdAt,databaseId 2>/dev/null)

    if [ -z "$result" ] || [ "$result" = "[]" ]; then
        printf "  %-15s %-12s %s\n" "$name" "—" "No runs found on $branch"
        return
    fi

    local status=$(echo "$result" | jq -r '.[0].status // "unknown"')
    local conclusion=$(echo "$result" | jq -r '.[0].conclusion // ""')
    local workflow=$(echo "$result" | jq -r '.[0].name // "unknown"')
    local created=$(echo "$result" | jq -r '.[0].createdAt // ""')
    local run_id=$(echo "$result" | jq -r '.[0].databaseId // ""')

    # Determine final status
    local final_status
    if [ "$status" = "completed" ]; then
        final_status="$conclusion"
    else
        final_status="$status"
    fi

    # Track failures
    if [ "$final_status" = "failure" ]; then
        FAILED_RUNS+=("$name|$repo|$run_id")
    fi

    # Format time (relative)
    local time_ago=""
    if [ -n "$created" ]; then
        time_ago=$(date -d "$created" +"%H:%M" 2>/dev/null || echo "")
    fi

    local formatted_status=$(format_status "$final_status")
    printf "  %-15s %-20s %-10s %s\n" "$name" "$formatted_status" "$time_ago" "$env_name"
}

echo ""
printf "  %-15s %-20s %-10s %s\n" "APP" "STATUS" "TIME" "ENVIRONMENT"
echo "  ─────────────────────────────────────────────────────────────────"

# Check each app - adjust branches as needed
check_repo "Portal" "hotosm/portal" "develop" "portal.hotosm.org"
check_repo "Login" "hotosm/login" "develop" "dev.login.hotosm.org"
check_repo "Drone-TM" "hotosm/drone-tm" "login-hanko" "testlogin.dronetm.hotosm.org"
check_repo "fAIr" "hotosm/fAIr" "login_hanko" "—"
check_repo "OAM" "hotosm/openaerialmap" "login_hanko" "—"
check_repo "ChatMap" "hotosm/chatmap" "main" "—"

echo ""

# Show error details if there are failures
if [ ${#FAILED_RUNS[@]} -gt 0 ]; then
    echo -e "${RED}════════════════════════════════════════════════${NC}"
    echo -e "${RED}  Failed Build Logs${NC}"
    echo -e "${RED}════════════════════════════════════════════════${NC}"

    for failed in "${FAILED_RUNS[@]}"; do
        IFS='|' read -r name repo run_id <<< "$failed"
        echo ""
        echo -e "${RED}▶ $name${NC} (run $run_id)"
        echo -e "${GRAY}─────────────────────────────────────────${NC}"

        # Get failed logs (last 30 lines)
        gh run view "$run_id" -R "$repo" --log-failed 2>&1 | tail -30

        echo ""
    done
fi
