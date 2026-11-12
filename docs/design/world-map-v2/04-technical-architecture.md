# 04 — Technical architecture (Godot 4.6, GDScript)

Status: **Implemented for the Hellfire slice (2026-11-12)** — see "As implemented" below for the places where the
code differs from this proposal; everything else was built as written. File paths marked **(new)** now exist.

## As implemented (deviations from the proposal, with the reason)

| Proposal | Implemented | Why |
|---|---|---|
| RunSession position = `node_id` + `cleared_ids`; column fields removed for v2 | The MapGraph is the saved truth of a v2 region and RunSession **mirrors** it into the existing column model (`RunSession.columns_from_graph`: depth = column, screen order = index, edges = `next`); `column` / `node_index` / `cleared_nodes` stay the storage, with id accessors (`node_id_at`, `current_node_id`, `choose_node_id`, `available_node_ids`, `cleared_ids`) on top | every column-addressed rule, seed, save point, dev walker and screen kept working unchanged; the v1 path is byte-identical; the graph API is still first-class (`get_map_graph`, previews by id) |
| `floor_seed()` by `hash([floor, node_id])` for v2 nodes | unchanged (`floor * 100 + column`) | the mirror has columns, so the existing formula stays deterministic and v1 arenas are untouched |
| `world.map_gen` / `world.depth_layout` keys in `chapters.json` | `region_rules.json` carries `depth_layout` and per-region `map_gen`; `chapters.json` untouched | one new file instead of touching the 2 000-line roster file (D10) |
| `KiepRules.apply_map_spec` v2 branch | `KiepRules.node_weight_mult(kind, level)` (read-only getter) feeds the `peril` archetype weight in `RegionMapGen.draw_archetypes`; the v1 column pass is untouched | smaller surface; U8 proves Kiep 3 raises the peril share |
| Forge screen = reward screen without cards | Forge screen = the **piece-deck screen** in phase `FORGE` with the ink row drawn as two buttons in the title band and a free `remove_shape` | `RewardView` draws the ink row only beside a card row; the piece-deck screen already lists every shape and its removal |
| Objective counter `vent_cells_stood` | `vents_dodged` (vent eruptions on the player's half the player was not standing in) | measurable from the existing `vent_erupted` signal without touching the hazard model |
| `--route-policy` with an O-preview "value" oracle | `--route-policy=safe|treasure|peril|elite|mystery|random|value` where `value` = risky lanes above 60 % HP, safe lanes below | the full oracle needs per-enemy loss tables the sim does not export; recorded as a limitation in the final report |
| Save `MIN_LOADABLE_VERSION` 8 | as proposed; three existing tests that asserted "a v5/v6 save loads live" were updated to the approved policy (`boss_fate_test`, `kiep_wiring_test`, `economy_test`) | D5 |

## 1. Architecture in one picture

```
assets/data/
  chapters.json            (unchanged: roster, pools, world.*)      ─┐
  route_archetypes.json    (new)  lane templates, weights            ├─► RegionMapGen (new, pure) ──► MapGraph (new, pure data)
  region_rules.json        (new)  rule per region, modifier pools   ─┘        │                          │
                                                                              ▼                          ▼
                                                                     MapValidator (new, pure)     RunSession (position by node_id, rule state)
                                                                                                         │
            EncounterComposer (new, pure) ◄── profile per fight node ◄────────────────────────────────────┤
                    │                                                                                    │
                    ▼                                                                                    ▼
            RunConfig.from_node(+profile)  ──►  RunController  ──►  CombatView (unchanged except 1 whitelist key)   GameFlow (node-id API)
                                                                                                         │
                                                                                 ChapterMapView v2 (lanes, preview) · WorldMapView (briefing)
```

Principles: generation and validation are **pure static functions over Dictionaries** (like `ChapterMapGen` today) so
they run headless in tests and in `deck_sim`; the map is **data with ids**; the legacy generator stays behind a flag
until the new one is verified (brief: do not delete old systems first).

## 2. Data model

### 2.1 MapGraph (saved verbatim inside the run save)

```gdscript
# One region map. All ids are Strings, stable for the life of the run.
{
  "schema": 2,
  "region_id": "hellfire", "floor": 1, "seed": 123456,
  "depths": 7,
  "lanes": [ {"id": "L0", "archetype": "peril", "order": 0},
             {"id": "L1", "archetype": "safe",  "order": 1},
             {"id": "L2", "archetype": "treasure", "order": 2} ],
  "nodes": {
    "n0":  {"id":"n0", "depth":0, "lane":"", "slot":"entry",   "kind":"battle", "match_id":"imp",
            "reward_tier":1, "modifiers":[], "objective":"", "tags":[]},
    "n1a": {"id":"n1a","depth":1, "lane":"L0","slot":"lane",    "kind":"danger", "match_id":"ash_golem",
            "reward_tier":2, "modifiers":["big_hands"], "objective":"", "tags":[]},
    ...
    "hub": {"id":"hub","depth":3, "lane":"", "slot":"hub",     "kind":"shop", "match_id":"", ...},
    "a1":  {"id":"a1", "depth":5, "lane":"", "slot":"prepare", "kind":"rest", ...},
    "a2":  {"id":"a2", "depth":5, "lane":"", "slot":"gamble",  "kind":"miniboss", "match_id":"fire_eater", ...},
    "w":   {"id":"w",  "depth":6, "lane":"", "slot":"warden",  "kind":"boss", "match_id":"inferno_lord", ...}
  },
  "edges": [["n0","n1a"],["n0","n1b"],["n0","n1c"],["n1a","n2a"], ... ,["a1","w"],["a2","w"]],
  "rule":  {"id":"heat", "gauge": 0}          # live region-rule state (RunSession owns it; copied here on save)
}
```

- `nodes` is a Dictionary keyed by id (O(1) lookup, stable save order via sorted keys in `to_dict`).
- `edges` is an array of `[from, to]`; `MapGraph.out_edges(id)` / `in_edges(id)` are computed once and cached in the
  RefCounted wrapper, never saved.
- `tags` carries region map effects (`hidden`, `buried`, `locked`, `key`) — strings, so the view and the validator need
  no per-region code.
- Kind strings are the existing `ChapterMapGen.KIND_*` constants (preserved ids, preserved icons) plus the new
  `forge` (01 §B8; resolved by GameFlow as a reward screen with the ink row only + a free `remove_shape`; one map icon,
  strings `node.forge.*`; see `07` C13 for the verified flow and the fallback).
- Responsibility split (07 C6): **RegionMapGen** writes `match_id`, `modifiers[]`, `objective`, `reward_tier` on
  the node at generation time (seeded, saved); **EncounterComposer** reads them at spawn/preview time and never
  draws anything. Region end is detected by `slot == "warden"` (the v1 wrapper sets `slot` from the kind).
- `floor_seed()`: v1 maps keep `arena_seed_for(run_seed, floor*100 + column)` (today's arenas unchanged); v2 nodes
  use `arena_seed_for(run_seed, hash([floor, node_id]))`.

### 2.2 Encounter profile (stored on the node, 03 §1)

Fields on the node record: `match_id`, `modifiers` (ids), `objective`, `reward_tier`, plus `rule_state` captured at
reveal time. The *resolved* match dictionary is never saved (it is a pure function of the above + data + floor).

### 2.3 New JSON files

- `assets/data/route_archetypes.json` — 03 §3 (templates, weights, min_floor, modifier_slots).
- `assets/data/region_rules.json` — 02 §1 (per region: rule id, gauge, map_effect, combat_effect by gauge,
  reward_effect, warden_hook, archetype weight overrides, modifier pool) + top-level `modifiers` catalogue (03 §4).
- `chapters.json world` gains **one** key: `"map_gen": "v2"` (default `"v1"` keeps today's generator) and
  `"depth_layout"` (`[1,3,3,1,3,2,1]` node counts per depth, documented default). `region_columns` stays for v1.
- `rewards.json node_rewards` gains an optional `tiers` block (01 §E2); absent = tier 1 = today.

Validation of all three follows the house pattern (`clean_*` with warnings and built-in defaults; never null).

## 3. Responsibilities

| Unit | File | Kind | Responsibility |
|---|---|---|---|
| `MapGraph` | `src/run/map/map_graph.gd` **(new)** | RefCounted, pure | wrap the dictionary: `node(id)`, `out_edges`, `in_edges`, `nodes_at_depth`, `lane_of`, `to_dict` / `from_dict` (+ `clean`) |
| `RegionMapGen` | `src/run/map/region_map_gen.gd` **(new)** | static, pure | `generate(spec, seed) -> MapGraph`: draw archetypes → build lanes/hub/approach/warden → draw matches (moved `_draw_match`, `_teach_lists`, teach pass over the graph) → modifiers → objectives → region map effect → edges |
| `MapValidator` | `src/run/map/map_validator.gd` **(new)** | static, pure | `validate(graph) -> {ok, errors[]}`: reachability from entry, warden reachable from every node, no dead ends, slot guarantees, archetype distinctness, kind restrictions by floor, pool membership of every match id, edge sanity; `metrics(graph)` for 06 |
| `EncounterComposer` | `src/run/map/encounter_composer.gd` **(new)** | static, pure | `profile(node, region_rules, rule_state) -> Dictionary` (modifiers → trait/match/arena patches, objective), `preview(profile, hidden)` |
| `RegionRules` | `src/run/map/region_rules.gd` **(new)** | RefCounted config | load/clean `region_rules.json`; `rule_for(region)`, `gauge_step(rule, kind)`, `combat_patch(rule, gauge)`, `tier_bonus(rule, gauge)` |
| `RunSession` | `src/run/run_session.gd` | existing | position = `node_id` (+ `cleared_ids: Array[String]`), `available_nodes()` = out-edges of the last cleared node not cleared, `choose_node(id)`, `complete_node` (advance by graph, warden by `slot == "warden"`), `rule_state`, save v8 |
| `ChaptersConfig` | existing | existing | `generate_region_map` dispatches on `world.map_gen`; v1 path untouched |
| `RunConfig` | existing | existing | `from_node(..., profile := {})` applies `profile.match_patch` beside the danger step; `_clean_match` + `boss_min_runes_add` |
| `GameFlow` | existing | existing | node-id API (`choose_node(id)`), `_node_key = "floor/<node_id>"`, seeds by node id, `_record_objective`, rule-state updates on `complete_node`, dev args by node id |
| `ChapterMapView` v2 | `src/run/chapter_map_view.gd` (rewrite of the route area; HUD bar kept) | existing file | lanes, edges, preview panel, gauge meter |
| `WorldMapView` | existing | existing | briefing panel from `RegionRules` + warden data |
| `ChapterMapGen` | existing | **kept (deprecated)** | v1 generator; removed only after 06 sign-off |

## 4. Interfaces (GDScript sketches)

```gdscript
class_name RegionMapGen
extends RefCounted
## Pure, seeded. Same (spec, seed) -> same graph. spec = ChaptersConfig.region_spec(...) + archetypes + rules.
static func generate(spec: Dictionary, seed: int) -> MapGraph
static func draw_archetypes(spec: Dictionary, rng: RandomNumberGenerator) -> Array[String]   # 3 distinct, guarantee
static func draw_match(spec: Dictionary, kind: String, tier: int, used: Array[String], rng, gate := Callable()) -> String  # moved verbatim

class_name MapValidator
static func validate(graph: MapGraph, spec: Dictionary) -> Dictionary   # {"ok": bool, "errors": Array[String]}
static func metrics(graph: MapGraph) -> Dictionary   # nodes, edges, paths_to_warden, distinct_lane_profiles, max_in/out degree

class_name EncounterComposer
static func profile(node: Dictionary, rules: RegionRules, gauge: int, floor: int) -> Dictionary
#   -> {"match_patch": {traits:[], boss_min_runes_add:int, boss_drop_interval_mult:float, hazard overrides…},
#       "arena_patch": {variant:bool}, "objective": {id, params}, "reward_tier": int}
static func preview(node: Dictionary, prof: Dictionary, hidden: bool) -> Dictionary   # 03 §7
static func objective_met(objective: Dictionary, match_stats: Dictionary) -> bool

# RunSession additions
var node_id: String = ""            # "" = none chosen
var cleared_ids: Array[String] = []
var rule_state: Dictionary = {}     # {"id": "heat", "gauge": 2}
func available_nodes() -> Array[Dictionary]   # out-edges of last cleared (entry when none), minus cleared
func choose_node(id: String) -> bool
func complete_node(hp_end, max_hp, kind, config, passive_heal := 0.0) -> Dictionary   # same return keys + "objective_met"
```

Seeds (every one a separate stream, hashed as today):
`map = hash([run_seed, region, floor])`; `archetypes = hash([map, "arch"])`; `matches = hash([map, "matches"])`;
`teach = hash([map, "teach"])`; `mods = hash([map, "mods", node_id])`; `rule = hash([map, "rule"])`;
shop / event / gold / reward / ink: existing formulas with `node_id` replacing `(column, node_index)` for v2 nodes
and `nodes_cleared` kept where it is today; v1 nodes keep every existing formula (§2.1 note on `floor_seed`).

## 5. Deterministic generation

- Inputs: `(run_seed, region_id, floor, kiep_level, cleared_bosses, data files)`. Nothing reads time, locale or
  progress beyond `cleared_bosses` (as today).
- Construction order is fixed (archetypes → nodes by depth and lane order → matches → teach → modifiers → objectives →
  map effect → edges); each step consumes its own stream so adding a later step never shifts an earlier one (the house
  rule from `ChapterMapGen`).
- Region rule gauge changes are deterministic functions of the cleared kinds; the profile captured at reveal is saved.
- Test: `map_sim` 10 000 seeds × the 7 assigned (region, floor) pairs generated twice → byte-equal `to_dict`; the
  unit test U6 covers 1 000 seeds per pair plus the edge seeds (06 §2).

## 6. Error handling and fallbacks

| Failure | Behaviour |
|---|---|
| `route_archetypes.json` / `region_rules.json` missing or invalid | built-in defaults (templates = 03 §3, rule = none); warning; generation proceeds |
| fewer than 3 legal archetypes for a floor | repeat `safe` (the only archetype allowed twice); warning |
| pool empty for a slot | existing `_draw_match` fallbacks (lower tier → any tier → chapter matches → `""` with warning); a `""` match id turns the node into `battle` from `match_ids` as today |
| validator fails after generation | **never silently**: in debug, `push_error` + the map is still returned; in tests the failure is asserted; the run never gets an unreachable warden because construction is deterministic by layout, so this is a regression guard |
| save holds a node id not in the map, or an edge to an unknown id | `from_dict` returns null → existing "run dropped" path |
| save `version < 8` | `needs_restart` with the existing notice (`run.restart.old_save`); v7 saves are column maps and cannot resume into lanes — a converter is not worth building for an in-development game (decision D5) |
| `world.map_gen` unknown | `"v1"` |

## 7. Save / load

- `RunSession.SAVE_VERSION` 7 → **8**; `MIN_LOADABLE_VERSION` 5 → **8** for *resume*; versions 5–7 take the
  `needs_restart` path (already implemented for < 5). `ProgressState.VERSION` 8 → 9 only if a progress field changes
  (none planned; the run dict is nested, so the progress version may stay 8).
- New keys: `node_id`, `cleared_ids`, `rule_state`, `objectives_met: [node_id]`; `map` is the MapGraph dict. Removed
  keys: `column`, `node_index`, `cleared_nodes` (kept readable for the needs_restart branch only).
- Save points: unchanged list (audit §1.3); two additions: after a gauge change (it happens inside `complete_node`,
  already saved) and after an objective is recorded (same call).
- `SaveSlots.summarize` keeps `floor` / `region` (unchanged keys).
- Resume: `_resume_position` unchanged in spirit; "a match node" = `node_id` set and `slot ∈ fight kinds`.

## 8. UI responsibilities

- `ChapterMapView`: reads `GameFlow.get_run_map()` (now a MapGraph dict), `get_available_nodes()` (ids),
  `get_node_preview(id)` (new, from `EncounterComposer.preview`), `get_rule_state()`. Layout: depth → x
  (7 columns of `ScreenLayout.map_route_rect`), lane order → y band; hub / approach / warden centred. Edges drawn
  straight. Everything else (plates, icons, check, selection, Enter, pause panel) reused.
- `WorldMapView`: `GameFlow.region_preview(region)` gains `rule` (name key, icon, gauge line), `warden_traits`
  (name keys), `has_shop` (from the shop plan). The Kiep-shifted scaling row replaces the raw row (fixes G8).
- `CombatView` intro band: reads `match_params["modifier_icons"]` (set by `RunController` from the profile) — display
  only.
- Strings: new keys under `route.<archetype>.*`, `mod.<id>`, `rule.<id>.*`, `objective.<id>` in
  `assets/i18n/strings.csv` (English first, Vietnamese column, as Story 042).

## 9. Migration strategy

1. Add data files + loaders with tests (no behaviour change; `map_gen` defaults to v1).
2. Add `MapGraph`, `RegionMapGen`, `MapValidator`, `EncounterComposer` with unit tests, driven only by tests and
   `tools/balance/map_sim.gd` (new) — still no game behaviour change.
3. Teach `RunSession` both position models behind `map_gen` (v1 column path kept verbatim; v2 node-id path new),
   save v8 for v2 runs only. Flip `map_gen` to v2 **for hellfire only** through a per-region override
   (`region_rules.hellfire.map_gen: "v2"`) — the vertical slice. Other regions keep v1 maps in the same run; the
   graph API wraps a v1 column map as a trivial MapGraph (columns → depths, `next` → edges) so GameFlow and the view
   speak one API. This is the key migration trick: **one API, two generators, per-region switch.**
4. Views: v2 route area renders any MapGraph (v1 wrapped maps look like today's columns).
5. After 06 sign-off: flip every region to v2, delete the v1 column path from RunSession, keep `ChapterMapGen` only
   for its moved helpers, update docs (schema.md, game_flow.gd header).

## 10. Files

**Modify:** `src/run/run_session.gd`, `src/run/game_flow.gd`, `src/run/run_config.gd` (profile arg, 1 whitelist key),
`src/run/run_controller.gd` (modifier icons param), `src/run/chapters_config.gd` (dispatch, new world keys),
`src/run/chapter_map_view.gd` (route area), `src/run/world_map_view.gd` (briefing), `src/run/reward_roller.gd`
(`reward_for_node(kind, tier)`), `src/run/economy_config.gd` (tier gold mult, 7-entry floor tables),
`src/combat/combat_view.gd` (intro icons only), `assets/data/chapters.json` (2 world keys), `assets/data/rewards.json`
(`tiers`), `assets/data/economy.json` (7 entries), `assets/i18n/strings.csv`, `assets/data/schema.md`,
`tools/balance/deck_sim.gd` (route policies), tests listed in 06.

**Add:** `src/run/map/{map_graph, region_map_gen, map_validator, encounter_composer, region_rules}.gd`,
`assets/data/route_archetypes.json`, `assets/data/region_rules.json`, `tools/balance/map_sim.gd`,
`tests/unit/run/map_v2/*_test.gd`, `tests/integration/run/world_map_v2_flow_test.gd`, map icons for archetypes and
modifiers (`assets/art/ui/map/`, code-drawn placeholders first; PixelLab only with the user's yes).

**Unchanged:** all combat under `src/combat/`, `src/traits/`, `src/arena/` (except the one intro-band read),
`src/pieces/`, `ShopLogic`, `EventLogic`, `FateLogic`, `RelicRoller`, `KiepRules` (map rule reads "branch slots =
lane slots" through the graph API), `ProgressState`, `SaveSlots`, roster data.

**Deprecate after verification:** `ChapterMapGen.generate` / `link_columns` / `_apply_special_nodes` /
`_column_kinds`; `world.region_columns`; `special_nodes.column`; RunSession `column` / `node_index` / `cleared_nodes`;
GameFlow `DEV_MAP3_COLUMNS` and the `fF/cC/nN` dev addressing (replaced by `--node=fF/<region>/<node_id>`).

## 11. Dependencies and order

Data loaders → MapGraph → RegionMapGen (+ validator, + sim) → EncounterComposer → RunSession v2 path + save v8 →
RunConfig profile → GameFlow node-id API → views → region rule (Heat) → rewards tiers → validation. Matches the
user's 8-step implementation order (05).

## 12. Engine notes (Godot 4.6)

Pure RefCounted + static funcs, `Dictionary` / typed `Array[String]`, `RandomNumberGenerator` seeded by `hash()` —
all unchanged idioms from the current generators; nothing here needs an API newer than what the repo already uses.
Headless tests remain SceneTree scripts. No new nodes, scenes, autoloads or GDExtension.
