#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
source ~/.config/restic/env
exec python3 backup-to-restic.py
