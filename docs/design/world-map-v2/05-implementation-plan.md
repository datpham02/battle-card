# 05 — Implementation plan and vertical slice (revised 2026-11-11, second pass)

Status: **executed 2026-11-12** (steps 0–9 of §2 under the user's autonomous-implementation brief). Per-step
status, files, commands and results: `production/qa/evidence/world-map-v2/autonomous-progress.md`; the
consolidated results: `final-implementation-report.md` in the same folder. The plan text below is kept as written;
where the implementation diverged, `04-technical-architecture.md` "As implemented" says how and why. Each step is
independently testable and leaves the game playable: the v1 generator stays the default for every region until the
last step. "Floor N" below is **1-based** (the number the player sees, `floor_number` in data); the code's
`RunSession.floor` is 0-based (`floor == N − 1`).

Floor assignments in force (`chapters.json world.region_order`, verified):

| Floor | 1 | 2 | 3 | 4 | 5 | 6 | 7 | after 7 |
|---|---|---|---|---|---|---|---|---|
| Region | ch1 Misty Forest | **hellfire** | desert | swamp | ch2 Dungeon | ch3 Ice Tower | sky_isles | an_dai (shop + keeper) |
| `floor_tiers` | [0,1,1] | [0,1,1] | [0,1,1] | [1,2,2] | [1,2,2] | [1,2,2] | [1,2,2] | final |

## 1. Vertical slice: Hellfire on floor 2 (`RunSession.floor == 1`)

**Why Hellfire** (brief §8 prefers it; the audit agrees): floor 2 is the first floor where every archetype is legal
(`danger` and `miniboss` have `min_floor 2`) and the first `guaranteed_min_floor` for the shop plan; its vents are
already in combat with two override keys (`vent_interval_sec`, `vent_tick_damage`, `RunConfig.HAZARD_OVERRIDE_KEYS`)
and one trait (`vent_surge`) that give the Heat gauge a combat effect with **no new combat code**; its roster is 9
ids in all four pools with two distinct elites.

**Slice scope** (brief §8 items 1–10): climb screen briefing → v2 map → three lanes with previews → node select →
fight / treasure / rest / shop / event / forge resolve → rewards by tier and heat → map with the gauge updated →
warden with the heat hook → fate → floor 3 (desert, **v1 map**) → save and resume at every exit point. Floors 1 and
3–7 stay v1 inside the same run; that is the architecture's main claim (one graph API, two generators).

### 1.1 The Hellfire graph, concretely

Layout `depth_layout = [1, 3, 3, 1, 3, 2, 1]` → 14 nodes, 20 edges, 7 depths. Node ids are fixed by slot so a save,
a test and a screenshot name the same thing in every seed; what the seed decides is the lane archetypes, the
kinds inside flexible slots, the match ids, the modifiers and the hub/prepare kinds.

```
depth   0        1          2         3        4          5           6
      ┌────┐   ┌─────┐    ┌─────┐           ┌─────┐
      │    │──▶│L0.1 │───▶│L0.2 │──┐     ┌─▶│L0.4 │──┐    ┌──────┐
      │    │   └─────┘    └─────┘  │     │  └─────┘  ├───▶│ a1   │──┐
      │ n0 │   ┌─────┐    ┌─────┐  │ ┌───┐  ┌─────┐  │    │prep. │  │  ┌───┐
      │    │──▶│L1.1 │───▶│L1.2 │──┼▶│hub│─▶│L1.4 │──┤    └──────┘  ├─▶│ w │
      │    │   └─────┘    └─────┘  │ └───┘  └─────┘  │    ┌──────┐  │  └───┘
      │    │   ┌─────┐    ┌─────┐  │     │  ┌─────┐  ├───▶│ a2   │──┘
      │    │──▶│L2.1 │───▶│L2.2 │──┘     └─▶│L2.4 │──┘    │gamble│
      └────┘   └─────┘    └─────┘           └─────┘       └──────┘
```

Edges (20): `n0→L0.1, n0→L1.1, n0→L2.1` · `Lk.1→Lk.2` (3) · `Lk.2→hub` (3) · `hub→Lk.4` (3) · `Lk.4→a1, Lk.4→a2` (6)
· `a1→w, a2→w` (2). No other edge exists; lanes never cross except through the hub.

Slots and what fills them on floor 2 (tiers from `floor_tiers["2"] = [0,1,1]`; the pools are the shipped hellfire
pools, verified in `00` §A1):

| Node id | depth | slot | kind (how decided) | tier | pool draw |
|---|---|---|---|---|---|
| `n0` | 0 | entry | `battle` (fixed) | 0 | B0: imp, ember_hound |
| `L0.1 L1.1 L2.1` | 1 | lane slot 1 | per archetype template (`03` §3) | 1 (safe: 0) | B1 / D1 / event |
| `L0.2 L1.2 L2.2` | 2 | lane slot 2 | per template: battle / **treasure** / danger / **miniboss** (elite lane) / battle | 1 | B1 / D1 / M1: fire_eater, ash_phoenix |
| `hub` | 3 | hub | `shop` on a shop-plan floor (floor 2 is eligible), else `rest` or `event` (seeded 50/50) | — | — |
| `L0.4 L1.4 L2.4` | 4 | lane slot 3 | per template: battle-or-rest / battle-or-**forge** / danger (+objective) / battle / event-or-treasure | 1 | B1 / D1 |
| `a1` | 5 | prepare | `rest` if the hub was not rest, else `shop` only if the plan allows, else `rest` (never two rests: see D13) | — | — |
| `a2` | 5 | gamble | `miniboss` (floor ≥ 2) / `event` (floor 1) | 1 | M1 |
| `w` | 6 | warden | `boss` | 1 | X1: inferno_lord |

One worked seed (illustrative, *not* a generated result — the first real one comes from `map_sim` in step 2):
archetypes L0 = peril, L1 = safe, L2 = treasure; `n0` imp; L0: ash_golem (+row_burner), flame_cultist
(+row_burner, big_hands), magma_slug (+row_burner, quick_blocks, thorn_field; objective `vent_dancer`); L1: ember_hound
(tier 0), imp, rest; L2: ember_hound, treasure, forge; hub shop; a1 rest; a2 fire_eater; w inferno_lord. Heat on the
peril lane: 0 → 1 → 2 → hub shop 1 → 2 → a1 rest 0 or a2 miniboss 4 → warden. The same seed on the safe lane peaks
at heat 2 (entry + L1.1, L1.2 before the hub).

Reconciliation of the parts the earlier draft named loosely: **three lanes** are depths 1, 2 and 4 of lanes
L0–L2 (9 nodes); **five archetypes** are the vocabulary a lane's template is drawn from (3 of 5 per map); the
**hub** is depth 3 (1 node); **prepare / gamble** are the two nodes of the **approach** depth 5; the **warden** is
depth 6. `1 + 3 + 3 + 1 + 3 + 2 + 1 = 14`. A player visits `n0`, two lane nodes, the hub, one lane node, one
approach node and the warden = **7 visits**, the same count as today's 7 columns.

## 2. Steps

The steps separate four concerns the earlier draft merged: **(G) graph generation**, **(E) encounter composition**,
**(R) RunSession progression + save**, **(F) GameFlow / views integration**. Each step names its concern.

| # | Concern | Step | Deliverables | Tests (`06` §4 ids) | Exit criterion |
|---|---|---|---|---|---|
| 0 | tooling | **Baseline** (before any v2 code): add `--region-pick=order` to `deck_sim` (tool code, not game code) so the sim follows `world.region_order`; record the v1 7-floor baseline | S0 | `baseline-7floor-v1.md` exists with the command, seed set and raw output |
| 1 | G | **Foundation**: `MapGraph`, `RegionRules` + `route_archetypes.json` / `region_rules.json` loaders, `MapValidator`, the v1-column → MapGraph wrapper | U1–U5 | graph round-trips; the wrapper turns every v1 map of the 7 assigned (region, floor) pairs into a valid graph over 200 seeds |
| 2 | G | **Route generation**: `RegionMapGen` (archetypes, lanes, hub, approach, warden, matches, teach pass, modifiers slots, map effects, edges), `tools/balance/map_sim.gd` | U6–U12, S1 | 10 000 seeds × the 7 assigned pairs valid; Hellfire floor 2 route metrics recorded |
| 3 | E | **Encounter composition**: `EncounterComposer`, modifier catalogue, `RunConfig.from_node(profile)`, `boss_min_runes_add`, objective evaluation from `CombatView.get_match_stats()` | U13–U17, I1a | every existing `*_flow_test` green with an empty profile; a composed Peril profile applied through `from_node` yields the expected `traits` / hazard keys |
| 4 | R | **RunSession v2 progression + minimum save/load**: `node_id` / `cleared_ids` / `rule_state`, `available_nodes` by edges, `complete_node` by graph, **save v8 and `from_dict` for v2 maps, `needs_restart` for v5–v7**, mixed v1/v2 floors in one session | U18–U20, U25–U28 | U25 round-trips at every exit point; U28 mixed generators; U26 old saves restart |
| 5 | F | **GameFlow integration** (hellfire = v2 through `region_rules.hellfire.map_gen`): node-id API, `_node_key` by node id, seeds by node id, forge node flow, objective recording, dev args by node id | I1, I3 | the slice runs headless end to end through GameFlow with saves at each step |
| 6 | E+R | **Heat rule**: gauge steps, `combat_patch` by gauge (vent keys, drop mult, `vent_surge`), warden hook, tier bonus | U21–U23, I2 | at heat 4 a spawned match's `TileHazards` reports `vent_interval_sec` 4.0 and the trait host holds `vent_surge` |
| 7 | R | **Rewards and progression**: `reward_for_node(kind, tier)`, tier gold mult, elite relic offer, objective bonus, 7-entry floor tables, forge ink + free removal | U24, U29–U31, S2 | sim: Peril net value ≥ Safe + 25 % with HP cost in band (`06` §3) |
| 8 | F | **UI**: `ChapterMapView` lanes + preview + gauge; `WorldMapView` briefing; intro-band icons; strings; code-drawn angular icons | E1–E6 | retained screenshots under `production/qa/evidence/world-map-v2/` |
| 9 | all | **Validation and flip decision**: full suite, `map_sim` 10k, `deck_sim` paired v1/v2 matrices, gameplay checks, report; then (user decision) flip the other six regions or stop | S1–S4, full suite | `06` release-blocking metrics met or deviations documented; no claim without output |

Each step ends with the report the user asked for: what changed, files, tests executed, results, remaining issues.

## 3. Dependencies

```
0 baseline ─────────────────────────────────────────────────────────────┐
1 MapGraph + loaders + validator ─► 2 RegionMapGen + map_sim ─► 3 EncounterComposer + from_node(profile)
                                                     │                     │
                                                     ▼                     ▼
                               4 RunSession v2 + save v8 (needs 1, 2) ─► 5 GameFlow integration (needs 3, 4)
                                                                            │
                                            6 Heat (needs 3, 5) ─► 7 rewards (needs 5, 6) ─► 8 UI (needs 5; 6–7 for the gauge/tier previews)
                                                                                                       │
                                                                                      9 validation (needs 0, 2, 7, 8) ◄┘
```

Steps 1–3 touch no running gameplay path (`from_node` with an empty profile is byte-equal to today, U15). Step 4 is
the first change to a run's state model, and it carries its own save/load tests — a v2 run must be savable before
any screen shows it (the user's point: save/load is part of RunSession integration, not a later phase). Step 8 can
start as soon as 5 lands (it needs only the graph API and the preview), in parallel with 6–7.

## 4. What stays untouched until step 9's sign-off

`ChapterMapGen` v1 path, `world.region_columns`, every other region's map, the climb order, all combat code except
the intro-band icon read, all card / relic / event / enemy data.

## 5. Gameplay validation inside the plan (not only technical)

Besides the metrics in `06`, each step from 5 on ends with one **played** check (windowed, muted, memory stores)
and a one-line note in the step report:

| Step | Played check | Question answered |
|---|---|---|
| 5 | walk the three lanes of one seed with `--seed` | does each lane *feel* like its name without reading the preview text? |
| 6 | a Peril lane to heat 4, then the warden | does Heat change where the player stands and when they cast? |
| 7 | the same seed on Safe vs Peril, compare HP/gold/relics at floor 3's entry | did the floor-2 route matter on floor 3? |
| 8 | first-time read of the map by the user (no explanation) | can the lanes be told apart in one glance? |
| 9 | one full run v1 (floors 1, 3–7) with the v2 Hellfire in the middle | does the slice break the run's rhythm? |

A modifier that the played check rates "just a stat" leaves the pool (03 §4 rule) — that is a design exit
criterion, recorded in the report, not a test.

## 6. Risks and mitigations

| Risk | Mitigation |
|---|---|
| The 7-floor baseline does not exist and the sim does not follow the climb order | step 0 adds `--region-pick=order` and records the baseline before any v2 number is judged |
| Two generators in one run confuse GameFlow | the wrapper makes v1 maps real MapGraphs; GameFlow sees only the graph API; U28 + I3 cover v1 → v2 → v1 |
| Forge needs a screen | the reward screen already draws an ink row; a reward with zero card offers and an ink row is **unverified** (`08` §F) — fallback: the PIECE_DECK screen gains an ink row |
| `GameFlow.remove_shape` always spends a token | add a `free: bool` parameter (small, step 5); `RunSession.remove_shape(id, spend_token)` already supports it |
| Heat makes Hellfire the hardest floor 2 by far | heat 0 = today; the Safe lane never passes heat 2; TD-027's ≤ 15-point spread rule applies to S2 |
| Modifier icons need art | code-drawn angular glyphs first (user rule); PixelLab only on request |
| `teach_after` over a graph | `n0` and the lane's slot-1 node are on every path to a slot-2 elite; U10 proves every path teaches |
| Dev args and demo walkers break | they move to node ids in step 5; `--run=map3` family re-pointed at the hellfire slice |

## 7. Effort (rough)

Step 0: ½ session · 1–2: 2 · 3: 1 · 4: 1–2 · 5: 1–2 · 6: 1 · 7: 1 · 8: 2 (+ captures) · 9: 1 + sim time. Order and
gates matter more than the numbers.
