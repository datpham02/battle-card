"""Check every assets/art/cards/*.png against the card-art Master Reference (design/assets/references/ui/card-art.md).

Read-only. Prints one line per file: size, alpha, background #2C2A35 in the 2 px margin, colours in tessera_master.gpl,
Ink edge around the subject (subject = pixels that are not the background colour).
Usage (repo root): python -X utf8 -I design/assets/candidates/ui/card-art/scripts/audit_installed.py
"""
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import card_qa  # noqa: E402

pal = set(card_qa.gpl())
rows = []
for path in sorted(glob.glob("assets/art/cards/*.png")):
    w, h, ct, px = card_qa.read_png(path)
    cid = os.path.basename(path)[:-4]
    alpha_ok = all(p[3] == 255 for p in px)
    margin = [px[y * w + x][:3] for y in range(h) for x in range(w) if x < 2 or y < 2 or x >= w - 2 or y >= h - 2]
    bg_ok = all(c == card_qa.BG for c in margin)
    off = sorted({card_qa.hx(p) for p in px if p[:3] not in pal})
    subj = lambda x, y: 0 <= x < w and 0 <= y < h and px[y * w + x][:3] != card_qa.BG
    edge = [(x, y) for y in range(h) for x in range(w) if subj(x, y) and not all(subj(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    ink = sum(1 for x, y in edge if px[y * w + x][:3] == card_qa.INK)
    ink_pct = 100 * ink // max(1, len(edge))
    ok = (w, h) == (32, 32) and alpha_ok and bg_ok and not off and ink_pct == 100
    rows.append(ok)
    print("%-13s %s size=%dx%d alpha255=%s margin_bg=%s off_gpl=%d ink_edge=%d%%%s" % (
        cid, "PASS" if ok else "FAIL", w, h, alpha_ok, bg_ok, len(off), ink_pct, (" " + ",".join(off[:4])) if off else ""))
print("%d files, %d pass, %d fail" % (len(rows), sum(rows), len(rows) - sum(rows)))
