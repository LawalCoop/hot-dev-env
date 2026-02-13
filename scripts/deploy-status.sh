#!/bin/bash

# Deploy Status Dashboard - Shows CI/CD status for all HOTOSM apps
# Requires: gh CLI authenticated, jq, gum (auto-installed)

# ============================================================================
# Auto-install gum if not present
# ============================================================================

install_gum() {
    echo "📦 Installing gum for beautiful CLI output..."
    echo ""

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install gum
        else
            echo "❌ Homebrew not installed. Install from https://brew.sh"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Ubuntu/Debian
        if command -v apt &> /dev/null; then
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
            echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
            sudo apt update && sudo apt install -y gum
        else
            echo "❌ apt not available. Install gum manually: https://github.com/charmbracelet/gum"
            exit 1
        fi
    else
        echo "❌ Unsupported OS. Install gum manually: https://github.com/charmbracelet/gum"
        exit 1
    fi

    echo ""
    echo "✅ gum installed successfully!"
    echo ""
}

# ============================================================================
# Check dependencies
# ============================================================================

check_deps() {
    if ! command -v gh &> /dev/null; then
        echo "❌ gh CLI not installed. Install from https://cli.github.com/"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        echo "❌ jq not installed."
        echo "   Mac:   brew install jq"
        echo "   Linux: sudo apt install jq"
        exit 1
    fi

    if ! gh auth status &> /dev/null; then
        echo "❌ gh CLI not authenticated. Run: gh auth login"
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
        time_str=$(date -d "$created" +"%H:%M" 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$created" +"%H:%M" 2>/dev/null || echo "")
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

# Store failed runs for later
declare -a FAILED_RUNS

print_row() {
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

    # Track failures
    if [ "$dev_status" = "failure" ] && [ -n "$dev_run_id" ]; then
        FAILED_RUNS+=("$app (dev)|$dev_repo|$dev_run_id")
    fi
    if [ "$prod_status" = "failure" ] && [ -n "$prod_run_id" ]; then
        FAILED_RUNS+=("$app (prod)|$prod_repo|$prod_run_id")
    fi

    # Format dev status
    local dev_display
    case "$dev_status" in
        "success") dev_display=$(gum style --foreground 82 "✓ $dev_url") ;;
        "failure") dev_display=$(gum style --foreground 196 "✗ $dev_url") ;;
        "running") dev_display=$(gum style --foreground 220 "◐ $dev_url") ;;
        *) dev_display=$(gum style --foreground 240 "○ —") ;;
    esac

    # Format prod status
    local prod_display
    case "$prod_status" in
        "success") prod_display=$(gum style --foreground 82 "✓ $prod_url") ;;
        "failure") prod_display=$(gum style --foreground 196 "✗ $prod_url") ;;
        "running") prod_display=$(gum style --foreground 220 "◐ $prod_url") ;;
        *) prod_display=$(gum style --foreground 240 "○ —") ;;
    esac

    printf "  %-14s │ %-36s │ %-36s\n" "$app" "$dev_display" "$prod_display"
}

show_dashboard() {
    # Header
    echo ""
    gum style \
        --border double \
        --border-foreground 212 \
        --padding "0 2" \
        --margin "0 2" \
        --align center \
        "🚀 HOTOSM Deploy Status"

    echo ""

    # Fetch all statuses
    gum spin --spinner dot --title "Fetching deploy status..." -- sleep 0.3

    local portal_dev=$(get_status "hotosm/portal" "develop")
    local portal_prod=$(get_status "hotosm/portal" "main")
    local login_dev=$(get_status "hotosm/login" "develop")
    local login_prod=$(get_status "hotosm/login" "main")
    local drone_dev=$(get_status "hotosm/drone-tm" "develop")
    local drone_prod=$(get_status "hotosm/drone-tm" "main")
    local fair_dev=$(get_status "hotosm/fAIr" "login_hanko")
    local fair_prod=$(get_status "hotosm/fAIr" "main")
    local umap_dev=$(get_status "hotosm/umap" "login_hanko")
    local export_dev=$(get_status "hotosm/osm-export-tool" "login_hanko")
    local tm_prod=$(get_status "hotosm/tasking-manager" "main")
    local rawdata_prod=$(get_status "hotosm/raw-data-api" "main")

    # Table header
    echo ""
    gum style --foreground 255 --bold "  APP            │ DEVELOPMENT                          │ PRODUCTION"
    gum style --foreground 240 "  ───────────────┼──────────────────────────────────────┼──────────────────────────────────────"

    # Rows
    print_row "Portal" "$portal_dev" "$portal_prod" "dev.portal" "portal.hotosm.org" "hotosm/portal" "hotosm/portal"
    print_row "Login" "$login_dev" "$login_prod" "dev.login" "login.hotosm.org" "hotosm/login" "hotosm/login"
    print_row "Drone-TM" "$drone_dev" "$drone_prod" "testlogin.drone" "drone.hotosm.org" "hotosm/drone-tm" "hotosm/drone-tm"
    print_row "fAIr" "$fair_dev" "$fair_prod" "testlogin.fair" "fair.hotosm.org" "hotosm/fAIr" "hotosm/fAIr"
    print_row "uMap" "$umap_dev" "none||" "testlogin.umap" "—" "hotosm/umap" ""
    print_row "Export Tool" "$export_dev" "none||" "testlogin.export" "—" "hotosm/osm-export-tool" ""
    print_row "TM" "none||" "$tm_prod" "—" "tasks.hotosm.org" "" "hotosm/tasking-manager"
    print_row "Raw Data API" "none||" "$rawdata_prod" "—" "api-prod.raw-data" "" "hotosm/raw-data-api"

    echo ""
    gum style --foreground 240 "  ───────────────┴──────────────────────────────────────┴──────────────────────────────────────"

    # Legend
    echo ""
    echo "  $(gum style --foreground 82 '✓ success')  $(gum style --foreground 196 '✗ failed')  $(gum style --foreground 220 '◐ running')  $(gum style --foreground 240 '○ none')"
    echo ""

    # Show failures if any
    if [ ${#FAILED_RUNS[@]} -gt 0 ]; then
        echo ""
        gum style \
            --border normal \
            --border-foreground 196 \
            --padding "0 1" \
            --foreground 196 \
            "⚠️  Failed Builds"

        for failed in "${FAILED_RUNS[@]}"; do
            IFS='|' read -r name repo run_id <<< "$failed"
            echo ""
            gum style --foreground 196 --bold "▶ $name"
            gum style --foreground 240 "─────────────────────────────────────────"

            # Get failed logs (last 20 lines)
            gh run view "$run_id" -R "$repo" --log-failed 2>&1 | tail -20

            echo ""
        done
    fi
}

# ============================================================================
# Main
# ============================================================================

check_deps
show_dashboard
