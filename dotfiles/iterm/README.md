# iTerm2 key map preset

`tmux-keymap.itermkeymap` — Cmd-prefixed shortcuts that send escape
sequences consumed by `dotfiles/tmux/tmux.conf` as `user-keys`.

Format: JSON interchange format used by iTerm2 3.4+ (top-level keys
`Key Mappings` and `Touch Bar Items`). Not the old XML plist preset format.

## Import

1. iTerm2 → Settings (`⌘,`) → Profiles → pick profile → **Keys** tab → **Key
   Mappings** sub-tab.
2. Click **Presets…** dropdown (bottom-right) → **Import…**.
3. Pick `dotfiles/iterm/tmux-keymap.itermkeymap`.
4. iTerm merges the bindings directly into the current profile's Key Mappings
   (no preset is created — bindings appear in the table immediately).
5. iTerm will warn about overriding existing mappings (Cmd-T, Cmd-W, etc.) —
   confirm. Those iTerm actions are intentionally replaced.

## Shortcut → action map

| Combo | Action |
|---|---|
| `⌘T` | new tmux window |
| `⌘W` | kill window (confirm) |
| `⌘N` | new tmux session |
| `⌘1`..`⌘9` | select window 1..9 |
| `⌘⇧]` / `⌘⇧[` | next / prev window |
| `⌘D` / `⌘⇧D` | split right / down |
| `⌘⌥←/→/↑/↓` | switch pane |
| `⌘↩` | zoom pane toggle |
| `⌘,` | rename window |
| `⌘K` | clear pane + history |

## Caveats

- iTerm's global "⌘+Number switches tabs" and "⌘+Number+Option switches
  windows" prefs intercept Cmd-1..9 and Cmd-Opt-arrows **before** the profile
  key map fires. Disable both:

  ```bash
  defaults write com.googlecode.iterm2 SwitchTabModifier -int 9
  defaults write com.googlecode.iterm2 SwitchWindowModifier -int 9
  ```

  Or in GUI: Settings → Keys → General → set both "⌘+Number" and
  "⌘+Number+Option" popups to **No Modifier**. Restart iTerm.

- Outside tmux these shortcuts print escape sequences (e.g. `[5001~`) into
  the shell. Acceptable tradeoff for native-feel inside tmux.
- `⌘,` is also macOS Settings. Import at *Profile* level (not Global
  Shortcuts) so it only fires inside iTerm.
- Arrow-key modifier masks vary across macOS versions. If `⌘⌥←` etc. don't
  fire after import, re-add manually via the GUI — iTerm will record the
  correct mask.
- Preset is per-profile. If you use multiple profiles, import into each.
