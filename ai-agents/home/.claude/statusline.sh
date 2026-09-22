#!/usr/bin/env bash
# Claude Code status line mirroring Pi's context-meter footer:
#
#   <cwd> (<branch>) [• <session-name>]
#   $0.918 (sub)  28k/272k 9%                            <model> • <effort>
#
# Context tiers match context-meter.ts and are relative to the model's window.

set -u
export LC_NUMERIC=C

sep=$'\x1f'
IFS="$sep" read -r cwd session_name cost subscribed ctx_tokens ctx_window ctx_percent model effort < <(
	jq -r --arg sep "$sep" '[
		.workspace.current_dir // .cwd // "",
		.session_name // "",
		.cost.total_cost_usd // 0,
		(if .rate_limits then "1" else "" end),
		(.context_window.total_input_tokens // 0),
		(.context_window.context_window_size // 0),
		(.context_window.used_percentage // "" | tostring),
		.model.id // "no-model",
		(if .effort.level then .effort.level
		 elif .thinking.enabled == false then "thinking off"
		 else "" end)
	] | map(tostring) | join($sep)'
)

RESET=$'\e[0m'
sgr() { printf '\e[%sm%s%s' "$1" "$2" "$RESET"; }
dim() { sgr 90 "$1"; }

tier_codes() {
	local percent=$1
	if ((percent < 50)); then echo 32
	elif ((percent < 70)); then echo '1;93'
	elif ((percent < 85)); then echo '30;103'
	elif ((percent < 100)); then echo '1;97;41'
	else echo '1;5;97;41'
	fi
}

fmt_tokens() {
	local count=$1
	if ((count < 1000)); then printf '%d' "$count"
	elif ((count < 10000)); then printf '%.1fk' "${count}e-3"
	elif ((count < 1000000)); then printf '%.0fk' "${count}e-3"
	elif ((count < 10000000)); then printf '%.1fM' "${count}e-6"
	else printf '%.0fM' "${count}e-6"
	fi
}

# ----- line 1: cwd (branch) • session -----
location=${cwd/#$HOME/\~}
branch=$(git -C "$cwd" symbolic-ref --short -q HEAD 2>/dev/null ||
	git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
[[ -n $branch ]] && location+=" ($branch)"
[[ -n $session_name ]] && location+=" • $session_name"

# ----- line 2: cost + context meter (left), model • effort (right) -----
cost_text=$(printf '$%.3f' "$cost")
[[ -n $subscribed ]] && cost_text+=" (sub)"

if [[ -z $ctx_percent || $ctx_percent == null || $ctx_tokens -eq 0 ]]; then
	ctx_text="[ctx —/$(fmt_tokens "$ctx_window")]"
	ctx_rendered=$(dim "$ctx_text")
else
	ctx_text=" $(fmt_tokens "$ctx_tokens")/$(fmt_tokens "$ctx_window") $(printf '%.0f' "$ctx_percent")% "
	ctx_rendered=$(sgr "$(tier_codes "${ctx_percent%.*}")" "$ctx_text")
fi

right_text=$model
[[ -n $effort ]] && right_text+=" • $effort"

left_plain="$cost_text $ctx_text"
width=${COLUMNS:-80}
pad=$((width - ${#left_plain} - ${#right_text}))
((pad < 2)) && pad=2

printf '%s\n' "$(dim "$location")"
printf '%s%s%s%s\n' "$(dim "$cost_text ")" "$ctx_rendered" "$(dim "$(printf '%*s' "$pad" '')")" "$(dim "$right_text")"
