---
name: workspace-apps
description: Use the official Notion CLI (`ntn`) for Notion, local `gog` for Google Workspace (Drive, Docs, Sheets, Gmail, Calendar), and official Slack MCP for Slack workspace search/read tasks. Load when the user asks to search/read/update workspace knowledge in Notion, Slack messages/channels/threads, Google Drive documents/spreadsheets/files, Gmail, or Google Calendar.
---

# Workspace Apps

Use the official Notion CLI `ntn` for Notion and `gog` for Google Drive/Docs/Sheets/Gmail/Calendar. Do not use the Notion MCP bridge, legacy `pi-notion`, or legacy `pi-gdrive`/rclone path unless the user explicitly asks or the official CLI is unavailable and the user approves the fallback. Use official Slack MCP for Slack tasks; see the dedicated `slack-mcp` skill. This keeps pi cheap: no Notion/Google tool schemas are loaded into every session, and Slack MCP loads on demand.

## Security

- Never ask the user to paste tokens into chat.
- Tokens live in env vars, OS/encrypted keyrings, official CLI config dirs, or `~/.config/pi-workspace/*.token` with mode `0600`. For Notion, prefer `ntn login` with OS keychain or `NOTION_API_TOKEN`; `NOTION_KEYRING=0` stores plain JSON and must be treated as a secret.
- Prefer read-only OAuth/API scopes. Ask before writing, sending email, changing sharing/settings, or modifying calendar events.
- Treat Slack/Notion/Google Workspace output as sensitive; quote only the necessary excerpts.

## Notion

Use Notion's official CLI, `ntn`: https://developers.notion.com/cli/get-started/overview

Install only with user permission. Per official docs, the install script supports Linux/macOS; the npm package requires Node.js 22+.

```bash
command -v ntn || echo 'ntn not installed'
ntn --version
# if installation is approved:
curl -fsSL https://ntn.dev | bash
# or with Node.js 22+:
npm install --global ntn
```

Auth is workspace-scoped. `ntn login` stores tokens in the OS credential store under service `notion-cli`; it requires full workspace membership. For unattended use, set `NOTION_API_TOKEN`, which takes precedence over keychain auth. If the OS keychain is unusable, `NOTION_KEYRING=0 ntn login` stores plain JSON in the Notion config directory; treat it as a secret.

```bash
ntn login
ntn doctor
ntn debug

# PAT / unattended use; never ask the user to paste this into chat.
export NOTION_API_TOKEN=ntn_xxx...
ntn api v1/users/me
```

Prefer official API calls through `ntn api`; it injects auth and `Notion-Version` headers. For page content, prefer the markdown endpoint; use block children only when exact block structure matters.

```bash
ntn api v1/search --data '{"query":"roadmap","page_size":10}'
ntn api v1/search filter:='{"property":"object","value":"page"}' query=roadmap page_size:=10
ntn api "v1/pages/$PAGE_ID"
ntn api "v1/pages/$PAGE_ID/markdown"
ntn api "v1/blocks/$PAGE_ID/children" page_size==100
ntn api "v1/data_sources/$DATA_SOURCE_ID/query" page_size:=20

# With explicit user permission only:
ntn api "v1/pages/$PAGE_ID" -X PATCH archived:=true
```

Prefer `ntn api ls`, `ntn api <path> --help`, `--spec`, and `--docs` to inspect endpoints before calling unfamiliar paths.

## Slack

Auth: `SLACK_USER_TOKEN`, `SLACK_BOT_TOKEN`, `SLACK_TOKEN`, or `~/.config/pi-workspace/slack.token`.

A user token with `search:read` is usually required for global message search. A bot token can read conversations the bot is in if it has `channels:history`, `groups:history`, etc.

```bash
pi-slack status --check
pi-slack channels --query query --limit 50
pi-slack search '"exact phrase" OR keyword' --limit 20
pi-slack history '#channel-name' --limit 50
pi-slack thread '#channel-name' <root-ts> --limit 100
pi-slack users --query person@example.com
pi-slack user <USER_ID_OR_EMAIL>
```

Slack MCP is also available through the lazy MCP bridge: `/mcp-load slack`, or prompts containing `slack`. It uses Slack's first-party endpoint at `https://mcp.slack.com/mcp`, reuses Claude Code's official Slack plugin OAuth cache in `~/.claude/.credentials.json`, and filters obvious mutating tools by default. Use Slack MCP when the user asks for MCP-backed Slack access or needs server-side Slack search/read/user/canvas context; use `pi-slack` only when MCP auth is unavailable or a quick CLI query is simpler.

For recent context in a known channel, prefer MCP channel reads over broad search. For a message with replies, use MCP thread reads with the root timestamp.

## Google Workspace: Drive / Docs / Sheets / Gmail / Calendar

Backed by `gog` (`steipete/gogcli`) on pi's `PATH`. It uses official Google APIs and stores OAuth refresh tokens in the OS keyring or encrypted file keyring. Prefer read-only OAuth scopes. Ask before writing files, editing Docs/Sheets, changing permissions/sharing, sending or modifying email, or creating/updating/deleting/responding to calendar events.

One-time setup requires a Google OAuth Desktop client JSON with the needed APIs enabled. Prefer read-only when only reading:

```bash
gog auth credentials ~/Downloads/client_secret_....json
gog auth add <email> --services drive,docs,sheets,gmail,calendar --readonly --drive-scope readonly --gmail-scope readonly
gog auth status
gog auth list --check
```

For write-capable Google Workspace access, the user may authorize without `--readonly`. Mutations are still permission-gated per task:

```bash
gog auth add <email> --services drive,docs,sheets,gmail,calendar
gog auth status
gog auth list --check
```

Use IDs from Drive/search results rather than ambiguous path/title matching:

```bash
gog drive ls --max 50 --json
gog drive search "filename or title" --max 20 --json
gog drive get <fileId> --json
gog drive url <fileId>

gog docs cat <docId> --max-bytes 50000
gog docs export <docId> --format txt --out -
gog docs export <docId> --format pdf --out /tmp/doc.pdf

gog sheets metadata <spreadsheetId> --json
gog sheets get <spreadsheetId> 'Sheet1!A1:B10' --json
gog sheets export <spreadsheetId> --format xlsx --out /tmp/sheet.xlsx
# With explicit user permission only:
gog sheets update <spreadsheetId> 'Sheet1!A1' 'new value' --json
gog sheets append <spreadsheetId> 'Sheet1!A:C' 'new|row|data' --json

gog --gmail-no-send gmail search 'from:person@example.com newer_than:30d' --max 20 --json
gog --gmail-no-send gmail thread get <threadId> --json
gog --gmail-no-send gmail get <messageId> --json

gog calendar calendars --json
gog calendar events primary --today --json
gog calendar events primary --from today --to tomorrow --json
gog calendar freebusy primary --from 2026-05-04T09:00:00-04:00 --to 2026-05-04T17:00:00-04:00 --json
```

For Gmail, default to `--gmail-no-send` unless the user explicitly asks to send/reply/forward. For Calendar, read/list/freebusy are safe; ask before create/update/delete/respond. The legacy `pi-gdrive` wrapper is rclone-backed and should not be used unless the user explicitly asks for rclone.
