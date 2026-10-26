# Story 035 — fate policy and final-match simulation

Tool: `tools/balance/deck_sim.gd --world --fate=execute|spare|alternate --relic-policy=pick` (build policy, bot dodge 0.85 = TD-006
default, shops greedy and events risky as shipped). Raw output: `simulation-fate-raw.txt` (sections `===== <run> / <character>`).
"Final probe" runs make floors 1-5 trivial (`--world-set=heal:1.0,scale.1..5.hp_mult:0.05`) so every run reaches the final match at
full HP; they measure the final match alone. 30 seeds per probe cell (about +-9 points of noise), 70 seeds per run cell.

Story targets (F4): final-match win when reached 35-55 %; the final match <= 40 % of deaths; all-execute beats all-spare by 8-20 run-win points.

## 1. The final boss as first written (starting values)

Phase 2 = `seal_caster` + `thorn_field` + `row_burner`, `aggressive`, step x0.85, strong card list, not rooted while swinging.

| Run (70 seeds) | Kiem si | Phap su | Sat thu |
|---|---|---|---|
| execute: final reached / won | 7 / 1 | 5 / 1 | 1 / 0 |
| spare: final reached / won | 13 / 0 | 11 / 0 | 7 / 0 |
| final probe (30): final won | 0 % | 0 % | 0 % |

The bot died with the boss at about 45-50 % HP (the phase threshold): the final was unwinnable. For comparison the old final
`mist_lord` in the same probe was won 66.7 / 83.3 / 70.0 %.

## 2. Finding the cause (final probe, 30 seeds, win % when reached)

| Variant | Kiem si | Phap su | Sat thu |
|---|---|---|---|
| starting phase 2 | 0.0 | 0.0 | 0.0 |
| final HP x1.0 instead of x1.5 (130) | 3.3 | 6.7 | 0.0 |
| final HP x0.8 (104) | 3.3 | 13.3 | 3.3 |
| phase 2 without `thorn_field` | 3.3 | 6.7 | 3.3 |
| phase 2 identical to phase 1 (only the shift) | 43.3 | 56.7 | 53.3 |
| v5: thorn + row_burner, balanced, phase-1 cards, rooted | 16.7 | 13.3 | 6.7 |
| v7: thorn + row_burner, aggressive, phase-1 cards, rooted | 23.3 | 30.0 | 16.7 |
| v8: thorn + row_burner, balanced, step x0.85, NOT rooted | 0.0 | 0.0 | 0.0 |
| **v6 (shipped): row_burner, aggressive, phase-1 cards, rooted, step x1.0** | **53.3** | **56.7** | **50.0** |

- The phase transition itself (invulnerable 1 s, cast cancelled) is fine: a phase 2 equal to phase 1 lands in the target band.
- **An unrooted boss is the killer**: with `root_while_swinging: false` the bot cannot land a cast (0 % even with a balanced brain).
- `thorn_field` costs about 30 points (v6 against v7); the strong card list and the faster step add more.

## 3. Shipped data (v6) on real runs (70 seeds)

| Policy | Kiem si | Phap su | Sat thu |
|---|---|---|---|
| execute: run win % | 5.7 | 4.3 | 0.0 |
| execute: final reached / won (win % when reached) | 7 / 4 (57.1) | 5 / 3 (60.0) | 1 / 0 (0.0) |
| spare: run win % | 7.1 | 8.6 | 5.7 |
| spare: final reached / won (win % when reached) | 13 / 5 (38.5) | 11 / 6 (54.5) | 7 / 4 (57.1) |
| final share of deaths (execute / spare) | 4.5 / 12.3 % | 3.0 / 7.8 % | 1.4 / 4.5 % |

Targets: final win when reached is inside or near 35-55 % (few reached runs: 1-13 per cell, so +-15 points of noise); the final is far below
40 % of deaths (PASS). **Execute does NOT beat spare** (it is 1.4-5.7 points WORSE): executing runs reach the final less often (7/5/1 against
13/11/7). Probable cause, not proven: the bot takes the rarest relic of the offer and the execute pool (rare and above) holds `huyet_an`
(epic, a known trap for the bot, TD-028), plus the relics the bot cannot use (TD-028). The run win itself (0-9 %) is low because the floors
before the final are hard (TD-027, TD-029, TD-030); that belongs to Story 040.

## Applied

- `assets/data/chapters.json` `an_dai_keeper` phase 2: `traits` seal_caster + row_burner (thorn_field removed), `aggressive`, `boss_step_cooldown_mult`
  1.0 (was 0.85), no `boss_cards` (keeps phase 1's list), `root_while_swinging` true (was false). Phase 1, HP 130, threshold 0.5, shift 1.0 s unchanged.
- `world.fate` unchanged (3 offers, min rarity rare): changing it cannot fix a bot that picks a trap relic.
- `tests/unit/run/final_match_data_test.gd` and `assets/data/schema.md` follow the new phase 2.
