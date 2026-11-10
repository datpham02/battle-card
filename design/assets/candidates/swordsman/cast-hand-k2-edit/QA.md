# K2 single-pose inpaint: result and QA (NOT approved, NOT integrated)

**Job and cost**
- Job: `4232a048-bec5-457c-9273-b279e676af5a`, `inpaint_image_pro_flash`, seed 0.
- Cost: 5 generations, the one approved call. No retry.

**Input and mask**
- Base: `cast-hand-v3/4.png`.
- Pro Flash requires dimensions that are multiples of 4, so the base was padded to 96×72 with 2 transparent rows on top (`base_v3f4_pad96x72.png`).
- Mask on the padded canvas: x56 y16 24×20, which is x56–79, y14–33 on the 96×70 frame.
- The result was unpadded back to 96×70. The pad rows were verified empty. Output: `k2_native.png`.

**Files**
- `k2_native.png` (96×70);
- `k2_x8.png`;
- `compare_v3f4_vs_k2_x6.png`, `compare_upper_v3f4_vs_k2_x10.png`;
- `raw_inpaint_96x72.png` (the raw tool output).

## What changed (pixel diff vs v3 frame 4)

- **155 pixels changed**, all within x56–72, y14–31. **0 pixels changed outside the mask.**
  - Sword, legs, feet, torso, cape, face and hair are byte-identical to v3 frame 4.
- The old horizontal forearm and upright fist (x58–73, y20–31) were removed.
- A new short, bent arm was drawn tight against the right side of the chest.
  - The hand sits at about x56–60, y21–31, beside the chest and below the chin.
  - The rightmost opaque pixel in the arm area is **x=60** (v3 reached x=72; the K2 target is x≈74).
- The result has 9 colours, 2 of them not in the base palette. No semi-transparent pixels.

## QA vs the K2 target

| Requirement | Result |
|---|---|
| Elbow bent, close to the torso | **Pass**, but too close: the arm is folded into the torso silhouette |
| Forearm angled upward and forward | **Fail.** It goes up, not forward. Reach x=60 against the target x≈74; the hand barely leaves the chest outline |
| Compact gauntlet, outward-facing palm | **Fail.** The hand is a small vertical shape beside the chest and does not read as a palm aimed at the enemy |
| Readable at 1× | **Fail.** The arm merges with the tabard and shoulder; the cast gesture is nearly invisible |
| Sword, feet, body anchor unchanged | **Pass** (guaranteed by the mask, verified by the diff) |
| Palette / outline match | **Pass with a note** (2 new colours) |

## Verdict

**Do not approve this K2.** The anatomy got more compact, but the model pulled the hand back into the body instead of
pushing it toward the enemy.

**Why:** the mask allowed the hand to sit anywhere from the shoulder down, and the prompt words "tucked near the
ribs" won over "forward".

**Next controlled step, if wanted** (each needs its own approval):
1. **Shape the mask instead of the prompt.** Use a custom mask that covers only the corridor in front of the chest:
   - x58–77, y18–31;
   - plus the upper-arm strip x56–60.
   That leaves no room near the chin or face, and the hand is forced out in front of the chest. Shorten the prompt to
   "open palm pushed forward toward the right". Cost: 5 generations.
2. **Or hand K2 to a human pixel artist**, with `../cast-hand-keypose-proposal/keypose_reference.html` as the brief.
