---
name: coding
description: Load before writing, modifying, or reviewing code in any language, including bug fixes reached through debugging or investigation. Covers change sequencing, simplicity, control flow and size limits (NASA Power of 10), assertions, bounds, naming, types, error handling, boundaries, static analysis, and tests. Use alongside applicable language skills.
---

## Simplicity

The burden of proof is on complexity, not simplicity.

- Start with the simplest correct version. Correctness is non-negotiable; add complexity only when a concrete signal demands it.
- YAGNI: build what's needed now, not what might be needed later. "We might need X" is debt. "We're hitting X" is justification.
- Data structures are central. Get those right and the code writes itself. Write stupid code that uses the right data structures.
- Never optimize without measuring first. Even then, only fix the part that actually dominates.
- Collapse abstractions once optional behavior becomes mandatory. Remove stale flags and split interfaces when they no longer model a real choice.
- Every layer must earn its keep. Needless layering adds indirection without value — e.g. 1-2 line functions that just delegate to another function with a hardcoded argument. Expose the parameter and delete the wrappers.

## Change sequencing

Small pull requests are more likely to receive fast reviews, introduce fewer bugs, carry less risk, and earn higher approval rates. Treat review size as a design constraint before implementation, not cleanup at submission time.

- Sequence work into cohesive PRs that each target fewer than 500 changed lines (additions plus deletions from the intended merge base).
- Prefer the smallest complete change with a clear review narrative. Split by independently reviewable outcomes, not arbitrary file or line boundaries. A reviewer must be able to understand each PR's intent, behavior, and verification without reconstructing the full stack. Each PR must be safe to merge in sequence, include the tests for its behavior, and state any dependency on an earlier PR.
- Put prerequisites before dependents. Keep mechanical bulk separate from hand-written logic when practical.
- Dependency or lock graph updates, generated stubs, large test fixtures or matrices, and deletion-heavy changes may take a PR over 500 lines. Ordinary test code still counts. Keep the non-exempt portion under 500 lines and make the exceptional bulk obvious to reviewers.
- Group the commits inside a PR by layer, so each one reviews on its own: config and types first, then implementation, then tests. Keep infrastructure (`k8s/`, terraform) out of code commits, keep migrations out of application code, and give proto or API definition changes their own commit.
- "Cohesive" alone is not an exception. Split an oversized hand-written change across PRs; if splitting would make the change less safe, order it into small reviewable commits and document why one larger PR is necessary.

## Power of 10 (adapted)

Holzmann's [Power of 10](https://en.wikipedia.org/wiki/The_Power_of_10:_Rules_for_Developing_Safety-Critical_Code) rules target C flight software. We keep the spirit: code a reviewer and a tool can both verify. The language skills (`go-development`, `rust-development`) map the lintable parts to tools; loop progress, resource bounds, and boundary ownership still require review.

1. **Simple control flow.** Early return, one level of `else` at most, no clever flag-juggling. Nesting depth ≤ 3. No `goto`-equivalents (`os.Exit`/`process::exit` outside `main`, panics as control flow). Recursion only over data with a bounded depth, and the bound is checked explicitly.
2. **Every loop has a bound, and a reader can name it.** Two kinds of loop. Loops over finite data (a slice, a map, a finite token stream, a finite reader until EOF) are bounded by the data: every iteration consumes input, and that is the bound. They need nothing extra; do not add a counter to a lexer to satisfy this rule. EOF alone does not bound an external stream; apply size limits and cancellation or deadlines. Loops that wait on the world (retry, poll, accept, worker) are not bounded by data and must exit on an attempts cap, a deadline, or cancellation. That exit is stated in the loop header, the first lines, or a one-line comment above the loop, so a reviewer finds it without reading the body. Retry loops carry a named max-attempts constant; "retry forever" is legal only if cancellation still ends the loop.
3. **Bound allocation.** Preallocate when the size is known. Every queue, channel, buffer, cache, and request body has an explicit capacity or size limit. Never let external input decide how much memory you allocate without a cap.
4. **Functions fit on one sheet of paper.** Target ≤ 60 lines of formatted body; the lint ceiling is 80. Above that, split by responsibility, not by line count.
5. **Assert at the owning boundary.** Validate untrusted inputs once and return an error. Internal functions rely on that contract; do not repeat validation or add nil checks for states callers cannot produce. Assert non-obvious internal invariants with a message naming the invariant; assertions are side-effect free. Prefer encoding the invariant in a type (parse, don't validate) so the assertion disappears. Assertion count is not a quality target.
6. **Smallest scope.** Declare at first use, minimal visibility (`unexported`, `pub(crate)`), no package/global mutable state, no `init`-time side effects.
7. **Check every return value.** Unchecked errors and unused results are lint failures, not style. Discarding one requires a comment saying why (see Error Handling).
8. **Pedantic compiler and enforced analyzers.** Require zero findings under the adopted CI gate and no new violations of the agreed stricter rules. Report existing debt separately; each suppression names the rule and the reason. See Static analysis.

Rules 8 (preprocessor) and 9 (pointers) from the original map to language specifics: `unsafe` hygiene in Rust, reflection/`unsafe`/`interface{}` hygiene in Go.

## Naming & Types

- Self-documenting: use clear names for types, fields, variables, functions.
- Types should encode meaning (use `Duration`, not `string`; use enums, not magic strings).
- Use plain domain language that states user intent instead of mechanism shorthand.
- Field names and type names must agree. If a field holds a `PaymentMode`, don't call it `PricingMode`.

## Constants

- Domain constants (pricing rates, conversion factors, protocol limits, sentinel IDs) require a source comment explaining where the number comes from.
- If a constant is derived from another system's config, derive it programmatically rather than duplicating the value. Independent hardcoding of the same constraint in two places will drift.
- Bounds (rule 2 and 3 above) are named constants next to the thing they bound, with the reason for the number.

## Comments

- Implementation comments explain non-obvious reasons, not obvious statements.
- API documentation states caller-visible contracts: behavior, ownership and cleanup, mutation and aliasing, concurrency and cancellation, significant errors, panics, and safety obligations where relevant. Add executable examples for non-obvious usage.
- Delete tautologies, not contracts.

## Error Handling

Recover where the layer can meaningfully do so. Otherwise choose deliberately:

1. **Propagate**: return unchanged when no useful context is available; otherwise add non-redundant context. Preserve error identity when callers may inspect it; translate implementation errors at boundaries. Do not log and return the same failure by default.
2. **Log and continue**: the operation is best-effort and the caller explicitly tolerates failure. Log the error with enough context to diagnose, and document why continuing is safe.
3. **Impossible**: the error condition cannot occur given the program's invariants. This is an assertion (rule 5): panic/abort with a message naming the violated invariant, and comment why it holds.

**Never silently discard.** `_ = SomeFunc()` with no comment is a bug. If the error truly doesn't matter, write why.

Invalid input at a boundary is category 1 with a typed/sentinel invalid-argument error, never a panic.

## Boundaries

- Clearly understand what concerns each module/package/layer should care about. Then check whether code stays within those boundaries or leaks concerns across them.
- Separate concerns unless coupling is justified: transport, business logic, storage, telemetry, and configuration are independent.
- Keep guarantees at the boundary. If an interface promises a strong type or invariant, enforce it there instead of normalizing ad hoc in business logic.
- Stay within the project's established language, tooling, and package conventions.
- Distinguish product semantics from mechanism before encoding logic: anchor to the intended system boundary, preserve intentional duplication until the upstream source actually exists, and fail or flag unsupported multiplicity instead of silently picking a row.
- Before deleting or relocating shared code, grep for all implementors of the affected interface and verify each one handles the removed responsibility — not just the case that motivated the change.

## Static analysis

1. **Inspect the effective gate.** Read the repo instructions, pinned compiler/analyzer versions, rule settings, thresholds, exclusions, and the Makefile/CI invocation. Use the language skill's baseline to identify gaps, not as an unexplained replacement config. A gap script is a shortlist: listed rules may be disabled, weakened, or excluded, and defaults vary by version. Distinguish repo policy, proposed rules, and executed checks.
2. **Check changed behavior, not only changed lines.** Run the repo's checks with their prerequisites, then the agreed stricter checks against the actual PR base. A diff-line ratchet can hide function-length or complexity findings reported on an unchanged signature. Inspect complete modified functions and compare structural findings with the base; do not claim a clean diff proves no new structural debt. Keep length, nesting, argument count, and cognitive/cyclomatic complexity as separate signals. Split by responsibility, not to game a limit or hide state in a catch-all struct.
3. **Propose rules from evidence.** For a gap that matters to the change, name the rule, representative code, concrete risk or readability cost, measured findings, and false positives. Treat baseline thresholds as proposed starting values until the repo adopts them; correctness defects are not optional because a linter misses them. Preserve repo-specific contracts for errors, logging, initialization, and enums. Suppress only the specific rule with a reason; reject blanket suppressions and remove stale ones. Keep config/Makefile/CI hardening separate from feature work, and do not modify those controls without authorization.
4. **Make adoption verifiable.** Keep established checks enforced; ratchet newly adopted rules while reporting existing debt separately. Provide a PR gate and a full-backlog target (such as `lint` and `lint-all`) using compatible pinned tools and explicit base/history setup. Disable finding caps and line deduplication when measuring debt, and distinguish production, tests, and generated/vendor code. Prove the gate catches a planted violation, including a structural finding outside changed lines. An informational backlog must still expose tool, config, and type-check failures. Never relax an adopted threshold or disable a rule merely to get green.

A repo we own without an enforced linter needs a separate adoption proposal. Lint passing is evidence of the checks that ran, not proof of correctness, readable design, bounded resource use, or a complete quality score.

## Tests

- Keep behavior close to tests; avoid speculative abstractions.
- When adding a conditional code path to an existing function (feature flag, new request type, optional dependency), add at least one test exercising that path through the function's entry point. Helper-only tests don't prove the integration works.
- Mock only unstable/expensive dependencies or failure-path seams. Check surrounding test files for the repo's mocking conventions before introducing new patterns.
- Precondition checks (rule 5) get a test per rejected input class, not per value.
