"""ASSET-007 Misty Forest thorns patch, drawn from the spec (no AI).

usage: draw_thorns.py OUT_DIR
40x12 canvas, anchor bottom-centre, sparse triangular spikes <= 6 px tall in bone-rust
#B89A6A with a darker #8A7350 shadow side and an Ink tip; no enclosing outline, the slab
face stays visible between spikes.
"""
import sys
sys.path.insert(0, __file__.rsplit('\\', 1)[0].rsplit('/', 1)[0])
from crop_frame import write_png

def c(h): return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), 255)
THORN, THORN_D, INK, T = c('#B89A6A'), c('#8A7350'), c('#1B1722'), (0, 0, 0, 0)
W, H = 40, 12
img = [[T for _ in range(W)] for _ in range(H)]

def spike(x, h, lean=0):
    """A triangle of height h whose base sits on the bottom row; apex at x (+lean per row up).
    Light side left, dark side right, Ink tip."""
    base = H - 1
    for i in range(h):
        y = base - i
        half = (h - 1 - i) // 2
        cx = x + (lean * i) // max(h - 1, 1)
        for dx in range(-half, half + 1):
            px = cx + dx
            if 0 <= px < W:
                img[y][px] = THORN_D if dx > 0 else THORN
    tip_y = base - (h - 1)
    tip_x = x + lean
    if 0 <= tip_x < W:
        img[tip_y][tip_x] = INK

# seven spikes, uneven spacing and heights 3..6, two leaning, gaps of 2-5 px between bases
spike(3, 4)
spike(9, 6, 1)
spike(14, 3)
spike(20, 5, -1)
spike(26, 4)
spike(31, 6)
spike(37, 3)

out = sys.argv[1]
write_png(f'{out}/ASSET-007-env_thorn_forest.png', W, H, img)
k = 8; bg = (74, 70, 64, 255)  # stone face behind, like in game
big = [[(img[y // k][x // k] if img[y // k][x // k][3] else bg) for x in range(W * k)] for y in range(H * k)]
write_png(f'{out}/preview-thorns-x8.png', W * k, H * k, big)
opaque = sum(1 for row in img for p in row if p[3])
print(f'thorns written: {opaque} opaque px of {W*H} ({opaque*100//(W*H)} %), max height 6')
