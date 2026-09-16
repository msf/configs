---
name: send-pr
description: Prepare, size-check, push, create, and monitor pull requests until checks are green and merge state is clean.
---

## What I do
- Send a pull request for the current branch with a CI-green and mergeable guarantee.
- Rebase on `origin/main`, run formatters/tests, push safely, create/update PR, and monitor checks.
- Iterate on failures and valid review feedback until PR checks pass and `mergeStateStatus` is `CLEAN`.

## Review-size gate

Target fewer than 500 changed lines per PR. Small PRs are more likely to receive fast reviews, introduce fewer bugs, carry less risk, and earn higher approval rates.

- Measure additions plus deletions from the intended base's merge base with `git diff --numstat`; inspect both the largest files and the commit sequence. Re-check after generation, formatting, or fixes change the diff and immediately before pushing.
- If the total is under 500 lines, proceed.
- If it is over, separate hand-written logic from allowed bulk: dependency or lock graph updates, generated stubs, large test fixtures or matrices, and deletion-heavy changes. Ordinary test code is not bulk. Verify generated output has the corresponding source change and reproducible generation command.
- Keep non-exempt changes under 500 lines. If they are not, stop before pushing or creating/updating the PR and propose a cohesive, dependency-ordered PR split. Do not use "cohesive" as a blanket exception or split implementation from its tests.
- Proceed with an oversized PR only for allowed bulk or after the user explicitly accepts an unavoidable cohesive exception. Keep exceptional bulk in separate commits when practical; otherwise make commits small and ordered for incremental review.
- For an oversized PR, state in its description the total changed lines, the exceptional files or generated portion, the approximate non-exempt size, and why the split is safe or impractical.

## Workflow
1. Pre-flight
   - Read repo instructions, `git status --short`, branch/upstream configuration, and the intended PR base before changing history.
   - If unrelated local changes make the branch unsafe to send, stop; do not stash or absorb them.
   - Fetch the intended base. If rebasing is required, set `GIT_EDITOR=true GIT_SEQUENCE_EDITOR=true` and rebase onto the fetched base.
   - Re-run repo generation commands if required by repo docs.
   - Verify no unintended drift in protected paths (for example `k8s/prod/`).
   - Apply the review-size gate before mutating remote state.

2. Format and test
   - Run the repo formatter or linter (make lint, cargo fmt, `./gradlew spotlessApply`, etc) )
   - Run the repo tests, if tests fail, fix and re-run.
   - If formatting/tests change files, commit those fixes.
   - If there are no documented format/lint/test commands, report the verification gap; do not add scaffolding just for this PR.

3. Push
   - Re-run the review-size gate against the final committed diff.
   - Use `git push --force-with-lease` after rebase/history rewrite.
   - For a new branch, use an explicit refspec: `git push origin HEAD:refs/heads/<branch>`, then set upstream to `origin/<branch>`. Never rely on an inherited upstream.

4. Create or update PR
   - Read the complete final diff against the intended base before writing the description; statistics and commit titles are not enough.
   - Check for repository PR templates in `.github/`, the repository root, and `docs/`. Preserve the applicable template's required sections and machine-owned fields. If the template choice is ambiguous, ask; do not merge templates.
   - Write the whole description for a human reviewer, in plain, complete English sentences. No fragments, no telegraphic bullets, no file list standing in for an explanation. Never add an agent-context section, a collapsed detail block, or pasted tool output.
   - Open with the outcome in 3-4 sentences: what changed, why, and what a user or operator will notice. Merge dependencies go in the first sentence. Keep one cohesive change as prose; give independent changes a sentence each, and a multi-setting config diff one summary sentence plus one `before → after` bullet per setting.
   - When the change carries behavior, add a short paragraph the reviewer can act on: the few files where a mistake would be expensive (it moves money, corrupts or drops data, changes auth, or breaks a downstream consumer) and what changed in each; the remainder as a count, such as "38 further files are generated fixtures and renames"; which flows you tested and which you did not; and what outside this repository the change reaches, or that nothing does.
   - Do not pad. A behavior-neutral change needs only the opening sentences, and a paragraph you have nothing to say in is left out rather than filled with "N/A".
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
