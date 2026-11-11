#!/usr/bin/env python
"""candidate: create a candidate folder in the project convention and record it in the registry.

    python -X utf8 -I tools/asset-pipeline/candidate.py new --group swordsman --name cast_hand \
        --asset unit.kiem_si [--clip cast_hand] --tool animate_image_pixminimax [--job-id ID] [--character-id ID] \
        [--seed N] [--prompt "..."] [--params '{"frames": 8}'] [--source-anchor art_src/units/kiem_si/idle/0.png] \
        [--provider pixellab|pixelfx|fx-pipeline|script] [--effect-id ice/frost-nova] [--cost "1 gen"] [--no-log]
    python -X utf8 -I tools/asset-pipeline/candidate.py qa <folder> --verdict PASS|WARN|FAIL|NOT_ASSESSED --summary "..." [--report path]
    python -X utf8 -I tools/asset-pipeline/candidate.py verdict <folder> --acceptance accepted|rejected|pending --by user --evidence "..."

Layout (docs/art/PIXEL_ART_WORKFLOW.md §5a): design/assets/candidates/<group>/<name>-v<N>-<YYYY-MM-DD>/
  raw/  clean/  preview/  QA.md  metadata.json
`v<N>` is the next free version for <name> in that group. `new` also appends a `candidate_created` event to the
registry entry (`asset_registry.py log-event`) unless --no-log. `qa` fills the QA section of QA.md and metadata.qa;
`verdict` records the user's words in QA.md, metadata.acceptance and the registry (`set-acceptance`). Nothing here
calls a generator or touches assets/.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CANDIDATES = ROOT / "design" / "assets" / "candidates"
REGISTRY = ROOT / "tools" / "asset-pipeline" / "asset_registry.py"
PY = [sys.executable, "-X", "utf8", "-I"]

QA_TEMPLATE = """# QA — {name} v{version} ({date})

## Request
- Asset: `{asset}`{clip_line}
- Why: {why}

## Call
- Provider / tool: {provider} / {tool}
- Ids: job {job_id} · character {character_id} · effect {effect_id}
- Seed: {seed} · Cost: {cost}
- Params: `{params}`
- Prompt: {prompt}
- Source anchor: `{source_anchor}`

## Measured
_(fill from tools/qa/art_check.py candidate <folder>, anim_qa.py, fxc check: frames, bbox, feet row/x, colours off-palette, red/orange pixels, clipping)_

## Verdict
- Technical: pending
- User: pending

## Next
pending
"""


def rel(p: Path) -> str:
    return str(p.relative_to(ROOT)).replace("\\", "/")


def next_version(group_dir: Path, name: str) -> int:
    best = 0
    if group_dir.is_dir():
        for d in group_dir.iterdir():
            m = re.match(r"^%s-v(\d+)-\d{4}-\d{2}-\d{2}$" % re.escape(name), d.name)
            if m:
                best = max(best, int(m.group(1)))
    return best + 1


def cmd_new(a) -> int:
    group_dir = CANDIDATES / a.group
    v = next_version(group_dir, a.name)
    today = date.today().isoformat()
    folder = group_dir / f"{a.name}-v{v}-{today}"
    params = json.loads(a.params) if a.params else {}
    meta = {
        "asset_id": a.asset, "entity_id": a.asset.split(".")[1] if a.asset.count(".") >= 1 else None, "clip": a.clip,
        "name": a.name, "version": v, "date": today, "provider": a.provider, "tool": a.tool, "job_id": a.job_id,
        "character_id": a.character_id, "effect_id": a.effect_id, "seed": a.seed, "cost": a.cost, "prompt": a.prompt,
        "params": params, "source_anchor": a.source_anchor, "qa": None, "acceptance": "pending", "folder": rel(folder),
    }
    if a.dry_run:
        print("would create %s" % rel(folder))
        print(json.dumps(meta, ensure_ascii=False, indent=1))
        return 0
    for sub in ("raw", "clean", "preview"):
        (folder / sub).mkdir(parents=True, exist_ok=True)
    (folder / "metadata.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    (folder / "QA.md").write_text(QA_TEMPLATE.format(
        name=a.name, version=v, date=today, asset=a.asset, clip_line=(" · clip `%s`" % a.clip) if a.clip else "",
        why=a.why or "—", provider=a.provider, tool=a.tool, job_id=a.job_id or "—", character_id=a.character_id or "—",
        effect_id=a.effect_id or "—", seed=a.seed if a.seed is not None else "—", cost=a.cost or "—",
        params=json.dumps(params, ensure_ascii=False), prompt=a.prompt or "—", source_anchor=a.source_anchor or "—"), encoding="utf-8")
    print("created %s" % rel(folder))
    if not a.no_log and REGISTRY.is_file():
        cmd = PY + [str(REGISTRY), "log-event", a.asset, "candidate_created", "--candidate", rel(folder),
                    "--note", "%s v%d via %s%s" % (a.name, v, a.tool, (" job " + a.job_id) if a.job_id else "")]
        if a.clip:
            cmd += ["--clip", a.clip]
        if a.job_id:
            cmd += ["--job-id", a.job_id]
        r = subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True, encoding="utf-8")
        print(r.stdout.strip() or r.stderr.strip())
        if r.returncode:
            print("registry log-event failed (exit %d): the folder exists, add the event by hand" % r.returncode)
            return 1
    return 0


def _load(folder: Path):
    meta_p = folder / "metadata.json"
    if not meta_p.is_file():
        raise SystemExit("no metadata.json in %s" % folder)
    return meta_p, json.loads(meta_p.read_text(encoding="utf-8"))


def _replace_section(text: str, heading: str, body: str) -> str:
    pattern = re.compile(r"(## %s\n)(.*?)(?=\n## |\Z)" % re.escape(heading), re.S)
    if not pattern.search(text):
        return text.rstrip() + "\n\n## %s\n%s\n" % (heading, body)
    return pattern.sub(lambda m: m.group(1) + body + "\n", text, count=1)


def cmd_qa(a) -> int:
    folder = Path(a.folder) if Path(a.folder).is_absolute() else ROOT / a.folder
    meta_p, meta = _load(folder)
    meta["qa"] = {"verdict": a.verdict, "summary": a.summary, "report": a.report, "on": date.today().isoformat()}
    meta_p.write_text(json.dumps(meta, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    qa = folder / "QA.md"
    text = qa.read_text(encoding="utf-8") if qa.is_file() else "# QA\n"
    text = _replace_section(text, "Measured", a.summary + (("\n\nReport: `%s`" % a.report) if a.report else ""))
    text = _replace_section(text, "Verdict", "- Technical: **%s** (%s)\n- User: %s" % (a.verdict, date.today().isoformat(), meta.get("acceptance", "pending")))
    qa.write_text(text, encoding="utf-8")
    if meta.get("asset_id") and REGISTRY.is_file():
        cmd = PY + [str(REGISTRY), "log-event", meta["asset_id"], "qa_completed", "--candidate", meta.get("folder") or rel(folder),
                    "--note", "technical %s: %s" % (a.verdict, a.summary[:200])]
        if meta.get("clip"):
            cmd += ["--clip", meta["clip"]]
        r = subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True, encoding="utf-8")
        print(r.stdout.strip() or r.stderr.strip())
    print("qa recorded: %s" % a.verdict)
    return 0


def cmd_verdict(a) -> int:
    folder = Path(a.folder) if Path(a.folder).is_absolute() else ROOT / a.folder
    meta_p, meta = _load(folder)
    if a.acceptance in ("accepted", "rejected") and (a.by != "user" or not a.evidence):
        raise SystemExit("%s needs --by user and --evidence (the user's words)" % a.acceptance)
    meta["acceptance"] = a.acceptance
    meta["acceptance_evidence"] = a.evidence
    meta["acceptance_on"] = date.today().isoformat()
    meta_p.write_text(json.dumps(meta, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    qa = folder / "QA.md"
    text = qa.read_text(encoding="utf-8") if qa.is_file() else "# QA\n"
    tech = (meta.get("qa") or {}).get("verdict", "pending")
    text = _replace_section(text, "Verdict", "- Technical: %s\n- User: **%s** (%s) — %s" % (tech, a.acceptance, date.today().isoformat(), a.evidence or ""))
    qa.write_text(text, encoding="utf-8")
    if meta.get("asset_id") and REGISTRY.is_file() and a.acceptance != "pending":
        cmd = PY + [str(REGISTRY), "set-acceptance", meta["asset_id"], a.acceptance, "--by", a.by, "--evidence", a.evidence]
        if meta.get("clip"):
            cmd += ["--clip", meta["clip"]]
        r = subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True, encoding="utf-8")
        print(r.stdout.strip() or r.stderr.strip())
        if r.returncode:
            return 1
    print("verdict recorded: %s" % a.acceptance)
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    n = sub.add_parser("new")
    n.add_argument("--group", required=True)
    n.add_argument("--name", required=True)
    n.add_argument("--asset", required=True, help="registry id, e.g. unit.kiem_si or vfx.floor.big_burst")
    n.add_argument("--clip")
    n.add_argument("--tool", required=True)
    n.add_argument("--provider", default="pixellab", choices=["pixellab", "pixelfx", "fx-pipeline", "script", "hand"])
    n.add_argument("--job-id")
    n.add_argument("--character-id")
    n.add_argument("--effect-id")
    n.add_argument("--seed", type=int)
    n.add_argument("--cost")
    n.add_argument("--prompt")
    n.add_argument("--params", help="JSON object")
    n.add_argument("--source-anchor")
    n.add_argument("--why")
    n.add_argument("--no-log", action="store_true")
    n.add_argument("--dry-run", action="store_true", help="print the folder and metadata, write nothing")
    q = sub.add_parser("qa")
    q.add_argument("folder")
    q.add_argument("--verdict", required=True, choices=["PASS", "WARN", "FAIL", "NOT_ASSESSED"])
    q.add_argument("--summary", required=True)
    q.add_argument("--report")
    v = sub.add_parser("verdict")
    v.add_argument("folder")
    v.add_argument("--acceptance", required=True, choices=["accepted", "rejected", "pending"])
    v.add_argument("--by")
    v.add_argument("--evidence")
    args = ap.parse_args(argv)
    return {"new": cmd_new, "qa": cmd_qa, "verdict": cmd_verdict}[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
