# 03 — Encounter system: profiles over the existing roster

Status: Proposed. Scope: how a map node becomes a fight (or a non-fight) with route-dependent variety, reusing every
enemy, pool, arena and trait that exists. Audit references: `00` §1.4–1.6.

## 1. Decision: composition, not multi-enemy

> **Decision changed on 2026-11-13 (user approval; see `MULTI-ENEMY-ENCOUNTER-AUDIT.md`).** The decision recorded
> below ("composition, not multi-enemy", 2026-11-11) is **superseded**, not deleted. New decision:
> - An encounter may contain **several simultaneously active enemy units**; multi-enemy is the official direction for
>   **Phase 3** (as `design/quick-specs/phase2-misty-forest-2026-11-01.md` D7 already anticipated: "Một quái mỗi trận
>   trong Phase 2; nhiều quái cùng lúc làm ở Phase 3").
> - Every existing single-enemy encounter (every `matches` block, every pool, every flat test config) keeps its exact
>   behaviour; a node whose `match_id` is a plain match is a 1-unit encounter.
> - Rationale: the audit found the 1v1 assumption is a *keying* assumption (`CombatState.Side` + scalar `enemy_*`
>   fields), not an architectural one; the agent layer is RefCounted and instantiable N times, hit tests are spatial
>   (no target UI needed), and `UnitLayer._draw` already sorts a unit list. Composition (the profile below) stays and
>   now applies to each unit of a formation.
> - Limits approved with the audit: 4 units and 5 occupied cells per half, `square` 2 units, a 2×2 warden with extra
>   units only on `boss_hall` / `oasis`; no new Support trait in Phase 0–2 (existing Tank self-guard / Disruptor
>   behaviour is used); stats, roster, ids, pools, AI, rewards and drops unchanged by the data step.
> - Phase 0 (2026-11-13) adds only the data schema (`chapters.json` `formations`, `pools.formation`, match keys
>   `enemies` / `attack_slots`, `FormationRules`, the `RunConfig` whitelist); the combat does not read `enemies` yet.
>
> **Original decision (2026-11-11), kept for the record:**

The brief asks whether a multi-enemy system is worth it. **No, not now.** `CombatState` holds one enemy
(`combat_state.gd:28-51`), `SwingArbiter`, `BossController`, the HUD and every trait assume one opponent; the
pattern brain and the 2×2 footprint are the only "bigger enemy" paths. Rebuilding that is a combat rewrite with no
map-design reason behind it: Tessera's fights are already 2–4 min and skill-bound; two opponents on one 5×5 half would
mostly make placement unreadable. Encounter depth comes from **composition** of five existing axes instead:

```
EncounterProfile
  match_id        existing roster id, drawn as today (pools[kind][tier], unused first, teach_after, caps)
  arena           the match's shape (+ seeded variant as today) + optional region overlay (02)
  modifiers[]     0..2 modifier ids (BossTraits or hazard overrides), from the region's pool, by archetype slot
  objective       optional {id, params} — a check evaluated from the match's stats on win
  reward_tier     1..3 (01 §E2), after the region rule's bonus
  rule_state      snapshot of the region gauge the fight is played at (Heat level)
```

The profile is **computed at node reveal time** (deterministic from seeds) and saved with the map, so the preview and
the fight always agree and a resumed run fights the same profile.

## 2. Roster use — unchanged draw, named slots

Each archetype template slot names a `kind` and an optional `tier_delta` (−1, 0, +1 relative to the floor's
`floor_tiers` slot). The draw itself is `ChapterMapGen._draw_match` moved into the new generator unchanged: pool of
the kind at the tier, lower tiers as fallback, unused ids first, `teach_after` gate, `onboarding_tier_cap`. So:

- **Every id, pool and tier is preserved**; the only new input is `tier_delta` (safe lane depth-1 battles draw from
  tier−1 when the pool has it; elite's miniboss draws at the floor tier as today).
- Restrictions preserved verbatim: `danger` from floor 2 (`archetype_min_floor.peril = 2` restates the column rule
  at the lane level), `miniboss` from floor 2, floor-1 event in the gamble slot, `teach_after` for ch1 elites — the
  teach pass runs over the whole graph, with the entry node and the chosen lane's depth-1 node as candidate teachers
  (both are on every path to a depth-2 elite).
- Orphan ch1 block matches stay orphans (data untouched).

## 3. Archetype templates (data)

`assets/data/route_archetypes.json` (new; numbers = 01 §B3 / §E2):

```json
{
  "safe":     {"slots": [{"kind":"battle","tier_delta":-1,"reward_tier":1},
                         {"kind":"battle","tier_delta":0,"reward_tier":1},
                         {"kind":["rest","battle"],"tier_delta":0,"reward_tier":1}],
               "modifier_slots": [0,0,0], "min_floor": 1, "weight": 1.0},
  "treasure": {"slots": [{"kind":"battle","reward_tier":1},
                         {"kind":"treasure","reward_tier":1},
                         {"kind":["battle","forge"],"reward_tier":1,"gold_mult":1.5}],
               "modifier_slots": [0,0,0], "min_floor": 1, "weight": 1.0},
  "peril":    {"slots": [{"kind":"danger","reward_tier":2},
                         {"kind":"danger","reward_tier":2},
                         {"kind":"danger","reward_tier":3,"objective":true}],
               "modifier_slots": [0,1,1], "min_floor": 2, "weight": 1.0},   // [0,1,2] until the 2026-11-12 tuning pass
  "elite":    {"slots": [{"kind":"battle","reward_tier":2},
                         {"kind":"miniboss","reward_tier":3,"relic_offer":1},
                         {"kind":"battle","reward_tier":2}],
               "modifier_slots": [0,0,1], "min_floor": 2, "weight": 0.8},
  "mystery":  {"slots": [{"kind":"event","reward_tier":1},
                         {"kind":"battle","reward_tier":1},
                         {"kind":["event","treasure"],"reward_tier":1}],
               "modifier_slots": [0,0,0], "min_floor": 1, "weight": 0.8}
}
```

Per region, `region_rules.json` can override `weight` and `min_floor` (Hellfire raises `peril`). A region draws 3
distinct archetypes by weight with the "≥ 1 of safe/treasure" guarantee (01 §B3). The `danger` kind keeps adding
`defaults.danger_traits` (`row_burner`) as today — the first modifier of every Peril fight is therefore the existing
one, and `modifier_slots` count the *additional* ones.

## 4. Modifier pool

A modifier is a data record that resolves to **one of two existing mechanisms** — nothing else is allowed, so every
modifier is implemented by a BossTrait or by arena/hazard numbers the combat already reads:

```json
"modifiers": {
  "row_burner":    {"trait": {"id":"row_burner","params":{}}, "icon":"mod_row", "text_key":"mod.row_burner"},
  "seal_caster":   {"trait": {"id":"seal_caster","params":{}}},
  "thorn_field":   {"trait": {"id":"thorn_field","params":{"min_swing_cells":4,"max_cells":3,"cooldown_sec":6}}},
  "frost_aura":    {"trait": {"id":"frost_aura","params":{}}},
  "shroud":        {"trait": {"id":"shroud","params":{}}},
  "step_reactor":  {"trait": {"id":"step_reactor","params":{}}},
  "big_hands":     {"match": {"boss_min_runes_add": 1}},
  "quick_blocks":  {"match": {"boss_drop_interval_mult": 0.85}},
  "narrow_arena":  {"arena": {"variant": true}},
  "vent_surge":    {"trait": {"id":"vent_surge","params":{"interval_sec":12,"vents":2}}}
}
```

Region pools (data): hellfire `[row_burner, big_hands, quick_blocks, vent_surge, thorn_field]`; others listed in the
schema when their regions are built. Rules: a modifier never duplicates a trait the match already has (dedupe by id);
`modifier_slots[i]` modifiers are drawn on the stream `hash([run_seed, region, floor, "mods", node_id])`;
`big_hands` is never drawn on a match with `boss_min_runes ≥ 3`.

**Warden hook (region rule `warden_hook`, B1 2026-11-12):** at or above `min_gauge` the hook overrides params of a
trait the warden *already carries* (a trait it lacks is not added). Hellfire: `vent_surge {interval_sec 7,
first_delay_sec 10}` — the surge comes every 7 s at heat ≥ 3, the first one still at 10 s; the heat-4 row adds 2.5 s
eruptions; the warning stays 1.0 s. A hook must never ask for more `vents` than the warden's arena has per half
(the caldera has 2; a higher count is clamped silently by `TileHazards.trigger_vents`) —
`tests/unit/run/map_v2/vent_surge_arena_invariant_test.gd` checks every `vent_surge` entry against the arenas it can
play in. Kept by the user on 2026-11-12 (simulator PASS + bot playtest; human feel ratings still open).

**Why these are not cosmetic:** every entry changes a grid decision — rows to avoid (`row_burner`), cells sealed
(`seal_caster`), entering thorns (`thorn_field`), drop tempo (`frost_aura`, `quick_blocks`), information (`shroud`),
movement discipline (`step_reactor`), minimum enemy cast size (`big_hands` → bigger zones to dodge).

## 5. Objectives (Peril depth-4 only at first)

Evaluated on win from `CombatView.get_match_stats()` (verified keys: `hits_taken`, `casts`, `joins`,
`featured_casts`, `signatures_used`, `frost_bursts`, `boss_thorn_steps`, `damage_dealt`, `damage_taken`). The first two
objectives use existing counters only; the other two need **two new counters in CombatView** (`max_cast_cells`,
`vent_cells_stood`) — small, but combat code, scheduled with step 3 and listed as unverified work in `08` §F:

| id | condition | reads | counter status |
|---|---|---|---|
| `no_hit_3` | ≤ 3 hits taken | `hits_taken` | exists |
| `joiner` | ≥ 2 joined casts | `joins` | exists |
| `big_cast` | one cast of ≥ 4 cells | `max_cast_cells` | **new** |
| `vent_dancer` (hellfire) | survive ≥ 2 vent eruptions on the enemy half with a block placed on a vented cell | `vent_cells_stood` | **new** |

Shown on the preview; a met objective lifts that node's reward by one tier's gold and adds the relic row (01 §E2).
Objectives are optional — missing one never reduces the base reward.

## 6. Non-fight nodes

Unchanged logic classes with the node id as their seed key instead of `(column, node_index)`:
`ShopLogic.build(run_seed, floor, node_id…)`, `EventLogic.pick_event(seed, floor, node_id…)`, rest as today. The
`treasure` node keeps its three rows. Event fights (`tran_thach` → `fight`) draw at `floor tier + tier_add` from the
`danger` pool as today, with the node's modifiers applied.

**`forge`** (new kind, 01 §B8): `set_pending_ink_offer` (2 shapes, seed `hash([run_seed, floor, node_id, "ink"])`)
shown on the reward screen's existing ink row with **no card row**, plus one free `RunSession.remove_shape(id,
spend_token = false)` through a new `free` flag on `GameFlow.remove_shape`; leaving completes the node. No combat, no
gold, no card. `ChapterMapGen.KINDS` gains `"forge"`; `RewardRoller node_rewards.forge` = `{offers 0}`;
`EconomyConfig` gold 0. Unverified: `RewardView` with zero card offers (`08` §F); fallback = ink row on the piece-deck
screen.

## 7. Preview contract (what the map shows, from the profile)

`EncounterProfile.preview()` → `{enemy_name_key, enemy_role, footprint, arena_shape_id, modifiers:[{icon, text_key}],
reward_tier, reward_summary, objective_text_key?, hidden: bool}`. `hidden` is set by the region rule (Mist /
Sandstorm) and blanks the enemy and modifiers but never the kind, archetype or reward tier.

## 8. Compatibility and tests

- `RunConfig.from_node(config, region, match_id, kind, floor_seed, floor, kiep)` gains one argument
  `profile: Dictionary` (modifiers, rule_state, objective); without it (tests, dev args) it behaves as today.
- `_clean_match` whitelist: add `boss_min_runes_add` (resolved into `boss_min_runes` in `_apply_scaling`) — the only
  new match key; everything else maps onto existing keys.
- Regression: every existing `*_flow_test` that spawns a match through `from_node` must pass with an empty profile.
- New unit tests: profile determinism, modifier dedupe, `big_hands` guard, objective evaluation from a stats dict,
  preview `hidden` masking, tier_delta pool fallback, teach_after over the graph (every path to an elite teaches).
