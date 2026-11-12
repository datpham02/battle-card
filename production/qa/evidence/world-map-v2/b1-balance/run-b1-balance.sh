#!/usr/bin/env bash
# B1 full balance validation (2026-11-12): 5 characters x 2 seed sets, 7-floor runs on route-policy=value with the
# shipped data (B1 hook + heat-4 vent_sec 2.5, variant C otherwise). Same flags as balance/C-full-value-*.txt
# (set 2001) and balance/rep-C-full-value-*.txt (set 3001). 8 at a time.
set -u
cd "$(dirname "$0")/../../../../.." || exit 1
GODOT=${GODOT:-C:/Users/ADMIN/AppData/Local/Microsoft/WinGet/Links/godot.exe}
OUT=production/qa/evidence/world-map-v2/b1-balance
BASE="--run=v6 --region-pick=order --seeds=70 --policies=build --shop-policy=greedy --event-policy=risky --relic-policy=pick --tables=v6 --final=on --route-policy=value"
LOG=$OUT/run-b1-balance.log
: > $OUT/jobs.txt
for set in 2001 3001; do
  for c in kiem_si phap_su sat_thu tho_san giao_si; do
    echo "B1-s$set-full-value-$c|--seed-offset=$set --characters=$c" >> $OUT/jobs.txt
  done
done
echo "START $(date) jobs=$(wc -l < $OUT/jobs.txt) region_rules=$(python -I -c "import json;h=json.load(open('assets/data/region_rules.json',encoding='utf-8'))['rules']['heat'];print(h['warden_hook']['trait_params'],h['combat_effect']['by_gauge']['4'].get('vent_sec'),h['gauge']['per_kind']['rest'],h['gauge']['per_kind']['shop'])")" >> $LOG
export GODOT OUT BASE LOG
run_one() { local name=${1%%|*}; local extra=${1#*|}; local t0=$(date +%s)
  "$GODOT" --headless --path . -s res://tools/balance/deck_sim.gd -- $BASE $extra > "$OUT/$name.txt" 2>&1
  echo "$name exit=$? seconds=$(( $(date +%s) - t0 ))" >> "$LOG"; }
export -f run_one
xargs -P 8 -I{} bash -c 'run_one "$@"' _ {} < $OUT/jobs.txt
echo "B1 BALANCE DONE $(date)" >> $LOG
