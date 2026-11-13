#!/bin/bash
# Runs every suite one Godot process at a time: headless for tests/unit + tests/integration (not ui), windowed for ui.
# 2026-11-13: headless suites get 600 s (pattern_roster_fairness_test needs ~270 s on a busy machine, above the old 240 s);
# a suite cut by the timeout is marked TIMEOUT on its line instead of an empty FAILS column (a timeout is never a pass).
G=${GODOT:-godot}
OUT="$1"; : > "$OUT"
cd "$(dirname "$0")/../.." || exit 1
for t in $(find tests/unit tests/integration -name "*_test.gd" | grep -v "tests/integration/ui/" | sort); do
  r=$(timeout 600 "$G" --headless -s res://$t 2>&1); code=$?; to=""; [ $code -eq 124 ] && to=" TIMEOUT"
  echo "$t: $(echo "$r" | grep -oE 'FAILS[=:] ?[0-9]+' | tail -1) $(echo "$r" | grep -c 'SCRIPT ERROR') se$to" >> "$OUT"
done
for t in $(find tests/integration/ui -name "*_test.gd" | sort); do
  r=$(timeout 240 "$G" --path . --windowed --resolution 1280x720 --audio-driver Dummy -s res://$t -- --no-autopause 2>&1); code=$?; to=""; [ $code -eq 124 ] && to=" TIMEOUT"
  echo "$t: $(echo "$r" | grep -oE 'FAILS[=:] ?[0-9]+' | tail -1) $(echo "$r" | grep -c 'SCRIPT ERROR') se$to" >> "$OUT"
done
echo DONE >> "$OUT"
