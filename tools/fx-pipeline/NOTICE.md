# Notices

fxkit is written for Tessera. Its structure and several small routines follow PixelFX
(https://github.com/patch-gg/pixelfx), studied in `docs/research/pixelfx-study.md`:

- the effect contract (a pure `draw(p, t, o)`, local space around an anchor, placement and flip that land on
  whole pixel cells, colour 0 = draw nothing) — `src/core/painter.js`, `docs/AUTHORING.md`;
- ramps resampled by `fit` and stepped by `at` — `src/core/color.js`;
- seeded randomness (`hash`, `rand`, mulberry32 `Rng`, `rng(seed, i)`) and the timing helpers (`seg`,
  `smooth`, `bump`, eases) — `src/core/math.js`;
- closed-form particles `fly`, `burst`, `cycle`, `stream` — `src/core/particles.js`;
- the checks for spill, ending empty, loop seams and determinism — `tools/check.mjs`.

PixelFX is MIT licensed:

> MIT License. Copyright (c) 2026 Patch. Copyright (c) 2026 Hugo Duprez.
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
> documentation files (the "Software"), to deal in the Software without restriction, including without
> limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the
> Software, and to permit persons to whom the Software is furnished to do so, subject to the following
> conditions: The above copyright notice and this permission notice shall be included in all copies or
> substantial portions of the Software. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.

No PixelFX effect, sprite, character or font is copied. The PNG decoder follows this repository's own
`tools/asset-pipeline/export_sheets.py`; the GIF writer follows `prototypes/art-check/tools/make_gif.py`.
