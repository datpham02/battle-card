## 1. Character x seed set: run win % (C -> B1, diff)

| character | set 2001 | set 3001 | mean C | mean B1 | diff |
|---|---|---|---|---|---|
| kiem_si | 25.7 -> 24.3 (-1.4) | 12.9 -> 12.9 (0.0) | 19.3 | 18.6 | -0.7 |
| phap_su | 7.1 -> 14.3 (7.2) | 24.3 -> 18.6 (-5.7) | 15.7 | 16.5 | 0.8 |
| sat_thu | 11.4 -> 8.6 (-2.8) | 7.1 -> 7.1 (0.0) | 9.2 | 7.8 | -1.4 |
| tho_san | 14.3 -> 11.4 (-2.9) | 7.1 -> 7.1 (0.0) | 10.7 | 9.2 | -1.4 |
| giao_si | 8.6 -> 11.4 (2.8) | 14.3 -> 17.1 (2.8) | 11.4 | 14.2 | 2.8 |
| **pooled (10 combos, 700 runs each)** | 13.4 -> 14.0 | 13.1 -> 12.6 | **13.3** | **13.3** | **0.0** |

## 2. Run-level metrics, pooled over the 10 combos (mean of per-combo values)

| metric | C | B1 | diff | diff % |
|---|---|---|---|---|
| run win % | 13.3 | 13.3 | 0.0 | +0.0 % |
| hellfire clear % (of runs entering floor 2) | 85.4 | 84.6 | -0.8 | -1.0 % |
| floor 2 clear % of runs entering (WORLD FLOORS) | 85.4 | 84.6 | -0.8 | -1.0 % |
| hellfire match win % | 96.8 | 96.6 | -0.2 | -0.2 % |
| est. minutes, all runs | 33.15 | 32.77 | -0.38 | -1.1 % |
| est. minutes, won runs (mean) | 49.35 | 49.12 | -0.23 | -0.5 % |
| run minutes, won median | 51.89 | 51.50 | -0.39 | -0.8 % |
| run minutes, lost median | 30.80 | 30.40 | -0.40 | -1.3 % |
| hits taken / run (all) | 32.11 | 31.73 | -0.38 | -1.2 % |
| hits taken / won run | 44.62 | 44.33 | -0.29 | -0.6 % |
| matches / run | 20.18 | 19.96 | -0.22 | -1.1 % |
| gold earned / run (all) | 622.8 | 615.9 | -6.9 | -1.1 % |
| gold spent / run (all) | 335.6 | 332.2 | -3.4 | -1.0 % |
| gold earned / won run | 1019.2 | 1023.6 | 4.4 | +0.4 % |
| relics / run | 10.62 | 10.54 | -0.08 | -0.7 % |
| deck size | 11.38 | 11.36 | -0.03 | -0.2 % |
| HP % entering floor 2 | 99.4 | 99.4 | 0.0 | +0.0 % |
| HP % after the hellfire warden (before heal) | 49.5 | 49.7 | 0.2 | +0.5 % |
| hellfire: HP lost in fights per route (pts) | 63.3 | 63.4 | 0.1 | +0.1 % |
| hellfire: net HP lost per route (pts) | 43.0 | 42.9 | -0.1 | -0.2 % |
| ROUTE gold (drops, mean of runs by hellfire lane taken; whole-run figure in full runs) | 484.0 | 476.1 | -8.0 | -1.6 % |
| ROUTE relics (mean of runs by lane taken) | 2.51 | 2.51 | 0.00 | +0.0 % |
| hellfire: objective met per route | 0.17 | 0.17 | 0.00 | +0.0 % |
| ROUTE NV = gold + 60 relics - 1.6 HP (same caveat; compare C vs B1 only) | 566.0 | 558.2 | -7.8 | -1.4 % |
| hellfire: heat at warden (mean) | 1.48 | 1.48 | -0.00 | -0.0 % |
| hellfire: warden reached at heat 3-4 % | 27.9 | 27.8 | -0.0 | -0.0 % |

## 3. Per character (both sets pooled): win % / hellfire clear % / minutes all runs / gold earned / relics / hellfire HP in fights / heat 3-4 at warden %

| character | C | B1 | diff (win / hell / min / gold / relics / HP / heat34) |
|---|---|---|---|
| kiem_si | 19.3 / 98.5 / 38.90 / 749.5 / 12.23 / 55.0 / 28.1 | 18.6 / 96.4 / 38.05 / 726.0 / 12.03 / 55.7 / 28.3 | -0.7 / -2.1 / -0.85 / -23.5 / -0.21 / 0.7 / 0.2 |
| phap_su | 15.7 / 88.6 / 32.20 / 646.5 / 10.46 / 59.7 / 27.3 | 16.5 / 88.6 / 32.75 / 659.0 / 10.62 / 57.7 / 27.5 | 0.8 / 0.0 / 0.55 / 12.5 / 0.17 / -2.0 / 0.2 |
| sat_thu | 9.2 / 74.3 / 28.65 / 541.5 / 9.61 / 68.4 / 26.2 | 7.8 / 72.8 / 27.85 / 527.0 / 9.46 / 68.6 / 26.2 | -1.4 / -1.5 / -0.80 / -14.5 / -0.14 / 0.2 / 0.0 |
| tho_san | 10.7 / 84.3 / 31.65 / 566.5 / 10.12 / 66.8 / 27.7 | 9.2 / 82.8 / 31.05 / 559.5 / 10.00 / 67.2 / 27.5 | -1.4 / -1.5 / -0.60 / -7.0 / -0.11 / 0.4 / -0.2 |
| giao_si | 11.4 / 81.4 / 34.35 / 610.0 / 10.66 / 66.8 / 30.1 | 14.2 / 82.2 / 34.15 / 608.0 / 10.57 / 67.9 / 29.9 | 2.8 / 0.8 / -0.20 / -2.0 / -0.09 / 1.1 / -0.2 |

## 4. Hellfire clear % per character x set (C -> B1), deaths on floor 2 of 70

| character | set 2001 | set 3001 |
|---|---|---|
| kiem_si | 100.0 -> 95.7 (deaths 0 -> 3) | 97.1 -> 97.1 (deaths 2 -> 2) |
| phap_su | 85.7 -> 88.6 (deaths 10 -> 8) | 91.4 -> 88.6 (deaths 6 -> 8) |
| sat_thu | 74.3 -> 71.4 (deaths 18 -> 20) | 74.3 -> 74.3 (deaths 18 -> 18) |
| tho_san | 85.7 -> 81.4 (deaths 10 -> 13) | 82.9 -> 84.3 (deaths 12 -> 11) |
| giao_si | 81.4 -> 80.0 (deaths 13 -> 14) | 81.4 -> 84.3 (deaths 13 -> 11) |

## 5. Warden arrival heat distribution (hellfire, value policy; all characters and sets pooled)

| variant | wardens reached | heat 0 | heat 1 | heat 2 | heat 3 | heat 4 | heat 3-4 % | mean heat |
|---|---|---|---|---|---|---|---|---|
| C | 664 | 232 (34.9 %) | 148 (22.3 %) | 99 (14.9 %) | 102 (15.4 %) | 83 (12.5 %) | 27.9 | 1.48 |
| B1 | 664 | 232 (34.9 %) | 148 (22.3 %) | 99 (14.9 %) | 102 (15.4 %) | 83 (12.5 %) | 27.9 | 1.48 |

## 6. Hellfire lanes taken on `value` (pooled over characters and sets, weighted by runs): clear % / gold / net HP / relics / objective / run win %

| lane | C runs | C | B1 runs | B1 |
|---|---|---|---|---|
| safe | 7 | 100.0 / 597.9 / 10.0 / 1.14 / 0.00 / 28.6 (HP in fights 48.6) | 7 | 100.0 / 597.9 / 10.0 / 1.14 / 0.00 / 28.6 (HP in fights 48.6) |
| treasure | 36 | 97.2 / 583.0 / 33.9 / 1.83 / 0.00 / 22.2 (HP in fights 46.0) | 36 | 97.2 / 547.6 / 36.4 / 1.83 / 0.00 / 19.4 (HP in fights 48.5) |
| peril | 476 | 82.8 / 456.9 / 44.6 / 2.73 / 0.25 / 9.9 (HP in fights 67.1) | 476 | 81.5 / 453.6 / 43.9 / 2.73 / 0.25 / 11.1 (HP in fights 66.8) |
| elite | 181 | 89.5 / 531.2 / 41.8 / 2.13 / 0.00 / 19.9 (HP in fights 57.6) | 181 | 89.5 / 516.2 / 42.7 / 2.13 / 0.00 / 17.1 (HP in fights 58.0) |
| mystery | 0 | - | 0 | - |

## 7. Files

- set 2001 kiem_si: C `balance/C-full-value-kiem_si.txt` (ok), B1 `b1-balance/B1-s2001-full-value-kiem_si.txt` (ok)
- set 2001 phap_su: C `balance/C-full-value-phap_su.txt` (ok), B1 `b1-balance/B1-s2001-full-value-phap_su.txt` (ok)
- set 2001 sat_thu: C `balance/C-full-value-sat_thu.txt` (ok), B1 `b1-balance/B1-s2001-full-value-sat_thu.txt` (ok)
- set 2001 tho_san: C `balance/C-full-value-tho_san.txt` (ok), B1 `b1-balance/B1-s2001-full-value-tho_san.txt` (ok)
- set 2001 giao_si: C `balance/C-full-value-giao_si.txt` (ok), B1 `b1-balance/B1-s2001-full-value-giao_si.txt` (ok)
- set 3001 kiem_si: C `balance/rep-C-full-value-kiem_si.txt` (ok), B1 `b1-balance/B1-s3001-full-value-kiem_si.txt` (ok)
- set 3001 phap_su: C `balance/rep-C-full-value-phap_su.txt` (ok), B1 `b1-balance/B1-s3001-full-value-phap_su.txt` (ok)
- set 3001 sat_thu: C `balance/rep-C-full-value-sat_thu.txt` (ok), B1 `b1-balance/B1-s3001-full-value-sat_thu.txt` (ok)
- set 3001 tho_san: C `balance/rep-C-full-value-tho_san.txt` (ok), B1 `b1-balance/B1-s3001-full-value-tho_san.txt` (ok)
- set 3001 giao_si: C `balance/rep-C-full-value-giao_si.txt` (ok), B1 `b1-balance/B1-s3001-full-value-giao_si.txt` (ok)
