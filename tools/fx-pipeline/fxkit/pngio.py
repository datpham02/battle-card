"""Read and write 8-bit PNG without Pillow.

Colours inside fxkit are ints: 0 = transparent, otherwise 0xFF000000 | 0xRRGGBB (alpha is 0 or 255 only).
`read_png` returns RGBA tuples so a checker can see any alpha a foreign file holds.
The decoder follows tools/asset-pipeline/export_sheets.py (8-bit, non-interlaced, all filter types).
"""
from __future__ import annotations

import struct
import zlib
from pathlib import Path

PNG_SIG = b"\x89PNG\r\n\x1a\n"


class PngError(Exception):
    """The file is not a PNG this module can read."""


def read_png(path: Path | str) -> tuple[int, int, list[list[tuple[int, int, int, int]]]]:
    """Decode an 8-bit non-interlaced PNG into rows of (r, g, b, a)."""
    data = Path(path).read_bytes()
    if data[:8] != PNG_SIG:
        raise PngError(f"{path}: not a PNG")
    pos, idat, plte, trns = 8, b"", None, None
    w = h = bd = ct = il = None
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        kind = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            w, h, bd, ct, _, _, il = struct.unpack(">IIBBBBB", chunk)
        elif kind == b"PLTE":
            plte = chunk
        elif kind == b"tRNS":
            trns = chunk
        elif kind == b"IDAT":
            idat += chunk
    if w is None or bd != 8 or il != 0:
        raise PngError(f"{path}: only 8-bit non-interlaced PNG is supported")
    bpp = {6: 4, 2: 3, 3: 1, 0: 1, 4: 2}[ct]
    raw = zlib.decompress(idat)
    stride = w * bpp
    rows: list[list[tuple[int, int, int, int]]] = []
    prev = bytearray(stride)
    i = 0
    for _ in range(h):
        f = raw[i]
        i += 1
        cur = bytearray(raw[i:i + stride])
        i += stride
        for x in range(stride):
            a = cur[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1:
                cur[x] = (cur[x] + a) & 255
            elif f == 2:
                cur[x] = (cur[x] + b) & 255
            elif f == 3:
                cur[x] = (cur[x] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                cur[x] = (cur[x] + (a if pa <= pb and pa <= pc else (b if pb <= pc else c))) & 255
        line = []
        for x in range(w):
            if ct == 6:
                line.append((cur[x * 4], cur[x * 4 + 1], cur[x * 4 + 2], cur[x * 4 + 3]))
            elif ct == 2:
                line.append((cur[x * 3], cur[x * 3 + 1], cur[x * 3 + 2], 255))
            elif ct == 3:
                idx = cur[x]
                alpha = trns[idx] if trns and idx < len(trns) else 255
                line.append((plte[idx * 3], plte[idx * 3 + 1], plte[idx * 3 + 2], alpha))
            elif ct == 0:
                line.append((cur[x], cur[x], cur[x], 255))
            else:
                line.append((cur[x * 2], cur[x * 2], cur[x * 2], cur[x * 2 + 1]))
        rows.append(line)
        prev = cur
    return w, h, rows


def to_ints(rows: list[list[tuple[int, int, int, int]]]) -> list[int]:
    """RGBA rows -> fxkit colour ints (alpha below 128 becomes transparent)."""
    out = []
    for line in rows:
        for r, g, b, a in line:
            out.append(0 if a < 128 else (0xFF000000 | (r << 16) | (g << 8) | b))
    return out


def load_image(path: Path | str) -> tuple[int, int, list[int]]:
    """A PNG as (w, h, colour ints)."""
    w, h, rows = read_png(path)
    return w, h, to_ints(rows)


def encode_png(w: int, h: int, pixels: list[int]) -> bytes:
    """Encode colour ints as RGBA8, deterministically (IHDR, IDAT, IEND; filter 0; zlib level 9)."""
    def chunk(kind: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for c in pixels[y * w:(y + 1) * w]:
            if c:
                raw += bytes(((c >> 16) & 255, (c >> 8) & 255, c & 255, 255))
            else:
                raw += b"\x00\x00\x00\x00"
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    return PNG_SIG + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")


def write_png(path: Path | str, w: int, h: int, pixels: list[int]) -> Path:
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(encode_png(w, h, pixels))
    return p
