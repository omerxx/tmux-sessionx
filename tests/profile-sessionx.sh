#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_SCRIPT="$ROOT_DIR/scripts/sessionx.sh"
SCENARIO="${1:-existing}"

if [[ ! -f "$TARGET_SCRIPT" ]]; then
  echo "Could not find $TARGET_SCRIPT" >&2
  exit 1
fi

if [[ -z "${EPOCHREALTIME:-}" ]]; then
  echo "This profiling test requires Bash 5+ (EPOCHREALTIME support)." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

MOCK_BIN="$TMP_DIR/bin"
HOME_DIR="$TMP_DIR/home"
TRACE_FILE="$TMP_DIR/xtrace.log"
STDOUT_FILE="$TMP_DIR/stdout.log"
STDERR_FILE="$TMP_DIR/stderr.log"
COMMAND_LOG="$TMP_DIR/commands.log"
mkdir -p "$MOCK_BIN" "$HOME_DIR/.config/tmuxinator"

WINDOW_MODE="off"
CUSTOM_PATHS=""
SELECTION="alpha"
EXISTING_TARGETS=$'work\nalpha'

case "$SCENARIO" in
  existing)
    ;;
  new)
    SELECTION="new-project"
    ;;
  directory)
    PROJECT_DIR="$TMP_DIR/projects/demo"
    mkdir -p "$PROJECT_DIR"
    CUSTOM_PATHS="$PROJECT_DIR"
    SELECTION="$PROJECT_DIR"
    ;;
  window)
    WINDOW_MODE="on"
    SELECTION="alpha:1 editor"
    ;;
  *)
    echo "Unknown scenario: $SCENARIO" >&2
    echo "Usage: tests/profile-sessionx.sh [existing|new|directory|window]" >&2
    exit 1
    ;;
esac

cat <<'EOF' > "$MOCK_BIN/tmux"
#!/usr/bin/env bash
set -euo pipefail

log_cmd() {
  printf 'tmux %s\n' "$*" >> "$SESSIONX_PROFILE_COMMAND_LOG"
}

extract_target() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      -t=*)
        printf '%s\n' "${arg#-t=}"
        return 0
        ;;
      -t)
        shift
        printf '%s\n' "$1"
        return 0
        ;;
    esac
  done
  printf '%s\n' "${*: -1}"
}

command_name="${1:-}"
shift || true

case "$command_name" in
  display-message)
    log_cmd "display-message $*"
    case "${*: -1}" in
      '#S')
        printf 'work\n'
        ;;
      '#{client_last_session}')
        printf 'alpha\n'
        ;;
      '#S\t#{client_last_session}')
        printf 'work\talpha\n'
        ;;
      *)
        printf '\n'
        ;;
    esac
    ;;
  list-sessions)
    log_cmd "list-sessions $*"
    printf 'work: 1 windows (created Tue)\n'
    printf 'alpha: 1 windows (created Tue)\n'
    ;;
  list-windows)
    log_cmd "list-windows $*"
    printf 'work:0 shell\n'
    printf 'alpha:1 editor\n'
    ;;
  show-option)
    log_cmd "show-option $*"
    option="${*: -1}"
    case "$option" in
      @sessionx-zoxide-mode) printf 'off\n' ;;
      @sessionx-_built-args) printf 'declare -a args=()\n' ;;
      @sessionx-_built-fzf-opts) printf 'declare -a fzf_opts=()\n' ;;
      @sessionx-_window-mode) printf '%s\n' "${SESSIONX_PROFILE_WINDOW_MODE:-off}" ;;
      @sessionx-_filter-current) printf 'true\n' ;;
      @sessionx-_bind-back) printf 'ctrl-b\n' ;;
      @sessionx-_git-branch) printf 'off\n' ;;
      @sessionx-_fzf-builtin-tmux) printf 'off\n' ;;
      @sessionx-_custom-paths) printf '%s\n' "${SESSIONX_PROFILE_CUSTOM_PATHS:-}" ;;
      @sessionx-_custom-paths-subdirectories) printf 'false\n' ;;
      @sessionx-_filtered-sessions) printf '\n' ;;
      *) printf '\n' ;;
    esac
    ;;
  has-session)
    log_cmd "has-session $*"
    target="$(extract_target "$@")"
    base_target="${target%%:*}"
    while IFS= read -r existing; do
      [[ -z "$existing" ]] && continue
      if [[ "$existing" == "$target" || "$existing" == "$base_target" ]]; then
        exit 0
      fi
    done <<< "${SESSIONX_PROFILE_EXISTING_TARGETS:-}"
    exit 1
    ;;
  new-session)
    log_cmd "new-session $*"
    ;;
  switch-client)
    log_cmd "switch-client $*"
    ;;
  list-panes)
    log_cmd "list-panes $*"
    printf '%s\n' "$PWD"
    ;;
  *)
    log_cmd "$command_name $*"
    ;;
esac
EOF
chmod +x "$MOCK_BIN/tmux"

cat <<'EOF' > "$MOCK_BIN/fzf-tmux"
#!/usr/bin/env bash
set -euo pipefail
printf 'fzf-tmux %s\n' "$*" >> "$SESSIONX_PROFILE_COMMAND_LOG"
cat >/dev/null
printf '%s\n' "$SESSIONX_PROFILE_SELECTION"
EOF
chmod +x "$MOCK_BIN/fzf-tmux"

cat <<'EOF' > "$MOCK_BIN/fzf"
#!/usr/bin/env bash
set -euo pipefail
printf 'fzf %s\n' "$*" >> "$SESSIONX_PROFILE_COMMAND_LOG"
cat >/dev/null
printf '%s\n' "$SESSIONX_PROFILE_SELECTION"
EOF
chmod +x "$MOCK_BIN/fzf"

cat <<'EOF' > "$MOCK_BIN/zoxide"
#!/usr/bin/env bash
set -euo pipefail
printf 'zoxide %s\n' "$*" >> "$SESSIONX_PROFILE_COMMAND_LOG"
printf '%s\n' "$PWD"
EOF
chmod +x "$MOCK_BIN/zoxide"

cat <<'EOF' > "$MOCK_BIN/tmuxinator"
#!/usr/bin/env bash
set -euo pipefail
printf 'tmuxinator %s\n' "$*" >> "$SESSIONX_PROFILE_COMMAND_LOG"
case "${1:-}" in
  list)
    printf 'demo\n'
    ;;
  start)
    printf 'started %s\n' "${2:-}"
    ;;
esac
EOF
chmod +x "$MOCK_BIN/tmuxinator"

export PATH="$MOCK_BIN:$PATH"
export HOME="$HOME_DIR"
export SESSIONX_PROFILE_WINDOW_MODE="$WINDOW_MODE"
export SESSIONX_PROFILE_CUSTOM_PATHS="$CUSTOM_PATHS"
export SESSIONX_PROFILE_SELECTION="$SELECTION"
export SESSIONX_PROFILE_EXISTING_TARGETS="$EXISTING_TARGETS"
export SESSIONX_PROFILE_COMMAND_LOG="$COMMAND_LOG"

export PS4=$'+__TRACE__\t${EPOCHREALTIME}\t${BASH_SOURCE}\t${LINENO}\t${FUNCNAME[0]:-MAIN}\t'
exec 3> "$TRACE_FILE"
export BASH_XTRACEFD=3

bash -x "$TARGET_SCRIPT" > "$STDOUT_FILE" 2> "$STDERR_FILE"

python3 - "$TRACE_FILE" "$TARGET_SCRIPT" "$SCENARIO" "$COMMAND_LOG" "$STDOUT_FILE" "$STDERR_FILE" <<'PY'
import collections
import pathlib
import sys

trace_path = pathlib.Path(sys.argv[1])
focus_script = str(pathlib.Path(sys.argv[2]).resolve())
scenario = sys.argv[3]
command_log = pathlib.Path(sys.argv[4])
stdout_path = pathlib.Path(sys.argv[5])
stderr_path = pathlib.Path(sys.argv[6])

Event = dict
all_events: list[Event] = []
for raw in trace_path.read_text().splitlines():
    if not raw.startswith('+__TRACE__\t'):
        continue
    parts = raw.split('\t', 5)
    if len(parts) < 6:
        continue
    _, ts, file_name, line, func, command = parts
    try:
        timestamp = float(ts)
    except ValueError:
        continue
    resolved = str(pathlib.Path(file_name).resolve())
    all_events.append(
        {
            'ts': timestamp,
            'file': resolved,
            'line': int(line),
            'func': func or 'MAIN',
            'command': command,
        }
    )

for index, event in enumerate(all_events):
    next_ts = all_events[index + 1]['ts'] if index + 1 < len(all_events) else None
    event['elapsed_ms'] = ((next_ts - event['ts']) * 1000.0) if next_ts is not None else None

focus_events = [event for event in all_events if event['file'] == focus_script]
function_totals: dict[str, float] = collections.defaultdict(float)
function_counts: dict[str, int] = collections.defaultdict(int)
for event in focus_events:
    if event['elapsed_ms'] is not None:
        function_totals[event['func']] += event['elapsed_ms']
    function_counts[event['func']] += 1

def format_ms(value: float | None) -> str:
    if value is None:
        return '   n/a'
    return f'{value:7.3f}'

def one_line(value: str) -> str:
    return value.replace('\\n', '\\\\n').strip()

print(f'SessionX profiling scenario: {scenario}')
print(f'Target script: {focus_script}')
print()
print('Command-level timings inside scripts/sessionx.sh')
print('elapsed_ms  line  function             command')
print('----------  ----  -------------------  -------')
for event in focus_events:
    print(f"{format_ms(event['elapsed_ms']):>10}  {event['line']:>4}  {event['func']:<19}  {one_line(event['command'])}")

print()
print('Function totals (inclusive of traced commands in scripts/sessionx.sh)')
print('total_ms   calls  function')
print('--------   -----  --------')
for func, total in sorted(function_totals.items(), key=lambda item: item[1], reverse=True):
    print(f'{total:8.3f}  {function_counts[func]:>5}  {func}')

stdout_text = stdout_path.read_text().strip()
stderr_text = stderr_path.read_text().strip()
command_lines = [line for line in command_log.read_text().splitlines() if line.strip()]

print()
print('Mock command log')
print('----------------')
for line in command_lines:
    print(one_line(line))

print()
print('Captured stdout')
print('---------------')
print(one_line(stdout_text) or '(empty)')

print()
print('Captured stderr')
print('---------------')
print(one_line(stderr_text) or '(empty)')
PY
