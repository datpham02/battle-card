#!/usr/bin/env python
"""art_check: one command for the technical art QA of this project (P3 of the AI Game Art Workflow).

    python -X utf8 -I tools/qa/art_check.py all                      # everything, incl. the Godot art suites
    python -X utf8 -I tools/qa/art_check.py changed                  # what `git status` touches under assets/art, art_src, registry
    python -X utf8 -I tools/qa/art_check.py asset <registry id>      # one asset (unit, vfx pack, env, ui, card)
    python -X utf8 -I tools/qa/art_check.py character <entity id>    # one unit: sheet export, clips, reference, registry
    python -X utf8 -I tools/qa/art_check.py clip <entity id> <clip>  # one clip: frames, anim_qa on the source frames
    python -X utf8 -I tools/qa/art_check.py candidate <folder>       # a candidate pack folder (fxc check) or frame folder (anim_qa)
  options: --no-godot (skip the Godot suites) --json <path> (machine-readable report) --godot <exe>

It only runs the checkers that already exist and reads their output:
  registry   tools/asset-pipeline/asset_registry.py validate + check        (registry vs disk)
  sheets     tools/asset-pipeline/export_sheets.py --check [--units]        (drift, palette, alpha, margins, frames)
  packs      tools/fx-pipeline/fxc.py check <pack> --layer <from index>     (alpha, palette, red, border, overlay length)
  imports    assets/art/**/*.png.import                                     (Lossless, no mipmaps, fix alpha, no premult)
  png        IHDR + zlib of every PNG in scope                              (integrity, RGBA)
  frames     art_src/units/<id>/clips.json vs the files + the sheet JSON    (counts, sizes, ms)
  anim_qa    .claude/skills/pixellab-animation-engineer/scripts/anim_qa.py (clip or candidate frames; observations)
  godot      tests/unit/art/*_test.gd headless                              (FAILS=N)

Verdict per check: PASS | WARNING | FAIL | UNKNOWN (the checker could not run — named reason). The report's
verdict is the worst: FAIL > UNKNOWN > WARNING > PASS. Technical PASS says nothing about the look; the user's
acceptance lives in the registry. Standard library only; no file in the project is written except --json.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import struct
import subprocess
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PY = [sys.executable, "-X", "utf8", "-I"]
REGISTRY = ROOT / "tools" / "asset-pipeline" / "asset_registry.py"
EXPORTER = ROOT / "tools" / "asset-pipeline" / "export_sheets.py"
FXC = ROOT / "tools" / "fx-pipeline" / "fxc.py"
ANIM_QA = ROOT / ".claude" / "skills" / "pixellab-animation-engineer" / "scripts" / "anim_qa.py"
GPL = ROOT / "art_src" / "palette" / "tessera_master.gpl"
ART = ROOT / "assets" / "art"
IMPORT_RULES = {"compress/mode": "0", "mipmaps/generate": "false", "process/fix_alpha_border": "true", "process/premult_alpha": "false"}
RANK = {"FAIL": 3, "UNKNOWN": 2, "WARNING": 1, "PASS": 0}


class Report:
    def __init__(self):
        self.rows: list[dict] = []

    def add(self, check: str, verdict: str, detail: str, scope: str = ""):
        self.rows.append({"check": check, "scope": scope, "verdict": verdict, "detail": detail})

    def verdict(self) -> str:
        return max((r["verdict"] for r in self.rows), key=lambda v: RANK[v], default="UNKNOWN")

    def print(self):
        print("== art_check ==")
        for r in self.rows:
            scope = (" [" + r["scope"] + "]") if r["scope"] else ""
            print("%-8s %-10s%s %s" % (r["verdict"], r["check"], scope, r["detail"]))
        counts = {v: sum(1 for r in self.rows if r["verdict"] == v) for v in RANK}
        print("-- verdict %s (%s)" % (self.verdict(), ", ".join("%s %d" % kv for kv in counts.items())))


def run(cmd: list[str], timeout: int = 600) -> tuple[int | None, str]:
    try:
        p = subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout)
        return p.returncode, (p.stdout + p.stderr)
    except FileNotFoundError as e:
        return None, "not found: %s" % e
    except subprocess.TimeoutExpired:
        return None, "timeout after %ds" % timeout


def rel(p: Path) -> str:
    return str(p.relative_to(ROOT)).replace("\\", "/")


# ─── individual checkers ─────────────────────────────────────────────────────
def check_registry(rep: Report, asset_id: str | None = None):
    if not REGISTRY.is_file():
        rep.add("registry", "UNKNOWN", "asset_registry.py missing")
        return
    rc, out = run(PY + [str(REGISTRY), "check"])
    if rc is None:
        rep.add("registry", "UNKNOWN", out)
        return
    lines = [l for l in out.splitlines() if l.startswith(("FAIL", "WARN", "INFO"))]
    if asset_id:
        lines = [l for l in lines if asset_id in l]
    fails = [l for l in lines if l.startswith("FAIL")]
    warns = [l for l in lines if l.startswith("WARN")]
    infos = [l for l in lines if l.startswith("INFO")]
    if rc != 0 and not fails and not asset_id:
        rep.add("registry", "FAIL", "check exit %s: %s" % (rc, out.strip().splitlines()[-1] if out.strip() else ""))
    elif fails:
        rep.add("registry", "FAIL", "; ".join(f[6:] for f in fails)[:600])
    elif warns:
        rep.add("registry", "WARNING", "; ".join(w[6:] for w in warns)[:600])
    else:
        rep.add("registry", "PASS", "registry and disk agree%s" % (("; %d INFO (acceptance unknown / no spec)" % len(infos)) if infos else ""))


def check_sheets(rep: Report, units: list[str] | None = None):
    if not EXPORTER.is_file():
        rep.add("sheets", "UNKNOWN", "export_sheets.py missing")
        return
    if not (ROOT / "art_src" / "units").is_dir():
        rep.add("sheets", "UNKNOWN", "no art_src/units sources")
        return
    cmd = PY + [str(EXPORTER), "--check"]
    if units:
        cmd += ["--units", ",".join(units)]
    rc, out = run(cmd)
    if rc is None:
        rep.add("sheets", "UNKNOWN", out)
    elif rc == 0:
        rep.add("sheets", "PASS", "%d sheet file(s) match their sources" % sum(1 for l in out.splitlines() if l.startswith("ok")), ",".join(units or []))
    elif rc == 1:
        drift = [l for l in out.splitlines() if l.startswith(("DRIFT", "differs", "missing")) or "differ" in l]
        rep.add("sheets", "FAIL", "export drift: " + ("; ".join(drift)[:500] or out.strip()[-300:]), ",".join(units or []))
    else:
        rep.add("sheets", "FAIL", "rule violation: " + out.strip()[-400:], ",".join(units or []))


def _index_layers() -> dict[str, str]:
    layers = {}
    for kind in ("floor", "cast"):
        p = ART / "vfx" / kind / "index.json"
        if p.is_file():
            d = json.loads(p.read_text(encoding="utf-8"))
            for key, e in (d.get("packs") or {}).items():
                if isinstance(e, dict) and e.get("dir"):
                    layers[kind + "/" + e["dir"]] = e.get("layer", "overlay")
    return layers


def _known_fxc_fails() -> dict[str, dict]:
    """Registry entries whose `qa.known_fxc_fail` is set: pre-fxkit packs recorded as failing; reported as WARNING
    with the registry note, never hidden. Anything else that fails is a FAIL."""
    known = {}
    rc, out = run(PY + [str(REGISTRY), "export-json", str(ROOT / ".art_check_registry.json")])
    tmp = ROOT / ".art_check_registry.json"
    try:
        if rc == 0 and tmp.is_file():
            for a in json.loads(tmp.read_text(encoding="utf-8")).get("assets", []):
                qa = a.get("qa") or {}
                if qa.get("known_fxc_fail"):
                    for p in a.get("production") or []:
                        known[p] = qa
    finally:
        if tmp.is_file():
            tmp.unlink()
    return known


def check_packs(rep: Report, packs: list[Path] | None = None, layer: str | None = None):
    if not FXC.is_file():
        rep.add("packs", "UNKNOWN", "fxc.py missing")
        return
    known = _known_fxc_fails() if REGISTRY.is_file() else {}
    layers = _index_layers()
    if packs is None:
        packs = sorted(p.parent for p in (ART / "vfx").glob("*/*/manifest.json"))
    if not packs:
        rep.add("packs", "UNKNOWN", "no pack folders in scope")
        return
    for pack in packs:
        key = "/".join(pack.parts[-2:])
        lay = layer or layers.get(key) or ("floor" if pack.parent.name == "floor" else "overlay")
        if pack.parent.name == "status":
            lay = "overlay"
        rc, out = run(PY + [str(FXC), "check", str(pack), "--layer", lay])
        scope = rel(pack) if pack.is_relative_to(ROOT) else str(pack)
        if rc is None:
            rep.add("packs", "UNKNOWN", out, scope)
            continue
        fails = [l.strip() for l in out.splitlines() if l.strip().startswith("FAIL")]
        warns = [l.strip() for l in out.splitlines() if l.strip().startswith("warn")]
        if fails and scope in known:
            rep.add("packs", "WARNING", "KNOWN pre-fxkit failure (registry qa, observed %s; decision pending: re-export or waive): %s" % (known[scope].get("observed_on"), "; ".join(fails))[:400], scope)
        elif fails:
            rep.add("packs", "FAIL", "; ".join(fails)[:400], scope)
        elif warns:
            rep.add("packs", "WARNING", "; ".join(warns)[:400], scope)
        else:
            rep.add("packs", "PASS", "fxc check clean (layer %s)" % lay, scope)


def check_imports(rep: Report, pngs: list[Path]):
    bad, missing, d3 = [], [], {"0": 0, "1": 0}
    for png in pngs:
        imp = Path(str(png) + ".import")
        if not imp.is_file():
            missing.append(rel(png))
            continue
        text = imp.read_text(encoding="utf-8", errors="replace")
        for key, want in IMPORT_RULES.items():
            m = re.search(r"^%s=(.*)$" % re.escape(key), text, re.M)
            if not m or m.group(1).strip() != want:
                bad.append("%s %s=%s" % (rel(png), key, m.group(1).strip() if m else "absent"))
        m = re.search(r"^detect_3d/compress_to=(\d)", text, re.M)
        if m:
            d3[m.group(1)] = d3.get(m.group(1), 0) + 1
    if not pngs:
        rep.add("imports", "UNKNOWN", "no PNG in scope")
    elif bad:
        rep.add("imports", "FAIL", "; ".join(bad)[:600])
    elif missing:
        rep.add("imports", "WARNING", "%d PNG without .import (Godot has not imported them yet): %s" % (len(missing), ", ".join(missing[:5])))
    else:
        note = "" if min(d3.values()) == 0 or len([v for v in d3.values() if v]) < 2 else "; detect_3d/compress_to mixed (0: %d, 1: %d)" % (d3["0"], d3["1"])
        rep.add("imports", "WARNING" if note else "PASS", "%d imports Lossless / no mipmaps / fix alpha / no premult%s" % (len(pngs), note))


def png_info(path: Path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError("not a PNG")
    w, h = struct.unpack(">II", data[16:24])
    ct = data[25]
    pos, idat = 8, b""
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        kind = data[pos + 4:pos + 8]
        if kind == b"IDAT":
            idat += data[pos + 8:pos + 8 + length]
        pos += 12 + length
    zlib.decompress(idat)
    return w, h, ct


def check_png(rep: Report, pngs: list[Path]):
    broken, non_rgba = [], []
    for png in pngs:
        try:
            w, h, ct = png_info(png)
            if ct != 6:
                non_rgba.append("%s (colour type %d)" % (rel(png), ct))
        except Exception as e:  # noqa: BLE001
            broken.append("%s: %s" % (rel(png), e))
    if not pngs:
        rep.add("png", "UNKNOWN", "no PNG in scope")
    elif broken:
        rep.add("png", "FAIL", "; ".join(broken)[:600])
    elif non_rgba:
        rep.add("png", "WARNING", "not RGBA: " + "; ".join(non_rgba)[:400])
    else:
        rep.add("png", "PASS", "%d PNG decode, all RGBA 8-bit" % len(pngs))


def check_frames(rep: Report, unit: str, clip: str | None = None):
    cj = ROOT / "art_src" / "units" / unit / "clips.json"
    sj = ART / "units" / ("unit_%s_sheet.json" % unit)
    if not cj.is_file():
        rep.add("frames", "UNKNOWN", "no clips.json for %s" % unit, unit)
        return
    # A malformed clips.json or sheet JSON is a FAIL line, not a traceback: the
    # commit hook greps FAIL lines to tell the user what to fix (watched 2026-11-14).
    try:
        clips = json.loads(cj.read_text(encoding="utf-8-sig"))
    except (ValueError, OSError) as e:
        rep.add("frames", "FAIL", "%s is not valid JSON: %s" % (cj.relative_to(ROOT).as_posix(), e), unit)
        return
    try:
        sheet = json.loads(sj.read_text(encoding="utf-8-sig")) if sj.is_file() else None
    except (ValueError, OSError) as e:
        rep.add("frames", "FAIL", "%s is not valid JSON: %s" % (sj.relative_to(ROOT).as_posix(), e), unit)
        return
    tags = {t["name"]: t for t in (sheet["meta"]["frameTags"] if sheet else [])}
    fw, fh = clips["frame"]["w"], clips["frame"]["h"]
    problems, seen = [], 0
    for c in clips["clips"]:
        if clip and c["name"] != clip:
            continue
        seen += 1
        if len(c["ms"]) != len(c["frames"]):
            problems.append("%s: %d ms values for %d frames" % (c["name"], len(c["ms"]), len(c["frames"])))
        for f in c["frames"]:
            p = ROOT / "art_src" / "units" / unit / f if not str(f).startswith("art_src") else ROOT / f
            if not p.is_file():
                p2 = ROOT / "art_src" / "units" / unit / c["name"] / Path(str(f)).name
                p = p2 if p2.is_file() else p
            if not p.is_file():
                problems.append("%s: frame file missing %s" % (c["name"], f))
                continue
            try:
                w, h, _ = png_info(p)
                if w != fw or h > fh:
                    problems.append("%s: %s is %dx%d, frame is %dx%d" % (c["name"], Path(str(f)).name, w, h, fw, fh))
            except Exception as e:  # noqa: BLE001
                problems.append("%s: %s unreadable (%s)" % (c["name"], f, e))
        if sheet:
            t = tags.get(c["name"])
            if not t:
                problems.append("%s: not in the exported sheet" % c["name"])
            elif t["to"] - t["from"] + 1 != len(c["frames"]):
                problems.append("%s: sheet has %d frames, clips.json %d" % (c["name"], t["to"] - t["from"] + 1, len(c["frames"])))
    if clip and not seen:
        rep.add("frames", "UNKNOWN", "clip %s not in clips.json" % clip, unit)
    elif not sheet:
        rep.add("frames", "UNKNOWN", "no exported sheet JSON for %s" % unit, unit)
    elif problems:
        rep.add("frames", "FAIL", "; ".join(problems)[:600], unit + (("/" + clip) if clip else ""))
    else:
        rep.add("frames", "PASS", "%d clip(s): files present, sizes within %dx%d, counts match the sheet" % (seen, fw, fh), unit + (("/" + clip) if clip else ""))


def check_anim_qa(rep: Report, frames_dir: Path, anchor: Path | None, size: str | None, feet_row: int | None, loop: bool | None, expect: int | None):
    if not ANIM_QA.is_file():
        rep.add("anim_qa", "UNKNOWN", "anim_qa.py missing")
        return
    cmd = PY + [str(ANIM_QA), "--frames", str(frames_dir)]
    if anchor and anchor.is_file():
        cmd += ["--anchor", str(anchor)]
    if GPL.is_file():
        cmd += ["--palette", str(GPL)]
    if size:
        cmd += ["--size", size]
    if feet_row is not None:
        cmd += ["--feet-row", str(feet_row)]
    if loop is True:
        cmd += ["--loop"]
    elif loop is False:
        cmd += ["--once"]
    if expect:
        cmd += ["--expect-frames", str(expect)]
    rc, out = run(cmd)
    scope = rel(frames_dir) if frames_dir.is_relative_to(ROOT) else str(frames_dir)
    if rc is None:
        rep.add("anim_qa", "UNKNOWN", out, scope)
        return
    crossed = [l.strip() for l in out.splitlines() if "CROSSED" in l]
    not_run = [l.strip() for l in out.splitlines() if "NOT RUN" in l]
    if crossed:
        rep.add("anim_qa", "FAIL", "thresholds crossed: " + "; ".join(crossed)[:500], scope)
    elif not_run:
        rep.add("anim_qa", "UNKNOWN", "%d check(s) not run: %s" % (len(not_run), "; ".join(not_run)[:400]), scope)
    else:
        rep.add("anim_qa", "PASS", "no threshold crossed", scope)


def check_godot(rep: Report, godot: str, suites: list[str] | None = None):
    tests = suites or sorted(rel(p) for p in (ROOT / "tests" / "unit" / "art").glob("*_test.gd"))
    if not tests:
        rep.add("godot", "UNKNOWN", "no tests/unit/art suites")
        return
    for t in tests:
        rc, out = run([godot, "--headless", "--path", str(ROOT), "-s", "res://" + t], timeout=240)
        if rc is None:
            rep.add("godot", "UNKNOWN", out, t)
            continue
        m = re.findall(r"FAILS[=:] ?(\d+)", out)
        se = out.count("SCRIPT ERROR")
        if not m:
            rep.add("godot", "UNKNOWN", "no FAILS= line (exit %s)" % rc, t)
        elif int(m[-1]) or se:
            rep.add("godot", "FAIL", "FAILS=%s, %d script error(s)" % (m[-1], se), t)
        else:
            rep.add("godot", "PASS", "FAILS=0", t)


# ─── scopes ──────────────────────────────────────────────────────────────────
def registry_entry(asset_id: str) -> dict | None:
    rc, out = run(PY + [str(REGISTRY), "export-json", str(ROOT / ".art_check_registry.json")])
    tmp = ROOT / ".art_check_registry.json"
    try:
        if rc != 0 or not tmp.is_file():
            return None
        data = json.loads(tmp.read_text(encoding="utf-8"))
    finally:
        if tmp.is_file():
            tmp.unlink()
    return next((a for a in data.get("assets", []) if a.get("id") == asset_id), None)


def pngs_under(paths: list[Path]) -> list[Path]:
    out = []
    for p in paths:
        if p.is_dir():
            out += sorted(p.rglob("*.png"))
        elif p.suffix == ".png" and p.is_file():
            out.append(p)
    return out


def mode_all(rep, args):
    check_registry(rep)
    check_sheets(rep)
    check_packs(rep)
    pngs = sorted(ART.rglob("*.png"))
    check_png(rep, pngs)
    check_imports(rep, pngs)
    for cj in sorted((ROOT / "art_src" / "units").glob("*/clips.json")):
        check_frames(rep, cj.parent.name)
    evid = list((ROOT / "production").rglob("*.png.import")) if (ROOT / "production").is_dir() else []
    if evid:
        if (ROOT / "production" / ".gdignore").is_file():
            rep.add("hygiene", "WARNING", "%d leftover .import files under production/ (.gdignore is present, so Godot will not import new evidence; delete the leftovers to clear this warning)" % len(evid))
        else:
            rep.add("hygiene", "WARNING", "%d .import files under production/ (evidence imported by Godot; add production/.gdignore)" % len(evid))
    if not args.no_godot:
        check_godot(rep, args.godot)


def mode_changed(rep, args):
    rc, out = run(["git", "status", "--short", "--", "assets/art", "art_src", "design/assets/asset-registry.yaml"])
    if rc is None:
        rep.add("scope", "UNKNOWN", out)
        return
    files = [l[3:].strip().strip('"') for l in out.splitlines() if l.strip()]
    if not files:
        rep.add("scope", "PASS", "nothing changed under assets/art, art_src or the registry")
        return
    units = {Path(f).parts[2] for f in files if f.startswith("art_src/units/") and len(Path(f).parts) > 2}
    units |= {m.group(1) for f in files for m in [re.search(r"assets/art/units/unit_(\w+)_sheet", f)] if m}
    # assets/art/vfx/<kind>/<pack>/... — parts[:4] is the kind folder and has no manifest.
    packs = sorted({ROOT / Path(*Path(f).parts[:5]) for f in files if f.startswith("assets/art/vfx/") and len(Path(f).parts) >= 6})
    pngs = [ROOT / f for f in files if f.endswith(".png") and (ROOT / f).is_file()]
    rep.add("scope", "PASS", "%d changed file(s); units %s; packs %s" % (len(files), ",".join(sorted(units)) or "-", ",".join(p.name for p in packs) or "-"))
    check_registry(rep)
    if units:
        check_sheets(rep, sorted(units))
        for u in sorted(units):
            check_frames(rep, u)
    if packs:
        check_packs(rep, packs)
    if pngs:
        check_png(rep, pngs)
        check_imports(rep, [p for p in pngs if p.is_relative_to(ART)])
    if not args.no_godot and (units or packs):
        suites = []
        if units:
            suites += ["tests/unit/art/sheet_export_test.gd", "tests/unit/art/sprite_sheet_test.gd"]
        if packs:
            suites += ["tests/unit/art/vfx_pack_test.gd", "tests/unit/art/floor_vfx_test.gd", "tests/unit/art/cast_vfx_test.gd"]
        check_godot(rep, args.godot, [s for s in suites if (ROOT / s).is_file()])


def mode_asset(rep, args):
    a = registry_entry(args.target)
    if a is None:
        rep.add("scope", "UNKNOWN", "no registry entry %s" % args.target)
        return
    check_registry(rep, args.target)
    prod = [ROOT / p for p in a.get("production") or []]
    pngs = pngs_under(prod)
    if a["type"] == "unit":
        check_sheets(rep, [a["entity_id"]])
        check_frames(rep, a["entity_id"])
    elif a["type"] == "vfx_pack":
        check_packs(rep, [p for p in prod if p.is_dir()])
    if pngs:
        check_png(rep, pngs)
        check_imports(rep, pngs)
    if a.get("status") == "installed" and a.get("acceptance") == "unknown":
        rep.add("lifecycle", "WARNING", "installed, acceptance unknown: the user's verdict is not recorded", args.target)
    if a.get("attention"):
        rep.add("lifecycle", "WARNING", "needs the user: " + a["attention"][:200], args.target)
    if not args.no_godot and a["type"] in ("unit", "vfx_pack"):
        suites = ["tests/unit/art/sheet_export_test.gd", "tests/unit/art/sprite_sheet_test.gd"] if a["type"] == "unit" else ["tests/unit/art/vfx_pack_test.gd", "tests/unit/art/floor_vfx_test.gd"]
        check_godot(rep, args.godot, suites)


def mode_character(rep, args):
    unit = args.target
    args.target = "unit." + unit
    mode_asset(rep, args)
    ref = ROOT / "design" / "assets" / "references" / "characters" / (unit + ".md")
    rep.add("reference", "PASS" if ref.is_file() else "WARNING", rel(ref) if ref.is_file() else "no Master Reference for %s" % unit, unit)


def mode_clip(rep, args):
    unit, clip = args.target, args.clip
    check_registry(rep, "unit." + unit)
    check_frames(rep, unit, clip)
    cj = ROOT / "art_src" / "units" / unit / "clips.json"
    if cj.is_file():
        clips = json.loads(cj.read_text(encoding="utf-8"))
        c = next((x for x in clips["clips"] if x["name"] == clip), None)
        frames_dir = ROOT / "art_src" / "units" / unit / clip
        if c and frames_dir.is_dir():
            check_anim_qa(rep, frames_dir, ROOT / "art_src" / "units" / unit / "idle" / "0.png",
                          "%dx%d" % (clips["frame"]["w"], clips["frame"]["h"]), None,
                          c.get("loop") == "loop", len(c["frames"]))


def mode_candidate(rep, args):
    folder = Path(args.target)
    if not folder.is_absolute():
        folder = ROOT / folder
    if not folder.is_dir():
        rep.add("scope", "UNKNOWN", "no folder %s" % folder)
        return
    if (folder / "manifest.json").is_file():
        check_packs(rep, [folder], args.layer)
        pngs = sorted(folder.glob("*.png"))
        check_png(rep, [p for p in pngs if p.name in ("whole.png", "behind.png", "front.png")])
    else:
        frames_dir = folder / "raw" if (folder / "raw").is_dir() else folder
        if (folder / "clean").is_dir():
            frames_dir = folder / "clean"
        check_png(rep, sorted(frames_dir.glob("*.png")))
        check_anim_qa(rep, frames_dir, None, None, None, None, None)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("mode", choices=["all", "changed", "asset", "character", "clip", "candidate"])
    ap.add_argument("target", nargs="?")
    ap.add_argument("clip", nargs="?")
    ap.add_argument("--no-godot", action="store_true")
    ap.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    ap.add_argument("--layer", choices=["overlay", "floor"])
    ap.add_argument("--json")
    args = ap.parse_args(argv)
    if args.mode in ("asset", "character", "clip", "candidate") and not args.target:
        ap.error("%s needs a target" % args.mode)
    if args.mode == "clip" and not args.clip:
        ap.error("clip needs <entity id> <clip>")
    rep = Report()
    {"all": mode_all, "changed": mode_changed, "asset": mode_asset, "character": mode_character,
     "clip": mode_clip, "candidate": mode_candidate}[args.mode](rep, args)
    rep.print()
    if args.json:
        Path(args.json).write_text(json.dumps({"mode": args.mode, "target": args.target, "verdict": rep.verdict(), "rows": rep.rows},
                                              ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    return 1 if rep.verdict() == "FAIL" else 0


if __name__ == "__main__":
    sys.exit(main())
