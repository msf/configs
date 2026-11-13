# vmlab: Linux kernel/storage test VMs on an Apple Silicon Mac

Two boxes, split by what each backend can do (measured 2026-11-12, M5 Max, macOS 26):

| Box | Backend | Use for | Memory |
|---|---|---|---|
| `dev` | OrbStack machine, Debian 13 arm64 (`orb-dev-setup.sh`, then `linux/setup-home.sh --shell-only`); `shlinux` | interactive Linux shell with git (forwarded SSH agent), builds (native + amd64 cross), userspace tests, io_uring | freed memory returns to macOS within ~90 s |
| `golden-<tag>`, `t-*`, `lab` | Lima VZ VMs (`vmlab`) | anything needing its own kernel: KVM guests, ZFS, ublk, loop, LVM/dm-thin, kernel A/B | held until the VM stops |

OrbStack machines share OrbStack's kernel (7.2.x): no `/dev/kvm` (nested KVM is
unsupported), no out-of-tree modules (no ZFS), no dm-thin, and isolated machines
get no ublk/loop/dm devices. Lima VZ has nested KVM and boots any kernel, but
Virtualization.framework never returns touched guest memory (no free-page
reporting), so keep Lima VMs short-lived and stop `lab` when idle.

`dev` is isolated (`orb create --isolated --forward-ssh-agent --mount <dir>:<guest-dir>`):
no `/mnt/mac`, no Mac commands, but the Mac's SSH agent is forwarded, so any process
in it can use your keys while it runs. Don't run untrusted code there.

## Golden image

`deb13-golden.yaml` + `provision.sh`: Debian 13 arm64, ZFS from trixie-backports
(DKMS), nested KVM with GICv3 sysreg trapping (without it nested guests stall
randomly), build-essential, fio, bpftrace, perf, lvm2, btrfs, xfs, no container
runtime, no host mounts, no forwarded ports or SSH agent.

```sh
vmlab golden <tag> [--param KERNEL=...] [--param KFLAVOR=cloud-arm64]   # ~3.5 min
vmlab golden <tag> --refresh        # reinstall guest/ tools, rerun selftest, restamp (~10 s)
```

`KERNEL` is `stock` (trixie), `backports` (newest trixie-backports), or
`snapshot/<YYYYMMDDTHHMMSSZ>/<abi>` for an exact kernel from snapshot.debian.org,
e.g. `snapshot/20260317T000000Z/6.18.15+deb13`. Build one golden per kernel for
A/B kernel tests. The build reboots into the selected kernel, purges every other
kernel, runs `guest/vmlab-selftest` (kernel, vgic trap, KVM, ZFS zvol + ext4,
ublk, io_uring, LVM thin + xfs, btrfs subvolumes) and writes `/etc/vmlab-golden`
(also `~/.cache/vmlab/golden-<tag>.txt`). Lima reruns provisioning on every boot;
a stamp makes reruns and clones no-ops.

## Disposable test VMs

```sh
vmlab new <task> [--from TAG] [--disk 64GiB|0] [--cpus 8] [--memory 8] [--raw-disk]
vmlab put <task> <mac paths>...      # -> /lab/in (read-only in the guest)
vmlab run <task> [--timeout 30m] script.sh [args]   # root; log + /lab/out on the Mac
vmlab shell <task>
vmlab ab <task> script.sh <inputs-a> <inputs-b> [--keep]   # two fresh clones, diff of out/
vmlab rm <task> ; vmlab keep <task> ; vmlab gc [--hours 24] [--yes] ; vmlab ls
```

Host files live in `~/.cache/vmlab/vms/t-<task>/{in,out}`; `rm` keeps `out/`.
Measured: `new` 10 s (APFS clone of the golden disk costs 32 KB; includes a 64 GiB
sparse data disk with the lab layout), `run` overhead ~3 s, `rm` <1 s.
`tests/nested-heartbeat.sh` boots a cloud-hypervisor guest that heartbeats under
disk load; 40/40 with the vgic trap, stalls without it.

## Storage inside a VM: labctl

The data disk becomes VG `lab`: thin pool `lab/thin` (45%), zpool `lab` on
`lab/zfs` (25%), btrfs `lab/scratch` with zstd at `/lab/scratch` (25%).
Everything is created per task and removed with one command:

```sh
sudo labctl zvol <task> <name> 4G          # sparse, volblocksize=16K, compression=off
sudo labctl lv   <task> <name> 8G          # thin LV
sudo labctl fs   <task> <name> 8G xfs|ext4|btrfs   # mounted at /lab/mnt/<task>/<name>
sudo labctl subvol <task> ; sudo labctl snap <task> <new-task>
sudo labctl drop <task> ; sudo labctl ls
```

## lab: the persistent hand-experiment VM

```sh
vmlab lab create [--from TAG] [--size 250GiB]   # clone + persistent disk "lab-data"
vmlab lab shell ; vmlab lab stop
vmlab lab recreate [--from TAG]   # fresh OS from a newer golden; lab-data is kept
```

`vmlab-lab-up.service` re-activates the VG, imports zpool `lab` and mounts
`/lab/scratch` on every boot, including after `recreate`.

## Gotchas found while building this

- `dmesg | grep -q` under `pipefail` fails: grep exits early and dmesg dies of SIGPIPE.
- macOS PATH may resolve GNU `cp`, which has no `-c` (APFS clone): use `/bin/cp -c`.
- `limactl delete -f` kills the VM; uncommitted btrfs writes are lost. Stop first.
- Debian's cloud-arm64 `vmlinuz` is a raw arm64 `Image`, usable directly by cloud-hypervisor.
- Debian 13 has glibc 2.41: binaries built on newer distros may need static linking.
- OrbStack `--mount` has no read-only option; `orb-dev-setup.sh` remounts the share
  read-only at boot (prevents accidents, not a security boundary).
