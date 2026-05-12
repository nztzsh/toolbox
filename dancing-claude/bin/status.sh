#!/usr/bin/env bash
# Report whether Dancing Claude is currently running.
# Exit codes: 0 running, 1 stopped, 2 stale pidfile, 3 tmux not running.
set -euo pipefail

STATE_DIR="$HOME/.cache/dancing-claude"
PANE_FILE="$STATE_DIR/pane.id"

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux not installed"
  exit 3
fi

if ! tmux info >/dev/null 2>&1; then
  echo "no tmux server running"
  exit 3
fi

if [ ! -f "$PANE_FILE" ]; then
  echo "stopped"
  exit 1
fi

PANE="$(cat "$PANE_FILE")"
if tmux list-panes -a -F "#{pane_id}" 2>/dev/null | grep -qx "$PANE"; then
  SIZE="$(tmux display-message -p -t "$PANE" '#{pane_width}x#{pane_height}' 2>/dev/null || echo '?x?')"
  echo "running — pane $PANE (${SIZE})"
  exit 0
fi

echo "stale pidfile — pane $PANE no longer exists (cleaned up)"
rm -f "$PANE_FILE"
exit 2
