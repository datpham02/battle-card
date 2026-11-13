"""Calibration read-out (2026-11-13): Hellfire figures of cal-<tag>-s2001-<char>.txt next to B1 and E (same set 2001).
Usage: python -I -X utf8 read-cal.py <tag>   (from this folder)"""
import os, sys, importlib.util
D = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("agg", os.path.join(D, "..", "group-e", "aggregate-e.py"))
src = open(spec.origin, encoding="utf-8").read().replace("\nmain()\n", "\n")
agg = {"__file__": spec.origin}
exec(compile(src, spec.origin, "exec"), agg)
tag = sys.argv[1]
B1 = os.path.join(D, "..", "..", "world-map-v2", "b1-balance")
for c in ["kiem_si", "sat_thu"]:
    rows = [("B1", os.path.join(B1, "B1-s2001-full-value-%s.txt" % c)), ("E x1", os.path.join(D, "..", "group-e", "E-s2001-%s.txt" % c)),
            (tag, os.path.join(D, "cal-%s-s2001-%s.txt" % (tag, c)))]
    print(c)
    for name, p in rows:
        m = agg["metrics"](p)
        if not m:
            print("  %-5s missing" % name); continue
        print("  %-5s win %5.1f | hell clear %5.1f | HP lost in fights/route %5.1f | HP after warden %5.1f | min all %5.2f"
              % (name, m["win"], m["hell_clear"], m["lane_hp_fights"], m["f2_hp_after"], m["min_all"]))
