#!/bin/bash

echo "Checking /etc/hosts configuration..."

HOSTS_ENTRIES=(
    "127.0.0.1 portal.localhost"
    "127.0.0.1 dronetm.localhost"
    "127.0.0.1 login.localhost"
    "127.0.0.1 minio.localhost"
    "127.0.0.1 nodeodm.localhost"
    "127.0.0.1 traefik.localhost"
)

MISSING_ENTRIES=()

for entry in "${HOSTS_ENTRIES[@]}"; do
    if ! grep -q "$entry" /etc/hosts 2>/dev/null; then
        MISSING_ENTRIES+=("$entry")
    fi
done

if [[ ${#MISSING_ENTRIES[@]} -eq 0 ]]; then
    echo "  ✓ All /etc/hosts entries present"
    return 0 2>/dev/null || exit 0
fi

echo "  ⚠ Missing /etc/hosts entries:"
for entry in "${MISSING_ENTRIES[@]}"; do
    echo "    $entry"
done
echo ""
echo "To add them automatically, run:"
echo ""
echo "  sudo bash -c 'cat >> /etc/hosts << EOF"
for entry in "${MISSING_ENTRIES[@]}"; do
    echo "$entry"
done
echo "EOF'"
echo ""
echo "Or add them manually to /etc/hosts"
echo ""
