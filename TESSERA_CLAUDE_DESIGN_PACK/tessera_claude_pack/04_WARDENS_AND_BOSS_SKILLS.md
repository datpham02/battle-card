# Tessera — Warden Bosses and Skill Design

**PROPOSED gameplay.** All eight bosses are canon concept characters; moves, timings and phase thresholds below are new proposed mechanics. Each Warden floats a **small irregular lattice-gold square-polyomino Primal Shard** above its head. This shard is not a round magic halo. Boss winds up with one hand back, one forward, empty hands and a few ivory square particles. When firing, warn exactly the struck tiles in red diagonal stripes; resolve in square particles, never beams. A boss skill may travel as a square-based delivery (`01` §1A) and must declare its delivery type, origin, travel animation, impact animation and cell mask; do not default to sky-to-target. Orange cracks and other creature colors never use red. Boss logical occupancy = one terrain tile despite large sprite.

**Legend:** `C`=common cast, `H`=heavy cast, `P`=phase. The specified pattern is a set of valid terrain tiles; rotate around chosen legal anchor and clip only if skill allows. Pattern visibility must be identical to hit resolution. Boss cannot choose an un-dodgeable pattern unless clearly labeled as a barrier/guard check with a guaranteed defensive answer.

## 1. Forest Witch — Warden of Misty Forest Ruins
Theme: **Root propagation, anchoring, gradual control**. Shape: crooked headdress of roots, root staff stays at side, long moss mantle.

| Skill | Warned pattern / timing | Gameplay result | Counterplay |
|---|---|---|---|
| Root Nail (C) | 1 occupied/current tile; 1 beat | Low hit + Root for 1 short beat | Sidestep before first stamp |
| Branch Lattice (C) | 3-cell L; next beat another 1-cell branch | First hit + 1 delayed secondary square | Follow red floor warnings, never guess direction |
| Entangled Row (H) | 3 contiguous cells in a row, 1.5 beats | Medium damage and mild Slow | Move to another row |
| Moss Guard (utility) | Self tile in muted ivory outline, no red | Gains barrier until root anchor destroyed | Focus one of clearly marked anchors |
| Root Anchor (mechanic) | Spawns 1–2 visible non-glowing root anchor markers on valid empty tiles | Next attacks extend toward those tiles | Break anchor via any block target; not hidden RNG |
| Withered Crown (P2) | Alternate 2-cell bars, second follows first after 1 beat | Pressure while allowing move-between gaps | Exit first lane, do not run into next warning |
| Forest's Last Knot (P3 finisher) | 4-cell T area then one center repeat, sequential | High threat, never full-board unavoidable | Clear anchor first or move to shown safe tile |

Phases: `>65%` teach anchors; `65–30%` 2 anchors + branch; `<30%` sequential T finisher every third cast. At phase transition boss spends one no-damage telegraph beat showing darkened roots. Builds that break anchors or exploit cooldowns feel good; a 1-cell starter Block must always be able to break one anchor.

## 2. Ogre King — Warden of Dark Dungeon
Theme: **Chain control, heavy two-beat pressure, slab breakage**. Shape: huge shoulders, rusted chain sash, cracked crown, square stone fists.

| Skill | Warned pattern / timing | Result | Counterplay |
|---|---|---|---|
| Chain Snare (C) | 1 tile, 1 beat | Slow/Root after visible chain squares land | Step out before hit |
| Iron Cell (C) | 2-cell line and one adjacent locked tile | Temporary unavailable cell for one beat | Choose parallel escape lane |
| Hammer Column (H) | 3–4 valid cells in a column, 1.7 beats | Heavy stamp and knock 1 legal square | Move sideways; no push into pit by default |
| Rust Guard (utility) | Self tile | Guard rises after he takes a hit | Shatter with second hit, poison bypass optional |
| Broken Chain (C) | 3-cell L on opponent side, strikes after 2 beats | Medium hit, marks location for echo | Remember shape and move in time |
| Dungeon Collapse (P2) | Clearly marked empty slab turns into pit after next beat | Board shrinks temporarily; NO instant pit under a player | Plan a new escape route; tile restores after 2 beats |
| King's Sentence (P3) | Two **separate** 2-cell bars in sequence | High damage if both hit; 1 beat between | Use the safe middle tile; guard last strike |

Phases: `>70%` single chain + slam; `70–35%` temporary pit and recovery; `<35%` sentence combo. Always reserve two reachable non-pit tiles when building an obstacle pattern.

## 3. Frost Lord — Warden of Mist Tower
Theme: **Freeze clock and repeated tile memory**. Shape: half-stone half-ice, fractured ice antlers and broad gray-white collar.

| Skill | Warned pattern / timing | Result | Counterplay |
|---|---|---|---|
| Cold Stamp (C) | 1 tile, 1 beat | Frost stack 1 | Shift before landing |
| Ice Fork (C) | 3-cell L, 1.2 beats | Slow + light damage | Exit the L foot |
| Glass Column (H) | 3-cell vertical line, slow windup | Freeze if already slowed | Change columns early |
| Shard Mirror (mechanic) | Records last player-targeted Block shape, shows ghost preview then red tile warning | Repeats **valid** version on player tiles after 1 beat | Watch final mask, rotate your next action for safety |
| Bell of Snow (C) | Warn 3 distinct single cells sequentially | Small hits and stacked frost if stationary | Move after each stamp |
| Frostbreak (P2) | One tile frozen gray, cracks in 2 beats; if hit, applies Fragile | Temporary terrain hazard, no instant pit | Stay off cracked tile until resolved |
| Last Winter (P3) | First cross then a *different* 3-cell L, sequential; not whole board at once | Medium area hit on two beats | Escape to the shown safe edge; defense answers overlap |

Phases: `>65%` Slow teach; `65–30%` recorded mirror; `<30%` rotating delayed patterns. Freeze should not disable both movement and cast simultaneously without counter.

## 4. Toad Matriarch — Warden of Poison Swamp
Theme: **Poison tiles, cleanse timing, limited safe space**. Giant olive toad, mushrooms/moss on shoulders, light ivory gullet, no red or glowing poison.

| Skill | Warned pattern / timing | Result | Counterplay |
|---|---|---|---|
| Mud Swat (C) | 2 adjacent cells, 1 beat | Low damage + safe one-cell push | Avoid edge/pit adjacency |
| Spore L (C) | 3-cell L, 1.25 beats | Poison stack | Exit before stamp |
| Sticky Cushion (utility) | 1 visible dull olive hazard tile | Slows move/cast while occupied, expires 2 beats | Break/cancel hazard or route around |
| Bog Choir (H) | 3 separated single tiles; second beat expands each by one if valid | Delayed poison squares | Move to area outside expansion; red previews expansion ahead of hit |
| Toad Belly Guard (defense) | Self tile outlined ivory (not enemy warning) | Absorbs first Block hit | Multi-hit or shred then punish recovery |
| Mycelial Wave (P2) | 2-cell row repeats once on same locations | Poison stack on repeated hit | Don't return early |
| Mother of Spores (P3) | T-shape strike then one post-hit hazard tile | Burst + poison zone | Dodge T and avoid lingering hazard; cleanse after |

Phases: `>70%` single poison attacks; `70–35%` growth/repeats; `<35%` T finisher. Teach the exact growth mechanic using Sporecap enemies before boss.

## 5. Sand Sphinx — Warden of Buried Sands
Theme: **Remember marked cells, delayed attacks, fair deception**. Winged cracked stone lion with ancient mask, dull old turquoise ornaments, no mystic rune text.

| Skill | Warned pattern / timing | Result | Counterplay |
|---|---|---|---|
| Sand Paw (C) | Single tile, 1 beat | Small blunt hit | One-cell dodge |
| Ancient Column (H) | Up to 4 valid cells of a column, 1.6 beats | Large hit | Exit column |
| Sand Clock (C) | 1 cell now + same tile after exactly 2 beats | Two small hits | Memorize the marker; don't return prematurely |
| Buried Arch (mechanic) | One empty slab gets a non-glowing sand mound, temporary impassable, 2 beats | Paths constrict; does not trap player alone | Choose route before column hit |
| Shifting Sphinx (C) | Two light-grey candidates displayed; only 1 turns red with 0.8s warning before hit | Single hit; fake markers are never red | React to final red warning |
| Wings of Dust (P2) | Alternating 2-cell bar, then rotated 2-cell bar | Medium hit in 2 beats | Move across first shape rather than chasing boss |
| Last Riddle (P3) | Sequence `1 cell -> 3-cell L -> 2×2`, each shown before resolution | Large temporal puzzle | Step through safe tile each beat, or guard last |

Phases: `>65%` slow memory attacks; `65–30%` introduce grey candidate markers; `<30%` Last Riddle. Nothing ever inflicts damage from false hint alone.

## 6. Inferno Demon Lord — Warden of Hellfire Citadel
Theme: **Orange-yellow cracks, delayed burn, temporary pit creation**. Charcoal armor, amber-orange seams, horns (no red cloth, fireballs or fiery aura).

| Skill | Warned pattern / timing | Result | Counterplay |
|---|---|---|---|
| Ember Press (C) | One tile, 1 beat | Burn 1 | One-cell dodge |
| Furnace Line (C) | 3-cell row, 1.1 beats | Medium hit + Burn | Exit row |
| Cracked Cross (H) | 5-cell cross where valid, 1.5 beats | Burst + Fragile, no round explosion | Stand in a clearly safe diagonal cell |
| Scorched Memory (mechanic) | Re-warns one valid location hit previously, after 2 beats | Repeat attack at known tile | Recall the last stamp, don't reoccupy |
| Broken Hearth (P2) | Mark one **empty** slab with orange fissure (not glow), then clear warning before it becomes a pit | Temporary pit for 2 beats | Plan path, cannot directly open under occupied actor |
| Ashen Guard (utility) | Self tile | Guard on next two attacks | Multi-hit, pierce or focus after guard duration |
| Citadel Verdict (P3) | Alternating 3-cell line then 3-cell L after short pause | High delayed burn pressure | Exit first line to a tile not in upcoming L; block/cleanse next |

Phases: `>65%` line attacks; `65–30%` delayed pits; `<30%` two-stage verdict. Enemy-tile warning red is still allowed, but no **red** lava/clothing/character VFX.

## 7. Storm Dragon — Warden of Sky Isles
Theme: **Floating bridges, pit-safe movement, sequential gusts**. Slate/ivory dragon coiled around dark stone island fragments; no round lightning spell bolts.

| Skill | Warned pattern / timing | Result | Counterplay |
|---|---|---|---|
| Talon Stamp (C) | 2 adjacent cells, 1 beat | Medium hit | Step sideways |
| Wind Fork (C) | 3-cell L, 1.2 beats | Push one legal tile, no forced cliff fall | Dodge toward safe edge |
| Cloud Step (mechanic) | Boss shows destination square then moves after one beat | Relocates logical origin | Target future square |
| Bridge Fracture (H) | Announce one empty bridge tile; pit appears after two beats | Temporary unavailable floor for 2 beats | Cross before break or choose other bridge |
| Storm Sequence (C) | 3 one-tile stamps in traveling sequence, red warning per beat | Sustained pressure | Move perpendicular to advancing line |
| Gale Ring (P2) | 4-cell perimeter subset, not full-board | Moderate damage to designated ring tiles | Stand on interior gap or guard |
| Skyfall Pattern (P3) | 4-cell T then delayed 2-cell bar on different row | High pressure | Hold safe exit; don't jump into cracked bridge |

Phases: `>70%` teach gusts; `70–35%` one temporary broken bridge; `<35%` skyfall mix. If island grid is split into two sections, maintain at least one available traversable route or guaranteed in-place defensive answer.

## 8. Heart Keeper — Final Warden of the Lattice Heart
Theme: **The original square grammar itself**; calm, ancient, non-evil guardian. Layered engraved gray slabs and gold lattice tiles, no red appearance. Visual heart at summit should be the established **floating golden CUBE**, not a flat heart glyph.

| Skill | Warned pattern / timing | Result | Counterplay |
|---|---|---|---|
| First Square (C) | 1 tile, 1 beat | Minimal hit; establishes rhythm | Dodge/guard |
| Memory L (C) | Copies last player-targeted connected L or bar into a legal warned area | Medium hit, same cell count capped to 4 | Read final floor mask, move to unmarked tile |
| Quarter Turn (mechanic) | Previews existing 3-cell L then visibly rotates 90°, final red mask has full warning | Hits rotated final mask only | Act on **final** red, not preview |
| Broken Unity (C) | 2×2 target then square shard particles on each cell | Medium area hit | Move outside square |
| Twin Stamp (P2) | 2 separate small patterns, one beat apart | Medium combo | Save mobility/guard for second |
| Lattice Repair (utility) | Restores one previously pit tile; self barrier for one beat | Shifts safe path and gains guard | Exploit newly safe floor, remove guard |
| Form Dissolution (P3) | 5-cell cross then 1-cell repeated center, each clearly warned | Large finale, always with safe path or shield answer | Use previous lessons: remember, move, block |

Phases: `>70%` show simple primary shapes, `70–35%` shape rotation and twin stamps, `<35%` bigger form. On defeat the gold cube becomes steady and quiet rather than a violent non-square blast. Reward closes run.

## AI decision logic and fair telegraphs
1. Every boss picks from phase-eligible skills, considering current safe-tile count, player status and recent move history. Avoid using exactly the same punishing skill repeatedly.
2. `canCast(skill)` must verify: warned targets exist; shape fits; no incorrectly targeted pits; a valid player response exists; the arena maintains movement access; overlapping warnings are clearly distinct by time.
3. The telegraph mask is built from the **same tile coordinates** as damage resolution. If arena changes between warn and hit, either recompute and show fresh warning or cancel/retarget; never silently redirect.
4. On phase change, pause aggression for a visible square-particle transformation that is not a damaging attack.
5. Add a **minimum recovery window** after hard skills in which players can perform one meaningful action, and cap stacked CC to prevent soft-lock.
6. If multiple enemies or environmental hazards are present with boss, cap total warned floor percentage and maintain defensible safe cells.

## Proposed boss artifact themes
Forest: `Root Anchor Breaker`; Dungeon: `Chain Reflector`; Tower: `Frost Clock`; Swamp: `Spore Recycler`; Sands: `Hourglass Echo`; Citadel: `Ash Combiner`; Sky: `Bridge Stitcher`; Heart: `Lattice Rewriter`. Each artifact should synergize with at least two classes, not just one required hero.
