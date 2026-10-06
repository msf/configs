import assert from "node:assert/strict";
import { mkdtempSync, rmSync } from "node:fs";
import { createServer, type Server } from "node:http";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, before, test } from "node:test";

const state = mkdtempSync(join(tmpdir(), "web-read-test-"));
process.env.WEB_READ_PROFILE_DIR = join(state, "profile");
process.env.WEB_READ_ARTIFACT_DIR = join(state, "artifacts");
const { profileDir, readUrl } = await import("./reader.ts");
const { BrowserSession } = await import("./browser-session.ts");
const browser = new BrowserSession(profileDir);

// Minimal uncompressed one-page PDF containing "Brake model ZEPHYR-1234".
function pdfBytes(): Buffer {
  const stream = "BT /F1 12 Tf 72 720 Td (Brake model ZEPHYR-1234) Tj ET";
  const objects = [
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>",
    `<< /Length ${stream.length} >>\nstream\n${stream}\nendstream`,
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
  ];
  let out = "%PDF-1.4\n";
  const offsets: number[] = [];
  objects.forEach((body, index) => {
    offsets.push(out.length);
    out += `${index + 1} 0 obj\n${body}\nendobj\n`;
  });
  const xref = out.length;
  out += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  for (const offset of offsets) out += `${String(offset).padStart(10, "0")} 00000 n \n`;
  out += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  return Buffer.from(out, "latin1");
}

const filler = "<p>Ordinary documentation text about maintenance intervals and parts.</p>".repeat(20);
const pages: Record<string, { status: number; type: string; body: string | Buffer }> = {
  "/doc": { status: 200, type: "text/html", body: `<html><head><title>Doc</title></head><body>${filler}<p>See <a href="/r/abc">here</a>.</p></body></html>` },
  "/ddg": { status: 202, type: "text/html", body: "<html><body>Unfortunately, bots use DuckDuckGo too. Please complete the following challenge.</body></html>" },
  "/shell": { status: 200, type: "text/html", body: '<html><head><title>App</title></head><body><div id="root"></div><script>document.getElementById("root").innerHTML = "<p>Build code ORBIT-4242</p>" + "<p>Release notes.</p>".repeat(30);</script></body></html>' },
  "/manual.pdf": { status: 200, type: "application/pdf", body: pdfBytes() },
};
let server: Server;
let base = "";

before(async () => {
  server = createServer((req, res) => {
    const page = pages[req.url ?? ""];
    if (!page) {
      res.writeHead(404).end("not found");
      return;
    }
    res.writeHead(page.status, { "Content-Type": page.type }).end(page.body);
  });
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  assert.ok(address && typeof address === "object");
  base = `http://127.0.0.1:${address.port}`;
});

after(async () => {
  await browser.close();
  server.close();
  rmSync(state, { recursive: true, force: true });
});

test("reads an ordinary page over HTTP and keeps link targets", async () => {
  const result = await readUrl(browser, `${base}/doc`, 20000);
  assert.equal(result.outcome, "acquired");
  assert.equal(result.via, "http");
  assert.match(result.text, /here \[→ http:\/\/127\.0\.0\.1:\d+\/r\/abc\]/);
});

test("never reports a bot challenge as acquired", { timeout: 60000 }, async () => {
  const result = await readUrl(browser, `${base}/ddg`, 20000);
  assert.equal(result.outcome, "blocked");
});

test("renders a JavaScript-only page in the browser", { timeout: 60000 }, async () => {
  const result = await readUrl(browser, `${base}/shell`, 20000);
  assert.equal(result.outcome, "acquired");
  assert.equal(result.via, "browser");
  assert.match(result.text, /Build code ORBIT-4242/);
});

test("extracts PDF text", async () => {
  const result = await readUrl(browser, `${base}/manual.pdf`, 20000);
  assert.equal(result.outcome, "acquired");
  assert.match(result.text, /Brake model ZEPHYR-1234/);
});

test("reports a missing page as failed", async () => {
  const result = await readUrl(browser, `${base}/missing`, 20000);
  assert.equal(result.outcome, "failed");
});

test("stops when the caller aborts", async () => {
  const controller = new AbortController();
  controller.abort();
  await assert.rejects(readUrl(browser, `${base}/shell`, 20000, controller.signal));
});
