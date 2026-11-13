# Master Reference — Ash Golem (`ash_golem`)

> One file per character (P1 convention). Facts come from the registry entry `unit.ash_golem`, `art_src/units/ash_golem/clips.json`, the sheet JSON and the Hellfire roster report; every claim names its source. **Approval lives in the registry** (`asset_registry.py show unit.ash_golem`); this file explains the character so new generations stay consistent. Unknown = no record exists; do not fill it from memory.

## 1. Identity

| Field | Value |
|---|---|
| Registry id | `unit.ash_golem` |
| Type / tier | unit / monster |
| Role | Enemy — normal tier (battle t1–2, danger t1), Thành Hỏa Ngục |
| Name (VI) | Khôi Tro (`strings.csv` `boss.ash_golem.name`) |
| Spec / report | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` §3.1 (design row), §12 (Checkpoint A/B) |
| Design (prompt text, anchor accepted 2026-11-13) | squat ash golem: square furnace-plate shoulders cut at right angles, head sunk into the chest, big fists, pitted grey ash body with dark cracks, dull ochre rivets, ivory eye slit. |
| Silhouette / proportions | 34x45 south-west, 7 colours; construct. |
| Likeness check | Closest: Golem (Clash) → square shoulders (lattice language), pitted ash. |

## 2. Approved references and anchor

| Field | Value |
|---|---|
| Concept reference | none (text design; region direction §3 of the report, art bible §5.2 warden row for the warden) |
| Anchor image (canonical frame) | `art_src/units/ash_golem/idle/0.png` — idle frame 0 of the installed source (= cleaned south-west rotation); every new clip is generated from this frame or from the PixelLab character below |
| Rotation set | `design/assets/candidates/hellfire/ash_golem/rot/` (south, south-west, west) |
| Anchor approval | **accepted** — user 2026-11-13 "Yes, 45 clip" after the Checkpoint A review (report §12.2–12.3b: measurements, likeness, arena mocks) |

## 3. Facing and frame

| Field | Value |
|---|---|
| Sheet facing | left (`clips.json` facing; the engine flips by negative width for the other side) |
| PixelLab view / direction | low top-down / south-west |
| Frame | 72x52 art px (widened from the tier minimum so sideways motion is not cut) |
| Anchor rule | feet on the last pixel row, body centred at x = w/2 from idle frame 0 (one shift per unit); ≥ 1 transparent px left / right / top |
| Sheet | `assets/art/units/unit_ash_golem_sheet.png`, one row per clip, 1 px gutter, Aseprite-array JSON |

## 4. Palette constraints

- Locked at generation (≤ 8 of `tessera_master.gpl`, Hellfire rows added 2026-11-13): #1B1722, #24201E, #4A4640, #5A5650, #6A6B62, #8A6A40, #EFE6D2
- No red `#E5293B` (telegraph), no Burn orange `#FF7A1F`, no lava `#FFB21F` on the body; lava is a dull ochre crack ≤ 2 px (RENDER-STANDARDS §4 Hỏa Ngục "Không": orange veins, orange eyes).

## 5. PixelLab configuration and style reference

| Field | Value |
|---|---|
| Character id | `0c2bb412-b321-4eea-b267-0c8eec61c6fe` |
| Configuration that produced the anchor | `create_character_pro_flash`, canvas by tier (64 / 80 / 96), low top-down, 8 directions, seed 1, palette locked (max 8), style_image = Goblin Scout v3 south rotation (`3b9516c8`), colour transfer off; prompt = report §12.1 |
| Clips | `animate_character` mode pixminimax, south-west, 8 frames, 1 gen each; prompts = report §12.4 (motion only, no negative words) |
| Post-generation (free, mechanical only) | palette snap to the locked colours, 8-connected clusters < 12 px removed, feet re-planted on the last row, one horizontal shift per unit, cropped to the frame (same logic as `tools/qa/sprite_clean.gd`); never hand-painted detail (user rule) |

## 6. Animation contract

Required for a block-brain enemy: `idle`, `step`, `windup`, `hit`, `down` (the special clips are only requested for pattern brains).

| Clip | Frames | ms per frame | Loop | Status | Acceptance | Generation | Note |
|---|---|---|---|---|---|---|---|
| `idle` | 4 | 250, 250, 250, 250 | loop | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 0/2/4/6 |
| `step` | 4 | 100, 100, 100, 100 | loop | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 1/3/5/7 ; nominal; the game paces step by the step cooldown |
| `windup` | 4 | 100, 100, 100, 0 | hold_last | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 1/2/4/8, fists raised overhead, held |
| `hit` | 3 | 40, 40, 40 | once | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 4/5/6 (2-3 had baked ash spray blobs) |
| `down` | 6 | 100, 120, 150, 150, 150, 150 | hold_last | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 2/4/5/6/7/8, crumbles into a heap |

## 7. Visual constraints (what a new generation must keep)

- Same anchor and character id; same canvas, feet row and feet x.
- Identity in the upper half: 34x45 south-west, 7 colours.
- 1 px closed Ink outline; banded shading; no glow, no gradient, no anti-aliasing fringe.
- Facing stays left in every frame; frames with baked effects (slashes, stars, fire) are dropped, never kept (see the hit notes).

## 8. Generation lineage

- 2026-11-13 anchor → character `0c2bb412-b321-4eea-b267-0c8eec61c6fe` (6–7 gen) — ACCEPTED ("Yes, 45 clip")
- 2026-11-13 5 clips (5 gen) → clean-72x52 → sheet

## 9. Approval history

| Date | Event | By | Evidence |
|---|---|---|---|
| 2026-11-13 | anchor accepted, clips generated, sheet installed | user / session | report §12; in-game `production/qa/evidence/world-map-v2/region-enemies/10-hellfire-ash_golem-idle.png` |
