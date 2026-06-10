#!/usr/bin/env bash

GIT_BRANCH_COLOR=$'\033[38;2;137;180;250m'
GIT_BRANCH_RESET=$'\033[0m'
GIT_BRANCH_ICON=""
GIT_TAG_ICON=""

format_sessions_with_git_branch() {
	local sessions="$1"
	local -a session_list=()
	local -a ref_list=()
	local -a icon_list=()
	local max_len=0

	while IFS= read -r session; do
		[[ -z "$session" ]] && continue
		session_list+=("$session")
		local pane_path
		pane_path=$(tmux list-panes -t "$session" -F '#{pane_current_path}' 2>/dev/null | head -1)
		local ref=""
		local icon="$GIT_BRANCH_ICON"
		if [[ -n "$pane_path" ]]; then
			ref=$(git -C "$pane_path" branch --show-current 2>/dev/null)
			if [[ -z "$ref" ]]; then
				ref=$(git -C "$pane_path" describe --tags --exact-match 2>/dev/null)
				[[ -n "$ref" ]] && icon="$GIT_TAG_ICON"
			fi
		fi
		ref_list+=("$ref")
		icon_list+=("$icon")
		local len=${#session}
		(( len > max_len )) && max_len=$len
	done <<< "$sessions"

	for ((j=0; j<${#session_list[@]}; j++)); do
		local name="${session_list[$j]}"
		local ref="${ref_list[$j]}"
		local icon="${icon_list[$j]}"
		if [[ -n "$ref" ]]; then
			printf "%-${max_len}s  ${GIT_BRANCH_COLOR}${icon} %s${GIT_BRANCH_RESET}\n" "$name" "$ref"
		else
			printf "%s\n" "$name"
		fi
	done
}

strip_git_branch_info() {
	local ESC
	ESC=$(printf '\033')
	echo "$1" | sed "s/${ESC}\[[0-9;]*m//g" | sed "s/[[:space:]]* .*//" | sed 's/[[:space:]]*$//'
}
