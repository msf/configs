---
name: send-pr
description: Prepare cohesive pull requests with small, well-explained commits; push, create, and monitor them until checks are green and merge state is clean.
---

## What I do
- Send a pull request for the current branch with a CI-green and mergeable guarantee.
- Rebase on `origin/main`, run formatters/tests, push safely, create/update PR, and monitor checks.
- Iterate on failures and valid review feedback until PR checks pass and `mergeStateStatus` is `CLEAN`.

## Commit review gate

Load the `coding` skill's change-sequencing and commit-message rules. Target at most 500 changed lines per commit; PRs have no line-count limit. Group related commits into a logically complete PR, and split PRs only at meaningful review, dependency, or rollout boundaries—not to meet a size target.

- Enumerate the commits introduced since the intended base's merge base, in dependency order. Measure each commit's additions plus deletions against its parent with `git diff --numstat <commit>^ <commit>`; inspect merge commits explicitly rather than treating an empty merge summary as zero changes. Re-check after generation, formatting, or fixes and immediately before pushing.
- For a commit over 500 lines, separate hand-written logic from allowed bulk: dependency or lock graph updates, generated stubs, large test fixtures or matrices, and deletion-heavy changes. Ordinary test code is not bulk. Verify generated output has the corresponding source change and reproducible generation command; isolate bulk when practical.
- If a commit's non-exempt portion exceeds 500 lines, stop before pushing or creating/updating the PR and propose splitting that commit within the same PR. Keep each commit buildable and tested; do not separate behavior from its tests to meet the target. Proceed with an unavoidable larger hand-written commit only after the user agrees. The PR's total size requires neither an exception nor a size justification in its description.
- Read every commit message against its diff: a specific imperative subject, with a concise why/how body when needed. Keep messages shorter than the PR description and scoped to the commit; no review-order section. The PR description explains the combined outcome and may still include a suggested review order.

## Workflow
1. Pre-flight
   - Read repo instructions, `git status --short`, branch/upstream configuration, and the intended PR base before changing history.
   - If unrelated local changes make the branch unsafe to send, stop; do not stash or absorb them.
   - Fetch the intended base. If rebasing is required, set `GIT_EDITOR=true GIT_SEQUENCE_EDITOR=true` and rebase onto the fetched base.
   - Re-run repo generation commands if required by repo docs.
   - Verify no unintended drift in protected paths (for example `k8s/prod/`).
   - Apply the commit review gate before mutating remote state.

2. Format and test
   - Run the repo formatter or linter (make lint, cargo fmt, `./gradlew spotlessApply`, etc) )
   - Run the repo tests, if tests fail, fix and re-run.
   - If formatting/tests change files, commit those fixes.
   - If there are no documented format/lint/test commands, report the verification gap; do not add scaffolding just for this PR.

3. Push
   - Re-run the commit review gate against the final commit sequence.
   - Use `git push --force-with-lease` after rebase/history rewrite.
   - For a new branch, use an explicit refspec: `git push origin HEAD:refs/heads/<branch>`, then set upstream to `origin/<branch>`. Never rely on an inherited upstream.

4. Create or update PR
   - Read the complete final diff against the intended base before writing the description; statistics and commit titles are not enough.
   - Check for repository PR templates in `.github/`, the repository root, and `docs/`. Preserve the applicable template's required sections and machine-owned fields. If the template choice is ambiguous, ask; do not merge templates.
   - If the diff adds or changes a README or docs page, check it against the `tech-writing` skill's rules for repository docs before writing the description.
   - Write the description for a reviewer from another team. Relevance decides what goes in, not a length budget. Use these parts in order, and leave out any that don't apply:
     1. **Why**: the problem or goal and any constraint the change works under (for example, live changes only, no restarts), in plain sentences a reviewer understands on first read: one idea per sentence, no unexplained codenames or acronyms. The merge dependency, the PR's place in its stack, and the links the reviewer needs (issue, dashboard, runbook) go here.
     2. **How**, when the change carries a design: who does what (data flow, threads, ownership), the guarantees it keeps (bounded memory, failure modes), and the trade-off you accepted. Explain the complete design in this PR, using its logical parts and commit sequence where helpful. Do not assume a non-trivial change needs a stack. If a meaningful boundary does require multiple PRs, explain the split and link their dependencies.
     3. **Important settings**, when the PR mainly changes settings or config: the settings that matter, each with its value (`before → after` when it had one), what it does, and why. Choose them by relevance; a large config diff doesn't need every setting explained. On such a PR this part usually takes the place of How.
     4. **The changes**, one per line, in the active voice, each line starting with its verb and carrying its reason.
     5. **Suggested review order**, when the PR spans several files: numbered `path`, then what to look at there, ordered so understanding builds (core logic, then wiring, then tests). Leave it out of a one- or two-file PR.

     ```markdown
     The current exporter shares a lock with the I/O workers, so recording a metric can stall a request.

     This PR adds per-worker counters and a way for one publisher thread to read them without blocking the workers.
     Each worker keeps adding to its own counters. Every 10 s the publisher reads all of them, turns totals into deltas, and sends the deltas.
     Memory per worker is fixed, and a slow or failed send loses nothing: the counters keep adding up until the next send succeeds.
     This is more code than a shared registry, but the workers never take a lock.

     - Adds the `metrics` crate: one fixed-size block of counters per worker, written only by that worker
     - Indexes counters by fixed enums and buckets, so recording never allocates or locks
     - Publishes counter deltas from a separate thread so sending never blocks workers
     - Records request metrics through the per-worker counters

     ## Suggested review order
     1. `crates/metrics/src/lib.rs`: `Block`, `record`, and the fixed bucket bounds
     2. `crates/metrics/src/publisher.rs`: delta tracking and send failures
     3. `crates/server/src/worker.rs`: request instrumentation
     4. `crates/metrics/tests/publisher.rs`: failed-send recovery
     ```

   - Leave out future work, "not in this PR" and "no X yet" lists, open items, test logs, and internal review history; they belong in the conversation or the notes.
   - Say what runs outside this repository on merge (a deploy, a production apply), and mention validation or rollout process only as far as a reviewer needs it.
   - When updating a PR, re-read the live description first and keep the user's text verbatim. Rewrite the rest to describe the current diff, not the history of its revisions.
   - Link a user-provided or confirmed issue with `Fixes ISSUE-ID` only when fully resolved, or `Towards ISSUE-ID` for partial progress. Never invent an issue reference.
   - If PR does not exist, create it via `gh pr create`; otherwise reuse it and continue.
   - If arguments are provided to the skill invocation, use them as PR title.

5. Monitor CI and feedback loop
   - Poll `gh pr checks <number>` every 30-60s until checks complete.
   - On failed checks, inspect logs (`gh run view <run-id> --log-failed`), fix, commit, push, and resume monitoring.
   - If branch becomes out-of-date (`mergeStateStatus` not `CLEAN`), rebase/regenerate/push and continue.
   - Review PR comments (human and bots); apply valid suggestions, explain rejected ones briefly, and report uncertain ones.
   - After the commit addressing a review comment is pushed, re-read the remote diff, reply when useful, and resolve that review thread. Never resolve a thread before its fix is upstream, or when the concern remains open or was declined.

6. Done
   - Finish only when all checks are green, every addressed review thread is resolved, and `mergeStateStatus` is `CLEAN`.
   - Final check if branch is outdated and needs rebase from origin/main again.
   - Output the PR URL.

## Safety rules
- Never force push to `main`/`master`.
- Never bypass pre-commit hooks.
- Keep iterating until green and mergeable.
