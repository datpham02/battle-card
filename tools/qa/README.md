# QA tools (`tools/qa/`)

## Art QA (P3 of the AI Game Art Workflow, 2026-11-11)

| File | What it is |
|---|---|
| `art_check.py` / `art_check.sh` | One command for the technical art QA: `all` · `changed` · `asset <registry id>` · `character <entity>` · `clip <entity> <clip>` · `candidate <folder>`. Runs the existing checkers (registry `check`, `export_sheets.py --check`, `fxc.py check`, `.import` flags, PNG decode, `clips.json` vs sheet, `anim_qa.py`, the `tests/unit/art` suites) and prints one row per check: PASS / WARNING / FAIL / UNKNOWN (a checker that could not run, with the reason). Pre-fxkit packs recorded in the registry as `qa.known_fxc_fail` show as WARNING "KNOWN", never PASS. `--no-godot` skips the suites, `--json <path>` writes the report. Exit 1 on FAIL. Technical PASS is not acceptance. |
| `review_package.py` | Builds `<candidate>/preview/`: `contact_x4.png`, `anim.gif`, `before_after_x4.png` (with `--current`), `REVIEW.md` (what to look at, QA summary from `--qa-json` / `adapter-report.json` / `raw/qa.json`, known issues, suggested revision, the decision to record). Ends with "Waiting for the user's decision". |

Candidate folders come from `tools/asset-pipeline/candidate.py new|qa|verdict`.

## Playtest bot

A playtest bot that plays real battles through the same `CombatView` API the touch input uses, and checks
the cast rules every frame. It is a **tool, not a test**: the test runner never runs it, and the game
never loads it. It was moved here from session scratch on 2026-11-05, after it played 72 matches with 0
rule violations.

| File | What it is |
|---|---|
| `play_bot.gd` | Plays one ch1 match as one hero. The bot moves, places random pieces on the enemy, lifts and moves them, chooses cards or lets the 4 s clock run out. It prints `VIOLATION <rule>` lines and one `RESULT` line, and saves up to 6 screenshots. |
| `run_bot_matrix.sh` | Runs `play_bot.gd` for heroes × matches and prints the RESULT, VIOLATION and SCRIPT ERROR lines. It keeps one log per match in the out dir. |

## Checked rules

These come from `design/quick-specs/niem-dung-tran-2026-11-04.md`.

- **Nothing moves while casting.** While a piece is held, in the place window and in the card menu, the enemy cell and the pattern stage stay fixed, and `try_step_player` is refused (`enemy_moved_while_casting`, `pattern_stage_changed_while_casting`, `hero_stepped_while_casting`).
- **The hero is not stuck in the cast pose.** After the card is chosen, the hero plays other clips than `cast_gesture` (`stuck_in_cast_gesture`).
- **A lifted piece keeps its cells** (`lift_changed_cells`).
- **The readout damage is never 0 while a piece is on the board** (`readout_zero_with_a_piece`).
- **The clock running out casts a card** (`timeout_did_not_cast`, `cast_clock_never_ran_out`).

## Running

Run from the repo root. The bot needs a window, because it takes screenshots, so do not pass
`--headless`. Always pass `--no-autopause`: the game pauses when the window loses focus, but the bot's
clock keeps running. Without the flag you get false `cast_clock_never_ran_out` and `timeout_did_not_cast`
reports.

```sh
GODOT=C:/Users/ADMIN/AppData/Local/Microsoft/WinGet/Links/godot.exe
# One match
$GODOT --path . --fixed-fps 60 -s res://tools/qa/play_bot.gd -- "<scratch>/bot" phap_su goblin_warlock 1 --no-autopause
# Matrix: 5 heroes x 6 Misty Forest matches, about 30-60 min, run in the background
bash tools/qa/run_bot_matrix.sh "<scratch>/bot" > "<scratch>/bot.out" 2>&1
grep -E "VIOLATION|NO RESULT|SCRIPT ERROR" "<scratch>/bot.out"
```

Arguments of `play_bot.gd` after `--` are `<out_dir> <hero> <match> <seed>`. The matrix script takes
`<out_dir> [heroes] [matches] [seed]`, with comma lists for heroes and matches.

## Limits

- **Win and loss numbers are not balance data.** The bot plays naively, with random pieces, the first available card and a 150 s cap. For balance use `tools/balance/`.
- **Long pieces may fail to place.** It rotates up to 3 times. A piece 4 cells long can still fail on the 3-row board, which shows as a `PLACE FAIL` line.
- **Only ch1 is covered.** The match ids come from `assets/data/chapters.json`.
