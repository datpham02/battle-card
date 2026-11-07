"""Component registry: name -> instance. A recipe names components by these keys."""
from __future__ import annotations

from .fire import FlameBurst, SquareFireball
from .gather import SquareGather
from .roots import RootCrawl, RootSpike
from .squares import SquareBurst, SquareMark, SquareSlash, SquareWave

REGISTRY = {c.name: c for c in (SquareWave(), SquareSlash(), SquareBurst(), SquareMark(), SquareGather(),
                                FlameBurst(), SquareFireball(), RootCrawl(), RootSpike())}


def get(name: str):
    if name not in REGISTRY:
        raise KeyError(f"no component '{name}' (have {sorted(REGISTRY)})")
    return REGISTRY[name]
