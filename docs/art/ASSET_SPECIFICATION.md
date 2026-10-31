# Asset Specification (this project: Godot 4.6, mobile landscape)

Engine-facing summary of art bible §8 plus the decisions made since. The art
bible is the source; this page exists so a programmer or an exporter script
can find the numbers without reading nine sections. Values marked *proposed*
or *to verify* carry those labels from the art bible.

## 1. Render contract

| Item | Value |
|---|---|
| Battlefield canvas | SubViewport 800×360 art-px; 640 play area centred, 80 px margins per side are backdrop only |
| Display | integer scale n = max(1, floor(min(W/640, H/360))), centred, leftover filled Ink #1B1722 |
| Filtering | Nearest on the viewport texture and every art node; MSAA 2D off, HDR 2D off |
| Pixel snap | on the SubViewport only (not project-wide, so the HUD stays unsnapped); verified on 4.6.3 (Story 047): `Viewport.snap_2d_transforms_to_pixel`, `snap_2d_vertices_to_pixel`, set in `src/battle/battle_canvas.gd` |
| HUD | drawn at native 1280×720 on top; text and bars sharp; UI language under review (2026-10-31 style test: sharp panels, chamfers, diamonds — not yet in the art bible) |
| Layers in the viewport | FloorLayer → UnitLayer (back row first, same row by x) → OverlayLayer; no Y-sort, no CanvasLayer |

## 2. Frames and anchors (art-px)

| Asset | Canvas | Notes |
|---|---|---|
| Hero | 40×48 | body ≤ 30 wide, 38–42 tall; weapon stays inside the canvas |
| Monster / elite | 32×48 | body ≤ 30 wide, ≤ 34 / ≤ 40 tall |
| Warden / Heart Keeper | 48×64 | body ≤ 52×40; Primal Shard built in code |
| Slab | 9-slice source 16×16 (margins 3/3/3, front lip 2–3) + up to 6 stamps | real cells 38×27 … 64×46, aspect 1.4 |
| Wall / Thorns | 40×40 / 40×12 | bottom-centre anchor |
| Backdrop | 800×360 per layer, ≤ 3 layers (sky ≤ 800×200, far, near) | near = drifting mist, seamless horizontally |
| Block tiles | 16×16 (falling, bag) and 5×5 (on the ground) | 7 columns: 5 materials, Odd, enemy |
| VFX | 38×27 frames, 3 greys (light / body / ink), tinted in code | centred on larger cells, never scaled |
| Material marks | 16×16 masks, 5 columns | nine-sliced or centred per the JSON |
| Telegraph stripe | 8×8 tileable | shader fallback |
| Icons | 12×12 on the pixel path; 55×55 tiles on the sharp-HUD path (candidate) | one pixel size per icon |
| Portrait | 64×80 | redrawn, not an upscaled sprite |
| UI 9-slice | 16×16, margins 4/4/4/6; slot margin 3; bar 16×6 (12 px at x2) | pixel path only |

Anchor = bottom-centre of the canvas, feet on the last pixel row, identical in
every frame of a unit. Keep ≥ 1 transparent px on every side. Even canvas
sizes so the centre lands on a pixel.

## 3. Palette

- Master ≤ 64 colours: `assets/art/palette/tessera_master.gpl` + `tessera_master_lut.png`; region subsets `tessera_region_<id>.gpl` = shared colours + ≤ 3 own.
- Per sprite: hero ≤ 8, monster ≤ 8, warden ≤ 12. Alpha only 0 or 255 on sprites, units and backdrops; alpha blending allowed only on floor overlays (cast tile 60 %, drag miss 50 %) and HUD glass (90 %).
- Red #E5293B only for the telegraph. No smooth gradients; dither only on mist layers and one transition band (2×2 checker, ≤ 4 px).
- Monster variants are exported as separate sheets by script (colour swap + accessories), never recoloured at runtime.
- Adding a colour is an art-director decision recorded at the top of the `.gpl`.

## 4. Naming and folders

Pattern `[group]_[data id]_[variant]_[size]`, snake_case, English groups, data ids as in the game data (`kiem_si`, `goblin_scout`).

| Group | Folder | Example |
|---|---|---|
| units | `assets/art/units/` | `unit_kiem_si_sheet.png` + `.json`; `unit_goblin_scout_alt_sheet.png` |
| wardens | `assets/art/wardens/` | `warden_forest_sheet.png` |
| environment | `assets/art/env/<region>/` | `env_slab_forest_9slice.png`, `env_slab_forest_stamps.png`, `env_wall_forest.png`, `bg_forest_far.png` |
| blocks | `assets/art/blocks/` | `block_tiles_16.png`, `block_tiles_5.png` |
| vfx | `assets/art/vfx/` | `vfx_slash_sheet.png`, `vfx_push_sheet.png`, `fx_material_marks_16.png`, `fx_telegraph_stripe_8.png` |
| ui | `assets/art/ui/` | `ui_frame_panel_9slice.png`, `ui_icons_12.png` + `.json` |
| portraits | `assets/art/portraits/` | `portrait_phap_su.png` |
| palette | `assets/art/palette/` | `tessera_master.gpl` |

Regions: `forest, dungeon, ice_tower, swamp, sands, hellfire, sky_isles, lattice_heart`.

Not imported by the engine: `design/assets/candidates/` (has `.gdignore`),
`art_src/` (sources, `.gdignore`), `design/art/reference/`.

## 5. Sources and export

- Hand-drawn source: one `.aseprite` per unit, tag = clip with frame durations. Accepted substitute until an artist works in Aseprite: `art_src/units/<id>/<clip>/<n>.png` + `clips.json` (order, ms, loop) — Story 045.
- Export: sheet PNG (one row per clip, fixed cells, 1 px transparent gutter) + Aseprite-format JSON (`frames`, `meta.frameTags`), so `aseprite -b --sheet --data` output and the Python exporter are interchangeable. Aseprite CLI *not verified here*.
- Battle atlases are generated by script: one shared atlas (heroes, VFX, overlays, icons, UI frames, block materials) and one per region (monsters, warden, slabs, props). Edit a source, rerun the script.
- Every PNG: RGBA 8-bit, lossless.

## 6. Godot import settings (every art PNG)

| Setting | Value | Why |
|---|---|---|
| Compress mode | Lossless | VRAM compression breaks pixel clusters |
| Mipmaps | off | blurs at non-native scales |
| Fix alpha border | on | no dark fringe on transparent edges |
| Premultiplied alpha | off | |
| Filter | Nearest, set on the node (`texture_filter`) and the SubViewport default | |
| Texture ceiling | ≤ 2048², target 1024² atlases (*to verify* on low-end devices) | |

Animation playback: a Node2D drawing `draw_texture_rect_region` from the JSON
frame table, not AnimatedSprite2D. Shaders: at most `unit_fx` and `floor_fx`;
VFX tinted with `modulate`.

## 7. Budgets (proposed, from art bible §8.7)

Art total ≈ 36 MB RGBA across all regions; one battle loads one region
(≈ 5 MB). Draw calls for the art tier ≈ 20–30 of a 150 budget. Particles ≤
128 squares at once.
