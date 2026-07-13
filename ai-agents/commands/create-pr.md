---
description: Create a pull request for the current branch (git + gh; auto-detects Graphite if you use it)
subtask: true
---

Create a pull request for the current branch.

If a `github-cli` skill is available, load it before starting; otherwise follow the rules inline below.

This command works with plain `git` + `gh` by default. If your branch is managed by Graphite
(`gt`), it will use the Graphite submit path instead -- detected automatically below.

## Current State

### Graphite tracking (auto-detect)

!`command -v gt >/dev/null 2>&1 && gt ls 2>/dev/null | grep -q "$(git branch --show-current)" && echo "GRAPHITE_TRACKED" || echo "PLAIN_GIT"`

### Commits on this branch

!`git log --oneline $(git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null)..HEAD 2>/dev/null || echo "NO_COMMITS"`

### Changed files

!`git diff --stat $(git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null)..HEAD 2>/dev/null || echo "NO_DIFF"`

## Arguments

User-provided context: $ARGUMENTS

Parse the following from `$ARGUMENTS` (all optional):
- **Linear issue ID** -- any token matching a `TEAM-123` pattern.
- **Reviewers** -- tokens after `--reviewer` or `-r` (comma-separated team slugs or usernames;
  prefix team slugs with the GitHub org if not already).
- **`--ready`** -- if present, mark the PR ready for review after creation. Default is draft.
- **`--merge`** -- if present, enable auto-merge when ready.
- Everything else is additional context for the PR description.

## Workflow

### Step 1: Read the full diff

Run `git diff $(git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null)..HEAD`
to read the complete diff. You need this to write a good description.

### Step 2: Write the PR description

Follow the PR description style:

- **Small/trivial changes**: empty body or a single sentence
- **Medium changes**: short prose paragraph explaining what and why
- **Larger changes**: a few paragraphs, optional `## Summary` / `## Context` headings

Rules:
- Terse prose paragraphs -- NOT bullet-point lists under headings
- Don't enumerate every file changed or produce tables of changes
- Don't produce `## Summary` + `## Changes` + `## Behavior` + `## Impact` scaffolding
- No "This PR..." preamble
- Use backticks for code identifiers
- Link to Slack threads if the user provided them
- If a Linear issue ID was provided, end with it on its own line:
  - `Fixes ISSUE-ID` -- when the PR fully resolves the issue
  - `Towards ISSUE-ID` -- when the PR contributes to but doesn't complete it
- If no Linear issue ID was provided, optionally search for a relevant issue (branch name, commit
  messages, context) and present any match for confirmation. If nothing is found, ask or omit.
- NEVER include a Linear reference that wasn't provided by the user or confirmed by them.

### Step 3: Confirm with user

Show the proposed **title** (imperative mood), the full **description**, the **reviewers**, and
whether it will be **draft** or **ready**. Ask the user to confirm or adjust before proceeding.

### Step 4: Push and create the PR

Never use `git add .` / `git add -A`; if there are unstaged changes, warn the user and stop.

**If the state above is `GRAPHITE_TRACKED`** (the user uses Graphite), submit via Graphite -- do
NOT use `git push` or `gh pr create`, which break stack tracking:
```bash
gt submit --no-edit --no-ai            # add --merge-when-ready if --merge was passed
```
If it fails with "needs restack", run `gt r` then retry. Then set metadata with `gh` (Step 5).

**Otherwise (plain git)**, push and open the PR directly:
```bash
git push -u origin "$(git branch --show-current)"
gh pr create --draft --title "<title>" --body "$(cat <<'EOF'
<description>
EOF
)"
```
Add `--reviewer <r1>,<r2>` if reviewers were specified. (Use `gh pr create` without `--draft` only
if you prefer; default to draft and promote in Step 6.)

### Step 5: Set / adjust PR metadata

For the Graphite path (or to amend the plain-git PR), set title, body and reviewers:
```bash
gh pr edit <number> --title "<title>" --body "$(cat <<'EOF'
<description>
EOF
)"
gh pr edit <number> --add-reviewer <reviewer1>,<reviewer2>   # if reviewers were specified
```

### Step 6: Mark ready (if requested)

If `--ready` was passed:
```bash
gh pr ready <number>
```
Default is to leave it as a draft.

### Step 7: Report

Show the GitHub PR URL, draft/ready status, reviewers assigned, and the full PR description.

## Key Rules

- **NEVER** use `git add .` or `git add -A` -- stage explicit paths; warn on unstaged changes.
- If the branch is Graphite-tracked, **never** use `git push` / `gh pr create` -- use `gt submit`.
- If you're not sure whether the user uses Graphite, trust the auto-detected state above.
- Default to **draft** PRs unless `--ready` was passed.
