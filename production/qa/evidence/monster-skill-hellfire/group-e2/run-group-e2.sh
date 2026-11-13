#!/usr/bin/env bash
# Group E2 (2026-11-13, Hellfire damage retuned): same as run-group-e.sh: same jobs and flags; skips a job whose output already ends with its "runtime:" line;
# before each job waits while group-e2/HOLD exists (Godot slot lent to another session) and while any Godot runs.
set -u
cd "$(dirname "$0")/../../../../.." || exit 1
GODOT=${GODOT:-C:/Users/ADMIN/AppData/Local/Microsoft/WinGet/Links/godot.exe}
OUT=production/qa/evidence/monster-skill-hellfire/group-e2
BASE="--run=v6 --region-pick=order --seeds=70 --policies=build --shop-policy=greedy --event-policy=risky --relic-policy=pick --tables=v6 --final=on --route-policy=value"
LOG=$OUT/run-group-e2.log
wait_free() { for i in $(seq 1 1440); do [ -e "$OUT/HOLD" ] || { tasklist | grep -qi godot || return 0; }; sleep 5; done; }
echo "RESUME $(date)" >> "$LOG"
for set in 2001 3001; do
  for c in kiem_si phap_su sat_thu tho_san giao_si; do
    f="$OUT/E2-s$set-$c.txt"
    grep -q "^runtime:" "$f" 2>/dev/null && continue
    wait_free
    t0=$(date +%s)
    "$GODOT" --headless --path . -s res://tools/balance/deck_sim.gd -- $BASE --seed-offset=$set --characters=$c > "$f" 2>&1
    echo "E2-s$set-$c exit=$? seconds=$(( $(date +%s) - t0 ))" >> "$LOG"
  done
done
echo "GROUP E2 DONE $(date)" >> "$LOG"
