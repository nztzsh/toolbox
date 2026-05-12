"""Render synthetic frames at typical tmux pane size. No audio.

Useful for inspecting sprite + bg composition without music.
"""
from __future__ import annotations

import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, ROOT)

from daemon.choreo import Choreographer  # noqa: E402
from daemon.moves import MoveLibrary  # noqa: E402
from daemon.sprite import Canvas  # noqa: E402
from daemon.state import STATE, BeatEvent  # noqa: E402


def main() -> int:
    lib = MoveLibrary(os.path.join(ROOT, "moves"))
    print(f"loaded moves: {list(lib.moves.keys())}")
    if not lib.moves:
        return 1

    width = 100
    height = 12  # 6 text rows × 2
    canvas = Canvas(width, height)
    ch = Choreographer(lib, width, height)

    now = time.monotonic()
    for i in range(4):
        STATE.record_beat(BeatEvent(t=now + i * 0.4, band="low", strength=0.9))
        if i % 2 == 0:
            STATE.record_beat(BeatEvent(t=now + i * 0.4, band="mid", strength=0.8))
        ch.handle_beats()
        ch.step_particles(0.4)
        ch.render(canvas, bpm=120.0, rms=0.05, now=now + i * 0.4)
        print(f"\n--- frame {i} ---")
        print(canvas.render_ansi())
    return 0


if __name__ == "__main__":
    sys.exit(main())
