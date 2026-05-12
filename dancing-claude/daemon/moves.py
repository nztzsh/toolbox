"""Move JSON loader. Hot-reloads when files change on disk."""
from __future__ import annotations

import json
import os
import time
from dataclasses import dataclass
from typing import Dict, List, Tuple

Pixel = Tuple[int, int, int, int]


def _hex_to_pixel(h: str) -> Pixel:
    h = h.strip()
    if h.startswith("#"):
        h = h[1:]
    if len(h) == 3:
        r = int(h[0] * 2, 16)
        g = int(h[1] * 2, 16)
        b = int(h[2] * 2, 16)
        return (r, g, b, 255)
    if len(h) == 4:
        r = int(h[0] * 2, 16)
        g = int(h[1] * 2, 16)
        b = int(h[2] * 2, 16)
        a = int(h[3] * 2, 16)
        return (r, g, b, a)
    if len(h) == 6:
        return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)
    if len(h) == 8:
        return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), int(h[6:8], 16))
    raise ValueError(f"bad color: {h}")


@dataclass
class Frame:
    id: str
    pixels: List[List[Pixel]]  # [row][col] — pixel art (legacy)
    ascii_rows: List[str] = None  # ASCII art rows; None if pixel frame
    ascii_color: Tuple[int, int, int] = (255, 255, 255)


@dataclass
class Move:
    name: str
    bpm_range: Tuple[float, float]
    palette: List[Pixel]
    frames: Dict[str, Frame]
    choreo: Dict[str, str]
    width: int
    height: int
    is_ascii: bool = False


def _build_frame(frame_def: dict, palette: List[Pixel], default_color: Tuple[int, int, int]) -> Frame:
    if "ascii" in frame_def:
        rows = frame_def["ascii"]
        color_hex = frame_def.get("color")
        if color_hex:
            px = _hex_to_pixel(color_hex)
            color = (px[0], px[1], px[2])
        else:
            color = default_color
        return Frame(id=frame_def["id"], pixels=[], ascii_rows=list(rows), ascii_color=color)
    rows = frame_def["rows"]
    pixels: List[List[Pixel]] = []
    for row in rows:
        rpx: List[Pixel] = []
        for ch in row:
            if ch in (" ", "."):
                rpx.append((0, 0, 0, 0))
            else:
                idx = int(ch, 16)
                rpx.append(palette[idx])
        pixels.append(rpx)
    return Frame(id=frame_def["id"], pixels=pixels)


def load_move(path: str) -> Move:
    with open(path, "r") as f:
        data = json.load(f)
    palette = [_hex_to_pixel(c) for c in data["palette"]]
    color_hex = data.get("color", "#ffffff")
    cpx = _hex_to_pixel(color_hex)
    default_color = (cpx[0], cpx[1], cpx[2])
    frames = {fd["id"]: _build_frame(fd, palette, default_color) for fd in data["frames"]}
    first = next(iter(frames.values()))
    is_ascii = first.ascii_rows is not None
    if is_ascii:
        h = len(first.ascii_rows)
        w = max((len(r) for r in first.ascii_rows), default=0)
    else:
        h = len(first.pixels)
        w = len(first.pixels[0]) if h > 0 else 0
    return Move(
        name=data["name"],
        bpm_range=tuple(data.get("bpm_range", [0, 999])),  # type: ignore[arg-type]
        palette=palette,
        frames=frames,
        choreo=data.get("choreo", {}),
        width=w,
        height=h,
        is_ascii=is_ascii,
    )


class MoveLibrary:
    def __init__(self, moves_dir: str):
        self.moves_dir = moves_dir
        self._mtimes: Dict[str, float] = {}
        self.moves: Dict[str, Move] = {}
        self.reload()

    def reload(self) -> List[str]:
        changed: List[str] = []
        if not os.path.isdir(self.moves_dir):
            return changed
        seen = set()
        for fname in os.listdir(self.moves_dir):
            if not fname.endswith(".json"):
                continue
            path = os.path.join(self.moves_dir, fname)
            try:
                mt = os.path.getmtime(path)
            except OSError:
                continue
            seen.add(fname)
            if self._mtimes.get(fname) == mt:
                continue
            try:
                move = load_move(path)
                self.moves[move.name] = move
                self._mtimes[fname] = mt
                changed.append(move.name)
            except Exception as e:  # noqa: BLE001
                print(f"[moves] failed to load {fname}: {e}")
        # drop removed
        for fname in list(self._mtimes):
            if fname not in seen:
                self._mtimes.pop(fname, None)
        return changed

    def pick(self, bpm: float) -> Move:
        candidates = [
            m for m in self.moves.values()
            if m.bpm_range[0] <= bpm <= m.bpm_range[1]
        ]
        if candidates:
            return candidates[0]
        if self.moves:
            return next(iter(self.moves.values()))
        raise RuntimeError("no moves loaded")
