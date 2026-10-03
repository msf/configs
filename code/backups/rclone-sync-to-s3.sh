#!/usr/bin/env bash
# Mirror the local restic repo to R2. restic files are content-addressed and
# never modified, so comparing sizes is enough; it avoids a HEAD per object.
set -euo pipefail

repo=/media/simple/restic/mfilipe-backups
remote=cloudflare-r2-backups:backups/restic

# sync deletes remote files missing locally: never mirror an empty or unmounted repo.
for entry in config keys index snapshots data; do
  if [[ ! -e $repo/$entry ]]; then
    echo "refusing to sync: $repo is not a restic repo (missing $entry)" >&2
    exit 1
  fi
done

progress=()
if [[ -t 1 ]]; then
  progress=(--progress)
fi

rclone sync --size-only --fast-list "${progress[@]}" "$repo" "$remote"
