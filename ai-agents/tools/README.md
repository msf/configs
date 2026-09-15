# ai-agents — managed agent configuration

Single source of truth for Pi, Claude Code, OpenCode, and Codex, split across:

- **`~/configs/ai-agents` (public):** generic instructions, skills, agents, commands, tools, and path-specific settings. No secrets or internal infrastructure details.
- **`~/configs-private` (private):** work-specific resources and MCP configuration. Tokens and machine state belong in neither repository.

`tools/manifest.txt` declares every live projection. `apply.sh` links owned sources into `$HOME`.

Pi is the primary runtime. Claude and Codex adoption are separate work; sharing a source does not make it harness-neutral. Codex shares the canonical instructions through `~/.codex/AGENTS.md` and a reviewed subset of Pi skills through `~/.agents/skills/`. `apply.sh` also adds `CLAUDE.md` to Codex's project-instruction fallbacks, matching Pi without duplicating repository instructions. Other Codex settings remain machine state because its single user config also contains trust decisions, notices, and plugin state.

Global instructions live in `instructions.md`, projected to each harness's conventional global instruction path. Do not duplicate them in this repository's `AGENTS.md` or `CLAUDE.md`: Pi loads global and ancestor/project context together.

## Layout

```text
ai-agents/
├── instructions.md            canonical global instructions
├── skills/                    Pi-maintained skills, also exposed to OpenCode
├── agents/
│   ├── pi/                    Pi agent format
│   ├── opencode/              OpenCode agent format
│   └── candidates/            unloaded snapshots for later evaluation
├── commands/                  OpenCode commands and Pi prompt templates
├── tools/
│   ├── extensions/            Pi extensions
│   ├── manifest.txt
│   └── {apply,checkpoint,codex-config,track}.sh
└── home/                      only irreducibly path-specific settings
    ├── .pi/agent/{settings,models}.json
    └── .pi/agent-lean/{settings,models}.json
```

The private repository mirrors the same ownership model: shared skills at `skills/`, Pi agents under `agents/pi/`, OpenCode agents under `agents/opencode/`, Pi tool configuration under `tools/`, and only path-specific application config under `home/`.

## Resource entrypoints

- Pi prompt templates: `/implement`, `/implement-and-review`, `/scout-and-plan`. Pi-lean lists those three files explicitly; it does not import command directories or inherit future main-profile prompts. For review, shipping, and reflection, use `/skill:code-review`, `/skill:send-pr`, `/skill:reflect`, and `/skill:weekly-review`; no duplicate command templates.
- Codex skills: the manifest projects the high-use, harness-neutral Pi subset into `~/.agents/skills/`, alongside independently installed skills. Pi-only MCP routing, web tools, resource import, reflection, and subagent workflows are deliberately excluded. Add skills individually only after checking their commands, tool names, resource paths, and delegation semantics in Codex.
- Workspace services: `notion` owns `ntn`; `slack-mcp` owns Slack MCP; `workspace-apps` owns `gog` and routes to those dedicated skills. The legacy workspace wrappers and standalone Slack MCP client are retired.
- `browser-read`, `mcp-bridge`, `subagent`, their tool names, and their command syntax are Pi-specific. Do not copy their routing/evaluation skills or agent templates to another harness without checking its native integrations.
- OpenCode directory projections currently contain Sietch cache links. Those are not canonical Pi resources; reconcile their ownership separately rather than using them as migration sources.

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
- Verify with `tools/apply.sh --verify`; Pi resources must also pass `uv run --quiet ~/.pi/agent/skills/pi-skill-import/scripts/audit.py`.
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
- Claude permission/session history and machine state.
- OpenCode secrets and tool keyrings.
- Extension `node_modules/`; rebuild them from lockfiles.
