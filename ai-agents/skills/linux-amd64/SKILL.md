---
name: linux-amd64
description: Build, run, or test on Linux amd64 (x86_64) from this Apple Silicon Mac through a persistent OrbStack build machine that caches Rust, Go, and C/C++ toolchains and dependencies. Use when you need a Linux amd64/x86_64 box, an amd64 build or binary, to check that something builds or runs on x86_64 Linux, or a Linux box in general on macOS.
---

# Linux amd64 on this Mac

The default is `linux-amd64`, a persistent OrbStack machine running Ubuntu 24.04 with an amd64 userland. Use it through the skill-relative wrapper `scripts/linux-amd64`. Toolchains, Cargo registry, Go module cache, and build outputs stay in the machine between runs.

## Choose the path

| Need | Use |
| --- | --- |
| Pure Go binary (`CGO_ENABLED=0`) | Cross-compile on the Mac: `GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build`. No VM needed. |
| Rust, cgo, C/C++, `go test`/`cargo test`, running amd64 binaries | `scripts/linux-amd64 run <cmd>` (default) |
| Clean or specific distro/glibc baseline, throwaway | `docker run --rm --platform linux/amd64 -v "$PWD":/w -w /w <image> <cmd>` |
| A real amd64 **kernel**: modules, ublk, KVM, `/proc/cpuinfo`, AVX2+ | Lima full emulation (QEMU TCG); slow. See below. |
| A Linux box, architecture irrelevant | Lima `linux-dev` (arm64, native speed): `limactl shell linux-dev` |

## Use the build machine

```sh
W=<this skill dir>/scripts/linux-amd64
cd <project on the Mac>
$W run cargo build --release        # creates, starts, and provisions on demand
$W run go build -o app-linux-amd64 .
$W run make test
$W target-dir                       # Mac path of this project's Cargo target dir
$W up                               # only (re)provision
```

- `run` executes in the current Mac directory; the Mac's `/Users` is mounted at the same path.
- Cargo writes to a guest-native per-project directory (`~/.cache/amd64-target/<path-slug>` in the guest), never the project's `./target`. `target-dir` prints its Mac path under `~/OrbStack/linux-amd64/...`. Override with `$W run env CARGO_TARGET_DIR=... cargo build`.
- Go writes where `-o` points, so artifacts land in the Mac checkout.
- Mac environment variables are not forwarded. Pass them as `$W run env FOO=bar <cmd>`.
- Interactive shell: `orb -m linux-amd64` or `ssh linux-amd64@orb`.
- Release resources: `orb stop linux-amd64`. The next `run` restarts it in about 8 seconds.

## Toolchains and caches

`scripts/provision.sh` installs build-essential, clang/lld, cmake/ninja, autotools, pkg-config, OpenSSL/zlib headers, protoc, Go (pinned `GO_VERSION`), and rustup stable with clippy and rustfmt. `up` and `run` re-run it whenever the script's hash changes, so add recurring dependencies there instead of installing them ad hoc. One-off installs (`$W run sudo apt-get install ...`) persist but are not recorded.

- Projects with `rust-toolchain.toml` or a newer `go.mod` toolchain directive fetch that toolchain on first use and cache it.
- Rust is never auto-updated. Run `$W run rustup update` deliberately.

## Limits you must account for

- **The kernel is OrbStack's arm64 kernel.** Rosetta translates the amd64 userland. `uname -m` reports `x86_64`, but kernel-level behavior is not amd64.
- **CPU level is x86-64-v2.** There is no AVX2 or AVX-512. Do not ship artifacts built with `-march=native` or `target-cpu=native` here. Runtime-dispatched SIMD paths take the v2 fallback, so benchmarks and SIMD-specific tests are not representative.
- **Speed:** a clean Rust release build ran about 3x slower than native macOS (measured 18 s vs 6 s). Incremental builds are fast.
- **glibc 2.39 (Ubuntu 24.04).** Binaries may not run on older distributions. For older baselines, use a container with an older image, or musl.
- **Trust equals the Mac.** The machine is not isolated: it has read-write access to `/Users`, a forwarded SSH agent, and macOS command integration. Build only code you would build on the Mac. For untrusted code, use a container or `orb create --isolated`.

## Real amd64 kernel (slow path)

Lima can emulate a complete x86_64 machine with QEMU TCG. Host QEMU is not installed system-wide, so run it from nix:

```sh
nix shell nixpkgs#qemu -c limactl start --name=<task>-amd64 --vm-type=qemu --arch=x86_64 template:ubuntu-24.04
limactl shell <task>-amd64
```

`limactl start` finds QEMU through `PATH`, so a restart needs the same `nix shell` prefix. Expect it to run an order of magnitude slower than native. Do not compile in it: build amd64 artifacts or images in `linux-amd64` or OrbStack Docker, then copy them in for the kernel-level test. Create one VM per task, keep mounts empty unless needed, and delete it when finished (`limactl delete -f <task>-amd64`). For authoritative performance or hardware results, use real x86_64 hardware.
