# Asset Specs — Character: Goblin Scout

> **Source**: design/assets/entity-inventory.md (Goblin Scout), assets/data/chapters.json (ch1 Misty Forest)
> **Art Bible**: design/art/art-bible.md (§3, §4, §5.2, §5.4, §5.6, §8)
> **Generated**: 2026-10-29
> **Status**: 1 asset specced / 0 approved / 0 in production / 0 done
> **Mode**: solo — art-director and technical-artist skipped; technical constraints not validated.

## ASSET-003 — Goblin small body sprite sheet (base: Goblin Scout)

| Field | Value |
|-------|-------|
| Category | Sprite / 2D art |
| Dimensions | Frame 32x48 art-px, anchor bottom-centre; height <= 34 px (normal monster), body width <= 30 px. Sheet: 5 rows (one clip per row) x up to 2 columns, 1 px transparent gutter, total 65x244 |
| Format | Source `art_src/units/unit_goblin_scout.aseprite` (one tag per clip). Export `.png` RGBA 8-bit + Aseprite `.json` |
| Naming | `assets/art/units/unit_goblin_scout_sheet.png` + `.json`. Variants on the same body (Art Bible §5.6, baked by script per §8.4): `unit_goblin_archer_sheet.png`, `unit_goblin_shaman_sheet.png` |
| Texture import | Lossless, mipmaps off, fix_alpha_border on, Nearest, alpha only 0 or 255 |
| Palette | <= 8 colours (table below) |
| Slice | 1 |

**Clips (8 drawn frames, Art Bible §5.4 / §8.6):**

| Clip | Frames | Hold | Description |
|---|---|---|---|
| idle | 2 | 0.4 s/frame, loop | Ears twitch 1 px, knees bent, weight forward |
| step | 2 | matches the step cooldown | Quick scuttle, body low |
| windup | 1 | held until the telegraph ends | Wind-up pose (Art Bible §3): hunched, one hand pulled back as if about to throw, the other hand forward; holds NO block, never both arms up. 3–5 ivory square particles at the back hand are code-drawn |
| hit | 1 | 0.12 s | Leans back 2 px; white flash by shader |
| down | 2 | 0.15 s then hold last | Collapses forward |

**Visual Description:**
Small goblin about 30 px tall facing left, low centre of gravity, long ears sticking out sideways (the species mark, in the upper half). Desaturated olive-green skin, a ragged hooded leather jerkin, a short knife at the belt. Eyes 2x2 pale pixels in a dark face. No block accent colour (enemies never carry a hero material colour). The scout's own accessory is a small pointed hood flap over one ear; the archer swaps it for a quiver strap, the shaman for a bone charm (palette swap 2–3 colours + one accessory <= 8x8 px, Art Bible §5.6).

**Palette:**

| Role | Hex | Source |
|---|---|---|
| Outline 1 px | #1B1722 (Ink) | Art Bible §4 |
| Skin mid | #7D8B5A | proposal (desaturated olive, S ~35 %, far from the hit-green #58D468) |
| Skin dark | #59643F | proposal |
| Leather | #6B5640 | proposal |
| Leather dark | #4A3C2E | proposal |
| Eyes / teeth / blade | #EFE6D2 (Ivory) | Art Bible §4 |
| Hood cloth | #5E6B55 (Misty Forest moss grey) | Art Bible §4 region colour |

Saturation 30–45 % (Art Bible §5.2). Forbidden: red, Lattice gold, Odd magenta, bright green, any hero block colour.

**Art Bible Anchors:**
- §3: enemies face left; identifying feature in the upper half; wind-up casting pose, no block.
- §4: region colour subset, no hero accent, signal colours forbidden.
- §5.2, §5.4, §5.6: enemy archetype, 8-frame minimal set, shared body + variants.
- §8.3, §8.4, §8.6: frame/anchor, variants baked by script, clips and holds.

**Generation Prompt** (PixelLab; AI for concept and pose only, then downscale, quantise, hand-fix):
```
Pixel art enemy sprite, small goblin scout facing left, 32x48 canvas, about 30 pixels tall, crouched low, long pointed ears sticking out sideways, desaturated olive green skin (#7D8B5A, shadow #59643F), ragged brown leather jerkin (#6B5640) with a small moss-grey hood flap over one ear, short knife at the belt, pale tiny eyes. 1-pixel dark outline #1B1722. Crisp square pixels, flat shading max 3 tones, no anti-aliasing, no dithering, no glow, transparent background. All identifying features in the upper half of the body.
Negative: red, gold, bright green, magenta, text, holding a block, arms raised, realistic proportions, soft edges, background.
```
Wind-up prompt: "same goblin, hunched, right arm pulled back as if about to throw, left arm forward, empty hands, facing left".
Not verified: PixelLab canvas sizes (generate 48x48 and crop to 32x48 if needed).

**Status:** Needed
