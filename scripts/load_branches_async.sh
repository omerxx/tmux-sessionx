#!/usr/bin/env bash
# Progressive branch loading for tmux-sessionx.
# Takes the fzf --listen port as argument.
# Resolves branches one by one and triggers a reload after each discovery,
# so session names stay visible while branches appear progressively.

PORT="$1"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/git-branch.sh"

CURRENT="$(tmux display-message -p '#S')"
eval $(tmux show-option -gqv @sessionx-_built-extra-options)

# Get sorted sessions (same logic as get_sorted_sessions in sessionx.sh)
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

# Collect custom paths
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

# Build session array
declare -a session_list=()
declare -a branch_list=()

while IFS= read -r session; do
	[[ -z "$session" ]] && continue
	session_list+=("$session")
	branch_list+=("")
done <<< "$sorted"

# Pre-compute max name length (instant, no git operations)
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

# Wait for fzf to be ready
sleep 0.1

# Resolve branches one by one, trigger reload after each discovery
for ((i=0; i<${#session_list[@]}; i++)); do
	session="${session_list[$i]}"
	pane_path=$(tmux list-panes -t "$session" -F '#{pane_current_path}' 2>/dev/null | head -1)
	branch=""
	if [[ -n "$pane_path" ]]; then
		branch=$(git -C "$pane_path" branch --show-current 2>/dev/null)
	fi
	branch_list[$i]="$branch"

	# Only trigger reload when a branch is found (visible change)
	if [[ -n "$branch" ]]; then
		tmpfile="${TMPBASE}-${i}"
		output_current_state > "$tmpfile"
		curl -s -XPOST "localhost:$PORT" \
			-d "reload-sync(cat $tmpfile; rm -f $tmpfile)" 2>/dev/null || exit 0
	fi
done
