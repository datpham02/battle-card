#!/usr/bin/env python3
"""Region environment generator — World Map v2 visual assets (2026-11-12).

Writes, for every climb region without hand/AI-made art, the bundle `assets/art/env/<region>/` that the battle
canvas reads through `ArtAssets` (same schema as the forest reference bundle):

  bg_<region>_far_<area>.png   800x360 far backdrops, one per map area (edge / inner / sanctum)
  bg_<region>_near.png         800x48 near strip (mist / cloud / haze), optional per region
  env_slab_<region>_9slice.png 16x16 slab, the forest 9-slice re-toned to the region's stone ramp
  env_slab_<region>_stamps.png + .json   the forest stamp sheet recoloured colour-for-colour (no pixel moved)
  env_thorn_<region>_tile16.png          the forest thorn tile recoloured
  env_support_<region>_{wall,pillar,arch}.png   the forest support kit recoloured by luminance rank
  region.json                  platform palette, support block, half tints, areas rules

Rules followed: art bible §6.2–6.6 (no outlines on scenery, S ≤ 25 %, V caps per region, dither only in mist /
cloud bands, props only in the horizon band and the two 80 px margins, bottom 36 % stepped darker), RENDER-STANDARDS
§4 signal colours kept out, REGION-MATERIALS-AND-PALETTE per-region hex. Pure standard library; deterministic
(seeded), so re-running reproduces the same bytes.

    python -X utf8 -I tools/asset-pipeline/make_region_env.py [--only hellfire,sands] [--out assets/art/env]
"""
from __future__ import annotations

import argparse
import json
import math
import random
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "fx-pipeline"))
from fxkit.pngio import read_png  # noqa: E402

PNG_SIG = b"\x89PNG\r\n\x1a\n"
W, H = 800, 360
HORIZON = 72          # 20 % band top (ScreenLayout.BOARD_BAND_TOP_RATIO)
MARGIN = 80           # side margins outside the 640 px play area
INK = "#1B1722"


# ----------------------------------------------------------------------------------------------- png / colour

def hx(s: str) -> tuple[int, int, int, int]:
    s = s.lstrip("#")
    return int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255


def encode_png(w: int, h: int, buf: bytearray) -> bytes:
    def chunk(kind: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)
    stride = w * 4
    raw = b"".join(b"\x00" + bytes(buf[y * stride:(y + 1) * stride]) for y in range(h))
    return PNG_SIG + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


def lum(c) -> float:
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def mix(a, b, t: float):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


def shade(c, k: float):
    """k < 1 darkens, k > 1 lightens (clamped)."""
    return tuple(max(0, min(255, int(round(c[i] * k)))) for i in range(3)) + (255,)


class Canvas:
    def __init__(self, w: int, h: int, fill=None):
        self.w, self.h = w, h
        self.buf = bytearray(w * h * 4)
        if fill is not None:
            self.rect(0, 0, w, h, fill)

    def put(self, x: int, y: int, c) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            i = (y * self.w + x) * 4
            self.buf[i:i + 4] = bytes(c)

    def get(self, x: int, y: int):
        i = (y * self.w + x) * 4
        return tuple(self.buf[i:i + 4])

    def rect(self, x: int, y: int, w: int, h: int, c) -> None:
        x0, y0 = max(0, x), max(0, y)
        x1, y1 = min(self.w, x + w), min(self.h, y + h)
        if x1 <= x0 or y1 <= y0:
            return
        row = bytes(c) * (x1 - x0)
        for yy in range(y0, y1):
            i = (yy * self.w + x0) * 4
            self.buf[i:i + (x1 - x0) * 4] = row

    def hline(self, x0: int, x1: int, y: int, c) -> None:
        self.rect(min(x0, x1), y, abs(x1 - x0) + 1, 1, c)

    def vline(self, x: int, y0: int, y1: int, c) -> None:
        self.rect(x, min(y0, y1), 1, abs(y1 - y0) + 1, c)

    def line(self, x0: int, y0: int, x1: int, y1: int, c) -> None:
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.put(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def poly(self, pts, c) -> None:
        ys = [p[1] for p in pts]
        for y in range(max(0, min(ys)), min(self.h, max(ys) + 1)):
            xs = []
            n = len(pts)
            for i in range(n):
                (xa, ya), (xb, yb) = pts[i], pts[(i + 1) % n]
                if ya == yb:
                    continue
                if (ya <= y < yb) or (yb <= y < ya):
                    xs.append(xa + (y - ya) * (xb - xa) / (yb - ya))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                self.rect(int(math.floor(xs[i])), y, int(math.ceil(xs[i + 1])) - int(math.floor(xs[i])) + 1, 1, c)

    def ellipse(self, cx: int, cy: int, rx: int, ry: int, c, top_only: bool = False) -> None:
        for y in range(-ry, 1 if top_only else ry + 1):
            k = 1.0 - (y * y) / float(ry * ry) if ry else 1.0
            if k < 0:
                continue
            half = int(rx * math.sqrt(k))
            self.rect(cx - half, cy + y, half * 2 + 1, 1, c)

    def dither(self, x: int, y: int, w: int, h: int, c, phase: int = 0) -> None:
        """2x2 checker (the only dither the bible allows: mist / cloud / one step band)."""
        for yy in range(max(0, y), min(self.h, y + h)):
            for xx in range(max(0, x), min(self.w, x + w)):
                if ((xx // 2) + (yy // 2) + phase) % 2 == 0:
                    self.put(xx, yy, c)

    def blit(self, other: "Canvas", x: int, y: int, mirror: bool = False) -> None:
        for yy in range(other.h):
            for xx in range(other.w):
                c = other.get(other.w - 1 - xx if mirror else xx, yy)
                if c[3]:
                    self.put(x + xx, y + yy, c)

    def colours(self) -> int:
        return len({bytes(self.buf[i:i + 4]) for i in range(0, len(self.buf), 4) if self.buf[i + 3]})

    def save(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(encode_png(self.w, self.h, self.buf))


# ------------------------------------------------------------------------------------------- scenery pieces

def steps(cv: Canvas, y0: int, y1: int, c_from, c_to, n: int, x0: int = 0, x1: int = W) -> None:
    """n flat bands from c_from (top) to c_to (bottom): stepped, never a smooth gradient."""
    for i in range(n):
        ya = y0 + (y1 - y0) * i // n
        yb = y0 + (y1 - y0) * (i + 1) // n
        cv.rect(x0, ya, x1 - x0, yb - ya, mix(c_from, c_to, i / max(n - 1, 1)))


def bottom_shade(cv: Canvas, start: int, bands: int, dark) -> None:
    """The control zone: the ground darkens step by step from `start` to the bottom."""
    for i in range(bands):
        ya = start + (H - start) * i // bands
        yb = start + (H - start) * (i + 1) // bands
        for y in range(ya, yb):
            for x in range(W):
                cv.put(x, y, mix(cv.get(x, y), dark, 0.18 * (i + 1)))
    cv.rect(0, H - 6, W, 6, dark)


def spire(cv: Canvas, x: int, base: int, w: int, h: int, c, cap: int = 2) -> None:
    cv.poly([(x - w // 2, base), (x - cap, base - h), (x + cap, base - h), (x + w // 2, base)], c)


def tower(cv: Canvas, x: int, base: int, w: int, h: int, c, crenel: int = 0, c_dark=None) -> None:
    cv.rect(x, base - h, w, h, c)
    if c_dark is not None:
        cv.rect(x + w - max(2, w // 4), base - h, max(2, w // 4), h, c_dark)
    if crenel:
        for i in range(0, w, crenel * 2):
            cv.rect(x + i, base - h - crenel, min(crenel, w - i), crenel, c)


def arch(cv: Canvas, x: int, base: int, w: int, h: int, c, hole, pier: int = 4) -> None:
    cv.rect(x, base - h, w, h, c)
    r = (w - pier * 2) // 2
    cv.rect(x + pier, base - h + r + 2, w - pier * 2, h - r - 2, hole)
    cv.ellipse(x + w // 2, base - h + r + 2, r, r, hole, top_only=True)


def pillar(cv: Canvas, x: int, top: int, w: int, h: int, light, mid, dark, cap: int = 3) -> None:
    cv.rect(x, top, w, h, mid)
    cv.rect(x, top, max(1, w // 4), h, light)
    cv.rect(x + w - max(1, w // 4), top, max(1, w // 4), h, dark)
    cv.rect(x - 2, top, w + 4, cap, light)
    cv.rect(x - 2, top + cap, w + 4, 1, dark)
    cv.rect(x - 2, top + h - cap, w + 4, cap, dark)


def chain(cv: Canvas, x0: int, y0: int, x1: int, y1: int, c, c2) -> None:
    n = max(1, int(math.hypot(x1 - x0, y1 - y0) // 4))
    for i in range(n + 1):
        x = int(round(x0 + (x1 - x0) * i / n))
        y = int(round(y0 + (y1 - y0) * i / n))
        cv.rect(x - 1, y - 1, 3, 3, c if i % 2 == 0 else c2)
        cv.put(x, y, c2 if i % 2 == 0 else c)


def banner(cv: Canvas, x: int, y: int, w: int, h: int, cloth, mark) -> None:
    """Square-in-square mark: the one cultural motif (bible §6.5)."""
    cv.rect(x, y, w, h, cloth)
    cv.poly([(x, y + h), (x + w // 2, y + h + w // 2), (x + w, y + h)], cloth)
    s = w - 6
    cv.rect(x + 3, y + 4, s, s, mark)
    cv.rect(x + 4, y + 5, s - 2, s - 2, cloth)
    cv.rect(x + 6, y + 7, s - 6, s - 6, mark)


def polyomino(cv: Canvas, x: int, y: int, cells, size: int, c, c_dark) -> None:
    """A broken Root-Form stone: grey square cells, worn (bible §6.5)."""
    for (cx, cy) in cells:
        cv.rect(x + cx * size, y + cy * size, size, size, c)
        cv.rect(x + cx * size, y + cy * size + size - 1, size, 1, c_dark)
        cv.rect(x + cx * size + size - 1, y + cy * size, 1, size, c_dark)


def broken_sword(cv: Canvas, x: int, y: int, ivory, dark) -> None:
    cv.rect(x, y - 14, 2, 14, ivory)
    cv.rect(x - 3, y - 4, 8, 2, dark)
    cv.rect(x, y - 16, 2, 2, dark)


def mist_band(cv: Canvas, y: int, h: int, c, phase: int = 0, x0: int = 0, x1: int = W) -> None:
    cv.dither(x0, y, x1 - x0, h, c, phase)


def fog_patches(cv: Canvas, rng: random.Random, y: int, h: int, c, n: int = 10, x0: int = 0, x1: int = W) -> None:
    """Drifting fog as dithered patches (checker 2x2 only inside each patch), never a full-width stripe."""
    for i in range(n):
        x = rng.randrange(x0, x1)
        w = rng.randrange(40, 140)
        ph = rng.randrange(max(2, h // 2), h + 1)
        cv.dither(x, y + rng.randrange(0, max(1, h - ph + 1)), w, ph, c, i)


def cloud_sea(cv: Canvas, rng: random.Random, y: int, h: int, light, mid, dark) -> None:
    cv.rect(0, y, W, h, mid)
    for _ in range(26):
        cx = rng.randrange(-20, W + 20)
        cy = y + rng.randrange(2, h)
        rx = rng.randrange(18, 60)
        ry = rng.randrange(4, 9)
        cv.ellipse(cx, cy, rx, ry, light, top_only=True)
        cv.ellipse(cx, cy + 1, rx - 4, 2, mid)
    cv.dither(0, y, W, 3, light, 1)
    cv.dither(0, y + h - 3, W, 3, dark, 0)


def reeds(cv: Canvas, rng: random.Random, x0: int, x1: int, base: int, c, c2, n: int) -> None:
    for _ in range(n):
        x = rng.randrange(x0, x1)
        h = rng.randrange(8, 22)
        cv.vline(x, base - h, base, c)
        cv.put(x + rng.choice((-1, 1)), base - h + 2, c2)
        cv.rect(x, base - h - 2, 1, 3, c2)


def mushroom(cv: Canvas, x: int, base: int, w: int, cap, cap_light, stem) -> None:
    cv.rect(x + w // 2 - 1, base - w // 2, 3, w // 2, stem)
    cv.ellipse(x + w // 2, base - w // 2, w // 2, max(2, w // 4), cap, top_only=True)
    cv.rect(x + 1, base - w // 2 - 1, w // 2, 1, cap_light)


def icicles(cv: Canvas, rng: random.Random, x0: int, x1: int, y: int, c, n: int) -> None:
    for _ in range(n):
        x = rng.randrange(x0, x1)
        h = rng.randrange(3, 9)
        cv.poly([(x - 1, y), (x + 2, y), (x, y + h)], c)


def frame_pillars(cv: Canvas, top: int, bottom: int, light, mid, dark, w: int = 18) -> None:
    pillar(cv, 14, top, w, bottom - top, light, mid, dark)
    pillar(cv, W - 14 - w, top, w, bottom - top, light, mid, dark)


def ground_cracks(cv: Canvas, rng: random.Random, x0: int, x1: int, y0: int, y1: int, c, n: int, glow=None) -> None:
    """Stepped 1 px cracks (bible §6.2) with one branch; `glow` lays a 2 px vein beside the Ink (hellfire exception)."""
    for _ in range(n):
        x, y = rng.randrange(x0, x1), rng.randrange(y0, y1)
        dx = rng.choice((-1, 1))
        for step in range(rng.randrange(14, 30)):
            cv.put(x, y, c)
            if glow is not None and step % 3 != 2:
                cv.put(x + 1, y, glow)
                cv.put(x + 2, y, glow)
            if step == 9:
                bx, by = x, y
                for _ in range(rng.randrange(5, 10)):
                    cv.put(bx, by, c)
                    if glow is not None:
                        cv.put(bx + 1, by, glow)
                    bx -= dx
                    by += rng.choice((0, 1))
            x += dx if rng.random() < 0.75 else 0
            y += rng.choice((0, 0, 1))


# ------------------------------------------------------------------------------------------- region palettes

REGIONS: dict[str, dict] = {
    "hellfire": {
        "chapter": "hellfire", "name": "Thành Hỏa Ngục",
        "sky": ("#2A2428", "#3A3236", "#443638"), "ground": ("#2A2628", "#1F1B1D", "#141114"),
        "stone": ("#4A4446", "#3A3436", "#2A2628"), "crack": "#241F22", "lip": "#1A1618", "lip_top": "#5A5254",
        "cover": ("#5A5658", "#45403F"), "thorn": ("#8C7E78", "#5E5450", "#2E2628"),
        "wall": ("#4E4648", "#3E3638", "#2E282A", "#221C1E"), "wall_cover": ("#5E5658", "#4A4244"),
        "half": ("#D8CCD0", "#B8ACB0"), "near": None, "vein": "#FFB21F",
    },
    "sands": {
        "chapter": "desert", "name": "Sa Mạc Cát Vùi",
        "sky": ("#AE9E80", "#B8A888", "#C0B090"), "ground": ("#9A8C70", "#7E7058", "#4E4432"),
        "stone": ("#B4A68C", "#9A8C70", "#7E7058"), "crack": "#6E6248", "lip": "#5E5440", "lip_top": "#C4B698",
        "cover": ("#C8B890", "#B4A478"), "thorn": ("#C4B690", "#8E8268", "#5E5440"),
        "wall": ("#B4A68C", "#9A8C70", "#7E7058", "#5E5440"), "wall_cover": ("#C8B890", "#A89A74"),
        "half": ("#F2EEE4", "#D8CCD0"), "near": "#C8B898", "jade": "#4F8A80",
    },
    "swamp": {
        "chapter": "swamp", "name": "Đầm Lầy Độc",
        "sky": ("#5E6350", "#6B705A", "#737860"), "ground": ("#454838", "#353A2C", "#20241A"),
        "stone": ("#6A6858", "#545244", "#403E32"), "crack": "#36352A", "lip": "#2A2A20", "lip_top": "#787664",
        "cover": ("#4E5A3C", "#3C4630"), "thorn": ("#9A9478", "#66604A", "#36352A"),
        "wall": ("#6A6858", "#545244", "#403E32", "#2A2A20"), "wall_cover": ("#4E5A3C", "#3C4630"),
        "half": ("#D8E0D4", "#BCB0BC"), "near": "#7A7E6A", "cap": ("#6A5868", "#8E8296", "#4A3E4A"),
    },
    "dungeon": {
        "chapter": "ch2", "name": "Hầm Ngục",
        "sky": ("#2C3038", "#363A44", "#3E4450"), "ground": ("#30343C", "#2C2826", "#1C1A1A"),
        "stone": ("#5A5E6A", "#484C58", "#363A44"), "crack": "#2E323B", "lip": "#24272E", "lip_top": "#6A6E7A",
        "cover": ("#6E6252", "#4E4438"), "thorn": ("#8E8A80", "#5E5A54", "#2E2A28"),
        "wall": ("#5A5E6A", "#484C58", "#363A44", "#24272E"), "wall_cover": ("#6E6252", "#4E4438"),
        "half": ("#D6DEEC", "#B4AABC"), "near": None, "torch": ("#8A6A40", "#6A5030"), "banner": ("#3A3448", "#5A5468"),
    },
    "ice_tower": {
        "chapter": "ch3", "name": "Tháp Sương",
        "sky": ("#9AA0C0", "#8E95B8", "#A6ABC8"), "ground": ("#5A6078", "#4C5069", "#2E3248"),
        "stone": ("#6A7088", "#565C74", "#444860"), "crack": "#3E4256", "lip": "#30344A", "lip_top": "#7E84A0",
        "cover": ("#A6ACC4", "#8A90B0"), "thorn": ("#B0B6CC", "#7E84A0", "#444860"),
        "wall": ("#6A7088", "#565C74", "#444860", "#30344A"), "wall_cover": ("#A6ACC4", "#8A90B0"),
        "half": ("#E0E6F4", "#C8C0D6"), "near": "#B4B8CC",
    },
    "sky_isles": {
        "chapter": "sky_isles", "name": "Không Đảo",
        "sky": ("#8AA2B8", "#B9BFC8", "#C4C4B4"), "ground": ("#6A7080", "#5A6070", "#343A48"),
        "stone": ("#7A7268", "#625A50", "#4C463E"), "crack": "#3E3A34", "lip": "#302C28", "lip_top": "#8E8678",
        "cover": ("#8A8478", "#6E6860"), "thorn": ("#A8A094", "#6E6860", "#3E3A34"),
        "wall": ("#7A7268", "#625A50", "#4C463E", "#302C28"), "wall_cover": ("#8A8478", "#6E6860"),
        "half": ("#E4ECF4", "#D0C8D8"), "near": "#A4AEBC", "thunder": "#C8C098",
    },
    "lattice_heart": {
        "chapter": "an_dai", "name": "Tâm Lưới",
        "sky": ("#15142A", "#15142A", "#1A1930"), "ground": ("#1A1930", "#0E0D1C", "#0A0914"),
        "stone": ("#4A4858", "#3A3848", "#2C2A3A"), "crack": "#24222E", "lip": "#1C1A26", "lip_top": "#5E5C6E",
        "cover": ("#4A4858", "#3A3848"), "thorn": ("#8E8A98", "#5E5C6E", "#2C2A3A"),
        "wall": ("#4A4858", "#3A3848", "#2C2A3A", "#1C1A26"), "wall_cover": ("#4A4858", "#3A3848"),
        "half": ("#D4D0E4", "#B8B0C8"), "near": None, "lattice": "#FFD45C", "ivory": "#9A9690",
    },
}

AREAS = ("edge", "inner", "sanctum")


# -------------------------------------------------------------------------------------------- backdrops
# Layout (bible §6.4, measured on the forest v4): the far band is rows 0..~100 (the 20 % horizon band plus the
# transition edge just under it), the board + support wall cover most of rows 72..300 in the play area
# (x 80..720 at 16:9), and rows 300..360 are the control zone. So the far band carries the identity, the margins
# frame it, and the ground stays calm under the board.

def base_sky_ground(cv: Canvas, p: dict, horizon_bands: int = 4, ground_bands: int = 5) -> None:
    sky = [hx(c) for c in p["sky"]]
    g = [hx(c) for c in p["ground"]]
    steps(cv, 0, HORIZON - 10, sky[0], sky[1], horizon_bands)
    cv.rect(0, HORIZON - 10, W, 10, sky[2])
    steps(cv, HORIZON, 232, g[0], g[1], ground_bands)
    cv.rect(0, 232, W, H - 232, g[1])


def finish_ground(cv: Canvas, rng: random.Random, p: dict, paving: bool = True) -> None:
    """Plaza paving under the board (low contrast), speckle, then the stepped control-zone shade."""
    g0, g1, g2 = (hx(c) for c in p["ground"])
    if paving:
        # Calm ground (in-game check 2026-11-12: a paving grid behind the board read as a wall): a few wide, faint
        # stepped bands and sparse flat stones; the board and its support wall cover most of it anyway.
        for i in range(6):
            y = 100 + i * 24 + rng.randrange(0, 8)
            cv.rect(0, y, W, 2, mix(g0, g1, 0.5 + 0.08 * (i % 2)))
        for _ in range(26):
            x, y = rng.randrange(0, W), rng.randrange(104, 296)
            w = rng.randrange(8, 26)
            cv.rect(x, y, w, 3, mix(g0, g1, 0.35))
            cv.rect(x, y + 3, w, 1, mix(g1, g2, 0.3))
    dark = mix(g1, g2, 0.5)
    for _ in range(200):
        x, y = rng.randrange(0, W), rng.randrange(HORIZON, 300)
        cv.rect(x, y, rng.choice((1, 2, 2, 3)), 1, dark if rng.random() < 0.6 else mix(g0, g1, 0.3))
    bottom_shade(cv, 236, 5, g2)


def rubble_edge(cv: Canvas, rng: random.Random, y: int, c, c2, n: int = 90, x0: int = 0, x1: int = W) -> None:
    """Breaks the straight horizon: rocks / rubble / tufts scattered along the ground's far edge."""
    for _ in range(n):
        x = rng.randrange(x0, x1)
        w, h = rng.randrange(3, 12), rng.randrange(2, 5)
        cv.rect(x, y - h + rng.randrange(0, 4), w, h, c)
        cv.rect(x, y - h + rng.randrange(0, 4), max(1, w // 2), 1, c2)


def skyline(cv: Canvas, rng: random.Random, base: int, c, kinds: tuple, count: int, hmin: int, hmax: int,
            wmin: int = 8, wmax: int = 24, x0: int = -20, x1: int = W + 20, c_dark=None) -> None:
    for _ in range(count):
        x = rng.randrange(x0, x1)
        h = rng.randrange(hmin, hmax)
        w = rng.randrange(wmin, wmax)
        kind = rng.choice(kinds)
        if kind == "spire":
            spire(cv, x, base, w, h, c, cap=max(1, w // 6))
        elif kind == "tower":
            tower(cv, x, base, w, h, c, crenel=max(2, w // 6) if rng.random() < 0.6 else 0, c_dark=c_dark)
        elif kind == "dome":
            cv.rect(x - w // 2, base - h // 2, w, h // 2, c)
            cv.ellipse(x, base - h // 2, w // 2, h // 2, c, top_only=True)
        elif kind == "arch":
            arch(cv, x, base, w + 10, h, c, c if c_dark is None else c_dark, pier=max(3, w // 5))
        elif kind == "hill":
            cv.ellipse(x, base, w * 3, h, c, top_only=True)
        elif kind == "tree":
            cv.rect(x, base - h, max(2, w // 6), h, c)
            cv.ellipse(x + 1, base - h, w // 2, h // 3, c, top_only=True)
            cv.ellipse(x + 1, base - h + h // 4, w // 3, h // 4, c, top_only=True)
        elif kind == "stump":
            cv.rect(x, base - h // 3, max(2, w // 4), h // 3, c)


def bg_hellfire(area: str, rng: random.Random) -> Canvas:
    p = REGIONS["hellfire"]
    cv = Canvas(W, H)
    base_sky_ground(cv, p)
    far, mid, near = hx("#1E1A1E"), hx("#2A2428"), hx("#332C30")
    smoke = hx("#443638")
    # ash smoke bands in the sky, then three depths of black citadel: spires, walls, bridges, towers
    for y in (14, 30, 46):
        cv.dither(0, y, W, 4, smoke, y // 2)
        cv.rect(rng.randrange(0, 200), y + 1, rng.randrange(200, 500), 2, smoke)
    skyline(cv, rng, 66, far, ("spire", "tower", "spire"), 34, 20, 58, 6, 18)
    cv.rect(0, 58, W, 10, far)
    for x in range(0, W, 14):
        cv.rect(x, 54, 7, 4, far)
    skyline(cv, rng, 74, mid, ("tower", "spire", "arch"), 16 if area == "edge" else 24, 16, 50, 10, 26, c_dark=far)
    for x in range(-10, W, 48):
        arch(cv, x + rng.randrange(0, 10), 76, 40, 18, mid, far, pier=6)
    if area != "edge":
        for x in (150, 400, 640):
            xx = x + rng.randrange(-30, 30)
            h = rng.randrange(50, 70)
            tower(cv, xx, 78, 30, h, near, crenel=4, c_dark=mid)
            spire(cv, xx + 15, 78 - h, 12, 30, near, cap=2)
            chain(cv, xx + 30, 30, xx + 70, 60, mid, far)
    if area == "sanctum":
        tower(cv, 340, 80, 120, 76, near, crenel=6, c_dark=mid)
        cv.rect(392, 50, 16, 30, far)
        cv.ellipse(400, 50, 8, 8, far, top_only=True)
        spire(cv, 356, 4, 14, 36, near)
        spire(cv, 444, 4, 14, 36, near)
        banner(cv, 366, 24, 12, 24, hx("#3A2E34"), hx("#5A4A50"))
        banner(cv, 422, 24, 12, 24, hx("#3A2E34"), hx("#5A4A50"))
    # lava veins: only inside cracks (1 px Ink + 2 px amber), sparse, never a wash (brief section 6)
    vein, ink = hx(p["vein"]), hx(INK)
    for x in range(30, W, 70):
        y = 70 + rng.randrange(-2, 2)
        cv.rect(x, y, 2, 1, ink)
        cv.rect(x + 2, y, 3, 1, vein)
    rubble_edge(cv, rng, 92, mix(far, hx(p["ground"][0]), 0.5), mid, 110)
    finish_ground(cv, rng, p)
    # margins: charred pillars with chains and cracked, vein-lit ground
    light, m, d = hx("#4E4648"), hx("#3E3638"), hx("#2E282A")
    for x, mirror in ((44, False), (W - 44, True)):
        pillar(cv, x - 11, 30, 22, 272, light, m, d, cap=4)
        spire(cv, x, 30, 26, 28, m)
        chain(cv, x, 70, x + (40 if not mirror else -40), 130, m, d)
        chain(cv, x, 150, x + (34 if not mirror else -34), 230, m, d)
        for i in range(6):
            cv.rect(x - 11 + rng.randrange(0, 20), 60 + i * 40 + rng.randrange(0, 20), 2, 2, ink)
    ground_cracks(cv, rng, 6, MARGIN + 10, 110, 300, ink, 4, vein)
    ground_cracks(cv, rng, W - MARGIN - 10, W - 6, 110, 300, ink, 4, vein)
    ground_cracks(cv, rng, 20, W - 20, 300, 340, ink, 5 if area == "sanctum" else 3, vein)
    polyomino(cv, 100, 250, [(0, 0), (1, 0), (1, 1)], 7, hx("#4A4446"), hx("#2A2628"))
    broken_sword(cv, W - 104, 270, hx("#C8C0B4"), hx("#2A2628"))
    return cv


def bg_sands(area: str, rng: random.Random) -> Canvas:
    p = REGIONS["sands"]
    cv = Canvas(W, H)
    base_sky_ground(cv, p)
    haze = hx(p["sky"][2])
    dune_far, dune_mid, dune_near = hx("#B0A28A"), hx("#A89A80"), hx("#9A8C70")
    ruin, ruin_d, ruin_l = hx("#8E8268"), hx("#7A6E58"), hx("#A09478")
    cv.dither(0, 26, W, 6, haze, 0)
    for i in range(9):
        cv.ellipse(rng.randrange(0, W), 70, rng.randrange(80, 170), rng.randrange(12, 26), dune_far, top_only=True)
    skyline(cv, rng, 66, mix(ruin_d, dune_far, 0.5), ("tower", "arch", "dome"), 14, 10, 34, 8, 20)
    for i in range(6):
        cv.ellipse(rng.randrange(0, W), 78, rng.randrange(60, 140), rng.randrange(8, 18), dune_mid, top_only=True)
    # an aqueduct line of arches half-sunk in the sand, then the plaza's ruins
    for x in range(-20, W, 44):
        arch(cv, x + 6, 82, 36, 22 + rng.randrange(0, 6), ruin, dune_mid, pier=5)
    cv.rect(0, 58, W, 3, ruin)
    if area != "edge":
        for x in (120, 250, 420, 560, 690):
            xx = x + rng.randrange(-24, 24)
            h = rng.randrange(30, 54)
            pillar(cv, xx, 84 - h, 10, h, ruin_l, ruin, ruin_d)
        arch(cv, 330, 86, 140, 52, ruin, haze, pier=12)
        cv.rect(330, 34, 140, 3, ruin_l)
    if area == "sanctum":
        arch(cv, 300, 90, 200, 74, ruin, haze, pier=18)
        cv.rect(300, 16, 200, 4, ruin_l)
        cv.rect(300, 20, 200, 2, ruin_d)
        banner(cv, 310, 24, 14, 30, hx("#7A6E58"), hx("#4F8A80"))
        banner(cv, 476, 24, 14, 30, hx("#7A6E58"), hx("#4F8A80"))
        for x in (322, 466):
            pillar(cv, x, 24, 12, 66, ruin_l, ruin, ruin_d)
    for i in range(7):
        cv.ellipse(rng.randrange(0, W), 92, rng.randrange(40, 100), rng.randrange(5, 10), dune_near, top_only=True)
    rubble_edge(cv, rng, 100, ruin_d, ruin_l, 60)
    finish_ground(cv, rng, p)
    for _ in range(16):
        cx = rng.choice((rng.randrange(0, MARGIN + 30), rng.randrange(W - MARGIN - 30, W)))
        cv.ellipse(cx, rng.randrange(100, 300), rng.randrange(14, 40), rng.randrange(3, 6), dune_mid, top_only=True)
    light, m, d = hx("#B4A68C"), hx("#9A8C70"), hx("#7E7058")
    for x in (40, W - 40):
        pillar(cv, x - 10, 20, 20, 240, light, m, d, cap=4)
        cv.rect(x - 14, 16, 28, 4, light)
        cv.ellipse(x, 262, 40, 12, dune_near, top_only=True)
    # the jade-glazed jar, dulled, half buried (brief section 5)
    jade, jade_d = hx(p["jade"]), hx("#3E6E66")
    cv.ellipse(100, 276, 11, 13, jade)
    cv.rect(92, 274, 16, 10, jade)
    cv.rect(89, 276, 22, 2, jade_d)
    cv.rect(96, 262, 8, 3, jade_d)
    cv.ellipse(100, 288, 22, 5, dune_near, top_only=True)
    polyomino(cv, W - 120, 250, [(0, 0), (1, 0), (2, 0), (1, 1)], 7, hx("#9A8C70"), hx("#6E6248"))
    broken_sword(cv, 118, 312, hx("#EFE6D2"), hx("#5E5440"))
    return cv


def bg_swamp(area: str, rng: random.Random) -> Canvas:
    p = REGIONS["swamp"]
    cv = Canvas(W, H)
    base_sky_ground(cv, p)
    far, mid, near = hx("#565A46"), hx("#484C3A"), hx("#3C402E")
    water, water_l, water_d = hx("#4E5240"), hx("#5A5E4C"), hx("#424634")
    fog = hx(p["near"])
    skyline(cv, rng, 54, far, ("tree", "tower", "tree", "stump"), 30, 14, 40, 10, 26)
    fog_patches(cv, rng, 44, 8, fog, 12)
    skyline(cv, rng, 62, mid, ("tree", "arch", "tower", "tree"), 18 if area == "edge" else 26, 12, 34, 10, 24, c_dark=far)
    # flat water with sunken columns and reflections, then the reed shore
    cv.rect(0, 62, W, 20, water)
    for _ in range(50):
        x = rng.randrange(0, W)
        cv.rect(x, 64 + rng.randrange(0, 16), rng.randrange(6, 24), 1, water_l if rng.random() < 0.6 else water_d)
    for x in range(20, W, 70):
        xx = x + rng.randrange(-12, 12)
        h = rng.randrange(10, 26)
        tower(cv, xx, 72, 8, h, near)
        cv.rect(xx, 72, 8, 3, water_d)
    if area != "edge":
        for x in (180, 420, 620):
            xx = x + rng.randrange(-20, 20)
            arch(cv, xx, 70, 50, 34, near, mid, pier=7)
            cv.rect(xx, 70, 50, 2, water_d)
    if area == "sanctum":
        tower(cv, 340, 74, 120, 44, near, c_dark=mid)
        arch(cv, 368, 74, 64, 38, mid, hx("#303426"), pier=9)
        cap, cap_l, stem = (hx(c) for c in p["cap"])
        for x in (344, 372, 436):
            mushroom(cv, x, 30 + rng.randrange(0, 4), 12, cap, cap_l, stem)
    fog_patches(cv, rng, 74, 10, fog, 14)
    reeds(cv, rng, 0, W, 90, hx("#3E422E"), hx("#56604A"), 90)
    rubble_edge(cv, rng, 92, near, mid, 40)
    finish_ground(cv, rng, p, paving=False)
    # margins: dead trunks with bare branches, reeds, mushrooms, mud pools
    trunk, trunk_d = hx("#3E3E30"), hx("#2A2A20")
    for x, mirror in ((60, False), (W - 60, True)):
        s = -1 if mirror else 1
        cv.rect(x - 9, 0, 18, 290, trunk)
        cv.rect(x + (5 if mirror else -9), 0, 4, 290, trunk_d)
        for by, bl in ((30, 44), (70, 36), (120, 28)):
            cv.line(x, by, x + s * bl, by - bl // 2, trunk)
            cv.line(x, by + 1, x + s * bl, by + 1 - bl // 2, trunk)
            cv.line(x + s * bl, by - bl // 2, x + s * bl + s * 10, by - bl // 2 - 10, trunk)
        cv.poly([(x - 16, 290), (x + 16, 290), (x + 30, 310), (x - 30, 310)], trunk_d)
        for i in range(5):
            cv.rect(x - 9 + rng.randrange(0, 16), 150 + i * 28, 3, 1, hx("#4E5A3C"))
    reeds(cv, rng, 4, MARGIN + 30, 300, hx("#3E422E"), hx("#56604A"), 30)
    reeds(cv, rng, W - MARGIN - 30, W - 4, 300, hx("#3E422E"), hx("#56604A"), 30)
    cap, cap_l, stem = (hx(c) for c in p["cap"])
    n_shroom = 3 if area == "edge" else 5 if area == "inner" else 8
    for i in range(n_shroom):
        side = i % 2
        x = rng.randrange(6, MARGIN + 20) if side == 0 else rng.randrange(W - MARGIN - 30, W - 20)
        mushroom(cv, x, rng.randrange(150, 290), rng.randrange(8, 18), cap, cap_l, stem)
    for _ in range(8):
        cx = rng.randrange(40, W - 40)
        cv.ellipse(cx, rng.randrange(262, 330), rng.randrange(20, 60), rng.randrange(3, 7), water, top_only=True)
    fog_patches(cv, rng, 244, 12, fog, 8)
    polyomino(cv, 96, 240, [(0, 0), (0, 1), (1, 1)], 7, hx("#6A6858"), hx("#403E32"))
    broken_sword(cv, W - 100, 256, hx("#D8D0C0"), hx("#2A2A20"))
    return cv


def bg_dungeon(area: str, rng: random.Random) -> Canvas:
    p = REGIONS["dungeon"]
    cv = Canvas(W, H)
    base_sky_ground(cv, p, horizon_bands=3)
    wall, wall_d, hole, hole_d = hx("#3E4450"), hx("#343A44"), hx("#262A32"), hx("#1C2026")
    light, m, d = hx("#5A5E6A"), hx("#484C58"), hx("#363A44")
    # the vault: no sky; stone courses, a row of arches whose foot is the horizon, pillars, chains
    cv.rect(0, 0, W, 86, wall)
    for y in range(0, 86, 7):
        cv.rect(0, y, W, 1, wall_d)
        for x in range(-((y // 7) % 2) * 11, W, 22):
            cv.rect(x, y, 1, 7, wall_d)
    cv.rect(0, 0, W, 12, hole_d)
    n_arch = 5 if area != "sanctum" else 3
    pitch = W // n_arch
    for i in range(n_arch):
        x = i * pitch + pitch // 2
        aw = pitch - 44 if area != "sanctum" else pitch - 100
        ah = 58 if area != "sanctum" else 74
        arch(cv, x - aw // 2, 86, aw, ah, wall_d, hole, pier=8)
        arch(cv, x - aw // 2 + 10, 86, aw - 20, ah - 14, hole, hole_d, pier=6)
        pillar(cv, x - aw // 2 - 14, 10, 14, 76, light, m, d)
    pillar(cv, W - 20, 10, 14, 76, light, m, d)
    for i in range(2 if area == "edge" else 5):
        x = rng.randrange(60, W - 60)
        chain(cv, x, 0, x + rng.randrange(-12, 12), rng.randrange(30, 70), m, d)
    torch, torch_d = hx(p["torch"][0]), hx(p["torch"][1])
    for x in (100, W - 100) if area == "edge" else (100, 300, W - 300, W - 100):
        cv.rect(x - 1, 44, 3, 10, d)
        cv.rect(x - 3, 36, 7, 8, torch_d)
        cv.rect(x - 2, 30, 5, 6, torch)
        cv.rect(x - 1, 28, 3, 2, torch)
    if area == "sanctum":
        banner(cv, 60, 14, 20, 44, hx(p["banner"][0]), hx(p["banner"][1]))
        banner(cv, W - 80, 14, 20, 44, hx(p["banner"][0]), hx(p["banner"][1]))
        cv.rect(340, 60, 120, 26, hole_d)
        for i in range(3):
            cv.rect(320 + i * 10, 80 + i * 4, 160 - i * 20, 4, wall_d if i % 2 == 0 else d)
    cv.rect(0, 86, W, 4, d)
    rubble_edge(cv, rng, 100, d, m, 70)
    finish_ground(cv, rng, p)
    # margins: massive pillars, hanging chains, barred cells, rubble
    for x in (46, W - 46):
        pillar(cv, x - 12, 60, 24, 240, light, m, d, cap=4)
        chain(cv, x - 30, 90, x - 30, 200, m, d)
        chain(cv, x + 30, 90, x + 30, 180, m, d)
        cv.rect(x - 34, 210, 68, 60, hole)
        for bx in range(x - 30, x + 34, 8):
            cv.rect(bx, 210, 2, 60, d)
        cv.rect(x - 34, 208, 68, 2, light)
    for _ in range(20):
        x = rng.choice((rng.randrange(4, MARGIN + 20), rng.randrange(W - MARGIN - 20, W - 8)))
        cv.rect(x, rng.randrange(110, 320), rng.randrange(3, 10), rng.randrange(2, 5), d)
    polyomino(cv, 96, 246, [(0, 0), (1, 0), (2, 0), (2, 1)], 7, hx("#5A5E6A"), hx("#363A44"))
    broken_sword(cv, W - 104, 266, hx("#D8D4CC"), hx("#24272E"))
    return cv


def bg_ice_tower(area: str, rng: random.Random) -> Canvas:
    p = REGIONS["ice_tower"]
    cv = Canvas(W, H)
    base_sky_ground(cv, p)
    tower_c, tower_d, far_t = hx("#6E7494"), hx("#5E6484"), hx("#8088AA")
    cloud_l, cloud_m, cloud_d = hx("#B4B8CC"), hx("#A6ABC2"), hx("#9AA0B8")
    cv.dither(0, 10, W, 4, cloud_m, 0)
    # far towers in the cloud sea (three depths), bridges between them, the terrace railing
    skyline(cv, rng, 58, far_t, ("tower", "spire"), 18, 26, 64, 8, 20)
    xs = (90, 400, 690) if area == "edge" else (60, 220, 400, 580, 740)
    for x in xs:
        xx = x + rng.randrange(-20, 20)
        h = rng.randrange(40, 68)
        tower(cv, xx, 66, 22, h, tower_c, crenel=3, c_dark=tower_d)
        spire(cv, xx + 11, 66 - h - 2, 18, 20, tower_c)
        tower(cv, xx - 10, 66, 10, h - 20, tower_d, crenel=2)
        icicles(cv, rng, xx, xx + 16, 66 - h + 6, cloud_l, 3)
    if area != "edge":
        for x0, x1 in ((230, 400), (400, 590)):
            cv.rect(x0, 44, x1 - x0, 4, tower_d)
            for x in range(x0, x1, 18):
                arch(cv, x, 48, 16, 10, tower_d, hx(p["sky"][1]), pier=3)
    if area == "sanctum":
        tower(cv, 364, 70, 72, 76, tower_c, crenel=5, c_dark=tower_d)
        spire(cv, 400, -6, 22, 40, tower_c)
        arch(cv, 386, 70, 28, 30, tower_d, hx("#3A3E66"), pier=5)
        banner(cv, 372, 12, 12, 26, hx("#3A3E66"), hx("#8E8A6A"))
        banner(cv, 416, 12, 12, 26, hx("#3A3E66"), hx("#8E8A6A"))
    cloud_sea(cv, rng, 50, 26, cloud_l, cloud_m, cloud_d)
    rail, rail_d = hx("#6A7090"), hx("#565C74")
    cv.rect(0, 70, W, 2, rail)
    cv.rect(0, 78, W, 4, rail)
    cv.rect(0, 82, W, 1, rail_d)
    for x in range(8, W, 20):
        cv.rect(x, 70, 4, 12, rail)
        cv.rect(x + 2, 70, 2, 12, rail_d)
    icicles(cv, rng, 0, W, 83, cloud_l, 28)
    rubble_edge(cv, rng, 100, rail_d, cloud_m, 40)
    finish_ground(cv, rng, p)
    # margins: frosted pillars, low ice spires (blue-grey, no cyan), frost on the ground
    light, m, d = hx("#7E84A8"), hx("#6A7088"), hx("#565C74")
    for x in (44, W - 44):
        pillar(cv, x - 10, 40, 20, 250, light, m, d, cap=4)
        icicles(cv, rng, x - 12, x + 12, 44, cloud_l, 5)
        for sx, sy in ((x - 30, 230), (x + 24, 214), (x - 8, 250)):
            spire(cv, sx, sy + 34, 12, 34, hx("#8A90B0"), cap=1)
            spire(cv, sx + 1, sy + 34, 5, 24, cloud_m, cap=1)
    for _ in range(30):
        x = rng.choice((rng.randrange(4, MARGIN + 30), rng.randrange(W - MARGIN - 30, W - 6)))
        cv.rect(x, rng.randrange(100, 320), rng.randrange(2, 10), 1, hx("#8A90B0"))
    fog_patches(cv, rng, 296, 8, cloud_d, 8)
    polyomino(cv, 100, 252, [(0, 0), (1, 0), (1, 1), (2, 1)], 7, hx("#6A7088"), hx("#444860"))
    broken_sword(cv, W - 104, 272, hx("#EFE6D2"), hx("#30344A"))
    return cv


def bg_sky_isles(area: str, rng: random.Random) -> Canvas:
    p = REGIONS["sky_isles"]
    cv = Canvas(W, H)
    base_sky_ground(cv, p, horizon_bands=5)
    thunder = hx(p["thunder"])
    cv.rect(0, 38, W, 12, thunder)
    cv.dither(0, 34, W, 4, thunder, 0)
    cv.dither(0, 50, W, 4, thunder, 1)
    isl, isl_top, isl_d, isl_far = hx("#5A6474"), hx("#7A7060"), hx("#46505E"), hx("#7A8A9A")
    for i in range(6):
        x, y, w = rng.randrange(0, W), rng.randrange(20, 50), rng.randrange(14, 30)
        cv.rect(x - w // 2, y, w, 2, isl_far)
        cv.poly([(x - w // 2, y + 2), (x + w // 2, y + 2), (x, y + 2 + w // 2)], isl_far)
    n = 5 if area == "edge" else 8
    for i in range(n):
        x = rng.randrange(20, W - 20)
        y = rng.randrange(8, 56)
        w = rng.randrange(26, 64)
        d = rng.randrange(w // 3, w // 2 + 4)
        cv.rect(x - w // 2, y, w, 3, isl_top)
        cv.poly([(x - w // 2, y + 3), (x + w // 2, y + 3), (x + w // 2 - w // 5, y + 3 + d // 2), (x + w // 8, y + 3 + d),
                 (x - w // 6, y + 3 + d - 3), (x - w // 2 + w // 6, y + 3 + d // 2)], isl)
        for j in range(3):
            cv.rect(x - w // 2 + 3 + j * 5, y + 5 + j * 3, w - 8 - j * 12, 1, isl_d)
        cv.rect(x - w // 2 + 2, y + 3, w - 4, 1, isl_d)
        if rng.random() < 0.7:
            tower(cv, x - 4, y, 8, rng.randrange(8, 18), isl_d, crenel=2)
        if rng.random() < 0.4:
            arch(cv, x + 4, y, 14, 9, isl_d, hx(p["sky"][0]), pier=3)
    for x0, y0 in ((110, 6), (640, 10)) if area != "edge" else ((640, 8),):
        cv.line(x0, y0, x0 + 8, y0 + 14, hx("#D8D4B8"))
        cv.line(x0 + 8, y0 + 14, x0 + 2, y0 + 26, hx("#D8D4B8"))
        cv.line(x0 + 2, y0 + 26, x0 + 7, y0 + 34, hx("#D8D4B8"))
    if area == "sanctum":
        cv.rect(290, 36, 220, 6, isl_top)
        cv.poly([(290, 42), (510, 42), (470, 76), (330, 68)], isl)
        tower(cv, 320, 36, 16, 30, isl_d, crenel=3)
        tower(cv, 466, 36, 16, 26, isl_d, crenel=3)
        arch(cv, 360, 36, 80, 26, isl_d, hx(p["sky"][1]), pier=8)
        chain(cv, 290, 42, 250, 70, isl_d, isl)
        chain(cv, 510, 42, 550, 70, isl_d, isl)
    cloud_sea(cv, rng, 56, 24, hx("#A4AEBC"), hx("#8A9AAC"), hx("#7A8A9C"))
    # the island the board stands on: rim of broken stone, then cloud below the control zone
    rim, rim_l = hx("#5A6070"), hx("#8A8478")
    cv.rect(0, 80, W, 4, rim_l)
    rubble_edge(cv, rng, 92, hx("#4C463E"), rim_l, 80)
    finish_ground(cv, rng, p)
    cloud_sea(cv, rng, 300, 60, hx("#9AA6B4"), hx("#7A8A9C"), hx("#6A7A8C"))
    cv.poly([(0, 296), (W, 296), (W, 312), (700, 304), (560, 318), (420, 306), (300, 320), (160, 308), (0, 314)], rim)
    cv.rect(0, H - 6, W, 6, hx(p["ground"][2]))
    light, m, d = hx("#8A8478"), hx("#6E6860"), hx("#4C463E")
    for x, mirror in ((50, False), (W - 84, True)):
        cv.rect(x, 90, 34, 190, m)
        cv.rect(x + (28 if mirror else 0), 90, 6, 190, d)
        cv.rect(x, 88, 34, 3, light)
        cv.poly([(x, 280), (x + 34, 280), (x + 24, 300), (x + 8, 296)], d)
        bx = x + 34 if not mirror else x - 40
        cv.rect(bx, 120, 40, 6, m)
        cv.rect(bx, 126, 40, 2, d)
        for i in range(3):
            cv.rect(bx + i * 14, 128, 8, 4 + i * 3, d)
    for _ in range(12):
        x = rng.choice((rng.randrange(4, MARGIN + 30), rng.randrange(W - MARGIN - 30, W - 6)))
        cv.rect(x, rng.randrange(100, 280), rng.randrange(2, 8), 2, d)
    polyomino(cv, 100, 244, [(0, 0), (0, 1), (1, 1), (1, 2)], 7, hx("#7A7268"), hx("#4C463E"))
    broken_sword(cv, W - 108, 264, hx("#EFE6D2"), hx("#302C28"))
    return cv


def bg_lattice_heart(area: str, rng: random.Random) -> Canvas:
    p = REGIONS["lattice_heart"]
    cv = Canvas(W, H)
    base_sky_ground(cv, p, horizon_bands=2, ground_bands=3)
    gold = hx(p["lattice"])
    gold_dim = mix(gold, hx(p["sky"][0]), 0.55)
    # the gold lattice (1 px, square nodes) over the sky band: ~25 % coverage, sparse
    for x in range(16, W, 32):
        for y in range(0, 90):
            if (y % 4) < 2:
                cv.put(x, y, gold_dim)
    for y in range(12, 90, 32):
        for x in range(0, W):
            if (x % 4) < 2:
                cv.put(x, y, gold_dim)
    for x in range(16, W, 32):
        for y in range(12, 90, 32):
            cv.rect(x - 1, y - 1, 3, 3, gold)
            cv.put(x, y, hx(p["sky"][0]))
    step_c, step_d, step_l = hx("#3A3848"), hx("#2C2A3A"), hx("#4A4858")
    for i, (x0, x1) in enumerate(((240, 560), (190, 610), (140, 660), (90, 710))):
        y = 62 + i * 8
        cv.rect(x0, y, x1 - x0, 8, step_c if i % 2 == 0 else step_d)
        cv.rect(x0, y, x1 - x0, 1, step_l)
    light, m, d = hx("#5E5C6E"), hx("#4A4858"), hx("#3A3848")
    for x in (150, 230, 310, W - 322, W - 242, W - 162):
        pillar(cv, x, 0, 12, 64, light, m, d)
    rubble_edge(cv, rng, 100, d, m, 30)
    finish_ground(cv, rng, p)
    for x in (44, W - 44):
        pillar(cv, x - 9, 40, 18, 260, light, m, d, cap=4)
    for x in range(100, W, 56):
        if MARGIN + 30 < x < W - MARGIN - 30:
            continue
        for y in range(110, 300):
            if (y % 4) < 2:
                cv.put(x, y, gold_dim)
    polyomino(cv, 100, 248, [(0, 0), (1, 0), (2, 0), (3, 0)], 7, hx("#4A4858"), hx("#2C2A3A"))
    _ = (area, rng)
    return cv


BACKDROPS = {
    "hellfire": bg_hellfire, "sands": bg_sands, "swamp": bg_swamp, "dungeon": bg_dungeon,
    "ice_tower": bg_ice_tower, "sky_isles": bg_sky_isles, "lattice_heart": bg_lattice_heart,
}


def near_strip(region: str, rng: random.Random) -> Canvas | None:
    c = REGIONS[region]["near"]
    if c is None:
        return None
    cv = Canvas(W, 48)
    col = hx(c)
    for _ in range(9):
        x, y = rng.randrange(-40, W), rng.randrange(6, 40)
        w, h = rng.randrange(80, 240), rng.randrange(3, 7)
        cv.rect(x, y, w, h, col)
        cv.dither(x - 10, y - 2, 10, h + 4, col, 0)
        cv.dither(x + w, y - 2, 10, h + 4, col, 1)
        cv.dither(x, y - 2, w, 2, col, 0)
        cv.dither(x, y + h, w, 2, col, 1)
    return cv


# ------------------------------------------------------------------------------------------- slabs & kit

FOREST = ROOT / "assets" / "art" / "env" / "forest"
FOREST_SLAB = {"stone": "#4C4D47", "light": "#6A6B62", "dark": "#3A3B37", "crack": "#3E3F3A", "lip": "#262521",
               "lip_top": "#5A5B54", "ink": "#1B1722", "moss": "#5E6B55", "moss_dark": "#4A5545"}


def nine_slice(p: dict) -> Canvas:
    light, stone, dark = (hx(c) for c in p["stone"])
    lip, lip_top, ink = hx(p["lip"]), hx(p["lip_top"]), hx(INK)
    cv = Canvas(16, 16, ink)
    cv.rect(0, 0, 14, 1, light)
    cv.rect(0, 1, 1, 11, light)
    cv.rect(1, 1, 13, 10, stone)
    cv.rect(14, 1, 1, 11, dark)
    cv.rect(1, 11, 14, 1, dark)
    cv.rect(1, 12, 13, 1, lip_top)
    cv.rect(0, 12, 1, 2, lip)
    cv.rect(14, 12, 1, 2, lip)
    cv.rect(0, 13, 15, 1, lip)
    cv.rect(1, 14, 13, 1, lip)
    return cv


def recolour(src: Path, mapping: dict) -> Canvas:
    """Colour-for-colour recolour (no pixel moved). Unknown colours map by nearest luminance in `mapping` keys."""
    w, h, rows = read_png(src)
    cv = Canvas(w, h)
    keys = {hx(k)[:3]: hx(v) for k, v in mapping.items()}
    for y, row in enumerate(rows):
        for x, px in enumerate(row):
            if px[3] == 0:
                continue
            k = px[:3]
            if k in keys:
                cv.put(x, y, keys[k])
            else:
                best = min(keys, key=lambda kk: abs(lum(kk) - lum(k)))
                cv.put(x, y, keys[best])
    return cv


def slab_mapping(p: dict) -> dict:
    light, stone, dark = p["stone"]
    cover, cover_dark = p["cover"]
    return {FOREST_SLAB["stone"]: stone, FOREST_SLAB["light"]: light, FOREST_SLAB["dark"]: dark,
            FOREST_SLAB["crack"]: p["crack"], FOREST_SLAB["lip"]: p["lip"], FOREST_SLAB["lip_top"]: p["lip_top"],
            FOREST_SLAB["ink"]: INK, FOREST_SLAB["moss"]: cover, FOREST_SLAB["moss_dark"]: cover_dark}


def is_cover(c) -> bool:
    r, g, b = c[:3]
    return g > r + 6 and g > b + 6


def kit_recolour(src: Path, p: dict) -> Canvas:
    """The forest support kit by luminance rank: stone pixels onto the region's 4-tone wall ramp, moss (green) pixels
    onto its 2-tone cover ramp; Ink stays Ink. No pixel is moved."""
    w, h, rows = read_png(src)
    stones = sorted({px[:3] for row in rows for px in row if px[3] and not is_cover(px) and px[:3] != hx(INK)[:3]}, key=lum)
    mosses = sorted({px[:3] for row in rows for px in row if px[3] and is_cover(px)}, key=lum)
    wall = [hx(c) for c in reversed(p["wall"])]        # dark -> light
    cov = [hx(c) for c in reversed(p["wall_cover"])]
    lo, hi = (lum(stones[0]), lum(stones[-1])) if stones else (0, 1)
    table = {}
    for c in stones:
        t = (lum(c) - lo) / max(hi - lo, 1)
        table[c] = mix(wall[min(len(wall) - 2, int(t * (len(wall) - 1)))], wall[min(len(wall) - 1, int(t * (len(wall) - 1)) + 1)], (t * (len(wall) - 1)) % 1.0)
    for i, c in enumerate(mosses):
        table[c] = cov[0] if i < len(mosses) // 2 else cov[1]
    cv = Canvas(w, h)
    for y, row in enumerate(rows):
        for x, px in enumerate(row):
            if px[3] == 0:
                continue
            cv.put(x, y, hx(INK) if px[:3] == hx(INK)[:3] else table[px[:3]])
    return cv


def region_json(region: str, p: dict, has_near: bool, kit: bool) -> dict:
    light, stone, dark = p["stone"]
    wall = p["wall"]
    cov = p["wall_cover"]
    areas_art = {
        "edge": {"backdrop": {"modulate": "#F4F2F6"}, "support": {"pillar_every": 200}},
        "inner": {},
        "sanctum": {"backdrop": {"modulate": "#CCC6D2"},
                    "half_tints": {"player": shade_hex(p["half"][0], 0.92), "enemy": shade_hex(p["half"][1], 0.92)},
                    "support": {"pillar_every": 90}},
    }
    data = {
        "id": region,
        "_doc": f"2026-11-12 World Map v2 region visuals, generated by tools/asset-pipeline/make_region_env.py (free, deterministic): {p['name']}. Backdrop composition per art bible §6.4 (far band 20 %, props only in the horizon band and the 80 px margins, bottom 36 % stepped), slabs = the forest 9-slice / stamps recoloured colour-for-colour to this region's ramp (no pixel moved), support kit = the forest wall / pillar / arch recoloured by luminance rank. A PixelLab painterly pass can replace bg_*_far_*.png one for one (same names) without touching this file.",
        "backdrop": {"far": f"bg_{region}_far_inner.png", "near_enabled": has_near,
                     "ground_shade": {"from_row": 300, "band": 10, "alphas": [0.12, 0.22, 0.34]}},
        "slab": {"nine_slice": f"env_slab_{region}_9slice.png", "stamps": f"env_slab_{region}_stamps.png",
                 "stamps_meta": f"env_slab_{region}_stamps.json"},
        "thorn_tile": f"env_thorn_{region}_tile16.png",
        "platform": {"deck": dark, "face": p["lip"], "face_top": p["lip_top"], "mortar": INK, "shadow": INK,
                     "shadow_alpha": 0.5, "divider": shade_hex(dark, 0.85)},
        "support": {"wall_height": 44, "course_height": 8, "block_widths": [16, 20, 14, 18, 22, 15],
                    "stone_top": wall[0], "stone": wall[1], "stone_dark": wall[2], "ground": wall[3],
                    "side": shade_hex(wall[2], 0.9), "moss": cov[0], "moss_dark": cov[1], "moss_every": 2,
                    "mist_alpha": 0.0, "foot_shadow": [0.55, 0.38, 0.22], "foot_band": 3, "crack_every": 4, "chip_every": 5,
                    "wall_bottom_shade": [0.25, 0.45], "wall_top_shade": [0.55, 0.3], "pillar_every": 120, "pillar_width": 22,
                    "fern_every": 0, "fern_sink": 8, "roots_inset": 10, "roots_rise": 2, "arch_margin": 4},
        "half_tints": {"player": p["half"][0], "enemy": p["half"][1]},
        "areas": {
            "_doc": "Floor progression inside the region: edge (first third of the map columns), inner, sanctum (the warden). Same rule shape as the forest (ArtAssets.area_for).",
            "rules": [{"id": "sanctum", "kinds": ["boss"]}, {"id": "edge", "until": 0.34}, {"id": "inner", "until": 1.0}],
            "art": areas_art,
        },
    }
    if has_near:
        data["backdrop"]["near"] = f"bg_{region}_near.png"
        data["backdrop"]["near_bottom_row"] = 84
    data["support"].update({"wall_tile": f"env_support_{region}_wall.png", "wall_modulate": "#C0C0C0"})
    if pillar_for(region, p) is not None:
        data["support"].update({"pillar": f"env_support_{region}_pillar.png", "pillar_modulate": "#C4C4C4"})
    else:
        data["support"]["pillar_every"] = 0
        data["areas"]["art"]["edge"]["support"]["pillar_every"] = 0
        data["areas"]["art"]["sanctum"]["support"]["pillar_every"] = 0
    if region == "sky_isles":
        data["support"].update({"foot_shadow": [], "wall_bottom_shade": [], "wall_top_shade": [0.4]})
    if region == "lattice_heart":
        del data["areas"]  # the final match is one node: no progression, no areas (region_areas_test's area-less fixture)
    if region == "swamp":
        data["support"].update({"roots": "env_support_swamp_roots.png", "ferns": "env_support_swamp_ferns.png", "fern_every": 120})
    dress = DRESS.get(region)
    if dress is not None:
        data["slab"].update({
            "flagstones": f"env_slab_{region}_flagstones.png",
            "flagstone_meta": {
                "_doc": "2026-11-12 arena surface integration: 16 procedural 64x64 flagstones of this region's own construction (tools/asset-pipeline/make_region_flagstones.py, deterministic, 0 gen; anatomy measured on the forest PixelLab sheet). Nine-cropped per cell like the forest's; plain tiles weigh most.",
                "size": 64, "count": 16, "border": 6, "weights": list(dress["weights"]),
            },
            "perimeter": dict(dress["perimeter"]),
            "_doc_perimeter": "2026-11-12: the ground reaching onto the cells along the board's outer edges (SlabPainter.paint_perimeter_cover, seeded; <= depth px, only on open sides).",
        })
        data["platform"].update({
            "face_tile": f"env_platform_{region}_face.png", "face_tile_modulate": "#E6E6E6",
            "_doc_face_tile": "2026-11-12 arena integration: the front face is a 12 px course cut from this region's own foundation strip, so lip and wall are one material (as the forest's lip is cut from its wall).",
            "rim_tile": f"env_platform_{region}_rim.png", "rim_rise": dress["rim_rise"], "rim_modulate": "#FFFFFF",
            "_doc_rim": "2026-11-12: the region's edge rim over the front faces (SlabPainter.paint_rim_strip), rising rim_rise px into the deck margin, never over a cell.",
        })
        if dress["joints"] is not None:
            data["platform"]["joints"] = dict(dress["joints"])
            data["platform"]["_doc_joints"] = "2026-11-12: seeded 1 px dashed lines in the joints between neighbouring cells (SlabPainter.joint_segments): what this region leaves in the cracks (bible §6.1)."
        data["support"].update({"foot_tile": f"env_support_{region}_foot.png", "foot_rise": dress["foot_rise"],
                                "foot_extend": dress["foot_extend"], "foot_modulate": "#FFFFFF",
                                "_doc_foot": "2026-11-12: the ground-contact strip at the foundation's foot (SupportLayer._draw_foot_strip): how this region's ground meets the wall."})
    _ = kit
    return data


def shade_hex(h: str, k: float) -> str:
    c = shade(hx(h), k)
    return "#%02X%02X%02X" % c[:3]



# ------------------------------------------------------------------------------- region-specific foundations
# 2026-11-12 (user: the six regions reused the forest support kit recoloured): every region gets its own foundation
# strip (231x44, repeated on an absolute x grid by SupportLayer) and, where its architecture has them, its own pillar
# (28x56). The silhouettes differ, not only the colours: basalt columns + veins, buried sandstone + sand drift, mud
# bank + sunken logs, dressed stone + iron bars, frosted blocks + icicles, and for the Sky Isles a tapered rock
# underside hanging over nothing (alpha 0 below the rock).

def _strip(p: dict) -> tuple[Canvas, list]:
    cv = Canvas(231, 44)
    ramp = [hx(c) for c in p["wall"]]   # light .. dark
    return cv, ramp


def strip_hellfire(p: dict) -> Canvas:
    cv, (l, m, d, g) = _strip(p)
    cv.rect(0, 0, 231, 44, g)
    ink, vein = hx(INK), hx(p["vein"])
    x = 0
    widths = [14, 11, 16, 12, 15, 13, 10, 17]
    i = 0
    while x < 231:
        w = widths[i % len(widths)]
        top = 0 if i % 3 else 2
        cv.rect(x, top, w, 44 - top, m)
        cv.rect(x, top, 2, 44 - top, l)
        cv.rect(x + w - 3, top, 3, 44 - top, d)
        cv.rect(x + w - 1, 0, 1, 44, ink)
        if i % 4 == 1:
            yy = 8 + (i * 7) % 20
            for k in range(10):
                cv.put(x + w - 1, yy + k, vein if k % 3 != 2 else ink)
        if i % 5 == 2:
            cv.rect(x + 2, 30 + (i % 3) * 3, w - 5, 1, ink)
        x += w
        i += 1
    cv.rect(0, 40, 231, 4, mix(g, hx(INK), 0.6))
    return cv


def strip_sands(p: dict) -> Canvas:
    cv, (l, m, d, g) = _strip(p)
    cv.rect(0, 0, 231, 44, m)
    ink = hx(INK)
    for row, y in enumerate(range(0, 44, 11)):
        off = (row % 2) * 13
        for x in range(-off, 231, 26):
            cv.rect(x, y, 25, 10, m)
            cv.rect(x, y, 25, 1, l)
            cv.rect(x, y + 9, 25, 1, d)
            cv.rect(x + 24, y, 1, 10, d)
            cv.rect(x + 3 + (row * 5) % 9, y + 4, 4, 1, d)
    # sand drift burying the lower half, a wavy top edge, a lighter crest
    sand, crest = hx("#C8B890"), hx("#D8CCA6")
    for x in range(231):
        h = 14 + int(6 * math.sin(x / 11.0)) + int(3 * math.sin(x / 4.3))
        cv.rect(x, 44 - h, 1, h, sand)
        cv.put(x, 44 - h, crest)
    for x in range(0, 231, 17):
        cv.rect(x + 3, 36 + (x % 5), 6, 1, hx("#B4A478"))
    _ = (ink, g)
    return cv


def strip_swamp(p: dict) -> Canvas:
    cv, (l, m, d, g) = _strip(p)
    cv.rect(0, 0, 231, 44, d)
    mud, mud_d, weed = hx("#3A382A"), hx("#2A2A20"), hx("#4E5A3C")
    cv.rect(0, 6, 231, 38, mud)
    for x in range(0, 231, 9):
        cv.rect(x, 6 + (x // 9) % 3, 5, 1, mud_d)
    # sunken logs and a few drowned stones
    log, log_l = hx("#3E3E30"), hx("#56564A")
    for x0, y0, ln in ((4, 12, 60), (90, 22, 48), (160, 9, 56), (120, 34, 40)):
        cv.rect(x0, y0, ln, 7, log)
        cv.rect(x0, y0, ln, 1, log_l)
        cv.rect(x0, y0 + 6, ln, 1, mud_d)
        for k in range(x0 + 6, x0 + ln, 12):
            cv.rect(k, y0 + 2, 1, 3, mud_d)
        cv.ellipse(x0 + ln, y0 + 3, 3, 3, log)
    for x0, y0 in ((70, 30), (200, 28), (30, 36)):
        cv.rect(x0, y0, 14, 6, m)
        cv.rect(x0, y0, 14, 1, l)
    for x in range(2, 231, 23):
        cv.rect(x, 4 + (x % 3), 7, 3, weed)
        cv.rect(x + 2, 7 + (x % 3), 3, 2, hx("#3C4630"))
    cv.rect(0, 0, 231, 2, g)
    return cv


def strip_dungeon(p: dict) -> Canvas:
    cv, (l, m, d, g) = _strip(p)
    cv.rect(0, 0, 231, 44, m)
    ink = hx(INK)
    for row, y in enumerate(range(0, 44, 8)):
        off = (row % 2) * 15
        for x in range(-off, 231, 30):
            cv.rect(x, y, 29, 7, m)
            cv.rect(x, y, 29, 1, l)
            cv.rect(x + 28, y, 1, 7, d)
            cv.rect(x, y + 7, 30, 1, ink)
    # a barred cell window and iron rings
    iron, rust = hx("#2E323B"), hx("#6E6252")
    for bx in (40, 150):
        cv.rect(bx, 8, 36, 26, hx("#1C2026"))
        cv.rect(bx - 1, 7, 38, 1, l)
        for k in range(bx + 4, bx + 36, 7):
            cv.rect(k, 8, 2, 26, iron)
            cv.put(k, 20, rust)
        cv.rect(bx, 20, 36, 2, iron)
    for rx in (12, 110, 215):
        cv.rect(rx, 12, 6, 1, iron)
        cv.rect(rx + 1, 13, 4, 5, iron)
        cv.rect(rx + 2, 15, 2, 2, m)
        cv.put(rx + 1, 17, rust)
    _ = g
    return cv


def strip_ice(p: dict) -> Canvas:
    cv, (l, m, d, g) = _strip(p)
    cv.rect(0, 0, 231, 44, m)
    frost, frost_d = hx("#A6ACC4"), hx("#8A90B0")
    for row, y in enumerate(range(0, 44, 10)):
        off = (row % 2) * 12
        for x in range(-off, 231, 24):
            cv.rect(x, y, 23, 9, m)
            cv.rect(x, y, 23, 1, l)
            cv.rect(x + 22, y, 1, 9, d)
            cv.rect(x, y + 9, 24, 1, d)
    # frost cap and icicles hanging from the top course, rime in the joints
    cv.rect(0, 0, 231, 3, frost)
    cv.rect(0, 3, 231, 1, frost_d)
    for x in range(3, 231, 9):
        h = 4 + (x * 7) % 9
        cv.poly([(x, 4), (x + 3, 4), (x + 1, 4 + h)], frost)
        cv.put(x + 1, 4 + h, frost_d)
    for x in range(0, 231, 24):
        cv.rect(x + 5, 20 + (x % 7), 1, 6, frost_d)
    cv.rect(0, 41, 231, 3, g)
    return cv


def strip_sky(p: dict) -> Canvas:
    """Rock underside tapering into nothing: the island's foot over the cloud (bible §6.3 'chân đá thon')."""
    cv, (l, m, d, g) = _strip(p)
    ink = hx(INK)
    x = 0
    i = 0
    widths = [22, 18, 26, 20, 24, 19]
    while x < 231:
        w = widths[i % len(widths)]
        depth = 24 + (i * 9) % 18
        tip = x + w // 2 + (i % 3) - 1
        cv.poly([(x, 0), (x + w, 0), (x + w - 2, 10), (tip + 3, depth), (tip, depth + 3), (tip - 3, depth - 2), (x + 1, 12)], m)
        cv.poly([(x, 0), (x + 3, 0), (x + 2, 10), (tip - 3, depth - 2), (tip - 5, depth - 6), (x + 1, 12)], l)
        cv.poly([(x + w - 5, 0), (x + w, 0), (x + w - 2, 10), (tip + 3, depth), (tip, depth + 3), (tip, depth - 4)], d)
        cv.rect(x, 0, w, 2, l)
        x += w
        i += 1
    _ = (g, ink)
    return cv


def pillar_for(region: str, p: dict) -> Canvas | None:
    """Own pillar silhouettes: hellfire chained column, sands worn drum column, dungeon square iron-banded pier,
    ice frosted pier with icicles. Swamp and Sky Isles have none."""
    if region not in ("hellfire", "sands", "dungeon", "ice_tower", "lattice_heart"):
        return None
    cv = Canvas(28, 56)
    l, m, d, g = (hx(c) for c in p["wall"])
    ink = hx(INK)
    if region == "hellfire":
        cv.rect(8, 2, 12, 54, m)
        cv.rect(8, 2, 3, 54, l)
        cv.rect(17, 2, 3, 54, d)
        cv.rect(6, 0, 16, 3, d)
        cv.rect(5, 52, 18, 4, g)
        for y in range(10, 50, 4):
            k = (y // 4) % 2
            cv.rect(7 + k * 2, y, 3, 2, ink)
            cv.rect(11 + k * 2, y, 3, 2, d)
            cv.rect(15 + k * 2, y, 3, 2, ink)
        vein = hx(p["vein"])
        for y in (20, 21, 23, 24):
            cv.put(19, y, vein)
    elif region == "sands":
        for y in range(4, 56, 8):
            cv.rect(7, y, 14, 7, m)
            cv.rect(7, y, 14, 1, l)
            cv.rect(7, y + 7, 14, 1, d)
            cv.rect(19, y, 2, 7, d)
        cv.rect(5, 0, 18, 4, l)
        cv.rect(5, 4, 18, 1, d)
        cv.ellipse(14, 54, 13, 4, hx("#C8B890"), top_only=True)
        cv.rect(12, 30, 3, 1, d)
    elif region == "dungeon":
        cv.rect(6, 0, 16, 56, m)
        cv.rect(6, 0, 3, 56, l)
        cv.rect(19, 0, 3, 56, d)
        cv.rect(4, 0, 20, 3, l)
        iron = hx("#2E323B")
        for y in (14, 38):
            cv.rect(5, y, 18, 3, iron)
            cv.put(8, y + 1, hx("#6E6252"))
            cv.put(19, y + 1, hx("#6E6252"))
        cv.rect(4, 52, 20, 4, d)
    elif region == "ice_tower":
        cv.rect(7, 0, 14, 56, m)
        cv.rect(7, 0, 3, 56, l)
        cv.rect(18, 0, 3, 56, d)
        frost = hx("#A6ACC4")
        cv.rect(5, 0, 18, 3, frost)
        for x, h in ((6, 6), (12, 9), (18, 5), (23, 7)):
            cv.poly([(x, 3), (x + 3, 3), (x + 1, 3 + h)], frost)
        cv.rect(5, 52, 18, 4, g)
    else:
        cv.rect(8, 0, 12, 56, m)
        cv.rect(8, 0, 2, 56, l)
        cv.rect(18, 0, 2, 56, d)
        cv.rect(6, 0, 16, 3, l)
        cv.rect(6, 53, 16, 3, d)
    return cv


STRIPS = {"hellfire": strip_hellfire, "sands": strip_sands, "swamp": strip_swamp, "dungeon": strip_dungeon,
          "ice_tower": strip_ice, "sky_isles": strip_sky, "lattice_heart": strip_dungeon}


# ------------------------------------------------------------------------------- arena dressing (2026-11-12)
# The arena is part of its region, not a board laid over it. Three strips per region, all outside the cells:
#   face  231x12  the platform's front face = a course cut from the region's OWN foundation strip (the forest did
#                 the same with its PixelLab wall, 0 gen), so lip and wall are one material;
#   rim   231xH   alpha strip over the face's top edge, rising <= 5 px into the deck margin: what the region leaves on
#                 the edge (sand lapping over, frost + icicles, scorched ash + embers, weed, rust dust + a chain, a
#                 wind-chipped lip);
#   foot  231xH   alpha strip at the foundation's foot, over the foot shadow: how the ground meets the wall (sand
#                 piled against it, stagnant water, ash heap with ember cracks, snow drift, rubble floor, and for the
#                 Sky Isles loose stones floating under the island).
# Joints: `platform.joints` = seeded 1 px dashed lines in the gaps between neighbouring cells (lava veins, rime,
# sand, weed), SlabPainter.joint_segments. Readability: 1 px, dashed, never a frame.

FACE_ROW = {"hellfire": 2, "sands": 0, "swamp": 6, "dungeon": 0, "ice_tower": 10, "sky_isles": 0, "lattice_heart": 0}


def face_from_wall(wall: Canvas, r0: int, light) -> Canvas:
    cv = Canvas(231, 12)
    for y in range(12):
        for x in range(231):
            cv.put(x, y, wall.get(x, min(r0 + y, wall.h - 1)))
    cv.rect(0, 0, 231, 1, light)
    return cv


def _specks(cv: Canvas, rng: random.Random, y0: int, y1: int, c, n: int, size: int = 2) -> None:
    for _ in range(n):
        cv.rect(rng.randrange(0, cv.w), rng.randrange(y0, y1), size, size // 2 + 1, c)


def rim_hellfire(p: dict) -> Canvas:
    cv = Canvas(231, 8)
    rng = random.Random(71)
    ash, scorch, ember, ember_d = hx("#5A5658"), hx("#241F22"), hx(p["vein"]), hx("#B8701A")
    # scorched patches biting the edge (rows 1..4), ash clumps on top, embers along the face top
    for x in range(0, 231, 29):
        w = 9 + (x // 29) % 7
        cv.rect(x + (x // 7) % 5, 2, w, 3, scorch)
        cv.rect(x + (x // 7) % 5 + 2, 1, w - 4, 1, scorch)
    _specks(cv, rng, 0, 3, ash, 26)
    for x in range(5, 231, 23):
        y = 3 + (x // 23) % 2
        cv.put(x, y, ember)
        cv.put(x + 1, y, ember_d)
        if x % 46 == 5:
            cv.put(x + 9, y + 1, ember_d)
    return cv


def rim_sands(p: dict) -> Canvas:
    cv = Canvas(231, 9)
    sand, crest, sand_d = hx("#C8B890"), hx("#D8CCA6"), hx("#B4A478")
    # sand lapping over the edge from one side: lumps heavy at their left, thinning to the right (bible §6.1)
    for x0, w in ((0, 46), (64, 30), (118, 52), (190, 41)):
        for x in range(x0, min(231, x0 + w)):
            t = (x - x0) / float(w)
            h = int(round(6 * (1 - t) ** 1.4 + 2 * math.sin(x / 3.1) * (1 - t))) + 1
            cv.rect(x, 0, 1, h, sand)
            cv.put(x, 0 if h > 1 else 0, crest)
            if h > 3 and x % 5 == 0:
                cv.put(x, h - 1, sand_d)
    # thin grains over the face top everywhere
    for x in range(2, 231, 6):
        cv.put(x, 3 + (x // 6) % 3, sand_d)
    return cv


def rim_swamp(p: dict) -> Canvas:
    cv = Canvas(231, 8)
    weed, weed_d, wet = hx("#4E5A3C"), hx("#3C4630"), hx("#2A2A20")
    cv.rect(0, 3, 231, 1, wet)              # the wet line where the slab meets the damp lip
    for x in range(0, 231, 19):
        w = 6 + (x // 19) % 5
        cv.rect(x + (x // 3) % 4, 1, w, 2, weed)
        cv.rect(x + (x // 3) % 4 + 1, 3, w - 2, 1, weed_d)
        cv.rect(x + (x // 3) % 4 + 2, 4, 1, 2 + (x // 19) % 3, weed_d)   # a strand draping over the face
    return cv


def rim_dungeon(p: dict) -> Canvas:
    cv = Canvas(231, 7)
    rng = random.Random(23)
    dust, iron, rust = hx("#6E6252"), hx("#2E323B"), hx("#6E6252")
    _specks(cv, rng, 0, 3, hx("#4E4438"), 14, 2)
    # two rusted chain lengths lying along the edge (bible §6.1 "xích gỉ ở lề")
    for x0, ln in ((22, 40), (140, 52)):
        for k in range(x0, x0 + ln, 5):
            cv.rect(k, 2, 4, 2, iron)
            cv.put(k + 1, 2, rust if (k // 5) % 3 == 0 else iron)
            cv.put(k + 2, 3, hx(INK))
    _ = dust
    return cv


def rim_ice(p: dict) -> Canvas:
    cv = Canvas(231, 12)
    frost, frost_d, rime = hx("#C4C8DC"), hx("#A6ACC4"), hx("#8A90B0")
    for x in range(231):
        h = 2 + ((x * 7) % 3)
        cv.rect(x, 1, 1, h, frost)
        cv.put(x, 1 + h, frost_d)
    # icicles hanging from the lip over the face, irregular lengths
    for x in range(2, 231, 9):
        h = 3 + (x * 5) % 7
        cv.poly([(x, 4), (x + 3, 4), (x + 1, 4 + h)], frost_d)
        cv.put(x + 1, 4 + h, rime)
        cv.put(x + 1, 5, frost)
    return cv


def rim_sky(p: dict) -> Canvas:
    cv = Canvas(231, 6)
    rng = random.Random(9)
    chip, dust = hx("#302C28"), hx("#8A8478")
    for x in range(7, 231, 31):
        cv.rect(x, 2, 3, 2, chip)
        cv.rect(x + 1, 1, 1, 1, chip)
    _specks(cv, rng, 0, 2, dust, 10, 2)
    return cv


def foot_hellfire(p: dict) -> Canvas:
    cv = Canvas(231, 14)
    rng = random.Random(5)
    ash_d, ash, ember = hx("#2A2628"), hx("#4A4446"), hx("#B8701A")
    for x in range(231):
        h = 5 + int(3 * math.sin(x / 9.0)) + int(2 * math.sin(x / 3.7))
        cv.rect(x, 14 - h, 1, h, ash_d)
        cv.put(x, 14 - h, ash)
    _specks(cv, rng, 7, 13, ash, 18)
    for x0 in (18, 96, 170):
        for k in range(14):
            cv.put(x0 + k + (k // 3) % 2, 10 + (k // 5), ember if k % 4 != 3 else hx(INK))
    return cv


def foot_sands(p: dict) -> Canvas:
    cv = Canvas(231, 16)
    sand, crest, sand_d, block = hx("#C8B890"), hx("#D8CCA6"), hx("#B4A478"), hx("#9A8C70")
    for x in range(231):
        h = 7 + int(4 * math.sin(x / 13.0)) + int(2 * math.sin(x / 5.3))
        cv.rect(x, 16 - h, 1, h, sand)
        cv.put(x, 16 - h, crest)
    for x in range(3, 231, 11):
        cv.rect(x, 12 + (x % 3), 4, 1, sand_d)
    for x0 in (40, 160):            # half-buried blocks of the square the sand swallowed
        cv.rect(x0, 6, 16, 7, block)
        cv.rect(x0, 6, 16, 1, hx("#B4A68C"))
        cv.rect(x0, 11, 16, 2, sand)
    return cv


def foot_swamp(p: dict) -> Canvas:
    cv = Canvas(231, 14)
    water, ripple, refl, lily = hx("#2E3428"), hx("#4A5444"), hx("#56564A"), hx("#6A5868")
    cv.rect(0, 3, 231, 11, water)
    cv.rect(0, 3, 231, 1, hx("#262A20"))
    for x in range(0, 231, 37):
        cv.rect(x + 4, 6 + (x // 37) % 3, 14 + (x // 37) % 9, 1, ripple)
        cv.rect(x + 9, 9 + (x // 37) % 2, 8, 1, ripple)
    for x in range(6, 231, 23):
        cv.rect(x, 11, 5, 1, refl)
    for x0 in (58, 190):
        cv.rect(x0, 5, 6, 2, lily)
        cv.rect(x0 + 1, 4, 3, 1, hx("#8E8296"))
    return cv


def foot_dungeon(p: dict) -> Canvas:
    cv = Canvas(231, 10)
    flag, flag_d, ink = hx("#30343C"), hx("#2C2826"), hx(INK)
    cv.rect(0, 2, 231, 8, flag)
    for x in range(-7, 231, 26):
        cv.rect(x, 2, 1, 8, ink)
        cv.rect(x + 1, 2, 24, 1, hx("#3E4450"))
    cv.rect(0, 5, 231, 1, ink)
    for x in range(13, 231, 26):
        cv.rect(x, 6, 1, 4, ink)
    for x0 in (30, 128, 205):        # rubble fallen from the vault
        cv.rect(x0, 0, 5, 3, flag_d)
        cv.rect(x0, 0, 5, 1, hx("#484C58"))
    return cv


def foot_ice(p: dict) -> Canvas:
    cv = Canvas(231, 12)
    snow, snow_d = hx("#C4C8DC"), hx("#A6ACC4")
    for x in range(231):
        h = 5 + int(3 * math.sin(x / 15.0)) + int(1.5 * math.sin(x / 4.0))
        cv.rect(x, 12 - h, 1, h, snow)
        cv.put(x, 12 - h, hx("#D8DCEC"))
        if x % 7 == 3:
            cv.put(x, 11, snow_d)
    cv.rect(0, 10, 231, 2, snow_d)
    return cv


def foot_sky(p: dict) -> Canvas:
    """Loose stones torn from the island, floating under it (alpha everywhere else; foot_rise < 0 leaves a gap)."""
    cv = Canvas(231, 22)
    l, m, d = (hx(c) for c in p["stone"])
    for x0, y0, w, h in ((14, 4, 8, 5), (70, 12, 5, 3), (112, 2, 10, 6), (168, 14, 6, 4), (205, 7, 4, 3)):
        cv.rect(x0, y0, w, h, m)
        cv.rect(x0, y0, w, 1, l)
        cv.rect(x0, y0 + h - 1, w, 1, d)
        cv.rect(x0 + w - 1, y0, 1, h, d)
    return cv


DRESS = {
    "hellfire": {"rim": rim_hellfire, "rim_rise": 3, "foot": foot_hellfire, "foot_rise": 2, "foot_extend": 6,
                 "joints": {"color": "#FFB21F", "dark": "#1B1722", "chance": 0.3},
                 "weights": [5, 3, 2, 1, 3, 2, 2, 1, 4, 2, 1, 2, 1, 2, 2, 4],
                 "perimeter": {"kind": "drift", "color": "#4A4446", "light": "#5A5658", "dark": "#241F22", "depth": 4, "chance": 0.45}},
    "sands": {"rim": rim_sands, "rim_rise": 4, "foot": foot_sands, "foot_rise": 3, "foot_extend": 12,
              "joints": {"color": "#C8B890", "dark": "#B4A478", "chance": 0.5},
              "weights": [5, 2, 2, 1, 4, 2, 2, 2, 1, 2, 2, 1, 4, 2, 2, 2],
              "perimeter": {"kind": "drift", "color": "#C8B890", "light": "#D8CCA6", "dark": "#B4A478", "depth": 6, "chance": 0.8, "sides": ["left", "bottom", "top"]}},
    "swamp": {"rim": rim_swamp, "rim_rise": 3, "foot": foot_swamp, "foot_rise": 3, "foot_extend": 16,
              "joints": {"color": "#4E5A3C", "dark": "#2A2A20", "chance": 0.4},
              "weights": [5, 2, 1, 2, 2, 1, 2, 2, 2, 2, 1, 1, 2, 2, 2, 2],
              "perimeter": {"kind": "clump", "color": "#4E5A3C", "light": "#5E6B55", "dark": "#3C4630", "depth": 5, "chance": 0.6}},
    "dungeon": {"rim": rim_dungeon, "rim_rise": 2, "foot": foot_dungeon, "foot_rise": 2, "foot_extend": 4,
                "joints": {"color": "#6E6252", "dark": "#1B1722", "chance": 0.12},
                "weights": [4, 3, 2, 2, 4, 2, 3, 2, 4, 2, 2, 2, 2, 2, 2, 2],
                "perimeter": {"kind": "drift", "color": "#3E4450", "light": "#484C58", "dark": "#24272E", "depth": 3, "chance": 0.3}},
    "ice_tower": {"rim": rim_ice, "rim_rise": 4, "foot": foot_ice, "foot_rise": 2, "foot_extend": 8,
                  "joints": {"color": "#A6ACC4", "dark": "#8A90B0", "chance": 0.45},
                  "weights": [5, 2, 2, 2, 4, 2, 1, 2, 1, 2, 2, 2, 4, 2, 1, 1],
                  "perimeter": {"kind": "rime", "color": "#A6ACC4", "light": "#C4C8DC", "dark": "#8A90B0", "depth": 4, "chance": 0.7}},
    "sky_isles": {"rim": rim_sky, "rim_rise": 2, "foot": foot_sky, "foot_rise": -6, "foot_extend": 10, "joints": None,
                  "weights": [5, 2, 1, 2, 2, 1, 2, 2, 1, 2, 2, 1, 4, 2, 1, 2],
                  "perimeter": {"kind": "drift", "color": "#6E665C", "light": "#8A8478", "dark": "#4C463E", "depth": 2, "chance": 0.25}},
}


def install_generated(region: str, src: Path, out_root: Path) -> str:
    """A PixelLab 792x336 backdrop -> bg_<region>_far_inner.png 800x360 (edge columns repeated x4, 24 px Ink at the
    bottom, exactly like the forest edge / sanctum backdrops), quantized to <= 40 colours."""
    w, h, rows = read_png(src)
    # Some generations come with a near-black letterbox frame: find the first / last rows and columns that are not
    # almost entirely black and extend from them (pixel art is never stretched).
    def dark_row(y: int) -> bool:
        return sum(1 for px in rows[y] if lum(px) < 14) > w * 0.95
    def dark_col(x: int) -> bool:
        return sum(1 for y in range(h) if lum(rows[y][x]) < 14) > h * 0.95
    y0 = 0
    while y0 < h - 1 and dark_row(y0):
        y0 += 1
    y1 = h - 1
    while y1 > y0 and dark_row(y1):
        y1 -= 1
    x0 = 0
    while x0 < w - 1 and dark_col(x0):
        x0 += 1
    x1 = w - 1
    while x1 > x0 and dark_col(x1):
        x1 -= 1
    cv = Canvas(W, H, hx(INK))
    for y in range(h):
        sy = min(max(y, y0), y1)
        row = rows[sy]
        for x in range(W):
            sx = min(max(x - 4, x0), x1)
            px = row[sx]
            cv.put(x, y, (px[0], px[1], px[2], 255))
    quantize(cv, 40)
    out = out_root / region / f"bg_{region}_far_inner.png"
    cv.save(out)
    return f"{out.name} {cv.w}x{cv.h} {cv.colours()} colours (from {src.name})"


# -------------------------------------------------------------------------------------------- main

def quantize(cv: Canvas, limit: int) -> None:
    """Art bible §8.4: a backdrop uses <= 40 colours. Keeps the `limit` most used colours, snaps the rest to the
    nearest kept one (the rare mixes of the stepped shades)."""
    counts: dict[bytes, int] = {}
    for i in range(0, len(cv.buf), 4):
        k = bytes(cv.buf[i:i + 4])
        counts[k] = counts.get(k, 0) + 1
    if len(counts) <= limit:
        return
    keep = [k for k, _ in sorted(counts.items(), key=lambda kv: -kv[1])[:limit]]
    table: dict[bytes, bytes] = {k: k for k in keep}
    for k in counts:
        if k not in table:
            table[k] = min(keep, key=lambda q: (q[0] - k[0]) ** 2 + (q[1] - k[1]) ** 2 + (q[2] - k[2]) ** 2)
    for i in range(0, len(cv.buf), 4):
        cv.buf[i:i + 4] = table[bytes(cv.buf[i:i + 4])]


def build(region: str, out_root: Path, backdrops: bool = True) -> list[str]:
    p = REGIONS[region]
    out = out_root / region
    out.mkdir(parents=True, exist_ok=True)
    written: list[str] = []
    for i, area in enumerate(AREAS if backdrops else ()):
        rng = random.Random(hash((region, area)) & 0xFFFF if False else (sum(map(ord, region)) * 31 + i))
        cv = BACKDROPS[region](area, rng)
        quantize(cv, 40)
        n = cv.colours()
        path = out / f"bg_{region}_far_{area}.png"
        cv.save(path)
        written.append(f"{path.name} {cv.w}x{cv.h} {n} colours")
    near = None  # 2026-11-12 in-game check: the scripted strip read as a checker stripe; the generated far carries its fog
    if near is not None:
        near.save(out / f"bg_{region}_near.png")
        written.append(f"bg_{region}_near.png 800x48 {near.colours()} colours")
    nine_slice(p).save(out / f"env_slab_{region}_9slice.png")
    stamps = recolour(FOREST / "env_slab_forest_stamps.png", slab_mapping(p))
    stamps.save(out / f"env_slab_{region}_stamps.png")
    meta = json.loads((FOREST / "env_slab_forest_stamps.json").read_text(encoding="utf-8"))
    meta["version"] = f"{region} 2026-11-12 (forest v2 sheet recoloured)"
    meta["palette"] = {"stone": p["stone"][1], "light_edge": p["stone"][0], "dark_edge": p["stone"][2], "crack": p["crack"],
                       "lip": p["lip"], "lip_top": p["lip_top"], "ink": INK, "cover": p["cover"][0], "cover_dark": p["cover"][1]}
    if region in ("sky_isles", "lattice_heart"):
        meta["rules"]["cover_chance"] = 0.12   # wind-worn / bare: almost no cover (bible §6.1)
    if region == "hellfire":
        meta["rules"]["crack_chance"] = 0.5     # floor cracked into cells, cracks are the veins' beds
    (out / f"env_slab_{region}_stamps.json").write_text(json.dumps(meta, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    t_light, t_mid, t_dark = p["thorn"]
    recolour(FOREST / "env_thorn_forest_tile16_v2.png", {"#A89C82": t_light, "#6E6452": t_mid, "#3A3328": t_dark, INK: INK}).save(out / f"env_thorn_{region}_tile16.png")
    wall_strip = STRIPS[region](p)
    wall_strip.save(out / f"env_support_{region}_wall.png")
    dress = DRESS.get(region)
    if dress is not None:
        face_from_wall(wall_strip, FACE_ROW[region], hx(p["lip_top"])).save(out / f"env_platform_{region}_face.png")
        dress["rim"](p).save(out / f"env_platform_{region}_rim.png")
        dress["foot"](p).save(out / f"env_support_{region}_foot.png")
        written += [f"env_platform_{region}_face.png 231x12", f"env_platform_{region}_rim.png", f"env_support_{region}_foot.png"]
    pil = pillar_for(region, p)
    if pil is not None:
        pil.save(out / f"env_support_{region}_pillar.png")
    for stale in ("arch", "pillar" if pil is None else ""):
        if stale and (out / f"env_support_{region}_{stale}.png").exists():
            (out / f"env_support_{region}_{stale}.png").unlink()
            imp = out / f"env_support_{region}_{stale}.png.import"
            if imp.exists():
                imp.unlink()
    if region == "swamp":
        for piece in ("roots", "ferns"):
            kit_recolour(FOREST / f"env_support_forest_{piece}.png", p).save(out / f"env_support_{region}_{piece}.png")
    (out / "region.json").write_text(json.dumps(region_json(region, p, near is not None, True), indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    written.append("region.json")
    return written


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--only", default="", help="comma-separated region ids (default: all)")
    ap.add_argument("--out", default=str(ROOT / "assets" / "art" / "env"))
    ap.add_argument("--install", action="append", default=[], help="region=<792x336 png>: pad a generated backdrop into the bundle")
    ap.add_argument("--no-backdrops", action="store_true", help="keep the bg_*_far_*.png files on disk (slabs / strips / json only)")
    args = ap.parse_args(argv)
    ids = [s for s in args.only.split(",") if s] or list(REGIONS)
    for region in ids:
        for line in build(region, Path(args.out), backdrops=not args.no_backdrops):
            print(f"{region}: {line}")
    for spec in args.install:
        region, _, path = spec.partition("=")
        print(f"{region}: {install_generated(region, Path(path), Path(args.out))}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
