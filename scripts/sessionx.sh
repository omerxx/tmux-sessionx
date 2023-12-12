#!/usr/bin/env bash

CURRENT="$(tmux display-message -p '#S')"

tmux_option_or_fallback() {
	local option_value
	option_value="$(tmux show-option -gqv "$1")"
	if [ -z "$option_value" ]; then
		option_value="$2"
	fi
	echo "$option_value"
}

check_window_mode() {
    default_window_mode=$(tmux_option_or_fallback "@sessionx-window-mode" "off")
    if [[ "$default_window_mode" == "on" ]]; then
        PREVIEW_OPTIONS="-w"
    fi
}

input() {
    default_window_mode=$(tmux_option_or_fallback "@sessionx-window-mode" "off")
    if [[ "$default_window_mode" == "on" ]]; then
        (tmux list-windows -a -F '#{session_name}:#{window_name}')
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
            tmux new-session -ds "$target"
        fi
    fi
    tmux switch-client -t "$target"
}

BIND_BSPACE="bspace:execute(tmux kill-session -t {})+reload(tmux list-sessions | sed -E 's/:.*$//' | grep -v $(tmux display-message -p '#S'))"
BIND_CTRL_W="ctrl-w:reload(tmux list-windows -a -F '#{session_name}:#{window_name}')+change-preview(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh -w {})"
BIND_CTRL_O="ctrl-o:print-query+execute(tmux new-session -d -s {})"
CTRL_X_PATH=$(tmux_option_or_fallback "@sessionx-x-path" "$HOME/.config")
BIND_CTRL_X="ctrl-x:reload(find $CTRL_X_PATH -mindepth 1 -maxdepth 1 -type d)"
BIND_ENTER="enter:replace-query+print-query"
BIND_CTRL_R='ctrl-r:execute(printf >&2 "New name: ";read name; tmux rename-session -t {} ${name};)+reload(tmux list-sessions | sed -E "s/:.*$//")'


check_window_mode
INPUT=$(input)
ADDITIONAL_INPUT=$(additional_input)
if [[ -n $ADDITIONAL_INPUT ]]; then
    INPUT="$(additional_input)\n$INPUT"
fi


RESULT=$(echo -e "${INPUT// /}" | \
    fzf-tmux \
        --bind "$BIND_BSPACE" \
        --bind "$BIND_CTRL_O" \
        --bind "$BIND_CTRL_X" \
        --bind "$BIND_CTRL_R" \
        --bind "$BIND_CTRL_W" \
        --bind "$BIND_ENTER" \
        --bind '?:toggle-preview' \
        --bind 'ctrl-u:preview-half-page-up,ctrl-d:preview-half-page-down' \
        --bind 'change:first' \
        --bind 'focus:transform-preview-label:echo [ {} ]' \
        --border-label "Current session: \"$CURRENT\" " \
        --color 'pointer:9,spinner:92,marker:46' \
        --color 'preview-border:236,preview-scrollbar:0' \
        --exit-0 \
        --header='󰿄=go bspace=delete C-r=rename C-x=custom C-w=window-mode' \
        --preview="${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh ${PREVIEW_OPTIONS} {}" \
        --preview-window=",55%,," \
        --pointer='▶' \
        -p "75%,75%" \
	--prompt " " \
	--print-query \
        --tac \
        --scrollbar '▌▐') 

handle_output "$RESULT"
