"""Onset, tempo, and drop detection.

Energy-based onset on three frequency bands (kick / snare / hat). Tempo
estimated by autocorrelation of the low-band onset envelope.
"""
from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Callable, List, Optional

import numpy as np

from .state import BeatEvent


BANDS = {
    "low": (20, 200),
    "mid": (200, 2000),
    "high": (2000, 8000),
}


@dataclass
class BandTracker:
    name: str
    history: List[float]
    last_emit: float
    min_interval: float
    sensitivity: float  # multiplier over moving avg

    def update(self, energy: float, t: float) -> Optional[float]:
        self.history.append(energy)
        if len(self.history) > 43:  # ~1s @ 1024 samples / 44.1k
            self.history.pop(0)
        if len(self.history) < 10:
            return None
        avg = sum(self.history[:-1]) / (len(self.history) - 1)
        if avg <= 1e-9:
            return None
        ratio = energy / avg
        if ratio > self.sensitivity and (t - self.last_emit) > self.min_interval:
            self.last_emit = t
            return min(1.0, (ratio - self.sensitivity) / self.sensitivity)
        return None


class BeatDetector:
    def __init__(self, samplerate: int = 44100):
        self.samplerate = samplerate
        self.bands = {
            "low": BandTracker("low", [], 0.0, min_interval=0.12, sensitivity=1.6),
            "mid": BandTracker("mid", [], 0.0, min_interval=0.08, sensitivity=1.5),
            "high": BandTracker("high", [], 0.0, min_interval=0.05, sensitivity=1.4),
        }
        self.onset_times: List[float] = []  # for tempo estimation
        self.last_rms: float = 0.0
        self.last_centroid: float = 0.0

    def process(self, block: np.ndarray, on_event: Callable[[BeatEvent], None]) -> None:
        if block.size == 0:
            return
        t = time.monotonic()

        # Hann window
        win = np.hanning(len(block))
        spec = np.abs(np.fft.rfft(block * win))
        freqs = np.fft.rfftfreq(len(block), 1 / self.samplerate)

        # RMS + spectral centroid
        rms = float(np.sqrt(np.mean(block * block) + 1e-12))
        total = float(spec.sum() + 1e-9)
        centroid = float((freqs * spec).sum() / total)
        self.last_rms = rms
        self.last_centroid = centroid

        for name, (lo, hi) in BANDS.items():
            mask = (freqs >= lo) & (freqs < hi)
            band_energy = float(spec[mask].sum())
            strength = self.bands[name].update(band_energy, t)
            if strength is not None:
                on_event(BeatEvent(t=t, band=name, strength=strength))
                if name == "low":
                    self.onset_times.append(t)
                    cutoff = t - 6.0
                    while self.onset_times and self.onset_times[0] < cutoff:
                        self.onset_times.pop(0)

    def estimate_bpm(self) -> float:
        """Median inter-onset-interval → BPM. Cheap, OK for steady beats."""
        if len(self.onset_times) < 4:
            return 0.0
        deltas = np.diff(self.onset_times)
        deltas = deltas[(deltas > 0.25) & (deltas < 1.2)]  # 50–240 bpm
        if len(deltas) < 3:
            return 0.0
        med = float(np.median(deltas))
        if med <= 0:
            return 0.0
        return 60.0 / med
