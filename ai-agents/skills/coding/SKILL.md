---
name: coding
description: Language-agnostic coding principles for writing and reviewing code. Covers simplicity, naming, types, error handling, boundaries, and testing fundamentals. Use as the foundation when writing, reviewing, or discussing code quality in any language.
compatibility: opencode
---

## Simplicity

The burden of proof is on complexity, not simplicity.

- Start with the simplest correct version. Correctness is non-negotiable; add complexity only when a concrete signal demands it.
- YAGNI: build what's needed now, not what might be needed later. "We might need X" is debt. "We're hitting X" is justification.
- Data structures are central. Get those right and the code writes itself. Write stupid code that uses the right data structures.
- Never optimize without measuring first. Even then, only fix the part that actually dominates.
- Collapse abstractions once optional behavior becomes mandatory. Remove stale flags and split interfaces when they no longer model a real choice.
- Every layer must earn its keep. Needless layering adds indirection without value — e.g. 1-2 line functions that just delegate to another function with a hardcoded argument. Expose the parameter and delete the wrappers.

## Naming & Types

- Self-documenting: use clear names for types, fields, variables, functions.
- Types should encode meaning (use `Duration`, not `string`; use enums, not magic strings).
- Use plain domain language that states user intent instead of mechanism shorthand.
- Field names and type names must agree. If a field holds a `PaymentMode`, don't call it `PricingMode`.

## Constants

- Domain constants (pricing rates, conversion factors, protocol limits, sentinel IDs) require a source comment explaining where the number comes from.
- If a constant is derived from another system's config, derive it programmatically rather than duplicating the value. Independent hardcoding of the same constraint in two places will drift.

## Comments

- Minimize comments — only explain non-obvious "why", never "what".
- If a comment restates what the code does, delete it.

## Error Handling

Every error falls into exactly one of three categories. Choose deliberately:

1. **Propagate**: wrap with context and return. The caller decides what to do. This is the default.
2. **Log and continue**: the operation is best-effort and the caller explicitly tolerates failure. Log the error with enough context to diagnose, and document why continuing is safe.
3. **Impossible**: the error condition cannot occur given the program's invariants. Document why with a comment. Use `// unreachable:` or panic if the invariant is compile-time provable.

**Never silently discard.** `_ = SomeFunc()` with no comment is a bug. If the error truly doesn't matter, write why.

## Boundaries

- Clearly understand what concerns each module/package/layer should care about. Then check whether code stays within those boundaries or leaks concerns across them.
- Separate concerns unless coupling is justified: transport, business logic, storage, telemetry, and configuration are independent.
- Keep guarantees at the boundary. If an interface promises a strong type or invariant, enforce it there instead of normalizing ad hoc in business logic.
- Stay within the project's established language, tooling, and package conventions.
- Distinguish product semantics from mechanism before encoding logic: anchor to the intended system boundary, preserve intentional duplication until the upstream source actually exists, and fail or flag unsupported multiplicity instead of silently picking a row.
- Before deleting or relocating shared code, grep for all implementors of the affected interface and verify each one handles the removed responsibility — not just the case that motivated the change.

## Tests

- Keep behavior close to tests; avoid speculative abstractions.
- When adding a conditional code path to an existing function (feature flag, new request type, optional dependency), add at least one test exercising that path through the function's entry point. Helper-only tests don't prove the integration works.
- Mock only unstable/expensive dependencies or failure-path seams. Check surrounding test files for the repo's mocking conventions before introducing new patterns.
