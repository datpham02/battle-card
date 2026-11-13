"""Card-art batch helper: prompts, palette swatches, mechanical post-process and QA (Master Reference §4.3, §8, §9).

Standard library only (no Pillow). Reads design/assets/candidates/ui/card-art/batch3/prompts.json.

  card_qa.py validate                 check every subset against the gpl and the §4.3 rules
  card_qa.py call <id>                print the description and the colour-image base64 for one card
  card_qa.py qa <id> <raw.png> <out>  §8 steps 4,1 (Ink edge recolour, background fill) then QA; JSON report on stdout,
                                      exit 1 when a check fails. Never rounds alpha, never snaps colours.
  card_qa.py sheet <out.png> <scale> <png> [<png> ...]          side-by-side preview
  card_qa.py silhouette <out.png> <scale> <png> [<png> ...]     black-fill preview (background = most common colour)
"""
import base64
import json
import os
import re
import struct
import sys
import zlib
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", "..", "..", ".."))
PROMPTS = os.path.join(ROOT, "design/assets/candidates/ui/card-art/batch3/prompts.json")
GPL = os.path.join(ROOT, "art_src/palette/tessera_master.gpl")
INK = (0x1B, 0x17, 0x22)
BG = (0x2C, 0x2A, 0x35)
SIZE = 32
MARGIN = 2


def gpl():
    out = []
    for line in open(GPL, encoding="utf-8"):
        m = re.match(r"\s*(\d+)\s+(\d+)\s+(\d+)\s", line)
        if m:
            c = tuple(int(v) for v in m.groups())
            if c not in out:
                out.append(c)
    return out


def hx(c):
    return "#%02X%02X%02X" % tuple(c[:3])


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def read_png(path):
    b = open(path, "rb").read()
    i, idat, plte, trns = 8, b"", None, None
    w = h = ct = bd = None
    while i < len(b):
        n, = struct.unpack(">I", b[i:i + 4])
        t, d = b[i + 4:i + 8], b[i + 8:i + 8 + n]
        i += 12 + n
        if t == b"IHDR":
            w, h, bd, ct = struct.unpack(">IIBB", d[:10])
        elif t == b"IDAT":
            idat += d
        elif t == b"PLTE":
            plte = [tuple(d[k:k + 3]) for k in range(0, len(d), 3)]
        elif t == b"tRNS":
            trns = d
    if bd != 8:
        raise SystemExit("%s: bit depth %s unsupported" % (path, bd))
    ch = {6: 4, 2: 3, 3: 1, 4: 2, 0: 1}[ct]
    raw = zlib.decompress(idat)
    stride, prev, o, px = w * ch, bytearray(w * ch), 0, []
    for _y in range(h):
        f = raw[o]
        o += 1
        line = bytearray(raw[o:o + stride])
        o += stride
        for x in range(stride):
            a = line[x - ch] if x >= ch else 0
            up = prev[x]
            c = prev[x - ch] if x >= ch else 0
            if f == 1:
                line[x] = (line[x] + a) & 255
            elif f == 2:
                line[x] = (line[x] + up) & 255
            elif f == 3:
                line[x] = (line[x] + (a + up) // 2) & 255
            elif f == 4:
                pa, pb, pc = abs(up - c), abs(a - c), abs(a + up - 2 * c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else (up if pb <= pc else c))) & 255
        prev = line
        for x in range(w):
            if ct == 6:
                px.append(tuple(line[x * 4:x * 4 + 4]))
            elif ct == 2:
                px.append(tuple(line[x * 3:x * 3 + 3]) + (255,))
            elif ct == 3:
                k = line[x]
                px.append(plte[k] + ((trns[k] if trns and k < len(trns) else 255),))
            elif ct == 4:
                px.append((line[x * 2],) * 3 + (line[x * 2 + 1],))
            else:
                px.append((line[x],) * 3 + (255,))
    return w, h, ct, px


def write_png(path, w, h, px):
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    raw = b"".join(b"\x00" + bytes(v for p in px[y * w:(y + 1) * w] for v in p) for y in range(h))
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                           + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


def swatch(cols):
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    row = b"\x00" + b"".join(bytes(c) for c in cols)
    data = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", len(cols), 1, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(row)) + chunk(b"IEND", b""))
    return base64.b64encode(data).decode("ascii")


def prompts():
    return json.load(open(PROMPTS, encoding="utf-8"))


def validate():
    d, pal = prompts(), set(hx(c) for c in gpl())
    bad = 0
    for cid, c in d["cards"].items():
        cols = c["only"].split(",")
        errs = []
        if cols[0] != "#1B1722":
            errs.append("Ink first")
        if "#2C2A35" in cols:
            errs.append("background colour in subset")
        if len(cols) > 8:
            errs.append(">8 colours")
        errs += ["%s not in gpl" % h for h in cols if h not in pal]
        errs += ["%s named but not in subset" % h for h in set(re.findall(r"#[0-9A-F]{6}", c["colours"])) - set(cols)]
        if errs:
            bad += 1
            print(cid, errs)
    print("%d cards, %d with errors, %d blocked" % (len(d["cards"]), bad, len(d.get("blocked", {}))))
    return bad == 0


def call(cid):
    d = prompts()
    c = d["cards"][cid]
    print(json.dumps({"description": d["template"].format(subject=c["subject"], colours=c["colours"]),
                      "color_image_base64": swatch([rgb(h) for h in c["only"].split(",")])}, ensure_ascii=False))


def qa(cid, raw_path, out_path):
    d = prompts()
    subset = set(rgb(h) for h in d["cards"][cid]["only"].split(","))
    w, h, ct, px = read_png(raw_path)
    rep = {"id": cid, "raw": raw_path, "out": out_path, "checks": {}}
    chk = rep["checks"]
    chk["size_32x32_rgba"] = (w, h, ct) == (SIZE, SIZE, 6)
    alphas = Counter(p[3] for p in px)
    chk["alpha_0_255"] = all(a in (0, 255) for a in alphas)
    if not chk["size_32x32_rgba"] or not chk["alpha_0_255"]:
        rep["pass"] = False
        rep["note"] = "stopped before post-process (size/alpha); alpha is never rounded"
        print(json.dumps(rep))
        return False
    opaque = lambda x, y: 0 <= x < w and 0 <= y < h and px[y * w + x][3] == 255
    new = list(px)
    recoloured = 0
    for y in range(h):
        for x in range(w):
            if opaque(x, y) and not all(opaque(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                if px[y * w + x][:3] != INK:
                    recoloured += 1
                new[y * w + x] = INK + (255,)
    final = [p if p[3] == 255 else BG + (255,) for p in new]
    write_png(out_path, w, h, final)
    subj = [(i % w, i // w) for i, p in enumerate(px) if p[3] == 255]
    xs, ys = [s[0] for s in subj], [s[1] for s in subj]
    rep["bbox"] = [min(xs), min(ys), max(xs), max(ys)] if subj else None
    rep["subject_px"] = len(subj)
    rep["ink_recoloured"] = recoloured
    cols = Counter(p[:3] for p in px if p[3] == 255)
    rep["colours"] = len(cols)
    chk["margin_2px"] = bool(subj) and min(xs) >= MARGIN and min(ys) >= MARGIN and max(xs) <= w - 1 - MARGIN and max(ys) <= h - 1 - MARGIN
    chk["background_exact"] = all(final[y * w + x][:3] == BG for y in range(h) for x in range(w) if px[y * w + x][3] == 0)
    chk["colours_in_subset"] = all(c in subset for c in cols)
    pal = set(gpl())
    chk["colours_in_gpl"] = all(p[:3] in pal for p in final if p[:3] != BG) and BG in pal
    edge = [(x, y) for (x, y) in subj if not all(opaque(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    chk["ink_edge_closed"] = all(final[y * w + x][:3] == INK for x, y in edge)
    chk["subject_size_ok"] = len(subj) >= 120
    rep["off_subset"] = [hx(c) for c in cols if c not in subset]
    rep["pass"] = all(chk.values())
    print(json.dumps(rep))
    return rep["pass"]


def grid(out, scale, paths, mode):
    ims = []
    for p in paths:
        w, h, ct, px = read_png(p)
        if mode == "silhouette":
            if any(a[3] == 0 for a in px):
                px = [(27, 23, 34, 255) if a[3] == 255 else (230, 230, 230, 255) for a in px]
            else:
                bg = Counter(a[:3] for a in px).most_common(1)[0][0]
                px = [(230, 230, 230, 255) if a[:3] == bg else (27, 23, 34, 255) for a in px]
        ims.append((w, h, px))
    g = 6
    W = sum(w * scale + g for w, _, _ in ims) + g
    H = max(h for _, h, _ in ims) * scale + 2 * g
    canvas = [(110, 110, 120, 255)] * (W * H)
    canvas = list(canvas)
    ox = g
    for w, h, px in ims:
        for y in range(h):
            for x in range(w):
                c = px[y * w + x]
                for dy in range(scale):
                    base = (g + y * scale + dy) * W + ox + x * scale
                    for dx in range(scale):
                        canvas[base + dx] = c
        ox += w * scale + g
    write_png(out, W, H, canvas)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "validate":
        sys.exit(0 if validate() else 1)
    if cmd == "call":
        call(sys.argv[2])
    elif cmd == "qa":
        sys.exit(0 if qa(sys.argv[2], sys.argv[3], sys.argv[4]) else 1)
    elif cmd in ("sheet", "silhouette"):
        grid(sys.argv[2], int(sys.argv[3]), sys.argv[4:], cmd)
