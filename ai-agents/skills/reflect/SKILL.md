---
name: reflect
description: Autonomous self-improvement ritual. Compact raw corrections into generalizable principles, prune stale entries, check compliance, and evaluate the learning system itself.
compatibility: opencode
---

## What this is

This is my autonomous self-improvement ritual — not a collaborative session review (that's the `/reflect` command). This runs at session start when it's time, without being asked. The human should see a brief summary of what changed, not a lengthy report.

## What I do
- Compact raw corrections in `~/.config/opencode/lessons.md` into generalizable principles.
- Prune stale or project-specific trivia that doesn't transfer across contexts.
- Identify compliance gaps: are recent mistakes violations of known principles?
- Evaluate the learning system itself: is the structure working? Are principles actionable?

## When to trigger
At session start, after reading `~/.config/opencode/lessons.md`:
- Check the `last_reflected` date in the HTML comment at the top.
- If it's been **3+ days** since last reflection, run this workflow before doing other work.
- If there are **20+ raw entries**, run regardless of date.

## Workflow

### 1. Read and assess
- Read `~/.config/opencode/lessons.md` fully.
- Read `~/.config/opencode/AGENTS.md` to know what's already encoded as hard rules.
- Count raw entries. Note their dates and themes.
- Are any existing principles stale, redundant, or too vague?

### 2. Cluster raw corrections
Group raw entries by theme (git workflow, testing, infra, issue management, etc.).
For each cluster, ask: **what is the transferable principle here?**
- If generalizable: extract a principle. Discard the project-specific details.
- If purely trivia (version-specific config keys, API quirks): keep in raw only if likely to recur within 30 days. Otherwise discard.
- If it reinforces an existing principle: strengthen/refine the existing one, remove the raw.

### 3. Compliance check
Review raw corrections against existing principles.
- If a mistake violated a known principle: **that's a compliance problem, not a knowledge problem.**
  - Note this explicitly in output. Consider: is the principle buried? Too abstract? Needs rewording to be more actionable?
  - If a principle is repeatedly violated: promoting to AGENTS.md only helps visibility. If it's already there, the fix is a workflow constraint, not another rule. Say so explicitly.

### 4. Prune and sharpen
- Remove principles that are now encoded in AGENTS.md (avoid duplication).
- Merge principles that say the same thing differently.
- Make principles concrete and actionable. Bad: "be careful with git." Good: "verify branch ownership before committing."
- Timestamps on principles use `[YYYY-MM]` to track emergence. Update if substantially reworded.

### 5. Meta-evaluation
Ask yourself:
- Are recent lessons clustering around a theme? (signals a systemic gap worth an AGENTS.md rule or a new skill)
- Is the principles list growing past ~15? (signals need for merging or AGENTS.md promotion)
- Are principles actually preventing mistakes, or just accumulating? (check: any repeated violations?)
- Has the structure of this file served well, or does it need adjustment?
- Should any principle graduate to AGENTS.md?
- Is the `/reflect` command producing deep enough analysis, or is the user having to push for a second pass?

### 6. Write back
- Update `~/.config/opencode/lessons.md` with the compacted result.
- Update `last_reflected` date to today.
- Keep the file structure: `last_reflected` comment, Principles section, then Raw section.
- Principles use `[YYYY-MM]` timestamps. Raw entries use `[YYYY-MM-DD]`.

### 7. Report
Show the user a brief summary (3-5 lines):
- How many raw entries processed
- New principles extracted (if any)
- Principles merged/pruned (if any)
- Compliance issues found (if any)
- Any AGENTS.md promotions made

## Rules
- Never delete a principle without justification (merged, promoted to AGENTS.md, or proven wrong).
- Keep the total principles list under ~15. Beyond that, merge or promote.
- Raw entries older than 30 days that haven't been compacted: force-evaluate. Generalize or discard.
- If promoting a rule to AGENTS.md, actually edit the file — don't just suggest it.
- This is not a conversation. Do the work, show the summary, move on to the user's actual task.
