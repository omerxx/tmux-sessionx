#!/usr/bin/env bash

# vi: sw=4 ts=4 noet

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
Z_MODE="off"

source "$CURRENT_DIR/tmuxinator.sh"
source "$CURRENT_DIR/fzf-marks.sh"

tmux_option_or_fallback() {
	local option_value
	option_value="$(tmux show-option -gqv "$1")"
	if [ -z "$option_value" ]; then
		option_value="$2"
	fi
	echo "$option_value"
}

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

input() {
	default_window_mode=$(tmux_option_or_fallback "@sessionx-window-mode" "off")
	current_session="$(tmux display-message -p '#S')"
	if [[ "$default_window_mode" == "on" ]]; then
		tmux list-windows -a -F '#{session_name}:#{window_index} #{window_name}'
	else
		filter_current_session=$(tmux_option_or_fallback "@sessionx-filter-current" "true")
		if [[ "$filter_current_session" == "true" ]]; then
			sessions=$(get_sorted_sessions | grep -v "$current_session$")
		else
			sessions=$(get_sorted_sessions)
		fi
		[ -z "$sessions" ] && sessions="$current_session"
		echo "$sessions"
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

# MAIN

ARGS=$1

INPUT=$(input)
ADDITIONAL_INPUT=$(additional_input)
if [[ -n $ADDITIONAL_INPUT ]]; then
	INPUT="$ADDITIONAL_INPUT\n$INPUT"
fi


build_fzf_cmd() {
	FZF_BUILTIN_TMUX=$(tmux_option_or_fallback "@sessionx-fzf-builtin-tmux" "off")

	window_height=$(tmux_option_or_fallback "@sessionx-window-height" "75%")
	window_width=$(tmux_option_or_fallback "@sessionx-window-width" "75%")

	if [[ "$FZF_BUILTIN_TMUX" == "on" ]]; then
		COMMAND="fzf --tmux $window_width,$window_height"
	else
		COMMAND="fzf-tmux -p '$window_width,$window_height' --"
	fi
}

build_fzf_cmd


echo $(echo -e "${INPUT}" | sed -E 's/✗/ /g') $COMMAND $ARGS | wl-copy


RESULT=$(echo -e "${INPUT}" | sed -E 's/✗/ /g' | sh -c "$COMMAND $ARGS 2>>/tmp/tmux-sessionx.log" | tail -n1)

handle_output "$RESULT"
