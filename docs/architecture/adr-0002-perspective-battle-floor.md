# ADR-0002: Perspective battle floor — flat sub-viewport warped by a homography; board geometry via BoardGeometry

## Status

Proposed — implements the user's 2026-11-02 approval to finish the perspective battle floor and ship it ON at back
ratio 0.82 (look approved on `production/qa/evidence/floor-perspective-proto/01-idle-082.png` and 03–06).

> **Who may move this to `Accepted`: the user, or `technical-director` on the user's explicit confirmation.**

## Date

2026-11-02

## Last Verified

2026-11-02

## Decision Makers

User (look and default ratio); drafted by Claude while finishing the prototype (commit aa1cae5).

## Summary

The battle board is drawn as a projective trapezoid ("real 3/4"): the bottom edge keeps its width, the back row is
`back_ratio` (0.82) as wide, rows get shorter towards the back. The floor is still painted FLAT, in its own 800x360
SubViewport, and a canvas_item shader resamples it through the inverse homography. Everything else that lives in board
space (HUD ghosts and labels, hazard tags, field drops, unit feet and shadows, VFX anchors, touch input) asks one facade,
`BoardGeometry`, for where a cell is on screen, so every consumer agrees on the same cell polygon.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 (4.6.3 installed) |
| **Domain** | Rendering (2D), UI / input |
| **Layer** | Presentation |
| **Knowledge Risk** | LOW — SubViewport, ViewportTexture, canvas_item shader with a `mat3` uniform, `draw_colored_polygon`: all pre-4.4 APIs |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Headless suites + windowed UI click suites with the warp on; screenshots in `production/qa/evidence/floor-perspective/` |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | Story 047 battle canvas (art SubViewport, ScreenLayout art frame) |
| **Enables** | A warped backdrop ground later (paused by the user; `backdrop_layer.gd` is untouched) |
| **Blocks** | None |

## Context

The flat board read as a top-down grid next to side-view units. The user approved a prototype (2026-11-02) that warps
the floor into a trapezoid at back ratio 0.82. The prototype warped only the floor, telegraphs, ghost cells and feet;
the HUD labels, hazard tags, drop tiles, boss placeholder, shadows and several overlays were still drawn on the flat
cell rects, so they floated off the warped slabs. ~50 call sites asked `ScreenLayout.cell_rect` / `cell_center` /
`cell_at` / `board_rect` directly.

## Decision

1. **Render path.** `FloorLayer` (+ `FloorDynamicLayer`: telegraphs, floor VFX, engraving) keeps drawing flat into a
   transparent 800x360 `FloorViewport`; `BattleCanvas` draws that texture on the `FloorWarp` Sprite2D through
   `canvas_floor_perspective.gdshader` (inverse homography per fragment, nearest sampling, half tints), between
   `BackdropLayer` and `UnitLayer`. Off (`back_ratio` 0) the Story 047 tree is used unchanged.
2. **The map.** `FloorPerspective` holds the homography in art px (closed-form warp / unwarp; the matrix / inverse
   Basis for the shader). Defined on the flat board's art rect, so warped slab edges land on the slabs' own edges.
3. **One geometry facade.** `BoardGeometry` (`src/layout/board_geometry.gd`) is the only board-space API for
   consumers. Model space = the flat board in screen px (ScreenLayout's layout; snapped to whole art px when warped,
   i.e. exactly the floor slabs); `to_screen` / `to_model` map it. It gives cell polygons, centres / top-centres /
   any fraction point, bounding boxes, fit rects (for text / panels / icons), `cell_at` (touch), the art-px forms for
   the art layers (`warp_art_px`, `art_quad`, `art_local_scale`) and drawing helpers (`fill`, `outline`, `line`,
   `draw_polygon_outline`, `offset_polygon`). Flat, it is the identity and calls the plain `draw_rect`, so the flat
   build draws exactly what it drew before.
4. **Consumers compose decorations in model space and draw through the map**: cell fills and outlines become warped
   quads, inner bars / cracks / ripples / X marks are mapped point by point, text and small panels sit on fit rects,
   rings and icons sit on mapped centres scaled by the local scale. Sprites and VFX frames are never scaled; only
   their anchors move (`warp_art_px`). The boss placeholder is the warped footprint body quad; the ground shadow is
   the stepped ellipse sized by the local scale at the feet.
5. **Guard.** `tests/unit/layout/board_geometry_consumers_test.gd` fails if any script outside BoardGeometry,
   ScreenLayout, FloorPerspective, FloorLayer and BattleCanvas asks ScreenLayout for board cells.
6. **Config.** combat.json `floor.perspective.back_ratio` = 0.82 (shipped); `--floor-perspective=0` forces flat.

## Alternatives Considered

- **Warp each consumer's own drawing by moving its rect's centre** (prototype for drops): cheap, but the rects stay
  axis-aligned and visibly miss the trapezoid slabs; every consumer re-implements the map. Rejected.
- **Render HUD board overlays into the floor viewport** so the shader warps them too: text and thin outlines would be
  resampled (pixel noise, unreadable small text) and they would sit under the units. Rejected.
- **A 2-triangle textured quad instead of the shader**: affine seam along the diagonal. Rejected (prototype).
- **3D camera / Node3D floor**: far more change (pipeline, pixel snapping, input) for the same picture. Rejected.

## Consequences

- Positive: one definition of where a cell is; touch, ghosts, labels and the floor cannot disagree.
- Positive: the flat path is the same code path (identity map), still testable by pinning back_ratio 0.
- Negative: back rows lose some source rows under nearest sampling (stair steps change spacing); accepted look.
- Negative: decoration sizes shrink a little at the back (local scale); fonts stay their flat size for legibility.

## Risks

- A new consumer that bypasses BoardGeometry draws flat cells over the warped floor — caught by the guard test.
- `cell_at` near slab edges uses the snapped model board (sub-art-px differences from the unsnapped layout are absorbed
  by checking neighbours).

## Performance Implications

One extra 800x360 SubViewport and one full-canvas shader pass (one sample, one 3x3 multiply, one divide per fragment);
HUD polygons are 4-point `draw_colored_polygon` calls instead of `draw_rect`. Negligible on the mobile target.

## Validation Criteria

- `tests/unit/layout/board_geometry_test.gd`, `board_geometry_consumers_test.gd`, `floor_perspective_test.gd`,
  `tests/unit/battle/floor_perspective_wiring_test.gd` pass; the full suite passes with the default (0.82) and with
  back_ratio forced to 0.
- Evidence screenshots: `production/qa/evidence/floor-perspective/01`–`09`.

## GDD Requirements Addressed

None new: presentation only. The board's rules (cells, halves, footprints, touch aiming) are unchanged; the HUD
spec's board-anchored elements (`design/ux/hud.md`, "Đọc đòn boss (trên lưới)", "Con số và trạng thái") keep their
meaning and now sit on the drawn (perspective) cells.

## Related

- `design/art/art-bible.md` §6.3 / §8.6, `design/ux/hud.md` (perspective notes), `assets/data/schema.md`
  (`floor.perspective.back_ratio`).
