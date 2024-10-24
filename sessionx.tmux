#!/usr/bin/env bash

# vi: sw=4 ts=4 noet

CURRENT_DIR="$(realpath "$(dirname "$0")")"
SCRIPTS_DIR="$CURRENT_DIR/scripts"

source "scripts/*"

tmux_option_or_fallback() {
    local option_value
    option_value="$(tmux show-option -gqv "$1")"
    if [ -z "$option_value" ]; then
        option_value="$2"
    fi
    echo "$option_value"
}

preview_settings() {
    default_window_mode=$(tmux_option_or_fallback "@sessionx-window-mode" "off")
    if [[ "$default_window_mode" == "on" ]]; then
        PREVIEW_OPTIONS="-w"
    fi
    default_window_mode=$(tmux_option_or_fallback "@sessionx-tree-mode" "off")
    if [[ "$default_window_mode" == "on" ]]; then
        PREVIEW_OPTIONS="-t"
    fi
    preview_location=$(tmux_option_or_fallback "@sessionx-preview-location" "top")
    preview_ratio=$(tmux_option_or_fallback "@sessionx-preview-ratio" "75%")
    preview_enabled=$(tmux_option_or_fallback "@sessionx-preview-enabled" "true")
}

window_settings() {
    layout_mode=$(tmux_option_or_fallback "@sessionx-layout" "default")
    prompt_icon=$(tmux_option_or_fallback "@sessionx-prompt" " ")
    pointer_icon=$(tmux_option_or_fallback "@sessionx-pointer" "▶")
}

handle_binds() {
    bind_tree_mode=$(tmux_option_or_fallback "@sessionx-bind-tree-mode" "ctrl-t")
    bind_window_mode=$(tmux_option_or_fallback "@sessionx-bind-window-mode" "ctrl-w")
    bind_configuration_mode=$(tmux_option_or_fallback "@sessionx-bind-configuration-path" "ctrl-x")
    bind_rename_session=$(tmux_option_or_fallback "@sessionx-bind-rename-session" "ctrl-r")

    bind_back=$(tmux_option_or_fallback "@sessionx-bind-back" "ctrl-b")
    bind_new_window=$(tmux_option_or_fallback "@sessionx-bind-new-window" "ctrl-e")
    bind_zo=$(tmux_option_or_fallback "@sessionx-bind-zo-new-window" "ctrl-f")
    bind_kill_session=$(tmux_option_or_fallback "@sessionx-bind-kill-session" "alt-bspace")

    bind_exit=$(tmux_option_or_fallback "@sessionx-bind-abort" "esc")
    bind_accept=$(tmux_option_or_fallback "@sessionx-bind-accept" "enter")
    bind_delete_char=$(tmux_option_or_fallback "@sessionx-bind-delete-char" "bspace")

    bind_scroll_up=$(tmux_option_or_fallback "@sessionx-bind-scroll-up" "ctrl-u")
    bind_scroll_down=$(tmux_option_or_fallback "@sessionx-bind-scroll-down" "ctrl-d")

    bind_select_up=$(tmux_option_or_fallback "@sessionx-bind-select-up" "ctrl-n")
    bind_select_down=$(tmux_option_or_fallback "@sessionx-bind-select-down" "ctrl-p")
}

build_args() {
    handle_binds
    window_settings
    preview_settings

    Z_MODE=$(tmux_option_or_fallback "@sessionx-zoxide-mode" "off")
    LS_COMMAND=$(tmux_option_or_fallback "@sessionx-ls-command" "ls")

    CONFIGURATION_PATH=$(realpath $(tmux_option_or_fallback "@sessionx-x-path" "$HOME/.config"))

    TREE_MODE="$bind_tree_mode:change-preview($SCRIPTS_DIR/preview.sh -t {1})"
    CONFIGURATION_MODE="$bind_configuration_mode:reload(find $CONFIGURATION_PATH -mindepth 1 -maxdepth 1 -type d -o -type l)+change-preview($LS_COMMAND {})"
    WINDOWS_MODE="$bind_window_mode:reload(tmux list-windows -a -F "#{session_name}:#{window_name}")+change-preview($SCRIPTS_DIR/preview.sh -w {1})"

    NEW_WINDOW="$bind_new_window:reload(find $PWD -mindepth 1 -maxdepth 1 -type d -o -type l)+change-preview($LS_COMMAND {})"
    ZO_WINDOW="$bind_zo:reload(zoxide query -l)+change-preview($LS_COMMAND {})"
    BACK="$bind_back:reload(echo -e \"${INPUT// /}\")+change-preview($SCRIPTS_DIR/preview.sh {1})"
    KILL_SESSION="$bind_kill_session:execute-silent(tmux kill-session -t {})+reload($SCRIPTS_DIR/reload_sessions.sh)"

    ACCEPT="$bind_accept:replace-query+print-query"
    DELETE="$bind_delete_char:backward-delete-char"
    EXIT="$bind_exit:abort"

    SELECT_UP="$bind_select_up:up"
    SELECT_DOWN="$bind_select_down:down"
    SCROLL_UP="$bind_scroll_up:preview-half-page-up"
    SCROLL_DOWN="$bind_scroll_down:preview-half-page-down"

    RENAME_SESSION_EXEC="bash -c '\''read -p \\\"New name: \\\" name; tmux rename-session -t \\\"{1}\\\" \\\"\\\${name}\\\" '\''"
    RENAME_SESSION_RELOAD="bash -c \\\"tmux list-sessions | sed -E '\''s/:.*$//'\''; \\\""
    RENAME_SESSION="$bind_rename_session:execute($RENAME_SESSION_EXEC)+reload($RENAME_SESSION_RELOAD)"

    HEADER="$bind_accept=󰿄 / $bind_kill_session=󱂧 / $bind_rename_session=󰑕 / $bind_configuration_mode=󱃖 / $bind_window_mode=  / $bind_new_window=󰇘 / $bind_back=󰌍 / $bind_tree_mode=󰐆  / $bind_scroll_up= / $bind_scroll_down= / $bind_zo="
    if is_fzf-marks_enabled; then
        HEADER="$HEADER / $(get_fzf-marks_keybind)=󰣉"
    fi

    if [[ "$FZF_BUILTIN_TMUX" == "on" ]]; then
        fzf_size_arg="--tmux"
    else
        fzf_size_arg="-p"
    fi
    if [[ "$preview_enabled" == "true" ]]; then
        PREVIEW_LINE="$SCRIPTS_DIR/preview.sh ${PREVIEW_OPTIONS} {}"
    fi

    args=(
        --bind "'$TREE_MODE'"
        --bind "'$CONFIGURATION_MODE'"
        --bind "'$WINDOWS_MODE'"
        --bind "'$NEW_WINDOW'"
        --bind "'$ZO_WINDOW'"
        --bind "'$BACK'"
        --bind "'$KILL_SESSION'"
        --bind "'$DELETE'"
        --bind "'$EXIT'"
        --bind "'$SELECT_UP'"
        --bind "'$SELECT_DOWN'"
        --bind "'$ACCEPT'"
        --bind "'$SCROLL_UP'"
        --bind "'$SCROLL_DOWN'"
        --bind "'$RENAME_SESSION'"
        --bind "'?:toggle-preview'"
        --bind "'change:first'"
        --exit-0
        --header="'$HEADER'"
        --preview="'${PREVIEW_LINE}'"
        --preview-window="'${preview_location},${preview_ratio},,'"
        --layout="'$layout_mode'"
        --pointer="'$pointer_icon'"
        --prompt "'$prompt_icon'"
        --print-query
        --tac
        --scrollbar "'▌▐'"
    )

    legacy=$(tmux_option_or_fallback "@sessionx-legacy-fzf-support" "off")
    if [[ "${legacy}" == "off" ]]; then
        # args+=(--border-label "'Current session: \"$CURRENT\" '")
        args+=(--bind "'focus:transform-preview-label:echo [ {} ]'")
    fi
    auto_accept=$(tmux_option_or_fallback "@sessionx-auto-accept" "off")
    if [[ "${auto_accept}" == "on" ]]; then
        args+=(--bind one:accept)
    fi

    if $(is_tmuxinator_enabled); then
        args+=(--bind "$(load_tmuxinator_binding)")
    fi
    if $(is_fzf-marks_enabled); then
        args+=(--bind "$(load_fzf-marks_binding)")
    fi

    echo ${args[@]}
}

build_fzf_opts() {
    additional_fzf_options=$(tmux_option_or_fallback "@sessionx-additional-options" "--color pointer:9,spinner:92,marker:46")
    echo $additional_fzf_options
}

cmd="$SCRIPTS_DIR/sessionx.sh \"$(build_args) $(build_fzf_opts)\""


tmux_bind="$(tmux_option_or_fallback "@sessionx-bind" "O")"
if [ `tmux_option_or_fallback "@sessionx-prefix" "on"` = "on"  ]; then
    tmux_bind_args=""
else
    tmux_bind_args="-n"
fi

tmux_bind_args="$tmux_bind_args $tmux_bind"


tmux bind-key $tmux_bind_args run-shell "$cmd"
