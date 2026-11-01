# TESSERA — COMPLETE GAME DESIGN KNOWLEDGE PACK

> CONVENTION: LOCKED = user-confirmed. PROPOSED = new design that must be reviewed and tuned.

This one-file export contains all eight Markdown chapters. See the ZIP for separate chapters and JSON data.


---

<!-- START 00_README_FOR_CLAUDE.md -->

# TESSERA — Design knowledge pack for Claude

**Purpose:** Produce a coherent roguelike, real-time grid-combat mobile game design. Treat these files as a *design proposal and data seed*, not as already implemented gameplay. Canon marked `LOCKED` must not be silently altered. All balance numbers are `PROPOSED / TUNE IN PLAYTEST`.

## Read order
1. `01_CANON_AND_COMBAT_SYSTEM.md` — setting, style rules, combat grammar and card/block interaction.
2. `02_ROGUELIKE_MAP_AND_ECONOMY.md` — tiers, branching rooms, choices, reward/shop/events and safeguards.
3. `03_ENEMY_ROSTER.md` — normal and elite monsters per Warden, moves and counters.
4. `04_WARDENS_AND_BOSS_SKILLS.md` — all eight bosses, distinct phases and skill telegraphs.
5. `05_PLAYER_CARDS.md` — 180 proposed player cards, split into six categories.
6. `06_DATA_MODEL_AND_IMPLEMENTATION.md` — ready-to-code typed data, generation and AI rules, tests.
7. `07_CLAUDE_TASKS.md` — exact prompts/tasks to give Claude for incremental implementation.

Supporting data: `cards.json`, `enemies.json`, `bosses.json`; optional for programmatic import. Source of conceptual truth is Markdown. The machine-readable examples are seed designs, not final balance data.

## Important design decisions
- **Skill Card ≠ Block Token.** A Skill Card defines *what happens*; a Block Token (1–7 connected square cells) defines *where it happens*. Their composition creates build diversity. This separation is a **PROPOSAL**, not confirmed canon, and should be validated before implementation.
- Tessera is a **mobile landscape active battle game**, not automatically a turn-based deckbuilder. `beats`/`seconds`, cooldowns, card-bar flow, and stamina in this pack are proposals.
- Common and elite enemies attack through the exact same square-grid grammar as bosses. There are **23 regular enemy archetypes and 16 elites** across 8 regions (including the summit), with **8 Warden bosses**.
- Every boss has its own enemies, elite variants, and traversal choices. No generic filler encounter should overpower region identity.
- The prior map concept called for *five tiers with two lands per tier*, but only seven regional Wardens + the summit are canon. The map plan uses **two choices of route** in tiers four and five rather than inventing new Warden lands. This preserves the named world.

## Constraints for Claude
- Reuse exact color and pixel guidelines. Do not introduce wuxia/xianxia, red attacks (except warning tiles), round spell explosions, beams, glowing scenery, floor perspective, runes or letters in rendered art. Traveling square-based skill visuals are allowed under the skill casting rules (`01` §1A, 2026-11-01); the gameplay Block object is never thrown.
- An `L` pattern needs an explicit number of cells; there are L-shaped triominoes (3) and tetrominoes (4). Do not interchange them.
- A card effect must specify pattern, target rules, timing, stacking, status interactions, telegraph, counterplay, and upgrade path before implementation.
- Never assume an attack can target a pit. Pit tiles are not valid attack/support locations unless a move *explicitly* changes terrain.
- Don't have character sprites hold or throw Blocks when using hero magic: the target cells illuminate as the cell mask, and the skill's delivery (`01` §1A: caster-to-target, sky-to-target, ground propagation, direct manifestation or sequential chain) carries the visual from its origin to those cells. Normal monsters may telegraph overhead flat block per canon; particular boss cast poses have **empty hands**.

## Suggested implementation sequence
1. Deterministic grid and polyomino placement; selection and overlapping-characters warning rendering.
2. Timed telegraph/cast/resolve pipeline; unified abilities and status rules.
3. One land vertical slice: Misty Forest, 3 common + 2 elite + Warden; branch/shop/reward/rest.
4. Player card & block token system and build screen, starting with a small tested subset.
5. Expand content land-by-land with data-driven assets, localization and balancing.
6. Full 180-card pool only after telemetry, card-draw flow, and encounter pacing stabilize.


<!-- END 00_README_FOR_CLAUDE.md -->


---

<!-- START 01_CANON_AND_COMBAT_SYSTEM.md -->

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


<!-- END 01_CANON_AND_COMBAT_SYSTEM.md -->


---

<!-- START 02_ROGUELIKE_MAP_AND_ECONOMY.md -->

# Tessera — Roguelike World Map, Encounters and Choices

All node rates, currencies and route lengths below are **PROPOSED**. The named lands, Wardens, and visual constraints are LOCKED.

## 1. The five-tier ascent (run structure)
| Tier | Left choice | Right choice | Boss at route end | Notes |
|---|---|---|---|---|
| I — lower slopes | Misty Forest Ruins | Dark Dungeon | Forest Witch OR Ogre King | Learn terrain and warnings |
| II — mid slopes | Mist Tower (Ice) | Poison Swamp | Frost Lord OR Toad Matriarch | Commitment to control/status |
| III — upper slopes | Buried Sands | Hellfire Citadel | Sand Sphinx OR Inferno Demon | High-pressure repositioning |
| IV — cloud ring | Sky Isles: Stable Bridges | Sky Isles: Shattered Bridges | Storm Dragon (both) | **Two routes within one canon land**, one safe, one high risk |
| V — summit | Lattice Heart: Lower Dais | Lattice Heart: Upper Dais | Heart Keeper (both) | **Two routes within one canon land**, not two invented lands |

The earlier idea of two distinct *lands* on every tier is presently inconsistent with seven named land Wardens plus summit. These routes make all five map rows offer two meaningful selections **without adding unapproved land lore**. If two *different lands* on tiers IV/V become a requirement, request new canon regions instead of inventing them.

Each chosen tier creates a small branching route: ~**5 nodes + Warden**; 2–3 path candidates at most decisions. Shorter mobile runs can use 3 nodes + Warden or checkpoints (PROPOSED). After defeating a Warden take a **Primal Shard** as run progression plus a reward choice, NOT a mandatory deck card. A defeated land is skipped until next run; alternative paths remain for replay.

## 2. Node types and purpose
| Node | Icon concept | Trigger and reward | Player choice |
|---|---|---|---|
| Common Battle | crossed swords | 1–3 regular monsters; choose 1 of 3 cards or one Block Token + coins | Safe improvement, learn a pattern |
| Elite | warning triangle | 1 elite + optionally 1 helper normal; rare card, artifact, shard fragments | Higher reward and higher risk, always visible in advance |
| Boss | skull/crown | Region Warden, guaranteed region artifact + advance to next tier | Build test; no arbitrary one-hit mechanics |
| Treasure | chest | 1 of 3 rewards: rare card / block upgrade / coins | Specialize deck or secure economy |
| Merchant | coin pouch | buy cards/tokens/artifacts; pay for repair, remove, upgrade, reroll | Optimize economy and trim weak deck |
| Rest / Camp | campfire | heal OR upgrade 1 card OR reshape one permanent Block Token | Recovery vs scaling |
| Event | geometric question tile | small narrative choice, e.g. exchange HP for shard, take temporary curse for relic | Knowledge, risk/reward |
| Shrine / Forge | four-square icon | rotate/upgrade/split/reforge Block Tokens | Engine build |

The 7 recognizable icons from the established world-map mockup (swords, warning, skull, chest, campfire, coin pouch, crown) can be reused. These icons belong **in HUD/map**, never as runes carved into battle Blocks or terrain.

## 3. Node generation constraints
1. Each route starts with one Common Battle. No elite before the player sees its normal teaching mechanic (except optional known high-difficulty mode).
2. Each route contains at least one of **Merchant, Treasure, Rest/Forge**. A generated shop must follow at least one source of coins.
3. The pre-boss row offers a non-combat alternative (Rest/Shop) whenever possible.
4. Elite is optional; minimum one ordinary route through each tier is always available.
5. Node graph must have no dead ends (except completed boss), links never cross in confusing ways, and at each fork the risk icon is visible.
6. Generate with a run seed for reproducibility. No forced elite in the only remaining path.
7. Only present a small number of visible decisions at once on mobile; high-level region choice and inside-land node choice are separate levels of map UI.

### Suggested region-node rhythm
`Common battle -> {Battle | Treasure | Event} -> {Battle | Shop | Elite} -> {Camp | Forge | Battle} -> {Elite | Battle | Treasure} -> Boss`

Example: **Misty Forest path**
- Opening: `Mossbound Sentry + Rootling` (root/warning tutorial)
- Fork A: `Broken Shrine Chest` (steel/wood Block upgrade) vs `Collapsed Arch Battle` (additional coin)
- Fork B: `Old Hermit Merchant` (shop: remove card, shield relic) vs `Elder Treant` (elite with root network)
- Pre-boss: `Mist Camp` (heal) vs `Root Forge` (add +1 connected tile to eligible Block)
- Boss: `Forest Witch` with growing root lines and breakable anchor tiles.

Example: **Hellfire Citadel path**
- Opening: `Ash Walker + Ember Imp` teaches delayed fissure lanes
- Fork: `Blacksmith Shop` (steel/charcoal block tuning) vs `Cracked Vault` (strong item + curse)
- Elite: `Cinder Magistrate` turns safe-looking columns into two-beat warnings
- Camp: `Cooled Bastion` chooses heal or purge burn
- Boss: `Inferno Demon Lord` tests moving through safe tiles and not panic-casting into pits.

## 4. Player build loop and rewards
1. Choose hero + starter kit. Each region path grants 2–4 card/token opportunities; between tiers choose a cross-region reward.
2. **Card reward**: pick 1 of 3 (no compulsory increase; take coins instead to avoid a bloated deck).
3. **Block reward**: gain 1 new connected shape or improve size within the 1–7 cell cap; can swap or merge with a current token subject to 7 cells.
4. **Artifacts** modify *rules* rather than replacing skill cards: e.g. next first Block rotated each battle gains +1 guard; first frozen tile struck breaks into 2 square shards.
5. **Merchant**: card purchase, Block purchase, card removal, heal, reroll; show all costs before selection.
6. **Rest**: heal ~25% max HP OR upgrade one Skill Card OR retune Block rotation/shape (not all three).
7. **Elite**: higher chance of artifacts and rare synergies; avoid guaranteeing only damage cards.
8. **Boss**: shard of Primal Form, one rare artifact choice, an optional replacement to remove a bad card; never force random build destruction.

### Proposed soft currency and cost anchors (tune)
- Common battle 15–25 coins; elite 35–50; treasure 20–40 or item; Warden 60–80.
- Common card 35; uncommon 60; rare 95; Block token 45–90 by shape; remove a card 50 escalating +15; rest service 35; merchant reroll 15.
- Offer one sale or affordable starter option per first shop. Don't gate all healing behind luck.

## 5. Event choice examples (2 each region)
| Land | Event | Choice A | Choice B |
|---|---|---|---|
| Forest | Rootbound Monument | Lose 8% HP to duplicate a wood Block once | Break vines for coins; add `Root` on first cast next battle |
| Forest | Lost Surveyor | Rescue for a free heal | Trade map fragment for a shop discount |
| Dungeon | Sealed Chain Vault | Remove one card, gain temporary `Fragile` | Fight a jailer elite for an artifact |
| Dungeon | Stone Gate | Spend coins to unlock Forge node | Take detour Common Battle for no coin cost |
| Mist Tower | Cracked Bell | Permanently improve freeze resistance | Gain a frost Skill but weaken first guard this act |
| Mist Tower | Frozen Stair | Cross shorter route with temporary slow | Longer safe route with camp |
| Swamp | Mushroom Ring | Take poison to gain poison-synergy card | Harvest coins safely |
| Swamp | Stillwater Mirror | Cleanse one status and heal | Copy a consumable Block token with corruption |
| Sands | Lost Hourglass | Gain a redraw once per encounter, lose coins | Reclaim loot from a sand guardian |
| Sands | Buried Caravan | Purchase random relic cheaply | Escort caravan through an extra battle |
| Citadel | Cold Forge | Upgrade charcoal Block, lose HP | Gain guard artifact without upgrade |
| Citadel | Furnace Toll | Pay coins to skip elite | Face elite for triple Block rewards |
| Sky | Hanging Bridge | Risk extra pit battle for relic | Safer long route to rest |
| Sky | Fallen Bell | Temporarily fix a broken tile in next fight | Gain storm-mark skill with more enemy hazards |
| Summit | Fragment Archive | Remove a duplicate skill for gold shard | Retain duplicate for echo build |
| Summit | Fractured Oath | Heal, give up a Block upgrade | Keep damage build, fight stronger guardian |

## 6. Visual readability
- Map UI uses compact square-cornered dark stone frames; important selected region highlighted in gold, not warning red.
- Node paths are connected by thin straight segmented lines (NOT magic projectiles).
- Battle HUD remains minimal. Top hero green health bar and enemy ivory bar; no big portraits. Red always reserved for attack warning tiles.
- Both grids physically identical in stone tone, even when a land has hazards, except for actual tile states (pits, targeted, red warning, afterglow marks).

## 7. Examples of replayable builds enabled by route decisions
- Knight + Forest + Dungeon: `Guard -> Reflect Stamp -> Shatter` counter-attack build.
- Mage + Citadel + Mist Tower: `Burn -> Freeze -> Thermal Shatter` status-combo build (orange and ice square particles only).
- Rogue + Swamp + Sky: `Mark -> Mobility -> Echo Chain` multi-hit avoidance build.
- Ranger + Sands + Sky: `Trap -> Long Bar -> Timed Burst` board control build.
- Cleric + Forest + Summit: `Shield -> Healing on adjacent cells -> Echo Support` defense/tile reuse build.


<!-- END 02_ROGUELIKE_MAP_AND_ECONOMY.md -->


---

<!-- START 03_ENEMY_ROSTER.md -->

# Tessera — Normal Monsters and Elites by Warden

**Content status: PROPOSED.** All combat happens on the 3×3 or 5×4 active grid according to the battle configuration. The ordinary land encounter may use **3×3**, or **5×4 with pits** at higher difficulty. Boss arenas can grow to **5×4**. `warn` means red diagonal-striped terrain tiles before the square-stamp impact. The roles and timings below are suggested, not set in stone.

## Shared monster implementation standard
- Every enemy has `IDLE -> READABLE WINDUP -> WARNING -> DELIVERY (visual only, no damage) -> STAMP/HIT -> RECOVERY`, with a distinct 2-frame cast gesture. Avoid arbitrary instant hits.
- Their art has no red; **only** warned floor tiles are red. Status-specific impact colors use small square particles, no beams, round splashes, or glowing auras. A traveling visual is allowed only as a square-based delivery (`01` §1A); every enemy skill defines its delivery type, origin, travel, impact and cell mask.
- Enemies occupy exactly one tile, even if the sprite visually sprawls across adjacent rows. Large elites/bosses must have a single logical origin tile unless special multi-tile occupancy is later approved.
- Monster packs have at most one primary high-complexity elite. Prefer 2 normals or 1 elite + 1 weak helper; on 3×3 avoid patterns leaving zero walkable safe cells.
- A move may reveal a `set of 2–5 warned cells`, a row, column, cross or L; test it on the actual grid before casting. Pit tiles are excluded.
- `Counter` is actionable: relocate to safe floor tile, break marked tile, preserve barrier, rotate Block to reach anchor, or interrupt a clearly signaled stance. Counter mechanics must be executable with starting gear.

## Land 1 — Misty Forest Ruins (Forest Witch)
**Teaching theme:** roots grow between marked squares; learn how warnings propagate one tile at a time. Palette: moss grey-green #5E6B55, muted stone; no glowing plants.

### Normal enemies
| Enemy | Role / silhouette | Skills (red warned tiles and square-only impact) | Counterplay |
|---|---|---|---|
| **Rootling** | Small walking knot of roots; quick skirmisher | `Root Prick`: warns one adjacent tile, low damage + Root 0.7s; `Creep`: shifts one safe tile sideways after 1.2s | Don't stand still; hit before second windup |
| **Mossbound Sentry** | Short stone sentry with moss shoulder | `Slab Tap`: warns 2-cell bar; `Brace`: guard on own occupied tile after a visible crouch | Move perpendicular to bar; flank with L Block |
| **Greycap Sporeling** | Dull purple-gray mushroom cluster | `Spore Squares`: warns 3-cell L, mild Poison; `Seedbed`: sets one dark green temporary hazard tile | Avoid clustered corners; clear marked source early |

### Elite enemies
| Elite | Twist / teaching payoff | Skill set | Counterplay / reward identity |
|---|---|---|---|
| **Ancient Root Sentinel** | Long trunk, blocky crown; roots link two distant floor tiles | `Branch Net`: warns a line of 3 and Roots only if the first tile hits; `Bark Shift`: creates one temporary non-pit barrier | Break its amber-tipped root anchor with a 2+ tile Block before follow-up; rewards Guard/Root relic |
| **Mistbriar Matron** | Hooded bark effigy with a dangling dry-vine arm | `Thorn Fork`: one warned tile branches into two orthogonal cells on next beat; `Wreath Guard`: guards at 50% HP | Track first tile then exit branch; shatter anchor, rewards delayed-chain artifact |

Suggested packs: `Rootling + Sentry`, `Rootling + Greycap`, optional `Ancient Root Sentinel + Rootling`. Forest Witch reuses root branching, now with multiple anchors.

## Land 2 — Dark Dungeon (Ogre King)
**Teaching theme:** chains, blocked lanes, pits, heavy windup; learn to reposition deliberately. Cold blue-grey #3E4450.

### Normal enemies
| Enemy | Role / silhouette | Skills | Counterplay |
|---|---|---|---|
| **Chain Rat** | Low crawling rodent dragging square chain-link | `Snag`: 1-cell warning, mild slow; `Chain Skip`: appears at an adjacent valid tile after telling blink | Move diagonally once; avoid putting both feet next to pit |
| **Stonebound Prisoner** | Bent revenant with slab arms | `Cell Slam`: 2-cell vertical line, high delayed damage; `Shale Guard`: one-hit barrier | Move one column; shatter guard with single-hit setup |
| **Gaol Bell** | Suspended iron-cage mimic, logical one-tile enemy | `Clang`: cross-shaped telegraph around itself (clipped to arena), stagger; `Echo Ring`: repeats 1-center tile 1 beat later | Leave center immediately, return only after second beat |

### Elite enemies
| Elite | Twist | Skill set | Counterplay / reward |
|---|---|---|---|
| **Chain Jailer** | Tall plated jailor, chain winding around arm | `Lockstep`: temporarily blocks one adjacent tile before 3-cell bar strike; `Dragback`: pulls actor one safe square if struck | Break the chain anchor or escape along perpendicular row; reward displacement/guard artifacts |
| **Gatebreaker Golem** | Broad torso, one huge stone fist | `Broken Gate`: warns 2×2 then cracks one non-occupied slab into a future pit (after additional warning); `Crush Line`: a slow 3-cell bar | Move off cracking slab in advance; exploit long recovery; reward pit-control relic |

Suggested packs: `Chain Rat + Prisoner`, `Gaol Bell + Chain Rat`, optional `Chain Jailer + Rat`. Ogre King turns chains into 2-stage lane pressure, not unpredictable grab hits.

## Land 3 — Mist Tower / Ice Tower (Frost Lord)
**Teaching theme:** sequential freezes and slowed safe routes. Pale blue-violet #8E95B8, no bright cyan scenery.

### Normal enemies
| Enemy | Role / silhouette | Skills | Counterplay |
|---|---|---|---|
| **Frost Wisp** | One square-faced pale mist spirit | `Cold Point`: 1 tile, slow for 1 cast; `Glide`: shift to neighboring safe tile | Target its destination; avoid stacking slow |
| **Rime Gargoyle** | Icicle-edged slab knight | `Ice Fang`: short 3-cell L, applies Freeze if already slowed; `Stone Skin`: 1 hit armor | Clear Slow first, choose safe corner of L |
| **Snowglass Crow** | Small bird with angular icy wings | `Perch Mark`: marks 2 separated cells; `Drop Frost`: strikes those two after fixed delay | Move after second warning; hit during perched recovery |

### Elite enemies
| Elite | Twist | Skill set | Counterplay / reward |
|---|---|---|---|
| **Broken Ice Knight** | Split blue-silver helm, tall spear-shaped gauntlet | `Mirror Freeze`: telegraphs one column and the adjacent column next beat; `Ice Guard`: freezes after taking a Block hit when armored | Use short Block to bait armor, then move to already resolved column; reward freeze/shatter artifact |
| **Bell of White Mist** | Silent bell golem with floating ice shards (no glow) | `Hush`: delays hero's next Skill Card activation; `Ice Clock`: warns 3 successive single tiles | Observe timing; save quick block/guard for delay window; reward charge/cooldown relic |

Suggested packs: `Wisp + Gargoyle`, `Crow + Wisp`, optional `Broken Ice Knight + Wisp`. Frost Lord extends staggered warning sequences but always preserves an exit.

## Land 4 — Poison Swamp (Toad Matriarch)
**Teaching theme:** poison over time, hazardous tiles, status cleansing. Olive mud #4E4A2A and greyed purple mushrooms.

### Normal enemies
| Enemy | Role / silhouette | Skills | Counterplay |
|---|---|---|---|
| **Muck Leech** | Low pale-gray leech with square jaw | `Siphon`: warns 1 tile, drains tiny amount of HP/guard; `Crawl`: moves to near safe tile | Strike before close approach; don't stack drain |
| **Sporecap Drifter** | Thin mushroom stalk with dull lilac cap | `Spores`: 3-cell L, applies 1 Poison; `Bloom`: leaves a 1-tile hazard for 2 beats | Avoid same hazard repeatedly; safe route outside L |
| **Bog Toadlet** | Tiny squat toad, broad head | `Mud Belly`: 2 adjacent cells, pushes one safe tile; `Croak Windup`: signals next 1-cell poison slap | Stay away from pit/border, avoid push |

### Elite enemies
| Elite | Twist | Skill set | Counterplay / reward |
|---|---|---|---|
| **Mycelium Abbess** | Tall mushroom-veiled swamp matron | `Bloom Web`: connects two poisoned tiles; strike repeats if player stands on either 1 beat later; `Spore Veil`: guard until one hazard destroyed | Destroy one spore anchor with a Block, then dodge followup; reward Poison-proc relic |
| **Bog Resin Harvester** | Hunched collector with square pitch bucket | `Sticky Patch`: changes 2 tiles to slowing mud; `Resin Press`: warns T-shape and adds Fragile | Leave slow mud immediately, avoid T center; reward field-control relic |

Suggested packs: `Leech + Sporecap`, `Toadlet + Leech`, optional `Mycelium Abbess + Leech`. Toad Matriarch tests status management, not unavoidable poison damage.

## Land 5 — Buried Sands (Sand Sphinx)
**Teaching theme:** obscured next warnings (never hidden actual hit tile), delayed impact, shifting obstacles. Warm beige #A8956C, old dull turquoise.

### Normal enemies
| Enemy | Role / silhouette | Skills | Counterplay |
|---|---|---|---|
| **Dune Scarab** | Angular low beetle, dusty carapace | `Sand Nip`: 1-cell mark then hit; `Burrow Shift`: moves to an *announced* adjacent tile | Follow emergence shadow, not motion blur |
| **Buried Sentinel** | Cracked standing statue, flat square face | `Column Stamp`: entire valid column after slow windup; `Sand Guard`: one-use barrier | Move across a column, guard against forced trap |
| **Dustshade** | Hooded sand shade with frayed hem | `False Step`: previews 2 candidate cells, one becomes active red warning in time to dodge; `Sift`: switches its own tile | Only dodge on final red warning; never give fake-red warnings |

### Elite enemies
| Elite | Twist | Skill set | Counterplay / reward |
|---|---|---|---|
| **Lesser Sand Sphinx** | Miniature lion-stone beast with cracked mask | `Riddle Steps`: 3 sequential 1-tile strikes travel left-to-right; `Stone Wing`: guards while standing on marked central tile | Predict sweep, break guard with side approach; reward sequential-hit relic |
| **Hourglass Custodian** | Stone gaoler with sand-filled square vessel | `Time Debt`: marks tile now, repeats the same target 2 beats later; `Delay Snare`: slows card activation | Watch repeating mark, hold dodge/guard; reward time/echo modifier |

Suggested packs: `Scarab + Sentinel`, `Dustshade + Scarab`, optional `Custodian + Dustshade`. Sand Sphinx tests remembering old marked locations.

## Land 6 — Hellfire Citadel (Inferno Demon Lord)
**Teaching theme:** delayed cracks and row/column lane denial; only cracks have yellow-orange color, NEVER red except incoming warnings.

### Normal enemies
| Enemy | Role / silhouette | Skills | Counterplay |
|---|---|---|---|
| **Ash Walker** | Compact gray humanoid with a dim amber chest fissure | `Cinder Press`: warns one tile then deals Burn; `Ash Drift`: hops to pre-marked safe tile | Target landing point, don't stay on heated square |
| **Ember Imp** | Small horned dark sprite, no flame aura | `Crack Line`: warns 2-cell bar, Burn 1; `Coal Leap`: moves one tile if threatened | Side-step perpendicular to line |
| **Furnace Chainling** | Chain link animated around a compact core | `Link Tap`: warns one cell, Fragile; `Chain Heat`: next 2 cells in row warned after first resolves | Watch chain propagation, exit row |

### Elite enemies
| Elite | Twist | Skill set | Counterplay / reward |
|---|---|---|---|
| **Cinder Magistrate** | Crowned charcoal statue with long angular gauntlet | `Sentence`: 3-tile line with delayed second stamp; `Hot Verdict`: tiles previously hit in fight get marked for repeat | Track recent marks; break its square armor during recovery; reward burn/echo relic |
| **Coal Colossus** | Enormous squared shoulders, molten seams, logical 1 tile | `Crucible`: 2×2 warned area, one of those tiles cracks and becomes a pit *after another warning*; `Fist Stamp`: 3-cell T | Respect gap and safe route; punish long recovery; reward terrain-change relic |

Suggested packs: `Ash Walker + Imp`, `Chainling + Walker`, optional `Magistrate + Imp`. Inferno Demon expands line and pit sequencing but retains warnings.

## Land 7 — Sky Isles (Storm Dragon)
**Teaching theme:** temporary bridge safety, pit pathing, staggered storm stamps. Gray-blue #8AA2B8; distant dull yellow thunder is static, never a glowing effect.

### Normal enemies
| Enemy | Role / silhouette | Skills | Counterplay |
|---|---|---|---|
| **Cloud Hatchling** | Small horned drake, muted gray scales | `Sky Stamp`: 2-cell line, shock slow; `Wing Shuffle`: steps to announced neighboring tile | Move perpendicular, anticipate landing |
| **Floating Slabling** | Small levitating chunk of plain stone | `Loose Edge`: warns a tile that becomes unavailable for 1 beat; `Stone Press`: a 1-cell hit after wait | Keep one escape tile, plan beyond edge |
| **Gale Feather** | Birdlike wind sprite with stiff square feathers | `Gust Fork`: 3-cell L, pushes one valid tile; `Perch`: holds position for one beat | Avoid pushes toward pits, use root/guard |

### Elite enemies
| Elite | Twist | Skill set | Counterplay / reward |
|---|---|---|---|
| **Thunderbound Knight** | Broad stone mail, muted brass bolt crest | `Bridge Claim`: warns bridge row, blocks one edge square for 1 beat; `Three-Step Thunder`: 3 distinct single strikes at increasing tempo | Exit claimed line early; reward mobility/charge relic |
| **Bridge Keeper** | Long-limbed stone golem gripping floating slab, logical 1 tile | `Missing Span`: removes 1 announced non-occupied tile for 2 beats; `Bridge Rebuild`: restores one tile and strikes a different warned tile | Pathfind with pit-safe tiles; reward restore/terrain relic |

Suggested packs: `Hatchling + Feather`, `Slabling + Feather`, optional `Bridge Keeper + Hatchling`. Storm Dragon uses a controlled series of known-safe tile changes.

## Land 8 — Lattice Heart Summit (Heart Keeper)
**Teaching theme:** combinations of all previously learned shapes, echoes, and reshaping the board. Indigo #15142A; lattice gold square-only energy, no red creature palette.

### Normal enemies
| Enemy | Role / silhouette | Skills | Counterplay |
|---|---|---|---|
| **Lattice Sentinel** | Ivory square-stone guardian, small segmented crest | `Pattern Copy`: repeats opponent's last 2-cell target shape, red-warned; `Stillguard`: guard after one resolved hit | Change tile after own cast, break guard using two-phase skill |
| **Broken Echo** | Jagged gray tile apparition, chipped shoulders | `Echo Stamp`: 1 tile now + same tile after beat; `Fragment Move`: shifts one safe tile | Remember previous impact, punish echo cooldown |

### Elite enemies
| Elite | Twist | Skill set | Counterplay / reward |
|---|---|---|---|
| **Mirror-Slab Keeper** | Split mirrored mask on pale stone | `Reflection`: next marked pattern reappears rotated 90 degrees (final warning shown), `Fracture`: 2×2 damage | Watch displayed final rotation, never trust only initial shape; reward rotation artifact |
| **Primal Archive Construct** | Rigid robe of square stone slabs, bright gold shard overhead | `Memory Line`: recalls last two warned lines, one after the other; `Seal`: disables repeated card for one beat | Use different Skill Card and rotate off recalled lines; reward artifact + Heart Shard fragment |

Suggested packs: `Sentinel + Echo`, optional `Mirror-Slab Keeper + Echo`. Final Heart Keeper combines telegraphed versions of mastered mechanics, no hidden/unavoidable tricks.

## Suggested encounter budgeting (PROPOSED)
- Common archetype: HP ~`0.55–0.85 × hero baseline`, one primary and one support skill, telegraph ~0.9–1.2s.
- Elite: HP ~`1.5–2.2 × normal at same tier`, one combo mechanic, ~1.2–1.8s on complex attacks. **Do not merely double all damage**.
- Boss: HP ~`4–7 × normal`, 6–7 distinct moves grouped by phases, very clearly signaled phase changes. In two-actor fights scale difficulty primarily by pattern/position, not hit-count spam.
- Difficulty modifies spawn composition, charge tempo and pattern complexity; preserve a dodge path and avoid hidden damage.

## Per-archetype art deliverable for Claude / PixelLab
For each enemy create: `idle_2frames`, `move_2frames`, `windup_2frames`, `hit_2frames`, `defeat_square_dissolve_4frames`, `dark_silhouette`, `square_telegraph_mask`. Hero/game scale small. One frame may show small square particles, but creatures and backgrounds themselves NEVER glow.


<!-- END 03_ENEMY_ROSTER.md -->


---

<!-- START 04_WARDENS_AND_BOSS_SKILLS.md -->

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


<!-- END 04_WARDENS_AND_BOSS_SKILLS.md -->


---

<!-- START 05_PLAYER_CARDS.md -->

# Tessera — 180 Proposed Player Skill Cards

**IMPORTANT:** This is an IDEATION POOL, not a balanced launch deck. All effects, costs, timings and rarities marked PROPOSED. No card replaces the 1–7 edge-connected Block rule. Every card must also define its delivery type, origin, travel animation, impact animation and affected cell mask (`01` §1A, 2026-11-01). The gameplay design separates Skill Card (effect) from Block Token (tile geometry); validate that proposal first.

Use `cards.json` to import into a tool. `proposed_cost` uses an invented 0–3 energy scale that must be tuned, not canon. `Neutral` means all heroes can potentially obtain the card.

## Attack / Damage — 40

| ID | Card | Affinity | Rarity / Energy | Shape | Effect (VN) / Tags |
|---|---|---|---|---|---|
| `atk_001` | First Cut | Knight | common / 1 | `any` | Gây 1 đòn vào các ô được chọn; +25% lên mục tiêu chưa bị đánh trong chuỗi hiện tại. (`slash / starter`) |
| `atk_002` | Second Cut | Knight | common / 1 | `any` | Đòn sau trúng cùng mục tiêu trong vòng 2 beat gây thêm 1 sát thương và không tự tạo echo. (`slash / combo`) |
| `atk_003` | Steel Sweep | Knight | uncommon / 2 | `bar` | Đánh vào dãy ngang đã chọn, thêm sát thương nếu bao phủ đủ 3 ô hợp lệ. (`slash / row`) |
| `atk_004` | Iron Column | Knight | uncommon / 2 | `bar` | Đóng dấu theo cột, phá một tầng Guard. (`stamp / guardbreak`) |
| `atk_005` | Cross Cleave | Knight | rare / 3 | `cross` | Đánh trên các ô dạng chữ thập, mỗi mục tiêu chịu 1 lần sát thương. (`slash / area`) |
| `atk_006` | Lancer's Step | Knight | common / 1 | `any` | Sau khi đổi vị trí một ô hợp lệ, đòn đánh kế tiếp có cộng sát thương. (`move / slash`) |
| `atk_007` | Slab Breaker | Knight | common / 1 | `any` | Đòn phá Guard gây thêm một mảnh vuông choáng ngắn trên ô mục tiêu. (`shatter / guardbreak`) |
| `atk_008` | Hammer Down | Knight | uncommon / 2 | `any` | Charge lâu hơn, gây đòn mạnh lên tối đa 4 ô hợp lệ của Block. (`heavy / stamp`) |
| `atk_009` | Armor Pierce | Knight | uncommon / 2 | `any` | Bỏ qua một phần Guard, nhưng hồi phục lâu hơn. (`pierce / slash`) |
| `atk_010` | Retaliation Stamp | Knight | rare / 3 | `any` | Nếu vừa đỡ được một đòn, dập lại hình Block đã dùng trước đó với nửa sức mạnh. (`counter / stamp`) |
| `atk_011` | Amber Flicker | Mage | common / 1 | `any` | Gây một điểm Burn trên mỗi ô đánh trúng. (`burn / attack`) |
| `atk_012` | Cinder L | Mage | common / 1 | `L3` | Đòn lửa dạng L-3; nạn nhân đang Burn chịu thêm sát thương. (`burn / burst`) |
| `atk_013` | Furnace Bar | Mage | uncommon / 2 | `bar4` | Dập 4 ô hàng thẳng, gây bonus lên ô đã bị Burn ở lượt trước. (`burn / row`) |
| `atk_014` | Coal Split | Mage | uncommon / 2 | `domino` | Dập hai ô liền kề rồi thêm một hit phụ vào ô đã đánh dấu gần đó. (`burn / chain`) |
| `atk_015` | Ash Stamp | Mage | rare / 3 | `any` | Gây sát thương nhẹ và xóa một tầng Burn để tạo hit vuông thêm trên cùng ô. (`burn / convert`) |
| `atk_016` | Thermal Fracture | Mage | common / 1 | `any` | Mục tiêu đang Freeze nhận thêm Shatter khi bị Block này đánh trúng. (`frost / shatter`) |
| `atk_017` | Heat Cycle | Mage | common / 1 | `any` | Đòn đánh ở ô lặp lại có sát thương tăng nhưng đặt thêm một nhịp hồi phục. (`burn / repeat`) |
| `atk_018` | Volcanic Ledge | Mage | uncommon / 2 | `any` | Đòn nổ vuông lan từ ô đầu đến các ô khác của cùng Block theo từng beat. (`chain / burst`) |
| `atk_019` | Flame Quilt | Mage | uncommon / 2 | `any` | Mỗi ô đang Burn liền kề một ô trúng sẽ kích hoạt thêm 1 hit nhẹ; giới hạn 2 lần. (`burn / adjacent`) |
| `atk_020` | Cinder Wake | Mage | rare / 3 | `any` | Để lại một dấu than tạm trên đúng ô vừa trúng, nổ vuông sau 1 beat và báo trước. (`burn / delayed`) |
| `atk_021` | Twin Dagger Mark | Rogue | common / 1 | `any` | Đòn đầu gây Mark và đòn thứ hai trên cùng Block tiêu thụ Mark để tăng damage. (`mark / slash`) |
| `atk_022` | Silent L | Rogue | common / 1 | `L3` | Đánh 3 ô dạng L với ít thời gian charge hơn, sát thương cơ bản thấp. (`speed / L`) |
| `atk_023` | Shadow Stitch | Rogue | uncommon / 2 | `any` | Sau khi né thành công, đòn kế gây thêm hit lên ô mục tiêu đã Mark. (`dodge / mark`) |
| `atk_024` | Rear Tile | Rogue | uncommon / 2 | `any` | Đòn đánh lên mục tiêu ở rìa grid gây bonus; không dịch chuyển vào grid địch. (`edge / slash`) |
| `atk_025` | Quick Cut | Rogue | rare / 3 | `1-2` | Charge gần như tức thời trên tối đa 2 ô, hồi chiêu dài hơn. (`speed / slash`) |
| `atk_026` | Fang Pattern | Rogue | common / 1 | `domino` | Khi hai ô chọn kề nhau đều trúng mục tiêu khác nhau, gây thêm 1 hit lên mỗi mục tiêu. (`multi / combo`) |
| `atk_027` | Sap Strike | Rogue | common / 1 | `any` | Một đòn nhẹ + Fragile ngắn trên ô mục tiêu. (`fragile / slash`) |
| `atk_028` | Echo Knife | Rogue | uncommon / 2 | `any` | Nếu ô mục tiêu đang Mark, lặp một hit 50%; hit phụ không tạo proc. (`echo / mark`) |
| `atk_029` | Trap Reversal | Rogue | uncommon / 2 | `any` | Kích nổ vuông những trap của chính mình nằm trong Block thay vì đặt trap mới. (`trap / burst`) |
| `atk_030` | Cross Ambush | Rogue | rare / 3 | `cross` | Chọn hình chữ thập, sát thương cao lên mục tiêu chưa cảnh giác, hiệu quả thấp khi lặp. (`cross / ambush`) |
| `atk_031` | Briar Bolt | Ranger | common / 1 | `any` | Trên ô chọn, gây damage và dựng dấu Root ngắn; không có đạn bay. (`root / stamp`) |
| `atk_032` | Longshot Bar | Ranger | common / 1 | `bar` | Sát thương tăng theo độ dài Block thẳng liên tục, tối đa 4 ô. (`bar / damage`) |
| `atk_033` | Crosshair Stamp | Ranger | uncommon / 2 | `any` | Đòn dấu tại ô có Mark được cộng sát thương, chỉ một check trên ô có địch. (`mark / precision`) |
| `atk_034` | Wooden Fork | Ranger | uncommon / 2 | `L3` | 3-cell T/L tạo bẫy nhỏ một beat trên ô không có địch. (`trap / area`) |
| `atk_035` | Snare Breaker | Ranger | rare / 3 | `any` | Gây thêm sát thương lên đối tượng đang Root hoặc Slow. (`root / damage`) |
| `atk_036` | Split Trigger | Ranger | common / 1 | `any` | Hai vùng tấn công khác ô sẽ tăng công nếu đều chạm các đơn vị khác nhau. (`multi / chain`) |
| `atk_037` | Rain of Squares | Ranger | common / 1 | `any` | Block dập theo thứ tự từng ô, mỗi ô có hiệu ứng vuông nhỏ, không tạo mưa mũi tên. (`sequential / stamp`) |
| `atk_038` | Lattice Lance | Ranger | uncommon / 2 | `bar4` | Dập thẳng 4 ô và làm vỡ một phần Guard, không bắn tia. (`bar / guardbreak`) |
| `atk_039` | Consecrated Stamp | Cleric | uncommon / 2 | `any` | Gây sát thương ivory nhẹ, tăng Guard cho mình nếu đánh trúng đơn vị đã Mark. (`guard / holy`) |
| `atk_040` | Judgment Cross | Cleric | rare / 3 | `cross` | Đòn chữ thập gây thêm damage trên kẻ đã gây sát thương trong beat trước. (`cross / retaliation`) |

## Block Manipulation — 35

| ID | Card | Affinity | Rarity / Energy | Shape | Effect (VN) / Tags |
|---|---|---|---|---|---|
| `block_001` | Quarter Turn | Neutral | common / 1 | `any` | Xoay một Block 90 độ ngay trước khi chọn ô; giảm một chút thời gian charge. (`rotate / utility`) |
| `block_002` | Half Turn | Neutral | uncommon / 2 | `any` | Xoay 180 độ; lần đặt kế tiếp lên đúng đường cảnh báo được cộng Guard. (`rotate / guard`) |
| `block_003` | Counter Turn | Neutral | uncommon / 2 | `any` | Đảo chiều thứ tự các ô khi một kỹ năng đánh theo chuỗi. (`rotate / sequential`) |
| `block_004` | Lattice Mirror | Neutral | rare / 3 | `any` | Cho phép phản chiếu hình Block theo trục dọc trong lần này; giữ liên thông. (`reflect / shape`) |
| `block_005` | Small Split | Neutral | common / 1 | `4+` | Tách Block 4+ thành hai mảnh liên thông, tổng số ô không đổi. (`split / shape`) |
| `block_006` | Twin Fragments | Neutral | uncommon / 2 | `3+` | Tách Block 3+ để dùng hai lần, mỗi hit giảm sức mạnh; một phần không được rỗng. (`split / echo`) |
| `block_007` | Square Weld | Neutral | uncommon / 2 | `two tokens` | Ghép 2 Token có cạnh chạm nhau; chỉ cho phép kết quả 1–7 ô liên thông. (`merge / shape`) |
| `block_008` | Extra Stud | Neutral | rare / 3 | `1-6` | Thêm 1 ô cạnh bên nếu chưa đủ 7; kỹ năng kế tốn thêm charge. (`grow / shape`) |
| `block_009` | Trim Edge | Neutral | common / 1 | `2+` | Bỏ 1 ô ở đầu mút mà vẫn giữ Block liên thông; đổi lấy giảm thời gian charge. (`shrink / speed`) |
| `block_010` | Cross Forge | Neutral | uncommon / 2 | `size5` | Biến một Block 5 ô thành chữ thập nếu có đủ 5 ô. (`reshape / cross`) |
| `block_011` | U Forge | Neutral | uncommon / 2 | `size5` | Đúc Block 5 ô thành dạng U; giảm tác dụng trên ô giữa không có thật. (`reshape / U`) |
| `block_012` | T Forge | Neutral | rare / 3 | `size4` | Đúc Block 4 ô thành dạng T, giữ nguyên material. (`reshape / T`) |
| `block_013` | S Forge | Neutral | common / 1 | `size4` | Đúc Block 4 ô thành dạng S, giữ nguyên material. (`reshape / S`) |
| `block_014` | L Forge | Neutral | uncommon / 2 | `size3-4` | Đúc Block 3 hoặc 4 ô thành L cùng size. (`reshape / L`) |
| `block_015` | Bar Forge | Neutral | uncommon / 2 | `size2-5` | Biến Block thành thanh liên tục nếu shape vừa kích thước grid. (`reshape / bar`) |
| `block_016` | Stagger Rotate | Neutral | rare / 3 | `any` | Hai lần cast liên tiếp được xoay hình trước khi dập mà không tốn chi phí quay. (`rotate / combo`) |
| `block_017` | Shape Bank | Neutral | common / 1 | `any` | Lưu một shape đã đặt để sử dụng lại một lần, không lưu mục tiêu. (`bank / shape`) |
| `block_018` | Block Reroll | Neutral | uncommon / 2 | `any` | Thay Token kế bằng shape khác cùng size từ danh mục hợp lệ. (`reroll / shape`) |
| `block_019` | Material Swap | Neutral | uncommon / 1 | `any` | Đổi diện mạo material của Token kế; không tự tạo hiệu ứng status. (`material / utility`) |
| `block_020` | Edge Snap | Neutral | rare / 3 | `any` | Tự đưa hình đặt sát biên hợp lệ gần nhất nếu vị trí mong muốn sai. (`placement / assist`) |
| `block_021` | Anchor Lock | Neutral | common / 1 | `any` | Cố định góc xoay của Token trong hai lần dập kế, nhận giảm charge. (`rotation / consistency`) |
| `block_022` | Ghost Preview | Neutral | uncommon / 1 | `any` | Hiện preview ô hợp lệ của hai góc xoay trước khi commit; không gây damage. (`preview / utility`) |
| `block_023` | Twin Offset | Neutral | uncommon / 2 | `any` | Lựa chọn dời Block đúng 1 ô trước khi dập mà không đổi hướng. (`translate / shape`) |
| `block_024` | Odd Stabilizer | Neutral | rare / 1 | `6-7` | Block 6–7 ô tốn ít charge hơn, nhưng không được split ở cast đó. (`odd / utility`) |
| `block_025` | Mosaic Stitch | Neutral | common / 1 | `two fragments` | Nếu đã lưu 2 mảnh liên thông, ráp thành shape mới tối đa 7 ô. (`merge / combo`) |
| `block_026` | Spare Corner | Neutral | uncommon / 2 | `2+` | Cho phép thay một đầu mút bằng một ô ở góc liền kề, vẫn liên thông. (`reshape / flex`) |
| `block_027` | Diagonal Echo | Neutral | uncommon / 2 | `any` | Lặp shape ở vị trí dời ngang một ô sau 1 beat; vị trí mới phải hợp lệ, hit 50%. (`echo / translate`) |
| `block_028` | Shape Exchange | Neutral | rare / 3 | `two tokens` | Đổi chỗ hai Block token trong thanh chờ, không thêm hoặc mất ô. (`economy / shape`) |
| `block_029` | Pocket Square | Neutral | common / 1 | `any` | Dự trữ một ô rời làm Token đơn cho lần sau, không ghép vào shape đang dùng. (`bank / token`) |
| `block_030` | Conserve Form | Neutral | uncommon / 2 | `5+` | Sau khi dập Block 5+ ô, xác suất giữ lại Token tăng (đề xuất 30%). (`resource / shape`) |
| `block_031` | Shape Refund | Neutral | uncommon / 2 | `any` | Nếu kỹ năng không đánh trúng mục tiêu, hoàn lại một phần năng lượng Block. (`economy / miss`) |
| `block_032` | First Tile Priority | Neutral | rare / 3 | `any` | Chọn ô bắt đầu cho kỹ năng chuỗi trong các ô Block đã chạm. (`sequence / control`) |
| `block_033` | Last Tile Focus | Neutral | common / 1 | `any` | Đòn cuối của chuỗi Block có bonus nếu kẻ địch vẫn ở ô đó. (`sequence / damage`) |
| `block_034` | Grid Fit | Neutral | uncommon / 1 | `any` | Cho phép chọn nhanh góc xoay tối ưu để tránh hố; không dịch chuyển đối tượng. (`pit / utility`) |
| `block_035` | Lattice Rewrite | Neutral | uncommon / 2 | `any` | Một lần mỗi trận đổi shape Token bất kỳ thành shape khác cùng kích cỡ. (`reshape / rare`) |

## Status / Control — 30

| ID | Card | Affinity | Rarity / Energy | Shape | Effect (VN) / Tags |
|---|---|---|---|---|---|
| `status_001` | Burn Seed | Mage | common / 1 | `any` | Dập tạo 1 Burn ở mỗi ô đánh trúng, sát thương ban đầu thấp. (`burn / status`) |
| `status_002` | Ash Debt | Mage | common / 1 | `any` | Mỗi 3 stack Burn trên kẻ địch chuyển thành thêm một hit vuông 1 lần rồi giảm 1 stack. (`burn / convert`) |
| `status_003` | Lingering Ember | Mage | uncommon / 2 | `any` | Burn kéo dài thêm 1 beat nhưng sát thương mỗi tick không tăng. (`burn / duration`) |
| `status_004` | Furnace Pressure | Mage | rare / 3 | `any` | Đòn trúng mục tiêu đã Burn thêm 1 Fragile ngắn. (`burn / fragile`) |
| `status_005` | Flare Clock | Mage | common / 1 | `any` | Sau 2 beat, các ô từng trúng Burn của cast này nhận thêm một dấu cảnh báo rồi nổ vuông. (`burn / delayed`) |
| `status_006` | Poison Seed | Rogue | common / 1 | `any` | Gây Poison 1 lên kẻ trúng, chỉ một proc cho mỗi cast. (`poison / status`) |
| `status_007` | Venom Bloom | Rogue | uncommon / 2 | `any` | Đòn trên mục tiêu đủ 3 Poison tạo thêm 1 Poison cho kẻ ở ô kề hợp lệ. (`poison / spread`) |
| `status_008` | Toxic Memory | Rogue | rare / 3 | `any` | Khi Poison tick, đánh dấu ô hiện tại làm vị trí mục tiêu ưu tiên của skill kế. (`poison / mark`) |
| `status_009` | Rotting Edge | Rogue | common / 1 | `any` | Poison giảm 1 tầng Guard trước khi tick damage, tối đa một lần mỗi beat. (`poison / guardbreak`) |
| `status_010` | Venom Harvest | Rogue | common / 1 | `any` | Hạ gục kẻ Poison hồi một ít năng lượng, giới hạn một lần mỗi trận. (`poison / economy`) |
| `status_011` | Frost Mark | Cleric | uncommon / 2 | `any` | Đặt 1 stack Slow trên ô đánh trúng bằng hiệu ứng vuông jade-white. (`frost / slow`) |
| `status_012` | Ice Chain | Cleric | rare / 3 | `any` | Nếu mục tiêu đã Slow, cast này chuyển một Slow thành Freeze ngắn. (`frost / freeze`) |
| `status_013` | Cold Shatter | Cleric | common / 1 | `any` | Gây thêm damage lên đối tượng Freeze rồi gỡ Freeze để chống khóa vô hạn. (`frost / shatter`) |
| `status_014` | Crystal Guard | Cleric | common / 1 | `any` | Khi chịu hit trong lúc đang Guard, kẻ đánh nhận Slow nhẹ, có hồi chiêu. (`frost / guard`) |
| `status_015` | Pale Stillness | Cleric | uncommon / 2 | `any` | Giảm tốc hồi chiêu của kẻ đã trúng băng trong thời gian ngắn. (`frost / debuff`) |
| `status_016` | Root Point | Ranger | rare / 3 | `any` | Đòn đánh áp Root 0.6s, nhưng không thể lặp lên cùng kẻ trong 2 beat. (`root / trap`) |
| `status_017` | Briar Lock | Ranger | common / 1 | `any` | Trap trúng kẻ Root tăng 1 sát thương và giải Root ngay sau hit. (`root / combo`) |
| `status_018` | Mud Step | Ranger | common / 1 | `any` | Các ô chọn trống thành Slow hazard trong 2 beat, không phải pit. (`slow / terrain`) |
| `status_019` | Snare Relay | Ranger | uncommon / 2 | `any` | Nếu một bẫy tự kích nổ, tạo dấu bẫy mới ở ô kề hợp lệ, giới hạn 1. (`trap / chain`) |
| `status_020` | Bark Hold | Ranger | rare / 3 | `any` | Cấp Guard nhỏ cho mình và Root lên kẻ trên ô mục tiêu nếu đánh trúng. (`root / guard`) |
| `status_021` | Mark Target | Rogue | common / 1 | `any` | Dấu Mark tồn tại 2 beat; hit đầu từ skill khác tiêu thụ để nhận bonus. (`mark / status`) |
| `status_022` | Double Mark | Rogue | common / 1 | `any` | Mark trên tối đa hai kẻ khác nhau trong cùng Block; không tăng stack trên một kẻ. (`mark / multi`) |
| `status_023` | Expose Armor | Knight | uncommon / 2 | `any` | Gây Fragile trong một beat nếu hit phá được Guard. (`fragile / guardbreak`) |
| `status_024` | Weak Spot | Rogue | rare / 3 | `any` | Nếu có Mark, đòn kế có thêm hit nhưng không dùng lại Mark để kích Echo. (`mark / combo`) |
| `status_025` | Stagger Stamp | Knight | common / 1 | `any` | Hit trên mục tiêu đang charge kéo dài charge một nhịp nếu có thể interrupt. (`interrupt / control`) |
| `status_026` | Purifying Square | Cleric | common / 1 | `any` | Xóa một stack Poison/Burn của bản thân khi đánh trúng mục tiêu. (`cleanse / heal`) |
| `status_027` | Status Recycle | Cleric | uncommon / 2 | `any` | Khi xóa debuff, nhận 1 Guard nhỏ; giới hạn 1/beat. (`cleanse / guard`) |
| `status_028` | Fragile Echo | Neutral | rare / 3 | `any` | Tấn công lên Fragile cho thêm 1 square shard hit 50%, không tự proc. (`fragile / echo`) |
| `status_029` | Burden Shift | Neutral | common / 1 | `any` | Chuyển một Slow bản thân thành Mark lên một kẻ trên ô đã chọn. (`convert / mark`) |
| `status_030` | Clean Slate | Neutral | common / 1 | `any` | Xóa 1 debuff của bản thân và 1 buff của địch trên cùng nhịp; không gây hit. (`cleanse / purge`) |

## Defense / Mobility — 25

| ID | Card | Affinity | Rarity / Energy | Shape | Effect (VN) / Tags |
|---|---|---|---|---|---|
| `def_001` | Steel Guard | Knight | common / 1 | `self` | Nhận một lượng Guard nhỏ trong 2 beat; giảm tốc chạy 0.3s. (`guard / defense`) |
| `def_002` | Shield Corner | Knight | uncommon / 2 | `self` | Nếu đứng sát góc hợp lệ, Guard tăng một chút nhưng không chặn mọi hướng. (`guard / position`) |
| `def_003` | Bastion Step | Knight | rare / 3 | `self` | Bước sang một ô an toàn trước khi Guard xuất hiện; không qua hố. (`move / guard`) |
| `def_004` | Guard Counter | Knight | common / 1 | `self` | Sau khi đỡ đúng lúc, skill tiếp theo có 1 hit vuông bonus, giới hạn một proc. (`counter / guard`) |
| `def_005` | Brace Line | Knight | uncommon / 2 | `self` | Nếu warning là thanh thẳng, nhận Guard tăng, chỉ dùng mỗi 4 beat. (`guard / row`) |
| `def_006` | Quiet Dodge | Rogue | rare / 3 | `self` | Bước nhanh một ô hợp lệ, không phải teleport, hồi chiêu ngắn. (`dodge / move`) |
| `def_007` | Afterimage Square | Rogue | common / 1 | `self` | Né đúng trước hit đặt dấu Mark ở kẻ gần nhất, không tạo clone nhân vật. (`dodge / mark`) |
| `def_008` | Side Slip | Rogue | uncommon / 2 | `self` | Chỉ dịch ngang một ô hợp lệ; cast tiếp giảm charge. (`move / speed`) |
| `def_009` | Corner Escape | Rogue | rare / 3 | `self` | Nếu đang ở rìa board, có thể chọn dịch theo trục còn lại an toàn. (`move / edge`) |
| `def_010` | Hidden Footing | Rogue | common / 1 | `self` | Trong một nhịp sau né, bẫy tự đặt không mất token. (`dodge / trap`) |
| `def_011` | Rooted Stance | Ranger | uncommon / 2 | `self` | Đổi một bước di chuyển thành Guard để chống knockback, không chặn status. (`guard / anchor`) |
| `def_012` | Forest Cover | Ranger | rare / 3 | `self` | Guard bổ sung khi đứng trên ô không có enemy warning ở cuối charge. (`guard / position`) |
| `def_013` | Bridge Sense | Ranger | common / 1 | `self` | Hiện ô sắp biến thành pit thêm 1 beat; không đổi logic map. (`pit / preview`) |
| `def_014` | Rapid Retreat | Ranger | uncommon / 2 | `self` | Lùi một ô hợp lệ sau khi đặt Block, không đi vào vùng đang warning. (`move / postcast`) |
| `def_015` | Snare Evade | Ranger | rare / 3 | `self` | Khi né thành công tạo một trap tại ô đã rời (nếu hợp lệ). (`move / trap`) |
| `def_016` | Ivory Ward | Cleric | common / 1 | `self` | Cấp Guard dựa trên số ô của Block đang dùng, tối đa 5 ô tính. (`guard / block`) |
| `def_017` | Square Sanctuary | Cleric | uncommon / 2 | `self` | Tạo một ô hỗ trợ trên phe mình giúp giảm một hit tiếp theo. (`guard / terrain`) |
| `def_018` | Healing Lattice | Cleric | rare / 3 | `self` | Hồi HP nhỏ nếu đứng trên một ô an toàn khi cast kết thúc. (`heal / position`) |
| `def_019` | Silver Exchange | Cleric | common / 1 | `self` | Đổi 1 Guard hiện có thành hồi máu tức thời, giới hạn 1/lượt charge. (`heal / guard`) |
| `def_020` | Last Shelter | Cleric | uncommon / 2 | `self` | Khi sắp về 0 HP, tự tạo một Guard bảo hiểm 1 lần mỗi trận. (`emergency / guard`) |
| `def_021` | Ice Footing | Neutral | rare / 3 | `self` | Không bị Slow từ một hazard trong 2 beat, không miễn hoàn toàn Freeze. (`resist / move`) |
| `def_022` | Stone Pivot | Neutral | common / 1 | `self` | Đổi vị trí trong một hàng hoặc cột 1 ô trước khi hiệu ứng Block kết thúc. (`move / shape`) |
| `def_023` | Emergency Tile | Neutral | uncommon / 2 | `self` | Khôi phục một ô pit đã đánh dấu từ trước thành ô tạm 2 beat; không tạo đường không hợp lệ. (`terrain / restore`) |
| `def_024` | Shatter Shield | Neutral | rare / 3 | `self` | Đỡ một hit rồi tạo tối đa 2 mảnh vuông ở ô đang đứng, không gây sát thương địch. (`guard / shatter`) |
| `def_025` | Safe Passage | Neutral | common / 1 | `self` | Sau khi né một warning, lần di chuyển kế bỏ qua một Slow hazard, không đi qua pit. (`dodge / resist`) |

## Combo / Economy — 25

| ID | Card | Affinity | Rarity / Energy | Shape | Effect (VN) / Tags |
|---|---|---|---|---|---|
| `combo_001` | First Spark | Neutral | common / 1 | `any` | Skill đầu mỗi trận được giảm 1 năng lượng nếu có ít nhất 1 token hợp lệ. (`economy / opening`) |
| `combo_002` | Second Wind | Neutral | uncommon / 2 | `any` | Sau 2 cast liên tiếp trúng, hồi 1 năng lượng, có cooldown nội bộ. (`combo / economy`) |
| `combo_003` | Three Stamp Rhythm | Neutral | uncommon / 2 | `any` | Đòn thứ ba liên tiếp thành công gây thêm một hit 50% lên ô cuối, không đẻ proc. (`combo / echo`) |
| `combo_004` | Tile Accountant | Neutral | rare / 3 | `any` | Mỗi ô riêng biệt trúng trong cast cộng 1 điểm charge, giới hạn 4. (`economy / area`) |
| `combo_005` | Empty-Slot Dividend | Neutral | common / 1 | `any` | Nếu có HUD slot Block trống, kỹ năng kế giảm thời gian charge. (`economy / slots`) |
| `combo_006` | Guard Dividend | Neutral | uncommon / 2 | `any` | Mỗi lần Guard hấp thụ hit nhận 1 năng lượng, tối đa một mỗi beat. (`guard / economy`) |
| `combo_007` | Status Bank | Neutral | uncommon / 2 | `any` | Lưu lại một stack debuff đã tiêu thụ cho skill khác, giới hạn 2. (`status / bank`) |
| `combo_008` | Chain Ledger | Neutral | rare / 3 | `any` | Mỗi chain hit trong cast tăng hit cuối 10%, cap 3 stacks. (`chain / scaling`) |
| `combo_009` | Combo Reset | Neutral | common / 1 | `any` | Chủ động xóa combo count để hồi một chút Guard, một lần mỗi 4 beat. (`combo / guard`) |
| `combo_010` | Card Sifter | Neutral | uncommon / 2 | `any` | Đổi một Skill Card chờ thành card khác cùng rarity từ deck, tốn 1 năng lượng. (`draw / economy`) |
| `combo_011` | Block Sifter | Neutral | uncommon / 2 | `any` | Đổi Block Token chờ sang token khác cùng size và shape hợp lệ. (`token / economy`) |
| `combo_012` | Pocket Cache | Neutral | rare / 3 | `any` | Giữ một token đã dùng vào bộ nhớ một lần trong encounter, không giữ toàn hand. (`bank / token`) |
| `combo_013` | Precise Timing | Neutral | common / 1 | `any` | Dập trong 0.2s trước enemy impact được bonus guard ngắn. (`timing / guard`) |
| `combo_014` | Clockwork Charge | Neutral | uncommon / 2 | `any` | Không dùng skill trong 2 beat, skill kế giảm 1 năng lượng; reset khi đánh. (`charge / economy`) |
| `combo_015` | Echo Reserve | Neutral | uncommon / 2 | `any` | Tích 2 điểm combo để cấp một lần repeat 50% không tái kích proc. (`echo / resource`) |
| `combo_016` | Skilled Rotation | Neutral | rare / 3 | `any` | Sau mỗi lần xoay đúng 90 độ thành công, cast tiếp thêm 1 Mark nhẹ. (`rotate / mark`) |
| `combo_017` | Pity Token | Neutral | common / 1 | `any` | Nếu ba token gần nhất không đặt được, lần tiếp theo bảo đảm token 1–3 ô. (`bar / accessibility`) |
| `combo_018` | Merchant's Edge | Neutral | uncommon / 0 | `meta` | Lần mua skill đầu mỗi shop giảm giá nhỏ, không thêm sức mạnh trong trận. (`shop / economy`) |
| `combo_019` | Scrap Recovery | Neutral | uncommon / 0 | `meta` | Gỡ một card yếu ngoài combat nhận coins và đổi lấy one-use token. (`shop / remove`) |
| `combo_020` | Deep Pockets | Neutral | rare / 0 | `meta` | Tăng số token lưu trữ +1 nhưng làm chậm tốc xuất hiện ban đầu. (`slots / economy`) |
| `combo_021` | Rare Momentum | Neutral | common / 1 | `any` | Khi dùng rare card, skill common kế tăng guard/tốc charge thay vì damage thô. (`rarity / combo`) |
| `combo_022` | Fragile Engine | Neutral | uncommon / 2 | `any` | Khi hạ kẻ có Fragile, nhận một token đơn 1 ô. (`fragile / resource`) |
| `combo_023` | Burn Cycle | Mage | uncommon / 2 | `any` | Burn bị tiêu thụ hồi một phần charge; không kích chuỗi vô hạn. (`burn / engine`) |
| `combo_024` | Poison Cycle | Rogue | rare / 3 | `any` | Poison kết liễu mục tiêu hồi một lượt Mark, giới hạn 1 per enemy. (`poison / engine`) |
| `combo_025` | Support Cycle | Cleric | common / 1 | `any` | Mỗi khi hồi máu thật sự, skill gây Guard kế tiếp giảm chi phí; giới hạn 1/beat. (`heal / economy`) |

## Odd / Legendary / Rule-break — 25

| ID | Card | Affinity | Rarity / Energy | Shape | Effect (VN) / Tags |
|---|---|---|---|---|---|
| `odd_001` | Odd Hexa | Neutral | rare / 3 | `size6` | Dùng một shape liên thông bất quy tắc đúng 6 ô, mỗi ô hit 1 lần rồi mất token. (`odd / 6tile`) |
| `odd_002` | Odd Hepta | Neutral | legendary / 3 | `size7` | Dùng shape bất quy tắc đúng 7 ô, tốn charge dài và giới hạn một lần encounter. (`odd / 7tile`) |
| `odd_003` | Magenta Relay | Neutral | rare / 3 | `size6-7` | Từ ô đầu của Odd, các ô kế trong shape resolve theo chuỗi 0.25s/ô. (`odd / chain`) |
| `odd_004` | Odd Mirror | Neutral | legendary / 3 | `size6-7` | Cho phép phản chiếu một shape Odd trước khi đặt; final pattern luôn preview đầy đủ. (`odd / reflect`) |
| `odd_005` | Odd Twin | Neutral | rare / 3 | `size6-7` | Tách một Odd thành hai shape liên thông cùng tổng ô, mỗi fragment cast 50%. (`odd / split`) |
| `odd_006` | Odd Anchor | Neutral | legendary / 3 | `size6-7` | Giữ lại ô trung tâm của Odd thành trap một beat sau khi stamp. (`odd / trap`) |
| `odd_007` | Odd Refund | Neutral | rare / 3 | `size6-7` | Nếu Odd không đánh trúng, lấy lại một nửa năng lượng, không phục hồi token. (`odd / economy`) |
| `odd_008` | Odd Crown | Neutral | legendary / 3 | `size6-7` | Đòn cuối của Odd được thêm Mark, không cộng thêm tile. (`odd / mark`) |
| `odd_009` | Odd Stitch | Neutral | rare / 3 | `size6-7` | Ghép một Block 4 ô với Block 2 hoặc 3 ô nếu liên thông, tối đa 7 ô. (`odd / merge`) |
| `odd_010` | Odd Chime | Neutral | legendary / 3 | `size6-7` | Một Odd vừa stamp trúng kẻ đang Root giải Root và gây hit 50%. (`odd / root`) |
| `odd_011` | Golden Afterstamp | Neutral | rare / 3 | `any` | Trong một lần cast, lặp *cùng* shape sau 1 beat ở 50% damage; không tự proc. (`legendary / echo`) |
| `odd_012` | Primal Fracture | Neutral | legendary / 3 | `any` | Bắn mảnh vuông trên các ô đã đánh trúng, mỗi ô thêm 1 hit nhỏ; không có projectile. (`legendary / shatter`) |
| `odd_013` | Lattice Bridge | Neutral | rare / 3 | `self` | Khôi phục tối đa 2 pit đã đánh dấu trên grid của mình trong 2 beat. (`legendary / terrain`) |
| `odd_014` | Form Crown | Neutral | legendary / 3 | `any` | Giảm 1 charge nếu shape >=5 ô, tăng hồi chiêu nếu <=2 ô. (`legendary / size`) |
| `odd_015` | Echo Labyrinth | Neutral | rare / 3 | `3+` | Trên target thuộc ít nhất 3 ô liên thông, lặp ô đầu và cuối ở 40%, 1 lần. (`legendary / echo`) |
| `odd_016` | Time Fold | Neutral | legendary / 3 | `any` | Đổi thứ tự resolve của hai skill kế tiếp, không hủy warning enemy. (`legendary / time`) |
| `odd_017` | Broken Symmetry | Neutral | rare / 3 | `any` | Được xoay và phản chiếu ngay trước cast, nếu chọn được shape hợp lệ. (`legendary / shape`) |
| `odd_018` | Status Loom | Neutral | legendary / 3 | `any` | Gộp một Burn và một Poison thành Fragile cộng một hit nhỏ, tiêu thụ cả hai. (`legendary / status`) |
| `odd_019` | Ivory Reversal | Neutral | rare / 3 | `any` | Khi Guard chặn hit, tạo mục tiêu phản công trên 1 ô kẻ tấn công đang đứng. (`legendary / counter`) |
| `odd_020` | Chrysalis Block | Neutral | legendary / 3 | `3-5` | Token 3–5 ô thay đổi shape cùng size sau lần đầu miss, chỉ một lần. (`legendary / reshape`) |
| `odd_021` | Royal Split | Neutral | rare / 3 | `size7` | Một token 7 ô chia thành 3 mảnh liên thông (min 1 ô), cast mỗi mảnh ở 30%. (`legendary / split`) |
| `odd_022` | Primal Memory | Neutral | legendary / 3 | `any` | Ghi nhớ một shape đã dùng; lần sau dùng lại nếu đang có token cùng size. (`legendary / bank`) |
| `odd_023` | Silent Cascade | Neutral | rare / 3 | `any` | Đòn giết một mục tiêu có Mark lặp 1 ô stamp lên kẻ tiếp theo nếu hợp lệ. (`legendary / chain`) |
| `odd_024` | Heart Temper | Neutral | legendary / 3 | `self` | Trong trận boss, lần đầu dưới 30% HP nhận một lớp Guard và giảm 1 Slow. (`legendary / survival`) |
| `odd_025` | Last Pattern | Neutral | rare / 3 | `any` | Sau 4 shape khác nhau được dùng, shape thứ năm tạo thêm 1 hit vuông 50% trên ô cuối. (`legendary / buildaround`) |

## Quality checks before using in game
- Keep each cast fully on valid enemy-grid cells; self/defense affects self-grid. Never allow placement into pits by default.
- Any delayed attack needs a tile-specific visible warning before the hit; no instant hidden damage.
- Resource/echo/status synergies require trigger cap and proc attribution to avoid infinite loops.
- For all 180 cards, Claude should create individual descriptions, VFX frames (square effects only), upgrade variants and balance tests before production.
- `shape_rule` is a type constraint, not a requirement to draw physical BLOCK objects enlarged on battlefield.
- UI may show card titles and effects; in concept art usually no text.


<!-- END 05_PLAYER_CARDS.md -->


---

<!-- START 06_DATA_MODEL_AND_IMPLEMENTATION.md -->

# Tessera — Data Model, Generation, AI and Validation for Claude

**Do not conflate proposed design with code already shipped.** The code snippets below define a possible language-agnostic domain model (TypeScript pseudotypes) translatable to Godot 4/GDScript, Flutter+Dart or any engine. The existing game engine has **not** been chosen by these docs.

## 1. Combat domain model
```ts
type Tile = { x: number; y: number }; // zero-based, left-to-right, back-to-front
type GridSide = 'hero' | 'enemy';
type TileState = 'solid' | 'pit' | 'temporary_blocked';
type Rarity = 'common' | 'uncommon' | 'rare' | 'legendary';
type Hero = 'knight' | 'mage' | 'rogue' | 'ranger' | 'cleric';

type BlockShape = {
  id: string;
  offsets: Tile[]; // unique connected cells via 4-neighbor adjacency, size 1..7
  material: 'steel'|'charcoal'|'ice'|'wood'|'glass'|'ivory'|'odd';
  rotationQuarterTurns: 0|1|2|3;
  canReflect?: boolean; // only if explicitly granted by card
};

type Status = {
  type: 'burn'|'poison'|'slow'|'freeze'|'root'|'mark'|'guard'|'fragile';
  stacks: number; expiresAtBeat?: number;
};

type DeliveryType = 'CASTER_TO_TARGET'|'SKY_TO_TARGET'|'GROUND_PROPAGATION'|'DIRECT_MANIFESTATION'|'SEQUENTIAL_CHAIN';

type Delivery = {               // 01 §1A, LOCKED 2026-11-01
  type: DeliveryType;
  origin: 'caster'|'sky'|'origin_cell'|'target_cells'|'first_cell';
  travelAnim: string;          // square-based visual id; never the gameplay Block object
  impactAnim: string;          // slash, burst, shatter, burn, freeze, poison, knockback, guard...
  cellMask: 'block_shape';     // only these cells are affected; the path deals no damage
  chainOrder?: 'nearest_first'|'row_major'|'authored'; // SEQUENTIAL_CHAIN only
};

type Ability = {
  id: string; name: string; tags: string[];
  owner: 'hero'|'normal'|'elite'|'boss';
  targetSide: GridSide | 'self';
  shapeRule: string; // e.g. any, L3, bar4, cross, line3, T4, dynamic
  windupBeats: number;
  resolvedEffects: Effect[]; // data-driven, no direct rendering logic
  warningMask: 'targeted_cells';
  delivery: Delivery;          // required for every player, enemy and boss skill
  cooldownBeats?: number;
  costs?: { energy?: number; token?: boolean };
  constraints?: { minSafeTiles?: number; needsValidPath?: boolean };
};

type Effect =
 | { kind:'damage'; amount:number; on:'each_target_actor_once' }
 | { kind:'apply_status'; status:Status }
 | { kind:'shield'; amount:number }
 | { kind:'push'; cells:number; rejectPit:true }
 | { kind:'terrain'; state:TileState; durationBeats:number; onlyEmpty:true }
 | { kind:'repeat'; delayBeats:number; damageMultiplier:number; noProcRecursion:true }
 | { kind:'gain_energy'; amount:number; capPerBeat:number };

type Enemy = {
  id: string; landId: string; tier: 'normal'|'elite'|'boss';
  logicalOccupiedTiles: 1; hp: number; skills: string[];
  visualSilhouette: string; counterplay: string;
};

type RoomNode = {
  id:string; type:'battle'|'elite'|'treasure'|'merchant'|'camp'|'event'|'forge'|'boss';
  tier:number; row:number; lane:number; linksTo:string[];
  encounterId?:string; rewards?:string[];
};
```

## 2. Grid and Block invariants (tests Claude must add)
- Grid X increases left-to-right and Y back-to-front; all slab rectangles identical; move, cast and effects reference **logical cells**, never image pixel positions.
- `assert 1 <= shape.length <= 7`, all unique offsets, orthogonally connected; rotation applies `(x,y) -> (-y,x)` then normalize min X/min Y to 0.
- `place(shape,anchor)` returns all cells in bounds, solid and not temporarily blocked; **no clipping** for player cards unless explicitly authored. Shape can be previewed in invalid state but not committed.
- Monster warning should be computed from resolved geometry; for a special skill that allows clipped masks, do so *at design time and show exact final cells*.
- Tile row/column counts are independent of sprite scaling; character's feet occupy 1 cell. A sprite may overlap row behind without changing logic occupancy.
- Rendering order: background -> back slabs -> characters on each row -> floor-target outlines/warning overlays that must be visible above character parts -> HUD. This order may need multiple overlay passes to keep warnings on top.
- Valid boss attack: at least 1 escape tile reachable for a movement-evadable move within windup time OR an accessible defense guaranteed. For team encounters, evaluate union of concurrent warnings.
- Terrain collapse: never convert currently occupied cell into pit without explicit fall-and-return design. In prototype restrict to empty cells, warn in advance, restore after N beats.

## 3. Data-driven attack lifecycle
```text
ENEMY_IDLE
  -> choosePattern(seed, heroTile, currentPhase, arenaSafeCells)
  -> validate(counterplayReachability)
  -> WINDUP (show animation, no hit)
  -> WARNING (same immutable set of tile coordinates as hit)
  -> DELIVERY (visual travel from the skill's origin; no damage on the path)
  -> RESOLVE (impact effect, damage/status on warned cells only)
  -> OPTIONAL FOLLOWUP (new warning before any secondary hit)
  -> RECOVERY -> IDLE
```

Patterns need explicit `anchor`, `rotation`, `offsets`, `targets`, `warningStart`, `resolutionBeat`. Snapshot at warning time. If a hazard invalidates cells after warning, cancel or visibly revise warning before hitting; never move target invisibly.

## 4. Suggested roguelike map generation algorithm
1. Seed RNG; choose one of two available **named regions/routes** for each tier based on prior user choice.
2. For selected region build 5 rows of 2–3 candidate nodes; start with guaranteed `battle`, end in `boss`; node types and edges generated under constraints.
3. Guarantee one source of coins before first `merchant`, and one `camp` or `forge` opportunity before boss. Optional elite lane with preview icon.
4. Link each node to one or two reachable next-row candidates; verify graph is acyclic, every node can reach the boss, no orphan nodes.
5. Generate encounters from land's enemy roster and tag difficulty; elite appearance after at least 1 normal teaching skill.
6. Final validate difficulty budget and note player route history; expose deterministic run seed for save/replay debugging.

Proposed node-type weight for nonfixed rows: `common 45%`, `elite 12%`, `treasure 14%`, `merchant 10%`, `camp 10%`, `event 6%`, `forge 3%`; **not independent probabilities across all rows**. Apply constraints first and sample only valid candidate types.

## 5. Proposed encounter budgets
`encounterThreat = sum(unitDanger) + boardHazardDanger + synergyDanger`.
- A single normal = 1.0; a second normal = +0.7; one elite = 1.9; elite + helper normal = 2.4; two elites **not supported by default**.
- No elite in first room; at least one safe route per region.
- Limit active red warned terrain cells per beat to ~45–60% of usable hero floor in ordinary encounters; exceptions must give accessible guard or staged warning with a known escape.
- Track per-enemy primary attack frequency; disallow excessive Root+Freeze overlap and two unavoidable pushes toward pits.

## 6. Combat AI pseudocode
```ts
function chooseEnemyMove(enemy, state, seededRng) {
  const candidates = enemy.skills
    .filter(id => isSkillAvailable(id, state))
    .map(id => ({id, plan: buildPlan(id, state)}))
    .filter(x => x.plan.valid && canHeroRespond(x.plan, state));
  if (!candidates.length) return {type:'wait'};
  return weightedChoose(candidates, seededRng, {
    punishStandingStill: 1.2,
    avoidRepeatLastSkill: 0.45,
    favorPhaseMechanic: 1.25,
    neverHideFinalWarning: true
  });
}
```
All selection weights need actual playtest tuning, never used to fabricate impossible unavoidable attacks.

## 7. Event hook discipline (prevent combo exploits)
Event envelope: `{actionId, parentActionId?, sourceCardId, owner, targetCells, flags}`. Rule `noProcRecursion` on echo/chain child attacks. Resource gains capped per beat and by source. If a card makes three separate tile hits, statuses should specify per tile, per target, or per cast explicitly.

## 8. Skill/art production schema
Each card/monster skill should have:
```yaml
id: forest_root_nail
land: misty_forest
owner: boss
shape: [{x: 0, y: 0}]
side: hero
telegraph_color: '#E5293B' # only on attacked floor tiles
telegraph_style: red_diagonal_2px_outline
cast_pose: boss_empty_hands_one_back_one_forward
windup_beats: 1.0
delivery: GROUND_PROPAGATION      # 01 §1A; not every skill is SKY_TO_TARGET
origin: caster_feet
travel_visual: root_squares_along_slabs
cell_mask: shape
impact_visual: square_shards_ivory
on_hit: [{type: damage, amount: 8}, {type: root, duration_beats: 1}]
recovery_beats: 0.8
counterplay: move_to_adjacent_unwarned_solid_cell
```

## 9. Test cases / acceptance criteria
- All 180 player cards have stable unique IDs, group, affinity, shape rule, rarity, effect, and tags.
- 8 lands have enemies with 23 normal and 16 elite archetypes; 8 bosses each have skills + phase behavior.
- All boss skills allow a valid response on each supported arena configuration, including 3×3 and 5×4 pit maps or explicitly restrict their arena size.
- No card spawns >7 connected cells, no skill targets an unannounced pit, no negative currency, no infinite proc loop.
- A generated run must produce playable paths in 10k seeded generation tests, guarantee shop access and rest/forge opportunity under the declared policy.
- Each attack VFX resolves into **tile squares**; no beam or circle VFX. Traveling visuals are square-based, never the gameplay Block, and never apply damage or status outside the cell mask. Every skill declares delivery type, origin, travel, impact and cell mask. Red used only for hostile warning cells.
- Screenshot tests: equal slab rectangle geometry, exact palette families, outlines on characters only, separate grids and fully visible warning overlays.

## 10. Balancing checklist before production
- Telegraph time vs input latency on actual Android devices (touch swipe, move responsiveness).
- Player starting damage vs earliest common/elite attack and survivability.
- Block-bar weighting: ensure any acquired skill can receive compatible shapes often enough, or provide a deterministic fallback token.
- Reward path: coin economy, merchant access, deck bloat and removal, dead card prevention.
- Advanced boss board shrink should be a **tactical puzzle**, never a no-solution death check.
- Add internal balance analytics: card pick-rate, win-rate by hero/build, elite path choose-rate, boss deaths by skill/pit, per-room duration, frequency of unavoidable situations.


<!-- END 06_DATA_MODEL_AND_IMPLEMENTATION.md -->


---

<!-- START 07_CLAUDE_TASKS.md -->

# Copy-and-paste tasks for Claude

## A. Initial architecture audit
> Read all files in this directory in README order. Separate LOCKED canon from PROPOSED mechanics. Summarize contradictions or unanswered high-impact decisions (especially Skill Card vs Block Token, active battle timing and 5 tiers/2 choices). Do not implement anything yet. Produce a 1-page architecture decision record with safe defaults and risks.

## B. Vertical slice / playable demo
> Implement one playable vertical slice of Tessera: Misty Forest region, deterministic 3×3 two-sided grids, Knight + Mage starter skills, 3 normal monsters + 2 elite monsters + Forest Witch Warden, 5-node branching map with Common Battle/Elite/Chest/Merchant/Camp/Boss, and 20 representative player cards from `05_PLAYER_CARDS.md`. Start with pure unit-testable grid/shape math, then telegraphed combat, then presentation. Keep canon art rules. Produce unit tests and debug seed logs. Do not silently implement remaining 160 cards.

## C. Enemy expansion by land
> Add one region at a time from `03_ENEMY_ROSTER.md` and its Warden from `04_WARDENS_AND_BOSS_SKILLS.md`. For each enemy write data (HP, cooldown, warning cells, behavior state machine), telegraph animation sheet spec and one counterplay test. Add at least one generated encounter involving each new normal + elite. Check no undodgeable warning patterns.

## D. Full card-system spec
> Read `cards.json` (180 proposed ideas) and derive a data-driven schema. Find duplicates, vague effects and contradictions; rank a subset of 60 MVP candidates for five heroes and shared deck. Implement trigger caps, Block/token compatibility, hero-affinity, upgrade transformations and a weighting algorithm for bar drops. Produce a balance workbook only if requested, otherwise JSON plus markdown implementation notes.

## E. Map generator
> Use `02_ROGUELIKE_MAP_AND_ECONOMY.md` to implement five-tier route selection and seeded 5-row DAG node generation. Each chosen land has 3 normal + 2 elite archetypes (Summit 2 normal + 2 elite), its named Warden, merchant, chest, camp, event, and optional elite. Validate every generated route offers a path to boss, one early coin source, no forced elite, a late camp or forge and viable deck growth. Test at least 10k seeds. Do not invent additional canon lands without approval.

## F. Asset and UI handoff
> Turn each monster, Warden and card into a PixelLab-ready asset specification: small true-size frame dimensions, 6x nearest-neighbor inspection scale, palette, silhouette, two-frame readable windup, square-only impact frames, warning mask coordinates, and layered background. Distinguish concept illustration from production sprite sheet. Avoid decorative runes/text and glowing environment.

## G. Skill delivery pass
> For every player card, enemy skill and boss skill, fill in delivery type, origin, travel animation, impact animation and affected cell mask per `01_CANON_AND_COMBAT_SYSTEM.md` §1A. Do not default to `SKY_TO_TARGET`. Add a test that a delivery path never applies damage or status outside the cell mask, and that no skill throws the gameplay Block object.

## What to decide with designer before coding
1. Is the card bar a stream of **Skill Cards**, **Block Tokens**, or a combined sequence?
2. Are Skill Cards consumable, cooldown-based, or permanently equipped actions during a battle?
3. How many simultaneous player Block/Skill slots are allowed on a 640×360 phone screen?
4. Is a run expected to clear all five tiers, or can players checkpoint/shorten to three tiers?
5. Should all 5 heroes share an 180-card pool or use 100 shared + 80 hero-specific as a starting ratio?
6. Is the canonical Warden boss arena 3×3, 5×4, or variable by land?
7. Does a defeated boss grant a new Block material, artifact, or a permanent meta-progression option?

These are **open design questions**, not blockers for the initial prototype; choose temporary documented defaults if the user wants coding immediately.


<!-- END 07_CLAUDE_TASKS.md -->
