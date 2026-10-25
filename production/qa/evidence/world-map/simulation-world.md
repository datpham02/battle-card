# Story 031 Part F: world-run simulation (5 floors + final match)

Tool: `tools/balance/deck_sim.gd --world` (documented in `tools/balance/README.md`). Date: 2026-10-25.
Runs: 70 seeds per character, `build` policy, region pick `random` (seeded, same path for every
character on the same seed), `cleared_bosses = 1`. One process per character. The raw output of every
run is in `simulation-world-raw.txt`, next to this file.

Bot line (identical in every run): `dodge=0.85 (TD-006 legacy default, not re-anchored) gap=0.60-1.60s
aim=0.90 counter=0.50 place=1.20s join=1.00/1.00s hold=1 choose=0.80s aware=0.00 sig=rules dt=0.050 |
overrides: none`.

**Assumption:** `node_overhead_sec = 25` per node (node pick, reward, reading). Estimated run time =
(Σ real match seconds + 25 × nodes) / 60. "Real" seconds are the player's wall clock, including the
card-menu slow motion. Sim seconds are about 35 % lower. The overhead does not count the region pick
screen or the match intro and end delays.

Node policy: Story 022's order (treasure > rest > miniboss at ≥ 70 % HP > battle > danger), plus Story
031's rule: below 50 % HP, take `rest` first. In the default frame, column 1 always holds exactly one rest
or treasure, so the bot never fights in column 1. A region is therefore 2 fights (battle, boss), and a won
run is 11 matches over 16 nodes.

**Shipped (2026-10-25):** Proposal 1 is now the data in `assets/data/chapters.json` (`floor_scaling`
hp_mult 1.0 / 1.1 / 1.2 / 1.3 / 1.4 / final 1.5, floor-4 `size_add` 0, `region_normalize.ch1` 0.75 / 1.05 / 0,
`floor_heal_ratio` 0.35). The P1 column below is therefore the shipped measurement (the sim is seeded and
applied P1 through in-memory overrides equal to the shipped values). Still open after P1: Sát thủ run win
5.7 %, region gap at one floor 30–56 points (floors 4–5 are thin samples), won run 24–28 estimated minutes.

## Results against the targets

| Target (story Part F) | Baseline (chapters.json as is) | Proposal 1 | Proposal 2 |
|---|---|---|---|
| Run win (build): Kiếm sĩ 20–40 % | **2.9 %** FAIL | **30.0 %** PASS | 11.4 % FAIL |
| Run win (build): Sát thủ 20–40 % | **2.9 %** FAIL | **5.7 %** FAIL | 0.0 % FAIL |
| Run win (build): Pháp sư ≥ 10 % | **2.9 %** FAIL | **18.6 %** PASS | 5.7 % FAIL |
| Won run 40–50 est. minutes (kiem / phap / sat) | 29.6 / 28.0 / 26.0 FAIL | 27.7 / 25.1 / 24.2 FAIL | 35.7 / 30.3 / – FAIL |
| Regions at the same floor ≤ 15 pts apart (largest gap; kiem / phap / sat) | 75.0 / 75.7 / 60.0 FAIL | 30.2 / 56.3 / 46.7 FAIL | 42.9 / 49.2 / 25.6 FAIL |
| No floor > 40 % of deaths (largest share) | 22.1 / 33.8 / **42.6** (Sát thủ floor 3) | 26.5 / 28.1 / 31.8 PASS | 25.8 / 31.8 / 32.9 PASS |
| Survival decreasing by floor | PASS (all) | PASS (all) | Pháp sư FAIL (one floor with 0 deaths) |
| Boss hits per won run (kiem / phap / sat) | 39.5 / 42.5 / 33.5 | 41.4 / 34.3 / 29.8 | 54.4 / 39.0 / – |
| Final luck, all runs (rarity weights c/r/e at that luck) | 8.2 / 8.9 / 7.6 (65/26/8–9) | see tables | see tables |

The sawtooth is visible. In the baseline, mean HP entering a floor is 100 → 89 → 81 → 76 → 75 % (Kiếm
sĩ), and it falls to 41–52 % after each boss before the floor heal. Almost every death is a region boss,
for example Kiếm sĩ: 59 of 68 deaths at a region boss, 2 at the final match (`WORLD DEATHS` lines). A won run reaches luck ≈ 16 (16 nodes). The final
luck in the table is the mean over all runs, dead ones included.

**How noisy is the region gap?** With 70 seeds, a (floor, region) cell holds 3–26 runs. At floors 4–5
most cells hold 5–15 runs, so one cell's clear % has a standard error of about 12–20 points. Below
roughly 200 seeds, the "≤ 15 points" target cannot be resolved at floors 4–5. The **floor-3 gap is
real**, though. In the baseline, ch1 clears 50 / 12 / 25 % (kiem / phap / sat) while ch2 clears
90 / 88 / 64 %, with 10–21 runs per cell. ch1 at `region_normalize` 1/1/0 is the hardest region from
floor 3 on, the opposite of the old chapter order.

## Proposals tested (in-memory `--world-set`, chapters.json not edited)

**Proposal 1: difficulty curve, ch1 parity, floor heal.**
`--world-set=norm.ch1.hp_mult:0.75,norm.ch1.step_mult:1.05,scale.2.hp_mult:1.1,scale.3.hp_mult:1.2,scale.4.hp_mult:1.3,scale.4.size_add:0,scale.5.hp_mult:1.4,scale.final.hp_mult:1.5,heal:0.35`

- `floor_scaling.hp_mult` 1.00 / 1.10 / 1.20 / 1.30 / 1.40 / final 1.50 (was 1.00 / 1.15 / 1.30 / 1.50 /
  1.70 / 1.90). `size_add` on floor 4 goes from 1 to 0. Step and defense are unchanged.
- `region_normalize.ch1` = 0.75 / 1.05 / 0 (was 1 / 1 / 0).
- `floor_heal_ratio` = 0.35 (was 0.25).
- Result: Kiếm sĩ 30.0 % and Pháp sư 18.6 % reach their targets. Sát thủ moves only from 2.9 % to 5.7 %.
  The death shares all pass. The region gap shrinks (Kiếm sĩ 75 → 30) but stays above 15, and ch1 is
  still the lowest region at floors 3–5 for Pháp sư and Sát thủ. Run time does not change (≈ 25–28 min).

**Proposal 2: Proposal 1 plus one more forced battle column per region** (`battle_columns:1`, region =
battle, battle, branch, boss: 4 columns).

- The won run grows from 27.7 to 35.7 min (Kiếm sĩ), still short of 40.
- Run win halves: 11.4 / 5.7 / 0.0 %. Five more fights per run, with no extra healing, cost more than the
  extra rewards give back.

## Recommendations (data only, not applied; the owner of chapters.json decides)

1. **Take Proposal 1's curve as the new starting point.** It is the only tested set that puts two of
   the three characters in range, and it fixes the floor-3 death spike for Sát thủ. Apply it to
   `world.floor_scaling`, `world.floor_heal_ratio` and `chapters[ch1].region_normalize`.
2. **Sát thủ (5.7 %) is a character problem, not a world-data problem.** At the same data, Kiếm sĩ
   wins 30 % and Pháp sư 18.6 %. Its deaths sit at the floor 3–4 bosses. Hand this to character /
   balance tuning (Story 040 or a follow-up). World data that lifts Sát thủ to 20 % would push Kiếm sĩ
   above 40 %.
3. **ch1 needs more than a flat normalize.** At 0.75 HP it is still the hardest region from floor 3 on.
   The next step is a per-match look at ch1's tier-2 and boss pool at floors 3–5. deck_sim `--world`
   does not print per-match tables yet; adding them is a small tool change.
4. **Run length cannot reach 40 min with the frame alone without breaking the win targets.** One more
   battle column gives +8 min and halves the win rate. The options are (a) one battle column **plus**
   a softer curve than Proposal 1, which is untested because of the two-proposal limit; (b) let Story 033's
   shop and event nodes carry the time, since non-combat nodes add overhead but no damage; (c) re-check
   the 25 s overhead and the bot's match pace on a phone (playtest gate 8). The estimate scales directly
   with both.
5. Boss hits per won run (30–54) are above the old 15–30 chapter band. That band was set for one
   chapter, so a 5-floor run needs its own target.

## Tables (generated from the raw output)

### Baseline (chapters.json as is)

```text
deck_sim --world (Story 031): seeds=70 timeout=180s policies=["build"] characters=["kiem_si"] cleared_bosses=1 region-pick=random node-overhead=25s (ASSUMPTION: node pick + reward + reading, per node) world-set=none
bot: dodge=0.85 (TD-006 legacy default, not re-anchored) gap=0.60-1.60s aim=0.90 counter=0.50 place=1.20s join=1.00/1.00s hold=1 choose=0.80s aware=0.00 sig=rules dt=0.050 | overrides: none
world: floors=5 choices=2 pool=["ch1", "ch2", "ch3"] columns=3 heal=0.25 final={ "region": "ch3", "match_id": "mist_lord" } tiers={ "1": [0, 1, 1], "2": [0, 1, 1], "3": [1, 2, 2], "4": [1, 2, 2], "5": [1, 2, 2] }
  floor_scaling 1: { "hp_mult": 1.0, "step_mult": 1.0, "defense_add": 0.0, "size_add": 0 }
  floor_scaling 2: { "hp_mult": 1.15, "step_mult": 0.95, "defense_add": 0.0, "size_add": 0 }
  floor_scaling 3: { "hp_mult": 1.3, "step_mult": 0.9, "defense_add": 1.0, "size_add": 0 }
  floor_scaling 4: { "hp_mult": 1.5, "step_mult": 0.85, "defense_add": 1.0, "size_add": 1 }
  floor_scaling 5: { "hp_mult": 1.7, "step_mult": 0.8, "defense_add": 2.0, "size_add": 1 }
  floor_scaling final: { "hp_mult": 1.9, "step_mult": 0.8, "defense_add": 2.0, "size_add": 1 }
  region_normalize ch1: { "hp_mult": 1.0, "step_mult": 1.0, "defense_add": 0.0 }
  region_normalize ch2: { "hp_mult": 0.85, "step_mult": 1.05, "defense_add": 0.0 }
  region_normalize ch3: { "hp_mult": 0.75, "step_mult": 1.1, "defense_add": -1.0 }
node policy: rest when HP < 50%, else treasure > rest (heal < 50% else forge) > miniboss at >= 70% HP > battle > danger; boss when alone. Region boss: boss reward + token + floor heal. Run time = (sum of match REAL seconds + overhead x nodes) / 60.
deck_sim --world (Story 031): seeds=70 timeout=180s policies=["build"] characters=["phap_su"] cleared_bosses=1 region-pick=random node-overhead=25s (ASSUMPTION: node pick + reward + reading, per node) world-set=none
deck_sim --world (Story 031): seeds=70 timeout=180s policies=["build"] characters=["sat_thu"] cleared_bosses=1 region-pick=random node-overhead=25s (ASSUMPTION: node pick + reward + reading, per node) world-set=none
```

**WORLD SUMMARY**

| character | policy | run win % | wins | boss hits / WON run | hits / run (all) | matches / run | nodes / run | mean match real sec | mean match sim sec | timeouts / run | est. minutes WON run mean (min-max) | est. minutes all runs | final luck (all runs) | rarity weights c/r/e at that luck | final deck size | deck level sum | tokens spent | rest heal / rest forge / treasure per run |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| kiem_si | build | 2.9 | 2 | 39.5 | 27.9 | 6.16 | 9.16 | 124.8 | 80.3 | 0.27 | 29.6 (28.0-31.3) | 16.6 | 8.2 | 65/26/8 | 7.80 | 11.60 | 1.16 | 0.10 / 1.44 / 1.46 |
| phap_su | build | 2.9 | 2 | 42.5 | 24.8 | 6.66 | 9.91 | 114.3 | 70.6 | 0.10 | 28.0 (24.5-31.4) | 16.8 | 8.9 | 65/26/9 | 7.90 | 11.60 | 1.33 | 0.49 / 1.14 / 1.63 |
| sat_thu | build | 2.9 | 2 | 33.5 | 21.5 | 5.77 | 8.59 | 108.0 | 70.1 | 0.04 | 26.0 (25.3-26.6) | 14.0 | 7.6 | 66/26/8 | 7.87 | 11.11 | 1.01 | 0.37 / 1.03 / 1.41 |

**WORLD FLOORS**

| character | floor | alive after % | deaths | deaths % of all deaths | clear % of runs entering | mean HP % entering | mean HP % after boss (before heal) |
|---|---|---|---|---|---|---|---|
| kiem_si | 1 | 81.4 | 13 | 19.1 | 81.4 | 100.0 | 69.4 |
| kiem_si | 2 | 64.3 | 12 | 17.6 | 78.9 | 88.9 | 59.7 |
| kiem_si | 3 | 42.9 | 15 | 22.1 | 66.7 | 80.5 | 52.0 |
| kiem_si | 4 | 21.4 | 15 | 22.1 | 50.0 | 75.7 | 51.4 |
| kiem_si | 5 | 5.7 | 11 | 16.2 | 26.7 | 74.8 | 41.1 |
| kiem_si | final | 2.9 | 2 | 2.9 | 50.0 | 65.3 | 31.4 |
| phap_su | 1 | 95.7 | 3 | 4.4 | 95.7 | 100.0 | 54.9 |
| phap_su | 2 | 77.1 | 13 | 19.1 | 80.6 | 77.2 | 42.9 |
| phap_su | 3 | 44.3 | 23 | 33.8 | 57.4 | 67.2 | 36.6 |
| phap_su | 4 | 18.6 | 18 | 26.5 | 41.9 | 61.5 | 32.5 |
| phap_su | 5 | 4.3 | 10 | 14.7 | 23.1 | 57.5 | 41.9 |
| phap_su | final | 2.9 | 1 | 1.5 | 66.7 | 66.9 | 33.9 |
| sat_thu | 1 | 90.0 | 7 | 10.3 | 90.0 | 100.0 | 55.7 |
| sat_thu | 2 | 67.1 | 16 | 23.5 | 74.6 | 78.7 | 39.6 |
| sat_thu | 3 | 25.7 | 29 | 42.6 | 38.3 | 63.5 | 30.8 |
| sat_thu | 4 | 8.6 | 12 | 17.6 | 33.3 | 55.8 | 33.9 |
| sat_thu | 5 | 4.3 | 3 | 4.4 | 50.0 | 58.9 | 17.2 |
| sat_thu | final | 2.9 | 1 | 1.5 | 66.7 | 42.2 | 8.9 |

**WORLD REGIONS**

| character | floor | region | entered | cleared | clear % |
|---|---|---|---|---|---|
| kiem_si | 1 | ch1 | 21 | 15 | 71.4 |
| kiem_si | 1 | ch2 | 26 | 22 | 84.6 |
| kiem_si | 1 | ch3 | 23 | 20 | 87.0 |
| kiem_si | 2 | ch1 | 15 | 11 | 73.3 |
| kiem_si | 2 | ch2 | 22 | 18 | 81.8 |
| kiem_si | 2 | ch3 | 20 | 16 | 80.0 |
| kiem_si | 3 | ch1 | 14 | 7 | 50.0 |
| kiem_si | 3 | ch2 | 10 | 9 | 90.0 |
| kiem_si | 3 | ch3 | 21 | 14 | 66.7 |
| kiem_si | 4 | ch1 | 9 | 0 | 0.0 |
| kiem_si | 4 | ch2 | 12 | 9 | 75.0 |
| kiem_si | 4 | ch3 | 9 | 6 | 66.7 |
| kiem_si | 5 | ch1 | 8 | 1 | 12.5 |
| kiem_si | 5 | ch2 | 3 | 0 | 0.0 |
| kiem_si | 5 | ch3 | 4 | 3 | 75.0 |
| phap_su | 1 | ch1 | 21 | 18 | 85.7 |
| phap_su | 1 | ch2 | 26 | 26 | 100.0 |
| phap_su | 1 | ch3 | 23 | 23 | 100.0 |
| phap_su | 2 | ch1 | 19 | 12 | 63.2 |
| phap_su | 2 | ch2 | 24 | 21 | 87.5 |
| phap_su | 2 | ch3 | 24 | 21 | 87.5 |
| phap_su | 3 | ch1 | 17 | 2 | 11.8 |
| phap_su | 3 | ch2 | 16 | 14 | 87.5 |
| phap_su | 3 | ch3 | 21 | 15 | 71.4 |
| phap_su | 4 | ch1 | 15 | 3 | 20.0 |
| phap_su | 4 | ch2 | 8 | 4 | 50.0 |
| phap_su | 4 | ch3 | 8 | 6 | 75.0 |
| phap_su | 5 | ch1 | 7 | 0 | 0.0 |
| phap_su | 5 | ch2 | 5 | 2 | 40.0 |
| phap_su | 5 | ch3 | 1 | 1 | 100.0 |
| sat_thu | 1 | ch1 | 21 | 16 | 76.2 |
| sat_thu | 1 | ch2 | 26 | 25 | 96.2 |
| sat_thu | 1 | ch3 | 23 | 22 | 95.7 |
| sat_thu | 2 | ch1 | 19 | 13 | 68.4 |
| sat_thu | 2 | ch2 | 22 | 17 | 77.3 |
| sat_thu | 2 | ch3 | 22 | 17 | 77.3 |
| sat_thu | 3 | ch1 | 16 | 4 | 25.0 |
| sat_thu | 3 | ch2 | 11 | 7 | 63.6 |
| sat_thu | 3 | ch3 | 20 | 7 | 35.0 |
| sat_thu | 4 | ch1 | 5 | 0 | 0.0 |
| sat_thu | 4 | ch2 | 5 | 3 | 60.0 |
| sat_thu | 4 | ch3 | 8 | 3 | 37.5 |
| sat_thu | 5 | ch1 | 3 | 1 | 33.3 |
| sat_thu | 5 | ch2 | 2 | 2 | 100.0 |
| sat_thu | 5 | ch3 | 1 | 0 | 0.0 |

```text
WORLD DEATHS BY FLOOR/KIND kiem_si: f1/boss=13, f2/boss=12, f3/battle=4, f3/boss=11, f4/battle=1, f4/boss=14, f5/battle=2, f5/boss=9, ffinal/final=2
WORLD VERDICT kiem_si/build: run win 2.9% (target 20-40) TOO HARD; est. minutes won run 29.6 (target 40-50) TOO SHORT; max region spread at a floor 75.0 pts (target <= 15, n >= 5) FAIL; max floor share of deaths 22.1% (target <= 40) PASS; survival strictly decreasing PASS; boss hits / won run 39.5
runtime: 193.8 s
WORLD DEATHS BY FLOOR/KIND phap_su: f1/boss=3, f2/boss=13, f3/battle=4, f3/boss=19, f4/battle=2, f4/boss=16, f5/battle=1, f5/boss=9, ffinal/final=1
WORLD VERDICT phap_su/build: run win 2.9% (target 10-100) TOO HARD; est. minutes won run 28.0 (target 40-50) TOO SHORT; max region spread at a floor 75.7 pts (target <= 15, n >= 5) FAIL; max floor share of deaths 33.8% (target <= 40) PASS; survival strictly decreasing PASS; boss hits / won run 42.5
runtime: 194.1 s
WORLD DEATHS BY FLOOR/KIND sat_thu: f1/boss=7, f2/boss=16, f3/battle=6, f3/boss=23, f4/battle=1, f4/boss=11, f5/boss=3, ffinal/final=1
WORLD VERDICT sat_thu/build: run win 2.9% (target 20-40) TOO HARD; est. minutes won run 26.0 (target 40-50) TOO SHORT; max region spread at a floor 60.0 pts (target <= 15, n >= 5) FAIL; max floor share of deaths 42.6% (target <= 40) FAIL; survival strictly decreasing PASS; boss hits / won run 33.5
runtime: 165.6 s
```

### Proposal 1 (difficulty + region parity + heal)

```text
deck_sim --world (Story 031): seeds=70 timeout=180s policies=["build"] characters=["kiem_si"] cleared_bosses=1 region-pick=random node-overhead=25s (ASSUMPTION: node pick + reward + reading, per node) world-set=norm.ch1.hp_mult:0.75,norm.ch1.step_mult:1.05,scale.2.hp_mult:1.1,scale.3.hp_mult:1.2,scale.4.hp_mult:1.3,scale.4.size_add:0,scale.5.hp_mult:1.4,scale.final.hp_mult:1.5,heal:0.35
bot: dodge=0.85 (TD-006 legacy default, not re-anchored) gap=0.60-1.60s aim=0.90 counter=0.50 place=1.20s join=1.00/1.00s hold=1 choose=0.80s aware=0.00 sig=rules dt=0.050 | overrides: none
world: floors=5 choices=2 pool=["ch1", "ch2", "ch3"] columns=3 heal=0.35 final={ "region": "ch3", "match_id": "mist_lord" } tiers={ "1": [0, 1, 1], "2": [0, 1, 1], "3": [1, 2, 2], "4": [1, 2, 2], "5": [1, 2, 2] }
  floor_scaling 1: { "hp_mult": 1.0, "step_mult": 1.0, "defense_add": 0.0, "size_add": 0 }
  floor_scaling 2: { "hp_mult": 1.1, "step_mult": 0.95, "defense_add": 0.0, "size_add": 0 }
  floor_scaling 3: { "hp_mult": 1.2, "step_mult": 0.9, "defense_add": 1.0, "size_add": 0 }
  floor_scaling 4: { "hp_mult": 1.3, "step_mult": 0.85, "defense_add": 1.0, "size_add": 0 }
  floor_scaling 5: { "hp_mult": 1.4, "step_mult": 0.8, "defense_add": 2.0, "size_add": 1 }
  floor_scaling final: { "hp_mult": 1.5, "step_mult": 0.8, "defense_add": 2.0, "size_add": 1 }
  region_normalize ch1: { "hp_mult": 0.75, "step_mult": 1.05, "defense_add": 0.0 }
  region_normalize ch2: { "hp_mult": 0.85, "step_mult": 1.05, "defense_add": 0.0 }
  region_normalize ch3: { "hp_mult": 0.75, "step_mult": 1.1, "defense_add": -1.0 }
node policy: rest when HP < 50%, else treasure > rest (heal < 50% else forge) > miniboss at >= 70% HP > battle > danger; boss when alone. Region boss: boss reward + token + floor heal. Run time = (sum of match REAL seconds + overhead x nodes) / 60.
deck_sim --world (Story 031): seeds=70 timeout=180s policies=["build"] characters=["phap_su"] cleared_bosses=1 region-pick=random node-overhead=25s (ASSUMPTION: node pick + reward + reading, per node) world-set=norm.ch1.hp_mult:0.75,norm.ch1.step_mult:1.05,scale.2.hp_mult:1.1,scale.3.hp_mult:1.2,scale.4.hp_mult:1.3,scale.4.size_add:0,scale.5.hp_mult:1.4,scale.final.hp_mult:1.5,heal:0.35
deck_sim --world (Story 031): seeds=70 timeout=180s policies=["build"] characters=["sat_thu"] cleared_bosses=1 region-pick=random node-overhead=25s (ASSUMPTION: node pick + reward + reading, per node) world-set=norm.ch1.hp_mult:0.75,norm.ch1.step_mult:1.05,scale.2.hp_mult:1.1,scale.3.hp_mult:1.2,scale.4.hp_mult:1.3,scale.4.size_add:0,scale.5.hp_mult:1.4,scale.final.hp_mult:1.5,heal:0.35
```

**WORLD SUMMARY**

| character | policy | run win % | wins | boss hits / WON run | hits / run (all) | matches / run | nodes / run | mean match real sec | mean match sim sec | timeouts / run | est. minutes WON run mean (min-max) | est. minutes all runs | final luck (all runs) | rarity weights c/r/e at that luck | final deck size | deck level sum | tokens spent | rest heal / rest forge / treasure per run |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| kiem_si | build | 30.0 | 21 | 41.4 | 32.9 | 7.80 | 11.50 | 116.2 | 74.8 | 0.20 | 27.7 (24.0-33.5) | 19.9 | 10.8 | 64/27/9 | 7.90 | 12.59 | 1.94 | 0.07 / 1.76 / 1.87 |
| phap_su | build | 18.6 | 13 | 34.3 | 29.4 | 7.93 | 11.73 | 108.3 | 67.2 | 0.07 | 25.1 (20.9-29.5) | 19.2 | 10.9 | 64/27/10 | 7.87 | 12.39 | 1.93 | 0.39 / 1.53 / 1.89 |
| sat_thu | build | 5.7 | 4 | 29.8 | 24.9 | 6.81 | 10.14 | 103.9 | 67.6 | 0.10 | 24.2 (23.2-25.5) | 16.0 | 9.2 | 65/26/9 | 7.94 | 11.76 | 1.46 | 0.36 / 1.33 / 1.64 |

**WORLD FLOORS**

| character | floor | alive after % | deaths | deaths % of all deaths | clear % of runs entering | mean HP % entering | mean HP % after boss (before heal) |
|---|---|---|---|---|---|---|---|
| kiem_si | 1 | 88.6 | 8 | 16.3 | 88.6 | 100.0 | 70.9 |
| kiem_si | 2 | 80.0 | 6 | 12.2 | 90.3 | 93.8 | 67.4 |
| kiem_si | 3 | 61.4 | 13 | 26.5 | 76.8 | 91.4 | 60.6 |
| kiem_si | 4 | 45.7 | 11 | 22.4 | 74.4 | 88.3 | 61.0 |
| kiem_si | 5 | 34.3 | 8 | 16.3 | 75.0 | 89.0 | 49.5 |
| kiem_si | final | 30.0 | 3 | 6.1 | 87.5 | 79.2 | 57.1 |
| phap_su | 1 | 94.3 | 4 | 7.0 | 94.3 | 100.0 | 60.4 |
| phap_su | 2 | 80.0 | 10 | 17.5 | 84.8 | 88.2 | 55.5 |
| phap_su | 3 | 67.1 | 9 | 15.8 | 83.9 | 86.1 | 41.6 |
| phap_su | 4 | 44.3 | 16 | 28.1 | 66.0 | 74.4 | 35.3 |
| phap_su | 5 | 27.1 | 12 | 21.1 | 61.3 | 69.3 | 31.2 |
| phap_su | final | 18.6 | 6 | 10.5 | 68.4 | 66.1 | 40.7 |
| sat_thu | 1 | 91.4 | 6 | 9.1 | 91.4 | 100.0 | 57.6 |
| sat_thu | 2 | 74.3 | 12 | 18.2 | 81.3 | 86.8 | 50.3 |
| sat_thu | 3 | 44.3 | 21 | 31.8 | 59.6 | 80.7 | 41.5 |
| sat_thu | 4 | 27.1 | 12 | 18.2 | 61.3 | 76.2 | 41.5 |
| sat_thu | 5 | 11.4 | 11 | 16.7 | 42.1 | 75.0 | 35.4 |
| sat_thu | final | 5.7 | 4 | 6.1 | 50.0 | 65.1 | 45.0 |

**WORLD REGIONS**

| character | floor | region | entered | cleared | clear % |
|---|---|---|---|---|---|
| kiem_si | 1 | ch1 | 21 | 20 | 95.2 |
| kiem_si | 1 | ch2 | 26 | 22 | 84.6 |
| kiem_si | 1 | ch3 | 23 | 20 | 87.0 |
| kiem_si | 2 | ch1 | 15 | 12 | 80.0 |
| kiem_si | 2 | ch2 | 24 | 23 | 95.8 |
| kiem_si | 2 | ch3 | 23 | 21 | 91.3 |
| kiem_si | 3 | ch1 | 20 | 15 | 75.0 |
| kiem_si | 3 | ch2 | 15 | 13 | 86.7 |
| kiem_si | 3 | ch3 | 21 | 15 | 71.4 |
| kiem_si | 4 | ch1 | 9 | 6 | 66.7 |
| kiem_si | 4 | ch2 | 15 | 14 | 93.3 |
| kiem_si | 4 | ch3 | 19 | 12 | 63.2 |
| kiem_si | 5 | ch1 | 15 | 11 | 73.3 |
| kiem_si | 5 | ch2 | 7 | 5 | 71.4 |
| kiem_si | 5 | ch3 | 10 | 8 | 80.0 |
| phap_su | 1 | ch1 | 21 | 17 | 81.0 |
| phap_su | 1 | ch2 | 26 | 26 | 100.0 |
| phap_su | 1 | ch3 | 23 | 23 | 100.0 |
| phap_su | 2 | ch1 | 19 | 13 | 68.4 |
| phap_su | 2 | ch2 | 24 | 22 | 91.7 |
| phap_su | 2 | ch3 | 23 | 21 | 91.3 |
| phap_su | 3 | ch1 | 19 | 14 | 73.7 |
| phap_su | 3 | ch2 | 15 | 14 | 93.3 |
| phap_su | 3 | ch3 | 22 | 19 | 86.4 |
| phap_su | 4 | ch1 | 15 | 8 | 53.3 |
| phap_su | 4 | ch2 | 15 | 12 | 80.0 |
| phap_su | 4 | ch3 | 17 | 11 | 64.7 |
| phap_su | 5 | ch1 | 16 | 7 | 43.8 |
| phap_su | 5 | ch2 | 9 | 6 | 66.7 |
| phap_su | 5 | ch3 | 6 | 6 | 100.0 |
| sat_thu | 1 | ch1 | 21 | 17 | 81.0 |
| sat_thu | 1 | ch2 | 26 | 25 | 96.2 |
| sat_thu | 1 | ch3 | 23 | 22 | 95.7 |
| sat_thu | 2 | ch1 | 19 | 17 | 89.5 |
| sat_thu | 2 | ch2 | 23 | 19 | 82.6 |
| sat_thu | 2 | ch3 | 22 | 16 | 72.7 |
| sat_thu | 3 | ch1 | 17 | 8 | 47.1 |
| sat_thu | 3 | ch2 | 13 | 12 | 92.3 |
| sat_thu | 3 | ch3 | 22 | 11 | 50.0 |
| sat_thu | 4 | ch1 | 8 | 4 | 50.0 |
| sat_thu | 4 | ch2 | 9 | 6 | 66.7 |
| sat_thu | 4 | ch3 | 14 | 9 | 64.3 |
| sat_thu | 5 | ch1 | 5 | 1 | 20.0 |
| sat_thu | 5 | ch2 | 8 | 3 | 37.5 |
| sat_thu | 5 | ch3 | 6 | 4 | 66.7 |

```text
WORLD DEATHS BY FLOOR/KIND kiem_si: f1/boss=8, f2/boss=6, f3/battle=2, f3/boss=11, f4/battle=1, f4/boss=10, f5/battle=1, f5/boss=7, ffinal/final=3
WORLD VERDICT kiem_si/build: run win 30.0% (target 20-40) PASS; est. minutes won run 27.7 (target 40-50) TOO SHORT; max region spread at a floor 30.2 pts (target <= 15, n >= 5) FAIL; max floor share of deaths 26.5% (target <= 40) PASS; survival strictly decreasing PASS; boss hits / won run 41.4
runtime: 256.9 s
WORLD DEATHS BY FLOOR/KIND phap_su: f1/boss=4, f2/boss=10, f3/boss=9, f4/battle=3, f4/boss=13, f5/battle=1, f5/boss=11, ffinal/final=6
WORLD VERDICT phap_su/build: run win 18.6% (target 10-100) PASS; est. minutes won run 25.1 (target 40-50) TOO SHORT; max region spread at a floor 56.3 pts (target <= 15, n >= 5) FAIL; max floor share of deaths 28.1% (target <= 40) PASS; survival strictly decreasing PASS; boss hits / won run 34.3
runtime: 245.5 s
WORLD DEATHS BY FLOOR/KIND sat_thu: f1/boss=6, f2/boss=12, f3/battle=1, f3/boss=20, f4/battle=1, f4/boss=11, f5/battle=1, f5/boss=10, ffinal/final=4
WORLD VERDICT sat_thu/build: run win 5.7% (target 20-40) TOO HARD; est. minutes won run 24.2 (target 40-50) TOO SHORT; max region spread at a floor 46.7 pts (target <= 15, n >= 5) FAIL; max floor share of deaths 31.8% (target <= 40) PASS; survival strictly decreasing PASS; boss hits / won run 29.8
runtime: 210.2 s
```

### Proposal 2 (Proposal 1 + one extra battle column)

```text
deck_sim --world (Story 031): seeds=70 timeout=180s policies=["build"] characters=["kiem_si"] cleared_bosses=1 region-pick=random node-overhead=25s (ASSUMPTION: node pick + reward + reading, per node) world-set=norm.ch1.hp_mult:0.75,norm.ch1.step_mult:1.05,scale.2.hp_mult:1.1,scale.3.hp_mult:1.2,scale.4.hp_mult:1.3,scale.4.size_add:0,scale.5.hp_mult:1.4,scale.final.hp_mult:1.5,heal:0.35,battle_columns:1
bot: dodge=0.85 (TD-006 legacy default, not re-anchored) gap=0.60-1.60s aim=0.90 counter=0.50 place=1.20s join=1.00/1.00s hold=1 choose=0.80s aware=0.00 sig=rules dt=0.050 | overrides: none
world: floors=5 choices=2 pool=["ch1", "ch2", "ch3"] columns=4 heal=0.35 final={ "region": "ch3", "match_id": "mist_lord" } tiers={ "1": [0, 1, 1], "2": [0, 1, 1], "3": [1, 2, 2], "4": [1, 2, 2], "5": [1, 2, 2] }
  floor_scaling 1: { "hp_mult": 1.0, "step_mult": 1.0, "defense_add": 0.0, "size_add": 0 }
  floor_scaling 2: { "hp_mult": 1.1, "step_mult": 0.95, "defense_add": 0.0, "size_add": 0 }
  floor_scaling 3: { "hp_mult": 1.2, "step_mult": 0.9, "defense_add": 1.0, "size_add": 0 }
  floor_scaling 4: { "hp_mult": 1.3, "step_mult": 0.85, "defense_add": 1.0, "size_add": 0 }
  floor_scaling 5: { "hp_mult": 1.4, "step_mult": 0.8, "defense_add": 2.0, "size_add": 1 }
  floor_scaling final: { "hp_mult": 1.5, "step_mult": 0.8, "defense_add": 2.0, "size_add": 1 }
  region_normalize ch1: { "hp_mult": 0.75, "step_mult": 1.05, "defense_add": 0.0 }
  region_normalize ch2: { "hp_mult": 0.85, "step_mult": 1.05, "defense_add": 0.0 }
  region_normalize ch3: { "hp_mult": 0.75, "step_mult": 1.1, "defense_add": -1.0 }
node policy: rest when HP < 50%, else treasure > rest (heal < 50% else forge) > miniboss at >= 70% HP > battle > danger; boss when alone. Region boss: boss reward + token + floor heal. Run time = (sum of match REAL seconds + overhead x nodes) / 60.
deck_sim --world (Story 031): seeds=70 timeout=180s policies=["build"] characters=["phap_su"] cleared_bosses=1 region-pick=random node-overhead=25s (ASSUMPTION: node pick + reward + reading, per node) world-set=norm.ch1.hp_mult:0.75,norm.ch1.step_mult:1.05,scale.2.hp_mult:1.1,scale.3.hp_mult:1.2,scale.4.hp_mult:1.3,scale.4.size_add:0,scale.5.hp_mult:1.4,scale.final.hp_mult:1.5,heal:0.35,battle_columns:1
deck_sim --world (Story 031): seeds=70 timeout=180s policies=["build"] characters=["sat_thu"] cleared_bosses=1 region-pick=random node-overhead=25s (ASSUMPTION: node pick + reward + reading, per node) world-set=norm.ch1.hp_mult:0.75,norm.ch1.step_mult:1.05,scale.2.hp_mult:1.1,scale.3.hp_mult:1.2,scale.4.hp_mult:1.3,scale.4.size_add:0,scale.5.hp_mult:1.4,scale.final.hp_mult:1.5,heal:0.35,battle_columns:1
```

**WORLD SUMMARY**

| character | policy | run win % | wins | boss hits / WON run | hits / run (all) | matches / run | nodes / run | mean match real sec | mean match sim sec | timeouts / run | est. minutes WON run mean (min-max) | est. minutes all runs | final luck (all runs) | rarity weights c/r/e at that luck | final deck size | deck level sum | tokens spent | rest heal / rest forge / treasure per run |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| kiem_si | build | 11.4 | 8 | 54.4 | 37.6 | 10.01 | 13.16 | 105.1 | 67.2 | 0.14 | 35.7 (33.4-37.5) | 23.0 | 12.3 | 63/27/10 | 7.84 | 12.69 | 2.53 | 0.19 / 1.54 / 1.41 |
| phap_su | build | 5.7 | 4 | 39.0 | 26.5 | 9.01 | 11.86 | 95.3 | 58.7 | 0.04 | 30.3 (26.7-32.0) | 19.3 | 10.9 | 64/27/10 | 7.84 | 11.89 | 2.11 | 0.53 / 1.00 / 1.31 |
| sat_thu | build | 0.0 | 0 | - | 22.6 | 7.51 | 9.90 | 91.9 | 59.2 | 0.01 | - | 15.6 | 8.9 | 65/26/9 | 7.87 | 11.26 | 1.49 | 0.40 / 0.81 / 1.17 |

**WORLD FLOORS**

| character | floor | alive after % | deaths | deaths % of all deaths | clear % of runs entering | mean HP % entering | mean HP % after boss (before heal) |
|---|---|---|---|---|---|---|---|
| kiem_si | 1 | 87.1 | 9 | 14.5 | 87.1 | 100.0 | 65.5 |
| kiem_si | 2 | 71.4 | 11 | 17.7 | 82.0 | 91.2 | 63.7 |
| kiem_si | 3 | 48.6 | 16 | 25.8 | 68.0 | 90.1 | 52.5 |
| kiem_si | 4 | 30.0 | 13 | 21.0 | 61.8 | 83.2 | 51.5 |
| kiem_si | 5 | 12.9 | 12 | 19.4 | 42.9 | 82.7 | 40.9 |
| kiem_si | final | 11.4 | 1 | 1.6 | 88.9 | 75.9 | 49.5 |
| phap_su | 1 | 88.6 | 8 | 12.1 | 88.6 | 100.0 | 47.2 |
| phap_su | 2 | 65.7 | 16 | 24.2 | 74.2 | 79.4 | 41.7 |
| phap_su | 3 | 35.7 | 21 | 31.8 | 54.3 | 75.4 | 36.9 |
| phap_su | 4 | 17.1 | 13 | 19.7 | 48.0 | 70.0 | 26.3 |
| phap_su | 5 | 5.7 | 8 | 12.1 | 33.3 | 58.6 | 21.3 |
| phap_su | final | 5.7 | 0 | 0.0 | 100.0 | 56.3 | 25.0 |
| sat_thu | 1 | 80.0 | 14 | 20.0 | 80.0 | 100.0 | 49.3 |
| sat_thu | 2 | 51.4 | 20 | 28.6 | 64.3 | 80.7 | 34.1 |
| sat_thu | 3 | 18.6 | 23 | 32.9 | 36.1 | 68.4 | 20.1 |
| sat_thu | 4 | 7.1 | 8 | 11.4 | 38.5 | 55.1 | 9.7 |
| sat_thu | 5 | 1.4 | 4 | 5.7 | 20.0 | 44.7 | 6.7 |
| sat_thu | final | 0.0 | 1 | 1.4 | 0.0 | 41.7 | 0.0 |

**WORLD REGIONS**

| character | floor | region | entered | cleared | clear % |
|---|---|---|---|---|---|
| kiem_si | 1 | ch1 | 21 | 16 | 76.2 |
| kiem_si | 1 | ch2 | 26 | 25 | 96.2 |
| kiem_si | 1 | ch3 | 23 | 20 | 87.0 |
| kiem_si | 2 | ch1 | 17 | 14 | 82.4 |
| kiem_si | 2 | ch2 | 22 | 19 | 86.4 |
| kiem_si | 2 | ch3 | 22 | 17 | 77.3 |
| kiem_si | 3 | ch1 | 18 | 14 | 77.8 |
| kiem_si | 3 | ch2 | 11 | 7 | 63.6 |
| kiem_si | 3 | ch3 | 21 | 13 | 61.9 |
| kiem_si | 4 | ch1 | 7 | 2 | 28.6 |
| kiem_si | 4 | ch2 | 13 | 9 | 69.2 |
| kiem_si | 4 | ch3 | 14 | 10 | 71.4 |
| kiem_si | 5 | ch1 | 9 | 4 | 44.4 |
| kiem_si | 5 | ch2 | 7 | 3 | 42.9 |
| kiem_si | 5 | ch3 | 5 | 2 | 40.0 |
| phap_su | 1 | ch1 | 21 | 17 | 81.0 |
| phap_su | 1 | ch2 | 26 | 23 | 88.5 |
| phap_su | 1 | ch3 | 23 | 22 | 95.7 |
| phap_su | 2 | ch1 | 18 | 10 | 55.6 |
| phap_su | 2 | ch2 | 22 | 20 | 90.9 |
| phap_su | 2 | ch3 | 22 | 16 | 72.7 |
| phap_su | 3 | ch1 | 16 | 5 | 31.3 |
| phap_su | 3 | ch2 | 12 | 9 | 75.0 |
| phap_su | 3 | ch3 | 18 | 11 | 61.1 |
| phap_su | 4 | ch1 | 9 | 2 | 22.2 |
| phap_su | 4 | ch2 | 7 | 5 | 71.4 |
| phap_su | 4 | ch3 | 9 | 5 | 55.6 |
| phap_su | 5 | ch1 | 5 | 0 | 0.0 |
| phap_su | 5 | ch2 | 3 | 1 | 33.3 |
| phap_su | 5 | ch3 | 4 | 3 | 75.0 |
| sat_thu | 1 | ch1 | 21 | 14 | 66.7 |
| sat_thu | 1 | ch2 | 26 | 24 | 92.3 |
| sat_thu | 1 | ch3 | 23 | 18 | 78.3 |
| sat_thu | 2 | ch1 | 19 | 11 | 57.9 |
| sat_thu | 2 | ch2 | 17 | 13 | 76.5 |
| sat_thu | 2 | ch3 | 20 | 12 | 60.0 |
| sat_thu | 3 | ch1 | 12 | 5 | 41.7 |
| sat_thu | 3 | ch2 | 11 | 4 | 36.4 |
| sat_thu | 3 | ch3 | 13 | 4 | 30.8 |
| sat_thu | 4 | ch1 | 1 | 0 | 0.0 |
| sat_thu | 4 | ch2 | 5 | 2 | 40.0 |
| sat_thu | 4 | ch3 | 7 | 3 | 42.9 |
| sat_thu | 5 | ch1 | 4 | 1 | 25.0 |
| sat_thu | 5 | ch2 | 1 | 0 | 0.0 |

```text
WORLD DEATHS BY FLOOR/KIND kiem_si: f1/boss=9, f2/battle=1, f2/boss=10, f3/battle=6, f3/boss=10, f4/battle=4, f4/boss=9, f5/battle=5, f5/boss=7, ffinal/final=1
WORLD VERDICT kiem_si/build: run win 11.4% (target 20-40) TOO HARD; est. minutes won run 35.7 (target 40-50) TOO SHORT; max region spread at a floor 42.9 pts (target <= 15, n >= 5) FAIL; max floor share of deaths 25.8% (target <= 40) PASS; survival strictly decreasing PASS; boss hits / won run 54.4
runtime: 282.0 s
WORLD DEATHS BY FLOOR/KIND phap_su: f1/boss=8, f2/battle=2, f2/boss=14, f3/battle=7, f3/boss=14, f4/battle=3, f4/boss=10, f5/battle=4, f5/boss=4
WORLD VERDICT phap_su/build: run win 5.7% (target 10-100) TOO HARD; est. minutes won run 30.3 (target 40-50) TOO SHORT; max region spread at a floor 49.2 pts (target <= 15, n >= 5) FAIL; max floor share of deaths 31.8% (target <= 40) PASS; survival strictly decreasing FAIL (a floor with no deaths); boss hits / won run 39.0
runtime: 237.2 s
WORLD DEATHS BY FLOOR/KIND sat_thu: f1/boss=14, f2/battle=2, f2/boss=18, f3/battle=7, f3/boss=16, f4/battle=3, f4/boss=5, f5/battle=1, f5/boss=3, ffinal/final=1
WORLD VERDICT sat_thu/build: run win 0.0% (target 20-40) TOO HARD; est. minutes won run - (target 40-50) NO WINS; max region spread at a floor 25.6 pts (target <= 15, n >= 5) FAIL; max floor share of deaths 32.9% (target <= 40) PASS; survival strictly decreasing PASS; boss hits / won run -
runtime: 196.6 s
```

