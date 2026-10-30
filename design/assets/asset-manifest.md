# Asset Manifest

> Last updated: 2026-10-31 (ASSET-001 and ASSET-003 moved to In Progress after the first PixelLab pass)
> Vertical slice 1: all 17 inventory rows marked Slice = 1 are specced (ASSET-001..015; UI frames are one asset with four files).

## Progress Summary

| Total | Needed | In Progress | Done | Approved |
|-------|--------|-------------|------|----------|
| 15 | 13 | 2 | 0 | 0 |

**In Progress** means: the idle A/B frames exist as candidates under `design/assets/candidates/<entity>/`, passed art bible §8.9 #1, #3, #7 (measured), #9 in `prototypes/art-check`, and the generation log lives in the spec. Still missing for Done: the remaining clips (hero 12 frames, goblin 6), the Aseprite source and the exported sheet + JSON under `assets/art/units/`.

## Assets by Context

### Character: Swordsman
| Asset ID | Name | Category | Status | Spec File |
|----------|------|----------|--------|-----------|
| ASSET-001 | Swordsman sprite sheet | Sprite / 2D art | In Progress (idle A/B: `design/assets/candidates/swordsman/ASSET-001-idle-A-32x48.png`, `-B`) | design/assets/specs/swordsman-assets.md |
| ASSET-002 | Swordsman portrait | Sprite / 2D art | Needed | design/assets/specs/swordsman-assets.md |

### Character: Goblin Scout
| Asset ID | Name | Category | Status | Spec File |
|----------|------|----------|--------|-----------|
| ASSET-003 | Goblin small body sprite sheet (base: Goblin Scout) | Sprite / 2D art | In Progress (idle A/B: `design/assets/candidates/goblin-scout/ASSET-003-idle-A-32x48.png`, `-B`; leather palette revised, see spec) | design/assets/specs/goblin-scout-assets.md |

### Level: Misty Forest
| Asset ID | Name | Category | Status | Spec File |
|----------|------|----------|--------|-----------|
| ASSET-004 | Slab set: Misty Forest | Environment | Needed | design/assets/specs/misty-forest-assets.md |
| ASSET-005 | Backdrop: Misty Forest | Environment | Needed | design/assets/specs/misty-forest-assets.md |
| ASSET-006 | Wall (Misty Forest) | Environment | Needed | design/assets/specs/misty-forest-assets.md |
| ASSET-007 | Thorns patch (Misty Forest) | Environment | Needed | design/assets/specs/misty-forest-assets.md |

### System: Slice 1 combat visuals and UI
| Asset ID | Name | Category | Status | Spec File |
|----------|------|----------|--------|-----------|
| ASSET-008 | Steel block tiles | Sprite / 2D art | Needed | design/assets/specs/slice1-combat-ui-assets.md |
| ASSET-009 | Spell VFX: Slash | VFX | Needed | design/assets/specs/slice1-combat-ui-assets.md |
| ASSET-010 | Hit flash (shader) | VFX | Needed | design/assets/specs/slice1-combat-ui-assets.md |
| ASSET-011 | Cast target tile | VFX | Needed | design/assets/specs/slice1-combat-ui-assets.md |
| ASSET-012 | Telegraph tile | VFX | Needed | design/assets/specs/slice1-combat-ui-assets.md |
| ASSET-013 | UI frames (Panel, Button, Slot, Bar) | UI | Needed | design/assets/specs/slice1-combat-ui-assets.md |
| ASSET-014 | Health bar skins | UI | Needed | design/assets/specs/slice1-combat-ui-assets.md |
| ASSET-015 | Icon set 12x12 (HUD) | UI | Needed | design/assets/specs/slice1-combat-ui-assets.md |
