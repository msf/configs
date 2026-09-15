---
name: skill-creator
description: Create, revise, validate, and evaluate the skills this machine manages for Pi, Claude Code, OpenCode, and Codex. Use when the user asks to build a skill, improve an existing SKILL.md, test skill behavior, or compare a skill against a baseline.
---

# Skill creator

Build the smallest skill that reliably changes behavior. A skill is instructions plus only the scripts or references that repeated use justifies.

## Source of truth

Before editing, read Pi's complete skill documentation:

`/home/miguel/.nvm/versions/node/v24.13.0/lib/node_modules/@earendil-works/pi-coding-agent/docs/skills.md`

One skill directory serves every harness here: Pi, Claude Code, OpenCode, and Codex read the same `SKILL.md`. Use the Agent Skills frontmatter Pi accepts — it is the strictest of the four, so it loads everywhere. Do not add harness-specific frontmatter fields.

Keep the body harness-neutral: name a tool only when every target harness has it, reference scripts and references by their canonical repository path, and prefer "the bash tool" over one harness's tool name. A skill whose mechanics are bound to one harness (its MCP tool names, its subagent syntax, its own runner) is projected to that harness alone and says so in the body.

For this machine, author owned skills in one of these repositories:

- Public: `~/configs/ai-agents/skills/<name>/`
- Private or Dune-internal: `~/configs-private/skills/<name>/`

Expose the finished skill through the manifest, never by hand: `tools/track.sh [--private] <live-path>` moves it to the canonical source, appends the entry, and creates the live symlink. Each harness that should load the skill gets its own manifest line, so reaching a new harness stays a deliberate, reviewed act. Never symlink a managed skill into a dune-sietch checkout or a cache, and never point one harness's skill root at another's.

## Workflow

1. **Capture intent:** define trigger phrases, expected behavior/output, trust boundaries, and one concrete success case. Read the current skill fully when revising one.
2. **Draft minimally:** write `SKILL.md`; add relative `scripts/`, `references/`, or `assets/` only when the main file would otherwise repeat or bloat. Keep harness mechanics accurate for every harness the skill will be projected to.
3. **Validate:** run `uvx --from skills-ref agentskills validate <skill-dir>`. Check every referenced relative file exists and grep for stale harness paths or terminology.
4. **Evaluate when useful:** for behavioral changes, make 2-3 realistic cases and compare the skill with a no-skill or previous-version baseline using `scripts/run_eval.py`. Subjective skills can use direct human review instead.

Do not turn a small edit into an evaluation project. Frontmatter/YAML fixes need validation, not benchmark infrastructure.

## Eval corpus

Use a small JSON file:

```json
{
  "evals": [
    {"id": "descriptive-id", "prompt": "A realistic user request", "cwd": "/optional/working/directory"}
  ]
}
```

Run from this skill directory:

```zsh
uv run --quiet python scripts/run_eval.py \
  --skill /path/to/new-skill \
  --evals /path/to/evals.json \
  --output /tmp/new-skill-eval \
  --model openai-codex/gpt-5.6-sol \
  --thinking xhigh
```

For an existing skill, snapshot the old directory and add `--baseline-skill /path/to/snapshot`. The runner is Pi-only. It uses isolated `pi --no-skills` processes, saves JSONL transcripts and final responses, and never changes the skill under test.

Review outputs before drawing conclusions. A subagent or score is evidence, not the final decision.

## Promotion gate

Before replacing a live skill:

- Re-read the target and verify it has not changed since the work began.
- Validate the staged copy and run the smallest relevant check.
- Replace only the manifest-owned source; do not edit or remove the upstream.
- Check the name against what each target harness already loads. Claude Code's shared skills root also holds dune-sietch links; a name that exists in both means one of the two wins.
- Let `tools/apply.sh` own the live symlinks, then run `tools/apply.sh --verify`, reload every harness that loads the skill, and confirm no name conflicts or missing descriptions.
- Keep provenance in the commit or handoff: source path/revision, material adaptations, validation, and deferred gaps.
