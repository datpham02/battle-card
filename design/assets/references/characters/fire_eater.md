# Master Reference — Fire Eater (`fire_eater`)

> One file per character (P1 convention). Facts come from the registry entry `unit.fire_eater`, `art_src/units/fire_eater/clips.json`, the sheet JSON and the Hellfire roster report; every claim names its source. **Approval lives in the registry** (`asset_registry.py show unit.fire_eater`); this file explains the character so new generations stay consistent. Unknown = no record exists; do not fill it from memory.

## 1. Identity

| Field | Value |
|---|---|
| Registry id | `unit.fire_eater` |
| Type / tier | unit / elite |
| Role | Enemy — elite tier (miniboss t1–2, burn_eater), Thành Hỏa Ngục |
| Name (VI) | Quỷ Nuốt Lửa (`strings.csv` `boss.fire_eater.name`) |
| Spec / report | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` §3.1 (design row), §12 (Checkpoint A/B) |
| Design (prompt text, anchor accepted 2026-11-13) | wide pot-bellied ogre-demon: huge open mouth with ivory teeth, chain collar of dull ochre links, charcoal skin cracked across the belly with dark bronze cracks, short thick legs, arms spread. |
| Silhouette / proportions | 60x75 south-west, 6 colours; elite, 75 px tall. |
| Likeness check | Closest: Oni → charcoal belly, no red face; the v1 anchor 87e8cfaa (47 px) was retired as too short for an elite. |

## 2. Approved references and anchor

| Field | Value |
|---|---|
| Concept reference | none (text design; region direction §3 of the report, art bible §5.2 warden row for the warden) |
| Anchor image (canonical frame) | `art_src/units/fire_eater/idle/0.png` — idle frame 0 of the installed source (= cleaned south-west rotation); every new clip is generated from this frame or from the PixelLab character below |
| Rotation set | `design/assets/candidates/hellfire/fire_eater/rot-v2/` (south, south-west, west) |
| Anchor approval | **accepted** — user 2026-11-13 "Yes, 45 clip" after the Checkpoint A review (report §12.2–12.3b: measurements, likeness, arena mocks)
- v1 anchor `87e8cfaa-9e26-47b5-9183-6caa4a690519` retired (size), kept on PixelLab, not used |

## 3. Facing and frame

| Field | Value |
|---|---|
| Sheet facing | left (`clips.json` facing; the engine flips by negative width for the other side) |
| PixelLab view / direction | low top-down / south-west |
| Frame | 92x80 art px (widened from the tier minimum so sideways motion is not cut) |
| Anchor rule | feet on the last pixel row, body centred at x = w/2 from idle frame 0 (one shift per unit); ≥ 1 transparent px left / right / top |
| Sheet | `assets/art/units/unit_fire_eater_sheet.png`, one row per clip, 1 px gutter, Aseprite-array JSON |

## 4. Palette constraints

- Locked at generation (≤ 8 of `tessera_master.gpl`, Hellfire rows added 2026-11-13): #24201E, #2C2925, #4A4640, #7A5A36, #8A6A40, #EFE6D2
- No red `#E5293B` (telegraph), no Burn orange `#FF7A1F`, no lava `#FFB21F` on the body; lava is a dull ochre crack ≤ 2 px (RENDER-STANDARDS §4 Hỏa Ngục "Không": orange veins, orange eyes).

## 5. PixelLab configuration and style reference

| Field | Value |
|---|---|
| Character id | `6a18c180-f27c-4624-bd0d-a8b3c39c7712` |
| Configuration that produced the anchor | `create_character_pro_flash`, canvas by tier (64 / 80 / 96), low top-down, 8 directions, seed 1, palette locked (max 8), style_image = Goblin Scout v3 south rotation (`3b9516c8`), colour transfer off; prompt = report §12.1 |
| Clips | `animate_character` mode pixminimax, south-west, 8 frames, 1 gen each; prompts = report §12.4 (motion only, no negative words) |
| Post-generation (free, mechanical only) | palette snap to the locked colours, 8-connected clusters < 12 px removed, feet re-planted on the last row, one horizontal shift per unit, cropped to the frame (same logic as `tools/qa/sprite_clean.gd`); never hand-painted detail (user rule) |

## 6. Animation contract

Required for a block-brain enemy: `idle`, `step`, `windup`, `hit`, `down` (the special clips are only requested for pattern brains).

| Clip | Frames | ms per frame | Loop | Status | Acceptance | Generation | Note |
|---|---|---|---|---|---|---|---|
| `idle` | 4 | 250, 250, 250, 250 | loop | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 0/2/4/6 |
| `step` | 4 | 100, 100, 100, 100 | loop | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 1/3/5/7 ; nominal; the game paces step by the step cooldown |
| `windup` | 4 | 100, 100, 100, 0 | hold_last | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 2/4/6/8, deep breath, mouth wide, held |
| `hit` | 3 | 40, 40, 40 | once | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 3/4/5 (1-2 had baked orange fire) |
| `down` | 6 | 100, 120, 150, 150, 150, 150 | hold_last | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 2/3/4/5/6/8, topples onto its belly |

## 7. Visual constraints (what a new generation must keep)

- Same anchor and character id; same canvas, feet row and feet x.
- Identity in the upper half: 60x75 south-west, 6 colours.
- 1 px closed Ink outline; banded shading; no glow, no gradient, no anti-aliasing fringe.
- Facing stays left in every frame; frames with baked effects (slashes, stars, fire) are dropped, never kept (see the hit notes).

## 8. Generation lineage

- 2026-11-13 anchor → character `6a18c180-f27c-4624-bd0d-a8b3c39c7712` (6–7 gen) after a retired v1 (6 gen) — ACCEPTED ("Yes, 45 clip")
- 2026-11-13 5 clips (5 gen) → clean-92x80 → sheet

## 9. Approval history

| Date | Event | By | Evidence |
|---|---|---|---|
| 2026-11-13 | anchor accepted, clips generated, sheet installed | user / session | report §12; in-game `production/qa/evidence/world-map-v2/region-enemies/10-hellfire-fire_eater-idle.png` |
