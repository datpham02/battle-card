#!/bin/bash
# Unified technical art QA — thin wrapper around tools/qa/art_check.py (see its docstring for modes).
#   bash tools/qa/art_check.sh all | changed | asset <id> | character <entity> | clip <entity> <clip> | candidate <folder>
# Options after the mode pass through (--no-godot, --json <path>, --godot <exe>, --layer overlay|floor).
# Exit 1 on FAIL; UNKNOWN / WARNING exit 0 but are printed by name — read the report, not only the exit code.
set -u
cd "$(dirname "$0")/../.." || exit 1
PYTHON=""
for c in python python3 py; do
  if command -v "$c" >/dev/null 2>&1; then PYTHON="$c"; break; fi
done
if [ -z "$PYTHON" ]; then
  echo "UNKNOWN  art_check: no python interpreter (tried python, python3, py)"
  exit 0
fi
exec "$PYTHON" -X utf8 -I tools/qa/art_check.py "$@"
