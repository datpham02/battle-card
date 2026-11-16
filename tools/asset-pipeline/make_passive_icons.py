#!/usr/bin/env python3
"""Draw the five passive icons for F3 (character-system redesign).

Free production, per OD-6 (approved 2026-11-13): icons are scripted, only the five portraits may use
paid generation. No Pillow — the repo's own pure-Python writer, tools/fx-pipeline/fxkit/pngio.py.

Design rules these obey, from the project's standing art rules:
  * ANGULAR shapes only, no circles. Every glyph here is straight segments and right angles.
  * No box, no frame, no outline chrome. The glyph is the icon.
  * Tinted with the OWNING CHARACTER's accent from assets/data/characters.json `identity.accent_color`,
    read from the data rather than hardcoded, so retinting a character retints its icon.
  * One glyph per MECHANISM, not per character: a player who sees the icon on the select screen should
    recognise the cue it stands for in combat.
  * Legible at 24 px (the HUD chip). Drawn at 32 px so the select card has headroom; strokes are >= 3 px
    so nothing vanishes when it is scaled down.

Usage:  python tools/asset-pipeline/make_passive_icons.py [--out assets/art/icons]
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "fx-pipeline"))
from fxkit.pngio import write_png  # noqa: E402

SIZE = 32
STROKE = 3
TRANSPARENT = 0x00000000


def _argb(hex_rgb: str, alpha: int = 255) -> int:
    s = hex_rgb.lstrip("#")
    r, g, b = int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16)
    return (alpha << 24) | (r << 16) | (g << 8) | b


class Canvas:
    """A tiny ARGB canvas. Only straight fills: every glyph is rectangles, so no curve can sneak in."""

    def __init__(self, w: int, h: int) -> None:
        self.w, self.h = w, h
        self.px = [TRANSPARENT] * (w * h)

    def rect(self, x: int, y: int, w: int, h: int, colour: int) -> None:
        for yy in range(max(y, 0), min(y + h, self.h)):
            row = yy * self.w
            for xx in range(max(x, 0), min(x + w, self.w)):
                self.px[row + xx] = colour

    def diag(self, x0: int, y0: int, length: int, dx: int, dy: int, thick: int, colour: int) -> None:
        """A staircase diagonal — pixel steps, not an anti-aliased line (pixel art, art bible)."""
        for i in range(length):
            self.rect(x0 + dx * i, y0 + dy * i, thick, thick, colour)


def glyph_second_wind(c: Canvas, k: int) -> None:
    """Rising step: three stairs climbing right. 'You get it back after each win.'"""
    for i, (x, y, h) in enumerate(((4, 22, 6), (13, 16, 12), (22, 10, 18))):
        c.rect(x, y, 6, h, k)


def glyph_wide_caster(c: Canvas, k: int) -> None:
    """Wide against narrow: one broad bar over one short bar. The passive's whole meaning is BREADTH.

    First attempt was a chevron pair; at 1x it read as mountains, not as a wide cast. A width
    comparison needs two things of different widths in the same picture — one shape alone has nothing
    to be wider *than*.
    """
    c.rect(3, 9, 26, 5, k)    # the broad cast
    c.rect(3, 14, 4, 3, k)    # end caps, so it reads as a measured span rather than a stripe
    c.rect(25, 14, 4, 3, k)
    c.rect(12, 22, 8, 5, k)   # the narrow one, for contrast


def glyph_quick_blade(c: Canvas, k: int) -> None:
    """A short, steep stroke — small and sharp, the hits this passive boosts."""
    c.diag(8, 24, 14, 1, -1, 4, k)
    c.rect(20, 6, 6, 4, k)   # the tip flare
    c.rect(22, 6, 4, 6, k)


def glyph_hunter_mark(c: Canvas, k: int) -> None:
    """Closing bracket: two jaws shutting inward. The same shape as the floor mark in combat."""
    c.rect(5, 7, STROKE, 18, k)
    c.rect(5, 7, 8, STROKE, k)
    c.rect(5, 22, 8, STROKE, k)
    c.rect(24, 7, STROKE, 18, k)
    c.rect(19, 7, 8, STROKE, k)
    c.rect(19, 22, 8, STROKE, k)


def glyph_prayer(c: Canvas, k: int) -> None:
    """A bold angular plus — the heal — with the two-segment link arriving at it from the left.

    First attempt drew a chime over a link and read as an anvil: it said nothing about healing. The
    cue this icon stands for literally puts a "+N" on screen, so the icon says "+" too. Angular by
    construction, and the elbow is the same two-segment shape the combat cue draws.
    """
    c.rect(17, 6, 6, 18, k)    # plus, vertical
    c.rect(11, 12, 18, 6, k)   # plus, horizontal
    c.rect(4, 24, 13, 4, k)    # the link: along, then up into the plus
    c.rect(4, 15, 4, 13, k)


GLYPHS = {
    "second_wind": glyph_second_wind,
    "wide_caster": glyph_wide_caster,
    "quick_blade": glyph_quick_blade,
    "hunter_mark": glyph_hunter_mark,
    "prayer": glyph_prayer,
}


def accents() -> dict[str, str]:
    """passive id -> the accent of the character that owns it, read from the data."""
    data = json.loads((ROOT / "assets" / "data" / "characters.json").read_text(encoding="utf-8"))
    out: dict[str, str] = {}
    for ch in data["characters"]:
        pid = str(ch.get("passive", {}).get("id", ""))
        accent = str(ch.get("identity", {}).get("accent_color", "#EFE6D2"))
        if pid:
            out[pid] = accent
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="assets/art/icons")
    args = ap.parse_args()
    out_dir = ROOT / args.out
    out_dir.mkdir(parents=True, exist_ok=True)

    tints = accents()
    missing = [p for p in GLYPHS if p not in tints]
    if missing:
        print("ABORT: no character owns these passives, so no accent to use: %s" % missing)
        return 1

    for pid, draw in GLYPHS.items():
        canvas = Canvas(SIZE, SIZE)
        draw(canvas, _argb(tints[pid]))
        path = out_dir / ("passive_%s.png" % pid)
        write_png(path, SIZE, SIZE, canvas.px)
        print("wrote %s  (%s, %d px)" % (path.relative_to(ROOT), tints[pid], SIZE))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
