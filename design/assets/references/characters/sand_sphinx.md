# Master Reference — Sand Sphinx (`sand_sphinx`)

> One file per character (P1 convention). Facts come from the registry entry `unit.sand_sphinx`, `art_src/units/sand_sphinx/clips.json`, the sheet JSON and the region roster report; every claim names its source. **Approval lives in the registry** (`asset_registry.py show unit.sand_sphinx`); this file explains the character so new generations stay consistent. Unknown = no record exists; do not fill it from memory.

## 1. Identity

| Field | Value |
|---|---|
| Registry id | `unit.sand_sphinx` |
| Type / tier | unit / boss |
| Role | Enemy — warden / boss (boss t1–2, sandstorm), Sa Mạc Cát Vùi; stands on ONE cell (block brain) |
| Name (VI) | Nhân Sư Cát (`strings.csv` `boss.sand_sphinx.name`) |
| Spec / report | `production/qa/evidence/world-map-v2/region-enemy-visual-assets-progress.md` §3 (design row), region Checkpoint A/B sections |
| Design (prompt text, anchor accepted 2026-11-13) | great sphinx seated upright on its haunches (art bible §5.2 row): human-like head with a horned headdress, dark stone face with ivory eyes, an ochre belt set with dull-jade stones, two flat stone-slab wings folded behind the shoulders, tail curled round the paws, weathered sandstone body; no gold, no floating bricks, never lying horizontal. |
| Silhouette / proportions | 46x85 south-west, 7 colours; warden, 85 px tall, seated statue (v1 61b00049 at 58 px was retired as too short). |
| Likeness check | Closest: Sphinx of Giza → horns, folded slab wings, seated upright. |

## 2. Approved references and anchor

| Field | Value |
|---|---|
| Concept reference | none (text design; region direction §3 of the report, art bible §5.2 warden row for the warden) |
| Anchor image (canonical frame) | `art_src/units/sand_sphinx/idle/0.png` — idle frame 0 of the installed source (= cleaned south-west rotation); every new clip is generated from this frame or from the PixelLab character below |
| Rotation set | `design/assets/candidates/sands/sand_sphinx/rot-v2/` (south, south-west, west) |
| Anchor approval | **accepted** — user 2026-11-13 "Yes, 45 clip" after the Checkpoint A review (measurements, likeness, line-up)
- v1 anchor `61b00049-4af1-4a53-9af7-f72f15f795fe` retired (size / likeness), kept on PixelLab, not used |

## 3. Facing and frame

| Field | Value |
|---|---|
| Sheet facing | left (`clips.json` facing; the engine flips by negative width for the other side) |
| PixelLab view / direction | low top-down / south-west |
| Frame | 106x86 art px (widened from the tier minimum where a clip moves sideways or spreads) |
| Anchor rule | feet (lowest opaque row) on the last pixel row, body centred at x = w/2 from idle frame 0 (one shift per unit); ≥ 1 transparent px left / right / top |
| Sheet | `assets/art/units/unit_sand_sphinx_sheet.png`, one row per clip, 1 px gutter, Aseprite-array JSON |

## 4. Palette constraints

- Locked at generation (≤ 8 of `tessera_master.gpl`, Sa Mạc rows added 2026-11-13): #1B1722, #2C2925, #4A4640, #4F8A80, #6E6248, #8A6A40, #A89A80, #EFE6D2
- Bright region (sky V 60–72): the dark masses (Ink, #2C2925, #6E6248) sit in the upper half; beige #A89A80 only on lit faces; dull jade #4F8A80 is the region accent (RENDER-STANDARDS §4 Sa Mạc), no bright jade, no gold.

## 5. PixelLab configuration and style reference

| Field | Value |
|---|---|
| Character id | `87c9efbd-1c9f-4653-ab52-f185a5df2ca8` |
| Configuration that produced the anchor | `create_character_pro_flash`, canvas by tier (64 / 80 / 96), low top-down, 8 directions, palette locked (max 8), style_image = Goblin Scout v3 south rotation (`3b9516c8`), colour transfer off; prompt = the region's Checkpoint A table in the report |
| Clips | `animate_character` mode pixminimax, south-west, 8 frames, 1 gen each; motion-only prompts (no negative words) |
| Post-generation (free, mechanical only) | palette snap to the locked colours, 8-connected clusters < 12 px removed, feet re-planted on the last row, one horizontal shift per unit, cropped to the frame (same logic as `tools/qa/sprite_clean.gd`); never hand-painted detail (user rule) |

## 6. Animation contract

Required for a block-brain enemy: `idle`, `step`, `windup`, `hit`, `down` (the special clips are only requested for pattern brains).

| Clip | Frames | ms per frame | Loop | Status | Acceptance | Generation | Note |
|---|---|---|---|---|---|---|---|
| `idle` | 4 | 250, 250, 250, 250 | loop | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 0/2/4/6 |
| `step` | 4 | 100, 100, 100, 100 | loop | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 1/3/5/7, weight shift ; nominal; the game paces step by the step cooldown |
| `windup` | 4 | 100, 100, 100, 0 | hold_last | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 2/4/6/8, rises on forepaws, wings spread, held |
| `hit` | 3 | 40, 40, 40 | once | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 5/6/7 (2-4 had baked stone chips) |
| `down` | 6 | 100, 120, 150, 150, 150, 150 | hold_last | installed | anchor accepted 2026-11-13; clip approved by the user 2026-11-13 | 1 gen pixminimax SW 8f | src 2/3/4/5/6/8, slumps forward |

## 7. Visual constraints (what a new generation must keep)

- Same anchor and character id; same canvas, feet row and feet x.
- Identity in the upper half: 46x85 south-west, 7 colours.
- 1 px closed Ink outline; banded shading; no glow, no gradient, no anti-aliasing fringe.
- Facing stays left in every frame; frames with baked effects (slashes, projectiles, debris) are dropped, never kept (see the clip notes).

## 8. Generation lineage

- 2026-11-13 anchor → character `87c9efbd-1c9f-4653-ab52-f185a5df2ca8` (6–7 gen) after a retired v1 (6–7 gen) — ACCEPTED ("Yes, 45 clip")
- 2026-11-13 5 clips (5 gen) → clean-106x86 → sheet

## 9. Approval history

| Date | Event | By | Evidence |
|---|---|---|---|
| 2026-11-13 | anchor accepted, clips generated, sheet installed | user / session | report; in-game `production/qa/evidence/world-map-v2/region-enemies/10-sands-sand_sphinx-idle.png` |
