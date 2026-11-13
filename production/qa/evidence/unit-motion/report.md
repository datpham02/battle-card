# Unit motion pass — verification report (2026-11-13)

Stage A audit and plan: [audit.md](audit.md). Nothing committed. No gameplay change: combat math, hitboxes, movement
rules, cooldowns, AI and gameplay timing are untouched. The cell still changes on the input frame. Only the drawing
follows it.

## Root causes (from the audit)
1. 67 of 72 sheets idle on the same 4 × 250 ms loop. All of them started together, at the same speed.
2. The sprite was drawn as one rigid rect, so every motion (glide, shake, recoil) moved a picture.
3. The glide had no arc, no anticipation and no landing. It used a cubic ease-out and then just stopped.
4. The block-brain `step` clip was stretched over the whole step cooldown (≈0.45 s+) while the glide lasts 0.15 s,
   so the legs kept walking in place after the unit arrived.
5. There was no per-unit difference and no transition between clips.

Art bible §8.10 rules out rotation, non-integer scale ("even a 1.05× breath") and half pixels. So everything here is
whole-pixel: **band shear** (the frame drawn as legs / torso / head bands from the same source rect; the head and
torso move by whole px, the legs never move, so the feet stay pinned) plus whole-body offsets and a narrower shadow.
No pixel is painted and no frame is invented.

## Files
| File | Change |
|---|---|
| `src/art/unit_motion.gd` (new) | `UnitMotion`: profile loader (default → archetype → unit overrides, per-unit phase from the id), pure poses: `idle_pose`, `move_pose`, `settle_pose`, `windup_pose`, `hit_pose`, `band_rows`; one-time body-height measure per sheet |
| `assets/art/units/unit_motion.json` (new) | 7 archetypes (default, hero, heavy, agile, caster, floaty, blob) and all 72 unit ids, with per-hero overrides |
| `src/battle/unit_layer.gd` | `unit_pose(side)` (the priority below), `_draw_frame_bands` (used by the sprite and the hit-flash layer), settle after the glide, weight-release dip, idle clip speed, per-profile glide time, the block-brain step legs timed to glide + settle, shadow narrows when lifted. The old per-frame `[_slide, _dust]` array is gone |
| `tests/unit/battle/unit_motion_test.gd` (new) | 37 checks: profiles, coverage, pose bounds, layer integration, interrupt, reduce motion, no object growth |
| `tools/qa/unit_motion_footage.gd`, `tools/qa/unit_motion_compare.sh` (new) | Deterministic capture (match frozen, units placed, 1/60 s fixed ticks, art-px crops tracking each unit at 4×), a pose log, an idle pixel-change metric, before/after videos and strips |

Not touched: `src/combat/*`, `src/traits/*`, `src/run/*`, `assets/data/*`, `unit_animator.gd`, `sprite_sheet.gd`,
`assets/art/vfx/cast/index.json`. No conflict with other sessions: `unit_layer.gd` had no uncommitted change from
anyone. To capture the "before" footage I put the committed `unit_layer.gd` back for the length of the capture and
restored my version right after (checked with `cmp` every time).

## What changed on screen
Pose = (body x, body y, head lean, squash), art px. Priority in `unit_pose`, highest first:
reduce motion / placeholder / dead / down / defeat / fall / victory / cast / awaken / parry / phase / stunned → **no
pose** (the authored clip alone) › hit → head whiplash › windup / guard / brace / howl → coil › gliding → move ›
settling → settle › idle (+ release dip). Every call reads the live state, so a hit or a death interrupts any pose on
the same tick.

1. **Idle**: a 1 px breath (2 px for blobs) on a per-profile period (1.5–3.2 s), with a phase taken from the unit id
   so no two units breathe together. A slow 1 px head sway for alert and caster units. A 1–2 px hover for units drawn
   in the air (ghosts, wisps, bats, cloud/frost sprites, veil, phoenix 1 px). The idle clip runs at 0.75× (heavy) to
   1.2× (agile).
2. **Move** (the hero's step, from the pose log):
   `f0 lean -1 squash 1` (crouch, head back) → `f1 lean +1` → `f2–7 lift 1, lean +1` (arc) → `f10–12 squash 1`
   (landing) → `f13+` settled. The drawn feet keep the old 0.15 s glide exactly (the HP plate and the tests follow
   them); only heavy (1.3×), agile (0.85×), floaty and blob glide times differ.
3. **Transitions**: the windup coils (head away from the foe, heavy units also dip 1 px), a hit whips the head back
   while the recoil runs, and an action clip handing back to idle gives a short weight-release dip. A block-brain
   step's legs now cycle over the glide + settle and then stand in idle, instead of walking in place for the rest of
   the cooldown. The logical clip is still `step` for the whole cooldown, as before.
4. **Personality** (enemy step timelines from the pose log):
   - Ogre King (heavy): `f0–2 lean back + squash` → `f3–11 lean in, no hop` → `f12–15 squash 2` → `f16–18 squash 1` → idle.
   - Slime / blob: `f0–1 crouch` → `f2–8 1 px hop` → `f11–13 squash 2` → `f14–19 squash 1` → idle.
   - Goblin (agile): 2 px hop, 2 px lean, 1 px overshoot, fast 1.5 s breath.
5. **Polish**: the pose is a `Vector4i` value from per-side float timers. There are no tweens and no new nodes. The
   band draw is 3 `draw_texture_rect_region` calls instead of 1, and only while a pose is non-zero. Body height is
   measured once per unit id. The test checks `OBJECT_COUNT` does not grow over 300 ticks. Reduce motion turns all
   of this off (and still snaps as before).

## Tests
- New `unit_motion_test`: **37 PASS, FAILS=0**.
- `tests/unit/battle/*` (19 suites, including unit_step_glide, unit_sprites, roster_sprite, witch_sprite,
  cast_hold_short_clip, cast_presentation, unit_status_overlay, unit_pass_order): all **FAILS=0**.
- `tests/integration/run/*` + `tests/unit/art/*` (55 suites): all **FAILS=0**.
- Not run: the full `unit/**` suite (other sessions' uncommitted combat work is in flux) and the windowed
  `integration/ui` click suites.

## Visual evidence (`footage/`)
Captured windowed with `--audio-driver Dummy`, before = the committed `unit_layer.gd`, after = this pass. Same arena,
same cells, the same fixed ticks:
- `footage/compare/<id>_idle.mp4`, `<id>_step.mp4`: before | after side by side, crops at 4×.
- `footage/compare/<id>_hero_step.png`, `<id>_enemy_step.png`: every 3rd frame of each step.
- `footage/{before,after}/<id>/motion.csv`: the per-frame clip and pose (after only).
- Idle art px changed per 50 ms frame (before → after): hero 190 → 202; Gale Bird 33 → 67; Slime 109 → 126; Ogre King
  112 → 105 (its idle loop is slower now, with a breath on top). Goblin Scout and Forest Witch were frozen mid-windup
  in this harness (their pattern brain stops wherever it was), so they show the windup coil, not the idle.

**Superseded by `review/` (see `review/README.md`)**: clean idle for every profile, 1:1 screen footage, seam sheets.
Not yet judged by eye at 1×: watch `review/compare/*_1x.mp4` and play one match. Feel cannot be
asserted by tests.

## Limits and suggestions
- **No true lean or squash-stretch.** The art bible forbids rotation and fractional scale, so lean is a 1–2 px band
  shear. At 1× on a phone that is subtle by design. If it reads too little, raise `lean_px` / `land_squash_px` per
  archetype in `unit_motion.json`. No code change is needed.
- **Band seams.** A 1 px head lean puts a 1 px jog in the outline at the chest line, and a squash hides 1–2 rows at
  the waist for a moment. On wide or tall bosses (Witch 160×130) the split is computed from the measured body height.
  Check the Witch and the Goblin Warlock by eye.
- **4-frame idles stay 4 frames.** More idle variety (blink, look-around) needs new frames, which means a PixelLab
  generation and the user's explicit yes per generation. Not done.
- **Heroes already lean in their dash clips**, so their procedural lean is kept at 1 px. Casts, awaken, victory and
  defeat play exactly as authored.
- **Archetype picks were made from ids and a contact sheet of the floaty units' idle frame.** Gale Bird, Storm Eagle,
  Harpy and Mirage Sprite stand on the ground, so they are agile (no hover). The other 60-odd picks were not checked
  sprite by sprite. Fixing one is a one-line data edit.
- Multi-enemy formations: the layer still draws one enemy side. When the Multi-Enemy session adds more units, each
  needs its own entry in the per-side tables (motion, settle, release).
