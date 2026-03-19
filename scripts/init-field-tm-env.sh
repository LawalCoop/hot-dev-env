#!/bin/bash
# Creates ../field-tm/.env with shell expressions in .env.example evaluated
# to their actual default values, which Docker Compose requires as literals.
set -e

EXAMPLE="../field-tm/.env.example"
OUTPUT="../field-tm/.env"

if [ -f "$OUTPUT" ]; then
    echo "  ✓ ../field-tm/.env already exists"
    exit 0
fi

if [ ! -f "$EXAMPLE" ]; then
    echo "  ⚠ ../field-tm/.env.example not found"
    exit 0
fi

(
    cd "$(dirname "$EXAMPLE")"
    set -a
    source .env.example 2>/dev/null
    set +a
    grep -v '^[[:space:]]*#' .env.example \
        | grep -E '^[A-Za-z_]+=' \
        | cut -d= -f1 \
        | while read -r var; do
            printf '%s=%s\n' "$var" "$(eval printf '%s' "\$$var")"
        done
) > "$OUTPUT"

echo "  ✓ Created ../field-tm/.env (please review and update)"
