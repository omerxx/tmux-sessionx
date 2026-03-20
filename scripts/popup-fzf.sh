#!/usr/bin/env bash
set -euo pipefail

width="${1:-}"
height="${2:-}"
shift 2 || true
original_args=("$@")

cleanup() {
  if [[ -n "${tmpdir:-}" ]]; then
    rm -rf "$tmpdir"
  fi
}
trap cleanup EXIT

tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/sessionx-popup-XXXXXX")
input_file="$tmpdir/input"
output_file="$tmpdir/output"
status_file="$tmpdir/status"
popup_script="$tmpdir/popup.sh"

cat > "$input_file"

popup_args=()
fzf_args=()
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "-p" && $# -ge 2 ]]; then
    popup_args=("-w${2%%,*}" "-h${2##*,}")
    shift 2
    continue
  fi
  fzf_args+=("$1")
  shift
done

quoted_fzf_args=$(printf '%q ' "${fzf_args[@]}")
quoted_path=$(printf '%q' "$PATH")
cat > "$popup_script" <<EOF
#!/usr/bin/env bash
set -uo pipefail
export PATH=$quoted_path
fzf $quoted_fzf_args --no-height --bind=ctrl-z:ignore --no-tmux < "$input_file" > "$output_file"
printf '%s\n' "\$?" > "$status_file"
EOF
chmod +x "$popup_script"

if tmux popup -d "$PWD" -E "${popup_args[@]}" "bash $(printf '%q' "$popup_script")" >/dev/null 2>&1 && [[ -f "$status_file" ]]; then
  cat "$output_file"
  exit "$(cat "$status_file" 2>/dev/null || echo 1)"
fi

cat "$input_file" | fzf-tmux -p "$width,$height" "${original_args[@]}"
