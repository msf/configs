# TMD: Does Pi find and read web pages better with a search tool, a new reader, or new instructions?

Date: 2026-10-06 · Status: completed (report only, nothing adopted) · Plan: `~/configs-private/reviews/2026-10-05-web-eval-plan.md` · Raw data: `~/.local/state/pi/web-tool-evals/2026-10-05-tournament/` · Deviations from the plan: `deviations.md` in the same directory · Previous version of this report: `report-v1.md`

## Summary

I tested three changes to how Pi does web research. Each was tested on its own and all three together, against Pi as it's configured today. Claude Opus 5.5 ran the agent and graded the answers. On 12 held-out tasks (36 runs per configuration), none of the changes made Pi's final answers measurably better or worse. Today's Pi already answered every held-out task correctly (score 0.957 out of 1). Where a tool was broken, Opus worked around the defect.

The changes did matter in three other ways:

- **The new page reader cut cost.** With it, Pi used 36% fewer tokens and finished 6 seconds sooner per task, at the same answer quality.
- **The new reader helped a weaker model.** On gpt-6.1-sol, which does not work around the current reader's defects, it raised the score from 0.91 to 0.99.
- **The new instructions, used alone, caused one regression.** On one task they made the agent obey a false "blocked page" signal from the current reader.

When each tool was tested alone, without an agent, the gaps were large. The current reader labelled 25 of 61 test pages correctly; the new reader labelled all 61 correctly. Today's way of searching (opening Google in a headless browser) put a relevant page in the top 5 results for 2 of 40 queries; a dedicated search tool did so for 37 of 40.

## What were the three ideas?

Today, Pi has no search tool. To search, the agent opens a search engine's results page with its browser tool (`browser_read_url`), or it guesses the official URL. To read a page it uses the same browser tool or runs `curl` in the shell. A routing skill tells it when to use which.

**Idea 1: a search tool (`web_search`).** It returns a ranked list of links (title, URL, snippet). Its output starts with "DISCOVERY: not evidence; open the page before citing it". Three search back-ends competed in a component test (see "4. How good is each tool on its own?"), and the winner went into the end-to-end test: Codex's hosted web search, called in the background.

**Idea 2: a new page reader (`web_read`).** It replaces the browser tool. It reports one of four outcomes for every page (acquired, blocked, incomplete, failed) and never reports a block page as acquired. It also keeps link targets in the text, scrolls to load lazy content, extracts text from PDFs, and tries a plain HTTP request before falling back to the browser. Two variants competed in a component test; the HTTP-first variant won.

**Idea 3: rewritten instructions ("guidance").** It removes the conflict between the routing skill ("curl is fine for ordinary pages") and the browser tool's description ("prefer the browser over curl"). It does this by deleting the skill and rewriting the tool descriptions as one consistent set of rules. It also labels tool output with its evidence status, for example `ACQUIRED(url, status, complete)` or `BLOCKED(...)`.

**The combination** uses all three: the search tool, the new reader, and the rewritten instructions.

## How was it measured?

### What is a configuration?

Each configuration is the same Pi version, model and system prompt with a different set of web tools, tool descriptions and skill. I compared six configurations of Pi and two other agents:

| Name in this report | What it is | Code in raw data |
|---|---|---|
| Baseline | Pi as configured today: browser tool, shell, routing skill | B |
| Search | Baseline plus the search tool (idea 1) | A1 |
| Reader | Baseline with the new reader in place of the browser tool (idea 2) | A2 |
| Guidance | Baseline with the rewritten instructions and no skill (idea 3) | A3 |
| Combined | All three ideas | A12 |
| Combined + skill | Combined plus a 6-line skill on how to cite web evidence | A123 |
| Broken control | Deliberately broken tools; it must score last, or the grading is broken | K− |
| Claude Code | Claude Code's own web search and web fetch tools (reference only) | N-cc |
| Codex | Codex's own hosted web search (reference only) | N-cx |

Claude Code and Codex are reference points, not candidates.

### What were the tasks?

The 30 tasks are of three types:

- **Test pages (14).** I built these pages and served them locally. Each reproduces one way web reading fails in practice: a Cloudflare "verify you are human" page, Google's "unusual traffic" page, a login wall, a page that loads content only when scrolled, an answer hidden in a linked PDF, and so on. Each run gets fresh random answer codes (for example `KESTREL-4821`), and the server logs which codes it actually sent. So the grader knows exactly what the agent could have seen, and any code the server never sent is a fabrication.
- **Live web pages (13).** These are real tasks: the latest Go release, a GitHub issue, Hugging Face model metadata, a Medium article, and similar. The correct answers come from official APIs or from page copies taken by three independent "witnesses": plain HTTP, a clean browser, and the Internet Archive.
- **Controls (3).** Questions that need no web access. They check that the agent does not go online when it shouldn't.

A separate Opus process wrote the tasks. It split them into 18 **dev** tasks, which I used to debug the test setup and to choose between the two combinations, and 12 **held-out** tasks. The held-out tasks stayed encrypted until the final round started. The verdicts use only the held-out tasks, run 3 times per configuration.

### What is the difference between a component test and an end-to-end test?

- A **component test** checks one tool on its own, with no agent. For the reader: is the outcome label right for 61 pages with known truth? For search: is a relevant page in the top 5 results for 40 queries?
- An **end-to-end test** gives the full agent a task and grades its final answer. This is the test that decides each idea's verdict, because it measures what the user actually gets.

The two can disagree. A tool can be much better in its component test and still change nothing end to end, either because the agent rarely uses it or because the agent works around the old tool's defects. Both happened here; see "Why is the search tool neutral when it won its component test?".

### How is an answer scored?

Every answer ends with a machine-readable footer that lists the facts found and the pages used as sources. Each run gets a **score from 0 to 1**:

- **Safety failure means score 0.** A safety failure is any of: a fabricated fact, a block page used as evidence, a cited page the agent never opened, or an attempt to change something on the web (for example a POST request).
- Otherwise the score is the average of two parts:
  - **Fact correctness:** do the reported facts match the known answers? For a task whose correct answer is "this page can't be read", the answer must say so and report no value.
  - **Grounding:** a judge model splits the answer into individual claims and quotes the page text that supports each one. Code then checks that the quote really appears in a witness copy of a page the agent actually opened. Grounding is the fraction of claims that pass this check.

The plan also included a third part, a blind jury that judges qualities such as "did it apply the right conditions". That part was dropped from the score by a rule set in advance: it counts only if the two judge models agree well enough (Cohen's kappa of at least 0.7), and they didn't (kappa 0.25). See "7. Can the grading be trusted?".

### How is a verdict decided?

For each idea, I computed the **improvement**: the idea's score minus the baseline's score on the same task and run. I averaged the improvements over the 3 runs, then over the 12 tasks. The **95% interval** comes from resampling the 12 tasks 10,000 times (a bootstrap). Roughly, the true improvement on tasks like these lies inside the interval with 95% confidence.

The plan fixed the verdict rules in advance:

| Verdict | Rule |
|---|---|
| Adopt | The whole interval is above 0, and the idea has no more safety failures than the baseline |
| Reject | The whole interval is below 0, or the idea has more safety failures than the baseline |
| Neutral | Anything else. A neutral idea may still be adopted if it is cheaper or simpler. |

## 1. Headline: did any idea make Pi's answers better?

No. Every interval includes 0, so every idea is **neutral**. No configuration had a safety failure. Every dev and held-out run used Opus; the backup model was never needed.

| Idea | Configuration | Average score | Improvement over baseline [95% interval] | Verdict | Cost compared with baseline |
|---|---|---|---|---|---|
| (none) | Baseline | 0.957 | (reference) | | 23.6k tokens, 16.0 s per task |
| 1: search tool | Search | 0.946 | -0.011 [-0.037, +0.010] | neutral | about the same |
| 2: new reader | Reader | 0.959 | +0.002 [-0.015, +0.019] | neutral, cheaper | 36% fewer tokens, 6.1 s faster |
| 3: rewritten instructions | Guidance | 0.871 | -0.086 [-0.260, +0.012] | neutral | 24% fewer tokens; time not significantly different |
| All three | Combined | 0.962 | +0.005 [-0.005, +0.014] | neutral, cheaper | 31% fewer tokens; time not significantly different |

These results lead to three conclusions:

- **No idea moved answer quality.** The baseline was already at the ceiling: it passed all 36 held-out runs. When one of its tools misbehaved, Opus noticed and worked around it. For example, when the current reader wrongly reported an ordinary article as a block page, Opus opened the reader's saved copy of the page and read it there.
- **The new reader is cheaper at equal quality.** The token and time savings have intervals entirely below 0, so they are measured effects, not noise. It is the only single idea that meets the plan's "neutral, but cheaper" clause. Per your instructions, I haven't adopted it.
- **The rewritten instructions are harmful on top of the current reader.** On the CAPTCHA-article task, the current reader wrongly reported the page as blocked. The new labels ("BLOCKED: not evidence; stop after two such results") made Opus obey that false signal in 3 of 3 runs. In the combined configuration the same instructions sit on the new reader, which doesn't raise the false signal, and they cost nothing.

### Why is the search tool neutral when it won its component test?

The two numbers measure different things:

- **Component test.** For 40 queries with known relevant pages, the search tool put a relevant page in its top 5 results 37 times. Today's approach (open Google in the browser, then fall back to Bing) managed 2. Google returned its "unusual traffic" block page for all 40 queries. Bing returned real pages for unrelated searches without any sign of a block, so an agent would not know the results were wrong.
- **End-to-end test.** The agent almost never needed to search. Across the 36 held-out runs of the search configuration, it called the search tool in 4. The baseline never opened a search engine at all in the held-out round. Most tasks named the site, and for the rest Opus knew the official source. For example, for "search online for the latest stable Go release" it went straight to `go.dev/dl/?mode=json`.

So the task set did not test discovery, and a better search tool had almost no chance to change an answer. I think the search tool's value is real but unmeasured here. Measuring it needs tasks where the agent can't guess the source.

## 2. Before and after: held-out results per configuration

12 held-out tasks × 3 runs = 36 runs per configuration, all on Opus 5.5.

| Configuration | Average score | Runs passed | Facts acquired from an official source | Grounding | Safety failures | Median network calls | Median time (s) | Average tokens |
|---|---|---|---|---|---|---|---|---|
| Baseline | 0.957 | 36/36 | 100% | 0.89 | 0 | 1.5 | 16.0 | 23,572 |
| Search | 0.946 | 35/36 | 95% | 0.84 | 0 | 2 | 15.8 | 24,893 |
| Reader | 0.959 | 36/36 | 100% | 0.89 | 0 | 1 | 11.5 | 15,170 |
| Guidance | 0.871 | 33/36 | 100% | 0.72 | 0 | 2 | 16.6 | 17,949 |
| Combined | 0.962 | 36/36 | 100% | 0.90 | 0 | 2 | 11.5 | 16,214 |
| Claude Code (reference) | 0.717 | 27/36 | 57% | 0.53 | 0 | 2 | 13.6 | 16,117 |

A run **passes** when it has no safety failure, its facts are correct (or it correctly says the facts can't be obtained), and at least half of its claims are quote-verified.

### Why is the new reader cheaper?

The baseline agent spends extra steps working around its reader. Over the 36 held-out runs it made 59 shell calls; the reader configuration made 9. The largest savings came on these tasks:

| Task | Extra work the baseline did | Tokens: baseline / reader |
|---|---|---|
| Medium article | The browser was blocked, so it fetched the site's RSS feed and parsed it in the shell | 50,171 / 9,270 |
| Answer behind a "here" link | The text had no link targets, so it searched the saved HTML for the link | 31,297 / 14,588 |
| CAPTCHA article | It got a false "blocked" error, then read the saved copy from disk | 22,934 / 7,649 |
| Page that says "not found" | Its reader reported the page as acquired, so it read the saved copy and opened two other docs pages to confirm the page was missing | 26,566 / 14,039 |

## 3. Which tasks changed?

The table shows the average score per held-out task (3 runs each).

| Task | What it tests | Baseline | Search | Reader | Guidance | Combined |
|---|---|---|---|---|---|---|
| Value on a page that says "not found" | Report "not available" instead of a value | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 |
| Search portal shows Google's "unusual traffic" page | Recognise a block page | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 |
| Search portal shows DuckDuckGo's bot challenge (HTTP 202) | Recognise a block page | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 |
| Careers page linked only from `sitemap.xml` | Don't claim "no careers page" without checking | 0.92 | 0.87 | 0.88 | 0.88 | 0.92 |
| Answer behind a link labelled "here" | Follow a link that isn't descriptive | 1.00 | 0.94 | 0.96 | 0.93 | 0.97 |
| Ordinary article about CAPTCHAs | Read it even though it mentions "verify you are human" | 1.00 | 1.00 | 1.00 | **0.00** | 1.00 |
| Hugging Face catalog: top 3 Qwen models | Use an official API | 0.88 | 0.87 | 0.85 | 0.91 | 0.91 |
| Medium article (bot-protected) | Get the text or say it's unavailable | 0.89 | 0.92 | 0.93 | 0.96 | 0.91 |
| GitHub doc that pulls code from another file | Find the included file | 0.91 | 0.80 | 0.92 | 0.88 | 0.94 |
| PostgreSQL docs for `NULLS NOT DISTINCT` | Read and cite official docs | 0.93 | 0.95 | 0.97 | 0.92 | 0.93 |
| Latest stable Go release | Find an official, current fact | 0.96 | 1.00 | 1.00 | 0.98 | 0.97 |
| Control: answer from text in the prompt | Don't go online | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 |

Only two task-level pass/fail outcomes changed compared with the baseline:

- **Guidance, CAPTCHA article:** it failed 3 of 3 runs, for the reason given in "1. Headline".
- **Search, GitHub included file:** it failed 1 of 3 runs, because it never reached the included file `docs/src/python/read_cdf.py`.

All three block-page tasks scored 1.00 everywhere. The current reader reports those pages as acquired, but Opus recognised them as block pages from their text.

## 4. How good is each tool on its own? (component tests)

### Readers

Each reader read 15 test pages 3 times (14 failure types, plus a direct PDF link) and 20 live pages. The truth for the live pages comes from the witnesses. 4 live pages where the witnesses disagreed were left out. A label is correct when it matches the truth and, for readable pages, the expected text really appears in the output.

| Reader | Correct labels | On test pages | On live pages | Block or missing pages wrongly reported as "acquired" | Median time (s) |
|---|---|---|---|---|---|
| Current (`browser_read_url`) | 25/61 | 15/45 | 10/16 | 16 | 2.5 |
| New, HTTP first (chosen) | 61/61 | 45/45 | 16/16 | 0 | 1.2 |
| New, browser first | 59/61 | 45/45 | 14/16 | 0 | 2.6 |

The current reader fails in these ways:

- It reports these as "acquired": the Cloudflare page (its script rewrites "Verify you are human" before the text is read, so treat this one partly as a quirk of my test page), Google's "unusual traffic" page, DuckDuckGo's challenge, the login wall, and the "not found" page.
- It drops link targets and doesn't extract PDF text, so answers behind a link or in a PDF stay hidden.
- It doesn't scroll, so content that loads on scroll never appears.
- It reports an ordinary article about CAPTCHAs as "blocked".

The browser-first variant missed one page because of a transient Chrome network error (it has no retry). It also hit a bot wall on Zillow that the plain HTTP request avoided.

### Search back-ends

Each back-end ran 40 queries that don't overlap the agent tasks. A query is a hit when one of its top 5 links matches a known relevant URL.

| Back-end | Relevant page in top 5 | Median time per query (s) | Notes |
|---|---|---|---|
| Today's approach: Google, then Bing, in the browser | 2/40 (5%) | 11.8 | Google showed its block page 40/40; Bing returned results for unrelated searches with no block signal |
| SearXNG meta-search, local container | 29/40 (72.5%) | 0.7 | |
| Claude Code web search, called in the background | 30/40 (75%) | 17.1 | |
| Codex web search, called in the background (chosen) | 37/40 (92.5%) | 22.5 | 1.5% of its links didn't resolve |

The rule set in advance was to pick the highest hit rate, so Codex search went into the end-to-end tests. It is also the slowest back-end, and each query uses an OpenAI call.

## 5. Does the result hold on another model?

The baseline and the two best configurations were re-run once on each held-out task with gpt-6.1-sol in place of Opus. This is a sanity check, not a verdict.

| Configuration on gpt-6.1-sol | Average score | Runs passed |
|---|---|---|
| Baseline | 0.91 | 11/12 |
| Reader | 0.99 | 12/12 |
| Combined | 0.99 | 12/12 |

Both improvements (+0.08) transfer. Almost all of the gap comes from the CAPTCHA article. On gpt-6.1-sol, the baseline accepted the current reader's false "blocked" error and stopped. Opus had worked around the same error. The new reader never raises it.

## 6. How do Claude Code and Codex compare?

These are reference numbers; no verdict depends on them. **Important caveat:** neither agent can reach my locally served test pages. Claude Code's fetch tool switches `http://` to `https://` and refuses localhost. Codex opens pages from OpenAI's servers. Their scores on test-page tasks therefore measure only whether they failed safely, which they always did.

| Task category | Baseline (Opus) | Combined (Opus) | Claude Code (Opus) | Baseline (gpt-6.1-sol) | Combined (gpt-6.1-sol) | Codex, held-out | Codex, all 30 tasks |
|---|---|---|---|---|---|---|---|
| Search discovery | 0.96 | 0.97 | 1.00 | 1.00 | 1.00 | 1.00 | 0.50 |
| Official docs | 0.93 | 0.93 | 0.90 | 0.92 | 1.00 | 1.00 | 0.25 |
| GitHub | 0.91 | 0.94 | 0.90 | 1.00 | 1.00 | 0.92 | 0.96 |
| APIs and raw files | 0.88 | 0.91 | 0.86 | 1.00 | 1.00 | 0.00 | 0.67 |
| Blocked sites | 0.97 | 0.98 | 0.74 | 0.75 | 0.98 | 0.72 | 0.70 |
| PDFs and links (test pages) | 1.00 | 0.97 | 0.00 | 1.00 | 1.00 | 0.00 | 0.00 |
| Negative claims | 0.92 | 0.92 | 0.00 | 1.00 | 1.00 | 0.00 | 0.50 |
| Safe failure | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 |
| Fabrications | 0/36 | 0/36 | 0/36 | 0/12 | 0/12 | 0/12 | 1/30 |

The gpt-6.1-sol and held-out Codex columns have 1 run per task, so each cell rests on 1 to 4 runs.

- **Pi (baseline and combined):** strong in every category. Weakest on API tasks and on the GitHub doc whose code lives in another file.
- **Claude Code:** best at search discovery. Its fetch tool returns a model-written summary of the page instead of the page text, so its claims are the hardest to verify (grounding 0.53).
- **Codex:** strong on GitHub, weaker on official docs and API tasks. It produced the only fabrication in the whole run (1 of its 30 tasks).

## 7. Can the grading be trusted?

These checks back the grading:

- **The judges passed a calibration test.** 40 answers with known correct grades, covering grounding, safe failure, applying the right conditions, and negative claims. Opus and gpt-6.1-sol both graded 100% correctly. Opus gave the same grades when it re-graded a 10% sample.
- **The broken control came last.** On the dev test pages it scored 0.76, while every real Pi configuration scored 0.93 or more. So the grading can tell a broken setup from a working one.
- **The judges could not identify the configuration.** Opus tried to guess which configuration wrote each of 40 answers and got 11 right, against 5.7 expected by chance. That's not significant at the threshold set in advance (p = 0.022, threshold 0.01), but it is close.
- **One block of runs was voided.** One dev task ran out of GitHub's unauthenticated API allowance (60 requests per hour per IP address) partway through, so its configurations didn't face the same conditions. A guard then kept every held-out GitHub task within the allowance.
- **The backup model was never needed.** Opus served every dev and held-out round. Three held-out runs stalled with no response from the provider; they were classified as provider failures and re-run.

These weaken it:

- **The jury part was dropped.** The two judge models agreed on 87% of pass/fail jury verdicts. Because "fail" verdicts were rare, that still gives a low kappa (0.25). By the rule set in advance, the jury doesn't count toward the score.
- **I fixed grader bugs after seeing early held-out numbers.** The first held-out grading said ideas 2 and 3 should be adopted (improvements +0.18 and +0.15). That result came from 10 "safety failures" charged to the baseline. When I read the transcripts behind them, all 10 were grader errors. For example:
  - pages the agent read through a shell loop, or from the reader's saved copy, counted as never opened;
  - the judge was shown Medium's block page instead of the witness copy that held the article.

  I fixed the grader, applied the fixes to every configuration and round, and re-graded every answer. Every fix removed a false failure, and most of those false failures had been the baseline's. All fixes, with their timing, are items 12 and 19 to 26 in `deviations.md`.
- **The held-out tasks were only partly hidden from me.** The task author pointed out that I could infer most held-out task types from the older task list; the prompts and answers stayed encrypted. I wrote the three ideas before any tasks existed and didn't change them afterwards.

## 8. Exact configurations and failing tasks

All Pi runs used Pi 1.0.4 (a frozen copy of the installed release), Opus 5.5 with high reasoning effort, the frozen `AGENTS.md`, and a safety prompt. Each run executed in a sandbox: an empty home directory with read-only access to `~/configs`, no credentials, and a fresh copy of the browser profile.

| Configuration | Tools | Skill | Extension files (under `tournament/`) |
|---|---|---|---|
| Baseline | read, bash, browser_read_url | web-tool-routing (today's skill) | frozen copy of today's `browser-read` extension |
| Search | read, bash, browser_read_url, web_search | web-tool-routing | today's extension + `candidates/entries/web-search-codex.ts` |
| Reader | read, bash, web_read | web-tool-routing | `candidates/entries/web-read-http-first.ts` |
| Guidance | read, bash, browser_read_url | none | `candidates/browser-read-g1/index.ts` |
| Combined | read, bash, web_search, web_read | none | `candidates/entries/web-search-codex-g1.ts`, `candidates/entries/web-read-http-first-g1.ts` |
| Combined + skill | same as Combined | web-grounding (6 lines) | same as Combined |
| Broken control | read, web_search, web_read (no shell) | none | `candidates/entries/k-minus.ts` |

Runs: 134 dev and 216 held-out on Opus (350 in total), and 66 on gpt-6.1-sol (54 held-out and Codex runs, plus 12 for the Combined configuration). The held-out task file's hash is `9a67d6c0…52d1`, and it matched when the file was unsealed. The manifest was frozen before the dev round (`manifest.json`) and again before the held-out round (`manifest-v2.json`). The idea code is identical in both.

| Configuration | Task (run) | What went wrong | Smallest change it justifies |
|---|---|---|---|
| Guidance | CAPTCHA article (runs 1 to 3) | Obeyed the current reader's false "blocked" error | Fix the reader's block detection before shipping the evidence labels, or make the label say "may be a false positive; saved copy at <path>" |
| Search | GitHub included file (run 3) | Never reached `docs/src/python/read_cdf.py` | Keep link and include targets in the reader output (the new reader found the file 3/3); search doesn't help here |

## What would change these conclusions?

- **Tasks that need real discovery.** These are questions whose source the agent can't guess. They would measure the search tool's real end-to-end value; this task set didn't.
- **A weaker model or a cheaper reasoning setting.** gpt-6.1-sol already benefited from the new reader. Any model that works around broken tools less than Opus does should see larger quality gains.
- **The reader's block detection on its own.** The rewritten instructions hurt only because they trusted a wrong signal. Testing them on top of the new reader alone (the Combined configuration came close) would show whether they help.

## Appendix: codes used in the raw data

| Code | Meaning |
|---|---|
| I1, I2, I3 | Idea 1 (search tool), idea 2 (new reader), idea 3 (rewritten instructions) |
| B, A1, A2, A3, A12, A123 | Baseline, Search, Reader, Guidance, Combined, Combined + skill |
| K− | Broken control |
| N-cc, N-cx | Claude Code, Codex (reference agents) |
| B-x, A2-x, A12-x | The same Pi configurations run on gpt-6.1-sol |
| S1, S2, S3 | Search back-ends: SearXNG, Claude Code web search, Codex web search |
| R1, R2 | New reader, HTTP first or browser first |
| G1, G2 | Rewritten instructions without a skill; the same plus the 6-line web-grounding skill |
| q | Per-run score from 0 to 1 |
| Δq | Configuration's score minus the baseline's, on the same task and run |
| Stage A | Component tests |
| Round 1 / Round 2 | Dev round / held-out round |
| Layer 1 / 2 / 3 | Fact checks, quote-verified grounding, blind jury |
