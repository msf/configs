---
name: linux-vm
description: Run, build, or test on Linux from this Apple Silicon Mac. Builds and userspace tests go to the OrbStack machine dev (Debian 13 arm64, amd64 cross-compiling, Rosetta). Anything needing its own kernel (KVM/nested VMs, cloud-hypervisor, ZFS/zvols, ublk, loop, LVM/dm-thin, kernel A/B) goes to disposable Lima VMs via vmlab. Use when you need a Linux box, a Linux build or test, an amd64/x86_64 Linux binary, or a kernel/block-device/VMM test.
---

# Linux on this Mac

Two backends, split by what each can do. Details, measurements and the golden-image recipe: `~/configs/macos/vmlab/README.md`.

| Need | Use |
|---|---|
| Build (native arm64 or amd64 cross), lint, unit tests, io_uring | OrbStack machine `dev`, through `scripts/linux-vm` |
| KVM / nested guests, ZFS, ublk, loop, LVM/dm-thin, a specific kernel | disposable Lima VM through `vmlab` |
| Real amd64 kernel | a remote amd64 host; locally only a slow QEMU VM (below) |

`dev` shares OrbStack's kernel (7.2.x): it has no `/dev/kvm`, no ZFS, no dm-thin, and as an isolated machine no ublk/loop/dm devices. Don't try kernel or block-device tests there.

## Builds: OrbStack `dev`

Debian 13 arm64, glibc 2.41, Go, rustup (stable plus any pinned toolchain), gcc/clang, the amd64 cross toolchain, zsh and the human's dotfiles. It is an isolated machine (no `/mnt/mac`, no Mac commands; selected Mac directories may be mounted read-only) but it forwards the Mac's SSH agent for git, so treat it as trusted: no untrusted code there; use a disposable `vmlab` VM or container instead. The human enters it with `shlinux` (`orb -m dev`).

Agents use the skill-relative wrapper `scripts/linux-vm` from the Mac project directory:

```sh
V=<this skill dir>/scripts/linux-vm
$V run <cmd...>     # start dev if needed, sync the project, run <cmd> in the matching guest dir
$V sync             # sync only; prints the guest dir (~/src/<path below the Mac home>)
$V path             # print the guest dir
$V setup            # (re)install toolchains; idempotent
```

- The project is the Git work tree or the current directory, and it must be below the Mac home directory.
- A Git project sends exactly the files Git sees (tracked, plus untracked files that are not ignored) and `.git`. Submodule contents are not sent. A non-Git directory sends all its files. A dangling tracked symlink makes rsync fail; export with `git archive` instead.
- A file is deleted in the guest only after an earlier sync sent it and the Mac no longer has it. Guest-created files, such as `target/` or other build outputs, persist; delete large target dirs when done.
- Copy results back with `orb -m dev cat <file> > <mac-dest>` or `scp dev@orb:<file> <mac-dest>`.
- `<cmd>` runs without a shell. Wrap anything that the guest must expand (`~`, `$(...)`, `&&`, globs) in `sh -c '...'` with single quotes, or the Mac shell expands it first.
- Mac environment variables are not forwarded: `$V run env FOO=bar <cmd>`.
- For a command that needs no project, use `orb -m dev <cmd>`.

### Explicit linux/amd64

Cross-compile in `dev`; Rosetta runs the amd64 output, including `cargo test`, except io_uring (ENOSYS under Rosetta).

```sh
$V run cargo build --release --target x86_64-unknown-linux-gnu
$V run sh -c 'mkdir -p ~/out && GOARCH=amd64 CGO_ENABLED=0 go build -o ~/out/app .'
$V run sh -c 'mkdir -p ~/out && GOARCH=amd64 CGO_ENABLED=1 CC=x86_64-linux-gnu-gcc go build -o ~/out/app .'
```

- C/C++ build systems: `CC=x86_64-linux-gnu-gcc CXX=x86_64-linux-gnu-g++ PKG_CONFIG=x86_64-linux-gnu-pkg-config`, autotools `--host=x86_64-linux-gnu`.
- The Cargo linker and target `pkg-config` are set in the guest's `~/.cargo/config.toml`. Add missing `<lib>-dev:amd64` packages to `orb-dev-setup.sh`, then `$V setup`.
- An amd64 container image or a native amd64 toolchain: OrbStack Docker, `docker run --rm --platform linux/amd64 ...` (about 4x slower than cross-compiling).

## Kernel, KVM and block-device tests: vmlab

`vmlab` (`~/configs/macos/vmlab/vmlab`) clones a stopped Debian 13 golden VM (`golden-<tag>`: chosen kernel, ZFS, nested KVM with the vgic trap, gcc, fio, bpftrace, lvm2) into `t-<task>` in about 10 s. One VM per task; never use another session's `t-*` VM.

```sh
vmlab new <task>                    # booted; 64 GiB data disk with VG lab / zpool lab / btrfs scratch
vmlab put <task> <mac paths>...     # -> /lab/in (read-only in the guest)
vmlab run <task> ./test.sh          # root, 30 min timeout; log and /lab/out land in ~/.cache/vmlab/vms/t-<task>/out
vmlab ab <task> ./test.sh <dirA> <dirB>   # same script in two fresh clones, diff of out/
vmlab shell <task> ; vmlab rm <task> ; vmlab gc [--yes]
```

- Inside: `sudo labctl zvol|lv|fs|subvol <task> ...` creates task-scoped storage; `sudo labctl drop <task>` removes it.
- Ship static binaries or binaries built on Debian 13 (`dev`); glibc is 2.41.
- Write test steps to a script file and `vmlab run` it; avoid inline `bash -c` quoting and self-matching `pkill -f`.
- Always run a negative control (the unfixed build must fail).
- `vmlab lab shell` is the human's persistent experiment VM; agents use it only when asked.

## Real amd64 kernel (slow, last resort)

A disposable Lima QEMU VM emulates x86_64 (TCG, roughly 10x slower). Copy prebuilt artifacts in; do not compile there.

```sh
nix shell --impure --expr 'with import <nixpkgs> {}; { lima = lima.override { withAdditionalGuestAgents = true; }; inherit qemu; }' lima qemu \
  -c limactl start --name=<task>-amd64 --vm-type=qemu --arch=x86_64 --mount-none template:debian-13
```

QEMU must be on `PATH` for every `limactl start`. Delete it when done: `limactl delete -f <task>-amd64`.

## Memory

OrbStack returns freed memory to macOS within about 90 s. Lima VZ VMs keep all memory the guest touched until they stop: keep `t-*` VMs short-lived and stop `lab` when idle (`vmlab lab stop`).
