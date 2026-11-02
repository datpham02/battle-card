"""Colours, the master palette and the material ramps.

A ramp is dark -> bright, as in PixelFX (fit, at), but every step must be a colour of
art_src/palette/tessera_master.gpl, and no ramp may come near the telegraph red #E5293B (art bible P3).
Ramp roles by index: 0 ink (outline), 1 dark, 2 body, 3 highlight, 4 core (the 1-2 frame "hero frame").
"""
from __future__ import annotations

import json
from pathlib import Path

TELEGRAPH_RED = 0xFFE5293B
# RGB distance a VFX colour must keep from the telegraph red. 60 lets the art bible's own Burn orange
# #FF7A1F (distance 86) through and still stops a reddish orange like #F0503A (distance 40).
RED_MIN_DISTANCE = 60


def hexc(s: str) -> int:
    s = s.lstrip("#")
    if len(s) == 3:
        s = "".join(ch * 2 for ch in s)
    return 0xFF000000 | int(s[:6], 16)


def tohex(c: int) -> str:
    return f"#{c & 0xFFFFFF:06X}"


def rgb(c: int) -> tuple[int, int, int]:
    return (c >> 16) & 255, (c >> 8) & 255, c & 255


def dist(a: int, b: int) -> float:
    ra, ga, ba = rgb(a)
    rb, gb, bb = rgb(b)
    return ((ra - rb) ** 2 + (ga - gb) ** 2 + (ba - bb) ** 2) ** 0.5


def mix(a: int, b: int, t: float) -> int:
    """Linear mix, for PREVIEWS only (the charge fill, the hit flash); never used inside an asset."""
    t = max(0.0, min(1.0, t))
    ra, ga, ba = rgb(a)
    rb, gb, bb = rgb(b)
    return 0xFF000000 | (round(ra + (rb - ra) * t) << 16) | (round(ga + (gb - ga) * t) << 8) | round(ba + (bb - ba) * t)


def read_gpl(path: Path) -> dict[int, str]:
    """GIMP .gpl -> {colour int: name}."""
    out: dict[int, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        parts = s.split(None, 3)
        if len(parts) < 3 or not all(p.isdigit() for p in parts[:3]):
            continue
        r, g, b = (int(p) for p in parts[:3])
        out[0xFF000000 | (r << 16) | (g << 8) | b] = parts[3] if len(parts) > 3 else ""
    return out


def fit(ramp: list[int], n: int) -> list[int]:
    """Resample a ramp to n steps keeping both ends (PixelFX color.js fit)."""
    if len(ramp) == n:
        return list(ramp)
    return [ramp[round(i * (len(ramp) - 1) / max(1, n - 1))] for i in range(n)]


def at(ramp: list[int], t: float) -> int:
    """The step for t in 0..1, never a blend (PixelFX color.js at)."""
    return ramp[max(0, min(len(ramp) - 1, int(t * len(ramp))))]


class Palettes:
    """The master palette plus the named ramps of tools/fx-pipeline/palettes.json, validated on load."""

    def __init__(self, gpl: Path, ramps_json: Path):
        self.gpl = gpl
        self.master = read_gpl(gpl)
        raw = json.loads(ramps_json.read_text(encoding="utf-8"))
        self.ramps: dict[str, list[int]] = {}
        problems = []
        for name, steps in raw["ramps"].items():
            if name.startswith("_"):
                continue
            ramp = [hexc(s) for s in steps]
            for s, c in zip(steps, ramp):
                if c not in self.master:
                    problems.append(f"ramp '{name}': {s} is not in {gpl.name}")
                if dist(c, TELEGRAPH_RED) < RED_MIN_DISTANCE:
                    problems.append(f"ramp '{name}': {s} is too close to the telegraph red #E5293B")
            self.ramps[name] = ramp
        if problems:
            raise ValueError("; ".join(problems))

    def ramp(self, name: str) -> list[int]:
        if name not in self.ramps:
            raise KeyError(f"no ramp '{name}' in palettes.json (have {sorted(self.ramps)})")
        return self.ramps[name]
