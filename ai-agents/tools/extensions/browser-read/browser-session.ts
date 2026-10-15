import { spawn } from "node:child_process";
import { mkdir, open } from "node:fs/promises";
import { join } from "node:path";
import { chromium, type BrowserContext } from "playwright-core";

// A login in another session must not block a reader indefinitely.
const profileLockTimeoutSeconds = 30;

type LaunchOptions = NonNullable<Parameters<typeof chromium.launchPersistentContext>[1]>;

export async function withProfileLock<T>(
  profileDir: string,
  action: () => Promise<T>,
  signal?: AbortSignal,
  timeoutSeconds = profileLockTimeoutSeconds,
): Promise<T> {
  signal?.throwIfAborted();
  if (!Number.isInteger(timeoutSeconds) || timeoutSeconds < 0 || timeoutSeconds > 120) {
    throw new Error("Profile lock timeout must be an integer from 0 to 120 seconds");
  }
  await mkdir(profileDir, { recursive: true });
  const file = await open(join(profileDir, ".browser-read.lock"), "a", 0o600);
  try {
    const command = process.platform === "darwin" ? "/usr/bin/lockf" : "flock";
    const args = process.platform === "darwin"
      ? ["-s", "-t", String(timeoutSeconds), "3"]
      : ["-w", String(timeoutSeconds), "3"];
    // The child locks our inherited open-file description; we retain it until close().
    await new Promise<void>((resolve, reject) => {
      const child = spawn(command, args, {
        stdio: ["ignore", "ignore", "ignore", file.fd],
        signal,
      });
      child.once("error", reject);
      child.once("close", (code) => {
        if (code === 0) return resolve();
        reject(new Error(
          `Browser profile is busy or could not be locked: ${profileDir} (${command} exit ${code}). ` +
          "Another Pi session or /browser-login may be using it. Close its browser window and retry.",
        ));
      });
    });
    signal?.throwIfAborted();
    return await action();
  } finally {
    // Keep the file: unlinking it would let callers lock different inodes.
    await file.close();
  }
}

export function waitForLastWindow(context: BrowserContext): Promise<void> {
  return new Promise((resolve) => {
    const checkPages = () => {
      if (context.pages().length === 0) resolve();
    };
    const watchPage = (page: ReturnType<BrowserContext["pages"]>[number]) => {
      page.once("close", checkPages);
    };
    context.once("close", () => resolve());
    context.on("page", watchPage);
    context.pages().forEach(watchPage);
    checkPages();
  });
}

export class BrowserSession {
  private readonly shutdown = new AbortController();
  private context: BrowserContext | undefined;
  private closing: Promise<void> | undefined;
  private readonly profileDir: string;

  constructor(profileDir: string) {
    this.profileDir = profileDir;
  }

  async run<T>(
    options: LaunchOptions,
    action: (context: BrowserContext) => Promise<T>,
    signal?: AbortSignal,
  ): Promise<T> {
    const combinedSignal = AbortSignal.any([
      this.shutdown.signal,
      ...(signal ? [signal] : []),
    ]);
    return withProfileLock(this.profileDir, async () => {
      combinedSignal.throwIfAborted();
      const context = await chromium.launchPersistentContext(this.profileDir, options).catch((error: unknown) => {
        if (error instanceof Error && /ProcessSingleton|SingletonLock/.test(error.message)) {
          throw new Error(
            `Chrome already owns the browser-read profile at ${this.profileDir}. ` +
            "Close or quit that dedicated browser (not your normal Chrome), then retry. " +
            "Reload older Pi sessions with /reload. Do not delete a live SingletonLock.",
            { cause: error },
          );
        }
        throw error;
      });
      this.context = context;
      const closeOnAbort = () => {
        // Cancellation is best-effort here; the finally block also awaits cleanup.
        void this.closeContext().catch((error: unknown) => console.error("Browser cancellation cleanup failed:", error));
      };
      combinedSignal.addEventListener("abort", closeOnAbort, { once: true });
      try {
        combinedSignal.throwIfAborted();
        return await action(context);
      } finally {
        combinedSignal.removeEventListener("abort", closeOnAbort);
        await this.closeContext();
        this.context = undefined;
        this.closing = undefined;
      }
    }, combinedSignal);
  }

  private async closeContext(): Promise<void> {
    // Playwright's second close() returns before the first close has completed.
    if (this.context) this.closing ??= this.context.close();
    await this.closing;
  }

  async close(): Promise<void> {
    this.shutdown.abort();
    await this.closeContext();
  }
}
