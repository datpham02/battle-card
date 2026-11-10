# Knight `cast_hand` v2 (open-palm STOP): PixMiniMax candidate, visual QA (NOT integrated)

> **REJECTED by the user (2026-11-09).** The hand looks exaggerated. The spread fingers read as waving or a high-five,
> not a restrained armoured cast. There is also a 5-frame static hold. Do not integrate.
> Next direction: `../cast-hand-keypose-proposal/keypose_reference.html`.

**Job and cost**
- Job: `25732533-b950-4a11-9867-eb6cdc24fea6`, 2026-11-09.
- Cost: 1 generation. This was the one approved call, with no retry.

**Input and parameters**
- Input: `art_src/units/kiem_si/idle/0.png` (96×70), used as both the first and the pinned last frame.
- frame_count 8 (9 frames in total). Direction south-east, view low top-down, no_background true.
- subject_description is unchanged from v1. The motion text is the user's revised STOP-gesture text, verbatim.

**Files**
- Frames: `0.png`–`8.png`.
- Strips: `strip_x4.png` (nearest ×4), `strip_x2_mobile.png`, `strip_x1_gameplay.png`.
- Animated previews: `preview_x4.gif`, `preview_x1_gameplay.gif` (100 ms per frame).
- Close-up: `qa_frames_0_1_4_7_x6.png`.
- Comparison: `compare_v1f4_v2f4_x4.png` (v1 handshake vs v2 palm).

## Measurements

| Frame | bbox | Feet (bottom row y=69) | Colours / semi-alpha | Pixels changed vs frame 0 |
|---|---|---|---|---|
| 0 | x31–80 y6–69 | x32–38 | 7 / 0 | 0 |
| 1 | x31–79 y5–69 | x32–38 | 7 / 0 | 745 |
| 2–6 | x31–78 y4–69 | x32–38 | 7 / 0 | 993–994 |
| 7 | x31–79 y5–69 | x32–38 | 7 / 0 | 768 |
| 8 | x31–80 y6–69 | x32–38 | 7 / 0 | 36 (back to idle) |

- **Frames 2–6 are a near-static hold.** Only 3–5 px change from frame to frame.
- **Structure:**
  - frame 0: idle;
  - frame 1: raise;
  - frames 2–6: palm held;
  - frame 7: lower;
  - frame 8: idle.

## Visual QA

| Check | Result |
|---|---|
| Open palm facing outward | **Pass.** In frames 2–6 the gauntlet is raised to shoulder/head height, fingers up and spread, with the flat palm turned toward the right and the camera. It reads as STOP / force-push, not a handshake. See `compare_v1f4_v2f4_x4.png`. |
| Elbow bent, arm armoured, gauntlet connected | **Pass.** Pauldron → bent plate forearm → dark gauntlet, one continuous piece. |
| Readable at gameplay scale | **Pass (×1 strip).** The raised hand with separated fingers is visible above the shoulder line. It is clearer at ×2 (mobile). |
| Sword consistency | **Pass with a note.** The sword stays lowered and visible in every frame. In frames 1–7 it is redrawn slightly (about 110–150 px differ in the sword region), with the same length and angle and no jump. Frame 8 returns to idle. |
| Feet anchoring | **Pass.** Measured identical in all 9 frames. |
| Armour / cape continuity | **Pass.** The cape with gold trim stays in every frame (the v1 defect is gone). Face, hair, tabard cross and palette are kept. |
| Baked VFX / stray pixels | **Pass.** No glint and no detached streak seen. 7 colours, crisp alpha. |
| Timing | **Note.** There is only one in-between frame in each direction, so the raise is snappy. With the existing clip ms list `[83,83,83,83,200,50,83,100,133]`, the raise lasts 83 ms and the hold (frames 2–6) about 0.5 s, which suits a cast. |

## Recommendation

**Approve as-is.** No mechanical fix is needed. On approval, the integration steps would be:
1. Copy the frames into `art_src/units/kiem_si/cast_hand/`.
2. Rebuild the kiem_si sheet, keeping the 96×92 / body_h 70 bottom alignment.
3. Test `vung_lay` in both facings.
4. Confirm that Trảm Địa, Ngàn Kiếm and Hỏa Lôi are unchanged.

Not integrated. The production sheet and `art_src/units/kiem_si/cast_hand/` are untouched.
