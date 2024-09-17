#!/usr/bin/env bash
CURRENT_SESSION=$(tmux display-message -p '#S')
SESSIONS=$(tmux list-sessions | sed -E 's/:.*$//')

if [[ $(echo "$SESSIONS" | wc -l) -gt 1 ]]; then
	echo "$SESSIONS" | grep -v "$CURRENT_SESSION"
else
	echo "$SESSIONS"
fi

