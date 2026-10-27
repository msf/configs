#!/usr/bin/env bash
set -euo pipefail

tools=$(cd "$(dirname "$0")" && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT

home=$fixture/local-lessons
mkdir -p "$home/configs/ai-agents/tools" "$home/.pi/agent"
cp "$tools/track.sh" "$tools/lib.sh" "$home/configs/ai-agents/tools/"
: > "$home/configs/ai-agents/tools/manifest.txt"
printf 'local lesson\n' > "$home/.pi/agent/lessons.md"
for visibility in public private; do
  args=()
  [ "$visibility" != private ] || args+=(--private)
  if HOME="$home" bash "$home/configs/ai-agents/tools/track.sh" "${args[@]}" .pi/agent/lessons.md > /dev/null 2>&1; then
    printf 'FAIL: track.sh accepted a %s lesson journal\n' "$visibility" >&2
    exit 1
  fi
  test ! -L "$home/.pi/agent/lessons.md"
  test "$(< "$home/.pi/agent/lessons.md")" = 'local lesson'
  test ! -s "$home/configs/ai-agents/tools/manifest.txt"
done
printf 'PASS: lesson journals stay local in public and private modes\n'

# A regular replacement of host-selected settings must not overwrite owned sources.
home=$fixture/owned-settings
repo=$home/configs/ai-agents
mkdir -p "$repo/tools" "$repo/home/.pi/agent" "$home/.pi/agent"
cp "$tools/track.sh" "$tools/lib.sh" "$repo/tools/"
printf 'replacement settings\n' > "$home/.pi/agent/settings.json"
printf 'existing mirror settings\n' > "$repo/home/.pi/agent/settings.json"
printf 'work settings\n' > "$repo/home/work-settings.json"
printf 'personal settings\n' > "$repo/home/personal-settings.json"
cat > "$repo/tools/manifest.txt" <<'MANIFEST'
repo .pi/agent/settings.json ai-agents/home/work-settings.json @liskov
repo .pi/agent/settings.json ai-agents/home/personal-settings.json @!liskov
MANIFEST
cp "$home/.pi/agent/settings.json" "$fixture/original-settings"
cp "$repo/home/.pi/agent/settings.json" "$fixture/original-mirror"
cp "$repo/home/work-settings.json" "$fixture/original-work"
cp "$repo/home/personal-settings.json" "$fixture/original-personal"
cp "$repo/tools/manifest.txt" "$fixture/original-manifest"
for host in liskov fw13; do
  for visibility in public private; do
    args=()
    [ "$visibility" != private ] || args+=(--private)
    if HOME="$home" AGENTS_HOST="$host" bash "$repo/tools/track.sh" "${args[@]}" .pi/agent/settings.json > "$fixture/refusal" 2>&1; then
      printf 'FAIL: track.sh accepted already-owned %s settings on %s\n' "$visibility" "$host" >&2
      exit 1
    fi
    grep -Fq 'already in manifest: .pi/agent/settings.json' "$fixture/refusal"
    test ! -L "$home/.pi/agent/settings.json"
    cmp "$fixture/original-settings" "$home/.pi/agent/settings.json"
    cmp "$fixture/original-mirror" "$repo/home/.pi/agent/settings.json"
    cmp "$fixture/original-work" "$repo/home/work-settings.json"
    cmp "$fixture/original-personal" "$repo/home/personal-settings.json"
    cmp "$fixture/original-manifest" "$repo/tools/manifest.txt"
    test ! -e "$home/.agents-backup" && test ! -e "$home/configs-private"
  done
done
printf 'PASS: already-owned conditional settings are refused without changing live/source/manifest bytes\n'

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
