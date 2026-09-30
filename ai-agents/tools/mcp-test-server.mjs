import { appendFileSync, writeFileSync } from "node:fs";
import { createInterface } from "node:readline";

const callLog = process.argv[2];
const tool = (name) => ({
  name,
  description: `Synthetic ${name}`,
  inputSchema: { type: "object", properties: {} },
  annotations: { readOnlyHint: true },
});

for await (const line of createInterface({ input: process.stdin })) {
  const request = JSON.parse(line);
  if (request.id === undefined) continue;
  let result;
  switch (request.method) {
    case "initialize":
      result = {
        protocolVersion: request.params.protocolVersion,
        capabilities: { tools: {}, resources: {} },
        serverInfo: { name: "native-mcp-test", version: "1.0.0" },
      };
      break;
    case "tools/list":
      result = request.params?.cursor
        ? { tools: [tool("save_issue"), tool("delete_all")] }
        : { tools: [tool("get_issue")], nextCursor: "second-page" };
      if (request.params?.cursor) writeFileSync(`${callLog}.ready`, "ready\n");
      break;
    case "tools/call":
      appendFileSync(callLog, `${request.params.name}\n`);
      result = {
        content: [{ type: "text", text: "x".repeat(22000) }],
        structuredContent: { answer: 42 },
      };
      break;
    case "resources/list":
      result = { resources: [] };
      break;
    default:
      process.stdout.write(`${JSON.stringify({ jsonrpc: "2.0", id: request.id, error: { code: -32601, message: "Unsupported test method" } })}\n`);
      continue;
  }
  process.stdout.write(`${JSON.stringify({ jsonrpc: "2.0", id: request.id, result })}\n`);
}
