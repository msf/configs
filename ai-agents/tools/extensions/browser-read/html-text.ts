// Converts a DOM subtree to readable text and keeps link targets as
// "text [→ url]". The function is self-contained so Playwright can serialize
// it into the page, and it also runs in Node against a linkedom document.
export function domToText(args: { root: any; baseUrl: string; withLinks: boolean; useComputedStyle: boolean }): string {
  const { root, baseUrl, withLinks, useComputedStyle } = args;
  const skip = new Set(["SCRIPT", "STYLE", "NOSCRIPT", "TEMPLATE", "SVG", "CANVAS", "IFRAME", "HEAD", "OBJECT"]);
  const block = new Set([
    "ADDRESS", "ARTICLE", "ASIDE", "BLOCKQUOTE", "BR", "DD", "DIV", "DL", "DT", "FIELDSET", "FIGCAPTION", "FIGURE",
    "FOOTER", "FORM", "H1", "H2", "H3", "H4", "H5", "H6", "HEADER", "HR", "LI", "MAIN", "NAV", "OL", "P", "PRE",
    "SECTION", "TABLE", "TR", "UL", "DETAILS", "SUMMARY", "CAPTION",
  ]);
  const out: string[] = [];
  const push = (value: string) => out.push(value);
  const resolve = (href: string): string | undefined => {
    if (!href || href.startsWith("#") || /^(javascript|mailto|tel):/i.test(href)) return undefined;
    try {
      return new URL(href, baseUrl).toString();
    } catch {
      return undefined;
    }
  };
  const hidden = (el: any): boolean => {
    if (el.hasAttribute && el.hasAttribute("hidden")) return true;
    if (!useComputedStyle) return false;
    const style = (globalThis as any).getComputedStyle?.(el);
    return Boolean(style && (style.display === "none" || style.visibility === "hidden"));
  };
  const walk = (node: any): void => {
    if (node.nodeType === 3) {
      push(String(node.nodeValue ?? "").replace(/\s+/g, " "));
      return;
    }
    if (node.nodeType !== 1 && node.nodeType !== 9 && node.nodeType !== 11) return;
    const tag = String(node.tagName ?? "").toUpperCase();
    if (skip.has(tag) || (node.nodeType === 1 && hidden(node))) return;
    if (tag === "PRE") {
      push("\n" + String(node.textContent ?? "") + "\n");
      return;
    }
    const isBlock = block.has(tag);
    if (isBlock) push("\n");
    if (/^H[1-6]$/.test(tag)) push("#".repeat(Number(tag[1])) + " ");
    if (tag === "LI") push("- ");
    if (tag === "TD" || tag === "TH") push(" | ");
    if (tag === "IMG" && node.getAttribute?.("alt")) push(`[image: ${node.getAttribute("alt")}]`);
    for (const child of Array.from(node.childNodes ?? [])) walk(child);
    if (tag === "A" && withLinks) {
      const target = resolve(String(node.getAttribute?.("href") ?? ""));
      if (target) push(` [→ ${target}]`);
    }
    if (isBlock) push("\n");
  };
  walk(root);
  return out
    .join("")
    .split("\n")
    .map((line) => line.replace(/[ \t]+/g, " ").trim())
    .filter((line, index, lines) => line !== "" || (index > 0 && lines[index - 1] !== ""))
    .join("\n")
    .trim();
}
