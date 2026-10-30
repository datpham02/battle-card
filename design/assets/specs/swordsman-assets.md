# Asset Specs — Character: Swordsman (Kiếm sĩ)

> **Source**: design/assets/entity-inventory.md (Swordsman), design/world-context.md §6
> **Art Bible**: design/art/art-bible.md (§1–§5, §8)
> **Generated**: 2026-10-29
> **Status**: 2 assets specced / 0 approved / 0 in production / 0 done
> **Mode**: solo — art-director and technical-artist skipped; technical constraints not validated.

## ASSET-001 — Swordsman sprite sheet

| Field | Value |
|-------|-------|
| Category | Sprite / 2D art |
| Dimensions | Frame 32x48 art-px, anchor bottom-centre; hero ~40 px tall, body width <= 30 px. Sheet: 8 rows (one clip per row) x up to 2 columns, 1 px transparent gutter, total 65x391 |
| Format | Source `art_src/units/unit_kiem_si.aseprite` (one tag per clip). Export `.png` RGBA 8-bit + Aseprite `.json` (array, tags) |
| Naming | `assets/art/units/unit_kiem_si_sheet.png`, `unit_kiem_si_sheet.json` |
| Texture import | Lossless, mipmaps off, fix_alpha_border on, Nearest filter on the node, alpha only 0 or 255 |
| Palette | <= 8 colours from the master 64-colour palette (table below) |
| Slice | 1 |

**Clips (14 drawn frames):**

| Clip | Frames | Hold | Description |
|---|---|---|---|
| idle | 2 | 0.4 s/frame, loop | Chest up 1 px; cloak tail offset 1 px; feet apart |
| step | 2 | matches the step cooldown (0.18-0.6 s, not measured) | Feet swap, cloak trails behind |
| cast_gesture | 2 | 0.08 s then 0.12 s | A: sword drawn at shoulder height, point backward. B: horizontal cut reaching x=30. Afterwards the sword jumps back to the back (no extra frame) |
| hit | 1 | 0.12 s | Leans back 2 px; white flash by shader, not drawn |
| victory | 2 | 0.4 s, loop | Sword or fist at shoulder height |
| defeat | 2 | 0.15 s then hold last | Kneels, slumps |
| fall | 1 | - | Arms up (falling off an island) |
| awaken | 2 | 0.12 s | Both hands on the sword at chest height, guard then cut; cloak flying |

**Visual Description:**
Chibi knight about 2.8 heads tall, standing upright facing right, square shoulders, steel-blue plate armour. A large greatsword is strapped diagonally across the back with the hilt sticking up at least 4 px above the head: this is the identifying feature and it sits in the upper half of the body. Pale blond hair in three tufts; eyes are two 2x2 ink pixels with no whites; cloak in dark Mist grey. All identifying features stay in the top 20 px because the lower half is often hidden by the row in front.

**Palette:**

| Role | Hex | Source |
|---|---|---|
| Outline 1 px | #1B1722 (Ink) | Art Bible §4 |
| Armour mid | #8FA3B8 | Art Bible §4 |
| Armour light | #EEF4FA | Art Bible §4 |
| Trim | #EFE6D2 (Ivory) | Art Bible §4 |
| Armour dark | #5F6F82 | proposal, to add to the shared palette |
| Cloak (dark Mist) | #4F5864 | proposal, to add to the shared palette |
| Hair, pale blond | #E8D9A8 | proposal, to add to the shared palette |
| Skin | #E3B99A | proposal, to add to the shared palette |

Accent colour <= 15 % of the pixels. Avoid: Burn orange, Frozen cyan, Chill blue #3A5CF0, Lattice gold, Odd magenta, red.

**Art Bible Anchors:**
- §1 P2: silhouette first, detail second; 1 px outline; <= 3 shading steps per material.
- §3: identifying features in the upper half; heroes face right; Swordsman = rectangular build.
- §4: palette and forbidden colours.
- §5.1, §5.4: Swordsman table, animation frame counts.
- §8.3, §8.6: frame, anchor, padding; clips and hold times.

**Generation Prompt** (PixelLab; AI is only for concept, pose and colour choice, then downscale, quantise to the palette, hand-fix):
```
Pixel art character sprite, tiny chibi knight facing right, standing upright, 32x48 canvas, about 40 pixels tall, big head about 14 px, squared shoulders. Steel plate armor in three flat tones (mid #8FA3B8, light #EEF4FA, dark #5F6F82) with ivory trim, a large greatsword strapped diagonally across the back with the hilt sticking up above the head, pale blond spiky hair in three tufts, dark grey-blue short cloak, eyes are two 2x2 dark pixels with no whites. 1-pixel dark outline #1B1722. Crisp square pixels, no anti-aliasing, no dithering, no gradients, no glow, flat shading, transparent background. All identifying features in the upper half of the body.
Negative: red, orange, gold glow, bright blue cape, text, realistic proportions, painterly shading, soft edges, background scenery, weapon held in front.
```
Animation prompt for `cast_gesture`: "draws sword to shoulder height, then swings it horizontally toward the right, then returns to idle".
Not verified: PixelLab canvas sizes. If only square canvases are allowed, generate 48x48 and crop to 32x48 keeping the feet on the same pixel row.

**Status:** Needed

## ASSET-002 — Swordsman portrait

| Field | Value |
|-------|-------|
| Category | Sprite / 2D art |
| Dimensions | 64x80 art-px (chest up); shown x2 at 720p (128x160) |
| Format | `.png` RGBA 8-bit, alpha 0/255, Lossless, Nearest |
| Naming | `assets/art/portraits/portrait_kiem_si.png` |
| Slice | - |

**Visual Description:** Chest-up Swordsman with the same palette and the same 1 px ink outline as the sprite. Redrawn by hand, not an upscaled sprite. One calm expression, eyes 3x3 px with a 1 px highlight, three-tuft hair with shading, the greatsword hilt peeking over the shoulder. Flat single-colour background.

**Art Bible Anchors:** §5.5 (portrait 64x80, same pixel size as the field, eyes 3x3 + 1 px highlight), §8.3 (portraits are redrawn), §4 (palette).

**Generation Prompt:**
```
Pixel art character portrait, bust of a young chibi knight, chest up, facing slightly right, 64x80 canvas. Steel plate armor in flat tones (#8FA3B8, #EEF4FA, #5F6F82) with ivory trim, pale blond spiky hair in three tufts, calm determined expression, eyes 3x3 pixels with a 1-pixel highlight, the hilt of a greatsword visible over the right shoulder. 1-pixel dark outline #1B1722. Crisp square pixels, same limited palette, no anti-aliasing, no dithering, no gradients, flat single-color background.
Negative: red, gold glow, text, painterly shading, soft edges, realistic face, busy background.
```

**Status:** Needed
