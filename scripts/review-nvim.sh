#!/usr/bin/env bash
# Open nvim in a new terminal tab, focused on git working-tree changes
# (modified + deleted + untracked) via diffview.nvim.
#
# Usage:
#   review-nvim.sh [project_dir]
#
# Defaults to $PWD. Uses TOOLBOX_TERMINAL env (default: iterm).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/terminal.sh
source "$SCRIPT_DIR/lib/terminal.sh"

PROJECT_DIR="${1:-$PWD}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

if [ ! -d "$PROJECT_DIR/.git" ] && ! git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  echo "warning: $PROJECT_DIR is not a git repo. nvim will open without diff view." >&2
  open_terminal_tab "$PROJECT_DIR" "nvim ."
  exit 0
fi

# :Review loads all changed + untracked files vs HEAD into arglist,
# opens first file in single pane with gitsigns inline diff markers.
open_terminal_tab "$PROJECT_DIR" "nvim +Review"
