#!/usr/bin/env bash
# Ubuntu CLI environment. Leaves SSH identities and private integrations alone.
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
[[ $(uname -s) == Linux && $(uname -m) == aarch64 ]] || {
	printf 'This setup requires Ubuntu ARM64.\n' >&2
	exit 1
}
[[ $EUID -ne 0 ]] || {
	printf 'Run as the development user, not root.\n' >&2
	exit 1
}
# shellcheck source=/dev/null
source /etc/os-release
[[ $ID == ubuntu ]] || {
	printf 'This setup requires Ubuntu.\n' >&2
	exit 1
}

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:$PATH"
backup_dir="$HOME/.local/state/home-setup/$(date +%Y%m%d-%H%M%S)"

link() {
	local target=$1 destination=$2
	if [[ -L $destination && $(readlink "$destination") == "$target" ]]; then
		return
	fi
	if [[ -e $destination || -L $destination ]]; then
		local backup="$backup_dir/${destination#"$HOME/"}"
		[[ ! -e $backup && ! -L $backup ]] || {
			printf 'Backup exists: %s\n' "$backup" >&2
			exit 1
		}
		mkdir -p "$(dirname "$backup")"
		mv "$destination" "$backup"
	fi
	mkdir -p "$(dirname "$destination")"
	ln -s "$target" "$destination"
}

install_archive() {
	local name=$1 url=$2 digest=$3 executable=$4
	local destination="$HOME/.local/opt/$name"
	if [[ ! -x $destination/$executable ]]; then
		curl --fail --location --silent --show-error --max-time 180 "$url" -o "$staging/$name.tar.gz"
		printf '%s  %s\n' "$digest" "$staging/$name.tar.gz" | sha256sum --check --status
		mkdir -p "$staging/$name" "$(dirname "$destination")"
		tar -xzf "$staging/$name.tar.gz" --strip-components=1 -C "$staging/$name"
		[[ ! -e $destination ]] || {
			printf 'Incomplete install: %s\n' "$destination" >&2
			exit 1
		}
		mv "$staging/$name" "$destination"
	fi
	link "$destination/$executable" "$HOME/.local/bin/${executable##*/}"
}

sudo apt-get update -qq
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
	ca-certificates curl git gh openssh-client rsync tmux neovim zsh ripgrep fd-find jq \
	build-essential pkg-config libssl-dev git-delta git-lfs fzf direnv unzip \
	nodejs npm golang-go rustup tree-sitter-cli ncurses-term chromium-browser

staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
# Match the Mac's versions; digests come from the official GitHub release assets.
install_archive nvim-0.12.5 \
	https://github.com/neovim/neovim/releases/download/v0.12.5/nvim-linux-arm64.tar.gz \
	1aa5ca085249580ae0f91eb14f27ec0919773ff2d99a163d03f3d6c21ac29725 bin/nvim
install_archive uv-0.12.17 \
	https://github.com/astral-sh/uv/releases/download/0.12.17/uv-aarch64-unknown-linux-gnu.tar.gz \
	d636d1b678e9e7f367ecb22b46bd1cabbed234d6bc3b4d96365d2b507f72f86c uv
link "$HOME/.local/opt/uv-0.12.17/uvx" "$HOME/.local/bin/uvx"
link /usr/bin/fdfind "$HOME/.local/bin/fd"

# Lima appends to .zshrc on boot; keep those writes out of the Git checkout.
zsh_wrapper="$HOME/.config/zsh/home-setup.zsh"
if [[ ! -e $zsh_wrapper ]]; then
	mkdir -p "$(dirname "$zsh_wrapper")"
	printf 'source "%s/.zshrc"\n' "$repo" >"$zsh_wrapper"
fi
link "$zsh_wrapper" "$HOME/.zshrc"
for path in .zsh_prompt .gitconfig .gitignore .tmux.conf; do
	link "$repo/$path" "$HOME/$path"
done
link "$repo/nvim" "$HOME/.config/nvim"
for script in pi-lean runbg dos2unix; do
	link "$repo/bin/$script" "$HOME/bin/$script"
done

npm config set prefix "$HOME/.local"
npm install --global --ignore-scripts @earendil-works/pi-coding-agent@1.1.0
rustup set profile minimal
rustup default stable
rustup component add rust-analyzer rustfmt clippy
sudo usermod --shell /usr/bin/zsh "$(id -un)"

# Snap Chromium cannot write profiles under hidden home directories.
browser_profile="$HOME/snap/chromium/common/pi-profile"
legacy_profile="$HOME/.pi/agent/browser-read/profile"
if [[ -d $legacy_profile && ! -L $legacy_profile && ! -e $browser_profile ]]; then
	mkdir -p "$(dirname "$browser_profile")"
	mv "$legacy_profile" "$browser_profile"
fi
mkdir -p "$browser_profile"
link "$browser_profile" "$legacy_profile"

"$repo/ai-agents/tools/apply.sh"
"$repo/ai-agents/tools/install-extensions.sh"

state="$HOME/.local/state/home-setup"
mkdir -p "$state"
timeout --kill-after=10s 600s nvim --headless '+Lazy! restore' +qa >"$state/neovim-install.log" 2>&1
timeout --kill-after=10s 180s pi update --extensions >"$state/pi-packages.log" 2>&1
printf '\nInstalled CLI environment. Configure Pi login separately.\n'
printf 'Backups, if needed: %s\n' "$backup_dir"
