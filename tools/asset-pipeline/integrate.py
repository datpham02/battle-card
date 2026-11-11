#!/usr/bin/env python
"""integrate: install an ACCEPTED candidate into the Godot asset tree through one repeatable, checked path.

    python -X utf8 -I tools/asset-pipeline/integrate.py pack <registry id> [--candidate <folder>] [--kind floor|cast|status]
        [--index-key <name>] [--dry-run] [--no-godot] [--by <who>]
    python -X utf8 -I tools/asset-pipeline/integrate.py clip <entity id> <clip> --candidate <folder> [--frames clean|raw]
        [--ms 83,83,...] [--loop loop|once|hold_last|hold] [--note "..."] [--dry-run] [--no-godot] [--by <who>]

Preconditions, checked before any write (docs/art/ASSET_REGISTRY.md, game-art-workflow references/integration.md):
  * the registry entry (or the clip) has acceptance: accepted with accepted_evidence — otherwise BLOCKED;
  * the destination does not exist (a pack dir, a clip folder, an index key) — never overwritten;
  * the candidate passes its technical check (fxc check for packs; export rules for clips).
Steps: copy files → index entry / clips.json entry (packs: the manifest's `index_entry`; clips: the candidate's
frames + ms + loop) → export (clips: export_sheets.py --units) → checks (art_check.py asset ...) → registry
`set-status installed` with the evidence path → manifest regenerated. --dry-run prints the plan and writes nothing.
Approval (`approved`) is never set here: that is the user's word after seeing it in game.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from datetime import date
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
# INTEGRATE_ROOT: a scratch tree with the same layout (registry, assets/art, art_src, candidates) for rehearsals and
# tests; the scripts always come from this repository. Default: the repository itself.
ROOT = Path(os.environ["INTEGRATE_ROOT"]).resolve() if os.environ.get("INTEGRATE_ROOT") else REPO
PY = [sys.executable, "-X", "utf8", "-I"]
REGISTRY = REPO / "tools" / "asset-pipeline" / "asset_registry.py"
EXPORTER = REPO / "tools" / "asset-pipeline" / "export_sheets.py"
FXC = REPO / "tools" / "fx-pipeline" / "fxc.py"
ART_CHECK = REPO / "tools" / "qa" / "art_check.py"
ART = ROOT / "assets" / "art"
EVIDENCE = ROOT / "production" / "qa" / "evidence" / "integration"
ROOT_ARG = ["--root", str(ROOT)]


def rel(p: Path) -> str:
    return str(p.relative_to(ROOT)).replace("\\", "/")


def run(cmd, timeout=600):
    p = subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout)
    return p.returncode, p.stdout + p.stderr


def registry() -> dict:
    tmp = ROOT / ".integrate_registry.json"
    rc, out = run(PY + [str(REGISTRY)] + ROOT_ARG + ["export-json", str(tmp)])
    try:
        if rc != 0 or not tmp.is_file():
            raise SystemExit("BLOCKED — registry unreadable: %s" % out.strip()[-300:])
        return json.loads(tmp.read_text(encoding="utf-8"))
    finally:
        if tmp.is_file():
            tmp.unlink()


def entry(data: dict, aid: str) -> dict:
    a = next((x for x in data.get("assets", []) if x.get("id") == aid), None)
    if a is None:
        raise SystemExit("BLOCKED — no registry entry %s" % aid)
    return a


def require_accepted(target: dict, label: str):
    if target.get("acceptance") != "accepted" or not target.get("accepted_evidence"):
        raise SystemExit("BLOCKED — %s is not accepted (acceptance: %s). Record the user's words first: "
                         "asset_registry.py set-acceptance ... --by user --evidence \"<file>: <quote>\"" % (label, target.get("acceptance")))
    if target.get("status") not in ("accepted", "candidate"):
        raise SystemExit("BLOCKED — %s status is %s; only accepted / candidate entries are integrated" % (label, target.get("status")))


def newest_candidate(a: dict, given: str | None) -> Path:
    if given:
        p = Path(given) if Path(given).is_absolute() else ROOT / given
    else:
        cands = [ROOT / c for c in (a.get("candidates") or []) if (ROOT / c).is_dir()]
        if not cands:
            raise SystemExit("BLOCKED — no candidate folder recorded for %s" % a["id"])
        p = cands[-1]
    if not p.is_dir():
        raise SystemExit("BLOCKED — candidate folder missing: %s" % p)
    return p


def write_evidence(name: str, lines: list[str]) -> Path:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    p = EVIDENCE / ("%s-%s.md" % (date.today().isoformat(), name))
    p.write_text("# Integration — %s (%s)\n\n" % (name, date.today().isoformat()) + "\n".join("- " + l for l in lines) + "\n", encoding="utf-8")
    return p


# ─── packs ───────────────────────────────────────────────────────────────────
def cmd_pack(a) -> int:
    data = registry()
    e = entry(data, a.id)
    if e.get("type") != "vfx_pack":
        raise SystemExit("BLOCKED — %s is a %s, not a vfx_pack" % (a.id, e.get("type")))
    require_accepted(e, a.id)
    cand = newest_candidate(e, a.candidate)
    manifest_p = cand / "manifest.json"
    if not manifest_p.is_file():
        raise SystemExit("BLOCKED — %s has no manifest.json" % cand)
    m = json.loads(manifest_p.read_text(encoding="utf-8"))
    ie = dict(m.get("index_entry") or (m.get("tessera") or {}).get("index_entry") or {})
    if not ie.get("dir"):
        raise SystemExit("BLOCKED — manifest carries no index_entry")
    kind = a.kind or ("status" if a.id.startswith("vfx.status.") else "cast" if a.id.startswith("vfx.cast.") else "floor")
    pack_id = ie["dir"]
    dest = ART / "vfx" / kind / pack_id
    index_p = ART / "vfx" / kind / "index.json"
    key = a.index_key or pack_id
    plan = ["candidate %s" % rel(cand), "destination %s" % rel(dest), "index %s key packs.%s" % (rel(index_p), key)]
    if dest.exists():
        raise SystemExit("BLOCKED — %s exists; never overwritten. Use a new pack id or ask the user to retire the old one" % rel(dest))
    if kind != "status":
        idx = json.loads(index_p.read_text(encoding="utf-8")) if index_p.is_file() else {"packs": {}}
        if key in (idx.get("packs") or {}):
            raise SystemExit("BLOCKED — index key packs.%s exists in %s" % (key, rel(index_p)))
    rc, out = run(PY + [str(FXC), "check", str(cand), "--layer", ie.get("layer", "overlay")])
    if rc != 0:
        raise SystemExit("BLOCKED — fxc check fails on the candidate:\n" + out.strip()[-600:])
    plan.append("fxc check: PASS")
    files = [f for f in ("manifest.json", "whole.png", "behind.png", "front.png") if (cand / f).is_file()]
    plan.append("files: " + ", ".join(files))
    if a.dry_run:
        print("DRY RUN — would do:\n  " + "\n  ".join(plan))
        return 0
    dest.mkdir(parents=True)
    for f in files:
        shutil.copy2(cand / f, dest / f)
    if kind != "status":
        idx = json.loads(index_p.read_text(encoding="utf-8")) if index_p.is_file() else {"packs": {}}
        idx.setdefault("packs", {})[key] = {k: v for k, v in ie.items() if k != "dir"} | {"dir": pack_id}
        if "_doc_integrate" not in idx:
            idx["_doc_integrate"] = "entries added by tools/asset-pipeline/integrate.py carry the candidate's index_entry verbatim; see the registry for provenance"
        index_p.write_text(json.dumps(idx, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    else:
        plan.append("status packs need a hand edit of status/index.json (kind x body) — not automated")
    rc, out = run(PY + [str(ART_CHECK), "candidate", str(dest), "--layer", ie.get("layer", "overlay")] + (["--no-godot"] if a.no_godot else []))
    plan.append("art_check candidate on the installed pack: " + ("PASS" if rc == 0 else "FAIL\n" + out[-400:]))
    if not a.no_godot:
        for t in ("tests/unit/art/vfx_pack_test.gd", "tests/unit/art/floor_vfx_test.gd", "tests/unit/art/cast_vfx_test.gd"):
            if (ROOT / t).is_file():
                rc2, out2 = run([a.godot, "--headless", "--path", str(ROOT), "-s", "res://" + t], timeout=240)
                plan.append("%s: %s" % (t, "FAILS=0" if "FAILS=0" in out2 else "see output: " + out2.strip()[-200:]))
    ev = write_evidence(a.id.replace(".", "-"), plan)
    plan += record_installed(e, a.id, None, ev, "integrate.py pack -> " + rel(dest), a.by)
    run(PY + [str(REGISTRY)] + ROOT_ARG + ["set-production", a.id, rel(dest)])
    print("\n".join(plan))
    print("installed %s -> %s. Approval stays with the user after the in-game look." % (a.id, rel(dest)))
    run(PY + [str(REGISTRY)] + ROOT_ARG + ["manifest"])
    return 0


def record_installed(e: dict, aid: str, clip: str | None, ev: Path, note: str, by: str) -> list[str]:
    """candidate -> accepted (the user's recorded acceptance moves the state) -> installed."""
    lines = []
    target = e if clip is None else next(c for c in e["clips"] if c["name"] == clip)
    clip_arg = ["--clip", clip] if clip else []
    if target.get("status") == "candidate":
        rc, out = run(PY + [str(REGISTRY)] + ROOT_ARG + ["set-status", aid, "accepted"] + clip_arg +
                      ["--by", "user", "--evidence", target.get("accepted_evidence") or "", "--on", target.get("accepted_on") or date.today().isoformat(),
                       "--note", "state moved to the acceptance already recorded (integrate.py)"])
        lines.append("registry: " + out.strip())
    rc, out = run(PY + [str(REGISTRY)] + ROOT_ARG + ["set-status", aid, "installed"] + clip_arg + ["--by", by, "--evidence", rel(ev), "--note", note])
    lines.append("registry: " + out.strip())
    return lines


# ─── clips ───────────────────────────────────────────────────────────────────
def cmd_clip(a) -> int:
    data = registry()
    e = entry(data, "unit." + a.entity)
    clip = next((c for c in e.get("clips") or [] if c.get("name") == a.clip), None)
    label = "unit.%s / %s" % (a.entity, a.clip)
    if clip is None:
        # a brand-new clip: the acceptance must be on a history event for it, i.e. recorded by candidate.py verdict
        ev = [h for h in e.get("history") or [] if h.get("clip") == a.clip and h.get("event") == "user_accepted"]
        if not ev:
            raise SystemExit("BLOCKED — %s has no clip entry and no user_accepted event; record the user's words first (candidate.py verdict … --acceptance accepted)" % label)
    else:
        require_accepted(clip, label)
    cand = newest_candidate(e, a.candidate)
    frames_dir = cand / (a.frames or ("clean" if (cand / "clean").is_dir() and any((cand / "clean").glob("*.png")) else "raw"))
    frames = sorted(frames_dir.glob("*.png"), key=lambda p: [int(t) if t.isdigit() else t for t in __import__("re").split(r"(\d+)", p.name)])
    if not frames:
        raise SystemExit("BLOCKED — no frames in %s" % frames_dir)
    unit_dir = ROOT / "art_src" / "units" / a.entity
    dest = unit_dir / a.clip
    cj = unit_dir / "clips.json"
    if not cj.is_file():
        raise SystemExit("BLOCKED — %s missing" % rel(cj))
    clips = json.loads(cj.read_text(encoding="utf-8"))
    if dest.exists() or any(c["name"] == a.clip for c in clips["clips"]):
        raise SystemExit("BLOCKED — clip %s already exists in %s; a replacement is a new version: ask the user to retire the old clip first" % (a.clip, rel(unit_dir)))
    ms = [int(x) for x in a.ms.split(",")] if a.ms else [100] * len(frames)
    if len(ms) != len(frames):
        raise SystemExit("BLOCKED — %d ms values for %d frames" % (len(ms), len(frames)))
    plan = ["candidate frames %s (%d)" % (rel(frames_dir), len(frames)), "destination %s" % rel(dest),
            "clips.json entry: %s frames=%d ms=%s loop=%s" % (a.clip, len(frames), ms, a.loop)]
    if a.dry_run:
        print("DRY RUN — would do:\n  " + "\n  ".join(plan))
        return 0
    dest.mkdir(parents=True)
    names = []
    for i, f in enumerate(frames):
        shutil.copy2(f, dest / ("%d.png" % i))
        names.append("%s/%d.png" % (a.clip, i))
    clips["clips"].append({"name": a.clip, "frames": names, "ms": ms, "loop": a.loop, "note": a.note or ("integrated %s from %s" % (date.today().isoformat(), rel(cand)))})
    cj.write_text(json.dumps(clips, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    rc, out = run(PY + [str(EXPORTER), "--units", a.entity] + ROOT_ARG)
    if rc != 0:
        # roll back the source edit so the tree stays consistent; the frames stay for inspection
        clips["clips"] = [c for c in clips["clips"] if c["name"] != a.clip]
        cj.write_text(json.dumps(clips, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        raise SystemExit("FAIL — export refused the frames (clips.json entry removed, frames left in %s):\n%s" % (rel(dest), out.strip()[-600:]))
    plan.append("export_sheets --units %s: ok" % a.entity)
    rc, out = run(PY + [str(ART_CHECK), "clip", a.entity, a.clip] + (["--no-godot"] if a.no_godot else []))
    plan.append("art_check clip: " + ("PASS/WARNING" if rc == 0 else "FAIL\n" + out[-400:]))
    if not a.no_godot:
        for t in ("tests/unit/art/sheet_export_test.gd", "tests/unit/art/sprite_sheet_test.gd"):
            rc2, out2 = run([a.godot, "--headless", "--path", str(ROOT), "-s", "res://" + t], timeout=240)
            plan.append("%s: %s" % (t, "FAILS=0" if "FAILS=0" in out2 else "see output: " + out2.strip()[-200:]))
    ev = write_evidence("unit-%s-%s" % (a.entity, a.clip), plan)
    if clip is not None:
        plan += record_installed(e, "unit." + a.entity, a.clip, ev, "integrate.py clip", a.by)
    else:
        plan.append("registry: new clip — add its entry under clips[] (status installed, generation, evidence %s) and run asset_registry.py check" % rel(ev))
    print("\n".join(plan))
    run(PY + [str(REGISTRY)] + ROOT_ARG + ["manifest"])
    print("installed clip %s. Approval stays with the user after the in-game look." % label)
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("pack")
    p.add_argument("id")
    p.add_argument("--candidate")
    p.add_argument("--kind", choices=["floor", "cast", "status"])
    p.add_argument("--index-key")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--no-godot", action="store_true")
    p.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    p.add_argument("--by", default="integrate.py")
    c = sub.add_parser("clip")
    c.add_argument("entity")
    c.add_argument("clip")
    c.add_argument("--candidate", required=True)
    c.add_argument("--frames", choices=["clean", "raw"])
    c.add_argument("--ms")
    c.add_argument("--loop", default="once", choices=["loop", "once", "hold_last", "hold"])
    c.add_argument("--note")
    c.add_argument("--dry-run", action="store_true")
    c.add_argument("--no-godot", action="store_true")
    c.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    c.add_argument("--by", default="integrate.py")
    args = ap.parse_args(argv)
    try:
        return {"pack": cmd_pack, "clip": cmd_clip}[args.cmd](args)
    except SystemExit as e:
        if isinstance(e.code, str):
            print(e.code, file=sys.stderr)
            return 2
        raise


if __name__ == "__main__":
    sys.exit(main())
