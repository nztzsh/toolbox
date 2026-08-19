#!/usr/bin/env bash
# Start Dancing Claude in a small tmux pane above the current pane, and
# also fan out lightweight viewer panes to every *other* window in the
# same session so the dancer is visible everywhere.
#
# Architecture: one producer (dance.py) renders ANSI frames and mirrors
# each frame to $STATE_DIR/frame.ansi. Viewer panes poll that file and
# redraw. A tmux `after-new-window` hook auto-splits a viewer into any
# future window created in this session.
#
# Usage:
#   bin/start.sh [rows]
#
# Default pane height is 6 rows. Override border colors with:
#   DANCING_CLAUDE_BORDER_FG=<tmux-color> DANCING_CLAUDE_BORDER_BG=<tmux-color>
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$HERE/bin"
ROWS="${1:-6}"
STATE_DIR="$HOME/.cache/dancing-claude"
PANE_FILE="$STATE_DIR/pane.id"
VIEWERS_FILE="$STATE_DIR/viewers.ids"
SESSION_FILE="$STATE_DIR/session.id"
ROWS_FILE="$STATE_DIR/rows"
BORDER_FILE="$STATE_DIR/border.env"
FRAME_FILE="$STATE_DIR/frame.ansi"
HOOK_INDEX=100  # arbitrary slot in after-new-window hook array

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

# Resolve the origin pane (where the dancer should appear). Normally we run
# inside tmux and use the current pane. But Claude Code agents / background
# jobs spawn shells that don't inherit $TMUX even when the user's Claude pane
# lives in tmux — so fall back to asking the tmux server for the most
# recently active attached client and use its active pane. An explicit
# DANCING_CLAUDE_PANE=<pane-id> overrides both.
resolve_origin_pane() {
  if [ -n "${DANCING_CLAUDE_PANE:-}" ]; then
    printf '%s\n' "$DANCING_CLAUDE_PANE"
    return 0
  fi
  if [ -n "${TMUX:-}" ]; then
    tmux display-message -p '#{pane_id}'
    return 0
  fi
  # outside tmux: most recently active attached client's active pane
  local client
  client="$(tmux list-clients -F '#{client_activity} #{client_tty}' 2>/dev/null \
      | sort -rn | awk 'NR==1{print $2}')"
  if [ -n "$client" ]; then
    tmux display-message -p -c "$client" '#{pane_id}'
    return 0
  fi
  # no attached client: most recently attached session's active pane
  local session
  session="$(tmux list-sessions -F '#{session_last_attached} #{session_id}' 2>/dev/null \
      | sort -rn | awk 'NR==1{print $2}')"
  if [ -n "$session" ]; then
    tmux display-message -p -t "$session" '#{pane_id}'
    return 0
  fi
  return 1
}

if ! ORIGIN_PANE="$(resolve_origin_pane)" || [ -z "$ORIGIN_PANE" ]; then
  cat >&2 <<'MSG'
error: no tmux session found.

  tmux new -s claude        # start a session
  claude                    # run Claude Code in it
  ./bin/start.sh            # then run this (any shell on this machine works —
                            # the script finds the attached tmux client itself)

The dancer lives in a pane of a running tmux session, so the tmux server must
have at least one session.
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
    echo "Dancing Claude already running in pane $EXISTING — stop first with $BIN/stop.sh" >&2
    exit 6
  fi
  # stale pidfile from a previous tmux session
  rm -f "$PANE_FILE" "$VIEWERS_FILE" "$SESSION_FILE" "$ROWS_FILE"
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

# clear any stale frame from a previous run
rm -f "$FRAME_FILE" "$FRAME_FILE.tmp"

# derive window/session from the origin pane (resolved above; works whether
# or not this shell itself is inside tmux)
ORIGIN_WINDOW="$(tmux display-message -p -t "$ORIGIN_PANE" '#{window_id}')"
ORIGIN_SESSION="$(tmux display-message -p -t "$ORIGIN_PANE" '#{session_id}')"

# style separator to blend. We apply window-scoped (-w) settings per window
# because each window needs them independently. apply_border_style is reused
# for the origin window, the fan-out loop, and (via state file) auto-viewer.sh
# for windows created after start.
BORDER_FG="${DANCING_CLAUDE_BORDER_FG:-colour0}"
BORDER_BG="${DANCING_CLAUDE_BORDER_BG:-default}"
cat > "$BORDER_FILE" <<EOF
BORDER_FG=$BORDER_FG
BORDER_BG=$BORDER_BG
EOF

apply_border_style() {
  local win="$1"
  tmux set-option -w -t "$win" pane-border-status off >/dev/null 2>&1 || true
  tmux set-option -w -t "$win" pane-border-style "fg=${BORDER_FG},bg=${BORDER_BG}" >/dev/null 2>&1 || true
  tmux set-option -w -t "$win" pane-active-border-style "fg=${BORDER_FG},bg=${BORDER_BG}" >/dev/null 2>&1 || true
  tmux set-option -w -t "$win" pane-border-indicators off >/dev/null 2>&1 || true
  tmux set-option -w -t "$win" pane-border-lines simple >/dev/null 2>&1 || true
}

apply_border_style "$ORIGIN_WINDOW"

# split origin pane: vertical, before (above), length=ROWS, detach focus
NEW_PANE="$(tmux split-window \
    -v -b -l "$ROWS" -d \
    -P -F '#{pane_id}' \
    -t "$ORIGIN_PANE" \
    "$PYTHON $HERE/bin/dance.py" 2>&1)" || {
  echo "error: tmux split-window failed: $NEW_PANE" >&2
  exit 7
}

echo "$NEW_PANE"      > "$PANE_FILE"
echo "$ORIGIN_SESSION" > "$SESSION_FILE"
echo "$ROWS"          > "$ROWS_FILE"
: > "$VIEWERS_FILE"  # truncate

tmux set-option -p -t "$NEW_PANE" remain-on-exit off >/dev/null 2>&1 || true
tmux set-option -p -t "$NEW_PANE" pane-border-status off >/dev/null 2>&1 || true

# fan out viewer panes to every OTHER window in this session
VIEWER_SH="$BIN/viewer.sh"
while IFS= read -r WIN; do
  [ -n "$WIN" ] || continue
  [ "$WIN" = "$ORIGIN_WINDOW" ] && continue
  apply_border_style "$WIN"
  V_PANE="$(tmux split-window \
      -v -b -l "$ROWS" -d \
      -P -F '#{pane_id}' \
      -t "$WIN" \
      "$VIEWER_SH" 2>/dev/null)" || continue
  tmux set-option -p -t "$V_PANE" remain-on-exit off >/dev/null 2>&1 || true
  tmux set-option -p -t "$V_PANE" pane-border-status off >/dev/null 2>&1 || true
  printf '%s\n' "$V_PANE" >> "$VIEWERS_FILE"
done < <(tmux list-windows -t "$ORIGIN_SESSION" -F '#{window_id}' 2>/dev/null)

# install after-new-window hook so future windows in this session also get
# a viewer. Indexed slot so stop.sh can remove ours without clobbering
# anything else the user has bound to the same hook.
tmux set-hook -g "after-new-window[$HOOK_INDEX]" \
  "run-shell -b '$BIN/auto-viewer.sh #{window_id}'" >/dev/null 2>&1 || true

# keep focus on the Claude Code pane
tmux select-pane -t "$ORIGIN_PANE" >/dev/null 2>&1 || true

VIEWER_COUNT="$(wc -l < "$VIEWERS_FILE" | tr -d ' ')"
echo "Dancing Claude started — producer pane $NEW_PANE, ${ROWS} rows, ${VIEWER_COUNT} viewer pane(s) in other windows."
echo "Stop with: $BIN/stop.sh"
