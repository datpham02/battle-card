# Master Reference — Ember Hound (`ember_hound`)

> One file per character (P1 convention). Facts come from the registry entry `unit.ember_hound`, `art_src/units/ember_hound/clips.json`, the sheet JSON and the Hellfire roster report; every claim names its source. **Approval lives in the registry** (`asset_registry.py show unit.ember_hound`); this file explains the character so new generations stay consistent. Unknown = no record exists; do not fill it from memory.

## 1. Identity

| Field | Value |
|---|---|
| Registry id | `unit.ember_hound` |
| Type / tier | unit / monster |
| Role | Enemy — normal tier (battle t0–1), Thành Hỏa Ngục |
| Name (VI) | Chó Than Hồng (`strings.csv` `boss.ember_hound.name`) |
| Spec / report | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` §3.1 (design row), §12 (Checkpoint A/B) |
| Design (prompt text, anchor accepted 2026-11-13) | gaunt charcoal hound on all fours: ribs showing as cracked charcoal plates, long jaw with ivory teeth, drooping ears, broken dull-ochre chain collar. |
| Silhouette / proportions | 40x41 south-west, 6 colours; low quadruped. |
| Likeness check | Closest: Hellhound (Doom) → no flame, no orange eyes; ribs as broken char. |

## 2. Approved references and anchor

| Field | Value |
|---|---|
| Concept reference | none (text design; region direction §3 of the report, art bible §5.2 warden row for the warden) |
| Anchor image (canonical frame) | `art_src/units/ember_hound/idle/0.png` — idle frame 0 of the installed source (= cleaned south-west rotation); every new clip is generated from this frame or from the PixelLab character below |
| Rotation set | `design/assets/candidates/hellfire/ember_hound/rot/` (south, south-west, west) |
| Anchor approval | **accepted** — user 2026-11-13 "Yes, 45 clip" after the Checkpoint A review (report §12.2–12.3b: measurements, likeness, arena mocks) |

## 3. Facing and frame

| Field | Value |
|---|---|
| Sheet facing | left (`clips.json` facing; the engine flips by negative width for the other side) |
| PixelLab view / direction | low top-down / south-west |
| Frame | 68x52 art px (widened from the tier minimum so sideways motion is not cut) |
| Anchor rule | feet on the last pixel row, body centred at x = w/2 from idle frame 0 (one shift per unit); ≥ 1 transparent px left / right / top |
| Sheet | `assets/art/units/unit_ember_hound_sheet.png`, one row per clip, 1 px gutter, Aseprite-array JSON |

## 4. Palette constraints

- Locked at generation (≤ 8 of `tessera_master.gpl`, Hellfire rows added 2026-11-13): #1B1722, #2C2925, #4A4640, #5A5650, #8A6A40, #EFE6D2
- No red `#E5293B` (telegraph), no Burn orange `#FF7A1F`, no lava `#FFB21F` on the body; lava is a dull ochre crack ≤ 2 px (RENDER-STANDARDS §4 Hỏa Ngục "Không": orange veins, orange eyes).

## 5. PixelLab configuration and style reference

| Field | Value |
|---|---|
| Character id | `677145ec-45f4-4d29-b650-905e5330c130` |
| Configuration that produced the anchor | `create_character_pro_flash`, canvas by tier (64 / 80 / 96), low top-down, 8 directions, seed 1, palette locked (max 8), style_image = Goblin Scout v3 south rotation (`3b9516c8`), colour transfer off; prompt = report §12.1 |
| Clips | `animate_character` mode pixminimax, south-west, 8 frames, 1 gen each; prompts = report §12.4 (motion only, no negative words) |
| Post-generation (free, mechanical only) | palette snap to the locked colours, 8-connected clusters < 12 px removed, feet re-planted on the last row, one horizontal shift per unit, cropped to the frame (same logic as `tools/qa/sprite_clean.gd`); never hand-painted detail (user rule) |

## 6. Animation contract

Required for a block-brain enemy: `idle`, `step`, `windup`, `hit`, `down` (the special clips are only requested for pattern brains).

| Clip | Frames | ms per frame | Loop | Status | Acceptance | Generation | Note |
|---|---|---|---|---|---|---|---|
| `idle` | 4 | 250, 250, 250, 250 | loop | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 0/2/4/6 |
| `step` | 4 | 100, 100, 100, 100 | loop | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 1/3/5/7 ; nominal; the game paces step by the step cooldown |
| `windup` | 4 | 100, 100, 100, 0 | hold_last | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 2/4/6/8, head low, teeth bared, held |
| `hit` | 3 | 40, 40, 40 | once | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 2/3/4 (1 had a baked yellow slash) |
| `down` | 6 | 100, 120, 150, 150, 150, 150 | hold_last | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 1/3/4/5/6/8, collapses onto its side |

## 7. Visual constraints (what a new generation must keep)

- Same anchor and character id; same canvas, feet row and feet x.
- Identity in the upper half: 40x41 south-west, 6 colours.
- 1 px closed Ink outline; banded shading; no glow, no gradient, no anti-aliasing fringe.
- Facing stays left in every frame; frames with baked effects (slashes, stars, fire) are dropped, never kept (see the hit notes).

## 8. Generation lineage

- 2026-11-13 anchor → character `677145ec-45f4-4d29-b650-905e5330c130` (6–7 gen) — ACCEPTED ("Yes, 45 clip")
- 2026-11-13 5 clips (5 gen) → clean-68x52 → sheet

## 9. Approval history

| Date | Event | By | Evidence |
|---|---|---|---|
| 2026-11-13 | anchor accepted, clips generated, sheet installed | user / session | report §12; in-game `production/qa/evidence/world-map-v2/region-enemies/10-hellfire-ember_hound-idle.png` |
