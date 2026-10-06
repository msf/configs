import assert from "node:assert/strict";
import test from "node:test";
import { parseHTML } from "linkedom";
import { classifyPage, needsBrowser } from "./classify.ts";
import { domToText } from "./html-text.ts";

const longText = "Useful documentation content. ".repeat(200);

function observe(status: number | undefined, title: string, text: string, finalUrl = "https://example.com/docs", isHtml = true) {
  return classifyPage({ status, title, text, finalUrl, isHtml });
}

test("acquires an ordinary page", () => {
  assert.equal(observe(200, "Docs", longText).outcome, "acquired");
});

test("acquires a long article that discusses CAPTCHA", () => {
  const text = "How CAPTCHA works. Verify you are human. Press and hold. ".repeat(10) + longText;
  assert.equal(observe(200, "How CAPTCHA challenges work: a field guide", text).outcome, "acquired");
});

test("blocks a short HTTP 200 Cloudflare interstitial", () => {
  assert.equal(observe(200, "Just a moment...", "example.com needs to review the security of your connection").outcome, "blocked");
});

test("blocks Google's /sorry/ page", () => {
  const result = observe(200, "https://www.google.com/search?q=x", "About this page Our systems have detected unusual traffic from your computer network.", "https://www.google.com/sorry/index?continue=x");
  assert.equal(result.outcome, "blocked");
});

test("blocks DuckDuckGo's HTTP 202 challenge", () => {
  const result = observe(202, "x at DuckDuckGo", "Unfortunately, bots use DuckDuckGo too. Please complete the following challenge to confirm this search was made by a human.");
  assert.equal(result.outcome, "blocked");
});

test("never treats a bare HTTP 202 as acquired", () => {
  assert.equal(observe(202, "Report", longText).outcome, "incomplete");
});

test("blocks a 403 bot wall", () => {
  assert.equal(observe(403, "Access Denied", "You don't have permission to access this resource.").outcome, "blocked");
});

test("blocks a login wall", () => {
  assert.equal(observe(200, "Sign in · Portal", "Sign in to continue. Email Password", "https://p.example/account").outcome, "blocked");
});

test("fails a soft 404", () => {
  assert.equal(observe(200, "Page not found – Docs", "Sorry, we couldn't find that page.").outcome, "failed");
});

test("acquires a short page with real content", () => {
  assert.equal(observe(200, "T-40 torque values", "# T-40 torque values\n| Fastener | Torque\n| Main bolt | 42 N·m\nSpecification revision: KESTREL-1234").outcome, "acquired");
});

test("acquires short non-HTML bodies (raw files, JSON, PDFs)", () => {
  assert.equal(observe(200, "", '{"ok":true}', "https://api.example.com/x", false).outcome, "acquired");
  assert.equal(observe(200, "", "Page not found in index: 0", "https://example.com/a.txt", false).outcome, "acquired");
  assert.equal(observe(404, "", '{"message":"Not Found"}', "https://api.example.com/x", false).outcome, "failed");
});

test("reports an empty render as incomplete", () => {
  assert.equal(observe(200, "App", "").outcome, "incomplete");
});

test("asks for a browser when static HTML is an empty app shell", () => {
  assert.equal(needsBrowser('<div id="root"></div>', "").length > 0, true);
  assert.equal(needsBrowser("<p>x</p>", longText + "\nLoading service intervals…") !== undefined, true);
  assert.equal(needsBrowser("<p>x</p>", longText), undefined);
});

test("keeps link targets in extracted text", () => {
  const { document } = parseHTML('<html><body><p>See <a href="/r/abc">here</a>.</p><script>x()</script></body></html>');
  const text = domToText({ root: document.body, baseUrl: "http://h.example/docs/a", withLinks: true, useComputedStyle: false });
  assert.match(text, /here \[→ http:\/\/h\.example\/r\/abc\]/);
  assert.doesNotMatch(text, /x\(\)/);
});
