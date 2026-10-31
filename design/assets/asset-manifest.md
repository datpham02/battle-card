# Asset Manifest

> Last updated: 2026-10-31 (every slice-1 asset with drawn art now has a candidate: units, Misty Forest set, UI frames + icons, floor tiles, slash + push VFX; ASSET-016 added)
> Vertical slice 1: all 18 inventory rows marked Slice = 1 are specced (ASSET-001..016; UI frames are one asset with four files; inventory row 112 Push joined slice 1 on 2026-10-31 because Chấn phong is in the Swordsman starter deck).

## Progress Summary

| Total | Needed | In Progress | Done | Approved |
|-------|--------|-------------|------|----------|
| 16 | 3 | 13 | 0 | 0 |

**In Progress** means: the frames or files exist as candidates under `design/assets/candidates/<group>/`, were rendered through `prototypes/art-check` with retained evidence (`production/qa/evidence/asset-slice1-art-check/`), and the production log lives in the spec. Still missing for Done: the art-director's sign-off on the open points listed in each spec, and the export into `assets/art/...` (units via Story 045's exporter; UI, floor and VFX files are already at their final pixel size and only need copying + import settings). **Needed** rows are code, not drawn art (ASSET-010 shader, ASSET-014 fills), plus the portrait.

## Assets by Context

### Character: Swordsman
| Asset ID | Name | Category | Status | Spec File |
|----------|------|----------|--------|-----------|
| ASSET-001 | Swordsman sprite sheet | Sprite / 2D art | In Progress (v2 design, all 14 frames at 40x48 in `design/assets/candidates/swordsman/`, every clip eye-checked as GIF; sheet export waits for Story 045) | design/assets/specs/swordsman-assets.md |
| ASSET-002 | Swordsman portrait | Sprite / 2D art | Needed | design/assets/specs/swordsman-assets.md |

### Character: Goblin Scout
| Asset ID | Name | Category | Status | Spec File |
|----------|------|----------|--------|-----------|
| ASSET-003 | Goblin small body sprite sheet (base: Goblin Scout) | Sprite / 2D art | In Progress (all 8 frames at 32x48 in `design/assets/candidates/goblin-scout/`, v3 palette for §6.6 legibility; open: outline counting rule, see spec) | design/assets/specs/goblin-scout-assets.md |

### Level: Misty Forest
| Asset ID | Name | Category | Status | Spec File |
|----------|------|----------|--------|-----------|
| ASSET-004 | Slab set: Misty Forest | Environment | In Progress (16x16 nine-slice + 6 stamps drawn by script, `design/assets/candidates/misty-forest/`) | design/assets/specs/misty-forest-assets.md |
| ASSET-005 | Backdrop: Misty Forest | Environment | In Progress (sky / far / near layers 800 wide, generated tree line + scripted ground, mist, margin props; open: tree tops under Z1) | design/assets/specs/misty-forest-assets.md |
| ASSET-006 | Wall (Misty Forest) | Environment | In Progress (40x40 candidate; open: §3 occlusion sentence) | design/assets/specs/misty-forest-assets.md |
| ASSET-007 | Thorns patch (Misty Forest) | Environment | In Progress (scripted candidate) | design/assets/specs/misty-forest-assets.md |

### System: Slice 1 combat visuals and UI
| Asset ID | Name | Category | Status | Spec File |
|----------|------|----------|--------|-----------|
| ASSET-008 | Steel block tiles | Sprite / 2D art | In Progress (16x16 + 5x5, steel column only, `design/assets/candidates/slice1-fx/`) | design/assets/specs/slice1-combat-ui-assets.md |
| ASSET-009 | Spell VFX: Slash | VFX | In Progress (4 frames 38x27, v2 solid 3 px band; open: §3 says 2x2) | design/assets/specs/slice1-combat-ui-assets.md |
| ASSET-010 | Hit flash (shader) | VFX | Needed (code; the art-check `--seq` flash shader shows the intended look) | design/assets/specs/slice1-combat-ui-assets.md |
| ASSET-011 | Cast target tile | VFX | In Progress (5 mark masks 16x16 + JSON; steel checked in-game, the other four on preview only) | design/assets/specs/slice1-combat-ui-assets.md |
| ASSET-012 | Telegraph tile | VFX | In Progress (8x8 stripe fallback texture; frame + Ink edge are code) | design/assets/specs/slice1-combat-ui-assets.md |
| ASSET-013 | UI frames (Panel, Button, Slot, Bar) | UI | In Progress (four 9/3-slice sources, `design/assets/candidates/slice1-ui/`; open: lip below the border, bar 16 px vs §7.5 12 px) | design/assets/specs/slice1-combat-ui-assets.md |
| ASSET-014 | Health bar skins | UI | Needed (code-drawn fills on the ASSET-013 bar; mocked in art-check `--ui`) | design/assets/specs/slice1-combat-ui-assets.md |
| ASSET-015 | Icon set 12x12 (HUD) | UI | In Progress (21 icons + JSON; open: pad arrows 28 px vs the 12 px grid) | design/assets/specs/slice1-combat-ui-assets.md |
| ASSET-016 | Spell VFX: Push | VFX | In Progress (4 frames 38x27, Chấn phong group) | design/assets/specs/slice1-combat-ui-assets.md |
