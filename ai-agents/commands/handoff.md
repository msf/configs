---
description: Generate a handoff document and save it to disk
agent: build
---

Analyze this entire conversation and generate a structured handoff document that another session can use to resume this work seamlessly. Save the document to disk so it can be picked up later with `/pickup`.

## Step 1: Determine the filename

If the user provided a name via arguments, use it: `$ARGUMENTS`

If no argument was provided (the above is empty or blank), generate a default name using this format:

```
<repo-or-dirname>@<branch>-<YYYY-MM-DD>
```

Where:
- `<repo-or-dirname>` is the repository name (from `basename $(git remote get-url origin 2>/dev/null | sed 's/.*\///' | sed 's/\.git$//')` or `basename $(pwd)` as fallback)
- `<branch>` is the current git branch (from `git branch --show-current`)
- `<YYYY-MM-DD>` is today's date

Example: `core@fix-auth-crash-2026-02-25`

## Step 2: Generate the handoff document

Write a markdown document with the following structure (no extra wrapping, just these headings as the top-level structure of the file):

### Goal
<What we're trying to accomplish -- one or two sentences>

### Context
<Repo, branch, worktree, relevant architectural context>

### Completed
<What's been done, with specific file paths and line-level changes>

### Pending
<What still needs to be done, in priority order>

### Key Decisions
<Important decisions made during this session and their rationale>

### Files Touched
<List of files created or modified, with a one-line description of each change>

### Gotchas
<Non-obvious things the next session needs to know -- quirks discovered, failed approaches, things that almost worked>

## Step 3: Save the file

1. Create the directory if it doesn't exist: `mkdir -p ~/.local/share/opencode/handoffs`
2. Write the document to: `~/.local/share/opencode/handoffs/<filename>.md`

## Step 4: Output

Only output the saved file path to the conversation. Do NOT output the full document contents. Format:

```
Handoff saved to ~/.local/share/opencode/handoffs/<filename>.md
```

## Content guidelines

- Be specific: include file paths, function names, config values, error messages
- Include any deferred items explicitly marked as such
- Note any dependencies between pending items
- If there are open questions or ambiguities, list them
- The document must be self-contained -- a new session with no prior context should be able to pick up where we left off
- Keep it concise. Skip completed items that have no bearing on remaining work.
