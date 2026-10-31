# Asset Specs — Level: Misty Forest (Rừng Sương)

> **Source**: design/assets/entity-inventory.md (Misty Forest set, Wall, Thorns patch), design/world-context.md §5
> **Art Bible**: design/art/art-bible.md (§2, §3, §4, §6, §8)
> **Generated**: 2026-10-29
> **Status**: 4 assets specced / 0 approved / 0 in production / 0 done
> **Mode**: solo — art-director and technical-artist skipped; technical constraints not validated.

## ASSET-004 — Slab set: Misty Forest

| Field | Value |
|-------|-------|
| Category | Environment (tiles) |
| Dimensions | 9-slice source 16x16 art-px: margins 3 left/right/top, front lip 2–3 px at the bottom; centre is a flat fill so it stretches. Stamps sheet: 6 stamps from 8x6 to 16x8 |
| Format | `.png` RGBA 8-bit, Lossless, Nearest; built at any cell size 38x27…64x46 (multiples of 2) in code; stamps placed by cell seed |
| Naming | `assets/art/env/forest/env_slab_forest_9slice.png`, `env_slab_forest_stamps.png` |
| Slice | 1 |

**Visual Description:** Dark stone slab in at most 3 tones: face, darker front lip (2 steps darker), ink gap 1–2 px. No ink outline on slabs. A 1 px light edge top-left. Stamps: two crack variants (1 px stepped, one step darker), two moss corners (organic, low, <= 25 % of the face), one root edge lifting a corner (cut at a clean 90° where it meets the lattice), one fallen leaf cluster.

**Palette:** Stone #4A4640, lip #2C2925, ink gap #1B1722, light edge one step above stone, moss #5E6B55 and one darker moss step. Face S <= 30 %, V <= 55 %.

**Art Bible Anchors:** §3 environment (slabs no outline, lip, gap), §4 (Stone #4A4640 / lip #2C2925, region moss #5E6B55, no bright greens), §6.1–6.3 (moss in the corners, 90° cut, 9-slice + 6 stamps), §8.3.

**Generation Prompt:**
```
Pixel art game tile, top-front view of a single square dark stone floor slab, 16x16 pixels, flat face in three muted grey-brown tones (#4A4640 face, #2C2925 thick front lip at the bottom 3 px), 1-pixel light edge on the top-left, small moss patch in one corner (#5E6B55), crisp pixels, no outline, no anti-aliasing, no dithering, no gradients, no text.
```
Stamps prompt: "pixel art sprite sheet of 6 small floor decals on transparent background: two thin stepped cracks, two small moss patches, a tree root cut square, a few fallen leaves; muted moss grey palette; 8 to 16 pixels wide; crisp pixels, no outline".

**Decision 2026-10-31 (user):** not generated with AI. The slab is fully determined by the spec and the stamps are 8–16 px decals below the size AI handles, so both were drawn by script (`draw_slabs.py`, session scratchpad, pure Python) at 0 generations. The prompts above stay as reference for later regions if an artist prefers a generated starting point.

**Production log:**

| # | Date | Tool | Result | Verdict |
|---|---|---|---|---|
| draw-01 | 2026-10-31 | script (free) | `design/assets/candidates/misty-forest/ASSET-004-env_slab_forest_9slice.png` 16x16: margins L3 R3 T3 B4 (1 px light edge #5A5650 top-left, face #4A4640, lip 3 px #2C2925, 1 px Ink gap right and bottom; centre flat so it stretches); `ASSET-004-env_slab_forest_stamps.png` 48x16, six 16x8 cells (crack_a 11x7, crack_b 12x7 in #3E3B36; moss_tl 6x5 and moss_br 7x4 in #5E6B55 + #4A5545; root_bl 12x6 in lip + crack tones; leaves 10x6) with `…stamps.json` (rects, anchors, kinds, rules, palette, nine-slice margins) | 7 colours total, all from the spec table; the two "one step" colours are now fixed: light edge #5A5650, crack #3E3B36, moss dark #4A5545. Lint 0 errors / 0 warnings on both sheets. |
| check-01 | 2026-10-31 | `prototypes/art-check --slabs` (free) | `production/qa/evidence/asset-slice1-art-check/22-slabs-forest-5x5-cell48x34.png`, `23-slabs-forest-3x3-cell64x46.png`, `24-slabs-forest-ring.png` | 9-slice stretches cleanly to 48x34, 64x46 and 49x35 (no seams, light edge and lip stay 1 px / 3 px); stamps placed per cell seed (45 % cover, 35 % crack) read at 1x: moss corners and cracks clear, root reads as a dark corner mark, leaves as a cluster. Units sit on the lip as before. Open: the root stamp is the weakest at 1x; the hole / island edge pieces of §6.3 (2–3 px darker rim, 3 px cliff) are not drawn yet. |

**Status:** In Progress (candidate drawn and checked; export to `assets/art/env/forest/` with Story 045's pipeline)

## ASSET-005 — Backdrop: Misty Forest

| Field | Value |
|-------|-------|
| Category | Environment (background) |
| Dimensions | 3 layers, each 800x360 art-px (sky may be <= 800x200); horizon at 9–13 % height (32–47 art-px) |
| Format | `.png` RGBA 8-bit, Lossless, Nearest; mist layer tiles seamlessly horizontally and drifts <= 1 art-px/s (static with Reduced motion) |
| Naming | `assets/art/env/forest/bg_forest_sky.png`, `bg_forest_far.png`, `bg_forest_near.png` |
| Slice | 1 |

**Visual Description:** Side view. Sky: flat Mist grey. Far: rolling tree line and 3–4 ruined arches no taller than 25 px, value <= 45, low contrast. Near (only at the two outer margins and along the horizon strip): broken pillars and roots, low mist hiding their feet. Below the horizon the ground darkens in 2–3 flat steps; directly under the grid it is at least one step darker than the slabs. One square-cut "broken Primal Form" stone at a margin, grey, not gold. No props inside the grid columns (Art Bible §6.5). Note: the concept image 07-forest-01 placed the far scene up to 40 % of the screen; compress it into the horizon strip and the margins.

**Palette:** Sky #7D8896, forest #5E6B55 and two darker moss steps, ground steps from #3A3F36 down to near-ink. S <= 25 %, sky V <= 72 %.

**Art Bible Anchors:** §2 (Misty Forest mood: lost among gentle ruins, low mist), §4 (region temperature cool, dominant #5E6B55, no bright green), §6.4 (recipe and horizon), §6.5 (props only at the horizon strip and margins), §6.6 (legibility: hero upper half must differ by V >= 25 from the background behind the head).

**Generation Prompt:**
```
Pixel art side-view game background, 800x360, misty forest with old stone ruins, flat layered composition: pale grey misty sky (#7D8896) at the top, a low line of dark moss-grey trees and three small broken stone arches near a low horizon about 12 % from the top, low mist bands, ground below darkening in three flat steps toward the bottom, very low contrast and desaturated, nothing bright, no glow, no characters, crisp pixels, no anti-aliasing, no text.
Negative: bright green, sunlight, god rays, vivid colours, tall foreground trees in the middle, perspective grid.
```

**Status:** Needed

## ASSET-006 — Wall (Misty Forest)

| Field | Value |
|-------|-------|
| Category | Environment (prop) |
| Dimensions | Canvas 40x40 art-px, anchor bottom-centre; wall ~30 px tall (lower than a hero), <= 36 px wide |
| Format | `.png` RGBA 8-bit, Lossless, Nearest; drawn in the unit layer, sorted by row |
| Naming | `assets/art/env/forest/env_wall_forest.png` |
| Slice | 1 |

**Visual Description:** A solid rectangular block of stacked stone tiles, closed outline, diagonal hatch on the face, standing on a normal slab. It hides the lower half of a unit behind it. Contrasts with Thorns on all four pairs: tall/low, solid/sparse, rectangular/triangular, closed/open.

**Palette:** Wall #6E7A88 (Art Bible §4 signal) with one light and one dark step, ink outline.

**Art Bible Anchors:** §3 environment (Wall vs Thorns), §4 (Wall #6E7A88), §6.3, §8.3.

**Generation Prompt:**
```
Pixel art game prop, a short solid stone barricade made of stacked square blocks, 40x40 canvas, about 30 pixels tall, blue-grey stone (#6E7A88) with diagonal hatching on the front face, closed 1-pixel dark outline, flat shading, crisp pixels, transparent background, no text.
```

**Status:** Needed

## ASSET-007 — Thorns patch (Misty Forest)

| Field | Value |
|-------|-------|
| Category | Environment (prop) |
| Dimensions | Canvas 40x12 art-px, anchor bottom-centre; spikes <= 6 px tall |
| Format | `.png` RGBA 8-bit, Lossless, Nearest; floor layer |
| Naming | `assets/art/env/forest/env_thorn_forest.png` |
| Slice | 1 |

**Visual Description:** Sparse low triangular spikes on a normal slab, the slab face visible between them; open (no enclosing outline), never confused with a Wall.

**Palette:** Thorns #B89A6A (Art Bible §4) with one dark step, ink tips.

**Art Bible Anchors:** §3 environment (Thorns low, sparse, triangular, open), §4 (Thorns #B89A6A), §6.3.

**Generation Prompt:**
```
Pixel art floor hazard decal, sparse low triangular thorns scattered across a square, 40x12 canvas, spikes at most 6 pixels tall, bone-rust colour (#B89A6A) with darker tips, gaps showing the floor between spikes, no enclosing outline, crisp pixels, transparent background, no text.
```

**Status:** Needed
