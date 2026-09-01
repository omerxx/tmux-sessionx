#!/usr/bin/env bash

# Check if tmuxinator integration is enabled.
is_tmuxinator_enabled() {
	local tmuxinator_mode=$(tmux_option_or_fallback "@sessionx-tmuxinator-mode" "off")

	if [[ "$tmuxinator_mode" != "on" ]]; then
		return 1
	fi

	return 0
}

# Check if a given name matches a tmuxinator template.
is_tmuxinator_template() {
	tmuxinator list --newline | grep -q "^$1$"
}

# Generate the fzf keybind configuration for tmuxinator templates.
load_tmuxinator_binding() {
	local keybind="$(tmux_option_or_fallback "@sessionx-bind-tmuxinator-list" "ctrl-/")"

	printf "$keybind:reload(tmuxinator list --newline | sed '1d')+change-preview(cat ~/.config/tmuxinator/{}.yml 2>/dev/null)"
}
