#!/usr/bin/env bash
# Called by the tmux `after-new-window` hook installed by start.sh.
# Splits a viewer pane above the newly-created window — but only if the
# new window belongs to the same session that Dancing Claude was started in.
#
# Args: $1=window_id (e.g. @42)
# Note: we do NOT pass session_id from the hook because tmux substitutes
# #{session_id} as `$N` and the shell expands `$0` to its own argv[0]
# before the script sees it. We derive session_id from the window instead.
set -u

STATE_DIR="${DANCING_CLAUDE_STATE_DIR:-$HOME/.cache/dancing-claude}"
SESSION_FILE="$STATE_DIR/session.id"
ROWS_FILE="$STATE_DIR/rows"
VIEWERS_FILE="$STATE_DIR/viewers.ids"

# silently bail if dancer isn't running
[ -f "$SESSION_FILE" ] || exit 0
[ -f "$ROWS_FILE" ] || exit 0

TARGET_SESSION="$(cat "$SESSION_FILE")"
WINDOW_ID="${1:-}"
[ -n "$WINDOW_ID" ] || exit 0

SESSION_ID="$(tmux display-message -p -t "$WINDOW_ID" '#{session_id}' 2>/dev/null)"
[ -n "$SESSION_ID" ] || exit 0
[ "$SESSION_ID" = "$TARGET_SESSION" ] || exit 0

ROWS="$(cat "$ROWS_FILE")"
HERE="$(cd "$(dirname "$0")" && pwd)"
VIEWER_SH="$HERE/viewer.sh"

# apply border style matching producer's window so the split blends in
BORDER_FILE="$STATE_DIR/border.env"
if [ -f "$BORDER_FILE" ]; then
  # shellcheck disable=SC1090
  . "$BORDER_FILE"
  tmux set-option -w -t "$WINDOW_ID" pane-border-status off 2>/dev/null || true
  tmux set-option -w -t "$WINDOW_ID" pane-border-style "fg=${BORDER_FG},bg=${BORDER_BG}" 2>/dev/null || true
  tmux set-option -w -t "$WINDOW_ID" pane-active-border-style "fg=${BORDER_FG},bg=${BORDER_BG}" 2>/dev/null || true
  tmux set-option -w -t "$WINDOW_ID" pane-border-indicators off 2>/dev/null || true
  tmux set-option -w -t "$WINDOW_ID" pane-border-lines simple 2>/dev/null || true
fi

# split above the window's active pane and run viewer
NEW_PANE="$(tmux split-window \
    -v -b -l "$ROWS" -d \
    -P -F '#{pane_id}' \
    -t "$WINDOW_ID" \
    "$VIEWER_SH" 2>/dev/null)" || exit 0

tmux set-option -p -t "$NEW_PANE" remain-on-exit off 2>/dev/null || true
tmux set-option -p -t "$NEW_PANE" pane-border-status off 2>/dev/null || true

# atomic append (one-line writes are atomic for small lines on local fs)
printf '%s\n' "$NEW_PANE" >> "$VIEWERS_FILE"
