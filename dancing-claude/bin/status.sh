#!/usr/bin/env bash
# Report whether Dancing Claude is currently running.
# Exit codes: 0 running, 1 stopped, 2 stale pidfile, 3 tmux not running.
set -euo pipefail

STATE_DIR="$HOME/.cache/dancing-claude"
PANE_FILE="$STATE_DIR/pane.id"
VIEWERS_FILE="$STATE_DIR/viewers.ids"

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
if ! tmux list-panes -a -F "#{pane_id}" 2>/dev/null | grep -qx "$PANE"; then
  echo "stale pidfile — pane $PANE no longer exists (cleaned up)"
  rm -f "$PANE_FILE" "$VIEWERS_FILE"
  exit 2
fi

SIZE="$(tmux display-message -p -t "$PANE" '#{pane_width}x#{pane_height}' 2>/dev/null || echo '?x?')"

# viewers — live vs total recorded
alive=0
total=0
if [ -f "$VIEWERS_FILE" ]; then
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    total=$((total + 1))
    if tmux list-panes -a -F "#{pane_id}" 2>/dev/null | grep -qx "$p"; then
      alive=$((alive + 1))
    fi
  done < "$VIEWERS_FILE"
fi

echo "running — producer pane $PANE (${SIZE}), viewers: $alive/$total alive"
exit 0
