"""Closed-form particle motion (PixelFX particles.js fly/burst/cycle/stream), so any frame is a pure function of t.

`shard` adds what PixelFX gets from its simulated GRIT particle: fall, bounce once, settle; solved analytically
instead of stepped, so a sheet frame can be drawn at any t without running a simulation.
"""
from __future__ import annotations

import math
from typing import Callable

from .rng import Rng, rng


def fly(x: float, y: float, vx: float, vy: float, t: float, g: float = 0.0, drag: float = 0.0) -> tuple[float, float]:
    """Where a particle is t s after leaving (x, y) at (vx, vy) px/s, under gravity g (down +) and linear drag."""
    if drag <= 0:
        return x + vx * t, y + vy * t + 0.5 * g * t * t
    f = (1 - math.exp(-drag * t)) / drag
    vt = g / drag
    return x + vx * f, y + vt * t + (vy - vt) * f


def shard(x: float, y: float, vx: float, vy: float, t: float, g: float, floor_y: float,
          bounce: float = 0.3, slide: float = 0.5) -> tuple[float, float, int]:
    """A falling bit: flies, lands on floor_y (its own depth on the slab), bounces once, rests.

    Returns (x, y, phase) with phase 0 flying, 1 bouncing, 2 resting.
    """
    a, b, c = 0.5 * g, vy, y - floor_y
    disc = b * b - 4 * a * c
    if g <= 0:
        return x + vx * t, y + vy * t, 0
    if disc < 0:  # the floor is above the arc's apex: it "lands" at the apex
        t1 = max(0.0, -vy / g)
    else:
        t1 = (-b + math.sqrt(disc)) / (2 * a)
    if t < t1:
        return x + vx * t, y + vy * t + a * t * t, 0
    x1, y1 = x + vx * t1, y + vy * t1 + a * t1 * t1
    v_land = vy + g * t1
    vy2 = -abs(v_land) * bounce
    vx2 = vx * slide
    t2 = 2 * abs(vy2) / g
    u = t - t1
    if u < t2:
        return x1 + vx2 * u, y1 + vy2 * u + a * u * u, 1
    return x1 + vx2 * t2, y1, 2


def burst(n: int, seed: int, fn: Callable[[Rng, int], None]) -> None:
    """n one-shot particles, each with its own repeatable generator."""
    for i in range(n):
        fn(rng(seed, i), i)


def cycle(t: float, period: float, count: int, seed: int, life, fn: Callable[[float, float, Rng, int], None]) -> None:
    """Particles repeating every `period` s, for seamless loops: fn(age, life, rng, i) for every live copy."""
    for i in range(count):
        g = rng(seed, i, 911)
        born = g.next() * period
        L = life(g) if callable(life) else life
        age = ((t - born) % period + period) % period
        while age < L:
            fn(age, L, rng(seed, i), i)
            age += period


def stream(t: float, t0: float, t1: float, rate: float, seed: int, life, fn: Callable[[float, float, Rng, int], None]) -> None:
    """Particles born at `rate` per s between t0 and t1: fn(age, life, rng, i) for every one alive at t."""
    n = int((min(t, t1) - t0) * rate)
    for i in range(n + 1):
        born = t0 + i / rate
        g = rng(seed, i, 911)
        L = life(g) if callable(life) else life
        age = t - born
        if 0 <= age < L:
            fn(age, L, rng(seed, i), i)
