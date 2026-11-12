# World Map v2 — Hellfire Warden Heat hook: investigation and proposal (2026-11-12)

User brief: "Investigate and Correct Hellfire Warden Heat Hook". **Investigation and proposal only** — no production
code, data or test was changed; `assets/data/region_rules.json` still carries the shipped hook
(`{"min_gauge": 3, "trait_params": {"vent_surge": {"vents": 3}}}`), rest −2 (variant C), shop −1. Nothing committed.

Evidence used: the live probe of `human-playtest-heat-decay-2026-11-12.md` §2.3 (seed 24, Heat 4:
`trigger_vents(PLAYER, 3) started 2`), the source files named below, and the existing tests.

## 1. Root cause

**A vent is a whole line of the half, and the caldera has two of them per half. The hook asks for three.**

1. **Arena data → vents.** `arenas.json` `caldera`: `side_cols 5, side_rows 5, missing_cells [[3,1],[3,2],[3,3]]`,
   `hazards.vents.player = [{col: 1}, {col: 4}]` (mirrored for the enemy). `ArenaLibrary._vents_side` turns each
   `{row}`/`{col}` line into **one vent** holding every real cell on that line
   (`ArenaValidator.vent_line_cells`); the validator only requires a line to have ≥ 1 real cell — there is no notion
   of "how many vents an arena should have". Result: the player's half has exactly **2 vents**, column 1
   `(1,0)…(1,4)` and column 4 `(4,0)…(4,4)`, 10 of its 22 real cells. (Side coordinates: column 0 is farthest from
   the divider, column 4 touches it; the three missing cells are column 3, rows 1–3.)
2. **The warden's own trait already fires both.** `chapters.json` `inferno_lord.traits` =
   `vent_surge {interval_sec 10, vents 2}` + `phase_shift {…, vent_interval_mult 0.7}`. `VentSurgeTrait._surge` calls
   `TileHazards.trigger_vents(PLAYER, _vents, player_cell)`, which starts **up to `count` *idle* vents** of the half
   (the one holding the player's cell first, then seeded picks) and returns how many it started. With 2 vents,
   `vents: 2` = both columns.
3. **The hook can only raise a number that is already saturated.** `EncounterComposer.compose` → for the warden at
   gauge ≥ 3, `RegionRules.warden_hook` returns `{"vent_surge": {"vents": 3.0}}`; `apply_to_raw` merges it into the
   params of the *existing* `vent_surge` entry (`KEY_TRAIT_PARAMS` branch: override params of a trait already on the
   boss; a trait that is not there is skipped). So the match the warden plays at Heat 3–4 carries
   `vent_surge {interval_sec 10, vents 3}` — verified live (§2.3 of the playtest doc) — and `trigger_vents(PLAYER, 3)`
   finds 2 idle vents and starts 2. **`vents` is clamped by the arena, silently.** No warning, no test, because
   `trigger_vents` is documented as "starts up to count" and behaves as documented.
4. **No arena in the game has a third vent.** Only `forge` (`{row 0},{row 1}`) and `caldera` (`{col 1},{col 4}`)
   define vents, 2 per half each. `vents: 3` is unreachable everywhere, not just in the caldera. The design text
   (`02-region-design.md` "at heat ≥ 3 … `vent_surge.vents` becomes 3") was written against the trait's parameter
   list, not against the arena data; `03` §4's catalogue entry `vent_surge {interval_sec 12, vents 2}` and the Heat-4
   row carry the same assumption.
5. **Related, same family:** the Heat-4 `by_gauge` row appends `traits: [vent_surge {interval 12, vents 2}]`. On the
   warden this entry is **ignored** (`apply_to_raw` appends a trait only when no entry with that id exists; the boss
   has one), so the Heat-4 row contributes nothing to the warden's surge either. It does add a surge to the *lane*
   fights at Heat 4 (imp, ember hound, … have no `vent_surge`), which is the intended "Surge on every fight" of `02`.

Why no test caught it: `region_traits_test._test_vent_surge_timing` builds a 3-row synthetic board and asks for 2;
`encounter_composer_test` U13/U15 and `region_rules_config_test` assert the *parameter* reaches the match
(`vents == 3.0`), never that the arena can honour it; `world_map_v2_flow_test` I2 asserts the same parameter on the
live match. All of them pass and all of them are true. The gap is an arena-vs-parameter invariant that nothing checks.

## 2. Current Heat 2 / 3 / 4 behaviour on the warden (caldera, as shipped)

| | Heat 2 | Heat 3 | Heat 4 |
|---|---|---|---|
| Surge (`vent_surge`, boss's own) | both columns warn 1 s → burn 2 s, every 10 s (first at 10 s) | **same** (hook `vents 3` → 2 started) | **same** (row-4 trait entry deduped; hook as at 3) |
| Regular clock: one random *idle* vent of the whole arena (4 vents, both halves) | every 5.0 s | every 4.5 s | every 4.0 s |
| Regular clock in phase 2 (boss ≤ 50 % HP, `vent_interval_mult 0.7`) | 3.5 s | 3.15 s | 2.8 s |
| Burn on an erupting cell (`vent_tick_sec 0.5`) | 2 / tick (8 per 2 s eruption if you stand in it) | **3** / tick (12) | 3 / tick (12) |
| Boss piece-drop interval | ×1.0 | ×0.9 | ×0.9 |
| Field pieces on erupting cells | buried (lost) | same | same |
| Player warning / escape | 1.0 s warning; step cooldown on this board 0.27 s (`0.45 × (2/4)^0.75`) | same | same |

Felt difference today: Heat 2 → 3 = +1 burn per tick and the boss 10 % faster, with a 0.5 s shorter clock;
Heat 3 → 4 = a 0.5 s shorter clock. Neither is "clearly increased pressure", and the thing the design names as the
warden's teeth (the surge) is identical at every Heat.

Escape geometry (why the current surge is fair): the player starts at `(2,2)` (nearest the half's centre; column 2 is
free). When both columns warn, the free cells are column 0 (5), column 2 (5) and the pocket `(3,0)`, `(3,4)` — 12 of
22. From column 1 any cell escapes in 1 step (0.27 s). From column 4 the escape is 1 step at rows 0 / 4, 2 steps at
rows 1 / 3 and **3 steps from `(4,2)`** (`(4,2)→(4,1)→(4,0)→(3,0)`, 0.8 s of the 1.0 s warning, because `(3,2)` is
missing). Column 4 row 2 is the one cell where a surge is nearly unavoidable; a player who stands there is already
making a choice (it is the cell nearest the boss on the centre row).

## 3. Option A — a third vent in the caldera

What it would be: one more `{row r}` or `{col c}` line in `arenas.json` `caldera.hazards.vents` (player and, for
symmetry, enemy). Only full lines exist; a partial line or a single cell would need validator / library code.

| Candidate line | New vent cells on the player's half | Overlap with the columns (a cell in two vents takes the higher phase — supported) | Free cells when all three burn | Escape from the start cell `(2,2)` |
|---|---|---|---|---|
| `{row 2}` (centre) | `(0,2)`, `(2,2)` (+ `(1,2)`, `(4,2)` already vents; `(3,2)` missing) | 2 cells | 10: `(0,0)(0,1)(0,3)(0,4)(2,0)(2,1)(2,3)(2,4)(3,0)(3,4)` | 1 step (to `(2,1)` / `(2,3)`) — but the start cell itself becomes a vent cell |
| `{row 0}` or `{row 4}` (edge) | `(0,0)`, `(2,0)`, `(3,0)` (or row 4) | 2 cells | 9 | 0 steps needed; the pocket `(3,0)` is lost, so escape from `(4,1)`/`(4,2)` gets longer (4 steps from `(4,2)` via row 4) |
| `{col 0}` or `{col 2}` | 5 cells | none | 7 (col 0 case: col 2 + pocket) | leaves one free column: a surge of 3 denies 15 of 22 cells |

Assessment:

- **Space / meaning**: `{row 2}` is the only line that adds a *meaningful* new shape (a cross with the columns) without
  collapsing the escape options; it still leaves 10 free cells and a 1-step escape, so three vents are **not**
  unavoidable damage. `{col 0/2}` is unfair (one free column); the edge rows kill the only escape pocket of column 4.
- **It changes more than the warden.** Vents are arena data: every Hellfire fight played in the caldera (the hellfire
  chapter's enemies split between `"shape": "caldera"` and `"shape": "forge"`, 5 and 4 entries) gets the third vent on
  its regular clock (5 idle vents per side → the clock now covers 12/22 cells of the player's half instead of 10/22,
  and the player's half is picked 3/6 of the time as before). The Heat 0–2 warden changes too: `vents 2` would then
  start **2 of 3** (the player's vent first, the other seeded), so the baseline surge becomes random instead of the
  fixed "both columns" — the control condition the sim measured is no longer the shipped one. Avoiding that needs a
  *second* caldera shape used only by the warden at Heat ≥ 3, which the hook cannot select today (it overrides trait
  params only; `arena_patch` carries a `variant` flag, not a shape) → new code.
- **It still does not separate Heat 3 from Heat 4** (one hook row; the Heat-4 row cannot touch the warden's surge, §1.5).
- **Risk of doing it "for the number 3"**: the design sentence was "vents becomes 3" because the trait has a `vents`
  parameter, not because a third line was ever drawn. The brief's own warning applies.

Verdict: feasible (row 2), fair, but it rewrites the baseline of every caldera fight and of the Heat 0–2 warden to
make one parameter true, and it leaves 3-vs-4 unsolved. Not recommended as the fix for this hook.

## 4. Option B — change what the hook (and the Heat rows) do

The hook is the right tool, pointed at the wrong parameter. `VentSurgeTrait` reads three params, all overridable by
`trait_params`: `interval_sec` (10), `vents` (2), `first_delay_sec` (= interval). The Heat rows can set any of the 19
`HAZARD_OVERRIDE_KEYS`, of which five are vent keys (`vent_interval_sec`, `vent_warn_sec`, `vent_sec`,
`vent_tick_sec`, `vent_tick_damage`) — `vent_sec` in a row is even exercised by `region_rules_config_test` ("typo
patch key dropped, valid hazard key kept": `{"vent_sec": 1.5}`).

### B1 — data only (recommended)

| Knob | Today | Proposed | What it does |
|---|---|---|---|
| `warden_hook.trait_params.vent_surge` | `{vents: 3}` | **`{interval_sec: 7.0, first_delay_sec: 10.0}`** (drop `vents`) | At Heat ≥ 3 the warden's surge (both columns) comes every **7 s** instead of 10 s. `first_delay_sec 10` keeps the first surge at 10 s, so the opening 10 s of the fight are identical at every Heat (fair: the player learns the arena before the pressure rises). |
| `by_gauge."4"` | `vent_interval_sec 4.0, vent_tick_damage 3, boss_drop_interval_mult 0.9, traits [vent_surge …]` | the same **+ `vent_sec: 2.5`** | At Heat 4 every eruption (surge and clock, both halves) burns **2.5 s** instead of 2 s. Warning unchanged (1 s), burn per tick unchanged (3). Pressure = time the columns are denied, not more damage per tick. |
| `by_gauge."3"` | `vent_interval_sec 4.5, vent_tick_damage 3, boss_drop_interval_mult 0.9` | unchanged | |
| `vent_warn_sec` | 1.0 | **unchanged at every Heat** | The warning is the fairness budget; it is never shortened. |

Resulting progression on the warden (regular clock = one idle vent of the arena's four):

| | Heat 2 | Heat 3 | Heat 4 |
|---|---|---|---|
| Surge: both columns, first at 10 s, then every | 10 s | **7 s** | **7 s** |
| Columns unusable per surge cycle (warn + burn) | 3 s / 10 s = 30 % | 3 s / 7 s = **43 %** | 3.5 s / 7 s = **50 %** |
| Regular clock (phase 1 / phase 2) | 5.0 / 3.5 s | 4.5 / 3.15 s | 4.0 / 2.8 s |
| Burn per tick / per full eruption | 2 / 8 | 3 / 12 | 3 / **15** (2.5 s = 5 ticks) |
| Boss drops | ×1.0 | ×0.9 | ×0.9 |
| Free cells during a surge / escape from `(2,2)` | 12 / 1 step | 12 / 1 step | 12 / 1 step |

Heat 2 → 3 is now felt on the mechanic the region is about (the surge comes 30 % more often, burn 3) and Heat 3 → 4
adds a longer burn on top of the faster clock — two visible steps, same warning, same escape. A player who never
stands on a vent cell takes **no** extra damage at any Heat; what rises is how often they must move and how many
field pieces the columns bury. That is the `02` thesis ("where you stand and when you cast matter more").

### B2 — same idea, with a small code change (optional, only if 3-vs-4 should be on the surge itself)

Let a `by_gauge` row carry `trait_params` so Heat 3 and Heat 4 can set *different* surge intervals (e.g. 8 s / 6 s)
without the single-threshold hook. `EncounterComposer.apply_to_raw` already handles a `trait_params` key in a patch;
only `RegionRules._clean_patch` (pass the key through, numbers as floats, like the hook does) and
`EncounterComposer._merge_patch` (merge the dictionary instead of overwriting) need ~10–15 lines, plus two unit
assertions. The hook would then be redundant for Hellfire (kept as a generic feature). Not needed for the progression
above; listed because it is the smallest code path if the user prefers the surge to carry both steps.

### A vs B

| | A (third vent) | B1 (hook interval + Heat-4 burn length) |
|---|---|---|
| Files | `arenas.json` (+ new shape and hook code if the baseline must stay) | `region_rules.json` only |
| Touches lane fights / Heat 0–2 warden | yes (every caldera fight; baseline surge becomes 2-of-3) | no |
| Separates Heat 3 from 4 | no | yes (surge 7 s at both; burn 2.5 s at 4) |
| Fairness levers | geometry (fixed once drawn) | warning untouched; interval and burn length are tunable numbers |
| Mechanics introduced | none (but a new board shape to learn) | none — the surge and the burn length already exist and are HUD-supported |
| Sim visibility | none either way (the bot never takes vent damage) | none — human playtest decides |
| Keeps the sim's C results valid | no (baseline changed) | yes (Heat ≤ 2 unchanged) |

## 5. Recommendation

**Option B1.** Replace the hook's `vents: 3` with `interval_sec: 7.0, first_delay_sec: 10.0`, and add `vent_sec: 2.5`
to the Heat-4 row. Keep everything else (clock 4.5 / 4.0, burn 3, drops ×0.9, warning 1.0 s, rest −2, shop −1,
peril `[0,1,1]`). Reasons, in order: it fixes the actual defect (a parameter the arena cannot honour) with the
parameter the hook was built to set; it gives the three-step progression the brief asks for on one well-understood
mechanic; it leaves every fight below Heat 3 and every lane fight exactly as measured; and it is data, so the
playtest can tune it (7 → 8 s, 2.5 → 3.0 s) without touching code. The numbers are **proposals to be validated by the
human playtest**, not measured values — the sim cannot see them (§7).

Also recommended, as a guard: a data test that fails when any `vent_surge.vents` (chapters, region rules, modifier
catalogue, hook) exceeds the vent count of every arena that fight can be played in (§9), so "a number the arena
cannot honour" cannot ship silently again.

## 6. Expected gameplay impact

- **Heat 2 warden**: unchanged in every respect (regression anchor for the playtest's H2 scenario).
- **Heat 3 warden**: a surge every 7 s after the first at 10 s; with the 4.5 s clock a column is warning or burning
  roughly half the time once phase 2 starts. The player relocates ~40 % more often; pieces left on columns 1 / 4 are
  lost more often. Damage only if the warning is ignored.
- **Heat 4 warden**: as Heat 3 plus eruptions that last 2.5 s and a 4.0 / 2.8 s clock; the columns are denied about
  half of each surge cycle. This is the "stronger but avoidable" tier: the escape is unchanged (12 free cells, ≤ 3
  steps), only the time away from the columns grows.
- **D's effect becomes real**: under D, 45 % of Peril and 55 % of Elite routes meet this Heat 3–4 warden instead of
  30 % / 26 %. The heat-decay decision (C vs D) should be re-read with this in mind: the sim's "no cost" for D was
  partly because the hook was a no-op, and would still be "no cost" after B1 because the bot dodges every warning.
- **Per character**: `sat_thu` (180 HP, fastest casts) and `giao_si` (210 HP, heal on bursts) are the two with the
  lowest Peril clear in the sim; they lose the most to being forced off the columns while a cast is lined up. The
  playtest's per-character rows will show whether 7 s is right for them.
- **Lane fights at Heat 4** keep the Heat-4 row's own surge (`interval 12, vents 2`, now also 2.5 s burns): a mild
  side effect of the `vent_sec` change on non-warden Heat-4 fights — acceptable (it is the "Surge on every fight at
  heat 4" the design already states) but listed, since it is the one change outside the warden.

## 7. Risks and edge cases

1. **The simulator cannot evaluate any of this.** `sim_core` leaves a warned cell after 0.4 s and an erupting cell at
   once; vent damage stays ~0 for the bot at every setting. The only tool that can price B1 is the human playtest
   (`human-playtest-heat-decay-2026-11-12.md`, whose scenarios H2 / C3 / C4 apply unchanged — C3 = D3, C4 = D4 still
   holds because the hook reads the integer Heat only).
2. **Surge vs clock collision**: `trigger_vents` only starts *idle* vents; if the clock already has a column warning
   or burning when the surge fires, the surge starts the other column only. No double-start, no extended burn; the
   pressure caps at "both columns" — by design.
3. **Phase 2 stacking at Heat 4**: clock 2.8 s over 4 vents + surge every 7 s + 2.5 s burns means columns 1 / 4 are
   rarely usable in the last half of the fight. Fair (columns 0 / 2 and the pocket stay free, warning unchanged) but
   the playtest must confirm it is still *enjoyable*; if not, the first knob to turn is `vent_sec` back to 2.0 at
   Heat 4, the second `interval_sec` 7 → 8.
4. **`(4,2)` remains the 3-step escape cell** at every Heat (existing geometry, unchanged by B1). Worth one line in the
   playtest checklist; if it reads as unfair, the geometric fix is dropping `(3,2)` from `missing_cells` (an arena
   change with its own review), not a hook change.
5. **`vent_sec` is symmetric**: the boss's half burns 2.5 s too at Heat 4; the boss brain treats warning / erupting
   vents as blocked cells (`boss_brain.gd` vent_blocked), so the boss also loses tempo. Neutral to slightly in the
   player's favour; listed so it is not a surprise.
6. **`first_delay_sec` semantics**: `setup` reads it with default = interval, `on_match_start` sets the timer to it;
   a value of 10 with interval 7 is honoured (the trait clamps only ≥ 0). Covered by a new assertion (§9).
7. **Save / load**: the hook is evaluated when the encounter is composed on entering the warden node; matches are not
   saved mid-fight; resume re-composes from the saved gauge. No save-format change.
8. **Docs drift**: `02-region-design.md` ("vents becomes 3"), `03-encounter-system.md` §4 catalogue note,
   `08-approval-package.md`, `assets/data/schema.md` hook row and `heat-decay-experiment-2026-11-12.md` ("hook fires"
   = gauge ≥ 3, semantics unchanged but the *effect* is now real) must say the same thing as the data.
9. **Objective `vent_dancer`** (survive ≥ 2 eruptions on the enemy half) is unaffected: it counts eruptions, not
   their length; lane fights only.

## 8. Proposed implementation scope (on approval only)

Data (1 file): `assets/data/region_rules.json` — `rules.heat.warden_hook.trait_params.vent_surge` →
`{"interval_sec": 7.0, "first_delay_sec": 10.0}`; `rules.heat.combat_effect.by_gauge."4"` += `"vent_sec": 2.5`.
`_doc` note. Nothing else in the file (gauge, rows 1–3, modifiers, pools untouched).

Code: **none** for B1. (B2, if wanted: `region_rules.gd _clean_patch` + `encounter_composer.gd _merge_patch`,
~15 lines.)

Tests to update (they assert the old parameter): `tests/unit/run/map_v2/region_rules_config_test.gd` ("warden hook
from heat 3" → the new params; "heat 4" row → `vent_sec 2.5`), `tests/unit/run/map_v2/encounter_composer_test.gd`
U13 / U15 (hook overrides `interval_sec` / `first_delay_sec` and keeps `vents 2`), `tests/integration/run/world_map_v2_flow_test.gd`
I2 (live match: `vent_surge.interval_sec == 7`, `first_delay_sec == 10`, hazards `vent_sec == 2.5` at Heat 4).
`tests/unit/run/regions_hellfire_sky_test.gd` (boss's own `interval 10, vents 2`) stays green.

Docs: `02-region-design.md` warden-hook paragraph, `03-encounter-system.md` §4, `08-approval-package.md` D-item on
the hook, `assets/data/schema.md`, `tools/balance/README.md` (ROUTE3 "hook fired" wording), a line in
`autonomous-progress.md`. Evidence: a new `ui/` or `human-playtest-heat-decay/` frame of a Heat-4 warden with both
columns erupting is **not** producible headlessly in a meaningful way (timing); the playtest supplies it.

Sim: `deck_sim`'s ROUTE3 "hook fired %" keeps its meaning (gauge ≥ 3 at entry). No re-run needed for the decision; a
re-run would show identical numbers (the bot dodges).

## 9. Tests needed after implementation

1. **Arena-vs-parameter invariant (new, data test)**: for every fight that carries a `vent_surge` entry (chapters,
   region-rule rows, the modifier catalogue, the hook's override), `vents` ≤ the number of vents on the player's half
   of every arena that fight can use (`ArenaLibrary` shapes it names; if a pool, every member). Today this would fail
   on the shipped hook (`3 > 2`) — the regression test for this defect, to be watched failing on the current data
   before the fix, per `.claude/rules/test-standards.md`.
2. **`TileHazards.trigger_vents` clamps** (new, `hazard_test._vent_tests`): with 2 idle vents, `trigger_vents(side, 3)`
   returns 2 and starts both; with one already warning, returns 1. Documents the behaviour the hook ran into.
3. **`VentSurgeTrait.first_delay_sec`** (new, `region_traits_test`): interval 7, first_delay 10 → no surge at 9.9 s, one
   at 10 s, the next at 17 s.
4. **Region rules** (update): hook returns `{"vent_surge": {"interval_sec": 7.0, "first_delay_sec": 10.0}}` at gauge
   3 and 4, `{}` at 2; Heat-4 row contains `vent_sec 2.5`; Heat-3 row does not.
5. **Composer** (update U13 / U15): the warden match at Heat 3 keeps `vents 2` and gets `interval_sec 7`,
   `first_delay_sec 10`; at Heat 4 also `vent_sec 2.5` in the hazard overrides; at Heat 2 the boss's own params.
6. **Flow I2** (update): the live `CombatView.match_params` and `TileHazards.config_value("vent_sec")` on the seed-24
   Heat-4 warden.
7. **Determinism**: the existing `final-probe-peril-kiem_si-determinism` style run (two identical sim invocations)
   after the data change — the bot's behaviour must not change (it does not read the surge interval).
8. **Full suite** (286 expected, the 4 updated files green) and the human playtest's H2 / C3 / C4 rows as the
   acceptance evidence for the *feel* (the only evidence that can validate 7 s / 2.5 s).

## 10. Files

- This report: `production/qa/evidence/world-map-v2/warden-heat-hook-investigation-2026-11-12.md`
- Probe evidence: `human-playtest-heat-decay-2026-11-12.md` §2.3, `human-playtest-heat-decay/heat_scan.gd.txt`
- Production untouched: `assets/data/region_rules.json`, `assets/data/arenas.json`, `assets/data/chapters.json`,
  `src/`, `tests/`.
