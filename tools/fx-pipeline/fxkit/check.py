"""Checks for components and packs (PixelFX tools/check.mjs, plus Tessera's pixel rules).

Two halves:
- check_component: what only the code can show - determinism, drawing outside the canvas (four seeds), a
  one-shot that does not end empty, a loop seam, randomness or clock use in the source.
- check_pack: what the files show, for any pack (ours or PixelLab's) - alpha 0/255, every colour in the master
  palette, nothing near the telegraph red, a clear 1 px border, sheet/JSON agreement, overlay duration, round-
  looking clusters, single-pixel specks, and how many square clusters a frame holds.

Each finding is (level, code, message), level FAIL | warn | info. A FAIL breaks the build; warn and info are
observations for the person judging the pack.
"""
from __future__ import annotations

import inspect
import json
import math
from pathlib import Path

from .component import Component
from .palette import TELEGRAPH_RED, RED_MIN_DISTANCE, dist, tohex
from .pngio import read_png
from .render import draw_frame, frame_times

Finding = tuple[str, str, str]
OVERLAY_MAX_SEC = 0.35       # art bible §1: only a hit VFX <= 0.35 s may be drawn over a unit
MAX_SQUARES = 128            # art bible §8.5: <= 128 squares at once
SPILL_SEEDS = (2, 3, 7)


def check_component(comp: Component, o: dict, fps: int) -> list[Finding]:
    out: list[Finding] = []
    o = comp.options(o)
    dur = comp.duration(o)
    src = inspect.getsource(inspect.getmodule(type(comp)))
    for bad in ("import random", "random.", "time.time", "datetime"):
        if bad in src:
            out.append(("FAIL", "unseeded", f"{comp.name}: source uses '{bad}'; use fxkit.rng with the seed"))
    # determinism: the same t twice draws the same pixels
    t = dur * 0.37
    a, _, _ = draw_frame(comp, o, t)
    b, _, _ = draw_frame(comp, o, t)
    if any(a[k].px != b[k].px for k in a):
        out.append(("FAIL", "nondeterministic", f"{comp.name}: two draws at t={t:.3f} differ"))
    # spill: nothing drawn outside the canvas, with the recipe seed and three more
    times = frame_times(dur, fps, comp.loop)
    worst = 0
    for seed in (o.get("seed", 1),) + SPILL_SEEDS:
        oo = dict(o, seed=seed)
        spill = sum(draw_frame(comp, oo, tt)[1] for tt in times)
        worst = max(worst, spill)
    if worst:
        out.append(("FAIL", "spill", f"{comp.name}: {worst} px drawn outside the {comp.box(o)[0]}x{comp.box(o)[1]} canvas (grow the box)"))
    if not comp.loop:
        end, _, _ = draw_frame(comp, o, dur)
        left = sum(L.count() for L in end.values())
        if left:
            out.append(("FAIL", "not_empty_at_end", f"{comp.name}: {left} px still drawn at t = duration ({dur:.3f} s)"))
    else:
        shots = [draw_frame(comp, o, tt)[0] for tt in times]
        flat = [s["behind"].px + s["front"].px for s in shots]
        steps = sorted(sum(1 for p, q in zip(flat[i], flat[i + 1]) if p != q) for i in range(len(flat) - 1))
        typical = steps[int(len(steps) * 0.9)] if steps else 0
        seam = sum(1 for p, q in zip(flat[-1], flat[0]) if p != q)
        if seam > max(typical * 2, 12):
            out.append(("warn", "loop_seam", f"{comp.name}: {seam} px change from the last frame to the first (a normal step is {typical})"))
    return out


def _clusters(px: list[tuple[int, int, int, int]], w: int, h: int) -> list[tuple[int, int, int, bool]]:
    """4-connected opaque clusters as (pixel count, bbox w, bbox h, all four bbox corners empty)."""
    seen = [False] * (w * h)
    found = []
    for i in range(w * h):
        if seen[i] or px[i][3] == 0:
            continue
        stack, n, members = [i], 0, set()
        seen[i] = True
        x0 = x1 = i % w
        y0 = y1 = i // w
        while stack:
            j = stack.pop()
            n += 1
            members.add(j)
            x, y = j % w, j // w
            x0, x1, y0, y1 = min(x0, x), max(x1, x), min(y0, y), max(y1, y)
            for k in ((j - 1) if x > 0 else -1, (j + 1) if x < w - 1 else -1, j - w, j + w):
                if 0 <= k < w * h and not seen[k] and px[k][3] != 0:
                    seen[k] = True
                    stack.append(k)
        corners_empty = all(c not in members for c in (y0 * w + x0, y0 * w + x1, y1 * w + x0, y1 * w + x1))
        found.append((n, x1 - x0 + 1, y1 - y0 + 1, corners_empty))
    return found


def check_pack(pack_dir: Path, master: dict[int, str], layer: str | None = None) -> list[Finding]:
    out: list[Finding] = []
    mpath = pack_dir / "manifest.json"
    if not mpath.is_file():
        return [("FAIL", "no_manifest", f"{pack_dir}: manifest.json missing")]
    m = json.loads(mpath.read_text(encoding="utf-8"))
    layer = layer or m.get("tessera", {}).get("layer")
    frame_ms, loop = int(m.get("frame_ms", 0)), bool(m.get("loop", True))
    cw, ch = m.get("canvas", {}).get("w", 0), m.get("canvas", {}).get("h", 0)
    if cw % 2 or ch % 2:
        out.append(("warn", "odd_canvas", f"canvas {cw}x{ch} is odd: centres fall between pixels"))
    clips = {c["name"]: c for c in m.get("clips", [])}
    if "whole" not in clips:
        out.append(("FAIL", "no_whole", "no 'whole' clip (every index entry plays 'whole')"))
        return out
    for name, c in clips.items():
        sh = c["sheets"][0]
        f = pack_dir / sh["file"]
        if not f.is_file():
            out.append(("FAIL", "no_sheet", f"{name}: {sh['file']} missing"))
            continue
        w, h, rows = read_png(f)
        fw, fh = c["frame"]["w"], c["frame"]["h"]
        cols = sh["columns"]
        nrows = math.ceil(c["frames"] / cols)
        if w < cols * fw or h < nrows * fh:
            out.append(("FAIL", "sheet_size", f"{name}: sheet {w}x{h} smaller than {cols}x{nrows} frames of {fw}x{fh}"))
            continue
        if name != "whole":
            continue
        dur_ms = c["frames"] * frame_ms
        if layer == "overlay" and not loop and dur_ms > OVERLAY_MAX_SEC * 1000 + 1:
            out.append(("FAIL", "overlay_too_long", f"overlay one-shot lasts {dur_ms} ms (> {int(OVERLAY_MAX_SEC * 1000)} ms over units)"))
        bad_alpha = off_palette = red = edge = 0
        off_seen: set[int] = set()
        round_like = specks = most_squares = 0
        for fi in range(c["frames"]):
            ox, oy = (fi % cols) * fw, (fi // cols) * fh
            frame = [rows[oy + y][ox + x] for y in range(fh) for x in range(fw)]
            for idx, (r_, g_, b_, a_) in enumerate(frame):
                if a_ == 0:
                    continue
                if a_ != 255:
                    bad_alpha += 1
                    continue
                col = 0xFF000000 | (r_ << 16) | (g_ << 8) | b_
                if col not in master:
                    off_palette += 1
                    off_seen.add(col)
                if dist(col, TELEGRAPH_RED) < RED_MIN_DISTANCE:
                    red += 1
                x, y = idx % fw, idx // fw
                if x == 0 or y == 0 or x == fw - 1 or y == fh - 1:
                    edge += 1
            cl = _clusters(frame, fw, fh)
            most_squares = max(most_squares, len(cl))
            specks += sum(1 for n, _, _, _ in cl if n == 1)
            for n, bw, bh, corners_empty in cl:
                # a disc fills about pi/4 of its box and leaves all four corners empty; two touching squares do not
                if corners_empty and bw >= 5 and bh >= 5 and abs(bw - bh) <= 2 and 0.70 <= n / (bw * bh) <= 0.86:
                    round_like += 1
        if bad_alpha:
            out.append(("FAIL", "alpha", f"{bad_alpha} px with alpha other than 0/255"))
        if off_palette:
            out.append(("FAIL", "palette", f"{off_palette} px off the master palette: {', '.join(tohex(c) for c in sorted(off_seen)[:6])}"))
        if red:
            out.append(("FAIL", "telegraph_red", f"{red} px within {RED_MIN_DISTANCE} of #E5293B (red is the enemy warning only)"))
        if edge:
            out.append(("FAIL", "edge", f"{edge} px on the frame border (keep 1 px clear on every side)"))
        if round_like:
            out.append(("warn", "round_shape", f"{round_like} cluster(s) shaped like a disc: magic is square (art bible P1)"))
        if most_squares > MAX_SQUARES:
            out.append(("warn", "too_many_squares", f"{most_squares} separate clusters in one frame (> {MAX_SQUARES})"))
        out.append(("info", "stats", f"{c['frames']} frames x {frame_ms} ms = {dur_ms} ms, {cw}x{ch}, "
                     f"up to {most_squares} clusters a frame, {specks} single-px specks in all"))
    return out


def failed(findings: list[Finding]) -> bool:
    return any(level == "FAIL" for level, _, _ in findings)


def format_findings(findings: list[Finding]) -> str:
    return "\n".join(f"  {lv:<4} {code}: {msg}" for lv, code, msg in findings) or "  ok"
