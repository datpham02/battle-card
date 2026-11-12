# World Map v2 — Step 0: seven-floor v1 baseline in the fixed climb order (2026-11-11)

Scope authorised by the user: tooling change to `deck_sim`, backward-compatibility check, the reproducible baseline,
report. No gameplay data, save format or gameplay behaviour was changed. HEAD `de6f88a` + the uncommitted tooling
edit below.

## 1. Files changed

| File | Change |
|---|---|
| `tools/balance/deck_sim.gd` | `REGION_PICKS` gains `"order"`; in the world loop `order` calls `WorldMapGen.floor_offer(_chapters.region_order(), pool, seed, f, path, choices)` (the game's own rule) and takes `offer[0]` without drawing the pick RNG; `random` and `first` keep their previous code path (`offer_for_floor` + the same pick expression). Header line updated. Parse check: ok. |
| `tools/balance/README.md` | the `--region-pick` row documents `order` and states that `random` / `first` play a region order the shipped game never does. |
| `production/qa/evidence/world-map-v2/*` | this report, the raw outputs, the run log (new files). |

`--route-policy=` was **not** added: it needs lanes to act on and nothing in v1 has them; it belongs to step 2.

## 2. Exact commands

Reference (backward-compatibility) command, run before the edit, after the edit, and once more after the edit:

```
GODOT=C:/Users/ADMIN/AppData/Local/Microsoft/WinGet/Links/godot.exe
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --run=v6 --seeds=3 --characters=kiem_si
```

Baseline, one process per character, all five in parallel (12 logical CPUs), run twice (replicate A, replicate B):

```
$GODOT --headless --path . -s res://tools/balance/deck_sim.gd -- --run=v6 --region-pick=order --seeds=70 --seed-offset=2001 \
  --characters=<kiem_si|phap_su|sat_thu|tho_san|giao_si> --policies=build --shop-policy=greedy --event-policy=risky \
  --relic-policy=pick --tables=v6 --final=on > production/qa/evidence/world-map-v2/baseline-7floor-v1-raw-<character>[-replicateB].txt 2>&1
```

Configuration in effect (from the raw headers): `world.floors 7`, `region_order` fixed, 7 columns per region, floor
scaling rows 1..7 + final as shipped, `cleared_bosses = 1` (sim constant), dodge 0.85 (TD-006 default), node overhead
25 s (a sim assumption), start gold 20, shop greedy, event risky, relic pick, pieces off (sim default), mercy none,
run seeds 2002..2071. Wall time per character 641–1016 s.

Raw evidence: `baseline-7floor-v1-raw-<character>.txt` (A), `baseline-7floor-v1-raw-<character>-replicateB.txt` (B),
`baseline-7floor-v1-runlog.txt` (exit codes and seconds). All exit codes 0.

## 3. Backward compatibility — result and a discrepancy

**Region picks**: identical before and after the edit in the reference command (same region on every floor of every
run; `random` still draws from `offer_for_floor` with the same RNG). **Climb order with `order`**: every raw file's
`WORLD REGIONS` table shows floor 1 ch1, 2 hellfire, 3 desert, 4 swamp, 5 ch2, 6 ch3, 7 sky_isles for every character,
which is `world.region_order`.

**Byte-identical output could not be demonstrated**, and the reason is a pre-existing property of the tool, not the
edit: running the *unchanged* post-edit code twice (`ref_after.txt` vs `ref_after2.txt`, same command) gives different
match outcomes from floor 3 on. The simulator is **not deterministic run to run**. A confirmed source (read in code,
not fixed): `sim_core.gd` builds `SwingArbiter` without setting `zone_rng` (`sim_core.gd:925`; grep finds no
`zone_rng` in `tools/balance`), so every thorn cast that scatters extra cells (`CutEffects.extra_thorn_cells`,
`cut_effects.gd:631-633`) falls back to a freshly **randomized** RNG; `CombatView` seeds it from the match seed
(`combat_view.gd:489-493`), the sim does not. The build policy takes thorn cards, so most runs hit this path. Other
`randomize()` fallbacks exist in combat classes when a seed is negative, but the sim passes seeds to those
(`sim_core.gd:845-972`); none was confirmed as a second source.

Consequence: "same output without the new flags" is supported by (a) the diff of the code change (the old branches are
textually unchanged) and (b) identical region picks, **not** by byte equality of outputs. The tool's own README
claim "so all three characters walk the same path on the same seed" still holds for *paths*, not for match results.

Recommendation (needs the user's OK; outside step 0): seed `arbiter.zone_rng` in `sim_core._setup` from
`match_seed + 3` exactly as `CombatView` does. It makes the sim reproducible, which the paired v1/v2 comparisons in
`06` assume. Until then every comparison must use replicate pairs and treat differences below the A/B noise as noise.

## 4. Run-to-run noise (replicate A vs replicate B, same seeds, same code)

| Character | Run win % A / B | Wins A / B (of 70) | Won-run minutes (median) A / B | Gold earned per run (mean) A / B | Relics at end (mean) A / B |
|---|---|---|---|---|---|
| kiem_si | 18.6 / 22.9 | 13 / 16 | 51.9 / 50.4 | 745 / 767 | 12.43 / 12.60 |
| phap_su | 18.6 / 22.9 | 13 / 16 | 49.4 / 49.7 | 706 / 730 | 11.23 / 11.44 |
| sat_thu | 11.4 / 10.0 | 8 / 7 | 47.1 / 47.9 | 516 / 511 | 9.61 / 9.57 |
| tho_san | 18.6 / 15.7 | 13 / 11 | 51.2 / 52.6 | 574 / 590 | 10.51 / 10.73 |
| giao_si | 11.4 / 10.0 | 8 / 7 | 54.4 / 53.3 | 607 / 601 | 11.17 / 11.10 |

Noise to carry into every later reading: **run win % ± ~4 points** (up to 3 wins of 70 flip), won-run minutes ± ~1.5,
gold ± ~3 %, relics ± 0.2, between two runs of the identical command. The 5-floor evidence quoted "± 5–6 points per
70-seed cell" as *seed* noise; this is *replicate* noise on top of it.

## 5. Baseline metrics (replicate A; B in the raw files)

### 5.1 Run level (`RUN` / `RUN DETAIL` / `WORLD VERDICT` lines)

| Character | Run win % (wins/70) | Final reached → won | Won-run minutes (median, est.) | Boss hits / won run | Gold earned / spent, all runs | Gold at the final (median) | Relics at end | Deck size |
|---|---|---|---|---|---|---|---|---|
| kiem_si | 18.6 (13) | 16 → 13 (81 %) | 51.9 | 48.7 | 745 / 419 | 399 | 12.4 | 12.7 |
| phap_su | 18.6 (13) | 14 → 13 (93 %) | 49.4 | 38.9 | 706 / 406 | 356 | 11.2 | 12.0 |
| sat_thu | 11.4 (8) | 10 → 8 (80 %) | 47.1 | 35.3 | 516 / 304 | 443 | 9.6 | 10.3 |
| tho_san | 18.6 (13) | 13 → 13 (100 %) | 51.2 | 41.4 | 574 / 350 | 299 | 10.5 | 10.6 |
| giao_si | 11.4 (8) | 10 → 8 (80 %) | 54.4 | 45.3 | 607 / 356 | 362 | 11.2 | 12.1 |

Mean run win 15.7 % (A) / 16.3 % (B). The sim's own verdict lines: "run win … TOO HARD" for four characters against
its 20–40 % target (phap_su's target band is 10–100 in the tool); minutes 44.6–51.1 against 40–50 ("TOO LONG" for
giao_si). For comparison, the recorded **5-floor** run (2026-10-27, different region draw) had 27–47 % wins and 27–30
won-run minutes; the 7-floor climb is both harder and longer, as its two extra floors imply.

### 5.2 Survival by floor (`WORLD FLOORS`: alive after the floor, % of 70 runs) and deaths by floor

| Character | f1 | f2 | f3 | f4 | f5 | f6 | f7 | after final | deaths f1..f7, final |
|---|---|---|---|---|---|---|---|---|---|
| kiem_si | 100 | 97.1 | 95.7 | 81.4 | 68.6 | 48.6 | 22.9 | 18.6 | 0/2/1/10/9/14/18, 3 |
| phap_su | 100 | 98.6 | 94.3 | 65.7 | 51.4 | 38.6 | 20.0 | 18.6 | 0/1/3/20/10/9/13, 1 |
| sat_thu | 100 | 77.1 | 72.9 | 47.1 | 32.9 | 22.9 | 14.3 | 11.4 | 0/16/3/18/10/7/6, 2 |
| tho_san | 100 | 92.9 | 90.0 | 50.0 | 38.6 | 22.9 | 18.6 | 18.6 | 0/5/2/28/8/11/3, 0 |
| giao_si | 100 | 94.3 | 90.0 | 62.9 | 44.3 | 27.1 | 14.3 | 11.4 | 0/4/3/19/13/12/9, 2 |

Two cliffs: **floor 4 (swamp)** kills 10–28 of 70 (mostly `toad_matriarch`, `WORLD DEATHS … f4/boss`), and **floor 2
(hellfire)** kills 16 of sat_thu's 70 (14 at `inferno_lord`). Floor 7 (sky_isles) is the other hard wall for kiem_si /
phap_su (`storm_dragon`).

### 5.3 Region clear % by assigned floor (`WORLD REGIONS`: cleared / entered)

| Floor → region | kiem_si | phap_su | sat_thu | tho_san | giao_si |
|---|---|---|---|---|---|
| 1 ch1 | 100 (70/70) | 100 | 100 | 100 | 100 |
| 2 hellfire | 97.1 (68/70) | 98.6 | **77.1** (54/70) | 92.9 | 94.3 |
| 3 desert | 98.5 | 95.7 | 94.4 | 96.9 | 95.5 |
| 4 swamp | 85.1 | **69.7** | **64.7** | **55.6** | **69.8** |
| 5 ch2 | 84.2 | 78.3 | 69.7 | 77.1 | 70.5 |
| 6 ch3 | 70.8 | 75.0 | 69.6 | 59.3 | 61.3 |
| 7 sky_isles | 47.1 (16/34) | 51.9 | 62.5 | 81.3 | 52.6 |

### 5.4 Match win % by floor (`REGION x FLOOR CHECK`, every match played there, n in brackets)

kiem_si: f1 100 (232) · f2 99.3 (294) · f3 99.7 (287) · f4 96.4 (279) · f5 96.2 (234) · f6 92.3 (183) · f7 87.1 (139).
The other characters sit within 94–100 on f1–f3 and 88–96 on f4–f7 (raw files). Hellfire floor 2 (the slice): match
win 94.5–99.7 % across characters; its *region* clear is 77–99 % because the warden is where the losses land.

### 5.5 Economy (`WORLD ECONOMY` / `ECONOMY TARGETS`)

Gold earned per run (mean, all runs): 516–745; per won run ≈ 960–1050; spent 304–419; shops per run 3.3; items per
run 5.8–8.2; the tool's own targets (350–450 earned, 4–6 items, < 100 left in won runs) are **MISS** for every
character except sat_thu's item count — the 7-floor run earns and holds far more gold than the 5-floor targets
assumed. Relic lift check: **FAIL** (`tam_huong` +33 pts on kiem_si, n small) — a bot-policy artefact (TD-037).

## 6. Failed or incomplete measurements

- **Reproducibility**: the tool is not run-to-run deterministic (§3); every number above has the replicate noise of §4.
- **`--route-policy=`** not implemented (no lanes in v1).
- **Per-enemy loss rates and HP loss per enemy id** (needed for the O-expert oracle in `06` §3.3) are not in the
  tool's tables; the raw files hold only per-floor / per-region aggregates. Extracting them needs a tool addition.
- **HP at each warden entry** is in `WORLD FLOORS` as "mean HP % entering" per floor, not per warden fight; usable as a
  proxy only.
- **Onboarding** (`cleared_bosses = 0`) not measured; the tool runs the main set at `cleared_bosses = 1`.
- **Dodge sweep** (`--dodge=0.7,0.85,0.95`) not run in step 0 (time); the 5-floor evidence showed ± 10–15 points.

## 8. Phase 0 completion — the deterministic (seeded) baseline, canonical for every v1/v2 comparison (2026-11-12)

The user approved seeding the simulator. Two seeds were needed, both tool code (`tools/balance/sim_core.gd`, `_setup`):

| RNG | Why it drifted | Seed chosen | Reason for the value |
|---|---|---|---|
| `SwingArbiter.zone_rng` (Vây Bắt extra thorn cells) | never set by the sim → `CutEffects.extra_thorn_cells` fell back to `randomize()` | `match_seed + 3` | exactly what `CombatView` does with `drops_seed + 3` (`combat_view.gd:489-493`); the sim's `match_seed` is its `drops_seed` (drops = seed, boss +1, boss pieces +2, pattern +4), so +3 is the same offset and a stream nothing else uses |
| `CutFlow.rng` (the timeout card pick) | `RandomNumberGenerator.new()` at field init is randomly seeded; `CombatView` leaves it random, only tests seed it (`cut_flow.gd:33-34`) | `match_seed + 5` | the next free offset; found only after the first seed still left runs different |

A negative `match_seed` keeps the randomized fallback (never happens: `deck_sim` masks every seed with `SEED_MASK`).
No gameplay file was touched: `CombatView`, `SwingArbiter`, `CutFlow`, `CutEffects` unchanged; the game itself still
leaves `CutFlow.rng` random (a finding, not fixed).

**Determinism checks** (3-seed reference command, `scratchpad/step0/det2_*.txt`, `runtime:` line excluded):

| Mode | run 1 vs run 2 | Region picks vs before the change |
|---|---|---|
| no flag (default `random`) | IDENTICAL | identical to `ref_before.txt` (pre-change code) |
| no flag vs `--region-pick=random` | IDENTICAL | — |
| `--region-pick=first` | IDENTICAL | identical to the pre-seed `first` run |
| `--region-pick=order` | IDENTICAL | ch1, hellfire, desert, swamp, ch2, ch3, sky_isles |
| full 70-seed kiem_si baseline repeated | see `baseline-7floor-v1-runlog.txt` "seeded-repeat" and §9 | — |

**Baseline (seeded; raw `baseline-7floor-v1-raw-<character>-seeded.txt`; same command as §2, wall 649–980 s):**

| Character | Run win % (wins/70) | Final reached → won | Won-run minutes (median) | Boss hits / won run | Gold earned / spent (all runs) | Gold at the final (median) | Relics at end | Deck size |
|---|---|---|---|---|---|---|---|---|
| kiem_si | 21.4 (15) | 17 → 15 | 50.8 | 49.0 | 745 / 417 | 406 | 12.4 | 12.6 |
| phap_su | 20.0 (14) | 14 → 14 | 50.9 | 42.6 | 716 / 414 | 311 | 11.3 | 12.0 |
| sat_thu | 15.7 (11) | 13 → 11 | 46.7 | 35.7 | 530 / 317 | 416 | 9.7 | 10.6 |
| tho_san | 12.9 (9) | 9 → 9 | 51.5 | 40.6 | 566 / 344 | 326 | 10.5 | 10.6 |
| giao_si | 10.0 (7) | 10 → 7 | 51.9 | 42.9 | 600 / 347 | 295 | 11.1 | 12.0 |

Mean run win 16.0 % (A 15.7, B 16.3): the seeded numbers sit inside the A/B replicate noise of §4, as expected — the
seeds remove run-to-run drift, they do not move the distribution.

Region clear % by assigned floor (cleared / entered), seeded:

| Floor → region | kiem_si | phap_su | sat_thu | tho_san | giao_si |
|---|---|---|---|---|---|
| 1 ch1 | 100 (70/70) | 100 | 100 | 100 | 100 |
| 2 hellfire | 97.1 (68/70) | 98.6 (69/70) | **77.1** (54/70) | 92.9 (65/70) | 94.3 (66/70) |
| 3 desert | 100 (68/68) | 97.1 | 94.4 | 95.4 | 93.9 |
| 4 swamp | 86.8 (59/68) | **71.6** | **68.6** | **58.1** | **67.7** |
| 5 ch2 | 79.7 | 70.8 | 71.4 | 72.2 | 66.7 |
| 6 ch3 | 72.3 | 82.4 | 76.0 | 65.4 | 71.4 |
| 7 sky_isles | 50.0 (17/34) | 50.0 | 68.4 | 52.9 | 50.0 |

The sim's own verdicts: run win "TOO HARD" (< 20 %) for sat_thu, tho_san, giao_si; PASS for kiem_si (21.4) and
phap_su; minutes 44.7–49.4 PASS; economy targets MISS (as in §5.5). These are the **canonical v1 numbers** for the
Hellfire floor-2 paired comparison; the A/B files stay as the pre-seed history.

## 7. Is the baseline suitable for comparison with World Map v2?

**Yes, with two conditions.**
1. Comparisons must be **replicate-aware**: either seed `zone_rng` in the sim first (recommended, one line, needs the
   user's OK) so A == B byte-for-byte, or run every v1 and v2 cell as replicate pairs and report differences against
   the §4 noise. The paired design in `06` §6 assumed determinism; it must be amended either way.
2. It is a **bot baseline** (dodge 0.85 unanchored, static shop/relic policies): a relative yardstick for v1 vs v2
   under the same bot, never an absolute difficulty claim.

With those, the baseline gives what the plan needs: run win %, won-run minutes, gold, relics, survival by floor and
region clear % on the real climb order, on a fixed seed set (2002..2071) that the v2 Hellfire run can reuse floor by
floor. The Hellfire floor-2 cell in particular is well populated (70 entries per character, 292–294 matches).
