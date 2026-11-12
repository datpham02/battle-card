"""B1 warden bot playtest (2026-11-12): turns the RESULT lines of bot/*.log into Markdown tables. Read-only.
Usage: python -I aggregate-bot.py"""
import glob, json, os, re, statistics

D = os.path.dirname(os.path.abspath(__file__))
HEROES = ["sat_thu", "giao_si", "kiem_si", "phap_su", "tho_san"]
RX = re.compile(r"^RESULT (?P<tag>\S+) (?P<result>WIN|LOSS|TIMEUP) (?P<real>[\d.]+)s \(sim (?P<sim>[\d.]+)s\) hp (?P<hp>[\d.]+)/(?P<hpmax>[\d.]+) enemy (?P<ehp>[\d.]+)/(?P<ehpmax>[\d.]+) \| first_surge (?P<first>\S+) gaps (?P<gaps>\[.*?\]) \(real (?P<real_s>\[.*?\])\) vents_per_surge (?P<vps>\[.*?\]) \| warned (?P<warned>\d+) erupted (?P<erupted>\d+) warn_on_me (?P<wom>\d+) unescapable (?P<unesc>\d+) \| vent_hits (?P<vh>\d+) vent_dmg (?P<vd>[\d.]+) \(locked (?P<vhl>\d+) / (?P<vdl>[\d.]+)\) other_burn (?P<ob>[\d.]+) total_dmg (?P<td>[\d.]+) \| dodges (?P<dodges>\d+) dodge_fail (?P<df>\d+) abandoned (?P<ab>\d+) casts (?P<casts>\d+) timeouts (?P<to>\d+) \| phase2_at (?P<p2>\S+) \| hz_stats (?P<hz>\{.*\})$")


def load():
    rows = []
    for p in sorted(glob.glob(os.path.join(D, "*.log"))):
        name = os.path.basename(p)[:-4]
        m = re.match(r"(\w+?)-heat(\d)-(dodge|naive)([\d.]+)-s(\d+)$", name)
        if not m:
            continue
        hero, heat, pol, react, seed = m.group(1), int(m.group(2)), m.group(3), m.group(4), int(m.group(5))
        res = None
        errs = 0
        for line in open(p, encoding="utf-8", errors="replace"):
            if "SCRIPT ERROR" in line:
                errs += 1
            mm = RX.match(line.strip())
            if mm:
                res = mm.groupdict()
        rows.append({"hero": hero, "heat": heat, "pol": pol, "react": react, "seed": seed, "name": name, "res": res, "errs": errs})
    return rows


def f(x):
    return float(x)


def main():
    rows = load()
    print("## Bot fights: per fight\n")
    print("| fight | result | sim s (real s) | HP end | first surge (sim s) | surge gaps (sim s) | vents / surge | warnings on own cell | unescapable | vent hits (while locked) | vent dmg (locked) | other burn | total dmg | dodges | casts abandoned | phase 2 at | script errors |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        x = r["res"]
        if not x:
            print(f"| {r['name']} | NO RESULT | | | | | | | | | | | | | | | {r['errs']} |")
            continue
        print(f"| {r['name']} | {x['result']} | {f(x['sim']):.0f} ({f(x['real']):.0f}) | {f(x['hp']):.0f}/{f(x['hpmax']):.0f} | {x['first']} | {x['gaps']} | {x['vps']} | {x['wom']} | {x['unesc']} | {x['vh']} ({x['vhl']}) | {f(x['vd']):.0f} ({f(x['vdl']):.0f}) | {f(x['ob']):.0f} | {f(x['td']):.0f} | {x['dodges']} | {x['ab']} | {x['p2']} | {r['errs']} |")

    print("\n## Per hero x heat, dodge 0.3 s (2 seeds): win / sim s / HP end % / vent hits / vent dmg / warnings on own cell / unescapable / abandoned casts\n")
    print("| hero | Heat 2 | Heat 3 | Heat 4 |")
    print("|---|---|---|---|")
    for h in HEROES:
        cells = []
        for heat in (2, 3, 4):
            rs = [r["res"] for r in rows if r["hero"] == h and r["heat"] == heat and r["pol"] == "dodge" and r["react"] == "0.3" and r["res"]]
            if not rs:
                cells.append("-")
                continue
            wins = sum(1 for x in rs if x["result"] == "WIN")
            cells.append(f"{wins}/{len(rs)} W / {statistics.mean(f(x['sim']) for x in rs):.0f} s / {statistics.mean(100*f(x['hp'])/f(x['hpmax']) for x in rs):.0f} % / {sum(int(x['vh']) for x in rs)} / {sum(f(x['vd']) for x in rs):.0f} / {sum(int(x['wom']) for x in rs)} / {sum(int(x['unesc']) for x in rs)} / {sum(int(x['ab']) for x in rs)}")
        print(f"| {h} | {cells[0]} | {cells[1]} | {cells[2]} |")

    print("\n## Surge timing check (dodge 0.3 s, all heroes): first surge and gaps on the simulated clock\n")
    print("| Heat | expected first / gap | fights | first surge mean (min-max) | gap mean (min-max) | gaps n |")
    print("|---|---|---|---|---|---|")
    for heat, exp in ((2, "10 / 10"), (3, "10 / 7"), (4, "10 / 7")):
        rs = [r["res"] for r in rows if r["heat"] == heat and r["pol"] == "dodge" and r["res"]]
        firsts = [f(x["first"]) for x in rs if x["first"] != "-"]
        gaps = [g for x in rs for g in json.loads(x["gaps"])]
        if not rs:
            continue
        fm = f"{statistics.mean(firsts):.1f} ({min(firsts):.1f}-{max(firsts):.1f})" if firsts else "-"
        gm = f"{statistics.mean(gaps):.1f} ({min(gaps):.1f}-{max(gaps):.1f})" if gaps else "-"
        print(f"| {heat} | {exp} | {len(rs)} | {fm} | {gm} | {len(gaps)} |")

    print("\n## Policies compared (3 priority heroes, seed 1): vent hits / vent dmg / result per heat\n")
    print("| hero | heat | dodge 0.3 | dodge 0.6 | naive |")
    print("|---|---|---|---|---|")
    for h in HEROES[:3]:
        for heat in (2, 3, 4):
            cells = []
            for pol, react in (("dodge", "0.3"), ("dodge", "0.6"), ("naive", "0")):
                rs = [r["res"] for r in rows if r["hero"] == h and r["heat"] == heat and r["pol"] == pol and r["react"] == react and r["seed"] == 1 and r["res"]]
                cells.append(f"{rs[0]['vh']} hits / {f(rs[0]['vd']):.0f} dmg / {rs[0]['result']} ({100*f(rs[0]['hp'])/f(rs[0]['hpmax']):.0f} % HP)" if rs else "-")
            print(f"| {h} | {heat} | {cells[0]} | {cells[1]} | {cells[2]} |")


main()
