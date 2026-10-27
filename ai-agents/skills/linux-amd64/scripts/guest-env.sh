#!/usr/bin/env bash
# guest-env.sh <cmd> [args...] — run a command inside the linux-amd64 guest with the
# provisioned toolchains on PATH. For projects on the Mac filesystem, Cargo output
# goes to a guest-native per-project directory instead of the shared ./target.
set -euo pipefail

export PATH="$HOME/.cargo/bin:/usr/local/go/bin:$HOME/go/bin:$PATH"

project_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)"
case "$project_root" in
  /Users/* | /Volumes/* | /mnt/mac/*)
    # Mac builds use ./target too; sharing it would mix host and guest artifacts
    # and run Cargo's file locking over virtiofs.
    slug="${project_root#/}"
    export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$HOME/.cache/amd64-target/${slug//\//_}}"
    ;;
esac

exec "$@"
