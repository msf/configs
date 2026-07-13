# ai-agents/ — agent-config tools

Single source of truth for my pi / claude-code / opencode setup, split across
two repos:

- **This tree (public)** — generic skills, commands, agents, extensions,
  settings. No secrets, no internal endpoints, no employer-specific infra
  content. Private *filenames* may appear in `manifest.txt` / `.gitignore`
  (that's deliberate); private *contents* never do.
- **`~/configs-private` (private repo)** — work-specific skills/commands/agents,
  MCP server definitions with internal endpoints, org/team identity, workspace
  docs. Same layout conventions (`home/` mirrors `$HOME`).

Everything is symlinked into `$HOME` on each machine via `apply.sh`.

## Layout

```
ai-agents/
├── CLAUDE.md            ← canonical prompt (terminus of the symlink chain)
├── skills/              ← generic skills (~/.config/opencode/skills)
├── commands/            ← /command prompts
├── agents/              ← subagent definitions
├── home/                ← mirrors $HOME for tool-specific dotfiles (see manifest)
└── tools/
    ├── manifest.txt     ← single source of truth: what gets symlinked where
    ├── apply.sh         ← $HOME ←─symlinks── repos
    ├── checkpoint.sh    ← $HOME ──copy────→ repos  (pull drift back in)
    ├── track.sh         ← start tracking a new file (--private for the private repo)
    └── lib.sh           ← shared helpers (roots, TS, backup, manifest iter)

~/configs-private/       (separate repo; override location via PRIVATE_DIR)
├── skills/              ← work skills (second skills root: skills-private)
├── commands/            ← work /commands (linked into the public commands dir)
├── agents/              ← work agents   (linked into the public agents dir)
├── dune-workspace/      ← workspace entry-point docs
└── home/                ← $HOME mirror for private dotfiles (pmirror entries)
```

## On a fresh machine

```bash
git clone <public-configs-remote> ~/configs
git clone <private-configs-remote> ~/configs-private   # optional on personal machines
~/configs/ai-agents/tools/apply.sh
~/configs/ai-agents/tools/install-extensions.sh
```

Without the private clone, `apply.sh` warns `source missing` for
`pmirror`/`prepo` entries and skips them; everything public still works.

## Daily ops

- **Edit anything**: edits to `~/.pi/...`, `~/.claude/...`, etc. go through
  symlinks straight into the owning repo. `git status` in either repo shows
  them. Just commit.
- **Add a new file**: `tools/track.sh ~/.pi/agent/extensions/my-new.ts`
  — or `tools/track.sh --private <path>` for anything with internal endpoints,
  org identity, schemas, or infra topology.
- **Sanity check sync state**: `tools/apply.sh --verify` (exit 1 if any drift)
- **Recover after something clobbered a symlink**: `tools/checkpoint.sh --dry-run`
  to see; run without flag to pull `$HOME` state back into the repo, then
  `tools/apply.sh` to restore the symlink.

## Public/private discipline

Anything that names internal endpoints, hostnames, DB/schema layouts, secret
naming conventions, dashboards, team membership, or internal repos goes in the
**private** repo. The public repo carries methodology and mechanism only.
When in doubt: would this line help someone map the employer's infrastructure?
Then it's private. Tokens/credentials go in **neither** — they live untracked
under `~/.config/opencode/secrets/` and similar, referenced via `{file:...}`
placeholders.

## Safety guarantees

- **Backups out-of-tree**: anything replaced by `apply.sh`/`track.sh`/`checkpoint.sh`
  goes to `~/.agents-backup/<TS>/<relative-path>`. Never `.bak` files inside the
  original tree — those would get auto-discovered as duplicate pi extensions / skills.
- **Dry-run on every script**: `--dry-run` prints intended actions and changes nothing.
- **Idempotent**: re-running `apply.sh` on a synced machine prints `ok` for every entry.
- **Deterministic**: order follows `manifest.txt` top-to-bottom.

## Supply-chain hardening (pi extensions)

pi extensions execute with full system permissions; their npm deps are a real
attack surface. Defenses (layered):

1. **Exact-pinned direct deps** in each `package.json` (no caret/tilde ranges).
2. **`npm ci` strict install** via `tools/install-extensions.sh`:
   - `npm ci`         — enforces `package-lock.json` exactly; no resolution drift.
   - `--omit=dev`     — skip dev deps entirely.
   - `--ignore-scripts` — block install/postinstall hooks (verified neither extension
     needs them; checked via `jq '.packages[] | select(.hasInstallScript == true)'`).
3. **sha512 integrity** — every fetched tarball is hash-verified against the lockfile
   (built into `npm ci`, lockfile v3).
4. **Provenance check** — `install-extensions.sh` runs `npm audit signatures` after
   install.
5. **Lockfile age gate** — `tools/verify-lockfile-age.sh` queries the npm registry for
   each package's publish date and fails if any version is younger than `MIN_AGE_DAYS`
   (default 7). Run **before committing a lockfile change**.

## What's tracked

Read `manifest.txt`. Five entry kinds: `mirror`, `pmirror`, `repo`, `prepo`,
`home` — see the header comment there.

## What's NOT tracked

By design, secrets and per-machine state:
- `~/.pi/agent/auth.json`, `~/.pi/agent/sessions/`
- `~/.claude/settings.json` and other permission history / machine state
- `~/.config/opencode/secrets/` (token files referenced via `{file:secrets/...}`)
- `~/.config/opencode/lessons.md` (local-only /reflect log)
- `node_modules/` under tracked extension dirs — rebuild with `install-extensions.sh`
- The pi-coding-agent global examples which symlink into the npm install path.
