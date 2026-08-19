#!/usr/bin/env bash
# Symlink dotfiles + Claude commands from this toolbox into expected paths.
# Idempotent — safe to run repeatedly.
#
# Add new mappings by appending to the LINKS array below:
#   "<source-relative-to-toolbox>::<absolute-target>"

set -euo pipefail

TOOLBOX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LINKS=(
  "dotfiles/nvim::$HOME/.config/nvim"
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

# scripts executable (recursive)
find "$TOOLBOX_DIR/scripts" -type f -name '*.sh' -exec chmod +x {} +

is_macos() { [ "$(uname -s)" = "Darwin" ]; }

# ---- 2. iTerm globals (so the tmux-keymap preset actually works) ------------
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

# ---- summary ----------------------------------------------------------------

echo
echo "done. next steps:"
echo "  - install deps:  brew install neovim ripgrep fd tmux"
echo "  - launch nvim:   nvim   (vim.pack bootstraps plugins on first run)"
echo "  - test review:   bash $TOOLBOX_DIR/scripts/review-nvim.sh"
echo "  - iTerm keymap:  import $TOOLBOX_DIR/dotfiles/iterm/tmux-keymap.itermkeymap"
echo "                   (Settings → Profiles → Keys → Key Mappings → Presets… → Import)"
echo "  - reload tmux:   tmux source-file ~/.tmux.conf   (or restart server)"
echo "  - dancing-claude: bash $TOOLBOX_DIR/dancing-claude/setup/install.sh   (one-time venv)"
