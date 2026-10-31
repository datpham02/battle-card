"""ASSET-008 steel tiles, ASSET-011 material marks, ASSET-012 telegraph stripe, ASSET-009 slash
sheet, drawn from the specs (design/assets/specs/slice1-combat-ui-assets.md, art bible §3, §4).

usage: draw_fx.py OUT_DIR
  ASSET-008-block_tiles_16.png  112x16  7 columns (steel, ember, ice, wood, glass, odd, enemy); slice 1
                                        fills column 0 (steel) only, the rest stay transparent
  ASSET-008-block_tiles_5.png    35x5   same columns at the on-ground size
  ASSET-011-fx_material_marks_16.png  80x16  5 white masks: bevel, crack, clipped corners, rope, lead
                                        (+ .json: how each one scales to the cell)
  ASSET-012-fx_telegraph_stripe_8.png  8x8  tileable 45-degree stripes, red #E5293B (stripe 255 /
                                        gap alpha 110)
  ASSET-016-vfx_push_sheet.png   155x27 4 frames, the Push group (column at the left edge sliding right half a tile)
  ASSET-009-vfx_slash_sheet.png  155x27 4 frames of 38x27 with a 1 px gutter, three greys only
                                        (light #FFFFFF, body #9A9A9A, ink #1B1722) for `modulate`
Previews x4 / x8 on a mid background next to the files.
"""
import json, sys
sys.path.insert(0, __file__.rsplit('\\', 1)[0].rsplit('/', 1)[0])
from crop_frame import write_png

def c(h, a=255): return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), a)
T = (0, 0, 0, 0)
INK = c('#1B1722')
STEEL, STEEL_HI, STEEL_LO = c('#8FA3B8'), c('#EEF4FA'), c('#5F6F82')
RED = c('#E5293B')
W1, W2 = c('#FFFFFF'), c('#FFFFFF', 128)     # mask: full / half (shadow edge of the bevel)
LIGHT, BODY = c('#FFFFFF'), c('#9A9A9A')

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

# ---------------- ASSET-008 steel ----------------
def steel16():
    img = blank(16, 16)
    rect(img, 0, 0, 15, 15, STEEL)
    rect(img, 0, 15, 15, 15, STEEL_LO); rect(img, 15, 0, 15, 15, STEEL_LO)   # bottom + right dark
    rect(img, 0, 0, 15, 0, STEEL_HI); rect(img, 0, 0, 0, 15, STEEL_HI)       # top + left light (wins the corners)
    img[15][0] = STEEL_LO                                                     # bottom-left: dark
    return img
def steel5():
    img = blank(5, 5)
    rect(img, 0, 0, 4, 4, STEEL)
    img[0][0] = STEEL_HI
    img[4][4] = STEEL_LO
    return img
COLS = ['steel', 'ember', 'ice', 'wood', 'glass', 'odd', 'enemy']
tiles16 = blank(16 * 7, 16); blit(tiles16, steel16(), 0, 0)
tiles5 = blank(5 * 7, 5); blit(tiles5, steel5(), 0, 0)

# ---------------- ASSET-011 marks (white masks) ----------------
def mark_bevel():
    m = blank(16, 16)
    rect(m, 0, 15, 15, 15, W2); rect(m, 15, 0, 15, 15, W2)
    rect(m, 0, 0, 15, 0, W1); rect(m, 0, 0, 0, 15, W1)
    m[15][0] = W2
    return m
def mark_crack():  # one stepped diagonal, 1 px, with a kink: top-left to bottom-right
    m = blank(16, 16)
    pts = [(3, 2), (4, 3), (5, 4), (6, 5), (7, 6), (7, 7), (8, 8), (9, 9), (10, 10), (11, 11), (11, 12), (12, 13)]
    for x, y in pts:
        m[y][x] = W1
    m[5][8] = W1; m[12][9] = W1   # two 1 px side splinters
    return m
def mark_clipped():  # 1 px frame, top-right and bottom-left corners cut 3 px at 45 degrees
    m = blank(16, 16)
    rect(m, 0, 0, 15, 0, W1); rect(m, 0, 15, 15, 15, W1); rect(m, 0, 0, 0, 15, W1); rect(m, 15, 0, 15, 15, W1)
    for i in range(4):  # clear the corner, draw the chamfer
        for j in range(4 - i):
            m[i][15 - j] = T
            m[15 - i][j] = T
    for i in range(4):
        m[i][12 + i] = W1
        m[15 - i][3 - i] = W1
    return m
def mark_rope():  # frame + one horizontal rope line with two knots
    m = blank(16, 16)
    rect(m, 0, 0, 15, 0, W1); rect(m, 0, 15, 15, 15, W1); rect(m, 0, 0, 0, 15, W1); rect(m, 15, 0, 15, 15, W1)
    rect(m, 1, 8, 14, 8, W1)
    m[7][4] = W1; m[9][4] = W1; m[7][11] = W1; m[9][11] = W1
    return m
def mark_lead():  # lead lines splitting the tile 2x2, no frame
    m = blank(16, 16)
    rect(m, 0, 7, 15, 8, W1); rect(m, 7, 0, 8, 15, W1)
    return m
MARKS = [('bevel', mark_bevel(), 'nine_slice', [1, 1, 1, 1]), ('crack', mark_crack(), 'center', None),
         ('clipped', mark_clipped(), 'nine_slice', [4, 4, 4, 4]), ('rope', mark_rope(), 'nine_slice', [1, 7, 1, 7]),
         ('lead', mark_lead(), 'nine_slice', [7, 7, 7, 7])]
marks = blank(16 * 5, 16)
marks_index = {}
for i, (name, m, how, margins) in enumerate(MARKS):
    blit(marks, m, 16 * i, 0)
    marks_index[name] = {"rect": [16 * i, 0, 16, 16], "scale": how, "nine_slice": margins}

# ---------------- ASSET-012 stripe ----------------
stripe = blank(8, 8)
for y in range(8):
    for x in range(8):
        stripe[y][x] = RED if (x + y) % 4 < 2 else c('#E5293B', 110)

# ---------------- ASSET-009 slash ----------------
FW, FH = 38, 27
# the full streak: 13 squares on a 45-degree line from (4,1) to (28,25), 2 px apart. v2 (2026-10-31,
# user: "thicker"): every lit square is 3x3, so neighbours overlap 1 px into one solid stepped band
# ~3 px wide with a 1 px body outline around the whole band; the trail is 2x2 body squares, then dust
PATH = [(4 + 2 * i, 1 + 2 * i) for i in range(13)]
def slash_frame(lit, body, dust):
    """lit: indices of the solid light band (outline pass first, then fills, so the band stays
    unbroken); body: 2x2 body squares, no outline; dust: one body pixel each (the trail dissolving)."""
    img = blank(FW, FH)
    for i in dust:
        x, y = PATH[i]; img[y + 1][x] = BODY
    for i in body:
        x, y = PATH[i]; rect(img, x, y, x + 1, y + 1, BODY)
    for i in lit:
        x, y = PATH[i]; rect(img, x - 1, y - 1, x + 3, y + 3, BODY)
    for i in lit:
        x, y = PATH[i]; rect(img, x, y, x + 2, y + 2, LIGHT)
    return img
FRAMES = [
    slash_frame(lit=[0, 1, 2, 3], body=[], dust=[]),                        # f1 0.05 s: the cut starts top-left
    slash_frame(lit=[4, 5, 6, 7, 8], body=[2, 3], dust=[0, 1]),             # f2 0.06 s: sweeping, tail thinning
    slash_frame(lit=[9, 10, 11, 12], body=[7, 8], dust=[4, 5, 6]),          # f3 0.06 s: reaches the bottom-right
    slash_frame(lit=[], body=[11, 12], dust=[7, 8, 9, 10]),                 # f4 0.06 s: fading; reduced motion holds this
]
GUT = 1
sheet = blank(FW * 4 + GUT * 3, FH)
for i, f in enumerate(FRAMES):
    blit(sheet, f, i * (FW + GUT), 0)

# ---------------- ASSET-016 push (Chấn phong group) ----------------
# §3: a column of squares at the left edge of each target tile slides right half a tile (19 px)
# and thins out; <= 0.3 s. Same greys and the same 3x3-square band as the slash v2.
PUSH_YS = [2, 6, 10, 14, 18]          # five 3x3 squares, 1 px apart (the outline fills the gaps)
def push_frame(x, ys, body_only=False, dust=()):
    img = blank(FW, FH)
    for dx, dy in dust:
        img[dy][dx] = BODY
    if body_only:
        for y in ys:
            rect(img, x, y + 1, x + 1, y + 2, BODY)
        return img
    for y in ys:
        rect(img, x - 1, y - 1, x + 3, y + 3, BODY)
    for y in ys:
        rect(img, x, y, x + 2, y + 2, LIGHT)
    return img
PUSH_FRAMES = [
    push_frame(2, PUSH_YS),                                                     # f1 0.06 s: the column stands at the left edge
    push_frame(8, PUSH_YS, dust=[(3, 3), (3, 19)]),                             # f2 0.08 s: slid 6 px, two dust px behind
    push_frame(14, PUSH_YS[1:4], dust=[(9, 3), (9, 19), (10, 7), (10, 15)]),    # f3 0.08 s: 3 squares left, more dust
    push_frame(19, PUSH_YS[2:4], body_only=True, dust=[(15, 7), (15, 15), (16, 11)]),  # f4 0.08 s: half a tile, two body squares, fading
]
push_sheet = blank(FW * 4 + GUT * 3, FH)
for i, f in enumerate(PUSH_FRAMES):
    blit(push_sheet, f, i * (FW + GUT), 0)

# ---------------- write ----------------
out = sys.argv[1]
write_png(f'{out}/ASSET-008-block_tiles_16.png', 16 * 7, 16, tiles16)
write_png(f'{out}/ASSET-008-block_tiles_5.png', 5 * 7, 5, tiles5)
json.dump({"columns": COLS, "cell_16": 16, "cell_5": 5, "filled": ["steel"]}, open(f'{out}/ASSET-008-block_tiles.json', 'w'), indent=2)
write_png(f'{out}/ASSET-011-fx_material_marks_16.png', 16 * 5, 16, marks)
json.dump({"cell": 16, "marks": marks_index, "alpha_levels": {"255": "highlight edge / line", "128": "shadow edge (bevel only)"}},
          open(f'{out}/ASSET-011-fx_material_marks_16.json', 'w'), indent=2)
write_png(f'{out}/ASSET-012-fx_telegraph_stripe_8.png', 8, 8, stripe)
write_png(f'{out}/ASSET-009-vfx_slash_sheet.png', FW * 4 + GUT * 3, FH, sheet)
json.dump({"frame": [FW, FH], "gutter": GUT, "frames": [{"i": i, "ms": ms} for i, ms in enumerate([50, 60, 60, 60])],
           "greys": {"light": "#FFFFFF", "body": "#9A9A9A", "ink": "#1B1722"}, "tint": "modulate = hero block highlight colour",
           "reduced_motion": "frame 3 held 150 ms"}, open(f'{out}/ASSET-009-vfx_slash_sheet.json', 'w'), indent=2)

write_png(f'{out}/ASSET-016-vfx_push_sheet.png', FW * 4 + GUT * 3, FH, push_sheet)
json.dump({"frame": [FW, FH], "gutter": GUT, "frames": [{"i": i, "ms": ms} for i, ms in enumerate([60, 80, 80, 80])],
           "greys": {"light": "#FFFFFF", "body": "#9A9A9A", "ink": "#1B1722"}, "tint": "modulate = hero block highlight colour",
           "reduced_motion": "frame 3 held 150 ms"}, open(f'{out}/ASSET-016-vfx_push_sheet.json', 'w'), indent=2)

def preview(name, img, w, h, k, bg=(74, 70, 64, 255)):
    big = [[(img[y // k][x // k] if img[y // k][x // k][3] == 255 else
             (tuple(int(bg[i] + (img[y // k][x // k][i] - bg[i]) * img[y // k][x // k][3] / 255) for i in range(3)) + (255,)) if img[y // k][x // k][3] else bg)
            for x in range(w * k)] for y in range(h * k)]
    write_png(f'{out}/preview-{name}.png', w * k, h * k, big)
preview('steel-x8', tiles16, 16 * 7, 16, 8)
preview('steel5-x8', tiles5, 5 * 7, 5, 8)
preview('marks-x8', marks, 16 * 5, 16, 8, bg=(50, 70, 90, 255))
preview('stripe-x8', stripe, 8, 8, 8, bg=(58, 63, 54, 255))
preview('slash-x4', sheet, FW * 4 + GUT * 3, FH, 4)
preview('push-x4', push_sheet, FW * 4 + GUT * 3, FH, 4)
print('fx written')
