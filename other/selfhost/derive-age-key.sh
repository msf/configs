#!/bin/bash
# Derive deterministic age identity from SSH key
set -euo pipefail

SSH_KEY="${HOME}/.ssh/id_ed25519"

if [ ! -f "$SSH_KEY" ]; then
    echo "ERROR: SSH key not found: $SSH_KEY"
    exit 1
fi

# Generate deterministic age key from SSH key hash
ssh-keygen -f "$SSH_KEY" -y | sha256sum | awk '{print $1}' | \
    xxd -r -p | age-keygen -o /dev/stdout 2>/dev/null || \
    (sha256sum "$SSH_KEY" | awk '{print "age-secret-key:" $1}')
