#!/usr/bin/env python
"""pixelfx_adapter: turn a PixelFX sprite-sheet export (PNG + Aseprite-style JSON) into a Tessera VfxPack
candidate (`manifest.json` + `whole.png`) that `src/art/vfx_pack.gd` reads and `fxc.py check` judges.

    python -X utf8 -I tools/fx-pipeline/pixelfx_adapter.py adapt <effect>.json [--png <effect>.png] --out <candidate dir>
        [--pack-id ID] [--frame-ms 50] [--frames A:B] [--crop WxH] [--alpha threshold|bayer] [--alpha-cut 128]
        [--layer overlay|floor] [--anchor ground_center|center] [--cell WxH] [--palette <.gpl>] [--ramp name|#hex,...]
        [--origin upstream|adapted|original] [--effect-id ID] [--upstream-commit SHA] [--seed N] [--title TEXT]
    python -X utf8 -I tools/fx-pipeline/pixelfx_adapter.py selftest

What it does, in order (docs/art/PIXELFX_INTEGRATION.md §4):
  1. reads the JSON (`frames[]`, `meta.pixelfx {fps, loop, frameSize, pivot, columns}`) and the sheet PNG;
  2. cuts the frames out, optionally keeps a window (`--frames`) and crops a WxH box around the pivot (`--crop`);
  3. quantises alpha to 0 / 255 (threshold, or a 4x4 Bayer dither of the alpha), snaps every opaque colour to
     the nearest master-palette colour (or to a ramp subset), counts what moved, refuses telegraph red by
     snapping it away;
  4. pads 1 px so no pixel sits on the frame border (the fxkit rule), re-packs a `whole.png` grid with the
     fxkit layout, writes a VfxPack `manifest.json` with `source` provenance and the `index_entry` to add;
  5. runs `fxkit.check.check_pack` on the result and writes `contact.png` + `anim.gif` previews and
     `adapter-report.json`. Exit 1 when the pack FAILs the check; the files stay so you can look.

Pure Python standard library plus fxkit (same folder). Nothing here writes into assets/: the output is a
candidate; installing it is the user's separate, approved step.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import struct
import sys
import tempfile
import zlib
from datetime import date
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from fxkit.check import check_pack, failed, format_findings  # noqa: E402
from fxkit.data import GPL, RAMPS  # noqa: E402
from fxkit.gif import write_gif  # noqa: E402
from fxkit.palette import TELEGRAPH_RED, RED_MIN_DISTANCE, dist, hexc, read_gpl, tohex  # noqa: E402
from fxkit.pngio import read_png, write_png  # noqa: E402
from fxkit.preview import upscale  # noqa: E402
from fxkit.sheet import grid  # noqa: E402

ADAPTER_VERSION = "0.1"
APP = f"pixelfx via tools/fx-pipeline/pixelfx_adapter.py {ADAPTER_VERSION}"
UPSTREAM_REPO = "https://github.com/patch-gg/pixelfx"
BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
GROUND = 0xFF262521


class AdapterError(Exception):
    pass


# ─── input ───────────────────────────────────────────────────────────────────
def load_export(json_path: Path, png_path: Path | None):
    d = json.loads(json_path.read_text(encoding="utf-8"))
    meta = d.get("meta") or {}
    pf = meta.get("pixelfx")
    if not isinstance(pf, dict) or "frameSize" not in pf or "pivot" not in pf:
        raise AdapterError(f"{json_path}: not a pixelfx sheet export (meta.pixelfx with frameSize and pivot expected)")
    if "pixelfx" not in str(meta.get("app", "")):
        raise AdapterError(f"{json_path}: meta.app is {meta.get('app')!r}, not a pixelfx export")
    png_path = png_path or json_path.with_name(meta.get("image") or json_path.with_suffix(".png").name)
    w, h, rows = read_png(png_path)
    frames_meta = d.get("frames") or []
    if not frames_meta:
        raise AdapterError(f"{json_path}: no frames")
    fw, fh = pf["frameSize"]
    frames = []
    for f in frames_meta:
        r = f["frame"]
        if r["w"] != fw or r["h"] != fh:
            raise AdapterError(f"frame {f.get('filename')}: {r['w']}x{r['h']} differs from frameSize {fw}x{fh}")
        if r["x"] + fw > w or r["y"] + fh > h:
            raise AdapterError(f"frame {f.get('filename')}: rect outside the {w}x{h} sheet")
        frames.append([rows[r["y"] + y][r["x"] + x] for y in range(fh) for x in range(fw)])
    durations = sorted({int(f.get("duration", 0)) for f in frames_meta})
    return {
        "effect_id": pf.get("id"), "name": pf.get("name"), "fps": pf.get("fps"), "loop": bool(pf.get("loop")),
        "frame_w": fw, "frame_h": fh, "pivot": [int(pf["pivot"][0]), int(pf["pivot"][1])],
        "columns": pf.get("columns"), "act": pf.get("act"), "durations_ms": durations,
        "frames": frames, "png": str(png_path), "json": str(json_path),
    }


# ─── pixel processing ────────────────────────────────────────────────────────
def window(frames, spec: str | None):
    if not spec:
        return frames, [0, len(frames) - 1]
    a, _, b = spec.partition(":")
    lo = int(a) if a else 0
    hi = int(b) if b else len(frames) - 1
    if lo < 0 or hi >= len(frames) or lo > hi:
        raise AdapterError(f"--frames {spec} outside 0..{len(frames) - 1}")
    return frames[lo:hi + 1], [lo, hi]


def crop(frames, fw, fh, pivot, box: str | None):
    """Keep a cw x ch box centred on the pivot x and bottom-aligned on the pivot y (ground effects) — rows above
    the pivot are kept up to ch - 1, one row below it, so a feet pivot lands on the box's last row - 1."""
    if not box:
        return frames, fw, fh, list(pivot)
    cw, ch = (int(v) for v in box.lower().split("x"))
    px, py = pivot
    x0 = px - cw // 2
    y0 = py - (ch - 2)
    out = []
    for px_ in frames:
        f = [0] * 0
        f = []
        for y in range(ch):
            sy = y0 + y
            for x in range(cw):
                sx = x0 + x
                f.append(px_[sy * fw + sx] if 0 <= sx < fw and 0 <= sy < fh else (0, 0, 0, 0))
        out.append(f)
    return out, cw, ch, [px - x0, py - y0]


def quantise(frames, fw, fh, mode: str, cut: int, master: dict[int, str], ramp: list[int] | None):
    """Alpha -> 0/255, colours -> nearest allowed colour. Returns (frames as colour ints, stats)."""
    allowed = ramp if ramp else [c for c in master]
    if TELEGRAPH_RED in allowed:
        allowed = [c for c in allowed if c != TELEGRAPH_RED]
    cache: dict[int, int] = {}
    stats = {"alpha_dropped": 0, "alpha_kept_translucent": 0, "snapped": 0, "unchanged": 0, "red_avoided": 0,
             "colours_in": set(), "colours_out": set()}

    def nearest(col: int) -> int:
        if col in cache:
            return cache[col]
        best = min(allowed, key=lambda c: dist(c, col))
        if dist(best, TELEGRAPH_RED) < RED_MIN_DISTANCE:
            stats["red_avoided"] += 1
            best = min((c for c in allowed if dist(c, TELEGRAPH_RED) >= RED_MIN_DISTANCE), key=lambda c: dist(c, col))
        cache[col] = best
        return best

    out = []
    for px in frames:
        o = []
        for idx, (r, g, b, a) in enumerate(px):
            if a == 0:
                o.append(0)
                continue
            if mode == "bayer":
                x, y = idx % fw, idx // fw
                keep = a * 16 > (BAYER4[y % 4][x % 4] + 0.5) * 255
            else:
                keep = a >= cut
            if not keep:
                stats["alpha_dropped"] += 1
                o.append(0)
                continue
            if a != 255:
                stats["alpha_kept_translucent"] += 1
            col = 0xFF000000 | (r << 16) | (g << 8) | b
            stats["colours_in"].add(col)
            snapped = nearest(col)
            stats["colours_out"].add(snapped)
            if snapped == col:
                stats["unchanged"] += 1
            else:
                stats["snapped"] += 1
            o.append(snapped)
        out.append(o)
    stats["colours_in"] = len(stats["colours_in"])
    stats["colours_out"] = sorted(tohex(c) for c in stats["colours_out"])
    return out, stats


def pad_border(frames, fw, fh):
    """Grow the frame by 1 px on every side when any opaque pixel touches the border (fxkit `edge` rule)."""
    touches = any(
        c for px in frames for idx, c in enumerate(px)
        if (idx % fw in (0, fw - 1) or idx // fw in (0, fh - 1)))
    if not touches:
        return frames, fw, fh, 0
    nw, nh = fw + 2, fh + 2
    out = []
    for px in frames:
        o = [0] * (nw * nh)
        for y in range(fh):
            o[(y + 1) * nw + 1:(y + 1) * nw + 1 + fw] = px[y * fw:(y + 1) * fw]
        out.append(o)
    return out, nw, nh, 1


def pack_sheet(frames, fw, fh):
    cols, rows_ = grid(len(frames))
    W, H = cols * fw, rows_ * fh
    out = [0] * (W * H)
    for i, px in enumerate(frames):
        ox, oy = (i % cols) * fw, (i // cols) * fh
        for y in range(fh):
            out[(oy + y) * W + ox:(oy + y) * W + ox + fw] = px[y * fw:(y + 1) * fw]
    return W, H, out, cols, rows_


def trailing_empty(frames):
    """A Tessera one-shot must end empty; report whether the last frame is."""
    return not any(frames[-1])


# ─── previews ────────────────────────────────────────────────────────────────
def over_ground(px, w, h):
    return [c if c else GROUND for c in px]


def write_previews(out_dir: Path, frames, fw, fh, frame_ms: int, loop: bool, zoom: int = 3):
    cols = min(8, len(frames))
    rows_ = math.ceil(len(frames) / cols)
    gap = 2
    W, H = cols * fw + (cols - 1) * gap, rows_ * fh + (rows_ - 1) * gap
    sheet = [0xFF1B1722] * (W * H)
    for i, px in enumerate(frames):
        ox, oy = (i % cols) * (fw + gap), (i // cols) * (fh + gap)
        shown = over_ground(px, fw, fh)
        for y in range(fh):
            sheet[(oy + y) * W + ox:(oy + y) * W + ox + fw] = shown[y * fw:(y + 1) * fw]
    write_png(out_dir / "contact.png", W * zoom, H * zoom, upscale(sheet, W, H, zoom))
    gif_frames = [upscale(over_ground(px, fw, fh), fw, fh, zoom) for px in frames]
    delays = [max(2, round(frame_ms / 10))] * len(frames)
    if loop:
        gif_frames = gif_frames * 3
        delays = delays * 3
    else:
        delays[-1] = max(delays[-1], 50)
    write_gif(out_dir / "anim.gif", fw * zoom, fh * zoom, gif_frames, delays)


# ─── adapt ───────────────────────────────────────────────────────────────────
def adapt(args) -> int:
    json_path = Path(args.json_path)
    png_path = Path(args.png) if args.png else None
    ex = load_export(json_path, png_path)
    fps = ex["fps"] or 30
    frame_ms = args.frame_ms or (ex["durations_ms"][0] if len(ex["durations_ms"]) == 1 and ex["durations_ms"][0] else round(1000 / fps))
    frames, kept = window(ex["frames"], args.frames)
    fw, fh, pivot = ex["frame_w"], ex["frame_h"], ex["pivot"]
    frames, fw, fh, pivot = crop(frames, fw, fh, pivot, args.crop)
    master = read_gpl(Path(args.palette) if args.palette else GPL)
    ramp = None
    if args.ramp:
        ramps = json.loads(RAMPS.read_text(encoding="utf-8")).get("ramps", {})
        if args.ramp in ramps:
            ramp = [hexc(c) for c in ramps[args.ramp]]
        else:
            ramp = [hexc(c) for c in args.ramp.split(",")]
        off = [tohex(c) for c in ramp if c not in master]
        if off:
            raise AdapterError(f"ramp colours not in the master palette: {', '.join(off)}")
    frames, stats = quantise(frames, fw, fh, args.alpha, args.alpha_cut, master, ramp)
    frames, fw, fh, padded = pad_border(frames, fw, fh)
    pivot = [pivot[0] + padded, pivot[1] + padded]
    loop = ex["loop"]
    if not loop and not trailing_empty(frames):
        # a Tessera one-shot ends empty: append one empty frame rather than cut the effect
        frames = frames + [[0] * (fw * fh)]
        stats["empty_frame_appended"] = True
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    W, H, px, cols, rows_ = pack_sheet(frames, fw, fh)
    write_png(out_dir / "whole.png", W, H, px)
    pack_id = args.pack_id or out_dir.name.split("-v")[0].replace("-", "_")
    anchor_kind = args.anchor
    layer = args.layer
    n = len(frames)
    index_entry = {"dir": pack_id, "layer": layer, "play": "loop" if loop else "once", "clip": "whole",
                   "frames": n, "frame_ms": frame_ms, "anchor": anchor_kind}
    if args.cell:
        cw, ch = (int(v) for v in args.cell.lower().split("x"))
        index_entry["cell"] = [cw, ch]
    colours = sorted({c for f in frames for c in f if c})
    manifest = {
        "app": APP,
        "name": args.title or f"Tessera fx (pixelfx {ex['effect_id']}) - {ex['name']}",
        "fps": round(1000 / frame_ms),
        "frame_ms": frame_ms,
        "frames": n,
        "loop": loop,
        "canvas": {"w": fw, "h": fh},
        "anchor": {"kind": anchor_kind, "x": pivot[0], "y": pivot[1]},
        "clips": [{
            "name": "whole", "title": "the whole effect (pixelfx layers composited)", "depth": "both",
            "loop": loop, "start_frame": 0, "frames": n, "frame": {"w": fw, "h": fh},
            "sheets": [{"file": "whole.png", "first_frame": 0, "frames": n, "columns": cols, "rows": rows_}],
            "offset": {"x": -pivot[0], "y": -pivot[1]},
        }],
        "source": {
            "provider": "pixelfx", "origin": args.origin, "effect_id": args.effect_id or ex["effect_id"],
            "upstream_repo": UPSTREAM_REPO, "upstream_commit": args.upstream_commit,
            "exported_json": ex["json"], "exported_png": ex["png"], "fps_rendered": fps, "seed": args.seed,
            "frames_window": kept, "crop": args.crop, "alpha": args.alpha, "alpha_cut": args.alpha_cut,
            "ramp": args.ramp, "adapter_version": ADAPTER_VERSION, "adapted_on": date.today().isoformat(),
            "act": ex["act"],
        },
        "tessera": {"pack": pack_id, "layer": layer, "cell": index_entry.get("cell"),
                    "duration_sec": round(n * frame_ms / 1000, 4), "palette": [tohex(c) for c in colours],
                    "index_entry": index_entry, "stats": stats, "border_padded_px": padded},
        "index_entry": index_entry,
    }
    (out_dir / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    write_previews(out_dir, frames, fw, fh, frame_ms, loop)
    findings = check_pack(out_dir, master, layer)
    report = {"pack": str(out_dir), "verdict": "FAIL" if failed(findings) else "PASS",
              "findings": [{"level": lv, "code": code, "message": msg} for lv, code, msg in findings],
              "stats": stats, "adapter_version": ADAPTER_VERSION}
    (out_dir / "adapter-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"adapted {ex['effect_id']}: {n} frames x {frame_ms} ms, {fw}x{fh}, pivot {pivot}, {len(colours)} colours; "
          f"alpha dropped {stats['alpha_dropped']}, snapped {stats['snapped']}, red avoided {stats['red_avoided']}, border padded {padded} px")
    print(format_findings(findings))
    print(f"verdict: {report['verdict']} -> {out_dir}")
    return 1 if failed(findings) else 0


# ─── selftest ────────────────────────────────────────────────────────────────
def _png_rgba(w, h, rows) -> bytes:
    raw = b"".join(b"\x00" + bytes(v for px in row for v in px) for row in rows)

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def selftest(_args) -> int:
    """Synthesise a pixelfx-shaped export with translucent glow, off-palette colours, a border touch and a
    telegraph-red pixel; adapt it; assert the pack is clean and the manifest is what vfx_pack.gd reads."""
    fw, fh, n, cols = 16, 12, 5, 3
    rows_ = math.ceil(n / cols)
    sheet = [[(0, 0, 0, 0)] * (fw * cols) for _ in range(fh * rows_)]
    for i in range(n):
        ox, oy = (i % cols) * fw, (i // cols) * fh
        for y in range(2, 9):
            for x in range(3, 11):
                sheet[oy + y][ox + x] = (0x9A, 0xA8, 0xC0, 255)          # off-palette steel-ish -> snaps to #8FA3B8
        sheet[oy + 5][ox + 12] = (0xFF, 0xFF, 0xFF, 90)                  # faint glow -> dropped at cut 128
        sheet[oy + 6][ox + 12] = (0xFF, 0xFF, 0xFF, 200)                 # translucent -> kept, snapped
        sheet[oy + 0][ox + 0] = (0x1B, 0x17, 0x22, 255)                  # border touch -> padding
        sheet[oy + 7][ox + 7] = (0xE5, 0x29, 0x3B, 255)                  # telegraph red -> snapped away
    frames = [{"filename": f"t {i}", "frame": {"x": (i % cols) * fw, "y": (i // cols) * fh, "w": fw, "h": fh},
               "rotated": False, "trimmed": False, "spriteSourceSize": {"x": 0, "y": 0, "w": fw, "h": fh},
               "sourceSize": {"w": fw, "h": fh}, "duration": 50} for i in range(n)]
    export = {"frames": frames, "meta": {"app": UPSTREAM_REPO, "version": "1", "image": "t.png", "format": "RGBA8888",
                                          "size": {"w": fw * cols, "h": fh * rows_}, "scale": "1",
                                          "frameTags": [{"name": "t", "from": 0, "to": n - 1, "direction": "forward"}],
                                          "pixelfx": {"id": "selftest/t", "name": "Selftest", "fps": 20, "loop": False,
                                                      "frames": n, "frameSize": [fw, fh], "pivot": [8, 10], "columns": cols}}}
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        (tmp / "t.json").write_text(json.dumps(export), encoding="utf-8")
        (tmp / "t.png").write_bytes(_png_rgba(fw * cols, fh * rows_, sheet))
        out = tmp / "t_pack-v1-selftest"
        ns = argparse.Namespace(json_path=str(tmp / "t.json"), png=None, out=str(out), pack_id="t_pack", frame_ms=50,
                                frames=None, crop=None, alpha="threshold", alpha_cut=128, layer="overlay",
                                anchor="ground_center", cell=None, palette=None, ramp=None, origin="upstream",
                                effect_id=None, upstream_commit="selftest", seed=1, title=None)
        rc = adapt(ns)
        m = json.loads((out / "manifest.json").read_text(encoding="utf-8"))
        checks = {
            "adapt exit 0 (pack passes fxc check)": rc == 0,
            "frames = 5 + 1 appended empty (one-shot ends empty)": m["frames"] == 6 and m["tessera"]["stats"].get("empty_frame_appended") is True,
            "canvas padded by 1 px (border touch)": m["canvas"] == {"w": fw + 2, "h": fh + 2} and m["tessera"]["border_padded_px"] == 1,
            "pivot shifted with the padding": m["anchor"] == {"kind": "ground_center", "x": 9, "y": 11},
            "offset = -pivot": m["clips"][0]["offset"] == {"x": -9, "y": -11},
            "sheet columns follow fxkit grid": m["clips"][0]["sheets"][0]["columns"] == grid(6)[0],
            "faint glow dropped, translucent kept": m["tessera"]["stats"]["alpha_dropped"] == n and m["tessera"]["stats"]["alpha_kept_translucent"] == n,
            "no colour near the telegraph red survives": all(dist(hexc(c), TELEGRAPH_RED) >= RED_MIN_DISTANCE for c in m["tessera"]["palette"]),
            "every colour in the master palette": all(hexc(c) in read_gpl(GPL) for c in m["tessera"]["palette"]),
            "provenance recorded": m["source"]["provider"] == "pixelfx" and m["source"]["adapter_version"] == ADAPTER_VERSION and m["source"]["origin"] == "upstream",
            "index entry carried": m["index_entry"]["play"] == "once" and m["index_entry"]["layer"] == "overlay",
            "previews written": (out / "contact.png").is_file() and (out / "anim.gif").is_file() and (out / "adapter-report.json").is_file(),
        }
        bad = [k for k, v in checks.items() if not v]
        for k, v in checks.items():
            print(("PASS " if v else "FAIL ") + k)
        # negative: a wrong JSON is refused
        try:
            load_export(tmp / "t.json", None)
            (tmp / "bad.json").write_text(json.dumps({"frames": [], "meta": {"app": "other"}}), encoding="utf-8")
            load_export(tmp / "bad.json", None)
            print("FAIL foreign JSON accepted")
            bad.append("foreign JSON accepted")
        except AdapterError as e:
            print("PASS foreign JSON refused: %s" % e)
    print("selftest: %d FAIL" % len(bad))
    return 1 if bad else 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("adapt", help="pixelfx JSON + PNG -> VfxPack candidate")
    a.add_argument("json_path")
    a.add_argument("--png")
    a.add_argument("--out", required=True)
    a.add_argument("--pack-id")
    a.add_argument("--frame-ms", type=int)
    a.add_argument("--frames", help="A:B window of source frames to keep")
    a.add_argument("--crop", help="WxH box centred on the pivot x, bottom-aligned 1 px under the pivot y")
    a.add_argument("--alpha", choices=["threshold", "bayer"], default="threshold")
    a.add_argument("--alpha-cut", type=int, default=128)
    a.add_argument("--layer", choices=["overlay", "floor"], default="overlay")
    a.add_argument("--anchor", choices=["ground_center", "center"], default="ground_center")
    a.add_argument("--cell", help="WxH cell the pack is made for (index entry)")
    a.add_argument("--palette", help=".gpl master palette (default art_src/palette/tessera_master.gpl)")
    a.add_argument("--ramp", help="ramp name from palettes.json or #hex,#hex,... — restricts the snap targets")
    a.add_argument("--origin", choices=["upstream", "adapted", "original"], default="upstream")
    a.add_argument("--effect-id")
    a.add_argument("--upstream-commit", default="unknown")
    a.add_argument("--seed", type=int)
    a.add_argument("--title")
    sub.add_parser("selftest", help="synthetic export round trip")
    args = ap.parse_args(argv)
    try:
        return {"adapt": adapt, "selftest": selftest}[args.cmd](args)
    except AdapterError as e:
        print("FAIL %s" % e, file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
