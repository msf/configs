#!/usr/bin/env bash
# Apply this host's local patches to installed Pi npm packages (tools/package-patches.txt).
#
# Idempotent. A reinstall or `pi update` replaces the package files; re-running apply.sh
# restores the patch while the installed version still equals the entry's base version.
#
# Usage:
#   tools/package-patches.sh              # apply
#   tools/package-patches.sh --dry-run    # show what would happen
#   tools/package-patches.sh --verify     # print problems (exit 1 if any)
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MODE=apply
case ${1:-} in
	"") ;;
	--dry-run) DRY_RUN=1 ;;
	--verify) MODE=verify ;;
	-h|--help) sed -n '2,11p' "$0"; exit 0 ;;
	*) die "unknown argument: $1" ;;
esac

PATCHES=${PACKAGE_PATCHES:-$TOOLS_DIR/package-patches.txt}
NPM_DIR=${PI_NPM_DIR:-$HOME/.pi/agent/npm/node_modules}
[ -r "$PATCHES" ] || exit 0

problems=0
problem() { warn "$*"; problems=$((problems+1)); }

installed_version() {
	sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$1/package.json" | head -n 1
}

apply_patch() {
	local package=$1 base=$2 patch=$TOOLS_DIR/patches/$3
	local dir=$NPM_DIR/$package version
	[ -r "$patch" ] || { problem "$package: patch file missing: $patch"; return; }
	[ -d "$dir" ] || { log "skip $package (not installed)"; return; }
	version=$(installed_version "$dir")

	if patch -p1 -R --dry-run -s -d "$dir" < "$patch" >/dev/null 2>&1; then
		[ "$MODE" = verify ] || log "ok   $package $version patched"
		return
	fi
	if [ "$version" != "$base" ]; then
		problem "$package: installed $version, patch is for $base; check upstream, then drop or rebase tools/patches/$3"
		return
	fi
	if ! patch -p1 --dry-run -s -d "$dir" < "$patch" >/dev/null 2>&1; then
		problem "$package $version: $3 neither applied nor applicable (package files modified?)"
		return
	fi
	if [ "$MODE" = verify ]; then
		problem "$package $version: $3 not applied; run tools/apply.sh"
		return
	fi
	if [ "$DRY_RUN" = 1 ]; then
		log "DRY  patch $package $version with $3"
		return
	fi
	patch -p1 -s -d "$dir" < "$patch"
	log "RUN  patched $package $version with $3"
}

while read -r host package base file _; do
	case $host in ''|'#'*) continue ;; esac
	[ "$host" = "$AGENTS_HOST" ] || continue
	[ -n "${file:-}" ] || die "$PATCHES: expected <host> <package> <base-version> <patch-file>"
	apply_patch "$package" "$base" "$file"
done < "$PATCHES"

[ "$problems" -eq 0 ] || { [ "$MODE" != verify ] || exit 1; }
