# Story 038 (2026-10-26) — Kiep levels simulation

Tool: `tools/balance/deck_sim.gd --world --seeds=70 --kiep=0..10` (build policy, no fate, bot dodge 0.85 = TD-006 default)
and `--kiep-only=0..10` (one level's rules alone). Raw output: `simulation-kiep-raw.txt` (sections `===== <run>`; the first
four are the story's order, the `v2/` ones the shipped order). A 70-seed cell at these rates has about +-4 points of noise.

## Verdict

The Kiep curve targets of the story (level 10 still winnable at >= 3 %, win(k) < win(k-2), level 10 run <= 55 min) **cannot
be met yet**: the run win rate at level 0 is only 6-13 % (Story 040 targets 30-45 %), so every hard rule pushes it to 0 and
the curve is buried in noise. User decision (2026-10-26): reorder the ten rules by measured difficulty now, keep the
starting numbers, and tune the curve in Story 040 (its Part C already has "win rate falls monotonically from Kiep 0 to
Kiep 10"). What this story can and does show: every rule applies (tests), the reordered curve falls step by step with no
cliff, and no level makes the game easier.

## 1. Each rule alone (`--kiep-only`, Kiem si, level 0 = 12.9 %)

| Rule (story order) | Win % | vs level 0 |
|---|---|---|
| boss_extra_trait (region bosses) | 0.0 | -12.9 |
| node_weight (danger x2) | 12.9 | 0.0 (*) |
| rest_heal_mult 0.67 | 12.9 | 0.0 (*) |
| player_drop_mult 1.15 | 1.4 | -11.4 |
| gold_mult 0.75 | 10.0 | -2.9 |
| boss_swing_mult 0.909 (10 % faster windup) | 1.4 | -11.4 |
| floor_heal_mult 0.5 | 1.4 | -11.4 |
| max_hp_mult 0.85 | 1.4 | -11.4 |
| floor_shift +1 (final hp x1.1) | 5.7 | -7.1 |
| shop_price_mult 1.2 + final extra trait | 2.9 | -10.0 |

(*) Not measurable with the bot: its node policy takes treasure over rest and battle over danger, and the middle column
always holds a rest or treasure, so it never enters an extra danger node and rarely rests. A player who rests or is
forced through danger nodes will feel both rules; they stay as the gentle first levels.

## 2. Stacked curve, run win % by level

Story order (first run): Kiem si 12.9 -> 0.0 from level 1 on (the region-boss extra trait first); a 12.9-point cliff at
level 1.

Shipped order (gentlest first): 1 gold, 2 rest, 3 danger, 4 floor shift, 5 shop price + final trait, 6 floor heal,
7 max HP, 8 player drop, 9 boss swing, 10 region-boss extra trait.

| Level | Kiem si | Phap su | Sat thu |
|---|---|---|---|
| 0 | 12.9 | 7.1 | 5.7 |
| 1 | 10.0 | 7.1 | 7.1 |
| 2 | 10.0 | 5.7 | 2.9 |
| 3 | 10.0 | 5.7 | 2.9 |
| 4 | 1.4 | 2.9 | 4.3 |
| 5 | 2.9 | 1.4 | 0.0 |
| 6 | 1.4 | 0.0 | 1.4 |
| 7 | 0.0 | 0.0 | 1.4 |
| 8 | 0.0 | 0.0 | 0.0 |
| 9 | 0.0 | 0.0 | 0.0 |
| 10 | 0.0 | 0.0 | 0.0 |

Checks (Kiem si): step `win(k) <= win(k-1) + 3` PASS; no drop > 12 points PASS (worst 8.6, was 12.9); skip `win(k) <
win(k-2)` FAIL only where the curve is flat (levels 2-3 have no bot effect, 7-10 are at 0); level 10 winnable FAIL;
level 10 minutes FAIL (no wins). Deaths move to earlier floors level by level (Kiem si deaths on floors 1-2: 27 at level
0, 67 at level 10). DEFERRED to Story 040 with the base win rate.
