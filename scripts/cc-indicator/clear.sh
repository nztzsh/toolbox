#!/usr/bin/env bash
# Manually clear cc-indicator dots.
#
# Usage:
#   clear.sh review   # clear the green (review) dot
#   clear.sh blocked  # clear the red (blocked) dot
#   clear.sh all      # clear both

set -euo pipefail

which="${1:-}"
dir="$HOME/.claude/cc-indicator/sessions"

if [ ! -d "$dir" ]; then
  exit 0
fi

case "$which" in
  review|blocked)
    for f in "$dir"/*; do
      [ -e "$f" ] || continue
      state=$(head -n1 "$f" 2>/dev/null | tr -d '[:space:]')
      if [ "$state" = "$which" ]; then
        rm -f "$f"
      fi
    done
    # Tell hook.sh to skip the next matching write so the slash command's
    # own Stop event doesn't immediately repaint the dot we just cleared.
    : > "$dir/.suppress-$which"
    ;;
  all)
    rm -f "$dir"/*
    : > "$dir/.suppress-review"
    : > "$dir/.suppress-blocked"
    ;;
  *)
    echo "usage: $0 {review|blocked|all}" >&2
    exit 1
    ;;
esac
