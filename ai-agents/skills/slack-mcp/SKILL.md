---
name: slack-mcp
description: Use official Slack MCP from Pi for Slack workspace search/read tasks. Load when the user asks about Slack channels, threads, messages, DMs, canvases, users, or workspace activity.
---

# Slack MCP

Use the official Slack MCP as the primary Slack path.

## Load and authenticate

- MCP endpoint: `https://mcp.slack.com/mcp`.
- Pi MCP bridge server: `slack`.
- If `slack__*` tools are not visible, run `/mcp-load slack`.
- If loading or authentication fails, report the bridge error and stop. Do not read another harness's credential cache or hand-roll authenticated requests.
- Never print, paste, copy, or summarize OAuth tokens.

## Tools

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
