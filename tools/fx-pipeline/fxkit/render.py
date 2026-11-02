"""Sample a component into frames (PixelFX tools/lib/fxlib.mjs renderFrames, pure components only)."""
from __future__ import annotations

import math
from dataclasses import dataclass, field

from .component import Component
from .painter import LAYERS, Layer, over, painters


@dataclass
class Render:
    comp: Component
    o: dict
    w: int
    h: int
    ox: int
    oy: int
    fps: int
    frame_ms: int
    loop: bool
    duration: float
    frames: list[dict[str, Layer]] = field(default_factory=list)
    spill: int = 0

    @property
    def n(self) -> int:
        return len(self.frames)

    def whole(self, i: int) -> list[int]:
        f = self.frames[i]
        return over(f["behind"].px, f["front"].px)

    def used_layers(self) -> list[str]:
        return [k for k in LAYERS if any(not f[k].is_empty() for f in self.frames)]


def frame_times(duration: float, fps: int, loop: bool) -> list[float]:
    """A loop: round(duration * fps) frames that wrap. A one-shot: every frame strictly before `duration`
    (the component must draw nothing at t = duration, checked separately)."""
    n = round(duration * fps) if loop else math.ceil(duration * fps - 1e-9)
    return [i / fps for i in range(max(1, n))]


def draw_frame(comp: Component, o: dict, t: float, margin: int = 0, flip: bool = False) -> tuple[dict[str, Layer], int, tuple]:
    """One frame at t on the component's box grown by `margin` px each side; returns (layers, spill, box)."""
    w, h, ox, oy = comp.box(o)
    W, H = w + 2 * margin, h + 2 * margin
    layers, P = painters(W, H, ox + margin, oy + margin, flip)
    comp.draw(P, t, o)
    return layers, sum(p.spilled for p in P.values()), (W, H, ox + margin, oy + margin)


def render(comp: Component, o: dict, fps: int) -> Render:
    o = comp.options(o)
    w, h, ox, oy = comp.box(o)
    dur = comp.duration(o)
    r = Render(comp, o, w, h, ox, oy, fps, round(1000 / fps), comp.loop, dur)
    for t in frame_times(dur, fps, comp.loop):
        layers, spill, _ = draw_frame(comp, o, t)
        r.frames.append(layers)
        r.spill += spill
    return r
