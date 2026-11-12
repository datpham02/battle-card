"""Heat decay experiment D (2026-11-12): aggregates heat-decay/*.txt (and the C full runs of balance/) into the
tables of heat-decay-experiment-2026-11-12.md. Read-only; prints Markdown. Usage: python -I aggregate-heat.py"""
import os, re

D = os.path.dirname(os.path.abspath(__file__))
BAL = os.path.join(os.path.dirname(D), "balance")
CHARS = ["kiem_si", "phap_su", "sat_thu", "tho_san", "giao_si"]
LANES = ["safe", "treasure", "peril", "elite", "mystery"]
SETS = ["2001", "3001"]


def rows(path, tag):
    out = []
    if not os.path.exists(path):
        return out
    for line in open(path, encoding="utf-8", errors="replace"):
        if line.startswith(tag + " | ") and not line.startswith(tag + " | character"):
            out.append([c.strip() for c in line.strip().strip("|").split("|")][1:])
    return out


def f(x):
    try:
        return float(x)
    except ValueError:
        return float("nan")


def probe(variant, lane, sets=SETS, chars=CHARS):
    a = {"runs": 0, "clear": 0.0, "gold": 0.0, "hp": 0.0, "relics": 0.0, "obj": 0.0, "ended": 0,
         "heat_w": 0.0, "reached": 0, "cnt": [0] * 5, "obj_nodes": 0.0, "rows": 0.0, "rows_taken": 0.0,
         "hp_c": 0.0, "hp_h": 0.0, "hp_e": 0.0, "rest_n": 0.0, "rest_in": 0.0, "rest_out": 0.0,
         "shop_n": 0.0, "shop_in": 0.0, "shop_out": 0.0, "hook_reached": 0, "hooked": 0.0}
    for s in sets:
        for c in chars:
            p = os.path.join(D, f"{variant}-s{s}-probe-{lane}-{c}.txt")
            for r in rows(p, "ROUTE"):
                if r[1] != lane:
                    continue
                n = int(r[2])
                a["runs"] += n
                for k, i in [("clear", 3), ("gold", 4), ("hp", 5), ("relics", 6), ("obj", 7)]:
                    a[k] += f(r[i]) * n
            for r in rows(p, "ROUTE2"):
                if r[1] != lane:
                    continue
                e = int(r[2])
                a["ended"] += e
                m = re.match(r"([\d.]+|-) \((\d+); (.*)\)", r[3])
                if m and m.group(1) != "-":
                    a["heat_w"] += f(m.group(1)) * int(m.group(2))
                    a["reached"] += int(m.group(2))
                    for cell in m.group(3).split():
                        h, cnt = cell.split(":")
                        a["cnt"][int(h)] += int(cnt)
                x, y = r[5].split(" / ")
                a["obj_nodes"] += f(x) * e
                x, y = r[6].split(" / ")
                a["rows"] += f(x) * e
                a["rows_taken"] += f(y) * e
                a["hp_c"] += f(r[9]) * e
                a["hp_h"] += f(r[10]) * e
                a["hp_e"] += f(r[11]) * e
            for r in rows(p, "ROUTE3"):
                if r[1] != lane:
                    continue
                e = int(r[2])
                rn = f(r[3]) * e
                a["rest_n"] += rn
                if "->" in r[4]:
                    x, y = r[4].split("->")
                    a["rest_in"] += f(x) * rn
                    a["rest_out"] += f(y) * rn
                sn = f(r[5]) * e
                a["shop_n"] += sn
                if "->" in r[6]:
                    x, y = r[6].split("->")
                    a["shop_in"] += f(x) * sn
                    a["shop_out"] += f(y) * sn
                reached = int(r[7])
                a["hook_reached"] += reached
                if r[8] != "-":
                    a["hooked"] += f(r[8]) / 100.0 * reached
    return a


def nv(a):
    n = max(a["runs"], 1)
    return a["gold"] / n + 60.0 * a["relics"] / n - 1.6 * a["hp"] / n


def main():
    print("## Lane probes, both seed sets pooled (lane == policy, 5 characters, weighted by visits)\n")
    print("| variant / lane | visits | region clear % | gold (drops) | HP lost net | relics | objective met / visit | NV | heat at warden mean | heat 3-4 at warden % | hook fired % | rests / route | heat before -> after rest | shops / route | heat before -> after shop | HP lost in fights | HP healed outside |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for v in ["C", "D"]:
        for lane in LANES:
            a = probe(v, lane)
            if not a["runs"]:
                continue
            n = a["runs"]; e = max(a["ended"], 1)
            hw = f"{a['heat_w']/a['reached']:.2f}" if a["reached"] else "-"
            s34 = 100.0 * (a["cnt"][3] + a["cnt"][4]) / max(a["reached"], 1)
            hook = f"{100.0*a['hooked']/a['hook_reached']:.1f}" if a["hook_reached"] else "-"
            rest = f"{a['rest_in']/a['rest_n']:.2f} -> {a['rest_out']/a['rest_n']:.2f}" if a["rest_n"] else "-"
            shop = f"{a['shop_in']/a['shop_n']:.2f} -> {a['shop_out']/a['shop_n']:.2f}" if a["shop_n"] else "-"
            print(f"| {v} / {lane} | {n} | {a['clear']/n:.1f} | {a['gold']/n:.1f} | {a['hp']/n:.1f} | {a['relics']/n:.2f} | {a['obj']/n:.2f} | {nv(a):.1f} | {hw} | {s34:.1f} | {hook} | {a['rest_n']/e:.2f} | {rest} | {a['shop_n']/e:.2f} | {shop} | {a['hp_c']/e:.1f} | {a['hp_h']/e:.1f} |")
    print("\n## Per seed set (peril and safe)\n")
    print("| variant / lane / set | visits | clear % | gold | HP net | relics | NV | heat 3-4 at warden % | hook fired % |")
    print("|---|---|---|---|---|---|---|---|---|")
    for v in ["C", "D"]:
        for lane in ["safe", "peril"]:
            for s in SETS:
                a = probe(v, lane, [s])
                if not a["runs"]:
                    continue
                n = a["runs"]
                s34 = 100.0 * (a["cnt"][3] + a["cnt"][4]) / max(a["reached"], 1)
                hook = f"{100.0*a['hooked']/a['hook_reached']:.1f}" if a["hook_reached"] else "-"
                print(f"| {v} / {lane} / {s} | {n} | {a['clear']/n:.1f} | {a['gold']/n:.1f} | {a['hp']/n:.1f} | {a['relics']/n:.2f} | {nv(a):.1f} | {s34:.1f} | {hook} |")
    print("\n## Per character (peril lane, both sets: clear % / gold / HP net / relics / heat 3-4 at warden %)\n")
    print("| character | C | D |")
    print("|---|---|---|")
    for c in CHARS:
        cells = []
        for v in ["C", "D"]:
            a = probe(v, "peril", SETS, [c])
            n = max(a["runs"], 1)
            s34 = 100.0 * (a["cnt"][3] + a["cnt"][4]) / max(a["reached"], 1)
            cells.append(f"{a['clear']/n:.1f} / {a['gold']/n:.0f} / {a['hp']/n:.0f} / {a['relics']/n:.2f} / {s34:.0f} %" if a["runs"] else "-")
        print(f"| {c} | " + " | ".join(cells) + " |")
    print("\n## Paired full runs (hellfire on `value`; C from balance/, D from heat-decay/)\n")
    print("| character | run win % C s1 / D s1 / C s2 / D s2 | hellfire clear % C s1 / D s1 / C s2 / D s2 | won minutes C s1 / D s1 / C s2 / D s2 |")
    print("|---|---|---|---|")
    wins = {k: [] for k in ["C1", "D1", "C2", "D2"]}
    hell = {k: [] for k in wins}
    for c in CHARS:
        files = {"C1": os.path.join(BAL, f"C-full-value-{c}.txt"), "D1": os.path.join(D, f"D-s2001-full-value-{c}.txt"),
                 "C2": os.path.join(BAL, f"rep-C-full-value-{c}.txt"), "D2": os.path.join(D, f"D-s3001-full-value-{c}.txt")}
        w, h, m = [], [], []
        for k, p in files.items():
            run = rows(p, "RUN")
            hl = None
            if os.path.exists(p):
                for line in open(p, encoding="utf-8", errors="replace"):
                    mm = re.match(r"\| \w+ \| 2 \| hellfire \| (\d+) \| (\d+) \| ([\d.]+) \|", line)
                    if mm:
                        hl = f(mm.group(3))
            if run:
                wins[k].append(f(run[0][3])); w.append(f"{f(run[0][3]):.1f}")
                m.append(run[0][6].split("/")[0].strip())
            else:
                w.append("-"); m.append("-")
            if hl is not None:
                hell[k].append(hl); h.append(f"{hl:.1f}")
            else:
                h.append("-")
        print(f"| {c} | {' / '.join(w)} | {' / '.join(h)} | {' / '.join(m)} |")
    print("| **mean** | " + " / ".join(f"{sum(v)/len(v):.1f}" if v else "-" for v in wins.values()) + " | " +
          " / ".join(f"{sum(v)/len(v):.1f}" if v else "-" for v in hell.values()) + " | |")


main()


def per_char_lanes():
    print("\n## Per character x lane (both sets pooled): clear % / heat 3-4 at warden % / HP lost in fights per route\n")
    print("| character | lane | C | D |")
    print("|---|---|---|---|")
    for c in CHARS:
        for lane in LANES:
            cells = []
            for v in ["C", "D"]:
                a = probe(v, lane, SETS, [c])
                if not a["runs"]:
                    cells.append("-"); continue
                n = a["runs"]; e = max(a["ended"], 1)
                s34 = 100.0 * (a["cnt"][3] + a["cnt"][4]) / max(a["reached"], 1)
                cells.append(f"{a['clear']/n:.1f} / {s34:.0f} % / {a['hp_c']/e:.0f}")
            print(f"| {c} | {lane} | {cells[0]} | {cells[1]} |")
    print("\n## Per character: heat before -> after rest on the peril lane (both sets pooled)\n")
    print("| character | C | D |")
    print("|---|---|---|")
    for c in CHARS:
        cells = []
        for v in ["C", "D"]:
            a = probe(v, "peril", SETS, [c])
            cells.append(f"{a['rest_in']/a['rest_n']:.2f} -> {a['rest_out']/a['rest_n']:.2f} ({a['rest_n']/max(a['ended'],1):.2f} rests/route)" if a["rest_n"] else "-")
        print(f"| {c} | {cells[0]} | {cells[1]} |")


per_char_lanes()
