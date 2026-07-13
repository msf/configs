#!/usr/bin/env bash
# pr-triage queue builder.
# Emits a JSON array of PRs needing review, ranked.
#
# Usage: queue.sh [--debug]
#   --debug prints intermediate counts to stderr.

set -euo pipefail

# Org/team identity lives in a local config, not in this script:
#   ~/.config/pr-triage.conf   (override path via PR_TRIAGE_CONF)
# Expected shell-variable assignments: ORG, ME, TEAM, optionally STALE_DAYS.
CONF="${PR_TRIAGE_CONF:-$HOME/.config/pr-triage.conf}"
[[ -r "$CONF" ]] || { echo "error: missing config $CONF (needs ORG, ME, TEAM)" >&2; exit 1; }
# shellcheck source=/dev/null
source "$CONF"
: "${ORG:?set in $CONF}" "${ME:?set in $CONF}" "${TEAM:?set in $CONF}"
STALE_DAYS="${STALE_DAYS:-21}"

DEBUG=0
[[ "${1:-}" == "--debug" ]] && DEBUG=1
log() { [[ "$DEBUG" == 1 ]] && echo "[queue] $*" >&2 || true; }

# Team members (excluding me).
mapfile -t TEAM_MEMBERS < <(
  gh api "/orgs/$ORG/teams/$TEAM/members" --jq '.[].login' \
    | grep -vx "$ME"
)
log "team members: ${TEAM_MEMBERS[*]}"

# 1. Assigned to me.
ASSIGNED_ME=$(
  gh search prs --owner="$ORG" --state=open --review-requested=@me \
    --json number,title,repository,author,url,updatedAt,isDraft --limit 100
)

# 2. Assigned to team.
ASSIGNED_TEAM=$(
  gh search prs --owner="$ORG" --state=open \
    --review-requested="$ORG/$TEAM" \
    --json number,title,repository,author,url,updatedAt,isDraft --limit 100
)

# 3. Authored by teammates.
AUTHORED="[]"
for u in "${TEAM_MEMBERS[@]}"; do
  chunk=$(
    gh search prs --owner="$ORG" --state=open --author="$u" \
      --json number,title,repository,author,url,updatedAt,isDraft --limit 100
  )
  AUTHORED=$(jq -s 'add' <(echo "$AUTHORED") <(echo "$chunk"))
done

# Tag each batch with a source, then merge.
TAGGED=$(
  jq -s --arg me "$ME" '
    def tag(s): map(. + {source: s});
    (.[0] | tag("assigned"))
      + (.[1] | tag("assigned"))
      + (.[2] | tag("team"))
    | map(select(.isDraft == false))
    | map(select(.author.login != $me))
    | unique_by([.repository.nameWithOwner, .number])
      # assigned wins over team on dedup: sort so assigned is first before unique_by.
  ' <(echo "$ASSIGNED_ME") <(echo "$ASSIGNED_TEAM") <(echo "$AUTHORED")
)
log "raw candidates: $(echo "$TAGGED" | jq length)"

# jq's unique_by is stable on sort order; re-tag by giving assigned precedence.
# Approach: for each (repo, number), pick the entry with source=assigned if any.
MERGED=$(
  echo "$TAGGED" | jq '
    group_by([.repository.nameWithOwner, .number])
    | map(
        (map(select(.source == "assigned")) | first)
        // .[0]
      )
  '
)

# Enrich: compute ageDays, fetch my review state per PR.
NOW_EPOCH=$(date +%s)
ENRICHED="[]"
while IFS= read -r row; do
  repo=$(echo "$row" | jq -r '.repository.nameWithOwner')
  num=$(echo "$row" | jq -r '.number')
  updated=$(echo "$row" | jq -r '.updatedAt')
  updated_epoch=$(date -d "$updated" +%s)
  age_days=$(( (NOW_EPOCH - updated_epoch) / 86400 ))

  # My latest review state on this PR (APPROVED, CHANGES_REQUESTED, COMMENTED, or empty).
  my_state=$(
    gh api "repos/$repo/pulls/$num/reviews" --paginate \
      --jq "[.[] | select(.user.login==\"$ME\")] | last | .state // \"\""
  ) || my_state=""

  # Is a review still pending from me or the team?
  pending=$(
    gh api "repos/$repo/pulls/$num/requested_reviewers" \
      --jq "(.users // []) | map(.login) | index(\"$ME\") != null" 2>/dev/null \
      || echo "false"
  )
  pending_team=$(
    gh api "repos/$repo/pulls/$num/requested_reviewers" \
      --jq "(.teams // []) | map(.slug) | index(\"$TEAM\") != null" 2>/dev/null \
      || echo "false"
  )
  re_requested="false"
  [[ "$pending" == "true" || "$pending_team" == "true" ]] && re_requested="true"

  entry=$(echo "$row" | jq \
    --argjson age "$age_days" \
    --arg state "$my_state" \
    --argjson rereq "$re_requested" \
    '. + {ageDays: $age, myReviewState: $state, reRequested: $rereq}'
  )
  ENRICHED=$(jq -s 'add' <(echo "$ENRICHED") <(echo "[$entry]"))
done < <(echo "$MERGED" | jq -c '.[]')

# Filter: drop PRs already approved/changes-requested by me unless re-requested.
FILTERED=$(
  echo "$ENRICHED" | jq '
    map(select(
      (.myReviewState == "APPROVED" or .myReviewState == "CHANGES_REQUESTED") | not
      or .reRequested
    ))
  '
)

# Split fresh vs stale.
FRESH=$(echo "$FILTERED" | jq --argjson stale "$STALE_DAYS" 'map(select(.ageDays <= $stale))')
STALE=$(echo "$FILTERED" | jq --argjson stale "$STALE_DAYS" 'map(select(.ageDays > $stale))')

# Rank fresh: assigned first, then oldest updatedAt, then repo.
RANKED_FRESH=$(
  echo "$FRESH" | jq '
    sort_by(
      (if .source == "assigned" then 0 else 1 end),
      .updatedAt,
      .repository.nameWithOwner
    )
  '
)
RANKED_STALE=$(
  echo "$STALE" | jq 'sort_by(.updatedAt)'
)

log "fresh: $(echo "$RANKED_FRESH" | jq length), stale: $(echo "$RANKED_STALE" | jq length)"

jq -n --argjson fresh "$RANKED_FRESH" --argjson stale "$RANKED_STALE" \
  '{fresh: $fresh, stale: $stale}'
