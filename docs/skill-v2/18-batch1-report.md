# Skill v2 batch 1 report (2026-11-11)

Four blocked cards from `16-mvp-matrix.md` are now playable: `min_tre` Mìn Trễ, `chuoi_set` Chuỗi Sét, `dap_vo`
Đập Vỡ, `thuong_xuyen` Thương Xuyên. Each is a small, data-driven extension of an existing system; no new VFX code
(the shared delivery / impact packs on the card data draw them). Playable count: 38 → **42 / 60**.

Nothing committed. The user commits.

## Cards and fields

| Card | Bible | New data on the card | Where the rule lives |
|---|---|---|---|
| `min_tre` common · delayed | fuse 1.2 s ×1.6, detonation pushes 1 | `resolve: delayed`, `fuse_sec 1.2`, `fuse_mult 1.6`, `max_active 2`, `event_payload: {push: {cells: 1}}`, `cast_presentation: throw` | `CastResolver.PAYLOAD_KEYS` += `push` (`cells` 1..3); `SwingArbiter._fire_event` applies it on a damaging hit; `CutEffects.push_from` moves the target away from the mask's ShapeTags centre (row/column by the larger offset; away from the divider when standing on the centre; stops at the half's edge, a blocked cell or a footprint that does not fit). Hỏa Lôi's data and path are untouched (ignite only). |
| `chuoi_set` rare · chain | +15 % per link after the first, cap +60 %; `S` → links every 0.06 s | `resolve: arrival` on `SEQUENTIAL_CHAIN`, `max_hits 1`, `link_ramp 0.15`, `link_ramp_cap 0.6`, `shape_clause {tag: S, link_step_sec: 0.06}` | `CastResolver.validate` (ramp needs `arrival`; cap ≤ 1.0), `_arrival_events`: link k × (1 + min(k × ramp, cap)); a `link_step_sec` clause that holds re-times the links. Ramp defaults to 0: every existing chain card (all `instant`) is unchanged. |
| `dap_vo` common · anti-armour | strips Guard, ×1.5 if it had Guard; `compact` → 1 Rạn | `resolve: arrival` on `SKY_TO_TARGET` (one drop per cell, `max_hits 1`), `guard_break: true`, `guard_break_mult 1.5`, `shape_clause {tag: compact, fragile_stacks: 1}` | `CutEffects.apply`: reads `StatusEffects.guard_amount`, `clear_guard` before the damage, ×mult when Guard was present, the stripped amount leaves this hit's flat defense (the match's `boss_defense` stays). Clause key `fragile_stacks` (1..3) applied in `_apply_keywords` when the clause holds for the cast context. |
| `thuong_xuyen` common · line payoff | requires a `line` piece; dpc 5 +1 per cell beyond 2, cap +3; pierces in order | `resolve: arrival` on `CASTER_TO_TARGET` (the surge path = cell by cell from the caster outward), `max_hits 1`, `requires_shape {tag: line, scope: any_piece}`, `dpc_bonus {per_cell: 1, from_cells: 2, cap: 3}` | `SkillAvailability`: new context key `CTX_PIECE_TAGS` (tag lists of the placed pieces, `piece_tags_of(CastPlan)`), new reason `need_shape` (HUD text `ui.hud.need_shape`); `CombatView.get_availability_context` and `sim_core.availability_context` supply it while the menu is open. `CutEffects.dpc_bonus` (shared with the sim's `cast_value`). |

Why `dap_vo` is `arrival` and not `instant`: `skill_v2_golden_test` pins the whole result of every instant card; an
instant Đập Vỡ would have added a 34th legacy card to a fixture that is already out of date (see below). Sky
arrival drops each cell with the delivery's own 0.12 s fall, so the look matches the bible ("hammer drops").

`card_order`: `…, vung_lay, thuong_xuyen, dap_vo, chuoi_set, min_tre` (the bible's order). `chuoi_set` and `min_tre`
are "unlockable" in the bible but no `unlock_by` key is set (the unlock source is not specified there); they sit in
the shared pool like the other commons/rares until that is decided.

## Files

Changed (user-approved 2026-11-11): `src/combat/skill_config.gd` (normalises `link_ramp`, `link_ramp_cap`,
`guard_break`, `guard_break_mult`, `requires_shape`, `dpc_bonus`; `UPGRADE_FLOORS` for `link_ramp` /
`guard_break_mult`), `src/combat/cast_resolver.gd`, `src/combat/cut_effects.gd`, `src/combat/swing_arbiter.gd`,
`src/combat/skill_availability.gd`, `src/combat/combat_view.gd` (only `get_availability_context`),
`src/combat/cut_hud_view.gd` (reason `need_shape`), `src/run/card_text.gd` (placeholders `link_ramp_pct`,
`link_cap_pct`, `guard_break_mult`, `dpc_bonus_per`, `dpc_bonus_from`, `dpc_bonus_cap`, `payload_push_cells`,
`clause_fragile_stacks`), `assets/data/cards.json`, `assets/i18n/strings.csv` (13 rows appended, CRLF: name / desc /
desc_battle ×4 + `ui.hud.need_shape`), `tools/balance/sim_core.gd` (availability context piece tags; `cast_value`
counts `dpc_bonus`, the mean link ramp, ×`guard_break_mult` while the boss has Guard), `tests/unit/combat/deck_power_test.gd`
(rarity spread 42 cards: 24 common / 13 rare / 5 epic), `tests/unit/combat/keyword2_test.gd` and
`tests/unit/combat/cast_scheduler_test.gd` (see the suite section).

New: `tests/unit/combat/cast_resolver_push_payload_test.gd`, `cast_resolver_link_ramp_test.gd`,
`cut_effects_guard_break_test.gd`, `skill_availability_shape_requirement_test.gd`;
`tests/integration/run/min_tre_flow_test.gd`, `chuoi_set_flow_test.gd`, `dap_vo_flow_test.gd`,
`thuong_xuyen_flow_test.gd`; `tests/integration/run/skill_v2_batch1_evidence.gd` (windowed capture, not a test);
`production/qa/evidence/skill-v2-batch1/01..04.png`.

Not touched: `src/art/**`, `assets/art/**`, `src/battle/unit_layer.gd`, audio files, Hỏa Lôi / Ngàn Kiếm / Trảm Địa
data and tests.

## Tests

Unit (deterministic, FAILS=N), each through the real CutActor → SwingArbiter → CutEffects path:

- `cast_resolver_push_payload_test.gd`: data + validation (cap, object, non-delayed), plan carries the payload, push
  along the row / the column / from the centre cell / stopped at the half's edge, a miss pushes nothing, Hỏa Lôi's
  blast never pushes, determinism. 16 checks.
- `cast_resolver_link_ramp_test.gd`: data + validation, link multipliers in chain order (×1 / 1.15 / 1.3 / 1.45),
  the cap at 6 links, no ramp = ×1 (bang_chau stays legacy), the S clause re-timing, one hit at the link that finds
  the boss (26 at the 3rd link), determinism. 14 checks.
- `cut_effects_guard_break_test.gd`: Guard 6 → stripped, 18 with no defense taken off; no Guard → 12; boss_defense 2
  + Guard 6 → 16; kiem_khi leaves Guard alone; compact clause Rạn (square yes, bar2 no, no context no); real sky
  arrival; determinism. 13 checks.
- `skill_availability_shape_requirement_test.gd`: need_shape rule (square only → refused, with a bar2 → ok, no
  context key → unchecked, cells before shape, all_pieces scope), `piece_tags_of` from a CastPlan, the dpc_bonus
  curve, pierce order from the hero outward with one hit at the far end (28 at 4 cells), other cards ignore the
  rule, determinism. 14 checks.

Integration (real CombatView flow: bag → place → menu → choose): `min_tre_flow_test` (armed field, threat feed,
detonation at 1.2 s, push +1 cell, field cap / no-valid-cells menu rules), `chuoi_set_flow_test` (4 links scheduled
0.1 s apart, one hit at the boss's link with that link's ramp, need_cells below 4), `dap_vo_flow_test` (Guard 6
stripped, 18 then a plain 12, square → +1 Rạn), `thuong_xuyen_flow_test` (square only → need_shape, choosing
refused, the Block returned; bar3 → pierce in order, one hit, 18). All FAILS=0.

Evidence (`production/qa/evidence/skill-v2-batch1/`, real ch1 battle vs Dire Wolf, Swordsman, boss_defense 1):
`01-min-tre-detonation-push.png` (HIT -15, the wolf pushed one cell right), `02-chuoi-set-last-link-hit.png`
(HIT -28 on the t4's last link ×1.45), `03-dap-vo-guard-break.png` (HIT -17 through Guard 6),
`04-thuong-xuyen-pierce.png` (HIT -17, bar3 pierced). Re-capture:
`godot --path . --windowed --resolution 1280x720 -s res://tests/integration/run/skill_v2_batch1_evidence.gd`.

### Full suite (`bash tools/qa/run_all_tests.sh production/qa/batch1-suite-2026-11-11.txt`)

Run 2026-11-11 (headless unit + integration, windowed ui): **242 tests, 241 green (FAILS=0, 0 script errors), 1 red.**

| Test | FAILS | Cause | Red before the batch? |
|---|---|---|---|
| `tests/unit/combat/skill_v2_golden_test.gd` | 2 (`32 legacy (instant) player cards in card_order` → 33; `case count` 640 vs 660) | `vung_lay` (previous agent, uncommitted) is a 33rd instant card; the fixture was never re-recorded. Batch 1 adds no instant card (all 4 are `delayed` / `arrival`) and adds no result key to legacy results, so it does not change this count. | **Yes** — identical FAILS=2 before any batch-1 edit. |

Due to the batch: **0**. Red before the batch: **1** (the golden test above, left untouched per the parent session).

The two older tests that the batch did make red were updated with the user's OK (2026-11-11) and are green:
`keyword2_test.gd` (the common dpc 6–7 band now exempts `delayed` and `dpc_bonus` cards, like Vũng Lầy's mire
exemption) and `cast_scheduler_test.gd` (the list of non-instant card ids gained the 4 batch-1 ids).

## Left open

- `skill_v2_golden_test.gd` was already red before this batch (33 instant cards vs the fixture's 32, 660 vs 640
  cases: `vung_lay` from the previous agent, uncommitted). Not touched, per the parent session; the user decides.
- Sim parity: the balance sim runs the real arbiter, so the damage paths are shared by construction; the bot's value
  estimate (`cast_value`) now mirrors the three new rules. No `--card-set` sim run was made for the 4 cards.
- VFX: the shared packs draw these cards (`knockback`, `chain_spark/burst`, `falling_squares/shatter`,
  `square_streak/slash`); the VFX session restyles impacts by type. `min_tre` is `cast_presentation: throw`, a
  presentation no sheet has a clip for yet (falls back to the weapon clip).
- Unlock sources for `chuoi_set` / `min_tre` (bible "unlockable") are not set.
