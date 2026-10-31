"""ASSET-004 Misty Forest slab set, drawn pixel by pixel from the spec (no AI).

usage: draw_slabs.py OUT_DIR
Writes env_slab_forest_9slice.png (16x16), env_slab_forest_stamps.png (48x16, six 16x8 cells),
env_slab_forest_stamps.json (cell rects, anchors) and 8x previews.
"""
import json, sys
sys.path.insert(0, __file__.rsplit('\\', 1)[0].rsplit('/', 1)[0])
from crop_frame import write_png

def c(h): return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), 255)
# v2 2026-10-31 (user: bolder slabs, cooler than the earth backdrop): face 3 tones (light edge,
# face, dark inner edge), lip darker with a 1 px light line on top; v1 was #5A5650 / #4A4640 / #2C2925
INK, LIGHT, STONE, DARK, CRACK, LIP, LIP_TOP = c('#1B1722'), c('#6A6B62'), c('#4C4D47'), c('#3A3B37'), c('#3E3F3A'), c('#262521'), c('#5A5B54')
MOSS, MOSS_D = c('#5E6B55'), c('#4A5545')
T = (0, 0, 0, 0)

def blank(w, h, fill=T): return [[fill for _ in range(w)] for _ in range(h)]
def put(img, pts, col):
    for x, y in pts: img[y][x] = col

# --- 9-slice 16x16: margins L3 R3 T3 B4; centre (3..12, 3..11) is flat face so it stretches ---
s = blank(16, 16, STONE)
put(s, [(x, 15) for x in range(16)] + [(15, y) for y in range(16)], INK)        # gap right + bottom
put(s, [(x, y) for y in (12, 13, 14) for x in range(15)], LIP)                   # front lip 3 px
put(s, [(x, 12) for x in range(1, 14)], LIP_TOP)                                 # light line on the lip's top edge
put(s, [(x, 11) for x in range(1, 15)] + [(14, y) for y in range(1, 12)], DARK)  # dark inner edge right + bottom
put(s, [(x, 0) for x in range(15)] + [(0, y) for y in range(12)], LIGHT)         # light edge top-left
# v4 (user 2026-10-31: "viền của sàn đừng có vuông quá"): the four face corners are notched 1 px
# (Ink = the gap), so every slab reads as a worn stone, not a rectangle; chips below add variety
put(s, [(0, 0), (14, 0), (0, 14), (14, 14)], INK)
s[1][0] = LIGHT; s[0][1] = LIGHT

# --- stamps: six 16x8 cells, 3 columns x 2 rows (v1 band, rects unchanged) + a v3 band below
# (y 16..31): crack_c and two moss clusters traced from the Pro Flash slab test (gen-01, 2026-10-31)
# and two speckle stamps (sparse 2 px clusters, <= 4 % of a face per art bible §6.2) ---
SHEET_W, SHEET_H = 96, 48
st = blank(SHEET_W, SHEET_H)
def cell(cx, cy, pts, col): put(st, [(cx * 16 + x, cy * 8 + y) for x, y in pts], col)
# 0 crack A (10x6): 1 px stepped line, one step darker than the face
cell(0, 0, [(1, 1), (2, 1), (3, 2), (4, 2), (5, 3), (6, 3), (6, 4), (7, 4), (8, 5), (9, 5)], CRACK)
# 1 crack B (11x6): the other diagonal with a short fork
cell(1, 0, [(1, 5), (2, 5), (3, 4), (4, 4), (5, 3), (6, 3), (7, 2), (8, 2), (9, 1), (10, 1), (5, 4), (5, 5)], CRACK)
# 2 moss corner A (6x5), anchored top-left: organic, low, two tones
cell(2, 0, [(0, 0), (1, 0), (2, 0), (3, 0), (0, 1), (1, 1), (2, 1), (3, 1), (4, 1), (5, 1),
            (0, 2), (1, 2), (2, 2), (3, 2), (4, 2), (0, 3), (1, 3), (2, 3), (0, 4), (1, 4)], MOSS)
cell(2, 0, [(1, 1), (2, 2), (0, 3), (0, 4), (4, 2)], MOSS_D)
# 3 moss corner B (7x4), anchored bottom-right
cell(0, 1, [(15, 7), (14, 7), (13, 7), (12, 7), (11, 7), (10, 7), (9, 7),
            (15, 6), (14, 6), (13, 6), (12, 6), (11, 6), (10, 6),
            (15, 5), (14, 5), (13, 5), (12, 5), (15, 4), (14, 4)], MOSS)
cell(0, 1, [(14, 6), (13, 5), (15, 4), (11, 7), (9, 7)], MOSS_D)
# 4 root edge (12x6), anchored bottom-left: a root lifting the corner, cut at a clean 90 degrees
cell(1, 1, [(0, 2), (1, 2), (0, 3), (1, 3), (0, 4), (1, 4), (2, 4), (0, 5), (1, 5), (2, 5), (3, 5), (4, 5),
            (5, 5), (6, 5), (7, 5), (8, 5), (9, 5), (10, 5), (11, 5), (5, 4), (6, 4), (7, 4), (9, 4), (10, 4)], LIP)
cell(1, 1, [(0, 2), (1, 2), (2, 4), (5, 4), (6, 4), (9, 4), (11, 5)], CRACK)
# 5 fallen leaves (10x6), anchored anywhere: four 2x2 leaves in two moss tones, clusters not single pixels
cell(2, 1, [(1, 1), (2, 1), (1, 2), (5, 3), (6, 3), (6, 4), (8, 0), (9, 0), (3, 5), (4, 5)], MOSS)
cell(2, 1, [(2, 2), (5, 4), (8, 1), (9, 1), (4, 4)], MOSS_D)

# v3 band -------------------------------------------------------------------------------
SPECK, SPECK_D = c('#5A5B54'), c('#3A3B37')
# crack_c: the long curved crack of the generated slab, traced as one stepped line (32x14),
# dark core with a 1 px crack tone beside it on the lower side
crack_c = [(0, 13), (1, 13), (2, 12), (3, 12), (4, 11), (5, 11), (6, 11), (7, 10), (8, 10), (9, 10), (10, 10), (11, 9), (12, 9),
           (13, 9), (14, 8), (15, 8), (16, 7), (17, 7), (18, 7), (19, 6), (20, 6), (21, 5), (22, 5), (23, 5), (24, 4), (25, 4),
           (26, 3), (27, 3), (28, 2), (29, 2), (30, 1), (31, 0)]
for (x, y) in crack_c:
    st[16 + y][x] = LIP if x % 5 in (0, 1, 2) else CRACK
    if 16 + y + 1 < SHEET_H and x % 3 == 0:
        st[16 + y + 1][x] = CRACK
# moss_c (8x7) and moss_d (8x4): the two moss clusters of the generated slab, two tones
moss_c = [(2, 0), (3, 0), (4, 0), (3, 1), (4, 1), (5, 1), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2), (1, 3), (2, 3), (3, 3), (4, 3),
          (5, 3), (6, 3), (7, 3), (2, 4), (3, 4), (4, 4), (5, 4), (6, 4), (0, 5), (1, 5), (2, 5), (3, 5), (5, 6), (6, 6)]
for (x, y) in moss_c:
    st[16 + y][34 + x] = MOSS_D if (x + y) % 4 == 0 else MOSS
moss_d = [(2, 0), (3, 0), (4, 0), (1, 1), (2, 1), (3, 1), (4, 1), (5, 1), (6, 1), (0, 2), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (3, 3), (4, 3), (7, 3)]
for (x, y) in moss_d:
    st[16 + y][44 + x] = MOSS_D if (x * y) % 5 == 1 else MOSS
# speckle_a / speckle_b (16x8): 5 clusters of 2 px, one dark cluster each; never single pixels
for (ox, pts, dark) in ((54, [(1, 1), (2, 1), (6, 3), (7, 3), (11, 0), (11, 1), (3, 6), (4, 6), (13, 5), (14, 5)], (6, 3)),
                        (72, [(0, 4), (1, 4), (5, 1), (6, 1), (9, 6), (10, 6), (13, 2), (14, 2), (7, 7), (8, 7)], (13, 2))):
    for (x, y) in pts:
        st[16 + y][ox + x] = SPECK
    st[16 + dark[1]][ox + dark[0]] = SPECK_D
    st[16 + dark[1]][ox + dark[0] + 1] = SPECK_D

# v4 band (y 32..47): edge chips and nicks. A chip is Ink (the gap colour) biting into the slab
# plus the light edge re-drawn along the bite's top-left, so the stone looks broken, not drawn on.
def chip(ox, pts_ink, pts_light=(), pts_dark=()):
    for (x, y) in pts_ink: st[32 + y][ox + x] = INK
    for (x, y) in pts_light: st[32 + y][ox + x] = LIGHT
    for (x, y) in pts_dark: st[32 + y][ox + x] = DARK
# chip_tl 5x4: corner bite, stepped
chip(0, [(0,0),(1,0),(2,0),(3,0),(0,1),(1,1),(2,1),(0,2),(1,2),(0,3)], [(4,0),(3,1),(2,2),(1,3)])
# chip_tr 5x4 (mirror): the bite's inner edge is dark on the right side
chip(6, [(1,0),(2,0),(3,0),(4,0),(2,1),(3,1),(4,1),(3,2),(4,2),(4,3)], [(0,0)], [(1,1),(2,2),(3,3)])
# chip_bl 4x4
chip(12, [(0,0),(0,1),(1,1),(0,2),(1,2),(2,2),(0,3),(1,3),(2,3),(3,3)], [(1,0),(2,1),(3,2)])
# chip_br 4x4
chip(17, [(3,0),(2,1),(3,1),(1,2),(2,2),(3,2),(0,3),(1,3),(2,3),(3,3)], (), [(2,0),(1,1),(0,2)])
# nick_top 6x2: a shallow bite on the top edge, light edge continues under it
chip(22, [(1,0),(2,0),(3,0),(4,0),(2,1),(3,1)], [(0,0),(5,0),(1,1),(4,1),(2,2) if False else (2,1) if False else (0,1)], ())
# nick_left 2x6: bite on the left edge
chip(29, [(0,1),(0,2),(1,2),(0,3),(1,3),(0,4)], [(1,1),(1,4)], ())
# nick_lip 6x3: a chunk missing from the front lip's bottom (Ink), lip tone above it
chip(32, [(1,2),(2,2),(3,2),(4,2),(2,1),(3,1)], (), ())
for (x, y) in [(1,1),(4,1),(0,2),(5,2)]: st[32 + y][32 + x] = LIP

meta = {
    "cell": [16, 8],
    "stamps": [
        {"name": "crack_a", "rect": [0, 0, 11, 7], "anchor": "any", "kind": "crack"},
        {"name": "crack_b", "rect": [16, 0, 12, 7], "anchor": "any", "kind": "crack"},
        {"name": "moss_tl", "rect": [32, 0, 6, 5], "anchor": "top_left", "kind": "cover"},
        {"name": "moss_br", "rect": [9, 12, 7, 4], "anchor": "bottom_right", "kind": "cover"},
        {"name": "root_bl", "rect": [16, 10, 12, 6], "anchor": "bottom_left", "kind": "cover"},
        {"name": "leaves", "rect": [32, 8, 10, 6], "anchor": "any", "kind": "cover"},
        {"name": "crack_c", "rect": [0, 16, 32, 14], "anchor": "any", "kind": "crack"},
        {"name": "moss_c", "rect": [34, 16, 8, 7], "anchor": "any", "kind": "cover"},
        {"name": "moss_d", "rect": [44, 16, 8, 4], "anchor": "any", "kind": "cover"},
        {"name": "speckle_a", "rect": [54, 16, 16, 8], "anchor": "any", "kind": "speckle"},
        {"name": "speckle_b", "rect": [72, 16, 16, 8], "anchor": "any", "kind": "speckle"},
        {"name": "chip_tl", "rect": [0, 32, 5, 4], "anchor": "top_left", "kind": "chip"},
        {"name": "chip_tr", "rect": [6, 32, 5, 4], "anchor": "top_right", "kind": "chip"},
        {"name": "chip_bl", "rect": [12, 32, 4, 4], "anchor": "bottom_left_face", "kind": "chip"},
        {"name": "chip_br", "rect": [17, 32, 4, 4], "anchor": "bottom_right_face", "kind": "chip"},
        {"name": "nick_top", "rect": [22, 32, 6, 2], "anchor": "top_edge", "kind": "chip"},
        {"name": "nick_left", "rect": [29, 32, 2, 6], "anchor": "left_edge", "kind": "chip"},
        {"name": "nick_lip", "rect": [32, 32, 6, 3], "anchor": "lip_bottom", "kind": "chip"},
    ],
    "version": "v4 2026-10-31 (v3 stamps + notched corners + edge chips/nicks for worn edges)",
    "rules": {"max_cracks_per_slab": 2, "max_cover_face_ratio": 0.25, "speckle_max_face_ratio": 0.04, "placed_by": "cell seed"},
    "palette": {"stone": "#4C4D47", "light_edge": "#6A6B62", "dark_edge": "#3A3B37", "crack": "#3E3F3A", "lip": "#262521",
                "lip_top": "#5A5B54", "ink": "#1B1722", "moss": "#5E6B55", "moss_dark": "#4A5545"},
    "version": "v2 2026-10-31",
    "nine_slice": {"size": [16, 16], "margins": {"left": 3, "right": 3, "top": 3, "bottom": 4}},
}

out = sys.argv[1]
write_png(f'{out}/ASSET-004-env_slab_forest_9slice.png', 16, 16, s)
write_png(f'{out}/ASSET-004-env_slab_forest_stamps.png', SHEET_W, SHEET_H, st)
json.dump(meta, open(f'{out}/ASSET-004-env_slab_forest_stamps.json', 'w'), indent=2)
k = 8; bg = (27, 23, 34, 255)
for name, img, w, h in (('9slice', s, 16, 16), ('stamps', st, SHEET_W, SHEET_H)):
    big = [[(img[y // k][x // k] if img[y // k][x // k][3] else bg) for x in range(w * k)] for y in range(h * k)]
    write_png(f'{out}/preview-{name}-x8.png', w * k, h * k, big)
cols = {p[:3] for img in (s, st) for row in img for p in row if p[3]}
print('written; colours used:', len(cols))
