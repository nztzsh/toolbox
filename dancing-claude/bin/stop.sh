#!/usr/bin/env bash
# Stop Dancing Claude: kill producer pane, every fan-out viewer pane,
# remove the after-new-window hook, and clear shared state.
# Exit codes: 0 stopped (or already stopped), 1 tmux not available.
set -euo pipefail

STATE_DIR="$HOME/.cache/dancing-claude"
PANE_FILE="$STATE_DIR/pane.id"
VIEWERS_FILE="$STATE_DIR/viewers.ids"
SESSION_FILE="$STATE_DIR/session.id"
ROWS_FILE="$STATE_DIR/rows"
FRAME_FILE="$STATE_DIR/frame.ansi"
HOOK_INDEX=100

if ! command -v tmux >/dev/null 2>&1; then
  echo "error: tmux not installed" >&2
  exit 1
fi

# remove the auto-viewer hook unconditionally — cheap and idempotent
tmux set-hook -gu "after-new-window[$HOOK_INDEX]" >/dev/null 2>&1 || true

if [ ! -f "$PANE_FILE" ] && [ ! -f "$VIEWERS_FILE" ]; then
  echo "Dancing Claude is not running (no pidfile)."
  exit 0
fi

killed=0
missing=0

kill_pane() {
  local pane="$1"
  [ -n "$pane" ] || return 0
  if tmux list-panes -a -F "#{pane_id}" 2>/dev/null | grep -qx "$pane"; then
    if tmux kill-pane -t "$pane" 2>/dev/null; then
      killed=$((killed + 1))
    else
      echo "warning: kill-pane $pane failed; remove manually" >&2
    fi
  else
    missing=$((missing + 1))
  fi
}

# producer
if [ -f "$PANE_FILE" ]; then
  kill_pane "$(cat "$PANE_FILE")"
fi

# viewers
if [ -f "$VIEWERS_FILE" ]; then
  while IFS= read -r pane; do
    kill_pane "$pane"
  done < "$VIEWERS_FILE"
fi

rm -f "$PANE_FILE" "$VIEWERS_FILE" "$SESSION_FILE" "$ROWS_FILE" \
      "$STATE_DIR/border.env" "$FRAME_FILE" "$FRAME_FILE.tmp"

echo "Stopped — killed $killed pane(s)${missing:+, $missing already gone}."
