#!/usr/bin/env bash
# verify-lockfile-age.sh — fail if any package in a lockfile was published
# less than $MIN_AGE_DAYS ago. Run before committing a lockfile change.
#
# Threat model: npm-supply-chain attacks typically rely on a malicious version
# being pulled into your tree quickly. A simple age gate gives the wider
# community + npm itself time to flag/yank.
#
# Usage:
#   tools/verify-lockfile-age.sh                       # check both pi extensions
#   tools/verify-lockfile-age.sh <lockfile.json>       # check a specific lockfile
#   MIN_AGE_DAYS=14 tools/verify-lockfile-age.sh       # override threshold (default: 7)
#
# Requires: jq, curl.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MIN_AGE_DAYS=${MIN_AGE_DAYS:-7}
REGISTRY=${NPM_REGISTRY:-https://registry.npmjs.org}

LOCKS=()
if [ $# -gt 0 ]; then
	LOCKS=("$@")
else
	LOCKS=(
		"$HOME_MIRROR/.pi/agent/extensions/browser-read/package-lock.json"
		"$HOME_MIRROR/.pi/agent/extensions/mcp-bridge/package-lock.json"
	)
fi

command -v jq   >/dev/null || die "jq required"
command -v curl >/dev/null || die "curl required"

now_epoch=$(date -u +%s)
threshold_secs=$(( MIN_AGE_DAYS * 86400 ))

fail=0
checked=0
youngest_pkg=""
youngest_age=999999

for lock in "${LOCKS[@]}"; do
	[ -r "$lock" ] || { warn "unreadable: $lock"; fail=1; continue; }
	log "=== $lock  (min age: ${MIN_AGE_DAYS}d) ==="
	# Build a list of "name<TAB>version" pairs from .packages, deduplicated.
	# Skip the root entry (key "") and workspace-local entries (no resolved url).
	while IFS=$'\t' read -r name version; do
		[ -n "$name" ] && [ -n "$version" ] || continue
		# Encode scoped names: @scope/pkg → @scope%2Fpkg
		enc=${name//\//%2F}
		# /<pkg> manifest .time has all version dates including "created"/"modified"
		published=$(curl -fsS "$REGISTRY/$enc" 2>/dev/null \
			| jq -r --arg v "$version" '.time[$v] // empty' || true)
		if [ -z "$published" ]; then
			warn "no publish date: $name@$version (skipped)"
			continue
		fi
		pub_epoch=$(date -u -d "$published" +%s 2>/dev/null || echo 0)
		[ "$pub_epoch" -gt 0 ] || { warn "unparseable date for $name@$version: $published"; continue; }
		age=$(( now_epoch - pub_epoch ))
		age_days=$(( age / 86400 ))
		checked=$((checked+1))
		if [ "$age_days" -lt "$youngest_age" ]; then
			youngest_age=$age_days
			youngest_pkg="$name@$version"
		fi
		if [ "$age" -lt "$threshold_secs" ]; then
			printf 'TOO NEW  %-50s  published %s  (%dd ago)\n' "$name@$version" "$published" "$age_days"
			fail=1
		fi
	done < <(
		jq -r '
			.packages
			| to_entries[]
			| select(.key != "" and (.value.resolved // "") != "")
			| ((.value.name // (.key | sub("^.*node_modules/"; ""))) as $n
			   | "\($n)\t\(.value.version)")
		' "$lock" | sort -u
	)
done

log
log "checked $checked package versions; youngest: $youngest_pkg ($youngest_age days)"
if [ "$fail" -ne 0 ]; then
	die "verify-lockfile-age: at least one package is newer than ${MIN_AGE_DAYS} days"
fi
log "ok: all packages older than ${MIN_AGE_DAYS} days"
