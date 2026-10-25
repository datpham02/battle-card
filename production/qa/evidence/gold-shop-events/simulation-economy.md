# Story 033 — economy simulation (gold, shops, events)

Tool: `tools/balance/deck_sim.gd --world --seeds=70 --characters=<c> --shop-policy=<p> --event-policy=<e>`,
build policy, bot dodge 0.85 (TD-006 default, not anchored to a human). Raw output of every run below:
`simulation-economy-raw.txt` (sections `===== <run> / <character>`).

Story targets (`ECONOMY TARGETS` line): earned per run 350–450, items per run 4–6, median gold left in
WON runs < 100, the first shop offered is affordable (median gold >= cheapest item).

Note on noise: 70 seeds give 3–17 won runs per character, so the "WON" columns rest on few runs.

## Runs

| Run | Data | Shop / event policy |
|---|---|---|
| without | first numbers (prices 40/60/85 cards, 75/100/130 relics; 2 guaranteed shops, shop_weight 0.3) | none / leave |
| with | same data | greedy / risky |
| p075 | prices x0.75 through `--economy-set` | greedy / risky |
| final | prices written: cards 30/40/60, relics 50/70/90 | greedy / risky |
| shops3 | + `world.special_nodes` guaranteed_shops 3, shop_weight 0.6 (rejected: events fell to 45 per 1000 regions) | greedy / risky |
| eager | shops3 data | eager / risky (a shop beats a treasure once the bot holds 60 gold) |
| ship_greedy | **shipped data**: prices of `final`, guaranteed_shops 3, shop_weight 0.0 | greedy / risky |
| ship_eager | **shipped data** | eager / risky |

## Results (Kiem si / Phap su / Sat thu)

| Run | Run win % | Earned per WON run (median) | Left in WON runs (median) | Shops per run | Items per run (all; WON) |
|---|---|---|---|---|---|
| without | 24.3 / 21.4 / 7.1 | — | — | — | 0 |
| with | 17.1 / 12.9 / 7.1 | 375 / 351 / 375 | 235 / 283 / 324 | 0.70 / 0.69 / 0.56 | 0.96;1.67 / 0.93;1.44 / 0.69;1.00 |
| p075 | 18.6 / 15.7 / 8.6 | 375 / 366 / 390 | 270 / 270 / 277 | 0.70 / 0.64 / 0.56 | 1.24;2.08 / 1.09;1.64 / 0.90;1.67 |
| final | 24.3 / 12.9 / 5.7 | 378 / 366 / 375 | 278 / 272 / 249 | 0.69 / 0.61 / 0.54 | 1.33;1.94 / 1.11;2.11 / 0.91;1.50 |
| shops3 | 20.0 / 17.1 / 4.3 | 374 / 365 / 389 | 216 / 212 / 212 | 1.01 / 0.84 / 0.71 | 1.77;2.86 / 1.46;2.75 / 1.21;3.33 |
| eager | 24.3 / 17.1 / 5.7 | 349 / 346 / 338 | 119 / 144 / 160 | 1.91 / 1.76 / 1.41 | 2.44;3.76 / 2.31;3.75 / 1.89;3.25 |
| **ship_greedy** | 18.6 / 14.3 / 5.7 | 385 / 371 / 378 | 216 / 210 / 214 | 0.96 / 0.77 / 0.66 | 1.73;2.85 / 1.36;2.80 / 1.11;2.75 |
| **ship_eager** | 22.9 / 12.9 / 7.1 | 353 / 357 / 343 | 118 / 185 / 115 | 1.87 / 1.54 / 1.30 | 2.50;3.88 / 2.13;4.00 / 1.86;3.60 |

The first shop offered is affordable in 100 % of runs from `p075` on (80–82 % with the first prices).

## Findings

1. **Price is not what leaves gold unspent.** Cutting prices to x0.7 changed the gold left in won runs by
   nothing measurable (235–324 → 249–278). The bot buys about 1.3–1.9 items per shop visit at any price;
   it simply sees too few shops (0.5–0.7 per run).
2. **Shop count and route are.** Three guaranteed shops cut the gold left in won runs to about 210–216; a route that prefers a shop to a treasure when holding gold cuts it to 119–160 and raises won
   runs to 3.3–3.8 items. The `greedy` bot always takes a treasure first, which a player with 200 gold
   would not.
3. **A floor of unspendable gold remains.** The floor-5 boss drop (35 x 1.4 = 49) and the final match come after
   the last shop the run can reach, so roughly 50–100 gold is left by construction.
4. **Win rate.** Shops plus events cost 0–9 points against walking past them (`without` vs `with`). With
   the shipped data: greedy route Kiem si / Phap su / Sat thu 18.6 / 14.3 / 5.7, eager route 22.9 / 12.9 / 7.1,
   against 24.3 / 21.4 / 7.1 without shops and events. Phap su loses 7–8.5 points, at the edge of the ±7-point
   noise of a 70-seed cell; not explained (the bot buys relics first, and Phap su gains from start pieces,
   see Story 032). Sat thu stays too hard (TD-027).
5. **Shops crowd out events.** A region's middle column has 2–3 nodes; a shop there leaves an event room only
   if 2 fights remain. shop_weight 0.6 cut events to 45 per 1000 regions (test `shop_event_nodes_test`
   failed); the shipped shop_weight 0.0 with 3 planned shop floors gives 600 shops and 122 events per 1000
   regions (first data: 500 and 111).
6. **Events** are visited 0.13–0.29 times per run by the risky bot; curse damage is 0 (the bot holds no
   curse long enough); `tran_thach` extra fights: 2–3 per 70 runs.

## Applied

- `assets/data/economy.json`: card prices 40/60/85 → **30/40/60**, relic prices 75/100/130 → **50/70/90**.
- `assets/data/chapters.json` `world.special_nodes`: guaranteed_shops 2 → **3** (3 of floors 2–5 always have a
  shop), shop_weight 0.3 → **0.0** (no extra random shop: it took the event's place).
- `tests/unit/run/shop_event_nodes_test.gd`: the data check accepts shop_weight 0.
- `tools/balance/deck_sim.gd`: new `--shop-policy=eager`.

## Still missing the targets (tech debt)

- Gold left in won runs 115–185 with the eager route (target < 100) and 210–216 with the greedy route.
- Items per won run 3.6–4.0 with the eager route (target 4–6, at the bottom edge), 2.8 with the greedy route.
- Earned per run (all runs) 156–218 against 350–450: the target fits a won run (338–389), not the mean over
  runs that die on floors 1–3; the target needs restating as "per won run".
- A shop between the floor-5 boss and the final match would let the last 50–100 gold be spent; this is a map
  design change, not tuning, so it is left for gate 8 playtest.
