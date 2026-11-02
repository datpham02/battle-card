#!/usr/bin/env python3
"""fxc: build, check and preview code-drawn VFX packs for Tessera (docs/plans/animation-pipeline.md).

Pure Python 3 standard library. Run from the repository root:

    python -X utf8 -I tools/fx-pipeline/fxc.py build tools/fx-pipeline/recipes/kiem_khi.fx.json
    python -X utf8 -I tools/fx-pipeline/fxc.py check design/assets/candidates/fx-pipeline/<pack> [--layer overlay]
    python -X utf8 -I tools/fx-pipeline/fxc.py selftest

build = for every pack of the recipe and every cell size: render the component, check the code (determinism,
spill, ends empty, loop seam), write the pack (manifest.json + PNGs) to design/assets/candidates/fx-pipeline/,
check the files (palette, alpha, red, border, overlay length, shapes), write contact.png / anim.gif /
strip12.png to production/qa/evidence/fx-pipeline/<recipe>/<pack>/, then the skill timeline (timeline.gif,
timeline-keys.png, skill_timing.json). Exit 1 when any FAIL is found. Nothing is written into assets/.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from components import get as get_component  # noqa: E402
from fxkit import data, preview  # noqa: E402
from fxkit.check import check_component, check_pack, failed, format_findings  # noqa: E402
from fxkit.palette import Palettes, read_gpl  # noqa: E402
from fxkit.render import render  # noqa: E402
from fxkit.sheet import export_pack  # noqa: E402
from fxkit.timeline import build_timeline  # noqa: E402


def variant_id(pack_id: str, cell, ref_cell) -> str:
    if cell is None or list(cell) == list(ref_cell):
        return pack_id
    return f"{pack_id}_c{cell[0]}x{cell[1]}"


def delivery_problems(recipe: dict) -> list[str]:
    """The recipe's delivery must be the one the game data declares for the skill (plan N2)."""
    want, have = recipe.get("delivery", {}), recipe.get("data_delivery")
    if not have:
        return ["the recipe names no data_delivery reference"]
    return [f"delivery.{k}: recipe '{want.get(k)}' but game data '{have.get(k)}'"
            for k in ("type", "origin", "impact") if want.get(k) != have.get(k)]


def cmd_build(args) -> int:
    path = Path(args.recipe).resolve()
    _, rec = data.load_recipe(path)
    pal = Palettes(data.GPL, data.RAMPS)
    ramp = pal.ramp(rec["material"])
    fps = int(rec.get("fps", 20))
    ref_cell = rec.get("ref_cell", [64, 46])
    out_root = Path(args.out).resolve() if args.out else data.CANDIDATES
    ev_root = data.EVIDENCE / rec["id"]
    bad = False
    lines = [f"# fxc build: {rec['id']} ({rec.get('title', '')})", ""]
    probs = delivery_problems(rec)
    for p in probs:
        print(f"FAIL delivery: {p}")
        lines.append(f"- FAIL delivery: {p}")
    bad |= bool(probs)
    for spec in rec["packs"]:
        comp = get_component(spec["component"])
        cells = spec.get("cells") or [None]
        material = spec.get("material", rec["material"])
        ramp = pal.ramp(material)
        # variants: the same component with a few options changed (e.g. a root entering from each edge)
        variants = spec.get("variants") or [{"suffix": "", "options": {}}]
        for cell, var in [(c, v) for c in cells for v in variants]:
            o ={"ramp": ramp, "seed": spec.get("seed", rec.get("seed", 1)), **spec.get("options", {}), **var["options"]}
            if cell is not None:
                o["cell"] = list(cell)
            vid = variant_id(spec["id"] + var["suffix"], cell, ref_cell)
            r = render(comp, o, fps)
            f1 = check_component(comp, o, fps)
            pdir = export_pack(r, out_root / vid, vid, spec.get("title", f"Tessera fx - {vid}") + (f" [{var['suffix'].strip('_')}]" if var["suffix"] else ""),
                               spec["layer"], {"recipe": rec["id"], "material": material, "delivery": rec["delivery"]})
            f2 = check_pack(pdir, pal.master, spec["layer"])
            ev = ev_root / vid
            preview.contact(r, ev / "contact.png")
            preview.animation(r, ev / "anim.gif")
            preview.strip12(r, ev / "strip12.png")
            findings = f1 + f2
            bad |= failed(findings)
            head = f"{vid}: {comp.name}, {r.n} frames x {r.frame_ms} ms, {r.w}x{r.h}, {spec['layer']}"
            print(head)
            print(format_findings(findings))
            lines += [f"## {vid}", "", head, "", "```", format_findings(findings), "```", ""]
    tl = rec.get("timeline")
    if tl:
        suffix = variant_id("", tl["cell"], ref_cell)  # the timeline plays the packs made for its own cell size
        timing = build_timeline({**tl, "delivery": rec["delivery"]}, out_root, ev_root / "timeline", suffix)
        hits = [e.get("at") for e in timing["events"] if "at" in e]
        print(f"timeline: {ev_root / 'timeline'} (impacts at {', '.join(str(h) for h in hits)} s)")
        lines += ["## timeline", "", "```json", json.dumps(timing, indent=1), "```", ""]
    (ev_root / "build-report.md").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"report: {ev_root / 'build-report.md'}")
    return 1 if bad else 0


def cmd_check(args) -> int:
    master = read_gpl(data.GPL)
    bad = False
    for d in args.packs:
        f = check_pack(Path(d), master, args.layer)
        print(f"{d}\n{format_findings(f)}")
        bad |= failed(f)
    return 1 if bad else 0


def cmd_selftest(_args) -> int:
    """Small proofs that the core behaves: PNG round trip, seeded rng, painter flip, shard landing, timing."""
    import tempfile

    from fxkit.motion import shard
    from fxkit.painter import Layer, Painter
    from fxkit.pngio import load_image, write_png
    from fxkit.rng import Rng, rand
    from fxkit.timeline import arrival_times

    ok = True

    def expect(cond, what):
        nonlocal ok
        print(("ok   " if cond else "FAIL ") + what)
        ok &= bool(cond)

    with tempfile.TemporaryDirectory() as tmp:
        px = [0, 0xFF1B1722, 0xFFEFE6D2, 0]
        write_png(Path(tmp) / "a.png", 2, 2, px)
        expect(load_image(Path(tmp) / "a.png") == (2, 2, px), "PNG round trip keeps every pixel and transparency")
    expect([Rng(7).next() for _ in range(3)] == [Rng(7).next() for _ in range(3)], "Rng(seed) repeats")
    expect(rand(1, 2) == rand(1, 2) and rand(1, 2) != rand(1, 3), "rand(seed, i) is a pure hash")
    L = Layer(8, 4)
    Painter(L, 4, 0, flip=True).px(0, 0, 0xFF000001)
    expect(L.get(3, 0) == 0xFF000001, "flip mirrors local x = 0 onto the pixel left of the origin")
    x, y, ph = shard(0, -5, 10, -100, 5.0, 900, 3)
    expect(ph == 2 and abs(y - 3) < 1e-6, "a shard ends resting on its own floor")
    cells = [(3, 1), (4, 1), (5, 1), (4, 0)]
    timing = {"CASTER_TO_TARGET": {"spread_step_sec": 0.08, "first_hold_sec": 0.13}}
    t = arrival_times("CASTER_TO_TARGET", cells, (1, 1), timing)
    expect(t[(3, 1)] == 0 and abs(t[(4, 1)] - 0.21) < 1e-9 and abs(t[(5, 1)] - 0.29) < 1e-9 and abs(t[(4, 0)] - 0.29) < 1e-9,
           "CASTER_TO_TARGET spread matches SkillDelivery._spread (0, 0.21, 0.29, 0.29)")
    return 0 if ok else 1


def main() -> int:
    ap = argparse.ArgumentParser(prog="fxc", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build", help="render, export, check and preview every pack of a recipe")
    b.add_argument("recipe")
    b.add_argument("--out", help="packs folder (default design/assets/candidates/fx-pipeline)")
    c = sub.add_parser("check", help="check pack folders")
    c.add_argument("packs", nargs="+")
    c.add_argument("--layer", choices=["floor", "overlay"])
    sub.add_parser("selftest", help="core sanity checks")
    args = ap.parse_args()
    return {"build": cmd_build, "check": cmd_check, "selftest": cmd_selftest}[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
