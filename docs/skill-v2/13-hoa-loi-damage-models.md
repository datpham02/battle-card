# Skill v2 — Hỏa Lôi damage-model evaluation (A vs A4 vs C)

**Date:** 2026-11-09 · **Status:** evaluation done, recommendation awaiting your approval. **The game still runs
Model A**: no change to `cards.json`, the damage rule or any other card. Audio A1 not started. Nothing committed.
Raw data and the full tables: `production/qa/evidence/skill-v2-hoa-loi/damage-models/`.

## 1. Method

| Item | Choice |
|---|---|
| Matches | every encounter of all 8 chapters (73 encounters: ch1 16, ch2 10, ch3 10, an_dai 1, swamp 9, desert 9, hellfire 9, sky_isles 9) |
| Seeds | 20 matched seeds per encounter → **1,460 complete matches per set-up, 10,220 in total**; every set-up plays the same (encounter, seed) pairs |
| Hero / deck | Fire Mage, level-1 starter deck (`kiem_khi, hoa_xa, hoa_tinh ×2, hoa_tran, bang_phong`); HL set-ups add 2 × `hoa_loi`; no relics |
| Set-ups | BASE (no Hỏa Lôi) · {baseline bot, predictive bot} × {A, A4, C} |
| Models (evaluation seam only) | **A**: every armed cell counts (production) · **A4**: at most 4 cells count · **C**: at most boss footprint + 1 cells count |
| How the model is changed | `SwingArbiter.armed_damage_cells_fn`, an evaluation-only seam, unset in the game (tested: `damage_model_seam_test`) |
| Baseline bot | the existing deck_sim bot (aims at the boss, values a fuse at 50 % landing) |
| Predictive bot | evaluation-only `bot["fuse_policy"] = "predict"`: while Hỏa Lôi is ready, its placement covers the boss's open exits (+60 each) and its planned destination (+200); the card choice estimates the hit chance (rooted through cast + fuse → 0.9; all reachable cells covered → 0.85; otherwise ¼ of the covered share, +0.2 if the destination is covered) and **skips** Hỏa Lôi below 0.4 |
| Uncertainty | win rate: Wilson 95 % CI; means: ± 1.96 · sd / √n; differences: paired on (encounter, seed) |
| Boss archetypes | measured in BASE, not hand-picked: **multi-cell** footprint ≥ 2 (2 encounters); **mobile** top third steps/min (≥ 65.9; 24 encounters); **rooted** top third time busy (≥ 21 %; 14); **mixed** the rest (33) |
| Burn | boss burn ticks on cells a Hỏa Lôi blast lit, until they burn out |

## 2. Side-by-side results (all chapters, n = 1,460 each)

| Set-up | Win % [95 % CI] | Mean s ± CI | HL casts / match | HL hit % [CI] | HL share of dmg (hit + burn) | Burn share | Dmg / cast | Dmg / hit | Armed cells / blast | Boss-occupied cells / hit | Casts while boss busy |
|---|---|---|---|---|---|---|---|---|---|---|---|
| BASE | 97.4 [96.4–98.1] | 55.2 ± 1.7 | — | — | — | — | — | — | — | — | — |
| baseline / A | 97.5 [96.6–98.2] | 54.4 ± 1.7 | 1.65 | 28.2 [26.5–30.1] | 12.3 % | 1.3 % | 10.0 | 35.6 | 2.90 | 1.16 | 30 % |
| baseline / A4 | 97.4 [96.4–98.1] | 54.5 ± 1.7 | 1.64 | 28.6 [26.8–30.5] | 11.7 % | 1.2 % | 9.4 | 33.2 | 2.91 | 1.16 | 30 % |
| baseline / C | 97.2 [96.2–97.9] | 55.4 ± 1.7 | 1.68 | 28.5 [26.7–30.3] | 9.3 % | 1.3 % | 7.1 | 25.1 | 2.90 | 1.16 | 30 % |
| predict / A | 98.1 [97.2–98.7] | **49.0 ± 1.6** | 2.52 | **56.1** [54.5–57.7] | **49.8 %** | 3.0 % | 26.4 | 47.3 | 3.70 | 1.10 | 29 % |
| predict / A4 | 97.7 [96.8–98.4] | 50.6 ± 1.7 | 2.59 | 56.3 [54.7–57.9] | 45.4 % | 3.1 % | 23.5 | 41.9 | 3.69 | 1.10 | 29 % |
| predict / C | 96.8 [95.8–97.6] | 58.4 ± 1.8 | 2.96 | 56.2 [54.7–57.6] | 31.0 % | 3.5 % | 13.6 | 24.4 | 3.69 | 1.09 | 28 % |

**Full-match paired differences (same encounter + seed):**

| Comparison | Δ win (pts) | Δ mean battle s |
|---|---|---|
| baseline/A − BASE | +0.1 ± 0.9 | −0.85 ± 1.23 (not significant) |
| baseline/C − baseline/A | −0.3 ± 0.4 | +1.07 ± 0.37 |
| predict/A − BASE | +0.7 ± 0.9 | **−6.19 ± 1.34** (−11 %) |
| predict/A4 − BASE | +0.3 ± 0.9 | −4.66 ± 1.32 |
| predict/C − BASE | −0.5 ± 1.0 | +3.22 ± 1.35 |
| predict/A4 − predict/A | −0.3 ± 0.4 | +1.54 ± 0.37 |
| predict/C − predict/A | −1.2 ± 0.6 | +9.42 ± 0.82 |
| predict/A − baseline/A | +0.5 ± 0.8 | −5.34 ± 1.33 |

**Win rate does not separate the models.** A level-1 Mage starter wins 87–100 % of every chapter with or without
Hỏa Lôi, and all win-rate differences sit inside ±1 point. The signals are battle duration (kill speed) and
Hỏa Lôi's damage share.

## 3. Boss archetypes (HL hit % / HL damage share / mean s; BASE mean s in brackets)

| Archetype | baseline A | baseline A4 | baseline C | predict A | predict A4 | predict C |
|---|---|---|---|---|---|---|
| Mobile (24 enc., n 480; BASE 71.0 s) | 13 % / 9 % / 72.3 | 13 % / 8 % / 72.4 | 14 % / 6 % / 73.8 | **40 %** / 55 % / 63.1 | 41 % / 50 % / 65.3 | 41 % / 30 % / 76.7 |
| Rooted (14 enc., n 280; BASE 51.1 s) | 60 % / 17 % / 48.6 | 60 % / 17 % / 48.8 | 59 % / 13 % / 50.0 | 74 % / 46 % / 44.6 | 74 % / 42 % / 45.9 | 76 % / 31 % / 52.0 |
| Mixed (33 enc., n 660; BASE 40.8 s) | 19 % / 8 % / 39.5 | 19 % / 7 % / 39.5 | 19 % / 5 % / 40.2 | 60 % / 56 % / 36.3 | 60 % / 50 % / 37.4 | 60 % / 31 % / 44.0 |
| Multi-cell (2 enc., n 40; BASE 131.5 s) | 85 % / 22 % / 124.5 | 85 % / 21 % / 125.5 | 85 % / 21 % / 124.7 | 92 % / 35 % / 121.3 | 91 % / 33 % / 123.4 | 92 % / 33 % / 122.1 |

Per chapter: see the summary file. The same pattern holds in every chapter. Hit rate falls in later chapters
(sky_isles: 12 % baseline, 27 % predictive) because they have more mobile bosses.

## 4. Field size (the "double reward")

| Model (predictive bot) | n = 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|
| hit rate | 29 % | 50 % | 68 % | 70 % | 71 % | 75 % |
| dmg / hit, **A** | 23.7 | 35.4 | 47.1 | 58.9 | 71.1 | 83.2 |
| dmg / hit, **A4** | 23.7 | 35.4 | 47.1 | 46.9 | 47.0 | 47.3 |
| dmg / hit, **C** | 23.7 | 24.1 | 24.1 | 24.5 | 25.9 | 33.5 |
| expected dmg / blast, A (hit × dmg) | 6.9 | 17.7 | 32.0 | 41.2 | 50.5 | 62.4 |
| expected dmg / blast, C | 6.9 | 12.1 | 16.4 | 17.2 | 18.4 | 25.1 |

- On **85–94 % of hits the boss stood on exactly one seal**. Under A, that single contact pays for the whole
  field (n = 5: 59 instead of 24).
- Bigger fields are both easier to hit (29 % → 70 %) **and** stronger under A, so expected damage per blast grows
  about 6× from 2 to 5 cells. Under C the field size buys coverage only.
- The predictive bot learned this: it grew its fields from 2.9 to 3.7 armed cells.
- Counterfactual vs full match: the damage per hit recomputed from the Model A runs matches the measured full-match
  value. Baseline bot: A4 33.3 vs 33.2, C 25.3 vs 25.1. Predictive bot: A4 41.9 vs 41.9, C 25.1 vs 24.4.
- What the counterfactual cannot show: under C the predictive bot casts Hỏa Lôi more often (2.96 vs 2.52 per
  match) and the battles get longer (+9.4 s). Only the full matches reveal this; see the caveat in §6.

## 5. Design assessment

| Question | A | A4 | C |
|---|---|---|---|
| Large field both easier to hit **and** stronger? | yes, about 6× per blast from 2 to 5 cells | until 4 cells, then capped | **no**: size buys coverage only (vs a 1-cell boss) |
| One-cell contact worth the whole field? | yes | up to 4 cells | no: at most footprint + 1 |
| Does predicting the boss pay? | yes (hit 28 → 56 %) | yes | **yes** (mobile 14 → 41 %) |
| Square variant worthwhile? | dominant (57.6 on any 1-cell boss) | 4 × 2.4 = 57.6, unchanged | **vs 1-cell boss** 2 × 2.4 = 28.8 at 1.8 s (a small premium); **vs 2×2 boss** 57.6, its intended use |
| Small Blocks disadvantaged? | yes: 2 cells 23.7 vs 5 cells 58.9 per hit | less | **no**: same per hit, they only cover less |
| Share of the Mage's damage, predictive play (roadmap cap 25 %) | **49.8 %** | 45.4 % | **31.0 %** (closest) |
| Speed vs no Hỏa Lôi, predictive play | −6.2 s (too strong) | −4.7 s | +3.2 s (undertuned at ×2.0, see §6) |
| Multi-cell bosses | full value | full value up to 4 | full value (footprint + 1 ≥ field) |

**Next to Trảm Địa and Ngàn Kiếm** (design values: Trảm Địa about 27 per cast every 6 s; Ngàn Kiếm about 36 per
cast every 10 s, rooted 1.48 s):
- Hỏa Lôi A in predictive hands: 26.4 per cast every 6 s, plus burn, plus area denial, with no root after the
  0.45 s cast. It is equal per cast and better in kind, and it carries half of the Mage's damage.
- Hỏa Lôi C: 13.6 per cast, which is too weak at the current ×2.0.

## 6. Recommendation

**Model C (cells counted = boss footprint + 1), with a follow-up tuning pass on `fuse_mult` before final balance.**

- **Why C:**
  - It is the only model that removes the double reward.
  - It keeps the card's identity: damage comes from where the boss is; Block size and shape only decide how well
    you trap it.
  - Prediction is still clearly rewarded: mobile-boss hit rate 14 → 41 %.
  - Small Blocks stay viable, and multi-cell bosses keep full value.
  - The square becomes a counter to large bosses instead of a default best choice.
  - A4 only trims fields of 5 or more cells. Predictive fields are mostly 3–5 cells, so A4 leaves Hỏa Lôi at 45 % of
    the Mage's damage.
- **Why not apply it alone:** at ×2.0, C makes Hỏa Lôi a weak pick (13.6 per cast). In the probe, predictive play
  with C was 3.2 s slower than having no Hỏa Lôi at all.
- **Caveat:** that slowdown is partly a bot artefact. The bot values Hỏa Lôi with the old full-field formula, so
  under C it over-picks the card (2.96 casts per match).
- **Proposed next step (needs your approval):** apply C, make the bot's value aware of the model, then probe
  `fuse_mult` at 2.4 / 2.8 / 3.2. The target is predictive-play damage share ≤ 25–30 % and battle time no slower
  than BASE.
- **Alternative if you want Block size to matter for damage:** A4. Its predictive-play share is 45 %, so it would
  need a lower multiplier.

## 7. Limits of this evaluation

- Bots, not humans. The predictive policy is a heuristic, not an optimal player. Human play is likely between the
  two bots.
- Win rate is saturated (a level-1 starter clears every chapter), so difficulty differences are invisible.
  A harder set-up (later floors' HP scaling, fewer heals) would be needed.
- Only 2 multi-cell encounters (n = 40 per set-up) and 1 an_dai encounter. Their CIs are wide.
- The square variant was not separated in the logs. It is assessed analytically from the formulas.
- Burn attribution: a cell lit by Hỏa Lôi and later re-lit by another fire card stays attributed to Hỏa Lôi until it
  burns out (small effect: burn share 1–3.5 %).
- Hit rate counts blasts. Two fields of one cast window are not independent, so the hit-rate CIs are slightly
  optimistic.

## 8. Focus-test stabilisation

- `GameFlow.set_focus_autopause_for_test(false)`: a test-only hook equal to the demos' `--no-autopause`.
  Production keeps the auto-pause, since the default is on.
- `focus_flow_test` uses the hook. Its assertions are unchanged.
- The new `tests/integration/ui/focus_autopause_test.gd` checks:
  - **production**: a focus loss pauses the battle;
  - **opt-out**: a focus loss does not pause it, and a pushed bag tap after a focus loss still starts placing.
- Results:
  - `focus_flow_test` in normal runs: 2/2 PASS.
  - With a **deliberate focus loss** injected before the tap (a temporary variant of the test): 2/2 PASS. The same
    variant failed 2/2 before the hook.
  - `focus_autopause_test`: 2/2 PASS (4 checks each).
  - The first run of the new test showed that the real window had already lost focus and auto-paused before the
    controlled check. The test now resumes explicitly before it, which confirms the diagnosis.
  - In the full suite the new test failed once. The suite runner passes `--no-autopause` to every windowed UI test,
    which switched off the production behaviour under test. The test now sets its mode after GameFlow has read its
    command line: 4/4 PASS with and without the runner's flag.

## 10. Regression

Full suite: **219 test files, 218 green on the run, plus the one fixed above**, which then passed 4/4 including the
runner's own flags:
- `skill_v2_golden_test` unchanged;
- all Trảm Địa, Ngàn Kiếm and Hỏa Lôi tests green;
- `damage_model_seam_test`, `sim_hoa_loi_test` and `focus_flow_test` green.

## 9. Files changed during this evaluation

| File | Change |
|---|---|
| `src/run/game_flow.gd` | `set_focus_autopause_for_test()` test hook (production default unchanged) |
| `tests/integration/ui/focus_flow_test.gd` | turns the auto-pause off for the test window (assertions unchanged) |
| `tests/integration/ui/focus_autopause_test.gd` | **new**: production auto-pause and opt-out checks |
| `src/combat/swing_arbiter.gd` | `armed_damage_cells_fn` evaluation seam (unset in the game = Model A) |
| `tools/balance/sim_core.gd` | evaluation-only: `fuse_policy` predict, `armed_damage_policy`, metrics `fz_casts`, `fz_burn_dmg`, `fz_skipped`, `b_steps`, `b_busy_t`, `b_total_t` |
| `tools/balance/hoa_loi_model_probe.gd` | **new**: the model × bot matrix probe (JSON lines) |
| `tests/unit/balance/damage_model_seam_test.gd` | **new**: A / A4 / C seam, Trảm Địa unaffected |
| `tests/unit/balance/sim_hoa_loi_test.gd` | +2 checks (default policy baseline, predictive estimate) |
| `docs/skill-v2/13-hoa-loi-damage-models.md` | this report |
| `docs/skill-v2/02-implementation-roadmap.md`, `production/session-state/active.md` | progress log |
| `production/qa/evidence/skill-v2-hoa-loi/damage-models/` | summary tables + raw JSON lines |

Not changed: `cards.json`, any card or damage rule in the game, Trảm Địa, Ngàn Kiếm, starter decks, rewards, assets.
