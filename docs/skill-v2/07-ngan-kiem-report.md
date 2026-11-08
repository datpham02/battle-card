# Skill v2 — Ngàn Kiếm (ngan_kiem) report

**Date:** 2026-11-08 · **Status:** APPROVED by the user 2026-11-08 as a completed technical prototype (final
acceptance and Cast Commitment: `08-ngan-kiem-acceptance.md`). Sections below are the history of the work; the
PixelLab spend in total: 2 gens, `cast_overhead` v1 (job ac2cb023, later removed) and `cast_summon` (job 91224bb1,
accepted).

| Area | Status |
|---|---|
| GAMEPLAY | **COMPLETE** |
| VFX | **APPROVED** (2026-11-08: scale, overlap, boss readability, HUD safety; frozen) |
| CHARACTER ANIMATION | **ACCEPTED** (`cast_summon`, PixMiniMax job 91224bb1; see 08 acceptance; v1 `cast_overhead` of §11 retired) |
| AUTOMATED TESTS | **PASSED** (see §6) |
| REAL DEVICE QA | **PENDING** (Android) |

## 1. Completed gameplay (sections 1–5, unchanged except one confirmed bug fix)

- **Card data:** `ngan_kiem` is the Knight's epic card: min 4 cells, cooldown 10 s, 12 per hit (`fixed_hit`), max 3
  hits, hover 0.5 s, stagger 0.12 s, `from_centre` order.
  - Branched shapes: `shape_clause {branched, tips_first, centre_mult 1.5}`.
  - Awakening: `awakening_extra_hits` 1.
  - Pools: `hero_reward` (Knight rewards only, Q3); never in a starter deck or the boss's cards.
- **Schedule:** `CastResolver.sky_events`, one drop per open cell, each its own wave, at hover + i × stagger.
  - Order: the hub (ShapeTags centre, ties to the caster), then BFS outward inside its region; separate regions
    follow by distance to the hub (ties y, x).
  - Branched shapes: the hub is the junction (most neighbours) and the order is reversed, so the tips fall first and
    the centre falls last as `drop_final` ×1.5.
  - Locked cells get no drop.
- **Damage:**
  - Fixed per hit (`CutEffects`: damage_per_cell once, the signature cell rule skipped); relic, passive and signature
    hooks still see the cast's cells.
  - Defense applies per hit; one hit per drop; `max_hits` per cast (+1 with Awakening, read when the swing resolves).
  - The first damaging drop interrupts.
  - Card-level hooks (relics, signature, stats) run once, at the cast's end.
- **Boss awareness:** `SwingArbiter.pending_cells` and the BossBrain "seen cells" rule. This is the same mechanism as
  Trảm Địa, already covering sky drops: the boss reacts only to cells it saw during the swing, after its reaction time
  and step cooldown, using the real time left.
- **Confirmed bug fixed (2026-11-08, found in the in-game capture):**
  - **Symptom:** a pattern enemy's warning still hit the hero (−8) at the first blade's impact.
  - **Cause:** a scheduled cast called `PatternController.on_enemy_hit` only at the cast's END. This breaks the
    interruption policy (catalog M02: the first damaging event interrupts); it also delayed Trảm Địa by up to
    0.37 s.
  - **Fix:** a new `SwingArbiter.pattern_hit_fn` fires once per scheduled player cast at its first damaging,
    non-parried impact (not for parry cards). CombatView and the sim bind it, and skip the end-of-cast call for
    scheduled results; instant (legacy) casts are unchanged.
  - **Regression test:** `ngan_kiem_test` `test_pattern_interrupt_at_first_hit`, watched failing with the call
    removed.

## 2. New VFX architecture

`src/art/sky_drop_fx.gd` (`SkyDropFx`) is a reusable SKY_TO_TARGET presentation, pure and deterministic, made of
code-drawn squares. It is driven ONLY by the authoritative schedule:
- **Records:** `SkyDropFx.records_from_cast(cast_scheduled payload, t0)` gives one record per event: its cell, its
  `at` and `final`, in schedule order (nothing recomputed for visuals).
- **Phases on the arbiter clock:**
  - materialize (0.2 s: square fragments gather, then the sword assembles part by part);
  - hover (1 px tremble);
  - fall (the last 0.1 s, ease-in, stepped trail; the tip touches the ground EXACTLY at `at`);
  - embedded (0.35 s, tip sunk 8 px, cracks at the end);
  - shatter (0.25 s, square fragments fall and vanish).
- **Ground impact:** at `at`, a white flash cross, square shards and a flat shock.
- **Floor telegraph:** a tile-exact square shadow (inset 1/6) from the swing end to `at`, darkening (alpha 0.18 →
  0.62). It is drawn through the board map.
- **Summoning (stage A):** steel squares rise around the Knight's hand while a SKY_TO_TARGET swing winds up, with a
  bright point near the release.
- **Finale:** `drop_final` is drawn ×1.3 with the bright steel ramp, a ×1.4 flash and more shards.
- **Cleanup:**
  - `drops_now` hides the pending blades of a cast the arbiter dropped (`SwingArbiter.has_cast`: death, match end);
    landed blades finish.
  - CombatView prunes finished records.
  - Nothing is a node; everything is drawn per frame from data.
- **Reduce motion:** no tremble, no trail, fewer gather squares.
- **Wiring:**
  - `CombatView`: `_on_cast_scheduled` → `_sky_plan`; `get_sky_drops`; `combat_clock`.
  - Sky impacts only play the floor stamp pack (small; big for the finale). Hit feedback (HIT / number) still comes
    from `impact_resolved`, so it shows only on a real hit.
  - `OverlayLayer`: `_sky_shadow_items` (floor, mapped) and `sky_items` (screen space, Ink edge).
- **Reuse:** Thiên Thạch, Thiên Quang and Tuyết rơi can pass their own shape builder (`blade_rects` is the sword
  one) and colours. The phases, shadow, timing, cleanup and impact are generic.
- **Distinct from Trảm Địa:** no eruption pack, no projectile, no surge fronts. Swords stand above their own tiles
  and fall one by one.

## 3. Character animation

- **ART PENDING.** Ngàn Kiếm casts with `cast_gesture` (its coil holds the sword raised). This is acceptable as a
  fallback but is not the requested summoning gesture.
- The spec and the exact PixelLab call A are in `design/assets/specs/swordsman-cast-overhead.md`:
  - `animate_image_pixminimax` on `art_src/units/kiem_si/cast_gesture/0.png`, first and last frame pinned;
  - 8 frames, south-east, low top-down, seed 1;
  - **≤ 1 generation**;
  - integrated like `cast_forward` through `card_casts.ngan_kiem.clip`.

## 4. Free assets

- No new image files. Everything is code (`SkyDropFx`) plus the existing floor stamp packs.
- The sword silhouette (blade + fuller + edge, a guard wider than the blade, hilt, pommel; tip down) reads as a sword
  at 2× and stays recognizable at native 640×360.
- Size follows `docs/art/vfx-scale-impact-guide.md` (§9 below): the sword is ~58 px (1.35 tile heights).

## 5. Evidence (`production/qa/evidence/skill-v2-ngan-kiem/sequences/`)

- **Capture setup:** deterministic, one battle per sequence (seed 1, Goblin Scout, `rect` arena, `--no-autopause`,
  60 fps fixed); every 4th frame on the sheets.
- **Scenarios:** straight `bar4`, L `l4`, T `t4`, Plus `plus5`, moving boss (`--tram-move=1,0`: 2 hits on 2
  different drops) and a 2×2 boss (`--pattern=dev_pattern_boss`: hit once per drop under it).
- **Files per scenario:**
  - `<name>-2x-sheet.png` (desktop 2×);
  - `<name>-native640-sheet.png` (nearest 0.5× = the game's own pixels);
  - `<name>.events.txt` (the authoritative events: clock, cell, kind, hit, damage).
- **Video:** `ngan_kiem_plus5.avi`, a continuous 3.4 s gameplay recording (Godot movie writer). It is kept local, not
  committed, like the Trảm Địa AVIs.
- **Reproduce:**

  ```bash
  godot --path . --fixed-fps 60 -- --character=kiem_si --seed=1 --match=1 --arena=rect --demo=tram_live --no-autopause --live-card=ngan_kiem --tram-shape=plus5
  ```

## 6. Tests

| Test | Result |
|---|---|
| `tests/unit/combat/ngan_kiem_test.gd` | pass: 14 groups (data, cells / cooldown, count / timing, order, branched, fixed damage / cap, Awakening, moving, 2×2, locked, defense, interruption / cleanup, determinism, pattern interrupt) |
| `tests/unit/art/sky_drop_fx_test.gd` (new) | pass: mapping from the real schedule, impact timing, phases, tile-exact shadow, silhouette, finale, cleanup after a dropped cast, nothing lingering, no damage from drawing |
| Mutation checks | fixed-hit off + tips-first off → 11 fails; impact 0.02 s early → 1 fail; pattern hook removed → 1 fail (all restored) |
| Full suite (after the final change) | **209 / 209 files green, 0 script errors**: golden 640 unchanged; Trảm Địa, boss awareness and hero reward pass |
| Deterministic sim (`deck_sim --seeds=5 --chapters=0`) vs B1.5 | **identical** (0 diff lines; no deck holds a Skill v2 card yet) |

**In-game HP check after the bug fix:**
- **Hero untouched (200 / 200):** straight and moving-boss captures. Their first blade hits at clock 1.70 and breaks
  the Goblin Scout's warning in time.
- **Hero at 192 / 200:** the Plus and 2×2 captures. Their first damaging blade lands at 2.43 / 2.06, AFTER the
  goblin's warning resolves (1.70). That is correct play under the interruption policy (nothing had hit it yet), not
  a bug.

## 7. Remaining issues

1. Character animation: `cast_overhead` generated and integrated (§11), awaiting approval.
2. Sword size fixed by the scale upgrade (§9). A hand-drawn blade would still read better: optional PixelLab B.
3. Swords start materializing at the swing END (the authoritative schedule exists from then). The tile shadows give
   the boss 0.5 s before the first drop, and the mask itself is highlighted during the whole swing.
4. The hovering centre sword overlaps the boss sprite on its cell (by design: it falls on the boss).
5. The formation map's gold rings (an existing feature) light the cast cells after every Knight cast.
6. No phone check yet.

## 8. PixelLab plans (each needs your explicit approval; nothing generated)

- **A. Knight `cast_overhead`:** see `design/assets/specs/swordsman-cast-overhead.md`; ≤ 1 generation.
- **B. `ngan_kiem_spectral_blade` (optional):** only if the code sword is judged too plain.
  - Tool: `create_image_pro_flash`, 32×48 (5 generations, the Pro Flash ladder up to 96 px).
  - Style reference: the Knight's sword pixels.
  - Prompt: "a single spectral steel sword pointing straight down, straight blade with a pointed tip, small
    crossguard, short hilt and round pommel, pale glowing steel-blue edges, crisp pixel art, transparent background".
  - Palette: the steel ramp.
  - Use: `SkyDropFx` would draw it instead of `blade_rects`, with the same anchor (tip).

## 9. VFX scale upgrade (2026-11-08, free art, gameplay unchanged)

Sized against the measured tile (60 × 43 px at 640×360) and the Knight (64 px); see
`docs/art/vfx-scale-impact-guide.md`.

| Setting (`SkyDropFx`) | Before | **Recommended final** | Ratio |
|---|---|---|---|
| `BLADE_LEN` (+ guard 3, grip 9, pommel 4) | 16 | **40** | sword 58 px = 1.35 H |
| `BLADE_HALF_W` / `GUARD_W` | 1 / (derived) | **3 / 19** | |
| `HOVER_TIP_PX` | 12 | **24** | tip hovers ≤ 1 H above its tile |
| `SINK_PX` | 4 | **8** | |
| `FINAL_SCALE` | 1.25 | **1.3** | finale +30 % |
| `IMPACT_HALF_W` (finale ×1.4) | (impact ~15 px wide) | **26** | impact 0.85 W, finale +35 % |
| `SHARD_PX` | (fixed 2–3) | **4** | |

- Drops are drawn back rows first, so nearer swords overlap farther ones.
- Schedule, damage, cells and hit caps unchanged; `sky_drop_fx_test` `test_scale_targets` pins the ratios.
- Evidence: `production/qa/evidence/skill-v2-ngan-kiem/scale-upgrade/plus5_before_after_2x.png` and
  `plus5_before_after_native640.png`. The `sequences/` sheets predate the upgrade.

**Open visual points at §9 (fixed in §10):**
1. In a Plus, the top-row sword's hilt overlaps the centre sword's blade during the hover (both on screen ~0.3 s).
2. The finale sword covers the boss sprite on its cell while hovering (it falls on the boss by design).
3. The finale pommel on the top row reaches close to the HUD band.

## 10. Visual scale finalization (2026-11-08, free art, gameplay unchanged)

The §9 sizes are the approved baseline and are kept. This pass fixes overlap, enemy visibility and HUD safety, and
strengthens the finale, without shrinking the swords.

**Final dimensions (art px at 640×360; a tile is ~60 × 43):**

| Element | Size | Tile ratio |
|---|---|---|
| Regular sword | 56 px tip to pommel, guard 19 wide (58 × 21 with the 1 px Ink edge) | 1.35 H |
| Finale sword | 73 px, guard 25 wide (77 × 29 with its 2 px Ink edge) | 1.75 H (+30 %) |
| Ground impact (flash) | 53 px at its first frame, 51 a frame later | 0.85–0.9 W |
| Finale impact | 73 px wide, 16 shards, 2 shock rings | +38 % |
| Hover (tip above its tile) | 24 px (finale 31); 50 px over the enemy | ≤ 1.2 H |

**Visual-only layout (`SkyDropFx.layout_dx`, `hover_px`, `blade_alpha`; the target cells and times are untouched):**
- **Stacked swords:** of two drops in one column on neighbouring rows, the BACK one hovers 18 px to the side (26 px
  when the one in front is the finale or a sword lifted over the enemy). The finale stays centred; the sword in front
  of it moves instead. A column of three alternates right / left. The offset slides home during the fall, so the tip
  lands on the tile centre exactly at `at`.
- **Enemy visibility:** a drop on a cell the enemy covered at the swing end hovers 50 px up, above a Goblin Scout's
  head (46 px), and is see-through (alpha 0.7) until it falls. If the enemy steps under a sword later, that sword turns
  see-through too.
- **HUD safety:** every hover is capped so the pommel stays at or below y 18 (the HUD title band ends at ~y 12).
  Upward fragments and the fall trail are capped at the same line.

**Finale emphasis (not only size):**
- Assembly: 14 gathering squares from 1.5× farther, then a white forge flash on the finished sword.
- Silhouette: 2 px Ink edge, bright steel ramp.
- Fall: 0.07 s with a cubic ease-in (normal drops 0.1 s, quadratic), a longer trail; same contact time.
- Contact: +40 % flash, 16 shards in two distances thrown higher, two shock rings.
- Board shake: 2 px side to side for 0.12 s at contact. It moves the foundation, floor, pickups, units and overlay
  (`BattleCanvas.set_board_offset`); the far backdrop and the HUD stay still. It is off under reduce motion and never
  touches the combat clock.

**Motion stages, each visible at native 640×360 in the sheets:** fragments gather above the tile → complete sword
hovers → tile-exact shadow darkens → each sword accelerates down on its own → the tip touches the tile → embedded
sword with cracks → square shatter → nothing left.

**Evidence (`production/qa/evidence/skill-v2-ngan-kiem/scale-final/`):**
- `plus5_before_baseline_final_native640.png`: three labelled rows, same capture, same frames:
  - BEFORE OLD = the pre-upgrade SkyDropFx, recovered from the session history; it reproduces the original "before"
    frames byte for byte;
  - BASELINE V1 = the approved §9 scale;
  - FINAL = this pass.
- `<shape>_before_after_native640.png` and `<shape>_before_after_2x.png` for plus5, t4, bar4 and l4: BEFORE OLD vs
  AFTER FINAL. Each column is labelled with its frame number and time.
- `ngan_kiem_final_<shape>.avi`: continuous 3.5 s gameplay recordings (about 27 MB each, kept local, not committed).
- The older `sequences/` and `scale-upgrade/` sheets predate this pass.
- Tool: `tools/qa/compare_sheet.gd` (labelled rows, built-in pixel font).

## 11. Knight `cast_overhead` clip (2026-11-08)

**Generation (user-approved, 1 generation, no retry):**
- `animate_image_pixminimax` job `ac2cb023-7fff-4722-b7c7-4b79bfb9e217`, using the exact call in
  `design/assets/specs/swordsman-cast-overhead.md` §3.
- First and last frame pinned to `cast_gesture/0` (guard); 8 frames; south-east; low top-down; seed 1.
- Raw output: `design/assets/candidates/swordsman/cast-overhead/raw/f0-f8.png`.

**Mechanical clean (no painting):**
- `tools/qa/sprite_clean.gd`: palette snap to the 7 sheet colours. It dropped 0 speck pixels, and no move was
  needed (the feet sit on x32–38, row 69, in all 9 raw frames).
- Row 0 cleared on f2–f3, 4 px each: the generated blade tip touched the frame top, and the exporter enforces art
  bible 8.3's 1 px margin.
- Output: `clean-96x70/`; the final slots are also kept as candidates at
  `swordsman/v3-tall/clean-96x70/cast_overhead/`.

**Slots (same 9 ms as `cast_gesture` / `cast_forward`):**

| Slot | 0 | 1 | 2 | 3 | 4 (held) | 5 (release) | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|---|
| Raw frame | f0 guard | f1 rise | f2 upright | f3 upright | f3 | f5 command | f6 hold | f7 return | f8 guard |

- Raw f4 (an in-between tilt) is dropped.
- Slot 4 is held during the swing telegraph. Slot 5 starts at the swing end, the moment the swords begin to
  materialize.

**Integration:**
- `art_src/units/kiem_si/cast_overhead/0–8.png` and its `clips.json` entry; `unit_kiem_si_sheet` re-exported
  (872×1064; only that sheet changed).
- `cast/index.json` `card_casts.ngan_kiem = {clip: cast_overhead, hand: [44, -9], charge_hand: [5, -64]}`:
  - `charge_hand` = the raised blade tip on the hold;
  - `hand` = the sword tip on the command frame.
- `UnitLayer.is_cast_clip` knows `cast_overhead`.
- `OverlayLayer.sky_items`: the summoning squares gather at `charge_hand` when the card has one (Ngàn Kiếm is the
  only SKY_TO_TARGET card).
- Every other Knight card keeps its clip: Trảm Địa `cast_forward`, the rest `cast_gesture`.

**Measured:**
- Feet x32–38 on row 69 in all 9 slots: no slide, no bob.
- 7 colours, 0 off-palette.
- Navy cape with gold trim; no gold drift.

**In battle:**
- The authoritative events are identical to the `cast_gesture` capture (plus5 and bar4 event logs diff to nothing).
- The command pose starts on the same frame as the old release, at the swing end. The first sword lands 0.5 s later,
  as before.

**Known limits:**
- The hands stay at chest height: the blade, not the arms, goes above the head. It reads as a raised summoning
  sword, not arms fully overhead.
- The tip on the two upright frames is cut flat by the 1 px margin.
- The existing Knight release streak (white dots from the hand) now leaves from the command sword tip.

**Evidence (`production/qa/evidence/skill-v2-ngan-kiem/cast-overhead/`):**
- `01-raw-candidate-x4.png`
- `02-final-slots-x4.png`
- `03-ingame-hero-2x.png` (BEFORE cast_gesture vs AFTER cast_overhead, same capture frames)
- `04-ingame-native640.png`
- `05-ingame-bar4-native640.png`
- `ngan_kiem_cast_overhead_plus5.avi` (3.5 s; local, not committed)

