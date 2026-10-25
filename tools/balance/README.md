# Balance tools (`tools/balance/`)

Headless simulators that play the real v5 combat code with a scripted player. Use them to measure
chapter win rates and per-boss hit rates before and after changing data. They are **tools, not
tests**: the test runner never runs them, and the game never loads them. Story 026 moved them here
from session scratch.

| File | What it is |
|---|---|
| `sim_core.gd` | Shared harness. It builds one match the way `CombatView._ready` does and runs `CombatView._process`'s tick order headless. It contains the v5 player bot. Both tools preload it. |
| `deck_sim.gd` | Full-run simulator. It plays seeds × characters × chapters through the chapter map with the reward policy, then prints win %, boss hits per won run, and per-kind and per-match tables. |
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
2. **`NODE KIND BREAKDOWN`** and **`PER-MATCH`**: win %, hits, damage and deaths by node kind and by
   boss. These show which boss breaks the curve.
3. **`VERDICT chN char/build`**: win % against the Story 023/026 targets (ch1 40–60, ch2 25–45,
   ch3 15–35) and hits per won run against 15–30. **`RESULT: ALL PASS | FAIL`** covers only the build
   rows' win targets, as before.

Old and new numbers are comparable column by column. The bot is a different player, though: it must
walk to pieces, and a cast is one or two puzzle pieces rather than connected runes. Treat a shift as
"rules + bot changed" and not as balance drift alone.

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
