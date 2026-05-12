#!/usr/bin/env bash
# Stop Dancing Claude (kill its tmux pane).
# Exit codes: 0 stopped (or already stopped), 1 tmux not available.
set -euo pipefail

STATE_DIR="$HOME/.cache/dancing-claude"
PANE_FILE="$STATE_DIR/pane.id"

if ! command -v tmux >/dev/null 2>&1; then
  echo "error: tmux not installed" >&2
  exit 1
fi

if [ ! -f "$PANE_FILE" ]; then
  echo "Dancing Claude is not running (no pidfile)."
  exit 0
fi

PANE="$(cat "$PANE_FILE")"

if tmux list-panes -a -F "#{pane_id}" 2>/dev/null | grep -qx "$PANE"; then
  if tmux kill-pane -t "$PANE" 2>/dev/null; then
    echo "Stopped — killed pane $PANE."
  else
    echo "warning: pane $PANE existed but kill-pane failed; you may need to remove it manually" >&2
  fi
else
  echo "Pane $PANE no longer exists; cleaning up pidfile."
fi

rm -f "$PANE_FILE"
