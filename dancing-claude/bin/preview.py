"""Standalone terminal preview — no tmux, no iTerm API.

Renders into the current terminal at full size. Useful for tweaking moves
and choreo before installing into a tmux pane.
"""
from __future__ import annotations

import os
import shutil
import signal
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, ROOT)

from daemon.audio import AudioSource  # noqa: E402
from daemon.beat import BeatDetector  # noqa: E402
from daemon.choreo import Choreographer  # noqa: E402
from daemon.moves import MoveLibrary  # noqa: E402
from daemon.sprite import Canvas  # noqa: E402
from daemon.state import STATE  # noqa: E402


def main() -> int:
    rows_arg = int(os.environ.get("DANCING_CLAUDE_ROWS", "6"))
    size = shutil.get_terminal_size((100, max(rows_arg, 6)))
    cols = max(40, size.columns)
    rows = max(2, min(rows_arg, size.lines - 2))
    canvas_h = rows * 2
    if canvas_h % 2 != 0:
        canvas_h += 1

    canvas = Canvas(cols, canvas_h)
    lib = MoveLibrary(os.path.join(ROOT, "moves"))
    ch = Choreographer(lib, cols, canvas_h)

    audio = None
    try:
        audio = AudioSource()
        audio.start()
        sys.stderr.write(f"[preview] audio: {audio.device_info()}\n")
    except Exception as e:  # noqa: BLE001
        sys.stderr.write(f"[preview] no audio: {e}\n")

    detector = BeatDetector()

    sys.stdout.write("\x1b[?1049h\x1b[?25l\x1b[2J\x1b[H")
    sys.stdout.flush()

    stopping = {"flag": False}

    def shutdown(*_):
        stopping["flag"] = True

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    last = time.monotonic()
    try:
        while not stopping["flag"]:
            now = time.monotonic()
            dt = now - last
            last = now

            if audio is not None:
                for _ in range(8):
                    block = audio.pop_block()
                    if block is None:
                        break
                    detector.process(block, STATE.record_beat)

            bpm = detector.estimate_bpm()
            ch.maybe_reload_moves(now)
            ch.refresh_move(bpm)
            ch.handle_beats()
            ch.step_particles(dt)
            ch.render(canvas, bpm, detector.last_rms, now)

            sys.stdout.write("\x1b[H" + canvas.render_ansi())
            sys.stdout.flush()
            time.sleep(0.04)
    finally:
        sys.stdout.write("\x1b[0m\x1b[?25h\x1b[?1049l")
        sys.stdout.flush()
        if audio is not None:
            audio.stop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
