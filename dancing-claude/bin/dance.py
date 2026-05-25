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
import traceback

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

STATE_DIR = os.path.expanduser("~/.cache/dancing-claude")
FRAME_PATH = os.path.join(STATE_DIR, "frame.ansi")
LOG_PATH = os.path.join(STATE_DIR, "dance.log")
LOG_MAX_BYTES = 256 * 1024  # truncate if larger at startup
AUDIO_CHECK_INTERVAL = 5.0   # seconds between stream health checks
ERROR_BACKOFF = 0.25         # sleep this long after a caught exception
ERROR_LOG_MIN_INTERVAL = 2.0  # rate-limit identical errors to avoid log spam


def _setup_logging() -> None:
    """Redirect stderr to a rotating-ish log file so post-mortem is possible.

    Without this, any exception printed to stderr dies with the pane and we
    have nothing to debug from.
    """
    try:
        os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)
        if os.path.exists(LOG_PATH) and os.path.getsize(LOG_PATH) > LOG_MAX_BYTES:
            # naive truncate — keep the tail
            with open(LOG_PATH, "rb") as f:
                f.seek(-LOG_MAX_BYTES // 2, os.SEEK_END)
                tail = f.read()
            with open(LOG_PATH, "wb") as f:
                f.write(b"--- log truncated ---\n")
                f.write(tail)
        log_fp = open(LOG_PATH, "ab", buffering=0)
        os.dup2(log_fp.fileno(), 2)
        sys.stderr.write(f"\n=== dance.py start pid={os.getpid()} t={time.time():.0f} ===\n")
    except Exception:
        # never let logging break startup
        pass


def _mirror_frame(payload: str) -> None:
    """Write the latest frame to a shared file so viewer panes in other tmux
    windows can render it. Atomic via os.replace — readers either see the
    previous file or the new one, never a torn write.

    Failures are swallowed: a missing or unwritable state dir must never kill
    the render loop.
    """
    try:
        tmp = FRAME_PATH + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            f.write(payload)
        os.replace(tmp, FRAME_PATH)
    except Exception:
        pass


def _log_exc(tag: str, exc: BaseException) -> None:
    try:
        sys.stderr.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {tag}: {exc!r}\n")
        traceback.print_exc(file=sys.stderr)
    except Exception:
        pass


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


def _try_start_audio() -> "AudioSource | None":
    try:
        a = AudioSource()
        a.start()
        sys.stderr.write(f"[dance] audio: {a.device_info()}\n")
        return a
    except Exception as e:  # noqa: BLE001
        _log_exc("audio start failed", e)
        return None


def _audio_alive(audio: "AudioSource | None") -> bool:
    if audio is None or audio._stream is None:
        return False
    try:
        return bool(audio._stream.active)
    except Exception:
        return False


def main() -> int:
    _setup_logging()

    cols, rows = pane_size()
    canvas_w = max(20, cols)
    canvas_h = max(2, rows * 2)
    if canvas_h % 2 != 0:
        canvas_h += 1

    lib = MoveLibrary(os.path.join(ROOT, "moves"))
    canvas = Canvas(canvas_w, canvas_h)
    choreo = Choreographer(lib, canvas_w, canvas_h)

    audio = _try_start_audio()
    detector = BeatDetector()

    enter_alt_screen()

    stopping = {"flag": False}

    def shutdown(*_):
        stopping["flag"] = True

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)
    # Note: SIGHUP intentionally NOT trapped — tmux does not normally send it,
    # but some macOS sleep/wake or terminal hand-offs can. Letting it default
    # to SIG_IGN keeps the pane alive across those events.
    signal.signal(signal.SIGHUP, signal.SIG_IGN)

    last = time.monotonic()
    last_audio_check = 0.0
    last_err_t = 0.0
    last_err_repr = ""
    try:
        while not stopping["flag"]:
            try:
                now = time.monotonic()
                dt = now - last
                last = now

                # periodic audio health check — restart silently if stream died
                if now - last_audio_check > AUDIO_CHECK_INTERVAL:
                    last_audio_check = now
                    if not _audio_alive(audio):
                        if audio is not None:
                            try:
                                audio.stop()
                            except Exception:
                                pass
                        audio = _try_start_audio()

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
                payload = "\x1b[H" + frame
                _mirror_frame(payload)
                try:
                    sys.stdout.write(payload)
                    sys.stdout.flush()
                except (BrokenPipeError, OSError) as e:
                    # tty briefly unavailable (e.g. tmux re-layout) — back off
                    _log_exc("stdout write failed", e)
                    time.sleep(ERROR_BACKOFF)
                    continue

                # frame pacing
                elapsed = time.monotonic() - now
                sleep_for = FRAME_DT - elapsed
                if sleep_for > 0:
                    time.sleep(sleep_for)
            except KeyboardInterrupt:
                stopping["flag"] = True
            except Exception as e:  # noqa: BLE001
                # never let a single bad frame kill the pane
                er = repr(e)
                tnow = time.monotonic()
                if er != last_err_repr or (tnow - last_err_t) > ERROR_LOG_MIN_INTERVAL:
                    _log_exc("loop iteration error", e)
                    last_err_t = tnow
                    last_err_repr = er
                time.sleep(ERROR_BACKOFF)
    finally:
        leave_alt_screen()
        if audio is not None:
            try:
                audio.stop()
            except Exception as e:  # noqa: BLE001
                _log_exc("audio stop failed", e)
        sys.stderr.write(f"=== dance.py exit pid={os.getpid()} t={time.time():.0f} ===\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
