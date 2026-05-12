#!/usr/bin/env bash
# Scaffold a new move JSON. Daemon hot-reloads within ~1s — no restart.
# Usage:  add_move.sh <move-name>
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
NAME="${1:-}"

if [ -z "$NAME" ]; then
  echo "Usage: add_move.sh <move-name>" >&2
  exit 2
fi

SAFE="$(echo "$NAME" | tr ' ' '_' | tr -cd 'A-Za-z0-9_-')"
if [ -z "$SAFE" ]; then
  echo "Invalid name after sanitization (only A-Z, a-z, 0-9, '_', '-' allowed)" >&2
  exit 2
fi

FILE="$HERE/moves/${SAFE}.json"
if [ -e "$FILE" ]; then
  echo "$FILE already exists — pick a different name or edit the file directly" >&2
  exit 1
fi

cat > "$FILE" <<JSON
{
  "name": "${SAFE}",
  "bpm_range": [60, 200],
  "palette": [
    "#0000",
    "#1d1d1f",
    "#f5cba0",
    "#ffffff",
    "#7c5cff",
    "#3a2a8a",
    "#ff7a3c"
  ],
  "frames": [
    {
      "id": "A",
      "rows": [
        ".....1111....",
        "....111111...",
        "6...122221...",
        "66..121121...",
        ".....4444....",
        ".....5555...."
      ]
    },
    {
      "id": "B",
      "rows": [
        ".....1111....",
        "....111111...",
        "....122221..6",
        "....121121.66",
        ".....4444....",
        ".....5555...."
      ]
    }
  ],
  "choreo": {
    "on_kick": "cycle:A,B",
    "on_snare": "particle:burst",
    "on_drop": "palette_swap"
  }
}
JSON

echo "Created $FILE"
echo "Daemon will pick it up within ~1s if running. Edit the rows to design your pose."
