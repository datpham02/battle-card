# Skill v2 batch 2 report (2026-11-11)

Six more blocked cards from `16-mvp-matrix.md` are playable, on four shared modules of `15-sprint-60-plan.md` §3:
M04 ground run stopped by holes, M05 shockwave, M12 pull + R3, M14 echo, M15 reactions R1 / R2 (card-listed).
Playable count: 42 → **48 / 60**. Nothing committed. The user commits.

## Cards and fields

| Card | Bible | New data on the card | Where the rule lives |
|---|---|---|---|
| `dia_chan` Địa Chấn (common) | tremor from the cell nearest the hero, stopped by holes; hit → push 1; `line` → push 2; blocked → R3 | `effect: push` on `resolve: arrival` (GROUND_PROPAGATION), `max_hits 1`, `shape_clause {tag: line, push_cells: 2}`, `reactions: ["r3"]` | `CastResolver.SCHEDULED_EFFECTS` += `push`; `_arrival_events` drops locked cells and a GROUND run reaches only the open cells 4-connected to its start (BFS; the start = the open cell nearest the origin). `CutEffects.apply`: a clause `push_cells` that holds replaces the card's; `_push` now returns the cells moved and a short move slams (`_react_r3`) when the card lists r3. |
| `loc_cuon` Lốc Cuốn (rare) | pulls a unit inside or next to the mask 1 toward the centre, then hits; `square` → pull 2 + Pin 0.4; blocked → R3 | `pull_cells 1`, `shape_clause {tag: square, pull_cells: 2, pin_sec: 0.4}`, `reactions: ["r3"]`, `resolve: waves, hits 1` (one scheduled event of every cell; keeps the legacy golden set unchanged) | `CutEffects.pull_toward` (axis of the larger offset each step, never off the half / onto a blocked cell / where the footprint does not fit) runs BEFORE the hit is judged for a unit inside or 4-adjacent; a refused step → R3. Clause `pin_sec` pins on the hit. `CutEffects.can_affect` lets the arbiter resolve an event whose unit is only adjacent (pull cards). |
| `bang_vo` Băng Vỡ (rare) | Rạn before the damage, so a Pinned target triggers R2 | `fragile_stacks 1`, `fragile_timing: "before"`, `reactions: ["r2"]`, `resolve: arrival` SKY (one drop per cell) | `CutEffects.apply`: the card's Rạn lands before its own hit spends one (never again in `_apply_keywords`); R2: Pinned + Rạn → × `reactions.r2.mult` instead of the Rạn multiplier, the stack is spent, `StatusEffects.end_pin` (new). |
| `hoa_bang` Hỏa Băng (epic) | ignites the mask and adds 1 Hàn on hit → R1 Hơi Nước | `effect: damage` dpc 3, `frost_stacks 1`, `event_payload {ignite 2 s}`, `reactions: ["r1"]`, `resolve: waves, hits 1` | `CutEffects.try_r1`: a hit that gave Hàn while the target stands on a burning cell bursts `reactions.r1.burst_damage` straight to HP (ignores defense), `clear_burn` on that cell, `StatusEffects.consume_frost` (new) spends 1 Hàn. Called inside `apply` (target already on fire) and by `SwingArbiter._fire_event` right after the event's ignite payload (the card lights the cell it just chilled). |
| `thien_thach` Thiên Thạch (Mage, epic, hero reward) | meteor on the centre 0.6 s ×1.5, shockwave ring by ring 0.1 s, all cells burn 2 s; `plus` → every arm at once, centre ×2 | `resolve: arrival` SKY, `sky_mode: "shockwave"`, `sky_hover_sec 0.6`, `ring_step_sec 0.1`, `hub_mult 1.5`, `event_payload {ignite 2 s}`, `shape_clause {tag: plus, ring_step_sec: 0, hub_mult: 2}` | `CastResolver.shockwave_events`: hub = ShapeTags centre (ties nearest the caster) at hover × hub_mult (kind `hub`), rings at hover + BFS distance × ring_step_sec (kind `ring`; a cut-off cell by Manhattan distance), every event its own wave, `max_hits 1`. Clause keys `ring_step_sec`, `hub_mult`, `hub_all`. |
| `hoi_am` Hồi Âm (epic) | hit now, one echo at 60 % 0.6 s later shifted 1 cell toward the enemy's back edge (in place when invalid); `square` → two echoes | `resolve: waves, hits 1`, `echo {count 1, mult 0.6, delay_sec 0.6, shift 1}`, `shape_clause {tag: square, echo_count: 2}` | `CastResolver.echo_events` (kind `echo`, wave `hits + k - 1`, `shifted` flag); `plan()` takes a new `allowed` list = the target half's cells (SwingArbiter passes `grid.enemy_cells()` / `player_cells()`); the shift direction follows the cast context's side (+x player, −x boss; the arbiter adds the side to a context that lacks one, for planning only). `max_hits` grows by the echo count. |

Cross-cutting:

- **`event_payload` on every scheduled resolve.** Validation now allows a payload on `arrival` and `waves` (only an
  `instant` card is refused); `plan()` copies it onto every event. Hỏa Lôi / Mìn Trễ (delayed) keep the identical one
  event + payload.
- **Reactions are card-listed, numbers global.** `combat.json` gained `reactions {r1: {burst_damage 12}, r2: {mult 2},
  r3: {damage 8, pin_sec 0.6}}` → `CombatConfig.reactions()` → `SwingArbiter.reactions` → `CutEffects` options
  (built-in defaults when absent). A card opts in with `reactions: [...]` (SkillConfig validates r1 / r2 / r3).
  The catalog (M15) describes R1–R3 as global rules; they are **not** global here, on purpose: `skill_v2_golden_test`
  pins `hit3_ran_pinned` and `edge_push` scenarios for the 33 legacy cards, so a global switch changes every old
  card's result. Turning them global is a balance decision for the user; the data path is ready (list the id on the
  card, or flip a future global flag). Not built: the R1 trigger "a unit with Hàn enters / is ignited on a burning
  cell" (needs a hook in StatusEffects' burn entry), the per-unit 1.0 s reaction ICD, `burn_eater` / `immune_status`
  checks, R3 on thorn-cell endings.
- **Only one shape clause per card.** Thiên Thạch's `square → all four cells are the centre` is not on the card (the
  `plus` clause is); the `hub_all` clause key exists for it when the data format allows two clauses.
- **Card order:** `…, do_kiem, dia_chan, vung_lay, thuong_xuyen, dap_vo, chuoi_set, loc_cuon, hoi_am, min_tre, bang_vo,
  hoa_bang`; `thien_thach` is a hero card (appended automatically, Mage rewards). "Unlockable" cards (`loc_cuon`,
  `hoi_am`, `bang_vo`, `hoa_bang`) have no `unlock_by` (the bible names no source).
- **Boss use:** `dia_chan`, `loc_cuon`, `bang_vo`, `hoa_bang`, `hoi_am` are shared `direct` cards, so the block-brain boss
  may draw them; the pull / push / echo paths are side-agnostic (the player can be pulled toward a boss mask's centre,
  an echo shifts −x for the boss). Not sim-tuned yet.

## Files

Changed (user-approved 2026-11-11): `src/combat/cast_resolver.gd`, `skill_config.gd`, `cut_effects.gd`,
`swing_arbiter.gd`, `status_effects.gd` (`consume_frost`, `end_pin`), `combat_config.gd` (`reactions`),
`combat_view.gd` (one line: `_arbiter.reactions`), `src/run/card_text.gd` (placeholders `clause_push_cells`,
`pull_cells`, `clause_pull_cells`, `clause_pin_sec`, `r1_burst`, `r2_mult`, `r3_damage`, `r3_pin_sec`, `hub_mult`,
`clause_hub_mult`, `ring_step_sec`, `echo_mult_pct`, `echo_delay_sec`, `echo_shift`, `echo_count`, `clause_echo_count`;
`{fuse_sec}` shows `sky_hover_sec` on a non-delayed card), `assets/data/combat.json` (`reactions`),
`assets/data/cards.json`, `assets/i18n/strings.csv` (18 CRLF rows), `tools/balance/sim_core.gd` (`arbiter.reactions`;
`cast_value` counts the mean shockwave multiplier, the echo waves × `ECHO_STAY_EXPECT` 0.5, R2 on a pinned boss),
`tests/unit/combat/deck_power_test.gd` (48 cards: 25 common / 15 rare / 8 epic), `cast_scheduler_test.gd` (the 6 new
non-instant ids), `keyword2_test.gd` (push cards sit under the common dpc band like chan_phong / xung_kich).

New: `tests/unit/combat/cast_resolver_ground_push_test.gd`, `cut_effects_pull_test.gd`, `cut_effects_reaction_r2_test.gd`,
`cut_effects_reaction_r1_test.gd`, `cast_resolver_shockwave_test.gd`, `cast_resolver_echo_test.gd`;
`tests/integration/run/dia_chan_flow_test.gd`, `loc_cuon_flow_test.gd`, `bang_vo_flow_test.gd`, `hoa_bang_flow_test.gd`,
`thien_thach_flow_test.gd`, `hoi_am_flow_test.gd`; `tests/integration/run/skill_v2_batch2_evidence.gd` (windowed
capture); `production/qa/evidence/skill-v2-batch2/01..06.png`.

Not touched: `src/art/**`, `assets/art/**`, `src/battle/**`, audio files, Hỏa Lôi / Ngàn Kiếm / Trảm Địa data and tests.

## Tests

Unit (deterministic, FAILS=N), through the real CutActor → SwingArbiter → CutEffects path unless noted:

- `cast_resolver_ground_push_test.gd` (14): data, run order from the hero, a hole stops the run (bar3 and an L cut in
  two), push 1 (L) / line push 2 (bar3), the edge slam 15 + 8 with the Pin, chan_phong never slams, determinism.
- `cut_effects_pull_test.gd` (12): `pull_toward` steps and blocking, an adjacent unit pulled in then hit, square pull 2 +
  Pin 0.4, a far unit untouched, a blocked pull slams without a hit, the arbiter path, determinism.
- `cut_effects_reaction_r2_test.gd` (9): R2 30 on a Pinned foe with the Pin ended and the stack spent, 22.5 unpinned,
  kiem_khi keeps ×1.5 + Pin, the sky-arrival path, determinism.
- `cut_effects_reaction_r1_test.gd` (10): 10 (defense 2) + 12 (no defense) with the boss's cell put out and 3 burning,
  a target already on fire reacts in `apply`, a miss ignites without a reaction, han_kiem never bursts, determinism.
- `cast_resolver_shockwave_test.gd` (13): hub then rings (0.6 / 0.7 / 0.8), a cut-off cell by Manhattan distance, the
  plus clause all at 0.6 with the hub ×2, 42 on the hub / 28 on the far ring at 0.8 s, the payload lights ring by ring,
  determinism.
- `cast_resolver_echo_test.gd` (12): echo +1 at 0.6 ×0.6 (max_hits 2), in place at the edge, square → 2 echoes, the
  boss's echo shifts −x, 15 + 9 on a unit that stayed / 15 when the shifted echo misses, determinism.

Integration (real CombatView flow, bag → place → menu → choose; the enemy half is 3 cells wide there):
`dia_chan_flow_test` (run scheduled outward, line push 2 stopped by the edge → R3 reported, 23),
`loc_cuon_flow_test` (square pull onto the centre + Pin 0.4; a t4 pulls an adjacent boss 1), `bang_vo_flow_test`
(30 with the Pin ended, then 22.5 unpinned), `hoa_bang_flow_test` (12 + 12, Hàn spent, the boss's cell out, 3 burning),
`thien_thach_flow_test` (hub first at +0.6 s, one hit with the cell's multiplier, 4 cells burning), `hoi_am_flow_test`
(hit now, echo 0.6 s later in place ×0.6, 15 + 9). All FAILS=0.

Evidence (`production/qa/evidence/skill-v2-batch2/`, real ch1 battle vs Dire Wolf, Mage, boss_defense 1):
`01-dia-chan-push-slam.png` (HIT -14, the wolf pushed 2 cells by the line clause), `02-loc-cuon-pull-to-centre.png`
(HIT -15, pulled onto the square's centre, Frozen chip), `03-bang-vo-shatter.png` (HIT -29 on the Frozen wolf),
`04-hoa-bang-steam.png` (HIT -11 then the burst, 3 cells burning, the wolf's cell out), `05-thien-thach-shockwave.png`
(HIT -41 on the hub, the hub lit), `06-hoi-am-echo.png` (the echo HIT -8). Re-capture:
`godot --path . --windowed --resolution 1280x720 --audio-driver Dummy -s res://tests/integration/run/skill_v2_batch2_evidence.gd`.

### Full suite (`bash tools/qa/run_all_tests.sh production/qa/batch2-suite-2026-11-11.txt`)

Run 2026-11-11 (headless unit + integration, windowed ui): **255 tests, 253 green (FAILS=0, 0 script errors), 2 red.**

| Test | FAILS | Cause | Red before the batch? |
|---|---|---|---|
| `tests/unit/combat/skill_v2_golden_test.gd` | 2 (33 instant cards vs the fixture's 32; 640 vs 660 cases) | `vung_lay` (previous agent); batch 2 adds no instant card and no result key to legacy results. | **Yes** (since before batch 1). |
| `tests/unit/ui/terminology_scan_test.gd` | 2 (vi `Hàn` in `card.hoa_bang.desc` / `desc_battle`; en `runs` in `card.dia_chan.desc`) | Batch-2 strings used the old glossary terms. **Fixed after the run** (`Hàn` → `Giá Lạnh`, `runs` → `rolls`); re-run FAILS=0, `card_text_test` / `i18n_test` / `deck_power_test` FAILS=0, translations re-imported. | No — due to the batch, fixed. |

Due to the batch: **1, fixed after the run (terminology)**. Red before the batch: **1** (the golden test, untouched).


## Left open

The five open items below are **Deferred after 60/60** by the user's decision of 2026-11-11, in priority order in
`16-mvp-matrix.md` § "Deferred after 60/60"; none blocks 60/60.

- `skill_v2_golden_test.gd` red before batch 1 (33 instant cards vs the fixture's 32: `vung_lay`), untouched; batch 2
  adds no instant card (`loc_cuon` / `hoa_bang` / `hoi_am` are `waves`, the others `arrival`).
- Reactions global or card-listed: the user's call (see above). R1's second trigger, the ICD, immunities and thorn
  endings are not built.
- Thiên Thạch `square` clause (two clauses per card), the Mage's own cast clip; `cast_presentation` of the 6 cards is
  `hand` / `body` (the existing clips).
- VFX: shared packs draw the cards; kinds `hub` / `ring` / `echo`, the events' `pulled` / `push_from` / `reaction` /
  `reaction_damage` / `shifted` keys are there for the VFX session.
- Deferred to batch 3 (own modules): `moc_keo` (hook + path telegraph), `tuong_da` (pillar zone), `bay_kep` / `bay_lo` /
  `gai_no` (M09 traps), `thanh_thuan` / `khien_thep` (M10 wards), `chuong_thanh` / `dau_tu` (mark echo), `thien_quang`,
  `hoa_tuyen`, `phi_tieu`.
