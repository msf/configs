---
name: rust-development
description: Rust-specific coding practices, crate layout, error handling, static analysis (clippy restriction lints + cargo [lints] baseline), and Makefile/cargo workflows. Builds on the language-agnostic `coding` skill. Use when writing, reviewing, or discussing Rust code.
---

Load the `coding` skill first for language-agnostic principles (simplicity, Power of 10, naming, errors, boundaries, tests). Everything below is Rust-specific.

## Scope detection (always first)

Decide whether the crate is `binary`, `library`, or `workspace` before proposing changes.

- Binary: `src/main.rs`, or `src/bin/*.rs`; owns config, signal handling, and the only `process::exit`.
- Library: `src/lib.rs` with a public API; no `main`, no global state, errors are types not strings.
- Workspace: root `Cargo.toml` with `[workspace]`; lints live in `[workspace.lints]` and every member has `[lints] workspace = true`.

## Power of 10 in Rust

How the `coding` skill's adapted rules land in Rust. Each has a lint in the baseline below; the text here is what the lint can't see.

- **Control flow:** `?` then the happy path at nesting 0. `let ... else` and early `return` over nested `match`. `match` on enums is exhaustive with no `_ =>` that hides a new variant. `process::exit` only in `main`. `panic!`/`unwrap` is not control flow; invalid input returns `Err`.
- **Bounded loops:** `for x in iter` and `loop {}` that consumes a reader or token stream and breaks on end of input are bounded by their data; leave them alone. `loop {}` that waits (retry, poll, worker, accept) must exit on an attempts counter, `tokio::select!` on a cancellation token or shutdown signal, or a deadline, and the exit is visible in the first lines or a comment above the loop. Retries use a named `MAX_ATTEMPTS` and backoff with a ceiling. `thread::sleep`/`tokio::time::sleep` in a waiting loop without cancellation is a bug. `clippy::infinite_loop` only catches loops with no `break`/`return` at all; the rest is a review item.
- **Bounded allocation:** `Vec::with_capacity(n)` when `n` is known. Channels are `bounded`/`mpsc::channel(cap)`, never `unbounded`. `take(limit)` on every reader fed by external input; `Body::limit`, max page sizes. Caches have a max size. No `Box::leak`/`mem::forget` outside a documented leaf.
- **Function size:** body ≤ 60 lines is the norm, 80 is the lint ceiling (tests exempt). Long `match` arms mean the arm body wants a function.
- **Assertions and input validation:** public constructors validate and return `Result<Self, Error>`; parse, don't validate (`NonZeroU32`, newtypes, `TryFrom`). Internal invariants use `assert!`/`debug_assert!` with a message naming the invariant, or `expect("<invariant>")`. `.unwrap()` is banned in production code: use `?`, `expect` with an invariant message, or a `let ... else`. Indexing is `.get()` or preceded by an `assert!` on the bound.
- **Smallest scope:** `pub(crate)` by default, `pub` only for the crate's API. No `static mut`; `OnceLock`/`LazyLock` only for config and metrics. Declare at first use, shadow only to refine the same value.
- **Check every return:** `#[must_use]` results are never dropped; `let _ = fallible()` needs a comment. `Result` in `Drop` is logged, not swallowed.
- **`unsafe` (rule 8/9 analog):** `unsafe_code = "forbid"` everywhere except the one leaf crate that needs it, where it becomes `deny` with `#[expect(unsafe_code, reason = "...")]` per block, one unsafe op per block, and a `// SAFETY:` comment.
- **Integer casts (rule 9 analog):** `From`/`TryFrom` over `as`; `checked_`/`saturating_` arithmetic on anything derived from input.

## Code writing rules

- Errors: one `enum Error` per crate or module boundary with `thiserror`; `anyhow` only in binaries and tests. Variants carry the context the caller needs, not a `String`.
- No `Box<dyn Error>` in library public APIs.
- Traits for seams that have two real implementations or a test double; otherwise concrete types.
- Prefer borrowing (`&str`, `&[T]`, `impl AsRef<Path>`) in signatures; `clone()` in a hot path needs a comment or a profile.
- `async`: no blocking calls in async fns (`std::fs`, `std::thread::sleep`, `Mutex` held across `.await`). Spawned tasks are tracked (`JoinSet`) and cancelled on shutdown.
- Constructors with more than 5 parameters take a config struct or a builder. `too_many_arguments` enforces the 5.

## Static analysis (mandatory)

Tooling decision: **rustc lints plus clippy, configured in `Cargo.toml` `[lints]` and `clippy.toml`, run through `cargo clippy --all-targets --all-features -- -D warnings`.** No third-party lint runner. `cargo-deny` for licenses/advisories and `cargo-audit` are supply-chain checks, run in CI next to clippy. Dylint is not adopted: no rule in the baseline needs a custom lint.

Every crate has the two reference files applied:

- [references/cargo-lints.toml](references/cargo-lints.toml): the `[lints.rust]` and `[lints.clippy]` tables. `clippy::all` denied, `pedantic` warned, and the Power of 10 restriction lints opted in one by one with the rule they serve.
- [references/clippy-baseline.toml](references/clippy-baseline.toml): thresholds (`too-many-lines-threshold = 80`, `cognitive-complexity-threshold = 15`, `excessive-nesting-threshold = 3`, `too-many-arguments-threshold = 5`) and the `allow-*-in-tests` switches.

The baseline is the contract; a crate may add lints or tighten thresholds, and may only downgrade a lint with a comment in the config saying why.

Non-negotiable:

- `unsafe_code = "forbid"` except in a documented leaf crate.
- `unwrap_used`, `panic`, `indexing_slicing`, `infinite_loop`, `exit`, `too_many_lines`, `excessive_nesting`, `unwrap_in_result`, `let_underscore_must_use`, `unused_result_ok` at `deny`.
- `allow_attributes = "deny"`: suppressions are `#[expect(clippy::rule, reason = "...")]`, which also fails when the suppression becomes stale.
- Tests keep `unwrap`/`expect`/`panic`/indexing through the `allow-*-in-tests` keys, not through `#[allow]`.

Compiler-side pedantry (P10 rule 10): `RUSTFLAGS="-D warnings"` in CI, `cargo build --all-targets`, `cargo test` under `cargo nextest` or `cargo test -- --test-threads` as the repo prefers, `cargo doc --no-deps` with `-D rustdoc::broken_intra_doc_links`, `cargo +nightly miri test` on any crate with `unsafe`. Pin the toolchain in `rust-toolchain.toml` so clippy lint names are stable.

## Linter adoption policy (check before writing code)

First action in any Rust repo: look for `[lints]`/`[workspace.lints]` in `Cargo.toml`, a `clippy.toml`, and a `lint` make/just target. Then pick the branch below. Never bundle lint-config changes with feature work; they go in their own commit or PR.

**Owned crate, config present.** Run the crate's own lints on your change; new code is clean under them. Also hold new code to the P10 rules the crate may not enable yet (unwrap in production code, unbounded loops, long functions): the reviewer sees them even if the lint doesn't. Diff the config against the baseline and propose missing lints as a separate PR, starting at `warn`.

**Owned crate, no config.** Add the baseline `[lints]` table and `clippy.toml`, add `lint` and `lint-all` targets, run `lint` on your change before calling it done. Ratchet: start the P10 restriction lints at `warn`, make CI fail on warnings only in changed files (`cargo clippy --message-format=json` filtered against `git diff --name-only origin/main`), and promote each lint to `deny` when its count reaches zero. `lint-all` reports the backlog. Do not raise thresholds to get green.

**Not owned (upstream, fork, contribution, vendored).** Do not add or edit `[lints]`, `clippy.toml`, or CI. Follow their configuration if they have one; if they don't, run the baseline against your diff only:

```zsh
cargo clippy --all-targets -- $(sed -n 's/^\([a-z_]*\) = "deny".*/-D clippy::\1/p' ~/.pi/agent/skills/rust-development/references/cargo-lints.toml)
```

Fix findings inside your diff, leave untouched code alone, and don't add `#[expect]` attributes for lints the project doesn't run. If the project's style contradicts a P10 rule (`unwrap` everywhere, 200-line functions), match the project; the skill governs code we own.

**Generated code** (`build.rs` output, `prost`/`tonic`, bindgen) is excluded by `#![allow(clippy::all)]` at the top of the generated module via the generator's config, not by hand edits.

## Testing

- Unit tests in the same file under `#[cfg(test)]`; integration tests in `tests/`; behavior tests at the crate's public boundary.
- Property tests (`proptest`) for parsers, encoders, and anything with an invariant worth asserting.
- Every constructor or public fn with precondition checks has one test per rejected input class.
- `cargo test --doc` runs; examples in docs compile.
- Don't unit-test metrics emission; test the logic that decides a label or value.

## Makefile / justfile DX contract

Canonical targets (names can vary, behavior should not):
- `setup`: `rustup component add clippy rustfmt`, `cargo install cargo-deny cargo-nextest` (or `cargo binstall`).
- `fmt`: `cargo fmt --all -- --check`.
- `lint`: `cargo clippy --all-targets --all-features -- -D warnings`, `cargo deny check`, `cargo doc --no-deps` with broken-link denial.
- `lint-all`: full clippy without the ratchet filter; informational until the burn-down finishes.
- `test`: `cargo nextest run --all-features` (or `cargo test`), plus `cargo test --doc`.
- `bench`: `cargo bench` or `criterion`, separated from `test`.
- `setup-containers` / `teardown-containers`: compose-backed external dependencies when the crate has them.

## Code hygiene checklist

- `cargo fmt --check` clean.
- `cargo clippy --all-targets --all-features -- -D warnings` clean under the crate's config.
- `cargo deny check` clean or the exception is recorded in `deny.toml` with a reason.
- `Cargo.lock` committed for binaries; `cargo update` in its own commit.
- No `unwrap`/`panic`/`todo!` in production code paths; no `#[allow]`, only `#[expect(..., reason)]`.
- Tests pass; `unsafe` crates also pass `miri`.
