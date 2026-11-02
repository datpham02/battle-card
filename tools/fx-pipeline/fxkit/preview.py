"""Looking at a pack: contact sheet, GIF, and a strip of consecutive 12 fps steps (PixelFX render.mjs / act.mjs).

Previews draw on the real Misty Forest slab (design/assets/candidates/misty-forest/slab-cell-43x31-for-vfx.png,
nine-sliced to any cell size), because an effect judged on black looks different on the board.
Nothing here goes into a pack.
"""
from __future__ import annotations

from pathlib import Path

from .data import ROOT
from .gif import write_gif
from .painter import over
from .palette import hexc
from .pngio import load_image, write_png
from .render import Render, draw_frame

SLAB_SRC = ROOT / "design" / "assets" / "candidates" / "misty-forest" / "slab-cell-43x31-for-vfx.png"
SLAB_MARGINS = (1, 3, 2, 5)  # left, top, right, bottom of the slab cell image (its gap and lip included)
GROUND = hexc("#262521")
INK = hexc("#1B1722")
_slab_cache: dict = {}


def slab(w: int, h: int) -> list[int]:
    """A w x h board cell (slab face, light edge, lip, ink gap) nine-sliced from the slab candidate."""
    key = (w, h)
    if key in _slab_cache:
        return _slab_cache[key]
    sw, sh, src = load_image(SLAB_SRC)
    l, t, r, b = SLAB_MARGINS

    def map_axis(v: int, size: int, lo: int, hi: int, ssize: int) -> int:
        if v < lo:
            return v
        if v >= size - hi:
            return ssize - (size - v)
        return lo + (v - lo) % max(1, ssize - lo - hi)

    out = [src[map_axis(y, h, t, b, sh) * sw + map_axis(x, w, l, r, sw)] for y in range(h) for x in range(w)]
    _slab_cache[key] = out
    return out


def blit(dst: list[int], dw: int, dh: int, src: list[int], sw: int, sh: int, x0: int, y0: int) -> None:
    for y in range(sh):
        ty = y0 + y
        if not 0 <= ty < dh:
            continue
        for x in range(sw):
            c = src[y * sw + x]
            tx = x0 + x
            if c and 0 <= tx < dw:
                dst[ty * dw + tx] = c


def upscale(px: list[int], w: int, h: int, k: int) -> list[int]:
    if k == 1:
        return list(px)
    out = []
    for y in range(h):
        row = []
        for x in range(w):
            row.extend([px[y * w + x]] * k)
        for _ in range(k):
            out.extend(row)
    return out


def backdrop(r: Render) -> list[int]:
    """Ground colour, with the pack's cell drawn under its anchor when the pack belongs to a cell."""
    bg = [GROUND] * (r.w * r.h)
    cell = r.o.get("cell")
    if cell and r.comp.anchor in ("ground_center", "center"):
        cw, ch = int(cell[0]), int(cell[1])
        blit(bg, r.w, r.h, slab(cw, ch), cw, ch, r.ox - cw // 2, r.oy - ch // 2)
    return bg


def shown(r: Render, px: list[int]) -> list[int]:
    return over(backdrop(r), px)


def contact(r: Render, out: Path, zoom: int = 4, cols: int = 8, gap: int = 2) -> Path:
    n = r.n
    cols = min(cols, n)
    rows = (n + cols - 1) // cols
    W, H = cols * r.w + (cols - 1) * gap, rows * r.h + (rows - 1) * gap
    sheet = [INK] * (W * H)
    for i in range(n):
        blit(sheet, W, H, shown(r, r.whole(i)), r.w, r.h, (i % cols) * (r.w + gap), (i // cols) * (r.h + gap))
    return write_png(out, W * zoom, H * zoom, upscale(sheet, W, H, zoom))


def animation(r: Render, out: Path, zoom: int = 4, loops: int = 3, hold_ms: int = 500) -> Path:
    frames, delays = [], []
    bg = backdrop(r)
    reps = loops if r.loop else 1
    for _ in range(reps):
        for i in range(r.n):
            frames.append(upscale(over(bg, r.whole(i)), r.w, r.h, zoom))
            delays.append(max(2, round(r.frame_ms / 10)))
    frames.append(upscale(bg, r.w, r.h, zoom))
    delays.append(max(2, round(hold_ms / 10)))
    return write_gif(out, r.w * zoom, r.h * zoom, frames, delays)


def strip12(r: Render, out: Path, zoom: int = 3, gap: int = 2) -> Path:
    """Consecutive 1/12 s steps from 0 to the end: motion bugs do not show in evenly spaced samples."""
    step = 1 / 12
    times, t = [], 0.0
    while t < r.duration - 1e-9:
        times.append(t)
        t += step
    W = len(times) * (r.w + gap) - gap
    sheet = [INK] * (W * r.h)
    bg = backdrop(r)
    for j, tt in enumerate(times):
        layers, _, _ = draw_frame(r.comp, r.o, tt)
        blit(sheet, W, r.h, over(bg, over(layers["behind"].px, layers["front"].px)), r.w, r.h, j * (r.w + gap), 0)
    return write_png(out, W * zoom, r.h * zoom, upscale(sheet, W, r.h, zoom))
