---
name: workspace-apps
description: Route workspace tasks to the Notion and Slack skills; use gog for Google Drive, Docs, Sheets, Gmail, and Calendar. Load for Google Workspace tasks or requests spanning multiple workspace services.
---

# Workspace Apps

- For Notion, read [notion](../notion/SKILL.md). It owns `ntn` authentication and operations.
- For Slack, read [slack-mcp](../slack-mcp/SKILL.md). It owns Slack MCP loading, authentication, and operations.
- For Google Workspace, use `gog` as described below.

## Security

- Never ask the user to paste tokens into chat or print credentials.
- Prefer read-only OAuth/API scopes. Ask before writing, sending email, changing sharing/settings, or modifying calendar events.
- Treat workspace output as sensitive; quote only the necessary excerpts.

## Google Workspace: Drive / Docs / Sheets / Gmail / Calendar

Backed by `gog` (`steipete/gogcli`) on Pi's `PATH`. It uses official Google APIs and stores OAuth refresh tokens in the OS keyring or encrypted file keyring.

On this machine, `$HOME/bin/gog` loads the encrypted-file-keyring password from the mode-0600 `$HOME/.gog_secret`; never source that file manually or bypass the wrapper. Before debugging or reauthorizing, verify the actual agent entrypoint:

```bash
[[ "$(command -v gog)" == "$HOME/bin/gog" ]] && gog --no-input auth list --check
```

If this fails, fix the wrapper/PATH first. Reauthorization does not fix a missing `GOG_KEYRING_PASSWORD` in the invoking process.

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

For Gmail, default to `--gmail-no-send` unless the user explicitly asks to send/reply/forward. For Calendar, read/list/freebusy are safe; ask before create/update/delete/respond.
