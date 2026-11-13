"""Print tessera_master.gpl as a palette PNG for create_image_pixflux's color_image_base64.

Card-art Master Reference (design/assets/references/ui/card-art.md) §5. Standard library only (no Pillow).
Writes nothing to disk: the PNG (one pixel per palette row, 1 px high) goes to stdout as base64.
Usage: python -X utf8 -I design/assets/candidates/ui/card-art/scripts/gpl_swatch.py [--count] [--only "#1B1722,#8FA3B8,..."]
--only keeps just those colours (the per-card subset of Master Reference §4.3); every one must be a gpl row,
otherwise the script exits with an error naming it.
"""
import base64
import re
import struct
import sys
import zlib

GPL = "art_src/palette/tessera_master.gpl"


def colours(path=GPL):
    out = []
    for line in open(path, encoding="utf-8"):
        m = re.match(r"\s*(\d+)\s+(\d+)\s+(\d+)\s", line)
        if m:
            rgb = tuple(int(v) for v in m.groups())
            if rgb not in out:
                out.append(rgb)
    return out


def png(rgbs):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    row = b"\x00" + b"".join(bytes(c) for c in rgbs)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", len(rgbs), 1, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(row)) + chunk(b"IEND", b""))


if __name__ == "__main__":
    cols = colours()
    if "--only" in sys.argv:
        want = [h.strip().upper() for h in sys.argv[sys.argv.index("--only") + 1].split(",") if h.strip()]
        known = {"#%02X%02X%02X" % c: c for c in cols}
        missing = [h for h in want if h not in known]
        if missing:
            sys.exit("not in %s: %s" % (GPL, ", ".join(missing)))
        cols = [known[h] for h in want]
    if "--count" in sys.argv:
        print(len(cols), " ".join("#%02X%02X%02X" % c for c in cols))
    else:
        print(base64.b64encode(png(cols)).decode("ascii"))
