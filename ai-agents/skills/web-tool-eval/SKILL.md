---
name: web-tool-eval
description: Evaluate or benchmark Pi's web tools (web_search, web_read). Use when asked to rerun the web retrieval eval, compare web-tool changes, investigate web-tool failure rates, or review whether web search/page reading improved.
---

# Web Tool Eval

Measure user-visible retrieval behavior without turning the benchmark into a framework.

## Canonical assets

- `evals/eval.json` — small historical-task corpus.
- `scripts/run_eval.py` — isolated Pi runner.
- `history.md` — outline of how Pi's web tools evolved and what each test found. Full reports and raw transcripts stay outside the repository.

Resolve these paths relative to this `SKILL.md`.

## Workflow

1. Run every case once against an explicit model and thinking level. Each case gets a fresh `pi --mode json --no-session` process, the natural prompt, normal global skills/extensions, `read,bash,web_read,web_search`, and read-only intent.
2. Grade user-visible behavior: retrieval triggered, authoritative content acquired, claims grounded, blocks handled safely, and request budget respected.
3. Change one behavior at a time, then rerun the same corpus with the same model. Repeat only flaky or changed cases before paying for another full run.
4. Add a case only for an observed failure class. Prefer replacing redundant cases and keep the core corpus around 12–16 cases.

## Run

```zsh
skill=~/.pi/agent/skills/web-tool-eval
uv run --quiet python "$skill/scripts/run_eval.py" \
  --eval "$skill/evals/eval.json" \
  --provider anthropic \
  --model claude-opus-5-5 \
  --thinking high
```

The runner executes cases serially because concurrent Pi processes share the persistent browser profile. Cases that search start the local SearXNG container on first use. Use `--case <id>` to rerun selected cases and `--output <dir>` to choose an artifact directory.

## Report these dimensions

- Cases × runs, exact executor model, thinking level, duration, network attempts, and reported model cost.
- Behavioral trigger recall: positive prompts that made a network retrieval; negative controls that did not.
- Acquisition success and safe-failure counts.
- Grounding and route/budget failures.
- Exact failing case IDs and the smallest change they justify.

## Artifact and safety rules

- Default raw output to `$XDG_STATE_HOME/pi/web-tool-evals/` (or `~/.local/state/pi/web-tool-evals/`) with user-only permissions.
- Never commit raw page content, browser profiles, cookies, private URLs, or authenticated-page output.
- Keep only the sanitized corpus and `history.md` in the repository; add one dated entry per test.
- Graders inspect saved outputs without making new network requests. If grading is delegated, review their evidence before reporting results.
- Private GitHub/authentication canaries are optional runtime cases supplied by the user; do not store their URLs in the public corpus.
