---
name: pi-skill-import
description: Manage, audit, import, track, and restore the skills, agents, prompts, extensions, or configuration that the manifest deploys to Pi, Claude Code, OpenCode, and Codex, through the owned config repositories and manifest tools. Use for new Pi resources, upstream adaptation, reproducibility checks, recovery, provenance, conflicts, or preventing clobbered and half-migrated configuration.
---

# Managed agent resource management and import

The manifest owns every harness projection on this machine. Pi is the primary runtime; Claude Code, OpenCode, and Codex load the same sources through their own manifest entries. dune-sietch is an upstream to inspect and a co-writer to coexist with, never a live dependency to edit or symlink into.

## Ownership boundary

Managed source and deployment:

- Manifest and management: `~/configs/ai-agents/tools/`
- Public sources: `~/configs/ai-agents/{skills,agents/{pi,claude,opencode},commands,tools/{extensions,bin}}`
- Private sources: `~/configs-private/{skills,agents/pi,tools/extensions}`
- Path-specific settings only: each repository's `home/` mirror
- Live projections, symlinked only by the management tools:
  - Pi: `~/.pi/agent/`
  - Claude Code: `~/.claude/CLAUDE.md`, `~/.claude/settings.json`, and per-resource entries under `~/.claude/skills` and `~/.claude/agents`
  - OpenCode: `~/.config/opencode/`
  - Codex: `~/.codex/AGENTS.md` and `~/.agents/skills/`

Read the tools README and manifest before changing harness configuration. The manifest is the deployment source of truth; ownership in a repository without a manifest entry is incomplete.

Everything else under a harness config root is machine state, not a manifest entry: credentials, sessions, transcripts, permission history, trust decisions, caches, and generated model catalogs.

Read-only upstreams unless the user separately asks to change them:

- dune-sietch repository: `~/dune/ai-first-engineering/`
- installed dune-sietch cache: `~/.cache/dune-sietch/`

Never point a managed skill, agent, prompt, extension, settings entry, or secret reference at those upstreams. Import an independent copy and adapt it.

## Directories shared with dune-sietch

dune-sietch writes its own links into `~/.claude/{skills,agents,commands}` and `~/.config/opencode/{agents,commands}`:

- Project individual resources into those directories, never the whole directory. A directory-level entry swallows sietch's links into this repository, which is how `agents/opencode/` and `commands/` collected untracked cache links.
- `dune-sietch check` only tests that a link exists, not where it points, so displacing one is silent.
- `dune-sietch update` re-claims a displaced link and renames the previous one to `<path>.pre-dune-sietch`. Inside a skills root that leftover is loaded as a second copy of the same skill: delete it, then re-run `tools/apply.sh`.
- A name owned by both sides is a decision, not an accident. Record which side won and why.

## Start with audit

Run both gates:

```zsh
~/configs/ai-agents/tools/apply.sh --verify
uv run --quiet ~/.pi/agent/skills/pi-skill-import/scripts/audit.py
```

Fix hard failures before importing more. The first gate verifies all managed harness projections; the second verifies Pi ownership, manifest coverage, schemas, models, and stale dependencies. Warnings about external Agent Skills or package-managed skills are provenance signals, not automatic migration work.

## Import workflow

1. **Select, don't sweep.** Name one candidate and the behavior it adds. Read its entire directory and compare it with the current Pi resource. Reject duplicates, stale snapshots, and policy bundles that add no behavior.
2. **Record provenance.** Read `references/imports.md`, then capture the source path, git revision when available, dirty state, and source tree hash. Never use an unexamined cache as the canonical upstream when its repository checkout exists.
3. **Stage independently.** Copy the candidate to `/tmp/pi-import-<name>/`; do not edit the upstream or live target. Choose public or private ownership before adaptation. For an existing resource, confirm its live symlink and manifest entry before editing its owned target.
4. **Translate semantics:**
   - skills use Pi's Agent Skills frontmatter and relative resources;
   - Pi agents use Pi frontmatter (`name`, `description`, comma-separated `tools`, `model: provider/id:thinking`); Claude Code agents use `name`, `description`, comma-separated Claude tool names in `tools`, and `model: opus|sonnet|haiku|inherit`. Neither file loads in the other harness, so an agent needed in both is adapted per harness under `agents/<harness>/`;
   - OpenCode commands become Pi prompt templates only when plain expansion is sufficient; workflows needing runtime behavior become extensions;
   - tool, MCP, OAuth, model, hook, and session APIs must be checked against complete Pi docs rather than renamed by intuition;
   - secrets move only to a Pi-owned path with preserved `0600` permissions and an updated consumer. Never print them.
5. **Validate and smoke test.** Run official validation, check every relative reference, grep for stale harness paths, and execute the smallest isolated Pi test. For behavioral skills, use `skill-creator`; for agent definitions, invoke the agent on a bounded read-only task.
6. **Promote through the config tools.** Re-read/hash the target immediately before replacement and refuse if it changed. For a new resource, copy the validated stage to its live path as a regular file/directory, then run `tools/track.sh <path>` or `tools/track.sh --private <path>`; it routes the resource to the canonical top-level source, backs it up, appends the manifest entry, and creates the symlink. For an existing tracked resource, replace only its owned top-level target and preserve the manifest-managed live symlink. Never create the live symlink or edit the manifest by hand during a routine import. Do not modify the upstream copy.
7. **Verify and record.** Reload Pi; run `tools/apply.sh --verify` and the audit; verify the exact entrypoint; then update `references/imports.md` with the source revision/hash, target, adaptations, checks, and disposition.

## Stale-harness checks

Before promotion, inspect the whole staged tree for:

```text
compatibility: opencode
~/.config/opencode/skills
~/.config/opencode/agents
~/.config/opencode/commands
~/.claude/skills
claude -p
Task tool
TodoList
OpenCode-only model variants or permission maps
```

A historical OpenCode session path may be intentional in review tooling. A live skill/config/credential dependency is not.

The audit errors on these patterns in every skill except this one, so keep another harness's config paths out of shared skills. Harness-specific mechanics belong here, in `agents/<harness>/`, or in `tools/README.md`.

## Promotion report

Report only:

- imported, merged, or rejected;
- source path/revision/hash and Pi target;
- material adaptations;
- validation and smoke-test evidence;
- explicit remaining gaps.

Do not call an import complete while Pi still loads the upstream path, a live resource is absent from the manifest, `apply.sh --verify` fails, or any required agent/script/reference is missing.
