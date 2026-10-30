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
Verified 2026-10-31: 32x48 is a native Pro Flash preset (`get_pro_flash_capabilities`), so no square-then-crop step is needed for the single image. The 8-direction rotation pads to a 48x48 square; crop back to 32x48 keeping the feet on the same pixel row.

**Generation log (PixelLab):**

| # | Date | Tool | Params | Cost | Result | Verdict |
|---|---|---|---|---|---|---|
| cand-01 | 2026-10-31 | `create_image_pro_flash` | 32x48, seed 0, palette locked to the 8 hex above, max_colors 8, no_background; prompt = the one above plus "seen from the side, facing right, feet apart, feet on the bottom edge, light from top-left" | 5 gen | job `a767e4a3-ed2c-45dd-b891-a5e9bf061c76`, gallery `a6363d0f-98c8-57f6-8d88-3a402661837c`, file `design/assets/candidates/swordsman/ASSET-001-cand-01-proflash-seed0.png` | Palette 7/8 (all in spec, #EEF4FA unused), sword on back, 3 hair tufts, 2x2 eyes, ~38 px tall, ~25 px wide, transparent bg. FAIL §5.1 facing: drawn front/3-4 toward the viewer, not right; hilt not >= 4 px above the head. Kept as identity anchor. |
| rot-01 | 2026-10-31 | `create_character_pro_flash` | source_image_id = cand-01, palette locked, view low top-down, 8 directions | 1 gen | character `7b1bbf5f-5cbd-42dc-8982-1f0e039fc83c` (48x48 canvas); saved `east`, `south-east`, `south` under `design/assets/candidates/swordsman/ASSET-001-rot-01-*-48.png` | All 7 colours in spec, alpha 0/255. **south-east chosen** as the facing-right base (3/4 per §5.1): face, 2x2 eye, 3 tufts, cloak, sword behind. `east` rejected: blade covers the body, hair hides the eye. Hilt still level with the hair. |
| fix-01 | 2026-10-31 | `pixelart_workbench edit` (free) | on south-east: pommel moved up 5 px (copy_region), grip extended, 3 ink pixels close the right outline; lint 0 errors / 0 warnings | 0 | workbench image `fdea9dce-67f3-4b6e-a2e4-1277627721d8`, file `ASSET-001-rot-01-south-east-48-hiltfix.png` | Hilt top 4 px above the hair mass (y=2 vs y=6). |
| crop-01 | 2026-10-31 | local `crop_frame.py` (scratchpad, pure Python) | 48x48 to 32x48, dx -8, dy +1 (feet on row 47) | 0 | **`design/assets/candidates/swordsman/ASSET-001-idle-A-32x48.png`** | bbox x 5-26 (22 wide), y 3-47 (45 tall incl. hilt and tufts; hair mass to feet = 42), 7 colours, alpha 0/255, no opaque pixel lost. Candidate for clip `idle` frame A. |
| check-01 | 2026-10-31 | `prototypes/art-check` (free) | 5x5 + 5x5 board, 38x27 art-px slabs (Stone #4A4640, lip #2C2925), 640x360 shown at 2x, Nearest, feet 3 px above the lip, y-sorted | 0 | `production/qa/evidence/asset-slice1-art-check/01-pair-5x5.png`, `02-blackout.png` | §8.9 #1 PASS for the pair: the Ink silhouette keeps the spiky hair and the sword hilt and cannot be mistaken for the goblin. #9 PASS (retained). Head and hilt reach one row up into the row behind, as §1 intends. Upper-half identity reads at 1x. Still open: #1 with all 5 heroes. |
| anim-01 | 2026-10-31 | `animate_image_pixminimax` | first frame = idle-A (base64), 4 frames, seed 1, view low top-down, direction south-east, motion "chest rises 1 px, cloak tail sways 1 px, feet planted" | 1 gen | job `5475b18e-c797-40fb-a582-aed7a0bf3aa9`, gallery `3470b808-8c8d-5189-bf16-9753d5c50ba6`; raw frames `design/assets/candidates/swordsman/idle-clip-raw/f1-f5.png`; **idle B = f5** saved as `ASSET-001-idle-B-32x48.png` | All 5 frames: feet row 47 and feet x 11-22 unchanged, 7 colours unchanged, alpha 0/255, lint 0 errors, score 96. f2-f3 move the head 1 px; f4-f5 lift the body 1 px (bbox top y3 -> y2), matching the spec's "chest up 1 px". Clip `idle` = A (idle-A) / B (f5), 0.4 s each. §8.9 #7 PASS on the measurements; eye check pending in the art-check scene. |

**Status:** In Progress

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
