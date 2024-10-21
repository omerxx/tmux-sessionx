#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT="$(tmux display-message -p '#S')"
Z_MODE="off"

source "$CURRENT_DIR/tmuxinator.sh"
source "$CURRENT_DIR/fzf-marks.sh"

get_sorted_sessions() {
	last_session=$(tmux display-message -p '#{client_last_session}')
	sessions=$(tmux list-sessions | sed -E 's/:.*$//' | grep -v "^$last_session$")
	filtered_sessios=$(tmux_option_or_fallback "@sessionx-filtered-sessions" "")
	if [[ -n "$filtered_sessios" ]]; then
	  filtered_and_piped=$(echo "$filtered_sessios" | sed -E 's/,/|/g')
	  sessions=$(echo "$sessions" | grep -Ev "$filtered_and_piped")
	fi
	echo -e "$sessions\n$last_session" | awk '!seen[$0]++'
}

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
	additional_fzf_options=$(tmux_option_or_fallback "@sessionx-additional-options" "--color pointer:9,spinner:92,marker:46")

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

input() {
	default_window_mode=$(tmux_option_or_fallback "@sessionx-window-mode" "off")
	if [[ "$default_window_mode" == "on" ]]; then
		tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name}'
	else
		filter_current_session=$(tmux_option_or_fallback "@sessionx-filter-current" "true")
		if [[ "$filter_current_session" == "true" ]]; then
			(get_sorted_sessions | grep -v "$CURRENT$") || echo "$CURRENT"
		else
			(get_sorted_sessions) || echo "$CURRENT"
		fi
	fi
}

additional_input() {
	sessions=$(get_sorted_sessions)
	custom_paths=$(tmux_option_or_fallback "@sessionx-custom-paths" "")
	custom_path_subdirectories=$(tmux_option_or_fallback "@sessionx-custom-paths-subdirectories" "false")
	if [[ -z "$custom_paths" ]]; then
		echo ""
	else
		clean_paths=$(echo "$custom_paths" | sed -E 's/ *, */,/g' | sed -E 's/^ *//' | sed -E 's/ *$//' | sed -E 's/ /✗/g')
		if [[ "$custom_path_subdirectories" == "true" ]]; then
			paths=$(find ${clean_paths//,/ } -mindepth 1 -maxdepth 1 -type d)
		else
			paths=${clean_paths//,/ }
		fi
		add_path() {
			local path=$1
			if ! grep -q "$(basename "$path")" <<< "$sessions"; then
				echo "$path"
			fi
		}
		export -f add_path
		printf "%s\n" "${paths//,/$IFS}" | xargs -n 1 -P 0 bash -c 'add_path "$@"' _
	fi
}

handle_output() {
	if [ -d "$*" ]; then
		# No special handling because there isn't a window number or window name present
		# except in unlikely and contrived situations (e.g.
		# "/home/person/projects:0\ bash" could be a path on your filesystem.)
		target=$(echo "$@" | tr -d '\n')
	elif is_fzf-marks_mark "$@" ; then
		# Needs to run before session name mode
		mark=$(get_fzf-marks_mark "$@")
		target=$(get_fzf-marks_target "$@")
	elif echo "$@" | grep ':' >/dev/null 2>&1; then
		# Colon probably delimits session name and window number
		session_name=$(echo "$@" | cut -d: -f1)
		num=$(echo "$@" | cut -d: -f2 | cut -d' ' -f1)
		target=$(echo "${session_name}:${num}" | tr -d '\n')
	else
		# All tokens represent a session name
		target=$(echo "$@" | tr -d '\n')
	fi

	if [[ -z "$target" ]]; then
		exit 0
	fi

	if ! tmux has-session -t="$target" 2>/dev/null; then
		if is_tmuxinator_enabled && is_tmuxinator_template "$target"; then
			tmuxinator start "$target"
		elif test -n "$mark"; then
			tmux new-session -ds "$mark" -c "$target"
			target="$mark"
		elif test -d "$target"; then
			d_target="$(basename "$target" | tr -d '.')"
			tmux new-session -ds $d_target -c "$target"
			target=$d_target
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

	exit 0
}

handle_args() {
	LS_COMMAND=$(tmux_option_or_fallback "@sessionx-ls-command" "ls")
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
	FZF_BUILTIN_TMUX=$(tmux_option_or_fallback "@sessionx-fzf-builtin-tmux" "off")

	TREE_MODE="$bind_tree_mode:change-preview(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh -t {1})"
	CONFIGURATION_MODE="$bind_configuration_mode:reload(find $CONFIGURATION_PATH -mindepth 1 -maxdepth 1 -type d -o -type l)+change-preview($LS_COMMAND {})"
	WINDOWS_MODE="$bind_window_mode:reload(tmux list-windows -a -F '#{session_name}:#{window_name}')+change-preview(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh -w {1})"

	NEW_WINDOW="$bind_new_window:reload(find $PWD -mindepth 1 -maxdepth 1 -type d -o -type l)+change-preview($LS_COMMAND {})"
	ZO_WINDOW="$bind_zo:reload(zoxide query -l)+change-preview($LS_COMMAND {})"
	BACK="$bind_back:reload(echo -e \"${INPUT// /}\")+change-preview(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh {1})"
	KILL_SESSION="$bind_kill_session:execute-silent(tmux kill-session -t {})+reload(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/reload_sessions.sh)"

	ACCEPT="$bind_accept:replace-query+print-query"
	DELETE="$bind_delete_char:backward-delete-char"
	EXIT="$bind_exit:abort"

	SELECT_UP="$bind_select_up:up"
	SELECT_DOWN="$bind_select_down:down"
	SCROLL_UP="$bind_scroll_up:preview-half-page-up"
	SCROLL_DOWN="$bind_scroll_down:preview-half-page-down"

	RENAME_SESSION_EXEC='bash -c '\'' printf >&2 "New name: ";read name; tmux rename-session -t {1} "${name}"; '\'''
	RENAME_SESSION_RELOAD='bash -c '\'' tmux list-sessions | sed -E "s/:.*$//"; '\'''
	RENAME_SESSION="$bind_rename_session:execute($RENAME_SESSION_EXEC)+reload($RENAME_SESSION_RELOAD)"

	HEADER="$bind_accept=󰿄  $bind_kill_session=󱂧  $bind_rename_session=󰑕  $bind_configuration_mode=󱃖  $bind_window_mode=   $bind_new_window=󰇘  $bind_back=󰌍  $bind_tree_mode=󰐆   $bind_scroll_up=  $bind_scroll_down= / $bind_zo="
	if is_fzf-marks_enabled; then
		HEADER="$HEADER  $(get_fzf-marks_keybind)=󰣉"
	fi

	if [[ "$FZF_BUILTIN_TMUX" == "on" ]]; then
		fzf_size_arg="--tmux"
	else
		fzf_size_arg="-p"
	fi

	args=(
		--bind "$TREE_MODE"
		--bind "$CONFIGURATION_MODE"
		--bind "$WINDOWS_MODE"
		--bind "$NEW_WINDOW"
		--bind "$ZO_WINDOW"
		--bind "$BACK"
		--bind "$KILL_SESSION"
		--bind "$DELETE"
		--bind "$EXIT"
		--bind "$SELECT_UP"
		--bind "$SELECT_DOWN"
		--bind "$ACCEPT"
		--bind "$SCROLL_UP"
		--bind "$SCROLL_DOWN"
		--bind "$RENAME_SESSION"
		--bind '?:toggle-preview'
		--bind 'change:first'
		--exit-0
		--header="$HEADER"
		--preview="${PREVIEW_LINE}"
		--preview-window="${preview_location},${preview_ratio},,"
		--layout="$layout_mode"
		--pointer="$pointer_icon"
		"${fzf_size_arg}" "$window_width,$window_height"
		--prompt "$prompt_icon"
		--print-query
		--tac
		--scrollbar '▌▐'
	)

	legacy=$(tmux_option_or_fallback "@sessionx-legacy-fzf-support" "off")
	if [[ "${legacy}" == "off" ]]; then
		args+=(--border-label "Current session: \"$CURRENT\" ")
		args+=(--bind 'focus:transform-preview-label:echo [ {} ]')
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

	eval "fzf_opts=($additional_fzf_options)"
}

run_plugin() {
	preview_settings
	window_settings
	handle_binds
	handle_args

	if [[ "$FZF_BUILTIN_TMUX" == "on" ]]; then
		RESULT=$(echo -e "${INPUT}" | sed -E 's/✗/ /g' | fzf "${fzf_opts[@]}" "${args[@]}" | tail -n1)
	else
		RESULT=$(echo -e "${INPUT}" | sed -E 's/✗/ /g' | fzf-tmux "${fzf_opts[@]}" "${args[@]}" | tail -n1)
	fi
}

run_plugin
handle_output "$RESULT"
