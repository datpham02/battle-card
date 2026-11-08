# Skill v2 — Trảm Địa polish pass report

**Date:** 2026-11-08 · **Status:** polish validated in the real battle scene · nothing committed · no PixelLab call.

**Unchanged from the prototype (`04-tram-dia-report.md`):**
- Gameplay rules: damage, cooldown, surge order and timing, hit limits.
- The resolver.
- The Mage work.

## 1. Visual improvements

| Area | Before | Now |
|---|---|---|
| Primary impact | the shared big steel burst + a flat shock ring | **steel eruption** standing up on screen from the burst tile (`CastFloorFx.eruption_rects`, drawn unmapped over the tile's drawn centre): a white collision flash across the tile (0–0.05 s), a stepped column of steel squares shooting 1.4 cells up and thinning (0–0.14 s), 16 shards thrown up and out, falling back under gravity and shrinking (until 0.5 s); plus the pack burst, the big stamp and the double shock ring |
| Propagation | crack + small burst per cell | an **incoming steel front** (`CastFloorFx.front_rects`, 4 stepped squares with a lit head) travels from the cell the surge came from into the next cell, timed on the **arbiter clock** so it arrives exactly when that cell's authoritative event fires; then the small burst, the directional crack, shards and the fading stamp |
| Topology | — | the fronts follow the real BFS parents: a line advances as one slash; an L turns at its corner; T and plus split at the junction (several fronts leave the same cell together); a separate region gets its landing with no front from another region |
| Targeting feedback | none | **tile-exact preview** (`CastFloorFx.preview_rects`, steel, no red): the landing cell gets four corner squares and a centre square, each surge cell a small chevron pointing its propagation direction, a locked cell inside the Block a dim X. It shows while the card menu offers an available Trảm Địa, and during the Knight's wind-up, where the board is not covered by the menu |
| Cast gesture | upward cut | unchanged art. The release stays synchronised: the coil is held through the telegraph, the slash frame comes 0.03 s before launch, and the wave lands on the burst event. A **`cast_forward` spec** is written (`design/assets/specs/swordsman-cast-forward.md`); nothing generated |

## 2. Gameplay-adjacent changes

- **Boss awareness** (`BossBrain`, `BossController.pending_threat_fn`, `SwingArbiter.pending_cells`):
  - **What changes:** after the swing resolves, the surge cells still pending on the clock stay "incoming", with the
    real time left. The boss keeps avoiding cells it **already saw** during the Knight's swing, after its normal
    reaction time.
  - **What does not:**
    - Cells it never saw are not revealed.
    - Without a pending surge, nothing changes.
    - The sim (`tools/balance/sim_core.gd`) is wired the same way.
- **Reward pool** (approved Phase 2 Q3: "Hero cards only in their hero's rewards"):
  - Trảm Địa has `hero_reward: true`. `RewardRoller.roll(..., hero_id)` offers a hero's own `hero_reward` cards in
    that hero's node rewards, at their rarity (rare).
  - Other heroes, the block-brain boss and the shop / event pools never get it.
  - `do_kiem` (starter card, no flag) stays out of all pools.
  - Starter decks are unchanged.
  - `--demo=tram_live` is unchanged.

## 3. Files changed in this pass

| File | Change |
|---|---|
| `src/art/cast_floor_fx.gd` | `eruption_rects`, `front_rects`, `preview_rects` (pure) |
| `src/battle/overlay_layer.gd` | `_front_items`, `_preview_items`, `eruption_items` + its unmapped draw |
| `src/combat/combat_view.gd` | `_on_cast_scheduled`, `get_surge_fronts` (arbiter clock), `get_surge_preview` (menu + wind-up), boss pending-threat wiring |
| `src/combat/swing_arbiter.gd` | `pending_cells(side)` |
| `src/combat/boss_brain.gd` | pending surge cells the boss saw stay incoming (`_seen_cells`), time left from the schedule |
| `src/combat/boss_controller.gd` | `pending_threat_fn` → ctx `pending_threat` |
| `tools/balance/sim_core.gd` | same wiring as the game |
| `src/run/reward_roller.gd`, `src/run/game_flow.gd` | `hero_id` in `roll`; node rewards pass the run's hero |
| `src/combat/skill_config.gd`, `assets/data/cards.json` | `hero_reward` field; `tram_dia` flagged |
| `tools/qa/contact_sheet.gd` | new QA tool: consecutive movie frames → contact sheet (nearest, `half` = native 640×360) |
| `design/assets/specs/swordsman-cast-forward.md` | future clip spec (not generated) |
| tests | `tram_dia_test` (+15 checks: eruption, front, preview), `boss_surge_awareness_test` (new, 7), `hero_card_pool_test` (+4) |

## 4. Tests

| Check | Result |
|---|---|
| Full suite (after the final change) | **207 / 207 files green, 0 script errors** |
| `tram_dia_test` | pass: 66 prototype checks + 15 polish checks (eruption, front, preview) |
| `boss_surge_awareness_test` (new) | 7 / 7 |
| `hero_card_pool_test` | pass: Knight offered Trảm Địa 152 / 1500 rolls; other heroes 0; `do_kiem` 0 |
| Golden 640 legacy cases | pass, fixture untouched |
| Deterministic sim (`deck_sim --seeds=5 --chapters=0`) vs B1.5 before Trảm Địa | **identical** apart from the runtime line. One run showed Assassin dmg/match 370.6 vs 370.7; a rerun of the same code gave 370.7, so that is run-to-run noise in the sim, not a change |
| Bot matrix, Knight × 6 matches | 5 wins, 1 timeup (Matron, as before), 0 violations, 0 script errors |

- **Mutation check:** the boss awareness test fails with the pending read removed (watched), and passes again once
  restored.
- **Golden:** the 640 legacy cases run against an untouched fixture.

## 5. In-game evidence (`production/qa/evidence/skill-v2-tram-dia-polish/`)

**Setup:** every sequence uses one fixed encounter (`--seed=1 --match=1 --arena=rect`: Goblin Scout, 4×3 halves)
and the deterministic demo. Each sequence is continuous: Godot movie writer, 60 fps fixed, every 3rd frame on the
sheets.

| File | Content |
|---|---|
| `straight_bar4-sheet.png` | wind-up with preview → slash release → wave travel → collision flash → eruption → shards → surge fronts cell by cell → HIT −28 on the boss (step 1 ×1.15) → cleanup |
| `l_shape_l4-sheet.png`, `branch_t4-sheet.png`, `cross_plus5-sheet.png` | the turn at the corner; the split at the junction (plus: centre, then three arms at once, HIT −30) |
| `native640_bar4-sheet.png`, `native640_plus5-sheet.png` | the same frames at native 640×360 (nearest 0.5× of the 2× capture = the game's own pixels) |
| `tram_dia_bar4.avi` | continuous 2.25 s gameplay recording (Godot movie writer, MJPEG, 1280×720) |
| `preview_swing_plus5.png`, `preview_swing_l4_locked.png`, `preview_menu_bar4.png` | targeting preview during the wind-up (landing corners, direction chevrons, the cracking cell blocked); with the menu open |
| `*.events.txt` | the authoritative event log of each sequence (clock, cell, kind, step, mult, hit, damage) |

## 6. Remaining visual limitations

1. The eruption is code-drawn steel squares. It reads as the heaviest beat, but it has no hand-drawn silhouette (no
   blade shapes, no light bloom). The shared big steel burst pack is still under it.
2. **The menu covers most of the board.** The preview shown while choosing is mostly hidden behind the cards; the
   wind-up preview carries the readable telegraph. A menu-time preview needs a UI layout change (out of scope).
3. The cast pose is still the upward cut (spec ready).
4. Preview chevrons are 2 px squares: subtle at 1×, by design. On a crowded board they can sit under the boss sprite.
5. The formation map's gold rings (`engraving_lit`, an existing feature) light the cast cells after every Knight
   cast. They overlap the fading stamps in the last frames.
6. No phone check yet (captures are desktop 2× and native 1×).

## 7. Production readiness

**Gameplay, timing, feedback and access are production-ready:**
- authoritative events with full tests;
- boss awareness without unfair knowledge;
- the Knight-only reward pool;
- the preview.

**Visuals are a solid shippable placeholder, not final art:** every beat reads in the real game at 1× and 2×. The
centrepiece eruption and the cast pose would benefit from dedicated art.

## 8. Assets that genuinely need PixelLab (each needs your yes, nothing generated)

1. **`tram_dia_eruption`** (`vfx_workbench` or `create_image_pro_flash` frames): 6–8 frames, 1 cell wide ×
   1.5 cells tall, a steel blade-shaped eruption with stepped shards; it would replace the code column (keeping the
   code flash and shards).
2. **Knight `cast_forward`**: 1 PixMiniMax gen per `design/assets/specs/swordsman-cast-forward.md`.

Not needed: the fronts, cracks, preview and shockwave stay code-drawn (square-only house style, testable).
