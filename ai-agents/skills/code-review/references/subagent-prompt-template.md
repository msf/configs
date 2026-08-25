# Per-PR Context Template

When invoking the `code-reviewer` subagent, inject this context into the prompt. The agent's own system prompt handles rubric, severity, and output format.

```text
Review <repo> PR #<number>.
Local path: <local-path>
Base branch: <base-branch>
Hard deadline: <absolute-deadline>, no more than 10 minutes after launch.

## Coordination deadline

The parent enforces the hard deadline externally. Stop exploration early enough to return the best high-confidence findings before it. If the complete review cannot fit, report the unchecked areas under `Unverified`; do not keep exploring past the deadline. Do not run builds or tests unless the task explicitly requests them and includes them within this same budget.

## Review stance

This is a bar-raiser self-review. Be skeptical until proven shippable. Run simplification, idiomatic-readability, call-flow/API-semantics, and proof passes. Treat extra branches, arg/mode/type variants, nil checks, fallbacks, retries, or compatibility paths as possible YAGNI/overengineering when the current product path cannot produce them. Verify whether each path is truly supported; otherwise simplify and keep cyclomatic complexity low.

## Coding guidelines

Read these skill files in full before reviewing:
- `~/.pi/agent/skills/coding/SKILL.md`
- <each relevant language/domain skill path, for example `~/.pi/agent/skills/go-development/SKILL.md`>

Treat those files as review policy. If a path is unavailable, report the missing guideline instead of guessing.

<If Linear ticket was found>
## Linear context
- Issue: <issue-id> — <title>
- Problem: <problem statement>
- Acceptance criteria: <criteria>
</If>

<If existing PR discussion materially affects severity>
## PR discussion context
- Author/reviewer comments affecting severity: <summary>
- Companion PRs / in-flight client updates: <summary>
- Concerns already addressed in thread: <summary>
</If>

<If stacked>
## Stack context
- This PR's base: <base-pr> (verdict: <verdict>)
- Known issues from base review: <issues if any>
</If>

<If cross-repo context was gathered>
## Repo/ownership context
<summary from dune-explore>
</If>
```
