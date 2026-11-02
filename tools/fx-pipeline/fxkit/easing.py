"""Timing helpers (PixelFX math.js): windows, smoothstep, bumps and easing curves, all pure."""
from __future__ import annotations

import math


def clamp(x: float, a: float = 0.0, b: float = 1.0) -> float:
    return a if x < a else b if x > b else x


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def seg(t: float, t0: float, t1: float) -> float:
    """Progress 0..1 of t through [t0, t1]: 0 before, 1 after."""
    return clamp((t - t0) / (t1 - t0)) if t1 != t0 else (1.0 if t >= t1 else 0.0)


def smooth(e0: float, e1: float, x: float) -> float:
    t = seg(x, e0, e1)
    return t * t * (3 - 2 * t)


def bump(t: float, t0: float, t1: float) -> float:
    """0 -> 1 -> 0 over [t0, t1]."""
    return 0.0 if t <= t0 or t >= t1 else math.sin(math.pi * seg(t, t0, t1))


def out_quad(t: float) -> float:
    return 1 - (1 - t) * (1 - t)


def out_cubic(t: float) -> float:
    return 1 - (1 - t) ** 3


def out_quart(t: float) -> float:
    return 1 - (1 - t) ** 4


def out_expo(t: float) -> float:
    return 1.0 if t >= 1 else 1 - 2 ** (-10 * t)


def in_quad(t: float) -> float:
    return t * t


def out_back(t: float, s: float = 1.70158) -> float:
    if t <= 0:
        return 0.0
    if t >= 1:
        return 1.0
    return 1 + (s + 1) * (t - 1) ** 3 + s * (t - 1) ** 2
