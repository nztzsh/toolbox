# toolbox

Personal dev toolbox. Dotfiles + scripts + Claude Code commands, all symlinked into expected locations.

## Layout

```
toolbox/
├── dotfiles/            source-of-truth configs (symlinked out by install.sh)
│   └── nvim/            → ~/.config/nvim
├── scripts/
│   ├── install.sh       symlink dotfiles + claude commands into place
│   ├── review-nvim.sh   open nvim diff-review in new terminal window
│   └── lib/
│       └── terminal.sh  pluggable terminal launcher (iterm only for now)
└── claude/
    └── commands/        → ~/.claude/commands (slash commands)
```

## Setup

```bash
# 1. install nvim + deps
brew install neovim ripgrep fd git

# 2. symlink everything
bash scripts/install.sh

# 3. first nvim launch — lazy.nvim bootstraps plugins
nvim
# inside: :Lazy sync   (auto-runs on first launch)

# 4. test review flow from any git repo
bash scripts/review-nvim.sh
# or in claude code:
/review-nvim
```

## Adding a new dotfile

1. Drop config under `dotfiles/<name>/`.
2. Add mapping line in `scripts/install.sh` `DOTFILES` array.
3. Re-run `bash scripts/install.sh`.

## Adding a new terminal backend

Edit `scripts/lib/terminal.sh`. Implement `open_terminal_<name>` and add case in `open_terminal_window` dispatch.
