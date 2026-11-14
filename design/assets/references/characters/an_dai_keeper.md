# Master Reference — Heart Keeper (`an_dai_keeper`)

> One file per character (P1 convention). Facts come from the registry entry `unit.an_dai_keeper`, `art_src/units/an_dai_keeper/clips.json`, the sheet JSON and the region roster report; every claim names its source. **Approval lives in the registry** (`asset_registry.py show unit.an_dai_keeper`); this file explains the character so new generations stay consistent. Unknown = no record exists; do not fill it from memory.

## 1. Identity

| Field | Value |
|---|---|
| Registry id | `unit.an_dai_keeper` |
| Type / tier | unit / boss |
| Role | Final boss of the Lattice Heart (an_dai chapter, block brain, two phases, casts hero cards); stands on ONE cell |
| Name (VI) | Người Giữ Tâm Lưới (`strings.csv` `boss.an_dai_keeper.name`) |
| Spec / report | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` §3 (design row), region Checkpoint A/B sections |
| Design (prompt text, anchor accepted 2026-11-13) | tall hooded guardian (art bible 5.2 Keeper row): warm ivory-grey layered robe with a dark indigo panel down the front, deep hood with an empty dark face, shoulder mantle of small square stone tiles, thin cloth ribbons, one open palm held forward. The 3 Lattice Light shards above the head are drawn by code, not in the sheet. SIZE EXCEPTION accepted by the user 2026-11-14: about 73 px, smaller than the wardens, because the Goblin style image fixes humanoid scale near 70 px (3 anchors tried: 66, 73, 72 px; v3 e180e48a on 120x120 also retired). |
| Silhouette / proportions | 40x73 south-west, 6 colours. |
| Likeness check | Closest: Nazgul / Ringwraith → ivory robe, indigo panel, ribbons, open palm. |

## 2. Approved references and anchor

| Field | Value |
|---|---|
| Concept reference | none (text design; region direction §3 of the report, art bible §5.2 warden row for the warden) |
| Anchor image (canonical frame) | `art_src/units/an_dai_keeper/idle/0.png` — idle frame 0 of the installed source (= cleaned south-west rotation); every new clip is generated from this frame or from the PixelLab character below |
| Rotation set | `design/assets/candidates/lattice_heart/an_dai_keeper/rot-v2/` (south, south-west, west) |
| Anchor approval | **accepted** — user 2026-11-13 "Yes, 45 clip" after the Checkpoint A review (measurements, likeness, line-up)
- v1 anchor `1dacabeb-7c93-4289-925a-69f52206ad2d` retired (size / likeness), kept on PixelLab, not used |

## 3. Facing and frame

| Field | Value |
|---|---|
| Sheet facing | left (`clips.json` facing; the engine flips by negative width for the other side) |
| PixelLab view / direction | low top-down / south-west |
| Frame | 96x84 art px (widened from the tier minimum where a clip moves sideways or spreads) |
| Anchor rule | feet (lowest opaque row) on the last pixel row, body centred at x = w/2 from idle frame 0 (one shift per unit); ≥ 1 transparent px left / right / top |
| Sheet | `assets/art/units/unit_an_dai_keeper_sheet.png`, one row per clip, 1 px gutter, Aseprite-array JSON |

## 4. Palette constraints

- Locked at generation (≤ 8 of `tessera_master.gpl`, Tâm Lưới rows added 2026-11-13): #1B1722, #2E3450, #4C5266, #6A6B62, #A89A80, #D8CDB0, #EFE6D2
- Lattice Heart: night indigo #2E3450 panel, warm ivory-grey robe (#A89A80, #D8CDB0, #EFE6D2); no gold on the body, the Lattice Light #FFD45C shards are drawn by code

## 5. PixelLab configuration and style reference

| Field | Value |
|---|---|
| Character id | `d32ddbf9-a403-4f4d-a246-50d958d79363` |
| Configuration that produced the anchor | `create_character_pro_flash`, canvas by tier (64 / 80 / 96), low top-down, 8 directions, palette locked (max 8), style_image = Goblin Scout v3 south rotation (`3b9516c8`), colour transfer off; prompt = the region's Checkpoint A table in the report |
| Clips | `animate_character` mode pixminimax, south-west, 8 frames, 1 gen each; motion-only prompts (no negative words) |
| Post-generation (free, mechanical only) | palette snap to the locked colours, 8-connected clusters < 12 px removed, feet re-planted on the last row, one horizontal shift per unit, cropped to the frame (same logic as `tools/qa/sprite_clean.gd`); never hand-painted detail (user rule) |

## 6. Animation contract

Required for a block-brain enemy: `idle`, `step`, `windup`, `hit`, `down` (the special clips are only requested for pattern brains).

| Clip | Frames | ms per frame | Loop | Status | Acceptance | Generation | Note |
|---|---|---|---|---|---|---|---|
| `idle` | 4 | 250, 250, 250, 250 | loop | installed | anchor accepted 2026-11-13; clip not yet reviewed by the user | 1 gen pixminimax SW 8f | src 0/2/4/6, slow breathing, ribbons drifting |
| `step` | 4 | 100, 100, 100, 100 | loop | installed | anchor accepted 2026-11-13; clip not yet reviewed by the user | 1 gen pixminimax SW 8f | src 1/3/5/7, glide ; nominal; the game paces step by the step cooldown |
| `windup` | 4 | 100, 100, 100, 0 | hold_last | installed | anchor accepted 2026-11-13; clip not yet reviewed by the user | 1 gen pixminimax SW 8f | src 2/4/6/8, both hands raised wide, held (a small yellow tassel was snapped to the palette) |
| `hit` | 3 | 40, 40, 40 | once | installed | anchor accepted 2026-11-13; clip not yet reviewed by the user | 1 gen pixminimax SW 8f | src 3/4/5, sways back |
| `down` | 6 | 100, 120, 150, 150, 150, 150 | hold_last | installed | anchor accepted 2026-11-13; clip not yet reviewed by the user | 1 gen pixminimax SW 8f | src 2/3/4/5/6/8, sinks into a heap of cloth |

## 7. Visual constraints (what a new generation must keep)

- Same anchor and character id; same canvas, feet row and feet x.
- Identity in the upper half: 40x73 south-west, 6 colours.
- 1 px closed Ink outline; banded shading; no glow, no gradient, no anti-aliasing fringe.
- Facing stays left in every frame; frames with baked effects (slashes, projectiles, debris) are dropped, never kept (see the clip notes).

## 8. Generation lineage

- 2026-11-13 anchor → character `d32ddbf9-a403-4f4d-a246-50d958d79363` (6–7 gen) after a retired v1 (6–7 gen) — ACCEPTED ("Yes, 45 clip")
- 2026-11-13 5 clips (5 gen) → clean-96x84 → sheet

## 9. Approval history

| Date | Event | By | Evidence |
|---|---|---|---|
| 2026-11-13 | anchor accepted, clips generated, sheet installed | user / session | report; in-game `production/qa/evidence/world-map-v2/region-enemies/10-lattice_heart-an_dai_keeper-idle.png` |
