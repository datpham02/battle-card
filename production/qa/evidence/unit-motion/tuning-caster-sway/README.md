# Tuning: caster idle sway off for Forest Witch and Goblin Warlock (2026-11-13)

Follows `../review/README.md` (seam analysis). Nothing committed.

## The change (data only)
`assets/art/units/unit_motion.json`, `units`:
```
"goblin_warlock": "caster"  ->  {"archetype": "caster", "sway_px": 0}
"forest_witch":   "caster"  ->  {"archetype": "caster", "sway_px": 0}
```
plus one sentence in the file's `_doc` saying why. No code, sprite, archetype or other unit was changed.

I resolved all 72 profiles from the old file and from the new one and compared them field by field: **2 units
changed, 1 field each: `sway_px` 1 → 0 for `forest_witch` and `goblin_warlock`.** Breathing (`breath_px` 1,
`breath_sec` 2.8), movement (`lean_px` 1, `hop_px` 1, `anticipate`), landing (`land_squash_px` 1, `settle_sec`),
windup (`windup_lean_px` 1), hit (`hit_lean_px` 1) and every other unit are as before. The Ghost hover is still 2 px.

## Verification
Captured the same way as `review/` (windowed, muted, frozen match, fixed 1/60 s ticks, one Godot at a time). For a
controlled pair, both sides were filmed in the scratch worktree with the current `unit_layer.gd` / `unit_motion.gd`
copied in: **before** = the old `unit_motion.json`, **after** = the new one. The boss is placed on the first cell its
footprint fits, (6, 0), in every run (multi-cell bosses spawn on varying cells). A run from the real working tree gave
the same after numbers (Witch 611.7, Warlock 927.2 px per frame).

| Check | Forest Witch | Goblin Warlock |
|---|---|---|
| Idle poses, 6 s, before | lean ≠ 0 in 228 of 360 frames | lean ≠ 0 in 239 of 360 frames |
| Idle poses, 6 s, after | **lean 0 in all 360**: rest 168, breath (squash 1) 192 | **lean 0 in all 360**: rest 168, breath 192 |
| In-game seam stills (distinct idle poses reached) | after: only `0 0 0 0` and `0 0 0 1` | after: only `0 0 0 0` and `0 0 0 1` |
| Breathing still visible | yes, 1 px dip in 53 % of idle frames | yes, the same |
| Idle art px changed per 50 ms, before → after | 660 → 612 | 983 → 927 |
| Enemy step frames (anticipation, lean, landing squash, settle) | **identical** (14 frames) | **identical** (15 frames) |
| Hero rows in the same runs | identical | identical except 4 idle frames where the hero's breath flips at its threshold one frame apart (capture timing jitter: the clock runs in real time for the 120 frames before the freeze); the hero's profile did not change |

- **The 1 px idle lean discontinuity is gone** for both units. In idle the head band never moves sideways, so the
  hair, staff, hands, hat, ears and stone pack stay aligned. The only idle offset left is the breath: torso and head
  move down together, so there is **no jog at the chest split**.
- **Still there by design (preserved as asked):** a 1 px head lean during a **move** (about 0.15 s) and during a
  **windup / guard / howl** (`windup_lean_px` 1), so the seam can show during those moments. If it bothers you there,
  the data-only option is `lean_px` 0 and / or `windup_lean_px` 0 on these two ids.
- **Attack, hit and death:** the change only feeds `UnitMotion.idle_pose` (the `sway_px` term). The hit whiplash,
  windup coil, move and settle poses do not read `sway_px`, and dead / down / fall / cast poses are zero. The suites
  that cover them pass: `unit_motion_test` (37 checks, including hit interrupting a move and reduce motion),
  `unit_sprites_test` (clip table, death / down / hit / step clips), `unit_step_glide_test`, `witch_sprite_test`,
  `roster_sprite_test`, `cast_hold_short_clip_test`, `unit_status_overlay_test`: **all FAILS=0**.
- **Gameplay timing:** untouched (no code change; glide, step clip and cooldown values are the same).

## Lower-band pixel loss (landing squash and breath, unchanged values)
From the regenerated seam sheets (`seams/`; the same idle frame drawn in each pose). These are the legs-band art px at
and below the waist split that the squashed torso band covers:

| Unit | Squash 1 (breath, landing; the only squash these two ever reach) | Squash 2 (stress test; not reachable for casters) |
|---|---|---|
| Forest Witch (waist row 83, mid robe) | 25 of 76 opaque px in 1 row change | 82 of 155 px in 2 rows |
| Goblin Warlock (waist row 79, across the staff hand) | 40 of 90 opaque px in 1 row change | 101 of 177 px in 2 rows |

The covered row is not erased: the torso band's bottom row is drawn over it, so where the torso is transparent the
legs row still shows, and no gap opens. On the Warlock that row crosses the staff hand, so during a breath the hand
reads 1 px shorter for a moment. Squash values were kept as asked.

## Files (`production/qa/evidence/unit-motion/tuning-caster-sway/`)
- `compare/forest_witch_idle_1x.mp4`, `compare/goblin_warlock_idle_1x.mp4`: real screen 1:1, before | after,
  6 s idle. **Start here.**
- `compare/*_idle_4x.mp4`: the same at 4× art px. `compare/*_step_1x.mp4`, `*_step_4x.mp4`,
  `*_hero_step.png`, `*_enemy_step.png`: the steps (unchanged).
- `before/<id>/`, `after/<id>/`: frames, `context.png`, `motion.csv` (per-frame clip and pose); `after/<id>/seam_*`:
  the enemy alone at 8× on each distinct idle pose (rest and breath only now).
- `seams/forest_witch_seams.png`, `seams/goblin_warlock_seams.png`: the regenerated seam sheets. These are
  pose-generic (every pose drawn, including the leans the units no longer use in idle), so they match `review/seams/`.
