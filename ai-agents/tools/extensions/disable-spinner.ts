import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_event, context) => {
		context.ui.setWorkingIndicator({
			frames: ["·", "●"],
			intervalMs: 1_500,
		});
	});
}
