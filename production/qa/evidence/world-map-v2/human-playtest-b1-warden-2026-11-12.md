# World Map v2 — B1 human Warden playtest (Hellfire), prepared 2026-11-12

User brief: "B1 Human Warden Playtest Preparation". **Preparation only — no scenario has been played yet** (§9 lists
them all as NOT PLAYED). No gameplay parameter, data file or code was changed; nothing committed.

Configuration under test (B1, shipped in `assets/data/region_rules.json` since the hook fix): rest −2, shop −1, peril
modifier slots `[0, 1, 1]`, warden hook at Heat ≥ 3 = `vent_surge {interval_sec 7.0, first_delay_sec 10.0}`, Heat-4
row `vent_sec 2.5`. Simulator validation: `b1-balance-validation-2026-11-12.md` (PASS on the run-level criteria;
the bot evades vents, so fairness and fun are **not** validated — this playtest is that step).

## 0. History and what changed since the earlier playtest document

`human-playtest-heat-decay-2026-11-12.md` (earlier the same day) prepared the same H2 / C3 / C4 scenarios for the
**pre-B1** data. It stays as the historical record; two of its statements are no longer current and are corrected here:

| Earlier finding | Status now |
|---|---|
| **F1** — C and D produce the identical warden at the same integer Heat (the composer reads the gauge only) | **Still true.** "C3 / C4" are scenario names for Heat 3 / Heat 4, not the old baseline configuration; under B1 the fight at a given Heat is the B1 fight, whatever route decay brought the player there. |
| **F2** — the warden hook `vents 3` was a no-op in the caldera (2 vents per half; `trigger_vents` clamps) | **Historical.** Root cause and fix: `warden-heat-hook-investigation-2026-11-12.md`, `warden-heat-hook-implementation-2026-11-12.md`. Under B1 the hook sets the surge **interval to 7 s** (first surge still at 10 s) and does not touch `vents`; the surge is both columns, as always. |
| Earlier Heat table (surge identical at every Heat; Heat 3 vs 4 = 0.5 s of clock) | **Replaced** by §2 below. |

## 1. The B1 warden per Heat (Chúa Quỷ Lửa / `inferno_lord`, arena caldera)

Verified live for this preparation on seed 27, Heat 4, headless (`human-playtest-b1/seed27-paths-and-warden-probe-b1.txt`):
match traits `vent_surge {interval_sec 7.0, vents 2.0, first_delay_sec 10.0}` + `phase_shift {…, vent_interval_mult 0.7}`,
hazards `vent_interval_sec 4.0, vent_warn_sec 1.0, vent_sec 2.5, vent_tick_sec 0.5, vent_tick_damage 3.0`, player
half vents = 2 (columns 1 and 4, five cells each).

| | H2 — Heat 2 (control, hook inactive) | C3 — Heat 3 (hook active) | C4 — Heat 4 (hook active) |
|---|---|---|---|
| Surge (`vent_surge`): **both** player columns warn 1 s → erupt | every **10 s**, first at 10 s | every **7 s**, first at 10 s | every **7 s**, first at 10 s |
| Eruption burn length | 2.0 s | 2.0 s | **2.5 s** |
| Regular clock: one random *idle* vent of the arena's 4 (both halves) | 5.0 s | 4.5 s | 4.0 s |
| Regular clock after phase 2 (boss ≤ 50 % HP, ×0.7) | 3.5 s | 3.15 s | 2.8 s |
| Burn per 0.5 s tick on an erupting cell (if you stand in it) | 2 | 3 | 3 |
| Full eruption if you never leave the cell | 8 | 12 | 15 |
| Boss piece-drop interval | ×1.0 | ×0.9 | ×0.9 |
| Warning before every eruption | 1.0 s | 1.0 s | 1.0 s |
| Columns unusable per surge cycle (warn + burn) | 3 s / 10 s = 30 % | 3 s / 7 s = 43 % | 3.5 s / 7 s = 50 % |

Geometry: the player's half is 5 × 5 minus the three missing cells of column 3 (rows 1–3). Vent columns 1 and 4;
free cells during a surge: column 0 (5), column 2 (5), `(3,0)`, `(3,4)` = 12 of 22. Start cell `(2,2)` (column 2,
free). Step cooldown on this board ≈ 0.27 s. Escape from column 1: 1 step; from column 4: 1 step at rows 0 / 4, 2 at
rows 1 / 3, **3 steps from `(4,2)`** (`(3,2)` is missing) — the only cell where a 1 s warning is nearly too short.

Hero HP for reference: kiem_si 200, phap_su 210, sat_thu 180, tho_san 200, giao_si 210.

## 2. Launch (existing DEV args, no code change, memory store — the real save is never touched)

```bash
C:/Users/ADMIN/AppData/Local/Microsoft/WinGet/Links/godot.exe --path . --windowed --resolution 1280x720 -- --region=hellfire --at-floor=2 --seed=27 --lang=vi --character=kiem_si
```

- `--character=` one of `kiem_si`, `phap_su`, `sat_thu`, `tho_san`, `giao_si` (verified: frame
  `human-playtest-b1/launch-seed27-sat_thu-hellfire-floor2.png` shows Sát thủ, HP 180, seed 27's map, "Nhiệt 0/4").
- Leave the audio on (vent cues are judged); add `--audio-driver Dummy` only for silent captures.
- The hero starts floor 2 fresh (full HP, 20 gold, starting deck, no relics) — identical across scenarios, weaker than
  a real floor-2 hero. Optional, identical for every scenario if used: `--hp=N`, `--gold=N`, `--deck+=id,id`,
  `--relics=id,id`.
- Reset = close the game and relaunch (nothing persists). A death on the lane = relaunch the scenario.
- The same three scenarios are also reachable on seeds 49 and 6 (`human-playtest-heat-decay/heat-scan-seeds-1-60.txt`
  PATH rows) if seed 27's lanes get stale; seed 24 (hub shop, the evidence seed) gives Heat 4 via gamble and Heat 1
  via rest.

## 3. Scenario matrix — seed 27 (map: Tinh anh / An toàn / Hiểm nguy, hub = Trại nghỉ, prepare = Forge, gamble = Tinh anh miniboss)

Paths re-verified under B1 (`seed27-paths-and-warden-probe-b1.txt`; the Heat column is the shipped rest −2):

| Scenario | Target Heat | Lane at the fork | Lane nodes (all mandatory, real fights) | Hub | Lane end | Approach | Heat at the warden |
|---|---|---|---|---|---|---|---|
| **H2** (control) | 2 | **Hiểm nguy** (peril, bottom) | Trận, Hiểm địa, Hiểm địa (+1 +1 +1 = 3) | Trại nghỉ (−2 → 1) | Trận or Hiểm địa (+1 → 2) | **Forge** (top approach node, 0) | **2** |
| **C3** | 3 | **Tinh anh** (elite, top) | Trận, Trận, Tinh anh miniboss (+1 +1 +2 = 4) | Trại nghỉ (−2 → 2) | Trận or Hiểm địa (+1 → 3) | **Forge** (0) | **3** |
| **C4** | 4 | any lane (Hiểm nguy recommended, same as H2) | as H2 | Trại nghỉ (→ 1) | (+1 → 2) | **Tinh anh miniboss** (gamble, bottom approach node, +2 → 4) | **4** |

Fights to win on the way: H2 / C4 ≈ 4 lane fights (+1 miniboss for C4); C3 = 2 battles + 1 miniboss + 1 lane end.
Read the Heat on the map banner ("Nhiệt n/4") with the warden node selected before entering; if it is not the
target, the route was not followed — relaunch. The node preview line "Nhiệt a -> b" shows what each node will do.

Why it cannot be done without routes: the dev args have no "set Heat" switch and the brief forbids editing data; the
route is the only legitimate way, and seed 27 is the only seed among 1–60 with all three targets on one map.

## 4. What "working as intended" looks like in the fight

- **First surge at 10 s** in every scenario: both vent columns (columns 1 and 4 of your half — the two columns
  nearest and farthest from the middle missing column, never the start column) show the ember streak + "SẮP PHUN" for
  1 s, then erupt (2.0 s in H2 / C3, 2.5 s in C4).
- **Next surges**: H2 at 20 s, 30 s …; C3 / C4 at 17 s, 24 s, 31 s … If only one column lights up at a surge, the
  other was already warning / erupting from the regular clock (expected, not a bug).
- **Regular single-vent eruptions** between surges, either half, roughly every 5 / 4.5 / 4 s (faster after the phase-2
  banner).
- **Intro band**: the warden shows no modifier icon (the hook is a trait parameter, not a modifier) — correct.
- **Pieces on an erupting column are burnt**; the burn tick on your HP bar reads 2 (H2) or 3 (C3 / C4).

## 5. Character coverage plan

| Priority | Character | H2 | C3 | C4 | Notes |
|---|---|---|---|---|---|
| 1 | `sat_thu` (180 HP, fastest casts, lowest sim Peril clear 65 %) | 2 runs | 2 runs | 2 runs | the character most likely to show a problem |
| 2 | `giao_si` (210 HP, heal on bursts, sim Peril clear 72 %) | 2 | 2 | 2 | |
| 3 | `kiem_si` (200 HP, strongest in the sim) | 2 | 2 | 2 | calibrates "normal" |
| 4 (if practical) | `phap_su` (210 HP, wide casts) | 1–2 | 1–2 | 1–2 | |
| 5 (if practical) | `tho_san` (200 HP, marks) | 1–2 | 1–2 | 1–2 | |

Minimum = 18 warden fights (3 characters × 3 scenarios × 2 runs); full = 30. Order per character: H2 first, then C4,
then C3; answer the "can you tell them apart" questions only after all three. A character not played is reported as
not tested (§9), never as passed.

## 6. Observation checklist (one block per fight)

Vent behaviour
1. Time of the first surge (expect ≈ 10 s).
2. Time between surges (expect 10 s in H2, 7 s in C3 / C4).
3. Number and position of vents per surge (expect 2: columns 1 and 4).
4. Warning duration as perceived; readability of the streak + "SẮP PHUN" (rating below).
5. Both columns activated as expected? (yes / no / only one — and why).
6. Did a warning overlap another danger (boss cut telegraph, pin, odd block, a burning cell of your own)? How often?

Player experience
7. Times hit by a vent (stood on an erupting cell for ≥ 1 tick).
8. HP lost to vents — **only if you can attribute it** (watch the tick numbers; otherwise write "not attributable").
9. Reasonable opportunity to dodge each time? Count the surges you could not escape.
10. Did dodging force you to abandon a cast / placement / combo you wanted? How often?
11. Were you ever trapped (no safe cell reachable in 1 s)? Describe the cell and the situation.
12. Does the vent pressure feel fair?

Overall
13. Warden difficulty; fight duration (seconds, from the intro end to the kill or death); HP at the end; died?
14. After all three scenarios: do Heat 2 / 3 / 4 feel meaningfully different? Which cue tells them apart?
15. Still enjoyable? Would you take the Peril lane again knowing this warden?
16. Character-specific problems (cast tempo, reach, heal timing, HP pool).

Ratings 1–5 (1 unacceptable / frustrating, 2 poor, 3 acceptable, 4 good, 5 excellent): **fairness, fun, warning
readability, dodgeability, overall difficulty** (for difficulty: 1 = trivial or hopeless, 3 = right, 5 = hardest
acceptable; note which end a 1 means).

Screenshots: the first surge and the end state, saved as new files under
`production/qa/evidence/world-map-v2/human-playtest-b1/<scenario>-<character>-run<n>-<what>.png`.

## 7. Decision rules (from the brief; no automatic tuning)

- **Keep B1** if fairness and fun are consistently ≥ 3 across the tested characters and no fight had an unavoidable
  vent death (item 11 = never, or only from a boss telegraph the player could have avoided).
- **Investigate** (do not change yet) if: Heat 3 and Heat 4 feel indistinguishable (item 14); Heat 4 creates excessive
  pressure, especially after the phase-2 banner (items 9–12 in C4 runs); any character repeatedly suffers unavoidable
  vent damage (items 7, 11 across its runs).
- Never reduce `vent_sec` or raise `interval_sec` on one bad run. If the evidence supports a change, the order to
  consider is (1) `vent_sec` 2.5 → 2.0, (2) `interval_sec` 7.0 → 8.0 — options for a later decision, not authorised
  here.
- The simulator criteria already met (`b1-balance-validation-2026-11-12.md`) stay in force; a tuning that follows from
  this playtest would need its own paired re-run.

## 8. Result log (fill in; empty = not played)

| Scenario | Character | Run | Heat at entry (banner) | first surge (s) | surge gap (s) | vents / surge | hits by vents | vent HP (attributable?) | unescapable surges | abandoned actions | trapped? | fight sec | HP end / died | fairness | fun | readability | dodgeability | difficulty | notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| H2 | sat_thu | 1 | | | | | | | | | | | | | | | | | |
| H2 | sat_thu | 2 | | | | | | | | | | | | | | | | | |
| C3 | sat_thu | 1 | | | | | | | | | | | | | | | | | |
| C3 | sat_thu | 2 | | | | | | | | | | | | | | | | | |
| C4 | sat_thu | 1 | | | | | | | | | | | | | | | | | |
| C4 | sat_thu | 2 | | | | | | | | | | | | | | | | | |
| H2 | giao_si | 1 | | | | | | | | | | | | | | | | | |
| H2 | giao_si | 2 | | | | | | | | | | | | | | | | | |
| C3 | giao_si | 1 | | | | | | | | | | | | | | | | | |
| C3 | giao_si | 2 | | | | | | | | | | | | | | | | | |
| C4 | giao_si | 1 | | | | | | | | | | | | | | | | | |
| C4 | giao_si | 2 | | | | | | | | | | | | | | | | | |
| H2 | kiem_si | 1 | | | | | | | | | | | | | | | | | |
| H2 | kiem_si | 2 | | | | | | | | | | | | | | | | | |
| C3 | kiem_si | 1 | | | | | | | | | | | | | | | | | |
| C3 | kiem_si | 2 | | | | | | | | | | | | | | | | | |
| C4 | kiem_si | 1 | | | | | | | | | | | | | | | | | |
| C4 | kiem_si | 2 | | | | | | | | | | | | | | | | | |
| H2 | phap_su | 1 | | | | | | | | | | | | | | | | | |
| C3 | phap_su | 1 | | | | | | | | | | | | | | | | | |
| C4 | phap_su | 1 | | | | | | | | | | | | | | | | | |
| H2 | tho_san | 1 | | | | | | | | | | | | | | | | | |
| C3 | tho_san | 1 | | | | | | | | | | | | | | | | | |
| C4 | tho_san | 1 | | | | | | | | | | | | | | | | | |

Free-form observations and unexpected behaviour:

- (none recorded yet)

Blind-difference answers (item 14), per character: Heat 2 vs 3: ______ · Heat 3 vs 4: ______ · cue: ______

## 8b. Bot playtest (added 2026-11-12, after the user asked for a bot run) — NOT human results

A scratchpad bot played **48 live warden fights** at Heat 2 / 3 / 4 (5 heroes × 2 seeds with a 0.3 s vent reaction,
plus 0.6 s and a vent-ignoring policy for sat_thu / giao_si / kiem_si): `human-playtest-b1/bot/bot-playtest-report-2026-11-12.md`.
Measured: first surge 10.0 s and gaps 10.1 / 7.0 / 7.0 s at Heat 2 / 3 / 4 on the match clock (B1 confirmed live);
0 unescapable warnings in 48 fights; a 0.3 s-reacting player took 8 vent damage in 30 fights (3 hits), a 0.6 s one 15
in 9; a player who never dodges takes ≈18 / 36 / 54 vent damage per fight at Heat 2 / 3 / 4 and died in 2 of 3 Heat-4
fights. Every dodge-policy loss had 0 vent damage (boss cuts). The bot cannot rate fun, readability or the cost of
dodging to a planned combo — §8 above remains the human log and is still empty.

## 9. Status of the scenarios

**Decision (user, 2026-11-12, after the bot run): keep B1.** The hook stays `vent_surge {interval_sec 7, first_delay_sec 10}` with `vent_sec 2.5` at Heat 4. Human ratings (fun, readability, combo cost) remain unrecorded; the log below stays open for whenever the user plays.

**Nothing has been played by a human.** (A bot run exists, §8b.) H2, C3 and C4 are NOT PLAYED by a human for every character (sat_thu, giao_si, kiem_si, phap_su,
tho_san). No rating in §8 is real; the table is empty on purpose. Scenarios that cannot currently be reproduced:
none — all three targets are reachable on seed 27 with the production data and the existing dev launch, verified
headless for this preparation (paths) and live for Heat 4 (probe). What is *not* reproducible: a warden at Heat 3 or
4 for a hero that died on the lane (relaunch), and a true-D route (not needed: same fight at the same Heat).

## 10. Limitations

- Fresh floor-2 hero (no floor-1 rewards): absolute difficulty readings are pessimistic; comparisons between the three
  scenarios are fair because the start state is identical.
- Lane fights are real: C3 requires beating the Tinh anh miniboss on the lane; a tester who cannot clear the lane
  cannot reach the warden at that Heat on this seed (seeds 49 / 6 offer the same targets on other lanes).
- Vent RNG differs per run (which column the regular clock picks, surge order), hence two runs per scenario.
- The simulator provides no comparison figure for vent damage; the playtest's attributable vent HP is the first such
  number.
- The `(4,2)` 3-step escape is arena geometry, unchanged by B1; a fairness complaint about that cell is not a hook
  finding.

## 11. Files of this preparation

- `production/qa/evidence/world-map-v2/human-playtest-b1-warden-2026-11-12.md` (this document)
- `production/qa/evidence/world-map-v2/human-playtest-b1/seed27-paths-and-warden-probe-b1.txt` — seed 27 paths with
  the Heat at warden entry and the live B1 warden probe (Heat 4)
- `production/qa/evidence/world-map-v2/human-playtest-b1/launch-seed27-sat_thu-hellfire-floor2.png` — frame 60 of the
  dev launch with `--character=sat_thu` (Sát thủ, HP 180, "Nhiệt 0/4", lanes Tinh anh / An toàn / Hiểm nguy)
- Unchanged: `assets/data/region_rules.json` (B1), `route_archetypes.json`, every other data file, `src/`, `tests/`.
- Historical, left as written: `human-playtest-heat-decay-2026-11-12.md` (a dated banner now points here).
