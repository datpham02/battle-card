# Master Reference — Mossbound Sentry (`mossbound_sentry`)

> One file per character (P1, 2026-11-11). Facts come from the registry entry `unit.mossbound_sentry`, `art_src/units/mossbound_sentry/clips.json`, the sheet JSON and the spec; every claim names its source. **Approval lives in the registry** (`asset_registry.py show unit.mossbound_sentry`); this file explains the character so new generations stay consistent. Unknown = no record exists; do not fill it from memory.

## 1. Identity

| Field | Value |
|---|---|
| Registry id / legacy id | `unit.mossbound_sentry` / ASSET-023 |
| Type / tier | unit / monster |
| Role | Enemy — normal tier, Misty Forest (guard skill 'brace') |
| Spec | `design/assets/specs/misty-forest-roster-assets.md` |
| Design (approved text) | Squat stack of grey slab stones, thick moss on the shoulders and back, no arms, eye glints in a slit (ASSET-023 row). The model gave it stone arms despite 'no arms' — accepted. |
| Silhouette / proportions | Hunched stone golem 30x45 south-west, 7 colours. |
| Likeness check | Closest: a generic rock golem (Graveler-like). Flagged to the user; accepted ('Duyệt cả 4'). |

## 2. Approved references and anchor

| Field | Value |
|---|---|
| Concept reference | none (text design, phase2-misty-forest quick spec §8) |
| Anchor image (canonical frame) | `art_src/units/mossbound_sentry/idle/0.png` — idle frame 0 of the installed source; every new clip is generated from this frame or from the PixelLab character below |
| Rotation set | `design/assets/candidates/mossbound-sentry/anim`, `design/assets/candidates/mossbound-sentry/clean-64x52` |
| Anchor approval | **approved** — art_src/units/mossbound_sentry/clips.json source: "approved 2026-11-02"; misty-forest-roster-assets.md:40 "All four approved by the user 2026-11-02 ('Duyệt cả 4')" |

## 3. Facing and frame

| Field | Value |
|---|---|
| Sheet facing | left (`clips.json` facing; the engine flips by negative width for the other side) |
| PixelLab view / direction | low top-down / south-west |
| Frame | 64x52 art px |
| Anchor rule | feet on the last pixel row, feet x = 32; ≥ 1 transparent px left / right / top (`export_sheets.py` refuses otherwise) |
| Sheet | `assets/art/units/unit_mossbound_sentry_sheet.png` 389x317, one row per clip, 1 px gutter, Aseprite-array JSON |

## 4. Palette constraints

- Locked at generation: Ink; stone #2C2925 / #4A4640 / #5A5650 / #6A6B62; moss #4A5545 / #5E6B55; eyes #EFE6D2.
- In the installed sheet (`meta.tessera.palette`, 8 colours): `#1B1722`, `#2C2925`, `#4A4640`, `#4A5545`, `#5A5650`, `#5E6B55`, `#6A6B62`, `#EFE6D2`
- Master: `art_src/palette/tessera_master.gpl`; ≤ 8 colours per unit; alpha 0 / 255 only; no red `#E5293B` (telegraph), no orange baked in (Burn); adding a colour is the art-director's call (bible §8.4).

## 5. PixelLab configuration and style reference

| Field | Value |
|---|---|
| Character id | 44968e76-914f-4ee8-9e6b-c552f0a1fdcd |
| Image / job ids on record | — |
| Configuration that produced the anchor and clips | create_character_pro_flash 64x64, low top-down, 8 directions, seed 1, palette locked (max 8), style_image = Goblin v3 south rotation (colour off); clips animate_character pixminimax south-west, 8 frames (6 clips incl. brace). |
| Style reference (style_image lineage) | Goblin Scout v3 south rotation. |
| Post-generation (free, mechanical only) | palette snap to the locked colours, specks < 12 px removed, feet re-planted on the last row, body recentred; region recolour when the model drifted (Knight cape); never hand-painted detail (user rule) |

## 6. Animation contract

Required for a monster (art bible §5.4 / §8.6): `idle`, `step`, `windup`, `hit`, `down`.
Optional clips the code plays when present (fallback otherwise): `brace`, `guard`, `stunned`, `howl`.

| Clip | Frames | ms per frame | Loop | Status | Acceptance | Generation | Note |
|---|---|---|---|---|---|---|---|
| `idle` | 4 | 250 | loop | installed | unknown | — |  |
| `step` | 4 | 100 | loop | installed | unknown | — | nominal; the game paces step by the step cooldown |
| `windup` | 4 | 100, 100, 100, 0 | hold_last | installed | unknown | — |  |
| `brace` | 4 | 100, 100, 100, 0 | hold_last | installed | unknown | — | played while a guard skill (brace) winds up |
| `hit` | 3 | 40 | once | installed | unknown | — | src 5-7 (1-4 had baked bursts) |
| `down` | 6 | 100, 120, 150, 150, 150, 150 | hold_last | installed | unknown | — | red streaks in the rubble snapped to the stone colours |

Timing rules: `idle` 125 ms (heroes) / 250–300 ms (enemies) per frame today (bible §8.6 says 0.4 s — the installed timing is the user's accepted feel); `step` is nominal, the game paces it by the step cooldown; `windup` ends on a 0 ms frame held until the telegraph ends; hero casts share the Knight's 9-slot timing 83, 83, 83, 83, 200 (hold frame 4), 50, 83, 100, 133 with the release on frame 5.

## 7. Visual constraints (what a new generation must keep)

- Same anchor: generate from `art_src/units/mossbound_sentry/idle/0.png` (or the character id) with the first frame pinned; for one-shot clips pin the last frame too.
- Same canvas 64x52, same feet row and feet x; the exporter bottom-aligns shorter sources, never taller ones.
- Identity in the upper half: Hunched stone golem 30x45 south-west, 7 colours.
- 1 px closed Ink outline; banded shading, light from the upper left; no glow, no smooth gradients, no anti-aliasing fringe (ART_QA_CHECKLIST §B–§D).
- Facing stays left in every frame (the model sometimes turns the back from frame 4: drop those frames, as for the Witch's step_up).
- Effects (bursts, stars, slash smears, red sprays) are never part of the body: delete or drop the frame; VFX are separate packs.
- Allowed variation: pose, cloth / hair / tendril sway, breathing 1–2 px, held weapon angle; not allowed: palette drift, proportions, props disappearing, new accessories.

## 8. Generation lineage

- 2026-11-02 anchor → character 44968e76 (6 gen) — APPROVED ('Duyệt cả 4')
- 2026-11-02 6 clips → clean-64x52 → sheet

## 9. Versions

- **Current:** installed sheet, see §3

## 10. Approval history (from the registry)

| Date | Event | Target | By | Evidence / note |
|---|---|---|---|---|
| 2026-11-11 | registered | asset | — | bootstrapped from disk by asset_registry.py; status by location only |
| 2026-11-02 | user_approved installed→approved | asset | user | art_src/units/mossbound_sentry/clips.json source: "approved 2026-11-02"; misty-forest-roster-assets.md:40 "All four approved by the user 2026-11-02 ('Duyệt cả 4')" |
| 2026-11-11 | note | asset | — | Master Reference created: design/assets/references/characters/mossbound_sentry.md |

## 11. Open points

- none recorded

Evidence folders: `production/qa/evidence/misty-forest-roster`, `production/qa/evidence/misty-forest-roster-v2`
