#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmux_option_or_fallback() {
	local option_value
	option_value="$(tmux show-option -gqv "$1")"
	if [ -z "$option_value" ]; then
		option_value="$2"
	fi
	echo "$option_value"
}

if [ `tmux_option_or_fallback "@sessionx-prefix" "on"` = "on"  ]; then
	tmux bind-key "$(tmux_option_or_fallback "@sessionx-bind" "O")" run-shell "$CURRENT_DIR/scripts/sessionx.sh"
else
	tmux bind-key -n "$(tmux_option_or_fallback "@sessionx-bind" "O")" run-shell "$CURRENT_DIR/scripts/sessionx.sh"
fi
