---
name: weekly-review
description: Analyze recent sessions to find patterns, recurring mistakes, and propose improvements to AGENTS.md and lessons.md.
compatibility: opencode
---

## What this is

A periodic deep review of how the user and assistant work together. Reads session
history from the database, dispatches parallel agents to analyze conversations,
then runs multiple reflection loops to surface patterns and propose changes.

## When to trigger

User runs `/review-week`. Not autonomous — this is a deliberate review.

## Inputs

- `$ARGUMENTS`: optional time range in days (default: 7). Example: `/review-week 14`

## Data sources

Review all active harness stores, not just the current harness:
- Opencode SQLite: `~/.local/share/opencode/opencode.db`
- Pi JSONL: `~/.pi/agent/sessions/**/*.jsonl` and `~/.pi/agent-lean/sessions/**/*.jsonl` when present

Opencode key tables:
- `session`: metadata (id, title, directory, time_created, time_updated)
- `message`: per-session messages (id, session_id, data JSON)
- `part`: message content (id, message_id, session_id, data JSON with `type` and `text` fields)

Pi JSONL key records:
- `{"type":"session", "id": ..., "timestamp": ..., "cwd": ...}`
- `{"type":"message", "message":{"role": ..., "content":[...]}}`

For manifests, use IDs/paths/counts/titles only. Do not print raw snippets until redacted.

## Workflow

### 1. Gather sessions

```sql
SELECT id, title, directory,
  datetime(time_created/1000, 'unixepoch', 'localtime') as created,
  datetime(time_updated/1000, 'unixepoch', 'localtime') as updated
FROM session
WHERE time_created > (strftime('%s', 'now', '-N days') * 1000)
  AND title NOT LIKE '%@explore%'
  AND title NOT LIKE '%@general%'
ORDER BY time_created ASC;
```

Replace `N` with the requested day range. If the default window is sparse or empty,
find the last weekly-review session and propose a meaningful fallback window
(usually 21-30 days or since last review) before analyzing.

Filter out subagent sessions — they're noise for pattern analysis. For Pi JSONL,
exclude sessions whose first user message starts with `Task:` and exclude the
current review session.

Count messages per session to find the substantive ones (>3 messages).

### 2. Dispatch parallel agents

Group substantive sessions into 3-5 batches. For each batch, launch a `general`
subagent with instructions to:

1. Extract conversation text.

   For Opencode sessions:
   ```sql
   SELECT json_extract(m.data, '$.role') AS role,
          json_extract(p.data, '$.text') AS text
   FROM part p
   JOIN message m ON m.id = p.message_id
   WHERE m.session_id = 'SESSION_ID'
     AND json_extract(p.data, '$.type') = 'text'
   ORDER BY p.time_created ASC;
   ```

   For Pi JSONL sessions, parse `type="message"` records and extract only
   `message.role` plus text content items from `message.content`. Skip thinking,
   tool calls, and tool results unless needed for a correction; never quote secrets.
2. For each session, identify:
   - What the user was trying to accomplish
   - Corrections the user made to the assistant
   - Frustration signals
   - Where the assistant over- or under-delivered
   - Design decisions and their quality
3. Return a comprehensive analysis focused on patterns and lessons, not summaries.

### 3. Read context files

While agents run, read:
- `~/.config/opencode/AGENTS.md`
- `~/.config/opencode/lessons.md`

### 4. Reflection loops

Run 2-3 passes over the combined agent output:

**Loop 1 — Patterns:** What themes repeat across sessions? Which are the most
frequent and most damaging? Cross-reference against existing AGENTS.md and
lessons.md rules — are these known problems (compliance failure) or new gaps?

**Loop 2 — Design problems:** Why does the system produce these failures?
What's the root cause behind the patterns? Are existing rules too vague,
misplaced, or structurally unenforceable?

**Loop 3 — Proposals:** Concrete, minimal changes. Prefer strengthening existing
rules over adding new ones. Every proposed change must map to a specific pattern
found in the data.

### 5. Present findings

Show the user:
- Session count and coverage
- Top patterns with frequency and severity
- The compliance question: which patterns already have rules?
- Proposed changes as exact edits (old → new)

### 6. Apply changes

After user approval, edit AGENTS.md and lessons.md. Auto-apply with confirmation
on each change.

## Rules

- Never add more than ~15 lines to AGENTS.md in one review. If you need more, the
  rules aren't sharp enough.
- Prefer rewriting existing sections over adding new ones.
- The "Compliance > new rules" principle applies here: if a pattern violates an
  existing rule, say so and propose strengthening the rule, not adding another.
- Show exact diffs for every proposed change. No vague "we should improve X."
- This is collaborative — present, discuss, then apply. Don't auto-apply without
  the user seeing the proposals.
