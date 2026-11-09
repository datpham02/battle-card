# Skill v2 — Phase 3: Hỏa Lôi (`hoa_loi`) design and audit

**Date:** 2026-11-08 · **Status:** PROPOSED — design and audit only. Nothing here is implemented; no data, code,
asset or balance value was changed. Every number is a **candidate** for the balance sim, not an approved value.
**Owner hero:** Pháp sư (`phap_su`). **Reference skills it must stay distinct from:** Trảm Địa (approved),
Ngàn Kiếm (approved technical prototype, `0472896`).

Sources read: `02-skill-bible.md` §1 Pháp sư, `02-mechanics-catalog.md` (M07, M09, M11, M15, §G zones),
`02-implementation-roadmap.md`, `02-design-decisions.md`, `02-vfx-concepts.md` §8.2,
`design/quick-specs/nhip-ra-chieu-2026-11-05.md`, `design/quick-specs/cast-commitment-ngan-kiem-2026-11-08.md`,
`assets/data/cards.json`, `characters.json` (`phap_su`), the combat code listed in §13, the Mage sheet and VFX
indexes.

---

## 1. Current roadmap and implementation status

### 1.1 Three-way status

| Item | Status | Where |
|---|---|---|
| Cast context, `ShapeTags`, `CastResolver` waves, scheduled events, one hit per unit per wave | **Implemented** (B1/B1.5, `986874b`) | `cast_resolver.gd`, `swing_arbiter.gd`, `shape_tags.gd` |
| `arrival` resolve: surge (Trảm Địa), sky drops with `max_hits` / `fixed_hit` / `from_centre` (Ngàn Kiếm) | **Implemented** | `cast_resolver.gd`, `sky_drop_fx.gd` |
| Cast Commitment (channel, commit lock, cancel policy `spent`) | **Implemented, Ngàn Kiếm only** | `combat_view.gd` 3121–3206, `skill_config.gd` |
| Burn as a **cell** effect: `ignite`, ticks, stacks ≤ 3, `burn_on_entry`, boss hard-blocked by burning cells on its half | **Implemented** | `status_effects.gd` 141/305, `boss_brain.gd` 281, `combat.json` |
| One zone per cell (`_claim_zone_cell`) for burn, thorns, drop tiles | **Implemented** | `status_effects.gd` 536 |
| Region hazards: lava vents (warn → erupt → burn), mire, sand, crumble | **Implemented** | `tile_hazards.gd` |
| Boss awareness of scheduled player cells (`pending_threat`, seen cells only) | **Implemented** | `boss_brain.gd` 90, `combat_view.gd` 476 |
| Mage signature Thiên Hỏa: detonates enemy-half burn ×2, resets burn cards | **Implemented** | `src/signatures/thien_hoa.gd` |
| M07 delayed / zone kind `fuse`, M09 trap, zone kind `ward`, `pillar`, `ice_floor` | **Designed, not implemented** | mechanics catalog |
| Crit `target_burning` (M19), reactions R1–R3 (M15) | **Designed, not implemented** (`CritRules.CONDITIONS` = `target_pinned` only) | `crit_rules.gd` 13 |
| Brain path costs for fuse / trap / pillar | **Designed, not implemented** | roadmap §3 |
| Scheduling a **burn**-effect card | **Absent** — `CastResolver` schedules `effect == "damage"` only | `cast_resolver.gd` 58, 126 |
| Countdown drawing for a player-placed delayed effect | **Absent** | — |
| `hoa_loi` in data, code, strings, tests | **Absent** | audit 01 §320 |
| Mage cast clips other than `cast_gesture` | **Absent** (no `cast_ground`, no book clip) | `art_src/units/phap_su/clips.json` |
| Audio of any kind | **Absent** (see `10-audio-system-design.md`) | — |

### 1.2 Roadmap position
- Roadmap batch **B3 (Mage)** holds `hoa_loi`, `thien_thach`, `hoa_tuyen` + `min_tre`. Stage **S3** brings M07
  delayed (zone `fuse`). The vfx concepts name Hỏa Lôi one of five pilots ("a telegraph that counts down and then
  erupts").
- Planned Mage hero cards (bible §1): `hoa_loi` (common), `thien_thach` (epic), `hoa_tuyen` (rare). Starter v2:
  `hoa_loi, hoa_xa, hoa_tinh ×2, hoa_tran, bang_phong` (decisions §9). The current deck is still
  `kiem_khi, hoa_xa, hoa_tinh ×2, hoa_tran, bang_phong`.
- MVP roster: 60 cards = 32 existing + 28 new (Q1 approved). Data today has 36 entries (incl. curses and
  `tram_dia`, `ngan_kiem`).

### 1.3 Proposed in this document
Everything in §2–§16: concrete cast rules, the fuse module as a **generic** delayed-wave mode, the seal
countdown painter, the boss "fuse awareness" rule, candidate numbers, the animation and VFX plan, tests.
Where this document departs from the bible or the catalog it says so (**Δ**).

---

## 2. Tactical identity

> "Put the fire where the boss **will** be. Then make that the only place it can be."

| | Trảm Địa | Ngàn Kiếm | **Hỏa Lôi** |
|---|---|---|---|
| Question asked | Is the line to the boss clear now? | Will the boss stay inside the mask while I channel? | Where will the boss be in 1.5 s, and can I close its exits? |
| Commitment | short swing, wave travels | long channel, rooted, cancellable | short cast, then **free**; the commitment is the placement |
| When damage is decided | on arrival, cell by cell | per drop, from the centre outward | **one instant**: all seals at once |
| Space after the hit | none | none | **burning cells** that the boss cannot enter |
| Main skill expressed | aim | timing and nerve | **prediction and herding** |

Long-term roadmap value: Hỏa Lôi is the first card where the hero acts **away from** the damage moment. It proves
three modules the 60-card MVP needs (delayed wave, armed zone, aftermath hazard) instead of one card.

---

## 3. Proposed gameplay mechanics (summary)

1. Place Blocks on the enemy half as usual. Choose Hỏa Lôi (min 2 cells).
2. The Mage plays a **short fixed cast** (0.45 s). At its end the seals become authoritative on every valid cell of
   the cast's cells.
3. The seals count down `fuse_sec` (1.5 s; square 1.8 s). The Mage moves and plays other cards meanwhile.
4. At zero, **every seal detonates in the same instant** (one wave). A unit whose footprint touches any seal cell is
   hit **once**: `dpc × cells × fuse_mult`. Its position is sampled **at detonation**.
5. Every seal cell (hit or not) ignites with the existing burn (hoa_xa values). Burning cells already block the
   boss's movement and hurt on entry, so the explosion leaves a short no-go area.

---

## 4. Cast and movement rules

| Rule | Proposal | Why (and roadmap value) |
|---|---|---|
| Initial cast duration | **fixed 0.45 s** (`duration_override`), not 0.2 + 0.25 × cells. The Tay Vững passive (×0.75 at ≥ 4 cells) does not stack on an override. | The cast places a trap; it must not cost like a swing. A fixed cast keeps the 1.5 s fuse the only timing to learn. Reusable as `cast_time_fixed` for every armed-zone card (traps, wards). |
| Rooted during the cast | **Yes, for the 0.45 s only** (reuse `is_cast_rooted` with a "lock only" Commitment profile: `channel_extend_sec` 0, no Hủy button). Normal cards let the hero step mid-swing; Hỏa Lôi roots briefly. | Couples the hand gesture to the seals appearing; small, readable cost. Generalises Cast Commitment into profiles (full channel / lock only / none). |
| Seals authoritative | **At the swing end** (`cast_scheduled`): cells, times and owner fixed from then on. | Same contract as Trảm Địa and Ngàn Kiếm: gameplay never reads animation. |
| Voluntary cancel | **None** (no Hủy). | The decision is the placement; a cancel adds a second decision with no tactical content. Δ vs Ngàn Kiếm on purpose. |
| Interruption during the 0.45 s | Existing swing rule: the boss's first damaging event interrupts the swing; **no seals**, Blocks spent and cooldown kept (as any interrupted swing today). | No new rule; the short window keeps this rare. |
| After the cast | Seals **survive** the Mage being hit (arbiter already does); cleared without firing on caster death or match end. | M07 as catalogued. |
| Block cost | Blocks consumed at placement (as all cards). | — |
| Cooldown | Starts at the swing start (as all cards). | — |
| Movement restored | At 0.45 s (end of the swing). | "Short cast, then free" as requested. |
| Several fields | Allowed; **max 2 active Hỏa Lôi casts** per hero (while 2 are armed the card is unavailable). A seal is never placed on a cell that already holds an armed seal: that cell is skipped, the rest of the cast places. In practice there is rarely more than one field (cd 6 s > fuse 1.8 s) unless Thiên Hỏa resets the cooldown. | Δ vs catalog §G "a new fuse on a fuse resets its countdown": resetting lets a player stall a fuse forever; skipping keeps every countdown honest. Open decision D3. |

---

## 5. Block-shape interaction

All cells come from the existing resolver (`CastPlan` union → `StatusEffects.unlocked_cells`); Hỏa Lôi adds no
cell rule.

| Shape | Coverage read | Rule |
|---|---|---|
| Straight (`line`, 2–5) | blocks one row or column: an exit wall | no clause |
| L | corner trap: covers a cell and the two ways out of it | no clause |
| T | a cell plus three exits | no clause |
| Plus | the target cell and all four exits | no clause (the plus is already the best "pin in place" shape) |
| 2×2 square | exactly a 2×2 boss footprint, or 4 cells around a 1×1 boss | **shape clause `square`**: fuse 1.8 s, ×2.5 instead of ×2.0 (bible). A heavier, slower charge: better on bosses that are rooted in long attacks. |
| Irregular (S, U, P, odd) | as placed | no clause |
| Locked / invalid cells | removed at cast; a cell that becomes **locked before detonation** fizzles (no damage, no burn) — checked at fire time | Δ small: today locks are checked only at cast time |

**Simultaneous vs staggered — recommendation: simultaneous.** Staggered explosions are Ngàn Kiếm's identity
(centre-out drops) and turn a prediction into a chase. One instant makes the question exact: "where is the boss at
t = 1.5 s?". Implementation: one wave, `t = cast_sec + fuse_sec`, all cells.

Multiple placed Blocks: the union is one field with one timer (cells from all pieces). Shape clause scope
`any_piece` (as Ngàn Kiếm): one 2×2 piece is enough for the square charge.

---

## 6. Delayed explosion (authoritative)

| Point | Rule |
|---|---|
| Scheduling | `CastResolver` new resolve `"delayed"`: one wave `{t: fuse_sec (× clause), cells: valid cells, kind: "fuse", mult: fuse_mult}`. `SwingArbiter._schedule_cast` fixes `at = clock + t` at the swing end. |
| Sampling | At the event's `at`: `_state.unit_in(opposite, ev_cells)` (existing). Position at placement is never used. |
| Per-cell damage | **No.** One hit per unit per wave (existing rule): damage = `dpc × cast cells × fuse_mult`. A boss standing on 1 of 4 seals takes the full value — the whole field explodes together. |
| Multi-cell bosses | 2×2 footprint: hit once if any footprint cell is a seal (existing `unit_in`). |
| Interrupting attacks | Yes: the detonation is a damaging event → existing "first damaging event interrupts the opponent's swing" and `pattern_hit_fn` → `PatternController.on_enemy_hit` interrupts an interruptible windup/warning. This is the reward for timing seals into a boss windup. |
| Ordering | Existing `(at, seq)` order; at the same instant swings settle before events (arbiter `_step`). Two fields at the same `at` fire in cast order. Burn is applied **after** the damage of the same event (so the hit does not also pay an entry tick). |
| Cleanup | Caster death / match end: `_cancel_all` (existing). Cell locked before fire: that cell drops out of the event (new check). Disarm by enemy zones (catalog X3): **later milestone** — no enemy zone lands on the enemy half today. |

---

## 7. Burning ground

**Audit result:** the burning-tile hazard already exists and is generic: `StatusEffects.ignite(cells, duration,
tick, dmg)`, ticks, stacks ≤ 3 (+1 dmg per stack), `burn_on_entry`, one zone per cell, boss mover hard-blocked by
burning cells on its own half, `burn_avoid` weight, Thiên Hỏa detonation, `burn_painter.gd` time bar, the
`burning_cell` floor pack. Hỏa Lôi does **not** need a new hazard system.

| Point | Proposal |
|---|---|
| Duration | 2.0 s (hoa_xa) |
| Damage model | entry + periodic, existing: tick 0.5 s × 1.5 dmg (hoa_xa) |
| Overlap | existing stacking (refresh + stack ≤ 3); a seal cell already burning stays a seal (catalog X1) and re-ignites at detonation |
| Ownership / friendly fire | player fire lives on the enemy half; the hero never stands there → no friendly fire. Owner tag added to the zone record (needed later for reactions and for "your fire" vs "boss fire" visuals) |
| Movement | boss: hard-blocked on entering (existing). Brain must still keep an exit (`ZoneRules.fit_cells` rule applies to card zones per catalog §M11) — **check needed**: a plus field around a 1×1 boss can leave it on a burning centre with 4 burning exits for 2 s. Proposal: the boss may step off a burning cell onto another burning cell when no exit exists (pays the entry tick). |
| Status interactions | Thiên Hỏa ×2 detonation (existing); `target_burning` crit and R1 Hơi Nước are later (B6) |
| Telegraph | existing burning_cell loop + time bar; must stay smaller than the eruption (§11) |
| Max stacks | existing cap 3 |

**Recommendation: include burning ground in the first prototype**, behind a data switch
(`fuse_burn: true`), because it costs one `ignite` call on existing code and it is half of the card's identity
(area denial). Disable it for an A/B sim run to measure its share of damage.

Roadmap value: confirms burn as **the** generic ground hazard. Hỏa Tuyến (walls), Thiên Thạch (burning crater),
R1 Hơi Nước and Thiên Hỏa all read the same cell burn.

---

## 8. Boss counterplay

**Audit:** `BossBrain` dodges only player cells it **saw** during the swing, after `reaction_sec` (0.35 s default),
weighted `dodge_danger × urgency`; step cooldown 0.55 s; burning cells are hard-blocked; pattern bosses are rooted
while `is_busy` (WINDUP → WARNING → RESOLVE → FOLLOWUP → RECOVERY).

Risk: seals are visible for 1.5 s and `pending_threat` would report them like an incoming swing → the boss would
step off **every** field that is not under a busy boss. The card becomes "only useful during recovery".

**Proposed fuse awareness (generic armed-threat rule):**
1. Seals enter `pending_threat` with their `time_left` and a `kind: "fuse"`.
2. The boss treats a fuse as a threat only in its last `fuse_react_window` (0.8 s candidate) — before that it is a
   soft path cost (`fuse_avoid`, like thorns).
3. It must still obey `reaction_sec`, step cooldown, busy stages and blocked cells (burn, edges, other seals).
4. It picks the best **reachable** cell; if every reachable cell is a seal or blocked, it stays (or takes the
   cheapest seal cell).

This yields the intended counterplay:
- **Poor trap** (only the boss's current cell, open exits): it walks off in the last 0.8 s. → miss.
- **Exit coverage** (L / T / plus around it, or two Blocks): it has no safe reachable cell. → hit.
- **Recovery timing**: cast so the detonation lands inside RECOVERY or WINDUP/WARNING; the boss is rooted. → hit, and
  a windup hit interrupts it.
- **Herding**: earlier burning cells (Hỏa Xạ, a previous Hỏa Lôi) remove exits. → the Mage's combo chain.

Target in the sim (roadmap §4): fuse hit rate **40–70 %**. `fuse_react_window` and `fuse_avoid` are the two tuning
knobs; per-boss movement profiles can override them (some bosses read fire well, others are slow).

Roadmap value: the same rule serves traps (M09), Ngàn Kiếm-style shadows, Thiên Thạch's shadow and any future
telegraphed player effect — "a visible threat becomes urgent only near its time".

---

## 9. Reusable Skill v2 architecture

| Module | Kind | Hỏa Lôi uses | Also serves (from the repository roster) |
|---|---|---|---|
| **Delayed wave** (`resolve: "delayed"`, `fuse_sec`, `fuse_mult`) | resolver extension | the fuse | `min_tre` (B3), Thiên Thạch's shadow delay, echo waves (M14), Dấu Tử echo (×0.6 after 0.6 s) |
| **Event payload** (`on_event: [damage, ignite, pin, frost]`) — lets a scheduled event carry effects, lifting the "scheduled = damage only" limit | resolver + arbiter + `CutEffects.apply_event` | damage + ignite | hoa_xa / hoa_tinh / hoa_tran when they move to scheduled timing (B7), bang_phong pin waves, Thiên Thạch burns |
| **Armed-zone registry** (zone kind `fuse`, later `trap`, `ward`): owner, cast id, cells, `time_left`, disarm rule | `StatusEffects` zone book | seals, one-per-cell, skip on own armed cells | Bẫy Kẹp (trap), Thánh Thuẫn (ward), Bẫy Lò |
| **Threat feed** (`pending_threat` entries with `kind`, `time_left`, `react_window`) | `BossBrain` | fuse awareness | traps (`trap_avoid`), shadows, pillars |
| **Cast profile** (fixed cast time; root: none / lock / channel; cancel: none / spent) | `skill_config` + `combat_view` | 0.45 s lock | Ngàn Kiếm already = channel profile; traps / wards = lock profile |
| **Tile countdown painter** (code-drawn, player colour, 3 pips) | `cut_hud_view` / floor layer | seal countdown | traps arming, ward expiry, Thiên Thạch shadow |
| **Ground hazard = cell burn** | existing `StatusEffects` | aftermath | Hỏa Tuyến wall, Thiên Thạch crater, R1 |
| **Crit conditions** `target_burning`, `target_on_hazard` | `CritRules` | — (later) | hoa_xa, hoa_tinh, hoa_tran (rhythm spec) |
| **VFX stage modules** (seal, charge, eruption, aftermath) indexed per card in `card_casts` | `assets/art/vfx` + overlay/floor layers | 4 stages | reused by fire cards (eruption), traps (seal frame, recoloured), Thiên Thạch (eruption) |
| **Audio event hooks** on the same signals | audio system | seal / charge / detonate | every card (see audio doc) |

No Hỏa Lôi-specific combat path: every rule is a data field read by a shared module.

---

## 10. Initial balance candidates

| Field | Bible / rhythm spec | **Proposed start** | Reason |
|---|---|---|---|
| Rarity / owner | common, Mage hero | common, Mage hero | — |
| `min_cells` | 2 | 2 | starter card for 2-cell hands |
| Cast time | swing formula | **0.45 s fixed** | §4 |
| `fuse_sec` | 1.5 | **1.5** | ≥ boss step cooldown (0.55) + reaction (0.35) + one step: a fair dodge window |
| Square clause | 1.8 s, ×2.5 | **1.8 s, ×2.4** | keep the 2×2 payoff without beating Ngàn Kiếm's best case at 4 cells |
| `damage_per_cell` | 6 | 6 | same base as the Mage's fire cards |
| `fuse_mult` | 2.0 | **2.0** | the payment for the delay and the miss risk |
| `cooldown_sec` | 5 | **6** | Δ: the burn aftermath and Thiên Hỏa resets add value the spec did not count |
| Burn | as hoa_xa | 2.0 s, 0.5 s tick, 1.5 dmg | existing values |
| Multi-hit | — | 1 hit per unit per cast | one instant |
| Awakening (Mage: Bùng Nổ) | — | no special rule: burning seal cells are detonated by Thiên Hỏa like any burn; a field still armed is **not** detonated early | keeps fuses honest (catalog combo check) |
| Active field cap | — | 2 | §4 |

**Worked damage (no relics, no crit):**

| Cast | Hit | Burn (if it stays 2 s, 1 stack) | Cooldown | Expected at 55 % hit rate |
|---|---|---|---|---|
| Hỏa Lôi 2 cells | 24 | +6 | 6 s | ≈ 15 |
| Hỏa Lôi 4 cells (T / L / line) | 48 | +6 | 6 s | ≈ 29 |
| Hỏa Lôi 2×2 square | 6×4×2.4 = 58 | +6 | 6 s | ≈ 34 (slower fuse) |
| Trảm Địa 3 cells, burst | 6×3×1.5 = 27 | — | 6 s | ≈ 24 (high hit rate) |
| Ngàn Kiếm 4 cells, 3 hits | 36 (+centre ×1.5) | — | 10 s | ≈ 25–30, rooted 1.48 s |

A delayed card that hits ~55 % of the time should land near the direct cards in expected value, above them only
when the player predicts well. The sim must confirm: fuse hit rate 40–70 %, Hỏa Lôi ≤ 25 % of the Mage's damage
(roadmap §4), Mage win rate 35–65 %.

---

## 11. Fire Mage animation

**Audit:** sheet `unit_phap_su_sheet` 96×70, facing right (3/4 south-east), no `body_h`, 13 clips. The only cast
clip is `cast_gesture` (9 frames, 83/83/83/83/200/50/83/100/133 ms; frame 4 coil, frame 5 palm out), built from
cast + victory frames. `card_casts` has no Mage entry, so all Mage cards play `cast_gesture`. Pose language (art
bible): book in one hand; pose B = free palm pushed forward; Bùng Nổ = book raised high.

| Desired beat | Covered by `cast_gesture`? |
|---|---|
| 1. opens / raises the book | partly (frames 0–3 lift) |
| 2. forms a geometric fire command | **no** — no frame shows a command at the book |
| 3. seals appear on the ground | release frame 5 is a palm **forward**, not toward the floor |
| 4. finishes and can move | yes (frames 6–8 recover, then idle/step) |
| 5. seals charge and explode | VFX only, the Mage is already free |

**Recommendation:**
- **Prototype (free):** bind `card_casts.hoa_loi` to `cast_gesture`, scaled to 0.45 s, hold frame 4 for the command
  beat, frame 5 = seals appear (swing end). Add a code-drawn amber command glyph (a 3×3 square) at the book hand
  during the hold (`charge_hand` slot, as Trảm Địa's). Readable, zero cost.
- **Final (needs one paid generation, later, with its own approval):** a `cast_ground` clip, **6 frames**, same
  96×70 frame (no headroom needed — the book stays at chest height):
  1. book opens at chest, 2. free palm draws over the page (glyph forms), 3. hold (command), 4. palm flicks
  **down and forward** toward the floor ahead, 5. recoil, 6. back to guard.
  Feet planted at the existing anchor; palette, hat silhouette and book unchanged; positive motion prompt only
  (memory: no negative words). It becomes the shared `cast_ground` archetype for Hỏa Lôi, `min_tre`, traps.
- The Mage must never hold the cast pose during the fuse.

---

## 12. VFX storyboard (four stages, each a reusable module)

Grammar: squares only; player telegraphs in the Mage's block colours (#3A2A26 body, #F0A030 amber); fire ramp
#3A2A26 / #EFE6D2 / #FF7A1F / #FFB21F; enemy red #E5293B forbidden; floor effects centred in the cell; cell 64×46
(43×31 variant); sized from the cell and judged at 1× and 2×.

| Stage | Time | Look | Layer / size | Module |
|---|---|---|---|---|
| **1 Seal placement** | 0 → 0.25 s from the swing end | a square sigil **draws itself from the 4 corners inward** on the slab: amber outer square (≈ 48×34), charcoal inner square, 4 corner pips; 4–6 square embers kick up from the slab | floor, center | `square_sigil` (new fxkit component): `draw_in` |
| **2 Charging** | 0.25 s → fuse end | three discrete steps (3-2-1): at each third one corner pip goes out and the inner square shrinks one step and brightens (#F0A030 → #FFB21F → #EFE6D2 core); a 1-px heat shimmer of 2–3 squares rises; **last 0.3 s**: the outer square pulses twice (no strobe) | floor + a thin overlay shimmer | `square_sigil`: `charge` (3 steps), `final_pulse` |
| **3 Detonation** | fuse end ± 0.1 s | anticipation: the sigil **collapses inward** to one bright square (2 frames, 60 ms) → impact frame: a full-cell cream flash square → a **stepped flame column** of squares rising ≈ 2.2 cells (≈ 100 px), 6 frames × 50 ms, charcoal square smoke cap at the top; square: a 1-px board kick | overlay, ground_center, canvas ≈ 112×128 | `fire_eruption` (new pack, fxkit or free vfx_workbench) |
| **4 Burning ground** | 2.0 s | existing `burning_cell` loop + `mark_embers_burn`; a scorched sigil decal (charcoal outline) fades in 0.6 s | floor | existing packs + `square_sigil`: `scorch` |
| Fizzle (locked / disarmed) | 0.2 s | the sigil breaks into 4 grey squares, no flame | floor | `square_sigil`: `fizzle` |

Distinctness: Trảm Địa = grey-steel **jagged shards** spreading sideways along a line; Ngàn Kiếm = **objects above
the board** falling in sequence; Hỏa Lôi = **ground glyphs that count down**, then **vertical** fire columns all at
once. Never a recolour of either.

Validation (per `02-vfx-concepts.md` §8.2): countdown readable without text at 1×; seals never hide the boss's HP
plate; fizzle ≠ eruption; five simultaneous columns stay readable (stagger draw order back-to-front, cap the cream
flash to the cell).

---

## 13. Required asset inventory

| Asset | Kind | Cost |
|---|---|---|
| `square_sigil` component: draw_in (5 f), charge steps (3 × 2 f), final_pulse (4 f), collapse (2 f), scorch (4 f), fizzle (4 f); 64×46 + 43×31 | fxkit (code-generated) | free |
| `fire_eruption_hoa_loi` overlay pack, 7–8 f, 112×128, + 43×31 variant | fxkit or vfx_workbench | free |
| command glyph at the hand (code-drawn) | code | free |
| `burning_cell`, `mark_embers_burn`, `impact_flame_small_burn` | existing | — |
| card texts `card.hoa_loi.name/desc` vi/en; card face icon | data / existing card art pipeline | free |
| `cast_ground` Mage clip, 6 f | PixMiniMax, **1 generation**, separate approval | paid, later |
| audio events (seal, charge, detonate, burn loop, fizzle) | see `10-audio-system-design.md` | later |

---

## 14. File-by-file implementation plan

| File | Existing / extension / new | Change |
|---|---|---|
| `assets/data/cards.json` | extension (data) | `hoa_loi` entry: `hero phap_su`, `effect damage`, `resolve "delayed"`, `fuse_sec`, `fuse_mult`, `fuse_burn {sec, tick, dmg}`, `cast_time_fixed 0.45`, `cast_root "lock"`, `shape_clause {tag square, fuse_sec 1.8, fuse_mult 2.4}` |
| `src/combat/skill_config.gd` | extension | parse + validate the new fields with defaults; `cast_profile()` helper (none / lock / channel) |
| `src/combat/cast_resolver.gd` | extension | resolve `"delayed"`: one wave at `fuse_sec`; square clause; event payload `on_event` (damage + ignite); lift the damage-only limit for payload events |
| `src/combat/swing_arbiter.gd` | extension | at fire time drop cells now locked; apply payload (`ignite` after damage); expose `pending_cells` with `kind` and `cast_id` |
| `src/combat/cut_effects.gd` | extension | `apply_event` path for payload effects (ignite via `StatusEffects`) |
| `src/combat/status_effects.gd` | extension | armed zone kind `fuse` (owner, cast id, cells, time_left); `_claim_zone_cell` skip rule for own armed cells; owner tag on burn |
| `src/combat/cut_actor.gd` | extension | honour `cast_time_fixed` (override before relic modifiers) |
| `src/combat/combat_view.gd` | extension | Commitment "lock" profile (root for the swing only, no Hủy); active field cap 2; feed fuse threats to the brain |
| `src/combat/boss_brain.gd`, `boss_brain_config.gd` | extension | threat `kind`, `fuse_react_window`, `fuse_avoid`; reachable-cell choice with seals as blockers |
| `src/combat/cut_hud_view.gd` or `src/battle/floor_dynamic_layer.gd` | extension | seal countdown painter (code fallback before the fxkit pack lands) |
| `src/art/fuse_fx.gd` | **new** | timeline of the 4 stages from `cast_scheduled` (like `sky_drop_fx.gd`): pure functions, reduce-motion aware |
| `src/battle/overlay_layer.gd`, `floor_dynamic_layer.gd` | extension | draw sigils (floor) and eruptions (overlay) from `FuseFx` |
| `assets/art/vfx/cast/index.json`, `floor/index.json` | extension | `card_casts.hoa_loi` (clip, hand, glyph, packs); new packs |
| `tools/fx-pipeline/` | extension | `square_sigil` component + recipe, `fire_eruption` recipe |
| `assets/i18n/strings.csv` | extension | card name / description vi/en |
| `tools/balance/sim_core.gd` | extension | delayed waves already run through the real arbiter; **new bot logic**: value = hit chance × damage, aim at predicted cells / exits, cast in boss recovery; metrics fuse hit rate, burn share |
| `tools/balance/hoa_loi_probe.gd` | **new** | fixed-seed probe like `ngan_kiem_probe.gd` |
| `src/dev/demo_args.gd` | extension | reuse `--live-card=hoa_loi`, `--boss-move-at`; add `--boss-recovery-at` if needed for scenario C |

---

## 15. Automated test matrix

| # | Test | Level | Checks |
|---|---|---|---|
| 1 | `hoa_loi_test.gd` timing | unit | swing 0.45 s for 2–5 cells; detonation at cast end + 1.5 s (square 1.8 s) exactly, on the arbiter clock; all cells one wave |
| 2 | valid / invalid cells | unit | locked cells get no seal; a cell locked during the fuse fizzles (no damage, no burn) |
| 3 | moving enemy | unit | boss on a seal at cast time but off at detonation → miss; off at cast, on at detonation → hit |
| 4 | multi-cell boss | unit | 2×2 boss touching 1 or 4 seals → exactly one hit, same damage |
| 5 | shape clause | unit | square → 1.8 s / ×2.4; T, L, line, plus → 1.5 s / ×2.0; clause scope `any_piece` |
| 6 | overlap | unit | second cast on an armed cell skips that cell; cap 2 active fields; same-instant fields fire in cast order |
| 7 | burning ground | unit | every seal cell ignites after the damage; duration / ticks / stacks as hoa_xa; boss blocked from entering; boss on a burning cell with no exit may step to a burning cell |
| 8 | interruption | integration | boss hit during the 0.45 s → no seals, Blocks spent, cooldown kept; Mage hit during the fuse → seals stay; caster death / match end → nothing fires |
| 9 | movement restore | integration | d-pad locked for 0.45 s only; steps accepted right after; no Hủy shown |
| 10 | detonation interrupts a windup | integration | detonation during an interruptible WINDUP/WARNING stops the boss skill |
| 11 | Awakening / Thiên Hỏa | integration | armed fields not detonated early; burning seal cells detonated ×2 |
| 12 | boss counterplay | unit (brain) | lone-cell trap with open exits → boss leaves in the last 0.8 s; full exit cover → no safe cell, boss stays; busy boss never moves |
| 13 | simulator parity | unit (balance) | `sim_core` and CombatView give identical detonation time, hit result and burn for the same seed |
| 14 | animation / VFX sync | unit (art) | `FuseFx` stage times derive from `cast_scheduled` `at`, never from the clip; eruption frame == detonation tick; reduce motion removes shimmer and board kick |
| 15 | regression | suite | golden test unchanged; Trảm Địa, Ngàn Kiếm, existing Mage cards identical; full suite green |

Every new test is watched failing first (test standards).

---

## 16. Gameplay acceptance scenarios (real battle captures, `--demo=tram_live --live-card=hoa_loi`)

| | Scenario | Expected |
|---|---|---|
| A | boss stays on the marked cells (cast during its RECOVERY) | hit at 1.5 s, cells burn |
| B | lone-cell seal, open exits | boss steps off in the last 0.8 s; seals erupt empty; burn left behind |
| C | player covers the escape side (L around the boss) | boss steps into the covered exit or stays → hit |
| D | line / L / T / plus / 2×2 on the same board | contact sheet of the coverage of each, and the square's slower charge |
| E | burning ground from cast 1 herds the boss onto cast 2 | the boss avoids burning cells and walks onto the second field |

Evidence to `production/qa/evidence/skill-v2-hoa-loi/`: native 640 and 2× sheets, event logs, a short video kept
local.

---

## 17. Open decisions requiring approval

| # | Decision | Recommendation |
|---|---|---|
| D1 | Cast: fixed 0.45 s with a short root and no Hủy | **Yes** (alternative: no root, like other Mage cards) |
| D2 | Detonation simultaneous (one wave) | **Yes** |
| D3 | Seal on an armed cell: skip (Δ catalog "reset") | **Skip** |
| D4 | Burning ground in the first prototype (switchable) | **Yes** |
| D5 | Candidate numbers: fuse 1.5 / square 1.8, ×2.0 / square ×2.4, cd 6 (Δ bible cd 5, ×2.5) | approve as sim starting values |
| D6 | Boss fuse awareness: threat only in the last 0.8 s + soft cost before | **Yes**, tuned to 40–70 % hit rate |
| D7 | Generic modules (delayed wave, event payload, armed-zone registry, threat feed, cast profiles) instead of a Hỏa Lôi path | **Yes** |
| D8 | Animation: prototype on `cast_gesture` + code glyph; one `cast_ground` PixMiniMax gen later | prototype free first; the gen only after the prototype is accepted, with its own approval |
| D9 | VFX made free (fxkit / vfx_workbench) | **Yes** |
| D10 | Starter deck: `hoa_loi` replaces `kiem_khi` in the Mage deck (decisions §9) | defer to the batch that ships it |
| D11 | Disarm by enemy zones (X3), `target_burning` crit, R1 | later milestones (B6) |
