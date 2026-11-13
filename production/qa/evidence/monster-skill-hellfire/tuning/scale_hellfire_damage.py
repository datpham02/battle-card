"""Monster Skill Phase 1 tuning (2026-11-13, user chose "raise skill damage" after group E): sets the direct-hit damage of the
Hellfire pattern skills in assets/data/enemy_skills.json to round(BASE x M). BASE = the approved design values (design doc
section 4); burn-zone ticks (zone.damage 2.0) are not touched. Idempotent: always computed from BASE.
Usage: python -I -X utf8 scale_hellfire_damage.py <multiplier>   (run from the repo root)"""
import re, sys
BASE = {"imp_ash_dart": [6], "hound_ember_charge": [10], "golem_cinder_slam": [12], "shared_jab": [8], "slug_lava_spit": [8],
        "knight_cleave": [14], "eater_ember_belch": [12], "phoenix_ash_dive": [12], "lord_brand": [10], "lord_cinder_lane": [14],
        "lord_eruption_call": [14, 10]}  # eruption: first strike, then followup
m = float(sys.argv[1])
p = "assets/data/enemy_skills.json"
raw = open(p, "rb").read().decode("utf-8")
for sid, vals in BASE.items():
    start = raw.index('"%s": {' % sid)
    nxt = re.search(r'\n\t\t\}', raw[start:])
    end = start + nxt.end()
    block = raw[start:end]
    hits = list(re.finditer(r'"damage": (\d+)(?=[,}])', block))
    hits = [h for h in hits if int(h.group(1)) > 0]
    assert len(hits) == len(vals), (sid, [h.group(0) for h in hits])
    for h, b in reversed(list(zip(hits, vals))):
        block = block[:h.start(1)] + str(int(round(b * m))) + block[h.end(1):]
    raw = raw[:start] + block + raw[end:]
open(p, "wb").write(raw.encode("utf-8"))
print("x%s:" % m, {k: [int(round(b * m)) for b in v] for k, v in BASE.items()})
