#!/usr/bin/env bash
# One-way managed main-profile sync. Stop guest Pi sessions before running.
set -euo pipefail
umask 077

[[ $# -le 1 ]] || { printf 'Usage: %s [lima-instance]\n' "$0" >&2; exit 1; }
instance=${1:-linux-dev}
[[ $instance =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]] || {
	printf 'Invalid Lima instance name.\n' >&2
	exit 1
}
# shellcheck source=../ai-agents/tools/lib.sh
source "$(dirname "$0")/../ai-agents/tools/lib.sh"
snapshot=$(mktemp -d)
remote_tmp=
cleanup() {
	rm -rf -- "$snapshot"
	if [[ -n $remote_tmp ]]; then
		limactl shell --workdir=/ "$instance" -- rm -rf -- "$remote_tmp" ||
			printf 'Warning: could not remove guest staging directory %s\n' "$remote_tmp" >&2
	fi
}
trap cleanup EXIT

collect_source() {
	local type=$1 path=$2 arg2=${3:-} source_file destination
	case "$path" in .pi/agent/*|.agents/skills/*) ;; *) return ;; esac
	# Credential stores must never enter this snapshot, even if misdeclared.
	case "$path" in
		.pi/agent/auth.json|.pi/agent/mcp-auth.json|.pi/agent/secrets|.pi/agent/secrets/*) return ;;
	esac
	[[ $type != home ]] || return 0
	source_file=$(resolve_target "$type" "$path" "$arg2")
	[[ -e $source_file ]] || {
		printf 'Missing managed source: %s\n' "$source_file" >&2
		exit 1
	}
	case "$type" in
		mirror) destination="configs/ai-agents/home/$path" ;;
		pmirror) destination="configs-private/home/$path" ;;
		repo) destination="configs/$arg2" ;;
		prepo) destination="configs-private/$arg2" ;;
		*) die "unsupported manifest type: $type" ;;
	esac
	mkdir -p "$snapshot/payload/$(dirname "$destination")"
	# Resolve managed links, but rebuild dependencies for Linux instead of copying them.
	rsync -aL --exclude=node_modules --exclude=.git --exclude=__pycache__ \
		"$source_file" "$snapshot/payload/$(dirname "$destination")/"
	# Freeze the sender's resolved projection; guest hostnames must not reselect it.
	printf '%s %s %s\n' "$type" "$path" "$arg2" >>"$snapshot/payload/configs/ai-agents/tools/manifest.txt"
}

mkdir -p "$snapshot/payload/configs/ai-agents/tools"
: >"$snapshot/payload/configs/ai-agents/tools/manifest.txt"
foreach_manifest collect_source
for name in apply.sh lib.sh; do
	cp "$TOOLS_DIR/$name" "$snapshot/payload/configs/ai-agents/tools/$name"
done
for name in settings.json models.json mcp.json; do
	while IFS= read -r file; do
		jq -e objects "$file" >/dev/null
	done < <(find "$snapshot/payload" -type f -name "$name")
done
tar -czf "$snapshot/config.tar.gz" -C "$snapshot/payload" .
# shellcheck disable=SC2016
remote_tmp=$(limactl shell --workdir=/ "$instance" -- bash -c '
	set -euo pipefail
	umask 077
	install -d -m 700 "$HOME/.local/state/pi-config-sync"
	mktemp -d "$HOME/.local/state/pi-config-sync/.incoming.XXXXXXXX"
')
limactl copy --backend=scp "$snapshot/config.tar.gz" "$instance:$remote_tmp/config.tar.gz"
limactl shell --workdir=/ "$instance" -- bash -s -- "$remote_tmp" "$HOME" <<'RECEIVER'
set -euo pipefail
umask 077
incoming=$1
host_home=$2
state="$HOME/.local/state/pi-config-sync"
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
export PI_CODING_AGENT_DIR="$HOME/.pi/agent"
exec 9>"$state/lock"
flock -n 9 || { printf 'Another Pi config sync is running.\n' >&2; exit 1; }
tar -xzf "$incoming/config.tar.gz" -C "$incoming"
rm "$incoming/config.tar.gz"

# Translate absolute home paths in JSON without touching arbitrary skill/source text.
while IFS= read -r file; do
	jq --arg host "$host_home/" --arg guest "$HOME/" \
		'walk(if type == "string" then split($host) | join($guest) else . end)' \
		"$file" >"$file.tmp"
	mv "$file.tmp" "$file"
done < <(find "$incoming" -type f -name '*.json' ! -name 'package*.json')
models="$incoming/configs/ai-agents/home/.pi/agent/models.json"
if [[ -f $models ]]; then
	guest_url=
	if [[ -f $HOME/.pi/agent/models.json ]]; then
		guest_url=$(jq -r '.providers.local.baseUrl // empty' "$HOME/.pi/agent/models.json")
	fi
	jq --arg url "$guest_url" '
		if .providers.local.baseUrl then
			.providers.local.baseUrl |= (if $url != "" then $url
			else sub("://localhost"; "://host.lima.internal")
			| sub("://127\\.0\\.0\\.1"; "://host.lima.internal") end)
		else . end' "$models" >"$models.tmp"
	mv "$models.tmp" "$models"
fi

while IFS= read -r lock; do
	directory=$(dirname "$lock")
	(cd "$directory" && timeout --kill-after=10s 180s npm ci --omit=dev --ignore-scripts --no-progress) \
		>"$state/npm-install.log" 2>&1 || {
		printf 'Extension dependency install failed; see %s/npm-install.log\n' "$state" >&2
		exit 1
	}
done < <(find "$incoming" -path '*/extensions/*/package-lock.json')
rm -rf -- "$state/previous"
if [[ -d $state/current ]]; then mv "$state/current" "$state/previous"; fi
mv "$incoming" "$state/current"
export PRIVATE_DIR="$state/current/configs-private"
bash "$state/current/configs/ai-agents/tools/apply.sh" --pi
bash "$state/current/configs/ai-agents/tools/apply.sh" --pi --verify
# Retire only dangling links owned by earlier snapshots, not guest-local resources.
for root in "$HOME/.pi/agent" "$HOME/.agents/skills"; do
	[[ -d $root ]] || continue
	while IFS= read -r -d '' link; do
		case $(readlink "$link") in
			"$state/current/"*) [[ -e $link ]] || rm -- "$link" ;;
		esac
	done < <(find "$root" -maxdepth 2 -type l -print0)
done
# Pi packages are installed on Linux, never copied from the Mac's npm cache.
(cd "$HOME" && timeout --kill-after=10s 180s pi update --extensions) >"$state/packages.log" 2>&1 || {
	printf 'Config deployed, but Pi package update failed; see %s/packages.log\n' "$state" >&2
	exit 1
}
RECEIVER
remote_tmp=
printf 'Synced managed Pi config, skills and extensions to %s. Restart guest Pi.\n' "$instance"
