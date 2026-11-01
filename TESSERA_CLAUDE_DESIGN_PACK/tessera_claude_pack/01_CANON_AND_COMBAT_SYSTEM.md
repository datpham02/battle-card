# Tessera — Canon and Combat System

## 1. LOCKED world and visual grammar
- Western high-fantasy world shattered by the Cataclysm. The Primal Form broke at the mountain summit, the Lattice Heart. A square-tile lattice spread over lands. All techniques, swords and magic are only powered through joined-square **BLOCKS**.
- Each land is slab-tiled over its former landscape and defended by a Warden possessing a small gold-tile shard of the Primal Form.
- Quiet, melancholic, readable pixel art. Landscape battle native **640×360**, nearest-neighbor scale; heroes ~**40 pixels** in **32×48** frame; boss nominal **52 pixels** in **48×64** frame (concept art can enlarge 6× for inspection).
- Character and Block: **1px dark ink outline `#1B1722`**; background/slab scenery: **no black outline**. Desaturated background/dark slabs, no glows except Blocks and the Lattice Heart. Strict crisp square pixels, no blur/antialiasing/dither bloom.
- Palette anchors: stone `#4A4640`, mist `#7D8896`, ivory `#EFE6D2`, gold `#FFD45C`, blue steel `#8FA3B8`, amber `#F0A030`, jade-white `#BFF3EC`, jade `#46D6A4`, odd magenta `#E04CD0`; warning red `#E5293B` **exclusively** for imminent incoming-attack warning tiles.
- Magic is represented by square tiles, block stamps, square shards and square particles. No circular magic explosions, beam lines or illuminated terrain. Traveling effects are allowed only as square-based visuals under §1A (skill casting rules, 2026-11-01). Orange/yellow volcanic cracks are static color, not bloom.
- Battle camera: orthographic side-on stage, **no perspective**. Tiles are equally sized flat horizontal rectangles ~1.5× wider than tall; straight horizontal/vertical grid lines; thin 2–3 px front lip; two untinted side-by-side grids separated by small gap, hero left and foe right, characters' feet inside one floor tile and upper halves overlapping back row. Side-view background near top.
- Heroes cast by short shoulder-high motion, no halo and no Block in hands; the gameplay Block object is never thrown. A skill's visual may travel from its origin as a square-based effect according to its delivery type (§1A). Enemy windups are readable; boss windup described in sheets: hunched, one arm back, other forward, empty hands, a few tiny ivory *square* particles at back hand. Only selected floor tiles light up in the player material color. Monster warnings are diagonal striped red with outlines over characters.
- Never render letters, logos or runes on blocks/terrain. Gameplay UI can use compact names/numbers when specifically requested, but concept illustrations generally have no text.

## 1A. LOCKED skill casting rules (user-confirmed 2026-11-01)
The earlier rule that every effect falls from above or materializes directly on the selected tiles is **obsolete**. A skill is described by three separate concepts:

1. **BLOCK SHAPE** defines which logical grid cells are affected (the cell mask). Only these cells take damage or status.
2. **SKILL DELIVERY** defines the visual's origin and travel:
   - `CASTER_TO_TARGET`: leaves the caster (hand or weapon) and travels to the target cells.
   - `SKY_TO_TARGET`: drops onto the target cells from above.
   - `GROUND_PROPAGATION`: runs along the floor slabs from an origin cell to the target cells.
   - `DIRECT_MANIFESTATION`: appears in place on the target cells.
   - `SEQUENTIAL_CHAIN`: resolves cell by cell in a defined order, starting from a first cell.
3. **IMPACT EFFECT** defines what plays on each affected cell: slash, burst, shatter, burn, freeze, poison, knockback, guard, etc.

Rules:
- Traveling **square-based** effects are allowed (square-pixel streaks, square shards, stepped square trails). Circular explosions and beam lines stay forbidden.
- **Never throw the actual gameplay Block object.** The Block is the targeting shape, not a projectile.
- **Path visuals never cause extra, untelegraphed damage.** Damage and status apply only on the cell mask (telegraphed in red for enemy skills).
- Every player, enemy and boss skill must define its **delivery type, origin, travel animation, impact animation and affected cell mask**.
- **Do not default every skill to `SKY_TO_TARGET`.** Pick the delivery that fits the skill (a sword slash travels from the caster, a falling rock comes from the sky, a root runs along the ground, a curse manifests in place, a spark jumps cell to cell).

## 2. LOCKED BLOCK geometry and material
Each Block consists of `1..7` unit squares connected edge-to-edge in orthogonal 4-neighborhood. Examples: 1, domino, 3-cell L, 2×2 square, 4-cell T, 4-cell S, 4-cell bar, 5-cell cross, 5-cell U; 6- and 7-cell Odd Blocks in magenta with one shape outline. Rotation allowed by quarter turns; no reflection by default (PROPOSED). Shape identity is separate from block art/material. Block scale on floor ~1/3 of a terrain tile and hovers 2 native px above slab with dark square shadow. Target area is full-size **terrain tiles**, not block icon.

Material only influences visual identity unless a skill explicitly checks it: steel bevelled, charcoal with amber cracks, translucent jade-white ice, jade-rope wood, lilac stained glass, ivory enemy, magenta Odd. Do not let the material alone infer magic school or status effect.

## 3. PROPOSED — unify active combat
**Skill Card**: gameplay effect, target policy, cooldown/charge/resource demand, rarity, tags, upgrade. **Block Token**: player-selected set of tile offsets/rotation. A character has a starting skill set and a run-grown deck. Card-bar produces cards/tokens with weighted drop rates (existing concept); implementation must decide whether two separate lanes or a combined bar. Do not hardwire turn-based draw/discard assumptions.

**Suggestion for a first playable prototype:** A small hand of 3 available Skill Cards, 3 Block slots, action/energy resource, shared cooldown 0.4 sec, a scrolling weighted bar of incoming Block Tokens, and active movement. Aim: readable mobile touch play, not a frantic particle spectacle. All these numbers are tunable.

### Proposed action pipeline
`READY -> CHOOSE SKILL -> CHOOSE/ROTATE BLOCK -> HOVER FLOOR TARGET -> VALIDATE -> CHARGE -> DELIVER -> IMPACT -> RESOLVE IN TILES -> RECOVERY -> READY`

1. Normalize shape tile offsets; rotate clockwise; compute target set on opponent grid. Reject pits, out-of-bounds, duplicate/nonconnected shapes if skill forbids.
2. Enemy-tile selection visually lights **exactly the targeted floor tiles** in the hero's Block color. Use full-tile fill and 2px outline, check mark only on tile occupied by foe.
3. During charge raise tile brightness using palette-swapped stepped frames, not bloom.
4. Play the skill's delivery from its origin (§1A; the path deals no damage), then at resolution show the impact effect **on targeted tiles**, then damage/status/push. For a delayed chain, tile A resolves first; new warned tiles B/C must be visibly announced before secondary resolution.
5. Record combat events so synergies can trigger without circular loops.

### Primary rules to settle before coding
- **Hit model:** Any actor standing in a targeted valid floor tile is hit; multiple overlapping targets never count twice on the same resolution unless a skill states multi-hit.
- **Terrain:** Pit cannot be occupied/targeted. A pushed actor cannot be moved into pit unless a skill explicitly defines fall damage and recovery; default movement into pit is rejected.
- **Statuses:** `burn` (damage over time), `poison` (sustained damage), `freeze` (slower/movement lock), `root` (no movement), `mark` (next hit amplified), `guard` (barrier), `fragile` (take bonus damage), `echo` (repeat next block once), `charge` (store pending proc). Ticks and caps are tunable; e.g., status stack cap 5, freeze 1 activation, echo repeat 1 once.
- **Rotation and transforms:** Preserve edge adjacency and max 7 cells. When splitting, all fragments must each be valid connected Blocks if stored as pieces.
- **Timing:** Warnings tell exactly *which tiles* and *when* an enemy skill hits. Prefer 0.8–1.5 second normal telegraphs and longer elite/boss, tune after mobile tests; make a player reachable safe tile whenever attack claims to be dodgeable.
- **Anti-loop:** One trigger can create at most one `echo` child; child hits cannot retrigger the same echo or self-generate resources in the same resolution chain.

## 4. Card design taxonomy (180 proposed entries)
- Attack 40; block manipulation 35; status/control 30; defense/mobility 25; combo/economy 25; Odd/Legendary 25.
- Pool distribution proposal: ~55% neutral/shared, ~25% hero-affinity (Knight/Mage/Rogue/Ranger/Cleric), ~20% unlockable/special. Do not lock all synergistic components behind a single hero; keep cross-hero build creativity.
- Tags rather than card names drive synergies: `slash`, `stamp`, `burst`, `burn`, `poison`, `frost`, `trap`, `guard`, `move`, `echo`, `combo`, `odd`, `split`, `merge`, `rotate`, `chain`, `tile`, `shatter`, `economy`.
- A rarity controls appearance *frequency and complexity*, not simply raw numerical power. A low-rarity common should still remain playable in a focused build.

## 5. Design principles for enemies
- One enemy = 1 strong silhouette, 1 distinct attack pattern, 1 distinct counterplay; elite adds a new rule rather than only +HP.
- All attacks show a warning occupancy mask (red), then square impact particles; no instant red-free damage.
- Distinct enemy families: pressure / control / zone denial / disruption / summon / block sabotage; only combine 2+ when elite or boss.
- Elite gimmicks are taught safely by a corresponding normal enemy before the elite appears.
- Boss has 2–3 phases telegraphed by HP/behavior, at least 1 learnable mechanic, 1 counterplay, 1 big square-tile spectacle. Boss phase transitions MUST not cause unavoidable damage.
