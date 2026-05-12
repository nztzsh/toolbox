# Dancing Claude

Beat-synced color pixel art that lives in a small **tmux pane** above your
Claude Code session. The pane border is styled to blend with the surrounding
window so it reads as part of the same view. Audio comes from BlackHole.

## Requirements

- macOS, tmux 3.2+ (3.5a tested).
- [BlackHole 2ch](https://existential.audio/blackhole/).
- Python 3.10+.

## Install

```bash
./setup/install.sh
```

Sets up `.venv` in the repo with `sounddevice`, `numpy`. No system-wide
install.

## Use

You must already be inside a tmux session.

### From Claude Code (slash commands)

When Claude Code is running in `/Users/nitesh/projects/toolbox`:

| Command                  | Effect                                       |
|--------------------------|----------------------------------------------|
| `/dance:start [rows]`    | Split a `[rows]`-tall dancer pane above; default 6. |
| `/dance:stop`            | Kill the dancer pane.                        |
| `/dance:restart [rows]`  | Stop + start.                                |
| `/dance:status`          | Print running state and pane size.           |
| `/dance:add-move <name>` | Scaffold a new move JSON; hot-reloaded.      |

Each shells out to the matching `bin/` script. Errors surface verbatim with
the script's own actionable suggestion (start tmux, run setup, etc.).

### Directly from the shell

```bash
tmux new -s claude            # if you aren't already in tmux
claude                        # start Claude Code in this pane
# in another pane of the same session:
./bin/start.sh                # 6-row dancer pane above current pane
./bin/start.sh 4              # smaller
./bin/stop.sh                 # remove
./bin/status.sh               # check if running
./bin/add_move.sh windmill    # scaffold moves/windmill.json
```

Focus stays on your Claude Code pane. The dancer pane is created with
`tmux split-window -d -b -l <rows>` and styled so the separator is the
darkest color the theme offers. On a dark theme it's barely visible; on a
light theme set:

```bash
DANCING_CLAUDE_BORDER_FG=colour255 ./bin/start.sh
```

### Route system audio to BlackHole

Open **Audio MIDI Setup** (`/Applications/Utilities`), create a *Multi-Output
Device* combining `BlackHole 2ch` + your speakers/headphones. Set that
Multi-Output Device as the macOS system output. Music still plays through
your speakers; BlackHole gets a parallel copy that the dancer reads.

## Try without tmux

Live preview in any 24-bit terminal:

```bash
./.venv/bin/python bin/preview.py
```

Static 4-frame snapshot (no audio):

```bash
./.venv/bin/python bin/smoke_test.py
```

## Adding moves

Each move is a JSON file in `moves/`. Rows are strings of palette indices
(`0`=transparent, `1`-`f` = palette colors). Drop the file into `moves/`;
the running daemon reloads within ~1s — no restart.

```json
{
  "name": "windmill",
  "bpm_range": [110, 180],
  "palette": ["#0000", "#1d1d1f", "#f5cba0", "#ff7a3c"],
  "frames": [
    { "id": "A", "rows": [
      "....1111....",
      "...111111...",
      "3..122221..3",
      "33.121121.33",
      "....4444....",
      "....4444...."
    ] },
    { "id": "B", "rows": [
      "....1111....",
      "...111111...",
      "...122221.33",
      "...121121.3.",
      "33..4444....",
      "3...4444...."
    ] }
  ],
  "choreo": {
    "on_kick": "cycle:A,B",
    "on_snare": "particle:burst",
    "on_drop": "palette_swap"
  }
}
```

`bpm_range` decides which move is active for the detected tempo. First match
wins; fallback is the first move loaded.

## Layout

```
dancing-claude/
├── bin/
│   ├── dance.py             # tmux pane entry — the render loop
│   ├── preview.py           # full-terminal standalone preview
│   ├── smoke_test.py        # no-audio 4-frame check
│   ├── start.sh             # split current tmux pane, run dance.py
│   └── stop.sh              # kill the dancer pane
├── daemon/
│   ├── audio.py             # BlackHole capture (sounddevice)
│   ├── beat.py              # energy onset + BPM estimation
│   ├── sprite.py            # pixel canvas + multi-row half-block render
│   ├── moves.py             # JSON loader + hot reload
│   ├── choreo.py            # gradient + EQ bars + sprite + particles
│   └── state.py             # shared state between worker + main
├── moves/                   # drop new moves here
└── setup/install.sh
```

## Distribute as a Claude Code plugin

Not packaged yet. Once visuals feel right, the plan is a Claude Code plugin
exposing `/dance:start [rows]` and `/dance:stop` slash commands that shell
out to `bin/start.sh` / `bin/stop.sh`. The plugin would also offer
`/dance:add-move <name>` to scaffold a new move JSON.

## Caveats

- Single dancer pane per tmux session (pidfile lives at
  `~/.cache/dancing-claude/pane.id`).
- tmux always draws a 1-char separator between panes. We color it to vanish
  on dark themes; light themes need `DANCING_CLAUDE_BORDER_FG` set.
- Beat detection is energy-based — works well on EDM / hip-hop / pop;
  choppier on jazz, classical, ambient.
