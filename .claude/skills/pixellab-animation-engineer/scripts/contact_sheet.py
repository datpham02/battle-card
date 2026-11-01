"""Lay animation frames side by side, enlarged with nearest-neighbour, for review.

Standard library only.
Usage:
  python contact_sheet.py --frames DIR|a.png,b.png --out sheet.png [--scale 4]
                          [--cols 0] [--gutter 2] [--bg 3a3b37] [--skip-first]
  --cols 0 puts every frame in one row. Frames of different sizes are top-left
  aligned in cells of the largest size. Transparent pixels show the --bg colour.
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngio import read_png, write_png  # noqa: E402


def natural_key(path):
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", os.path.basename(path))]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--frames", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--scale", type=int, default=4)
    ap.add_argument("--cols", type=int, default=0)
    ap.add_argument("--gutter", type=int, default=2)
    ap.add_argument("--bg", default="3a3b37")
    ap.add_argument("--skip-first", action="store_true")
    a = ap.parse_args()
    if os.path.isdir(a.frames):
        paths = sorted((os.path.join(a.frames, f) for f in os.listdir(a.frames)
                        if f.lower().endswith(".png") and f not in ("sheet.png", "contact.png")), key=natural_key)
    else:
        paths = [p.strip() for p in a.frames.split(",") if p.strip()]
    if a.skip_first:
        paths = paths[1:]
    if not paths:
        print("contact_sheet: no frames")
        return 2
    imgs = [read_png(p) for p in paths]
    cw = max(i[0] for i in imgs)
    ch = max(i[1] for i in imgs)
    cols = a.cols if a.cols > 0 else len(imgs)
    rows = (len(imgs) + cols - 1) // cols
    s, g = max(1, a.scale), max(0, a.gutter)
    bg = tuple(int(a.bg[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
    gut = (16, 14, 20, 255)
    W = cols * cw * s + (cols + 1) * g
    H = rows * ch * s + (rows + 1) * g
    canvas = [[gut] * W for _ in range(H)]
    for k, (w, h, px) in enumerate(imgs):
        ox = g + (k % cols) * (cw * s + g)
        oy = g + (k // cols) * (ch * s + g)
        for y in range(ch * s):
            row = canvas[oy + y]
            sy = y // s
            for x in range(cw * s):
                sx = x // s
                if sy < h and sx < w and px[sy][sx][3] > 0:
                    p = px[sy][sx]
                    al = p[3] / 255.0
                    row[ox + x] = (round(p[0] * al + bg[0] * (1 - al)), round(p[1] * al + bg[1] * (1 - al)),
                                   round(p[2] * al + bg[2] * (1 - al)), 255)
                else:
                    row[ox + x] = bg
    write_png(a.out, W, H, canvas)
    print("contact_sheet: %d frames -> %s (%dx%d)" % (len(imgs), a.out, W, H))
    return 0


if __name__ == "__main__":
    sys.exit(main())
