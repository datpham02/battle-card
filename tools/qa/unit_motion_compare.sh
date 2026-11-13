#!/usr/bin/env bash
# Unit motion pass (2026-11-13): before/after evidence from tools/qa/unit_motion_footage.gd output.
# For each id present in both before/ and after/, in <E>/compare/:
#   <id>_idle_4x.mp4   art-px crops at 4x, before | after, 20 fps (real time, 6 s)
#   <id>_step_4x.mp4   art-px crops at 4x, before | after, 60 fps frames played at 30 fps (half speed)
#   <id>_idle_1x.mp4   the real screen at 1:1 (1280x720 window, 2 screen px per art px), before | after, real time
#   <id>_step_1x.mp4   the same for the steps, real time (60 fps)
#   <id>_hero_step.png / <id>_enemy_step.png   every 3rd step frame at 4x, before | after per tile
# Usage: bash tools/qa/unit_motion_compare.sh <evidence dir with before/ and after/>
set -euo pipefail
E="${1:?evidence dir}"
FF="${FFMPEG:-C:/Users/ADMIN/AppData/Local/Microsoft/WinGet/Links/ffmpeg.exe}"
ENC=(-c:v libx264 -crf 10 -preset slow -pix_fmt yuv420p)
SBS="[0]pad=iw+12:ih:0:0:color=0x402020[a];[a][1]hstack,pad=ceil(iw/2)*2:ceil(ih/2)*2"
mkdir -p "$E/compare"
for d in "$E"/after/*/; do
	id=$(basename "$d")
	[ -d "$E/before/$id" ] || continue
	"$FF" -y -loglevel error -framerate 20 -i "$E/before/$id/idle_%03d.png" -framerate 20 -i "$E/after/$id/idle_%03d.png" \
		-filter_complex "$SBS" "${ENC[@]}" "$E/compare/${id}_idle_4x.mp4"
	"$FF" -y -loglevel error -framerate 30 -i "$E/before/$id/step_%03d.png" -framerate 30 -i "$E/after/$id/step_%03d.png" \
		-filter_complex "$SBS" "${ENC[@]}" "$E/compare/${id}_step_4x.mp4"
	"$FF" -y -loglevel error -framerate 20 -i "$E/before/$id/screen_idle_%03d.png" -framerate 20 -i "$E/after/$id/screen_idle_%03d.png" \
		-filter_complex "$SBS" "${ENC[@]}" "$E/compare/${id}_idle_1x.mp4"
	"$FF" -y -loglevel error -framerate 60 -i "$E/before/$id/screen_step_%03d.png" -framerate 60 -i "$E/after/$id/screen_step_%03d.png" \
		-filter_complex "$SBS" "${ENC[@]}" "$E/compare/${id}_step_1x.mp4"
	for part in hero:0 enemy:36; do
		name=${part%%:*}; start=${part#*:}
		"$FF" -y -loglevel error -start_number "$start" -framerate 60 -i "$E/before/$id/step_%03d.png" \
			-start_number "$start" -framerate 60 -i "$E/after/$id/step_%03d.png" \
			-filter_complex "[0]pad=iw+12:ih+12:0:0:color=0x402020[a];[1]pad=iw+12:ih+12:0:0:color=0x204020[b];[a][b]hstack,select='not(mod(n\,3))',tile=2x6" \
			-frames:v 1 "$E/compare/${id}_${name}_step.png"
	done
	echo "built $id"
done
