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
