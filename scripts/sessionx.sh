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

RESULT=$(input | \
    fzf-tmux \
        -p "55%,55%" \
	--prompt "(current:\"$CURRENT\")  " \
        --header=' ^-d=delete ^-w=workspaces enter=switch/create' \
	--print-query \
        --bind "ctrl-d:execute(tmux kill-session -t {})+reload(tmux list-sessions | sed -E 's/:.*$//' | grep -v $(tmux display-message -p '#S'))" \
        --bind "ctrl-o:print-query+execute(tmux new-session -d -s {})" \
        --bind "ctrl-w:reload(find ~/Documents '~/Documents/Obsidian\ Vault' -mindepth 1 -maxdepth 1 -type d)" \
        --bind "ctrl-x:reload(find ~/dotfiles -mindepth 1 -maxdepth 1 -type d)" \
        --bind=enter:replace-query+print-query \
        --exit-0 \
        --preview='tmux-prev {} | bat --theme TwoDark --style plain')

handle_output "$RESULT"
