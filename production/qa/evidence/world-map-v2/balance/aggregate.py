"""World Map v2 balance validation (2026-11-12): aggregates the raw deck_sim outputs of run-experiments.sh into the
tables of balance-validation-2026-11-12.md. Read-only; prints Markdown. Usage: python -I aggregate.py [balance dir]."""
import glob, os, re, sys

D = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))
EV = os.path.dirname(D)
CHARS = ["kiem_si", "phap_su", "sat_thu", "tho_san", "giao_si"]


def rows(path, tag):
    out = []
    for line in open(path, encoding="utf-8", errors="replace"):
        if line.startswith(tag + " | ") and not line.startswith(tag + " | character"):
            out.append([c.strip() for c in line.strip().strip("|").split("|")][1:])
    return out


def f(x):
    try:
        return float(x)
    except ValueError:
        return float("nan")


def probe(variant, policy):
    """Pooled lane rows (archetype == policy) over the 5 characters: visits-weighted means of ROUTE + ROUTE2."""
    acc = {"runs": 0, "ended": 0, "clear": 0.0, "gold": 0.0, "hp": 0.0, "relics": 0.0, "obj": 0.0,
           "heat_w_sum": 0.0, "heat_w_n": 0, "heat_cnt": [0] * 5, "heat_max": 0.0, "obj_nodes": 0.0, "obj_met": 0.0,
           "rows": 0.0, "rows_taken": 0.0, "ink_o": 0.0, "ink_t": 0.0, "forge": 0.0, "forge_r": 0.0,
           "hp_c": 0.0, "hp_h": 0.0, "hp_e": 0.0, "per_char": {}}
    for c in CHARS:
        p = os.path.join(D, f"{variant}-probe-{policy}-{c}.txt")
        if not os.path.exists(p):
            continue
        for r in rows(p, "ROUTE"):
            if r[1] != policy:
                continue
            n = int(r[2])
            acc["runs"] += n
            acc["clear"] += f(r[3]) * n
            acc["gold"] += f(r[4]) * n
            acc["hp"] += f(r[5]) * n
            acc["relics"] += f(r[6]) * n
            acc["obj"] += f(r[7]) * n
            acc["per_char"][c] = {"n": n, "clear": f(r[3]), "gold": f(r[4]), "hp": f(r[5]), "relics": f(r[6]), "obj": f(r[7])}
        for r in rows(p, "ROUTE2"):
            if r[1] != policy:
                continue
            ended = int(r[2])
            acc["ended"] += ended
            m = re.match(r"([\d.]+|-) \((\d+); (.*)\)", r[3])
            if m and m.group(1) != "-":
                acc["heat_w_sum"] += f(m.group(1)) * int(m.group(2))
                acc["heat_w_n"] += int(m.group(2))
                for cell in m.group(3).split():
                    h, cnt = cell.split(":")
                    acc["heat_cnt"][int(h)] += int(cnt)
            acc["heat_max"] += f(r[4]) * ended
            a, b = r[5].split(" / ")
            acc["obj_nodes"] += f(a) * ended
            acc["obj_met"] += f(b) * ended
            a, b = r[6].split(" / ")
            acc["rows"] += f(a) * ended
            acc["rows_taken"] += f(b) * ended
            if "n/a" not in r[7]:
                a, b = r[7].split(" / ")
                acc["ink_o"] += f(a) * ended
                acc["ink_t"] += f(b) * ended
            a, b = r[8].split(" / ")
            acc["forge"] += f(a) * ended
            if "n/a" not in b:
                acc["forge_r"] += f(b) * ended
            acc["hp_c"] += f(r[9]) * ended
            acc["hp_h"] += f(r[10]) * ended
            acc["hp_e"] += f(r[11]) * ended
    return acc


def probe_line(label, a):
    n = max(a["runs"], 1)
    e = max(a["ended"], 1)
    nv = a["gold"] / n + 60.0 * a["relics"] / n - 1.6 * a["hp"] / n
    return (f"| {label} | {a['runs']} | {a['clear']/n:.1f} | {a['gold']/n:.1f} | {a['hp']/n:.1f} | {a['relics']/n:.2f} | "
            f"{a['obj']/n:.2f} | {nv:.1f} |"), e


def probe_line2(label, a):
    e = max(a["ended"], 1)
    hw = f"{a['heat_w_sum']/a['heat_w_n']:.2f}" if a["heat_w_n"] else "-"
    cnt = " ".join(f"{h}:{c}" for h, c in enumerate(a["heat_cnt"]))
    share34 = 100.0 * (a["heat_cnt"][3] + a["heat_cnt"][4]) / max(a["heat_w_n"], 1)
    return (f"| {label} | {a['ended']} | {hw} ({cnt}) | {share34:.1f} | {a['heat_max']/e:.2f} | {a['obj_nodes']/e:.2f} / {a['obj_met']/e:.2f} | "
            f"{a['rows']/e:.2f} / {a['rows_taken']/e:.2f} | {a['ink_o']/e:.2f} / {a['ink_t']/e:.2f} | {a['forge']/e:.2f} / {a['forge_r']/e:.2f} | "
            f"{a['hp_c']/e:.1f} | {a['hp_h']/e:.1f} | {a['hp_e']/e:.1f} | {a['hp']/max(a['runs'],1):.1f} |")


def full(variant, c):
    p = os.path.join(D, f"{variant}-full-value-{c}.txt") if variant != "v1" else os.path.join(EV, f"baseline-7floor-v1-raw-{c}-seeded.txt")
    if not os.path.exists(p):
        return None
    run = rows(p, "RUN")
    if not run:
        return None
    r = run[0]
    reg = None
    for line in open(p, encoding="utf-8", errors="replace"):
        if line.startswith(f"| {c} | 2 | hellfire |"):
            cells = [x.strip() for x in line.strip().strip("|").split("|")]
            reg = (int(cells[3]), int(cells[4]), f(cells[5]))
    return {"win": f(r[3]), "deaths": r[4], "minutes": r[6], "gold": r[7], "relics": f(r[8]), "hell": reg}


def main():
    print("## Probe tables (lane == policy, 5 characters pooled, weighted by visits)\n")
    print("| variant / lane | visits | region clear % | gold (drops) | HP lost pts | relics | objective met / visit | NV gold-eq |")
    print("|---|---|---|---|---|---|---|---|")
    for variant, pols in [("cur", ["safe", "treasure", "peril", "elite", "mystery", "value"]), ("A", ["safe", "peril"]), ("B", ["safe", "peril"]), ("C", ["peril"]), ("curpieces", ["safe", "treasure", "peril"])]:
        for pol in pols:
            a = probe(variant, pol)
            if a["runs"]:
                print(probe_line(f"{variant} / {pol}", a)[0])
    print("\n## Instrumentation (ROUTE2, per route that ended)\n")
    print("| variant / lane | routes ended | heat at warden mean (count 0..4) | heat 3-4 at warden % | heat max | objective fights / met | relic rows offered / taken | inks offered / taken | forge visits / free removals | HP lost in fights | HP healed outside | event HP delta | net HP lost (ROUTE) |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for variant, pols in [("cur", ["safe", "treasure", "peril", "elite", "mystery", "value"]), ("A", ["safe", "peril"]), ("B", ["safe", "peril"]), ("C", ["peril"]), ("curpieces", ["safe", "treasure", "peril"])]:
        for pol in pols:
            a = probe(variant, pol)
            if a["ended"]:
                print(probe_line2(f"{variant} / {pol}", a))
    print("\n## Per character (peril lane, region clear % / gold / HP lost / relics)\n")
    print("| character | " + " | ".join(["cur", "A", "B", "C"]) + " |")
    print("|---|---|---|---|---|")
    per = {v: probe(v, "peril")["per_char"] for v in ["cur", "A", "B", "C"]}
    for c in CHARS:
        cells = []
        for v in ["cur", "A", "B", "C"]:
            d = per[v].get(c)
            cells.append(f"{d['clear']:.1f} / {d['gold']:.0f} / {d['hp']:.0f} / {d['relics']:.2f}" if d else "-")
        print(f"| {c} | " + " | ".join(cells) + " |")
    print("\n## Paired full runs (same 70 seeds; v1 = seeded baseline, others = hellfire on `value`)\n")
    print("| character | run win % v1 / cur / A / B / C | hellfire clear % v1 / cur / A / B / C | won minutes (median) v1 / cur / A / B / C | gold earned/spent v1 / cur / A / B / C | relics at end v1 / cur / A / B / C |")
    print("|---|---|---|---|---|---|")
    means = {v: [] for v in ["v1", "cur", "A", "B", "C"]}
    hells = {v: [] for v in ["v1", "cur", "A", "B", "C"]}
    for c in CHARS:
        d = {v: full(v, c) for v in ["v1", "cur", "A", "B", "C"]}
        def cell(key, fmt):
            out = []
            for v in ["v1", "cur", "A", "B", "C"]:
                x = d[v]
                out.append(fmt(x) if x else "-")
            return " / ".join(out)
        for v in d:
            if d[v]:
                means[v].append(d[v]["win"])
                if d[v]["hell"]:
                    hells[v].append(d[v]["hell"][2])
        print(f"| {c} | {cell('win', lambda x: f'{x['win']:.1f}')} | {cell('hell', lambda x: f'{x['hell'][2]:.1f}' if x['hell'] else '-')} | "
              f"{cell('minutes', lambda x: x['minutes'].split('/')[0].strip())} | {cell('gold', lambda x: x['gold'].split(';')[0].strip())} | {cell('relics', lambda x: f'{x['relics']:.1f}')} |")
    print("| **mean** | " + " / ".join(f"{sum(m)/len(m):.1f}" if m else "-" for m in means.values()) + " | " +
          " / ".join(f"{sum(m)/len(m):.1f}" if m else "-" for m in hells.values()) + " | | | |")


main()
