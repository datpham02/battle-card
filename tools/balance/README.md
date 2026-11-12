# Balance tools (`tools/balance/`)

Headless simulators that play the real v5 combat code with a scripted player. Use them to measure
chapter win rates and per-boss hit rates before and after changing data. They are **tools, not
tests**: the test runner never runs them, and the game never loads them. Story 026 moved them here
from session scratch.

| File | What it is |
|---|---|
| `sim_core.gd` | Shared harness. It builds one match the way `CombatView._ready` does and runs `CombatView._process`'s tick order headless. It contains the v5 player bot. Both tools preload it. |
| `deck_sim.gd` | Full-run simulator. It plays seeds × characters × chapters through the chapter map with the reward policy, then prints win %, boss hits per won run, and per-kind and per-match tables. `--world` (Story 031) plays whole 5-floor runs instead: region picks, short region maps, floor heal, the final match. `--run=v6` (Story 040) adds the whole-run tables and VERDICT lines. |
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
| `--aware-min=N` | 3 | Smallest piece a formation-aware placement uses (1..7 since Story 041; odd blocks reach 7 cells). |
| `--sig=off\|ready\|rules` | rules | Signature activation. `rules` = the Story 021 rules: Tram before a cast of 3+ cells or when the boss is at 40 % HP or less; Thien Hoa on 15+ burn or 2+ burning enemy cells, otherwise after holding 6 s; Anh Bo when the boss is pinned, on a dodge, or at the next cast; Story 037: Vay Bat right after a player zone forms, Thanh An when the boss has >= 1 Han stack (section below). `ready` fires as soon as the signature is usable. |
| `--progress=none\|all` | all | Story 037, see the section below. `none` = an empty save (every unlock still locked in the pools), `all` = nothing locked. |
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
| `--no-zone-cards` | Story 027 "before" measurement: drops the zone cards (`SkillConfig.is_zone_card`: effect `thorns`) from every match deck, and deck_sim also drops them from the reward pool (`RewardRoller.roll` exclude list). Same tool, same seeds as the "after" run. Boss zone traits (`seal_caster`, `thorn_field`) are NOT affected. |
| `--card-set=id.key:value,...` | Sets a key of a cards.json card in memory, e.g. `--card-set=tran_gai.cooldown_sec:8,gai_doc.min_cells:4,gai_nguyen.rarity:epic`. Level-1 values; the card's `upgrade` deltas still apply on top. |
| `--relics=id,...` | Story 032. The player owns these relics (relics.json ids; unknown ids are dropped with a message) in every match. In deck_sim, the run starts with them. In hit_probe, every probe match has them. |
| `--relic-set=id.param:value,...` | Story 032. Sets a relic param in memory (relics.json is never written). A config-type relic takes a nested path: `--relic-set=an_don.mult:1.6,la_ban.formation_fade.mul:1.15,tui_rong.piece_spawn_interval.mul:1.4`. |

### Relics in the sim (Story 032)

`sim_core._relic_config_overrides` and `_setup_relics` port `CombatView._setup_relics`, `_apply_drop_overrides`, `_apply_status_overrides` and `_wire_relics`, as written by the combat wave on 2026-10-25. The relics are
created per match from `relic_ids` (`RelicRegistry.instantiate`). Their merged `config_overrides()` are
written into the per-match configs **before** FieldDrops, the bag, FormationMap and StatusEffects are
built:

| Key | Where it goes |
|---|---|
| `thorn_sec`, `thorn_ran` | `arbiter.player_zone_overrides` = the merged overrides. CutEffects applies them after the card's own value, for the player's zone casts only. |
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

The match gets `CombatView._wire_zones`'s wiring: a hole blocker (the boss's drop tiles) on both movers (`UnitMover.add_blocker`),
each side's `UnitMover.is_cell_blocked` as the arbiter's leave-a-path test (`blocked_cell_fns`), and
`CombatConfig.zone_numbers()` on the arbiter. The boss's card list skips zone cards
(`SkillConfig.boss_card_order`), as in the game. Without this wiring zone cards would do nothing in the sim.

Bot rule (`SimCore._zone_choice`, decided in the card menu once the cast cells are placed; the bot only
sees its hand after placing, like a player):

1. Never when an available damage card in the hand would kill the boss, and never as the follow-up cast.
2. **Thorns** when the cast covers at least `ZONE_THORN_MIN_COVER` (2) open exits of the boss
   (enemy-half neighbours its mover may step into: its dodge cells).
3. After a zone forms, the bot follows up at once while the zone lasts: no gap, no strike wait, aimed at
   the boss. The placement planner scores only open neighbours (blocked 0, thorned half), so the follow-up
   covers the boss cell and the exit still open.

On its own half the bot treats holes (the boss's drop tiles) as blocked (mover blockers), walks around
thorns, and dodges into thorns only when no other cell is free. deck_sim's build policy takes an offered
zone card right after an upgrade pick, at most `ZONE_PER_EFFECT` (1) per effect in the deck (higher
`damage_per_cell` / `thorn_fragile_stacks` first).

Match counters (`play_match` result): `zone_casts`, `thorns` / `thorn_cells` (zones that formed and
their cells), `bthorn` / `bthorn_dmg` (boss thorn entries, damage counted in `dealt`), `pthorn` /
`pthorn_dmg` (player entries, counted in `taken`), and `o_res` / `o_hits` (resolved / hit non-zone casts).

The player Wall cards and their seal zone were deleted on 2026-11-01 (the boss uses drop tiles instead);
the seal rule, the `seals` / `seal_cells` / `ps_*` counters and `POST_SEAL_SEC` went with them.

The header line `bot: ... | overrides: ...` prints every value in use. Paste it next to any number
you report.

## deck_sim flags and output

| Flag | Default | Meaning |
|---|---|---|
| `--seeds=N` | 70 | Runs per character, policy and chapter. |
| `--chapters=0,1,2` | 0 | Chapter indices (0-based). |
| `--policies=build,always_skip` | both | `always_skip` runs on chapter 1 only. `build` is the verdict policy. |
| `--characters=kiem_si,phap_su,sat_thu,tho_san,giao_si` | the first three | Subset of characters. Story 037: `tho_san` and `giao_si` are accepted but are not in the default list (older command lines stay as they were). The kiem_si onboarding row (cleared_bosses 0) is added on chapter 1. |
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
2. **`CHn ZONES`** (Story 027): zone cards picked per run and held in the final deck, zone casts,
   thorns formed per match with their mean cells, boss and player thorn entries per match, thorn damage
   to the boss, the hit % of non-zone casts (with n), and the overall player hit %. With `--no-zone-cards` the zone columns are 0.
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
| `--region-pick=random\|first\|order` | random | Bot region pick: seeded random, always the first id of the offer, or (`order`, World Map v2 step 0) the game's own rule `WorldMapGen.floor_offer` with `world.region_order` — the fixed climb `ch1, hellfire, desert, swamp, ch2, ch3, sky_isles` that the shipped game plays (region locks do not apply, as in `RunSession.roll_offer`). `random` and `first` draw from `offer_for_floor` and ignore `region_order`, so they play a random region order that the shipped game never does; use `order` for any number meant to describe the shipped climb. |
| `--region-rules=<path>`, `--route-archetypes=<path>` | assets/data | World Map v2 tuning experiments: load an alternative `region_rules.json` / `route_archetypes.json` into the shared loaders for this process (the game keeps `assets/data/`). Printed in the `world-map-v2:` header line of the output. Used by `production/qa/evidence/world-map-v2/balance/run-experiments.sh`. |
| `--route-policy=...` output | | Per lane taken at a v2 fork: a `ROUTE` row (clear %, gold, net HP lost, relics, objective met) and a `ROUTE2` row (heat at the warden with its 0..4 count, heat max, objective fights won / met, relic rows offered / taken, ink rows offered / taken and forge visits / free removals with `--pieces=on`, HP lost in fights vs healed outside fights vs the events' signed delta). Forge nodes = ink row + one free removal, no fight. A `ROUTE3` row adds rests / shops per route with the mean heat before -> after each, wardens reached and the warden-hook fired % (`RegionRules.warden_hook` at the heat the warden fight began — fired = heat ≥ 3; since B1 (2026-11-12) the hook means surge every 7 s with the first at 10 s, plus 2.5 s eruptions at heat 4; the bot leaves warned cells, so a fired hook costs it nothing measurable). |
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

## deck_sim `--region` (Story 036): one region at chosen floors

`--region=<id,...>` plays every match of each listed chapters.json entry (`swamp`, `desert`, and also `ch1`,
`ch2`, `ch3` for the comparison) on its own: full HP, the character's starter deck, `--relics` if given, N seeds
per match (`--seeds`), at each floor of `--floor=1,3,5` (1-based, default 1). The Story 031 scaling is the one of
the game: `RunConfig.from_node(..., floor - 1)` applies `region_normalize`, then `floor_scaling` row N. The pool
kind (`battle`, `miniboss`, `boss`) is printed; breakers sit in the `miniboss` pool (min floor 2 on the map) but
are played at every listed floor. `--region` replaces the chapter and `--world` runs; other shared flags apply.

| Flag | Default | Meaning |
|---|---|---|
| `--region=id,...` | off | Region mode. Unknown ids print a line and are skipped. |
| `--floor=1,3,5` | 1 | Floors (1-based) every match is played at. |

Output, per character, region and floor:

| Line | What |
|---|---|
| `REGION` | one match: kind, n, win %, timeout %, hits landed / match, boss hits / match, HP taken / match, mire entries / match, mire HP / match, mire share of HP taken %, pieces buried / match, pieces drifted / match (player half), boss mire entries / match, sand cells filled / match, the arena's hazards (mire cells, sand, wind) |
| `REGION MEAN` | the unweighted mean over the region's matches at that floor: the line to compare with `--region=ch1,ch2,ch3` at the same floor |
| `REGION CHECK` | story 036 E3: floor-1 matches outside 15-95 % win, mire share <= 15 %; the +-10 points vs ch1-ch3 needs the other run |

Hazards (Story 036, both tools): `sim_core` mirrors `CombatView._setup_hazards`: a `TileHazards` per match
(seed = the drops seed; combat.json `hazards` overlaid by the match keys of the same names), arena mire / sand /
wind from `ArenaLibrary.hazards_for_match`, the sand blocker and the mire step cost on both movers, `mire_immune`
for the boss, mire damage on the unit standing in it (counted in "HP taken"), burial on `sand_filled`, the
drift on `drift_due`, the wind offset of new drops, sand / sand-warning cells refusing drops, `ctx["hazards"]`
for the traits and `BossController.set_hazards` when it exists. The bot walks with a Dijkstra on hazard maps:
a step INTO mire costs `MIRE_STEP_EXTRA` (2) extra steps (an assumption), sand is blocked, and with the wind on a
piece it cannot reach before the next drift is chased at the cell it will drift to. Maps without mire or wind
keep the plain BFS walk, so hazard-free output is byte-identical to the sim before Story 036.

```bash
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --region=swamp,desert --floor=1,3,5 --seeds=70 --characters=kiem_si > "<scratch>/regions_new.out" 2>&1
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --region=ch1,ch2,ch3 --floor=1,3,5 --seeds=70 --characters=kiem_si > "<scratch>/regions_old.out" 2>&1
grep "REGION MEAN\|REGION CHECK" "<scratch>"/regions_*.out
```

## hit_probe flags and output

| Flag | Default | Meaning |
|---|---|---|
| `--chapter=N` | 0 | One chapter (0-based). Every match of it is probed on its own arena. |
| `--region=id` | off | Story 036: the chapter by chapters.json id (`swamp`, `desert`, `ch1`...); overrides `--chapter`. |
| `--floor=N` | off | Story 036: plays every match at floor N (1-based) with the Story 031 scaling (`region_normalize`, then `floor_scaling` row N). Off = the unscaled match, as before. `bot` mode adds a `RESULT BOT HAZARDS` line (mire entries / HP / share of HP taken, buried, drifted, boss mire entries per match) after each match that had a hazard effect. |
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

Story 040 (the v6 run tables) prints every table at three dodge values on request (`--dodge=0.7,0.85,0.95`) and
keeps the anchoring criterion DEFERRED while no playtest exists: see "Story 040" below.

## What the bot does not model

- It never cancels a placement or a menu, and never rotates for its own sake: it re-aims the same
  piece on drop and takes the best rotation.
- It picks up every non-rotten piece and walks around rotten ones. A rotten piece in the bag blocks
  a slot until it rots out.
- Card choice is a value model ported from the rune-era sim (`SimCore.cast_value`). It does not
  account for the featured shape's bonus effect.
- Cut from the label-era probes: the `naive` and `blob` connected-rune modes (runes no longer exist)
  and the `--boss=rune` boss mode.

## Story 037: `--progress`, the two new characters, `--unlock-runs`

Milestone unlocks only widen the POOLS (card rewards, piece drops, relics, regions, character select). The sim has
three tools for the Part F "Mô phỏng" checks: the character list, `--progress` and the unlock-runs mode.

**`--characters`** accepts `tho_san` (Thợ săn) and `giao_si` (Giáo sĩ) next to the three open ones. The default list
stays `kiem_si,phap_su,sat_thu`, so every older command line (and its output) is unchanged. The sim never gates the
character list by progress: you pick who plays.

**`--progress=none|all`** (shared, `sim_core.gd`; default `all`). `none` = an empty save: `SimCore.locked` =
`AchievementsConfig.shared().locked_content(ProgressState.new())`, the `RunSession.locked` form (`{kind: [ids]}`);
`all` = `{}`, nothing locked (every sim before Story 037 behaves as before, apart from the new shapes and cards now
being in the open data). The header prints `progress=none (Story 037, empty save): locked card[...] piece[...] ...`.
Where the sim builds a pool itself, it applies `locked`:

| Pool | Where | How |
|---|---|---|
| Card rewards (boss / treasure / battle rows) | `deck_sim._apply_policy` | locked cards join the `RewardRoller.roll` exclude list |
| Relic row at a treasure, fate offers | `deck_sim._take_relic` | locked relic ids are passed as already owned to `RelicRoller.roll` |
| Shop and event offers | `ShopLogic` / `EventLogic` | `_session_of` copies `locked` into the `RunSession` proxy, so the game's own filters apply |
| Player's piece drops | `sim_core._setup` | locked shapes get no weight in the player's `FieldDrops` (also with `--piece-deck`); the boss's drops are untouched |
| Region offer (`--world`) | `deck_sim._open_region_ids` | locked regions are left out of the pool (an all-locked pool keeps the full one) |
| Chapter-mode `RunSession` | `deck_sim._run` | `session.locked` is set |

Compare win rates of the two modes with two invocations, same seeds:

```sh
for p in none all; do
  timeout 3000 $GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=70 --characters=kiem_si,phap_su,sat_thu,tho_san,giao_si --progress=$p > "<scratch>/chars_$p.out" 2>&1
done
grep -h "WORLD CHARACTERS\|WORLD VERDICT" "<scratch>"/chars_*.out
```

`WORLD CHARACTERS | progress=<mode> | policy | character | run win % ... | mean of N open characters ... | delta ... (band +-10): PASS|FAIL`
prints once per new character at the end of a `--world` run that played it together with the open ones (Part F
bullet 1: within 10 points of the mean of the three open characters). Bullet 2 (`none` against `all` within 10 points,
per character) is read from the `WORLD VERDICT` / `WORLD SUMMARY` win % of the two files.

### Bot rules for the new signatures (`--sig=rules`)

The bot activates once the signature is ready (formation map covered, cooldown over), like the older ones:

| Signature | Rule (`SimCore._bot_signature`) |
|---|---|
| `vay_bat` (Thợ săn) | Right after a player zone (thorns) formed: the tick after a zone cast resolved, while that zone's follow-up window is still open (`_zone_follow_until`). It covers the bot's follow-up casts of that zone (Ran stacks consumed at `fragile_mult`) and any zone cast in the next `duration_sec`; the zone that just formed is not lengthened. |
| `thanh_an` (Giáo sĩ) | When the boss has at least `sig_thanh_an_min_stacks` (1) Han stack (`StatusEffects.frost_stacks(ENEMY)`). |

`--sig=ready` fires both as soon as they are usable; `--sig=off` never. `sim_core` also ports the Story 037 combat wiring of
`CombatView`: the passive hooks (`on_frost_burst`, `on_boss_thorn_step`, `on_player_zone_formed`, `tick`, ctx `heal_player`),
the signature hooks (`zone_sec_mult`, `fragile_mult_override`, `frost_burst_mult`) and the match counter `frost_bursts`
(a Han burst on the boss; `boss_thorn_steps` is the existing `bthorn`). When `CombatView` changes that wiring, update the port.

### `--unlock-runs=N [--unlock-reps=R] [--unlock-full]`

Unlock speed (Part F bullet 3). For each open character (`--characters`, default the three; new characters are ignored
here), R repetitions (default 30) of up to N consecutive `--world` runs on ONE `ProgressState`, seeds `rep * 1000 + run`,
the `build` policy, and the fate policy `--fate=alternate` (default here; execute, spare, execute, ... per run in the order of
the run's region bosses; `--fate=execute|spare` is honoured). Before each run `SimCore.locked` is set from the ledger
(`AchievementsConfig.locked_content(progress)`), so pools widen as achievements are earned, as in the game. After each run the
sim writes what `GameFlow` writes and raises the events through `UnlockRules.process`, in this order per match:

1. a won REGION boss (`FateLogic.is_boss_fate_node`): `record_boss_clear`, `add_region_boss_beaten(region)`, `record_fate(match_id, fate)`;
2. `final_reached` (`record_final_reached` + the event) before the first final-floor match;
3. a `match_won` event for EVERY won match: `match_stats` = that match's `hits_taken` (boss hits), `casts`, `joins`, `featured_casts`,
   `signatures_used`, `frost_bursts`, `boss_thorn_steps`, `damage_*`; `run_stats` = the sum so far (a lost match also adds its stats);
   `deck_ids` = the deck after that node's reward;
4. at the end: on a win `record_run_won(character)` + `record_ending(FateLogic.ending_for(...))`, then the `run_ended` event (won or lost).

Not modelled: the extra fights of `tran_thach` events (no event, their stats are not summed). A repetition stops as soon as both
new characters are open, unless `--unlock-full` (then all N runs are played, which also gives the full achievement picture).
The sim does not play the new characters inside this mode.

| Output line | What |
|---|---|
| `UNLOCK RUNS RAW <char> rep K` | one repetition: `W`/`L` per run, the run index at which `tho_san` / `giao_si` opened (`-` = not within N), new achievements per run, total held |
| `UNLOCK RUNS SUMMARY <char> \| <new character> (via <achievement>)` | opened in X of R reps, mean run index (median, max) over the reps that opened it, the mean with a never-opened rep counted as N+1, and the story target 1-3 runs (PASS needs that last mean in range) |
| `UNLOCK RUNS ACHIEVEMENTS <char>` | new achievements per run index (mean over reps that played it), mean held at the end of a rep, run win % over all runs |
| `UNLOCK RUNS EARNED <char>` | how many reps held each of the 22 achievements at the end of the rep |

```sh
# Smoke (about 20 s)
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --unlock-runs=2 --unlock-reps=2 --characters=kiem_si
# Part F bullet 3: 30 reps, up to 8 runs, three open characters (about 5 min per character), then read the summary lines
timeout 3000 $GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --unlock-runs=8 --unlock-reps=30 > "<scratch>/unlock_runs.out" 2>&1
grep "^UNLOCK RUNS" "<scratch>/unlock_runs.out"
```


## Story 038: `--kiep`, `--kiep-only` (Kiep levels 1..10 in the world run)

Kiep makes the run harder (never stronger), per character, rules stacking: level k applies the rules of levels 1..k from
`assets/data/kiep_levels.json` (`KiepRules`). Level 0 = the game as it is. Both flags need `--world` (they are ignored with
a `KIEP:` notice under `--region`, `--unlock-runs` or the chapter mode) and run **the same seeds at every level**.

| Flag | Meaning |
|---|---|
| `--kiep=<levels>` | The run's level. `<levels>` = one level (`5`), a comma list (`0,3,6,10`), a range (`0..10`) or a mix (`0,3..5`); distinct, ascending, valid 0..10. One level = a normal world run (full WORLD tables) plus its KIEP row. Several levels = one invocation runs each in turn, prints only the KIEP tables (`=== KIEP LEVEL k ===` markers and the seed progress lines), then the table and the checks at the end |
| `--kiep-only=<levels>` | Same list syntax, but each level runs **its own rules alone** (`KiepRules.shared().set_only(k)`, a single-rule table, run at level k) to measure one rule's own difficulty. Put `0` in the list: it is the baseline the deltas are read against |
| `--kiep-full` | With several levels, also print every level's full WORLD tables (volume: levels x characters x ~20 lines) |

No flag = nothing of the above runs and the output is byte-identical to the sim before this story (checked: `--world
--seeds=2 --characters=kiem_si` before and after, `diff` empty apart from the `runtime:` and seed progress lines).

**Where the level is applied** (the same points, with the same `KiepRules` calls, as the game: W2 wiring): matches
`RunConfig.from_node(..., floor, kiep_level)` (extra boss trait, boss swing, scaling row shift, final HP; the event
fights too), the region map `generate_region_map(..., kiep_level)` and the event fight's `region_spec(..., kiep_level)`
(node weight), max HP `KiepRules.apply_run_start` on the character before `--hp-mult`, rest heal (`WorldRun.rest_heal`
through `rest_heal_ratio`), floor heal (`floor_heal_ratio` at the end of floors 1..5), gold (`economy_mult("gold")`, rounded,
>= 0, in `_drop_gold`), shop prices (`ShopLogic.build(..., kiep_level)`; the `RunSession` proxy carries `kiep_level`). The
player's drop interval (`player_drop_interval_mult`, Kiep 4) is applied in `sim_core._setup` like `CombatView`: x on
`piece_spawn_interval_sec` of the PLAYER's drops, after the relic overrides.

### Output (every line starts with `KIEP`)

| Line | Content |
|---|---|
| `KIEP: STACKED\|ONLY ... levels=[...]` | header: mode, levels, seeds, characters, policies |
| `KIEP \| character \| policy \| level \| run win % \| wins / runs \| deaths by floor (f1 f2 f3 f4 f5 final) \| est. minutes WON run mean \| est. minutes all runs \| boss hits / WON run \|` | the table, one row per (character, policy, level). Est. minutes = real match seconds + `--node-overhead` per node, as the WORLD table; `-` = no won run |
| `KIEP CHECK curve <char>/<policy>` | the win % per level in one line |
| `KIEP CHECK monotone step` | `win(k) <= win(k-1) + 3` for every pair of consecutive levels that ran |
| `KIEP CHECK monotone skip` | `win(k) < win(k-2)` for every k >= 2 (strict: two zeros fail it, a floor effect, read it with the curve) |
| `KIEP CHECK no big drop` | no single drop > 12 points between neighbours (the worst one is printed) |
| `KIEP CHECK winnable` | level 10 run win % >= 3 % for `kiem_si` (the story's Kiem si build); the other characters print the number as INFO |
| `KIEP CHECK minutes` | level 10 est. minutes (WON run mean; `NO WINS` falls back to the all-runs mean and fails) <= 55 |
| `KIEP CHECK RESULT <char>/<policy>`, `KIEP CHECK RESULT` | ALL PASS or FAIL (n checks), per character and over all |
| `KIEP ONLY \| character \| policy \| level \| rule \| run win % \| +-1 sd \| vs level 0 (pts) \| verdict \| wins / runs \|` | `--kiep-only` only: the rule type(s) of the level, its win %, the binomial noise sqrt(p(1-p)/n), the change vs level 0 and the verdict `HARDER` (<= -1 pt), `NO EFFECT` (within 1 pt: change the number or the order in `kiep_levels.json`, the story rule), `EASIER` (a positive delta of >= 1 pt: noise or a bug) |

A check whose levels did not run is `SKIPPED`, never PASS (e.g. `--kiep=0..5` skips `winnable` and `minutes`). Checks are
not printed in `--kiep-only` mode (the levels are not stacked there, the monotone rules do not apply).

**Reading `--kiep-only`.** Level k's row = only rule k on top of the base game, so `vs level 0` is that rule's own cost
in win points. With 70 seeds one sd of a win % near 40 is about 6 points: a rule inside `+-1 sd` is "not measurable",
not "zero", so trust a `NO EFFECT` only when it also shows in the deaths by floor / hits columns (or rerun with more
seeds). Level 10 only = both its rules (`shop_price_mult+boss_extra_trait`). Rules interact (HP x gold x heals), so the
sum of the single deltas is not the stacked drop; the stacked table is the one the checks use.

### Command lines

```sh
GODOT=C:/Users/ADMIN/AppData/Local/Microsoft/WinGet/Links/godot.exe
# Smoke (about 20 s): three levels, 2 seeds
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=2 --characters=kiem_si --kiep=0..2
# The story bullet: levels 0..10, 70 seeds, the default build policy. About 3 s per seed and character at level 0, less at
# high levels (runs die earlier): roughly 35-45 min per character. One invocation per character keeps the output small
# and survives a timeout; the three can only run one after the other (one Godot at a time)
timeout 7000 $GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=70 --characters=kiem_si --kiep=0..10 > "<scratch>/kiep_kiem_si.out" 2>&1
timeout 7000 $GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=70 --characters=phap_su --kiep=0..10 > "<scratch>/kiep_phap_su.out" 2>&1
timeout 7000 $GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=70 --characters=sat_thu --kiep=0..10 > "<scratch>/kiep_sat_thu.out" 2>&1
grep "^KIEP" "<scratch>/kiep_kiem_si.out"
# Per rule alone (with the level-0 baseline):
timeout 7000 $GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=70 --characters=kiem_si --kiep-only=0..10 > "<scratch>/kiep_only_kiem_si.out" 2>&1
grep "^KIEP ONLY" "<scratch>/kiep_only_kiem_si.out"
```

One invocation with all three characters (`--characters=kiem_si,phap_su,sat_thu`, or no `--characters`) prints one block of
rows and checks per character at the end. Other flags compose as before (`--fate=execute --relic-policy=pick` for the Story 035
fate pick, `--progress=none`, `--world-set=`, `--economy-set=`, `--relics=`), but a tuning pass should vary one thing at a time:
the level rules and `kiep_levels.json` numbers are edited in the data file, the sim reads them at start.

## Story 039: Hellfire and Sky Isles (`--region=hellfire,sky_isles`, `--region-freq=N`)

Two new regions (7 in `world.region_pool`): `hellfire` (lava vents, `burn_eater`, `rebirth`, `vent_surge` boss) and `sky_isles`
(crumbling cells, `gust`, `shroud`, `island_drop` boss). The sim mirrors the game's wiring and the report gets the Story 039
columns. Every new output is additive: a run that meets no vent, no crumble arena and no new trait prints exactly the lines it
printed before (checked: `--region=swamp --floor=1 --seeds=2 --characters=kiem_si` and `--world --seeds=2` before / after).

### What sim_core mirrors (`SimCore._setup_hazards` and handlers, the CombatView wiring of W1 / W3)

| Game | Sim |
|---|---|
| `hazards_for_match` -> `set_vents`, `enable_crumble` | the same calls with the arena's `vents_player` / `vents_enemy` / `crumble` (guarded with `has_method`, so a build without the model still runs) |
| `vent_erupted` -> `StatusEffects.ignite` on the cells (`vent_sec`, `vent_tick_sec`, `vent_tick_damage` of the hazards block) + the field pieces there are burnt (`bury_cells`) | `_on_vent_erupted`: the same ignite; the burnt pieces count in the "buried" column |
| `cell_fell` -> pieces lost, `fall_damage` for a pushed unit (the model moves the unit), the fallen cell is the 4th mover blocker | `_on_cell_fell` + `is_fallen` blocker on both movers; the HP actually lost goes into `fall_hp` and "HP taken" |
| `burn_eater` (`StatusEffects.burn_heal_ratio_fn`), `rebirth` (`CombatState.enemy_death_hook_fn`), `gust`, `island_drop`, `vent_surge`, `shroud` | traits run through `TraitHost` with `ctx["hazards"]` as in the game (no sim code); the sim only counts: boss HP healed by burns (`boss_heal`), `rebirth_used` |

Bot rules (assumptions, like Story 036's mire cost; they live in `sim_core.gd`):

- A vent line that has been in its WARNING phase for `VENT_REACT_SEC` (0.4 s, a human noticing it) counts as a warned cell (`_haz_warned`, with a cracking cell): the bot
  leaves it like a row_burner warning (`_fire_dodge`; if no neighbour is safe it walks along the shortest way to a safe cell), keeps off it
  while walking, and an erupting vent is a burning cell (`status.is_burning`). It does NOT keep off a quiet vent line.
- On a `crumble` arena it never camps: after `CRUMBLE_LEAVE_SEC` (1.5 s, vs `crumble_after_sec` 2.0) on one cell it steps to
  the neighbour it stood on longest ago (a piece first), only when the step is free and its own swing is not running; a
  cracking cell is left at once. It never steps onto a fallen cell (the mover blocker). Standing still happens only while
  it places / waits in the card menu, which is where falls and pushes come from.
- Not modelled: the hit forecast (the bot never reads it, so `shroud` only shows up as the match's own difficulty), the gust
  arrow (the bot is pushed like a player who ignores it), the island warning (it reacts to nothing before the drop).

Shared flags (both tools; printed in the `overrides:` header only when changed): `--vent-react=S` (default 0.4, `SimCore.VENT_REACT_SEC`:
seconds a vent has warned before the bot notices it) and `--crumble-leave=S` (default 1.5, `CRUMBLE_LEAVE_SEC`: seconds on one cell
before it steps off on a crumble arena).

**Reading the vent numbers.** The bot leaves an erupting vent cell at once (the Story 021 burning-cell dodge, shared with
row_burner, unchanged), so even with `--vent-react=2` (it never notices a warning) the HP it loses to vents is close to 0
(phap_su, hellfire floor 1, 6 seeds: 0.04 HP / match): the first burn tick needs 0.5 s on the cell. The cost of a vent to the bot
is the burnt field pieces (`buried`) and the steps it spends; the HP a human loses standing in a vent is NOT measured. Do not tune
`vent_tick_damage` / `vent_interval_sec` from the vent HP column alone.

### New output (all start with `REGION`)

| Line | What |
|---|---|
| `REGION 039` | per match, printed only when a vent erupted, a cell fell, burn_eater healed or rebirth was used: vent HP / match, fall HP / match, times pushed / match, vents erupted, cells fallen, boss HP healed by burn, rebirth used %, player hit % |
| `REGION MEAN 039` | per region and floor, only for a region with vents or crumble: the means of vent HP, fall HP, their sum, times pushed, hit % |
| `REGION 039 SHROUD` | the match with the `shroud` trait: its hit % vs the region's other matches and vs all (story: hit rate at the Shroud match vs the mean) |
| `REGION 039 FIRE EATER` | the `burn_eater` match at floor 1: win % vs the story target >= 25 (meant for `--characters=phap_su`; other characters print INFO) |
| `REGION` (extended) | the arena column of a vent / crumble match gains ` \| vents N, crumble` |

`HP lost to vents` = HP the player loses to burn ticks while standing on an erupting vent cell (also part of "HP taken");
`HP lost to falls` = `fall_damage` of every fall that pushed the player. `hit_probe` prints the same numbers in one
`RESULT BOT HAZARDS039` line per match (only when a vent / fall / heal happened).

### `--region-freq=N`

N seeded runs of the world map generator as the game does (`RunSession.begin_world`, `roll_offer` each floor over
`world.region_pool` minus the locked regions, the bot picks one of the offers at random, `choose_region`, next floor), floors
1..`world.floors`. No match is played, so it takes seconds. `--progress` composes (locked regions leave the pool).

| Line | What |
|---|---|
| `REGION FREQ` header | runs, floors, choices per floor, pool |
| `REGION FREQ \| region \| ...` | per region: times offered, offered % of choice events, times chosen, chosen % of choice events, offers per floor |
| `REGION FREQ CHECK offered share` | story E3: every region OFFERED in 20-40 % of the choice events (with 2 offers out of 7 regions the mean is 28.6 %; chosen % is half of it by construction) |
| `REGION FREQ CHECK runs that repeat a region` | runs that chose one region twice (the "unvisited first" rule of `WorldMapGen.offer_for_floor` makes it 0 with 7 regions and 5 floors) |

### Command lines

```sh
GODOT=C:/Users/ADMIN/AppData/Local/Microsoft/WinGet/Links/godot.exe
# Frequency of the regions (seconds): the story's 200 seeded runs
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --region-freq=200 > "<scratch>/region_freq.out" 2>&1
grep "^REGION FREQ" "<scratch>/region_freq.out"
# Smoke (about 1 min): one new region, one floor, 2 seeds
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --region=hellfire --floor=1 --seeds=2 --characters=kiem_si
# The story table: both new regions and the five existing ones at floors 1, 3, 5 (one character per invocation)
for c in kiem_si phap_su sat_thu; do
  $GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --region=hellfire,sky_isles --floor=1,3,5 --seeds=70 --characters=$c > "<scratch>/regions039_$c.out" 2>&1
  $GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --region=ch1,ch2,ch3,swamp,desert --floor=1,3,5 --seeds=70 --characters=$c > "<scratch>/regions_old5_$c.out" 2>&1
done
grep "REGION MEAN \|REGION 039\|REGION CHECK" "<scratch>"/regions039_*.out "<scratch>"/regions_old5_*.out
# The fire_eater bullet: the Phap su starter deck at floor 1 (REGION 039 FIRE EATER line)
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --region=hellfire --floor=1 --seeds=70 --characters=phap_su > "<scratch>/fire_eater.out" 2>&1
# One match in detail (vents / falls per match, the hazards line):
$GODOT --headless --path . -s res://tools/balance/hit_probe.gd -- --region=sky_isles --floor=1 --seeds=20 --characters=kiem_si
```

Reading the story targets from the output: the mean win % of a new region (`REGION MEAN`, same floor and character) within
+-10 points of the mean of the five existing regions' `REGION MEAN` rows (average the five lines by hand); no floor-1 match
outside 15-95 % (`REGION CHECK`); `REGION 039 FIRE EATER` >= 25 for `phap_su`; `REGION FREQ CHECK` PASS. Tuning is JSON only
(`chapters.json` match numbers, `combat.json` `hazards`, `arenas.json`).

## Story 040: the v6 run tables (`--run=v6`, `--floors`, `--mercy`, `--shop`, `--pieces`, `--relic`, `--dodge=a,b,c`)

Story 040 balances the whole v6 run (5 floors + the final match, relics, gold, piece deck, Spare / Execute, Kiep) by data. This
section is the tooling half: aliases for the policy flags that already existed, two new bot policies, the out-of-match time
table, and the Part C table / VERDICT lines. **Without any flag below the output is byte-identical to before** (checked
before / after on `--world --seeds=3 --fate=alternate --relic-policy=pick`, `--world --piece-deck=small_out --shop-policy=eager
--node-overhead=30 --dodge=0.7`, `--world --kiep=0..1` and chapter mode, `diff` empty apart from `runtime:` and the seed
progress lines). Nothing here reads or writes game code or `assets/data`.

### Flags

Every flag below turns on world mode and the v6 tables (`--tables=v6`); `--tables=none` turns the tables off again.

| Flag | Meaning |
|---|---|
| `--run=v6` | `--world` plus the v6 tables. Nothing else is implied: the policy flags below stay at the old defaults. |
| `--floors=a..b` or `a` | Play only floors a..b of the 5 (1-based). Default 1..5. The run starts at floor a with the starter deck at full HP, so this is a probe, not a slice of a real run. The final match is played only when b is the last floor and `--final` is not `off`. A run "wins" when it clears the last floor it plays. The old WORLD tables show unplayed floors as 100 % alive: read the RUN tables. |
| `--final=on\|off` | Play the final match (default on). `off` ends the run after the last floor. |
| `--mercy=kill\|spare\|mixed` | `--fate=execute\|spare\|alternate`. A comma list (`--mercy=kill,spare`) runs the same seeds once per value, see Variants. |
| `--shop=on\|off` | `on` = `--shop-policy=greedy` **plus the v6 extras**: after the greedy buys the bot also buys the remove-card service while the deck holds more than 10 cards (the lowest-value card), and with `--pieces=on` the remove-shape service. `off` = `--shop-policy=none`. For the old greedy bot alone use `--shop-policy=greedy`. |
| `--pieces=on\|off` | `on` = the bot piece-deck policy below; `off` = no piece deck (or whatever `--piece-deck` gave). `--pieces=on,off` = both, see Variants. |
| `--relic=value\|random\|none` | How the bot chooses from a relic offer (treasure row and Execute offer). `value` = the offered relic with the best score = rarity rank x 10 + a per-relic bonus from a STATIC table in `deck_sim.gd` (`RELIC_VALUE_BONUS`, printed in the header: `an_don`, `tui_rong`, `tam_hop` +3; `chi_khau`, `khoi_the`, `tam_huong`, `an_chu` +2; others +1 / 0; `huyet_an` -50 so it is never the first pick; the first best on a tie). It is an assumption, not a measurement. `random` = a seeded random pick of the offer. `none` = `--relic-policy=none` (never takes a relic row). The old `--relic-policy=pick\|none` still works (`pick` = rarest first). |
| `--dodge=a,b,c` | A list runs the SAME seeds at each dodge value (the bot dodge chance, TD-006). One value = the old flag. |
| `--tables=v6\|none` | Force the v6 tables on, or off. |
| `--seed-offset=N` | Run seeds N+1..N+seeds instead of 1..seeds (the header prints it). The final check of a tuning pass uses a seed set the tuning rounds never saw (Story 040 Implementation Notes). |
| `--char-set=<id>.<key path>:<X\|xF>[,...]` | Override characters.json in memory, like `--world-set` for chapters.json: `X` sets, `xF` multiplies; the key path walks the character's dictionary (`phap_su.max_hp:210`, `phap_su.signature.params.burn_damage_per_tick:x1.5`). Each applied override is printed; unknown keys are printed and ignored. Lets character probes run side by side without editing the data file. |
| `--node-overhead=S` | Still works. When passed it replaces the out-of-match table below (S seconds per node, no intro / end delay), which is exactly the old formula. |

### Piece-deck policy (`--pieces=on`)

The run keeps its own `PieceDeck` state (`WorldRun.piece_deck`, set into `sim_core` before every match, boss drops untouched,
exactly the `--piece-deck` path of Story 034 but per run). It mirrors the real run:

- **Ink rows**: after a won battle / danger node with chance `piece_rewards.ink_offer_chance`, after every treasure, rolled by
  `PieceDeck.roll_ink_offer` with `GameFlow._roll_ink_for`'s seed (`hash([run_seed, floor, region, column, nodes_cleared, "ink"])`).
  The bot inks the offered shape of **2 or 3 cells** with the fewest cells (first on a tie); if none is offered it skips.
  In the shipped `pieces.json` the only 2-3 cell shapes are the default ones (`bar2`, `bar3`, `l3`; `mono` has 1 cell, the run-only
  `z4` / `j4` / `y5` have 4-5), so the bot only ever raises the multiplier of those three (`mult_step` each, up to `mult_max`) and
  never takes a run-only shape.
- **Removals**: it has `shape_removals_start` tokens at the start and gains `shape_removals_per_boss` per region boss, and spends
  every token at once on the **5-cell default shape with the biggest bounding box** (a static stand-in for "fits the arenas
  least"), never below `min_shapes`. With `--shop=on` it also buys the remove-shape service when it can pay.

The header line `v6 pieces policy` says this, the `WORLD PIECES` table (Story 034) is printed as with `--piece-deck`, and the
RUN table's last column is the mean number of active shapes at the end of the run (16 = the start deck).

### Run time, with the out-of-match seconds

`est. minutes` of the v6 tables = (sum of match **real** seconds (the player's wall clock, including the 0.2x menu slow motion)
+ the out-of-match seconds below) / 60. The match's own `intro_sec` + `end_delay_sec` (RunConfig) are added per match; event
fights included. Constants at the top of `deck_sim.gd` and printed in the header, all **assumptions** (TD-006 family):

| Visit | Seconds | | Visit | Seconds |
|---|---|---|---|---|
| map pick, per node | 8 | | event node | 30 |
| reward pick (cards, or the relic row; the ink row is part of it) | 15 | | rest node | 10 |
| shop node | 45 | | Spare / Execute choice | 10 |

The old `WORLD SUMMARY` line keeps the old 25 s per node formula (`--node-overhead`), so the old output does not move; the v6
tables use the table above. Pass `--node-overhead=S` to put the old formula in the v6 tables too.

### Output (all lines start with the name in the first column)

| Line | Content |
|---|---|
| `RUN \| character \| policy \| kiep \| win % \| deaths by floor \| hits taken / won run \| run minutes \| gold earned / spent \| relics / run \| deck size \| piece set size` | One row per character and policy. `policy` = `build` plus the flags in force. Deaths by floor = `f1/f2/f3/f4/f5/final` (counts). Run minutes = won median / lost median. Gold = mean per run over all runs; then over won runs. |
| `RUN DETAIL` | death % of the runs entering each floor, final reached / won, the mean boss swing hit as % of max HP (swing hits only: `bdmg / shits / max HP`), the median gold when the final floor starts, the shop relic price it is compared with (common relic at the last floor). |
| `REGION x FLOOR \| character \| floor \| region \| matches entered \| match win %` and `REGION x FLOOR CHECK` | Every match of the runs (event fights included, the final left out) by floor and region. The CHECK needs >= 20 matches in a cell (smaller cells are marked `small` and left out; `DEFERRED` when none is left) and passes when every checked region sits within +-10 points of that floor's mean match win %. |
| `RELIC LIFT \| relic \| runs with it by floor <= 2 \| win % with \| win % without \| lift (pts)` | From the runs of the invocation (all characters and policies pooled). A relic counts as "with" when owned at the end of floor 2 (or at death, when the run ended earlier). It is a correlation, not a causal lift: a relic that is found in a good run looks good. Cells under 10 runs (with or without) are `small`. `RELIC LIFT CHECK`: no non-small relic above +15. |
| `SHOP \| item \| bought \| offered \| bought % of shop visits \| bought % of offers` | Items are `card:<id>`, `relic:<id>`, `service:<id>` (`remove_card`, `heal`, `remove_shape`). `SHOP CHECK` prints the literal story rule (bought in < 2 % of shop visits; almost every card and relic fails it because a given item is rarely in stock, so it is information only) and the rule it judges: **offered in >= 10 visits and bought in < 2 % of those offers** = "never worth buying". `DEFERRED` under 20 shop visits. |
| `VERDICT run <character>/<policy> \| what \| value \| PASS\|FAIL\|DEFERRED` | The Part C targets, one line each, see below. |
| `VERDICT run all` | The invocation-wide ones: relic lift, shop, spread between characters, and the comparisons. |
| `DODGE SENSITIVITY \| character \| dodge \| win % \| variant` | With a `--dodge` list: one row per character and value. |

The old WORLD tables and `WORLD VERDICT` lines are printed first, unchanged, then the RUN block (RUN, RUN DETAIL, REGION x FLOOR,
VERDICT run), then the AGGREGATE block (RELIC LIFT, SHOP, spread).

### How to read `VERDICT run`

| Line | Target (Part C) | Notes |
|---|---|---|
| run win % | 30-45 per character | shown with its binomial sd: at 70 seeds one sd is about 6 points. The 20-point spread between characters is `VERDICT run all`. |
| death probability non-decreasing f1..f5 | p(f) >= p(f-1) - 3 pts, p = deaths on floor f / runs that entered it | `DEFERRED` when a floor was entered < 10 times. |
| floor-1 deaths | <= 10 % of runs | |
| final-match win when reached | 50-70 % | `DEFERRED` with `--final=off` or no run reaching it. |
| won-run minutes median / lost-run minutes median | 40-50 / >= 15 | the table above. |
| boss hits per won run; mean boss hit | 15-30; 4-15 % of max HP | swing hits only in the second (fuse / slam hits are in the first, not the second). |
| gold | spent >= 70 % of earned in won runs; median gold when the final floor starts <= the common shop relic price at the last floor | |
| regions | the REGION x FLOOR CHECK result | |
| onboarding win >= 20 % | needs an empty save | `DEFERRED` unless the run has `--progress=none` (then the run win % is used; this is the closest the world sim has to "cleared_bosses 0"). |
| bot anchored on a playtest | Part A | **always `DEFERRED`** while `DEFAULT_BOT` is the legacy dodge. |
| kill vs spare gap <= 10; pieces on not above off by > 10 | needs both runs | PASS / FAIL when one invocation ran `--mercy=kill,spare` / `--pieces=on,off`; otherwise `DEFERRED` with the command. |
| Kiep monotone 0..10, Kiep 10 >= 3 % | the `KIEP CHECK` lines | always `DEFERRED` here: run `--kiep=0..10` (Story 038 section). |
| no relic lift > +15; no shop item never worth buying | see the tables above | |

**DEFERRED is not a pass.** The story forbids PASS for the anchor criterion without playtest data: `DEFAULT_BOT` (`sim_core.gd`)
still holds `dodge=0.85`, the TD-006 legacy value, and TD-006 stays open. Every number above is conditional on that dodge: read
the `DODGE SENSITIVITY` rows (below) before trusting a verdict.

### Variants: `--dodge=a,b,c`, `--mercy=kill,spare`, `--pieces=on,off`

A list on any of the three runs the same seeds once per combination (the cartesian product). Each variant prints
`=== VARIANT dodge=.. mercy=.. pieces=.. ===`, its `bot:` header, its WORLD tables, its RUN / REGION x FLOOR / VERDICT block and
its AGGREGATE block. At the end: `DODGE SENSITIVITY` (with a dodge list) and the comparison VERDICT lines (kill vs spare gap
<= 10; pieces on not above off by > 10) per character, within the same dodge. A single value, or no list, is a plain run.
Runs of the Kiep modes (`--kiep`) take the first value only.

### DODGE SENSITIVITY (Story 040 Part A, second bullet)

While no playtest log exists, report every table at three dodge values and say how far the verdicts move:

```sh
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --run=v6 --seeds=70 --characters=kiem_si --dodge=0.7,0.85,0.95 > "<scratch>/dodge_kiem_si.out" 2>&1
grep -E "^RUN \||^DODGE SENSITIVITY|^VERDICT run" "<scratch>/dodge_kiem_si.out"
```

Read it as: if the win % band (30-45) is hit at 0.85 but missed at 0.70 and 0.95, the data is tuned to one guess about the
player; widen the margin until the three rows are inside or near the band, or record the spread in Completion Notes. When a
playtest gives the real dodge, change `DEFAULT_BOT["dodge"]` (and `LEGACY_DODGE_P` label), update "The TD-006 dodge assumption"
and re-run; until then the criterion is `DEFERRED`.

### Command lines

```sh
GODOT=C:/Users/ADMIN/AppData/Local/Microsoft/WinGet/Links/godot.exe
# Smoke (about 13 s): parse + the tables, 3 seeds, one character
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --run=v6 --seeds=3 --characters=kiem_si
# The final Part E run, one character per invocation (about 3.5 s per run: ~4-5 min each; one Godot at a time):
for c in kiem_si phap_su sat_thu tho_san giao_si; do
  timeout 3000 $GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --run=v6 --seeds=70 --characters=$c --mercy=mixed --shop=on --pieces=off --relic=value > "<scratch>/v6_$c.out" 2>&1
done
# The comparisons (4 variants in one invocation, about 4x as long): kill vs spare and pieces on vs off
timeout 6000 $GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --run=v6 --seeds=70 --characters=kiem_si --mercy=kill,spare --pieces=on,off --shop=on --relic=value > "<scratch>/v6_cmp_kiem_si.out" 2>&1
# Relic lift needs many runs of one invocation: all five characters, 70 seeds, pooled (run the characters in one process)
timeout 9000 $GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --run=v6 --seeds=70 --characters=kiem_si,phap_su,sat_thu,tho_san,giao_si --mercy=mixed --shop=on --relic=value > "<scratch>/v6_all.out" 2>&1
# Relic none, Kiep (Story 038 flags compose; the v6 per-character tables print only for a single Kiep level)
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --run=v6 --seeds=70 --characters=kiem_si --relic=none
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --world --seeds=30 --characters=kiem_si --kiep=0..10
grep -E "^RUN \||^RUN DETAIL|^REGION x FLOOR CHECK|^VERDICT run|^RELIC LIFT CHECK|^SHOP CHECK|^DODGE" "<scratch>/v6_all.out"
```

Change one thing at a time between tuning runs and use a different seed set for the final run: seeds are `1..N` unless
`--seed-offset=N` moves them (`N+1..N+seeds`); Story 040 tuned on offsets 0 / 100 / 200 / 300 and checked on 1000 and 2000.
`--char-set` probes a character change without editing characters.json, so several probes run side by side.

Measured runtimes (Story 040 Part E, 12-thread Windows machine, up to 11 Godot processes at once): smoke 5 seeds x one
character 38 s; 70 seeds x one character about 7-9 minutes; five characters in one process at 70 seeds 36 minutes
(2184 s); Kiep 0..3 at 30 seeds about 14 minutes. One 70-seed cell has about 5-6 points of standard deviation on run win %,
a 30-seed cell about 8-9.

### What the v6 policies do not model

- The relic value table, the 5-cell removal order and the 2-3 cell ink rule are simple rules written for the bot, not a solver.
- The bot never skips a shop for lack of a plan: with `--shop=on` it buys greedy, then the extras.
- `--floors=a..b` is a probe: the run starts with the starter deck and full HP at floor a.
- The onboarding line uses `--progress=none` (locked pools), not `cleared_bosses 0`.
- Out-of-match times are assumptions until a playtest gives them (TD-006 family, Part A also asks for the drag and card-pick
  times: `--place-sec`, `--choose-sec`, `--join-sec`).

## Story 041: odd blocks (`--odd=on|off`, `--odd-chance=X`, the `ODD` line)

Odd blocks ("Khối Lạ") reach the sim through the same path as the game: sim_core loads `FieldDropsConfig` from
`assets/data/field_drops.json` (block `odd_blocks`, chance 0.25 shipped), both sides' drops configs are copies of it, and
`FieldDrops.enable_pieces` prepares odd blocks for its target half (player drops target the boss's half, the boss's drops
the player's half). Tick spawns roll the odd chance on the drops' own odd RNG; start pieces are never odd; a failed
generation falls back to a classic piece. The bot picks up, rotates, places and joins odd pieces with the same planner as
classic pieces (5-7 cells; the placement cache keys odd pieces on their turned cells, because two odd blocks of one
canonical shape can be grown in different base orientations). Per match, sim_core applies the chapter match key
`odd_blocks` (merged over the file block, like `CombatView._apply_odd_overrides`), then the flags below.

### Flags (sim_core, so deck_sim and hit_probe both take them)

| Flag | Default | Meaning |
|---|---|---|
| `--odd=on\|off` | on | `on` = the data's chance (and the match key, if any). `off` = chance 0 on BOTH sides (no odd roll at all, so the classic draw sequence is the pre-041 one). |
| `--odd-chance=X` | data | 0..1, overrides the chance on BOTH sides, after the match key. `--odd=off` wins over it. |
| `--aware-min=N` | 3 | Now accepts 1..7 (odd blocks reach 7 cells), was 1..5. |

The header (`bot: ... | overrides: ... | <odd>`, every mode) ends with `odd=on chance=0.25 (data) sizes 5..7
max=clamp(cells/4+3, 4, 7) weights={...} tries=40`, `odd=on chance=1.00 (--odd-chance) ...`, `odd=off (--odd=off: chance
0 on both sides)` or `odd=off (chance 0 in data)`.

### The `ODD` line (world mode, plain `--world` and `--run=v6`; one per character / policy)

```
ODD | character | odd share of player drops % | mean odd size | odd fallbacks (total; per run) | boss odd share % | policy | player odd / drops | boss odd / drops | boss mean odd size | boss fallbacks | matches with odd possible player / boss / all | <odd header>
ODD | kiem_si | 20.7 | 5.48 | 3; 1.00 | 28.9 | build [mercy=none ...] | 131 / 632 | 178 / 616 | 5.44 | 2 | 33 / 33 / 33 |
```

Every match of the character's runs is summed (extra fights included). Share = odd spawns / ALL piece spawns of that half
(`FieldDrops.get_odd_spawned / get_total_spawned`; start pieces count as drops, so at `--odd-chance=1` the player share stays
below 100 %). Mean size = odd cells / odd spawns (from `point_spawned`). Fallbacks = odd rolls whose generation failed
(`get_odd_fallbacks`, player half; the boss's are a later column). "Matches with odd possible" = matches whose half allowed an
odd size (`is_odd_enabled`; the size rule turns them off when `min_cells` > the half's max size). With the shipped
chance 0.25 the expected player share is a bit under 25 % (start pieces dilute it). The `--kiep` compact tables do not print it.

### Comparing on / off on the same seeds (Story 041 Part E)

Run the two variants as two invocations with the SAME `--seed-offset` and only the odd flag different; use a seed set the
Story 040 tuning never saw (it used offsets 0 / 100 / 200 / 300 / 1000 / 2000):

```sh
for c in kiem_si phap_su sat_thu tho_san giao_si; do
  for o in on off; do
    timeout 3000 $GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --run=v6 --seeds=70 --seed-offset=3000 --characters=$c --mercy=mixed --shop=on --pieces=off --relic=value --odd=$o > "<scratch>/v6_odd_${o}_$c.out" 2>&1
  done
done
grep -hE "^RUN \||^ODD \|" "<scratch>"/v6_odd_*.out
```

Compare the `RUN` win % of each character between the on and off files (Part E: 30-45 %, or within ±5 points of Story 040's
44.3 / 35.7 / 42.9 / 27.1 / 47.1, and no character > 10 points apart between on and off). Odd blocks draw on their own RNG,
but the matches still diverge once an odd piece lands (different casts, different HP), so on/off is a paired comparison of
the same seeds, not identical runs. Tune only data (`chance`, `size_weights`, `min_cells`); `--odd-chance=X` probes a chance
without editing the JSON. Smoke (3 seeds, about 10-25 s each): `--run=v6 --seeds=3 --characters=kiem_si --odd=on`
(then `--odd=off`, `--odd-chance=1`).

## 2026-11-04: pattern-brain matches, cracking cells, `pool:`

- `sim_core.gd` plays `brain: "pattern"` matches like `CombatView._setup_pattern_brain`: a PatternController per match (no
  boss pieces), the bot dodges a pattern warning (or queued stripe) on its cell with the same `--dodge` chance and
  reaction as a boss swing, and pattern strikes count in the boss columns (swings, hits, damage taken).
- The bot treats a cracking cell (drop tile) as blocked and steps off one cracking under it. Before this it stood on the
  Ancient Root Sentinel's drop tiles and fell (lethal), so older Sentinel / world numbers are too harsh.
- The stale `CutFlow.update_cut(..., combat.join_extra_sec)` call (removed from the game 2026-11-01) no longer errors.
- `--world-set=pool:ch1` (or `pool:ch1|swamp`) sets `world.region_pool`, e.g. every floor in one region.

