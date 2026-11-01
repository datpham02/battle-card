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
