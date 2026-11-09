import json, math, sys, statistics as st
from collections import defaultdict

paths = sys.argv[1:]
rows = []
for p in paths:
    for line in open(p, encoding='utf-8'):
        line = line.strip()
        if line:
            rows.append(json.loads(line))

SETUPS = ['BASE', 'baseline/A', 'baseline/A4', 'baseline/C', 'predict/A', 'predict/A4', 'predict/C']


def wilson(k, n, z=1.96):
    if n == 0:
        return (0, 0, 0)
    p = k / n
    d = 1 + z * z / n
    c = (p + z * z / (2 * n)) / d
    h = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return (100 * p, 100 * (c - h), 100 * (c + h))


def mci(xs):
    if not xs:
        return (0, 0)
    m = sum(xs) / len(xs)
    if len(xs) < 2:
        return (m, 0)
    return (m, 1.96 * st.stdev(xs) / math.sqrt(len(xs)))


# --- archetypes from BASE runs
by_match = defaultdict(list)
for r in rows:
    if r['setup'] == 'BASE':
        by_match[(r['ch'], r['match'])].append(r)
arche = {}
mob = {}
busy = {}
for key, rs in by_match.items():
    fp = max(r['fp'] for r in rs)
    spm = st.median([r['b_steps'] / max(r['sec'] / 60.0, 0.01) for r in rs])
    bs = st.median([r['b_busy_t'] / max(r['b_total_t'], 0.01) for r in rs])
    mob[key] = spm
    busy[key] = bs
    arche[key] = 'multi-cell' if fp >= 2 else None
singles = [k for k in arche if arche[k] is None]
mv = sorted(mob[k] for k in singles)
bv = sorted(busy[k] for k in singles)
m67 = mv[int(len(mv) * 0.67)] if mv else 0
b67 = bv[int(len(bv) * 0.67)] if bv else 0
for k in singles:
    if mob[k] >= m67:
        arche[k] = 'mobile'
    elif busy[k] >= b67:
        arche[k] = 'rooted'
    else:
        arche[k] = 'mixed'


def agg(rs):
    n = len(rs)
    wins = sum(1 for r in rs if r['won'])
    w = wilson(wins, n)
    sec = mci([r['sec'] for r in rs])
    casts = sum(r['fz_casts'] for r in rs)
    blasts = sum(r['fz_events'] for r in rs)
    hits = sum(r['fz_hits'] for r in rs)
    hl_dmg = sum(r['fz_dmg'] for r in rs)
    burn = sum(r['fz_burn'] for r in rs)
    dealt = sum(r['dealt'] for r in rs)
    cells = sum(r['fz_cells'] for r in rs)
    busyc = sum(r['fz_busy'] for r in rs)
    skipped = sum(r['fz_skipped'] for r in rs)
    k_hits = [k for r in rs for k, h in zip(r['lk'], r['lh']) if h]
    hr = wilson(hits, blasts)
    return {'n': n, 'win': w, 'sec': sec, 'casts_pm': casts / max(n, 1), 'blasts': blasts, 'hit': hr,
            'share': 100 * (hl_dmg + burn) / max(dealt, 1), 'burn_share': 100 * burn / max(dealt, 1),
            'dmg_cast': hl_dmg / max(casts, 1), 'dmg_hit': hl_dmg / max(hits, 1), 'cells': cells / max(blasts, 1),
            'k': sum(k_hits) / max(len(k_hits), 1), 'busy': 100 * busyc / max(casts, 1), 'skipped_pm': skipped / max(n, 1),
            'timeouts': sum(1 for r in rs if r.get('timeout'))}


def line(name, a):
    return ('| %s | %d | %.1f [%.1f–%.1f] | %.1f ± %.1f | %.2f | %.1f [%.1f–%.1f] | %.1f | %.1f | %.1f | %.1f | %.2f | %.2f | %.0f | %.2f |' %
            (name, a['n'], a['win'][0], a['win'][1], a['win'][2], a['sec'][0], a['sec'][1], a['casts_pm'], a['hit'][0], a['hit'][1],
             a['hit'][2], a['share'], a['burn_share'], a['dmg_cast'], a['dmg_hit'], a['cells'], a['k'], a['busy'], a['skipped_pm']))


HEAD = ('| set-up | n | win % [95% CI] | mean s ± CI | HL casts/match | HL hit % [CI] | HL share % (hit+burn) | burn share % | dmg/cast | dmg/hit | armed cells/blast | occupied cells/hit | casts in boss busy % | skipped/match |\n'
        '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|')

out = []
by_setup = defaultdict(list)
for r in rows:
    by_setup[r['setup']].append(r)
out.append('## Overall (all chapters)\n')
out.append(HEAD)
for s in SETUPS:
    if by_setup[s]:
        out.append(line(s, agg(by_setup[s])))

# paired differences vs BASE and vs A (matched match+seed)
idx = {(r['setup'], r['ch'], r['match'], r['seed']): r for r in rows}
out.append('\n## Paired differences (matched match + seed)\n')
out.append('| comparison | pairs | Δ win pts ± CI | Δ mean s ± CI |\n|---|---|---|---|')
for a, b in [('baseline/A', 'BASE'), ('baseline/A4', 'BASE'), ('baseline/C', 'BASE'), ('predict/A', 'BASE'), ('predict/A4', 'BASE'),
             ('predict/C', 'BASE'), ('baseline/A4', 'baseline/A'), ('baseline/C', 'baseline/A'), ('predict/A4', 'predict/A'),
             ('predict/C', 'predict/A'), ('predict/A', 'baseline/A')]:
    dw, ds = [], []
    for (s, ch, m, sd), r in idx.items():
        if s != a:
            continue
        o = idx.get((b, ch, m, sd))
        if o is None:
            continue
        dw.append((1 if r['won'] else 0) - (1 if o['won'] else 0))
        ds.append(r['sec'] - o['sec'])
    w = mci(dw)
    t = mci(ds)
    out.append('| %s − %s | %d | %+.1f ± %.1f | %+.2f ± %.2f |' % (a, b, len(dw), 100 * w[0], 100 * w[1], t[0], t[1]))

# per chapter
out.append('\n## By chapter (win % / mean s / HL hit % / HL share %)\n')
chs = sorted({r['ch'] for r in rows}, key=lambda c: [r['ch'] for r in rows].index(c))
out.append('| chapter | ' + ' | '.join(SETUPS) + ' |\n|' + '---|' * (len(SETUPS) + 1))
for ch in chs:
    cells_ = []
    for s in SETUPS:
        a = agg([r for r in by_setup[s] if r['ch'] == ch])
        cells_.append('%.0f / %.0f / %.0f / %.0f' % (a['win'][0], a['sec'][0], a['hit'][0], a['share']))
    out.append('| %s | %s |' % (ch, ' | '.join(cells_)))

# per archetype
out.append('\n## By boss archetype (measured in BASE: multi-cell = footprint >= 2; mobile = top third steps/min; rooted = top third time busy; mixed = rest)\n')
counts = defaultdict(int)
for k, v in arche.items():
    counts[v] += 1
out.append('Encounters per archetype: ' + ', '.join('%s %d' % (k, v) for k, v in sorted(counts.items())) +
           ' (thresholds: mobile >= %.1f steps/min, rooted >= %.0f%% busy)\n' % (m67, 100 * b67))
for arc in ['mobile', 'rooted', 'mixed', 'multi-cell']:
    out.append('### %s\n' % arc)
    out.append(HEAD)
    for s in SETUPS:
        rs = [r for r in by_setup[s] if arche.get((r['ch'], r['match'])) == arc]
        if rs:
            out.append(line(s, agg(rs)))
    out.append('')

# field-size distribution
out.append('\n## Damage per HIT by armed-cell count n (mean, hits)\n')
out.append('| set-up | ' + ' | '.join('n=%d' % n for n in range(2, 9)) + ' |\n|' + '---|' * 8)
for s in SETUPS[1:]:
    dd = defaultdict(list)
    for r in by_setup[s]:
        for n, h, d in zip(r['ln'], r['lh'], r['ld']):
            if h:
                dd[n].append(d)
    out.append('| %s | %s |' % (s, ' | '.join('%.1f (%d)' % (sum(dd[n]) / len(dd[n]), len(dd[n])) if dd[n] else '—' for n in range(2, 9))))

out.append('\n## Blasts by armed-cell count n and hit rate per n\n')
out.append('| set-up | ' + ' | '.join('n=%d' % n for n in range(2, 9)) + ' |\n|' + '---|' * 8)
for s in SETUPS[1:]:
    tot = defaultdict(int)
    hit = defaultdict(int)
    for r in by_setup[s]:
        for n, h in zip(r['ln'], r['lh']):
            tot[n] += 1
            hit[n] += h
    out.append('| %s | %s |' % (s, ' | '.join('%d (%.0f%%)' % (tot[n], 100 * hit[n] / tot[n]) if tot[n] else '—' for n in range(2, 9))))

# occupied cells on hits
out.append('\n## Occupied armed cells on hits (k) — share of hits\n')
for s in SETUPS[1:]:
    ks = defaultdict(int)
    tot = 0
    for r in by_setup[s]:
        for k, h in zip(r['lk'], r['lh']):
            if h:
                ks[k] += 1
                tot += 1
    out.append('- %s: ' % s + ', '.join('k=%d %.0f%%' % (k, 100 * v / max(tot, 1)) for k, v in sorted(ks.items())) + ' (hits %d)' % tot)

# counterfactual from the A runs
out.append('\n## Counterfactual (recomputed from the Model A runs) vs full-match measured\n')
for bot in ['baseline', 'predict']:
    rs = by_setup[bot + '/A']
    tot = {'A': 0, 'A4': 0, 'C': 0}
    hits = 0
    for r in rs:
        for n, h, d in zip(r['ln'], r['lh'], r['ld']):
            if not h:
                continue
            hits += 1
            tot['A'] += d
            tot['A4'] += d * min(n, 4) / n
            tot['C'] += d * min(n, r['fp'] + 1) / n
    meas = {m: agg(by_setup[bot + '/' + m])['dmg_hit'] for m in ['A', 'A4', 'C']}
    out.append('- %s bot: counterfactual dmg/hit A %.1f, A4 %.1f, C %.1f | measured in full matches A %.1f, A4 %.1f, C %.1f' %
               (bot, tot['A'] / max(hits, 1), tot['A4'] / max(hits, 1), tot['C'] / max(hits, 1), meas['A'], meas['A4'], meas['C']))

print('\n'.join(out))
print('\nrows=%d' % len(rows))
