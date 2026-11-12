#!/usr/bin/env bash
# orb-dev-setup.sh [user]: idempotent build setup for an OrbStack Debian 13 arm64
# machine: native + amd64 cross C/Rust/Go toolchains (see README.md).
#
# Create the machine (isolated: no /mnt/mac, no Mac commands, no SSH agent):
#   orb create --isolated --mount <mac-dir>:<guest-dir> debian:trixie dev
# Then, as root inside it:
#   orb -m dev -u root env RO_MOUNT=<guest-dir> bash -s -- "$USER" < orb-dev-setup.sh
#
# Env: GO_VERSION (default 1.26.8); RUST_PIN (extra pinned toolchain, optional);
# RO_MOUNT (remount that host share read-only at boot; empty = skip).
set -euo pipefail

readonly BUILD_USER="${1:-miguel}"
readonly GO_VERSION="${GO_VERSION:-1.26.8}"
readonly TRIPLET=x86_64-linux-gnu
readonly RUST_TARGET=x86_64-unknown-linux-gnu

[[ "$(id -u)" -eq 0 ]] || { echo "must run as root" >&2; exit 1; }
[[ "$(dpkg --print-architecture)" == arm64 ]] || { echo "expects an arm64 guest" >&2; exit 1; }
BUILD_HOME="$(getent passwd "$BUILD_USER" | cut -d: -f6)"
readonly BUILD_HOME
[[ -n "$BUILD_HOME" ]] || { echo "unknown user $BUILD_USER" >&2; exit 1; }
readonly RO_MOUNT="${RO_MOUNT:-}"

mkdir -p /run/lock
exec 9>/run/lock/orb-dev-setup.lock
flock 9
export DEBIAN_FRONTEND=noninteractive

# --- 0. home directory --------------------------------------------------------
# With --mount below the home dir, OrbStack creates /home/<user> as root:root
# with no skeleton files, so rustup cannot write ~/.cargo. Fix ownership of the
# home dir itself only (never recurse into the host mount).
BUILD_GROUP="$(id -gn "$BUILD_USER")"
if [[ "$(stat -c %U "$BUILD_HOME")" != "$BUILD_USER" ]]; then
  chown "$BUILD_USER:$BUILD_GROUP" "$BUILD_HOME"
fi
for f in .bashrc .profile .bash_logout; do
  [[ -e "$BUILD_HOME/$f" ]] || install -o "$BUILD_USER" -g "$BUILD_GROUP" -m 0644 "/etc/skel/$f" "$BUILD_HOME/$f"
done

# --- 1. read-only view of the selectively mounted host tree -------------------
# OrbStack's --mount has no read-only option (SOURCE:DEST:ro creates a directory
# literally named "DEST:ro"). Remount the bind read-only at boot instead. This
# blocks accidental writes from the guest; guest root (and miguel via sudo) can
# undo it, so it is not a security boundary.
if [[ -n "$RO_MOUNT" ]]; then
  unit=/etc/systemd/system/orb-ro-mount.service
  want="[Unit]
Description=Remount OrbStack host share $RO_MOUNT read-only
ConditionPathIsMountPoint=$RO_MOUNT
After=local-fs.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/mount -o remount,bind,ro $RO_MOUNT

[Install]
WantedBy=multi-user.target"
  if [[ ! -f "$unit" ]] || [[ "$(cat "$unit")" != "$want" ]]; then
    printf '%s\n' "$want" > "$unit"
    systemctl daemon-reload
  fi
  systemctl enable orb-ro-mount.service >/dev/null 2>&1 || true
  if mountpoint -q "$RO_MOUNT"; then
    findmnt -no OPTIONS "$RO_MOUNT" | grep -q '^ro' || mount -o remount,bind,ro "$RO_MOUNT"
  fi
fi

# --- 2. native packages -------------------------------------------------------
dpkg --print-foreign-architectures | grep -qx amd64 || dpkg --add-architecture amd64
PACKAGES=(
  # build parity with linux-dev
  build-essential pkgconf pkg-config git curl ca-certificates jq zstd xz-utils rsync
  busybox-static libc6-dev file python3 sudo
  # bindgen (libublk) needs libclang; clang/lld for crates that ask for them
  clang lld libclang-dev
  protobuf-compiler
  # kernel-feature smoke / ops tools
  fio lvm2 thin-provisioning-tools btrfs-progs util-linux kmod
  # amd64 cross toolchain + multiarch libs (Debian names; same as the Ubuntu script)
  gcc-x86-64-linux-gnu g++-x86-64-linux-gnu
  libc6:amd64 libc6-dev:amd64 libssl-dev:amd64 zlib1g-dev:amd64
  libssl-dev
)
missing=()
for pkg in "${PACKAGES[@]}"; do
  dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed' || missing+=("$pkg")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends "${missing[@]}"
fi

# Debian ships <triplet>-pkg-config only for the native arch; pkgconf picks this
# personality from the invoked name.
mkdir -p /usr/share/pkgconfig/personality.d
cat > "/usr/share/pkgconfig/personality.d/$TRIPLET.personality" <<EOF
Triplet: $TRIPLET
DefaultSearchPaths: /usr/local/lib/$TRIPLET/pkgconfig:/usr/lib/$TRIPLET/pkgconfig:/usr/share/pkgconfig
SystemIncludePaths: /usr/include
SystemLibraryPaths: /lib/$TRIPLET:/usr/lib/$TRIPLET
EOF
ln -sf /usr/bin/pkgconf "/usr/local/bin/$TRIPLET-pkg-config"

# --- 3. Go (upstream tarball) -------------------------------------------------
if [[ "$(/usr/local/go/bin/go env GOVERSION 2>/dev/null || true)" != "go$GO_VERSION" ]]; then
  tmp="$(mktemp -d)"
  curl -fsSL --retry 3 -o "$tmp/go.tgz" "https://go.dev/dl/go$GO_VERSION.linux-arm64.tar.gz"
  rm -rf /usr/local/go
  tar -C /usr/local -xzf "$tmp/go.tgz"
  rm -rf "$tmp"
fi
cat > /etc/profile.d/go.sh <<'EOF'
case ":$PATH:" in *:/usr/local/go/bin:*) ;; *) PATH="/usr/local/go/bin:$PATH" ;; esac
case ":$PATH:" in *":$HOME/go/bin:"*) ;; *) PATH="$PATH:$HOME/go/bin" ;; esac
export PATH
EOF
# non-login shells (orb -m dev cmd ...) read ~/.bashrc only on interactive; make
# go reachable for scripts too.
ln -sf /usr/local/go/bin/go /usr/local/bin/go
ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt

# --- 4. Rust (per-user rustup, minimal profile) -------------------------------
RUST_PIN="${RUST_PIN:-stable}"
sudo -u "$BUILD_USER" -H env RUST_PIN="$RUST_PIN" RUST_TARGET="$RUST_TARGET" bash -euo pipefail -c '
  if [[ ! -x "$HOME/.cargo/bin/rustup" ]]; then
    curl --proto "=https" --tlsv1.2 -fsSL https://sh.rustup.rs \
      | sh -s -- -y --profile minimal --default-toolchain stable --no-modify-path
  fi
  export PATH="$HOME/.cargo/bin:$PATH"
  rustup toolchain list | grep -q "^stable" || rustup toolchain install stable --profile minimal
  rustup toolchain list | grep -q "^$RUST_PIN-" \
    || rustup toolchain install "$RUST_PIN" --profile minimal -c rustfmt -c clippy
  for tc in stable "$RUST_PIN"; do
    rustup +"$tc" target list --installed | grep -qx "$RUST_TARGET" || rustup +"$tc" target add "$RUST_TARGET"
  done
  grep -q ".cargo/env" "$HOME/.profile" 2>/dev/null || echo ". \"\$HOME/.cargo/env\"" >> "$HOME/.profile"
  grep -q ".cargo/env" "$HOME/.bashrc" 2>/dev/null || echo ". \"\$HOME/.cargo/env\"" >> "$HOME/.bashrc"
'

# Merge cross settings into ~/.cargo/config.toml through a TOML parser.
sudo -u "$BUILD_USER" -H python3 - "$BUILD_HOME/.cargo/config.toml" <<'PY'
import os, sys, tempfile, tomllib
path = sys.argv[1]
target = "x86_64-unknown-linux-gnu"
linker = "x86_64-linux-gnu-gcc"
env = {
    "PKG_CONFIG_x86_64_unknown_linux_gnu": "x86_64-linux-gnu-pkg-config",
    "PKG_CONFIG_ALLOW_CROSS_x86_64_unknown_linux_gnu": "1",
}
block = ("\n# orb-dev setup: amd64 cross settings\n"
         f"[target.{target}]\nlinker = \"{linker}\"\n\n[env]\n"
         + "".join(f"{k} = \"{v}\"\n" for k, v in env.items()))
def configured(cfg):
    e = cfg.get("env", {})
    return (cfg.get("target", {}).get(target, {}).get("linker") == linker
            and all(e.get(k) == v for k, v in env.items()))
text = open(path).read() if os.path.exists(path) else ""
cfg = tomllib.loads(text)
if configured(cfg):
    sys.exit(0)
if "env" in cfg or target in cfg.get("target", {}):
    sys.exit(f"{path} already defines [env] or [target.{target}]; merge by hand:\n{block}")
new_text = (text.rstrip("\n") + "\n" if text else "") + block
assert configured(tomllib.loads(new_text))
os.makedirs(os.path.dirname(path), exist_ok=True)
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
with os.fdopen(fd, "w") as out:
    out.write(new_text)
os.chmod(tmp, 0o644)
os.replace(tmp, path)
PY

# --- 5. report ----------------------------------------------------------------
echo "go: $(/usr/local/go/bin/go version)"
sudo -u "$BUILD_USER" -H bash -c 'export PATH=$HOME/.cargo/bin:$PATH; rustup toolchain list | tr "\n" " "; echo'
echo "cross: $(x86_64-linux-gnu-gcc --version | head -1)"
[[ -n "$RO_MOUNT" ]] && echo "ro mount: $(findmnt -no OPTIONS "$RO_MOUNT" 2>/dev/null || echo 'not mounted')"
echo "orb-dev setup: ok"
