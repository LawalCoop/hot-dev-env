#!/bin/bash
# Add .local domains to /etc/hosts for HOTOSM development

echo "Adding .local domains to /etc/hosts..."

# Check if entries already exist
if grep -q "portal.local" /etc/hosts; then
    echo "✓ .local domains already exist in /etc/hosts"
else
    echo "127.0.0.1 portal.local login.local dronetm.local minio.local nodeodm.local traefik.local" | sudo tee -a /etc/hosts
    echo "✓ Added .local domains to /etc/hosts"
fi

echo ""
echo "You can now access:"
echo "  - http://portal.local"
echo "  - http://login.local"
echo "  - http://dronetm.local"
echo "  - http://minio.local"
echo "  - http://nodeodm.local"
echo "  - http://traefik.local"
