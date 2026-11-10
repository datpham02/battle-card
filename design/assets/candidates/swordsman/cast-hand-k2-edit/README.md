# Knight K2 single-pose correction: proposal (nothing generated)

**Status (2026-11-09)**
- v3 rejected: raised fist / thumbs-up; arm too horizontal and rigid.
- The user asked for ONE corrected K2 pose before any new animation.

## Limitation

A high-quality hand-drawn armoured arm and open palm is beyond what Claude can do reliably with the free pixel tools.
- Earlier hand-painted cast_hand frames were rejected as a "thin stick arm".
- Other hand-painted details were rejected as ugly.
- No existing generated frame contains a compact, camera-facing palm that could be transplanted mechanically.

So no crude arm was built.

## Proposed controlled edit

**Tool:** `inpaint_image_pro_flash`. Pixels outside the mask are copied back byte for byte.

| Item | Value |
|---|---|
| Base | `cast-hand-v3/4.png` (body brace, sword, feet and face are already right) |
| Mask | rectangle x56 y14, 22×21 px: the upper arm from the pauldron, the forearm and the gauntlet only (`mask_arm_x56_y14_22x21.png`, preview `mask_overlay_on_v3f4_x8.png`) |
| Cost | 5 generations (96 px canvas), 1 call, needs an explicit yes |
| Outside the mask | sword, legs, feet, torso, cape and face are unchanged by construction |
