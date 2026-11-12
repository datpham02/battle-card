# World Map v2 — Hellfire Warden Heat hook fix, variant B1: implementation report (2026-11-12)

User brief: "Implement Hellfire Warden Heat Hook Fix — Variant B1", from
`warden-heat-hook-investigation-2026-11-12.md` (unchanged). **Nothing committed, pushed or deployed.** Production
data is on variant C (rest −2, shop −1, peril `[0,1,1]`) with the B1 hook applied as the brief asked. **B1 is a
proposed setting for the human playtest, not balance confirmed by it.**

## 1. Files changed (this task only; every earlier uncommitted change in the tree was left as it was)

| File | Change |
|---|---|
| `assets/data/region_rules.json` | the B1 data (§2) + one sentence in `_doc` |
| `tests/unit/run/map_v2/vent_surge_arena_invariant_test.gd` | **new** regression test (§3.1) |
| `tests/unit/run/map_v2/region_rules_config_test.gd` | hook / row assertions updated (§3.2) |
| `tests/unit/run/map_v2/encounter_composer_test.gd` | U13 / U15 updated + heat 2 / 4 warden assertions (§3.2) |
| `tests/integration/run/world_map_v2_flow_test.gd` | I2 live-match assertions updated (§3.2) |
| `tests/unit/traits/region_traits_test.gd` | **new** `_test_vent_surge_first_delay` (§3.3) |
| `tests/unit/combat/hazard_test.gd` | **new** `_vent_trigger_clamp_tests` (§3.4) |
| `docs/design/world-map-v2/02-region-design.md` | Heat table row 4 + the warden-hook paragraph rewritten |
| `docs/design/world-map-v2/03-encounter-system.md` | §4: warden-hook note |
| `docs/design/world-map-v2/08-approval-package.md` | post-approval note under the balance gate |
| `assets/data/schema.md` | `rules.<id>` row: hook semantics, clamp, shipped B1 values |
| `tools/balance/README.md` | ROUTE3 "hook fired" wording |
| `production/qa/evidence/world-map-v2/autonomous-progress.md` | Phase 14 |
| `production/qa/evidence/world-map-v2/warden-hook/` | **new** evidence folder (outputs listed in §4–§6) |

Not touched: `src/` (no code change), `arenas.json`, `chapters.json`, `route_archetypes.json`, every other data file,
the save format, other regions, earlier evidence files. `git status` shows no new `src/` modification from this task;
the only data file modified is `region_rules.json`.

## 2. Data before / after (`assets/data/region_rules.json`, rule `heat`)

| Key | Before | After |
|---|---|---|
| `warden_hook.min_gauge` | 3 | 3 (unchanged) |
| `warden_hook.trait_params.vent_surge` | `{"vents": 3}` | **`{"interval_sec": 7.0, "first_delay_sec": 10.0}`** |
| `combat_effect.by_gauge."4"` | `vent_interval_sec 4.0, vent_tick_damage 3.0, boss_drop_interval_mult 0.9, traits [vent_surge {12, 2}]` | same **+ `vent_sec: 2.5`** |
| `by_gauge."3"` | `vent_interval_sec 4.5, vent_tick_damage 3.0, boss_drop_interval_mult 0.9` | unchanged |
| `by_gauge."0".."2"` | `{}`, `vent_interval_sec 6.0`, `vent_interval_sec 5.0` | unchanged |
| `gauge.per_kind` | rest −2, shop −1, battle/danger +1, miniboss +2 | unchanged |
| `vent_warn_sec` | not set anywhere (combat.json 1.0) | still not set |
| modifiers, pools, `regions.*`, `depth_layout` | — | unchanged |

Resulting warden (Chúa Quỷ Lửa, caldera) per Heat at entry, from the code paths verified by the tests:

| Heat | Surge interval | First surge | Eruption burn | Regular vent clock | Burn / tick | Warning |
|---|---|---|---|---|---|---|
| 2 | 10 s | 10 s | 2.0 s | 5.0 s | 2 | 1.0 s |
| 3 | **7 s** | 10 s | 2.0 s | 4.5 s | 3 | 1.0 s |
| 4 | **7 s** | 10 s | **2.5 s** | 4.0 s | 3 | 1.0 s |

`vents` stays 2 (the boss's own value) at every Heat — the caldera's player half has 2 vents.

## 3. Tests

### 3.1 New regression test — `vent_surge_arena_invariant_test.gd`
Every `vent_surge` entry a fight can carry must ask for ≤ the vents on the player's half of every arena that fight can
play in (`ArenaLibrary.hazards_for_match` on the arena data). Sources: each chapter match's own trait vs its own
`arena` block; each region rule's `by_gauge` row traits and `warden_hook` `vents` vs the region's arenas (the hook vs
the boss-pool matches that carry the trait); each catalogue modifier offered in a region's pool vs the region's arenas.
A match without an `arena` block (combat.json board, no vents) is printed as a NOTE and counts as a failure only when
it carries the trait itself (none does; in the shipped data every hellfire match names `forge` or `caldera`, so no
NOTE was printed). Six entries are checked in the shipped data.

**Watched failing on the old data, then passing** (`.claude/rules/test-standards.md`):

| Run | File | Result |
|---|---|---|
| before the data change (hook `vents: 3`) | `warden-hook/invariant-before-fix-vents3.txt` | **FAILS=1** — `FAIL hellfire warden hook vent_surge vents 3 <= 2 vents of inferno_lord's arena { "shape": "caldera" }`; the other 8 checks PASS |
| after B1 | `warden-hook/vent_surge_arena_invariant_test-after-fix.txt` | **FAILS=0** (9 PASS) |

### 3.2 Updated tests (old hook values → B1)
- `region_rules_config_test.gd`: hook `{}` at heat 2; `{"vent_surge": {"interval_sec": 7.0, "first_delay_sec": 10.0}}`
  at heat 3 and identical at 4; the hook never carries `vents`; heat 3 row has no `vent_sec`; heat 4 row has
  `vent_sec 2.5`, tick 3, drops ×0.9 and no `vent_warn_sec`; heat 0–2 rows unchanged (existing assertions).
- `encounter_composer_test.gd`: U13 warden profile at heat 3 and 4 carries the B1 `trait_params`, none at 2;
  `vent_sec 2.5` only at 4. U15 the built warden match at heat 3: `vent_surge {interval 7, first_delay 10, vents 2}`;
  at heat 2: the boss's own `{interval 10, vents 2}` and no `vent_sec` override (same as the base match); at heat 4:
  `vent_sec 2.5` and no `vent_warn_sec` override.
- `world_map_v2_flow_test.gd` I2 (seed 24, heat 4 warden, live `CombatView`): `vent_surge interval 7 / first delay 10 /
  vents 2`, hazards `vent_interval_sec 4.0`, `vent_tick_damage 3`, `vent_sec 2.5`, `vent_warn_sec 1.0`.

Coverage of the brief's eight checks: (1) no hook at heat 2 — rules + composer; (2) hook at 3 and 4 — rules +
composer + flow; (3) `interval_sec 7` — composer U15 + flow; (4) `first_delay_sec 10` — same; (5) `vents 2` kept —
composer U15 + flow; (6) heat 4 `vent_sec 2.5` — rules + composer + flow; (7) heat 3 without it — rules + composer;
(8) heat 2 unchanged — rules (`combat_patch(heat, 2) == {"vent_interval_sec": 5.0}`) + composer U15 heat-2 warden.

### 3.3 New — `region_traits_test._test_vent_surge_first_delay`
Real `TileHazards` with two 3-cell column vents, the regular clock parked at 1000 s, trait `vent_surge {interval 7,
first_delay 10, vents 2}`, trait and hazards ticked together at 0.1 s: no surge at 9.9 s; one surge at 10 s that
warns both vents; still one at 16.9 s; the second at 17 s (the vents idle again after 1 s warn + 2 s burn).

### 3.4 New — `hazard_test._vent_trigger_clamp_tests`
Two row vents: `trigger_vents(PLAYER, 3)` returns 2 and warns both (clamped to the half); with nothing idle it returns
0; both erupt after the warning and are idle again after `vent_sec`; with one vent already warning, asking 3 starts
the other 1; with `count 1` the vent holding the player's cell is started first. No behaviour was changed — the test
pins what the hook ran into.

Two of the new assertions needed a correction while writing them (noted for honesty, no behaviour involved): the
first-delay test must configure the regular clock *before* `set_vents` (which arms the timer), and the clamp test
needed 0.05 s of float slack on its timers.

## 4. Validation — targeted suites (all after B1; outputs in `warden-hook/`)

| Suite | Result | File |
|---|---|---|
| `vent_surge_arena_invariant_test` | FAILS=0 (9 PASS) | `vent_surge_arena_invariant_test-after-fix.txt` |
| `region_rules_config_test` | FAILS=0 | `region_rules_config_test-after-fix.txt` |
| `encounter_composer_test` | FAILS=0 (26 PASS) | `encounter_composer_test-after-fix.txt` |
| `region_traits_test` (VentSurgeTrait) | FAILS=0 (102 PASS) | `region_traits_test-after-fix.txt` |
| `hazard_test` (TileHazards) | FAILS=0 (129 PASS) | `hazard_test-after-fix.txt` |
| `regions_hellfire_sky_test` (boss's own params untouched) | FAILS=0 | `regions_hellfire_sky_test-after-fix.txt` |
| `world_map_v2_flow_test` (I1 + I2, live game, save / reload) | FAILS=0 | `world_map_v2_flow_test-after-fix.txt` |
| parse check of the six test files | ok | (stdout) |

## 5. Full suite

`GODOT=… bash tools/qa/run_all_tests.sh production/qa/evidence/world-map-v2/warden-hook/full-suite-b1-2026-11-12.txt`
— result: **287 / 287 suites green, 0 script errors** (286 of the balance pass + the new invariant test; the four
suites that print `FAILS: 0` instead of `FAILS=0` are green too). Headless unit + integration suites, windowed UI
suites with `--audio-driver Dummy`.

## 6. Deterministic probes (`deck_sim`, seeds 2002..2071, kiem_si, same flags as the balance pass)

| Probe | File | Finding |
|---|---|---|
| Peril lane probe with B1 | `warden-hook/probe-peril-kiem_si-b1.txt` | vs the variant-C determinism probe (`balance/final-probe-peril-kiem_si-determinism.txt`): map, routes, lane visits, clear % (peril 95.7, elite 100, mystery 100), gold, relics, objectives, heat at the warden and heat max are **identical**; only HP-loss figures move (peril net HP 27.2 → 24.6, fights 59.9 → 58.1; elite 23.5 → 42.0 on n = 2) — the 2.5 s burns at heat 4 and the 7 s surge change the combat RNG stream, nothing else. ROUTE3 rows now present (added by the heat-decay experiment, absent from the older C file). |
| The same probe run twice | `warden-hook/probe-peril-kiem_si-b1-repeat.txt` | **byte-identical** ROUTE / ROUTE2 / ROUTE3 / RUN rows → B1 output is deterministic. |
| 7-floor `value` run with B1 | `warden-hook/full-value-kiem_si-b1.txt` | vs `balance/C-full-value-kiem_si.txt` (same seeds): run win 25.7 → 24.3 %, hellfire clear 100.0 → **95.7 %** (3 deaths on floor 2 vs 0), won-run minutes 51.7 → 52.0, relics 12.44 → 12.03. One character, one seed set: inside the ±10-pt per-character swing documented in the balance pass, but in the "harder" direction B1 intends — see §8. No `SCRIPT ERROR`, no `unknown match`. |

Confirmed by the probes and tests together: Heat 2 warden unchanged (composer U15, rules); Heat 3 / 4 warden gets the
new hook (flow I2 live); lane fights below heat 4 unchanged (rows 0–3 untouched, composer U13 heat-3 lane patch);
heat-4 lane fights get `vent_sec 2.5` (row 4, composer U13 / U15 on `magma_slug`); other regions stay v1 with no
rule (`region_rules_config_test` loop over the six other ids); save v8 untouched (no save code or key changed; flow
test's three save / reload checkpoints green); combat core, arena geometry, enemy roster untouched (no `src/`,
`arenas.json`, `chapters.json` change).

## 7. Unexpected changes
None in behaviour. Two bookkeeping notes: the first full `value` run was lost to a shell path error and rerun (the
rerun is the file above); the C determinism probe file predates the ROUTE3 row, so the diff shows those rows as
additions.

## 8. Risks not verified by simulation
1. **The feel of 7 s / 2.5 s is unmeasured.** The bot leaves warned cells after 0.4 s and erupting cells at once, so
   neither the surge interval nor the burn length costs it HP directly; the human playtest
   (`human-playtest-heat-decay-2026-11-12.md`, scenarios H2 / C3 / C4 on seed 27) is the only check of
   "clearly increased but fair" — and its F2 note is now outdated: with B1 the hook *does* change the fight.
2. **Hellfire clear −4.3 pts for kiem_si in the one B1 full run** (3 floor-2 deaths in 70 runs vs 0 under C). With one
   character and one seed set this is noise-sized, but it is the direction B1 pushes (longer burns bury more pieces and
   block more cells at heat 4). A 5-character × 2-set re-run (~75 min, the balance-pass command set with the new data)
   would settle whether the run-level guard (±10 pts) still holds — not run here, since the brief asked for probes,
   not a balance pass.
3. **Heat-4 lane fights** also get 2.5 s eruptions (by design per `02`), on forge and caldera arenas with their own
   regular clock at 4.0 s — unmeasured for humans too.
4. **Phase 2 stacking at heat 4** (clock 2.8 s + surge 7 s + 2.5 s burns): see the investigation's §7.3; the first
   tuning knobs if the playtest finds it too dense are `vent_sec` 2.5 → 2.0 and `interval_sec` 7 → 8.

## 9. Confirmation
No `git commit`, `git push`, deploy, reset, stash, checkout or branch change was run. All work is uncommitted on
`main` next to the earlier uncommitted World Map v2 changes. Earlier evidence files were neither modified nor
removed (the investigation report is unchanged; the playtest doc was not edited in this task).
