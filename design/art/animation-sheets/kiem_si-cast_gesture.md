# Animation Design Sheet — Combat: kiem_si / cast_gesture (v4, wind-up)

Made with `/pixellab-animation-engineer`, 2026-11-01.

## Header

| Field | Value |
|---|---|
| Character | Swordsman (`kiem_si`), PixelLab character `2d093318-1ba4-43aa-b843-a5f0fdf62939` |
| Clip | `cast_gesture` (the cast that launches the sword-qi wave) |
| Replaces | `art_src/units/kiem_si/cast_gesture/` (7 frames) — user 2026-11-01: "nhân vật ko thể đứng thẳng rồi cầm kiếm vung như vậy được, nhìn nó cứng quá, phải có động tác hay chuyển động gì rồi chém ra chứ" |
| Direction / view | south-east / low top-down (mirrored at runtime for facing left) |
| Frame | 96×70 final (generated at 96×96), feet row 69 (79 on the 96×96 canvas), feet x 48 |
| Loop | one-shot → idle |
| Engine | `animate_character` mode `pixminimax`, 8 frames, 1 gen — the engine every current clip of this character came from |

## Why the old clip reads stiff

1. The sword is already drawn on frame 0 and the legs never change: no weight
   shift, no crouch, no step.
2. Code: during the swing telegraph (~1.2 s for the fallback card) the clip is
   paused on frame 0 (`UnitLayer.cast_hold`), so the hero stands still holding
   the sword up and only swings in the last 0.27 s.

## Gameplay purpose and events

| Event | Frame | Use |
|---|---|---|
| hold | 3 | held for the whole swing telegraph (variable length), released `gesture_lead_sec` before the launch |
| release | 5 | the sword-qi wave leaves the hand (`CastVfx` launch) |
| recover | 7 | back to stance |

## Key poses

| Key | Name | Body mechanics |
|---|---|---|
| K0 | Idle | upright, sword sheathed on the back, hilt over the right shoulder |
| K1 | Draw | right hand over the shoulder pulling the sword; weight starts back |
| K2 | Coil (held) | deep crouch, weight on the back foot, front knee bent, shoulders twisted away, sword low behind the hip in both hands, cape swung forward |
| K3 | Lunge + slash | front foot steps forward, body uncoils, one horizontal cut to the right at chest height, arms fully extended |
| K4 | Overshoot | blade past the front, torso rotated forward, cape whipping back |
| K5 | Recover | stands up, sword slides back into the scabbard |

## Frames

| f | Pose | Ticks @60 Hz | Event |
|---|---|---|---|
| 0 | idle (source frame) | — | |
| 1 | draw over the shoulder | 5 | |
| 2 | sinking, twisting away | 5 | |
| 3 | coil peak | held (nominal 12) | hold |
| 4 | lunge, blade sweeping (smear allowed, own palette) | 2 | |
| 5 | arms extended at chest height | 3 | release |
| 6 | overshoot, cape whips back | 5 | |
| 7 | standing up | 6 | recover |
| 8 | sheathing, back to idle | 8 | |

Slash part f4–f8 = 24 ticks (0.40 s); slash start → release = 2 ticks (0.033 s).

## Constraints (positive wording)

- Faces right in every frame; camera locked; same size every frame.
- The sword keeps its length; it is in the right hand.
- Feet on the ground row; the back foot stays, the front foot steps and returns.
- Only the character: the slash trail and the wave are separate VFX.
- Palette `art_src/palette/tessera_master.gpl`; the cape stays navy (known drift: turns skin-coloured).

## Prompt Pack (take 1)

- Tool: `animate_character`, `mode: pixminimax`, `directions: ["south-east"]`, `frame_count: 8`, `keep_first_frame: true`, `enhance_prompt`: off.
- `action_description`: "Reaches over the right shoulder and draws the long sword, then sinks into a deep crouch with the weight on the back foot, torso twisted away and the sword held low behind the hip with both hands, the cape swinging forward; holds that coiled pose, then steps forward with the front foot and uncoils into one fast horizontal slash to the right at chest height, arms fully extended; the blade overshoots past the front while the cape whips back; then stands up and slides the sword back into the scabbard on the back. Faces right in every frame, feet stay on the ground, the sword keeps the same length, only the character, no effects."
- `subject_description`: "a slender young knight with ash-blond hair, steel plate armour with square pauldrons, a navy cape with brass trim and a long narrow straight sword"
- `initial_pose`: "standing upright facing right, relaxed, the sword sheathed on the back with the hilt above the right shoulder"
- Cost: 1 gen. Approved by the user 2026-11-01.

## QA log

| Take | Job | Verdict | Crossed / not run | Fix applied |
|---|---|---|---|---|
| 1 | `f98fdeec-41d6-4c6c-8e88-61a9b30abb9e` (group `a5212561-d534-444a-8fe6-63e7c6f335d3`), 1 gen, raw in `design/assets/candidates/swordsman/v3-tall/anim/cast_gesture-2026-11-01/raw/` | **WARN → accepted by the user 2026-11-01** ("Nhận, gắn vào game") | `palette` 13.78 % off but `palette_far` 0.28 % (near shades of steel / ink / ivory, snap-fixable); `size_drift` frame 6 = 1.341 (the lunge + smear, explained by the pose); not run: `foot_x_planted` (the clip steps on purpose), `loop_seam` (one-shot). Visual: crouch + lunge + follow-through read; deviations from the sheet: the coil holds the sword up vertical (not low behind the hip) and the clip ends with the sword raised, not sheathed | free: palette snap, crop 96×96 → 96×70 (rows 10..79), append the accepted frame 6 (sheathed) as the last frame; code: hold the coil frame during the telegraph |

## Hand-off (2026-11-01)

- Clean frames (palette snap to the 8 knight colours, 0 specks, crop rows 10..79): `design/assets/candidates/swordsman/v3-tall/clean-96x70/cast_gesture/` (v4); the v3 clip kept in `clean-96x70/cast_gesture-v3/`.
- Installed: `art_src/units/kiem_si/cast_gesture/0..8.png`, `clips.json` ms `[83, 83, 83, 83, 200, 50, 83, 100, 133]`; sheet re-exported (`unit_kiem_si_sheet.png` 872x567).
- Code: `assets/art/vfx/cast/index.json` `gesture_hold_frame: 4`, `gesture_lead_sec: 0.03`; `UnitLayer._drive_cast_hold` plays the clip from the swing start, stops on frame 4 during the telegraph, jumps to frame 5 when the launch is due; `UnitAnimator.seek`.
- In-game evidence: `production/qa/evidence/playtest-fixes-2026-10-31/22-cast-gesture-v4-windup-in-game.png`; compare page `cast-gesture-compare.html`.

```json
{"clip": "cast_gesture", "frames": 9, "ticks_60hz": [5, 5, 5, 5, 12, 3, 5, 6, 8], "events": {"hold": 4, "release": 5, "recover": 7}}
```
