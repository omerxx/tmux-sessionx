#!/usr/bin/env bash

is_tmuxinator_enabled() {
	local tmuxinator_mode=$(tmux_option_or_fallback "@sessionx-tmuxinator-mode" "off")

	if [[ "$tmuxinator_mode" != "on" ]]; then
		return 1
	fi

	return 0
}

is_tmuxinator_template() {
	tmuxinator list --newline | grep -q "^$1$"
}

load_tmuxinator_binding() {
	local keybind="$(tmux_option_or_fallback "@sessionx-bind-tmuxinator-list" "ctrl-/")"

	printf "$keybind:reload(tmuxinator list --newline | sed '1d')+change-preview(cat ~/.config/tmuxinator/{}.yml 2>/dev/null)"
}
