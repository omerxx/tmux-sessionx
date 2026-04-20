#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_SCRIPT="$ROOT_DIR/sessionx.tmux"
RUNS="${1:-7}"

if [[ ! -f "$PLUGIN_SCRIPT" ]]; then
  echo "Could not find $PLUGIN_SCRIPT" >&2
  exit 1
fi

REAL_TMUX="$(command -v tmux)"
if [[ -z "$REAL_TMUX" ]]; then
  echo "tmux is required" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
WRAP_BIN="$TMP_DIR/bin"
mkdir -p "$WRAP_BIN"

cleanup() {
  if [[ -n "${SOCK_NAME:-}" ]]; then
    TMUX_TMPDIR="$TMP_DIR" "$REAL_TMUX" -L "$SOCK_NAME" kill-server >/dev/null 2>&1 || true
  fi
  if [[ -n "${ATTACH_PID:-}" ]]; then
    kill "$ATTACH_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat > "$WRAP_BIN/tmux" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ -n "\${SESSIONX_TMUX_LOG:-}" ]]; then
  printf '%s\t%s\n' "\${EPOCHREALTIME:-0}" "tmux \$*" >> "\${SESSIONX_TMUX_LOG}"
fi
exec "$REAL_TMUX" "\$@"
EOF
chmod +x "$WRAP_BIN/tmux"

cat > "$WRAP_BIN/fzf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cat >/dev/null || true
printf 'work\n'
EOF
chmod +x "$WRAP_BIN/fzf"

RUNNER="$TMP_DIR/run-sessionx.sh"
cat > "$RUNNER" <<EOF
#!/usr/bin/env bash
set -euo pipefail
run_id="\$1"
export PATH="$WRAP_BIN:\$PATH"
export SESSIONX_TMUX_LOG="$TMP_DIR/tmux-\$run_id.log"
: > "\$SESSIONX_TMUX_LOG"
printf '%s\n' "\${EPOCHREALTIME:-0}" > "$TMP_DIR/start-\$run_id.txt"
"$ROOT_DIR/scripts/sessionx.sh" >/dev/null 2>"$TMP_DIR/stderr-\$run_id.txt" || true
touch "$TMP_DIR/done-\$run_id"
EOF
chmod +x "$RUNNER"

SOCK_NAME="benchmark-popup-$$"
TMUX_TMPDIR="$TMP_DIR" "$REAL_TMUX" -f /dev/null -L "$SOCK_NAME" new-session -d -s work
TMUX_TMPDIR="$TMP_DIR" "$REAL_TMUX" -L "$SOCK_NAME" new-session -d -s alpha
TMUX_TMPDIR="$TMP_DIR" "$REAL_TMUX" -L "$SOCK_NAME" new-session -d -s beta
TMUX_TMPDIR="$TMP_DIR" "$REAL_TMUX" -L "$SOCK_NAME" run-shell "$PLUGIN_SCRIPT"

script -q /dev/null env TMUX_TMPDIR="$TMP_DIR" tmux -L "$SOCK_NAME" attach -t work >/dev/null 2>&1 &
ATTACH_PID=$!

CLIENTS=""
for _ in $(seq 1 100); do
  CLIENTS=$(TMUX_TMPDIR="$TMP_DIR" "$REAL_TMUX" -L "$SOCK_NAME" list-clients -F '#{client_tty}' 2>/dev/null || true)
  if [[ -n "$CLIENTS" ]]; then
    break
  fi
  sleep 0.05
done

if [[ -z "$CLIENTS" ]]; then
  echo "Failed to attach a real tmux client" >&2
  exit 1
fi

RESULTS=()
for run in $(seq 1 "$RUNS"); do
  rm -f "$TMP_DIR/done-$run" "$TMP_DIR/start-$run.txt" "$TMP_DIR/tmux-$run.log" "$TMP_DIR/stderr-$run.txt"
  TMUX_TMPDIR="$TMP_DIR" "$REAL_TMUX" -L "$SOCK_NAME" send-keys -t work:0 C-c
  TMUX_TMPDIR="$TMP_DIR" "$REAL_TMUX" -L "$SOCK_NAME" send-keys -t work:0 "$RUNNER $run" C-m

  for _ in $(seq 1 400); do
    if [[ -f "$TMP_DIR/done-$run" ]]; then
      break
    fi
    sleep 0.025
  done

  if [[ ! -f "$TMP_DIR/done-$run" ]]; then
    echo "Benchmark run $run did not complete" >&2
    TMUX_TMPDIR="$TMP_DIR" "$REAL_TMUX" -L "$SOCK_NAME" capture-pane -pt work:0 | tail -40 >&2
    exit 1
  fi

  popup_ms=$(python3 - <<'PY' "$TMP_DIR/start-$run.txt" "$TMP_DIR/tmux-$run.log"
import pathlib
import re
import sys

start = float(pathlib.Path(sys.argv[1]).read_text().strip())
popup_ts = None
for line in pathlib.Path(sys.argv[2]).read_text().splitlines():
    if not line.strip():
        continue
    ts_text, cmd = line.split('\t', 1)
    ts = float(ts_text)
    if ts >= start and re.search(r'\btmux (?:popup|display-popup)\b', cmd):
        popup_ts = ts
        break
if popup_ts is None:
    raise SystemExit('no popup timestamp found')
print(f'{(popup_ts - start) * 1000:.3f}')
PY
)
  RESULTS+=("$popup_ms")
  printf 'run_%02d_ms=%s\n' "$run" "$popup_ms"
  sleep 0.1
done

python3 - <<'PY' "${RESULTS[@]}"
import statistics
import sys

values = [float(value) for value in sys.argv[1:]]
print(f'metric_ms={statistics.median(values):.3f}')
print(f'avg_ms={statistics.mean(values):.3f}')
print(f'min_ms={min(values):.3f}')
print(f'max_ms={max(values):.3f}')
PY
