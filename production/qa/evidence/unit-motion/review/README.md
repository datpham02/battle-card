# Unit motion — review footage (2026-11-13)

This folder replaces `../footage/` (first-pass captures, some with the enemy caught in a windup). The amplitudes,
gameplay timing, sprites and other systems are as they were after the motion pass. Nothing changed for this footage.

## How it was captured
- **Before** = the committed code (HEAD 6bbcdd0), run from a separate detached git worktree in the session scratchpad.
  The working tree was never swapped or touched. **After** = the working tree with the motion pass.
- Windowed 1280×720, `--audio-driver Dummy`, one Godot at a time. The layer clock is driven at a fixed 1/60 s per
  frame (`tools/qa/unit_motion_footage.gd`).
- The match is frozen before filming: boss brain off, the pattern brain paused (its own `set_active(false)`; the
  committed controller is ended through `_end_skill`, the same call), CombatView's tick stopped. **Every enemy is in
  `idle` for the whole 6 s idle segment in both runs** (logged in `after/<id>/motion.csv`).
- Same arena, same cells, same frames for before and after: hero (Swordsman, `kiem_si`) on (1,1), enemy on (4,1)
  where it fits (bosses with a big footprint stay at their spawn cell, the same in both runs).

## Profiles covered
| Profile | Sample (folder id) | Notes |
|---|---|---|
| hero | `kiem_si`, the left unit in every clip | |
| heavy | `ogre_king` | |
| agile | `goblin_scout` | now really idle (was in a windup before) |
| caster | `forest_witch`, `goblin_warlock`, `cultist` | Witch and Warlock now really idle |
| floaty | `ghost` | |
| blob | `slime` | |
| default | `default_cultist` | **No shipped unit uses `default`.** This is the Cultist with its profile forced to `default` by the capture tool, only for the after run. Its "before" is the plain Cultist |

## Files (all under `production/qa/evidence/unit-motion/review/`)
**Start here: `compare/<id>_idle_1x.mp4` and `compare/<id>_step_1x.mp4`.** They show the real screen at the game's
own scale, before on the left, after on the right, in real time.
- `compare/<id>_idle_1x.mp4`: 6 s idle, real screen 1:1 (2 screen px per art px), before | after.
- `compare/<id>_step_1x.mp4`: the hero steps, then the enemy steps, real time, 1:1, before | after.
- `compare/<id>_idle_4x.mp4`, `compare/<id>_step_4x.mp4`: the same at 4× art px, cropped round each unit and
  following its ground anchor (the step video plays at half speed).
- `compare/<id>_hero_step.png`, `compare/<id>_enemy_step.png`: every 3rd step frame at 4×, before | after per tile.
- `compare/ghost_hover_1x_pair.png`: the strongest idle motion at 1:1 (hover 0 and 2 px).
- `seams/<id>_seams.png` (8 units): controlled seam sheets at 6×. The same idle frame is drawn exactly like the game
  in 7 poses (zero, lean +1, lean −1, squash 1, lean +1 squash 1, lean +2, squash 2). Top row: the pose, with cyan
  ticks at the two split rows. Bottom row: every art px that differs from the zero pose, in magenta.
- `seams/forest_witch_zero_vs_lean2.png`, `..._zero_vs_squash2.png`, and the same for `goblin_warlock`: zero beside
  the strongest pose, whole frame at 6×.
- `compare/forest_witch_seams_8x.png`, `compare/goblin_warlock_seams_8x.png`: the first in-game frame of each
  distinct pose, enemy alone at 8×. These mix idle frames, so use `seams/` to judge the seams themselves.
- `before/<id>/`, `after/<id>/`: the raw frames (`idle_*`, `step_*` at 4×; `screen_idle_*`, `screen_step_*` at
  1:1), `context.png` (the whole screen) and `motion.csv` (after: per-frame clip and pose).

## Seams: Forest Witch and Goblin Warlock
Split rows (frame rows from the top, `seams/*` cyan ticks):

| Unit | Frame | Body h | Chest split | Waist split |
|---|---|---|---|---|
| Forest Witch | 160×130 | 112 | row 54: through the hanging hair under the mask, and the hand gripping the staff (the reaching hand is below it) | row 83: mid robe, crossing the staff shaft |
| Goblin Warlock | 160×130 | 121 | row 48: through the bottom of the stone pack and the hat cone, just above the brim and ears | row 79: across the hand on the staff and the staff shaft |

- **In play, casters only ever reach lean ±1 and squash 1** (sway, move and windup are 1 px; land squash 1). Lean +2
  and squash 2 in the sheets are stress tests: they never happen on these two units.
- **Lean 1** moves only the head band, so there is one 1-px step at the chest row. On the Witch it runs through the
  hanging hair and the staff hand: the hair and the top of the staff slide 1 px against the hand. On the Warlock the
  stone pack and the hat cone slide 1 px against the brim and the ears, and the staff gets a 1-px kink there.
- **Squash 1** moves torso and head together: no jog at the chest row. At the waist row 1 row is hidden for a moment
  (Witch: mid robe; Warlock: across the hand on the staff). No gap opens.
- **How often:** in the 6 s idle the Witch shows a non-zero lean in 228 of 360 frames and the Warlock in 239 of 360.
  The slow head sway rounds a sine to ±1, which holds the lean about two-thirds of the time. A band offset is on
  screen most of the idle, not only at the sway's peaks. This is the main thing to look at in
  `compare/forest_witch_idle_4x.mp4` and `compare/goblin_warlock_idle_4x.mp4`.

## Is 1–2 px noticeable at the normal display scale?
- The battle art is drawn at an integer scale (`ScreenLayout.art_scale`). At the reference 1280×720 window,
  **1 art px = 2 screen px** (logged by every run). On a 1080p-tall phone (canvas_items stretch from 720) it is
  about **3 device px, roughly 0.2 mm** on a typical 6.5" screen.
- The hero is about 120 screen px tall at 1:1, so a 1-px breath is a 2-screen-px dip (under 2 % of the body).
- Measured idle motion, art px changed per 50 ms frame on each unit's crop (before → after): hero 187 → 199; Goblin
  Scout 77 → 116; Forest Witch 590 → 660; Goblin Warlock 954 → 983; Ogre King 111 → 107; Ghost 51 → 86; Slime
  107 → 109; Cultist 23 → 36; Cultist with `default` 23 → 31. The big bosses already animate a lot. The small,
  quiet sheets (Ghost, Goblin Scout, Cultist) gain the most.
- My read from the 1:1 stills, to be confirmed by your eye on the videos: the 2-px hover is clearly visible. 1-px
  breaths and leans read as "alive" when you look straight at a unit, and mostly disappear while you watch the board.
  The step pose (crouch, hop, landing) is the most visible change, because it happens all at once in 0.15–0.3 s.

## Not covered
- The hero is always the Swordsman. The other four heroes share the `hero` profile with small per-hero overrides.
- Only the 7 profiles above. The other 60-odd enemies use the same seven archetypes.
- No Android capture.
- Recapture: `bash tools/qa/unit_motion_compare.sh production/qa/evidence/unit-motion/review` rebuilds `compare/`
  from the frames. The before worktree is still at the session scratchpad (`head-tree`); remove it with
  `git worktree remove --force <path>` when the review is done.
