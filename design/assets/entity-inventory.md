# Visual Entity & Screen Inventory

> Generated: 2026-10-29
> Sources: design/art/art-bible.md (all 9 sections), design/world-context.md, design/glossary.md, design/ux/hud.md, assets/data/chapters.json and assets/i18n/strings.csv (names). No design/gdd/ (rigor minimal).
> Slice column: `1` = Vertical slice 1 (Swordsman, Goblin Scout, Misty Forest set, steel block, Slash VFX, Wall + Thorns, hit / telegraph / cast-tile overlays, basic UI frames and icons). Art-bible rule: monster species share one body and variants are exported by script (Section 8.4), so the real drawing count is ~22 bodies for 60 monsters.

## Entities

| # | Name | Type | Description | Source | Status | Slice |
|---|------|------|-------------|--------|--------|-------|
| 1 | Swordsman (Kiếm sĩ) | Character | steel plate, greatsword across the back; 32x48 frame, ~40 px; steel blocks; clips: idle, step, cast_gesture, hit, down, victory, defeat, awaken | art-bible §5 | Needed | 1 |
| 2 | Mage (Pháp sư) | Character | tall thin triangle silhouette, dark charcoal-brown robe with amber trim, pointed bent hat; ember blocks; clips: idle, step, cast_gesture, hit, down, victory, defeat, awaken | art-bible §5 | Needed |  |
| 3 | Assassin (Sát thủ) | Character | low crouching diamond silhouette, hood, two daggers; ~34-36 px; jade-white ice blocks; clips: idle, step, cast_gesture, hit, down, victory, defeat, awaken | art-bible §5 | Needed |  |
| 4 | Hunter (Thợ săn) | Character | T-shaped silhouette, crossbow across shoulders, wide-brimmed hat; wood-and-rope blocks; clips: idle, step, cast_gesture, hit, down, victory, defeat, awaken | art-bible §5 | Needed |  |
| 5 | Priest (Giáo sĩ) | Character | bell-shaped robe, veil, staff topped by a square within a square; stained-glass blocks; clips: idle, step, cast_gesture, hit, down, victory, defeat, awaken | art-bible §5 | Needed |  |
| 6 | Swordsman portrait | Character | 64x80 character-select portrait, one expression, same palette and 1 px ink outline | art-bible §5.5 (LOD) | Needed |  |
| 7 | Mage portrait | Character | 64x80 character-select portrait, one expression, same palette and 1 px ink outline | art-bible §5.5 (LOD) | Needed |  |
| 8 | Assassin portrait | Character | 64x80 character-select portrait, one expression, same palette and 1 px ink outline | art-bible §5.5 (LOD) | Needed |  |
| 9 | Hunter portrait | Character | 64x80 character-select portrait, one expression, same palette and 1 px ink outline | art-bible §5.5 (LOD) | Needed |  |
| 10 | Priest portrait | Character | 64x80 character-select portrait, one expression, same palette and 1 px ink outline | art-bible §5.5 (LOD) | Needed |  |
| 11 | Goblin Scout | Enemy | Misty Forest; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed | 1 |
| 12 | Grey Wolf | Enemy | Misty Forest; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 13 | Goblin Chief | Enemy | Misty Forest; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 14 | Goblin Warrior | Enemy | Misty Forest; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 15 | Dire Wolf | Enemy | Misty Forest; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 16 | Goblin Shaman | Enemy | Misty Forest; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 17 | Alpha Wolf | Enemy | Misty Forest; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 18 | Goblin Archer | Enemy | Misty Forest; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 19 | Goblin Brute | Enemy | Misty Forest; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 20 | Goblin Warlock | Enemy | Misty Forest; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 21 | Forest Witch | Enemy (Warden) | Misty Forest; 48x64 frame, body <= 52 px, Primal Shard floats above (code); clips: idle, step, windup, strike, hit, down | art-bible §5.2 | Needed |  |
| 22 | Skeleton Guard | Enemy | The Dungeon; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 23 | Zombie | Enemy | The Dungeon; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 24 | Crypt Bat Swarm | Enemy | The Dungeon; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 25 | Dungeon Slime | Enemy | The Dungeon; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 26 | Cultist | Enemy | The Dungeon; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 27 | Rat King's Guard | Enemy | The Dungeon; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 28 | Ghost | Enemy | The Dungeon; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 29 | The Reacter | Enemy | The Dungeon; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 30 | The Jailer | Enemy | The Dungeon; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 31 | Giant Ogre | Enemy (Warden) | The Dungeon; 48x64 frame, body <= 52 px, Primal Shard floats above (code); clips: idle, step, windup, strike, hit, down | art-bible §5.2 | Needed |  |
| 32 | Frost Sprite | Enemy | The Mist Tower; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 33 | Wisp | Enemy | The Mist Tower; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 34 | Stone Sentry | Enemy | The Mist Tower; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 35 | Snow Wolf | Enemy | The Mist Tower; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 36 | Rime Archer | Enemy | The Mist Tower; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 37 | Ice Golem | Enemy | The Mist Tower; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 38 | Greater Ghost | Enemy | The Mist Tower; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 39 | Fuse Cannon | Enemy | The Mist Tower; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 40 | Frost Mage | Enemy | The Mist Tower; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 41 | Lord of the Mist | Enemy (Warden) | The Mist Tower; 48x64 frame, body <= 52 px, Primal Shard floats above (code); clips: idle, step, windup, strike, hit, down | art-bible §5.2 | Needed |  |
| 42 | Heart Keeper | Enemy (final boss) | The Lattice Heart; 48x64 frame, body <= 52 px, Primal Shard floats above (code); clips: idle, step, windup, strike, hit, down, phase-2 change | art-bible §5.2 | Needed |  |
| 43 | Bog Rat | Enemy | The Poison Swamp; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 44 | Mire Slug | Enemy | The Poison Swamp; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 45 | Swamp Lizard | Enemy | The Poison Swamp; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 46 | Marsh Toad | Enemy | The Poison Swamp; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 47 | Reed Witch | Enemy | The Poison Swamp; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 48 | Bog Hound | Enemy | The Poison Swamp; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 49 | Spore Cap | Enemy | The Poison Swamp; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 50 | Leap Frog | Enemy | The Poison Swamp; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 51 | Toad Matriarch | Enemy (Warden) | The Poison Swamp; 48x64 frame, body <= 52 px, Primal Shard floats above (code); clips: idle, step, windup, strike, hit, down | art-bible §5.2 | Needed |  |
| 52 | Dune Jackal | Enemy | The Buried Sands; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 53 | Sand Beetle | Enemy | The Buried Sands; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 54 | Dust Nomad | Enemy | The Buried Sands; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 55 | Mirage Sprite | Enemy | The Buried Sands; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 56 | Scarab Guard | Enemy | The Buried Sands; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 57 | Sun Archer | Enemy | The Buried Sands; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 58 | Sand Burrower | Enemy | The Buried Sands; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 59 | Riposte Scorpion | Enemy | The Buried Sands; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 60 | Sand Sphinx | Enemy (Warden) | The Buried Sands; 48x64 frame, body <= 52 px, Primal Shard floats above (code); clips: idle, step, windup, strike, hit, down | art-bible §5.2 | Needed |  |
| 61 | Imp | Enemy | The Hellfire Citadel; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 62 | Ember Hound | Enemy | The Hellfire Citadel; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 63 | Ash Golem | Enemy | The Hellfire Citadel; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 64 | Flame Cultist | Enemy | The Hellfire Citadel; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 65 | Magma Slug | Enemy | The Hellfire Citadel; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 66 | Hell Knight | Enemy | The Hellfire Citadel; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 67 | Fire Eater | Enemy | The Hellfire Citadel; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 68 | Ash Phoenix | Enemy | The Hellfire Citadel; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 69 | Inferno Lord | Enemy (Warden) | The Hellfire Citadel; 48x64 frame, body <= 52 px, Primal Shard floats above (code); clips: idle, step, windup, strike, hit, down | art-bible §5.2 | Needed |  |
| 70 | Cloud Sprite | Enemy | The Sky Isles; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 71 | Harpy | Enemy | The Sky Isles; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 72 | Wind Monk | Enemy | The Sky Isles; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 73 | Storm Eagle | Enemy | The Sky Isles; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 74 | Sky Sentinel | Enemy | The Sky Isles; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 75 | Thunder Shaman | Enemy | The Sky Isles; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 76 | Gale Bird | Enemy | The Sky Isles; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 77 | Cloud Veil | Enemy | The Sky Isles; 32x48 frame, <= 34 px (elite <= 40); shared body + palette/accessory variant; clips: idle, step, windup, strike, hit, down | art-bible §5.2, §5.6 | Needed |  |
| 78 | Storm Dragon | Enemy (Warden) | The Sky Isles; 48x64 frame, body <= 52 px, Primal Shard floats above (code); clips: idle, step, windup, strike, hit, down | art-bible §5.2 | Needed |  |
| 79 | Slab set: Misty Forest | Environment | 9-slice 16x16 slab + 6 stamps (cracks, region cover); front lip 2-3 px; no outline | art-bible §6.3 | Needed | 1 |
| 80 | Backdrop: Misty Forest | Environment | 800x360 side-view, <= 3 layers (sky/far/near), horizon 9-13 %; low saturation; no text | art-bible §6.4 | Needed | 1 |
| 81 | Slab set: The Dungeon | Environment | 9-slice 16x16 slab + 6 stamps (cracks, region cover); front lip 2-3 px; no outline | art-bible §6.3 | Needed |  |
| 82 | Backdrop: The Dungeon | Environment | 800x360 side-view, <= 3 layers (sky/far/near), horizon 9-13 %; low saturation; no text | art-bible §6.4 | Needed |  |
| 83 | Slab set: The Mist Tower | Environment | 9-slice 16x16 slab + 6 stamps (cracks, region cover); front lip 2-3 px; no outline | art-bible §6.3 | Needed |  |
| 84 | Backdrop: The Mist Tower | Environment | 800x360 side-view, <= 3 layers (sky/far/near), horizon 9-13 %; low saturation; no text | art-bible §6.4 | Needed |  |
| 85 | Slab set: The Poison Swamp | Environment | 9-slice 16x16 slab + 6 stamps (cracks, region cover); front lip 2-3 px; no outline | art-bible §6.3 | Needed |  |
| 86 | Backdrop: The Poison Swamp | Environment | 800x360 side-view, <= 3 layers (sky/far/near), horizon 9-13 %; low saturation; no text | art-bible §6.4 | Needed |  |
| 87 | Slab set: The Buried Sands | Environment | 9-slice 16x16 slab + 6 stamps (cracks, region cover); front lip 2-3 px; no outline | art-bible §6.3 | Needed |  |
| 88 | Backdrop: The Buried Sands | Environment | 800x360 side-view, <= 3 layers (sky/far/near), horizon 9-13 %; low saturation; no text | art-bible §6.4 | Needed |  |
| 89 | Slab set: The Hellfire Citadel | Environment | 9-slice 16x16 slab + 6 stamps (cracks, region cover); front lip 2-3 px; no outline | art-bible §6.3 | Needed |  |
| 90 | Backdrop: The Hellfire Citadel | Environment | 800x360 side-view, <= 3 layers (sky/far/near), horizon 9-13 %; low saturation; no text | art-bible §6.4 | Needed |  |
| 91 | Slab set: The Sky Isles | Environment | 9-slice 16x16 slab + 6 stamps (cracks, region cover); front lip 2-3 px; no outline | art-bible §6.3 | Needed |  |
| 92 | Backdrop: The Sky Isles | Environment | 800x360 side-view, <= 3 layers (sky/far/near), horizon 9-13 %; low saturation; no text | art-bible §6.4 | Needed |  |
| 93 | Slab set: The Lattice Heart | Environment | 9-slice 16x16 slab + 6 stamps (cracks, region cover); front lip 2-3 px; no outline | art-bible §6.3 | Needed |  |
| 94 | Backdrop: The Lattice Heart | Environment | 800x360 side-view, <= 3 layers (sky/far/near), horizon 9-13 %; low saturation; no text | art-bible §6.4 | Needed |  |
| 95 | Wall | Environment | 40x40, ~30 px tall, solid, rectangular, diagonal hatch; per region variants | art-bible §3, §6.3 | Needed | 1 |
| 96 | Thorns patch | Environment | 40x12, <= 6 px, sparse triangular spikes; per region variants | art-bible §3, §6.3 | Needed | 1 |
| 97 | Hole / pit floor | Environment | dark bottom per region + 3 px cliff lip | art-bible §3, §6.3 | Needed |  |
| 98 | Floating island underside | Environment | tapered rock foot (Sky Isles) | art-bible §3, §6.3 | Needed |  |
| 99 | Burning cell | Environment | darker slab + stepped flame + horizontal stripes | art-bible §3, §6.3 | Needed |  |
| 100 | Swamp cell | Environment | sunk 2 px, olive mud #4E4A2A + foam | art-bible §3, §6.3 | Needed |  |
| 101 | Buried-in-sand cell | Environment | organic sand waves, 100 % cover | art-bible §3, §6.3 | Needed |  |
| 102 | Lava vein | Environment | 3 px gap: 1 px ink + 2 px #FFB21F (Hellfire) | art-bible §3, §6.3 | Needed |  |
| 103 | Crumbling cell | Environment | crack + dashed outline, regrow animation | art-bible §3, §6.3 | Needed |  |
| 104 | Steel block | Item / Prop | block tiles 16x16 (falling, bag) and 5x5 (on ground); autotile masks; states: falling, lying, shatter, dissolve | art-bible §3 | Needed | 1 |
| 105 | Cracked ember block | Item / Prop | block tiles 16x16 (falling, bag) and 5x5 (on ground); autotile masks; states: falling, lying, shatter, dissolve | art-bible §3 | Needed |  |
| 106 | Sharp ice block | Item / Prop | block tiles 16x16 (falling, bag) and 5x5 (on ground); autotile masks; states: falling, lying, shatter, dissolve | art-bible §3 | Needed |  |
| 107 | Wood-and-rope block | Item / Prop | block tiles 16x16 (falling, bag) and 5x5 (on ground); autotile masks; states: falling, lying, shatter, dissolve | art-bible §3 | Needed |  |
| 108 | Stained-glass block | Item / Prop | block tiles 16x16 (falling, bag) and 5x5 (on ground); autotile masks; states: falling, lying, shatter, dissolve | art-bible §3 | Needed |  |
| 109 | Odd Block (magenta, one outline + sparkle) | Item / Prop | block tiles 16x16 (falling, bag) and 5x5 (on ground); autotile masks; states: falling, lying, shatter, dissolve | art-bible §3 | Needed |  |
| 110 | Enemy block (ivory stone, flat) | Item / Prop | block tiles 16x16 (falling, bag) and 5x5 (on ground); autotile masks; states: falling, lying, shatter, dissolve | art-bible §3 | Needed |  |
| 111 | Spell VFX: Slash | VFX / Particles | stepped diagonal streak across each target tile, <= 0.25 s; 3 grey values, tinted in code | art-bible §3 (VFX table) | Needed | 1 |
| 112 | Spell VFX: Push | VFX / Particles | column of squares sliding right half a tile, <= 0.3 s; 3 grey values, tinted in code | art-bible §3 (VFX table) | In Progress (ASSET-016 candidate, 2026-10-31) | 1 |
| 113 | Spell VFX: Burn | VFX / Particles | stepped flame column rising 2 steps, <= 0.35 s; 3 grey values, tinted in code | art-bible §3 (VFX table) | Needed |  |
| 114 | Spell VFX: Ice | VFX / Particles | falling shards freezing into a square frame (Frozen) or a plus (Chill), <= 0.35 s; 3 grey values, tinted in code | art-bible §3 (VFX table) | Needed |  |
| 115 | Spell VFX: Crack | VFX / Particles | stepped 1 px crack spreading across tiles, <= 0.3 s; 3 grey values, tinted in code | art-bible §3 (VFX table) | Needed |  |
| 116 | Spell VFX: Build | VFX / Particles | squares rising from the slab front (Wall/Thorns), <= 0.3 s; 3 grey values, tinted in code | art-bible §3 (VFX table) | Needed |  |
| 117 | Frozen overlay | VFX / Particles | square ice shell around the sprite, 2 sizes | art-bible §3/§4/§8 | Needed |  |
| 118 | Burning overlay | VFX / Particles | stepped flame 2 frames + horizontal stripe, 2 sizes | art-bible §3/§4/§8 | Needed |  |
| 119 | Fragile crack overlay | VFX / Particles | ink cracks over ivory | art-bible §3/§4/§8 | Needed |  |
| 120 | Chill overlay | VFX / Particles | plus-shaped snowflake + stack count | art-bible §3/§4/§8 | Needed |  |
| 121 | Hit flash | VFX / Particles | 1 frame, palette flash to ivory (shader), no red | art-bible §3/§4/§8 | Needed | 1 |
| 122 | Primal Shard | VFX / Particles | polyomino of lattice-gold tiles, 2 px per tile, one shape per Warden (code-built) | art-bible §3/§4/§8 | Needed |  |
| 123 | Engraving cell | VFX / Particles | recessed gold square, 1 px inner outline, fades 100 -> 0 % | art-bible §3/§4/§8 | Needed |  |
| 124 | Cast target tile | VFX / Particles | material-colour tile with bevel, intensity ramp 35 -> 100 % (code/shader) | art-bible §3/§4/§8 | Needed | 1 |
| 125 | Telegraph tile | VFX / Particles | red fill, 45-degree stripes, 2 px outline + ink edge (code) | art-bible §3/§4/§8 | Needed | 1 |
| 126 | Square particles | VFX / Particles | 2x2 px particle sprites: ivory, material colours | art-bible §3/§4/§8 | Needed |  |
| 127 | UI frame: Panel | UI | 9-slice 16x16, margins 4/4/4/6; #1E1B24 90 %, 1 art-px Sương border | art-bible §7 | Needed | 1 |
| 128 | UI frame: Button | UI | raised, pressed state sinks 2 art-px | art-bible §7 | Needed | 1 |
| 129 | UI frame: Slot | UI | recessed, margin 3 | art-bible §7 | Needed | 1 |
| 130 | UI frame: Bar | UI | 3-slice horizontal, ink groove | art-bible §7 | Needed | 1 |
| 131 | Health bar skins | UI | player green, boss ivory; half-life notch | art-bible §7 | Needed | 1 |
| 132 | Icon set 12x12 (HUD) | UI | pause, low-HP "!", check, cross, rotate, armor, Burn, Fragile, Chill, Frozen, cloud, Odd sparkle, plus, info, Engraving/Awakening 2x2, 4 d-pad arrows | art-bible §7 | Needed | 1 |

## UI Screens

| # | Screen Name | Description | Source | Status |
|---|-------------|-------------|--------|--------|
| 1 | Title | In-match HUD specced in design/ux/hud.md; other screens need their own UX spec; all use the frame system of art-bible §7 | art-bible §7.9 / hud.md | Needed |
| 2 | Character select (Pact) | In-match HUD specced in design/ux/hud.md; other screens need their own UX spec; all use the frame system of art-bible §7 | art-bible §7.9 / hud.md | Needed |
| 3 | World map (floors) | In-match HUD specced in design/ux/hud.md; other screens need their own UX spec; all use the frame system of art-bible §7 | art-bible §7.9 / hud.md | Needed |
| 4 | Region map (stages) | In-match HUD specced in design/ux/hud.md; other screens need their own UX spec; all use the frame system of art-bible §7 | art-bible §7.9 / hud.md | Needed |
| 5 | Match HUD | In-match HUD specced in design/ux/hud.md; other screens need their own UX spec; all use the frame system of art-bible §7 | art-bible §7.9 / hud.md | Needed |
| 6 | Card reward / treasure | In-match HUD specced in design/ux/hud.md; other screens need their own UX spec; all use the frame system of art-bible §7 | art-bible §7.9 / hud.md | Needed |
| 7 | Shop | In-match HUD specced in design/ux/hud.md; other screens need their own UX spec; all use the frame system of art-bible §7 | art-bible §7.9 / hud.md | Needed |
| 8 | Event | In-match HUD specced in design/ux/hud.md; other screens need their own UX spec; all use the frame system of art-bible §7 | art-bible §7.9 / hud.md | Needed |
| 9 | Rest camp | In-match HUD specced in design/ux/hud.md; other screens need their own UX spec; all use the frame system of art-bible §7 | art-bible §7.9 / hud.md | Needed |
| 10 | Spare / Execute | In-match HUD specced in design/ux/hud.md; other screens need their own UX spec; all use the frame system of art-bible §7 | art-bible §7.9 / hud.md | Needed |
| 11 | Spoils (Primal Shard) | In-match HUD specced in design/ux/hud.md; other screens need their own UX spec; all use the frame system of art-bible §7 | art-bible §7.9 / hud.md | Needed |
| 12 | Climb over | In-match HUD specced in design/ux/hud.md; other screens need their own UX spec; all use the frame system of art-bible §7 | art-bible §7.9 / hud.md | Needed |
| 13 | Ending (3 variants) | In-match HUD specced in design/ux/hud.md; other screens need their own UX spec; all use the frame system of art-bible §7 | art-bible §7.9 / hud.md | Needed |
| 14 | Achievements | In-match HUD specced in design/ux/hud.md; other screens need their own UX spec; all use the frame system of art-bible §7 | art-bible §7.9 / hud.md | Needed |
| 15 | Pause | In-match HUD specced in design/ux/hud.md; other screens need their own UX spec; all use the frame system of art-bible §7 | art-bible §7.9 / hud.md | Needed |
| 16 | Settings | In-match HUD specced in design/ux/hud.md; other screens need their own UX spec; all use the frame system of art-bible §7 | art-bible §7.9 / hud.md | Needed |
| 17 | Block set | In-match HUD specced in design/ux/hud.md; other screens need their own UX spec; all use the frame system of art-bible §7 | art-bible §7.9 / hud.md | Needed |

## HUD Elements

| # | Element | Description | Source | Status |
|---|---------|-------------|--------|--------|
| 1 | HUD elements E-01..E-40 | Specified in design/ux/hud.md; visuals from art-bible §7 (frames, icons, bars, text tiers) | hud.md | Needed |

## Audio

| # | Name | Type (SFX / Music / Ambient) | Description | Source | Status |
|---|------|------------------------------|-------------|--------|--------|
| - | none | - | The game has no audio yet (art-bible §8, accessibility Auditory) | - | - |
