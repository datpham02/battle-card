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

suites=0; fail_total=0; se_total=0; to_total=0; nores_total=0

# 2026-11-14 (5): TREE STABILITY. A full run takes ~25 minutes across a checkout many sessions share. An edit
# landing mid-run splits the run across two versions of the code and still prints a tidy number - and on the
# first run through the fixed gates above, exactly that happened. It was caught only because the session that
# did it said so. A gate that relies on someone owning up is not a gate.
# Allowlist of source-like extensions, never a denylist: --import regenerates .import/.uid sidecars for assets
# other sessions added before the run, and the denylist version of this cried wolf the first time it ran. A
# denylist has to be complete; an allowlist only has to be small.
tree_moved=0
TREE_BEFORE=$(mktemp); TREE_AFTER=$(mktemp)
tree_manifest() {
  git status --porcelain 2>/dev/null | awk '{print $NF}' | grep -E '\.(gd|json|csv|tres|tscn|cfg|sh)$' | sort \
    | while read -r f; do [ -f "$f" ] && printf '%s  %s\n' "$(git hash-object "$f")" "$f"; done
}
# Taken AFTER the import above: the sidecars the import itself writes belong in the baseline, not the diff.
# It sits here and not up beside the import because the function and $TREE_BEFORE are declared above it.
# Called earlier it wrote to an empty filename, left no baseline, and the diff then reported a change on
# EVERY run - a guard that always fires is worse than no guard, because it teaches people to ignore it.
tree_manifest > "$TREE_BEFORE"

record() {  # record <suite path> <godot output> <exit code>
  local t="$1" r="$2" code="$3" to="" f n se
  if [ "$code" -eq 124 ]; then to=" TIMEOUT"; to_total=$((to_total + 1)); fi
  f=$(echo "$r" | grep -oE 'FAILS[=:] ?[0-9]+' | tail -1)
  n=$(echo "$f" | grep -oE '[0-9]+' | tail -1)
  [ -n "$n" ] && fail_total=$((fail_total + n))
  # 2026-11-14 (3): NO FAILS LINE IS ITS OWN OUTCOME. A suite that dies before printing leaves this column empty,
  # and an empty column reads as clean - worse, `n` is empty too, so fail_total is not incremented and the run
  # stays green by arithmetic. Seen in the wild: a suite whose path did not exist exited 0 and reported nothing.
  if [ -z "$f" ] && [ "$code" -ne 124 ]; then
    f="*** NO RESULT ***"; nores_total=$((nores_total + 1))
  fi
  # 'Parse Error' as well as 'SCRIPT ERROR': a suite that fails to COMPILE prints the former and not the latter,
  # so without this it combines with the line above into "empty verdict, zero errors, clean" - a suite that
  # cannot be compiled reading as a suite that passed, in the project's own canonical run.
  se=$(echo "$r" | grep -cE 'SCRIPT ERROR|Parse Error')
  suites=$((suites + 1))
  if [ "$se" -gt 0 ]; then
    se_total=$((se_total + se))
    echo "$t: $f  *** SCRIPT ERRORS=$se ***$to" >> "$OUT"
  else
    echo "$t: $f 0 se$to" >> "$OUT"
  fi
}

# `find` generates these, so a mistyped path cannot happen here - but the guard costs nothing and the same
# record() is what a hand-written list would use.
for t in $(find tests/unit tests/integration -name "*_test.gd" | grep -v "tests/integration/ui/" | sort); do
  r=$(timeout 600 "$G" --headless -s res://$t 2>&1); record "$t" "$r" "$?"
done
for t in $(find tests/integration/ui -name "*_test.gd" | sort); do
  r=$(timeout 240 "$G" --path . --windowed --resolution 1280x720 --audio-driver Dummy -s res://$t -- --no-autopause 2>&1); record "$t" "$r" "$?"
done
tree_manifest > "$TREE_AFTER"
# Before AND after, diffed. One manifest at either end cannot tell a stable tree from a lucky one.
if ! diff -q "$TREE_BEFORE" "$TREE_AFTER" >/dev/null 2>&1; then
  tree_moved=1
  echo "*** TREE CHANGED MID-RUN - these results are not trustworthy ***" >> "$OUT"
  echo "  Files that moved while the suites were running:" >> "$OUT"
  diff "$TREE_BEFORE" "$TREE_AFTER" | grep -E '^[<>]' | head -20 >> "$OUT"
  echo "  A suite is a separate process reading its files at launch, so suites that ran BEFORE an edit are" >> "$OUT"
  echo "  unaffected and ones that ran after saw different code. Re-run on a quiet tree before believing it." >> "$OUT"
fi
rm -f "$TREE_BEFORE" "$TREE_AFTER"
echo DONE >> "$OUT"
echo "SUMMARY: suites=$suites failures=$fail_total script_errors=$se_total timeouts=$to_total no_result=$nores_total tree_moved=$tree_moved" >> "$OUT"
# 2026-11-14 (4): GREEN MUST BE ASSERTED, NEVER INFERRED. Until now only script_errors gated: failures and
# timeouts were counted, printed, and used for nothing, so a run with seven real failures printed "RESULT: ok"
# and exited 0 (seen in a real main-verify log). The header above has said "a timeout is never a pass" since
# yesterday - true as a sentence, false as code, and invisible because the comment reads like a guarantee.
if [ "$se_total" -gt 0 ] || [ "$fail_total" -gt 0 ] || [ "$to_total" -gt 0 ] || [ "$nores_total" -gt 0 ] || [ "$tree_moved" -gt 0 ]; then
  echo "RESULT: FAILED - failures=$fail_total script_errors=$se_total timeouts=$to_total no_result=$nores_total tree_moved=$tree_moved" >> "$OUT"
  echo "  no_result = a suite printed no FAILS line: it may have died before printing. Never counted as a pass." >> "$OUT"
  [ "$tree_moved" -gt 0 ] && echo "  tree_moved = source changed mid-run: the verdict above describes no single version of the code." >> "$OUT"
  exit 1
fi
echo "RESULT: ok" >> "$OUT"
