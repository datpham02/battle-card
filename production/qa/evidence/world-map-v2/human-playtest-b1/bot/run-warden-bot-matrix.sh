#!/usr/bin/env bash
# B1 warden bot playtest matrix (2026-11-12): the scratchpad bot (copy: warden_bot.gd.txt here) plays the live warden
# at Heat 2 / 3 / 4 as every hero. dodge = leaves a warned / erupting cell after a 0.3 s (or 0.6 s) reaction,
# cancelling a placement if it must; naive = ignores vents (upper bound of vent damage). 3 windowed Godot at a time.
set -u
cd "$(dirname "$0")/../../../../../.." || exit 1
GODOT=${GODOT:-C:/Users/ADMIN/AppData/Local/Microsoft/WinGet/Links/godot.exe}
BOT=${BOT:?path to warden_bot.gd}
OUT=production/qa/evidence/world-map-v2/human-playtest-b1/bot
LOG=$OUT/matrix.log
: > $OUT/jobs.txt
for h in sat_thu giao_si kiem_si phap_su tho_san; do
  for heat in 2 3 4; do
    for seed in 1 2; do echo "$h $heat $seed dodge 0.3" >> $OUT/jobs.txt; done
  done
done
for h in sat_thu giao_si kiem_si; do
  for heat in 2 3 4; do
    echo "$h $heat 1 dodge 0.6" >> $OUT/jobs.txt
    echo "$h $heat 1 naive 0" >> $OUT/jobs.txt
  done
done
echo "START $(date) jobs=$(wc -l < $OUT/jobs.txt)" >> $LOG
export GODOT BOT OUT LOG
run_one() { set -- $1; local h=$1 heat=$2 seed=$3 pol=$4 react=$5; local name="$h-heat$heat-$pol$react-s$seed"; local t0=$(date +%s)
  timeout 420 "$GODOT" --path . --windowed --resolution 1280x720 --audio-driver Dummy --fixed-fps 60 -s "$BOT" -- "$OUT" "$h" "$heat" "$seed" "$pol" "$react" --no-autopause > "$OUT/$name.log" 2>&1
  echo "$name exit=$? seconds=$(( $(date +%s) - t0 )) $(grep -m1 '^RESULT' "$OUT/$name.log" | cut -c1-80)" >> "$LOG"; }
export -f run_one
xargs -P 3 -I{} bash -c 'run_one "$@"' _ {} < $OUT/jobs.txt
echo "MATRIX DONE $(date)" >> $LOG
