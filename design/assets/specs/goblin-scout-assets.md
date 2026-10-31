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
| Leather | #9A7D5E (was #856B50, before that #6B5640) | proposal; lifted twice 2026-10-31: first for slab contrast, then for the §6.6 measurement (V 60 %, S 39 %) |
| Leather dark | #66523F (was #4A3C2E) | proposal; lifted one step 2026-10-31 (V 40 %) |
| Eyes / teeth / blade | #EFE6D2 (Ivory) | Art Bible §4 |
| Hood cloth | #8FA070 (was #5E6B55 Misty Forest moss grey) | pale moss, S 30 % V 63 %; changed 2026-10-31 for the §6.6 measurement so the hood carries the "V >= 60" share a dark-region enemy needs; the region moss stays on the slab stamps |

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
Verified 2026-10-31: 32x48 is a native Pro Flash preset. Pro Flash ignores "facing left" and draws a front view; the facing-left frame comes from the 8-direction rotation (`south-west`, mirror of the hero's `south-east`), as done for the Swordsman.

**Generation log (PixelLab):**

| # | Date | Tool | Params | Cost | Result | Verdict |
|---|---|---|---|---|---|---|
| cand-01 | 2026-10-31 | `create_image_pro_flash` | 32x48, seed 0, palette locked to the 7 hex above, max_colors 7, no_background; style_image = Swordsman `ASSET-001-idle-A-32x48.png` (base64, style_options colour off, outline/detail/shading on); prompt = the one above reworded as front view, ~30 px tall, ears straight out sideways | 5 gen | job `d2fba081-c414-4306-8518-a4c80074b5e6`, gallery `32fecc31-dcaf-5bd9-9f9a-fd36c44735fc`, file `design/assets/candidates/goblin-scout/ASSET-003-cand-01-proflash-seed0.png` | bbox 24x28 (x 4-27, y 20-47), feet on row 47, 6 colours all in spec (#59643F unused), alpha 0/255, lint 0 errors. Ears sideways in the upper half, hood flap, dark face with pale eyes, knife at belt, arms down. Front view: needs rotation for facing left. Style density matches the Swordsman. |
| rot-01 | 2026-10-31 | `create_character_pro_flash` | source_image_id = cand-01, palette locked, view low top-down, 8 directions | 1 gen | character `12574376-b113-460f-b07a-e75d265832db` (48x48 canvas); saved `south-west`, `west`, `south` under `design/assets/candidates/goblin-scout/ASSET-003-rot-01-*-48.png` | 6 colours in spec, alpha 0/255, lint 0 errors. **south-west chosen** (3/4 facing left, mirror of the hero's south-east): ears and hood readable, dark face with pale eye, knife at belt, 21x29 bbox. `west` rejected: face hidden, reads as a blob. |
| crop-01 | 2026-10-31 | local `crop_frame.py` (free) | 48x48 to 32x48, dx -10, dy 0 (feet already on row 47) | 0 | **`design/assets/candidates/goblin-scout/ASSET-003-idle-A-32x48.png`** | bbox x 5-25 (21 wide), y 19-47 (29 tall, spec <= 34), 6 colours, alpha 0/255. Candidate for clip `idle` frame A. Hood reads as a wide pointed cap rather than a flap over one ear (spec text), acceptable as the scout's accessory, note for the archer/shaman variants. |
| check-01 | 2026-10-31 | `prototypes/art-check` (free) | 5x5 + 5x5 board, 38x27 art-px slabs (Stone #4A4640, lip #2C2925), 640x360 shown at 2x, Nearest, feet 3 px above the lip, y-sorted | 0 | `production/qa/evidence/asset-slice1-art-check/01-pair-5x5.png`, `02-blackout.png`, `03-three-goblins-rows.png` | §8.9 #1 PASS: Ink silhouette = pointed hood plus the side ear, clearly smaller and rounder than the hero. #3 PASS: three scouts in one column on adjacent rows count as three (each hood top shows above the one in front) and the species reads. #9 PASS (retained). **CONCERN, contrast on the slab:** leather dark #4A3C2E has the same V (29 %) as Stone #4A4640 and leather mid #6B5640 is only 13 points lighter; at 1x the body reads as a dark blob held together by the outline, only the skin (V 55 %) and hood pop. Proposal before any animation: lift the two leather tones one step (about V 40 % / 52 %) or let more skin show; decide with the art-director (solo mode: user). |
| fix-01 | 2026-10-31 | `pixelart_workbench edit` map_colors (free) | #6B5640 -> #856B50, #4A3C2E -> #66523F on idle-A (135 px), user-approved | 0 | workbench image `3dcf997f-7e17-4027-9348-253c4a8998ee`; **`ASSET-003-idle-A-32x48.png` replaced** (old frame kept as `ASSET-003-idle-A-32x48-v1-darkleather.png`); art-check re-run: `04-pair-5x5-leather-v2.png`, `05-three-goblins-rows-leather-v2.png` | Body now separates from the slab at 1x (leather V 52/40 % vs Stone 29 %); hood and skin still read; #3 still passes. Contrast concern closed. Note: the PixelLab character `12574376` keeps the old palette, so future clips come from this local frame (`animate_image*`), not from `animate_character`. |
| anim-01 | 2026-10-31 | `animate_image_pixminimax` | first frame = idle-A v2 (base64), 4 frames, seed 1, view low top-down, direction south-west, motion "ears twitch 1 px, body bobs 1 px, knees bent, hands down" | 1 gen | job `fe933c11-5aef-47f4-bac2-b94d4c9bb856`, gallery `f3b1d2cf-61a9-5085-bdda-4eb0eba85262`; raw frames `design/assets/candidates/goblin-scout/idle-clip-raw/f1-f5.png`; **idle B = f3** saved as `ASSET-003-idle-B-32x48.png` | All 5 frames: feet row 47 and feet x 7-20 unchanged, 6 colours (new leather) unchanged, alpha 0/255, lint 0 errors, score 96.7. Only f3 moves (191 px, body up 1 px, bbox top y19 -> y18); f2/f4/f5 are within 2-38 px of f1, so the clip is effectively 2 poses. Clip `idle` = A / B (f3), 0.4 s each. §8.9 #7 PASS on the measurements; eye check pending. |
| anim-02 | 2026-10-31 | `animate_image_pixminimax` | first frame = idle-A v2, 4 frames, seed 1, south-west, motion "recoils, leans back 2 px toward the right, ears flick, feet planted" | 1 gen | job `1d2b35e1-c3cf-4347-8e1d-79930053cefa`, gallery `c26bbb04-c7a6-5d25-9ae1-b3a6d0caf1a9`; raw `hit-clip-raw/f1-f5.png`; **hit = f5** saved as `ASSET-003-hit-32x48.png` | Feet row 47 and feet x 7-20 in all frames, palette 6 and alpha unchanged, lint 0 errors. Upper-body centroid vs idle: f3 +3.3 px, f4 +4.5 px, f5 +2.7 px; f5 is the closest to the 2 px lean-back (f4 kept as a stronger option). |
| anim-03 | 2026-10-31 | `animate_image_pixminimax` | first frame = idle-A v2, 4 frames, seed 1, south-west, motion "quick scuttle in place, feet swap, body low, ears bounce" | 1 gen | job `ff75955d-b7d3-4373-88d1-a2cdee9f3a13`, gallery `a3177b7d-1c37-5eda-abaf-7d7ca2dda0a3`; raw `step-clip-raw/f1-f5.png`; **step A = f2, step B = f4** saved as `ASSET-003-step-A/B-32x48.png` | Feet row 47 in all frames, palette 6 and alpha unchanged, lint 0 errors. Footprints f2 x 8-14 (body up 1 px) and f4 x 11-17 (body down) give a 3 px foot swap with the body staying low; f3/f5 are the in-betweens. |
| anim-04 | 2026-10-31 | `animate_image_pixminimax` | first frame = idle-A v2, **8 frames**, seed 1, south-west, motion "buckles, falls forward onto knees and hands, collapses flat, ears droop, stays down, no blood" | 1 gen | job `f0a56fbb-126b-4ca5-b7aa-b7584f00e5e9`, gallery `3322236b-f1ab-5fd0-b0cc-1eff30253d27`; raw `down-clip-raw/f1-f9.png`; **down A = f5, down B = f7** saved as `ASSET-003-down-A/B-32x48.png` | Bottom row 47 in all frames, alpha 0/255, lint 0 errors, margins >= 1 px. Silhouette height 29 -> 20 (f5, on knees and hands) -> 13 (f7, flat heap); hood top 20 -> 31 -> 37, far past the 4 px of §5.3. f7 = f8 = f9: hold f7. Palette drops to 5 colours from f6 (the ivory eyes/teeth are hidden face-down), a subset of the spec palette. Ears still read in the heap, so the species survives the down pose. |
| check-03 | 2026-10-31 | `prototypes/art-check --anim` (free) | idle, step, hit, down, windup cycled beside the hero in layout v2 | 0 | `production/qa/evidence/asset-slice1-art-check/anim/*.gif` | §8.9 #7 PASS by eye: feet stay on the slab, no outline jitter, down settles flat, windup reads as a throw wind-up at 1x. All 8 goblin frames remain candidates; Done still needs the Aseprite source and the sheet + JSON export. |
| fix-02 | 2026-10-31 | local script (free), user-approved | hood #5E6B55 -> #8FA070 and leather mid #856B50 -> #9A7D5E on all 8 candidate frames (644 px); previous set kept in `pre-legibility-fix/` | 0 | all `ASSET-003-*-32x48.png`; evidence `asset-slice1-art-check/32-forest-goblin-v3-pair.png`, `33-…-blackout.png`, `34-…-rows.png` | §6.6 on the slab face (V 29), outline pixels counted as the rule is written: 6 % -> **36 %** at dV >= 25 (rule asks 40) and 0 % -> **31 %** at V >= 60 (asks 25). The upper half is 45 % Ink outline, so 55 % is the ceiling; excluding the outline the share is 67 %. Remaining lever is leather dark #66523F (39 px, V 40), which would flatten the leather ramp. Recommendation to the art-director: count fills only (the outline is the separator by design) and accept; otherwise lift leather dark to about #8A6E52. |
| anim-05 | 2026-10-31 | `animate_image_pixminimax` | first frame = idle-A v2, 8 frames, seed 1, south-west, motion "hunches lower, far hand pulled back behind the shoulder palm open, near hand stretched forward to aim, holds; only one arm back, nothing in the hands, feet planted" | 1 gen | job `10add0b1-061f-43ad-9bbb-ded9911f9ea2`, gallery `544a4bae-7c2f-5113-9b29-9eb90a03f227`; raw `windup-clip-raw/f1-f9.png`; **windup = f4** saved as `ASSET-003-windup-32x48.png` | Feet row 47 in all frames, palette 6, alpha 0/255, lint 0 errors. From f3 the pose matches §3: body lower (26 px tall, bbox y22-47), near hand forward to x4-5, far hand pulled back to x26, hands empty, never both arms up. f4 = f6 = f7 = f8 = f9: the held pose, margins L4 R4. Ivory particles at the back hand stay code-drawn as the spec says. |

**Status:** In Progress
