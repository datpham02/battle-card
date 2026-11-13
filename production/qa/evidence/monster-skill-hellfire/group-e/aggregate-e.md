## 1. Character x seed set: run win % (B1 -> E, diff)

| character | set 2001 | set 3001 | mean B1 | mean E | diff |
|---|---|---|---|---|---|
| kiem_si | 24.3 -> 21.4 (-2.9) | 12.9 -> 24.3 (11.4) | 18.6 | 22.9 | 4.2 |
| phap_su | 14.3 -> 21.4 (7.1) | 18.6 -> 14.3 (-4.3) | 16.5 | 17.9 | 1.4 |
| sat_thu | 8.6 -> 15.7 (7.1) | 7.1 -> 21.4 (14.3) | 7.8 | 18.5 | 10.7 |
| tho_san | 11.4 -> 10.0 (-1.4) | 7.1 -> 17.1 (10.0) | 9.2 | 13.6 | 4.3 |
| giao_si | 11.4 -> 20.0 (8.6) | 17.1 -> 11.4 (-5.7) | 14.2 | 15.7 | 1.4 |
| **pooled (10 combos, 700 runs each)** | 14.0 -> 17.7 | 12.6 -> 17.7 | **13.3** | **17.7** | **4.4** |

## 2. Run-level metrics, pooled over the 10 combos (mean of per-combo values)

| metric | B1 | E | diff | diff % |
|---|---|---|---|---|
| run win % | 13.3 | 17.7 | 4.4 | +33.3 % |
| hellfire clear % (of runs entering floor 2) | 84.6 | 100.0 | 15.4 | +18.2 % |
| floor 2 clear % of runs entering (WORLD FLOORS) | 84.6 | 100.0 | 15.4 | +18.2 % |
| hellfire match win % | 96.6 | 100.0 | 3.4 | +3.5 % |
| est. minutes, all runs | 32.77 | 34.57 | 1.80 | +5.5 % |
| est. minutes, won runs (mean) | 49.12 | 47.30 | -1.82 | -3.7 % |
| run minutes, won median | 51.50 | 49.46 | -2.04 | -4.0 % |
| run minutes, lost median | 30.40 | 30.34 | -0.06 | -0.2 % |
| hits taken / run (all) | 31.73 | 31.44 | -0.29 | -0.9 % |
| hits taken / won run | 44.33 | 41.02 | -3.31 | -7.5 % |
| matches / run | 19.96 | 22.32 | 2.36 | +11.8 % |
| gold earned / run (all) | 615.9 | 702.0 | 86.1 | +14.0 % |
| gold spent / run (all) | 332.2 | 384.2 | 52.0 | +15.7 % |
| gold earned / won run | 1023.6 | 1040.9 | 17.3 | +1.7 % |
| relics / run | 10.54 | 11.85 | 1.31 | +12.5 % |
| deck size | 11.36 | 12.08 | 0.72 | +6.4 % |
| HP % entering floor 2 | 99.4 | 99.1 | -0.2 | -0.3 % |
| HP % after the hellfire warden (before heal) | 49.7 | 85.1 | 35.4 | +71.2 % |
| hellfire: HP lost in fights per route (pts) | 63.4 | 15.2 | -48.2 | -76.0 % |
| hellfire: net HP lost per route (pts) | 42.9 | 11.9 | -31.0 | -72.2 % |
| ROUTE gold (drops, mean of runs by hellfire lane taken; whole-run figure in full runs) | 476.1 | 574.8 | 98.8 | +20.7 % |
| ROUTE relics (mean of runs by lane taken) | 2.51 | 2.73 | 0.21 | +8.5 % |
| hellfire: objective met per route | 0.17 | 0.19 | 0.02 | +11.4 % |
| ROUTE NV = gold + 60 relics - 1.6 HP (same caveat; compare B1 vs E only) | 558.2 | 719.3 | 161.1 | +28.9 % |
| hellfire: heat at warden (mean) | 1.48 | 1.55 | 0.07 | +4.6 % |
| hellfire: warden reached at heat 3-4 % | 27.8 | 28.6 | 0.7 | +2.6 % |

## 3. Per character (both sets pooled): win % / hellfire clear % / minutes all runs / gold earned / relics / hellfire HP in fights / heat 3-4 at warden %

| character | B1 | E | diff (win / hell / min / gold / relics / HP / heat34) |
|---|---|---|---|
| kiem_si | 18.6 / 96.4 / 38.05 / 726.0 / 12.03 / 55.7 / 28.3 | 22.9 / 100.0 / 37.65 / 752.0 / 12.40 / 18.3 / 28.6 | 4.2 / 3.6 / -0.40 / 26.0 / 0.37 / -37.3 / 0.3 |
| phap_su | 16.5 / 88.6 / 32.75 / 659.0 / 10.62 / 57.7 / 27.5 | 17.9 / 100.0 / 33.80 / 730.0 / 11.62 / 16.2 / 28.6 | 1.4 / 11.4 / 1.05 / 71.0 / 0.99 / -41.6 / 1.1 |
| sat_thu | 7.8 / 72.8 / 27.85 / 527.0 / 9.46 / 68.6 / 26.2 | 18.5 / 100.0 / 32.30 / 674.0 / 11.70 / 14.1 / 28.6 | 10.7 / 27.2 / 4.45 / 147.0 / 2.23 / -54.5 / 2.4 |
| tho_san | 9.2 / 82.8 / 31.05 / 559.5 / 10.00 / 67.2 / 27.5 | 13.6 / 100.0 / 33.60 / 663.0 / 11.74 / 15.4 / 28.6 | 4.3 / 17.2 / 2.55 / 103.5 / 1.74 / -51.8 / 1.1 |
| giao_si | 14.2 / 82.2 / 34.15 / 608.0 / 10.57 / 67.9 / 29.9 | 15.7 / 100.0 / 35.50 / 691.0 / 11.80 / 12.0 / 28.6 | 1.4 / 17.8 / 1.35 / 83.0 / 1.23 / -55.9 / -1.3 |

## 4. Hellfire clear % per character x set (B1 -> E), deaths on floor 2 of 70

| character | set 2001 | set 3001 |
|---|---|---|
| kiem_si | 95.7 -> 100.0 (deaths 3 -> 0) | 97.1 -> 100.0 (deaths 2 -> 0) |
| phap_su | 88.6 -> 100.0 (deaths 8 -> 0) | 88.6 -> 100.0 (deaths 8 -> 0) |
| sat_thu | 71.4 -> 100.0 (deaths 20 -> 0) | 74.3 -> 100.0 (deaths 18 -> 0) |
| tho_san | 81.4 -> 100.0 (deaths 13 -> 0) | 84.3 -> 100.0 (deaths 11 -> 0) |
| giao_si | 80.0 -> 100.0 (deaths 14 -> 0) | 84.3 -> 100.0 (deaths 11 -> 0) |

## 5. Warden arrival heat distribution (hellfire, value policy; all characters and sets pooled)

| variant | wardens reached | heat 0 | heat 1 | heat 2 | heat 3 | heat 4 | heat 3-4 % | mean heat |
|---|---|---|---|---|---|---|---|---|
| B1 | 664 | 232 (34.9 %) | 148 (22.3 %) | 99 (14.9 %) | 102 (15.4 %) | 83 (12.5 %) | 27.9 | 1.48 |
| E | 700 | 235 (33.6 %) | 135 (19.3 %) | 130 (18.6 %) | 110 (15.7 %) | 90 (12.9 %) | 28.6 | 1.55 |

## 6. Hellfire lanes taken on `value` (pooled over characters and sets, weighted by runs): clear % / gold / net HP / relics / objective / run win %

| lane | B1 runs | B1 | E runs | E |
|---|---|---|---|---|
| safe | 7 | 100.0 / 597.9 / 10.0 / 1.14 / 0.00 / 28.6 (HP in fights 48.6) | 0 | - |
| treasure | 36 | 97.2 / 547.6 / 36.4 / 1.83 / 0.00 / 19.4 (HP in fights 48.5) | 30 | 100.0 / 490.0 / 8.2 / 1.83 / 0.00 / 13.3 (HP in fights 10.4) |
| peril | 476 | 81.5 / 453.6 / 43.9 / 2.73 / 0.25 / 11.1 (HP in fights 66.8) | 485 | 100.0 / 592.2 / 12.5 / 2.93 / 0.28 / 18.1 (HP in fights 16.0) |
| elite | 181 | 89.5 / 516.2 / 42.7 / 2.13 / 0.00 / 17.1 (HP in fights 58.0) | 185 | 100.0 / 543.1 / 11.0 / 2.32 / 0.00 / 17.3 (HP in fights 13.9) |
| mystery | 0 | - | 0 | - |

## 7. Files

- set 2001 kiem_si: B1 `b1-balance/B1-s2001-full-value-kiem_si.txt` (ok), E `group-e/E-s2001-kiem_si.txt` (ok)
- set 2001 phap_su: B1 `b1-balance/B1-s2001-full-value-phap_su.txt` (ok), E `group-e/E-s2001-phap_su.txt` (ok)
- set 2001 sat_thu: B1 `b1-balance/B1-s2001-full-value-sat_thu.txt` (ok), E `group-e/E-s2001-sat_thu.txt` (ok)
- set 2001 tho_san: B1 `b1-balance/B1-s2001-full-value-tho_san.txt` (ok), E `group-e/E-s2001-tho_san.txt` (ok)
- set 2001 giao_si: B1 `b1-balance/B1-s2001-full-value-giao_si.txt` (ok), E `group-e/E-s2001-giao_si.txt` (ok)
- set 3001 kiem_si: B1 `b1-balance/B1-s3001-full-value-kiem_si.txt` (ok), E `group-e/E-s3001-kiem_si.txt` (ok)
- set 3001 phap_su: B1 `b1-balance/B1-s3001-full-value-phap_su.txt` (ok), E `group-e/E-s3001-phap_su.txt` (ok)
- set 3001 sat_thu: B1 `b1-balance/B1-s3001-full-value-sat_thu.txt` (ok), E `group-e/E-s3001-sat_thu.txt` (ok)
- set 3001 tho_san: B1 `b1-balance/B1-s3001-full-value-tho_san.txt` (ok), E `group-e/E-s3001-tho_san.txt` (ok)
- set 3001 giao_si: B1 `b1-balance/B1-s3001-full-value-giao_si.txt` (ok), E `group-e/E-s3001-giao_si.txt` (ok)
