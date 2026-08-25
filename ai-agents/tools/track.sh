#!/usr/bin/env bash
# track.sh [--private] <path> — start tracking a new managed path.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PRIVATE=0
if [ "${1:-}" = --private ]; then
	PRIVATE=1
	shift
fi
[ $# -eq 1 ] || die "usage: tools/track.sh [--private] <path>"
input=$1

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
[ -e "$h" ] || [ -L "$h" ] || die "no such path: $h"
[ -L "$h" ] && die "already a symlink: $h"

kind=mirror
target=$HOME_MIRROR/$rel
manifest_target=

if [ "$PRIVATE" = 1 ]; then
	kind=pmirror
	target=$PRIVATE_MIRROR/$rel
	case "$rel" in
		.pi/agent/skills/*)
			suffix=${rel#.pi/agent/skills/}
			kind=prepo; manifest_target=skills/$suffix; target=$PRIVATE_DIR/$manifest_target ;;
		.pi/agent/agents/*)
			suffix=${rel#.pi/agent/agents/}
			kind=prepo; manifest_target=agents/pi/$suffix; target=$PRIVATE_DIR/$manifest_target ;;
		.pi/agent/extensions/*)
			suffix=${rel#.pi/agent/extensions/}
			kind=prepo; manifest_target=tools/extensions/$suffix; target=$PRIVATE_DIR/$manifest_target ;;
		.pi/agent/lessons.md)
			kind=prepo; manifest_target=lessons.md; target=$PRIVATE_DIR/$manifest_target ;;
	esac
else
	case "$rel" in
		.pi/agent/skills/*)
			suffix=${rel#.pi/agent/skills/}
			kind=repo; manifest_target=ai-agents/skills/$suffix; target=$REPO_DIR/$manifest_target ;;
		.pi/agent/agents/*)
			suffix=${rel#.pi/agent/agents/}
			kind=repo; manifest_target=ai-agents/agents/pi/$suffix; target=$REPO_DIR/$manifest_target ;;
		.pi/agent/prompts/*)
			suffix=${rel#.pi/agent/prompts/}
			kind=repo; manifest_target=ai-agents/commands/$suffix; target=$REPO_DIR/$manifest_target ;;
		.pi/agent/extensions/*)
			suffix=${rel#.pi/agent/extensions/}
			kind=repo; manifest_target=ai-agents/tools/extensions/$suffix; target=$REPO_DIR/$manifest_target ;;
		.pi/agent/bin/*)
			suffix=${rel#.pi/agent/bin/}
			kind=repo; manifest_target=ai-agents/tools/bin/$suffix; target=$REPO_DIR/$manifest_target ;;
	esac
fi

escaped_rel=${rel//\//\/}
manifest_pattern="^[[:space:]]*(mirror|pmirror|repo|prepo|home)[[:space:]]+${escaped_rel}([[:space:]]|$)"
if grep -qE "$manifest_pattern" "$MANIFEST"; then
	warn "already in manifest: $rel"
fi

run mkdir -p -- "$(dirname "$target")"
if [ -e "$target" ] || [ -L "$target" ]; then
	backup "$target"
	run rm -rf -- "$target"
fi
backup "$h"
run mv -- "$h" "$target"
run ln -s -- "$target" "$h"

if ! grep -qE "$manifest_pattern" "$MANIFEST"; then
	if [ -n "$manifest_target" ]; then
		printf '%-7s %s  %s\n' "$kind" "$rel" "$manifest_target" >> "$MANIFEST"
	else
		printf '%-7s %s\n' "$kind" "$rel" >> "$MANIFEST"
	fi
	log "manifest: appended $kind $rel${manifest_target:+ $manifest_target}"
fi

log "tracked: $h → $target"
log "next: commit $target and $MANIFEST in their owning repositories"
