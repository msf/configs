# Pi import ledger

Update this after promoting an import. Revisions identify the inspected checkout; dirty upstream work is not implied to be part of that revision.

## 2026-08-13: OpenCode separation

Upstream revisions:

- `~/configs`: `622d8f7bf57bfd3aa59dd452ee377bcecd6269c9` (dirty checkout)
- `~/configs-private`: `97ca2d546bab3bb7d0a06c388663029ff10ca12e` (dirty checkout)
- Pi: `0.84.1`

Imported from `~/.config/opencode/skills/` into public Pi ownership:

- `code-review`, `coding`, `go-development`, `k8s-debug`, `log-investigator`
- `pr-triage`, `reflect`, `send-pr`, `skill-creator`
- `web-tool-eval`, `web-tool-routing`, `weekly-review`

Imported from `~/.config/opencode/skills-private/` into private Pi ownership:

- `dbsh`, `dune-explore`, `grafana-metrics`, `trino-bench`, `trino-heapdump`

Material adaptations:

- Removed OpenCode compatibility metadata and live path dependencies.
- Replaced the OpenCode code-review agent with Pi `code-reviewer` (`claude-opus-5:xhigh`).
- Replaced Claude/OpenCode skill evaluation with an isolated Pi runner.
- Made reflection explicit rather than an unsupported autonomous skill trigger.
- Reworked `dbsh`, `trino-bench`, and `trino-heapdump` around verified read-only/safety boundaries.
- Moved Linear, Slack, and Grafana credentials to Pi-owned runtime stores; added Pi MCP OAuth login.

Direct untracked Pi resources moved into ownership:

- Skills: `simplified-technical-english`, `tech-writing`
- Agents: `analyst-sol-max`, `doc-reviewer-terra`, `doc-style-reviewer-sol`, `ste-distiller-sol`
- Extension: customized `subagent`
- Prompt templates: `implement`, `implement-and-review`, `scout-and-plan`

## Sietch review

Inspected `~/dune/ai-first-engineering` at `25b7ff8102393a3464ce624d76dc1e9bded4ce82`.

- Rejected Sietch replacements for `code-review`, `dune-explore`, `k8s-debug`, and `log-investigator`: local versions had stronger evidence, scope, and safety workflows.
- Rejected Sietch `skill-creator`: same main instructions but missing the local implementation bundle.
- Deferred `systematic-debugging`: useful candidate, but not needed to complete harness separation.
- Rejected wholesale `git-workflow`, `github-cli`, and `babysit-pr` imports because they duplicate local policy/workflows or contain conflicting assumptions.

## 2026-08-14: public writing skills

Published in `~/configs` commit `42df2bc10d206ba6be39562fcb4fc16fee8c7dd9`:

- `simplified-technical-english`: promoted the direct local skill to public ownership unchanged (`sha256:dd5f15afe969d7324f2f31e59bb0bf90c343253c892b15bb5c0f421f4f5a2a4f`).
- `tech-writing`: moved the direct local skill from private to public ownership (`sha256:3377a5131551ed509453c049f8adcc2712c2bb85c3af3be02b844be83b6fcb71` before adaptation). Removed employer-specific identifiers and the machine-local corpus path; retained the personal style methodology and aggregate measurements.
- Validated both with `agentskills validate`; verified manifest projection with `apply.sh --verify` and the Pi ownership audit.

## 2026-08-13: config-tool reconciliation

- Made `~/configs/ai-agents/tools/manifest.txt` authoritative for every migrated Pi skill, agent, prompt, extension, instruction file, lessons file, and custom `pi-*` wrapper.
- Updated this skill and Pi's `AGENTS.md` to require `track.sh` for new resources and `apply.sh --verify` before completion.
- Extended `audit.py` to reject owned-but-unmanifested resources and manifest target drift.
- Restored two Sietch-clobbered OpenCode command projections from the manifest; backups are under `~/.agents-backup/20260813-141948/`.
- Verified `apply.sh --verify`, `checkpoint.sh --dry-run` (zero drift), audit unit tests, official skill validation, and clean Pi startup.

## 2026-08-25: top-level ownership layout

- Moved public/private skills, Pi agents, prompt templates, extensions, wrappers, and lessons out of the `$HOME` mirror into canonical top-level source directories.
- Made `ai-agents/AGENTS.md` the single instruction source; `CLAUDE.md` is an alias and every harness projects the same file.
- Kept Pi and OpenCode agents under explicit format-specific subdirectories; skills are shared.
- Updated `track.sh`, the manifest, ownership audit, dependency tooling, and docs so new resources cannot recreate the deep mirror layout.
- Backed up the pre-migration sources under `~/.agents-backup/20260825-020027/layout-migration/`.
