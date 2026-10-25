# Story 030 Phần C: signature balance after the rework (bot, scratch)

Re-measured 2026-10-25 after the user reordered Thiên Hỏa. Probe (scratch): `sigbal_probe.gd`, a copy of Story 029's `sigcd_probe.gd`, patched for the reorder as described below. Grep'd lines: `signature-balance-raw.txt` (new run first, the previous run after it).

## Previous measurement: ignite, then detonate (rejected)

- Old order: every lit formation cell was ignited and the whole burn was detonated in the same use.
- With the placeholders (burn 2.0 s / tick 0.5 / 1.5 per tick, detonate ×2) each lit cell was worth about 12 damage: 108 on a 3×3 board, 144 on 4×3.
- Four-board mean value/min at P = 0.5: **Trảm 13.2 / Thiên Hỏa 129.7 / Ảnh Bộ 9.0**, about 10 : 1. One use usually killed the boss.
- The data-only fix that met the target cut the fire to 0.2 per lit cell (`burn_duration_sec` 0.5, `burn_damage_per_tick` 0.1, cd 20).
  - That made "set the whole formation ablaze" invisible: the fire was detonated in the same frame and was worth almost nothing.
  - Most of the value came from card burn.
- Rejected by the user. Separately, Ảnh Bộ `small_mult` 2.0 → 1.75 from that run was kept and is in the data.

## New order (implemented in `src/signatures/thien_hoa.gd`)

1. **Detonate** the burn already on the enemy half: `detonate_mult` × remaining burn damage, then clear it.
2. **Reset** the cooldown of every `effect: burn` card.
3. **Ignite** every lit enemy-half formation cell `burn_stacks` times with `burn_duration_sec` / `burn_tick_sec` / `burn_damage_per_tick`.
   - This is a lasting sea of fire. It hurts the boss while it stands in it and blocks its path, because the boss brain avoids burning cells (`burn_avoid`).
   - It is **not** detonated in the same use.

## Method

- Same harness, matrix and seeds as the previous run:
  - real combat objects and the real `tram` / `thien_hoa` / `anh_bo` signatures;
  - chapter 1, starter deck at level 1;
  - boards square (9 cells), rect (12), cross (11), ring (21);
  - about 30 matches per cell; dt = 0.05.
- Formation-aware bot with chance P = 0.5 / 0.25. Bot activation rules are unchanged (Story 021).
  - Thiên Hỏa fires when the remaining burn is ≥ 15 or ≥ 2 enemy cells burn; otherwise after holding 6 s.
- **Probe change for the reorder.** `last_damage()` is now only the detonation, so the fire is credited separately:
  - every burn tick the boss takes on a cell set on fire by the signature, while that fire lasts, is added to the signature's damage;
  - each tick is capped at the fire's own damage per tick, so a burn card stacked on top keeps its share.
  - The probe also counts boss hits on the player per minute during the fire and outside it.
- Value per use = the signature's extra damage, plus Trảm's real HP healed, capped at the boss HP left.
- value/min = total value / total match minutes. "mean val/min" = plain mean of the four boards.
- Each cell reads: uses/match / value per use / value per minute / match seconds / win rate.
- Sweeps override params in the script only (`--set=key:value`). The chosen values were then written to `characters.json` and re-run without overrides.

## Before: new order with the old Thiên Hỏa numbers, current data elsewhere

| tag | char | P | cd | square | rect | cross | ring | mean val/min |
|---|---|---|---|---|---|---|---|---|
| base | kiem_si | 0.50 | 25 | 1.30 / 11.6 / 23.4 / 39 / 100% | 1.31 / 7.7 / 11.8 / 51 / 100% | 1.43 / 7.1 / 11.9 / 51 / 100% | 1.83 / 4.4 / 5.7 / 84 / 93% | 13.2 |
| base | kiem_si | 0.25 | 25 | 0.83 / 10.2 / 13.7 / 37 / 100% | 0.53 / 6.9 / 4.6 / 48 / 100% | 0.80 / 9.0 / 8.7 / 50 / 100% | 0.60 / 8.2 / 3.9 / 75 / 97% | 7.7 |
| base | phap_su | 0.50 | 15 | 1.27 / 5.6 / 12.0 / 35 / 100% | 1.50 / 10.1 / 20.8 / 44 / 100% | 1.47 / 15.1 / 26.2 / 51 / 100% | 1.57 / 12.7 / 16.2 / 74 / 100% | 18.8 |
| base | phap_su | 0.25 | 15 | 0.93 / 5.7 / 8.7 / 37 / 100% | 0.66 / 6.2 / 5.3 / 46 / 100% | 0.83 / 14.4 / 14.8 / 49 / 100% | 0.57 / 17.8 / 8.2 / 74 / 100% | 9.2 |
| base | sat_thu | 0.50 | 12 | 1.67 / 3.7 / 11.0 / 34 / 100% | 1.75 / 2.6 / 5.7 / 48 / 100% | 1.70 / 2.6 / 5.9 / 46 / 100% | 1.70 / 2.7 / 3.9 / 70 / 100% | 6.6 |
| base | sat_thu | 0.25 | 12 | 1.33 / 5.8 / 14.2 / 33 / 100% | 0.63 / 4.5 / 4.3 / 39 / 100% | 0.73 / 4.9 / 5.1 / 43 / 100% | 0.43 / 5.4 / 2.2 / 64 / 100% | 6.4 |

- **Target not met.** Thiên Hỏa (18.8) is above Trảm (13.2) at P = 0.5: strongest : weakest = 2.84 : 1.
- Per use, Thiên Hỏa is about 5–6 from the detonation (card burn) plus about 5 from the fire. The fire at 2 s × 1.5 per 0.5 s is worth at most 6.
- **Trảm : Ảnh Bộ is already 1.99 : 1 at P = 0.5** (13.2 vs 6.6), whatever Thiên Hỏa does.
  - With the ~2 : 1 limit, Thiên Hỏa must fall between Ảnh Bộ and Trảm at both P: 6.6–13.2 at P = 0.5 and 6.4–7.7 at P = 0.25.

## Sweep: Thiên Hỏa fire numbers (`burn_duration_sec` d, `burn_damage_per_tick` p, `cooldown_sec` cd)

`burn_stacks` 1, `burn_tick_sec` 0.5 and `detonate_mult` 2.0 are fixed. Fire worth per use ≤ d / 0.5 × p (if the boss stands in it the whole time).

| config | P | square | rect | cross | ring | mean val/min | fire/use | Trảm ≥ TH ≥ Ảnh Bộ | strongest : weakest |
|---|---|---|---|---|---|---|---|---|---|
| d2 p0.5 cd15 | 0.50 | 4.1 | 15.1 | 20.9 | 12.3 | 13.1 | 1.7 | yes | 1.99 |
| d2 p0.5 cd15 | 0.25 | 2.9 | 2.7 | 11.4 | 6.7 | 5.9 | 1.7 | no | 1.30 |
| d2 p0.5 cd20 | 0.50 | 12.1 | 12.0 | 14.9 | 11.6 | 12.7 | 1.7 | yes | 1.99 |
| d2 p0.5 cd20 | 0.25 | 2.8 | 2.6 | 11.2 | 6.7 | 5.8 | 1.6 | no | 1.33 |
| d2 p1.0 cd15 | 0.50 | 8.1 | 18.2 | 23.9 | 14.2 | 16.1 | 3.4 | no | 2.43 |
| d2 p1.0 cd15 | 0.25 | 5.6 | 4.2 | 13.2 | 7.4 | 7.6 | 3.3 | yes | 1.20 |
| d2 p1.0 cd20 | 0.50 | 15.7 | 14.7 | 17.1 | 13.6 | 15.3 | 3.4 | no | 2.31 |
| d2 p1.0 cd20 | 0.25 | 5.4 | 4.1 | 12.8 | 7.4 | 7.4 | 3.2 | yes | 1.20 |
| d2 p1.5 cd15 (old numbers) | 0.50 | 12.0 | 20.8 | 26.2 | 16.2 | 18.8 | 5.0 | no | 2.84 |
| d2 p1.5 cd15 (old numbers) | 0.25 | 8.7 | 5.3 | 14.8 | 8.2 | 9.2 | 4.9 | no | 1.43 |
| d2 p1.5 cd20 | 0.50 | 19.2 | 17.5 | 19.5 | 15.7 | 18.0 | 5.0 | no | 2.71 |
| d2 p1.5 cd20 | 0.25 | 8.4 | 5.1 | 14.3 | 8.1 | 9.0 | 4.7 | no | 1.39 |
| **d3 p0.5 cd15 (chosen)** | 0.50 | 6.9 | 16.8 | 16.6 | 10.5 | 12.7 | 2.5 | yes | 1.99 |
| **d3 p0.5 cd15 (chosen)** | 0.25 | 3.8 | 3.3 | 11.9 | 6.9 | 6.5 | 2.5 | yes | 1.20 |
| d3 p0.5 cd20 | 0.50 | 9.1 | 11.8 | 12.7 | 12.6 | 11.6 | 2.6 | yes | 1.99 |
| d3 p0.5 cd20 | 0.25 | 3.6 | 3.3 | 11.8 | 6.9 | 6.4 | 2.5 | no | 1.21 |
| d3 p1.0 cd15 | 0.50 | 12.0 | 21.5 | 20.7 | 13.2 | 16.9 | 4.9 | no | 2.54 |
| d3 p1.0 cd15 | 0.25 | 7.5 | 5.2 | 14.6 | 7.8 | 8.8 | 4.8 | no | 1.36 |
| d3 p1.0 cd20 | 0.50 | 14.4 | 16.7 | 17.0 | 15.1 | 15.8 | 5.2 | no | 2.38 |
| d3 p1.0 cd20 | 0.25 | 7.2 | 5.2 | 14.3 | 7.8 | 8.6 | 4.9 | no | 1.34 |
| d3 p1.5 cd15 | 0.50 | 17.4 | 26.4 | 24.7 | 16.1 | 21.1 | 7.3 | no | 3.19 |
| d3 p1.5 cd15 | 0.25 | 11.0 | 6.9 | 17.0 | 8.6 | 10.9 | 7.1 | no | 1.69 |
| d3 p1.5 cd20 | 0.50 | 19.3 | 21.4 | 21.1 | 17.9 | 19.9 | 7.5 | no | 3.01 |
| d3 p1.5 cd20 | 0.25 | 10.8 | 6.8 | 16.4 | 8.6 | 10.7 | 7.3 | no | 1.65 |
| d4 p0.5 cd15 | 0.50 | 19.0 | 14.5 | 14.3 | 15.8 | 15.9 | 3.2 | no | 2.40 |
| d4 p0.5 cd15 | 0.25 | 5.1 | 4.1 | 13.5 | 7.4 | 7.5 | 3.1 | yes | 1.20 |
| d4 p0.5 cd20 | 0.50 | 9.1 | 12.5 | 14.7 | 12.0 | 12.1 | 3.4 | yes | 1.99 |
| d4 p0.5 cd20 | 0.25 | 5.0 | 3.6 | 15.3 | 7.4 | 7.8 | 3.0 | no | 1.21 |
| d4 p1.0 cd15 | 0.50 | 25.0 | 20.6 | 19.7 | 19.8 | 21.3 | 6.3 | no | 3.21 |
| d4 p1.0 cd15 | 0.25 | 10.2 | 6.0 | 16.3 | 8.5 | 10.2 | 6.1 | no | 1.59 |
| d4 p1.0 cd20 | 0.50 | 16.1 | 18.4 | 19.5 | 16.0 | 17.5 | 6.6 | no | 2.64 |
| d4 p1.0 cd20 | 0.25 | 9.9 | 5.3 | 17.7 | 8.5 | 10.3 | 5.8 | no | 1.60 |
| d4 p1.5 cd15 | 0.50 | 31.8 | 26.5 | 25.2 | 23.7 | 26.8 | 9.4 | no | 4.05 |
| d4 p1.5 cd15 | 0.25 | 15.2 | 8.0 | 19.1 | 9.6 | 13.0 | 8.9 | no | 2.01 |
| d4 p1.5 cd20 | 0.50 | 23.9 | 24.5 | 25.1 | 19.9 | 23.4 | 9.8 | no | 3.52 |
| d4 p1.5 cd20 | 0.25 | 14.9 | 7.2 | 20.0 | 9.6 | 12.9 | 8.7 | no | 2.00 |

- Only the passing configurations are listed below. The rest fail at least one P.
  - `d2 p0.5 cd15` (single key, 13.1 / 5.9) and `d2 p0.5 cd20` fall just under Ảnh Bộ at P = 0.25.
  - `d3 p0.5 cd20` (11.6 / 6.4) ties Ảnh Bộ at P = 0.25 and fails on rounding.
  - `d4 p0.5 cd20` (12.1 / 7.8) is just over Trảm at P = 0.25.
- **Only `d3 p0.5 cd15` passes both P.** No single-key change in the grid passes:
  - dmg/tick alone: 0.5 fails P = 0.25, 1.0 fails P = 0.5;
  - duration alone: 3 or 4 at p 1.5 overshoots;
  - cooldown alone: cd 20 at d2 p1.5 overshoots.
  - So the smallest passing change is two keys, with the cooldown left alone.

### Chosen values (written to `assets/data/characters.json`)

- `phap_su.signature.params.burn_duration_sec` 2.0 → **3.0**.
- `phap_su.signature.params.burn_damage_per_tick` 1.5 → **0.5**.
- Unchanged: `cooldown_sec` 15, `burn_stacks` 1, `burn_tick_sec` 0.5, `detonate_mult` 2.0.
- Fire per lit cell: at most 3 s / 0.5 s × 0.5 = 3 damage while the boss stands in it. It burns 1 s longer than before, so it blocks the boss's path for longer.
- Other characters unchanged: `kiem_si` cd 25; `sat_thu` `small_mult` 1.75 (already in the data), cd 12.

## After: applied data, re-run without overrides

| tag | char | P | cd | square | rect | cross | ring | mean val/min |
|---|---|---|---|---|---|---|---|---|
| base | kiem_si | 0.50 | 25 | 1.30 / 11.6 / 23.4 / 39 / 100% | 1.31 / 7.7 / 11.8 / 51 / 100% | 1.43 / 7.1 / 11.9 / 51 / 100% | 1.83 / 4.4 / 5.7 / 84 / 93% | 13.2 |
| base | kiem_si | 0.25 | 25 | 0.83 / 10.2 / 13.7 / 37 / 100% | 0.53 / 6.9 / 4.6 / 48 / 100% | 0.80 / 9.0 / 8.7 / 50 / 100% | 0.60 / 8.2 / 3.9 / 75 / 97% | 7.7 |
| applied | phap_su | 0.50 | 15 | 1.43 / 2.9 / 6.9 / 36 / 100% | 1.44 / 8.2 / 16.8 / 42 / 100% | 1.50 / 9.8 / 16.6 / 53 / 100% | 1.30 / 9.3 / 10.5 / 69 / 100% | 12.7 |
| applied | phap_su | 0.25 | 15 | 0.90 / 2.7 / 3.8 / 38 / 100% | 0.66 / 3.9 / 3.3 / 47 / 100% | 0.83 / 12.1 / 11.9 / 51 / 100% | 0.43 / 19.2 / 6.9 / 72 / 100% | 6.5 |
| base | sat_thu | 0.50 | 12 | 1.67 / 3.7 / 11.0 / 34 / 100% | 1.75 / 2.6 / 5.7 / 48 / 100% | 1.70 / 2.6 / 5.9 / 46 / 100% | 1.70 / 2.7 / 3.9 / 70 / 100% | 6.6 |
| base | sat_thu | 0.25 | 12 | 1.33 / 5.8 / 14.2 / 33 / 100% | 0.63 / 4.5 / 4.3 / 39 / 100% | 0.73 / 4.9 / 5.1 / 43 / 100% | 0.43 / 5.4 / 2.2 / 64 / 100% | 6.4 |

| P | Trảm | Thiên Hỏa | Ảnh Bộ | strongest : weakest | order |
|---|---|---|---|---|---|
| 0.50 | 13.2 | 12.7 | 6.6 | **1.99 : 1** | Trảm ≥ Thiên Hỏa ≥ Ảnh Bộ ✔ |
| 0.25 | 7.7 | 6.5 | 6.4 | **1.20 : 1** | Trảm ≥ Thiên Hỏa ≥ Ảnh Bộ ✔ |

- The applied run is identical to the sweep cell `d3 p0.5 cd15` (the bot is deterministic).
- Uses per match on square at P = 0.5: Trảm 1.30, Thiên Hỏa 1.43, Ảnh Bộ 1.67. All are ≤ 3.
- Thiên Hỏa per use at P = 0.5 is about 5.1 from the detonation plus 2.5 from the fire.
  - The fire lasts 2.4–2.7 s per use, because some matches end first.
- Win rate is 100 % everywhere except Trảm on ring (93 % at P = 0.5, 97 % at P = 0.25); Thiên Hỏa wins 100 % on every board.

### Boss hit rate during the fire (boss hits on the player per minute: all / during the fire / outside it; n = hits landed during the fire, all matches)

| P | square | rect | cross | ring |
|---|---|---|---|---|
| 0.50 | 1.38 / 0.00 / 1.54 (n=0) | 1.02 / 0.54 / 1.07 (n=1) | 1.13 / 0.00 / 1.23 (n=0) | 0.81 / 0.58 / 0.82 (n=1) |
| 0.25 | 1.42 / 0.81 / 1.47 (n=1) | 1.00 / 0.00 / 1.03 (n=0) | 1.46 / 0.90 / 1.49 (n=1) | 0.47 / 0.00 / 0.48 (n=0) |

- During the fire the boss lands fewer hits per minute than outside it on every board. Only 0–1 hits land in fire windows per 30 matches, though, so this is a hint, not a measurement.
- The bot does not step into the boss's half, so this measures only the boss's own disruption.

## Caveats

- **The margins are thin and within bot noise** (about 30 matches per cell, one seed set; differences under 10–15 % are not significant).
  - At P = 0.25, Thiên Hỏa 6.5 vs Ảnh Bộ 6.4.
  - At P = 0.5, Thiên Hỏa 12.7 vs Trảm 13.2.
  - The order between neighbours can flip with another seed set.
- **The ~2 : 1 limit is already used up by Trảm : Ảnh Bộ = 1.99 : 1 at P = 0.5**, independent of Thiên Hỏa.
  - That comes from `small_mult` 1.75 (Ảnh Bộ was 9.0/min at 2.0).
  - Any further nerf to Ảnh Bộ or buff to Trảm breaks the target; raising Ảnh Bộ is the lever if there should be headroom.
- **The per-board spread is large.**
  - Thiên Hỏa is weak on square (6.9 at P = 0.5 vs Trảm 23.4) and strong on rect / cross (16.8 / 16.6 vs Trảm 11.8 / 11.9).
  - Bigger boards light more cells, and the detonation of card burn matters more there.
  - Data cannot make every board 2 : 1. The target is judged on the four-board mean.
- **The fire is the minor part of Thiên Hỏa's value** (about 2.5 of about 7.6 per use). Most comes from detonating card burn ×2.
  - The fire's main effect is control: it lasts 3 s and the boss avoids it.
  - The bot model does not value that, and it does not show in value/min.
- **The bot still holds Thiên Hỏa up to 6 s** waiting for card burn. A player who fires at once gets more fire uses and less detonation; not re-measured.
- **Ảnh Bộ's no-cooldown steps (dodging value) are not counted.** Only damage and heal are.
- **Narrow scope:** starter deck at level 1, chapter 1 bosses, no joins, no upgrades. Burn-heavy decks raise the detonation further.
- The previous run's tables (ignite-then-detonate, its sweeps and its recommendation) are superseded. Its raw lines are kept at the end of the raw file.
