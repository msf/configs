# ai-agents — managed agent configuration

Single source of truth for Pi and Claude Code, split across:

- **`~/configs/ai-agents` (public):** generic instructions, skills, agents, commands, tools, and path-specific settings. No secrets or internal infrastructure details.
- **`~/configs-private` (private):** personal agents, lessons, and session-derived reviews. Tokens and machine state belong in neither repository.

`tools/manifest.txt` declares every live projection. `apply.sh` links owned sources into `$HOME`.

Pi and Claude Code share the canonical instructions and one skill set. Claude Code also gets two adapted subagents and `settings.json`.

Global instructions live in `instructions.md`, projected to each harness's conventional global instruction path. Do not duplicate them in this repository's `AGENTS.md` or `CLAUDE.md`: Pi loads global and ancestor/project context together.

## Layout

```text
ai-agents/
├── instructions.md            canonical global instructions
├── skills/                    skills shared by all harnesses, plus the Pi-only ones
├── skills-frozen/             unloaded references, outside skill discovery
├── agents/
│   ├── pi/                    Pi agent format
│   ├── claude/                Claude Code agent format
│   └── candidates/            unloaded snapshots for later evaluation
├── commands/                  Pi prompt templates
├── tools/
│   ├── extensions/            Pi extensions
│   ├── manifest.txt
│   └── {apply,checkpoint,track}.sh
└── home/                      only irreducibly path-specific settings
    ├── .claude/settings.json
    ├── .pi/agent/{settings,models}.json
    └── .pi/agent-lean/{settings,models}.json
```

The private repository mirrors the same ownership model: shared skills at `skills/`, Pi agents under `agents/pi/`, unloaded agent snapshots under `agents/candidates/`, Pi tool configuration under `tools/`, and only path-specific application config under `home/`.

## Resource entrypoints

- Pi prompt templates: `/implement`, `/implement-and-review`, `/scout-and-plan`. Pi-lean lists those three files explicitly; it does not import command directories or inherit future main-profile prompts. For review, shipping, and reflection, use `/skill:code-review`, `/skill:send-pr`, `/skill:reflect`, and `/skill:weekly-review`; no duplicate command templates.
- Skills: a `skill <name>` (public) or `pskill <name>` (private) manifest entry links one source into `~/.agents/skills/` and `~/.claude/skills/`. Pi reads `~/.agents/skills/`, so a shared skill must not also appear under `~/.pi/agent/skills/`, where Pi would load it twice. Skills there are Pi-only: they use native MCP/codemode or custom extensions (`browser-read`, `subagent`). Shared is the default; `track.sh` writes a `skill`/`pskill` entry for any skills-root path. Work skills that Claude must not load use a `repo`/`prepo` entry for `.agents/skills/<name>` instead, which projects them to Pi only.
- Claude Code: besides the shared skills, the manifest projects the `code-reviewer` and `skill-applier` subagents into `~/.claude/agents`, the canonical instructions as `~/.claude/CLAUDE.md`, and `settings.json` from the `home/` mirror.
- Workspace services: `notion` prefers the workspace's configured Notion MCP, with `ntn` as a fallback when no MCP is configured; `workspace-apps` owns `gog`. The legacy workspace wrappers, Slack and Linear integrations, and `trino-bench` skill are retired.
- Native MCP/codemode, `browser-read`, `web-search`, `subagent`, their tool names, and their command syntax are Pi-specific. Do not copy their routing/evaluation skills or agent templates to another harness without checking its native integrations.

## Native MCP (Pi 0.99+)

Pi's built-in MCP replaces the retired `mcp-bridge`. The Dune-only server configuration and its main/lean projections were removed on 2026-10-09; no MCP server configuration is currently managed by the manifest. Register any future configuration deliberately through `track.sh`. Keep credentials in machine-local stores, default exposure to `hidden`, and expose only reviewed tools through exact allowlists.

Pi activates codemode automatically when these tools connect. Ordinary tools stay available; neither profile uses codemode-only mode. Discover MCP schemas with codemode's `searchTools()` / `describeTool()`. Native results are `CallToolResult`, including `structuredContent` and `isError`, not flattened strings.

Use `/mcp` for status, reconnect, and explicit enabling. Changes to the shared server configuration persist for both profiles. Writes require an explicit user request or approval of the content, not a second per-tool permission dialog; the exact tool-exposure allowlists remain in force.

OAuth state is machine-local and profile-specific: `<agent-dir>/mcp-auth.json`. Sign in separately for each profile with `pi mcp login <server>` and `PI_CODING_AGENT_DIR="$HOME/.pi/agent-lean" pi mcp login <server>`.

Run the offline integration tests with `node --test tools/mcp.test.mjs` from `ai-agents/`. Tests use temporary configuration and locate the installed Pi package; set `PI_PACKAGE_DIR` explicitly for another layout. They launch only a synthetic local MCP server and make no model requests.

## Web tools (Pi)

Two Pi extensions; neither depends on another agent harness.

- `web_read` (`extensions/browser-read`) reads one URL over plain HTTP and falls back to headless Chrome with the persistent profile in `~/.pi/agent/browser-read/profile`. Its output starts with an evidence label: `ACQUIRED(...)` is citable; `BLOCKED`, `INCOMPLETE` and `FAILED` are not. It keeps link targets and extracts PDF text with `pdftotext`. `/browser-login <url>` opens the profile in a visible browser to solve a login or CAPTCHA.
- `web_search` (`extensions/web-search`) queries a local SearXNG container on `127.0.0.1:28100` (`SEARXNG_PORT` overrides it). The tool starts the container when it can't reach it. By hand: `~/.pi/agent/extensions/web-search/searxng.sh start|stop|status`.

The container runs a digest-pinned image with `--restart unless-stopped`, so it survives reboots. SearXNG scrapes other search engines, which change their pages and rate-limit; `web_search` lists the engines that didn't answer. To update, bump `IMAGE` in `searxng.sh` and run `searxng.sh start`: it recreates a container whose image or port differs.

How these tools evolved and what was tested: `skills/web-tool-eval/history.md`.

## Optional Pi packages

`@narumitw/pi-goal@0.54.4` is retained in Pi settings with `extensions: []`: pinned, but disabled by default after high token usage during a trial. Enable it deliberately with `pi config`, then start a fresh session. Use `/goal --tokens <budget> <objective>` for a bounded trial; its default 25-response limit is not a cost cap, and the token budget can overshoot by one model call.

## Fresh machine

```bash
git clone <public-configs-remote> ~/configs
git clone <private-configs-remote> ~/configs-private   # optional
~/configs/ai-agents/tools/apply.sh
~/configs/ai-agents/tools/install-extensions.sh
```

Without the private clone, `apply.sh` skips unavailable private entries; public resources still work.

## Daily operations

- Edit an existing resource through its `$HOME` symlink or its canonical top-level source.
- Add a resource with `tools/track.sh <live-path>`; add `--private` for internal content. Skills under Pi's, Claude's, or the shared Agent Skills root, plus Pi agents, prompts, extensions, and wrappers, are routed to their canonical top-level directories automatically. Lesson journals stay machine-local; `track.sh` refuses them.
- Preview projection changes with `tools/apply.sh --dry-run`.
- Verify with `tools/apply.sh --verify`; Pi resources must also pass `uv run --quiet ~/.agents/skills/pi-skill-import/scripts/audit.py`.
- `apply.sh --pi` limits deployment/verification to the main Pi profile and shared skills; it skips Claude-specific projections and Pi-lean settings. Harnesses that read shared skills or alias main-profile resources still see those changes. The Lima sync script (`../../macos/sync-pi-config.sh`) deploys a manifest-selected snapshot without changing guest checkouts. Audit that layout with `audit.py --source-home <snapshot-root>`; the normal default remains `$HOME`.
- Recover clobbered live links with `tools/checkpoint.sh --dry-run`, then checkpoint and apply deliberately.

## Public/private boundary

Anything naming internal endpoints, hostnames, schemas, infrastructure topology, team identity, or internal repositories belongs in `~/configs-private`. Tokens and credentials stay in untracked stores such as `~/.pi/agent/mcp-auth.json`, `~/.pi/agent/secrets/`, and tool keyrings.

## Safety

- Replaced paths are backed up under `~/.agents-backup/<timestamp>/`.
- `apply.sh --dry-run`, `apply.sh --verify`, and `checkpoint.sh --dry-run` do not mutate live projections.
- Manifest order is deterministic and matters for private overlays inside public-linked directories.
- Never create managed live symlinks manually.

## Extension dependencies

Pi extensions execute with full user permissions. Direct dependencies are exact-pinned. Install them with:

```bash
~/configs/ai-agents/tools/verify-lockfile-age.sh
~/configs/ai-agents/tools/install-extensions.sh
```

`install-extensions.sh` uses `npm ci --omit=dev --ignore-scripts`, verifies lockfile integrity, and audits npm signatures.

### Browser reader

`browser-read` shares one persistent profile across Pi sessions. It uses kernel file locks (`/usr/bin/lockf` on macOS, `flock` from util-linux on Linux), with a 30-second wait limit. Closing the last `/browser-login` window quits the dedicated Chrome instance, including on macOS. Never delete `SingletonLock` while its Chrome process is running.

Run `npm --prefix ~/.pi/agent/extensions/browser-read test`. To include real-browser lifecycle tests, set `PI_BROWSER_EXECUTABLE` to Chrome's executable path. These tests open temporary profiles and a headed window; they do not use your normal Chrome profile.

## Not tracked

- Pi credentials, trust decisions, sessions, lesson journals, generated model stores, browser profiles, package checkouts, and caches.
- Local Railway project configuration under `~/rlwy/`; it is not a home-config projection.
- Claude credentials, sessions, transcripts, plugin caches, and `settings.local.json` permission grants. Only `settings.json` and the manifest-listed resources are managed.
- Extension `node_modules/`; rebuild them from lockfiles.
