#!/usr/bin/env bash
# Exercise the sender and receiver with disposable homes and mocked Lima/npm.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
export HOME="$fixture/host" FIXTURE_GUEST_HOME="$fixture/guest"
export PATH="$fixture/bin:$PATH"
script="$HOME/configs/macos/sync-pi-config.sh"
tools="$HOME/configs/ai-agents/tools"
mkdir -p "$tools" "$(dirname "$script")" "$fixture/bin" "$FIXTURE_GUEST_HOME/.pi/agent"
cp "$repo/macos/sync-pi-config.sh" "$script"
cp "$repo/ai-agents/tools/"{apply,lib}.sh "$tools/"
cat >"$tools/manifest.txt" <<'MANIFEST'
skill probe
pskill private-probe
mirror .pi/agent/settings.json
mirror .pi/agent/models.json
mirror .pi/agent/auth.json
mirror .pi/agent/secrets
repo .pi/agent/extensions/probe ai-agents/tools/extensions/probe
repo .pi/agent/AGENTS.md ai-agents/instructions.md
pmirror .pi/agent/mcp.json
home .pi/agent-lean/auth.json .pi/agent/auth.json
mirror .claude/settings.json
MANIFEST
mkdir -p "$HOME/configs/ai-agents/"{skills/probe,home/.pi/agent,tools/extensions/probe/node_modules} \
	"$HOME/configs-private/"{skills/private-probe,home/.pi/agent}
printf 'public skill\n' >"$HOME/configs/ai-agents/skills/probe/SKILL.md"
printf 'private skill\n' >"$HOME/configs-private/skills/private-probe/SKILL.md"
printf 'instructions\n' >"$HOME/configs/ai-agents/instructions.md"
printf 'extension\n' >"$tools/extensions/probe/index.ts"
printf 'mac-native\n' >"$tools/extensions/probe/node_modules/mac-only"
printf '{}\n' >"$tools/extensions/probe/package-lock.json"
printf '{"defaultModel":"fixture","shellPath":"%s/bin/bash"}\n' "$HOME" \
	>"$HOME/configs/ai-agents/home/.pi/agent/settings.json"
printf '{"providers":{"local":{"baseUrl":"http://localhost:8090/v1"}}}\n' \
	>"$HOME/configs/ai-agents/home/.pi/agent/models.json"
printf '{"mcpServers":{}}\n' >"$HOME/configs-private/home/.pi/agent/mcp.json"
printf '{"providers":{"local":{"baseUrl":"http://guest-custom:1234/v1"}}}\n' \
	>"$FIXTURE_GUEST_HOME/.pi/agent/models.json"
printf 'guest credentials\n' >"$FIXTURE_GUEST_HOME/.pi/agent/auth.json"
mkdir -p "$FIXTURE_GUEST_HOME/configs" "$FIXTURE_GUEST_HOME/.pi/agent/browser-read/profile"
printf 'guest checkout\n' >"$FIXTURE_GUEST_HOME/configs/sentinel"
printf 'cookies\n' >"$FIXTURE_GUEST_HOME/.pi/agent/browser-read/profile/sentinel"
cat >"$fixture/bin/limactl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case $1 in
shell)
	shift
	[[ $1 == --workdir=/ ]]; shift
	[[ $1 == linux-dev ]]; shift
	[[ $1 == -- ]]; shift
	HOME="$FIXTURE_GUEST_HOME" exec "$@"
	;;
copy)
	shift
	[[ $1 == --backend=scp ]]; shift
	[[ ${FAIL_COPY:-0} == 0 ]] || exit 9
	cp -- "$1" "${2#*:}"
	;;
*) exit 2 ;;
esac
MOCK
cat >"$fixture/bin/npm" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ ${FAIL_NPM:-0} == 0 ]] || exit 9
mkdir -p node_modules
printf 'linux-native\n' >node_modules/linux-only
MOCK
cat >"$fixture/bin/pi" <<'MOCK'
#!/usr/bin/env bash
[[ $* == 'update --extensions' ]]
MOCK
printf '#!/usr/bin/env bash\nexit 0\n' >"$fixture/bin/flock"
printf '#!/usr/bin/env bash\nshift 2\nexec "$@"\n' >"$fixture/bin/timeout"
chmod +x "$fixture/bin/"*
run_sync() { bash "$script" >"$fixture/output" 2>&1; }
run_sync || { tail -40 "$fixture/output"; exit 1; }
state="$FIXTURE_GUEST_HOME/.local/state/pi-config-sync"
agent="$FIXTURE_GUEST_HOME/.pi/agent"
[[ $(jq -r .shellPath "$agent/settings.json") == "$FIXTURE_GUEST_HOME/bin/bash" ]]
[[ $(jq -r .providers.local.baseUrl "$agent/models.json") == http://guest-custom:1234/v1 ]]
[[ -f $FIXTURE_GUEST_HOME/.agents/skills/probe/SKILL.md ]]
[[ -f $FIXTURE_GUEST_HOME/.agents/skills/private-probe/SKILL.md ]]
[[ -f $agent/mcp.json && -f $agent/AGENTS.md ]]
[[ -f $agent/extensions/probe/node_modules/linux-only ]]
[[ -f $state/current/configs/ai-agents/tools/manifest.txt ]]
[[ ! -e $agent/extensions/probe/node_modules/mac-only ]]
[[ ! -e $FIXTURE_GUEST_HOME/.claude && ! -e $FIXTURE_GUEST_HOME/.codex ]]
[[ $(<"$agent/auth.json") == 'guest credentials' ]]
[[ $(<"$agent/browser-read/profile/sentinel") == cookies ]]
[[ $(<"$FIXTURE_GUEST_HOME/configs/sentinel") == 'guest checkout' ]]
[[ ! -e $state/current/configs/ai-agents/home/.pi/agent/auth.json ]]
[[ ! -e $state/current/configs/ai-agents/home/.pi/agent/secrets ]]
run_sync
printf 'PASS: syncs public/private resources, remaps JSON paths, rebuilds dependencies; repeatable and scoped\n'

rm "$agent/models.json"
run_sync
[[ $(jq -r .providers.local.baseUrl "$agent/models.json") == http://host.lima.internal:8090/v1 ]]
printf 'PASS: fresh model config maps Mac localhost to host.lima.internal\n'
printf 'updated skill\n' >"$HOME/configs/ai-agents/skills/probe/SKILL.md"
mkdir -p "$FIXTURE_GUEST_HOME/.agents/skills/guest-only"
grep -v '^pskill ' "$tools/manifest.txt" >"$fixture/manifest"
mv "$fixture/manifest" "$tools/manifest.txt"
run_sync
[[ $(<"$FIXTURE_GUEST_HOME/.agents/skills/probe/SKILL.md") == 'updated skill' ]]
[[ ! -L $FIXTURE_GUEST_HOME/.agents/skills/private-probe ]]
[[ -d $FIXTURE_GUEST_HOME/.agents/skills/guest-only ]]
printf 'PASS: propagates edits, retires removed snapshot links, preserves guest-only skills\n'
cp -L "$agent/settings.json" "$fixture/original-settings"
printf '{"defaultModel":"changed"}\n' >"$HOME/configs/ai-agents/home/.pi/agent/settings.json"
for failure in FAIL_COPY FAIL_NPM; do
	if env "$failure=1" bash "$script" >"$fixture/output" 2>&1; then exit 1; fi
	cmp "$fixture/original-settings" "$agent/settings.json"
done
printf 'invalid\n' >"$HOME/configs/ai-agents/home/.pi/agent/settings.json"
if run_sync; then exit 1; fi
cmp "$fixture/original-settings" "$agent/settings.json"
printf '{}\n' >"$HOME/configs/ai-agents/home/.pi/agent/settings.json"
rm -rf "$HOME/configs/ai-agents/skills/probe"
if run_sync; then exit 1; fi
cmp "$fixture/original-settings" "$agent/settings.json"
if compgen -G "$state/.incoming.*" >/dev/null; then exit 1; fi
if bash "$script" '../invalid' >"$fixture/output" 2>&1; then exit 1; fi
printf 'PASS: failed transfer/install and malformed JSON preserve deployed config and clean staging; rejects invalid instance\n'
