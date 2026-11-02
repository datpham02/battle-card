"""Generates the ancient UI plate textures (2026-11-02, user reference sheet of the button system).

Pixel art drawn by code, deterministic (seeded noise), into assets/art/ui/plates/:
  plate_<look>_up.png / plate_<look>_down.png  for look in gold, navy, wine, grey
      a 48x34 art-px nine-slice source (margins left 8, top 8, right 8, bottom 10): 4 px cut corners, a 1 px ink
      outline, a 2 px gold rim shaded per pixel (light top-left, dark bottom-right), a 1 px ink gap, a 1 px thin
      inner gold line with corner ticks, a speckled fill with a light first row; "up" has a 2 px lip under the
      plate (raised), "down" is the pressed plate moved down onto where the lip was.
  gem.png  an 11x11 faceted blue diamond in a gold socket.
UiButtons draws the plates with PixelFrame.draw_nine_tiled at the menus' whole-number scale (2 at 720p).

Run: python -X utf8 -I tools/asset-pipeline/make_ui_plates.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from export_sheets import encode_png  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art" / "ui" / "plates"

W, H = 48, 32
LIP = 2
CUT = 4


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


INK = hexc("1B1722")
RIM_LIGHT = hexc("F6D98A")
RIM = hexc("D9A23E")
RIM_DARK = hexc("9A6420")
INNER_GOLD = hexc("B0832F")
GREY_RIM_LIGHT = hexc("9A99A4")
GREY_RIM = hexc("6A6974")
GREY_RIM_DARK = hexc("4A4952")
GREY_INNER = hexc("55545E")
LIP_GOLD = hexc("5E3C12")
LIP_GREY = hexc("26252C")

# fill base, speckle dark, speckle light, top highlight row
FILLS = {
    "gold": (hexc("E8B04A"), hexc("DCA442"), hexc("EFBC56"), hexc("F8D884")),
    "navy": (hexc("262A44"), hexc("1F2238"), hexc("30355A"), hexc("3A4068")),
    "wine": (hexc("5C2430"), hexc("4A1C27"), hexc("6C2C3A"), hexc("7E3A48")),
    "grey": (hexc("34333C"), hexc("2C2B33"), hexc("3C3B45"), hexc("45444F")),
}


def rng(seed):
    state = [seed & 0xFFFFFFFF]

    def nxt():
        state[0] = (state[0] * 1664525 + 1013904223) & 0xFFFFFFFF
        return state[0] / 4294967296.0
    return nxt


def inside(x, y, w, h, inset):
    """True when (x, y) lies inside the plate shrunk by inset px (corners cut by CUT - inset, at least 1 when inset < CUT)."""
    if x < inset or y < inset or x >= w - inset or y >= h - inset:
        return False
    c = max(CUT - inset, 0)
    lx, ty, rx, by = x - inset, y - inset, (w - 1 - inset) - x, (h - 1 - inset) - y
    return not ((lx + ty < c) or (rx + ty < c) or (lx + by < c) or (rx + by < c))


def plate(look, pressed):
    base, dark, light, top = FILLS[look]
    grey = look == "grey"
    rim_l, rim_m, rim_d, inner = (GREY_RIM_LIGHT, GREY_RIM, GREY_RIM_DARK, GREY_INNER) if grey else (RIM_LIGHT, RIM, RIM_DARK, INNER_GOLD)
    lip = LIP_GREY if grey else LIP_GOLD
    rand = rng({"gold": 11, "navy": 23, "wine": 37, "grey": 41}[look])
    total_h = H + LIP
    px = [[(0, 0, 0, 0)] * W for _ in range(total_h)]
    oy = LIP if pressed else 0
    if not pressed:
        for y in range(H):
            for x in range(W):
                if inside(x, y, W, H, 0):
                    px[y + LIP][x] = lip
    for y in range(H):
        for x in range(W):
            if not inside(x, y, W, H, 0):
                continue
            if not inside(x, y, W, H, 1):
                c = INK
            elif not inside(x, y, W, H, 3):
                # rim: light on the top / left faces, dark on the bottom / right faces
                d_top, d_left, d_bot, d_right = y, x, H - 1 - y, W - 1 - x
                if min(d_top, d_left) <= min(d_bot, d_right):
                    c = rim_l if min(d_top, d_left) <= 1 else rim_m
                else:
                    c = rim_d if min(d_bot, d_right) <= 1 else rim_m
            elif not inside(x, y, W, H, 4):
                c = INK
            elif not inside(x, y, W, H, 5):
                c = inner
            else:
                r = rand()
                c = dark if r < 0.16 else (light if r < 0.26 else base)
                if not inside(x, y - 1, W, H, 5):
                    c = top
            px[y + oy][x] = c
    # corner ticks: short gold strokes just inside the inner line at each corner
    for (cx, cy, sx, sy) in ((6, 6, 1, 1), (W - 7, 6, -1, 1), (6, H - 7, 1, -1), (W - 7, H - 7, -1, -1)):
        for k in range(2):
            px[cy + oy][cx + sx * k] = rim_m
            px[cy + sy * k + oy][cx] = rim_m
    return px


def gem():
    n = 11
    c = n // 2
    socket_ink, socket_gold = INK, RIM
    g_dark, g_mid, g_light, g_spark = hexc("2F5FA8"), hexc("5E9BE8"), hexc("A8CCF4"), hexc("EAF4FF")
    px = [[(0, 0, 0, 0)] * n for _ in range(n)]
    for y in range(n):
        for x in range(n):
            d = abs(x - c) + abs(y - c)
            if d > c:
                continue
            if d == c:
                px[y][x] = socket_ink
            elif d == c - 1:
                px[y][x] = socket_gold
            elif d == c - 2:
                px[y][x] = socket_ink
            else:
                upper_left = (x - c) + (y - c) < 0
                px[y][x] = g_light if upper_left else (g_dark if (x - c) + (y - c) > 1 else g_mid)
    px[c - 1][c - 1] = g_spark
    return px


def save(name, px):
    rows = [b"".join(bytes(p) for p in row) for row in px]
    (OUT / name).write_bytes(encode_png(len(px[0]), len(px), rows))
    print("wrote", (OUT / name).relative_to(ROOT).as_posix(), "%dx%d" % (len(px[0]), len(px)))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for look in FILLS:
        save("plate_%s_up.png" % look, plate(look, False))
        save("plate_%s_down.png" % look, plate(look, True))
    save("gem.png", gem())


if __name__ == "__main__":
    main()
