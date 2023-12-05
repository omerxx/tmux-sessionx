#!/usr/bin/env bash

CURRENT="$(tmux display-message -p '#S')"

input() {
    (tmux list-sessions | sed -E 's/:.*$//' | grep -v "$CURRENT") || echo "$CURRENT"
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
BIND_CTRL_O="ctrl-o:print-query+execute(tmux new-session -d -s {})"
BIND_CTRL_N="ctrl-n:reload(find ~/notes)"
BIND_CTRL_X="ctrl-x:reload(find ~/dotfiles -mindepth 1 -maxdepth 1 -type d)"
BIND_ENTER="enter:replace-query+print-query"

RESULT=$(input | \
    fzf-tmux \
        -p "55%,55%" \
	--prompt " " \
        --header=' C-d=del C-n=notes C-x=config 󰿄=switch/create' \
	--print-query \
        --border-label "Current session: \"$CURRENT\" " \
        --bind "$BIND_CTRL_D" \
        --bind "$BIND_CTRL_O" \
        --bind "$BIND_CTRL_N" \
        --bind "$BIND_CTRL_X" \
        --bind "$BIND_ENTER" \
        --exit-0 \
        --preview='tmux-prev {} | bat --theme TwoDark --style plain')

handle_output "$RESULT"
