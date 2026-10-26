# Tech-debt pass 2-3 (2026-10-26) — balance simulation

Tool: `tools/balance/deck_sim.gd --world --seeds=70` (build policy, shops greedy, events risky, bot dodge 0.85 = TD-006
default). Raw output: `simulation-td-raw.txt` (sections `===== <run>`). A 70-seed cell has about +-7 points of noise, the
three-character mean about +-4. Run win is Kiem si / Phap su / Sat thu.

## Changes measured

- `huyet_an` (TD-028): the 2 HP are lost only when a cast of 5+ cells misses (was: every such cast).
- Shop before the final match (TD-029): `chapters.json` `world.final_prelude` = `[["shop"]]`.
- Single-cell / bar2 weights (TD-030): measured with the new `--piece-weight-set` flag, NOT shipped (see below).
- Sat thu (TD-027): `quick_blade` `max_cells` 3 -> 4 (shipped).

## 1. Data after huyet_an + final shop (before the Sat thu change)

| Run | Run win | Mean |
|---|---|---|
| base | 20.0 / 15.7 / 4.3 | 13.3 |
| always own `huyet_an` | 20.0 / 21.4 / 8.6 | 16.7 (+3.4: no longer a trap; it was -17.6) |
| remove `mono` from the piece deck | 25.7 / 24.3 / 10.0 | 20.0 (+6.7: below the +10 dominance threshold; it was +12.8) |

## 2. Lowering small-shape weights (TD-030 option chosen first by the user) — not shipped

| Weights | Run win (mean) | Gain from removing mono |
|---|---|---|
| shipped | 13.3 | +6.7 |
| mono x0.5, bar2 x0.5 | 13.4 | +6.1 |
| mono x0.25, bar2 x0.25 | 10.5 | +2.3 |
| mono x0.5 | 12.4 | +5.2 |
| mono x0.25 | 12.4 | — |

Lower small-shape weights do not make runs easier (Kiem si falls from 20 to 10-13 %); `bar2` carries value (joins). The
removal gain is already below the threshold, so the weights stay as shipped (user decision 2026-10-26).

## 3. Sat thu variants (70 seeds, Sat thu only; base 4.3 % run win, 9 % reach the final)

| Variant | Run win | Reach the final |
|---|---|---|
| max HP 180 -> 200 | 11.4 | 19 % |
| quick_blade x1.25 -> x1.4 | 11.4 | 17 % |
| **quick_blade up to 4 cells (shipped)** | **15.7** | **30 %** |
| Anh Bo cooldown 12 -> 9 s | 4.3 | 9 % |
| HP 200 + quick_blade 4 cells | 21.4 | 36 % |

## 4. Confirmation with every shipped change

| | Kiem si | Phap su | Sat thu |
|---|---|---|---|
| run win | 20.0 | 15.7 | 15.7 |
| reach the final (wins + final deaths) / 70 | 23 (33 %) | 18 (26 %) | 21 (30 %) |
| gold left in won runs < 100 (TD-029 target) | PASS | PASS | PASS |
| `--fate=execute`: run win; final reached / won | 21.4; 21 / 15 | 25.7; 21 / 18 | 15.7; 14 / 11 |
| `--fate=spare`: run win; final reached / won | 22.9; 22 / 16 | 14.3; 19 / 10 | 11.4; 13 / 8 |

- Execute now beats spare by +4.7 points on the mean (was 1.4-5.7 points worse); the Story 035 target is 8-20.
- Final-match win when reached is now 53-86 % (target 35-55 %): spending the floor-5 gold at the new shop makes the final
  easier; left to Story 040 after the gate 8 playtest.
- The region spread at a floor is still 30-45 points (target <= 15, TD-027) and won runs are 25-30 minutes (target 40-50).
