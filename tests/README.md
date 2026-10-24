# Tests

Headless SceneTree suites (`extends SceneTree`). Each prints PASS/FAIL lines and ends with `FAILS=N`. Not gdUnit4 (see TD-010).

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

## Known failing (pre-existing, stale assertions — TD-011)
- `unit/combat/pace_test.gd` — FAILS=2 (old boss step-cooldown multipliers)
- `unit/run/run_state_test.gd` — FAILS=16 (pre-022 floor/match run model)

Baseline 2026-10-24 after the move: 35 suites, 33 pass, the 2 above fail identically to their scratchpad originals.
