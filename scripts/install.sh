#!/usr/bin/env bash
# Symlink dotfiles + Claude commands from this toolbox into expected paths,
# install macOS deps, and wire Claude Code hooks for cc-indicator.
# Idempotent — safe to run repeatedly.
#
# Add new mappings by appending to the LINKS array below:
#   "<source-relative-to-toolbox>::<absolute-target>"

set -euo pipefail

TOOLBOX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LINKS=(
  "dotfiles/nvim::$HOME/.config/nvim"
  "dotfiles/hammerspoon::$HOME/.hammerspoon"
  "dotfiles/tmux/tmux.conf::$HOME/.tmux.conf"
  "claude/commands::$HOME/.claude/commands"
)

ts="$(date +%Y%m%d-%H%M%S)"

# ---- 1. symlinks ------------------------------------------------------------

link_one() {
  local src_rel="$1" target="$2"
  local src="$TOOLBOX_DIR/$src_rel"

  if [ ! -e "$src" ]; then
    echo "skip: source missing: $src" >&2
    return
  fi

  mkdir -p "$(dirname "$target")"

  if [ -L "$target" ]; then
    local current; current="$(readlink "$target")"
    if [ "$current" = "$src" ]; then
      echo "ok:   $target -> $src (already linked)"
      return
    fi
    echo "relink: $target was -> $current"
    rm "$target"
  elif [ -e "$target" ]; then
    local backup="${target}.bak-${ts}"
    echo "backup: $target -> $backup"
    mv "$target" "$backup"
  fi

  ln -s "$src" "$target"
  echo "link: $target -> $src"
}

for entry in "${LINKS[@]}"; do
  src_rel="${entry%%::*}"
  target="${entry##*::}"
  link_one "$src_rel" "$target"
done

# scripts executable (recursive across subdirs like cc-indicator/)
find "$TOOLBOX_DIR/scripts" -type f -name '*.sh' -exec chmod +x {} +

# ---- 2. macOS deps (cc-indicator) ------------------------------------------

is_macos() { [ "$(uname -s)" = "Darwin" ]; }

ensure_brew_pkg() {
  local kind="$1" pkg="$2" check="$3"
  if eval "$check" >/dev/null 2>&1; then
    echo "ok:   $pkg already installed"
    return
  fi
  if ! command -v brew >/dev/null 2>&1; then
    echo "warn: homebrew missing, skipping $pkg (install from https://brew.sh)" >&2
    return 1
  fi
  echo "==> brew install $kind $pkg"
  brew install "$kind" "$pkg"
}

if is_macos; then
  ensure_brew_pkg --cask hammerspoon  '[ -d /Applications/Hammerspoon.app ]' || true
  ensure_brew_pkg ""       jq          'command -v jq' || true
fi

# ---- 3. Claude Code hooks for cc-indicator ----------------------------------

CC_HOOK="$TOOLBOX_DIR/scripts/cc-indicator/hook.sh"
SETTINGS="$HOME/.claude/settings.json"

if command -v jq >/dev/null 2>&1 && [ -f "$CC_HOOK" ]; then
  mkdir -p "$HOME/.claude" "$HOME/.claude/cc-indicator/sessions"
  [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

  hook_prefix="bash $CC_HOOK"
  tmp=$(mktemp)

  # idempotent: skips events whose hooks[].command already starts with our
  # prefix + the event arg. preserves existing unrelated hooks.
  jq --arg hook "$hook_prefix" '
    def add_hook($event; $arg):
      .hooks[$event] = (.hooks[$event] // []) |
      if any(.hooks[$event][]?.hooks[]?; (.command // "") | startswith($hook + " " + $arg)) then .
      else .hooks[$event] += [{
        "hooks": [{"type":"command","command": ($hook + " " + $arg),"timeout": 5}]
      }] end;

    add_hook("Stop"; "Stop") |
    add_hook("Notification"; "Notification") |
    add_hook("UserPromptSubmit"; "UserPromptSubmit") |
    add_hook("PreToolUse"; "PreToolUse") |
    add_hook("PostToolUse"; "PostToolUse") |
    add_hook("SessionEnd"; "SessionEnd")
  ' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

  echo "ok:   cc-indicator hooks registered in $SETTINGS"
fi

# ---- 4. iTerm globals (so the tmux-keymap preset actually works) ------------
#
# iTerm's "⌘+Number switches tabs" and "⌘+Number+Option switches windows"
# defaults intercept Cmd-1..9 and Cmd-Opt-arrows BEFORE the profile key map
# fires, which silently breaks dotfiles/iterm/tmux-keymap.itermkeymap. Set
# both to "No Modifier" (tag 9 = kPreferenceModifierTagNone). Idempotent.

if is_macos; then
  for key in SwitchTabModifier SwitchWindowModifier; do
    current="$(defaults read com.googlecode.iterm2 "$key" 2>/dev/null || echo "")"
    if [ "$current" = "9" ]; then
      echo "ok:   iterm $key already disabled"
    else
      defaults write com.googlecode.iterm2 "$key" -int 9
      echo "set:  iterm $key -> 9 (no modifier; was: ${current:-default})"
    fi
  done
  echo "      (restart iTerm for these to take effect)"
fi

# ---- 5. start / reload Hammerspoon ------------------------------------------

if is_macos && [ -d /Applications/Hammerspoon.app ]; then
  if pgrep -x Hammerspoon >/dev/null 2>&1; then
    if /usr/bin/osascript -e 'tell application "Hammerspoon" to execute lua code "hs.reload()"' >/dev/null 2>&1; then
      echo "ok:   reloaded running Hammerspoon"
    else
      echo "warn: could not reload Hammerspoon via AppleScript"
      echo "      first run only: open Hammerspoon → Preferences → enable"
      echo "      'Launch Hammerspoon at login' and 'Enable Accessibility'"
    fi
  else
    open /Applications/Hammerspoon.app
    echo "ok:   launched Hammerspoon"
  fi

  # Accessibility check (ok if AppleScript IPC works at all → HS can probe)
  has_a11y=$(/usr/bin/osascript -e 'tell application "Hammerspoon" to execute lua code "return tostring(hs.accessibilityState())"' 2>/dev/null || echo unknown)
  if [ "$has_a11y" = "true" ]; then
    echo "ok:   Hammerspoon has Accessibility permission"
  else
    cat <<'EOF'

================================================================
ACTION REQUIRED — grant Hammerspoon Accessibility permission:

  System Settings → Privacy & Security → Accessibility
  → toggle Hammerspoon ON

Then re-run this script (or run `hs.reload()` from HS console).
================================================================
EOF
  fi
fi

# ---- summary ----------------------------------------------------------------

echo
echo "done. next steps:"
echo "  - install deps:  brew install neovim ripgrep fd tmux"
echo "  - launch nvim:   nvim   (vim.pack bootstraps plugins on first run)"
echo "  - test review:   bash $TOOLBOX_DIR/scripts/review-nvim.sh"
echo "  - cc-indicator:  state dir = $HOME/.claude/cc-indicator/sessions"
echo "  - iTerm keymap:  import $TOOLBOX_DIR/dotfiles/iterm/tmux-keymap.itermkeymap"
echo "                   (Settings → Profiles → Keys → Key Mappings → Presets… → Import)"
echo "  - reload tmux:   tmux source-file ~/.tmux.conf   (or restart server)"
echo "  - dancing-claude: bash $TOOLBOX_DIR/dancing-claude/setup/install.sh   (one-time venv)"
