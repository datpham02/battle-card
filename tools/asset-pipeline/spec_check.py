#!/usr/bin/env python3
"""Check region and monster specs. Stdlib only. Exit 1 on a failure."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGIONS = ROOT / "design" / "assets" / "regions"
CHARACTERS = ROOT / "design" / "assets" / "characters"
HEX = re.compile(r"#[0-9A-Fa-f]{6}")
ALLOWED_HEX = {"#1B1722"}
ORDER = ["forest", "hellfire", "sands", "swamp", "dungeon", "ice_tower", "sky_isles", "lattice_heart"]
OUT = {"wolf", "goblin_chief", "goblin_warrior", "goblin_shaman", "goblin_brute"}


def fields(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith(" ") or line.startswith("-"):
            continue
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        out[key.strip()] = value.strip()
    return out


def monsters(path: Path) -> list[str]:
    ids: list[str] = []
    grab = False
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("monsters:"):
            grab = True
            continue
        if grab:
            if line.startswith("  - "):
                ids.append(line[4:].strip())
            elif line and not line.startswith(" "):
                break
    return ids


def main() -> int:
    fails = 0

    def bad(msg: str) -> None:
        nonlocal fails
        fails += 1
        print("FAIL", msg)

    files = sorted(REGIONS.glob("*.yaml"))
    got = [p.stem for p in files]
    if set(got) != set(ORDER):
        bad("region set %s" % got)
    floors = {"forest": "1", "hellfire": "2", "sands": "3", "swamp": "4", "dungeon": "5", "ice_tower": "6", "sky_isles": "7", "lattice_heart": "null"}
    for path in files:
        data = fields(path)
        if data.get("id") != path.stem:
            bad("%s id" % path.name)
        if data.get("floor") != floors[path.stem]:
            bad("%s floor %s" % (path.stem, data.get("floor")))
        if path.stem == "forest":
            if data.get("sprite_palette_status") != "partial_see_palette_doc":
                bad("forest palette status")
            if data.get("environment") != "present":
                bad("forest env")
        else:
            if data.get("sprite_palette_status") != "needs_art_director_review":
                bad("%s palette status" % path.stem)
            if data.get("environment") != "missing":
                bad("%s env" % path.stem)
        if data.get("sprite_colours") != "[]":
            bad("%s invented sprite colours" % path.stem)
        for entity_id in monsters(path):
            char = CHARACTERS / path.stem / f"{entity_id}.yaml"
            if not char.is_file():
                bad("missing character %s" % char)
            if entity_id in OUT:
                bad("out of pool was specced %s" % entity_id)
    for char in CHARACTERS.glob("*/*.yaml"):
        text = char.read_text(encoding="utf-8")
        data = fields(char)
        extra = set(HEX.findall(text)) - ALLOWED_HEX
        if extra:
            bad("%s hex %s" % (char.name, sorted(extra)))
        if data.get("colours") != "[]":
            bad("%s colours not empty" % char.name)
        if data.get("approval") != "unknown":
            bad("%s approval inferred" % char.name)
        region = char.parent.name
        if region != "forest" and data.get("palette_status") != "needs_art_director_review":
            bad("%s palette %s" % (char.name, data.get("palette_status")))
        if char.stem == "an_dai_keeper" and "160, 130" not in text:
            bad("keeper frame")
        if char.stem == "dire_wolf" and "68, 52" not in text:
            bad("dire wolf frame")
    print("-- %d FAIL" % fails)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
