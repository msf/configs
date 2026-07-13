import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { SSEClientTransport } from "@modelcontextprotocol/sdk/client/sse.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";
import type { OAuthClientProvider } from "@modelcontextprotocol/sdk/client/auth.js";
import type { OAuthTokens, OAuthClientMetadata, OAuthClientInformationMixed } from "@modelcontextprotocol/sdk/shared/auth.js";
import { readFileSync, writeFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

// --- Config types ---

// enabledTools/disabledTools: arrays of regex patterns matched against the raw MCP
// tool name (without `${server}__` prefix). If enabledTools is omitted, all tools
// are eligible unless disabledTools filters them out.
// autoload: when true, connect/register on session start. Keep false for context economy.
// triggers: regex patterns matched against user input to lazy-load the server before the agent turn.
interface BaseServerConfig {
  enabled?: boolean;
  enabledTools?: string[];
  disabledTools?: string[];
  autoload?: boolean;
  triggers?: string[];
}

interface StdioServerConfig extends BaseServerConfig {
  type: "stdio";
  command: string;
  args?: string[];
  env?: Record<string, string | { file: string }>;
}

interface SseServerConfig extends BaseServerConfig {
  type: "sse";
  url: string;
  auth?: { source: "opencode"; server: string };
}

interface ClaudeAuthConfig {
  source: "claude";
  clientId: string;
  serverName?: string;
  serverUrl?: string;
  callbackPort?: number;
  credentialsPath?: string;
}

interface StreamableHttpServerConfig extends BaseServerConfig {
  type: "streamable_http";
  url: string;
  headers?: Record<string, string | { file: string }>;
  auth?:
    | { source: "bearer"; token: string | { file: string } }
    | { source: "opencode"; server: string }
    | ClaudeAuthConfig;
}

type ServerConfig = StdioServerConfig | SseServerConfig | StreamableHttpServerConfig;
interface Config { servers: Record<string, ServerConfig> }
interface NotifyContext { ui?: { notify(msg: string, level: string): void } }

// --- Claude Code OAuth store (camelCase) ---

interface ClaudeOAuthEntry {
  serverName: string;
  serverUrl: string;
  accessToken?: string;
  refreshToken?: string;
  expiresAt?: number;
  scope?: string;
  discoveryState?: unknown;
}

interface ClaudeCredentials {
  mcpOAuth?: Record<string, ClaudeOAuthEntry>;
}

function resolveHomePath(path: string): string {
  return path.replace(/^~/, process.env.HOME ?? "");
}

function readClaudeCredentials(path: string): ClaudeCredentials {
  return JSON.parse(readFileSync(path, "utf-8"));
}

function writeClaudeCredentials(path: string, data: ClaudeCredentials) {
  writeFileSync(path, JSON.stringify(data, null, 2), "utf-8");
}

function findClaudeOAuthEntry(
  store: ClaudeCredentials,
  auth: ClaudeAuthConfig,
): [string, ClaudeOAuthEntry] {
  const entries = Object.entries(store.mcpOAuth ?? {});
  const hit = entries.find(([, entry]) => {
    if (auth.serverName && entry.serverName === auth.serverName) return true;
    if (auth.serverUrl && entry.serverUrl === auth.serverUrl) return true;
    return false;
  });
  if (!hit) {
    throw new Error(
      `Claude MCP OAuth credentials not found for ${auth.serverName ?? auth.serverUrl ?? auth.clientId}`,
    );
  }
  return hit;
}

function makeClaudeOAuthProvider(auth: ClaudeAuthConfig): OAuthClientProvider {
  const credentialsPath = resolveHomePath(auth.credentialsPath ?? "~/.claude/.credentials.json");
  const redirectUrl = new URL(`http://localhost:${auth.callbackPort ?? 3118}/callback`);
  let _codeVerifier = "";

  function readEntry(): { store: ClaudeCredentials; key: string; entry: ClaudeOAuthEntry } {
    const store = readClaudeCredentials(credentialsPath);
    const [key, entry] = findClaudeOAuthEntry(store, auth);
    return { store, key, entry };
  }

  return {
    get redirectUrl() { return redirectUrl; },

    get clientMetadata(): OAuthClientMetadata {
      return {
        redirect_uris: [redirectUrl],
        token_endpoint_auth_method: "none",
        grant_types: ["authorization_code", "refresh_token"],
        response_types: ["code"],
        client_name: "claude-code-slack-plugin",
      };
    },

    clientInformation(): OAuthClientInformationMixed {
      return { client_id: auth.clientId };
    },

    tokens(): OAuthTokens | undefined {
      const { entry } = readEntry();
      if (!entry.accessToken) return undefined;
      const result: OAuthTokens = {
        access_token: entry.accessToken,
        token_type: "Bearer",
      };
      if (entry.refreshToken) result.refresh_token = entry.refreshToken;
      if (entry.scope) result.scope = entry.scope;
      if (entry.expiresAt) {
        result.expires_in = Math.max(0, Math.floor((entry.expiresAt - Date.now()) / 1000));
      }
      return result;
    },

    saveTokens(tokens: OAuthTokens) {
      const { store, key, entry } = readEntry();
      entry.accessToken = tokens.access_token;
      if (tokens.refresh_token) entry.refreshToken = tokens.refresh_token;
      entry.expiresAt = tokens.expires_in
        ? Date.now() + tokens.expires_in * 1000
        : undefined;
      entry.scope = tokens.scope ?? entry.scope ?? "";
      store.mcpOAuth = store.mcpOAuth ?? {};
      store.mcpOAuth[key] = entry;
      writeClaudeCredentials(credentialsPath, store);
    },

    discoveryState() {
      return readEntry().entry.discoveryState as any;
    },

    saveDiscoveryState(state: unknown) {
      const { store, key, entry } = readEntry();
      entry.discoveryState = state;
      store.mcpOAuth = store.mcpOAuth ?? {};
      store.mcpOAuth[key] = entry;
      writeClaudeCredentials(credentialsPath, store);
    },

    redirectToAuthorization(_url: URL) {
      throw new Error(
        "Claude Slack MCP OAuth is missing or expired. Authenticate Slack in Claude Code, then retry in pi.",
      );
    },

    saveCodeVerifier(v: string) { _codeVerifier = v; },
    codeVerifier() { return _codeVerifier; },
  };
}

// --- Opencode OAuth store (camelCase) ---

interface OpencodeAuthEntry {
  clientInfo: { clientId: string; clientIdIssuedAt?: number };
  serverUrl: string;
  tokens: {
    accessToken: string;
    refreshToken?: string;
    expiresAt?: number;
    scope?: string;
  };
}

const OPENCODE_AUTH_PATH = resolve(
  process.env.HOME ?? "",
  ".local/share/opencode/mcp-auth.json",
);

function readOpencodeAuth(): Record<string, OpencodeAuthEntry> {
  return JSON.parse(readFileSync(OPENCODE_AUTH_PATH, "utf-8"));
}

function writeOpencodeAuth(data: Record<string, OpencodeAuthEntry>) {
  writeFileSync(OPENCODE_AUTH_PATH, JSON.stringify(data, null, 4), "utf-8");
}

// --- OAuthClientProvider backed by opencode's mcp-auth.json ---

function makeOAuthProvider(serverKey: string): OAuthClientProvider {
  let _codeVerifier = "";

  return {
    get redirectUrl() { return new URL("http://localhost:0/callback"); },

    get clientMetadata(): OAuthClientMetadata {
      return {
        redirect_uris: [new URL("http://localhost:0/callback")],
        token_endpoint_auth_method: "none",
        grant_types: ["authorization_code", "refresh_token"],
        response_types: ["code"],
        client_name: "pi-mcp-bridge",
      };
    },

    clientInformation(): OAuthClientInformationMixed | undefined {
      try {
        const store = readOpencodeAuth();
        const entry = store[serverKey];
        if (!entry?.clientInfo) return undefined;
        return {
          client_id: entry.clientInfo.clientId,
          client_id_issued_at: entry.clientInfo.clientIdIssuedAt,
        };
      } catch {
        return undefined;
      }
    },

    saveClientInformation(info: OAuthClientInformationMixed) {
      const store = readOpencodeAuth();
      if (!store[serverKey]) return;
      store[serverKey].clientInfo = {
        clientId: info.client_id,
        clientIdIssuedAt: info.client_id_issued_at,
      };
      writeOpencodeAuth(store);
    },

    tokens(): OAuthTokens | undefined {
      try {
        const entry = readOpencodeAuth()[serverKey];
        if (!entry?.tokens?.accessToken) return undefined;
        const t = entry.tokens;
        const result: OAuthTokens = {
          access_token: t.accessToken,
          token_type: "Bearer",
        };
        if (t.refreshToken) result.refresh_token = t.refreshToken;
        if (t.scope) result.scope = t.scope;
        if (t.expiresAt) {
          const remaining = Math.max(0, Math.floor(t.expiresAt - Date.now() / 1000));
          result.expires_in = remaining;
        }
        return result;
      } catch {
        return undefined;
      }
    },

    saveTokens(tokens: OAuthTokens) {
      const store = readOpencodeAuth();
      if (!store[serverKey]) return;
      store[serverKey].tokens = {
        accessToken: tokens.access_token,
        refreshToken: tokens.refresh_token,
        expiresAt: tokens.expires_in
          ? Date.now() / 1000 + tokens.expires_in
          : undefined,
        scope: tokens.scope ?? "",
      };
      writeOpencodeAuth(store);
    },

    redirectToAuthorization(_url: URL) {
      throw new Error(
        `Linear OAuth session expired. Run opencode once to re-authenticate, then restart pi.`,
      );
    },

    saveCodeVerifier(v: string) { _codeVerifier = v; },
    codeVerifier() { return _codeVerifier; },
  };
}

// --- Helpers ---

function resolveEnvValue(val: string | { file: string }): string {
  if (typeof val === "string") {
    return val.startsWith("$") ? (process.env[val.slice(1)] ?? "") : val;
  }
  const p = resolveHomePath(val.file);
  return readFileSync(p, "utf-8").trim();
}

function buildEnv(extra?: Record<string, string | { file: string }>): Record<string, string> {
  const env: Record<string, string> = {};
  for (const [k, v] of Object.entries(process.env)) {
    if (v !== undefined) env[k] = v;
  }
  if (extra) {
    for (const [k, v] of Object.entries(extra)) env[k] = resolveEnvValue(v);
  }
  return env;
}

function buildHeaders(cfg: StreamableHttpServerConfig): Record<string, string> {
  const headers: Record<string, string> = {};
  for (const [k, v] of Object.entries(cfg.headers ?? {})) {
    headers[k] = resolveEnvValue(v);
  }
  if (cfg.auth?.source === "bearer") {
    const token = resolveEnvValue(cfg.auth.token);
    headers.Authorization = token.toLowerCase().startsWith("bearer ")
      ? token
      : `Bearer ${token}`;
  }
  return headers;
}

function notify(ctx: NotifyContext | undefined, message: string, level: string) {
  ctx?.ui?.notify(message, level);
}

function triggerMatches(cfg: ServerConfig, input: string): boolean {
  if (!cfg.triggers?.length) return false;
  return cfg.triggers.some((pattern) => new RegExp(pattern, "i").test(input));
}

// --- Extension ---

export default function (pi: ExtensionAPI) {
  const clients = new Map<string, Client>();
  const loading = new Map<string, Promise<number>>();

  const extDir =
    typeof __dirname !== "undefined"
      ? __dirname
      : dirname(fileURLToPath(import.meta.url));
  const configPath = resolve(extDir, "servers.json");

  function readConfig(): Config {
    return JSON.parse(readFileSync(configPath, "utf-8"));
  }

  async function connectServer(name: string, cfg: ServerConfig): Promise<number> {
    if (clients.has(name)) return 0;

    let transport;

    if (cfg.type === "stdio") {
      transport = new StdioClientTransport({
        command: cfg.command,
        args: cfg.args ?? [],
        env: buildEnv(cfg.env),
      });
    } else if (cfg.type === "sse") {
      const opts: ConstructorParameters<typeof SSEClientTransport>[1] = {};
      if (cfg.auth?.source === "opencode") {
        opts.authProvider = makeOAuthProvider(cfg.auth.server);
      }
      transport = new SSEClientTransport(new URL(cfg.url), opts);
    } else {
      const opts: ConstructorParameters<typeof StreamableHTTPClientTransport>[1] = {};
      if (cfg.auth?.source === "claude") {
        opts.authProvider = makeClaudeOAuthProvider(cfg.auth);
      } else if (cfg.auth?.source === "opencode") {
        opts.authProvider = makeOAuthProvider(cfg.auth.server);
      } else {
        opts.requestInit = { headers: buildHeaders(cfg) };
      }
      transport = new StreamableHTTPClientTransport(new URL(cfg.url), opts);
    }

    const client = new Client({ name: `pi-mcp-${name}`, version: "1.0.0" });
    await client.connect(transport);
    clients.set(name, client);

    const { tools } = await client.listTools();

    const allowFilters = cfg.enabledTools?.map((p) => new RegExp(`^(?:${p})$`));
    const denyFilters = cfg.disabledTools?.map((p) => new RegExp(`^(?:${p})$`));
    const isEnabled = (toolName: string) => {
      if (allowFilters && !allowFilters.some((re) => re.test(toolName))) return false;
      if (denyFilters?.some((re) => re.test(toolName))) return false;
      return true;
    };

    const registeredNames: string[] = [];
    for (const tool of tools) {
      if (!isEnabled(tool.name)) continue;
      const piToolName = `${name}__${tool.name}`;
      registeredNames.push(piToolName);
      pi.registerTool({
        name: piToolName,
        label: `[${name}] ${tool.name}`,
        description: tool.description ?? `MCP tool ${tool.name} from ${name}`,
        promptSnippet: `[${name}] ${tool.description ?? tool.name}`,
        parameters: Type.Unsafe(tool.inputSchema ?? { type: "object", properties: {} }),

        async execute(_toolCallId, params, signal) {
          const result = await client.callTool(
            { name: tool.name, arguments: params ?? {} },
            undefined,
            { signal },
          );

          const text =
            result.content
              ?.map((c: any) => (c.type === "text" ? c.text : JSON.stringify(c)))
              .join("\n") ?? "No output";

          if (result.isError) {
            throw new Error(text);
          }

          return {
            content: [{ type: "text", text }],
            details: { server: name, tool: tool.name },
          };
        },
      });
    }

    if (registeredNames.length > 0) {
      const active = new Set(pi.getActiveTools());
      for (const toolName of registeredNames) active.add(toolName);
      pi.setActiveTools([...active]);
    }

    return registeredNames.length;
  }

  async function loadServer(name: string, ctx?: NotifyContext): Promise<number> {
    const existing = loading.get(name);
    if (existing) return existing;

    const promise = (async () => {
      const config = readConfig();
      const cfg = config.servers[name];
      if (!cfg) throw new Error(`Unknown MCP server: ${name}`);
      if (cfg.enabled === false) return 0;
      return connectServer(name, cfg);
    })();

    loading.set(name, promise);
    try {
      return await promise;
    } catch (e: any) {
      notify(ctx, `MCP: ${name} failed: ${e.message}`, "error");
      throw e;
    } finally {
      loading.delete(name);
    }
  }

  async function loadAutoloadServers(ctx?: NotifyContext) {
    let config: Config;
    try {
      config = readConfig();
    } catch (e: any) {
      notify(ctx, `MCP bridge: config error: ${e.message}`, "error");
      return;
    }

    const results: string[] = [];
    for (const [name, cfg] of Object.entries(config.servers)) {
      if (cfg.enabled === false || cfg.autoload !== true) continue;
      try {
        const count = await loadServer(name, ctx);
        results.push(`${name}: ${count} tools`);
      } catch {
        results.push(`${name}: FAILED`);
      }
    }

    if (results.length > 0) notify(ctx, `MCP autoload: ${results.join(", ")}`, "info");
  }

  async function loadTriggeredServers(input: string, ctx?: NotifyContext) {
    let config: Config;
    try {
      config = readConfig();
    } catch (e: any) {
      notify(ctx, `MCP bridge: config error: ${e.message}`, "error");
      return;
    }

    const results: string[] = [];
    for (const [name, cfg] of Object.entries(config.servers)) {
      if (cfg.enabled === false || clients.has(name) || cfg.autoload === true) continue;
      try {
        if (!triggerMatches(cfg, input)) continue;
      } catch (e: any) {
        notify(ctx, `MCP: invalid trigger for ${name}: ${e.message}`, "error");
        continue;
      }

      try {
        const count = await loadServer(name, ctx);
        results.push(`${name}: ${count} tools`);
      } catch {
        results.push(`${name}: FAILED`);
      }
    }

    if (results.length > 0) notify(ctx, `MCP lazy-load: ${results.join(", ")}`, "info");
  }

  async function stopAll() {
    for (const [, client] of clients) {
      try { await client.close(); } catch {}
    }
    clients.clear();
    loading.clear();
  }

  pi.registerCommand("mcp-list", {
    description: "List configured MCP bridge servers and whether they are loaded",
    handler: async (_args, ctx) => {
      const config = readConfig();
      const lines = Object.entries(config.servers).map(([name, cfg]) => {
        const state = clients.has(name) ? "loaded" : cfg.enabled === false ? "disabled" : "idle";
        const mode = cfg.autoload === true ? "autoload" : cfg.triggers?.length ? "lazy" : "manual";
        const toolFilter = cfg.enabledTools?.length ? `${cfg.enabledTools.length} allow` : "all";
        const denyFilter = cfg.disabledTools?.length ? `, ${cfg.disabledTools.length} deny` : "";
        return `${name}\t${state}\t${mode}\t${toolFilter}${denyFilter} tools`;
      });
      ctx.ui.notify(lines.join("\n"), "info");
    },
  });

  pi.registerCommand("mcp-load", {
    description: "Lazy-load MCP bridge server(s): /mcp-load <server|all>",
    handler: async (args, ctx) => {
      const config = readConfig();
      const requested = args.trim();
      if (!requested) {
        ctx.ui.notify(`Usage: /mcp-load <${Object.keys(config.servers).join("|")}|all>`, "warning");
        return;
      }

      const names = requested === "all" ? Object.keys(config.servers) : requested.split(/[\s,]+/).filter(Boolean);
      const results: string[] = [];
      for (const name of names) {
        try {
          const count = await loadServer(name, ctx);
          results.push(`${name}: ${clients.has(name) ? "loaded" : "idle"} (${count} new tools)`);
        } catch (e: any) {
          results.push(`${name}: FAILED (${e.message})`);
        }
      }
      ctx.ui.notify(`MCP load: ${results.join(", ")}`, "info");
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    await stopAll();
    await loadAutoloadServers(ctx);
  });

  pi.on("input", async (event, ctx) => {
    if (event.source === "extension") return { action: "continue" as const };
    await loadTriggeredServers(event.text, ctx);
    return { action: "continue" as const };
  });

  pi.on("session_shutdown", async () => {
    await stopAll();
  });
}
