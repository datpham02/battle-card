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

`--mode=normal|blackout|rows`, `--board=CxR` (cells per half, default 5x5),
`--cell=WxH` (default 38x27), `--scale=N` (default 2), `--hud` (flat
placeholder zones Z1–Z5 of `design/ux/hud.md` drawn at 1280x720 on top),
`--layout=v1|v2` (v1 = shipped ScreenLayout; v2 = the 2026-10-31 sketch:
arena to 64 %, floating 4-way joystick, slots on an arc),
`--arena=<id>` (a shape of `assets/data/arenas.json`: bounding grid plus
missing cells, mirrored onto the enemy half like BoardGrid; units stand on
BoardGrid's default cells), `--cell=auto` (largest 1.4-aspect slab between
38x27 and 64x46 that fits the band and the width),
`--anim=<clip>` (idle, step, hit, defeat, victory, fall, cast, awaken; both
units cycle their candidate frames at the spec hold, and with `--shot` one PNG
per frame index is written as `<shot>-<i>.png`),
`--slabs=<9slice.png>,<stamps.png>` draws the real ASSET-004 slab art (the
16x16 nine-slice stretched per cell with `draw_texture_rect_region`, stamps
from the sheet placed by cell seed; JSON beside the stamps PNG gives rects,
anchors and margins) instead of the flat placeholder slab,
`--props=<wall.png>,<thorns.png>` places the Wall one cell ahead of the hero
(unit layer, with a stand-in unit on the row behind it) and the Thorns on the
floor layer beside the goblin,
`--bg=<far.png>[,<near.png>]` draws the ASSET-005 backdrop layers (far
centred under everything, the 800-wide layer's outer 80 px hidden on a 640
canvas; near = mist band with its bottom on canvas row 46, the horizon + 2),
`--ui=<dir>` draws the ASSET-013 frames (9-slice at x2: slots, pad and Awaken
buttons, pause panel, bars with the ASSET-014 fills in code) and ASSET-015
icons from that folder in place of the flat HUD rects, and hides the zone
labels; `--fx=<dir>` puts the slice-1 floor/VFX candidates on the board
(ASSET-012 telegraph on the hero's cell and the one below, ASSET-011 steel
target tiles under the goblin, ASSET-008 lying T block and falling domino,
ASSET-009 slash frame 3 tinted steel on the target tiles),
`--seq=slash|push` (needs `--fx`) plays the cast sequence as keyframes: target
ramp, cast A/B, the steel domino falling, the VFX sheet at its own timings
with the goblin's hit frame and an Ivory flash (a 2-line shader standing in
for ASSET-010), rest; with `--shot` every keyframe is saved as
`<shot>-NN.png` plus `<shot>.json` (durations in cs), and
`tools/make_gif.py OUT.gif X0 Y0 X1 Y1 @<shot>.json SCALE <frames…>` turns
them into a GIF with per-frame delays (`tools/` holds the pure-Python GIF
encoder and PNG reader that used to live in the session scratchpad),
`--shot=<png>` saves the window after 30 frames and quits.
`make_gif.py` in the session scratchpad turned those frames into the looping
GIFs under `production/qa/evidence/asset-slice1-art-check/anim/` (pure Python,
no Pillow). The board sits in
the ScreenLayout band (below the 3–13 % HUD band, above the 55 % control band).
Since 2026-10-31 the hero frame is 40x48 (`ASSET-001-*-40x48.png`). Sprites
are read from `design/assets/candidates/` with `Image.load_from_file`, so new
candidates need no import.

## Status

concluded (2026-10-31) — kept for re-runs when a new candidate lands. The
layout findings became `design/quick-specs/control-layout-v2.md` and
Story 044 (`production/epics/kaiten-duel/story-044-control-layout-v2.md`);
the user chose the 6x6 crystal with the band to 76 % as the largest board.

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
- 2026-10-31 later: the Swordsman was redesigned (v1 read as Cloud from FF7).
  `06-pair-5x5-swordsman-v2.png` and `07-blackout-swordsman-v2.png` re-run #1
  with the v2 anchor: silhouette = round head, T-shaped hilt above it, boxy
  pauldrons; still clearly not the goblin.
- 2026-10-31, scale check with the placeholder HUD (`08-hud-5x5-cell38x27.png`,
  `09-hud-3x3-cell64x46.png`, `10-hud-5x5-rows.png`; dark fills only on the
  touch targets per art bible §7.2): at 1280x720 the hero is 86 px tall (12 %
  of the screen), the goblin 58 px; a 5x5 cell is 76x54 screen px, a 3x3 cell
  128x92. The board band Z2 (14–55 % of the height) is 295 px, so a 5x5 board
  is never taller than ~270 px whatever the sprites do: the "small arena"
  feeling comes from the thumb layout (controls own 45 % of the height, slots
  22 % tall, pad buttons 13.5 %), not from the sprite size. Hero : cell ratio
  matches the OSFE reference (about one cell tall on 3x3, 1.6 on 5x5). Levers
  if it must be bigger: lower ARENA_BOTTOM_RATIO (0.55) and shrink Z4/Z5 while
  keeping 88 px touch targets; a 3x canvas (427x240) would not fit 5x5 in the
  band. That is a UX decision (`design/ux/hud.md`), sprites would not change.
- 2026-10-31, layout v2 mock from the user's sketch (`11-layout-v2-5x5-cell48x34.png`,
  `12-layout-v2-3x3-cell64x46.png`, `13-layout-v2-5x5-rows.png`): arena bottom
  55 % -> 64 % (board band 295 -> 360 px), floating 4-way joystick in a
  0–30 % x 64–100 % home zone (base 160 px, knob 88 px; the zone starts at the
  arena bottom so a touch on the board's last row is never a stick), three
  130x93 px slots on an arc (radius 2x slot height around the right thumb
  pivot, 100/128/156 degrees, 28 degrees apart so they never touch), Awaken
  115 px low centre, no solid control band. 5x5 slabs grow
  from 38x27 to 48x34 art-px (+26 %), 3x3 stays at the 64x46 ceiling. The board
  (972 px wide at 5x5) stays clear of both thumb zones. Pending: the user's
  verdict, then `design/quick-specs/control-layout-v2.md`, `hud.md` Z3/Z5
  and a UI story (ScreenLayout, joystick input, Settings fallback to the pad).
- 2026-10-31, real arena shapes in layout v2 with `--cell=auto`
  (`14-layout-v2-arena-ring.png` 6x5 -> 49x35 slabs, `15-…-three-isles.png`
  7x2 -> 42x30, `16-…-cross.png` 4x4 -> 60x43, `17-…-islands-bridge.png`
  6x3 -> 49x35): every one of the 19 shapes of `arenas.json` fits (bounding
  box <= 7x6 per half); wide shapes are limited by the half width (298 art-px),
  tall ones by the band (176 art-px). Missing cells show the ground, so the
  slab 9-slice needs edge pieces on all four sides plus inner corners (ASSET-004,
  art bible §6.3). Units stand on BoardGrid's default cells.
- 2026-10-31, "crystal" ad-hoc shape at the v2 ceiling (`18-layout-v2-arena-crystal-7x6.png`,
  `19-…-rows.png`; `--board=7x6 --missing=0,0;1,0;2,0;0,1;1,1;0,2;0,3;0,4;1,4;0,5;1,5;2,5`):
  a 7x6 bounding box per half with the far corners cut in steps (3/2/1/1/2/3),
  30 real cells per half, slabs 40x29 art-px (80x58 on screen). This is the
  biggest board v2 can hold: 1206 px of the 1280 width, 348 of the 360 px band.
  The hero (86 px) is 1.5 cells tall, the goblin one cell; three goblins in a
  column still count as three. Not in `arenas.json`; gameplay (step paths,
  block placement on 30 cells) is a design question before it becomes a shape.
- 2026-10-31, "can the board grow into the free space?" (`20-layout-v2b-crystal-6x6-band76.png`,
  `21-layout-v2b-crystal-7x6-band76.png`; `--arena-bottom=0.76`, controls still
  start at 64 %, joystick zone narrowed to 25 % of the width): the side space
  the user circled is the crystal's own cut corners plus the 3 % margin, nothing
  to gain there. The gap under the board between the thumbs (x 330–980, y
  460–580) can take the board's narrow bottom rows: with the band to 76 % a
  6x6 crystal grows from 40x29 to 49x35 slabs (+20 %), while the 7x6 crystal
  stays at 42x30 because seven columns are already width-bound (298 art-px per
  half / 7 / 1.4 = 30 px tall). Rule of thumb: width binds at >= 6 columns,
  height binds at <= 5 columns; a taller band only helps shapes up to 6 wide.
  Costs of the 76 % band: ScreenLayout needs a non-rectangular safe area (full
  width to 64 %, 330–980 px below), and a 6-row board's bottom row sits 100 px
  from the Awaken button.
- 2026-10-31, clips played in the scene (`anim/<clip>.gif` + `<clip>.strip.png`,
  layout v2, 5x5 at 48x34, 2x crop of the two units): all 8 hero clips and the
  goblin's idle/step/hit/down/windup cycle without foot drift or outline
  jitter (anchor fixed by the shared canvas); cast B's blade points at the
  enemy half, awaken's cape reads at 1x, defeat/down settle on the slab. Art
  bible §8.9 #7 passes by eye for the candidate set. Not covered: real hold
  times per frame (one hold per clip here) and the hit flash shader.
- 2026-10-31, HUD with the real frames and icons (`35-ui-layout-v2-5x5.png`,
  `36-ui-layout-v1-5x5.png`, `37-ui-frames-zoom-x3.png`; `--ui`): the 16x16
  9-slices stretch to every control size without seams, the notched corners
  survive x2, the Ink lip only reads once it hangs below the Mist border (inside
  the #1E1B24 fill it is one value step and invisible — logged as a deviation in
  the ASSET-013 spec). Icons at 24 px are fine on the pause panel and the slots;
  on 97–115 px buttons the glyph is drawn x4 (48 px). Open: §7.5 "28 px arrows"
  vs the 12 px grid; the 16 px bar vs §7.5 "12 px".
- 2026-10-31, floor and VFX candidates on the board (`38-fx-layout-v2-5x5.png`,
  `39-fx-zoom-x3.png`; `--fx`): the telegraph (stripe texture tiled on the floor
  layer, 2 px red frame + 1 px Ink edge on the overlay) stays readable with the
  hero standing on it; the steel target tile (60 % body, raised edge, bevel mark
  nine-sliced) is clearly not the telegraph and not the slab; the lying 5x5 T
  block and the falling 16x16 domino read with their 1 px halo. The first slash
  (2x2 squares, 4 px on screen) was thin; redrawn the same day as a solid 3 px
  stepped band (3x3 squares overlapping), which reads as one cut at 2x — the
  §3 "2x2" wording is the open point, logged in the ASSET-009 spec.
- 2026-10-31, cast sequence (`anim/seq-slash.gif`, `anim/seq-push.gif`, their
  `.sheet.png` contact sheets; `--seq`): 13 keyframes, ~2.1 s per cycle. The
  order the user described — choose tiles, choose the card, cast gesture, the
  block drops on the chosen tiles, the card's VFX in each tile, the enemy
  reacts — holds with the existing frames; the slash and the push differ by
  shape and direction with the same tint. Found and fixed on the way: the
  VFX must draw above the landed block (first pass drew it underneath), and a
  modulate-based flash turns the Ink outline purple, so the flash is a real
  colour-replace shader. Not covered: the block's dissolve or engraving after
  the hit, the real channel time.
- The 38x27 slab with a 48 px sprite behaves as §1 expects: a unit covers the
  lower half of the one on the row behind; identity stays in the upper 20 px.
- Technique notes for the SubViewport story: `Image.load_from_file` +
  `ImageTexture.create_from_image` with `texture_filter = NEAREST` on the
  sprite and `canvas_item_default_texture_filter = NEAREST` plus both
  `snap_2d_*_to_pixel` on the SubViewport gave clean pixels at 2x; the
  self-capture (`await RenderingServer.frame_post_draw`, then
  `get_viewport().get_texture().get_image().save_png`) worked windowed.
