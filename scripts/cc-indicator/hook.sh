#!/usr/bin/env bash
# Claude Code hook handler for cc-indicator.
#
# Usage (in ~/.claude/settings.json):
#   "command": "bash ~/projects/toolbox/scripts/cc-indicator/hook.sh <event>"
#
# event ∈ { Stop, Notification, UserPromptSubmit, PreToolUse, PostToolUse,
#           SessionEnd }
#
# Reads hook JSON payload from stdin, extracts session_id, writes/clears
# state file at ~/.claude/cc-indicator/sessions/<session_id>.

set -euo pipefail

event="${1:-}"
[ -z "$event" ] && exit 0

# Hooks must never block the session. Cap any failure here.
payload=$(cat || true)

sid=$(printf '%s' "$payload" | /usr/bin/python3 -c '
import json, sys
try:
    d = json.loads(sys.stdin.read() or "{}")
    print(d.get("session_id", ""), end="")
except Exception:
    pass
' 2>/dev/null || true)

[ -z "$sid" ] && exit 0

dir="$HOME/.claude/cc-indicator/sessions"
mkdir -p "$dir"
file="$dir/$sid"

write_state() {
  printf '%s' "$1" > "$file.tmp"
  mv -f "$file.tmp" "$file"
}

case "$event" in
  Notification)
    write_state blocked
    ;;
  Stop)
    # assistant finished its turn — ready for review.
    # always wins over any prior blocked state (approval was resolved if
    # the turn reached Stop).
    write_state review
    ;;
  UserPromptSubmit|PreToolUse|PostToolUse)
    rm -f "$file"
    ;;
  SessionEnd)
    rm -f "$file"
    ;;
esac

exit 0
