"""Roots: the Forest Witch's root crawl (floor) and root spikes (thorns impact).

Roots are the "old world" (art bible §3: organic shapes are allowed for roots, they are not power), so they are not
forced into squares; they keep the pixel rules: whole pixels, banded colour, no anti-aliasing, no glow. Wood is lit on
the top/left edge and dark on the bottom/right (Thorns #B89A6A, leather #9A7D5E / #66523F); ivory only at the moment
of arrival. Runs step across the slab in stair jogs.

Learned from PixelFX: nature/thorns (a seam races along the floor ahead; hooked thorns punch up one after another with
overshoot and a white frame, hold, sink; the thorn is a tapering horn lit down one edge with a hooked point),
nature/root-snare (roots grow, hold, crumble), nature/earth-spike (outBack rise, dirt thrown, settle).
build-11 notes: a stack of separate squares read as a bamboo pole and evenly bevelled squares as a ribbed stick;
both are now drawn as one continuous shape with a lit edge and a dark edge.
"""
from __future__ import annotations

from fxkit.component import Component
from fxkit.easing import out_back, out_cubic, seg
from fxkit.motion import shard
from fxkit.rng import rng

from .squares import _even, unit

# entry edge -> how (s along the run, q across it) maps to (x, y) in a cell of half size (hw, hh)
DIRS = {
    "e": lambda s, q, hw, hh: (hw - s, q),
    "w": lambda s, q, hw, hh: (-hw + s, q),
    "n": lambda s, q, hw, hh: (q, -hh + s),
    "s": lambda s, q, hw, hh: (q, hh - s),
}


class RootCrawl(Component):
    """Floor: a root runs into the cell from one edge across the slab, tapering, with two branches and rootlets;
    holds; withers from where it came in.

    Variants by `from` (e / w / n / s): the edge the root enters by (the side of the cell it came from), so a chain
    of cells reads as one root crawling cell by cell. Anchor = center. Floor layer, under the units. A 1 px ink seam
    runs ahead of the tip while it crawls (PixelFX thorns).
    """

    name = "root_crawl"
    desc = "A tapering root crawls across the cell from one edge, branches, holds, withers."
    loop = False
    anchor = "center"
    defaults = {"from": "e", "cell": [64, 46], "crawl": 0.14, "hold": 0.30, "wither": 0.18}

    def duration(self, o):
        return o["crawl"] + o["hold"] + o["wither"]

    def box(self, o):
        cw, ch = o["cell"]
        return _even(cw), _even(ch), _even(cw) // 2, _even(ch) // 2

    @staticmethod
    def _path(seed, L, span, jog, start_q=0.0, step=1):
        """Points (s, q) every px along s, q stepping by `jog` now and then (a stair run, not a straight rod)."""
        r = rng(seed, 7)
        pts, q, s, nxt = [], start_q, 0, r.range(1.5, 3.0) * jog * 2
        while s <= L:
            if s >= nxt:
                q = max(-span, min(span, q + r.pick([-1, 1]) * jog))
                nxt = s + r.range(2.0, 4.0) * jog * 2
            pts.append((s, q))
            s += step
        return pts

    def _band(self, p, pts, f, hw, hh, horizontal, size_at, R3, R2, R1):
        """A continuous root: body squares, then a 1 px dark edge below/right and a 1 px lit edge above/left."""
        for s, q, sz in ((s, q, size_at(s)) for s, q in pts):
            x, y = f(s, q, hw, hh)
            p.square(x, y, sz, R2)
        for s, q, sz in ((s, q, size_at(s)) for s, q in pts):
            x, y = f(s, q, hw, hh)
            x0, y0 = int(x) - sz // 2, int(y) - sz // 2
            if horizontal:
                p.rect(x0, y0 + sz - 1, 1, 1, R1)
                if sz >= 3:
                    p.rect(x0, y0, 1, 1, R3)
            else:
                p.rect(x0 + sz - 1, y0, 1, 1, R1)
                if sz >= 3:
                    p.rect(x0, y0, 1, 1, R3)

    def draw(self, P, t, o):
        R, p, u = o["ramp"], P["behind"], unit(o)
        cw, ch = o["cell"]
        dur = self.duration(o)
        if t >= dur:
            return
        hw, hh = cw / 2 - u / 2 - 2, ch / 2 - u / 2 - 2   # every square stays inside the cell
        f = DIRS[o["from"]]
        horizontal = o["from"] in ("e", "w")
        L = 2 * (hw if horizontal else hh)
        perp = hh if horizontal else hw
        grow = out_cubic(seg(t, 0.0, o["crawl"]))
        wither = seg(t, o["crawl"] + o["hold"], dur)
        head, tail = grow * L, wither * L
        fresh = wither < 0.4
        R3, R2, R1 = (R[3], R[2], R[1]) if fresh else (R[2], R[1], R[1])
        main = [(s, q) for s, q in self._path(o["seed"], L, perp * 0.35, max(1, u // 2)) if tail <= s <= head]
        size_main = lambda s: max(2, round(u + 1 - (u - 1) * s / max(1, L)))
        self._band(p, main, f, hw, hh, horizontal, size_main, R3, R2, R1)
        # two branches growing forward at 45 degrees, one to each side, tapering; plus short rootlets
        for b, (at, side, length) in enumerate(((0.28, 1, 0.75), (0.56, -1, 0.65))):
            s0 = at * L
            if head < s0 or tail > s0:
                continue
            q0 = next((qq for ss, qq in self._path(o["seed"], L, perp * 0.35, max(1, u // 2)) if ss >= s0), 0)
            blen = perp * length * out_cubic(seg(head, s0, s0 + L * 0.35))
            pts = [(s0 + d, q0 + side * d) for d in range(0, int(blen) + 1)]
            pts = [(s, max(-perp, min(perp, q))) for s, q in pts]
            size_b = lambda s, s0=s0: max(2, round(u - 1 - (u - 3) * (s - s0) / max(1, perp * length)))
            self._band(p, pts, f, hw, hh, horizontal, size_b, R3, R2, R1)
        # (1 px rootlets were tried in build-11: they read as hatching noise at 1x and were dropped)
        # the seam ahead of the tip, and the hot tip, only while it moves
        if grow < 1:
            path = self._path(o["seed"], L, perp * 0.35, max(1, u // 2))
            for s, q in path:
                if head < s <= head + 2 * u:
                    x, y = f(s, q, hw, hh)
                    p.px(x, y, R[0])
            if main:
                s, q = main[-1]
                x, y = f(s, q, hw, hh)
                p.square(x, y, size_main(s), R[4])


class RootSpike(Component):
    """Overlay: hooked root thorns punch up out of the cell one after another with overshoot, hold, sink (<= 0.35 s).

    Each thorn is a tapering horn drawn row by row (PixelFX thorns): lit left edge, wood body, dark right edge, its
    point hooked; the point is ivory for the first two beats. Dirt squares are thrown as they break the slab.
    Anchor = ground_center.
    """

    name = "root_spike"
    desc = "Three hooked root thorns punch up through the cell one after another, hold, and sink."
    loop = False
    anchor = "ground_center"
    defaults = {"cell": [64, 46], "dur": 0.35}
    # x (of cell w), depth (of cell h), height (of 0.95 cell h), base width (in u), hook (of height), delay (s)
    SPIKES = ((-0.24, 0.10, 0.62, 2.0, 0.22, 0.00), (0.0, 0.0, 1.00, 2.6, -0.18, 0.04), (0.25, -0.08, 0.72, 2.2, 0.20, 0.07))

    def duration(self, o):
        return o["dur"]

    def box(self, o):
        cw, ch = o["cell"]
        top = round(0.95 * ch * 1.12) + 8
        w = _even(cw * 1.3)
        return w, _even(top + ch / 2 + 4), w // 2, _even(top)

    def draw(self, P, t, o):
        R, p, u = o["ramp"], P["front"], unit(o)
        cw, ch = o["cell"]
        dur = o["dur"]
        if t >= dur:
            return
        for fx, fd, fh, fw, hook, delay in self.SPIKES:
            tt = t - delay
            if tt < 0:
                continue
            H = max(6, round(0.95 * ch * fh))
            rise = out_back(seg(tt, 0.0, 0.08), 2.2)
            sink = seg(t, dur - 0.10, dur - 0.01)
            shown = H * min(1.12, rise) * (1 - sink)        # how much of the thorn is above the floor
            x0, base = fx * cw, round(fd * ch)
            hot = tt < 0.10
            bw = fw * u
            for i in range(int(shown)):
                yrow = base - i                              # screen row, counting up from the floor
                v = (H - shown + i) / H                      # which part of the thorn this row is (0 base, 1 tip)
                if v < 0 or v > 1:
                    continue
                half = (bw / 2) * (1 - v) ** 0.85 + 0.35
                cx = x0 + hook * H * v ** 2.4
                xa, xb = int(cx - half + 0.5), int(cx + half + 0.5)
                for x in range(xa, max(xa, xb) + 1):
                    if v > 0.86:
                        c = R[4] if hot else R[3]
                    elif x == xa:
                        c = R[3]
                    elif x >= xb - (1 if xb - xa >= 4 else 0):
                        c = R[1]
                    else:
                        c = R[2]
                    p.px(x, yrow, c)
            if tt < 0.16:                                    # broken soil at its foot
                for sx in (-1, 1):
                    p.square(x0 + sx * (bw / 2 + 2), base - 1, max(2, u - 2), R[1])
        for i in range(7):
            r = rng(o["seed"], 30 + i)
            born = 0.01 + r.range(0.0, 0.05)
            life = min(dur - 0.01 - born, r.range(0.18, 0.26))
            age = t - born
            if age < 0 or age >= life:
                continue
            x, y, _ = shard(r.range(-0.2, 0.2) * cw, 0.0, r.sign() * cw * r.range(0.6, 1.4), -r.range(80, 160),
                            age, 1500.0, ch * r.range(-0.25, 0.3))
            v = age / life
            p.square(x, y, max(2, u - 2), R[1] if v < 0.6 else R[0])
