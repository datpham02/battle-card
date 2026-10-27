# Story 040 (2026-10-26/27): whole-run balance simulation, run v6

Tool: `tools/balance/deck_sim.gd --run=v6` (Story 040 package: 5 floors + the An Dai final, floor heal, relics, gold,
shop, Spare / Execute, Kiep). Policy "build" with `--mercy=mixed --shop=on --pieces=off --relic=value`, Kiep 0, bot
dodge 0.85 (the TD-006 legacy default, **not anchored**: no playtest log exists, Part A is DEFERRED). Raw output:
`simulation-run-v6-raw.txt` (sections `===== final2/<job>` = the shipped data, `===== final/<job>` = the data before the
second data pass). Every table has its `bot: ... | overrides: ...` header in the raw file.

Noise: one 70-seed cell has a standard deviation of about 5-6 points on run win % (the tool prints it); a 30-seed cell
about 8-9. The same data gave Kiem si 36 % on seeds 1-50 and 50 % on seeds 101-150 during tuning, so single-cell
differences under about 10 points are not signal.

Seed sets: tuning rounds used seeds 1-50 / 101-150 / 201-250 / 301-350; the final check used seeds the tuning never saw
(`--seed-offset=1000`, then `--seed-offset=2000` after the second data pass), as the story's Implementation Notes ask.

## Final result (shipped data, seeds 2001-2070, 70 runs per character)

| Character | Run win % | Deaths f1/f2/f3/f4/f5/final | Final won when reached | Boss hits / won run | Won-run minutes (est.) | Lost-run minutes |
|---|---|---|---|---|---|---|
| Kiem si | 44.3 | 1/0/7/5/10/16 | 66.0 % (31/47) | 34.7 | 28.2 | 23.8 |
| Phap su | 35.7 | 6/8/5/8/9/9 | 73.5 % (25/34) | 32.4 | 29.3 | 21.8 |
| Sat thu | 42.9 | 2/5/8/8/7/10 | 75.0 % (30/40) | 30.4 | 26.7 | 18.6 |
| Tho san | 27.1 | 5/5/13/5/7/16 | 54.3 % (19/35) | 32.8 | 29.7 | 18.9 |
| Giao si | 47.1 | 1/2/4/4/8/18 | 64.7 % (33/51) | 36.1 | 27.9 | 26.4 |

Mean run win 39.4 %; spread 20.0 points (47.1 - 27.1). Mean boss swing hit 6.1-7.1 % of max HP. Gold: 75-81 % of
earned gold spent in won runs; median gold left at the final 28-47 (one shop relic = 60).

## Part C targets

| Target | Result | Verdict |
|---|---|---|
| Run win 30-45 % per character (Kiep 0) | 3 of 5 inside; Tho san 27.1, Giao si 47.1 (both within 1 sd of the band) | FAIL (2 of 5, by 2-3 pts) |
| Spread between characters <= 20 pts | 20.0 (tool prints FAIL on the unrounded value) | at the limit |
| Onboarding (empty save) >= 20 % | 50.0 / 46.7 / 33.3 (Kiem si / Phap su / Sat thu, `--progress=none`, pass-1 data, 30 seeds) | PASS |
| Death probability non-decreasing f1..f5 (allow -3) | 3 of 5 PASS; Phap su f3 < f2 by 3.6, Tho san f4 < f3 by 11 | FAIL (2 of 5) |
| Floor-1 deaths <= 10 % | 1.4-8.6 % | PASS |
| Final won when reached 50-70 % | 3 of 5; Phap su 73.5, Sat thu 75.0 | FAIL (2 of 5) |
| Won-run minutes 40-50 | 26.7-29.7 | DEFERRED (see "Minutes and boss hits") |
| Lost-run minutes >= 15 | 18.6-26.4 | PASS |
| Boss hits per won run 15-30 | 30.4-36.1 | DEFERRED (see "Minutes and boss hits") |
| Mean boss hit 4-15 % of max HP | 6.1-7.1 % | PASS |
| Regions within +-10 pts of the floor mean | Phap su, Giao si PASS; Kiem si sky_isles f3 82.4 vs 94.9; Sat thu, Tho san swamp f2 85.0 vs 96.3 (cells of 20-25 matches) | FAIL (3 of 5) |
| Kill vs spare gap <= 10 pts | 30 seeds each: kill 48.7 vs spare 38.0 mean (+10.7); per character +23 / +33 / +13 / -3 / -13 | FAIL (borderline) |
| No relic lift > +15 | khoi_the +19.4, huyet_an +18.5 (an_don was +20.2 before the second pass, now under +15) | FAIL |
| No shop item bought < 2 % of its offers | 15 items: 12 cards the build policy never picks plus the 3 services (heal, remove card, remove shape: 0 / 595) | FAIL (bot policy) |
| Pieces on not above off by > 10 | on 41.3 vs off 44.7 (mean of 5 x 30 seeds) | PASS |
| Gold spent >= 70 % (won runs); gold left <= one relic | 75-81 %; 28-47 <= 60 | PASS |
| Kiep monotone 0..10, Kiep 10 >= 3 %, no step > 12 | Kiem si, 30 seeds: 0=60.0 1=46.7 2=46.7 3=46.7 4=23.3 5=10.0 6=6.7 7..10=0.0 | FAIL |
| Bot anchored on a playtest (Part A) | no playtest log | DEFERRED (TD-006 open) |

### Minutes and boss hits

The two targets pull against each other under the bot: it wins a run in about 28 minutes and takes 30-36 boss hits.
40-50 minutes needs about 45 % more matches, which brings about 45 % more boss hits (target 15-30). Both numbers are
set by the bot's speed and dodge (Part A): a person drags pieces and reads cards more slowly (minutes up, no extra hits)
and dodges at an unknown rate. So both stay DEFERRED until the gate-8 playtest anchors the bot; they were not forced
with data.

### Dodge sensitivity (pass-1 data, 30 seeds)

| Character | dodge 0.70 | 0.85 | 0.95 |
|---|---|---|---|
| Kiem si | 33.3 | 36.7 | 46.7 |
| Phap su | 20.0 | 40.0 | 30.0 |

The run win rate moves by about 10-15 points across the plausible dodge range (30-seed noise is about 9): the tuning is
only as good as the 0.85 assumption.

### Relics none (shipped data, 30 seeds)

33.3 / 36.7 / 30.0 / 30.0 / 40.0 (mean 34.0 against 39.4 with `--relic=value`): relics as a whole add about 5 points.

## Data changes (JSON only)

| File / key | Old -> new | Why (table that was off) |
|---|---|---|
| `characters.json` every `starter_deck` | see Part C2 in the story | Part C2: each character's direction (test `starter_identity_test`) |
| `chapters.json` `world.floor_heal_ratio` | 0.35 -> 0.6 | base run win 0-27 %: deaths piled up at region bosses after the HP carry-over |
| `chapters.json` `world.floor_scaling` hp_mult rows 1..5 | 1.0 / 1.1 / 1.2 / 1.3 / 1.4 -> 0.7 / 0.8 / 0.85 / 1.05 / 1.15 | run win too low; a steeper slope late so deaths rise with the floor |
| `chapters.json` `world.floor_scaling.final.hp_mult` | 1.5 -> 1.25 | Kiep 4 (floor_shift) makes floor 5 use this row: at 2.0 it was a cliff (Kiep 3 -> 4: 30 -> 7 %) |
| `chapters.json` `an_dai_keeper.boss_max_hp` | 130 -> 198 | the final's difficulty moved here from the final row: final HP at Kiep 0 = 198 x 1.25 = 248 (was 195); with the lower floors the final was won 80-96 % when reached |
| `chapters.json` `sky_isles.region_normalize.hp_mult` | 0.53 -> 0.45 | sky_isles 15-24 pts under the floor mean at floors 3-4 |
| `chapters.json` `world.fate.execute_artifact_offers` | 3 -> 2 | kill beat spare by 10-20 pts per character |
| `characters.json` `phap_su.max_hp` | 190 -> 210 | Phap su 13-20 % while the others were 30-40 (early deaths) |
| `characters.json` `tho_san.max_hp` | 190 -> 200 | Tho san low end of the band in round 6 |
| `characters.json` `sat_thu.passive.params.damage_mult` (quick_blade) | 1.25 -> 1.4 | Sat thu 18-24 % after the world change; its identity (small casts) rather than HP |
| `relics.json` `an_don.params.mult` | 2.0 -> 1.75 | RELIC LIFT +20.2 |

Text that names these numbers was updated with them (`strings.csv`): `passive.quick_blade.desc` 25 % -> 40 %;
`relic.an_don.desc` x2 -> x1,75 / x1.75; and `passive.second_wind.desc` said 10 HP while the data has been 20 since
before this story (fixed to 20).

## Tuning rounds (summary; per-round raw output kept in the session scratch, not in the repo)

| Round | Seeds | Change tried | Run win % KS / PS / ST / TS / GS |
|---|---|---|---|
| base | 1-70 | new starter decks, old world data | 21.4 / 5.7 / 0.0 / 2.9 / 18.6 |
| 1 | 1-30 | heal 0.6 and hp x0.85 | 26.7 / 16.7 / 23.3 / 30.0 / 36.7 |
| 2 | 1-30 | heal 0.8, hp x0.85 | 30.0 / 13.3 / 30.0 / 40.0 / 36.7 |
| 3 | 1-50 | heal 0.6, hp x0.8 | 54 / 18 / 32 / 36 / 52 (final won 80-96 % when reached) |
| 4 | 1-50 | hp x0.75, final row 1.8 | 36 / 32 / 18 / 44 / 44 |
| 5 | 1-50, 101-150 | Sat thu, Phap su probes (`--char-set`) | ST hp 205: 24, hp 220: 28, quick_blade 1.4: 40; PS hp 205: 36, hp 215: 42 |
| 6 | 201-250 | rows 0.7..1.1, final 2.0, ST qb 1.4, PS 210 | 34 / 42 / 50 / 30 / 36 |
| 7 | 301-350 | rows 0.7/0.8/0.85/1.05/1.15, final 2.0, ST qb 1.33, TS 200 | 42 / 32 / 32 / 36 / 44 |
| final pass 1 | 1001-1070 | round 7 written to JSON | 27.1 / 31.4 / 24.3 / 34.3 / 32.9 |
| final pass 2 | 2001-2070 | + final row 1.25 / keeper 198, sky_isles 0.45, execute offers 2, an_don 1.75, ST qb 1.4 | 44.3 / 35.7 / 42.9 / 27.1 / 47.1 |

Pass 1 and pass 2 differ by up to 17 points per character for small data changes: most of that is seed-set noise
(sd 5-6 per cell), which is why tuning stopped here instead of chasing Tho san and Giao si back into the band.

## Runtime

Smoke (5 seeds, one character): 38.1 s. One character x 70 seeds: about 7-9 minutes; five characters in one process
(70 seeds): 36 minutes (2184 s). The tuning ran up to 11 processes in parallel on a 12-thread machine.

## Open after this story

- Kiep ladder (FAIL): Kiep 4 floor_shift costs 23 pts after the steeper floor curve; Kiep 7-10 win 0 % (Kiep 10 >= 3 %
  fails). Needs its own tuning pass on `kiep_levels.json` (order and params): new TD.
- Shop "never bought" and relic lift: limits of the bot's static policies (it never buys services, its card picks
  follow the build policy, relic lift is correlational and the value policy picks some relics first). A smarter shop
  policy is tooling work: new TD.
- Minutes and boss hits: wait for the playtest (TD-006).
