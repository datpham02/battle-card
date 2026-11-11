# Master Reference — Wolf Alpha (elite) (`wolf_alpha`)

> One file per character (P1, 2026-11-11). Facts come from the registry entry `unit.wolf_alpha`, `art_src/units/wolf_alpha/clips.json`, the sheet JSON and the spec; every claim names its source. **Approval lives in the registry** (`asset_registry.py show unit.wolf_alpha`); this file explains the character so new generations stay consistent. Unknown = no record exists; do not fill it from memory.

## 1. Identity

| Field | Value |
|---|---|
| Registry id / legacy id | `unit.wolf_alpha` / ASSET-028 |
| Type / tier | unit / elite |
| Role | Enemy — elite tier, Misty Forest roster v2 (howl = interrupt window) |
| Spec | `design/assets/specs/misty-forest-roster-assets.md` |
| Design (approved text) | Heavy-set alpha dire wolf on all four legs, broad chest, dark stone-grey fur, thick pale ash-silver mane over neck and shoulders, three pale claw scars on the muzzle, a ring of dark thorny briar round the neck, long fangs, bushy low tail (ASSET-028 Design). |
| Silhouette / proportions | Fills the cell width; south-west bbox 58x55 (Dire Wolf 46x43), 7 colours; 80x80 frame, feet x = 40. |
| Likeness check | Closest: Moro (Princess Mononoke) or Ghost (Game of Thrones). Differentiated: dark grey body, only the mane pale, claw scars, briar ring, not god-sized. |

## 2. Approved references and anchor

| Field | Value |
|---|---|
| Concept reference | none (doi-hinh-rung-suong quick spec §3.4) |
| Anchor image (canonical frame) | `art_src/units/wolf_alpha/idle/0.png` — idle frame 0 of the installed source; every new clip is generated from this frame or from the PixelLab character below |
| Rotation set | `design/assets/candidates/wolf-alpha/rot`, `design/assets/candidates/wolf-alpha/anim`, `design/assets/candidates/wolf-alpha/clean-80x80` |
| Anchor approval | **approved** — art_src/units/wolf_alpha/clips.json source: "approved 2026-11-04" |

## 3. Facing and frame

| Field | Value |
|---|---|
| Sheet facing | left (`clips.json` facing; the engine flips by negative width for the other side) |
| PixelLab view / direction | low top-down / south-west |
| Frame | 80x80 art px |
| Anchor rule | feet on the last pixel row, feet x = 40; ≥ 1 transparent px left / right / top (`export_sheets.py` refuses otherwise) |
| Sheet | `assets/art/units/unit_wolf_alpha_sheet.png` 485x485, one row per clip, 1 px gutter, Aseprite-array JSON |

## 4. Palette constraints

- Locked at generation: Ink #1B1722; fur #2C2925 / #4A4640 / #5A5650 / #6A6B62; mane #D8CDB0; eyes / fangs / scars #EFE6D2; briar #4A3A2A. No red, no glow.
- In the installed sheet (`meta.tessera.palette`, 8 colours): `#1B1722`, `#2C2925`, `#4A3A2A`, `#4A4640`, `#5A5650`, `#6A6B62`, `#D8CDB0`, `#EFE6D2`
- Master: `art_src/palette/tessera_master.gpl`; ≤ 8 colours per unit; alpha 0 / 255 only; no red `#E5293B` (telegraph), no orange baked in (Burn); adding a colour is the art-director's call (bible §8.4).

## 5. PixelLab configuration and style reference

| Field | Value |
|---|---|
| Character id | 76e105ae-6ec5-49b5-ab3b-5bacaf99a17f |
| Image / job ids on record | 09d03dc5, 8fcc8ec0, e67295e8, 96b6d0f1, db38c1f8, bd63c977 (clip groups) |
| Configuration that produced the anchor and clips | create_character_pro_flash 80x80, low top-down, 8 directions, seed 1, template `dog`, palette locked (max 8), style_image = Goblin v3 south rotation (colour off). Clips: animate_character pixminimax south-west, 8 frames (6 gen incl. howl). |
| Style reference (style_image lineage) | Goblin Scout v3 south rotation; `dog` template. |
| Post-generation (free, mechanical only) | palette snap to the locked colours, specks < 12 px removed, feet re-planted on the last row, body recentred; region recolour when the model drifted (Knight cape); never hand-painted detail (user rule) |

## 6. Animation contract

Required for a elite (art bible §5.4 / §8.6): `idle`, `step`, `windup`, `hit`, `down`.
Optional clips the code plays when present (fallback otherwise): `brace`, `guard`, `stunned`, `howl`.

| Clip | Frames | ms per frame | Loop | Status | Acceptance | Generation | Note |
|---|---|---|---|---|---|---|---|
| `idle` | 4 | 250 | loop | installed | unknown | — | src frames 0/2/4/6 |
| `step` | 4 | 100 | loop | installed | unknown | — | nominal; the game paces step by the step cooldown; src 1/3/5/7 |
| `windup` | 4 | 100, 100, 100, 0 | hold_last | installed | unknown | — | crouches to lunge, held until the telegraph ends; src 2/4/6/8 (the red mouth snapped to the fur greys) |
| `howl` | 4 | 150, 150, 150, 0 | hold_last | installed | unknown | — | sits back and howls at the sky, held for the rest of the 1.4 s wind-up (the interrupt window); src 2/3/5/8 |
| `hit` | 3 | 40 | once | installed | unknown | — | src frames 3-5 (1-2 had a baked red spray) |
| `down` | 6 | 100, 120, 150, 150, 150, 150 | hold_last | installed | unknown | — | slumps onto its side; src 2/3/4/5/6/8 |

Timing rules: `idle` 125 ms (heroes) / 250–300 ms (enemies) per frame today (bible §8.6 says 0.4 s — the installed timing is the user's accepted feel); `step` is nominal, the game paces it by the step cooldown; `windup` ends on a 0 ms frame held until the telegraph ends; hero casts share the Knight's 9-slot timing 83, 83, 83, 83, 200 (hold frame 4), 50, 83, 100, 133 with the release on frame 5.

## 7. Visual constraints (what a new generation must keep)

- Same anchor: generate from `art_src/units/wolf_alpha/idle/0.png` (or the character id) with the first frame pinned; for one-shot clips pin the last frame too.
- Same canvas 80x80, same feet row and feet x; the exporter bottom-aligns shorter sources, never taller ones.
- Identity in the upper half: Fills the cell width; south-west bbox 58x55 (Dire Wolf 46x43), 7 colours; 80x80 frame, feet x = 40.
- 1 px closed Ink outline; banded shading, light from the upper left; no glow, no smooth gradients, no anti-aliasing fringe (ART_QA_CHECKLIST §B–§D).
- Facing stays left in every frame (the model sometimes turns the back from frame 4: drop those frames, as for the Witch's step_up).
- Effects (bursts, stars, slash smears, red sprays) are never part of the body: delete or drop the frame; VFX are separate packs.
- Allowed variation: pose, cloth / hair / tendril sway, breathing 1–2 px, held weapon angle; not allowed: palette drift, proportions, props disappearing, new accessories.

## 8. Generation lineage

- 2026-11-04 anchor-01 → character 76e105ae (6 gen) — APPROVED
- 2026-11-04 anim-6clips (6 gen) → clean-80x80 → sheet

## 9. Versions

- **Current:** installed sheet, see §3

## 10. Approval history (from the registry)

| Date | Event | Target | By | Evidence / note |
|---|---|---|---|---|
| 2026-11-11 | registered | asset | — | bootstrapped from disk by asset_registry.py; status by location only |
| 2026-11-04 | user_approved installed→approved | asset | user | art_src/units/wolf_alpha/clips.json source: "approved 2026-11-04" |
| 2026-11-11 | note | asset | — | Master Reference created: design/assets/references/characters/wolf_alpha.md |

## 11. Open points

- none recorded

Evidence folders: `production/qa/evidence/misty-forest-roster`, `production/qa/evidence/misty-forest-roster-v2`
