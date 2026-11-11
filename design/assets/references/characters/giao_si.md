# Master Reference — Cleric (Giáo sĩ) (`giao_si`)

> One file per character (P1, 2026-11-11). Facts come from the registry entry `unit.giao_si`, `art_src/units/giao_si/clips.json`, the sheet JSON and the spec; every claim names its source. **Approval lives in the registry** (`asset_registry.py show unit.giao_si`); this file explains the character so new generations stay consistent. Unknown = no record exists; do not fill it from memory.

## 1. Identity

| Field | Value |
|---|---|
| Registry id / legacy id | `unit.giao_si` / ASSET-033 |
| Type / tier | unit / hero |
| Role | Player hero — Cleric (Giáo sĩ); stained-glass blocks |
| Spec | `design/assets/specs/cleric-assets.md` |
| Design (approved text) | Chibi, calm upright pose, robe flaring into a wide bell to the ground. Soft ivory veil over head and shoulders, eyes closed (short Ink line). Ivory-grey layered robe with wide sleeves, lead-grey tabard, plain belt. Tall pale staff in the right hand, its head a square frame inside a larger square (turned 45°) (cleric-assets.md:14). The lilac accent of the design did not survive generation: the approved anchor has no block-colour accent (cleric-assets.md:37, open deviation from bible §5.1). |
| Silhouette / proportions | Bell with a wide base (bible §5.1); south-east bbox 33x66 (cleric-assets.md:34); 96x72 canvas keeps the staff head. |
| Likeness check | Closest: Final Fantasy's White Mage and generic fantasy nuns. Differentiated: no red triangle trim, no hood with ears, a veil with closed eyes, the square-in-square staff (cleric-assets.md:19). |

## 2. Approved references and anchor

| Field | Value |
|---|---|
| Concept reference | design/art/reference/04-cleric-01.png (user approved the design 2026-11-05: 'Duyệt cả ba'; cleric-assets.md:5) |
| Anchor image (canonical frame) | `art_src/units/giao_si/idle/0.png` — idle frame 0 of the installed source; every new clip is generated from this frame or from the PixelLab character below |
| Rotation set | `design/assets/candidates/cleric/edit01`, `design/assets/candidates/cleric/rot`, `design/assets/candidates/cleric/anim`, `design/assets/candidates/cleric/anim-idle-v2` |
| Anchor approval | **approved** — design/assets/specs/cleric-assets.md:37 "edit-01 approved by the user as the anchor ('Duyệt bản này') without the lilac" |

## 3. Facing and frame

| Field | Value |
|---|---|
| Sheet facing | right (`clips.json` facing; the engine flips by negative width for the other side) |
| PixelLab view / direction | low top-down / south-east |
| Frame | 96x72 art px |
| Anchor rule | feet on the last pixel row, feet x = 48; ≥ 1 transparent px left / right / top (`export_sheets.py` refuses otherwise) |
| Sheet | `assets/art/units/unit_giao_si_sheet.png` 872x948, one row per clip, 1 px gutter, Aseprite-array JSON |

## 4. Palette constraints

- Locked at generation: Ink #1B1722; robe #6E7282 / #B8BCC8 / #E2E3EA; lilac #8F86B8 / #B9B0DC (absent in the result); skin #E3B99A; staff ivory #D8CDB0. No red, no gold, no saturated purple (cleric-assets.md:18). Sheet uses 5 colours.
- In the installed sheet (`meta.tessera.palette`, 5 colours): `#1B1722`, `#6E7282`, `#B8BCC8`, `#E2E3EA`, `#E3B99A`
- Master: `art_src/palette/tessera_master.gpl`; ≤ 8 colours per unit; alpha 0 / 255 only; no red `#E5293B` (telegraph), no orange baked in (Burn); adding a colour is the art-director's call (bible §8.4).

## 5. PixelLab configuration and style reference

| Field | Value |
|---|---|
| Character id | dd4ae0ea-c394-4082-9b93-564aa6475835 |
| Image / job ids on record | 8dd433f4, e76c9426 (anchor-01), ad569528 (anchor-02), 8dd433f4-3aef-4ac6-a161-40a3049757fe (edit-01 = approved anchor, image 5f2d435e), 9e174321 (idle), ad0dde11 (step), 90eed179 (cast), 7f462a6d (hit), 5d28235e (victory), 647dc4da (defeat), ea27d945 (fall), e9129f24 (awaken), b3fccf42 (draw), bfab244e (step_forward), 07b4d53c (step_back), d16f224d (step_down) |
| Configuration that produced the anchor and clips | create_character_pro_flash 96x96, low top-down, 8 directions, seed 5, palette locked (max 8), style_image = Knight v3 south 84x84 (upload 8efc54de, colour off); anchor = edit_image_pro_flash (text, seed 5, use_color_palette_correction true) on anchor-01's south-east rotation (cleric-assets.md:34-36). Clips: animate_image_pixminimax x12 from edit01/south-east.png (upload bf7f0a79), 8 frames, seed 1, one locked prompt set approved once (cleric-assets.md:38). |
| Style reference (style_image lineage) | Knight v3 south 84x84 (upload 8efc54de). |
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
| `awaken` | 5 | 120 | loop | installed | unknown | — |  |

Timing rules: `idle` 125 ms (heroes) / 250–300 ms (enemies) per frame today (bible §8.6 says 0.4 s — the installed timing is the user's accepted feel); `step` is nominal, the game paces it by the step cooldown; `windup` ends on a 0 ms frame held until the telegraph ends; hero casts share the Knight's 9-slot timing 83, 83, 83, 83, 200 (hold frame 4), 50, 83, 100, 133 with the release on frame 5.

## 7. Visual constraints (what a new generation must keep)

- Same anchor: generate from `art_src/units/giao_si/idle/0.png` (or the character id) with the first frame pinned; for one-shot clips pin the last frame too.
- Same canvas 96x72, same feet row and feet x; the exporter bottom-aligns shorter sources, never taller ones.
- Identity in the upper half: Bell with a wide base (bible §5.1); south-east bbox 33x66 (cleric-assets.md:34); 96x72 canvas keeps the staff head.
- 1 px closed Ink outline; banded shading, light from the upper left; no glow, no smooth gradients, no anti-aliasing fringe (ART_QA_CHECKLIST §B–§D).
- Facing stays right in every frame (the model sometimes turns the back from frame 4: drop those frames, as for the Witch's step_up).
- Effects (bursts, stars, slash smears, red sprays) are never part of the body: delete or drop the frame; VFX are separate packs.
- Allowed variation: pose, cloth / hair / tendril sway, breathing 1–2 px, held weapon angle; not allowed: palette drift, proportions, props disappearing, new accessories.

## 8. Generation lineage

- 2026-11-05 anchor-01 → character dd4ae0ea (7 gen, job e76c9426) — 0 lilac, staff edge-on
- 2026-11-05 anchor-02 → character 67c145a6 (7 gen, job ad569528) — worse (face painted in robe colours)
- 2026-11-05 edit-01 edit_image_pro_flash on anchor-01 south-east → job 8dd433f4, image 5f2d435e (5 gen) — APPROVED anchor ('Duyệt bản này') without the lilac
- 2026-11-05 anim-12clips (12 gen, all usable) → sheet-01
- 2026-11-11 cast_hand hand-paint dropped by the user. The sheet has no `cast_hand`. A hand cast holds idle.

## 9. Versions

- **Current:** installed sheet, see §3
- **Rejected:**
  - anchor-02 (character 67c145a6): 'Worse … a washed-out lilac-cream statue / ghost' (cleric-assets.md:35)

## 10. Approval history (from the registry)

| Date | Event | Target | By | Evidence / note |
|---|---|---|---|---|
| 2026-11-11 | registered | asset | — | bootstrapped from disk by asset_registry.py; status by location only |
| 2026-11-05 | user_approved installed→approved | asset | user | design/assets/specs/cleric-assets.md:37 "edit-01 approved by the user as the anchor ('Duyệt bản này') without the lilac" |
| 2026-11-11 | note | asset | — | Master Reference created: design/assets/references/characters/giao_si.md |

## 11. Open points

- no lilac accent — bible §5.1 not met, accepted by the user as an open deviation (cleric-assets.md:37)
- no step_up

Evidence folders: `production/qa/evidence/cleric-sprite`
