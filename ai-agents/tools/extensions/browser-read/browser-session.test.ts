import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { mkdtemp, rm, symlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test, { type TestContext } from "node:test";
import { BrowserSession, waitForLastWindow, withProfileLock } from "./browser-session.ts";

async function profile(t: TestContext): Promise<string> {
  const dir = await mkdtemp(join(tmpdir(), "browser-session-test-"));
  t.after(() => rm(dir, { recursive: true, force: true }));
  return dir;
}

async function holdProfile(t: TestContext, dir: string) {
  const source = `
    import { withProfileLock } from ${JSON.stringify(new URL("./browser-session.ts", import.meta.url).href)};
    await withProfileLock(${JSON.stringify(dir)}, async () => {
      process.stdout.write("locked");
      process.stdin.resume();
      await new Promise(resolve => process.stdin.once("end", resolve));
    });
  `;
  const child = spawn(process.execPath, ["--input-type=module", "-e", source], {
    stdio: ["pipe", "pipe", "inherit"],
  });
  t.after(async () => {
    if (child.exitCode === null && child.signalCode === null) {
      const closed = once(child, "close");
      child.kill("SIGKILL");
      await closed;
    }
  });
  await Promise.race([
    once(child.stdout, "data"),
    once(child, "close").then(() => { throw new Error("Lock holder exited before acquiring lock"); }),
  ]);
  return child;
}

test("serializes independent processes and releases a crashed holder's lock", { timeout: 5000 }, async (t) => {
  const dir = await profile(t);
  const child = await holdProfile(t, dir);
  await assert.rejects(withProfileLock(dir, async () => assert.fail("overlapping access"), undefined, 0), /profile is busy/);
  const closed = once(child, "close");
  child.kill("SIGKILL");
  await closed;
  assert.equal(await withProfileLock(dir, async () => "released", undefined, 0), "released");
});

test("a waiting process acquires the lock after graceful release", { timeout: 5000 }, async (t) => {
  const dir = await profile(t);
  const child = await holdProfile(t, dir);
  const waiting = withProfileLock(dir, async () => "next", undefined, 2);
  child.stdin.end();
  assert.equal(await waiting, "next");
});

test("releases the lock when the operation fails", async (t) => {
  const dir = await profile(t);
  await assert.rejects(withProfileLock(dir, async () => { throw new Error("operation failed"); }), /operation failed/);
  assert.equal(await withProfileLock(dir, async () => true, undefined, 0), true);
});

test("cancels a lock waiter without running its operation", { timeout: 5000 }, async (t) => {
  const dir = await profile(t);
  await holdProfile(t, dir);
  await assert.rejects(
    withProfileLock(dir, async () => assert.fail("cancelled operation ran"), AbortSignal.timeout(100)),
    { name: "AbortError" },
  );
});

test("rejects pre-cancelled requests and invalid wait bounds", async (t) => {
  const dir = await profile(t);
  await assert.rejects(withProfileLock(dir, async () => assert.fail(), AbortSignal.abort()));
  for (const timeout of [-1, 0.5, 121]) {
    await assert.rejects(withProfileLock(dir, async () => assert.fail(), undefined, timeout), /timeout must be/);
  }
});

test("profile aliases share the same lock", { timeout: 5000 }, async (t) => {
  const dir = await profile(t);
  const alias = `${dir}-alias`;
  await symlink(dir, alias);
  t.after(() => rm(alias));
  await holdProfile(t, dir);
  await assert.rejects(withProfileLock(alias, async () => assert.fail(), undefined, 0), /profile is busy/);
});

const executablePath = process.env.PI_BROWSER_EXECUTABLE;
const browserTest = { skip: !executablePath, timeout: 15000 };
const launchOptions = { executablePath, headless: true };

test("closing the last headed window closes Chrome and permits profile reuse", browserTest, async (t) => {
  const dir = await profile(t);
  const browser = new BrowserSession(dir);
  await browser.run({ ...launchOptions, headless: false }, async (context) => {
    const windowsClosed = waitForLastWindow(context);
    const first = context.pages()[0];
    const second = await context.newPage();
    await first.close();
    assert.equal(context.pages().length, 1);
    await second.close();
    await windowsClosed;
  });
  await browser.run(launchOptions, async (context) => assert.equal(context.pages().length, 1));
});

test("separate sessions preserve login cookies in the shared profile", browserTest, async (t) => {
  const dir = await profile(t);
  await new BrowserSession(dir).run(launchOptions, async (context) => {
    await context.addCookies([{ name: "login", value: "synthetic", url: "https://example.com", expires: Math.floor(Date.now() / 1000) + 3600 }]);
  });
  await new BrowserSession(dir).run(launchOptions, async (context) => {
    const cookies = await context.cookies("https://example.com");
    assert.equal(cookies.find((cookie) => cookie.name === "login")?.value, "synthetic");
  });
});

test("read errors close Chrome and release its profile", browserTest, async (t) => {
  const browser = new BrowserSession(await profile(t));
  await assert.rejects(browser.run(launchOptions, async () => { throw new Error("read failed"); }), /read failed/);
  await browser.run(launchOptions, async (context) => assert.equal(context.pages().length, 1));
});

test("cancellation interrupts browser work and releases its profile", browserTest, async (t) => {
  const browser = new BrowserSession(await profile(t));
  const controller = new AbortController();
  await assert.rejects(browser.run(launchOptions, async (context) => {
    const page = context.pages()[0];
    controller.abort();
    await page.waitForTimeout(10000);
  }, controller.signal), /closed|aborted/i);
  await browser.run(launchOptions, async (context) => assert.equal(context.pages().length, 1));
});

test("session shutdown closes Chrome and rejects later work", browserTest, async (t) => {
  const browser = new BrowserSession(await profile(t));
  await browser.run(launchOptions, async (context) => {
    const closed = once(context, "close");
    await browser.close();
    await closed;
  });
  await assert.rejects(browser.run(launchOptions, async () => assert.fail()), /abort/i);
});

test("an unmanaged live Chrome gets an actionable error without breaking its lock", browserTest, async (t) => {
  const dir = await profile(t);
  const { chromium } = await import("playwright-core");
  const existing = await chromium.launchPersistentContext(dir, launchOptions);
  try {
    const browser = new BrowserSession(dir);
    await assert.rejects(browser.run(launchOptions, async () => assert.fail()), /Chrome already owns.*profile/);
    assert.equal(existing.pages().length, 1);
  } finally {
    await existing.close();
  }
});
