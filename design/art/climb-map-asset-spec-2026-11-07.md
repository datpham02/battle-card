# Tower Ascent (climb map) — asset spec, Phase 2

Date: 2026-11-07 · Target: the user's approved concept (`design/assets/candidates/climb-map/ref-concept-climb.png`,
not committed: user reference) · Brief: the user's "TESSERA — FINAL TOWER ASCENT MAP REDESIGN".

## Phase 1 findings (what stays, what goes)

| Part | Today | Keep / replace |
|---|---|---|
| Progression | `world.region_order` (7 regions, 1 offered per floor), 7 columns per floor, `floor_scaling` 1..7 + `final`; the Lattice Heart is the **final match after floor 7** (`world.final_match`, its own map with the `final_prelude` shop column), not an 8th floor | keep (no logic change) |
| Selection flow | `WorldMapView`: tap island = select, tap again or the gold button = `choose_region`; only the current floor is enterable | keep |
| Layout math | `ClimbMap` (map 2.4 screens tall, zig-zag, scroll to the current floor) | keep, add per-island anchors |
| Islands | code-drawn polygons | **replace** with PixelLab sprites |
| Stairs | 4 px stepped lines | **replace** with code-placed stone step sprites |
| Sky | 24-band gradient | **replace** with gradient + parallax far layer + cloud sprites |
| Cube | crop of `menu_bg.png` | keep for the prototype; a summit sprite in Phase 5 |
| Info panel | the old WORLD_MAP region card | restyle (icons + rows, compact) |

## Frame and scale

- Art canvas 640×360, drawn at the whole-number UI scale (2× at 1280×720), nearest filtering.
- Camera: slightly elevated 3/4 side view, light from the upper left (same as the arena).
- Hero: the real sheet (`unit_<id>_sheet`, frames 96×70, the body ≈ 44 px tall) at 1× art scale = ~¼ of the island's
  height, like the concept.
- Island sprite: **320×192 art px** (transparent), the walk surface's centre at (160, 78) = hero feet anchor.
- Per island anchors (art px, in `assets/art/ui/climb/islands.json`): `feet`, `stair_in` (where the stair from below
  lands), `stair_out` (where the stair up leaves), `marker` (done tick). Measured on the generated sprite.
- Stair step: **32×32 art px** sprite (3–4 variants), stepped by code from `stair_out` of island N to `stair_in` of
  island N+1, each step 1 step-height up; states by modulate (done: warm gold accent, next: brighter, locked: grey-violet).

## Render layers (back to front)

1. Sky gradient (code, indigo → dusty violet).
2. Far layer (sprite 792×336, parallax 0.3, mirrored copies stacked vertically to hide seams).
3. Cloud banks (sprites, parallax 0.6, slow drift).
4. Stairs (step sprites).
5. Islands (state tint: locked = desaturated and darker, never black).
6. Hero, done ticks, selection accent (thin gold outline from the sprite alpha, pulsing).
7. Labels, info panel, HUD.

## Storage

`assets/art/ui/climb/`: `island_<region>.png`, `stair_step_<n>.png`, `sky_far.png`, `cloud_<n>.png`, `islands.json`
(anchors). Candidates under `design/assets/candidates/climb-map/`.

## Phase 3 generation request (prototype) — needs approval

All `create_image_pro` (PixelLab v2 `POST /generate-image-v2`), palette "Tessera Misty Forest" (the 15 colours of the
forest backdrops) unless noted. Costs from the tool's price ladder; the receipt prints the exact charge.

| # | Asset | Size | no_background | Candidates | Cost |
|---|---|---|---|---|---|
| G1 | Misty Forest island | 320×192 | true | 1 | 10–15 |
| G2 | Stone stair step | 32×32 | true | 64 | 10 |
| G3 | Far sky layer | 792×336 | false | 1 | 25 |
| G4 | Cloud bank | 128×48 | true | 4 | 10 |
| | **Total** | | | | **55–60** |

References: G1 = `ref-forest-island.png` (the concept's forest island, cropped); G3 = `ref-concept-climb.png`.

**G1 prompt:** "A floating island fragment of ancient overgrown forest ruins above the clouds, slightly elevated
three-quarter side view, transparent background. A wide flat walkable top of worn grey-green flagstones with moss and
small white flowers; a large twisted old tree on the left whose roots wrap the island's edge; a giant weathered stone
face half sunk beside the tree; broken stone arches and short pillars on the right; restrained hanging vines. A layered
rocky underside of stacked mossy stone blocks tapering downward, two thin waterfalls pouring off the front edge.
Muted desaturated grey-green stone, restrained moss green, soft light from the upper left, melancholic dark fantasy,
crisp pixel art, clean pixel clusters, 1 px dark outline." Reference usage: "island design target: the island's
silhouette, the tree, the stone face, the arches, the waterfalls and the layered underside; the island alone".

**G2 prompt:** "A single worn ancient stone stair step block, weathered grey-violet masonry with a chipped front edge
and a darker underside, slightly elevated three-quarter side view, top face lit from the upper left, crisp pixel art,
1 px dark outline, transparent background." (pick 3–4 matching variants of the 64)

**G3 prompt:** "Distant sky backdrop for a vertical fantasy world map: deep indigo and dusty violet sky filled with
soft layered cloud banks, faint low-contrast silhouettes of small far-away floating ruined islands and broken arches,
a dim warm glow low on the left, very low contrast, calm and mysterious, crisp pixel art clouds." Reference usage:
"sky colours, clouds and the faint distant ruins only".

**G4 prompt:** "A soft drifting cloud bank of dusty violet and pale indigo, flat bottom, rounded pixel clusters, low
contrast, crisp pixel art, transparent background."

## Phase 5 (after the prototype is approved)

6 more islands at G1's size and settings (10–15 each, 60–90), a Lattice Heart summit (≈15), so ≈ 75–105 more.
