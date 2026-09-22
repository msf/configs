---
name: code-review
description: Run hard-nosed self-review for pull requests, commit stacks, diffs, and GitHub changes before they ship. Use this whenever the user asks to review their own PR, branch, commit, diff, stacked changes, or wants approval/comment recommendations.
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
- If the PR references a Linear issue or branch name implies one, use the active harness's Linear integration when available and read the ticket. If Linear is unavailable, use the PR context and mark the ticket context unverified rather than blocking the review.
- Read existing PR discussion before judging severity: issue comments, review threads, and author replies. Extract explicit scope limits, migration plans, companion PRs, and claims like "internal-only" or "all clients are being updated together".
- For stacked work, review base PRs first and descendants against their actual base branch.
- Compatibility findings need actual blast-radius analysis. An exported API change in an internal repo, a brand-new API, or a PR with companion client updates in flight is not a blocker by default. It blocks when unmanaged consumers or rollout ordering make it unsafe.

### 2. Coordinate a bounded reviewer pass

- Delegation is optional evidence, never a prerequisite for finishing the review.
- A delegated review has a hard **10-minute wall-clock deadline per PR**. Invoke the `code-reviewer` only through a tool or process that enforces that deadline. A deadline written only in the prompt does not count. If the available subagent tool has no timeout parameter, skip delegation and review directly.
- Never place a subagent call in a parallel tool batch: the batch remains blocked until every call returns.
- In Pi, use the `code-reviewer` defined in `~/.pi/agent/agents/code-reviewer.md`. In another harness, use its native reviewer only when the same deadline and isolation guarantees are enforceable. Pass the paths of `coding` and each relevant language/domain skill; the isolated agent must read those files itself.
- Build the task from `references/subagent-prompt-template.md`, including the absolute deadline plus ticket, PR-discussion, stack, and cross-repo context already gathered.
- Never pass your own hypotheses to an agent as established fact. Do not write "this leaks on the error path" or "another reviewer confirmed X" for a conclusion you reached yourself. The agent builds on it and returns it, and you then read your own idea as independent corroboration. To get a hypothesis checked, send it to exactly one agent as an open question with no answer attached.
- A review mission the user set is not bias. "Weight security, this is auth code" scopes the review; pass it to every agent verbatim, as the user's scope. The prohibition covers conclusions you formed, not the mission you were given.
- Do not hand an agent a curated list of files to read and things to look for. That is a scavenger hunt, and it returns hunt-shaped results.
- On timeout, abort once, do not retry delegation for that PR in the same review, and continue the parent review directly. Report any resulting evidence gap as unverified; a timed-out subagent never blocks delivery.
- Treat returned findings like a junior's PR: re-read every surfaced location and keep only findings you personally understand with high confidence.

### 3. Bar-raiser checks

Run these checks yourself even if the subagent misses them:

- **Right problem**: does the PR solve the real issue from the ticket/PR body, or just make the local symptom disappear?
- **Boundary ownership**: is each invariant enforced at the correct boundary, not repeatedly normalized in business logic?
- **Belt-and-suspenders smell**: flag code that accepts or handles states the current product path cannot produce, especially extra credential/mode/type variants, nil checks, fallback paths, retries, or compatibility branches. Diagnose whether the variation is a real requirement, active migration, or genuine shared-library boundary; otherwise treat it as YAGNI/overengineering caused by uncertainty about what must be supported. Reject unsupported states at the boundary or delete the branch. Prefer fewer paths and lower cyclomatic complexity.
- **Simplification**: ask what can be deleted. Look for needless helper structs, wrapper functions, flags that no longer represent choices, duplicated paths, speculative config, broad DB reads, and multi-step flows where a direct call would do. For new helpers, types, or dependencies, search the existing package and repository for equivalent functionality; name the existing implementation when proposing reuse. Do not invent shared abstractions for merely similar code.
- **Idiomatic readability**: require names, control flow, error handling, and tests to match nearby code and the relevant language skill. "It works" is not enough if the next maintainer has to reverse-engineer it.
- **Error semantics**: every error must be propagated, logged-and-continued with a real reason, or impossible by invariant. Sequential checks that obscure mutually exclusive cases are suspect.
- **Schema/migration coupling**: a migration and the code that depends on it do not deploy atomically, and reverting the deploy does not revert the migration. When one PR carries both, work out the ordering it implies. Code that reads a new column fails in the window before the migration runs. A destructive migration — drop, rename, narrow a type — fails the old code still serving traffic during the rollout. Demand the expand-migrate-contract split: the additive migration ships first, the code that uses it second, the destructive step last, once nothing references the old shape. One PR is fine when the migration is additive and the code tolerates its absence.
- **Test proof**: new branches through an existing entrypoint need entrypoint-level tests. Billing, auth, quota, rollout, or data-loss behavior needs direct assertions on the risk, not only golden totals or helper tests.

### 4. Synthesize

- Do not default to approval. Recommend approval only after the PR survives the bar-raiser checks.
- Rank findings by risk and codebase value, not by quantity.
- Reading code does not prove a fact that lives outside the diff: that a metric exists, what a production config holds, what a third-party API returns. When a blocker rests on such a fact, check it only if a single tool call settles it. Otherwise stop there; do not spend the review chasing it. Demote it to a question that names the fact and asks the author to confirm. A confident wrong claim about the world outside the diff costs the author more than the finding is worth.
- Suppress pure preference and cosmetic polish. Style issues are not cosmetic when they violate repo conventions, obscure semantics, or make maintenance harder.
- If the code has extra branches, variants, or fallbacks because the real supported states are unclear, do not let that pass as prudence. Verify the product/API semantics; if the path is not real, simplify it away or ask a blocking question.
- Hold off-diff observations to a higher bar than diff-local ones; if they are not close to blocker-level or deployment-risk-level, omit them.
- Do not re-raise a point already acknowledged or resolved in PR discussion unless you have new evidence that the resolution is insufficient.
- Compatibility concerns need stronger proof than "exported API changed". Request changes only when you can point to unmanaged consumers, uncoordinated rollout risk, or another concrete failure mode that survives the existing discussion.
- If multiple PRs form a stack, finish with a cross-PR summary showing stack order and verdicts.
- Use the report shape in `references/report-template.md`.

### 5. Mutation discipline

Reaching a verdict and posting it are separate decisions. Posting an approval without asking changes who clicks the button, never what earns the click: approval is still earned, never the default, and never granted just because no catastrophic blocker was found.

**Post an approval without asking** when every one of these holds. The point is to keep a clean PR moving while its author is still at their desk.

- The verdict is `approved` or `approved, with suggestions`, and every comment riding along is non-blocking.
- Required checks are green, or the only red ones are unrelated to the diff and the report names them and says why.
- No blocking question is open, and nothing under `Unverified` bears on the approval.
- You re-read every finding at its source yourself. A subagent's report is evidence, not verification.
- The diff touches none of: credentials or authentication, billing, quota or attribution, destructive migrations or data deletion, or an API contract with consumers outside the repository.
- Your approval does not itself trigger an automatic merge. Check before posting when the repository enables auto-merge; approving there means shipping.

Reversing a block you placed yourself is postable on the same terms. You know exactly what you asked for, so verify it was done, say so plainly, and do not make the author wait for a second round trip on work they already did.

**Ask first** in every other case, and always for `changes requested` or `significant issues`. Those spend the author's time, so the person whose name is on the review decides.

1. Present findings, severity classifications, and draft comments to the user.
2. Make the separation explicit in the user-facing report:
   - Lead the recommendation with `My suggestion is ...`
   - Use future tense for mutation, never past tense. Say `I recommend approving`, `I would request changes`, or `I can post this review`, not `approved` / `requested` in a way that implies GitHub state already changed.
   - End the analysis turn with a clear gate: `NEED YOUR APPROVAL TO SUBMIT`.
3. In a follow-up user turn, post with `gh pr review` or `gh api`.

Write the review payload to a file before posting, and post it with `gh pr review` or `gh api --input`. A payload that survives a refused or failed call can be retried or handed to the user verbatim.

When you post without asking, say so in past tense with the review URL, and keep the full findings in that same message. The reader is seeing the reasoning and the action at once, so the reasoning still has to stand on its own.

## Verdicts

The verdict describes the change, not the review. Before requesting changes, state the concrete harm of merging as-is in one sentence: what breaks, who it reaches, and what it costs. If you cannot name that harm, the verdict is `approved, with suggestions`. Blocking a net-positive change over a description error or a stylistic disagreement costs the author real time and spends the trust the next review needs.

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
