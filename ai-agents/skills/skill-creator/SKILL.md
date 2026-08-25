---
name: skill-creator
description: Create, revise, validate, and evaluate native Pi skills. Use when the user asks to build a skill, improve an existing SKILL.md, test skill behavior, or compare a skill against a baseline.
---

# Pi skill creator

Build the smallest skill that reliably changes behavior. A skill is instructions plus only the scripts or references that repeated use justifies.

## Source of truth

Before editing, read Pi's complete skill documentation:

`/home/miguel/.nvm/versions/node/v24.13.0/lib/node_modules/@earendil-works/pi-coding-agent/docs/skills.md`

Use the Agent Skills frontmatter accepted by Pi. Do not add OpenCode or Claude-specific fields, commands, tool names, or paths.

For this machine, author owned skills in one of these repositories:

- Public: `~/configs/ai-agents/skills/<name>/`
- Private or Dune-internal: `~/configs-private/skills/<name>/`

Expose the finished skill with a symlink under `~/.pi/agent/skills/`. Never make a Pi skill a symlink into `~/.config/opencode`, `~/.claude`, a dune-sietch checkout, or a cache.

## Workflow

1. **Capture intent:** define trigger phrases, expected behavior/output, trust boundaries, and one concrete success case. Read the current skill fully when revising one.
2. **Draft minimally:** write `SKILL.md`; add relative `scripts/`, `references/`, or `assets/` only when the main file would otherwise repeat or bloat. Keep harness mechanics accurate for Pi.
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

For an existing skill, snapshot the old directory and add `--baseline-skill /path/to/snapshot`. The runner uses isolated `pi --no-skills` processes, saves JSONL transcripts and final responses, and never changes the skill under test.

Review outputs before drawing conclusions. A subagent or score is evidence, not the final decision.

## Promotion gate

Before replacing a live skill:

- Re-read the target and verify it has not changed since the work began.
- Validate the staged copy and run the smallest relevant check.
- Replace only the Pi-owned target; do not edit or remove the upstream source.
- Repoint the live symlink atomically, reload Pi, and confirm no skill conflicts or missing descriptions.
- Keep provenance in the commit or handoff: source path/revision, material adaptations, validation, and deferred gaps.
