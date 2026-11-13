# Master Reference — Snow Wolf (`snow_wolf`)

> One file per character (P1 convention). Facts come from the registry entry `unit.snow_wolf`, `art_src/units/snow_wolf/clips.json`, the sheet JSON and the region roster report; every claim names its source. **Approval lives in the registry** (`asset_registry.py show unit.snow_wolf`); this file explains the character so new generations stay consistent. Unknown = no record exists; do not fill it from memory.

## 1. Identity

| Field | Value |
|---|---|
| Registry id | `unit.snow_wolf` |
| Type / tier | unit / monster |
| Role | Enemy — normal tier (battle t1–2, danger t1), Tháp Sương |
| Name (VI) | Sói tuyết (`strings.csv` `boss.snow_wolf.name`) |
| Spec / report | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` §3 (design row), region Checkpoint A/B sections |
| Design (prompt text, anchor accepted 2026-11-13) | snow wolf on all fours: thick pale grey-white fur, heavy snowy mane, narrow snout, night-blue back stripe, ivory teeth. |
| Silhouette / proportions | 40x42 south-west, 5 colours; pale quadruped with a mane (vs Dire Wolf, Ember Hound, Dune Jackal, Bog Hound). |
| Likeness check | Closest: Ghost (Game of Thrones) / Mightyena → mane, night-blue stripe. |

## 2. Approved references and anchor

| Field | Value |
|---|---|
| Concept reference | none (text design; region direction §3 of the report, art bible §5.2 warden row for the warden) |
| Anchor image (canonical frame) | `art_src/units/snow_wolf/idle/0.png` — idle frame 0 of the installed source (= cleaned south-west rotation); every new clip is generated from this frame or from the PixelLab character below |
| Rotation set | `design/assets/candidates/ice_tower/snow_wolf/rot/` (south, south-west, west) |
| Anchor approval | **accepted** — user 2026-11-13 "Yes, 45 clip" after the Checkpoint A review (measurements, likeness, line-up) |

## 3. Facing and frame

| Field | Value |
|---|---|
| Sheet facing | left (`clips.json` facing; the engine flips by negative width for the other side) |
| PixelLab view / direction | low top-down / south-west |
| Frame | 72x52 art px (widened from the tier minimum where a clip moves sideways or spreads) |
| Anchor rule | feet (lowest opaque row) on the last pixel row, body centred at x = w/2 from idle frame 0 (one shift per unit); ≥ 1 transparent px left / right / top |
| Sheet | `assets/art/units/unit_snow_wolf_sheet.png`, one row per clip, 1 px gutter, Aseprite-array JSON |

## 4. Palette constraints

- Locked at generation (≤ 8 of `tessera_master.gpl`, Tháp Sương rows added 2026-11-13): #1B1722, #2E3450, #6E7282, #A8B0C8, #EFE6D2
- Bright region (sky 60-72, cloud sea): the dark masses (night blue #2E3450, Ink) sit in the upper half; slate #4C5266 and rime light #A8B0C8 on lit faces; never cyan #A6EEFF (Frozen shell) — cyan the model drew was snapped to rime grey.

## 5. PixelLab configuration and style reference

| Field | Value |
|---|---|
| Character id | `eca3ebc1-2b13-4000-85f4-c78cb3c0f049` |
| Configuration that produced the anchor | `create_character_pro_flash`, canvas by tier (64 / 80 / 96), low top-down, 8 directions, palette locked (max 8), style_image = Goblin Scout v3 south rotation (`3b9516c8`), colour transfer off; prompt = the region's Checkpoint A table in the report |
| Clips | `animate_character` mode pixminimax, south-west, 8 frames, 1 gen each; motion-only prompts (no negative words) |
| Post-generation (free, mechanical only) | palette snap to the locked colours, 8-connected clusters < 12 px removed, feet re-planted on the last row, one horizontal shift per unit, cropped to the frame (same logic as `tools/qa/sprite_clean.gd`); never hand-painted detail (user rule) |

## 6. Animation contract

Required for a block-brain enemy: `idle`, `step`, `windup`, `hit`, `down` (the special clips are only requested for pattern brains).

| Clip | Frames | ms per frame | Loop | Status | Acceptance | Generation | Note |
|---|---|---|---|---|---|---|---|
| `idle` | 4 | 250, 250, 250, 250 | loop | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 0/2/4/6 |
| `step` | 4 | 100, 100, 100, 100 | loop | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 1/3/5/7, trot ; nominal; the game paces step by the step cooldown |
| `windup` | 4 | 100, 100, 100, 0 | hold_last | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 2/4/6/8, hackles up, teeth bared, held |
| `hit` | 3 | 40, 40, 40 | once | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 3/4/5 (1-2 had a baked slash and lines) |
| `down` | 6 | 100, 120, 150, 150, 150, 150 | hold_last | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 2/3/4/5/6/8, collapses onto its side |

## 7. Visual constraints (what a new generation must keep)

- Same anchor and character id; same canvas, feet row and feet x.
- Identity in the upper half: 40x42 south-west, 5 colours.
- 1 px closed Ink outline; banded shading; no glow, no gradient, no anti-aliasing fringe.
- Facing stays left in every frame; frames with baked effects (slashes, projectiles, debris) are dropped, never kept (see the clip notes).

## 8. Generation lineage

- 2026-11-13 anchor → character `eca3ebc1-2b13-4000-85f4-c78cb3c0f049` (6–7 gen) — ACCEPTED ("Yes, 45 clip")
- 2026-11-13 5 clips (5 gen) → clean-72x52 → sheet

## 9. Approval history

| Date | Event | By | Evidence |
|---|---|---|---|
| 2026-11-13 | anchor accepted, clips generated, sheet installed | user / session | report; in-game `production/qa/evidence/world-map-v2/region-enemies/10-ice_tower-snow_wolf-idle.png` |
