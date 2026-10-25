# Story 029 Phần D — signature cooldown measurement (bot, scratch)

Measured 2026-10-25. Only measured here; product code, data and tests were not changed. Probe script (scratch): `sigcd_probe.gd`, copied from `formation_probe.gd`. Grep'd lines: `signature-cooldown-raw.txt`.

## Method

- Real objects: CombatState, BoardGrid/ArenaLibrary, BossController (brain, learning, traits), SwingArbiter → CutEffects, StatusEffects, FormationMap, and the real signatures (`tram`, `thien_hoa`, `anh_bo`) with their `characters.json` params.
- Readiness is modelled in the script, following Phần D. The signature is ready when the cooldown is over **and** the FormationMap (`grid.enemy_cells()`, fade `formation_fade_for` = 5.0 + 0.8/cell) is complete. Once ready it stays ready until used. Using it calls the real `activate()`, resets the map to 0 and starts the cooldown. Trảm and Ảnh Bộ start their cooldown when the timed effect ends; Thiên Hỏa starts its cooldown immediately. The script does **not** read `cooldown_sec` from characters.json; it sweeps its own values. `cd=none` is a baseline where the signature never becomes ready.
- Activation uses the Story 021 bot rules:
  - **Trảm:** fires before a cast of ≥ 3 cells, or when the boss is at ≤ 40 % HP.
  - **Thiên Hỏa:** fires when the burn left is ≥ 15 or ≥ 2 enemy cells are burning; otherwise it fires anyway after being held for 6 s.
  - **Ảnh Bộ:** fires when the boss is pinned or when dodging; otherwise at the next cast.
- Value per use = the signature's extra damage plus the HP it heals:
  - **Trảm:** the doubled-cells part of each hit (exact; damage is linear in effective cells).
  - **Ảnh Bộ:** the ×2 part on a pinned boss with a cut of ≤ 3 cells (exact, through a wrapper around `player_signature_modifier`).
  - **Thiên Hỏa:** the detonation damage.
  - All extra damage is capped at the boss HP left, so killing-blow overkill is not counted. Healing = the real HP gained from Trảm lifesteal.
  - value/min = (sum of damage + heal) / (sum of match minutes).
- Chapter 1, starter deck, level-1 cards. Formation-aware bot: with chance P per cast it places the 3–5-cell pieces.json piece that covers the most dark cells. Two levels: P = 0.5 and P = 0.25.
- Boards (forced as in formation_probe):
  - square (goblin_scout, wolf, goblin_chief; 9 cells)
  - rect (4 bosses; 12 cells)
  - cross (goblin_archer, forest_witch; 11 cells)
  - ring (3 bosses forced onto the ring arena; 21 cells)
- About 30 matches per cell (rect 32). The bot's RNG uses the same seeds for every cooldown value. dt = 0.05.
- Bot assumptions:
  - One piece per cast; it never joins pieces.
  - Boss root-while-swinging lock (TD-017) is live.
  - Other levers as in formation_probe: aim 0.9, dodge 0.85, casts every 1.2–2.2 s.

## Results

Each cell reads: uses/match / value per use / value per minute / match seconds / win rate.


#### kiem_si, P = 0.5

| cd (s) | square uses / val/use / val/min / sec / won | rect uses / val/use / val/min / sec / won | cross uses / val/use / val/min / sec / won | ring uses / val/use / val/min / sec / won |
|---|---|---|---|---|
| none | 0.00 / 0.0 / 0.0 / 44 / 100% | 0.00 / 0.0 / 0.0 / 55 / 100% | 0.00 / 0.0 / 0.0 / 54 / 100% | 0.00 / 0.0 / 0.0 / 89 / 97% |
| 0 | 2.33 / 9.5 / 37.0 / 36 / 100% | 2.13 / 6.5 / 15.9 / 52 / 100% | 1.90 / 7.7 / 18.0 / 49 / 100% | 2.13 / 5.0 / 7.8 / 81 / 97% |
| 10 | 1.90 / 9.3 / 27.5 / 39 / 100% | 1.94 / 6.8 / 15.7 / 50 / 100% | 1.83 / 7.7 / 17.1 / 50 / 100% | 2.13 / 5.0 / 7.8 / 81 / 97% |
| 15 | 1.60 / 9.3 / 22.4 / 40 / 100% | 1.66 / 7.8 / 15.5 / 50 / 100% | 1.63 / 7.8 / 15.9 / 48 / 100% | 2.17 / 4.9 / 7.5 / 84 / 93% |
| 20 | 1.40 / 11.5 / 24.8 / 39 / 100% | 1.44 / 8.4 / 14.1 / 51 / 100% | 1.47 / 7.4 / 13.0 / 50 / 100% | 2.07 / 5.1 / 7.6 / 84 / 97% |
| 25 | 1.30 / 11.6 / 23.4 / 39 / 100% | 1.31 / 7.7 / 11.8 / 51 / 100% | 1.43 / 7.1 / 11.9 / 51 / 100% | 1.83 / 4.4 / 5.7 / 84 / 93% |
| 30 | 1.27 / 12.5 / 25.0 / 38 / 100% | 1.28 / 8.2 / 12.3 / 51 / 100% | 1.20 / 6.8 / 9.9 / 50 / 100% | 1.50 / 5.4 / 6.2 / 79 / 93% |

#### phap_su, P = 0.5

| cd (s) | square uses / val/use / val/min / sec / won | rect uses / val/use / val/min / sec / won | cross uses / val/use / val/min / sec / won | ring uses / val/use / val/min / sec / won |
|---|---|---|---|---|
| none | 0.00 / 0.0 / 0.0 / 38 / 100% | 0.00 / 0.0 / 0.0 / 48 / 100% | 0.00 / 0.0 / 0.0 / 61 / 100% | 0.00 / 0.0 / 0.0 / 84 / 97% |
| 0 | 1.73 / 2.4 / 6.4 / 39 / 100% | 1.72 / 5.3 / 11.7 / 46 / 100% | 1.50 / 9.5 / 17.2 / 50 / 100% | 1.60 / 8.8 / 11.0 / 77 / 97% |
| 10 | 1.60 / 1.8 / 4.4 / 40 / 100% | 1.72 / 5.2 / 11.4 / 47 / 100% | 1.40 / 10.4 / 17.9 / 49 / 100% | 1.60 / 8.8 / 11.0 / 77 / 97% |
| 15 | 1.60 / 2.5 / 5.8 / 42 / 100% | 1.56 / 3.0 / 5.8 / 48 / 100% | 1.33 / 10.4 / 16.6 / 50 / 100% | 1.60 / 8.8 / 11.0 / 77 / 97% |
| 20 | 1.47 / 0.8 / 1.6 / 42 / 100% | 1.41 / 4.3 / 7.6 / 48 / 100% | 1.33 / 8.5 / 12.6 / 54 / 100% | 1.63 / 6.9 / 8.5 / 79 / 97% |
| 25 | 1.33 / 1.7 / 3.2 / 42 / 100% | 1.19 / 7.2 / 11.1 / 46 / 100% | 1.23 / 7.0 / 9.3 / 56 / 100% | 1.50 / 7.1 / 8.2 / 78 / 97% |
| 30 | 1.23 / 2.2 / 4.1 / 39 / 100% | 1.16 / 7.8 / 11.7 / 46 / 100% | 1.13 / 6.2 / 7.5 / 56 / 100% | 1.33 / 7.0 / 6.9 / 80 / 97% |

#### sat_thu, P = 0.5

| cd (s) | square uses / val/use / val/min / sec / won | rect uses / val/use / val/min / sec / won | cross uses / val/use / val/min / sec / won | ring uses / val/use / val/min / sec / won |
|---|---|---|---|---|
| none | 0.00 / 0.0 / 0.0 / 36 / 100% | 0.00 / 0.0 / 0.0 / 48 / 100% | 0.00 / 0.0 / 0.0 / 50 / 100% | 0.00 / 0.0 / 0.0 / 77 / 100% |
| 0 | 2.47 / 0.9 / 3.7 / 36 / 100% | 2.22 / 0.3 / 0.8 / 52 / 100% | 2.23 / 0.3 / 0.9 / 51 / 100% | 1.80 / 0.4 / 0.6 / 71 / 100% |
| 10 | 1.97 / 0.7 / 2.4 / 36 / 100% | 2.09 / 0.0 / 0.0 / 53 / 100% | 1.97 / 0.8 / 1.8 / 50 / 100% | 1.80 / 0.4 / 0.6 / 71 / 100% |
| 15 | 1.60 / 1.4 / 3.7 / 35 / 100% | 1.84 / 0.0 / 0.0 / 51 / 100% | 1.67 / 0.5 / 0.9 / 49 / 100% | 1.80 / 0.4 / 0.6 / 71 / 100% |
| 20 | 1.40 / 1.0 / 2.3 / 37 / 100% | 1.59 / 0.0 / 0.0 / 51 / 100% | 1.67 / 0.5 / 0.9 / 52 / 100% | 1.70 / 0.4 / 0.6 / 71 / 100% |
| 25 | 1.33 / 1.1 / 2.3 / 37 / 100% | 1.41 / 0.0 / 0.0 / 51 / 100% | 1.50 / 0.5 / 0.8 / 53 / 100% | 1.43 / 0.5 / 0.6 / 73 / 100% |
| 30 | 1.17 / 1.2 / 2.3 / 37 / 100% | 1.31 / 0.3 / 0.5 / 50 / 100% | 1.40 / 0.5 / 0.9 / 52 / 100% | 1.40 / 0.5 / 0.6 / 72 / 100% |

#### kiem_si, P = 0.25

| cd (s) | square uses / val/use / val/min / sec / won | rect uses / val/use / val/min / sec / won | cross uses / val/use / val/min / sec / won | ring uses / val/use / val/min / sec / won |
|---|---|---|---|---|
| none | 0.00 / 0.0 / 0.0 / 42 / 100% | 0.00 / 0.0 / 0.0 / 49 / 100% | 0.00 / 0.0 / 0.0 / 52 / 100% | 0.00 / 0.0 / 0.0 / 79 / 97% |
| 0 | 1.37 / 9.9 / 22.5 / 36 / 100% | 0.66 / 6.6 / 5.4 / 48 / 100% | 1.00 / 8.7 / 10.8 / 49 / 100% | 0.60 / 8.2 / 3.9 / 75 / 97% |
| 10 | 1.23 / 9.4 / 18.8 / 37 / 100% | 0.66 / 6.2 / 5.1 / 48 / 100% | 1.00 / 8.5 / 10.4 / 49 / 100% | 0.60 / 8.2 / 3.9 / 75 / 97% |
| 15 | 0.93 / 9.5 / 14.2 / 37 / 100% | 0.56 / 7.2 / 5.0 / 48 / 100% | 0.90 / 10.2 / 11.4 / 48 / 100% | 0.60 / 8.2 / 3.9 / 75 / 97% |
| 20 | 0.90 / 9.7 / 14.1 / 37 / 100% | 0.56 / 7.5 / 5.2 / 49 / 100% | 0.80 / 10.1 / 9.9 / 49 / 100% | 0.60 / 8.2 / 3.9 / 75 / 97% |
| 25 | 0.83 / 10.2 / 13.7 / 37 / 100% | 0.53 / 6.9 / 4.6 / 48 / 100% | 0.80 / 9.0 / 8.7 / 50 / 100% | 0.60 / 8.2 / 3.9 / 75 / 97% |
| 30 | 0.83 / 10.2 / 13.7 / 37 / 100% | 0.50 / 6.2 / 3.8 / 48 / 100% | 0.77 / 8.2 / 7.5 / 50 / 100% | 0.60 / 8.2 / 3.9 / 75 / 97% |

#### phap_su, P = 0.25

| cd (s) | square uses / val/use / val/min / sec / won | rect uses / val/use / val/min / sec / won | cross uses / val/use / val/min / sec / won | ring uses / val/use / val/min / sec / won |
|---|---|---|---|---|
| none | 0.00 / 0.0 / 0.0 / 40 / 100% | 0.00 / 0.0 / 0.0 / 49 / 100% | 0.00 / 0.0 / 0.0 / 55 / 100% | 0.00 / 0.0 / 0.0 / 76 / 100% |
| 0 | 1.10 / 1.7 / 2.9 / 39 / 100% | 0.63 / 1.7 / 1.4 / 46 / 100% | 0.80 / 11.0 / 10.3 / 51 / 100% | 0.50 / 14.7 / 6.2 / 71 / 100% |
| 10 | 1.10 / 1.7 / 2.9 / 39 / 100% | 0.63 / 1.7 / 1.4 / 46 / 100% | 0.80 / 11.0 / 10.3 / 51 / 100% | 0.50 / 14.7 / 6.2 / 71 / 100% |
| 15 | 1.00 / 1.8 / 2.8 / 39 / 100% | 0.66 / 1.6 / 1.4 / 47 / 100% | 0.80 / 11.0 / 10.3 / 51 / 100% | 0.50 / 14.7 / 6.2 / 71 / 100% |
| 20 | 0.93 / 0.0 / 0.0 / 40 / 100% | 0.56 / 1.9 / 1.4 / 47 / 100% | 0.77 / 11.5 / 10.5 / 50 / 100% | 0.50 / 14.7 / 6.2 / 71 / 100% |
| 25 | 0.90 / 0.0 / 0.0 / 39 / 100% | 0.56 / 1.9 / 1.4 / 47 / 100% | 0.77 / 11.5 / 10.5 / 50 / 100% | 0.47 / 20.0 / 7.9 / 71 / 100% |
| 30 | 0.87 / 0.0 / 0.0 / 40 / 100% | 0.56 / 1.9 / 1.4 / 47 / 100% | 0.77 / 11.5 / 10.5 / 50 / 100% | 0.47 / 18.6 / 7.3 / 71 / 100% |

#### sat_thu, P = 0.25

| cd (s) | square uses / val/use / val/min / sec / won | rect uses / val/use / val/min / sec / won | cross uses / val/use / val/min / sec / won | ring uses / val/use / val/min / sec / won |
|---|---|---|---|---|
| none | 0.00 / 0.0 / 0.0 / 35 / 100% | 0.00 / 0.0 / 0.0 / 40 / 100% | 0.00 / 0.0 / 0.0 / 43 / 100% | 0.00 / 0.0 / 0.0 / 66 / 100% |
| 0 | 1.23 / 0.1 / 0.3 / 34 / 100% | 0.66 / 2.1 / 2.1 / 39 / 100% | 0.73 / 2.0 / 2.1 / 44 / 100% | 0.47 / 1.6 / 0.7 / 66 / 100% |
| 10 | 1.10 / 0.2 / 0.3 / 34 / 100% | 0.69 / 2.0 / 2.1 / 39 / 100% | 0.73 / 2.0 / 2.1 / 44 / 100% | 0.47 / 1.6 / 0.7 / 66 / 100% |
| 15 | 1.03 / 0.2 / 0.3 / 34 / 100% | 0.66 / 2.1 / 2.1 / 40 / 100% | 0.67 / 2.3 / 2.1 / 43 / 100% | 0.47 / 1.6 / 0.7 / 66 / 100% |
| 20 | 1.03 / 0.2 / 0.3 / 33 / 100% | 0.66 / 2.1 / 2.1 / 40 / 100% | 0.63 / 1.2 / 1.0 / 44 / 100% | 0.47 / 1.6 / 0.7 / 66 / 100% |
| 25 | 1.00 / 0.2 / 0.3 / 33 / 100% | 0.56 / 2.5 / 2.1 / 40 / 100% | 0.53 / 1.4 / 1.0 / 44 / 100% | 0.47 / 1.6 / 0.7 / 66 / 100% |
| 30 | 0.93 / 0.2 / 0.3 / 33 / 100% | 0.56 / 2.5 / 2.1 / 40 / 100% | 0.53 / 1.4 / 1.0 / 44 / 100% | 0.47 / 1.6 / 0.7 / 66 / 100% |

#### Detail lines (square, P=0.5): dmg/use, heal/use, taken, reasons, use distribution

kiem_si cd=-1: dmg/use=0.0 heal/use=0.0 taken=22.7 dealt=108.2 sec=43.9 first=0.0 blocked=0.00 0=100% 1=0% 2=0% 3=0% 4+=0% reasons={}
kiem_si cd=0: dmg/use=8.0 heal/use=1.5 taken=17.2 dealt=111.6 sec=35.8 first=16.9 blocked=0.00 0=3% 1=33% 2=30% 3=13% 4+=20% reasons={"before":70}
kiem_si cd=10: dmg/use=8.2 heal/use=1.1 taken=17.8 dealt=108.8 sec=38.6 first=16.9 blocked=1.20 0=3% 1=43% 2=33% 3=10% 4+=10% reasons={"before":57}
kiem_si cd=15: dmg/use=8.4 heal/use=0.9 taken=19.8 dealt=107.0 sec=40.1 first=16.9 blocked=1.33 0=3% 1=57% 2=27% 3=3% 4+=10% reasons={"before":48}
kiem_si cd=20: dmg/use=10.2 heal/use=1.3 taken=19.8 dealt=107.8 sec=39.1 first=16.9 blocked=1.37 0=3% 1=63% 2=23% 3=10% 4+=0% reasons={"before":42}
kiem_si cd=25: dmg/use=10.3 heal/use=1.3 taken=19.6 dealt=108.0 sec=38.6 first=16.9 blocked=1.40 0=3% 1=70% 2=20% 3=7% 4+=0% reasons={"before":39}
kiem_si cd=30: dmg/use=10.8 heal/use=1.7 taken=18.6 dealt=108.7 sec=38.2 first=16.9 blocked=1.43 0=3% 1=70% 2=23% 3=3% 4+=0% reasons={"before":38}
phap_su cd=-1: dmg/use=0.0 heal/use=0.0 taken=15.4 dealt=109.9 sec=38.1 first=0.0 blocked=0.00 0=100% 1=0% 2=0% 3=0% 4+=0% reasons={}
phap_su cd=0: dmg/use=2.4 heal/use=0.0 taken=21.6 dealt=108.4 sec=38.8 first=19.4 blocked=0.00 0=3% 1=50% 2=23% 3=17% 4+=7% reasons={"held":48,"burn":4}
phap_su cd=10: dmg/use=1.8 heal/use=0.0 taken=19.6 dealt=107.4 sec=39.6 first=19.4 blocked=0.77 0=3% 1=57% 2=20% 3=17% 4+=3% reasons={"held":44,"burn":4}
phap_su cd=15: dmg/use=2.5 heal/use=0.0 taken=23.6 dealt=108.0 sec=41.7 first=19.4 blocked=0.97 0=3% 1=63% 2=13% 3=13% 4+=7% reasons={"held":43,"burn":5}
phap_su cd=20: dmg/use=0.8 heal/use=0.0 taken=24.8 dealt=107.8 sec=42.2 first=19.4 blocked=1.13 0=3% 1=63% 2=17% 3=17% 4+=0% reasons={"held":41,"burn":3}
phap_su cd=25: dmg/use=1.7 heal/use=0.0 taken=21.8 dealt=108.6 sec=42.2 first=19.4 blocked=1.30 0=3% 1=70% 2=17% 3=10% 4+=0% reasons={"held":37,"burn":3}
phap_su cd=30: dmg/use=2.2 heal/use=0.0 taken=21.6 dealt=108.5 sec=39.3 first=19.4 blocked=1.07 0=3% 1=70% 2=27% 3=0% 4+=0% reasons={"held":34,"burn":3}
sat_thu cd=-1: dmg/use=0.0 heal/use=0.0 taken=22.0 dealt=108.6 sec=35.7 first=0.0 blocked=0.00 0=100% 1=0% 2=0% 3=0% 4+=0% reasons={}
sat_thu cd=0: dmg/use=0.9 heal/use=0.0 taken=16.6 dealt=108.8 sec=35.5 first=14.7 blocked=0.00 0=3% 1=17% 2=47% 3=17% 4+=17% reasons={"boss":6,"next":61,"dodge":7}
sat_thu cd=10: dmg/use=0.7 heal/use=0.0 taken=19.3 dealt=108.6 sec=35.9 first=14.7 blocked=1.13 0=3% 1=30% 2=43% 3=17% 4+=7% reasons={"boss":4,"next":53,"dodge":2}
sat_thu cd=15: dmg/use=1.4 heal/use=0.0 taken=18.3 dealt=108.8 sec=35.3 first=14.7 blocked=1.23 0=3% 1=47% 2=37% 3=13% 4+=0% reasons={"boss":5,"next":39,"dodge":4}
sat_thu cd=20: dmg/use=1.0 heal/use=0.0 taken=19.7 dealt=108.3 sec=37.4 first=14.7 blocked=1.40 0=3% 1=67% 2=20% 3=7% 4+=3% reasons={"boss":5,"next":33,"dodge":4}
sat_thu cd=25: dmg/use=1.1 heal/use=0.0 taken=20.1 dealt=108.8 sec=36.9 first=14.7 blocked=1.37 0=3% 1=67% 2=27% 3=0% 4+=3% reasons={"boss":5,"next":33,"dodge":2}
sat_thu cd=30: dmg/use=1.2 heal/use=0.0 taken=19.9 dealt=108.6 sec=36.6 first=14.7 blocked=1.43 0=3% 1=80% 2=13% 3=3% 4+=0% reasons={"boss":4,"next":30,"dodge":1}

## Reading

1. **The formation map limits uses more than the cooldown does.** At cd 0 and P = 0.5, uses/match averages 2.5 or less everywhere. The cooldown only trims the tail of matches with 4 or more uses (Trảm square cd 0: 20 % of matches with 4+; cd 20: 0 %). At P = 0.25, uses are about 0.5–1.4/match, and the cooldown barely matters.
2. **Value per use (P = 0.5):**
   - **Trảm:** about 9–12 on square, 7–8 on rect/cross, about 5 on ring. Heal is about 1–2 of that.
   - **Thiên Hỏa:** 1–2.5 on square and rect, 6–10 on cross and ring. 85–90 % of its uses were the "held 6 s" fallback with little burn on the field.
   - **Ảnh Bộ:** 0–1.5. Most uses come at "next cast"; the boss is seldom pinned during the 2 s window. The starter pin card bang_phong needs 4 cells and has a 10 s cooldown.
3. **value/min cannot be made comparable through the cooldown.** A cooldown can only remove uses. On square at P = 0.5, Trảm is 37/min at cd 0 and still about 23–25 at cd 25–30. Thiên Hỏa is about 3–6 and Ảnh Bộ about 2–4 at any cooldown. That is about 6–8 : 1.5 : 1, and the cooldown can only bring Trảm down toward the others; it cannot raise them. This is a balance or activation-rule question for game-designer (Thiên Hỏa params and timing, Ảnh Bộ pin condition), not something cooldown_sec can fix.
4. **Big boards vs small boards:** on ring (21 cells), completing the map takes so long that cooldowns up to about 20 s change nothing (Trảm stays at 2.1–2.2 uses at cd 0–20 and drops to 1.8 / 1.5 only at 25 / 30). Thiên Hỏa and Ảnh Bộ do not change on ring from 0 to 30 s. So the cooldown only matters on small boards (square/rect/cross, 9–12 cells) with a player who spreads casts well.

## Recommendation: cooldown_sec

| character | signature | recommend | placeholder in data | why |
|---|---|---|---|---|
| kiem_si | tram | **25** | 20 | Strongest by about 5×. At 25: square P=0.5 is 1.30 uses/match, 0 % with 4+, 7 % with 3; value/min about 23. At 20 it is also ≤ 3 (0 % with 4+); 25 just narrows the gap to the others a little more. |
| phap_su | thien_hoa | **15** | 15 | Middle. Square P=0.5: 1.60 uses/match, about 7 % with 4+ (the 4+ share is noisy: 3 % at cd 10). Its low value comes from the activation rule and params, not from the cooldown. |
| anh_bo | sat_thu | **12** | 12 | Shortest. Between cd 10 (7 % with 4+) and cd 15 (0 % with 4+, 13 % with 3), so about 3 uses at most. Its direct value is near zero, so its use count hardly affects balance. |

The ratio I aimed for: the cooldown order Trảm > Thiên Hỏa > Ảnh Bộ, with at most about 3 uses on the small square board at P = 0.5. value/min within about 2:1 between strongest and weakest is **not reachable** with cooldown_sec alone (it is about 6:1 even at these values). Flagged for game-designer.

## Caveats

- Bot, not a human. Thiên Hỏa and Ảnh Bộ value depends heavily on the activation rule. A patient human (Thiên Hỏa only when there is burn, Ảnh Bộ only on a pin) would get more per use. That variant was **not** measured: the patch failed, and the duplicate log `sigcd_patient_raw.txt` in the scratchpad is invalid and was not used.
- Indirect value is not counted: Ảnh Bộ's free steps (dodges) and Thiên Hỏa's reset of burn-card cooldowns. Damage taken per match with n = 30 swings by ±5 HP between runs that should be equivalent, so it cannot isolate them.
- Thiên Hỏa detonation is counted gross. Some of the burn it consumes would have hurt the boss anyway, so its net value is lower.
- Flat defense is ignored in the Trảm and Ảnh Bộ extra (chapter-1 bosses are almost all 0). Card levels are 1 and there is no run progression.
- About 30 matches per cell. value/use for Thiên Hỏa and Ảnh Bộ varies by ±2 between neighbouring cooldown rows (noise). Share of matches with 4+ uses: ±5–7 points.
