# Quick Design Spec: Mỗi nhân vật một nhịp ra chiêu + chí mạng có điều kiện

**Type**: Addition (umbrella for 5 stories, one per hero; over a week in total, so each hero ships on its own)
**System**: Cast flow (`CombatView`, `CutEffects`), cards (`cards.json`), starter decks (`characters.json`), boss brain,
balance sim
**GDD Reference**: `design/game-brief.md` (no GDD at `workflow: minimal`); builds on `niem-dung-tran-2026-11-04.md`
(every cast stops the match, one 4 s clock)
**Date**: 2026-11-05
**Status**: Draft, written on the user's "Duyệt, viết spec" (2026-11-05); per-hero numbers are starting values

## Change Summary

Today all 33 cards are cast the same way: place pieces on enemy cells, pick a card, the card hits exactly those cells
once, at once. `delivery` only changes the drawing. Each hero gets **one cast rhythm of its own** (a new `cast_mode`
on cards) and every card gets a **crit condition** (`crit`), so heroes play differently from the first match.

## Motivation

User 2026-11-05: "skill của tất cả char đang gần như là giống nhau, không có một tí khác biệt gì"; "tôi cần cách cast
skill đa dạng hơn ở mỗi skill ... hiện tại nó basic cơ bản quá". Audit 2026-11-05: Kiếm Khí is in all 5 starters
(8 of 30 starter cards), the Assassin shares 6/6 starter cards, 4 of 5 signatures are timed multipliers, 2 of 5
passives are cell-count multipliers that both trigger at 4 cells, every card is `cell_mask: block_shape`.

References (research 2026-11-05):
- One Step From Eden ties each hero to one spell family: Hazel turrets, Terra tile breaking, Reva shields. Its spells
  differ by timing: Bomb Toss (delayed), Frostbolt (charge 0.3 s), Infinity Beam (channel), Mine (trap), Reflector
  (0.6 s reflect window).
- Mega Man Battle Network chips: TimeBomb (delayed), Tornado (8 hits), Mine (trap in the enemy area), Barrier /
  Recover (self), Guard (reflect), AreaGrab (steal a column).
- Dead Cells: conditional crits (Nutcracker on stunned / frozen / rooted, Oiled Sword on burning, Twin Daggers on the
  3rd hit, Flawless when not hit for 15 s); one item applies the state another crits on (Wolf Trap roots → crits);
  traps and turrets as skills (Wolf Trap, Double Crossb-o-matic). Steve Filby: each weapon needs its own play pattern.
- Into the Breach: every enemy attack is shown ahead, which is what makes counterplay readable.

## 1. Shared rules

### 1.1 `cast_mode` (new card field, default `"direct"`)

| Mode | Rule (resolution after the cast stop ends) |
|---|---|
| `direct` | As today: the card resolves on the placed cells at once. |
| `delayed` | The placed cells get a **fuse mark** for `fuse_sec`. When it ends, each marked cell resolves the card with damage x `fuse_mult`. A unit inside is hit; an empty cell is not. The mark is a visible floor telegraph with a countdown, on the enemy's half; the boss brain treats marked cells like an incoming swing (it may step off). |
| `combo` | The card resolves on the same cells `hits` times, `hit_interval_sec` apart; each hit is a full hit (keywords, Fragile consumption, passive / signature hooks). The combo counter (1.2) counts each hit. |
| `trap` | Pieces may be placed on enemy cells the enemy is not standing on (as today) and the card arms a **trap** on those cells for `trap_sec` instead of hitting. The first time the enemy enters a trap cell, every trap of that cast fires once: damage x cells of that trap on the entered cell's footprint, plus the card's keywords (e.g. Pin). Traps are visible to the player and to the boss brain (path cost like thorns, `trap_avoid`). Cast on the enemy's own cell, it fires at once. |
| `ward` | Pieces are placed on the **player's own half** (new placement rule for this mode only). Each covered cell becomes a ward cell for `ward_sec`: while the hero stands on a ward cell, incoming damage is multiplied by `ward_mult` and the hero heals `ward_heal_per_sec`. |
| `parry` | The card is available only while an enemy skill is in WINDUP or WARNING (`PatternController` stages). It resolves on the placed cells as `direct` (small damage) and opens a **guard** of `parry_sec` after the stop ends: the next enemy hit on the hero in that window deals 0, the enemy takes `reflect_mult` x that hit's damage and is pinned `parry_pin_sec`. No hit in the window: nothing else happens (the risk). |

Input stays the same on touch: pick pieces, place, pick the card (one 4 s clock). `ward` changes only which half the
pieces may land on; the card menu greys a `ward` card when pieces sit on the enemy half and the other cards when they
sit on the player's half.

### 1.2 `crit` (new card field)

`"crit": {"when": "<condition>", "mult": 1.5}`; a hit that meets the condition deals damage x `mult` and shows the
word **CHÍ MẠNG** over the target (bare emphasised text, no box, per the effect-label rule). Conditions (first set):

| `when` | True when |
|---|---|
| `target_pinned` | the target is pinned at the moment of the hit |
| `target_burning` | the target stands on a burning cell |
| `combo_3` | the hit is the 3rd (or later) hit of the same `combo` cast |
| `target_on_hazard` | the target stands on a player thorn or trap cell |
| `self_hp_high` | the hero's HP is at or above `crit_hp_ratio` (0.7) of max |

The card face shows one short line with the condition (vi/en strings). The crit multiplies after Fragile and before
defense, in the same place as the existing multipliers in `CutEffects.apply`.

### 1.3 Each hero sets up its own crits, and one other hero's

Pin comes from the Knight's parry and the Hunter's trap; burn from the Mage; thorns / traps from the Hunter. So the
Knight's `target_pinned` cards pay off on the Hunter's traps too, without shared cards (Dead Cells' Wolf Trap →
Nutcracker pattern). The card pool stays shared ("no classes"): any hero can find any mode as a reward; the starter
and the passive make one mode that hero's own.

## 2. Per hero (first card + starter change)

Each hero's new card **replaces one Kiếm Khí** in its starter (the cast-timeout fallback becomes that hero's first
starter card of its own mode). Card ids and names are working names, to be confirmed with the user.

| Hero | Rhythm | New card (working) | Numbers (start) | Crit on the hero's other starter cards |
|---|---|---|---|---|
| Kiếm sĩ | **Parry**: read the enemy's telegraph, answer it | `do_kiem` "Đỡ Kiếm", `parry`, min 1 cell, cd 6 s | dpc 3, `parry_sec` 0.8, `reflect_mult` 1.5, `parry_pin_sec` 1.2 | `target_pinned` x1.5 on kiem_vu, thiet_kiem, chan_phong |
| Pháp sư | **Delayed**: place where the boss will be, wait | `hoa_loi` "Hỏa Lôi", `delayed` + burn, min 2, cd 5 s | dpc 6, `fuse_sec` 1.5, `fuse_mult` 2.0, burn as hoa_xa | `target_burning` x1.5 on hoa_xa, hoa_tinh, hoa_tran |
| Sát thủ | **Combo**: several fast hits | `song_dao` "Song Đao", `combo`, min 1, cd 3 s | dpc 3, `hits` 3, `hit_interval_sec` 0.12 | `combo_3` x2.0 on song_dao; `target_pinned` x1.5 on kiem_vu, thiet_kiem |
| Thợ săn | **Trap**: arm cells ahead of the boss | `bay_kep` "Bẫy Kẹp", `trap` + Pin, min 2, cd 6 s | dpc 6, `trap_sec` 8, Pin 1.2 s on trigger | `target_on_hazard` x1.5 on tran_gai, gai_doc, ran_kich |
| Giáo sĩ | **Ward**: hold your own ground | `thanh_thuan` "Thánh Thuẫn", `ward`, min 2, cd 8 s | `ward_sec` 4, `ward_mult` 0.5, `ward_heal_per_sec` 2 | `self_hp_high` x1.5 on han_khi, han_kiem |

Passives and signatures are **not** changed by this spec (next pass: rule-changing passives and signatures, e.g. the
Assassin's signature lets casts skip the cast stop).

## 3. Readability (code VFX in this pass, art later)

- `delayed`: a floor mark per cell (block colour of the card) with a 3-2-1 countdown that shrinks; the boss sees it.
- `combo`: one hit flash per hit, the 3rd larger; damage numbers stack (3 numbers rising).
- `trap`: a small closed-jaw icon centred in each trap cell (floor VFX centred rule), opens when it fires.
- `ward`: own cells framed in the Cleric's ivory with a slow inner pulse; the hero glows ivory while on one.
- `parry`: the Knight holds a guard pose (reuse a frame of `draw` / `cast_gesture`) with a thin bar for `parry_sec`;
  a successful parry shows **ĐỠ** and a white flash on the enemy.
- `crit`: **CHÍ MẠNG** over the target, the damage number 1 step larger.

New hero cast clips per mode (PixelLab) are a later, separately approved art pass.

## 4. Balance and sim

`tools/balance/sim_core.gd` must model each mode (fuse with boss dodging, combo hits, trap triggers, ward damage
taken, parry against enemy hits) and print per-hero measures: fuse hits / match, combo 3rd-hit crits / match, trap
triggers / match, damage absorbed by ward / match, parries / match, crits / match. Tuning targets: ch1 chapter win
35–65 % for every hero (40 seeds, build policy), and **no tuning of mode cards toward 6 per cell**: a hero is tuned
through its own measure first (e.g. fuse hit rate 40–70 %, trap trigger rate 50–80 %).

## 5. Order and cost

One story per hero, each: data + `CutEffects` / `CombatView` rule + card text + code VFX + sim model + tests +
evidence. Order by risk: **Sát thủ combo** (only reuses the hit path) → **Pháp sư delayed** (reuses telegraph and
boss avoidance) → **Thợ săn trap** (reuses zones) → **Kiếm sĩ parry** (needs the enemy stage hooks) → **Giáo sĩ
ward** (new placement half). Crit (1.2) ships with the first story.

## 6. Acceptance Criteria (per story; all must hold before the hero's story closes)

- [ ] The mode resolves as in 1.1, with a unit test per rule (e.g. combo: 3 hits, the 3rd crits with `combo_3`;
      delayed: a unit that leaves the cell before the fuse ends takes nothing; trap: fires once on entry, not before;
      ward: damage x0.5 only while standing on a ward cell; parry: a hit in the window deals 0 and reflects, none
      outside it). Each test watched failing before the code.
- [ ] Crit conditions as in 1.2, with tests for each `when` used by that hero.
- [ ] Card texts vi/en fit the card face and the battle card (existing text tests pass).
- [ ] The hero's starter has its new card in place of one Kiếm Khí; the cast-timeout fallback picks an available card
      as today.
- [ ] `deck_sim` ch1 (40 seeds): the hero 35–65 %, its own measure inside its band, the other heroes unchanged within
      noise.
- [ ] Retained screenshots in `production/qa/evidence/<mode>/`: the telegraph / trap / ward / guard visible, a crit
      shown.
- [ ] Full suite green; bot matrix (`tools/qa/run_bot_matrix.sh`) with that hero: 0 violations.

### Knight story (Kiếm sĩ parry + shared crit), implementation note 2026-11-05

Status of the per-story criteria for the Knight (the boxes above stay open until all five heroes close):

- [x] Parry resolves as in 1.1, one unit test per rule (`tests/unit/combat/parry_crit_test.gd`, watched failing first):
      unavailable with no telegraph, available in WINDUP / WARNING and during a block-brain boss swing; a strike in the
      window deals 0, reflects x`reflect_mult` and pins; a strike after the window hurts; a burn tick is not parried; a
      boss swing is parried and does not interrupt the hero.
- [x] Crit `target_pinned` with tests (only when pinned, x1.5 after Ran, cards without crit never crit).
- [x] Card texts vi/en fit the card face and the battle card (card_face_battle_text / card_face_layout tests green).
- [x] Starter: `do_kiem` replaces the Knight's one Kiếm Khí; the timeout pick takes a random AVAILABLE hand card as
      today (so never `do_kiem` without a telegraph), Kiếm Khí when none is.
- [ ] `deck_sim` ch1 40 seeds: see the story report (numbers below in the hand-back; the parry success rate is low and
      crits are rare, see Deviations).
- [x] Retained screenshots: `production/qa/evidence/parry/` (guard bar during the warning, PARRY + reflected number on a
      Frozen enemy, CRIT on the Frozen enemy). English locale captures; the vi words are CHÍ MẠNG / ĐỠ.
- [ ] Full suite green (see the hand-back); bot matrix with the Knight not run.

Decisions made while implementing (for review):

1. **The parry card's own hit never interrupts** the enemy attack it answers (`SwingArbiter` result `no_interrupt`;
   the view and the sim skip `PatternController.on_enemy_hit`). Otherwise every interruptible skill (the default) is
   cancelled by Đỡ Kiếm's small hit and no parry could ever land.
2. **What a parry takes**: the next enemy SKILL hit only: pattern strikes (damage and their status, e.g. Root, are both
   negated; zones still form) and block-brain boss swings through the damage path. Not parried: burn ticks, thorn steps,
   trait blasts (fuse cannon, row burner, slam), relic damage, a boss card that only ignites / pins.
3. **Availability** counts only ATTACK skills (a self buff / marker windup is no telegraph) and the block-brain boss's
   running or queued swing. The context is injected (`SkillAvailability.check(..., context)`,
   `CutFlow.availability_context_fn`, `CombatView.get_availability_context`); an empty context = no telegraph.
4. **Guard start**: the guard opens when the card is chosen and ticks only on match time, so its `parry_sec` starts when
   the match runs again after the cast stop.
5. **Wording**: the pin is shown to players as "Đóng Băng / Frozen", so the crit line reads "Chí mạng x1,5 lên địch
   Đóng Băng." / "Crit x1.5 vs Frozen." (`{crit_mult}` placeholder).
6. `do_kiem` is a common, upgrade `reflect_mult` +0.25; it sits last in `card_order`; non-direct cards are out of the
   boss card list; the dpc 6-7 curve check exempts mode cards (spec 4: no tuning toward 6 per cell).
7. Guard pose = the Knight's `draw` clip held on its last frame (UnitLayer `parry_guard`); a sheet without `draw` idles.

## Open (for the user)

- Card names and the exact numbers per hero (starting values above).
- Whether Kiếm Khí stays in the starters at all (this spec removes one copy per hero).
- The next pass on passives / signatures and on hero cast clips per mode (art).
