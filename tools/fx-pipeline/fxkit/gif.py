"""Animated GIF writer (GIF89a, global palette, loops forever), pure Python.

Same output family as prototypes/art-check/tools/make_gif.py, with a faster LZW (integer keys) and identical
consecutive frames merged into one longer delay.
"""
from __future__ import annotations

import struct
from pathlib import Path


def _lzw(indices: list[int], min_code: int) -> bytes:
    clear, eoi = 1 << min_code, (1 << min_code) + 1
    table: dict[int, int] = {}
    nxt, size = eoi + 1, min_code + 1
    out = bytearray()
    acc = nbits = 0

    def emit(code: int, bits: int) -> None:
        nonlocal acc, nbits
        acc |= code << nbits
        nbits += bits
        while nbits >= 8:
            out.append(acc & 0xFF)
            acc >>= 8
            nbits -= 8

    emit(clear, size)
    prefix = -1
    for k in indices:
        if prefix < 0:
            prefix = k
            continue
        key = (prefix << 8) | k
        code = table.get(key)
        if code is not None:
            prefix = code
            continue
        emit(prefix, size)
        if nxt < 4096:
            table[key] = nxt
            nxt += 1
            if nxt - 1 == (1 << size) and size < 12:
                size += 1
        else:
            emit(clear, size)
            table.clear()
            nxt, size = eoi + 1, min_code + 1
        prefix = k
    if prefix >= 0:
        emit(prefix, size)
    emit(eoi, size)
    if nbits:
        out.append(acc & 0xFF)
    return bytes(out)


def write_gif(path: Path | str, w: int, h: int, frames: list[list[int]], delays_cs: list[int]) -> Path:
    """frames: opaque colour ints (0 is drawn as black). delays in centiseconds (>= 2)."""
    merged: list[list[int]] = []
    delays: list[int] = []
    for fr, d in zip(frames, delays_cs):
        if merged and fr == merged[-1]:
            delays[-1] += d
        else:
            merged.append(fr)
            delays.append(d)
    palette: list[int] = []
    index: dict[int, int] = {}
    for fr in merged:
        for c in fr:
            if c not in index:
                index[c] = len(palette)
                palette.append(c)
    if len(palette) > 256:
        raise ValueError(f"{path}: {len(palette)} colours, a GIF holds 256")
    bits = max(1, (len(palette) - 1).bit_length())
    gif = bytearray(b"GIF89a")
    gif += struct.pack("<HHBBB", w, h, 0x80 | ((bits - 1) << 4) | (bits - 1), 0, 0)
    for i in range(1 << bits):
        c = palette[i] if i < len(palette) else 0
        gif += bytes(((c >> 16) & 255, (c >> 8) & 255, c & 255))
    gif += b"\x21\xFF\x0BNETSCAPE2.0\x03\x01\x00\x00\x00"
    min_code = max(2, bits)
    for fr, d in zip(merged, delays):
        gif += b"\x21\xF9\x04\x00" + struct.pack("<H", max(2, d)) + b"\x00\x00"
        gif += b"\x2C" + struct.pack("<HHHHB", 0, 0, w, h, 0)
        gif.append(min_code)
        data = _lzw([index[c] for c in fr], min_code)
        for i in range(0, len(data), 255):
            part = data[i:i + 255]
            gif.append(len(part))
            gif += part
        gif.append(0)
    gif += b"\x3B"
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(bytes(gif))
    return p
