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

## 2026-08-29: Pi extension usage accounting

- Reconciled the owned `subagent` extension against the Pi `0.84.4` packaged example (`sha256:4facaa61c9c781748dd000eb5d2ec0a75289986d1a6e11ce13971ca5653dc252`).
- Retained local context-isolation, model-dispatch, and project-agent confirmation behavior.
- Added complete child usage propagation, including nested tool and compaction usage, to the parent tool result.
- Updated `context-meter` to count assistant, tool, compaction, and branch-summary usage using Pi's session-accounting semantics, with a fallback for subagent usage recorded by older sessions only in tool details.
- Validated both extensions through Pi's loader, synthetic usage smoke tests, manifest verification, and the Pi ownership audit.

## 2026-09-06: local wiki memory

- Adapted the existing owned wiki skill, not a new upstream import. Previous SHA256: `a611c76264007553c788befc15d056c617a991c1fbad5a5e1e9d0d18fa75a731`; new SHA256: `847ffaf441f2f6f12de7046c80d6d8ceeda5af16c8de016b2a8f7b47e5612cbc`. Config checkout at final inspection: `c1753975289d0faf8bad035df7e87cba235a3c82`, with this adaptation uncommitted.
- Replaced the compulsory long server-wiki bootstrap with explicit/local root selection, a short entry point, selective retrieval, source-backed narrow capture, and personal/work boundaries. Personal wiki content remains outside config repositories.
- Added a shared Local Memory trigger; pointed pi-lean skill/prompt imports at owned sources rather than another harness's projections. Preserved existing manifest links; no model-serving or synchronization changes.
- Validated the skill schema, both Pi resource loaders, native cloud/local retrieval, manifest projection and Pi ownership audit. The private pilot at `~/play/wiki-memory-eval/pilot-01/REPORT.md` preserves all policy variants and curation failures. Explicit `/skill:wiki` invocation worked for local retrieval; unattended local-model curation is not validated.

## 2026-09-06: shared wiki projection reconciliation

- Kept the wiki skill from `a515800` unchanged. Registered `.claude/skills/wiki` through `track.sh` against the same canonical source as Pi; Pi does not depend on the Claude projection. Added regression coverage for both public skill paths.
- Scoped standalone Pi's bundled Node runtime to `pi` and `pi-lean` launches instead of changing the shell's general Node version. Verified Pi 0.85.1 with Node 22.23.1 on the second machine; the laptop remains on Node 24.13.0.
- Verified both Pi profile loaders on both machines and a native read-only Claude `/wiki` invocation on the second machine. Laptop manifest verification and Pi audit pass. Full second-machine audit remains blocked by missing private resources and provider availability; see the private deployment report before claiming complete reconciliation.
- Personal wiki contents, credentials, and machine-generated catalogs remain outside this public configuration change.
