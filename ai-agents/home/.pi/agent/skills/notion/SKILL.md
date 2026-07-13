---
name: notion
description: Drive Notion via the official `ntn` CLI to search, read pages, create pages, edit pages, and write comments. Use whenever the user asks to find, open, create, update, or comment on Notion docs/pages/databases, or wants to pull Notion content into a session. Overrides the more general `workspace-apps` skill for any Notion-specific task.
---

# Notion (`ntn`)

Official Notion CLI. Docs: https://developers.notion.com/cli/get-started/overview.

This skill is the canonical Notion path. Do **not** use the Notion MCP bridge or legacy `pi-notion`. `workspace-apps` covers Notion at a high level; this skill is the operational guide.

## What `ntn` is and is not

`ntn` calls Notion's **public API** as an integration named "Notion CLI". It does not act as Miguel. Consequences worth surfacing up front:

- **No inbox, no notifications, no mentions, no activity feed.** The public API does not expose them. `ntn api ls` is the full surface area (~44 endpoints: pages, blocks, comments, databases/data sources, users, views, files, workers).
- **Search is title-only**, and scoped to pages connected to the integration. Body-text search (cmd-K in the UI) is **not** available via API. A doc about "undercharging" whose title is "Q3 pricing audit" will not surface from `v1/search query=undercharging`.
- **Access is per-page, opt-in.** Until Miguel adds the "Notion CLI" connection to a page or teamspace (Notion → Settings → Connections → Notion CLI → Access), every API call returns empty / 404. Empty results are almost always an access problem, not a missing page.
- **Page-level comment listing ≠ inline discussions.** `v1/comments?block_id=<page_id>` returns only top-of-page comments. Inline discussion threads are anchored to specific blocks; pull them with the block's id. The markdown view exposes those anchors as `discussion-urls="discussion://<id>"` spans inside `<span>` tags.

## How to use it (user-facing playbook)

For Miguel, in chat with an agent that has this skill loaded:

1. **Find the doc yourself in Notion UI** (cmd-K does body-text search). Paste the URL into chat.
2. **Share once per scope.** First time touching a teamspace, open it in Notion → Connections → add "Notion CLI". Access propagates to children. Workspace-wide access requires adding the connection at the workspace root (admin).
3. **Ask the agent for what you want.** Examples:
   - "Read this page and summarize the open questions: <url>"
   - "Create a page under <parent-url> with this content: …"
   - "Append a 'Decisions' section to <url>"
   - "Post a page-level comment on <url> saying …"
   - "List comments / discussions on <url>"
4. **Refactor loop.** After the agent creates a page, you can iterate freely in the same or a later session: "Now move the TL;DR to the top", "Add a table comparing X and Y", "Replace the body with this Markdown I'm pasting". Under the hood that's `ntn pages get` → edit → `ntn pages update`.
5. **Skill loading.** The CLI works any time `ntn` is on PATH. The *skill file* is just routing/guidance the agent reads at session start. After editing the skill, run `/reload` or start a new session for the agent to see it. Mid-session, the agent can still call `ntn` directly without the skill.

## Auth and prerequisites

- Token is stored in the OS keychain under service `notion-cli` after `ntn login`, or passed via `NOTION_API_TOKEN` (overrides keychain).
- `NOTION_KEYRING=0` falls back to plaintext `~/.config/notion/auth.json` — treat as a secret.
- Default workspace and config are visible via `ntn doctor`.
- **The Notion integration only sees pages explicitly shared with it.** If `search` or `pages get` returns 404 / empty results, the user must open the page in Notion → `…` → "Connections" → add the integration (default name: "Notion CLI"). Surface this hint early; do not assume the page is missing.
- Never print, paste, or summarize the API token.

```bash
ntn doctor                      # auth + workspace check
ntn api v1/users/me             # confirm the bot identity
```

## Page IDs and URL anatomy

Notion URLs look like:

```
https://www.notion.so/<workspace>/<slug>-<page_id>?d=<data_source_or_view_id>#<block_id>
```

- The 32-char hex right before `?` (or end of URL) is the **page ID**.
- `?d=<id>` is a database/data-source view ID. Ignore unless you want `ntn datasources query <id>`.
- `?v=<id>` is a saved view ID; ignore for page reads.
- `#<id>` is a **block ID** — the specific block the user was viewing. Useful for block-anchored comments and for fetching a discussion thread.

`ntn` accepts dashed and undashed IDs. To normalize into the 8-4-4-4-12 UUID form:

```bash
notion_id() {
  local raw="${1%%\?*}"      # drop ?query
  raw="${raw%%#*}"           # drop #fragment
  raw="${raw//-/}"           # strip dashes anywhere
  raw="${raw##*/}"           # drop everything up to last `/`
  raw="${raw: -32}"          # last 32 hex chars are the id
  printf '%s-%s-%s-%s-%s\n' "${raw:0:8}" "${raw:8:4}" "${raw:12:4}" "${raw:16:4}" "${raw:20:12}"
}
notion_id 'https://www.notion.so/dune/My-Page-1234567890abcdef1234567890abcdef'
notion_id '12345678-90ab-cdef-1234-567890abcdef'
notion_id 'https://www.notion.so/dune/Foo-abcdef1234567890abcdef1234567890?v=xyz'
```

`page_id`, `block_id`, and `data_source_id` all use this form. `data_source_id` ≠ `database_id`; resolve with `ntn datasources resolve <database-id>`.

## Search

Notion search is title-only and scoped to pages/data_sources shared with the integration.

```bash
# Plain query
ntn api v1/search -X POST query=roadmap page_size:=10

# JSON body via -d (use when the body has nesting or special chars)
ntn api v1/search -X POST -d '{"query":"roadmap","filter":{"property":"object","value":"page"},"page_size":10}'

# Inline typed body: := for JSON, = for strings
ntn api v1/search -X POST query=roadmap filter:='{"property":"object","value":"page"}' page_size:=10

# Sort by last edited descending
ntn api v1/search -X POST query=postmortem sort:='{"timestamp":"last_edited_time","direction":"descending"}' page_size:=5
```

Result rows include `object` (`page` | `data_source`), `id`, `url`, and a title in `properties` (page) or `title` (data_source). To extract titles + URLs from results, pipe through `jq` or python.

## Read a page

`ntn pages get` returns Markdown with page properties as YAML frontmatter. Prefer this over assembling blocks manually.

```bash
ntn pages get <page-id>                 # Markdown + frontmatter
ntn pages get <page-id> --json          # raw API payload (look at unknown_block_ids if truncated)
ntn api v1/pages/<page-id>              # page metadata only (no content)
ntn api v1/blocks/<page-id>/children page_size==100   # raw block tree
```

If stderr mentions `unknown_block_ids`, the markdown view dropped unsupported blocks; rerun with `--json` and inspect those block IDs directly via `v1/blocks/{block_id}`.

## Query a database / data source

`databases` hold one or more `data_sources`. Always query the data source.

```bash
ntn datasources resolve <database-id>           # list contained data sources
ntn datasources query <data-source-id> --limit 50
ntn datasources query <data-source-id> \
  --filter '{"property":"Status","status":{"equals":"In Progress"}}' --json
```

## Create a page

Parent is required for top-level placement and is one of `page:<id>`, `database:<id>`, or `data-source:<id>`. The integration must have access to the parent.

```bash
# Inline content
ntn pages create --parent page:<parent-page-id> --content '# Title

Body paragraph.

- bullet 1
- bullet 2'

# From a file via stdin
ntn pages create --parent page:<parent-page-id> < /tmp/page.md

# With JSON output to capture the new page id/url
ntn pages create --parent page:<parent-page-id> --content '# Smoke test' --json
```

For database/data-source children that need property values (Status, Select, multi-select, Relations…), use the full Pages API instead — `ntn pages create` only sets the title from the first H1:

```bash
ntn api v1/pages -X POST \
  parent:='{"data_source_id":"<data-source-id>"}' \
  properties:='{"Name":{"title":[{"text":{"content":"My row"}}]},"Status":{"status":{"name":"In Progress"}}}'
```

## Edit / update a page

`ntn pages update` rewrites the page body from Markdown (it replaces top-level content; frontmatter properties round-trip when present). Use it for "rewrite the doc" or "append a section" workflows where you `pages get` → edit → `pages update`.

```bash
ntn pages update <page-id> --content '# New body

Replacement content.'

# Diff-then-update flow
ntn pages get <page-id> > /tmp/page.md
$EDITOR /tmp/page.md
ntn pages update <page-id> < /tmp/page.md
```

For surgical edits to a single block (toggle archived, change a property, edit one paragraph), use the Blocks/Pages API directly:

```bash
ntn api v1/pages/<page-id> -X PATCH archived:=true
ntn api v1/blocks/<block-id> -X PATCH \
  paragraph:='{"rich_text":[{"text":{"content":"updated line"}}]}'
ntn api v1/blocks/<page-id>/children -X PATCH \
  children:='[{"object":"block","type":"paragraph","paragraph":{"rich_text":[{"text":{"content":"appended"}}]}}]'
```

Always confirm destructive edits (archive, mass property changes, replacing a non-trivial body) with the user before running.

## Comments

Comments support inline Markdown only — bold, italic, strikethrough, code, links, inline equations, and mentions. Block-level Markdown (headings, fences, lists, tables) is **not** rendered as structured blocks inside a comment.

```bash
# Create a page-level comment (Markdown shorthand)
ntn api v1/comments -X POST \
  parent:='{"page_id":"<page-id>"}' \
  markdown='Looks good — see `note` and **bold** here.'

# Comment on a specific block
ntn api v1/comments -X POST \
  parent:='{"block_id":"<block-id>"}' \
  markdown='Question on this block.'

# Rich-text form (when you need annotations or mentions)
ntn api v1/comments -X POST -d '{
  "parent": {"page_id": "<page-id>"},
  "rich_text": [
    {"type":"text","text":{"content":"Heads up: "}},
    {"type":"text","text":{"content":"this section is stale","link":null},"annotations":{"bold":true}}
  ]
}'

# List page-level comments (block_id == page_id returns only top-of-page comments)
ntn api v1/comments -X GET block_id==<page-id> page_size==50

# Pull an inline discussion thread: use the block id from the body's discussion-urls span
ntn api v1/comments -X GET block_id==<block-id-from-discussion-url> page_size==50

# Update / delete an existing comment (requires comment_id)
ntn api v1/comments/<comment-id> -X PATCH markdown='edited'
ntn api v1/comments/<comment-id> -X DELETE
```

## Inline body input cheatsheet (`ntn api`)

Parser precedence, applied in order:

| Syntax              | Meaning                          | Example                                                  |
| ------------------- | -------------------------------- | -------------------------------------------------------- |
| `path:=json`        | Typed JSON value (numbers/bools/objects/arrays/null) | `archived:=true`, `page_size:=20`        |
| `name==value`       | Query parameter                  | `block_id==abc123`, `page_size==100`                     |
| `Header:Value`      | Request header                   | `Notion-Version:2026-03-11`                              |
| `path=value`        | Body string field                | `query=roadmap`, `parent[page_id]=abc123`                |

- GET by default; POST/PATCH inferred automatically when stdin, `--data`, or inline body inputs are present. `-X/--method` always wins.
- Body JSON comes from exactly one source: stdin, `--data`, or inline body inputs — never mix.
- Use `path[subkey]` for nested objects, `path[]` for array append.

## Discovering endpoints

```bash
ntn api ls                              # full endpoint list
ntn api v1/pages/{page_id} --help       # inline help for a path
ntn api v1/pages -X POST --spec         # reduced OpenAPI fragment
ntn api v1/pages -X POST --docs         # full official docs in Markdown
```

Prefer `--spec` / `--docs` before guessing the body schema for an unfamiliar endpoint.

## Safety

- Read/search/list operations are fine when the user asks for Notion information.
- Confirm before: creating pages outside the user's stated parent, updating an existing page's body, archiving, deleting comments/pages, or mass-editing via Blocks API.
- Quote only the necessary excerpts from page content; Notion content can be sensitive.
- Never echo `NOTION_API_TOKEN` or the contents of `~/.config/notion/auth.json`.
