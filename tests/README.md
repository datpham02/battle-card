# Tests

Headless SceneTree suites (`extends SceneTree`). Each prints PASS/FAIL lines and ends with `FAILS=N`. Not gdUnit4 (see TD-010).

## Test runner decision
SceneTree suites that print PASS/FAIL lines and end with `FAILS=N` are the project's standard test runner (TD-010). Why: the project has 95 headless and 4 windowed suites written this way, they need no addon, and no gdUnit4 addon is installed (there is no `addons/` folder), so the gdUnit4 command named in the coding standards cannot run here. CI should run the two loops under **Run** below and fail the job when any suite prints `FAILS=` with a value other than 0, prints `SCRIPT ERROR`, or prints no `FAILS` line at all; the windowed `integration/ui/` suites need a display (a virtual one such as Xvfb on Linux CI), one at a time. Moving to gdUnit4 would be a separate decision, taken when CI is set up.

## Layout
- `unit/<system>/` — pure logic (combat, traits, run, ui)
- `integration/run/` — game-flow suites (headless)
- `integration/ui/` — click-driven suites: **windowed only**, a headless run stalls
- `fixtures/` — JSON configs the suites load via `res://tests/fixtures/...`

## Run
```bash
G=C:/Users/ADMIN/AppData/Local/Microsoft/WinGet/Links/godot.exe
$G --headless --path . --import                       # after adding class_name files
$G --headless --path . -s res://tests/unit/run/map_gen_test.gd
$G --windowed --resolution 1280x720 --path . -s res://tests/integration/ui/cut_flow_test.gd -- --no-autopause
```
All suites, verdict lines only:
```bash
for f in $(find tests/unit tests/integration/run -name '*_test.gd'); do echo "$f: $($G --headless --path . -s res://$f 2>&1 | grep -oE 'FAILS[=: ]+[0-9]+' | tail -1)"; done
for f in tests/integration/ui/*_test.gd; do echo "$f: $($G --windowed --resolution 1280x720 --path . -s res://$f -- --no-autopause 2>&1 | grep -oE 'FAILS[=: ]+[0-9]+' | tail -1)"; done
```

## Known failing
None. Baseline 2026-10-25 (Story 026, runes and the floor model retired; `boss_stall_test` added for TD-022; Story 027 added `zone_test`, `boss_zones_test`, `zone_traits_test`; Story 031 added `world_map_gen_test`, `floor_scaling_test`, `progress_v5_test`, `run_session_v5_test`; Story 032 added `tests/unit/relics/*` (5 suites) and `run_session_relics_test`; Story 033 added `economy_test`, `shop_event_nodes_test`, `curse_test`, `shop_logic_test`, `event_logic_test`, `shop_event_flow_test`; Story 034 added `tests/unit/pieces/{piece_deck,piece_library_pool,field_drops_weight_source}_test`, `run_session_piece_deck_test`, `piece_deck_flow_test`, `tests/unit/combat/piece_deck_match_test`, `tests/unit/ui/piece_deck_strings_test`; Story 035 added `final_match_data_test`, `boss_fate_test`, `run_session_stats_test`, `tests/unit/combat/{final_boss_phase,boss_downed}_test`, `fate_flow_test`, `tests/unit/ui/ending_strings_test`; the 2026-10-26 tech-debt pass added `tests/unit/combat/deck_return_test` and `tests/integration/run/final_prelude_test`; Story 036 added `tests/unit/combat/{hazard,boss_brain_hazard}_test`, `tests/unit/traits/region_traits_test`, `tests/unit/run/regions_swamp_desert_test`, `tests/unit/ui/hazard_strings_test`; Story 037 added `tests/unit/run/{unlock_rules,progress_state_v7,achievements_config,unlock_content_consistency,unlock_content,character_unlock,unlock_pools,run_start_parity}_test`, `tests/unit/combat/hunter_prayer_test`, `tests/unit/ui/unlock_strings_test`, `tests/integration/run/unlock_flow_test`): 95 headless suites (`unit/**`, `integration/run/**`) and 4 windowed suites (`integration/ui/**`), all FAILS=0.

Story 026 migrations: `pace_test` asserts the current boss step cooldown (`CombatConfig.step_cooldown_for` x each chapters.json match's `boss_step_cooldown_mult`, via `RunConfig.from_node`); `run_state_test` keeps the RunState rules on a 4-match fixture (shipped runs are single-match nodes) and drops the old one-floor "monotone difficulty" check; `chapters_test` / `map_gen_test` / `i18n_test` dropped the floor-API cases (`resolved_floor`, `from_floor`, `floor_count`, `floor_name`...) and the perimeter-label checks left `grid_test`.
