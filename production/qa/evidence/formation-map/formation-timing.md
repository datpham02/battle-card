# Story 029 — Formation map timing vs the old 18-cell charge (bot measurement)

Story: `production/epics/kaiten-duel/story-029-formation-map.md`, Phần C, "Đo bằng bot".
Target there: the signature is ready **1–3 times per match**, as it was under the old charge. If it misses, change
`formation_fade_base_sec` / `formation_fade_per_cell_sec` in the data. This file only measures and recommends; no
product, data or test file was changed.
Raw lines: `formation-timing-raw.txt` (same folder). Date: 2026-10-25, Godot 4.6.3 headless.

## Method

- **Script (scratch, not in repo):** `formation_probe.gd` in the session scratchpad. It is a copy of `hit_probe.gd`
  (itself a copy of `deck_sim.gd`), so matches run on the real objects: BossController (brain, mover, actor, drops),
  SwingArbiter → CutEffects, StatusEffects, TraitHost, BossLearning, the real FormationMap and CombatConfig. The
  boss's root-while-swinging lock (TD-017) is live because it lives in those classes.
- **Matches:** chapter-1 match data from `RunConfig.from_node(chapter 0, id, "battle", seed)`. The hero is kiem_si
  with the level-1 starter deck at full HP. 15 seeds per match id. The arena comes from the match:
  - square: goblin_scout, wolf, goblin_chief (45 matches)
  - rect: goblin_warrior, dire_wolf, goblin_shaman, wolf_alpha (60)
  - cross (variant): goblin_archer, forest_witch (30)
  - ring: **forced** `{"shape":"ring"}` on goblin_archer, goblin_brute, forest_witch (45). Chapter 1 has no ring match.
  - bonus boards: u_shape (variant): goblin_brute (15); staircase (variant): goblin_warlock (15)
- **Both rules see the same casts in the same match.** The real signature never fires: the bot's `_sig_ready()` is
  forced false, so Tram damage does not shorten matches. Each rule counts its own *virtual* readies, and the bot
  "fires" a rule the moment it is ready. After that, the rule is blocked for 3.0 s, the length of Tram's timed effect.
  - **Old rule:** the counter adds `cells.size()` of every player cast when the swing starts (like the deleted
    `SignatureCharge`, capped at 18). The rule is ready at 18, then resets to 0.
  - **New rule:** `FormationMap.init(grid.enemy_cells(), fade)`. On every player swing resolve (hit or miss) it calls
    `cover(result.cells)` and ticks with the sim dt (0.05 s). Complete while not active means ready, then `reset()`.
    Complete while the effect is active does nothing (the map is not reset), the same as
    `CombatView._cover_formation`.
  - **Fade settings, side by side in the same matches:** the data value 4.0/0.60 (through
    `CombatConfig.formation_fade_for`), plus 3.0/0.50, 5.0/0.80, 8.0/1.00 and 12.0/1.20. These are script
    parameters; `combat.json` was not changed.
- **Bot:** the existing deck_sim bot.
  - Cast cadence is 1.2–2.2 s plus windup.
  - It aims at the boss (AIM 0.9). It strikes right after the boss steps, re-targets onto boss swings and follows
    up pins.
  - Cell counts come from CELLS_WEIGHTS, or from the strike/interrupt windup budget.
  - Each cast is **one piece**: the real `pieces.json` placement of n cells that covers the target and as many of
    its neighbours as possible. It never joins two pieces.
  - **Finding:** this bot casts mostly **1-cell strikes**. On square, 520 of 694 casts were 1 cell. Mean cells per
    cast is about 1.4. Every cast lands near the boss.
- **Formation-aware variant (`--aware=P`):** with chance P per cast, the bot hunts the data-setting map instead. It
  picks the pieces.json placement of 3–5 cells (at least its own n) that covers the most "darkness"
  (Σ 1 − fraction_left), with +0.5 if it also covers the boss. Variants measured: P = 0, 0.25, 0.5, 1.0. It stands
  in for a player who works the map part of the time.

## Results

Columns per board: `readies/match` and `% matches with 0 / 1 / 2 / 3+`, then `first ready s` (mean over matches
that reached one, with n reached / n). "data" = 4.0/0.60, the current `combat.json`.

### A. Bot as-is (P = 0) — the bot's normal casting rhythm

| Board (enemy cells, data fade s) | match s | casts | old 18 | new data 4.0/0.60 | alt 3.0/0.50 | alt 5.0/0.80 | 8.0/1.00 | 12.0/1.20 |
|---|---|---|---|---|---|---|---|---|
| square (9, 9.4) | 35.9 | 15.4 | **0.82** (18/82/0/0) first 29.5 s, 37/45 | **0.02** (98/2/0/0) 1/45 | 0.00 | 0.09 | 0.22 | 0.42 |
| rect (12, 11.2) | 44.2 | 18.6 | **0.97** (10/83/7/0) first 30.2 s | **0.00** (100/0/0/0) | 0.00 | 0.00 | 0.05 | 0.08 |
| cross (11, 10.7) | 44.0 | 18.1 | **1.50** (17/40/27/17) first 23.8 s | **0.00** | 0.00 | 0.10 | 0.37 | 0.50 |
| ring (21, 16.6) | 67.6 | 29.0 | **2.09** (0/9/73/18) first 25.6 s | **0.00** | 0.00 | 0.00 | 0.02 | 0.02 |
| u_shape (9, 9.6) | 46.7 | 20.1 | 1.07 | 0.00 | 0.00 | 0.00 | 0.00 | 0.33 |
| staircase (10, 10.0) | 57.6 | 25.7 | 1.20 | 0.00 | 0.00 | 0.00 | 0.00 | 0.07 |

Peak lit share for the data setting: square 0.74, rect 0.67, cross 0.71, ring 0.61. The map stalls at about 2/3.
All matches were won, with no timeouts.

### B. Hunts the map 1 cast in 4 (P = 0.25)

| Board | match s | old 18 | new data 4.0/0.60 | alt 3.0/0.50 | alt 5.0/0.80 | 8.0/1.00 | 12.0/1.20 |
|---|---|---|---|---|---|---|---|
| square | 40.4 | 1.53 (4/49/36/11) | **1.22** (29/36/24/11) first 22.4 s, 32/45 | 0.89 (33/49/16/2) | 1.47 (20/33/31/16) | 1.67 | 1.73 |
| rect | 51.0 | 1.90 (5/32/38/25) | **0.52** (62/30/5/3) first 29.8 s, 23/60 | 0.37 (73/18/7/2) | 0.72 (47/40/10/3) | 0.97 | 1.10 |
| cross | 51.9 | 2.53 (0/33/20/47) | **0.67** (50/33/17/0) first 29.8 s, 15/30 | 0.20 (83/13/3/0) | 0.97 (40/27/30/3) | 1.10 | 1.23 |
| ring | 80.9 | 3.71 (0/0/24/76) | **0.16** (84/16/0/0) first 53.2 s, 7/45 | 0.02 (98/2/0/0) | 0.53 (49/49/2/0) | 0.84 | 1.00 |
| u_shape | 55.2 | 2.00 | 0.53 | 0.47 | 0.60 | 0.87 | 1.07 |
| staircase | 65.5 | 2.40 | 0.33 | 0.33 | 0.53 | 0.67 | 0.73 |

### C. Hunts the map 1 cast in 2 (P = 0.5)

| Board | match s | old 18 | new data 4.0/0.60 | alt 3.0/0.50 | alt 5.0/0.80 | 8.0/1.00 | 12.0/1.20 |
|---|---|---|---|---|---|---|---|
| square | 45.1 | 2.44 (2/36/22/40) | **2.80** (13/9/24/53) first 13.8 s | 2.36 (13/16/33/38) | 2.93 (7/13/27/53) | 3.09 | 3.11 |
| rect | 56.7 | 2.98 (3/12/23/62) | **2.08** (8/27/30/35) first 25.4 s | 1.50 (22/30/32/17) | 2.42 (5/18/32/45) | 2.55 | 2.58 |
| cross | 55.3 | 3.23 (0/20/23/57) | **1.73** (27/27/13/33) first 24.0 s | 1.13 (40/27/20/13) | 2.00 (17/30/13/40) | 2.13 | 2.27 |
| ring | 86.9 | 4.93 (0/2/7/91) | **1.33** (18/49/18/16) first 43.5 s | 0.49 (60/31/9/0) | 2.11 (7/31/16/47) first 33.4 s | 2.40 | 2.47 |
| u_shape | 61.8 | 2.87 | 2.27 | 1.67 | 2.47 | 2.60 | 2.67 |
| staircase | 70.5 | 3.60 | 2.00 | 1.60 | 2.13 | 2.33 | 2.33 |

### D. Always hunts the map (P = 1.0; almost every cast is a 5-cell piece)

| Board | match s (won / timeout) | old 18 | new data | alt 3.0/0.50 | alt 5.0/0.80 | 8.0/1.00 | 12.0/1.20 |
|---|---|---|---|---|---|---|---|
| square | 55.2 (100% / 0%) | 4.13 | 5.56 (first 9.4 s) | 5.18 | 5.58 | 5.60 | 5.60 |
| rect | 74.8 (95% / 5%) | 5.63 | 6.18 | 5.72 | 6.23 | 6.25 | 6.25 |
| cross | 75.8 (90% / 10%) | 6.03 | 5.17 | 4.00 | 5.27 | 5.30 | 5.30 |
| ring | 86.7 (98% / 2%) | 6.78 | 4.53 | 3.40 | 4.53 | 4.53 | 4.53 |
| u_shape | 87.2 (93% / 7%) | 6.60 | 6.93 | 6.53 | 6.93 | 6.93 | 6.93 |
| staircase | 106.4 (67% / 13%) | 8.07 | 7.07 | 6.67 | 7.07 | 7.07 | 7.07 |

## Reading

1. **Under the bot's normal play, the new rule almost never readies.** Old: 0.8–2.1 per match, inside or near the
   target. New (data): 0.00–0.02 per match on every board. No fade value fixes this; even 12.0/1.20 gives ≤ 0.5.
   The limit is throughput. The bot lights about 1.4 cells per cast at about 0.42 casts/s, all near the boss, so it
   cannot keep 9–21 cells lit at once. Fade only matters once the player spreads casts across the enemy half.
2. **With deliberate hunting, the data setting is close but depends on board size.** At P = 0.5, data gives
   1.3–2.8 per match, inside 1–3 on every board. At P = 0.25 it is below target everywhere except square, and ring
   collapses (0.16 per match, first ready at 53 s). The per-cell term (0.6 s) is too small for the large ring.
3. **3.0/0.50 is strictly worse** for the goal: lower on every board, and ring is about 0 at P ≤ 0.5.
4. **5.0/0.80 is the balanced option.**
   - P = 0.5: 2.0–2.9 on every board. All are inside the target; the ring spread is 7/31/16/47 %.
   - P = 0.25: 0.5–1.5 instead of 0.16–1.22.
   - It does not raise the ceiling: at P = 1.0 it equals data within 0.05.
   - 8.0/1.00 and 12.0/1.20 add little more at P = 0.5 and push square to 3.1 (over target).
5. **The ceiling is set by cast rate and the 3 s block, not by fade.** At P = 1.0 every setting saturates at 4.5–7
   per match. The old rule was just as high there (4–8). If players hunt hard, fade cannot hold the signature to
   1–3 per match. That needs a design lever, not a fade value: for example a post-signature lockout longer than the
   3 s effect, or a ready count cap. This is a question for game-designer, not something to fix in tuning.

## Recommendation

- **Change `formation_fade_base_sec` 4.0 → 5.0 and `formation_fade_per_cell_sec` 0.6 → 0.8.** Fades become square
  12.2 s, rect/cross 14.6 / 13.8 s and ring 21.8 s. This keeps every board inside 1–3 readies per match for a
  player who spends about half their casts on the map. It also stops the ring collapse at lighter hunting, and it
  does not raise the hard-hunting ceiling.
- **Flag to game-designer:** under the bot's current strike-heavy rhythm (≈ 1-cell casts at the boss), the
  formation map is effectively unreachable at any fade. The Story 029 target "1–3 as before" holds only if players
  spread casts. Whether that trade (damage now vs signature later) is the intended fantasy should be confirmed
  with a playtest. Whether hard hunting (4–7 per match) needs a cap is a separate design call.

## Caveats

- The bot casts **one piece per cast and never joins pieces** (Story 028). Joins would raise cells per cast and the
  readies of both rules.
- The hunting heuristic is greedy: maximum darkness covered, +0.5 if it covers the boss. A human may plan better or
  worse. P is a proxy for "how much the player cares about the map", not a measured human behaviour.
- The real signature never fires, so Tram's ×2 cells and lifesteal do not shorten matches. In game, matches with
  several readies would be somewhat shorter, so readies per match here are a little high for P ≥ 0.5.
- Hunting casts often miss the boss. At P = 1.0 matches get longer, with timeouts up to 13 % on staircase, which
  inflates readies per match there.
- Chapter 1 has no ring match. Ring uses three chapter-1 bosses' stats on a forced ring arena. Cross, u_shape and
  staircase are seeded variants, so the enemy cell count can differ by ±1 from the base shape. The table shows the
  mean.
- Only kiem_si with the level-1 starter deck at full HP, on battle nodes. Rewards, deck growth and other characters
  were not run. sat_thu's faster steps and phap_su's wide_caster (bigger casts) would shift both rules.
- The 18-cell "old" counter is a reconstruction of the deleted `SignatureCharge`: cells added at cast start, capped
  at 18, reset on fire, ready only while the effect is not active.
- In the raw file, the run labelled `aware=0.3` is the `--aware=0.25` run, a print-rounding artefact.
