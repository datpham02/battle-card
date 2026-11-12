# World Map v2 — B1 full balance validation (5 characters × 2 seed sets), 2026-11-12

User brief: "Full Balance Validation — B1 (5 Characters × 2 Seed Sets)". Validation only: no gameplay parameter was
changed during the run; nothing committed, pushed or deployed; the C evidence in `balance/` was read, not modified.

## 0. Verdict

**PASS on the existing project criteria** — with the caveat of §8 (the bot evades warned vents, so this says
nothing about human fairness or fun).

| Criterion (existing) | Threshold | C | B1 | Result |
|---|---|---|---|---|
| Pooled run-level win rate (10 combos, 700 runs each) | within ±10 pts | 13.3 % | 13.3 % | **+0.0 pts — PASS** |
| Average run duration (est. minutes, all runs) | within ±2 % | 33.15 | 32.77 | **−1.1 % — PASS** (won-run mean −0.5 %, won median −0.8 %, lost median −1.3 %) |
| Per-character win rate reported separately | — | see §2 | — | every character within ±2.8 pts; no character hidden by the pool |
| Hellfire clear rate (runs entering floor 2) | report + investigate | 85.4 % | 84.6 % | −0.8 pts (102 → 108 deaths of 700); direction consistent with B1, size inside seed noise — §6 |
| Economy / reward vs C | report | gold 622.8 / relics 10.62 | 615.9 / 10.54 | −1.1 % / −0.7 %; no unintended change — §4 |

No new threshold was invented; where none exists the difference is reported with its size and likely cause.

## 1. Configuration and commands

Configuration under test (`assets/data/region_rules.json`, read back by the run script into the log): warden hook
`vent_surge {interval_sec 7.0, first_delay_sec 10.0}`, heat-4 row `vent_sec 2.5`, rest −2, shop −1; peril
`modifier_slots [0, 1, 1]` (`route_archetypes.json`, identical to `variants/route_archetypes_C.json` that the C runs
named explicitly). Nothing else differs from the C configuration.

Script: `production/qa/evidence/world-map-v2/b1-balance/run-b1-balance.sh` (10 jobs, 8 in parallel, 15:46 → 16:18,
all `exit=0`; log `b1-balance/run-b1-balance.log`). Each job:

```
godot --headless --path . -s res://tools/balance/deck_sim.gd -- --run=v6 --region-pick=order --seeds=70
  --policies=build --shop-policy=greedy --event-policy=risky --relic-policy=pick --tables=v6 --final=on
  --route-policy=value --seed-offset=<2001|3001> --characters=<char>
```

Baseline C (same seeds, same flags, from the balance pass and its replicate): set 2001 = `balance/C-full-value-<char>.txt`
(run with `--route-archetypes=…/route_archetypes_C.json`, the file now shipped), set 3001 =
`balance/rep-C-full-value-<char>.txt`. Seeds: 2002..2071 and 3002..3071 — the same 70 seeds per character for C
and B1, so maps, routes, decks and offers are paired (the warden heat distribution is byte-identical between the
two, §5, which confirms the pairing). Aggregation: `b1-balance/aggregate-b1.py` → `b1-balance/aggregate-b1.md`
(read-only, Markdown). No run failed; no rerun was needed; no `SCRIPT ERROR` / `unknown match` in any raw file.

## 2. Character × seed set — run win %

| character | set 2001 (C → B1) | set 3001 (C → B1) | mean C | mean B1 | diff |
|---|---|---|---|---|---|
| kiem_si | 25.7 → 24.3 (−1.4) | 12.9 → 12.9 (0.0) | 19.3 | 18.6 | −0.7 |
| phap_su | 7.1 → 14.3 (+7.2) | 24.3 → 18.6 (−5.7) | 15.7 | 16.5 | +0.8 |
| sat_thu | 11.4 → 8.6 (−2.8) | 7.1 → 7.1 (0.0) | 9.2 | 7.8 | −1.4 |
| tho_san | 14.3 → 11.4 (−2.9) | 7.1 → 7.1 (0.0) | 10.7 | 9.2 | −1.4 |
| giao_si | 8.6 → 11.4 (+2.8) | 14.3 → 17.1 (+2.8) | 11.4 | 14.2 | +2.8 |
| **pooled** | 13.4 → 14.0 | 13.1 → 12.6 | **13.3** | **13.3** | **0.0** |

Death rate = 100 − win rate: pooled 86.7 % under both. Per-character differences (−1.4 … +2.8 pts on 140 runs) are
below the ±10-pt swing the same character shows between the two seed sets of the *same* variant (phap_su C: 7.1 vs
24.3), i.e. seed noise. Set 2001 moves +0.6, set 3001 −0.5: no seed-set effect.

## 3. Run-level metrics, pooled (mean of the 10 per-combo values)

| metric | C | B1 | diff | diff % |
|---|---|---|---|---|
| run win % | 13.3 | 13.3 | 0.0 | 0.0 % |
| hellfire clear % (runs entering floor 2) | 85.4 | 84.6 | −0.8 | −1.0 % |
| hellfire match win % (every hellfire fight) | 96.8 | 96.6 | −0.2 | −0.2 % |
| est. minutes, all runs | 33.15 | 32.77 | −0.38 | −1.1 % |
| est. minutes, won runs (mean) | 49.35 | 49.12 | −0.23 | −0.5 % |
| run minutes, won median / lost median | 51.89 / 30.80 | 51.50 / 30.40 | −0.39 / −0.40 | −0.8 % / −1.3 % |
| hits taken / run (all) · / won run | 32.11 · 44.62 | 31.73 · 44.33 | −0.38 · −0.29 | −1.2 % · −0.6 % |
| matches / run | 20.18 | 19.96 | −0.22 | −1.1 % |
| HP % entering floor 2 · after the hellfire warden (before heal) | 99.4 · 49.5 | 99.4 · 49.7 | 0.0 · +0.2 | — |
| hellfire: HP lost in fights per route (pts of max) | 63.3 | 63.4 | +0.1 | +0.1 % |
| hellfire: net HP lost per route | 43.0 | 42.9 | −0.1 | −0.2 % |

"Average HP lost per fight" is not an instrumented column; the proxies are hits taken per run (−1.2 %), hellfire HP
lost in fights per route (+0.1 %) and the hellfire match win rate (−0.2 pts). None moves.

## 4. Economy and rewards

| metric | C | B1 | diff |
|---|---|---|---|
| gold earned / run (all runs) | 622.8 | 615.9 | −6.9 (−1.1 %) |
| gold spent / run (all runs) | 335.6 | 332.2 | −3.4 (−1.0 %) |
| gold earned / won run | 1019.2 | 1023.6 | +4.4 (+0.4 %) |
| relics / run (acquired) | 10.62 | 10.54 | −0.08 (−0.7 %) |
| deck size at the end | 11.38 | 11.36 | −0.03 |
| hellfire ROUTE relics (mean of runs by lane taken) | 2.51 | 2.51 | 0.00 |
| hellfire objective met per route | 0.17 | 0.17 | 0.00 |
| ROUTE NV (gold + 60 relics − 1.6 HP, same ROUTE basis for both) | 566.0 | 558.2 | −7.8 (−1.4 %) |

Relics *offered* vs *taken* per route (ROUTE2 "relic rows offered / taken") are unchanged at the lane level (§6:
identical relics per lane). The economy moves by about −1 % across the board together with "matches / run" (−1.1 %):
runs are very slightly shorter, so they collect very slightly less — a consequence of the 6 extra floor-2 deaths, not
a reward change (gold per *won* run is +0.4 %). No unintended economy change.

## 5. Heat and warden metrics

Warden arrival heat (hellfire, `value` policy, 664 wardens reached per variant, all characters and sets):

| variant | heat 0 | heat 1 | heat 2 | heat 3 | heat 4 | heat 3–4 % | mean |
|---|---|---|---|---|---|---|---|
| C | 232 (34.9 %) | 148 (22.3 %) | 99 (14.9 %) | 102 (15.4 %) | 83 (12.5 %) | 27.9 | 1.48 |
| B1 | 232 (34.9 %) | 148 (22.3 %) | 99 (14.9 %) | 102 (15.4 %) | 83 (12.5 %) | 27.9 | 1.48 |

Identical by construction: B1 changes the warden fight, not the route or the rest/shop decay, so the same seeds
arrive at the same heat. The hook therefore fired on the same 185 wardens (27.9 %) under both; what differed inside
those fights is the 7 s surge and, on the 83 heat-4 wardens, the 2.5 s burn.

Warden encounter results by heat level: the ROUTE rows give clear % per lane (§6), not per arrival heat — the sim
does not print warden win % keyed by heat. Available proxy: the per-lane clear rates (peril, the lane with the most
heat-3–4 arrivals, 82.8 → 81.5 %; elite 89.5 → 89.5; treasure 97.2 → 97.2; safe 100 → 100). Vent instrumentation:
`TileHazards.stats()` counts vent ticks / damage per match, but `deck_sim` does not print them; the only vent-related
output is the hook-fired column of ROUTE3 (= heat ≥ 3, unchanged) — **vent damage taken by the bot is not measured
and is ~0 by construction** (it leaves warned cells after 0.4 s and erupting cells at once).

## 6. Hellfire clear rate — the one metric that moved, investigated

Deaths on floor 2 (of 70 runs per cell):

| character | set 2001 (C → B1) | set 3001 (C → B1) |
|---|---|---|
| kiem_si | 0 → 3 | 2 → 2 |
| phap_su | 10 → 8 | 6 → 8 |
| sat_thu | 18 → 20 | 18 → 18 |
| tho_san | 10 → 13 | 12 → 11 |
| giao_si | 13 → 14 | 13 → 11 |
| **total** | 51 → 58 | 51 → 50 |

Pooled: 102 → 108 deaths of 700 (14.6 → 15.4 %, −0.8 pts clear). Five cells get worse, three better, two equal; the
per-character pooled change is −2.1 … +0.8 pts. Significance: the standard error of a clear rate near 85 % on 700
runs is ≈1.3 pts, so −0.8 is well inside one standard error; it is not a significant regression on the project's
scale (the balance pass treated < ~3 pts on 700 runs as noise). Likely cause of the direction, in order of
plausibility: (1) heat-4 fights (lane fights and the warden) keep cells burning 2.5 s instead of 2 s, so pieces on
vent cells are buried more often and more cells are blocked for placement; (2) the 7 s warden surge buries pieces more
often at heat ≥ 3; (3) RNG divergence once the combat patch differs. The bot's own HP loss in hellfire fights is flat
(+0.1 pt), consistent with it never standing in an eruption — the cost it pays is tempo and pieces, not burn damage.
Per lane (§7 of `aggregate-b1.md`): peril clear 82.8 → 81.5 (476 runs), elite / treasure / safe unchanged — the lane
with the most heat-3–4 wardens is the one that moved, which fits cause (1)–(2).

## 7. Raw outputs

`production/qa/evidence/world-map-v2/b1-balance/`: `B1-s{2001,3001}-full-value-{kiem_si,phap_su,sat_thu,tho_san,giao_si}.txt`
(10 raw deck_sim outputs), `run-b1-balance.sh`, `run-b1-balance.log`, `jobs.txt`, `aggregate-b1.py`,
`aggregate-b1.md` (every table above plus the per-lane table). Baseline C files listed in §1 (unmodified).

## 8. Limitations

- **The bot evades warned vents** (0.4 s reaction, leaves erupting cells at once). This run validates that B1 does
  not break the aggregate balance or any character for a player who always dodges; it cannot say whether the 7 s
  surge or the 2.5 s burn is fair or fun for a human. Human warden playtesting (`human-playtest-heat-decay-2026-11-12.md`,
  H2 / C3 / C4 on seed 27) remains a separate required step; its F2 note predates B1.
- "Warden encounter results by heat level" and "HP lost per fight" are not printed by the simulator; proxies are
  given in §3 and §5. Vent damage is not instrumented in `deck_sim` output.
- `value` policy almost never takes the safe (7 runs) or mystery (0) lanes, so those lanes are unmeasured here; the
  lane probes of the heat-decay experiment cover them under C only.
- Two seed sets of 70 per character: per-character differences below ~8 pts and pooled differences below ~3 pts are
  noise; the criteria above are met by margins far wider than that noise, the hellfire change is inside it.
- Run duration is the simulator's estimate (node overhead 25 s assumption + simulated match time), the same
  estimator for both variants.

## 9. Recommendation

B1 can stay in the data for the human playtest: on the simulator it is balance-neutral at the run level (win rate
identical, duration −1.1 %, economy −1 %), every character within ±3 pts, and the only directional change is a
−0.8-pt hellfire clear that is inside noise and explained by longer burns at heat 4. Nothing here authorises calling
B1 "validated" — that needs the playtest. No tuning was done; none is proposed from these numbers.

No commit, push, deploy, reset, stash, checkout or branch change was run; all earlier uncommitted work is intact.
