# World Map v2 — autonomous implementation checkpoint

Resume rule: read this file first, then `git status`; never discard existing changes; no commits.
Approved scope: `docs/design/world-map-v2/08-approval-package.md` (D1–D15), the user's "Autonomous Implementation"
brief (2026-11-11/12). Vertical slice = Hellfire floor 2 only; other regions keep v1 behaviour.

## Phase 0 — deterministic baseline

- Status: **done** (2026-11-12; seeded baseline 70 seeds × 5 characters recorded in `baseline-7floor-v1.md` §8)
- Files changed: `tools/balance/deck_sim.gd` (`--region-pick=order`), `tools/balance/README.md`,
  `tools/balance/sim_core.gd` (seed `arbiter.zone_rng = match_seed + 3`, `flow.rng.seed = match_seed + 5`).
- Determinism: `order` ×2 IDENTICAL, `first` ×2 IDENTICAL, no-flag ×2 IDENTICAL, no-flag == `--region-pick=random`,
  region picks identical to the pre-change run (`scratchpad/step0/det2_*.txt`).
- Known issue: the first seed alone (`zone_rng`) was not enough — `CutFlow.rng` (timeout card pick) is randomized at
  creation; the sim seeds it too (tool code only).
- Result: `baseline-7floor-v1.md` updated (A/B history kept); run win 10.0–21.4 % (mean 16.0), seeded repeat IDENTICAL.

## Phase 1 — foundation
- Status: **done** (2026-11-12)
- Files added: `src/run/map/map_graph.gd` (MapGraph: ids, edges, caches, to_dict/from_dict, v1 wrapper
  `from_v1_columns`, `v1_node_id` = "c<col>n<idx>"), `src/run/map/map_validator.gd` (structural + v2 layout rules,
  metrics), `src/run/map/region_rules.gd` + `assets/data/region_rules.json` (hellfire v2 + heat; others v1, no rule;
  modifier catalogue), `src/run/map/route_archetypes.gd` + `assets/data/route_archetypes.json` (5 templates, guarantee,
  hub/gamble, objectives). `godot --import` run (class_name registered).
- Tests (all FAILS=0): `tests/unit/run/map_v2/{map_graph_round_trip,region_rules_config,route_archetypes_config,
  map_validator,v1_map_wrapper}_test.gd`; U5 = 200 seeds × 7 assigned pairs wrapped and validated, old-style map
  without `next`, final map. Existing v1 map tests re-run green (see the command log below).
- Decisions recorded: node ids are slot-stable strings; wrapped v1 nodes keep `tier`; rule state saved as {id, gauge};
  warden-hook params normalised to float; typed-array `==` needs parentheses around `as` casts in tests.
- Known issues: none open.
- Next: Phase 2 RegionMapGen + map_sim.

## Phase 2 — route generation
- Status: **done**
- Files: `src/run/map/region_map_gen.gd` (new), `src/run/chapters_config.gd` (+`generate_region_graph`,
  `region_graph_spec`; v1 path untouched), `src/run/kiep_rules.gd` (+`node_weight_mult`, read-only getter),
  `src/run/map/map_graph.gd` (optional `tier`/`gold_mult`/`relic_offer` on nodes), `tools/balance/map_sim.gd` (new).
- Tests: `tests/unit/run/map_v2/region_map_gen_test.gd` U6–U11 FAILS=0 (7000 maps layout, archetype rules, pools,
  teach_after over the graph on ch1, shop plan, event cap).
- Simulations: `map-sim-assigned-10k.txt` (hellfire 10k = 100 % valid; the ch1 floor-1 "failures" were the v2
  floor rule applied to a v1 map — tool fixed, see the note in the file), `map-sim-assigned-10k-forcev2.txt`
  (70 000 / 70 000 valid, p50 0.46 ms, p95 0.79 ms), `map-sim-all-pairs-1k-forcev2.txt` (49 pairs, informational;
  re-run after the teach fix).
- Decisions: the safe lane may add a third heal opportunity (01 §B3 promise) while hub/prepare never double (D13);
  ≤ 2 events per map enforced in generation order (gamble, lanes, hub); an elite nobody on its path can teach
  degrades to a battle of the same tier (pack 02 §3 items 1/6) — ch1 has all three minibosses gated.
- Known issues: none open.

## Phase 3 — encounter composition
- Status: **done**
- Files: `src/run/map/encounter_composer.gd` (new), `src/run/run_config.gd` (`from_node(..., profile := {})`,
  applied after the danger traits, before Kiep; empty profile byte-equal), `src/combat/combat_view.gd` (two
  counters only: `max_cast_cells` in `_count_cast`, `vents_dodged` in `_on_vent_erupted`), objective stat renamed
  `vents_dodged` (vent eruptions on the player's half the player was not standing in — measurable with the existing
  signal; recorded as the D7 counter decision).
- Tests: `tests/unit/run/map_v2/encounter_composer_test.gd` U13–U17 FAILS=0; existing `floor_scaling`,
  `kiep_wiring`, `regions_hellfire_sky`, `chapters23`, `run_session_stats` green.
- Known issues: none open.

## Phase 4 — run state and save v8
- Status: **done**
- Files: `src/run/run_session.gd`: `SAVE_VERSION 8`, `MIN_LOADABLE_VERSION 8` (v5–v7 → needs_restart, D5);
  fields `graph`, `rule_state`, `objectives_met`; `choose_region` builds a v2 graph when `region_rules` says v2 and
  MIRRORS it into the column model (`columns_from_graph`: depth = column, screen order = index, edges = `next`), else
  the v1 column map exactly as before (wrapped for the API); id accessors (`node_id_at`, `current_node_id`,
  `choose_node_id`, `available_node_ids`, `cleared_ids`), `gauge()`, `current_rule()`, `record_objective_met`;
  `complete_node` steps the gauge; `to_dict` adds `map_graph`, `rule_state`, `objectives_met`; `from_dict` rebuilds
  the mirror from the graph (truth) for v2, validates it, clamps the gauge.
- Architecture note (vs 08 §B): position is still stored as (column, node_index) with the graph mirrored into
  columns, so every existing column-addressed rule, seed and screen keeps working; node ids are first-class accessors
  and the graph is the saved truth. `floor_seed()` unchanged (the mirror has columns).
- Tests updated to the approved policy: `boss_fate_test` (v5 → needs_restart), `economy_test` (SAVE_VERSION 8),
  `kiep_wiring_test` (v6 → needs_restart). New: `tests/unit/run/map_v2/run_session_v2_test.gd` U18–U20, U25–U28.
- Known issues: none open.

## Phase 5 — game flow integration
- Status: **done** (flow); UI in Phase 8
- Files: `src/run/game_flow.gd` (profile per live match → `RunConfig.from_node(..., profile)`; objective judged on
  `get_match_stats()` in `_on_match_won`; `choose_node_id`, `get_node_preview`, `get_rule_state`, `get_region_rule`,
  `get_map_graph`; forge: Phase `FORGE`, `_open_forge` (ink row rolled, saved in `RunSession.forge_state`),
  `forge_leave`, `remove_shape` free once; `region_preview` += `map_gen`, `rule`, `warden_traits`, `has_shop`;
  `set_seed_for_test`), `src/run/run_controller.gd` (`match_modifiers` → `match_params["modifiers"]`),
  `src/run/run_session.gd` (`forge_state`, `luck_extra`).
- Tests: `tests/integration/run/world_map_v2_flow_test.gd` (I1 + I2, seeds 24 and 28) FAILS=0; existing
  `run_flow2_test` updated for the v2 floor-2 map (mirror of the graph), `shop_event`, `fate`, `piece_deck`,
  `final_prelude`, `unlock` flows green.
- Decision: the forge reuses the reward screen's ink row machinery (`pending_ink_offer`) and a free
  `RunSession.remove_shape(id, false)`; its screen is drawn in Phase 8.

## Phase 6 — Hellfire Heat
- Status: **done**
- Verified in I1/I2 (live `TileHazards` cfg): heat 1 → vent 6 s, heat 2 → 5 s, heat 4 → 4 s + tick 3; gauge steps
  battle +1, miniboss +2, shop −1, clamp 4; warden hook vents 3 at heat ≥ 3; tier bonus from heat 3; reset on a v1
  region. Other regions: `region_rules.json` `map_gen: v1`, `rule: ""` (proposals as `_proposed_rule` text only).

## Phase 7 — rewards and economy
- Status: **core done; simulation pending** (deck_sim route policy)
- Files: `assets/data/rewards.json` (+`reward_tiers` 1/2/3, `node_rewards.forge`; economy.json untouched, D14),
  `src/run/reward_roller.gd` (`tier_rule`, `reward_for_node_tier`), GameFlow gold mult (node × tier × objective),
  relic rows (tier 3 / elite miniboss / objective, source `event`, ≤ 3), `luck_extra`.
- Verified in I1: tier-3 node paid gold ×1.6 and a relic row; objective bonus; luck +4 over the peril lane.
- Next: `deck_sim --route-policy` + v2 map walk, S2 paired comparison (Phase 9).

## Phase 8 — UI
- Status: **done** (captures re-run after the climb-panel rows were added; see `ui/`)
- Files: `src/run/chapter_map_view.gd` (lane bands per archetype with labels, code-drawn angular forge glyph, tier
  diamonds, Heat meter under the floor banner, the preview panel: kind · lane, enemy · arena · modifiers, tier ·
  objective · heat before -> after), `src/run/world_map_view.gd` (climb briefing rows: rule + one line, shop at the
  crossing; the old 1-of-2 card gets the same line), `src/run/piece_deck_view.gd` (FORGE screen: title, two "Học
  <hình>" buttons in the title band = the ink row, free-removal line, Close = forge_leave), `src/run/game_flow.gd`
  (piece-deck rows honour the free removal), `assets/i18n/strings.csv` (+38 rows vi/en: node.forge, route.*, rule.heat,
  mod.*, objective.*, ui.map.*, ui.world.shop_here, ui.forge.*).
- Evidence: `tests/integration/run/world_map_v2_evidence.gd` (windowed, `--audio-driver Dummy`, seeds 24 / 28) →
  `production/qa/evidence/world-map-v2/ui/E1..E7` (climb briefing, three lanes, peril previews, heat 3 / 4,
  warden preview, forge node + forge screen, resumed map identical to the pre-reload frame).
- Touch: nodes keep `map_route_node_hit_rect` (≥ MIN_TOUCH_SIDE); ink buttons ≥ MIN_TOUCH_SIDE tall; tap-select /
  tap-confirm unchanged; angular shapes only (parallelogram bands, diamonds, chamfered pouch), no circles.
- Known limitations: the in-battle intro band does not show modifier icons (the preview and `match_params.modifiers`
  carry them; display-only, not started); hub/approach nodes have no band (by design); legend has no forge entry
  (no pixel icon; the glyph is code-drawn).
- Pre-existing noise: `Parameter "obj" is null` from `src/audio/ui_audio_bridge.gd:35` when a main scene is freed in
  tests (also in `run_flow2_test`), unrelated.

## Phase 9 — validation and evidence
- Status: **done** (2026-11-12) — final suite on the final code `full-suite-final-2026-11-12.txt` = 286 / 286 green (1572 s)
- Found and fixed during validation: the probe bot left its lane at the hub (the existing node policy picks by kind),
  so the first probe pass measured two lane nodes only; `deck_sim` now keeps `route_lane` past the hub when a route
  policy is set (the game lets the player switch there). `boss_downed_test` asserted the exact stats-key count (9)
  → updated to 11 (the two D7 counters). `i18n_test`: `TEXT_ROUTE_NAME_FORMAT` → `ROUTE_NAME_KEY_FORMAT`;
  `terminology_scan_test`: three modifier names → glossary trait names.
- Results: `route-sim-2026-11-12.md` (Peril +37 % NV vs Safe = met; Peril deaths +16.9 pts = NOT met; run-level
  guard met, mean win 16.0 → 15.7), `full-suite-2026-11-12.txt` (282/286 green, the 3 real failures fixed, the 4th is
  the 240 s timeout of `pattern_roster_fairness_test` under load).
- Docs: `assets/data/schema.md` += route_archetypes / region_rules / reward_tiers / save v8; `04` "As implemented";
  `05` status; `06` results note; README status.
- Deliverable: `final-implementation-report.md` — recommendation **ready for playtest, needs tuning** (Peril risk).

## Phase 10 — balance and playtest validation (user brief "Balance & Playtest Validation", 2026-11-12)
- Status: **done** — report `balance-validation-2026-11-12.md`; raw `balance/` (90 experiment + 15 replicate files,
  `run-experiments.sh`, `run-replicate.sh`, `aggregate.py`), `variants/` (A, B, C, v1 reference).
- Decision: **variant C adopted** — `route_archetypes.json` peril `modifier_slots` [0,1,2] → [0,1,1] (Peril death gap
  vs Safe +16.9 → +9.2 pts, inside the ≤ +10 band; NV +51 %; run-level guard met on 140 seeds). A (heat 3 vent tick
  3 → 2) is invisible to the bot (identical output); B (heat 4 vent 4.0 → 4.5 s) is noise (+0.4). Heat unchanged.
- Simulator fixes (tool only): forge nodes were played as a default fight; event-led (Mystery) lanes were missing from
  the ROUTE table (the "Mystery never appears" finding was this, not rarity: 48.6 % of 10k maps); a death in an event
  fight did not end the route. Added `--region-rules=` / `--route-archetypes=` flags, the ROUTE2 instrumentation row
  (heat at warden, objective fights, relic rows offered / taken, inks, forge, HP in fights vs healed), map_sim ARCH rows.
- Finding for the user: only 8–27 % of routes reach the warden at heat 3–4 (design intent ≥ 60 % on Peril) — the hub
  shop (−1) and prepare rest (−2) decay it; not changed (design question).
- UI: intro band shows the encounter's active modifiers (`run_hud_view.gd`, left block); `ui-balance-2026-11-12/E8`
  (two modifiers, pre-tuning) and `ui-balance-2026-11-12-C/` (tuned set). Flow test asserts the plumbing + layout.
- Tests updated to the tuned value: `route_archetypes_config_test` U3, `world_map_v2_flow_test` I1. Docs: 01 §B3, 03 §3,
  08 §B, schema.md. Regression: v2 suites + flow green, map_sim 70 000 / 70 000, determinism identical, full suite 286 / 286 green
  (`balance/full-suite-balance-2026-11-12.txt`).

## Phase 11 — Heat Decay Experiment D (user brief "Heat Decay Experiment D", 2026-11-12)
- Status: **done, waiting for the user's decision** — report `heat-decay-experiment-2026-11-12.md`; raw `heat-decay/`
  (50 C probes + 50 D probes + 10 D full runs, two seed sets 2002..2071 and 3002..3071, `run-heat-decay.sh`,
  `aggregate-heat.py` -> `aggregate-heat.md`); variant `variants/region_rules_D.json` (rest -1, nothing else).
- Production data NOT changed: `region_rules.json` rest -2 (C), `route_archetypes.json` peril [0,1,1] (C).
- Result: D raises warden heat 3-4 reach peril 30 -> 45 %, elite 26 -> 55 % (hook fires on exactly those); rest on
  peril 2.74 -> 1.74 instead of -> 0.74; shop unchanged. Peril NV +57 % vs safe (met), run-level guard met
  (13.3 -> 16.0 % mean win), other lanes flat. Death gap +11.1 vs +8.8 under C: NOT met nominally, but the peril side
  is unchanged (80.8 -> 80.6) and the move is on safe clear (+2.1, noise; D has no mechanism for it).
- Verdict: inconclusive on the death gap -> retain C; recommend D after a human warden playtest at heat 3-4 (the bot
  never takes vent damage, so the sim prices D's main effect at zero). Design intent >= 60 % peril at heat 3-4 still
  unmet under D (hub shop -1 + rest -1 in the way).
- Tool code only: `deck_sim.gd` ROUTE3 row (rest/shop heat before -> after, warden hook fired %) + `route_hook` field.
  No game code, data or tests changed; full suite not re-run (last: balance pass 286/286).

## Phase 12 — human playtest preparation, Hellfire warden at Heat 3 / 4 (user brief, 2026-11-12)
- Status: **prepared, waiting for the user's playtest** — `human-playtest-heat-decay-2026-11-12.md`; evidence folder
  `human-playtest-heat-decay/` (dev-launch frame seed 24, seed scan 1-60 output, scan script copy). No code / data /
  test change; production stays on C.
- Launch path (existing DEV args): `--region=hellfire --at-floor=2 --seed=27 --lang=vi --character=<id>` (memory
  store). Seed 27 reaches the warden at Heat 2 (peril + forge), 3 (elite + forge) and 4 (gamble) under C; alternates
  seeds 49, 6, 24.
- F1: C and D are the same fight at the same Heat (composer reads the integer gauge only) -> C3 = D3, C4 = D4; the
  playtest compares Heat 2 / 3 / 4. True-D routes would need a DEV `--region-rules=` arg in GameFlow (proposed, not
  implemented) or a temporary file swap (excluded).
- F2 (finding): the warden hook "vent_surge vents 3" is a no-op in the caldera (2 vents per half; the boss's own
  surge already fires both; probe: trigger_vents(PLAYER, 3) started 2). Heat >= 3 on the warden = clock 4.5 / 4 s,
  burn 3 per tick, boss drops x0.9 only. Design decision for the user (third vent or another hook parameter).

## Phase 13 — warden Heat hook investigation (user brief, 2026-11-12)
- Status: **proposal, waiting for approval** — `warden-heat-hook-investigation-2026-11-12.md`. No code / data / test
  change; production on C with the shipped hook (vents 3).
- Root cause: a vent is a whole {row}/{col} line; caldera (the warden's only arena) has 2 per half; the boss's own
  vent_surge already fires both; the hook's `vents 3` is clamped by `trigger_vents` (starts up to count, idle only).
  No arena anywhere has 3 vents. The Heat-4 row's vent_surge entry is deduped on the warden too.
- Option A (third vent, row 2 is the only fair line) changes every caldera fight and the Heat 0-2 baseline, does not
  separate 3 from 4 -> not recommended. Option B1 (recommended, data only): hook -> `interval_sec 7, first_delay_sec 10`
  (drop vents), Heat-4 row += `vent_sec 2.5`; warning 1.0 s untouched. Progression: surge every 10 / 7 / 7 s, burn
  2 / 2 / 2.5 s, clock 5 / 4.5 / 4 s, tick 2 / 3 / 3. B2 (optional code, ~15 lines): trait_params in by_gauge rows.
- Tests after: arena-vs-vents invariant (new, fails on today's data), trigger_vents clamp, first_delay_sec, 3 updated
  suites (region rules, composer U13/U15, flow I2). Sim cannot evaluate (bot dodges); human playtest decides.

## Phase 14 — warden Heat hook fix, variant B1 (user brief "Implement Hellfire Warden Heat Hook Fix", 2026-11-12)
- Status: **implemented, waiting for the user's review** — report `warden-heat-hook-implementation-2026-11-12.md`;
  evidence `warden-hook/` (invariant before/after, suite outputs, full suite, probes). Nothing committed.
- Data (`assets/data/region_rules.json` only): hook `vent_surge {vents 3}` -> `{interval_sec 7, first_delay_sec 10}`;
  heat-4 row += `vent_sec 2.5`. Rows 1-3, gauge (rest -2, shop -1), modifiers, pools, `route_archetypes.json` ([0,1,1]),
  `arenas.json`, `chapters.json` untouched. Warden: surge 10 / 7 / 7 s, burn 2 / 2 / 2.5 s at heat 2 / 3 / 4, warning 1 s.
- Tests: new `tests/unit/run/map_v2/vent_surge_arena_invariant_test.gd` (every vent_surge `vents` <= the vents of the
  arenas it can play in; FAILS=1 on the old data, 0 after); `hazard_test` += trigger_vents clamp block;
  `region_traits_test` += first_delay_sec (7 s / 10 s: none at 9.9, one at 10, two at 17); updated
  `region_rules_config_test`, `encounter_composer_test` U13/U15, `world_map_v2_flow_test` I2. No src/ change.
- Docs: 02 §Heat table + hook paragraph, 03 §4 hook note, 08 post-approval note, schema.md `rules.<id>` row,
  tools/balance/README ROUTE3 wording. B1 numbers are proposed for the human playtest, not confirmed by it.

## Phase 15 — B1 full balance validation, 5 characters x 2 seed sets (user brief, 2026-11-12)
- Status: **done, PASS on the existing criteria** — report `b1-balance-validation-2026-11-12.md`; raw `b1-balance/`
  (10 runs, 15:46-16:18, all exit=0, `run-b1-balance.sh`, `aggregate-b1.py` -> `aggregate-b1.md`). Paired with
  `balance/C-full-value-*` (set 2001) and `balance/rep-C-full-value-*` (set 3001); C evidence untouched.
- Pooled run win 13.3 -> 13.3 % (+0.0, criterion +-10); duration 33.15 -> 32.77 min (-1.1 %, criterion +-2 %);
  per character -1.4 ... +2.8 pts; hellfire clear 85.4 -> 84.6 (-0.8, 102 -> 108 deaths of 700, inside noise; peril
  lane 82.8 -> 81.5); economy -1 % with shorter runs, gold per won run +0.4 %; warden heat distribution identical.
- Caveat: the bot evades vents — no human fairness claim; vent damage not instrumented. No parameter changed, nothing committed.

## Phase 16 — B1 human Warden playtest preparation (user brief, 2026-11-12)
- Status: **prepared, NOTHING PLAYED yet** — `human-playtest-b1-warden-2026-11-12.md` (H2 / C3 / C4 on seed 27,
  character coverage sat_thu > giao_si > kiem_si (> phap_su, tho_san), 2 runs per scenario, rating checklist 1-5,
  empty result log, decision rules); evidence `human-playtest-b1/` (seed-27 paths + live B1 warden probe at Heat 4:
  surge 7 s / first 10 s / vents 2 / vent_sec 2.5 / warn 1.0; launch frame with --character=sat_thu).
- The earlier `human-playtest-heat-decay-2026-11-12.md` got a dated "superseded for B1" banner; its F2 note is
  historical (pre-B1), left as written.
- State of validation: B1 full simulator validation PASSED (Phase 15); human playtesting is the remaining
  validation step. No gameplay parameter, data, code or test changed in this phase; nothing committed.

## Phase 17 — B1 warden bot playtest (user: "bạn xài bot test giúp tôi đi", 2026-11-12)
- Status: **done (bot, not human)** — `human-playtest-b1/bot/bot-playtest-report-2026-11-12.md`; 48 live warden
  fights via a scratchpad driver (EncounterComposer profile -> RunConfig.from_node -> enter_test_floor, play_bot loop
  + vent policy). B1 timing confirmed live (first surge 10.0 s, gaps 10.1 / 7.0 / 7.0 s on the match clock).
- Dodge 0.3 s (30 fights): 26 W, 3 vent hits / 8 dmg total, 0 unescapable, 0 cast-locked hits; losses = boss cuts.
  Dodge 0.6 s: 15 dmg / 9 fights. Naive: ~18 / 36 / 54 vent dmg per fight at Heat 2 / 3 / 4, 2 of 3 Heat-4 deaths.
- Still open for a human: fun, readability, cost of dodging to a planned combo. No data / code / test changed.

## Decision — B1 kept (user, 2026-11-12, "Giữ B1")
- After Phase 15 (simulator PASS) and Phase 17 (bot playtest: timing confirmed, 0 unescapable warnings, ~0 vent
  damage at 0.3 s reaction, ≈18 / 36 / 54 for a non-dodger), the user chose to keep B1: hook
  `vent_surge {interval_sec 7, first_delay_sec 10}`, heat-4 `vent_sec 2.5`, rest -2, shop -1, peril [0,1,1].
- Open: human ratings (fun, readability, combo cost) in `human-playtest-b1-warden-2026-11-12.md` §8; the next World
  Map v2 region still waits for the user's approval. Nothing committed (the user gathers the commits).
