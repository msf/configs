import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test, type TestContext } from "node:test";

const dockerMock = String.raw`#!/bin/sh
set -eu
printf '%s\n' "$1" >> "$TEST_LOG"
case "$1" in
inspect)
  [ -n "$TEST_CONTAINER_BASE" ] || exit 1
  case "$*" in
    *'.Mounts'*) printf '%s%s\n' "$TEST_CONTAINER_BASE" "$TEST_CONTAINER_MOUNT" ;;
    *) printf '%s\n' "$TEST_CONTAINER_BASE" ;;
  esac
  ;;
run)
  shift
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --mount|-v) printf '%s %s\n' "$1" "$2" >> "$TEST_LOG"; shift ;;
    esac
    shift
  done
  ;;
rm|start) ;;
*) exit 2 ;;
esac
`;

function fixture(t: TestContext) {
  const root = realpathSync(mkdtempSync(join(tmpdir(), "pi searxng test-")));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const bin = join(root, "bin");
  const settings = join(root, "settings.yml");
  const script = join(root, "searxng.sh");
  const liveScript = join(root, "live", "searxng.sh");
  const log = join(root, "docker.log");
  mkdirSync(bin);
  mkdirSync(join(root, "live"));
  copyFileSync(new URL("./searxng.sh", import.meta.url), script);
  symlinkSync(script, liveScript);
  writeFileSync(settings, "use_default_settings: true\n");
  writeFileSync(log, "");
  writeFileSync(join(bin, "docker"), dockerMock, { mode: 0o755 });
  writeFileSync(join(bin, "curl"), "#!/bin/sh\nexit 0\n", { mode: 0o755 });
  const source = readFileSync(script, "utf8");
  const image = source.match(/^IMAGE=(.+)$/m)?.[1];
  assert.ok(image, "the startup script must pin its image");
  const base = `${image} 127.0.0.1:28100`;
  const mount = ` bind:${settings}:false`;
  return {
    settings,
    base,
    mount,
    start(containerBase = base, containerMount = mount) {
      const result = spawnSync("sh", [liveScript, "start"], {
        encoding: "utf8",
        timeout: 5000,
        env: {
          ...process.env,
          PATH: `${bin}:${process.env.PATH}`,
          SEARXNG_PORT: "28100",
          TEST_CONTAINER_BASE: containerBase,
          TEST_CONTAINER_MOUNT: containerMount,
          TEST_LOG: log,
        },
      });
      assert.ifError(result.error);
      return { ...result, calls: readFileSync(log, "utf8").trim().split("\n").filter(Boolean) };
    },
  };
}

function assertRecreated(result: { status: number | null; stderr: string; calls: string[] }, settings: string) {
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.calls, [
    "inspect",
    "rm",
    "run",
    `--mount type=bind,src=${settings},dst=/etc/searxng/settings.yml,readonly`,
    "start",
  ]);
}

test("retains a container with the canonical read-only settings mount", (t) => {
  const f = fixture(t);
  const result = f.start();
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.calls, ["inspect", "start"]);
});

test("recreates a container that still mounts settings from /tmp", (t) => {
  const f = fixture(t);
  assertRecreated(f.start(f.base, " bind:/tmp/pi-web-search/settings.yml:false"), f.settings);
});

test("recreates a container without the settings mount", (t) => {
  const f = fixture(t);
  assertRecreated(f.start(f.base, ""), f.settings);
});

test("recreates a container with a writable settings mount", (t) => {
  const f = fixture(t);
  assertRecreated(f.start(f.base, ` bind:${f.settings}:true`), f.settings);
});

test("recreates a container after an image change", (t) => {
  const f = fixture(t);
  assertRecreated(f.start("searxng/searxng:old 127.0.0.1:28100"), f.settings);
});

test("recreates a container after a port change", (t) => {
  const f = fixture(t);
  assertRecreated(f.start(f.base.replace(":28100", ":28000")), f.settings);
});

test("creates a missing container with an explicit read-only bind mount", (t) => {
  const f = fixture(t);
  const result = f.start("");
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.calls, [
    "inspect",
    "run",
    `--mount type=bind,src=${f.settings},dst=/etc/searxng/settings.yml,readonly`,
    "start",
  ]);
});

for (const kind of ["missing", "directory"] as const) {
  test(`rejects a ${kind} settings file before touching the container`, (t) => {
    const f = fixture(t);
    rmSync(f.settings);
    if (kind === "directory") mkdirSync(f.settings);
    const result = f.start();
    assert.equal(result.status, 1);
    assert.match(result.stderr, /settings must be a regular file/);
    assert.deepEqual(result.calls, []);
    if (kind === "missing") assert.throws(() => readFileSync(f.settings), /ENOENT/);
  });
}
