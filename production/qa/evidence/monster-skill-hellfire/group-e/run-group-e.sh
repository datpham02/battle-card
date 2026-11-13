#!/usr/bin/env bash
# Monster Skill Phase 1 group E (2026-11-13): the same 7-floor balance run as B1 (production/qa/evidence/world-map-v2/
# b1-balance/run-b1-balance.sh: 5 characters x 2 seed sets x 70 seeds, route-policy=value), with the whole of Hellfire on
# the pattern brain. ONE job at a time (user rule: never two Godot processes on the project); waits while any other
# Godot runs. Compare each E-<set>-<character>.txt with b1-balance/B1-s<set>-full-value-<character>.txt.
set -u
cd "$(dirname "$0")/../../../../.." || exit 1
GODOT=${GODOT:-C:/Users/ADMIN/AppData/Local/Microsoft/WinGet/Links/godot.exe}
OUT=production/qa/evidence/monster-skill-hellfire/group-e
BASE="--run=v6 --region-pick=order --seeds=70 --policies=build --shop-policy=greedy --event-policy=risky --relic-policy=pick --tables=v6 --final=on --route-policy=value"
LOG=$OUT/run-group-e.log
wait_free() { for i in $(seq 1 720); do tasklist | grep -qi godot || return 0; sleep 5; done; }
echo "START $(date)" >> "$LOG"
for set in 2001 3001; do
  for c in kiem_si phap_su sat_thu tho_san giao_si; do
    wait_free
    t0=$(date +%s)
    "$GODOT" --headless --path . -s res://tools/balance/deck_sim.gd -- $BASE --seed-offset=$set --characters=$c > "$OUT/E-s$set-$c.txt" 2>&1
    echo "E-s$set-$c exit=$? seconds=$(( $(date +%s) - t0 ))" >> "$LOG"
  done
done
echo "GROUP E DONE $(date)" >> "$LOG"
