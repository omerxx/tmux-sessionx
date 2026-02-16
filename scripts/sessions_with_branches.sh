#!/usr/bin/env bash
# Git branch enrichment for tmux-sessionx.
# Without args: outputs full enriched list to stdout (for fzf reload).
# With a port arg: progressive reloads via fzf --listen API.

PORT="${1:-}"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/git-branch.sh"

CURRENT="$(tmux display-message -p '#S')"
eval $(tmux show-option -gqv @sessionx-_built-extra-options)

# Build sorted session list
last_session=$(tmux display-message -p '#{client_last_session}')
sessions=$(tmux list-sessions | sed -E 's/:.*$//' | grep -Fxv "$last_session")
filtered_sessions=${extra_options["filtered-sessions"]}
if [[ -n "$filtered_sessions" ]]; then
	filtered_and_piped=$(echo "$filtered_sessions" | sed -E 's/,/|/g')
	sessions=$(echo "$sessions" | grep -Ev "$filtered_and_piped")
fi
sorted=$(echo -e "$sessions\n$last_session" | awk '!seen[$0]++')

filter_current=${extra_options["filter-current"]}
if [[ "$filter_current" == "true" ]]; then
	filtered=$(echo "$sorted" | grep -Fxv "$CURRENT")
	if [[ -n "$filtered" ]]; then
		sorted="$filtered"
	else
		sorted="$CURRENT"
	fi
fi

# Custom paths (prepended before sessions)
custom_prefix=""
custom_paths=${extra_options["custom-paths"]}
if [[ -n "$custom_paths" ]]; then
	custom_path_subdirectories=${extra_options["custom-paths-subdirectories"]}
	clean_paths=$(echo "$custom_paths" | sed -E 's/ *, */,/g' | sed -E 's/^ *//' | sed -E 's/ *$//' | sed -E 's/ /✗/g')
	if [[ "$custom_path_subdirectories" == "true" ]]; then
		paths=$(find ${clean_paths//,/ } -mindepth 1 -maxdepth 1 -type d)
	else
		paths=${clean_paths//,/ }
	fi
	for path in $paths; do
		if ! grep -q "$(basename "$path")" <<< "$sorted"; then
			custom_prefix+="$path"$'\n'
		fi
	done
fi

if [[ -z "$PORT" ]]; then
	# Stdout mode: output full enriched list at once
	[[ -n "$custom_prefix" ]] && printf "%s" "$custom_prefix"
	format_sessions_with_git_branch "$sorted"
else
	# Progressive mode: resolve branches one by one, reload after each
	declare -a session_list=()
	declare -a branch_list=()
	while IFS= read -r session; do
		[[ -z "$session" ]] && continue
		session_list+=("$session")
		branch_list+=("")
	done <<< "$sorted"

	max_len=0
	for name in "${session_list[@]}"; do
		len=${#name}
		(( len > max_len )) && max_len=$len
	done

	TMPBASE="/tmp/sessionx-branches-$$"

	output_current_state() {
		[[ -n "$custom_prefix" ]] && printf "%s" "$custom_prefix"
		for ((j=0; j<${#session_list[@]}; j++)); do
			name="${session_list[$j]}"
			br="${branch_list[$j]}"
			if [[ -n "$br" ]]; then
				printf "%-${max_len}s  ${GIT_BRANCH_COLOR}${GIT_BRANCH_ICON} %s${GIT_BRANCH_RESET}\n" "$name" "$br"
			else
				printf "%s\n" "$name"
			fi
		done
	}

	sleep 0.1

	for ((i=0; i<${#session_list[@]}; i++)); do
		session="${session_list[$i]}"
		pane_path=$(tmux list-panes -t "$session" -F '#{pane_current_path}' 2>/dev/null | head -1)
		branch=""
		if [[ -n "$pane_path" ]]; then
			branch=$(git -C "$pane_path" branch --show-current 2>/dev/null)
		fi
		branch_list[$i]="$branch"

		if [[ -n "$branch" ]]; then
			tmpfile="${TMPBASE}-${i}"
			output_current_state > "$tmpfile"
			curl -s -XPOST "localhost:$PORT" \
				-d "reload-sync(cat $tmpfile; rm -f $tmpfile)" 2>/dev/null || exit 0
		fi
	done
fi
