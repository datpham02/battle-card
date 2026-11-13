"""Monster Skill Phase 1 group E (2026-11-13): pairs world-map-v2/b1-balance/B1-s<set>-full-value-<char>.txt (Hellfire
on the block brain) with group-e2/E2-s<set>-<char>.txt (Hellfire on the pattern brain), same flags and seeds, and prints
the same Markdown tables as aggregate-b1.py with columns B1 -> E. Read-only. Usage: python -I aggregate-e.py"""
import os, re

D = os.path.dirname(os.path.abspath(__file__))
BAL = os.path.join(os.path.dirname(os.path.dirname(D)), "world-map-v2", "b1-balance")
CHARS = ["kiem_si", "phap_su", "sat_thu", "tho_san", "giao_si"]
SETS = {"2001": ("B1-s2001-full-value-%s.txt", "E2-s2001-%s.txt"), "3001": ("B1-s3001-full-value-%s.txt", "E2-s3001-%s.txt")}
LANES = ["safe", "treasure", "peril", "elite", "mystery"]


def f(x):
    try:
        return float(str(x).split()[0])
    except (ValueError, IndexError):
        return float("nan")


def cells(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]


def parse(path):
    """{table name: [dict(header cell -> value)]} for the tagged tables (RUN, ROUTE, ROUTE2, REGION x FLOOR) and the
    headed Markdown tables (WORLD SUMMARY, WORLD FLOORS, WORLD REGIONS, WORLD ECONOMY)."""
    out = {}
    if not os.path.exists(path):
        return out
    headers = {}
    current = None
    for line in open(path, encoding="utf-8", errors="replace"):
        s = line.rstrip("\n")
        m = re.match(r"^(RUN|ROUTE|ROUTE2|ROUTE3|REGION x FLOOR|WORLD SUMMARY|WORLD FLOORS|WORLD REGIONS|WORLD ECONOMY) \| (.*)$", s)
        if m:
            tag, rest = m.group(1), m.group(2)
            c = cells(rest)
            if c and c[0] == "character":
                headers[tag] = c
                current = tag
                out.setdefault(tag, [])
                continue
            if tag in headers:
                out.setdefault(tag, []).append(dict(zip(headers[tag], c)))
            continue
        if s.startswith("|---"):
            continue
        if s.startswith("| ") and current in ("WORLD SUMMARY", "WORLD FLOORS", "WORLD REGIONS", "WORLD ECONOMY") and current in headers:
            c = cells(s)
            if c and c[0] in CHARS:
                out.setdefault(current, []).append(dict(zip(headers[current], c)))
            continue
        if not s.strip():
            current = None
    return out


def one(t, tag, **where):
    for r in t.get(tag, []):
        if all(str(r.get(k, "")) == str(v) for k, v in where.items()):
            return r
    return {}


def metrics(path):
    t = parse(path)
    if not t:
        return {}
    m = {}
    run = one(t, "RUN")
    m["win"] = f(run.get("win %"))
    mins = run.get("run minutes (est., won median / lost median)", "")
    m["min_won_med"] = f(mins.split("/")[0]) if "/" in mins else float("nan")
    m["min_lost_med"] = f(mins.split("/")[1]) if "/" in mins else float("nan")
    gold = run.get("gold earned / spent (all runs; won runs)", "")
    mm = re.match(r"([\d.]+) / ([\d.]+); ([\d.]+) / ([\d.]+)", gold)
    m["gold_earned"], m["gold_spent"], m["gold_earned_won"], m["gold_spent_won"] = [f(x) for x in mm.groups()] if mm else [float("nan")] * 4
    m["relics"] = f(run.get("relics / run"))
    m["deck"] = f(run.get("deck size"))
    m["hits_won"] = f(run.get("hits taken / won run"))
    ws = one(t, "WORLD SUMMARY")
    m["min_all"] = f(ws.get("est. minutes all runs"))
    m["min_won_mean"] = f(ws.get("est. minutes WON run mean (min-max)"))
    m["hits_all"] = f(ws.get("hits / run (all)"))
    m["matches_run"] = f(ws.get("matches / run"))
    fl2 = one(t, "WORLD FLOORS", floor="2")
    m["f2_clear"] = f(fl2.get("clear % of runs entering"))
    m["f2_hp_in"] = f(fl2.get("mean HP % entering"))
    m["f2_hp_after"] = f(fl2.get("mean HP % after boss (before heal)"))
    reg = one(t, "WORLD REGIONS", floor="2")
    m["hell_entered"] = f(reg.get("entered"))
    m["hell_cleared"] = f(reg.get("cleared"))
    m["hell_clear"] = f(reg.get("clear %"))
    rxf = one(t, "REGION x FLOOR", floor="2")
    m["hell_matches"] = f(rxf.get("matches entered"))
    m["hell_match_win"] = f(rxf.get("match win %"))
    # Lanes (hellfire, value policy): pooled over archetypes weighted by runs.
    lanes = {}
    for r in t.get("ROUTE", []):
        n = f(r.get("runs"))
        lanes[r["archetype"]] = {"n": n, "clear": f(r.get("region clear %")), "gold": f(r.get("gold gained (drops, mean)")),
                                 "hp": f(r.get("HP lost pts of max (mean)")), "relics": f(r.get("relics gained (mean)")),
                                 "obj": f(r.get("objective met / run")), "win": f(r.get("run win %"))}
    for r in t.get("ROUTE2", []):
        a = lanes.setdefault(r["archetype"], {"n": f(r.get("routes ended"))})
        a["ended"] = f(r.get("routes ended"))
        hw = r.get("heat at warden mean (reached; count by heat 0..4)", "")
        mm = re.match(r"([\d.]+|-) \((\d+); (.*)\)", hw)
        a["heat_cnt"] = [0] * 5
        a["reached"] = 0
        if mm and mm.group(1) != "-":
            a["reached"] = int(mm.group(2))
            for cell in mm.group(3).split():
                h, cnt = cell.split(":")
                a["heat_cnt"][int(h)] = int(cnt)
        a["hp_fights"] = f(r.get("HP lost in fights pts"))
        a["hp_heal"] = f(r.get("HP healed outside fights pts"))
        x = r.get("objective fights won / met per route", "0 / 0").split("/")
        a["obj_fights"], a["obj_met"] = f(x[0]), f(x[1])
        x = r.get("relic rows offered / taken per route", "0 / 0").split("/")
        a["relic_off"], a["relic_taken"] = f(x[0]), f(x[1])
    m["lanes"] = lanes
    tot = sum(a.get("n", 0) for a in lanes.values()) or 1
    m["lane_hp_fights"] = sum(a.get("hp_fights", 0) * a.get("ended", 0) for a in lanes.values()) / max(sum(a.get("ended", 0) for a in lanes.values()), 1)
    m["lane_gold"] = sum(a["gold"] * a["n"] for a in lanes.values() if "gold" in a) / tot
    m["lane_relics"] = sum(a["relics"] * a["n"] for a in lanes.values() if "relics" in a) / tot
    m["lane_hp"] = sum(a["hp"] * a["n"] for a in lanes.values() if "hp" in a) / tot
    m["lane_obj"] = sum(a["obj"] * a["n"] for a in lanes.values() if "obj" in a) / tot
    m["lane_nv"] = m["lane_gold"] + 60.0 * m["lane_relics"] - 1.6 * m["lane_hp"]
    cnt = [0] * 5
    reached = 0
    for a in lanes.values():
        for i in range(5):
            cnt[i] += a.get("heat_cnt", [0] * 5)[i]
        reached += a.get("reached", 0)
    m["heat_cnt"] = cnt
    m["reached"] = reached
    m["heat34"] = 100.0 * (cnt[3] + cnt[4]) / max(reached, 1)
    m["heat_mean"] = sum(i * cnt[i] for i in range(5)) / max(reached, 1)
    return m


def mean(vals):
    vals = [v for v in vals if v == v]
    return sum(vals) / len(vals) if vals else float("nan")


def fmt(v, d=1):
    if v is None or v != v:
        return "-"
    return f"{v:.{d}f}"


def main():
    data = {}  # (variant, set, char) -> metrics
    for s, (cf, bf) in SETS.items():
        for c in CHARS:
            data[("B1", s, c)] = metrics(os.path.join(BAL, cf % c))
            data[("E", s, c)] = metrics(os.path.join(D, bf % c))

    def col(variant, key, s=None, c=None):
        return [data[(variant, ss, cc)].get(key, float("nan")) for ss in SETS for cc in CHARS
                if data[(variant, ss, cc)] and (s is None or ss == s) and (c is None or cc == c)]

    print("## 1. Character x seed set: run win % (B1 -> E, diff)\n")
    print("| character | set 2001 | set 3001 | mean B1 | mean E | diff |")
    print("|---|---|---|---|---|---|")
    for c in CHARS:
        cellsx = []
        for s in SETS:
            cm, bm = data[("B1", s, c)], data[("E", s, c)]
            cellsx.append(f"{fmt(cm.get('win'))} -> {fmt(bm.get('win'))} ({fmt(bm.get('win', float('nan')) - cm.get('win', float('nan')), 1) if bm and cm else '-'})")
        mc, mb = mean(col("B1", "win", c=c)), mean(col("E", "win", c=c))
        print(f"| {c} | {cellsx[0]} | {cellsx[1]} | {fmt(mc)} | {fmt(mb)} | {fmt(mb - mc)} |")
    pc, pb = mean(col("B1", "win")), mean(col("E", "win"))
    print(f"| **pooled (10 combos, 700 runs each)** | {fmt(mean(col('B1', 'win', s='2001')))} -> {fmt(mean(col('E', 'win', s='2001')))} | {fmt(mean(col('B1', 'win', s='3001')))} -> {fmt(mean(col('E', 'win', s='3001')))} | **{fmt(pc)}** | **{fmt(pb)}** | **{fmt(pb - pc)}** |")

    print("\n## 2. Run-level metrics, pooled over the 10 combos (mean of per-combo values)\n")
    print("| metric | B1 | E | diff | diff % |")
    print("|---|---|---|---|---|")
    for key, label, d in [("win", "run win %", 1), ("hell_clear", "hellfire clear % (of runs entering floor 2)", 1),
                          ("f2_clear", "floor 2 clear % of runs entering (WORLD FLOORS)", 1), ("hell_match_win", "hellfire match win %", 1),
                          ("min_all", "est. minutes, all runs", 2), ("min_won_mean", "est. minutes, won runs (mean)", 2),
                          ("min_won_med", "run minutes, won median", 2), ("min_lost_med", "run minutes, lost median", 2),
                          ("hits_all", "hits taken / run (all)", 2), ("hits_won", "hits taken / won run", 2), ("matches_run", "matches / run", 2),
                          ("gold_earned", "gold earned / run (all)", 1), ("gold_spent", "gold spent / run (all)", 1),
                          ("gold_earned_won", "gold earned / won run", 1), ("relics", "relics / run", 2), ("deck", "deck size", 2),
                          ("f2_hp_in", "HP % entering floor 2", 1), ("f2_hp_after", "HP % after the hellfire warden (before heal)", 1),
                          ("lane_hp_fights", "hellfire: HP lost in fights per route (pts)", 1), ("lane_hp", "hellfire: net HP lost per route (pts)", 1),
                          ("lane_gold", "ROUTE gold (drops, mean of runs by hellfire lane taken; whole-run figure in full runs)", 1), ("lane_relics", "ROUTE relics (mean of runs by lane taken)", 2),
                          ("lane_obj", "hellfire: objective met per route", 2), ("lane_nv", "ROUTE NV = gold + 60 relics - 1.6 HP (same caveat; compare B1 vs E only)", 1),
                          ("heat_mean", "hellfire: heat at warden (mean)", 2), ("heat34", "hellfire: warden reached at heat 3-4 %", 1)]:
        a, b = mean(col("B1", key)), mean(col("E", key))
        pct = f"{100.0 * (b - a) / a:+.1f} %" if a == a and a != 0 else "-"
        print(f"| {label} | {fmt(a, d)} | {fmt(b, d)} | {fmt(b - a, d)} | {pct} |")

    print("\n## 3. Per character (both sets pooled): win % / hellfire clear % / minutes all runs / gold earned / relics / hellfire HP in fights / heat 3-4 at warden %\n")
    print("| character | B1 | E | diff (win / hell / min / gold / relics / HP / heat34) |")
    print("|---|---|---|---|")
    for c in CHARS:
        vals = []
        for v in ["B1", "E"]:
            vals.append([mean(col(v, k, c=c)) for k in ["win", "hell_clear", "min_all", "gold_earned", "relics", "lane_hp_fights", "heat34"]])
        cstr = " / ".join(fmt(x, 2 if i in (2, 4) else 1) for i, x in enumerate(vals[0]))
        bstr = " / ".join(fmt(x, 2 if i in (2, 4) else 1) for i, x in enumerate(vals[1]))
        dstr = " / ".join(fmt(b - a, 2 if i in (2, 4) else 1) for i, (a, b) in enumerate(zip(vals[0], vals[1])))
        print(f"| {c} | {cstr} | {bstr} | {dstr} |")

    print("\n## 4. Hellfire clear % per character x set (B1 -> E), deaths on floor 2 of 70\n")
    print("| character | set 2001 | set 3001 |")
    print("|---|---|---|")
    for c in CHARS:
        cl = []
        for s in SETS:
            cm, bm = data[("B1", s, c)], data[("E", s, c)]
            cl.append(f"{fmt(cm.get('hell_clear'))} -> {fmt(bm.get('hell_clear'))} (deaths {fmt(cm.get('hell_entered', 0) - cm.get('hell_cleared', 0), 0)} -> {fmt(bm.get('hell_entered', 0) - bm.get('hell_cleared', 0), 0)})")
        print(f"| {c} | {cl[0]} | {cl[1]} |")

    print("\n## 5. Warden arrival heat distribution (hellfire, value policy; all characters and sets pooled)\n")
    print("| variant | wardens reached | heat 0 | heat 1 | heat 2 | heat 3 | heat 4 | heat 3-4 % | mean heat |")
    print("|---|---|---|---|---|---|---|---|---|")
    for v in ["B1", "E"]:
        cnt = [0] * 5
        reached = 0
        for s in SETS:
            for c in CHARS:
                m = data[(v, s, c)]
                if not m:
                    continue
                reached += m["reached"]
                for i in range(5):
                    cnt[i] += m["heat_cnt"][i]
        if reached:
            print(f"| {v} | {reached} | " + " | ".join(f"{cnt[i]} ({100.0*cnt[i]/reached:.1f} %)" for i in range(5)) + f" | {100.0*(cnt[3]+cnt[4])/reached:.1f} | {sum(i*cnt[i] for i in range(5))/reached:.2f} |")

    print("\n## 6. Hellfire lanes taken on `value` (pooled over characters and sets, weighted by runs): clear % / gold / net HP / relics / objective / run win %\n")
    print("| lane | B1 runs | B1 | E runs | E |")
    print("|---|---|---|---|---|")
    for lane in LANES:
        agg = {}
        for v in ["B1", "E"]:
            n = 0
            acc = {"clear": 0.0, "gold": 0.0, "hp": 0.0, "relics": 0.0, "obj": 0.0, "win": 0.0, "hpf": 0.0, "ended": 0.0}
            for s in SETS:
                for c in CHARS:
                    a = data[(v, s, c)].get("lanes", {}).get(lane) if data[(v, s, c)] else None
                    if not a or "clear" not in a:
                        continue
                    n += a["n"]
                    for k in ["clear", "gold", "hp", "relics", "obj", "win"]:
                        acc[k] += a[k] * a["n"]
                    acc["hpf"] += a.get("hp_fights", 0) * a.get("ended", 0)
                    acc["ended"] += a.get("ended", 0)
            agg[v] = (n, acc)
        row = []
        for v in ["B1", "E"]:
            n, acc = agg[v]
            if n:
                row.append(f"{int(n)} | {acc['clear']/n:.1f} / {acc['gold']/n:.1f} / {acc['hp']/n:.1f} / {acc['relics']/n:.2f} / {acc['obj']/n:.2f} / {acc['win']/n:.1f} (HP in fights {acc['hpf']/max(acc['ended'],1):.1f})")
            else:
                row.append("0 | -")
        print(f"| {lane} | {row[0]} | {row[1]} |")

    print("\n## 7. Files\n")
    for s, (cf, bf) in SETS.items():
        for c in CHARS:
            cp, bp = os.path.join(BAL, cf % c), os.path.join(D, bf % c)
            print(f"- set {s} {c}: B1 `b1-balance/{cf % c}` ({'ok' if os.path.exists(cp) else 'MISSING'}), E2 `group-e2/{bf % c}` ({'ok' if os.path.exists(bp) else 'MISSING'})")


main()
