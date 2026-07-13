---
description: Review and simplify all changes on this branch
---

Review all changes on this branch and simplify them.

Changed files:
!`git diff $(git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null || echo HEAD~1)...HEAD --stat`

Full diff:
!`git diff $(git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null || echo HEAD~1)...HEAD`

User focus (if any): $ARGUMENTS

## Instructions

Launch THREE parallel review agents using the Task tool, each analyzing the
changes for a specific dimension. Use subagent_type: simplify-synergy for Agent 1
and subagent_type: explore for Agents 2 and 3. Pass each agent the list of
changed files and the diff.

Agents must look BEYOND the diff. The changed files are a starting point, not a
boundary: read surrounding code (sibling files, the package/module the change
lives in, callers and callees) and grep the wider repo, so findings account for
what already exists instead of judging the diff in isolation.

### Agent 1: Codebase Synergy & Reuse  (subagent_type: simplify-synergy)
Explore the existing codebase, not just the diff. For every new function, type,
constant, or helper introduced, grep the package and wider repo for an equivalent
that already exists.
- Reimplementations of logic that already exists elsewhere (name the existing
  function/file the new code should call instead)
- Existing utilities/helpers/abstractions that should replace inline code
- New code that ignores an established pattern in the same package (error
  handling, logging, validation, config access, test helpers) -- show the local
  pattern it should follow
- New imports/dependencies that duplicate capability already vendored in the repo
- Genuinely identical duplicated logic across the changed files worth extracting
Do NOT invent speculative shared abstractions: flag reuse of existing, proven
code only, and suggest extraction only when duplication is real and semantically
identical (duplication beats the wrong abstraction).

### Agent 2: Code Quality  (subagent_type: explore)
Read sibling files in each changed file's package to learn the local conventions
before judging.
- Poor naming that obscures intent
- Overly complex expressions or control flow that could be simplified
- Dead code, unnecessary comments, leftover debugging artifacts
- Convention violations -- both for the language/framework and for the
  conventions already established in the files/package being changed

### Agent 3: Efficiency  (subagent_type: explore)
- Unnecessary allocations, copies, or conversions
- Redundant operations (duplicate lookups, repeated computations)
- Algorithmic improvements for hot paths
- Unnecessary dependencies or imports added

Each agent must return a structured list of findings:
- File path and line range
- Category (reuse/quality/efficiency)
- Issue description
- Suggested fix with concrete code

## After Collecting Results

1. Deduplicate overlapping findings across agents
2. Prioritize by impact (high/medium/low). Surface "reuse existing code X instead
   of new code Y" findings explicitly -- they are high value and easiest to miss.
3. If you have edit capabilities (build mode):
   - Apply all clear improvements directly
   - Skip changes that would alter public API signatures or observable behavior
   - Report what was changed and what was intentionally skipped
4. If you are in read-only mode (plan mode):
   - Present all findings grouped by file
   - Include concrete code suggestions for each finding
   - Provide a summary with estimated impact
