# Knight `cast_hand` v3 (K2 compact palm push): PixMiniMax candidate, visual QA (NOT integrated)

**Job and cost**
- Job: `2a14a25c-48f3-4a89-80a4-047986527bf0`, 2026-11-09.
- Cost: 1 generation, the one approved call. No retry.

**Parameters**
- Input: `art_src/units/kiem_si/idle/0.png` (96×70), used as both the first and the pinned last frame.
- frame_count 8, direction south-east, view low top-down, no_background true.
- Approved subject text, initial_pose and motion text, used verbatim.

**Files**
- Frames: `0.png`–`8.png`.
- Strips: `strip_x4.png`, `strip_x1_gameplay.png`.
- Timed previews (clip ms list 83/83/83/83/200/50/83/100/133, plus a 0.5 s idle pause before the loop):
  `preview_x4_gameplay_timing.gif` and `preview_x2_gameplay_timing.gif`.
- K2 close-up: `k2_closeup_v3f2_f3_f4_x8.png` (frames 2, 3 and 4).
- Comparison: `compare_v1f4_v2f4_v3f4_x6.png`.
- Approved target: `../cast-hand-keypose-proposal/keypose_reference.html`.

## Measurements

| Frame | Pixels changed from the previous frame | Feet (y=69) | Colours / semi-alpha |
|---|---|---|---|
| 1 | 784 | x32–38 | 7 / 0 |
| 2 | 811 | x32–38 | 7 / 0 |
| 3 | 327 | x32–38 | 7 / 0 |
| 4 | 807 | x32–38 | 7 / 0 |
| 5 | 9 | x32–38 | 7 / 0 |
| 6 | 5 | x32–38 | 7 / 0 |
| 7 | 912 | x32–38 | 7 / 0 |
| 8 | 666 (18 px from idle) | x32–38 | 7 / 0 |

- **Structure:**
  - frame 0: guard;
  - frame 1: raise;
  - frames 2–3: forearm up at the chest, hand gathering (frame 3 is a small adjustment);
  - frame 4: push forward to K2;
  - frames 5–6: hold;
  - frame 7: retract and lower;
  - frame 8: guard.
- The static hold is now 3 frames (4–6), down from 5 in v2. Frames 4–6 last 333 ms with the clip ms list.

## K2 vs the approved target (frame 4)

| Criterion | Target | v3 frame 4 | Result |
|---|---|---|---|
| Elbow | (60,30), bent, close to the torso | about (61,27), close to the torso | **Pass** |
| Elbow angle | 110–120° | about 90–100°: forearm nearly horizontal, hand upright | **Close** (slightly tighter) |
| Gauntlet centre | (71,23) | about (69,25) | **Pass** (within 2–3 px) |
| Gauntlet size | about 6×7 | about 7×9 | **Pass with a note** (slightly larger, still compact) |
| Maximum reach | x≈74 | x=72 | **Pass** |
| Fingers grouped, clean silhouette | one block | upright block in frame 4; in frames 2–3 the fingers split into a 2-prong "V / claw" shape | **Frame 4 pass; frames 2–3 note** |
| Palm plane visible to camera | palm partly visible | The hand is seen mostly edge-on (side of the hand facing right). The flat palm surface is barely visible. | **Weak**: reads as a "halt" hand from the side, not a presented palm |
| Not a handshake / wave / high-five | — | Compact, low and close to the body | **Pass** |

## Consistency

| Check | Result |
|---|---|
| Sword | **Pass.** Same length and angle, lowered in every frame. It is redrawn slightly in frames 1–7 (130–240 px in the sword region), with no jump. |
| Face | **Pass.** Same face and hair. The redraw is small (about 200 px in the head area, the head turns slightly toward the target). |
| Armour / cape | **Pass.** The cape with gold trim stays in every frame. |
| Feet | **Pass.** Identical in all frames. |
| VFX / stray pixels | **Pass.** None. |

## Verdict

- **Much closer to K2 than v1 or v2.** Elbow, reach, size and the restrained feel are right, and the anticipation → push → recovery reads.
- **Remaining gaps:**
  1. The palm surface is mostly edge-on, so the "presented palm" reads weakly at 1×.
  2. The split-finger "V" shape in frames 2–3.
  3. A 3-frame static hold (acceptable).
- **Usable as a candidate.** The fix for gaps 1 and 2 must be a controlled key-pose correction, not another text-only generation.

Not integrated. The production sheet and `art_src/units/kiem_si/cast_hand/` are untouched.
