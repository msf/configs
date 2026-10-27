import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const stateKey = "openai-fast-mode";

function supportsPriority(ctx: ExtensionContext): boolean {
	const model = ctx.model;
	return model !== undefined &&
		(model.provider === "openai" || model.provider === "openai-codex") &&
		["openai-responses", "openai-codex-responses", "openai-completions"].includes(model.api);
}

export default function fastMode(pi: ExtensionAPI) {
	let enabled = false;

	function updateStatus(ctx: ExtensionContext) {
		ctx.ui.setStatus(stateKey, enabled ? (supportsPriority(ctx) ? "fast: priority" : "fast: paused") : undefined);
	}

	function restoreState(_event: unknown, ctx: ExtensionContext) {
		enabled = false;
		for (const entry of ctx.sessionManager.getBranch()) {
			if (entry.type === "custom" && entry.customType === stateKey && typeof entry.data === "boolean") {
				enabled = entry.data;
			}
		}
		updateStatus(ctx);
	}

	pi.on("session_start", restoreState);
	pi.on("session_tree", restoreState);
	pi.on("model_select", (_event, ctx) => updateStatus(ctx));

	pi.on("before_provider_request", (event, ctx) => {
		if (!enabled || !supportsPriority(ctx)) return;
		if (typeof event.payload !== "object" || event.payload === null || Array.isArray(event.payload)) return;
		return { ...event.payload, service_tier: "priority" };
	});

	pi.registerCommand("fast", {
		description: "Toggle OpenAI priority service (higher usage/cost): /fast [on|off|status]",
		handler: async (args, ctx) => {
			const action = args.trim().toLowerCase();
			if (!["", "on", "off", "status"].includes(action)) {
				ctx.ui.notify("Usage: /fast [on|off|status]", "error");
				return;
			}
			if (action === "status") {
				ctx.ui.notify(`Fast mode: ${enabled ? "on (priority requested)" : "off"}${supportsPriority(ctx) ? "" : "; current model unsupported"}.`, "info");
				return;
			}
			const nextEnabled = action === "" ? !enabled : action === "on";
			if (nextEnabled && !supportsPriority(ctx)) {
				ctx.ui.notify("Fast mode requires an OpenAI or ChatGPT/Codex model.", "error");
				return;
			}
			pi.appendEntry(stateKey, nextEnabled);
			enabled = nextEnabled;
			updateStatus(ctx);
			ctx.ui.notify(enabled
				? "Fast mode on: requesting priority service. Higher usage/cost may apply; reasoning unchanged."
				: "Fast mode off: using the provider's normal service tier.", "info");
		},
	});
}
