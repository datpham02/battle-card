"""ASSET-013 UI frames and ASSET-015 icon sheet, drawn from the spec (no AI).

usage: draw_ui.py OUT_DIR
Frames (art-px, drawn x2 on the 1280x720 HUD layer):
  ui_frame_panel_9slice.png   16x16  margins 4/4/4/6, notched corners, Mist border (rows 0..13), fill #1E1B24 @90 %, 2 px Ink lip below the frame
  ui_frame_button_9slice.png  48x16  three 16x16 states in a row: default (lip), pressed (no lip), disabled (dim)
  ui_frame_slot_9slice.png    16x16  margin 3, recessed (Ink top-left, #4A4652 bottom-right), Mist outer border
  ui_frame_bar_3slice.png     16x8   ends 2, border 1, Ink groove @90 %
Icons: ui_icons_12.png, 21 icons of 12x12 in a 7x3 grid with 1 px gutters (90x38) + ui_icons_12.json.
Only squares and 45-degree steps, 2 px strokes, one flat colour + one Ivory highlight pixel top-left.
"""
import json, sys
sys.path.insert(0, __file__.rsplit('\\', 1)[0].rsplit('/', 1)[0])
from crop_frame import write_png

def c(h, a=255): return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), a)
T = (0, 0, 0, 0)
INK, MIST, IVORY = c('#1B1722'), c('#7D8896'), c('#EFE6D2')
FILL = c('#1E1B24', 230)          # 90 % per art bible §7.4 (HUD glass; the 0/255 alpha rule is for sprites)
FILL_DIM = c('#1E1B24', 150)
BORDER_DIM = c('#4A4652')
RECESS_LIGHT = c('#4A4652')
GROOVE = c('#1B1722', 230)

def blank(w, h): return [[T] * w for _ in range(h)]
def rect(img, x0, y0, x1, y1, col):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            img[y][x] = col
def frame(img, x0, y0, x1, y1, col, notch=True):
    rect(img, x0, y0, x1, y0, col); rect(img, x0, y1, x1, y1, col)
    rect(img, x0, y0, x0, y1, col); rect(img, x1, y0, x1, y1, col)
    if notch:
        for (x, y) in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
            img[y][x] = T

# --- panel 16x16: Mist frame rows 0..13 (fill rows 1..12), the 2 px Ink lip HANGS BELOW the frame
# (rows 14..15, inset 1 px like the notch). Ink inside the #1E1B24 fill is invisible (1 value step),
# so the lip only reads as "raised" when it sits under the border, against whatever is behind the
# button. Pressed = the same frame without the lip (the drawer shifts it down 2 art-px). ---
def panel(dim=False, lip=True):
    img = blank(16, 16)
    rect(img, 1, 1, 14, 12, FILL_DIM if dim else FILL)
    frame(img, 0, 0, 15, 13, BORDER_DIM if dim else MIST)
    if lip:
        rect(img, 1, 14, 14, 15, INK)
    return img

# --- button 48x16: default | pressed | disabled ---
btn = blank(48, 16)
for i, img in enumerate((panel(), panel(lip=False), panel(dim=True))):
    for y in range(16):
        for x in range(16):
            btn[y][16 * i + x] = img[y][x]

# --- slot 16x16: Mist outer frame, recessed inner edges, dark fill ---
slot = blank(16, 16)
rect(slot, 1, 1, 14, 14, c('#15131A', 230))
rect(slot, 1, 1, 14, 1, INK); rect(slot, 1, 1, 1, 14, INK)                  # top-left inner edge
rect(slot, 2, 14, 14, 14, RECESS_LIGHT); rect(slot, 14, 2, 14, 14, RECESS_LIGHT)  # bottom-right inner edge
frame(slot, 0, 0, 15, 15, MIST)

# --- bar 16x8: border 1, groove inside, ends 2 (the end columns are the frame + 1 px) ---
bar = blank(16, 8)
rect(bar, 1, 1, 14, 6, GROOVE)
frame(bar, 0, 0, 15, 7, MIST)

# --- icons ---
S = 12
def icon(pixels_by_colour, outline=False):
    img = blank(S, S)
    for col, pts in pixels_by_colour:
        for x, y in pts:
            img[y][x] = col
    if outline:  # 1 px Ink outline for icons placed on the world (chips, check, cross)
        src = [row[:] for row in img]
        for y in range(S):
            for x in range(S):
                if src[y][x][3]:
                    continue
                if any(0 <= x + dx < S and 0 <= y + dy < S and src[y + dy][x + dx][3] and src[y + dy][x + dx] != INK
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    img[y][x] = INK
    # highlight: the top-left-most opaque non-ink pixel turns Ivory (skip if the icon is already Ivory)
    for y in range(S):
        for x in range(S):
            p = img[y][x]
            if p[3] and p != INK and p != IVORY:
                img[y][x] = IVORY
                return img
    return img

def box(x0, y0, x1, y1): return [(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)]
def diag(x0, y0, n, dx=1, dy=1, w=2):  # 45-degree stepped stroke, w px thick
    pts = []
    for i in range(n):
        for k in range(w):
            pts.append((x0 + i * dx + k, y0 + i * dy))
    return pts

ORANGE, BLUE, ICE, MAGENTA, GOLD, STEEL, GREEN = c('#FF7A1F'), c('#3A5CF0'), c('#A6EEFF'), c('#E04CD0'), c('#FFD45C'), c('#8FA3B8'), c('#58D468')
icons = [
    ('pause', icon([(IVORY, box(2, 1, 4, 10) + box(7, 1, 9, 10))])),
    ('low_hp', icon([(IVORY, box(5, 1, 6, 7) + box(5, 9, 6, 10))])),
    ('check', icon([(IVORY, diag(2, 6, 3, 1, 1) + diag(5, 8, 1) + diag(6, 7, 4, 1, -1))], outline=True)),
    ('cross', icon([(IVORY, diag(2, 2, 8) + diag(2, 9, 8, 1, -1))], outline=True)),
    # rotate: a 2 px ring open at the top-left, the open end capped by a stepped arrowhead pointing down
    ('rotate', icon([(IVORY, box(4, 1, 9, 2) + box(8, 1, 9, 10) + box(2, 9, 9, 10) + box(2, 6, 3, 10) + box(0, 4, 5, 4) + box(1, 5, 4, 5))])),
    ('armor', icon([(STEEL, box(2, 1, 9, 6) + box(3, 7, 8, 8) + box(4, 9, 7, 9) + box(5, 10, 6, 10))])),
    ('burn', icon([(ORANGE, box(5, 1, 6, 2) + box(4, 3, 7, 4) + box(3, 5, 8, 7) + box(2, 8, 9, 10) + box(4, 9, 7, 10))])),
    ('fragile', icon([(IVORY, box(2, 1, 9, 10)), (INK, diag(3, 2, 3) + [(6, 5), (6, 6)] + diag(6, 7, 3))])),
    ('chill', icon([(BLUE, box(5, 1, 6, 10) + box(1, 5, 10, 6) + [(2, 2), (9, 2), (2, 9), (9, 9), (3, 3), (8, 3), (3, 8), (8, 8)])])),
    ('frozen', icon([(ICE, box(2, 3, 9, 10)), (BLUE, box(2, 3, 9, 3) + box(2, 3, 2, 10))])),
    ('cloud', icon([(MIST, box(3, 4, 8, 5) + box(1, 6, 10, 9))])),
    ('odd', icon([(MAGENTA, box(5, 1, 6, 10) + box(1, 5, 10, 6) + box(4, 4, 7, 7))])),
    ('plus', icon([(MIST, box(5, 2, 6, 9) + box(2, 5, 9, 6))])),
    ('info', icon([(IVORY, box(5, 1, 6, 2) + box(5, 4, 6, 10))])),
    ('awakening', icon([(MIST, box(1, 1, 5, 5) + box(1, 7, 5, 11) + box(7, 7, 11, 11)), (GOLD, box(7, 1, 11, 5))])),
    ('arrow_up', icon([(IVORY, box(5, 1, 6, 2) + box(4, 3, 7, 4) + box(3, 5, 8, 6) + box(5, 7, 6, 10))])),
    ('arrow_down', icon([(IVORY, box(5, 1, 6, 4) + box(3, 5, 8, 6) + box(4, 7, 7, 8) + box(5, 9, 6, 10))])),
    ('arrow_left', icon([(IVORY, box(1, 5, 2, 6) + box(3, 4, 4, 7) + box(5, 3, 6, 8) + box(7, 5, 10, 6))])),
    ('arrow_right', icon([(IVORY, box(1, 5, 4, 6) + box(5, 3, 6, 8) + box(7, 4, 8, 7) + box(9, 5, 10, 6))])),
    ('coin', icon([(GOLD, box(3, 2, 8, 9) + box(2, 3, 9, 8)), (INK, box(5, 4, 6, 7))])),
    ('heart', icon([(IVORY, box(2, 2, 4, 4) + box(7, 2, 9, 4) + box(1, 3, 10, 6) + box(2, 7, 9, 7) + box(3, 8, 8, 8) + box(4, 9, 7, 9) + box(5, 10, 6, 10))])),
]
cols, rows, gut = 7, 3, 1
W, H = cols * S + (cols - 1) * gut, rows * S + (rows - 1) * gut
sheet = blank(W, H)
index = {}
for i, (name, img) in enumerate(icons):
    cx, cy = (i % cols) * (S + gut), (i // cols) * (S + gut)
    for y in range(S):
        for x in range(S):
            sheet[cy + y][cx + x] = img[y][x]
    index[name] = [cx, cy, S, S]

out = sys.argv[1]
write_png(f'{out}/ASSET-013-ui_frame_panel_9slice.png', 16, 16, panel())
write_png(f'{out}/ASSET-013-ui_frame_button_9slice.png', 48, 16, btn)
write_png(f'{out}/ASSET-013-ui_frame_slot_9slice.png', 16, 16, slot)
write_png(f'{out}/ASSET-013-ui_frame_bar_3slice.png', 16, 8, bar)
write_png(f'{out}/ASSET-015-ui_icons_12.png', W, H, sheet)
json.dump({"cell": S, "gutter": gut, "icons": index,
           "nine_slice": {"panel": [4, 4, 4, 6], "button": [4, 4, 4, 6], "slot": [3, 3, 3, 3], "bar_ends": 2}},
          open(f'{out}/ASSET-015-ui_icons_12.json', 'w'), indent=2)
# previews x8 on a mid background
k = 8; bg = (74, 70, 64, 255)
for name, img, w, h in (('panel', panel(), 16, 16), ('button', btn, 48, 16), ('slot', slot, 16, 16), ('bar', bar, 16, 8), ('icons', sheet, W, H)):
    big = [[(img[y // k][x // k] if img[y // k][x // k][3] else bg) for x in range(w * k)] for y in range(h * k)]
    write_png(f'{out}/preview-{name}-x8.png', w * k, h * k, big)
print(f'ui written: icons {len(icons)} sheet {W}x{H}')
