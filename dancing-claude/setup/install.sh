#!/usr/bin/env bash
# Set up the dancing-claude venv in this repo.
# After this, run `bin/start.sh` from inside a tmux session.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"

PYTHON_BIN="${PYTHON_BIN:-$(command -v python3)}"
if [ -z "$PYTHON_BIN" ]; then
  echo "python3 not found on PATH" >&2
  exit 1
fi

if [ ! -d .venv ]; then
  echo "==> Creating venv with $PYTHON_BIN ($($PYTHON_BIN --version 2>&1))"
  "$PYTHON_BIN" -m venv .venv
fi

echo "==> Installing dependencies"
.venv/bin/pip install --quiet --upgrade pip
.venv/bin/pip install --quiet -r requirements.txt

cat <<'NEXT'

Done.

  1. Start a tmux session if you aren't already in one:   tmux new -s claude
  2. Run Claude Code in that session as usual.
  3. From the same shell, start the dancer above your shell pane:
       ./bin/start.sh           # default 6-row dancer pane
       ./bin/start.sh 4         # smaller / bigger as you like
  4. Stop with:
       ./bin/stop.sh

System audio routing (one-time, in macOS Audio MIDI Setup):
  - Create a Multi-Output Device combining BlackHole 2ch + your speakers.
  - Set that Multi-Output Device as the system output while music plays.

Add new moves by dropping JSON files into moves/ — hot-reloaded within ~1s.
NEXT
