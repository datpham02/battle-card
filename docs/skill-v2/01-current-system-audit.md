# Skill v2 — Phase 1: current system audit

**Date:** 2026-11-07
**Scope:** read-only audit of the skill system as built (cards, heroes, statuses, blocks, delivery, animation, VFX).
Nothing in gameplay, balance, assets or code was changed for this report. No PixelLab calls.
**Sources:** the code under `src/`, data under `assets/data/`, design docs (`design/game-mechanics.md`,
`design/quick-specs/nhip-ra-chieu-2026-11-05.md`, `docs/architecture/adr-0001-tessera-design-pack-alignment.md`)
and the design pack `TESSERA_CLAUDE_DESIGN_PACK/tessera_claude_pack/` (00–07, `cards.json` with 180 proposed cards).

> Working-tree note: the Mage fireball cast pack and the per-impact pack choice (`unit_impacts`) described in §7 are
> in the working tree but **not committed** (2026-11-07 session).

---

## 1. Summary

A "skill" today is a **card**: one `effect`, damage = `damage_per_cell × cell count`, a cooldown and a minimum cell
count. The placed polyomino only supplies a **list of cells**; its shape is ignored by card damage. The five delivery
types (`CASTER_TO_TARGET`, `SKY_TO_TARGET`, `GROUND_PROPAGATION`, `SEQUENTIAL_CHAIN`, `DIRECT_MANIFESTATION`) change
**timing and visuals only**. Every cast resolves once, at the end of its swing, as one hit/miss test. Status
interactions are hand-wired, not a reaction system. Of the planned cast rhythms only `direct` and `parry` exist.

The architecture is clean enough to extend: the cast already carries per-piece data, delivery maths and a dormant
`path_rule` gate exist, statuses and zones have query APIs, and the passive/signature/relic hooks are generic.
The biggest structural gap is that `CutEffects.apply` receives only `cells` and resolves everything at one instant.

---

## 2. Source-of-truth files

| Area | Data | Loader / owner |
|---|---|---|
| Cards (34: 32 player + 2 curses) | `assets/data/cards.json` | `SkillConfig` (`src/combat/skill_config.gd`) |
| Heroes, passives, Awakenings, starter decks | `assets/data/characters.json` | `CharacterConfig` (`src/run/character_config.gd`), `PassiveRegistry`, `SignatureRegistry` |
| Swing timing, base damage, place window | `assets/data/cuts.json` | `CutConfig` |
| Status numbers, zones, hazards, delivery timing, cast caps | `assets/data/combat.json` | `CombatConfig` (`configure_status()` pushes numbers into `StatusEffects`) |
| Pieces (19 shapes) and weights | `assets/data/pieces.json` | `PieceLibrary` (`src/pieces/piece_library.gd`) |
| Odd blocks (4–7 cells, random) | `assets/data/field_drops.json` `odd_blocks` | `OddBlock` (`src/pieces/odd_block.gd`) |
| Arenas, sizes, featured (resonant) shape + bonus | `assets/data/arenas.json` | `ArenaLibrary` (`src/arena/arena_library.gd`) |
| Hand slots | `assets/data/hold_slots.json` | `HoldSlots` (`src/hold/hold_slots.gd`) |
| Relics that touch skills | `assets/data/relics.json` | `RelicConfig`, `RelicRegistry` |
| Rewards, rarity weights, levels | `assets/data/rewards.json` | `RewardRoller` (`src/run/reward_roller.gd`) |
| Card unlocks (real source) | `assets/data/achievements.json` `rewards[{kind:"card"}]` | `RunSession.locked_ids("card")` |
| Enemy skills (pattern brain) | `assets/data/enemy_skills.json` | `EnemySkillsConfig`, `PatternController` |
| Cast VFX binding | `assets/art/vfx/cast/index.json` | `CastVfx` (`src/art/cast_vfx.gd`) |
| Floor VFX packs | `assets/art/vfx/floor/index.json` | `FloorVfx` (`src/art/floor_vfx.gd`) |
| Status VFX packs | `assets/art/vfx/status/index.json` | `StatusPacks` (`src/art/status_packs.gd`) |
| Unit sprites | `assets/art/units/unit_<id>_sheet.{png,json}` from `art_src/units/<id>/` | `SpriteSheet`, `UnitAnimator`, `UnitLayer` |

### 2.1 Card schema (`SkillConfig._normalize`, `skill_config.gd:299`)
`effect` (one of `damage, push, burn, pin, fragile, frost, thorns`), `min_cells`, `cooldown_sec`, `damage_per_cell`
(missing → `cuts.json base_damage_per_cell` 6, burn cards → 0), effect params (`push_cells`, `burn_*`,
`pin_duration_sec`, `fragile_stacks`, `frost_stacks`, `pierce_defense`, `heal_self`, `execute`, `execute_ratio`,
`bonus_vs_fragile_mult`, `thorn_*`), `rarity` (`common/rare/epic/curse`), `upgrade` (additive deltas, `MAX_LEVEL` 3,
summed in `resolved(id, level)` at `skill_config.gd:250`), `implemented`, `player_pool`, `hero`, `delivery`
(`SkillDelivery.parse`), `cast_mode` (`direct|parry`), `crit` (`CritRules.normalize`).
**One effect per card**; extra behaviour lives in fixed side fields.

### 2.2 Heroes (`characters.json`)

| Hero | HP | Passive | Awakening (signature) |
|---|---|---|---|
| Kiếm sĩ `kiem_si` | 200 | `second_wind`: +20 HP after a won match | `tram` cd 25: 3 s cells ×2, lifesteal 20 % |
| Pháp sư `phap_su` | 210 | `wide_caster`: ≥ 4 cells swing ×0.75 | `thien_hoa` cd 15: detonate burns ×2, reset burn cards, ignite lit Engraving |
| Sát thủ `sat_thu` | 180 | `quick_blade`: ≤ 4 cells ×1.4 | `anh_bo` cd 12: 2 s free steps, ≤ 3 cells ×1.75 |
| Thợ săn `tho_san` | 200 | `hunter_mark`: thorn step / thorns next to boss → 1 Rạn (icd 3 s) | `vay_bat` cd 20: 4 s thorns ×1.5 duration, +1 cell, Rạn ×2 |
| Giáo sĩ `giao_si` | 210 | `prayer`: +8 HP per frost burst | `thanh_an` cd 22: 4 s +1 Hàn per hit, burst ×1.5 |

Hero ownership of a card is the `hero` string only; `RewardRoller._draw` (`reward_roller.gd:184`) skips hero cards.
The only hero card is `do_kiem` (Knight parry). Everything else is one shared pool. `starter_identity_test` pins that
at least 3 of a hero's 6 starter cards lean to its direction.

---

## 3. Cast pipeline (player)

`src/combat/combat_view.gd` unless noted.

1. **Place.** `PlacementController` / `PiecePlacement` (`src/pieces/piece_placement.gd:76`) accept cells on the enemy
   half only; every cell must be a real grid cell (static `missing_cells` count; runtime holes / cracks / thorns do
   not block placement). `confirm_placement()` (~1727) moves the piece out of `HoldSlots`, starts `CastPlan`
   (`init` / `add_piece`) and the place window.
2. **Join.** A second piece via `_attach_piece` (~1962): may touch or sit apart, may not overlap; cap
   `combat.json max_pieces_per_cast` 2 (3 with relic `tam_hop`); `max_cast_cells` 0 = off. One clock covers place,
   join and pick: `cuts.json place_window_sec` 4.0 × card-time setting (setting row removed 2026-11-07).
3. **Menu.** `press_cast()` or window end → `_open_card_menu()` → `Deck.draw_menu(hand_size 4)` →
   `CutFlow.open_menu(...)` (`src/combat/cut_flow.gd`); curses take slots (`_apply_curse_draw_damage`).
   `cards.json menu_time_scale` 0.0 freezes the match while the menu is open.
4. **Choose.** `CutFlow.choose` gated by `SkillAvailability.check` (`skill_availability.gd`): not_implemented → curse →
   `need_cells` (total cells of all joined pieces < `min_cells`) → cooldown → `no_telegraph` (parry only).
   Timeout → random available card, else `default_card` `kiem_khi`.
5. **Swing.** `_on_skill_chosen` (~2154) attaches the featured bonus (`CastPlan.is_featured`), `_begin_cut` (~2178) →
   `CutActor.begin_swing(cells, id, true, level, -1, featured_bonus)` (`cut_actor.gd:68`); cooldown starts at swing
   start (`SkillCooldowns.start`, keyed by **card id**: copies share it); parry opens `ParryGuard`; `signature.on_cast`.
   Swing = `0.2 + 0.25 × cells` s × `duration_mult` → passive `modify_swing_duration` → override → relic
   `cast_time_modifier`.
6. **Resolve.** `_process` (~1263) ticks status → hazards → signature → passive → formation → mover → drops →
   cooldowns → parry → boss → pattern → `SwingArbiter.tick` (`src/combat/swing_arbiter.gd`), which resolves both
   sides in time order and calls `CutEffects.apply(...)`. A hit cancels the opponent's running swing (trades within
   0.0005 s, parries and `no_interrupt` excepted).
7. **After.** `_on_swing_resolved` (~2260): `_play_cut_vfx` (delivery timing), relics `on_cast_landed`, Engraving cover
   (`_cover_formation` ~852), `signature.on_hit`, pattern / trait hooks.

---

## 4. Damage, effects and statuses

### 4.1 `CutEffects.apply` (`src/combat/cut_effects.gd:78–259`)
1. Locked cells (cracking or hole) removed (`StatusEffects.unlocked_cells`, `:118`); `heal_self` applies hit or miss.
2. `inside = state.unit_in(target, cells) and not untargetable` (`:146`) — **one boolean at resolve time**; a
   multi-cell boss is hit once.
3. Effects with their own path: thorns form a zone hit or miss (`_form_zone`); burn ignites every cast cell; pin,
   fragile, frost apply their keyword and return — except burn cards with dpc > 0 also take the damage path.
4. `damage = damage_per_cell × effective_cells` (`cells.size()`, then signature `modify_cells`, e.g. `tram` ×2).
5. Multipliers in order: `bonus_vs_fragile_mult` → pinned mult (1.0 today) → consume one Rạn (×`fragile_mult` 1.5 or
   `vay_bat` override) → crit (`CritRules.mult_for`, snapshot at swing start) → featured `damage_mult` → relics
   (`RelicRegistry.fold_damage`, capped ×3) → execute ×2 under `execute_ratio` → passive `modify_damage` → signature
   `modify_damage`.
6. Defense: flat `boss_defense + guard`, floor 1, skipped by `pierce_defense`. Parry: `ParryGuard.try_parry`.
7. Apply damage, then `_apply_keywords` (Rạn / Hàn stacks, Hàn burst), featured effect, `_push` (straight away from
   the divider).

Outside `apply`: frost burst (`StatusEffects.apply_frost`, `thanh_an` mult), Thiên Hỏa detonation and burn-card
cooldown reset, Trảm lifesteal, Thánh Ấn extra Hàn, `hunter_mark` thorn listener, `prayer` burst listener,
`second_wind` on match won.

### 4.2 Statuses (`src/combat/status_effects.gd`)

| Status | Stored | Rule |
|---|---|---|
| Burn (Cháy) | per **cell** | re-ignite: `left = max(left, dur) + 2`, stacks ≤ 3, tick +1 per stack; `burn_on_entry`; boss brain treats burning cells as blocked |
| Pin (Đóng Băng) | per side | no stacking; blocks stepping; `pinned_damage_mult` 1.0 → control only; crit condition `target_pinned` |
| Fragile (Rạn) | per side | ≤ 3 stacks; each damage/push hit spends one for ×1.5 |
| Frost (Giá Lạnh / Hàn) | per side | 3 stacks → 24-damage burst; no slow |
| Thorns (Bãi Gai) | per side zone cells | stepping in: damage + Rạn; steppable |
| Drop tiles (Ô rớt) | per cell | crack 0.8 s → hole 1.2 s; locked cells refuse casts and zones; boss-only (`ZoneRules.cast_drop`) |
| Root, Slow, Guard | per side | enemy pattern skills only |
| Mire, sand, vents, crumble | terrain | `TileHazards` (`src/combat/tile_hazards.gd`); no card creates them |
| Poison | — | **does not exist**; `gai_doc` uses a `poison` impact visual only |

One zone per cell (`_claim_zone_cell`, quick spec `mot-o-mot-hieu-ung-2026-11-01.md`).
Hard-wired interactions only: pin → crit, thorns → Rạn → damage, Hàn → burst → prayer heal, burn → Thiên Hỏa, zones
replacing zones, locked cells. **No generic reaction system.**

### 4.3 Cast modes and crits
- `SkillConfig.CAST_MODES = ["direct", "parry"]`; other values fall back to `direct` with a warning.
- `parry` (`do_kiem`): available only during an enemy telegraph; resolves as `direct`, opens a guard
  (`ParryGuard`): next enemy hit deals 0, reflects ×`reflect_mult`, pins the enemy.
- `CritRules.CONDITIONS` = `target_pinned` only.
- `delayed`, `combo`, `trap`, `ward`, the crit conditions `target_burning`, `combo_3`, `target_on_hazard`,
  `self_hp_high`, and the cards `hoa_loi`, `song_dao`, `bay_kep`, `thanh_thuan` exist **only** in
  `design/quick-specs/nhip-ra-chieu-2026-11-05.md`.

### 4.4 Enemy side
- Block-brain boss (`BossController`, `BossBrain._choose_skill` ~712) uses the **player's cards**
  (`boss_card_order`: no zone, parry or non-direct cards), same `CutActor` / `SwingArbiter` / `CutEffects`; no
  crit, featured bonus or modifiers.
- Pattern enemies (`PatternController`, `enemy_skills.json`) resolve their own flat damage / status / zone
  (`_resolve_cells`, `_apply_zone` ~615 for thorns and drop), sharing `StatusEffects`, `ZoneRules`, `ParryGuard` and
  `SkillDelivery` visuals.

---

## 5. Blocks, rotation, grid, terrain

### 5.1 Pieces
- `pieces.json`: 19 shapes — default `mono, bar2, bar3, l3, square, t4, l4, s4, bar4, plus5, u5, p5, bar5`;
  unlockable `w5, n5, v5`; run-only `z4, j4, y5`. Weight tables per chapter / region.
- `Piece` (`src/pieces/piece.gd`): `shape_id` + `rotation` (0–3) + base cells; `_normalise` (`:127`);
  rotation `(x,y)→(-y,x)`; `canonical_key` (`:106`, min over 4 rotations) — **no mirroring** (L ≠ J).
- `PieceLibrary` rejects shapes > `MAX_CELLS` 5, duplicates, disconnected. Odd blocks (4–7 cells,
  `shape_id = "odd:" + key`) are generated outside the library, chance 0.12.
- Rotation in play: `CombatView.rotate_piece()` (`:1626`) → `PlacementController.rotate()` (`:330`), re-snaps.
- Hand: 3 piece slots (`hold_slots.json`), freshness 8 s on the field (`FieldPoint`), rotten pieces from the
  `rotten_thrower` trait, pickup by stepping (`FieldDrops.pick_up_at`), burning cells refuse pickup.

### 5.2 Shape awareness today
- `FeaturedShape` (`src/pieces/featured_shape.gd`): `normalize`, `rotate_cells`, `matches` (4 rotations, no flip),
  `pair_compositions`. `CastPlan.is_featured` = exactly 2 pieces whose union equals the arena's featured shape
  (5–7 cells) → `featured_bonus {damage_mult, effect, stacks, sec}` (`arenas.json`), applied in
  `CutEffects._apply_featured_effect`. `ArenaValidator` requires ≥ 2 pair compositions.
- Relic `AnDon` (lone `mono`), `TamHop` (piece count); `cast_info.pieces` (shape ids) reaches relics through
  `_make_cast_info` (`combat_view.gd:1066`) but **never reaches `CutEffects`**.
- Cell-count thresholds: `huyet_an`, `wide_caster`, `quick_blade`, `anh_bo`.
- **No shape classifier** (line / square / L / T / S / plus …), no bounding-box or straightness features.

### 5.3 Board and movement
- `BoardGrid` (`src/board/board_grid.gd`): two halves `side_cols × side_rows`; player = left columns, enemy = right;
  `Vector2i(col,row)`, row 0 at the top; halves mirror `missing_cells`. Arenas from 3×3 to 7×2 / 6×5 / 6×4
  (`boss_hall`). `BoardGeometry` (`src/layout/board_geometry.gd`) is screen mapping only.
- `CombatState` (`src/combat/combat_state.gd`): `player_cell`, `enemy_cell`, `enemy_footprint`, `enemy_in` (`:225`,
  the single hit test), `enemy_hit_cell` (`:303`).
- `UnitMover.try_step`: 4-way, one cell, cooldown `CombatConfig.step_cooldown_for(board)` (ref 0.45 s, 0.18–0.60),
  blocked by pin/root, `blocked_cell_fn`, holes; mire scales cost.

### 5.4 Terrain and tile state
`StatusEffects` (holes, thorns, burn), `ZoneRules` (`src/combat/zone_rules.gd`: `cast_drop`, `cast_thorns`,
`fit_cells` fairness), `TileHazards` (mire, sand, wind, vents, crumble), `CrackField`, `FormationMap`
(`src/combat/formation_map.gd`: Engraving / Bản Khắc, lit by every landing cast, completes → Awakening ready).
Query API: `is_hole`, `is_cracking`, `thorns_at`, `is_burning`, `is_mire`, `is_sanded`, `is_fallen`, `is_locked`.
Player cards create thorns and burn only; `add_mire` / `add_sand` exist but no card uses them.

---

## 6. Delivery (`src/combat/skill_delivery.gd`)
- Types, origins, `TRAVELS`, `IMPACTS`, `CHAIN_ORDERS` (`nearest_first`, `row_major`, `authored`); `normalize` forces
  `cell_mask = block_shape` (`:102`).
- Pure maths: `nearest_cell`, `origin_cell`, `first_link`, `chain_cells`, `arrival_times` (`:202`), `travel_cells`
  (`:234`, line or `_l_path`), `ground_time`, `damage_cells` (`:269`, mask + path cells only when
  `path_rule.telegraphed`) — **`damage_cells` has no caller and no card defines `path_rule`**.
- Used only by presentation: `_play_cut_vfx` (`combat_view.gd:2845`), `_play_delivery_travel`, `_play_hero_wave`,
  `cast_travel_now` (`:2985`), `OverlayLayer`, `CastVfx`.
- Gameplay effect: none. GROUND is not blocked by holes or thorns, SKY adds no real delay, CHAIN does not bounce.
- Usage: cards 8 / 5 / 7 / 6 / 8 (caster / sky / ground / chain / direct); enemy skills 6 / 6 / 6 / 2 / 15.

---

## 7. Animation and VFX

### 7.1 Unit animation
- `UnitAnimator` (`src/art/unit_animator.gd`): pure clip state machine over a `SpriteSheet`; loop kinds `loop`,
  `once`, `hold_last`, `hold`; ticks on the battle clock.
- `UnitLayer` (`src/battle/unit_layer.gd`): `clip_for(ctx)` (`:522`) priority — fall/defeat/down → victory → hit →
  **cast_gesture** (player casting) → parry_guard → enemy phase_shift / stunned / guard / howl / windup_heavy / windup
  → awaken → step → idle. Directional step clips (`step_clip_for`), step glide and dust, hit flash and shake
  (`hit_feel`).
- Cast sync: `cast_hold` / `_drive_cast_hold` / `cast_hold_step` (`:468–520`) hold `cast_gesture` on the pack's
  `gesture_hold_frame` (coil) while the swing runs, then jump to the release frame `gesture_lead_sec` before launch.
- Clips per hero (all five): idle 8, draw 8, step 4, step_forward/back/down 5–7, **cast_gesture 9 (898 ms, one clip
  for every card)**, hit 3, victory 5–8, defeat 8, fall 4, awaken 5–8. Bosses: windup, windup_heavy, phase_shift,
  hit, down.
- Pipeline: frames in `art_src/units/<id>/<clip>/N.png` + `clips.json` → `tools/asset-pipeline` export →
  `assets/art/units/unit_<id>_sheet.{png,json}`. Mage spec log: `design/assets/specs/mage-assets.md`.

### 7.2 Cast VFX
- `CastVfx` + `assets/art/vfx/cast/index.json`: `units` (hero → pack), `default` `sword_wave`, `packs` (hand,
  aim_lift, travel_sec, charge + charge_sec, release, impact, cell_burst, impact_mark, cell_mark, flood, gesture
  timings), `impact_packs` (only `burn` → `impact_flame_burn`), `impact_marks` (`burn`), `travel_packs`
  (`floor_run` → `miss_dust`), `travel_style` (code-drawn squares), `impact_style` (per-impact colours),
  `block_colours` (per hero), `hit_feel`.
  Working tree (uncommitted): `unit_impacts` limits a hero's own pack to listed card impacts; `travel_impact_packs`
  (`floor_run:burn`); the Mage's `fire_bolt_burn`.
- Hero packs: Knight `square_wave_steel` (release slash, steel wave, burst, stamp); Mage `fire_bolt_burn`
  (uncommitted). Assassin, Hunter, Cleric use the default code streak.
- `OverlayLayer` (`src/battle/overlay_layer.gd`): `projectile_state` (charge at hand → projectile), `release_state`,
  `travel_items` (code-drawn falling / chain / run squares, impact flash and shards).
- `FloorDynamicLayer`: charge fill/outline of target cells, Engraving, flood. `CastFloorFx`: pure square geometry.
- `FloorVfx` + `floor/index.json` (27 packs): burning_cell, engraving_lit / complete, cracked_cell, cast_target,
  hit_impact, miss_dust, interrupt, thorn_spikes, root_seal, cell_slash, big/small_burst, steel bursts/stamps,
  flame bursts, ember marks (64×46 and 43×31 variants).
- Status overlays: `assets/art/vfx/status/` burn / frozen / chill for hero and goblin (PixelLab VFX workbench).
- Telegraph: `TelegraphPainter` + `fx_telegraph_stripe_8.png` (floor layer, darkening over the cast time).
- `VfxPack` (`src/art/vfx_pack.gd`): `manifest.json` + `whole.png` sheets, anchors, layers.

### 7.3 fxkit (free, code-drawn VFX)
`tools/fx-pipeline/` (plan `docs/plans/animation-pipeline.md`): Python stdlib; components `square_wave`,
`square_slash`, `square_burst`, `square_mark`, `square_gather`, `flame_burst`, `square_fireball` (new), `root_crawl`,
`root_spike`; materials `steel, charcoal, burn, root, moss, ivory`; recipes `kiem_khi`, `hoa_tran`,
`branch_lattice`, `phap_su_hoa_cau`. A build checks palette / alpha / determinism, writes candidates to
`design/assets/candidates/fx-pipeline/`, previews and a skill timeline with the real sprites to
`production/qa/evidence/fx-pipeline/<recipe>/`. Installing into `assets/` is a separate step.

---

## 8. Limitations that block richer skills

1. **Shape is invisible to cards.** `CutEffects.apply` gets `cells` only; piece ids stop at relics.
2. **Delivery is cosmetic.** No resolve rule per delivery; `path_rule` / `damage_cells` dormant.
3. **One effect per card**, combined through fixed side fields.
4. **One hit per cast at one instant.** No per-cell resolve times, multi-hit, fuse, trap or echo.
5. **No reaction system**; burn is per cell, other statuses per side; interactions hard-coded.
6. **Player placement fixed to the enemy half** (blocks `ward` and self-grid cards).
7. **Rarity and upgrades are numbers.** Rarity only weights pools (curse excepted); upgrades add one delta.
8. **Identity:** one shared pool, one hero card; one `cast_gesture` per hero for all cards; three of five heroes
   share the default cast VFX.
9. **Player terrain creation** limited to thorns and burn; no player drops, mire, sand, walls.
10. **Forecast** ignores locked cells and boss dodging; telegraphs do not draw path cells.
11. **Cooldown keyed by card id** (duplicate copies share one cooldown).
12. **Balance sim** (`tools/balance/sim_core.gd`) re-implements damage in `cast_value()` without crit, featured or
    relic multipliers and has no model for delayed / combo / trap / ward.
13. **Piece size cap** 5 in `PieceLibrary` vs canon 1–7 (odd blocks bypass it).

## 9. Existing mechanics that can carry new skill types

| Need | Reuse |
|---|---|
| Shape rules | `Piece.canonical_key`, `FeaturedShape.normalize / matches / rotate_cells`, `CastPlan.piece_cells(i)`, `cast_info.pieces` |
| Delivery rules | `SkillDelivery.arrival_times`, `travel_cells`, `chain_cells`, `path_rule` + `damage_cells` gate |
| Multi-hit / combo | `CutActor.queue_swing` (boss two-swing precedent) |
| Timed windows (fuse, ward, trap) | `ParryGuard` pattern, `StatusEffects` zone books + `_claim_zone_cell` + `unlocked_cells` |
| Terrain skills | `ZoneRules.cast_drop / cast_thorns / fit_cells`, `TileHazards.add_mire / add_sand`, `FairnessCheck` |
| Conditions | `CritRules.CONDITIONS / holds(ctx)`, `SkillAvailability` `context` |
| Hero identity | `hero` field + `RewardRoller` filter, `PassiveRegistry`, `SignatureRegistry`, `BaseRelic` hooks |
| Visual identity | `CastVfx` per-hero / per-impact packs, fxkit components and recipes, `impact_style` colours |
| Card text | `CardText` placeholders, `<desc_key>_battle` strings |

## 10. Recommended extension points (for Phase 2 design)

1. **Pass a cast context into resolve.** Extend the `CutEffects.apply` options with `{pieces, piece_cells,
   shape_tags, delivery, featured}` built once in `_on_skill_chosen`; everything downstream reads it.
2. **Add a shape classifier** next to `FeaturedShape` (pure, tested): tags such as `line`, `square`, `L`, `T`, `S`,
   `plus`, `U`, `mono`, `odd`, length, bounding box, and a mirror policy decision.
3. **Card schema v2** in `SkillConfig`: `shape_rule` (requirement) and `shape_bonus` (tag → effect), an `effects`
   list (keep `effect` for back-compat), `tags` (the pack's tag list drives synergies), `cast_mode` values.
4. **Per-cell resolve** in `SwingArbiter` / `CutEffects`: resolve each cell at its `arrival_times` value, which makes
   delivery rules (ground blocked by holes, sky delay, chain bounce) and fuses possible. Telegraph any path damage
   (`path_rule`) on the floor layer first.
5. **Reaction table** in data (`combat.json`): status pair → result, with the pack's anti-loop rule (one echo child,
   no self-retrigger).
6. **Hero pools** by `hero` / `affinity` tags in `RewardRoller`, following the pack's split (~55 % shared,
   ~25 % hero, ~20 % unlockable).
7. **Sim parity**: `sim_core.cast_value` must call the same resolver before any new card is tuned.
8. **Per-card cast animation hook**: `clip_for` could pick `cast_<delivery>` when the sheet has it, else
   `cast_gesture` (no art needed until a clip exists).

## 11. Missing or inconsistent items

| Item | Finding |
|---|---|
| **Hỏa Lôi** (`hoa_loi`) | Only in `nhip-ra-chieu-2026-11-05.md` (delayed + burn, fuse 1.5 s, ×2). Not in data, code, strings or tests. Same for `song_dao`, `bay_kep`, `thanh_thuan`. |
| Cast rhythms | Assassin combo, Mage delayed, Hunter trap, Cleric ward not built; only Knight parry. |
| Design pack | ADR-0001 D2 chose "60 MVP cards from the pack's 180 ideas, rewritten with shape rule, trigger, counterplay, upgrade, delivery". Not started: data still has the original 34. |
| `game-mechanics.md` vs data | Doc: place window 3 s, menu slows to 0.2×. Data: `place_window_sec` 4.0, `menu_time_scale` 0.0 (frozen). Doc: "36 cards"; data: 32 player + 2 curses (+3 wall cards not implemented). Doc groups Rét cắt / Tuyết rơi / Buốt xương under "Chém"; data gives them `freeze` / `shatter` impacts with frost stacks. |
| Poison | `gai_doc` impact is `poison`, but no poison status exists (it lays thorns + Rạn). |
| `unlock_by` in `cards.json` | Ignored by `SkillConfig`; `achievements.json` is the real source (`unlock_content_consistency_test`). |
| Frost burst | Card text says armor-piercing; verify against `CutEffects._apply_keywords` when redesigning. |
| Piece cap | `PieceLibrary.MAX_CELLS` 5 vs canon 1–7. |
| Pinned damage | `pinned_damage_mult` 1.0: Đóng Băng adds no damage, only control and crit eligibility. |
| Forecast | Green/red ghost ignores locked cells and dodging. |
| Accessibility doc | Card pick time option removed 2026-11-07 (doc updated). |

---

## 12. Constraints for any v2 design
- ADR-0001 D1: keep the input model (drop / pick up blocks, 4-card menu, min cells + cooldown, no energy).
- Pack §1A (LOCKED): shape / delivery / impact are separate; the Block is never thrown; path visuals never deal
  untelegraphed damage; square-based VFX only; no default to sky.
- Telegraphs: tile-exact, darkening on the floor layer; a dodgeable attack leaves a reachable safe tile.
- One zone per cell; locked cells refuse casts.
- Touch-first, readable at a distance; angular shapes.
- PixelLab spends need explicit approval per call; fxkit is free.
