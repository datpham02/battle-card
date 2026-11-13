# QA — impact_flash_steel_pixelfx v1 (2026-11-11)

## Request
- Asset: `vfx.floor.impact_flash_steel_pixelfx` (P3 proof of concept, not a card's effect yet)
- Why: show the PixelFX -> Tessera VfxPack path end to end before any real effect is built this way

## Call
- Provider / tool: pixelfx (impacts/hit-flash, upstream commit a841596) rendered with `node tools/render.mjs --sheet --fps 20 --seed 17` and the steel ramp; adapted by `tools/fx-pipeline/pixelfx_adapter.py adapt --frames 0:5 --frame-ms 50 --layer overlay --anchor ground_center --cell 64x46 --ramp steel`
- Cost: 0 gen (PixelFX is free)

## Measured
- 7 frames x 50 ms = 350 ms (overlay rule), 80x64, pivot (40, 54), 4 colours all in the master palette, alpha 0/255, no border touch, no telegraph red
- 7231 glow pixels dropped (alpha < 128), 194 translucent kept, 673 source colours snapped to 4
- `fxc check`: PASS (info: up to 40 clusters a frame, 16 single-px specks)
- `node tools/check.mjs impacts/hit-flash`: ok

## Verdict
- Technical: **PASS** (2026-11-11)
- User: pending

## Next
Review `preview/REVIEW.md`; the user decides accept / retake / reject. Known: the upstream effect is a red/white flash with radial lines; with the steel ramp it reads as a steel burst.
