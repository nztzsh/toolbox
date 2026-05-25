#!/usr/bin/env bash
# Dancing Claude frame viewer.
# Polls $STATE_DIR/frame.ansi at ~25fps and redraws into the current pane.
# One producer (dance.py) writes the file; multiple viewers (this script,
# one per tmux window) read it. Keeps a single logical dancer visible in
# every window of the session without running multiple dance.py instances.
set -u

STATE_DIR="${DANCING_CLAUDE_STATE_DIR:-$HOME/.cache/dancing-claude}"
FRAME="$STATE_DIR/frame.ansi"

# alt screen + hide cursor; restore on exit
printf '\033[?1049h\033[?25l\033[H\033[2J'
cleanup() {
  printf '\033[0m\033[?25h\033[?1049l'
}
trap cleanup EXIT INT TERM HUP

# 25fps poll. Always redraw (cheap) rather than mtime-diff — macOS `stat -f %m`
# is integer-second granularity, which loses sub-frame changes.
while :; do
  if [ -s "$FRAME" ]; then
    printf '\033[H'
    cat "$FRAME" 2>/dev/null || true
  fi
  sleep 0.04
done
