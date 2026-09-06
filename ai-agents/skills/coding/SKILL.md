---
name: coding
description: Load before writing, modifying, or reviewing code in any language, including bug fixes reached through debugging or investigation. Covers simplicity, control flow and size limits (NASA Power of 10), assertions, bounds, naming, types, error handling, boundaries, static analysis, and tests. Use alongside applicable language skills.
---

## Simplicity

The burden of proof is on complexity, not simplicity.

- Start with the simplest correct version. Correctness is non-negotiable; add complexity only when a concrete signal demands it.
- YAGNI: build what's needed now, not what might be needed later. "We might need X" is debt. "We're hitting X" is justification.
- Data structures are central. Get those right and the code writes itself. Write stupid code that uses the right data structures.
- Never optimize without measuring first. Even then, only fix the part that actually dominates.
- Collapse abstractions once optional behavior becomes mandatory. Remove stale flags and split interfaces when they no longer model a real choice.
- Every layer must earn its keep. Needless layering adds indirection without value — e.g. 1-2 line functions that just delegate to another function with a hardcoded argument. Expose the parameter and delete the wrappers.

## Power of 10 (adapted)

Holzmann's [Power of 10](https://en.wikipedia.org/wiki/The_Power_of_10:_Rules_for_Developing_Safety-Critical_Code) rules target C flight software. We keep the spirit: code a reviewer and a tool can both verify. The language skills (`go-development`, `rust-development`) map each rule to an enforced lint; this section is the contract.

1. **Simple control flow.** Early return, one level of `else` at most, no clever flag-juggling. Nesting depth ≤ 3. No `goto`-equivalents (`os.Exit`/`process::exit` outside `main`, panics as control flow). Recursion only over data with a bounded depth, and the bound is checked explicitly.
2. **Every loop has a bound, and a reader can name it.** Two kinds of loop. Loops over finite data (a slice, a map, a token stream, a reader until EOF) are bounded by the data: every iteration consumes input, and that is the bound. They need nothing extra; do not add a counter to a lexer to satisfy this rule. Loops that wait on the world (retry, poll, accept, worker) are not bounded by data and must exit on an attempts cap, a deadline, or cancellation. That exit is stated in the loop header, the first lines, or a one-line comment above the loop, so a reviewer finds it without reading the body. Retry loops carry a named max-attempts constant; "retry forever" is legal only if cancellation still ends the loop.
3. **Bound allocation.** Preallocate when the size is known. Every queue, channel, buffer, cache, and request body has an explicit capacity or size limit. Never let external input decide how much memory you allocate without a cap.
4. **Functions fit on one sheet of paper.** Target ≤ 60 lines of formatted body; the lint ceiling is 80. Above that, split by responsibility, not by line count.
5. **Assert.** Every non-trivial function checks its preconditions in its first lines. Public entry points validate inputs and return an error. Internal invariants that cannot fail by construction assert and panic/abort with a message. Assertions are side-effect free. Prefer encoding the invariant in a type (parse, don't validate) so the assertion disappears.
6. **Smallest scope.** Declare at first use, minimal visibility (`unexported`, `pub(crate)`), no package/global mutable state, no `init`-time side effects.
7. **Check every return value.** Unchecked errors and unused results are lint failures, not style. Discarding one requires a comment saying why (see Error Handling).
8. **Pedantic compiler, multiple analyzers, zero warnings.** Every repo ships its lint config, CI fails on any finding, and each suppression names the rule and the reason. See Static analysis.

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

- Minimize comments — only explain non-obvious "why", never "what".
- If a comment restates what the code does, delete it.

## Error Handling

Every error falls into exactly one of three categories. Choose deliberately:

1. **Propagate**: wrap with context and return. The caller decides what to do. This is the default.
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

- A repo without an enforced linter config is not done. The language skill names the tools and the exact rule set; use it, don't improvise a subset.
- Zero findings in CI. Warnings are errors.
- Every suppression (`//nolint:rule`, `#[allow(rule, reason = "...")]`) names the specific rule and states why. Blanket suppressions are rejected in review.
- Adopting strict rules on a legacy codebase: enforce on changed code first (ratchet), then burn down. Never lower a threshold to make the build green.
- Fixing a lint finding by disabling the rule is a root-cause failure. Fix the code or document why the rule is wrong for this repo in the config itself.

## Tests

- Keep behavior close to tests; avoid speculative abstractions.
- When adding a conditional code path to an existing function (feature flag, new request type, optional dependency), add at least one test exercising that path through the function's entry point. Helper-only tests don't prove the integration works.
- Mock only unstable/expensive dependencies or failure-path seams. Check surrounding test files for the repo's mocking conventions before introducing new patterns.
- Precondition checks (rule 5) get a test per rejected input class, not per value.
