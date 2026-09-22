#!/usr/bin/env bash
set -euo pipefail

tools=$(cd "$(dirname "$0")" && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT

# A tracked skill is linked into every shared root, and nowhere else.
assert_shared_links() {
  local home=$1 name=$2 target=$3 tracked_from=$4
  test "$(readlink "$home/.agents/skills/$name")" = "$target"
  test "$(readlink "$home/.claude/skills/$name")" = "$target"
  case "$tracked_from" in
    .pi/*) test ! -e "$home/$tracked_from" && test ! -L "$home/$tracked_from" ;;
  esac
}

for skill_path in .pi/agent/skills/wiki .claude/skills/wiki .agents/skills/wiki; do
  home=$fixture/${skill_path%%/*}
  target=$home/configs/ai-agents/skills/wiki
  mkdir -p "$home/configs/ai-agents/tools" "$home/$skill_path" "$target"
  cp "$tools/track.sh" "$tools/lib.sh" "$tools/apply.sh" "$tools/codex-config.sh" "$home/configs/ai-agents/tools/"
  : > "$home/configs/ai-agents/tools/manifest.txt"
  printf 'wiki fixture\n' > "$target/SKILL.md"
  cp "$target/SKILL.md" "$home/$skill_path/SKILL.md"

  HOME="$home" bash "$home/configs/ai-agents/tools/track.sh" "$skill_path" > /dev/null
  assert_shared_links "$home" wiki "$target" "$skill_path"
  test "$(< "$target/SKILL.md")" = 'wiki fixture'
  grep -Eq '^skill +wiki$' "$home/configs/ai-agents/tools/manifest.txt"
  HOME="$home" bash "$home/configs/ai-agents/tools/codex-config.sh" > /dev/null
  HOME="$home" bash "$home/configs/ai-agents/tools/apply.sh" --verify
  printf 'PASS: %s uses the canonical shared skill source\n' "$skill_path"
done

for skill_path in .pi/agent/skills/dbsh .claude/skills/dbsh .agents/skills/dbsh; do
  home=$fixture/private-${skill_path%%/*}
  target=$home/configs-private/skills/dbsh
  mkdir -p "$home/configs/ai-agents/tools" "$home/$skill_path" "$target"
  cp "$tools/track.sh" "$tools/lib.sh" "$tools/apply.sh" "$tools/codex-config.sh" "$home/configs/ai-agents/tools/"
  : > "$home/configs/ai-agents/tools/manifest.txt"
  printf 'dbsh fixture\n' > "$target/SKILL.md"
  cp "$target/SKILL.md" "$home/$skill_path/SKILL.md"

  HOME="$home" bash "$home/configs/ai-agents/tools/track.sh" --private "$skill_path" > /dev/null
  assert_shared_links "$home" dbsh "$target" "$skill_path"
  test "$(< "$target/SKILL.md")" = 'dbsh fixture'
  grep -Eq '^pskill +dbsh$' "$home/configs/ai-agents/tools/manifest.txt"
  HOME="$home" bash "$home/configs/ai-agents/tools/codex-config.sh" > /dev/null
  HOME="$home" bash "$home/configs/ai-agents/tools/apply.sh" --verify
  printf 'PASS: private %s uses the canonical shared skill source\n' "$skill_path"
done
