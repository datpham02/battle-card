#!/usr/bin/env bash
# World Map v2 balance validation (2026-11-12): every experiment of balance-validation-2026-11-12.md, 8 at a time.
# Same seeds / flags as route-sim-2026-11-12.md (seeds 2002..2071, build / greedy / risky / pick, tables v6).
# Variants: cur = assets/data as checked in; A / B = ../variants/region_rules_{A,B}.json; C = ../variants/route_archetypes_C.json.
# Output: balance/<variant>-<probe|full>-<policy>-<char>.txt, log balance/run-experiments.log.
set -u
cd "$(dirname "$0")/../../../../.." || exit 1
GODOT=${GODOT:-C:/Users/ADMIN/AppData/Local/Microsoft/WinGet/Links/godot.exe}
OUT=production/qa/evidence/world-map-v2/balance
VAR=res://production/qa/evidence/world-map-v2/variants
COMMON="--run=v6 --region-pick=order --seeds=70 --seed-offset=2001 --policies=build --shop-policy=greedy --event-policy=risky --relic-policy=pick --tables=v6"
CHARS="kiem_si phap_su sat_thu tho_san giao_si"
LOG=$OUT/run-experiments.log
: > $OUT/jobs.txt
job() { # name extra-flags
  echo "$1|$2" >> $OUT/jobs.txt
}
for c in $CHARS; do
  for pol in safe treasure peril elite mystery value; do
    job "cur-probe-$pol-$c" "--characters=$c --floors=2..2 --final=off --route-policy=$pol"
  done
done
for c in $CHARS; do
  for pol in peril safe; do
    job "A-probe-$pol-$c" "--characters=$c --floors=2..2 --final=off --route-policy=$pol --region-rules=$VAR/region_rules_A.json"
    job "B-probe-$pol-$c" "--characters=$c --floors=2..2 --final=off --route-policy=$pol --region-rules=$VAR/region_rules_B.json"
  done
  job "C-probe-peril-$c" "--characters=$c --floors=2..2 --final=off --route-policy=peril --route-archetypes=$VAR/route_archetypes_C.json"
done
for c in $CHARS; do
  for pol in peril treasure safe; do
    job "curpieces-probe-$pol-$c" "--characters=$c --floors=2..2 --final=off --route-policy=$pol --pieces=on"
  done
done
for c in $CHARS; do
  job "cur-full-value-$c" "--characters=$c --final=on --route-policy=value"
  job "A-full-value-$c" "--characters=$c --final=on --route-policy=value --region-rules=$VAR/region_rules_A.json"
  job "B-full-value-$c" "--characters=$c --final=on --route-policy=value --region-rules=$VAR/region_rules_B.json"
  job "C-full-value-$c" "--characters=$c --final=on --route-policy=value --route-archetypes=$VAR/route_archetypes_C.json"
done
echo "START $(date) jobs=$(wc -l < $OUT/jobs.txt)" >> $LOG
export GODOT OUT COMMON LOG
run_one() {
  local name=${1%%|*}; local extra=${1#*|}
  local t0=$(date +%s)
  "$GODOT" --headless --path . -s res://tools/balance/deck_sim.gd -- $COMMON $extra > "$OUT/$name.txt" 2>&1
  local rc=$?
  echo "$name exit=$rc seconds=$(( $(date +%s) - t0 ))" >> "$LOG"
}
export -f run_one
xargs -P 8 -I{} bash -c 'run_one "$@"' _ {} < $OUT/jobs.txt
echo "ALL EXPERIMENTS DONE $(date)" >> $LOG
