# ai-agents — managed agent configuration

Single source of truth for Pi, Claude Code, OpenCode, and Codex, split across:

- **`~/configs/ai-agents` (public):** generic instructions, skills, agents, commands, tools, and path-specific settings. No secrets or internal infrastructure details.
- **`~/configs-private` (private):** work-specific resources and MCP configuration. Tokens and machine state belong in neither repository.

`tools/manifest.txt` declares every live projection. `apply.sh` links owned sources into `$HOME`.

Codex currently shares the canonical instructions through `~/.codex/AGENTS.md`; its settings and skills are not yet managed here.

## Layout

```text
ai-agents/
├── AGENTS.md                  canonical instructions
├── CLAUDE.md -> AGENTS.md     conventional Claude filename
├── skills/                    shared Pi/OpenCode skills
├── agents/
│   ├── pi/                    Pi agent format
│   └── opencode/              OpenCode agent format
├── commands/                  OpenCode commands and Pi prompt templates
├── tools/
│   ├── bin/                   Pi command wrappers
│   ├── extensions/            Pi extensions
│   ├── manifest.txt
│   └── {apply,checkpoint,track}.sh
└── home/                      only irreducibly path-specific settings
    ├── .pi/agent/{settings,models}.json
    └── .pi/agent-lean/{settings,models}.json
```

The private repository mirrors the same ownership model: shared skills at `skills/`, Pi agents under `agents/pi/`, OpenCode agents under `agents/opencode/`, Pi tool configuration under `tools/`, and only path-specific application config under `home/`.

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
- Add a resource with `tools/track.sh <live-path>`; add `--private` for internal content. Pi skills, agents, prompts, extensions, wrappers, and lessons are routed to their canonical top-level directories automatically.
- Preview projection changes with `tools/apply.sh --dry-run`.
- Verify with `tools/apply.sh --verify`; Pi resources must also pass `uv run --quiet ~/.pi/agent/skills/pi-skill-import/scripts/audit.py`.
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
