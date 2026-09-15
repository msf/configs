#!/usr/bin/env bash
# Manage stable Codex defaults without owning its machine-local config.toml.
set -euo pipefail

MODE=apply
case ${1:-} in
	"") ;;
	--dry-run) MODE=dry-run ;;
	--verify) MODE=verify ;;
	-h|--help)
		printf 'usage: %s [--dry-run|--verify]\n' "$0"
		exit 0
		;;
	*) printf 'error: unknown argument: %s\n' "$1" >&2; exit 1 ;;
esac

config=${CODEX_CONFIG_FILE:-$HOME/.codex/config.toml}
setting='project_doc_fallback_filenames = ["CLAUDE.md"]'
key_pattern='^[[:space:]]*project_doc_fallback_filenames[[:space:]]*='

if [ -f "$config" ] && grep -Eq "$key_pattern" "$config"; then
	if grep -Fxq "$setting" "$config"; then
		exit 0
	fi
	printf 'error: %s already defines project_doc_fallback_filenames; add "CLAUDE.md" without discarding its existing values\n' "$config" >&2
	exit 1
fi

if [ "$MODE" = verify ]; then
	printf 'DIFF %s  (missing: %s)\n' "$config" "$setting"
	exit 1
fi
if [ "$MODE" = dry-run ]; then
	printf 'DRY  add %s to %s\n' "$setting" "$config"
	exit 0
fi

mkdir -p -- "$(dirname "$config")"
tmp=$(mktemp "$(dirname "$config")/.config.toml.tmp.XXXXXX")
trap 'rm -f -- "$tmp"' EXIT

if [ -f "$config" ]; then
	awk -v setting="$setting" '
		!inserted && /^[[:space:]]*\[/ {
			print setting
			print ""
			inserted = 1
		}
		{ print }
		END {
			if (!inserted) {
				print setting
			}
		}
	' "$config" > "$tmp"
	chmod --reference="$config" "$tmp"
else
	printf '%s\n' "$setting" > "$tmp"
	chmod 600 "$tmp"
fi

mv -- "$tmp" "$config"
trap - EXIT
printf 'RUN  add %s to %s\n' "$setting" "$config"
