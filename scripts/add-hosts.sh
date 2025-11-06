#!/bin/bash

echo "Checking hosts file configuration..."

# Detect OS and set hosts file path
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
    # Windows
    HOSTS_FILE="/c/Windows/System32/drivers/etc/hosts"
    IS_WINDOWS=true
else
    # Linux and macOS
    HOSTS_FILE="/etc/hosts"
    IS_WINDOWS=false
fi

HOSTS_ENTRIES=(
    "127.0.0.1 portal.hotosm.test"
    "127.0.0.1 dronetm.hotosm.test"
    "127.0.0.1 login.hotosm.test"
    "127.0.0.1 minio.hotosm.test"
    "127.0.0.1 traefik.hotosm.test"
)

MISSING_ENTRIES=()

for entry in "${HOSTS_ENTRIES[@]}"; do
    if ! grep -q "$entry" "$HOSTS_FILE" 2>/dev/null; then
        MISSING_ENTRIES+=("$entry")
    fi
done

if [[ ${#MISSING_ENTRIES[@]} -eq 0 ]]; then
    echo "  ✓ All hosts file entries present"
    return 0 2>/dev/null || exit 0
fi

echo "  ⚠ Missing hosts file entries:"
for entry in "${MISSING_ENTRIES[@]}"; do
    echo "    $entry"
done
echo ""

if [ "$IS_WINDOWS" = true ]; then
    # Windows instructions
    echo "To add them on Windows:"
    echo ""
    echo "1. Open PowerShell or Command Prompt as Administrator"
    echo ""
    echo "2. Run this command:"
    echo ""
    echo "notepad C:\\Windows\\System32\\drivers\\etc\\hosts"
    echo ""
    echo "3. Add these lines at the end:"
    echo ""
    for entry in "${MISSING_ENTRIES[@]}"; do
        echo "$entry"
    done
    echo ""
    echo "4. Save and close Notepad"
    echo ""
else
    # Linux/macOS instructions
    echo "To add them automatically, run:"
    echo ""
    echo "  sudo bash -c 'cat >> $HOSTS_FILE << EOF"
    for entry in "${MISSING_ENTRIES[@]}"; do
        echo "$entry"
    done
    echo "EOF'"
    echo ""
    echo "Or add them manually to $HOSTS_FILE"
    echo ""
fi
