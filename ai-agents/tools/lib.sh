# Shared helpers for apply.sh / checkpoint.sh / track.sh.
# Sourced, not executed. Assumes set -euo pipefail in caller.

# Resolve paths relative to this script's directory.
# Public root:  <configs repo>/ai-agents  (this tree — open source, no secrets,
#               no private-infra contents; private *filenames* may appear in the
#               manifest/.gitignore, that's deliberate and fine).
# Private root: ~/configs-private        (separate private repo — contents never
#               enter the public tree except as gitignored symlinks).
TOOLS_DIR=${TOOLS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
ROOT_DIR=$(cd "$TOOLS_DIR/.." && pwd)
REPO_DIR=$(cd "$ROOT_DIR/.." && pwd)
HOME_MIRROR=$ROOT_DIR/home
PRIVATE_DIR=${PRIVATE_DIR:-$HOME/configs-private}
PRIVATE_MIRROR=$PRIVATE_DIR/home
MANIFEST=$TOOLS_DIR/manifest.txt

TS=$(date +%Y%m%d-%H%M%S)
DRY_RUN=${DRY_RUN:-0}
BACKUP_ROOT=${BACKUP_ROOT:-$HOME/.agents-backup}

log()  { printf '%s\n' "$*"; }
warn() { printf 'warn: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

run() {
	if [ "$DRY_RUN" = 1 ]; then
		printf 'DRY  %s\n' "$*"
	else
		printf 'RUN  %s\n' "$*"
		"$@"
	fi
}

# Backup a path under $BACKUP_ROOT/<TS>/<orig-abs-path>.
# Out-of-tree on purpose: in-place .bak files inside tool-discovery dirs
# (pi/agent/extensions, skills, etc.) get loaded as duplicates. Keep them
# in a parallel tree the tools never scan. Idempotent for the same TS.
backup() {
	local p=$1
	[ -e "$p" ] || [ -L "$p" ] || return 0
	# rebuild absolute path: prefix BACKUP_ROOT/TS, then full path after $HOME or /
	local rel
	case "$p" in
		"$HOME"/*) rel=${p#$HOME/} ;;
		/*)        rel=ROOT${p} ;;
		*)         rel=$p ;;
	esac
	local bak=$BACKUP_ROOT/$TS/$rel
	if [ -e "$bak" ] || [ -L "$bak" ]; then return 0; fi
	run mkdir -p -- "$(dirname "$bak")"
	# cp -a preserves symlinks-as-symlinks, perms, timestamps
	run cp -a --no-target-directory "$p" "$bak"
}

# Iterate manifest entries. Calls $1 (a function name) with type, path, [arg2].
# Skips comments and blank lines.
foreach_manifest() {
	local fn=$1
	[ -r "$MANIFEST" ] || die "manifest not found: $MANIFEST"
	local type path arg2
	while IFS= read -r line || [ -n "$line" ]; do
		# strip leading whitespace and inline comments after content
		line=${line%%#*}
		# trim
		line=${line#"${line%%[![:space:]]*}"}
		line=${line%"${line##*[![:space:]]}"}
		[ -z "$line" ] && continue
		# split into up to 3 tokens
		read -r type path arg2 <<<"$line"
		[ -z "$type" ] && continue
		[ -z "$path" ] && die "manifest: missing path: $line"
		"$fn" "$type" "$path" "${arg2:-}"
	done < "$MANIFEST"
}

# Resolve the absolute target a manifest entry should point at.
resolve_target() {
	local type=$1 path=$2 arg2=${3:-}
	case "$type" in
		mirror)  printf '%s/%s\n' "$HOME_MIRROR" "$path" ;;
		pmirror) printf '%s/%s\n' "$PRIVATE_MIRROR" "$path" ;;
		repo)    [ -n "$arg2" ] || die "repo entry needs target: $path"
		         printf '%s/%s\n' "$REPO_DIR" "$arg2" ;;
		prepo)   [ -n "$arg2" ] || die "prepo entry needs target: $path"
		         printf '%s/%s\n' "$PRIVATE_DIR" "$arg2" ;;
		home)    [ -n "$arg2" ] || die "home entry needs target: $path"
		         printf '%s/%s\n' "$HOME" "$arg2" ;;
		*)       die "unknown manifest type: $type ($path)" ;;
	esac
}
