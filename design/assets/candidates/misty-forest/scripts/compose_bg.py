"""ASSET-005 Misty Forest backdrop: compose the three 800x360 layers.

usage: compose_bg.py TREELINE.png PILLAR.png OUT_DIR
  bg_forest_sky.png  800x200  flat Mist #7D8896
  bg_forest_far.png  800x360  sky, tree line + arches standing on the horizon row, ground in
                             three flat steps, margin props (broken pillar + roots left, mirrored
                             and cropped right, a square-cut broken Primal Form stone right),
                             outer 80 px per side mirrored from the play area before props
  bg_forest_near.png 800x48   mist band, seamless horizontally, checker 2x2 edges only (§6.2);
                             the engine draws it with its bottom at HORIZON + MIST_DROP
Also writes preview-bg-x1.png (far + near composited as the engine would).
"""
import math, sys
sys.path.insert(0, __file__.rsplit('\\', 1)[0].rsplit('/', 1)[0])
from crop_frame import read_png, write_png

def c(h): return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), 255)
SKY = c('#7D8896')
GROUND = [c('#3A3F36'), c('#30342D'), c('#262923')]   # three flat steps, darkest near the bottom
MIST = c('#8E99A6')                                    # one step above the sky
STONE_L, STONE, STONE_D = c('#5A5650'), c('#4A4640'), c('#2C2925')
T = (0, 0, 0, 0)
W, H = 800, 360
HORIZON = 44            # 12.2 % of 360: the tree line stands on this row
MIST_DROP = 3           # the mist band's bottom row = HORIZON + MIST_DROP (it lies on the trees' feet)
PLAY_X = 80             # the 640 play area is x 80..719 of the 800 layer
MH = 48

tree_path, pillar_path, out = sys.argv[1], sys.argv[2], sys.argv[3]
tw, th, tpx = read_png(tree_path)
pw, ph, ppx = read_png(pillar_path)
assert tw == 640, tw

def blit(dst, src, sw, sh, ox, oy, flip=False, clip_x=None):
    for y in range(sh):
        for x in range(sw):
            p = src[y][sw - 1 - x] if flip else src[y][x]
            if not p[3]:
                continue
            dx, dy = ox + x, oy + y
            if clip_x is not None and not (clip_x[0] <= dx <= clip_x[1]):
                continue
            if 0 <= dx < W and 0 <= dy < H:
                dst[dy][dx] = p

# --- far layer: sky, ground steps, tree line ---
far = [[SKY] * W for _ in range(H)]
for y in range(HORIZON + 1, H):
    far[y] = [GROUND[0] if y < 150 else GROUND[1] if y < 250 else GROUND[2]] * W
low = max(y for y in range(th) for x in range(tw) if tpx[y][x][3])
blit(far, tpx, tw, th, PLAY_X, HORIZON - low)
# margins: mirror the outer 80 px of the play area so wide screens continue the tree line
for y in range(H):
    for i in range(80):
        far[y][79 - i] = far[y][80 + i]
        far[y][720 + i] = far[y][719 - i]

# --- margin props (static, so they live in the far layer; the near layer is the drifting mist) ---
# The board on a 5x5 at 48x34 starts at canvas x 77 (layer x 157) and its top is canvas y 57, so
# props stay at layer x < 150 and x > 650, standing on ground step 0 (base row 92).
plow = max(y for y in range(ph) for x in range(pw) if ppx[y][x][3])
base = 92
blit(far, ppx, pw, ph, 86, base - plow)                                 # left pillar: layer x 86..149 = canvas 6..69, left of the board
blit(far, ppx, pw, ph, 652, base + 4 - plow, flip=True, clip_x=(652, 719))  # right: mirrored, canvas 572..639, cropped to the visible edge
# square-cut "broken Primal Form" stone at the right margin: a 12x10 block with one corner cut at 90 deg
sx, sy = 596, HORIZON + 2  # in the horizon strip, right of the board, canvas x 516..527 y 46..55
for y in range(10):
    for x in range(12):
        if x >= 8 and y < 4:
            continue  # the missing corner, cut square
        col = STONE_L if (y == 0 or x == 0 or (x == 8 and y < 4) or (y == 4 and x >= 8)) else STONE
        if y >= 8:
            col = STONE_D
        far[sy + y][sx + x] = col
write_png(f'{out}/ASSET-005-bg_forest_far.png', W, H, far)

# --- sky layer ---
write_png(f'{out}/ASSET-005-bg_forest_sky.png', W, 200, [[SKY] * W for _ in range(200)])

# --- near layer: mist band 800x48, seamless; drawn with its bottom at HORIZON + MIST_DROP ---
# Low ground mist: it must sit at the trees' FEET, never across their trunks. Two thin bands in the
# bottom 8 rows of the band, mostly 2x2 checker (allowed for the mist layer, §6.2) so the trees show
# through, a solid core only where a band is thickest; gaps along x; periodic in x so it tiles.
near = [[T] * W for _ in range(MH)]
bands = [(MH - 3, 2, 0.0), (MH - 6, 1, 2.6)]   # (centre row, half thickness, phase)
for cy, half, phase in bands:
    for x in range(W):
        t = 2 * math.pi * x / W
        thick = half + round(0.9 * math.sin(4 * t + phase) + 0.6 * math.sin(9 * t + phase * 0.7))
        gap = math.sin(6 * t + phase) < -0.35
        if gap or thick <= 0:
            continue
        for dy in range(-thick, thick + 1):
            y = cy + dy
            if not (0 <= y < MH):
                continue
            core = thick >= 2 and dy == 0
            if not core and ((x // 2 + y // 2) % 2 == 0):
                continue
            near[y][x] = MIST
write_png(f'{out}/ASSET-005-bg_forest_near.png', W, MH, near)

# --- preview ---
prev = [row[:] for row in far]
blit(prev, near, W, MH, 0, HORIZON + MIST_DROP - MH)
write_png(f'{out}/preview-bg-x1.png', W, H, prev)
cols_far = {p[:3] for row in far for p in row}
print(f'far colours={len(cols_far)} horizon={HORIZON} mist bottom={HORIZON + MIST_DROP} pillar base={base}')
