"""The skill timeline: built packs played on a board with Tessera's real sprites, at the game's own timings.

PixelFX acts an effect out with a stand-in body (src/core/act.js); Tessera has its own bodies, so this composes the
cast the way the game sequences it and reads every pack back from disk through its manifest (so the preview also
proves the export). Two sequences:

- player_cast (cards): swing (charge on the target cells) -> [hand charge, release, travel] -> resolve -> impacts
  per cell at SkillDelivery arrival times (assets/art/vfx/cast/index.json, assets/data/cuts.json, combat.json).
- enemy_skill (enemy_skills.json): windup (the enemy holds still, ivory squares gather at its hand) -> warning
  (red cells darkening, the timer) -> resolve -> travel/impacts per cell -> followup warning -> followup resolve.

It writes timeline.gif (2x = 720p size), timeline-keys.png (1x, the far view) and skill_timing.json (PixelFX
actTiming, flattened). Flat board (no perspective warp). Preview-only drawing: the code charge fill, the red
telegraph, the hit flash and the stand-in bodies for units without sprites - none of it goes into a pack.
"""
from __future__ import annotations

import json
from pathlib import Path

from .data import ROOT
from .gif import write_gif
from .palette import hexc, mix
from .pngio import load_image, write_png
from .preview import GROUND, INK, blit, slab, upscale

FEET_DEPTH_RATIO = 0.72  # src/battle/unit_layer.gd: feet at top + 0.72 x cell height (>= 3 px above the bottom)
NEIGHBOURS = ((1, 0), (0, 1), (0, -1), (-1, 0))
WHITE, RED, MIST = hexc("#FFFFFF"), hexc("#E5293B"), hexc("#7D8896")


# ---------------------------------------------------------------- timing (mirrors SkillDelivery.arrival_times)
def manhattan(a, b) -> int:
    return abs(a[0] - b[0]) + abs(a[1] - b[1])


def nearest_cell(cells, frm):
    best = cells[0]
    for c in cells:
        dc, db = (abs(c[0] - frm[0]), abs(c[1] - frm[1])), (abs(best[0] - frm[0]), abs(best[1] - frm[1]))
        if dc[0] < db[0] or (dc[0] == db[0] and dc[1] < db[1]):
            best = c
    return best


def spread(cells, first, step, hold) -> dict:
    arrive = {first: 0.0}
    area = set(cells)
    queue = [first]
    while True:
        while queue:
            cur = queue.pop(0)
            for dx, dy in NEIGHBOURS:
                n = (cur[0] + dx, cur[1] + dy)
                if n in area and n not in arrive:
                    arrive[n] = arrive[cur] + step + (hold if cur == first else 0.0)
                    queue.append(n)
        rest = [c for c in cells if c not in arrive]
        if not rest:
            return arrive
        d, frm, to = min((manhattan(c, r), r, c) for c in rest for r in arrive)
        arrive[to] = arrive[frm] + step * d + (hold if frm == first else 0.0)
        queue.append(to)


def origin_cell(delivery: dict, cells, caster):
    if delivery.get("origin") in ("caster", "origin_cell"):
        return caster
    return nearest_cell(cells, caster)


def arrival_times(dtype: str, cells, caster, timing: dict, delivery: dict | None = None) -> dict:
    delivery = delivery or {"type": dtype}
    t = timing.get(dtype, {})
    if dtype == "CASTER_TO_TARGET":
        return spread(cells, nearest_cell(cells, caster), t["spread_step_sec"], t["first_hold_sec"])
    if dtype == "SKY_TO_TARGET":
        rows = sorted(cells, key=lambda c: (c[1], c[0]))
        return {c: t["fall_sec"] + i * t["stagger_sec"] for i, c in enumerate(rows)}
    if dtype == "GROUND_PROPAGATION":
        o = origin_cell(delivery, cells, caster)
        return {c: manhattan(c, o) * t["step_sec"] for c in cells}
    if dtype == "SEQUENTIAL_CHAIN":
        return {c: i * t["step_sec"] for i, c in enumerate(cells)}
    return {c: t.get("appear_sec", 0.0) for c in cells}


# ---------------------------------------------------------------- sprites and packs read back from disk
class Clips:
    """A unit's clips from art_src/units/<id>/clips.json, or a flat grey stand-in (body + pointed hat)."""

    def __init__(self, unit: str | None, stand_in=(64, 52)):
        self.frames: dict[str, list[tuple[list[int], int]]] = {}
        base = ROOT / "art_src" / "units" / (unit or "_none_")
        if unit and (base / "clips.json").is_file():
            spec = json.loads((base / "clips.json").read_text(encoding="utf-8"))
            self.w, self.h = spec["frame"]["w"], spec["frame"]["h"]
            self.real = True
            for clip in spec["clips"]:
                self.frames[clip["name"]] = [(load_image(base / f)[2], ms) for f, ms in zip(clip["frames"], clip["ms"])]
        else:
            self.real = False
            self.w, self.h = stand_in
            px = [0] * (self.w * self.h)
            bw, bh = max(8, self.w // 3), int(self.h * 0.62)
            x0, y0 = (self.w - bw) // 2, self.h - bh
            for y in range(y0, self.h):
                for x in range(x0 - 2, x0 + bw + 2):
                    if 0 < x < self.w - 1:
                        px[y * self.w + x] = INK if x in (x0 - 2, x0 + bw + 1) or y == y0 else MIST
            for k in range(bw // 2 + 4):  # a stepped pointed hat, so the stand-in reads as a caster
                for x in range(x0 - 2 + k, x0 + bw + 2 - k):
                    y = y0 - 1 - k
                    if 0 < y < self.h and 0 < x < self.w - 1:
                        px[y * self.w + x] = INK if x in (x0 - 2 + k, x0 + bw + 1 - k) else MIST
            self.frames["idle"] = [(px, 400)]

    def at(self, clip: str, t: float, loop: bool = True) -> list[int]:
        frames = self.frames.get(clip) or self.frames["idle"]
        total = sum(ms for _, ms in frames) / 1000.0
        if loop and total > 0:
            t = t % total
        acc = 0.0
        for px, ms in frames:
            acc += ms / 1000.0
            if t < acc:
                return px
        return frames[-1][0]


class Pack:
    """A built pack read through its manifest, like src/art/vfx_pack.gd."""

    def __init__(self, path: Path):
        m = json.loads((path / "manifest.json").read_text(encoding="utf-8"))
        c = next(c for c in m["clips"] if c["name"] == "whole")
        sh = c["sheets"][0]
        W, _, px = load_image(path / sh["file"])
        self.fw, self.fh = c["frame"]["w"], c["frame"]["h"]
        self.off = (c["offset"]["x"], c["offset"]["y"])
        self.frame_ms, self.loop = m["frame_ms"], m["loop"]
        self.layer = m.get("tessera", {}).get("layer", "overlay")
        cols = sh["columns"]
        self.frames = []
        for i in range(c["frames"]):
            ox, oy = (i % cols) * self.fw, (i // cols) * self.fh
            self.frames.append([px[(oy + y) * W + ox + x] for y in range(self.fh) for x in range(self.fw)])

    def frame(self, elapsed: float):
        if elapsed < 0:
            return None
        i = int(elapsed * 1000 // self.frame_ms)
        if self.loop:
            return self.frames[i % len(self.frames)]
        return self.frames[i] if i < len(self.frames) else None

    def draw(self, dst, W, H, elapsed, anchor):
        f = self.frame(elapsed)
        if f is not None:
            blit(dst, W, H, f, self.fw, self.fh, round(anchor[0]) + self.off[0], round(anchor[1]) + self.off[1])


# ---------------------------------------------------------------- the board and its actors
class Board:
    def __init__(self, tl: dict):
        self.cw, self.ch = tl["cell"]
        self.cols, self.rows, self.gap = tl["arena"]["cols"], tl["arena"]["rows"], tl["arena"]["gap"]
        self.mx, self.top = 10, tl.get("top", 56)
        self.W = 2 * self.mx + 2 * self.cols * self.cw + self.gap
        self.H = self.top + self.rows * self.ch + 10

    def xy(self, side, c, r):
        """Top-left of a cell. Player half: c = screen column (0 far left). Enemy half: c = 0 is the front column."""
        x = self.mx + c * self.cw if side == "player" else self.mx + self.cols * self.cw + self.gap + c * self.cw
        return x, self.top + r * self.ch

    def centre(self, side, c, r):
        x, y = self.xy(side, c, r)
        return x + self.cw // 2, y + self.ch // 2

    def feet(self, side, c, r):
        x, y = self.xy(side, c, r)
        return x + self.cw // 2, y + min(round(self.ch * FEET_DEPTH_RATIO), self.ch - 3)

    def to_global(self, side, cell):
        return (cell[0], cell[1]) if side == "player" else (self.cols + cell[0], cell[1])


class Actor:
    def __init__(self, cfg: dict, board: Board):
        self.cfg, self.side = cfg, cfg["side"]
        self.cell = tuple(cfg["cell"])
        self.footprint = [tuple(f) for f in cfg.get("footprint", [[0, 0]])]
        self.cells = [(self.cell[0] + dx, self.cell[1] + dy) for dx, dy in self.footprint]
        self.clips = Clips(cfg.get("unit"), tuple(cfg.get("stand_in", (64, 52))))
        front = max(r for _, r in self.cells)
        xs = [board.feet(self.side, c, r)[0] for c, r in self.cells if r == front]
        self.feet = (sum(xs) // len(xs), board.feet(self.side, self.cells[0][0], front)[1])
        self.row = front
        hx, hy = cfg.get("hand", [14, -34])
        self.hand = (self.feet[0] + hx, self.feet[1] + hy)
        self.hit_at: float | None = None
        self.offset = lambda t: (0, 0)
        self.frame_at = lambda t: self.clips.at("idle", t)

    def draw(self, img, W, H, t, flash_sec, flash_alpha, shake_px, shake_sec):
        px = self.frame_at(t)
        dx, dy = self.offset(t)
        if self.hit_at is not None and self.hit_at <= t < self.hit_at + 0.12 and "hit" in self.clips.frames:
            px = self.clips.at("hit", t - self.hit_at, loop=False)
        if self.hit_at is not None and self.hit_at <= t < self.hit_at + shake_sec:
            dx += shake_px if int((t - self.hit_at) * 30) % 2 == 0 else -shake_px
        if self.hit_at is not None and self.hit_at <= t < self.hit_at + flash_sec:
            px = [mix(c, WHITE, flash_alpha) if c else 0 for c in px]
        blit(img, W, H, px, self.clips.w, self.clips.h, self.feet[0] - self.clips.w // 2 + dx, self.feet[1] - self.clips.h + dy)


# ---------------------------------------------------------------- sequences -> plays
class Plays:
    """Everything that happens, as data: packs to draw (with start time and position), cell fills, telegraphs."""

    def __init__(self):
        self.packs: list[dict] = []      # {pack, start, pos: (x, y) | callable(t), until?}
        self.charge: list[dict] = []     # {cells: [(side, c, r)], t0, t1, body, hi}
        self.telegraph: list[dict] = []  # {cells, t0, t1}
        self.events: list[dict] = []     # for skill_timing.json

    def add(self, pack, start, pos, until=None):
        if pack is not None:
            self.packs.append({"pack": pack, "start": start, "pos": pos, "until": until})


def _pack_loader(packs_dir: Path, suffix: str):
    cache: dict[str, Pack | None] = {}

    def get(pid: str | None):
        if not pid:
            return None
        key = pid + suffix
        if key not in cache:
            # the variant made for this cell size, else the pack itself (packs that do not depend on the cell)
            path = next((packs_dir / k for k in (key, pid) if (packs_dir / k / "manifest.json").is_file()), None)
            cache[key] = Pack(path) if path else None
            if path is None:
                print(f"  timeline: pack {key} not built, skipped")
        return cache[key]

    return get


def player_cast(tl, board, caster, target, get) -> tuple[Plays, float]:
    P = Plays()
    roles = tl["packs"]
    mask = [tuple(c) for c in tl["mask"]]
    pre = tl["pre_sec"]
    swing = tl["swing_base_sec"] + tl["swing_per_cell_sec"] * len(mask)
    R = pre + swing
    delivery = tl["delivery"]
    caster_g = board.to_global(caster.side, caster.cell)
    arrive_g = arrival_times(delivery["type"], [board.to_global("enemy", c) for c in mask], caster_g, tl["timing"], delivery)
    arrive = {c: arrive_g[board.to_global("enemy", c)] for c in mask}
    first = min(arrive, key=lambda c: arrive[c])
    P.charge.append({"cells": [("enemy",) + c for c in mask], "t0": pre, "t1": R,
                     "body": hexc(tl["block_colours"][0]), "hi": hexc(tl["block_colours"][1])})
    P.events.append({"what": "swing / charge on the target cells", "from": 0.0, "to": round(swing, 3)})
    for c in mask:
        P.add(get(roles.get("gather")), pre, board.centre("enemy", *c), until=R)
    travel = bool(roles.get("travel"))
    launch = R - (tl["travel_sec"] if travel else 0.0)
    lead = tl.get("gesture_lead_sec", 0.0)
    if travel:
        if tl.get("charge_pack"):  # the game's existing hand-charge pack (PixelLab), drawn as the game draws it
            P.add(Pack(ROOT / tl["charge_pack"]), launch - tl["charge_sec"], caster.hand, until=launch)
        P.add(get(roles.get("release")), launch - lead, caster.hand)
        aim_cell = first
        ax = board.centre("enemy", *aim_cell)[0]
        ay = board.feet("enemy", *aim_cell)[1] - tl["aim_lift"]
        hx, hy = caster.hand
        P.add(get(roles["travel"]), launch,
              lambda t, a=(hx, hy, ax, ay): (a[0] + (a[2] - a[0]) * (t - launch) / max(1e-6, R - launch),
                                             a[1] + (a[3] - a[1]) * (t - launch) / max(1e-6, R - launch)), until=R)
        P.events.append({"what": "travel hand -> first cell", "from": round(launch - pre, 3), "to": round(swing, 3)})
    for c, at in arrive.items():
        big = c == first
        P.add(get(roles.get("first_mark" if big else "spread_mark")), R + at, board.centre("enemy", *c))
        P.add(get(roles.get("first" if big else "spread")), R + at, board.centre("enemy", *c))
        P.events.append({"what": f"impact {'first' if big else 'spread'} cell {list(c)}", "at": round(R - pre + at, 3)})
    if target.cell in arrive:
        target.hit_at = R + arrive[target.cell]
    # the caster's body
    gesture = caster.clips.frames.get("cast_gesture")
    if gesture:
        hold = tl["gesture_hold_frame"]
        ms = [m / 1000.0 for _, m in gesture]
        hold_from, release = sum(ms[:hold]), launch - lead - pre

        def frame_at(t):
            s = t - pre
            if s < 0:
                return caster.clips.at("idle", t)
            if s < hold_from:
                acc = 0.0
                for i, d in enumerate(ms):
                    acc += d
                    if s < acc:
                        return gesture[i][0]
            if s < release:
                return gesture[hold][0]
            uu, acc = s - release, 0.0
            for i in range(hold + 1, len(gesture)):
                acc += ms[i]
                if uu < acc:
                    return gesture[i][0]
            return caster.clips.at("idle", t)

        caster.frame_at = frame_at
    else:  # stand-in: the art bible's 0.2 s cast gesture as a 2 px push towards the enemy
        caster.offset = lambda t: (2, 0) if pre <= t < pre + 0.2 else (0, 0)
    return P, R + max(arrive.values())


def _entry_side(cell, parent) -> str:
    """The edge of `cell` that faces `parent` (where the root comes in from)."""
    if parent[0] > cell[0]:
        return "e"
    if parent[0] < cell[0]:
        return "w"
    return "n" if parent[1] < cell[1] else "s"


def enemy_skill(tl, board, caster, target, get) -> tuple[Plays, float]:
    P = Plays()
    roles = tl["packs"]
    mask = [tuple(c) for c in tl["mask"]]       # player half, screen columns
    pre, windup, warning = tl["pre_sec"], tl["windup_sec"], tl["warning_sec"]
    W0 = pre + windup
    R = W0 + warning
    delivery = tl["delivery"]
    caster_g = board.to_global("enemy", min(caster.cells))
    arrive = arrival_times(delivery["type"], mask, caster_g, tl["timing"], delivery)
    origin = origin_cell(delivery, mask, caster_g)
    # the enemy holds still in its wind-up pose through the warning (art bible §3: standing still is the tell)
    caster.offset = lambda t: (-2, 2) if pre <= t < R else (0, 0)
    P.add(get(roles.get("windup")), pre, caster.hand, until=R)
    P.events.append({"what": "windup (holds still, ivory squares at the hand)", "from": 0.0, "to": round(windup, 3)})
    P.telegraph.append({"cells": [("player",) + c for c in mask], "t0": W0, "t1": R})
    P.events.append({"what": "warning: red cells darken", "from": round(windup, 3), "to": round(windup + warning, 3)})
    lead = tl.get("crawl_lead_sec", 0.05)

    def root_cell(c, at, parent):
        side = _entry_side(c, parent)
        crawl_id = roles.get("crawl", "").replace("{from}", side) if roles.get("crawl") else None
        P.add(get(crawl_id), at - lead, board.centre("player", *c))
        P.add(get(roles.get("impact")), at, board.centre("player", *c))
        P.events.append({"what": f"root reaches cell {list(c)} from {side}, spike", "at": round(at - pre, 3)})

    for c in sorted(mask, key=lambda c: arrive[c]):
        if c == origin:
            parent = (c[0] + 1, c[1])          # the first cell: the root comes in from the enemy's side (east)
        else:
            parent = min((n for n in mask if manhattan(n, c) == 1), key=lambda n: arrive[n])
        root_cell(c, R + arrive[c], parent)
    end = R + max(arrive.values())
    fu = tl.get("followup")
    if fu:
        fc = [tuple(c) for c in fu["cells"]]
        RF = R + fu["warning_sec"]
        P.telegraph.append({"cells": [("player",) + c for c in fc], "t0": R, "t1": RF})
        P.events.append({"what": "followup warning", "from": round(R - pre, 3), "to": round(RF - pre, 3)})
        for c in fc:
            parent = min(mask, key=lambda n: manhattan(n, c))
            root_cell(c, RF, parent)
        end = RF
        if target.cell in fc:
            target.hit_at = RF
    if target.cell in arrive:
        target.hit_at = R + arrive[target.cell]
    return P, end


# ---------------------------------------------------------------- render
def _fill_cells(img, W, board, cells, fn):
    for side, c, r in cells:
        x0, y0 = board.xy(side, c, r)
        for y in range(y0 + 2, y0 + board.ch - 4):
            for x in range(x0 + 1, x0 + board.cw - 2):
                img[y * W + x] = fn(img[y * W + x], x - x0, y - y0)


def build_timeline(tl: dict, packs_dir: Path, out_dir: Path, suffix: str = "") -> dict:
    board = Board(tl)
    W, H = board.W, board.H
    caster, target = Actor(tl["caster"], board), Actor(tl["target"], board)
    get = _pack_loader(packs_dir, suffix)
    seq = tl.get("sequence", "player_cast")
    plays, last = (player_cast if seq == "player_cast" else enemy_skill)(tl, board, caster, target, get)
    pre, post = tl["pre_sec"], tl["post_sec"]
    end = last + post
    hf = tl["hit_feel"]
    fps = tl["fps"]
    frames, delays, keys = [], [], []
    action_from = min([p["start"] for p in plays.packs] + [pre]) - 0.1
    for i in range(int(end * fps) + 1):
        t = i / fps
        img = [GROUND] * (W * H)
        for side in ("player", "enemy"):
            for r in range(board.rows):
                for c in range(board.cols):
                    x, y = board.xy(side, c, r)
                    blit(img, W, H, slab(board.cw, board.ch), board.cw, board.ch, x, y)
        for ch in plays.charge:                 # the game's code charge: 4 steps of the block colour, 2 px rim
            if ch["t0"] <= t < ch["t1"]:
                a = 0.35 + 0.40 * int(min(3, (t - ch["t0"]) / (ch["t1"] - ch["t0"]) * 4)) / 3
                cw, chh = board.cw, board.ch
                _fill_cells(img, W, board, ch["cells"], lambda c, x, y, a=a, ch=ch, cw=cw, chh=chh:
                            ch["hi"] if (y < 4 or y >= chh - 6 or x < 3 or x >= cw - 4) else mix(c, ch["body"], a))
        for tg in plays.telegraph:              # the enemy warning: stripes 0.5 -> 1, fill 0 -> 0.45, rim 0.3 -> 1
            if tg["t0"] <= t < tg["t1"]:
                k = (t - tg["t0"]) / (tg["t1"] - tg["t0"])
                cw, chh = board.cw, board.ch

                def red(c, x, y, k=k, cw=cw, chh=chh):
                    if y < 4 or y >= chh - 6 or x < 3 or x >= cw - 4:
                        return mix(c, RED, 0.3 + 0.7 * k)
                    if (x + y) % 6 < 3:
                        return mix(c, RED, 0.5 + 0.5 * k)
                    return mix(c, RED, 0.45 * k)

                _fill_cells(img, W, board, tg["cells"], red)
        live = [p for p in plays.packs if p["start"] <= t and (p["until"] is None or t < p["until"])]
        for p in live:
            if p["pack"].layer == "floor":
                pos = p["pos"](t) if callable(p["pos"]) else p["pos"]
                p["pack"].draw(img, W, H, t - p["start"], pos)
        for a in sorted((caster, target), key=lambda a: a.row):
            a.draw(img, W, H, t, hf["flash_sec"], hf["flash_alpha"], hf["shake_px"], hf["shake_sec"])
        for p in live:
            if p["pack"].layer != "floor":
                pos = p["pos"](t) if callable(p["pos"]) else p["pos"]
                p["pack"].draw(img, W, H, t - p["start"], pos)
        frames.append(upscale(img, W, H, tl["zoom"]))
        delays.append(round(100 / fps))
        if action_from <= t <= last + 0.4:
            keys.append(img)
    out_dir.mkdir(parents=True, exist_ok=True)
    write_gif(out_dir / "timeline.gif", W * tl["zoom"], H * tl["zoom"], frames, delays)
    keys = keys[::2]
    cols = 4
    rows = (len(keys) + cols - 1) // cols
    SW, SH = cols * (W + 2) - 2, rows * (H + 2) - 2
    sheet = [INK] * (SW * SH)
    for j, img in enumerate(keys):
        blit(sheet, SW, SH, img, W, H, (j % cols) * (W + 2), (j // cols) * (H + 2))
    write_png(out_dir / "timeline-keys.png", SW, SH, sheet)
    timing = {"sequence": seq, "t0": "0 = the timeline's action start (pre_sec trimmed)",
              "events": plays.events, "ends": round(last - pre, 3),
              "hit": None if target.hit_at is None else {"unit": tl["target"].get("unit"), "at": round(target.hit_at - pre, 3),
                                                         "flash_sec": hf["flash_sec"], "shake_px": hf["shake_px"],
                                                         "freeze_sec": tl.get("freeze_sec", 0)}}
    (out_dir / "skill_timing.json").write_text(json.dumps(timing, indent=1, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    return timing
