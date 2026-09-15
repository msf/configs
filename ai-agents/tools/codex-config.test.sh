#!/usr/bin/env bash
set -euo pipefail

tools=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
config=$test_root/config.toml

printf 'model = "test"\n\n[projects."/tmp/test"]\ntrust_level = "trusted"\n' > "$config"
CODEX_CONFIG_FILE=$config bash "$tools/codex-config.sh"
CODEX_CONFIG_FILE=$config bash "$tools/codex-config.sh" --verify
[ "$(grep -c '^project_doc_fallback_filenames = ' "$config")" -eq 1 ]
[ "$(sed -n '3p' "$config")" = 'project_doc_fallback_filenames = ["CLAUDE.md"]' ]

printf 'project_doc_fallback_filenames = ["TEAM_GUIDE.md"]\n' > "$config"
if CODEX_CONFIG_FILE=$config bash "$tools/codex-config.sh" >/dev/null 2>&1; then
	printf 'expected conflicting setting to fail\n' >&2
	exit 1
fi
grep -Fxq 'project_doc_fallback_filenames = ["TEAM_GUIDE.md"]' "$config"

printf 'codex-config tests passed\n'
