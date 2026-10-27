import assert from "node:assert/strict";
import test from "node:test";
import fastMode from "./index.ts";

function harness(provider = "openai-codex", api = "openai-codex-responses") {
	const handlers = new Map();
	const commands = new Map();
	const entries = [];
	const notifications = [];
	const statuses = new Map();
	const ctx = {
		model: { provider, api },
		sessionManager: { getBranch: () => entries },
		ui: {
			notify: (...args) => notifications.push(args),
			setStatus: (key, value) => statuses.set(key, value),
		},
	};
	fastMode({
		on: (event, handler) => handlers.set(event, handler),
		registerCommand: (name, command) => commands.set(name, command),
		appendEntry: (customType, data) => entries.push({ type: "custom", customType, data }),
	});
	return {
		ctx, entries, notifications, statuses,
		command: (args = "") => commands.get("fast").handler(args, ctx),
		emit: (event, data = {}) => handlers.get(event)({ type: event, ...data }, ctx),
	};
}

for (const [provider, api] of [
	["openai-codex", "openai-codex-responses"],
	["openai", "openai-responses"],
	["openai", "openai-completions"],
]) {
	test(`${provider}/${api}: toggle changes only the service tier`, async () => {
		const h = harness(provider, api);
		const payload = { model: "test", reasoning: { effort: "high" }, service_tier: "flex" };
		assert.equal(h.emit("before_provider_request", { payload }), undefined);
		await h.command();
		assert.deepEqual(h.emit("before_provider_request", { payload }), { ...payload, service_tier: "priority" });
		assert.equal(payload.service_tier, "flex");
		assert.equal(h.statuses.get("openai-fast-mode"), "fast: priority");
		await h.command();
		assert.equal(h.emit("before_provider_request", { payload }), undefined);
		assert.equal(h.statuses.get("openai-fast-mode"), undefined);
	});
}

test("explicit controls, status, and invalid input", async () => {
	const h = harness();
	await h.command("on");
	await h.command("on");
	await h.command("status");
	assert.equal(h.entries.length, 2);
	assert.match(h.notifications.at(-1)[0], /on \(priority requested\)/);
	await h.command("bad");
	assert.equal(h.notifications.at(-1)[1], "error");
	assert.equal(h.entries.length, 2);
	await h.command(" OFF ");
	assert.equal(h.entries.at(-1).data, false);
});

test("unsupported providers and APIs never receive priority", async () => {
	for (const [provider, api] of [["anthropic", "anthropic-messages"], ["proxy", "openai-responses"], ["openai", "unknown"]]) {
		const h = harness(provider, api);
		await h.command("on");
		assert.equal(h.entries.length, 0);
		assert.equal(h.notifications.at(-1)[1], "error");
		assert.equal(h.emit("before_provider_request", { payload: {} }), undefined);
	}
	const h = harness();
	h.ctx.model = undefined;
	await h.command("on");
	assert.equal(h.entries.length, 0);
});

test("switching models pauses priority and allows disabling", async () => {
	const h = harness();
	await h.command("on");
	h.ctx.model = { provider: "anthropic", api: "anthropic-messages" };
	h.emit("model_select");
	assert.equal(h.statuses.get("openai-fast-mode"), "fast: paused");
	assert.equal(h.emit("before_provider_request", { payload: {} }), undefined);
	await h.command("off");
	assert.equal(h.entries.at(-1).data, false);
});

test("reload, resume, new sessions, and tree navigation restore branch-local state", async () => {
	const h = harness();
	await h.command("on");
	const restored = harness();
	restored.entries.push(...h.entries);
	restored.emit("session_start");
	assert.deepEqual(restored.emit("before_provider_request", { payload: {} }), { service_tier: "priority" });
	restored.entries.push({ type: "custom", customType: "other", data: false });
	restored.emit("session_start");
	assert.deepEqual(restored.emit("before_provider_request", { payload: {} }), { service_tier: "priority" });
	restored.entries.push({ type: "custom", customType: "openai-fast-mode", data: false });
	restored.emit("session_tree");
	assert.equal(restored.emit("before_provider_request", { payload: {} }), undefined);
	restored.entries.length = 0;
	restored.emit("session_start");
	assert.equal(restored.emit("before_provider_request", { payload: {} }), undefined);
});

test("non-object payloads are not rewritten", async () => {
	const h = harness();
	await h.command("on");
	for (const payload of [null, undefined, "text", [], 1]) {
		assert.equal(h.emit("before_provider_request", { payload }), undefined);
	}
});
