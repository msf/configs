#!/usr/bin/env bash
# apply.sh — recreate symlinks from manifest into $HOME.
#
# Idempotent: re-running on a synced machine is a no-op.
# Safe:      anything in $HOME that would be displaced is backed up to <path>.bak.<TS>.
# Deterministic: order of operations follows manifest order; same input → same output.
#
# Usage:
#   tools/apply.sh                  # apply
#   tools/apply.sh --dry-run        # show what would happen, change nothing
#   tools/apply.sh --verify         # print only mismatches (exit 1 if any)
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MODE=apply
for arg in "$@"; do
	case $arg in
		--dry-run) DRY_RUN=1 ;;
		--verify)  MODE=verify ;;
		-h|--help) sed -n '2,15p' "$0"; exit 0 ;;
		*) die "unknown arg: $arg" ;;
	esac
done

mismatches=0

apply_one() {
	local type=$1 path=$2 arg2=${3:-}
	local target h
	target=$(resolve_target "$type" "$path" "$arg2")
	h=$HOME/$path

	# Source must exist for mirror/repo; for home it's another $HOME path which
	# should exist after earlier entries in manifest.
	if [ ! -e "$target" ] && [ ! -L "$target" ]; then
		warn "source missing: $target  (entry: $type $path $arg2)"
		mismatches=$((mismatches+1))
		return
	fi

	# Already correct?
	if [ -L "$h" ]; then
		local cur
		cur=$(readlink -- "$h")
		if [ "$cur" = "$target" ]; then
			[ "$MODE" = verify ] || log "ok   $h"
			return
		fi
	fi

	if [ "$MODE" = verify ]; then
		log "DIFF $h  (want: $target;  have: $(readlink -- "$h" 2>/dev/null || echo "<regular file/dir>"))"
		mismatches=$((mismatches+1))
		return
	fi

	# Need to (re)create. Back up any existing thing first.
	if [ -L "$h" ] || [ -e "$h" ]; then
		backup "$h"
		run rm -rf -- "$h"
	fi
	run mkdir -p -- "$(dirname "$h")"
	run ln -s -- "$target" "$h"
}

foreach_manifest apply_one

if [ "$MODE" = verify ]; then
	[ "$mismatches" -eq 0 ] || exit 1
fi
