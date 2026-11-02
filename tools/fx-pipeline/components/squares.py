"""Square components for physical/steel skills: the sword-qi wave, the release slash, the burst, the floor mark.

Shape grammar (art bible §1 P1, §3): every piece is a square or a 45-degree step; the "hot" moment is 1-2 frames
of the ramp's core colour, then the pieces step down the ramp. No circles, no glow, no translucency.
Ramp roles: R[0] ink, R[1] dark, R[2] body, R[3] highlight, R[4] core.

Scale (user 2026-11-02: "hiệu ứng còn quá nhỏ nhìn từ xa gần như ko thấy gì"): sizes come from the cell, not
from fixed pixels. The square unit u is about a tenth of the cell height (5 px on a 64x46 cell, 3 px on 43x31);
a burst spans most of its cell; the wave is nearly a cell tall. Most of the area is the highlight and core
colours: the steel dark step is too close to the slab to read from a distance, so it is used only at the end.

Learned from PixelFX: sword-slash (a blade plus echoes a beat behind, fast head / slow tail, bits flung where it
stops), hit-spark (fixed beats at contact: full cross, thinning; a diamond core), small-explosion (flash ->
shock ring -> debris that lands -> clears by the end).
"""
from __future__ import annotations

import math

from fxkit.component import Component
from fxkit.easing import out_cubic, seg
from fxkit.motion import cycle, shard
from fxkit.rng import rng


def _even(v: float) -> int:
    v = int(math.ceil(v))
    return v + (v % 2)


def unit(o: dict) -> int:
    """The square unit: o["u"] if given, else about a tenth of the cell height (3..6 px)."""
    if o.get("u"):
        return int(o["u"])
    return max(3, min(6, round(o.get("cell", [64, 46])[1] * 0.11)))


class SquareWave(Component):
    """Travel: sword qi made of squares, facing right, looping while the game moves it.

    A sharp ">" blade of u-px squares nearly a cell tall (a vertical cut seen edge-on: the angular answer to the
    rejected crescent), a body-colour back edge for thickness, two shorter echoes, squares shed off the back.
    Anchor = the middle of the blade's point (the point the game flies from the hand to the first cell).
    """

    name = "square_wave"
    desc = "Sword qi: a sharp chevron of large squares, two echoes, shed squares; loops in flight."
    loop = True
    anchor = "origin"
    defaults = {"u": 5, "rows": 4, "shed": 6, "period": 0.2}

    def duration(self, o):
        return o["period"]

    def _geo(self, o):
        u = unit(o)
        return u, o["rows"], u, u // 2 + 1  # u, rows, step, lean

    def box(self, o):
        u, rows, step, lean = self._geo(o)
        half = rows * step + u + 2
        back = rows * lean + 9 * u + 6
        return _even(back + u + 4), _even(2 * half), _even(back), _even(half)

    def draw(self, P, t, o):
        R, p = o["ramp"], P["front"]
        u, rows, step, lean = self._geo(o)
        phase = int((t / o["period"]) * 4) % 4
        # echoes first (furthest back), so the blade sits on top
        for gap, size, span, col in ((4 * u, u - 2, rows - 2, R[2]), (2 * u, u - 1, rows - 1, R[3] if phase % 2 == 0 else R[2])):
            for k in range(-span, span + 1):
                p.square(-gap - abs(k) * lean, k * step, max(2, size), col)
        # the blade: a body-colour back edge, then the bright face, then a 1 px core line on the leading edge
        for k in range(-rows, rows + 1):
            a = abs(k)
            x, y = -a * lean, k * step
            p.square(x - u // 2 - 1, y, u, R[2])
        for k in range(-rows, rows + 1):
            a = abs(k)
            x, y = -a * lean, k * step
            p.square(x, y, u, R[4] if a == 0 else R[3])
            if a <= 2:
                p.rect(x + u // 2, y - u // 2, 1, u, R[4])

        # squares shed off the back of the blade fall behind (seamless: on a cycle of the period)
        def shed(age, life, r, i):
            v = age / life
            row = r.int(-rows + 1, rows - 1)
            x = -abs(row) * lean - 5 * u - v * r.range(2.0, 4.0) * u
            y = row * step + round(v * r.range(-u, u))
            p.square(x, y, max(2, u - 1 if v < 0.5 else u - 2), R[3] if v < 0.45 else R[2])

        cycle(t, o["period"], o["shed"], o["seed"], lambda g: g.range(0.14, 0.2), shed)


class SquareSlash(Component):
    """Release: the horizontal cut at the hand, a band of u-px squares, drawn in four beats (0.2 s).

    Anchor = the hand (the point the wave leaves from). Plays once at the release frame of the cast gesture.
    """

    name = "square_slash"
    desc = "A horizontal band of large squares cuts forward through the hand in four drawn beats."
    loop = False
    anchor = "origin"
    defaults = {"u": 5}

    BEATS = 4      # drawn like hand-made frames: cut appears, cut full, cut breaks, specks
    BEAT = 0.05

    def duration(self, o):
        return self.BEATS * self.BEAT

    def _geo(self, o):
        u = unit(o)
        return u, 5 * u, 8 * u  # u, back, reach

    def box(self, o):
        u, back, reach = self._geo(o)
        return _even(back + reach + 4 * u), _even(4 * u + 8), _even(back + u + 2), _even(2 * u + 4)

    @staticmethod
    def _y(x, back, u):
        return -((x + back) // (3 * u))  # the cut lifts 1 px every 3 squares: level, with a stepped rise

    def draw(self, P, t, o):
        R, p = o["ramp"], P["front"]
        u, back, reach = self._geo(o)
        beat = int(t / self.BEAT)
        if beat == 0:  # the cut appears behind the hand, its head already hot
            for x in range(-back, u, u):
                p.square(x, self._y(x, back, u), u, R[3] if x > -back + u else R[2])
            p.square(u, self._y(u, back, u), u + 1, R[4])
        elif beat == 1:  # full length, two squares thick in the middle, core-white head with a tip
            for x in range(-back + u, reach, u):
                y = self._y(x, back, u)
                v = (x + back) / (back + reach)
                p.square(x, y, u, R[3] if v > 0.2 else R[2])
                if 0.25 < v < 0.85:
                    p.square(x, y + u, u, R[3] if v > 0.5 else R[2])
            hy = self._y(reach, back, u)
            p.square(reach, hy, u + 1, R[4])
            p.rect(reach + u // 2 + 1, hy - 1, u, 2, R[4])
        elif beat == 2:  # the band breaks: every other square, stepping down
            for j, x in enumerate(range(0, reach + u, u)):
                if j % 2 == 0:
                    p.square(x, self._y(x, back, u), u - 1, R[3] if x > reach * 0.5 else R[2])
        elif beat == 3:  # a few squares drift on past the tip
            for j in range(3):
                x = reach - 2 * u + j * (u + 2)
                p.square(x, self._y(x, back, u) + (j % 2), max(2, u - 2), R[2])


class SquareBurst(Component):
    """Impact: a square burst on a cell, size "big" (the first cell) or "small" (each further cell).

    Beats (PixelFX hit-spark + small-explosion, squared): hero frame (a core diamond about a third of the cell
    tall and a cross of u-px squares reaching most of the cell), a thick diamond ring, the ring breaking into four,
    bevelled shards flung out that land on their own depth of the slab, bounce once and shrink away.
    Overlay pack (over units), so it lasts <= 0.35 s (art bible §1); the lasting part is SquareMark on the floor.
    Anchor = ground_center: the cell centre on the floor; the core sits above it.
    """

    name = "square_burst"
    desc = "Square impact: big core diamond and cross, thick breaking diamond ring, bevelled shards."
    loop = False
    anchor = "ground_center"
    defaults = {"size": "big", "cell": [64, 46]}

    # sizes as fractions of the cell height (ch) / width (cw)
    SIZES = {
        "big": {"dur": 0.35, "core": 0.30, "lift": 0.20, "ring": (0.45, 0.66), "arm_x": 0.62, "arm_up": 0.55,
                "arm_dn": 0.25, "shards": 16, "spread": (1.0, 2.0), "up": (80, 170)},
        "small": {"dur": 0.25, "core": 0.18, "lift": 0.14, "ring": (0.28, 0.40), "arm_x": 0.36, "arm_up": 0.30,
                  "arm_dn": 0.15, "shards": 7, "spread": (0.7, 1.4), "up": (60, 120)},
    }
    G = 1500.0  # shards drop back onto the slab inside the burst's 0.35 s

    def _k(self, o):
        return self.SIZES[o["size"]]

    def duration(self, o):
        return self._k(o)["dur"]

    def box(self, o):
        cw, ch = o["cell"]
        k, u = self._k(o), unit(o)
        lift, r1 = round(k["lift"] * ch), round(k["ring"][1] * ch)
        top = lift + max(r1, round(k["arm_up"] * ch) + u) + 16
        w = _even(cw * 1.5 + 2 * u)
        return w, _even(top + ch / 2 + u + 4), w // 2, _even(top)

    def draw(self, P, t, o):
        R, k, u = o["ramp"], self._k(o), unit(o)
        cw, ch = o["cell"]
        front = P["front"]
        small = o["size"] == "small"
        cy = -round(k["lift"] * ch)
        core = round(k["core"] * ch)
        r0, r1 = round(k["ring"][0] * ch), round(k["ring"][1] * ch)
        su = u - 1 if small else u
        beat = int(t / 0.05)
        if beat == 0:  # the hit: core-white diamond with a highlight rim, a cross of squares
            self._cross(front, cy, cw * k["arm_x"], ch * k["arm_up"], ch * k["arm_dn"], su, R[3], R[3], gap=False)
            front.diamond(0, cy, core, R[4], R[3])
        elif beat == 1:  # the diamond shrinks, a thick ring opens, the cross breaks
            self._cross(front, cy, cw * k["arm_x"] * 1.15, ch * k["arm_up"] * 1.1, ch * k["arm_dn"], su, R[3], R[2], gap=True)
            front.diamond(0, cy, max(2, core // 2), R[3], R[2])
            front.diamond_ring(0, cy, r0, max(2, su - 1), R[3])
        elif beat == 2:
            front.diamond_ring(0, cy, (r0 + r1) // 2, max(2, su - 2), R[3], gaps=4, phase=0.125)
        elif beat == 3:
            front.diamond_ring(0, cy, r1, 2, R[2], gaps=4, phase=0.125)
        # shards: flung out of the core, each landing on its own depth of the slab, bouncing once, shrinking away
        for i in range(k["shards"]):
            r = rng(o["seed"], i)
            born = 0.04 + r.range(0.0, 0.02)
            life = min(k["dur"] - 0.01 - born, r.range(0.22, 0.30))
            age = t - born
            if age < 0 or age >= life:
                continue
            side = -1 if i % 2 else 1
            vx = side * cw * r.range(*k["spread"]) * (0.45 if i % 5 == 4 else 1.0)  # a few drop near the core
            vy = -r.range(*k["up"])
            floor = ch * r.range(-0.32, 0.32)
            x, y, _ = shard(0.0, cy, vx, vy, age, self.G, floor)
            v = age / life
            big = r.int(max(2, su - 1), su)
            s = big if v < 0.5 else max(2, big - 1) if v < 0.8 else 2
            if s >= 3:
                front.bevel(x, y, s, R[3] if v < 0.5 else R[2], R[4] if v < 0.5 else R[3], R[2] if v < 0.5 else R[1])
            else:
                front.square(x, y, s, R[3] if v < 0.6 else R[2])

    def _cross(self, p, cy, ax, up, dn, s, near, far, gap):
        """Arms of s px squares along the four axes, touching (a solid stepped bar); `gap` breaks them."""
        for dx, dy, L in ((1, 0, ax), (-1, 0, ax), (0, -1, up), (0, 1, dn)):
            n = max(1, int(L // s))
            for j in range(1, n + 1):
                if gap and j % 2:
                    continue
                p.square(dx * j * s, cy + dy * j * s, s if j < n else max(2, s - 2), near if j <= n * 0.6 else far)




class SquareMark(Component):
    """Floor mark: large material squares knocked out over the struck slab, lying a beat, then shrinking away.

    Drawn under the units (FloorDynamicLayer), so it may outlast the 0.35 s overlay burst: it is what still shows
    from a distance. Scattered squares, not a frame: a frame read as a UI selection box and corner brackets as a
    camera reticle (build-06), and a lit tile would be the illuminated terrain pack 01 forbids.
    Eight directions (axes and diagonals) for the big mark, four diagonals for the small; each square jitters by
    seed so the pattern is not a perfect ring. Anchor = center, kept inside the cell.
    """

    name = "square_mark"
    desc = "Large material squares knocked out over the struck slab, lying a beat, then shrinking away."
    loop = False
    anchor = "center"
    defaults = {"size": "big", "cell": [64, 46]}
    DUR = {"big": 0.45, "small": 0.35}
    DIRS = {"big": ((1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)),
            "small": ((1, 1), (-1, 1), (-1, -1), (1, -1))}

    def duration(self, o):
        return self.DUR[o["size"]]

    def box(self, o):
        cw, ch = o["cell"]
        return _even(cw), _even(ch), _even(cw) // 2, _even(ch) // 2

    def draw(self, P, t, o):
        R, p, u = o["ramp"], P["behind"], unit(o)
        cw, ch = o["cell"]
        big = o["size"] == "big"
        dur = self.duration(o)
        if t < 0.05 or t >= dur:  # beat 0 belongs to the overlay burst's hero frame: piled at the centre the
            return               # squares merged into one round blob (build-08)
        e_out = out_cubic(seg(t, 0.0, 0.15))          # knocked out fast...
        e = seg(t, 0.15, dur)                          # ...then lies there and shrinks away
        for i, (dx, dy) in enumerate(self.DIRS[o["size"]]):
            r = rng(o["seed"], 100 + i)
            reach = r.range(0.30, 0.42) if big else r.range(0.22, 0.32)
            d0 = 0.10
            d = d0 + (reach - d0) * e_out
            # no 1/sqrt(2) on the diagonals: they go to the corners, so the eight squares lie on the cell's own
            # rectangle (an even radius made an ellipse of dots that read as a round ring, build-07)
            x = dx * cw * d + r.range(-1.5, 1.5)
            y = dy * ch * d + r.range(-1.5, 1.5)
            s0 = (u + 1) if big and i % 2 == 0 else u
            s = s0 if e < 0.35 else max(2, s0 - 1) if e < 0.7 else 2
            if t < 0.10:
                p.square(x, y, s, R[4])
            elif s >= 3:
                p.bevel(x, y, s, R[3] if e < 0.5 else R[2], R[4] if e < 0.5 else R[3], R[2] if e < 0.5 else R[1])
            else:
                p.square(x, y, s, R[2])
