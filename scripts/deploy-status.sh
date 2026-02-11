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

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq not installed."
    echo "  Linux:   sudo apt install jq"
    echo "  Mac:     brew install jq"
    echo "  Windows: winget install jqlang.jq"
    exit 1
fi

# Check if gh is authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: gh CLI not authenticated${NC}"
    echo "Run: gh auth login"
    exit 1
fi

# Spinner animation
spinner() {
    local pid=$1
    local name=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while kill -0 $pid 2>/dev/null; do
        printf "\r  %-15s ${YELLOW}%s${NC} loading..." "$name" "${spin:i++%${#spin}:1}"
        sleep 0.1
    done
    printf "\r%-50s\r" ""  # Clear the line
}

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
            echo -e "${YELLOW}~ running${NC}"
            ;;
        "queued")
            echo -e "${YELLOW}~ queued${NC}"
            ;;
        *)
            echo "$status"
            ;;
    esac
}

# Function to get workflow status (returns short status)
get_workflow_status() {
    local repo="$1"
    local workflow="$2"

    local result=$(gh run list -R "$repo" --workflow "$workflow" -L 1 --json status,conclusion 2>/dev/null)

    if [ -z "$result" ] || [ "$result" = "[]" ]; then
        echo -e "${GRAY}-${NC}"
        return
    fi

    local status=$(echo "$result" | jq -r '.[0].status // "unknown"')
    local conclusion=$(echo "$result" | jq -r '.[0].conclusion // ""')

    if [ "$status" = "completed" ]; then
        if [ "$conclusion" = "success" ]; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
        fi
    elif [ "$status" = "in_progress" ] || [ "$status" = "queued" ]; then
        echo -e "${YELLOW}~${NC}"
    else
        echo -e "${GRAY}-${NC}"
    fi
}

# Function to check login prod with multiple workflows
check_login_prod() {
    local name="$1"
    local env_name="$2"

    # Get both statuses
    local img_status=$(get_workflow_status "hotosm/login" "build-prod.yml")
    local chart_status=$(get_workflow_status "hotosm/login" "release-chart.yml")

    # Get latest time from build-prod workflow
    local result=$(gh run list -R "hotosm/login" --workflow "build-prod.yml" -L 1 --json createdAt 2>/dev/null)
    local time_ago=""
    if [ -n "$result" ] && [ "$result" != "[]" ]; then
        local created=$(echo "$result" | jq -r '.[0].createdAt // ""')
        if [ -n "$created" ]; then
            time_ago=$(date -d "$created" +"%d/%m %H:%M" 2>/dev/null || echo "")
        fi
    fi

    # Use placeholder if no time
    if [ -z "$time_ago" ]; then
        time_ago="-"
    fi

    local combined_status="i:${img_status} c:${chart_status}"
    printf "  %-15s %-40s %-14s %s\n" "$name" "$combined_status" "$time_ago" "$env_name"
}

# Function to check a repo
check_repo() {
    local name="$1"
    local repo="$2"
    local branch="$3"
    local env_name="$4"

    # Get latest run with spinner
    local tmpfile=$(mktemp)
    gh run list -R "$repo" --branch "$branch" -L 1 --json status,conclusion,name,createdAt,databaseId 2>/dev/null > "$tmpfile" &
    local pid=$!
    spinner $pid "$name"
    wait $pid
    local result=$(cat "$tmpfile")
    rm -f "$tmpfile"

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

    # Format time (date + hour)
    local time_ago=""
    if [ -n "$created" ]; then
        time_ago=$(date -d "$created" +"%d/%m %H:%M" 2>/dev/null || echo "")
    fi

    local formatted_status=$(format_status "$final_status")
    # ANSI codes add ~11 chars, so we use 31 instead of 20 for alignment
    printf "  %-15s %-31s %-14s %s\n" "$name" "$formatted_status" "$time_ago" "$env_name"
}

echo ""
printf "  %-15s %-20s %-14s %s\n" "APP" "STATUS" "TIME" "ENVIRONMENT"
echo "  ───────────────────────────────────────────────────────────────────────────"

# Check each app - adjust branches as needed
check_repo "Portal" "hotosm/portal" "develop" "portal.hotosm.org"
check_repo "Login (dev)" "hotosm/login" "develop" "dev.login.hotosm.org"
check_login_prod "Login (prod)" "login.hotosm.org"
check_repo "Drone-TM" "hotosm/drone-tm" "login-hanko" "testlogin.dronetm.hotosm.org"
check_repo "fAIr" "hotosm/fAIr" "login_hanko" "testlogin.fair.hotosm.org"
check_repo "uMap" "hotosm/umap" "login_hanko" "testlogin.umap.hotosm.org"
check_repo "ChatMap" "hotosm/chatmap" "develop" "chatmap-dev.hotosm.org"
check_repo "OAM" "hotosm/openaerialmap" "login_hanko" "—"
check_repo "Export Tool" "hotosm/osm-export-tool" "login_hanko" "testlogin.export.hotosm.org"
check_repo "Raw Data API" "hotosm/raw-data-api" "main" "api-prod.raw-data.hotosm.org"
check_repo "Tasking Mgr" "hotosm/tasking-manager" "main" "tasks.hotosm.org"

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
