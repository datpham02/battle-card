## 1. Character x seed set: run win % (B1 -> E, diff)

| character | set 2001 | set 3001 | mean B1 | mean E | diff |
|---|---|---|---|---|---|
| kiem_si | 24.3 -> 18.6 (-5.7) | 12.9 -> 25.7 (12.8) | 18.6 | 22.1 | 3.5 |
| phap_su | 14.3 -> 2.9 (-11.4) | 18.6 -> 5.7 (-12.9) | 16.5 | 4.3 | -12.2 |
| sat_thu | 8.6 -> 10.0 (1.4) | 7.1 -> 18.6 (11.5) | 7.8 | 14.3 | 6.5 |
| tho_san | 11.4 -> 11.4 (0.0) | 7.1 -> 14.3 (7.2) | 9.2 | 12.9 | 3.6 |
| giao_si | 11.4 -> 12.9 (1.5) | 17.1 -> 11.4 (-5.7) | 14.2 | 12.2 | -2.1 |
| **pooled (10 combos, 700 runs each)** | 14.0 -> 11.2 | 12.6 -> 15.1 | **13.3** | **13.2** | **-0.1** |

## 2. Run-level metrics, pooled over the 10 combos (mean of per-combo values)

| metric | B1 | E | diff | diff % |
|---|---|---|---|---|
| run win % | 13.3 | 13.2 | -0.1 | -1.0 % |
| hellfire clear % (of runs entering floor 2) | 84.6 | 90.1 | 5.6 | +6.6 % |
| floor 2 clear % of runs entering (WORLD FLOORS) | 84.6 | 90.1 | 5.6 | +6.6 % |
| hellfire match win % | 96.6 | 97.8 | 1.2 | +1.3 % |
| est. minutes, all runs | 32.77 | 31.34 | -1.43 | -4.4 % |
| est. minutes, won runs (mean) | 49.12 | 46.35 | -2.77 | -5.6 % |
| run minutes, won median | 51.50 | 48.62 | -2.88 | -5.6 % |
| run minutes, lost median | 30.40 | 28.87 | -1.53 | -5.0 % |
| hits taken / run (all) | 31.73 | 28.39 | -3.34 | -10.5 % |
| hits taken / won run | 44.33 | 39.15 | -5.18 | -11.7 % |
| matches / run | 19.96 | 20.42 | 0.46 | +2.3 % |
| gold earned / run (all) | 615.9 | 629.5 | 13.6 | +2.2 % |
| gold spent / run (all) | 332.2 | 344.3 | 12.1 | +3.6 % |
| gold earned / won run | 1023.6 | 1026.1 | 2.5 | +0.2 % |
| relics / run | 10.54 | 10.81 | 0.27 | +2.6 % |
| deck size | 11.36 | 11.48 | 0.13 | +1.1 % |
| HP % entering floor 2 | 99.4 | 98.7 | -0.7 | -0.7 % |
| HP % after the hellfire warden (before heal) | 49.7 | 58.7 | 9.0 | +18.0 % |
| hellfire: HP lost in fights per route (pts) | 63.4 | 48.8 | -14.6 | -23.0 % |
| hellfire: net HP lost per route (pts) | 42.9 | 31.8 | -11.1 | -25.8 % |
| ROUTE gold (drops, mean of runs by hellfire lane taken; whole-run figure in full runs) | 476.1 | 498.0 | 21.9 | +4.6 % |
| ROUTE relics (mean of runs by lane taken) | 2.51 | 2.51 | -0.01 | -0.3 % |
| hellfire: objective met per route | 0.17 | 0.18 | 0.01 | +4.7 % |
| ROUTE NV = gold + 60 relics - 1.6 HP (same caveat; compare B1 vs E only) | 558.2 | 597.5 | 39.2 | +7.0 % |
| hellfire: heat at warden (mean) | 1.48 | 1.48 | 0.00 | +0.1 % |
| hellfire: warden reached at heat 3-4 % | 27.8 | 27.3 | -0.5 | -1.9 % |

## 3. Per character (both sets pooled): win % / hellfire clear % / minutes all runs / gold earned / relics / hellfire HP in fights / heat 3-4 at warden %

| character | B1 | E | diff (win / hell / min / gold / relics / HP / heat34) |
|---|---|---|---|
| kiem_si | 18.6 / 96.4 / 38.05 / 726.0 / 12.03 / 55.7 / 28.3 | 22.1 / 92.8 / 36.25 / 726.5 / 11.95 / 52.6 / 28.1 | 3.5 / -3.6 / -1.80 / 0.5 / -0.08 / -3.1 / -0.1 |
| phap_su | 16.5 / 88.6 / 32.75 / 659.0 / 10.62 / 57.7 / 27.5 | 4.3 / 82.8 / 25.40 / 534.0 / 9.18 / 55.5 / 25.8 | -12.2 / -5.8 / -7.35 / -125.0 / -1.45 / -2.2 / -1.7 |
| sat_thu | 7.8 / 72.8 / 27.85 / 527.0 / 9.46 / 68.6 / 26.2 | 14.3 / 91.5 / 29.80 / 616.0 / 10.75 / 44.4 / 28.3 | 6.5 / 18.6 / 1.95 / 89.0 / 1.29 / -24.3 / 2.1 |
| tho_san | 9.2 / 82.8 / 31.05 / 559.5 / 10.00 / 67.2 / 27.5 | 12.9 / 92.9 / 31.95 / 625.5 / 11.02 / 47.5 / 27.1 | 3.6 / 10.1 / 0.90 / 66.0 / 1.02 / -19.7 / -0.4 |
| giao_si | 14.2 / 82.2 / 34.15 / 608.0 / 10.57 / 67.9 / 29.9 | 12.2 / 90.7 / 33.30 / 645.5 / 11.13 / 44.3 / 27.3 | -2.1 / 8.5 / -0.85 / 37.5 / 0.56 / -23.6 / -2.6 |

## 4. Hellfire clear % per character x set (B1 -> E), deaths on floor 2 of 70

| character | set 2001 | set 3001 |
|---|---|---|
| kiem_si | 95.7 -> 90.0 (deaths 3 -> 7) | 97.1 -> 95.7 (deaths 2 -> 3) |
| phap_su | 88.6 -> 81.4 (deaths 8 -> 13) | 88.6 -> 84.1 (deaths 8 -> 11) |
| sat_thu | 71.4 -> 90.0 (deaths 20 -> 7) | 74.3 -> 92.9 (deaths 18 -> 5) |
| tho_san | 81.4 -> 92.9 (deaths 13 -> 5) | 84.3 -> 92.9 (deaths 11 -> 5) |
| giao_si | 80.0 -> 87.1 (deaths 14 -> 9) | 84.3 -> 94.3 (deaths 11 -> 4) |

## 5. Warden arrival heat distribution (hellfire, value policy; all characters and sets pooled)

| variant | wardens reached | heat 0 | heat 1 | heat 2 | heat 3 | heat 4 | heat 3-4 % | mean heat |
|---|---|---|---|---|---|---|---|---|
| B1 | 664 | 232 (34.9 %) | 148 (22.3 %) | 99 (14.9 %) | 102 (15.4 %) | 83 (12.5 %) | 27.9 | 1.48 |
| E | 666 | 230 (34.5 %) | 147 (22.1 %) | 107 (16.1 %) | 101 (15.2 %) | 81 (12.2 %) | 27.3 | 1.48 |

## 6. Hellfire lanes taken on `value` (pooled over characters and sets, weighted by runs): clear % / gold / net HP / relics / objective / run win %

| lane | B1 runs | B1 | E runs | E |
|---|---|---|---|---|
| safe | 7 | 100.0 / 597.9 / 10.0 / 1.14 / 0.00 / 28.6 (HP in fights 48.6) | 27 | 70.4 / 308.9 / 0.4 / 1.26 / 0.00 / 3.7 (HP in fights 41.7) |
| treasure | 36 | 97.2 / 547.6 / 36.4 / 1.83 / 0.00 / 19.4 (HP in fights 48.5) | 40 | 82.5 / 414.8 / 20.8 / 1.65 / 0.00 / 10.0 (HP in fights 42.6) |
| peril | 476 | 81.5 / 453.6 / 43.9 / 2.73 / 0.25 / 11.1 (HP in fights 66.8) | 461 | 90.7 / 521.5 / 34.3 / 2.78 / 0.27 / 13.9 (HP in fights 51.1) |
| elite | 181 | 89.5 / 516.2 / 42.7 / 2.13 / 0.00 / 17.1 (HP in fights 58.0) | 171 | 93.6 / 484.6 / 32.5 / 2.18 / 0.00 / 13.5 (HP in fights 45.3) |
| mystery | 0 | - | 0 | - |

## 7. Files

- set 2001 kiem_si: B1 `b1-balance/B1-s2001-full-value-kiem_si.txt` (ok), E2 `group-e2/E2-s2001-kiem_si.txt` (ok)
- set 2001 phap_su: B1 `b1-balance/B1-s2001-full-value-phap_su.txt` (ok), E2 `group-e2/E2-s2001-phap_su.txt` (ok)
- set 2001 sat_thu: B1 `b1-balance/B1-s2001-full-value-sat_thu.txt` (ok), E2 `group-e2/E2-s2001-sat_thu.txt` (ok)
- set 2001 tho_san: B1 `b1-balance/B1-s2001-full-value-tho_san.txt` (ok), E2 `group-e2/E2-s2001-tho_san.txt` (ok)
- set 2001 giao_si: B1 `b1-balance/B1-s2001-full-value-giao_si.txt` (ok), E2 `group-e2/E2-s2001-giao_si.txt` (ok)
- set 3001 kiem_si: B1 `b1-balance/B1-s3001-full-value-kiem_si.txt` (ok), E2 `group-e2/E2-s3001-kiem_si.txt` (ok)
- set 3001 phap_su: B1 `b1-balance/B1-s3001-full-value-phap_su.txt` (ok), E2 `group-e2/E2-s3001-phap_su.txt` (ok)
- set 3001 sat_thu: B1 `b1-balance/B1-s3001-full-value-sat_thu.txt` (ok), E2 `group-e2/E2-s3001-sat_thu.txt` (ok)
- set 3001 tho_san: B1 `b1-balance/B1-s3001-full-value-tho_san.txt` (ok), E2 `group-e2/E2-s3001-tho_san.txt` (ok)
- set 3001 giao_si: B1 `b1-balance/B1-s3001-full-value-giao_si.txt` (ok), E2 `group-e2/E2-s3001-giao_si.txt` (ok)
