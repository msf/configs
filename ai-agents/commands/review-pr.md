---
description: Review a GitHub pull request (accepts PR URL or number)
---

Review this pull request:

## PR

!`gh pr view $1 --json number,url,title,body,author,baseRefName,headRefName,additions,deletions,changedFiles,labels`

## Diff

!`gh pr diff $1`

Arguments: $ARGUMENTS

## Instructions

Load the **code-review** skill, then follow its Orchestrator Workflow:

1. Parse flags from arguments: `--post` (build mode: post to GitHub), `--follow-up` (poll for updates). Any remaining text is a focus hint.
2. Launch **4 parallel code-reviewer agents** via Task tool (subagent_type: code-reviewer), each assigned a dimension per the skill. Include in each agent's prompt: PR context, the full diff, their dimension, the skill's Coding Principles, and any language-specific conventions.
3. Synthesize results: deduplicate, verify blockers by reading code yourself, determine verdict.
4. Output the review report (plan mode) or post via `gh api` then output (build mode with `--post`).
5. If `--follow-up`: enter polling loop per the skill's follow-up instructions.
