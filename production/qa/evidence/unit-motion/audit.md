# Unit motion pass — Stage A audit and plan (2026-11-13)

Scope: how the hero and the monsters animate in battle. Look and feel only: no combat math, hitbox, movement rule,
cooldown, AI or gameplay timing changes.

## 1. Current architecture

| Piece | File | What it does |
|---|---|---|
| Sheet loader | `src/art/sprite_sheet.gd` | Reads `assets/art/units/unit_<id>_sheet.json` (Aseprite array export from `art_src/units/<id>/clips.json`): one frameTag per clip, per-frame ms, `meta.tessera.loop` (loop / once / hold_last / hold), facing, optional `body_h`. Texture loaded lazily. |
| Clip clock | `src/art/unit_animator.gd` | Pure state machine: `play`, `play_timed` (frames share a given total), `seek`, `set_paused`, `tick(delta)`. No blending, no offsets: it only answers "which source rect". |
| Unit layer | `src/battle/unit_layer.gd` | One `UnitAnimator` per side (player, enemy). `_update_clip` picks the clip each tick through the pure priority `clip_for(ctx)`: fall > defeat/down > victory > hit (0.12 s) > cast > parry guard > phase_shift > stunned > guard/brace > howl > windup_heavy > windup > awaken > step > idle. Draws the frame with `draw_texture_rect_region` at the feet anchor in whole art px, mirrored by a negative width when the sheet faces away. |
| Cell-to-cell movement | `unit_layer.gd` `_track_step` / `slide_offset` | Gameplay moves the unit instantly (`CombatState` cell changes). The layer sees the new cell and glides the drawn feet from the old drawn feet with a cubic ease-out over `hit_feel.step_slide_sec` = 0.15 s (`assets/art/vfx/cast/index.json`), plus 4 dust grains. Shadow, overlays, HP plate and sprite all ride the same feet. |
| Step clip | `_update_clip` CLIP_STEP | Block-brain enemies: the 4-frame `step` clip is stretched over the mover's whole cooldown (`play_timed`). Heroes and the Forest Witch: directional `step_forward/back/up/down` at their own 50-100 ms frames, held on the last frame. |
| Hit feel | `_tick_flash_wait`, `shake_offset`, `recoil_offset` | White add-blend flash (child node), 2 px shake flipping every 30 ms, 3 px recoil decaying over 0.12 s. All whole-sprite offsets. |
| Tweens / procedural motion | — | **None.** No Tween, no AnimationPlayer, no per-unit procedural pose. Everything is per-tick timers on the layer. |

## 2. Why units feel stiff (root causes)

1. **Idle is a 4-frame, 1 s loop for 67 of 72 sheets** (`idle` 4 × 250 ms; heroes 8 × 125 ms). Every monster breathes at the same rate and the loop starts on the same frame when the match binds. Nothing distinguishes a golem from a wolf at rest.
2. **The sprite is one rigid rect.** Movement, shake and recoil all translate the whole frame. Nothing makes the head lead or trail the feet, so a move reads as "picture slides between cells".
3. **The glide has no arc, no anticipation and no landing.** A cubic ease-out (fast start, soft stop) is good for responsiveness, but the unit just stops: no settle, no weight on arrival.
4. **Block-brain `step` is stretched over the cooldown** (≈0.45 s+) while the glide is 0.15 s, so the legs keep cycling after the body has already arrived.
5. **No per-unit personality.** Every enemy uses the same slide time, the same (zero) lift, the same timings.
6. **Clip changes are hard cuts** (windup → idle, cast → idle): nothing marks the release of weight.

## 3. Hard constraint from the art bible

`design/art/art-bible.md` §8.10 forbids **odd-angle rotation, non-integer scaling ("even a 1.05× breath") and
half-pixel placement**, and §8.9 #7 requires that feet do not drift between frames. So the usual tools (rotate to
lean, scale to breathe, smooth sub-pixel tweens) are not allowed. Everything below is done in **whole art px only**:

- **Band shear**: the frame is drawn as 3 horizontal bands (legs / torso / head) from the same source rect. The
  torso and head bands may be offset by whole pixels. Head 1 px ahead of the torso reads as a lean; torso + head
  1 px down (overlapping the band below, never opening a gap) reads as a breath or a landing squash. The legs band
  never moves, so the feet stay pinned. No new pixels are painted; it is a mechanical draw-time edit.
- **Whole-body offsets** for the hop arc, the hover of flying units and a 1 px arrival overshoot.
- **Shadow narrowing** while a unit is lifted (the shadow is a computed stepped ellipse, so this is allowed).

## 4. Units affected

All 72 sheets in `assets/art/units/` (5 heroes, 67 enemies/bosses), and every enemy without a sheet keeps its
placeholder (no change). Clip inventory: 61 enemies have only the 5 block-brain clips (idle, step, windup, hit,
down); Forest Witch and Goblin Warlock add windup_heavy / phase_shift; Ancient Root Sentinel `stunned`, Mossbound
Sentry `brace`, Mistbriar Matron `guard`, Wolf Alpha `howl`. Heroes have draw, directional steps, cast clips,
victory, defeat, fall, awaken.

## 5. Reusable clips

- `idle` everywhere: kept, played at a per-profile speed (heavy slower, agile faster); procedural breath/sway on top.
- Hero / Witch `step_*` already contain a lean; the procedural lean for them stays small (data).
- `windup` (held) gets a procedural coil (head leans back, torso dips) so the attack has visible anticipation
  without touching the telegraph timing.
- `hit`: the existing recoil gets a head whiplash (head trails the body).

## 6. Files

| File | Change | Conflict? |
|---|---|---|
| `src/battle/unit_layer.gd` | Pose per side, band-shear draw, hop/settle/overshoot, idle speed, flash layer uses the same draw | **Clean** (no uncommitted change from any session) |
| `src/art/unit_motion.gd` (new) | Pure profile loader + pose math | New |
| `assets/art/units/unit_motion.json` (new) | Per-archetype profiles, unit id → archetype + overrides | New; not under `assets/data/` |
| `tests/unit/battle/unit_motion_test.gd` (new) | Pose math + layer integration | New |
| `tools/qa/unit_motion_footage.gd` (new) | Deterministic before/after capture | New |

Not touched: `src/combat/*`, `src/traits/*`, `src/run/*`, `assets/data/*` (other sessions' uncommitted work),
`unit_animator.gd`, `sprite_sheet.gd`, `assets/art/vfx/cast/index.json` (glide time and hit feel stay as they are).

## 7. Plan (Stage B order)

1. Idle: per-unit breath (torso+head 1 px dip on a per-profile period, phase hashed from the unit id so no two units
   are in sync), slow head sway for alert units, hover bob for flyers, per-profile idle clip speed.
2. Move: anticipation (head leans back in the first ~12 % of the glide), lean into the move, hop arc (per profile,
   0 for heavy), landing squash + settle (head follow-through, 1 px overshoot for agile units). The glide time and
   path of the drawn feet are unchanged, so the HP plate, the hit flash anchor and the tests stay put, and no
   gameplay delay is added: the cell still changes on the input frame.
3. Transitions: windup coil, hit whiplash, a short weight-release dip when an action clip returns to idle; dead /
   downed / victory / fall have no procedural pose at all.
4. Personality: archetypes hero, heavy, agile, caster, floaty, blob (+ per-hero overrides) in data.
5. Polish: pose is a pure function of per-side timers returned as a `Vector4i` (no allocation, no tweens); every
   higher-priority state simply overrides it the same tick; reduce motion turns it all off.

Limits known up front: no true rotation or squash-stretch (art bible), so lean and breath are 1–2 px band offsets;
idle frames cannot be added without new generations (not in scope; no PixelLab spend).
