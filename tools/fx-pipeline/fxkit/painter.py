"""Layers and the square-only painter.

PixelFX's painter (src/core/painter.js) draws in local coordinates around an origin and places, mirrors and
rounds to whole pixel cells, so a flipped effect still lands on whole pixels. This one keeps that and drops
everything Tessera forbids: no circles, arcs, glow/light buffer, translucent blending or dither (art bible P1,
§6.2, §8.10). Colour 0 means "draw nothing": a shape never erases what is under it.

Local space: (0, 0) is the effect's anchor, x right, y down, 1 unit = 1 art px. Directional effects face right;
`flip` mirrors them. Two layers per frame: "behind" (the floor layer, under units) and "front" (over units).
"""
from __future__ import annotations

import math

LAYERS = ("behind", "front")


class Layer:
    """w x h colour ints (0 = transparent)."""

    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.px = [0] * (w * h)

    def get(self, x: int, y: int) -> int:
        return self.px[y * self.w + x] if 0 <= x < self.w and 0 <= y < self.h else 0

    def is_empty(self) -> bool:
        return not any(self.px)

    def count(self) -> int:
        return sum(1 for c in self.px if c)


def over(base: list[int], top: list[int]) -> list[int]:
    """`top` drawn over `base` (same size): opaque pixels win."""
    return [t if t else b for b, t in zip(base, top)]


class Painter:
    """Draws into one Layer with the effect's origin at (tx, ty) of that layer."""

    def __init__(self, layer: Layer, tx: int, ty: int, flip: bool = False):
        self.layer, self.tx, self.ty, self.flip = layer, tx, ty, flip
        self.spilled = 0

    # ---- raw write: whole local pixel (lx, ly)
    def _put(self, lx: int, ly: int, c: int) -> None:
        if not c:
            return
        sx = self.tx - lx - 1 if self.flip else self.tx + lx
        sy = self.ty + ly
        L = self.layer
        if 0 <= sx < L.w and 0 <= sy < L.h:
            L.px[sy * L.w + sx] = c
        else:
            self.spilled += 1

    # ---- pixels and rectangles
    def px(self, x: float, y: float, c: int) -> None:
        self._put(math.floor(x), math.floor(y), c)

    def rect(self, x: float, y: float, w: int, h: int, c: int) -> None:
        """Filled rectangle, top-left (x, y) rounded to whole px."""
        x0, y0 = round(x), round(y)
        for yy in range(y0, y0 + int(h)):
            for xx in range(x0, x0 + int(w)):
                self._put(xx, yy, c)

    def square(self, cx: float, cy: float, s: int, fill: int, edge: int = 0) -> None:
        """An s x s square centred on (cx, cy): `edge` is its 1 px rim (art bible §3: light fill, body rim)."""
        s = int(s)
        if s <= 0:
            return
        x0, y0 = math.floor(cx) - s // 2, math.floor(cy) - s // 2
        if edge and s >= 3:
            self.rect(x0, y0, s, s, edge)
            self.rect(x0 + 1, y0 + 1, s - 2, s - 2, fill)
        else:
            self.rect(x0, y0, s, s, fill)

    def bevel(self, cx: float, cy: float, s: int, body: int, lit: int, dark: int) -> None:
        """An s x s square with a 1 px light top/left and dark bottom/right edge (the Steel material mark)."""
        s = int(s)
        if s <= 0:
            return
        x0, y0 = math.floor(cx) - s // 2, math.floor(cy) - s // 2
        if s < 3:
            self.rect(x0, y0, s, s, lit if s == 1 else body)
            if s == 2:
                self._put(x0, y0, lit)
                self._put(x0 + 1, y0 + 1, dark)
            return
        self.rect(x0, y0, s, s, body)
        for i in range(s - 1):
            self._put(x0 + i, y0, lit)
            self._put(x0, y0 + i, lit)
        for i in range(1, s):
            self._put(x0 + i, y0 + s - 1, dark)
            self._put(x0 + s - 1, y0 + i, dark)

    def rect_ring(self, cx: float, cy: float, hw: float, hh: float, c: int, dash: int = 0, phase: int = 0) -> None:
        """1 px outline of the rectangle [cx-hw, cx+hw] x [cy-hh, cy+hh]; `dash` > 0 draws dash-on/dash-off."""
        x0, x1 = math.floor(cx - hw), math.floor(cx + hw)
        y0, y1 = math.floor(cy - hh), math.floor(cy + hh)
        k = 0
        pts = [(x, y0) for x in range(x0, x1 + 1)] + [(x1, y) for y in range(y0 + 1, y1 + 1)]
        pts += [(x, y1) for x in range(x1 - 1, x0 - 1, -1)] + [(x0, y) for y in range(y1 - 1, y0, -1)]
        for x, y in pts:
            if not dash or ((k + phase) // dash) % 2 == 0:
                self._put(x, y, c)
            k += 1

    # ---- 45-degree shapes
    def diamond(self, cx: float, cy: float, r: int, c: int, rim: int = 0) -> None:
        """|dx| + |dy| <= r, with an optional 1 px rim at |dx| + |dy| == r + 1."""
        X, Y, r = math.floor(cx), math.floor(cy), int(r)
        for dy in range(-r - 1, r + 2):
            for dx in range(-r - 1, r + 2):
                m = abs(dx) + abs(dy)
                if m <= r:
                    self._put(X + dx, Y + dy, c)
                elif m == r + 1 and rim:
                    self._put(X + dx, Y + dy, rim)

    def diamond_ring(self, cx: float, cy: float, r: int, w: int, c: int, gaps: int = 0, phase: float = 0.0) -> None:
        """A diamond outline from radius r - w + 1 to r; `gaps` cuts it into that many arcs (a breaking ring)."""
        X, Y, r, w = math.floor(cx), math.floor(cy), int(r), max(1, int(w))
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                m = abs(dx) + abs(dy)
                if r - w < m <= r:
                    if gaps:
                        a = (math.atan2(dy, dx) / (2 * math.pi) + phase) % 1.0
                        if (a * gaps) % 1.0 < 0.38:
                            continue
                    self._put(X + dx, Y + dy, c)

    def line(self, x0: float, y0: float, x1: float, y1: float, c: int) -> None:
        """1 px Bresenham line."""
        x, y, ex, ey = math.floor(x0), math.floor(y0), math.floor(x1), math.floor(y1)
        dx, dy = abs(ex - x), -abs(ey - y)
        sx, sy = (1 if x < ex else -1), (1 if y < ey else -1)
        err = dx + dy
        while True:
            self._put(x, y, c)
            if x == ex and y == ey:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x += sx
            if e2 <= dx:
                err += dx
                y += sy

    def poly(self, pts: list[tuple[float, float]], c: int) -> None:
        """Filled polygon by pixel centres (even-odd rule)."""
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        n = len(pts)
        for y in range(math.floor(min(ys)), math.ceil(max(ys)) + 1):
            cy = y + 0.5
            for x in range(math.floor(min(xs)), math.ceil(max(xs)) + 1):
                cx = x + 0.5
                inside = False
                j = n - 1
                for i in range(n):
                    xi, yi = pts[i]
                    xj, yj = pts[j]
                    if (yi > cy) != (yj > cy) and cx < (xj - xi) * (cy - yi) / (yj - yi) + xi:
                        inside = not inside
                    j = i
                if inside:
                    self._put(x, y, c)

    def sprite(self, rows: list[str], pal: dict[str, int], x: float, y: float) -> None:
        """A tiny sprite from strings ('.' and ' ' are empty), top-left at (x, y)."""
        X, Y = math.floor(x), math.floor(y)
        for r, row in enumerate(rows):
            for q, ch in enumerate(row):
                if ch not in ". ":
                    self._put(X + q, Y + r, pal.get(ch, 0))


def painters(w: int, h: int, ox: int, oy: int, flip: bool = False) -> tuple[dict[str, Layer], dict[str, Painter]]:
    """Fresh layers of w x h with painters whose origin is (ox, oy)."""
    layers = {k: Layer(w, h) for k in LAYERS}
    return layers, {k: Painter(layers[k], ox, oy, flip) for k in LAYERS}
