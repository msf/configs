#!/bin/bash
# Decrypt and deploy secrets
set -euo pipefail

cd "$(dirname "$0")"

AGE_KEY="$HOME/.age-key.txt"
if [ ! -f "$AGE_KEY" ]; then
    echo "ERROR: Age key not found at $AGE_KEY"
    echo "Copy it from your backup or original machine"
    exit 1
fi

if [ ! -f secrets.tar.age ]; then
    echo "ERROR: secrets.tar.age not found"
    exit 1
fi

echo "Decrypting secrets..."
age -d -i "$AGE_KEY" secrets.tar.age | tar xzf -

echo ""
echo "✓ Secrets decrypted to:"
echo "  - caddy/env"
echo "  - ddns/env"
echo "  - immich/env"
echo ""
echo "Deploy services with docker compose or service scripts"
