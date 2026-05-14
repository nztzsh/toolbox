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

# Suppression: clear.sh drops a sentinel so subsequent matching writes are
# skipped until the user takes a new action.
#
# Two sentinel types with different consumption rules:
#   - suppress-review: consumed once by Stop (Stop fires once per turn).
#   - suppress-blocked: persistent, since Notification fires repeatedly while
#     idle. Cleared on the *next* UserPromptSubmit, with a grace window so a
#     UserPromptSubmit firing immediately after clear.sh (e.g. when a slash
#     command's `!bash` expansion sets the sentinel) does not wipe it before
#     the suppressed event arrives.
SUPPRESS_GRACE_SECS=5

suppress_active() {
  [ -f "$dir/.suppress-$1" ]
}

suppress_age() {
  local m="$dir/.suppress-$1"
  [ -f "$m" ] || { echo -1; return; }
  echo $(( $(date +%s) - $(stat -f %m "$m" 2>/dev/null || echo 0) ))
}

case "$event" in
  Notification)
    suppress_active blocked && exit 0
    write_state blocked
    ;;
  Stop)
    # assistant finished its turn — ready for review.
    # always wins over any prior blocked state (approval was resolved if
    # the turn reached Stop). Consume the sentinel after use.
    if suppress_active review; then
      rm -f "$file" "$dir/.suppress-review"
      exit 0
    fi
    write_state review
    ;;
  UserPromptSubmit)
    # New user turn — clear state. Clear suppression sentinels only if
    # they are older than the grace window; a freshly-set sentinel (from a
    # slash command's `!bash` expansion in this very prompt) must survive
    # so the upcoming Stop/Notification can honor it.
    rm -f "$file"
    age=$(suppress_age review)
    [ "$age" -ge 0 ] && [ "$age" -gt "$SUPPRESS_GRACE_SECS" ] && rm -f "$dir/.suppress-review"
    age=$(suppress_age blocked)
    [ "$age" -ge 0 ] && [ "$age" -gt "$SUPPRESS_GRACE_SECS" ] && rm -f "$dir/.suppress-blocked"
    ;;
  PreToolUse|PostToolUse)
    # Mid-turn tool activity — clear state only. Do NOT touch suppress
    # sentinels: clear.sh may run inside a Bash tool call, so wiping the
    # sentinel here would erase the suppression it just set.
    rm -f "$file"
    ;;
  SessionEnd)
    rm -f "$file" "$dir/.suppress-review" "$dir/.suppress-blocked"
    ;;
esac

exit 0
