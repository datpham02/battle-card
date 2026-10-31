# Asset Specs — System: Slice 1 combat visuals and UI

> **Source**: design/assets/entity-inventory.md (Slice 1 rows: Steel block, Spell VFX: Slash, Hit flash, Cast target tile, Telegraph tile, UI frames, Health bar skins, Icon set), design/ux/hud.md
> **Art Bible**: design/art/art-bible.md (§3, §4, §7, §8)
> **Generated**: 2026-10-29
> **Status**: 15 assets specced / 0 approved / 11 in production (008, 009, 011, 012, 013, 015, 016 script-drawn; 017, 018, 020 VFX-workbench loops; 019 script) / 0 done — 010 and 014 are code, no drawn art
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

**Production log** (script, 0 generations — pixel-exact tiles, see `design/assets/candidates/slice1-fx/scripts/draw_fx.py`):

| # | Date | What | Gen | Result |
|---|---|---|---|---|
| script-01 | 2026-10-31 | `steel16`: body #8FA3B8, light 1 px top + left #EEF4FA (wins both corners it touches), dark 1 px bottom + right #5F6F82, no outline; `steel5`: body + one light px top-left + one dark px bottom-right. Written as the 7-column sheets of the spec (`block_tiles_16.png` 112x16, `block_tiles_5.png` 35x5) with **only column 0 (steel) filled**; `ASSET-008-block_tiles.json` records the column order | 0 | Kept: `candidates/slice1-fx/ASSET-008-block_tiles_16.png`, `_5.png`, `.json`; previews `preview-steel-x8.png`, `preview-steel5-x8.png` |
| check-01 | 2026-10-31 | art-check `--fx` (evidence `38-fx-layout-v2-5x5.png`, zoom `39-fx-zoom-x3.png`): a lying T of four 5x5 tiles with a 1 px Ink halo, 2 px hover and a square shadow on a 49x35 slab; a falling 16x16 domino with the halo over the enemy half | 0 | Both read at 2x; the 5 px mark (one light, one dark pixel) is visible on the lying block. The halo colour (Ink here) and the hover/shadow are code decisions (spec §3), not part of the PNG |

**Status:** In Progress (candidate; other 6 columns pending their heroes / the enemy block)

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

**Production log** (script, 0 generations — the streak is a fixed 45° staircase, see `draw_fx.py`):

| # | Date | What | Gen | Result |
|---|---|---|---|---|
| script-01 | 2026-10-31 | 4 frames 38x27 in one sheet with a 1 px gutter (155x27). Path: 11 squares of 2x2 on a 45° line from (6,3) to (27,24). Frames: f1 squares 0–2 lit; f2 3–6 lit, 1–2 body, 0 dust; f3 7–10 lit, 5–6 body, 3–4 dust; f4 9–10 body, 6–8 dust. Lit square = light #FFFFFF with a 1 px body #9A9A9A outline (§3: "ô vuông màu phần sáng, viền 1 px màu thân"), dust = one body pixel. Timings in `ASSET-009-vfx_slash_sheet.json`: 50/60/60/60 ms = 0.23 s (≤ 0.25); Reduced motion = f4 held 0.15 s. Ink grey is reserved in the palette but unused by this streak | 0 | Kept: `candidates/slice1-fx/ASSET-009-vfx_slash_sheet.png` + `.json`; preview `preview-slash-x4.png` |
| check-01 | 2026-10-31 | art-check `--fx`: frame 3 drawn centred on the two target tiles with `modulate` = steel highlight #EEF4FA (evidence 38/39) | 0 | Reads as a diagonal cut across the tile, no curve, inside the cell. **Thin**: 2x2 squares are 4 px on screen; open for the art-director whether the leading squares may be 3x3 (§3 fixes 2x2). Motion not yet played in the scene (frames only) |
| script-02 | 2026-10-31 | User: "thicker". Path extended to 13 squares (4,1)→(28,25); every lit square is now **3x3 at 2 px steps**, so neighbours overlap 1 px into one solid stepped band ~3 px wide, with one 1 px body outline around the whole band (outline pass, then fills). Trail = 2x2 body squares, then 1 px dust. Frames: f1 0–3; f2 4–8 lit, 2–3 body, 0–1 dust; f3 9–12 lit, 7–8 body, 4–6 dust; f4 11–12 body, 7–10 dust | 0 | Replaces script-01 in the same files. **Deviation from §3 "ô vuông 2x2"**: the lit band is 3 px; the trail keeps 2x2. Art bible §3 VFX row to be updated if the art-director accepts |
| check-02 | 2026-10-31 | art-check `--fx` re-run (evidence 38/39 overwritten) | 0 | Frame 3 reads as one solid diagonal cut across the 49x35 tile, still inside the cell and still square-only. The thin-streak concern is closed |
| check-03 | 2026-10-31 | art-check `--seq=slash`: the whole cast sequence as 13 keyframes (`anim/seq-slash.gif`, `.sheet.png`): target ramp 35 → 100 %, cast A 0.08 s / B 0.12 s, steel domino falls in 3 keyframes, slash f1–f4 at 50/60/60/60 ms on both tiles above the landed block, goblin `hit` on f2–f3 with the Ivory flash on f2, rest | 0 | The rhythm reads: the hero's swing lands before the block, the cut is visible on the goblin and on the block. Not covered: the block's dissolve / engraving after the hit, the countdown ramp of the real channel time |

**Status:** In Progress (candidate)

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

**Production log** (script, 0 generations — masks, see `draw_fx.py`):

| # | Date | What | Gen | Result |
|---|---|---|---|---|
| script-01 | 2026-10-31 | 5 white masks 16x16 in `fx_material_marks_16.png` (80x16): **bevel** (top + left alpha 255, bottom + right alpha 128 — two levels so the shader can tint highlight / shadow), **crack** (1 px stepped diagonal with a kink and two 1 px splinters), **clipped** (1 px frame, top-right and bottom-left corners cut 3 px at 45°), **rope** (1 px frame + 1 px line on row 8 with four knot pixels), **lead** (2 px cross splitting the tile 2x2, no frame). `ASSET-011-fx_material_marks_16.json` gives each mark's rect and how it scales to the cell: `nine_slice` with margins (bevel 1, clipped 4, rope 1/7, lead 7) or `center` (crack — a stretched diagonal would break its steps) | 0 | Kept: `candidates/slice1-fx/ASSET-011-fx_material_marks_16.png` + `.json`; preview `preview-marks-x8.png` |
| check-01 | 2026-10-31 | art-check `--fx`: steel body #8FA3B8 at 60 % on two target tiles, raised edge (highlight top-left, shadow bottom-right) by code, bevel mask nine-sliced to the face minus 2 px, tinted #EEF4FA; intensity 70 % under the goblin, 100 % on the tile below (evidence 38/39) | 0 | Reads as a raised steel tile, distinct from the red telegraph; the slab stays visible through the 60 % fill. Only steel is checked in-game (slice 1 has one hero); the four other masks are checked on the x8 preview only |
| check-02 | 2026-10-31 | **User rule: when a piece is dragged or cast, only the tiles light up; no block sprite travels onto the board.** The falling domino was removed from the fx demo and from the `--seq` cast sequence (now: tiles ramp → cast A/B → VFX → hit), `anim/seq-slash-v2.gif` | 0 | Matches art bible §3 "không vẽ khối lên sân" for the drag; the "Khối rơi" state of ASSET-008 remains for blocks lying on the floor to pick up, not for casts |

**Status:** In Progress (candidate; shader `floor_fx` is code)

## ASSET-012 — Telegraph tile

| Field | Value |
|-------|-------|
| Category | VFX (floor overlay) |
| Dimensions | Code-drawn at cell size; fallback stripe texture 8x8 |
| Format | `floor_fx` shader (stripes by `floor(pixel)`), fallback `assets/art/vfx/fx_telegraph_stripe_8.png` |
| Naming | `assets/art/vfx/fx_telegraph_stripe_8.png` |
| Slice | 1 |

**Description:** Incoming-attack cell on the player's half: red #E5293B fill with 45° diagonal stripes, a 2 px red outline with a 1 art-px ink edge outside — **all on the floor layer, under units** (changed 2026-10-31; the outline was on the overlay). **No countdown label**: the tile carries an `intensity` 0 → 1 over the enemy's cast time and the hit lands at 1 — stripes alpha 0.5 → 1, flat fill 0 → 0.45, outline 0.3 → 1 (art-check `--tele-k`, evidence `61-telegraph-ramp-0-50-100.png`); Reduced motion: three discrete steps. Red is used nowhere else.

**Art Bible Anchors:** §1 P3 (red reserved), §4 (telegraph signal row), §7.4 (ink edge, label on ink plate), §8.6 (layer order).

**Production log** (script, 0 generations, see `draw_fx.py`):

| # | Date | What | Gen | Result |
|---|---|---|---|---|
| script-01 | 2026-10-31 | 8x8 tile: pixels with (x + y) mod 4 < 2 are #E5293B at alpha 255, the rest #E5293B at alpha 110, so one texture gives fill + 45° stripes and tiles seamlessly (period 4 divides 8) | 0 | Kept: `candidates/slice1-fx/ASSET-012-fx_telegraph_stripe_8.png`; preview `preview-stripe-x8.png` |
| check-01 | 2026-10-31 | art-check `--fx`: tiled over the hero's slab face and the one below (floor layer), 2 px red frame with a 1 px Ink edge outside on the overlay layer above the units (evidence 38/39) | 0 | Reads from across the board; with the Swordsman standing on the cell the stripes stay visible above and on both sides of the body (art bible §1 note, passes for this hero). Countdown label on an Ink plate not mocked |
| check-02 | 2026-10-31 | **User rule: nothing on a tile may cover the unit standing on it.** The 2 px red frame + Ink edge moved from the overlay layer to the floor layer (under units) in art-check; the HP plates under the feet were dropped (the HUD bars carry HP); keyword chips sit centred under the feet. Evidence `58-bg-v2-5x5.png`, zoom `60-units-on-tiles-zoom-x3.png` | 0 | The hero stands clear on the red tile. This reverses the art bible §1 "hệ quả kỹ thuật" line that put the frame above units (2026-10-28) — wording change proposed, see active.md. The countdown label stays on the HUD layer above everything |

**Status:** In Progress (candidate; shader stripes are code, this is the fallback texture)

## ASSET-013 — UI frames (Panel, Button, Slot, Bar)

| Field | Value |
|-------|-------|
| Category | UI |
| Dimensions | Panel and Button: 9-slice source 16x16, margins 4/4/4/6. Button: 3 states (default with 2 art-px bottom lip, pressed without lip, disabled). Slot: 9-slice 16x16, margin 3, recessed. Bar: 3-slice **16x6** (was 16x8; changed 2026-10-31 so the bar is 12 px tall at x2, §7.5), ends 2, border 1. Drawn at x2 art-px on the 1280x720 HUD layer |
| Format | `.png` RGBA 8-bit, Lossless, Nearest; integer art-px stretch only |
| Naming | `assets/art/ui/ui_frame_panel_9slice.png`, `ui_frame_button_9slice.png` (3 states in a row), `ui_frame_slot_9slice.png`, `ui_frame_bar_3slice.png` |
| Slice | 1 |

**Description:** Square corners notched by 1 art-px, no rounded corners, no pills, no glow. Panel fill #1E1B24 at 90 %, border Mist #7D8896 1 art-px (>= 3:1), bottom lip ink. Slot: recessed (top-left ink, bottom-right #4A4652), outer border Mist. Bar groove ink at 90 %. Touch targets are separate invisible rects (>= 88 px, primary >= 96 px).

**Art Bible Anchors:** §3 UI shape grammar, §4 UI palette, §7.4 frame system and contrast fixes, §8.3 UI 9-slice.

**Generation Prompt:**
```
Pixel art UI kit, four small frames on transparent background: 1) a dark panel 16x16 with square corners notched by one pixel, 1-pixel grey-blue border (#7D8896), fill #1E1B24, darker 2-pixel bottom lip; 2) the same as a button in three states (raised, pressed without lip, disabled faded); 3) a recessed slot with dark top-left and lighter bottom-right edges; 4) a thin horizontal bar frame 16x8 with a dark groove. Crisp pixels, flat colours, no rounded corners, no glow, no text.
```

**Production log** (script, 0 generations — frames need exact pixels, see `design/assets/candidates/slice1-ui/scripts/draw_ui.py`):

| # | Date | What | Gen | Result |
|---|---|---|---|---|
| script-01 | 2026-10-31 | Panel 16x16: Mist #7D8896 frame with 1 px notched corners, fill #1E1B24 at 90 % (alpha 230), **2 art-px Ink lip hanging below the frame** (frame rows 0–13, lip rows 14–15 inset 1 px). Button 48x16 = default (lip), pressed (no lip), disabled (fill alpha 150, frame #4A4652). Slot 16x16: Mist outer frame, recessed inner edge (Ink top-left, #4A4652 bottom-right), fill #15131A. Bar 16x8: Mist frame 1, Ink groove at 90 %, ends 2. Margins in `ASSET-015-ui_icons_12.json` → `nine_slice` (panel / button 4,4,4,6; slot 3; bar ends 2) | 0 | Kept: `candidates/slice1-ui/ASSET-013-ui_frame_{panel,button,slot}_9slice.png`, `ui_frame_bar_3slice.png`; previews `preview-{panel,button,slot,bar}-x8.png` |
| check-01 | 2026-10-31 | art-check `--ui` draws the frames with a 9-slice at x2 on the HUD layer: 130x93 arc slots and 97 px pad / 115 px Awaken buttons, 32x32 pause panel, 435x16 bars (evidence `35-ui-layout-v2-5x5.png`, `36-ui-layout-v1-5x5.png`, zoom `37-ui-frames-zoom-x3.png`) | 0 | Corners keep the notch, edges stay 2 px, no seams at any size. **Deviation from the spec wording**: the first draft put the Ink lip inside the fill (spec: "bottom lip ink") and it vanished — Ink #1B1722 on #1E1B24 is one value step; moved below the Mist border, where it reads as a raised edge against the backdrop. Proposed art bible §7.4 wording: "mép dưới Mực 2 art-px nhô dưới viền" |
| script-02 | 2026-10-31 | Bar source 16x8 → **16x6** (border 1, groove 4 art-px, ends 2) so the bar is 12 px tall at x2 as §7.5 asks; the fills stay code at screen pixels inside the 8 px groove (§7.4: bars are drawn sharp at 1280x720). `ASSET-015-ui_icons_12.json` → `nine_slice.bar_source` [16, 6] | 0 | Replaces the bar file; evidence 35/36/37 re-captured. The §7.5 vs spec "16x8" mismatch is closed in favour of §7.5; this spec's Dimensions row should read "Bar: 3-slice 16x6" |

**Status:** In Progress (candidate; art-director to confirm the lip placement)

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

**Note (2026-10-31):** no drawn art. The art-check `--ui` mock draws the fills in code on the ASSET-013 bar (player #4CBF59 at 85 % with a #B8B0A0 trail to 93 %, boss Ivory with the 2 px Ivory half-life notch sticking out 3 px) — evidence 35/36. Closed 2026-10-31: the bar source is now 6 art-px (ASSET-013 script-02), so the frame is 12 px tall at x2 and the fills draw at screen pixels inside the 8 px groove.

**Status:** Needed (code)

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

**Production log** (script, 0 generations — 12x12 glyphs on the grid, see `draw_ui.py`):

| # | Date | What | Gen | Result |
|---|---|---|---|---|
| script-01 | 2026-10-31 | 21 icons in a 7x3 grid, 1 px gutter (90x38) + `ASSET-015-ui_icons_12.json` (name → rect). 2 px strokes, squares and 45° steps only, one flat colour + one Ivory highlight pixel (top-left-most opaque pixel), 1 px Ink outline only on check and cross. Colours: Ivory glyphs; armor #8FA3B8; burn #FF7A1F; chill #3A5CF0; frozen #A6EEFF with a #3A5CF0 edge; cloud and plus Mist #7D8896; odd #E04CD0; awakening = three Mist squares + one gold #FFD45C; coin #FFD45C with an Ink slot. Rotate redrawn once (v1 unreadable): a 2 px ring open at the top-left, capped by a stepped arrowhead | 0 | Kept: `candidates/slice1-ui/ASSET-015-ui_icons_12.png` + `.json`; preview `preview-icons-x8.png` |
| check-01 | 2026-10-31 | preview x8 and art-check `--ui` (pause on the panel, plus in the slots, awakening x4 on the Awaken button, the four arrows x4 on the v1 pads; evidence 35–37) | 0 | Every status icon has its own shape (flame / cracked tile / plus-snowflake / ice cube); the gold square of the awakening icon reads at 24 and 48 px. Open: §7.5 asks for 28 px pad arrows, the 12x12 grid gives 24 or 48 px (48 used on the 97 px pads); the §7.4 blackout test of the sheet is not done |
| gen-01 | 2026-10-31 | **Direction change** (user: the pixel set is "thô", wants One Step From Eden's design language). Pixen 256x256, no background, "4x4 grid of 16 icons on dark navy rounded tiles, thick dark outline, soft inner glow, one saturated colour per glyph", seeds 11 and 42 | 2 | Seed 11 (job f78b137b) kept: navy tiles 55x55 at a 61 px pitch, 21 colours, every glyph readable; the cross was missing (a second rotate) so it is drawn by script on a copy of the pause tile. Seed 42 (job 43cadc3a) rejected: white tiles. Assembled as `candidates/slice1-ui/osfe-icons/ASSET-015-osfe-icons_55.png` (4x4, 1 px gutter) + `.json`; raw sheets kept beside it |
| check-02 | 2026-10-31 | art-check `--skin=osfe --icons=…` (evidence `46-skin-osfe-icons.png`): pause + info at 1:1 (55 px) top centre, Cháy/Rạn chips at 0.5 beside the goblin's HP plate, the Awakening glyph inside the diamond | 0 | Reads as one family with the sharp-UI skin; the glow and tile make the glyphs sit on any backdrop. Open: chips at 0.5 lose pixels (a 28 px chip variant needs its own gen or a 1:1 chip), icons not yet palette-locked, the 12x12 pixel set stays as the placeholder for the pixel-layer path |

**Status:** In Progress (two candidate sets: 12x12 pixel-grid set and the 55 px OSFE-style set; direction decision pending)

## ASSET-016 — Spell VFX: Push

| Field | Value |
|-------|-------|
| Category | VFX |
| Dimensions | 4 frames, each 38x27 art-px (the smallest cell); centred, never scaled, on larger cells; total <= 0.3 s |
| Format | `.png` sheet RGBA 8-bit in the same three greys as ASSET-009 (light / body / ink), tinted in code with the hero's block colour via `modulate` |
| Naming | `assets/art/vfx/vfx_push_sheet.png` (+ `.json` frame timings) |
| Slice | 1 — added 2026-10-31: Chấn phong (Push group) is in the Swordsman's starter deck, so slice 1 needs two VFX groups, not one |

**Visual Description (art bible §3, "Đẩy"):** a column of squares standing at the left edge of each target tile slides right half a tile and thins out; no beam, no burst. Reduced motion: only the last frame, held 0.15 s.

**Art Bible Anchors:** §1 P1 (squares only), §3 VFX table (Đẩy: Hích nhẹ, Xô lùi, Cú húc, Sạt lở; Chấn phong by game-mechanics §3), §8.3 (3 greys, code tint).

**Production log** (script, 0 generations, see `design/assets/candidates/slice1-fx/scripts/draw_fx.py`):

| # | Date | What | Gen | Result |
|---|---|---|---|---|
| script-01 | 2026-10-31 | Five 3x3 light squares stacked 1 px apart (rows 1–21) with one body outline around the column, the same band language as the slash v2. Frames: f1 column at x 2; f2 at x 8 with two dust px behind; f3 at x 14, three squares, more dust; f4 at x 19 (half a tile), two 2x2 body squares, dust. Timings 60/80/80/80 ms = 0.3 s; Reduced motion = f4 held 0.15 s | 0 | Kept: `candidates/slice1-fx/ASSET-016-vfx_push_sheet.png` (155x27) + `.json`; preview `preview-push-x4.png` |
| check-01 | 2026-10-31 | art-check `--seq=push`: the full cast sequence on the board (`anim/seq-push.gif`, `.sheet.png`), push frames tinted steel on both target tiles, drawn above the landed block | 0 | Reads as a shove from left to right across the tile and thins out as §3 asks; distinct from the slash by shape and direction alone (same colour). Passes the look check |

**Status:** In Progress (candidate)

## ASSET-017 — Status overlay: Burning · ASSET-018 — Frozen · ASSET-019 — Fragile · ASSET-020 — Chill

| Field | Value |
|-------|-------|
| Category | VFX (status overlay on the unit; art bible §5.4 "không vẽ khung", §4 status colours) |
| Dimensions | Drawn around the unit canvas (32x48 monsters, 40x48 heroes); loops |
| Format | Spritesheet PNG + Aseprite-format JSON per effect, or the game-pack pieces (behind / in front of the sprite) |
| Naming | `assets/art/vfx/fx_status_burn_sheet.png`, `fx_status_frozen_sheet.png`, `fx_status_fragile_<W>x48.png`, `fx_status_chill_sheet.png` |
| Slice | 1 (user 2026-10-31: "làm thêm một số animation cho hiệu ứng đó gắn rồi apply vào char") |

**Production log:**

| # | Date | What | Gen | Result |
|---|---|---|---|---|
| script-01 | 2026-10-31 | `scripts/draw_status.py`: burn 2 frames of stacked 2x2 squares (two sizes), frozen 2 px shell with icicles, fragile 3 stepped Ink cracks with Ivory beside, chill 8x8 plus snowflake; art-check `--status` and `--seq=status` (evidence `65-status-overlays-and-chips.png`, `66-status-zoom.png`, `anim/status-overlays.gif`) | 0 | Functional but crude (user: use PixelLab where the hand version is weak). Kept as the fallback; fragile stays script (no workbench part for cracks on ivory) |
| vfx-01 | 2026-10-31 | PixelLab **VFX workbench** (free) around the goblin idle frame: `on_fire` (colours #FF7A1F / #FFB21F / Ivory, size 0.6, amount 0.6), `freeze_status` (#A6EEFF / #3A5CF0 / #FFFFFF, size 0.7, amount 0.7), `snowfall` at the head (#3A5CF0 / #A6EEFF, size 0.5, amount 0.5) | 0 | Exported to the user's My effects: Burn `7dda0f74…` (27x38, 12 f @ 12 fps), Frozen `d34834ba…` (28x40, 12 f @ 10 fps), Chill `1d53478e…` (51x60, 16 f @ 12 fps); files in `candidates/slice1-fx/status-vfx/` (GIF + sheet + JSON each). The sheets include the goblin; the effect alone comes from a `--game-pack` export (behind / front pieces) once the look is approved. Open: the hero size (40x48) needs the same effects around the Swordsman frame; palette check against §4 (the parts add a few intermediate tones); reduce-motion = hold frame 1 |

| vfx-02 | 2026-10-31 | User approved the look. **Game-pack exports** (effect alone: `behind.png`, `front.png`, `whole.png`, `part-*.png`, `manifest.json` with frame size, columns, offset from the feet anchor, frame_ms) for the goblin set (replacing effects 7dda0f74 / d34834ba / 1d53478e) and a **hero set** built around the Swordsman 40x48 frame with the same parts and colours (Burn `6e0c80cb…` 33x52 @ 12 fps, Frozen `f98b7179…` 33x54 @ 10 fps, Chill `d6085e0b…` 51x74 @ 12 fps). Folders `status-vfx/pack-tessera-status-<burn|frozen|chill>-<goblin|hero>/` | 0 | Pieces are palette-clean: alpha 255 only, 2–3 colours each (burn #FF7A1F / #FFB21F / Ivory; frozen #A6EEFF / #FFFFFF; chill #3A5CF0 / #A6EEFF). **The cold tint and the hot rim are not in the pieces** — they are sprite recolours the workbench did on its preview; in the game they come from `unit_fx` (art bible §8.5), the pieces give the flames, crystals and flakes. art-check `--status-pack` draws `behind` under the unit and `front` over it by the manifest (evidence `67-status-pack-burn-chill.png`, `68-status-pack-frozen.png`, `69-status-pack-zoom-x4.png`) |

**Status:** In Progress (candidates approved by the user for look; export to `assets/art/vfx/` and the `unit_fx` tint are the UI/VFX story's work)

## Inventory rows covered here
Steel block (ASSET-008), Spell VFX: Slash (ASSET-009), Spell VFX: Push (ASSET-016, slice 1 since 2026-10-31), Hit flash (ASSET-010), Cast target tile (ASSET-011), Telegraph tile (ASSET-012), UI frame: Panel/Button/Slot/Bar (ASSET-013, one asset with four files), Health bar skins (ASSET-014), Icon set 12x12 (ASSET-015).
