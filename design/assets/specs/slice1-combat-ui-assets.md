# Asset Specs — System: Slice 1 combat visuals and UI

> **Source**: design/assets/entity-inventory.md (Slice 1 rows: Steel block, Spell VFX: Slash, Hit flash, Cast target tile, Telegraph tile, UI frames, Health bar skins, Icon set), design/ux/hud.md
> **Art Bible**: design/art/art-bible.md (§3, §4, §7, §8)
> **Generated**: 2026-10-29
> **Status**: 10 assets specced / 0 approved / 0 in production / 0 done
> **Mode**: solo — art-director and technical-artist skipped; technical constraints not validated.

## ASSET-008 — Steel block tiles

| Field | Value |
|-------|-------|
| Category | Sprite / 2D art (item) |
| Dimensions | One tile 16x16 (falling, bag) and one tile 5x5 (on the ground); the outer ink outline of the whole block shape is drawn in code (not 16 autotile masks) |
| Format | `.png` RGBA 8-bit, Lossless, Nearest; column 1 of the shared block sheets |
| Naming | `assets/art/blocks/block_tiles_16.png`, `block_tiles_5.png` (column order: steel, ember, ice, wood, glass, odd, enemy) |
| Slice | 1 |

**Visual Description:** Polished steel square with a bevel: 1 px light edge top-left, dark edge bottom-right, flat mid face. At 5 px the mark is a single light pixel top-left and a dark pixel bottom-right. Only the block glows: a 1 px hand-drawn pixel halo is added in code around the whole shape. States (falling, lying with 2 px hover and square shadow, shatter into 4 square shards, dissolve into 1 px particles) are code-driven from these tiles.

**Palette:** #8FA3B8 body, #EEF4FA highlight, #5F6F82 shadow, #1B1722 outline (code).

**Art Bible Anchors:** §1 P1 (only blocks glow), §3 (block states, steel mark), §4 (steel colours), §8.3 (16x16 and 5x5 tiles).

**Generation Prompt:**
```
Pixel art game tile, one square polished steel block face, 16x16 pixels, bevelled: light 1-pixel edge on top and left (#EEF4FA), darker edge on bottom and right (#5F6F82), flat blue-grey middle (#8FA3B8), crisp pixels, no outline, no text, transparent background.
```

**Status:** Needed

## ASSET-009 — Spell VFX: Slash

| Field | Value |
|-------|-------|
| Category | VFX |
| Dimensions | 3–5 frames, each 38x27 art-px (the smallest cell); centred, never scaled, on larger cells; total <= 0.25 s |
| Format | `.png` sheet RGBA 8-bit in three fixed grey values (light / body / ink), tinted in code with the hero's block colour via `modulate` |
| Naming | `assets/art/vfx/vfx_slash_sheet.png` |
| Slice | 1 |

**Visual Description:** A stepped diagonal streak of 2x2 squares sweeping once across each target tile from left to right, then gone. No beams, no round bursts, no screen shake. Reduced motion: only the last frame, held 0.15 s.

**Art Bible Anchors:** §1 P1 (all VFX built from squares), §3 VFX table (Slash), §8.3 (3 greys, code tint), §8.5 (particles <= 128).

**Generation Prompt:**
```
Pixel art effect sprite sheet, 4 frames of 38x27 pixels, a diagonal slash made only of small square pixels in a stepped staircase line sweeping from left to right across the tile, three grey values only (light, mid, dark), no curves, no glow, no blur, transparent background.
```

**Status:** Needed

## ASSET-010 — Hit flash (shader, no drawn art)

| Field | Value |
|-------|-------|
| Category | VFX (shader) |
| Dimensions | n/a — part of the `unit_fx` canvas shader |
| Format | Palette flash of the unit sprite to Ivory #EFE6D2 for 0.06 s; no red |
| Naming | `assets/shaders/unit_fx.gdshader` (shared with Frozen, Burning, Fragile, Awakening palette swap) |
| Slice | 1 |

**Description:** On hit, every opaque texel of the unit is drawn as Ivory for 0.06 s, then normal. Reduced motion: a single static frame. Fallback without shader: the `hit` frame of the sheet alone. Output must stay inside the palette (texel or one palette colour).

**Art Bible Anchors:** §5.4 (hit flash not drawn), §4 (no red), §8.5 (shader rules, <= 3 ShaderMaterials, fallback).

**Status:** Needed

## ASSET-011 — Cast target tile

| Field | Value |
|-------|-------|
| Category | VFX (floor overlay) |
| Dimensions | Code-drawn at cell size; per-material 16x16 mark mask (bevel / crack / clipped corners / rope / lead lines) stretched by 9-slice |
| Format | `floor_fx` shader + `assets/art/vfx/fx_material_marks_16.png` (5 columns, one per hero material) |
| Naming | `assets/shaders/floor_fx.gdshader`, `assets/art/vfx/fx_material_marks_16.png` |
| Slice | 1 |

**Description:** The chosen enemy floor tiles, whole tiles only, filled with the hero's block body colour at 60 % (alpha blend allowed on the floor layer only, Art Bible §8.5) with the material mark and a raised edge in the highlight colour, intensity ramping 35 → 100 % over the channel time (0.2 s + 0.25 s per cell), never blinking; Reduced motion: constant 70 %. While dragging (before the cast) the same tiles use the block colour with an Ivory outline and ✓/✗ with an ink edge (Art Bible §7.4). Never confused with Engraving (recessed gold) or the telegraph (red, diagonal stripes).

**Art Bible Anchors:** §3 (block and target-tile states), §4 (signal row "Ô đích đang niệm"), §7.4 (outline and ✓/✗ in Ivory with ink edge), §8.5.

**Generation Prompt** (mark sheet only):
```
Pixel art sheet of 5 square tile marks, 16x16 each, on transparent background, white only: 1) bevel edge, 2) a single diagonal crack, 3) square with two clipped corners, 4) square frame with one horizontal rope line, 5) square split into 2x2 by thin lead lines. Crisp pixels, no anti-aliasing.
```

**Status:** Needed

## ASSET-012 — Telegraph tile

| Field | Value |
|-------|-------|
| Category | VFX (floor overlay) |
| Dimensions | Code-drawn at cell size; fallback stripe texture 8x8 |
| Format | `floor_fx` shader (stripes by `floor(pixel)`), fallback `assets/art/vfx/fx_telegraph_stripe_8.png` |
| Naming | `assets/art/vfx/fx_telegraph_stripe_8.png` |
| Slice | 1 |

**Description:** Incoming-attack cell on the player's half: red #E5293B fill with 45° diagonal stripes on the floor layer (under units), a 2 px red outline with a 1 art-px ink edge outside drawn on the overlay layer above units, countdown label on an ink plate in the HUD layer. Red is used nowhere else.

**Art Bible Anchors:** §1 P3 (red reserved), §4 (telegraph signal row), §7.4 (ink edge, label on ink plate), §8.6 (layer order).

**Status:** Needed

## ASSET-013 — UI frames (Panel, Button, Slot, Bar)

| Field | Value |
|-------|-------|
| Category | UI |
| Dimensions | Panel and Button: 9-slice source 16x16, margins 4/4/4/6. Button: 3 states (default with 2 art-px bottom lip, pressed without lip, disabled). Slot: 9-slice 16x16, margin 3, recessed. Bar: 3-slice 16x8, ends 2, border 1. Drawn at x2 art-px on the 1280x720 HUD layer |
| Format | `.png` RGBA 8-bit, Lossless, Nearest; integer art-px stretch only |
| Naming | `assets/art/ui/ui_frame_panel_9slice.png`, `ui_frame_button_9slice.png` (3 states in a row), `ui_frame_slot_9slice.png`, `ui_frame_bar_3slice.png` |
| Slice | 1 |

**Description:** Square corners notched by 1 art-px, no rounded corners, no pills, no glow. Panel fill #1E1B24 at 90 %, border Mist #7D8896 1 art-px (>= 3:1), bottom lip ink. Slot: recessed (top-left ink, bottom-right #4A4652), outer border Mist. Bar groove ink at 90 %. Touch targets are separate invisible rects (>= 88 px, primary >= 96 px).

**Art Bible Anchors:** §3 UI shape grammar, §4 UI palette, §7.4 frame system and contrast fixes, §8.3 UI 9-slice.

**Generation Prompt:**
```
Pixel art UI kit, four small frames on transparent background: 1) a dark panel 16x16 with square corners notched by one pixel, 1-pixel grey-blue border (#7D8896), fill #1E1B24, darker 2-pixel bottom lip; 2) the same as a button in three states (raised, pressed without lip, disabled faded); 3) a recessed slot with dark top-left and lighter bottom-right edges; 4) a thin horizontal bar frame 16x8 with a dark groove. Crisp pixels, flat colours, no rounded corners, no glow, no text.
```

**Status:** Needed

## ASSET-014 — Health bar skins

| Field | Value |
|-------|-------|
| Category | UI |
| Dimensions | Bar 12 px tall at 720p using ASSET-013 Bar frame; fill drawn in code |
| Format | Code-drawn fills; no extra texture |
| Naming | n/a (uses `ui_frame_bar_3slice.png`) |
| Slice | 1 |

**Description:** Player fill #58D468, boss fill Ivory; damage trail #B8B0A0 shrinking over 0.4 s (no red); boss half-life notch Ivory 2 px, sticking out 3 px; low HP: "!" + Ivory border pulsing 1 Hz (Reduced motion: solid 3 art-px border); number "170/200" at 24 px with ink outline.

**Art Bible Anchors:** §4 UI palette (no red health bars), §7.5 health bar.

**Status:** Needed

## ASSET-015 — Icon set 12x12 (HUD)

| Field | Value |
|-------|-------|
| Category | UI |
| Dimensions | Each icon 12x12 art-px (24 px at 720p); one sheet, 1 px gutter |
| Format | `.png` RGBA 8-bit, Lossless, Nearest |
| Naming | `assets/art/ui/ui_icons_12.png` (+ `.json` index of names) |
| Slice | 1 |

**Icons (21):** pause, low-HP "!", check ✓, cross ✗, rotate, armor (shield), Burn, Fragile, Chill, Frozen, cloud (shroud), Odd sparkle, plus (empty slot), info ⓘ, Engraving/Awakening (2x2 squares, one lit), d-pad arrow up/down/left/right, gold coin, heart.

**Description:** Stroke 2 art-px, flat single signal colour + one Ivory highlight pixel top-left; only squares and 45° steps, no curves, no glow; 1 art-px ink outline only for icons placed on the world (chips, ✓/✗). Each status icon has a different shape (flame, crack, plus-snowflake, ice cube). Cancel has no icon (text only); broken block uses the word "HỎNG" / "BROKEN", not ✗.

**Art Bible Anchors:** §3 UI (12x12 grid, distinct shapes), §4 signal colours, §7.4 icon rules, §8.3.

**Generation Prompt:**
```
Pixel art icon sheet, 21 icons of 12x12 pixels each on transparent background, built only from square pixels and 45-degree steps, 2-pixel strokes, one flat colour each plus a single light pixel highlight: pause bars, exclamation mark, check mark, cross, rotate arrow made of steps, square shield, stepped flame (orange #FF7A1F), crack (ivory with dark line), plus-shaped snowflake (#3A5CF0), ice cube (#A6EEFF), cloud, plus-shaped sparkle (magenta #E04CD0), plus sign, info "i", 2x2 squares with one lit (gold #FFD45C), four arrows, coin, heart. No curves, no glow, no anti-aliasing, no text.
```

**Status:** Needed

## Inventory rows covered here
Steel block (ASSET-008), Spell VFX: Slash (ASSET-009), Hit flash (ASSET-010), Cast target tile (ASSET-011), Telegraph tile (ASSET-012), UI frame: Panel/Button/Slot/Bar (ASSET-013, one asset with four files), Health bar skins (ASSET-014), Icon set 12x12 (ASSET-015).
