#!/usr/bin/env bash
CURRENT_SESSION=$(tmux display-message -p '#S')
SESSIONS=$(tmux list-sessions | sed -E 's/:.*$//')

if [[ $(echo "$SESSIONS" | wc -l) -gt 1 ]]; then
	SESSIONS=$(echo "$SESSIONS" | grep -v "$CURRENT_SESSION")
else
	true
fi

GIT_BRANCH=$(tmux show-option -gqv "@sessionx-git-branch")
if [[ "$GIT_BRANCH" == "on" ]]; then
	while IFS= read -r session; do
		if [[ -z "$session" ]]; then
			continue
		fi
		pane_path=$(tmux list-panes -t "$session" -F '#{pane_current_path}' 2>/dev/null | head -1)
		if [[ -n "$pane_path" ]]; then
			branch=$(git -C "$pane_path" branch --show-current 2>/dev/null)
			if [[ -n "$branch" ]]; then
				echo "$session  $branch"
				continue
			fi
		fi
		echo "$session"
	done <<< "$SESSIONS"
else
	echo "$SESSIONS"
fi
