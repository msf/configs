import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, realpathSync } from "node:fs";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { homedir, tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { setTimeout as delay } from "node:timers/promises";
import { fileURLToPath, pathToFileURL } from "node:url";
import test from "node:test";

const toolsDir = dirname(fileURLToPath(import.meta.url));
function findPiPackage() {
  if (process.env.PI_PACKAGE_DIR) return process.env.PI_PACKAGE_DIR;
  let directory = dirname(realpathSync(execFileSync("which", ["pi"], { encoding: "utf8" }).trim()));
  for (let depth = 0; depth < 4; depth++, directory = dirname(directory)) {
    if (existsSync(join(directory, "dist/index.js"))) return directory;
  }
  throw new Error("Set PI_PACKAGE_DIR to the installed Pi package directory.");
}
const packageDir = findPiPackage();
const sdk = await import(pathToFileURL(join(packageDir, "dist/index.js")));
const { loadMcpConfig, getMcpToolExposure } = await import(pathToFileURL(join(packageDir, "dist/extensions/mcp/config.js")));

test("managed profiles have no extra Linear write approval extension", async () => {
  assert.doesNotMatch(await readFile(join(toolsDir, "manifest.txt"), "utf8"), /mcp-write-approval/);
  for (const profile of ["agent", "agent-lean"]) {
    assert.equal(existsSync(join(homedir(), ".pi", profile, "extensions/mcp-write-approval.ts")), false);
  }
});

test("private native configuration preserves allowlists and freezes unused integrations", async () => {
  const privateDir = process.env.PRIVATE_DIR ?? join(homedir(), "configs-private");
  const agentDir = join(privateDir, "home/.pi/agent");
  const loaded = loadMcpConfig({ agentDir, cwd: toolsDir, projectTrusted: false });
  assert.deepEqual(loaded.errors, []);
  assert.deepEqual(loaded.servers.map(server => server.name).sort(), ["grafana_dev", "grafana_prod", "linear", "slack"]);
  const configs = Object.fromEntries(loaded.servers.map(server => [server.name, server.config]));
  assert.notEqual(configs.grafana_prod.enabled, false);
  assert.notEqual(configs.linear.enabled, false);
  assert.equal(configs.grafana_dev.enabled, false);
  assert.equal(configs.slack.enabled, false);
  for (const config of Object.values(configs)) {
    assert.equal(config.exposure, "hidden");
    assert.equal(getMcpToolExposure(config, "new_unreviewed_tool"), "hidden");
    assert(Object.keys(config.toolExposure).every(name => !name.includes("*")));
    assert(Object.values(config.toolExposure).every(exposure => exposure === "codemode"));
  }
  assert.equal(Object.keys(configs.grafana_prod.toolExposure).length, 8);
  assert.deepEqual(configs.grafana_prod.toolExposure, configs.grafana_dev.toolExposure);
  assert.equal(Object.keys(configs.linear.toolExposure).length, 18);
  assert.equal(Object.keys(configs.slack.toolExposure).length, 8);
  assert.match(configs.grafana_prod.env.GRAFANA_SERVICE_ACCOUNT_TOKEN, /^!cat /);
  assert.equal(configs.linear.oauth.callbackUrl, "http://localhost:8765/callback");
  assert.equal(configs.slack.oauth.callbackUrl, "http://localhost:3118/callback");
});

async function createFixture(cwd, tools) {
  const settingsManager = sdk.SettingsManager.inMemory();
  const resourceLoader = new sdk.DefaultResourceLoader({
    cwd, agentDir: cwd, settingsManager,
    noExtensions: true, noSkills: true, noPromptTemplates: true, noThemes: true, noContextFiles: true,
    extensionFactories: [sdk.createCodemodeExtension({ models: false }), sdk.createMcpExtension({
      logPath: join(cwd, "mcp.log"),
      loadConfig: () => ({ errors: [], servers: [{
        name: "linear", source: join(cwd, "mcp.json"), scope: "global",
        config: { command: process.execPath, args: [join(toolsDir, "mcp-test-server.mjs"), join(cwd, "calls")], exposure: "hidden", toolExposure: { get_issue: "codemode", save_issue: "codemode" } },
      }] }),
    })],
  });
  await resourceLoader.reload();
  assert.deepEqual(resourceLoader.getExtensions().errors, []);
  const modelRuntime = await sdk.ModelRuntime.create({ authPath: join(cwd, "auth.json"), modelsPath: null, modelsStorePath: join(cwd, "models.json"), allowModelNetwork: false, refreshOnCreate: false });
  const { session } = await sdk.createAgentSession({ cwd, agentDir: cwd, settingsManager, resourceLoader, modelRuntime, tools, sessionManager: sdk.SessionManager.inMemory(cwd) });
  await session.bindExtensions({ mode: "print" });
  return session;
}

async function waitForConnection(session) {
  for (let attempt = 0; attempt < 100; attempt++) {
    if (session.getAllTools().some(tool => tool.name === "mcp__linear__save_issue")) return;
    await delay(25);
  }
  throw new Error("Synthetic native MCP server did not connect.");
}

async function executeCodemode(session, code) {
  const id = `test-${session.sessionManager.getBranch().length}`;
  const usage = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 } };
  session.sessionManager.appendMessage({ role: "assistant", content: [{ type: "toolCall", id, name: "codemode", arguments: { code } }], api: "openai-responses", provider: "openai", model: "synthetic", usage, stopReason: "toolUse", timestamp: Date.now() });
  session.refreshContext();
  const tool = session.state.tools.find(tool => tool.name === "codemode");
  assert(tool);
  const result = await tool.execute(id, { code: `// @options: {"timeout_ms": 5000, "max_output_tokens": 300}\n${code}` });
  return result.content.filter(block => block.type === "text").map(block => block.text).join("\n");
}

test("native MCP pagination, structured results, hidden tools, and writes without a second approval", { timeout: 15000 }, async () => {
  const cwd = await mkdtemp(join(tmpdir(), "pi-native-mcp-test-"));
  let session;
  try {
    session = await createFixture(cwd);
    await waitForConnection(session);
    assert(session.getActiveToolNames().includes("codemode"));
    assert(!session.getActiveToolNames().includes("mcp__linear__get_issue"));
    assert(!session.getCallableToolNames().includes("mcp__linear__delete_all"));
    assert(!session.getCallableToolNames().includes("read_mcp_resource"));
    const output = await executeCodemode(session, "const r = await tools.mcp__linear__get_issue({}); text({answer: r.structuredContent.answer, chars: r.content[0].text.length});");
    assert.match(output, /Script completed/);
    assert.match(output, /"answer":42/);
    assert.match(output, /"chars":22000/);
    session.sessionManager.appendMessage({ role: "user", content: "Save the synthetic test issue.", timestamp: Date.now() });
    const saved = await executeCodemode(session, "const r = await tools.mcp__linear__save_issue({}); text({answer: r.structuredContent.answer});");
    assert.match(saved, /Script completed/);
    assert.match(saved, /"answer":42/);
    assert.equal(await readFile(join(cwd, "calls"), "utf8"), "get_issue\nsave_issue\n");
    const hidden = await executeCodemode(session, "await tools.mcp__linear__delete_all({});");
    assert.match(hidden, /Script failed/);
    assert.equal(await readFile(join(cwd, "calls"), "utf8"), "get_issue\nsave_issue\n");
  } finally {
    if (session) {
      await session.extensionRunner.emit({ type: "session_shutdown" });
      session.dispose();
    }
    await rm(cwd, { recursive: true, force: true });
  }
});

test("explicit read-only subagent tool allowlist does not grow after native MCP connects", { timeout: 15000 }, async () => {
  const cwd = await mkdtemp(join(tmpdir(), "pi-native-mcp-restricted-"));
  let session;
  try {
    session = await createFixture(cwd, ["read"]);
    for (let attempt = 0; attempt < 100 && !existsSync(join(cwd, "calls.ready")); attempt++) await delay(25);
    assert(existsSync(join(cwd, "calls.ready")), "Restricted session's MCP server must complete tool discovery");
    await delay(25);
    assert.deepEqual(session.getActiveToolNames(), ["read"]);
    assert.deepEqual(session.getCallableToolNames(), ["read"]);
  } finally {
    if (session) {
      await session.extensionRunner.emit({ type: "session_shutdown" });
      session.dispose();
    }
    await rm(cwd, { recursive: true, force: true });
  }
});
