# Skill v2 — Trảm Địa final art production report

**Date:** 2026-11-08 · **Status:** awaiting final visual approval · nothing committed.
**Unchanged:** gameplay, timing, AI, rewards and tests' behaviour; the Mage work is untouched.

## 1. Assets

| Asset | Tool / cost | Result |
|---|---|---|
| Knight `cast_forward` | `animate_image_pixminimax`, job `5e5e14ed-952d-42ec-b517-8bff32bb795e`, seed 1, 8 frames pinned to the guard frame, **1 generation** (user-approved, run once) | 9-slot clip: guard, draw back ×2, coil (held), release low and forward, follow-through ×2, guard. Raw frame f4 dropped (baked slash smear) |
| `impact_eruption_tram_dia` | `vfx_workbench` (free for the subscription, confirmed through `search_help`), effect `d31090ea-…` | overlay pack, 112×112, 7 frames @ 20 fps (0.35 s), anchor `ground_center` (56, 84): white collision core + rays, three jagged steel sword-energy blades tearing up and **forward** (+x), a rising cut, chunk shards; collapse in square blocks |
| `mark_eruption_tram_dia` | `vfx_workbench`, effect `851f40e8-…` | floor pack, 112×112, 12 frames (0.6 s), `ground_center`: a ground shockwave ring (camera tilt 0.7, like the board), three short stepped cracks, settling shards |

**Palette:** the approved ramp `#1B1722 #5F6F82 #8FA3B8 #C8D2DE #EEF4FA #FFFFFF`, dark outline, no dither; no red.

**Timing:** the approved plan said rise 0.05–0.2 s / peak 0.2–0.3 s / collapse 0.3–0.45 s, but also limited the
overlay pack to 7 frames (0.35 s). The rise, peak and collapse were compressed into 0.35 s (peak frame 4); the fade
of the cracks, ring and shards runs on the 0.6 s floor pack.

## 2. Mechanical edits (no hand painting)

- **`tools/qa/sprite_clean.gd`:**
  - palette snap to the 7 Knight sheet colours;
  - specks under 6 px dropped (3 px on f5);
  - whole-frame translation so the feet stay on x32–38: f1 / f2 +5 px, f3 +6, f6 / f7 −1.
- **`tools/qa/sprite_recolour_region.gd`:** the cape colour fix.
  - The interior of gold components of at least 25 px is recoloured `#b8893a` → navy `#34406e`: slots 5 and 6
    only, 54 + 30 px.
  - The 1 px gold rim (the cape's trim) and every armour trim are untouched.
- **Verified** (`tools/qa/sprite_measure.gd`):
  - feet row 69 and feet x32–38 on all 9 slots (slot 5's row-69 span includes the blade tip);
  - 0 off-palette colours;
  - alpha 0 / 255.

## 3. Integration

- **`art_src/units/kiem_si/cast_forward/0–8.png` + `clips.json`:** same 9 ms as `cast_gesture`, so the coil hold and
  release timing are unchanged.
- **Sheet:** `unit_kiem_si_sheet` rebuilt to 872×993.
- **`assets/art/vfx/cast/index.json`, `card_casts.tram_dia`:**

  | Key | Value | Effect |
  |---|---|---|
  | `clip` | `cast_forward` | the clip played for this card |
  | `hand` | (34, −10) | the launch point on the release frame |
  | `charge_hand` | (2, −30) | the charge glint at the hands on the raised coil |
  | `impact` | `impact_eruption_tram_dia` | the burst-cell eruption |
  | `impact_mark` | `mark_eruption_tram_dia` | the burst-cell floor mark |

  Every other Knight card keeps `cast_gesture` and the shared steel burst (tested).
- **`assets/art/vfx/floor/`:** two new pack folders and their two index lines.
- **Code:**
  - `CastVfx.entry_for(unit, impact, skill_id)` merges `card_casts`; `CastVfx.cast_clip`.
  - `UnitLayer` plays the card's cast clip (`cast_clip_for`, `is_cast_clip`).
  - The overlay uses the card's hand and `charge_hand`.
  - `CombatView._on_impact_resolved` passes the card.
- **Removed duplicates:**
  - the code-drawn square-column eruption (no longer drawn; the pure helper stays tested);
  - the burst cell's code shock ring (the floor pack has the ring). A disconnected `landing` keeps its small code ring.
- **Unchanged:** projectile, square-wave travel, surge fronts, cracks, secondary bursts, preview, damage timing and
  all gameplay.

**Direction:** the burst is always the Block cell nearest the Knight (column first), so the surge only ever leaves
it to the right, up or down, never back toward the Knight. The eruption therefore leans forward (+x, the direction
of the incoming wave) and needs no mirroring. The real geometry (turns, T / plus splits) is carried by the code fronts.

## 4. Evidence (`production/qa/evidence/skill-v2-tram-dia-art/`)

**Assets and the cast clip:**
- `impact_eruption_tram_dia_sheet_x3.png`, `mark_eruption_tram_dia_sheet_x3.png` and the two GIFs: the
  spritesheets.
- `cast_forward_raw_x4.png`, `cast_forward_clean_x4.png`, `cape_fix_before_after_x4.png`.
- `cast_forward_ingame_2x-sheet.png`, `cast_forward_ingame_native640-sheet.png`.

**`sequences/`:** continuous deterministic captures (seed 1, Goblin Scout, `rect` arena, `--no-autopause`).
- Straight, L, T and Plus, each as a 2× sheet and a native 640×360 sheet.
- Events logs.
- `tram_dia_bar4_final.avi`.

## 5. Tests

| Check | Result |
|---|---|
| Full suite | 207 files: 206 green on the run; `floor_vfx_test` failed only on its pinned pack list (27 → 29). Added the two ids; it now checks both packs load, have 7 / 12 regions and draw: **207 / 207** |
| Golden 640 legacy cases | pass, fixture untouched |
| `tram_dia_test` | pass (+4 checks: Trảm Địa overrides, other Knight cards unchanged, cast clip, both packs load) |
| Sheet tests | `sheet_export_test` (Knight row `cast_forward`, sheet 872×993) and `sprite_sheet_test` pass; `export_sheets.py --check` ok |

## 6. Remaining limitations

1. The cast_forward wind-up still raises the sword high before the low release (generated pose; accepted).
2. Small gold patches remain near the collar in slots 5–6: thin areas with no interior, kept on purpose.
3. The eruption lean is fixed forward. If a future card bursts on a cell where the surge leaves backward, it would
   need a mirrored pack; this cannot happen with the landing rule.
4. The formation map's gold rings (an existing feature) light the cast cells in the last frames, over the fading
   stamps.
5. **Not verified on a phone.** Captures are desktop 2× and native 640×360 renders.
