#!/bin/bash
# Encrypt secrets for git
set -euo pipefail

cd "$(dirname "$0")"

AGE_KEY="$HOME/.age-key.txt"
if [ ! -f "$AGE_KEY" ]; then
    echo "ERROR: Age key not found at $AGE_KEY"
    echo "Generate with: age-keygen -o ~/.age-key.txt"
    exit 1
fi

echo "Collecting secrets..."
tar czf secrets.tar \
    caddy/env \
    ddns/env \
    immich/env

echo "Encrypting with age..."
age -r $(age-keygen -y "$AGE_KEY") -o secrets.tar.age secrets.tar

echo "Cleaning up plaintext archive..."
rm secrets.tar

echo ""
echo "✓ Encrypted: secrets.tar.age"
echo "  This file is safe to commit to git"
echo ""
echo "To decrypt: ./deploy.sh"
