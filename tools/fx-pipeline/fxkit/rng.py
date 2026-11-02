"""Seeded randomness only (PixelFX math.js hash, rand, Rng, rng): the same frame every render."""
from __future__ import annotations

M32 = 0xFFFFFFFF


def _imul(a: int, b: int) -> int:
    return (a * b) & M32


def hash_ints(*ns: int) -> int:
    h = 0x9E3779B9
    for n in ns:
        h = _imul(h ^ (int(n) & M32), 0x85EBCA6B)
        h ^= h >> 13
        h = _imul(h, 0xC2B2AE35)
        h ^= h >> 16
    return h & M32


def rand(*ns: int) -> float:
    """Deterministic number in [0, 1) from integers (seed, particle index, which value...)."""
    return hash_ints(*ns) / 4294967296.0


class Rng:
    """mulberry32."""

    def __init__(self, seed: int = 1):
        self.s = (int(seed) & M32) or 1

    def next(self) -> float:
        self.s = (self.s + 0x6D2B79F5) & M32
        t = self.s
        t = _imul(t ^ (t >> 15), t | 1)
        t ^= (t + _imul(t ^ (t >> 7), t | 61)) & M32
        return ((t ^ (t >> 14)) & M32) / 4294967296.0

    def range(self, a: float, b: float) -> float:
        return a + (b - a) * self.next()

    def int(self, a: int, b: int) -> int:
        return min(b, a + int(self.next() * (b - a + 1))) if b > a else a

    def chance(self, p: float) -> bool:
        return self.next() < p

    def sign(self) -> int:
        return -1 if self.next() < 0.5 else 1

    def pick(self, items):
        return items[int(self.next() * len(items))]


def rng(*ns: int) -> Rng:
    """A generator for one particle: rng(seed, i) gives the same numbers every frame."""
    return Rng(hash_ints(*ns))
