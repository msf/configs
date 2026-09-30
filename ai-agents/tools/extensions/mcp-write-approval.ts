import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Server annotations are untrusted; only known read operations bypass approval.
const LINEAR_READ_TOOLS = new Set([
  "list_issues", "get_issue", "list_comments", "list_projects", "get_project",
  "list_milestones", "list_teams", "get_user", "list_users", "list_initiatives",
  "get_initiative", "get_status_updates",
]);
const LINEAR_PREFIX = "mcp__linear__";

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (!event.toolName.startsWith(LINEAR_PREFIX)) return;
    if (LINEAR_READ_TOOLS.has(event.toolName.slice(LINEAR_PREFIX.length))) return;
    if (!ctx.hasUI) {
      return { block: true, reason: "Linear mutations require interactive approval." };
    }
    const approved = await ctx.ui.confirm(
      "Approve Linear mutation?",
      `${event.toolName}\n${JSON.stringify(event.input, null, 2)}`,
    );
    if (!approved) return { block: true, reason: "Linear mutation was not approved." };
  });
}
