# World Map v2 — balance and playtest validation (Hellfire floor 2), 2026-11-12

Brief: "World Map v2 — Balance & Playtest Validation" (Priorities 1–5). Scope: Hellfire only; data, simulator, tests,
evidence and the intro-band presentation fix. Core combat, map structure, rosters, other regions, economy, save format:
untouched. Nothing committed. Every number below is a **bot** number (deck_sim, dodge 0.85, static policies): a relative
yardstick between configurations on the same seeds, never an absolute difficulty claim.

Raw output of every experiment: `balance/` (90 + 15 files, `run-experiments.sh` / `run-replicate.sh` are the exact
commands, `run-experiments.log` the timings, `aggregate.py` the tables). Variant data files: `variants/`. Earlier
evidence (`route-sim-2026-11-12.md`, `fullrun-*.txt`, `route-sim-hellfire-*.txt`, `ui/`) is kept as it was.

## 0. Summary

- **Recommended configuration: variant C** — Peril's third slot draws **one** extra modifier instead of two
  (`route_archetypes.json` `peril.modifier_slots` `[0,1,2]` → `[0,1,1]`). Heat numbers unchanged. Decision detail §9.
- Priority 1: C brings Peril's region clear from 73.6 % to 81.3 % (Safe 90.5 %): the death gap falls from +16.9 to
  **+9.2 points, inside the ≤ +10 band**; Peril still pays +31 % gold, +0.83 relics and +51 % net value over Safe
  (target +25 %) and still costs +17 HP points in fights — risk/reward kept. A (heat 3 vent damage 3 → 2) changes
  **nothing** in the simulation because the bot never stands in a vent (§6); B (heat 4 vent interval 4.0 → 4.5 s)
  moves Peril by +0.4 points — noise. Neither is adopted on bot evidence.
- Priority 2: Mystery is **not rare** — 48.6 % of 10 000 hellfire maps hold it. It was missing from the first report
  because the simulator only began its route bookkeeping at a *fight* node and Mystery opens with an event (§5). Fixed in
  the tool; no data change needed.
- Priority 3: three simulator defects fixed (forge nodes played a default fight; event-led lanes dropped from the ROUTE
  table; a death in an event fight did not end the route) and a second ROUTE2 row added per lane (heat at the warden,
  objective fights, relic rows offered vs taken, inks, forge, HP lost in fights vs healed outside). What still cannot be
  measured is listed in §6, not guessed.
- Priority 4: the battle intro band now shows the encounter's **active** modifiers (left block, mirror of the arena
  block); verified at 1280 × 720 (`ui-balance-2026-11-12/E8`), covered by the flow test.
- Priority 5: regression — §8.

## 1. Commands and seeds

Probe (one lane per process; `--floors=2..2` = Hellfire alone, started with the starter deck at full HP; seeds
2002..2071; a seed counts for a lane only when its map offered that lane):

```
GODOT=C:/Users/ADMIN/AppData/Local/Microsoft/WinGet/Links/godot.exe
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --run=v6 --region-pick=order --seeds=70 --seed-offset=2001 \
  --characters=<char> --policies=build --shop-policy=greedy --event-policy=risky --relic-policy=pick --tables=v6 \
  --floors=2..2 --final=off --route-policy=<safe|treasure|peril|elite|mystery|value> \
  [--region-rules=res://production/qa/evidence/world-map-v2/variants/region_rules_<A|B>.json] \
  [--route-archetypes=res://production/qa/evidence/world-map-v2/variants/route_archetypes_C.json] [--pieces=on]
```

Paired full run (same seeds and flags as the Phase 0 baseline, hellfire on the greedy `value` lane policy):

```
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --run=v6 --region-pick=order --seeds=70 --seed-offset=2001 \
  --characters=<char> --policies=build --shop-policy=greedy --event-policy=risky --relic-policy=pick --tables=v6 --final=on --route-policy=value [variant flag]
```

Replicate seed set 3002..3071 (`--seed-offset=3001`) for v1 (hellfire on the v1 column map through
`variants/region_rules_v1.json`), current and C: `balance/run-replicate.sh`.

`--region-rules=` / `--route-archetypes=` are new tool flags (deck_sim only) that load an alternative data file into the
shared loaders; the game always reads `assets/data/`. Each raw file's header line `world-map-v2: region_rules=…
route_archetypes=… route-policy=… pieces=…` states what it ran.

## 2. Original configuration (as approved, D1–D15)

| Item | Value |
|---|---|
| Heat per kind | battle +1, danger +1, miniboss +2, rest −2, shop −1, event / treasure / forge / boss 0; clamp 0–4 |
| Heat combat patch | 1: vent 6 s · 2: vent 5 s · 3: vent 4.5 s, tick 3, enemy drops ×0.9 · 4: vent 4 s, tick 3, drops ×0.9, `vent_surge` (12 s, 2 vents) |
| Heat reward / warden | tier +1 from heat 3; warden hook at heat ≥ 3: `vent_surge` vents 3 |
| Peril template | danger (tier 2) · danger (tier 2, +1 modifier) · danger (tier 3, **+2 modifiers**, objective); weight 1.0 × hellfire 1.5; min floor 2 |
| Hellfire modifier pool | big_hands, quick_blocks, thorn_field, seal_caster, vent_surge |
| Archetype weights | safe 1.0, treasure 1.0, peril 1.0 (×1.5 hellfire), elite 0.8, mystery 0.8; 3 of 5 per map; guarantee safe or treasure |
| Reward tiers | gold ×1.0 / 1.3 / 1.6; tier 3 rare floor + 1 relic row; luck +0 / +1 / +2; objective ×1.3 gold + 1 relic row |

Variants (one variable each, `variants/`):

| Variant | File | Change |
|---|---|---|
| A | `region_rules_A.json` | heat 3 `vent_tick_damage` 3.0 → 2.0 (the heat 4 row keeps 3.0) |
| B | `region_rules_B.json` | heat 4 `vent_interval_sec` 4.0 → 4.5 |
| C | `route_archetypes_C.json` | peril `modifier_slots` [0,1,2] → [0,1,1] |

## 3. Simulator fixes made before measuring (tool code only, `tools/balance/deck_sim.gd`)

Found while reading the first pass's raw output (`route-sim-hellfire-f2-treasure-*.txt` carried 50 `RunConfig: unknown
match ''` backtraces each, `random` 14, `value` / `fullrun-*` 4–6):

1. **Forge nodes were played as a default fight.** The world loop had no `forge` branch, so a treasure lane whose third
   slot rolled the forge fell through to `_world_match` with an empty match id ("using the default match"). Now a forge
   node is an ink row (always) plus one free shape removal (`--pieces=on`), no fight, no gold — as `GameFlow._open_forge`.
   Effect on the first report: the Treasure lane's numbers (clear 91.0 %, gold 82.5) included ~half a default fight per
   visit; corrected values are in §4 (clear 93.5 %, gold 85.1). Peril / Safe / Elite had no forge and are unchanged.
2. **Event-led lanes were missing from the ROUTE table.** Route bookkeeping began inside `_world_match`, so a lane whose
   first node is an event (Mystery) never got an archetype and was dropped from the table — the "mystery never appears"
   finding of the first report. Now the fork is recorded for every kind. Mystery: 175 visits in the same 70 seeds (§5).
3. **A death in an event fight did not end the route** (the lane stayed "not ended" and was excluded from the clear %).
   Now it ends the route as a loss.
4. Instrumentation (§6) — the ROUTE row is unchanged in meaning; a ROUTE2 row was added per lane.

Determinism check after the changes: the Peril, Safe and Elite rows of the current configuration reproduce the first
pass to the last digit (same seeds; e.g. Peril 235 visits, 73.6 %, 107.6 gold, 44.5 HP, 2.31 relics).

## 4. Priority 1 — Peril balance

### 4.1 Lane probes (lane == policy, 5 characters pooled, weighted by visits; seeds 2002..2071)

NV = gold + 60 × relics − 1.6 × HP lost (the first report's yardstick: a shop relic ≈ 60 gold, a 25 % heal ≈ 40 gold).

| configuration / lane | visits | region clear % | gold (drops) | HP lost (net, pts) | relics | objective met / visit | NV gold-eq |
|---|---|---|---|---|---|---|---|
| current / safe | 190 | 90.5 | 91.2 | 35.8 | 1.55 | 0.00 | 127.1 |
| current / treasure | 245 | 93.5 | 85.1 | 35.8 | 1.75 | 0.00 | 132.5 |
| current / peril | 235 | **73.6** | 107.6 | 44.5 | 2.31 | 0.25 | 174.7 |
| current / elite | 205 | 88.8 | 99.0 | 41.4 | 1.83 | 0.00 | 142.3 |
| current / mystery | 175 | 94.9 | 80.7 | 32.1 | 2.21 | 0.00 | 161.8 |
| A / safe | 190 | 90.5 | 91.2 | 35.7 | 1.55 | 0.00 | 127.2 |
| A / peril | 235 | 73.6 | 107.6 | 44.5 | 2.31 | 0.25 | 174.8 |
| B / safe | 190 | 91.6 | 92.6 | 35.8 | 1.55 | 0.00 | 128.4 |
| B / peril | 235 | 74.0 | 108.4 | 44.6 | 2.31 | 0.26 | 175.9 |
| **C / peril** | 235 | **81.3** | **119.4** | 43.7 | **2.38** | 0.26 | **192.0** |

Against the `06` §3 targets (Safe = the reference of its own configuration):

| Target | current | A | B | C |
|---|---|---|---|---|
| Peril NV ≥ Safe + 25 % | +37 % met | +37 % met | +37 % met | **+51 % met** |
| Peril death rate ≤ Safe + 10 pts | +16.9 **not met** | +16.9 not met | +17.6 not met | **+9.2 met** |
| Peril HP cost = Safe + 15–25 pts (net) | +8.7 below | +8.8 below | +8.8 below | +7.9 below |
| Peril HP lost **in fights** vs Safe (gross, new ROUTE2) | +24.1 | +24.2 | +24.7 | +17.3 |

Reading: the "HP cost" band was written for gross fight damage; net of the heals the bot buys on the way it is +8–9 on
every configuration, while the gross fight loss (new counter) is inside the 15–25 band on all four. The acceptance
thresholds were not changed; the gross row is shown as the number the band was meant to measure.

Per character on the Peril lane (region clear % / gold / net HP lost / relics):

| character | current | A | B | C |
|---|---|---|---|---|
| kiem_si | 91.5 / 134 / 26 / 2.49 | 91.5 / 134 / 26 / 2.49 | 91.5 / 134 / 28 / 2.49 | 95.7 / 142 / 27 / 2.55 |
| phap_su | 78.7 / 116 / 53 / 2.49 | 78.7 / 116 / 53 / 2.49 | 78.7 / 116 / 51 / 2.49 | 95.7 / 143 / 48 / 2.57 |
| sat_thu | 59.6 / 85 / 46 / 2.04 | 59.6 / 85 / 46 / 2.04 | 59.6 / 85 / 45 / 2.04 | 66.0 / 97 / 51 / 2.15 |
| tho_san | 76.6 / 113 / 48 / 2.34 | 76.6 / 113 / 48 / 2.34 | 78.7 / 117 / 49 / 2.36 | 74.5 / 107 / 42 / 2.40 |
| giao_si | 61.7 / 90 / 51 / 2.17 | 61.7 / 90 / 51 / 2.17 | 61.7 / 90 / 50 / 2.19 | 74.5 / 109 / 50 / 2.21 |

C lifts the three heroes that died most (phap_su +17, giao_si +13, sat_thu +6) and leaves the Knight near 96 %; the
Assassin stays the Peril casualty (66 %), which is the lane doing its job on the lowest-HP hero rather than a defect.

**A is identical to the current configuration in every number** (235 visits, same clears, same gold to the decimal).
The simulated bot leaves a warned vent cell 0.4 s after the warning and an erupting cell at once (`sim_core.gd`
VENT_REACT_SEC, Story 039 notes), so it takes no vent ticks; `vent_tick_damage` is invisible to the bot. A can only be
judged in a playtest. **B** changes the bot only through the extra forced moves (+0.4 points, below the ±4-point
replicate noise). Neither is adopted or rejected on this evidence; they stay at the approved values.

### 4.2 Paired full runs (7 floors, same 70 seeds; v1 = the Phase 0 seeded baseline, others = hellfire on `value`)

| character | run win % v1 / cur / A / B / C | hellfire clear % v1 / cur / A / B / C | won minutes (median) v1 / cur / C | gold earned / spent (all runs) v1 / cur / C | relics at end v1 / cur / C |
|---|---|---|---|---|---|
| kiem_si | 21.4 / 24.3 / 24.3 / 24.3 / 25.7 | 97.1 / 98.6 / 98.6 / 97.1 / 100.0 | 50.8 / 51.9 / 51.7 | 745/417 · 775/387 · 781/394 | 12.4 / 12.3 / 12.4 |
| phap_su | 20.0 / 12.9 / 11.4 / 12.9 / **7.1** | 98.6 / 84.3 / 84.3 / 85.7 / 85.7 | 50.9 / 50.8 / 50.8 | 716/414 · 614/308 · 595/316 | 11.3 / 10.1 / 10.1 |
| sat_thu | 15.7 / 14.3 / 14.3 / 14.3 / 11.4 | 77.1 / 71.4 / 71.4 / 68.6 / 74.3 | 46.7 / 49.2 / 50.5 | 530/317 · 538/296 · 554/314 | 9.7 / 9.4 / 9.8 |
| tho_san | 12.9 / 15.7 / 15.7 / 17.1 / 14.3 | 92.9 / 81.4 / 81.4 / 82.9 / 85.7 | 51.5 / 50.8 / 50.9 | 566/344 · 602/329 · 590/334 | 10.5 / 10.6 / 10.6 |
| giao_si | 10.0 / 8.6 / 8.6 / 7.1 / 8.6 | 94.3 / 74.3 / 74.3 / 75.7 / 81.4 | 51.9 / 52.2 / 52.0 | 600/347 · 547/296 · 578/315 | 11.1 / 9.9 / 10.4 |
| **mean** | 16.0 / 15.2 / 14.9 / 15.1 / 13.4 | 92.0 / 82.0 / 82.0 / 82.0 / 85.4 | | | |

(The `cur` column differs slightly from the first report — phap_su 14.3 → 12.9, giao_si 10.0 → 8.6 — because the forge
nodes of the first pass were default fights; this is the corrected current configuration.)

Run-level guard (`06` §3: ± 10 points win rate, ± 15 % minutes): the means are inside it on every configuration
(largest −2.6 for C); **one character is outside it on C — phap_su 20.0 → 7.1 (−12.9)** — although C makes Hellfire
*easier* for phap_su (lane clear 78.7 → 95.7, region clear 84.3 → 85.7). The deaths moved to later floors (deaths by
floor v1 `0/0/1/8/14/15/18` vs C `0/1/1/10/16/19/16`): a different reward on floor 2 reshuffles the run's gold, relics
and later fights, and 70 runs resolve 1.4 points each. To tell chaos from a real effect the three configurations were
rerun on a second seed set:

Replicate seed set 3002..3071 (`balance/rep-*.txt`; v1 = hellfire on its v1 column map through `variants/region_rules_v1.json`):

| character | run win % v1 / cur / C | hellfire clear % v1 / cur / C | deaths by floor (f1 f2 f3 f4 f5 f6 f7 final) v1 · cur · C |
|---|---|---|---|
| kiem_si | 12.9 / 22.9 / 12.9 | 98.6 / 92.9 / 97.1 | 0/1/0/19/21/8/6/6 · 0/5/1/17/13/6/8/4 · 0/2/1/16/17/8/11/6 |
| phap_su | 5.7 / 25.7 / 24.3 | 98.6 / 85.7 / 91.4 | 0/1/6/27/11/8/13/0 · 0/10/5/10/13/5/8/1 · 0/6/7/13/14/5/8/0 |
| sat_thu | 22.9 / 12.9 / 7.1 | 90.0 / 78.6 / 74.3 | 0/7/3/16/7/11/5/5 · 0/15/7/16/5/5/10/3 · 0/18/6/15/8/6/6/6 |
| tho_san | 10.0 / 2.9 / 7.1 | 92.9 / 81.4 / 82.9 | 0/5/3/23/16/9/6/1 · 0/13/1/23/12/8/7/4 · 0/12/5/21/11/6/6/4 |
| giao_si | 4.3 / 18.6 / 14.3 | 94.3 / 82.9 / 81.4 | 0/4/3/19/13/13/12/3 · 0/12/1/13/5/9/15/2 · 0/13/4/10/8/7/13/5 |
| **mean** | 11.2 / 16.6 / 13.1 | 94.9 / 84.3 / 85.4 | |

The same character swings the other way on the second set (phap_su v1 → C: −12.9 on set 1, **+18.6** on set 2;
kiem_si +4.3 then 0.0; sat_thu −4.3 then −15.8). Per-character win rates at 70 seeds are seed noise of ± 10–15 points
whichever configuration runs; only the means carry information. Pooled over both sets (140 seeds × 5 heroes):

| | v1 | current | C |
|---|---|---|---|
| run win % (mean of 10 character-sets) | 13.6 | 15.9 | 13.3 |
| hellfire clear % | 93.5 | 83.2 | 85.4 |

Run-level guard on the pooled means: C −0.3 points vs v1 (band ± 10) — **met**; won-run minutes within ± 2 % — met.
Hellfire itself is about 8 points harder than v1 for a bot that always takes Peril/Elite (C) against 10 points on the
current configuration; a player who reads the lane bands can take Safe (clear ≈ v1).

**Verdict on Priority 1:** C is the only tested variable that moves Peril's death rate, it brings the gap inside the
band on the primary seed set (+9.2), the lane keeps its reward edge (+51 % NV) and its gross HP cost (+17 points in
fights), and the run-level guard holds on 140 seeds. A and B are not adopted: A is invisible to the bot, B is noise.
**Selected: C.** Note the margin: +9.2 against a +10 band on 235 visits is about one visit's worth; the playtest in
§10 is the real test.

## 5. Priority 2 — archetype distribution (`balance/map-sim-hellfire-10k-archetypes.txt`)

`tools/balance/map_sim.gd --seeds=10000 --pairs=assigned --regions=hellfire` (new ARCH rows), 10 000 maps, all valid,
deterministic (first 100 seeds × 2):

| archetype | maps holding it | lane 0 / 1 / 2 (screen order) | slot kinds (depth 1 · 2 · 4) |
|---|---|---|---|
| peril | 7 300 (73.0 %) | 2423 / 2429 / 2448 | danger · danger · danger |
| safe | 6 562 (65.6 %) | 2111 / 2209 / 2242 | battle · battle · battle 3293 / rest 3269 |
| treasure | 6 462 (64.6 %) | 2221 / 2185 / 2056 | battle · treasure · battle 3256 / forge 3206 |
| mystery | 4 860 (48.6 %) | 1605 / 1604 / 1651 | event · battle · event 2461 / treasure 2399 |
| elite | 4 816 (48.2 %) | 1640 / 1573 / 1603 | battle · miniboss · battle |

- Hostile archetypes (peril, elite) per map: 0 → 672, 1 → 6 540, 2 → 2 788, **3 → 0 (0.00 %)** — three hostile lanes
  cannot happen with the safe/treasure guarantee.
- Repeated archetype on one map: 0. Guarantee misses (neither safe nor treasure): 0. Gamble: miniboss on 10 000 / 10 000
  (floor 2). Technically-allowed-but-never-drawn archetypes: none.
- Expected rates from the weights (peril 1.5, safe 1, treasure 1, elite 0.8, mystery 0.8, three draws without
  replacement, then the guarantee): peril ≈ 73 %, safe ≈ 65 %, treasure ≈ 65 %, mystery ≈ 49 %, elite ≈ 48 %. The sample
  matches; lane position is uniform (the seeded shuffle works).
- The 70-seed route set: Mystery was offered on 175 of 350 visits (50 %) — see §4.1. **No configuration change**: the
  first report's "never appears" was the simulator's bookkeeping gap (§3), not rarity.

## 6. Priority 3 — simulation quality

What the simulator now measures (ROUTE2 row, per route that ended; current configuration, seeds 2002..2071):

| lane | heat at warden mean (count 0/1/2/3/4) | heat 3–4 at warden | heat max on route | objective fights / met | relic rows offered / taken | HP lost in fights | HP healed outside fights | event HP delta |
|---|---|---|---|---|---|---|---|---|
| safe | 1.34 (94/16/27/20/30) | 26.7 % | 3.02 | 0 / 0 | 0.90 / 0.61 | 50.1 | 9.8 | −0.6 |
| treasure | 0.82 (140/35/45/25/0) | 10.2 % | 2.24 | 0 / 0 | 0.29 / 0.29 | 45.3 | 6.3 | −0.9 |
| peril | 1.41 (64/60/22/39/15) | 27.0 % | 2.78 | 0.87 / 0.25 | 1.56 / 1.20 | 74.2 | 15.8 | −1.0 |
| elite | 1.56 (54/49/44/34/18) | 26.1 % | 3.04 | 0 / 0 | 1.02 / 0.74 | 56.6 | 10.1 | −1.0 |
| mystery | 0.85 (105/5/51/14/0) | 8.0 % | 1.79 | 0 / 0 | 0.75 / 0.56 | 33.1 | 3.7 | −5.8 |
| peril, variant C | 1.47 (65/61/26/43/18) | 28.6 % | 2.83 | 0.91 / 0.26 | 1.64 / 1.27 | 67.4 | 14.6 | −1.0 |

Inks (`--pieces=on`, the bot's piece policy; a separate probe set because the piece deck changes the fights):

| lane | ink rows offered / taken per route | forge visits / free removals | region clear % (pieces on) |
|---|---|---|---|
| safe | 0.98 / 0.35 | 0 / 0 | 94.7 |
| treasure | 2.07 / 0.71 | 0.51 / 0.51 | 92.7 |
| peril | 1.29 / 0.43 | 0 / 0 | 80.4 |

Per metric of the brief:

| Metric | Status |
|---|---|
| Ink earned and spent | **Measured with `--pieces=on` only** (rows offered / inks taken / free forge removals; an ink is spent the moment it is taken — there is no ink currency). The default probe set runs with pieces off, where inks are **unmeasured**. The bot's ink choice (smallest 2–3-cell shape) is a policy, not a player. |
| Heat at the Warden | **Measured** (ROUTE2). Finding: on every lane only 8–27 % of routes reach the warden at heat 3–4 (design intent ≥ 60 % on Peril), because the hub shop (−1) and the prepare rest (−2) sit between the lane and the warden and the bot takes them; the warden hook (`vent_surge` 3 vents) therefore fires in about a quarter of Peril routes. Not a tuning variable of this brief; recorded as a design question (§10). |
| Objective completion and rewards | **Measured for `no_hit_3` and `joiner`** (hits taken, joins): 0.87 objective fights won per Peril route, 25–26 % met; the bonus gold ×1.3 and the relic row are applied and counted in the ROUTE gold / relic rows. **Unmeasured: `big_cast` and `vent_dancer`** (the bot has no cast-size or vent-dodge counters; they count as not met, so the sim's 25 % is a floor). |
| Relics offered vs acquired | **Measured**: 1.56 rows offered vs 1.20 taken per Peril route (a row the bot declines is an empty roll — all relics owned or locked — not a choice). |
| Combat HP loss vs route HP cost | **Measured**: the ROUTE "HP lost" is net; ROUTE2 splits it into HP lost in fights, HP healed outside fights (rest, shop, passive heal on a win) and the events' signed delta. |
| Vent tick damage | **Unmeasured** — the bot never stands in a vent (§4.1 A). |
| Human reading of the lane bands, heat meter, previews | Not simulated; playtest only. |

## 7. Priority 4 — intro band modifier icons

Cause: `RunController.match_modifiers` (the node's profile ids) reached `match_params["modifiers"]` but
`RunHudView._draw_intro` never read them. Fix (`src/run/run_hud_view.gd`): a modifier block at the band's left end,
the arena block's size and vertical span (`intro_modifiers_rect`), one line per **active** modifier — a small angular
glyph (no box) and the glossary name in the warning colour. The ids come from the controller only, so a modifier in the
region's pool that was not drawn for the fight is never shown. The centred name and description lines shrink to the width
between the two blocks when either is shown, so nothing overlaps. Display only; no combat change.

Verification (`ui-balance-2026-11-12/`, 1280 × 720, windowed, muted; the earlier `ui/` set untouched):
`E8-battle-intro-active-modifiers.png` — the Peril slot-3 fight (seed 24) shows "Boxed In" and "Bigger blocks", the
same two the map preview lists in `E3-peril-end-preview-two-modifiers-objective.png`; the arena block ("Caldera",
Resonance ×1.5) and the title / name / hint lines are clear of it. Test: `world_map_v2_flow_test.gd` I1 now asserts
`controller.match_modifiers == the preview's ids` (2 of a pool of 5) and that the modifier block lies inside the band,
left of the arena block. E-series re-captured on the C configuration after §8: `ui-balance-2026-11-12-C/`.

## 8. Priority 5 — regression

Run on the final code and data (variant C applied), in this order:

| Check | Command / file | Result |
|---|---|---|
| Hellfire v2 unit suites U1–U28 | `tests/unit/run/map_v2/*_test.gd` (8 suites, headless) | FAILS=0 each (`route_archetypes_config_test` after the default-template update) |
| Flow I1 + I2 (profiles, Heat, rewards, forge, save/load reloads at the fork, before the hub, at the approach) | `tests/integration/run/world_map_v2_flow_test.gd` | FAILS=0, incl. the new intro-band assertions |
| Save / load compatibility | U25–U28 (`run_session_v2_test`), I1 reloads, E7 frame | green; save v8 unchanged — no format change was needed |
| v1 regions unchanged | `v1_map_wrapper_test` U5 (200 seeds × 7 pairs byte-equal wrap); `balance/map-sim-assigned-10k-C.txt` — 6 wrapped v1 pairs 60 000 / 60 000 valid | green; v1 data and generator untouched |
| Map simulation | `balance/map-sim-assigned-10k-C.txt` — 70 000 / 70 000 valid, determinism 0 failures, hellfire ARCH rows identical to §5 (the modifier count does not touch the draw), p50 0.54 ms, p95 0.92 ms | pass |
| Deterministic route simulation | `balance/final-probe-peril-kiem_si-determinism.txt` == `balance/C-probe-peril-kiem_si.txt` | identical |
| UI evidence on the tuned data | `ui-balance-2026-11-12-C/` E1–E8 (1280 × 720, windowed, muted): E3 preview lists one modifier ("Boxed In") and the objective; E8 intro band shows that one modifier, clear of the arena block; E7 resumed map == E5 | pass |
| Complete test suite | `balance/full-suite-balance-2026-11-12.txt` (`tools/qa/run_all_tests.sh`) | **286 / 286 suites green** (1620 s; `pattern_roster_fairness_test` included, no timeout) |

Earlier evidence kept unchanged: `ui/` (first pass), `route-sim-*.txt`, `fullrun-*.txt`, `full-suite-*.txt`,
`baseline-7floor-v1*`, `map-sim-*.txt`.

## 9. Final recommended configuration

**`assets/data/route_archetypes.json` — peril `modifier_slots` `[0, 1, 2]` → `[0, 1, 1]`.** Everything else as
approved: Heat per-kind steps, combat patch rows (A, B rejected on bot evidence — unmeasured / noise), warden hook, reward
tiers, archetype weights, modifier pool, map structure. Mirrored in `RouteArchetypes.default_data()` (the built-in
fallback the loader test compares with the file), `assets/data/schema.md`, `docs/design/world-map-v2/01` §B3 table,
`03` §3 template, `08` §B (0–1 modifiers). Tests pinned to the old value updated: `route_archetypes_config_test` U3,
`world_map_v2_flow_test` I1 (L0.4 now carries one modifier; the intro-band assertion checks that one).

Determinism of the shipped data: `balance/final-probe-peril-kiem_si-determinism.txt` (the peril probe rerun on
`assets/data/` after the change) is identical, row for row, to `balance/C-probe-peril-kiem_si.txt`.

Not changed, with the reason: heat 3 `vent_tick_damage` (A, unmeasurable by the bot), heat 4 interval (B, +0.4
points), archetype weights (Mystery is not rare, §5), prepare rest −2 (the heat-decay finding of §6 is a design
question for the user, not a tuning variable of this brief).

## 10. Remaining risks

- The Assassin (sat_thu) still clears Peril in 66 % of bot visits (Safe 87 %); the lane is meant to punish low-HP
  heroes, but a playtest should confirm it reads as a choice, not a trap.
- Heat rarely reaches the warden at 3–4 (§6); the warden hook and the "heat 3–4 at the warden" promise of `01` need a
  design decision: prepare rest −2 → −1, or key the hook to the route's highest heat, or accept the decay as the cost
  of resting. Any of these is a data change, none is made here.
- `vent_tick_damage` (A) and the vent interval (B) are judged by humans only; the bot is blind to the first and nearly
  so to the second. If a playtest finds the vents too punishing at heat 3–4, A is the knob, unmeasured by this tool.
- Objective hit rate (25 %) is a floor: two of four objectives cannot be met by the bot.
- Seed noise: 70 seeds = 1.4 points per run; per-character swings under ±6 points are not evidence (the replicate set
  bounds this, §4.2).
- Not covered: Android device check of the intro block at phone size; the other six regions (unchanged by design).
