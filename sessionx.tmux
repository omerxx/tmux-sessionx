#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$CURRENT_DIR/scripts"
CURRENT="$(tmux display-message -p '#S')"

source "$SCRIPTS_DIR/tmuxinator.sh"
source "$SCRIPTS_DIR/fzf-marks.sh"

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

	bind_select_up=$(tmux_option_or_fallback "@sessionx-bind-select-up" "ctrl-p")
	bind_select_down=$(tmux_option_or_fallback "@sessionx-bind-select-down" "ctrl-n")

}

handle_args() {
	LS_COMMAND=$(tmux_option_or_fallback "@sessionx-ls-command" "ls")
	if [[ "$preview_enabled" == "true" ]]; then
		PREVIEW_LINE="${SCRIPTS_DIR%/}/preview.sh ${PREVIEW_OPTIONS} {}"
	fi
	CONFIGURATION_PATH=$(tmux_option_or_fallback "@sessionx-x-path" "$HOME/.config")
	FZF_BUILTIN_TMUX=$(tmux_option_or_fallback "@sessionx-fzf-builtin-tmux" "off")

	TREE_MODE="$bind_tree_mode:change-preview(${SCRIPTS_DIR%/}/preview.sh -t {1})"
	CONFIGURATION_MODE="$bind_configuration_mode:reload(find -L $CONFIGURATION_PATH -mindepth 1 -maxdepth 1 -type d -o -type l)+change-preview($LS_COMMAND {})"
	WINDOWS_MODE="$bind_window_mode:reload(tmux list-windows -a -F '#{session_name}:#{window_name}')+change-preview(${SCRIPTS_DIR%/}/preview.sh -w {1})"

	NEW_WINDOW="$bind_new_window:reload(find -L $PWD -mindepth 1 -maxdepth 1 -type d -o -type l)+change-preview($LS_COMMAND {})"
	ZO_WINDOW="$bind_zo:reload(zoxide query -l)+change-preview($LS_COMMAND {})"
	KILL_SESSION="$bind_kill_session:execute-silent(tmux kill-session -t {1})+reload(${SCRIPTS_DIR%/}/reload_sessions.sh)"

	ACCEPT="$bind_accept:replace-query+print-query"
	DELETE="$bind_delete_char:backward-delete-char"
	EXIT="$bind_exit:abort"

	SELECT_UP="$bind_select_up:up"
	SELECT_DOWN="$bind_select_down:down"
	SCROLL_UP="$bind_scroll_up:preview-half-page-up"
	SCROLL_DOWN="$bind_scroll_down:preview-half-page-down"

	RENAME_SESSION_EXEC='bash -c '\''
  current="$0";
  clear >&2;
  clear >&2;
  cols=$(tput cols 2>/dev/null || echo 80);
  label=" 󰑕 Rename Session ";
  inner_w=$((cols - 4));
  if [ $inner_w -lt 20 ]; then inner_w=20; fi;
  max_input=$((inner_w - 1));
  max_display=$((inner_w - 2));
  scroll_margin=5;
  pad=$(( (cols - inner_w - 2) / 2 ));
  sp=$(printf "%${pad}s" "");
  bot_border=$(printf "─%.0s" $(seq 1 $inner_w));
  label_len=${#label};
  label_start=$(( (inner_w - label_len) / 2 ));
  top_left=$(printf "─%.0s" $(seq 1 $label_start));
  top_right=$(printf "─%.0s" $(seq 1 $((inner_w - label_start - label_len))));
  input_label=" 󰥻  New name ";
  input_label_len=${#input_label};
  input_label_start=$(( (inner_w - input_label_len) / 2 ));
  input_top_left=$(printf "─%.0s" $(seq 1 $input_label_start));
  input_top_right=$(printf "─%.0s" $(seq 1 $((inner_w - input_label_start - input_label_len))));
  input_inner_spaces=$(printf " %.0s" $(seq 1 $((inner_w - 2))));
  input_bot=$(printf "─%.0s" $(seq 1 $inner_w));
  if [ ${#current} -gt $max_display ]; then
    display_name="${current:0:$((max_display - 3))}...";
  else
    display_name="$current";
  fi;
  cur_len=${#display_name};
  cur_pad=$((inner_w - 2 - cur_len));
  cur_spaces=$(printf "%${cur_pad}s" "");
  printf >&2 "\n\n\n";
  printf >&2 "%s\033[1;35m╭%s\033[1;33m%s\033[1;35m%s╮\033[0m\n" "$sp" "$top_left" "$label" "$top_right";
  printf >&2 "%s\033[1;35m│\033[0m \033[1;33m%s\033[0m%s \033[1;35m│\033[0m\n" "$sp" "$display_name" "$cur_spaces";
  printf >&2 "%s\033[1;35m╰%s╯\033[0m\n" "$sp" "$bot_border";
  printf >&2 "\n";
  printf >&2 "%s\033[1;36m╭%s\033[1;33m%s\033[1;36m%s╮\033[0m\n" "$sp" "$input_top_left" "$input_label" "$input_top_right";
  printf >&2 "%s\033[1;36m│\033[0m%s\033[1;36m│\033[0m\n" "$sp" "$input_inner_spaces";
  printf >&2 "%s\033[1;36m╰%s╯\033[0m\n" "$sp" "$input_bot";
  name="";
  cursor=0;
  scroll=0;
  escaped=0;
  redraw_input() {
    visible="${name:$scroll:$max_input}";
    vis_len=${#visible};
    fill_pad=$((inner_w - 1 - vis_len));
    fill=$(printf "%${fill_pad}s" "");
    printf >&2 "\r%s\033[1;36m│\033[0m %s%s\033[1;36m│\033[0m" "$sp" "$visible" "$fill";
    cur_screen=$((cursor - scroll));
    printf >&2 "\r\033[%dC" "$((pad + 2 + cur_screen))";
  };
  adjust_scroll() {
    if [ $((cursor - scroll)) -lt 0 ]; then
      scroll=$cursor;
    elif [ $((cursor - scroll)) -ge $max_input ]; then
      scroll=$((cursor - max_input + 1));
    fi;
  };
  adjust_scroll_back() {
    want=$((cursor - scroll_margin));
    if [ $want -lt 0 ]; then want=0; fi;
    if [ $scroll -gt $want ]; then
      scroll=$want;
    fi;
    if [ $((cursor - scroll)) -ge $max_input ]; then
      scroll=$((cursor - max_input + 1));
    fi;
  };
  do_home() {
    cursor=0;
    scroll=0;
  };
  do_end() {
    cursor=${#name};
    adjust_scroll;
  };
  printf >&2 "\033[2A";
  redraw_input;
  old_settings=$(stty -g </dev/tty);
  stty -echo -icanon min 1 time 0 </dev/tty;
  while true; do
    char=$(dd bs=1 count=1 2>/dev/null </dev/tty);
    if [ -z "$char" ] || [ "$char" = "$(printf "\r")" ] || [ "$char" = "$(printf "\n")" ]; then
      break;
    elif [ "$char" = "$(printf "\001")" ]; then
      do_home;
    elif [ "$char" = "$(printf "\005")" ]; then
      do_end;
    elif [ "$char" = "$(printf "\177")" ] || [ "$char" = "$(printf "\b")" ]; then
      if [ $cursor -gt 0 ]; then
        name="${name:0:$((cursor-1))}${name:$cursor}";
        cursor=$((cursor - 1));
        adjust_scroll_back;
      fi;
    elif [ "$char" = "$(printf "\033")" ]; then
      stty min 0 time 1 </dev/tty;
      bracket=$(dd bs=1 count=1 2>/dev/null </dev/tty);
      stty min 1 time 0 </dev/tty;
      if [ -z "$bracket" ]; then
        escaped=1;
        break;
      elif [ "$bracket" = "[" ]; then
        code=$(dd bs=1 count=1 2>/dev/null </dev/tty);
        case "$code" in
          D)
            if [ $cursor -gt 0 ]; then
              cursor=$((cursor - 1));
              adjust_scroll;
            fi;;
          C)
            if [ $cursor -lt ${#name} ]; then
              cursor=$((cursor + 1));
              adjust_scroll;
            fi;;
          H)
            do_home;;
          F)
            do_end;;
          1)
            tilde=$(dd bs=1 count=1 2>/dev/null </dev/tty);
            if [ "$tilde" = "~" ]; then
              do_home;
            fi;;
          4)
            tilde=$(dd bs=1 count=1 2>/dev/null </dev/tty);
            if [ "$tilde" = "~" ]; then
              do_end;
            fi;;
          3)
            tilde=$(dd bs=1 count=1 2>/dev/null </dev/tty);
            if [ "$tilde" = "~" ] && [ $cursor -lt ${#name} ]; then
              name="${name:0:$cursor}${name:$((cursor+1))}";
              adjust_scroll_back;
            fi;;
        esac;
      elif [ "$bracket" = "O" ]; then
        code=$(dd bs=1 count=1 2>/dev/null </dev/tty);
        case "$code" in
          H)
            do_home;;
          F)
            do_end;;
        esac;
      fi;
    else
      if [ ${#name} -lt 256 ]; then
        name="${name:0:$cursor}${char}${name:$cursor}";
        cursor=$((cursor + 1));
        adjust_scroll;
      fi;
    fi;
    redraw_input;
  done;
  stty "$old_settings" </dev/tty;
  printf >&2 "\n\n";
  if [ $escaped -eq 0 ] && [ -n "$name" ]; then
    tmux rename-session -t "$current" "$name";
      if [ $escaped -eq 0 ] && [ -n "$name" ]; then
        tmux rename-session -t "$current" "$name";
        tmux set-option -g @sessionx-_current-name "$name";
      fi
    tmux set-option -g @sessionx-_current-name "$name";
  fi
'\'' {}'

	RENAME_SESSION_RELOAD='bash -c '\'' tmux list-sessions | sed -E "s/:.*$//"; '\'''
	RENAME_SESSION_LABEL='bash -c '\'' printf "Current session: \"%s\" " "$(tmux display-message -p "#S")" '\'''

	RENAME_SESSION_PREVIEW_LABEL='bash -c '\'' name=$(tmux show-option -gqv @sessionx-_current-name); printf "[ %s ]" "$name" '\'''
	RENAME_SESSION="$bind_rename_session:execute($RENAME_SESSION_EXEC)+reload($RENAME_SESSION_RELOAD)+transform-border-label($RENAME_SESSION_LABEL)+transform-preview-label($RENAME_SESSION_PREVIEW_LABEL)"

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
		--ansi
		--bind "$TREE_MODE"
		--bind "$CONFIGURATION_MODE"
		--bind "$WINDOWS_MODE"
		--bind "$NEW_WINDOW"
		--bind "$ZO_WINDOW"
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
		args+=(--bind 'focus:transform-preview-label:echo [ {} ] | sed "s/\x1b\[[0-9;]*m//g"')
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

handle_extra_options() {
	# Store each option individually to avoid bash 3.2 associative array issues on macOS
	tmux set-option -g @sessionx-_bind-back "$bind_back"
	tmux set-option -g @sessionx-_filtered-sessions "$(tmux_option_or_fallback "@sessionx-filtered-sessions" "")"
	tmux set-option -g @sessionx-_window-mode "$(tmux_option_or_fallback "@sessionx-window-mode" "off")"
	tmux set-option -g @sessionx-_filter-current "$(tmux_option_or_fallback "@sessionx-filter-current" "true")"
	tmux set-option -g @sessionx-_custom-paths "$(tmux_option_or_fallback "@sessionx-custom-paths" "")"
	tmux set-option -g @sessionx-_custom-paths-subdirectories "$(tmux_option_or_fallback "@sessionx-custom-paths-subdirectories" "false")"
	tmux set-option -g @sessionx-_git-branch "$(tmux_option_or_fallback "@sessionx-git-branch" "off")"
	tmux set-option -g @sessionx-_fzf-builtin-tmux "$FZF_BUILTIN_TMUX"
}

preview_settings
window_settings
handle_binds
handle_args
handle_extra_options

tmux set-option -g @sessionx-_built-args "$(declare -p args)"
tmux set-option -g @sessionx-_built-fzf-opts "$(declare -p fzf_opts)"

if [ $(tmux_option_or_fallback "@sessionx-prefix" "on") = "on" ]; then
	tmux bind-key "$(tmux_option_or_fallback "@sessionx-bind" "O")" run-shell "$CURRENT_DIR/scripts/sessionx.sh"
else
	tmux bind-key -n "$(tmux_option_or_fallback "@sessionx-bind" "O")" run-shell "$CURRENT_DIR/scripts/sessionx.sh"
fi
