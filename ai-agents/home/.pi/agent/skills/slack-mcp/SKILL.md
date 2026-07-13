---
name: slack-mcp
description: Use official Slack MCP from Pi for Slack workspace search/read tasks. Load when the user asks about Slack, Slack channels/threads/DMs/canvases/users, Dune team channels like DWH/warehouse, or asks what they/someone wrote in a work channel.
---

# Slack MCP

Use this as the primary Slack path. Do not fall back to `pi-slack` unless Slack MCP auth is unavailable or the user explicitly asks for the old CLI.

## Auth and transport

- Official Slack MCP endpoint: `https://mcp.slack.com/mcp`.
- Pi MCP bridge config: `~/.pi/agent/extensions/mcp-bridge/servers.json`, server `slack`.
- Auth reuses Claude Code's official Slack plugin OAuth cache: `~/.claude/.credentials.json`, entry `plugin:slack:slack`.
- Never print, paste, copy, or summarize OAuth tokens.
- Slack audit attribution is Claude Code's Slack plugin client because Pi reuses that OAuth client.

## Preferred access

If `slack__...` tools are visible, use them directly:

- `slack__slack_search_channels` — find channel IDs.
- `slack__slack_search_public_and_private` — search authorized public/private channels, DMs, and MPIMs.
- `slack__slack_search_public` — public-only search.
- `slack__slack_read_channel` — read channel history by channel ID.
- `slack__slack_read_thread` — read a thread by channel ID and root message timestamp.
- `slack__slack_search_users` / `slack__slack_read_user_profile` — user lookup/profile.
- `slack__slack_read_canvas` — read canvases.

If the tools are not visible or the MCP server has not been loaded, use the local helper CLI. It connects to Slack MCP on demand and closes the connection:

```bash
pi-slack-mcp tools
pi-slack-mcp channels 'dwh'
pi-slack-mcp search 'from:<@U049PC9R8GZ> in:<#C0123ABCDEF>' --limit 3 --sort timestamp --sort-dir desc
pi-slack-mcp read-channel C0123ABCDEF --limit 20
pi-slack-mcp read-thread C0123ABCDEF 1777389208.337769 --limit 100
pi-slack-mcp user U049PC9R8GZ
pi-slack-mcp call slack_search_public_and_private '{"query":"from:<@U049PC9R8GZ> in:<#C0123ABCDEF>","content_types":"messages","limit":3,"sort":"timestamp","sort_dir":"desc","include_context":false}'
```

In interactive Pi, `/reload` picks up extension/skill edits. `/mcp-load slack` manually loads the Slack MCP server; prompts containing `slack` also lazy-load it.

## Safety

- Read/search tools are okay when the user asks for Slack information.
- Mutating tools are denied by `servers.json` and by `pi-slack-mcp` unless explicitly overridden. Ask before sending/scheduling messages, creating drafts, or creating/updating canvases.
- Quote only necessary Slack excerpts. Slack output may be sensitive.
- Prefer `include_context=false` for search unless context is needed.

## Known user/channel context

- Miguel's Slack user ID: `U049PC9R8GZ`.
- Team channel names/IDs: resolve with `slack_search_channels` / `pi-slack-mcp channels`; a local cache may exist at `~/.config/opencode/secrets/slack-channels.md` (not tracked here).

## Search patterns

- Latest messages by Miguel in a channel:

```bash
pi-slack-mcp search 'from:<@U049PC9R8GZ> in:<#CHANNEL_ID>' --limit 5 --sort timestamp --sort-dir desc --format detailed
```

- Find DWH-ish channels:

```bash
pi-slack-mcp channels 'dwh'
pi-slack-mcp channels 'warehouse'
pi-slack-mcp channels 'team dwh'
```

- Search workspace/private-visible messages:

```bash
pi-slack-mcp search 'query terms after:2026-04-01' --limit 10 --sort timestamp --sort-dir desc
```
