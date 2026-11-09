#!/bin/sh
# Installs managed Brave policy (needs root) and the user desktop override.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
sudo install -D -m 0644 "$here/policy.json" /etc/brave/policies/managed/declarative.json
mkdir -p "$HOME/.local/share/applications"
sed "s|^Exec=/usr/bin/brave-browser-stable|Exec=$HOME/bin/brave|" \
  /usr/share/applications/brave-browser.desktop \
  > "$HOME/.local/share/applications/brave-browser.desktop"
