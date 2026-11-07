# Skill v2 — Phase 2: animation and VFX concepts

**Date:** 2026-11-07 · **Status:** PROPOSED · design only — no asset generated, no PixelLab call.
Per-card CAST / DELIVERY / IMPACT / AFTERMATH lines live in `02-skill-bible.md`. This document defines the visual
grammar, the reusable modules, which cards need unique assets, and the hero cast-clip plan.

## 1. Visual grammar (rules every skill follows)
1. **Square-based only** (pack §1A): squares, stepped bevels, 45° diamonds, rect outlines. No circles, no beams, no
   bloom, no smoke puffs. Fire = stepped flame with horizontal stripes; ice = jade-white squares; steel = bevelled.
2. **Four beats, always readable:** CAST (the hero's pose, `cast_gesture` coil → release) → DELIVERY (how it reaches
   the cells) → IMPACT (on the target cells only) → AFTERMATH (what stays, or the fade). Each beat must be readable
   at 1× on a phone from arm's length (memory rule: size from the cell, bright colours).
3. **The Block is never thrown.** Projectiles are square-based art (streaks, waves, daggers, meteors).
4. **Telegraph layer is sacred:** player telegraphs (fuse sigils, sky shadows, echo outlines, pull paths, traps) sit
   on the floor layer, tile-exact, in the hero's block colour; enemy warning red `#E5293B` is never used by player
   effects (fxkit check already enforces it).
5. **Floor effects are centred in their cell** (memory rule); effect labels (CHÍ MẠNG, ĐỠ, VỠ BĂNG) are bare
   emphasised text, never boxed.
6. **Identity = shape language + motion + material**, not a colour swap. Two cards of the same element must differ in
   at least two of: delivery motion, impact silhouette, aftermath.
7. **Gameplay drives visuals:** VFX schedule from the authoritative impact schedule (M02); a visual never implies a hit
   that did not happen (miss → miss dust, not a burst).

## 2. Hero visual identity

| Hero | Material / palette | Motion signature | Recurring motif |
|---|---|---|---|
| Kiếm sĩ | steel ramp `#1B1722 #5F6F82 #8FA3B8 #EEF4FA` | forward, linear, heavy stops | chevron waves, blades stuck in slabs |
| Pháp sư | charcoal + burn `#3A2A26 #FF7A1F #FFB21F #EFE6D2` | slow build, sudden release | sigils that collapse then erupt |
| Sát thủ | teal steel `#BFF3EC #FFFFFF` + ink | fast, staggered, many small marks | X slashes, diamond brackets |
| Thợ săn | jade-rope wood `#8A5A33 #46D6A4` | grounded, mechanical snaps | jaws, ropes, splinters |
| Giáo sĩ | ivory + pale frost `#E4DAFF #B8BCC8 #EEF4FA` | rhythmic pulses, rings | square ripples, bells, light shafts |

## 3. Reusable modules (fxkit components and code-drawn layers)

| Id | Module | Status | Used by |
|---|---|---|---|
| V01 | `square_gather` (charge at hand / on cell) | **exists** | every hero charge, fuse build-up |
| V02 | `square_wave` (projectile wave) | **exists** (steel) | tram_dia, chan_phong |
| V03 | `square_fireball` (projectile) | **exists, uncommitted** (Mage work) | Mage strike cards |
| V04 | `square_burst` big / small | **exists** | first-cell bursts, generic impacts |
| V05 | `flame_burst` big / small | **exists** | fire impacts, Hỏa Lôi eruption |
| V06 | `square_mark` (floor stamp) | **exists** | aftermath stamps, embers |
| V07 | `square_slash` (release cut) | **exists** | Knight release, Song Đao X |
| V08 | `root_crawl` / `root_spike` | **exists** (Witch) | thorn growth, Gai Nổ regrow |
| V09 | **shadow telegraph** (growing square shadow on a cell) | new, code-drawn (reuse enemy telegraph darkening) | all SKY cards |
| V10 | **sigil fuse** (square sigil with 3-2-1 shrink) | new fxkit component `square_sigil` | hoa_loi, min_tre |
| V11 | **falling object** (blade / meteor / pillar / hammer drop with stepped trail) | new component `square_drop` (variants: blade, meteor, shaft, hammer, ice spike) | ngan_kiem, thien_thach, thien_quang, dap_vo, bang_vo |
| V12 | **shockwave ring** (square ring rolling outward cell by cell) | new component `square_ring` | thien_thach, thien_lang, han_bang, chuong_thanh ripple |
| V13 | **ground front** (stepped front running slab to slab) | new component `square_front` (fire, tremor, mud, crack variants) | hoa_tuyen, dia_chan, vung_lay, ran_van, hoa_xa |
| V14 | **chain hop** (bright square hopping link to link with afterglow) | upgrade of code `chain_spark` into a pack | chuoi_set, chain cards |
| V15 | **echo ghost** (translucent copy of the mask that slides / re-stamps) | new code layer + `square_mark` | hoi_am, chuong_thanh, dau_tu echo |
| V16 | **zone objects**: trap jaws, spring plate, pillar, ice floor, ward frame, mire, fire wall | new fxkit components `trap_jaw`, `stone_pillar`, `ward_frame`, `ice_glaze`, `mire_pool`; fire wall = taller `burning_cell` variant | traps, terrain, wards |
| V17 | **rope / hook** (line of squares between two points, taut / slack) | new code-drawn layer | moc_keo |
| V18 | **forced-move trail** (drag marks + slam flash) | new code layer | pulls, pushes, R3 |
| V19 | **reaction bursts**: steam (R1), shatter (R2), slam (R3) | new components `steam_burst`, `ice_shatter`; R3 reuses V04 | reactions |
| V20 | **multi-hit numbers** (stacked rising damage numbers, 3rd larger) | new UI code | combo cards |
| V21 | **status brackets** (Dấu Tử diamond bracket, countdown) | new code layer | dau_tu |

Rule: a new card first composes existing modules; a new fxkit component is written only when no composition reads as
the intended motion. All of V09–V21 are free (fxkit / code). None needs PixelLab.

## 4. Per-card module map and unique assets

| Card | Cast clip | Modules | Unique asset? |
|---|---|---|---|
| tram_dia | cast_forward | V01 V02 V04 V06 V13(crack) | no (steel variants) |
| ngan_kiem | cast_overhead | V09 V11(blade) V04 V06 | **blade sprite** (fxkit `square_drop` blade) |
| do_kiem | parry_guard (built) | V07 + ĐỠ label | no |
| hoa_loi | cast_ground | V10 V05 burning_cell | **sigil** component |
| thien_thach | cast_overhead | V09 V11(meteor) V12 V05 | **meteor** + crater frame |
| hoa_tuyen | cast_ground | V13(fire) V05 fire-wall variant | fire-wall column |
| song_dao | cast_forward (fast) | V07(X) V20 | X-slash variant |
| phi_tieu | cast_throw | V14 dagger variant, V04 small | **dagger** streak |
| dau_tu | cast_point | V21 V15 | diamond bracket |
| bay_kep | cast_ground | V16 trap_jaw | **jaw** component |
| moc_keo | cast_throw | V17 V18 V04 | **hook claw** |
| gai_no | cast_pull | V08 reverse + splinters V04 | splinter burst |
| thanh_thuan | cast_overhead (staff) | V16 ward_frame | ward frame |
| chuong_thanh | cast_swing | V12 ripple V15 | **bell outline** |
| thien_quang | cast_overhead | V09 V11(shaft) V12 | light shaft |
| dia_chan | cast_ground | V13(tremor) V04 | no |
| vung_lay | cast_ground | V13(mud) V16 mire_pool | mire pool |
| lien_tram | cast_forward | V07 ×2 V20 | no |
| khien_thep | cast_overhead | V16 steel plates | steel plate |
| thuong_xuyen | cast_throw | V02 lance variant V04 | lance streak |
| dap_vo | cast_overhead | V09 V11(hammer) V04 | hammer head |
| chuoi_set | cast_point | V14 | spark |
| loc_cuon | cast_point | V01 inverse spiral, V18 | spiral |
| tuong_da | cast_ground | V16 stone_pillar | **pillar** |
| bay_lo | cast_ground | V16 spring plate V18 | spring plate |
| hoi_am | cast_point | V15 V04 | no |
| min_tre | cast_ground | V10 V04 | mine plate |
| bang_vo | cast_overhead | V11(ice spike) V19 shatter | ice spike |
| hoa_bang | cast_point | V01 two-tone V19 steam | steam burst |
| 4 reworks | as card family | V02 / V16 ice_glaze / V07 / V13 crack | ice glaze |

**Genuinely unique assets (fxkit components to write): 11** — blade, sigil, meteor + crater, jaw, hook claw, bell
outline, light shaft, pillar, ice spike, steam burst, ice shatter. The rest are variants or code layers.

## 5. Hero cast clips (animation plan)

Today each hero has **one** `cast_gesture` (9 frames) for every card. v2 proposes **5 cast archetypes**, chosen by
`UnitLayer.clip_for` from the card's delivery / mode when the hero's sheet has the clip, else `cast_gesture`:

| Archetype | Pose | Delivery / mode |
|---|---|---|
| `cast_forward` | step-in thrust / slash forward | CASTER_TO_TARGET, combo |
| `cast_overhead` | arms / weapon raised high, held | SKY_TO_TARGET, wards |
| `cast_ground` | kneel / slap or stamp the floor | GROUND, traps, fuses, terrain |
| `cast_throw` | throw / cast a line | daggers, hook, lance |
| `cast_point` | point / tap, small and quick | DIRECT, chains, marks, echoes |

- Each clip keeps the coil / release frame convention (`gesture_hold_frame`, `gesture_lead_sec`) so the existing
  cast sync works unchanged.
- **Art cost (later, separately approved):** up to 5 clips × 5 heroes = 25 PixelLab animation calls (~1 gen each with
  `animate_image_pixminimax` from each hero's anchor), done one hero at a time, one clip first, positive-motion
  prompts only. MVP needs only the archetypes each hero's cards use: Knight 3, Mage 3, Assassin 3, Hunter 3,
  Cleric 3 → **15 clips**.
- The pending Mage `cast_gesture` redraw becomes the Mage's `cast_forward`; its prompt should be re-checked against
  this plan before spending.

## 6. Existing VFX to keep, and the uncommitted Mage work
- Keep: Knight steel packs, burn flame / ember packs, status overlays, telegraph stripes, engraving packs.
- The Mage fireball (`square_fireball`, `fire_bolt_burn`, per-impact pack choice `unit_impacts`, travel colours by
  impact) is **uncommitted in the working tree**. It is compatible with this plan (V03) and should be committed
  before Phase 3 starts; Phase 3 must not reset or overwrite it.

---

## 7. Revision 2 rules (after the user's Phase 2 review)
- **No PixelLab cast clips now.** All skills ship first on the existing clips: `cast_gesture` (coil / release),
  `draw` frames for the overhead hold, `parry_guard` for Đỡ Kiếm, `hit` / `victory` frames only where already used.
  `clip_for` falls back to `cast_gesture` whenever an archetype clip is missing.
- **In-game validation before any paid clip:** each skill's fxkit version is checked in the real game at 1× (1280×720)
  and a phone-size viewport with a frame strip (`production/qa/evidence/skill-v2/<card>/`). Only a skill that passes
  may later get its archetype clip proposed (one call at a time, with prompt and cost shown first).
- **Distinctness check:** no two MVP cards share all three of delivery motion, impact silhouette and aftermath. The
  per-card module map (§4) is the checklist; a reviewer marks the strip of each card against its nearest neighbour.

## 8. Pilot skills (to receive full production specs later)
Five skills chosen to cover five different gameplay mechanics and VFX problems.

| Pilot | Gameplay mechanic proved | VFX problem proved |
|---|---|---|
| **Trảm Địa** | projectile + burst-first + surge (M03, S group) | a travelling wave that changes from flight to ground spread |
| **Hỏa Lôi** | delayed fuse zone (M07), armed-zone rules | a telegraph that counts down and then erupts |
| **Ngàn Kiếm** | multi-drop sky with `max_hits` (M05) | many objects appearing above the board, then a sequence |
| **Bẫy Kẹp** | trap zone + entry trigger (M09) | a persistent object that waits, then snaps |
| **Thánh Thuẫn** | ward re-anchor A2 (M10) | an own-half zone that must read as protective, not as a telegraph |

### 8.1 Trảm Địa — beat sheet
| t (ms, from swing end) | Beat | Module | Fallback clip |
|---|---|---|---|
| −300…0 | coil, then release slash at the hand | V01 steel charge, V07 | `cast_gesture` (hold frame 4 → 5) |
| −150…0 | wave flies low to the first cell | V02 steel wave | — |
| 0 | big square burst on the first cell (+ Pin flash if hit) | V04 big | — |
| 80 × step | surge cell to cell, crack line follows | V04 small + V13 crack | — |
| +400 | stamps fade, shards settle | V06 | — |
Validation: the first-cell burst is clearly bigger than the spread; the surge direction is readable on a `bar4`.

### 8.2 Hỏa Lôi — beat sheet
| t | Beat | Module | Fallback clip |
|---|---|---|---|
| −300…0 | palm taps the book, flicks down | V01 charcoal at hand | `cast_gesture` |
| 0 | sigils burn into each slab | V10 sigil (new) | — |
| 0…1500 | sigils shrink in three steps (3-2-1), brighter each step | V10 | — |
| 1500 | sigils collapse inward, stepped flame columns erupt | V05 big | — |
| 1500+ | burning cells with embers | existing `burning_cell`, V06 embers | — |
| disarmed (X3) | 0.2 s fizzle, no flame | V10 fizzle frames | — |
Validation: the countdown is readable without text at 1×; the boss brain visibly avoids the sigils; fizzle ≠ eruption.

### 8.3 Ngàn Kiếm — beat sheet
| t | Beat | Module | Fallback clip |
|---|---|---|---|
| −300…0 | sword raised overhead, held | V01 steel | `draw` last frame held, then `cast_gesture` release |
| 0…500 | a blade fades in point-down above each mask cell; shadows grow | V11 blade (new), V09 shadow | — |
| 500 + 120·i | blades drop from the centre outward; each stabs with a square splash | V11, V04 small | — |
| +600 | blades stay stuck, then crumble into squares | V06 | — |
Validation: blades above cells never cover the boss's HP plate; drop order readable; max 3 hits shown as 3 numbers.

### 8.4 Bẫy Kẹp — beat sheet
| t | Beat | Module | Fallback clip |
|---|---|---|---|
| −300…0 | kneel / palm slap on the floor | V01 jade | `cast_gesture` |
| 0 | open jaws fold up out of each slab | V16 `trap_jaw` (new) | — |
| idle (≤ 8 s) | jaws breathe 1 px; a faint jade outline | V16 loop | — |
| trigger | jaws snap shut with a square bite and wood chips; Pin bracket | V16 snap, V04 small | — |
| Pin end | jaws splinter | V16 break | — |
Validation: armed jaws distinct from thorns at 1×; the snap reads from across the board.

### 8.5 Thánh Thuẫn — beat sheet
| t | Beat | Module | Fallback clip |
|---|---|---|---|
| menu highlight | ivory ghost of the re-anchored shape around the Cleric | V16 `ward_frame` ghost (code) | — |
| −300…0 | staff planted, free palm raised | V01 ivory | `cast_gesture` |
| 0 | ivory frames draw themselves around each own-half slab | V16 `ward_frame` | — |
| 0…4000 | slow inner pulse; the Cleric glows faintly while on a ward cell | V16 loop | — |
| last 1000 | frames thin out and fade | V16 fade | — |
Validation: the ward never reads as an enemy telegraph (no red, no diagonal stripes, ivory frame not fill).
