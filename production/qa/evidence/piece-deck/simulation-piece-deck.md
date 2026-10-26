# Story 034 — piece deck simulation

Tool: `tools/balance/deck_sim.gd --world --seeds=70 --characters=<c> --piece-deck=<spec>` (build policy, shops greedy,
events risky, bot dodge 0.85 = TD-006 default). The deck is fixed for the bot from the first match of the run (no ink
offers, no removals in play), so every configuration is the deck a player could only reach later in a real run.
Raw output: `simulation-piece-deck-raw.txt` (sections `===== <config> / <character>`). Data at the time of the run:
`rewards.json` `piece_rewards` as shipped (min_shapes 5, mult_max 4, run_only_weight 6), Story 033 economy.

Noise: a 70-seed cell has about +-7 run-win points of noise (Story 032 measurement), the three-character mean about +-4.

## Run win % (Kiem si / Phap su / Sat thu) and the change against base

| Config | Spec | Run win % | Change (points) | Mean change |
|---|---|---|---|---|
| base | start deck through `weights_for_match` (same numbers as no flag) | 18.6 / 14.3 / 5.7 | — | — |
| remove mono | `remove:mono` | 40.0 / 25.7 / 11.4 | +21.4 / +11.4 / +5.7 | +12.8 |
| remove mono, bar2 | `remove:mono,bar2` | 34.3 / 38.6 / 14.3 | +15.7 / +24.3 / +8.6 | +16.2 |
| small_out | `remove:mono,bar2,bar3` | 32.9 / 27.1 / 4.3 | +14.3 / +12.8 / -1.4 | +8.6 |
| big_out | `remove:plus5,u5,bar5` | 18.6 / 17.1 / 11.4 | 0.0 / +2.8 / +5.7 | +2.8 |

## Combat measures (Kiem si; the other two characters follow the same pattern, see raw)

| Config | Casts / match | Cells / cast | Player hit % | Joins / match | Featured / match | Interrupts landed / suffered | Region clear % |
|---|---|---|---|---|---|---|---|
| base | 23.06 | 3.28 | 33.3 | 0.62 | 0.09 | 2.79 / 1.55 | 81.1 |
| remove mono | 21.65 | 3.57 | 33.7 | 0.36 | 0.08 | 2.54 / 1.55 | 86.2 |
| remove mono, bar2 | 20.87 | 3.83 | 32.4 | 0.14 | 0.02 | 2.26 / 1.69 | 84.8 |
| small_out | 21.45 | 4.00 | 31.8 | 0.09 | 0.00 | 2.08 / 1.87 | 85.8 |
| big_out | 23.61 | 3.09 | 34.5 | 0.65 | 0.11 | 3.08 / 1.45 | 78.8 |

No configuration hit the fallback rule (0 fallback matches in every run: every shipped arena fits some shape of each deck).

## Findings

1. **Removing small shapes is a dominant strategy.** Removing ONE shape (`mono`) already raises the run win by
   +12.8 points on the three-character mean (+21.4 for Kiem si); removing two raises it by +16.2. The story's threshold is
   +10 points. Removing the large shapes is not dominant (+2.8, inside the noise).
2. **Why.** The hit rate barely moves when small shapes go (33 % in every config); the cast simply carries more cells
   (3.28 -> 3.57 -> 3.83 -> 4.00 cells per cast) and damage scales with cells, while the number of casts drops only a little
   (23 -> 21). A small piece buys no speed the bot can turn into damage. Joining pieces and featured shapes become rare
   (joins 0.62 -> 0.09 per match), which the bot does not miss. The base drop table makes it worse: `mono` and `bar2` are
   28 of the 68 weight points in `ch1`.
3. **The story's levers cannot fix it.** `min_shapes` only limits HOW MANY shapes go; blocking the first removal needs
   `min_shapes` 13 (removal disabled). `mult_max` and `run_only_weight` act on inked shapes and leave a one-removal deck
   untouched. So no value was changed: the shipped data stays `min_shapes` 5, `mult_max` 4, `run_only_weight` 6.
4. **What would fix it (needs a design decision, outside this story):** lower the base weight of `mono` / `bar2` in
   `pieces.json` (a global balance change: it also raises the base win rate, so it belongs with Story 040's rebalance),
   or give small casts a real advantage (faster windup, a cheaper cast, or damage that does not scale only with cells), or
   make removal tokens rarer (one per run, no shop service). The real-play effect is smaller than measured here because a
   player reaches a thinned deck only after the first token (start: 1) or a shop, not from the first match.
