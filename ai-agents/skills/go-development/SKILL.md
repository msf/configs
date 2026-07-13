---
name: go-development
description: Go-specific coding practices, architecture, testing, and Makefile workflows for service and library repositories. Builds on the language-agnostic `coding` skill. Use when writing, reviewing, or discussing Go code.
compatibility: opencode
---

Load the `coding` skill first for language-agnostic principles (simplicity, naming, errors, boundaries, tests). Everything below is Go-specific.

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

## Code writing rules

- Small functions, early returns, explicit error paths.
- Favor package-level cohesion over deep inheritance-like patterns.
- Keep business rules in handlers/use-cases, not in transport handlers.
- Keep storage details in `db/*` adapters behind interfaces used by handlers.
- Keep transport focused on parsing, validation, and protocol error mapping.
- Use `models/` for shared domain and API-adjacent types.
- In composition roots (`cmd/*/main.go`), wire dependencies explicitly and support graceful shutdown.
- When a constructor exceeds 5 parameters, use an options/config struct. Optional dependencies are pointer fields, not positional args that force `nil` at every call site.

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

## Testing

- Prefer integration tests at behavior boundaries (handler + db + external deps).
- Keep unit tests narrow and deterministic.
- Use `*_test.go`; keep representative fixtures in `testdata/` where useful.
- Run race detection and coverage in the default test target.
- Don't unit-test metrics. it adds friction and discourages instrumentation. Test the logic that *decides* a label or value, not the `.Inc()`/`.Observe()` emission.

## Makefile DX contract

Canonical targets (names can vary, behavior should not):
- `setup`: install local toolchain binaries and `go mod download`.
- `lint`: `go vet`, formatting/linting, `govulncheck`.
- `test`: `go test` with `-race` and coverage.
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
- Formatter/linter clean.
- `govulncheck` clean or explicitly acknowledged.
- Tests pass with race enabled.
- Generated artifacts (mocks/parsers/proto) are up to date.
- No accidental changes in protected deployment paths.
