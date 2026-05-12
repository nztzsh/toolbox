"""Pixel canvas + HTML half-block renderer for iTerm2 status bar.

iTerm2 status bar is one text row tall. Half-block `▀` gives us 2 pixel rows
per char row, so canvas height is always 2. Each cell becomes a `<span>` with
fg (top pixel) and bg (bottom pixel) colors.
"""
from __future__ import annotations

from typing import List, Tuple

import numpy as np

Pixel = Tuple[int, int, int, int]
TRANSPARENT: Pixel = (0, 0, 0, 0)


def _esc(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


class Canvas:
    """A 2D pixel buffer. Height must be even (we pack 2 rows per char)."""

    def __init__(self, width: int, height: int = 2, bg: Pixel = (0, 0, 0, 255)):
        if height % 2 != 0:
            height += 1
        self.width = width
        self.height = height
        self.bg = bg
        self.buf = np.zeros((height, width, 4), dtype=np.uint8)
        # ASCII overlay grid: one entry per character cell (height/2 rows × width cols)
        # Each cell None or (char, fg_rgb_tuple)
        self.text: List[List] = [[None] * width for _ in range(height // 2)]
        self.clear()

    def clear(self) -> None:
        self.buf[:, :, 0] = self.bg[0]
        self.buf[:, :, 1] = self.bg[1]
        self.buf[:, :, 2] = self.bg[2]
        self.buf[:, :, 3] = 255
        for r in self.text:
            for i in range(len(r)):
                r[i] = None

    def put_text(self, x: int, y_char: int, ch: str, fg: Tuple[int, int, int]) -> None:
        if 0 <= x < self.width and 0 <= y_char < len(self.text):
            self.text[y_char][x] = (ch, fg)

    def fill_bg_gradient(self, c1: Pixel, c2: Pixel) -> None:
        for y in range(self.height):
            f = y / max(1, self.height - 1)
            self.buf[y, :, 0] = int(c1[0] * (1 - f) + c2[0] * f)
            self.buf[y, :, 1] = int(c1[1] * (1 - f) + c2[1] * f)
            self.buf[y, :, 2] = int(c1[2] * (1 - f) + c2[2] * f)
            self.buf[y, :, 3] = 255

    def fill_x_gradient(self, c1: Pixel, c2: Pixel) -> None:
        for x in range(self.width):
            f = x / max(1, self.width - 1)
            self.buf[:, x, 0] = int(c1[0] * (1 - f) + c2[0] * f)
            self.buf[:, x, 1] = int(c1[1] * (1 - f) + c2[1] * f)
            self.buf[:, x, 2] = int(c1[2] * (1 - f) + c2[2] * f)
            self.buf[:, x, 3] = 255

    def put(self, x: int, y: int, px: Pixel) -> None:
        if 0 <= x < self.width and 0 <= y < self.height and px[3] > 0:
            if px[3] == 255:
                self.buf[y, x, 0] = px[0]
                self.buf[y, x, 1] = px[1]
                self.buf[y, x, 2] = px[2]
                self.buf[y, x, 3] = 255
            else:
                a = px[3] / 255.0
                cur = self.buf[y, x]
                self.buf[y, x, 0] = int(px[0] * a + cur[0] * (1 - a))
                self.buf[y, x, 1] = int(px[1] * a + cur[1] * (1 - a))
                self.buf[y, x, 2] = int(px[2] * a + cur[2] * (1 - a))
                self.buf[y, x, 3] = 255

    def blit_sprite(self, x0: int, y0: int, sprite: List[List[Pixel]]) -> None:
        for sy, row in enumerate(sprite):
            for sx, px in enumerate(row):
                self.put(x0 + sx, y0 + sy, px)

    def fill_rect(self, x0: int, y0: int, w: int, h: int, px: Pixel) -> None:
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                self.put(x, y, px)

    def column_bar(self, x: int, height: int, color: Pixel) -> None:
        """Draw a vertical bar in column x, growing upward from bottom."""
        h = max(0, min(self.height, height))
        for y in range(self.height - h, self.height):
            self.put(x, y, color)

    def render_html(self) -> str:
        """One row of `▀` spans. fg = top pixel, bg = bottom pixel."""
        parts: List[str] = []
        last_fg: Tuple[int, int, int] = (-1, -1, -1)
        last_bg: Tuple[int, int, int] = (-1, -1, -1)
        open_span = False
        run = ""

        def flush(buf_run: str, fg, bg):
            if not buf_run:
                return ""
            return (
                f'<span style="color:#{fg[0]:02x}{fg[1]:02x}{fg[2]:02x};'
                f'background-color:#{bg[0]:02x}{bg[1]:02x}{bg[2]:02x}">{_esc(buf_run)}</span>'
            )

        # We only use rows 0 and 1 (first half-block pair). If canvas taller,
        # we average down to those two effective rows.
        top_row = self.buf[0]
        bot_row = self.buf[1]
        if self.height > 2:
            half = self.height // 2
            top_row = self.buf[:half].mean(axis=0).astype(np.uint8)
            bot_row = self.buf[half:].mean(axis=0).astype(np.uint8)

        for x in range(self.width):
            fg = (int(top_row[x, 0]), int(top_row[x, 1]), int(top_row[x, 2]))
            bg = (int(bot_row[x, 0]), int(bot_row[x, 1]), int(bot_row[x, 2]))
            if fg == last_fg and bg == last_bg:
                run += "▀"
            else:
                parts.append(flush(run, last_fg, last_bg))
                run = "▀"
                last_fg = fg
                last_bg = bg
        parts.append(flush(run, last_fg, last_bg))
        return "".join(parts)

    def render_ansi(self) -> str:
        """Multi-row ANSI half-block render with bold ASCII text overlay."""
        out: List[str] = []
        for y in range(0, self.height, 2):
            char_row = y // 2
            row_text = self.text[char_row] if char_row < len(self.text) else None
            last_fg = (-1, -1, -1)
            last_bg = (-1, -1, -1)
            bold = False
            top_row = self.buf[y]
            bot_row = self.buf[y + 1] if (y + 1) < self.height else self.buf[y]
            for x in range(self.width):
                tcell = row_text[x] if row_text is not None else None
                if tcell is not None:
                    ch, fg = tcell
                    # darken bg so bright bold fg pops harder
                    bg = (
                        int(((int(top_row[x, 0]) + int(bot_row[x, 0])) // 2) * 0.35),
                        int(((int(top_row[x, 1]) + int(bot_row[x, 1])) // 2) * 0.35),
                        int(((int(top_row[x, 2]) + int(bot_row[x, 2])) // 2) * 0.35),
                    )
                    want_bold = True
                else:
                    fg = (int(top_row[x, 0]), int(top_row[x, 1]), int(top_row[x, 2]))
                    bg = (int(bot_row[x, 0]), int(bot_row[x, 1]), int(bot_row[x, 2]))
                    ch = "▀"
                    want_bold = False
                if want_bold != bold:
                    out.append("\x1b[1m" if want_bold else "\x1b[22m")
                    bold = want_bold
                if fg != last_fg:
                    out.append(f"\x1b[38;2;{fg[0]};{fg[1]};{fg[2]}m")
                    last_fg = fg
                if bg != last_bg:
                    out.append(f"\x1b[48;2;{bg[0]};{bg[1]};{bg[2]}m")
                    last_bg = bg
                out.append(ch)
            out.append("\x1b[0m")
            if y + 2 < self.height:
                out.append("\n")
        return "".join(out)
