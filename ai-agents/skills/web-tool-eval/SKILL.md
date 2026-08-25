---
name: web-tool-eval
description: Evaluate or benchmark the performance of web-tool-routing and browser_read_url. Use when asked to rerun the web retrieval eval, compare routing changes, investigate web-tool failure rates, or review whether web search/page reading improved.
---

# Web Tool Eval

Measure user-visible retrieval behavior without turning the benchmark into a framework.

## Canonical assets

- `evals/eval.json` — small historical-task corpus.
- `scripts/run_eval.py` — isolated Pi runner.
- `baselines/` — compact reports; raw transcripts stay outside the repository.

Resolve these paths relative to this `SKILL.md`.

## Workflow

1. Run every case once against an explicit model and thinking level. Each case gets a fresh `pi --mode json --no-session` process, the natural prompt, normal global skills/extensions, and read-only intent.
2. Grade user-visible behavior first: retrieval triggered, authoritative content acquired, claims grounded, blocks handled safely, and request budget respected. Report skill activation separately; do not fail an otherwise successful case only because the skill was not loaded.
3. Change one behavior at a time, then rerun the same corpus with the same model. Repeat only flaky or changed cases before paying for another full run.
4. Add a case only for an observed failure class. Prefer replacing redundant cases and keep the core corpus around 12–16 cases.

## Run

```zsh
skill=~/.pi/agent/skills/web-tool-eval
uv run --quiet python "$skill/scripts/run_eval.py" \
  --eval "$skill/evals/eval.json" \
  --provider anthropic \
  --model claude-sonnet-4-5 \
  --thinking high
```

The runner executes browser cases serially because concurrent Pi processes share the persistent browser profile. Use `--case <id>` to rerun selected cases and `--output <dir>` to choose an artifact directory.

## Report these dimensions

- Cases × runs, exact executor model, thinking level, duration, network attempts, and reported model cost.
- Behavioral trigger recall: positive prompts that made a network retrieval; negative controls that did not.
- Acquisition success and safe-failure counts.
- Grounding and route/budget failures.
- Skill activation rate as a diagnostic metric.
- Exact failing case IDs and the smallest change they justify.

A strict all-assertions score may be included, but never use it as the headline when a diagnostic assertion dominates the result.

## Artifact and safety rules

- Default raw output to `$XDG_STATE_HOME/pi/web-tool-evals/` (or `~/.local/state/pi/web-tool-evals/`) with user-only permissions.
- Never commit raw page content, browser profiles, cookies, private URLs, or authenticated-page output.
- Keep only the sanitized corpus and compact baseline reports in the repository.
- Graders inspect saved outputs without making new network requests. If grading is delegated, review their evidence before reporting results.
- Private GitHub/authentication canaries are optional runtime cases supplied by the user; do not store their URLs in the public corpus.
