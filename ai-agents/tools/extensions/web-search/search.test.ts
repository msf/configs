import assert from "node:assert/strict";
import { createServer, type Server } from "node:http";
import { test } from "node:test";
import { formatResults, parseResults, search } from "./search.ts";

const body = {
  results: [
    { url: "https://go.dev/doc/devel/release", title: "Release History", content: "go1.27.1 (released 2026-09-01)" },
    { url: "https://go.dev/dl/", title: "Downloads", content: "" },
    { url: "javascript:void(0)", title: "junk" },
  ],
  unresponsive_engines: [["brave", "too many requests"]],
};

function listen(server: Server, port = 0): Promise<number> {
  return new Promise((resolve) => {
    server.listen(port, "127.0.0.1", () => {
      const address = server.address();
      assert.ok(address && typeof address === "object");
      resolve(address.port);
    });
  });
}

function fakeSearxng(): Server {
  return createServer((req, res) => {
    assert.match(req.url ?? "", /^\/search\?q=go\+release&format=json$/);
    res.writeHead(200, { "Content-Type": "application/json" }).end(JSON.stringify(body));
  });
}

test("keeps http results up to the limit and reports engines that failed", () => {
  const result = parseResults(body, 1);
  assert.deepEqual(result.hits.map((hit) => hit.url), ["https://go.dev/doc/devel/release"]);
  assert.deepEqual(result.failedEngines, ["brave (too many requests)"]);
});

test("labels results as discovery, not evidence", () => {
  const text = formatResults("go release", parseResults(body, 10));
  assert.match(text, /^DISCOVERY: /);
  assert.match(text, /2\. Downloads\n {3}https:\/\/go\.dev\/dl\//);
  assert.match(text, /Engines that did not answer: brave/);
  assert.doesNotMatch(text, /javascript:/);
});

test("queries a running instance without starting it", async () => {
  const server = fakeSearxng();
  const port = await listen(server);
  try {
    const result = await search("go release", 8, {
      baseUrl: `http://127.0.0.1:${port}`,
      start: () => assert.fail("start must not run when SearXNG answers"),
    });
    assert.equal(result.hits.length, 2);
  } finally {
    server.close();
  }
});

test("starts SearXNG once when it is unreachable, then retries", async () => {
  const probe = createServer();
  const port = await listen(probe);
  await new Promise((resolve) => probe.close(resolve));
  const server = fakeSearxng();
  let starts = 0;
  try {
    const result = await search("go release", 8, {
      baseUrl: `http://127.0.0.1:${port}`,
      start: async () => {
        starts += 1;
        await listen(server, port);
      },
    });
    assert.equal(starts, 1);
    assert.equal(result.hits.length, 2);
  } finally {
    server.close();
  }
});

test("propagates a failed start", async () => {
  const probe = createServer();
  const port = await listen(probe);
  await new Promise((resolve) => probe.close(resolve));
  await assert.rejects(
    search("go release", 8, {
      baseUrl: `http://127.0.0.1:${port}`,
      start: async () => {
        throw new Error("docker: permission denied");
      },
    }),
    /permission denied/,
  );
});
