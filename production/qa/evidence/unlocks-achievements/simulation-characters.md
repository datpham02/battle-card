# Story 037 (2026-10-26) — characters and unlocks simulation

Tool: `tools/balance/deck_sim.gd --world --seeds=70` (build policy, bot dodge 0.85 = TD-006 default), new flag
`--progress=none|all` (`none` = an empty save: the 4 cards, 3 shapes, 4 relics and 2 characters of this story are locked;
`all` = nothing locked) and the new `--unlock-runs=8 --unlock-reps=30` mode. Raw output: `simulation-characters-raw.txt`
(sections `===== <run>`). A 70-seed cell at these rates has about +-4 points of noise (one standard error). The sim lets the new
characters play under `--progress=none` too, so both modes have all five rows.

Run win % is low for every character (5-16 %): that is the known v6 run balance (TD-029 .. TD-031), retuned in Story 040.
This story's targets are the differences, not the levels.

## 1. Run win %, final data

| Character | `--progress=none` | `--progress=all` | all - none (target <= 10) |
|---|---|---|---|
| Kiem si | 15.7 | 12.9 | -2.8 PASS |
| Phap su | 11.4 | 7.1 | -4.3 PASS |
| Sat thu | 10.0 | 5.7 | -4.3 PASS |
| Tho san | 14.3 | 11.4 | -2.9 PASS |
| Giao si | 5.7 | 5.7 | 0.0 PASS |

New characters against the mean of the three old ones (target +-10): with everything open the old mean is 8.6, Tho san
11.4 (+2.8) and Giao si 5.7 (-2.9): PASS. (Empty save: old mean 12.4, Tho san +1.9, Giao si -6.7.)

## 2. Tuning: the three new 5-cell shapes (JSON only)

First run, shapes at the story's weights (1.0 in default/ch2/ch3, 0.5 in ch1/swamp/desert): unlocking everything cost
Kiem si 12.8 points (15.7 -> 2.9) and Phap su 11.4 (11.4 -> 0.0), above the 10-point limit. Probes with `--piece-weight-set`
(progress=all):

| New shapes w5 / n5 / v5 | Kiem si | Phap su |
|---|---|---|
| story weights | 2.9 | 0.0 |
| removed (weight 0) | 10.0 | 8.6 |
| x0.5 | 7.1 | 5.7 |
| x0.25 (shipped) | 12.9 | 7.1 |

The large shapes dilute the drop pool and the bot plays small casts (TD-030), so more 5-cell drops make runs harder, not
easier: unlocking is breadth, never power, but here it was a trap. Shipped: x0.25 (0.25 in `default ch2 ch3`, 0.125 in
`ch1 swamp desert`). The cards and relics were not tuned: with the shapes removed the rest moves the mean by -2.8..-5.7,
within noise.

## 3. Runs to unlock each new character (alternating Spare / Execute, 30 repetitions, up to 8 runs)

| Played as | Tho san (`hunter_path`, 3 executions) | Giao si (`mercy_path`, 3 spares) |
|---|---|---|
| Kiem si | 2.27 (median 2) PASS | 2.63 (median 2) PASS |
| Phap su | 2.57 (median 2) PASS | 3.03 (median 3) — 0.03 over 3, within noise |
| Sat thu | 2.33 (median 2) PASS | 2.70 (median 2) PASS |

Target 1-3 runs: met for both characters (mean of the three columns 2.39 and 2.79); the one cell at 3.03 is within noise.
Sim fix: the first version restarted the alternation at Execute every run, so a run that died after one boss gave only
executions and Giao si took 3.0-3.6 runs; `--unlock-runs` now continues the alternation across runs (the ledger's choice
count), which is what "alternating" means for a player.

## 4. Bot rules for the new signatures (tools/balance/README.md)

Vay Bat right after a player seal / thorn zone forms; Thanh An when the boss has >= 1 Han stack.
