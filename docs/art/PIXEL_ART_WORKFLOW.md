# Pixel Art Production Workflow

General workflow for producing pixel art for a game with a small team and an
AI-assisted pipeline. Engine-independent; the numbers for this project are in
`ASSET_SPECIFICATION.md`, the identity in `design/art/art-bible.md`.

Written 2026-10-31 after a day in which four generations were wasted on
backdrops that did not match the game's view. Step 1 exists because of that.

## 1. Before anything is drawn or generated: reference and constraints

1. **Open the project's own references first**: the art bible sections that
   govern the asset, the latest in-game screenshot, the concept images
   (reference for composition and mood only — never traced, never used as
   img2img input), the already-approved neighbours the asset will sit next to.
2. **Write the view down** in one sentence. For this game: *slabs seen
   slightly from above on a dark ground, far scenery band on top; units stand
   upright and overlap the row behind.* An asset drawn for another view
   (side-scroller, isometric, pure top-down) cannot be fixed afterwards.
3. **Write the layout constraints** the asset must obey: what will cover it
   (board, HUD, controls), the visible strip left for it, the pixel size it is
   displayed at, which palette subset it may use.
4. **Name the closest famous thing it could be mistaken for** (a character
   that looks like Cloud, a HUD that looks like a Terraria screen) and say in
   the prompt or the sketch how it differs.
5. **Decide the method per asset**: script (exact pixels — tiles, 9-slices,
   icons on a grid, VFX made of squares), hand edit in the workbench, or AI
   generation (organic shapes — creatures, foliage, scenery). Script and hand
   work are free and exact but have no taste; generation has taste but needs
   the checks below.

Only then spend a generation, and **spend one first**: composite it in the
game, look, then decide whether a second is worth it.

## 2. Design fundamentals the pipeline must apply (the "art" part)

These are what separated a wireframe from a designed asset in this project.
Sources: *Pixel Logic* (Michafrar), Sam Keddy's outline articles, Slynyrd's
tile and lighting tutorials — all from the awesome-pixel-art list.

- **Value before colour.** A three-value thumbnail (dark / mid / light) of the
  whole frame decides whether the board, units and backdrop separate. Squint
  or blackout the screenshot; if the silhouette test fails, no shading fixes it.
- **One light direction** per scene (this project: top-left). Every bevel,
  slab lip and UI edge agrees with it.
- **Banded shading, 2–3 steps, with a hue shift** (shadows cooler, lights
  warmer or the reverse per region), never a smooth gradient and never
  "pillow shading" (lighter in the middle, darker all round).
- **Outlines are a decision, not a default**: units and blocks get a closed
  1 px dark outline; environment and UI get selective outlines or none, so
  the eye finds the units first.
- **Clusters, not noise**: every colour forms readable clusters; no orphan
  pixels, no 1 px checker except where the art bible allows dither.
- **Readability at 1x**: identity in the upper half of a sprite; three units
  in a column must stay countable; a status icon must be recognisable in
  blackout.
- **Composition is a frame, not an asset**: a detailed strip over a flat fill
  reads as two pictures. Design the backdrop as one image in the game's view
  with a quiet zone where the board and controls go.
- **UI off the pixel grid when the HUD is sharp**: 1 px lines and real fonts
  at native resolution; pixel art only for glyphs and world objects. Decide
  this per project and write it in the art bible.

## 3. Production steps per asset

| Step | Output | Who / tool |
|---|---|---|
| Brief | spec entry: dimensions, palette, anchors, art-bible sections, prompt or script plan | asset-spec skill / art-director |
| Reference & constraints | the step-1 notes in the spec's production log | the person spending the gen |
| Draft | candidate PNG(s) under `design/assets/candidates/<group>/` | script, workbench edit, or generator |
| Fix | palette lock, edge fixes, outline closure, 1 px shifts | workbench (`map_colors`, `patch_pixels`, `reduce_colors`) or the script |
| In-game check | screenshot with the asset next to its real neighbours at the real scale | `prototypes/art-check` (or the game) |
| QA | `ART_QA_CHECKLIST.md` filled in | reviewer; automated lines by `pixelart_workbench lint/score` |
| Log | production log row: date, method, generations, result, open points | spec file |
| Export | final file at the final path + JSON, import settings | exporter script, then engine import |
| Status | manifest row updated | manifest |

A candidate becomes **Done** only after the art-director (or the user in solo
mode) signs the open points off and the file sits at its final path.

## 4. Animation

- Frame counts and holds come from the spec; one canvas size per unit so the
  bottom-centre anchor never moves between frames.
- Draw key poses first (idle A/B, hit, cast A/B), then in-betweens only where
  the spec asks; this project's animation budget is the biggest risk (art
  bible §1.5).
- Check every clip as a loop in the engine at 1x, not frame by frame: foot
  drift, outline jitter, canvas-edge touches, hold times.
- Hit flash, freeze, burn and similar states are overlays or shader palette
  swaps, never extra frames.

## 5. Sheets, naming and export

- One sheet per unit, one row per clip, fixed cells, 1 px transparent gutter,
  plus an Aseprite-format JSON (frame rects, durations, tags) so the engine
  reads hand-drawn and generated sources the same way.
- Names come from the data id, not from the display name; group prefix,
  then id, then variant, then size. Exact rules in `ASSET_SPECIFICATION.md`.
- Sources that are not final (candidates, explorations, raw generator output)
  live outside the engine's import path, each with the script that made them.

## 6. Tools (verified state on 2026-10-31)

| Tool | Role here | Verified? |
|---|---|---|
| PixelLab MCP (`create_image_pixen`, `create_image_pro_flash`, `create_character_pro_flash`, `animate_image_pixminimax`, `reduce_colors`) | generation of organic assets and clips; palette-locked where the tool allows | yes, used for every generated candidate |
| PixelLab `pixelart_workbench` | free lint / score / inspect / exact edits / sheet split-join | yes |
| Pure-Python PNG scripts (`crop_frame.py`, `draw_*.py`, `make_gif.py`) | exact tiles, 9-slices, icons, VFX frames, compositing, GIF evidence; no Pillow needed | yes |
| Godot 4.6 (`prototypes/art-check`) | in-engine look check, self-capture, sequences | yes |
| Aseprite (`aseprite -b` CLI export) | would replace the Python exporter for hand-drawn sources; tag = clip | **not installed, not verified** |
| LibreSprite | free fork of an old Aseprite with a similar CLI | not installed, not verified |
| GIMP, PixelCraft, Pixelrepo, rx, Draw! | editors without a scriptable path that fits this pipeline | evaluated, not adopted |
| Lospec palette list, Palette Extractor | palette reference; extraction is already done by the workbench | reference only |

Claude cannot operate a GUI editor; anything that must be repeatable goes
through a script or an MCP tool.

## 7. What was taken from awesome-pixel-art, and what was not

**Taken**: *Pixel Logic* and the Sam Keddy outline articles (section 2),
Slynyrd's tutorials for tiles and lighting, Lospec as the palette reference,
Aseprite as the only listed editor with a CLI worth integrating once an
artist joins. **Not taken**: browser editors, pixeldudesmaker (generic
characters conflict with the no-lookalike rule), Broider (CSS), the
inspiration game list beyond what the art bible already cites (Fez).
