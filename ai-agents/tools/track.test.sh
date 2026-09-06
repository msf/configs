#!/usr/bin/env bash
set -euo pipefail

tools=$(cd "$(dirname "$0")" && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT

for skill_path in .pi/agent/skills/wiki .claude/skills/wiki; do
  home=$fixture/${skill_path%%/*}
  target=$home/configs/ai-agents/skills/wiki
  mkdir -p "$home/configs/ai-agents/tools" "$home/$skill_path" "$target"
  cp "$tools/track.sh" "$tools/lib.sh" "$tools/apply.sh" "$home/configs/ai-agents/tools/"
  : > "$home/configs/ai-agents/tools/manifest.txt"
  printf 'wiki fixture\n' > "$target/SKILL.md"
  cp "$target/SKILL.md" "$home/$skill_path/SKILL.md"

  HOME="$home" bash "$home/configs/ai-agents/tools/track.sh" "$skill_path" > /dev/null
  test "$(readlink "$home/$skill_path")" = "$target"
  test "$(< "$target/SKILL.md")" = 'wiki fixture'
  grep -Fq "$skill_path  ai-agents/skills/wiki" "$home/configs/ai-agents/tools/manifest.txt"
  HOME="$home" bash "$home/configs/ai-agents/tools/apply.sh" --verify
  printf 'PASS: %s uses the canonical shared skill source\n' "$skill_path"
done
