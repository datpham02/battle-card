# Skill v2 — Hỏa Lôi Model C: implementation and multiplier tuning

**Date:** 2026-11-09 · **Status:** Model C applied, as approved for the prototype. **The multiplier is still ×2.0 in
`cards.json`.** The recommended values below wait for your approval. Nothing committed.
Data: `production/qa/evidence/skill-v2-hoa-loi/multiplier-tuning/`.

## 1. Model C implementation (shared, data-driven)

| Change | File |
|---|---|
| New generic card field `damage_cells_rule` {mode: `all` (default) / `footprint` (min(cells, footprint + extra)) / `max`}, validated and reported; rejected on instant cards | `src/combat/cast_resolver.gd` (`DAMAGE_CELL_MODES`, `damage_cells()`, `_damage_cells_rule()`), `src/combat/skill_config.gd` |
| The scheduler reads the card's rule for every scheduled hit, on the target's footprint at the hit; one hit per unit per wave unchanged; the evaluation seam can still override it in probes | `src/combat/swing_arbiter.gd` |
| Hỏa Lôi: `"damage_cells_rule": {"mode": "footprint", "extra": 1}`; `fuse_mult` 2.0; square clause 1.8 s / ×2.4 (unchanged) | `assets/data/cards.json` |
| Square ratio form `shape_clause.fuse_mult_scale` (supported and tested, **not yet used in data**) so the square can follow a re-tuned base | `cast_resolver.gd` |
| Card text: "damage per cell (counting at most its size + {cells_extra} cells)", vi/en | `assets/i18n/strings.csv`, `src/run/card_text.gd` |
| **Sim parity fix:** the balance sim's own cast path now builds the same CastContext as CombatView. Before, no shape clause (square, Trảm Địa `line_h`, Ngàn Kiếm `branched`) ever applied in the sim; earlier balance probes under-counted those clauses | `tools/balance/sim_core.gd` |
| Model-aware evaluation bot. Its expected value = p_hit × the authoritative damage rule (`CastResolver.damage_cells` on the cells still armable, the boss footprint, the clause-aware multiplier and fuse), after the boss's damage multipliers and defense, plus the expected burn. It compares that against every other card in hand and skips Hỏa Lôi below p = 0.4. Selection metrics added (offered / chosen / what was cast instead) | `tools/balance/sim_core.gd` (`fuse_expected_value`, `fuse_hit_estimate`), evaluation only |
| Tuning probe (in-memory overrides; square = base × 1.2, fuse kept 1.8 s; optional `--hp-ratio`) | `tools/balance/hoa_loi_tuning_probe.gd` (new) |

**Tests updated explicitly (approved rule change):**
- `hoa_loi_test`:
  - square on a 1-cell boss 57.6 → 28.8;
  - 1 of 4 seals 48 → 24;
  - blast tick 48 → 24;
  - 2×2 boss stays 48.
  - 9 new Model C / square-ratio checks.
- `damage_model_seam_test`: unset now means the card's own rule.
- `sim_hoa_loi_test`: +3 checks. The sim square holds 1.8 s and gives 6 × 2 × 2.4 = 28.8, equal to the game.

**Mutations:**
- removing the sim CastContext → 2 fails;
- disabling the footprint rule → 3 fails.

**Unchanged:** Trảm Địa, Ngàn Kiếm and the golden test (still green); targeting, fuse timing, burn, cooldown, cast time,
boss movement and VFX. The HUD numbers use the event's damage, so they show the Model C value (checked in a test).

## 2. Method

- **Matches:** complete matches, all 8 chapters (73 encounters), 20 matched seeds each = **1,460 matches per set-up**.
  Main matrix: 11 set-ups (16,060 matches), plus a ×2.6 confirmation (2,920).
- **Harder scenario:** start at 35 % HP, 10 seeds, 4 set-ups (2,920 matches).
- **Uncertainty:** win rate as Wilson 95 % CI; means as ± 1.96 sd / √n; differences paired on (encounter, seed).
- **Bots:**
  - **baseline**: the existing policy, which values Hỏa Lôi at a 50 % landing with its old whole-field estimate;
  - **predict**: the model-aware policy described above.

## 3. Multiplier comparison (all chapters, n = 1,460 each; square = ×1.2)

| Set-up | Win % [CI] | Mean s | Δ s vs no HL (paired) | Casts / match | Chosen when offered | Hit % | HL share (hit + burn) | Burn share | Dmg / cast | Dmg / hit |
|---|---|---|---|---|---|---|---|---|---|---|
| No Hỏa Lôi | 97.3 [96.4–98.0] | 55.5 | — | — | — | — | — | — | — | — |
| predict ×1.6 | 97.5 | 56.5 | +1.03 ± 1.31 | 1.22 | 3 % | 34.7 | 7.8 % | 1.5 | 7.7 | 22.3 |
| predict ×2.0 | 97.5 | 55.4 | −0.15 ± 1.28 | 1.57 | 7 % | 44.1 | 14.0 % | 1.9 | 11.5 | 26.2 |
| predict ×2.4 | 97.4 | 54.2 | −1.33 ± 1.29 | 1.80 | 10 % | 48.3 | 20.4 % | 2.1 | 15.2 | 31.7 |
| **predict ×2.6** | 97.4 | 53.5 | **−1.98 ± 1.30** | 1.92 | 12 % | 49.5 | **23.7 %** | 2.4 | 16.5 | 33.7 |
| predict ×2.8 | 97.6 | 52.4 | −3.15 ± 1.28 | 2.17 | 16 % | 53.0 | 30.1 % | 2.4 | 18.9 | 35.9 |
| predict ×3.2 | 97.8 | 51.1 | −4.45 ± 1.31 | 2.36 | 19 % | 55.3 | 38.6 % | 2.5 | 22.5 | 41.0 |
| baseline ×2.0 | 97.1 | 56.1 | +0.61 ± 1.26 | 1.70 | 15 % | 27.7 | 9.4 % | 1.5 | 6.9 | 25.1 |
| baseline ×2.6 | 97.4 | 55.1 | −0.47 ± 1.48 | 5.98 | 97 % | 28.8 | 44.5 % | 4.5 | 9.7 | 34.0 |
| baseline ×2.8 | 97.5 | 53.9 | −1.67 ± 1.50 | 5.90 | 98 % | 29.1 | 47.3 % | 4.4 | 10.6 | 36.7 |
| baseline ×3.2 | 97.5 | 51.9 | −3.64 ± 1.50 | 5.77 | 100 % | 29.2 | 52.4 % | 4.0 | 12.2 | 42.0 |

**Notes on the bots:**
- **Model-aware bot.** It casts Hỏa Lôi when it is worth it: chosen 7–19 % of the times it is offered. In the other
  ~90 % it skips mostly because p < 0.4; when it skips it casts Tro hồng (35 %), Lò than (22 %), Tia lửa (21 %) or
  Rạch nhẹ (12 %).
- **Baseline bot.** From ×2.6 up it spams Hỏa Lôi almost every time (still on the old whole-field estimate). That makes
  Hỏa Lôi 45–52 % of its damage at a 29 % hit rate, **without making it faster** than no Hỏa Lôi at ×2.6
  (−0.47 ± 1.48 s). So spam does not dominate the outcome.

## 4. By boss type (model-aware bot; HL share / hit % / Δ s vs no HL)

| Mult | Mobile (24) | Rooted (14) | Mixed (33) | Multi-cell (2) |
|---|---|---|---|---|
| ×2.0 | 9 % / 25 % / +1.6 | 14 % / 70 % / −1.9 | 11 % / 43 % / 0.0 | 33 % / 93 % / −10.1 |
| ×2.4 | 15 % / 29 % / +0.7 | 20 % / 74 % / −4.2 | 18 % / 49 % / −0.8 | 39 % / 94 % / −14.2 |
| **×2.6** | 18 % / 31 % / −0.1 | 24 % / 74 % / −4.6 | 21 % / 50 % / −1.3 | 41 % / 94 % / −17.9 |
| ×2.8 | 26 % / 36 % / −2.0 | 29 % / 76 % / −5.4 | 29 % / 54 % / −2.1 | 43 % / 93 % / −17.6 |
| ×3.2 | 36 % / 39 % / −3.3 | 36 % / 77 % / −6.0 | 39 % / 57 % / −3.4 | 49 % / 95 % / −24.0 |

By chapter (×2.6 model-aware, Δ s vs no HL / HL share), from the summary file: about −5 to +3 s per chapter. The
shares are close to 25 % except desert and hellfire (11–24 %, mobile-heavy).

## 5. Square (2×2 clause, ratio 1.2, fuse 1.8 s) — model-aware bot at ×2.6

| | Blasts | Hit % | Dmg / hit |
|---|---|---|---|
| Square, all | 234 | 61 | 37.0 |
| Square vs 1-cell boss | 231 | 60 | 36.2 (= 6 × 2 × 3.12 minus defense) |
| Square vs 2×2 boss | 3 | 100 | 74.9 |
| Square vs mobile bosses | 89 | 40 | 36.5 |
| Square vs rooted bosses | 52 | 81 | 36.5 |
| Ordinary, all | 2,548 | 48 | 33.3 |
| Ordinary vs 1-cell boss | 2,370 | 45 | 30.2 |
| Ordinary vs 2×2 boss | 178 | 94 | 53.3 |

**Square assessment:**
- It is a small, situational premium: +20 % damage for +0.3 s of fuse and a fixed 2×2 footprint. It is 8 % of blasts.
- Against a 1-cell boss it is only modestly better per hit (36 vs 30) and does not take over: the bot still prefers
  other shapes 92 % of the time.
- Against 2×2 bosses it is the strongest option (75 per hit), which is its intended role.
- The higher hit rate (60 % vs 45 %) is partly selection: the bot only picks the square when the boss is likely
  rooted. On mobile bosses the 1.8 s fuse still lands 40 % of the time, versus 31 % for all Hỏa Lôi blasts on
  mobile bosses.
- The data shows no evidence that the longer fuse makes the square a trap or a must-pick. **Keep ratio 1.2.**

## 6. Harder scenario (start at 35 % HP, 10 seeds, n = 730)

| Set-up | Win % [CI] | Δ win vs no HL | Mean s | Δ s | HL share |
|---|---|---|---|---|---|
| No Hỏa Lôi | 79.0 [75.9–81.8] | — | 49.0 | — | — |
| predict ×2.0 | 80.5 | +1.5 ± 3.1 | 48.9 | −0.12 ± 1.62 | 13.7 % |
| predict ×2.6 | 80.7 | +1.6 ± 3.1 | 47.8 | −1.22 ± 1.60 | 22.9 % |
| predict ×2.8 | 80.1 | +1.1 ± 3.2 | 46.6 | −2.42 ± 1.58 | 29.3 % |

The win rate is no longer saturated (79 %), but Hỏa Lôi moves it by under 2 points (not significant) at every
multiplier. It is a useful card, not a decisive one.

## 7. Recommendation (needs your approval)

- **Base `fuse_mult` ×2.6.**
  - With intelligent play it is 23.7 % of the Mage's damage (just under the 25–30 % guardrail).
  - Battles are 2.0 ± 1.3 s faster than without the card, so it is not slower.
  - Hit rate is 49.5 %, damage 16.5 per cast.
  - On mobile bosses it breaks even (−0.1 s), which is fair for a prediction card.
  - Naive spam gives no speed advantage.
- **×2.8 as the upper alternative:** 30.1 % share, −3.2 s. It sits at the top edge of the band, and it gives more
  against 2×2 bosses, where the card is already strongest.
- I prefer ×2.6 because human players who predict better than the bot will push the share up, and because of the
  multi-cell risk below.
- **Square: ratio 1.2 → ×3.12 at base 2.6, fuse 1.8 s.** Switch the data to `"fuse_mult_scale": 1.2` so it follows
  the base.

## 8. Regression

A fresh full suite after the Model C and tuning work: **228 / 228 test files green in one run** (2026-11-09). It
includes the focus and auto-pause tests, Hỏa Lôi mechanics and visuals, simulator parity, Trảm Địa, Ngàn Kiếm, the
golden test, the new crit-condition test and the audio session's 8 new test files.

## 9. Remaining balance risks

1. **Multi-cell bosses (2 encounters, n = 40): Hỏa Lôi is strongest there** (41 % share, −18 s of 131 s at ×2.6;
   the baseline spam bot −35 s). Model C counts footprint + 1 = 5 cells on a 2×2. Watch it in human play; a lower
   `extra` for large footprints would be the lever.
2. **Bot vs human:** the predictive policy is a heuristic. Real players may reach a higher hit rate on mobile bosses.
3. **Win rates** barely react, even in the harder scenario. Difficulty tuning needs a later-run setup (relics, floor
   HP scaling).
4. **Burn attribution:** a re-ignited cell stays attributed to Hỏa Lôi (burn is only 2–5 % of damage).
5. **Earlier probes** (A / A4 / C on 2026-11-09) ran before the sim CastContext fix, so square-clause numbers there
   were under-counted. The ranking of the models is unaffected (C and A4 cap the same way).
