---
name: go-development
description: Go-specific coding practices, architecture, testing, static analysis (golangci-lint v2 + revive baseline), and Makefile workflows for service and library repositories. Builds on the language-agnostic `coding` skill. Use when writing, reviewing, or discussing Go code.
---

Load the `coding` skill first for language-agnostic principles (simplicity, Power of 10, naming, errors, boundaries, tests). Everything below is Go-specific.

## Scope detection (always first)

Decide whether the repository is mainly `service`, `library`, or `hybrid` before proposing changes.

Service indicators:
- `cmd/<binary>/main.go` composition roots.
- `handlers/`, `db/`, `models/`, and transport packages (`grpcserver/` or `httpserver/`).
- Local infra and schema artifacts (`compose.yaml`/`docker-compose.yaml`, `migrations/`).

Library indicators:
- No service runtime entrypoints.
- Packages under `lib/`, `clients/`, `models/` with reusable APIs.
- Optional integration dependencies only for specific package tests.

If `hybrid`, keep service and library expectations separate.

## Power of 10 in Go

How the `coding` skill's adapted rules land in Go. Each has a lint in the baseline below; the text here is what the lint can't see.

- **Control flow:** `if err != nil { return }` then the happy path at nesting 0. No `else` after a return. `switch` over enums is exhaustive with no `default` that hides a missed case. `os.Exit`/`log.Fatal` only in `main`. `panic` only for invariants, never for input.
- **Bounded loops:** `for range x` and `for {}` that consumes a reader or token stream and returns on `io.EOF` are bounded by their data; leave them alone. `for {}` that waits (retry, poll, worker, accept) must `select` on `ctx.Done()` or count attempts against a named max, and the exit is visible in the header, the first lines, or a comment above the loop. `time.Sleep` in a waiting loop is a bug; use `time.Ticker`/`time.After` under `ctx`. No lint checks this; it is a review item. Measured on a 94k LOC service: 13 production `for {}` loops, 6 waiting loops all `select` on ctx, 7 data loops (lexer, parsers, one retry loop with ctx checks in the body).
- **Bounded allocation:** `make([]T, 0, n)` when `n` is known (`prealloc` catches the obvious cases). Channels are buffered with a stated capacity or unbuffered by design; never goroutine-per-item without a semaphore/worker pool. `http.MaxBytesReader`, `io.LimitReader`, and max page sizes on every external input. Caches have a max size. `sync.Pool` only after a profile.
- **Function size:** body ≤ 60 lines is the norm, 80 is the lint ceiling (tests exempt). Error-return boilerplate counts; if it dominates, the function does too much.
- **Assertions and input validation:** exported functions and constructors validate arguments first and return `ErrInvalidArgument`-style errors wrapped with the field name. Internal invariants use an explicit `panic("pkg: <invariant> violated")`, not a bare index-out-of-range. Type assertions are always two-valued. Prefer constructors that return a validated type over re-checking downstream.
- **Smallest scope:** no `init()`, no mutable package-level vars except registered metrics and sentinel errors, `var` declared at first use.
- **Check every return:** `errcheck` is never disabled. `_ =` needs a comment. `defer f.Close()` on writers is an unchecked error.
- **Pointer/reflection hygiene (rule 9 analog):** no `**T`, no `any` where a concrete type or small interface exists, `reflect`/`unsafe` only in leaf packages with a package comment explaining why.

## Code writing rules

- Small functions, early returns, explicit error paths.
- Favor package-level cohesion over deep inheritance-like patterns.
- Keep business rules in handlers/use-cases, not in transport handlers.
- Keep storage details in `db/*` adapters behind interfaces used by handlers.
- Keep transport focused on parsing, validation, and protocol error mapping.
- Use `models/` for shared domain and API-adjacent types.
- In composition roots (`cmd/*/main.go`), wire dependencies explicitly and support graceful shutdown.
- When a constructor exceeds 5 parameters, use an options/config struct. Optional dependencies are pointer fields, not positional args that force `nil` at every call site. `argument-limit` enforces the 5.

## Layer contract

```
transport -> handlers -> db  (one direction)
```

- Transport maps protocol concerns; handlers map domain concerns.
- `db/` packages own SQL/query/object-store mechanics and retries.
- **Middleware is transport layer.** It handles auth, rate limiting, request/response decoration, and protocol concerns. Business logic that requires external service calls belongs in handlers, not middleware. If middleware needs computed data, the handler resolves it.

## Service shape (when applicable)

```text
cmd/
  grpcserver/main.go
  httpserver/main.go        # optional
  worker/main.go            # optional

handlers/
  <domain>/                 # business logic

db/
  <store>/                  # postgres/s3/redis/etc adapters

models/
  ...

grpcserver/                 # gRPC transport layer
httpserver/                 # healthz/metrics/admin endpoints

config/
migrations/
compose.yaml or docker-compose.yaml
Makefile
```

## Static analysis (mandatory)

Tooling decision: **golangci-lint v2 is the single runner; revive inside it carries the Power of 10 rules.** This matches what the five existing production configs already do (all run revive as a golangci linter with `var-naming`/`string-format` tuned). Standalone revive is not adopted: golangci already runs it, caches, and integrates with CI, and revive's rule set is where function length, complexity, nesting, argument count, and deep-exit checks live. Do not run two runners, and do not introduce a `revive.toml` next to a `.golangci.yml`.

Every repo has a `.golangci.yml` derived from [references/golangci-baseline.yml](references/golangci-baseline.yml). The baseline is the contract; a repo may add rules or forbid patterns, and may only remove a rule with a comment in the config saying why.

Non-negotiable in the baseline:

- Default linters (`errcheck`, `govet`, `staticcheck`, `unused`, `ineffassign`) all on. `errcheck` is never disabled, including in tests.
- `revive` with: `function-length [0, 80]`, `cognitive-complexity [15]`, `max-control-nesting [3]`, `argument-limit [5]`, `function-result-limit [3]`, `deep-exit`, `unchecked-type-assertion`, `early-return`, `unconditional-recursion`, `defer`, `datarace`, `range-val-address`, `waitgroup-by-value`, `bare-return`, `identical-branches`, `modifies-parameter`, `import-shadowing`, `use-any`. Listing rules in golangci's revive block keeps revive's defaults active (verified on v2.8).
- `exhaustive`, `nilerr`, `nilnesserr`, `gochecknoinits`, `makezero`, `prealloc`, `bodyclose`, `noctx`, `fatcontext`, `errorlint`, `gosec`, `unparam`, `predeclared`, `misspell`, `forbidigo`, `gomodguard_v2` (requires golangci-lint ≥ 2.12; the repos pin 2.11 to 2.13, so bump 2.11 first).
- `nolintlint` with `require-explanation` and `require-specific`: every `//nolint:<rule> // <why>`.
- Formatters: `gofumpt`, `gci` (standard, default, org prefix, localmodule), `goimports`.
- Test files: exempt from `function-length`, `cognitive-complexity`, `argument-limit`, `gosec`, `noctx`, `unparam`. Nothing else.

Compiler-side pedantry (P10 rule 10): `go vet ./...` with all analyzers, `go build` with `-race` in tests, `go test -race -shuffle=on -count=1`, `govulncheck ./...`. `staticcheck` runs through golangci, not separately. Optional extra analyzer for nil safety: `nilaway` via `go vet -vettool`; adopt per repo after a trial run, not by default.

## Linter adoption policy (check before writing code)

First action in any Go repo: run the gap report, read-only:

```zsh
~/.pi/agent/skills/go-development/scripts/config-gap.sh .
```

Exit 2 means no config (create one, branch below). Exit 1 lists the baseline linters and revive rules the repo lacks, and calls out any standard linter (`errcheck`, `govet`, `staticcheck`, `unused`, `ineffassign`) that is disabled. Put that list in the review or PR description as "lint config gaps", ranked by which rules would have caught something in this diff. Measured on five existing production configs: every one lacks the P10 revive rules (`function-length`, `cognitive-complexity`, `max-control-nesting`, `argument-limit`, `deep-exit`, `unchecked-type-assertion`) and `nolintlint`; two of them disable `errcheck`, which is a rule-7 violation and the first fix to propose.

Then pick the branch below. Never bundle lint-config changes with feature work; they go in their own commit or PR.

**Owned repo, config present.** The repo config is the CI gate and stays authoritative; do not edit it in the same change. Run it on the packages you touched; new code is clean under it. Then run the baseline on the diff only, as a local pre-commit check:

```zsh
golangci-lint run -c ~/.pi/agent/skills/go-development/references/golangci-baseline.yml --new-from-merge-base=origin/main ./...
```

Fix findings in the code, not with `//nolint` for rules the repo doesn't run. Measured on the last 10 commits of three repos (9k, 28k, 94k LOC): 1, 2, 0 findings on changed lines, against whole-repo backlogs of 151, 312, 292 (golangci-lint 2.13.1). Rules that caught something real in your diff are candidates for the next lint-config PR; propose them with the ratchet enabled so the PR is green on day one.

**Owned repo, no config.** Create `.golangci.yml` from the baseline, add `lint`/`lint-all` targets, and run `lint` on your change before calling it done. Enable the ratchet (`--new-from-merge-base=origin/main`, or `issues.new-from-merge-base` in the config) so CI fails only on changed code; `lint-all` reports the backlog. Burn down by package, oldest-touched first. Do not lower thresholds to get green.

**Not owned (upstream, fork, contribution, vendored).** Do not add or edit lint config, Makefiles, or CI. Follow their linter if they have one; if they don't, run the baseline against your diff only:

```zsh
golangci-lint run -c ~/.pi/agent/skills/go-development/references/golangci-baseline.yml --new-from-merge-base=origin/main ./...
```

Fix findings inside your diff, leave untouched code alone, and don't leave `//nolint` comments for rules the project doesn't run. Mention pre-existing findings in the PR description only if they affect the change. If the project's style contradicts a P10 rule (e.g. 200-line functions are the norm), match the project; the skill governs code we own.

**Generated and vendored paths** (`mocks/`, `*.pb.go`, `third_party/`) are excluded in config, not with `//nolint`.

Cobra (Holzmann's own checker) is not adopted for Go: its P10 checker is a set of C token patterns (`p10.def`) and would need a Go token table and rewritten patterns. Revive covers rules 1, 4, 7 and the lintable part of 5 directly.

## Testing

- Prefer integration tests at behavior boundaries (handler + db + external deps).
- Keep unit tests narrow and deterministic.
- Use `*_test.go`; keep representative fixtures in `testdata/` where useful.
- Run race detection, shuffle, and coverage in the default test target.
- Don't unit-test metrics. it adds friction and discourages instrumentation. Test the logic that *decides* a label or value, not the `.Inc()`/`.Observe()` emission.
- Every exported function with precondition checks has one test per rejected input class.

## Makefile DX contract

Canonical targets (names can vary, behavior should not):
- `setup`: install local toolchain binaries (`golangci-lint`, `govulncheck`, `gofumpt`) and `go mod download`.
- `lint`: `go vet ./...`, `golangci-lint run` (with `--new-from-rev` in PR CI when ratcheting), `govulncheck ./...`.
- `lint-all`: full `golangci-lint run --uniq-by-line=false` without ratchet; informational until the burn-down finishes. The default dedups findings that land on the same line (e.g. `function-length` and `cognitive-complexity` on one `func`), which under-reports the backlog by ~30%.
- `test`: `go test -race -shuffle=on -count=1 -cover`.
- `benchmark`: benchmark target separated from regular tests.
- `gen-mocks`: regenerate mocks from interfaces.
- `setup-containers` / `teardown-containers`: local external dependencies.
- `init-testdb` / `migrate`: when schema migrations exist.

Use make targets as the contract for both humans and CI.

## Local container dependencies

- Define external deps in compose (Postgres, MinIO, Trino, Redis, etc.).
- Reproducible local bootstrapping: `setup-containers` and `teardown-containers` make targets backed by compose.
- Health checks and startup wait loops in make targets.
- Ports configurable via environment variables when practical.

## Code hygiene checklist

- `go mod tidy` has no diff.
- `golangci-lint run` clean against the baseline; every `//nolint` has a rule and a reason.
- `govulncheck` clean or explicitly acknowledged.
- Tests pass with `-race -shuffle=on`.
- Every `for {}` has a visible bound; every channel/buffer/cache has a stated capacity.
- Generated artifacts (mocks/parsers/proto) are up to date.
- No accidental changes in protected deployment paths.
