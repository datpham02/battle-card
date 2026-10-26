# Story 036 (2026-10-26) — region balance simulation

Tool: `tools/balance/deck_sim.gd --region=<ids> --floor=1,3,5 --seeds=30` (new in this story). Each match is played
alone, at full HP, with the starter deck; floor N applies `floor_scaling` row N after `region_normalize`. Bot dodge 0.85
is the TD-006 legacy default (not re-anchored). Timeout is 180 s; most "losses" below are timeouts, not deaths.
Raw output: `simulation-regions-raw.txt` (sections `===== <run>`). A 30-seed cell has about +-9 points of noise per
match, the region mean (9 matches x 3 characters) about +-3.

Win % is the mean of Kiem si / Phap su / Sat thu.

## Targets (story)

- Swamp and desert region mean win % within +-10 points of the ch1-ch3 mean at floors 1, 3, 5.
- Mire damage <= 15 % of the HP the player takes in swamp matches.
- No match above 95 % win at floor 1: **not attainable as measured** — every old-region match is also 97-100 % at
  floor 1 (one match alone, full HP, floor-1 scaling). Reported as a measurement limit, not a region problem.

## Result

| Region | Floor 1 | Floor 3 | Floor 5 | Mire share of HP taken |
|---|---|---|---|---|
| ch1-ch3 (same run) | 95.6 | 90.1 | 80.9 | — |
| swamp, before tuning | 95.2 | 85.2 | 68.2 (-12.7) | 19-23 % |
| swamp, after | 96.4 (+0.8) | 89.6 (-0.5) | 80.6 (-0.3) | 10.7 / 11.5 / 13.4 % |
| desert, before tuning | 98.8 | 88.8 | 71.0 (-9.9) | — |
| desert, after | 99.3 (+3.7) | 90.4 (+0.3) | 77.5 (-3.4) | — |

Per old region after (floor 1 / 3 / 5): ch1 96.9 / 91.4 / 84.4, ch2 95.5 / 90.2 / 73.7, ch3 94.4 / 88.8 / 84.7.
The old regions were not changed; their run-to-run difference is noise.

All targets PASS except the floor-1 cap (measurement limit above). 0 script errors in all runs.

## Tuning (JSON only)

| Where | Change | Why |
|---|---|---|
| `combat.json` `hazards.mire_tick_damage` (+ `TileHazards.DEFAULTS`, schema.md) | 1.0 -> 0.5 | mire share 19-23 % > 15 %; 0.5 gives 10-14 %. Win % barely moved (mire hurt the bot in exchange for HP it would lose anyway) |
| `bog_hound` | `boss_step_cooldown_mult` 1.3 -> 1.6, `swing_speed_mult` 0.9 -> 1.0 | floor 5: 14 % win, 54 % timeouts |
| `reed_witch` | step 1.35 -> 1.6, `rotten_thrower.interval_sec` 7.0 -> 9.0 | floor 5: 28 % win, 72 % timeouts |
| `sun_archer` | step 1.3 -> 1.6, swing 0.9 -> 1.0 | floor 5: 30 % win |
| `scarab_guard` | `boss_defense` 3 -> 2 | floor 5: 42 % win, 58 % timeouts |

Backup of chapters.json before tuning: kept in the session scratchpad only.

## Floor 5 per match (after), win % / timeout %

| Swamp | | Desert | |
|---|---|---|---|
| bog_rat 100 / 0 | | dune_jackal 100 / 0 | |
| mire_slug 96 / 4 | | dust_nomad 93 / 7 | |
| swamp_lizard 95 / 5 | | mirage_sprite 95 / 5 | |
| spore_cap 90 / 10 | | scorpion 93 / 7 | |
| reed_witch 82 / 18 (was 28) | | sand_beetle 85 / 15 | |
| bog_hound 78 / 13 (was 14) | | sun_archer 82 / 10 (was 30) | |
| leap_frog 78 / 22 | | sand_burrower 76 / 24 | |
| marsh_toad 71 / 29 | | scarab_guard 49 / 50 (was 42) | |
| toad_matriarch (boss) 37 / 42 | | sand_sphinx (boss) 24 / 76 | |

The region bosses sit at the low end of the old-region boss range (forest_witch 33, ogre_king 35, goblin_warlock 61,
mist_lord 81); `sand_sphinx` is the lowest, almost all timeouts (burrow + sandstorm stretch the fight). Left as is —
the region mean is in band; watch it in the gate 8 playtest.
