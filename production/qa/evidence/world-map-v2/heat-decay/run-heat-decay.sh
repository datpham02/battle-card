#!/usr/bin/env bash
# Heat decay experiment D (2026-11-12): C (assets/data, peril [0,1,1], rest -2) vs D (variants/region_rules_D.json, rest -1).
# Two seed sets (2002..2071 and 3002..3071), same bot / flags as balance-validation-2026-11-12.md. 8 at a time.
set -u
cd "$(dirname "$0")/../../../../.." || exit 1
GODOT=${GODOT:-C:/Users/ADMIN/AppData/Local/Microsoft/WinGet/Links/godot.exe}
OUT=production/qa/evidence/world-map-v2/heat-decay
VAR=res://production/qa/evidence/world-map-v2/variants
BASE="--run=v6 --region-pick=order --seeds=70 --policies=build --shop-policy=greedy --event-policy=risky --relic-policy=pick --tables=v6"
LOG=$OUT/run-heat-decay.log
: > $OUT/jobs.txt
for set in 2001 3001; do
  for c in kiem_si phap_su sat_thu tho_san giao_si; do
    for pol in peril safe treasure elite mystery; do
      echo "C-s$set-probe-$pol-$c|--seed-offset=$set --characters=$c --floors=2..2 --final=off --route-policy=$pol" >> $OUT/jobs.txt
      echo "D-s$set-probe-$pol-$c|--seed-offset=$set --characters=$c --floors=2..2 --final=off --route-policy=$pol --region-rules=$VAR/region_rules_D.json" >> $OUT/jobs.txt
    done
  done
done
for set in 2001 3001; do
  for c in kiem_si phap_su sat_thu tho_san giao_si; do
    echo "D-s$set-full-value-$c|--seed-offset=$set --characters=$c --final=on --route-policy=value --region-rules=$VAR/region_rules_D.json" >> $OUT/jobs.txt
  done
done
echo "START $(date) jobs=$(wc -l < $OUT/jobs.txt)" >> $LOG
export GODOT OUT BASE LOG
run_one() { local name=${1%%|*}; local extra=${1#*|}; local t0=$(date +%s)
  "$GODOT" --headless --path . -s res://tools/balance/deck_sim.gd -- $BASE $extra > "$OUT/$name.txt" 2>&1
  echo "$name exit=$? seconds=$(( $(date +%s) - t0 ))" >> "$LOG"; }
export -f run_one
xargs -P 8 -I{} bash -c 'run_one "$@"' _ {} < $OUT/jobs.txt
echo "HEAT DECAY DONE $(date)" >> $LOG
