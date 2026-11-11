# Skill v2 batch 4 report (2026-11-11)

The last five blocked cards of `16-mvp-matrix.md` are playable. Playable count: 55 → **60 / 60**. Nothing committed.
The user commits.

| Card | Bible | New data on the card | Where the rule lives |
|---|---|---|---|
| `chuong_thanh` Chuông Thánh (Cleric, rare) | hit now, two echoes at 0.6 s intervals at 50 %, each wave that hits +1 Hàn; `square` → three echoes | `resolve: waves, hits 1`, `frost_stacks 1`, `echo {count 2, mult 0.5, delay_sec 0.6, shift 0}`, `shape_clause {square, echo_count 3}` | The batch-2 echo (`CastResolver.echo_events`) ringing in place; the keyword path lands the Hàn on every wave that hits (three Hàn burst). `MAX_ECHO_COUNT` 2 → 3. |
| `thien_quang` Thiên Quang (Cleric, epic) | a pillar per cell after a 0.7 s shadow, one damage hit, +1 Hàn per pillar that finds the unit (max 2 per cast); `plus` → the centre lands first and, if it hits, the Cleric heals 6 | `resolve: arrival` SKY, `sky_hover_sec 0.7`, `drop_order from_centre`, `max_hits 1`, `frost_stacks 1`, `keyword_hits_max 2`, `shape_clause {plus, hub_heal 6}` | New field `keyword_hits_max`: in `SwingArbiter._fire_event` a drop that finds the unit once the cast's damage hits are spent applies only the card's keywords (`CutEffects.apply_keywords_only`), counted with the damage hits up to the cap (`cast.keyword_hits`, event key `keyword_only`). Clause `hub_heal`: the first event (the centre, `from_centre`) that hits heals the caster (event key `hub_heal`). |
| `dau_tu` Dấu Tử (Assassin, epic) | a hit marks the target 3 s (`mono` 5 s): the next damaging cast on it echoes once at 60 % and executes ×2 under 30 % HP | `mark {sec 3, echo_mult 0.6, execute_ratio 0.3}`, `shape_clause {mono, mark_sec 5}`, dpc 2, min 1, `resolve: waves, hits 1` | `StatusEffects` death mark (`apply_mark` / `mark_at` / `has_mark` / `consume_mark`, timed, refreshed never stacked, status id `mark`, signals `mark_applied` / `mark_expired` / `mark_triggered`). `CutEffects.apply` leaves the mark on the card's hit. `SwingArbiter`: a PLAYER cast that hits a marked target (not the mark's card, not an echo) gets `options.mark_execute_ratio` (×2 at ≤ 30 %) and, when it finishes (`_settle` for an instant card, `_finish_cast` for a scheduled one), `_trigger_mark` spends the mark and schedules ONE echo cast: the last hit's cells (`echo_cells`), 0.6 s later, × `echo_mult`, counted on the parent's cells. An echo cast runs with `options.echo` (no Rạn spent or gained, no crit, no execute), heals nothing, never triggers a mark and emits no `swing_resolved` (not a cast for the listeners: no Engraving / Awakening charge, no relic on_cast, no cast count). Per §7 the echo repeats the base hit (an executed parent echoes without the ×2). |
| `phi_tieu` Phi Tiêu Liên Hoàn (Assassin, rare) | one dagger per cell in sequence, nearest first, 0.08 s apart; a dagger whose cell is empty re-targets the mask cell the unit moved to; at most 2 hits; `L` → the corner's dagger first, Rạn before the rest | `resolve: arrival` SEQUENTIAL_CHAIN (origin caster, nearest_first), `link_step_sec 0.08`, `max_hits 2`, `bounce true`, `shape_clause {L, corner_first true, fragile_stacks 1}` | `link_step_sec` is a card field now (the clause form stays). `bounce`: each dagger is its own wave (so a unit may be hit twice); in `_fire_event` a bouncing event whose cell is empty re-targets the mask cell the unit stands on (`bounced_from` on the event). `corner_first`: `CastResolver.corner_cell` (the mask cell whose two neighbours are perpendicular) is put first in the chain. The clause Rạn lands on that hit (batch 1's clause keyword). |
| `moc_keo` Móc Kéo (Hunter, rare) | a hook flies to the first mask cell; a hit pulls the unit up to 2 cells along its row toward the divider, step by step; a blocked step → R3; ending on a thorn / trap triggers it; the pull path is telegraphed; `line_h` → +1 | `resolve: arrival` CASTER_TO_TARGET (the M03 surge), `max_hits 1`, `pull_row_cells 2`, `reactions ["r3"]`, `shape_clause {line_h, pull_row_cells 3}` | `_fire_event`: the hit drags the target with `CutEffects.pull_toward` toward the divider cell of its row (the first enemy column), with the target mover's blocked test; a refused step slams (R3) for the card. The row pull is a cell change, so the existing entry checks fire thorns / traps the unit lands on. `cast_scheduled` carries `pull_path` (the cells the unit would be dragged through from where it stands at the swing end) for the telegraph. Event keys `pulled` / `pull_from` / `pull_to`. |

Cross-cutting:

- **Echo waves are echo waves.** Every event of kind `echo` (Hồi Âm, Chuông Thánh, the mark's) now resolves with
  `options.echo`: no Rạn spent or gained, no crit, no execute (02-design-decisions.md §7, the stricter reading of
  the catalog's "never consumes Rạn twice in one wave"). Batch-2 echo tests are unchanged (no Rạn in them);
  Deferred 13 asks the balance pass to re-measure.
- **Push blocked cells (batch 3) applies to the hook's pull too**: a pull into a pillar / hole slams for Móc Kéo.
- **Card order:** all five are hero cards (Cleric ×2, Assassin ×2, Hunter), offered in their hero's rewards
  (`hero_reward: true`), appended after `card_order`.

## Files

Changed (user-approved 2026-11-11): `src/combat/status_effects.gd` (death mark), `cut_effects.gd` (echo option,
mark execute, the mark on hit, `apply_keywords_only`), `cast_resolver.gd` (`MAX_ECHO_COUNT` 3, `link_step_sec`
field, `bounce` events per wave, `corner_cell`, clause keys `hub_heal` / `corner_first` / `mark_sec` /
`pull_row_cells`), `skill_config.gd` (`mark`, `keyword_hits_max`, `bounce`, `link_step_sec`, `pull_row_cells`),
`swing_arbiter.gd` (bounce, keyword cap, hub heal, row pull + telegraph, mark trigger + echo cast,
`MARK_ECHO_DELAY_SEC`, the echo option on echo events, `echo_cells` on results), `src/run/card_text.gd`
(placeholders), `assets/data/cards.json`, `assets/i18n/strings.csv` (15 CRLF rows), `tests/unit/combat/deck_power_test.gd`
(60 cards: 29 / 20 / 11), `cast_scheduler_test.gd` (+5 ids), `docs/skill-v2/16-mvp-matrix.md` (Deferred 10–13).
`tools/balance/sim_core.gd`: no change needed (the sim runs the real arbiter; the bot's `cast_value` already counts
echo waves from batch 2; the mark and the keyword cap are not in its estimate — a tuning-only gap).

New: `tests/unit/combat/cast_resolver_echo_waves_test.gd`, `cast_resolver_keyword_cap_test.gd`,
`status_effects_death_mark_test.gd`, `cast_resolver_bounce_test.gd`, `cast_resolver_row_pull_test.gd`;
`tests/integration/run/batch4_flow_test.gd`; `tests/integration/run/skill_v2_batch4_evidence.gd`;
`production/qa/evidence/skill-v2-batch4/01..05.png`.

Not touched: `src/art/**`, `assets/art/**`, `src/battle/**`, `combat_view.gd`, audio, `combat.json`.

## Tests

Unit (deterministic, FAILS=N; the real CutActor → SwingArbiter → CutEffects → StatusEffects path):

- `cast_resolver_echo_waves_test.gd` (6): two echoes in place (square three), 12 + 6 + 6 with the third Hàn's
  burst, echo waves ignore Rạn (18 / 6 / 6, one stack left), determinism.
- `cast_resolver_keyword_cap_test.gd` (7): the centre first at 0.7 s with 25 + Hàn + heal 6, a 3-wide boss: one
  damage hit, one keyword-only drop, Hàn 2 (the cap), no clause no heal, determinism.
- `status_effects_death_mark_test.gd` (14): the mark applied / refreshed (mono 5 s, bar2 3 s), the next cast's
  12 then its echo 7.2 with the mark spent and no `swing_resolved` for the echo, execute ×2 under 30 % (24 + 7.2),
  the echo ignores Rạn (18 + 7.2), expiry, a scheduled parent (Đập Vỡ) echoes its last hit's cell, determinism.
- `cast_resolver_bounce_test.gd` (10): daggers 0.08 s apart with the corner first, a bounce onto the moved unit
  (2 hits, 20), leaving the mask escapes, the 2-hit cap (20 + 30 with the corner's Rạn), no Rạn without the L,
  determinism.
- `cast_resolver_row_pull_test.gd` (9): the hook's hit drags 2 toward the divider (one hit per cast), line_h 3 with
  the `pull_path` telegraph, a blocked pull slams (12 + 8, Pinned), ending on thorns pays the toll (18, +1 Rạn), a
  miss pulls nothing, determinism.

Integration: `batch4_flow_test.gd` (real CombatView flow, one scene per card: the bell's three waves and burst, a
pillar hit + Hàn, the mark then Kiếm Khí's echo, the bouncing daggers, the hook's drag with the telegraphed path).
FAILS=0.

Evidence (`production/qa/evidence/skill-v2-batch4/`, real ch1 battle vs Dire Wolf, Assassin, muted): the bell's
rings, the centre pillar (48: 25 + burn-free, the wolf stood on the hub), Dấu Tử then Kiếm Khí's echo (-7 after
the -6), the daggers' two hits, the hook's drag to the divider cell. The mark has no HUD chip or bracket yet
(Deferred 10). Re-capture: `godot --path . --windowed --resolution 1280x720 --audio-driver Dummy -s res://tests/integration/run/skill_v2_batch4_evidence.gd`.

### Full suite (`bash tools/qa/run_all_tests.sh production/qa/batch4-suite-2026-11-11.txt`)

Run 2026-11-11 (headless unit + integration, windowed ui): **271 tests, 271 green (FAILS=0, 0 script errors).**
The regression subset run before the commit had one find (Thiên Quang's `Cột`, fixed to `Trụ` before this run).
`skill_v2_golden_test` is green since the parent session's `V2_INSTANT_CARDS` fix; batch 4 adds no instant card.

## Left open

Deferred after 60/60 items 10–13 in `16-mvp-matrix.md` (the mark's HUD chip, the Awakening snapshot on echoes, the
pull path as a `path_rule`, the echo-and-Rạn rule to re-measure). With this batch every card of the bible is
playable; the remaining work is the deferred list, the VFX / audio signatures and the balance pass.
