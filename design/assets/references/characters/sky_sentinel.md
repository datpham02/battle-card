# Master Reference — Sky Sentinel (`sky_sentinel`)

> One file per character (P1 convention). Facts come from the registry entry `unit.sky_sentinel`, `art_src/units/sky_sentinel/clips.json`, the sheet JSON and the region roster report; every claim names its source. **Approval lives in the registry** (`asset_registry.py show unit.sky_sentinel`); this file explains the character so new generations stay consistent. Unknown = no record exists; do not fill it from memory.

## 1. Identity

| Field | Value |
|---|---|
| Registry id | `unit.sky_sentinel` |
| Type / tier | unit / monster |
| Role | Enemy — normal tier (battle t2, danger t1–2), Không Đảo |
| Name (VI) | Lính Gác Trời (`strings.csv` `boss.sky_sentinel.name`) |
| Spec / report | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` §3 (design row), region Checkpoint A/B sections |
| Design (prompt text, anchor accepted 2026-11-13) | hooded brown stone sentinel statue with folded stone wings, frayed rope on the arms, a stone spear, blank face with ivory eyes. Step clip generated on a second call after the user allowed 1 more gen (the first call had been blocked by the auto-mode permission check). |
| Silhouette / proportions | 34x51 south-west, 7 colours; hooded statue with wings and spear (vs Stone Sentry: wings, rope, brown). |
| Likeness check | Closest: Gargoyle → hood, rope, spear. |

## 2. Approved references and anchor

| Field | Value |
|---|---|
| Concept reference | none (text design; region direction §3 of the report, art bible §5.2 warden row for the warden) |
| Anchor image (canonical frame) | `art_src/units/sky_sentinel/idle/0.png` — idle frame 0 of the installed source (= cleaned south-west rotation); every new clip is generated from this frame or from the PixelLab character below |
| Rotation set | `design/assets/candidates/sky_isles/sky_sentinel/rot/` (south, south-west, west) |
| Anchor approval | **accepted** — user 2026-11-13 "Yes, 45 clip" after the Checkpoint A review (measurements, likeness, line-up) |

## 3. Facing and frame

| Field | Value |
|---|---|
| Sheet facing | left (`clips.json` facing; the engine flips by negative width for the other side) |
| PixelLab view / direction | low top-down / south-west |
| Frame | 64x53 art px (widened from the tier minimum where a clip moves sideways or spreads) |
| Anchor rule | feet (lowest opaque row) on the last pixel row, body centred at x = w/2 from idle frame 0 (one shift per unit); ≥ 1 transparent px left / right / top |
| Sheet | `assets/art/units/unit_sky_sentinel_sheet.png`, one row per clip, 1 px gutter, Aseprite-array JSON |

## 4. Palette constraints

- Locked at generation (≤ 8 of `tessera_master.gpl`, Không Đảo rows added 2026-11-13): #1B1722, #2C2925, #4A4640, #5A5048, #6A6B62, #8A6A40, #EFE6D2
- Không Đảo region colours (tessera_master.gpl 2026-11-13): island stone #5A5048, storm grey #6A7080, dull storm yellow #B8A860 (accent only, never the Lattice gold #FFD45C)

## 5. PixelLab configuration and style reference

| Field | Value |
|---|---|
| Character id | `1d71becf-a375-4c41-9d52-ab8d1c4f71dd` |
| Configuration that produced the anchor | `create_character_pro_flash`, canvas by tier (64 / 80 / 96), low top-down, 8 directions, palette locked (max 8), style_image = Goblin Scout v3 south rotation (`3b9516c8`), colour transfer off; prompt = the region's Checkpoint A table in the report |
| Clips | `animate_character` mode pixminimax, south-west, 8 frames, 1 gen each; motion-only prompts (no negative words) |
| Post-generation (free, mechanical only) | palette snap to the locked colours, 8-connected clusters < 12 px removed, feet re-planted on the last row, one horizontal shift per unit, cropped to the frame (same logic as `tools/qa/sprite_clean.gd`); never hand-painted detail (user rule) |

## 6. Animation contract

Required for a block-brain enemy: `idle`, `step`, `windup`, `hit`, `down` (the special clips are only requested for pattern brains).

| Clip | Frames | ms per frame | Loop | Status | Acceptance | Generation | Note |
|---|---|---|---|---|---|---|---|
| `idle` | 4 | 250, 250, 250, 250 | loop | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 0/2/4/6 |
| `step` | 4 | 100, 100, 100, 100 | loop | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 1/3/5/7, heavy side step (generated after the user allowed 1 more gen; the first try had been blocked by the auto-mode permission check) ; nominal; the game paces step by the step cooldown |
| `windup` | 4 | 100, 100, 100, 0 | hold_last | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 2/4/6/8, spear drawn back, wing opening, held |
| `hit` | 3 | 40, 40, 40 | once | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 3/4/5 |
| `down` | 6 | 100, 120, 150, 150, 150, 150 | hold_last | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 2/3/4/5/6/8, crumbles into stone blocks |

## 7. Visual constraints (what a new generation must keep)

- Same anchor and character id; same canvas, feet row and feet x.
- Identity in the upper half: 34x51 south-west, 7 colours.
- 1 px closed Ink outline; banded shading; no glow, no gradient, no anti-aliasing fringe.
- Facing stays left in every frame; frames with baked effects (slashes, projectiles, debris) are dropped, never kept (see the clip notes).

## 8. Generation lineage

- 2026-11-13 anchor → character `1d71becf-a375-4c41-9d52-ab8d1c4f71dd` (6–7 gen) — ACCEPTED ("Yes, 45 clip")
- 2026-11-13 5 clips (5 gen) → clean-64x53 → sheet

## 9. Approval history

| Date | Event | By | Evidence |
|---|---|---|---|
| 2026-11-13 | anchor accepted, clips generated, sheet installed | user / session | report; in-game `production/qa/evidence/world-map-v2/region-enemies/10-sky_isles-sky_sentinel-idle.png` |
