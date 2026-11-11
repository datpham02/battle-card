# Master Reference — Forest Witch (warden) (`forest_witch`)

> One file per character (P1, 2026-11-11). Facts come from the registry entry `unit.forest_witch`, `art_src/units/forest_witch/clips.json`, the sheet JSON and the spec; every claim names its source. **Approval lives in the registry** (`asset_registry.py show unit.forest_witch`); this file explains the character so new generations stay consistent. Unknown = no record exists; do not fill it from memory.

## 1. Identity

| Field | Value |
|---|---|
| Registry id / legacy id | `unit.forest_witch` / ASSET-020 |
| Type / tier | unit / boss |
| Role | Enemy — warden / boss of the Misty Forest; 2x2 block (D13 footprint) |
| Spec | `design/assets/specs/forest-witch-assets.md` |
| Design (approved text) | Thin hunched woman, ragged moss / dead-leaf cloak to the ground, long ivory hair, carved wooden bird-beak mask with two short branching antlers, bony hand reaching forward, twisted root staff close to her side (forest-witch-assets.md:22). Wide anchor: cloak spreading wide at the ground like the roots of an old tree, ~140 px wide (anchor-wide-01, user: 'nếu đứng 2x2 thì tôi muốn nó to ra hơn để khớp với 2x2 và đứng ở giữa'). |
| Silhouette / proportions | Wide low spread over two columns; bbox 151x112 on 160x136; 160x130 frame, feet mid-block. |
| Likeness check | Closest: Leshen (The Witcher 3). Differentiated: carved wooden bird-beak mask (no deer skull), thin woman with long ivory hair, short antlers (~12 px), no crows. User approved 2026-11-02 (forest-witch-assets.md:16). |

## 2. Approved references and anchor

| Field | Value |
|---|---|
| Concept reference | design/art/reference/08-warden-forest-01.png (described in words, never used as an image input; forest-witch-assets.md:3-5); art bible §5.2 row 'Phù thủy rừng' |
| Anchor image (canonical frame) | `art_src/units/forest_witch/idle/0.png` — idle frame 0 of the installed source; every new clip is generated from this frame or from the PixelLab character below |
| Rotation set | `design/assets/candidates/forest-witch`, `design/assets/candidates/forest-witch/anim-wide`, `design/assets/candidates/forest-witch/clean-160x130` |
| Anchor approval | **approved** — art_src/units/forest_witch/clips.json source: "wide anchor (job ad5b2658, 160x136, approved 2026-11-02)"; design/assets/specs/forest-witch-assets.md row anchor-wide-01 |

## 3. Facing and frame

| Field | Value |
|---|---|
| Sheet facing | left (`clips.json` facing; the engine flips by negative width for the other side) |
| PixelLab view / direction | low top-down / south-west |
| Frame | 160x130 art px |
| Anchor rule | feet on the last pixel row, feet x = 80; ≥ 1 transparent px left / right / top (`export_sheets.py` refuses otherwise) |
| Sheet | `assets/art/units/unit_forest_witch_sheet.png` 1287x1309, one row per clip, 1 px gutter, Aseprite-array JSON |

## 4. Palette constraints

- Locked at generation: Ink #1B1722; moss #3A4538 / #4A5545 / #5E6B55; bark #4A3A2A; mask and antlers #8A7350 / #B89A6A; hair and hands #EFE6D2. No red, no glow (forest-witch-assets.md:12).
- In the installed sheet (`meta.tessera.palette`, 8 colours): `#1B1722`, `#3A4538`, `#4A3A2A`, `#4A5545`, `#5E6B55`, `#8A7350`, `#B89A6A`, `#EFE6D2`
- Master: `art_src/palette/tessera_master.gpl`; ≤ 8 colours per unit; alpha 0 / 255 only; no red `#E5293B` (telegraph), no orange baked in (Burn); adding a colour is the art-director's call (bible §8.4).

## 5. PixelLab configuration and style reference

| Field | Value |
|---|---|
| Character id | — |
| Image / job ids on record | 3e710e28-5599-5f09-9182-bdeca58fe4f6, f34c2791-e76b-4323-b763-ef34e23e9aee (anchor-01), ad5b2658-4e4b-4c3f-a899-81d6953dd415 (anchor-wide-01, image 3e710e28-5599-5f09-9182-bdeca58fe4f6), d6a72828-dfe1-4f30-a33b-9d4cf9040ad4 (idle narrow), 11cedb7b (idle wide), 1e70b409, 43707dfd, a6148199, 87fa7a7b (moves), 914a5475 (windup), 86c84a4a (windup_heavy), 292d2aee (phase_shift), 86e41cc6 (hit), 174ed270 (down) |
| Configuration that produced the anchor and clips | Anchor: create_image_pro_flash 160x136, seed 1, palette locked (max 8), style_image = anchor-01 (source_image_id 9c5a2e55) (forest-witch-assets.md:25). Clips: animate_image_pixminimax x10, first frame = anchor-wide-01, 8 frames, south-west, seed 1 (forest-witch-assets.md:26). |
| Style reference (style_image lineage) | Her own narrow anchor-01 (image 9c5a2e55) as style_image for the wide anchor; no hero / goblin style image. |
| Post-generation (free, mechanical only) | palette snap to the locked colours, specks < 12 px removed, feet re-planted on the last row, body recentred; region recolour when the model drifted (Knight cape); never hand-painted detail (user rule) |

## 6. Animation contract

Required for a boss (art bible §5.4 / §8.6): `idle`, `step`, `windup`, `hit`, `down`.
Optional clips the code plays when present (fallback otherwise): `step_forward`, `step_back`, `step_up`, `step_down`, `windup_heavy`, `phase_shift`.

**Missing required clips:** `step`.

| Clip | Frames | ms per frame | Loop | Status | Acceptance | Generation | Note |
|---|---|---|---|---|---|---|---|
| `idle` | 4 | 300 | loop | installed | accepted 2026-11-02 | — |  |
| `step_forward` | 7 | 50 | once | installed | accepted 2026-11-02 | — | OSFE-style dash toward her front (left); the game glides the unit |
| `step_back` | 7 | 50 | once | installed | accepted 2026-11-02 | — |  |
| `step_up` | 5 | 50 | once | installed | accepted 2026-11-02 | — | src frames 1, 2, 3, 2, 1: from frame 4 the model turned her back |
| `step_down` | 7 | 50 | once | installed | accepted 2026-11-02 | — |  |
| `windup` | 3 | 100, 100, 0 | hold_last | installed | accepted 2026-11-02 | — | common skills: the reaching hand raised to the shoulder, held while the skill winds up and warns |
| `windup_heavy` | 3 | 100, 100, 0 | hold_last | installed | accepted 2026-11-02 | — | uninterruptible skills (entangled_row, withered_crown, forest_last_knot): the staff planted with both hands, held |
| `phase_shift` | 8 | 120, 120, 120, 120, 150, 150, 150, 200 | hold_last | installed | accepted 2026-11-02 | — | phase transition (1.5 s): doubles over, straightens taller |
| `hit` | 3 | 40 | once | installed | accepted 2026-11-02 | — | src frames 2-4 (frame 1 had a baked slash smear) |
| `down` | 6 | 100, 100, 120, 120, 150, 150 | hold_last | installed | accepted 2026-11-02 | — | defeat: sinks to her knees, collapses, the staff falls flat |

Timing rules: `idle` 125 ms (heroes) / 250–300 ms (enemies) per frame today (bible §8.6 says 0.4 s — the installed timing is the user's accepted feel); `step` is nominal, the game paces it by the step cooldown; `windup` ends on a 0 ms frame held until the telegraph ends; hero casts share the Knight's 9-slot timing 83, 83, 83, 83, 200 (hold frame 4), 50, 83, 100, 133 with the release on frame 5.

## 7. Visual constraints (what a new generation must keep)

- Same anchor: generate from `art_src/units/forest_witch/idle/0.png` (or the character id) with the first frame pinned; for one-shot clips pin the last frame too.
- Same canvas 160x130, same feet row and feet x; the exporter bottom-aligns shorter sources, never taller ones.
- Identity in the upper half: Wide low spread over two columns; bbox 151x112 on 160x136; 160x130 frame, feet mid-block.
- 1 px closed Ink outline; banded shading, light from the upper left; no glow, no smooth gradients, no anti-aliasing fringe (ART_QA_CHECKLIST §B–§D).
- Facing stays left in every frame (the model sometimes turns the back from frame 4: drop those frames, as for the Witch's step_up).
- Effects (bursts, stars, slash smears, red sprays) are never part of the body: delete or drop the frame; VFX are separate packs.
- Allowed variation: pose, cloth / hair / tendril sway, breathing 1–2 px, held weapon angle; not allowed: palette drift, proportions, props disappearing, new accessories.

## 8. Generation lineage

- 2026-11-02 anchor-01 create_image_pro_flash 128x128 → job f34c2791, image 9c5a2e55 (6 gen) — approved as narrow v1, then superseded
- 2026-11-02 anim-idle (1 gen) + anim-9clips (9 gen) → clean-128x125 (history)
- 2026-11-02 anchor-wide-01 create_image_pro_flash 160x136 → job ad5b2658, image 3e710e28 (6 gen) — APPROVED
- 2026-11-02 anim-wide-10clips (10 gen) → clean-160x130 → sheet 1287x1309; clips accepted (session note)

## 9. Versions

- **Current:** wide 160x130
- **Retired:**
  - narrow v1 128x125 — paths `design/assets/candidates/forest-witch/clean-128x125`, `design/assets/candidates/forest-witch/anim` — forest-witch-assets.md rows anchor-01 / anim-9clips, superseded by anchor-wide-01 (user: 'nếu đứng 2x2 thì tôi muốn nó to ra hơn')
- **Rejected:**
  - narrow v1 128x125 body: 'the thin 85 px body did not read as four cells' (forest-witch-assets.md:25) — kept as history in candidates/forest-witch/anim, clean-128x125

## 10. Approval history (from the registry)

| Date | Event | Target | By | Evidence / note |
|---|---|---|---|---|
| 2026-11-11 | registered | asset | — | bootstrapped from disk by asset_registry.py; status by location only |
| 2026-11-02 | user_approved installed→approved | asset | user | art_src/units/forest_witch/clips.json source: "wide anchor (job ad5b2658, 160x136, approved 2026-11-02)"; design/assets/specs/forest-witch-assets.md row anchor-wide-01 |
| 2026-11-02 | user_accepted | asset | user | production/session-state/active.md 2026-11-02 entry: 10 clips (approved, 10 gen) — session note |
| 2026-11-11 | note | asset | — | Master Reference created: design/assets/references/characters/forest_witch.md |

## 11. Open points

- clip acceptance is recorded only in the gitignored session state (registry: accepted, session note)
- step_up has 5 frames: from frame 4 the model turned her back

Evidence folders: `production/qa/evidence/forest-witch-sprite`, `production/qa/evidence/boss-footprint`
