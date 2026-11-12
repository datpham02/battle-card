# B1 Hellfire Warden — bot playtest (live game, not the balance simulator), 2026-11-12

Requested by the user ("bạn xài bot test giúp tôi đi") in place of the human playtest. **This is a bot, not a
human**: it answers the measurable questions (timing, dodgeability, vent damage per policy) and cannot rate fun,
readability or the cost of dodging to a planned combo. The human result log in
`human-playtest-b1-warden-2026-11-12.md` §8 stays empty.

## 1. What ran

- Driver: `warden_bot.gd` (scratchpad script, copy `warden_bot.gd.txt` here; not a repo test). It boots the real game
  (`main.tscn`, memory store), picks the hero, and enters **one live warden fight composed exactly as the route would
  compose it**: `EncounterComposer.profile(warden node, "hellfire", heat)` → `RunConfig.from_node(..., "inferno_lord",
  "boss", seed, floor 1, profile)` → `GameFlow.enter_test_floor` (the same calls the game and the flow test use). The
  match is printed at start: at Heat 4 `vent_surge {interval 7, first_delay 10, vents 2}`, hazards clock 4.0 s,
  warn 1.0 s, burn 2.5 s, tick 3.0, two vents on the player's half.
- Play: the `tools/qa/play_bot.gd` loop (random pieces placed on the boss, a card or the 4 s clock, lifts) plus a
  **vent policy**: `dodge` = after a reaction time (0.3 s or 0.6 s) on a warned / erupting cell, step along the
  shortest path to a safe cell (cancelling a placement if movement is locked); `naive` = ignores vents entirely
  (upper bound of vent damage). The bot never dodges the boss's cuts — losses with 0 vent damage are boss damage.
- Instrumentation (per fight): surge times on the **simulated clock** (the match slows / stops while placing or in
  the card menu, so real seconds run longer — both are printed), vents started per surge, warnings on the bot's own
  cell, **unescapable** warnings (nearest safe cell farther than 1.0 s ÷ 0.268 s per step allows), hits by vents and
  **attributable vent damage** (`StatusEffects.burn_hurt` on a cell `TileHazards.is_venting`), hits while movement
  was cast-locked, dodges, casts abandoned, phase-2 time, result, HP. Screenshots: first surge, phase 2, end.
- Matrix: `run-warden-bot-matrix.sh` — 5 heroes × Heat 2 / 3 / 4 × seeds 1, 2 with dodge 0.3 s (30 fights) + the 3
  priority heroes × 3 heats with dodge 0.6 s and with naive (18) = **48 fights**, 17:34 → 17:51, all `exit=0`, no
  script errors, every fight ended (no time-outs). Raw: `<hero>-heat<h>-<policy><react>-s<seed>.log`, `matrix.log`,
  `jobs.txt`; tables: `aggregate-bot.py` → `aggregate-bot.md`.

## 2. B1 timing confirmed in the live game

| Heat | expected first surge / gap | fights | first surge (sim s) | gap mean (min–max) | gaps measured |
|---|---|---|---|---|---|
| 2 | 10 / 10 | 13 | 10.0 (10.0–10.0) | 10.1 (10.0–10.2) | 47 |
| 3 | 10 / 7 | 13 | 10.0 (10.0–10.2) | 7.0 (7.0–7.2) | 49 |
| 4 | 10 / 7 | 13 | 10.0 (10.0–10.0) | 7.0 (6.9–7.2) | 65 |

Vents per surge: 2 when both columns were idle, 1 when the regular clock already had one going (e.g.
`[1,2,2,1,1,1,1]` at Heat 4 — the regular 4.0 s clock often occupies a column, so the surge adds the other). On the
real clock the gaps stretch (e.g. 99 s of simulated fight = 202 s real for kiem_si Heat 4 dodge 0.6) because the
game slows the match while the player places or chooses — a human sees the same.

## 3. Dodging bot (0.3 s reaction), 5 heroes × 3 heats × 2 seeds

| hero | Heat 2: W / sim s / HP end / vent hits / vent dmg / warnings on own cell / unescapable | Heat 3 | Heat 4 |
|---|---|---|---|
| sat_thu | 2/2 / 43 s / 30 % / 1 / 2 / 6 / 0 | 1/2 / 62 s / 28 % / 1 / 3 / 5 / 0 | 2/2 / 37 s / 57 % / 0 / 0 / 3 / 0 |
| giao_si | 2/2 / 41 s / 56 % / 0 / 0 / 5 / 0 | 2/2 / 38 s / 48 % / 0 / 0 / 5 / 0 | 2/2 / 63 s / 8 % / 0 / 0 / 7 / 0 |
| kiem_si | 2/2 / 49 s / 24 % / 0 / 0 / 4 / 0 | 2/2 / 34 s / 48 % / 0 / 0 / 6 / 0 | 1/2 / 41 s / 30 % / 0 / 0 / 3 / 0 |
| phap_su | 2/2 / 66 s / 34 % / 0 / 0 / 6 / 0 | 2/2 / 32 s / 76 % / 0 / 0 / 3 / 0 | 2/2 / 48 s / 69 % / 0 / 0 / 8 / 0 |
| tho_san | 2/2 / 46 s / 30 % / 0 / 0 / 1 / 0 | 1/2 / 39 s / 48 % / 0 / 0 / 4 / 0 | 1/2 / 38 s / 30 % / 1 / 3 / 3 / 0 |

Totals over the 30 fights: **26 wins / 4 losses**; 69 warnings landed on the bot's own cell → 66 dodges; **3 vent
hits, 8 vent damage in total** (never more than 3 in a fight, i.e. one tick); **0 unescapable warnings**; **0 hits
while cast-locked**; 0 casts had to be cancelled. The 4 losses (sat_thu H3 s2, kiem_si H4 s1, tho_san H3 s2, H4 s2)
all have **0 vent damage** — the random-piece bot died to the boss's cuts, which it does not dodge; nothing in the
losses points at the vents. With a 0.3 s reaction the B1 vents are, for every hero and every heat, avoidable.

## 4. Reaction time and the non-dodging upper bound (3 priority heroes, seed 1)

| hero | Heat | dodge 0.3 s | dodge 0.6 s | naive (ignores vents) |
|---|---|---|---|---|
| sat_thu | 2 | 1 hit / 2 dmg / WIN 21 % | 0 / 0 / WIN 33 % | 9 hits / 22 dmg / WIN 68 % |
| sat_thu | 3 | 1 / 3 / WIN 56 % | 0 / 0 / WIN 67 % | 9 / 37 / WIN 23 % |
| sat_thu | 4 | 0 / 0 / WIN 100 % | 1 / 3 / WIN 44 % | 6 / 36 / **LOSS** |
| giao_si | 2 | 0 / 0 / WIN 50 % | 0 / 0 / LOSS (boss) | 6 / 13 / WIN 69 % |
| giao_si | 3 | 0 / 0 / WIN 37 % | 0 / 0 / WIN 68 % | 7 / 27 / **LOSS** |
| giao_si | 4 | 0 / 0 / WIN 15 % | 0 / 0 / WIN 40 % | 15 / 55 / WIN 0 % (alive on < 1 HP) |
| kiem_si | 2 | 0 / 0 / WIN 4 % | 0 / 0 / WIN 76 % | 8 / 18 / WIN 80 % |
| kiem_si | 3 | 0 / 0 / WIN 81 % | 0 / 0 / LOSS (boss) | 13 / 45 / WIN 62 % |
| kiem_si | 4 | 0 / 0 / LOSS (boss) | 3 / 12 / LOSS (boss) | 16 / 70 / **LOSS** |

- **0.6 s reaction** (a slow human): 4 vent hits / 15 damage over 9 fights — still negligible against 180–210 HP.
- **Naive**: mean vent damage per fight **Heat 2 ≈ 18, Heat 3 ≈ 36, Heat 4 ≈ 54** (of 180–210 HP), 6–16 hits per
  fight. This is the progression the design wants, measured on a player who never moves for a vent: Heat 3 doubles
  the vent cost, Heat 4 triples it; Heat 4 killed 2 of the 3 naive runs. For a player who reacts, it is a tempo
  cost (66 forced moves in 30 fights), not an HP cost.

## 5. Readings against the playtest questions (bot's share only)

| Question (brief §2) | Bot answer | Needs a human |
|---|---|---|
| 1. Is the 7 s surge too frequent? | Dodgeable at 0.3 s and 0.6 s reaction with ~0 damage; one forced relocation every ~7 s (plus the regular clock). Whether that *feels* too frequent: not answerable by a bot. | yes (feel) |
| 2. Is the 2.5 s Heat-4 burn too punishing? | For a dodging player no extra damage was measured (0 hits at Heat 4 in 10 dodge fights); for a non-dodging player Heat 4 is the most punishing tier (≈54 vent damage). The columns stay denied 2.5 s — tempo, not HP. | yes (feel) |
| 3. Warnings readable, enough reaction time? | Mechanically yes: 1.0 s warning vs 0.268 s per step, 0 unescapable warnings in 48 fights (the `(4,2)` 3-step cell was never a problem in practice). Visual readability (streak + "SẮP PHUN") is a human rating. | yes (readability) |
| 4. Dodging without losing combat opportunities? | The bot never had to cancel a placement (0 abandoned) and lost no cast to a vent; but its casts are random, not planned combos. | yes |
| 5. Heat 3 / 4 feel more dangerous than Heat 2? | Measurable, yes: surge every 7 s instead of 10 s; naive vent damage ×2 / ×3; Heat 4 burns longer. Whether 3 vs 4 is *felt* by a dodging player: unanswered. | yes |
| 6. Fair across heroes? | No hero took meaningful vent damage; all 4 dodge losses were boss cuts. sat_thu (180 HP) and giao_si (210, heals) show no vent-specific problem. | yes (fun) |

## 6. Limitations of the bot evidence

- Random pieces and cards, no cut dodging: fights are short (32–66 s simulated, 3–13 surges) and wins / losses say
  nothing about vent fairness beyond "0 vent damage in the losses".
- The dodge policy moves along the shortest path the frame the reaction time elapses — a human is noisier.
- `enter_test_floor` draws the Misty Forest backdrop (the art region is not set by this harness; the arena, vents and
  boss are the real Hellfire warden). Cosmetic only.
- Warden HP in this harness is the floor-2-scaled value the game uses (≈101 at this point of the climb), with a fresh
  floor-2 hero (no floor-1 rewards), as in the dev launch.
- Videos (`video/`, seed 3, dodge 0.3 s, 3 heroes × 3 heats, recorded in Movie Maker mode at 60 fps and transcoded to
  H.264 mp4 at 30 fps; the 7.1 GB of raw AVIs were deleted after transcoding; the folder is git-ignored) — for a human
  to watch the rhythm. Results of the recorded fights (`video/videos.log`): sat_thu H2 WIN 38/180, H3 WIN 162/180,
  H4 WIN 29/180; giao_si H2 WIN 132/210, H3 WIN 20/210, H4 WIN 68/210; kiem_si H2 LOSS (boss cuts, 0 vent dmg),
  H3 WIN 160/200, H4 WIN 56/200. First surge 10.0 s in all nine; gaps 10.0 / 7.0 / 7.0. One gap of 14.0 s in
  sat_thu H4 = a surge that found both columns already busy (started 0 vents, so it is not counted) — a human sees
  no "extra" surge there either.
- A surge that starts 0 vents (both columns warning / erupting from the regular clock) is skipped by the trait and
  therefore invisible; at Heat 4 (4.0 s clock, 2.5 s burns) this happened once in 48 + 9 fights.

## 7. Files

`bot/`: `warden_bot.gd.txt` (driver copy), `run-warden-bot-matrix.sh`, `jobs.txt`, `matrix.log`, 48 `*.log`,
117 screenshots `<fight>-<n>-<first-surge|phase2|end>.png`, `aggregate-bot.py`, `aggregate-bot.md`,
`run-warden-bot-videos.sh`, `video/`. No data, code or test of the repo changed; nothing committed.
