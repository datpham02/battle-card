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

**Visual Description (v2, 2026-10-31; v1 read as Cloud Strife and was dropped, see the generation log):**
Chibi knight about 2.8 heads tall, standing upright facing right, rectangular build with two big square symmetric pauldrons, steel-blue plate armour with an ivory trim band across the chest, no bare arms. A straight, narrow double-edged sword (blade 2 px wide) sits in a dark scabbard strapped diagonally across the back, so what shows above the head is the hilt: a wide cross-shaped guard (~6 px) and a round pommel, rising at least 4 px above the hair. The cross-guard is the identifying mark, not a wide blade. Pale blond hair cut short with a flat fringe and three small tufts only at the crown, held by a 1 px ivory headband. Eyes are two 2x2 ink pixels with no whites, a 1 px straight brow. A short cape to the hips in dark Mist grey, fastened at both shoulders. All identifying features (cross-guard, headband, pauldrons) stay in the top 20 px because the lower half is often hidden by the row in front.

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
Pixel art character sprite, tiny chibi knight, front view, standing upright with feet apart on the bottom edge of the canvas, 32x48 canvas, about 40 pixels tall, big head about 14 px, rectangular build with two big square symmetric shoulder pauldrons. Full steel plate armor in three flat tones (mid #8FA3B8, light #EEF4FA, dark #5F6F82) with an ivory trim band across the chest, arms fully armored. A straight narrow double-edged sword in a dark scabbard strapped diagonally across the back: only the hilt shows above the head, a wide cross-shaped guard and a round pommel rising above the hair. Pale blond hair cut short with a flat straight fringe and three small tufts at the crown, a thin ivory headband. Eyes are two 2x2 dark pixels with no whites, a straight 1 px brow. Short dark grey-blue cape to the hips fastened at both shoulders. 1-pixel dark outline #1B1722. Crisp square pixels, no anti-aliasing, no dithering, no gradients, no glow, flat shading with light from the top-left, transparent background. All identifying features in the upper half of the body.
Negative: tall spiky swept-up hair, wide single-edged buster sword, bare arms, sleeveless top, one-sided pauldron, long cloak, red, orange, gold glow, bright blue cape, text, realistic proportions, painterly shading, soft edges, background scenery, weapon held in front.
```
v1 prompt (dropped): the same without the cross-guard, headband and symmetric pauldrons, with "spiky hair" and "large greatsword"; it produced a Cloud look.
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
| anim-02 | 2026-10-31 | `animate_image_pixminimax` | first frame = idle-A, 4 frames, seed 1, south-east, motion "recoils, leans back 2 px toward the left, feet planted" | 1 gen | job `9db765fc-07d6-46c6-85ab-fed76431eb2e`, gallery `48df8a0f-6c40-55ae-8bb4-4f4b1f4de784`; raw `hit-clip-raw/f1-f5.png`; **hit = f3** saved as `ASSET-001-hit-32x48.png` | Feet row 47 in all frames, palette 7 and alpha unchanged, lint 0 errors. Upper-body centroid vs idle: f2 -3.6 px, f3 -2.5 px, f4 -1.3 px; f3 is the 2 px lean-back the spec asks for (f2 kept as a stronger option). |
| anim-03 | 2026-10-31 | `animate_image_pixminimax` | first frame = idle-A, 4 frames, seed 1, south-east, motion "walking in place, feet swap, cloak trails" | 1 gen | job `16953a26-14ab-446f-8fe9-26fce6d155a7`, gallery `61d129f1-70b8-5a5c-adc1-6c61d3869617`; raw `step-clip-raw/f1-f5.png`; **step A = f3**, **step B = f5 shifted down 1 px** (local, feet back on row 47), saved as `ASSET-001-step-A/B-32x48.png` | Palette 7 and alpha unchanged. f3 = back foot extended (feet x 9-17), f5 = front foot extended (feet x 13-21) but the whole frame sat 1 px high (feet row 46, a hop), so it was translated down 1 px; f4 is a knee lift with one foot down (feet x 11-13), not used. Lint 0 errors on f3 and f5. Cloak trails in both. |
| anim-04 | 2026-10-31 | `animate_image_pixminimax` | first frame = idle-A, **8 frames**, seed 1, south-east, motion "staggers, drops to one knee, slumps forward, stays down, sword on back, no blood" | 1 gen | job `5dda3808-d38d-41d9-b090-f891ec9e6a8d`, gallery `7cd76154-d064-565a-8487-1e37d503bc9b`; raw `defeat-clip-raw/f1-f9.png`; **defeat A = f6, defeat B = f7** saved as `ASSET-001-defeat-A/B-32x48.png` | Bottom row 47 and palette 7 in all frames, alpha 0/255, lint 0 errors. The face (skin top row) drops from 10 to 16 and the figure ends kneeling, head bowed, so the silhouette changes >= 4 px (§5.3) even though the bbox height stays 45 (the pommel keeps the top). f7 = f8 = f9: the clip settles, hold f7. **f4 and f5 rejected**: the swinging blade touches the canvas edges (bbox x0-29 / x0-31, no 1 px margin, §8.3). Deviation to note: in f6-f7 the blade stands vertical beside the body as if planted, not strapped on the back; reads well as a defeat pose, art-director call whether to keep. |
| anim-05 | 2026-10-31 | `animate_image_pixminimax` | first frame = idle-A, 8 frames, seed 1, south-east, motion "raises one clenched fist to shoulder height and pumps it, chest out, feet planted, sword on back, fist never above the head" | 1 gen | job `90c54a59-a033-4da8-8b5e-aba28e004dc2`, gallery `d174a842-aa85-5b8b-b463-0f9811fbec1e`; raw `victory-clip-raw/f1-f9.png`; **victory A = f3, victory B = f5** saved as `ASSET-001-victory-A/B-32x48.png` | Feet row 47 in all frames (stance 1 px wider from f3), palette 7, alpha 0/255, lint 0 errors. From f3 the fist sits out front at shoulder height (bbox right edge x27-28); the clip repeats a 3-frame pump (f3/f4/f5 = f6/f7/f8), f5 bounces the body up 2 px (bbox top y1, 1 px margin kept). A = fist out, B = fist pumped; loop 0.4 s each per the spec. |
| anim-06 | 2026-10-31 | `animate_image_pixminimax` | first frame = idle-A, 4 frames, seed 1, south-east, motion "throws both arms up, knees bend, head tips back as the ground gives way" | 1 gen | job `49de63cd-0f48-4273-8322-a8779c06cb1c`, gallery `d9378222-ae64-50cd-a857-f63745edfefc`; raw `fall-clip-raw/f1-f5.png`; **fall = f4 shifted down 1 px** saved as `ASSET-001-fall-32x48.png` | Both hands up at head height, head tipped back; f4 floated 1 px (bottom row 46) so it was translated down; margins L1 R1 after the shift. f3 and f5 touch the canvas edges (x31 / x0), rejected. Palette 7, alpha 0/255, lint 0 errors. |
| anim-07 | 2026-10-31 | `animate_image_pixminimax` | first frame = idle-A, 8 frames, seed 1, south-east, motion "draws the greatsword with both hands, diagonal guard at the chest, swings across to the right, cloak flies, sword inside the frame" | 1 gen | job `9dbb5d6f-8e15-45bd-81ed-b93b4b33ad77`, gallery `3e04ea07-442b-527d-a29b-aaf4c66069b5`; raw `awaken-clip-raw/f1-f9.png`; **no frame adopted** | Every drawn-sword frame touches a canvas edge: f3/f5/f6 reach x0 and y0 (blade up-left), f4 reaches x31 (blade tip, complete, 1 px shift would fix), f7 reaches x0 (cloak), f8/f9 span x0-31 (cut: cloak left, blade right). A two-handed greatsword plus a flying cloak does not fit 32x48 with 1 px margins (§8.3). Options recorded: f4 shifted 1 px left as A, f7 shifted 1 px right as B (a raise, not a cut), or a 40x48 frame for awaken only. Superseded by the design revision below. |

**Design revision 2026-10-31 (user decision):** the v1 Swordsman reads as Cloud Strife (FF7): tall swept-up blond spikes, very wide single-edged blade on the back, dark cloak. The user chose to redesign and re-roll the anchor; every v1 hero frame above (cand-01 to anim-07) is kept as reference only. The revised Visual Description and prompt are now the ones above the log (user approved 2026-10-31).

| # | Date | Tool | Params | Cost | Result | Verdict |
|---|---|---|---|---|---|---|
| v2-cand-01 | 2026-10-31 | `create_image_pro_flash` | 32x48, seed 2, palette locked (8 hex), max_colors 8, no_background, NO style_image (to avoid pulling the v1 look); prompt = the v2 prompt above | 5 gen | job `cdafe2b0-a1c9-438e-931f-d739f4bf1893`, gallery `4f95ee3d-56d9-5840-a21c-5e0f88f42840`, file `design/assets/candidates/swordsman/ASSET-001-v2-cand-01-proflash-seed2.png` | No longer reads as Cloud: short flat blond cut with headband, two square pauldrons, full plate with ivory chest band, short cape, cross-guard + pommel ~7 px above the head on the upper left. bbox 27x42 (x2-28, y4-45), 7 colours (hair drawn in Ivory #EFE6D2, blond #E8D9A8 unused), light armour #EEF4FA = 10.5 % of pixels (accent <= 15 % OK), alpha 0/255, lint 0 errors. Floats 2 px (feet on row 45): fix at crop. Front view: rotation next. |
| v2-rot-01 | 2026-10-31 | `create_character_pro_flash` | source_image_id = v2-cand-01, palette locked, low top-down, 8 directions | 1 gen | character `5767dbe4-ff99-4a38-8d89-0d152df6ae5a` (48x48); saved `south-east`, `east`, `south` as `ASSET-001-v2-rot-01-*-48.png` | All 7 colours in spec, alpha 0/255, lint 0 errors. **south-east chosen** again (3/4 facing right): headband, flat fringe, square pauldron, short cape behind, scabbard on the back with the hilt above the head; bbox 26x43 (x9-34, y3-45), floats 2 px. `east` shows the clearest T-shaped cross-guard but hides the face. To hand-fix before crop: hair Ivory -> blond #E8D9A8, cross-guard made explicit on the south-east hilt. |
| v2-fix-01 | 2026-10-31 | `pixelart_workbench edit` (free) | map_colors Ivory -> blond in the hair rows 5-14 (63 px); patch_pixels 16 px: a 7 px steel cross-guard bar on row 10 across the grip, Ink outline above/below/ends, highlight at x10 | 0 | workbench `7697e131-51eb-458d-aa2c-3644c454fc59`, file `ASSET-001-v2-rot-01-south-east-48-fix.png` | 8 colours now (all spec), lint 0 errors / 0 warnings, 1 hole (arm gap). T-shaped hilt reads left of the head; face keeps Ivory as its light tone. |
| v2-crop-01 | 2026-10-31 | local `crop_frame.py` | 48x48 to 32x48, dx -6, dy +2 (feet from row 45 to 47) | 0 | **`design/assets/candidates/swordsman/ASSET-001-idle-A-32x48.png`** (canonical idle A is now v2; every v1 file moved to `v1-cloudlike/`) | bbox x2-28 (27 wide), y5-47 (43 tall incl. pommel), 8 colours, alpha 0/255, no pixel lost. Art-check re-run with the goblin: `production/qa/evidence/asset-slice1-art-check/06-pair-5x5-swordsman-v2.png`, `07-blackout-swordsman-v2.png`. |
| v2-anim-01 | 2026-10-31 | `animate_image_pixminimax` | first frame = v2 idle-A, 4 frames, seed 1, south-east, "chest rises 1 px, cape sways, feet planted, sword sheathed" | 1 gen | job `903ee75a-3b4a-468a-8d04-6f85d60c57e5`, gallery `56a026c9-be3c-56e9-84e3-a6bcd1df3443`; raw `idle-clip-raw/f1-f5.png`; **idle B = f3** `ASSET-001-idle-B-32x48.png` | Feet row 47 and feet x 11-26 in all frames, 8 colours, alpha 0/255, lint 0 errors. bbox never moves (the pommel sets the top); f3 changes 154 px (head and cape), f4 145, f2/f5 under 60. Subtler than v1's 1 px body lift; acceptable for a 0.4 s loop, revisit if it reads static in game. |
| v2-anim-02 | 2026-10-31 | `animate_image_pixminimax` | first frame = v2 idle-A, 4 frames, seed 1, south-east, "walking in place, feet swap, cape trails, sword sheathed" | 1 gen | job `026dff79-98ea-48a6-b0e1-8056be0aaaf4`, gallery `bbd2af38-cfd2-5013-b28a-83b128bc2b14`; raw `step-clip-raw/f1-f5.png`; **step A = f3, step B = f5** | Feet row 47 in all frames (no hop this time), 8 colours, lint 0 errors. f3: stride with feet x 12-26 and the body stretched 1 px (bbox top y4); f5: opposite stride, feet x 15-22, cape out to x1 and arm to x30 (margins 1 px, legal). f2 is a wide double stance (feet x 9-29), f4 legs crossing. |
| v2-anim-03 | 2026-10-31 | `animate_image_pixminimax` | first frame = v2 idle-A, 4 frames, seed 1, south-east, "recoils, leans back 2 px toward the left, feet planted, sword sheathed" | 1 gen | job `2d2fa2f6-ce3e-4cd6-94fc-8f6cc3a728d9`, gallery `fed7e392-ae3c-5d59-8ab8-ccaa7396b983`; raw `hit-clip-raw/f1-f5.png`; **hit = f4** `ASSET-001-hit-32x48.png` | Feet row 47 and x 11-26 in all frames, 8 colours, lint 0 errors. Upper-body centroid vs idle: f2 -1.0, f3 -2.7, f4 -1.3 px. f3 is the spec's 2 px lean but touches the left canvas edge (bbox x0); shifting it right would move the feet toward the enemy, so f4 (1.3 px, margins 1 px) is used. If the hit reads weak in game, redraw f3's x0 column by hand instead of shifting. |
| v2-anim-04 | 2026-10-31 | `animate_image_pixminimax` | first frame = v2 idle-A, 8 frames, seed 1, south-east, "staggers, drops to one knee, slumps forward, stays down, sword sheathed, no blood" | 1 gen | job `ea155982-26ed-4bf1-8ac4-70941478a875`, gallery `53d9e992-ef6d-5510-b2e8-7ed1ba92d3c3`; raw `defeat-clip-raw/f1-f9.png`; **defeat A = f4, defeat B = f7** `ASSET-001-defeat-A/B-32x48.png` | Feet/knee on row 47 in all frames, 8 colours, alpha 0/255, lint 0 errors, margins >= 1 px (f4 x2-30, f7 x4-29). Face top drops from row 11 to 20 and the silhouette from 43 to 39 px: §5.3 satisfied. f6-f9 settle (hold f7). Sword stays sheathed on the back this time. |
| v2-anim-05 | 2026-10-31 | `animate_image_pixminimax` + workbench fixes (free) | 8 frames, seed 1, south-east, "raises one fist to shoulder height and pumps it, feet planted, sword sheathed" | 1 gen | job `c71d5ba7-5071-4e2d-9edb-82bb04e14f8d`, gallery `57ab9fc1-42bc-50e2-b199-ee43fe4b0fb0`; raw `victory-clip-raw/f1-f9.png`; **victory A = f3 fixed** (workbench `e30bf391`: fist block moved 1 px left off x31), **victory B = f4 fixed** (workbench `8c83e124`: cross-guard bar moved 1 px right off x0) | Every raw frame was 31 px wide (pommel to fist) and touched an edge; the two fixes bring A and B to bbox x1-30 with feet x 11-26 on row 47 in both, 8 colours, lint 0 errors. A = fist out at chest height, B = bounce with the fist higher; loop 0.4 s each. |
| v2-anim-06 | 2026-10-31 | `animate_image_pixminimax` + workbench fix (free) | 4 frames, seed 1, south-east, "throws both arms up, knees bend, head tips back" | 1 gen | job `d896faf3-65ba-446f-8a13-103e61df4fc0`, gallery `331b6d4e-22b7-568f-a949-d6ae694a08c8`; raw `fall-clip-raw/f1-f5.png`; **fall = f2 fixed** (workbench `45de2b7b`: right hand moved 1 px left off x31) then shifted down 1 px locally | f3-f5 jump 2-3 px and span the full 32 px width (both arms flung wide), rejected. f2: both arms up, head back; after the fix and the shift bbox x1-30, y4-47, feet on row 47, 8 colours, lint 0 errors. |

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
