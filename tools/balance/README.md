# Balance tools (`tools/balance/`)

Headless simulators that play the real v5 combat code with a scripted player. Use them to measure
chapter win rates and per-boss hit rates before and after changing data. They are **tools, not
tests**: the test runner never runs them, and the game never loads them. Story 026 moved them here
from session scratch.

| File | What it is |
|---|---|
| `sim_core.gd` | Shared harness. It builds one match the way `CombatView._ready` does and runs `CombatView._process`'s tick order headless. It contains the v5 player bot. Both tools preload it. |
| `deck_sim.gd` | Full-run simulator. It plays seeds × characters × chapters through the chapter map with the reward policy, then prints win %, boss hits per won run, and per-kind and per-match tables. `--world` (Story 031) plays whole 5-floor runs instead: region picks, short region maps, floor heal, the final match. |
| `hit_probe.gd` | Per-boss probe of one chapter. It measures hit rates for pieces, pairs and counters, the boss's attack rate on an idle player (TD-022), and full-bot matches for signature and formation numbers. |

Neither tool writes any file. Data experiments use the override flags below. These apply **in
memory only** and never edit `assets/data/*.json`.

## Running

Godot is not on PATH: use `C:/Users/ADMIN/AppData/Local/Microsoft/WinGet/Links/godot.exe`. Run from
the repo root. Send the output to a file and grep the verdict lines (see
`.claude/docs/context-management.md`, "Long Outputs").

```sh
GODOT=C:/Users/ADMIN/AppData/Local/Microsoft/WinGet/Links/godot.exe
# Full measurement (Story 026 Phần C): 70 seeds x 3 characters x chapters 1-3, build policy
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --seeds=70 --chapters=0,1,2 --policies=build > "<scratch>/deck_sim.out" 2>&1
grep -E "VERDICT|INFO|RESULT|runtime|SCRIPT ERROR" "<scratch>/deck_sim.out"
# World smoke (about 35 s): 5 seeds x 3 characters, 5 floors + final (Story 031)
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=5
# Smoke (about 35 s): 5 seeds, chapter 1
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --seeds=5 --chapters=0 --policies=build
# Per-boss probe of chapter 1: idle boss attack rate (TD-022) + piece/counter hit rates
$GODOT --headless --path . -s res://tools/balance/hit_probe.gd -- --chapter=0 --modes=idle,piece,counter --sizes=1,2,3,4,5
```

Always run with a timeout. A script error inside a SceneTree `_init` leaves Godot hanging instead of
quitting, so check `tasklist | grep -i godot` afterwards.

**Run time** (measured 2026-10-25): deck_sim with 5 seeds × 3 characters + onboarding on chapter 1
takes about 33 s. That is about 1.6 s per run, so the full 70 seeds × 3 chapters should take roughly
20–30 minutes; that is an estimate, it has not been timed. hit_probe takes under 1 s per cast mode per
boss and about 2 s per 60 s idle seed. In `bot` mode it takes 1–3 s per match.

Chapters are **0-based** on the command line (`--chapters=0,1,2` = ch1–ch3). The output prints them
1-based.

## Shared flags (both tools)

Bot model. Defaults are in `sim_core.gd` `DEFAULT_BOT`:

| Flag | Default | Meaning |
|---|---|---|
| `--dodge=P` | 0.85 | Chance to step out of a telegraphed boss swing aimed at the bot's cell. **TD-006 assumption, see below.** |
| `--gap=MIN,MAX` | 0.6,1.6 | Sim seconds from the end of the bot's swing to its next placement (uniform). |
| `--aim=P` | 0.9 | Chance a cast aims at the boss's cell (otherwise at a random enemy cell). |
| `--counter=P` | 0.5 | Chance to cast at once when the boss starts a swing. The boss is rooted while it swings. |
| `--place-sec=S` | 1.2 | REAL seconds to drag and drop one piece. Focus freezes the match during this time when it is ready; otherwise it runs at `menu_time_scale`. |
| `--join-sec=S` | 1.0 | REAL seconds to drag the second piece of a join (card menu, 0.2×). |
| `--choose-sec=S` | 0.8 | REAL seconds to tap a card (card menu, 0.2×). |
| `--join=P` | 1.0 | Chance to join a second piece when the planner says the union scores higher. |
| `--hold=N` | 1 | Placeable pieces held before a non-counter cast. 1 = cast as soon as one piece is held, which almost never joins. 2 = wait for a pair; this is how joins and featured casts appear. A full bag casts anyway. |
| `--aware=P` | 0.0 | Chance a placement lights dark formation-map cells instead of aiming at the boss. At 0, signatures rarely become ready. |
| `--aware-min=N` | 3 | Smallest piece a formation-aware placement uses. |
| `--sig=off\|ready\|rules` | rules | Signature activation. `rules` = the Story 021 rules: Tram before a cast of 3+ cells or when the boss is at 40 % HP or less; Thien Hoa on 15+ burn or 2+ burning enemy cells, otherwise after holding 6 s; Anh Bo when the boss is pinned, on a dodge, or at the next cast. `ready` fires as soon as the signature is usable. |
| `--dt=S` | 0.05 | Loop step in REAL seconds. The sim step is dt × scale. |

In-memory data overrides:

| Flag | Meaning |
|---|---|
| `--hp-mult=X` | Hero max HP × X. |
| `--boss-hp-mult=X` | `boss_max_hp` of every match × X. |
| `--think-mult=X` | `boss_think_interval_sec` and `boss_reaction_sec` × X. |
| `--combo=P` | Sets `combo_chance` on every match. |
| `--step-mult=X` | `boss_step_cooldown_mult` × X. |
| `--drop-mult=X` | Player piece spawn interval × X. |
| `--boss-drop-mult=X` | Boss drop intervals × X, on top of the match's `boss_drop_interval_mult`. |
| `--root=on\|off` | Forces `root_while_swinging`. |
| `--sig-cd=id:sec,...` | Signature `cooldown_sec` by signature id or character id, e.g. `--sig-cd=tram:20,anh_bo:10`. |
| `--hp-ids=id,id,...` + `--hp-ids-mult=X` | `boss_max_hp` × X only for the listed match ids (e.g. the chapter's miniboss and boss). |
| `--passive-set=key:value,...` | Sets a passive param on the played character when its passive has that key, e.g. `--passive-set=min_cells:4` (Mage `wide_caster`). |
| `--match-set=key:value,...` | Sets any RunConfig match key on every match, e.g. `--match-set=boss_defense:2,swing_speed_mult:1.1`. |
| `--no-zone-cards` | Story 027 "before" measurement: drops the zone cards (`SkillConfig.is_zone_card`: effect `seal` / `thorns`) from every match deck, and deck_sim also drops them from the reward pool (`RewardRoller.roll` exclude list). Same tool, same seeds as the "after" run. Boss zone traits (`seal_caster`, `thorn_field`) are NOT affected. |
| `--card-set=id.key:value,...` | Sets a key of a cards.json card in memory, e.g. `--card-set=ket_gioi.cooldown_sec:8,tran_gai.min_cells:4,long_an.rarity:epic`. Level-1 values; the card's `upgrade` deltas still apply on top. |
| `--relics=id,...` | Story 032. The player owns these relics (relics.json ids; unknown ids are dropped with a message) in every match. In deck_sim, the run starts with them. In hit_probe, every probe match has them. |
| `--relic-set=id.param:value,...` | Story 032. Sets a relic param in memory (relics.json is never written). A config-type relic takes a nested path: `--relic-set=an_don.mult:1.6,la_ban.formation_fade.mul:1.15,tui_rong.piece_spawn_interval.mul:1.4`. |

### Relics in the sim (Story 032)

`sim_core._relic_config_overrides` and `_setup_relics` port `CombatView._setup_relics`, `_apply_drop_overrides`, `_apply_status_overrides` and `_wire_relics`, as written by the combat wave on 2026-10-25. The relics are
created per match from `relic_ids` (`RelicRegistry.instantiate`). Their merged `config_overrides()` are
written into the per-match configs **before** FieldDrops, the bag, FormationMap and StatusEffects are
built:

| Key | Where it goes |
|---|---|
| `seal_sec`, `thorn_ran` | `arbiter.player_zone_overrides` = the merged overrides. CutEffects applies them after the card's own value, for the player's zone casts only. |
| `burn_max_stacks`, `han_stacks`, `han_damage` | `combat.burn_max_stacks`, `frost_stacks_to_burst`, `frost_burst_damage` (then `configure_status`). |
| `piece_spawn_interval`, `piece_freshness_sec`, `start_pieces` | The player's `FieldDropsConfig` copy, applied after `--drop-mult`. |
| `hold_slots` | Bag size, clamped to `HoldSlots.MAX_SLOTS`. |
| `focus_sec` | `FocusController.set_max_sec_override`, starting from the character's or the card config's value. |
| `formation_fade` | Fade seconds of `FormationMap`. |
| `signature_cooldown` | `_sig_cd_sec`. |

The hooks are wired as follows:

- **Damage.** It goes through `arbiter.player_relic_modifier`, the ONE relic damage point in CutEffects, right after the featured multiplier. It calls `RelicRegistry.fold_damage`, capped at `relic_damage_mult_cap`, with the `--relic-set` config.
- **Cast time.** It goes through `CutActor.cast_time_modifier`, the ONE windup point, which calls `fold_cast_time` once per begun player swing.
- **`an_chu`.** It replaces the featured bonus `damage_mult`.
- **`tam_hop`.** It raises the CastPlan piece limit, and the bot then tries one more greedy join per `join_sec`.
- **`phan_don`.** It puts a fresh piece into the first free bag slot.
- **`chi_khau` / `huyet_an`.** They heal or hurt the player through `CombatState`.

Each match counts its relic `triggered` signals (`relic_trig`). When CombatView's relic wiring changes, update this port to match it.

### Zone cards (Story 027)

The match gets `CombatView._wire_zones`'s wiring: a seal blocker on both movers (`UnitMover.add_blocker`),
each side's `UnitMover.is_cell_blocked` as the arbiter's leave-a-path test (`blocked_cell_fns`), and
`CombatConfig.zone_numbers()` on the arbiter. The boss's card list skips zone cards
(`SkillConfig.boss_card_order`), as in the game. Without this wiring zone cards would do nothing in the sim.

Bot rule (`SimCore._zone_choice`, decided in the card menu once the cast cells are placed; the bot only
sees its hand after placing, like a player):

1. Never when an available damage card in the hand would kill the boss, and never as the follow-up cast.
2. **Seal** when the boss has at most `ZONE_SEAL_MAX_EXITS` (3) open exits (enemy-half neighbours its
   mover may step into) and the cast covers all of them but one (at least one). The leave-a-path rule then
   leaves the boss one exit at most.
3. Else **thorns** when the cast covers at least `ZONE_THORN_MIN_COVER` (2) open exits (its dodge cells).
4. After a zone forms, the bot follows up at once while the zone lasts: no gap, no strike wait, aimed at
   the boss. The placement planner scores only open neighbours (sealed 0, thorned half), so the follow-up
   covers the boss cell and the exit still open.

On its own half the bot treats sealed cells as blocked (mover blockers), walks around thorns, and dodges
into thorns only when no other cell is free. deck_sim's build policy takes an offered zone card right after
an upgrade pick, at most `ZONE_PER_EFFECT` (1) per effect in the deck (seal before thorns).

Match counters (`play_match` result): `zone_casts`, `seals` / `seal_cells`, `thorns` / `thorn_cells`
(zones that formed and their cells after the leave-a-path rule), `bthorn` / `bthorn_dmg` (boss thorn
entries, damage counted in `dealt`), `pthorn` / `pthorn_dmg` (player entries, counted in `taken`), and
`ps_res` / `ps_hits` (non-zone casts started at most `POST_SEAL_SEC` = 2 s after a seal formed) against
`o_res` / `o_hits` (the other non-zone casts).

The header line `bot: ... | overrides: ...` prints every value in use. Paste it next to any number
you report.

## deck_sim flags and output

| Flag | Default | Meaning |
|---|---|---|
| `--seeds=N` | 70 | Runs per character, policy and chapter. |
| `--chapters=0,1,2` | 0 | Chapter indices (0-based). |
| `--policies=build,always_skip` | both | `always_skip` runs on chapter 1 only. `build` is the verdict policy. |
| `--characters=kiem_si,phap_su,sat_thu` | all | Subset of characters. The kiem_si onboarding row (cleared_bosses 0) is added on chapter 1. |
| `--no-treasure` | off | The bot never takes a treasure node (map experiment). |
| `--trace=N` or `--trace=<match id>` | off | Event log of match N, or of the first match against that boss. |

Output for each chapter, in the same order as the rune-era sim (`deck_sim.s023.final.out`):

1. **`CHn | character | policy | ...`**: the main table. The first 23 columns match the old sim one
   for one: win %, columns cleared, **hits taken / WON run** (target 15–30), hits per run, damage per
   hit as % of max HP, HP at the end, rest and treasure counts, deck size and levels, mean match
   seconds, timeouts, damage taken and dealt per match, boss swings per run, boss hit rate, and sig
   acts per run. v5 columns are appended at the end: casts / match, player hit % (of resolved swings),
   Focus / match, joins / match, featured / match, counters / match, and interrupts / match (boss
   swings the bot interrupted).
2. **`CHn ZONES`** (Story 027): zone cards picked per run and held in the final deck, zone casts, seals
   and thorns formed per match with their mean cells, boss and player thorn entries per match, thorn
   damage to the boss, the hit % of non-zone casts started at most 2 s after a seal (with n) against the
   other non-zone casts, and the overall player hit %. With `--no-zone-cards` the zone columns are 0.
3. **`NODE KIND BREAKDOWN`** and **`PER-MATCH`**: win %, hits, damage and deaths by node kind and by
   boss. These show which boss breaks the curve.
4. **`VERDICT chN char/build`**: win % against the Story 023/026 targets (ch1 40–60, ch2 25–45,
   ch3 15–35) and hits per won run against 15–30. **`RESULT: ALL PASS | FAIL`** covers only the build
   rows' win targets, as before.

Old and new numbers are comparable column by column. The bot is a different player, though: it must
walk to pieces, and a cast is one or two puzzle pieces rather than connected runes. Treat a shift as
"rules + bot changed" and not as balance drift alone.

## deck_sim `--world` (Story 031): a 5-floor run

`--world` swaps the per-chapter runs for whole world runs, the v6 run shape:

1. For each floor `f` = 0..`world.floors`−1: `WorldMapGen.offer_for_floor(world.region_pool, seed, f, path,
   choices_per_floor)` offers regions and the bot picks one (`--region-pick`). The region's map comes from
   `ChaptersConfig.generate_region_map(region, seed, f, cleared_bosses = 1)`.
2. The bot walks the map column by column. It uses the Story 022 node policy, plus one rule: **below 50 %
   HP it takes a `rest` node first** (before a treasure). Every match is built by
   `RunConfig.from_node(chapters, region, match_id, kind, seed, f)`, so `region_normalize` and
   `floor_scaling[f]` apply.
3. A region boss gives the normal boss reward (3 cards under the build policy) and +1 removal token. It
   does **not** end the run: the bot heals `world.floor_heal_ratio` × max HP (clamped to max) and moves to
   the next floor.
4. TD-029: the final floor first walks the `world.final_prelude` columns (shipped: one shop column) with the same node / shop policy as a region map (greedy / eager / none), so the gold of the floor-5 boss can be spent; the header prints a `final prelude` line when it is not empty.
   4. After the last floor comes the final match (`world.final_match`, `from_node(..., floor = floors)` = the
   `final` scaling row). Winning it wins the run. A lost or timed-out match ends the run.

Luck counts every node cleared over the whole run (`luck_per_node`). The sim keeps its own run state
(`WorldRun` in `deck_sim.gd`) and does not use `RunSession`. Region picks use their own RNG seeded by the
seed alone, so all three characters walk the same path on the same seed while they are alive.

| Flag | Default | Meaning |
|---|---|---|
| `--world` | off | World mode. `--chapters` is ignored. The policy is `build` unless `--policies=` is passed. |
| `--region-pick=random\|first` | random | Bot region pick: seeded random, or always the first id of the offer. |
| `--node-overhead=S` | 25 | Seconds per node outside the match: node pick, reward screen, reading. **An assumption (story Part F), not a measurement.** It is printed in the header. |
| `--world-set=key:value,...` | none | Overrides the world data in memory (chapters.json is never written). `heal:X` sets `world.floor_heal_ratio`. `scale.<row>.<axis>:X` sets a `floor_scaling` row: the row is `1`..`5`, `final` or `*` (every row), the axis is `hp_mult`, `step_mult`, `defense_add` or `size_add`. `norm.<region>.<axis>:X` sets a region's `region_normalize`. A value written `xF` multiplies instead of setting (`scale.*.hp_mult:x0.9`). `mid_columns:N` sets N copies of the middle region column between the first column and the boss column; the default frame has 1. `battle_columns:N` adds N copies of the first, battle-only column right after it. `final_prelude:none` (TD-029) empties `world.final_prelude`: the final floor is the boss column alone, the pre-TD-029 run (the no-prelude output is byte-identical to the sim before TD-029). This is the only override that adds fights: the bot always takes the rest or treasure of a middle column. |

```sh
# Story 031 Part F: 70 seeds per character, 3 characters as 3 parallel processes (about 3-6 min each)
for c in kiem_si phap_su sat_thu; do
  timeout 3000 $GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=70 --characters=$c > "<scratch>/world_$c.out" 2>&1 &
done; wait
grep -h "WORLD VERDICT" "<scratch>"/world_*.out
# Data experiment: a longer region and a bigger floor heal
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=70 --world-set=mid_columns:2,heal:0.35
```

Output for each character:

- **Header**: the bot line, the world line (floors, choices, pool, columns, heal, final match, tiers),
  every `floor_scaling` row and `region_normalize` in use, and the `--world-set` list.
- **`WORLD SUMMARY`**: run win %, boss hits per won run and per run, matches and nodes per run, mean
  match seconds (real, i.e. the player's wall clock with the card-menu slow motion, and sim), timeouts,
  **estimated minutes** = (Σ real match seconds + `node_overhead` × nodes) / 60 for won runs (mean,
  min–max) and for all runs, final luck and the rarity weights at that luck, deck size, levels, tokens
  spent, and rest / treasure counts.
- **`WORLD FLOORS`**: % of runs alive after each floor and after the final match; deaths and their
  share of all deaths; the clear % of the runs that entered the floor; mean HP % entering the floor (after
  the floor heal: the sawtooth) and after its boss.
- **`WORLD REGIONS`**: for each floor and region, the runs that entered it, the runs that cleared it, and
  the clear %. This is the "same floor, region against region" comparison.
- **`WORLD DEATHS BY FLOOR/KIND`**: deaths keyed `f<floor>/<node kind>`.
- **`WORLD VERDICT`**: the story targets. Run win 20–40 % (Kiếm sĩ, Sát thủ) or ≥ 10 % (Pháp sư); won
  run 40–50 estimated minutes; region spread ≤ 15 points at every floor (regions entered ≥ 5 times);
  no floor > 40 % of deaths; survival strictly decreasing (every floor kills someone).

- **`WORLD RELICS`** (Story 032): the `--relic-policy`, the mean number of relics owned at the end of a
  run, how many runs owned each relic at the end, and the relic triggers per run.

The match timeout is the same as in chapter mode (180 s sim) and counts as a death. The node overhead
does not include the region pick screen or the intro and end delays of a match.

**`--relic-policy=none|pick`** (Story 032, world and chapter mode, default `none`). With `pick`, the bot
takes the relic row at a treasure node instead of the card row. The row comes from
`RelicRoller.roll("treasure", owned, rng)`, with the rng seeded like GameFlow:
`hash([run_seed, floor, column, node_index, "relic"])`. The bot takes the rarest relic offered (boss >
epic > rare > common; on a tie, the first in offer order). This includes the `negative` `huyet_an`. If
the relic row is empty, the bot takes from the card row. The `always_skip` policy never takes a relic.

```bash
# Story 032 relic sweep: one relic alone, a pair, and the pick policy (70 seeds per character)
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=70 --characters=kiem_si --relics=an_don
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=70 --relics=an_don,phan_don
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=70 --relic-policy=pick
# Confirm a proposed number in memory
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=70 --relics=an_don --relic-set=an_don.mult:1.6
```

## deck_sim `--world` economy (Story 033): gold, shops, events, curses

World mode mirrors GameFlow's Story 033 economy. Chapter mode does not.

- **Gold.** Every won match node, the final match included, and every treasure node drops
  `EconomyConfig.gold_for(kind, floor, hash([run_seed, floor, column, node_index, "gold"]))`, the same
  call GameFlow makes. A run starts with `starting_gold`.
- **Shop and event nodes** go through the real `ShopLogic` (`build`, `buy`, `use_service`) and
  `EventLogic` (`pick_event`, `describe`, `resolve`, `complete_pick`, `finish_fight`). Both take a
  `RunSession` built from the sim's `WorldRun` (`_session_of`), and the results are copied back.
- **Event fight.** `tran_thach`'s extra fight is a real sim match. It is drawn as in
  `GameFlow._start_event_fight`: kind `danger`, column tier + `tier_add`, from the region pool. A loss
  ends the run with death kind `event_fight`. A win ticks the run modifiers, carries HP and passive
  heal, and applies the prize.
- **Curses** are dealt into the bot's card menu by `Deck.draw_menu` with the safety rule, as in
  CombatView. A curse takes a slot and the bot cannot pick it. *Oán Hồn*'s `draw_damage` hurts on
  each draw.
- **Run modifiers.** The run's modifiers reach `sim_core.run_modifiers`, which applies them to the
  player's step cooldown as CombatView does (`loi_the`: ×1.2 for 2 matches). They tick after every
  won match.

Node choice: rest (HP < 50 %) > treasure > shop (greedy, gold ≥ 60) > event (risky) > the Story 022
order. With `none` / `leave` the bot only enters a shop or event node when the column has nothing
else, and walks past it.

| Flag | Default | Meaning |
|---|---|---|
| `--shop-policy=greedy\|eager\|none` | greedy | `eager`: same purchases as `greedy`, but on the map a shop beats a treasure once the bot holds the shop minimum gold (`greedy` takes the treasure first). `greedy`: below 50 % HP buy the heal service, then the most expensive relic you can afford (repeat), then the cards the build policy picks from the affordable stock (repeat). The remove-card service is not used. `none`: walk past. |
| `--event-policy=risky\|leave` | risky | `risky`: above 60 % HP take the first enabled choice that is not a pure heal; otherwise take a pure heal choice (`suoi_tinh` drink) if there is one; otherwise Rời đi. Card offers use the build pick (first card if no rule fires). An upgrade goes to the Rèn target. A removal takes a curse first. `leave`: always the last choice. |
| `--economy-set=key:value,...` | none | Overrides economy.json in memory; the file is never written. The key is a dotted path (`gold_drops.battle`, `shop.relic_prices.common`, `gold_floor_mult`); a last part of `*` means every key of that object. The value is a number, `xF` (multiply a number or every element of an array), or `a/b/c` (an array). |

Extra output per character × policy:

- **`WORLD ECONOMY`**: gold earned per run (drops + event gold, median and P10–P90), for all runs and
  for won runs; event gold in and lost; gold spent at shops; gold left at the end, for all runs and
  for won runs; shops per run; items per shop and per first shop; items per run; relics, cards and
  heals bought. It also shows the gold in hand at the first column that offers a shop (entered or
  not), and the % of runs that can buy that shop's cheapest item there.
- **`WORLD EVENTS`**: events per run; non-leave choices; `tran_thach` extra fights, the deaths in them
  and the death %; curses picked up; curse draws and damage; matches slowed by `loi_the`; a count per
  `event/choice`.
- **`ECONOMY RAW`**: one `earned|spent|left|won|items|first_shop_items|seen_shop_gold` cell per run.
- **`ECONOMY TARGETS`**: the Story 033 Part A checks as observations: earned 350–450, items 4–6,
  median gold left on won runs < 100, and the first offered shop affordable for at least 50 % of runs.

```bash
# Story 033: with vs without shops and events (70 seeds per character)
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=70 --characters=kiem_si --relic-policy=pick --shop-policy=greedy --event-policy=risky
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=70 --characters=kiem_si --relic-policy=pick --shop-policy=none --event-policy=leave
# Confirm a proposed economy number in memory
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=70 --relic-policy=pick --economy-set=gold_drops.*:x1.2,shop.relic_prices.common:65
```

## Piece deck in the sim (Story 034): `--piece-deck`

A shared flag (`sim_core.gd`, both tools, deck_sim chapter and `--world` modes). It gives the bot a **fixed** piece
deck from the start of the run to its end: no ink offers, no shape removals in play. Each match the player's field
drops get `PieceDeck.weights_for_match(state, lib, chapter_id, grid, cfg)["weights"]` as the 6th argument of
`FieldDrops.enable_pieces` (what `CombatView._setup` does); the boss's drops keep the original weights. When no deck
shape fits the arena, `weights_for_match` falls back to the original weights (`fallback`) and the match is counted.
Numbers (`min_shapes`, `mult_step`, `mult_max`, `run_only_weight`) come from `rewards.json` `piece_rewards`.

| Value | Meaning |
|---|---|
| `base` | The start deck (every default-pool shape at mult 1) through `weights_for_match`: the baseline the other configurations are compared with. Its results equal a run without the flag; it only adds the header line and the tables below. |
| `small_out` | `remove:mono,bar2,bar3` |
| `big_out` | `remove:plus5,u5,bar5` |
| `remove:a,b\|add:c,d` | Sections separated by `\|`, applied in the order written. `remove:` calls `PieceDeck.remove` per id and respects `min_shapes`: a refused removal (unknown, already removed, or `min_shapes`) prints one `--piece-deck: WARNING remove '<id>' refused: <reason key> ...` line and the run continues with that shape. `add:` calls `PieceDeck.apply_ink` once per listed id: a `run_only` shape (`z4`, `j4`, `y5`) joins at mult 1, a default shape gains `mult_step` (`add:square,square` gives square mult 3), capped at `mult_max` (a refused add prints a WARNING line). Quote the value in a shell: `\|` is a pipe. |

Without the flag nothing changes: the output is byte-identical to before Story 034 for the same seeds (checked on
`--world --seeds=3 --characters=kiem_si`; only the wall-clock `runtime:` line differs).

Output with the flag:

- a header line after the `bot:` line: `piece deck (Story 034): spec=... | active N: <ids, "x2.0" when mult is not 1> | removed: ... | min_shapes=.. run_only_weight=..`;
- `--world`: one `WORLD PIECES` table per character/policy, after the economy lines. It sums every match of the
  run (tran_thach extra fights included): fallback matches / matches, casts / match, cells / cast, player hit %,
  hit % by cast cells (`cells:hit%(resolved n)`; a joined cast counts its union), joins / match (% of casts),
  featured / match (% of casts), interrupts landed / match (the player broke a boss swing), interrupts suffered /
  match (the boss broke the player's), region clear % (regions cleared / entered) and run win %. The existing
  tables still give the rest (WORLD SUMMARY, FLOORS, REGIONS);
- chapter mode and hit_probe: a final `PIECE DECK <spec>: fallback matches X of Y` line. The chapter `CH<n>` table
  already has casts, hit %, joins, featured and interrupts per match. In hit_probe the deck only matters to the
  `bot` mode: the cast modes cast `pieces.json` shapes of exactly n cells directly, not field drops.

Story 034 D2 compares the three configurations, 70 seeds x 3 characters each; a configuration that raises the
run win % more than 10 points over `base` is a dominant strategy (tune `min_shapes`, `mult_max` or
`run_only_weight` and measure again):

```bash
for d in base small_out big_out; do for c in kiem_si phap_su sat_thu; do
  timeout 3000 $GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=70 --characters=$c --piece-deck=$d > "<scratch>/deck_${d}_$c.out" 2>&1
done; done
# Smoke (about 12 s): one configuration, 3 seeds
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=3 --characters=kiem_si --piece-deck=small_out
# A custom deck: no mono or bar2, y5 added, square at mult 2
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=3 --characters=kiem_si "--piece-deck=remove:mono,bar2|add:y5,square"
# The bot against each chapter-1 boss with a deck
$GODOT --headless --path . -s res://tools/balance/hit_probe.gd -- --chapter=0 --modes=bot --seeds=3 --piece-deck=big_out
```

Run one configuration per process at a time when other Godot processes share the machine (the README's
"Running" rules).

### Piece drop weights in the sim: `--piece-weight-set`

A shared flag (`sim_core.gd`, both tools, every mode). `--piece-weight-set=<id>:<value>,...` overrides the
`pieces.json` base drop weights **in memory** for the whole run, in **every** weights map (`default`, `ch1`, `ch2`,
`ch3`), right after `PieceLibrary.load_from_file()` in `SimCore.load_configs`. The player's and the boss's field
drops both read that one library, so both see the change (and `--piece-deck`'s `weights_for_match` starts from the
changed base weights). Nothing on disk changes.

| Value | Meaning |
|---|---|
| `xF` (e.g. `mono:x0.5`) | Multiplies the shape's existing weight in each map by F |
| a plain number (e.g. `bar5:2`) | Sets the shape's weight to that number in each map |

A negative result clamps to 0 (0 = never drops). An unknown shape, a `run_only` shape (`z4`, `j4`, `y5`: no table
weight, only the piece deck gives them one) or a value that is neither `N` nor `xF` is ignored with a `WARNING`
in the header line. deck_sim and hit_probe print one header line after the `--piece-deck` line:
`piece-weight-set: <spec> -> ch1{mono 7, bar2 7} ch2{...} ch3{...} default{...} (in memory, player and boss drops)`.
hit_probe prints the same line (only its `bot` mode feels field-drop weights). Without the flag the output is byte-identical to before.

```bash
# Halve the small shapes everywhere (about 12 s)
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=3 --characters=kiem_si --piece-weight-set=mono:x0.5,bar2:x0.5
# Set bar5 to 2 in every chapter map, combined with a deck
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=3 --characters=kiem_si --piece-weight-set=bar5:2 --piece-deck=small_out
```

## deck_sim `--world --fate` (Story 035): Spare / Execute and the final match

`--fate=execute|spare|alternate` (only in `--world` mode; default none = no fate, output unchanged). At
every downed REGION boss (`FateLogic.is_boss_fate_node`: kind `boss`, never a miniboss or the final match)
the bot takes the fate before the boss reward:

- `execute`: `FateLogic.roll_execute_offer(owned relics, ChaptersConfig.fate_config(), the sim's relic
  config, seed)` (seed `hash([run_seed, floor, region, "fate"])`), and the bot takes one relic of the offer:
  the rarest with `--relic-policy=pick` (same rule as at a treasure), else the first offered.
- `spare`: nothing.
- `alternate`: execute, spare, execute, ... (by the order of the run's region bosses).

The boss reward (cards + removal token) is the same in all three. The final match (`world.final_match`,
`an_dai_keeper`) is played with its `boss_phases` trait: SimCore builds its TraitHost from
`match_params["traits"]` like CombatView, and the match result carries `boss_phase` (the phase it ended in)
and `boss_hp_end_ratio`.

Extra lines per character/policy (only with `--fate`):

| Line | What |
|---|---|
| `WORLD FATE \| ...` | run win %, final reached / won, final-match win % when reached (won / reached), deaths, final deaths and their share of all deaths, executes / spares / relics from executes per run |
| `FATE DEATHS BY FLOOR` | deaths on floors 1..5 and in the final |
| `FATE FINAL PHASES` | "final phase 2 reached in X of Y final matches" and the final boss's HP % left at the end (mean, min) |
| `FATE TARGETS` | Story 035 F4: final-match win when reached 35-55 %, final <= 40 % of deaths; the run win to compare across runs ("execute beats spare by 8-20 points" needs the `--fate=execute` and `--fate=spare` runs side by side) |

```sh
# Smoke (about 12 s each)
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=3 --characters=kiem_si --fate=execute
# Story 035 F4: 70 seeds x 3 characters, once per fate policy, then compare the run wins
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=70 --fate=execute --relic-policy=pick > "<scratch>/fate_exec.out" 2>&1
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=70 --fate=spare --relic-policy=pick > "<scratch>/fate_spare.out" 2>&1
grep -E "^FATE|^\| .* \| (execute|spare|alternate) \|" "<scratch>/fate_exec.out" "<scratch>/fate_spare.out"
# Probe the final match only: weak floor bosses so runs reach it (the final keeps its own scaling)
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=4 --fate=alternate --world-set=heal:1.0,scale.1.hp_mult:0.05,scale.2.hp_mult:0.05,scale.3.hp_mult:0.05,scale.4.hp_mult:0.05,scale.5.hp_mult:0.05
```

## hit_probe flags and output

| Flag | Default | Meaning |
|---|---|---|
| `--chapter=N` | 0 | One chapter (0-based). Every match of it is probed on its own arena. |
| `--modes=a,b` | piece,counter,idle | See below. |
| `--sizes=1,2,...` | 1..5 | Cast sizes for the cast modes. |
| `--trials=N` | 40 | Casts per boss × mode × size. |
| `--only=id,id` | all | Subset of match ids. |
| `--seeds=N` | 3 | Seeds per boss for `idle` and `bot`. |
| `--idle-sec=S` | 600 | Sim seconds per idle seed. |
| `--char=id` | kiem_si | Character for `bot` mode and for the passive in the cast modes. |
| `--immortal` | off | `bot` mode: keep the player at full HP. |
| `--trace` | off | Event log of the first match. |

Modes. In the cast modes the player cannot die, the boss has 1e6 HP, and there is no bag or menu
(best case):

- `piece`: cast the best pieces.json shape of exactly n cells covering the boss's cell, most covered
  neighbours first, every 0.6–1.6 s. `piece_strike` waits for the boss's step first.
- `pair`: the same with two pieces whose union has n cells.
- `counter`, `counter_pair`: cast only in the step the boss starts a swing.
- `idle`: the player never casts or moves. `RESULT IDLE` prints swing starts, hits and damage per
  minute: the boss's attack rate. Use it for TD-022, where three bosses attack only 4–6 times a minute.
- `bot`: the full deck_sim bot against each boss. `RESULT BOT` prints win / died / timeout %, casts
  and hit % of the player, boss starts and hits per minute, interrupts, counters, Focus, joins and
  featured per match, sig uses per match, first sig use (sim s), and sig damage per use (Thien Hoa
  detonation, Tram's doubled-cell share, Anh Bo's multiplied share). This replaces the scratch
  `formation_probe`, `sigcd_probe` and `sigbal_probe`; use it with `--aware`, `--sig`, `--sig-cd` and
  `--hold`.

`RESULT` columns of the cast modes: `nofit` = casts for which no shape of that size could cover the
boss's cell on that arena (they count as misses). `busy` = boss swings left unanswered because the
previous counter was still winding up. `fallback` = strike casts made after waiting 3 s without a
boss step.

## The TD-006 dodge assumption

The bot's dodge chance has not been re-anchored on a user playtest yet. The default `--dodge=0.85` is
the rune-era bot's value (Story 020 calibration). Every run prints this in its header. Once a playtest
estimate exists, pass it with `--dodge=` and record it in the story's Completion Notes. The same
applies to the human-time defaults (`--place-sec`, `--choose-sec`, `--join-sec`, `--gap`): they are
assumptions, not measurements.

## What the bot does not model

- It never cancels a placement or a menu, and never rotates for its own sake: it re-aims the same
  piece on drop and takes the best rotation.
- It picks up every non-rotten piece and walks around rotten ones. A rotten piece in the bag blocks
  a slot until it rots out.
- Card choice is a value model ported from the rune-era sim (`SimCore.cast_value`). It does not
  account for the featured shape's bonus effect.
- Cut from the label-era probes: the `naive` and `blob` connected-rune modes (runes no longer exist)
  and the `--boss=rune` boss mode.
