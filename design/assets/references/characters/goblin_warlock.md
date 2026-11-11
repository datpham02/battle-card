# Master Reference — Goblin Warlock (boss) (`goblin_warlock`)

> One file per character (P1, 2026-11-11). Facts come from the registry entry `unit.goblin_warlock`, `art_src/units/goblin_warlock/clips.json`, the sheet JSON and the spec; every claim names its source. **Approval lives in the registry** (`asset_registry.py show unit.goblin_warlock`); this file explains the character so new generations stay consistent. Unknown = no record exists; do not fill it from memory.

## 1. Identity

| Field | Value |
|---|---|
| Registry id / legacy id | `unit.goblin_warlock` / ASSET-029 |
| Type / tier | unit / boss |
| Role | Enemy — boss tier (floor 1–2), Misty Forest roster v2; 2x2 block |
| Spec | `design/assets/specs/misty-forest-roster-assets.md` |
| Design (approved text) | Huge hunched old goblin warlock: long sideways ears, olive skin, wrinkled face, pale eyes, crooked fangs, tall bent stitched-leather hat, ragged leather robe spreading at the ground, a huge pack of stacked square grey stone tiles on his back, a stone tile in one raised hand, a crooked staff topped by a cage of small tiles (ASSET-029 Design). |
| Silhouette / proportions | Fills the 2x2 block; bbox 118x121 on a 160x136 image; 160x130 frame, feet x = 80. |
| Likeness check | Closest: the Great Goblin (The Hobbit). Differentiated: stooped old caster, not fat; no crown; tall leather hat; the pack of stolen square tiles. |

## 2. Approved references and anchor

| Field | Value |
|---|---|
| Concept reference | none (doi-hinh-rung-suong quick spec §3.5) |
| Anchor image (canonical frame) | `art_src/units/goblin_warlock/idle/0.png` — idle frame 0 of the installed source; every new clip is generated from this frame or from the PixelLab character below |
| Rotation set | `design/assets/candidates/goblin-warlock`, `design/assets/candidates/goblin-warlock/anim`, `design/assets/candidates/goblin-warlock/clean-160x130` |
| Anchor approval | **approved** — art_src/units/goblin_warlock/clips.json source: "Pro Flash image 450b57de (anchor 64f0b5de + skin edit, approved 2026-11-04)" |

## 3. Facing and frame

| Field | Value |
|---|---|
| Sheet facing | left (`clips.json` facing; the engine flips by negative width for the other side) |
| PixelLab view / direction | low top-down / south-west |
| Frame | 160x130 art px |
| Anchor rule | feet on the last pixel row, feet x = 80; ≥ 1 transparent px left / right / top (`export_sheets.py` refuses otherwise) |
| Sheet | `assets/art/units/unit_goblin_warlock_sheet.png` 804x916, one row per clip, 1 px gutter, Aseprite-array JSON |

## 4. Palette constraints

- Locked at generation: Ink #1B1722; skin #7D8B5A / #59643F; leather #9A7D5E / #66523F; stolen tiles #4A4640 / #6A6B62; eyes / fangs #EFE6D2. No red, no glow.
- In the installed sheet (`meta.tessera.palette`, 8 colours): `#1B1722`, `#4A4640`, `#59643F`, `#66523F`, `#6A6B62`, `#7D8B5A`, `#9A7D5E`, `#EFE6D2`
- Master: `art_src/palette/tessera_master.gpl`; ≤ 8 colours per unit; alpha 0 / 255 only; no red `#E5293B` (telegraph), no orange baked in (Burn); adding a colour is the art-director's call (bible §8.4).

## 5. PixelLab configuration and style reference

| Field | Value |
|---|---|
| Character id | — |
| Image / job ids on record | 64f0b5de-be9d-54e1-a382-200240164135, 450b57de-0f40-5824-b6a1-95879b9699d9, bcf74085 (anchor-01 image 64f0b5de-be9d-54e1-a382-200240164135), 475694ae (edit-01 image 450b57de-0f40-5824-b6a1-95879b9699d9), 40e79e5f, 62bd96c4, 7a0527a4, 081827ad, 80d476f0, 8a32e20b (clips) |
| Configuration that produced the anchor and clips | Anchor: create_image_pro_flash 160x136, seed 1, no_background, palette locked (max 8), style_image = Goblin v3 south rotation (colour off) → image 64f0b5de; skin recolour edit_image_pro_flash (text) → image 450b57de (21 colours, snapped to the 8 locked ones for free). Clips: animate_image_pixminimax x7, first frame = the snapped edit (uploaded), 8 frames, seed 1, low top-down. |
| Style reference (style_image lineage) | Goblin Scout v3 south rotation; single-image anchor (no 8-direction character). |
| Post-generation (free, mechanical only) | palette snap to the locked colours, specks < 12 px removed, feet re-planted on the last row, body recentred; region recolour when the model drifted (Knight cape); never hand-painted detail (user rule) |

## 6. Animation contract

Required for a boss (art bible §5.4 / §8.6): `idle`, `step`, `windup`, `hit`, `down`.
Optional clips the code plays when present (fallback otherwise): `step_forward`, `step_back`, `step_up`, `step_down`, `windup_heavy`, `phase_shift`.

| Clip | Frames | ms per frame | Loop | Status | Acceptance | Generation | Note |
|---|---|---|---|---|---|---|---|
| `idle` | 4 | 250 | loop | installed | unknown | — | src frames 0/2/4/6 |
| `step` | 4 | 100 | loop | installed | unknown | — | the row blink; src 1/3/5/7 |
| `windup` | 4 | 100, 100, 100, 0 | hold_last | installed | unknown | — | hex bolt / curse lane; src 2/4/6/8 |
| `windup_heavy` | 4 | 100, 100, 120, 0 | hold_last | installed | unknown | — | heaves a stone tile overhead for stolen_shape / twin_shapes; src 2/3/4/6 |
| `phase_shift` | 4 | 200 | loop | installed | unknown | — | src 1/3/5/7 |
| `hit` | 3 | 40 | once | installed | unknown | — | src frames 5-7 (1-4 had a baked red burst) |
| `down` | 5 | 120, 150, 150, 150, 150 | hold_last | installed | unknown | — | collapses, tiles spill; src 2/3/4/5/8 (6-7 had a red blob, 1-3 a cyan glint, snapped / removed) |

Timing rules: `idle` 125 ms (heroes) / 250–300 ms (enemies) per frame today (bible §8.6 says 0.4 s — the installed timing is the user's accepted feel); `step` is nominal, the game paces it by the step cooldown; `windup` ends on a 0 ms frame held until the telegraph ends; hero casts share the Knight's 9-slot timing 83, 83, 83, 83, 200 (hold frame 4), 50, 83, 100, 133 with the release on frame 5.

## 7. Visual constraints (what a new generation must keep)

- Same anchor: generate from `art_src/units/goblin_warlock/idle/0.png` (or the character id) with the first frame pinned; for one-shot clips pin the last frame too.
- Same canvas 160x130, same feet row and feet x; the exporter bottom-aligns shorter sources, never taller ones.
- Identity in the upper half: Fills the 2x2 block; bbox 118x121 on a 160x136 image; 160x130 frame, feet x = 80.
- 1 px closed Ink outline; banded shading, light from the upper left; no glow, no smooth gradients, no anti-aliasing fringe (ART_QA_CHECKLIST §B–§D).
- Facing stays left in every frame (the model sometimes turns the back from frame 4: drop those frames, as for the Witch's step_up).
- Effects (bursts, stars, slash smears, red sprays) are never part of the body: delete or drop the frame; VFX are separate packs.
- Allowed variation: pose, cloth / hair / tendril sway, breathing 1–2 px, held weapon angle; not allowed: palette drift, proportions, props disappearing, new accessories.

## 8. Generation lineage

- 2026-11-04 anchor-01 create_image_pro_flash → image 64f0b5de (job bcf74085, 6 gen)
- 2026-11-04 edit-01 edit_image_pro_flash → image 450b57de (job 475694ae, 6 gen 'Xài 6 Gen') — APPROVED anchor after palette snap
- 2026-11-04 anim-7clips (7 gen) → clean-160x130 → sheet

## 9. Versions

- **Current:** installed sheet, see §3

## 10. Approval history (from the registry)

| Date | Event | Target | By | Evidence / note |
|---|---|---|---|---|
| 2026-11-11 | registered | asset | — | bootstrapped from disk by asset_registry.py; status by location only |
| 2026-11-04 | user_approved installed→approved | asset | user | art_src/units/goblin_warlock/clips.json source: "Pro Flash image 450b57de (anchor 64f0b5de + skin edit, approved 2026-11-04)" |
| 2026-11-11 | note | asset | — | Master Reference created: design/assets/references/characters/goblin_warlock.md |

## 11. Open points

- hit / down had baked red bursts, snapped or dropped (clips.json notes)

Evidence folders: `production/qa/evidence/misty-forest-roster`, `production/qa/evidence/misty-forest-roster-v2`
