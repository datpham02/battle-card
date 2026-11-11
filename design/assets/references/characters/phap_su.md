# Master Reference — Mage (Pháp sư) (`phap_su`)

> One file per character (P1, 2026-11-11). Facts come from the registry entry `unit.phap_su`, `art_src/units/phap_su/clips.json`, the sheet JSON and the spec; every claim names its source. **Approval lives in the registry** (`asset_registry.py show unit.phap_su`); this file explains the character so new generations stay consistent. Unknown = no record exists; do not fill it from memory.

## 1. Identity

| Field | Value |
|---|---|
| Registry id / legacy id | `unit.phap_su` / ASSET-030 |
| Type / tier | unit / hero |
| Role | Player hero — Mage (Pháp sư); ember blocks |
| Spec | `design/assets/specs/mage-assets.md` |
| Design (approved text) | Chibi ~4 heads, huge wide-brim witch hat bent back with two amber stripes, amber band and a cord with an amber pompom, messy ash-silver hair, brown capelet with amber edge, long brown robe open at the front with an amber-lined hem, square amber buckle, cream under-robe, brown boots, open book in one hand (mage-assets.md:20 anchor-02 prompt; art bible §5.1 row Pháp sư). |
| Silhouette / proportions | Tall thin triangle (bible §5.1); south-east bbox 32x58 at the anchor, 8 px shorter than the Knight (mage-assets.md:20); the robe was stretched 7 rows at cleanup so the sheet body is 32x65 (clips.json source). |
| Likeness check | Closest: Frieren (silver hair, book) and Vivi (hat); differs by the visible human face, bent hat with tassel, charcoal robe with amber trim (mage-assets.md:14,20). |

## 2. Approved references and anchor

| Field | Value |
|---|---|
| Concept reference | design/art/reference/04-mage-01.png (user chose its open book 2026-11-04: 'Cầm sách, như ảnh mẫu'; mage-assets.md:19) |
| Anchor image (canonical frame) | `art_src/units/phap_su/idle/0.png` — idle frame 0 of the installed source; every new clip is generated from this frame or from the PixelLab character below |
| Rotation set | `design/assets/candidates/mage/rot02`, `design/assets/candidates/mage/anim02`, `design/assets/candidates/mage/anim03` |
| Anchor approval | **installed** — acceptance unknown |
| Attention | anchor result never recorded as approved: design/assets/specs/mage-assets.md rows anchor-02 / anim03-idle-v3 record per-call approval only. Confirm the current anchor, or name the fix. |

## 3. Facing and frame

| Field | Value |
|---|---|
| Sheet facing | right (`clips.json` facing; the engine flips by negative width for the other side) |
| PixelLab view / direction | low top-down / south-east |
| Frame | 96x70 art px |
| Anchor rule | feet on the last pixel row, feet x = 48; ≥ 1 transparent px left / right / top (`export_sheets.py` refuses otherwise) |
| Sheet | `assets/art/units/unit_phap_su_sheet.png` 872x851, one row per clip, 1 px gutter, Aseprite-array JSON |

## 4. Palette constraints

- Locked at generation: Ink #1B1722; robe #3A2A26 / #4A3A2A / #66523F; amber #F0A030; hair #D8CDB0 / #EFE6D2; skin #E3B99A. No red, no glow (mage-assets.md:13).
- In the installed sheet (`meta.tessera.palette`, 8 colours): `#1B1722`, `#3A2A26`, `#4A3A2A`, `#66523F`, `#D8CDB0`, `#E3B99A`, `#EFE6D2`, `#F0A030`
- Master: `art_src/palette/tessera_master.gpl`; ≤ 8 colours per unit; alpha 0 / 255 only; no red `#E5293B` (telegraph), no orange baked in (Burn); adding a colour is the art-director's call (bible §8.4).

## 5. PixelLab configuration and style reference

| Field | Value |
|---|---|
| Character id | 89dc779e-091a-49a7-96bb-79126a0433eb |
| Image / job ids on record | 91b7bd35-d73e-45bf-9c33-fb8d5e4b74ba (idle v3), 60bf9be2-7bb0-46ca-a2b6-921b5d86e305 (idle v2), 3a75d836 (step), 303e532f (cast), 60758c69 (victory) |
| Configuration that produced the anchor and clips | create_character_pro_flash, asked 80x96 (returned 96x96), low top-down, 8 directions, seed 5, palette locked (max 8), style_image = Knight v3 south rotation (colour off) (mage-assets.md:20). Clips: animate_image_pixminimax, first frame = rot02/south-east-long.png (upload 8a9a1cad for idle v3), 8 frames, seed 1, positive motion words only (negative words painted the Mage red: mage-assets.md:23-24). |
| Style reference (style_image lineage) | Knight v3 south rotation 64 (style_image, colour off). |
| Post-generation (free, mechanical only) | palette snap to the locked colours, specks < 12 px removed, feet re-planted on the last row, body recentred; region recolour when the model drifted (Knight cape); never hand-painted detail (user rule) |

## 6. Animation contract

Required for a hero (art bible §5.4 / §8.6): `idle`, `step`, `cast_gesture`, `hit`, `victory`, `defeat`, `awaken`, `fall`.
Optional clips the code plays when present (fallback otherwise): `draw`, `step_forward`, `step_back`, `step_up`, `step_down`, `cast_hand`, `cast_forward`, `cast_summon`.

| Clip | Frames | ms per frame | Loop | Status | Acceptance | Generation | Note |
|---|---|---|---|---|---|---|---|
| `idle` | 8 | 125 | loop | installed | unknown | — |  |
| `draw` | 8 | 60, 60, 80, 80, 80, 80, 80, 120 | once | installed | unknown | — |  |
| `step` | 4 | 100 | loop | installed | unknown | — |  |
| `step_forward` | 7 | 50 | once | installed | unknown | — |  |
| `step_back` | 7 | 50 | once | installed | unknown | — |  |
| `step_down` | 7 | 50 | once | installed | unknown | — |  |
| `cast_gesture` | 9 | 83, 83, 83, 83, 200, 50, 83, 100, 133 | once | installed | unknown | — |  |
| `hit` | 3 | 40 | once | installed | unknown | — |  |
| `victory` | 8 | 100 | hold_last | installed | unknown | — |  |
| `defeat` | 8 | 100 | hold_last | installed | unknown | — |  |
| `fall` | 4 | 100 | hold_last | installed | unknown | — |  |
| `awaken` | 8 | 120 | loop | installed | unknown | — |  |

Timing rules: `idle` 125 ms (heroes) / 250–300 ms (enemies) per frame today (bible §8.6 says 0.4 s — the installed timing is the user's accepted feel); `step` is nominal, the game paces it by the step cooldown; `windup` ends on a 0 ms frame held until the telegraph ends; hero casts share the Knight's 9-slot timing 83, 83, 83, 83, 200 (hold frame 4), 50, 83, 100, 133 with the release on frame 5.

## 7. Visual constraints (what a new generation must keep)

- Same anchor: generate from `art_src/units/phap_su/idle/0.png` (or the character id) with the first frame pinned; for one-shot clips pin the last frame too.
- Same canvas 96x70, same feet row and feet x; the exporter bottom-aligns shorter sources, never taller ones.
- Identity in the upper half: Tall thin triangle (bible §5.1); south-east bbox 32x58 at the anchor, 8 px shorter than the Knight (mage-assets.md:20); the robe was stretched 7 rows at cleanup so the sheet body is 32x65 (clips.json source).
- 1 px closed Ink outline; banded shading, light from the upper left; no glow, no smooth gradients, no anti-aliasing fringe (ART_QA_CHECKLIST §B–§D).
- Facing stays right in every frame (the model sometimes turns the back from frame 4: drop those frames, as for the Witch's step_up).
- Effects (bursts, stars, slash smears, red sprays) are never part of the body: delete or drop the frame; VFX are separate packs.
- Allowed variation: pose, cloth / hair / tendril sway, breathing 1–2 px, held weapon angle; not allowed: palette drift, proportions, props disappearing, new accessories.

## 8. Generation lineage

- 2026-11-04 anchor-01 create_character_pro_flash 64x84 → character ec5d1863 (6 gen) — REJECTED by the user ('design hơi xấu', made without the reference concept)
- 2026-11-04 anchor-02 create_character_pro_flash 96x96 → character 89dc779e (7 gen) — in use; result approval not recorded
- 2026-11-04 anim02 8 clips (red paint from negative words) → idle v2 + 5 clips redone positive (6 gen) + draw/dash (5 gen)
- 2026-11-05 anim03 idle v3 job 91b7bd35 (1 gen), anchor pinned first and last; anim_qa.py clean

## 9. Versions

- **Current:** installed sheet, see §3
- **Rejected:**
  - anchor-01 (character ec5d1863): 'Rejected by the user ("design hơi xấu")' (mage-assets.md:19)
  - anim02-8clips first idle/cast takes with baked red (negative-word prompts) (mage-assets.md:23)

## 10. Approval history (from the registry)

| Date | Event | Target | By | Evidence / note |
|---|---|---|---|---|
| 2026-11-11 | registered | asset | — | bootstrapped from disk by asset_registry.py; status by location only |
| 2026-11-11 | note | asset | — | Master Reference created: design/assets/references/characters/phap_su.md |

## 11. Open points

- anchor result never recorded as approved: design/assets/specs/mage-assets.md rows anchor-02 / anim03-idle-v3 record per-call approval only. Confirm the current anchor, or name the fix.
- anchor-02 result never recorded as approved (registry attention)
- no step_up and no cast_hand by design (cast_gesture is the hand cast; docs/skill-v2/17-cast-presentation.md)

Evidence folders: `production/qa/evidence/mage-sprite`, `production/qa/evidence/mage-cast`, `production/qa/evidence/mage-fire`
