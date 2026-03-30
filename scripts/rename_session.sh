#!/usr/bin/env bash

if [ -z "$1" ]; then
  echo "Usage: rename_session.sh <session-name>" >&2
  exit 1
fi

current="$1"
clear >&2
clear >&2
cols=$(tput cols 2>/dev/null || echo 80)
label=" 󰑕 Rename Session "
inner_w=$((cols - 4))
if [ $inner_w -lt 20 ]; then inner_w=20; fi
max_input=$((inner_w - 1))
max_display=$((inner_w - 2))
scroll_margin=5
pad=$(( (cols - inner_w - 2) / 2 ))
sp=$(printf "%${pad}s" "")
bot_border=$(printf "─%.0s" $(seq 1 $inner_w))
label_len=${#label}
label_start=$(( (inner_w - label_len) / 2 ))
top_left=$(printf "─%.0s" $(seq 1 $label_start))
top_right=$(printf "─%.0s" $(seq 1 $((inner_w - label_start - label_len))))
input_label=" 󰥻  New name "
input_label_len=${#input_label}
input_label_start=$(( (inner_w - input_label_len) / 2 ))
input_top_left=$(printf "─%.0s" $(seq 1 $input_label_start))
input_top_right=$(printf "─%.0s" $(seq 1 $((inner_w - input_label_start - input_label_len))))
input_inner_spaces=$(printf " %.0s" $(seq 1 $((inner_w - 2))))
input_bot=$(printf "─%.0s" $(seq 1 $inner_w))
if [ ${#current} -gt $max_display ]; then
  display_name="${current:0:$((max_display - 3))}..."
else
  display_name="$current"
fi
cur_len=${#display_name}
cur_pad=$((inner_w - 2 - cur_len))
cur_spaces=$(printf "%${cur_pad}s" "")
printf >&2 "\n\n\n"
printf >&2 "%s\033[1;35m╭%s\033[1;33m%s\033[1;35m%s╮\033[0m\n" "$sp" "$top_left" "$label" "$top_right"
printf >&2 "%s\033[1;35m│\033[0m \033[1;33m%s\033[0m%s \033[1;35m│\033[0m\n" "$sp" "$display_name" "$cur_spaces"
printf >&2 "%s\033[1;35m╰%s╯\033[0m\n" "$sp" "$bot_border"
printf >&2 "\n"
printf >&2 "%s\033[1;36m╭%s\033[1;33m%s\033[1;36m%s╮\033[0m\n" "$sp" "$input_top_left" "$input_label" "$input_top_right"
printf >&2 "%s\033[1;36m│\033[0m%s\033[1;36m│\033[0m\n" "$sp" "$input_inner_spaces"
printf >&2 "%s\033[1;36m╰%s╯\033[0m\n" "$sp" "$input_bot"
name=""
cursor=0
scroll=0
escaped=0
redraw_input() {
  visible="${name:$scroll:$max_input}"
  vis_len=${#visible}
  fill_pad=$((inner_w - 1 - vis_len))
  fill=$(printf "%${fill_pad}s" "")
  printf >&2 "\r%s\033[1;36m│\033[0m %s%s\033[1;36m│\033[0m" "$sp" "$visible" "$fill"
  cur_screen=$((cursor - scroll))
  printf >&2 "\r\033[%dC" "$((pad + 2 + cur_screen))"
}
adjust_scroll() {
  if [ $((cursor - scroll)) -lt 0 ]; then
    scroll=$cursor
  elif [ $((cursor - scroll)) -ge $max_input ]; then
    scroll=$((cursor - max_input + 1))
  fi
}
adjust_scroll_back() {
  want=$((cursor - scroll_margin))
  if [ $want -lt 0 ]; then want=0; fi
  if [ $scroll -gt $want ]; then
    scroll=$want
  fi
  if [ $((cursor - scroll)) -ge $max_input ]; then
    scroll=$((cursor - max_input + 1))
  fi
}
do_home() {
  cursor=0
  scroll=0
}
do_end() {
  cursor=${#name}
  adjust_scroll
}
printf >&2 "\033[2A"
redraw_input
old_settings=$(stty -g </dev/tty)
stty -echo -icanon min 1 time 0 </dev/tty
while true; do
  char=$(dd bs=1 count=1 2>/dev/null </dev/tty)
  if [ -z "$char" ] || [ "$char" = "$(printf "\r")" ] || [ "$char" = "$(printf "\n")" ]; then
    break
  elif [ "$char" = "$(printf "\001")" ]; then
    do_home
  elif [ "$char" = "$(printf "\005")" ]; then
    do_end
  elif [ "$char" = "$(printf "\177")" ] || [ "$char" = "$(printf "\b")" ]; then
    if [ $cursor -gt 0 ]; then
      name="${name:0:$((cursor-1))}${name:$cursor}"
      cursor=$((cursor - 1))
      adjust_scroll_back
    fi
  elif [ "$char" = "$(printf "\033")" ]; then
    stty min 0 time 1 </dev/tty
    bracket=$(dd bs=1 count=1 2>/dev/null </dev/tty)
    stty min 1 time 0 </dev/tty
    if [ -z "$bracket" ]; then
      escaped=1
      break
    elif [ "$bracket" = "[" ]; then
      code=$(dd bs=1 count=1 2>/dev/null </dev/tty)
      case "$code" in
        D)
          if [ $cursor -gt 0 ]; then
            cursor=$((cursor - 1))
            adjust_scroll
          fi;;
        C)
          if [ $cursor -lt ${#name} ]; then
            cursor=$((cursor + 1))
            adjust_scroll
          fi;;
        H)
          do_home;;
        F)
          do_end;;
        1)
          tilde=$(dd bs=1 count=1 2>/dev/null </dev/tty)
          if [ "$tilde" = "~" ]; then
            do_home
          fi;;
        4)
          tilde=$(dd bs=1 count=1 2>/dev/null </dev/tty)
          if [ "$tilde" = "~" ]; then
            do_end
          fi;;
        3)
          tilde=$(dd bs=1 count=1 2>/dev/null </dev/tty)
          if [ "$tilde" = "~" ] && [ $cursor -lt ${#name} ]; then
            name="${name:0:$cursor}${name:$((cursor+1))}"
            adjust_scroll_back
          fi;;
      esac
    elif [ "$bracket" = "O" ]; then
      code=$(dd bs=1 count=1 2>/dev/null </dev/tty)
      case "$code" in
        H)
          do_home;;
        F)
          do_end;;
      esac
    fi
  else
    if [ ${#name} -lt 256 ]; then
      name="${name:0:$cursor}${char}${name:$cursor}"
      cursor=$((cursor + 1))
      adjust_scroll
    fi
  fi
  redraw_input
done
stty "$old_settings" </dev/tty
printf >&2 "\n\n"
if [ $escaped -eq 0 ] && [ -n "$name" ]; then
  tmux rename-session -t "$current" "$name"
  tmux set-option -g @sessionx-_current-name "$name"
fi
