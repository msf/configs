/**
 * context-meter: replace pi's default footer with one that keeps all the
 * stats but renders the context segment with a high-contrast, model-relative
 * meter and surfaces the system-prompt baseline (`sys Xk`).
 *
 * Layout matches the default footer:
 *
 *   <cwd> (<branch>) [• <session-name>]
 *   ↑118k ↓7.3k R219k $0.918 [28k/272k 9%] sys 7.4k     <model> • <thinking>
 *   <extension statuses...>
 *
 * Color tiers are computed against the *active* model's context window,
 * so 60k tokens looks calm on Opus-1M and red on a 128k local model.
 */

import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

// Read `compaction.enabled` from pi settings. Project-local overrides global.
// Default true (matches pi's own default).
function readAutoCompactEnabled(cwd: string): boolean {
	const paths = [
		join(cwd, ".pi", "settings.json"),
		join(homedir(), ".pi", "agent", "settings.json"),
	];
	for (const p of paths) {
		try {
			const raw = readFileSync(p, "utf8");
			const v = JSON.parse(raw)?.compaction?.enabled;
			if (typeof v === "boolean") return v;
		} catch {
			// missing or unreadable file: try next
		}
	}
	return true;
}

// ---------- ANSI helpers ----------
const RESET = "\x1b[0m";
const sgr = (codes: string, s: string) => `\x1b[${codes}m${s}${RESET}`;

type TierStyle = (s: string) => string;

function tierFor(percent: number): TierStyle {
	if (percent < 50) return (s) => sgr("32", s); // green fg — ok
	if (percent < 70) return (s) => sgr("1;93", s); // bright yellow fg — notice
	if (percent < 85) return (s) => sgr("30;103", s); // black on bright-yellow bg — warn
	if (percent < 100) return (s) => sgr("1;97;41", s); // white on red bg — danger
	return (s) => sgr("1;5;97;41", s); // blink + white on red — overflow
}

// ---------- formatting (matches pi's footer style) ----------
function fmtTokens(count: number): string {
	if (count < 1000) return String(count);
	if (count < 10_000) return `${(count / 1000).toFixed(1)}k`;
	if (count < 1_000_000) return `${Math.round(count / 1000)}k`;
	if (count < 10_000_000) return `${(count / 1_000_000).toFixed(1)}M`;
	return `${Math.round(count / 1_000_000)}M`;
}

function sanitizeStatusText(text: string): string {
	return text.replace(/[\r\n\t]/g, " ").replace(/ +/g, " ").trim();
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_event, ctx) => {
		const autoCompact = readAutoCompactEnabled(ctx.cwd);
		ctx.ui.setFooter((tui, theme, footerData) => {
			const unsubBranch = footerData.onBranchChange(() => tui.requestRender());

			return {
				dispose: unsubBranch,
				invalidate() {},
				render(width: number): string[] {
					// ----- Cumulative usage across the whole session -----
					let totalInput = 0;
					let totalOutput = 0;
					let totalCacheRead = 0;
					let totalCacheWrite = 0;
					let totalCost = 0;
					for (const entry of ctx.sessionManager.getEntries()) {
						if (entry.type === "message" && entry.message.role === "assistant") {
							const u = entry.message.usage;
							totalInput += u.input;
							totalOutput += u.output;
							totalCacheRead += u.cacheRead;
							totalCacheWrite += u.cacheWrite;
							totalCost += u.cost.total;
						}
					}

					// ----- Context + system-prompt baseline -----
					const usage = ctx.getContextUsage();
					const contextWindow =
						usage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
					const sysTokens = Math.ceil(ctx.getSystemPrompt().length / 4);
					const sysPct = contextWindow > 0 ? (sysTokens / contextWindow) * 100 : 0;

					// Context meter — colorized block
					let ctxSeg: string;
					if (!usage) {
						ctxSeg = sgr("90", "[ctx —]");
					} else if (usage.tokens === null || usage.percent === null) {
						// Right after compaction, before next response.
						ctxSeg = sgr("90", `[ctx —/${fmtTokens(usage.contextWindow)}]`);
					} else {
						const inner = ` ${fmtTokens(usage.tokens)}/${fmtTokens(usage.contextWindow)} ${usage.percent.toFixed(0)}% `;
						ctxSeg = tierFor(usage.percent)(inner);
					}

					// System-prompt baseline — only escalate above 10% of window.
					const sysStyle: TierStyle =
						sysPct < 10 ? (s) => sgr("90", s) : tierFor(sysPct);
					const sysSeg = sysStyle(`sys ${fmtTokens(sysTokens)}`);

					// ----- pwd / branch / session line -----
					let pwd = ctx.sessionManager.getCwd();
					const home = process.env.HOME || process.env.USERPROFILE;
					if (home && pwd.startsWith(home)) pwd = `~${pwd.slice(home.length)}`;
					const branch = footerData.getGitBranch();
					if (branch) pwd = `${pwd} (${branch})`;
					const sessionName = pi.getSessionName();
					if (sessionName) pwd = `${pwd} • ${sessionName}`;

					// ----- Stats line: assemble parts -----
					const statsParts: string[] = [];
					if (totalInput) statsParts.push(`↑${fmtTokens(totalInput)}`);
					if (totalOutput) statsParts.push(`↓${fmtTokens(totalOutput)}`);
					if (totalCacheRead) statsParts.push(`R${fmtTokens(totalCacheRead)}`);
					if (totalCacheWrite) statsParts.push(`W${fmtTokens(totalCacheWrite)}`);
					const usingSub = ctx.model
						? ctx.modelRegistry.isUsingOAuth(ctx.model)
						: false;
					if (totalCost || usingSub) {
						statsParts.push(
							`$${totalCost.toFixed(3)}${usingSub ? " (sub)" : ""}`,
						);
					}
					statsParts.push(ctxSeg);
					statsParts.push(sysSeg);
					if (autoCompact) statsParts.push("(auto-compaction)");

					// Wrap non-colored parts in dim. Colored parts (ctxSeg, sysSeg) carry
					// their own SGR + reset, so we apply dim per-segment to avoid the
					// reset clobbering an outer dim wrapper.
					const dimPlain = (s: string) => theme.fg("dim", s);
					const coloredSet = new Set([ctxSeg, sysSeg]);
					const statsLeft = statsParts
						.map((p) => (coloredSet.has(p) ? p : dimPlain(p)))
						.join(dimPlain(" "));
					let statsLeftWidth = visibleWidth(statsLeft);
					let statsLeftRendered = statsLeft;
					if (statsLeftWidth > width) {
						statsLeftRendered = truncateToWidth(statsLeft, width, "...");
						statsLeftWidth = visibleWidth(statsLeftRendered);
					}

					// ----- Right side: model + thinking level + provider prefix -----
					const modelName = ctx.model?.id || "no-model";
					const thinkingLevel = pi.getThinkingLevel();
					let rightCore = modelName;
					if (ctx.model?.reasoning) {
						rightCore =
							thinkingLevel === "off"
								? `${modelName} • thinking off`
								: `${modelName} • ${thinkingLevel}`;
					}
					let rightSide = rightCore;
					const minPadding = 2;
					if (footerData.getAvailableProviderCount() > 1 && ctx.model) {
						const withProv = `(${ctx.model.provider}) ${rightCore}`;
						if (statsLeftWidth + minPadding + visibleWidth(withProv) <= width) {
							rightSide = withProv;
						}
					}

					// ----- Layout left + right with padding/truncation -----
					const rightWidth = visibleWidth(rightSide);
					let statsLine: string;
					if (statsLeftWidth + minPadding + rightWidth <= width) {
						const pad = " ".repeat(width - statsLeftWidth - rightWidth);
						statsLine = statsLeftRendered + dimPlain(pad + rightSide);
					} else {
						const availRight = width - statsLeftWidth - minPadding;
						if (availRight > 0) {
							const trunc = truncateToWidth(rightSide, availRight, "");
							const pad = " ".repeat(
								Math.max(0, width - statsLeftWidth - visibleWidth(trunc)),
							);
							statsLine = statsLeftRendered + dimPlain(pad + trunc);
						} else {
							statsLine = statsLeftRendered;
						}
					}

					// ----- Compose lines -----
					const lines: string[] = [];
					lines.push(
						truncateToWidth(dimPlain(pwd), width, dimPlain("...")),
					);
					lines.push(statsLine);

					const exts = footerData.getExtensionStatuses();
					if (exts.size > 0) {
						const sorted = Array.from(exts.entries())
							.sort(([a], [b]) => a.localeCompare(b))
							.map(([, text]) => sanitizeStatusText(text));
						lines.push(truncateToWidth(sorted.join(" "), width, dimPlain("...")));
					}

					return lines;
				},
			};
		});
	});
}
