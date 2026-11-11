# Master Reference — Ancient Root Sentinel (elite) (`ancient_root_sentinel`)

> One file per character (P1, 2026-11-11). Facts come from the registry entry `unit.ancient_root_sentinel`, `art_src/units/ancient_root_sentinel/clips.json`, the sheet JSON and the spec; every claim names its source. **Approval lives in the registry** (`asset_registry.py show unit.ancient_root_sentinel`); this file explains the character so new generations stay consistent. Unknown = no record exists; do not fill it from memory.

## 1. Identity

| Field | Value |
|---|---|
| Registry id / legacy id | `unit.ancient_root_sentinel` / ASSET-024 |
| Type / tier | unit / elite |
| Role | Enemy — elite tier, Misty Forest (stunned clip for the stunned pattern brain) |
| Spec | `design/assets/specs/misty-forest-roster-assets.md` |
| Design (approved text) | Tall twisted root trunk, blocky square moss canopy, long root arms to the ground, eye slits, 2–3 ivory 2x2 scales (ASSET-024 row). v2 regenerated 'about 68 px tall' so elites read bigger than normals (user: 'quái có cấp bậc càng cao thì càng to'). |
| Silhouette / proportions | Tree-like guardian with a cubic canopy; v2 69 px tall south-west (v1 54). |
| Likeness check | Closest: an Ent / Groot. Differences: cubic canopy, no beard or human face. |

## 2. Approved references and anchor

| Field | Value |
|---|---|
| Concept reference | none (text design, phase2-misty-forest quick spec §8) |
| Anchor image (canonical frame) | `art_src/units/ancient_root_sentinel/idle/0.png` — idle frame 0 of the installed source; every new clip is generated from this frame or from the PixelLab character below |
| Rotation set | `design/assets/candidates/root-sentinel/rot-v2`, `design/assets/candidates/root-sentinel/anim-v2`, `design/assets/candidates/root-sentinel/clean-80x80` |
| Anchor approval | **approved** — art_src/units/ancient_root_sentinel/clips.json source: "v2, elite size, approved 2026-11-02" |

## 3. Facing and frame

| Field | Value |
|---|---|
| Sheet facing | left (`clips.json` facing; the engine flips by negative width for the other side) |
| PixelLab view / direction | low top-down / south-west |
| Frame | 80x80 art px |
| Anchor rule | feet on the last pixel row, feet x = 40; ≥ 1 transparent px left / right / top (`export_sheets.py` refuses otherwise) |
| Sheet | `assets/art/units/unit_ancient_root_sentinel_sheet.png` 485x485, one row per clip, 1 px gutter, Aseprite-array JSON |

## 4. Palette constraints

- Locked at generation: Ink; root #4A3A2A / #8A7350 / #B89A6A; moss #3A4538 / #4A5545 / #5E6B55; scales #EFE6D2.
- In the installed sheet (`meta.tessera.palette`, 8 colours): `#1B1722`, `#3A4538`, `#4A3A2A`, `#4A5545`, `#5E6B55`, `#8A7350`, `#B89A6A`, `#EFE6D2`
- Master: `art_src/palette/tessera_master.gpl`; ≤ 8 colours per unit; alpha 0 / 255 only; no red `#E5293B` (telegraph), no orange baked in (Burn); adding a colour is the art-director's call (bible §8.4).

## 5. PixelLab configuration and style reference

| Field | Value |
|---|---|
| Character id | fd080ea7-32d9-40e8-b1cc-64416bb1de38 |
| Image / job ids on record | — |
| Configuration that produced the anchor and clips | v2: create_character_pro_flash 80x80, low top-down, 8 directions, seed 1, palette locked (max 8), style_image = Goblin v3 south rotation, 'about 68 px tall'; clips animate_character pixminimax south-west, 8 frames (6 gen). |
| Style reference (style_image lineage) | Goblin Scout v3 south rotation. |
| Post-generation (free, mechanical only) | palette snap to the locked colours, specks < 12 px removed, feet re-planted on the last row, body recentred; region recolour when the model drifted (Knight cape); never hand-painted detail (user rule) |

## 6. Animation contract

Required for a elite (art bible §5.4 / §8.6): `idle`, `step`, `windup`, `hit`, `down`.
Optional clips the code plays when present (fallback otherwise): `brace`, `guard`, `stunned`, `howl`.

| Clip | Frames | ms per frame | Loop | Status | Acceptance | Generation | Note |
|---|---|---|---|---|---|---|---|
| `idle` | 4 | 250 | loop | installed | unknown | — |  |
| `step` | 4 | 100 | loop | installed | unknown | — | nominal; the game paces step by the step cooldown |
| `windup` | 4 | 100, 100, 100, 0 | hold_last | installed | unknown | — |  |
| `stunned` | 4 | 200 | loop | installed | unknown | — | src 4-7 (slumped; 1-3 had baked yellow stars) |
| `hit` | 3 | 40 | once | installed | unknown | — | src 5-7 (1-4 had baked bursts) |
| `down` | 6 | 100, 120, 150, 150, 150, 150 | hold_last | installed | unknown | — |  |

Timing rules: `idle` 125 ms (heroes) / 250–300 ms (enemies) per frame today (bible §8.6 says 0.4 s — the installed timing is the user's accepted feel); `step` is nominal, the game paces it by the step cooldown; `windup` ends on a 0 ms frame held until the telegraph ends; hero casts share the Knight's 9-slot timing 83, 83, 83, 83, 200 (hold frame 4), 50, 83, 100, 133 with the release on frame 5.

## 7. Visual constraints (what a new generation must keep)

- Same anchor: generate from `art_src/units/ancient_root_sentinel/idle/0.png` (or the character id) with the first frame pinned; for one-shot clips pin the last frame too.
- Same canvas 80x80, same feet row and feet x; the exporter bottom-aligns shorter sources, never taller ones.
- Identity in the upper half: Tree-like guardian with a cubic canopy; v2 69 px tall south-west (v1 54).
- 1 px closed Ink outline; banded shading, light from the upper left; no glow, no smooth gradients, no anti-aliasing fringe (ART_QA_CHECKLIST §B–§D).
- Facing stays left in every frame (the model sometimes turns the back from frame 4: drop those frames, as for the Witch's step_up).
- Effects (bursts, stars, slash smears, red sprays) are never part of the body: delete or drop the frame; VFX are separate packs.
- Allowed variation: pose, cloth / hair / tendril sway, breathing 1–2 px, held weapon angle; not allowed: palette drift, proportions, props disappearing, new accessories.

## 8. Generation lineage

- 2026-11-02 v1 anchor 64x64 → character fe4c307a (6 gen) — superseded (54 px, read as a normal)
- 2026-11-02 v2 anchor 80x80 → character fd080ea7 (6 gen) — APPROVED elite size
- 2026-11-02 v2 6 clips (6 gen) → clean-80x80 → sheet

## 9. Versions

- **Current:** v2 80x80 elite size
- **Retired:**
  - v1 64x64 — paths `design/assets/candidates/root-sentinel/clean-64x64`, `design/assets/candidates/root-sentinel/anim`, `design/assets/candidates/root-sentinel/rot` — design/assets/specs/misty-forest-roster-assets.md §"Elites v2 — bigger by tier (2026-11-02)"
- **Rejected:**
  - v1 64x64 body (character fe4c307a): 'still read as normals' (misty-forest-roster-assets.md §Elites v2)

## 10. Approval history (from the registry)

| Date | Event | Target | By | Evidence / note |
|---|---|---|---|---|
| 2026-11-11 | registered | asset | — | bootstrapped from disk by asset_registry.py; status by location only |
| 2026-11-02 | user_approved installed→approved | asset | user | art_src/units/ancient_root_sentinel/clips.json source: "v2, elite size, approved 2026-11-02" |
| 2026-11-11 | note | asset | — | Master Reference created: design/assets/references/characters/ancient_root_sentinel.md |

## 11. Open points

- stunned: the model kept the idle pose and drew yellow stars; frames 4–7 (slumped) kept

Evidence folders: `production/qa/evidence/misty-forest-roster`, `production/qa/evidence/misty-forest-roster-v2`
