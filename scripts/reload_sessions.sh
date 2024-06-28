#!/usr/bin/env bash
CURRENT_SESSION=$(tmux display-message -p '#S')

filter_current_session=$(tmux_option_or_fallback "@sessionx-filter-current" "true")
if [[ "$filter_current_session" == "true" ]]; then
	(tmux list-sessions | sed -E 's/:.*$//' | grep -v "$CURRENT_SESSION$") || echo "$CURRENT_SESSION"
else
	(tmux list-sessions | sed -E 's/:.*$//') || echo "$CURRENT_SESSION"
fi
