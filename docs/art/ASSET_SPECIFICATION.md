# Asset Specification (this project: Godot 4.6, mobile landscape)

Engine-facing summary of art bible §8 plus the decisions made since. The art
bible is the source; this page exists so a programmer or an exporter script
can find the numbers without reading nine sections. Values marked *proposed*
or *to verify* carry those labels from the art bible.

> **Synced 2026-11-11 (P0 of the AI art workflow):** §2–§6 now state what is on
> disk, verified against `assets/art/units/*_sheet.json`, the `.import` files and
> `art_src/`. Per-asset facts (frame, clips, PixelLab ids, status, approval) live
> in `design/assets/asset-registry.yaml`; `design/assets/asset-manifest.md` is
> generated from it. Values the art bible still carries as the *target* are
> marked *(bible target)*.

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
| Hero | **96×70** (phap_su, sat_thu), **96×72** (tho_san, giao_si), **96×92** (kiem_si, `body_h` 70; sources 96×70 bottom-aligned by the exporter since 2026-11-08) | body ≈ 31 wide, ≈ 66 tall; feet on the last row at x = 48; weapon stays inside the canvas. *(bible §8.3 target: 96×70; 40×48 and 32×48 were the pre-2026-10-31 sizes)* |
| Monster | **64×52** (goblin_scout, goblin_archer, rootling, greycap_sporeling, mossbound_sentry); **68×52** dire_wolf (tail) | body ≈ 46 tall, feet x = 32 (34 for the wolf) |
| Elite | **80×80** (ancient_root_sentinel, mistbriar_matron, wolf_alpha) | taller than normals by tier; feet x = 40 |
| Boss / Warden | **160×130** (forest_witch, goblin_warlock; 2×2 block) | feet x = 80; Primal Shard built in code. *(bible target was 48×64 — superseded 2026-11-02 by the wide boss anchor)* |
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

- Master ≤ 64 colours: **`art_src/palette/tessera_master.gpl`** (47 colours on 2026-11-11, grown from 16; `.gdignore`d with the sources, read by `export_sheets.py`, `tools/fx-pipeline` and `tests/unit/art/sheet_export_test.gd`). *(bible target: `assets/art/palette/` + `tessera_master_lut.png` + region subsets — none of those exist yet.)*
- Per sprite: hero ≤ 8, monster ≤ 8, warden ≤ 12. Alpha only 0 or 255 on sprites, units and backdrops; alpha blending allowed only on floor overlays (cast tile 60 %, drag miss 50 %) and HUD glass (90 %).
- Red #E5293B only for the telegraph. No smooth gradients; dither only on mist layers and one transition band (2×2 checker, ≤ 4 px).
- Monster variants are exported as separate sheets by script (colour swap + accessories), never recoloured at runtime.
- Adding a colour is an art-director decision recorded at the top of the `.gpl`.

## 4. Naming and folders

Pattern `[group]_[data id]_[variant]_[size]`, snake_case, English groups, data ids as in the game data (`kiem_si`, `goblin_scout`).

| Group | Folder | Example |
|---|---|---|
| units (heroes, monsters, elites, bosses — one folder) | `assets/art/units/` | `unit_kiem_si_sheet.png` + `.json`, `unit_forest_witch_sheet.png` (bosses live here too; no `wardens/`) |
| environment | `assets/art/env/<region>/` + `region.json` | `env_slab_forest_9slice.png`, `env_slab_forest_stamps.png` + `.json`, `env_slab_forest_flagstones.png`, `env_support_forest_{wall,pillar,arch,roots,ferns}.png`, `env_platform_forest_face.png`, `env_thorn_forest_tile16_v2.png`, `bg_forest_far_v4.png`, `bg_forest_far_{edge,sanctum}.png`; only `forest/` exists; `assets/art/regions.json` maps chapters to regions |
| vfx (packs) | `assets/art/vfx/{cast,floor,status}/<pack>/` + `index.json` per kind | `manifest.json` + `whole.png` (+ `behind.png` / `front.png`) per pack, `VfxPack` format; `_c43x31` siblings are the 43×31-cell variants; loose: `vfx/fx_telegraph_stripe_8.png`, `vfx/pickup_voxel.json` |
| ui | `assets/art/ui/{cards,climb,map,plates,title}/`, `ui/ui_icons_55.png` + `.json` | `card_frame.png`, `island_<region>.png` + `islands.json`, `icon_*.png`, `plate_<look>_{up,down}.png`, `menu_bg.png` — no group prefix today *(bible target: `[group]_[id]_[variant]_[size]`)* |
| cards | `assets/art/cards/<card_id>.png` | 32×32 per card id, found by convention from `card_face.gd` |
| blocks, portraits, palette | — | **not created**: blocks are code-drawn, portraits are missing (registry backlog), the palette is in `art_src/palette/` |

Regions: `forest, dungeon, ice_tower, swamp, sands, hellfire, sky_isles, lattice_heart`.

Not imported by the engine: `design/assets/candidates/` (has `.gdignore`),
`art_src/` (sources, `.gdignore`), `design/art/reference/`.

## 5. Sources and export

- Hand-drawn source: one `.aseprite` per unit, tag = clip with frame durations. Accepted substitute until an artist works in Aseprite: `art_src/units/<id>/<clip>/<n>.png` + `clips.json` (order, ms, loop) — Story 045.
- Export: sheet PNG (one row per clip, fixed cells, 1 px transparent gutter) + Aseprite-format JSON (`frames`, `meta.frameTags`), so `aseprite -b --sheet --data` output and the Python exporter are interchangeable. Aseprite CLI *not verified here*.
- Battle atlases *(bible target, not implemented)*: today every unit sheet, VFX pack sheet and env tile is its own texture; the largest is `unit_forest_witch_sheet.png` 1287×1309 (under the 2048² ceiling, over the 1024² target).
- Sources that are not final (candidates, explorations, raw generator output) live outside the engine's import path: `design/assets/candidates/` (`.gdignore`), `art_src/` (`.gdignore`), `design/art/reference/` (`.gdignore`). `production/qa/evidence/` has **no** `.gdignore` yet, so Godot imports every evidence screenshot (P4 fix).
- Every PNG: RGBA 8-bit, lossless.

## 6. Godot import settings (every art PNG)

| Setting | Value | Why |
|---|---|---|
| Compress mode | Lossless | VRAM compression breaks pixel clusters |
| Mipmaps | off | blurs at non-native scales |
| Fix alpha border | on | no dark fringe on transparent edges |
| Premultiplied alpha | off | |
| `detect_3d/compress_to` | 0 on the 8 unit sheets `sheet_export_test.gd` pins; the default 1 on the other 162 art imports (2026-11-11) | harmless in 2D; made consistent in P4 |
| Filter | Nearest, set on the node (`texture_filter`) and the SubViewport default | |
| Texture ceiling | ≤ 2048², target 1024² atlases (*to verify* on low-end devices) | |

Animation playback: a Node2D drawing `draw_texture_rect_region` from the JSON
frame table, not AnimatedSprite2D. Shaders: at most `unit_fx` and `floor_fx`;
VFX tinted with `modulate`.

## 7. Budgets (proposed, from art bible §8.7)

Art total ≈ 36 MB RGBA across all regions; one battle loads one region
(≈ 5 MB). Draw calls for the art tier ≈ 20–30 of a 150 budget. Particles ≤
128 squares at once.
