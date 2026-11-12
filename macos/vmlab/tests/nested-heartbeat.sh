#!/bin/bash
# Nested-KVM health check, run as root inside a vmlab VM (vmlab run <vm> this-file).
# Boots a minimal cloud-hypervisor guest (this VM's own kernel + busybox) that
# writes one heartbeat per second to a results disk while another disk is under
# write load. A stalled L2 guest (Apple VZ drops LPIs unless L1 traps GICv3
# sysregs) shows up as missing heartbeats. Exit 0 iff all heartbeats arrived.
set -euo pipefail

CH_VERSION=${CH_VERSION:-v54.0}
SECS=${SECS:-40}
cache=/var/cache/vmlab
ch=$cache/cloud-hypervisor-$CH_VERSION
w=$(mktemp -d /var/tmp/nested-heartbeat.XXXXXX)
chpid=""
cleanup() { [ -z "$chpid" ] || kill "$chpid" 2>/dev/null || true; rm -rf "$w"; }
trap cleanup EXIT

if [ ! -x "$ch" ]; then
  mkdir -p "$cache"
  curl -fsSL -o "$ch.tmp" \
    "https://github.com/cloud-hypervisor/cloud-hypervisor/releases/download/$CH_VERSION/cloud-hypervisor-static-aarch64"
  chmod +x "$ch.tmp"
  mv "$ch.tmp" "$ch"
fi

# An arm64 vmlinuz is a raw Image ("ARMd" at 0x38; Debian cloud), gzip, or an
# EFI zboot wrapper around a gzip/zstd Image (Ubuntu).
extract_image() {
  local vmlinuz=$1 off
  if [ "$(dd if="$vmlinuz" bs=1 skip=56 count=4 2>/dev/null)" = ARMd ]; then cat "$vmlinuz"; return; fi
  if zcat -t "$vmlinuz" 2>/dev/null; then zcat "$vmlinuz"; return; fi
  off=$(LC_ALL=C grep -abo $'\x1f\x8b\x08' "$vmlinuz" | head -1 | cut -d: -f1 || true)
  if [ -n "$off" ]; then tail -c +$((off + 1)) "$vmlinuz" | zcat 2>/dev/null; return; fi
  off=$(LC_ALL=C grep -abo $'\x28\xb5\x2f\xfd' "$vmlinuz" | head -1 | cut -d: -f1)
  tail -c +$((off + 1)) "$vmlinuz" | zstd -dc
}
extract_image "/boot/vmlinuz-$(uname -r)" > "$w/Image" || true
[ -s "$w/Image" ] || { echo "cannot extract kernel Image" >&2; exit 1; }

# initramfs: busybox, virtio_blk and its module dependencies in load order.
ird=$w/initramfs
mkdir -p "$ird"/{bin,dev,proc,sys,mods}
cp /usr/bin/busybox "$ird/bin/busybox"
n=0
while read -r kind path; do
  [ "$kind" = insmod ] || continue
  n=$((n + 1))
  case $path in
    *.xz) xz -dc "$path" ;;
    *.zst) zstd -dc "$path" ;;
    *) cat "$path" ;;
  esac > "$ird/mods/$(printf %02d $n).ko"
done < <(modprobe --show-depends virtio_blk)
cat > "$ird/init" <<EOF
#!/bin/busybox sh
/bin/busybox --install -s /bin
mount -t proc proc /proc; mount -t sysfs sys /sys; mount -t devtmpfs dev /dev
for m in /mods/*.ko; do insmod \$m; done
while [ ! -b /dev/vdb ]; do sleep 0.1; done
(while :; do dd if=/dev/zero of=/dev/vdb bs=1M count=64 conv=fsync 2>/dev/null; done) &
i=0
while [ \$i -lt $SECS ]; do
  i=\$((i + 1))
  echo "HB \$i \$(cut -d' ' -f1 /proc/uptime)" | dd of=/dev/vda bs=512 seek=\$i conv=sync,fsync 2>/dev/null
  sleep 1
done
echo DONE | dd of=/dev/vda bs=512 conv=sync,fsync 2>/dev/null
poweroff -f
EOF
chmod +x "$ird/init"
(cd "$ird" && find . | cpio -o -H newc 2>/dev/null | gzip > "$w/initramfs.cpio.gz")

truncate -s 1M "$w/results.img"
truncate -s 256M "$w/load.img"
"$ch" --version
"$ch" --kernel "$w/Image" --initramfs "$w/initramfs.cpio.gz" \
  --cmdline "console=ttyAMA0 loglevel=5" --cpus boot=2 --memory size=512M \
  --disk path="$w/results.img",image_type=raw path="$w/load.img",image_type=raw \
  --serial file="$w/serial.log" --console off > "$w/ch.log" 2>&1 &
chpid=$!

deadline=$((SECONDS + SECS + 60))
until tr -d '\000' < "$w/results.img" | grep -q '^DONE'; do
  kill -0 "$chpid" 2>/dev/null || { echo "cloud-hypervisor exited early:"; tail -5 "$w/ch.log"; break; }
  [ "$SECONDS" -lt "$deadline" ] || { echo "timeout waiting for DONE"; break; }
  sleep 1
done
beats=$(tr -d '\000' < "$w/results.img" | grep -c '^HB' || true)
echo "heartbeats=$beats/$SECS last=$(tr -d '\000' < "$w/results.img" | grep '^HB' | tail -1)"
mkdir -p /lab/out 2>/dev/null && cp "$w/serial.log" /lab/out/nested-heartbeat-serial.log 2>/dev/null || true
[ "$beats" -eq "$SECS" ]
