#!/usr/bin/env bash
# Copy credential stores only. Stop guest Pi sessions before running this script.
set -euo pipefail
umask 077

[[ $# -le 1 ]] || {
	printf 'Usage: %s [lima-instance]\n' "$0" >&2
	exit 1
}
instance=${1:-linux-dev}
[[ $instance =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]] || {
	printf 'Invalid Lima instance name.\n' >&2
	exit 1
}

snapshot=$(mktemp -d)
remote_tmp=
cleanup() {
	rm -rf -- "$snapshot"
	if [[ -n $remote_tmp ]]; then
		# Cleanup is best-effort if the VM disconnected during the transfer.
		limactl shell --workdir=/ "$instance" -- rm -f -- "$remote_tmp" ||
			printf 'Warning: could not remove guest temporary file %s\n' "$remote_tmp" >&2
	fi
}
trap cleanup EXIT

files=()
for name in auth.json mcp-auth.json; do
	source_file="$HOME/.pi/agent/$name"
	[[ -f $source_file ]] || continue
	cp "$source_file" "$snapshot/$name"
	chmod 600 "$snapshot/$name"
	if ! jq -e objects "$snapshot/$name" >/dev/null 2>&1; then
		printf 'Invalid credential JSON: %s\n' "$source_file" >&2
		exit 1
	fi
	files+=("$name")
done
[[ ${#files[@]} -gt 0 ]] || {
	printf 'No Pi credential stores found.\n' >&2
	exit 1
}

for name in "${files[@]}"; do
	# Expand HOME and positional arguments in the guest, not on macOS.
	# shellcheck disable=SC2016
	remote_tmp=$(limactl shell --workdir=/ "$instance" -- bash -c '
		set -euo pipefail
		umask 077
		install -d -m 700 "$HOME/.pi/agent"
		if [[ -L "$HOME/.pi/agent/$1" ]]; then
			printf "Refusing to replace a credential symlink: %s\n" "$1" >&2
			exit 1
		fi
		mktemp "$HOME/.pi/agent/.auth-sync.XXXXXXXX"
	' -- "$name")
	limactl copy --backend=scp "$snapshot/$name" "$instance:$remote_tmp"
	# Expand HOME and positional arguments in the guest, not on macOS.
	# shellcheck disable=SC2016
	limactl shell --workdir=/ "$instance" -- bash -c '
		set -euo pipefail
		if ! jq -e objects "$1" >/dev/null 2>&1; then
			printf "Invalid transferred credential JSON.\n" >&2
			exit 1
		fi
		chmod 600 "$1"
		mv -f -- "$1" "$HOME/.pi/agent/$2"
	' -- "$remote_tmp" "$name"
	remote_tmp=
	printf 'Synced %s to %s (0600).\n' "$name" "$instance"
done
printf 'Restart Pi in the VM to use the copied credentials.\n'
