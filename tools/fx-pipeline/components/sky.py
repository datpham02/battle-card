"""Sky components: what a SKY_TO_TARGET skill looks like on its way DOWN.

Why this exists (user, 2026-11-17): a boss raised its club, smashed the air, and an effect appeared on a cell
several steps away. Nothing connected the two. Four of the six boss signatures are SKY_TO_TARGET, where the
story — it falls from above — is sound, but the only thing drawn on the way was the shared code-drawn travel
(`travel_style.falling_squares`: four squares of 6 px). At a 64x46 cell that is a tenth of the cell and reads
as nothing, so the attack still *appeared* rather than *arrived*.

Shape grammar is the same as squares.py (art bible §1 P1, §3): squares and 45-degree steps, no circles, no
glow, no translucency. Ramp roles: R[0] ink, R[1] dark, R[2] body, R[3] highlight, R[4] core.

Scale follows the same rule the burst learned the hard way (user 2026-11-02, "hiệu ứng còn quá nhỏ nhìn từ xa
gần như ko thấy gì"): the block is sized FROM THE CELL, not from a fixed pixel count — a falling block is about
a third of the cell wide, so it is the size of a thing that could hurt you.
"""
from __future__ import annotations

import math

from fxkit.component import Component
from fxkit.easing import out_cubic
from fxkit.rng import rng


def _even(v: float) -> int:
    v = int(math.ceil(v))
    return v + (v % 2)


class SkyFall(Component):
    """Travel: heavy blocks dropping onto the cell from off the top of the screen.

    Overlay pack (drawn over the units), so it stays within the art bible's 0.35 s for an overlay one-shot.
    Anchor = ground_center: the blocks converge on the cell's floor centre, which is where the impact pack
    will then play. The two packs therefore agree about where the attack lands.

    It ENDS EMPTY on purpose. The last block is gone before the final frame, because the impact pack takes
    over at exactly that moment; a travel that lingers would read as a second, weaker impact.
    """

    name = "sky_fall"
    desc = "Travel: blocks falling onto the cell, each landing with a flat step, ending empty for the impact."
    loop = False
    anchor = "ground_center"
    defaults = {"count": 4, "cell": [64, 46], "dur": 0.30}

    def _blocks(self, o):
        """(size, start x, launch delay, land time) per block - pure, from the seed."""
        cw, ch = o["cell"]
        n = int(o["count"])
        dur = float(o["dur"])
        out = []
        for i in range(n):
            r = rng(o["seed"], i)
            # about a third of the cell wide, the smallest still a quarter: a block, not a speck
            s = max(4, round(cw * r.range(0.24, 0.34)))
            s += s % 2
            # EVENLY SPACED SLOTS, not random x. Measured on the first build: four random draws landed at
            # x = 1.2, -3.9, -0.5, -4.8 on a 64 px cell - a vertical column, not a spread, and it read as one
            # falling stream. Random placement can cluster; slots cannot, and the jitter keeps it from looking
            # mechanical.
            half = max(2, (cw - s) // 2)
            slot = (i + 0.5) / n * 2.0 - 1.0          # -1 .. 1 across the cell
            x = slot * half + r.range(-half * 0.18, half * 0.18)
            land = dur * (0.45 + 0.42 * (i / max(1, n - 1))) if n > 1 else dur * 0.6
            out.append((s, x, land - 0.22, land))
        return out

    def duration(self, o):
        return float(o["dur"])

    def box(self, o):
        cw, ch = o["cell"]
        # tall enough that a block starts fully above the cell and nothing is ever clipped
        top = _even(ch * 1.9 + 10)
        w = _even(cw + 2 * max(4, round(cw * 0.34)) + 4)
        return w, _even(top + ch / 2 + 6), w // 2, top

    def draw(self, P, t, o):
        R = o["ramp"]
        cw, ch = o["cell"]
        front = P["front"]
        top = -(ch * 1.75 + 6)
        for i, (s, x, born, land) in enumerate(self._blocks(o)):
            if t < born:
                continue
            fall = max(0.001, land - born)
            if t <= land:
                # the drop: fast at the end, so the eye reads weight rather than a float
                v = (t - born) / fall
                y = top + (0.0 - top) * (v * v)
                front.bevel(x, y, s, R[2], R[3], R[1])
                # a flat shadow square on the floor, growing as the block nears it: where it WILL land
                sh = max(2, round(s * (0.35 + 0.45 * v)))
                front.square(x, 0, sh, R[1])
                continue
            age = t - land
            if age >= 0.12:
                continue
            # the landing: one flat beat of the core, then a low step that fades before the impact plays
            if age < 0.05:
                front.square(x, -s // 4, s, R[4], R[3])
            else:
                w = max(2, round(s * out_cubic(min(1.0, (age - 0.05) / 0.07))))
                front.rect(x - s / 2, -2, s, max(2, w // 3), R[3])
