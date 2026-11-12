"""Procedural flagstone sheets per region (2026-11-12, arena surface integration; free, deterministic).

One 256x256 sheet of 16 tiles 64x64 per region, consumed by the existing `slab.flagstones` hook (SlabPainter.paint_flagstone
nine-crops a tile into the cell: the 6 px border is kept, the middle windowed / repeated, never stretched). The tile anatomy
copies the forest's PixelLab sheet, measured 2026-11-12: 1 px Ink frame, 3 px light edge top / left, 2 px dark edge bottom /
right, a flat face, <= 12 colours, no dither, no outline inside the face (bible 6.2). What differs per region is the
CONSTRUCTION and the DETAIL, not the colour of one drawing:

  hellfire   obsidian / basalt slabs split by angular cracks, scorched ash patches, a few molten cracks (Ink + ember pixels)
  sands      sandstone with strata, eroded rounded corners, sand drifted into one corner, square-in-square worn patterns
  swamp      damp stone with mud stains, puddles with a light rim, moss clumps in corners, a root crossing some tiles
  dungeon    heavy masonry: tiles split into 1x2 / 2x1 / 2x2 dressed blocks with darkened joints, worn edges, cracks
  ice_tower  frozen stone under an ice layer: pale cracks in the ice, frost on the edges, snow in a corner, a reflection streak
  sky_isles  wind-worn island rock: horizontal erosion streaks, pits, a chipped edge, a faint lattice line on a few tiles
  forest     (kept: the approved PixelLab sheet)

Usage: python -X utf8 -I tools/asset-pipeline/make_region_flagstones.py [--only a,b] [--out assets/art/env]
Also importable: `sheet(region) -> Canvas`, `WEIGHTS[region]`.
"""
from __future__ import annotations

import argparse
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_region_env import Canvas, REGIONS, INK, hx, mix, shade  # noqa: E402

T = 64
INK_C = hx(INK)


class Pal:
    def __init__(self, p: dict, **extra):
        self.light, self.face, self.dark = (hx(c) for c in p["stone"])
        self.crack = hx(p["crack"])
        self.cover, self.cover_dark = (hx(c) for c in p["cover"])
        self.lip = hx(p["lip"])
        for k, v in extra.items():
            setattr(self, k, hx(v) if isinstance(v, str) else v)


def frame(cv: Canvas, pal: Pal, face=None) -> None:
    """The shared anatomy: Ink frame, 3 px light top/left, 2 px dark bottom/right, flat face."""
    cv.rect(0, 0, T, T, INK_C)
    cv.rect(1, 1, T - 2, T - 2, face or pal.face)
    cv.rect(1, 1, T - 2, 3, pal.light)
    cv.rect(1, 1, 3, T - 2, pal.light)
    cv.rect(1, T - 3, T - 2, 2, pal.dark)
    cv.rect(T - 3, 1, 2, T - 2, pal.dark)
    cv.put(T - 3, 1, pal.light)


def crack(cv: Canvas, rng: random.Random, x: int, y: int, length: int, c, shadow=None, dx: int = 1, dy: int = 1) -> None:
    """A 1 px stepped crack (bible 6.2): one step per pixel, random turns, with a 1 px shadow below-right."""
    for _ in range(length):
        if 4 <= x < T - 4 and 4 <= y < T - 4:
            cv.put(x, y, c)
            if shadow is not None:
                cv.put(x + 1, y + 1, shadow) if rng.random() < 0.5 else None
        r = rng.random()
        if r < 0.45:
            x += dx
        elif r < 0.9:
            y += dy
        else:
            x += dx
            y += dy


def branch_crack(cv: Canvas, rng: random.Random, c, shadow=None) -> None:
    x, y = rng.randrange(8, 40), rng.randrange(8, 40)
    crack(cv, rng, x, y, rng.randrange(14, 30), c, shadow, 1, 1)
    crack(cv, rng, x, y, rng.randrange(8, 18), c, shadow, -1, 1)
    if rng.random() < 0.5:
        crack(cv, rng, x, y, rng.randrange(6, 14), c, shadow, 1, -1)


def blob(cv: Canvas, rng: random.Random, cx: int, cy: int, rx: int, ry: int, c, c2=None) -> None:
    """A low organic clump: an ellipse eaten at the rim (no straight edge, no outline)."""
    for y in range(-ry, ry + 1):
        k = 1 - (y * y) / float(ry * ry) if ry else 1
        if k < 0:
            continue
        half = int(rx * math.sqrt(k)) - rng.randrange(0, 3)
        if half <= 0:
            continue
        x0 = cx - half + rng.randrange(0, 2)
        cv.rect(max(4, x0), cy + y, min(T - 4, cx + half) - max(4, x0), 1, c)
    if c2 is not None:
        for _ in range(max(2, rx)):
            cv.put(cx + rng.randrange(-rx, rx + 1), cy + rng.randrange(-ry, ry + 1), c2)


def corner_chip(cv: Canvas, rng: random.Random, pal: Pal, corner: int, size: int = 6) -> None:
    """A rounded eroded corner: the frame bitten by Ink in a quarter-ellipse."""
    cx, cy = (1, 1) if corner == 0 else (T - 2, 1) if corner == 1 else (1, T - 2) if corner == 2 else (T - 2, T - 2)
    sx, sy = (1 if cx == 1 else -1), (1 if cy == 1 else -1)
    for y in range(size):
        w = int(round(math.sqrt(max(size * size - (size - y) ** 2, 0))))
        w = size - w
        for x in range(w):
            cv.put(cx + sx * x, cy + sy * y, INK_C)
        cv.put(cx + sx * w, cy + sy * y, pal.dark if sx < 0 or sy < 0 else pal.light)


def speckles(cv: Canvas, rng: random.Random, c, n: int) -> None:
    for _ in range(n):
        x, y = rng.randrange(6, T - 7), rng.randrange(6, T - 7)
        cv.rect(x, y, 2, 1, c)
        if rng.random() < 0.4:
            cv.put(x, y + 1, c)


def square_in_square(cv: Canvas, pal: Pal, cx: int, cy: int, n: int, step: int, c, c2) -> None:
    for i in range(n):
        s = step * (i + 1)
        cv.rect(cx - s, cy - s, 2 * s + 1, 1, c)
        cv.rect(cx - s, cy + s, 2 * s + 1, 1, c2)
        cv.rect(cx - s, cy - s, 1, 2 * s + 1, c)
        cv.rect(cx + s, cy - s, 1, 2 * s + 1, c2)


# ---------------------------------------------------------------------------------------------------------- regions

def tile_hellfire(cv: Canvas, rng: random.Random, i: int, pal: Pal) -> None:
    frame(cv, pal)
    ash, scorch, ember, ember_d = pal.ash, pal.scorch, pal.ember, pal.ember_d
    # basalt: the face split into 2-3 angular plates by Ink cracks with a light fold on one side
    if i % 4 != 0:
        x = rng.randrange(18, 46)
        y = 4
        while y < T - 4:
            cv.put(x, y, INK_C)
            cv.put(x - 1, y, pal.dark)
            cv.put(x + 1, y, pal.light if i % 2 else pal.dark)
            y += 1
            if rng.random() < 0.35:
                x += rng.choice((-1, 1))
                x = min(max(x, 8), T - 9)
        if i % 3 == 1:
            yy = rng.randrange(18, 46)
            for xx in range(4, x):
                cv.put(xx, yy, INK_C)
                cv.put(xx, yy + 1, pal.dark)
                yy += rng.choice((0, 0, 1, -1))
    if i in (2, 6, 9, 13):          # scorched patches: a dark rim, ash inside (the surface burnt, not a hole)
        cx, cy = rng.randrange(16, 48), rng.randrange(16, 48)
        blob(cv, rng, cx, cy, rng.randrange(10, 15), rng.randrange(6, 9), scorch, None)
        blob(cv, rng, cx, cy, rng.randrange(7, 11), rng.randrange(4, 6), ash, pal.light)
    if i in (3, 10):                # a molten crack: Ink stepped line with ember pixels (bible 6.3 exception, kept short)
        x0, y0 = rng.randrange(10, 30), rng.randrange(10, 30)
        for k in range(rng.randrange(14, 24)):
            cv.put(x0, y0, INK_C)
            cv.put(x0 + 1, y0, ember if k % 3 != 2 else ember_d)
            if rng.random() < 0.5:
                x0 += 1
            else:
                y0 += 1
    if i in (5, 11, 14):
        speckles(cv, rng, ash, 6)
    if i == 7:
        corner_chip(cv, rng, pal, 3, 7)
    if i == 12:
        corner_chip(cv, rng, pal, 1, 5)


def tile_sands(cv: Canvas, rng: random.Random, i: int, pal: Pal) -> None:
    frame(cv, pal)
    sand, crest, sand_d = pal.sand, pal.crest, pal.sand_d
    # strata: 2-3 faint horizontal bands one tone off
    for k in range(rng.randrange(1, 4)):
        y = rng.randrange(8, 56)
        cv.rect(4 + rng.randrange(0, 10), y, 40 + rng.randrange(0, 16), 1, pal.strata)
    if i % 3 == 0:                  # eroded corners
        corner_chip(cv, rng, pal, rng.randrange(0, 4), rng.randrange(5, 9))
    if i in (1, 5, 9, 13):          # sand drifted into the bottom-right corner (one side, bible 6.1)
        for y in range(0, 20):
            w = int(22 * math.sqrt(max(1 - (y / 20.0) ** 1.6, 0))) + rng.randrange(-2, 2) + int(2 * math.sin(y / 1.7))
            if w > 0:
                cv.rect(T - 4 - w, T - 4 - y, w, 1, sand)
                cv.put(T - 4 - w, T - 4 - y, crest)
        for _ in range(5):
            cv.put(T - 6 - rng.randrange(0, 16), T - 6 - rng.randrange(0, 12), sand_d)
    if i in (3, 11):                # worn square-in-square (the only cultural pattern, bible 6.5)
        square_in_square(cv, pal, 32, 32, 3, 6, pal.dark, pal.light)
        for _ in range(10):         # worn away in places
            cv.put(32 + rng.randrange(-18, 19), 32 + rng.randrange(-18, 19), pal.face)
    if i in (6, 14):
        branch_crack(cv, rng, pal.crack, None)
    if i in (2, 7, 10, 15):
        speckles(cv, rng, sand_d, 5)
    if i == 8:
        blob(cv, rng, 14, 50, 9, 4, sand, crest)


def tile_swamp(cv: Canvas, rng: random.Random, i: int, pal: Pal) -> None:
    frame(cv, pal)
    mud, mud_d, water, water_l, root, root_l = pal.mud, pal.mud_d, pal.water, pal.water_l, pal.root, pal.root_l
    if i in (1, 4, 6, 9, 12, 14):   # damp stains: wide low blobs, darker, no green
        blob(cv, rng, rng.randrange(16, 48), rng.randrange(16, 48), rng.randrange(10, 18), rng.randrange(4, 8), mud, mud_d)
    if i in (2, 10):                # a puddle: dark water with one light rim line (reflection), no outline
        cx, cy = rng.randrange(20, 44), rng.randrange(20, 44)
        rx, ry = rng.randrange(8, 13), rng.randrange(4, 7)
        cv.ellipse(cx, cy, rx, ry, water)
        cv.rect(cx - rx // 2, cy - ry + 1, rx, 1, water_l)
    if i in (3, 7, 13):             # moss only in a corner (<= 25 % of the face), cover colour
        c = rng.randrange(0, 4)
        cx, cy = (10 if c % 2 == 0 else 54), (10 if c < 2 else 54)
        blob(cv, rng, cx, cy, 13, 9, pal.cover, pal.cover_dark)
    if i in (5, 11):                # a root crossing the tile: 3 px bark with a light top, stepped
        x, y = 4, rng.randrange(14, 50)
        while x < T - 4:
            cv.rect(x, y, 2, 3, root)
            cv.rect(x, y, 2, 1, root_l)
            x += 2
            y += rng.choice((0, 0, 1, -1))
    if i in (8, 15):
        branch_crack(cv, rng, pal.crack, mud_d)
    if i == 0:
        speckles(cv, rng, mud_d, 4)


def tile_dungeon(cv: Canvas, rng: random.Random, i: int, pal: Pal) -> None:
    frame(cv, pal)
    joint = pal.joint
    # masonry: split the tile into dressed blocks with a darkened joint, each block with its own light / dark edge
    kind = i % 4
    splits = {0: [], 1: [("v", 32)], 2: [("h", 32)], 3: [("v", 32), ("h", 32)]}[kind]
    if i >= 12:
        splits = [("v", 22 + (i % 2) * 20)]
    for axis, at in splits:
        if axis == "v":
            cv.rect(at, 1, 2, T - 2, joint)
            cv.rect(at - 2, 1, 2, T - 2, pal.dark)
            cv.rect(at + 2, 1, 3, T - 2, pal.light)
        else:
            cv.rect(1, at, T - 2, 2, joint)
            cv.rect(1, at - 2, T - 2, 2, pal.dark)
            cv.rect(1, at + 2, T - 2, 3, pal.light)
    cv.rect(1, 1, T - 2, 3, pal.light)
    cv.rect(1, 1, 3, T - 2, pal.light)
    if i in (2, 7, 11):
        branch_crack(cv, rng, INK_C, pal.dark)
    if i in (5, 9, 14):
        corner_chip(cv, rng, pal, rng.randrange(0, 4), rng.randrange(4, 7))
    if i in (3, 10, 15):            # rust dust at a block corner (bible 6.1 "bụi đá, xích gỉ")
        blob(cv, rng, rng.randrange(10, 54), rng.randrange(10, 54), 5, 3, pal.cover, pal.cover_dark)
    if i in (1, 6, 13):
        speckles(cv, rng, pal.dark, 5)


def tile_ice(cv: Canvas, rng: random.Random, i: int, pal: Pal) -> None:
    frame(cv, pal)
    ice, ice_l, frost, snow, snow_d = pal.ice, pal.ice_l, pal.frost, pal.snow, pal.snow_d
    # the ice layer: a slightly paler sheet over the stone leaving the frame, cracked with light lines
    cv.rect(5, 5, T - 10, T - 10, ice)
    for _ in range(rng.randrange(1, 3)):
        x, y = rng.randrange(8, 40), rng.randrange(8, 40)
        crack(cv, rng, x, y, rng.randrange(12, 28), ice_l, None, 1, 1)
        if rng.random() < 0.6:
            crack(cv, rng, x, y, rng.randrange(8, 16), ice_l, None, -1, 1)
    if i in (1, 5, 9, 13):          # frost on the top / left edge
        cv.rect(4, 4, T - 8, 2, frost)
        cv.rect(4, 4, 2, T - 8, frost)
        for x in range(5, T - 6, 3):
            cv.rect(x, 6, 2, rng.randrange(0, 4), frost)
        for y in range(5, T - 6, 3):
            cv.rect(6, y, rng.randrange(0, 4), 2, frost)
    if i in (2, 10, 14):            # snow in a corner, with its shadow
        cx, cy = (rng.choice((12, 52)), rng.choice((12, 52)))
        blob(cv, rng, cx, cy + 2, 13, 4, snow_d, None)
        blob(cv, rng, cx, cy, 12, 4, snow, None)
    if i in (3, 7, 11):             # one reflection streak (the ice catching the light)
        x, y = rng.randrange(10, 36), rng.randrange(10, 50)
        cv.rect(x, y, rng.randrange(8, 18), 1, ice_l)
        cv.rect(x + 2, y + 1, 4, 1, ice_l)
    if i in (6, 15):
        branch_crack(cv, rng, INK_C, pal.dark)
    if i == 8:
        corner_chip(cv, rng, pal, 3, 6)


def tile_sky(cv: Canvas, rng: random.Random, i: int, pal: Pal) -> None:
    frame(cv, pal)
    streak, pit, pit_l, lattice = pal.streak, pal.pit, pal.pit_l, pal.lattice
    # wind erosion: broken horizontal streaks one tone lighter, biased to the right
    for _ in range(rng.randrange(2, 5)):
        y = rng.randrange(8, 56)
        x = rng.randrange(6, 30)
        while x < T - 6:
            ln = rng.randrange(3, 9)
            cv.rect(x, y, min(ln, T - 6 - x), 1, streak)
            x += ln + rng.randrange(2, 6)
    if i in (1, 4, 7, 10, 13):      # erosion pits: small dark hollows with a light lower rim
        for _ in range(rng.randrange(1, 3)):
            x, y = rng.randrange(10, 50), rng.randrange(10, 50)
            cv.rect(x, y, 3 + rng.randrange(0, 3), 2, pit)
            cv.rect(x + 1, y + 2, 2 + rng.randrange(0, 2), 1, pit_l)
    if i in (2, 8, 14):             # a chipped, wind-worn edge
        corner_chip(cv, rng, pal, rng.randrange(0, 4), rng.randrange(6, 10))
    if i in (5, 11):                # a faint line of the exposed Lattice (bible 6.5: 1 px, one step of colour, no glow)
        y = rng.randrange(14, 50)
        for x in range(4, T - 4):
            if (x // 6) % 2 == 0:
                cv.put(x, y, lattice)
        cv.rect(rng.randrange(10, 50), y - 1, 3, 3, lattice)
    if i in (3, 9, 15):
        branch_crack(cv, rng, pal.crack, None)
    if i == 6:
        speckles(cv, rng, pal.dark, 4)


TILES = {"hellfire": tile_hellfire, "sands": tile_sands, "swamp": tile_swamp, "dungeon": tile_dungeon,
         "ice_tower": tile_ice, "sky_isles": tile_sky}

EXTRA = {
    "hellfire": dict(ash="#5A5658", scorch="#241F22", ember="#FFB21F", ember_d="#B8701A"),
    "sands": dict(sand="#C8B890", crest="#D8CCA6", sand_d="#B4A478", strata="#A89A7C"),
    "swamp": dict(mud="#46443A", mud_d="#36352A", water="#2E3428", water_l="#6A7064", root="#3E3E30", root_l="#56564A"),
    "dungeon": dict(joint="#1B1722"),
    "ice_tower": dict(ice="#5C627C", ice_l="#8A90B0", frost="#A6ACC4", snow="#B4B8CC", snow_d="#7E84A0"),
    "sky_isles": dict(streak="#6E665C", pit="#3E3A34", pit_l="#8A8478", lattice="#8C7E48"),
}

# plain tiles more often (the forest's own rule): index 0 and the least detailed ones carry weight 5
WEIGHTS = {
    "hellfire": [5, 3, 2, 1, 3, 2, 2, 1, 4, 2, 1, 2, 1, 2, 2, 4],
    "sands": [5, 2, 2, 1, 4, 2, 2, 2, 1, 2, 2, 1, 4, 2, 2, 2],
    "swamp": [5, 2, 1, 2, 2, 1, 2, 2, 2, 2, 1, 1, 2, 2, 2, 2],
    "dungeon": [4, 3, 2, 2, 4, 2, 3, 2, 4, 2, 2, 2, 2, 2, 2, 2],
    "ice_tower": [5, 2, 2, 2, 4, 2, 1, 2, 1, 2, 2, 2, 4, 2, 1, 1],
    "sky_isles": [5, 2, 1, 2, 2, 1, 2, 2, 1, 2, 2, 1, 4, 2, 1, 2],
}


def sheet(region: str) -> Canvas:
    pal = Pal(REGIONS[region], **EXTRA[region])
    out = Canvas(T * 4, T * 4)
    for i in range(16):
        rng = random.Random(1000 + i * 7919 + sum(map(ord, region)))
        cv = Canvas(T, T)
        TILES[region](cv, rng, i, pal)
        out.blit(cv, (i % 4) * T, (i // 4) * T)
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--out", default=str(Path(__file__).resolve().parents[2] / "assets" / "art" / "env"))
    a = ap.parse_args(argv)
    ids = [s for s in a.only.split(",") if s] or list(TILES)
    for r in ids:
        cv = sheet(r)
        p = Path(a.out) / r / f"env_slab_{r}_flagstones.png"
        cv.save(p)
        print(f"{r}: {p.name} {cv.w}x{cv.h} {cv.colours()} colours")
    return 0


if __name__ == "__main__":
    sys.exit(main())
