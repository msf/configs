# How Pi's web tools evolved, and what we tested

Last updated: 2026-10-06. Raw data and full reports stay on this machine under `~/.local/state/pi/web-tool-evals/`.

## Timeline

| Date | Change |
|---|---|
| Before 2026-04-15 | No web tools: Pi fetched pages with `curl` in bash. |
| 2026-04-15 | `browser-read` extension: `browser_read_url` reads pages in headless Chrome with a persistent profile, and `/browser-login` lets you solve a login or CAPTCHA by hand. The `web-tool-routing` skill says when to use curl and when to use the browser. |
| 2026-07-27 | The reader reports HTTP errors and known challenge pages (Reddit, Medium) as failures instead of content. |
| 2026-10-06 | `web_read` replaces `browser_read_url`, `web_search` is added (local SearXNG), and `web-tool-routing` is retired. |

## What we tested

### 2026-07-27: baseline and a broader routing skill (Sonnet 4.5, 12 to 15 tasks, 1 run each)

- **Baseline:** Sonnet went online for every task that needed it (11/11) without ever loading the routing skill. It got usable official content in 8 of 11 and handled 3 of 3 blocked sites without inventing content. The browser tool reported Reddit's and Medium's block pages as successes, and Sonnet noticed.
- **Broader routing skill (A/B):** the skill loaded more often (0/13 to 5/13), but results got worse: 13/15 tasks passed before and 11/15 after, runs took 31% longer and cost 16% more. Reverted. More routing prose made the agent search redundantly.
- **Reader fix:** after the change, the Reddit, Medium and Shimano block pages came back as errors, and all three answers failed safely.

### 2026-10-06: tournament (Opus 5.5, 30 tasks, 350 runs, with a gpt-6.1-sol cross-check)

It compared Pi as configured then against three ideas: a search tool, a new reader, and rewritten tool instructions with no skill. The two kinds of test gave different answers:

- **Component tests (each tool alone):**
  - Readers: the old reader labelled 25 of 61 pages correctly. It reported challenge, login and "not found" pages as content, dropped link targets and couldn't read PDFs. The new reader labelled 61 of 61 correctly.
  - Search: opening Google in the browser put a relevant page in the top 5 for 2 of 40 queries. Google blocked every query, and the Bing fallback silently returned unrelated results. SearXNG managed 29/40, Claude Code's search 30/40 and Codex's search 37/40.
- **End-to-end tests (the agent's final answers, 12 held-out tasks × 3 runs):**
  - No idea changed answer quality. Opus already passed 36 of 36 runs by working around the broken tools.
  - The new reader used 36% fewer tokens and finished 6 s sooner per task.
  - On gpt-6.1-sol, which works around broken tools less, the new reader raised the score from 0.91 to 0.99.
  - The rewritten instructions on top of the old reader made Opus trust a false "blocked" signal (1 task, 3 of 3 runs).

What shipped: `web_read`, and `web_search` on SearXNG rather than Codex, so Pi depends on no other agent harness. SearXNG answers in about 1 s and can't invent URLs. Its lower hit rate partly reflects strict scoring: some of its "misses" were official pages, for example in another locale. After shipping, Opus and gpt-6.1-sol both called `web_search` when asked to "search online" and skipped it otherwise (8 of 8 prompts).

## Lessons that still apply

- Grade what the user gets (correct facts, grounded claims, safe failure), not whether a skill loaded.
- Put guarantees in the tool's code. A strong model hides a broken tool, and a weaker one doesn't.
- Test each tool on its own as well as end to end, because the two can disagree.
- Before trusting a verdict, check every failure the grader flags against its transcript.
