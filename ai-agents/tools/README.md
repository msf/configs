# ai-agents — managed agent configuration

Single source of truth for Pi, Claude Code, and Codex, split across:

- **`~/configs/ai-agents` (public):** generic instructions, skills, agents, commands, tools, and path-specific settings. No secrets or internal infrastructure details.
- **`~/configs-private` (private):** work-specific resources and MCP configuration. Tokens and machine state belong in neither repository.

`tools/manifest.txt` declares every live projection. `apply.sh` links owned sources into `$HOME`.

Pi, Claude Code, and Codex share the canonical instructions and one skill set. Claude Code also gets two adapted subagents and `settings.json`; Codex gets the canonical instructions through `~/.codex/AGENTS.md`. `apply.sh` also adds `CLAUDE.md` to Codex's project-instruction fallbacks, matching Pi without duplicating repository instructions. Other Codex settings remain machine state because its single user config also contains trust decisions, notices, and plugin state.

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
│   └── {apply,checkpoint,codex-config,track}.sh
└── home/                      only irreducibly path-specific settings
    ├── .claude/settings.json
    ├── .pi/agent/{settings,models}.json
    └── .pi/agent-lean/{settings,models}.json
```

The private repository mirrors the same ownership model: shared skills at `skills/`, Pi agents under `agents/pi/`, unloaded agent snapshots under `agents/candidates/`, Pi tool configuration under `tools/`, and only path-specific application config under `home/`.

## Resource entrypoints

- Pi prompt templates: `/implement`, `/implement-and-review`, `/scout-and-plan`. Pi-lean lists those three files explicitly; it does not import command directories or inherit future main-profile prompts. For review, shipping, and reflection, use `/skill:code-review`, `/skill:send-pr`, `/skill:reflect`, and `/skill:weekly-review`; no duplicate command templates.
- Skills: a `skill <name>` (public) or `pskill <name>` (private) manifest entry links one source into `~/.agents/skills/` and `~/.claude/skills/`. Pi and Codex both read `~/.agents/skills/`, so a shared skill must not also appear under `~/.pi/agent/skills/`, where Pi would load it twice. Skills there are Pi-only: they use native MCP/codemode or custom extensions (`browser-read`, `subagent`). Shared is the default; `track.sh` writes a `skill`/`pskill` entry for any skills-root path.
- Claude Code: besides the shared skills, the manifest projects the `code-reviewer` and `skill-applier` subagents into `~/.claude/agents`, the canonical instructions as `~/.claude/CLAUDE.md`, and `settings.json` from the `home/` mirror.
- Workspace services: `notion` owns `ntn`; `workspace-apps` owns `gog`. Slack is frozen: its server is disabled and its skill is archived outside discovery under `skills-frozen/slack-mcp`. The legacy workspace wrappers, standalone Slack MCP client, and `trino-bench` skill are retired.
- Native MCP/codemode, `browser-read`, `subagent`, their tool names, and their command syntax are Pi-specific. Do not copy their routing/evaluation skills or agent templates to another harness without checking its native integrations.
- dune-sietch also writes into `~/.claude/{skills,agents,commands}`, so Claude entries are per-resource, never directory-level: a directory projection would pull Sietch's links into this repository. `code-review`, `k8s-debug`, `log-investigator`, `skill-creator`, `dune-explore` and `code-reviewer` are names both sides ship; the manifest wins them deliberately. `dune-sietch check` only tests that a link exists, so it stays quiet; `dune-sietch update` re-claims them and leaves `<name>.pre-dune-sietch` behind, which `apply.sh --verify` now fails on until it is deleted.

## Native MCP (Pi 0.99+)

Pi's built-in MCP replaces the retired `mcp-bridge`. The private `home/.pi/agent/mcp.json` is projected to main and lean; it contains endpoints and secret-file commands, not tokens. Enabled servers connect at startup. Grafana prod and Linear are enabled; Grafana dev is opt-in and Slack stays frozen. Exposure defaults to `hidden`, with exact named tools exposed through codemode; resources and unreviewed tools stay unreachable.

Pi activates codemode automatically when these tools connect. Ordinary tools stay available; neither profile uses codemode-only mode. Discover MCP schemas with codemode's `searchTools()` / `describeTool()`. Native results are `CallToolResult`, including `structuredContent` and `isError`, not flattened strings.

Use `/mcp` for status, reconnect, and explicit enabling. Changes to the shared server configuration persist for both profiles. Linear writes require an explicit user request or approval of the content, not a second per-tool permission dialog. Main and lean use Pi's native MCP pipeline without an extra Linear approval extension; the exact tool-exposure allowlists remain in force.

OAuth state is machine-local and profile-specific: `<agent-dir>/mcp-auth.json`. On cutover, archive the bridge-format store outside resource discovery with mode `0600`; do not reuse its incompatible entries. Sign in separately for each profile:

```zsh
pi mcp login linear
PI_CODING_AGENT_DIR="$HOME/.pi/agent-lean" pi mcp login linear
```

Slack retains its registered client ID and exact localhost callback, but requires explicit unfreeze approval and a fresh login before use. Restart existing sessions after cutover; old bridge tool names are not supported.

Run the offline integration tests with `PRIVATE_DIR=<private-repo> node --test tools/mcp.test.mjs` from `ai-agents/`. Tests locate the installed npm Pi package; set `PI_PACKAGE_DIR` explicitly for another layout. They launch only a synthetic local MCP server and make no model requests.

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
- Add a resource with `tools/track.sh <live-path>`; add `--private` for internal content. Skills under Pi, Claude, or Codex's Agent Skills root, plus Pi agents, prompts, extensions, wrappers, and lessons, are routed to their canonical top-level directories automatically.
- Preview projection changes with `tools/apply.sh --dry-run`.
- Verify with `tools/apply.sh --verify`; Pi resources must also pass `uv run --quiet ~/.agents/skills/pi-skill-import/scripts/audit.py`.
- If `~/.codex/config.toml` already defines `project_doc_fallback_filenames`, add `CLAUDE.md` to that list manually; the tooling refuses to overwrite existing fallback choices.
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

## Not tracked

- Pi credentials, trust decisions, sessions, generated model stores, browser profiles, package checkouts, and caches.
- Claude credentials, sessions, transcripts, plugin caches, and `settings.local.json` permission grants. Only `settings.json` and the manifest-listed resources are managed.
- Extension `node_modules/`; rebuild them from lockfiles.
