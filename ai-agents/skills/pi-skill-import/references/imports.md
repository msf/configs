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

## 2026-09-15: retire duplicate resources and instructions

Owned-source cleanup from `~/configs` at `caff3b2` (dirty checkout), using Pi 0.85.1; no upstream import.

- Renamed the canonical rules to `ai-agents/instructions.md` and repointed existing global projections through the apply helpers. Removed the duplicate `~/configs/AGENTS.md` and subtree `CLAUDE.md` alias. Native Pi context probes load the rules exactly once in both profiles from the configs root, ai-agents root, and skills directory.
- Retired four legacy workspace wrappers, the standalone Slack MCP CLI, the generic Pi `reviewer`, and four redundant command templates. Workspace routing now delegates Notion and Slack to their dedicated skills; implementation review follows `code-review`. Reflection uses native `/skill:reflect` and `/skill:weekly-review` commands.
- Verified 32 skills without discovery diagnostics, 10 agents, three native prompts and review argument expansion, five instruction projections, 18 retired paths absent, five custom extensions preserved, and five audit tests passing. The full Pi ownership/schema/model audit passes.
- `apply.sh --verify` still reports two pre-existing OpenCode/Sietch command mismatches and two missing Pi-lean source files. Settings/models recovery and relocation belong to the user's parallel work; Sietch ownership repair is separate. Backups: `~/.agents-backup/20260915-142616-pi-tidy/`. No credentials, caches, or package installations were removed.

## 2026-09-15: selected Sietch material and slim Pi-lean prompts

- Preserved Andre's unchanged OpenCode reviewer as the **unloaded candidate** `agents/candidates/andre-code-reviewer.md`, not a Pi import. Source revision/hash and format limitations are recorded in `agents/candidates/README.md`. Restored the original tracked OpenCode `code-reviewer.md` from its byte-verified backup and removed that in-tree backup. No reviewer conversion, invocation, or quality evaluation was performed.
- Adapted full-diff inspection, repository-template preservation, and confirmed issue linkage from the inspected deployed `create-pr` into `send-pr`. The deployed source (`sha256:6f93e158f0432292b9fa1c903f71e8327a44bfe3b4e716ae327fb475b2d3eba8`) differs from the older repository checkout, which was also read; its heavy description format and Graphite workflow were not imported. Added the concrete existing-code reuse check from `simplify` (`sha256:581d889f230135e9693096db2aff0429372a31287ffa43b7f4714fd29cf7fc4b`) to normal `code-review`. Removed only the selected `create-pr`, `handoff`, and `simplify` command links; upstream files remain untouched.
- After the user restored Pi-lean's settings/models, replaced its broad command-directory import with three explicit prompt file paths and removed its shared prompt-directory projection. Native Pi resolution now enables exactly `implement`, `implement-and-review`, and `scout-and-plan` in both profiles, with no Sietch templates. Other Pi-lean settings, skills, models, and extensions were unchanged.
- Both changed skills pass official validation; the Pi ownership/schema/model audit and five audit tests pass. Candidate bytes/isolation, original reviewer restoration, and selected removals were checked without model calls. Full manifest verification still reports only the two existing `dune-analyze` / `add-table-specs` OpenCode link conflicts; broader Sietch ownership separation remains deferred. Backups: `~/.agents-backup/20260915-163636-sietch-selection/`.

## 2026-09-15: private datashare table-add skill

- Added `datashare-add-table` as one private, independently owned `SKILL.md`, registered with `track.sh --private`. Source provenance and operational details stay in the private file. No wrappers, agent imports, or dependency on the old command at runtime.
- Verified against current repository tooling, validated the skill schema, and confirmed native Pi discovers it exactly once. The Pi audit passes with 33 skills; five audit tests pass. The two existing OpenCode manifest conflicts remain unchanged.
- No table configuration, queries, deployments, or flow triggers were executed. The skill defaults to configuration and tests, with explicit approval required for operational changes.

## 2026-09-15: retire the final conflicting OpenCode commands

- Removed `dune-analyze` and `add-table-specs`: live links, in-tree `.pre-dune-sietch` links, owned private command files, manifest entries, and obsolete ignore rules. Upstream cached files and the independent `datashare-add-table` Pi skill remain untouched. The original private sources remain in Git at `5b8208f` and in `~/.agents-backup/20260915-165833-retire-opencode-commands/`.
- Full manifest verification now passes on the laptop, as does the Pi audit (33 skills, 10 agents). Verified all six retired paths absent and the retained skill present; unrelated resources were not changed.
