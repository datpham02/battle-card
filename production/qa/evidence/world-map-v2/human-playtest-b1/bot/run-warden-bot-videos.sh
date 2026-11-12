#!/usr/bin/env bash
# Records 9 bot warden fights (3 priority heroes x Heat 2/3/4, dodge 0.3 s, seed 3) as AVI (Movie Maker mode,
# MJPEG, 60 fps) for a human to watch the surge rhythm. One at a time (encoding is CPU-bound). Videos stay local.
set -u
cd "$(dirname "$0")/../../../../../.." || exit 1
GODOT=${GODOT:-C:/Users/ADMIN/AppData/Local/Microsoft/WinGet/Links/godot.exe}
BOT=${BOT:?path to warden_bot.gd}
OUT=production/qa/evidence/world-map-v2/human-playtest-b1/bot/video
mkdir -p "$OUT"
LOG=$OUT/videos.log
echo "START $(date)" >> $LOG
for h in sat_thu giao_si kiem_si; do
  for heat in 2 3 4; do
    name="$h-heat$heat-dodge0.3-s3"; t0=$(date +%s)
    timeout 900 "$GODOT" --path . --windowed --resolution 1280x720 --audio-driver Dummy --fixed-fps 60 --write-movie "$OUT/$name.avi" -s "$BOT" -- "$OUT" "$h" "$heat" 3 dodge 0.3 --no-autopause > "$OUT/$name.log" 2>&1
    echo "$name exit=$? seconds=$(( $(date +%s) - t0 )) $(grep -m1 '^RESULT' "$OUT/$name.log" | cut -c1-80)" >> "$LOG"
  done
done
echo "VIDEOS DONE $(date)" >> $LOG
