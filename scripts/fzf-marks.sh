#!/usr/bin/env bash

is_fzf-marks_enabled() {
  local fzf_marks_mode fzf_marks_file
  fzf_marks_file=$(get_fzf-marks_file)
  if [[ -e "${fzf_marks_file}" ]]; then
	  fzf_marks_mode=$(tmux_option_or_fallback "@sessionx-fzf-marks-mode" "off")
  fi

  if [[ "$fzf_marks_mode" != "on" ]]; then
    return 1
  fi

  return 0
}

is_fzf-marks_mark(){
  if $(echo "$@" | grep -q ' : '  2>&1); then
    return 0
  fi

  return 1
}

get_fzf-marks_file() {
  echo "$(tmux_option_or_fallback "@sessionx-fzf-marks-file" "$HOME/.fzf-marks" | sed "s|~|$HOME|")"
}

get_fzf-marks_mark() {
  local mark
  mark=$(echo "$@" | cut -d: -f1 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
  echo "$mark"
}

get_fzf-marks_target() {
  local target
  target=$(echo "$@" | cut -d: -f2 | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
  echo "$target"
}

get_fzf-marks_keybind() {
  local keybind
  keybind="$(tmux_option_or_fallback "@sessionx-bind-fzf-marks" "ctrl-g")"
  echo "$keybind"
}

load_fzf-marks_binding(){
  echo "$(get_fzf-marks_keybind):reload(cat $(get_fzf-marks_file))+change-preview(sed 's/.*: \(.*\)$/\1/' <<< {} | xargs $(tmux_option_or_fallback "@sessionx-ls-command" "ls"))"
}
