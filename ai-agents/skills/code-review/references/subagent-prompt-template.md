# Per-PR Context Template

When invoking the `code-reviewer` subagent, inject this context into the prompt. The agent's own system prompt handles rubric, severity, and output format.

```text
Review <repo> PR #<number>.
Local path: <local-path>
Base branch: <base-branch>

## Review stance

This is a bar-raiser self-review. Be skeptical until proven shippable. Run simplification, idiomatic-readability, call-flow/API-semantics, and proof passes. Treat extra branches, arg/mode/type variants, nil checks, fallbacks, retries, or compatibility paths as possible YAGNI/overengineering when the current product path cannot produce them. Verify whether each path is truly supported; otherwise simplify and keep cyclomatic complexity low.

## Coding guidelines

<Paste the content of the `coding` skill here — the subagent cannot load skills.>

<If language-specific skill was loaded (e.g. go-development), paste its content here too.>

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
