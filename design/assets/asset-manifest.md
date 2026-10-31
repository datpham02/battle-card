# Asset Manifest

> Last updated: 2026-10-31 (Story 047: ASSET-004/005/007 and the status overlays 017/018/020 are drawn in the battle canvas and set to Done, rows 017–020 added; Story 045: ASSET-001 and ASSET-003 exported to `assets/art/units/` and set to Done; earlier the same day every slice-1 asset with drawn art got a candidate: units, Misty Forest set, UI frames + icons, floor tiles, slash + push VFX; ASSET-016 added)
> Vertical slice 1: all 18 inventory rows marked Slice = 1 are specced (ASSET-001..016; UI frames are one asset with four files; inventory row 112 Push joined slice 1 on 2026-10-31 because Chấn phong is in the Swordsman starter deck).

## Progress Summary

| Total | Needed | In Progress | Done | Approved |
|-------|--------|-------------|------|----------|
| 20 | 3 | 8 (+1 superseded) | 8 | 0 |

**In Progress** means: the frames or files exist as candidates under `design/assets/candidates/<group>/`, were rendered through `prototypes/art-check` with retained evidence (`production/qa/evidence/asset-slice1-art-check/`), and the production log lives in the spec. Still missing for Done: the art-director's sign-off on the open points listed in each spec, and the export into `assets/art/...` (units via Story 045's exporter; UI, floor and VFX files are already at their final pixel size and only need copying + import settings). **Needed** rows are code, not drawn art (ASSET-010 shader, ASSET-014 fills), plus the portrait.

## Assets by Context

### Character: Swordsman
| Asset ID | Name | Category | Status | Spec File |
|----------|------|----------|--------|-----------|
| ASSET-001 | Swordsman sprite sheet | Sprite / 2D art | Done (Story 045, 2026-10-31: `assets/art/units/unit_kiem_si_sheet.png` 81x391 + `.json`, 8 clips / 14 frames, facing right, exported by `tools/asset-pipeline/export_sheets.py` from `art_src/units/kiem_si/`; evidence `production/qa/evidence/unit-sheet-export/`; awaiting the art-director's sign-off for Approved) | design/assets/specs/swordsman-assets.md |
| ASSET-002 | Swordsman portrait | Sprite / 2D art | Needed | design/assets/specs/swordsman-assets.md |

### Character: Goblin Scout
| Asset ID | Name | Category | Status | Spec File |
|----------|------|----------|--------|-----------|
| ASSET-003 | Goblin small body sprite sheet (base: Goblin Scout) | Sprite / 2D art | Done (Story 045, 2026-10-31: `assets/art/units/unit_goblin_scout_sheet.png` 65x244 + `.json`, 5 clips / 8 frames, facing left, exported from `art_src/units/goblin_scout/`; evidence `production/qa/evidence/unit-sheet-export/`; awaiting the art-director's sign-off for Approved; open from the spec: outline counting rule) | design/assets/specs/goblin-scout-assets.md |

### Level: Misty Forest
| Asset ID | Name | Category | Status | Spec File |
|----------|------|----------|--------|-----------|
| ASSET-004 | Slab set: Misty Forest | Environment | Done (in game since Story 047, 2026-10-31: `assets/art/env/forest/env_slab_forest_9slice.png` + stamps drawn by `SlabPainter`; v4 nine-slice + 18 stamps, dark tone approved; light variant parked in `slab-explorations/`; awaiting art-director sign-off) | design/assets/specs/misty-forest-assets.md |
| ASSET-005 | Backdrop: Misty Forest | Environment | Done (in game since Story 047, 2026-10-31: `assets/art/env/forest/bg_forest_far.png` + `bg_forest_near.png` via `BackdropLayer`, mist bottom row 70 in `region.json`; v2 one-frame scene, 20 % band; open: palette lock; awaiting sign-off) | design/assets/specs/misty-forest-assets.md |
| ASSET-006 | Wall (Misty Forest) | Environment | Superseded 2026-10-31 — the Wall cards drop the tile out (code effect on the slab art, no drawn asset); v1/v2 files kept as history | design/assets/specs/misty-forest-assets.md |
| ASSET-007 | Thorns patch (Misty Forest) | Environment | Done (in game since Story 047, 2026-10-31: `assets/art/env/forest/env_thorn_forest_tile16.png` tiled over thorn cells by `FloorLayer`; awaiting sign-off) | design/assets/specs/misty-forest-assets.md |

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
| ASSET-017 | Status overlay: Burning (hero + goblin frames) | VFX | Done (in game since Story 047, 2026-10-31: PixelLab VFX game pack under `assets/art/vfx/status/`, `VfxPack` + `UnitLayer` behind/front; awaiting sign-off) | design/assets/specs/slice1-combat-ui-assets.md |
| ASSET-018 | Status overlay: Frozen (hero + goblin frames) | VFX | Done (in game since Story 047, 2026-10-31: PixelLab VFX game pack under `assets/art/vfx/status/`, `VfxPack` + `UnitLayer` behind/front; awaiting sign-off) | design/assets/specs/slice1-combat-ui-assets.md |
| ASSET-019 | Status overlay: Fragile | VFX | In Progress (script overlay in `draw_status.py`; stays code-drawn in `CutHudView`) | design/assets/specs/slice1-combat-ui-assets.md |
| ASSET-020 | Status overlay: Chill (hero + goblin frames) | VFX | Done (in game since Story 047, 2026-10-31: PixelLab VFX game pack under `assets/art/vfx/status/`, `VfxPack` + `UnitLayer` behind/front; awaiting sign-off) | design/assets/specs/slice1-combat-ui-assets.md |
