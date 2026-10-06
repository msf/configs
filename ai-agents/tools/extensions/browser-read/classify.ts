export type Outcome = "acquired" | "blocked" | "incomplete" | "failed";

export interface Classification {
  outcome: Outcome;
  reason: string;
}

export interface PageObservation {
  status: number | undefined;
  title: string;
  text: string;
  finalUrl: string;
  // Text-based rules (challenge wording, login, soft 404, empty render) only make sense for HTML.
  isHtml: boolean;
}

// Pages shorter than this are interstitials or stubs; generic challenge words
// only count on them, so long articles that discuss CAPTCHA stay acquired.
export const SHORT_PAGE_CHARS = 3000;
export const EMPTY_PAGE_CHARS = 40;

const challengeTitles = [
  "just a moment",
  "attention required",
  "access denied",
  "security check",
  "verify you are human",
  "are you a robot",
  "are you human",
  "captcha",
  "bot verification",
  "robot check",
  "one more step",
];

const challengeBodyMarkers = [
  "prove your humanity",
  "verify you are human",
  "verify you're human",
  "captcha",
  "checking if the site connection is secure",
  "needs to review the security of your connection",
  "press and hold",
  "are you human",
  "access denied",
  "temporarily blocked",
  "blocked by network security",
  "performing security verification",
  "protect against malicious bots",
  "enable javascript and cookies to continue",
  "please complete the following challenge",
  "request unsuccessful. incapsula",
];

// Search-engine block pages: matched regardless of page length.
const searchBlockMarkers = [
  "our systems have detected unusual traffic",
  "unfortunately, bots use duckduckgo too",
  "this page checks to see if it's really you sending the requests",
  "one last step: please solve the challenge below",
];

const loginTitles = ["sign in", "log in", "login", "sign-in", "log-in"];
const loginBodyMarkers = ["sign in to continue", "log in to continue", "please sign in", "please log in", "you need to sign in"];

const notFoundTitle = /(^|\W)(404|not found|page not found|page doesn['’]t exist|page does not exist|no such page)(\W|$)/i;
const notFoundBody = /(page (was )?not found|couldn['’]t find (that|this|the) page|could not find (that|this|the) page|page (you requested )?(does not|doesn['’]t) exist|404)/i;

function includesAny(haystack: string, needles: string[]): string | undefined {
  return needles.find((needle) => haystack.includes(needle));
}

export function classifyPage(page: PageObservation): Classification {
  const title = page.title.toLowerCase();
  const text = page.text.trim();
  const textLower = text.slice(0, 20000).toLowerCase();
  const isShort = text.length < SHORT_PAGE_CHARS;
  const path = safePath(page.finalUrl);
  const status = page.status;

  const searchBlock = includesAny(textLower, searchBlockMarkers);
  if (path.startsWith("/sorry/") || searchBlock) {
    return { outcome: "blocked", reason: `search-engine block page (${searchBlock ?? "/sorry/ redirect"})` };
  }

  // Interstitials are titled by the challenge itself; an article whose title
  // merely mentions CAPTCHA does not start with the marker.
  const titleChallenge = page.isHtml ? challengeTitles.find((marker) => title.trim().startsWith(marker)) : undefined;
  const bodyChallenge = page.isHtml && isShort ? includesAny(textLower, challengeBodyMarkers) : undefined;
  if (titleChallenge || bodyChallenge) {
    return { outcome: "blocked", reason: `challenge page ("${titleChallenge ?? bodyChallenge}")` };
  }

  if (status === 401 || status === 407) return { outcome: "blocked", reason: `HTTP ${status} authentication required` };
  if (status === 403 || status === 429 || status === 451) return { outcome: "blocked", reason: `HTTP ${status}` };
  if (status === 404 || status === 410) return { outcome: "failed", reason: `HTTP ${status} not found` };
  if (status !== undefined && status >= 400) return { outcome: "failed", reason: `HTTP ${status}` };

  const loginTitle = loginTitles.some((marker) => new RegExp(`(^|\\W)${marker}(\\W|$)`).test(title));
  const loginBody = includesAny(textLower, loginBodyMarkers);
  if (page.isHtml && isShort && (loginTitle || loginBody)) {
    return { outcome: "blocked", reason: "login wall" };
  }

  if (page.isHtml && isShort && (notFoundTitle.test(page.title) || notFoundBody.test(text.slice(0, 600)))) {
    return { outcome: "failed", reason: "soft 404 (page says it was not found)" };
  }

  if (status === 202) {
    return { outcome: "incomplete", reason: "HTTP 202 accepted, content may not be final" };
  }
  if (status !== undefined && (status < 200 || status >= 300)) {
    return { outcome: "incomplete", reason: `HTTP ${status}` };
  }

  if (page.isHtml && text.length < EMPTY_PAGE_CHARS) {
    return { outcome: "incomplete", reason: "little or no visible text" };
  }
  return { outcome: "acquired", reason: "content acquired" };
}

function safePath(url: string): string {
  try {
    return new URL(url).pathname;
  } catch {
    return "";
  }
}

// Static HTML that only renders in a browser: empty app roots, noscript
// warnings, or loading placeholders. Used by the HTTP-first reader to decide
// whether to fall back to the browser.
export function needsBrowser(html: string, text: string): string | undefined {
  if (text.trim().length < 500) return "little static text";
  if (/<noscript[^>]*>[^<]*(enable|requires?) javascript/i.test(html) && text.trim().length < 2000) {
    return "page requires JavaScript";
  }
  if (/<div[^>]+id=["'](root|app|__next|__nuxt)["'][^>]*>\s*<\/div>/i.test(html)) return "empty application root";
  if (/^loading\b.{0,60}(\.\.\.|…)$/im.test(text)) return "loading placeholder in static HTML";
  return undefined;
}
