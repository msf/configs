---
description: Analyze changes and output git add + commit commands grouped by logical change
subtask: true
agent: commit-planner
---

Analyze the current uncommitted changes and produce a sequence of git commands
to create well-structured commits. Output commands only -- do not execute them.

Start by running `git status --short` and `git diff --stat` to understand the
scope of changes. Then selectively `git diff <file>` for files you need to
inspect in detail for grouping decisions. Do NOT dump the entire diff at once
if there are many changed files.

Context from the user (if provided): $ARGUMENTS

## Instructions

1. Analyze all changes (staged, unstaged, and relevant untracked files)
2. Group changes into logical commits by architectural layer:
   - Config/types first, then implementation, then tests
   - Separate infra (k8s/, terraform) from code
   - Separate migrations from application code
   - Proto/API definition changes get their own commit
3. For each commit, output the exact commands:
   - `git add <file>` for whole files
   - When a file has changes belonging to different commits, provide
     `git add -p <file>` with clear instructions on which hunks to
     stage (describe the hunk by function name, line range, or content)
   - `git commit -m "<message>"` (or `-m "<subject>" -m "<body>"` when
     a body is warranted)
4. Ignore untracked files that aren't part of the logical change (.DS_Store,
   IDE configs, temp files, etc.)
5. Respect already-staged changes -- don't unstage them
6. Prefer whole-file adds. Only use `git add -p` when a file genuinely
   contains changes for two different logical commits.

## Commit Message Style

Detect the repo and apply the right style:

**erpc repo**: Conventional Commits with scope
- `feat(module): short description`
- `fix(module): short description`
- `test: short description`
- Scope = Go package/module name

**All other Dune repos**: Free-form imperative
- Capitalized, imperative mood: "Add ...", "Fix ...", "Remove ...", "Refactor ..."
- 40-70 characters, no trailing period
- No conventional commit prefix

**Body**: Only when the change is complex enough that the subject line alone
doesn't explain the "why". Keep it brief. No ticket references -- those go in
the PR description.

## Output Format

Output a single code block with all commands, with comments explaining each commit:

```bash
# Commit 1: <brief description of what this commit does>
git add path/to/file1
git add -p path/to/file2  # Stage only the hunk adding the new struct (lines ~45-60)
git commit -m "Add datashare target region config"

# Commit 2: <brief description>
git add path/to/file3
git commit -m "Implement Snowflake target client for datashare"
```

Do not suggest `git add .` or `git add -A`. Always be explicit about files.
