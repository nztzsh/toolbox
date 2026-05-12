"""Tmux pane entry point for Dancing Claude.

Runs inside a small tmux pane (split above your shell). Renders a multi-row
ANSI half-block canvas sized to the pane. Audio comes from BlackHole.

The pane is styled by start.sh so its border blends with the surrounding
session.
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

FPS = 25
FRAME_DT = 1.0 / FPS


def pane_size() -> tuple[int, int]:
    size = shutil.get_terminal_size((100, 5))
    return size.columns, size.lines


def enter_alt_screen() -> None:
    # alt screen + hide cursor + clear
    sys.stdout.write("\x1b[?1049h\x1b[?25l\x1b[H\x1b[2J")
    sys.stdout.flush()


def leave_alt_screen() -> None:
    sys.stdout.write("\x1b[0m\x1b[?25h\x1b[?1049l")
    sys.stdout.flush()


def main() -> int:
    cols, rows = pane_size()
    canvas_w = max(20, cols)
    canvas_h = max(2, rows * 2)
    if canvas_h % 2 != 0:
        canvas_h += 1

    lib = MoveLibrary(os.path.join(ROOT, "moves"))
    canvas = Canvas(canvas_w, canvas_h)
    choreo = Choreographer(lib, canvas_w, canvas_h)

    audio = None
    try:
        audio = AudioSource()
        audio.start()
        sys.stderr.write(f"[dance] audio: {audio.device_info()}\n")
    except Exception as e:  # noqa: BLE001
        sys.stderr.write(f"[dance] no audio: {e}\n")

    detector = BeatDetector()

    enter_alt_screen()

    stopping = {"flag": False}

    def shutdown(*_):
        stopping["flag"] = True

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGHUP, shutdown)

    last = time.monotonic()
    try:
        while not stopping["flag"]:
            now = time.monotonic()
            dt = now - last
            last = now

            # resize check — recreate canvas if pane changed
            cur_cols, cur_rows = pane_size()
            new_w = max(20, cur_cols)
            new_h = max(2, cur_rows * 2)
            if new_h % 2 != 0:
                new_h += 1
            if new_w != canvas.width or new_h != canvas.height:
                canvas = Canvas(new_w, new_h)
                choreo.canvas_w = new_w
                choreo.canvas_h = new_h
                sys.stdout.write("\x1b[2J")

            if audio is not None:
                for _ in range(12):
                    block = audio.pop_block()
                    if block is None:
                        break
                    detector.process(block, STATE.record_beat)

            bpm = detector.estimate_bpm()
            choreo.maybe_reload_moves(now)
            choreo.refresh_move(bpm)
            choreo.handle_beats()
            choreo.step_particles(dt)
            choreo.render(canvas, bpm, detector.last_rms, now)

            frame = canvas.render_ansi()
            sys.stdout.write("\x1b[H" + frame)
            sys.stdout.flush()

            # frame pacing
            elapsed = time.monotonic() - now
            sleep_for = FRAME_DT - elapsed
            if sleep_for > 0:
                time.sleep(sleep_for)
    finally:
        leave_alt_screen()
        if audio is not None:
            audio.stop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
