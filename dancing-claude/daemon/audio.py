"""Audio capture from BlackHole (or any input device).

Provides a non-blocking stream of mono float32 frames via a ring buffer.
"""
from __future__ import annotations

import threading
from collections import deque
from typing import Deque, Optional

import numpy as np
import sounddevice as sd


def find_blackhole_device() -> Optional[int]:
    """Return index of first BlackHole input device, else None."""
    for idx, dev in enumerate(sd.query_devices()):
        name = dev["name"].lower()
        if "blackhole" in name and dev["max_input_channels"] > 0:
            return idx
    return None


class AudioSource:
    """Pulls audio from the chosen input device into a thread-safe ring buffer."""

    def __init__(self, device: Optional[int] = None, samplerate: int = 44100, blocksize: int = 1024):
        self.samplerate = samplerate
        self.blocksize = blocksize
        self.device = device if device is not None else find_blackhole_device()
        if self.device is None:
            # fall back to default input — at least dev won't crash
            self.device = sd.default.device[0] if sd.default.device else None
        self._frames: Deque[np.ndarray] = deque(maxlen=64)
        self._lock = threading.Lock()
        self._stream: Optional[sd.InputStream] = None

    def _callback(self, indata: np.ndarray, frames: int, time_info, status) -> None:
        if status:
            # buffer overruns happen — keep going
            pass
        # mono mix
        mono = indata.mean(axis=1) if indata.ndim == 2 else indata
        with self._lock:
            self._frames.append(mono.copy())

    def start(self) -> None:
        self._stream = sd.InputStream(
            device=self.device,
            channels=2 if self._device_has_stereo() else 1,
            samplerate=self.samplerate,
            blocksize=self.blocksize,
            dtype="float32",
            callback=self._callback,
        )
        self._stream.start()

    def _device_has_stereo(self) -> bool:
        if self.device is None:
            return False
        info = sd.query_devices(self.device)
        return info["max_input_channels"] >= 2

    def stop(self) -> None:
        if self._stream is not None:
            self._stream.stop()
            self._stream.close()
            self._stream = None

    def pop_block(self) -> Optional[np.ndarray]:
        with self._lock:
            if not self._frames:
                return None
            return self._frames.popleft()

    def device_info(self) -> str:
        if self.device is None:
            return "no audio device"
        info = sd.query_devices(self.device)
        return f"{info['name']} @ {self.samplerate}Hz"
