import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";
import { UnauthorizedError } from "@modelcontextprotocol/sdk/client/auth.js";
import type { OAuthClientProvider } from "@modelcontextprotocol/sdk/client/auth.js";
import type {
  OAuthClientInformationMixed,
  OAuthClientMetadata,
  OAuthDiscoveryState,
  OAuthTokens,
} from "@modelcontextprotocol/sdk/shared/auth.js";
import { randomUUID } from "node:crypto";
import { chmodSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { createServer } from "node:http";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

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

interface PiAuthConfig {
  source: "pi";
  server: string;
  callbackPort: number;
  clientId?: string;
}

interface StreamableHttpServerConfig extends BaseServerConfig {
  type: "streamable_http";
  url: string;
  headers?: Record<string, string | { file: string }>;
  auth?:
    | { source: "bearer"; token: string | { file: string } }
    | PiAuthConfig;
}

type ServerConfig = StdioServerConfig | StreamableHttpServerConfig;
interface Config { servers: Record<string, ServerConfig> }
interface NotifyContext { ui?: { notify(message: string, level: "info" | "warning" | "error"): void } }

interface StoredTokens {
  accessToken: string;
  refreshToken?: string;
  expiresAt?: number;
  scope?: string;
}

interface StoredOAuthEntry {
  serverUrl: string;
  clientInformation?: OAuthClientInformationMixed;
  tokens?: StoredTokens;
  discoveryState?: OAuthDiscoveryState;
}

interface OAuthStore {
  version: 1;
  servers: Record<string, StoredOAuthEntry>;
}

const HOME = process.env.HOME ?? "";
const AUTH_PATH = resolve(HOME, ".pi/agent/mcp-auth.json");

function resolveHomePath(path: string): string {
  return path.replace(/^~/, HOME);
}

function readAuthStore(): OAuthStore {
  try {
    return JSON.parse(readFileSync(AUTH_PATH, "utf8"));
  } catch (error: any) {
    if (error?.code === "ENOENT") return { version: 1, servers: {} };
    throw error;
  }
}

function writeAuthStore(store: OAuthStore) {
  mkdirSync(dirname(AUTH_PATH), { recursive: true });
  const temporary = `${AUTH_PATH}.tmp-${process.pid}`;
  writeFileSync(temporary, JSON.stringify(store, null, 2) + "\n", { mode: 0o600 });
  chmodSync(temporary, 0o600);
  renameSync(temporary, AUTH_PATH);
  chmodSync(AUTH_PATH, 0o600);
}

function readEntry(server: string, serverUrl: string): StoredOAuthEntry {
  return readAuthStore().servers[server] ?? { serverUrl };
}

function updateEntry(
  server: string,
  serverUrl: string,
  update: (entry: StoredOAuthEntry) => void,
) {
  const store = readAuthStore();
  const entry = store.servers[server] ?? { serverUrl };
  entry.serverUrl = serverUrl;
  update(entry);
  store.servers[server] = entry;
  writeAuthStore(store);
}

function makeOAuthProvider(
  auth: PiAuthConfig,
  serverUrl: string,
  onRedirect?: (url: URL) => void | Promise<void>,
  fresh = false,
): OAuthClientProvider {
  const redirectUrl = new URL(`http://localhost:${auth.callbackPort}/callback`);
  const oauthState = randomUUID();
  let codeVerifier = "";
  let stagedClientInformation: OAuthClientInformationMixed | undefined;
  let stagedDiscoveryState: OAuthDiscoveryState | undefined;

  return {
    get redirectUrl() { return redirectUrl; },

    get clientMetadata(): OAuthClientMetadata {
      return {
        redirect_uris: [redirectUrl],
        token_endpoint_auth_method: "none",
        grant_types: ["authorization_code", "refresh_token"],
        response_types: ["code"],
        client_name: `pi-mcp-${auth.server}`,
      };
    },

    state() { return oauthState; },

    clientInformation(): OAuthClientInformationMixed | undefined {
      if (fresh) return stagedClientInformation ?? (auth.clientId ? { client_id: auth.clientId } : undefined);
      return readEntry(auth.server, serverUrl).clientInformation
        ?? (auth.clientId ? { client_id: auth.clientId } : undefined);
    },

    saveClientInformation(info: OAuthClientInformationMixed) {
      if (fresh) {
        stagedClientInformation = info;
        return;
      }
      updateEntry(auth.server, serverUrl, (entry) => { entry.clientInformation = info; });
    },

    tokens(): OAuthTokens | undefined {
      if (fresh) return undefined;
      const stored = readEntry(auth.server, serverUrl).tokens;
      if (!stored?.accessToken) return undefined;
      const tokens: OAuthTokens = {
        access_token: stored.accessToken,
        token_type: "Bearer",
      };
      if (stored.refreshToken) tokens.refresh_token = stored.refreshToken;
      if (stored.scope) tokens.scope = stored.scope;
      if (stored.expiresAt) {
        tokens.expires_in = Math.max(0, Math.floor((stored.expiresAt - Date.now()) / 1000));
      }
      return tokens;
    },

    saveTokens(tokens: OAuthTokens) {
      updateEntry(auth.server, serverUrl, (entry) => {
        const previous = entry.tokens;
        if (fresh) {
          entry.clientInformation = stagedClientInformation
            ?? (auth.clientId ? { client_id: auth.clientId } : entry.clientInformation);
          entry.discoveryState = stagedDiscoveryState;
        }
        entry.tokens = {
          accessToken: tokens.access_token,
          refreshToken: tokens.refresh_token ?? (fresh ? undefined : previous?.refreshToken),
          expiresAt: tokens.expires_in ? Date.now() + tokens.expires_in * 1000 : undefined,
          scope: tokens.scope ?? (fresh ? undefined : previous?.scope),
        };
      });
    },

    discoveryState() {
      return fresh ? stagedDiscoveryState : readEntry(auth.server, serverUrl).discoveryState;
    },

    saveDiscoveryState(state: OAuthDiscoveryState) {
      if (fresh) {
        stagedDiscoveryState = state;
        return;
      }
      updateEntry(auth.server, serverUrl, (entry) => { entry.discoveryState = state; });
    },

    async redirectToAuthorization(url: URL) {
      if (!onRedirect) {
        throw new Error(`OAuth required for ${auth.server}. Run /mcp-login ${auth.server}.`);
      }
      await onRedirect(url);
    },

    saveCodeVerifier(value: string) { codeVerifier = value; },
    codeVerifier() {
      if (!codeVerifier) throw new Error("OAuth code verifier is missing");
      return codeVerifier;
    },
  };
}

function resolveSecret(value: string | { file: string }): string {
  if (typeof value === "string") {
    return value.startsWith("$") ? (process.env[value.slice(1)] ?? "") : value;
  }
  return readFileSync(resolveHomePath(value.file), "utf8").trim();
}

function buildEnv(extra?: Record<string, string | { file: string }>): Record<string, string> {
  const env = Object.fromEntries(
    Object.entries(process.env).filter((entry): entry is [string, string] => entry[1] !== undefined),
  );
  for (const [key, value] of Object.entries(extra ?? {})) env[key] = resolveSecret(value);
  return env;
}

function buildHeaders(config: StreamableHttpServerConfig): Record<string, string> {
  const headers: Record<string, string> = {};
  for (const [key, value] of Object.entries(config.headers ?? {})) {
    headers[key] = resolveSecret(value);
  }
  if (config.auth?.source === "bearer") {
    const token = resolveSecret(config.auth.token);
    headers.Authorization = token.toLowerCase().startsWith("bearer ") ? token : `Bearer ${token}`;
  }
  return headers;
}

function triggerMatches(config: ServerConfig, input: string): boolean {
  return config.triggers?.some((pattern) => new RegExp(pattern, "i").test(input)) ?? false;
}

async function startCallbackServer(port: number, expectedState: string) {
  let resolveCode!: (code: string) => void;
  let rejectCode!: (error: Error) => void;
  const code = new Promise<string>((resolve, reject) => {
    resolveCode = resolve;
    rejectCode = reject;
  });

  const server = createServer((request, response) => {
    const url = new URL(request.url ?? "/", `http://127.0.0.1:${port}`);
    const oauthError = url.searchParams.get("error");
    const receivedState = url.searchParams.get("state");
    const authorizationCode = url.searchParams.get("code");

    if (url.pathname !== "/callback" || oauthError || !authorizationCode || receivedState !== expectedState) {
      response.writeHead(400, { "content-type": "text/plain" });
      response.end("OAuth failed. Return to Pi for details.\n");
      rejectCode(new Error(oauthError ?? "invalid OAuth callback"));
      return;
    }

    response.writeHead(200, { "content-type": "text/plain" });
    response.end("OAuth complete. You can close this tab.\n");
    resolveCode(authorizationCode);
  });

  await new Promise<void>((resolveListen, rejectListen) => {
    server.once("error", rejectListen);
    server.listen(port, "127.0.0.1", resolveListen);
  });

  const timeout = setTimeout(() => rejectCode(new Error("OAuth callback timed out")), 180_000);
  return {
    code,
    close: () => {
      clearTimeout(timeout);
      server.close();
    },
  };
}

export default function (pi: ExtensionAPI) {
  const clients = new Map<string, Client>();
  const loading = new Map<string, Promise<number>>();
  const extensionDir = typeof __dirname !== "undefined" ? __dirname : dirname(fileURLToPath(import.meta.url));
  const configPath = resolve(extensionDir, "servers.json");

  function readConfig(): Config {
    try {
      return JSON.parse(readFileSync(configPath, "utf8"));
    } catch (error: any) {
      if (error?.code === "ENOENT") return { servers: {} };
      throw error;
    }
  }

  async function connectServer(name: string, config: ServerConfig): Promise<number> {
    if (clients.has(name)) return 0;

    const transport = config.type === "stdio"
      ? new StdioClientTransport({
          command: config.command,
          args: config.args ?? [],
          env: buildEnv(config.env),
        })
      : new StreamableHTTPClientTransport(new URL(config.url), config.auth?.source === "pi"
          ? { authProvider: makeOAuthProvider(config.auth, config.url) }
          : { requestInit: { headers: buildHeaders(config) } });

    const client = new Client({ name: `pi-mcp-${name}`, version: "1.0.0" });
    await client.connect(transport);
    clients.set(name, client);

    const { tools } = await client.listTools();
    const allow = config.enabledTools?.map((pattern) => new RegExp(`^(?:${pattern})$`));
    const deny = config.disabledTools?.map((pattern) => new RegExp(`^(?:${pattern})$`));
    const registered: string[] = [];

    for (const tool of tools) {
      if (allow && !allow.some((pattern) => pattern.test(tool.name))) continue;
      if (deny?.some((pattern) => pattern.test(tool.name))) continue;

      const toolName = `${name}__${tool.name}`;
      registered.push(toolName);
      pi.registerTool({
        name: toolName,
        label: `[${name}] ${tool.name}`,
        description: tool.description ?? `MCP tool ${tool.name} from ${name}`,
        parameters: Type.Unsafe(tool.inputSchema ?? { type: "object", properties: {} }),
        async execute(_toolCallId, params, signal) {
          const result = await client.callTool(
            { name: tool.name, arguments: params ?? {} },
            undefined,
            { signal },
          );
          const text = result.content
            ?.map((item: any) => item.type === "text" ? item.text : JSON.stringify(item))
            .join("\n") ?? "No output";
          if (result.isError) throw new Error(text);
          return {
            content: [{ type: "text" as const, text }],
            details: { server: name, tool: tool.name },
          };
        },
      });
    }

    if (registered.length) {
      pi.setActiveTools([...new Set([...pi.getActiveTools(), ...registered])]);
    }
    return registered.length;
  }

  async function loadServer(name: string): Promise<number> {
    const inFlight = loading.get(name);
    if (inFlight) return inFlight;
    const promise = (async () => {
      const config = readConfig().servers[name];
      if (!config) throw new Error(`Unknown MCP server: ${name}`);
      if (config.enabled === false) return 0;
      return connectServer(name, config);
    })();
    loading.set(name, promise);
    try {
      return await promise;
    } finally {
      loading.delete(name);
    }
  }

  async function stopServer(name: string) {
    const client = clients.get(name);
    if (client) await client.close().catch(() => {});
    clients.delete(name);
    loading.delete(name);
  }

  async function loginServer(name: string, context: any) {
    const config = readConfig().servers[name];
    if (!config || config.type !== "streamable_http" || config.auth?.source !== "pi") {
      throw new Error(`${name} is not configured for Pi OAuth`);
    }

    await stopServer(name);
    const state = randomUUID();
    const callback = await startCallbackServer(config.auth.callbackPort, state);
    const provider = makeOAuthProvider(config.auth, config.url, async (url) => {
      url.searchParams.set("state", state);
      const opened = await pi.exec("xdg-open", [url.toString()]);
      if (opened.code !== 0) context.ui.notify(`Open this OAuth URL manually: ${url}`, "warning");
    }, true);
    const client = new Client({ name: `pi-mcp-login-${name}`, version: "1.0.0" });
    const transport = new StreamableHTTPClientTransport(new URL(config.url), { authProvider: provider });

    try {
      try {
        await client.connect(transport);
      } catch (error) {
        if (!(error instanceof UnauthorizedError)) throw error;
        const code = await callback.code;
        await transport.finishAuth(code);
      }
    } finally {
      callback.close();
      await client.close().catch(() => {});
    }

    return loadServer(name);
  }

  async function stopAll() {
    await Promise.all([...clients.keys()].map(stopServer));
  }

  pi.registerCommand("mcp-list", {
    description: "List Pi MCP bridge servers and load state",
    handler: async (_args, context) => {
      const lines = Object.entries(readConfig().servers).map(([name, config]) => {
        const state = clients.has(name) ? "loaded" : config.enabled === false ? "disabled" : "idle";
        const mode = config.autoload ? "autoload" : config.triggers?.length ? "lazy" : "manual";
        return `${name}\t${state}\t${mode}`;
      });
      context.ui.notify(lines.join("\n"), "info");
    },
  });

  pi.registerCommand("mcp-load", {
    description: "Load Pi MCP server(s): /mcp-load <server|all>",
    handler: async (args, context) => {
      const config = readConfig();
      const requested = args.trim();
      if (!requested) {
        context.ui.notify(`Usage: /mcp-load <${Object.keys(config.servers).join("|")}|all>`, "warning");
        return;
      }
      const names = requested === "all" ? Object.keys(config.servers) : requested.split(/[\s,]+/).filter(Boolean);
      const results = [];
      for (const name of names) {
        try {
          results.push(`${name}: ${await loadServer(name)} tools`);
        } catch (error: any) {
          results.push(`${name}: FAILED (${error.message})`);
        }
      }
      context.ui.notify(results.join(", "), "info");
    },
  });

  pi.registerCommand("mcp-login", {
    description: "Authenticate a Pi MCP server: /mcp-login <server>",
    handler: async (args, context) => {
      const name = args.trim();
      if (!name) {
        context.ui.notify("Usage: /mcp-login <server>", "warning");
        return;
      }
      if (!context.hasUI) {
        throw new Error("MCP OAuth login requires interactive Pi");
      }
      context.ui.notify(`Starting ${name} OAuth in your browser`, "info");
      const count = await loginServer(name, context);
      context.ui.notify(`${name} authenticated; ${count} tools loaded`, "info");
    },
  });

  pi.on("session_start", async (_event, context) => {
    await stopAll();
    for (const [name, config] of Object.entries(readConfig().servers)) {
      if (!config.autoload || config.enabled === false) continue;
      try {
        await loadServer(name);
      } catch (error: any) {
        context.ui.notify(`MCP ${name} failed: ${error.message}`, "error");
      }
    }
  });

  pi.on("input", async (event, context) => {
    if (event.source === "extension") return { action: "continue" as const };
    for (const [name, config] of Object.entries(readConfig().servers)) {
      if (config.enabled === false || config.autoload || clients.has(name)) continue;
      try {
        if (triggerMatches(config, event.text)) await loadServer(name);
      } catch (error: any) {
        context.ui.notify(`MCP ${name} failed: ${error.message}`, "error");
      }
    }
    return { action: "continue" as const };
  });

  pi.on("session_shutdown", stopAll);
}
