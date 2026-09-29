#!/bin/bash
# link-dotfiles.sh — link the macOS-compatible subset of this repository into $HOME.
#
#   macos/link-dotfiles.sh            # link; back up anything displaced
#   macos/link-dotfiles.sh --dry-run  # print what would change
#
# Idempotent. A displaced file or directory is moved to <path>.bak.<timestamp>.
# Agent resources are separate: ai-agents/tools/apply.sh.
# Linux-only configs (sway, xmonad, awesome, wmii, X11, alacritty,
# power/fan scripts) are deliberately not listed.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
TS=$(date +%Y%m%d-%H%M%S)
DRY_RUN=0
[[ ${1:-} == --dry-run ]] && DRY_RUN=1

# <path relative to $HOME>  <path relative to repo>
LINKS="
.zshrc                              .zshrc
.zsh_prompt                         .zsh_prompt
.gitconfig                          .gitconfig
.tmux.conf                          .tmux.conf
.config/ghostty/config              ghostty/config
.config/nvim                        nvim
.config/kitty/kitty.conf            kitty/kitty.conf
bin/claude.sh                       bin/claude.sh
bin/dos2unix                        bin/dos2unix
bin/finddup.pl                      bin/finddup.pl
bin/fio-bench-randrw.sh             bin/fio-bench-randrw.sh
bin/fio-bench-reads.sh              bin/fio-bench-reads.sh
bin/gog                             bin/gog
bin/percentiles.py                  bin/percentiles.py
bin/pi-lean                         bin/pi-lean
bin/prs                             bin/prs
bin/runbg                           bin/runbg
bin/strip-conflict.sh               bin/strip-conflict.sh
bin/ytmusic                         bin/ytmusic
bin/ytvid                           bin/ytvid
"

run() {
	if ((DRY_RUN)); then echo "would: $*"; else "$@"; fi
}

while read -r rel target; do
	[[ -z $rel ]] && continue
	h=$HOME/$rel
	t=$REPO/$target
	if [[ ! -e $t ]]; then
		echo "MISSING source $t" >&2
		exit 1
	fi
	if [[ -L $h && $(readlink -- "$h") == "$t" ]]; then
		continue
	fi
	if [[ -e $h || -L $h ]]; then
		echo "backup $h -> $h.bak.$TS"
		run mv -- "$h" "$h.bak.$TS"
	fi
	run mkdir -p -- "$(dirname "$h")"
	echo "link   $h -> $t"
	run ln -s -- "$t" "$h"
done <<<"$LINKS"

# SSH: ~/.ssh/config is machine-local; create it only if absent. Private host
# blocks go in ~/.ssh/config.d/ (never in Git). Both Includes are top-level so
# host blocks are read before the shared `Host *` defaults.
ssh_cfg=$HOME/.ssh/config
include="Include $REPO/ssh/common.conf"
run mkdir -p -m 700 "$HOME/.ssh/cm" "$HOME/.ssh/config.d"
if [[ ! -e $ssh_cfg ]]; then
	echo "create $ssh_cfg"
	if ((!DRY_RUN)); then
		printf '# Machine-local. Private Host blocks: ~/.ssh/config.d/\n\nInclude ~/.ssh/config.d/*\n%s\n' "$include" >"$ssh_cfg"
		chmod 600 "$ssh_cfg"
	fi
elif ! grep -qxF "$include" "$ssh_cfg"; then
	echo "NOTE: $ssh_cfg exists without '$include'; add it manually before any Host line." >&2
fi
