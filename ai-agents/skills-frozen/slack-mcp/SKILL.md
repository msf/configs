---
name: slack-mcp
description: Frozen Slack MCP reference. Invoke explicitly only to inspect the retired workflow.
---

# Slack MCP

**Frozen.** The native `slack` server is disabled. Do not load, authenticate, or query Slack unless the user explicitly asks to unfreeze it. The instructions below are historical, not active routing.

## Load and authenticate

- MCP endpoint: `https://mcp.slack.com/mcp`.
- Native Pi MCP server: `slack`, disabled in `~/.pi/agent/mcp.json`.
- Only after explicit unfreeze approval: use `/mcp` to enable the server, then `/mcp login slack` if needed. Enabling persists across sessions and both Pi profiles.
- Find `mcp__slack__*` tools through codemode discovery, not direct tool visibility.
- If loading or authentication fails, report the native MCP error and stop. Do not read another harness's credential cache or hand-roll authenticated requests.
- Never print, paste, copy, or summarize OAuth tokens.

## Historical tool names

Native Pi prefixes each name below with `mcp__`.

- `slack__slack_search_channels`: find channel IDs.
- `slack__slack_search_public_and_private`: search authorized public/private channels, DMs, and MPIMs.
- `slack__slack_search_public`: search public channels only.
- `slack__slack_read_channel`: read channel history by channel ID.
- `slack__slack_read_thread`: read a thread by channel ID and root message timestamp.
- `slack__slack_search_users` and `slack__slack_read_user_profile`: resolve users and read profiles.
- `slack__slack_read_canvas`: read canvases.

## Workflow

1. Resolve user and channel IDs instead of relying on remembered IDs or another tool's cache.
2. Prefer a channel read for recent context in a known channel.
3. Use search when the channel is unknown or the request spans channels.
4. Scope searches by user, channel, and date when possible.
5. Read the root thread when a matching message has replies.
6. Return only the context needed to answer the request.

Useful Slack search query shapes:

```text
from:<@USER_ID> in:<#CHANNEL_ID>
"exact phrase" after:YYYY-MM-DD
query terms in:<#CHANNEL_ID> after:YYYY-MM-DD
```

## Safety

- Read and search only when the user asks for Slack information.
- Ask before sending or scheduling messages, creating drafts, or creating or updating canvases.
- Treat Slack output as sensitive. Quote only necessary excerpts.
- Prefer `include_context=false` for search unless adjacent messages are needed.
- Do not broaden a private-channel or DM request beyond the people and period needed.
