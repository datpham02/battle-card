# Skill v2 — Phase 2: mechanics catalog

**Date:** 2026-11-07 · **Status:** PROPOSED · design only, numbers are starting values for the sim.
Every mechanic lists targeting, timing, resolution, counterplay, what it reuses and what it needs.
Ids `M01…` are referenced by the skill bible and the roadmap.

## 0. Global constraints (from ADR-0001 and the pack §1A)
Pickup / placement model, 4-card menu, min cells + cooldown, no energy · shape / delivery / impact separate ·
tile-exact floor telegraphs · one zone per cell, locked cells refuse casts · no untelegraphed path damage ·
holes, missing cells and valid movement respected · square-based VFX only.

---

## A. Foundations (no new card works without these)

### M01 Cast context
- **What:** one immutable record per cast, built in `CombatView._on_skill_chosen`: `{card, level, pieces:[{shape_id,
  canonical_key, rotation, cells, tags}], cells (union), cell_count, effective_cells, delivery, cast_mode,
  featured, caster_side, caster_cell, t_cast}`.
- **Why:** today `CutEffects.apply` receives only `cells`; shape and delivery never reach gameplay.
- **Reuses:** `CastPlan.piece_cells(i)`, `_make_cast_info` (already carries piece ids), `SkillDelivery.normalize`.
- **Needs:** pass the context through `CutActor.begin_swing` → `SwingArbiter._settle` → resolver; relics read the
  same record. Back-compat: absent fields = today's behaviour.

### M02 Impact schedule (authoritative per-cell timing)
- **What:** on swing resolve the resolver expands the cast into **impact events** `{cell, t, wave, kind, mult}` and
  resolves them in time order inside `SwingArbiter`'s time slicing.
- **Rules:**
  - `direct` with `resolve: "instant"` (all existing cards in MVP) → one wave, every cell at t = 0 → identical to today.
  - **One hit per unit per wave.** The first event of a wave that finds the unit applies the cast damage
    (`dpc × cell_count` × multipliers); later cells of the same wave skip that unit. Multi-cell bosses stay one hit.
  - Damage still scales with the cast's **total** cell count, not with the cells that happened to be under the unit.
  - Locked cells (cracking / hole) produce no event.
  - Engraving lights each cell at its event time, hit or miss.
  - Card-level "landed" (relic `on_cast_landed`, `huyet_an` miss cost, signature `on_hit`) fires once when the cast's
    last event resolves, with `hit = any event damaged the target`.
- **Interruption:** the first damaging event that hits the opponent cancels its running swing (today: the swing end).
  Events after the swing (fuse, trap, echo) interrupt only if the card says `interrupts: true`.
- **Cancellation:** if the caster's swing is interrupted, nothing is scheduled. Once resolved, scheduled floor objects
  persist until they fire or expire; they are cleared when the match ends or the caster dies.
- **Visual vs authority:** VFX reads the same schedule (`SkillDelivery.arrival_times`) and subscribes to
  `impact_resolved(cell, hit)`. Visual-only beats (projectile flight before t = 0, aftermath fades) never decide damage.
  Reduce motion changes visuals, never timing.
- **Reuses:** `SkillDelivery.arrival_times`, `normalize_timing`, `SwingArbiter` slicing, `CutActor.queue_swing` as the
  multi-hit precedent.
- **Needs:** a `CastResolver` (pure, tested) called by `SwingArbiter`; `CutEffects.apply` split into
  `damage_for(context, wave)` and `apply_event(event)`; sim calls the same resolver.

### M16 Shape classification and shape clauses
- **Tags per piece** (pure function of its physical cells, mirror-invariant, rotation-aware only where noted):
  | Tag | Rule | Library shapes |
  |---|---|---|
  | `mono` | 1 cell | mono |
  | `line` (+ `line_h` / `line_v` by rotation) | bbox width or height = 1, ≥ 2 cells | bar2–bar5 |
  | `square` | exactly 2×2 | square |
  | `L` | a line of ≥ 2 plus one end cell turned 90° (incl. mirrors) | l3, l4, j4, v5 (wide L) |
  | `T` | a line of 3 plus one middle cell | t4, y5 (also `branched`) |
  | `plus` | 5-cell cross | plus5 |
  | `S` | zig-zag (two offset dominoes) | s4, z4, n5, w5 |
  | `U` | u5 | u5 |
  | `P` | p5 | p5 |
  | `branched` | any cell with ≥ 3 neighbours | t4, y5, plus5, p5 |
  | `compact` | cells / bbox area ≥ 0.75 | square, p5 |
  | `odd` | Odd block (4–7 cells) | `odd:` ids |
- Derived numbers: `size`, `bbox`, `length` (longest straight run), `branch_count`, `centre` (cell nearest the
  bbox centre; ties → the cell nearest the hero).
- **Source of truth:** a data table `shape_tags.json` keyed by canonical key (computed tags as fallback for Odd).
  Mirror policy: tags use the smaller of the key and its mirror's key, so L and J share `L`. Placement stays
  rotation-only (no flip), as today.
- **Clause scope:** `any_piece` (default: at least one placed piece has the tag; separated pieces count separately),
  `all_pieces`, or `union` (the whole cast's cells, used sparingly).
- **Rotation matters** only for orientation tags (`line_h` = along the row toward the boss; `line_v` = a column).
- **Effective cells** (Trảm ×2) change damage only, never tags.
- **Resonance** (arena Featured Shape) is unchanged and separate: exact two-piece union match, numeric bonus +
  arena effect. Shape clauses change behaviour. Both may apply; combined multiplier cap ×3.
- **Size limit:** regular pieces 1–5 (library); 6–7 only Odd blocks with tag `odd` and a size tag. MVP keeps this.
- **Reuses:** `Piece.canonical_key`, `FeaturedShape.normalize / rotate_cells`. **Needs:** `ShapeTags` class + tests
  for every library shape and 50 random Odd blocks.

## B. Delivery rules (opt-in per card with `resolve: "arrival"`)

### M03 Projectile — `CASTER_TO_TARGET`
- **Targeting:** mask = placed cells. First cell = mask cell nearest the hero along its row (existing `first_link`).
- **Timing:** flight `travel_sec` (visual, before the swing end) → first cell at t = 0 → the rest by BFS through the
  mask, `step_sec` per step (existing `arrival_times`).
- **Resolution:** waves as M02. Option `burst_first: mult` — the first cell's event deals the cast damage × mult if the
  unit stands there (the "explodes strongly, then propagates" beat).
- **Counterplay:** the spread takes time; a boss at the far end of a long mask can step out before the front arrives.
- **Needs:** resolver uses arrival times; forecast shows the first cell brighter.

### M04 Ground propagation — `GROUND_PROPAGATION`
- **Targeting:** origin = mask cell nearest the hero; the front moves cell to neighbour cell inside the mask only.
- **Rule:** a **locked cell, hole, missing cell or pillar breaks the front**: mask cells reachable only through it get
  no event. Thorn and burn cells do not block (they are floor, not walls).
- **Timing:** Manhattan / BFS distance × `step_sec` (existing `ground_time`).
- **Counterplay:** the boss can stand behind a hole; the player can see cut cells as dim in the forecast.
- **Needs:** BFS with blockers in `SkillDelivery`; forecast draws cut cells dim.

### M05 Sky fall — `SKY_TO_TARGET`
- **Targeting:** each mask cell gets its own drop.
- **Timing:** a **ground shadow telegraph** on each cell from t = 0 (tile-exact square shadow that darkens), impact at
  `fall_sec` (0.35–0.6 s) + index × `stagger_sec`.
- **Resolution:** a drop hits whoever stands on its cell at impact. Each drop is its own wave, but one cast may hit a
  unit at most `max_hits` times (default 1 = "the first drop that finds you"; cards like Ngàn Kiếm raise it).
- **Shockwave variant (`shockwave`):** one big drop on the centre cell; its wave reaches the other mask cells
  `ring_step_sec` later, nearest first.
- **Counterplay:** read the shadow, leave the cell.
- **Needs:** shadow telegraph on the floor layer (reuse the enemy telegraph darkening), boss brain treats shadows as
  an incoming swing.

### M06 Sequential chain — `SEQUENTIAL_CHAIN`
- **Targeting:** mask cells in `chain_order` (`nearest_first`, `row_major`, `authored`, new `from_centre`).
- **Timing:** link i at i × `step_sec` (0.08–0.15 s).
- **Resolution:** default one hit per unit per cast (first link that finds it). Option `ramp`: each link after the
  first adds +X % to the next hit (cap), so long chains reward big shapes. Option `bounce`: links follow the unit
  if it moved onto another mask cell (still capped by `max_hits`).
- **Counterplay:** leaving the mask before the front reaches you.
- **Needs:** chain timing in the resolver; `CHAIN_ORDERS` gains `from_centre`.

### M17 Direct manifestation — `DIRECT_MANIFESTATION`
Stays instant (t = 0). It is the "certain but weaker" delivery: cards using it trade damage for no travel.

## C. Cast modes (from the rhythm spec, unchanged where specified)

### M07 Delayed (fuse) — `cast_mode: "delayed"`
- **Targeting:** the mask cells become **fuse cells** (zone kind `fuse`, one zone per cell, enemy half).
- **Timing:** `fuse_sec` (1.5) with a shrinking 3-2-1 floor mark; detonation is one wave at the end.
- **Resolution:** a unit on a fuse cell at detonation is hit with `dpc × cell_count × fuse_mult` (2.0); empty → miss.
  Fuses survive the caster being hit; cleared on caster death / match end.
- **Counterplay:** the boss brain treats fuse cells as an incoming swing and may step off; the player herds it.
- **Reuses:** zone books, `_claim_zone_cell`, telegraph painter. **Needs:** zone kind `fuse`, brain cost.

### M08 Multi-hit combo — `cast_mode: "combo"`
- **Timing:** `hits` (3) waves on the same mask, `hit_interval_sec` (0.12) apart, starting at the swing end.
- **Resolution:** each hit is a full hit (keywords, Rạn consumption, passive / signature hooks, defense per hit);
  combo counter per cast; crit `combo_3` on the 3rd+ hit.
- **Interruption:** the first damaging hit interrupts; later hits still land if the unit stays.
- **Counterplay:** flat defense and Guard reduce every hit; the boss can leave after the first hit.
- **Reuses:** `CutActor.queue_swing` precedent. **Needs:** waves in the resolver; damage-number stacking UI.

### M09 Trap — `cast_mode: "trap"`
- **Targeting:** mask cells on the enemy half, the enemy's own cells allowed (fires at once).
- **Rule:** cells become **trap cells** (zone `trap`) for `trap_sec` (8). The first enemy entry fires every trap cell
  of that cast once: `dpc × trap cells under the footprint` + keywords (Pin). Max 2 active trap casts per hero.
- **Counterplay:** traps are visible; boss path cost `trap_avoid`; the boss can wait them out.
- **Reuses:** thorn zone code (entry detection `_check_thorn_entries`), `ZoneRules.fit_cells`. **Needs:** zone kind
  `trap`, entry event, brain cost.

### M10 Ward (re-anchored on the hero) — `placement: "self_anchor"`
- **Targeting (revision 2, option A2):** pieces are placed on the enemy half as for every card. Choosing a ward card
  re-anchors the cast's shape (mirrored to face the hero's side) so its centre cell sits on the **hero's cell**, on
  the own half; off-grid, missing and locked cells are trimmed. The highlighted ward card previews the ghost. The
  enemy-half cells are not hit and do not light Engraving. See `02-design-decisions.md` §11.
- **Rule:** covered cells become **ward cells** (zone `ward`, player half) for `ward_sec`. Standing on one: incoming
  damage × `ward_mult`, heal `ward_heal_per_sec`, or the card's own effect (Guard, reflect).
- **Counterplay:** enemy telegraphs force the hero off the ward.
- **Needs:** a remap function (pure, tested), ward ghost preview in the menu highlight, zone kind `ward` on the player
  half. No placement half switch.

### M18 Parry (built)
Kept as built (`do_kiem`, `ParryGuard`). Becomes the template for timed windows.

## D. Field and space

### M11 Terrain manipulation
- **Kinds (MVP):** `pillar` (blocked cell, 3 s, enemy half, never under a unit), `mire` (step ×1.6 for 4 s, existing
  hazard), `ice_floor` (entering pins 0.4 s, ICD 2 s per unit), `burning` (existing burn cells; Mage fire wall makes
  them **block boss movement** for the wall's duration).
- **Rules:** through `ZoneRules.fit_cells` — the unit must keep at least one exit; one zone per cell (new replaces
  old); locked cells refuse. Player-made **holes** are Expansion (fairness risk).
- **Counterplay:** short durations; brain path costs.
- **Reuses:** `TileHazards.add_mire / add_sand`, `StatusEffects` zone books, `FairnessCheck`. **Needs:** zone kinds
  `pillar`, `ice_floor`; mover blockers.

### M12 Spatial manipulation
- **MVP:** `pull` (move the unit N cells toward a cell: the mask centre or the hero's row), `push` (built),
  `slam` (push / pull blocked by edge, hole, pillar or another unit → R3).
- **Expansion:** `swap` (hero ↔ an empty own-half cell mirrored, or boss ↔ a marked cell), `fold` (two cells linked so
  a hit on one also lands on the other, both telegraphed).
- **Rules:** forced moves are step-by-step, never through holes or missing cells, never into a hole unless a card
  says fall (none in MVP); a multi-cell boss moves only if every footprint cell is clear.
- **Reuses:** `CutEffects._push`, `UnitMover` blockers. **Needs:** generic `force_move(unit, dir, n)`.

### M13 Summons and temporary objects (Expansion)
- A **construct** zone on one empty cell (own half or enemy half by card), with an action timer (`every_sec`,
  `actions`), its own tile-exact telegraph before each action. It does not block the hero; the boss may destroy it by
  stepping on it (enemy half). No HP bars.
- **Needs:** zone kind `construct`, action scheduler on the resolver, art per construct.

### M14 Echo
- **Rule:** after the parent's last event, an **echo wave** repeats the cast on the same mask (or shifted 1 cell by
  `echo_shift`) after `echo_delay` (0.6 s) at `echo_mult` (0.5). The echo mask is telegraphed (pale outline) from the
  parent's resolve.
- **Anti-loop:** an echo never creates an echo, never charges the Awakening or Engraving, never triggers relic
  `on_cast` hooks, never consumes Rạn twice in one wave; max one echo child per cast unless the card says 2.
- **Snapshot:** echoes use the parent's cast-time modifiers (an Awakening started after the parent does not boost it).
- **Needs:** echo waves in the resolver; event tag `echo`.

## E. Status layer

### M15 Status reactions (MVP set)

| Id | Name | Trigger | Effect | Consumes | Priority |
|---|---|---|---|---|---|
| R2 | **Vỡ Băng** | a damage event on a **Pinned** unit that has **Rạn** | damage × 2.0 instead of × 1.5; Pin ends at once | 1 Rạn + the Pin | 1 |
| R1 | **Hơi Nước** | a unit on a **burning cell** gains **Hàn**, or a unit with Hàn enters / is ignited on a burning cell | burst 12 damage, ignores defense; the cell's burn is put out | 1 Hàn + that cell's burn | 2 |
| R3 | **Va Đập** | a forced move is blocked (edge, hole, pillar, unit) or ends on a thorn cell | 8 damage + Pin 0.6 s (thorn: thorns fire twice) | — | 3 |
| R4 | **Dẫn Điện** (Expansion) | a lightning hit on a unit standing on a **charged** cell | chains to every charged cell's unit, 50 % | the charges | — |

- **Storage:** burn per cell, Hàn / Rạn / Pin per side — each reaction reads the cell under the unit for burn.
- **Rules:** one reaction per event per unit; reaction events are tagged `reaction` and cannot trigger reactions,
  echoes, relic hooks, Engraving or Awakening charge; per-unit ICD 1.0 s per reaction id; bosses with `burn_eater`
  are immune to R1 (they heal from fire instead); `immune_status` lists on enemies apply.
- **Priority:** when one event satisfies several, R2 > R1 > R3; the others do not fire for that event.
- **Data:** `combat.json reactions{}` with numbers, ICD, immunity keys. **Needs:** `ReactionRules` (pure) called from
  the resolver and from status application points (`ignite`, `apply_frost`, `pin`, forced moves).

### M19 Conditions (crit and clauses)
`CritRules.CONDITIONS` grows: `target_burning`, `combo_3`, `target_on_hazard`, `self_hp_high` (rhythm spec), plus
`first_strike` (target not hit for 3 s), `target_marked` (has Rạn), `line_full` (a `line` piece of length ≥ 4).

---

## F. Dependencies and order

```
M01 cast context ─┬─ M16 shape tags ─────────────── shape clauses on every card
                  └─ M02 impact schedule ─┬─ M03 projectile / M04 ground / M05 sky / M06 chain
                                          ├─ M08 combo ─ M19 combo_3
                                          ├─ M07 delayed (needs zone kind fuse)
                                          ├─ M09 trap (zone kind trap + entry events)
                                          └─ M14 echo
zone kinds (fuse, trap, ward, pillar, ice_floor) ── M11 terrain ── M12 spatial (force_move) ── M15 R3
M15 reactions R1/R2 need only status hooks + M02 events
M10 ward needs placement half switch (independent of M02)
M13 summons need M02 scheduler + zone kind construct (Expansion)
Sim parity (resolver shared with sim_core) before any tuning
```

---

## G. Zone conflicts and replacement (revision 2)

**Layers.** (1) **Region terrain** from the arena (`TileHazards`: region mire, sand, vents, crumble, wind) is a
separate layer and is never replaced by card zones (as `mot-o-mot-hieu-ung-2026-11-01.md` already says). (2) **Cell
zones** — exactly one per cell: burn, fire wall, thorns, fuse, trap, ward, pillar, ice floor, card mire. (3) **Locked**
cells (cracking / hole) refuse every zone and every cast. (4) **Aftermath decals** (embers, stamps, scars) are VFX only,
not zones; they may overlap and never block anything.

**Classes.**
- **Armed** zones hold a pending trigger: `fuse`, `trap`. The player's own zones **cannot replace** an armed zone (the
  new zone simply skips that cell; damage of the cast still applies). Enemy zones and locks **can** replace it.
- **Solid** zone: `pillar` (blocks movement and zone placement). Nothing replaces it until it expires, except a lock.
- **Surface** zones: burn, fire wall, thorns, ice floor, card mire, ward — the newer replaces the older (existing rule).

**Same kind:** burn re-ignites (stacks / duration as today); fire wall refreshes and keeps `blocks_boss`; thorns,
ice floor, mire, ward refresh duration; a new fuse on a fuse resets its countdown (same owner); a new trap on a trap
refreshes `trap_sec`; pillar refreshes.

**Matrix — row = new zone, column = existing zone on the cell.** R = replaces, S = skipped (old kept), X = reaction
or special rule (numbered below), — = cannot meet (different halves).

| New ↓ / Old → | Burn | Fire wall | Thorns | Fuse | Trap | Ward | Pillar | Ice floor | Mire (card) |
|---|---|---|---|---|---|---|---|---|---|
| **Burn** | refresh | refresh (wall kept) | R | X1 | S | — (enemy burn: R) | S | X2 | R |
| **Fire wall** | R (wall) | refresh | R | S | S | — | S | X2 | R |
| **Thorns** | R | R | refresh | S | S | — (enemy thorns: R) | S | R | R |
| **Fuse** | R (re-ignites at detonation) | R | R | reset | S | — | S | R | R |
| **Trap** | R | R | R | S | refresh | — | S | R | R |
| **Ward** (own half) | R (own-half burn put out) | — | R (enemy thorns removed) | — | — | refresh | — | — | R |
| **Pillar** | R | R | R | S | S | — | refresh | R | R |
| **Ice floor** | X2 | X2 | R | S | S | — | S | refresh | R |
| **Mire (card)** | R | R | R | S | S | — | S | R | refresh |
| **Enemy zone / lock** | R | R | R | R + X3 | R + X3 | R | lock only | R | R |

- **X1 Burn on a fuse:** the fuse is **not** replaced; it keeps its countdown and will re-ignite the cell when it
  detonates. (Protects the Mage chain Hỏa Tuyến → Hỏa Lôi → Bùng Nổ.)
- **X2 Fire meets ice:** both are removed (a small steam puff, no damage). A unit standing there with Hàn instead
  triggers R1 Hơi Nước by the normal reaction rules.
- **X3 Disarm:** when an enemy zone or a lock removes a fuse or trap, its trigger is **cancelled** — no damage, the
  sigil / jaws play a 0.2 s fizzle and vanish, the countdown label is removed.

**Cleanup rules.** Replacing a zone removes its floor visual at once (no overlap) and starts the new one; pending
triggers die with their zone (X3); aftermath decals are not touched; a zone's expiry plays its own short fade. When the
caster dies or the match ends, all player zones and pending triggers are cleared without firing.

**Combo checks (must hold):**
- Mage: a fire wall and fuses on **different** cells coexist; burn landing on a fuse keeps the fuse (X1); Bùng Nổ
  detonates burning cells, not fuses (fuses keep their own timer).
- Hunter: thorns and traps never overwrite traps; Gai Nổ consumes thorns **and** traps inside its mask; Móc Kéo pulls
  onto them without changing them.
- Cleric: wards live on the own half, so the Cleric's enemy-half zones never touch them; only enemy zones and locks can
  remove a ward cell.

## H. Multiplier groups (revision 2)
See `02-design-decisions.md` §10. Summary: existing chain unchanged (relic fold keeps its own ×3 cap); new
**shape-clause group** S (burst-first, surge, ramp, centre, stem…) capped at ×2.0 and applied after crit; additive dpc
clauses capped at +3; echo multipliers (×0.5–0.6) and Dấu Tử are outside S (they scale a repeated wave, not a bonus).

## I. Dấu Tử (card-specific mark, revision 2)
A timed target status separate from Rạn. Rules in `02-design-decisions.md` §7: triggers on the first damaging cast,
adds one ×0.6 echo wave of that cast's last hit, never consumes or benefits from Rạn on the echo, ignores `combo_3`
and execute on the echo, max 3 echo waves per cast.
