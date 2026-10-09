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

# A skill entry projects one source into every shared skills root.
printf 'skill   probe\n' > "$repo/tools/manifest.txt"
rm "$home/.claude/skills/probe"
HOME="$home" bash "$repo/tools/apply.sh" > /dev/null
test "$(readlink "$home/.agents/skills/probe")" = "$repo/skills/probe"
test "$(readlink "$home/.claude/skills/probe")" = "$repo/skills/probe"
HOME="$home" bash "$repo/tools/apply.sh" --verify
printf 'PASS: skill entry projects into every shared root\n'

# Main-profile deployment must not touch other harnesses or the lean profile.
rm "$home/.claude/skills/probe"
printf "mirror .pi/agent-lean/settings.json\nmirror .claude/settings.json\n" >> "$repo/tools/manifest.txt"
HOME="$home" bash "$repo/tools/apply.sh" --pi > /dev/null
test ! -e "$home/.claude/skills/probe"
test ! -e "$home/.pi/agent-lean"
HOME="$home" bash "$repo/tools/apply.sh" --pi --verify
printf "PASS: --pi deploys shared skills without other harnesses or lean state\n"
