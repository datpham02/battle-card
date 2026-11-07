"""Fire made of squares: the Mage's square flame burst.

Art bible §3/§4: fire in Tessera is a *stepped flame of squares with horizontal stripes* ("lửa bậc thang + sọc
ngang"; diagonal stripes are the enemy warning's). Colours Burn #FF7A1F / lava #FFB21F over the Mage's charcoal
#3A2A26, ivory only in the core. No red, no glow, no smoke puffs.

Learned from PixelFX: fire/_lib flameTongue + status/burning (a fire is several tongues of different heights that
lean and flicker, hottest low in the middle, cooling outward and upward; sparks stream off; a tick flares it),
explosions/small-explosion (flash -> column -> debris -> clear). Squared: a base of u-px squares, three tongues of
squares that narrow upward, one row of each tongue a ramp step darker (the horizontal stripe), the tops tearing off
as chunks that rise and cool.
build-11 note: one symmetric pyramid with an ivory band at its foot read as a traffic cone.
"""
from __future__ import annotations

from fxkit.component import Component
from fxkit.easing import out_cubic
from fxkit.motion import cycle, shard
from fxkit.rng import rng

from .squares import _even, unit

# per beat: (tongue x offset in squares, width in squares, height as a share of the flame, lean every 2 rows)
TONGUES = {
    1: ((0, 3, 1.00, 0), (-2, 2, 0.62, -1), (2, 2, 0.50, 1)),
    2: ((0, 3, 0.86, 1), (-2, 2, 0.70, -1), (2, 2, 0.40, 0)),
    3: ((0, 2, 0.40, 0), (-2, 1, 0.30, -1), (2, 1, 0.26, 1)),
}


class FlameBurst(Component):
    name = "flame_burst"
    desc = "Three tongues of squared flame erupt from a burning base, flicker, and tear off into rising chunks."
    loop = False
    anchor = "ground_center"
    defaults = {"size": "big", "cell": [64, 46]}
    SIZES = {"big": {"dur": 0.35, "w": 0.62, "h": 1.10, "chunks": 10, "sparks": 8},
             "small": {"dur": 0.30, "w": 0.46, "h": 0.80, "chunks": 6, "sparks": 5}}

    def duration(self, o):
        return self.SIZES[o["size"]]["dur"]

    def box(self, o):
        cw, ch = o["cell"]
        k, u = self.SIZES[o["size"]], unit(o)
        top = round(ch * (0.9 * k["h"] + 0.5)) + 2 * u + 8   # the highest chunk: 0.9 of the flame + half a cell
        w = _even(cw * 1.3 + 2 * u)
        return w, _even(top + ch * 0.35 + u + 6), w // 2, _even(top)  # sparks land up to 0.3 of a cell in front

    def _tongue(self, p, R, u, x_sq, width, rows, y0, lean, stripe_row, core_rows):
        for j in range(rows):
            n = max(1, round(width * (1 - j / max(1, rows)) + 0.49))
            xs = x_sq + (j // 2) * lean
            for q in range(n):
                x = (xs - (n - 1) / 2 + q) * u
                edge = n > 1 and (q == 0 or q == n - 1)
                if j < core_rows and not edge and n >= 3:
                    c = R[4]
                elif j == stripe_row:
                    c = R[2]
                else:
                    c = R[2] if edge else R[3]
                p.square(x, y0 - j * u, u, c)

    def draw(self, P, t, o):
        R, k, u = o["ramp"], self.SIZES[o["size"]], unit(o)
        cw, ch = o["cell"]
        p = P["front"]
        base_w = max(4, round(k["w"] * cw / u))
        tall = max(4, round(k["h"] * ch / u))
        beat = int(t / 0.05)
        y0 = -u // 2
        if beat <= 3:
            # the burning base: two rows of squares across the cell, burn at the ends, lava inside
            for j in range(2 if beat < 3 else 1):
                n = base_w - j * 2
                for q in range(n):
                    edge = q == 0 or q == n - 1
                    mid = abs(q - (n - 1) / 2) <= 0.5               # the hot core: the middle squares only
                    c = R[4] if (beat == 0 and j == 1 and mid) else (R[2] if edge else R[3])
                    p.square((q - (n - 1) / 2) * u, y0 - j * u, u, c)
        if beat == 0:  # the burst: short, hot
            self._tongue(p, R, u, 0, 3, 2, y0 - 2 * u, 0, -1, 1)
        elif beat in TONGUES:
            for dx, width, share, lean in TONGUES[beat]:
                rows = max(1, round(tall * share) - 2)
                self._tongue(p, R, u, dx, width, rows, y0 - 2 * u, lean, rows // 2, 1 if beat == 1 else 0)
        # chunks: torn off the tongues, they rise, drift and cool (closed form, seeded)
        for i in range(k["chunks"]):
            r = rng(o["seed"], i)
            born = 0.06 + r.range(0.0, 0.05)
            life = min(k["dur"] - 0.01 - born, r.range(0.18, 0.26))
            age = t - born
            if age < 0 or age >= life:
                continue
            v = age / life
            x = r.range(-0.3, 0.3) * cw + r.sign() * out_cubic(v) * r.range(0.1, 0.3) * cw
            y = -r.range(0.3, 0.9) * ch * k["h"] - out_cubic(v) * r.range(0.25, 0.5) * ch
            s = u if v < 0.4 else max(2, u - 1) if v < 0.75 else 2
            p.square(x, y, s, R[3] if v < 0.35 else R[2] if v < 0.7 else R[1])
        # sparks: small squares flung out low over the slab, landing and going dark
        for i in range(k["sparks"]):
            r = rng(o["seed"], 50 + i)
            born = 0.03
            life = min(k["dur"] - 0.01 - born, r.range(0.2, 0.28))
            age = t - born
            if age < 0 or age >= life:
                continue
            x, y, _ = shard(0.0, -u, r.sign() * cw * r.range(0.8, 1.8), -r.range(60, 140), age, 1500.0,
                            ch * r.range(-0.3, 0.3))
            v = age / life
            p.square(x, y, max(2, u - 2), R[3] if v < 0.5 else R[2])


class SquareFireball(Component):
    """Travel: the Mage's fireball of squares, facing right, looping while the game moves it.

    2026-11-07 (user: the Mage's cast should read as fire, not the shared square streak): a blocky head of u-px
    squares (no circle: a stepped lozenge three to five squares tall), ivory-hot at the leading column, lava inside,
    burn at the rim, one row a ramp step darker (the art bible's horizontal stripe); three flame tongues trail behind
    and flicker every beat; squares tear off the tail and cool. Anchor = the head's leading point.
    """

    name = "square_fireball"
    desc = "Fireball: a stepped head of hot squares, three flickering tongues behind, cooling squares shed; loops."
    loop = True
    anchor = "origin"
    defaults = {"u": 5, "shed": 7, "period": 0.2}
    # head columns from the front: half height in squares
    HEAD = (1, 2, 2, 2, 1)
    # tongue length (squares) per row offset and beat
    TAILS = {-1: (2, 3, 2, 1), 0: (4, 3, 5, 4), 1: (2, 1, 3, 2)}

    def duration(self, o):
        return o["period"]

    def box(self, o):
        u = unit(o)
        back = (len(self.HEAD) + 5 + 5) * u + 8
        half = 3 * u + 6
        return _even(back + u + 6), _even(2 * half), _even(back), _even(half)

    def draw(self, P, t, o):
        R, p, u = o["ramp"], P["front"], unit(o)
        beat = int((t / o["period"]) * 4) % 4
        n = len(self.HEAD)
        # tongues first so the head sits on top
        for row, lengths in self.TAILS.items():
            length = lengths[beat]
            for j in range(length):
                x = -(n + j) * u
                c = R[3] if j < length // 2 else R[2]
                if j == length - 1:
                    c = R[1] if length > 2 else R[2]
                p.square(x, row * u, max(2, u - (1 if j >= length - 1 else 0)), c)
        # the head: a stepped lozenge, hottest at the front, a darker stripe one row below the middle
        for col, half in enumerate(self.HEAD):
            for row in range(-half, half + 1):
                edge = abs(row) == half
                if col == 0:
                    c = R[4] if row == 0 else R[3]
                elif row == 1:
                    c = R[2]
                elif edge:
                    c = R[2]
                else:
                    c = R[3] if (col + beat) % 3 else R[4]
                p.square(-col * u, row * u, u, c)

        # squares torn off the tail drift back and down and cool (seamless: on a cycle of the period)
        def shed(age, life, r, i):
            v = age / life
            row = r.int(-1, 1)
            x = -(n + 4) * u - v * r.range(2.0, 4.0) * u
            y = row * u + round(v * r.range(0, u))
            p.square(x, y, max(2, u - 1 if v < 0.5 else u - 2), R[3] if v < 0.4 else R[2] if v < 0.75 else R[1])

        cycle(t, o["period"], o["shed"], o["seed"], lambda g: g.range(0.14, 0.2), shed)
