"""Thread-shared state between audio worker and iTerm2 status bar component."""
from __future__ import annotations

import threading
import time
from dataclasses import dataclass, field


@dataclass
class BeatEvent:
    t: float
    band: str  # "low" | "mid" | "high"
    strength: float  # 0..1


@dataclass
class SharedState:
    frame_str: str = ""
    bpm: float = 0.0
    last_kick_t: float = 0.0
    last_snare_t: float = 0.0
    last_hat_t: float = 0.0
    last_drop_t: float = 0.0
    rms: float = 0.0
    centroid: float = 0.0
    palette_phase: float = 0.0  # 0..1, hue offset
    lock: threading.Lock = field(default_factory=threading.Lock)

    def record_beat(self, ev: BeatEvent) -> None:
        with self.lock:
            if ev.band == "low":
                self.last_kick_t = ev.t
            elif ev.band == "mid":
                self.last_snare_t = ev.t
            elif ev.band == "high":
                self.last_hat_t = ev.t

    def record_drop(self) -> None:
        with self.lock:
            self.last_drop_t = time.monotonic()


STATE = SharedState()
