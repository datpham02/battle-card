# Story 024 — hit rates with real pieces (chapter 1, 40 casts per cell)

Measured 2026-10-24 with `hit_probe.gd` (scratch copy of `deck_sim.gd`, real CombatState / BossBrain / CutActor logic, headless, dt 0.05, `--trials=40 --chapter=0`). Raw lines: `hit-rates-pieces-raw.txt`.

Player stands still and is never killed; boss HP 1e6; every cast is aimed at the boss's CURRENT cell at the instant the swing starts (best case: no drawing / dragging time), card *Kiếm khí*, windup by cell count as in v4. Value = hit % of resolved casts.

- **naive / blob / strike** = the rune-era measurement (arbitrary connected clusters): naive = random connected shape containing the boss cell; blob = boss cell + its neighbours first; strike = blob cast the instant the boss has just stepped (falls back after 3 s). These columns reproduce the 2026-10-24 rune table (same probe code, re-run in the same session as the piece columns).
- **piece** = only shapes from `pieces.json` with exactly N cells, any rotation, valid anchors (`PiecePlacement.valid_anchors`), choosing the placement that covers the boss cell and the most of its orthogonal neighbours (ties random, seeded).
- **piece_strike** = piece, cast right after the boss steps (like strike).
- `*` = some casts had no pieces.json shape of that size able to cover the boss cell on that arena; they count as misses.
- Caveat on the rune columns: the probe let a 1-cell rune cut land on ANY cell, but the real rune game could not place a 1-cell cut on the centre cell (no perimeter label there). The piece columns have no such limit — a mono piece goes anywhere.

| enemy | role | arena | react / think / step cd (s) | N | naive | blob | strike | piece | piece_strike |
|---|---|---|---|---|---|---|---|---|---|
| goblin_scout | battle | square | 0.60 / 0.50 / 0.80 | 1 | 63 | 47 | 100 | 62 | 100 |
| | | | | 2 | 53 | 66 | 100 | 49 | 100 |
| | | | | 3 | 29 | 62 | 100 | 68 | 97 |
| | | | | 4 | 47 | 82 | 82 | 80 | 84 |
| | | | | 5 | 54 | 68 | 100 | 32 | 45 |
| wolf | battle/danger | square | 0.45 / 0.40 / 0.65 | 1 | 46 | 56 | 100 | 59 | 100 |
| | | | | 2 | 33 | 47 | 100 | 44 | 100 |
| | | | | 3 | 36 | 43 | 33 | 54 | 28 |
| | | | | 4 | 48 | 58 | 82 | 72 | 76 |
| | | | | 5 | 52 | 54 | 100 | 31 | 60 |
| goblin_chief | miniboss | square | 0.35 / 0.30 / 0.55 | 1 | 13 | 11 | 87 | 18 | 88 |
| | | | | 2 | 9 | 3 | 0 | 15 | 0 |
| | | | | 3 | 6 | 10 | 46 | 29 | 39 |
| | | | | 4 | 0 | 7 | 17 | 0 | 3 |
| | | | | 5 | 0 | 12 | 0 | 0 | 3 |
| goblin_warrior | battle/danger | rect | 0.60 / 0.50 / 0.80 | 1 | 59 | 54 | 100 | 64 | 100 |
| | | | | 2 | 59 | 50 | 100 | 58 | 100 |
| | | | | 3 | 49 | 58 | 94 | 72 | 97 |
| | | | | 4 | 29 | 62 | 76 | 76 | 82 |
| | | | | 5 | 25 | 77 | 100 | 43 | 30 |
| dire_wolf | battle/danger | rect | 0.45 / 0.40 / 0.65 | 1 | 55 | 50 | 100 | 37 | 100 |
| | | | | 2 | 47 | 29 | 100 | 24 | 100 |
| | | | | 3 | 14 | 46 | 17 | 38 | 16 |
| | | | | 4 | 44 | 49 | 87 | 51 | 85 |
| | | | | 5 | 6 | 55 | 100 | 24 | 54 |
| goblin_shaman | miniboss | rect | 0.40 / 0.35 / 0.59 | 1 | 24 | 28 | 100 | 43 | 100 |
| | | | | 2 | 29 | 16 | 0 | 16 | 0 |
| | | | | 3 | 12 | 34 | 15 | 18 | 22 |
| | | | | 4 | 9 | 24 | 83 | 23 | 91 |
| | | | | 5 | 0 | 0 | 0 | 3 | 0 |
| wolf_alpha | miniboss | rect | 0.35 / 0.30 / 0.55 | 1 | 19 | 14 | 76 | 14 | 85 |
| | | | | 2 | 19 | 14 | 0 | 11 | 0 |
| | | | | 3 | 9 | 16 | 32 | 3 | 6 |
| | | | | 4 | 3 | 0 | 9 | 0 | 0 |
| | | | | 5 | 3 | 0 | 3 | 3 | 0 |
| goblin_archer | battle/danger | cross | 0.45 / 0.40 / 0.65 | 1 | 51 | 34 | 100 | 44 | 100 |
| | | | | 2 | 46 | 46 | 100 | 57 | 100 |
| | | | | 3 | 44 | 67 | 71 | 72 | 78 |
| | | | | 4 | 41 | 71 | 86 | 67 | 89 |
| | | | | 5 | 46 | 64 | 100 | 55* | 76* |
| goblin_brute | battle/danger | u_shape | 0.40 / 0.35 / 0.59 | 1 | 39 | 33 | 100 | 27 | 100 |
| | | | | 2 | 11 | 21 | 0 | 25 | 0 |
| | | | | 3 | 18 | 35 | 26 | 31 | 36 |
| | | | | 4 | 18 | 26 | 91 | 26 | 87 |
| | | | | 5 | 8 | 20 | 3 | 4 | 3 |
| goblin_warlock | boss | staircase | 0.35 / 0.30 / 0.55 | 1 | 21 | 21 | 95 | 26 | 92 |
| | | | | 2 | 22 | 26 | 24 | 15 | 22 |
| | | | | 3 | 15 | 25 | 20 | 15 | 27 |
| | | | | 4 | 28 | 19 | 17 | 23 | 17 |
| | | | | 5 | 21 | 14 | 8 | 0* | 0* |
| forest_witch | boss | cross | 0.30 / 0.25 / 0.50 | 1 | 3 | 3 | 3 | 5 | 3 |
| | | | | 2 | 3 | 6 | 22 | 14 | 12 |
| | | | | 3 | 3 | 9 | 29 | 18 | 35 |
| | | | | 4 | 6 | 9 | 34 | 18 | 24 |
| | | | | 5 | 10 | 19 | 31 | 19 | 38 |

## Findings

- **Bosses, piece vs rune (mean over N = 1–5, aimed / strike):** goblin_warlock piece 16 / piece_strike 32 vs rune blob 21 / strike 33; forest_witch piece 15 / piece_strike 22 vs rune blob 9 / strike 24. Real pieces are about as hittable as the rune-era best-case clusters — the piece change makes aiming easier (one drag instead of perimeter labels) but does not, by itself, make bosses easier to hit.
- **1–4 cells: piece ≈ blob or better.** Means over the 11 enemies: N=3 piece 38 vs blob 37, N=4 piece 40 vs blob 37; with strike timing piece_strike ≈ strike at every N ≤ 4. A mono piece can now really be placed on the centre cell, which the rune game could not do, so the N=1 rune numbers were optimistic and the piece N=1 numbers are the first honest ones.
- **5 cells is the weak size: piece 19 vs blob 35 (piece_strike 28 vs strike 50).** Only plus5, u5 and bar5 have 5 cells and they are rigid: on 3x3 a plus5 fits only at the centre, bar5 never fits, so a 5-cell placement around an edge or corner boss leaves its escape cells open. On the goblin_warlock staircase arena no 5-cell shape could cover the boss cell in 13 / 40 (piece) and 8 / 40 (piece_strike) casts (`*`), and the casts that did place hit 0 %.
- **Balance consequence (for Story 026, not changed here):** after Part C eight cards need 5 cells (dai_dao, hoa_tran, thien_lang, han_tran, song_kiem, han_bang, thien_hoa, tu_kiem). With real pieces those are the LEAST reliable casts — the opposite of the "big cut = big payoff" intent. Since 5 is the largest piece, every one of these casts needs a plus5 / u5 / bar5. Options: add more compact 5-cell shapes (e.g. a P-pentomino, which fits a 3x3 half in many places) to pieces.json, or lower some of these cards to 4.
- Minibosses stay hard either way (goblin_chief, wolf_alpha ≤ 30 % even with strike timing): their reaction / think / step cooldown, not the cast shape, dominates.

## Averages over N = 1–5 (hit %)

| enemy | role | naive | blob | strike | piece | piece_strike |
|---|---|---|---|---|---|---|
| goblin_scout | battle | 49 | 65 | 96 | 58 | 85 |
| wolf | battle/danger | 43 | 52 | 83 | 52 | 73 |
| goblin_chief | miniboss | 6 | 9 | 30 | 12 | 27 |
| goblin_warrior | battle/danger | 44 | 60 | 94 | 63 | 82 |
| dire_wolf | battle/danger | 33 | 46 | 81 | 35 | 71 |
| goblin_shaman | miniboss | 15 | 20 | 40 | 21 | 43 |
| wolf_alpha | miniboss | 11 | 9 | 24 | 6 | 18 |
| goblin_archer | battle/danger | 46 | 56 | 91 | 59 | 89 |
| goblin_brute | battle/danger | 19 | 27 | 44 | 23 | 45 |
| goblin_warlock | boss | 21 | 21 | 33 | 16 | 32 |
| forest_witch | boss | 5 | 9 | 24 | 15 | 22 |

## By size, mean over the 11 enemies (hit %)

| N | naive | blob | strike | piece | piece_strike |
|---|---|---|---|---|---|
| 1 | 36 | 32 | 87 | 36 | 88 |
| 2 | 30 | 29 | 50 | 30 | 49 |
| 3 | 21 | 37 | 44 | 38 | 44 |
| 4 | 25 | 37 | 60 | 40 | 58 |
| 5 | 20 | 35 | 50 | 19 | 28 |
