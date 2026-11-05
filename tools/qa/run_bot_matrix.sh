#!/usr/bin/env bash
# Plays the playtest bot (tools/qa/play_bot.gd) over heroes x ch1 matches, one windowed Godot run each, and prints
# one RESULT line per match plus any VIOLATION / SCRIPT ERROR lines. Observations only, no verdict.
# Usage: tools/qa/run_bot_matrix.sh <out_dir> [heroes] [matches] [seed]
#   heroes / matches: comma lists; default all 5 heroes and the 6 Misty Forest matches; seed default 1.
# Run from the repo root, in the background (about 1-2 min per match).
set -u
OUT="${1:?out_dir}"
HEROES="${2:-kiem_si,phap_su,giao_si,sat_thu,tho_san}"
MATCHES="${3:-goblin_scout,dire_wolf,goblin_archer,wolf_alpha,mistbriar_matron,goblin_warlock}"
SEED="${4:-1}"
GODOT="${GODOT:-C:/Users/ADMIN/AppData/Local/Microsoft/WinGet/Links/godot.exe}"
mkdir -p "$OUT"
for h in ${HEROES//,/ }; do
	for m in ${MATCHES//,/ }; do
		"$GODOT" --path . --fixed-fps 60 -s res://tools/qa/play_bot.gd -- "$OUT" "$h" "$m" "$SEED" --no-autopause \
			> "$OUT/$h-$m.log" 2>&1
		grep -hE "^RESULT|^VIOLATION|SCRIPT ERROR" "$OUT/$h-$m.log" || echo "NO RESULT $h-$m (see $OUT/$h-$m.log)"
	done
done
