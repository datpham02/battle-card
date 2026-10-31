"""ASSET-007 v2 (user 2026-10-31: "sao ko làm gai hiện nguyên cái ô"): a TILEABLE 16x16 thorn patch
the engine repeats over the whole cell face, so a thorn tile reads as thorny edge to edge while the
slab still shows between spikes (art bible §6.3: low spikes <= 6 px, no enclosing outline).

usage: draw_thorns_v2.py OUT_DIR  -> ASSET-007-env_thorn_forest_tile16.png + preview (3x3 tiles, x6)
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from crop_frame import write_png

def c(h): return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), 255)
THORN, THORN_D, BRAMBLE, INK, T = c('#B89A6A'), c('#8A7350'), c('#4A3A2A'), c('#1B1722'), (0, 0, 0, 0)
S = 16
img = [[T for _ in range(S)] for _ in range(S)]

def spike(x, base, h, lean=0):
    for i in range(h):
        y = (base - i) % S
        half = (h - 1 - i) // 2
        cx = x + (lean * i) // max(h - 1, 1)
        for dx in range(-half, half + 1):
            img[y][(cx + dx) % S] = THORN_D if dx > 0 else THORN
    img[(base - (h - 1)) % S][(x + lean) % S] = INK

# brambles first (thin dark stems lying on the ground), then spikes on two staggered rows so the
# tiling never lines up into a visible grid
for (x, y) in [(0, 6), (1, 6), (2, 7), (3, 7), (9, 14), (10, 14), (11, 15), (12, 15), (13, 2), (14, 2), (5, 11), (6, 11)]:
    img[y][x] = BRAMBLE
spike(3, 15, 5, 1)
spike(10, 15, 3)
spike(14, 15, 4, -1)
spike(6, 7, 4)
spike(12, 7, 5, 1)
spike(1, 9, 3)

out = sys.argv[1]
write_png(f'{out}/ASSET-007-env_thorn_forest_tile16.png', S, S, img)
k = 6; bg = (0x4C, 0x4D, 0x47, 255)  # slab v2 face behind
big = [[(img[(y // k) % S][(x // k) % S] if img[(y // k) % S][(x // k) % S][3] else bg) for x in range(S * 3 * k)] for y in range(S * 3 * k)]
write_png(f'{out}/preview-thorns-tile16-3x3-x6.png', S * 3 * k, S * 3 * k, big)
opaque = sum(1 for row in img for p in row if p[3])
print(f'thorn tile written: {opaque} opaque px of {S*S} ({opaque*100//(S*S)} %)')
