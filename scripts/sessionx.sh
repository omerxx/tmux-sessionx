#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT="$(tmux display-message -p '#S')"
Z_MODE="off"

source "$CURRENT_DIR/tmuxinator.sh"
source "$CURRENT_DIR/fzf-marks.sh"

get_sorted_sessions() {
	last_session=$(tmux display-message -p '#{client_last_session}')
	sessions=$(tmux list-sessions | sed -E 's/:.*$//' | grep -Fxv "$last_session")
	filtered_sessios=${extra_options["filtered-sessions"]}
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

input() {
	default_window_mode=${extra_options["window-mode"]}
	if [[ "$default_window_mode" == "on" ]]; then
		tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name}'
	else
		filter_current_session=${extra_options["filter-current"]}
		if [[ "$filter_current_session" == "true" ]]; then
			(get_sorted_sessions | grep -Fxv "$CURRENT") || echo "$CURRENT"
		else
			(get_sorted_sessions) || echo "$CURRENT"
		fi
	fi
}

additional_input() {
	sessions=$(get_sorted_sessions)
	custom_paths=${extra_options["custom-paths"]}
	custom_path_subdirectories=${extra_options["custom-paths-subdirectories"]}
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

handle_input() {
	INPUT=$(input)
	ADDITIONAL_INPUT=$(additional_input)
	if [[ -n $ADDITIONAL_INPUT ]]; then
		INPUT="$(additional_input)\n$INPUT"
	fi
	bind_back=${extra_options["bind-back"]}
	BACK="$bind_back:reload(echo -e \"${INPUT// /}\")+change-preview(${TMUX_PLUGIN_MANAGER_PATH%/}/tmux-sessionx/scripts/preview.sh {1})"
}

run_plugin() {
	Z_MODE=$(tmux_option_or_fallback "@sessionx-zoxide-mode" "off")
	eval $(tmux show-option -gqv @sessionx-_built-args)
	eval $(tmux show-option -gqv @sessionx-_built-extra-options)
	handle_input
	args+=(--bind "$BACK")

	if [[ "$FZF_BUILTIN_TMUX" == "on" ]]; then
		RESULT=$(echo -e "${INPUT}" | sed -E 's/✗/ /g' | fzf "${fzf_opts[@]}" "${args[@]}" | tail -n1)
	else
		RESULT=$(echo -e "${INPUT}" | sed -E 's/✗/ /g' | fzf-tmux "${fzf_opts[@]}" "${args[@]}" | tail -n1)
	fi
}

run_plugin
handle_output "$RESULT"
