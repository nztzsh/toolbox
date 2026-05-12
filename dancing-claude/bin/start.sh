#!/usr/bin/env bash
# Start Dancing Claude in a small tmux pane above the current pane.
# Pane border is styled to blend with the surrounding window.
#
# Usage:
#   bin/start.sh [rows]
#
# Default pane height is 6 rows. Override border colors with:
#   DANCING_CLAUDE_BORDER_FG=<tmux-color> DANCING_CLAUDE_BORDER_BG=<tmux-color>
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
ROWS="${1:-6}"
STATE_DIR="$HOME/.cache/dancing-claude"
PANE_FILE="$STATE_DIR/pane.id"

mkdir -p "$STATE_DIR"

# numeric validation
if ! [[ "$ROWS" =~ ^[0-9]+$ ]] || [ "$ROWS" -lt 2 ] || [ "$ROWS" -gt 30 ]; then
  echo "error: rows must be an integer in [2, 30] (got: $ROWS)" >&2
  exit 2
fi

# tmux available?
if ! command -v tmux >/dev/null 2>&1; then
  cat >&2 <<'MSG'
error: tmux is not installed.

Install it (e.g. brew install tmux), start a session (tmux new -s claude),
run Claude Code inside that session, then re-run this script.
MSG
  exit 3
fi

# inside a tmux session?
if [ -z "${TMUX:-}" ]; then
  cat >&2 <<'MSG'
error: not inside a tmux session.

  tmux new -s claude        # start a session
  claude                    # run Claude Code in it
  ./bin/start.sh            # then run this from another pane in the same session

The dancer lives in a pane of the *current* tmux session, which is why this
shell has to be inside tmux too.
MSG
  exit 4
fi

# venv present?
PYTHON="$HERE/.venv/bin/python"
if [ ! -x "$PYTHON" ]; then
  cat >&2 <<MSG
error: venv missing at $PYTHON

Run setup first:
  $HERE/setup/install.sh
MSG
  exit 5
fi

# deps importable?
if ! "$PYTHON" -c "import sounddevice, numpy" >/dev/null 2>&1; then
  cat >&2 <<MSG
error: Python dependencies missing in venv.

Reinstall:
  $HERE/setup/install.sh
MSG
  exit 5
fi

# already running?
if [ -f "$PANE_FILE" ]; then
  EXISTING="$(cat "$PANE_FILE")"
  if tmux list-panes -a -F "#{pane_id}" 2>/dev/null | grep -qx "$EXISTING"; then
    echo "Dancing Claude already running in pane $EXISTING — stop first with ./bin/stop.sh" >&2
    exit 6
  fi
  # stale pidfile from a previous tmux session
  rm -f "$PANE_FILE"
fi

# audio device hint (non-fatal)
if ! "$PYTHON" - <<'PY' 2>/dev/null
import sys
import sounddevice as sd
for d in sd.query_devices():
    if "blackhole" in d["name"].lower() and d["max_input_channels"] > 0:
        sys.exit(0)
sys.exit(1)
PY
then
  echo "warning: BlackHole input device not detected — dancer will use the default mic" >&2
fi

# capture origin pane (where the user invoked us, i.e. Claude Code)
ORIGIN_PANE="$(tmux display-message -p '#{pane_id}')"

# style separator to blend (must be set at server scope, not pane scope)
BORDER_FG="${DANCING_CLAUDE_BORDER_FG:-colour0}"
BORDER_BG="${DANCING_CLAUDE_BORDER_BG:-default}"
tmux set-option -w pane-border-status off >/dev/null
tmux set-option -w pane-border-style "fg=${BORDER_FG},bg=${BORDER_BG}" >/dev/null
tmux set-option -w pane-active-border-style "fg=${BORDER_FG},bg=${BORDER_BG}" >/dev/null
tmux set-option -w pane-border-indicators off >/dev/null 2>&1 || true
tmux set-option -w pane-border-lines simple >/dev/null 2>&1 || true

# split current pane: vertical, before (above), length=ROWS, detach focus
NEW_PANE="$(tmux split-window \
    -v -b -l "$ROWS" -d \
    -P -F '#{pane_id}' \
    -t "$ORIGIN_PANE" \
    "$PYTHON $HERE/bin/dance.py" 2>&1)" || {
  echo "error: tmux split-window failed: $NEW_PANE" >&2
  exit 7
}

echo "$NEW_PANE" > "$PANE_FILE"

tmux set-option -p -t "$NEW_PANE" remain-on-exit off >/dev/null 2>&1 || true
tmux set-option -p -t "$NEW_PANE" pane-border-status off >/dev/null 2>&1 || true

# keep focus on the Claude Code pane
tmux select-pane -t "$ORIGIN_PANE" >/dev/null 2>&1 || true

echo "Dancing Claude started — pane $NEW_PANE, ${ROWS} rows."
echo "Stop with: $HERE/bin/stop.sh"
