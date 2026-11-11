# Skill v2 batch 5 — the "Deferred after 60/60" list (2026-11-11)

Items 1–5, 8, 9, 11–13 of `16-mvp-matrix.md` and the data half of 10. Items 6, 7 and the HUD chip / board bracket of
10 stay with the VFX session. Nothing committed; the user gathers the commits.

| # | Item | Decision taken | Where the rule lives |
|---|---|---|---|
| 1 | Reaction ICD + immunity | **1.0 s per unit per reaction id**, `combat.json reactions.icd_sec`. Immunity: `StatusEffects.reaction_immune_fn` (Callable(side, id) -> bool, for an enemy's `immune_status` list — nothing wires it yet, no enemy has such a list) and a **burn_eater boss is immune to R1** on its own (`burn_heal_ratio_fn > 0`). | `StatusEffects.reaction_allowed(side, id, icd_sec)` is the ONE gate (a true answer starts the cooldown); `reaction_cooldown_left`, `time()`. CutEffects / SwingArbiter / the trap and entry paths all pass it. `clear()` resets the book. |
| 2 | R1–R3 card-listed or global | **Global** (`reactions.global: true`; CutEffects' built-in default is global too). A card's `reactions` list is now documentation; `global: false` restores the card-listed rule as data (tested). | `CutEffects.reaction_enabled(skill, id, reactions)` + `_reaction_ok` (the gate). Golden re-recorded on purpose, see below. |
| 3 | The boss drawing the 5 shared cards | **Smoke only** (the tuning is the balance pass): `boss_card_order()` holds `dia_chan`, `loc_cuon`, `bang_vo`, `hoa_bang`, `hoi_am` (printed by `echo_ran_probe.gd`); the sim's arbiter already gets `combat.reactions()` (now with ICD / global). No sim change needed. | `tools/balance/sim_core.gd` (unchanged). |
| 4 | Several shape clauses on one card | New card field `shape_clauses` (a list of clause objects); `shape_clause` stays as the first. **The first clause that holds is the active one.** Thiên Thạch: `plus` (ring 0, hub ×2) then `square` → `hub_all` (every cell a hub at hover, ×1.5). | `CastResolver.shape_clauses(skill)` / `active_clause(skill, context)`; every clause reader (resolver, CutEffects, arbiter) goes through it. `card_text.gd` keeps reading `shape_clause` (the first). |
| 5 | R1 on entry with Hàn; R3 on a thorn landing | A unit carrying Hàn that **steps onto** a burning cell bursts (12, the fire out, 1 Hàn spent) — `StatusEffects._r1_entry` in the entry check, signal `reaction_fired(side, id, damage)`. A forced move (push, pull, row drag, trap fling) that **ends on a thorn cell** slams (R3 8 + Pin 0.6) on top of the thorn toll — `CutEffects._r3_on_thorns`, used by the push / pull paths, the arbiter's row pull and `fire_trap`. Also the M15 "is ignited on": a burn-effect card or an ignite payload landing under a unit with Hàn reacts (global, ICD-gated). | `status_effects.gd`, `cut_effects.gd`, `swing_arbiter.gd`. |
| 8 | Trap damage through defense | **Through the flat defense** (`reactions.trap_through_defense: true`): the snap is a hit, `dpc × cells − defense` (minimum 1, Guard counts, `pierce_defense` skips). `false` restores the thorn-toll rule as data. | `StatusEffects.fire_trap` with `defense_fn` (Callable(side) -> float; SwingArbiter sets it in `_init`: `boss_defense + Guard`). |
| 9 | Fire wall detonation; trap fling into a pillar | Gai Nổ's `detonate_zones` consumes fire-wall cells too (the burn put out, the cell counts). A trap's fling never enters a pillar / hole (`StatusEffects.blocked_fn_for`, the arbiter's `blocked_cell_fns`) and a stopped fling slams (R3, ICD-gated). | `CutEffects.apply` (detonate), `push_away(…, blocked_fn)`, `fire_trap`. |
| 10 | Dấu Tử HUD chip (data half) | `STATUS_MARK` is in `STATUS_ORDER` (after Chill) and `active_statuses` lists it as a timed debuff; strings `ui.status.mark.name` = Dấu Tử / Death Mark, `ui.status.mark.desc`. **Left for VFX:** the `mark` row in `src/ui/status_row.gd` (icon + colour) and the board bracket. | `status_effects.gd`, `strings.csv` (2 CRLF rows). |
| 11 | Echo snapshots of the signature | The player's signature factor is **frozen at the cast** (`SwingArbiter._signature_factor`: the hook called with damage 1 at the swing end → `cast.sig_factor` / `result.sig_factor`); every echo wave (a card's own, the mark's) applies that factor instead of the live hook. The parent's own events keep the live hook (the signature's own rule). | `swing_arbiter.gd` (`_settle`, `_schedule_cast`, `_fire_event`, `_finish_cast`, `_trigger_mark`). |
| 12 | Móc Kéo pull path as a `path_rule` | `SkillDelivery.PATH_EFFECT_PULL` ("pull"): the delivery declares `path_rule {effect "pull", telegraphed true}`; `damage_cells` adds NO travel cell for it; `SkillDelivery.path_effect(delivery)`. The arbiter emits `cast_scheduled.pull_path` **only** through the rule (the drag itself stays `pull_row_cells`). | `skill_delivery.gd`, `swing_arbiter.gd`, `cards.json` (`moc_keo.delivery.path_rule`). |
| 13 | Echo waves and Rạn | Measured with `tools/balance/echo_ran_probe.gd`; **rule A kept** (an echo neither spends Rạn nor takes ×1.5). The readings differ only with a 2+ stack bank, by 11–14 % of the cast, and the looser one drains the bank in one cast. Written up in `02-design-decisions.md §7.1`. | — |

## Golden fixture (`tests/unit/combat/skill_v2_golden_test.gd`, re-recorded on purpose)

640 cases, 22 of the 32 legacy cards change rows, all through the global reactions (nothing else touches the legacy
path):

- **`hit3_ran_pinned` (40 rows, every damaging card)** — the Pinned boss with 1 Rạn now takes **R2 ×2** instead of
  the Rạn ×1.5, the Pin ends (`reaction: "r2"`). Was card-listed (Băng Vỡ only).
- **`edge_push` (8 rows: chan_phong, cuong_phong, thien_lang, xung_kich)** and **`hit1` / `hit3_row` / `hit5_plus` /
  `hit3_hole` / `boss2x2_4cells` of thien_lang + `boss2x2_4cells` of xung_kich (20 rows)** — a push stopped short by
  the edge / hole / footprint slams: **R3 +8 and Pinned 0.6** (`reaction: "r3"`). Was card-listed (Địa Chấn, Lốc Cuốn,
  Bẫy Lò, Móc Kéo).
- **`hit3_burning` (10 rows: bang_tam, han_kiem, han_tran + the Hàn cards)** — a Hàn-giving hit on a boss standing
  on a burning cell bursts **R1 12**, the fire out, 1 Hàn spent (`reaction: "r1"`). Was card-listed (Hỏa Băng).
- **`hit3_frost2` (14 rows: hoa_tinh, hoa_tran, hoa_xa, liet_hoa, thien_hoa… the burn cards)** — a burn card landing
  under a boss that carries 2 Hàn reacts (R1): the M15 "is ignited on" reading, global.

The fixture is the record of the rule; `reactions.global: false` in `combat.json` would restore every row (the test
passes no reactions, so it reads CutEffects' built-in default, which is global).

## Files

Changed (user-approved 2026-11-11): `src/combat/status_effects.gd`, `cut_effects.gd`, `cast_resolver.gd`,
`skill_config.gd`, `swing_arbiter.gd`, `skill_delivery.gd`, `combat_config.gd`, `assets/data/combat.json`
(`reactions.icd_sec / global / trap_through_defense`), `assets/data/cards.json` (`thien_thach.shape_clauses`,
`moc_keo.delivery.path_rule`), `assets/i18n/strings.csv` (2 rows), `tests/unit/combat/golden/skill_v2_cut_effects.json`
(re-recorded), `docs/skill-v2/02-design-decisions.md` (§7.1), `16-mvp-matrix.md` (items marked). Tests updated to
the global rule: `cut_effects_reaction_r1_test.gd` (han_kiem reacts; `global: false` keeps the old number),
`cut_effects_reaction_r2_test.gd` (kiem_khi shatters; `global: false` keeps 27), `cast_resolver_row_pull_test.gd`
(a drag onto thorns slams: 26), `cast_resolver_ground_push_test.gd` (chan_phong slams at the edge), `keyword2_test.gd`
(the Pinned Rạn hit is R2 x2).

New: `tests/unit/combat/status_effects_reaction_icd_test.gd`, `cast_resolver_shape_clauses_test.gd`,
`status_effects_reaction_entry_test.gd`, `status_effects_trap_defense_test.gd`,
`swing_arbiter_signature_snapshot_test.gd`, `skill_delivery_pull_path_test.gd`; `tools/balance/echo_ran_probe.gd`.

Not touched: `src/art/**`, `assets/art/**`, `src/battle/**`, `src/ui/**` (the `status_row.gd` row is VFX work),
`combat_view.gd`, `cut_hud_view.gd`, audio, `tools/balance/sim_core.gd`.

## Tests

Unit (deterministic, FAILS=N):

- `status_effects_reaction_icd_test.gd` (14): data; a second R2 within 1 s falls back to the Rạn ×1.5 and fires again
  at 1.0 s; the ICD is per id and per unit; `icd_sec 0`; `clear()`; the immunity hook; a burn_eater boss never R1s;
  `global: false` keeps the card-listed rule (kiem_khi 27, bang_vo 30); determinism.
- `cast_resolver_shape_clauses_test.gd` (12): Thiên Thạch's two clauses, validation (a list of objects, every entry
  checked), `active_clause` order (plus / square / none; the first of two that hold), square → 4 hubs at 0.6 s ×1.5,
  plus unchanged, bar4 the card's own numbers, determinism.
- `status_effects_reaction_entry_test.gd` (8): a boss with Hàn stepping onto fire bursts 12 (fire out, Hàn spent,
  `reaction_fired`), nothing without Hàn or fire, two entries 0.01 s apart burst once and again after 1 s, Xung Kích's
  push onto a thorn cell adds the toll 6 and the slam 8 (Pinned, 1 Rạn), a clean landing adds nothing, determinism.
- `status_effects_trap_defense_test.gd` (8): Bẫy Kẹp 6 through defense 4 = 2, defense + Guard never below 1,
  `trap_through_defense false` = the old 6, Bẫy Lò's fling into a pillar stays put and slams (3 + 8, Pin 0.6,
  `reaction_fired`), Gai Nổ detonates a 3-cell fire wall (the burn out), determinism.
- `swing_arbiter_signature_snapshot_test.gd` (5): the mark's echo keeps ×1.75 after the signature ended (6.3), a
  signature activated after the cast adds nothing (3.6), a scheduled parent (Đập Vỡ) snapshots too, Hồi Âm's own
  echo keeps the factor (15.75), determinism.
- `skill_delivery_pull_path_test.gd` (10): `pull` normalises (telegraphed required, no sky), `damage_cells` adds no
  travel cell for it (damage still does), Móc Kéo is the only card with a rule, the arbiter telegraphs
  `pull_path` (6,1) (5,1) (4,1) only with the rule (the drag unchanged without it).

Probe: `tools/balance/echo_ran_probe.gd` (the §7.1 table).

### Full suite (`bash tools/qa/run_all_tests.sh production/qa/batch5-suite-2026-11-11.txt`)

Run 2026-11-11 (headless unit + integration, windowed ui): **277 tests** (271 + the 6 new). First pass: 274 green,
three red — `cast_resolver_ground_push_test` ("other push cards never slam") and `keyword2_test` ("Ghim: Rạn only =
21") still encoded the card-listed rule and were updated to the global one (chan_phong at the edge 12 + 8 Pinned;
the Pinned Rạn hit x2 = 28, the Pin ended), both green on the rerun; `tests/integration/ui/focus_flow_test.gd`
(2 fails: "card menu: match stopped", "Huy in menu returns the piece") is green on an immediate rerun (windowed,
muted) — a timing flake, unrelated to this batch (no HUD / menu code changed here; the VFX session has uncommitted
`cut_hud_view.gd` / `status_row.gd` edits in the same checkout). **FAILS=0 on every suite after the reruns; 0 script
errors.**

## Left open

- VFX session: Deferred 6, 7, the `mark` row in `status_row.gd` + the board bracket (10); a HUD cue for
  `StatusEffects.reaction_fired` (the entry R1 / trap R3 have no CutEffects result to show a number from).
- Balance pass: the boss with the 5 shared cards (3) and the global reactions' effect on the 33 legacy cards' bands
  (2) are measured, not tuned; `immune_status` lists are a hook with no enemy data yet.
- No new in-game screenshots were captured for this batch (rules only; the batch-1…4 evidence stands). Re-capture of
  any batch: `godot --path . --windowed --resolution 1280x720 --audio-driver Dummy -s res://tests/integration/run/skill_v2_batchN_evidence.gd`.
