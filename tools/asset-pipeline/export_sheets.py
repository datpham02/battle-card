#!/usr/bin/env python3
"""Export the unit sprite sheets of art bible §8.1 from loose PNG frames.

Pure Python 3 (stdlib only, no Pillow). Run from anywhere:

    python -X utf8 -I tools/asset-pipeline/export_sheets.py            # write sheets
    python -X utf8 -I tools/asset-pipeline/export_sheets.py --check    # CI: compare, exit 1 on drift
    python -X utf8 -I tools/asset-pipeline/export_sheets.py --units kiem_si

Input, per unit `<id>` (Story 045, the user's 2026-10-31 decision: loose PNGs
stand in for the `.aseprite` source until an artist works in Aseprite):

    art_src/units/<id>/clips.json        clip order, frame files, ms per frame, loop kind
    art_src/units/<id>/<clip>/<n>.png    one RGBA frame per file, all the unit's frame size
    art_src/palette/tessera_master.gpl   every opaque colour a frame may use

Output, in the Aseprite "array" JSON layout so the engine never knows the
source was not Aseprite:

    assets/art/units/unit_<id>_sheet.png   one row per clip, fixed cells, 1 px gutter
    assets/art/units/unit_<id>_sheet.json  frames[] + meta.frameTags[] + meta.tessera

Rules enforced (an error aborts the export with exit 2):
  * every frame is <frame.w> x <frame.h>, 8-bit, non-interlaced
  * alpha is only 0 or 255; every opaque colour is in the palette;
    at most MAX_COLOURS distinct opaque colours per unit (§8.9 #4)
  * the left, right and top 1 px edge of every frame is transparent (§8.3;
    the bottom row is the foot-contact row and may be opaque), which is what
    keeps the sheet's side edges and the gutters clear at the 81x391 / 65x244
    sizes the story fixes (gutter between cells, the frame margin at the edge)
  * clips.json lists one ms value per frame and a loop kind of
    loop | once | hold_last | hold

The output is deterministic: fixed chunk order, filter-0 rows, zlib level 9,
no timestamp, JSON in insertion order with LF newlines.
"""
from __future__ import annotations

import argparse
import json
import struct
import sys
import zlib
from pathlib import Path

GUTTER = 1
MAX_COLOURS = 8
LOOP_KINDS = ("loop", "once", "hold_last", "hold")
FACINGS = ("right", "left")
PNG_SIG = b"\x89PNG\r\n\x1a\n"


class ExportError(Exception):
    """A rule of the pipeline was broken; the message says where."""


# --------------------------------------------------------------------------- PNG


def read_png(path: Path) -> tuple[int, int, list[list[tuple[int, int, int, int]]]]:
    """Decode an 8-bit non-interlaced PNG into rows of (r, g, b, a) tuples."""
    data = path.read_bytes()
    if data[:8] != PNG_SIG:
        raise ExportError(f"{path}: not a PNG")
    pos = 8
    idat = b""
    plte = trns = None
    w = h = bd = ct = il = None
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos : pos + 4])
        kind = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            w, h, bd, ct, _, _, il = struct.unpack(">IIBBBBB", chunk)
        elif kind == b"PLTE":
            plte = chunk
        elif kind == b"tRNS":
            trns = chunk
        elif kind == b"IDAT":
            idat += chunk
    if w is None:
        raise ExportError(f"{path}: no IHDR")
    if bd != 8 or il != 0:
        raise ExportError(f"{path}: only 8-bit non-interlaced PNG is supported (bit depth {bd}, interlace {il})")
    bpp = {6: 4, 2: 3, 3: 1, 0: 1, 4: 2}[ct]
    raw = zlib.decompress(idat)
    stride = w * bpp
    rows: list[list[tuple[int, int, int, int]]] = []
    prev = bytearray(stride)
    i = 0
    for _ in range(h):
        f = raw[i]
        i += 1
        cur = bytearray(raw[i : i + stride])
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
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                cur[x] = (cur[x] + pr) & 255
        line: list[tuple[int, int, int, int]] = []
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


def encode_png(w: int, h: int, rows: list[bytearray]) -> bytes:
    """Encode RGBA8 rows (w*4 bytes each) deterministically: IHDR, IDAT, IEND only."""

    def chunk(kind: bytes, body: bytes) -> bytes:
        crc = zlib.crc32(kind + body) & 0xFFFFFFFF
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", crc)

    raw = b"".join(b"\x00" + bytes(r) for r in rows)
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    return PNG_SIG + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


# ------------------------------------------------------------------------ inputs


def read_palette(path: Path) -> dict[str, str]:
    """GIMP .gpl -> {'#RRGGBB': name}. Rows are 'R G B <tab> name'; # lines are comments."""
    if not path.is_file():
        raise ExportError(f"palette missing: {path}")
    colours: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        parts = s.split(None, 3)
        if len(parts) < 3 or not all(p.isdigit() for p in parts[:3]):
            continue  # header lines: GIMP Palette, Name:, Columns:
        r, g, b = (int(p) for p in parts[:3])
        key = f"#{r:02X}{g:02X}{b:02X}"
        colours[key] = parts[3] if len(parts) > 3 else key
    if not colours:
        raise ExportError(f"palette has no colour rows: {path}")
    return colours


def read_clips(unit_dir: Path) -> dict:
    """Load and validate art_src/units/<id>/clips.json."""
    path = unit_dir / "clips.json"
    if not path.is_file():
        raise ExportError(f"clips.json missing: {path}")
    spec = json.loads(path.read_text(encoding="utf-8"))
    for key in ("id", "frame", "facing", "clips"):
        if key not in spec:
            raise ExportError(f"{path}: missing key '{key}'")
    if spec["id"] != unit_dir.name:
        raise ExportError(f"{path}: id '{spec['id']}' does not match folder '{unit_dir.name}'")
    if spec["facing"] not in FACINGS:
        raise ExportError(f"{path}: facing must be one of {FACINGS}")
    names: set[str] = set()
    for clip in spec["clips"]:
        for key in ("name", "frames", "ms", "loop"):
            if key not in clip:
                raise ExportError(f"{path}: clip {clip.get('name', '?')} missing '{key}'")
        name = clip["name"]
        if name in names:
            raise ExportError(f"{path}: duplicate clip '{name}'")
        names.add(name)
        if not clip["frames"]:
            raise ExportError(f"{path}: clip '{name}' has no frames")
        if len(clip["ms"]) != len(clip["frames"]):
            raise ExportError(f"{path}: clip '{name}' needs one ms per frame")
        if clip["loop"] not in LOOP_KINDS:
            raise ExportError(f"{path}: clip '{name}' loop must be one of {LOOP_KINDS}")
        if any((not isinstance(m, int)) or m < 0 for m in clip["ms"]):
            raise ExportError(f"{path}: clip '{name}' ms must be non-negative integers")
    return spec


# ------------------------------------------------------------------------ export


def build_unit(unit_dir: Path, palette: dict[str, str]) -> tuple[str, bytes, str]:
    """Return (unit id, sheet png bytes, sheet json text) for one unit folder."""
    spec = read_clips(unit_dir)
    uid = spec["id"]
    fw, fh = int(spec["frame"]["w"]), int(spec["frame"]["h"])
    clips = spec["clips"]
    cols = max(len(c["frames"]) for c in clips)
    rows = len(clips)
    sw = cols * fw + (cols - 1) * GUTTER
    sh = rows * fh + (rows - 1) * GUTTER

    sheet = [bytearray(sw * 4) for _ in range(sh)]
    colours: set[str] = set()
    frames_json: list[dict] = []
    tags_json: list[dict] = []
    loops: dict[str, str] = {}
    index = 0
    for row, clip in enumerate(clips):
        first = index
        for col, (rel, ms) in enumerate(zip(clip["frames"], clip["ms"])):
            fpath = unit_dir / rel
            if not fpath.is_file():
                raise ExportError(f"{uid}/{clip['name']}: frame missing: {fpath}")
            w, h, px = read_png(fpath)
            if (w, h) != (fw, fh):
                raise ExportError(f"{fpath}: is {w}x{h}, unit frame is {fw}x{fh}")
            ox = col * (fw + GUTTER)
            oy = row * (fh + GUTTER)
            for y in range(fh):
                line = sheet[oy + y]
                for x in range(fw):
                    r, g, b, a = px[y][x]
                    if a not in (0, 255):
                        raise ExportError(f"{fpath}: alpha {a} at ({x},{y}); only 0 or 255 allowed")
                    if a == 0:
                        continue  # stays (0,0,0,0)
                    if x == 0 or y == 0 or x == fw - 1:
                        # The bottom row is exempt: feet touch the last pixel row (art bible 8.3).
                        raise ExportError(f"{fpath}: opaque pixel on the frame edge at ({x},{y}); art bible 8.3 needs a 1 px margin left, right and top")
                    key = f"#{r:02X}{g:02X}{b:02X}"
                    if key not in palette:
                        raise ExportError(f"{fpath}: colour {key} at ({x},{y}) is not in the palette")
                    colours.add(key)
                    base = (ox + x) * 4
                    line[base] = r
                    line[base + 1] = g
                    line[base + 2] = b
                    line[base + 3] = 255
            frames_json.append(
                {
                    "filename": f"{uid}_{clip['name']}_{col}",
                    "frame": {"x": ox, "y": oy, "w": fw, "h": fh},
                    "rotated": False,
                    "trimmed": False,
                    "spriteSourceSize": {"x": 0, "y": 0, "w": fw, "h": fh},
                    "sourceSize": {"w": fw, "h": fh},
                    "duration": ms,
                }
            )
            index += 1
        tags_json.append({"name": clip["name"], "from": first, "to": index - 1, "direction": "forward"})
        loops[clip["name"]] = clip["loop"]
    if len(colours) > MAX_COLOURS:
        raise ExportError(f"{uid}: {len(colours)} opaque colours, limit {MAX_COLOURS}: {sorted(colours)}")

    png = encode_png(sw, sh, sheet)
    doc = {
        "frames": frames_json,
        "meta": {
            "app": "tools/asset-pipeline/export_sheets.py",
            "version": "1.0",
            "image": f"unit_{uid}_sheet.png",
            "format": "RGBA8888",
            "size": {"w": sw, "h": sh},
            "scale": "1",
            "frameTags": tags_json,
            "layers": [{"name": "unit", "opacity": 255, "blendMode": "normal"}],
            "slices": [],
            "tessera": {
                "unit": uid,
                "asset": spec.get("asset", ""),
                "facing": spec["facing"],
                "frame": {"w": fw, "h": fh},
                "gutter": GUTTER,
                "columns": cols,
                "loop": loops,
                "palette": sorted(colours),
            },
        },
    }
    text = json.dumps(doc, ensure_ascii=False, indent=2) + "\n"
    return uid, png, text


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--check", action="store_true", help="compare with the committed files instead of writing; exit 1 on drift")
    ap.add_argument("--units", default="", help="comma-separated unit ids (default: every folder under art_src/units)")
    ap.add_argument("--root", default="", help="repo root (default: two levels above this script)")
    args = ap.parse_args(argv)

    root = Path(args.root).resolve() if args.root else Path(__file__).resolve().parents[2]
    src_root = root / "art_src" / "units"
    out_root = root / "assets" / "art" / "units"
    palette_path = root / "art_src" / "palette" / "tessera_master.gpl"

    try:
        palette = read_palette(palette_path)
        if args.units:
            unit_dirs = [src_root / u.strip() for u in args.units.split(",") if u.strip()]
        else:
            unit_dirs = sorted(p for p in src_root.iterdir() if p.is_dir())
        if not unit_dirs:
            raise ExportError(f"no unit folders under {src_root}")
        drift = 0
        for unit_dir in unit_dirs:
            if not unit_dir.is_dir():
                raise ExportError(f"unit folder missing: {unit_dir}")
            uid, png, text = build_unit(unit_dir, palette)
            png_path = out_root / f"unit_{uid}_sheet.png"
            json_path = out_root / f"unit_{uid}_sheet.json"
            size = json.loads(text)["meta"]["size"]
            if args.check:
                for path, want in ((png_path, png), (json_path, text.encode("utf-8"))):
                    rel = path.relative_to(root).as_posix()
                    have = path.read_bytes() if path.is_file() else None
                    if have is None:
                        print(f"MISSING  {rel}")
                        drift += 1
                    elif have != want:
                        print(f"DRIFT    {rel} (committed {len(have)} B, fresh {len(want)} B)")
                        drift += 1
                    else:
                        print(f"ok       {rel}")
            else:
                out_root.mkdir(parents=True, exist_ok=True)
                png_path.write_bytes(png)
                json_path.write_bytes(text.encode("utf-8"))
                print(f"wrote    {png_path.relative_to(root).as_posix()} {size['w']}x{size['h']} + .json")
        if args.check and drift:
            print(f"export_sheets --check: {drift} file(s) differ; run the exporter and commit the result", file=sys.stderr)
            return 1
        return 0
    except ExportError as err:
        print(f"export_sheets: {err}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
