# Master Reference — Swordsman / Knight (Kiếm sĩ) (`kiem_si`)

> One file per character (P1, 2026-11-11). Facts come from the registry entry `unit.kiem_si`, `art_src/units/kiem_si/clips.json`, the sheet JSON and the spec; every claim names its source. **Approval lives in the registry** (`asset_registry.py show unit.kiem_si`); this file explains the character so new generations stay consistent. Unknown = no record exists; do not fill it from memory.

## 1. Identity

| Field | Value |
|---|---|
| Registry id / legacy id | `unit.kiem_si` / ASSET-001 |
| Type / tier | unit / hero |
| Role | Player hero — Swordsman / Knight (Kiếm sĩ); steel blocks |
| Spec | `design/assets/specs/swordsman-assets.md` |
| Design (approved text) | Chibi knight, rectangular build with two big square symmetric pauldrons, steel-blue plate armour with an ivory trim band across the chest; a straight narrow double-edged sword (blade 2 px) in a dark scabbard across the back — the wide cross-guard (~6 px) and round pommel above the head are the identifying mark, not a wide blade; pale blond hair cut short with a flat fringe, hair falling over the forehead (anti-Cloud choice), 1 px ivory headband; eyes 2x2 Ink, no whites. (design/assets/specs/swordsman-assets.md:34-35 Visual Description v2; art bible §5.1 row Kiếm sĩ) |
| Silhouette / proportions | Rectangle; two square shoulders; v3 tall OSFE ratio ~4.5 heads: visible 31x66 px south-east (swordsman-assets.md:105). In battle the sword is held in a guard stance the whole match (user 2026-11-02 'trạng thái đứng luôn'; swordsman-assets.md:112). |
| Likeness check | v1 read as Cloud Strife (FF7) and was dropped (swordsman-assets.md:85). Differentiated: short flat blond cut with headband, narrow double-edged sword with cross-guard, square pauldrons, short cape. |

## 2. Approved references and anchor

| Field | Value |
|---|---|
| Concept reference | design/art/reference/04-knight-01.png (described in words, never used as an image input — swordsman-assets.md row v3-knight-01) |
| Anchor image (canonical frame) | `art_src/units/kiem_si/idle/0.png` — idle frame 0 of the installed source; every new clip is generated from this frame or from the PixelLab character below |
| Rotation set | `design/assets/candidates/swordsman/v3-tall`, `design/assets/candidates/swordsman/v3-tall/clean-96x70`, `design/assets/candidates/swordsman/anim-idle-v2`, `design/assets/candidates/swordsman/cast-forward`, `design/assets/candidates/swordsman/cast-command`, `design/assets/candidates/swordsman/cast-hand-v3` |
| Anchor approval | **approved** — art_src/units/kiem_si/clips.json source: "v3 tall anchor, approved 2026-10-31"; design/assets/specs/swordsman-assets.md:116 (Status 2026-10-31 v3) |

## 3. Facing and frame

| Field | Value |
|---|---|
| Sheet facing | right (`clips.json` facing; the engine flips by negative width for the other side) |
| PixelLab view / direction | low top-down / south-east |
| Frame | 96x92 art px, body_h 70 |
| Anchor rule | feet on the last pixel row, feet x = 48; ≥ 1 transparent px left / right / top (`export_sheets.py` refuses otherwise) |
| Sheet | `assets/art/units/unit_kiem_si_sheet.png` 872x1394, one row per clip, 1 px gutter, Aseprite-array JSON |

## 4. Palette constraints

- Locked at generation: Ink #1B1722; steel #5F6F82 / #8FA3B8 / #EEF4FA; navy cape #34406E; brass #B8893A; ash hair #D8CDB0; skin #E3B99A (swordsman-assets.md:104 v3-knight-01 palette). Accent (light steel #EEF4FA) ≤ 15 % of pixels (art bible §5.1).
- In the installed sheet (`meta.tessera.palette`, 8 colours): `#1B1722`, `#34406E`, `#5F6F82`, `#8FA3B8`, `#B8893A`, `#D8CDB0`, `#E3B99A`, `#EEF4FA`
- Master: `art_src/palette/tessera_master.gpl`; ≤ 8 colours per unit; alpha 0 / 255 only; no red `#E5293B` (telegraph), no orange baked in (Burn); adding a colour is the art-director's call (bible §8.4).

## 5. PixelLab configuration and style reference

| Field | Value |
|---|---|
| Character id | 2d093318-1ba4-43aa-b843-a5f0fdf62939 |
| Image / job ids on record | 5e5e14ed-952d-42ec-b517-8bff32bb795e (cast_forward), 91224bb1-17de-4a5b-a70b-b4f6a93ac14d (cast_summon), 9d1adf31 (idle v2), 5e4ba76d-2db3-44aa-8ea5-cc0d2e0a4118 (guard cast = cast_gesture), ac2cb023 (cast_overhead v1, rejected), 2a14a25c (cast_hand v3, dropped 2026-11-11, not on the sheet) |
| Configuration that produced the anchor and clips | create_character_pro_flash, canvas 64x84 (text), low top-down, 8 directions, seed 5, palette locked (max 8), style_image = v3-knight-01 south rotation (own image; outline / shading / detail only, colour off); prompt 'same design, ~4.5 heads, ~76 px tall' (swordsman-assets.md:105). Clips: animate_character pixminimax south-east 4–8 frames (2026-10-31/11-02), then animate_image_pixminimax from the local guard anchor with first (and last) frame pinned (2026-11-02 onward). |
| Style reference (style_image lineage) | v3-knight-01 (character f81b0fb3, 48x64) → v3-knight-tall (character 2d093318). The Knight's south rotation is the style_image for every other hero (upload 8efc54de, 84x84). |
| Post-generation (free, mechanical only) | palette snap to the locked colours, specks < 12 px removed, feet re-planted on the last row, body recentred; region recolour when the model drifted (Knight cape); never hand-painted detail (user rule) |

## 6. Animation contract

Required for a hero (art bible §5.4 / §8.6): `idle`, `step`, `cast_gesture`, `hit`, `victory`, `defeat`, `awaken`, `fall`.
Optional clips the code plays when present (fallback otherwise): `draw`, `step_forward`, `step_back`, `step_up`, `step_down`, `cast_hand`, `cast_forward`, `cast_summon`.

| Clip | Frames | ms per frame | Loop | Status | Acceptance | Generation | Note |
|---|---|---|---|---|---|---|---|
| `idle` | 8 | 125 | loop | installed | unknown | 9d1adf31 | 2026-11-02 guard stance (user: in battle the knight holds the sword ready, 'trạng thái đứng luôn'): PixMiniMax from the draw_to_guard last frame, cleaned and recentred on the body |
| `draw` | 8 | 60, 60, 80, 80, 80, 80, 80, 120 | once | installed | unknown | — | 2026-11-02 match start: draws the sword from the back into the guard stance (PixMiniMax on the v3 character, no recentring: the feet do not move); UnitLayer plays it once when the match binds |
| `step` | 4 | 100 | loop | installed | unknown | — | nominal; the game paces step by the step cooldown |
| `step_forward` | 7 | 50 | once | installed | unknown | — | 2026-11-02 guard stance (user: in battle the knight holds the sword ready, 'trạng thái đứng luôn'): PixMiniMax from the draw_to_guard last frame, cleaned and recentred on the body; OSFE dash, the game glides the unit |
| `step_back` | 7 | 50 | once | installed | unknown | — | 2026-11-02 guard stance (user: in battle the knight holds the sword ready, 'trạng thái đứng luôn'): PixMiniMax from the draw_to_guard last frame, cleaned and recentred on the body; OSFE back-dash, still facing right |
| `step_up` | 7 | 50 | once | installed | unknown | — | 2026-11-02 guard stance (user: in battle the knight holds the sword ready, 'trạng thái đứng luôn'): PixMiniMax from the draw_to_guard last frame, cleaned and recentred on the body; keeps facing right (the first roll turned its back) |
| `step_down` | 7 | 50 | once | installed | unknown | — | 2026-11-02 guard stance (user: in battle the knight holds the sword ready, 'trạng thái đứng luôn'): PixMiniMax from the draw_to_guard last frame, cleaned and recentred on the body |
| `cast_gesture` | 9 | 83, 83, 83, 83, 200, 50, 83, 100, 133 | once | installed | unknown | — | 2026-11-02 guard stance: PixMiniMax from the guard anchor (first and last frame pinned to it), src frames 0,1,2,3,4,8,6,7,0: guard, raise, lift, coil, coil (frame 4, held during the swing telegraph by the cast index gesture_hold_frame), slash with the arm fully out (5, the release cut and the wave leave; src 5 had a baked crescent smear, dropped), follow-through x2, back to the guard. Same 9 frames and ms as the v4 clip, so the cast timing data is unchanged |
| `cast_forward` | 9 | 83, 83, 83, 83, 200, 50, 83, 100, 133 | once | approved | approved 2026-11-08 | 5e5e14ed-952d-42ec-b517-8bff32bb795e | 2026-11-08 Trảm Địa (user-approved PixMiniMax job 5e5e14ed-952d-42ec-b517-8bff32bb795e, 1 gen; first and last frame pinned to cast_gesture/0 guard): raw f0-f8 in design/assets/candidates/swordsman/cast-forward/raw, cleaned mechanically (tools/qa/sprite_clean.gd: palette snap to the 7 sheet colours, specks < 6 px dropped, f1/f2 +5 px, f3 +6 px, f6/f7 -1 px so the feet stay on x32-38). Slots: f0 guard, f1-f2 draw back, f3 coil (also slot 4, held during the swing telegraph like cast_gesture's frame 4), f5 release (low forward), f6-f7 follow-through, f8 guard; raw f4 dropped (baked slash smear). Same 9 ms as cast_gesture so the cast timing data is unchanged. Known: the wind-up raises the sword high (not low to the hip as asked) (cape fixed 2026-11-08: tools/qa/sprite_recolour_region.gd b8893a -> 34406e on the INTERIOR of gold components >= 25 px, slots 5 and 6 only, 54 + 30 px; the 1 px gold trim and every armour trim kept). |
| `cast_summon` | 9 | 83, 83, 83, 83, 200, 50, 83, 100, 133 | once | installed | accepted 2026-11-08 | 91224bb1-17de-4a5b-a70b-b4f6a93ac14d | 2026-11-08 Ngàn Kiếm cast (user-chosen): one-handed raise + pull-down, user-approved PixMiniMax job 91224bb1-17de-4a5b-a70b-b4f6a93ac14d (1 gen; first frame = guard 96x92, last frame = the earlier command pose 96x92), raw in design/assets/candidates/swordsman/cast-command/raw. Mechanical clean only (palette snap; 0 speck px; no move: feet already on x32-38 row 91). Slots: raw f0 guard, f1 crouch, f3 raise, f5 raise, f4 summon hold (slot 4: held through the swing and, for the on-tile summon, until the visual command), f7 pull-down + cape (release), f8 command pose, then the return and the guard (frames of the retired cast_overhead v1 7 and 8, kept here as slots 7-8). Raw f2 (blade on the frame top row) and f6 (baked smear arc) dropped. Known and accepted by the user: the raised blade overlaps the top-row HUD on 3 of 4 cells. |
| `hit` | 3 | 40 | once | installed | unknown | — | 2026-11-02 guard stance (user: in battle the knight holds the sword ready, 'trạng thái đứng luôn'): PixMiniMax from the draw_to_guard last frame, cleaned and recentred on the body (src frames 1, 4, 5: the slash smear of 2-3 dropped) |
| `victory` | 5 | 100 | hold_last | installed | unknown | — |  |
| `defeat` | 8 | 100 | hold_last | installed | unknown | — |  |
| `fall` | 4 | 100 | hold_last | installed | unknown | — | unused until the falling-cell story (no gameplay uses it yet) |
| `awaken` | 6 | 120 | loop | installed | unknown | — |  |

Timing rules: `idle` 125 ms (heroes) / 250–300 ms (enemies) per frame today (bible §8.6 says 0.4 s — the installed timing is the user's accepted feel); `step` is nominal, the game paces it by the step cooldown; `windup` ends on a 0 ms frame held until the telegraph ends; hero casts share the Knight's 9-slot timing 83, 83, 83, 83, 200 (hold frame 4), 50, 83, 100, 133 with the release on frame 5.

## 7. Visual constraints (what a new generation must keep)

- Same anchor: generate from `art_src/units/kiem_si/idle/0.png` (or the character id) with the first frame pinned; for one-shot clips pin the last frame too.
- Same canvas 96x92, same feet row and feet x; the exporter bottom-aligns shorter sources, never taller ones.
- Identity in the upper half: Rectangle; two square shoulders; v3 tall OSFE ratio ~4.5 heads: visible 31x66 px south-east (swordsman-assets.md:105). In battle the sword is held in a guard stance the whole match (user 2026-11-02 'trạng thái đứng luôn'; swordsman-assets.md:112).
- 1 px closed Ink outline; banded shading, light from the upper left; no glow, no smooth gradients, no anti-aliasing fringe (ART_QA_CHECKLIST §B–§D).
- Facing stays right in every frame (the model sometimes turns the back from frame 4: drop those frames, as for the Witch's step_up).
- Effects (bursts, stars, slash smears, red sprays) are never part of the body: delete or drop the frame; VFX are separate packs.
- Allowed variation: pose, cloth / hair / tendril sway, breathing 1–2 px, held weapon angle; not allowed: palette drift, proportions, props disappearing, new accessories.

## 8. Generation lineage

- 2026-10-31 v1 40x48 / 32x48 frames (Cloud-like) — rejected, parked in candidates/swordsman/v1-cloudlike + ASSET-001-*-40x48.png
- 2026-10-31 v2-cand-01 create_image_pro_flash 32x48 seed 2 (job cdafe2b0) — anti-Cloud design, superseded by v3
- 2026-10-31 v3-cand-01 create_image_pro_flash 48x64 (job 391d2fc7) — not accepted (bald head, front only)
- 2026-10-31 v3-knight-01 create_character_pro_flash 48x64 → character f81b0fb3 (6 gen) — design right, too short
- 2026-10-31 v3-knight-tall create_character_pro_flash 64x84, style_image = v3-knight-01 south → character 2d093318 (6 gen) — APPROVED anchor
- 2026-10-31 v3-anim-idle + 7 clips animate_character pixminimax (8 gen) → clean-96x70
- 2026-11-02 dashes (4 gen), draw_to_guard + 6 guard clips (7 gen), guard cast (1 gen, job 5e4ba76d) — guard stance set
- 2026-11-05 idle v2 animate_image_pixminimax job 9d1adf31 (anchor pinned first + last)
- 2026-11-08 cast_forward job 5e5e14ed (1 gen) — approved; cast_summon job 91224bb1 (1 gen) — accepted; canvas grew to 96x92 (option A)
- 2026-11-10 cast_hand v3 job 2a14a25c — approved, then dropped from the sheet by the user on 2026-11-11. The raw frames stay in candidates/swordsman/cast-hand-v3 and are not installed. A hand cast holds idle.

## 9. Versions

- **Current:** v3-tall (96x92 canvas since 2026-11-08, sources 96x70 bottom-aligned)
- **Retired:**
  - v1 40x48 (Cloud-like) — paths `design/assets/candidates/swordsman/ASSET-001-*-40x48.png`, `design/assets/candidates/swordsman/v1-cloudlike`, `design/assets/candidates/swordsman/pre-40x48` — design/assets/specs/swordsman-assets.md:85 "the v1 Swordsman reads as Cloud Strife"
  - v2 anti-Cloud rotations — paths `design/assets/candidates/swordsman/ASSET-001-v2-*.png` — swordsman-assets.md v2 rows (superseded by v3 tall)
  - cast_overhead v1 (job ac2cb023) — paths `design/assets/candidates/swordsman/cast-overhead` — design/assets/specs/swordsman-cast-overhead-v2.md:3 "placeholder and is NOT approved"; not in clips.json
- **Rejected:**
  - v1 40x48 Cloud-like body (swordsman-assets.md:85)
  - v3-cand-01 48x64 still (swordsman-assets.md:103)
  - cast_overhead v1 (job ac2cb023): 'placeholder and is NOT approved' (swordsman-cast-overhead-v2.md:3)
  - cast_summon K4 first take: 'Verdict: NOT APPROVED' (swordsman-cast-command.md:72) before the accepted raise + pull-down
  - cast_hand v1, v2, v3, k2-edit, k2-mitten. v3 was approved 2026-11-10 and removed from the sheet 2026-11-11 (candidates/swordsman/cast-hand-*/QA.md)

## 10. Approval history (from the registry)

| Date | Event | Target | By | Evidence / note |
|---|---|---|---|---|
| 2026-11-11 | registered | asset | — | bootstrapped from disk by asset_registry.py; status by location only |
| 2026-10-31 | user_approved installed→approved | asset | user | art_src/units/kiem_si/clips.json source: "v3 tall anchor, approved 2026-10-31"; design/assets/specs/swordsman-assets.md:116 (Status 2026-10-31 v3) |
| 2026-11-08 | user_approved installed→approved | cast_forward | user | docs/skill-v2/skill-checklist.md tram_dia row: Animation **APPROVED** (cast_forward); art_src/units/kiem_si/clips.json note "user-approved PixMiniMax job 5e5e14ed" |
| 2026-11-08 | user_accepted | cast_summon | user | design/assets/specs/swordsman-cast-command.md:3 "ACCEPTED by the user 2026-11-08 as cast_summon"; docs/skill-v2/skill-checklist.md ngan_kiem row "ACCEPTED 2026-11-08 (cast_summon, job 91224bb1)" |
| 2026-11-10 | user_approved installed→approved | cast_hand | user | art_src/units/kiem_si/clips.json note "PixMiniMax v3 (job 2a14a25c, user-approved 2026-11-10)"; commit 03b71a4 "Knight cast_hand clip from the approved PixMiniMax v3 hand push" |
| 2026-11-11 | note | asset | — | Master Reference created: design/assets/references/characters/kiem_si.md |
| 2026-11-11 | note | cast_hand | user | dropped from the sheet. Job 2a14a25c is not installed. A hand cast holds idle. |

## 11. Open points

- 5x5 back-row head sits under the player HP panel (swordsman-assets.md:116, deferred top-row HUD issue)
- fall clip unused until the falling-cell story
- Registry `unit.kiem_si`: `status` approved (2026-10-31, evidence in §10), `acceptance` unknown. Do not treat status as acceptance.
- `palette_status`: locked. The eight sheet colours in §4 match `unit_kiem_si_sheet.json` `meta.tessera.palette` and are in `tessera_master.gpl`. No further body colour.
- Frame 96x92, `body_h` 70, sheet 872x1394: matches `docs/art/RENDER-STANDARDS.md` and the sheet JSON. Outline is the Ink already named in §4.
- Shade steps per material: unknown. Not measured on the sheet.
- Anatomy beyond §1 (a separate eye, armour or weapon spec): unknown. Do not add it.
- `cast_hand` is not on the sheet (dropped 2026-11-11, §8 and §10). §6 lists it only as a clip the code plays when the sheet has it.

Evidence folders: `production/qa/evidence/swordsman-v3`, `production/qa/evidence/guard-stance`, `production/qa/evidence/kiem-si-cast-hand`, `production/qa/evidence/skill-v2-tram-dia-art`, `production/qa/evidence/skill-v2-ngan-kiem`, `production/qa/evidence/unit-sheet-export`, `production/qa/evidence/units-centred`
