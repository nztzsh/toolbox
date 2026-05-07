#!/usr/bin/env bash
# Pluggable terminal launcher. Add backends by implementing
# open_terminal_<name> and adding a case to open_terminal_tab.
#
# Contract:
#   open_terminal_tab <cwd> <command...>
#     Opens a NEW tab of the configured terminal (new window if none open),
#     cd's into <cwd>, then runs <command...>. Tab stays open after exit.

set -euo pipefail

_applescript_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

open_terminal_iterm() {
  local cwd="$1"; shift
  local cmd="$*"
  local full="cd $(printf '%q' "$cwd") && ${cmd}"
  local esc; esc=$(_applescript_escape "$full")

  /usr/bin/osascript <<EOF
tell application "iTerm"
  activate
  if (count of windows) = 0 then
    create window with default profile
  else
    tell current window
      create tab with default profile
    end tell
  end if
  tell current session of current window
    write text "${esc}"
  end tell
end tell
EOF
}

open_terminal_tab() {
  local backend="${TOOLBOX_TERMINAL:-iterm}"
  case "$backend" in
    iterm) open_terminal_iterm "$@" ;;
    *) echo "unsupported terminal backend: $backend" >&2; return 1 ;;
  esac
}
