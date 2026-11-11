# Master Reference — Goblin Scout (`goblin_scout`)

> One file per character (P1, 2026-11-11). Facts come from the registry entry `unit.goblin_scout`, `art_src/units/goblin_scout/clips.json`, the sheet JSON and the spec; every claim names its source. **Approval lives in the registry** (`asset_registry.py show unit.goblin_scout`); this file explains the character so new generations stay consistent. Unknown = no record exists; do not fill it from memory.

## 1. Identity

| Field | Value |
|---|---|
| Registry id / legacy id | `unit.goblin_scout` / ASSET-003 |
| Type / tier | unit / monster |
| Role | Enemy — normal tier, Misty Forest; base body of the goblin species (archer / shaman variants per bible §5.6) |
| Spec | `design/assets/specs/goblin-scout-assets.md` |
| Design (approved text) | Small goblin facing left, low centre of gravity, long ears sticking out sideways (species mark, upper half), desaturated olive-green skin, ragged hooded leather jerkin, short knife at the belt, eyes 2x2 pale pixels in a dark face; no block accent colour (goblin-scout-assets.md Visual Description). v3 = OSFE scale, ~70 % of the Knight. |
| Silhouette / proportions | Hunched scout, visible 26x46 px south-west (goblin-scout-assets.md:85); feet x = 32 on a 64x52 frame. |
| Likeness check | Closest known look is a generic hooded D&D goblin, no named character (goblin-scout-assets.md:85). |

## 2. Approved references and anchor

| Field | Value |
|---|---|
| Concept reference | design/art/reference/05-battle-01.png and the spec, described in words (goblin-scout-assets.md:85) |
| Anchor image (canonical frame) | `art_src/units/goblin_scout/idle/0.png` — idle frame 0 of the installed source; every new clip is generated from this frame or from the PixelLab character below |
| Rotation set | `design/assets/candidates/goblin-scout/v3`, `design/assets/candidates/goblin-scout/v3/clean-64x52` |
| Anchor approval | **approved** — art_src/units/goblin_scout/clips.json source: "v3 OSFE-scale anchor, approved 2026-10-31"; design/assets/specs/goblin-scout-assets.md:88 "anchor approved and animated" |

## 3. Facing and frame

| Field | Value |
|---|---|
| Sheet facing | left (`clips.json` facing; the engine flips by negative width for the other side) |
| PixelLab view / direction | low top-down / south-west |
| Frame | 64x52 art px |
| Anchor rule | feet on the last pixel row, feet x = 32; ≥ 1 transparent px left / right / top (`export_sheets.py` refuses otherwise) |
| Sheet | `assets/art/units/unit_goblin_scout_sheet.png` 519x264, one row per clip, 1 px gutter, Aseprite-array JSON |

## 4. Palette constraints

- Locked at generation: Ink #1B1722; skin #7D8B5A / #59643F; leather #9A7D5E / #66523F; hood #8FA070; eyes #EFE6D2 (7 colours; goblin-scout-assets.md palette table + fix-02 recolour for §6.6 legibility).
- In the installed sheet (`meta.tessera.palette`, 7 colours): `#1B1722`, `#59643F`, `#66523F`, `#7D8B5A`, `#8FA070`, `#9A7D5E`, `#EFE6D2`
- Master: `art_src/palette/tessera_master.gpl`; ≤ 8 colours per unit; alpha 0 / 255 only; no red `#E5293B` (telegraph), no orange baked in (Burn); adding a colour is the art-director's call (bible §8.4).

## 5. PixelLab configuration and style reference

| Field | Value |
|---|---|
| Character id | 3b9516c8-2be0-43e2-b505-c58ba6e254c8 |
| Image / job ids on record | — |
| Configuration that produced the anchor and clips | create_character_pro_flash 64x64 (text), low top-down, 8 directions, seed 5, 7-colour palette locked, style_image = Swordsman knight-01 south rotation (outline / shading / detail only, color_palette off) (goblin-scout-assets.md:85). Clips: animate_character pixminimax south-west (idle 4, step 4, windup 4, hit 4, down 8). |
| Style reference (style_image lineage) | Swordsman v3-knight-01 south rotation. The Goblin's own south rotation is the style_image for every later Misty Forest enemy. |
| Post-generation (free, mechanical only) | palette snap to the locked colours, specks < 12 px removed, feet re-planted on the last row, body recentred; region recolour when the model drifted (Knight cape); never hand-painted detail (user rule) |

## 6. Animation contract

Required for a monster (art bible §5.4 / §8.6): `idle`, `step`, `windup`, `hit`, `down`.
Optional clips the code plays when present (fallback otherwise): `brace`, `guard`, `stunned`, `howl`.

| Clip | Frames | ms per frame | Loop | Status | Acceptance | Generation | Note |
|---|---|---|---|---|---|---|---|
| `idle` | 4 | 250 | loop | installed | unknown | — |  |
| `step` | 4 | 100 | loop | installed | unknown | — | nominal; the game paces step by the step cooldown |
| `windup` | 2 | 100, 0 | hold_last | installed | unknown | — | frame 1 is 0 ms: held until the telegraph ends |
| `hit` | 3 | 40 | once | installed | unknown | — |  |
| `down` | 8 | 100 | hold_last | installed | unknown | — |  |

Timing rules: `idle` 125 ms (heroes) / 250–300 ms (enemies) per frame today (bible §8.6 says 0.4 s — the installed timing is the user's accepted feel); `step` is nominal, the game paces it by the step cooldown; `windup` ends on a 0 ms frame held until the telegraph ends; hero casts share the Knight's 9-slot timing 83, 83, 83, 83, 200 (hold frame 4), 50, 83, 100, 133 with the release on frame 5.

## 7. Visual constraints (what a new generation must keep)

- Same anchor: generate from `art_src/units/goblin_scout/idle/0.png` (or the character id) with the first frame pinned; for one-shot clips pin the last frame too.
- Same canvas 64x52, same feet row and feet x; the exporter bottom-aligns shorter sources, never taller ones.
- Identity in the upper half: Hunched scout, visible 26x46 px south-west (goblin-scout-assets.md:85); feet x = 32 on a 64x52 frame.
- 1 px closed Ink outline; banded shading, light from the upper left; no glow, no smooth gradients, no anti-aliasing fringe (ART_QA_CHECKLIST §B–§D).
- Facing stays left in every frame (the model sometimes turns the back from frame 4: drop those frames, as for the Witch's step_up).
- Effects (bursts, stars, slash smears, red sprays) are never part of the body: delete or drop the frame; VFX are separate packs.
- Allowed variation: pose, cloth / hair / tendril sway, breathing 1–2 px, held weapon angle; not allowed: palette drift, proportions, props disappearing, new accessories.

## 8. Generation lineage

- 2026-10-31 v1 32x48 frames (ASSET-003-*) + fix-01/02 recolours — superseded
- 2026-10-31 v3-goblin create_character_pro_flash → character 3b9516c8 (6 gen) — APPROVED anchor
- 2026-10-31 v3-goblin-anim 5 clips (5 gen) → clean-64x52 → sheet (Story 045 export)

## 9. Versions

- **Current:** v3 64x52
- **Retired:**
  - v1 32x48 frames + rotations — paths `design/assets/candidates/goblin-scout/ASSET-003-*.png`, `design/assets/candidates/goblin-scout/pre-legibility-fix` — goblin-scout-assets.md generation log v3 (2026-10-31) supersedes the 32x48 set
- **Rejected:**
  - v1 32x48 set (superseded by v3 scale; kept in candidates/goblin-scout/ and pre-legibility-fix/)

## 10. Approval history (from the registry)

| Date | Event | Target | By | Evidence / note |
|---|---|---|---|---|
| 2026-11-11 | registered | asset | — | bootstrapped from disk by asset_registry.py; status by location only |
| 2026-10-31 | user_approved installed→approved | asset | user | art_src/units/goblin_scout/clips.json source: "v3 OSFE-scale anchor, approved 2026-10-31"; design/assets/specs/goblin-scout-assets.md:88 "anchor approved and animated" |
| 2026-11-11 | note | asset | — | Master Reference created: design/assets/references/characters/goblin_scout.md |

## 11. Open points

- status overlays were sized on the v1 body (goblin-scout-assets.md:88)
- archer / shaman variants are not baked from the v3 body; the Archer got its own character instead (ASSET-026)
- Registry `unit.goblin_scout`: `status` approved (2026-10-31, evidence in §10), `acceptance` unknown. Do not treat status as acceptance.
- `palette_status`: locked. The seven colours in §4 match `unit_goblin_scout_sheet.json` `meta.tessera.palette` and are in `tessera_master.gpl`. `#59643F` is on that sheet. A note in `docs/art/REGION-MATERIALS-AND-PALETTE.md` calls it unused; the sheet wins for this character. Do not drop it from §4.
- Frame 64x52, sheet 519x264: matches `docs/art/RENDER-STANDARDS.md` and the sheet JSON. Outline is the Ink already named in §4.
- Shade steps per material: unknown. Not measured on the sheet.
- Anatomy beyond §1: unknown. Do not add it.

Evidence folders: `production/qa/evidence/goblin-v3`, `production/qa/evidence/unit-sheet-export`, `production/qa/evidence/battle-canvas-art`
