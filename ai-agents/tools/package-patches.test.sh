#!/usr/bin/env bash
# Hermetic checks for package-patches.sh in a throwaway tools dir and npm dir.
set -euo pipefail

tools=$(cd "$(dirname "$0")" && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT

mkdir -p "$fixture/tools/patches" "$fixture/npm/pkg"
cp "$tools/package-patches.sh" "$tools/lib.sh" "$fixture/tools/"
printf 'one\n' > "$fixture/original.txt"
printf '{\n  "version": "1.0.0"\n}\n' > "$fixture/npm/pkg/package.json"
cp "$fixture/original.txt" "$fixture/npm/pkg/file.txt"
mkdir "$fixture/new" && printf 'two\n' > "$fixture/new/file.txt"
(cd "$fixture" && mkdir -p a b && cp original.txt a/file.txt && cp new/file.txt b/file.txt &&
	{ diff -u a/file.txt b/file.txt || true; } > tools/patches/pkg.patch)
printf 'thishost pkg 1.0.0 pkg.patch\n' > "$fixture/tools/package-patches.txt"

run() { AGENTS_HOST=$1 PI_NPM_DIR=$fixture/npm bash "$fixture/tools/package-patches.sh" "${@:2}"; }
patched() { [ "$(cat "$fixture/npm/pkg/file.txt")" = two ]; }

run otherhost > /dev/null
! patched
run otherhost --verify
printf 'PASS: other hosts are untouched\n'

! run thishost --verify 2>/dev/null
run thishost --dry-run > /dev/null
! patched
run thishost > /dev/null
patched
run thishost --verify
run thishost > /dev/null
patched
printf 'PASS: apply patches, verify passes, re-run is a no-op\n'

cp "$fixture/original.txt" "$fixture/npm/pkg/file.txt"
! run thishost --verify 2>/dev/null
run thishost > /dev/null
patched
printf 'PASS: a reinstalled package is patched again\n'

cp "$fixture/original.txt" "$fixture/npm/pkg/file.txt"
printf '{\n  "version": "1.1.0"\n}\n' > "$fixture/npm/pkg/package.json"
! run thishost --verify 2>/dev/null
run thishost > /dev/null 2>&1
! patched
printf 'PASS: a version change warns, fails verify, and leaves the package alone\n'
