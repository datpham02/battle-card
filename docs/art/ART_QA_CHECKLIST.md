# Art QA Checklist

Run for every candidate before it is logged, and again before it is exported.
Lines marked **[auto]** have a command; the rest are by eye on the in-game
screenshot (art bible §8.9 #9: the screenshot is retained in
`production/qa/evidence/`). Art bible §8.9 is the authority; this page adds
the automated commands and the lessons of 2026-10-31.

## A. Before drawing or generating (gate — see workflow §1)

- [ ] Art bible sections for this asset re-read; neighbours it will sit next to opened.
- [ ] View written down and matches the game (slabs seen slightly from above, scenery band on top). *Side-view or isometric scenes are rejected before any pixel is checked.*
- [ ] Layout constraints written: what covers the asset, visible strip, display scale, palette subset.
- [ ] Closest look-alike named and differentiated.
- [ ] Method chosen (script / workbench / generation) and, for generation, the prompt and the number of generations shown to the user; one generation first.

## B. Pixel integrity

- [ ] **[auto]** `pixelart_workbench lint <id>` — no `orphan_pixel`, no `outline_gap` on units and blocks, no anti-aliasing fringe.
- [ ] **[auto]** `pixelart_workbench score <id>` recorded in the spec log.
- [ ] One pixel size across the asset and its neighbours (no mixed scales, no non-integer upscale).
- [ ] Alpha only 0 or 255 on sprites and backdrops (overlays and HUD glass excepted).
- [ ] Canvas size exactly as specified; ≥ 1 transparent px on every side; nothing touches the canvas edge.
- [ ] Transparent background where required (`no_background` output or checked by the lint).

## C. Colour

- [ ] **[auto]** `pixelart_workbench extract-palette <id>` — every colour in the master palette or the region subset; counts within the per-sprite limit (hero ≤ 8, monster ≤ 8, warden ≤ 12).
- [ ] No red #E5293B outside the telegraph; no smooth gradient; dither only where §6.2 allows.
- [ ] Shading is banded (2–3 steps) with the scene's light direction (top-left); no pillow shading.
- [ ] Value separation measured where the bible gives a number: §6.6 legibility (≥ 40 % of a unit's upper-half pixels at ΔV ≥ 25 against the slab, measured by script as for the goblin).

## D. Outline and shape

- [ ] Units and blocks: 1 px closed Ink #1B1722 outline; slabs, backdrop and HUD frames: no Ink outline.
- [ ] Only squares and 45° steps where the bible asks (blocks, VFX, icons).
- [ ] Silhouette / blackout test at 1x: heroes and same-region monsters distinguishable; identity in the upper half.
- [ ] Three-in-a-column test: three monsters on adjacent rows stay countable.

## E. Animation and sheets

- [ ] Same canvas for every frame; feet on the same row; no outline jitter between frames (play the GIF from art-check, do not judge stills).
- [ ] Frame count and holds as in the spec; clip plays inside the canvas (drawn weapons included).
- [ ] Sheet: one row per clip, fixed cells, 1 px gutter; JSON frame rects match the PNG.

## F. In context (the check that catches what single-asset checks miss)

- [ ] Rendered in `prototypes/art-check` (or the game) at the real scale next to real neighbours, HUD on, the chosen backdrop behind; screenshot retained.
- [ ] Whole-frame read: does the screen read as one picture (backdrop, board, units, HUD), or as pasted parts? Squint test on the screenshot.
- [ ] Nothing fights the HUD or the touch zones; the control zone has a quiet base.
- [ ] Perspective and ground plane agree with the board (no horizon cut by a straight line, no trunks standing in front of the board).
- [ ] Layer order right: floor overlays under units, VFX and frames above units and above landed blocks.

## G. Record

- [ ] Production log row in the spec: date, method, generations spent, result, open points, deviation from the bible if any.
- [ ] Manifest row updated; evidence file numbers listed.
- [ ] Open points that need the art-director named explicitly, not folded into "done".

## Known automated coverage gaps

- §8.9 #1–#3 (blackout, upper half, three rows) are by eye; a blackout render exists in art-check (`--mode=blackout`, `--mode=rows`) but the verdict is human.
- The §6.6 contrast measurement counts outline pixels in the denominator; the rule for outline-heavy sprites is open.
- No automated check for "same light direction" or "pillow shading"; those are the reviewer's.
