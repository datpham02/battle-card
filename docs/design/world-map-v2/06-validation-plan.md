# 06 — Validation plan (revised 2026-11-11, second pass)

> **Results (2026-11-12):** executed for the Hellfire slice — `production/qa/evidence/world-map-v2/final-implementation-report.md`
> (§4 tests, §5 balance, §6 save/load, §7 UI, §8 what was not met: Peril's death-rate band). Detail:
> `route-sim-2026-11-12.md`, `map-sim-*.txt`, `full-suite-*.txt`, `ui/`.
> **Balance pass (2026-11-12):** `production/qa/evidence/world-map-v2/balance-validation-2026-11-12.md` — Peril
> death band met with variant C (peril modifier_slots [0,1,1]); §6 lists what the simulator measures and what it cannot.
> **Heat decay experiment D (2026-11-12):** `production/qa/evidence/world-map-v2/heat-decay-experiment-2026-11-12.md` —
> rest −1 tested, not adopted (production stays C): warden heat 3–4 reach rises peril 30 → 45 %, elite 26 → 55 %;
> lanes flat; death gap nominally +11.1 (noise on the safe side). Decision waits for the user and a human warden playtest.

Status: Proposed. Rule from the brief: **baseline first; no number below is a result.** Every target is a gate to
measure. Metrics are tagged **[BLOCK]** (release-blocking for the slice) or **[INFO]** (recorded, discussed, never a
gate by itself). Every percentage names its numerator, denominator and population.

## 1. Baseline — does a 7-floor v1 baseline exist, and can the sim produce one?

**Verified in `tools/balance/deck_sim.gd` (2026-11-11):**
- `--run=v6` turns on world mode; without `--floors` the run plays `_f_range(floors)` = floors 1..`world.floors`
  (`_floors_b = -1` → `last_region = floors - 1`), i.e. **all 7 floors**, then the final when `--final` is not
  `off` (`deck_sim.gd:2994-2995`). The README line "5 floors" (`tools/balance/README.md:11, 793`) is stale text; the
  code reads `ChaptersConfig.world_floors()`.
- The region of each floor is drawn with `WorldMapGen.offer_for_floor(...)` and `--region-pick=random|first`
  (`deck_sim.gd:1557-1559`, `REGION_PICKS`). It **does not read `world.region_order`**. So today's sim plays a
  *random* 7-region order, not the shipped fixed climb. The audit's "no 7-floor baseline" stands, and the earlier
  draft's baseline command would have produced a run that no player can play.
- World mode uses its own `WorldRun` state, not `RunSession` (`deck_sim.gd:20-21`): the sim measures the economy and
  matches, not save/load.
- Main runs use `CLEARED_BOSSES_MAIN = 1` (tier 2 unlocked), one onboarding set only on chapter 1.

**Reproducible baseline definition (step 0 of `05`):**
1. Tool change (tool code, not game code; needs the user's OK as part of approving the plan): `--region-pick=order`
   → `WorldMapGen.floor_offer(chapters.region_order(), pool, seed, f, path)` (the function the game uses), so the sim
   walks `ch1, hellfire, desert, swamp, ch2, ch3, sky_isles`.
2. Command (flags verified to exist: `--run=v6 --seeds --seed-offset --characters --policies --shop-policy
   --event-policy --relic-policy --tables --final --region-pick`):

```
GODOT=C:/Users/ADMIN/AppData/Local/Microsoft/WinGet/Links/godot.exe
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --run=v6 --region-pick=order --seeds=70 --seed-offset=2001 \
  --characters=kiem_si,phap_su,sat_thu,tho_san,giao_si --policies=build --shop-policy=greedy --event-policy=risky \
  --relic-policy=pick --tables=v6 --final=on > production/qa/evidence/world-map-v2/baseline-7floor-v1-raw.txt 2>&1
```

3. Seed set: run seeds 2002..2071 (`--seed-offset=2001`, the Story 040 convention). The same 70 seeds are used for
   every later paired comparison (§6).
4. Recorded per character: run win % (won runs / 70), won-run minutes (p50, p95), nodes visited, gold earned / spent /
   left, cards gained, relics **acquired**, inks applied, boss hits, HP at each warden entry, death floor histogram.
   Per (region, assigned floor): match win % (wins / matches played there).
5. File: `production/qa/evidence/world-map-v2/baseline-7floor-v1.md` (+ raw). Until that file exists, every
   comparison in this plan is **not runnable**.

**Step 0 result (2026-11-11):** the baseline was run twice (replicates A and B) in the climb order; report and raw
files in `production/qa/evidence/world-map-v2/baseline-7floor-v1.md`. Finding that changes this plan: `deck_sim` is
**not run-to-run deterministic** (unseeded `SwingArbiter.zone_rng` in `sim_core`, see the report §3), so §6's paired
design needs either the one-line seeding fix (recommended, user's OK required) or replicate pairs with the report's §4
noise as the floor for any claimed difference.

Known limits of the baseline (carry into every reading): the bot's telegraph dodge 0.85 was never anchored to a
playtest (TD-006); the shop/relic policies are static (TD-037). The baseline is a *relative* yardstick for v1 vs v2
under the same bot, never an absolute difficulty claim.

## 2. Map quality — generator validation (pure, `tools/balance/map_sim.gd`, no combat)

**Populations and seed scopes (reconciled):**
- **Progression population** = the 7 *assigned* (region, floor) pairs of `region_order` (ch1 f1, hellfire f2, desert
  f3, swamp f4, ch2 f5, ch3 f6, sky_isles f7). Gates apply here.
- **Generality population** = every (region, floor) pair, 7 × 7 = 49 (the generator must accept any pair because
  `WorldMapGen.offer_for_floor` still exists and the "1 of 2" mode may return). **[INFO]** only.
- Seeds: `map_sim` 10 000 per pair (ADR-0001 D3 / pack task E); the unit test `U7` runs 1 000 per assigned pair on
  every suite pass (≈ 7 000 maps, budget < 10 s headless); regression seeds `[1, 7, 42, 1234, 99991]` plus edge seeds
  `0`, `1`, `2^31 − 1` in every unit test.

| Metric | Tag | Numerator / denominator | Target |
|---|---|---|---|
| maps with a path entry → warden | BLOCK | maps with a path / maps generated (70 000 progression) | 100 % |
| nodes reachable from entry | BLOCK | reachable nodes / all nodes (14 × maps) | 100 % |
| nodes with ≥ 1 out-edge (except warden) and ≥ 1 in-edge (except entry) | BLOCK | conforming nodes / all nodes | 100 % |
| maps whose 3 lanes have 3 distinct archetypes with ≥ 1 of safe/treasure | BLOCK | conforming maps / maps | 100 % |
| maps with a hub, a prepare, a gamble, a warden in their slots | BLOCK | conforming maps / maps | 100 % |
| match ids drawn from the node kind's pool at a legal tier | BLOCK | conforming fight nodes / fight nodes | 100 % |
| `teach_after` honoured on every path (ch1 f1 only) | BLOCK | conforming maps / ch1 maps | 100 % |
| hub = shop on shop-plan floors; ≤ 5 shops per run; ≤ 2 events per region | BLOCK | conforming maps / maps (shops per run: over 10 000 run seeds × 7 floors) | 100 % |
| kinds respect `min_floor` / `max_floor` (danger, miniboss, event) | BLOCK | conforming nodes / nodes | 100 % |
| determinism: generate twice, `to_dict` byte-equal | BLOCK | equal pairs / maps | 100 % |
| distinct archetype triples per assigned pair over 10 000 seeds | INFO | distinct triples (max 10) | ≥ 6 |
| lanes of one map with identical `(kinds, reward tiers)` sequence | INFO | maps with ≥ 2 identical lanes / maps | 0 % |
| repeated match id on one lane | INFO | lanes with a repeat / lanes | 0 % |
| distinct match ids per map (hellfire: 9 ids for 11 fight slots max) | INFO | mean over maps | ≥ 8 |
| generation time per map, headless | BLOCK | p50 / p95 over 10 000 maps (`Time.get_ticks_usec`) | p50 < 3 ms, **p95 < 8 ms** |

Validator rules are the single source of truth: `MapValidator.validate` implements every BLOCK row; `map_sim` only
counts and prints.

## 3. Risk and reward — route simulation (paired, `deck_sim` with route policies)

**Tool change:** `--route-policy=safe|treasure|peril|elite|mystery|random|value` (new flag, tool code). The bot takes
the named lane at depth 1 when present (else `random`); `value` takes the lane with the highest preview-only net
value (§3.3, the O-preview oracle). Route policy applies at the fork; hub-exit and approach choices follow the
existing node policy.

**Population:** the 70 baseline seeds × 5 characters, Hellfire floor 2 (slice), the run started at floor 2 with the
starter deck (the existing `--floors=2..2 --final=off` probe semantics, verified in README line 793) — so lane
effects are not confounded by floor-1 variance. Later: `--floors=1..7` paired runs (§6).

### 3.1 Net value definition

For one region visit, with weights anchored in `economy.json` (shop prices, verified) so that every term is in
**gold-equivalent**:

```
NV = ΔG                                   gold earned − gold spent on the lane's own nodes
   + Σ cards gained × value(rarity)        common 30, rare 40, epic 60  (shop card prices)
   + relics_acquired × value(rarity)       common 50, rare 70, epic 90  (shop relic prices)
   + inks_applied × 45                     (shop remove_shape price as the piece-deck anchor)
   − HP_combat_loss  × 1.6 / 1 % max HP    (shop heal: 40 gold for 25 % → 1.6 gold per 1 %)
   − HP_route_cost   × 1.6 / 1 % max HP    (Swamp toll; 0 in the slice)
   − P(death on this lane) × V_run         V_run = mean gold-equivalent of a completed run from the baseline (§1)
```

`HP_combat_loss` and `HP_route_cost` are reported **separately** as well as inside NV. Relics are reported as
**offered** (rows shown) and **acquired** (picked) in two columns; only acquired enter NV.

### 3.2 Metrics

| Question | Measure (per lane, mean over 350 region visits = 70 seeds × 5 characters) | Tag | Target |
|---|---|---|---|
| does Peril pay? | NV(peril) − NV(safe), paired by seed × character, bootstrap 95 % CI | BLOCK | lower CI bound ≥ +25 % of NV(safe) |
| what does Peril cost? | HP_combat_loss(peril) − HP_combat_loss(safe), % max HP; death rate = deaths / visits | BLOCK | +15…+25 pts; death rate ≤ safe + 10 pts |
| is Elite worth it? | relics acquired per visit; miniboss loss rate = losses / miniboss fights | INFO | ≈ 1 relic per visit; loss ≤ 20 % at floor 2 |
| Treasure vs Safe | ΔG, inks applied | INFO | ΔG ≥ safe + 20 %; +1 ink |
| Mystery variance | std(NV) vs safe; mean within band | INFO | ≥ 1.5× safe std; mean ±10 % of safe |
| Heat | gauge at warden entry (histogram); warden win % by heat = wins / warden fights at that heat | BLOCK | heat 3–4 reached on peril ≥ 60 % of visits; warden win % at heat 4 ≥ heat 0 − 15 pts |
| run-level guard (TD-027) | per-character win % and won-run p50 minutes, v2 vs v1 paired (§6) | BLOCK | within ± 10 pts / ± 15 % unless a tuning decision says otherwise |
| region spread | max − min of match win % across the 7 assigned pairs | INFO | ≤ 15 pts (TD-027 target) |

### 3.3 Information sufficiency — the oracle policy

Question: does the preview give the player enough to choose well? Two oracles, both restricted to information
**visible before the depth-1 decision**:

- **O-preview**: reads only the preview contract (`03` §7): lane archetypes, node kinds, reward tiers, modifier ids,
  the enemy name + role of depth-1 nodes, the gauge and its published step table, the shop/rest presence at hub and
  prepare. Enemy difficulty is taken **only from the node's tier and kind** (no per-enemy knowledge). It scores each
  lane with NV using the *published* tables (tier → gold mult / rarity floor / relic row) and a fixed HP-cost prior per
  kind (battle 8 %, danger 14 %, miniboss 20 % of max HP; priors come from the baseline §1, not tuned by hand).
- **O-expert**: O-preview plus per-enemy-id loss rates and HP loss from the baseline (a veteran's memory). Still
  nothing hidden: no event outcomes, no shop stock, no hidden-node content.
- **Hindsight**: the lane with the highest realised NV for that seed × character, from the full simulation (all three
  lanes played from the same state).

Metric: **agreement** = decisions where the oracle's lane == hindsight lane / all depth-1 decisions (350). Target:
O-preview ≥ 55 %, O-expert ≥ 65 % **[INFO]** (three lanes → chance 33 %). A low O-preview with a high O-expert means
the preview hides what matters (enemy identity) — a UX finding, not a balance one. Hindsight ties (NV within 5 %)
count as agreement.

## 4. Automated tests (new; naming per `.claude/rules/test-standards.md`, SceneTree scripts printing PASS/FAIL and `FAILS=N` like the suite)

Unit (`tests/unit/run/map_v2/`):
- U1 `map_graph_round_trip_test` — to_dict/from_dict, edge caches, unknown id → null.
- U2 `region_rules_config_test` — loader defaults, bad values, gauge steps, combat patch by gauge.
- U3 `route_archetypes_config_test` — templates, weights, min_floor, modifier_slots, `forge` alternative.
- U4 `map_validator_test` — accepts a valid graph; rejects each error class (dead end, unreachable warden, duplicate
  archetype, missing hub/prepare/gamble, kind illegal for the floor, match not in pool, edge to unknown id).
- U5 `v1_map_wrapper_test` — every v1 map of the 7 assigned pairs over 200 seeds wraps into a valid graph; `next` →
  edges; column index → depth.
- U6 `region_map_gen_determinism_test` — same inputs twice → equal dicts; a different floor or seed → different map;
  seeds 0, 1, 2^31 − 1.
- U7 `region_map_gen_layout_test` — 1 000 seeds × 7 assigned pairs: 14 nodes, 20 edges, 7 depths, slots, 3 distinct
  archetypes, the safe/treasure guarantee (**layout test**).
- U8 `region_map_gen_archetype_rules_test` — floor 1 never peril/elite; `min_floor` overrides per region; weights
  honoured over 10 000 draws within ± 3 pts (**archetype test**).
- U9 `region_map_gen_pools_test` — every match id in its kind's pool at a legal tier; `tier_delta −1` falls back
  upward when tier 0 is empty (every region's `danger` tier 0 is `[]`); no repeat on a lane.
- U10 `region_map_gen_teach_after_test` — ch1 f1: every path to an elite passes a teacher.
- U11 `region_map_gen_shop_plan_test` — hub = shop exactly on `shop_floors(run_seed)` floors + floor 1; ≤ 5 shops per
  run over 10 000 run seeds; prepare never shop when the hub is; ≤ 2 events per region (**shop-plan test**).
- U12 `region_map_gen_map_effects_test` — tags by rule id (`hidden`, `buried`, `locked`, `key`); none for heat.
- U13 `encounter_composer_profile_test` — modifiers from the region pool by slot count, dedupe with match traits,
  `big_hands` guard on `boss_min_runes ≥ 3`.
- U14 `encounter_composer_preview_test` — hidden masking keeps kind / archetype / tier.
- U15 `run_config_profile_test` — empty profile → `from_node` result byte-equal to today; patch applied after danger
  traits; `boss_min_runes_add` resolves into `boss_min_runes`.
- U16 `objective_eval_test` — each objective from a stats dict; missing counter → not met.
- U17 `modifier_catalogue_test` — every modifier resolves to a `TraitRegistry.SCRIPTS` id or a whitelisted key.
- U18 `run_session_v2_progression_test` — `available_nodes` by edges; `choose_node(id)`; `complete_node` advances by
  graph; warden by slot; region end by slot not by kind.
- U19 `run_session_rule_state_test` — gauge steps per kind, clamp, reset on `_enter_region`.
- U20 `run_session_floor_seed_test` — `floor_seed()` by `hash([floor, node_id])`, stable across save/load.
- U21 `heat_combat_patch_test` — table `02` §2 by gauge; warden hook at ≥ 3; patch keys ⊂ `HAZARD_OVERRIDE_KEYS ∪ {boss_drop_interval_mult, traits}`.
- U22 `heat_reward_tier_test` — tier bonus at ≥ 3, cap 3.
- U23 `heat_gauge_preview_test` — preview shows heat before and after the node.
- U24 `reward_tiers_test` — `reward_for_node(kind, tier)`; tier 1 == today's table for every kind.
- U25 `run_session_v8_save_test` — round trip at **every exit point**: entry chosen, lane node chosen, hub open
  (shop_state/event_state keyed by node id), approach, warden chosen, fate pending, reward pending, ink pending,
  forge open; `rule_state` and `objectives_met` kept.
- U26 `run_session_old_save_test` — v5, v6, v7 fixtures → `needs_restart` + `RESTART_OLD_SAVE`; v4 unchanged path.
- U27 `run_session_invalid_v8_test` — see §8 edge cases; save size < 32 KB asserted.
- U28 `run_session_mixed_generators_test` — floor 1 v1 map → floor 2 v2 map → floor 3 v1 map in one session; the graph
  API answers identically for both kinds; save/load between each.
- U29 `economy_tier_gold_test` — gold mult by tier; 7-entry floor tables; clamp past the last entry.
- U30 `elite_relic_offer_test` — exactly one relic row on the elite's miniboss, `RelicRoller` source `event`, offered
  ≠ acquired bookkeeping in stats.
- U31 `forge_node_test` — ink offer of 2, one free `remove_shape(id, false)`, token count unchanged, node completes
  on leave.

Integration (`tests/integration/run/`):
- I1 `world_map_v2_flow_test` — GameFlow through the hellfire slice with `--seed`: enter, three lanes offered, choose
  peril, fight carries modifiers (read `CombatView` traits and `TileHazards` cfg), treasure / rest / shop / event /
  forge resolve, warden, fate, floor 3 (desert, v1) reached; `_save_run` at each step; resume from each save.
  I1a = the `from_node(profile)` sub-check runnable at step 3.
- I2 `heat_vents_flow_test` — a match spawned at heat 4: `vent_interval_sec` 4.0 in `TileHazards`, `vent_tick_damage`
  3, `vent_surge` in the trait host; at heat 0 the base numbers.
- I3 `save_migration_and_mixed_resume_test` — the sequence the user asked for: (a) load a **v7 fixture** (floor 1
  mid-map) → `needs_restart` notice → fresh run; (b) play floor 1 (v1) to the warden, save; (c) enter hellfire (v2),
  choose a lane, save; reload → same map, same node, same gauge; (d) play to the warden, fate, save; reload → climb
  screen at floor 3; (e) enter desert (v1), choose a node, save; reload → v1 map resumed. Every reload goes through
  `ProgressState.from_json` → `RunSession.from_dict`.

Existing suites that must stay green: every file under `tests/unit/run` and `tests/integration/run` (271 as of
`docs/skill-v2/21-batch4-report.md`). `map_gen_test`, `map_links_test`, `first_floor_map_test`,
`shop_event_nodes_test` keep testing the v1 path until step 9 retires it.

## 5. Evidence (retained, `production/qa/evidence/world-map-v2/`)

Windowed captures always with `--audio-driver Dummy`, 1280×720, memory stores (`--seed` fixed, named in the file):
E1 climb briefing for hellfire · E2 region map with three lanes, hub, approach, warden, one node selected with its
preview · E3 a Peril node preview with two modifiers and the objective, and the same fight's intro band · E4 the
gauge at heat 4 and the ember-lit bonus star · E5 the warden preview with "heat matters" and the fate screen after it
· E6 a resumed run at a mid-lane save beside E2 (same seed) · plus `baseline-7floor-v1.md`, `map-sim-<date>.md`,
`route-sim-<date>.md`, the full-suite results file.

## 6. Paired comparisons (v1 vs v2)

Every v1/v2 number is a **paired difference** on the same seed set (2002..2071) and the same character, bot and
policies; report mean difference with a bootstrap 95 % CI (1 000 resamples) and the paired sign test, never two
unpaired means. Pairs:
- **Hellfire probe**: `--floors=2..2` v1 vs v2 (route policy `value`) — gold, HP loss, relics acquired, win %.
- **Full run**: `--floors=1..7 --final=on --region-pick=order` v1 vs v2-hellfire-only — win %, won-run minutes,
  gold left, death floor. The only difference between the two runs is floor 2's generator, so the paired difference
  isolates the slice.
- **Dodge sensitivity**: both at `--dodge=0.7,0.85,0.95` (existing flag) — a conclusion that flips with dodge is
  reported as "bot-dependent" (TD-006).

## 7. Technical quality

- Determinism (U6; `map_sim` 10 000 × 7 twice, byte-equal).
- Save/load (U25–U28, I3).
- Full suite green; parse check on every new/modified `.gd`
  (`godot --headless --path . -s res://.claude/scripts/godot-parse-check.gd -- <files>`); `godot --headless --path .
  --import` after new `class_name`s.
- Performance **[BLOCK]**: generation p50 < 3 ms, p95 < 8 ms; `ChapterMapView` draw ≤ 1 frame at 720p with no
  per-frame allocation beyond today's; save size < 32 KB (U27).
- Compatibility: v1 regions unaffected (U28, I3, full suite); `deck_sim` runs both generators.

## 8. Edge cases — specified behaviour (U27 and friends)

| Case | Specified behaviour | Test |
|---|---|---|
| save `node_id` not in the map | `from_dict` → null → "run dropped" path (existing) | U27 |
| save `cleared_ids` holds an id not in the map | the unknown id is dropped with a warning; the run loads | U27 |
| save edge to an unknown id | `MapGraph.clean` drops the edge; if the warden becomes unreachable → null | U27 |
| `rule_state.gauge` out of range or wrong rule id | clamped to the rule's range; unknown rule id → rule `none` with a warning | U27 |
| archetype id unknown in a saved lane | lane kept, archetype shown as `safe` glyph, warning | U27 |
| `region_rules.json` missing entirely | built-in defaults: no rule, templates from `route_archetypes.json` built-ins; v2 still generates a valid map (the slice must not depend on the file existing) | U2, U7 |
| `route_archetypes.json` missing | built-in templates `03` §3 | U3 |
| empty encounter pool for a (kind, tier) | existing `_draw_match` fallback chain (lower tier → any tier → chapter match_ids → `""` with warning); a `""` id turns the node into `battle` from `match_ids`; never an empty fight | U9 |
| every region's `danger` tier 0 is `[]` | `tier_delta −1` on a danger slot falls back **up** to tier 1 (never to an empty tier) | U9 |
| Kiep 3 (`node_weight` danger ×2) | `KiepRules.apply_map_spec` reads v1 `columns`; for v2 the rule is re-expressed as `peril` archetype weight ×2 and `danger` fill weight ×2 inside flexible slots (new branch in `apply_map_spec`, v1 branch untouched) — **unverified until written**; U8 covers it | U8 |
| Kiep 10 (`boss_extra_trait` on the region boss) | applied by `KiepRules.apply_match` after the profile patch; Heat's warden hook and the Kiep trait both apply, dedupe by id | U21 |
| seed 0, seed 1, seed 2^31 − 1, negative seed | masked with `SEED_MASK` as today; negative seeds never reach the generator (`_begin_run` masks) | U6 |
| `depth_layout` malformed in data | fallback to `[1,3,3,1,3,2,1]` with a warning | U3 |
| region with < 3 legal archetypes on a floor | `safe` repeated (the only archetype allowed twice), warning | U8 |
| v1 region after a v2 region in one run | U28 / I3 | — |

## 9. Gameplay checks that are not automated

Playtest notes (step-wise, `05` §5): lane legibility without text; whether Heat changes standing and casting;
whether the floor-2 route is felt on floor 3; whether any modifier reads as "just a stat" (then it leaves the pool).
These are design exit criteria, recorded in the step reports; they never claim a number.
