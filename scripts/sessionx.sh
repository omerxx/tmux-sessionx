#!/usr/bin/env bash

CURRENT="$(tmux display-message -p '#S')"

input() {
    (tmux list-sessions | sed -E 's/:.*$//' | grep -v "$CURRENT") || echo "$CURRENT"
}

tmux_option_or_fallback() {
	local option_value
	option_value="$(tmux show-option -gqv "$1")"
	if [ -z "$option_value" ]; then
		option_value="$2"
	fi
	echo "$option_value"
}

handle_output() {
    target=$(echo "$1" | tr -d '\n')
    if [[ -z "$target" ]]; then
        exit 0
    fi
    if ! tmux has-session -t="$target" 2> /dev/null; then
        if test -d "$target"; then
            tmux new-session -ds "${target##*/}" -c "$target"
            target="${target##*/}"
        else
            tmux new-session -ds "$target"
        fi
    fi
    tmux switch-client -t "$target"
}

BIND_CTRL_D="ctrl-d:execute(tmux kill-session -t {})+reload(tmux list-sessions | sed -E 's/:.*$//' | grep -v $(tmux display-message -p '#S'))"
BIND_CTRL_W="ctrl-w:reload(tmux list-windows -a -F '#{session_name}:#{window_name}')+change-preview(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh -w {} | bat --style plain)"
BIND_CTRL_O="ctrl-o:print-query+execute(tmux new-session -d -s {})"
CTRL_X_PATH=$(tmux_option_or_fallback "@sessionx-x-path" "$HOME/.config")
BIND_CTRL_X="ctrl-x:reload(find $CTRL_X_PATH -mindepth 1 -maxdepth 1 -type d)"
BIND_ENTER="enter:replace-query+print-query"
BIND_CTRL_R='ctrl-r:execute(printf >&2 "New name: ";read name; tmux rename-session -t {} ${name};)+reload(tmux list-sessions | sed -E "s/:.*$//")'

RESULT=$(input | \
    fzf-tmux \
        -p "75%,75%" \
	--prompt " " \
        --header='󰿄=go C-d=del C-r=rename C-x=custom C-w=window-mode' \
	--print-query \
        --border-label "Current session: \"$CURRENT\" " \
        --bind "$BIND_CTRL_D" \
        --bind "$BIND_CTRL_O" \
        --bind "$BIND_CTRL_X" \
        --bind "$BIND_CTRL_R" \
        --bind "$BIND_CTRL_W" \
        --bind "$BIND_ENTER" \
        --exit-0 \
        --preview="${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh {} | bat --style plain" \
        --preview-window=",55%,,") 

handle_output "$RESULT"
