import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { DEFAULT_MAX_BYTES, DEFAULT_MAX_LINES, formatSize, truncateHead } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { BrowserSession, waitForLastWindow } from "./browser-session.ts";
import { browserExecutable, profileDir, readUrl, type ReadResult } from "./reader.ts";

const EXCERPT_CHARS = 400;

function parseHttpUrl(value: string): URL {
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    throw new Error(`Invalid URL: ${value}`);
  }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    throw new Error(`Unsupported URL protocol: ${parsed.protocol}`);
  }
  return parsed;
}

// The first line is an evidence label the model can rely on:
// ACQUIRED(url, status, complete) is citable; BLOCKED, INCOMPLETE and FAILED are not.
export function formatReadResult(result: ReadResult): { text: string; complete: boolean } {
  const status = result.status ?? "none";
  if (result.outcome !== "acquired") {
    const lines = [`${result.outcome.toUpperCase()}(url=${result.finalUrl}, status=${status}, reason=${result.reason})`];
    if (result.title) lines.push(`Title: ${result.title}`);
    if (result.attempts.length > 0) lines.push(`Attempts: ${result.attempts.join("; ")}`);
    lines.push("This output is not evidence of the page's content.");
    if (result.outcome === "blocked") lines.push(`If a login or challenge is the cause, the user can run /browser-login ${result.finalUrl}.`);
    const excerpt = result.text.trim().slice(0, EXCERPT_CHARS);
    if (excerpt) lines.push(`Page excerpt (not evidence):\n${excerpt}`);
    return { text: lines.join("\n"), complete: false };
  }
  const truncated = truncateHead(result.text, { maxBytes: DEFAULT_MAX_BYTES, maxLines: DEFAULT_MAX_LINES });
  const complete = !truncated.truncated;
  const lines = [`ACQUIRED(url=${result.finalUrl}, status=${status}, complete=${complete})`];
  if (result.title) lines.push(`Title: ${result.title}`);
  if (result.contentType) lines.push(`Content-Type: ${result.contentType}`);
  if (!complete) {
    lines.push(
      `Truncated: showing ${truncated.outputLines} of ${truncated.totalLines} lines ` +
        `(${formatSize(truncated.outputBytes)} of ${formatSize(truncated.totalBytes)}). ` +
        `Full text: ${result.textPath} (use read with offset).`,
    );
  }
  lines.push("", truncated.content.trim());
  return { text: lines.join("\n"), complete };
}

async function openPersistentBrowser(browser: BrowserSession, url: string): Promise<void> {
  await browser.run({
    executablePath: browserExecutable(),
    headless: false,
    viewport: { width: 1440, height: 1600 },
  }, async (context) => {
    const page = context.pages()[0] ?? (await context.newPage());
    // On macOS the app stays running after the last window closes.
    const windowsClosed = waitForLastWindow(context);
    if (url !== "about:blank") {
      // Navigation errors are fine here: the user fixes them in the visible window.
      await page.goto(url, { waitUntil: "domcontentloaded", timeout: 30000 }).catch(() => undefined);
    }
    await windowsClosed;
  });
}

export default function (pi: ExtensionAPI) {
  const browser = new BrowserSession(profileDir);
  pi.on("session_shutdown", () => browser.close());
  pi.registerCommand("browser-login", {
    description: "Open a real browser with the persistent web_read profile so you can solve CAPTCHA/login/consent manually",
    handler: async (args, ctx) => {
      const targetUrl = (args ?? "").trim() || "about:blank";
      const normalizedUrl = targetUrl === "about:blank" ? targetUrl : parseHttpUrl(targetUrl).toString();
      if (ctx.hasUI) ctx.ui.notify("Browser session opening. Solve CAPTCHA/login/consent, then close the browser window.", "info");
      await openPersistentBrowser(browser, normalizedUrl);
      if (ctx.hasUI) ctx.ui.notify(`Browser session saved to ${profileDir}`, "info");
    },
  });

  pi.registerTool({
    name: "web_read",
    label: "Web Read",
    description:
      "Read one URL (web page, PDF, JSON/API response, or raw file). Use it for every page whose content you will cite; curl in bash is also fine for JSON APIs and raw files. The output starts with an evidence label: ACQUIRED(url, status, complete) is citable evidence; BLOCKED, INCOMPLETE, and FAILED are not.",
    promptSnippet: "Read a URL and get a typed outcome plus its text.",
    promptGuidelines: [
      "Use web_read for human-facing pages, PDFs, and anything you will cite; use curl in bash only for JSON APIs and raw files.",
      "Cite only ACQUIRED output. BLOCKED, INCOMPLETE, and FAILED output is not evidence; after two such results for a site, stop and report what could not be acquired.",
      "When complete=false, read the saved full text with the read tool instead of fetching the page again.",
    ],
    parameters: Type.Object({
      url: Type.String({ description: "HTTP or HTTPS URL to read" }),
      timeoutMs: Type.Optional(Type.Integer({ description: "Browser navigation timeout in milliseconds", minimum: 1000, maximum: 120000 })),
    }),
    async execute(_toolCallId, params, signal, onUpdate) {
      const url = parseHttpUrl(params.url).toString();
      onUpdate?.({ content: [{ type: "text", text: `Reading ${url}...` }], details: undefined });
      const result = await readUrl(browser, url, params.timeoutMs ?? 30000, signal);
      const formatted = formatReadResult(result);
      return {
        content: [{ type: "text", text: formatted.text }],
        isError: result.outcome === "blocked" || result.outcome === "failed",
        details: {
          outcome: result.outcome,
          reason: result.reason,
          url: result.url,
          finalUrl: result.finalUrl,
          status: result.status,
          complete: formatted.complete,
          via: result.via,
          attempts: result.attempts,
          textPath: result.textPath,
        },
      };
    },
  });
}
