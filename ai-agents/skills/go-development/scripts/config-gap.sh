#!/usr/bin/env bash
# Report which baseline linters and revive rules a repo's .golangci.yml lacks.
# Read-only. Usage: config-gap.sh [repo-dir]   (defaults to cwd)
set -euo pipefail

repo="${1:-.}"
here="$(cd "$(dirname "$0")" && pwd)"
baseline="$here/../references/golangci-baseline.yml"

cfg=""
for f in .golangci.yml .golangci.yaml .golangci.toml .golangci.json; do
  if [ -f "$repo/$f" ]; then cfg="$repo/$f"; break; fi
done
if [ -z "$cfg" ]; then
  echo "no golangci config in $repo: create one from $baseline"
  exit 2
fi

uv run --quiet --with pyyaml python - "$baseline" "$cfg" <<'PY'
import sys, yaml

STANDARD = {"errcheck", "govet", "ineffassign", "staticcheck", "unused"}

def load(path):
    with open(path) as f:
        return yaml.safe_load(f) or {}

def linters(cfg):
    l = cfg.get("linters", {}) or {}
    default = l.get("default", "standard")
    enabled = set(l.get("enable", []) or [])
    if default in ("standard", None):
        enabled |= STANDARD
    enabled -= set(l.get("disable", []) or [])
    # gomodguard was renamed gomodguard_v2 in golangci-lint 2.12; treat as one linter.
    return {"gomodguard_v2" if n == "gomodguard" else n for n in enabled}

def revive_rules(cfg):
    rules = ((cfg.get("linters", {}) or {}).get("settings", {}) or {}).get("revive", {}) or {}
    return {r["name"] for r in rules.get("rules", []) or [] if not r.get("disabled")}

def nolintlint_strict(cfg):
    s = ((cfg.get("linters", {}) or {}).get("settings", {}) or {}).get("nolintlint", {}) or {}
    return bool(s.get("require-explanation")) and bool(s.get("require-specific"))

base, repo = load(sys.argv[1]), load(sys.argv[2])
missing_linters = sorted(linters(base) - linters(repo))
missing_rules = sorted(revive_rules(base) - revive_rules(repo)) if "revive" in linters(repo) else sorted(revive_rules(base))
disabled_standard = sorted(STANDARD - linters(repo))

print(f"config: {sys.argv[2]}")
if disabled_standard:
    print(f"standard linters disabled (never acceptable): {' '.join(disabled_standard)}")
print(f"missing linters ({len(missing_linters)}): {' '.join(missing_linters) or '-'}")
print(f"missing revive rules ({len(missing_rules)}): {' '.join(missing_rules) or '-'}")
if "nolintlint" in linters(repo) and not nolintlint_strict(repo):
    print("nolintlint present but without require-explanation/require-specific")
sys.exit(1 if (missing_linters or missing_rules or disabled_standard) else 0)
PY
