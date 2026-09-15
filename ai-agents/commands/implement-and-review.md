---
description: Worker implements, code-review skill reviews, worker applies accepted fixes
---
Implement and review: $@

1. Delegate implementation to the `worker` agent with the task scope and worktree context.
2. Read `~/.pi/agent/skills/code-review/SKILL.md` and review the resulting diff. Follow its delegation deadline; review directly when the available tool cannot enforce it.
3. Validate the findings, delegate accepted fixes to `worker` within the original scope, then verify the final diff and tests.
