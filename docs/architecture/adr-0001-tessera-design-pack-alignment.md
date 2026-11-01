# ADR-0001: Align the shipped game with the Tessera design pack

## Status

Accepted (by the user, 2026-11-01, with the amendments in "User amendments" below)

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**

## Date

2026-11-01

## Last Verified

2026-11-01

## Decision Makers

User (decisions D1–D7 and amendments A1–A6, 2026-11-01); drafted by Claude from the design pack audit (pack task A).

## Summary

The user added a design pack (`TESSERA_CLAUDE_DESIGN_PACK/`, `TESSERA_ALL_IN_ONE_FOR_CLAUDE.md`) written as if the
game did not exist yet, while the Godot 4.6 build already runs most of its scope (8 Wardens, branching region maps,
shops, treasure, rest, events, deck building, blocks). This ADR records which parts of the pack the build adopts,
which it keeps from the current game, the safe defaults for the pack's own ambiguities, and the phased order of work —
no part of the pack is implemented in one step.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 (4.6.3 installed) |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | LOW — data and design alignment, no new engine API |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None beyond the existing headless suites (`tests/README.md`) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | Future ADRs: enemy skill pattern model (phase 2), map generator v2 (phase 3), status and card schema v2 (phase 4) |
| **Blocks** | Phase 1–6 stories below until this ADR is Accepted |
| **Ordering Note** | Phases run in order; phase 1 is data/canon tidy-up and presentation polish only |

## Context

### Problem Statement

The pack (`00`–`07`, `cards.json`, `enemies.json`, `bosses.json`) proposes a full design: LOCKED world/visual canon,
a 5-tier map with fixed land pairs, 23 normal + 16 elite enemies with one signature pattern each, 8 Wardens with
3 phases × 7 skills, 180 proposed cards in 6 groups, and an energy/card-bar casting model. Several of these contradict
what is built and tested; implementing the pack literally would mean rebuilding combat. The user decided each conflict
on 2026-11-01 (D1–D7 below). Without a written record, later sessions would re-open the pack and "fix" the build back.

### Current State

See the audit digest of the build: real-time two half-grid combat; blocks drop on the player half and are picked up by
stepping; a block dropped on the enemy half opens a 4-card menu (cards cost a minimum cell count plus a cooldown, no
energy); 2-block joins, Resonant Shape, Engraving/Awakening, Interrupt, Focus; 5 floors of 2-of-7 random lands × 3
stages, then the Lattice Heart; 36 cards in a shared pool; ~6 normals + 1–3 elites per land, all enemies driven by one
block-placing AI (`BossBrain`) plus traits; Wardens with 1–2 traits; Pact levels, Spare/Kill, 3 endings, Luck,
achievements; 139 headless/windowed test files, all FAILS=0 on 2026-11-01.

### Constraints

- Keep the build playable and the test suite green after every phase.
- Data-driven: new content goes in `assets/data/*.json` + `assets/i18n/strings.csv`, never hard-coded.
- Pack canon marked LOCKED is not silently altered; a deliberate deviation is listed here with the user's decision.
- Art follows the pack's LOCKED visual grammar and `design/art/art-bible.md` (square-only magic, red only on enemy
  warnings, no wuxia).

### Requirements

- Every pack system the user adopted (D3–D5, D7) reaches the build through phased, testable stories.
- Every deviation from the pack (D1, D2 scope, D6) is recorded with its reason.
- The pack's internal ambiguities get a documented default so coding is not blocked.

## Decision

### User decisions (2026-11-01)

| # | Topic | Decision | Pack status |
|---|---|---|---|
| D1 | Casting model | **Keep the current input and combat logic** (drop/pick-up blocks, 4-card menu, min cells + cooldown, no energy). D1 covers *how the player chooses* a cast, not how it is shown: delivery is free per A1. Improve the block-on-floor and cast animation so it reads less rough. | Deviation from a PROPOSED system (pack `01` §3 marks it as a proposal, not canon) |
| D2 | Cards | **60 MVP cards first**, taken from the pack's 180 ideas and rewritten for D1 (numbers, shape rule, trigger, counterplay, upgrade, delivery). Grow the pool in batches after playtests. | Matches pack `00` step 6 and task D |
| D3 | Map | **Follow the pack**: 5 tiers with fixed land pairs (I Forest/Dungeon, II Tower/Swamp, III Sands/Hellfire, IV Sky Isles two routes, V Lattice Heart two routes), ~5-row DAG per land + Warden, separate Forge node. Keep Pact levels, Spare/Kill, endings, Luck, achievements (the pack is silent on them). | Adopted |
| D4 | Enemies | **Follow the pack**: 3 normals + 2 elites per land (Summit 2 + 2), one signature pattern and one counterplay each; elites add a rule, not just HP. | Adopted |
| D5 | Wardens | **Follow the pack**: 3 phases × 7 skills per Warden, phase change with a visible pause and no damage. | Adopted |
| D6 | Drop tiles | **Keep the 2026-10-31 rule** (`design/quick-specs/o-rot-thay-tuong-2026-10-31.md`): the boss may crack the cell the player stands on; standing on it when it falls is lethal, under the spec's fairness rules. | **Deliberate deviation** from pack `06` §2 "never convert an occupied cell into a pit" |
| D7 | Skill casting | **Pack updated by the user** (pack `01` §1A, LOCKED 2026-11-01): block shape (cell mask) / skill delivery (`CASTER_TO_TARGET`, `SKY_TO_TARGET`, `GROUND_PROPAGATION`, `DIRECT_MANIFESTATION`, `SEQUENTIAL_CHAIN`) / impact effect are separate; traveling square-based visuals allowed; the gameplay Block is never thrown; the path is animation only and deals no damage outside the target cells, unless a skill defines its own path rule and telegraphs it clearly (A1); every skill declares delivery, origin, travel, impact and cell mask; no default to sky-to-target. | Adopted (canon) |


### User amendments (2026-11-01, on accepting this ADR)

- **A1 — Skill Delivery, Block Shape and Impact Effect are independent.** The build must support all five delivery
  types (`CASTER_TO_TARGET`, `SKY_TO_TARGET`, `GROUND_PROPAGATION`, `DIRECT_MANIFESTATION`, `SEQUENTIAL_CHAIN`). Keep
  the working combat logic (D1), but structure the cast so that the cell mask (from the block shape), the delivery
  (origin + travel animation + timing) and the impact (per-cell effect) are separate data and separate code paths: a
  skill picks one of each, and none of them knows how the others are drawn. The travel is animation only; it applies
  no damage or status outside the target cells, **unless** the skill defines its own path rule and that path is
  telegraphed as clearly as the target cells. D1 does not conflict with this: D1 keeps the input model, A1 governs
  presentation and the resolve order.
- **A2 — Misty Forest roster:** keep Goblin Scout and the wolves (reuse the finished art) and **add** the pack's
  normals and elites (Rootling, Mossbound Sentry, Greycap Sporeling; elites Ancient Root Sentinel, Mistbriar Matron).
  Phase 2 work.
- **A3 — Pact levels 3 and 9:** unchanged for now; re-evaluate once map v2 is complete.
- **A4 — Final boss:** keep the current 2 phases for the prototype; the Warden phase/skill data model (phase 2) must
  extend to 3 phases × 7 skills without code changes, so the Heart Keeper can grow later.
- **A5 — Drop tiles:** implement exactly the 2026-10-31 spec, no rule changes. Add tests for the warning, the fall
  timing, collision (units on a falling cell, moving in and out during the warning) and every case that would leave
  the player no way to react (frozen, rooted, step cooldown, no safe neighbour, Focus).
- **A6 — Beat:** 0.5 s default, configurable in data, never hard-coded.
- **A7 — Boss size and occupancy (2026-11-01, Phase 2 decision D13):** Wardens are drawn 2–3× the hero's size and
  may occupy several cells instead of one (pack `01`/`03`/`04` say one logical tile; the pack allows multi-tile
  occupancy once approved — approved here). The footprint is data per enemy; a hit counts once per resolution however
  many footprint cells it covers. Footprint shape and boss arena size: see design/quick-specs/phase2-misty-forest-2026-11-01.md.
- **Process:** Phase 1 runs task by task; each task is finished and tested before the next starts. Later phases are
  not started without the user.

### Defaults for the pack's open ambiguities

| Ambiguity (pack) | Default until the user decides otherwise |
|---|---|
| "Beat" is never defined | Author timings in **seconds**. A pack "beat" converts through a data value `timing.beat_sec` (default **0.5 s**, in `assets/data/combat.json`), never a hard-coded constant (A6). |
| 4-cell bars and 4-long boss patterns on a 3×3 grid | A pattern that does not fit an arena is **unavailable** there (`canCast` false); clipping only when a skill is authored to clip. Arenas stay data-driven (`arenas.json`). |
| Which grid an anchor/hazard sits on | The **player's half** unless the skill states the enemy half. |
| Diagonal moves in counterplay text | No diagonal movement; rewrite those counters as orthogonal escapes. |
| Status lists differ between `01` and `06` | Phase 4 defines one list: existing Burn, Frozen, Fragile, Chill, Push, Execute, Pierce, Thorns + pack poison, root, mark, guard, echo, slow, each with cap and stacking rule, plus the anti-loop envelope (pack `06` §7). |
| Boss reward (artifact vs choice) | Keep the current boss reward + Spare/Kill relic choice. |
| "Elder Treant" named but not in the roster | Treat as an old name; use the roster in pack `03`. |
| Card rarity tracks cost | Rarity is set per card in the MVP pass on frequency/complexity, not cost. |
| Free actions sold as cards (rotate, preview, move) | Not carried into the MVP; rotation, preview and stepping stay free. |
| Hero names | Knight = Kiếm sĩ, Mage = Pháp sư, Rogue = Sát thủ, **Ranger = Thợ săn**, Cleric = Giáo sĩ. |

### Implementation Guidelines — phases

Each phase is one or more stories under `production/epics/`; each keeps the suite green.

**Phase 1 — canon, data and presentation tidy-up (low risk)**
1. Drop-tile story (D6, A5): `zones.hole_warn_sec`, `hole_reaction_margin_sec`, `hole_fall_lethal`, `seal_caster`
   may target the player cell under the fairness rules; tests for the warning, the fall timing, collision and every
   no-reaction case.
2. Remove the Wall cards from the player pool (`ket_gioi`, `long_an`, `luoi_san`): Hunter starter deck →
   `kiem_khi`×2, `tran_gai`×2, `gai_doc`, `ran_kich`; `boss_dungeon` reward → `gai_nguyen`; relic `phong_an` →
   Gai Dai (thorns +1 s). Per the 2026-10-31 spec.
3. Names: align Warden display names with the pack where they differ (Mist Tower Warden = Frost Lord); refresh
   `design/game-mechanics.md` to the in-game names; fix the Hunter text in `design/world-context.md`.
4. Delivery architecture (D7, A1, A6): split the cast into cell mask / delivery / impact (separate data and code
   paths) with all five delivery types available; add `delivery` (type, origin, travel, impact, cell mask) to every
   existing card and boss attack in data; `timing.beat_sec` in data; tests that no delivery path applies damage
   outside the cell mask unless the skill's own path rule is telegraphed.
5. Presentation (D1, D7): block-on-floor and cast pass following pack `01` §3 — target cells lit in the hero's block
   colour (full fill, 2 px outline, ✓ on the foe's cell), stepped charge brightening (no bloom), the skill's delivery,
   square impact on the cells. Sword cast: replace the curved crescent wave with a square-based streak and the oval
   burst base with a square cell flash. New art is PixelLab work, priced and approved per call.

**Phase 2 — enemy skill model + Misty Forest slice (D4, D5)**
- Data model for a signature attack pattern (anchor, rotation, offsets, warning start, resolve time, delivery),
  next to the existing `BossBrain`; pack `06` §6 move choice (`canHeroRespond`, avoid repeats, phase favour).
- Misty Forest per pack `03` and A2: keep Goblin Scout and the wolves, add Rootling, Mossbound Sentry, Greycap
  Sporeling; elites Ancient Root Sentinel, Mistbriar Matron; Forest Witch with 3 phases × 7 skills (pack `04`). The
  phase/skill model must also carry the final boss later (A4). Fairness test: every skill has a valid
  response on every Misty Forest arena.

**Phase 3 — map v2 (D3)**
- Tier pairs, ~5-row DAG per land ending in the Warden, Forge as its own node, pack `02`/`06` §4 constraints
  (battle first, no elite before its teaching normal, coin source before a merchant, non-combat row before the boss,
  no dead ends); keep Pact levels, Spare/Kill, endings. 10k-seed generator test.

**Phase 4 — statuses and 60 MVP cards (D2)**
- One status list with caps and the anti-loop event envelope; card schema v2 (shape rule, trigger, tags, upgrade,
  delivery); pick and specify 60 cards from pack `05` (task D), merging the earlier 8-group proposal; data + tests;
  card art after the list is fixed.

**Phase 5 — land-by-land content** (pack task C): the other 7 lands' enemies and Wardens, then art, balanced with
`tools/balance/` bots.

**Phase 6 — card pool growth**: further batches of 30–40 cards after playtest data.

## Alternatives Considered

### Alternative 1: implement the pack literally (energy card bar, 180 cards, new combat core)

- **Pros**: one source of truth; the pack's card ideas fit it directly.
- **Cons**: rebuilds the tested combat core, input and HUD; ~30 cards depend on that model; 180 cards have no numbers.
- **Rejection Reason**: user decision D1; the pack itself marks the card-bar model as a proposal.

### Alternative 2: keep the build and ignore the pack

- **Pros**: no work.
- **Cons**: loses the pack's land identity (signature enemies, phased Wardens, fixed tier pairs) and the casting
  grammar the user just locked.
- **Rejection Reason**: user decisions D3–D5, D7.

## Consequences

### Positive

- Land identity through signature enemies and phased Wardens, on the tested combat core.
- One recorded answer for every pack conflict; later sessions do not re-open them.

### Negative

- Misty Forest grows: the goblins and wolves stay beside the pack's roster (A2), so that land has more enemy types
  than the pack's 3 + 2.
- Map v2 replaces the 3-stage land layout and its tests.
- The pack's 180-card file stays mostly unused until phase 6.

### Neutral

- Pact levels, Spare/Kill, endings, Luck and achievements stay as they are; the pack is silent on them.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| D6 lethal drop tiles feel unfair on mobile | Medium | High | Spec fairness rules; `hole_fall_lethal` switch to fall damage after playtest |
| Run length grows with 5-row lands (already 27–30 min by bot vs 40–50 target) | Medium | Medium | Measure with `tools/balance` after phase 3; the pack allows a 3-node mobile variant |
| Signature-pattern enemies and the block AI conflict in one fight | Medium | Medium | Phase 2 keeps one brain per enemy type; elites may mix |
| Art workload (39 enemies, 8 Wardens × phases, 60 card pictures) | High | Medium | Land by land; PixelLab calls priced and approved one by one |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (frame time) | unchanged | unchanged (data and AI choice per cast, not per frame) | 16.6 ms |
| Memory | — | + enemy/boss sheets per land | per land load |
| Load Time | — | unchanged | — |

## Migration Plan

1. Phase 1 stories (data/canon/presentation) — verify with the full suite and captures in `production/qa/evidence/`.
2. Phase 2 slice behind the existing match flow; old Misty Forest roster kept until the slice passes playtest.
3. Phase 3 map v2 replaces `ChapterMapGen` stages; save files: start a new run on version change.

**Rollback plan**: each phase is its own commit series; revert a phase's commits and its data files.

## Validation Criteria

- [ ] Suite FAILS=0 after every phase.
- [ ] Every card and enemy/boss attack in data declares a delivery, and the path-damage test passes.
- [ ] Every Misty Forest enemy/Warden skill passes the valid-response test on every Misty Forest arena.
- [ ] 10k generated runs: every route reaches the Warden, coin source before a merchant, rest or forge before the boss.
- [ ] Playtest: the user confirms the cast/floor animation no longer reads as rough.

## GDD Requirements Addressed

Foundational — no GDD (`modes.workflow: minimal`; the design record is `design/game-brief.md`,
`design/game-mechanics.md` and the pack). Enables: combat casting presentation, enemy skills, Warden phases, map
generation, card system v2.

## Related

- Design pack: `TESSERA_CLAUDE_DESIGN_PACK/tessera_claude_pack/00`–`07` (casting rules §1A added 2026-11-01).
- `design/quick-specs/o-rot-thay-tuong-2026-10-31.md` (D6).
- `design/references/osfe-spell-anatomy.md`, `design/references/osfe-card-layout.md`.

## Open questions for the user

Answered on 2026-11-01 — see A2 (Misty Forest roster), A3 (Pact levels 3 and 9), A4 (final boss).
