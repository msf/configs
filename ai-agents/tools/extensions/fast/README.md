# OpenAI fast mode

Run `/reload` after installation, then `/fast` to toggle priority service.
`/fast on`, `/fast off`, and `/fast status` are also available.

New sessions default to off. The setting follows the current session branch and
survives reload/resume. The footer shows `fast: priority`, or `fast: paused` when
an unsupported model is selected. Only `openai` and `openai-codex` are supported.

When enabled, the extension sets `service_tier: "priority"` in outgoing provider
payloads without changing reasoning effort. Turning it off stops overriding the
provider's configured tier. OpenAI decides availability and billing; requesting
priority does not prove it was granted. Higher costs or subscription usage may
apply. Pi's estimated costs may not reflect the priority surcharge.

Uses Pi 1.3.0's `before_provider_request` extension hook. Verified with local
payload tests and Pi's extension loader; no paid provider request was made.

Run tests with Node 24 or newer:

```sh
node --test ~/.pi/agent/extensions/fast/index.test.mjs
```
