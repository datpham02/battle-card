# 00 — Current state audit (read-only, 2026-11-11)

Scope: the run, world map, region map, encounter, reward and save systems of Tessera at HEAD `de6f88a`.
Everything marked **[V]** was read in the source or data named; **[I]** is inference; **[D]** is a stale document
claim that the code contradicts. Nothing was modified for this audit.

Reading order of this document: §1 what exists, §2 how the pieces connect, §3 reusable vs limiting, §4 gaps and
stale docs, §5 what the redesign must preserve.

---

## 1. The systems as they are

### 1.1 Run skeleton [V]

| Fact | Value | Where |
|---|---|---|
| Floors per run | **7**, fixed order `ch1 → hellfire → desert → swamp → ch2 → ch3 → sky_isles` | `assets/data/chapters.json` `world.floors`, `world.region_order` |
| Region offer | one region per floor (`region_order`); the Story 031 "pick 1 of 2" branch is still in code but inactive | `WorldMapGen.floor_offer` (`src/run/world_map_gen.gd:54-60`) |
| Final | `an_dai_keeper` (the Lattice Heart keeper), reached after floor 7 through `world.final_match`; preceded by one `shop` column (`world.final_prelude`) | `ChaptersConfig.final_map` (`chapters_config.gd:226`) |
| Region map | **7 columns**: battle · 3 nodes · 2–3 (+treasure) · 2–3 (+elite from floor 2 / event on floor 1) · 3 (rest + treasure-or-battle) · 2–3 (shop/event column) · warden | `world.region_columns`, `ChapterMapGen.generate` (`chapter_map_gen.gd:81`) |
| Links | OSFE `WorldBar` order between adjacent columns; every node has `next` (indices into the next column); the player may only enter a node linked from the node just cleared | `ChapterMapGen.link_columns` (`:110`), `RunSession.linked_indices` (`run_session.gd:350`) |
| Nodes per run | ≈ 7 floors × 7 nodes + shop + final ≈ **51 node visits** | derived |
| Difficulty | `region_normalize` (per region) × `floor_scaling["1".."7","final"]` (hp, step, defense, size) + `floor_tiers` (pool tier per column slot) + `onboarding_tier_cap` (tier ≤ 1 until one boss ever cleared) + Kiep | `RunConfig._apply_scaling` (`run_config.gd:148`), `ChaptersConfig.region_spec` (`:298`) |
| Save | `RunSession.to_dict` v7 inside the progress file v8, three slots `user://saves/slot_<n>.json`, atomic writes, memory store under any dev arg | `run_session.gd:943`, `progress_state.gd`, `save_slots.gd` |

The climb screen (`WorldMapView` + `ClimbMap`) is a vertical strip of one island per floor; the player taps the current
floor's island and enters it. Since `region_order` is fixed, that screen is a **progress view, not a decision**. [V]

### 1.2 Region map generation — `ChapterMapGen` [V]

`generate(spec, seed, cleared_bosses)` walks the column spec in order, draws each column's node kinds
(`required` first, then fillers to a seeded `pick` count, siblings differ when possible, seeded shuffle), draws a match
id per fight node from `pools[kind][tier]` (unused ids first, lower tiers as fallback), then runs three post passes on
their own RNG streams: `_teach_gated` (ch1 elites only after a teacher fight), `_apply_special_nodes` (one shop / one
event in `special_nodes.column`, shop guaranteed on the run's `shop_floors`), `link_columns`.

Seeds: region map = `hash([run_seed, region_id, floor])`; links `hash([seed, id, "links"])`; special
`hash([seed, id, "special"])`; teach `hash([seed, id, "teach"])`. **Same inputs → same map** is tested
(`tests/unit/run/map_gen_test.gd`, `map_links_test.gd`, 5 seeds × every region × every floor).

What the generator does **not** know: which route a node belongs to, what the node will reward, what modifiers the
fight carries, or whether two sibling paths differ in anything but the drawn match ids. A column's nodes are drawn
independently; the only "route" concept is the link graph laid over them afterwards.

### 1.3 Node resolution — `GameFlow` [V]

| Kind | Resolution |
|---|---|
| battle / danger / miniboss / boss | `RunConfig.from_node` → `RunController` → `CombatView`; on win `_complete_match_node`: gold drop, run-modifier tick, `complete_node`, card offer (`_offer_reward`) |
| treasure | gold + free card offer + relic row (3) + ink row, no fight |
| rest | `REST` screen: heal 30 % or forge +1 level on one card |
| shop | `ShopLogic.build` (3 cards, 2 relics, 3 services) seeded per node |
| event | `EventLogic.pick_event` from 8 events; outcomes gold / hp / relic / curse / card offer / upgrade / fight / run modifier / relic swap |
| boss (region) | FATE screen (spare / execute, execute = 2 rare+ relics) → boss reward → floor +1, heal 60 % max HP, next region |

Every transition saves (`_save_run`, 20+ call sites). Resume restarts a match from its start at the saved HP. [V]

### 1.4 Encounter knobs that already exist [V]

Per match (whitelisted by `RunConfig._clean_match`, `run_config.gd:215-294`): `boss_max_hp`, brain set / think /
reaction / movement, `boss_step_cooldown_mult`, `swing_speed_mult`, drop interval multipliers, `boss_defense`,
`boss_min_runes`, `boss_cards`, `traits[]` (22 registered ids), `phases[]`, `arena {shape, variant, crumble}` + 19
per-match hazard overrides, `featured_shape/bonus`, `odd_blocks`, pattern-brain `brain/enemy/pattern_tempo_mult`.

Per region: `region_normalize`, piece drop weights (`pieces.json weights.<chapter_id>`), art. **No region-level
hazard flag exists**: hazards ride on the arena *shape* (`bog`, `dunes`, `forge`, `twin_isles` …). Any match can borrow
any region's terrain by naming its shape.

Per node kind: `danger` appends `defaults.danger_traits` (= `row_burner`); region `boss` sets `boss_can_down`.

Per run: relic overrides (10 keys), `run_modifiers` (combat honours only `step_cooldown`), Kiep rules.

**Battles are strictly one player vs one enemy unit** (`CombatState` holds one `enemy_cell`/`enemy_hp`; one
`BossController`, one `BossBrain`). Multi-cell footprints exist (2×2 wardens). No allies, minions or summons. [V]

### 1.5 Region mechanics already in combat [V]

| Region | Terrain / rule in combat | Driven by |
|---|---|---|
| ch1 Misty Forest | none; identity = pattern-brain roster (telegraphed skills, root, thorns, `bark_shift`, 2×2 wardens) | enemy_skills.json |
| ch2 Dungeon | none; traits `step_reactor`, `slam`, `seal_caster`, `rotten_thrower`, armour | match traits |
| ch3 Ice Tower | none; traits `frost_aura` (player drops ×0.8), `fuse_cannon`, `thorn_field`, armour | match traits |
| swamp | **mire** cells: leaving costs ×1.6 step, standing bleeds; `mire_immune`, `bog_spread`, `spore_burst`, `hop_skip` | shapes `bog`, `reed_maze` |
| desert | **sand** fills 2 cells / side every 6 s for 3 s (buries pieces); **wind** drifts field pieces, shifts drops; `sandstorm`, `burrow`, `riposte` | shapes `dunes`, `oasis` |
| hellfire | **lava vents**: one line per half erupts every 7 s after a 1 s warning, burns cells 2 s (2 dmg / 0.5 s) and the pieces on them; `vent_surge`, `burn_eater`, `rebirth`, `phase_shift.vent_interval_mult` | shapes `forge`, `caldera` |
| sky_isles | **crumble**: a cell stood on 2 s cracks, falls 4 s, pushes the unit off for 8 dmg; `island_drop`, `gust`, `shroud` (no hit forecast) | shapes `twin_isles`, `three_isles`, `islands_bridge`+`crumble` |
| an_dai | none; 2-phase keeper | phases |

Four of seven regions have a terrain rule; three have none. The rules are *per match*, never aware of the route or of
the region's progress. [V]

### 1.6 Roster [V]

62 match ids across 7 regions + final; per region 9–16 matches in `battle / danger / miniboss / boss` pools by tier
0–2. Full tables with hp, traits, arenas and restrictions: the combat audit appendix (§A1 below). Restrictions in
force: `teach_after` on three ch1 elites; `min_floor 2` on `danger` (columns 1–2) and `miniboss`; `max_floor 1` on
the column-3 `event`; `onboarding_tier_cap 1`; `floor_tiers` → tier-2 boss from floor 4. Five ch1 block-brain matches
(`wolf`, `goblin_chief`, `goblin_warrior`, `goblin_shaman`, `goblin_brute`) are defined but in **no pool** (orphans).

### 1.7 Rewards and economy [V]

| Node | Cards | Gold (base, ×floor mult, ±20 %) | Other |
|---|---|---|---|
| battle | 3 (common+) | 12 | ink offer 35 % |
| danger | 3 | 22 | ink 35 % |
| treasure | 3 free | 15 | relic row (3), ink always |
| miniboss | 3 (rare+) | 25 | — |
| boss | 3 | 35 | +1 removal token, +1 shape removal, fate (execute → 2 rare+ relics), heal 60 % |
| rest | — | 0 | heal 30 % or forge +1 |
| shop | — | 0 | 3 cards (30/40/60), 2 relics (50/70/90), services remove 60 / heal 40 (25 %) / remove shape 45 |
| event | — | 0 | 8 events, closed effect vocabulary |

Luck = nodes cleared (whole run); rarity weights 70/25/5 → 31/35/34 at luck 70. `gold_floor_mult` and
`price_floor_mult` have **5 entries** for a **7-floor** run (floors 5–7 clamp to the last). Shops: floor 1 always, 3
more on random floors 2–7, 1 before the final = 5 per run. `relics.json source_rules.boss_kill` has **no consumer**.

### 1.8 Build axes present in the data [V]

Burn (hoa_*, liet_hoa, thien_hoa, dau_than) · Frost / chill burst (han_*, bang_*, han_ky) · Fragile / execute
(ran_*, song_kiem, tu_kiem) · Thorns (tran_gai, gai_*, phong_an, gai_ran) · Spatial control (push / pull / pillars /
mines: chan_phong, xung_kich, cuong_phong, thien_lang, dia_chan, loc_cuon, tuong_da, bay_lo, min_tre) · Traps and
wards (bay_lo, bay_kep, khien_thep, thanh_thuan) · Sequential chains (dai_dao, bang_chau, han_phong, song_kiem,
chuoi_set, phi_tieu) · Small casts vs big zones (an_don, dau_tu vs 5-cell cards, huyet_an) · Shape clauses keyed to
piece tags (line, square, plus, branched, S, L) · Piece deck (ink multipliers, run-only shapes z4/j4/y5, removals).

There is **no "node collection" mechanic** by that name. The brief's "collect nodes and connect them" is Tessera's
**block pickup → placement → cast** loop (`mảnh ấn`, `PieceDeck`, `CastPlan`). The redesign treats those as the same
thing.

### 1.9 Tests and tooling [V]

- Runner: `tools/qa/run_all_tests.sh <file>` runs every `*_test.gd` under `tests/unit` and `tests/integration`
  (SceneTree scripts printing `PASS/FAIL` and `FAILS=N`), 240 s each; last full run 271/271 green (`docs/skill-v2/21-batch4-report.md`).
- Map tests: `map_gen_test`, `map_links_test`, `map_gen_teach_after_test`, `first_floor_map_test`, `shop_event_nodes_test`,
  `world_map_gen_test`, `climb_map_test`, `floor_scaling_test`, `regions_*_test`.
- Run tests: `run_session_v4/v5_test` (save round trips at six exit points), `run_flow2_test`, `shop_event_flow_test`,
  `fate_flow_test`, `final_prelude_test`, `save_slots_*`.
- Simulator: `tools/balance/deck_sim.gd` (bot-played full runs: `--run=v6 --seeds= --floors= --shop-policy= …`),
  `sim_core.gd` (headless match, dodge 0.85 — TD-006, never anchored to real play).
- Baselines: all run-level evidence (`production/qa/evidence/run-v6-balance/`, `regions-hellfire-skyisles/`,
  `gold-shop-events/`) was measured on the **5-floor** run. The current 7-floor climb has **no recorded baseline**.

---

## 2. How the systems interact (call chain) [V]

```
TitleView ─► GameFlow.start_run ─► RunSession.begin_world(seed) ─► roll_offer()  (= region_order[floor])
                                                                    │
WorldMapView (climb) ─► GameFlow.choose_region ─► ChaptersConfig.generate_region_map(region, seed, floor, cleared_bosses, kiep)
                                                     └► region_spec (frame + floor_tiers + kiep) ─► ChapterMapGen.generate
                                                                                                     ├ _teach_gated
                                                                                                     ├ _apply_special_nodes
                                                                                                     └ link_columns
ChapterMapView ─► GameFlow.choose_node(i) ─► RunSession.choose_node (linked_indices) ─► by kind:
      fight ─► RunConfig.from_node(region, match_id, kind, floor_seed, floor, kiep)  [normalize ∘ floor_scaling ∘ danger_traits ∘ kiep ∘ _clean_match]
            ─► RunController._spawn_battle (+ character, deck, relics, piece_deck, run_modifiers, boss_can_down)
            ─► CombatView._ready (_apply_arena, hazards from the shape, traits, brain)
            ─► match_ended ─► GameFlow._complete_match_node ─► EconomyConfig gold ─► RunSession.complete_node ─► RewardRoller / RelicRoller / ink
      rest / shop / event ─► their logic classes, seeded by (run_seed, floor, column, node_index)
      boss ─► FateLogic ─► complete_node (_clear_floor: heal, floor+1, next offer or final_map)
```

Every arrow above is column/index addressed. The 21 places that assume "layered columns, one cleared node per column,
`next` = indices into the next column" are listed in §A2 (from the run-flow audit). [V]

---

## 3. Reusable vs limiting

### 3.1 Reusable as-is (keep)

- **Roster, pools, tiers, `teach_after`, onboarding cap** — all data; the redesign only changes who *asks* the pools.
- **`RunConfig.from_node` scaling pipeline** — the single place difficulty is applied; new encounter modifiers plug in
  beside the `danger_traits` step (`run_config.gd:129-138`) and the `_clean_match` whitelist.
- **BossTrait registry** (`src/traits/trait_registry.gd`) — traits already act as encounter modifiers (`frost_aura`,
  `shroud`, `vent_surge`). New modifiers are new traits, not a new system.
- **Arena library + variants + hazards** — region terrain is already composable per match through the shape id and
  the 19 hazard override keys.
- **RewardRoller / RelicRoller / EconomyConfig / ShopLogic / EventLogic / FateLogic** — pure, seeded, tested; they take
  `(seed, kind, config)` and need only a richer *kind* (reward tier) to serve routes.
- **Save plumbing** — `ProgressState` versioning, slots, atomic writes, `needs_restart` path for too-old saves.
- **Seeding discipline** — every subsystem hashes its own stream; the redesign keeps this (§04).
- **Views' input model** — tap to select, tap again / button to enter, emulated-event dedup, 1280×720 landscape.

### 3.2 Limiting (replace or extend)

| Limitation | Why it blocks the design vision | Verdict |
|---|---|---|
| Nodes are `{kind, match_id, next[]}` in column arrays, addressed by `(column, index)` | no node identity → no route membership, no per-node modifiers / rewards / previews, no cross-column edges | **replace** with an id-addressed graph (§04) |
| Kinds are drawn per column independently | sibling paths differ only by match id; no route has an identity or a predictable payoff | **replace** generation with route-first (archetype) generation (§01 B) |
| Rewards keyed by `kind` only | a high-risk fight and a safe fight pay the same | **extend**: reward tier per node (§01 E) |
| Encounter = match id + kind | no modifiers / objectives / region rules per node | **extend**: encounter profile (§03) |
| Region mechanics are per match, blind to the route | region identity cannot build up or interact with the map | **add** region rules with run-scoped state (§02) |
| `region_order` fixed, climb screen is a progress view | no world-level decision; the brief wants informed route choice at region scale too | **keep order for the slice**, re-open "1 of 2" as a tuning decision (§01 A, decision D2) |
| `ci == 3` hard-coded in `link_columns`, `floor*100 + column` seeds, `BEST_FLOOR_MAX = 8`, 5-entry floor multiplier tables | brittle constants from the 7-column / 5-floor eras | **fix** in the migration |
| No per-node preview in `ChapterMapView` (`match_id` is never read) | players choose blind | **add** preview panel (§01 G) |

---

## 4. Gaps, dead data and stale documents

| # | Finding | Kind | Where |
|---|---|---|---|
| G1 | `game_flow.gd` header (lines 42-58) and `schema.md` "World v6" still say 5 floors / 2 choices / 3 columns | [D] | stale doc |
| G2 | `schema.md:563` says `best_floor` 0..6; code `BEST_FLOOR_MAX = 8` | [D] | `progress_state.gd:18` |
| G3 | `schema.md` says sky_isles normalize = ch1 values; data has `hp_mult 0.45` | [D] | `chapters.json:1812` |
| G4 | `gold_floor_mult` / `price_floor_mult` have 5 entries for 7 floors | dead-ish data | `economy.json` |
| G5 | `relics.json source_rules.boss_kill` has no consumer; `an_chu` / `tam_hop` (boss tier) only reachable through other sources | dead data | `relic_roller.gd` |
| G6 | `reach_floor_4` / `reach_floor_5` achievements and `first_floor_map_test` header ("floors 2..5") predate 7 floors | stale | `achievements.json`, test |
| G7 | Five ch1 block-brain matches in no pool | orphan data | `chapters.json:162-425` |
| G8 | `region_preview` shows the un-shifted scaling row; understates Kiep ≥ 4 | [I] | `game_flow.gd:967` |
| G9 | Treasure relic count hard-coded 3 in GameFlow instead of `source_rules.treasure.count` | smell | `game_flow.gd:2530-2550` |
| G10 | Execute offer ignores luck (TD-031) | open debt | `fate_logic.gd:70-82` |
| G11 | No 7-floor run baseline; TD-027 (spread 30–45 pts between regions, won runs 25–30 min vs 40–50 target) open | missing evidence | tech-debt register |
| G12 | `run_modifiers` only honour `step_cooldown` in combat | partial feature | `combat_view.gd:391` |

None of these is fixed by this task (design only). G4, G6, G7 and G9 are cheap fixes to fold into the migration
(§05); G11 is the first thing the validation plan measures (§06).

---

## 5. What the redesign must preserve (non-negotiables confirmed against code)

1. **Combat identity**: pickup → place polyomino → cast; one player vs one enemy; no basic attack. The redesign adds
   nothing that bypasses placement.
2. **Every match id, name key, role, tier and pool membership** in `chapters.json`; `teach_after`; `min_floor` /
   `max_floor` semantics; `onboarding_tier_cap`.
3. **Deterministic generation** for the same `(run_seed, region, floor, kiep, cleared_bosses)`.
4. **Save/load at every exit point** and the `needs_restart` path for saves older than the new version.
5. **The 60-card pool, relics, events, shop and fate** as content; only their *selection* and *tiering* change.
6. **Mobile touch-first UI** at 1280×720 landscape: tap-select then tap-confirm; angular shapes; bare icons without
   boxes on map nodes; no circles except the joystick (user rules).

---

## A1 — Roster appendix (from the combat audit)

Pools: B battle, D danger, M miniboss, X boss; digit = tier. All ids verbatim from `chapters.json`.

**ch1 Misty Forest** (pattern brain): goblin_scout B0 · rootling B0 B1 · mossbound_sentry B0 B1 B2 D2 ·
greycap_sporeling B1 B2 D1 · goblin_archer B1 B2 D1 D2 · dire_wolf B1 B2 D1 D2 · ancient_root_sentinel M1 M2
(teach_after rootling, mossbound_sentry) · wolf_alpha M1 M2 (teach_after dire_wolf, goblin_archer) · mistbriar_matron
M2 (teach_after greycap_sporeling, rootling) · goblin_warlock X1 (2×2, 2 phases) · forest_witch X2 (2×2, 3 phases) ·
orphans: wolf, goblin_chief, goblin_warrior, goblin_shaman, goblin_brute.

**ch2 Dungeon**: skeleton B0 · zombie B0 B1 · bat_swarm B1 B2 D1 · slime B1 B2 D1 D2 · ghost B1 D1 (def 12) · reacter
B1 B2 D1 D2 (step_reactor) · cultist B2 D2 · rat_king_guard B2 D2 (row_burner) · jailer M1 M2 (rotten_thrower,
row_burner, seal_caster) · ogre_king X1 X2 (slam).

**ch3 Ice Tower**: frost_sprite B0 · wisp B0 B1 · stone_sentry B1 B2 D1 · snow_wolf B1 B2 D1 · fuse_golem B1 B2 D1 D2
(fuse_cannon) · rime_archer B2 D2 · ice_golem B2 D2 (row_burner) · ghost_elite B2 D2 (def 16) · frost_mage M1 M2
(frost_aura, thorn_field) · mist_lord X1 X2 (frost_aura, phase_shift).

**swamp**: bog_rat B0 B1 · mire_slug B0 B1 (mire_immune) · swamp_lizard B1 B2 D1 · marsh_toad B1 B2 D1 D2 · reed_witch
B2 D1 D2 (rotten_thrower) · bog_hound B2 D2 (row_burner) · spore_cap M1 M2 (spore_burst) · leap_frog M1 M2 (hop_skip) ·
toad_matriarch X1 X2 (mire_immune, bog_spread, seal_caster).

**desert**: dune_jackal B0 B1 · sand_beetle B0 B1 · dust_nomad B1 B2 D1 · mirage_sprite B1 B2 D1 D2 · scarab_guard B2
D1 D2 · sun_archer B2 D2 (row_burner) · sand_burrower M1 M2 (burrow) · scorpion M1 M2 (riposte) · sand_sphinx X1 X2
(sandstorm).

**hellfire**: imp B0 B1 (forge) · ember_hound B0 B1 (caldera) · ash_golem B1 B2 D1 (def 3, forge) · flame_cultist B1
B2 D1 D2 (row_burner, caldera) · magma_slug B2 D1 D2 (forge) · hell_knight B2 D2 (def 2, min 3, caldera) · fire_eater
M1 M2 (burn_eater, forge) · ash_phoenix M1 M2 (rebirth, caldera) · inferno_lord X1 X2 (vent_surge, phase_shift
vent_interval_mult 0.7, caldera).

**sky_isles**: cloud_sprite B0 B1 · harpy B0 B1 · wind_monk B1 B2 D1 (crumble) · storm_eagle B1 B2 D1 D2 ·
sky_sentinel B2 D1 D2 (def 3) · thunder_shaman B2 D2 (row_burner, crumble) · gale_bird M1 M2 (gust) · cloud_veil M1 M2
(shroud) · storm_dragon X1 X2 (island_drop, gust, crumble).

**an_dai**: an_dai_keeper (phases: seal_caster → seal_caster + row_burner at 0.5).

Arena shapes (20): square, rect, cross, u_shape, ring, islands_bridge, staircase, diamond, cross_wide, pillars,
an_dai_dais, bog, reed_maze, dunes, oasis, forge, caldera, twin_isles, three_isles, boss_hall. Arena is fixed per
match; `variant: true` toggles 1–3 holes seeded by `hash([floor_seed, match_id])`.

## A2 — Column/index assumptions that a node-id graph touches (from the run-flow audit)

RunSession: `column` + `node_index` position model; `linked_indices` reads only `column-1`; `complete_node` does
`column += 1`; region end = `kind == "boss"`; `from_dict` bounds checks on column / node_index; `_clean_map` keeps only
`kind, match_id, next`; `floor_seed = arena_seed_for(run_seed, floor*100 + column)`; `is_last_floor` shim.
ChapterMapGen / ChaptersConfig: column spec; `link_columns` i→i+1 only, `ci == 3` rule; `region_spec` tier by column
slot; `special_nodes.column`; `final_map` columns; `KiepRules.apply_map_spec` "not first, not last".
GameFlow: `_node_key = "floor/column/node"`; shop / event / event-fight / gold / relic / reward / ink seeds hash
`(floor, column, node_index | nodes_cleared)`; event fight tier from `current_column().tier`; `ArtAssets.area_for(column,
size, kind)`; public API `get_run_map / get_current_column / get_available_nodes / get_cleared_nodes`; dev walkers
(`_dev_clear_columns`, `_dev_reaches_kind`, `_apply_dev_node fF/region/cC/nN`, `DEV_MAP3_COLUMNS`).
Other: `ProgressState.BEST_FLOOR_MAX`, `SaveSlots.summarize`, `ChapterMapView` (column layout), `WorldMapView` /
`ClimbMap` (one island per `region_order` entry).
