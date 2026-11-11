# Skill v2 V1 — per-card impact forms (ImpactFx)

**Date:** 2026-11-10 · **Plan:** `16-animation-audit-and-plan.md` §4 step 1 · **User decisions:** VFX and mechanics
run in parallel (this session VFX, `skills-batch1` mechanics); the contact sheet was approved; the 4 touched files
were approved one by one. **Not committed.**

## What changed

Before: `CastFloorFx.impact_rects` drew ONE shape per impact type, so the 8 freeze cards all ended in the same five
pale squares. Now each card may name an **ImpactFx form** (19 forms in 6 families) plus knobs; a card without one
keeps the old shards, so nothing else moved.

| File | Change |
|---|---|
| `src/art/impact_fx.gd` (new) | pure, deterministic forms: freeze `frame` `cross` `spike` `cluster`; slash `arc_h` `arc_v` `cross_x` `double` `stab4`; shatter `crack` `chunks` `shards`; knockback `column` `wedge` `slam`; thorns `spikes` `bubbles`; burst `ring` `ring2`. Every rect is clipped to the cell + 1 px edge (art bible §3). Reduce motion = one still frame for 0.15 s (`REDUCE_U_BY_FORM`). |
| `assets/art/vfx/cast/index.json` | `impact_variants`: 27 cards → form + knobs (`sparse`, `diag`, `drops`, `tilt`, `count`, `size`, `web`, `vine`). |
| `src/art/cast_vfx.gd` | `impact_variant(skill_id)`: the entry, or `{}` for none / an unknown form. |
| `src/battle/overlay_layer.gd` | the player's hit cells draw `ImpactFx.items(...)` when the card has a variant, else `CastFloorFx.impact_rects`. Colours and `sec` still come from `impact_style`. The boss keeps the old shards. |
| `src/combat/combat_view.gd` | 1 line: the recorded cast (`_cast_travel`) carries `skill_id`, so the overlay knows the card after the resolve. |
| `tests/unit/art/impact_fx_test.gd` (new) | every form: empty outside [0, sec), deterministic, inside the cell, draws, flips with direction, reduce-motion hold; `form_of`; knobs change the picture. |
| `tools/qa/impact_contact_sheet.gd` (new) | renders all variants × 5 moments + reduce frame (headless, Image ops). |
| `tools/qa/impact_footage.gd` (new) | casts a card list in a real ch1 battle and saves the frames while the impact draws. |

## Density pass (2026-11-11, user: "hiệu ứng thì đang quá ít")

The first pass was a few 2–3 px squares per cell. Every form is now three layers sized from the cell: the **hit
burst** (a 6 px pop and 10 shards flying to the cell edge over the first third), the **form** itself at 1.5–2× (4 px
streaks with a shadow line, 3 px crosses with caps and secondary arms, ice columns with side shards, two push columns
of five, 5-line 2 px cracks, two-ring bursts of 18, five spikes / bubbles) and the **residue** (six dust squares
settling over the last part). Each variant carries `sec: 0.5` in the index, which replaces the type's `impact_style`
sec for that card (the art bible's ≤ 0.35 s is overridden on the user's call), and `OverlayLayer.TRAVEL_TAIL_SEC`
went 0.4 → 0.55 so the recorded cast outlives the last cell's impact. `no_burst: true` on a variant drops the burst
layer (unused so far).

## Standing layer (2026-11-11, user: "hiệu ứng phải trông như dựng từ mặt đất lên", the camera is a low top-down)

Flat shapes mapped onto the slab were foreshortened into the floor, so every form is now two layers on the same
arrival clock:
- **flat** (`ImpactFx.items`, cell art px through the board map): the full-cell hit sheet, ice frame, frost cross,
  cracks, shock ring, push wedge, burst ring, the vine, and the dust residue;
- **standing** (`ImpactFx.standing_items`, screen art px over the tile's drawn ground centre, unmapped like
  `FuseFx.eruption_items` and the Ngàn Kiếm blades): the shards thrown up by the hit, ice columns and crystals,
  sword streaks in the vertical plane, thorns, bubbles, push walls, flying chunks. Heights are fractions of the
  drawn cell width (`COLUMN_CELLS` 1.0), so a Hàn Trận column stands a full tile tall.
`OverlayLayer.impact_standing_items()` builds the standing list for the player's resolved cast (same pack-ownership
rule as the flat path) and `_draw_groups` draws it after the Hỏa Lôi columns, back rows first, Ink edges per group.
The user also asked for 80–100 % cell coverage: flat shapes reach the cell edges and standing shapes span the
tile's width. A checkerboard ground tint was tried and rejected (it read as a dotted grid); it stays as the opt-in
knob `tint: true`.

## V2 — hero cast glyphs (2026-11-11, approved to start: "Làm V2 glyph")

`src/art/cast_glyph_fx.gd` (new): one kit per hero at the casting hand while any `cast_gesture` swing runs, in the
hero's block colours, 23 px, no box behind it: Knight `sigil` (steel frame, corner studs lock in, core), Mage `runes`
(three flame runes lighting bottom-up, embers), Assassin `daggers` (two jade strokes crossing, tips flash), Hunter
`leaf` (stepped jade leaf from a stem, three seeds), Cleric `halo` (ivory square halo from a core, second ring).
Timeline on the CutActor clock: draw-in 0–0.6, pulse 0.6–0.85, flare ring ≥ 0.85 (none under reduce motion).
- `assets/art/vfx/cast/index.json` `cast_glyphs`: form + `hand` (art px from the feet on the hold frame, measured
  from each sheet's `cast_gesture` frame 4 and placed beside the raised hand, off the face).
- `CastVfx.cast_glyph(hero)`; `OverlayLayer.fuse_items` draws it (group -1) for every cast whose card has no
  `card_casts` clip and no `glyph` of its own, so Trảm Địa, Ngàn Kiếm and Hỏa Lôi keep their choreography.
- `tests/unit/art/cast_glyph_fx_test.gd`; review sheet `tools/qa/glyph_contact_sheet.gd` →
  `production/qa/evidence/skill-v2-cast-glyphs/glyph_contact_sheet_x3.png` (each hero's real hold frame + glyph at
  k 0.15 / 0.4 / 0.7 / 0.9 + reduce).

## V3 — delivery upgrades (2026-11-11, approved to start: "lam v3 di")

`src/art/delivery_fx.gd` (new): the travel of every generic card, in the same flat + standing layers, on
`SkillDelivery.arrival_times`:
- **sky** (`falling_squares`, 9 cards): flat target square closing in on the cell over the last 0.3 s; standing
  element block (9 px core, trail of three, two sparks) falling from 1.4 H onto the tile over `fall_sec`.
- **ground** (`floor_run`, 9 cards): flat ripple front — five slabs along the path with a two-row wedge each side,
  the Trảm Địa front idea; standing dust squares hopping up behind the front.
- **chain** (`chain_spark`, 6 cards): the hop is now a standing bolt (8 px head, tail of seven, two sparks) arcing
  link to link at 0.45 H; the old flat hop square is gone.
- **projectile** (`square_streak`, the boss's straight shot): 8 px head, tail of three, two side sparks (the
  player's projectiles stay on the hero cast packs).
- **in place** (`travel none`, 7 cards): flat gather — eight squares converging on each cell over the last 0.2 s
  before it manifests — and three standing squares dropping in from 0.6 H.
Wiring: `OverlayLayer._side_items` draws the flat parts (replacing `fall_rects` / `run_rects` / the hop square),
`delivery_standing_items()` the standing parts (player side; hero_pack and square_streak casts excluded), drawn by
`_draw_groups` before the impact's standing layer. Tests: `tests/unit/art/delivery_fx_test.gd`. Review sheet:
`tools/qa/delivery_contact_sheet.gd` → `production/qa/evidence/skill-v2-delivery/delivery_contact_sheet_x3.png`;
in-game strips `<card>_travel_ingame.png` (kiem_vu sky, xung_kich ground, bang_chau chain; the gather of bang_phong
runs in the last 0.2 s of the swing, which the footage tool's swing sampling did not reach — seen on the sheet only).

## V4 — feel pass (2026-11-11, user: "skill nó hơi đơn giản", approved A + B + C)

**A. Hit feel** (`CastVfx.hit_feel`, new keys in `index.json`, all data-driven, 0 disables):
- `hit_stop_sec` 0.06: when the player's cast lands on the boss (damage > 0), `CombatView` holds the whole
  simulation for that much REAL time at the cast's first arrival (`_hit_stop_at`, `_hit_stop_left`); the floor VFX
  clock pauses with it (`scaled_delta`), so nothing scheduled shifts relative to anything else. `is_hit_stopped()`.
- `board_shake_px` 2 / `board_shake_sec` 0.14: a visual-only board shake (`hit_shake_offset`, applied by
  `BattleCanvas` like the Ngàn Kiếm finale shake; zero under reduce motion).
- `recoil_px` 3 / `recoil_sec` 0.12: the hit unit is nudged away from the blow (the boss right, the hero left),
  decaying, on top of its white flash and side-to-side shake (`UnitLayer.recoil_offset`).

**B. Four tones** instead of two: every ImpactFx / DeliveryFx item carries `tone` 0–3 (dark = body darkened 38 %,
body, highlight, core #F8FBFF). `OverlayLayer.tone_colour` maps it. Cores show only in the first tenth of a clip
(the hit sheet is core-white for `SHEET_END`, streak and sky-block heads carry a core); low parts (the bottom quarter
of a flat cell, the bottom layers of standing shapes) go dark, so columns, frames and streaks have a shaded base.

**C. Aftermath** (`ImpactFx.aftermath_items`, `after_sec` 1.0 on every variant, `TRAVEL_TAIL_SEC` 0.55 → 1.6):
after the impact clip the cell keeps a flat, dark trace that thins in its last third — rime frame and lying shards
(freeze), the cracks (shatter), a scar line (slash), settling chips (knockback, burst), stumps (thorns), drops
(poison). Tones 0–1 only, never brighter than the body colour.

Evidence: `production/qa/evidence/skill-v2-feel-pass/` — `<card>_before.png` (the committed V1 strips) and
`<card>_after.png` (8 frames over 1.4 s, so the aftermath is in the last three). Tests: `impact_fx_test` (tones,
core timing, aftermath), `delivery_fx_test`, the flow tests of Hỏa Lôi / Ngàn Kiếm / Mìn Trễ (hit-stop leaves their
clock-relative timings intact).

## Card → form

| Family | Card | Form | Knobs |
|---|---|---|---|
| freeze | bang_phong · suong_mong | frame | suong_mong `sparse` (dashed 1 px frame) |
| | han_khi · han_phong · thanh_thuy | cross | han_phong `diag`; thanh_thuy `drops 3` |
| | han_kiem · han_tran | spike | han_kiem `tilt`; han_tran `count 2` |
| | bang_chau | cluster | |
| slash | thiet_kiem | arc_h | |
| | kiem_vu | arc_v | |
| | kiem_than | cross_x | |
| | dai_dao · song_kiem | double | song_kiem `size 2` |
| | tu_kiem | stab4 | |
| shatter | ran_kich · ran_van | crack | ran_van `web` |
| | han_bang | chunks | |
| | bang_tam | shards | |
| knockback | chan_phong · cuong_phong | column | cuong_phong `count 2` |
| | xung_kich | wedge | |
| | thien_lang | slam | |
| thorns / poison | tran_gai · gai_nguyen | spikes | gai_nguyen `vine` |
| | gai_doc | bubbles | |
| burst | kiem_khi · do_kiem | ring / ring2 | |

Burn cards keep their art pack. `vung_lay`, Trảm Địa, Ngàn Kiếm and Hỏa Lôi are untouched.

## Known limits

- **Hero cast packs own their impacts.** For the Knight (`square_wave_steel`) and the Mage (`fire_bolt_burn`), a
  CASTER_TO_TARGET `hero_pack` card (kiem_khi, thiet_kiem, kiem_than, han_kiem, do_kiem, dai_dao, song_kiem for the
  Knight) draws the pack's steel burst and skips the code impact (`packs_replace_shards`, 2026-11-02). Those variants
  show on the Assassin, Hunter and Cleric, whose default pack has no impact. Deciding whether the Knight's steel burst
  should give way to the per-card form is a separate call.
- The full-cell white flash (`flash_rects`) and the HIT label still sit over the impact; the forms are sized to the
  cell and read, but the flash is the loudest thing on the cell. Not changed here.
- pixelfx (`docs/research/pixelfx-study.md`) was rendered for reference (`production/qa/evidence/skill-v2-impact-families/pixelfx-picks/`):
  side-view, 130–300 px, 1–5 s, so it is a source of motion ideas for the big moments (ice-spikes, chain-lightning,
  lightning-strike, earth-spike, thorns, meteor / star-fall, flame-pillar, ground-slam), not sheets to paste.

## Evidence

`production/qa/evidence/skill-v2-impact-families/`:
- `contact_sheet_x3.png`, `contact_sheet_x1.png`, `part1-3_x3.png`: all 27 variants, 5 moments + reduce frame.
- `ingame/<card>_ingame_strip.png`: 10 cards cast by the Assassin in a real ch1 battle (bang_phong, han_tran,
  kiem_than, ran_van, xung_kich, thien_lang, gai_doc, bang_chau, han_khi, chan_phong), 7 frames across the 0.3 s.

## Tests

Full suite with V3 + V4 (+ batch 2) in the tree (2026-11-11): **256 suites, 255 green, 1 red** — the same
pre-existing `skill_v2_golden_test` mismatch (33 vs 32 instant cards from `vung_lay`).

- `tests/unit/art/*` (15 files) and the battle / combat tests touching CastVfx or the overlay: green.
- Full suite: see below.

Full suite with V1 + V2 + batch 1 in the tree (2026-11-11): **243 suites, 242 green, 1 red** — the golden
mismatch below. (The first pass of that run showed script errors in `trait_test` and four UI suites; all five were
re-run alone and came back clean, FAILS=0 and 0 script errors — a transient of other sessions editing files mid-run.)
Full suite after the standing layer (2026-11-11, V1 only; the UI suites now run with `--audio-driver Dummy`):
**242 suites, 241 green, 1 red** — the same golden mismatch.
Earlier run (2026-11-10, flat pass): **216 suites, 215 green, 1 red**:
`tests/unit/combat/skill_v2_golden_test.gd` FAILS=2 ("32 legacy (instant) player cards in card_order 33", "case count
640 vs 660"). Both are the pre-existing `vung_lay` golden mismatch from the earlier agent's uncommitted work (the
golden set does not know the 33rd card); not caused by this change and not touched here. The golden decision
(regenerate for `vung_lay` or drop the card) is pending with the user.
