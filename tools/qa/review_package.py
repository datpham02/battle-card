#!/usr/bin/env python
"""review_package: build the visual review package for a candidate so the user can judge it before acceptance.

    python -X utf8 -I tools/qa/review_package.py <candidate folder> [--current <frames dir | pack dir>] [--zoom 4]
        [--frame-ms 100] [--known "issue; issue"] [--suggest "revision prompt"] [--qa-json <art_check --json output>]

Reads the candidate's frames (a pack folder with manifest.json + whole.png, or a frame folder: clean/ then raw/
then the folder itself) and writes into <candidate>/preview/:
  contact_x<zoom>.png      every frame in a grid on the ground colour
  anim.gif                 the clip at its timing (loops play 3 times)
  before_after_x<zoom>.png the current version (--current) on the top row, the candidate below, frame by frame
  REVIEW.md                what to look at, the technical QA summary, known issues, suggested revision, the open question
It never decides: the last line of REVIEW.md is "Waiting for the user's decision". Standard library + fxkit.
"""
from __future__ import annotations

import argparse
import json
import math
import re
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "fx-pipeline"))
from fxkit.gif import write_gif  # noqa: E402
from fxkit.pngio import read_png, write_png  # noqa: E402
from fxkit.preview import upscale  # noqa: E402

GROUND = 0xFF262521
INK = 0xFF1B1722


def natural(p: Path):
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", p.name)]


def rgba_to_ints(rows):
    return [0 if a == 0 else (0xFF000000 | (r << 16) | (g << 8) | b) for row in rows for (r, g, b, a) in row]


def load_frames(folder: Path):
    """-> (frames as colour ints, w, h, frame_ms, loop, source description)"""
    manifest = folder / "manifest.json"
    if manifest.is_file():
        m = json.loads(manifest.read_text(encoding="utf-8"))
        clip = next(c for c in m["clips"] if c["name"] == "whole")
        sh = clip["sheets"][0]
        w, h, rows = read_png(folder / sh["file"])
        px = rgba_to_ints(rows)
        fw, fh, cols = clip["frame"]["w"], clip["frame"]["h"], sh["columns"]
        frames = []
        for i in range(clip["frames"]):
            ox, oy = (i % cols) * fw, (i // cols) * fh
            frames.append([px[(oy + y) * w + ox + x] for y in range(fh) for x in range(fw)])
        return frames, fw, fh, int(m.get("frame_ms", 50)), bool(m.get("loop", False)), "pack %s" % folder.name
    for sub in ("clean", "raw", "."):
        d = folder / sub
        files = sorted(d.glob("*.png"), key=natural) if d.is_dir() else []
        if files:
            frames, sizes = [], set()
            for f in files:
                w, h, rows = read_png(f)
                sizes.add((w, h))
                frames.append(rgba_to_ints(rows))
            if len(sizes) != 1:
                raise SystemExit("frames differ in size: %s" % sorted(sizes))
            (w, h), = sizes
            return frames, w, h, None, None, "%s/%s (%d frames)" % (folder.name, sub, len(files))
    raise SystemExit("no frames in %s" % folder)


def on_ground(px):
    return [c if c else GROUND for c in px]


def sheet(frames, w, h, cols, gap=2):
    rows_ = math.ceil(len(frames) / cols)
    W, H = cols * w + (cols - 1) * gap, rows_ * h + (rows_ - 1) * gap
    out = [INK] * (W * H)
    for i, px in enumerate(frames):
        ox, oy = (i % cols) * (w + gap), (i // cols) * (h + gap)
        shown = on_ground(px)
        for y in range(h):
            out[(oy + y) * W + ox:(oy + y) * W + ox + w] = shown[y * w:(y + 1) * w]
    return W, H, out


def fit_frames(frames, w, h, W, H):
    """Place frames of w x h bottom-centred into W x H cells (for before/after rows of different sizes)."""
    if (w, h) == (W, H):
        return frames
    out = []
    for px in frames:
        o = [0] * (W * H)
        ox, oy = (W - w) // 2, H - h
        for y in range(h):
            ty = oy + y
            if 0 <= ty < H:
                for x in range(w):
                    tx = ox + x
                    if 0 <= tx < W:
                        o[ty * W + tx] = px[y * w + x]
        out.append(o)
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("candidate")
    ap.add_argument("--current")
    ap.add_argument("--zoom", type=int, default=4)
    ap.add_argument("--frame-ms", type=int)
    ap.add_argument("--known", default="")
    ap.add_argument("--suggest", default="")
    ap.add_argument("--qa-json")
    a = ap.parse_args(argv)
    cand = Path(a.candidate) if Path(a.candidate).is_absolute() else ROOT / a.candidate
    frames, w, h, ms, loop, src = load_frames(cand)
    ms = a.frame_ms or ms or 100
    out = cand / "preview"
    out.mkdir(parents=True, exist_ok=True)
    cols = min(8, len(frames))
    W, H, px = sheet(frames, w, h, cols)
    contact = out / ("contact_x%d.png" % a.zoom)
    write_png(contact, W * a.zoom, H * a.zoom, upscale(px, W, H, a.zoom))
    gif_frames = [upscale(on_ground(f), w, h, a.zoom) for f in frames]
    delays = [max(2, round(ms / 10))] * len(frames)
    if loop:
        gif_frames, delays = gif_frames * 3, delays * 3
    else:
        delays[-1] = max(delays[-1], 50)
    write_gif(out / "anim.gif", w * a.zoom, h * a.zoom, gif_frames, delays)
    before_after = None
    cur_desc = None
    if a.current:
        cur = Path(a.current) if Path(a.current).is_absolute() else ROOT / a.current
        cframes, cw, ch, _, _, cur_desc = load_frames(cur)
        BW, BH = max(w, cw), max(h, ch)
        n = max(len(frames), len(cframes))
        top = fit_frames(cframes, cw, ch, BW, BH) + [[0] * (BW * BH)] * (n - len(cframes))
        bottom = fit_frames(frames, w, h, BW, BH) + [[0] * (BW * BH)] * (n - len(frames))
        W2, H2, px2 = sheet(top + bottom, BW, BH, n)
        before_after = out / ("before_after_x%d.png" % a.zoom)
        write_png(before_after, W2 * a.zoom, H2 * a.zoom, upscale(px2, W2, H2, a.zoom))
    qa_lines = []
    if a.qa_json and Path(a.qa_json).is_file():
        q = json.loads(Path(a.qa_json).read_text(encoding="utf-8"))
        qa_lines.append("Technical verdict: **%s** (`tools/qa/art_check.py %s`)" % (q.get("verdict"), q.get("mode")))
        qa_lines += ["- %s %s%s: %s" % (r["verdict"], r["check"], (" [" + r["scope"] + "]") if r.get("scope") else "", r["detail"]) for r in q.get("rows", [])]
    rep = cand / "adapter-report.json"
    if rep.is_file():
        r = json.loads(rep.read_text(encoding="utf-8"))
        qa_lines.append("Adapter / fxc check: **%s**; " % r.get("verdict") + "; ".join("%s %s: %s" % (f["level"], f["code"], f["message"]) for f in r.get("findings", [])))
    qa_json = cand / "raw" / "qa.json"
    if qa_json.is_file():
        q = json.loads(qa_json.read_text(encoding="utf-8"))
        crossed = [x for x in q if str(x.get("status", "")).startswith("CROSSED")] if isinstance(q, list) else []
        not_run = [x for x in q if str(x.get("status", "")).startswith("NOT RUN")] if isinstance(q, list) else []
        qa_lines.append("anim_qa.py: %d crossed, %d not run" % (len(crossed), len(not_run)))
    if not qa_lines:
        qa_lines.append("NOT ASSESSED — no QA report found (run `tools/qa/art_check.py candidate %s` and pass --qa-json)" % a.candidate)
    md = [
        "# Review — %s (%s)" % (cand.name, date.today().isoformat()),
        "",
        "Source: %s · %d frames · %d×%d art px · %d ms/frame · %s" % (src, len(frames), w, h, ms, "loop" if loop else "one-shot"),
        "",
        "## Look at",
        "- `preview/%s` — every frame at %d× on the ground colour; judge silhouette, palette, feet row, outline." % (contact.name, a.zoom),
        "- `preview/anim.gif` — the timing; judge the read at 1× distance too (shrink the window).",
    ]
    if before_after:
        md.append("- `preview/%s` — top: current (%s); bottom: candidate, same frame index." % (before_after.name, cur_desc))
    md += ["", "## Technical QA"] + qa_lines
    md += ["", "## Known issues", a.known or "none recorded", "", "## Suggested revision (if rejected)", a.suggest or "none prepared",
           "", "## Decision", "Accept this candidate, ask for a retake with the suggested revision, or reject it.",
           "Record the answer: `python -X utf8 -I tools/asset-pipeline/candidate.py verdict %s --acceptance accepted|rejected --by user --evidence \"<the user's words>\"`" % a.candidate,
           "", "**Waiting for the user's decision.**", ""]
    (out / "REVIEW.md").write_text("\n".join(md), encoding="utf-8")
    print("review package: %s (contact, anim.gif%s, REVIEW.md)" % (out, ", before_after" if before_after else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
