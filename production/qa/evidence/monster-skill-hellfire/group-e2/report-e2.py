"""Group E2 read-out (2026-11-14): B1 -> E (x1) -> E2 (x3.5) per character, both seed sets pooled, with the phap_su
HP confound called out (OD-1 dropped its max_hp 210 -> 170 between E and E2). Read-only.
Usage: python -I -X utf8 report-e2.py"""
import os, importlib.util

D = os.path.dirname(os.path.abspath(__file__))
HF = os.path.dirname(D)
spec = importlib.util.spec_from_file_location("agg", os.path.join(HF, "group-e", "aggregate-e.py"))
src = open(spec.origin, encoding="utf-8").read().replace("\nmain()\n", "\n")
agg = {"__file__": spec.origin}
exec(compile(src, spec.origin, "exec"), agg)
B1 = os.path.join(os.path.dirname(HF), "world-map-v2", "b1-balance")
CHARS = ["kiem_si", "phap_su", "sat_thu", "tho_san", "giao_si"]
SETS = ["2001", "3001"]
KEYS = [("win", "run win %"), ("hell_clear", "hellfire clear %"), ("lane_hp_fights", "HP lost in fights / route"),
        ("f2_hp_after", "HP % after warden"), ("min_all", "est. minutes, all runs")]


def mean(v):
    v = [x for x in v if x == x]
    return sum(v) / len(v) if v else float("nan")


def series(variant, c):
    out = []
    for s in SETS:
        p = {"B1": os.path.join(B1, "B1-s%s-full-value-%s.txt" % (s, c)),
             "E": os.path.join(HF, "group-e", "E-s%s-%s.txt" % (s, c)),
             "E2": os.path.join(HF, "group-e2", "E2-s%s-%s.txt" % (s, c))}[variant]
        m = agg["metrics"](p)
        if m:
            out.append(m)
    return out


print("# Group E2 (Hellfire damage x3.5) vs B1 (block brain) and E (x1), both seed sets pooled\n")
for key, label in KEYS:
    print("## %s\n" % label)
    print("| character | B1 | E x1 | E2 x3.5 | E2 - B1 |")
    print("|---|---|---|---|---|")
    for c in CHARS:
        v = {k: mean([m[key] for m in series(k, c)]) for k in ["B1", "E", "E2"]}
        note = "  <- also max_hp 210 -> 170 (OD-1)" if c == "phap_su" and key == "win" else ""
        print("| %s | %.1f | %.1f | %.1f | %+.1f%s |" % (c, v["B1"], v["E"], v["E2"], v["E2"] - v["B1"], note))
    pooled = {k: mean([mean([m[key] for m in series(k, c)]) for c in CHARS]) for k in ["B1", "E", "E2"]}
    print("| **pooled** | **%.1f** | **%.1f** | **%.1f** | **%+.1f** |\n" % (pooled["B1"], pooled["E"], pooled["E2"], pooled["E2"] - pooled["B1"]))
print("Excluding phap_su (its max_hp changed between E and E2, so its E2 row mixes two changes):\n")
print("| metric | B1 | E2 x3.5 | diff |")
print("|---|---|---|---|")
for key, label in KEYS:
    four = [c for c in CHARS if c != "phap_su"]
    a = mean([mean([m[key] for m in series("B1", c)]) for c in four])
    b = mean([mean([m[key] for m in series("E2", c)]) for c in four])
    print("| %s | %.1f | %.1f | %+.1f |" % (label, a, b, b - a))
