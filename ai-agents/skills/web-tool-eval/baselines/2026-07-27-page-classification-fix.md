# Browser page-classification fix — focused rerun

- Executor: `anthropic/claude-sonnet-4-5`, thinking `high`
- Cases: Shimano, Reddit, Medium; one isolated run each
- Deterministic classifier tests: 5/5 passed
- Each live case used one browser request and returned `is_error=true`
- Reddit's HTTP 200 network-security block is now classified as a challenge
- Medium's HTTP 403 Cloudflare page is now classified as a challenge
- Shimano's existing challenge behavior remains intact
- All three answers failed safely without using blocked content
- Skill activation remained 0/3; not part of this fix

Raw artifacts: `~/.local/state/pi/web-tool-evals/2026-07-27T15-03-26Z-claude-sonnet-4-5/`
