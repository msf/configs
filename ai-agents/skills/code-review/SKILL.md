---
name: code-review
description: Run hard-nosed self-review for pull requests, commit stacks, diffs, and GitHub changes before they ship. Use this whenever the user asks to review their own PR, branch, commit, diff, stacked changes, or wants approval/comment recommendations.
compatibility: opencode
---

## Philosophy

This is a **bar-raiser self-review**, not a courtesy review. The job is to protect the codebase from your own blind spots before reviewers or production find them.

Default posture: **skeptical until proven shippable**. Approval is earned by clear intent, simple design, idiomatic code, correct boundaries, and evidence. Do not rubber-stamp. Do not pad with performative nits. Be tough, specific, and pragmatic.

A good hard review is not dogmatic:
- Prefer the repo's established conventions over personal taste.
- Accept boring, simple, slightly repetitive code when it is clearer than abstraction.
- Block only on problems that materially affect correctness, operability, maintainability, security, readability, or team conventions.
- Do not invent idealized rewrites. Demand the smallest fix that makes the PR solid.

## Non-negotiable review posture

Before recommending approval, actively try to disprove the PR:

1. **Guidelines loaded** — review against `coding` and the relevant language/framework skills. If you have not loaded them, the review is incomplete.
2. **Simplification pass** — try to delete code, collapse branches, remove stale optionality, inline needless wrappers, and replace cleverness with the obvious data shape.
3. **Idiomatic pass** — compare the diff with nearby code and language-specific conventions. Flag code that is technically functional but hard to read, non-idiomatic, or alien to the repo.
4. **Semantics/complexity pass** — trace upstream callers and downstream callees before accepting extra branches, arg/mode/type variants, fallback paths, retries, nil handling, or broad error handling. Ask whether each path represents a real supported state or just uncertainty/overgenerality. Keep cyclomatic complexity low.
5. **Proof pass** — require tests, execution, logs, or CI evidence for the behavior that changed. Helper-only tests do not prove entrypoint behavior.

## Workflow

### 1. Scope and context

- Read repo instructions. Classify each repo as `service`, `library`, or `hybrid`.
- Load skills in the parent session before reviewing:
  - Always load `coding` for language-agnostic principles.
  - Load language-specific skills based on the PR: `go-development` for Go, etc.
  - Load `dune-explore` for ownership/archeology, `k8s-debug` or `log-investigator` when operationally motivated.
  - If no local skill covers the language/framework, say so. Use `find-skills` for discovery only if the user asks; never install skills mid-review.
- If the PR references a Linear issue or branch name implies one, pull the ticket via Linear MCP. Extract the actual problem, constraints, and acceptance criteria.
- Read existing PR discussion before judging severity: issue comments, review threads, and author replies. Extract explicit scope limits, migration plans, companion PRs, and claims like "internal-only" or "all clients are being updated together".
- For stacked work, review base PRs first and descendants against their actual base branch.
- Compatibility findings need actual blast-radius analysis. An exported API change in an internal repo, a brand-new API, or a PR with companion client updates in flight is not a blocker by default. It blocks when unmanaged consumers or rollout ordering make it unsafe.

### 2. Spawn the code-reviewer agent

- Use the `code-reviewer` subagent (defined in `~/.config/opencode/agents/code-reviewer.md`). It runs with read-only permissions and all GitHub mutation commands denied.
- Launch one `code-reviewer` subagent per PR. Split within a PR only for genuinely independent areas.
- **Include loaded and relevant skill content in the subagent prompt.** The subagent cannot load skills, so the parent must pass the relevant principles and guidelines as context. Include the content from `coding` and any language-specific skill (e.g. `go-development`) directly in the Task prompt alongside the PR context from `references/subagent-prompt-template.md`.
- Pass any Linear/cross-repo context you already gathered into the prompt so the review starts from the real problem, not just the patch.
- Treat subagent output like a junior's PR: verify claims, check file refs, discount overclaims. Only surface findings you personally understand with high confidence.

### 3. Bar-raiser checks

Run these checks yourself even if the subagent misses them:

- **Right problem**: does the PR solve the real issue from the ticket/PR body, or just make the local symptom disappear?
- **Boundary ownership**: is each invariant enforced at the correct boundary, not repeatedly normalized in business logic?
- **Belt-and-suspenders smell**: flag code that accepts or handles states the current product path cannot produce, especially extra credential/mode/type variants, nil checks, fallback paths, retries, or compatibility branches. Diagnose whether the variation is a real requirement, active migration, or genuine shared-library boundary; otherwise treat it as YAGNI/overengineering caused by uncertainty about what must be supported. Reject unsupported states at the boundary or delete the branch. Prefer fewer paths and lower cyclomatic complexity.
- **Simplification**: ask what can be deleted. Look for needless helper structs, wrapper functions, flags that no longer represent choices, duplicated paths, speculative config, broad DB reads, and multi-step flows where a direct call would do.
- **Idiomatic readability**: require names, control flow, error handling, and tests to match nearby code and the relevant language skill. "It works" is not enough if the next maintainer has to reverse-engineer it.
- **Error semantics**: every error must be propagated, logged-and-continued with a real reason, or impossible by invariant. Sequential checks that obscure mutually exclusive cases are suspect.
- **Test proof**: new branches through an existing entrypoint need entrypoint-level tests. Billing, auth, quota, rollout, or data-loss behavior needs direct assertions on the risk, not only golden totals or helper tests.

### 4. Synthesize

- Do not default to approval. Recommend approval only after the PR survives the bar-raiser checks.
- Rank findings by risk and codebase value, not by quantity.
- Suppress pure preference and cosmetic polish. Style issues are not cosmetic when they violate repo conventions, obscure semantics, or make maintenance harder.
- If the code has extra branches, variants, or fallbacks because the real supported states are unclear, do not let that pass as prudence. Verify the product/API semantics; if the path is not real, simplify it away or ask a blocking question.
- Hold off-diff observations to a higher bar than diff-local ones; if they are not close to blocker-level or deployment-risk-level, omit them.
- Do not re-raise a point already acknowledged or resolved in PR discussion unless you have new evidence that the resolution is insufficient.
- Compatibility concerns need stronger proof than "exported API changed". Request changes only when you can point to unmanaged consumers, uncoordinated rollout risk, or another concrete failure mode that survives the existing discussion.
- If multiple PRs form a stack, finish with a cross-PR summary showing stack order and verdicts.
- Use the report shape in `references/report-template.md`.

### 5. Mutation discipline

Investigation and GitHub mutation are always separate turns.
1. Present findings, severity classifications, and draft comments to the user.
2. Make the separation explicit in the user-facing report:
   - Lead the recommendation with `My suggestion is ...`
   - Use future tense for mutation, never past tense. Say `I recommend approving`, `I would request changes`, or `I can post this review`, not `approved` / `requested` in a way that implies GitHub state already changed.
   - End the analysis turn with a clear gate: `NEED YOUR APPROVAL TO SUBMIT`.
3. In a follow-up user turn, post with `gh pr review` or `gh api`.
4. Never approve just because no catastrophic blocker was found. Approval requires the PR to be understandable, idiomatic, scoped, and proven.

## Verdicts

- `approved`: the PR survives the bar-raiser checks. No blockers, no unresolved semantic uncertainty, no important simplification left, and evidence is adequate.
- `approved, with suggestions`: shippable, but has one or two concrete improvements worth doing soon. Do not use this for polish or stylistic cleanup.
- `changes requested`: the PR has a material defect or fails a non-negotiable review gate: wrong problem, unclear call-flow semantics, unearned complexity, non-idiomatic/hard-to-read code, misplaced invariants, missing proof for changed behavior, security/data risk, or a rollout/compatibility hazard.
- `significant issues`: the approach itself is wrong. Explain the better direction and the smallest path back.

## Useful commands

- Metadata: `gh pr view <n> --json title,body,files,commits,statusCheckRollup`
- Issue comments: `gh api repos/<org>/<repo>/issues/<n>/comments --paginate`
- Review threads/comments: `gh api repos/<org>/<repo>/pulls/<n>/reviews --paginate` and `gh api repos/<org>/<repo>/pulls/<n>/comments --paginate`
- Diff: `gh pr diff <n>` or `gh api repos/<org>/<repo>/pulls/<n>/files --paginate`
- CI failures: `gh run view <run-id> --log-failed`
- Approve: `gh pr review <n> --approve --body "..."`
- Request changes: `gh pr review <n> --request-changes --body "..."`
- Comment only: `gh pr review <n> --comment --body "..."`

Read `references/report-template.md` for the final report shape.
