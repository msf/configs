#!/usr/bin/env bash
# provision.sh <user> — idempotent toolchain setup for the linux-amd64 build machine.
# Runs inside the guest as root. Installs only what is missing; never upgrades
# an installed Rust toolchain (run `rustup update` deliberately).
set -euo pipefail

readonly BUILD_USER="${1:?usage: provision.sh <user>}"
readonly STATE_DIR=/var/lib/linux-amd64
# Matches the Mac's Go at skill creation. Projects that need a newer Go get it
# through go.mod's toolchain directive (GOTOOLCHAIN=auto), cached per version.
readonly GO_VERSION=1.26.7
readonly APT_PACKAGES=(
  build-essential clang lld cmake ninja-build pkg-config autoconf automake libtool
  libssl-dev zlib1g-dev protobuf-compiler
  git curl ca-certificates jq unzip xz-utils zstd file python3 python3-venv
)

[[ "$(id -u)" -eq 0 ]] || { echo "provision.sh: must run as root" >&2; exit 1; }
[[ "$(dpkg --print-architecture)" == amd64 ]] || { echo "provision.sh: not an amd64 userland" >&2; exit 1; }

mkdir -p "$STATE_DIR"
# Concurrent agents may call `up` at once; apt and rustup are not safe to race.
exec 9>"$STATE_DIR/provision.lock"
flock 9

install_apt_packages() {
  local missing=()
  local pkg
  for pkg in "${APT_PACKAGES[@]}"; do
    dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q 'install ok installed' || missing+=("$pkg")
  done
  [[ ${#missing[@]} -eq 0 ]] && return 0
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends "${missing[@]}"
}

install_go() {
  if [[ -x /usr/local/go/bin/go ]] && [[ "$(/usr/local/go/bin/go env GOVERSION)" == "go${GO_VERSION}" ]]; then
    return 0
  fi
  local file="go${GO_VERSION}.linux-amd64.tar.gz"
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL "https://go.dev/dl/?mode=json&include=all" -o "$tmp/releases.json"
  local want
  want="$(jq -r --arg f "$file" '.[].files[] | select(.filename == $f) | .sha256' "$tmp/releases.json")"
  [[ -n "$want" ]] || { echo "provision.sh: no checksum for $file" >&2; exit 1; }
  curl -fsSL "https://go.dev/dl/$file" -o "$tmp/$file"
  echo "$want  $tmp/$file" | sha256sum -c --quiet
  rm -rf /usr/local/go
  tar -C /usr/local -xzf "$tmp/$file"
  rm -rf "$tmp"
}

install_rust() {
  local home
  home="$(getent passwd "$BUILD_USER" | cut -d: -f6)"
  [[ -x "$home/.cargo/bin/rustup" ]] && return 0
  local url=https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init
  sudo -u "$BUILD_USER" -H bash -euo pipefail -c '
    tmp="$(mktemp -d)"
    curl -fsSL "$1" -o "$tmp/rustup-init"
    want="$(curl -fsSL "$1.sha256" | cut -d" " -f1)"
    echo "$want  $tmp/rustup-init" | sha256sum -c --quiet
    chmod +x "$tmp/rustup-init"
    "$tmp/rustup-init" -y --no-modify-path --profile minimal --default-toolchain stable \
      --component clippy,rustfmt
    rm -rf "$tmp"
  ' _ "$url"
}

install_apt_packages
install_go
install_rust
echo "provision.sh: ok ($(/usr/local/go/bin/go env GOVERSION))"
