#!/usr/bin/env bash

GIT_BRANCH_COLOR=$'\033[38;2;137;180;250m'
GIT_BRANCH_RESET=$'\033[0m'
GIT_BRANCH_ICON=""

format_sessions_with_git_branch() {
	local sessions="$1"
	local -a session_list=()
	local -a branch_list=()
	local max_len=0

	while IFS= read -r session; do
		[[ -z "$session" ]] && continue
		session_list+=("$session")
		local pane_path
		pane_path=$(tmux list-panes -t "$session" -F '#{pane_current_path}' 2>/dev/null | head -1)
		local branch=""
		if [[ -n "$pane_path" ]]; then
			branch=$(git -C "$pane_path" branch --show-current 2>/dev/null)
		fi
		branch_list+=("$branch")
		local len=${#session}
		(( len > max_len )) && max_len=$len
	done <<< "$sessions"

	for ((j=0; j<${#session_list[@]}; j++)); do
		local name="${session_list[$j]}"
		local branch="${branch_list[$j]}"
		if [[ -n "$branch" ]]; then
			printf "%-${max_len}s  ${GIT_BRANCH_COLOR}${GIT_BRANCH_ICON} %s${GIT_BRANCH_RESET}\n" "$name" "$branch"
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
