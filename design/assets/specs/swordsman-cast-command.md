# Swordsman `cast_summon`: one-handed raise + pull-down (ACCEPTED 2026-11-08; was `cast_command_proto`)

**Date:** 2026-11-08 · **For:** Ngàn Kiếm · **Status:** ACCEPTED by the user 2026-11-08 as `cast_summon`. It
overlaps the top-row HUD on 3 of 4 top-row cells; the user accepted that overlap (no change).

## Generation (user-approved, exactly 1 call)

- `animate_image_pixminimax`, job `91224bb1-17de-4a5b-a70b-b4f6a93ac14d`. **Cost: 1 generation** (2,168.9 →
  2,167.9).
- **First frame:** the guard padded to 96×92. **Last frame:** `cast_overhead/5` (the command pose) padded to
  96×92. Both were checked first: 3/4 south-east, the same identity, 7 colours, feet on row 91 x32–38.
- `frame_count` 8, south-east, low top-down, seed 1, `no_background`, no prompt enhancement. The subject and
  initial pose are the verified ones; the description is the user's motion text verbatim (955 characters, under the
  1,000 limit). The images were sent as uploads.
- **Files:** `design/assets/candidates/swordsman/cast-command/raw/f0–f8.png`, `clean/`, `source/` (the two
  endpoints).

## Frame review

| Raw | Pose | Notes |
|---|---|---|
| f0 | guard | the pinned input |
| f1 | **anticipation: knees bent, body dipped, sword low** | good weight shift |
| f2 | one-handed raise, blade up-left to the sky | blade on the frame's top row (art bible 8.3 margin): dropped |
| f3–f5 | high one-handed summon, left fist at the chest, face and hair visible | strong silhouette; the torso opens toward near-frontal (the face stays 3/4 right) |
| f6 | the pull-down | **baked smear arc**: dropped |
| f7 | the command, leaning in, cape flaring behind | good follow-through |
| f8 | the command pose | the pinned last frame (= `cast_overhead/5`) |

- **Feet:** x32–38 on row 91 in all 9 frames (no shift needed).
- **Cleanup:** palette snap only (f5 snapped; 0 speck px dropped).

## Nine-slot sequence (same ms as every Knight cast: 83, 83, 83, 83, 200 + swing hold, 50, 83, 100, 133)

| Slot | 0 | 1 | 2 | 3 | 4 (held) | 5 (release) | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|---|
| Frame | f0 guard | f1 crouch | f3 raise | f5 raise | f4 summon hold | f7 pull-down + cape | f8 command | `cast_overhead/7` return | `cast_overhead/8` guard |

The recovery comes from existing frames. `cast_overhead/7` lifts the sword slightly with a cape flare before the
guard. It is coherent, but it is a short re-lift, not a smooth settle.

## Checks

| Check | Result |
|---|---|
| Feet anchor | **PASS.** x32–38 on row 91 in all 9 slots |
| Identity (face, hair, armour, cape, sword) | **PASS.** The face and hair stay visible; the left hand stays a fist at the chest. |
| 3/4 south-east view | **PARTIAL.** The head keeps the view; on the raise the torso opens toward the camera. |
| Raise → hold → pull-down → command → recovery | **PASS** as a read (anticipation, a big raise, a held summon, a forceful pull-down with the cape, the command); the recovery is a short re-lift |
| Pixel quality | **PASS** for the used frames (7 colours, no smear: f6 dropped) |
| **HUD, top row** (hold frame, every part above the body) | **FAIL on 3 of 4 cells.** Column 0 overlaps the left HUD column (30 px); columns 2–3 touch the title (−2 px); column 1 is clear (22 px). |
| Gameplay | **unchanged.** Event log identical (clock, cells, order, kinds, damage) |

## VFX sync (Prototype A link VFX, `card_casts.ngan_kiem.summon_fx`)

- The focus appears with the raised blade (`summon_focus_from_sec` 0.166 = slot 2) and runs until the release
  frame.
- The command flash runs from the release frame to the swing end. The engine's release beat leads the pose switch by
  one frame (16 ms), exactly as for every Knight cast.
- The swords answer at the authoritative swing end (t0).

## Evidence (`production/qa/evidence/skill-v2-ngan-kiem/cast-command/`)

- `01-raw-frames-x4.png`
- `02-nine-slot-sequence-x4.png`
- `03-hud-top-row-hold-frame-2x.png`
- `04-ingame-hero-2x.png` (Prototype A vs this candidate)
- `05-ingame-native640.png`
- `06-sync-release-2x.png`
- `ngan_kiem_cast_command_plus5.avi` (local, not committed)

**Verdict: NOT APPROVED.** The acting is the best yet, but the raised blade breaks the top-row HUD rule on 3 of 4
cells. Card mapping right now: `ngan_kiem` → `cast_summon` (for review; Prototype A's
`cast_summon_proto` and v1 `cast_overhead` stay in the sheet).

## Tile-summon staging (2026-11-08, user direction: no beam to the sky)

- **Binding:** `card_casts.ngan_kiem = {clip: cast_summon, hand: [44, -9], charge_hand: [-39, -84], release: "",
  summon_fx: true, summon_focus_from_sec: 0.166}`. `release: ""` drops the hero's release slash and streak for this
  card. The Prototype A hand focus, command beam and response flashes were removed from the code.
- **Beats (plus5 capture, 60 fps):**

  | Beat | Time | Frames | Clip slot |
  |---|---|---|---|
  | guard | 0.00 s | F0–F5 | 0 |
  | crouch | 0.083 s | F5–F9 | 1 |
  | **raise** | 0.166 s | F10 | 2–3 |
  | **summon hold** | 0.33 s → visual command | F20 → about F104, held past the swing end | 4 |
  | **pull-down (command)** | about F104 | `SkyDropFx.summon_command_at` = first fall − 0.12 s | 5 |
  | command pose, return, guard | | | 6–8 |

- **Tiles:** from the raise, every target tile gets its own sword. CombatView runs the same `CastResolver.plan` as the
  arbiter during the swing, so the cells, finale, order and layout are the real ones. The tile shadow fades in, steel
  fragments gather, and the sword is built part by part (0.45 s; in schedule order, 0.06 s apart); then it hovers.
  The same code works for every shape.
- **Command:** the swords lock on (0.1 s white flash, 4 px cock-up) exactly when the Knight pulls down. Then each one
  stabs at its own authoritative `at` (the first 0.12 s after the command). At the swing end, the real schedule takes
  over with the identical re-timing (no jump).
- **Knight hold past the swing end:** `UnitLayer.cast_hold` and `CombatView.summon_hold_until`, visual only. A step
  cancels the hold, and the clip plays its pull-down at once.
- **Gameplay:** the plus5, T4 and bar4 event logs are identical to before (clock, cells, order, kinds, damage).
- **Tests:** `sky_drop_fx_test` `test_on_tile_summon` (9 checks; mutation-checked: no cock-up, no stagger and a late
  command each fail). Full suite 209/209.
- **Remaining blocker:** the raised pose still breaks the top-row HUD on 3 of 4 cells (column 0 the HP panel / relic
  column, columns 2–3 the title).
- **Evidence:** `production/qa/evidence/skill-v2-ngan-kiem/tile-summon/`.

