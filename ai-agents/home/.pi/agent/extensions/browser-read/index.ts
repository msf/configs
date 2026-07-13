import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import {
  DEFAULT_MAX_BYTES,
  DEFAULT_MAX_LINES,
  formatSize,
  truncateHead,
} from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { chromium } from "playwright-core";
import { randomUUID } from "node:crypto";
import { existsSync } from "node:fs";
import { mkdir, writeFile } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { join, resolve } from "node:path";

const homeDir = process.env.HOME ?? ".";
const browserRootDir = resolve(homeDir, ".pi/agent/browser-read");
const browserProfileDir = join(browserRootDir, "profile");
const browserArtifactRootDir = join(browserRootDir, "artifacts");

const challengeMarkers = [
  "prove your humanity",
  "verify you are human",
  "verify you're human",
  "captcha",
  "recaptcha",
  "attention required",
  "checking if the site connection is secure",
  "press and hold",
  "are you human",
  "access denied",
  "temporarily blocked",
];

let browserQueue: Promise<void> = Promise.resolve();
let cachedBrowserExecutable: string | undefined;

function withBrowserLock<T>(fn: () => Promise<T>): Promise<T> {
  const next = browserQueue.then(() => fn(), () => fn());
  browserQueue = next.then(() => undefined, () => undefined);
  return next;
}

function resolveBrowserExecutable(): string {
  if (cachedBrowserExecutable) return cachedBrowserExecutable;

  const explicitCandidates = [
    process.env.PI_BROWSER_EXECUTABLE,
    process.env.BROWSER_READ_EXECUTABLE,
    "/usr/bin/google-chrome-stable",
    "/usr/bin/google-chrome",
    "/snap/bin/chromium",
    "/usr/bin/chromium-browser",
    "/usr/bin/chromium",
  ].filter((value): value is string => Boolean(value));

  for (const candidate of explicitCandidates) {
    if (existsSync(candidate)) {
      cachedBrowserExecutable = candidate;
      return candidate;
    }
  }

  for (const command of ["google-chrome-stable", "google-chrome", "chromium-browser", "chromium"]) {
    const result = spawnSync("bash", ["-lc", `command -v ${command}`], { encoding: "utf8" });
    const resolvedPath = result.stdout.trim();
    if (result.status === 0 && resolvedPath) {
      cachedBrowserExecutable = resolvedPath;
      return resolvedPath;
    }
  }

  throw new Error(
    "No supported Chrome/Chromium executable found. Set PI_BROWSER_EXECUTABLE to your browser path.",
  );
}

function parseHttpUrl(value: string): URL {
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    throw new Error(`Invalid URL: ${value}`);
  }

  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    throw new Error(`Unsupported URL protocol for browser reading: ${parsed.protocol}`);
  }

  return parsed;
}

function makeArtifactDirName(): string {
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  return `${timestamp}-${randomUUID().slice(0, 8)}`;
}

function detectChallengePage(title: string, bodyText: string, finalUrl: string): boolean {
  const haystack = `${title}\n${bodyText.slice(0, 8000)}\n${finalUrl}`.toLowerCase();
  return challengeMarkers.some((marker) => haystack.includes(marker));
}

async function openPersistentBrowser(url: string): Promise<{ browserExecutable: string; profileDir: string }> {
  const browserExecutable = resolveBrowserExecutable();
  await mkdir(browserProfileDir, { recursive: true });

  const context = await chromium.launchPersistentContext(browserProfileDir, {
    executablePath: browserExecutable,
    headless: false,
    viewport: { width: 1440, height: 1600 },
  });

  try {
    const page = context.pages()[0] ?? await context.newPage();
    if (url !== "about:blank") {
      await page.goto(url, { waitUntil: "domcontentloaded", timeout: 30000 }).catch(() => undefined);
    }

    await new Promise<void>((resolve) => {
      context.once("close", () => resolve());
    });
  } finally {
    if (context.browser()?.isConnected()) {
      await context.close().catch(() => undefined);
    }
  }

  return { browserExecutable, profileDir: browserProfileDir };
}

async function readRenderedPage(params: {
  url: string;
  timeoutMs: number;
  saveScreenshot: boolean;
}): Promise<{
  title: string;
  finalUrl: string;
  responseStatus?: number;
  text: string;
  browserExecutable: string;
  profileDir: string;
  artifactDir: string;
  textPath: string;
  htmlPath: string;
  screenshotPath?: string;
}> {
  const browserExecutable = resolveBrowserExecutable();
  await mkdir(browserProfileDir, { recursive: true });
  await mkdir(browserArtifactRootDir, { recursive: true });

  const artifactDir = join(browserArtifactRootDir, makeArtifactDirName());
  await mkdir(artifactDir, { recursive: true });

  const context = await chromium.launchPersistentContext(browserProfileDir, {
    executablePath: browserExecutable,
    headless: true,
    viewport: { width: 1440, height: 2000 },
  });

  try {
    const page = context.pages()[0] ?? await context.newPage();
    const response = await page.goto(params.url, {
      waitUntil: "domcontentloaded",
      timeout: params.timeoutMs,
    });

    await page.waitForLoadState("load", { timeout: 5000 }).catch(() => undefined);
    await page.waitForLoadState("networkidle", { timeout: 3000 }).catch(() => undefined);
    await page.waitForTimeout(500);

    const [title, finalUrl, text, html] = await Promise.all([
      page.title(),
      Promise.resolve(page.url()),
      page.locator("body").innerText({ timeout: 5000 }).catch(async () =>
        page.evaluate(() => document.body?.innerText ?? ""),
      ),
      page.content(),
    ]);

    const textPath = join(artifactDir, "page.txt");
    const htmlPath = join(artifactDir, "page.html");
    await writeFile(textPath, text, "utf8");
    await writeFile(htmlPath, html, "utf8");

    let screenshotPath: string | undefined;
    const challengeDetected = detectChallengePage(title, text, finalUrl);
    if (params.saveScreenshot || challengeDetected) {
      screenshotPath = join(artifactDir, "page.png");
      await page.screenshot({ path: screenshotPath, fullPage: true }).catch(() => undefined);
    }

    if (challengeDetected) {
      throw new Error(
        `Challenge or login wall detected at ${finalUrl}. Run /browser-login ${finalUrl}, solve it manually, then retry browser_read_url. Artifacts: ${artifactDir}`,
      );
    }

    return {
      title,
      finalUrl,
      responseStatus: response?.status(),
      text,
      browserExecutable,
      profileDir: browserProfileDir,
      artifactDir,
      textPath,
      htmlPath,
      screenshotPath,
    };
  } finally {
    await context.close().catch(() => undefined);
  }
}

export default function (pi: ExtensionAPI) {
  pi.registerCommand("browser-login", {
    description: "Open a real browser with the persistent browser-read profile so you can solve CAPTCHA/login/consent manually",
    handler: async (args, ctx) => {
      const targetUrl = (args ?? "").trim() || "about:blank";
      const normalizedUrl = targetUrl === "about:blank" ? targetUrl : parseHttpUrl(targetUrl).toString();

      if (ctx.hasUI) {
        ctx.ui.notify(
          "Browser session opening. Solve CAPTCHA/login/consent, then close the browser window.",
          "info",
        );
      }

      const result = await withBrowserLock(() => openPersistentBrowser(normalizedUrl));

      if (ctx.hasUI) {
        ctx.ui.notify(
          `Browser session saved to ${result.profileDir}`,
          "info",
        );
      }
    },
  });

  pi.registerTool({
    name: "browser_read_url",
    label: "Browser Read URL",
    description: "Open a human web page in a real browser session with persistent cookies/profile, then return the rendered text. Prefer this over curl/wget/Python fetches for JS-heavy or anti-bot pages.",
    promptSnippet: "Read a human web page through a real browser session with persistent cookies/profile.",
    promptGuidelines: [
      "Use this tool for user-facing web pages that may require JavaScript, cookies, or a real browser session.",
      "Prefer this over bash with curl/wget or ad hoc Python urllib/requests for human-facing page URLs.",
      "Do not use this tool for APIs, raw files, or direct downloads.",
      "If the tool reports a challenge or login wall, tell the user to run /browser-login <url> and retry.",
    ],
    parameters: Type.Object({
      url: Type.String({ description: "HTTP or HTTPS page URL to open in the browser" }),
      timeoutMs: Type.Optional(Type.Integer({
        description: "Navigation timeout in milliseconds",
        minimum: 1000,
        maximum: 120000,
      })),
      saveScreenshot: Type.Optional(Type.Boolean({
        description: "Save a screenshot artifact alongside the extracted text",
      })),
    }),
    async execute(_toolCallId, params, _signal, onUpdate) {
      const normalizedUrl = parseHttpUrl(params.url).toString();
      const timeoutMs = params.timeoutMs ?? 30000;
      const saveScreenshot = params.saveScreenshot ?? false;

      onUpdate?.({
        content: [{ type: "text", text: `Opening ${normalizedUrl} in the browser...` }],
        details: {},
      });

      const result = await withBrowserLock(() => readRenderedPage({
        url: normalizedUrl,
        timeoutMs,
        saveScreenshot,
      }));

      const truncated = truncateHead(result.text, {
        maxBytes: DEFAULT_MAX_BYTES,
        maxLines: DEFAULT_MAX_LINES,
      });

      let text = `Title: ${result.title || "(untitled)"}\nURL: ${result.finalUrl}`;
      if (result.responseStatus !== undefined) {
        text += `\nStatus: ${result.responseStatus}`;
      }
      text += `\n\n${truncated.content.trim()}`;

      if (truncated.truncated) {
        text += `\n\n[Text truncated: ${truncated.outputLines} of ${truncated.totalLines} lines`;
        text += ` (${formatSize(truncated.outputBytes)} of ${formatSize(truncated.totalBytes)}).`;
        text += ` Full text: ${result.textPath}. HTML: ${result.htmlPath}`;
        if (result.screenshotPath) text += `. Screenshot: ${result.screenshotPath}`;
        text += "]";
      } else {
        text += `\n\n[Full text: ${result.textPath}. HTML: ${result.htmlPath}`;
        if (result.screenshotPath) text += `. Screenshot: ${result.screenshotPath}`;
        text += "]";
      }

      return {
        content: [{ type: "text", text }],
        details: {
          title: result.title,
          finalUrl: result.finalUrl,
          responseStatus: result.responseStatus,
          browserExecutable: result.browserExecutable,
          profileDir: result.profileDir,
          artifactDir: result.artifactDir,
          textPath: result.textPath,
          htmlPath: result.htmlPath,
          screenshotPath: result.screenshotPath,
        },
      };
    },
  });
}
