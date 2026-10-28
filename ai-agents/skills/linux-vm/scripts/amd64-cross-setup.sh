#!/usr/bin/env bash
# amd64-cross-setup.sh <user> — idempotent amd64 cross-build setup for an arm64
# Ubuntu Lima guest that has Rosetta binfmt enabled. Runs as root.
set -euo pipefail

readonly BUILD_USER="${1:?usage: amd64-cross-setup.sh <user>}"
readonly TRIPLET=x86_64-linux-gnu
# amd64 libraries that -sys crates and cgo commonly link against. Add more as
# `<pkg>:amd64` here rather than ad hoc, so the setup stays reproducible.
readonly PACKAGES=(
  gcc-x86-64-linux-gnu g++-x86-64-linux-gnu pkgconf file python3
  libc6:amd64 libc6-dev:amd64 libssl-dev:amd64 zlib1g-dev:amd64
)

[[ "$(id -u)" -eq 0 ]] || { echo "must run as root" >&2; exit 1; }
[[ "$(dpkg --print-architecture)" == arm64 ]] || { echo "expects an arm64 guest" >&2; exit 1; }
grep -qx enabled /proc/sys/fs/binfmt_misc/rosetta 2>/dev/null \
  || { echo "Rosetta binfmt is not enabled; set vmOpts.vz.rosetta in Lima" >&2; exit 1; }
BUILD_HOME="$(getent passwd "$BUILD_USER" | cut -d: -f6)"
readonly BUILD_HOME
[[ -n "$BUILD_HOME" ]] || { echo "unknown user $BUILD_USER" >&2; exit 1; }

exec 9>/run/lock/amd64-cross-setup.lock
flock 9

dpkg --print-foreign-architectures | grep -qx amd64 || dpkg --add-architecture amd64
missing=()
for pkg in "${PACKAGES[@]}"; do
  dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed' || missing+=("$pkg")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  # Refresh every time: an earlier run may have added amd64 but failed to fetch its index.
  apt-get update -qq
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
'

# Merge the Cargo settings through a TOML parser: a textual append could
# redefine an existing table and break every Cargo command.
sudo -u "$BUILD_USER" -H python3 - "$BUILD_HOME/.cargo/config.toml" <<'PY'
import os
import sys
import tempfile
import tomllib

path = sys.argv[1]
target = "x86_64-unknown-linux-gnu"
linker = "x86_64-linux-gnu-gcc"
env = {
    "PKG_CONFIG_x86_64_unknown_linux_gnu": "x86_64-linux-gnu-pkg-config",
    "PKG_CONFIG_ALLOW_CROSS_x86_64_unknown_linux_gnu": "1",
}
block = (
    "\n# amd64-cross-setup: cross settings\n"
    f"[target.{target}]\nlinker = \"{linker}\"\n\n[env]\n"
    + "".join(f"{key} = \"{value}\"\n" for key, value in env.items())
)


def configured(cfg):
    have_env = cfg.get("env", {})
    return cfg.get("target", {}).get(target, {}).get("linker") == linker and all(
        have_env.get(key) == value for key, value in env.items()
    )


text = open(path).read() if os.path.exists(path) else ""
cfg = tomllib.loads(text)  # a file that does not parse is left untouched
if configured(cfg):
    sys.exit(0)
if "env" in cfg or target in cfg.get("target", {}):
    sys.exit(f"{path} already defines [env] or [target.{target}]; merge by hand:\n{block}")
new_text = (text.rstrip("\n") + "\n" if text else "") + block
if not configured(tomllib.loads(new_text)):
    sys.exit(f"appending to {path} would not yield the wanted settings; merge by hand:\n{block}")
os.makedirs(os.path.dirname(path), exist_ok=True)
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path))
with os.fdopen(fd, "w") as out:
    out.write(new_text)
os.chmod(tmp, 0o644)
os.replace(tmp, path)
PY
echo "amd64-cross-setup: ok"
