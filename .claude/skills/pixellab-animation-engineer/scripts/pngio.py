"""Minimal PNG read/write with the Python standard library only (no Pillow).

read_png(path) -> (width, height, pixels) where pixels[y][x] = (r, g, b, a), 0-255.
Supports 8-bit greyscale, grey+alpha, RGB, RGBA and palette (with tRNS) PNGs,
non-interlaced. Raises PngError with a reason for anything else, so callers can
report the check as NOT RUN instead of guessing.
write_png(path, width, height, pixels) writes 8-bit RGBA.
"""
import struct
import zlib


class PngError(Exception):
    pass


def read_png(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise PngError("not a PNG file")
    pos, idat, pal, trns = 8, b"", None, None
    w = h = depth = ctype = interlace = None
    while pos < len(data):
        n, tag = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + n]
        pos += 12 + n
        if tag == b"IHDR":
            w, h, depth, ctype, _c, _f, interlace = struct.unpack(">IIBBBBB", body)
        elif tag == b"PLTE":
            pal = [tuple(body[i:i + 3]) for i in range(0, len(body), 3)]
        elif tag == b"tRNS":
            trns = list(body)
        elif tag == b"IDAT":
            idat += body
        elif tag == b"IEND":
            break
    if w is None:
        raise PngError("no IHDR chunk")
    if depth != 8:
        raise PngError("bit depth %d not supported (8 only)" % depth)
    if interlace:
        raise PngError("interlaced PNG not supported")
    bpp = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(ctype)
    if bpp is None:
        raise PngError("colour type %d not supported" % ctype)
    if ctype == 3 and pal is None:
        raise PngError("palette PNG without PLTE")
    raw = zlib.decompress(idat)
    stride = w * bpp
    prev = bytearray(stride)
    rows = []
    i = 0
    for _y in range(h):
        ftype = raw[i]
        line = bytearray(raw[i + 1:i + 1 + stride])
        i += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if ftype == 1:
                line[x] = (line[x] + a) & 255
            elif ftype == 2:
                line[x] = (line[x] + b) & 255
            elif ftype == 3:
                line[x] = (line[x] + ((a + b) >> 1)) & 255
            elif ftype == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else (b if pb <= pc else c))) & 255
        rows.append(line)
        prev = line
    px = []
    for y in range(h):
        r = rows[y]
        out = []
        for x in range(w):
            if ctype == 6:
                out.append(tuple(r[x * 4:x * 4 + 4]))
            elif ctype == 2:
                out.append(tuple(r[x * 3:x * 3 + 3]) + (255,))
            elif ctype == 0:
                v = r[x]
                out.append((v, v, v, 255))
            elif ctype == 4:
                v, al = r[x * 2], r[x * 2 + 1]
                out.append((v, v, v, al))
            else:
                k = r[x]
                rgb = pal[k] if k < len(pal) else (0, 0, 0)
                al = trns[k] if trns is not None and k < len(trns) else 255
                out.append(rgb + (al,))
        px.append(out)
    return w, h, px


def write_png(path, w, h, px):
    raw = b"".join(b"\x00" + bytes(v for p in row for v in p) for row in px)

    def chunk(tag, body):
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n"
                + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9))
                + chunk(b"IEND", b""))
