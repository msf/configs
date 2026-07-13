---
name: pr-triage
description: Proactively surface open PRs that need the user's review — PRs where they are a requested reviewer and PRs authored by their team. Use when the user asks for daily review queue, "what should I review today", PR triage, or any variation of proactively checking for review work.
compatibility: opencode
---

## Purpose

Build a ranked review queue so the user reviews proactively instead of reactively. This skill **only discovers and ranks**. Actual reviewing is delegated to the `code-review` skill, one PR at a time, with explicit user approval.

## Scope

Org, user, and team come from `~/.config/pr-triage.conf` (shell vars `ORG`, `ME`, `TEAM`; override path via `PR_TRIAGE_CONF`). Team members are fetched live via `gh api /orgs/$ORG/teams/$TEAM/members`.

Two sources feed the queue:

1. **Assigned** — open PRs where `$ME` or `$ORG/$TEAM` is a requested reviewer.
2. **Team** — open non-draft PRs authored by other `$TEAM` members in `$ORG`.

## Workflow

### 1. Gather

Run `scripts/queue.sh` (or inline the commands from it). It emits a JSON array with fields: `source`, `repo`, `number`, `title`, `author`, `url`, `updatedAt`, `isDraft`, `ageDays`, `myReviewState`.

Rules applied by the script:
- Drop drafts.
- Drop PRs authored by `$ME`.
- Dedupe across the two sources (assigned takes precedence).
- Drop PRs already reviewed by `$ME` where the review state is `APPROVED` or `CHANGES_REQUESTED`, **unless** there is a re-request pending (`$ME` or `$TEAM` appears in current `requestedReviewers` / `requestedTeams`).
- Drop PRs untouched for more than 21 days (stale — surface separately at the bottom if any).

### 2. Rank

Sort by:
1. `source == "assigned"` first (explicit ping).
2. Oldest `updatedAt` first within each source — stale work ages worst.
3. Tie-break by repo name.

### 3. Present

Show a compact table to the user. For each PR include: source tag (`ASSIGNED` / `TEAM`), repo, #number, author, age (`Xd`), one-line title, URL, CI state if easily available.

Then propose the top 1–3 to review now. Do not start reviewing until the user picks.

### 4. Hand off

Once the user picks a PR, load the `code-review` skill and follow its workflow. One `code-reviewer` subagent per PR. Never batch-review from this skill.

## Commands

Fast, copy-pasteable. These are what `scripts/queue.sh` wraps.

```bash
source ~/.config/pr-triage.conf   # ORG, ME, TEAM

# Assigned to me
gh search prs --owner="$ORG" --state=open --review-requested=@me \
  --json number,title,repository,author,url,updatedAt,isDraft --limit 50

# Assigned to the team
gh search prs --owner="$ORG" --state=open \
  --review-requested="$ORG/$TEAM" \
  --json number,title,repository,author,url,updatedAt,isDraft --limit 50

# Authored by teammates (fetch members first)
for u in $(gh api "/orgs/$ORG/teams/$TEAM/members" --jq '.[].login' | grep -vx "$ME"); do
  gh search prs --owner="$ORG" --state=open --author="$u" \
    --json number,title,repository,author,url,updatedAt,isDraft --limit 50
done

# Per-PR: have I already reviewed it?
gh api "repos/<org>/<repo>/pulls/<n>/reviews" \
  --jq "[.[] | select(.user.login==\"$ME\")] | last | .state"

# Per-PR: current requested reviewers (user + team)
gh pr view <n> --repo <org>/<repo> \
  --json reviewRequests --jq '.reviewRequests'
```

## Guardrails

- Read-only. Never post reviews from this skill — that's `code-review`.
- Do not auto-spawn review subagents. Discovery ends with a table and a proposal.
- Team membership can drift; re-fetch it when the queue surprises the user.
- If `gh` is unauthenticated, stop and tell the user to fix auth.
