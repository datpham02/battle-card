"""Paths and data references.

A recipe never types a game timing by hand (plan N8): a string "@<source>:<dotted.path>" is read from the game's
own data when the recipe is loaded, so a beat changed in assets/data re-renders at the new beat.
"""
from __future__ import annotations

import json
from pathlib import Path

PIPE = Path(__file__).resolve().parent.parent           # tools/fx-pipeline
ROOT = PIPE.parent.parent                               # the repository
GPL = ROOT / "art_src" / "palette" / "tessera_master.gpl"
RAMPS = PIPE / "palettes.json"
CANDIDATES = ROOT / "design" / "assets" / "candidates" / "fx-pipeline"
EVIDENCE = ROOT / "production" / "qa" / "evidence" / "fx-pipeline"
SOURCES = {
    "combat": ROOT / "assets" / "data" / "combat.json",
    "cuts": ROOT / "assets" / "data" / "cuts.json",
    "cards": ROOT / "assets" / "data" / "cards.json",
    "enemy_skills": ROOT / "assets" / "data" / "enemy_skills.json",
    "cast": ROOT / "assets" / "art" / "vfx" / "cast" / "index.json",
    "floor": ROOT / "assets" / "art" / "vfx" / "floor" / "index.json",
}
_cache: dict[str, object] = {}


class RefError(Exception):
    pass


def source(name: str):
    if name not in _cache:
        if name not in SOURCES:
            raise RefError(f"unknown data source '{name}' (have {sorted(SOURCES)})")
        _cache[name] = json.loads(SOURCES[name].read_text(encoding="utf-8"))
    return _cache[name]


def ref(s: str):
    """'@combat:timing.delivery.CASTER_TO_TARGET.first_hold_sec' -> 0.13"""
    src, _, path = s[1:].partition(":")
    node = source(src)
    for key in path.split(".") if path else []:
        if isinstance(node, dict) and key in node:
            node = node[key]
        elif isinstance(node, list) and key.isdigit() and int(key) < len(node):
            node = node[int(key)]
        else:
            raise RefError(f"{s}: '{key}' not found")
    return node


def resolve(obj):
    """Replace every '@source:path' string inside obj by the value it names."""
    if isinstance(obj, str) and obj.startswith("@"):
        return ref(obj)
    if isinstance(obj, dict):
        return {k: resolve(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [resolve(v) for v in obj]
    return obj


def load_recipe(path: Path) -> tuple[dict, dict]:
    """(raw recipe, recipe with every reference resolved)."""
    raw = json.loads(path.read_text(encoding="utf-8"))
    return raw, resolve(raw)
