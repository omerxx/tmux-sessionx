#!/usr/bin/env bash
# Display preview of tmux windows/panes.
# Meant for use in fzf preview.
# Kudos:
#   https://stackoverflow.com/a/55247572/197789
#   https://github.com/petobens/dotfiles/blob/master/tmux/tmux_tree

single_mode() {
	session_name="${1}"
	if test "${DISPLAY_TMUXP}" -eq 1; then
		if $(tmux has-session -t "${session_name}" >&/dev/null); then
			:
		else
			tmuxp_conf="${HOME}/.tmuxp/${session_name}.yaml"
			if test -e "${tmuxp_conf}"; then
				cat "${tmuxp_conf}"
				return
			fi
		fi
	fi
	display_session "${session_name}"
}

tmux_option_or_fallback() {
	local option_value
	option_value="$(tmux show-option -gqv "$1")"
	if [ -z "$option_value" ]; then
		option_value="$2"
	fi
	echo "$option_value"
}

# Display a single sesssion
display_session() {
	session_name="${1}"
	session_id=$(tmux ls -F '#{session_id}' -f "#{==:#{session_name},${session_name}}")
	if test -z "${session_id}"; then
		return 1
	fi
	tmux capture-pane -ep -t "${session_id}"
}

window_mode() {
	args=($1)
	tmux capture-pane -ep -t "${args[0]}"
}

# Display a full tree, with selected session highlighted.
# If an session name is passed as an argument, highlight it
# in the output.
# This is the original tmux_tree script (see kudos).
tree_mode() {
	highlight="${1}"
	icon=$(tmux_option_or_fallback "@sessionx-tree-icon" "󰘍")
	tmux ls -F'#{session_id}' | while read -r s; do
		S=$(tmux ls -F'#{session_id}#{session_name}: #{T:tree_mode_format}' | grep ^"$s")
		session_info=${S##$s}
		session_name=$(echo "$session_info" | cut -d ':' -f 1)
		if [[ -n "$highlight" ]] && [[ "$highlight" == "$session_name" ]]; then
			echo -e "\033[1;34m$session_info\033[0m"
		else
			echo -e "\033[1m$session_info\033[0m"
		fi
		# Display each window
		tmux lsw -t"$s" -F'#{window_id}' | while read -r w; do
			W=$(tmux lsw -t"$s" -F'#{window_id}#{T:tree_mode_format}' | grep ^"$w")
			echo "  $icon ${W##$w}"
		done
	done
}

usage() {
	cat <<-END
		Usage: $0 [<options>] [<session_name>]

		Options:
		  -h              Print help and exit.
		  -p              Display tmuxp configuration is session not running
		  -t              Display tree of sessions

		A session name of "*Last*" is replaced with the client's last session.
	END
	# Note 'END' above most be fully left justified.
}

# What are we displaying?
# 'tree' == full tree of active sessions
# 'single' == single session
mode="single"

# In single mode, if session is not running, display
# tmuxp configuration instead (if it exists)
DISPLAY_TMUXP=0

while getopts ":hptw" opt; do
	case $opt in
	h)
		usage
		exit 0
		;;
	p) DISPLAY_TMUXP=1 ;;
	t) mode="tree" ;;
	w) mode="window" ;;
	\?) echo "Invalid option: -$OPTARG" >&2 ;;
	esac
done

shift $(($OPTIND - 1))
SESSION="$1"

if test "${SESSION}" == '*Last*'; then
	SESSION=$(tmux display-message -p "#{client_last_session}")
	if test -z "${SESSION}"; then
		echo "No last session."
		exit 0
	fi
fi

case "${mode}" in
single) single_mode "${SESSION}" ;;
tree) tree_mode "${SESSION}" ;;
window) window_mode "${SESSION}" ;;
*) echo "Unknown mode \"${mode}\"" ;;
esac

exit $status
