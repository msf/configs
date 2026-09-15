#!/usr/bin/env bash
# Hermetic checks for apply.sh in a throwaway HOME.
set -euo pipefail

tools=$(cd "$(dirname "$0")" && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT

home=$fixture/home
repo=$home/configs/ai-agents
mkdir -p "$repo/tools" "$repo/skills/probe" "$home/.claude/skills"
cp "$tools"/*.sh "$repo/tools/"
printf -- '---\nname: probe\n---\nbody\n' > "$repo/skills/probe/SKILL.md"
printf 'repo    .claude/skills/probe  ai-agents/skills/probe\n' > "$repo/tools/manifest.txt"

HOME="$home" bash "$repo/tools/apply.sh" > /dev/null
test "$(readlink "$home/.claude/skills/probe")" = "$repo/skills/probe"
HOME="$home" bash "$repo/tools/apply.sh" --verify
printf 'PASS: manifest entry projects and verifies\n'

# A third party that re-claims the link leaves <path>.pre-dune-sietch behind.
ln -s "$repo/skills/probe" "$home/.claude/skills/probe.pre-dune-sietch"
if HOME="$home" bash "$repo/tools/apply.sh" --verify 2>/dev/null; then
  printf 'FAIL: --verify accepted a displaced leftover\n' >&2
  exit 1
fi
# pipefail would kill the script on the expected non-zero exit; capture first.
out=$(HOME="$home" bash "$repo/tools/apply.sh" --verify 2>&1 || true)
printf '%s' "$out" | grep -Fq 'displaced leftover'
printf 'PASS: --verify reports a displaced leftover\n'

rm "$home/.claude/skills/probe.pre-dune-sietch"
HOME="$home" bash "$repo/tools/apply.sh" --verify
printf 'PASS: --verify is clean once the leftover is gone\n'
