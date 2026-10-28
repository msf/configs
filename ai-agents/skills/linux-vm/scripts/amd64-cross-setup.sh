#!/usr/bin/env bash
# amd64-cross-setup.sh <user> — idempotent amd64 cross-build setup for an arm64
# Ubuntu Lima guest that has Rosetta binfmt enabled. Runs as root.
set -euo pipefail

readonly BUILD_USER="${1:?usage: amd64-cross-setup.sh <user>}"
readonly TRIPLET=x86_64-linux-gnu
# amd64 libraries that -sys crates and cgo commonly link against. Add more as
# `<pkg>:amd64` here rather than ad hoc, so the setup stays reproducible.
readonly PACKAGES=(
  gcc-x86-64-linux-gnu g++-x86-64-linux-gnu pkgconf file
  libc6:amd64 libc6-dev:amd64 libssl-dev:amd64 zlib1g-dev:amd64
)

[[ "$(id -u)" -eq 0 ]] || { echo "must run as root" >&2; exit 1; }
[[ "$(dpkg --print-architecture)" == arm64 ]] || { echo "expects an arm64 guest" >&2; exit 1; }
grep -qx enabled /proc/sys/fs/binfmt_misc/rosetta 2>/dev/null \
  || { echo "Rosetta binfmt is not enabled; set vmOpts.vz.rosetta in Lima" >&2; exit 1; }

exec 9>/run/lock/amd64-cross-setup.lock
flock 9

if ! dpkg --print-foreign-architectures | grep -qx amd64; then
  dpkg --add-architecture amd64
  apt-get update -qq
fi
missing=()
for pkg in "${PACKAGES[@]}"; do
  dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed' || missing+=("$pkg")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends "${missing[@]}"
fi

# Debian ships a <triplet>-pkg-config wrapper only for the native architecture;
# pkgconf selects this personality from the invoked name.
cat > "/usr/share/pkgconfig/personality.d/$TRIPLET.personality" <<EOF
Triplet: $TRIPLET
DefaultSearchPaths: /usr/local/lib/$TRIPLET/pkgconfig:/usr/lib/$TRIPLET/pkgconfig:/usr/share/pkgconfig
SystemIncludePaths: /usr/include
SystemLibraryPaths: /lib/$TRIPLET:/usr/lib/$TRIPLET
EOF
ln -sf /usr/bin/pkgconf "/usr/local/bin/$TRIPLET-pkg-config"

sudo -u "$BUILD_USER" -H bash -euo pipefail -c '
  export PATH="$HOME/.cargo/bin:$PATH"
  rustup target list --installed | grep -qx x86_64-unknown-linux-gnu \
    || rustup target add x86_64-unknown-linux-gnu
  config="$HOME/.cargo/config.toml"
  # TOML forbids repeated tables, so never append a second [target...] or [env].
  if ! grep -qxF "[target.x86_64-unknown-linux-gnu]" "$config" 2>/dev/null; then
    if grep -qxF "[env]" "$config" 2>/dev/null; then
      echo "$config already has [env]; merge the amd64 settings by hand" >&2
      exit 1
    fi
    cat >> "$config" <<EOF

# amd64-cross-setup: cross settings
[target.x86_64-unknown-linux-gnu]
linker = "x86_64-linux-gnu-gcc"

[env]
PKG_CONFIG_x86_64_unknown_linux_gnu = "x86_64-linux-gnu-pkg-config"
PKG_CONFIG_ALLOW_CROSS_x86_64_unknown_linux_gnu = "1"
EOF
  fi
'
echo "amd64-cross-setup: ok"
