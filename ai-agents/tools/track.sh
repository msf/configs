#!/usr/bin/env bash
# track.sh [--private] <path>  — start tracking a new file or directory.
#
# Default: `mirror` entry in the public tree ($ROOT/home/<rel>).
# --private: `pmirror` entry in the private repo ($PRIVATE_DIR/home/<rel>).
#   Use --private for anything with internal endpoints, org/team identity,
#   schemas, or infra topology. Filenames may still appear in the public
#   manifest — contents never do.
#
# <path> can be absolute (under $HOME) or relative to $HOME.
# Steps (all idempotent-friendly, backs up before moving):
#   1. Compute target path under the chosen mirror root
#   2. Backup $HOME/<rel>
#   3. Move $HOME/<rel> into the mirror
#   4. Symlink it back
#   5. Append manifest entry if not already present
#
# Usage:
#   tools/track.sh ~/.pi/agent/extensions/foo.ts
#   tools/track.sh --private ~/.config/some-internal.conf
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

KIND=mirror
MIRROR_ROOT=$HOME_MIRROR
if [ "${1:-}" = --private ]; then
	KIND=pmirror
	MIRROR_ROOT=$PRIVATE_MIRROR
	shift
fi
[ $# -eq 1 ] || die "usage: tools/track.sh [--private] <path>"
input=$1

# Normalize to a path relative to $HOME.
case "$input" in
	/*)
		case "$input" in
			"$HOME"/*) rel=${input#$HOME/} ;;
			*) die "path must be under \$HOME: $input" ;;
		esac
		;;
	*) rel=$input ;;
esac

h=$HOME/$rel
r=$MIRROR_ROOT/$rel

[ -e "$h" ] || [ -L "$h" ] || die "no such path: $h"
[ -L "$h" ] && die "already a symlink: $h"

if grep -qE "^[[:space:]]*p?mirror[[:space:]]+${rel//\//\\/}([[:space:]]|$)" "$MANIFEST"; then
	warn "already in manifest: $rel"
fi

run mkdir -p -- "$(dirname "$r")"
if [ -e "$r" ] || [ -L "$r" ]; then
	backup "$r"
	run rm -rf -- "$r"
fi
backup "$h"
run mv -- "$h" "$r"
run ln -s -- "$r" "$h"

if ! grep -qE "^[[:space:]]*p?mirror[[:space:]]+${rel//\//\\/}([[:space:]]|$)" "$MANIFEST"; then
	printf '%s  %s\n' "$KIND" "$rel" >> "$MANIFEST"
	log "manifest: appended  $KIND  $rel"
fi

log "tracked: $h  →  $r"
if [ "$KIND" = pmirror ]; then
	log "next:    git -C $PRIVATE_DIR add home/$rel   # and commit the manifest in the public repo"
else
	log "next:    git -C $REPO_DIR add ${ROOT_DIR#$REPO_DIR/}/home/$rel ${ROOT_DIR#$REPO_DIR/}/tools/manifest.txt"
fi
