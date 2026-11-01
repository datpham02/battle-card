"""Measure an animation's frames against the checks in references/animation-qa.md.

Standard library only. Prints observations: each check's value, its threshold,
and `ok`, `CROSSED` or `NOT RUN: <reason>`. It never prints a verdict; the
skill decides (FAIL > WARN > NOT ASSESSED > PASS) after the visual review.

Usage:
  python anim_qa.py --frames DIR [--anchor PNG] [--palette FILE|HEX,HEX,...]
                    [--expect-frames N] [--size WxH] [--feet-row R]
                    [--loop | --once] [--planted] [--skip-first] [--json OUT]

  --frames      a folder of PNG frames (sorted by the number in the name) or
                a comma list of files
  --anchor      the approved still / idle frame of the character
  --palette     .gpl, .json (list of hex), .txt (one hex per line) or a
                comma list of hex colours
  --skip-first  drop frame 0 (the source frame PixelLab echoes back)
  --planted     the feet must not move (attacks in place, idle, hurt, cast)
Exit code: 0 always when it ran; 2 when no frame could be read.
"""
import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngio import PngError, read_png  # noqa: E402

# Defaults (references/animation-qa.md); a project profile may pass others.
TH = {
    "palette_off_ratio": 0.005,
    "palette_far": 48,
    "identity_warn": 0.65,
    "identity_error": 0.45,
    "area_low": 0.72,
    "area_high": 1.32,
    "outlier_low": 0.35,
    "outlier_high": 2.75,
    "edge_px": 24,
    "feet_px_min": 2,
    "feet_ratio": 0.10,
    "feet_x_px": 2,
    "jitter_mult": 3.0,
    "jitter_px": 2.0,
    "dup_mad": 1.5,
    "seam_high": 2.0,
    "seam_low": 0.3,
}


def natural_key(path):
    name = os.path.basename(path)
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", name)]


def load_palette(spec):
    if spec is None:
        return None
    hexes = []
    if os.path.isfile(spec):
        text = open(spec, encoding="utf-8").read()
        if spec.lower().endswith(".gpl"):
            for line in text.splitlines():
                m = re.match(r"\s*(\d+)\s+(\d+)\s+(\d+)", line)
                if m:
                    hexes.append(tuple(int(v) for v in m.groups()))
            return set(hexes)
        if spec.lower().endswith(".json"):
            items = json.loads(text)
            if isinstance(items, dict):
                items = items.get("colors") or items.get("palette") or []
            text = ",".join(items)
        spec = text
    for tok in re.findall(r"#?([0-9a-fA-F]{6})", spec):
        hexes.append(tuple(int(tok[i:i + 2], 16) for i in (0, 2, 4)))
    return set(hexes)


def opaque(px):
    return [(x, y, p) for y, row in enumerate(px) for x, p in enumerate(row) if p[3] > 0]


def histogram(px):
    h = [0] * 64
    n = 0
    for row in px:
        for r, g, b, a in row:
            if a > 0:
                h[(r >> 6) * 16 + (g >> 6) * 4 + (b >> 6)] += 1
                n += 1
    return [v / n for v in h] if n else None


def intersection(h1, h2):
    return sum(min(a, b) for a, b in zip(h1, h2))


def mad(px1, px2):
    """Mean absolute RGBA difference over the pixels where either frame is opaque (empty canvas does not dilute it)."""
    total, n = 0, 0
    for r1, r2 in zip(px1, px2):
        for p, q in zip(r1, r2):
            if p[3] == 0 and q[3] == 0:
                continue
            total += abs(p[0] - q[0]) + abs(p[1] - q[1]) + abs(p[2] - q[2]) + abs(p[3] - q[3])
            n += 4
    return total / n if n else 0.0


def result(name, status, value=None, threshold=None, detail=None):
    return {"check": name, "status": status, "value": value, "threshold": threshold, "detail": detail}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--frames", required=True)
    ap.add_argument("--anchor")
    ap.add_argument("--palette")
    ap.add_argument("--expect-frames", type=int)
    ap.add_argument("--size")
    ap.add_argument("--feet-row", type=int)
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--loop", action="store_true")
    g.add_argument("--once", action="store_true")
    ap.add_argument("--planted", action="store_true")
    ap.add_argument("--skip-first", action="store_true")
    ap.add_argument("--json")
    a = ap.parse_args()

    if os.path.isdir(a.frames):
        paths = sorted((os.path.join(a.frames, f) for f in os.listdir(a.frames) if f.lower().endswith(".png")), key=natural_key)
    else:
        paths = [p.strip() for p in a.frames.split(",") if p.strip()]
    paths = [p for p in paths if os.path.basename(p) not in ("sheet.png", "contact.png")]
    if a.skip_first and paths:
        paths = paths[1:]

    frames, unreadable = [], []
    for p in paths:
        try:
            frames.append((p, read_png(p)))
        except (OSError, PngError, ValueError) as e:
            unreadable.append("%s (%s)" % (os.path.basename(p), e))
    out = []
    if unreadable:
        out.append(result("readable", "CROSSED", len(unreadable), 0, "; ".join(unreadable)))
    if not frames:
        out.append(result("all", "NOT RUN: no readable frame in --frames"))
        return finish(out, a, 2)

    anchor = None
    if a.anchor:
        try:
            anchor = read_png(a.anchor)
        except (OSError, PngError, ValueError) as e:
            out.append(result("anchor", "NOT RUN: anchor unreadable (%s)" % e))
    palette = None
    try:
        palette = load_palette(a.palette)
    except (OSError, ValueError) as e:
        out.append(result("palette_file", "NOT RUN: palette unreadable (%s)" % e))

    n = len(frames)
    sizes = {(f[1][0], f[1][1]) for f in frames}
    W, H = frames[0][1][0], frames[0][1][1]

    # 1. frame count
    if a.expect_frames is None:
        out.append(result("frame_count", "NOT RUN: no --expect-frames", n))
    else:
        out.append(result("frame_count", "ok" if n == a.expect_frames else "CROSSED", n, a.expect_frames))

    # 2. frame size
    if len(sizes) > 1:
        out.append(result("frame_size", "CROSSED", sorted(sizes), "all frames one size"))
    elif a.size is None:
        out.append(result("frame_size", "NOT RUN: no --size (frames are %dx%d)" % (W, H), "%dx%d" % (W, H)))
    else:
        tw, th = (int(v) for v in a.size.lower().split("x"))
        out.append(result("frame_size", "ok" if (W, H) == (tw, th) else "CROSSED", "%dx%d" % (W, H), a.size))
    same_size = len(sizes) == 1

    ops = [opaque(f[1][2]) for f in frames]
    areas = [len(o) for o in ops]

    # 3. background
    partial = sum(1 for o in ops for (_x, _y, p) in o if p[3] < 255)
    corners = 0
    for _p, (w, h, px) in frames:
        if all(px[y][x][3] > 0 for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))):
            corners += 1
    out.append(result("background_partial_alpha", "ok" if partial == 0 else "CROSSED", partial, 0))
    out.append(result("background_opaque_corners", "ok" if corners == 0 else "CROSSED", corners, 0, "frames whose four corners are opaque"))

    # 4. palette
    if palette is None:
        out.append(result("palette", "NOT RUN: no --palette"))
        out.append(result("palette_far", "NOT RUN: no --palette"))
    else:
        total = sum(areas)
        pal_list = list(palette)
        off, far, seen = 0, 0, {}
        for o in ops:
            for (_x, _y, p) in o:
                c = p[:3]
                if c in palette:
                    continue
                off += 1
                if c not in seen:
                    seen[c] = min(sum((u - v) ** 2 for u, v in zip(c, q)) for q in pal_list) ** 0.5
                if seen[c] > TH["palette_far"]:
                    far += 1
        ratio = off / total if total else 0.0
        far_ratio = far / total if total else 0.0
        out.append(result("palette", "ok" if ratio <= TH["palette_off_ratio"] else "CROSSED", round(ratio, 4), TH["palette_off_ratio"],
                          "%d of %d opaque px off-palette, %d distinct colours" % (off, total, len(seen))))
        out.append(result("palette_far", "ok" if far_ratio <= TH["palette_off_ratio"] else "CROSSED", round(far_ratio, 4), TH["palette_off_ratio"],
                          "%d px farther than RGB distance %d from every palette colour (a new colour family)" % (far, TH["palette_far"])))

    # 5-6. identity + size drift vs anchor
    if anchor is None:
        out.append(result("identity", "NOT RUN: no --anchor"))
        out.append(result("size_drift", "NOT RUN: no --anchor"))
    else:
        ha = histogram(anchor[2])
        aa = len(opaque(anchor[2]))
        if ha is None or aa == 0:
            out.append(result("identity", "NOT RUN: anchor is fully transparent"))
            out.append(result("size_drift", "NOT RUN: anchor is fully transparent"))
        else:
            scores = []
            for (_p, (_w, _h, px)) in frames:
                hf = histogram(px)
                scores.append(round(intersection(ha, hf), 3) if hf else 0.0)
            worst = min(scores)
            st = "ok" if worst >= TH["identity_warn"] else "CROSSED"
            out.append(result("identity", st, scores, "warn<%.2f error<%.2f" % (TH["identity_warn"], TH["identity_error"]),
                              "worst frame %d = %.3f" % (scores.index(worst), worst)))
            ratios = [round(v / aa, 3) for v in areas]
            bad = [i for i, r in enumerate(ratios) if r < TH["area_low"] or r > TH["area_high"]]
            out.append(result("size_drift", "ok" if not bad else "CROSSED", ratios, "%.2f-%.2f" % (TH["area_low"], TH["area_high"]),
                              "frames out of range: %s" % bad if bad else None))

    # 7. outlier frame vs median
    med = sorted(areas)[n // 2]
    if med == 0:
        out.append(result("outlier_frame", "NOT RUN: median frame is empty"))
    else:
        bad = [i for i, v in enumerate(areas) if v < TH["outlier_low"] * med or v > TH["outlier_high"] * med]
        out.append(result("outlier_frame", "ok" if not bad else "CROSSED", bad, "%.2fx-%.2fx median" % (TH["outlier_low"], TH["outlier_high"])))

    # 8. edge clipping (left, right, top; the feet may stand on the bottom row)
    edge = []
    for (_p, (w, _h, _px)), o in zip(frames, ops):
        edge.append(sum(1 for (x, y, _q) in o if x <= 1 or y <= 1 or x >= w - 2))
    out.append(result("edge_clipping", "ok" if max(edge) <= TH["edge_px"] else "CROSSED", edge, TH["edge_px"],
                      "opaque px within 2 px of the left, right or top edge"))

    # 9. foot contact
    bottoms, feet_x = [], []
    for o in ops:
        if not o:
            bottoms.append(None)
            feet_x.append(None)
            continue
        low = max(y for (_x, y, _q) in o)
        xs = [x for (x, y, _q) in o if y >= low - 1]
        bottoms.append(low)
        feet_x.append(sum(xs) / len(xs))
    valid = [b for b in bottoms if b is not None]
    tol = max(TH["feet_px_min"], TH["feet_ratio"] * H)
    ref = a.feet_row if a.feet_row is not None else sorted(valid)[len(valid) // 2]
    dev = [abs(b - ref) if b is not None else None for b in bottoms]
    worst = max(d for d in dev if d is not None)
    out.append(result("foot_row", "ok" if worst <= tol else "CROSSED", bottoms,
                      "row %s +/- %.1f" % (ref, tol), None if a.feet_row is not None else "no --feet-row: compared with the median row"))
    if a.planted:
        fx = [v for v in feet_x if v is not None]
        drift = max(fx) - min(fx)
        out.append(result("foot_x_planted", "ok" if drift <= TH["feet_x_px"] else "CROSSED", round(drift, 2), TH["feet_x_px"]))
    else:
        out.append(result("foot_x_planted", "NOT RUN: clip not marked --planted (steps / jumps move the feet on purpose)"))

    # 10. jitter (lower-body centroid)
    cents = []
    for o in ops:
        if not o:
            cents.append(None)
            continue
        top = min(y for (_x, y, _q) in o)
        low = max(y for (_x, y, _q) in o)
        cut = low - (low - top) * 0.4
        lower = [(x, y) for (x, y, _q) in o if y >= cut]
        cents.append((sum(p[0] for p in lower) / len(lower), sum(p[1] for p in lower) / len(lower)))
    steps = [((c2[0] - c1[0]) ** 2 + (c2[1] - c1[1]) ** 2) ** 0.5
             for c1, c2 in zip(cents, cents[1:]) if c1 is not None and c2 is not None]
    if len(steps) < 2:
        out.append(result("jitter", "NOT RUN: fewer than 3 non-empty frames"))
    else:
        mean = sum(steps) / len(steps)
        spikes = [i for i, s in enumerate(steps) if s > TH["jitter_mult"] * mean and s > TH["jitter_px"]]
        out.append(result("jitter", "ok" if not spikes else "CROSSED", [round(s, 2) for s in steps],
                          ">%.1fx mean and >%.1f px" % (TH["jitter_mult"], TH["jitter_px"]),
                          "spikes after frames %s" % spikes if spikes else None))

    # 11-12. near-duplicates and loop seam (need one frame size)
    if not same_size:
        out.append(result("near_duplicates", "NOT RUN: frames differ in size"))
        out.append(result("loop_seam", "NOT RUN: frames differ in size"))
    else:
        diffs = [mad(frames[i][1][2], frames[i + 1][1][2]) for i in range(n - 1)]
        dups = [i for i, d in enumerate(diffs) if d <= TH["dup_mad"]]
        out.append(result("near_duplicates", "ok" if not dups else "CROSSED", [round(d, 2) for d in diffs], "<= %.1f" % TH["dup_mad"],
                          "pairs (i, i+1) for i in %s" % dups if dups else None))
        if not a.loop:
            out.append(result("loop_seam", "NOT RUN: clip not marked --loop" + (" (one-shot)" if a.once else "")))
        elif n < 3 or not diffs or sum(diffs) == 0:
            out.append(result("loop_seam", "NOT RUN: too few or identical frames"))
        elif sum(diffs) / len(diffs) <= TH["dup_mad"]:
            out.append(result("loop_seam", "NOT RUN: frames nearly static (mean step %.2f), seam ratio undefined; judge the loop by eye"
                              % (sum(diffs) / len(diffs))))
        else:
            seam = mad(frames[-1][1][2], frames[0][1][2])
            ratio = seam / (sum(diffs) / len(diffs))
            st = "ok" if TH["seam_low"] <= ratio <= TH["seam_high"] else "CROSSED"
            out.append(result("loop_seam", st, round(ratio, 2), "%.1f-%.1f" % (TH["seam_low"], TH["seam_high"])))

    return finish(out, a, 0, [os.path.basename(f[0]) for f in frames])


def finish(out, a, code, names=None):
    print("anim_qa — %s" % a.frames)
    if names:
        print("frames (%d): %s" % (len(names), ", ".join(names)))
    for r in out:
        line = "  %-26s %s" % (r["check"], r["status"])
        if r["value"] is not None:
            line += " | value=%s" % (r["value"],)
        if r["threshold"] is not None:
            line += " | threshold=%s" % (r["threshold"],)
        if r["detail"]:
            line += " | %s" % r["detail"]
        print(line)
    crossed = [r["check"] for r in out if r["status"] == "CROSSED"]
    not_run = [r["check"] for r in out if r["status"].startswith("NOT RUN")]
    print("crossed: %s" % (", ".join(crossed) or "none"))
    print("not run: %s" % (", ".join(not_run) or "none"))
    if a.json:
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump({"frames": names, "checks": out, "crossed": crossed, "not_run": not_run}, f, indent=1)
    return code


if __name__ == "__main__":
    sys.exit(main())
