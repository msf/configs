#!/usr/bin/env bash
# Hermetic checks for apply.sh in a throwaway HOME.
set -euo pipefail
# Keep the fixture independent of tools installed on the developer's host.
export HAS_CODEX=0

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

# A dormant skill stays unlinked on its host and deploys on other hosts.
printf 'skill   probe\n' > "$repo/tools/manifest.txt"
printf 'thishost probe\n' > "$repo/tools/dormant.txt"
rm -f "$home/.agents/skills/probe" "$home/.claude/skills/probe"
HOME="$home" AGENTS_HOST=thishost bash "$repo/tools/apply.sh" > /dev/null
test ! -e "$home/.agents/skills/probe" && test ! -e "$home/.claude/skills/probe"
HOME="$home" AGENTS_HOST=thishost bash "$repo/tools/apply.sh" --verify
HOME="$home" AGENTS_HOST=otherhost bash "$repo/tools/apply.sh" > /dev/null
test "$(readlink "$home/.agents/skills/probe")" = "$repo/skills/probe"
rm "$repo/tools/dormant.txt"
printf 'PASS: dormant skills stay unlinked only on their host\n'

# Host selectors choose one source per path without deploying work-only skills elsewhere.
printf 'work\n' > "$repo/skills/probe/work.md"
printf 'personal\n' > "$repo/skills/probe/personal.md"
printf 'repo .pi/agent/settings.json ai-agents/skills/probe/work.md @work\nrepo .pi/agent/settings.json ai-agents/skills/probe/personal.md @!work\nskill probe @work\n' > "$repo/tools/manifest.txt"
rm -f "$home/.agents/skills/probe" "$home/.claude/skills/probe"
HOME="$home" AGENTS_HOST=personal bash "$repo/tools/apply.sh" > /dev/null
HOME="$home" AGENTS_HOST=personal bash "$repo/tools/apply.sh" --verify
test "$(readlink "$home/.pi/agent/settings.json")" = "$repo/skills/probe/personal.md"
test ! -L "$home/.agents/skills/probe"
HOME="$home" AGENTS_HOST=work bash "$repo/tools/apply.sh" --dry-run > "$fixture/dry-run"
test "$(readlink "$home/.pi/agent/settings.json")" = "$repo/skills/probe/personal.md"
HOME="$home" AGENTS_HOST=work bash "$repo/tools/apply.sh" > /dev/null
HOME="$home" AGENTS_HOST=work bash "$repo/tools/apply.sh" --verify
test "$(readlink "$home/.pi/agent/settings.json")" = "$repo/skills/probe/work.md"
test "$(readlink "$home/.agents/skills/probe")" = "$repo/skills/probe"
for entry in 'skill probe @' 'skill probe @!' 'skill probe @work*' 'skill probe @work extra'; do
	printf '%s\n' "$entry" > "$repo/tools/manifest.txt"
	if HOME="$home" AGENTS_HOST=work bash "$repo/tools/apply.sh" > "$fixture/error" 2>&1; then
		printf 'FAIL: accepted malformed selector: %s\n' "$entry" >&2
		exit 1
	fi
done
printf 'repo .pi/agent/settings.json ai-agents/skills/probe/work.md @work\nrepo .pi/agent/settings.json ai-agents/skills/probe/personal.md\n' > "$repo/tools/manifest.txt"
if HOME="$home" AGENTS_HOST=work bash "$repo/tools/apply.sh" --verify > "$fixture/error" 2>&1; then exit 1; fi
grep -q 'duplicate active manifest path' "$fixture/error"
printf 'PASS: host selectors isolate settings and skills; malformed and overlapping entries fail\n'

# Codex entries and defaults apply only where Codex is installed.
printf 'repo    .codex/AGENTS.md  ai-agents/skills/probe/SKILL.md\n' > "$repo/tools/manifest.txt"
HOME="$home" HAS_CODEX=0 bash "$repo/tools/apply.sh" > /dev/null
test ! -e "$home/.codex"
HOME="$home" HAS_CODEX=0 bash "$repo/tools/apply.sh" --verify
HOME="$home" HAS_CODEX=1 bash "$repo/tools/apply.sh" > /dev/null
test "$(readlink "$home/.codex/AGENTS.md")" = "$repo/skills/probe/SKILL.md"
grep -Fxq 'project_doc_fallback_filenames = ["CLAUDE.md"]' "$home/.codex/config.toml"
HOME="$home" HAS_CODEX=1 bash "$repo/tools/apply.sh" --verify
printf 'PASS: Codex entries apply only with Codex installed\n'
