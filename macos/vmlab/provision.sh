#!/bin/bash
# Golden-image provisioning, run by Lima as root (see deb13-golden.yaml).
# Lima reruns provisioning on every boot; the stamp makes reruns and clones no-ops.
set -euo pipefail

recipe="v1 kernel=${PARAM_KERNEL} flavor=${PARAM_KFLAVOR}"
state=/var/lib/vmlab
if [ -f "$state/provisioned" ] && [ "$(cat "$state/provisioned")" = "$recipe" ]; then
  exit 0
fi
mkdir -p "$state"
export DEBIAN_FRONTEND=noninteractive
apt_get() { apt-get -o Dpkg::Options::=--force-confold -y "$@"; }

rm -f /etc/apt/sources.list
cat > /etc/apt/sources.list.d/debian.sources <<'EOF'
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie trixie-updates trixie-backports
Components: main contrib
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://deb.debian.org/debian-security
Suites: trixie-security
Components: main contrib
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF

flavor="$PARAM_KFLAVOR"
ktarget=""
case "$PARAM_KERNEL" in
  stock)
    kpkgs=("linux-image-$flavor" "linux-headers-$flavor") ;;
  backports)
    kpkgs=(-t trixie-backports "linux-image-$flavor" "linux-headers-$flavor") ;;
  snapshot/*/*)
    IFS=/ read -r _ snap abi <<<"$PARAM_KERNEL"
    echo "deb [check-valid-until=no signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] http://snapshot.debian.org/archive/debian/$snap trixie-backports main" \
      > /etc/apt/sources.list.d/kernel-snapshot.list
    kpkgs=("linux-image-$abi-$flavor" "linux-headers-$abi-$flavor")
    ktarget="$abi-$flavor" ;;
  *)
    echo "unknown KERNEL=$PARAM_KERNEL" >&2; exit 1 ;;
esac

apt-get -o APT::Update::Error-Mode=any update
apt_get upgrade
apt_get install "${kpkgs[@]}"
apt_get install -t trixie-backports dpkg-dev zfs-dkms zfsutils-linux
apt_get install --no-install-recommends \
  build-essential pkg-config git curl ca-certificates rsync jq zstd python3 \
  busybox-static qemu-utils fio stress-ng tmux vim less file \
  lvm2 thin-provisioning-tools btrfs-progs xfsprogs e2fsprogs dosfstools parted \
  linux-perf bpftrace bpftool trace-cmd blktrace strace ltrace gdb \
  numactl sysstat iproute2 iputils-ping tcpdump ethtool lsof psmisc

# The kernel the image must boot: the snapshot ABI, else the newest installed.
# Older kernels are purged after the first reboot (vmlab golden), so grub's
# default entry is this one.
[ -n "$ktarget" ] || ktarget=$(ls /lib/modules | sort -V | tail -1)
[ -d "/lib/modules/$ktarget" ] || { echo "kernel $ktarget not installed" >&2; exit 1; }
find "/lib/modules/$ktarget" -name 'zfs.ko*' | grep -q . || dkms autoinstall -k "$ktarget"
find "/lib/modules/$ktarget" -name 'zfs.ko*' | grep -q . || { echo "no zfs module for $ktarget" >&2; exit 1; }
echo "$ktarget" > "$state/kernel"

# Nested guests stall on Apple VZ unless L1 traps GICv3 system registers.
echo 'GRUB_CMDLINE_LINUX_DEFAULT="$GRUB_CMDLINE_LINUX_DEFAULT kvm-arm.vgic_v3_group0_trap=1 kvm-arm.vgic_v3_group1_trap=1 kvm-arm.vgic_v3_common_trap=1"' \
  > /etc/default/grub.d/99-vmlab-vgic-trap.cfg
update-grub

echo zfs > /etc/modules-load.d/zfs.conf
echo 'options ublk_drv ublks_max=128' > /etc/modprobe.d/ublk.conf
usermod -aG kvm "{{.User}}"
# Quiet, deterministic guests: no background apt runs during tests.
systemctl disable --now apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
apt-get clean

echo "$recipe" > "$state/provisioned"
