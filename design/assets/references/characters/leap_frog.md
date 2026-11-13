# Master Reference — Leap Frog (`leap_frog`)

> One file per character (P1 convention). Facts come from the registry entry `unit.leap_frog`, `art_src/units/leap_frog/clips.json`, the sheet JSON and the region roster report; every claim names its source. **Approval lives in the registry** (`asset_registry.py show unit.leap_frog`); this file explains the character so new generations stay consistent. Unknown = no record exists; do not fill it from memory.

## 1. Identity

| Field | Value |
|---|---|
| Registry id | `unit.leap_frog` |
| Type / tier | unit / elite |
| Role | Enemy — elite tier (miniboss t1–2, hop_skip), Đầm Lầy Độc |
| Name (VI) | Ếch Nhảy (`strings.csv` `boss.leap_frog.name`) |
| Spec / report | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` §3 (design row), region Checkpoint A/B sections |
| Design (prompt text, anchor accepted 2026-11-13) | big swamp frog sitting upright and tall: very long folded hind legs, slim olive body, bulging ivory eyes on top of the head, pale ivory belly, webbed feet. |
| Silhouette / proportions | 31x62 south-west, 6 colours; elite measured against the low normals of the region like the Wolf Alpha (user 2026-11-13 'Yes, chấp nhận'). |
| Likeness check | Closest: Greninja → a real frog, no scarf. |

## 2. Approved references and anchor

| Field | Value |
|---|---|
| Concept reference | none (text design; region direction §3 of the report, art bible §5.2 warden row for the warden) |
| Anchor image (canonical frame) | `art_src/units/leap_frog/idle/0.png` — idle frame 0 of the installed source (= cleaned south-west rotation); every new clip is generated from this frame or from the PixelLab character below |
| Rotation set | `design/assets/candidates/swamp/leap_frog/rot-v2/` (south, south-west, west) |
| Anchor approval | **accepted** — user 2026-11-13 "Yes, 45 clip" after the Checkpoint A review (measurements, likeness, line-up)
- v1 anchor `76d61629-3d97-4a6e-81be-b2f634fd6b9f` retired (size / likeness), kept on PixelLab, not used |

## 3. Facing and frame

| Field | Value |
|---|---|
| Sheet facing | left (`clips.json` facing; the engine flips by negative width for the other side) |
| PixelLab view / direction | low top-down / south-west |
| Frame | 80x80 art px (widened from the tier minimum where a clip moves sideways or spreads) |
| Anchor rule | feet (lowest opaque row) on the last pixel row, body centred at x = w/2 from idle frame 0 (one shift per unit); ≥ 1 transparent px left / right / top |
| Sheet | `assets/art/units/unit_leap_frog_sheet.png`, one row per clip, 1 px gutter, Aseprite-array JSON |

## 4. Palette constraints

- Locked at generation (≤ 8 of `tessera_master.gpl`, Đầm Lầy rows added 2026-11-13): #1B1722, #3A4538, #4E4C3C, #5E6B55, #8FA070, #EFE6D2
- Dark region (V ≤ 40, black water): every body carries a light mass in the upper half (ivory belly / throat, light mushroom #8E8296, light moss #5E6B55). Olive #4E4C3C and mud #5A4A3A are the region colours; the forest moss and mushroom ramps are reused; the mire-cell colours #4E4A2A / #A8C83A are never on a body. No red: open mouths the model drew red were snapped to the palette.

## 5. PixelLab configuration and style reference

| Field | Value |
|---|---|
| Character id | `320c81ba-7698-46f2-b192-372de5d6745b` |
| Configuration that produced the anchor | `create_character_pro_flash`, canvas by tier (64 / 80 / 96), low top-down, 8 directions, palette locked (max 8), style_image = Goblin Scout v3 south rotation (`3b9516c8`), colour transfer off; prompt = the region's Checkpoint A table in the report |
| Clips | `animate_character` mode pixminimax, south-west, 8 frames, 1 gen each; motion-only prompts (no negative words) |
| Post-generation (free, mechanical only) | palette snap to the locked colours, 8-connected clusters < 12 px removed, feet re-planted on the last row, one horizontal shift per unit, cropped to the frame (same logic as `tools/qa/sprite_clean.gd`); never hand-painted detail (user rule) |

## 6. Animation contract

Required for a block-brain enemy: `idle`, `step`, `windup`, `hit`, `down` (the special clips are only requested for pattern brains).

| Clip | Frames | ms per frame | Loop | Status | Acceptance | Generation | Note |
|---|---|---|---|---|---|---|---|
| `idle` | 4 | 250, 250, 250, 250 | loop | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 0/2/4/6 |
| `step` | 4 | 100, 100, 100, 100 | loop | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 1/3/5/7, small hop ; nominal; the game paces step by the step cooldown |
| `windup` | 4 | 100, 100, 100, 0 | hold_last | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 2/4/6/8, crouched to spring, held |
| `hit` | 3 | 40, 40, 40 | once | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 5/6/7 (3-4 had a baked ivory slash and lines) |
| `down` | 6 | 100, 120, 150, 150, 150, 150 | hold_last | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 2/3/4/5/6/8, sprawls flat |

## 7. Visual constraints (what a new generation must keep)

- Same anchor and character id; same canvas, feet row and feet x.
- Identity in the upper half: 31x62 south-west, 6 colours.
- 1 px closed Ink outline; banded shading; no glow, no gradient, no anti-aliasing fringe.
- Facing stays left in every frame; frames with baked effects (slashes, projectiles, debris) are dropped, never kept (see the clip notes).

## 8. Generation lineage

- 2026-11-13 anchor → character `320c81ba-7698-46f2-b192-372de5d6745b` (6–7 gen) after a retired v1 (6–7 gen) — ACCEPTED ("Yes, 45 clip")
- 2026-11-13 5 clips (5 gen) → clean-80x80 → sheet

## 9. Approval history

| Date | Event | By | Evidence |
|---|---|---|---|
| 2026-11-13 | anchor accepted, clips generated, sheet installed | user / session | report; in-game `production/qa/evidence/world-map-v2/region-enemies/10-swamp-leap_frog-idle.png` |
