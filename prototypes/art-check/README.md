# art-check — slice-1 sprites on the 5x5 board

**Hypothesis:** the PixelLab candidates for the Swordsman (ASSET-001) and the
Goblin Scout (ASSET-003) pass art bible §8.9 #1 (blackout silhouettes on a 5x5
board), #3 (three monsters in one column on adjacent rows stay countable) and
#9 (in-game screenshot retained) under the §8.2–8.3 render rules: 640x360 art
canvas at an integer scale, Nearest filtering, 38x27 art-px slabs (the
smallest allowed, so the hardest case), units anchored bottom-centre 3 art-px
above the slab's front edge, back rows drawn first.

The battle itself still draws vector markers at 1280x720 (the SubViewport
story is not done), so this scene stands in for it. Nothing in `src/` uses it.

## Run

```
godot --path . --windowed --resolution 1280x720 res://prototypes/art-check/art_check.tscn -- --mode=normal --shot=C:/abs/out.png
```

`--mode=normal|blackout|rows`, `--cell=WxH` (default 38x27), `--scale=N`
(default 2), `--shot=<png>` saves the window after 30 frames and quits. Sprites
are read from `design/assets/candidates/` with `Image.load_from_file`, so new
candidates need no import.

## Status

concluded (2026-10-31) — kept for re-runs when a new candidate lands.

## Findings

Evidence: `production/qa/evidence/asset-slice1-art-check/01-pair-5x5.png`,
`02-blackout.png`, `03-three-goblins-rows.png`. Verdicts are logged in the
asset specs (`design/assets/specs/*-assets.md`, generation log tables).

- §8.9 #1 (blackout) passes for the pair: hero = spiky hair + sword hilt,
  goblin = pointed hood + side ear, clearly smaller. The full test needs all
  five heroes.
- §8.9 #3 (three goblins, one column, adjacent rows) passes: countable, species
  readable, each hood top shows above the unit in front.
- §8.9 #9 passes (screenshots retained).
- Concern found and fixed: the goblin's leather tones sat at the slab's value
  (leather dark #4A3C2E vs Stone #4A4640, both V 29 %), so the body read as a
  dark blob at 1x. Lifted one step (#856B50 / #66523F) and re-run: `04-*` and
  `05-*` show the body separating from the slab; #3 still passes.
- The 38x27 slab with a 48 px sprite behaves as §1 expects: a unit covers the
  lower half of the one on the row behind; identity stays in the upper 20 px.
- Technique notes for the SubViewport story: `Image.load_from_file` +
  `ImageTexture.create_from_image` with `texture_filter = NEAREST` on the
  sprite and `canvas_item_default_texture_filter = NEAREST` plus both
  `snap_2d_*_to_pixel` on the SubViewport gave clean pixels at 2x; the
  self-capture (`await RenderingServer.frame_post_draw`, then
  `get_viewport().get_texture().get_image().save_png`) worked windowed.
