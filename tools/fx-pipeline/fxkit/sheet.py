"""Write a rendered component as a game pack the engine already reads (src/art/vfx_pack.gd).

Pack = <dir>/manifest.json + whole.png (+ behind.png / front.png when both layers are used). Limits of the loader
honoured here: one frame_ms for the whole pack, the first sheet of a clip only, frames row-major with no gutter,
no scaling. `offset` is the frame's top-left relative to the anchor. The `tessera` block is extra (the loader
ignores it): where the pack came from, and the index entry `fxc install` would add.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

from .painter import over
from .palette import tohex
from .pngio import write_png
from .render import Render

APP = "tools/fx-pipeline fxc 0.1"


def grid(n: int) -> tuple[int, int]:
    cols = n if n <= 10 else math.ceil(math.sqrt(n))
    return cols, math.ceil(n / cols)


def _sheet(frames: list[list[int]], w: int, h: int) -> tuple[int, int, list[int], int, int]:
    cols, rows = grid(len(frames))
    W, H = cols * w, rows * h
    out = [0] * (W * H)
    for i, px in enumerate(frames):
        ox, oy = (i % cols) * w, (i // cols) * h
        for y in range(h):
            out[(oy + y) * W + ox:(oy + y) * W + ox + w] = px[y * w:(y + 1) * w]
    return W, H, out, cols, rows


def _clip(name: str, depth: str, r: Render, file: str, cols: int, rows: int) -> dict:
    return {
        "name": name, "title": {"whole": "the whole effect", "behind": "under the units", "front": "over the units"}[name],
        "depth": depth, "loop": r.loop, "start_frame": 0, "frames": r.n,
        "frame": {"w": r.w, "h": r.h},
        "sheets": [{"file": file, "first_frame": 0, "frames": r.n, "columns": cols, "rows": rows}],
        "offset": {"x": -r.ox, "y": -r.oy},
    }


def export_pack(r: Render, out_dir: Path, pack_id: str, title: str, layer: str, extra: dict | None = None) -> Path:
    """Write the pack; `layer` is the game layer it is meant for: floor (under units) or overlay (over units)."""
    out_dir.mkdir(parents=True, exist_ok=True)
    used = r.used_layers()
    clips = []
    W, H, px, cols, rows = _sheet([r.whole(i) for i in range(r.n)], r.w, r.h)
    write_png(out_dir / "whole.png", W, H, px)
    clips.append(_clip("whole", "both" if len(used) > 1 else (used[0] if used else "both"), r, "whole.png", cols, rows))
    if len(used) > 1:
        for name in used:
            W, H, px, cols, rows = _sheet([f[name].px for f in r.frames], r.w, r.h)
            write_png(out_dir / f"{name}.png", W, H, px)
            clips.append(_clip(name, name, r, f"{name}.png", cols, rows))
    colours = sorted({c for f in r.frames for k in used for c in f[k].px if c})
    anchor = r.comp.anchor
    index_entry = {"dir": pack_id, "layer": layer, "play": "loop" if r.loop else "once", "clip": "whole",
                   "frames": r.n, "frame_ms": r.frame_ms}
    if anchor in ("ground_center", "center"):
        index_entry["anchor"] = anchor
    manifest = {
        "app": APP,
        "name": title,
        "fps": r.fps,
        "frame_ms": r.frame_ms,
        "frames": r.n,
        "loop": r.loop,
        "canvas": {"w": r.w, "h": r.h},
        "anchor": {"kind": anchor, "x": r.ox, "y": r.oy},
        "clips": clips,
        "tessera": {
            "pack": pack_id, "component": r.comp.name, "layer": layer,
            "cell": r.o.get("cell"), "seed": r.o.get("seed"), "duration_sec": round(r.duration, 4),
            "palette": [tohex(c) for c in colours],
            "index_entry": index_entry,
            **(extra or {}),
        },
    }
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    return out_dir
