#!/usr/bin/env bash
# Hellfire damage tuning (2026-11-13): (1) the Hellfire suites on the tuned data, (2) a calibration sim (kiem_si + sat_thu,
# set 2001, B1 flags; skipped with a 2nd arg `tests-only`) to read HP lost in fights per route before the full group-E rerun. One Godot at a time.
set -u
cd "$(dirname "$0")/../../../../.." || exit 1
G=${GODOT:-C:/Users/ADMIN/AppData/Local/Microsoft/WinGet/Links/godot.exe}
OUT=production/qa/evidence/monster-skill-hellfire/tuning
TAG=${1:-x3}
LOG=$OUT/tests-$TAG.txt; : > "$LOG"
fail=0
for t in tests/unit/combat/pattern_hellfire_group_a_test.gd tests/unit/combat/pattern_hellfire_group_b_test.gd \
         tests/unit/combat/pattern_hellfire_group_c_test.gd tests/unit/combat/pattern_hellfire_group_d_test.gd \
         tests/unit/combat/pattern_hellfire_fairness_test.gd tests/integration/run/pattern_hellfire_dodge_test.gd \
         tests/unit/combat/enemy_skills_config_test.gd; do
  r=$(timeout 600 "$G" --headless --path . -s res://$t 2>&1); code=$?
  f=$(echo "$r" | grep -oE 'FAILS[=:] ?[0-9]+' | tail -1); se=$(echo "$r" | grep -c 'SCRIPT ERROR')
  echo "$t: $f ${se}se exit=$code" >> "$LOG"
  echo "$r" | grep -E "^FAIL" >> "$LOG"
  [ "$f" = "FAILS=0" ] && [ "$se" = "0" ] || fail=1
done
echo "TESTS DONE fail=$fail" >> "$LOG"
[ $fail -eq 0 ] || exit 1
[ "${2:-}" = "tests-only" ] && exit 0
BASE="--run=v6 --region-pick=order --seeds=70 --policies=build --shop-policy=greedy --event-policy=risky --relic-policy=pick --tables=v6 --final=on --route-policy=value"
for c in kiem_si sat_thu; do
  "$G" --headless --path . -s res://tools/balance/deck_sim.gd -- $BASE --seed-offset=2001 --characters=$c > "$OUT/cal-$TAG-s2001-$c.txt" 2>&1
  echo "cal-$TAG-s2001-$c exit=$?" >> "$LOG"
done
echo "CAL DONE" >> "$LOG"
