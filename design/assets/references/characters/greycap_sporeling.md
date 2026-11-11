# Master Reference — Greycap Sporeling (`greycap_sporeling`)

> One file per character (P1, 2026-11-11). Facts come from the registry entry `unit.greycap_sporeling`, `art_src/units/greycap_sporeling/clips.json`, the sheet JSON and the spec; every claim names its source. **Approval lives in the registry** (`asset_registry.py show unit.greycap_sporeling`); this file explains the character so new generations stay consistent. Unknown = no record exists; do not fill it from memory.

## 1. Identity

| Field | Value |
|---|---|
| Registry id / legacy id | `unit.greycap_sporeling` / ASSET-022 |
| Type / tier | unit / monster |
| Role | Enemy — normal tier, Misty Forest |
| Spec | `design/assets/specs/misty-forest-roster-assets.md` |
| Design (approved text) | Cluster of three dull grey-violet mushrooms on one squat stalk-body, ivory stems, mossy root base, eye slits under the big cap, pale spore dots (misty-forest-roster-assets.md ASSET-022 row). |
| Silhouette / proportions | Big spotted cap over an ivory stem body, two small caps at the sides like arms; 29x47 south-west, 7 colours. |
| Likeness check | Closest: Toad / the Super Mushroom (Mario). Differences: dull grey-violet, three caps, eye slits — flagged and accepted by the user ('Duyệt cả 4'). |

## 2. Approved references and anchor

| Field | Value |
|---|---|
| Concept reference | none (text design, phase2-misty-forest quick spec §8) |
| Anchor image (canonical frame) | `art_src/units/greycap_sporeling/idle/0.png` — idle frame 0 of the installed source; every new clip is generated from this frame or from the PixelLab character below |
| Rotation set | `design/assets/candidates/greycap/anim`, `design/assets/candidates/greycap/clean-64x52` |
| Anchor approval | **approved** — art_src/units/greycap_sporeling/clips.json source: "approved 2026-11-02"; design/assets/specs/misty-forest-roster-assets.md:40 "All four approved by the user 2026-11-02 ('Duyệt cả 4')" |

## 3. Facing and frame

| Field | Value |
|---|---|
| Sheet facing | left (`clips.json` facing; the engine flips by negative width for the other side) |
| PixelLab view / direction | low top-down / south-west |
| Frame | 64x52 art px |
| Anchor rule | feet on the last pixel row, feet x = 32; ≥ 1 transparent px left / right / top (`export_sheets.py` refuses otherwise) |
| Sheet | `assets/art/units/unit_greycap_sporeling_sheet.png` 389x264, one row per clip, 1 px gutter, Aseprite-array JSON |

## 4. Palette constraints

- Locked at generation: Ink; caps #4A3E4A / #6A5868 / #8E8296; stem #D8CDB0; moss #4A5545 / #5E6B55; spores #EFE6D2.
- In the installed sheet (`meta.tessera.palette`, 8 colours): `#1B1722`, `#4A3E4A`, `#4A5545`, `#5E6B55`, `#6A5868`, `#8E8296`, `#D8CDB0`, `#EFE6D2`
- Master: `art_src/palette/tessera_master.gpl`; ≤ 8 colours per unit; alpha 0 / 255 only; no red `#E5293B` (telegraph), no orange baked in (Burn); adding a colour is the art-director's call (bible §8.4).

## 5. PixelLab configuration and style reference

| Field | Value |
|---|---|
| Character id | 5705da35-be85-49c2-9704-555fbe8c755e |
| Image / job ids on record | — |
| Configuration that produced the anchor and clips | create_character_pro_flash 64x64, low top-down, 8 directions, seed 1, palette locked (max 8), style_image = Goblin v3 south rotation (colour off); clips animate_character pixminimax south-west, 8 frames. |
| Style reference (style_image lineage) | Goblin Scout v3 south rotation. |
| Post-generation (free, mechanical only) | palette snap to the locked colours, specks < 12 px removed, feet re-planted on the last row, body recentred; region recolour when the model drifted (Knight cape); never hand-painted detail (user rule) |

## 6. Animation contract

Required for a monster (art bible §5.4 / §8.6): `idle`, `step`, `windup`, `hit`, `down`.
Optional clips the code plays when present (fallback otherwise): `brace`, `guard`, `stunned`, `howl`.

| Clip | Frames | ms per frame | Loop | Status | Acceptance | Generation | Note |
|---|---|---|---|---|---|---|---|
| `idle` | 4 | 250 | loop | installed | unknown | — |  |
| `step` | 4 | 100 | loop | installed | unknown | — | nominal; the game paces step by the step cooldown |
| `windup` | 4 | 100, 100, 100, 0 | hold_last | installed | unknown | — | src 1, 2, 4, 6: the model drew the swelling red; the palette snap turned it into a grey-violet puff |
| `hit` | 3 | 40 | once | installed | unknown | — | src 5-7 (2-4 had baked bursts) |
| `down` | 6 | 100, 120, 150, 150, 150, 150 | hold_last | installed | unknown | — |  |

Timing rules: `idle` 125 ms (heroes) / 250–300 ms (enemies) per frame today (bible §8.6 says 0.4 s — the installed timing is the user's accepted feel); `step` is nominal, the game paces it by the step cooldown; `windup` ends on a 0 ms frame held until the telegraph ends; hero casts share the Knight's 9-slot timing 83, 83, 83, 83, 200 (hold frame 4), 50, 83, 100, 133 with the release on frame 5.

## 7. Visual constraints (what a new generation must keep)

- Same anchor: generate from `art_src/units/greycap_sporeling/idle/0.png` (or the character id) with the first frame pinned; for one-shot clips pin the last frame too.
- Same canvas 64x52, same feet row and feet x; the exporter bottom-aligns shorter sources, never taller ones.
- Identity in the upper half: Big spotted cap over an ivory stem body, two small caps at the sides like arms; 29x47 south-west, 7 colours.
- 1 px closed Ink outline; banded shading, light from the upper left; no glow, no smooth gradients, no anti-aliasing fringe (ART_QA_CHECKLIST §B–§D).
- Facing stays left in every frame (the model sometimes turns the back from frame 4: drop those frames, as for the Witch's step_up).
- Effects (bursts, stars, slash smears, red sprays) are never part of the body: delete or drop the frame; VFX are separate packs.
- Allowed variation: pose, cloth / hair / tendril sway, breathing 1–2 px, held weapon angle; not allowed: palette drift, proportions, props disappearing, new accessories.

## 8. Generation lineage

- 2026-11-02 anchor → character 5705da35 (6 gen) — APPROVED ('Duyệt cả 4')
- 2026-11-02 5 clips (part of the 23-gen batch) → clean-64x52 → sheet

## 9. Versions

- **Current:** installed sheet, see §3

## 10. Approval history (from the registry)

| Date | Event | Target | By | Evidence / note |
|---|---|---|---|---|
| 2026-11-11 | registered | asset | — | bootstrapped from disk by asset_registry.py; status by location only |
| 2026-11-02 | user_approved installed→approved | asset | user | art_src/units/greycap_sporeling/clips.json source: "approved 2026-11-02"; design/assets/specs/misty-forest-roster-assets.md:40 "All four approved by the user 2026-11-02 ('Duyệt cả 4')" |
| 2026-11-11 | note | asset | — | Master Reference created: design/assets/references/characters/greycap_sporeling.md |

## 11. Open points

- windup came out bright red; the palette snap turned it into a grey-violet puff (spec Clips table)

Evidence folders: `production/qa/evidence/misty-forest-roster`, `production/qa/evidence/misty-forest-roster-v2`
