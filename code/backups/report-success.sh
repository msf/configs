#!/usr/bin/env bash
# Records a successful backup job in VictoriaMetrics for the Grafana "Backups" dashboard.
# Best-effort: a monitoring outage must not fail a backup that already succeeded.
set -uo pipefail

job=${1:?usage: report-success.sh <job>}
vm_import_url=http://localhost:8428/api/v1/import/prometheus
repo_dataset=simple/restic

metrics="backup_last_success_timestamp_seconds{job=\"$job\"} $(date +%s)"
if repo_bytes=$(zfs get -Hp -o value used "$repo_dataset"); then
  metrics+=$'\n'"backup_repo_bytes $repo_bytes"
fi

# The here-string adds the trailing newline; without it VictoriaMetrics drops the last line.
if ! curl -fsS -m 10 --data-binary @- "$vm_import_url" <<<"$metrics"; then
  echo "report-success: could not record $job in VictoriaMetrics" >&2
fi
exit 0
