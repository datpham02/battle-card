# Skill v2 batch 3 report (2026-11-11)

Seven blocked cards from `16-mvp-matrix.md` are playable on three shared modules of `15-sprint-60-plan.md` §3:
M09 trap zones with an entry trigger, M10 wards re-anchored on the hero, M11 terrain (pillars, fire wall) — plus the
zone queries Gai Nổ needs. Playable count: 48 → **55 / 60**. Nothing committed. The user commits.

## The field-zone book

`StatusEffects` gained one more zone book, `_fields` (side → cell → {kind, left, total, cast_id, data}) for the
kinds `trap`, `ward` and `pillar`, next to burn / thorns / drop tiles. Every placement goes through the existing
one-zone-per-cell gate (`_claim_zone_cell`), extended with the catalog's §G matrix: an **armed trap** or a **solid
pillar** is never replaced by another player zone (the new zone skips the cell; the same kind refreshes), a **lock**
(drop tile crack) removes any field — a trap without firing (X3 disarm) — and a surface field (ward) is replaced like
thorns. `zone_applied` / `zone_expired` carry the new kinds for the floor layer; `zone_kinds_at` lists them.
Burning cells may carry a `wall` flag (`ignite(..., wall)`, `is_fire_wall`, `wall_cells`).

| Card | Bible | New data on the card | Where the rule lives |
|---|---|---|---|
| `bay_kep` Bẫy Kẹp (Hunter, common) | trap 8 s; the first entry fires every cell: dpc × cells under the footprint + Pin 1.2; `line_v` → Pin 1.6; cast on the enemy's cell fires at once; max 2 | `cast_mode: "trap"`, `effect: "trap"`, `trap_sec 8`, `trap_pin_sec 1.2`, `max_active 2`, `shape_clause {line_v, trap_pin_sec 1.6}`, `resolve: waves, hits 1` | `CutEffects._form_field` arms the cells on the enemy half (`apply_field`, one cast id, data dpc / pin / push / r3 / skill id); `StatusEffects._check_thorn_entries` → `fire_trap` on the first entry (a multi-cell boss: the first new footprint cell that holds a trap, `_entered_cell`); the unit already standing there fires it at once (the card result is a hit). `SkillAvailability`: `max_active` now caps any card through `CTX_ARMED_COUNT_FN` (CombatView / sim add `trap_cast_count`). `BossBrain`: trap cells cost `trap_avoid` (falls back to `thorn_avoid`) × dpc like thorns. |
| `bay_lo` Bẫy Lò Xo (shared, common) | trap 8 s; entry → push 2 away from the divider, R3 if blocked | `trap_push_cells 2`, `reactions ["r3"]`, dpc 3 | `fire_trap` pushes with `CutEffects.push_away`; a short push slams with the card's R3 numbers. |
| `gai_no` Gai Nổ (Hunter, epic) | detonates every player thorn / trap cell in the mask: 6 per detonated cell under the footprint (one hit), +1 Rạn per cell, zones consumed; `branched` → tips regrow thorns 2 s | `detonate_zones: true`, dpc 6, `fragile_per_cell 1`, `shape_clause {branched, regrow_sec 2}` | `CutEffects.apply`: the detonated cells (`thorns_at` / `field_at` kind trap) are cleared (`clear_thorn_cell`, `remove_field`), the damage path runs on them with `cast_cell_count` = cells under the footprint, Rạn = per cell; no field = a miss; `_regrow_tips` lays thorns on the mask's 1-neighbour cells with the match's thorn numbers. |
| `thanh_thuan` Thánh Thuẫn (Cleric, common) | re-anchored on the hero (A2); ward 4 s: damage ×0.5, +2 HP/s; the enemy not hit; `square` → each softened hit gives the attacker +1 Hàn | `placement: "self_anchor"`, `effect: "ward"`, `ward_sec 4`, `ward {damage_mult 0.5, heal_per_sec 2}`, `shape_clause {square, attacker_frost 1}` | `WardAnchor.remap` (new, pure): the placed shape mirrored across the divider, its ShapeTags centre on the hero's cell, trimmed to the own half and unlocked cells, never empty. `CombatView._on_skill_chosen` and the sim's cast remap the cells when the card is chosen; `_form_field` lays the ward on the caster's half. `StatusEffects.ward_absorb` (mult, then Guard, then attacker Hàn with its burst) is called by `CutEffects.apply` for boss block swings on the hero and by `PatternController` for pattern skills; `_tick_fields` heals the hero standing on a ward. |
| `khien_thep` Khiên Thép (shared, common) | ward: Guard 6; `line_v` → immune to push on it | `ward {guard 6}`, `shape_clause {line_v, push_immune true}` | the same hook (flat −6, minimum 1); `CutEffects.apply` skips a push on a `push_immune` ward (`ward_push_immune`). |
| `tuong_da` Tường Đá (shared, rare) | empty mask cells → pillars 3 s (blocked, never under a unit, an exit remains); `line` → 4 s; pillars cause R3 | `effect: "pillar"`, `pillar_sec 3`, `shape_clause {line, pillar_sec 4}` | `_form_field`: the mask's empty, unlocked enemy-half cells through `ZoneRules.fit_cells` (the target keeps one exit) → `apply_field` pillar. Both movers get `is_pillar` as a blocker (`CombatView._wire_zones`, the sim); `BossBrain` treats pillars as blocked cells. `CutEffects._push` now takes the target mover's blocked test, so a push into a pillar (or a hole) stops short — an R3 slam for cards that list it (Địa Chấn into a pillar: 15 + 8). |
| `hoa_tuyen` Hỏa Tuyến (Mage, rare) | floor fire from the cell nearest the hero (holes stop it), hits, burns 3 s; `line` → the burning cells are a fire wall that blocks the boss (an exit remains) | `resolve: arrival` GROUND, dpc 4, `event_payload {ignite 3 s}`, `shape_clause {line, fire_wall true}` | M04 (batch 2) runs the floor; `SwingArbiter._fire_event` lights the wall cells with `wall = true` after `ZoneRules.fit_cells` on the target's standing cell (the cell it needs as an exit burns without blocking); the ENEMY's mover refuses `is_fire_wall` cells (CombatView, sim). |

Cross-cutting:

- **Scheduled zone cards.** The five instant-looking cards (traps, wards, pillar) use `resolve: waves, hits 1` (one
  event of every cell at the swing end) rather than `instant`, so the legacy golden set keeps its 33 cards.
  `SCHEDULED_EFFECTS` += `trap` / `ward` / `pillar`, `cast_mode: trap` is a scheduled mode, and
  `CutEffects.can_affect` lets the arbiter resolve a field or detonating event with no unit inside (the zone forms
  hit or miss). The card-level result of a scheduled cast now carries `zone_kind` / `zone_cells`.
- **No MISS marker for a zone-only cast**: `CombatView._on_swing_resolved` skips the HUD marker when a ward / pillar /
  trap formed without a hit (the zone is the feedback).
- **Pushes respect blocked cells.** `CutEffects._push` stops at a cell the target's mover refuses (pillar, hole),
  per M12 "never into a hole"; before, only the half's edge stopped it. The golden fixture's `edge_push` /
  `hit3_hole` cases run without a blocked test and are unchanged.
- **Card placement.** `placement: "self_anchor"` is validated (`SkillConfig.PLACEMENTS`); `is_self_anchored` is the
  one query. Hero cards (`bay_kep`, `gai_no`, `thanh_thuan`, `hoa_tuyen`) are appended after `card_order`; the shared
  ones sit `…, vung_lay, khien_thep, thuong_xuyen, …, loc_cuon, tuong_da, bay_lo, hoi_am, …` (the bible's order).
  Zone cards (`trap` / `ward` / `pillar` joined `ZONE_EFFECTS`) and trap-mode cards are never the boss's.

## Files

Changed (user-approved 2026-11-11): `src/combat/status_effects.gd` (field book, `fire_trap`, `ward_absorb`,
`ward_push_immune`, `is_pillar`, `is_fire_wall` / `wall_cells`, `trap_cast_count`, `clear_thorn_cell`,
`remove_field`, the §G claims, `ignite(wall)`), `cut_effects.gd` (`_form_field`, detonate, ward hook, push immunity,
`_push(blocked_fn)`, `push_away`, `can_affect`), `cast_resolver.gd` (scheduled effects / cast modes, clause keys
`trap_pin_sec` / `regrow_sec` / `attacker_frost` / `push_immune` / `pillar_sec` / `fire_wall`, `max_active` on a trap
card), `skill_config.gd` (effects, `cast_mode trap`, `placement`, `ward`, the trap / pillar numbers, `id`),
`skill_availability.gd` (cap for any `max_active`), `swing_arbiter.gd` (fire wall on the ignite payload, zone keys on
the card-level result), `combat_view.gd` (ward remap on choose, pillar / wall blockers, trap count in the context, no
MISS for a zone-only cast — string edits beside the VFX session's V4 hunks), `pattern_controller.gd` (ward hook),
`boss_brain.gd` (pillars blocked, `trap_avoid`), `tools/balance/sim_core.gd` (remap, blockers, trap count),
`src/run/card_text.gd` (placeholders), `assets/data/cards.json`, `assets/i18n/strings.csv` (21 CRLF rows),
`tests/unit/combat/deck_power_test.gd` (55 cards: 29 / 17 / 9; the shared zone count read from the data),
`cast_scheduler_test.gd` (+7 ids), `docs/skill-v2/16-mvp-matrix.md` (Deferred 6–9).

New: `src/combat/ward_anchor.gd`; `tests/unit/combat/status_effects_trap_test.gd`, `cut_effects_detonate_test.gd`,
`ward_anchor_test.gd`, `status_effects_ward_test.gd`, `status_effects_pillar_test.gd`, `cast_resolver_fire_wall_test.gd`;
`tests/integration/run/batch3_flow_test.gd` (the 7 cards, one scene each); `tests/integration/run/skill_v2_batch3_evidence.gd`;
`production/qa/evidence/skill-v2-batch3/01..07.png`.

Not touched: `src/art/**`, `assets/art/**`, `src/battle/**`, audio, `combat.json`, `zone_rules.gd` (reused as is).

## Tests

Unit (deterministic, FAILS=N; the real CutActor → SwingArbiter → CutEffects → StatusEffects path):

- `status_effects_trap_test.gd` (13): arms then fires on entry (6, Pin 1.2, consumed), line_v Pin 1.6, own-cell snap,
  the spring fling 2 and the edge slam (3 + 8, Pin 0.6), the cap (field_cap, per card), a crack disarms without
  firing, burn / thorns never overwrite a trap, a trap refreshes a trap, determinism.
- `cut_effects_detonate_test.gd` (9): thorns under the boss → 6 + 1 Rạn, a thorn + a trap under a 2-cell boss → 12 + 2
  Rạn in one hit, no field = miss, fields outside the mask stay, the branched tips regrow 2 s, the arbiter path.
- `ward_anchor_test.gd` (8): mirror, centre on the hero, edge / divider / locked trimming, never empty, determinism.
- `status_effects_ward_test.gd` (12): the ward forms on the own half without hitting, 12 → 6 taken, +2 HP/s, the
  square clause chills the boss, Guard 6 (6 and the minimum 1), push immunity on a column only, expiry, off-ward hits
  are plain, determinism.
- `status_effects_pillar_test.gd` (11): empty cells only (not under the boss, not cracking), the mover refuses a
  pillar, Địa Chấn into a pillar slams (23), the corner boss keeps one exit, line 4 s / else 3 s, expiry, burn never
  overwrites a pillar, a crack removes it, determinism.
- `cast_resolver_fire_wall_test.gd` (9): a vertical line burns as a wall and blocks the boss, an L burns without
  blocking, the boss's last exit burns without being a wall, the wall goes out with the burn, determinism.

Integration: `batch3_flow_test.gd` (real CombatView flow, one scene per card: the trap snapping on the boss's
entry, the spring fling + slam at the edge, the thorn burst, the ward around the hero halving 12 and healing, Guard 6,
3 pillars the boss's mover refuses, the fire-wall column). FAILS=0.

Evidence (`production/qa/evidence/skill-v2-batch3/`, real ch1 battle vs Dire Wolf, Hunter, muted): the field zones
have no floor drawing yet (Deferred 7), so the frames show the HUD effects over the shared delivery impacts: the snap
(Frozen chip, -6), the fling (the wolf flung to the edge), the burst (Rạn chip), the wards (the hero's HP line), the
pillars (3 impact stamps on the empty row), the wall column lighting. Re-capture:
`godot --path . --windowed --resolution 1280x720 --audio-driver Dummy -s res://tests/integration/run/skill_v2_batch3_evidence.gd`.

### Full suite (`bash tools/qa/run_all_tests.sh production/qa/batch3-suite-2026-11-11.txt`)

Run 2026-11-11 (headless unit + integration, windowed ui): **263 tests, 262 green (FAILS=0, 0 script errors), 1 red.**

| Test | FAILS | Cause | Red before the batch? |
|---|---|---|---|
| `tests/unit/combat/skill_v2_golden_test.gd` | 2 (33 instant cards vs the fixture's 32; 640 vs 660 cases) | `vung_lay` (previous agent); batch 3 adds no instant card and no result key to legacy results. | **Yes** (since before batch 1). |

Due to the batch: **0** (the two glossary terms the batch-3 strings used, `Cột` / `Column`, were caught by the
regression subset before this run and fixed: `terminology_scan_test` green). Red before the batch: **1** (golden,
untouched).


## Left open

Deferred after 60/60 items 6–9 in `16-mvp-matrix.md` (ward ghost preview, floor drawing for the field zones, trap
damage vs defense, Bùng Nổ on a wall / trap fling into a pillar). Also: `skill_v2_golden_test` stays red from before
batch 1 (`vung_lay`; batch 3 adds no instant card). Remaining blocked cards: `moc_keo`, `chuong_thanh`, `dau_tu`,
`thien_quang`, `phi_tieu` (5 → batch 4: hook + path telegraph, mark echo, Hàn cap + heal, bounce).
