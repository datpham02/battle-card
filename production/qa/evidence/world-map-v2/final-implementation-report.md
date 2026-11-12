# World Map v2 — final implementation report (Hellfire vertical slice), 2026-11-12

Scope executed: the user's "Autonomous Implementation — World Map v2" brief (Phases 0–9) on top of the approved
design package (`docs/design/world-map-v2/`, decisions D1–D15). Repository left uncommitted on `main` (HEAD
`de6f88a` + the working tree below). Nothing was committed, pushed or deployed. Only Hellfire (floor 2) runs the
new map and rule; the other six regions and the final keep their v1 behaviour (D8).

## 1. Summary

The player enters Hellfire from the climb screen with a briefing (rule "Heat", shop at the crossing, warden traits),
sees a 14-node map of three labelled lanes (Safe / Treasure / Peril / Elite drawn 3 of 5), a hub, a prepare-or-gamble
approach and the warden, with a preview per node (enemy, arena, modifiers, reward tier, objective, heat before →
after). Fights are composed from the unchanged roster plus modifiers that are existing traits / hazard numbers; the
Heat gauge rises with fights, shortens the vents and lifts reward tiers; the warden gets its vent surge at heat 3+;
the Forge node teaches a block and forgets one for free; rewards pay by tier; the run saves at every step (save v8)
and resumes identically; floor 3 (desert) is v1 again in the same run. All of it is covered by headless tests, a
10 000-seed map simulation, a deterministic route simulation and retained screenshots.

## 2. Files changed and added

Modified (gameplay / tooling):
`src/run/run_session.gd` (save v8, graph mirror, rule state, forge state, luck_extra, id accessors),
`src/run/game_flow.gd` (profiles, objectives, tiers, relic rows, forge flow, previews, briefing, seed hook),
`src/run/run_config.gd` (`from_node(..., profile)`), `src/run/run_controller.gd` (`match_modifiers`),
`src/run/chapters_config.gd` (`generate_region_graph`, `region_graph_spec`), `src/run/kiep_rules.gd`
(`node_weight_mult` getter), `src/run/reward_roller.gd` (tier rules), `src/combat/combat_view.gd` (two stat
counters only), `src/run/chapter_map_view.gd`, `src/run/world_map_view.gd`, `src/run/piece_deck_view.gd` (UI),
`assets/data/rewards.json` (+`reward_tiers`, `node_rewards.forge`), `assets/i18n/strings.csv` (+38 rows),
`assets/data/schema.md` (+World Map v2 section), `tools/balance/deck_sim.gd` (`--region-pick=order`,
`--route-policy`, v2 maps, ROUTE table), `tools/balance/sim_core.gd` (two seeds), `tools/balance/README.md`.
Tests updated to the approved policy: `tests/unit/run/boss_fate_test.gd`, `economy_test.gd`, `kiep_wiring_test.gd`,
`tests/integration/run/run_flow2_test.gd`, `tests/unit/combat/boss_downed_test.gd` (stats key count 9 → 11).

Added: `src/run/map/{map_graph, map_validator, region_rules, route_archetypes, region_map_gen, encounter_composer}.gd`,
`assets/data/region_rules.json`, `assets/data/route_archetypes.json`, `tools/balance/map_sim.gd`,
`tests/unit/run/map_v2/{map_graph_round_trip, map_validator, region_rules_config, route_archetypes_config,
v1_map_wrapper, region_map_gen, encounter_composer, run_session_v2}_test.gd`,
`tests/integration/run/world_map_v2_flow_test.gd`, `tests/integration/run/world_map_v2_evidence.gd`,
`docs/design/world-map-v2/*` (design package, 10 files), this folder (`production/qa/evidence/world-map-v2/`).

Untouched: every other region's data, `chapters.json`, `economy.json` (D14), cards / relics / events / enemies, all
combat code except the two counters, `ChapterMapGen` (v1 generator kept, D rule "no removal before validation").

## 3. Architecture as implemented vs the proposal

As in `docs/design/world-map-v2/08-approval-package.md` §B with these deviations (full table in
`04-technical-architecture.md` "As implemented"):
- The MapGraph is the saved truth of a v2 region; RunSession **mirrors** it into the existing column model instead of
  replacing `column` / `node_index` (every column-addressed rule, seed and screen kept working; node ids are
  first-class accessors).
- `region_rules.json` carries `map_gen` / `depth_layout`; `chapters.json` was not touched.
- Kiep 3 acts on the `peril` archetype weight through a read-only getter; the v1 column pass is untouched.
- The Forge screen is the piece-deck screen in phase FORGE (ink row as two buttons), not a cardless reward screen.
- Objective counter `vents_dodged` replaces `vent_cells_stood`.
- `--route-policy=value` is the simple greedy oracle (risky lanes above 60 % HP), not the preview-table oracle.

## 4. Tests and exact commands

Headless single suites (every one FAILS=0 on the final code):

```
GODOT=C:/Users/ADMIN/AppData/Local/Microsoft/WinGet/Links/godot.exe
$GODOT --headless --path . -s res://tests/unit/run/map_v2/<name>_test.gd        # 8 suites: U1–U28
$GODOT --headless --path . -s res://tests/integration/run/world_map_v2_flow_test.gd   # I1 + I2 (seeds 24, 28)
```

Full suite (`tools/qa/run_all_tests.sh`, 286 suites, 240 s timeout each, windowed UI suites muted):
- first pass during Phase 9 (`full-suite-2026-11-12.txt`, 2015 s): 282 green; `boss_downed_test` (stats key count
  — updated), `i18n_test` (a `TEXT_` constant that was a key format — renamed), `terminology_scan_test` (three
  modifier names used glossary-banned English words — renamed to the glossary's trait names),
  `pattern_roster_fairness_test` (no result line: it needs 257 s alone and the runner's timeout is 240 s; FAILS=0 when
  run by itself). All four fixed / explained; the three fixed ones FAILS=0 on rerun.
- final pass on the final code: `full-suite-final-2026-11-12.txt` — **286 / 286 green** (1572 s), no timeouts.

Map simulation (`tools/balance/map_sim.gd`): `--seeds=10000 --pairs=assigned` → `map-sim-assigned-10k.txt`
(70 000 maps: hellfire v2 and six wrapped v1 maps, 100 % valid, p50 0.52 ms, p95 0.82 ms);
`--seeds=10000 --pairs=assigned --force-v2` → 70 000 / 70 000 valid, p50 0.46 ms, p95 0.79 ms;
`--seeds=1000 --pairs=all --force-v2` → 49 000 / 49 000 valid after the teach fix (an elite nobody on its path can
teach degrades to a battle; ch1's whole miniboss pool is gated). Determinism: the first 100 seeds of every pair
generated twice, byte-equal.

Route and run simulation: `route-sim-2026-11-12.md` (commands, tables, verdict).

## 5. Baseline comparison and balance

- Phase 0 baseline (deterministic, climb order, 70 seeds × 5 characters): run win 10.0–21.4 % (mean 16.0), won runs
  46.7–51.9 min — `baseline-7floor-v1.md` §8.
- Paired v2 (hellfire on `value`): run win mean 15.7 % (kiem_si 21.4 → 24.3, phap_su 20.0 → 14.3, sat_thu 15.7 →
  14.3, tho_san 12.9 → 15.7, giao_si 10.0 → 10.0), minutes unchanged, gold within ± 15 %. Run-level guard **met**.
- Lanes (bot, hellfire floor 2): Peril +18 % gold, +0.76 relics, +8.7 HP pts lost, **−16.9 pts region clear** vs
  Safe; Elite +9 % gold, +0.28 relics, −1.7 pts clear; Treasure −9.5 % drop gold (value in the chest / forge).
  Peril's net value target (+25 %) is met (+37 %); its death-rate band (≤ +10 pts) is **not** — see §8.

## 6. Save / load compatibility

- Save v8 round-trips at every exit point of a v2 region and across v1 → v2 → v1 floors (U25–U28, I1 reloads at the
  fork, before the hub and at the approach through `go_back` + `continue_requested`; E7 is the resumed frame).
- v5 / v6 / v7 saves take the `needs_restart` path with the existing notice (U26; three older tests updated to this
  approved policy). v4 unchanged.
- Invalid v8 data: unknown edge dropped; warden unreachable → run dropped; gauge clamped; unknown rule → state
  dropped; node index past the depth → run dropped; tampered `map` copy rebuilt from the graph (U27). Save size of a
  v2 run < 32 KB (asserted).
- v1 regions' arena seeds unchanged (the wrapped graph uses the region map seed; the column formula stays).

## 7. UI verification

1280 × 720, windowed, muted (`tests/integration/run/world_map_v2_evidence.gd`): `ui/E1` climb briefing (rule +
shop line, description trimmed to fit), `E2` three lanes with bands and labels, `E2b` peril start preview, `E3`
peril end with two modifiers and the objective, `E4a/E4b` heat 3 meter, `E5` warden preview at heat 4, `E6a/E6b`
forge node and forge screen (two "Learn <shape>" buttons, free forget line), `E7` resumed map identical to E5.
Touch: node hit rects unchanged (≥ MIN_TOUCH_SIDE), ink buttons ≥ MIN_TOUCH_SIDE, tap-select / tap-confirm, angular
shapes only. Not verified on a phone: the Android build was not produced in this pass.

## 8. Known bugs, limitations and unresolved risks

- **Peril is too deadly for four of five heroes (bot)**: region clear 73.6 % vs 90.5 % on Safe. The reward side is
  right; the first knobs are heat 3 `vent_tick_damage` 3 → 2, heat 4 `vent_interval_sec` 4.0 → 4.5 or the peril
  slot-3 modifier count 2 → 1 (`region_rules.json` / `route_archetypes.json` only). Not changed in this pass.
- The `mystery` lane never appears on hellfire floor 2 in the 70-seed set (weight 0.8 vs peril ×1.5 and the
  safe/treasure guarantee); untested in play beyond the generator tests (U7/U8 cover it on other floors).
- The in-battle intro band does not show the modifier icons (they are in `match_params.modifiers`; the map preview
  shows them). Display only.
- The simulator does not model inks, the Heat distribution at the warden, or the two combat-only objectives; its
  objective hit rate (25 % on peril) is a bot number.
- `pattern_roster_fairness_test` exceeds the runner's 240 s timeout under CPU load (passes alone in 257 s).
- Pre-existing noise unrelated to this work: `Parameter "obj" is null` from `src/audio/ui_audio_bridge.gd:35`
  when a test frees the main scene; the game itself leaves `CutFlow.rng` random (only the sim seeds it).
- Not done: Android device run; the other six regions' rules (D8, direction only); a converter for v5–v7 saves (D5).

## 9. Evidence files

`baseline-7floor-v1.md` (+ raw A / B / seeded / seeded-repeat per character, run log), `map-sim-assigned-10k.txt`,
`map-sim-assigned-10k-forcev2.txt`, `map-sim-all-pairs-1k-forcev2.txt`, `route-sim-2026-11-12.md` (+ 35 probe raw
files, 5 full-run raw files, `route-sim-runlog.txt`), `full-suite-2026-11-12.txt`, `full-suite-final-2026-11-12.txt`,
`ui/E1..E7` screenshots, `autonomous-progress.md` (per-phase checkpoint). Design package:
`docs/design/world-map-v2/` (README → 08 approval package; 04 "As implemented").

Final suite result (`full-suite-final-2026-11-12.txt`, 1572 s): **286 / 286 suites green**, every suite printed `FAILS=0` (including `pattern_roster_fairness_test` this time).

## 10. Recommendation

**Ready for playtest, needs tuning.** The slice is complete and verified end to end (generation, encounter
composition, Heat, rewards, forge, save/load, UI, determinism); nothing blocks a playtest build. Before widening to
other regions: (1) a playtest of the Peril lane on the low-HP heroes against the bot's −17-point region clear,
(2) one data-only tuning pass on the Heat / peril knobs above with the route simulation re-run, (3) the Android
check of the three-lane map and the forge buttons at phone size.
