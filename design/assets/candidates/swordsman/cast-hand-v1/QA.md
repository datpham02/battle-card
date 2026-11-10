# Knight `cast_hand` v1 — PixMiniMax candidate, visual QA (NOT integrated)

- **Job:** `d34501bc-1923-48a4-9fc4-e4a5d8cc23aa`, 2026-11-09. **Cost:** 1 generation (the one approved call). No
  regeneration.
- **Input:** `art_src/units/kiem_si/idle/0.png` (96×70), used as both the first and the pinned last frame. 8 frames
  generated, 9 in total (`0.png` is the input).
- **Parameters:** exactly as approved (south-east, low top-down, the approved subject and motion text).
- **Files:**
  - `0.png`–`8.png`: native frames;
  - `strip_x4.png`: all 9 at ×4;
  - `qa_frames_0_4_5_7_x4.png`: close-up of frames 0, 4, 5 and 7;
  - `compare_old_handpainted_x4.png` vs `compare_new_generated_x4.png`: frames 0 / 2 / 4 / 5 / 7.

## Measurements

- All 9 frames are 96×70, with 7 opaque colours each and no semi-transparent pixels (crisp).
- Feet: the bottom row is y = 69 and the foot pixels span x = 32–38 **in every frame** (anchoring identical to idle).
- Bounding box: x grows from 80 to 85 at the extension (the hand reaches 5 px further forward); the top moves 1–2 px.

## Visual QA

| Check | Result |
|---|---|
| Arm anatomy / armour continuity | **Pass.** The casting arm is the same plate armour as the body: pauldron, articulated forearm, believable thickness. No thin stick. |
| Gauntlet | **Pass.** A dark steel gauntlet; fingers open toward the right in frames 4–6. |
| Gesture readable as an empty-hand cast | **Pass.** Anticipation (1–2), extension (3), held reach (4–6), return (7–8). It does not read as a sword attack. |
| Sword consistency | **Pass with a note.** The sword stays lowered and visible in all frames. In frames 4–5 it is drawn slightly shorter and flatter than in idle (a few px), then returns. |
| Feet anchoring | **Pass** (measured, identical). |
| Camera / facing | **Pass with a note.** Same 3/4 south-east view. In frames 4–5 the torso squares up a little toward the target (more frontal tabard); acceptable acting. |
| Character identity | **Defect 1 — the cape.** The gold-trimmed dark cape behind the body, prominent in idle, mostly **disappears in frames 3–6**: only fragments of the trim remain at the left edge. It returns by frame 8. Face, hair, tabard cross and armour colours are kept. |
| Pixel-art quality | **Defect 2 — stray pixels in frame 7:** a small detached grey streak right of the hand (about x 80–85), the remains of the retracting arm. **Minor note:** frame 5 has a 1–2 px light highlight at the fingertips that could read as a glint (the brief asked for no VFX baked into the frames). |
| Readable at 640×360 | **Likely yes:** the arm reaches about 5 px beyond the idle silhouette and the hold lasts the clip's held frame (200 ms on frame 4). To be confirmed in game after approval. |

## Recommendation

**Usable with two small mechanical fixes, if you approve:**
1. Remove the stray streak in frame 7: delete only those detached pixels.
2. Optionally remove the 1–2 px fingertip glint in frame 5.

These are pixel deletions, not hand-painted additions. The cape loss in frames 3–6 cannot be fixed mechanically
without painting (not allowed). Options:
- **(a)** accept it: it lasts about 0.4 s while the arm is out and the cape returns;
- **(b)** one more generation with a positive cue such as "the dark cape with gold trim hangs behind his back
  throughout". That needs a new approval.

Not integrated. The active sheet and `art_src/units/kiem_si/cast_hand/` are unchanged.
