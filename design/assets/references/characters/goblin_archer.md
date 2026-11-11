# Master Reference — Goblin Archer (`goblin_archer`)

> One file per character (P1, 2026-11-11). Facts come from the registry entry `unit.goblin_archer`, `art_src/units/goblin_archer/clips.json`, the sheet JSON and the spec; every claim names its source. **Approval lives in the registry** (`asset_registry.py show unit.goblin_archer`); this file explains the character so new generations stay consistent. Unknown = no record exists; do not fill it from memory.

## 1. Identity

| Field | Value |
|---|---|
| Registry id / legacy id | `unit.goblin_archer` / ASSET-026 |
| Type / tier | unit / monster |
| Role | Enemy — normal tier, Misty Forest roster v2 (Goblin Scout body variant, bible §5.6) |
| Spec | `design/assets/specs/misty-forest-roster-assets.md` |
| Design (approved text) | The Goblin Scout's body: dark moss-grey hood up between the long sideways ears, short curved wooden bow held low in the near hand, quiver strap across the chest with arrow tips over the shoulder (ASSET-026 Design). |
| Silhouette / proportions | Hunched goblin with bow; south-west bbox 38x43 (bow included), 7 colours. |
| Likeness check | Closest: Dart Goblin (Clash Royale). Differentiated: desaturated olive skin, short bow, no mask, ragged leather, quiver. |

## 2. Approved references and anchor

| Field | Value |
|---|---|
| Concept reference | none (design/quick-specs/doi-hinh-rung-suong-2026-11-03.md §3.2) |
| Anchor image (canonical frame) | `art_src/units/goblin_archer/idle/0.png` — idle frame 0 of the installed source; every new clip is generated from this frame or from the PixelLab character below |
| Rotation set | `design/assets/candidates/goblin-archer/rot`, `design/assets/candidates/goblin-archer/anim`, `design/assets/candidates/goblin-archer/clean-64x52` |
| Anchor approval | **approved** — art_src/units/goblin_archer/clips.json source: "approved 2026-11-03" |

## 3. Facing and frame

| Field | Value |
|---|---|
| Sheet facing | left (`clips.json` facing; the engine flips by negative width for the other side) |
| PixelLab view / direction | low top-down / south-west |
| Frame | 64x52 art px |
| Anchor rule | feet on the last pixel row, feet x = 32; ≥ 1 transparent px left / right / top (`export_sheets.py` refuses otherwise) |
| Sheet | `assets/art/units/unit_goblin_archer_sheet.png` 389x264, one row per clip, 1 px gutter, Aseprite-array JSON |

## 4. Palette constraints

- Locked at generation: Ink #1B1722; skin #7D8B5A / #59643F; leather #9A7D5E / #66523F; eyes #EFE6D2; hood #5E6B55; bow wood #8A7350. No red, no glow.
- In the installed sheet (`meta.tessera.palette`, 7 colours): `#1B1722`, `#5E6B55`, `#66523F`, `#7D8B5A`, `#8A7350`, `#9A7D5E`, `#EFE6D2`
- Master: `art_src/palette/tessera_master.gpl`; ≤ 8 colours per unit; alpha 0 / 255 only; no red `#E5293B` (telegraph), no orange baked in (Burn); adding a colour is the art-director's call (bible §8.4).

## 5. PixelLab configuration and style reference

| Field | Value |
|---|---|
| Character id | b580ca70-d8e9-4912-a3e0-ff8e0f79d3b2 |
| Image / job ids on record | 134a1167, dcc371e1, 005cb8d3, 4b14210b, b3fe5b11 (clip groups) |
| Configuration that produced the anchor and clips | create_character_pro_flash 64x64, low top-down, 8 directions, seed 1, palette locked (max 8), style_image = Goblin v3 south rotation (uploaded, colour off; a base64 style image was refused by the server). Clips: animate_character pixminimax south-west, 8 frames (5 gen). |
| Style reference (style_image lineage) | Goblin Scout v3 south rotation. |
| Post-generation (free, mechanical only) | palette snap to the locked colours, specks < 12 px removed, feet re-planted on the last row, body recentred; region recolour when the model drifted (Knight cape); never hand-painted detail (user rule) |

## 6. Animation contract

Required for a monster (art bible §5.4 / §8.6): `idle`, `step`, `windup`, `hit`, `down`.
Optional clips the code plays when present (fallback otherwise): `brace`, `guard`, `stunned`, `howl`.

| Clip | Frames | ms per frame | Loop | Status | Acceptance | Generation | Note |
|---|---|---|---|---|---|---|---|
| `idle` | 4 | 250 | loop | installed | unknown | — | src frames 0/2/4/6 |
| `step` | 4 | 100 | loop | installed | unknown | — | nominal; the game paces step by the step cooldown; src 1/3/5/7 |
| `windup` | 4 | 100, 100, 100, 0 | hold_last | installed | unknown | — | raises the bow and draws; the last frame is held until the telegraph ends; src 2/4/6/8 |
| `hit` | 3 | 40 | once | installed | unknown | — | src frames 4-6 (1-3 had a baked yellow burst and a red spray; red is the telegraph only) |
| `down` | 6 | 100, 120, 150, 150, 150, 150 | hold_last | installed | unknown | — | drops the bow and falls face down; src 1/2/3/4/5/8 |

Timing rules: `idle` 125 ms (heroes) / 250–300 ms (enemies) per frame today (bible §8.6 says 0.4 s — the installed timing is the user's accepted feel); `step` is nominal, the game paces it by the step cooldown; `windup` ends on a 0 ms frame held until the telegraph ends; hero casts share the Knight's 9-slot timing 83, 83, 83, 83, 200 (hold frame 4), 50, 83, 100, 133 with the release on frame 5.

## 7. Visual constraints (what a new generation must keep)

- Same anchor: generate from `art_src/units/goblin_archer/idle/0.png` (or the character id) with the first frame pinned; for one-shot clips pin the last frame too.
- Same canvas 64x52, same feet row and feet x; the exporter bottom-aligns shorter sources, never taller ones.
- Identity in the upper half: Hunched goblin with bow; south-west bbox 38x43 (bow included), 7 colours.
- 1 px closed Ink outline; banded shading, light from the upper left; no glow, no smooth gradients, no anti-aliasing fringe (ART_QA_CHECKLIST §B–§D).
- Facing stays left in every frame (the model sometimes turns the back from frame 4: drop those frames, as for the Witch's step_up).
- Effects (bursts, stars, slash smears, red sprays) are never part of the body: delete or drop the frame; VFX are separate packs.
- Allowed variation: pose, cloth / hair / tendril sway, breathing 1–2 px, held weapon angle; not allowed: palette drift, proportions, props disappearing, new accessories.

## 8. Generation lineage

- 2026-11-03 anchor-01 → character b580ca70 (6 gen, 'Duyệt, gen 6 gen') — APPROVED
- 2026-11-03 anim-5clips (5 gen) → clean-64x52 → sheet

## 9. Versions

- **Current:** installed sheet, see §3

## 10. Approval history (from the registry)

| Date | Event | Target | By | Evidence / note |
|---|---|---|---|---|
| 2026-11-11 | registered | asset | — | bootstrapped from disk by asset_registry.py; status by location only |
| 2026-11-03 | user_approved installed→approved | asset | user | art_src/units/goblin_archer/clips.json source: "approved 2026-11-03" |
| 2026-11-11 | note | asset | — | Master Reference created: design/assets/references/characters/goblin_archer.md |

## 11. Open points

- none recorded

Evidence folders: `production/qa/evidence/misty-forest-roster`, `production/qa/evidence/misty-forest-roster-v2`
