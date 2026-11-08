# Skill v2 — Phase 2: implementation roadmap

**Date:** 2026-11-07 · **Status:** PROPOSED · nothing here is started. Phase 3 begins only after approval.

## 0. Before anything
- **Uncommitted Mage work** in the working tree (fireball pack, `unit_impacts`, `travel_impact_packs`, travel colours
  by impact, `square_fireball` component, tests): commit it (or shelve it on a branch) first. No step below may
  reset, overwrite or re-generate it.
- Golden baseline: record today's damage / status / zone events for all 32 cards on fixed boards (a new test
  `skill_v2_golden_test`) so every later step proves "existing cards behave the same unless their entry says so".

## 1. Stages, dependencies and complexity

| Stage | Content | Depends on | Size | Cards unlocked |
|---|---|---|---|---|
| **S0 Foundation** | M01 cast context through `CutActor` → `SwingArbiter` → `CutEffects`; M16 `ShapeTags` + `shape_tags.json`; card schema v2 fields (`shape_clause`, `resolve`, `placement`, `hits`, `fuse_*`, `trap_*`, `echo_*`, `max_hits`, `tags`) parsed with defaults; sim refactor so `sim_core` calls the real resolver | — | M | shape clauses on existing cards (data only) |
| **S1 Resolver** | M02 `CastResolver` + impact events + one-hit-per-unit-per-wave + interrupt at first damaging event; `CutEffects` split into `damage_for` / `apply_event`; VFX subscribe to `impact_resolved` | S0 | **H** (core) | — |
| **S2 Delivery rules** | M03 burst-first, M04 ground blocked by holes, M05 sky shadows + `max_hits` + shockwave, M06 chain ramp / bounce / `from_centre`; forecast shows cut cells and first cell | S1 | M | tram_dia, ngan_kiem, thien_thach, thien_quang, dia_chan, chuoi_set, thuong_xuyen, dap_vo, phi_tieu |
| **S3 Cast modes** | M08 combo + M19 crit conditions, M07 delayed (zone `fuse`), M09 trap (zone `trap`, entry events), M10 self placement + ward | S1 (+ zones) | M each | song_dao, lien_tram, hoa_loi, min_tre, bay_kep, bay_lo, thanh_thuan, khien_thep |
| **S4 Field and space** | M11 zones `pillar`, `ice_floor`, fire wall, mire card hook; M12 `force_move` pull / push / slam; brain path costs for every new zone | S1, S3 zones | M–H | tuong_da, vung_lay, hoa_tuyen, loc_cuon, moc_keo, chan_phong, suong_mong |
| **S5 Echo and reactions** | M14 echo waves + target-attached echo; M15 R1–R3 + `combat.json reactions` + anti-loop tags | S1, S4 (R3) | M | hoi_am, chuong_thanh, dau_tu, bang_vo, hoa_bang, gai_no, ran_van, kiem_than |
| **S6 Roster and run** | hero pools in `RewardRoller`, starters v2, unlock wiring (`achievements.json` for the 8 new unlockables), card texts vi/en, shape clause line on the card face and battle card, deck / starter tests | S0–S5 per card | M | all |
| **S7 VFX** | fxkit components V09–V21 (free), installs per card, evidence | per card after its rule | M per family | — |
| **S8 Cast clips (paid, approved per call)** | up to 15 MVP archetype clips, one hero at a time, one clip first | S7 for that hero | — | — |

Order inside S2–S5 follows the rhythm spec's risk order where it applies: combo → delayed → trap → parry (done) → ward.

## 2. Rollout batches (each one shippable, playtested, balanced)

| Batch | Contents | Why first |
|---|---|---|
| B1 | S0 + S1 + golden test; no new card | proves the resolver keeps today's game identical |
| B2 | Assassin: song_dao, lien_tram, phi_tieu, dau_tu (needs S5 echo — ship dau_tu in B5 if S5 lags) | combo is the lowest-risk new rule |
| B3 | Mage: hoa_loi, thien_thach, hoa_tuyen + min_tre | delayed + sky + ground rules |
| B4 | Hunter: bay_kep, moc_keo, gai_no + bay_lo, tuong_da, vung_lay, dia_chan | traps + terrain + pull |
| B5 | Knight + Cleric: tram_dia, ngan_kiem, thanh_thuan, chuong_thanh, thien_quang + khien_thep, hoi_am | ward placement + echo |
| B6 | Reactions and shared payoffs: bang_vo, hoa_bang, chuoi_set, thuong_xuyen, dap_vo, loc_cuon + 4 reworks | needs everything above |
| B7 | Shape clauses on the 28 existing cards (data) + full sim pass | balance with the whole roster |

## 3. Technical feasibility per system (reuse → extend)

| System | Reuse | Extend |
|---|---|---|
| `CutEffects` | multiplier chain, keywords, push, zones | split per event; read the cast context; reaction hook |
| `SwingArbiter` | time slicing, interrupt rule | resolve scheduled events; interrupt at the first damaging event |
| `SkillDelivery` | arrival times, chain orders, `_l_path`, `path_rule` gate | blockers in BFS, `from_centre`, shockwave rings, `max_hits` |
| `CastPlan` | piece cells, union | expose per-piece data to the context |
| `FeaturedShape` | normalize / rotate / matches | shared helpers for `ShapeTags`; Resonance unchanged |
| `ParryGuard` | timed window pattern | template for fuse / ward / echo timers |
| `StatusEffects` | zone books, `_claim_zone_cell`, `unlocked_cells`, burn per cell | zone kinds `fuse`, `trap`, `ward`, `pillar`, `ice_floor`, fire wall; entry events for traps; reaction hooks |
| `ZoneRules` | `fit_cells`, `cast_drop`, `cast_thorns` | `cast_pillar`, `cast_trap`, `cast_fuse`, `cast_ward` with fairness |
| `CritRules` | condition list | `target_burning`, `combo_3`, `target_on_hazard`, `self_hp_high`, `first_strike`, `target_marked`, `line_full` |
| `CastVfx` / `FloorVfx` | per-hero / per-impact packs (`unit_impacts`), floor index | per-card pack keys; listen to `impact_resolved`; shadow / sigil / echo layers |
| `UnitAnimator` / `UnitLayer` | clip state machine, cast hold | `clip_for` picks a cast archetype by delivery / mode when present |
| fxkit | components, checks, timeline | V09–V21 components; timeline supports fuse, echo, trap trigger |
| Balance sim | `play_match`, bot | call the real resolver; model fuse dodging, traps, combo, ward, pulls, reactions; per-hero measures |
| `BossBrain` / `PatternController` | thorn / burn path costs | costs for fuse, trap, shadow, pillar, mire, ice floor; avoid ward-less telegraph abuse |
| `RewardRoller` | hero filter | offer hero cards to their hero |
| `PiecePlacement` | half validation | self-half placement for `placement: "self"` cards |

## 4. Testing requirements (per stage; tests written first and watched failing)
- **S0/S1:** golden test (32 cards, identical events / damage); one-hit-per-unit-per-wave on a 2×2 boss; interrupt at
  first damaging event; locked cells produce no event; sim and game resolver agree on 1,000 random casts.
- **S2:** ground front stops at a hole; sky shadow lets a stepping boss escape; `max_hits` cap; chain ramp cap;
  forecast shows cut cells.
- **S3:** rhythm spec acceptance criteria (combo 3 hits + `combo_3` crit; fuse misses an empty cell; trap fires once
  on entry; ward ×0.5 only on ward cells); self placement greys the right cards.
- **S4:** `fit_cells` always leaves an exit (property test on every arena); pull never crosses holes; multi-cell boss
  moves only when all footprint cells are clear; R3 on blocked moves.
- **S5:** echo never creates an echo, never charges Engraving / Awakening; reactions fire once per event, respect
  ICD and immunity (burn_eater); no infinite chain in a 10,000-event fuzz.
- **S6:** hero cards only in their hero's rewards; starters; texts fit the card face; unlock consistency test.
- **S7:** fxkit build checks (palette, alpha, no red, square only, determinism) + in-game screenshots retained in
  `production/qa/evidence/skill-v2/<card>/`.
- **Balance:** `deck_sim` ch1 40 seeds: every hero 35–65 %; per-hero measures in band (fuse hit 40–70 %, trap trigger
  50–80 %, combo 3rd-hit share, ward damage absorbed); no single card > 25 % of a hero's damage.
- **Full suite** green and bot matrix 0 violations before each batch closes.

## 5. Effort estimate (rough, for planning)

| Stage | Estimate |
|---|---|
| S0 + S1 | 3–5 days (core refactor + golden tests) |
| S2 | 2–3 days |
| S3 | 3–4 days (four modes) |
| S4 | 3–4 days |
| S5 | 2–3 days |
| S6 | 2 days |
| S7 | ~0.5 day per card family (≈ 6–8 days total) |
| S8 | art, per approved call |

## 6. Open items for the user
See `02-design-decisions.md` §6 (Q1–Q13). Also: which batch to start with after B1 (recommended B2 Assassin), and
whether the Mage `cast_gesture` redraw waits for the archetype plan (recommended: yes, it becomes `cast_forward`).

---

## 7. Revision 2 — B1 (Foundation + Resolver) step order, as agreed by the user
B1 adds **no new skill** and must leave every existing card behaving exactly as today.

1. **Protect the uncommitted Mage work** — checkpoint option chosen by the user (`02-design-decisions.md` §12;
   recommended: full suite, then one dedicated commit on `main` by path). Nothing reset, discarded or regenerated.
2. **Golden tests for the 32 existing cards** — fixed boards (3×3, 5×5 with holes, 2×2 boss), each card at 1, 3 and
   5 cells: record cells hit, event times (all at the swing end today), damage, statuses, zones, interrupts, Engraving.
   Watched passing on today's code before any refactor.
3. **Cast context** — build M01 in `_on_skill_chosen`, pass it through `CutActor` → `SwingArbiter` → `CutEffects`
   (read-only for now); `ShapeTags` + `shape_tags.json` with unit tests for every library shape; schema v2 fields
   parsed with defaults, unused.
4. **Impact schedule** — `CastResolver` producing waves / events; `instant` cards produce one wave at the swing end;
   one-hit-per-unit-per-wave; interrupt at the first damaging event (identical timing for instant cards); VFX
   subscribe to `impact_resolved`; sim calls the same resolver.
5. **Re-run** — golden tests unchanged and green, full suite green, bot matrix 0 violations, sim numbers within noise
   of the pre-B1 baseline. Only then are new rules switched on (B2+).

Fallback tests (decisions §13) and the no-option 0.5 s auto-cast land in B1 as well, since they touch `CutFlow` only.

## 8. Progress log

| Date | Step | State | Where |
|---|---|---|---|
| 2026-11-08 | B1 cast context, resolver wave, Q10 fallback | committed + pushed `986874b` | `03-b1.5-validation-report.md` |
| 2026-11-08 | B1.5 ShapeTags `compact`, frozen context, scheduled waves | committed + pushed `986874b` | `03-b1.5-validation-report.md` |
| 2026-11-08 | **Trảm Địa** (first advanced skill): gameplay, `cast_forward`, eruption VFX | **approved**; Android QA pending | `skill-checklist.md`, reports 04–06 |
| — | Ngàn Kiếm | not started (waits for the user) | — |
