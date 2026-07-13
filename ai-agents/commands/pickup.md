---
description: Bootstrap a session from a handoff document
agent: build
---

You are starting a new session by picking up work from a previous session's handoff document.

## Step 1: Locate and read the handoff document

The handoff name is: `$ARGUMENTS`

Read the file at: `~/.local/share/opencode/handoffs/$ARGUMENTS.md`

If the file doesn't exist, list available handoffs in `~/.local/share/opencode/handoffs/` and tell the user which ones are available so they can try again.

## Step 2: Parse the handoff

Extract all sections from the document:
- **Goal** -- what we're trying to accomplish
- **Context** -- repo, branch, worktree, architecture
- **Completed** -- what's already done
- **Pending** -- what still needs to be done
- **Key Decisions** -- decisions made and their rationale
- **Files Touched** -- files that were created or modified
- **Gotchas** -- non-obvious things to watch out for

## Step 3: Validate the current state

Run these checks to confirm the handoff matches reality:

1. **Branch check**: Run `git branch --show-current` and compare to the Context section
2. **File existence**: Verify files listed in "Files Touched" exist on disk
3. **Recent history**: Run `git log --oneline -10` to confirm completed work is present in the commit history
4. **Working tree**: Run `git status --short` to check for uncommitted changes or divergence

## Step 4: Build real context

Read the most important files mentioned in the **Pending** and **Files Touched** sections to build genuine understanding -- don't just trust the handoff descriptions blindly. Focus on:
- Files that have pending work
- Files that were recently modified and are central to the remaining tasks
- Any config or test files relevant to the next steps

## Step 5: Output a session bootstrap

Present a structured summary:

### Validated State
- Confirmed branch, repo, and working tree status
- Which completed items are verified in git history
- Any uncommitted changes present

### Discrepancies
- Anything that doesn't match the handoff (wrong branch, missing files, extra changes)
- If everything checks out, say so briefly

### Action Plan
- Prioritized list of pending items, informed by both the handoff and your reading of the actual code
- Note any dependencies between items
- Flag items that may need clarification before starting

### Open Questions
- Ambiguities or decisions that need user input before proceeding

## Step 6: Register the work

Use the todo list tool to register all pending items so progress can be tracked throughout the session.

## Important

- Do NOT start working on the pending items yet -- just bootstrap the session and present the plan
- Be honest about discrepancies -- if the repo state doesn't match the handoff, surface it clearly
- If the handoff references files or branches that don't exist, flag this prominently
