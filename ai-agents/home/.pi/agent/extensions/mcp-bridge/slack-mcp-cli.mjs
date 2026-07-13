#!/usr/bin/env node
import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";

const home = process.env.HOME;
if (!home) throw new Error("HOME is not set");

const serverUrl = "https://mcp.slack.com/mcp";
const clientId = "1601185624273.8899143856786";
const serverName = "plugin:slack:slack";
const callbackPort = 3118;
const credentialsPath = resolve(home, ".claude/.credentials.json");
const serversPath = resolve(home, ".pi/agent/extensions/mcp-bridge/servers.json");

function usage() {
  console.error(`Usage:
  pi-slack-mcp tools [--all]
  pi-slack-mcp channels <query> [--limit N] [--format concise|detailed]
  pi-slack-mcp search <query> [--public] [--limit N] [--sort timestamp|score] [--sort-dir asc|desc] [--format concise|detailed] [--include-context]
  pi-slack-mcp read-channel <channel_id> [--limit N] [--oldest TS] [--latest TS] [--format concise|detailed]
  pi-slack-mcp read-thread <channel_id> <message_ts> [--limit N] [--format concise|detailed]
  pi-slack-mcp user [user_id] [--format concise|detailed]
  pi-slack-mcp call <tool_name> <json_args> [--allow-write]

Uses Claude Code's official Slack MCP OAuth cache. Never prints tokens.`);
  process.exit(2);
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function writeJson(path, data) {
  writeFileSync(path, JSON.stringify(data, null, 2), "utf8");
}

function slackConfig() {
  return readJson(serversPath).servers.slack ?? {};
}

function disabledToolRegexes() {
  return (slackConfig().disabledTools ?? []).map((pattern) => new RegExp(`^(?:${pattern})$`));
}

function isAllowedTool(name) {
  return !disabledToolRegexes().some((regex) => regex.test(name));
}

function findClaudeSlackEntry(store) {
  const hit = Object.entries(store.mcpOAuth ?? {}).find(([, entry]) => {
    return entry.serverName === serverName || entry.serverUrl === serverUrl;
  });
  if (!hit) {
    throw new Error("Claude Slack MCP OAuth credentials not found. Authenticate Slack in Claude Code first.");
  }
  return hit;
}

function readClaudeEntry() {
  const store = readJson(credentialsPath);
  const [key, entry] = findClaudeSlackEntry(store);
  return { store, key, entry };
}

function makeClaudeOAuthProvider() {
  const redirectUrl = new URL(`http://localhost:${callbackPort}/callback`);
  let codeVerifier = "";

  return {
    get redirectUrl() { return redirectUrl; },

    get clientMetadata() {
      return {
        redirect_uris: [redirectUrl],
        token_endpoint_auth_method: "none",
        grant_types: ["authorization_code", "refresh_token"],
        response_types: ["code"],
        client_name: "claude-code-slack-plugin",
      };
    },

    clientInformation() {
      return { client_id: clientId };
    },

    tokens() {
      const { entry } = readClaudeEntry();
      if (!entry.accessToken) return undefined;
      const tokens = {
        access_token: entry.accessToken,
        token_type: "Bearer",
      };
      if (entry.refreshToken) tokens.refresh_token = entry.refreshToken;
      if (entry.scope) tokens.scope = entry.scope;
      if (entry.expiresAt) {
        tokens.expires_in = Math.max(0, Math.floor((entry.expiresAt - Date.now()) / 1000));
      }
      return tokens;
    },

    saveTokens(tokens) {
      const { store, key, entry } = readClaudeEntry();
      entry.accessToken = tokens.access_token;
      if (tokens.refresh_token) entry.refreshToken = tokens.refresh_token;
      entry.expiresAt = tokens.expires_in ? Date.now() + tokens.expires_in * 1000 : undefined;
      entry.scope = tokens.scope ?? entry.scope ?? "";
      store.mcpOAuth[key] = entry;
      writeJson(credentialsPath, store);
    },

    discoveryState() {
      return readClaudeEntry().entry.discoveryState;
    },

    saveDiscoveryState(state) {
      const { store, key, entry } = readClaudeEntry();
      entry.discoveryState = state;
      store.mcpOAuth[key] = entry;
      writeJson(credentialsPath, store);
    },

    redirectToAuthorization() {
      throw new Error("Claude Slack MCP OAuth is missing or expired. Authenticate Slack in Claude Code, then retry.");
    },

    saveCodeVerifier(value) { codeVerifier = value; },
    codeVerifier() { return codeVerifier; },
  };
}

async function withClient(fn) {
  const client = new Client({ name: "pi-slack-mcp", version: "1.0.0" });
  const transport = new StreamableHTTPClientTransport(new URL(serverUrl), {
    authProvider: makeClaudeOAuthProvider(),
  });
  await client.connect(transport);
  try {
    return await fn(client);
  } finally {
    await client.close().catch(() => {});
  }
}

function parseOptions(argv) {
  const opts = {};
  const args = [];
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (!arg.startsWith("--")) {
      args.push(arg);
      continue;
    }

    const name = arg.slice(2);
    if (["all", "allow-write", "include-context", "include-bots", "public"].includes(name)) {
      opts[name] = true;
      continue;
    }

    if (i + 1 >= argv.length) usage();
    opts[name] = argv[++i];
  }
  return { opts, args };
}

function intOpt(opts, name, fallback) {
  if (opts[name] === undefined) return fallback;
  const value = Number.parseInt(opts[name], 10);
  if (!Number.isFinite(value)) throw new Error(`--${name} must be an integer`);
  return value;
}

function textResult(result) {
  return result.content?.map((item) => item.type === "text" ? item.text : JSON.stringify(item)).join("\n") ?? "";
}

async function callTool(client, name, args, opts = {}) {
  if (!opts["allow-write"] && !isAllowedTool(name)) {
    throw new Error(`Tool ${name} is disabled by ~/.pi/agent/extensions/mcp-bridge/servers.json. Pass --allow-write only for explicit write requests.`);
  }
  const result = await client.callTool({ name, arguments: args });
  process.stdout.write(textResult(result));
  if (!String(textResult(result)).endsWith("\n")) process.stdout.write("\n");
}

async function main() {
  const [cmd, ...rest] = process.argv.slice(2);
  if (!cmd || cmd === "help" || cmd === "--help") usage();
  const { opts, args } = parseOptions(rest);

  await withClient(async (client) => {
    if (cmd === "tools") {
      const { tools } = await client.listTools();
      for (const tool of tools.sort((a, b) => a.name.localeCompare(b.name))) {
        const allowed = isAllowedTool(tool.name);
        if (!opts.all && !allowed) continue;
        console.log(`${allowed ? "ok" : "disabled"}\t${tool.name}\t${tool.description?.split("\n")[0] ?? ""}`);
      }
      return;
    }

    if (cmd === "channels") {
      if (args.length < 1) usage();
      await callTool(client, "slack_search_channels", {
        query: args.join(" "),
        channel_types: opts.types ?? "public_channel,private_channel",
        limit: intOpt(opts, "limit", 20),
        response_format: opts.format ?? "concise",
        include_archived: Boolean(opts["include-archived"]),
      }, opts);
      return;
    }

    if (cmd === "search") {
      if (args.length < 1) usage();
      const tool = opts.public ? "slack_search_public" : "slack_search_public_and_private";
      const input = {
        query: args.join(" "),
        content_types: opts["content-types"] ?? "messages",
        limit: intOpt(opts, "limit", 10),
        sort: opts.sort ?? "timestamp",
        sort_dir: opts["sort-dir"] ?? "desc",
        response_format: opts.format ?? "detailed",
        include_context: Boolean(opts["include-context"]),
        include_bots: Boolean(opts["include-bots"]),
      };
      if (opts.after) input.after = opts.after;
      if (opts.before) input.before = opts.before;
      await callTool(client, tool, input, opts);
      return;
    }

    if (cmd === "read-channel") {
      if (args.length !== 1) usage();
      const input = {
        channel_id: args[0],
        limit: intOpt(opts, "limit", 20),
        response_format: opts.format ?? "detailed",
      };
      if (opts.oldest) input.oldest = opts.oldest;
      if (opts.latest) input.latest = opts.latest;
      await callTool(client, "slack_read_channel", input, opts);
      return;
    }

    if (cmd === "read-thread") {
      if (args.length !== 2) usage();
      await callTool(client, "slack_read_thread", {
        channel_id: args[0],
        message_ts: args[1],
        limit: intOpt(opts, "limit", 100),
        response_format: opts.format ?? "detailed",
      }, opts);
      return;
    }

    if (cmd === "user") {
      if (args.length > 1) usage();
      await callTool(client, "slack_read_user_profile", {
        user_id: args[0],
        response_format: opts.format ?? "concise",
      }, opts);
      return;
    }

    if (cmd === "call") {
      if (args.length !== 2) usage();
      await callTool(client, args[0], JSON.parse(args[1]), opts);
      return;
    }

    usage();
  });
}

main().catch((error) => {
  console.error(`pi-slack-mcp: ${error.message}`);
  process.exit(1);
});
