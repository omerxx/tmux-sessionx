#!/usr/bin/env bash

CURRENT="$(tmux display-message -p '#S')"
Z_MODE="off"

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
    window_height=$(tmux_option_or_fallback "@sessionx-window-height" "75%")
    window_width=$(tmux_option_or_fallback "@sessionx-window-width" "75%")
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
  bind_kill_session=$(tmux_option_or_fallback "@sessionx-bind-kill-session" "alt-bspace")

  bind_exit=$(tmux_option_or_fallback "@sessionx-bind-abort" "esc")
  bind_accept=$(tmux_option_or_fallback "@sessionx-bind-accept" "enter")
  bind_delete_char=$(tmux_option_or_fallback "@sessionx-bind-delete-char" "bspace")

  bind_scroll_up=$(tmux_option_or_fallback "@sessionx-bind-scroll-up" "ctrl-p")
  bind_scroll_down=$(tmux_option_or_fallback "@sessionx-bind-scroll-down" "ctrl-d")

  bind_select_up=$(tmux_option_or_fallback "@sessionx-bind-select-up" "ctrl-n")
  bind_select_down=$(tmux_option_or_fallback "@sessionx-bind-select-down" "ctrl-m")
}

input() {
    default_window_mode=$(tmux_option_or_fallback "@sessionx-window-mode" "off")
    if [[ "$default_window_mode" == "on" ]]; then
        (tmux list-windows -a -F '#{session_name}:#{window_index}')
    else
        filter_current_session=$(tmux_option_or_fallback "@sessionx-filter-current" "true")
        if [[ "$filter_current_session" == "true" ]]; then
            (tmux list-sessions | sed -E 's/:.*$//' | grep -v "$CURRENT$")  || echo "$CURRENT"
        else
            (tmux list-sessions | sed -E 's/:.*$//')  || echo "$CURRENT"
        fi
    fi
}

additional_input() {
    sessions=$(tmux list-sessions | sed -E 's/:.*$//')
    custom_paths=$(tmux_option_or_fallback "@sessionx-custom-paths" "")
    list=()
    if [[ -z "$custom_paths" ]]; then
        echo ""
    else
        for i in ${custom_paths//,/ }; do
            if [[ $sessions == *"${i##*/}"* ]]; then
                continue
              fi
              list+=("${i}\n")
            last=$i
        done
        unset 'list[${#list[@]}-1]'
        list+=("${last}")
        echo "${list[@]}"
    fi
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
            if [[ "$Z_MODE" == "on" ]]; then
                z_target=$(zoxide query "$target")
                tmux new-session -ds "$target" -c "$z_target" -n "$z_target"
            else
                tmux new-session -ds "$target"
            fi
        fi
    fi
    tmux switch-client -t "$target"
}

handle_args() {
    INPUT=$(input)
    ADDITIONAL_INPUT=$(additional_input)
    if [[ -n $ADDITIONAL_INPUT ]]; then
        INPUT="$(additional_input)\n$INPUT"
    fi
    if [[ "$preview_enabled" == "true" ]]; then
        PREVIEW_LINE="${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh ${PREVIEW_OPTIONS} {}"
    fi
    Z_MODE=$(tmux_option_or_fallback "@sessionx-zoxide-mode" "off")
    CONFIGURATION_PATH=$(tmux_option_or_fallback "@sessionx-x-path" "$HOME/.config")

    TREE_MODE="$bind_tree_mode:change-preview(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh -t {1})"
    CONFIGURATION_MODE="$bind_configuration_mode:reload(find $CONFIGURATION_PATH -mindepth 1 -maxdepth 1 -type d)+change-preview(ls {})"
    WINDOWS_MODE="$bind_window_mode:reload(tmux list-windows -a -F '#{session_name}:#{window_index}')+change-preview(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh -w {1})"

    NEW_WINDOW="$bind_new_window:reload(find $PWD -mindepth 1 -maxdepth 1 -type d)+change-preview(ls {})"
    BACK="$bind_back:reload(echo -e \"${INPUT// /}\")+change-preview(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh {1})"
    KILL_SESSION="$bind_kill_session:execute-silent(tmux kill-session -t {})+reload(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/reload_sessions.sh)"

    ACCEPT="$bind_accept:replace-query+print-query"
    DELETE="$bind_delete_char:backward-delete-char"
    EXIT="$bind_exit:abort"

    SELECT_UP="$bind_select_up:up"
    SELECT_DOWN="$bind_select_down:down"
    SCROLL_UP="$bind_scroll_up:preview-half-page-up"
    SCROLL_DOWN="$bind_scroll_down:preview-half-page-down"

    RENAME_SESSION_EXEC='bash -c '\'' printf >&2 "New name: ";read name; tmux rename-session -t {} ${name}; '\'''
    RENAME_SESSION_RELOAD='bash -c '\'' tmux list-sessions | sed -E "s/:.*$//"; '\'''
    RENAME_SESSION="$bind_rename_session:execute($RENAME_SESSION_EXEC)+reload($RENAME_SESSION_RELOAD)"

    HEADER="$bind_accept=󰿄  $bind_kill_session=󱂧  $bind_rename_session=󰑕  $bind_configuration_mode=󱃖  $bind_window_mode=   $bind_new_window=󰇘  $bind_back=󰌍  $bind_tree_mode=󰐆   $bind_scroll_up=  $bind_scroll_down= "


    args=(
        --bind "$TREE_MODE" \
        --bind "$CONFIGURATION_MODE" \
        --bind "$WINDOWS_MODE" \
        --bind "$NEW_WINDOW" \
        --bind "$BACK" \
        --bind "$KILL_SESSION" \
        --bind "$DELETE" \
        --bind "$EXIT" \
        --bind "$SELECT_UP" \
        --bind "$SELECT_DOWN" \
        --bind "$ACCEPT" \
        --bind "$SCROLL_UP" \
        --bind "$SCROLL_DOWN" \
        --bind "$RENAME_SESSION" \
        --bind '?:toggle-preview' \
        --bind 'change:first' \
        --color 'pointer:9,spinner:92,marker:46' \
        --exit-0 \
        --header="$HEADER" \
        --preview="${PREVIEW_LINE}" \
        --preview-window="${preview_location},${preview_ratio},," \
        --layout="$layout_mode" \
        --pointer=$pointer_icon \
        -p "$window_width,$window_height" \
        --prompt "$prompt_icon" \
        --print-query \
        --tac \
        --scrollbar '▌▐'\
        )

    legacy=$(tmux_option_or_fallback "@sessionx-legacy-fzf-support" "off")
    if [[ "${legacy}" == "off" ]]; then
        args+=(--border-label "Current session: \"$CURRENT\" ")
        args+=(--bind 'focus:transform-preview-label:echo [ {} ]')
    fi

}

run_plugin() {
    preview_settings
    window_settings
    handle_binds
    handle_args
    RESULT=$(echo -e "${INPUT// /}" | fzf-tmux "${args[@]}")
}

run_plugin
handle_output "$RESULT"
