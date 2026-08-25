# Routing skill A/B — Claude Sonnet 4.5

## Setup

- Executor: `anthropic/claude-sonnet-4-5`, thinking `high`
- Corpus: 15 cases, one isolated run per configuration
- Old: pre-change `web-tool-routing`
- Candidate: broader search-oriented description, domain-native discovery guidance, GitHub guidance, and network-wide budgets

## Result

The candidate regressed and was reverted.

- Behavioral passes: 13/15 → 11/15
- Skill activation on positive cases: 0/13 → 5/13
- Network attempts: 36 → 42 (+16.7%)
- Duration: 542.2s → 711.4s (+31.2%)
- Reported model cost: $0.823 → $0.953 (+15.9%)
- Timeouts: 0 → 1 (`decathlon-support-read`)
- Pairwise verdicts: 1 better, 10 same, 4 worse
- Negative controls: 2/2 remained network-free in both configurations

The only improvement was exact-quote discovery, which avoided Google and DuckDuckGo challenges by using GitHub-native discovery (4 requests → 3). Regressions were current Go search (2 → 6 requests), PostgreSQL docs search (1 → 5), GitHub repository navigation (8 → 11), and Decathlon (useful answer → timeout).

## Decision

Do not optimize skill activation as an end in itself. Sonnet already retrieved evidence on every positive prompt without loading the skill, and the broader instructions caused redundant discovery. The live routing skill was restored exactly to the old version.

## Artifacts

- Old: `~/.local/state/pi/web-tool-evals/2026-07-27-sonnet-4-5-routing-old-15/`
- Candidate: `~/.local/state/pi/web-tool-evals/2026-07-27-sonnet-4-5-routing-candidate-15/`
- Pairwise grades: `~/.local/state/pi/web-tool-evals/2026-07-27-routing-ab-grades-{a,b,c}.json`
