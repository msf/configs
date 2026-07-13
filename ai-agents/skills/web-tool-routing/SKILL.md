---
name: web-tool-routing
description: Choose the right existing tool for reading a URL or webpage. Use when the user asks to inspect web content, a Reddit post, or any URL and the right fetch method is unclear.
---

# Web Tool Routing

Use the cheapest tool that can correctly read the target.

## Routing rules

1. **APIs, machine-readable endpoints, and raw files**
   - Use existing efficient tooling: `bash` with `curl`/`wget`, or a short Python script.
   - Examples: `/api/`, JSON endpoints, RSS/XML feeds, raw text, CSV, raw GitHub files, Hugging Face APIs.

2. **Ordinary pages that work as plain HTTP without browser state**
   - `curl` or a short script is still fine.
   - Do not pay the browser cost unless there is a concrete reason.

3. **Human-facing pages that need a real browser**
   - Use `browser_read_url` when the page likely needs JavaScript, cookies, browser rendering, or a real session.
   - Strong signals: Reddit, X/Twitter, LinkedIn, Instagram, Medium, Substack, consent walls, login walls, JS-heavy apps, anti-bot challenges.

4. **When `browser_read_url` hits a wall**
   - Tell the user to run `/browser-login <url>`.
   - They solve CAPTCHA, login, or consent manually in the real browser window.
   - Then retry `browser_read_url`.

5. **When browser output is truncated**
   - `browser_read_url` saves full text and HTML artifacts.
   - Use the normal `read` tool on those artifact paths if more context is needed.

## Browser automation vs Playwright

`browser_read_url` is the default browser-automation interface for reading rendered human webpages. Treat Playwright/Puppeteer as implementation mechanisms, not the first routing choice.

Do not install or script Playwright from `bash` just to read a page. Propose a Playwright-backed/custom browser tool only when the task requires multi-step DOM interaction: clicking, filling forms, scrolling, downloads, network capture, or repeated structured extraction that `browser_read_url` cannot handle.

## Budget guardrails

- Before the 4th browser read in a session, or the 3rd read for the same domain, pause and state why more pages are needed.
- After two blocked/login/CAPTCHA/403/empty results, stop hammering the site and ask for `/browser-login <url>` or an alternate source.
- For docs, check `llms.txt`, `sitemap.xml`, raw GitHub, or official APIs/search before crawling rendered pages.
- Prefer targeted artifact reads over repeatedly re-opening large pages.

## Decision heuristic

Ask: **Is this URL better treated like an API/file or like a human webpage?**

- If it is an API/file, stay with `curl`/Python.
- If it is a human webpage and plain fetches are flaky, incomplete, or blocked, use `browser_read_url`.

## Avoid

- Do not default to browser automation for every URL.
- Do not keep hammering a blocked site with ad hoc `curl`/Python fetches when the browser tool is the appropriate tool.
- Do not use the browser tool for direct downloads or API queries unless the user explicitly needs browser behavior.
