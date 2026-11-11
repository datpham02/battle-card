# Master Reference — Hunter (Thợ săn) (`tho_san`)

> One file per character (P1, 2026-11-11). Facts come from the registry entry `unit.tho_san`, `art_src/units/tho_san/clips.json`, the sheet JSON and the spec; every claim names its source. **Approval lives in the registry** (`asset_registry.py show unit.tho_san`); this file explains the character so new generations stay consistent. Unknown = no record exists; do not fill it from memory.

## 1. Identity

| Field | Value |
|---|---|
| Registry id / legacy id | `unit.tho_san` / ASSET-032 |
| Type / tier | unit / hero |
| Role | Player hero — Hunter (Thợ săn); wood-and-rope blocks |
| Spec | `design/assets/specs/hunter-assets.md` |
| Design (approved text) | Chibi, upright, square shoulders. Wide round-brim brown hat with one ivory feather; brown hair under the brim, eyes 2x1 in the brim's shadow. Olive-grey hooded cloak with a ragged hem to the knees, jade clasp, short jade cord across the chest. Brown leather jerkin, belt with pouch and square buckle, brown trousers, boots. Anchor-02: the wooden crossbow held lowered in both hands across the hips, bow arm visible (hunter-assets.md:14,34). |
| Silhouette / proportions | T shape (bible §5.1); south-east bbox 46x69 with the feather (hunter-assets.md:34); 96x72 canvas so the feather tip is kept. |
| Likeness check | Closest: Van Helsing (wide hat + crossbow) and Robin Hood. Differentiated: chibi build, round wide brim, olive-grey not Lincoln green, brown hair, crossbow (hunter-assets.md:19). |

## 2. Approved references and anchor

| Field | Value |
|---|---|
| Concept reference | design/art/reference/04-ranger-01.png (user approved the design 2026-11-05: 'Duyệt cả ba'; hunter-assets.md:5) |
| Anchor image (canonical frame) | `art_src/units/tho_san/idle/0.png` — idle frame 0 of the installed source; every new clip is generated from this frame or from the PixelLab character below |
| Rotation set | `design/assets/candidates/hunter/rot02`, `design/assets/candidates/hunter/anim`, `design/assets/candidates/hunter/anim-idle-v2` |
| Anchor approval | **installed** — acceptance unknown |
| Attention | anchor result never recorded as approved: design/assets/specs/hunter-assets.md:5 design approved 2026-11-05 ("Duyệt cả ba"); rows anchor-01/02 record gen approval, not the result. Confirm the current anchor, or name the fix. |

## 3. Facing and frame

| Field | Value |
|---|---|
| Sheet facing | right (`clips.json` facing; the engine flips by negative width for the other side) |
| PixelLab view / direction | low top-down / south-east |
| Frame | 96x72 art px |
| Anchor rule | feet on the last pixel row, feet x = 48; ≥ 1 transparent px left / right / top (`export_sheets.py` refuses otherwise) |
| Sheet | `assets/art/units/unit_tho_san_sheet.png` 872x948, one row per clip, 1 px gutter, Aseprite-array JSON |

## 4. Palette constraints

- Locked at generation: Ink #1B1722; leather #5C3A22 / #8A5A33; olive-grey #5E6150 / #7E8068; jade #46D6A4; skin #E3B99A; ivory #EFE6D2 (feather, buckle). No red, no orange (hunter-assets.md:18).
- In the installed sheet (`meta.tessera.palette`, 7 colours): `#1B1722`, `#46D6A4`, `#5C3A22`, `#5E6150`, `#7E8068`, `#8A5A33`, `#E3B99A`
- Master: `art_src/palette/tessera_master.gpl`; ≤ 8 colours per unit; alpha 0 / 255 only; no red `#E5293B` (telegraph), no orange baked in (Burn); adding a colour is the art-director's call (bible §8.4).

## 5. PixelLab configuration and style reference

| Field | Value |
|---|---|
| Character id | 02521cd4-fad2-4e0c-882d-d1c542c9eaa6 |
| Image / job ids on record | 74bfa36c (anchor-01), 84bad9a1 (anchor-02), b4fc02ad-5164-4c43-8929-f4d6ed5ca82a (idle), 47621581 (cast), a26d8dc3 (step), a5497791 (hit), 2bac1b05 (victory), 8eba13d5 (defeat), 10f0ad8e (fall), 93e0c560 (awaken), 6e0e70d5 (draw), 93243692 (step_forward), 72c2041b (step_back), ad804051 (step_down) |
| Configuration that produced the anchor and clips | create_character_pro_flash 96x96, low top-down, 8 directions, seed 5, palette locked (max 8), style_image = Knight v3 south 84x84 (upload 8efc54de, colour off) (hunter-assets.md:33-34). Clips: animate_image_pixminimax from rot02/south-east.png, 8 frames, seed 1; cast pinned to the anchor as last frame. |
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
| `step_back` | 5 | 50 | once | installed | unknown | — |  |
| `step_down` | 7 | 50 | once | installed | unknown | — |  |
| `cast_gesture` | 9 | 83, 83, 83, 83, 200, 50, 83, 100, 133 | once | installed | unknown | — |  |
| `hit` | 3 | 40 | once | installed | unknown | — |  |
| `victory` | 8 | 100 | hold_last | installed | unknown | — |  |
| `defeat` | 8 | 100 | hold_last | installed | unknown | — |  |
| `fall` | 4 | 100 | hold_last | installed | unknown | — |  |
| `awaken` | 5 | 120 | loop | installed | unknown | — |  |

Timing rules: `idle` 125 ms (heroes) / 250–300 ms (enemies) per frame today (bible §8.6 says 0.4 s — the installed timing is the user's accepted feel); `step` is nominal, the game paces it by the step cooldown; `windup` ends on a 0 ms frame held until the telegraph ends; hero casts share the Knight's 9-slot timing 83, 83, 83, 83, 200 (hold frame 4), 50, 83, 100, 133 with the release on frame 5.

## 7. Visual constraints (what a new generation must keep)

- Same anchor: generate from `art_src/units/tho_san/idle/0.png` (or the character id) with the first frame pinned; for one-shot clips pin the last frame too.
- Same canvas 96x72, same feet row and feet x; the exporter bottom-aligns shorter sources, never taller ones.
- Identity in the upper half: T shape (bible §5.1); south-east bbox 46x69 with the feather (hunter-assets.md:34); 96x72 canvas so the feather tip is kept.
- 1 px closed Ink outline; banded shading, light from the upper left; no glow, no smooth gradients, no anti-aliasing fringe (ART_QA_CHECKLIST §B–§D).
- Facing stays right in every frame (the model sometimes turns the back from frame 4: drop those frames, as for the Witch's step_up).
- Effects (bursts, stars, slash smears, red sprays) are never part of the body: delete or drop the frame; VFX are separate packs.
- Allowed variation: pose, cloth / hair / tendril sway, breathing 1–2 px, held weapon angle; not allowed: palette drift, proportions, props disappearing, new accessories.

## 8. Generation lineage

- 2026-11-05 anchor-01 → character f2d0da86 (7 gen, job 74bfa36c) — crossbow read as a stick, 0 jade pixels: re-rolled
- 2026-11-05 anchor-02 → character 02521cd4 (7 gen, job 84bad9a1) — in use; result approval not recorded
- 2026-11-05 anim-idle job b4fc02ad (1 gen) + anim-11clips (11 gen; hit f1 had a red smear, dropped) → sheet-01
- 2026-11-11 cast_hand hand-paint dropped by the user. The sheet has no `cast_hand`. A hand cast holds idle.

## 9. Versions

- **Current:** installed sheet, see §3
- **Rejected:**
  - anchor-01 (character f2d0da86) re-rolled: 'Misses: the crossbow shows only as a short stock … 0 jade pixels' (hunter-assets.md:33)

## 10. Approval history (from the registry)

| Date | Event | Target | By | Evidence / note |
|---|---|---|---|---|
| 2026-11-11 | registered | asset | — | bootstrapped from disk by asset_registry.py; status by location only |
| 2026-11-11 | note | asset | — | Master Reference created: design/assets/references/characters/tho_san.md |

## 11. Open points

- anchor result never recorded as approved: design/assets/specs/hunter-assets.md:5 design approved 2026-11-05 ("Duyệt cả ba"); rows anchor-01/02 record gen approval, not the result. Confirm the current anchor, or name the fix.
- anchor-02 result never recorded as approved
- step_back has 5 frames (others 7); no step_up

Evidence folders: `production/qa/evidence/hunter-sprite`, `production/qa/evidence/hunter-thorn`
