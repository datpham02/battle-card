#!/usr/bin/env bash
# Replicate seed set (3002..3071) for the paired full runs: v1 (hellfire v1 via variants/region_rules_v1.json), cur, C.
set -u
cd "$(dirname "$0")/../../../../.." || exit 1
GODOT=${GODOT:-C:/Users/ADMIN/AppData/Local/Microsoft/WinGet/Links/godot.exe}
OUT=production/qa/evidence/world-map-v2/balance
VAR=res://production/qa/evidence/world-map-v2/variants
COMMON="--run=v6 --region-pick=order --seeds=70 --seed-offset=3001 --policies=build --shop-policy=greedy --event-policy=risky --relic-policy=pick --tables=v6 --final=on --route-policy=value"
LOG=$OUT/run-replicate.log
: > $OUT/jobs-rep.txt
for c in kiem_si phap_su sat_thu tho_san giao_si; do
  echo "rep-v1-full-value-$c|--characters=$c --region-rules=$VAR/region_rules_v1.json" >> $OUT/jobs-rep.txt
  echo "rep-cur-full-value-$c|--characters=$c" >> $OUT/jobs-rep.txt
  echo "rep-C-full-value-$c|--characters=$c --route-archetypes=$VAR/route_archetypes_C.json" >> $OUT/jobs-rep.txt
done
echo "START $(date)" >> $LOG
export GODOT OUT COMMON LOG
run_one() { local name=${1%%|*}; local extra=${1#*|}; local t0=$(date +%s)
  "$GODOT" --headless --path . -s res://tools/balance/deck_sim.gd -- $COMMON $extra > "$OUT/$name.txt" 2>&1
  echo "$name exit=$? seconds=$(( $(date +%s) - t0 ))" >> "$LOG"; }
export -f run_one
xargs -P 8 -I{} bash -c 'run_one "$@"' _ {} < $OUT/jobs-rep.txt
echo "REPLICATE DONE $(date)" >> $LOG
