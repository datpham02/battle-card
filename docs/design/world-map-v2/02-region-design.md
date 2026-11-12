# 02 — Region identity: one rule system, seven configurations

Status: Proposed. Only **Hellfire / Heat** (§2) is in the vertical slice; §3–§8 are proposals whose numbers are
placeholders to be measured, not shipped.

Principle (brief §4 "Region identity"): a region must change *decisions on the grid and on the map*, not only art and
roster. Second principle (brief): prefer one reusable system with per-region configuration. Third (audit §1.5): four
regions already own a terrain hazard in combat; the map side is what is missing everywhere.

## 1. The Region Rule system

```
RegionRule (data, assets/data/region_rules.json)
  id            "heat" | "mist" | "sandstorm" | "sink" | "locks" | "cold" | "gale"
  gauge         optional {min, max, start, per_node: {kind: delta}, decay_on: [kinds]}   — run-scoped per region
  map_effect    one of: hide_enemy_beyond(depth) | bury_lane | lane_toll | gate_lane | close_edge_after_node
  combat_effect {trait_id, params_by_gauge} | {hazard_override_by_gauge} — applied in RunConfig.from_node
  reward_effect {tier_bonus_by_gauge}                                      — applied by the reward tier lookup
  warden_hook   {trait param tweak by gauge} — optional
```

Runtime: `RegionRuleState` lives in `RunSession` (saved), reset on `_enter_region`. The map generator reads
`map_effect` (it changes the graph or its visibility), `RunConfig.from_node` reads `combat_effect` (it emits the
existing per-match keys: a trait, or one of the 19 hazard override keys — nothing new in combat for Heat), the reward
tier lookup reads `reward_effect`. The map view reads the gauge for its meter and the preview.

Why this shape: every effect is expressed through a **key combat already understands** (`traits[]`, hazard overrides,
`player_drop_interval_mult`) or a **graph operation** the generator already performs (hide, remove edge, mark node),
so no region needs a bespoke combat subsystem. The audit confirmed `_clean_match` whitelists these keys
(`run_config.gd:215-294`) and `ArenaLibrary.hazards_for_match` merges per-match hazard numbers.

---

## 2. Thành Hỏa Ngục — Hellfire · rule **Heat** (vertical slice)

**Gameplay identity:** the pressure region. Fighting feeds the citadel; the citadel pays you back and burns you for it.

**Core mechanic — the Heat gauge (0–4):**
- Starts at 0 on entry. `battle` / `danger` won: +1. `miniboss` won: +2. `rest`: −2. `shop`: −1. `event`, `treasure`,
  `forge`: 0. Clamped 0–4. Reset on leaving the region.
- The map shows the gauge (angular ember meter, 4 segments) and, on every fight node's preview, the heat the fight
  *will* be fought at (current heat) and the heat after it.

**Combat interaction** (existing hazards and traits only):

| Heat | `vent_interval_sec` (base 7) | burn tick damage (base 2) | extra |
|---|---|---|---|
| 0 | 7.0 | 2 | — |
| 1 | 6.0 | 2 | — |
| 2 | 5.0 | 2 | — |
| 3 | 4.5 | 3 | enemy `boss_drop_interval_mult` ×0.9 (it gets blocks faster) |
| 4 | 4.0 | 3 | **Surge**: trait `vent_surge {interval_sec 12, vents 2}` on every fight (today only the warden has it); eruptions burn `vent_sec` 2.5 s instead of 2.0 (B1, 2026-11-12; the 1.0 s warning is unchanged) |

All five rows map onto keys that exist: hazard override `vent_interval_sec` / `vent_tick_damage` (two of the 19
`RunConfig.HAZARD_OVERRIDE_KEYS`, base values in `combat.json hazards`),
`boss_drop_interval_mult`, `traits[]`. Vents are the region's real decision pressure: at heat 4 the player places a
block every ~4 s under a moving burn line, so **where you stand and when you cast** matter more, not less — which is
the brief's test for a mechanic.

**Map interaction:**
- Reward tier of a fight node = template tier + (1 if heat ≥ 3) — capped at 3. The preview shows the bonus star lit
  in ember colour when it applies. So the *order* of nodes on a lane matters: fight-fight-rest and rest-fight-fight
  give different heat at the depth-4 fight.
- The `peril` lane's archetype weight is raised in Hellfire (it is the region's thesis); `safe` keeps its minimum
  guarantee.

**Warden hook (B1, 2026-11-12):** Inferno Lord's `phase_shift.vent_interval_mult 0.7` stays; at heat ≥ 3 entering the
warden, its `vent_surge` fires every **7 s** instead of 10 s, with the first surge still at 10 s (data `warden_hook`
= `{interval_sec 7, first_delay_sec 10}`). At heat 4 the Heat row above adds the 2.5 s eruptions. The hook never
raises `vents`: the caldera has two vents per half (columns 1 and 4) and the boss's own surge already fires both — the
original "`vents` becomes 3" was clamped silently by `TileHazards.trigger_vents` (see
`production/qa/evidence/world-map-v2/warden-heat-hook-investigation-2026-11-12.md`). Resulting warden progression:
heat 2 = surge 10 s / burn 2.0 s / clock 5.0 s / tick 2; heat 3 = surge 7 s / burn 2.0 s / clock 4.5 s / tick 3;
heat 4 = surge 7 s / burn 2.5 s / clock 4.0 s / tick 3. Warning 1.0 s at every heat. Kept by the user on 2026-11-12 after the
simulator validation (`b1-balance-validation-2026-11-12.md`, PASS) and a 48-fight bot playtest of the live warden
(`human-playtest-b1/bot/bot-playtest-report-2026-11-12.md`: timing confirmed, 0 unescapable warnings, vent damage
≈ 0 for a 0.3 s reaction); human fun / readability ratings are still open. The briefing warns: "Warden: heat matters".

**Risk / reward:** a full-heat lane is ~+2 reward tiers across the region and a relic chance from the objective node;
the cost is burn ticks and lost blocks (vents burn field pieces, `combat_view.gd:688`). Burn-build players (Mage,
`burn_eater` aside) get fewer *clean* casts, not more damage — Heat does not favour the fire deck, which keeps the
region from being a free lunch for one archetype.

**What makes it different:** the only region whose difficulty is a dial *the player turns* on the map.

**Why this is the slice:** it exercises a gauge, a map effect (preview + tier bonus), a combat effect through existing
keys, a warden hook, all five archetypes (Hellfire is floor 2: elite and peril are both legal), and the shop plan
(floor 2 is `guaranteed_min_floor`). It needs **no new combat code** beyond reading two hazard numbers that already
exist as override keys and adding one trait to a fight.

---

## 3. Rừng Sương — Misty Forest (ch1, floor 1) · rule **Mist**

**Identity:** the teaching region; the mist hides what is far and shows what is near.

**Map effect:** `hide_enemy_beyond(1)` — nodes two or more depths ahead show their kind and archetype but not the
enemy; the preview says "hidden in the mist". The lane's archetype (and thus its reward tier) is always visible, so
the first region teaches *route reading* before *enemy reading*.

**Combat effect:** none new. The pattern-brain roster (telegraphed skills) is this region's combat identity; adding
a shroud here would hide the very telegraphs floor 1 is meant to teach. Audit §1.5: ch1 has no terrain, and that is
correct for floor 1.

**Risk / reward:** none beyond the lanes. Different from the others by being the one region whose rule is purely
informational.

## 4. Sa Mạc Cát Vùi — Desert (floor 3) · rule **Sandstorm**

**Identity:** things are buried; digging pays.

**Map effect:** `bury_lane` — one lane (seeded, never `safe`) is drawn buried: its node kinds show as "dune" until the
player stands on a node adjacent to it (the hub reveals the whole second half). A buried fight node cleared pays gold
×1.3 ("dug up"); a buried treasure is a real treasure. The lane's archetype band is visible, the nodes are not.

**Combat effect:** existing — `dunes` / `oasis` sand and wind. Gauge-free.

**Why:** the Desert's existing combat rule is "cells vanish, drops drift" — uncertainty of *position*; the map rule
is uncertainty of *content* for a price. Different from Mist: the mist is distance, the sand is a lane you can choose
to dig.

## 5. Đầm Lầy Độc — Swamp (floor 4) · rule **Sink**

**Identity:** every step costs; choose how far you wade.

**Map effect:** `lane_toll` — lanes have a **toll** shown on the band: `safe` 0, `treasure` 2 % max HP per node,
`peril` / `elite` 4 %, `mystery` 2 %. Paid on entering each node of the lane (never lethal: floor at 1 HP). The hub
(rest) is dry.

**Combat effect:** existing mire + a region trait on `danger` nodes: `bog_spread` (today only the warden has it) —
each enemy cast spreads one mire cell. Mire tolls movement; the map toll tolls HP.

**Why different:** it is the one region where *HP is the route currency* explicitly, which makes the Safe lane
genuinely tempting for once and sets up a heal-heavy build (chi_khau, wards) as a Swamp answer.

## 6. Hầm Ngục — Dungeon (floor 5) · rule **Locks**

**Identity:** the citadel's underside: gates, keys, collapsing floors.

**Map effect:** `gate_lane` — the `elite` or `peril` lane (whichever is drawn; seeded if both) is **locked** at
depth 1; its key sits on another lane's depth-1 node (shown as a key glyph). Clearing that node unlocks the gate and
opens an extra edge from that lane's depth 2 into the locked lane's depth 2 — so the Dungeon is the one region where
switching lanes before the hub is possible, as a reward.

**Combat effect:** existing traits (`seal_caster`, `step_reactor`, `slam`) + a region hazard overlay on `peril`
nodes: `collapse` — a cell the enemy's cast lands on with ≥ 3 cells becomes a hole for the rest of the match (an
arena transformation; reuses `missing_cells` at runtime through the crumble path with `fall_sec = ∞`). The arena
shrinks as the fight goes; big-zone builds change the battlefield they stand on.

**Why different:** the only region with a key/gate graph and permanent arena transformation.

## 7. Tháp Băng — Ice Tower (ch3, floor 6) · rule **Cold**

**Identity:** attrition of tempo, not HP.

**Gauge:** Cold 0–3. Every node +1; `rest` or an event brazier → 0; `shop` −1. Shown as a frost meter.

**Combat effect:** `player_drop_interval_mult` ×(1 + 0.1·cold) — the player's blocks arrive slower (the existing
`frost_aura` trait does ×0.8 *to the enemy's benefit* already; Cold applies the same key to the player by gauge).
The warden (`mist_lord`, `frost_aura` + `phase_shift`) at cold 3 adds `thorn_field`.

**Map effect:** reward tier bonus on the node *after* a rest (warm → +1 tier once), so resting early is paid, not
only safe.

**Why different:** Heat punishes greed with vents and pays in tiers; Cold punishes *not resting* with tempo and pays
for resting — the mirror of Hellfire, deliberately, since both are gauges and the player meets Heat first.

## 8. Không Đảo — Sky Isles (floor 7) · rule **Gale**

**Identity:** the ground leaves; commit.

**Map effect:** `close_edge_after_node` — after each cleared node the gale removes one random *unvisited* edge of the
next depth (never the last edge into a node, never into the warden). The map is drawn with the closed edges
crumbling away. The player sees the *odds* (which edges remain) but cannot know which closes next.

**Combat effect:** existing crumble (`twin_isles`, `three_isles`, `islands_bridge`) + `gust` on `danger` nodes.

**Why different:** the only region where the graph itself changes during the region — the summit's "the ground
falls if you stand still" on the map scale.

---

## 9. Consistency table

| Region | Gauge | Map effect | Combat key reused | New combat code |
|---|---|---|---|---|
| ch1 Mist | — | hide_enemy_beyond | — | none |
| hellfire Heat | 0–4 | tier bonus | vent interval / burn dmg overrides, `vent_surge`, drop mult | **none** |
| desert Sandstorm | — | bury_lane | sand / wind (exist) | none |
| swamp Sink | — | lane_toll | mire, `bog_spread` on danger | none (toll is run logic) |
| ch2 Locks | — | gate_lane | `collapse` overlay | **one hazard overlay** (crumble with no regrow) |
| ch3 Cold | 0–3 | post-rest tier | `player_drop_interval_mult` by gauge, `thorn_field` | none |
| sky_isles Gale | — | close_edge_after_node | crumble, `gust` | none |

Six of seven need no new combat code; the Dungeon's `collapse` is the one new combat piece and is explicitly after
the slice. Every map effect is one of five graph operations, implemented once in the generator / validator.

## 10. Open design decisions (for the user)

- D-R1 Heat numbers above (interval 7→4 s, burn 2→3) — approve as *starting* values for the sim, not final.
- D-R2 Whether Mist (floor 1) should hide anything at all, or whether floor 1 shows everything and Mist starts
  on a later Misty Forest visit (only relevant if the "1 of 2 regions" offer returns).
- D-R3 Swamp toll as HP (proposed) vs gold — HP keeps the brief's "HP cost" question alive; gold would make the
  Swamp an economy region, which the Desert already is.
- D-R4 Dungeon `collapse` permanence (proposed permanent) vs regrow after 10 s (reuses crumble as-is, no new code).
