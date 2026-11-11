#!/bin/bash
# Runs every suite one Godot process at a time: headless for tests/unit + tests/integration (not ui), windowed for ui.
G=${GODOT:-godot}
OUT="$1"; : > "$OUT"
cd "$(dirname "$0")/../.." || exit 1
for t in $(find tests/unit tests/integration -name "*_test.gd" | grep -v "tests/integration/ui/" | sort); do
  r=$(timeout 240 "$G" --headless -s res://$t 2>&1); echo "$t: $(echo "$r" | grep -oE 'FAILS[=:] ?[0-9]+' | tail -1) $(echo "$r" | grep -c 'SCRIPT ERROR') se" >> "$OUT"
done
for t in $(find tests/integration/ui -name "*_test.gd" | sort); do
  r=$(timeout 240 "$G" --path . --windowed --resolution 1280x720 --audio-driver Dummy -s res://$t -- --no-autopause 2>&1); echo "$t: $(echo "$r" | grep -oE 'FAILS[=:] ?[0-9]+' | tail -1) $(echo "$r" | grep -c 'SCRIPT ERROR') se" >> "$OUT"
done
echo DONE >> "$OUT"
