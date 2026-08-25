import assert from "node:assert/strict";
import test from "node:test";
import { classifyPageFailure } from "./page-classification.ts";

test("accepts an ordinary successful page", () => {
  assert.equal(
    classifyPageFailure(200, "Documentation", "Useful documentation content", "https://example.com/docs"),
    undefined,
  );
});

test("detects Reddit's HTTP 200 network-security block", () => {
  assert.equal(
    classifyPageFailure(
      200,
      "",
      "You've been blocked by network security. If you think this is a mistake, file a ticket.",
      "https://www.reddit.com/?js_challenge=1",
    ),
    "challenge",
  );
});

test("detects Medium's Cloudflare verification page", () => {
  assert.equal(
    classifyPageFailure(
      403,
      "Just a moment...",
      "Performing security verification. This website uses a security service to protect against malicious bots.",
      "https://medium.com/article",
    ),
    "challenge",
  );
});

test("rejects an HTTP error without challenge text", () => {
  assert.equal(
    classifyPageFailure(404, "Page not found", "The requested page does not exist.", "https://example.com/missing"),
    "http-error",
  );
});

test("preserves existing challenge detection", () => {
  assert.equal(
    classifyPageFailure(200, "Verify", "Verify you are human to continue.", "https://example.com"),
    "challenge",
  );
});
