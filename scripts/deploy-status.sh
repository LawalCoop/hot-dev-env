#!/bin/bash

# Deploy Status Dashboard - Shows CI/CD status for all HOTOSM apps
# Requires: gh CLI authenticated, jq, gum (auto-installed)

# ============================================================================
# Auto-install gum if not present
# ============================================================================

install_gum() {
    echo "Installing gum for beautiful CLI output..."
    echo ""

    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            brew install gum
        else
            echo "Homebrew not installed. Install from https://brew.sh"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt &> /dev/null; then
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
            echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
            sudo apt update && sudo apt install -y gum
        else
            echo "apt not available. Install gum manually: https://github.com/charmbracelet/gum"
            exit 1
        fi
    else
        echo "Unsupported OS. Install gum manually: https://github.com/charmbracelet/gum"
        exit 1
    fi

    echo ""
    echo "gum installed successfully!"
    echo ""
}

# ============================================================================
# Check dependencies
# ============================================================================

check_deps() {
    if ! command -v gh &> /dev/null; then
        echo "gh CLI not installed. Install from https://cli.github.com/"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        echo "jq not installed."
        echo "   Mac:   brew install jq"
        echo "   Linux: sudo apt install jq"
        exit 1
    fi

    if ! gh auth status &> /dev/null; then
        echo "gh CLI not authenticated. Run: gh auth login"
        exit 1
    fi

    if ! command -v gum &> /dev/null; then
        install_gum
    fi
}

# ============================================================================
# Data Fetching
# ============================================================================

get_status() {
    local repo="$1"
    local branch="$2"

    local result=$(gh run list -R "$repo" --branch "$branch" -L 1 --json status,conclusion,createdAt,databaseId 2>/dev/null)

    if [ -z "$result" ] || [ "$result" = "[]" ]; then
        echo "none||"
        return
    fi

    local status=$(echo "$result" | jq -r '.[0].status // "unknown"')
    local conclusion=$(echo "$result" | jq -r '.[0].conclusion // ""')
    local created=$(echo "$result" | jq -r '.[0].createdAt // ""')
    local run_id=$(echo "$result" | jq -r '.[0].databaseId // ""')

    local time_str=""
    if [ -n "$created" ]; then
        time_str=$(date -d "$created" +"%Y-%m-%d %H:%M" 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$created" +"%Y-%m-%d %H:%M" 2>/dev/null || echo "")
    fi

    if [ "$status" = "completed" ]; then
        if [ "$conclusion" = "success" ]; then
            echo "success|$time_str|$run_id"
        else
            echo "failure|$time_str|$run_id"
        fi
    elif [ "$status" = "in_progress" ] || [ "$status" = "queued" ]; then
        echo "running|$time_str|$run_id"
    else
        echo "none||"
    fi
}

# ============================================================================
# Dashboard Display
# ============================================================================

declare -a FAILED_RUNS

print_card() {
    local app="$1"
    local dev_data="$2"
    local prod_data="$3"
    local dev_url="$4"
    local prod_url="$5"
    local dev_repo="$6"
    local prod_repo="$7"

    local dev_status=$(echo "$dev_data" | cut -d'|' -f1)
    local dev_time=$(echo "$dev_data" | cut -d'|' -f2)
    local dev_run_id=$(echo "$dev_data" | cut -d'|' -f3)

    local prod_status=$(echo "$prod_data" | cut -d'|' -f1)
    local prod_time=$(echo "$prod_data" | cut -d'|' -f2)
    local prod_run_id=$(echo "$prod_data" | cut -d'|' -f3)

    # Determine card color based on status
    local border_color="240"  # gray default

    if [ "$dev_status" = "failure" ] || [ "$prod_status" = "failure" ]; then
        border_color="196"  # red
    elif [ "$dev_status" = "running" ] || [ "$prod_status" = "running" ]; then
        border_color="220"  # yellow
    elif [ "$dev_status" = "success" ] || [ "$prod_status" = "success" ]; then
        border_color="82"   # green
    fi

    # Track failures
    if [ "$dev_status" = "failure" ] && [ -n "$dev_run_id" ]; then
        FAILED_RUNS+=("$app|dev|$dev_repo|$dev_run_id")
    fi
    if [ "$prod_status" = "failure" ] && [ -n "$prod_run_id" ]; then
        FAILED_RUNS+=("$app|prod|$prod_repo|$prod_run_id")
    fi

    # Build status icons
    local dev_icon prod_icon
    case "$dev_status" in
        "success") dev_icon="✓" ;;
        "failure") dev_icon="✗" ;;
        "running") dev_icon="◐" ;;
        *) dev_icon="○" ;;
    esac

    case "$prod_status" in
        "success") prod_icon="✓" ;;
        "failure") prod_icon="✗" ;;
        "running") prod_icon="◐" ;;
        *) prod_icon="○" ;;
    esac

    # Format dev line
    local dev_line
    if [ "$dev_url" != "—" ]; then
        dev_line="DEV  $dev_icon  $dev_url"
        [ -n "$dev_time" ] && dev_line="$dev_line\n     $dev_time"
    else
        dev_line="DEV  ○  —"
    fi

    # Format prod line
    local prod_line
    if [ "$prod_url" != "—" ]; then
        prod_line="PROD $prod_icon  $prod_url"
        [ -n "$prod_time" ] && prod_line="$prod_line\n     $prod_time"
    else
        prod_line="PROD ○  —"
    fi

    # Build card content with fixed width
    printf "%s\n%s\n%b\n\n%b" \
        "$app" \
        "───────────────────────────────" \
        "$dev_line" \
        "$prod_line" | gum style \
            --border rounded \
            --border-foreground "$border_color" \
            --padding "1 2" \
            --width 42
}

fetch_and_show() {
    local app="$1"
    local dev_repo="$2"
    local dev_branch="$3"
    local prod_repo="$4"
    local prod_branch="$5"
    local dev_url="$6"
    local prod_url="$7"

    # Show fetching indicator
    printf "  Fetching %-20s" "$app..."

    # Fetch dev status
    local dev_data="none||"
    if [ -n "$dev_repo" ] && [ "$dev_repo" != "—" ]; then
        dev_data=$(get_status "$dev_repo" "$dev_branch")
    fi

    # Fetch prod status
    local prod_data="none||"
    if [ -n "$prod_repo" ] && [ "$prod_repo" != "—" ]; then
        prod_data=$(get_status "$prod_repo" "$prod_branch")
    fi

    # Clear the "Fetching..." line
    printf "\r\033[K"

    # Show the card
    print_card "$app" "$dev_data" "$prod_data" "$dev_url" "$prod_url" "$dev_repo" "$prod_repo"
    echo ""
}

show_dashboard() {
    clear
    echo ""

    # Header
    gum style \
        --foreground 212 \
        --bold \
        --align center \
        --width 80 \
        "HOTOSM Deploy Status"

    gum style --foreground 240 --align center --width 80 "$(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo ""

    # Fetch and display each app progressively
    fetch_and_show "Portal" \
        "hotosm/portal" "develop" \
        "hotosm/portal" "main" \
        "dev.portal.hotosm.org" "portal.hotosm.org"

    fetch_and_show "Login" \
        "hotosm/login" "develop" \
        "hotosm/login" "main" \
        "dev.login.hotosm.org" "login.hotosm.org"

    fetch_and_show "Drone-TM" \
        "hotosm/drone-tm" "develop" \
        "hotosm/drone-tm" "main" \
        "testlogin.dronetm.hotosm.org" "dronetm.hotosm.org"

    fetch_and_show "fAIr" \
        "hotosm/fAIr" "login_hanko" \
        "hotosm/fAIr" "main" \
        "testlogin.fair.hotosm.org" "fair.hotosm.org"

    fetch_and_show "uMap" \
        "hotosm/umap" "login_hanko" \
        "" "" \
        "testlogin.umap.hotosm.org" "—"

    fetch_and_show "Export Tool" \
        "hotosm/osm-export-tool" "login_hanko" \
        "" "" \
        "testlogin.export.hotosm.org" "—"

    fetch_and_show "Tasking Manager" \
        "" "" \
        "hotosm/tasking-manager" "main" \
        "—" "tasks.hotosm.org"

    fetch_and_show "Raw Data API" \
        "hotosm/raw-data-api" "login_hanko" \
        "hotosm/raw-data-api" "main" \
        "dev.raw-data.hotosm.org" "api-prod.raw-data.hotosm.org"

    # Legend
    echo ""
    gum style --foreground 240 "  $(gum style --foreground 82 '✓') success   $(gum style --foreground 196 '✗') failed   $(gum style --foreground 220 '◐') running   $(gum style --foreground 240 '○') none"
    echo ""

    # Show failures if any
    if [ ${#FAILED_RUNS[@]} -gt 0 ]; then
        echo ""
        gum style \
            --border double \
            --border-foreground 196 \
            --padding "0 2" \
            --foreground 196 \
            --bold \
            "FAILED BUILDS"
        echo ""

        for failed in "${FAILED_RUNS[@]}"; do
            IFS='|' read -r name env repo run_id <<< "$failed"

            gum style --foreground 196 --bold "$name ($env)"
            gum style --foreground 240 "  repo: $repo  |  run: $run_id"
            echo ""

            # Get failed logs (last 25 lines)
            gh run view "$run_id" -R "$repo" --log-failed 2>&1 | tail -25 | while read -r line; do
                gum style --foreground 203 "  $line"
            done

            echo ""
            gum style --foreground 240 "─────────────────────────────────────────────────────────────────────────────"
            echo ""
        done
    fi

    echo ""
}

# ============================================================================
# Main
# ============================================================================

check_deps
show_dashboard
