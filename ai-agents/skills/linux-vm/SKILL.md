---
name: linux-vm
description: Run, build, or test on Linux from this Apple Silicon Mac using the Lima VM linux-dev (arm64, native speed), including linux/amd64 (x86_64) builds by cross-compiling there and running the results through Rosetta. Use when you need a Linux box, a Linux VM, a Linux build or test, an amd64/x86_64 Linux binary, or to check that something builds or runs on linux/amd64.
---

# Linux VM on this Mac

One VM serves both cases: the Lima instance `linux-dev` (Ubuntu 26.04 arm64, VZ, 8 vCPUs, 16 GiB, nested KVM, Rosetta). The human enters it with `shlinux` (`limactl shell linux-dev`). Its setup and trust model are documented in `~/configs/macos/linux-dev.md`.

Agents use the skill-relative wrapper `scripts/linux-vm` from the Mac project directory:

```sh
V=<this skill dir>/scripts/linux-vm
$V run <cmd...>     # start the VM if needed, sync the project, run <cmd> in the matching guest dir
$V sync             # sync only; prints the guest dir (~/src/<path below the Mac home>)
$V path             # print the guest dir
```

- The project is the Git work tree or the current directory, and it must be below the Mac home directory.
- A Git project sends exactly the files Git sees (tracked, plus untracked files that are not ignored) and `.git`. Submodule contents are not sent. A non-Git directory sends all its files.
- A file is deleted in the guest only after an earlier sync sent it and the Mac no longer has it. Guest-created files, such as `target/` or other build outputs, persist.
- Copy results back with `limactl copy linux-dev:/home/$USER/out/<file> <mac-dest>`.
- `<cmd>` runs without a shell. Wrap anything that the guest must expand (`~`, `$(...)`, `&&`, globs) in `sh -c '...'` with single quotes, or the Mac shell expands it first.
- Mac environment variables are not forwarded: `$V run env FOO=bar <cmd>`.
- For a command that needs no project, use `limactl shell --workdir / linux-dev -- <cmd>`.

## Any Linux

Build and test natively (arm64). Rust, Go, gcc, and the usual tools are installed. Install missing guest packages with `sudo apt-get install`. This VM is trusted: it has a forwarded SSH agent. Do not run untrusted code here; use a container or a disposable Lima VM.

## Explicit linux/amd64

Cross-compile in `linux-dev`. It is as fast as a native arm64 build. Rosetta and multiarch `:amd64` libraries let the guest run the amd64 output directly, including `cargo test`.

```sh
$V run cargo build --release --target x86_64-unknown-linux-gnu
$V run cargo test --target x86_64-unknown-linux-gnu
$V run sh -c 'mkdir -p ~/out && GOARCH=amd64 CGO_ENABLED=0 go build -o ~/out/app .'   # pure Go (also works on the Mac)
$V run sh -c 'mkdir -p ~/out && GOARCH=amd64 CGO_ENABLED=1 CC=x86_64-linux-gnu-gcc go build -o ~/out/app .'
$V run sh -c 'mkdir -p ~/out && x86_64-linux-gnu-gcc main.c -o ~/out/app $(x86_64-linux-gnu-pkg-config --libs zlib)'
```

- C/C++ build systems: `CC=x86_64-linux-gnu-gcc CXX=x86_64-linux-gnu-g++ PKG_CONFIG=x86_64-linux-gnu-pkg-config`, autotools `--host=x86_64-linux-gnu`, CMake `-DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=x86_64` with those compilers.
- The Cargo linker and target-specific `pkg-config` are set in the guest's `~/.cargo/config.toml`.
- If a build fails on a missing amd64 library, add `<lib>-dev:amd64` to `PACKAGES` in `scripts/amd64-cross-setup.sh`, then run `$V setup-amd64`. The script is idempotent and also restores the setup on a rebuilt VM.
- Executed amd64 code runs through Rosetta, which exposes AVX2 (x86-64-v3) but not AVX-512.

### When cross-compiling is not enough

- **The build insists on a native amd64 toolchain, or you need an amd64 container image:** use OrbStack Docker on the Mac, for example `docker run --rm --platform linux/amd64 -v "$PWD":/w -w /w <image> <cmd>` or `docker buildx build --platform linux/amd64`. It is about 4x slower than cross-compiling, and its Rosetta hides AVX2.
- **Older glibc target:** the guest has glibc 2.43, so dynamically linked output may need glibc 2.43 or newer. To target older systems, build in an older amd64 container or use `--target x86_64-unknown-linux-musl`.
- **A real amd64 kernel (modules, ublk, KVM, kernel behavior):** create a disposable Lima QEMU VM. Copy prebuilt artifacts into it; do not compile there.

  ```sh
  nix shell nixpkgs#qemu -c limactl start --name=<task>-amd64 --vm-type=qemu --arch=x86_64 --mount-none template:ubuntu-24.04
  ```

  QEMU must be on `PATH` for every `limactl start`, so prefix restarts the same way. Delete the VM when done with `limactl delete -f <task>-amd64`.

## Memory

A running Lima VZ VM keeps all guest memory it has touched, up to its configured 16 GiB, until it stops. Freeing memory in the guest does not return it to macOS. Stop it when idle with `limactl stop linux-dev`; `$V run` starts it again. OrbStack, by contrast, returns freed memory to macOS within seconds.
