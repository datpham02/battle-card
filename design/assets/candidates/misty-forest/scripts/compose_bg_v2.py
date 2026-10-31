"""ASSET-005 Misty Forest backdrop v2 (2026-10-31): layers from the generated full-frame scene.

usage: compose_bg_v2.py SCENE_640x360.png OUT_DIR
  bg_forest_far.png   800x360  the scene with the outer 80 px per side mirrored from the play area
                               and the lower third darkened in flat steps (control base, art bible
                               §6.4 "đáy 36 % tối dần theo bậc"; §6.2: no smooth gradients)
  bg_forest_near.png  800x48   drifting mist: three seamless wisp bands in the valley's own light
                               tones, 2x2 checker edges only; the engine draws it with its BOTTOM at
                               MIST_BOTTOM (art-px) so it lies over the far valley in the visible
                               0–20 % strip, not behind the board
  No separate sky layer: the scene is opaque to the top edge (≤ 3 layers allowed, 2 used).
Also writes preview-bg-v2-x1.png (far + near composited as the engine would).
"""
import math, sys
sys.path.insert(0, __file__.rsplit('\\', 1)[0].rsplit('/', 1)[0])
from crop_frame import read_png, write_png

W, H, MH = 800, 360, 48
MIST_BOTTOM = 70                      # the strip above the board is rows 0..71 at a 20 % band
STEPS = [(215, 1.0), (245, 0.78), (285, 0.6), (325, 0.48), (360, 0.42)]
MIST_A = (185, 188, 181, 255)         # sampled from the scene's valley light (#B9BCB5)
MIST_B = (173, 176, 168, 255)         # one step lower (#ADB0A8), for the lower band
T = (0, 0, 0, 0)

scene_path, out = sys.argv[1], sys.argv[2]
sw, sh, spx = read_png(scene_path)
assert (sw, sh) == (640, 360), (sw, sh)

# --- far layer ---
# Darkening is done by REMAPPING to the scene's own palette (nearest colour), not by multiplying
# freely: a multiply would turn 38 colours into ~270 and break the flat-step rule.
base = sorted({p[:3] for row in spx for p in row})
def nearest(rgb):
    return min(base, key=lambda c: (c[0] - rgb[0]) ** 2 + (c[1] - rgb[1]) ** 2 + (c[2] - rgb[2]) ** 2)
cache = {}
far = [[(0, 0, 0, 255)] * W for _ in range(H)]
for y in range(H):
    f = 1.0
    for i in range(len(STEPS) - 1):
        if STEPS[i][0] <= y < STEPS[i + 1][0]:
            f = STEPS[i + 1][1]
    for x in range(sw):
        p = spx[y][x]
        g = f * (0.85 if y >= 72 and (x < 30 or x > 609) else 1.0)
        if g == 1.0:
            far[y][80 + x] = (p[0], p[1], p[2], 255)
        else:
            key = (p[:3], g)
            if key not in cache:
                cache[key] = nearest((int(p[0] * g), int(p[1] * g), int(p[2] * g)))
            far[y][80 + x] = cache[key] + (255,)
    for i in range(80):
        far[y][79 - i] = far[y][80 + i]
        far[y][720 + i] = far[y][719 - i]
write_png(f'{out}/ASSET-005-bg_forest_far.png', W, H, far)

# --- near layer: mist wisps, seamless in x (functions of 2*pi*x/W), bottom row = MIST_BOTTOM ---
near = [[T] * W for _ in range(MH)]
bands = [(18, 3, 0.0, MIST_A), (29, 4, 2.1, MIST_A), (40, 3, 4.2, MIST_B)]
for cy, half, phase, col in bands:
    for x in range(W):
        t = 2 * math.pi * x / W
        thick = half + round(1.5 * math.sin(3 * t + phase) + 1.0 * math.sin(7 * t + phase * 0.5))
        gap = math.sin(5 * t + phase) < -0.5
        if gap or thick <= 0:
            continue
        for dy in range(-thick, thick + 1):
            y = cy + dy
            if 0 <= y < MH:
                edge = abs(dy) >= thick - 1
                if edge and ((x // 2 + y // 2) % 2 == 0):
                    continue
                # mist only over the valley: skip where the far layer under this pixel is dark
                # (trunks, crowns), so the wisps never cut across the trees (user's remark on v1)
                fy = MIST_BOTTOM - MH + y
                under = far[fy][x] if 0 <= fy < H else (0, 0, 0, 255)
                if max(under[:3]) < 120:
                    continue
                near[y][x] = col
write_png(f'{out}/ASSET-005-bg_forest_near.png', W, MH, near)

# --- preview ---
prev = [row[:] for row in far]
oy = MIST_BOTTOM - MH
for y in range(MH):
    for x in range(W):
        if near[y][x][3] and 0 <= oy + y < H:
            prev[oy + y][x] = near[y][x]
write_png(f'{out}/preview-bg-v2-x1.png', W, H, prev)
cols = {p[:3] for row in far for p in row}
print(f'far colours={len(cols)} mist bottom={MIST_BOTTOM} near opaque px={sum(1 for r in near for p in r if p[3])}')
