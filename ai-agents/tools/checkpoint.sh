#!/usr/bin/env bash
# checkpoint.sh — pull drift from $HOME back into the repo.
#
# For each `mirror` / `pmirror` manifest entry:
#   - If $HOME/<path> is already a symlink pointing at the repo entry → in sync, skip.
#   - If $HOME/<path> exists as a regular file/dir → copy it back into the repo,
#     backing up the repo's previous version to <repo-path>.bak.<TS>.
#   - If $HOME/<path> is missing → warn (machine doesn't have this).
#
# Does NOT process `repo`/`prepo`/`home` entries — those are symlink edges, not data.
#
# Usage:
#   tools/checkpoint.sh                  # apply
#   tools/checkpoint.sh --dry-run        # show what would happen
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

for arg in "$@"; do
	case $arg in
		--dry-run) DRY_RUN=1 ;;
		-h|--help) sed -n '2,15p' "$0"; exit 0 ;;
		*) die "unknown arg: $arg" ;;
	esac
done

checkpoint_one() {
	local type=$1 path=$2
	local r
	case "$type" in
		mirror)  r=$HOME_MIRROR/$path ;;
		pmirror) r=$PRIVATE_MIRROR/$path ;;
		*) return 0 ;;
	esac

	local h=$HOME/$path

	if [ ! -e "$h" ] && [ ! -L "$h" ]; then
		warn "missing on this machine: $h"
		return
	fi

	if [ -L "$h" ]; then
		local cur
		cur=$(readlink -- "$h")
		if [ "$cur" = "$r" ]; then
			log "sync $h"
			return
		fi
		warn "foreign symlink at $h -> $cur  (skipping; resolve manually)"
		return
	fi

	# Regular file or dir at $h — drift case. Pull it in.
	log "drift $h  →  $r"
	if [ -e "$r" ] || [ -L "$r" ]; then
		backup "$r"
		run rm -rf -- "$r"
	fi
	run mkdir -p -- "$(dirname "$r")"
	run cp -a --no-target-directory "$h" "$r"
}

foreach_manifest checkpoint_one
