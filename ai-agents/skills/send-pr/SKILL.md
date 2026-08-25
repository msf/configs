---
name: send-pr
description: Prepare, push, create, and monitor pull requests until checks are green and merge state is clean.
---

## What I do
- Send a pull request for the current branch with a CI-green and mergeable guarantee.
- Rebase on `origin/main`, run formatters/tests, push safely, create/update PR, and monitor checks.
- Iterate on failures and valid review feedback until PR checks pass and `mergeStateStatus` is `CLEAN`.

## Workflow
1. Pre-flight
   - Read repo instructions, `git status --short`, branch/upstream configuration, and the intended PR base before changing history.
   - If unrelated local changes make the branch unsafe to send, stop; do not stash or absorb them.
   - Fetch the intended base. If rebasing is required, set `GIT_EDITOR=true GIT_SEQUENCE_EDITOR=true` and rebase onto the fetched base.
   - Re-run repo generation commands if required by repo docs.
   - Verify no unintended drift in protected paths (for example `k8s/prod/`).

2. Format and test
   - Run the repo formatter or linter (make lint, cargo fmt, `./gradlew spotlessApply`, etc) )
   - Run the repo tests, if tests fail, fix and re-run.
   - If formatting/tests change files, commit those fixes.
   - If there are no documented format/lint/test commands, report the verification gap; do not add scaffolding just for this PR.

3. Push
   - Use `git push --force-with-lease` after rebase/history rewrite.
   - For a new branch, use an explicit refspec: `git push origin HEAD:refs/heads/<branch>`, then set upstream to `origin/<branch>`. Never rely on an inherited upstream.

4. Create or update PR
   - If PR does not exist, create it via `gh pr create`.
   - Write for review scanning: lead with the outcome. Use 2-3 sentences for one cohesive change; for multi-setting/config diffs, use one summary sentence plus one `before → after` bullet per independent setting. Put merge dependencies in the opening sentence.
   - If PR exists, reuse it and continue.
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
