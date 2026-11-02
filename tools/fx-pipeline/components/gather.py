"""Gather: squares drawn in to a point, looping (the "charge" beat).

One component, two jobs (plan: reuse before writing new code):
- on a target cell, floor layer: the Mage's cells gathering fire while the swing charges ("các ô mục tiêu tích lực");
- at an enemy's back hand, front layer: the art bible's wind-up mark, "3-5 ivory squares gather at the back hand"
  (art bible §3, "Tư thế niệm của địch").

Learned from PixelFX: magic-missile / spell-charge (motes spiral in to the hand before the release), sim.js STREAK
(gathering energy accelerates as it arrives). Squared: the bits are squares that ease in (accelerate), grow brighter
as they arrive, and a core square at the point pulses between two ramp steps.
"""
from __future__ import annotations

import math

from fxkit.component import Component
from fxkit.easing import in_quad
from fxkit.motion import cycle

from .squares import _even, unit


class SquareGather(Component):
    name = "square_gather"
    desc = "Squares ease in from around a point and brighten as they arrive; a core square pulses. Loops."
    loop = True
    anchor = "center"
    # layer: behind (on a cell) | front (at a hand). reach: how far out the squares start, as a fraction of the
    # cell (rx = reach * cell w / 2, ry = reach * cell h / 2) or, with reach_px, in art px.
    defaults = {"layer": "behind", "reach": 0.9, "reach_px": 0, "count": 8, "period": 0.4, "core": True}

    def duration(self, o):
        return o["period"]

    def _radii(self, o):
        if o["reach_px"]:
            return o["reach_px"], o["reach_px"]
        cw, ch = o.get("cell", [64, 46])
        return o["reach"] * cw / 2, o["reach"] * ch / 2

    def box(self, o):
        rx, ry = self._radii(o)
        u = unit(o)
        return _even(2 * rx + 2 * u + 4), _even(2 * ry + 2 * u + 4), _even(rx + u + 2), _even(ry + u + 2)

    def draw(self, P, t, o):
        R, p, u = o["ramp"], P[o["layer"]], unit(o)
        rx, ry = self._radii(o)

        def bit(age, life, r, i):
            v = in_quad(age / life)                       # accelerating inwards
            # start on the rectangle round the point (not a circle): a side, then a place along it
            side, s = i % 4, r.range(-1.0, 1.0)
            sx, sy = [(1, s), (-1, s), (s, 1), (s, -1)][side]
            x, y = sx * rx * (1 - v), sy * ry * (1 - v)
            size = u if v < 0.6 else max(2, u - 1)       # full-size squares: they must read from a distance
            col = R[2] if v < 0.35 else R[3] if v < 0.8 else R[4]
            p.square(x, y, size, col)

        cycle(t, o["period"], o["count"], o["seed"], lambda g: g.range(0.22, 0.32), bit)
        if o["core"]:
            beat = int(t / 0.05) % 2
            p.square(0, 0, u + 3, R[3] if beat == 0 else R[2])
            p.square(0, 0, max(1, u - 1), R[4] if beat == 0 else R[3])
