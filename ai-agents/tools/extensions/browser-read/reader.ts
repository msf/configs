import { parseHTML } from "linkedom";
import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { existsSync } from "node:fs";
import { mkdir, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";
import type { BrowserSession } from "./browser-session.ts";
import { classifyPage, needsBrowser, type Classification } from "./classify.ts";
import { domToText } from "./html-text.ts";

export interface ReadResult extends Classification {
  url: string;
  finalUrl: string;
  status?: number;
  contentType: string;
  title: string;
  text: string;
  via: "http" | "browser";
  attempts: string[];
  artifactDir: string;
  textPath: string;
}

const MAX_HTTP_BYTES = 15 * 1024 * 1024;
const USER_AGENT =
  "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36";

const homeDir = process.env.HOME ?? ".";
export const profileDir = resolve(
  process.env.WEB_READ_PROFILE_DIR ?? join(homeDir, ".pi/agent/browser-read/profile"),
);
const artifactRootDir = resolve(process.env.WEB_READ_ARTIFACT_DIR ?? join(homeDir, ".pi/agent/browser-read/artifacts"));

export function browserExecutable(): string {
  const candidates = [
    process.env.PI_BROWSER_EXECUTABLE,
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    join(homeDir, "Applications/Google Chrome.app/Contents/MacOS/Google Chrome"),
    "/Applications/Chromium.app/Contents/MacOS/Chromium",
    join(homeDir, "Applications/Chromium.app/Contents/MacOS/Chromium"),
    "/usr/bin/google-chrome-stable",
    "/usr/bin/google-chrome",
    "/usr/bin/chromium",
    "/usr/bin/chromium-browser",
    "/snap/bin/chromium",
  ].filter((value): value is string => Boolean(value));
  const found = candidates.find((candidate) => existsSync(candidate));
  if (!found) throw new Error("No Chrome/Chromium executable found. Set PI_BROWSER_EXECUTABLE.");
  return found;
}

function throwIfAborted(signal: AbortSignal | undefined): void {
  if (signal?.aborted) throw new Error("web_read aborted");
}

async function newArtifactDir(): Promise<string> {
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  const dir = join(artifactRootDir, `${stamp}-${randomUUID().slice(0, 8)}`);
  await mkdir(dir, { recursive: true });
  return dir;
}

export function pdfToText(bytes: Uint8Array, signal?: AbortSignal): Promise<string> {
  return new Promise((resolvePromise, reject) => {
    const child = spawn("pdftotext", ["-layout", "-enc", "UTF-8", "-", "-"], { signal });
    const chunks: Buffer[] = [];
    let stderr = "";
    child.stdout.on("data", (chunk: Buffer) => chunks.push(chunk));
    child.stderr.on("data", (chunk: Buffer) => (stderr += chunk.toString()));
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0) resolvePromise(Buffer.concat(chunks).toString("utf8"));
      else reject(new Error(`pdftotext exited ${code}: ${stderr.slice(0, 200)}`));
    });
    child.stdin.end(Buffer.from(bytes));
  });
}

function isPdf(contentType: string, bytes: Uint8Array): boolean {
  return contentType.includes("application/pdf") || Buffer.from(bytes.slice(0, 5)).toString("latin1") === "%PDF-";
}

function isHtml(contentType: string): boolean {
  return contentType.includes("text/html") || contentType.includes("application/xhtml");
}

function htmlToText(html: string, baseUrl: string): { title: string; text: string } {
  const { document } = parseHTML(html);
  const title = String(document.querySelector("title")?.textContent ?? "").trim();
  const root = document.body ?? document.documentElement;
  const text = domToText({ root, baseUrl, withLinks: true, useComputedStyle: false });
  return { title, text };
}

async function readBody(response: Response, signal?: AbortSignal): Promise<Uint8Array> {
  const reader = response.body?.getReader();
  if (!reader) return new Uint8Array();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    throwIfAborted(signal);
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > MAX_HTTP_BYTES) {
      await reader.cancel();
      throw new Error(`response larger than ${MAX_HTTP_BYTES} bytes`);
    }
    chunks.push(value);
  }
  return Buffer.concat(chunks);
}

interface Acquired {
  status?: number;
  finalUrl: string;
  contentType: string;
  title: string;
  text: string;
  html: string;
}

async function httpAcquire(url: string, signal?: AbortSignal): Promise<Acquired> {
  const timeout = AbortSignal.timeout(20000);
  const combined = signal ? AbortSignal.any([signal, timeout]) : timeout;
  const response = await fetch(url, {
    redirect: "follow",
    signal: combined,
    headers: {
      "User-Agent": USER_AGENT,
      Accept: "text/html,application/xhtml+xml,application/json;q=0.9,application/pdf;q=0.9,*/*;q=0.8",
      "Accept-Language": "en-US,en;q=0.9",
    },
  });
  const bytes = await readBody(response, combined);
  const contentType = (response.headers.get("content-type") ?? "").toLowerCase();
  const finalUrl = response.url || url;
  if (isPdf(contentType, bytes)) {
    const text = await pdfToText(bytes, signal);
    return { status: response.status, finalUrl, contentType: "application/pdf", title: "", text, html: "" };
  }
  const raw = new TextDecoder().decode(bytes);
  if (isHtml(contentType) || /^\s*<(!doctype html|html)/i.test(raw)) {
    const parsed = htmlToText(raw, finalUrl);
    return { status: response.status, finalUrl, contentType, ...parsed, html: raw };
  }
  return { status: response.status, finalUrl, contentType, title: "", text: raw, html: "" };
}

async function scrollToBottom(page: import("playwright-core").Page, signal?: AbortSignal): Promise<void> {
  for (let step = 0; step < 20; step += 1) {
    throwIfAborted(signal);
    const atBottom = await page.evaluate(() => {
      window.scrollBy(0, window.innerHeight);
      return window.scrollY + window.innerHeight >= document.documentElement.scrollHeight - 4;
    });
    await page.waitForTimeout(250);
    if (atBottom) break;
  }
  await page.waitForLoadState("networkidle", { timeout: 2500 }).catch(() => undefined);
  await page.waitForTimeout(300);
}

async function browserAcquire(
  browser: BrowserSession,
  url: string,
  timeoutMs: number,
  signal?: AbortSignal,
): Promise<Acquired> {
  return browser.run({
    executablePath: browserExecutable(),
    headless: true,
    viewport: { width: 1440, height: 2000 },
  }, async (context) => {
    const page = context.pages()[0] ?? (await context.newPage());
    let response: import("playwright-core").Response | null = null;
    try {
      response = await page.goto(url, { waitUntil: "domcontentloaded", timeout: timeoutMs });
    } catch (error) {
      if (!String(error).includes("Download is starting")) throw error;
    }
    const headerType = (response?.headers()["content-type"] ?? "").toLowerCase();
    if (!response || headerType.includes("application/pdf")) {
      const download = await context.request.get(url, { timeout: timeoutMs });
      const bytes = await download.body();
      const contentType = (download.headers()["content-type"] ?? "").toLowerCase();
      if (isPdf(contentType, bytes)) {
        const text = await pdfToText(bytes, signal);
        return { status: download.status(), finalUrl: download.url(), contentType: "application/pdf", title: "", text, html: "" };
      }
      return { status: download.status(), finalUrl: download.url(), contentType, title: "", text: bytes.toString("utf8"), html: "" };
    }
    await page.waitForLoadState("load", { timeout: 5000 }).catch(() => undefined);
    await page.waitForLoadState("networkidle", { timeout: 3000 }).catch(() => undefined);
    await scrollToBottom(page, signal);
    throwIfAborted(signal);
    const source = domToText.toString();
    const text = (await page.evaluate(
      `(${source})({ root: document.body ?? document.documentElement, baseUrl: location.href, withLinks: true, useComputedStyle: true })`,
    )) as string;
    const [title, html] = await Promise.all([page.title(), page.content()]);
    return { status: response.status(), finalUrl: page.url(), contentType: headerType, title, text, html };
  }, signal);
}

async function finish(
  url: string,
  acquired: Acquired,
  via: "http" | "browser",
  attempts: string[],
): Promise<ReadResult> {
  const artifactDir = await newArtifactDir();
  const textPath = join(artifactDir, "page.txt");
  await writeFile(textPath, acquired.text, "utf8");
  if (acquired.html) await writeFile(join(artifactDir, "page.html"), acquired.html, "utf8");
  const verdict = classifyPage({
    status: acquired.status,
    title: acquired.title,
    text: acquired.text,
    finalUrl: acquired.finalUrl,
    isHtml: Boolean(acquired.html) || isHtml(acquired.contentType),
  });
  return {
    ...verdict,
    url,
    finalUrl: acquired.finalUrl,
    status: acquired.status,
    contentType: acquired.contentType,
    title: acquired.title,
    text: acquired.text,
    via,
    attempts,
    artifactDir,
    textPath,
  };
}

function failure(url: string, via: "http" | "browser", attempts: string[], error: unknown): ReadResult {
  return {
    outcome: "failed",
    reason: `request failed: ${String((error as Error)?.message ?? error).split("\n")[0].slice(0, 200)}`,
    url,
    finalUrl: url,
    contentType: "",
    title: "",
    text: "",
    via,
    attempts,
    artifactDir: "",
    textPath: "",
  };
}

// HTTP first: most pages need no browser. Fall back to Chrome when the static
// response is blocked, incomplete, or only renders with JavaScript.
export async function readUrl(
  browser: BrowserSession,
  url: string,
  timeoutMs: number,
  signal?: AbortSignal,
): Promise<ReadResult> {
  const attempts: string[] = [];
  let httpResult: ReadResult | undefined;
  try {
    const acquired = await httpAcquire(url, signal);
    httpResult = await finish(url, acquired, "http", attempts);
    const fallbackReason =
      httpResult.outcome !== "acquired" && httpResult.outcome !== "failed"
        ? httpResult.reason
        : httpResult.outcome === "acquired" && isHtml(acquired.contentType)
          ? needsBrowser(acquired.html, acquired.text)
          : undefined;
    attempts.push(`http: ${httpResult.outcome} (${httpResult.reason})`);
    if (!fallbackReason) return httpResult;
    attempts.push(`browser fallback: ${fallbackReason}`);
  } catch (error) {
    throwIfAborted(signal);
    attempts.push(`http: failed (${String((error as Error)?.message ?? error).slice(0, 120)})`);
  }
  try {
    return await finish(url, await browserAcquire(browser, url, timeoutMs, signal), "browser", attempts);
  } catch (error) {
    throwIfAborted(signal);
    return httpResult ?? failure(url, "browser", attempts, error);
  }
}
