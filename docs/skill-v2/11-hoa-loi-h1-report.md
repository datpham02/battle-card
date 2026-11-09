# Skill v2 — Hỏa Lôi Milestone H1 (mechanics) report

**Date:** 2026-11-08 · **Status:** H1 implemented, awaiting review. H2 (visuals) and A1 (audio) not started.
**Design:** `09-hoa-loi-design.md` (D1–D9 approved for the prototype; D5 numbers for balance testing only).
**Nothing committed.** No PixelLab, no paid tool, no change to Trảm Địa, Ngàn Kiếm, other cards or the starter deck.

## 1. What was built (generic modules, no Hỏa Lôi-only combat path)

| Module | Where | What it does |
|---|---|---|
| Delayed wave (`resolve: "delayed"`) | `cast_resolver.gd` | open cells (not locked, not already armed) → ONE wave, ONE event `fuse` at `fuse_sec`, × `fuse_mult`; a shape clause may carry `fuse_sec` / `fuse_mult` (capped by the shape-clause group ×2.0 relative to the base); `cast_cells` = armed cells; no open cell → `fizzled` |
| Event payload | `cast_resolver.gd` (validated), `swing_arbiter.gd` (applied) | `event_payload.ignite {sec, tick_sec, damage}` on the event's open cells **after** the damage, hit or miss; unknown keys and payloads on non-delayed cards are rejected (reported, never silent) |
| Armed-zone registry | `swing_arbiter.gd` `armed_cells`, `armed_cast_count`, `armed_threats` | armed = events flagged `armed` still on the authoritative schedule; same-side skip rule; a `recheck_locked` event drops cells locked by the time it fires |
| Threat feed | `swing_arbiter.pending_cells` (+ `armed`), `BossController.cast_delay_fn`, `CastResolver.threat_delay` | armed seals reported apart with their real time left; a running delayed swing reports its fuse delay |
| Boss fuse awareness | `boss_brain.gd`, `boss_brain_config.gd` | a seal is **urgent** only within the set's `fuse_react_sec` (0.8), before that a soft cost `fuse_avoid` (1.0); per weight set; movement still obeys step cooldown, busy stages, blocked (burning) cells |
| Cast profile | `cut_actor.gd` `cast_time_fn`, `skill_config.gd` `cast_time_sec` / `cast_root`, `combat_view.gd` `is_cast_locked` | fixed swing time (replaces the per-cell formula and the passive; relic cast-time hooks still apply); `cast_root: "lock"` roots the hero for the swing only — no Hủy, no commit lock |
| Menu rules | `skill_availability.gd` (`field_cap`, `no_valid_cells`, `delayed_open_cells`), `cut_flow.menu_cells`, `combat_view.get_availability_context`, HUD reason texts | at most `max_active` armed fields per card; a placement with nothing left to arm makes the card unavailable, so **no Block or cooldown is spent for nothing** |
| Card + texts | `cards.json` `hoa_loi`, `strings.csv`, `card_text.gd` (`fuse_sec`, `fuse_mult`, payload burn) | Mage hero card, `hero_reward: false` (not in runs yet, D10) |
| Sim parity | `sim_core.gd` | same cast time, lock, threat delay, availability context; bot value × fuse_mult × 0.5 expected; `fz_*` metrics and a per-blast log |
| Probe | `tools/balance/hoa_loi_probe.gd` | BASE vs HL vs boss react 0.0 / 1.5, plus the damage-model comparison |
| Demo | `demo_args.gd` | `--live-card=hoa_loi` already worked; added `--boss-idle`, boss-move and fuse logs |

**Deviation (reported):** the armed-zone registry lives on the arbiter's schedule (events flagged `armed`), not as a
`fuse` zone kind in `StatusEffects`' zone books. Reason: the only rules needing a zone book entry are disarm by enemy
zones (deferred, D11) and one-zone-per-cell with burn (catalog X1: a seal on a burning cell keeps both) — neither needs
it yet. Moving it into the zone books later does not change the event model.

## 2. Tests (all watched failing by mutation)

| Test | Checks | Result |
|---|---|---|
| `tests/unit/combat/hoa_loi_test.gd` (new) | data + validation (5 rejection cases), 0.45 s cast for 2–5 cells, one wave at swing end + 1.5 s, square 1.8 s ×2.4, whole-field damage once, moving target both ways, 2×2 boss once, locked at cast / during fuse (fizzle), skip + fizzled cast, field cap + reasons, burn payload (no entry tick on the blast, missed field burns, ends after 2 s, ticks 1.5 / 0.5 s), caster hit / death / cancelled cast, threat feed, determinism | 52 PASS, 0 FAIL |
| `tests/unit/combat/boss_fuse_awareness_test.gd` (new) | early seal not urgent, late seal dodged, full cover → no safe cell, delayed swing not urgent, direct swing still dodged, per-set window | 6 PASS |
| `tests/integration/run/hoa_loi_flow_test.gd` (new) | real CombatView menu flow: 0.45 s, lock + d-pad, no Hủy, free at swing end, step during fuse, threat feed, 1.5 s, damage, burn; `no_valid_cells` refuses the card and the Block can be taken back | 20 PASS |
| `tests/unit/balance/sim_hoa_loi_test.gd` (new) | sim cast 0.45, bot rooted then free, detonation 1.95 after the choice, damage, burn, fz metrics, sim availability | 11 PASS |
| `skill_v2_golden_test`, `boss_surge_awareness_test`, full suite | existing cards unchanged | see §5 |

Mutations (each restored): skip rule removed → 2 fails; react window removed → 2; lock re-check removed → 1; payload
removed → 4; cast lock removed → 1; `no_valid_cells` removed → 3.

## 3. Validation scenarios (real battle, `--demo=tram_live --live-card=hoa_loi`)

Event logs in `production/qa/evidence/skill-v2-hoa-loi/h1-mechanics/`. Seals have **no visuals yet** (H2), so H1
evidence is the authoritative event log; screenshots come with H2.

| # | Requirement | Scenario | Result |
|---|---|---|---|
| 1 | stationary boss is hit | A (`--boss-idle`, bar2) | hit at 1.950 s, 24 dmg, 2 cells burn |
| 2 | moving boss escapes | B (boss moves (0,1) at 1.0 s) | miss, 0 dmg; the cells still burn |
| 3 | predicted route covered | C (plus5, same move) | hit at its new cell, 60 dmg |
| 4 | shapes give different coverage | S_bar4 / S_l4 / S_t4 / S_square, C | row / column+foot / top row+stem / 2×2 (1.8 s, ×2.4, 57.6) / plus |
| 5 | burning ground changes movement | D, E (live boss) | after the blast the boss leaves its burning cell for a non-burning one ((5,1) → (5,0) with (4,1) burning); unit test: boss blocked from burning cells |
| 6 | locked and overlapping cells | F (`--cast-lock`): 3 seals, (6,1) none, 36 dmg; overlap: unit tests (skip, fizzle, cap) | as designed |
| 7 | deterministic | D run twice | identical logs |

**Not shown in a real battle:** the boss **dodging** a lone seal. In the demo match the boss is mid-attack (rooted)
when the seals blow, so D and E are timing hits. The dodge is proven by `boss_fuse_awareness_test` and measured in the
sim (below).

## 4. Balance probe (chapter 1, 16 matches × 12 seeds, Mage starter + 2 × hoa_loi; `balance-probe-ch1-12seeds.txt`)

| Set-up | Win % | Mean s | Blasts | Hit % | Cells / blast | HL share of damage | Casts while boss busy |
|---|---|---|---|---|---|---|---|
| BASE (no Hỏa Lôi) | 100 | 58.3 | — | — | — | — | — |
| HL (react 0.8) | 99 | 54.6 | 344 | **62** | 2.68 | **13.9 %** | 73 % |
| HL react 0.0 | 99 | 54.0 | 344 | 69 | 2.73 | 16.0 % | 73 % |
| HL react 1.5 | 99 | 54.9 | 344 | 60 | 2.70 | 13.5 % | 72 % |

- Inside the targets: fuse hit rate 40–70 %, Hỏa Lôi ≤ 25 % of the Mage's damage, win rate unchanged.
- Hits depend on the boss: rooted / slow bosses 60–90 % (forest_witch 89, goblin_warlock 81, wolf_alpha 81); mobile
  ones 0–10 % (wolf 0, goblin_chief 8, goblin_shaman 7, goblin_warrior 10). The react window moves the total only
  62 → 69 → 60 %, because 73 % of the bot's casts land while the boss is busy (rooted) — the bot does not predict.

**Damage models** (counterfactual over the 214 hits of the HL run; the rule was NOT changed):

| Model | Rule | dmg / hit | dmg / blast | by armed cells n (dmg / hit) |
|---|---|---|---|---|
| **A whole field (approved)** | dpc × n × mult | 33.0 | 20.5 | n2 23.8 · n3 36.0 · n4 48.0 · n5 59.7 · n6 70.8 · n7 78.0 |
| B covered cells only | dpc × k × mult | 15.5 | 9.6 | ≈ 14–23 for every n |
| C capped field | dpc × min(n, fp + 1) × mult | 26.8 | 16.7 | n2 23.8 · n3 28.2 · n4 35.1 · n5 28.4 · n6 44.6 · n7 55.7 |

Facts: on 73 % of hits the boss touched **one** seal (k = 1: 157, k = 2: 50, k = 3: 7); 62 % of hits were on 1-cell
bosses. Under A, a 5–7-cell field (the bot joins two Blocks) pays 60–78 for a one-seal touch — larger fields grow damage
**and** coverage at once. B makes the card weaker than direct cards (≈ 15 per hit). C keeps small fields identical to
A and halves the payoff of big fields on small bosses.

**Recommendation (not applied):** keep A for the H1/H2 prototype; before final balance choose between A with a field
cap (`max_damage_cells`, e.g. 4) and C, measured by the same probe with a predicting bot. The rule change needs your
approval.

## 5. Regression

Full suite (216 test files = 212 + 4 new): **215 green**, golden unchanged; Trảm Địa, Ngàn Kiếm, cast scheduler and
the existing Mage cards green.
- Fixed on the way (caused by adding the card, expectations / texts only): `cast_scheduler_test` (hoa_loi joins the
  Skill v2 scheduled cards), `deck_power_test` (35 player cards, 18 common), `card_text_test` (no hard-coded "2x2" in
  the description), `terminology_scan_test` (English "Seal" is a retired glossary term → "sigil").
- **1 failing, not caused by H1:** `tests/integration/ui/focus_flow_test.gd` "tap piece -> PLACING + focus active"
  fails deterministically today; it fails identically on a clean worktree of `0472896` (the last commit, without any
  H1 change) and passed in the 2026-11-08 suite. Probably environmental (windowed input); not investigated further
  (out of H1 scope).

## 6. Outstanding problems / open points

1. **Seals are invisible** until H2: the card is not player-readable yet (it is not in rewards, `hero_reward: false`).
2. **Damage model A** over-rewards large fields on 1-cell bosses (§4) — decision pending.
3. **Mobile bosses** almost never get hit (0–10 %), rooted ones 60–90 %: Hỏa Lôi is strongly boss-dependent. A
   predicting bot is needed to know the human ceiling; human playtest needed.
4. **Boss dodge not captured in a real battle** (demo boss always busy at the blast); proven in unit tests and the sim.
5. With **no safe cell** the boss may step from one seal to another (harmless, but a wasted step); unchanged.
6. **Fizzled cast feedback** (a seal that fizzles, a cast with nothing armed if cells lock during the 0.45 s) is in the
   events but has no HUD feedback yet — H2.
7. The `tram_live` demo ignores `--match` (same boss every run) — demo limitation, not gameplay.
