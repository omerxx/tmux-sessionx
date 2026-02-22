#!/usr/bin/env bash
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CURRENT_DIR/git-branch.sh"

CURRENT_SESSION=$(tmux display-message -p '#S')
SESSIONS=$(tmux list-sessions | sed -E 's/:.*$//')

if [[ $(echo "$SESSIONS" | wc -l) -gt 1 ]]; then
	SESSIONS=$(echo "$SESSIONS" | grep -v "$CURRENT_SESSION")
else
	true
fi

GIT_BRANCH=$(tmux show-option -gqv "@sessionx-git-branch")
if [[ "$GIT_BRANCH" == "on" ]]; then
	format_sessions_with_git_branch "$SESSIONS"
else
	echo "$SESSIONS"
fi
