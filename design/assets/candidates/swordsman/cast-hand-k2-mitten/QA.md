# K2 mitten-gauntlet inpaint (corridor mask): result and QA (NOT approved, NOT integrated)

**Job and cost**
- Job: `b7442e1d-5cd2-4ee4-8236-77c0f0ecd397`, `inpaint_image_pro_flash`, seed 0, 2026-11-10.
- Cost: 5 generations, approved by the user ("làm cách 1 đi"). No retry.

**Input and mask**
- Base: `cast-hand-v3/4.png`, padded to 96×72 (2 empty rows on top), then unpadded. The pad rows were verified empty.
- Corridor mask: x56–79, y18–33 on the 96×70 frame, which is only the space in front of the chest. There is no room
  near the chin or face.

**Prompt**
"armoured forearm angled slightly upward, pushed forward toward the right in front of the chest, ending in a fingerless
mitten-style steel gauntlet: one compact rounded block with a flat palm facing right toward the enemy, a small light
highlight on the palm plane, dark outline, matching the existing palette and shading"

**Files**
- `k2_native.png`: raw result, 96×70.
- `k2_native_palette_snapped.png`: **recommended**, see the palette fix below.
- `k2_x8.png`, `k2_x1.png`.
- `compare_v3f4_inpaint1_mitten_x6.png`: v3 frame 4 | first inpaint | mitten.
- `closeup_v3f4_vs_mitten_x10.png`, `closeup_raw_vs_snapped_x10.png`.

## Pixel changes vs v3 frame 4

- **119 pixels changed, 0 outside the mask.** Sword, legs, feet, torso, cape, face and hair are byte-identical.
- The removed and replaced pixels cover the old horizontal forearm and the upright fist / "thumb", x58–73 y20–31.
- The new forearm rises slightly from the elbow (about x60, y27) to the wrist (about x66, y25).
- The new gauntlet is one rounded block at about x66–72, y21–30, with a light highlight on its right-front face.
- **Palette fix (mechanical, free):**
  - The raw result added 5 colours that are not in the base palette.
  - The 99 pixels using them were remapped to the nearest existing colour. No pixel was moved or drawn.
  - Output: `k2_native_palette_snapped.png`.

| Raw colour | → base colour |
|---|---|
| (35,31,42) | (27,23,34) |
| (148,164,175) | (143,163,184) |
| (107,123,140) | (95,111,130) |
| (176,139,100) | (184,137,58) |
| (62,73,111) | (52,64,110) |

- **Thumb fix (user, 2026-11-10: "vẫn có ngón cái", "there is still a thumb"):**
  - The 5 cream (216,205,176) highlight pixels on the gauntlet face (68,25), (69,25), (68,26), (69,26) and (70,26) read as
    a thumbnail.
  - They were recoloured to steel (143,163,184). Recolour only.
  - Output: `k2_native_no_thumb_highlight.png`. Comparison: `closeup_snapped_vs_no_thumb_x10.png`.

- **Reference-style mitten draft (user reference image, 2026-11-10: small chibi hands without fingers):**
  - The 7×10 ball gauntlet was replaced by a small mitten, 6×8 including the outline.
  - Placed at x65–70, y22–29, on the forearm end.
  - Uses existing colours only: outline (27,23,34), light steel (143,163,184), mid steel (95,111,130).
  - The palm plane (light) faces right and the camera; the back of the hand is mid steel. No crease, no highlight.
  - Two silhouette gaps at the wrist were closed with outline.
  - 46 pixels changed vs the ball version, all inside x65–74, y20–31.
  - Output: `k2_mitten_ref_draft.png`.
  - Sheets: `closeup_ball_vs_mitten_draft_x10.png`, `compare_v3_ball_mitten_full_x6.png`, `mitten_draft_x1.png`.
  - Free, a Claude pixel draft. NOT approved.

- **Hand from the user's crop (2026-11-10):** the user rejected the mitten draft and sent a crop of the reference hand.
  - The new hand is a wide rounded block, 7×6 including the outline, at x65–71, y23–28.
  - It has a darker left edge and 2 small crease pixels inside the bottom row.
  - **Skin variant** (`k2_hand_ref_skin.png`): skin (227,185,154), shade gold (184,137,58).
  - **Steel variant** (`k2_hand_ref_steel.png`): light steel (143,163,184), mid steel (95,111,130).
  - Both use existing colours only.
  - Sheets: `closeup_hand_skin_vs_steel_x10.png`, `full_hand_skin_vs_steel_x6.png`.
  - Free Claude draft. NOT approved.

## QA vs K2

| Requirement | Result |
|---|---|
| Elbow bent, close to the torso | **Pass** |
| Forearm slightly upward and forward | **Pass.** No longer a rigid horizontal bar |
| Reach | **Pass.** x=72 (target ≈74) |
| No fingers / thumb / spikes | **Pass.** A single mitten block |
| Compact gauntlet | **Pass with a note.** About 7×10, a little larger than 6×7 |
| Palm facing the enemy | **Partial.** The flat right face carries a highlight, but the block is quite round. It can read as a fist or as a hand holding a small orb |
| Sword, feet, body unchanged | **Pass** (guaranteed by the mask, verified by the diff) |
| Palette | **Pass** after the snap (raw: 5 new colours) |

## Verdict

**The best K2 so far, and a usable pose target.** All the anatomy and reach criteria pass, and the finger problem is
gone. The remaining risk is that the round mitten reads as "fist / holding an orb" more than "open palm".

At gameplay scale this will be partly carried by the separate Godot cast VFX at the hand: the glyph appears on the palm
side.

**Next step after approval:** build the transition frames around K2. Not started.
