#!/usr/bin/env bash
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

# Filter current session if configured
filter_current=${extra_options["filter-current"]}
if [[ "$filter_current" == "true" ]]; then
	filtered=$(echo "$sorted" | grep -Fxv "$CURRENT")
	if [[ -n "$filtered" ]]; then
		sorted="$filtered"
	else
		sorted="$CURRENT"
	fi
fi

# Handle custom paths (additional input, prepended before sessions)
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
			echo "$path"
		fi
	done
fi

# Output enriched sessions with git branches
format_sessions_with_git_branch "$sorted"
