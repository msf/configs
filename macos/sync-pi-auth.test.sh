#!/usr/bin/env bash
# Exercise the real receiver against disposable homes; never use real credentials.
set -euo pipefail
script=$(cd "$(dirname "$0")" && pwd)/sync-pi-auth.sh
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
export HOME="$fixture/host" FIXTURE_GUEST_HOME="$fixture/guest"
export PATH="$fixture/bin:$PATH"
mkdir -p "$HOME/.pi/agent" "$FIXTURE_GUEST_HOME" "$fixture/bin"

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
chmod +x "$fixture/bin/limactl"
printf '{"test-provider":{"type":"api_key","key":"not-a-real-token"}}\n' >"$HOME/.pi/agent/auth.json"
printf '{"fixture-mcp":{}}\n' >"$HOME/.pi/agent/mcp-auth.json"

run_sync() { bash "$script" >"$fixture/output" 2>&1; }
assert_no_staging() {
	if compgen -G "$FIXTURE_GUEST_HOME/.pi/agent/.auth-sync.*" >/dev/null; then
		printf 'FAIL: credential staging file remains\n' >&2
		exit 1
	fi
}

run_sync
for name in auth.json mcp-auth.json; do
	file="$FIXTURE_GUEST_HOME/.pi/agent/$name"
	cmp "$HOME/.pi/agent/$name" "$file"
	[[ $(find "$file" -prune -perm 0600) == "$file" ]]
done
[[ $(find "$FIXTURE_GUEST_HOME/.pi/agent" -prune -perm 0700) == "$FIXTURE_GUEST_HOME/.pi/agent" ]]
if grep -q 'not-a-real-token' "$fixture/output"; then
	printf 'FAIL: credential contents reached output\n' >&2
	exit 1
fi
run_sync
assert_no_staging
printf 'PASS: copies both stores, enforces permissions, repeats without leaking credentials\n'

cp "$FIXTURE_GUEST_HOME/.pi/agent/auth.json" "$fixture/original-auth.json"
cp "$FIXTURE_GUEST_HOME/.pi/agent/mcp-auth.json" "$fixture/original-mcp.json"
printf 'invalid-json\n' >"$HOME/.pi/agent/mcp-auth.json"
if run_sync; then
	printf 'FAIL: accepted invalid JSON\n' >&2
	exit 1
fi
cmp "$fixture/original-auth.json" "$FIXTURE_GUEST_HOME/.pi/agent/auth.json"
cmp "$fixture/original-mcp.json" "$FIXTURE_GUEST_HOME/.pi/agent/mcp-auth.json"
rm "$HOME/.pi/agent/mcp-auth.json"
run_sync
cmp "$fixture/original-mcp.json" "$FIXTURE_GUEST_HOME/.pi/agent/mcp-auth.json"
printf 'PASS: invalid JSON changes nothing; absent source leaves guest store intact\n'

mv "$FIXTURE_GUEST_HOME/.pi/agent/auth.json" "$fixture/referent.json"
ln -s "$fixture/referent.json" "$FIXTURE_GUEST_HOME/.pi/agent/auth.json"
if run_sync; then
	printf 'FAIL: replaced a credential symlink\n' >&2
	exit 1
fi
cmp "$fixture/original-auth.json" "$fixture/referent.json"
rm "$FIXTURE_GUEST_HOME/.pi/agent/auth.json"
cp "$fixture/referent.json" "$FIXTURE_GUEST_HOME/.pi/agent/auth.json"
if FAIL_COPY=1 run_sync; then
	printf 'FAIL: ignored a failed transfer\n' >&2
	exit 1
fi
cmp "$fixture/original-auth.json" "$FIXTURE_GUEST_HOME/.pi/agent/auth.json"
assert_no_staging
printf 'PASS: refuses symlinks; transfer failure preserves old credentials and cleans staging\n'

rm "$HOME/.pi/agent/auth.json"
if run_sync; then
	printf 'FAIL: accepted an empty source\n' >&2
	exit 1
fi
printf 'PASS: refuses a source with no credential stores\n'
