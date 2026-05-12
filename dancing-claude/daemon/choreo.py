"""Choreographer: composes the pixel canvas each frame.

Height-aware: works at any even canvas height (set by tmux pane size).

Layers, bottom to top:
  1. Vertical hue-shift gradient
  2. EQ-style column bars driven by tempo + kick energy
  3. Kick flash overlay
  4. Sprite (current pose), drifts with mid energy
  5. Particles from snare hits
"""
from __future__ import annotations

import colorsys
import math
import random
from dataclasses import dataclass, field
from typing import List, Optional

from .moves import Move, MoveLibrary
from .sprite import Canvas
from .state import STATE


@dataclass
class Particle:
    x: float
    y: float
    vx: float
    vy: float
    life: float
    max_life: float
    color: tuple


@dataclass
class Choreographer:
    library: MoveLibrary
    canvas_w: int
    canvas_h: int
    cycle_idx: int = 0
    particles: List[Particle] = field(default_factory=list)
    palette_shift: float = 0.0
    last_kick_seen: float = 0.0
    last_snare_seen: float = 0.0
    last_drop_seen: float = 0.0
    last_reload: float = 0.0

    def __post_init__(self) -> None:
        pass

    def refresh_move(self, bpm: float) -> None:
        # noop — all animals render together regardless of bpm
        pass

    def _frame_cycle_for(self, move: Move) -> List[str]:
        on_kick = move.choreo.get("on_kick", "")
        if on_kick.startswith("cycle:"):
            return [s.strip() for s in on_kick.split(":", 1)[1].split(",")]
        return list(move.frames.keys())

    def maybe_reload_moves(self, now: float) -> None:
        if now - self.last_reload > 1.0:
            self.last_reload = now
            self.library.reload()

    def handle_beats(self) -> None:
        with STATE.lock:
            kick = STATE.last_kick_t
            snare = STATE.last_snare_t
            drop = STATE.last_drop_t
        if kick > self.last_kick_seen:
            self.last_kick_seen = kick
            self.cycle_idx += 1
        if snare > self.last_snare_seen:
            self.last_snare_seen = snare
            self._spawn_particles(10)
        if drop > self.last_drop_seen:
            self.last_drop_seen = drop
            self.palette_shift = (self.palette_shift + 180.0) % 360.0

    def _spawn_particles(self, n: int) -> None:
        cx = self.canvas_w / 2
        cy = self.canvas_h / 2
        for _ in range(n):
            angle = random.uniform(0, 2 * math.pi)
            speed = random.uniform(20.0, 60.0)
            life = random.uniform(0.3, 0.65)
            hue = random.random()
            r, g, b = colorsys.hsv_to_rgb(hue, 0.95, 1.0)
            self.particles.append(
                Particle(
                    x=cx,
                    y=cy,
                    vx=math.cos(angle) * speed,
                    vy=math.sin(angle) * speed * 0.6,
                    life=life,
                    max_life=life,
                    color=(int(r * 255), int(g * 255), int(b * 255)),
                )
            )

    def step_particles(self, dt: float) -> None:
        alive: List[Particle] = []
        for p in self.particles:
            p.x += p.vx * dt
            p.y += p.vy * dt
            p.life -= dt
            if p.life > 0 and -2 <= p.x < self.canvas_w + 2 and -2 <= p.y < self.canvas_h + 2:
                alive.append(p)
        self.particles = alive

    def render(self, canvas: Canvas, bpm: float, rms: float, now: float) -> None:
        H = canvas.height
        W = canvas.width
        canvas.clear()

        base_hue = (now * 22 + self.palette_shift) % 360 / 360.0

        # 1. vertical gradient bg
        c1 = self._hsv(base_hue, 0.7, 0.10 + min(0.25, rms * 5))
        c2 = self._hsv((base_hue + 0.5) % 1.0, 0.8, 0.03 + min(0.10, rms * 2))
        canvas.fill_bg_gradient(c1 + (255,), c2 + (255,))

        # 2. EQ column bars
        since_kick = now - self.last_kick_seen
        kick_pulse = max(0.0, 1.0 - since_kick / 0.4)
        bar_step = 3  # bar width 2 + 1 gap
        bar_count = W // bar_step
        rate = 2.0 + (bpm if bpm else 90) / 60.0
        for i in range(bar_count):
            phase = (now * rate + i * 0.38) % (2 * math.pi)
            wave = (math.sin(phase) + 1) * 0.5
            height = wave * H * (0.35 + min(1.4, rms * 10)) + H * 0.25 * kick_pulse
            bar_h = max(0, min(H, int(height)))
            hue = (base_hue + i / max(1, bar_count) * 0.55) % 1.0
            color = self._hsv(hue, 0.9, 0.55 + 0.45 * wave) + (215,)
            x0 = i * bar_step
            for bx in range(2):
                canvas.column_bar(x0 + bx, bar_h, color)

        # 3. kick flash overlay
        if since_kick < 0.13:
            t = 1 - since_kick / 0.13
            a = int(140 * t)
            flash = self._hsv((base_hue + 0.12) % 1.0, 0.35, 1.0) + (a,)
            canvas.fill_rect(0, 0, W, H, flash)

        # 4. animals — render every loaded move side by side
        moves = list(self.library.moves.values())
        if moves:
            char_rows = H // 2
            gap = 2
            total_w = sum(m.width for m in moves) + gap * (len(moves) - 1)
            start_x = max(0, (W - total_w) // 2)
            cur_x = start_x
            for i, m in enumerate(moves):
                cycle = self._frame_cycle_for(m)
                if not cycle:
                    cur_x += m.width + gap
                    continue
                # phase-shift cycle index per animal so they don't all hit same pose
                idx = (self.cycle_idx + i) % len(cycle)
                frame = m.frames.get(cycle[idx])
                if frame is None:
                    cur_x += m.width + gap
                    continue
                drift_x = int(math.sin(now * 2.6 + i * 1.1) * 2)
                drift_y = int(math.sin(now * 5.0 + i * 0.7) * 1) - int(kick_pulse * 1.5)
                if m.is_ascii:
                    sx = cur_x + drift_x
                    sy_char = max(0, (char_rows - m.height) // 2 + (drift_y // 2))
                    color = self._shift_color(frame.ascii_color, self.palette_shift / 360.0)
                    for ry, row in enumerate(frame.ascii_rows):
                        for cx, ch in enumerate(row):
                            if ch == " " or ch == ".":
                                continue
                            canvas.put_text(sx + cx, sy_char + ry, ch, color)
                else:
                    sx = cur_x + drift_x
                    sy = max(0, (H - m.height) // 2 + drift_y)
                    shifted = self._shift_palette(frame.pixels, self.palette_shift / 360.0)
                    canvas.blit_sprite(sx, sy, shifted)
                cur_x += m.width + gap

        # 5. particles
        for p in self.particles:
            f = max(0.0, p.life / p.max_life)
            alpha = int(255 * f)
            px = (p.color[0], p.color[1], p.color[2], alpha)
            canvas.put(int(p.x), int(p.y), px)
            # 2-pixel-wide trail for visibility
            canvas.put(int(p.x) + 1, int(p.y), px)

    @staticmethod
    def _hsv(h: float, s: float, v: float) -> tuple:
        r, g, b = colorsys.hsv_to_rgb(h % 1.0, max(0.0, min(1.0, s)), max(0.0, min(1.0, v)))
        return (int(r * 255), int(g * 255), int(b * 255))

    @staticmethod
    def _shift_color(rgb, shift: float):
        if shift == 0:
            return rgb
        r, g, b = rgb
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        h = (h + shift) % 1.0
        rr, gg, bb = colorsys.hsv_to_rgb(h, s, v)
        return (int(rr * 255), int(gg * 255), int(bb * 255))

    @staticmethod
    def _shift_palette(pixels, shift: float):
        if shift == 0:
            return pixels
        out = []
        for row in pixels:
            nr = []
            for r, g, b, a in row:
                if a == 0:
                    nr.append((r, g, b, a))
                    continue
                h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
                h = (h + shift) % 1.0
                rr, gg, bb = colorsys.hsv_to_rgb(h, s, v)
                nr.append((int(rr * 255), int(gg * 255), int(bb * 255), a))
            out.append(nr)
        return out
