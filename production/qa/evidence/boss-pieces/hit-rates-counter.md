# Story 025: counter hits on a swinging boss, and piece-boss vs rune-boss danger (chapter 1)

Measured on 2026-10-25 with `counter_probe.gd`, a scratch copy of `hit_probe.gd` (which is based on `deck_sim.gd`). It drives the real CombatState, BossController, BossBrain, CutActor and SwingArbiter headless, with dt 0.05, `--chapter=0` (ch1), 40 casts per cell and all 11 chapter-1 enemies. The raw lines are in `hit-rates-counter-raw.txt`. No product code, data or tests were changed.

## Method

- **Probe setup (same as Stories 024 and 028):** the player stands still and is never killed (HP is refilled each tick). The boss has 1e6 HP. The card is *Kiếm khí* L1, and the player's windup grows with the cell count: 0.45 / 0.70 / 0.95 / 1.20 / 1.45 / 1.70 s for 1–6 cells. A boss swing that lands on the player while the player is still winding up **cuts the player's cast**, and that cast never resolves.
- **`--boss=rune|pieces`:** `pieces` calls `BossController.enable_pieces(PieceLibrary.load_from_file(), "ch1", match_seed + 2)` right after the controller is built, the same way `CombatView` does (default `max_pieces` 2). `rune` keeps the classic labelled-point boss, so it can be compared with earlier tables.
- **`--root=on|off`:** overrides `BossBrainConfig.root_while_swinging` after the match parameters are applied. The data default is `true`. No chapter-1 match overrides it.
- **`counter`:** in the same tick that the boss's actor emits `swing_started`, the player places the best single `pieces.json` piece of exactly N cells on the boss's current cell. Any rotation and any valid anchor (`PiecePlacement.valid_anchors`) can be used. Among the placements that cover the boss cell, the probe picks the one that also covers the most of the boss's orthogonal neighbours; ties are broken by a seeded RNG. One cast is made per boss swing. If the player is still winding up the previous counter, that boss swing goes unanswered and is not counted.
- **`counter_pair`:** the same, but with the best union of two pieces that has exactly N cells (4–6).
- **`piece` / `piece_strike`:** the Story 024 modes, re-run in the same session against the piece-boss with root ON. `piece` casts every 0.6–1.6 s at the boss cell. `piece_strike` casts the instant the boss has stepped.
- **Main value: hit % of casts.** This is hits / casts. A cast that the boss's swing cut, or one that no piece can fit (`*`), counts as a miss. The value in brackets is hit % of *resolved* casts, which is the metric used in the Story 024 and 028 tables. Under root ON it is almost always 100 %, so the boss never escapes a counter that actually lands.
- **cut by boss:** the number of counter casts interrupted by the boss's own swing landing first. This is the player losing the windup race.
- **Danger (section 4):** the player stands still and never casts. The probe runs 3 seeds × 600 s of simulated time per enemy, for each combination of boss type (rune / pieces) and root (on / off).
- `n=…` marks a cell with fewer than 40 casts, because the boss swung fewer than 40 times inside the 900 s probe timeout. `*` marks cells where some casts had no piece of that size able to cover the boss cell.

## 1. Counter, single piece (sizes 1–5) — hit % of casts (hit % of resolved casts in brackets)

| enemy | role | arena | react / think / step cd (s) | N | counter, piece-boss, root ON | cut by boss | counter, piece-boss, root OFF | cut by boss | counter, rune-boss, root ON | counter, rune-boss, root OFF | piece (ON) | piece_strike (ON) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| goblin_scout | battle | square | 0.60 / 0.50 / 0.80 | 1 | 72 (100) n=18 | 5 | 72 (100) n=18 | 5 | 100 | 100 | 70 | 100 |
| | | | | 2 | 88 (100) | 5 | 58 (64) | 4 | 100 | 73 | 60 | 100 |
| | | | | 3 | 83 (100) | 7 | 80 (97) | 7 | 83 | 60 | 60 | 98 |
| | | | | 4 | 68 (100) | 13 | 65 (96) | 13 | 88 | 85 | 73 | 98 |
| | | | | 5 | 40 (100) | 24 | 35 (78) | 22 | 78 | 60 | 30 | 78 |
| wolf | battle/danger | square | 0.45 / 0.40 / 0.65 | 1 | 75 (100) | 10 | 23 (26) | 6 | 100 | 10 | 53 | 100 |
| | | | | 2 | 80 (100) | 8 | 40 (50) | 8 | 100 | 40 | 43 | 100 |
| | | | | 3 | 60 (100) | 16 | 30 (50) | 16 | 63 | 45 | 53 | 55 |
| | | | | 4 | 35 (100) | 26 | 20 (100) | 32 | 63 | 55 | 43 | 83 |
| | | | | 5 | 13 (100) | 35 | 5 (67) | 37 | 40 | 5 | 23 | 53 |
| goblin_chief | miniboss | square | 0.35 / 0.30 / 0.55 | 1 | 75 (100) | 10 | 38 (50) | 10 | 100 | 33 | 40 | 85 |
| | | | | 2 | 75 (100) | 10 | 20 (25) | 8 | 100 | 40 | 23 | 18 |
| | | | | 3 | 65 (100) | 14 | 13 (20) | 15 | 28 | 10 | 23 | 40 |
| | | | | 4 | 13 (83) | 34 | 0 (0) | 30 | 58 | 0 | 10 | 30 |
| | | | | 5 | 5 (67) | 37 | 0 (0) | 35 | 28 | 3 | 3 | 8 |
| goblin_warrior | battle/danger | rect | 0.60 / 0.50 / 0.80 | 1 | 95 (100) | 2 | 88 (95) | 3 | 100 | 100 | 55 | 100 |
| | | | | 2 | 95 (100) | 2 | 43 (44) | 1 | 100 | 43 | 58 | 100 |
| | | | | 3 | 73 (100) | 11 | 43 (74) | 17 | 80 | 73 | 38 | 90 |
| | | | | 4 | 25 (100) | 30 | 40 (94) | 23 | 60 | 65 | 73 | 73 |
| | | | | 5 | 10 (100) | 36 | 8 (75) | 36 | 58 | 58 | 30 | 60 |
| dire_wolf | battle/danger | rect | 0.45 / 0.40 / 0.65 | 1 | 100 (100) | 0 | 18 (18) | 0 | 100 | 5 | 53 | 100 |
| | | | | 2 | 93 (100) | 3 | 38 (38) | 1 | 100 | 53 | 65 | 100 |
| | | | | 3 | 70 (100) | 12 | 50 (67) | 10 | 80 | 60 | 43 | 33 |
| | | | | 4 | 25 (100) | 30 | 23 (75) | 28 | 60 | 60 | 38 | 83 |
| | | | | 5 | 13 (50) n=8 | 6 | 3 (11) n=36 | 27 | 30 | 13 | 20 | 40 |
| goblin_shaman | miniboss | rect | 0.40 / 0.35 / 0.59 | 1 | 100 (100) | 0 | 30 (30) | 0 | 100 | 23 | 48 | 100 |
| | | | | 2 | 100 (100) | 0 | 13 (13) | 2 | 100 | 30 | 38 | 30 |
| | | | | 3 | 83 (97) | 6 | 35 (48) | 11 | 80 | 50 | 28 | 35 |
| | | | | 4 | 35 (100) | 26 | 20 (53) | 25 | 68 | 3 | 15 | 65 |
| | | | | 5 | 23 (82) | 29 | 0 (0) n=23 | 19 | 28 | 8 | 10 | 8 |
| wolf_alpha | miniboss | rect | 0.35 / 0.30 / 0.55 | 1 | 90 (100) | 4 | 18 (21) | 6 | 100 | 8 | 35 | 90 |
| | | | | 2 | 98 (100) | 1 | 13 (14) | 5 | 100 | 33 | 28 | 15 |
| | | | | 3 | 48 (95) | 20 | 8 (15) | 20 | 65 | 5 | 20 | 35 |
| | | | | 4 | 20 (89) | 31 | 0 (0) | 29 | 58 | 0 | 5 | 10 |
| | | | | 5 | 8 (100) | 37 | 0 (0) | 36 | 38 | 0 | 5 | 5 |
| goblin_archer | battle/danger | cross | 0.45 / 0.40 / 0.65 | 1 | 100 (100) | 0 | 15 (17) | 5 | 100 | 5 | 68 | 100 |
| | | | | 2 | 100 (100) | 0 | 55 (65) | 6 | 100 | 53 | 43 | 100 |
| | | | | 3 | 65 (100) | 14 | 53 (78) | 13 | 78 | 73 | 68 | 58 |
| | | | | 4 | 43 (100) | 23 | 38 (94) | 24 | 68 | 60 | 58 | 95 |
| | | | | 5 | 20 (89)* | 31 | 15 (50)* | 28 | 55* | 38* | 45 | 70* |
| goblin_brute | battle/danger | u_shape | 0.40 / 0.35 / 0.59 | 1 | 98 (100) | 1 | 28 (28) | 0 | 100 | 28 | 45 | 100 |
| | | | | 2 | 98 (100) | 1 | 20 (22) | 3 | 100 | 25 | 23 | 28 |
| | | | | 3 | 68 (100) | 13 | 43 (61) | 12 | 68 | 43 | 35 | 43 |
| | | | | 4 | 50 (100) | 20 | 28 (55) | 20 | 53 | 10 | 25 | 58 |
| | | | | 5 | 3 (100) | 39 | 0 (0) n=38 | 37 | 28 | 10 | 13 | 10 |
| goblin_warlock | boss | staircase | 0.35 / 0.30 / 0.55 | 1 | 75 (100) | 10 | 28 (37) | 10 | 100 | 13 | 33 | 93 |
| | | | | 2 | 70 (100) | 12 | 40 (59) | 13 | 80 | 58 | 30 | 18 |
| | | | | 3 | 25 (100) | 30 | 3 (9) | 29 | 83 | 8 | 8 | 28 |
| | | | | 4 | 25 (100) | 30 | 0 (0) | 29 | 58 | 3 | 15 | 20 |
| | | | | 5 | 10 (18)* | 18 | 0 (0)* | 23 | 20* | 3* | 0* | 3* |
| forest_witch | boss | cross | 0.30 / 0.25 / 0.50 | 1 | 80 (100) | 8 | 0 (0) | 0 | 100 | 0 | 28 | 20 |
| | | | | 2 | 63 (100) | 15 | 15 (23) | 14 | 100 | 38 | 28 | 28 |
| | | | | 3 | 3 (100) | 39 | 3 (100) | 39 | 65 | 10 | 10 | 33 |
| | | | | 4 | 0 (-) | 40 | 0 (-) | 40 | 55 | 15 | 15 | 20 |
| | | | | 5 | 0 (-) | 40 | 0 (-) | 40 | 58 | 10 | 8 | 43 |

## 2. Counter, two-piece union (sizes 4–6) — hit % of casts (hit % of resolved)

| enemy | role | N | counter_pair, root ON | cut by boss | counter_pair, root OFF | cut by boss |
|---|---|---|---|---|---|---|
| goblin_scout | battle | 4 | 63 (100) | 15 | 58 (92) | 15 |
|  |  | 5 | 45 (100) | 22 | 45 (100) | 22 |
|  |  | 6 | 20 (100) | 32 | 10 (50) | 32 |
| wolf | battle/danger | 4 | 23 (100) | 31 | 15 (86) | 33 |
|  |  | 5 | 10 (100) | 36 | 5 (33) | 34 |
|  |  | 6 | 0 (-) n=9 | 9 | 0 (-) n=9 | 9 |
| goblin_chief | miniboss | 4 | 25 (100) | 30 | 0 (0) | 27 |
|  |  | 5 | 5 (100) | 38 | 0 (0) | 37 |
|  |  | 6 | 5 (100) | 38 | 0 (0) | 38 |
| goblin_warrior | battle/danger | 4 | 40 (100) | 24 | 33 (100) | 27 |
|  |  | 5 | 13 (100) | 35 | 15 (100) | 34 |
|  |  | 6 | 12 (100) n=25 | 22 | 8 (67) n=24 | 21 |
| dire_wolf | battle/danger | 4 | 35 (100) | 26 | 20 (73) | 29 |
|  |  | 5 | 15 (100) | 34 | 5 (50) | 36 |
|  |  | 6 | 5 (100) | 38 | 3 (25) | 36 |
| goblin_shaman | miniboss | 4 | 25 (100) | 30 | 13 (38) | 27 |
|  |  | 5 | 13 (83) | 34 | 0 (0) | 35 |
|  |  | 6 | 0 (-) n=11 | 11 | 0 (-) n=11 | 11 |
| wolf_alpha | miniboss | 4 | 28 (100) | 29 | 0 (0) | 30 |
|  |  | 5 | 8 (100) | 37 | 0 (0) | 37 |
|  |  | 6 | 0 (-) | 40 | 0 (0) | 39 |
| goblin_archer | battle/danger | 4 | 35 (100) | 26 | 35 (100) | 26 |
|  |  | 5 | 20 (100) | 32 | 8 (38) | 32 |
|  |  | 6 | 5 (100) | 38 | 5 (67) | 37 |
| goblin_brute | battle/danger | 4 | 28 (100) | 29 | 10 (40) | 30 |
|  |  | 5 | 20 (100) | 32 | 0 (0) n=33 | 28 |
|  |  | 6 | 5 (100) | 38 | 0 (0) | 39 |
| goblin_warlock | boss | 4 | 13 (100) | 35 | 0 (0) | 31 |
|  |  | 5 | 23 (100) | 31 | 5 (20) | 30 |
|  |  | 6 | 30 (100) | 28 | 5 (18) | 29 |
| forest_witch | boss | 4 | 0 (-) | 40 | 0 (-) | 40 |
|  |  | 5 | 0 (-) | 40 | 0 (-) | 40 |
|  |  | 6 | 0 (-) | 40 | 0 (-) | 40 |

## 3. Overall — pooled hit % of casts (hits / casts over the group)

| group | N | counter ON | counter OFF | counter rune-boss ON | counter rune-boss OFF | piece (ON) | piece_strike (ON) | counter ON, % of resolved | counter OFF, % of resolved |
|---|---|---|---|---|---|---|---|---|---|
| battle/danger | 1 | 92 | 37 | 100 | 41 | 57 | 100 | 100 | 41 |
|  | 2 | 92 | 42 | 100 | 48 | 48 | 88 | 100 | 47 |
|  | 3 | 70 | 50 | 75 | 59 | 49 | 62 | 100 | 72 |
|  | 4 | 41 | 35 | 65 | 56 | 51 | 81 | 100 | 85 |
|  | 5 | 17 | 11 | 48 | 30 | 27 | 52 | 95 | 55 |
| miniboss | 1 | 88 | 28 | 100 | 21 | 41 | 92 | 100 | 33 |
|  | 2 | 91 | 15 | 100 | 34 | 29 | 21 | 100 | 17 |
|  | 3 | 65 | 18 | 58 | 22 | 23 | 37 | 98 | 30 |
|  | 4 | 22 | 7 | 61 | 1 | 10 | 35 | 93 | 22 |
|  | 5 | 12 | 0 | 31 | 3 | 6 | 7 | 82 | 0 |
| boss | 1 | 78 | 14 | 100 | 6 | 30 | 56 | 100 | 16 |
|  | 2 | 66 | 28 | 90 | 48 | 29 | 22 | 100 | 42 |
|  | 3 | 14 | 2 | 74 | 9 | 9 | 30 | 100 | 17 |
|  | 4 | 12 | 0 | 56 | 9 | 15 | 20 | 100 | 0 |
|  | 5 | 5 | 0 | 39 | 6 | 4 | 22 | 18 | 0 |
| miniboss + boss | 1 | 84 | 22 | 100 | 15 | 36 | 78 | 100 | 26 |
|  | 2 | 81 | 20 | 96 | 40 | 29 | 22 | 100 | 25 |
|  | 3 | 44 | 12 | 64 | 16 | 18 | 34 | 98 | 28 |
|  | 4 | 18 | 4 | 59 | 4 | 12 | 29 | 95 | 17 |
|  | 5 | 9 | 0 | 34 | 4 | 5 | 13 | 46 | 0 |
| all 11 | 1 | 88 | 30 | 100 | 29 | 48 | 90 | 100 | 34 |
|  | 2 | 87 | 32 | 98 | 44 | 40 | 58 | 100 | 38 |
|  | 3 | 58 | 32 | 70 | 40 | 35 | 50 | 99 | 57 |
|  | 4 | 31 | 21 | 62 | 32 | 33 | 58 | 99 | 63 |
|  | 5 | 13 | 6 | 42 | 19 | 17 | 34 | 70 | 34 |

| group | N (pair) | counter_pair ON | counter_pair OFF | ON, % of resolved | OFF, % of resolved |
|---|---|---|---|---|---|
| battle/danger | 4 | 37 | 28 | 100 | 85 |
|  | 5 | 20 | 13 | 100 | 66 |
|  | 6 | 9 | 5 | 100 | 47 |
| miniboss | 4 | 26 | 4 | 100 | 14 |
|  | 5 | 8 | 0 | 91 | 0 |
|  | 6 | 2 | 0 | 100 | 0 |
| boss | 4 | 6 | 0 | 100 | 0 |
|  | 5 | 11 | 2 | 100 | 20 |
|  | 6 | 15 | 2 | 100 | 18 |
| miniboss + boss | 4 | 18 | 2 | 100 | 11 |
|  | 5 | 10 | 1 | 95 | 10 |
|  | 6 | 8 | 1 | 100 | 14 |
| all 11 | 4 | 28 | 17 | 100 | 58 |
|  | 5 | 15 | 8 | 99 | 49 |
|  | 6 | 8 | 3 | 100 | 33 |

## 4. Boss danger — player stands still and never casts (3 seeds x 600 s per enemy)

swings/min = boss swings started per minute; hits/min = boss swings that hit the player per minute; dmg/min = swing damage per minute (no trait damage occurred); windup = mean boss swing duration (s).

| enemy | role | rune ON: swings/min | hits/min | dmg/min | windup | pieces ON: swings/min | hits/min | dmg/min | windup | rune OFF: hits/min | pieces OFF: hits/min |
|---|---|---|---|---|---|---|---|---|---|---|---|
| goblin_scout | battle | 8.0 | 6.7 | 160 | 1.90 | 4.1 | 4.1 | 53 | 1.47 | 7.1 | 4.0 |
| wolf | battle/danger | 13.1 | 9.1 | 103 | 1.28 | 10.4 | 10.2 | 104 | 1.24 | 9.9 | 8.5 |
| goblin_chief | miniboss | 17.4 | 11.7 | 142 | 1.12 | 13.6 | 13.4 | 161 | 1.05 | 12.8 | 13.4 |
| goblin_warrior | battle/danger | 11.3 | 7.1 | 94 | 1.41 | 9.5 | 9.4 | 103 | 1.23 | 7.1 | 8.3 |
| dire_wolf | battle/danger | 12.6 | 7.3 | 90 | 1.41 | 4.8 | 4.7 | 50 | 1.18 | 8.0 | 2.9 |
| goblin_shaman | miniboss | 15.2 | 8.5 | 96 | 1.34 | 8.9 | 8.9 | 93 | 1.18 | 9.6 | 7.6 |
| wolf_alpha | miniboss | 17.1 | 9.2 | 114 | 1.27 | 12.9 | 12.6 | 136 | 1.10 | 9.1 | 13.0 |
| goblin_archer | battle/danger | 10.1 | 5.9 | 69 | 1.37 | 10.2 | 9.6 | 105 | 1.28 | 7.6 | 8.9 |
| goblin_brute | battle/danger | 15.0 | 11.6 | 125 | 1.22 | 5.7 | 5.6 | 56 | 1.14 | 11.6 | 6.3 |
| goblin_warlock | boss | 16.9 | 9.8 | 111 | 1.02 | 16.3 | 13.8 | 170 | 0.89 | 10.6 | 14.2 |
| forest_witch | boss | 29.7 | 9.4 | 120 | 0.89 | 17.1 | 17.1 | 202 | 0.78 | 9.8 | 17.0 |
| **battle/danger** | | 11.7 | 7.9 | 107 | 1.39 | 7.4 | 7.3 | 78 | 1.25 | 8.6 | 6.5 |
| **miniboss** | | 16.6 | 9.8 | 117 | 1.24 | 11.8 | 11.6 | 130 | 1.10 | 10.5 | 11.3 |
| **boss** | | 23.3 | 9.6 | 116 | 0.94 | 16.7 | 15.4 | 186 | 0.83 | 10.2 | 15.6 |
| **miniboss + boss** | | 19.3 | 9.7 | 117 | 1.09 | 13.8 | 13.2 | 152 | 0.97 | 10.4 | 13.0 |
| **all 11** | | 15.1 | 8.8 | 111 | 1.22 | 10.3 | 10.0 | 112 | 1.08 | 9.4 | 9.5 |

## Conclusion

**1. Rooting the boss works.** With root ON, a counter that resolves lands about 95–100 % of the time on every enemy (bracketed values), so the boss can no longer step out of it. With root OFF, the same counters land on only 26 % of resolved casts against minibosses and bosses at 1 cell, and 0–17 % at 4–5 cells.

**2. Minibosses and bosses become hittable with small pieces, but not with large ones.** Pooled hit % of casts for the 3 minibosses and 2 bosses, piece-boss, single piece:

| N | counter, root ON | counter, root OFF | `piece` (no counter, root ON) |
|---|---|---|---|
| 1 | 84 | 22 | 36 |
| 2 | 81 | 20 | 29 |
| 3 | 44 | 12 | 18 |
| 4 | 18 | 4 | 12 |
| 5 | 9 | 0 | 5 |

- **Against the ~50–70 % target:**
  - 1–2-cell counters overshoot the target, at 81–84 %.
  - 3-cell counters fall just short, at 44 %.
  - 4–5-cell counters stay at 9–18 %.
  - Weighted by the bot's cast-size mix (2/3/4/5 cells at 20/35/30/15 %), the minibosses and bosses come out at about **39 %** with root ON, against about **9 %** with root OFF.
  - On the two bosses alone, 3+ cells drop to 5–14 %.
  - Two-piece unions of 4–6 cells reach only 8–18 % against minibosses and bosses.
- **What causes the misses with root ON.** It is the windup race, not the boss escaping:
  - Almost every miss is in the "cut by boss" column: the boss's swing lands on the still-winding player first.
  - The piece-boss's mean swing lasts 0.97 s on minibosses and bosses, about the same as a 3-cell windup (0.95 s). On the two bosses it lasts 0.83 s, which is shorter than a 3-cell windup.
  - So a counter only fits if its windup is shorter than what is left of the boss's swing.
- **Rune-boss comparison.** A counter against the *rune*-boss with root ON does better at every size (minibosses and bosses: 100 / 96 / 64 / 59 / 34 %), because the rune-boss swings last longer (mean 1.09 s).
- **Not modelled:** a real player could step out of the target while winding up. This probe does not model that, so 3+-cell counter values are a lower bound for a player who dodges and counters at the same time, if the game allows that.

**3. The piece-boss is more dangerous than the rune-boss against minibosses and bosses, and slightly less dangerous against ordinary enemies.** Player standing still, root ON:

- **Swing accuracy:** the piece-boss swings less often (10.3 vs 15.1 swings/min overall) but hits a standing player with **97 %** of its swings, against **58 %** for the rune-boss.
- **All 11 enemies:** both bosses land about the same per minute: 10.0 vs 8.8 hits/min and 112 vs 111 dmg/min.
- **Minibosses and bosses:** the piece-boss is clearly harsher, at **13.2 vs 9.7 hits/min (+36 %)** and **152 vs 117 dmg/min (+31 %)**. The two bosses alone reach **186 vs 116 dmg/min (+61 %)**.
- **Battle and danger enemies:** the piece-boss is softer, at 7.3 vs 7.9 hits/min and **78 vs 107 dmg/min (−27 %)**. Goblin scout, dire wolf and goblin brute swing only 4–6 times per minute as piece-bosses, against 8–15 as rune-bosses. This was not diagnosed. It is probably the supply of piece drops or the piece-mode candidates on those arenas.
- **Root ON vs OFF** barely changes boss danger (all 11: 9.5 vs 10.0 hits/min for the piece-boss).
- **Caveat:** a player who stands still is the piece-boss's best case, because it places a piece directly over the player's cell. Against a player who moves, its 97 % accuracy will fall. The rune-boss baseline has the same stand-still bias.
