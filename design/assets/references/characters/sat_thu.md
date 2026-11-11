# Master Reference — Assassin (Sát thủ) (`sat_thu`)

> One file per character (P1, 2026-11-11). Facts come from the registry entry `unit.sat_thu`, `art_src/units/sat_thu/clips.json`, the sheet JSON and the spec; every claim names its source. **Approval lives in the registry** (`asset_registry.py show unit.sat_thu`); this file explains the character so new generations stay consistent. Unknown = no record exists; do not fill it from memory.

## 1. Identity

| Field | Value |
|---|---|
| Registry id / legacy id | `unit.sat_thu` / ASSET-031 |
| Type / tier | unit / hero |
| Role | Player hero — Assassin (Sát thủ); jade-white ice blocks |
| Spec | `design/assets/specs/assassin-assets.md` |
| Design (approved text) | Chibi, crouched wide stance, knees bent. Pointed square-cut hood (tip falls back) with a small jade-white diamond emblem on the forehead and a jade-white hood edge; dark cloth mask over nose and mouth; charcoal fringe under the hood; eyes 2x2 Ink. Short charcoal capelet, brown leather bracers, belt with a square buckle, wrapped legs, brown boots. Two short daggers held reverse grip, crossed in front of the chest at rest (assassin-assets.md:16). |
| Silhouette / proportions | Flat rhombus, crouched, meant to be the shortest hero (bible §5.1); the anchor came out as tall as the Knight (bbox 42x67, the crouch went into width — assassin-assets.md:36). |
| Likeness check | Closest: the hooded assassins of Assassin's Creed (Altaïr / Ezio). Differentiated: chibi crouch, square pointed hood with a diamond emblem, charcoal cloth, reverse-grip short daggers (assassin-assets.md:21). |

## 2. Approved references and anchor

| Field | Value |
|---|---|
| Concept reference | design/art/reference/04-rogue-01.png (user approved the design 2026-11-05: 'Duyệt cả ba'; assassin-assets.md:5) |
| Anchor image (canonical frame) | `art_src/units/sat_thu/idle/0.png` — idle frame 0 of the installed source; every new clip is generated from this frame or from the PixelLab character below |
| Rotation set | `design/assets/candidates/assassin/rot`, `design/assets/candidates/assassin/anim`, `design/assets/candidates/assassin/anim-idle-v2` |
| Anchor approval | **installed** — acceptance unknown |
| Attention | anchor result never recorded as approved: design/assets/specs/assassin-assets.md:5 design approved 2026-11-05 ("Duyệt cả ba"); row anchor-01 records the gen approval ("Duyệt, gen 7 gen"), not the result. Confirm the current anchor, or name the fix. |

## 3. Facing and frame

| Field | Value |
|---|---|
| Sheet facing | right (`clips.json` facing; the engine flips by negative width for the other side) |
| PixelLab view / direction | low top-down / south-east |
| Frame | 96x70 art px |
| Anchor rule | feet on the last pixel row, feet x = 48; ≥ 1 transparent px left / right / top (`export_sheets.py` refuses otherwise) |
| Sheet | `assets/art/units/unit_sat_thu_sheet.png` 872x851, one row per clip, 1 px gutter, Aseprite-array JSON |

## 4. Palette constraints

- Locked at generation: Ink #1B1722; cloth #2C2A35 / #3A3744 / #555064; leather #5E4636 / #8A6A50; jade-white #BFF3EC; skin #E3B99A (eye band only). No red, no orange, no ice blue (assassin-assets.md:20).
- In the installed sheet (`meta.tessera.palette`, 8 colours): `#1B1722`, `#2C2A35`, `#3A3744`, `#555064`, `#5E4636`, `#8A6A50`, `#BFF3EC`, `#E3B99A`
- Master: `art_src/palette/tessera_master.gpl`; ≤ 8 colours per unit; alpha 0 / 255 only; no red `#E5293B` (telegraph), no orange baked in (Burn); adding a colour is the art-director's call (bible §8.4).

## 5. PixelLab configuration and style reference

| Field | Value |
|---|---|
| Character id | 47d6480b-8685-429a-9971-8f28145d6bdb |
| Image / job ids on record | ba18ae67 (anchor-01), 352a7f82-1c49-4242-a197-d148798928ff (idle), 66c2c370-7430-4261-8b0f-97b410c4c0ef (cast X-slash = cast_gesture), aa9bd847 (step), 0172ee9f (first cast, replaced), e1fb8dcc (hit), 70c8d999 (victory), 505383fc (defeat), 66a4bb2d (fall), 5caa3f37 (awaken), 77835371 (draw), eddb6e2d (step_forward), fbdc6ca3 (step_back, not installed), c01eed60 (step_down) |
| Configuration that produced the anchor and clips | create_character_pro_flash 96x96, low top-down, 8 directions, seed 5, palette locked (max 8), style_image = Knight v3 south 84x84 (upload 8efc54de, colour off) (assassin-assets.md:36). Clips: animate_image_pixminimax, first frame = rot/south-east.png, 8 frames, seed 1, south-east, positive motion words only; cast X-slash pinned first and last to the anchor (job 66c2c370). |
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
| `step_down` | 7 | 50 | once | installed | unknown | — |  |
| `cast_gesture` | 9 | 83, 83, 83, 83, 200, 50, 83, 100, 133 | once | installed | unknown | — |  |
| `hit` | 3 | 40 | once | installed | unknown | — |  |
| `victory` | 8 | 100 | hold_last | installed | unknown | — |  |
| `defeat` | 8 | 100 | hold_last | installed | unknown | — |  |
| `fall` | 4 | 100 | hold_last | installed | unknown | — |  |
| `awaken` | 5 | 120 | loop | installed | unknown | — |  |

Timing rules: `idle` 125 ms (heroes) / 250–300 ms (enemies) per frame today (bible §8.6 says 0.4 s — the installed timing is the user's accepted feel); `step` is nominal, the game paces it by the step cooldown; `windup` ends on a 0 ms frame held until the telegraph ends; hero casts share the Knight's 9-slot timing 83, 83, 83, 83, 200 (hold frame 4), 50, 83, 100, 133 with the release on frame 5.

## 7. Visual constraints (what a new generation must keep)

- Same anchor: generate from `art_src/units/sat_thu/idle/0.png` (or the character id) with the first frame pinned; for one-shot clips pin the last frame too.
- Same canvas 96x70, same feet row and feet x; the exporter bottom-aligns shorter sources, never taller ones.
- Identity in the upper half: Flat rhombus, crouched, meant to be the shortest hero (bible §5.1); the anchor came out as tall as the Knight (bbox 42x67, the crouch went into width — assassin-assets.md:36).
- 1 px closed Ink outline; banded shading, light from the upper left; no glow, no smooth gradients, no anti-aliasing fringe (ART_QA_CHECKLIST §B–§D).
- Facing stays right in every frame (the model sometimes turns the back from frame 4: drop those frames, as for the Witch's step_up).
- Effects (bursts, stars, slash smears, red sprays) are never part of the body: delete or drop the frame; VFX are separate packs.
- Allowed variation: pose, cloth / hair / tendril sway, breathing 1–2 px, held weapon angle; not allowed: palette drift, proportions, props disappearing, new accessories.

## 8. Generation lineage

- 2026-11-05 anchor-01 create_character_pro_flash → character 47d6480b (7 gen, job ba18ae67); hood emblem came out as a cross
- 2026-11-05 anim-idle job 352a7f82 (1 gen) + anim-11clips (11 gen) → sheet-01
- 2026-11-05 anim-cast-xslash job 66c2c370 (1 gen) — installed as cast_gesture after the user called the first cast pose a glitch
- 2026-11-11 cast_hand hand-paint dropped by the user. The sheet has no `cast_hand`. A hand cast holds idle.

## 9. Versions

- **Current:** installed sheet, see §3
- **Rejected:**
  - first cast_gesture (crossed-dagger hold) replaced 2026-11-05: user 'động tác cast skill của sát thủ xấu quá, làm cho nó chém chéo nhau' (assassin-assets.md:41)

## 10. Approval history (from the registry)

| Date | Event | Target | By | Evidence / note |
|---|---|---|---|---|
| 2026-11-11 | registered | asset | — | bootstrapped from disk by asset_registry.py; status by location only |
| 2026-11-11 | note | asset | — | Master Reference created: design/assets/references/characters/sat_thu.md |

## 11. Open points

- anchor result never recorded as approved: design/assets/specs/assassin-assets.md:5 design approved 2026-11-05 ("Duyệt cả ba"); row anchor-01 records the gen approval ("Duyệt, gen 7 gen"), not the result. Confirm the current anchor, or name the fix.
- anchor result never recorded as approved (design was)
- no step_back / step_up clip (not required by the bible)

Evidence folders: `production/qa/evidence/assassin-sprite`
