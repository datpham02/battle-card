# Story 028 — hit rates of 2-piece (joined) casts, chapter 1

Measured 2026-10-25 with `hit_probe.gd` (scratch copy of `deck_sim.gd`; real CombatState / BossBrain / CutActor logic, headless, dt 0.05, `--trials=40 --chapter=0`). Raw lines: `hit-rates-join-raw.txt`. Same method as the Story 024 table (`../player-pieces/hit-rates-pieces.md`): the player stands still and is never killed, boss HP 1e6, every cast aimed at the boss's CURRENT cell at the instant the swing starts (best case: no drag / menu time), card *Kiếm khí*, windup by total cell count. Value = hit % of resolved casts.

- **piece / piece_strike** = one `pieces.json` shape of exactly N cells (Story 024 modes, re-run in this session; `024` columns = the published Story 024 numbers).
- **pair** = two `pieces.json` shapes, any rotations, valid anchors, no shared cell (adjacency not required), union of exactly N cells covering the boss cell; the placement covering the most orthogonal neighbours of the boss cell is chosen (ties random, seeded). **pair_strike** = pair, cast right after the boss steps (falls back after 3 s).
- **blob / strike** = arbitrary connected cluster (the rune-era ideal), for scale.
- `*` = some casts found no placement covering the boss cell (counted as misses). The probe ignores the extra time a join takes (second drag, `join_extra_sec` of menu time): in play the boss may step while the second piece is dragged, so real 2-piece numbers sit below `pair` and nearer the aimed-late case.

## By size, mean over the 11 enemies (hit %)

| N | piece (024) | piece | pair | blob | piece_strike (024) | piece_strike | pair_strike | strike |
|---|---|---|---|---|---|---|---|---|
| 4 | 40 | 60 | 60 | 58 | 58 | 71 | 66 | 67 |
| 5 | 19 | 42 | 51 | 59 | 28 | 41 | 67 | 65 |
| 6 | - | - | 45 | 51 | - | - | 55 | 68 |
| 7 | - | - | 38 | 44 | - | - | 41 | 47 |

Excluding the 3 minibosses and 2 bosses (the 6 battle/danger enemies): N=4 piece 71 / pair 69 / pair_strike 86; N=5 piece 53 / pair 64 / pair_strike 92; N=6 piece - / pair 53 / pair_strike 84; N=7 piece - / pair 48 / pair_strike 53.

## Per enemy (hit %)

| enemy | role | arena | react / think / step cd (s) | N | piece (024) | piece | pair | blob | piece_strike (024) | piece_strike | pair_strike | strike |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| goblin_scout | battle | square | 0.60 / 0.50 / 0.80 | 4 | 80 | 73 | 78 | 71 | 84 | 85 | 90 | 80 |
| | | | | 5 | 32 | 50 | 80 | 84 | 45 | 63 | 100 | 100 |
| | | | | 6 | - | - | 69 | 86 | - | - | 98 | 97 |
| | | | | 7 | - | - | 70 | 64 | - | - | 100 | 100 |
| wolf | battle/danger | square | 0.45 / 0.40 / 0.65 | 4 | 72 | 83 | 84 | 81 | 76 | 90 | 90 | 80 |
| | | | | 5 | 31 | 58 | 67 | 88 | 60 | 57 | 100 | 100 |
| | | | | 6 | - | - | 61 | 69 | - | - | 97 | 97 |
| | | | | 7 | - | - | 60 | 56 | - | - | 29 | 35 |
| goblin_chief | miniboss | square | 0.35 / 0.30 / 0.55 | 4 | 0 | 34 | 47 | 38 | 3 | 54 | 21 | 29 |
| | | | | 5 | 0 | 42 | 25 | 34 | 3 | 16 | 36 | 42 |
| | | | | 6 | - | - | 32 | 26 | - | - | 9 | 30 |
| | | | | 7 | - | - | 25 | 16 | - | - | 4 | 12 |
| goblin_warrior | battle/danger | rect | 0.60 / 0.50 / 0.80 | 4 | 76 | 86 | 74 | 85 | 82 | 83 | 83 | 85 |
| | | | | 5 | 43 | 53 | 73 | 81 | 30 | 59 | 100 | 100 |
| | | | | 6 | - | - | 73 | 75 | - | - | 100 | 100 |
| | | | | 7 | - | - | 61 | 58 | - | - | 100 | 100 |
| dire_wolf | battle/danger | rect | 0.45 / 0.40 / 0.65 | 4 | 51 | 73 | 63 | 68 | 85 | 73 | 88 | 88 |
| | | | | 5 | 24 | 55 | 69 | 72 | 54 | 46 | 100 | 100 |
| | | | | 6 | - | - | 48 | 56 | - | - | 91 | 100 |
| | | | | 7 | - | - | 28 | 52 | - | - | 36 | 27 |
| goblin_shaman | miniboss | rect | 0.40 / 0.35 / 0.59 | 4 | 23 | 62 | 67 | 54 | 91 | 90 | 78 | 78 |
| | | | | 5 | 3 | 31 | 39 | 33 | 0 | 34 | 43 | 38 |
| | | | | 6 | - | - | 55 | 47 | - | - | 3 | 35 |
| | | | | 7 | - | - | 33 | 33 | - | - | 26 | 31 |
| wolf_alpha | miniboss | rect | 0.35 / 0.30 / 0.55 | 4 | 0 | 47 | 41 | 34 | 0 | 36 | 44 | 47 |
| | | | | 5 | 3 | 25 | 32 | 42 | 0 | 26 | 40 | 36 |
| | | | | 6 | - | - | 35 | 25 | - | - | 16 | 47 |
| | | | | 7 | - | - | 12 | 21 | - | - | 34 | 36 |
| goblin_archer | battle/danger | cross | 0.45 / 0.40 / 0.65 | 4 | 67 | 69 | 69 | 63 | 89 | 78 | 80 | 85 |
| | | | | 5 | 55* | 56* | 60 | 74 | 76* | 54* | 100 | 100 |
| | | | | 6 | - | - | 36 | 55 | - | - | 88 | 100 |
| | | | | 7 | - | - | 37 | 67 | - | - | 23 | 56 |
| goblin_brute | battle/danger | u_shape | 0.40 / 0.35 / 0.59 | 4 | 26 | 42 | 45 | 48 | 87 | 78 | 83 | 78 |
| | | | | 5 | 4 | 48 | 32 | 41 | 3 | 26 | 52 | 17 |
| | | | | 6 | - | - | 33 | 40 | - | - | 30 | 16 |
| | | | | 7 | - | - | 32 | 44 | - | - | 29 | 39 |
| goblin_warlock | boss | staircase | 0.35 / 0.30 / 0.55 | 4 | 23 | 39 | 52 | 48 | 17 | 43 | 32 | 41 |
| | | | | 5 | 0* | 9* | 30 | 52 | 0* | 10* | 29 | 29 |
| | | | | 6 | - | - | 12 | 53 | - | - | 25 | 67 |
| | | | | 7 | - | - | 22 | 41 | - | - | 30 | 47 |
| forest_witch | boss | cross | 0.30 / 0.25 / 0.50 | 4 | 18 | 53 | 39 | 50 | 24 | 69 | 39 | 50 |
| | | | | 5 | 19 | 30 | 50 | 53 | 38 | 62 | 42 | 56 |
| | | | | 6 | - | - | 40 | 32 | - | - | 50 | 54 |
| | | | | 7 | - | - | 37 | 30 | - | - | 39 | 38 |

## Conclusion (TD-012)

Joining largely fixes TD-012. Compare within this session, not against the `024` columns: the single-piece and rune-cluster baselines moved up since Story 024 (same reaction / think / step-cooldown values and windups; the cause is game changes since then, not the probe), e.g. N=5 piece 19 → 42 and blob 35 → 59. Within the session, a 5-cell cast hits **51 %** aimed as a 2+3 / 1+4 join vs **42 %** for a single 5-cell piece (ideal cluster 59 %), and with strike timing **67 %** vs **41 %** (ideal 65 %). So a joined 5-cell cast is about as good as the old free-form cluster, and the `*` no-fit cases are gone: goblin_warlock on staircase goes from 9* / 10* to 30 / 29, and goblin_archer on cross from 56* / 54* to 60 / 100. At 4 cells a pair adds nothing (60 vs 60 aimed); there the single pieces were already flexible enough. 6- and 7-cell joins (45 / 55 and 38 / 41) cost hit rate, mainly from the longer windup, so they are payoff casts and not reliable ones. Two caveats: this is the best case (the probe aims at the swing's start and leaves out the second drag and `join_extra_sec` of menu time, so in play the boss can move during the join), and minibosses and bosses stay at or below 50 % at every size. Their reaction speed, not the shape, is what limits those fights. Recommendation: close TD-012 as mitigated by joining. Leave adding a compact 5-cell piece (P-pentomino) as an open option for Story 026 if playtests show joins are too slow to set up.
