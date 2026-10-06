import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

export interface SearchHit {
  url: string;
  title: string;
  snippet: string;
}

export interface SearchResult {
  hits: SearchHit[];
  failedEngines: string[];
}

export interface SearchOptions {
  baseUrl: string;
  start: (signal?: AbortSignal) => Promise<void>;
  signal?: AbortSignal;
}

export const SCRIPT_PATH = fileURLToPath(new URL("./searxng.sh", import.meta.url));

const DEFAULT_PORT = 28100;
const REQUEST_TIMEOUT_MS = 20_000;
// The first start may pull the pinned image (about 264 MB).
const START_TIMEOUT_MS = 180_000;
const SNIPPET_CHARS = 300;

export function searxngUrl(): string {
  const port = Number(process.env.SEARXNG_PORT ?? DEFAULT_PORT);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error(`SEARXNG_PORT must be a TCP port, got ${process.env.SEARXNG_PORT}`);
  }
  return `http://127.0.0.1:${port}`;
}

async function query(baseUrl: string, text: string, signal?: AbortSignal): Promise<unknown> {
  const timeout = AbortSignal.timeout(REQUEST_TIMEOUT_MS);
  const params = new URLSearchParams({ q: text, format: "json" });
  const response = await fetch(`${baseUrl}/search?${params}`, {
    signal: signal ? AbortSignal.any([signal, timeout]) : timeout,
  });
  if (!response.ok) throw new Error(`SearXNG returned HTTP ${response.status}`);
  return response.json();
}

// fetch reports refused or reset connections as TypeError; timeouts and aborts are DOMExceptions.
function isUnreachable(error: unknown): boolean {
  return error instanceof TypeError;
}

export function parseResults(data: unknown, limit: number): SearchResult {
  const body = (data ?? {}) as { results?: unknown; unresponsive_engines?: unknown };
  const results = Array.isArray(body.results) ? body.results : [];
  const hits = results
    .map((r: { url?: unknown; title?: unknown; content?: unknown }) => ({
      url: String(r.url ?? ""),
      title: String(r.title ?? ""),
      snippet: String(r.content ?? ""),
    }))
    .filter((hit) => hit.url.startsWith("http"))
    .slice(0, limit);
  const unresponsive = Array.isArray(body.unresponsive_engines) ? body.unresponsive_engines : [];
  const failedEngines = unresponsive.map((e) => (Array.isArray(e) ? `${e[0]} (${e[1]})` : String(e)));
  return { hits, failedEngines };
}

// One start attempt per call: if SearXNG is unreachable, start it and query once more.
export async function search(text: string, limit: number, options: SearchOptions): Promise<SearchResult> {
  let data: unknown;
  try {
    data = await query(options.baseUrl, text, options.signal);
  } catch (error) {
    if (!isUnreachable(error)) throw error;
    await options.start(options.signal);
    data = await query(options.baseUrl, text, options.signal);
  }
  return parseResults(data, limit);
}

export function formatResults(text: string, result: SearchResult): string {
  const lines = [
    "DISCOVERY: search results are leads, not evidence. Open a result with web_read before citing it.",
    `Query: ${text}`,
  ];
  if (result.failedEngines.length > 0) lines.push(`Engines that did not answer: ${result.failedEngines.join(", ")}`);
  if (result.hits.length === 0) lines.push("No results.");
  result.hits.forEach((hit, index) => {
    lines.push(`${index + 1}. ${hit.title || "(untitled)"}`, `   ${hit.url}`);
    const snippet = hit.snippet.replace(/\s+/g, " ").trim().slice(0, SNIPPET_CHARS);
    if (snippet) lines.push(`   ${snippet}`);
  });
  return lines.join("\n");
}

let starting: Promise<void> | undefined;

// Concurrent callers share one start; the script itself is idempotent.
export function startSearxng(signal?: AbortSignal): Promise<void> {
  starting ??= runScript(["start"], signal).finally(() => {
    starting = undefined;
  });
  return starting;
}

function runScript(args: string[], signal?: AbortSignal): Promise<void> {
  return new Promise((resolve, reject) => {
    const child = spawn("sh", [SCRIPT_PATH, ...args], { signal, timeout: START_TIMEOUT_MS, stdio: ["ignore", "ignore", "pipe"] });
    let stderr = "";
    child.stderr.on("data", (chunk: Buffer) => {
      stderr = (stderr + chunk.toString()).slice(-2000);
    });
    child.on("error", reject);
    child.on("close", (code, killedBy) => {
      if (code === 0) resolve();
      else reject(new Error(`searxng.sh ${args.join(" ")} failed (${killedBy ?? `exit ${code}`}): ${stderr.trim()}`));
    });
  });
}
