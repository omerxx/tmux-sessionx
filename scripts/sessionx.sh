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
    preview_location=$(tmux_option_or_fallback "@sessionx-preview-location" "top")
    preview_ratio=$(tmux_option_or_fallback "@sessionx-preview-ratio" "75%")
}

window_settings() {
    window_height=$(tmux_option_or_fallback "@sessionx-window-height" "75%")
    window_width=$(tmux_option_or_fallback "@sessionx-window-width" "75%")
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
    Z_MODE=$(tmux_option_or_fallback "@sessionx-zoxide-mode" "off")
    BIND_ALT_BSPACE="alt-bspace:execute-silent(tmux kill-session -t {})+reload(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/reload_sessions.sh)"
    BIND_CTRL_W="ctrl-w:reload(tmux list-windows -a -F '#{session_name}:#{window_index}')+change-preview(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh -w {1})"
    CTRL_X_PATH=$(tmux_option_or_fallback "@sessionx-x-path" "$HOME/.config")
    BIND_CTRL_X="ctrl-x:reload(find $CTRL_X_PATH -mindepth 1 -maxdepth 1 -type d)+change-preview(ls {})"
    BIND_CTRL_E="ctrl-e:reload(find $PWD -mindepth 1 -maxdepth 1 -type d)+change-preview(ls {})"
    BIND_CTRL_T="ctrl-t:change-preview(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh -t {1})"
    BIND_CTRL_B="ctrl-b:reload(echo -e \"${INPUT// /}\")+change-preview(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh {1})"
    BIND_ENTER="enter:replace-query+print-query"
    BIND_CTRL_R='ctrl-r:execute(printf >&2 "New name: ";read name; tmux rename-session -t {} ${name};)+reload(tmux list-sessions | sed -E "s/:.*$//")'
    HEADER="enter=󰿄  alt+󰁮 =󱂧  C-r=󰑕  C-x=󱃖  C-w=   C-e=󰇘  C-b=󰌍  C-t=󰐆   C-u=  C-d= "

    args=(
        --bind "$BIND_ALT_BSPACE" \
        --bind "$BIND_CTRL_X" \
        --bind "$BIND_CTRL_E" \
        --bind "$BIND_CTRL_B" \
        --bind "$BIND_CTRL_R" \
        --bind "$BIND_CTRL_W" \
        --bind "$BIND_CTRL_T" \
        --bind "$BIND_ENTER" \
        --bind '?:toggle-preview' \
        --bind 'ctrl-u:preview-half-page-up,ctrl-d:preview-half-page-down' \
        --bind 'change:first' \
        --color 'pointer:9,spinner:92,marker:46' \
        --exit-0 \
        --header="$HEADER" \
        --preview="${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh ${PREVIEW_OPTIONS} {}" \
        --preview-window="${preview_location},${preview_ratio},," \
        --pointer='▶' \
        -p "$window_width,$window_height" \
        --prompt " " \
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
    handle_args
    RESULT=$(echo -e "${INPUT// /}" | fzf-tmux "${args[@]}") 
}

run_plugin
handle_output "$RESULT"
