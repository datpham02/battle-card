# Lean review: Forest Witch and Goblin Warlock, move and windup (2026-11-13)

Review only. **No value was changed.** Current data: idle `sway_px` 0 (previous tuning), move `lean_px` 1, `windup_lean_px` 1,
`hit_lean_px` 1, `land_squash_px` 1. Evidence below is from the working tree with those values.

## How the footage was made
- **Move:** the step frames from `../tuning-caster-sway/after/<id>/` (current values, fixed 1/60 s ticks).
- **Windup:** new mode `windup` in `tools/qa/unit_motion_footage.gd`. The pattern brain is unpaused and the whole match
  runs on CombatView's own tick, called by hand at 1/60 s, so the windup plays at game timing. The tool saves every
  frame from 10 frames before the enemy leaves idle until 40 frames after it is back. Windowed, muted, one Godot at a
  time. No game code was touched.
- **Seams:** `tools/qa/unit_band_seams.gd` now takes `<id>:<clip>` (here the held `windup` frame) and lists the frame
  columns where a pose breaks the outer silhouette at a band seam, counting only breaks the pose adds.

## Findings

### 1. When each unit leans in play (from `motion.csv`)
| Moment | Witch | Warlock | Lean |
|---|---|---|---|
| Move: anticipation | 2 frames (33 ms) | 2 frames | −1 (head back) with a 1 px crouch |
| Move: glide + start of settle | 11 frames (0.18 s) | 11 frames | +1 (head leads) |
| Windup / warning (held `windup` frame) | **146 frames = 2.43 s** in one run, 35 frames = 0.58 s in another | 77 frames = 1.28 s; 118 frames = 1.97 s | +1, constant for the whole hold (away from the hero) |
| Back to idle | 8 frames of weight-release dip (squash 1, no lean) | the same | 0 |

**The windup is the long one.** The lean is held on a still frame for 0.6–2.4 s, depending on which skill the brain
picks. A move lean lasts about 0.2 s, while the authored step clip and the glide are both moving.

### 2. Do the connected parts detach? (`seams/`)
New outer-silhouette breaks that a lean +1 adds at the chest seam (no pose adds any break at the waist seam). Both
sheets face left, as the enemy does, so they are drawn unmirrored and the sheet's lean +1 is the screen's lean +1:

| Frame | Witch (chest row 54) | Warlock (chest row 48) |
|---|---|---|
| `windup` (held, what the player stares at) | **1 column**: x 38, the raised hand's wrist (hand vs forearm) | **3 columns**: x 31 / 36, where the crystal meets the raised fist; x 143, the lantern's lower right corner (lantern vs shaft) |
| `idle` (now only during a move, from the old sway) | 1 column: x 44 (hair edge) | 4 columns: x 34 (pack), 107 / 113 / 118 (lantern and shaft) |

- **Staff hand:** on both units the hand on the staff sits inside the robe, so no silhouette breaks there. The Witch's
  chest row runs through her staff grip. During a lean the shaft above the grip sits 1 px off the shaft below,
  inside the outline. This shows only at 6–8× (`seams/forest_witch_windup_zero_vs_lean1.png`).
- **Hair, hat, ears, stone pack:** the lean moves the whole head band in one piece, so the hat, pack, antlers and
  hair top stay together. What shifts is the band against what sits right under the seam: the Warlock's pack and hat
  cone against the brim and ears, and the Witch's hanging hair against the staff hand. These are interior, texture-
  level shifts, with no outline gap.
- The marked frames show exactly where: `seams/goblin_warlock_windup_lean1_breaks_marked.png` and
  `seams/forest_witch_windup_lean1_breaks_marked.png` (zero pose left, lean +1 right, red boxes at the break columns).
  The windup frame at 8× mid-hold in gameplay: `compare/*_windup_hold_8x_detail.png`.

### 3. Is the seam noticeable in actual gameplay?
- **Move:** no. At 1:1 (`../tuning-caster-sway/compare/*_step_1x.mp4`) the 1 px band shift lasts about 0.2 s, while
  the directional step clip changes the whole pose (staff angle, cloak, face) and the body glides a full cell. The
  4× strips (`move/*_rest_antic_glide_4x.png`, `move/*_move_lean_4x.png`) show the authored change is many times
  larger than the shear.
- **Windup:** hard to see at 1:1. At the game's scale one break is a 2-screen-px notch on an outline edge (the
  crystal tip, the lantern corner, the Witch's wrist), next to the windup telegraph VFX under the unit
  (`compare/*_windup_onset_1x.png`, `compare/*_windup_1x.mp4`). It is visible at 4–8× (`compare/*_windup_4x.mp4`,
  `compare/*_windup_enemy_8x_halfspeed.mp4`). It is static for up to 2.4 s, which makes it the case closest to the old
  idle seam. But it happens only during a windup, not for the whole idle, and the player's eye is on the telegraph.
- **Stress-test sheets vs play:** lean ±2 and squash 2 in `../review/seams/` never happen on these two units.

### 4. Does the lean help movement and anticipation?
- **Move, for these two big casters: barely.** The −1 anticipation lean lasts 2 frames (33 ms), too short to read
  on its own. The +1 lead during the glide is 2 screen px against a full-cell glide and an authored step clip. The
  crouch, the 1 px hop and the landing squash carry more of the weight read than the lean does.
- **Windup: only at the onset.** The lean starts on the same frame the windup clip appears, as a 2-screen-px jolt
  backwards that adds a little "coil" to that moment. The authored windup frame already does most of it (the crystal
  hand comes up, the pose changes, the telegraph starts). After the onset the held lean adds nothing new; it only
  keeps the band offset on screen.

## Conclusion
No obvious visual detachment at the normal display scale. The breaks are 1 px notches at three outline points that
show at 4× and up. **I recommend keeping the current values** and judging the 1:1 windup videos and one real match
on a device.

## Targeted fix, if the windup notch shows in your review (not applied)
Keep the coil at the windup onset and drop it for the hold, on these two units only:
- Add `windup_lean_sec` to `unit_motion.json`: how long the windup lean lasts from the moment the coil clip starts
  (absent = the whole windup, as now). Set 0.15 s on `forest_witch` and `goblin_warlock`.
- Code: `UnitLayer.unit_pose` would read the time since the coil clip started (one float per side, reset when the
  logical clip enters the coil set). That is a small change in `unit_layer.gd` + `unit_motion.gd` plus a test. No
  gameplay timing changes. The move lean, the onset jolt, breathing and landing stay exactly as now.
- A data-only alternative is `windup_lean_px` 0 on these two. It removes the onset jolt as well.
- Not recommended: moving the chest split (`chest_ratio`). Both staffs run through every row from the lantern or
  branches to the ground, so any split row crosses a staff.

## Files (`production/qa/evidence/unit-motion/lean-review/`)
- `compare/forest_witch_windup_1x.mp4`, `compare/goblin_warlock_windup_1x.mp4`: real screen 1:1, idle → windup →
  idle, real time. **Start here.**
- `compare/*_windup_4x.mp4` (hero | enemy at 4×), `compare/*_windup_enemy_8x_halfspeed.mp4` (enemy alone at 8×, half
  speed).
- `compare/*_windup_onset_1x.png`: the last idle frame and the first windup frame at 1:1.
- `compare/*_windup_hold_8x_detail.png`: a mid-hold windup frame at 8×.
- `seams/*_windup_seams.png`: the held windup frame in every pose, with a changed-pixel mask.
- `seams/*_windup_zero_vs_lean1.png`: the windup frame at lean 0, at lean +1, and the mask.
- `seams/*_windup_lean1_breaks_marked.png`: the break columns boxed in red.
- `seams/*_seams.png` (idle frame) and `seams/*_chest_seam_closeup.png`.
- `move/*_rest_antic_glide_4x.png`: rest, anticipation and glide frames at 4×. `move/*_move_lean_4x.png`: every lean
  frame of a step.
- `windup/<id>/`: raw frames (`windup_*` 4×, `screen_windup_*` 1:1, `enemy_windup_*` 8×) and `motion.csv`.
