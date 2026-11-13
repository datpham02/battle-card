#!/bin/bash
# Runs every suite one Godot process at a time: headless for tests/unit + tests/integration (not ui), windowed for ui.
# 2026-11-13: headless suites get 600 s (pattern_roster_fairness_test needs ~270 s on a busy machine, above the old 240 s);
# a suite cut by the timeout is marked TIMEOUT on its line instead of an empty FAILS column (a timeout is never a pass).
# 2026-11-14: two changes, both about FALSE GREENS.
#   (1) The class cache is rebuilt once before the first suite. A class_name another session just added is invisible
#       until then, and every suite that loads a scene dies on it WHILE STILL PRINTING FAILS=0. Without this the run
#       inherits whatever cache state the machine happens to be in.
#   (2) A suite with script errors no longer reports "FAILS=0 0 se", which puts a pass and a failure signal side by
#       side at the same weight. It is marked, counted, and the whole run exits non-zero.
# Baseline when the gate went in: a full run reported 0 script errors on all 311 suites, so no suite in the tree
# provokes them on purpose and the gate needs no allowlist. That number is not re-derivable once the gate exists.
G=${GODOT:-godot}
OUT="$1"; : > "$OUT"
cd "$(dirname "$0")/../.." || exit 1

"$G" --headless --import --path . >/dev/null 2>&1
echo "import: exit=$?" >> "$OUT"

suites=0; fail_total=0; se_total=0; to_total=0

record() {  # record <suite path> <godot output> <exit code>
  local t="$1" r="$2" code="$3" to="" f n se
  if [ "$code" -eq 124 ]; then to=" TIMEOUT"; to_total=$((to_total + 1)); fi
  f=$(echo "$r" | grep -oE 'FAILS[=:] ?[0-9]+' | tail -1)
  n=$(echo "$f" | grep -oE '[0-9]+' | tail -1)
  [ -n "$n" ] && fail_total=$((fail_total + n))
  se=$(echo "$r" | grep -c 'SCRIPT ERROR')
  suites=$((suites + 1))
  if [ "$se" -gt 0 ]; then
    se_total=$((se_total + se))
    echo "$t: $f  *** SCRIPT ERRORS=$se ***$to" >> "$OUT"
  else
    echo "$t: $f 0 se$to" >> "$OUT"
  fi
}

for t in $(find tests/unit tests/integration -name "*_test.gd" | grep -v "tests/integration/ui/" | sort); do
  r=$(timeout 600 "$G" --headless -s res://$t 2>&1); record "$t" "$r" "$?"
done
for t in $(find tests/integration/ui -name "*_test.gd" | sort); do
  r=$(timeout 240 "$G" --path . --windowed --resolution 1280x720 --audio-driver Dummy -s res://$t -- --no-autopause 2>&1); record "$t" "$r" "$?"
done
echo DONE >> "$OUT"
echo "SUMMARY: suites=$suites failures=$fail_total script_errors=$se_total timeouts=$to_total" >> "$OUT"
if [ "$se_total" -gt 0 ]; then
  echo "RESULT: FAILED - $se_total script error(s). A suite that dies while loading still prints FAILS=0, so this is never a pass." >> "$OUT"
  exit 1
fi
echo "RESULT: ok" >> "$OUT"
