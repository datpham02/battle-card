# World Map v2 — Human playtest: Hellfire Warden at Heat 3 / 4 (C vs D) — preparation (2026-11-12)

> **Superseded for B1 (same day, later):** this document describes the **pre-B1** data. Its F2 finding (the hook
> `vents 3` was a no-op) led to the B1 fix; under B1 the hook sets the surge interval to 7 s and Heat 4 burns 2.5 s.
> The current playtest plan, matrix and result log are in `human-playtest-b1-warden-2026-11-12.md`. Kept unchanged
> below as the historical record.

User brief: "Prepare Human Playtest for Heat Decay C vs D". **Preparation only.** Production stays on C:
`assets/data/region_rules.json` rest −2, shop −1; `route_archetypes.json` peril [0,1,1]; warden hook `vent_surge`
at actual Heat ≥ 3 on entry. No code, data or test file was changed for this preparation; nothing committed.

Companion documents: `heat-decay-experiment-2026-11-12.md` (the simulation, C vs D) and
`balance-validation-2026-11-12.md` (variant C). Evidence folder of this preparation:
`production/qa/evidence/world-map-v2/human-playtest-heat-decay/` (launch frame, seed scan output, scan script).

## 0. Two findings that shape the playtest

**F1 — C and D are the same fight at the same Heat.** The warden encounter is composed from the region rule and the
*integer Heat at entry* only (`EncounterComposer.compose` → `RegionRules.combat_patch(rule, gauge)` +
`RegionRules.warden_hook(rule, gauge)`). C and D differ in one number, the Rest decay, which only changes *which Heat the
player arrives with*. So **C3 ≡ D3 and C4 ≡ D4** in the arena: same vents, same timers, same traits, same boss. The
playtest therefore measures the warden at **Heat 2 (control), 3 and 4**, and the C-vs-D question becomes "is the fight
that D makes ~1.5–2× more frequent (Heat 3–4 on 45 % of Peril / 55 % of Elite routes instead of 30 % / 26 %) acceptable
for a human?". A separate D-only observation (Rest leaving 1 Heat on the gauge) is covered in §4.4.

**F2 — the warden hook "vents 3" has no observable effect in the warden's arena.** Verified live (seed 24, Heat 4,
headless probe `heat_scan.gd --probe=24`, output in §2.3): the warden Chúa Quỷ Lửa (`inferno_lord`) always fights in
the **caldera** (`chapters.json` → `"arena": {"shape": "caldera"}`), whose player half has exactly **2 vents** (whole
columns 1 and 4, five cells each; `arenas.json`). The boss's own `vent_surge` already fires `vents: 2` = both columns;
the hook raises the parameter to 3, and `TileHazards.trigger_vents(PLAYER, 3)` starts **2** (there is no third vent).
The surge is identical at every Heat. What Heat ≥ 3 *does* change on the warden is the rest of the Heat row:

| Heat at entry | regular vent clock (one random vent of the 4 in the arena) | same after the boss's phase 2 (×0.7) | burn per tick on an erupting cell | per full eruption (2 s / 0.5 s = 4 ticks) | boss piece-drop interval | surge (`vent_surge`) |
|---|---|---|---|---|---|---|
| 0 | 7.0 s | 4.9 s | 2 | 8 | ×1.0 | both player columns every 10 s (first at 10 s) |
| 1 | 6.0 s | 4.2 s | 2 | 8 | ×1.0 | same |
| 2 (control) | 5.0 s | 3.5 s | 2 | 8 | ×1.0 | same |
| **3** | **4.5 s** | **3.15 s** | **3** | **12** | **×0.9** | same (hook vents 3 → 2 started) |
| **4** | **4.0 s** | **2.8 s** | **3** | **12** | **×0.9** | same (the Heat-4 row's extra `vent_surge` entry is deduped by the boss's own, interval stays 10 s) |

(`vent_warn_sec` 1.0, `vent_sec` 2.0, `vent_tick_sec` 0.5 from `combat.json` hazards, unchanged by Heat. Hero HP:
kiem_si 200, phap_su 210, sat_thu 180, tho_san 200, giao_si 210.)

So "Heat 3 vs Heat 4" on the warden is a 0.5 s difference on the regular vent clock and nothing else; "Heat 2 vs 3" is
0.5 s on the clock, +1 burn per tick (+4 per eruption) and the boss dropping pieces 10 % faster. The playtest should
confirm or refute that these are felt. **Investigated in `warden-heat-hook-investigation-2026-11-12.md` (root cause, options, recommendation B1).** This is a finding for the user, not something changed here: if the hook is
meant to be felt, either the caldera needs a third vent or the hook needs to override another parameter
(`interval_sec`, `first_delay_sec`) — a design decision, out of this brief's scope.

## 1. How the scenarios are launched (existing tools, no code change)

The game's own DEV launch args (`src/run/game_flow.gd` header) open a fresh seeded run on the Hellfire map at floor 2
with floor 1 auto-cleared, on a **memory store** (dev args switch the progress store to memory: `user://progress.json`
is never written, so nothing to reset and the user's real save is untouched):

```bash
godot --path . --windowed --resolution 1280x720 -- --region=hellfire --at-floor=2 --seed=27 --lang=vi
```

- The Hellfire map of a seed is the same one the headless scan and the evidence runner see (seed 24 reproduces the
  `ui/E2` map: peril / safe / treasure, forge on the treasure lane — frame
  `human-playtest-heat-decay/launch-seed24-hellfire-floor2.png`).
- The hero starts floor 2 "fresh" (full HP, 20 gold, starting deck, no relics) — identical in every scenario, which is
  what a controlled comparison needs, but weaker than a real floor-2 hero. To approximate a real floor-2 hero add
  `--hp=N`, `--gold=N`, `--deck+=id,id`, `--relics=id,id` (all DEV args of the same header) — keep them identical
  across scenarios.
- Character: `--character=<id>` (kiem_si, phap_su, sat_thu, tho_san, giao_si) picks the hero exactly as the select
  screen would (DEV arg, Story 018). Without it the dev run uses the default (the launch frame shows kiem_si).
- Audio: the brief does not need captures; omit `--audio-driver Dummy` to hear the vent cues (they are part of what is
  judged). For a silent capture add it.
- The map screen shows **"Nhiệt n/4"** under the floor banner (`ui.map.heat`) and each node preview shows
  **"Nhiệt a -> b"** (what the node will do to Heat). That banner value *when the warden node is selected* is the Heat
  at warden entry — the number the hook reads.
- Reset between scenarios: close the game and relaunch the command (memory store = nothing persists). Within a
  scenario, death = relaunch.

## 2. Scenario matrix

All scenarios: hero kiem_si unless the per-character pass is being run, seed 27, Hellfire floor 2, the same warden
(Chúa Quỷ Lửa, caldera), the same starting state. Seed 27's map (from the headless scan, `heat-scan-seeds-1-60.txt`,
PATH rows for seed 27): three lanes **elite (L0)**, **safe (L1)**, **peril (L2)**; the hub is a **Rest** (no shop on
this map), the "prepare" node is a **Forge** (no Heat), the "gamble" node a miniboss (+2).

| Scenario | Variant | Route on seed 27 | Heat at warden entry | Hook | Equivalent to |
|---|---|---|---|---|---|
| **H2 (control)** | C | peril lane: battle, danger, danger → hub rest (−2) → battle/danger → **prepare (forge)** → warden | **2** | none | the warden most Peril players meet under C today |
| **C3 = D3** | C | elite lane: battle, battle, miniboss → hub rest (−2) → battle/danger → **prepare (forge)** → warden | **3** | `vent_surge` (no-op, F2) + Heat-3 row | **D3**: the same fight; under D the *peril* lane's prepare route arrives at 3 (2 + 1 kept by the rest) |
| **C4 = D4** | C | any lane → hub rest → lane end → **gamble (miniboss)** → warden | **4** | `vent_surge` (no-op) + Heat-4 row | **D4**: the same fight; under D the elite prepare route also arrives at 4 |
| **D3 (true D route)** | D | peril lane, prepare (forge) | 3 | same as C3 | requires the D rule loaded in the game — see §4.4 |
| **D4 (true D route)** | D | elite lane, prepare (forge) | 4 | same as C4 | same |

Why seed 27: it is the only seed among 1–60 with, on one map, a rest-route at Heat 2, a rest-route at Heat 3 under C and
a gamble route at Heat 4 — every warden condition without touching the rule file. Alternates (same scan): **seed 49**
(peril prepare → 2, elite prepare → 3, gamble → 4, hub rest), **seed 6** (treasure lane gamble → 3, peril prepare → 2,
gamble → 4, hub rest), **seed 24** (hub *shop*; peril gamble → 4, peril prepare → 1, treasure+forge+gamble → 3; the
map of the existing evidence).

What the player has to win on the way (real fights, no dev win): H2 / D3 = 1 battle + 2 dangers (+1 battle or danger)
≈ 4 fights; C3 = 2 battles + 1 miniboss (+1) ≈ 4 fights incl. a miniboss; C4 = the lane + the gamble miniboss ≈ 5 fights.
The scan's heat numbers assume the player does not die and does not skip nodes (each node on the route is mandatory).

### 2.1 Expected behaviour in the warden fight (what "vent_surge active" looks like)

- At **10 s** after the fight starts, and every 10 s after, **both** vent columns of the player's half (columns 1 and 4
  of the 5-wide half, counted from the far edge; the middle column 3 has the three missing cells) light up with the
  ember streak + **"SẮP PHUN"** warning for 1 s, then erupt for 2 s. This is the surge; it happens at **every Heat**
  (F2). If only one column lights up at a surge, the other was already erupting from the regular clock.
- Between surges the regular clock makes **one random vent of the whole arena** (either half) warn → erupt every
  7 / 6 / 5 / 4.5 / 4 s (Heat 0–4); the player's columns are hit about every other time.
- After the boss drops to 50 % HP (phase 2 banner) the regular clock runs ×0.7.
- Standing on an erupting cell: 2 burn per 0.5 s (Heat ≤ 2), 3 (Heat ≥ 3).
- The intro band's modifier block is **empty** on the warden (the hook is a trait parameter, not a modifier) — do not
  expect a "vent_surge" icon there; the Heat banner on the map is the readout.

### 2.2 How to verify the Heat and the hook during play

| What | Where | Expected |
|---|---|---|
| Heat at warden entry | map screen, "Nhiệt n/4" under the floor banner, with the warden node selected | H2: 2, C3: 3, C4: 4 |
| Hook active (Heat ≥ 3) | not displayed; inferred from the Heat (hook = `min_gauge: 3`, no other condition) and confirmed by the regular vent clock ≤ 4.5 s and 3-damage ticks | — |
| Surge | both player columns warn together at 10 s, 20 s, … | every scenario |
| Heat-3/4 row | count seconds between two regular (single-vent) eruptions before phase 2: ~5 s (H2) vs ~4.5 s (3) vs ~4 s (4); burn numbers on an erupting cell 2 vs 3 | — |

Optional hard proof (headless, read-only, no gameplay): the scan script's probe prints the live `TileHazards` values
and the trait params the warden actually received for a seed (`human-playtest-heat-decay/heat_scan.gd.txt`, run from
the scratchpad copy; §2.3 is its output for seed 24 at Heat 4).

### 2.3 Probe output (seed 24, Heat 4, headless, 2026-11-12)

```
PROBE 24: heat at warden entry = 4 (rule_state { "id": "heat", "gauge": 4 })
PROBE 24: match traits = [{ "id": "vent_surge", "params": { "interval_sec": 10.0, "vents": 3.0 } }, { "id": "phase_shift", "params": { "at_hp_ratio": 0.5, ..., "vent_interval_mult": 0.7 } }]
PROBE 24: arena = { "shape": "caldera" }
PROBE 24: hazards vent_interval_sec=4.0 vent_warn_sec=1.0 vent_sec=2.0 vent_tick_sec=0.5 vent_tick_damage=3.0
PROBE 24: player-half vents = 2
PROBE 24:   vent cells [(1, 0), (1, 1), (1, 2), (1, 3), (1, 4)]
PROBE 24:   vent cells [(4, 0), (4, 1), (4, 2), (4, 3), (4, 4)]
PROBE 24: enemy-half vents = 2
PROBE 24: trigger_vents(PLAYER, 3) started 2
```

## 3. Observation checklist (fill per scenario, per character)

Score 1–5 where a scale is given; write numbers where asked. Play each scenario at least twice (the vent RNG differs
per run); record the worst and the typical run.

1. **Vents**: how many columns erupt per surge (expect 2); where (expect columns 1 and 4 of your half).
2. **Timing**: seconds from the fight start to the first surge (expect ~10); seconds between regular single-vent
   eruptions before phase 2 (expect ~5 / 4.5 / 4 for Heat 2 / 3 / 4); after phase 2 (×0.7).
3. **Readability**: is the 1 s "SẮP PHUN" warning enough to leave the column? (1 = never saw it coming, 5 = always clear)
4. **Dodgeability**: with both columns erupting, the free cells are columns 0, 2, 3 (col 3 minus its 3 missing cells).
   Could you always reach one in time? Count the surges you could not escape.
5. **Damage taken from vents**: total burn damage from vents over the fight (watch the HP bar; ticks are 2 or 3);
   number of eruptions you stood in.
6. **Pressure vs unavoidable damage**: did a surge ever coincide with a boss cut / pin so that no safe cell was
   reachable? How often? (this is the fairness question for "three vents" — here effectively "two whole columns")
7. **Per character**: did the fight feel fair for this hero's movement and cast tempo? (1–5) Note the hero's HP at the
   end and whether the hero died.
8. **Heat 3 vs Heat 4**: after playing both, could you tell them apart blind? What gave it away (clock, burn, boss
   tempo)? (expect: barely — 0.5 s on the clock)
9. **Heat 2 vs Heat 3**: same question (expect: the 3-burn ticks and the faster boss drops are the only differences).
10. **Enjoyment**: challenging-but-fun (1–5); would you take the Peril lane again knowing the warden feels like this?
11. **D-specific** (only if §4.4 is done): with Rest leaving 1 Heat on the gauge, did the Rest-vs-Gamble choice feel
    different from C? Did you ever choose to skip the Rest?

## 4. Procedure

### 4.1 Per scenario

1. Launch: `godot --path . --windowed --resolution 1280x720 -- --region=hellfire --at-floor=2 --seed=27 --lang=vi --character=kiem_si`
   (prefix with the engine path, e.g. `C:/Users/ADMIN/AppData/Local/Microsoft/WinGet/Links/godot.exe`; swap the
   `--character=` id per hero).
2. On the map read "Nhiệt 0/4". Take the lane the scenario names (lane order on seed 27: elite / safe / peril — the
   banners name them). Play every node of the lane for real.
3. At the hub (Rest): rest. Read the Heat (seed 27 under C: elite lane 4 → 2, peril lane 3 → 1, safe lane 3 → 1; the
   node preview shows "Nhiệt a -> b" before you confirm; the PATH rows of the scan give every route's values).
4. Lane end node, then at the approach choose **prepare (forge)** for H2 / C3 or **gamble (miniboss)** for C4.
5. With the warden selected, write down the banner Heat → this is the scenario's Heat at entry. If it is not the
   expected value, you took a different node than the route says — abort the scenario and relaunch.
6. Fight the warden. Fill §3. Screenshot (PrtSc or the app's capture) the first surge and the end state; save them under
   `production/qa/evidence/world-map-v2/human-playtest-heat-decay/<scenario>-<hero>-<n>.png` (new files only).
7. Close the game. Nothing to reset.

### 4.2 Per character
Repeat H2 / C3 / C4 for each of the five heroes (15 fights minimum, 30 with the repeat). If time is short, prioritise
sat_thu and giao_si (the two heroes already at 65 % / 72 % Peril clear in the sim) and kiem_si (the strongest).

### 4.3 Order
H2 first (calibrates "normal"), then C4 (the extreme), then C3; the difference question in §3 items 8–9 is answered
after all three.

### 4.4 The true-D route (optional, needs a decision)
Playing a *route* under D (to feel "Rest keeps 1 Heat") needs the game to load rest −1. The production file must not
change, and the game has no rule-file override. Two ways, neither done here:

- **(a) Smallest code change (proposed, not implemented)**: a DEV-ONLY arg `--region-rules=<res path>` parsed in
  `GameFlow`'s dev-arg block (next to `--seed=`), doing
  `RegionRules.set_shared(RegionRules.load_from_file(path))` before the run starts — ~6 lines in `src/run/game_flow.gd`
  plus a header line; mirrors `deck_sim`'s flag of the same name; no effect without the arg; `set_shared` already
  exists for tests. Launch would then be the §4.1 command plus
  `--region-rules=res://production/qa/evidence/world-map-v2/variants/region_rules_D.json`.
- **(b) No code change**: temporarily copy `variants/region_rules_D.json` over `assets/data/region_rules.json` for
  the session and restore it with `git checkout -- assets/data/region_rules.json` afterwards. Excluded by this brief
  ("Do NOT change assets/data/region_rules.json"), listed only for completeness.

Because of F1 this step is **not needed to judge the warden**; it only adds the route-level feel (item 11).

## 5. Result table (fill after playing)

| Scenario | Hero | Run | Heat at entry (banner) | first surge at (s) | columns per surge | regular eruptions before phase 2: gap (s) | surges not escapable | vent damage taken | HP end / died? | fair (1–5) | fun (1–5) | notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| H2 | kiem_si | 1 | | | | | | | | | | |
| H2 | kiem_si | 2 | | | | | | | | | | |
| C3 | kiem_si | 1 | | | | | | | | | | |
| C3 | kiem_si | 2 | | | | | | | | | | |
| C4 | kiem_si | 1 | | | | | | | | | | |
| C4 | kiem_si | 2 | | | | | | | | | | |
| H2 | phap_su | 1 | | | | | | | | | | |
| C3 | phap_su | 1 | | | | | | | | | | |
| C4 | phap_su | 1 | | | | | | | | | | |
| H2 | sat_thu | 1 | | | | | | | | | | |
| C3 | sat_thu | 1 | | | | | | | | | | |
| C4 | sat_thu | 1 | | | | | | | | | | |
| H2 | tho_san | 1 | | | | | | | | | | |
| C3 | tho_san | 1 | | | | | | | | | | |
| C4 | tho_san | 1 | | | | | | | | | | |
| H2 | giao_si | 1 | | | | | | | | | | |
| C3 | giao_si | 1 | | | | | | | | | | |
| C4 | giao_si | 1 | | | | | | | | | | |

Blind-difference answers (§3 items 8–9): Heat 3 vs 4: ______ ; Heat 2 vs 3: ______.

## 6. Decision rule (C or D)

The simulation criteria of the heat-decay brief stay in force; this playtest adds the human criterion the simulation
could not measure. **Adopt D only if all of the following hold**, otherwise keep C:

1. **Sim criteria already measured** (`heat-decay-experiment-2026-11-12.md` §0): Peril NV ≥ Safe +25 % (met), run-level
   guard (met), warden Heat 3–4 activation up meaningfully (met), other lanes unchanged (met), and the Peril death gap
   ≤ +10 pts — **nominally not met at +11.1 (C: +8.8)**. This is not waived here: adopting D requires the user to accept
   explicitly that the +2.3-pt difference between the two gaps is within the method's noise (§4.2 of that report:
   Peril clear unchanged 80.8 → 80.6, the move is on the Safe side) — or to re-measure with a third seed set and apply
   the ≤ +10 rule to the pooled result as it comes out.
2. **Human warden criterion (this playtest)**: across the heroes played, the Heat 3 and Heat 4 wardens are rated fair
   ≥ 3 and fun ≥ 3 by the player, no hero dies to the warden *because of vent damage* in both of its runs, and
   "surges not escapable" is 0 or explained by a boss cut the player could have avoided. If any hero is consistently
   unfair at Heat 3–4, D fails (D sends ~1.5–2× more routes there).
3. **Heat 3–4 must be a felt step**: if items 8–9 say the player cannot tell Heat 2 / 3 / 4 apart, then D changes
   nothing a player notices on the warden and the decision should rest on the route feel (item 11) and the sim's NV /
   guard results alone — in that case keep C unless item 11 is clearly in D's favour, and raise F2 (the no-op hook) as
   the thing to fix first.

Keep C if the playtest is not run, is run on one hero only, or any item of rule 2 fails.

## 7. Known limitations

- **No true C-vs-D blind test is possible**: at equal Heat the fights are identical (F1). The comparison is Heat 2 vs 3
  vs 4, and D's effect is read off the sim's reach rates (30 → 45 % Peril, 26 → 55 % Elite at Heat 3–4).
- **The hook is a no-op in the caldera** (F2). "vent_surge vents 3" was the designed teeth of the warden hook; it has
  none in the shipped arena. The playtest will be judging the Heat row (clock 4.5 / 4 s, burn 3), not the hook.
- **Fresh hero at floor 2**: the dev launch skips floor 1's rewards; the warden is harder than for a real floor-2 hero
  with relics and a grown deck. Consistent across scenarios, but absolute difficulty readings are pessimistic.
- **Route fights are real**: reaching the warden on the elite lane means beating a miniboss first; a death on the way
  means a relaunch. The scan's Heat values assume every node on the route is played.
- **Vent RNG**: the regular clock's vent choice and the surge order are seeded per match; two runs of the same
  scenario differ. Hence two runs per scenario for kiem_si.
- The seed scan covers seeds 1–60 on kiem_si (the Hellfire map depends on the run seed and floor, not on the hero, so
  the routes hold for every hero; not re-verified per hero).
- Nothing here measures the Shop-vs-Rest distinction or the Peril reward band — those remain the sim's domain.

## 8. Files of this preparation

- `production/qa/evidence/world-map-v2/human-playtest-heat-decay-2026-11-12.md` (this document)
- `production/qa/evidence/world-map-v2/human-playtest-heat-decay/launch-seed24-hellfire-floor2.png` — frame 60 of the
  dev launch (`--region=hellfire --at-floor=2 --seed=24`, 1280×720): Hellfire floor 2 map, "Heat 0/4", node preview
  "Heat 0 -> 1"
- `production/qa/evidence/world-map-v2/human-playtest-heat-decay/heat-scan-seeds-1-60.txt` — every entry → warden path
  of seeds 1–60 with the Heat at entry under C and D (1080 paths)
- `production/qa/evidence/world-map-v2/human-playtest-heat-decay/heat_scan.gd.txt` — the scratchpad scan / probe
  script (copy for reproducibility; it lives outside the repo and is not a test)
- Production data untouched: `assets/data/region_rules.json`, `assets/data/route_archetypes.json`; no `src/`, `tests/`
  or `tools/` change in this step.
