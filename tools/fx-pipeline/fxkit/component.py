"""The component contract: one reusable, code-drawn animation (PixelFX's "effect", pure form).

A component is a pure function of time: `draw(P, t, o)` paints the frame at t seconds into the painters
P["behind"] / P["front"], from t and the options alone. So any frame can be drawn alone, a loop has no seam,
and a sheet is just the component sampled at the pack's frame rate (PixelFX docs/AUTHORING.md "Pure").

Options `o` always carry:
  ramp  - the material ramp, dark -> bright (palette.py roles: 0 ink, 1 dark, 2 body, 3 highlight, 4 core)
  seed  - every random number comes from it (rng.py); never `random`, never the clock
  cell  - [w, h] of the board cell the pack is made for (art px)
plus the component's own knobs (`defaults`).
"""
from __future__ import annotations


class Component:
    name = "component"
    desc = ""
    loop = False
    anchor = "origin"  # how the game places the pack: origin | ground_center | center
    defaults: dict = {}

    def options(self, o: dict) -> dict:
        merged = dict(self.defaults)
        merged.update(o)
        return merged

    def duration(self, o: dict) -> float:
        raise NotImplementedError

    def box(self, o: dict) -> tuple[int, int, int, int]:
        """(w, h, ox, oy): the canvas and where the anchor sits in it. Even sizes, so centres land on pixels."""
        raise NotImplementedError

    def draw(self, P: dict, t: float, o: dict) -> None:
        raise NotImplementedError
