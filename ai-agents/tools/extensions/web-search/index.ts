import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { formatResults, SCRIPT_PATH, search, searxngUrl, startSearxng } from "./search.ts";

const DEFAULT_LIMIT = 8;
const MAX_LIMIT = 10;

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "web_search",
    label: "Web Search",
    description:
      "Search the web through a local SearXNG instance and return ranked results (title, URL, snippet). When the user asks you to search (\"search online\", \"search the web\", \"look it up online\"), call this tool first, even if you already know a likely URL. Results are DISCOVERY, not evidence: open a result with web_read before citing it.",
    promptSnippet: "Search the web for candidate URLs.",
    promptGuidelines: [
      "When the user asks to search the web or online, call web_search first, even if you know a likely URL. Otherwise use it only when you don't know the authoritative URL; if the task names a site, API, or repository, go there directly.",
      "Search results are leads, not evidence: open a result with web_read before citing it.",
    ],
    parameters: Type.Object({
      query: Type.String({ description: "Search query" }),
      limit: Type.Optional(
        Type.Integer({ description: `Maximum results (default ${DEFAULT_LIMIT})`, minimum: 1, maximum: MAX_LIMIT }),
      ),
    }),
    async execute(_toolCallId, params, signal, onUpdate) {
      const text = params.query.trim();
      if (!text) throw new Error("web_search: the query is empty");
      const start = (startSignal?: AbortSignal) => {
        onUpdate?.({ content: [{ type: "text", text: "SearXNG is not running; starting it..." }], details: undefined });
        return startSearxng(startSignal);
      };
      let result;
      try {
        result = await search(text, params.limit ?? DEFAULT_LIMIT, { baseUrl: searxngUrl(), start, signal });
      } catch (error) {
        const reason = (error as Error)?.message ?? String(error);
        throw new Error(`web_search failed: ${reason}\nStart SearXNG by hand with: sh ${SCRIPT_PATH} start`);
      }
      if (result.hits.length === 0 && result.failedEngines.length > 0) {
        throw new Error(
          `web_search: no search engine answered (${result.failedEngines.join(", ")}). Retry later, or open a known official URL with web_read.`,
        );
      }
      return {
        content: [{ type: "text", text: formatResults(text, result) }],
        details: { count: result.hits.length, urls: result.hits.map((hit) => hit.url), failedEngines: result.failedEngines },
      };
    },
  });
}
