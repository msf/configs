---
name: send-pr
description: Prepare, push, create, and monitor pull requests until checks are green and merge state is clean.
compatibility: opencode
---

## What I do
- Send a pull request for the current branch with a CI-green and mergeable guarantee.
- Rebase on `origin/main`, run formatters/tests, push safely, create/update PR, and monitor checks.
- Iterate on failures and valid review feedback until PR checks pass and `mergeStateStatus` is `CLEAN`.

## Workflow
1. Pre-flight
   - Ensure branch is clean. If not, create a new branch and commit the current working changes.
   - Run `git fetch origin main`.
   - If branch is behind main, run `git rebase origin/main` and resolve conflicts.
   - Re-run repo generation commands if required by repo docs.
   - Verify no unintended drift in protected paths (for example `k8s/prod/`).

2. Format and test
   - Run the repo formatter or linter (make lint, cargo fmt, `./gradlew spotlessApply`, etc) )
   - Run the repo tests, if tests fail, fix and re-run.
   - If formatting/tests change files, commit those fixes.
   - If there are no documented format/lint/test commands, report that and propose adding a `Makefile` with standard targets.

3. Push
   - Use `git push --force-with-lease` after rebase/history rewrite.
   - If branch is new, use `git push -u origin <branch>`.

4. Create or update PR
   - If PR does not exist, create it via `gh pr create` with a concise 2-3 sentence summary.
   - If PR exists, reuse it and continue.
   - If arguments are provided to the skill invocation, use them as PR title.

5. Monitor CI and feedback loop
   - Poll `gh pr checks <number>` every 30-60s until checks complete.
   - On failed checks, inspect logs (`gh run view <run-id> --log-failed`), fix, commit, push, and resume monitoring.
   - If branch becomes out-of-date (`mergeStateStatus` not `CLEAN`), rebase/regenerate/push and continue.
   - Review PR comments (human and bots); apply valid suggestions, explain rejected ones briefly, and report uncertain ones.

6. Done
   - Finish only when all checks are green and `mergeStateStatus` is `CLEAN`.
   - final check if branch is outdated and needs rebase from origin/main again
   - Output the PR URL.

## Merging stacked PRs

When PRs are stacked (PR B targets branch A, not main), merging requires careful ordering to avoid GitHub auto-closing dependent PRs when `delete_branch_on_merge` is enabled (common repo setting).

**Before merging PR A (the base):**
1. Check if any open PR targets branch A as its base: `gh pr list --repo <repo> --json number,title,baseRefName | jq '.[] | select(.baseRefName == "<branch-A>")'`
2. For each dependent PR found, retarget it first: `gh pr edit <N> --base main` (or the new target)
3. Only then merge A: `gh pr merge <A>`

**Order of operations:**
```
retarget B → main
merge A (branch A gets deleted)   # B is safe, already points at main
retarget C → main
merge B
...
```

**Never** run `gh pr merge <base-pr>` without first checking for and retargeting dependents.
Failure to do so causes GitHub to auto-close any PR whose base branch is deleted — and GitHub will not allow reopening or retargeting a closed PR via API.

## Safety rules
- Never force push to `main`/`master`.
- Append changes, don't overwrite existing commits.
- Never bypass pre-commit hooks.
- Keep iterating until green and mergeable.
