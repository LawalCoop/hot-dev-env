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
    "127.0.0.1 fair.hotosm.test"
    "127.0.0.1 openaerialmap.hotosm.test"
    "127.0.0.1 umap.hotosm.test"
    "127.0.0.1 chatmap.hotosm.test"
    "127.0.0.1 login.hotosm.test"
    "127.0.0.1 mail.hotosm.test"
    "127.0.0.1 minio.hotosm.test"
    "127.0.0.1 s3.hotosm.test"
    "127.0.0.1 traefik.hotosm.test"
)

MISSING_ENTRIES=()

for entry in "${HOSTS_ENTRIES[@]}"; do
    # Extract just the hostname (second part after the IP)
    hostname=$(echo "$entry" | awk '{print $2}')

    # Check if hostname exists in hosts file (with sudo if needed on Linux/macOS)
    if [[ "$IS_WINDOWS" = false ]]; then
        if ! sudo grep -q "$hostname" "$HOSTS_FILE" 2>/dev/null; then
            MISSING_ENTRIES+=("$entry")
        fi
    else
        # Windows - no sudo needed
        if ! grep -q "$hostname" "$HOSTS_FILE" 2>/dev/null; then
            MISSING_ENTRIES+=("$entry")
        fi
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
    # Linux/macOS - offer to add automatically
    echo "Would you like to add them automatically? (requires sudo)"
    echo ""
    read -p "Add entries to $HOSTS_FILE? (y/N): " -n 1 -r
    echo ""
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Adding entries to $HOSTS_FILE..."
        echo ""

        # Create temporary file with entries
        TMP_FILE=$(mktemp)
        for entry in "${MISSING_ENTRIES[@]}"; do
            echo "$entry" >> "$TMP_FILE"
        done

        # Append to hosts file with sudo
        sudo bash -c "cat $TMP_FILE >> $HOSTS_FILE"

        # Clean up temp file
        rm "$TMP_FILE"

        if [[ $? -eq 0 ]]; then
            echo "✓ Entries added successfully!"
            echo ""

            # Flush DNS cache
            if [[ "$OSTYPE" == "darwin"* ]]; then
                echo "Flushing DNS cache..."
                sudo dscacheutil -flushcache
                sudo killall -HUP mDNSResponder 2>/dev/null
                echo "✓ DNS cache flushed"
            elif command -v systemctl &> /dev/null; then
                echo "Flushing DNS cache..."
                sudo systemctl restart systemd-resolved 2>/dev/null || true
                echo "✓ DNS cache flushed"
            fi
            echo ""
        else
            echo "✗ Failed to add entries"
            echo ""
            echo "Please add them manually to $HOSTS_FILE:"
            for entry in "${MISSING_ENTRIES[@]}"; do
                echo "  $entry"
            done
            echo ""
        fi
    else
        echo "Entries not added. To add them manually, run:"
        echo ""
        echo "  sudo bash -c 'cat >> $HOSTS_FILE << EOF"
        for entry in "${MISSING_ENTRIES[@]}"; do
            echo "$entry"
        done
        echo "EOF'"
        echo ""
    fi
fi
