"""Status overlays drawn on the unit (art bible §5.4 "không vẽ khung", §4 status colours):
ASSET-017 Burning, ASSET-018 Frozen, ASSET-019 Fragile, ASSET-020 Chill. Script, no AI.

usage: draw_status.py OUT_DIR
  ASSET-017-fx_burn_<W>x48.png     2 frames side by side (1 px gutter): three stepped flame columns of
                                   2x2 squares rising from the feet, heights swap between frames;
                                   #FF7A1F body, #FFB21F tips. Sizes 32x48 (monsters) and 40x48 (heroes)
  ASSET-018-fx_frozen_<W>x48.png   square ice shell #A6EEFF 2 px around the body box, 1 px notched
                                   corners, #FFFFFF light line top-left, three 2x3 icicles under the top edge
  ASSET-019-fx_fragile_<W>x48.png  three stepped 1 px Ink cracks across the body with an Ivory pixel
                                   beside each crack pixel ("nứt Mực trên Ngà")
  ASSET-020-fx_chill_8.png         8x8 plus-shaped snowflake #3A5CF0 with #A6EEFF tips; the stack count is
                                   text drawn by code beside it; code bobs it 1 px
  + ASSET-017-020-status.json (frames, holds, anchors) and x4 previews on a mid background.
"""
import json, sys
sys.path.insert(0, __file__.rsplit('\\', 1)[0].rsplit('/', 1)[0])
from crop_frame import write_png

def c(h, a=255): return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), a)
T = (0, 0, 0, 0)
INK, IVORY = c('#1B1722'), c('#EFE6D2')
BURN, BURN_TIP = c('#FF7A1F'), c('#FFB21F')
ICE, ICE_HI, CHILL = c('#A6EEFF'), c('#FFFFFF'), c('#3A5CF0')

def blank(w, h): return [[T] * w for _ in range(h)]
def rect(img, x0, y0, x1, y1, col):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= y < len(img) and 0 <= x < len(img[0]):
                img[y][x] = col
def blit(dst, src, ox, oy):
    for y, row in enumerate(src):
        for x, p in enumerate(row):
            if p[3]:
                dst[oy + y][ox + x] = p

# body box per canvas width (where the sprite's body sits: bottom-centre anchored, feet on row 47)
BODY = {32: (8, 14, 23, 47), 40: (10, 10, 29, 47)}   # x0, y0, x1, y1

def burn(W, heights):
    img = blank(W, 48)
    cx = W // 2
    for i, h in enumerate(heights):
        x = cx - 9 + i * 7
        for k in range(h):                      # stacked 2x2 squares, top one is the tip
            y = 46 - k * 2 - 1
            col = BURN_TIP if k == h - 1 else BURN
            rect(img, x, y, x + 1, y + 1, col)
        # a 1 px ember beside the base of each flame
        img[46][x + 3] = BURN
    return img

def frozen(W):
    img = blank(W, 48)
    x0, y0, x1, y1 = BODY[W]
    x0, y0, x1, y1 = x0 - 2, y0 - 2, x1 + 2, y1
    for t in range(2):                            # 2 px shell
        rect(img, x0 + t, y0 + t, x1 - t, y0 + t, ICE); rect(img, x0 + t, y1 - t, x1 - t, y1 - t, ICE)
        rect(img, x0 + t, y0 + t, x0 + t, y1 - t, ICE); rect(img, x1 - t, y0 + t, x1 - t, y1 - t, ICE)
    for (x, y) in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):   # notched corners
        img[y][x] = T
    rect(img, x0 + 1, y0 + 1, x1 - 2, y0 + 1, ICE_HI); rect(img, x0 + 1, y0 + 1, x0 + 1, y1 - 2, ICE_HI)
    for ix in (x0 + 5, (x0 + x1) // 2, x1 - 6):   # icicles 2x3 hanging from the top edge
        rect(img, ix, y0 + 2, ix + 1, y0 + 4, ICE)
        img[y0 + 5][ix] = ICE
    return img

def fragile(W):
    img = blank(W, 48)
    x0, y0, x1, y1 = BODY[W]
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    paths = [
        [(cx - 6, cy - 10), (cx - 5, cy - 9), (cx - 4, cy - 8), (cx - 4, cy - 7), (cx - 3, cy - 6), (cx - 2, cy - 5), (cx - 2, cy - 4), (cx - 1, cy - 3)],
        [(cx + 1, cy - 2), (cx + 2, cy - 1), (cx + 3, cy), (cx + 3, cy + 1), (cx + 4, cy + 2), (cx + 5, cy + 3), (cx + 5, cy + 4), (cx + 6, cy + 5)],
        [(cx - 1, cy + 6), (cx - 2, cy + 7), (cx - 3, cy + 8), (cx - 3, cy + 9), (cx - 4, cy + 10)],
    ]
    for path in paths:
        for (x, y) in path:
            if 0 <= y < 48 and 0 <= x < W:
                img[y][x] = INK
                if x + 1 < W and img[y][x + 1][3] == 0:
                    img[y][x + 1] = IVORY
    return img

def chill():
    img = blank(8, 8)
    rect(img, 3, 0, 4, 7, CHILL); rect(img, 0, 3, 7, 4, CHILL)
    for (x, y) in ((1, 1), (6, 1), (1, 6), (6, 6)):
        img[y][x] = ICE_HI
    img[0][3] = ICE; img[3][0] = ICE
    return img

out = sys.argv[1]
meta = {"anchor": "same canvas as the unit frame, bottom-centre; draw at the unit's position",
        "burn": {"frames": 2, "hold_ms": 150, "sizes": [32, 40]},
        "frozen": {"frames": 1, "sizes": [32, 40], "code": "shell static; optional cool modulate on the unit"},
        "fragile": {"frames": 1, "sizes": [32, 40], "code": "static; the unit's palette may lean to Ivory via unit_fx"},
        "chill": {"frames": 1, "size": 8, "code": "drawn 2 px above the head, bobs 1 px every 300 ms; stack count text beside it"}}
previews = []
for W in (32, 40):
    a, b = burn(W, (4, 6, 3)), burn(W, (6, 4, 5))
    sheet = blank(W * 2 + 1, 48); blit(sheet, a, 0, 0); blit(sheet, b, W + 1, 0)
    write_png(f'{out}/ASSET-017-fx_burn_{W}x48.png', W * 2 + 1, 48, sheet); previews.append((f'burn-{W}', sheet, W * 2 + 1, 48))
    fz = frozen(W); write_png(f'{out}/ASSET-018-fx_frozen_{W}x48.png', W, 48, fz); previews.append((f'frozen-{W}', fz, W, 48))
    fr = fragile(W); write_png(f'{out}/ASSET-019-fx_fragile_{W}x48.png', W, 48, fr); previews.append((f'fragile-{W}', fr, W, 48))
ch = chill(); write_png(f'{out}/ASSET-020-fx_chill_8.png', 8, 8, ch); previews.append(('chill', ch, 8, 8))
json.dump(meta, open(f'{out}/ASSET-017-020-status.json', 'w'), indent=2)
k = 4; bg = (74, 70, 64, 255)
for name, img, w, h in previews:
    big = [[(img[y // k][x // k] if img[y // k][x // k][3] else bg) for x in range(w * k)] for y in range(h * k)]
    write_png(f'{out}/preview-status-{name}-x4.png', w * k, h * k, big)
print('status overlays written')
