#!/usr/bin/env bash
# Download every job in batch3/jobs.tsv (id <TAB> attempt <TAB> job_id) that has no raw file yet, then run
# card_qa.py qa on it. Raw: batch3/raw/<id>_a<n>.png; processed: batch3/<id>_a<n>.png; reports: batch3/qa.jsonl.
# Usage (repo root): bash design/assets/candidates/ui/card-art/scripts/fetch_qa.sh
set -u
B=design/assets/candidates/ui/card-art/batch3
Q="python -X utf8 -I design/assets/candidates/ui/card-art/scripts/card_qa.py"
while IFS=$'\t' read -r id n job; do
  [ -z "$id" ] && continue
  raw="$B/raw/${id}_a${n}.png"
  if [ ! -s "$raw" ]; then
    code=000
    for _ in $(seq 1 30); do
      code=$(curl -s -o "$raw" -w "%{http_code}" "https://api.pixellab.ai/mcp/images/$job/download")
      [ "$code" = 200 ] && break
      sleep 4
    done
    if [ "$code" != 200 ]; then rm -f "$raw"; echo "$id a$n: download failed ($code)"; continue; fi
    $Q qa "$id" "$raw" "$B/${id}_a${n}.png" | sed "s/^{/{\"attempt\": $n, \"job_id\": \"$job\", /" >> "$B/qa.jsonl"
    tail -1 "$B/qa.jsonl" | python -X utf8 -I -c "import json,sys; r=json.loads(sys.stdin.read()); print(r['id'], 'a%d' % r['attempt'], 'PASS' if r['pass'] else 'FAIL', [k for k,v in r['checks'].items() if not v], r.get('bbox'), r.get('colours'), r.get('off_subset'))"
  fi
done < "$B/jobs.tsv"
