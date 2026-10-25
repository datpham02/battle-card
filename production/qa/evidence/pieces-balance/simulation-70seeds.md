# Story 026 — balance with pieces (70 seeds × 3 characters × 3 chapters)

Tool: `tools/balance/deck_sim.gd` (see `tools/balance/README.md`), build policy, bot defaults
(`dodge=0.85` — TD-006 legacy value, not re-anchored; `hold=1`, `aware=0`, `sig=rules`).
Raw output: `simulation-70seeds-raw.txt`. Single seed set (seeds fixed), so a cell is ±~11 points (95 %).

## Final numbers (shipped data)

| Chapter (target win %) | Character | Win % | Boss hits / won run (15–30) | Hits / run (all) | Boss swings / run | Boss hit rate | Signature uses / run | Joins / match |
|---|---|---|---|---|---|---|---|---|
| ch1 (40–60) | Kiếm sĩ | **52.9** | 15.5 | 17.8 | 63.7 | 0.28 | 1.31 | 0.89 |
| ch1 | Pháp sư | **25.7** ↓ | 13.9 | 15.8 | 48.2 | 0.33 | 1.09 | 1.10 |
| ch1 | Sát thủ | **48.6** | 12.1 | 14.1 | 53.9 | 0.26 | 1.11 | 0.68 |
| ch2 (25–45) | Kiếm sĩ | **48.6** ↑ | 15.0 | 16.1 | 48.5 | 0.33 | 1.44 | 0.57 |
| ch2 | Pháp sư | **18.6** ↓ | 14.3 | 13.6 | 36.3 | 0.37 | 1.16 | 0.77 |
| ch2 | Sát thủ | **40.0** | 12.6 | 13.0 | 42.5 | 0.31 | 1.36 | 0.46 |
| ch3 (15–35) | Kiếm sĩ | **35.7** | 16.9 | 19.1 | 56.0 | 0.34 | 1.79 | 0.55 |
| ch3 | Pháp sư | **20.0** | 12.4 | 14.2 | 38.5 | 0.37 | 1.21 | 0.86 |
| ch3 | Sát thủ | **14.3** ↓ | 12.6 | 14.7 | 46.4 | 0.32 | 1.87 | 0.38 |

5 of 9 cells in band; the misses are character spread (TD-008 allows relative gaps): Pháp sư 7–14 points low in
ch1/ch2, Kiếm sĩ 3.6 points high in ch2, Sát thủ 0.7 points low in ch3. Boss hits per won run 12–17: at or under the
15 floor for Pháp sư and Sát thủ (shorter fights with less boss HP; TD-006 dodge still unanchored).

## Where we started

| Win % (K / P / S) | ch1 | ch2 | ch3 |
|---|---|---|---|
| Before the TD-022 fix, Story 023 data, 70 seeds | 65.7 / 20.0 / 47.1 | 17.1 / 0.0 / 7.1 | 2.9 / 0.0 / 2.9 |
| After the TD-022 fix, Story 023 data, 40 seeds | 70.0 / 20.0 / 45.0 | 15.0 / 0.0 / 7.5 | 5.0 / 0.0 / 2.5 |
| Final (this story's data) | 52.9 / 25.7 / 48.6 | 48.6 / 18.6 / 40.0 | 35.7 / 20.0 / 14.3 |

`--hold=2 --aware=0.5` (bot waits for 2 pieces, aims at unlit formation cells) was worse everywhere
(ch1 32.9 / 8.6 / 30.0, ch2 2.9 / 1.4 / 1.4 before tuning): waiting to join costs more than it gains.

## Data changes (all data-only except TD-022)

| Lever | Before | After | Why |
|---|---|---|---|
| ch1 `boss_max_hp`, every match | 80…150 | ×1.08 (86…162) | Kiếm sĩ 68.6 % → 52.9 % |
| ch2 `jailer` / `ogre_king` HP | 170 / 290 | 77 / 132 | deaths concentrate on miniboss + boss; normals kept so HP still escalates ch1 → ch3 (`chapters23_test`) |
| ch3 `frost_mage` / `mist_lord` HP | 210 / 320 | 92 / 139 | same |
| Pháp sư `max_hp` | 160 | 190 | TD-008 |
| `wide_caster` | ≥5 cells, ×0.85 | ≥4 cells, ×0.75 | with pieces 5-cell casts are rare, the passive almost never fired |
| New piece `p5` (P pentomino, 2×3 box) | — | weight ch1 1.5 / ch2 4 / ch3 6 / default 3 | TD-012: compact 5-cell shape for the nine 5-cell cards |
| `BossBrain` full-hand rule (code, TD-022) | full hand below `min_cut_score` = no cast forever | casts its best candidate | see below |

Tried and dropped: uniform HP cut of every ch2/ch3 match (×0.65 / ×0.62; in band but ch2 normals fell below ch1,
breaking the escalation rule); boss step ×1.3 (no effect in ch2); hero HP ×1.3 (weak); Thiên Hỏa cooldown 12 s (no gain).

## TD-022 — why some piece-bosses barely swung

Cause (measured, `td022_probe`, 600 s × 3 seeds × 6 enemies, standing player): the boss fills its 3-slot hand before
casting; single-cell pieces pile up; with three singles every candidate scores 2.3–2.7, under `min_cut_score`
(3.0, cautious 4.0); a full hand cannot pick up, so the boss never swings again. Stalled 8–66 % of the time on every
enemy; which enemies looked slow in Story 025 was seed luck. Supply (15–19 pieces/min), placement limits, arena fit,
feints and the root were ruled out. Fix: a full hand casts its best candidate (`src/combat/boss_brain.gd`,
`tests/unit/combat/boss_stall_test.gd`, 14 checks, 7 fail with the rule off). After: stall 0–6 %, 7.7–12.3 swings/min.
A data-only fix (lower bar) was rejected: with the player hand full for 4 s (`quick_cut_bias`) the best two-single
score is 1.94, under any sensible bar.

## TD-012 — 5-cell hit rate (hit_probe, ch3, 40 casts per size per enemy, piece mode)

| Cast size | 3 | 4 | 5 |
|---|---|---|---|
| Hits / casts | 42 % | 30 % | 23 % |

Story 024 measured 19 % for 5 cells on chapter 1 without `p5`; different chapter, so not a clean before/after.
5-cell casts remain the weakest size.
