# World Map v2 — Heat Decay Experiment D (2026-11-12)

User brief: "World Map v2 — Heat Decay Experiment D". Hellfire slice only. **Experiment, not a production change**:
`assets/data/region_rules.json` still carries rest −2 (variant C configuration). Nothing committed, pushed or deployed.

| | C (production, approved) | D (experiment) |
|---|---|---|
| Rest heat decay | **−2** | **−1** |
| Shop heat decay | −1 | −1 (unchanged) |
| Peril modifier slots | [0, 1, 1] | [0, 1, 1] (unchanged) |
| Warden hook | `vent_surge` at actual heat ≥ 3 on warden entry | unchanged |
| Heat combat rows, reward tiers, archetype weights, other regions, save format | unchanged | unchanged |

Variant file: `production/qa/evidence/world-map-v2/variants/region_rules_D.json` (a copy of the shipped
`region_rules.json` with `rules.heat.gauge.per_kind.rest` = −1 and nothing else changed).

## 0. Summary

**Verdict: inconclusive on one criterion → retain C in production; D is the better design on everything the
simulator can see and is recommended for adoption after one human playtest of the warden at heat 3–4.**

| Criterion (brief) | C | D | D status |
|---|---|---|---|
| Peril NV ≥ Safe NV + 25 % | 194.0 vs 119.8 (**+62 %**) | 194.2 vs 123.7 (**+57 %**) | **met** |
| Peril death gap vs Safe ≤ +10 pts | 89.6 − 80.8 = **+8.8** | 91.7 − 80.6 = **+11.1** | **not met nominally** (§4.2: Peril is unchanged, the Safe side moved +2.1 pts and D has no mechanism for that) |
| Run-level guard (mean run win within ±10 pts of C) | 13.4 / 13.1 (two seed sets) | 14.8 / 17.1 | **met** (+2.7 pts pooled) |
| Warden heat 3–4 / hook activation rises meaningfully | peril 30.2 %, elite 26.1 % | peril **44.7 %**, elite **54.9 %** | **met** (+14.5 / +28.8 pts) |
| Other lanes not unintentionally easier / harder | — | clear −0.9 … +2.1 pts, HP lost in fights ±1.0 | **met** (within seed noise) |

What D does, measured: a Rest on the Peril lane now drops heat 2.74 → 1.74 instead of 2.74 → 0.74 (Shop unchanged
2.64 → 1.64), so Rest still cools the player but no longer erases the heat; 45 % of Peril routes and 55 % of Elite
routes reach the warden at heat 3–4 (C: 30 % / 26 %) and the `vent_surge` hook fires on exactly those. The design
intent of ≥ 60 % on Peril is still not reached under D — the hub Shop (−1) and the prepare Rest (−1) still sit between
the last lane fight and the warden.

What the simulator cannot see (§7): the bot leaves warned vent cells before they erupt, so `vent_surge` on the warden
costs it nothing. D makes the warden hook fire 1.5–2× as often, and that is exactly the cost the sim does not measure.
The clear-rate numbers above therefore say "D does not hurt the lanes before the warden", not "the warden at D is fine".

## 1. Commands, seeds, raw output

Script: `production/qa/evidence/world-map-v2/heat-decay/run-heat-decay.sh` (110 jobs, 8 in parallel, 44 min;
log `run-heat-decay.log`, all 110 `exit=0`). Aggregation: `heat-decay/aggregate-heat.py` (read-only, prints Markdown;
its full output is saved as `heat-decay/aggregate-heat.md`).

Common flags (identical to `balance-validation-2026-11-12.md`):

```
godot --headless --path . -s res://tools/balance/deck_sim.gd -- --run=v6 --region-pick=order --seeds=70
  --policies=build --shop-policy=greedy --event-policy=risky --relic-policy=pick --tables=v6
  --seed-offset=<2001|3001> --characters=<kiem_si|phap_su|sat_thu|tho_san|giao_si>
```

| Job family | Extra flags | Files | Count |
|---|---|---|---|
| Lane probes C | `--floors=2..2 --final=off --route-policy=<lane>` | `heat-decay/C-s<set>-probe-<lane>-<char>.txt` | 50 |
| Lane probes D | same + `--region-rules=res://production/qa/evidence/world-map-v2/variants/region_rules_D.json` | `heat-decay/D-s<set>-probe-<lane>-<char>.txt` | 50 |
| Full runs D | `--final=on --route-policy=value` + the `--region-rules=` flag | `heat-decay/D-s<set>-full-value-<char>.txt` | 10 |
| Full runs C (paired, from the balance pass) | `--final=on --route-policy=value` | `balance/C-full-value-<char>.txt` (set 2001), `balance/rep-C-full-value-<char>.txt` (set 3001) | 10 |

Seeds: set 2001 = seeds 2002..2071, set 3001 = seeds 3002..3071 (70 per character per job; the same seeds for C and D,
so every C/D pair starts from the same map, deck and bot state). Per lane and variant: 5 characters × 2 sets ×
up to 70 routes = 345–485 lane visits (a visit exists only when the generator offers that lane; the counts are identical
for C and D because the map is seeded before the heat rule applies). Raw output preserved; nothing from the balance
pass was overwritten.

Each raw file ends with one Godot `ObjectDB instances leaked at exit` note (`at: cleanup (core/object/object.cpp)`) —
the same line the balance-pass files carry; not a simulator error. No `SCRIPT ERROR`, no `unknown match` in any file.

Instrumentation added for this experiment (tool code only, `tools/balance/deck_sim.gd`): the `ROUTE3` row — rests and
shops on the route with the mean heat before → after each, warden reached, hook fired % — and the `route_hook` field
(`RegionRules.warden_hook` evaluated at the heat the warden fight began, i.e. the hook semantics of the game, not the
max historical heat). Parse-checked; the balance-pass rows are unchanged.

## 2. Pooled lane probes (lane == policy, both seed sets, weighted by visits)

| variant / lane | visits | clear % | gold | HP net | relics | obj / visit | NV | heat at warden (mean) | heat 3–4 at warden % | hook fired % | rests / route | heat before → after rest | shops / route | heat before → after shop | HP lost in fights | HP healed outside |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| C / safe | 460 | 89.6 | 88.9 | 37.5 | 1.51 | 0.00 | 119.8 | 1.28 | 21.6 | 21.6 | 1.46 | 1.96 → 0.53 | 0.53 | 2.88 → 1.88 | 51.1 | 8.6 |
| D / safe | 460 | 91.7 | 92.9 | 37.4 | 1.51 | 0.00 | 123.7 | 1.92 | 38.8 | 38.8 | 1.46 | 2.18 → 1.28 | 0.53 | 2.88 → 1.88 | 49.9 | 8.6 |
| C / treasure | 435 | 93.3 | 84.1 | 36.0 | 1.76 | 0.00 | 131.9 | 0.76 | 10.3 | 10.3 | 1.00 | 1.87 → 0.13 | 0.54 | 2.00 → 1.00 | 46.2 | 6.8 |
| D / treasure | 435 | 92.4 | 85.4 | 34.9 | 1.76 | 0.00 | 135.0 | 1.49 | 26.4 | 26.5 | 1.00 | 1.87 → 0.87 | 0.54 | 2.00 → 1.00 | 46.0 | 6.9 |
| C / peril | 485 | 80.8 | 120.4 | 43.6 | 2.39 | 0.22 | 194.0 | 1.61 | 30.2 | 30.2 | 0.93 | 2.74 → 0.74 | 0.49 | 2.64 → 1.64 | 68.5 | 15.4 |
| D / peril | 485 | 80.6 | 121.2 | 44.0 | 2.39 | 0.22 | 194.2 | 2.46 | 44.7 | 44.7 | 0.93 | 2.74 → 1.74 | 0.49 | 2.64 → 1.64 | 68.7 | 15.3 |
| C / elite | 375 | 88.8 | 100.8 | 40.2 | 1.93 | 0.00 | 152.1 | 1.63 | 26.1 | 26.1 | 0.98 | 2.91 → 0.91 | 0.51 | 2.86 → 1.86 | 56.7 | 11.0 |
| D / elite | 375 | 89.9 | 104.8 | 40.1 | 2.00 | 0.00 | 160.8 | 2.53 | 54.9 | 54.9 | 0.98 | 2.91 → 1.91 | 0.51 | 2.86 → 1.86 | 55.7 | 11.1 |
| C / mystery | 345 | 94.5 | 79.4 | 32.3 | 2.15 | 0.00 | 157.0 | 0.78 | 5.5 | 5.5 | 1.00 | 1.07 → 0.08 | 0.58 | 1.54 → 0.54 | 34.8 | 4.5 |
| D / mystery | 345 | 95.4 | 81.7 | 32.4 | 2.15 | 0.00 | 159.1 | 1.10 | 20.1 | 20.0 | 1.00 | 1.07 → 0.41 | 0.58 | 1.54 → 0.54 | 34.7 | 4.6 |

Definitions: clear % = routes that beat the warden; gold = drops on the route; HP net = HP % lost over the route net of
healing; NV = gold + 60 × relics − 1.6 × HP net (the balance-pass formula); "heat 3–4 at warden" and "hook fired" are
over routes that reached the warden; HP lost in fights / healed outside are per ended route. Rest and Shop heat columns
are means over the rests / shops that happened on the route (Shop = the hub shop, Rest = the prepare rest before the
warden; Safe routes carry one extra rest).

### 2.1 Reading the table

- **Rest heat before → after** is the direct measurement of D: Peril 2.74 → 0.74 (C) becomes 2.74 → 1.74 (D).
  The "before" is identical in both because the only rest on a Peril route is the prepare rest and nothing before it
  changed. Safe shows a higher "before" under D (1.96 → 2.18) because its first rest decays less, so its second rest
  starts hotter. Shop columns are identical across C and D — the brief's "do not change Shop decay" holds.
- **Heat at the warden** rises on every lane by roughly the one point D keeps: Peril +0.85, Elite +0.90, Safe +0.64,
  Treasure +0.73, Mystery +0.32 (Mystery routes rarely build heat in the first place: 1.07 before the rest).
- **Hook fired %** equals **heat 3–4 %** on every row — the hook is `min_gauge: 3` with no other condition, so this
  is the consistency check that `route_hook` measures the game's semantics (actual heat at entry).
- **Everything downstream of the warden (clear, gold, HP, relics, objectives)** is flat between C and D on every lane:
  clear −0.9 … +2.1 pts, gold +1.3 … +4.0, HP lost in fights −1.1 … +0.2, relics 0 … +0.07. §7 explains why this is
  expected from the bot and must not be read as "the hotter warden is harmless".

## 3. Per seed set (Peril and Safe)

| variant / lane / set | visits | clear % | gold | HP net | relics | NV | heat 3–4 at warden % | hook fired % |
|---|---|---|---|---|---|---|---|---|
| C / safe / 2001 | 190 | 90.5 | 91.2 | 35.8 | 1.55 | 127.1 | 26.7 | 26.7 |
| C / safe / 3001 | 270 | 88.9 | 87.3 | 38.7 | 1.49 | 114.7 | 18.0 | 18.0 |
| D / safe / 2001 | 190 | 93.7 | 95.9 | 37.4 | 1.55 | 128.8 | 38.2 | 38.2 |
| D / safe / 3001 | 270 | 90.4 | 90.8 | 37.3 | 1.48 | 120.1 | 39.2 | 39.2 |
| C / peril / 2001 | 235 | 81.3 | 119.4 | 43.7 | 2.38 | 192.0 | 28.6 | 28.7 |
| C / peril / 3001 | 250 | 80.4 | 121.3 | 43.5 | 2.40 | 195.8 | 31.7 | 31.7 |
| D / peril / 2001 | 235 | 80.8 | 119.3 | 44.3 | 2.35 | 189.5 | 39.7 | 39.7 |
| D / peril / 3001 | 250 | 80.4 | 123.0 | 43.6 | 2.42 | 198.6 | 49.3 | 49.3 |

Death gap (Safe clear − Peril clear) per set: C 9.2 / 8.5, D 12.9 / 10.0. The heat effect replicates in both sets
(Peril heat 3–4: +11.1 and +17.6 pts); the clear-rate differences do not exceed the set-to-set spread of the same
variant (Safe C: 90.5 vs 88.9; Safe D: 93.7 vs 90.4).

## 4. Acceptance criteria in detail

### 4.1 Peril NV ≥ Safe + 25 % — met
C +62 %, D +57 %. D narrows the ratio by 5 points only because Safe gold rose 88.9 → 92.9 (noise-sized, §4.2); Peril NV
itself is unchanged (194.0 → 194.2).

### 4.2 Peril death gap ≤ +10 pts — not met nominally (+11.1), attributed to the Safe side, not to D
- Peril clear is the same under both: 80.8 → 80.6. The gap widens because **Safe clear rose** 89.6 → 91.7.
- D can only *raise* heat. A higher heat adds vent ticks at 3, drops ×0.9 at 3, `vent_surge` at 4. There is no
  mechanism by which keeping one more heat point makes Safe routes win more fights; the +2.1 pts is seed noise plus RNG
  divergence (once the combat patch differs, the random stream of the rest of the route differs too).
- Scale of the noise: a clear % over ~460 visits at ~85–90 % has a standard error of ≈1.5 pts; the C-vs-D *difference*
  of two such numbers ≈2.1 pts; the difference of two gaps (11.1 − 8.8 = 2.3) is about one standard error. The per-set
  Safe values (88.9 / 90.5 / 90.4 / 93.7) span 4.8 pts on their own.
- Per character (Peril clear C → D): kiem_si +1.0, phap_su −7.2, sat_thu −0.1, tho_san +6.1, giao_si −1.1 — opposite
  signs of the same magnitude, the ±10-pt per-character swing already documented in the balance pass.
- Honest statement: **the simulator cannot distinguish C from D on Peril deaths**; the criterion is failed by a number
  that is inside the noise of the method. It is reported as not met, as the brief requires. It was not re-rolled, no
  threshold was moved, no extra seed set was added to push it under 10.

### 4.3 Run-level guard — met
Paired 7-floor runs on `value` (Hellfire floor 2 inside the full climb):

| character | run win % C s1 / D s1 / C s2 / D s2 | hellfire clear % C s1 / D s1 / C s2 / D s2 | won minutes C s1 / D s1 / C s2 / D s2 |
|---|---|---|---|
| kiem_si | 25.7 / 22.9 / 12.9 / 21.4 | 100.0 / 100.0 / 97.1 / 95.7 | 51.7 / 52.6 / 53.4 / 51.8 |
| phap_su | 7.1 / 17.1 / 24.3 / 24.3 | 85.7 / 87.1 / 91.4 / 95.7 | 50.8 / 51.7 / 51.5 / 51.0 |
| sat_thu | 11.4 / 15.7 / 7.1 / 14.3 | 74.3 / 78.6 / 74.3 / 77.1 | 50.5 / 45.3 / 51.0 / 45.8 |
| tho_san | 14.3 / 11.4 / 7.1 / 11.4 | 85.7 / 85.7 / 82.9 / 84.3 | 50.9 / 51.8 / 53.0 / 51.3 |
| giao_si | 8.6 / 7.1 / 14.3 / 14.3 | 81.4 / 80.0 / 81.4 / 77.1 | 52.0 / 53.0 / 54.1 / 52.0 |
| **mean** | **13.4 / 14.8 / 13.1 / 17.1** | **85.4 / 86.3 / 85.4 / 86.0** | |

Pooled over 140 seeds: run win C 13.3 % → D 16.0 % (+2.7, inside ±10); Hellfire clear 85.4 → 86.1. Per-character cells
swing ±10 pts between seed sets of the *same* variant (kiem_si C 25.7 vs 12.9), so only the means carry information.
The run-level numbers say D does not break the climb; they do not say D improves it.

### 4.4 Warden heat 3–4 / hook activation — met
| lane | C heat 3–4 % | D heat 3–4 % | Δ |
|---|---|---|---|
| peril | 30.2 | 44.7 | +14.5 |
| elite | 26.1 | 54.9 | +28.8 |
| safe | 21.6 | 38.8 | +17.2 |
| treasure | 10.3 | 26.4 | +16.1 |
| mystery | 5.5 | 20.1 | +14.6 |

Elite gains most because Elite routes carry the highest heat into the rest (2.91) and have no second rest. Peril at
44.7 % is still below the design intent of ≥ 60 %: with max heat 4 and the hub Shop (−1) + prepare Rest (−1) in the
way, a Peril route needs heat 4 before the hub, or no hub shop, to arrive at 3+. Reaching the intent would require
touching the Shop decay or the hook semantics, both excluded by the brief.

### 4.5 Other lanes — met
Safe, Treasure, Elite and Mystery clear move by −0.9 … +2.1 pts, HP lost in fights by −1.1 … +0.2, HP healed by ≤ 0.1.
The one larger move is Elite NV +8.7 (gold +4.0, relics +0.07); gold on a lane is not a function of heat decay at the
rest (which happens after the last lane fight), so this is RNG divergence, not a reward change. None of the lanes
became easier or harder by any mechanism of D.

## 5. Per character

### 5.1 Peril lane (both sets): clear % / gold / HP net / relics / heat 3–4 at warden %

| character | C | D |
|---|---|---|
| kiem_si | 95.9 / 144 / 25 / 2.59 / 30 % | 96.9 / 147 / 22 / 2.59 / 47 % |
| phap_su | 92.8 / 142 / 47 / 2.56 / 29 % | 85.6 / 130 / 50 / 2.58 / 46 % |
| sat_thu | 65.0 / 96 / 50 / 2.21 / 32 % | 64.9 / 96 / 49 / 2.22 / 47 % |
| tho_san | 78.4 / 114 / 45 / 2.38 / 29 % | 84.5 / 125 / 50 / 2.36 / 42 % |
| giao_si | 72.2 / 105 / 51 / 2.20 / 30 % | 71.1 / 107 / 49 / 2.20 / 41 % |

The heat effect is uniform (+11 … +17 pts on every character). sat_thu's Peril clear of 65 % and giao_si's 72 % are the
same under both variants — the Peril difficulty for those two is a combat property, not a heat property, and D neither
helps nor hurts them. kiem_si is the only character with ~47 % Peril heat-3–4 reach *and* a 97 % clear; for the other
four the hotter warden lands on characters that already die 15–35 % of the time (see §7 on what the sim misses here).

### 5.2 All lanes: clear % / heat 3–4 at warden % / HP lost in fights per route

| character | lane | C | D |
|---|---|---|---|
| kiem_si | safe | 96.8 / 22 % / 40 | 97.8 / 40 % / 38 |
| kiem_si | treasure | 98.9 / 10 % / 31 | 98.9 / 26 % / 35 |
| kiem_si | peril | 95.9 / 30 % / 60 | 96.9 / 47 % / 55 |
| kiem_si | elite | 98.7 / 27 % / 46 | 98.7 / 59 % / 44 |
| kiem_si | mystery | 98.6 / 6 % / 25 | 98.6 / 20 % / 23 |
| phap_su | safe | 92.4 / 22 % / 47 | 94.6 / 38 % / 45 |
| phap_su | treasure | 94.2 / 10 % / 46 | 90.8 / 26 % / 44 |
| phap_su | peril | 92.8 / 29 % / 60 | 85.6 / 46 % / 66 |
| phap_su | elite | 98.7 / 27 % / 53 | 90.7 / 53 % / 54 |
| phap_su | mystery | 94.2 / 6 % / 36 | 97.1 / 19 % / 35 |
| sat_thu | safe | 82.6 / 20 % / 60 | 90.2 / 40 % / 57 |
| sat_thu | treasure | 87.4 / 10 % / 56 | 85.0 / 26 % / 56 |
| sat_thu | peril | 65.0 / 32 % / 79 | 64.9 / 47 % / 77 |
| sat_thu | elite | 78.6 / 24 % / 66 | 85.4 / 54 % / 65 |
| sat_thu | mystery | 91.3 / 4 % / 46 | 91.3 / 20 % / 44 |
| tho_san | safe | 89.1 / 22 % / 52 | 93.5 / 37 % / 52 |
| tho_san | treasure | 92.0 / 10 % / 52 | 94.2 / 26 % / 48 |
| tho_san | peril | 78.4 / 29 % / 66 | 84.5 / 42 % / 69 |
| tho_san | elite | 80.0 / 27 % / 57 | 88.0 / 58 % / 54 |
| tho_san | mystery | 94.2 / 6 % / 30 | 95.6 / 20 % / 34 |
| giao_si | safe | 87.0 / 22 % / 56 | 82.6 / 39 % / 57 |
| giao_si | treasure | 94.2 / 10 % / 46 | 93.1 / 26 % / 46 |
| giao_si | peril | 72.2 / 30 % / 77 | 71.1 / 41 % / 76 |
| giao_si | elite | 88.0 / 26 % / 62 | 86.7 / 51 % / 61 |
| giao_si | mystery | 94.2 / 6 % / 37 | 94.2 / 20 % / 37 |

Per character the clear deltas go both ways (phap_su Peril −7.2 and Elite −8.0 while sat_thu Safe +7.6 and Elite +6.8).
Per-character cells are 69–97 visits each (standard error 3–5 pts), so none of these individual moves is a finding.

### 5.3 Rest heat before → after, Peril lane

| character | C | D |
|---|---|---|
| kiem_si | 2.78 → 0.78 (0.98 rests / route) | 2.78 → 1.78 |
| phap_su | 2.78 → 0.78 (0.99) | 2.78 → 1.78 |
| sat_thu | 2.72 → 0.72 (0.84) | 2.72 → 1.72 |
| tho_san | 2.72 → 0.72 (0.95) | 2.72 → 1.72 |
| giao_si | 2.67 → 0.67 (0.87) | 2.67 → 1.67 |

(sat_thu and giao_si have fewer rests per route because more of their routes end in a death before the prepare rest.)

## 6. Gameplay interpretation

- **Is Rest still meaningful?** Yes, and more so: under C, Rest takes a Peril route from 2.74 to 0.74 — the warden is
  almost always fought cold (30 % at heat 3–4) and the heat the player built on the lane is effectively refunded.
  Under D the Rest heals HP and takes one heat point, leaving 1.74 on average, so the choice "rest or not" starts to
  matter (a player at heat 3 who skips the rest meets the warden at 3 and gets `vent_surge`; one who rests meets it
  at 2). Note the simulator's bot always rests; the "skip the rest" branch is not measured.
- **Does Rest still cost heat?** It removes heat; it never adds it. "Cost" in the brief's sense (resting is not free of
  consequence) is not something this slice has — resting is strictly good for the player in both C and D. D makes it
  less *overwhelmingly* good.
- **Shop vs Rest distinct?** Under D both decay 1. They stay distinct by what they give (gold → cards / relics vs HP /
  forge) but no longer by heat. If the intent is "Rest cools more than Shop", D erases that; if the intent is "Rest and
  Shop each cool a little", D delivers it. This is a design call, not a measurement.
- **Warden difficulty.** Under D the hook fires on 45 % of Peril and 55 % of Elite routes. In the game `vent_surge`
  on the warden means three vents instead of the heat-row count; a real player will take vent damage during the warden
  fight. The bot does not (it leaves warned cells before they erupt, §7), so **the simulator reports zero cost for D's
  main effect**. The honest expectation is that D makes the Hellfire warden harder for human players on roughly half of
  Peril/Elite routes and a third of Safe routes, by an amount this method cannot estimate.
- **Peril reward and death band.** Unchanged by D (gold 120 → 121, relics 2.39 → 2.39, NV 194 → 194, clear 80.8 → 80.6).
  D is not a Peril-balance change; the balance-pass conclusion (variant C) stands.

## 7. Limitations

1. **The bot never takes vent damage** (it leaves a warned cell within 0.4 s and never stands on an erupting one), so
   heat-3 vent ticks, heat-4 `vent_surge`, and the warden hook have no measurable effect on clear or HP. Every "D is
   harmless downstream" number in this report has this blind spot; D's main effect is a cost the sim cannot price.
2. **Seed noise**: 70 seeds per character per set, 345–485 visits per lane cell. Lane clear differences < ~3 pts and
   per-character differences < ~8 pts are noise. The death-gap criterion lives inside this band (§4.2).
3. **Pairing is weak after the fork**: C and D share the seed, map and deck, but once the heat rule differs the
   combat RNG stream diverges, so the pairing does not cancel combat noise the way a true paired test would.
4. **The bot always rests and always shops** when the node is on its route, so the "skip the Rest to keep heat for the
   objective" play that D is meant to enable is unmeasured; so is any human reaction to seeing heat 3 on the gauge.
5. Objectives: only `no_hit_3` / `joiner` are modelled (0.22 met per Peril visit, unchanged); `big_cast` /
   `vent_dancer` are not evaluated by the bot. Ink rows need `--pieces=on`, which this experiment did not use (pieces
   do not interact with heat decay).
6. Tool code changed for this experiment (`ROUTE3` row, `route_hook` field in `deck_sim.gd`): instrumentation only,
   verified by the C re-runs reproducing the balance-pass Peril numbers (set 2001: 81.3 % / 119.4 gold / 2.38 relics /
   192.0 NV, identical to `balance-validation-2026-11-12.md` §4). The full test suite was not re-run for this
   experiment (no game code, data or tests changed); the last full suite is the balance pass's 286 / 286.

## 8. Recommendation

**Keep C in production data now** — the brief's rule is "if D fails any important criterion, retain C", and the death-gap
criterion is nominally failed. **Recommend adopting D after one targeted human check**, because:

- D does exactly what it was tested for: Rest keeps one heat point, the warden sees heat 3–4 on 45 / 55 % of Peril /
  Elite routes instead of 30 / 26 %, with no measurable change to lane rewards, lane deaths, or the 7-floor climb.
- The one failed criterion is a +2.1-pt move in *Safe* clear that D has no mechanism to cause, and the Peril side it is
  meant to protect is unchanged (80.8 → 80.6). More seeds would shrink that noise but would be re-rolling for a pass.
- The real unknown is the warden at heat 3–4 with `vent_surge` for a human — the sim is blind there. That is a
  10-minute playtest (Hellfire, Peril lane, reach the warden at heat 3+; the evidence runner's E-scenarios or a seeded
  run get there), not another simulation.

If the user prefers a sim-only decision, the honest answer is "inconclusive → C", and the ≥ 60 % design intent for
Peril warden heat stays unmet under either variant until the hub Shop decay or the hook semantics are revisited (both
out of this brief's scope).

## 9. Raw file index

- `heat-decay/run-heat-decay.sh`, `heat-decay/run-heat-decay.log` (110 jobs, all `exit=0`, 12:50 → 13:34),
  `heat-decay/jobs.txt`
- `heat-decay/C-s{2001,3001}-probe-{safe,treasure,peril,elite,mystery}-{kiem_si,phap_su,sat_thu,tho_san,giao_si}.txt` (50)
- `heat-decay/D-s{2001,3001}-probe-…` (50), `heat-decay/D-s{2001,3001}-full-value-<char>.txt` (10)
- `balance/C-full-value-<char>.txt`, `balance/rep-C-full-value-<char>.txt` (the paired C full runs, from the balance pass)
- `heat-decay/aggregate-heat.py` → `heat-decay/aggregate-heat.md`
- `variants/region_rules_D.json`

Production data untouched: `assets/data/region_rules.json` (rest −2), `assets/data/route_archetypes.json` (variant C).
