---
description: Review this session together and extract lessons
---

Analyze this conversation and extract improvements. This is a collaborative review — present findings, discuss with the user, then persist agreed-upon lessons.

## Instructions

Review the full conversation history and identify:

### 1. Corrections and mistakes
- Where you were corrected or needed clarification
- Wrong assumptions that caused rework
- Questions you should have asked earlier

### 2. New rules
Specific, actionable rules that would prevent the same mistakes:
- Generic rules (transferable across projects)
- Project-specific context future sessions should know

### 3. Process improvements
- Better workflows or tool usage patterns
- Where the user had to repeat preferences
- Missing context that would have helped upfront

### 4. Prompt improvements
How the user could be more effective:
- Better ways to structure requests
- Useful context to provide proactively

### 5. Deep analysis: contrast with existing rules
Read `~/.config/opencode/lessons.md` and `~/.config/opencode/AGENTS.md` before presenting findings.

For each mistake or correction found in steps 1-4, check:
- Does a rule or principle ALREADY exist that should have prevented this?
- Has the SAME underlying principle been violated in prior raw entries?
- If yes: this is a compliance/behavioral failure, not a knowledge gap. Adding another rule won't help. Diagnose WHY the existing rule failed:
  - (a) Rule is too abstract to trigger in the moment → reword it
  - (b) Action was batched/parallelized and fired before conscious check → needs workflow constraint (hard stop between phases)
  - (c) Rule applies to a different phase than where the mistake happened → needs promotion or restructuring
- If no existing rule covers it: propose one, but keep it minimal — one rule per genuine gap.

The goal is to go one level deeper than "here's what went wrong." The question is: **is this a problem of missing rules, missing runbooks, missing verification, or repeated non-compliance with existing rules?** Each has a different fix. Don't prescribe rules for behavioral problems.

## Output

Present findings concisely. Each rule must be specific enough to guide future behavior — no vague observations.

After discussion with the user, append agreed-upon lessons to `~/.config/opencode/lessons.md` under the Raw section with today's date as `[YYYY-MM-DD]` timestamps.
