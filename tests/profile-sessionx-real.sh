#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_SCRIPT="$ROOT_DIR/sessionx.tmux"
RUNS="${1:-5}"

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
WRAP_TMUX="$WRAP_BIN/tmux"
TMUX_LOG="$TMP_DIR/tmux.log"
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

cat > "$WRAP_TMUX" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ -n "\${SESSIONX_REAL_LOG:-}" ]]; then
  printf '%s\t%s\n' "\${EPOCHREALTIME:-0}" "tmux \$*" >> "\${SESSIONX_REAL_LOG}"
fi
exec "$REAL_TMUX" "\$@"
EOF
chmod +x "$WRAP_TMUX"

SOCK_NAME="sessionx-real-$$"
ENV_PATH="$WRAP_BIN:$PATH"
export SESSIONX_REAL_LOG="$TMUX_LOG"

env PATH="$ENV_PATH" TMUX_TMPDIR="$TMP_DIR" "$REAL_TMUX" -f /dev/null -L "$SOCK_NAME" new-session -d -s work
env PATH="$ENV_PATH" TMUX_TMPDIR="$TMP_DIR" "$REAL_TMUX" -L "$SOCK_NAME" new-session -d -s alpha
env PATH="$ENV_PATH" TMUX_TMPDIR="$TMP_DIR" "$REAL_TMUX" -L "$SOCK_NAME" new-session -d -s beta
env PATH="$ENV_PATH" TMUX_TMPDIR="$TMP_DIR" "$REAL_TMUX" -L "$SOCK_NAME" set-option -g @sessionx-prefix off
env PATH="$ENV_PATH" TMUX_TMPDIR="$TMP_DIR" "$REAL_TMUX" -L "$SOCK_NAME" set-option -g @sessionx-bind O
env PATH="$ENV_PATH" TMUX_TMPDIR="$TMP_DIR" "$REAL_TMUX" -L "$SOCK_NAME" run-shell "$PLUGIN_SCRIPT"
sleep 0.3

script -q /dev/null env PATH="$ENV_PATH" SESSIONX_REAL_LOG="$TMUX_LOG" TMUX_TMPDIR="$TMP_DIR" "$REAL_TMUX" -L "$SOCK_NAME" attach -t work >/dev/null 2>&1 &
ATTACH_PID=$!

CLIENT_TTY=""
for _ in $(seq 1 100); do
  CLIENT_TTY=$(TMUX_TMPDIR="$TMP_DIR" "$REAL_TMUX" -L "$SOCK_NAME" list-clients -F '#{client_tty}' 2>/dev/null | head -1 || true)
  if [[ -n "$CLIENT_TTY" ]]; then
    break
  fi
  sleep 0.05
done

if [[ -z "$CLIENT_TTY" ]]; then
  echo "Failed to attach a real tmux client" >&2
  exit 1
fi

python3 - <<'PY' "$RUNS" "$TMUX_LOG" "$SOCK_NAME" "$TMP_DIR" "$CLIENT_TTY" "$WRAP_TMUX"
import os
import pathlib
import re
import statistics
import subprocess
import sys
import time

runs = int(sys.argv[1])
log_path = pathlib.Path(sys.argv[2])
sock_name = sys.argv[3]
tmp_dir = sys.argv[4]
initial_client_tty = sys.argv[5]
wrap_tmux = sys.argv[6]

def tmux(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env['TMUX_TMPDIR'] = tmp_dir
    env['SESSIONX_REAL_LOG'] = str(log_path)
    return subprocess.run([wrap_tmux, '-L', sock_name, *args], env=env, text=True, capture_output=True, check=check)

def current_client_tty() -> str:
    result = tmux('list-clients', '-F', '#{client_tty}')
    clients = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    if clients:
        return clients[0]
    return initial_client_tty

deltas: list[float] = []
last_client_tty = initial_client_tty

for _ in range(runs):
    before = log_path.read_text() if log_path.exists() else ''
    last_client_tty = current_client_tty()
    send_result = tmux('send-keys', '-K', 'O', check=False)
    if send_result.returncode != 0:
        raise SystemExit(f'Failed to send O to tmux client: {send_result.stderr.strip()}')
    start = time.time()
    popup_ts = None
    key_ts = None
    while time.time() - start < 5.0:
        content = log_path.read_text()
        new_text = content[len(before):]
        for line in new_text.splitlines():
            if not line.strip():
                continue
            ts_text, command = line.split('\t', 1)
            ts = float(ts_text)
            if key_ts is None and 'send-keys -K O' in command:
                key_ts = ts
            if key_ts is not None and re.search(r'\btmux (?:popup|display-popup)\b', command):
                popup_ts = ts
                break
        if popup_ts is not None:
            break
        time.sleep(0.01)

    if key_ts is None or popup_ts is None:
        raise SystemExit('Failed to observe keypress or popup in tmux log')

    deltas.append((popup_ts - key_ts) * 1000.0)
    tmux('send-keys', '-K', 'Escape', check=False)
    time.sleep(0.15)

print(f'Real tmux sessionx popup timing over {runs} run(s)')
print(f'Client tty: {last_client_tty}')
print()
print('run  key_to_popup_ms')
print('---  ---------------')
for index, delta in enumerate(deltas, start=1):
    print(f'{index:>3}  {delta:>15.3f}')
print()
print(f'average_ms: {statistics.mean(deltas):.3f}')
print(f'median_ms:  {statistics.median(deltas):.3f}')
print(f'min_ms:     {min(deltas):.3f}')
print(f'max_ms:     {max(deltas):.3f}')
PY
