#!/usr/bin/env bash
# Exercise GNU/BSD date parsing without contacting the registry.
set -euo pipefail
tools=$(cd "$(dirname "$0")" && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin"
printf '{"packages":{"node_modules/probe":{"version":"1.0.0","resolved":"https://example.invalid/probe.tgz"}}}\n' >"$fixture/lock.json"
cat >"$fixture/bin/curl" <<'MOCK'
#!/bin/sh
printf '{"time":{"1.0.0":"2020-01-01T00:00:00.000Z"}}\n'
MOCK
cat >"$fixture/bin/date" <<'MOCK'
#!/bin/sh
case "$*" in
  '-u +%s') echo 2000000000 ;;
  '-u -d '* )
    [ "$DATE_MODE" = gnu ] || exit 1
    echo 1000000000 ;;
  '-j -u -f '* )
    [ "$DATE_MODE" = bsd ] || exit 1
    echo 1000000000 ;;
  '+%Y%m%d-%H%M%S') echo fixture ;;
  *) exit 1 ;;
esac
MOCK
chmod +x "$fixture/bin/"*
for mode in gnu bsd; do
	PATH="$fixture/bin:$PATH" DATE_MODE=$mode bash "$tools/verify-lockfile-age.sh" "$fixture/lock.json" >"$fixture/log"
	grep -q 'checked 1 package versions' "$fixture/log"
done
if PATH="$fixture/bin:$PATH" DATE_MODE=invalid bash "$tools/verify-lockfile-age.sh" "$fixture/lock.json" >"$fixture/log" 2>&1; then
	printf 'FAIL: an unparsed timestamp passed the age gate\n' >&2
	exit 1
fi
printf 'PASS: lockfile age gate supports GNU/BSD date and fails on unparsed timestamps\n'
