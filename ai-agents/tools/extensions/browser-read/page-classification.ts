const challengeMarkers = [
  "prove your humanity",
  "verify you are human",
  "verify you're human",
  "captcha",
  "recaptcha",
  "attention required",
  "checking if the site connection is secure",
  "press and hold",
  "are you human",
  "access denied",
  "temporarily blocked",
  "blocked by network security",
  "performing security verification",
  "protect against malicious bots",
];

export type PageFailure = "challenge" | "http-error" | undefined;

export function classifyPageFailure(
  responseStatus: number | undefined,
  title: string,
  bodyText: string,
  finalUrl: string,
): PageFailure {
  const haystack = `${title}\n${bodyText.slice(0, 8000)}\n${finalUrl}`.toLowerCase();
  if (challengeMarkers.some((marker) => haystack.includes(marker))) {
    return "challenge";
  }
  if (responseStatus !== undefined && responseStatus >= 400) {
    return "http-error";
  }
  return undefined;
}
