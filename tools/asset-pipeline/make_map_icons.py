"""Generates the map screen's pixel art (2026-11-02, user reference: diamond route nodes with pixel icons).

Deterministic, drawn by code into assets/art/ui/map/:
  node_plate.png           40x40  diamond plate: ink outline, gold rim shaded per pixel (light upper-left, dark
                                  lower-right), ink gap, speckled navy fill, gold pips at the four tips.
  node_plate_selected.png  48x48  the same, larger, with a bright rim and a second thin gold ring.
  node_plate_boss.png      48x48  the warden's plate: double gold rim and extra pips.
  icon_<kind>.png          20x20  battle, danger, treasure, rest, miniboss, boss, shop, event: shapes rasterised
                                  on the pixel grid, then an ink outline and a light top / dark bottom shade.
  check.png                11x9   green check mark with an ink outline.
  stat_<deck|blocks|gold|removal>.png 16x16, gear.png 20x20, pennant.png 24x34 (the HUD bar's hero banner with a
                                  gold 2x2 tessera emblem).
ChapterMapView draws them at the menus' whole-number scale (2 at 720p).

Run: python -X utf8 -I tools/asset-pipeline/make_map_icons.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from export_sheets import encode_png  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art" / "ui" / "map"


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (255,)


INK = hexc("1B1722")
GOLD_L, GOLD, GOLD_D = hexc("F6D98A"), hexc("D9A23E"), hexc("9A6420")
NAVY, NAVY_D, NAVY_L = hexc("262A44"), hexc("1F2238"), hexc("30355A")
CLEAR = (0, 0, 0, 0)

# icon colours
SILVER = hexc("C8CDD8")
STEEL = hexc("8A93A6")
BROWN = hexc("7A5230")
BROWN_L = hexc("9A6A3E")
ORANGE = hexc("F08A4B")
FLAME = hexc("FFB070")
YELLOW = hexc("FFD45C")
IVORY = hexc("EFE6D2")
GREEN = hexc("58D468")
GREEN_D = hexc("2F8A4A")
SHOP_GREEN = hexc("6FD39A")
BLUE = hexc("86A8F2")
PURPLE = hexc("C495E0")
PARCH = hexc("E8D8B0")


def rng(seed):
    state = [seed & 0xFFFFFFFF]

    def nxt():
        state[0] = (state[0] * 1664525 + 1013904223) & 0xFFFFFFFF
        return state[0] / 4294967296.0
    return nxt


class Grid:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[None] * w for _ in range(h)]

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, c)

    def line(self, x0, y0, x1, y1, width, c):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            x = round(x0 + (x1 - x0) * i / n)
            y = round(y0 + (y1 - y0) * i / n)
            for dy in range(width):
                for dx in range(width):
                    self.set(x + dx, y + dy, c)

    def poly(self, pts, c):
        for y in range(self.h):
            for x in range(self.w):
                if _inside(pts, x + 0.5, y + 0.5):
                    self.set(x, y, c)

    def finish(self):
        """Light top edge, dark bottom edge on every coloured pixel, then a 1 px ink outline around the shape."""
        out = [[None] * self.w for _ in range(self.h)]
        for y in range(self.h):
            for x in range(self.w):
                c = self.px[y][x]
                if c is None or c == INK:
                    out[y][x] = c
                    continue
                up = self.px[y - 1][x] if y > 0 else None
                down = self.px[y + 1][x] if y < self.h - 1 else None
                if up is None or up == INK or up != c:
                    out[y][x] = shade(c, 1.18) if up is None or up == INK else c
                elif down is None or down == INK:
                    out[y][x] = shade(c, 0.78)
                else:
                    out[y][x] = c
        for y in range(self.h):
            for x in range(self.w):
                if out[y][x] is not None:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and self.px[ny][nx] not in (None, INK):
                        out[y][x] = INK
                        break
        self.px = out
        return self

    def rows(self):
        return [b"".join(bytes(c if c is not None else CLEAR) for c in row) for row in self.px]


def _inside(pts, x, y):
    inside = False
    n = len(pts)
    for i in range(n):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % n]
        if (y1 > y) != (y2 > y):
            xc = x1 + (y - y1) * (x2 - x1) / (y2 - y1)
            if x < xc:
                inside = not inside
    return inside


def save(name, w, h, rows):
    (OUT / name).write_bytes(encode_png(w, h, rows))
    print("wrote", (OUT / name).relative_to(ROOT).as_posix(), "%dx%d" % (w, h))


# --- plates --------------------------------------------------------------------------------------------------------

def plate(size, r, rim_light, rim, rim_dark, seed, ring=False, boss=False):
    c = (size - 1) / 2.0
    rand = rng(seed)
    px = [[CLEAR] * size for _ in range(size)]
    for y in range(size):
        for x in range(size):
            d = abs(x - c) + abs(y - c)
            if d > r:
                continue
            if d > r - 1:
                col = INK
            elif d > r - 4:
                col = rim_light if (x - c) + (y - c) < -1 else (rim_dark if (x - c) + (y - c) > 1 else rim)
                if boss and r - 2.5 < d <= r - 1.5:
                    col = INK
            elif d > r - 5:
                col = INK
            elif ring and r - 7 < d <= r - 6:
                col = rim
            else:
                v = rand()
                col = NAVY_D if v < 0.16 else (NAVY_L if v < 0.26 else NAVY)
            px[y][x] = col
    # gold pips just inside the four tips
    tips = [(c, c - r + 1), (c + r - 1, c), (c, c + r - 1), (c - r + 1, c)]
    for (tx, ty) in tips:
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                if abs(dx) + abs(dy) <= 1:
                    x, y = int(round(tx + dx - 0.5 if tx % 1 else tx + dx)), int(round(ty + dy - 0.5 if ty % 1 else ty + dy))
                    if 0 <= x < size and 0 <= y < size:
                        px[y][x] = GOLD_L if dx + dy < 0 else GOLD
    if boss:
        # extra pips half-way along each edge
        for (sx, sy) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            mx, my = int(round(c + sx * (r - 2) / 2)), int(round(c + sy * (r - 2) / 2))
            for dy in range(-1, 2):
                for dx in range(-1, 2):
                    if abs(dx) + abs(dy) <= 1:
                        px[my + dy][mx + dx] = GOLD_L
    return [b"".join(bytes(p) for p in row) for row in px]


# --- icons ---------------------------------------------------------------------------------------------------------

def icon_battle():
    g = Grid(20, 20)
    # two long blades crossing in the middle; guards, grips and pommels at the lower corners
    for (tx, ty), (bx, by), (gx0, gy0), (gx1, gy1), (hx, hy), (px_, py_) in (
        ((2, 1), (13, 12), (11, 15), (15, 11), (15, 14), (17, 16)),
        ((16, 1), (5, 12), (7, 15), (3, 11), (3, 14), (1, 16)),
    ):
        g.line(tx, ty, bx, by, 2, SILVER)
        g.line(gx0, gy0, gx1, gy1, 1, YELLOW)
        g.line(gx0 + (1 if gx1 > gx0 else -1), gy0, gx1, gy1 + 1, 1, YELLOW)
        g.line(bx + (1 if hx > bx else -1), by + 1, hx, hy, 2, BROWN_L)
        g.rect(px_, py_, 2, 2, YELLOW)
    return g.finish()


def icon_danger():
    g = Grid(20, 20)
    g.poly([(10, 1.5), (18.5, 17.5), (1.5, 17.5)], ORANGE)
    g.rect(9, 6, 2, 6, INK)
    g.rect(9, 13, 2, 2, INK)
    return g.finish()


def icon_treasure():
    g = Grid(20, 20)
    g.poly([(3, 9), (17, 9), (17, 16), (3, 16)], BROWN)
    g.poly([(4, 4), (16, 4), (17, 9), (3, 9)], BROWN_L)
    for x in (5, 13):
        g.rect(x, 4, 2, 12, YELLOW)
    g.rect(3, 9, 14, 1, INK)
    g.rect(9, 8, 2, 4, YELLOW)
    return g.finish()


def icon_rest():
    g = Grid(20, 20)
    g.poly([(10, 1), (16.5, 10), (14, 17.5), (6, 17.5), (3.5, 10)], ORANGE)
    g.poly([(10, 7), (13, 12), (11.5, 17.5), (8.5, 17.5), (7, 12)], YELLOW)
    return g.finish()


def icon_miniboss():
    g = Grid(20, 20)
    g.poly([(4, 7), (6, 3), (14, 3), (16, 7), (16, 11), (13, 13), (13, 17), (7, 17), (7, 13), (4, 11)], IVORY)
    g.rect(6, 8, 3, 3, INK)
    g.rect(11, 8, 3, 3, INK)
    g.rect(9, 12, 2, 1, INK)
    for x in (8, 10, 12):
        g.rect(x, 15, 1, 2, INK)
    for p in ((7, 9), (12, 9)):
        g.set(p[0], p[1], PURPLE)
    return g.finish()


def icon_boss():
    g = Grid(20, 20)
    g.poly([(2, 7), (6, 11), (10, 3), (14, 11), (18, 7), (17, 16), (3, 16)], YELLOW)
    g.rect(3, 13, 14, 3, GOLD_D)
    for x in (5, 9, 13):
        g.rect(x, 13, 2, 2, BLUE)
    g.rect(9, 7, 2, 2, IVORY)
    return g.finish()


def icon_shop():
    g = Grid(20, 20)
    g.poly([(6, 6), (14, 6), (17, 11), (16, 17), (4, 17), (3, 11)], SHOP_GREEN)
    g.rect(7, 4, 6, 2, GREEN_D)
    g.line(7, 3, 5, 1, 1, GREEN_D)
    g.line(12, 3, 14, 1, 1, GREEN_D)
    g.poly([(10, 9), (13, 10.5), (13, 14.5), (10, 16), (7, 14.5), (7, 10.5)], YELLOW)
    g.rect(9, 12, 2, 2, GOLD_D)
    return g.finish()


def icon_event():
    g = Grid(20, 20)
    g.rect(5, 4, 10, 13, PARCH)
    g.rect(3, 2, 14, 3, BROWN_L)
    g.rect(3, 16, 14, 3, BROWN_L)
    for (x, y) in ((8, 7), (9, 6), (10, 6), (11, 7), (11, 8), (10, 9), (9, 10), (9, 11), (9, 13)):
        g.rect(x, y, 1, 1, INK)
    for (x, y) in ((8, 8), (10, 10)):
        g.rect(x, y, 1, 1, BLUE)
    return g.finish()


def stat_deck():
    g = Grid(16, 16)
    g.poly([(2, 4), (9, 2), (11, 12), (4, 14)], STEEL)
    g.rect(6, 3, 8, 11, IVORY)
    g.rect(8, 6, 4, 4, BLUE)
    return g.finish()


def stat_blocks():
    g = Grid(16, 16)
    for (x, y) in ((2, 2), (2, 7), (7, 7)):
        g.rect(x, y, 5, 5, BLUE)
    for (x, y) in ((2, 2), (2, 7), (7, 7)):
        g.rect(x + 4, y, 1, 5, INK)
        g.rect(x, y + 4, 5, 1, INK)
    return g.finish()


def stat_gold():
    g = Grid(16, 16)
    g.poly([(8, 1), (14, 4.5), (14, 11.5), (8, 15), (2, 11.5), (2, 4.5)], YELLOW)
    g.rect(6, 6, 4, 4, GOLD_D)
    return g.finish()


def stat_removal():
    g = Grid(16, 16)
    g.rect(4, 2, 9, 12, IVORY)
    g.line(3, 3, 12, 13, 2, ORANGE)
    return g.finish()


def gear():
    import math
    g = Grid(20, 20)
    c = 9.5
    body = [(c + math.cos(-math.pi / 2 + k * math.pi / 4 + math.pi / 8) * 6.6, c + math.sin(-math.pi / 2 + k * math.pi / 4 + math.pi / 8) * 6.6) for k in range(8)]
    g.poly(body, YELLOW)
    for k in range(8):
        a = -math.pi / 2 + k * math.pi / 4
        tx, ty = c + math.cos(a) * 7.6, c + math.sin(a) * 7.6
        g.rect(int(round(tx - 1.5)), int(round(ty - 1.5)), 3, 3, YELLOW)
    g.rect(8, 8, 4, 4, INK)
    return g.finish()


def pennant():
    w, h = 24, 34
    px = [[CLEAR] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            # cloth: a rectangle whose bottom is cut into a V
            notch = max(0, (h - 1 - y) - (abs(x - (w - 1) / 2.0) * 0.6))
            if y >= h - 8 and (h - 1 - y) < 8 - abs(x - (w - 1) / 2.0) * 0.6:
                continue
            col = INK if x in (0, w - 1) or y == 0 else (GOLD if x in (1, w - 2) or y == 1 else NAVY)
            px[y][x] = col
    # gold outline along the V
    for y in range(h - 9, h):
        for x in range(w):
            if px[y][x] != CLEAR and (y + 1 >= h or px[y + 1][x] == CLEAR):
                px[y][x] = INK
                if y - 1 >= 0 and px[y - 1][x] == NAVY:
                    px[y - 1][x] = GOLD
    # emblem: a 2x2 tessera block
    for (bx, by) in ((7, 8), (12, 8), (7, 13), (12, 13)):
        for yy in range(by, by + 4):
            for xx in range(bx, bx + 4):
                px[yy][xx] = GOLD_L if (yy == by or xx == bx) else GOLD
    # a pole cap
    for x in range(w):
        px[0][x] = GOLD_D if 0 < x < w - 1 else INK
    return [b"".join(bytes(p) for p in row) for row in px]


def check():
    g = Grid(11, 9)
    g.line(1, 4, 3, 6, 2, GREEN)
    g.line(4, 6, 8, 1, 2, GREEN)
    return g.finish()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    save("node_plate.png", 40, 40, plate(40, 19.5, GOLD_L, GOLD, GOLD_D, 51))
    save("node_plate_selected.png", 48, 48, plate(48, 23.5, hexc("FFF0B0"), GOLD_L, GOLD, 53, ring=True))
    save("node_plate_boss.png", 48, 48, plate(48, 23.5, GOLD_L, GOLD, GOLD_D, 57, ring=True, boss=True))
    for name, fn in (("battle", icon_battle), ("danger", icon_danger), ("treasure", icon_treasure), ("rest", icon_rest),
                     ("miniboss", icon_miniboss), ("boss", icon_boss), ("shop", icon_shop), ("event", icon_event)):
        g = fn()
        save("icon_%s.png" % name, g.w, g.h, g.rows())
    g = check()
    save("check.png", g.w, g.h, g.rows())
    for name, fn in (("stat_deck", stat_deck), ("stat_blocks", stat_blocks), ("stat_gold", stat_gold), ("stat_removal", stat_removal),
                     ("gear", gear)):
        g = fn()
        save("%s.png" % name, g.w, g.h, g.rows())
    save("pennant.png", 24, 34, pennant())


if __name__ == "__main__":
    main()
