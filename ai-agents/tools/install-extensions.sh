#!/usr/bin/env bash
# install-extensions.sh — supply-chain-safe install of pi extension deps.
#
# Strict-pin install:
#   - `npm ci`         enforces package-lock.json exactly (no resolution drift)
#   - `--omit=dev`     skip dev deps
#   - `--ignore-scripts` block install/postinstall hooks (verified: no dep needs them)
# Then verify signatures via `npm audit signatures --omit=dev`.
#
# Run after a fresh clone or after lockfile updates.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

EXTS=(
	"$HOME_MIRROR/.pi/agent/extensions/browser-read"
	"$HOME_MIRROR/.pi/agent/extensions/mcp-bridge"
)

fail=0
for ext in "${EXTS[@]}"; do
	[ -d "$ext" ] || { warn "missing: $ext"; continue; }
	[ -f "$ext/package-lock.json" ] || { warn "no lockfile: $ext"; fail=1; continue; }
	echo
	echo "=== $ext ==="
	# `npm ci` deletes node_modules then installs strictly from lockfile.
	# Integrity (sha512) is verified for every fetched tarball.
	( cd "$ext" && npm ci --omit=dev --ignore-scripts )
	# Provenance check. Non-fatal warning if registry doesn't have signatures.
	( cd "$ext" && npm audit signatures --omit=dev ) || warn "signature audit had findings in $ext"
done

[ "$fail" -eq 0 ] || die "install-extensions: failures above"
log
log "done."
